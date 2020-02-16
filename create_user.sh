#!/usr/bin/env bash
#
# Description: Add user & group for mosquitto broker
#
# Author: murdoc@storm-clan.de
#
# Configuration file: none
#
# Parameters: none
#


#
# get the OS id
#
OS=$(awk '/^ID=/' /etc/*-release | sed 's/ID=//' | tr '[:upper:]' '[:lower]')

#
# Function for Arch Linux
env_arch() {
   echo "arch"
   useradd -u 1883 -M -s /sbin/nologin mosquitto
   useradd -u 101 -M -s /sbin/nologin nginx
}

#
# Function for Raspian
#
env_raspbian() {
   echo "raspbian"
   addgroup -S -g 1883 mosquitto
}

#
# I'm root?
#
if [ "$EUID" -ne 0 ]
then echo "Please run as root or with sudo $(basename $0)"
  exit
fi

#
# Depending on the OS
#
case "$OS" in
   arch) env_arch ;;
   raspbian) env_raspbian ;;
   *) echo "unknown os - exiting" ; exit 1 ;;
esac
