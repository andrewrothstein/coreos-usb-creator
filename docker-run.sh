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

NODE=${NODE:-core-1}
DOMAIN=${DOMAIN:-drewfus.org}
write-image $NODE $DOMAIN
