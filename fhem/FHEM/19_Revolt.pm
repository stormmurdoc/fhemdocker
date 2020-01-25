#                                            
# Written by Martin Paulat, 2013             
# mainted by Gernot Hillier (yoda_gh), 2018- 
#            <gernot@hillier.de>             
#                                           
# $Id: 19_Revolt.pm 17447 2018-10-01 19:13:48Z yoda_gh $

package main;

use strict;
use warnings;
use Date::Parse;



#####################################
sub Revolt_Initialize($)
{
  my ($hash) = @_;

  $hash->{Match}     = "^r......................\$";
  $hash->{DefFn}     = "Revolt_Define";
  $hash->{UndefFn}   = "Revolt_Undef";
  $hash->{ParseFn}   = "Revolt_Parse";
  $hash->{AttrList}  = "IODev ".
                       "EnergyAdjustValue ".
                       $readingFnAttributes;
}

#####################################
sub Revolt_Define($$)
{
  my ($hash, $def) = @_;
  my @a = split("[ \t][ \t]*", $def);

  return "wrong syntax: define <name> Revolt <id>" if(int(@a) != 3);
  $a[2] = lc($a[2]);
  return "Define $a[0]: wrong <id> format: specify a 4 digit hex value"	if($a[2] !~ m/^[a-f0-9][a-f0-9][a-f0-9][a-f0-9]$/);

  $hash->{ID} = $a[2];
  #$hash->{STATE} = "Initialized";
  $modules{REVOLT}{defptr}{$a[2]} = $hash;
  AssignIoPort($hash);
  
  my $name = $a[0]; 
  #$attr{$name}{"event-aggregator"} = "power::none:median:120,energy::none:median:120" if(!defined($attr{$name}{"event-aggregator"}));
  $attr{$name}{"stateFormat"} = "P: power E: energy V: voltage C: current Pf: pf" if(!defined($attr{$name}{"stateFormat"}));
  
  return undef;
}

#####################################
sub Revolt_Undef($$)
{
  my ($hash, $name) = @_;
  delete($modules{REVOLT}{defptr}{$hash->{ID}}) if(defined($hash->{ID}) &&
                                                   defined($modules{REVOLT}{defptr}{$hash->{ID}}));
  return undef;
}

#####################################
sub Revolt_Parse($$)
{
  my ($hash, $msg) = @_;

  $msg = lc($msg);
  my $seq = substr($msg, 1, 2);
  my $dev = substr($msg, 3, 4);
  my $cde = substr($msg, 7, 4);
  my $val = substr($msg, 11, 22);
  my $id       = substr($msg, 1, 4);
  my $voltage  = hex(substr($msg, 5, 2));
  my $current  = hex(substr($msg, 7, 4)) * 0.01;
  my $freq     = hex(substr($msg, 11, 2));
  my $power    = hex(substr($msg, 13, 4)) * 0.1;
  my $pf       = hex(substr($msg, 17, 2)) * 0.01;
  my $energy   = hex(substr($msg, 19, 4)) * 0.01;
  my $lastval  = 0.0;
  my $type = "";
  my $energyAdj = $energy;
  
  if(!defined($modules{REVOLT}{defptr}{$id})) {
    Log3 undef,3, "Unknown Revolt device $id, please define it";
    $type = "Revolt" if(!$type);
    return "UNDEFINED ${type}_$id Revolt $id";
  }

  my $def = $modules{REVOLT}{defptr}{$id};
  my $name = $def->{NAME};
  return "" if(IsIgnored($name));
  
  # check if data is invalid
  if (defined($def->{READINGS}{".lastenergy"})) {
    $lastval = $def->{READINGS}{".lastenergy"}{VAL};
  } 
  else {
    readingsSingleUpdate($def,".lastenergy", $energy, 1);
  }
  
  # adjust energy value
  $energy -= AttrVal($name, "EnergyAdjustValue", 0);
  
  my $isInvalid = 0;
  #my $energydiff = 0;
  #my $maxenergy = 0;

  #TODO: This plausability check will stop accepting values forever after 
  #receiving a very small outlier once. We could use abs(...), but what about
  #changing energyadjustvalue etc.? Do we really need this at all?
  #
  #if (defined($def->{READINGS}{"energy"})) {
  # my $timediff = gettimeofday() - str2time($def->{READINGS}{"energy"}{TIME});
  #  $energydiff = $energy - $def->{READINGS}{"energy"}{VAL};
  #  $maxenergy = 3.65 * ($timediff / 3600.0);
  #}
  #if ($energydiff > $maxenergy) {
  #  $isInvalid = 1;
  #}

  if (0 == $pf) {
    $pf = 0.0001;
  }
  # plausability check partly taken from http://www.sknorrell.de/blog/energiemesssung-mit-revolt-nc-5462/
  if (($voltage < 80) || ($freq > 65) || ($power > 3650) || ($current > 16) ||
      ((($power / $voltage / $pf) > 0.00999) && (0 == $current))) {
    $isInvalid = 1;
  }

  if (0 == $isInvalid) {
    #my $state = "P: ".sprintf("%5.1f", $power)." E: ".sprintf("%6.2f", $energy)." V: ".sprintf("%3d", $voltage)." C: ".sprintf("%6.2f", $current)." F: $freq Pf: ".sprintf("%4.2f", $pf);

    readingsBeginUpdate($def);

    my $timediff = gettimeofday() - str2time($def->{READINGS}{".lastenergy"}{TIME});
    if (($lastval != $energy) && (($energy - $lastval) < (3.65 * ($timediff / 3600.0)))) {
        readingsBulkUpdate($def, ".lastenergy", $energy, 1);
    }

    readingsBulkUpdate($def, "state", "active",  0);
    readingsBulkUpdate($def, "voltage", $voltage, 1);
    readingsBulkUpdate($def, "current", $current, 1);
    readingsBulkUpdate($def, "frequency", $freq, 1);
    readingsBulkUpdate($def, "power", $power, 1);
    readingsBulkUpdate($def, "pf", $pf, 1);
    readingsBulkUpdate($def, "energy", $energy, 1);

    readingsEndUpdate($def, 1);
  }

  return $name;
}

1;

=pod
=item device
=item summary Receive power, energy, voltage etc. from Revolt NC-5462 433MHz devices
=item summary_DE Energieverbrauch von Revolt NC-5462 über 433MHz empfangen
=begin html

<a name="Revolt"></a>
<h3>Revolt NC-5462</h3>
<ul>
  Provides energy consumption readings for Revolt NC-5462 devices via CUL or
  SIGNALduino (433MHz).
  <br><br>
  These devices send telegrams with measured values every few seconds. Many 
  users saw problems with cheap 433MHz receivers - and even with good 
  receivers, wrong values are received quite often, leading to outliers
  in plots and sporadic autocreation of devices with wrong IDs.
  <br><br>
  This module now ignores implausible telegrams (e.g. voltage below 80),
  but to further reduce outliers and event frequency, you should use the common
  attributes described below. You also might want to disable autocreation of
  Revolt devices once all of yours are detected.
  <br><br>

  <a name="RevoltDefine"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; Revolt &lt;id&gt;</code>
    <br><br>
    &lt;id&gt; is a 4 digit hex number to identify the NC-5462 device.<br>
    Note: devices are autocreated on reception of the first message.<br>
  </ul>
  <br>
  <a name="RevoltAttributes"></a>
  <b>Attributes</b>
  <ul>
    <li>EnergyAdjustValue: adjust the energy reading (energy = energy - EnergyAdjustValue)</li>
  </ul>
  <br>
  <b>Common attributes</b>
  <ul>
    <li><a href="#event-aggregator">event-aggregator</a>: To reduce the high sending frequency and filter reception errors, you can use FHEM's event-aggregator. Common examples:
      <ul>
        <li><tt>power:60:linear:mean,energy:36000:none:v</tt> reduce sampling frequency to one power event per minute and one energy value per 10 hours, other events can be disabled via <tt>event-on-change-reading</tt> or <tt>event-on-update-reading</tt>.</li>
        <li><tt>power::none:median:120,energy::none:median:120</tt> keep sampling frequency untouched, but filter outliers using statistical median</li>
      </ul>
    </li>
    <li><a href="#event-min-interval">event-min-interval</a></li>
    <li><a href="#event-on-change-reading">event-on-change-reading</a>: can be used to disable events for readings you don't need. See documentation for details.</li>
    <li><a href="#event-on-update-reading">event-on-update-reading</a>: can be used to disable events for readings you don't need. See documentatino for details.</li> 
  </ul>
  <a name="RevoltReadings"></a>
  <b>Readings</b>
  <ul>
    <li>energy    [kWh]: Total energy consumption summed up in the NC-5462
        devices. It seems you can't reset this counter and it will wrap around
        to 0 at 655.35 kWh. The EnergyAdjustValue attribute (see above) allows
        to adapt the reading, e.g. when you connect a new device.</li>
    <li>power     [W]</li>
    <li>voltage   [V]</li>
    <li>current   [A]</li>
    <li>frequency [Hz]</li>
    <li>Pf: Power factor</li>
  </ul>

</ul>
=end html
=cut
