#################################################################################
# 46_PW_Scan.pm
#
# FHEM module Plugwise motion scanners
#
# Copyright (C) 2015 Stefan Guttmann
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# The GNU General Public License may also be found at http://www.gnu.org/licenses/gpl-2.0.html .
###################################
#
# $Id: 46_PW_Scan.pm 20792 2019-12-20 17:32:00Z rudolfkoenig $ 
package main;

use strict;
use warnings;
use Data::Dumper;

my $time_old = 0;

my $DOT = q{_};

sub PW_Scan_Initialize($)
{
  my ($hash) = @_;

  $hash->{Match}     = "PW_Scan";
  $hash->{DefFn}     = "PW_Scan_Define";
  $hash->{UndefFn}   = "PW_Scan_Undef";
  $hash->{ParseFn}   = "PW_Scan_Parse";
  $hash->{SetFn}     = "PW_Scan_Set";
  $hash->{AttrList}  = "IODev do_not_notify:1,0 ".
                       $readingFnAttributes;

  Log3 $hash, 5, "PW_Scan_Initialize() Initialize";
}

#####################################
sub PW_Scan_Define($$)
{
  my ($hash, $def) = @_;
  my @a = split("[ \t][ \t]*", $def);
  my $a = int(@a);

  Log3 $hash,5,"PW_Scan: Define called --> $def";

  return "wrong syntax: define <name> PW_Scan address" if(int(@a) != 3);

  my $name = $a[0];
  my $code = $a[2];
  my $device_name = "PW_Scan".$DOT.$code;

  $hash->{CODE} = $code;
  $modules{PW_Scan}{defptr}{$device_name} = $hash;
  AssignIoPort($hash);
  if( $init_done ) {
  	$attr{$name}{room}='Plugwise';
        }

  return undef;
}

#####################################
sub PW_Scan_Undef($$)
{
  my ($hash, $name) = @_;
  delete($modules{PW_Scan}{defptr}{$name});
  return undef;
}

sub PW_Scan_Set($@)
{
	my ( $hash, @a ) = @_;
	return "\"set X\" needs at least an argument" if ( @a < 2 );
	my $name = shift @a;
	my $opt = shift @a;
	my $value = join("", @a);

	Log3 $hash,5,"$hash->{NAME} - PW_Scan-Set: N:$name O:$opt V:$value";
	
	if ($opt eq "removeNode") {
		IOWrite($hash,$hash->{CODE},$opt);
	} elsif ($opt eq "ping") {
		IOWrite($hash,$hash->{CODE},$opt);
	}
	else
        {
          return "Unknown argument $opt, choose one of removeNode ping";
        }
}

sub PW_Scan_Parse($$)
{
 my ($hash, $msg2) = @_;
  my $msg=$hash->{RAWMSG};
#Log 3,"SCAN: got a msg";

  my $time = time();
  if ($msg->{type} eq "err") {return undef};

  Log3 $hash,5,"PW_Scan: Parse called ".$msg->{short};

  $time_old = $time;
  Log3 $hash,5, Dumper($msg);
  my $device_name = "PW_Scan".$DOT.$msg->{short};
  Log3 $hash,5,"New Devicename: $device_name";
  my $def = $modules{PW_Scan}{defptr}{"$device_name"};
  if(!$def) {
        Log3 $hash, 3, "PW_Scan: Unknown device $device_name, please define it";
        return "UNDEFINED $device_name PW_Scan $msg->{short}";
  }
  # Use $def->{NAME}, because the device may be renamed:
  my $name = $def->{NAME};

  my $type = $msg->{type};
  Log3 $hash,5,"PW_Scan: Type is '$type'";
  Log3 $hash,5,Dumper($msg);

  readingsBeginUpdate($def);
  Log3 $hash,5,Dumper($msg);

  if($type eq "sense") {
    readingsBulkUpdate($def, "state", ($msg->{val1} eq 0 ? 'off' : 'on' ));
  }
  
  readingsEndUpdate($def, 1);
  
  return $name;
   }

"Cogito, ergo sum.";

=pod
=item device
=item summary    Submodule for 45_Plugwise
=item summary_DE Untermodul zu 45_Plugwise
=begin html

<a name="PW_Scan"></a>
<h3>PW_Scan</h3>
<ul>
  The PW_Scan module is invoked by Plugwise. You need to define a Plugwise-Stick first. 
See <a href="#PW_Scan">PW_Scan</a>.
  <br>
  <a name="PW_Scan define"></a>
  <br>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; PW_Scan &lt;ShortAddress&gt;</code> <br>
    <br>
    <code>&lt;ShortAddress&gt;</code>
    <ul>
      specifies the short (last 4 Bytes) of the PW_Scan received by the Plugwise-Stick. <br>
    </ul>
    <br>
      Example: <br>
    	<code>define PW_Scan_2907CC9 PW_Scan 2907CC9</code>
      <br>
  </ul>
  <br>
</ul>

=end html

=begin html_DE

<a name="PW_Scan"></a>
<h3>PW_Scan</h3>
<ul>
  Das PW_Scan Modul setzt auf das Plugwise-System auf. Es muss zuerst ein Plugwise-Stick angelegt werden. 
  Siehe <a href="#Plugwise">Plugwise</a>.
  <br>
  <a name="PW_Scan define"></a>
  <br>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; PW_Scan &lt;ShortAddress&gt;</code> <br>
    <br>
    <code>&lt;ShortAddress&gt;</code>
    <ul>
      gibt die Kurzadresse (die letzten 4 Bytes) des Gerätes an. <br>
    </ul>
  <br><br>    
  </ul>
</ul>

=end html_DE
=cut

