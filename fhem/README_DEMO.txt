Prerequisite:
  - perl
  - stop any existing FHEM process first (if started any).

HOWTO:
  Start FHEM with a demo configuration with 
    perl fhem.pl fhem.cfg.demo
  (typed in a terminal) and point your browser to http://YourFhemHost:8083
  Use the startfhemDemo skript on the FritzBox.
  If you'd like to see the RSS demo, you have to install the Perl GD library,
  e.g. with:
    sudo apt-get install libgd-gd2-perl
    sudo apt-get install libgd-text-perl

Stopping:
  - type shutdown in the browser command window, followed by RETURN
  or
  - type CTRL-C in the terminal window

This demo:
- it won't overwrite any settings in the productive FHEM installation
- it uses its own log-directory (demolog) and configfile (fhem.cfg.demo)
- it won't start in the background, the FHEM-log is written to the terminal
- it won't touch any home-automation hardware (CUL, ZWawe dongle, etc) attached
  to the host.
