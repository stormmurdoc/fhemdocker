#!/usr/bin/env sh
#
# Description
#
# Author: murdoc@storm-clan.de
#
# Configuration file: none
#
# Parameters: none
#

# Stoping all docker containers
docker-compose down

# Deleting all containers
docker rm $(docker ps -a -q)

# Deleting all images
docker rmi $(docker images -q)
