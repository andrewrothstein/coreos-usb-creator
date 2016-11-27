#!/usr/bin/env sh
DISK=disk4
diskutil unmountDisk /dev/$DISK
dd if=out/usbkey.drewfus.org.iso of=/dev/r$DISK
diskutil eject /dev/$DISK

