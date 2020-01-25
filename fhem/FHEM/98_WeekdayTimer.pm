# $Id: 98_WeekdayTimer.pm 20769 2019-12-17 06:12:03Z Beta-User $
##############################################################################
#
#     98_WeekdayTimer.pm
#     written by Dietmar Ortmann
#     modified by Tobias Faust
#     Maintained by igami since 02-2018
#     Thanks Dietmar for all you did for FHEM, RIP
#
#     This file is part of fhem.
#
#     Fhem is free software: you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation, either version 2 of the License, or
#     (at your option) any later version.
#
#     Fhem is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
#
#     You should have received a copy of the GNU General Public License
#     along with fhem.  If not, see <http://www.gnu.org/licenses/>.
#
##############################################################################
##############################################################################
package main;
use strict;
use warnings;
use POSIX;

use Time::Local 'timelocal_nocheck';

use Data::Dumper;
$Data::Dumper::Sortkeys = 1;

################################################################################
sub WeekdayTimer_Initialize($){
  my ($hash) = @_;

# Consumer
  $hash->{SetFn}   = "WeekdayTimer_Set";
  $hash->{DefFn}   = "WeekdayTimer_Define";
  $hash->{UndefFn} = "WeekdayTimer_Undef";
  $hash->{GetFn}   = "WeekdayTimer_Get";
  $hash->{AttrFn}  = "WeekdayTimer_Attr";
  $hash->{UpdFn}   = "WeekdayTimer_Update";
  $hash->{AttrList}= "disable:0,1 delayedExecutionCond WDT_delayedExecutionDevices WDT_Group switchInThePast:0,1 commandTemplate ".
     $readingFnAttributes;
}
################################################################################
sub WeekdayTimer_Define($$) {
  my ($hash, $def) = @_;
  WeekdayTimer_InitHelper($hash);
  my  @a = split("[ \t\\\n]+", $def);

  return "Usage: define <name> $hash->{TYPE} <device> <language> <switching times> <condition|command>"
     if(@a < 4);

  #fuer den modify Altlasten bereinigen
  delete($hash->{helper});

  my $name     = shift @a;
  my $type     = shift @a;
  my $device   = shift @a;

  WeekdayTimer_DeleteTimer($hash);
  my $delVariables = "(CONDITION|COMMAND|profile|Profil)";
  map { delete $hash->{$_} if($_=~ m/^$delVariables.*/g) }  keys %{$hash};

  $hash->{NAME}            = $name;
  $hash->{DEVICE}          = $device;
  my $language = WeekdayTimer_Language  ($hash, \@a);
  
  InternalTimer(time(), "WeekdayTimer_Start",$hash,0);
  
  return undef;
}
################################################################################
sub WeekdayTimer_Undef($$) {
  my ($hash, $arg) = @_;

  foreach my $idx (keys %{$hash->{profil}}) {
     WeekdayTimer_RemoveInternalTimer($idx, $hash);
  }
  WeekdayTimer_RemoveInternalTimer("SetTimerOfDay", $hash);
  delete $modules{$hash->{TYPE}}{defptr}{$hash->{NAME}};
  return undef;
}
################################################################################
sub WeekdayTimer_Start($) {
  my ($hash) = @_;
  my $name = $hash->{NAME};
  my @a = split("[ \t\\\n]+", $hash->{DEF});
  my $device   = shift @a;

  my $language = WeekdayTimer_Language  ($hash, \@a);

  my $idx = 0;
  $hash->{dayNumber}    = {map {$_ => $idx++}     @{$hash->{shortDays}{$language}}};
  $hash->{helper}{daysRegExp}        = '(' . join ("|",        @{$hash->{shortDays}{$language}}) . ")";
  $hash->{helper}{daysRegExpMessage} = $hash->{helper}{daysRegExp};

  $hash->{helper}{daysRegExp}   =~ s/\$/\\\$/g;
  $hash->{helper}{daysRegExp}   =~ s/\!/\\\!/g;

  WeekdayTimer_GlobalDaylistSpec ($hash, \@a);

  my @switchingtimes       = WeekdayTimer_gatherSwitchingTimes ($hash, \@a);
  my $conditionOrCommand   = join (" ", @a);

  # test if device is defined
  Log3 ($hash, 3, "[$name] device <$device> in fhem not defined, but accepted") if(!$defs{$device});

  # wenn keine switchintime angegeben ist, dann Fehler
  Log3 ($hash, 3, "[$name] no valid Switchingtime found in <$conditionOrCommand>, check first parameter")  if (@switchingtimes == 0);

  $hash->{STILLDONETIME}  = 0;
  $hash->{SWITCHINGTIMES} = \@switchingtimes;
  $attr{$name}{verbose}   = 5 if (!defined $attr{$name}{verbose} && $name =~ m/^tst.*/ );
  $defs{$device}{STILLDONETIME} = 0 if($defs{$device});

  $modules{$hash->{TYPE}}{defptr}{$hash->{NAME}} = $hash;

  $hash->{CONDITION}  = ""; $hash->{COMMAND}    = "";
  if($conditionOrCommand =~  m/^\(.*\)$/g) {         #condition (*)
     $hash->{CONDITION} = $conditionOrCommand;
  } elsif(length($conditionOrCommand) > 0 ) {
     $hash->{COMMAND} = $conditionOrCommand;
  }

  WeekdayTimer_Profile    ($hash);
  delete $hash->{VERZOEGRUNG};
  delete $hash->{VERZOEGRUNG_IDX};

  $attr{$name}{commandTemplate} =
     'set $NAME '. WeekdayTimer_isHeizung($hash) .' $EVENT' if (!defined $attr{$name}{commandTemplate});

  WeekdayTimer_SetTimerOfDay({ HASH => $hash});

  return undef;
}
################################################################################
sub WeekdayTimer_Set($@) {
  my ($hash, @a) = @_;

  return "no set value specified" if(int(@a) < 2);
  return "Unknown argument $a[1], choose one of enable:noArg disable:noArg WDT_Params:single,WDT_Group,all weekprofile" if($a[1] eq "?");

  my $name = shift @a;
  my $v = join(" ", @a);

  if ($v eq "enable") {
    Log3 ($hash, 3, "[$name] set $name $v");
    if (AttrVal($name, "disable", 0)) {
      CommandAttr(undef, "$name disable 0");
    } else {
      WeekdayTimer_SetTimerOfDay({ HASH => $hash});
    }
  } elsif ($v eq "disable") {
    Log3 $hash, 3, "[$name] set $name $v";
     CommandAttr(undef, "$name disable 1");
  } elsif ($v =~ m/WDT_Params/) {
    if ($v =~ /single/) {
      WeekdayTimer_SetParm($name);
      Log3 ($hash, 4, "[$name] set $name $v called");
    } elsif ($v =~ /WDT_Group/) {
      my $group = AttrVal($hash->{NAME},"WDT_Group",undef);
      unless (defined $group ){
         Log3 $hash, 3, "[$name] set $name $v cancelled: group attribute not set for $name!";
      } else {
         WeekdayTimer_SetAllParms($group);
      }
    } elsif ($v =~ /all/){
      WeekdayTimer_SetAllParms("all");
      Log3 $hash,3, "[$name] set $name $v called; params in all WeekdayTimer instances will be set!";
    } 
  } elsif ($v =~ /weekprofile ([^: ]+):([^:]+):([^: ]+)\b/) {
    Log3 $hash, 3, "[$name] set $name $v";
    return unless WeekdayTimer_UpdateWeekprofileReading($hash, $1, $2, $3);	
    WeekdayTimer_Start($hash);
  }
  return undef;
}
################################################################################
sub WeekdayTimer_Get($@) {
  my ($hash, @a) = @_;
  return "argument is missing" if(int(@a) != 2);

  $hash->{LOCAL} = 1;
  delete $hash->{LOCAL};
  my $reading= $a[1];
  my $value;

  if(defined($hash->{READINGS}{$reading})) {
    $value= $hash->{READINGS}{$reading}{VAL};
  } else {
    return "no such reading: $reading";
  }
  return "$a[0] $reading => $value";
}
################################################################################
sub WeekdayTimer_GetHashIndirekt ($$) {
  my ($myHash, $function) = @_;

  if (!defined($myHash->{HASH})) {
    Log 3, "[$function] myHash not valid";
    return undef;
  };
  return $myHash->{HASH};
}
################################################################################
sub WeekdayTimer_InternalTimer($$$$$) {
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
sub WeekdayTimer_RemoveInternalTimer($$) {
   my ($modifier, $hash) = @_;

   my $timerName = "$hash->{NAME}_$modifier";
   my $myHash = $hash->{TIMER}{$timerName};
   if (defined($myHash)) {
      delete $hash->{TIMER}{$timerName};
      Log3 $hash, 5, "[$hash->{NAME}] removing Timer: $timerName";
      RemoveInternalTimer($myHash);
   }
}
################################################################################
sub WeekdayTimer_InitHelper($) {
  my ($hash) = @_;

  $hash->{longDays} =  { "de" => ["Sonntag",  "Montag","Dienstag","Mittwoch",  "Donnerstag","Freitag", "Samstag",  "Wochenende", "Werktags" ],
                         "en" => ["Sunday",   "Monday","Tuesday", "Wednesday", "Thursday",  "Friday",  "Saturday", "weekend",    "weekdays" ],
                         "fr" => ["Dimanche", "Lundi", "Mardi",   "Mercredi",  "Jeudi",     "Vendredi","Samedi",   "weekend",    "jours de la semaine"],
                         "nl" => ["Zondag", "Maandag", "Dinsdag", "Woensdag", "Donderdag", "Vrijdag", "Zaterdag", "weekend", "werkdagen"]};
  $hash->{shortDays} = { "de" => ["so","mo","di","mi","do","fr","sa",'$we','!$we'],
                         "en" => ["su","mo","tu","we","th","fr","sa",'$we','!$we'],
                         "fr" => ["di","lu","ma","me","je","ve","sa",'$we','!$we'],
                         "nl" => ["zo","ma","di","wo","do","vr","za",'$we','!$we']};
}
################################################################################
sub WeekdayTimer_Profile($) {
  my $hash = shift;

  my $language =   $hash->{LANGUAGE};
  my %longDays = %{$hash->{longDays}};

  delete $hash->{profil};
  my $now = time();
  my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime($now);
    
# ---- Zeitpunkte den Tagen zuordnen -----------------------------------
  my $idx = 0;
  foreach  my $st (@{$hash->{SWITCHINGTIMES}}) {
    my ($tage,$time,$parameter,$overrulewday) = WeekdayTimer_SwitchingTime ($hash, $st);

    
    $idx++;
    foreach  my $d (@{$tage}) {
      my    @listeDerTage = ($d);
      push  (@listeDerTage, WeekdayTimer_getListeDerTage($hash, $d, $time)) if ($d>=7);
      
      map { my $day = $_;
        my $dayOfEchteZeit = $day;
        #####
        if ($day < 7) {
          my $relativeDay = $day - $wday; 
          $relativeDay = $relativeDay + 7 if $relativeDay < 0 ;
          $dayOfEchteZeit = undef if ($hash->{helper}{WEDAYS}{$relativeDay} && $overrulewday);
        }
        $dayOfEchteZeit = ($wday>=1&&$wday<=5) ? 6 : $wday  if ($day==7); # ggf. Samstag $wday ~~ [1..5]
        $dayOfEchteZeit = ($wday==0||$wday==6) ? 1 : $wday  if ($day==8); # ggf. Montag  $wday ~~ [0, 6]
        if (defined $dayOfEchteZeit) { 
          my $echtZeit = WeekdayTimer_EchteZeit($hash, $dayOfEchteZeit, $time);
          $hash->{profile}    {$day}{$echtZeit} = $parameter;
          $hash->{profile_IDX}{$day}{$echtZeit} = $idx;
        }
      } @listeDerTage;
    }
  }
# ---- Zeitpunkte des aktuellen Tages mit EPOCH ermitteln --------------
  $idx = 0;
  foreach  my $st (@{$hash->{SWITCHINGTIMES}}) {
    my ($tage,$time,$parameter,$overrulewday)       = WeekdayTimer_SwitchingTime ($hash, $st);
    my $echtZeit                      = WeekdayTimer_EchteZeit     ($hash, $wday, $time);
    my ($stunde, $minute, $sekunde)   = split (":",$echtZeit);

    $idx++;
    $hash->{profil}{$idx}{TIME}  = $time;
    $hash->{profil}{$idx}{PARA}  = $parameter;
    $hash->{profil}{$idx}{EPOCH} = WeekdayTimer_zeitErmitteln ($now, $stunde, $minute, $sekunde, 0);
    $hash->{profil}{$idx}{TAGE}  = $tage;
    $hash->{profil}{$idx}{WE_Override} = $overrulewday;
  }
# ---- Texte Readings aufbauen -----------------------------------------
  Log3 $hash, 4,  "[$hash->{NAME}] " . sunrise_abs() . " " . sunset_abs() . " " . $longDays{$language}[$wday];
  foreach  my $d (sort keys %{$hash->{profile}}) {
    my $profiltext = "";
    foreach  my $t (sort keys %{$hash->{profile}{$d}}) {
      $profiltext .= "$t " .  $hash->{profile}{$d}{$t} . ", ";
    }
    my $profilKey  = "Profil $d: $longDays{$language}[$d]";
    $profiltext =~ s/, $//;
    $hash->{$profilKey} = $profiltext;
    Log3 $hash, 4,  "[$hash->{NAME}] $profiltext ($profilKey)";
  }

  # für logProxy umhaengen
  $hash->{helper}{SWITCHINGTIME} = $hash->{profile};
  delete $hash->{profile};
}
################################################################################
sub WeekdayTimer_getListeDerTage($$$) {
  my ($hash, $d, $time) = @_;
  my %hdays=();
  unless (AttrVal('global', 'holiday2we', '') =~ m,\bweekEnd\b,) {
    @hdays{(0, 6)} = undef  if ($d==7); # sa,so   ( $we)
    @hdays{(1..5)} = undef  if ($d==8); # mo-fr   (!$we)
  } else {
    @hdays{(0..6)} = undef  if ($d==8); # mo-fr   (!$we)
  }
  my ($sec,$min,$hour,$mday,$mon,$year,$nowWday,$yday,$isdst) = localtime(time());
  for (my $i=0;$i<=6;$i++) {
    my $relativeDay = $i - $nowWday; 
    $relativeDay = $relativeDay + 7 if $relativeDay < 0 ;
    if ($hash->{helper}{WEDAYS}{$relativeDay}) {
      $hdays{$i} = undef if ($d==7); # $we Tag aufnehmen
      delete $hdays{$i} if ($d==8);  # !$we Tag herausnehmen
    }
  }

  #Log 3, "result------------>" . join (" ", sort keys %hdays);
  return keys %hdays;
}
################################################################################
sub WeekdayTimer_SwitchingTime($$) {
  my ($hash, $switchingtime) = @_;

  my $name = $hash->{NAME};
  my $globalDaylistSpec = $hash->{GlobalDaylistSpec};
  my @tageGlobal = @{WeekdayTimer_daylistAsArray($hash, $globalDaylistSpec)};

  my (@st, $daylist, $time, $timeString, $para);
  @st = split(/\|/, $switchingtime);
  my $overrulewday = 0;
  if ( @st == 2 || @st == 3 && $st[2] eq "w") {
    $daylist = ($globalDaylistSpec gt "") ? $globalDaylistSpec : "0123456";
    $time    = $st[0];
    $para    = $st[1];
    $overrulewday = 1 if defined $st[2] && $st[2] eq "w";
  } elsif ( @st == 3 || @st == 4) {
    $daylist  = $st[0];
    $time     = $st[1];
    $para     = $st[2];
    $overrulewday = 1 if defined $st[3] && $st[3] eq "w";
  }

  my @tage = @{WeekdayTimer_daylistAsArray($hash, $daylist)};
  my $tage=@tage;
  if ( $tage==0 ) {
    Log3 ($hash, 1, "[$name] invalid daylist in $name <$daylist> use one of 012345678 or $hash->{helper}{daysRegExpMessage}");
  }

  my %hdays=();
  @hdays{@tageGlobal} = undef;
  @hdays{@tage}       = undef;
  @tage = sort keys %hdays;

  #Log3 $hash, 3, "Tage: " . Dumper \@tage;
  return (\@tage,$time,$para,$overrulewday);
}
################################################################################
sub WeekdayTimer_daylistAsArray($$){
  my ($hash, $daylist) = @_;

  my $name = $hash->{NAME};
  my @days;

  my %hdays=();

  $daylist = lc($daylist);
  # Angaben der Tage verarbeiten
  # Aufzaehlung 1234 ...
  if (      $daylist =~  m/^[0-8]{0,9}$/g) {

    #Log3 ($hash, 3, "[$name] " . '"7" in daylist now means $we(weekend) - see dokumentation!!!' ) if (index($daylist, '7') != -1);

    @days = split("", $daylist);
    @hdays{@days} = undef;

    # Aufzaehlung Sa,So,... | Mo-Di,Do,Fr-Mo
  } elsif ($daylist =~  m/^($hash->{helper}{daysRegExp}(,|-|$)){0,7}$/g   ) {
    my @subDays;
    my @aufzaehlungen = split (",", $daylist);
    foreach my $einzelAufzaehlung (@aufzaehlungen) {
      my @days = split ("-", $einzelAufzaehlung);
      my $days = @days;
      if ($days == 1) {
        #einzelner Tag: Sa
        $hdays{$hash->{dayNumber}{$days[0]}} = undef;
      } else {
        # von bis Angabe: Mo-Di
        my $von  = $hash->{dayNumber}{$days[0]};
        my $bis  = $hash->{dayNumber}{$days[1]};
        if ($von <= $bis) {
          @subDays = ($von .. $bis);
        } else {
          #@subDays = ($dayNumber{so} .. $bis, $von .. $dayNumber{sa});
          @subDays = (           00  .. $bis, $von ..            06);
        }
        @hdays{@subDays}=undef;
      }
    }
  } else {
    %hdays = ();
  }

  my @tage = sort keys %hdays;
  return \@tage;
}
################################################################################
sub WeekdayTimer_EchteZeit($$$) {
  my ($hash, $d, $time)  = @_;

  my $name = $hash->{NAME};

  my $now = time();
  my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime($now);

  my $listOfDays = "";

  # Zeitangabe verarbeiten.
  $time = '"' . "$time" . '"'       if($time !~  m/^\{.*\}$/g);
  my $date           = $now+($d-$wday)*86400;
  my $timeString     = '{ my $date='."$date;" .$time."}";
  my $eTimeString    = eval( $timeString );                            # must deliver HH:MM[:SS]
  if ($@) {
    $@ =~ s/\n/ /g;
    Log3 ($hash, 3, "[$name] " . $@ . ">>>$timeString<<<");
    $eTimeString = "00:00:00";
  }

  if      ($eTimeString =~  m/^[0-2][0-9]:[0-5][0-9]$/g) {          #  HH:MM
    $eTimeString .= ":00";                                          #  HH:MM:SS erzeugen
  } elsif ($eTimeString =~  m/^[0-2][0-9](:[0-5][0-9]){2,2}$/g) {   #  HH:MM:SS
      ;                                                               #  ok.
  } else {
    Log3 ($hash, 1, "[$name] invalid time <$eTimeString> HH:MM[:SS]");
    $eTimeString = "00:00:00";
  }
  return $eTimeString;
}
################################################################################
sub WeekdayTimer_zeitErmitteln  ($$$$$) {
  my ($now, $hour, $min, $sec, $days) = @_;

  my @jetzt_arr = localtime($now);
  #Stunden               Minuten               Sekunden
  $jetzt_arr[2]  = $hour; $jetzt_arr[1] = $min; $jetzt_arr[0] = $sec;
  $jetzt_arr[3] += $days;
  my $next = timelocal_nocheck(@jetzt_arr);
  return $next;
}
################################################################################
sub WeekdayTimer_gatherSwitchingTimes {
  my $hash = shift;
  my $a    = shift;

  my $name = $hash->{NAME};
  my @switchingtimes = ();
  my $conditionOrCommand;

  # switchingtime einsammeln
  while (@$a > 0) {

    #pruefen auf Angabe eines Schaltpunktes
    my $element = "";
    my @restoreElements = ();
E:  while (@$a > 0) {

      my $actualElement = shift @$a;
      push @restoreElements, $actualElement;
      $element = $element . $actualElement . " ";
      Log3 $hash, 5, "[$name] $element - trying to accept as a switchtime";

      # prüfen ob Anführungszeichen paarig sind
      my @quotes = ('"', "'" );
      foreach my $quote (@quotes){
        my $balancedSign = eval "((\$element =~ tr/$quote//))";
        if ($balancedSign % 2) { # ungerade Anzahl quotes, dann verlängern
          Log3 $hash, 5, "[$name] $element - unbalanced quotes: $balancedSign $quote found";
          next E;
        }
      }

      # prüfen ob öffnende/schliessende Klammern paarig sind
      my %signs = ('('=>')', '{'=>'}');
      foreach my $signOpened (keys(%signs)) {
        my $signClosed  = $signs{$signOpened};
        my $balancedSign = eval "((\$element =~ tr/$signOpened//) - (\$element =~ tr/$signClosed//))";
        if ($balancedSign) { # öffnende/schließende Klammern nicht gleich, dann verlängern
          Log3 $hash, 5, "[$name] $element - unbalanced brackets $signOpened$signClosed:$balancedSign";
          next E;
        }
      }
      last;
    }

    # ein space am Ende wieder abschneiden
    $element = substr ($element, 0, length($element)-1);
    my @t = split(/\|/, $element);
    my $anzahl = @t;

    if ( ($anzahl > 1 && $anzahl < 5) && $t[0] gt "" && $t[1] gt "" ) {
      Log3 $hash, 4, "[$name] $element - accepted";
      #$element = "0-6|".$element if $t[0] =~ m/\d:\d/;
      push(@switchingtimes, $element);
    } elsif ($element =~ /weekprofile/ ) {
      my @wprof = split(/:/, $element);
      my $wp_name = $wprof[1];
      my ($unused,$wp_profile) = split(":", WeekdayTimer_GetWeekprofileReadingTriplett($hash, $wp_name),2);
      return unless $wp_profile;
      my $wp_sunaswe = $wprof[2]//0;
      my $wp_profile_data = CommandGet(undef,$wp_name . " profile_data ". $wp_profile);
      if ($wp_profile_data =~ /(profile.*not.found|usage..profile_data..name)/ ) {
        Log3 $hash, 3, "[$name] weekprofile $wp_name: no profile named \"$wp_profile\" available";
        return;
      }
      my $wp_profile_unpacked;
      my $json = JSON->new->allow_nonref;
      eval { $wp_profile_unpacked = $json->decode($wp_profile_data); };
      $hash->{weekprofiles}{$wp_name} = {'PROFILE'=>$wp_profile,'PROFILE_JSON'=>$wp_profile_data,'SunAsWE'=>$wp_sunaswe,'PROFILE_DATA'=>$wp_profile_unpacked };
      my %wp_shortDays = ("Mon"=>1,"Tue"=>2,"Wed"=>3,"Thu"=>4,"Fri"=>5,"Sat"=>6,"Sun"=>0);
      foreach my $wp_days (sort keys %{$hash->{weekprofiles}{$wp_name}{PROFILE_DATA}}) {
        my $wp_times = $hash->{weekprofiles}{$wp_name}{PROFILE_DATA}{$wp_days}{time};
        my $wp_temps = $hash->{weekprofiles}{$wp_name}{PROFILE_DATA}{$wp_days}{temp};
        my $wp_shortDay = $wp_shortDays{$wp_days};
        for ( my $i = 0; $i < @{$wp_temps}; $i++ ) {
          my $itime = "00:10";
          $itime = $hash->{weekprofiles}{$wp_name}{PROFILE_DATA}{$wp_days}{time}[$i-1] if $i;
          my $itemp = $hash->{weekprofiles}{$wp_name}{PROFILE_DATA}{$wp_days}{temp}[$i];
          my $wp_dayprofile = "$wp_shortDay"."|$itime" . "|$itemp";
          $wp_dayprofile .= "|w" if $wp_sunaswe eq "true";
          push(@switchingtimes, $wp_dayprofile);
          if ($wp_sunaswe eq "true" and $wp_shortDay == 0) {
            $wp_dayprofile = "7|$itime" . "|$itemp";
            push(@switchingtimes, $wp_dayprofile);
          }
        }
      }
    } else {
      Log3 $hash, 4, "[$name] $element - NOT accepted, must be command or condition";
      unshift @$a, @restoreElements;
      last;
    }
  }
  return (@switchingtimes);
}
################################################################################
sub WeekdayTimer_Language {
  my ($hash, $a) = @_;

  my $name = $hash->{NAME};

  # ggf. language optional Parameter
  my $langRegExp = "(" . join ("|", keys(%{$hash->{shortDays}})) . ")";
  my $language   = shift @$a;

  unless ($language =~  m/^$langRegExp$/g) {
    Log3 ($hash, 3, "[$name] language: $language not recognized, use one of $langRegExp") if (length($language) == 2);
    unshift @$a, $language;
    $language = lc(AttrVal("global","language","en"));
    $language = $language =~  m/^$langRegExp$/g ? $language : "en";
  }
  $hash->{LANGUAGE} = $language;

  return ($langRegExp, $language);
}
################################################################################
sub WeekdayTimer_GlobalDaylistSpec {
  my ($hash, $a) = @_;

  my $daylist = shift @$a;

  my @tage = @{WeekdayTimer_daylistAsArray($hash, $daylist)};
  my $tage = @tage;
  if ($tage > 0) {
    ;
  } else {
    unshift (@$a,$daylist);
    $daylist = "";
  }

  $hash->{GlobalDaylistSpec} = $daylist;
}
################################################################################
sub WeekdayTimer_SetTimerForMidnightUpdate($) {
  my ($myHash) = @_;
  my $hash = WeekdayTimer_GetHashIndirekt($myHash, (caller(0))[3]);
  return if (!defined($hash));

  my $now = time();
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($now);

  my $midnightPlus5Seconds = WeekdayTimer_zeitErmitteln  ($now, 0, 0, 5, 1);
  #Log3 $hash, 3, "midnightPlus5Seconds------------>".FmtDateTime($midnightPlus5Seconds);+#
  WeekdayTimer_RemoveInternalTimer("SetTimerOfDay", $hash);
  my $newMyHash = WeekdayTimer_InternalTimer      ("SetTimerOfDay", $midnightPlus5Seconds, "$hash->{TYPE}_SetTimerOfDay", $hash, 0);
  $newMyHash->{SETTIMERATMIDNIGHT} = 1;

}
################################################################################
sub WeekdayTimer_SetTimerOfDay($) {
  my ($myHash) = @_;
  my $hash = WeekdayTimer_GetHashIndirekt($myHash, (caller(0))[3]);
  return if (!defined($hash));

  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time());
  my $secSinceMidnight = 3600*$hour + 60*$min + $sec;

  my %wedays =();
    
  my $iswe = IsWe();
  $wedays{(0)} = $iswe if $iswe;
  $iswe = IsWe("tomorrow");
  $wedays{(1)} = $iswe if $iswe;
    
  for (my $i=2;$i<=6;$i++) {
    my $noWeekEnd = 0;
    my $ergebnis = 'none';
    my $izeit = time() + DAYSECONDS * $i;
    my ($isec,$imin,$ihour,$imday,$imon,$iyear,$iwday,$iyday,$iisdst) = localtime($izeit);
  
    foreach my $h2we (split(',', AttrVal('global', 'holiday2we', ''))) {
      if($h2we && ( $ergebnis eq 'none' || $h2we eq "noWeekEnd" )  && InternalVal($h2we, 'TYPE', '') eq "holiday" && !$noWeekEnd) {
        $ergebnis = CommandGet(undef,$h2we . ' ' . sprintf("%02d-%02d",$imon+1,$imday));
        if ($ergebnis ne 'none' && $h2we eq "noWeekEnd") {
          $ergebnis = 'none';
          $noWeekEnd = 1;
        }
      }
    }
    if ($ergebnis ne 'none') {
      $wedays{$i} = $ergebnis ;
    } else {
      if (AttrVal('global', 'holiday2we', '') =~ m,\bweekEnd\b, && ($iwday == 0 || $iwday == 6)) { 
        delete $wedays{$i};
      } elsif ( $iwday == 0 || $iwday == 6) {
        $wedays{$i} = 1 ;
      } else {
        delete $wedays{$i};
      }
    }
  }
  $hash->{helper}{WEDAYS} = \%wedays;
  $hash->{SETTIMERATMIDNIGHT} = $myHash->{SETTIMERATMIDNIGHT};
  WeekdayTimer_DeleteTimer($hash);
  WeekdayTimer_Profile    ($hash);
  WeekdayTimer_SetTimer   ($hash);
  delete $hash->{SETTIMERATMIDNIGHT};
  WeekdayTimer_SetTimerForMidnightUpdate( { HASH => $hash} );
}
################################################################################
sub WeekdayTimer_SetTimer($) {
  my $hash = shift;
  my $name = $hash->{NAME};

  my $now  = time();

  my $isHeating         = WeekdayTimer_isHeizung($hash);
  my $swip              = AttrVal($name, "switchInThePast", 0);
  my $switchInThePast   = ($swip || $isHeating);

  Log3 $hash, 4, "[$name] Heating recognized - switch in the past activated" if ($isHeating);
  Log3 $hash, 4, "[$name] no switch in the yesterdays because of the devices type($hash->{DEVICE} is not recognized as heating) - use attr switchInThePast" if (!$switchInThePast && !defined $hash->{SETTIMERATMIDNIGHT});

  my @switches = sort keys %{$hash->{profil}};
  if (@switches == 0) {
    Log3 $hash, 3, "[$name] no switches to send, due to possible errors.";
    return;
  }

  readingsSingleUpdate ($hash,  "state", "inactive", 1) if (!defined $hash->{SETTIMERATMIDNIGHT});
  for(my $i=0; $i<=$#switches; $i++) {

    my $idx = $switches[$i];

    my $time        = $hash->{profil}{$idx}{TIME};
    my $timToSwitch = $hash->{profil}{$idx}{EPOCH};
    my $tage        = $hash->{profil}{$idx}{TAGE};
    my $para        = $hash->{profil}{$idx}{PARA};
    my $overrulewday = $hash->{profil}{$idx}{WE_Override};

    my $secondsToSwitch = $timToSwitch - $now;

    my $isActiveTimer = WeekdayTimer_isAnActiveTimer ($hash, $tage, $para, $overrulewday);
    readingsSingleUpdate ($hash,  "state",      "active",    1)
      if (!defined $hash->{SETTIMERATMIDNIGHT} && $isActiveTimer);

    if ($secondsToSwitch>-5 || defined $hash->{SETTIMERATMIDNIGHT} ) {
      if($isActiveTimer) {
        Log3 $hash, 4, "[$name] setTimer - timer seems to be active today: ".join("",@$tage)."|$time|$para";
        WeekdayTimer_RemoveInternalTimer("$idx", $hash);
        WeekdayTimer_InternalTimer ("$idx", $timToSwitch, "$hash->{TYPE}_Update", $hash, 0);
      } else {
        Log3 $hash, 4, "[$name] setTimer - timer seems to be NOT active today: ".join("",@$tage)."|$time|$para ". $hash->{CONDITION};
        WeekdayTimer_RemoveInternalTimer("$idx", $hash);
      }
      #WeekdayTimer_RemoveInternalTimer("$idx", $hash);
      #WeekdayTimer_InternalTimer ("$idx", $timToSwitch, "$hash->{TYPE}_Update", $hash, 0);
    }
  }

  if (defined $hash->{SETTIMERATMIDNIGHT}) {
    return;
  }

  my ($aktIdx,$aktTime,$aktParameter,$nextTime,$nextParameter) =
    WeekdayTimer_searchAktNext($hash, time()+5);
  if(!defined $aktTime) {
    Log3 $hash, 3, "[$name] can not compute past switching time";
  }

  readingsSingleUpdate ($hash,  "nextUpdate", FmtDateTime($nextTime), 1);
  readingsSingleUpdate ($hash,  "nextValue",  $nextParameter,         1);
  readingsSingleUpdate ($hash,  "currValue",  $aktParameter,          1); # HB

  if ($switchInThePast && defined $aktTime) {
    # Fensterkontakte abfragen - wenn einer im Status closed, dann Schaltung um 60 Sekunden verzögern
    if (WeekdayTimer_FensterOffen($hash, $aktParameter, $aktIdx)) {
      return;
    }

    # alle in der Vergangenheit liegenden Schaltungen sammeln und
    # nach 5 Sekunden in der Reihenfolge der Schaltzeiten
    # durch WeekdayTimer_delayedTimerInPast() als Timer einstellen
    # die Parameter merken wir uns kurzzeitig im hash
    #    modules{WeekdayTimer}{timerInThePast}
    my $device = $hash->{DEVICE};
    Log3 $hash, 4, "[$name] past timer on $hash->{DEVICE} at ". FmtDateTime($aktTime). " with  $aktParameter activated";

    my $parameter = $modules{WeekdayTimer}{timerInThePast}{$device}{$aktTime};
    $parameter = [] if (!defined $parameter);
    push (@$parameter,["$aktIdx", $aktTime, "$hash->{TYPE}_Update", $hash, 0]);
    $modules{WeekdayTimer}{timerInThePast}{$device}{$aktTime} = $parameter;

    my $tipHash = $modules{WeekdayTimer}{timerInThePastHash};
    $tipHash    = $hash if (!defined $tipHash);
    $modules{WeekdayTimer}{timerInThePastHash} = $tipHash;

    WeekdayTimer_RemoveInternalTimer("delayed", $tipHash);
    WeekdayTimer_InternalTimer      ("delayed", time()+5, "WeekdayTimer_delayedTimerInPast", $tipHash, 0);

  }
}
################################################################################
sub WeekdayTimer_delayedTimerInPast($) {
  my ($myHash) = @_;
  my $hash = WeekdayTimer_GetHashIndirekt($myHash, (caller(0))[3]);
  return if (!defined($hash));

  my $tim = time();
  
  my $tipIpHash = $modules{WeekdayTimer}{timerInThePast};
  
  foreach my $device ( keys %$tipIpHash ) {
    foreach my $time (         sort keys %{$tipIpHash->{$device}} ) {
      Log3 $hash, 4, "[$hash->{NAME}] $device ".FmtDateTime($time)." ".($tim-$time)."s ";

      foreach my $para ( @{$tipIpHash->{$device}{$time}} ) {
        WeekdayTimer_RemoveInternalTimer(@$para[0], @$para[3]);
        my $mHash =WeekdayTimer_InternalTimer (@$para[0],@$para[1],@$para[2],@$para[3],@$para[4]);
        $mHash->{forceSwitch} = 1;
      }
    }
  }
  delete $modules{WeekdayTimer}{timerInThePast};
  delete $modules{WeekdayTimer}{timerInThePastHash}
}
################################################################################
sub WeekdayTimer_searchAktNext($$) {
  my ($hash, $now) = @_;
  my $name = $hash->{NAME};

  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($now);
  #Log3 $hash, 3, "[$name] such--->".FmtDateTime($now);

  my ($oldTag,  $oldTime,  $oldPara , $oldIdx);
  my ($nextTag, $nextTime, $nextPara, $nextIdx);

  my $language  =   $hash->{LANGUAGE};
  my %shortDays = %{$hash->{shortDays}};

  my @realativeWdays  = ($wday..6,0..$wday-1,$wday..6,0..6);
  for (my $i=0;$i<=$#realativeWdays;$i++) {

    my $relativeDay = $i-7;
    my $relWday     = $realativeWdays[$i];

    foreach my $time (sort keys %{$hash->{helper}{SWITCHINGTIME}{$relWday}}) {
      my ($stunde, $minute, $sekunde) = split (":",$time);

      $oldTime  = $nextTime;
      $oldPara  = $nextPara;
      $oldIdx   = $nextIdx;
      $oldTag   = $nextTag;

      $nextTime = WeekdayTimer_zeitErmitteln ($now, $stunde, $minute, $sekunde, $relativeDay);
      $nextPara = $hash->{helper}{SWITCHINGTIME}{$relWday}{$time};
      #$nextIdx  = $hash->{helper}{SWITCHINGTIME}{$relWday}{$time};
      $nextIdx  = $hash->{profile_IDX}{$relWday}{$time};
      $nextTag  = $relWday;

      #Log3 $hash, 3, $shortDays{$language}[$nextTag]." ".FmtDateTime($nextTime)." ".$nextPara." ".$nextIdx;
      my $ignore = 0;
      my $wend = 0;
      my $tage = $hash->{profil}{$nextIdx}{TAGE}[0];
      if ($wday==$relWday) {
        $wend = $hash->{helper}{WEDAYS}{0};
        $ignore = (($tage == 7 && !$wend ) || ($tage == 8 && $wend ));
      } elsif ( $wday==$relWday+1) {
        $wend = $hash->{helper}{WEDAYS}{1};
        $ignore = (($tage == 7 && !$wend ) || ($tage == 8 && $wend ));
      }
      if (!$ignore && $nextTime >= $now ) {
        return ($oldIdx, $oldTime, $oldPara, $nextTime, $nextPara);
      }
    }
  }
  return (undef,undef,undef,undef);
}
################################################################################
sub WeekdayTimer_DeleteTimer($) {
  my $hash = shift;
  map {WeekdayTimer_RemoveInternalTimer ($_, $hash)}      keys %{$hash->{profil}};
}
################################################################################
sub WeekdayTimer_Update($) {
  my ($myHash) = @_;
  my $hash = WeekdayTimer_GetHashIndirekt($myHash, (caller(0))[3]);
  return if (!defined($hash));

  my $name     = $hash->{NAME};
  my $idx      = $myHash->{MODIFIER};
  my $now      = time();

  #my $sollZeit    = $myHash->{TIME};

  #my $setModifier = WeekdayTimer_isHeizung($hash);
  #my $isHeating = $setModifier gt "";

  # Schaltparameter ermitteln
  my $tage        = $hash->{profil}{$idx}{TAGE};
  my $time        = $hash->{profil}{$idx}{TIME};
  my $newParam    = $hash->{profil}{$idx}{PARA};
  my $timToSwitch = $hash->{profil}{$idx}{EPOCH};
  my $overrulewday = $hash->{profil}{$idx}{WE_Override};

  #Log3 $hash, 3, "[$name] $idx ". $time . " " . $newParam . " " . join("",@$tage);

  # Fenserkontakte abfragen - wenn einer im Status closed, dann Schaltung um 60 Sekunden verzögern
  if (WeekdayTimer_FensterOffen($hash, $newParam, $idx)) {
    readingsSingleUpdate ($hash,  "state", "open window", 1);
    return;
  }

  my $dieGanzeWoche = $hash->{helper}{WEDAYS}{0} ? [7]:[8];

  my ($activeTimer, $activeTimerState);
  if (defined $myHash->{forceSwitch}) {
     
    $activeTimer      = WeekdayTimer_isAnActiveTimer ($hash, $dieGanzeWoche, $newParam, $overrulewday);
    $activeTimerState = WeekdayTimer_isAnActiveTimer ($hash, $tage, $newParam, $overrulewday);
    Log3 $hash, 4, "[$name] Update   - past timer activated";
    WeekdayTimer_RemoveInternalTimer("$idx",  $hash);
    WeekdayTimer_InternalTimer ("$idx", $timToSwitch, "$hash->{TYPE}_Update", $hash, 0) if ($timToSwitch > $now && ($activeTimerState||$activeTimer));
  } else {
    $activeTimer = WeekdayTimer_isAnActiveTimer ($hash, $tage, $newParam, $overrulewday);
    $activeTimerState = $activeTimer;
    Log3 $hash, 4, "[$name] Update   - timer seems to be active today: ".join("",@$tage)."|$time|$newParam" if($activeTimer);
  }
  #Log3 $hash, 3, "activeTimer------------>$activeTimer";
  #Log3 $hash, 3, "activeTimerState------->$activeTimerState";
  my ($aktIdx, $aktTime,  $aktParameter, $nextTime, $nextParameter) =
    WeekdayTimer_searchAktNext($hash, time()+5);

  my $device   = $hash->{DEVICE};
  my $disabled = AttrVal($hash->{NAME}, "disable", 0);

  # ggf. Device schalten
  WeekdayTimer_Switch_Device($hash, $newParam, $tage)   if($activeTimer);

  readingsBeginUpdate($hash);
  readingsBulkUpdate ($hash,  "nextUpdate", FmtDateTime($nextTime));
  readingsBulkUpdate ($hash,  "nextValue",  $nextParameter);
  readingsBulkUpdate ($hash,  "currValue",  $aktParameter); # HB
  readingsBulkUpdate ($hash,  "state",      $newParam )   if($activeTimerState);
  readingsEndUpdate  ($hash,  defined($hash->{LOCAL} ? 0 : 1));

  return 1;

}
################################################################################
sub WeekdayTimer_isAnActiveTimer ($$$$) {
  my ($hash, $tage, $newParam, $overrulewday)  = @_;

  my $name = $hash->{NAME};
  my %specials   = ( "%NAME" => $hash->{DEVICE}, "%EVENT" => $newParam);

  my $condition  = WeekdayTimer_Condition ($hash, $tage, $overrulewday);
  my $tageAsHash = WeekdayTimer_tageAsHash($hash, $tage);
  my $xPression  = "{".$tageAsHash.";;".$condition ."}";
     $xPression  = EvalSpecials($xPression, %specials);
  Log3 $hash, 5, "[$name] condition: $xPression";

  my $ret = AnalyzeCommandChain(undef, $xPression);
  Log3 $hash, 5, "[$name] result of condition: $ret";
  return  $ret;
}
################################################################################
sub WeekdayTimer_isHeizung($) {
  my ($hash)  = @_;

  my $name = $hash->{NAME};

  my $dHash = $defs{$hash->{DEVICE}};
  return "" if (!defined $dHash); # vorzeitiges Ende wenn das device nicht existiert

  my $dType = $dHash->{TYPE};
  return ""   if (!defined($dType) || $dType eq "dummy" );

  my $dName = $dHash->{NAME};

  my @tempSet = ("desired-temp", "desiredTemperature", "desired", "thermostatSetpointSet");
  my $allSets = getAllSets($dName);

  foreach my $ts (@tempSet) {
    if ($allSets =~ m/$ts/) {
      Log3 $hash, 4, "[$name] device type heating recognized, setModifier:$ts";
      return $ts
    }
  }

}
################################################################################
sub WeekdayTimer_FensterOffen ($$$) {
  my ($hash, $event, $time) = @_;
  my $name = $hash->{NAME};

  my %specials = (
         '%HEATING_CONTROL'  => $hash->{NAME},
         '%WEEKDAYTIMER'     => $hash->{NAME},
         '%NAME'             => $hash->{DEVICE},
         '%EVENT'            => $event,
         '%TIME'             => $hash->{profil}{$time}{TIME},
         '$HEATING_CONTROL'  => $hash->{NAME},
         '$WEEKDAYTIMER'     => $hash->{NAME},
         '$NAME'             => $hash->{DEVICE},
         '$EVENT'            => $event,
         '$TIME'             => $hash->{profil}{$time}{TIME},
  );

  my $verzoegerteAusfuehrungCond = AttrVal($hash->{NAME}, "delayedExecutionCond", "0");
  #$verzoegerteAusfuehrungCond    = 'xxx(%WEEKDAYTIMER,%NAME,%HEATING_CONTROL,$WEEKDAYTIMER,$EVENT,$NAME,$HEATING_CONTROL)';

  my $nextRetry = time()+55+int(rand(10));
  my $epoch = $hash->{profil}{$time}{EPOCH};
  my $delay = int(time()) - $epoch;
  my $nextDelay = int($delay/60.+1.5)*60;  # round to multiple of 60sec
  $nextRetry = $epoch + $nextDelay;
  Log3 $hash, 4, "[$name] time=".$hash->{profil}{$time}{TIME}."/$epoch delay=$delay, nextDelay=$nextDelay, nextRetry=$nextRetry";

  map { my $key =  $_; $key =~ s/\$/\\\$/g;
        my $val = $specials{$_};
        $verzoegerteAusfuehrungCond =~ s/$key/$val/g
      } keys %specials;
  Log3 $hash, 4, "[$name] delayedExecutionCond:$verzoegerteAusfuehrungCond";

  my $verzoegerteAusfuehrung = eval($verzoegerteAusfuehrungCond);

  my $logtext =  $verzoegerteAusfuehrung // 'no condition attribute set';
  Log3 $hash, 4, "[$name] result of delayedExecutionCond: $logtext";

  if ($verzoegerteAusfuehrung) {
    if (!defined($hash->{VERZOEGRUNG})) {
      Log3 $hash, 3, "[$name] switch of $hash->{DEVICE} delayed - delayedExecutionCond: '$verzoegerteAusfuehrungCond' is TRUE";
    }
    if (defined($hash->{VERZOEGRUNG_IDX}) && $hash->{VERZOEGRUNG_IDX}!=$time) {
      #Prüfen, ob der nächste Timer überhaupt für den aktuellen Tag relevant ist!
    
      Log3 $hash, 3, "[$name] timer at $hash->{profil}{$hash->{VERZOEGRUNG_IDX}}{TIME} skipped by new timer at $hash->{profil}{$time}{TIME}, delayedExecutionCond returned $verzoegerteAusfuehrung";
      WeekdayTimer_RemoveInternalTimer($hash->{VERZOEGRUNG_IDX},$hash);
    }
    $hash->{VERZOEGRUNG_IDX} = $time;
    WeekdayTimer_RemoveInternalTimer("$time",  $hash);
    WeekdayTimer_InternalTimer      ("$time",  $nextRetry, "$hash->{TYPE}_Update", $hash, 0);
    $hash->{VERZOEGRUNG} = 1;
    return 1;
  }

  my %contacts =  ( "CUL_FHTTK"       => { "READING" => "Window",          "STATUS" => "(Open)",        "MODEL" => "r" },
                    "CUL_HM"          => { "READING" => "state",           "STATUS" => "(open|tilted)", "MODEL" => "r" },
                    "EnOcean"         => { "READING" => "state",           "STATUS" => "(open)",        "MODEL" => "r" },
                    "ZWave"           => { "READING" => "state",           "STATUS" => "(open)",        "MODEL" => "r" },
                    "MAX"             => { "READING" => "state",           "STATUS" => "(open.*)",      "MODEL" => "r" },
                    "dummy"           => { "READING" => "state",           "STATUS" => "(([Oo]pen|[Tt]ilt).*)",   "MODEL" => "r" },
                    "HMCCUDEV"        => { "READING" => "state",           "STATUS" => "(open|tilted)", "MODEL" => "r" },
                    "WeekdayTimer"    => { "READING" => "delayedExecution","STATUS" => "^1\$",          "MODEL" => "a" },
                    "Heating_Control" => { "READING" => "delayedExecution","STATUS" => "^1\$",          "MODEL" => "a" }
                  );

  my $fensterKontakte = $hash->{NAME} ." ". AttrVal($hash->{NAME}, "WDT_delayedExecutionDevices", "");
  my $HC_fensterKontakte = AttrVal($hash->{NAME}, "windowSensor", undef);
  $fensterKontakte .= " ".$HC_fensterKontakte if defined $HC_fensterKontakte;
  $fensterKontakte =~ s/^\s+//;
  $fensterKontakte =~ s/\s+$//;

  Log3 $hash, 4, "[$name] list of window sensors found: '$fensterKontakte'";
  if ($fensterKontakte ne "" ) {
    my @kontakte = split("[ \t]+", $fensterKontakte);
    foreach my $fk (@kontakte) {
      #hier flexible eigene Angaben ermöglichen?, Schreibweise: Device[:Reading[:ValueToCompare[:Comparator]]]; defaults: Reading=state, ValueToCompare=0/undef/false, all other true, Comparator=eq (options: eq, ne, lt, gt, ==, <,>,<>)
      my $fk_hash = $defs{$fk};
      unless($fk_hash) {
        Log3 $hash, 3, "[$name] sensor <$fk> not found - check name.";
      } else {
        my $fk_typ  = $fk_hash->{TYPE};
        if (!defined($contacts{$fk_typ})) {
          Log3 $hash, 3, "[$name] TYPE '$fk_typ' of $fk not yet supported, $fk ignored - inform maintainer";
        } else {

          my $reading      = $contacts{$fk_typ}{READING};
          my $statusReg    = $contacts{$fk_typ}{STATUS};
          my $model        = $contacts{$fk_typ}{MODEL};

          my $windowStatus;
          if ($model eq "r")  {   ### Reading, sonst Attribut
            $windowStatus = ReadingsVal($fk,$reading,"nF");
          }else{
            $windowStatus = AttrVal    ($fk,$reading,"nF");
          }

          if ($windowStatus eq "nF") {
            Log3 $hash, 3, "[$name] Reading/Attribute '$reading' of $fk not found, $fk ignored - inform maintainer" if ($model eq "r");
          } else {
            Log3 $hash, 5, "[$name] sensor '$fk' Reading/Attribute '$reading' is '$windowStatus'";

            if ($windowStatus =~  m/^$statusReg$/g) {
              if (!defined($hash->{VERZOEGRUNG})) {
                Log3 $hash, 3, "[$name] switch of $hash->{DEVICE} delayed - sensor '$fk' Reading/Attribute '$reading' is '$windowStatus'";
              }
              if (defined($hash->{VERZOEGRUNG_IDX}) && $hash->{VERZOEGRUNG_IDX}!=$time) {
                Log3 $hash, 3, "[$name] timer at $hash->{profil}{$hash->{VERZOEGRUNG_IDX}}{TIME} skipped by new timer at $hash->{profil}{$time}{TIME} while window contact returned open state";
                WeekdayTimer_RemoveInternalTimer($hash->{VERZOEGRUNG_IDX},$hash);
              }
              $hash->{VERZOEGRUNG_IDX} = $time;
              WeekdayTimer_RemoveInternalTimer("$time", $hash);
              WeekdayTimer_InternalTimer      ("$time",  $nextRetry, "$hash->{TYPE}_Update", $hash, 0);
              $hash->{VERZOEGRUNG} = 1;
              return 1
            }
          }
        }
      }
    }
  }
  if ($hash->{VERZOEGRUNG}) {
    Log3 $hash, 3, "[$name] delay of switching $hash->{DEVICE} stopped.";
  }
  delete $hash->{VERZOEGRUNG};
  delete $hash->{VERZOEGRUNG_IDX} if defined($hash->{VERZOEGRUNG_IDX});
  return 0;
}
################################################################################
sub WeekdayTimer_Switch_Device($$$) {
  my ($hash, $newParam, $tage)  = @_;

  my ($command, $condition, $tageAsHash) = "";
  my $name  = $hash->{NAME};                                        ###
  my $dummy = "";

  my $now = time();
  #modifier des Zieldevices auswaehlen
  my $setModifier = WeekdayTimer_isHeizung($hash);

  $attr{$name}{commandTemplate} =
     'set $NAME '. $setModifier .' $EVENT' if (!defined $attr{$name}{commandTemplate});

  $command = AttrVal($hash->{NAME}, "commandTemplate", "commandTemplate not found");
  $command = $hash->{COMMAND}   if ($hash->{COMMAND} gt "");

  my $activeTimer = 1;

  my $isHeating = $setModifier gt "";
  my $aktParam  = ReadingsVal($hash->{DEVICE}, $setModifier, "");
     $aktParam  = sprintf("%.1f", $aktParam)   if ($isHeating && $aktParam =~ m/^[0-9]{1,3}$/i);
     $newParam  = sprintf("%.1f", $newParam)   if ($isHeating && $newParam =~ m/^[0-9]{1,3}$/i);

  my $disabled = AttrVal($hash->{NAME}, "disable", 0);
  my $disabled_txt = $disabled ? "" : " not";
  Log3 $hash, 4, "[$name] aktParam:$aktParam newParam:$newParam - is$disabled_txt disabled";

  #Kommando ausführen
  if ($command && !$disabled && $activeTimer
    && $aktParam ne $newParam
    ) {
    $newParam =~ s/\\:/|/g;
    $newParam =~ s/:/ /g;
    $newParam =~ s/\|/:/g;

    my %specials = ( "%NAME" => $hash->{DEVICE}, "%EVENT" => $newParam);
    $command= EvalSpecials($command, %specials);

    Log3 $hash, 4, "[$name] command: '$command' executed with ".join(",", map { "$_=>$specials{$_}" } keys %specials);
    my $ret  = AnalyzeCommandChain(undef, $command);
    Log3 ($hash, 3, $ret) if($ret);
  }
}
################################################################################
sub WeekdayTimer_tageAsHash($$) {
  my ($hash, $tage)  = @_;

  my %days = map {$_ => 1} @$tage;
  map {delete $days{$_}} (7,8);

  return 'my $days={};map{$days->{$_}=1}'.'('.join (",", sort keys %days).')';
}
################################################################################
sub WeekdayTimer_Condition($$$) {
  my ($hash, $tage, $overrulewday)  = @_;

  my $name = $hash->{NAME};
  Log3 $hash, 4, "[$name] condition:$hash->{CONDITION} - Tage:".join(",",@$tage);

  my $condition  = "( ";
  $condition .= ($hash->{CONDITION} gt "") ? $hash->{CONDITION}  : 1 ;
  $condition .= " && " . WeekdayTimer_TageAsCondition($tage, $overrulewday);
  $condition .= ")";

  return $condition;
}
################################################################################
sub WeekdayTimer_TageAsCondition ($$) {
  my ($tage, $overrulewday) = @_;

  my %days     = map {$_ => 1} @$tage;

  my $we       = $days{7}; delete $days{7};  # $we
  my $notWe    = $days{8}; delete $days{8};  #!$we

  my $tageExp  = '(defined $days->{$wday}';
     $tageExp  .= ' && !$we' if $overrulewday;
     $tageExp .= ' ||  $we' if defined $we;
     $tageExp .= ' || !$we' if defined $notWe;
     $tageExp .= ')';

  return $tageExp;
}
################################################################################
sub WeekdayTimer_Attr($$$$) {
  my ($cmd, $name, $attrName, $attrVal) = @_;
  return if (!$init_done);
  $attrVal = 0 if(!defined $attrVal);

  my $hash = $defs{$name};
  if( $attrName eq "disable" ) {
    readingsSingleUpdate ($hash,  "disabled",  $attrVal, 1);
    WeekdayTimer_SetTimerOfDay({ HASH => $hash}) unless $attrVal;
  } elsif ( $attrName eq "enable" ) {
    WeekdayTimer_SetTimerOfDay({ HASH => $hash});
  } elsif ( $attrName eq "weekprofile" ) {
    $attr{$name}{$attrName} = $attrVal;
    WeekdayTimer_Start($hash);
  } elsif ( $attrName eq "switchInThePast" ) {
    $attr{$name}{$attrName} = $attrVal;
    WeekdayTimer_SetTimerOfDay({ HASH => $hash});
  }
  return undef;
}
################################################################################
sub WeekdayTimer_SetParm($) {
  my ($name) = @_;

  my $hash = $defs{$name};
  if(defined $hash) {
    WeekdayTimer_DeleteTimer($hash);
    WeekdayTimer_SetTimer($hash);
  }
}
################################################################################
sub WeekdayTimer_SetAllParms(;$) {            # {WeekdayTimer_SetAllParms()}
  my ($group) = @_; 
  my @wdtNames;
  if (!defined $group or $group eq "all") {
    @wdtNames = devspec2array('TYPE=WeekdayTimer');
  } else {
    @wdtNames = devspec2array("TYPE=WeekdayTimer:FILTER=WDT_Group=$group");
  }
  foreach my $wdName ( @wdtNames ) {
    WeekdayTimer_SetParm($wdName);
  }
  Log3 undef,  3, "WeekdayTimer_SetAllParms() done on: ".join(" ",@wdtNames );
}
################################################################################
sub WeekdayTimer_UpdateWeekprofileReading($$$$) {
  my ($hash,$wp_name,$wp_topic,$wp_profile) = @_;
  my $name = $hash->{NAME};
  unless (defined $defs{$wp_name} && InternalVal($wp_name,"TYPE","false") eq "weekprofile")  {
    Log3 $hash, 3, "[$name] weekprofile $wp_name not accepted, device seems not to exist or not to be of TYPE weekprofile";
    return undef;
  }
  unless ($hash->{DEF} =~ m/weekprofile:$wp_name\b/) {
    Log3 $hash, 3, "[$name] weekprofile $wp_name not accepted, device is not correctly listed as weekprofile in the WeekdayTimer definition";
    return undef;
  }
  my $actual_wp_reading = ReadingsVal($name,"weekprofiles",undef);
  my @newt = ();
  my @t = split(" ", $actual_wp_reading);	  
  my $newtriplett = $wp_name.":".$wp_topic.":".$wp_profile;
  push @newt ,$newtriplett;
  foreach my $triplett (@t){
    push @newt ,$triplett unless $triplett =~ m/$wp_name\b/;
  }
  readingsSingleUpdate ($hash,  "weekprofiles", join(" ",@newt), 1);
  return 1;
}
################################################################################
sub WeekdayTimer_GetWeekprofileReadingTriplett($$) {
  my ($hash,$wp_name) = @_;
  my $name = $hash->{NAME};
  my $wp_topic   = "default";
  my $wp_profile = "default";
  unless (defined $defs{$wp_name} && InternalVal($wp_name,"TYPE","false") eq "weekprofile")  {
    Log3 $hash, 3, "[$name] weekprofile $wp_name not accepted, device seems not to exist or not to be of TYPE weekprofile";
    return undef;
  }
  my $newtriplett = $wp_name.":".$wp_topic.":".$wp_profile;
  my $actual_wp_reading = ReadingsVal($name,"weekprofiles",0);
  unless ($actual_wp_reading) {
    readingsSingleUpdate ($hash,  "weekprofiles", $newtriplett, 0);
    $actual_wp_reading = $newtriplett;
  }
  my @t = split(" ", $actual_wp_reading);	  
  foreach my $triplett (@t){
    return $triplett if $triplett =~ m/$wp_name\b/;
  }
  return undef;
}
################################################################################
1;

=pod
=encoding utf8
=item helper
=item summary    sends parameter to devices at defined times
=item summary_DE sendet Parameter an Devices zu einer Liste mit festen Zeiten
=begin html

<a name="WeekdayTimer"></a>
<meta content="text/html; charset=ISO-8859-1" http-equiv="content-type">
<h3>WeekdayTimer</h3>
<ul>
  <br>
  <a name="weekdayTimer_define"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; WeekdayTimer &lt;device&gt; [&lt;language&gt;] [<u>weekdays</u>] &lt;profile&gt; &lt;command&gt;|&lt;condition&gt;</code>
    <br><br>

    to set a weekly profile for &lt;device&gt;<br><br>

    You can define different switchingtimes for every day.<br>
    The new parameter is sent to the &lt;device&gt; automatically with <br><br>

    <code>set &lt;device&gt; &lt;para&gt;</code><br><br>

    If you have defined a &lt;condition&gt; and this condition is false if the switchingtime has reached, no command will executed.<br>
    An other case is to define an own perl command with &lt;command&gt;.
    <p>
    The following parameter are defined:
    <ul><b>device</b><br>
      The device to switch at the given time.
    </ul>
    <p>
    <ul><b>language</b><br>
      Specifies the language used for definition and profiles.
      de,en,fr,nl are possible. The parameter is optional.
    </ul>
    <p>
    <ul><b>weekdays</b><br>
      Specifies the days for all timer in the <b>WeekdayTimer</b>.
      The parameter is optional. For details see the weekdays part in profile.
    </ul>
    <p>
    <ul><b>profile</b><br>
      Define the weekly profile. All timings are separated by space. A switchingtime can be defined
      in two ways: the classic definition or via the use of a <b><a href="#weekprofile">weekprofile</a></b> (see below, only temperature profiles can be set). Example for a classic definition: <br><br>
      
      <ul><b>[&lt;weekdays&gt;|]&lt;time&gt;|&lt;parameter&gt;</b></ul><br>

      <u>weekdays:</u> optional, if not set every day of the week is used.<br>
        Otherwise you can define a day with its number or its shortname.<br>
        <ul>
        <li>0,su  sunday</li>
        <li>1,mo  monday</li>
        <li>2,tu  tuesday</li>
        <li>3,we  wednesday</li>
        <li>4 ...</li>
        <li>7,$we  weekend  ($we)</li>
        <li>8,!$we weekday  (!$we)</li>
        </ul><br>
         It is possible to define $we or !$we in daylist to easily allow weekend an holiday. $we !$we are coded as 7 8, when using a numeric daylist. <br>
         Note: $we will use general IsWe() function to determine $we handling for today and tomorrow. The complete daylist for all other days will reflect the results of holiday devices listed as holiday2we devices in global, including weekEnd and noWeekEnd (see global - holiday2we attribute).<br><br>
      <u>time:</u>define the time to switch, format: HH:MM:[SS](HH in 24 hour format) or a Perlfunction like {sunrise_abs()}. Within the {} you can use the variable $date(epoch) to get the exact switchingtimes of the week. Example: {sunrise_abs_dat($date)}<br><br>
      <u>parameter:</u>the parameter to be set, using any text value like <b>on</b>, <b>off</b>, <b>dim30%</b>, <b>eco</b> or <b>comfort</b> - whatever your device understands.<br>
      NOTE: Use ":" to replace blanks in parameter and escape ":" in case you need it. So e.g. <code>on-till:06\:00</code> will be a valid parameter.<br><br>
      NOTE: When using $we in combination with regular weekdays (from 0-6), switchingtimes may be combined. If you want $we to be given priority when true, add a "|w" at the end of the respective profile:<br><br>
      <ul><b>[&lt;weekdays&gt;|]&lt;time&gt;|&lt;parameter&gt;|w</b></ul><br>
      </ul>
      <ul>Example for a <b><a href="#weekprofile">weekprofile</a></b> definition:</ul><br>
      <ul><ul><b>weekprofile:&lt;weekprofile-device-name&gt;</b></ul></ul><br>  
      <ul>Example for a <b>weekprofile</b> definition using sunday profile for all $we days, giving exclusive priority to the $we profile:</ul><br>
      <ul><ul><b>weekprofile:&lt;weekprofile-device-name&gt;:true</b></ul><br>  
      NOTE: only temperature profiles can be set via weekprofile, but they have the advantage of possible updates from weekprofile side (including the use of so-called topics) or via the command: 
      <code>set &lt;device&gt; weekprofile &lt;weekprofile-device:topic:profile&gt;</code><br><br>  
    </ul>
    <p>
    <ul><b>command</b><br>
      If no condition is set, all the rest is interpreted as a command. Perl-code is setting up
      by the well-known Block with {}.<br>
      Note: if a command is defined only this command is executed. In case of executing
      a "set desired-temp" command, you must define the hole commandpart explicitly by yourself.<br>
      

  <!----------------------------------------------------------------------------- -->
  <!-- -------------------------------------------------------------------------- -->
      The following parameter are replaced:<br>
        <ol>
          <li>$NAME  => the device to switch</li>
          <li>$EVENT => the new temperature</li>
        </ol>
    </ul>
    <p>
    <ul><b>condition</b><br>
      if a condition is defined you must declare this with () and a valid perl-code.<br>
      The return value must be boolean.<br>
      The parameters $NAME and $EVENT will be interpreted.
    </ul>
    <p>
    <b>Examples:</b>
    <ul>
        <code>define shutter WeekdayTimer bath 12345|05:20|up  12345|20:30|down</code><br>
        Mo-Fr are setting the shutter at 05:20 to <b>up</b>, and at 20:30 <b>down</b>.<p>

        <code>define heatingBath WeekdayTimer bath 07:00|16 Mo,Tu,Th-Fr|16:00|18.5 20:00|eco
          {fhem("set dummy on"); fhem("set $NAME desired-temp $EVENT");}</code><br>
        At the given times and weekdays only(!) the command will be executed.<p>

        <code>define dimmer WeekdayTimer livingRoom Sa-Su,We|07:00|dim30% Sa-Su,We|21:00|dim90% (ReadingsVal("WeAreThere", "state", "no") eq "yes")</code><br>
        The dimmer is only set to dimXX% if the dummy variable WeAreThere is "yes"(not a real live example).<p>

        If you want to have set all WeekdayTimer their current value (e.g. after a temperature lowering phase holidays)
        you can call the function <b>WeekdayTimer_SetParm("WD-device")</b> or <b>WeekdayTimer_SetAllParms()</b>.<br>
        To limit the affected WeekdayTimer devices to a subset of all of your WeekdayTimers, use the WDT_Group attribute and <b>WeekdayTimer_SetAllParms("<group name>")</b>.<br> This offers the same functionality than <code>set wd WDT_Params WDT_Group</code>
        This call can be automatically coupled to a dummy by a notify:<br>
        <code>define dummyNotify notify Dummy:. * {WeekdayTimer_SetAllParms()}</code>
        <br><p>
        Some definitions without comment:
        <code>
        <pre>
        define wd    Weekdaytimer  device de         7|23:35|25        34|23:30|22 23:30|16 23:15|22     8|23:45|16
        define wd    Weekdaytimer  device de         fr,$we|23:35|25   34|23:30|22 23:30|16 23:15|22    12|23:45|16
        define wd    Weekdaytimer  device de         20:35|25          34|14:30|22 21:30|16 21:15|22    12|23:00|16

        define wd    Weekdaytimer  device de         mo-so, $we|{sunrise_abs_dat($date)}|on       mo-so, $we|{sunset_abs_dat($date)}|off
        define wd    Weekdaytimer  device de         mo-so,!$we|{sunrise_abs_dat($date)}|aus      mo-so,!$we|{sunset_abs_dat($date)}|aus

        define wd    Weekdaytimer  device de         {sunrise_abs_dat($date)}|19           {sunset_abs_dat($date)}|21
        define wd    Weekdaytimer  device de         22:35|25  23:00|16
        </code></pre>
        The daylist can be given globaly for the whole Weekdaytimer:<p>
        <code><pre>
        define wd    Weekdaytimer device de  !$we     09:00|19  (function("Ein"))
        define wd    Weekdaytimer device de   $we     09:00|19  (function("Ein"))
        define wd    Weekdaytimer device de   78      09:00|19  (function("exit"))
        define wd    Weekdaytimer device de   57      09:00|19  (function("exit"))
        define wd    Weekdaytimer device de  fr,$we   09:00|19  (function("exit"))
        </code></pre>
    </ul>
  </ul>

  <a name="WeekdayTimerset"></a>
  <b>Set</b>
    <ul><br>
    <code><b><font size="+1">set &lt;name&gt; &lt;value&gt;</font></b></code>
    <br><br>
    where <code>value</code> is one of:<br>
    <pre>
    <b>disable</b>               # disables the WeekdayTimer
    <b>enable</b>                # enables  the WeekdayTimer, switching times will be recaltulated. 
    <b>WDT_Params [one of: single, WDT_Group or all]</b>
    <b>weekprofile &lt;weekprofile-device:topic:profile&gt;</b></pre>
    <br>
    You may especially use <b>enable</b> in case one of your global holiday2we devices has changed since 5 seconds past midnight.
    <br><br>
    <b>Examples</b>:
    <ul>
      <code>set wd disable</code><br>
      <code>set wd enable</code><br>
      <code>set wd WDT_Params WDT_Group</code><br>
      <code>set wd weekprofile myWeekprofiles:holiday:livingrooms</code><br>
    </ul>
    <ul>
    The WDT_Params function can be used to reapply the current switching value to the device, all WDT devices with identical WDT_Group attribute or all WeekdayTimer devices; delay conditions will be obeyed, for non-heating type devices, switchInThePast has to be set.
    </ul>
    <ul>
    <br>
    NOTES on <b>weekprofile</b> usage:<br><br>
    <ul>
      <li>The weekprofile set will only be successfull, if the &lt;weekprofile-device&gt; is part of the definition of the WeekdayTimer, the mentionned device exists and it provides data for the &lt;topic:profile&gt; combination. If you haven't activated the "topic" feature in the weekprofile device, use "default" as topic.</li> 
      <li>Once you set a weekprofile for any weekprofile device, you'll find the values set in the reading named "weekprofiles"; for each weekprofile device there's an entry with the set triplett.</li><br>
      <li>As WeekdayTimer will recalculate the switching times for each day a few seconds after midnight, 10 minutes pas midnight will be used as a first switching time for weekpofile usage.</li><br>
      <li>This set is the way the weekprofile module uses to update a WeekdayTimer device. So aforementioned WeekdayTimer command<br>
      <code>set wd weekprofile myWeekprofiles:holiday:livingrooms</code><br>
      is aequivalent to weekprofile command<br>
      <code>set myWeekprofiles send_to_device holiday:livingrooms wd</code><br>
      </li><br>
      <li>Although it's possible to use more than one weekprofile device in a WeekdayTimer, this is explicitly not recommended despite you are exactly knwowing what you are doing.</li><br>
    </ul>	
    </ul>
  </ul>
  <a name="WeekdayTimerget"></a>
  <b>Get</b> <ul>N/A</ul><br>

  <a name="WeekdayTimerattr"></a>
  <b>Attributes</b>
  <ul>
    <li>delayedExecutionCond <br>
    defines a delay Function. When returning true, the switching of the device is delayed until the function returns a false value. The behavior is just like a windowsensor in Heating_Control.

    <br><br>
    <b>Example:</b>
    <pre>
    attr wd delayedExecutionCond isDelayed("$WEEKDAYTIMER","$TIME","$NAME","$EVENT")
    </pre>
    the parameter $WEEKDAYTIMER(timer name) $TIME $NAME(device name) $EVENT are replaced at runtime by the correct value.
    <br><br>
    <b>Example of a function:</b>
    <pre>
    sub isDelayed($$$$) {
       my($wdt, $tim, $nam, $event ) = @_;

       my $theSunIsStillshining = ...

       return ($tim eq "16:30" && $theSunIsStillshining) ;
    }
    </pre>
    </li>
    <li>WDT_delayedExecutionDevices<br>
    Defines a space separated list devices (atm only window sensors are supported). When one of its state readings is <b>open</b> the aktual switch is delayed.</li><br>
    <br>
    <li>WDT_Group<br>
    Used to generate groups of WeekdayTimer devices to be switched together in case one of them is set to WDT_Params with the WDT_Group modifier, e.g. <code>set wd WDT_Params WDT_Group</code>.<br>This is intended to allow former Heating_Control devices to be migrated to WeekdayTimer and replaces the Heating_Control_SetAllTemps() functionality.</li><br>

    <li>switchInThePast<br>
    defines that the depending device will be switched in the past in definition and startup phase when the device is not recognized as a heating.
    Heatings are always switched in the past.
    </li>

    <li><a href="#disable">disable</a></li>
    <li><a href="#loglevel">loglevel</a></li>
    <li><a href="#event-on-update-reading">event-on-update-reading</a></li>
    <li><a href="#event-on-change-reading">event-on-change-reading</a></li>
    <li><a href="#stateFormat">stateFormat</a></li>
  <br>
  </ul>
</ul>

=end html

=for :application/json;q=META.json 98_WeekdayTimer.pm
{
   "abstract" : "sends parameter to devices at defined times",
   "x_lang" : {
      "de" : {
         "abstract" : "sendet Parameter an Devices zu einer Liste mit festen Zeiten"
      }
   },
   "keywords" : [
      "heating",
      "Heizung"
   ],
   "prereqs" : {
      "runtime" : {
         "requires" : {
            "Data::Dumper" : "0",
            "POSIX" : "0",
            "Time::Local" : "0",
            "strict" : "0",
            "warnings" : "0"
         }
      }
   }
}
=end :application/json;q=META.json

=cut
