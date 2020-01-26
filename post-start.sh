#!/usr/bin/env bash
#
# This script will be run every time the container starts
# and after the FHEM process was already started.
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

exit 0
