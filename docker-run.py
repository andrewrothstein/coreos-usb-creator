#!/usr/bin/env bash
set -xe

#rewrite the image if necessary
./docker-build.sh

#where to put the generated USB images...
OUTPUT_DIR=out
mkdir -p $OUTPUT_DIR

function write-image {
    NODE=$1 #core-1
    DOMAIN=$2 #drewfus.org
    HOSTNAME=$NODE.$DOMAIN
    rm -f out/$HOSTNAME.iso
    docker run --rm -it \
	   -v $HOME/.ssh:$HOME/.ssh \
	   -v $(pwd)/$OUTPUT_DIR:/$OUTPUT_DIR \
	   coreos-usb-creator \
	   --autologin \
	   --coreoschannel stable \
	   --cloudconfig $DOMAIN/$NODE.yml \
	   -o /$OUTPUT_DIR/$HOSTNAME
}

DOMAIN=drewfus.org
write-image core-1 $DOMAIN
write-image core-2 $DOMAIN
write-image core-3 $DOMAIN

       
