########################################################################################
#
# $Id: 20_FRM_AD.pm 15932 2018-01-19 21:19:00Z jensb $
#
# FHEM module for one Firmata analog input pin
#
########################################################################################
#
#  LICENSE AND COPYRIGHT
#
#  Copyright (C) 2013 ntruchess
#  Copyright (C) 2016 jensb
#
#  All rights reserved
#
#  This script is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  The GNU General Public License can be found at
#  http://www.gnu.org/copyleft/gpl.html.
#  A copy is found in the textfile GPL.txt and important notices to the license
#  from the author is found in LICENSE.txt distributed with these scripts.
#
#  This script is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#  GNU General Public License for more details.
#
#  This copyright notice MUST APPEAR in all copies of the script!
#
########################################################################################

package main;

use strict;
use warnings;

#add FHEM/lib to @INC if it's not allready included. Should rather be in fhem.pl than here though...
BEGIN {
	if (!grep(/FHEM\/lib$/,@INC)) {
		foreach my $inc (grep(/FHEM$/,@INC)) {
			push @INC,$inc."/lib";
		};
	};
};

use Device::Firmata::Constants  qw/ :all /;

#####################################

my %gets = (
  "reading" => "",
  "state"   => "",
  "alarm-upper-threshold"   => "off",
  "alarm-lower-threshold"   => "off",
);

sub
FRM_AD_Initialize($)
{
  my ($hash) = @_;

  $hash->{AttrFn}    = "FRM_AD_Attr";
  $hash->{GetFn}     = "FRM_AD_Get";
  $hash->{DefFn}     = "FRM_Client_Define";
  $hash->{InitFn}    = "FRM_AD_Init";
  
  $hash->{AttrList}  = "IODev upper-threshold lower-threshold $main::readingFnAttributes";
  main::LoadModule("FRM");
}

sub
FRM_AD_Init($$)
{
	my ($hash,$args) = @_;
	my $ret = FRM_Init_Pin_Client($hash,$args,PIN_ANALOG);
	return $ret if (defined $ret);
	my $firmata = $hash->{IODev}->{FirmataDevice};
	my $name = $hash->{NAME};
	my $resolution = 10;
	if (defined $firmata->{metadata}{analog_resolutions}) {
		$resolution = $firmata->{metadata}{analog_resolutions}{$hash->{PIN}} 
	}
	$hash->{resolution} = $resolution;
	$hash->{".max"} = defined $resolution ? (1<<$resolution)-1 : 1024;
	eval {
		$firmata->observe_analog($hash->{PIN},\&FRM_AD_observer,$hash);
	};
	return FRM_Catch($@) if $@;
	if (! (defined AttrVal($name,"stateFormat",undef))) {
		$main::attr{$name}{"stateFormat"} = "reading";
	}
	if (! (defined AttrVal($name,"event-min-interval",undef))) {
		$main::attr{$name}{"event-min-interval"} = 5;
	}
	main::readingsSingleUpdate($hash,"state","Initialized",1);
	return undef;
}

sub
FRM_AD_observer
{
	my ($pin,$old,$new,$hash) = @_;
	my $name = $hash->{NAME};
	Log3 $name,5,"onAnalogMessage for pin ".$pin.", old: ".(defined $old ? $old : "--").", new: ".(defined $new ? $new : "--");
	main::readingsBeginUpdate($hash);
	main::readingsBulkUpdate($hash,"reading",$new,1);
	my $upperthresholdalarm = ReadingsVal($name,"alarm-upper-threshold","off");
	if ( $new < AttrVal($name,"upper-threshold",$hash->{".max"}) ) {
		if ( $upperthresholdalarm eq "on" ) {
			main::readingsBulkUpdate($hash,"alarm-upper-threshold","off",1);
		}
		my $lowerthresholdalarm = ReadingsVal($name,"alarm-lower-threshold","off"); 
		if ( $new > AttrVal($name,"lower-threshold",-1) ) {
			if ( $lowerthresholdalarm eq "on" ) {
				main::readingsBulkUpdate($hash,"alarm-lower-threshold","off",1);
			}
		} else {
			if ( $lowerthresholdalarm eq "off" ) {
				main::readingsBulkUpdate($hash,"alarm-lower-threshold","on",1);
			}
		}
	} else {
		if ( $upperthresholdalarm eq "off" ) {
			main::readingsBulkUpdate($hash,"alarm-upper-threshold","on",1);
		}
	};
	main::readingsEndUpdate($hash,1);
}

sub
FRM_AD_Get($)
{
  my ($hash,@a) = @_;
  my $name = shift @a;
  my $cmd = shift @a;
  my $ret;
  ARGUMENT_HANDLER: {
    $cmd eq "reading" and do {
      eval {
        return FRM_Client_FirmataDevice($hash)->analog_read($hash->{PIN});
      };
      return $@;
    };
    ( $cmd eq "alarm-upper-threshold" or $cmd eq "alarm-lower-threshold" or $cmd eq "state" ) and do {
      return main::ReadingsVal($name,"count",$gets{$cmd});
    };
  }
  return undef;
}

sub
FRM_AD_Attr($$$$) {
  my ($command,$name,$attribute,$value) = @_;
  my $hash = $main::defs{$name};
  eval {
    if ($command eq "set") {
      ARGUMENT_HANDLER: {
        $attribute eq "IODev" and do {
          if ($main::init_done and (!defined ($hash->{IODev}) or $hash->{IODev}->{NAME} ne $value)) {
            FRM_Client_AssignIOPort($hash,$value);
            FRM_Init_Client($hash) if (defined ($hash->{IODev}));
          }
          last;
        };
      }
    }
  };
  if ($@) {
    $@ =~ /^(.*)( at.*FHEM.*)$/;
    $hash->{STATE} = "error setting $attribute to $value: ".$1;
    return "cannot $command attribute $attribute to $value for $name: ".$1;
  }
}

1;

=pod

  CHANGES

  2016 jensb
    o modified sub FRM_AD_Init to catch exceptions and return error message
    
  19.01.2018 jensb
    o support analog resolution depending on device capability

=cut

=pod
=item device
=item summary Firmata: analog input
=item summary_DE Firmata: analog Eingang
=begin html

<a name="FRM_AD"></a>
<h3>FRM_AD</h3>
<ul>
  This module represents a pin of a <a href="http://www.firmata.org">Firmata device</a> 
  that should be configured as an analog input.<br><br>
  
  Requires a defined <a href="#FRM">FRM</a> device to work. The pin must be listed in the internal reading "<a href="#FRMinternals">analog_pins</a>"<br>
  of the FRM device (after connecting to the Firmata device) to be used as analog input.<br><br> 
  
  <a name="FRM_ADdefine"></a>
  <b>Define</b>
  <ul>
      <code>define &lt;name&gt; FRM_AD &lt;pin&gt;</code><br><br>
  
      Defines the FRM_AD device. &lt;pin&gt; is the arduino-pin to use.
  </ul><br>
  
  <a name="FRM_ADset"></a>
  <b>Set</b><br>
  <ul>
    N/A<br>
  </ul><br>
  
  <a name="FRM_ADget"></a>
  <b>Get</b><br>
  <ul>
    <li>reading<br>
    returns the voltage-level equivalent at the arduino-pin. The min value is zero and the max value<br>
    depends on the Firmata device (see internal reading "<a href="#FRMinternals">analog_resolutions</a>" of the FRM device.<br>
    For 10 bits resolution the range is 0 to 1023 (also see <a href="http://arduino.cc/en/Reference/AnalogRead">analogRead()</a> for details)<br></li>
    <li>alarm-upper-threshold<br>
    returns the current state of 'alarm-upper-threshold'. Values are 'on' and 'off' (Defaults to 'off')<br>
    'alarm-upper-threshold' turns 'on' whenever the 'reading' is higher than the attribute 'upper-threshold'<br>
    it turns 'off' again as soon 'reading' falls below 'alarm-upper-threshold'</li>
    <li>alarm-lower-threshold<br>
    returns the current state of 'alarm-lower-threshold'. Values are 'on' and 'off' (Defaults to 'off')<br>
    'alarm-lower-threshold' turns 'on' whenever the 'reading' is lower than the attribute 'lower-threshold'<br>
    it turns 'off' again as soon 'reading rises above 'alarm-lower-threshold'</li>
    <li>state<br>
    returns the 'state' reading</li>
  </ul><br>
  
  <a name="FRM_ADattr"></a>
  <b>Attributes</b><br>
  <ul>
      <li>upper-threshold<br>
      sets the 'upper-threshold'. Whenever the 'reading' exceeds this value 'alarm-upper-threshold' is set to 'on'<br>
      As soon 'reading' falls below the 'upper-threshold' 'alarm-upper-threshold' turns 'off' again<br>
      Defaults to the max pin resolution plus one.</li>
      <li>lower-threshold<br>
      sets the 'lower-threshold'. Whenever the 'reading' falls below this value 'alarm-lower-threshold' is set to 'on'<br>
      As soon 'reading' rises above the 'lower-threshold' 'alarm-lower-threshold' turns 'off' again<br>
      Defaults to -1.</li>
      <li><a href="#IODev">IODev</a><br>
      Specify which <a href="#FRM">FRM</a> to use. (Optional, only required if there is more
      than one FRM-device defined.)
      </li>
      <li><a href="#eventMap">eventMap</a><br></li>
      <li><a href="#readingFnAttributes">readingFnAttributes</a><br></li>
  </ul><br>
  
  <a name="FRM_ADnotes"></a>
  <b>Notes</b><br>
  <ul>
      <li>attribute <i>stateFormat</i><br>
      In most cases it is a good idea to assign "reading" to the attribute <i>stateFormat</i>. This will show the 
      current value of the pin in the web interface.
      </li>
  </ul>  
</ul><br>

=end html
=cut
