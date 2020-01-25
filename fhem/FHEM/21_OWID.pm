########################################################################################
#
# OWID.pm
#
# FHEM module to commmunicate with general 1-Wire ID-ROMS
#
# Prof. Dr. Peter A. Henning
# Norbert Truchsess
#
# $Id: 21_OWID.pm 15339 2017-10-29 08:14:07Z phenning $
#
########################################################################################
#
#  This programm is free software; you can redistribute it and/or modify
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
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
########################################################################################
package main;

use vars qw{%attr %defs %modules $readingFnAttributes $init_done};
use Time::HiRes qw(gettimeofday);

use strict;
use warnings;

#add FHEM/lib to @INC if it is not already included. Should rather be in fhem.pl than here though...
BEGIN {
  if (!grep(/FHEM\/lib$/,@INC)) {
    foreach my $inc (grep(/FHEM$/,@INC)) {
      push @INC,$inc."/lib";
    };
  };
};

use GPUtils qw(:all);
use ProtoThreads;
no warnings 'deprecated';
sub Log3($$$);

my $owx_version="7.01";
#-- declare variables
my %gets = (
  "present"     => ":noArg",
  "id"          => ":noArg",
  "version"     => ":noArg"
);
my %sets    = (
  "interval"    => ""
);
my %updates = (
  "present"    => ""
);
 
########################################################################################
#
# The following subroutines are independent of the bus interface
#
# Prefix = OWID
#
########################################################################################
#
# OWID_Initialize
#
# Parameter hash = hash of device addressed
#
########################################################################################

sub OWID_Initialize ($) {
  my ($hash) = @_;

  $hash->{DefFn}    = "OWID_Define";
  $hash->{UndefFn}  = "OWID_Undef";
  $hash->{GetFn}    = "OWID_Get";
  $hash->{SetFn}    = "OWID_Set";
  $hash->{AttrFn}   = "OWID_Attr";
  $hash->{NotifyFn} = "OWID_Notify";
  $hash->{InitFn}   = "OWID_Init";
  $hash->{AttrList} = "IODev do_not_notify:0,1 showtime:0,1 model interval ".
                      $readingFnAttributes;

  #--make sure OWX is loaded so OWX_CRC is available if running with OWServer
  main::LoadModule("OWX");	
}

#########################################################################################
#
# OWID_Define - Implements DefFn function
# 
# Parameter hash = hash of device addressed, def = definition string
#
#########################################################################################

sub OWID_Define ($$) {
  my ($hash, $def) = @_;
  
  #-- define <name> OWID <FAM_ID> <ROM_ID>
  my @a = split("[ \t][ \t]*", $def);
  
  my ($name,$interval,$model,$fam,$id,$crc,$ret);
  
  #-- default
  $name          = $a[0];
  $interval      = 300;
  $ret           = "";

  #-- check syntax
  return "OWID: Wrong syntax, must be define <name> OWID [<model>] <id> [interval] or OWAD <fam>.<id> [interval]"
       if(int(@a) < 2 || int(@a) > 5);
          
  #-- different types of definition allowed
  my $a2 = $a[2];
  my $a3 = defined($a[3]) ? $a[3] : "";
  #-- no model, 2+12 characters
  if(  $a2 =~ m/^[0-9|a-f|A-F]{2}\.[0-9|a-f|A-F]{12}$/ ) {
    $fam   = substr($a[2],0,2);
    $id    = substr($a[2],3);
    if(int(@a)>=4) { $interval = $a[3]; }
    if( $fam eq "01" ){
      $model = "DS2401";
      CommandAttr (undef,"$name model DS2401"); 
    }elsif( $fam eq "09" ){
      $model = "DS2502";
      CommandAttr (undef,"$name model DS2502"); 
    }else{
      $model = "unknown";
      CommandAttr (undef,"$name model unknown"); 
    }
  #-- model or family id, 12 characters
  } elsif(  $a3 =~ m/^[0-9|a-f|A-F]{12}$/ ) {
    $id  = $a[3];
    if(int(@a)>=5) { $interval = $a[4]; }
    #-- family id, 2 characters
    if(  $a2 =~ m/^[0-9|a-f|A-F]{2}$/ ) {
      $fam   = $a[2];
      if( $fam eq "01" ){
        $model = "DS2401";
        CommandAttr (undef,"$name model DS2401"); 
      }elsif( $fam eq "09" ){
        $model = "DS2502";
        CommandAttr (undef,"$name model DS2502"); 
      }else{
        $model = "unknown";
        CommandAttr (undef,"$name model unknown"); 
      }
    }else{
      $model   = $a[2];
      if( $model eq "DS2401" ){
        $fam = "01";
        CommandAttr (undef,"$name model DS2401"); 
      }elsif( $model eq "DS2502" ){
        $fam = "09";
        CommandAttr (undef,"$name model DS2502"); 
      }else{
        return "OWID: Unknown 1-Wire device model $model";
      }
    }
  } else {    
    return "OWID: $a[0] ID $a[2] invalid, specify a 12 or 2.12 digit value";
  }
  
  #-- determine CRC Code 
  $crc = sprintf("%02X",OWX_CRC($fam.".".$id."00"));
  
  #-- Define device internals
  $hash->{ROM_ID}     = "$fam.$id.$crc";
  $hash->{OW_ID}      = $id;
  $hash->{OW_FAMILY}  = $fam;
  $hash->{PRESENT}    = 0;
  $hash->{INTERVAL}   = $interval;
  
  #-- Couple to I/O device
  AssignIoPort($hash);
  if( !defined($hash->{IODev}) or !defined($hash->{IODev}->{NAME}) ){
    return "OWID: Warning, no 1-Wire I/O device found for $name.";
  } else {
    $hash->{ASYNC} = $hash->{IODev}->{TYPE} eq "OWX_ASYNC" ? 1 : 0; #-- false for now
  }

  $modules{OWID}{defptr}{$id} = $hash;
  #--
  readingsSingleUpdate($hash,"state","Defined",1);
  Log3 $name,1, "OWID:     Device $name defined."; 

  $hash->{NOTIFYDEV} = "global";

  return OWID_Init($hash);

}

#########################################################################################
#
# OWID_Notify - Implements NotifyFn function
# 
# Parameter hash = hash of device addressed, dev = device name
#
#########################################################################################

sub OWID_Notify ($$) {
  my ($hash,$dev) = @_;
  if( grep(m/^(INITIALIZED|REREADCFG)$/, @{$dev->{CHANGED}}) ) {
    OWID_Init($hash);
  } elsif( grep(m/^SAVE$/, @{$dev->{CHANGED}}) ) {
  }
}

#########################################################################################
#
# OWID_Init - Implements InitFn function
# 
# Parameter hash = hash of device addressed
#
#########################################################################################

sub OWID_Init ($) {
  my ($hash)=@_;
  #-- Start timer for updates
  RemoveInternalTimer($hash);
  InternalTimer(gettimeofday()+30, "OWID_GetValues", $hash, 0);
  #--
  readingsSingleUpdate($hash,"state","Initialized",1);
  
  if (! (defined AttrVal($hash->{NAME},"stateFormat",undef))) {
    $main::attr{$hash->{NAME}}{"stateFormat"} = "{ReadingsVal(\$name,\"present\",0) ? \"present\" : \"not present\"}";
  }
   
  return undef; 
}

#######################################################################################
#
# OWID_Attr - Set one attribute value for device
#
#  Parameter hash = hash of device addressed
#            a = argument array
#
########################################################################################

sub OWID_Attr(@) {
  my ($do,$name,$key,$value) = @_;
  
  my $hash = $defs{$name};
  my $ret;
  
  if ( $do eq "set") {
    ARGUMENT_HANDLER: {
      #-- interval modified at runtime
      $key eq "interval" and do {
        #-- check value
        return "OWID: set $name interval must be >= 0" if(int($value) < 0);
        #-- update timer
        $hash->{INTERVAL} = int($value);
        if ($init_done) {
          RemoveInternalTimer($hash);
          InternalTimer(gettimeofday()+$hash->{INTERVAL}, "OWID_GetValues", $hash, 0);
        }
        last;
      };
      $key eq "IODev" and do {
        AssignIoPort($hash,$value);
        if( defined($hash->{IODev}) ) {
          $hash->{ASYNC} = $hash->{IODev}->{TYPE} eq "OWX_ASYNC" ? 1 : 0;
          if ($init_done) {
            OWID_Init($hash);
          }
        }
        last;
      }
    }
  }
  return $ret;
}

########################################################################################
#
# OWID_Get - Implements GetFn function 
#
#  Parameter hash = hash of device addressed, a = argument array
#
########################################################################################

sub OWID_Get($@) {
  my ($hash, @a) = @_;
  
  my $reading = $a[1];
  my $name    = $hash->{NAME};
  my $model   = $hash->{OW_MODEL};
  my $value   = undef;
  my $ret     = "";
  my $offset;
  my $factor;

  #-- check syntax
  return "OWID: Get argument is missing @a"
    if(int(@a) != 2);
    
  #-- check argument
  my $msg = "OWID: Get with unknown argument $a[1], choose one of ";
  $msg .= "$_$gets{$_} " foreach (keys%gets);
  return $msg
    if(!defined($gets{$a[1]}));

  #-- get id
  if($a[1] eq "id") {
    $value = $hash->{ROM_ID};
     return "$name.id => $value";
  } 
  
  #-- get present
  if($a[1] eq "present") {
    #-- hash of the busmaster
    my $master    = $hash->{IODev};
    my $interface = $master->{TYPE};
  
    #-- OWX interface
    if( $interface eq "OWX" ){
      $value = OWX_Verify($master,$name,$hash->{ROM_ID},0);    
    #-- OWX_ASYNC interface
    }elsif( $interface eq "OWX_ASYNC" ){
      eval {
        OWX_ASYNC_RunToCompletion($hash,OWX_ASYNC_PT_Verify($hash));
      };
      return GP_Catch($@) if $@;
        
    #-- Unknown interface 
    } else {
      return "OWID: Verification not yet implemented for interface $interface";
    }
    #-- process results
    if( $master->{ASYNCHRONOUS} ){
      return undef;
    }else{
      #-- generate an event only if presence has changed
      if( $value == 0 ){
        readingsSingleUpdate($hash,"present",0,$hash->{PRESENT}); 
      } else {
        readingsSingleUpdate($hash,"present",1,!$hash->{PRESENT}); 
      }
      $hash->{PRESENT} = $value;
      return "$name.present => $value";
    }
  } 
  
  #-- get version
  if( $a[1] eq "version") {
    return "$name.version => $owx_version";
  }
}

########################################################################################
#
# OWID_GetValues - Updates the reading from one device
#
#  Parameter hash = hash of device addressed
#
########################################################################################

sub OWID_GetValues($) {
  my $hash    = shift;
  
  my $name    = $hash->{NAME};
  my $value   = 0;
  my $ret     = "";
  my $offset;
  my $factor;
  
  RemoveInternalTimer($hash); 
  #-- auto-update for device disabled;
  return undef
    if( $hash->{INTERVAL} == 0 );
  #-- restart timer for updates  
  InternalTimer(time()+$hash->{INTERVAL}, "OWID_GetValues", $hash, 0);
  
  #-- hash of the busmaster
  my $master    = $hash->{IODev};
  my $interface = $master->{TYPE};
  
  #-- OWX interface
  if( $interface eq "OWX" ){
    $value = OWX_Verify($master,$name,$hash->{ROM_ID},0);
      
  #-- OWX_ASYNC interface
  }elsif( $interface eq "OWX_ASYNC" ){
    eval {
      OWX_ASYNC_RunToCompletion($hash,OWX_ASYNC_PT_Verify($hash));
    };
    return GP_Catch($@) if $@;
  }

  #-- process results
  if( $master->{ASYNCHRONOUS} ){
    return undef;
  }else{
    #-- generate an event only if presence has changed
    if( $value == 0 ){
      readingsSingleUpdate($hash,"present",0,$hash->{PRESENT}); 
    } else {
      readingsSingleUpdate($hash,"present",1,!$hash->{PRESENT}); 
    }
    $hash->{PRESENT} = $value;
    return "$name.present => $value";
  }
}

#######################################################################################
#
# OWID_Set - Set one value for device
#
#  Parameter hash = hash of device addressed
#            a = argument array
#
########################################################################################

sub OWID_Set($@) {
  my ($hash, @a) = @_;
  
  my $key     = $a[1];
  my $value   = $a[2];
  
  #-- for the selector: which values are possible
  if (@a == 2){
    my $newkeys = join(" ", keys %sets);
    return $newkeys ;    
  }
  
  #-- check syntax
  return "OWID: Set needs at least one parameter"
    if( int(@a)<3 );
  #-- check argument
  if( !defined($sets{$a[1]}) ){
        return "OWID: Set with unknown argument $a[1]";
  }
  
  my $name    = $hash->{NAME};
  
  #-- set new timer interval
  if($key eq "interval") {
    # check value
    return "OWID: Set $name interval must be >= 0"
      if(int($value) < 0);
    # update timer
    $hash->{INTERVAL} = int($value);
    RemoveInternalTimer($hash);
    InternalTimer(gettimeofday()+$hash->{INTERVAL}, "OWID_GetValues", $hash, 0);
    return undef;
  }
}

########################################################################################
#
# OWID_Undef - Implements UndefFn function
#
# Parameter hash = hash of device addressed
#
########################################################################################

sub OWID_Undef ($) {
  my ($hash) = @_;
  delete($modules{OWID}{defptr}{$hash->{OW_ID}});
  RemoveInternalTimer($hash);
  return undef;
}

1;

=pod
=item device
=item summary to control 1-Wire devices having only a serial number
=begin html

 <a name="OWID"></a>
        <h3>OWID</h3>
        <p>FHEM module for 1-Wire devices that know only their unique ROM ID<br />
            <br />This 1-Wire module works with the OWX interface module or with the OWServer interface module
            Please define an <a href="#OWX">OWX</a> device or <a href="#OWServer">OWServer</a> device first. <br /></p>
        <br /><h4>Example</h4><br />
        <p>
            <code>define ROM1 OWX_ID OWCOUNT 09.CE780F000000 10</code>
            <br />
        </p><br />
        <a name="OWIDdefine"></a>
        <h4>Define</h4>
        <p>
            <code>define &lt;name&gt; OWID &lt;fam&gt; &lt;id&gt; [&lt;interval&gt;]</code> or <br/>
            <code>define &lt;name&gt; OWID &lt;fam&gt;.&lt;id&gt; [&lt;interval&gt;]</code>
            <br /><br /> Define a 1-Wire device.<br /><br />
        </p>
        <ul>
            <li>
                <code>&lt;fam&gt;</code>
                <br />2-character unique family id, see above 
            </li>
            <li>
                <code>&lt;id&gt;</code>
                <br />12-character unique ROM id of the converter device without family id and CRC
                code 
            </li>
            <li>
                <code>&lt;interval&gt;</code>
                <br />Interval in seconds for checking the presence of the device. The default is 300 seconds. </li>
        </ul>
         <br />
        <a name="OWIDset"></a>
        <h4>Set</h4>
        <ul>
            <li><a name="owid_interval">
                    <code>set &lt;name&gt; interval &lt;int&gt;</code></a><br />
                    Interval in seconds for checking the presence of the device. The default is 300 seconds. </li>
        </ul>
        <br />
        <a name="OWIDget"></a>
        <h4>Get</h4>
        <ul>
            <li><a name="owid_id">
                    <code>get &lt;name&gt; id</code></a>
                <br /> Returns the full 1-Wire device id OW_FAMILY.ROM_ID.CRC </li>
            <li><a name="owid_present">
                    <code>get &lt;name&gt; present</code>
                </a>
                <br /> Returns 1 if this 1-Wire device is present, otherwise 0. </li>
        </ul>
                <h4>Attributes</h4>
        <ul><li><a name="owtherm_interval2">
                    <code>attr &lt;name&gt; interval &lt;int&gt;</code></a><br /> Measurement
                interval in seconds. The default is 300 seconds, a value of 0 disables the automatic update.</li>
            <li><a href="#readingFnAttributes">readingFnAttributes</a></li>
        </ul>
        
=end html
=cut
