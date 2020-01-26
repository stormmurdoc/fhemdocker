#!/usr/bin/env bash
#
# This script will be run at the very beginning of the initialization of the new container, even before any custom packages will be installed.
#
# Author: murdoc@storm-clan.de
#
# Configuration file: none
#
# Parameters: none
#
SCRIPTNAME=$(basename $0)
USERNAME=$(whoami)

echo "+++ $SCRIPTNAME (USER/ID: $USERNAME/$UID) started +++"
echo "+++ starting ssh daemon +++"
/etc/init.d/ssh start

echo "+++ upgrade Debian system +++"
apt-get update && apt-get dist-upgrade -y
exit 0
