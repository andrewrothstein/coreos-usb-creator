#!/usr/bin/env sh
docker pull ubuntu:latest
docker build -t coreos-usb-creator .
