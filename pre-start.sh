#!/usr/bin/env bash
#
# $Id: template.sh,v 1.1 2019/11/15 08:34:48 murdoc Exp $
#
# This script will be run every time the container starts,
# even before the FHEM Docker Image's own startup preparations.
# FHEM will not yet be running at this point in time.
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

exit 0
