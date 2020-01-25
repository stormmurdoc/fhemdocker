# $Id: 12_HProtocolTank.pm 20548 2019-11-20 14:38:02Z eisler $
####################################################################################################
#
#	12_HProtocolTank.pm
#
#	Copyright: Stephan Eisler
#	Email: stephan@eisler.de 
#
#	This file is part of fhem.
#
#	Fhem is free software: you can redistribute it and/or modify
#	it under the terms of the GNU General Public License as published by
#	the Free Software Foundation, either version 2 of the License, or
#	(at your option) any later version.
#
#	Fhem is distributed in the hope that it will be useful,
#	but WITHOUT ANY WARRANTY; without even the implied warranty of
#	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#	GNU General Public License for more details.
#
#	You should have received a copy of the GNU General Public License
#	along with fhem.  If not, see <http://www.gnu.org/licenses/>.
#
####################################################################################################

package main;

sub HProtocolTank_Initialize($) {
  my ($hash) = @_;

  $hash->{DefFn}          = "HProtocolTank_Define";
  $hash->{ParseFn}        = "HProtocolTank_Parse";
  $hash->{FingerprintFn}  = "HProtocolTank_Fingerprint";
  $hash->{AttrFn}         = "HProtocolGateway_Attr";
  $hash->{Match}          = "^[a-zA-Z0-9_]+ [a-zA-Z0-9_]+ [+-]*[0-9]+([.][0-9]+)?";
  $hash->{AttrList}       = "hID " .
                            "sensorSystem:Hectronic,Unitronics,PMS-IB " .
                            "mode:FillLevel,Volume,Ullage " .
                            "product:Diesel,FuelOil,Petrol " .
                            "type " .
                            $readingFnAttributes;
}

sub HProtocolTank_Define($$) {
  my ($hash, $def) = @_;
  my @a = split("[ \t][ \t]*", $def);

  return "Wrong syntax: use define <name> HProtocolTank <gateway_name>" if(int(@a) != 3);

  my $name = $a[0];
  my $gateway = $a[2];

  if (!$hash->{IODev}) {
    AssignIoPort($hash, $gateway);
  }

  if (defined($hash->{IODev})) {
    Log3 $name, 3, "$name: I/O device is " . $hash->{IODev}->{NAME};
  } else {
    Log3 $name, 1, "$name: no I/O device";
  }

  if (defined($hash->{IODev})) {
      $iodev = $hash->{IODev}->{NAME};
  }

  $hash->{STATE} = "Initialized";

  $attr{$name}{room} = "HProtocol";

  # TODO This has to be updated when renaming the device.
  $modules{HProtocolTank}{defptr}{$name} = $hash;

  # TODO A Tank has to be unregistered when it's removed or renamed.
  HProtocolGateway_RegisterTank($hash);

  return undef;
}

sub HProtocolTank_Parse($$) {
  my ($iohash, $message) = @_;

  # $message = "<tankName> <reading> <value>"
  my @array = split("[ \t][ \t]*", $message);
  my $tankName = @array[0];
  my $reading = @array[1];
  my $value = @array[2];

  my $hash = $modules{HProtocolTank}{defptr}{$tankName};

  readingsSingleUpdate($hash, $reading, $value, 1);

	return $tankName;
}

sub HProtocolTank_Fingerprint($$) {
  # this subroutine is called before running Parse to check if
  # this message is a duplicate message. Refer to FHEM Wiki.
}

sub HProtocolTank_Attr (@) {
    my ($command, $name, $attr, $val) =  @_;
    my $hash = $defs{$name};
    my $msg = '';

    if ($attr eq 'type') {
      $attr{$name}{type} = $val;
    } elsif ($attr eq 'mode') {
      $attr{$name}{mode} = $val;
    } elsif ($attr eq 'product') {
      $attr{$name}{product} = $val;
    } elsif ($attr eq 'sensorSystem') {
      $attr{$name}{sensorSystem} = $val;
    }
}

1;


=pod
=item summary   devices communicating via the HProtocolGateway 
=begin html

<a name="HProtocolTank"></a>
<h3>HProtocolTank</h3>
<ul>
    The HProtocolTank is a fhem module defines a device connected to a HProtocolGateway.

  <br /><br /><br />

  <a name="HProtocolTank"></a>
  <b>Define</b>
  <ul>

    <code>define &lt;name&gt; HProtocolTank HProtocolGateway<br />
    attr &lt;name&gt; hID 01<br />
    attr &lt;name&gt; sensorSystem Hectronic<br />
    attr &lt;name&gt; product FuelOil<br />
    </code>
    <br />

    Defines an HProtocolTank connected to a HProtocolGateway.<br /><br />

  </ul><br />

  <a name="HProtocolTank"></a>
  <b>Readings</b>
  <ul>
    <li>ullage<br />
    0..999999 Ullage in litres</li>
    <li>filllevel<br />
    0..99999 Fill level in cm</li>
    <li>volume<br />
    0..999999 Volume in litres</li>
    <li>volume_15C<br />
    0..999999 Volume in litres at 15 °C</li>
    <li>temperature<br />
    -999 - +999 Temperature in °C</li>
    <li>waterlevel<br />
    0..9999 Water level in mm</li>
    <li>probe_offset<br />
    -9999 - +9999 Probe offset in mm</li>
    <li>version<br />
    00..999 Software version</li>
    <li>error<br />
    0..9 00.. Probe error</li>
  </ul><br />

  <a name="HProtocolTank"></a>
  <b>Attributes</b>
  <ul>
    <li>hID<br />
    01 - 32 Tank Number / Tank Address (99 for testing only)</li>
    <li>sensorSystem<br />
    Sensor System / Hectronic, Unitronics, PMS-IB</li>
    <li>mode<br />
    Mode / FillLevel, Volume, Ullage</li>
    <li>type<br />
    Type / Strapping Table csv</li>
    <li>product<br />
    Product / Diesel, FuelOil, Petrol</li>
  </ul><br /><br /> 
    strapping table csv<br /><br /> 

    <code>
    level,volume<br />
    10,16<br />
    520,7781<br />
    1330,29105<br />
    1830,43403<br />
    2070,49844<br />
    2220,53580<br />
    2370,57009<br />
    2400,57650<br />
    2430,58275<br />
    2370,57009<br />
    2400,57650<br />
    2430,58275<br />
    </code> 

</ul><br />

=end html

=cut
