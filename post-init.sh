#!/usr/bin/env bash
#
# $Id: template.sh,v 1.1 2019/11/15 08:34:48 murdoc Exp $
#
# This script will be run at the very end of the initialization
# of the new container, also after your local FHEM configuration
# was checked and adjusted for compatibility with the container.
# Custom packages you defined using the environment variables
# mentioned above will be installed already at this point in time.
# This is likely the best place for you to do any final changes
# to the environment that need to be done only once for the
# lifetime of that container.
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

exit 0
