#!/usr/bin/env python
import os
import logging
from subprocess import check_call

def make_iso(dst, syslinux, label, output):
    log = logging.getLogger("coreos-usb-creator.make_iso")
    log.info("Making hybrid ISO image %s in %s...", os.path.basename(output), dst))
    os.chdir(dst)
    check_call(["genisoimage",
                "-V", label,
                "-quiet", "-l", "-r", "-J",
                "-input-charset", "utf-8",
                "-o", output,
                "-b", "syslinux/isolinux.bin",
                "-c", "syslinux/boot.cat",
                "-no-emul-boot",
                "-boot-load-size", "4",
                "-boot-info-table", "."])
    log.info("done")

def start(dst, syslinux, syslinux_url):
    log = logging.getLogger("coreos-usb-creater.start")
    log.info("Downloading %s...", os.path.basename(syslinux_url))
    os.chdir(os.path.dirname(syslinux))
    archive = syslinux + ".tar.gz"
    download(syslinux_url, archive)
    log.info("Unarchiving %s...", archive)
    check_call(["tar", "zxvf", archive])
    log.info("done")

def is_mounted(dst):
    
    
def finish(dst, syslinux, img):
    
    
