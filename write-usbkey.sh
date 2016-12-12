#!/usr/bin/env sh
NODE=core-1
DOMAIN=drewfus.org
HOSTNAME=$NODE.$DOMAIN
DISK=disk4
diskutil unmountDisk /dev/$DISK
dd bs=1m if=out/$HOSTNAME.iso of=/dev/r$DISK
diskutil eject /dev/$DISK

