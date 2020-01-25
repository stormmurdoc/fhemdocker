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


![ctop](./media/ctop.png "ctop gui")
