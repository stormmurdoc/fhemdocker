##############################################
# $Id: 30_pilight_switch.pm 11306 2016-04-24 17:03:16Z risiko79 $
#
# Usage
# 
# define <name> pilight_switch <protocol> <id> <unit> 
#
# Changelog
#
# V 0.10 2015-02-22 - initial beta version
# V 0.11 2015-03-29 - FIX:  $readingFnAttributes
# V 0.12 2015-05-18 - FIX:  add version information
# V 0.13 2015-05-30 - FIX:  StateFn, noArg
# V 0.14 2015-07-27 - NEW:  SetExtensions on-for-timer
# V 0.15 2015-12-17 - NEW:  Attribut IODev to switch IO-Device
# V 0.16 2016-03-28 - NEW:  protocol daycom with three id's (id, systemcode, unit)
# V 0.17 2016-04-24 - NEW:  Attribut sendCount
############################################## 

package main;

use strict;
use warnings;
use Time::HiRes qw(gettimeofday);
use JSON;

use SetExtensions;

my %sets = ("on:noArg"=>0, "off:noArg"=>0);

sub pilight_switch_Parse($$);
sub pilight_switch_Define($$);


sub pilight_switch_Initialize($)
{
  my ($hash) = @_;

  $hash->{DefFn}    = "pilight_switch_Define";
  $hash->{Match}    = "^PISWITCH";
  $hash->{ParseFn}  = "pilight_switch_Parse";
  $hash->{SetFn}    = "pilight_switch_Set";
  $hash->{StateFn}  = "pilight_switch_State";
  $hash->{AttrList} = "IODev sendCount:1,2,3,4,5 ".$readingFnAttributes;
}

#####################################
sub pilight_switch_Define($$)
{
  my ($hash, $def) = @_;
  my @a = split("[ \t][ \t]*", $def);

  if(@a < 5) {
    my $msg = "wrong syntax: define <name> pilight_switch <protocol> <id> <unit> [systemcode]";
    Log3 undef, 2, $msg;
    return $msg;
  }

  my $me = $a[0];
  my $protocol = $a[2];
  my $id = $a[3];
  my $unit = $a[4];

  $hash->{STATE} = "defined";
  $hash->{PROTOCOL} = lc($protocol);  
  $hash->{ID} = $id;  
  $hash->{UNIT} = $unit;
  $hash->{SYSCODE} = undef;
  $hash->{SYSCODE} = $a[5] if (@a == 6);

  #$attr{$me}{verbose} = 5;
  
  $modules{pilight_switch}{defptr}{lc($protocol)}{$me} = $hash;
  AssignIoPort($hash);
  return undef;
}

#####################################
sub pilight_switch_State($$$$)
{
  my ($hash, $time, $name, $val) = @_;
  my $me = $hash->{NAME};
  
  #$hash->{STATE} wird nur ersetzt, wenn $hash->{STATE}  == ??? fhem.pl Z: 2469
  #machen wir es also selbst
  $hash->{STATE} = $val if ($name eq "state");
  return undef;
}

###########################################
sub pilight_switch_Parse($$)
{
  
  my ($mhash, $rmsg, $rawdata) = @_;
  my $backend = $mhash->{NAME};

  Log3 $backend, 4, "pilight_switch_Parse: RCV -> $rmsg";
  
  my ($dev,$protocol,$id,$unit,$state,@args) = split(",",$rmsg);
  return () if($dev ne "PISWITCH");
  
  my $chash;
  foreach my $n (keys %{ $modules{pilight_switch}{defptr}{lc($protocol)} }) { 
    my $lh = $modules{pilight_switch}{defptr}{$protocol}{$n};
    next if ( !defined($lh->{ID}) || !defined($lh->{UNIT}) );
    if ($lh->{ID} eq $id && $lh->{UNIT} eq $unit) {
      if (defined($lh->{SYSCODE})) { #protocol daycom needs three id's id, systemcode, unit
        next if (@args<=0);
        next if ($lh->{SYSCODE} ne $args[0]);
      }
      $chash = $lh;
      last;
    }
  }
  
  return () if (!defined($chash->{NAME}));
  
  readingsBeginUpdate($chash);
  readingsBulkUpdate($chash,"state",$state);
  readingsEndUpdate($chash, 1); 
  
  return $chash->{NAME};
}

#####################################
sub pilight_switch_Set($$)
{  
  my ($hash, $me, $cmd, @a) = @_;
  return "no set value specified" unless defined($cmd);
  
  my @match = grep( $_ =~ /^$cmd($|:)/, keys %sets );
  return SetExtensions($hash, join(" ", keys %sets), $me, $cmd, @a) unless @match == 1;
  return "$cmd expects $sets{$match[0]} parameters" unless (@a eq $sets{$match[0]});
  
  my $v = join(" ", @a);
  my $msg = "$me,$cmd";
  
  my $sndCount = AttrVal($me,"sendCount",1);
  for (my $i = 0; $i < $sndCount; $i++) {
    Log3 $me, 5, "$me(Set): $cmd $v".($i+1)." of $sndCount";
    IOWrite($hash, $msg);
  }
  
  #keinen Trigger bei Set auslösen
  #Aktualisierung erfolgt in Parse
  my $skipTrigger = 1; 
  return undef,$skipTrigger;
}


1;

=pod
=begin html

<a name="pilight_switch"></a>
<h3>pilight_switch</h3>
<ul>

  pilight_switch represents a switch controled with\from pilight<br>
  You have to define the base device pilight_ctrl first.<br>
  Further information to pilight: <a href="http://www.pilight.org/">http://www.pilight.org/</a><br>
  Supported switches: <a href="http://wiki.pilight.org/doku.php/protocols#switches">http://wiki.pilight.org/doku.php/protocols#switches</a><br>     
  <br>
  <a name="pilight_switch_define"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; pilight_switch protocol id unit</code>    
    <br><br>

    Example:
    <ul>
      <code>define myctrl pilight_switch kaku_switch_old 0 0</code><br>
    </ul>
  </ul>
  <br>
  <a name="pilight_switch_set"></a>
  <p><b>Set</b></p>
  <ul>
    <li>
      <b>on</b>
    </li>
    <li>
      <b>off</b>
    </li>
    <li>
      <a href="#setExtensions">set extensions</a> are supported<br>
    </li>
  </ul>
  <br>
  <a name="pilight_switch_readings"></a>
  <p><b>Readings</b></p>
  <ul>    
    <li>
      state<br>
      state of the switch on or off
    </li>
  </ul>
  <a name="pilight_switch_attr"></a>
  <b>Attributs</b>
  <ul>
    <li>
      IODev<br>
    </li>
    <li>
      sendCount<br>
      How many times the command is send. Default: 1
    </li>
  </ul>
  <br>
</ul>

=end html

=cut
