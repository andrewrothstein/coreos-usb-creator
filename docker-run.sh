#!/usr/bin/env bash
set -xe

echo rewrite the image if necessary...
./docker-build.sh
echo done

OUTPUT_DIR=out
echo writing generated USB images to $OUTPUT_DIR...
mkdir -p $OUTPUT_DIR

function write-image() {
    local NODE=$1 #core-1
    local DOMAIN=$2 #drewfus.org
    local HOSTNAME=$NODE.$DOMAIN # core-1.drewfus.org
    echo building image for $HOSTNAME...
    rm -f out/$HOSTNAME.{iso,img}
    docker run --rm -it \
	   -v $HOME/.ssh:$HOME/.ssh \
	   -v $(pwd)/$OUTPUT_DIR:/$OUTPUT_DIR \
	   coreos-usb-creator \
	   --autologin \
	   --coreoschannel stable \
	   --cloudconfig cloud-inits/$DOMAIN/$NODE.yml \
	   -o $HOSTNAME
    echo done!
}

function write-images() {
    local DOMAIN=$1
    echo writing images for $DOMAIN...
#    write-image core-1 $DOMAIN
#    write-image core-2 $DOMAIN
    write-image core-3 $DOMAIN
    echo done writing images for $DOMAIN!
}


write-images drewfus.org
