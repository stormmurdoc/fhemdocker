#!/usr/bin/env bash
#
# This script will be run every time the container starts,
# even before the FHEM Docker Image's own startup preparations.
# FHEM will not yet be running at this point in time.
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
