FROM ubuntu:latest

MAINTAINER Michal Příhoda <michal@prihoda.net>

ENV DEBIAN_FRONTEND=noninteractive
RUN dpkg --add-architecture i386 && \
    apt-get update -y && \
    apt-get upgrade -y && \
    apt-get install \
    	    -y --no-install-recommends \
            ca-certificates \
	    wget \
	    parted \
	    dosfstools \
	    kpartx \
            genisoimage \
	    cpio \
	    libc6:i386 \
	    libuuid1:i386

VOLUME /out
ADD . /opt/coreos-usb-creator
WORKDIR /opt/coreos-usb-creator
ENTRYPOINT ["/opt/coreos-usb-creator/mkimg.sh"]
