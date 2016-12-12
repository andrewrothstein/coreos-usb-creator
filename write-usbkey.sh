#!/usr/bin/env sh
DISK=${DISK:-disk4}
NODE=${NODE:-core-1}
DOMAIN=${DOMAIN:-drewfus.org}
HOSTNAME=$NODE.$DOMAIN
echo writing image for $HOSTNAME to /dev/$DISK...
diskutil unmountDisk /dev/$DISK
dd bs=1m if=out/$HOSTNAME.iso of=/dev/r$DISK
diskutil eject /dev/$DISK
echo done!
