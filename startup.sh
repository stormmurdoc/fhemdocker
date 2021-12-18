#!/usr/bin/env bash
#
# Description: Setup the environment and start the Docker stack
#
# Author: murdoc@storm-clan.de
#
# Configuration file: none
#
# Parameters: none
#

SCRIPT=$(basename "$0")

echo "+++ $SCRIPT started +++"

# setup access rights
echo "+++ Setup access rights +++"
chmod -R 755 ./reverseproxy

echo "+++ Starting docker-compose +++"
docker-compose up -d
echo "+++ $SCRIPT ended +++"
