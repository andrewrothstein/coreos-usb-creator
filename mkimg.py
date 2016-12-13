#!/usr/bin/env python3
import os
import logging
from subprocess import check_call
import argparse
import urllib

parser = argparse.ArgumentParser(description='CoreOS image builder')

parser.add_argument('--syslinux-version', default='6.03', help='syslinux version')
parser.add_argument('--syslinux-base-url',
                    default='https://www.kernel.org/pub/linux/utils/boot/syslinux')

parser.add_argument('--coreos-version', default='current', help='CoreOS version')
parser.add_argument('--coreos-channel', default='stable', help='CoreOS channel')
parser.add_argument('--coreos-kern-basename', default='coreos_production_pxe.vmlinuz')
parser.add_argument('--coreos-initrd-basename', default='coreos_production_pxe_image.cpio.gz')

parser.add_argument('--memtest-version', default='5.01', help='MemTest version')
parser.add_argument('--memtest-base-url',
                    default='http://www.memtest.org/download')

parser.add_argument('s', '--img-size', type=int, default=1000, help='image size')
parser.add_argument('--img-type', default='ISO', help='image type (ISO or IMG)')
parser.add_argument('--auto-login', action=store_true, default=False,
                    help='automatically login the main console/terminal')
parser.add_argument('--init-script', default='cloud-config.yml', help='cloud configuration')
parser.add_argument('--oem-config', default='oem-config.yml', help='OEM configuration')

parser.add_argument('--vol-label', default='COREOS', help='volume label')
parser.add_argument('--backgroup-img', default='splash.png', help='background image')

parser.add_argument('--pciid-url', default='http://pciids.sourceforge.net/v2.2/pci.ids')

def download(url, dest) :
    log = logging.getLogger('coreos-usb-creator.download')
    log.info('downloading %s to %s...', url, dest)
    urllib.urlretrieve(url, dest)
    log.info('done')

def prepare_coreos(dest,
                   kernel_url,
                   initrd_url,
                   oem_config,
                   cconfig_file_in,
                   cconfig_file_vol_label) :
    log = logging.getLogger('coreos-usb-creator.prepare_coreos')
    coreos_path = dest + '/coreos'
    if (not os.path.isdir(coreos_path)):
        os.mkdirs(coreos_path)
        
    vmlinuz = coreos_path + '/vmlinuz'
    if (not os.path.exists(vmlinuz)):
        log.info('downloading kernel...')
        download(kernel_url, vmlinuz)
    else :
        log.info('kernel already downloaded')

    initrd = coreos_path + '/cpio.gz'
    if (not os.path.exists(initrd)):
        log.info('downloading initrd...')
        download(initrd_url, initrd)
    else :
        log.info('initrd already downloaded')

    if (os.path.exists(oem_config)):
        oem_config_dir = coreos_path + '/usr/share/oem'
        os.mkdirs(oem_config_dir)

def make_device(dst, syslinux, vol_label, size, img):
    sysl_path = dst + '/syslinux'
    check_call(['dd', 'if=/dev/zero', 'of=' + img, 'bs=1m', 'count=' + size])
    device = check_output(['losetup', '--show', '-f', img])
    check_call(['parted', '-a', 'optimal', '-s', device, 'mklabel', 'msdos', '--', 'mkpart', 'primary', 'fat32', '1', '-1'])
    check_call(['parted', '-s', device, 'set', '1', 'boot', 'on'])
    check_call(['dd',
                'bs=440',
                'count=1',
                'conv=notrunc',
                'if=' + syslinux + '/bios/mbr/mbr.bin',
                'of=' + device])
    check_call(['losetup', '-d', device])
    
                
        
def make_iso(dst, syslinux, label, output):
    log = logging.getLogger('coreos-usb-creator.make_iso')
    log.info('Making hybrid ISO image %s in %s...', os.path.basename(output), dst))
    os.chdir(dst)
    check_call(['genisoimage',
                '-V', label,
                '-quiet', '-l', '-r', '-J',
                '-input-charset', 'utf-8',
                '-o', output,
                '-b', 'syslinux/isolinux.bin',
                '-c', 'syslinux/boot.cat',
                '-no-emul-boot',
                '-boot-load-size', '4',
                '-boot-info-table', '.'])
    log.info('done')

def start(dst, syslinux, syslinux_url):
    log = logging.getLogger('coreos-usb-creater.start')
    log.info('Downloading %s...', os.path.basename(syslinux_url))
    os.chdir(os.path.dirname(syslinux))
    archive = syslinux + '.tar.gz'
    download(syslinux_url, archive)
    log.info('Unarchiving %s...', archive)
    check_call(['tar', 'zxvf', archive])
    log.info('done')

def is_mounted(dst):
    
    
def finish(dst, syslinux, img):
    
    
