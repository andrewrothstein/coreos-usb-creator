#!/usr/bin/env sh
set -xe
./docker-build.sh
mkdir -p out/
rm -f out/usbkey.drewfus.org.iso
docker run --rm -it \
       -v $HOME/.ssh:$HOME/.ssh \
       -v $(pwd)/out:/out \
       coreos-usb-creator \
       --coreoschannel stable \
       --cloudconfigurl https://raw.githubusercontent.com/andrewrothstein/drewfus-org-cloud-inits/master/drewfus.org/usbkey.yml \
       -o /out/usbkey.drewfus.org

       
