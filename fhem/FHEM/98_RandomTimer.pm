##########################################################################
# $Id: 98_RandomTimer.pm 20844 2019-12-28 19:10:02Z Beta-User $
#
# copyright ###################################################################
#
# 98_RandomTimer.pm
#
# written by Dietmar Ortmann
# Maintained by igami since 02-2018
#
# This file is part of FHEM.
#
# FHEM is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# FHEM is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with FHEM.  If not, see <http://www.gnu.org/licenses/>.

# packages ####################################################################
package main;
  use strict;
  use warnings;
    no if $] >= 5.017011, warnings => 'experimental::smartmatch';
  use Time::HiRes qw(gettimeofday);
  use Time::Local 'timelocal_nocheck';

# forward declarations ########################################################
sub RandomTimer_Initialize($);

sub RandomTimer_Define($$);
sub RandomTimer_Undef($$);
sub RandomTimer_Set($@);
sub RandomTimer_Attr($$$);

sub RandomTimer_addDays ($$);
sub RandomTimer_device_switch ($);
sub RandomTimer_device_toggle ($);
sub RandomTimer_disableDown($);
sub RandomTimer_down($);
sub RandomTimer_Exec($);
sub RandomTimer_getSecsToNextAbschaltTest($);
sub RandomTimer_isAktive ($);
sub RandomTimer_isDisabled($);
sub RandomTimer_schaltZeitenErmitteln ($$);
sub RandomTimer_setActive($$);
sub RandomTimer_setState($);
sub RandomTimer_setSwitchmode ($$);
sub RandomTimer_SetTimer($);
sub RandomTimer_startZeitErmitteln  ($$);
sub RandomTimer_stopTimeReached($);
sub RandomTimer_stopZeitErmitteln  ($$);
sub RandomTimer_Wakeup();
sub RandomTimer_zeitBerechnen  ($$$$);

# initialize ##################################################################
sub RandomTimer_Initialize($) {
  my ($hash) = @_;

  $hash->{DefFn}     = "RandomTimer_Define";
  $hash->{UndefFn}   = "RandomTimer_Undef";
  $hash->{SetFn}     = "RandomTimer_Set";
  $hash->{AttrFn}    = "RandomTimer_Attr";
  $hash->{AttrList}  = "onCmd offCmd switchmode disable:0,1 disableCond disableCondCmd:none,offCmd,onCmd ".
                       "runonce:0,1 keepDeviceAlive:0,1 forceStoptimeSameDay:0,1 ".
                       $readingFnAttributes;
}

# regular Fn ##################################################################
sub RandomTimer_Define($$) {
  my ($hash, $def) = @_;

  RemoveInternalTimer($hash);
  my ($name, $type, $timespec_start, $device, $timespec_stop, $timeToSwitch) =
    split("[ \t][ \t]*", $def);

  return "wrong syntax: define <name> RandomTimer <timespec_start> <device> <timespec_stop> <timeToSwitch>"
    if(!defined $timeToSwitch);

  return "Wrong timespec_start <$timespec_start>, use \"[+][*]<time or func>\""
     if($timespec_start !~ m/^(\+)?(\*)?(.*)$/i);

  my ($rel, $rep, $tspec) = ($1, $2, $3);

  my ($err, $hr, $min, $sec, $fn) = GetTimeSpec($tspec);
  return $err if($err);

  $rel = "" if(!defined($rel));
  $rep = "" if(!defined($rep));

  return "Wrong timespec_stop <$timespec_stop>, use \"[+][*]<time or func>\""
     if($timespec_stop !~ m/^(\+)?(\*)?(.*)$/i);
  my ($srel, $srep, $stspec) = ($1, $2, $3);
  my ($e, $h, $m, $s, $f) = GetTimeSpec($stspec);
  return $e if($e);

  return "invalid timeToSwitch <$timeToSwitch>, use 9999"
     if(!($timeToSwitch =~  m/^[0-9]{2,4}$/i));

  RandomTimer_setSwitchmode ($hash, "800/200") if (!defined $hash->{helper}{SWITCHMODE});

  $hash->{NAME}                   = $name;
  $hash->{DEVICE}                 = $device;
  $hash->{helper}{TIMESPEC_START} = $timespec_start;
  $hash->{helper}{TIMESPEC_STOP}  = $timespec_stop;
  $hash->{helper}{TIMETOSWITCH}   = $timeToSwitch;
  $hash->{helper}{REP}            = $rep;
  $hash->{helper}{REL}            = $rel;
  $hash->{helper}{S_REP}          = $srep;
  $hash->{helper}{S_REL}          = $srel;
  $hash->{COMMAND}                = Value($hash->{DEVICE});

  #$attr{$name}{verbose} = 4;

  readingsSingleUpdate ($hash,  "TimeToSwitch", $hash->{helper}{TIMETOSWITCH}, 1);

  RandomTimer_RemoveInternalTimer("SetTimer", $hash);
  RandomTimer_InternalTimer("SetTimer", time(), "RandomTimer_SetTimer", $hash, 0);

  return undef;
}

sub RandomTimer_Undef($$) {

  my ($hash, $arg) = @_;

  RandomTimer_RemoveInternalTimer("SetTimer", $hash);
  RandomTimer_RemoveInternalTimer("Exec",     $hash);
  delete $modules{RandomTimer}{defptr}{$hash->{NAME}};
  return undef;
}

sub RandomTimer_Attr($$$) {
  my ($cmd, $name, $attrName, $attrVal) = @_;

  my $hash = $defs{$name};

  if( $attrName ~~ ["switchmode"] ) {
     RandomTimer_setSwitchmode($hash, $attrVal);
  }

  if( $attrName ~~ ["disable","disableCond"] ) {

    # Schaltung vorziehen, damit bei einem disable abgeschaltet wird.
    RandomTimer_RemoveInternalTimer("Exec", $hash);
    RandomTimer_InternalTimer("Exec", time()+1, "RandomTimer_Exec", $hash, 0);
  }
  return undef;
}

sub RandomTimer_Set($@) {
  my ($hash, @a) = @_;

  return "no set value specified" if(int(@a) < 2);
  return "Unknown argument $a[1], choose one of execNow:noArg" if($a[1] eq "?");

  my $name = shift @a;
  my $v = join(" ", @a);

  if ($v eq "execNow") {
    Log3 ($hash, 3, "[$name] set $name $v");
    if (AttrVal($name, "disable", 0)) {
      Log3 ($hash, 3, "[$name] is disabled, set execNow not possible");
    } else {
      RandomTimer_RemoveInternalTimer("Exec", $hash);
      RandomTimer_InternalTimer("Exec", time()+1, "RandomTimer_Exec", $hash, 0);
    }
  }
  return undef;
}


# module Fn ###################################################################
sub RandomTimer_addDays ($$) {
   my ($now, $days) = @_;

   my @jetzt_arr = localtime($now);
   $jetzt_arr[3] += $days;
   my $next = timelocal_nocheck(@jetzt_arr);
   return $next;

}

sub RandomTimer_device_switch ($) {
   my ($hash) = @_;

   my $command = "set @ $hash->{COMMAND}";
   if ($hash->{COMMAND} eq "on") {
      $command = AttrVal($hash->{NAME}, "onCmd", $command);
   } else {
      $command = AttrVal($hash->{NAME}, "offCmd", $command);
   }
   $command =~ s/@/$hash->{DEVICE}/g;
   $command = SemicolonEscape($command);
   readingsSingleUpdate($hash, 'LastCommand', $command, 1);
   Log3 $hash, 4, "[".$hash->{NAME}. "]"." command: $command";

   my $ret  = AnalyzeCommandChain(undef, $command);
   Log3 ($hash, 3, "[$hash->{NAME}] ERROR: " . $ret . " SENDING " . $command) if($ret);
  #Log3  $hash, 3, "[$hash->{NAME}] Value($hash->{COMMAND})=".Value($hash->{DEVICE});
  #$hash->{"$hash->{COMMAND}Value"} = Value($hash->{DEVICE});
}

sub RandomTimer_device_toggle ($) {
    my ($hash) = @_;

    my $status = Value($hash->{DEVICE});
    if ($status ne "on" && $status ne "off" ) {
       Log3 $hash, 3, "[".$hash->{NAME}."]"." result of function Value($hash->{DEVICE}) must be 'on' or 'off'";
    }

    my $sigma = ($status eq "on")
       ? $hash->{helper}{SIGMAWHENON}
       : $hash->{helper}{SIGMAWHENOFF};

    my $zufall = int(rand(1000));
    Log3 $hash, 4,  "[".$hash->{NAME}."]"." IstZustand:$status sigmaWhen-$status:$sigma random:$zufall<$sigma=>" . (($zufall < $sigma)?"true":"false");

    if ($zufall < $sigma ) {
       $hash->{COMMAND}  = ($status eq "on") ? "off" : "on";
       RandomTimer_device_switch($hash);
    }
}

sub RandomTimer_disableDown($) {
   my ($hash) = @_;
   my $disableCondCmd = AttrVal($hash->{NAME}, "disableCondCmd", 0);
   
   if ($disableCondCmd ne "none") {
     Log3 $hash, 4, "[".$hash->{NAME}."]"." setting requested disableCondCmd on $hash->{DEVICE}: ";
     $hash->{COMMAND} = AttrVal($hash->{NAME}, "disableCondCmd", 0) eq "onCmd" ? "on" : "off";
     RandomTimer_device_switch($hash);
   } else {
     Log3 $hash, 4, "[".$hash->{NAME}."]"." no action requested on $hash->{DEVICE}: ";
   }
}

sub RandomTimer_down($) {
   my ($hash) = @_;
   Log3 $hash, 4, "[".$hash->{NAME}."]"." setting requested keepDeviceAlive on $hash->{DEVICE}: ";
   $hash->{COMMAND} = AttrVal($hash->{NAME}, "keepDeviceAlive", 0) ? "on" : "off";
   RandomTimer_device_switch($hash);
}


sub RandomTimer_Exec($) {
   my ($myHash) = @_;

   my $hash = RandomTimer_GetHashIndirekt($myHash, (caller(0))[3]);
   return if (!defined($hash));

   my $now = time();

   # Wenn aktiv aber disabled, dann timer abschalten, Meldung ausgeben.
   my $active          = RandomTimer_isAktive($hash);
   my $disabled        = RandomTimer_isDisabled($hash);
   my $stopTimeReached = RandomTimer_stopTimeReached($hash);

   if ($active) {
      # wenn temporär ausgeschaltet
      if ($disabled) {
        Log3 $hash, 3, "[".$hash->{NAME}."]"." disabled before stop-time , ending RandomTimer on $hash->{DEVICE}: "
          . strftime("%H:%M:%S(%d)",localtime($hash->{helper}{startTime})) . " - "
          . strftime("%H:%M:%S(%d)",localtime($hash->{helper}{stopTime}));
        RandomTimer_disableDown($hash);
        RandomTimer_setActive($hash,0);
        RandomTimer_setState ($hash);
      }
      # Wenn aktiv und Abschaltzeit erreicht, dann Gerät ausschalten, Meldung ausgeben und Timer schließen
      if ($stopTimeReached) {
         Log3 $hash, 3, "[".$hash->{NAME}."]"." stop-time reached, ending RandomTimer on $hash->{DEVICE}: "
            . strftime("%H:%M:%S(%d)",localtime($hash->{helper}{startTime})) . " - "
            . strftime("%H:%M:%S(%d)",localtime($hash->{helper}{stopTime}));
         RandomTimer_down($hash);
         RandomTimer_setActive($hash, 0);
         if ( AttrVal($hash->{NAME}, "runonce", -1) eq 1 ) {
            Log 3, "[".$hash->{NAME}. "]" ."runonceMode";
            fhem ("delete $hash->{NAME}") ;
         }
         RandomTimer_setState($hash);
         return;
      }
   } else { # !active
      if ($disabled) {
         Log3 $hash, 4, "[".$hash->{NAME}. "] RandomTimer on $hash->{DEVICE} timer disabled - no switch";
         RandomTimer_setState($hash);
         RandomTimer_setActive($hash,0);
      }
      if ($stopTimeReached) {
         Log3 $hash, 4, "[".$hash->{NAME}."]"." definition RandomTimer on $hash->{DEVICE}: "
            . strftime("%H:%M:%S(%d)",localtime($hash->{helper}{startTime})) . " - "
            . strftime("%H:%M:%S(%d)",localtime($hash->{helper}{stopTime}));
         RandomTimer_setState ($hash);
         RandomTimer_setActive($hash,0);
         return;
      }
      if (!$disabled) {
         if ($now>$hash->{helper}{startTime} && $now<$hash->{helper}{stopTime}) {
            Log3 $hash, 3, "[".$hash->{NAME}."]"." starting RandomTimer on $hash->{DEVICE}: "
               . strftime("%H:%M:%S(%d)",localtime($hash->{helper}{startTime})) . " - "
               . strftime("%H:%M:%S(%d)",localtime($hash->{helper}{stopTime}));
            RandomTimer_setActive($hash,1);
         }
      }
   }

   RandomTimer_setState($hash);
   if ($now>$hash->{helper}{startTime} && $now<$hash->{helper}{stopTime}) {
      RandomTimer_device_toggle($hash) if (!$disabled);
   }

   my $nextSwitch = time() + RandomTimer_getSecsToNextAbschaltTest($hash);
   RandomTimer_RemoveInternalTimer("Exec", $hash);
   RandomTimer_InternalTimer("Exec", $nextSwitch, "RandomTimer_Exec", $hash, 0);

}

sub RandomTimer_getSecsToNextAbschaltTest($) {
    my ($hash) = @_;
    my $intervall = $hash->{helper}{TIMETOSWITCH};

    my $proz = 10;
    my $delta    = $intervall * $proz/100;
    my $nextSecs = $intervall - $delta/2 + int(rand($delta));

    return $nextSecs;
}

sub RandomTimer_isAktive ($) {
   my ($hash) = @_;
   return defined ($hash->{helper}{active}) ? $hash->{helper}{active}  : 0;
}

sub RandomTimer_isDisabled($) {
   my ($hash) = @_;

   my $disable = AttrVal($hash->{NAME}, "disable", 0 );
   return $disable if($disable);

   my $disableCond = AttrVal($hash->{NAME}, "disableCond", "nf" );
   if ($disableCond eq "nf") {
     return 0;
   } else {
      $disable = eval ($disableCond);
      if ($@) {
         $@ =~ s/\n/ /g;
         Log3 ($hash, 3, "[$hash->{NAME}] ERROR: " . $@ . " EVALUATING " . $disableCond);
      }
      return $disable;
   }
}

sub RandomTimer_schaltZeitenErmitteln ($$) {
  my ($hash,$now) = @_;

  RandomTimer_startZeitErmitteln($hash, $now);
  RandomTimer_stopZeitErmitteln ($hash, $now);

  readingsBeginUpdate($hash);
#  readingsBulkUpdate ($hash,  "Startzeit", FmtDateTime($hash->{helper}{startTime}));
#  readingsBulkUpdate ($hash,  "Stoppzeit", FmtDateTime($hash->{helper}{stopTime}));
  readingsBulkUpdate ($hash,  "StartTime", FmtDateTime($hash->{helper}{startTime}));
  readingsBulkUpdate ($hash,  "StopTime", FmtDateTime($hash->{helper}{stopTime}));
  readingsEndUpdate  ($hash,  defined($hash->{LOCAL} ? 0 : 1));

}

sub RandomTimer_setActive($$) {
   my ($hash, $value) = @_;
   $hash->{helper}{active} = $value;
   my $trigger = (RandomTimer_isDisabled($hash)) ? 0 : 1;
   readingsSingleUpdate ($hash,  "active", $value, $trigger);
}

sub RandomTimer_setState($) {
  my ($hash) = @_;

  if (RandomTimer_isDisabled($hash)) {
     my $dotrigger = ReadingsVal($hash->{NAME},"state","none") ne "disabled" ? 1 : 0;
     readingsSingleUpdate ($hash,  "state",  "disabled", $dotrigger);
  } else {
     my $state = $hash->{helper}{active} ? "on" : "off";
     readingsSingleUpdate ($hash,  "state", $state,  1);
  }

}

sub RandomTimer_setSwitchmode ($$) {

   my ($hash, $attrVal) = @_;
   my $mod = "[".$hash->{NAME} ."] ";


   if(!($attrVal =~  m/^([0-9]{1,3})\/([0-9]{1,3})$/i)) {
      Log3 undef, 3, $mod . "invalid switchMode <$attrVal>, use 999/999";
   } else {
      my ($sigmaWhenOff, $sigmaWhenOn) = ($1, $2);
      $hash->{helper}{SWITCHMODE}    = $attrVal;
      $hash->{helper}{SIGMAWHENON}   = $sigmaWhenOn;
      $hash->{helper}{SIGMAWHENOFF}  = $sigmaWhenOff;
      $attr{$hash->{NAME}}{switchmode} = $attrVal;
   }
}

sub RandomTimer_SetTimer($) {
  my ($myHash) = @_;
  my $hash = RandomTimer_GetHashIndirekt($myHash, (caller(0))[3]);
  return if (!defined($hash));

  my $now = time();
  my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime($now);

  RandomTimer_setActive($hash, 0);
  RandomTimer_schaltZeitenErmitteln($hash, $now);
  RandomTimer_setState($hash);

  Log3 $hash, 4, "[".$hash->{NAME}."]" . " timings  RandomTimer on $hash->{DEVICE}: "
   . strftime("%H:%M:%S(%d)",localtime($hash->{helper}{startTime})) . " - "
   . strftime("%H:%M:%S(%d)",localtime($hash->{helper}{stopTime}));

  my $secToMidnight = 24*3600 -(3600*$hour + 60*$min + $sec);

  my $setExecTime = max($now, $hash->{helper}{startTime});
  RandomTimer_RemoveInternalTimer("Exec",     $hash);
  RandomTimer_InternalTimer("Exec",     $setExecTime, "RandomTimer_Exec", $hash, 0);

  if ($hash->{helper}{REP} gt "") {
     my $setTimerTime = max($now+$secToMidnight + 15,
                            $hash->{helper}{stopTime}) + $hash->{helper}{TIMETOSWITCH}+15;
     RandomTimer_RemoveInternalTimer("SetTimer", $hash);
     RandomTimer_InternalTimer("SetTimer", $setTimerTime, "RandomTimer_SetTimer", $hash, 0);
  }
}

sub RandomTimer_startZeitErmitteln  ($$) {
   my ($hash,$now) = @_;

   my $timespec_start = $hash->{helper}{TIMESPEC_START};

   return "Wrong timespec_start <$timespec_start>, use \"[+][*]<time or func>\""
      if($timespec_start !~ m/^(\+)?(\*)?(.*)$/i);
   my ($rel, $rep, $tspec) = ($1, $2, $3);

   my ($err, $hour, $min, $sec, $fn) = GetTimeSpec($tspec);
   return $err if($err);

   my $startTime;
   if($rel) {
      $startTime = $now + 3600* $hour        + 60* $min       +  $sec;
   } else {
      $startTime = RandomTimer_zeitBerechnen($now, $hour, $min, $sec);
   }
   $hash->{helper}{startTime} = $startTime;
   $hash->{helper}{STARTTIME} = strftime("%d.%m.%Y  %H:%M:%S",localtime($startTime));
}

sub RandomTimer_stopTimeReached($) {
   my ($hash) = @_;
   return ( time()>$hash->{helper}{stopTime} );
}

sub RandomTimer_stopZeitErmitteln  ($$) {
   my ($hash,$now) = @_;

   my $timespec_stop = $hash->{helper}{TIMESPEC_STOP};

   return "Wrong timespec_stop <$timespec_stop>, use \"[+][*]<time or func>\""
      if($timespec_stop !~ m/^(\+)?(\*)?(.*)$/i);
   my ($rel, $rep, $tspec) = ($1, $2, $3);

   my ($err, $hour, $min, $sec, $fn) = GetTimeSpec($tspec);
   return $err if($err);

   my $stopTime;
   if($rel) {
      $stopTime = $hash->{helper}{startTime} + 3600* $hour        + 60* $min       +  $sec;
   } else {
      $stopTime = RandomTimer_zeitBerechnen($now, $hour, $min, $sec);
   }

   if (!AttrVal($hash->{NAME}, "forceStoptimeSameDay", 0)) {
      if ($hash->{helper}{startTime} > $stopTime) {
         $stopTime  = RandomTimer_addDays($stopTime, 1);
      }
   }
   $hash->{helper}{stopTime} = $stopTime;
   $hash->{helper}{STOPTIME} = strftime("%d.%m.%Y  %H:%M:%S",localtime($stopTime));

}

sub RandomTimer_Wakeup() {  # {RandomTimer_Wakeup()}

  foreach my $hc ( sort keys %{$modules{RandomTimer}{defptr}} ) {
     my $hash = $modules{RandomTimer}{defptr}{$hc};

     my $myHash->{HASH}=$hash;
     RandomTimer_SetTimer($myHash);
     Log3 undef, 3, "RandomTimer_Wakeup() for $hash->{NAME} done!";
  }
  Log3 undef,  3, "RandomTimer_Wakeup() done!";
}

sub RandomTimer_zeitBerechnen  ($$$$) {
   my ($now, $hour, $min, $sec) = @_;

   my @jetzt_arr = localtime($now);
   #Stunden               Minuten               Sekunden
   $jetzt_arr[2] = $hour; $jetzt_arr[1] = $min; $jetzt_arr[0] = $sec;
   my $next = timelocal_nocheck(@jetzt_arr);
   return $next;
}

sub RandomTimer_InternalTimer($$$$$) {
   my ($modifier, $tim, $callback, $hash, $waitIfInitNotDone) = @_;

   my $timerName = "$hash->{NAME}_$modifier";
   my $mHash = { HASH=>$hash, NAME=>"$hash->{NAME}_$modifier", MODIFIER=>$modifier};
   if (defined($hash->{TIMER}{$timerName})) {
      Log3 $hash, 1, "[$hash->{NAME}] possible overwriting of timer $timerName - please delete first";
      stacktrace();
   } else {
      $hash->{TIMER}{$timerName} = $mHash;
   }

   Log3 $hash, 5, "[$hash->{NAME}] setting  Timer: $timerName " . FmtDateTime($tim);
   InternalTimer($tim, $callback, $mHash, $waitIfInitNotDone);
   return $mHash;
}
################################################################################
sub RandomTimer_RemoveInternalTimer($$) {
   my ($modifier, $hash) = @_;

   my $timerName = "$hash->{NAME}_$modifier";
   my $myHash = $hash->{TIMER}{$timerName};
   if (defined($myHash)) {
      delete $hash->{TIMER}{$timerName};
      Log3 $hash, 5, "[$hash->{NAME}] removing Timer: $timerName";
      RemoveInternalTimer($myHash);
   }
}

sub RandomTimer_GetHashIndirekt ($$) {
  my ($myHash, $function) = @_;

  if (!defined($myHash->{HASH})) {
    Log 3, "[$function] myHash not valid";
    return undef;
  };
  return $myHash->{HASH};
}

1;

# commandref ##################################################################
=pod
=encoding utf8
=item helper
=item summary    imitates the random switch functionality of a timer clock (FS20 ZSU)
=item summary_DE bildet die Zufallsfunktion einer Zeitschaltuhr nach

=begin html

<a name="RandomTimer"></a>
<h3>RandomTimer</h3>
<div>
  <ul>
    <a name="RandomTimerdefine"></a>
    <b>Define</b>
    <ul>
      <code>
        define &lt;name&gt; RandomTimer  &lt;timespec_start&gt; &lt;device&gt; &lt;timespec_stop&gt; &lt;timeToSwitch&gt;
      </code>
      <br>
      Defines a device, that imitates the random switch functionality of a timer clock, like a <b>FS20 ZSU</b>. The idea to create it, came from the problem, that is was always a little bit tricky to install a timer clock before holiday: finding the manual, testing it the days before and three different timer clocks with three different manuals - a horror.<br>
      By using it in conjunction with a dummy and a disableCond, I'm able to switch the always defined timer on every weekend easily from all over the world.<br>
      <br>
      <b>Description</b>
      <ul>
        a RandomTimer device starts at timespec_start switching device. Every (timeToSwitch seconds +-10%) it trys to switch device on/off. The switching period stops when the next time to switch is greater than timespec_stop.
      </ul>
      <br>
      <b>Parameter</b>
      <ul>
        <li>
          <code>timespec_start</code><br>
          The parameter <b>timespec_start</b> defines the start time of the timer with format: HH:MM:SS. It can be a Perlfunction as known from the <a href="#at">at</a> timespec.
        </li><br>
        <li>
          <code>device</code><br>
          The parameter <b>device</b> defines the fhem device that should be switched.
        </li><br>
        <li>
          <code>timespec_stop</code><br>
          The parameter <b>timespec_stop</b> defines the stop time of the timer with format: HH:MM:SS. It can be a Perlfunction as known from the timespec <a href="#at">at</a>.
        </li><br>
        <li>
          <code>timeToSwitch</code><br>
          The parameter <b>timeToSwitch</b> defines the time in seconds between two on/off switches.
        </li>
      </ul>
      <br>
      <b>Examples</b>
      <ul>
        <li>
          <code>
            define ZufallsTimerTisch RandomTimer *{sunset_abs()} StehlampeTisch +03:00:00 500
          </code><br>
          defines a timer that starts at sunset an ends 3 hous later. The timer trys to switch every 500 seconds(+-10%).
        </li><br>
        <li>
          <code>
            define ZufallsTimerTisch RandomTimer *{sunset_abs()} StehlampeTisch *{sunset_abs(3*3600)} 480
          </code><br>
          defines a timer that starts at sunset and stops after sunset + 3 hours. The timer trys to switch every 480 seconds(+-10%).
        </li><br>
        <li>
          <code>
            define ZufallsTimerTisch RandomTimer *{sunset_abs()} StehlampeTisch 22:30:00 300
          </code><br>
          defines a timer that starts at sunset an ends at 22:30. The timer trys to switch every 300 seconds(+-10%).
        </li>
      </ul>
    </ul>
  </ul>
   <br>
   <ul>
     <a name="RandomTimerset"></a>
     <b>Set</b><br>
     <ul>
	   <code>set &lt;name&gt; execNow</code>
     <br>
	 This will force the RandomTimer device to immediately execute the next switch instead of waiting untill timeToSwitch has passed. Use this in case you want immediate reaction on changes of reading values factored in disableCond. As RandomTimer itself will not be notified about any event at all, you'll need an additional event handler like notify that listens to relevant events and issues the "execNow" command towards your RandomTimer device(s).
	 </ul>
   </ul><br>  

   <ul>  
    <a name="RandomTimerAttributes"></a>
    <b>Attributes</b>
    <ul>
      <li>
        <code>disableCond</code><br>
        The default behavior of a RandomTimer is, that it works. To set the Randomtimer out of work, you can specify in the disableCond attibute a condition in perlcode that must evaluate to true. The Condition must be put into round brackets. The best way is to define a function in 99_utils.<br>
        <br>
        <b>Examples</b>
        <ul>
          <li><code>
            attr ZufallsTimerZ disableCond (!isVerreist())
          </code></li>
          <li><code>
            attr ZufallsTimerZ disableCond (Value("presenceDummy") eq "present")
          </code></li>
        </ul>
      </li>
      <br>
      <li>
        <code>forceStoptimeSameDay</code><br>
        When <b>timespec_start</b> is later then <b>timespec_stop</b>, it forces the <b>timespec_stop</b> to end on the current day instead of the next day. See <a href="https://forum.fhem.de/index.php/topic,72988.0.html" title="Random Timer in Verbindung mit Twilight, EIN-Schaltzeit nach AUS-Schaltzeit">forum post</a> for use case.<br>
      </li>
      <br>
      <li>
        <code>keepDeviceAlive</code><br>
        The default behavior of a RandomTimer is, that it shuts down the device after stoptime is reached. The <b>keepDeviceAlive</b> attribute changes the behavior. If set, the device status is not changed when the stoptime is reached.<br>
        <br>
        <b>Examples</b>
        <ul>
          <li><code>attr ZufallsTimerZ keepDeviceAlive</code></li>
        </ul>
      </li>
	  <br>
	  <li>
        <code>disableCondCmd</code><br>
        In case the disable condition becomes true while a RandomTimer is already <b>running</b>, by default the same action is executed as when stoptime is reached (see keepDeviceAlive attribute). Setting the <b>disableCondCmd</b> attribute changes this as follows: "none" will lead to no action, "offCmd" means "use off command", "onCmd" will lead to execution of the "on command". Delete the attribute to get back to default behaviour.<br>
		<br>
        <b>Examples</b>
        <ul>
          <li><code>attr ZufallsTimerZ disableCondCmd offCmd</code></li>
        </ul>
      </li>
      <br>
      <li>
        <code>onCmd, offCmd</code><br>
        Setting the on-/offCmd changes the command sent to the device. Standard is: "set &lt;device&gt; on". The device can be specified by a @.<br>
        <br>
        <b>Examples</b>
        <ul>
          <li><code>
            attr Timer oncmd  {fhem("set @ on-for-timer 14")}
          </code></li>
          <li><code>
            attr Timer offCmd {fhem("set @ off 16")}
          </code></li>
          <li><code>
            attr Timer oncmd  set @ on-for-timer 12
          </code></li>
          <li><code>
            attr Timer offCmd set @ off 12
          </code></li>
        </ul>
        The decision to switch on or off depends on the state of the device and is evaluated by the funktion Value(&lt;device&gt;). Value() must evaluate one of the values "on" or "off". The behavior of devices that do not evaluate one of those values can be corrected by defining a stateFormat:<br>
        <code>
           attr stateFormat EDIPlug_01 {(ReadingsVal("EDIPlug_01","state","nF") =~ m/(ON|on)/i)  ? "on" : "off" }
        </code><br>
        if a devices Value() funktion does not evalute to on or off(like WLAN-Steckdose von Edimax) you get the message:<br>
        <code>
           [EDIPlug] result of function Value(EDIPlug_01) must be 'on' or 'off'
        </code>
      </li>
      <br>
      <li>
        <a href="#readingFnAttributes">
          <u><code>readingFnAttributes</code></u>
        </a>
      </li>
      <br>
      <li>
        <code>runonce</code><br>
        Deletes the RandomTimer device after <b>timespec_stop</b> is reached.
        <br>
      </li>
      <br>
      <li>
        <code>switchmode</code><br>
        Setting the switchmode you can influence the behavior of switching on/off. The parameter has the Format 999/999 and the default ist 800/200. The values are in "per mill". The first parameter sets the value of the probability that the device will be switched on when the device is off. The second parameter sets the value of the probability that the device will be switched off when the device is on.<br>
        <br>
        <b>Examples</b>
        <ul>
          <li><code>attr ZufallsTimerZ switchmode 400/400</code></li>
        </ul>
      </li>
    </ul>
  </ul>
</div>

=end html

=for :application/json;q=META.json 98_RandomTimer.pm
{
   "abstract" : "imitates the random switch functionality of a timer clock (FS20 ZSU)",
   "x_lang" : {
      "de" : {
         "abstract" : "bildet die Zufallsfunktion einer Zeitschaltuhr nach"
      }
   },
   "keywords" : [
   ],
   "prereqs" : {
      "runtime" : {
         "requires" : {
            "Time::HiRes" : "0",
            "Time::Local" : "0",
            "strict" : "0",
            "warnings" : "0"
         }
      }
   }
}
=end :application/json;q=META.json

=cut
