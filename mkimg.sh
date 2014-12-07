#!/usr/bin/env bash
#
# Coreos image builder (hybrid ISO and FAT32 IMG) for Linux
# (c) 2014 Jose Riguera <jriguera@gmail.com>
# Licensed under GPLv3
# https://github.com/nyarla/coreos-live-iso
set -e

PROGRAM=${PROGRAM:-$(basename $0)}
PROGRAM_DIR=$(cd $(dirname "$0") && pwd)
PROGRAM_OPTS=$@

# Default config
SYSLINUX_VERSION="6.02"
COREOS_VERSION="master"
MEMTEST_VERSION="5.01"
IMG_SIZE=1000
IMG_TYPE="ISO"
AUTOLOGIN=0
INIT_SCRIPT="cloud-config.yml"
INSTALL_SCRIPT="install.sh"
OEM_CLOUD_CONFIG=""
AUTOINSTALL=0

# Functions and procedures
#############################

# help
usage() {
    cat <<EOF
Usage:

    $PROGRAM  [<arguments>] 

Coreos image builder (hybrid ISO and FAT32 image) for Linux using syslinux
IMG: editable FAT32 ready to dump to a USB drive
ISO: hybrid ISO (image and USB) ready to dump or burn

Arguments:

   -a, --autologin			Enable coreos.autologin boot parameter
   -h, --help           		Show this usage message
   -i, --initcloudconfig <cloud-config> Cloud-config for live booting
   -k, --sshkey <file> 			ssh-key file to include automatically
   -l, --syslinuxversion <version> 	Syslinux version ($SYSLINUX_VERSION)
   -o, --output <file>			Output image file (coreos-${COREOS_VERSION}.iso)
   -p, --provcloudconfig <cloud-config> Cloud-config to perform automatic install
   -s, --size <#>       		Size in MB ($IMG_SIZE)
   -v, --coreosversion <version>   	Coreos version ($COREOS_VERSION)
   -u, --usb				Create an IMG file (ISO)
       --autoinstall		        Run automatically automatic install (WARNING!)
       --oemcloudconfig <cloud-config>  Static basic cloud-config for OEM

Note that a cloud-config file can be a bash script file. See cloud-init documentation.

EOF
}


download() {
    local url="$1"
    local destin="$2"

    echo -n "   "
    if [ ! -z "${destin}" ]; then
        wget --progress=dot "${url}" -O  "${destin}" 2>&1 | grep --line-buffered "%" | \
        sed -u -e "s,\.,,g" | awk '{printf("\b\b\b\b%4s", $2)}'
    else 
        wget --progress=dot "${url}" 2>&1 | grep --line-buffered "%" | \
        sed -u -e "s,\.,,g" | awk '{printf("\b\b\b\b%4s", $2)}'
    fi
    echo -ne "\b\b\b\b"
    echo "done"
}


get_coreos() {
    local dst="$1"
    local kernel_url="$2"
    local initrd_url="$3"
    local oem_config="$4"

    local coreos_path="${dst}/coreos"

    mkdir -p ${coreos_path}
    if [ ! -e "${coreos_path}/vmlinuz" ]; then
        echo -n "-> Downloading CoreOS's kernel $(basename ${kernel_url}):  "
        download "${kernel_url}" "${coreos_path}/vmlinuz"
    else
        echo "-> CoreOS's kernel already downloaded."
    fi
    if [ ! -e "${coreos_path}/cpio.gz" ]; then
        echo -n "-> Downloading CoreOS's initrd $(basename ${kernel_url}):  "
        download "${initrd_url}" "${coreos_path}/cpio.gz"
    else
        echo "-> CoreOS's initrd already downloaded."
    fi
    if [ -e "${oem_config}" ]; then
        echo "-> Integrating OEM config ${oem_config} ..."
        mkdir -p "${coreos_path}/usr/share/oem"
        cp "${oem_config}" "${coreos_path}/$(basename ${oem_config})"
        cp "${oem_config}" "${coreos_path}/usr/share/oem/cloud-config.yml"
        cd "${coreos_path}" && gzip -d cpio.gz && find usr | cpio -o -A -H newc -O cpio && gzip cpio
        rm -rf "${coreos_path}/usr"
        echo "-> Setting RO attribute to ${oem_config} ..."
        sudo chattr +i "${coreos_path}/$(basename ${oem_config})"
    else
        echo "-> Skipping OEM config."
    fi
}


make_dev() {
    local dst="$1"
    local syslinux="$2"
    local size="$3"
    local img="$4"

    local device
    local label="COREOS"
    local sysl_path="${dst}/syslinux"

    echo "-> Creating base image ${img} with dd ..."
    dd if=/dev/zero of="${img}" bs=1M count=${size} 2>/dev/null
    echo "-> Associating ${img} with a loop device ..."
    device=$(sudo losetup --show -f "${img}")
    echo "-> Creating partitions on ${device} ..."
    sudo parted -a optimal -s ${device} mklabel msdos -- mkpart primary fat32 1 -1
    sudo parted -s ${device} set 1 boot on
    echo "-> Writing syslinux MBR on ${device} ..."
    sudo dd bs=440 count=1 conv=notrunc if="${syslinux}/bios/mbr/mbr.bin" of=${device} 2>/dev/null
    echo "-> Creating FAT partition and fs on ${device} ..."
    sudo mkfs -t vfat -F 32 -n "${label}" ${device}p1 >/dev/null
    echo "-> Mounting ${device}p1 on $(basename ${dst}) ..."
    sudo mount -t vfat -o loop,uid=$(id -u $USER) ${device}p1 "${dst}"
    echo "-> Installing syslinux (extlinux) ..."
    sudo mkdir -p "${sysl_path}"
    sudo "${syslinux}"/bios/extlinux/extlinux --install "${sysl_path}" 2>/dev/null
}


set_confiles() {
    local dst="$1"
    local init="$2"
    local files="$3"
    local autologin="$4"
    local key="$5"
    local installer="$6"
    local autoinstaller="$7"

    local sshkey=""
    local alogin=""
    local cloudconfig="/$(basename ${init})"

    echo "-> Copying live configuration files ..."
    cp -a "${init}" "${dst}/"
    if [ ! -z ${files} ]; then
        for f in ${files}; do
            cp "$f" "${dst}/"
        done
    fi
    [ ! -z "${key}" ] && sshkey="sshkey=\"${key}\""
    [ ! -z "${autologin}" ] && [ "${autologin}" == "1" ] && alogin="coreos.autologin"
    echo "-> Creating main syslinux.cfg file ..."
    if [ ! -z "${installer}" ]; then
        [ ! -z "${autoinstaller}" ] && [ "${autoinstaller}" == "1" ] && cloudconfig="/$(basename ${installer})"
        cp -a "${installer}" "${dst}/"
    fi
    cat <<EOF > "${dst}/syslinux.cfg"
LABEL coreos
    MENU LABEL Run CoreOS
    KERNEL /coreos/vmlinuz
    APPEND initrd=/coreos/cpio.gz root=squashfs: state=tmpfs: ${alogin} ${sshkey} cloud-config-url=${cloudconfig}
    TEXT HELP
CoreOS is Linux distribution rearchitected to provide features to run
modern infrastructure stacks.
    ENDTEXT
EOF
    if [ ! -z "${installer}" ] && [ "${autoinstaller}" != "1" ]; then
        echo "-> Defining install on syslinux.cfg file ..."
        cat <<EOF >> "${dst}/syslinux.cfg"
LABEL coreosinstall
    MENU LABEL Automatically Install Coreos
    KERNEL /coreos/vmlinuz
    APPEND initrd=/coreos/cpio.gz root=squashfs: state=tmpfs: ${sshkey} cloud-config-url=/$(basename ${installer})
    TEXT HELP
Warning!!: Automatically installs CoreOS on your system and reboots!
    ENDTEXT
EOF
    fi
}


set_syslinux() {
    local dst="$1"
    local syslinux="$2"
    local syslinux_url="$3"
    local memtest_url="$4"
    local pciid_url="$5"

    local sysl_path="${dst}/syslinux"
    local memtest_path="${dst}/memtest"

    mkdir -p "${sysl_path}"
    echo "-> Copying syslinux files and modules ..."
    cp "${syslinux}"/bios/com32/chain/*.c32 "${sysl_path}"
    cp "${syslinux}"/bios/com32/lib/*.c32 "${sysl_path}"
    cp "${syslinux}"/bios/com32/libutil/*.c32 "${sysl_path}"
    cp "${syslinux}"/bios/com32/elflink/ldlinux/ldlinux.c32 "${sysl_path}"
    cp "${syslinux}"/bios/com32/gpllib/*.c32 "${sysl_path}"
    cp "${syslinux}"/bios/com32/menu/*.c32 "${sysl_path}"
    cp "${syslinux}"/bios/com32/cmenu/complex.c32 "${sysl_path}"
    cp "${syslinux}"/bios/com32/cmenu/display.c32 "${sysl_path}"
    cp "${syslinux}"/bios/com32/cmenu/libmenu/*.c32 "${sysl_path}"
    cp "${syslinux}"/bios/com32/gfxboot/*.c32 "${sysl_path}"
    cp "${syslinux}"/bios/com32/hdt/*.c32 "${sysl_path}"
    cp "${syslinux}"/bios/com32/lua/src/*.c32 "${sysl_path}"
    cp "${syslinux}"/bios/com32/mboot/*.c32 "${sysl_path}"
    cp "${syslinux}"/bios/com32/modules/*.c32 "${sysl_path}"
    cp "${syslinux}"/bios/com32/rosh/*.c32 "${sysl_path}"
    cp "${syslinux}"/bios/com32/sysdump/*.c32 "${sysl_path}"
    cp "${syslinux}"/bios/memdisk/memdisk "${sysl_path}"
    cp "${syslinux}"/bios/core/isolinux.bin "${sysl_path}"
    echo -n "-> Downloading $(basename ${memtest_url}) :  "
    mkdir -p "${memtest_path}"
    cd "${memtest_path}"
    download "${memtest_url}"
    gzip -d --stdout "$(basename ${memtest_url})" > memtest.bin
    rm -f "$(basename ${memtest_url})"
    cd "${sysl_path}"
    echo -n "-> Downloading pci.ids definition file for hdt :  "
    download "${pciid_url}" "pci.ids"
    cd "${sysl_path}"
    echo "-> Creating default syslinux.cfg configuration file ..."
    cat <<"EOF" > "${sysl_path}/syslinux.cfg"
SERIAL 0 38400
UI vesamenu.c32
MENU TITLE Coreos Boot Menu
MENU BACKGROUND /splash.png
TIMEOUT 600
PROMPT 0
ONTIMEOUT coreos
DEFAULT coreos

MENU WIDTH 		78
MENU MARGIN 		4
MENU ROWS 		6
MENU VSHIFT 		10
MENU TABMSGROW 		14
MENU CMDLINEROW 	14
MENU HELPMSGROW 	16
MENU HELPMSGENDROW 	29

MENU COLOR border       30;44   #40ffffff #a0000000 std
MENU COLOR title        1;36;44 #9033ccff #a0000000 std
MENU COLOR sel          7;37;40 #e0ffffff #20ffffff all
MENU COLOR unsel        37;44   #50ffffff #a0000000 std
MENU COLOR help         37;40   #c0ffffff #a0000000 std
MENU COLOR timeout_msg  37;40   #80ffffff #00000000 std
MENU COLOR timeout      1;37;40 #c0ffffff #00000000 std
MENU COLOR msg07        37;40   #90ffffff #a0000000 std
MENU COLOR tabmsg       31;40   #30ffffff #00000000 std

# include coreos
INCLUDE /syslinux.cfg

LABEL bootlocal
    MENU LABEL Boot first BIOS disk
    localboot 0x80
    TEXT HELP
Boot the operating system from the first bios disk.
    ENDTEXT

LABEL hdt
    MENU LABEL Hardware Detection Tool
    COM32 hdt.c32 
    APPEND pciids=pci.ids
    TEXT HELP
HDT (Hardware Detection Tool) displays hardware low-level information.
    ENDTEXT

LABEL memtest
    MENU LABEL Memtest86+
    LINUX ../memtest/memtest.bin
    TEXT HELP
Memtest86+ checks RAM for errors by doing stress tests operations.
    ENDTEXT

LABEL reboot
    MENU LABEL Reboot
    COM32 reboot.c32
 
LABEL poweroff
    MENU LABEL Power Off
    COM32 poweroff.c32
EOF
}


make_iso() {
    local dst="$1"
    local syslinux="$2"
    local output="$3"

    echo -n "-> Making hybrid ISO image $(basename ${output}) ... "
    cd "${dst}"
    mkisofs -quiet -l -r -J -input-charset utf-8 -o "${output}" \
            -b syslinux/isolinux.bin -c syslinux/boot.cat \
            -no-emul-boot -boot-load-size 4 -boot-info-table .
    ${syslinux}/bios/utils/isohybrid "${output}"
    echo "done"
}


start() {
    local dst="$1"
    local syslinux="$2"
    local syslinux_url="$3"

    if [ ! -e "${syslinux}" ]; then
        echo -n "-> Downloading $(basename ${syslinux_url}):  "
        cd $(dirname "${syslinux}")
        download "${syslinux_url}" "${syslinux}.tar.gz"
        tar zxf "${syslinux}.tar.gz" 
    fi
    echo "-> Creating ${dst} ..."
    mkdir -p "${dst}"
}


finish() {
    local dst="$1"
    local syslinux="$2"
    local img="$3"

    local device

    cd "$PROGRAM_DIR"
    if mount | grep -q $(basename "${dst}"); then
        echo "-> Umounting temporary mountpoint $(basename ${dst}) ..."
        sync && sleep 1
        sudo umount "${dst}"
        device=$(sudo losetup --show -f "${img}")
        echo "-> Disassociating ${img} with the loop device ${device} ..."
        sudo losetup -d ${device}
    fi
    echo "-> Removing temporary folder $(basename ${dst}) ..."
    rm -rf "${dst}"
}


###############
# Main Program
OPTIND=1
FILES=""
OUT=""
while getopts "haus:v:l:i:o:k:p:-:" optchar; do
    case "${optchar}" in
        -)
            # long options
            case "${OPTARG}" in
                help)
                    usage
                    exit 0
                ;;
                type)
                  eval IMG_TYPE="\$${OPTIND}"
                  OPTIND=$(($OPTIND + 1))
                ;;
                size)
                  eval IMG_SIZE="\$${OPTIND}"
                  OPTIND=$(($OPTIND + 1))
                ;;
                coreosversion)
                  eval COREOS_VERSION="\$${OPTIND}"
                  OPTIND=$(($OPTIND + 1))
                ;;
                syslinuxversion)
                  eval SYSLINUX_VERSION="\$${OPTIND}"
                  OPTIND=$(($OPTIND + 1))
                ;;
                oemcloudconfig)
                  eval OEM_CLOUD_CONFIG="\$${OPTIND}"
                  OPTIND=$(($OPTIND + 1))
                ;;
                initcloudconfig)
                  eval INIT_SCRIPT="\$${OPTIND}"
                  OPTIND=$(($OPTIND + 1))
                ;;
                output)
                  eval OUT="\$${OPTIND}"
                  OPTIND=$(($OPTIND + 1))
                ;;
                sshkey)
                  eval sshkeyfile="\$${OPTIND}"
                  SSHKEY=$([ -f "${sshkeyfile}" ] && cat "${sshkeyfile}")
                  OPTIND=$(($OPTIND + 1))
                ;;
                provcloudconfig)
                  eval INSTALL_SCRIPT="\$${OPTIND}"
                  OPTIND=$(($OPTIND + 1))
                ;;
                autoinstall)
		  AUTOINSTALL=1
                ;;
                autologin)
		  AUTOLOGIN=1
                ;;
                usb)
		  IMG_TYPE="IMG"
                ;;
                *)
                    echo "Unknown arg: ${OPTARG}"
		    exit 1
                ;;
            esac
        ;;
        h)
            usage
            exit 0
        ;;
        s)
            IMG_SIZE=$OPTARG
        ;;
        v)
            COREOS_VERSION=$OPTARG
        ;;
        l)
            SYSLINUX_VERSION=$OPTARG
        ;;
        i)
            INIT_SCRIPT=$OPTARG
        ;;
        o)
            OUT=$OPTARG
        ;;
        k)
            SSHKEY=$([ -f "$OPTARG" ] && cat "$OPTARG")
        ;;
        p)
            INSTALL_SCRIPT=$OPTARG
        ;;
        a)
            AUTOLOGIN=1
        ;;
        u)
            IMG_TYPE="IMG"
        ;;
    esac
done
shift $((OPTIND-1)) # Shift off the options and optional --.

PCIID_URL="http://pciids.sourceforge.net/v2.2/pci.ids"
SYSLINUX_BASE_URL="https://www.kernel.org/pub/linux/utils/boot/syslinux"
SYSLINUX_BASENAME="syslinux-${SYSLINUX_VERSION}"
SYSLINUX_URL="${SYSLINUX_BASE_URL}/${SYSLINUX_BASENAME}.tar.gz"
MEMTEST_BASE_URL="http://www.memtest.org/download"
MEMTEST_URL="${MEMTEST_BASE_URL}/${MEMTEST_VERSION}/memtest86+-${MEMTEST_VERSION}.bin.gz"
COREOS_BASE_URL="http://storage.core-os.net/coreos/amd64-generic"
COREOS_KERN_BASENAME="coreos_production_pxe.vmlinuz"
COREOS_INITRD_BASENAME="coreos_production_pxe_image.cpio.gz"
COREOS_KERN_URL="${COREOS_BASE_URL}/${COREOS_VERSION}/${COREOS_KERN_BASENAME}"
COREOS_INITRD_URL="${COREOS_BASE_URL}/${COREOS_VERSION}/${COREOS_INITRD_BASENAME}"

for f in "$@"; do
    [ -f "${PROGRAM_DIR}/${f}" ] && f="${PROGRAM_DIR}/${f}"
    [ -f "${f}" ] && FILES="${FILES} ${f}" || echo "-> Skipping ${f}: not found!"
done
[ -z ${OUT} ] && OUT="${PROGRAM_DIR}/coreos-${COREOS_VERSION}"
DST=$(cd `dirname "${OUT}"` && pwd)/$(basename ${OUT})_$$

SYSLINUX_BASENAME="${PROGRAM_DIR}/${SYSLINUX_BASENAME}"
[ ! -z "${INSTALL_SCRIPT}" ] && [ -f "${INSTALL_SCRIPT}" ] && INSTALL_SCRIPT="${PROGRAM_DIR}/${INSTALL_SCRIPT}"
[ ! -z "${INSTALL_SCRIPT}" ] && [ ! -f "${INSTALL_SCRIPT}" ] && INSTALL_SCRIPT="" && echo "-> Skipping INSTALL script: not found!"

# create folder and download syslinux
start "${DST}" "${SYSLINUX_BASENAME}" "${SYSLINUX_URL}"

# if IMG: create device, partitions, fs and install syslinux
[ "${IMG_TYPE}" == "IMG" ] && make_dev "${DST}" "${SYSLINUX_BASENAME}" ${IMG_SIZE} "${OUT}.img"

# setup syslinux files and modules
set_syslinux "${DST}" "${SYSLINUX_BASENAME}" "${SYSLINUX_URL}" "${MEMTEST_URL}" "${PCIID_URL}"

# download coreos img and initrd
OEM="" && [ ! -z "${OEM_CLOUD_CONFIG}" ] && [ -e "${OEM_CLOUD_CONFIG}" ] && OEM="${PROGRAM_DIR}/${OEM_CLOUD_CONFIG}"
get_coreos "${DST}" "${COREOS_KERN_URL}" "${COREOS_INITRD_URL}" "${OEM}"

# copy files: cloud-config and syslinux.cfg
set_confiles "${DST}" "${PROGRAM_DIR}/${INIT_SCRIPT}" "${FILES}" ${AUTOLOGIN} "${SSHKEY}" "${INSTALL_SCRIPT}" "${AUTOINSTALL}"

# if ISO: create iso
[ "${IMG_TYPE}" == "ISO" ] && make_iso "${DST}" "${SYSLINUX_BASENAME}" "${OUT}.iso"

# umount and delete folders
finish "${DST}" "${SYSLINUX_BASENAME}" "${OUT}.img"

[ "${AUTOINSTALL}" == "1" ] && echo -e "\n-> WARNING this image is like a virus!. Be careful, it is autoinstallable!\n" 

# EOF
