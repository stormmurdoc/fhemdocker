# Home Automation Stack

!["FHEM GUI"](./.media/fhem.png "FHEM gui")
The stack contains everything to run FHEM on a Docker host. Mosquitto is used as message broker. SIRI functions are realized with the help of a homebridge container. The complete stack runs on x86 as well as arm architectures. It is very easy to clone its complete productive environment and has a simple way to build a test system.

## Todo

+ [deCONZ Image](https://hub.docker.com/r/marthoc/deconz/) Container Integration
+ DBLog Integration

## Requirements

+ docker
+ docker-compose

## Installation raspberrypi

### Raspian Download

Download the image of your choise: [Raspian Download](https://www.raspberrypi.org/downloads/raspbian/)
Unzip the image and install it with:

      sudo dd bs=4M if=2019-09-26-raspbian-buster-full.img of=/dev/mmcblk0 conv=fsync
      sync

Eject the card and insert it again to mount the filesystems boot & rootfs.
Touch a blank file ssh to enable sshd daemon on first boot.

      sudo touch /media/boot/ssh
      sync
      umount /media/boot
      umount /medua/rootfs

Eject the card and insert into your raspberrpi. After that power on the rpi and login with
the known user __pi__ and password __raspberry__.

      ssh pi@raspberrypi4

Change your password with the command

      pi@raspberrypi:~ $ passwd
      Changing password for pi.
      Current password:
      New password:
      Retype new password:
      passwd: password updated successfully
      pi@raspberrypi:~ $



### System Update

      sudo apt-get update
      sudo apt-get dist-upgrade


### Set timezone

      sudo dpkg-reconfigure tzdata

### Raspberry Config

1) Expand the root filesystem (A1 / Advanced Options)
2) Update raspi-config

      sudo raspi-config
      sudo reboot

### Intall additional packages

      sudo apt-get install wget git apt-transport-https vim telnet zsh zsh-autosuggestions zsh-syntax-highlighting

### Install oh-my-zsh

      sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
### Install docker & docker-compose

After installation put your user pi into the docker group.

      #curl -sSL https://get.docker.com | sh
      #sudo systemctl enable docker
      #sudo systemctl start docker
      sudo apt-get install docker docker-compose
      sudo usermod -aG docker pi
      sudo reboot

### git repository export and start all container

      cd
      git clone https://github.com/stormmurdoc/fhemdocker.git
      cd fhemdocker
      docker-compose up

## Container

### Tasmota Admin

!["tasmotaadmin"](./.media/tasmotaadmin.png "Tasmota Admin Screenshot")

### Tasmota Compiler

!["tasmotacompiler"](./.media/tasmotacompiler.png "Tasmota Compiler Screenshot")

### Homebridge

!["homebridge"](./.media/homebridge.png "Homebridge Screenshot")

### Portainer

!["portainer"](./.media/portainer.png "Portainer Screenshot")


## ctop

### Description

ctop is a commandline monitoring tool for linux containers

!["ctop"](./.media/ctop.png "ctop gui")

### Installation

ctop is available in [AUR](https://aur.archlinux.org/packages/ctop/), so you can install it using AUR helpers, such as YaY, in Arch Linux and its variants such as Antergos and Manjaro Linux.

### Installation Linux

#### x86 Platform
      sudo wget https://github.com/bcicen/ctop/releases/download/v0.7.3/ctop-0.7.3-linux-amd64 -O /usr/local/bin/ctop
      sudo chmod +x /usr/local/bin/ctop

#### arm Platform
      sudo wget https://github.com/bcicen/ctop/releases/download/v0.7.3/ctop-0.7.3-linux-arm -O /usr/local/bin/ctop
      sudo chmod +x /usr/local/bin/ctop
