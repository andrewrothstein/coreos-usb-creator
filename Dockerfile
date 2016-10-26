FROM ubuntu:latest

MAINTAINER Michal Příhoda <michal@prihoda.net>

RUN dpkg --add-architecture i386

RUN dpkg --add-architecture i386 && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates wget parted dosfstools kpartx \
        genisoimage cpio libc6:i386 libuuid1:i386

RUN mkdir /opt/coreos-usb-creator /out

WORKDIR /opt/coreos-usb-creator

ADD * ./

VOLUME /out

ENTRYPOINT ["./mkimg.sh"]
