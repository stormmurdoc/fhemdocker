#!/usr/bin/env sh
#
# Description: send FHEM command via ssh to the local telnet daemon
#
# Configuration file: none
#
# Parameters: $1 : FHEM Command
#

# shellcheck disable=SC2145
ssh 2>/dev/null pi@raspberrypi4 -n "echo $@ | docker exec --interactive fhem_fhem socat -t50 - TCP:localhost:7072"
