# Home Automation Stack

## Requirements

+ docker
+ docker-compose

## Installation raspberrypi

### System Update
      sudo apt-get update
      sudo apt-get upgrade

### Raspberry Config

      sudo raspi-config
      sudo reboot

### Intall additional packages

      sudo apt-get install wget git apt-transport-https vim telnet

### Install docker

      curl -sSL https://get.docker.com | sh
      sudo systemctl enable docker
      sudo systemctl start docker
      sudo usermod -aG docker pi

### git repository export
      cd
      git clone https://github.com/stormmurdoc/fhemdocker.git
      cd fhemdocker

### Installation docker compose

      sudo apt-get install python-pip
      sudo pip install docker-compose

### ctop

#### Description

ctop is a commandline monitoring tool for linux containers

!["ctop"](./.media/ctop.png "ctop gui")

#### Installation

ctop is available in [AUR](https://aur.archlinux.org/packages/ctop/), so you can install it using AUR helpers, such as YaY, in Arch Linux and its variants such as Antergos and Manjaro Linux.

#### Installation Linux

      sudo wget https://github.com/bcicen/ctop/releases/download/v0.7.3/ctop-0.7.3-linux-amd64 -O /usr/local/bin/ctop
      sudo chmod +x /usr/local/bin/ctop
