#!/usr/bin/env bash
#
# $Id: template.sh,v 1.1 2019/11/15 08:34:48 murdoc Exp $
#
# This script will be run at the very beginning of the initialization of the new container, even before any custom packages will be installed.
#
# Author: patrick@kirchhoffs.de
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
