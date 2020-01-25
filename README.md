# House Automation Stack

## Installation raspberrypi


      sudo apt-get update
      sudo apt-get upgrade

      sudo raspi-config
      sudo reboot

      sudo apt-get install wget git apt-transport-https vim telnet

      curl -sSL https://get.docker.com | sh
      sudo systemctl enable docker
      sudo systemctl start docker
      sudo usermod -aG docker pi

      cd
      git clone -b raspbian https://github.com/klein0r/fhem-docker.git fhem-docker
      cd fhem-docker

      sudo apt-get install python-pip
      sudo pip install docker-compose

### ctop

#### Description

ctop is a commandline monitoring tool for linux containers

!["ctop"](./.media/ctop.png "ctop gui")

#### Installation

ctop is available in [AUR](https://aur.archlinux.org/packages/ctop/), so you can install it using AUR helpers, such as YaY, in Arch Linux and its variants such as Antergos and Manjaro Linux.
