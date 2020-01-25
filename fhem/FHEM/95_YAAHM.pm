﻿########################################################################################
#
# YAAHM.pm
#
# Yet Another Auto Home Module for FHEM
#
# Prof. Dr. Peter A. Henning
#
# $Id: 95_YAAHM.pm 19350 2019-05-08 18:01:13Z phenning $
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
#  TODO: 
#     Wenn Geräteaktion auf Wecken steht, wird bei manuellem Wecken nicht ausgelöst. Also besser umstellen von ZEIT auf Weckevent
#     Wieso Tageszeit ab 8:00, wenn schon um 7:30 geweckt wurde ?
#
########################################################################################

package main;

use strict;
use warnings;
use vars qw(%defs);		        # FHEM device/button definitions
use vars qw($FW_ME);
use vars qw($FW_inform);
use vars qw($FW_headerlines);
use vars qw($FW_id);

use Data::Dumper;
use Math::Trig;
use JSON;      # imports encode_json, decode_json, to_json and from_json.

#########################
# Global variables
my $yaahmname;
my $yaahmlinkname   = "Profile";     # link text
my $yaahmhiddenroom = "ProfileRoom"; # hidden room
my $yaahmpublicroom = "Unsorted";    # public room
my $yaahmversion    = "3.1";
my $firstcall       = 1;
    
my %yaahm_transtable_EN = ( 
    "ok"                =>  "OK",
    "notok"             =>  "Not OK",
    "start"             =>  "Start",
    "status"            =>  "Status",
    "notstarted"        =>  "Not started",
    "next"              =>  "Next",
    "manual"            =>  "Manual Time",
    "exceptly"          =>  "exceptionally",
    "undecid"           =>  "not decidable",
    "off"               =>  "off",
    "swoff"             =>  "switched off",
    "and"               =>  "and",
    "clock"             =>  "",
    "device"            =>  "Device",
    "devices"           =>  "Devices ",
    "deviceaction"      =>  "Device Action ",
    "deviceactions"     =>  "Device Actions ",
    "active"            =>  "Active",
    "inactive"          =>  "Inactive",
    "overview"          =>  "Summary",
    "name"              =>  "Name", 
    "event"             =>  "Event", 
    "time"              =>  "Time",
    "timer"             =>  "Timer",
    "earliest"          =>  "Earliest",
    "latest"            =>  "Latest",
    "action"            =>  "Action",
    "weekly"            =>  "Weekly ",
    "day"               =>  "Day",
    "daytime"           =>  "Daytime",
    "nighttime"         =>  "Nighttime",
    "daylight"          =>  "Daylight",
    "daytype"           =>  "Day Type",
    "daily"             =>  "Daily ",
    "type"              =>  "Type",
    "description"       =>  "Description",
    "profile"           =>  "Profile",
    "profiles"          =>  "Profiles",
    "transition"        =>  "Transition to",
    "onlposfrm"         =>  "only possible from",
    "notposfrm"         =>  "not possible from",
    #--
    "aftermidnight"     =>  "After Midnight",
    "beforesunrise"     =>  "Before Sunrise",
    "sunrise"           =>  "Sunrise",
    "aftersunrise"      =>  "After Sunrise",
    "wakeup"            =>  "WakeUp",
    "morning"           =>  "Morning",
    "noon"              =>  "Noon",
    "afternoon"         =>  "Afternoon",
    "evening"           =>  "Evening",
    "beforesunset"      =>  "Before Sunset",
    "sunset"            =>  "Sunset",
    "aftersunset"       =>  "After Sunset",
    "sleep"             =>  "Sleep",
    "night"             =>  "Night",
    "beforemidnight"    =>  "Before Midnight",
    #--
    "date"              =>  "Date",
    "today"             =>  "Today",
    "tomorrow"          =>  "Tomorrow",
    "weekday"           =>  "Day of Week",
    #--
    "mode"              =>  "Mode",
    "normal"            =>  "Normal",
    "party"             =>  "Party",
    "absence"           =>  "Absence",
    "donotdisturb"      =>  "DoNotDisturb",
    #--
    "state"             =>  "Security",
    "secstate"          =>  "Device states",
    "unlocked"          =>  "Unlocked",
    "locked"            =>  "Locked",
    "unsecured"         =>  "Not Secured",
    "secured"           =>  "Secured",
    "protected"         =>  "Protected",
    "guarded"           =>  "Guarded",
    #--
    "monday"    =>  ["Monday","Mon"],
    "tuesday"   =>  ["Tuesday","Tue"],
    "wednesday" =>  ["Wednesday","Wed"],
    "thursday"  =>  ["Thursday","Thu"],
    "friday"    =>  ["Friday","Fri"],
    "saturday"  =>  ["Saturday","Sat"],
    "sunday"    =>  ["Sunday","Sun"],
    "weekend"   =>  ["Weekend","We"],
    "holiday"   =>  ["Holiday","Hol"],
    "vacation"  =>  ["Vacation","Vac"],
    "workday"   =>  ["Workday","Wor"],
    #--
    "spring"    => "Spring",
    "summer"    => "Summer",
    "fall"      => "Fall",
    "winter"    => "Winter"
    );
    
 my %yaahm_transtable_DE = ( 
    "ok"                =>  "OK",
    "notok"             =>  "Nicht OK",
    "start"             =>  "Start",
    "status"            =>  "Status",
    "notstarted"        =>  "Nicht gestartet",
    "next"              =>  "Nächste",
    "manual"            =>  "Manuelle Zeit",
    "clock"             =>  "Uhr",
    "device"            =>  "Gerät",
    "devices"           =>  "Geräte-",
    "deviceaction"      =>  "Geräte-Aktions-",
    "deviceactions"     =>  "Geräte-Aktionen",
    "exceptly"          =>  "ausnahmsweise",
    "undecid"           =>  "nicht bestimmbar",
    "off"               =>  "Aus",
    "swoff"             =>  "ausgeschaltet",
    "and"               =>  "und",
    "active"            =>  "Aktiv",
    "inactive"          =>  "Inaktiv",
    "overview"          =>  "Zusammenfassung",
    "name"              =>  "Name", 
    "event"             =>  "Event", 
    "time"              =>  "Zeit",
    "timer"             =>  "Timer",
    "earliest"          =>  "Frühestens",
    "latest"            =>  "Spätestens",
    "action"            =>  "Aktion",
    "weekly"            =>  "Wochen-",
    "day"               =>  "Tag",
    "daytime"           =>  "Tageszeit",
    "nighttime"         =>  "Nachtzeit",
    "daylight"          =>  "Tageslicht",
    "daytype"           =>  "Tagestyp",
    "daily"             =>  "Tages-",
    "type"              =>  "Typ",
    "description"       =>  "Beschreibung",
    "profile"           =>  "Profil",
    "profiles"          =>  "Profile",
    "transition"        =>  "Übergang zu",
    "onlposfrm"         =>  "nur möglich aus",
    "notposfrm"         =>  "nicht möglich aus",
    #--
    "aftermidnight"     =>  "Nach Mitternacht",
    "beforesunrise"     =>  "Vor Sonnenaufgang",
    "sunrise"           =>  "Sonnenaufgang",
    "aftersunrise"      =>  "Nach Sonnenaufgang",
    "wakeup"            =>  "Wecken",
    "morning"           =>  "Morgen",
    "noon"              =>  "Mittag",
    "afternoon"         =>  "Nachmittag",
    "evening"           =>  "Abend",
    "beforesunset"      =>  "Vor Sonnenuntergang",
    "sunset"            =>  "Sonnenuntergang",
    "aftersunset"       =>  "Nach Sonnenuntergang",
    "sleep"             =>  "Schlafen",
    "night"             =>  "Nacht",
    "beforemidnight"    =>  "Vor Mitternacht",
    #--
    "date"              =>  "Termin",
    "today"             =>  "Heute",
    "tomorrow"          =>  "Morgen",
    "weekday"           =>  "Wochentag",
    #--
    "mode"              =>  "Modus",
    "normal"            =>  "Normal",
    "party"             =>  "Party",
    "absence"           =>  "Abwesenheit",
    "donotdisturb"      =>  "Nicht Stören",
    #--
    "state"             =>  "Sicherheit",
    "secstate"          =>  "Device States",
    "unlocked"          =>  "Unverschlossen",
    "locked"            =>  "Verschlossen",
    "unsecured"         =>  "Nicht Gesichert",
    "secured"           =>  "Gesichert",
    "protected"         =>  "Geschützt",
    "guarded"           =>  "Überwacht",
    #--
    "monday"    =>  ["Montag","Mo"],
    "tuesday"   =>  ["Dienstag","Di"],
    "wednesday" =>  ["Mittwoch","Mi"],
    "thursday"  =>  ["Donnerstag","Do"],
    "friday"    =>  ["Freitag","Fr"],
    "saturday"  =>  ["Samstag","Sa"],
    "sunday"    =>  ["Sonntag","So"],
    "weekend"   =>  ["Wochenende","We"],
    "holiday"   =>  ["Feiertag","Fei"],
    "vacation"  =>  ["Urlaubstag","Url"],
    "workday"   =>  ["Arbeitstag","Arb"],
    #--
    "spring"    => "Frühling",
    "summer"    => "Sommer",
    "fall"      => "Herbst",
    "winter"    => "Winter"
    );
    
my $yaahm_tt;

#-- default values, need to be overwritten from save file
# first and second parameter
#   entries in the default table with no time entry are single-timers
#   entries in the default table with only first time are single-timers
#   entries in the default table with only second time are single-timer offsets
#   entries in the default table with first an second time are two-timer periods
# third parameter
# fourth parameter

my %defaultdailytable = ( 
    "aftermidnight"     =>  [undef,"00:01",undef,undef],
    "beforesunrise"     =>  [undef,"01:00",undef,undef],
    "sunrise"           =>  [undef,undef,undef,undef],
    "aftersunrise"      =>  [undef,"01:00",undef,undef],
    "wakeup"            =>  ["06:15",undef,undef,undef],
    "morning"           =>  ["08:00",undef,undef,undef],
    "noon"              =>  ["13:00",undef,undef,undef],
    "afternoon"         =>  ["14:00",undef,undef,undef],
    "evening"           =>  ["18:30",undef,undef,undef],
    "beforesunset"      =>  [undef,"01:00",undef,undef],
    "sunset"            =>  [undef,undef,undef,undef],
    "aftersunset"       =>  [undef,"01:00",undef,undef],
    "sleep"             =>  ["22:30",undef,undef,undef],
    "night"             =>  ["22:00",undef,undef,undef],
    "beforemidnight"    =>  [undef,"00:05",undef,undef]);
   
my $defaultdailykeys = "(".join(")|(",keys %defaultdailytable).")";
    
my %dailytable = ();

sub YAAHM_dsort { 
  $dailytable{$a}[0] cmp $dailytable{$b}[0]
}
    
my @weeklytable = (
    "monday",    
    "tuesday",  
    "wednesday", 
    "thursday",
    "friday",   
    "saturday",  
    "sunday",
    "holiday",
    "vacation");
    
my %defaultwakeuptable = (
    "name"      =>  "",
    "action"    =>  "",
    "monday"    =>  "06:15",
    "tuesday"   =>  "06:15",
    "wednesday" =>  "06:15",
    "thursday"  =>  "06:15",
    "friday"    =>  "06:15",
    "saturday"  =>  "off",
    "sunday"    =>  "off");
    
my %defaultsleeptable = (
    "name"      =>  "",
    "action"    =>  "",
    "monday"    =>  "22:30",
    "tuesday"   =>  "22:30",
    "wednesday" =>  "22:30",
    "thursday"  =>  "22:30",
    "friday"    =>  "23:00",
    "saturday"  =>  "23:00",
    "sunday"    =>  "22:30");
    
my @daytype = (
    "workday",
    "vacation",
    "weekend",
    "holiday");
   
my %defaultdayproperties = (
    "date"      =>  "",
    "weekday"   =>  "",
    "daytype"   =>  0,
    "desc"      =>  "",
    "season"    =>  "");

my @times = (keys %defaultdailytable);
    
my @modes = (
    "normal","party","absence","donotdisturb");
   
my @states = (
    "unsecured","secured","protected","guarded");
    

my @seasons = (
    "winter","spring","summer","fall");
 
#-- modes or day types that affect the profile
my @profmode = ("party","absence","donotdisturb");
my @profday  = ("holiday","vacation"); 

#-- color schemes
my @csmode;
my @csmode1  = ("#53f3c7","#8bfa56","#ff9458","#fd5777");

my @csstate;
my @csstate1 = ("#53f3c7","#ff9458","#f554e2","#fd5777");

#-- temporary fix for update purpose
sub YAAHM_restore($$){};
sub YAAHM_setWeeklyTime($){};

#########################################################################################
#
# YAAHM_Initialize 
# 
# Parameter hash = hash of device addressed 
#
#########################################################################################

sub YAAHM_Initialize ($) {
  my ($hash) = @_;
		
  $hash->{DefFn}       = "YAAHM_Define";
  $hash->{SetFn}   	   = "YAAHM_Set";  
  $hash->{GetFn}       = "YAAHM_Get";
  $hash->{UndefFn}     = "YAAHM_Undef";   
  $hash->{AttrFn}      = "YAAHM_Attr";
  my $attst            = "linkname publicroom hiddenroom lockstate:locked,unlocked simulation:0,1 norepeat:0,1 ".
                         "modecolor0 modecolor1 modecolor2 modecolor3 statecolor0 statecolor1 statecolor2 statecolor3 ".
                         "timeHelper modeHelper modeAuto:0,1 stateDevices:textField-long stateInterval noicons:0,1 stateWarning stateHelper stateAuto:0,1 ".
                         "deviceActions:textField-long ".
                         "sunrise:SunRise,AstroTwilightMorning,NauticTwilightMorning,CivilTwilightMorning,CustomTwilightMorning ".
                         "sunset:SunSet,AstroTwilightEvening,NauticTwilightEvening,CivilTwilightEvening,CustomTwilightEvening ".
                         "holidayDevices:textField-long vacationDevices:textField-long specialDevices:textField-long";
 
  $hash->{AttrList}    = $attst;
  
  if( !defined($yaahm_tt) ){
    #-- in any attribute redefinition readjust language
    my $lang = AttrVal("global","language","EN");
    if( $lang eq "DE"){
      $yaahm_tt = \%yaahm_transtable_DE;
    }else{
      $yaahm_tt = \%yaahm_transtable_EN;
    }
  }
  $yaahmlinkname = $yaahm_tt->{"profiles"};
  #-- default colors
  @csmode  = @csmode1;
  @csstate = @csstate1;
  
  $data{FWEXT}{YAAHMx}{LINK} = "?room=".$yaahmhiddenroom;
  $data{FWEXT}{YAAHMx}{NAME} = $yaahmlinkname;		
  
  $data{FWEXT}{"/YAAHM_timewidget"}{FUNC} = "YAAHM_timewidget";
  $data{FWEXT}{"/YAAHM_timewidget"}{FORKABLE} = 0;	  
	
  return undef;
}

#########################################################################################
#
# YAAHM_Define - Implements DefFn function
# 
# Parameter hash = hash of device addressed, def = definition string
#
#########################################################################################

sub YAAHM_Define ($$) {
  my ($hash, $def) = @_;
  my $now  = time();
  my $name = $hash->{NAME}; 
  my $TYPE = $hash->{TYPE};
 
  $hash->{VERSION} = $yaahmversion;
  $yaahmname       = $name;

  #-- readjust language
  my $lang = AttrVal("global","language","EN");
  if( $lang eq "DE"){
    $yaahm_tt = \%yaahm_transtable_DE;
  }else{
    $yaahm_tt = \%yaahm_transtable_EN;
  }
 
  #-- default colors
  @csmode  = @csmode1;
  @csstate = @csstate1;

  # NOTIFYDEV
  my $NOTIFYDEV = "global,$name";
  unless ( defined( $hash->{NOTIFYDEV} ) && $hash->{NOTIFYDEV} eq $NOTIFYDEV )
  {
    $hash->{NOTIFYDEV} = $NOTIFYDEV;
    #$changed = 1;
  }

 readingsSingleUpdate( $hash, "state", "Initialized", 1 ); 
 
 $yaahmlinkname             = defined($attr{$name}{"linkname"})  ? $attr{$name}{"linkname"} : $yaahmlinkname; 
 $yaahmhiddenroom           = defined($attr{$name}{"hiddenroom"})  ? $attr{$name}{"hiddenroom"} : $yaahmhiddenroom;  
 $data{FWEXT}{YAAHMx}{LINK} = "?room=".$yaahmhiddenroom;
 $data{FWEXT}{YAAHMx}{NAME} = $yaahmlinkname;	
 $attr{$name}{"room"}       = $yaahmhiddenroom;
 
 my $date = YAAHM_restore($hash,0);
 
 #-- data seems to be ok, restore
 if( defined($date) ){
   YAAHM_restore($hash,1);
   Log3 $name,1,"[YAAHM_Define] data hash restored from save file with date $date";
   if( !defined($hash->{DATA}{"XT"}) ){
     $hash->{DATA}{"XT"} = {};
   }
 #-- intialization
 }else{
   Log3 $name,1,"[YAAHM_Define] data hash is initialized";
   #-- ZERO device action entries profile
   $hash->{DATA}{"XT"} = {};
   
   #-- clone daily default profile
   $hash->{DATA}{"DT"}  = {%defaultdailytable};
 
   #-- clone weekly default profile
   $hash->{DATA}{"WT"} = ();
   push(@{$hash->{DATA}{"WT"}},{%defaultwakeuptable});
   $hash->{DATA}{"WT"}[0]{"name"} = $yaahm_tt->{"wakeup"};
   push(@{$hash->{DATA}{"WT"}},{%defaultsleeptable});
   $hash->{DATA}{"WT"}[1]{"name"} = $yaahm_tt->{"sleep"};
   
   
   #-- clone days for today and tomorrow
   $hash->{DATA}{"DD"}  = ();
   push(@{$hash->{DATA}{"DD"}},{%defaultdayproperties});
   push(@{$hash->{DATA}{"DD"}},{%defaultdayproperties});
   
   #-- initial mode and state
   $hash->{DATA}{"HSM"}{"state"}="unsecured";
   $hash->{DATA}{"HSM"}{"mode"}="normal";
 }
 
 #-- determine Astro device
 if( !exists($modules{Astro}{defptr}) ){
   Log3 $name,1,"[YAAHM] does not find an Astro device, loading module Astro separately";
   require "95_Astro.pm";
 }else{
   my @keys = sort keys %{$modules{Astro}{defptr}};
   Log3 $name,1,"[YAAHM] finds ".int(@keys)." Astro devices, module not loaded separately";
 }
    
 #--
 $modules{YAAHM}{defptr}{$name} = $hash;
 
 RemoveInternalTimer($hash);
 InternalTimer      ($now + 5, 'YAAHM_CreateEntry', $hash, 0);

 return;
}

#########################################################################################
#
# YAAHM_Undef - Implements Undef function
# 
# Parameter hash = hash of device addressed, def = definition string
#
#########################################################################################

sub YAAHM_Undef ($$) {
  my ($hash,$arg) = @_;
  
  my $name = $hash->{NAME};
  
  RemoveInternalTimer($hash);
  delete $data{FWEXT}{YAAHMx};
  if (defined $defs{$name."_weblink"}) {
      FW_fC("delete ".$name."_weblink");
      Log3 $hash, 3, "[".$name. " V".$yaahmversion."]"." Weblink ".$name."_weblink deleted";
  }
  if (defined $defs{$name."_shortlink"}) {
      FW_fC("delete ".$name."_shortlink");
      Log3 $hash, 3, "[".$name. " V".$yaahmversion."]"." Weblink ".$name."_shortlink deleted";
  }
  delete($modules{YAAHM}{defptr});
  return undef;
}

#########################################################################################
#
# YAAHM_Attr - Implements Attr function
# 
# Parameter hash = hash of device addressed, ???
#
#########################################################################################

sub YAAHM_Attr($$$) {
  my ($cmd, $name, $attrName, $attrVal) = @_;
  
  my $hash = $defs{"$name"};
  
  #-- in any attribute redefinition readjust language
  my $lang = AttrVal("global","language","EN");
  if( $lang eq "DE"){
    $yaahm_tt = \%yaahm_transtable_DE;
  }else{
    $yaahm_tt = \%yaahm_transtable_EN;
  }
  
  #---------------------------------------
  if ( $attrName eq "timeHelper" ) {
    my $dh = (defined($attr{$name}{"timeHelper"})) ? $attr{$name}{"timeHelper"} : undef;
    #-- remove this function from all entries
    if( $cmd eq "del" ){
      foreach my $key (keys %defaultdailytable){
        my $xval = $hash->{DATA}{"DT"}{$key}[2];
        if( $xval =~ /^{$dh/){
          my @cmds = split(',',$xval);
          shift(@cmds);
          $xval = join(',',@cmds);
          $hash->{DATA}{"DT"}{$key}[2] = $xval;
        }
      }
    }
  #---------------------------------------  
  }elsif ( ($cmd eq "set") && ($attrName =~ /modecolor(\d)/) ) {
    my $ci = $1;
    if( $ci >= 0 && $ci <= 3 ){
      $csmode[$ci] = $attrVal;
    }   
    
  #---------------------------------------  
  }elsif ( ($cmd eq "del") && ($attrName =~ /modecolor(\d)/) ) {
    my $ci = $1;
    if( $ci >= 0 && $ci <= 3 ){
      $csmode[$ci] = $csmode1[$ci];
    }   
   #---------------------------------------  
  }elsif ( ($cmd eq "set") && ($attrName =~ /statecolor(\d)/) ) {
    my $ci = $1;
    if( $ci >= 0 && $ci <= 3 ){
      $csstate[$ci] = $attrVal;
    }   
    
  #---------------------------------------  
  }elsif ( ($cmd eq "del") && ($attrName =~ /statecolor(\d)/) ) {
    my $ci = $1;
    if( $ci >= 0 && $ci <= 3 ){
      $csstate[$ci] = $csstate1[$ci];
    }   
  #---------------------------------------  
  }elsif ( ($cmd eq "set") && ($attrName eq "linkname") ) {
    
    $yaahmlinkname = $attrVal;
    $data{FWEXT}{YAAHMx}{NAME} = $yaahmlinkname;	
  
  #---------------------------------------  
  }elsif ( ($cmd eq "set") && ($attrName eq "publicroom") ) {
    
    $yaahmpublicroom = $attrVal;
    FW_fC("attr ".$name."_shortlink room ".$yaahmpublicroom);	
    
  #---------------------------------------
  }elsif ( ($cmd eq "set") && ($attrName eq "hiddenroom") ){
    #-- remove old hiddenroom from FHEMWEB instances
    foreach my $dn (sort keys %defs) {
      if ($defs{$dn}{TYPE} eq "FHEMWEB" && $defs{$dn}{NAME} !~ /FHEMWEB:/) {
	     my $hr = AttrVal($defs{$dn}{NAME}, "hiddenroom", "");	
	     $hr =~ s/$yaahmhiddenroom//;
	     $hr =~ s/,,//;
	     $hr =~ s/,$//;
		 FW_fC("attr ".$defs{$dn}{NAME}." hiddenroom ".$hr);
      }
    }
    
    #-- new value
    $yaahmhiddenroom = $attrVal;
    $data{FWEXT}{YAAHMx}{LINK} = "?room=".$yaahmhiddenroom;
    FW_fC("attr ".$name."_weblink room ".$yaahmhiddenroom);
    #-- place into FHEMWEB instances
    foreach my $dn (sort keys %defs) {
      if ($defs{$dn}{TYPE} eq "FHEMWEB" && $defs{$dn}{NAME} !~ /FHEMWEB:/) {
	     my $hr = AttrVal($defs{$dn}{NAME}, "hiddenroom", "");	
	     if (index($hr,$yaahmhiddenroom) == -1){ 		
		    if ($hr eq "") {
		       FW_fC("attr ".$defs{$dn}{NAME}." hiddenroom ".$yaahmhiddenroom);
		    }else {
		       FW_fC("attr ".$defs{$dn}{NAME}." hiddenroom ".$hr.",".$yaahmhiddenroom);
		    }
		    Log3 $hash, 3, "[".$name. " V".$yaahmversion."]"." Added hidden room '".$yaahmhiddenroom."' to ".$defs{$dn}{NAME};
	     }	
      }
   }

  #---------------------------------------  
  }elsif ( ($cmd eq "delete") && ($attrName eq "stateDevices") ) {
    fhem("deletereading $name sdev_housestate");
    fhem("deletereading $name sec_housestate");
    fhem("deletereading $name sym_housestate");
    YAAHM_RemoveInternalTimer("check",$hash);
    
  #---------------------------------------  
  }elsif ( ($cmd eq "set") && ($attrName eq "stateInterval") ) {
    my $next = gettimeofday()+AttrVal($name,"stateInterval",60)*60;
    YAAHM_RemoveInternalTimer("check",$hash);
    YAAHM_InternalTimer("check",$next, "YAAHM_checkstate", $hash, 0);
    
  #---------------------------------------  
  }elsif ( ($cmd eq "delete") && ($attrName eq "stateInterval") ) {
    my $next = gettimeofday()+3600;
    YAAHM_RemoveInternalTimer("check",$hash);
    YAAHM_InternalTimer("check",$next, "YAAHM_checkstate", $hash, 0);
    
  #---------------------------------------    
  }elsif ( $attrName eq "holidayDevices" ) {
    return "Value for $attrName has invalid format"
      unless ( $cmd eq "del" || $attrVal =~ m/^[A-Za-z\d._]+(?:,[A-Za-z\d._]*)*$/ );
  #---------------------------------------
  }elsif ( $attrName eq "vacationDevices" ) {
    return "Value for $attrName has invalid format"
      unless ( $cmd eq "del" || $attrVal =~ m/^[A-Za-z\d._]+(?:,[A-Za-z\d._]*)*$/ );
  }

  return;  
}

#########################################################################################
#
# YAAHM_CreateEntry - Puts the YAAHM entry into the FHEM menu
# 
# Parameter hash = hash of device addressed
#
#########################################################################################

sub YAAHM_CreateEntry($) {
   my ($hash) = @_;
 
   my $name = $hash->{NAME};
   
   $yaahmlinkname   = defined($attr{$name}{"linkname"})    ? $attr{$name}{"linkname"}   : $yaahmlinkname; 
   $yaahmpublicroom = defined($attr{$name}{"publicroom"})  ? $attr{$name}{"publicroom"} : $yaahmpublicroom;  
   $yaahmhiddenroom = defined($attr{$name}{"hiddenroom"})  ? $attr{$name}{"hiddenroom"} : $yaahmhiddenroom;  
   
   #-- this is the long YAAHM entry
   FW_fC("defmod ".$name."_weblink weblink htmlCode {YAAHM_Longtable(\"".$name."\")}");
   Log3 $hash, 3, "[".$name. " V".$yaahmversion."]"." Weblink ".$name."_weblink created";
   FW_fC("attr ".$name."_weblink room ".$yaahmhiddenroom)
     if(!defined($attr{$name."_weblink"}{"room"}));  
   
   #-- this is the short YAAHM entry
   FW_fC("defmod ".$name."_shortlink weblink htmlCode {YAAHM_Shorttable(\"".$name."\")}");
   Log3 $hash, 3, "[".$name. " V".$yaahmversion."]"." Weblink ".$name."_shortlink created";
   FW_fC("attr ".$name."_shortlink room ".$yaahmpublicroom)
     if(!defined($attr{$name."_shortlink"}{"room"}));  
   
   foreach my $dn (sort keys %defs) {
      if ($defs{$dn}{TYPE} eq "FHEMWEB" && $defs{$dn}{NAME} !~ /FHEMWEB:/) {
	     my $hr = AttrVal($defs{$dn}{NAME}, "hiddenroom", "");	
	     if (index($hr,$yaahmhiddenroom) == -1){ 		
		    if ($hr eq "") {
		       FW_fC("attr ".$defs{$dn}{NAME}." hiddenroom ".$yaahmhiddenroom);
		    }else {
		       FW_fC("attr ".$defs{$dn}{NAME}." hiddenroom ".$hr.",".$yaahmhiddenroom);
		    }
		    Log3 $hash, 3, "[".$name. " V".$yaahmversion."]"." Added hidden room '".$yaahmhiddenroom."' to ".$defs{$dn}{NAME};
	     }	
      }
   }
   
   #-- Start updater
   InternalTimer(gettimeofday()+ 3, "YAAHM_updater",$hash,0);
   YAAHM_InternalTimer("check",time()+ 5, "YAAHM_checkstate", $hash, 0);

}

#########################################################################################
#
# YAAHM_Set - Implements the Set function
# 
# Parameter hash = hash of device addressed
#
#########################################################################################

sub YAAHM_Set($@) {
   my ( $hash, $name, $cmd, @args ) = @_;
   
   my $imax;
   my $if;
   my $msg;
   my $exec = ( defined($attr{$name}{"simulation"})&&$attr{$name}{"simulation"}==1 ) ? 0 : 1;
   
   #-----------------------------------------------------------
   if ( $cmd =~ /^manualnext.*/ ) {
     #--timer address
     if( $args[0] =~ /^\d+/ ) {
       #-- check if valid
       if( $args[0] >= int(@{$hash->{DATA}{"WT"}}) ){
         $msg = "Error, timer number ".$args[0]." does not exist, number must be smaller than ".int( @{$hash->{DATA}{"WT"}});
         Log3 $name,1,"[YAAHM_Set] ".$msg;
         return $msg;
       }
       $cmd = "next_".$args[0];
     }else{
       my $if = undef;
       for( my $i=0;$i<int(@{$hash->{DATA}{"WT"}});$i++){
         $if = $i
           if ($hash->{DATA}{"WT"}[$i]{"name"} eq $args[0] );
       };
       #-- check if valid
       if( !defined($if) ){
         $msg = "Error: timer name ".$args[0]." not found";
         Log3 $name,1,"[YAAHM_Set] ".$msg;
         return $msg;
       }
       $cmd = "next_".$if;
     }
	 return YAAHM_nextWeeklyTime($name,$cmd,$args[1],$exec);
	 
   #-----------------------------------------------------------
   }elsif ( $cmd =~ /^checkstate.*/ ) {
     YAAHM_InternalTimer("check",time()+ $args[0], "YAAHM_checkstate", $hash, 0);
   
   #-----------------------------------------------------------
   }elsif ( $cmd =~ /^correctstate.*/ ) {
     YAAHM_correctstate($hash);
   
   #-----------------------------------------------------------
   }elsif ( $cmd =~ /^time.*/ ) {
	 return YAAHM_time($name,$args[0],$exec);
  
   #-----------------------------------------------------------
   }elsif ( $cmd =~ /^mode.*/ ) {
	 return YAAHM_mode($name,$args[0],$exec);
   
   #-----------------------------------------------------------
   }elsif ( $cmd =~ /^state.*/ ) {
	 return YAAHM_state($name,$args[0],$exec);
	 
   #-----------------------------------------------------------
   }elsif ( $cmd =~ /^lock(ed)?$/ ) {
	 readingsSingleUpdate( $hash, "lockstate", "locked", 0 ); 
	 return;
	 
   #-----------------------------------------------------------
   } elsif ( $cmd =~ /^unlock(ed)?$/ ) {
	 readingsSingleUpdate( $hash, "lockstate", "unlocked", 0 );
	 return;
	 
   #-----------------------------------------------------------
   } elsif ( $cmd =~ /^save/ ) {
	return YAAHM_save($hash);
	 
   #-----------------------------------------------------------
   } elsif ( $cmd =~ /^restore/ ) {
     return YAAHM_restore($hash,1);
   
   #-----------------------------------------------------------
   } elsif ( $cmd =~ /^initialize/ ) {
     $firstcall = 1;
     YAAHM_updater($hash);
     YAAHM_InternalTimer("check",time()+ 5, "YAAHM_checkstate", $hash, 0);
     
   #-----------------------------------------------------------
   } elsif ( $cmd eq "createWeekly" ){
     return "[YAAHM] missing name for new weekly profile"
       if( !defined($args[0]) );
     #-- find index
     $imax = int(@{$hash->{DATA}{"WT"}});
     $if= undef;
     for( my $j=0;$j<$imax;$j++){
       if($hash->{DATA}{"WT"}[$j]{"name"} eq $args[0]){
         $if = $j;
         last;
       }
     }
     return "[YAAHM] name $args[0] for weekly profile to be created is already in use"
       if( defined($if) );
     #-- clone wakeuptable
     push(@{$hash->{DATA}{"WT"}},{%defaultwakeuptable});
     $hash->{DATA}{"WT"}[$imax]{"name"} = $args[0];
     #-- save everything
     YAAHM_save($hash);
     fhem("save");
     return "[YAAHM] weekly profile $args[0] created successfully";
     
   #-----------------------------------------------------------     
   } elsif ( $cmd eq "deleteWeekly" ){
     return "[YAAHM] missing name for weekly profile to be deleted"
       if( !defined($args[0]) );
     return "[YAAHM] Default weekly profile cannot be deleted"
       if( ($args[0] eq $yaahm_tt->{"wakeup"}) || ($args[0] eq $yaahm_tt->{"sleep"}) );
     #-- find index
     $imax = int(@{$hash->{DATA}{"WT"}});
     $if= undef;
     for( my $j=2;$j<$imax;$j++){
       if($hash->{DATA}{"WT"}[$j]{"name"} eq $args[0]){
         $if = $j;
         last;
       }
     }
     return "[YAAHM] name $args[0] for weekly profile to be deleted is not known"
       if( !defined($if) );
     splice(@{$hash->{DATA}{"WT"}},$if,1);
     #-- delete timer
     fhem("delete ".$name.".wtimer_".$if.".IF");
     #-- delete readings
     for( my $j=$if;$j<$imax-1;$j++){
       $hash->{READINGS}{"ring_".$j}{VAL} = $hash->{READINGS}{"ring_".($j+1)}{VAL};
       $hash->{READINGS}{"ring_".$j."_1"}{VAL} = $hash->{READINGS}{"ring_".($j+1)."_1"}{VAL};
       $hash->{READINGS}{"next_".$j}{VAL} = $hash->{READINGS}{"next_".($j+1)}{VAL};
       $hash->{READINGS}{"today_".$j}{VAL} = $hash->{READINGS}{"today_".($j+1)}{VAL};
       $hash->{READINGS}{"today_".$j."_e"}{VAL} = $hash->{READINGS}{"today_".($j+1)."_e"}{VAL};
       $hash->{READINGS}{"tomorrow_".$j}{VAL} = $hash->{READINGS}{"tomorrow_".($j+1)}{VAL};
       $hash->{READINGS}{"tomorrow_".$j."_e"}{VAL} = $hash->{READINGS}{"tomorrow_".($j+1)."_e"}{VAL};
       $hash->{READINGS}{"tr_wake_".$j}{VAL} = $hash->{READINGS}{"tr_wake".($j+1)}{VAL};
     }
     fhem("deletereading ".$name." ring_".($imax-1));
     fhem("deletereading ".$name." ring_".($imax-1)."_1");
     fhem("deletereading ".$name." ring_".($imax-1)."x");
     fhem("deletereading ".$name." ring_".($imax-1)."_1x");
     fhem("deletereading ".$name." next_".($imax-1));
     fhem("deletereading ".$name." today_".($imax-1));
     fhem("deletereading ".$name." today_".($imax-1)."_e");
     fhem("deletereading ".$name." tomorrow_".($imax-1));
     fhem("deletereading ".$name." tomorrow_".($imax-1)."_e");
     fhem("deletereading ".$name." tr_wake_".($imax-1));
     #-- save everything
     YAAHM_save($hash);
     fhem("save");
     return "[YAAHM] weekly profile $args[0] deleted successfully";
     
   #-----------------------------------------------------------	 
   } else {
     my $str =  "";
	 return "[YAAHM] Unknown argument " . $cmd . ", choose one of".
	   " manualnext time:".join(',',@times)." mode:".join(',',@modes).
	   " state:".join(',',@states)." locked:noArg unlocked:noArg save:noArg correctstate:noArg checkstate:0,5,10 restore:noArg initialize:noArg createWeekly deleteWeekly";
   }
}

#########################################################################################
#
# YAAHM_Get - Implements the Get function
# 
# Parameter hash = hash of device addressed
#
#########################################################################################

sub YAAHM_Get($@) {
  my ($hash, @args) = @_;
  my $res  = "";
  my $msg;
  my $name = $args[0];
  
  my $arg = (defined($args[1]) ? $args[1] : "");
  if ($arg eq "version") {
    return "YAAHM.version => $yaahmversion";
  }elsif ($arg eq "test") {
    YAAHM_testWeeklyTime($hash);
    return "ok";
  }elsif ( $arg eq "next" || $arg eq "sayNext" ){
    my $if;
    #--timer address
    if( $args[2] =~ /^\d+/ ) {
      #-- check if valid
      if( $args[2] >= int(@{$hash->{DATA}{"WT"}}) ){
        $msg = "Error, timer number ".$args[2]." does not exist, number musst be smaller than ".int( @{$hash->{DATA}{"WT"}});
        Log3 $name,1,"[YAAHM_Get] ".$msg;
        return $msg;
      }
      $if=$args[2];
    }else{
      $if = undef;
      for( my $i=0;$i<int(@{$hash->{DATA}{"WT"}});$i++){
        $if = $i
          if ($hash->{DATA}{"WT"}[$i]{"name"} eq $args[1] );
      };
      #-- check if valid
      if( !defined($if) ){
        $msg = "Error: timer name ".$args[2]." not found";
        Log3 $name,1,"[YAAHM_Get] ".$msg;
        return $msg;
      }
    }
    if( $arg eq "next" ){
      return YAAHM_sayWeeklyTime($hash,$if,0);
    }else{
      return YAAHM_sayWeeklyTime($hash,$if,1);
    }
  }elsif ($arg eq "template") {
   $res  = "################## subroutine for housestate transitions ###########\n";
   $res .= "sub HouseStateHelper(\@){\n".
           "  my (\$event,\$param1,\$param2) = \@_;\n\n".
           "  Log 1,\"[HouseStateHelper] event=\$event\";\n\n".
           "  my \$time    = ReadingsVal(\"".$name."\",\"housetime\",\"\");\n".
           "  my \$phase   = ReadingsVal(\"".$name."\",\"housephase\",\"\");\n".
           "  my \$state   = ReadingsVal(\"".$name."\",\"housestate\",\"\");\n".
           "  my \$party   = (ReadingsVal(\"".$name."\",\"housemode\",\"\") eq \"party\") ? 1 : 0;\n".
           "  my \$absence = (ReadingsVal(\"".$name."\",\"housemode\",\"\") eq \"absence\") ? 1 : 0;\n".
           "  my \$dndist  = (ReadingsVal(\"".$name."\",\"housemode\",\"\") eq \"donotdisturb\") ? 1 : 0;\n";
    #-- iterate through table        
    for( my $i=0;$i<int(@states);$i++) {
           $res .= "  #---------------------------------------------------------------------\n";
           my $if = ($i == 0) ? "if" : "}elsif";
           $res .= "  ".$if."( \$event eq \"".$states[$i]."\" ){\n\n";
    }
    $res .= "  }\n}\n";
    $res .= "################## subroutine for housemode transitions ###########\n";
    $res .= "sub HouseModeHelper(\@){\n".
           "  my (\$event,\$param1,\$param2) = \@_;\n\n".
           "  Log 1,\"[HouseStateHelper] event=\$event\";\n\n".
           "  my \$time    = ReadingsVal(\"".$name."\",\"housetime\",\"\");\n".
           "  my \$phase   = ReadingsVal(\"".$name."\",\"housephase\",\"\");\n".
           "  my \$state   = ReadingsVal(\"".$name."\",\"housestate\",\"\");\n".
           "  my \$party   = (ReadingsVal(\"".$name."\",\"housemode\",\"\") eq \"party\") ? 1 : 0;\n".
           "  my \$absence = (ReadingsVal(\"".$name."\",\"housemode\",\"\") eq \"absence\") ? 1 : 0;\n".
           "  my \$dndist  = (ReadingsVal(\"".$name."\",\"housemode\",\"\") eq \"donotdisturb\") ? 1 : 0;\n";
    #-- iterate through table        
    for( my $i=0;$i<int(@modes);$i++) {
           $res .= "  #---------------------------------------------------------------------\n";
           my $if = ($i == 0) ? "if" : "}elsif";
           $res .= "  ".$if."( \$event eq \"".$modes[$i]."\" ){\n\n";
    }
    $res .= "  }\n}\n";
    $res .= "################## subroutine for housetime transitions ###########\n";
    $res .= "sub HouseTimeHelper(\@){\n".
           "  my (\$event,\$param1,\$param2) = \@_;\n\n".
           "  Log 1,\"[HouseTimeHelper] event=\$event\";\n\n".
           "  my \$time    = ReadingsVal(\"".$name."\",\"housetime\",\"\");\n".
           "  my \$phase   = ReadingsVal(\"".$name."\",\"housephase\",\"\");\n".
           "  my \$state   = ReadingsVal(\"".$name."\",\"housestate\",\"\");\n".
           "  my \$party   = (ReadingsVal(\"".$name."\",\"housemode\",\"\") eq \"party\") ? 1 : 0;\n".
           "  my \$absence = (ReadingsVal(\"".$name."\",\"housemode\",\"\") eq \"absence\") ? 1 : 0;\n".
           "  my \$dndist  = (ReadingsVal(\"".$name."\",\"housemode\",\"\") eq \"donotdisturb\") ? 1 : 0;\n".
           "  my \$todaytype = ReadingsVal(\"".$name."\",\"tr_todayType\",\"\");\n".
           "  my \$todaydesc = ReadingsVal(\"".$name."\",\"todayDesc\",\"\");\n".
           "  my \$tomorrowtype = ReadingsVal(\"".$name."\",\"tr_tomorrowType\",\"\");\n".
           "  my \$tomorrowdesc = ReadingsVal(\"".$name."\",\"tomorrowDesc\",\"\");\n";
    #-- iterate through table        
    foreach my $key (sort YAAHM_dsort keys %dailytable){
           $res .= "  #---------------------------------------------------------------------\n";
           my $if = ($key eq "aftermidnight") ? "if" : "}elsif";
           $res .= "  ".$if."( \$event eq \"".$key."\" ){\n\n";
    }
    $res .= "  }\n}\n";
   
    return $res;
  } else {
    $res = "0,1";
    for(my $i = 2; $i<int( @{$hash->{DATA}{"WT"}});$i++){
      $res .= ",".$i;
    }
    return "Unknown argument $arg choose one of next:".$res." sayNext:".$res." version:noArg template:noArg";
  }
}

#########################################################################################
#
# YAAHM_save
#
# Parameter hash = hash of the YAAHM device
#
#########################################################################################

sub YAAHM_save($) {
  my ($hash) = @_;
  my $date = TimeNow();
  $hash->{DATA}{"savedate"} = $date;
  readingsSingleUpdate( $hash, "savedate", $date, 1 ); 
  my $jhash0 = toJSON($hash->{DATA});
  my $error  = FileWrite("YAAHMFILE",$jhash0);
  return;
}
	 
#########################################################################################
#
# YAAHM_restore
#
# Parameter hash = hash of the YAAHM device
#
#########################################################################################

sub YAAHM_restore($$) {
  my ($hash,$doit) = @_;
  my $name = $hash->{NAME};
  my ($error,$jhash0) = FileRead("YAAHMFILE");
  if( defined($error) && $error ne "" ){
    Log3 $name,1,"[YAAHM_restore] read error=$error";
    return undef;
  }
  my $json   = JSON->new->utf8;
  my $jhash1 = eval{ $json->decode( $jhash0 ) };
  my $date   = $jhash1->{"savedate"};
  #-- just for the first time, reading an old savefile
  $date = localtime(time)
    if( !defined($date));
  readingsSingleUpdate( $hash, "savedate", $date, 0 ); 
  if( $doit==1 ){
    $hash->{DATA}  = {%{$jhash1}}; 
    Log3 $name,5,"[YAAHM_restore] Data hash restored from save file with date ".$date;
    return 1;
  }else{  
    return $date;
  }
}

#########################################################################################
#
# YAAHM_setParm - Receives parameter values from the javascript FE
#
# Parameter name = name of the YAAHM device
#
#########################################################################################

sub YAAHM_setParm($@) {
  my ($name, @a) = @_;
  my $hash = $defs{$name};
 
  my $cmd  = $a[0];
  my $key  = $a[1];
  my $dea  = $a[2];
  my $msg  = "";
  my $val;
  
  #-- device action profile
  #   start, end/offset, execution, active in mode / daytype
  if ($cmd eq "xt") {
    for( my $i=1;$i<6;$i++){
       $val = $a[$i+1];
       if( ($val eq "undef")||($val eq "") ){
         $val = undef;
       }elsif( ($i>3) && ($i<5) && ($val !~ /\d?\d:\d\d/)){
         $msg = "wrong time specification $val in device action profile for device no. $key, must be hh:mm";
         Log 1,"[YAAHM_setParm] ".$msg;
       }
    }
    $hash->{DATA}{"XT"}{$dea}{"name"}     = $a[2];
    #-- check ??
    $hash->{DATA}{"XT"}{$dea}{"event"}    = $a[3];
    $hash->{DATA}{"XT"}{$dea}{"earliest"} = $a[4];
    $hash->{DATA}{"XT"}{$dea}{"latest"}   = $a[5];
    $hash->{DATA}{"XT"}{$dea}{"cmd"}      = $a[6];
    return $msg;
  #-- daily profile
  #   start, end/offset, execution, active in mode / daytype
  }elsif ($cmd eq "dt") {
    for( my $i=1;$i<5;$i++){
       $val = $a[$i+1];
       if( ($val eq "undef")||($val eq "") ){
         $val = undef;
       }elsif( ($i<3) && ($val !~ /\d?\d:\d\d/)){
         $msg = "wrong time specification $val in daily profile for timer no. $key, must be hh:mm";
         Log 1,"[YAAHM_setParm] ".$msg;
         $val = "00:00";
       }elsif( $i<3 ){
         my ($hour,$min) = split(':',$val);
         if( $hour>23 || $min>59 ){
           $msg = "wrong time specification $val in daily profile for timer no. $key > 23:59";
           Log 1,"[YAAHM_setParm] ".$msg;
           $val = "00:00";
         }
       }
       $hash->{DATA}{"DT"}{$key}[$i-1]=$val;
    }
    return $msg;
  #-- weekly profile
  }elsif ($cmd eq "wt") {
    #-- action
    $hash->{DATA}{"WT"}[$a[1]]{"action"}    = $a[2];
    #-- next time
    $val = $a[3];
    if( ($val eq "undef")||($val eq "") ){
         $val = undef;
    }elsif( $val =~/^off/ ){
      #-- ok
    }elsif( $val =~ /\d?\d:\d\d/ ){
      #-- ok
      my ($hour,$min) = split(':',$val);
      if( $hour>23 || $min>59 ){
        $msg = "wrong time specification next=$val for weekly timer ".$hash->{DATA}{"WT"}[$a[1]]{"name"}." > 23:59";
        Log 1,"[YAAHM_setParm] ".$msg;
        $val = "off";
      }
    }else{
      $msg = "wrong time specification next=$val for weekly timer ".$hash->{DATA}{"WT"}[$a[1]]{"name"}.", must be hh:mm of 'off'";
      Log 1,"[YAAHM_setParm] ".$msg;
      $val = "off";
    }
    #-- next waketime
    $hash->{DATA}{"WT"}[$a[1]]{"next"}      = $val;
    #-- activity party/absence
    $hash->{DATA}{"WT"}[$a[1]]{"acti_m"}    = $a[4];
    #-- activity vacation/holiday
    $hash->{DATA}{"WT"}[$a[1]]{"acti_d"}    = $a[5];
    #-- weekdays
    for( my $i=0;$i<9;$i++){
      $val = $a[$i+6];
      if( ($val eq "undef")||($val eq "") ){
        $val = undef;
      }elsif( $val =~/^off/ ){
        #-- ok
      }elsif( $val =~ /\d?\d:\d\d/ ){
        #-- ok
        my ($hour,$min) = split(':',$val);
        if( $hour>23 || $min>59 ){
          $msg = "wrong time specification $val for weekly timer ".$hash->{DATA}{"WT"}[$a[1]]{"name"}." > 23:59 ";
          Log 1,"[YAAHM_setParm] ".$msg;
          $val = "off";
        }
      }else{
        $msg = "wrong time specification $val for weekly timer ".$hash->{DATA}{"WT"}[$a[1]]{"name"}.", must be hh:mm or 'off'";
        Log 1,"[YAAHM_setParm] ".$msg;
        $val = "off";
      }
      $hash->{DATA}{"WT"}[$a[1]]{$weeklytable[$i]} = $val;
    }
    return $msg;
  }
}

#########################################################################################
#
# YAAHM_time - Change the house time (aftermidnight .. beforemidnight)
#
# Parameter name = name of the YAAHM device
#
# Careful: $exec=0 is needed in case we want to prevent execution of helper here
#
#########################################################################################

sub YAAHM_time {
  my ($name,$targettime,$exec) = @_;
  my $hash = $defs{$name};
  
  my $prevtime   = defined($hash->{DATA}{"HSM"}{"time"})  ? $hash->{DATA}{"HSM"}{"time"}  : "";
  my $currmode   = defined($hash->{DATA}{"HSM"}{"mode"})  ? $hash->{DATA}{"HSM"}{"mode"}  : "normal";
  my $currstate  = defined($hash->{DATA}{"HSM"}{"state"}) ? $hash->{DATA}{"HSM"}{"state"}  : "unsecured";
  my $msg        = "";
  
  #-- local checks
  #-- double change
  #if( $prevtime eq $targettime ){
  #  $msg = "Transition skipped, the time event $targettime has been executed already"; 
  #}
  
  #-- don't
  if( $msg ne "" ){
    Log3 $name,1,"[YAAHM_time] ".$msg;
    return $msg;
  }
  #-- doit
  my ($sec, $min, $hour, $day, $month, $year, $wday,$yday,$isdst) = localtime(time);
  my $lval = sprintf("%02d%02d",$hour,$min);
  my $mval = $dailytable{"morning"}[0];
  my $nval = $dailytable{"night"}[0];
  
  #-- is this a daily timer event ?
  my $regex = "((".join(")|(",@times)."))";
  my $isdaily = ( $targettime =~ /$regex/ )?1:0;
  if( $isdaily ){
    my $tval = $dailytable{$targettime}[0];
  
    $mval =~ s/://;
    $nval =~ s/://;
    $tval =~ s/://;
  
    #-- targetphase always according to real time, not to command time
    my $targetphase = ( ($lval >= $mval) && ( $nval > $lval ) ) ? "daytime" : "nighttime";
  
    #-- iterate through table to find next event
    my $nexttime;
    my $sval;   
    my $oval="0000";
    foreach my $key (sort YAAHM_dsort keys %dailytable){
      $nexttime = $key;
      $sval     = $dailytable{$key}[0];
      next
        if (!defined($sval));
      $sval     =~ s/://;
      last
        if ( ($lval <= $sval) && ( $lval > $oval ) );
      $oval     = $sval;
    }
    my $ma = defined($attr{$name}{"modeAuto"}) && ($attr{$name}{"modeAuto"} == 1);
    my $sa = defined($attr{$name}{"stateAuto"}) && ($attr{$name}{"stateAuto"} == 1);
      
    #-- automatically leave party mode at morning time or when going to bed
    # TODO 
    # TODO Fehler ! Wird nach party um Mitternacht aufgerufen und sichert das Haus, aber in jeder Zeile ein fehler undefined
    if( $currmode eq "party" && $targettime =~ /(morning)|(sleep)/ && $ma ){
      Log3 $name, 1,"[YAAHM_time] Leaving party mode because modeAuto=1";
      $msg  = YAAHM_mode($name,"normal",$exec)."\n";
      if( $currstate eq "unsecured" && $targettime eq "sleep" && $sa ){
        Log3 $name, 1,"[YAAHM_time] Securing the house because stateAuto=1";
        $msg .= YAAHM_state($name,"secured",$exec)."\n"
      };
  
    #-- automatically leave absence mode at wakeup time
    #   Ist das wirklich clever ? Was passiert, wenn der Wecker nicht ausgestellt wurde
    }elsif( $currmode eq "absence" && $targettime =~ /(wakeup)/ && $ma ){ 
      Log3 $name, 1,"[YAAHM_time] Leaving absence mode because modeAuto=1";
      $msg = YAAHM_mode($name,"normal",$exec)."\n";
  
    #-- automatically leave donotdisturb mode at any time event
    }elsif( $currmode eq "donotdisturb" && $ma ){
      Log3 $name, 1,"[YAAHM_time] Leaving donotdisturb mode because modeAuto=1"; 
      $msg = YAAHM_mode($name,"normal",$exec)."\n";
    
    #-- automatically secure the house at night time or when going to bed (if not absence, and if not party)
    }elsif( $currmode eq "normal" && $currstate eq "unsecured" && $targettime =~ /(night)|(sleep)/ && $sa ){
      Log3 $name, 1,"[YAAHM_time] Securing the house because stateAuto=1";
      $msg = YAAHM_state($name,"secured",$exec)."\n";
    }
  
    $hash->{DATA}{"HSM"}{"time"} = $targettime;
  
    YAAHM_checkMonthly($hash,'event',$targettime);
  
    readingsBeginUpdate($hash);
    readingsBulkUpdate($hash,"prev_housetime",$prevtime);
    readingsBulkUpdate($hash,"next_housetime",$nexttime);
    readingsBulkUpdate($hash,"housetime",$targettime);
    readingsBulkUpdate($hash,"tr_housetime",$yaahm_tt->{$targettime});
    readingsBulkUpdate($hash,"housephase",$targetphase);
    readingsBulkUpdate($hash,"tr_housephase",$yaahm_tt->{$targetphase});
    readingsEndUpdate($hash,1); 
  }
  #-- before fixing new times
  #   if manual wake/sleep/timer, the time for the current day needs to be set to empty, 
  #   but second execution on the same day is blocked if attribute norepeat is set.
  readingsBeginUpdate($hash);
  if( $targettime eq "wakeup" ){
    $hash->{DATA}{"WT"}[0]{"next"} = "";
    readingsBulkUpdate($hash,"next_0","");
  }elsif( $targettime eq "sleep" ){ 
    $hash->{DATA}{"WT"}[1]{"next"} = "";
    readingsBulkUpdate($hash,"next_1","");
  }elsif( $targettime =~ /timer_(\d+)/ ){ 
    my $i = $1;
    $hash->{DATA}{"WT"}[$i]{"next"} = "";
    readingsBulkUpdate($hash,"next_".$i,"");
  }
  readingsEndUpdate($hash,1); 
  
  #-- helper function not executed, e.g. by call from external timer
  return
    if( !defined($exec) || $exec==0);
  
  #-- execute the helper function
  my $xval;  
  my $ival;
  my $wupn;
  
  #-- after fixing new time
  #-- TODO here: what should we do, if the timer is NOT enabled and we get up or go to bed anyhow ???
  if( $targettime =~ /((wakeup)|(sleep)|(timer_(\d+)))/ ){
    my $timerno="";
    if( $targettime eq "wakeup" ){
      $timerno=0;
    }elsif( $targettime eq "sleep" ){ 
      $timerno=1;
    }elsif( $targettime =~ /timer_(\d+)/ ){ 
      $timerno = $1;
    }
    $wupn = $hash->{DATA}{"WT"}[$timerno]{"name"};
    $ival = (ReadingsVal($name.".wtimer_".$timerno.".IF","mode","") ne "disabled");
    $xval = $ival ? $hash->{DATA}{"WT"}[$timerno]{"action"} : "";
    my $norep = AttrVal($name,"norepeat",0);
    if( $exec==1 ){
      if( $hash->{DATA}{"WT"}[$timerno]{"done"} && $norep ){
        $msg = "Not executing action for timer $targettime, already done";
        Log3 $name,3,"[YAAHM_time] ".$msg;
        return $msg;
      }else{
        Log3 $name,1,"[YAAHM_time] executing action $xval for timer $targettime";
        fhem($xval);
        $hash->{DATA}{"WT"}[$timerno]{"done"} = 1;
        return;
      }
    }elsif( $exec==0 ){
      $msg .= "Simulation ".$xval." from timer ".$targettime;
      $msg .= " (disabled)"
        if !$ival;
      Log3 $name,1,"[YAAHM_time] ".$msg;
      return $msg;
    }
 
  #-- any other 
  }else{
    $xval  = $dailytable{$targettime}[2];
    $msg   = "Simulation ".$xval;
    if( $exec==1 ){
      Log3 $name,1,"[YAAHM_time] executing $xval";
      fhem($xval);
      return
    }elsif( $exec==0 ){
      Log3 $name,1,"[YAAHM_time] ".$msg;
      return $msg;
    }
  }
}

#########################################################################################
#
# YAAHM_nextWeeklyTime - set the next weekly time
#
# Parameter name = name of device addressed
#
#########################################################################################

sub YAAHM_nextWeeklyTime {
  my ($name,$cmd,$time,$exec) = @_;
   
  my $hash = $defs{$name};
  my $msg;
  
  #--determine which timer (duplicate check when coming from set)
  $cmd  =~ /.*next_([0-9]+)$/;
  my $i = $1;
  
  if( $i >= int( @{$hash->{DATA}{"WT"}}) ){
    $msg = "Error, timer number $i does not exist, number musst be smaller than ".int( @{$hash->{DATA}{"WT"}});
    Log3 $name,1,"[YAAHM_nextWeeklyTime] ".$msg;
    return $msg;
  }
  
  $time = lc($time);
  
  #-- check value - may be empty
  if( $time eq "" || $time eq "default" ){
    $time = "";      
  #-- nontrivial
  }else{
    #-- off=ok, do nothing
    if( $time eq "off"){
    #-- time=ok, check
    }elsif( $time =~ /(\d?\d):(\d\d)(:(\d\d))?/ ){
      if( $1 >= 24 || $2 >= 60){
        $msg = "Error, time specification $time for timer ".$cmd." > 23:59 ";
        Log3 $name,1,"[YAAHM_nextWeeklyTime] ".$msg;
        return $msg;
      }
      $time = sprintf("%02d:\%02d",$1,$2);
    }else{
      $msg = "Error, time specification $time invalid for timer ".$cmd.", must be hh:mm";;
      Log3 $name,1,"[YAAHM_nextWeeklyTime] ".$msg;
      return $msg;
    }
  }
  
  #-- all logic in setweeklytime     
  $hash->{DATA}{"WT"}[$i]{"next"} = $time; 
  $hash->{DATA}{"WT"}[$i]{"done"} = 0;
  YAAHM_setWeeklyTime($hash);                                          
}

#########################################################################################
#
# YAAHM_mode - Change the house mode (normal, party, absence)
#
# Parameter name = name of the YAAHM device
#
#########################################################################################

sub YAAHM_mode {
  my ($name,$targetmode,$exec) = @_;
  my $hash = $defs{$name};
  
  my $prevmode   = defined($hash->{DATA}{"HSM"}{"mode"})  ? $hash->{DATA}{"HSM"}{"mode"}  : "normal";
  my $currstate  = defined($hash->{DATA}{"HSM"}{"state"}) ? $hash->{DATA}{"HSM"}{"state"} : "unsecured";
  my $msg        = "";
  my $tr_msg     = "";
  
  #-- local checks
  #-- double change
  if( $prevmode eq $targetmode ){
    $msg = "transition skipped, we are already in $targetmode mode"; 
    
  #-- transition into party and absence is only possible from normal mode
  }elsif( $prevmode ne "normal" && $targetmode ne "normal"){
    $msg = "Transition into $targetmode mode is only possible from normal mode";
    $tr_msg = $yaahm_tt->{transition}.' "'.$yaahm_tt->{$targetmode}.'" '.$yaahm_tt->{"onlposfrm"}.' '.$yaahm_tt->{"mode"}.'="'.$yaahm_tt->{"normal"}.'"';

  #-- global checks
  #-- transition into party mode only possible in unlocked state
  }elsif( $targetmode eq "party" && $currstate ne "unsecured" ){
    $msg = "Transition into party mode is only possible from unsecured state";
    $tr_msg = $yaahm_tt->{transition}.' "'.$yaahm_tt->{$targetmode}.'" '.$yaahm_tt->{"onlposfrm"}.' '.$yaahm_tt->{"state"}.'="'.$yaahm_tt->{"unsecured"}.'"';
  }
  
  #-- don't
  if( $msg ne "" ){
    Log3 $name,1,"[YAAHM_mode] ".$msg;
    readingsSingleUpdate($hash,"tr_errmsg",$tr_msg,1);
    return $msg;
  }
    
  $hash->{DATA}{"HSM"}{"mode"} = $targetmode;
  
  readingsBeginUpdate($hash);
  readingsBulkUpdate($hash,"tr_errmsg","");
  readingsBulkUpdate($hash,"prev_housemode",$prevmode);
  readingsBulkUpdate($hash,"housemode",$targetmode);
  readingsBulkUpdate($hash,"tr_housemode",$yaahm_tt->{$targetmode});
  readingsEndUpdate($hash,1); 
  
  #-- doit, if not simulation
  if (defined($attr{$name}{"modeHelper"})){
    if( !defined($exec) || $exec==1 ){
      fhem("{".$attr{$name}{"modeHelper"}."('".$targetmode."')}");
    }else{
      $msg = "Simulation {".$attr{$name}{"modeHelper"}."('".$targetmode."')}";
      Log3 $name,1,"[YAAHM_mode]  ".$msg;
      return $msg;
    }
  }
  
}

#########################################################################################
#
# YAAHM_state - Change the house state (unscured, secured, guarded)
#
# Parameter name = name of the YAAHM device
#
#########################################################################################

sub YAAHM_state {
  my ($name,$targetstate,$exec) = @_;
  my $hash = $defs{$name};
  
  my $prevstate = defined($hash->{DATA}{"HSM"}{"state"}) ? $hash->{DATA}{"HSM"}{"state"} : "unsecured";
  my $currmode  = defined($hash->{DATA}{"HSM"}{"mode"})  ? $hash->{DATA}{"HSM"}{"mode"}  : "normal";
  my $msg       = "";
  my $tr_msg    = "";
 
  #-- local checks 
  #-- double change
  #if( $prevstate eq $targetstate ){
  #  $msg = "transition skipped, we are already in $targetstate state";

  #-- global checks
  #-- changing away from unlocked in party mode is not possible
  if( $targetstate ne "unlocked" && $currmode eq "party" ){
    $msg = "Not possible in party mode";
    $tr_msg = $yaahm_tt->{transition}.' "'.$yaahm_tt->{$targetstate}.'" '.$yaahm_tt->{"notposfrm"}.' '.$yaahm_tt->{"mode"}.'="'.$yaahm_tt->{"party"}.'"';
  }
  
  #-- don't
  if( $msg ne "" ){
    Log3 $name,1,"[YAAHM_state] ".$msg;
    readingsSingleUpdate($hash,"tr_errmsg",$tr_msg,1);
    return $msg;
  }
  
  $hash->{DATA}{"HSM"}{"state"} = $targetstate;
  readingsBeginUpdate($hash);
  readingsBulkUpdate($hash,"tr_errmsg","");
  readingsBulkUpdate($hash,"prev_housestate",$prevstate);
  readingsBulkUpdate($hash,"housestate",$targetstate);
  readingsBulkUpdate($hash,"tr_housestate",$yaahm_tt->{$targetstate});
  readingsEndUpdate($hash,1); 
  
  #-- doit, if not simulation
  if (defined($attr{$name}{"stateHelper"})){
    if( !defined($exec) || $exec==1 ){
      fhem("{".$attr{$name}{"stateHelper"}."('".$targetstate."')}");
    }else{
      $msg = "Simulation {".$attr{$name}{"stateHelper"}."('".$targetstate."')}";
      Log3 $name,1,"[YAAHM_state]  ".$msg;
      return $msg;
    }
  }
 
  YAAHM_InternalTimer("check",time()+ 30, "YAAHM_checkstate", $hash, 0);
}

#########################################################################################
#
# YAAHM_checkstate - check state devices
#
# Parameter someHash =  either internal hash of timer 
#                       => need to dereference it for getting device hash
#                       or device hash
#
#########################################################################################

sub YAAHM_checkstate($) {
  my ($someHash) = @_;
  
  my $hash;
  if( defined($someHash->{HASH}) ){
    $hash = $someHash->{HASH};
  }else{
    $hash = $someHash;
  }
  my $name = $hash->{NAME};
  
  my $next;
  
  $next = gettimeofday()+AttrVal($name,"stateInterval",60)*60;
  
  YAAHM_RemoveInternalTimer("check",$hash);
  YAAHM_InternalTimer("check",$next, "YAAHM_checkstate", $hash, 0);
  Log3 $name, 5,"[YAAHM_checkstate] on device ".$hash->{NAME}." called";
  
  my $istate;
  my $cstate = defined($hash->{DATA}{"HSM"}{"state"}) ? $hash->{DATA}{"HSM"}{"state"} : "";
  
  return undef 
  if( !defined($attr{$name}{"stateDevices"}) );
    
  for($istate=0;$istate<int(@states);$istate++){
    last 
      if($states[$istate] eq $cstate);
  }
  
  my (@devlist,@devl);
  my ($dev,$devs,$devh,);
  my @devf = ();
  my $isf  = 0;
   
  @devlist = split(',',$attr{$name}{"stateDevices"});
  foreach my $devc (@devlist) {
    @devl = split(':',$devc);
    $dev  = $devl[0];
    $devs = $devl[$istate+1];
    if( defined($devs) && ($devs ne "") ){
      $devh = Value($dev);
      if( $devs ne $devh ){
        $isf = 1;
        push(@devf,"<tr><td style=\"text-align:left;padding:5px\">".$dev."</td><td style=\"text-align:left;padding:5px\"><div style=\"color:red\">".$yaahm_tt->{'notok'}.
          "</div></td><td style=\"text-align:left;padding:5px\">".$devh."</td></tr>");
        if( defined(AttrVal($name,"stateWarning",undef)) ){
          fhem("{".AttrVal($name,"stateWarning",undef)."($dev,$devs,$devh)}");
        }
      }else{
        push(@devf,"<tr><td style=\"text-align:left;padding:5px\">".$dev."</td><td style=\"text-align:left;padding:5px\"><div style=\"color:green\">".$yaahm_tt->{'ok'}."</div></td><td></td></tr>");
      }
    }
  }
  readingsBeginUpdate($hash);
  readingsBulkUpdate($hash,"sdev_housestate","<html><table>".join("<br/>",@devf)."</table></html>");
  readingsBulkUpdate($hash,"sec_housestate",(($isf==0)?"secure":"insecure"));
  readingsBulkUpdate($hash,"sym_housestate",(($isf==0)?"<html><div style=\"color:green\">&#x2713;</div></html>":"<html><div style=\"color:red\">&#x274c;</div></html>"));
  readingsEndUpdate($hash,1); 
  
  return undef
}

#########################################################################################
#
# YAAHM_correctstate - correct state devices
#
# Parameter someHash =  either internal hash of timer 
#                       => need to dereference it for getting device hash
#                       or device hash
#
#########################################################################################

sub YAAHM_correctstate($) {
  my ($someHash) = @_;
  
  my $hash;
  if( defined($someHash->{HASH}) ){
    $hash = $someHash->{HASH};
  }else{
    $hash = $someHash;
  }
  my $name = $hash->{NAME};
  
  Log3 $name, 1,"[YAAHM_correctstate] on device ".$hash->{NAME}." called";
  
  my $istate;
  my $cstate = defined($hash->{DATA}{"HSM"}{"state"}) ? $hash->{DATA}{"HSM"}{"state"} : "";
  
  return undef 
  if( !defined($attr{$name}{"stateDevices"}) );
    
  for($istate=0;$istate<int(@states);$istate++){
    last 
      if($states[$istate] eq $cstate);
  }
  
  my (@devlist,@devl);
  my ($dev,$devs,$devh,);
  my @devf = ();
  my $isf  = 0;
   
  @devlist = split(',',$attr{$name}{"stateDevices"});
  foreach my $devc (@devlist) {
    @devl = split(':',$devc);
    $dev  = $devl[0];
    $devs = $devl[$istate+1];
    if( defined($devs) && ($devs ne "") ){
      $devh = Value($dev);
      if( $devs ne $devh ){
        Log3 $name, 1,"[YAAHM_correctstate] calling set ".$dev." ".$devs;
        fhem("set ".$dev." ".$devs);
        $isf = 1;
      }
    }
  }
  
  YAAHM_checkstate($hash)
    if($isf == 1);
  return undef
}

#########################################################################################
#
# YAAHM_informer - Tell FHEMWEB to inform this page
#
# Parameter me = hash of FHEMWEB instance
#
#########################################################################################

sub YAAHM_informer($) {
  my ($me) = @_;

  $me->{inform}{type} = "status";
  $me->{inform}{filter} = "YYY";
  #$me->{inform}{since} = time()-5;
  $me->{inform}{fmt} = "JSON";

  my $filter = $me->{inform}{filter};

  my %h = map { $_ => 1 } devspec2array($filter);
  
  $h{global} = 1 if( $me->{inform}{addglobal} );
  $h{"#FHEMWEB:$FW_wname"} = 1;
  $me->{inform}{devices} = \%h;
  %FW_visibleDeviceHash = FW_visibleDevices();
  
  $me->{NTFY_ORDER} = $FW_cname;   # else notifyfn won't be called
  %ntfyHash = ();
}

#########################################################################################
#
# YAAHM_startDeviceActions- start the device action function
#
# Parameter name = name of the YAAHM device
#
#########################################################################################

sub YAAHM_startDeviceActions($) {
  my ($name) = @_;
  return
    if(!defined($name));
    
  my $hash = $defs{$name};
  return
    if(!defined($hash));

  my $res;
  my $avl  = AttrVal($name,"deviceActions",undef);
  return
    if( !$avl );
    
  my ($dea,$dev,$evt);
    
  #-- number of action devices
  my $devactno;  
  my @actdevlist = split(',',$avl);
  $devactno=int(@actdevlist);
  
  #-- check for obsolete keys and remove from hash
  my %devacthash = %{$hash->{DATA}{"XT"}};
  my %actdevattr = map {$_ => 1} @actdevlist;
  foreach my $key (keys %devacthash){
    if($actdevattr{$key} != 1){
      delete($hash->{DATA}{"XT"}{$key});
    }
  }

  #-- start timer
  for( my $i=0;$i < $devactno ;$i++){
    $dea  = $actdevlist[$i];
    $dev  = $hash->{DATA}{"XT"}{$dea}{"name"};
    if( $dea ne $dev){
      Log3 $name,1,"[YAAHM_startDeviceActions] key $dea not equal to name $dev, no action timer started";
      next;
    }
    $evt  = $hash->{DATA}{"XT"}{$dea}{"event"};
    my $early = $hash->{DATA}{"XT"}{$dea}{"earliest"};
    my $late = $hash->{DATA}{"XT"}{$dea}{"latest"};
    my $exec = $hash->{DATA}{"XT"}{$dea}{"cmd"};
    my $cond;
  
    #-- event given is a housetime event (including wakeup/sleep)
    if( $evt =~ /$defaultdailykeys/ ){
      $cond = "[$name:\"housetime: $evt\"]";
    #-- event is a weekly timer event (excluding wakeup/sleep)
    #}else{
    #  $cond = "[$name:\"weeklytimer $evt\"]";
     }else{
      Log3 $name,1,"[YAAHM_startDeviceActions] event $evt not in list of allowed events";
      next;
    }

    #-- neither earliest nor latest
    if( (!defined($early)||($early eq "")) && (!defined($late)||($late eq "")) ){
      $cond = "($cond and ([$name:exec] eq \"0\"))";
    #-- only latest
    }elsif( (!defined($early)||($early eq "")) && defined($late) && $late =~ /\d?\d:\d\d(:\d\d)?/ ){
      $cond = "((($cond and [?00:00-$late]) or [$late]) and ([".$name.".xtimer_".$i.".IF:exec] eq \"0\"))";
    #-- only earliest
    }elsif( defined($early) && (!defined($late)||($late eq "")) && $early =~ /\d?\d:\d\d(:\d\d)?/ ){
      $cond = "($cond and [?00:00-$early]) (setreading ".$name.".xtimer_".$i.".IF event 1) ".
                "DOELSEIF ((([$early] and ([".$name.".xtimer_".$i.".IF:event] eq \"1\")) or ($cond and [?$early-23:59:59])) and ([".$name.".xtimer_".$i.".IF:exec] eq \"0\"))";
    #-- earliest and latest
    }elsif( defined($early) && defined($late) && $early =~ /\d?\d:\d\d(:\d\d)?/ && $late =~ /\d?\d:\d\d(:\d\d)?/){
      $cond = "($cond and [?00:00-$early]) (setreading ".$name.".xtimer_".$i.".IF event 1) ".
                "DOELSEIF ((([$early] and ([".$name.".xtimer_".$i.".IF:event] eq \"1\")) or ($cond and [?$early-$late]) or [$late]) and ([".$name.".xtimer_".$i.".IF:exec] eq \"0\"))";
    }else{
      Log3 $name, 1,"[YAAHM_startDeviceActions] no proper conditions found for action timer $dev with evt $evt"; 
      next;
    } 
    #$hash->{DATA}{"XT"}{$dea}{"time"} = $tfinal;
    $res  = "defmod ".$name.".xtimer_".$i.".IF DOIF $cond (".$exec.") (setreading ".$name.".xtimer_".$i.".IF exec 1)";
  
    fhem($res);
    fhem("attr ".$name.".xtimer_".$i.".IF comment ".$dev);
    fhem("attr ".$name.".xtimer_".$i.".IF userReadings event:none{},exec:none{}");
    fhem("attr ".$name.".xtimer_".$i.".IF do always");
    fhem("attr ".$name.".xtimer_".$i.".IF room ".(defined($attr{$name}{"publicroom"})  ? $attr{$name}{"publicroom"} : $yaahmpublicroom)); 
    fhem("set  ".$name.".xtimer_".$i.".IF enable");
    fhem("setreading ".$name.".xtimer_".$i.".IF event 0");
    fhem("setreading ".$name.".xtimer_".$i.".IF exec 0");   
   
  }
   
  #-- save everything
  YAAHM_save($hash);
  fhem("save");
  
  return "Device actions started";
}
  
#########################################################################################
#
# YAAHM_startDayTimer - start the daily timer function
#
# Parameter name = name of the YAAHM device
#
#########################################################################################

sub YAAHM_startDayTimer($) {
  my ($name) = @_;
  my $hash = $defs{$name};
  
  YAAHM_GetDayStatus($hash);

  my $res  = "defmod $name.dtimer.IF DOIF ";
  my $msg;
  
  #--cleanup after definition fault
  fhem("deletereading $name t_aftermidnight")
    if( ReadingsVal($name,"t_aftermidnight",undef) );
  fhem("deletereading $name t_aftersunrise")
    if( ReadingsVal($name,"t_aftersunrise",undef) );
  fhem("deletereading $name t_aftersunset")
    if( ReadingsVal($name,"t_aftersunset",undef) );
  fhem("deletereading $name t_beforemidnight")
    if( ReadingsVal($name,"t_beforemidnight",undef) );
  fhem("deletereading $name t_beforesunrise")
    if( ReadingsVal($name,"t_beforesunrise",undef) );
  fhem("deletereading $name t_beforesunset")
    if( ReadingsVal($name,"t_beforesunset",undef) );
    
  delete $hash->{DATA}{"DT"}{"daytime"};
  delete $hash->{DATA}{"DT"}{"nighttime"};
    
  #-- TODO check for plausibility
  #--aftermidnight must be >= 00:01
  my $check=$hash->{DATA}{"DT"}{"aftermidnight"}[0];
  $check =~ s/://;
  if( $check <= 0 ){
    Log3 $name,1,"[YAAHM_startDayTimer] aftermidnight is minimum 00:01, used this value";
    $hash->{DATA}{"DT"}{"aftermidnight"}[0] = "00:01";
  }
  
  #-- Internal timer for night time
  my ($sec, $min, $hour, $day, $month, $year, $wday,$yday,$isdst) = localtime(time);
  my $nval = $hash->{DATA}{"DT"}{"night"}[0];
  if( $nval !~ /\d?\d:\d\d/ ){
    $msg = "Error in night time specification";
    Log3 1,$name,"[YAAHM_startDayTimer] ".$msg;
    return $msg;
  }
  my ($hourn,$minn) = split(':',$nval);
  my $deltan = ($hourn-$hour)*3600+($minn-$min)*60-$sec;
  my $delta  = $deltan;
  $delta    += 86400
    if( $delta<0 );
  YAAHM_RemoveInternalTimer    ("nighttime", $hash);
  YAAHM_InternalTimer          ("nighttime", gettimeofday()+$delta, "YAAHM_tonight", $hash, 0);
  
  #-- Internal timer for daytime
  my $mval = $hash->{DATA}{"DT"}{"morning"}[0];
  if( $mval !~ /\d?\d:\d\d/ ){
    $msg = "Error in morning time specification";
    Log3 1,$name,"[YAAHM_startDayTimer] ".$msg;
    return $msg;
  }
  ($hourn,$minn) = split(':',$mval);
  my $deltam  = ($hourn-$hour)*3600+($minn-$min)*60-$sec;
  $delta      = $deltam;
  $delta     += 86400
    if( $delta<0 );
  YAAHM_RemoveInternalTimer    ("daytime", $hash);
  YAAHM_InternalTimer          ("daytime", gettimeofday()+$delta, "YAAHM_today", $hash, 0);
  
  #-- currently day or night ?
  my $currtime = (($deltam < 0) && ($deltan > 0)) ? "daytime" : "nighttime";
  
  #-- put data into readings
  readingsBeginUpdate($hash);
  readingsBulkUpdate($hash,"housephase",$currtime);
  readingsBulkUpdate($hash,"tr_housephase",$yaahm_tt->{$currtime});
  
  #-- compose external timer
  foreach my $key (sort YAAHM_dsort keys %defaultdailytable){
    next if( !defined($hash->{DATA}{"DT"}{$key}[2]) );
    my $f1 = defined($defaultdailytable{$key}[0]);
    my $f2 = defined($defaultdailytable{$key}[1]);
    my $f3 = defined($hash->{DATA}{"DT"}{$key}[2]) && $hash->{DATA}{"DT"}{$key}[2] ne "";

    #-- to prevent double execution of functions do this in YAAHM_time, NOT in timer
    my $xval = "{YAAHM_time('".$name."','".$key."',1)}";
    
    #-- entries in the default table with no entry are single-timers
    if( !$f1 and !$f2 ){
      $res .= "([[".$name.":s_".$key."]])\n(".$xval.")\nDOELSEIF"
        if( $f3 );
        
    #-- entries in the default table with only first time are single-timers
    }elsif( $f1 and !$f2 ){
      $res .= "([[".$name.":s_".$key."]])\n(".$xval.")\nDOELSEIF"
        if( $f3 );
        
    #-- entries in the default table with only second time are single-timer offsets
    }elsif( !$f1 and $f2 ){
      $res .= "([[".$name.":s_".$key."]])\n(".$xval.")\nDOELSEIF"
        if( $f3 );
        
    #-- entries in the default table with first and second time are two-timer periods
    }elsif( $f1 and $f2 ){
      $res .= "([[".$name.":s_".$key."]-[".$name.":t_".$key."]])\n(".$xval.")\nDOELSEIF"
        if( $f3 );
        
    #-- something wrong
    }else{
      $msg = "Daily timer $name.dtimer.IF NOT started, something wrong with entry ".$key;
      Log 1,"[YAAHM_startDayTimer] ".$msg;
      return $msg;
    }
  }
  readingsEndUpdate($hash,1);
  
  #-- take out last DOELSEIF
  $res =~ s/\nDOELSEIF$//;
  fhem($res);
  fhem("attr $name.dtimer.IF do always");
  fhem("attr $name.dtimer.IF room ".(defined($attr{$name}{"publicroom"})  ? $attr{$name}{"publicroom"} : $yaahmpublicroom)); 
  fhem("set $name.dtimer.IF enable");
  
  #-- save everything
  YAAHM_save($hash);
  fhem("save");
  
  return "Daily timer $name.dtimer.IF started";
}

#########################################################################################
#
# YAAHM_startWeeklyTimer - start the Weekly timer function
#
# Parameter name = name of the YAAHM device
#
#########################################################################################

sub YAAHM_startWeeklyTimer($) {
  my ($name) = @_;
  my $hash = $defs{$name};

  my $res;
  my $wupn;
  
  YAAHM_setWeeklyTime($hash);
  
  #-- start timer
  for( my $i=0;$i < int( @{$hash->{DATA}{"WT"}} );$i++){
    $wupn = $hash->{DATA}{"WT"}[$i]{"name"};
    $res = "defmod ".$name.".wtimer_".$i.".IF DOIF ([".$name.":ring_".$i."] eq \"off\")\n()\nDOELSEIF\n(([[".$name.":ring_".$i."]])";

    #-- check for mode activation
    my $g4a = defined($hash->{DATA}{"WT"}[$i]{"acti_m"}) ? $hash->{DATA}{"WT"}[$i]{"acti_m"} : "";
    my $v4a = ($g4a ne "") ? "(normal)|(".join(')|(',split(',',$g4a)).")" : "(normal)";
    
    #-- check for daytype activation
    my $g4b = defined($hash->{DATA}{"WT"}[$i]{"acti_d"}) ? $hash->{DATA}{"WT"}[$i]{"acti_d"} : "";
    my $v4b = ($g4b ne "") ? "(workday)|(weekend)|(".join(')|(',split(',',$g4b)).")" : "(workday)|(weekend)";
    
    $res .= "\nand ((([" .$name. ":housemode] =~ \"".$v4a."\")";
    $res .= "\nand ([" .$name. ":todayType] =~ \"".$v4b."\")) ";
    $res .= "\nor ([".$name.":ring_".$i."x] =~ \".*\(man\)\")) ";
    
    #-- to prevent double execution of functions do this in YAAHM_time, NOT in timer
    my $xval;
    if( $i==0 ){
      $xval  = "{YAAHM_time('".$name."','wakeup',1)}";
    }elsif( $i==1 ){
      $xval  = "{YAAHM_time('".$name."','sleep',1)}";
    }else{
      $xval  = "{YAAHM_time('".$name."','timer_".$i."',1)}";
    }
    #-- action
    $res .= ")\n(".$xval.")";
    
    #-- doit
    fhem($res);
    fhem("attr ".$name.".wtimer_".$i.".IF comment $g4b");
    fhem("attr ".$name.".wtimer_".$i.".IF do always");
    fhem("attr ".$name.".wtimer_".$i.".IF room ".(defined($attr{$name}{"publicroom"})  ? $attr{$name}{"publicroom"} : $yaahmpublicroom)); 
    fhem("set  ".$name.".wtimer_".$i.".IF enable");
  }
  
  #-- save everything
  YAAHM_save($hash);
  fhem("save");
  
  return "Weekly timers started";
}

#########################################################################################
#
# YAAHM_setWeeklyTime - set the Weekly times into readings
#
# Parameter hash = hash of device addressed
#
#########################################################################################

sub YAAHM_setWeeklyTime($) {
  my ($hash) = @_;
  my $name = $hash->{NAME};
  
  #-- weekly profile times
  my ($daytype_0,$daytype_1,$weektime_0,$weektime_1,$ring_0x,$ring_1x,$ring_0e,$ring_1e,$ring_0,$ring_1,$nexttime,$wupad,$wupam);
  
  #-- iterate over timers
  for( my $i=0;$i<int( @{$hash->{DATA}{"WT"}} );$i++){
    #-- obtain next time spec => will override all
    $nexttime  = $hash->{DATA}{"WT"}[$i]{ "next" };
    #-- highest priority is a disabled timer - no wakeup at all
    if( ReadingsVal($name.".wtimer_".$i.".IF","mode","") eq "disabled" ){
      $ring_0  = "off";
      $ring_0x = "off";
      $ring_0e = "disabled (timer)";
      $ring_1  = "off";
      $ring_1x = "off";
      $ring_1e = "disabled (timer)";
    #-- if the timer is enabled, we'll use its timing values
    }else{
      #-- timer active for the following daytypes
      $wupad = $hash->{DATA}{"WT"}[$i]{"acti_d"}.",workday,weekend"; 
      
      #-- start with tomorrow
      #-- because today we might also have an influence of housemode
      $daytype_1 = $hash->{DATA}{"DD"}[1]{"daytype"};
      $ring_1    = $hash->{DATA}{"WT"}[$i]{ $weeklytable[$hash->{DATA}{"DD"}[1]{"weekday"}] } ; 
      $ring_1x   = $ring_1;
      $ring_1e   = "enabled";    
      
      #-- holiday/vacation have higher priority, check for corresponding time
      if( $daytype_1 eq "holiday" ){
        #-- holiday special time
        $weektime_1 = $hash->{DATA}{"WT"}[$i]{ "holiday" } ;
        if( defined($weektime_1) && ($weektime_1 =~ /\d?\d:\d\d(:\d\d)?/) ){
          $ring_1  = $weektime_1;
          $ring_1x = $weektime_1;
        }elsif( index($wupad, "holiday") != -1 ){
          #-- no change
        }else{
          $ring_1  = "off (".$yaahm_tt->{"holiday"}[1].")"; 
          $ring_1x = "off (".$yaahm_tt->{"holiday"}[1].")";
          $ring_1e = "disabled (holiday)";
        }    
      }elsif( $daytype_1 eq "vacation" ){
        #-- vacation special time
        $weektime_1 = $hash->{DATA}{"WT"}[$i]{ "vacation" } ;
        if( defined($weektime_1) && ($weektime_1 =~ /\d?\d:\d\d(:\d\d)?/) ){
          $ring_1  = $weektime_1;
          $ring_1x = $weektime_1;
        }elsif( index($wupad, "vacation") != -1 ){
          #--no change
        }else{
          $ring_1  = "off (".$yaahm_tt->{"vacation"}[1].")"; 
          $ring_1x = "off (".$yaahm_tt->{"vacation"}[1].")";
          $ring_1e = "disabled (vacation)";
        }    
      }
      
      #-- now today
      #-- because today we might also have an influence of housemode
      $daytype_0 = $hash->{DATA}{"DD"}[0]{"daytype"};
      $ring_0    = $hash->{DATA}{"WT"}[$i]{ $weeklytable[$hash->{DATA}{"DD"}[0]{"weekday"}] } ;  
      $ring_0x   = $ring_0; 
      $ring_0e   = "enabled";
     
      #-- holiday/vacation have higher priority, check for corresponding time
      if( $daytype_0 eq "holiday" ){
        #-- holiday special time
        $weektime_0 = $hash->{DATA}{"WT"}[$i]{ "holiday" } ;
        if( defined($weektime_0) && ($weektime_0 =~ /\d?\d:\d\d(:\d\d)?/) ){
          $ring_0  = $weektime_0;
          $ring_0x = $weektime_0;
        }elsif( index($wupad, "holiday") != -1 ){
          #-- no change
        }else{
          $ring_0  = "off (".$yaahm_tt->{"holiday"}[1].")"; 
          $ring_0x = "off (".$yaahm_tt->{"holiday"}[1].")";
          $ring_0e = "disabled (holiday)";
        }    
      }elsif( $daytype_0 eq "vacation" ){
        #-- vacation special time
        $weektime_0 = $hash->{DATA}{"WT"}[$i]{ "vacation" } ;
        if( defined($weektime_0) && ($weektime_0 =~ /\d?\d:\d\d(:\d\d)?/) ){
          $ring_0  = $weektime_0;
          $ring_0x = $weektime_0;
        }elsif( index($wupad, "vacation") != -1 ){
          #--no change
        }else{
          $ring_0  = "off (".$yaahm_tt->{"vacation"}[1].")"; 
          $ring_0x = "off (".$yaahm_tt->{"vacation"}[1].")";
          $ring_0e = "disabled (vacation)";
        }    
      }
      #-- next higher priority for "off" (only today !) is housemode 
      my $wupam = $hash->{DATA}{"WT"}[$i]{"acti_m"}.",normal";
      if( index($wupam, ReadingsVal($name,"housemode","")) == -1 ){
        $ring_0x = "off (".substr(ReadingsVal($name,"tr_housemode",""),0,3).")";
        $ring_0e  = "disabled (".ReadingsVal($name,"housemode","").")";
      }else{
        $ring_0x = $ring_0;
      }
    }    
 
    #-- highest priority is a "next" time specification
    if( defined($nexttime) && ($nexttime =~ /(\d?\d:\d\d(:\d\d)?)|(off)/) ){
      #-- current time
      my ($sec, $min, $hour, $day, $month, $year, $wday,$yday,$isdst) = localtime(time);
      my $lga = sprintf("%02d%02d",$hour,$min);
      #-- today's waketime
      my $tga = $ring_0;
      $tga    =~ s/://;
      #-- tomorrow's waketime
      my $tgm = $ring_1;
      $tgm    =~ s/://;
      #-- "next" input
      my $nga = (defined $nexttime)?$nexttime:"";
      $nga    =~ s/://;
      #-- "next" is the same as todays waketime and todays waketime not over => restore !
      if( ($nga eq $tga) && ($tga > $lga)){
        $nexttime = "";
        $hash->{DATA}{"WT"}[$i]{ "next" }="";
      #-- "next" is the same as tomorrows waketime and todays waketime over => restore !
      }elsif( ($nga eq $tgm) && ($tga < $lga)){
        $nexttime  = "";
        $hash->{DATA}{"WT"}[$i]{ "next" }="";
      #-- "next" is off
      }elsif( $nga eq "off" ){
        #-- today's waketime not over => we mean today
        if( $tga ne "off" && ($tga > $lga)){
          if( $ring_0x !~ /^off/ ){
            $ring_0x = "off (man)";
            $ring_0 = "off";
          }
        #-- today's waketime over => we mean tomorrow
        }else{
          if( $ring_1x !~ /^off/ ){
            $ring_1x  = "off (man)";
            $ring_1 .= " (off)";
          }
        }
      #-- "next" is nontrivial timespec
      }else{
        #-- "next" after current time => we mean today
        if( $nga > $lga ){
          $ring_0x = "$nexttime (man)";
          $ring_0  = $nexttime;
        #-- "next" before current time => we mean tomorrow
        }else{
          $ring_1x = "$nexttime (man)";
          $ring_1 .= " ($nexttime)";
        }
      }
    }
    
    $hash->{DATA}{"WT"}[$i]{"ring_0"}  = $ring_0; 
    $hash->{DATA}{"WT"}[$i]{"ring_1"}  = $ring_1; 
    $hash->{DATA}{"WT"}[$i]{"ring_0x"} = $ring_0x; 
    $hash->{DATA}{"WT"}[$i]{"ring_1x"} = $ring_1x;  
    $hash->{DATA}{"WT"}[$i]{"ring_0e"} = $ring_0e;  
    $hash->{DATA}{"WT"}[$i]{"ring_1e"} = $ring_1e;  
  
    readingsBeginUpdate($hash);
    readingsBulkUpdate( $hash, "today_".$i,$ring_0 );  
    readingsBulkUpdate( $hash, "tomorrow_".$i,$ring_1 );
    readingsBulkUpdate( $hash, "today_".$i."_e",$ring_0e );  
    readingsBulkUpdate( $hash, "tomorrow_".$i."_e",$ring_1e );
    readingsBulkUpdate( $hash, "ring_".$i,$ring_0 );    
    readingsBulkUpdate( $hash, "ring_".$i."_1",$ring_1 ); 
    readingsBulkUpdate( $hash, "ring_".$i."x",$ring_0x );    
    readingsBulkUpdate( $hash, "ring_".$i."_1x",$ring_1x ); 
    readingsBulkUpdate( $hash, "next_".$i,$nexttime );     
    readingsEndUpdate($hash,1);  
    
    YAAHM_sayWeeklyTime($hash,$i,0);                                   
  }
   YAAHM_startDeviceActions($name);
}

#########################################################################################
#
# YAAHM_sayWeeklyTime - say the next weekly time
#
# Parameter hash = hash of YAAHM dvice
#           timer = number of timer 
#           sp = 1 => output for speech device
#
#########################################################################################

sub YAAHM_sayWeeklyTime($$$) {
  my ($hash,$timer,$sp) = @_;
  my $name = $hash->{NAME};
  
  my ($tod,$tom,$ton,$hl,$ml,$tl,$ht,$mt,$tt,$tsay,$chg,$msg,$hw,$mw,$pt,$rea,$done,$norep);
  
  #--determine which timer (duplicate check when coming from set)
  
  if( $timer >= int( @{$hash->{DATA}{"WT"}}) ){
    $msg = "Error, timer number $timer does not exist, number musst be smaller than ".int( @{$hash->{DATA}{"WT"}});
    Log3 $name,1,"[YAAHM_sayWeeklyTime] ".$msg;
    return $msg;
  }
  
  #-- init message
  $msg  = $hash->{DATA}{"WT"}[$timer]{"name"};

  #-- get timer values from readings, because these include vacation settings and special time
  $tod   = $hash->{DATA}{"WT"}[$timer]{"ring_0x"};
  $tom   = $hash->{DATA}{"WT"}[$timer]{"ring_1x"};
  $done  = $hash->{DATA}{"WT"}[$timer]{"done"};
  $norep = AttrVal($name,"norepeat",0);

  #-- current local time
  ($hl,$ml) = split(':',strftime('%H:%M', localtime(time)));
  $tl       = 60*$hl+$ml;
  
  #-- today off AND tomorrow any time or off => compare this time with current time
  if( $tod =~ /^off.*/ ){
  
    #-- tomorrow any time
    if( $tom =~ /(\d?\d):(\d\d)(:(\d\d))?/ && $tom !~ /.*\(off\)$/ ){
      ($ht,$mt) = split('[\s:]',$tom);
      $tt=60*$ht+$mt;
      
      #-- wakeup tomorrow later than now
      if( $tt < $tl ){
        $hw = $1*1;
        $mw = $2*1;
        $pt = sprintf("%d:%02d",$hw,$mw)." ".lc($yaahm_tt->{"tomorrow"});
        $msg .= " ".lc($yaahm_tt->{"tomorrow"})." $hw ".$yaahm_tt->{"clock"};
        $msg .=" $mw"
         if( $mw != 0 );
      }else{
        $pt   = "off ".lc($yaahm_tt->{"today"});
        $msg .= " ".lc($yaahm_tt->{"today"})." ".$yaahm_tt->{"swoff"}; 
      }
    }elsif( $tom =~ /^off/ || $tom =~ /.*\(off\)$/ ){
      $pt   = "off ".lc($yaahm_tt->{"today"})." ".$yaahm_tt->{"and"}." ".lc($yaahm_tt->{"tomorrow"});
      $msg .= " ".lc($yaahm_tt->{"today"})." ".$yaahm_tt->{"and"}." ".lc($yaahm_tt->{"tomorrow"})." ".$yaahm_tt->{"swoff"};
    }else{
      $pt  = $yaahm_tt->{"undecid"}; 
      $msg .= " ".$yaahm_tt->{"undecid"};
    }
    
  #-- today nontrivial => compare this time with current time
  }elsif( $tod =~ /(\d?\d):(\d\d)(:(\d\d))?/ ){
    ($ht,$mt) = split('[\s:]',$tod);
    $tt=60*$ht+$mt;
    
    #-- wakeup later today, and ( not yet done - or done, but repeat possible)
    if( ($tt >= $tl) && (($done == 0) | (($done == 1)&&($norep == 0))) ){
      $hw = $1*1;
      $mw = $2*1;
      $pt = sprintf("%d:%02d",$hw,$mw)." ".lc($yaahm_tt->{"today"});
      $msg .= " ".lc($yaahm_tt->{"today"})." $hw ".$yaahm_tt->{"clock"};
      $msg .=" $mw"
        if( $mw != 0 );
    #-- todays time already past => tomorrow - but this may be off
    }elsif( ($tom eq "off") || ($tom =~ /.*\(off\)/) ){
      $pt   = "off ".lc($yaahm_tt->{"tomorrow"});
      $msg .= " ".lc($yaahm_tt->{"tomorrow"})." ".$yaahm_tt->{"swoff"};
    }elsif( $tom =~ /(\d?\d):(\d\d)(:(\d\d))?( \((\d?\d):(\d\d)(:(\d\d))?\))?/ ){
      if( defined($5) && $5 ne ""){
        $hw = $6*1;
        $mw = $7*1;
      }else{
        $hw = $1*1;
        $mw = $2*1;
      }   
      $pt = sprintf("%d:%02d",$hw,$mw)." ".lc($yaahm_tt->{"tomorrow"});
      $msg .= " ".lc($yaahm_tt->{"tomorrow"})." $hw ".$yaahm_tt->{"clock"};
      $msg .=" $mw"
        if( $mw != 0 );
    }elsif( $tom =~ /^off/ || $tom =~ /.*\(off\)$/ ){
      $pt   = "off ".lc($yaahm_tt->{"tomorrow"});
      $msg .= " ".lc($yaahm_tt->{"tomorrow"})." ".$yaahm_tt->{"swoff"};
    }else{
      $pt   = $yaahm_tt->{"undecid"};
      $msg .= " ".$yaahm_tt->{"undecid"};
    }
  }else{
    $pt   = $yaahm_tt->{"undecid"};
    $msg .= " ".$yaahm_tt->{"undecid"};
  }
  $hash->{DATA}{"WT"}[$timer]{"wake"} = $pt;
  readingsSingleUpdate($hash,"tr_wake_".$timer,$pt,1);
  if( $sp==0 ){
    return $pt
  }else{
    return $msg;
  }
}

#########################################################################################
#
# YAAHM_checkMonthly - check Monthly calendar at each 
#
# Parameter hash = hash of device addressed
#
#########################################################################################

sub YAAHM_checkMonthly($$$) {
  my ($hash,$event,$param) = @_;
   
  my $name = $hash->{NAME};
  
  my ($ret,$line,$fline,$date);
  my (@lines,@chunks,@tday,@eday,@sday,@tmor,@two);
  my ($stoday,$stom,$stwom,$tod);
  my $todaylong = "";
  my $tomlong   = "";
  my $twodaylong= "";
    
  #-- Vorschau täglich oder wenn neu gestartet 
  if( ($event eq "test") || (($event eq 'event') && ($param eq 'aftermidnight')) ){
    
    my $specialDevs = AttrVal( $name, "specialDevices", "" );
    foreach my $specialDev ( split( /,/, $specialDevs ) ) {
      my ($todaydesc,$tomdesc,$twomdesc);
      #-- device of type holiday 
      if( IsDevice( $specialDev, "holiday" )){      
        $stoday = strftime('%m-%d', localtime(time));
        $stom   = strftime('%m-%d', localtime(time+86400));
        $stwom  = strftime('%m-%d', localtime(time+2*86400));
        $tod = holiday_refresh( $specialDev, $stoday );
        if ( $tod ne "none" ) {
          $todaydesc .= $tod.",";
          Log3 $name, 5,"[YAAHM] found today=special date \"$tod\" in holiday $specialDev";
        }
        $tod = holiday_refresh( $specialDev, $stom );
        if ( $tod ne "none" ) {
          $tomdesc .= $tod.",";
          Log3 $name, 5,"[YAAHM] found tomorrow=special date \"$tod\" in holiday $specialDev";
        } 
        $tod = holiday_refresh( $specialDev, $stwom );
        if ( $tod ne "none" ) {
          $twomdesc .= $tod.",";
          Log3 $name, 5,"[YAAHM] found twodays=special date \"$tod\" in holiday $specialDev";
        } 
      #-- device of type calendar
      }elsif( IsDevice($specialDev, "Calendar" )){
        $stoday  = strftime('%d.%m.%Y', localtime(time));
        $stom    = strftime('%d.%m.%Y', localtime(time+86400));
        $stwom   = strftime('%d.%m.%Y', localtime(time+2*86400));
        @tday  = split('\.',$stoday);
        @tmor  = split('\.',$stom);
        @two   = split('\.',$stwom);
        
        $fline=Calendar_Get($defs{$specialDev},,"get","events","format:full filter:mode=~'alarm|start|upcoming'");
        #-- more complicated to check here,
        #   format is '<id> upcoming [<datetoannounce> <timetoannouce>] <datestart> <timestart>-<dateend> <timeend> [<description>]
        
              #-- more complicated to check here,
      #   format is '<id>          start/upcoming  <datestart>  <timestart>-<dateend> <timeend> [<description>]
      #              d30479...5e6  start/upcoming  03.10.2018   00:00-                          Tag der Deutschen Einheit 
        my ($cstart,$cdesc);
                
        if($fline){
          #chomp($fline);
          @lines = split('\n',$fline);
          foreach $fline (@lines){
            chomp($fline);
            @chunks = split(' ',$fline);
            if( int(@chunks)>=7 ){
              $cstart = 4;
              $cdesc  = 7;
            }else{
              $cstart = 2;
              $cdesc  = 5,
            }
            @sday   = split('\.',$chunks[$cstart]);
            $tod = ($chunks[$cdesc]) ? $chunks[$cdesc] : "???";
            #-- today
            my $rets  = ($sday[2]-$tday[2])*365+($sday[1]-$tday[1])*31+($sday[0]-$tday[0]);
            if( $rets==0 ){
              $todaydesc .= $tod.",";
              Log3 $name, 5,"[YAAHM] found today=special date \"$tod\" in calendar $specialDev";
            }    
            $rets  = ($sday[2]-$tmor[2])*365+($sday[1]-$tmor[1])*31+($sday[0]-$tmor[0]);
            if( $rets==0 ){
              $tomdesc .= $tod.",";
              Log3 $name, 5,"[YAAHM] found tomorrow=special date \"$tod\" in calendar $specialDev";
            }
            $rets  = ($sday[2]-$two[2])*365+($sday[1]-$two[1])*31+($sday[0]-$two[0]);
            if( $rets==0 ){
              $twomdesc .= $tod.",";
              Log3 $name, 5,"[YAAHM] found twodays=special date \"$tod\" in calendar $specialDev";
            }
          }
        }  
      }else{
        Log3 $name, 1,"[YAAHM] unknown special device $specialDev";
        
      }
      #-- accumulate descriptions
      $todaylong .= $todaydesc
        if($todaydesc);   
      $tomlong .= $tomdesc
        if($tomdesc);  
      $twodaylong .= $twomdesc
        if($twomdesc);
    }
    $todaylong  =~ s/,$//;
    $tomlong    =~ s/,$//;
    $twodaylong =~ s/,$//;
    $hash->{DATA}{"DD"}[0]{"special"} = $todaylong;                        
    $hash->{DATA}{"DD"}[1]{"special"} = $tomlong;                                                 
    #-- put into readings
    readingsBeginUpdate($hash);
    readingsBulkUpdateIfChanged( $hash, "todaySpecial",$todaylong );
    readingsBulkUpdateIfChanged( $hash, "tomorrowSpecial",$tomlong);
    readingsBulkUpdateIfChanged( $hash, "twodaysSpecial",$twodaylong);
    readingsEndUpdate($hash,1);
  }
}  

#########################################################################################
#
# YAAHM_today - internal function to switch into daytime
#
# Parameter timerHash = internal hash of timer 
#                       => need to dereference it for getting device hash
#
#########################################################################################

sub YAAHM_today($) {
  my ($timerHash) = @_;
  my $next;
    
  my $hash = $timerHash->{HASH};
  my $name = $hash->{NAME};
  
  $next = gettimeofday()+86400;
  
  YAAHM_RemoveInternalTimer("today",$hash);
  YAAHM_InternalTimer("today",$next, "YAAHM_today", $hash, 0);
  Log 1,"[YAAHM_today] on device ".$hash->{NAME}." called for this day";
  
  readingsBeginUpdate($hash);
  readingsBulkUpdate($hash,"housephase","daytime");
  readingsBulkUpdate($hash,"tr_housephase",$yaahm_tt->{"daytime"});
  readingsEndUpdate($hash,1);
  
  return undef; 
}

#########################################################################################
#d
# YAAHM_tonight - internal function to switch into nighttime
#
# Parameter timerHash = internal hash of timer 
#                       => need to dereference it for getting device hash
#
#########################################################################################

sub YAAHM_tonight($) {
  my ($timerHash) = @_;
  my $next;
    
  my $hash = $timerHash->{HASH};
  my $name = $hash->{NAME};
  
  $next = gettimeofday()+86400;
  
  YAAHM_RemoveInternalTimer("tonight",$hash);
  YAAHM_InternalTimer("tonight",$next, "YAAHM_tonight", $hash, 0);
  Log 1,"[YAAHM_tonight] on device ".$hash->{NAME}." called for this day";
    
  readingsBeginUpdate($hash);
  readingsBulkUpdate($hash,"housephase","nighttime");
  readingsBulkUpdate($hash,"tr_housephase",$yaahm_tt->{"nighttime"});
  readingsEndUpdate($hash,1);
  
  return undef; 
}

#########################################################################################
#
# YAAHM_updater - internal update function 1 minute after midnight
#
# Parameter timerHash = on first call, device hash.
#                     = on later calls: internal hash of timer 
#                       => need to dereference it for getting device hash
#
#########################################################################################

sub YAAHM_updater($) {
  my ($timerHash) = @_;
  my $hash; 
  my $next;
  my $name = $hash->{NAME};

  #-- start timer for updates - when device is reloaded
  if( defined($firstcall) && ($firstcall==1) ){
    #-- timerHash is device hash
    $hash = $timerHash;
    my ($sec, $min, $hour, $day, $month, $year, $wday,$yday,$isdst) = localtime(time);
    $next = gettimeofday()+(23-$hour)*3600+(59-$min)*60+(59-$sec)+34;
    $firstcall=0;
    
  #-- continue timer for updates
  }else{
    #-- timerHash is internal hash
    $hash = $timerHash->{HASH};
    $next = gettimeofday()+86400;
  }
  
  #-- safeguard if hash is not properly indirected
  if( defined($hash->{HASH}) ){
    $hash = $hash->{HASH};
  }
  YAAHM_RemoveInternalTimer("aftermidnight",$hash);
  YAAHM_InternalTimer("aftermidnight",$next, "YAAHM_updater", $hash, 0);
  Log 1,"[YAAHM_updater] on device ".$hash->{NAME}." called for this day";
  
  YAAHM_GetDayStatus($hash);
  YAAHM_startDeviceActions($name);
  return undef; 
}

#########################################################################################
#
# YAAHM_InternalTimer - start named internal timer
#
# Parameter  modifier = name suffix
#            tim      = time
#            callback = callback function 
#            
#
#########################################################################################

sub YAAHM_InternalTimer($$$$$) {
   my ($modifier, $tim, $callback, $hash, $waitIfInitNotDone) = @_;

   my $mHash;
   if ($modifier eq "") {
      $mHash = $hash;
   } else {
      my $timerName = "$hash->{NAME}_$modifier";
      if (exists  ($hash->{TIMER}{$timerName})) {
          $mHash = $hash->{TIMER}{$timerName};
      } else {
          $mHash = { HASH=>$hash, NAME=>"$hash->{NAME}_$modifier", MODIFIER=>$modifier};
          $hash->{TIMER}{$timerName} = $mHash;
      }
   }
   InternalTimer($tim, $callback, $mHash, $waitIfInitNotDone);
}

#########################################################################################
#
# YAAHM_RemoveInternalTimer - kill named internal timer
#
# Parameter 
#
#########################################################################################

sub YAAHM_RemoveInternalTimer($$) {
   my ($modifier, $hash) = @_;

   my $timerName = "$hash->{NAME}_$modifier";
   if ($modifier eq "") {
      RemoveInternalTimer($hash);
   } else {
      my $myHash = $hash->{TIMER}{$timerName};
      if (defined($myHash)) {
         delete $hash->{TIMER}{$timerName};
         RemoveInternalTimer($myHash);
      }
   }
}

#########################################################################################
#
# YAAHM_GetDayStatus
# 
# Parameter hash = hash of device addressed
#
#########################################################################################

sub YAAHM_GetDayStatus($) {
  my ($hash) = @_;

  my $name = $hash->{NAME};
  
  #-- readjust language
  my $lang = AttrVal("global","language","EN");
  if( $lang eq "DE"){
    $yaahm_tt = \%yaahm_transtable_DE;
  }else{
    $yaahm_tt = \%yaahm_transtable_EN;
  }
  
  #-- iterate over timers to reset the "done" flag
  for( my $i=0;$i<int( @{$hash->{DATA}{"WT"}} );$i++){
   $hash->{DATA}{"WT"}[$i]{"done"} = 0;
  }
  
  my ($ret,$line,$fline,$date);
  my (@lines,@chunks,@tday,@eday,@sday,@tmor,@ttwo);
  my ($todaydesc,$todaytype,$tomdesc,$tomtype,$twodesc,$twotype);

  my $stoday  = strftime('%d.%m.%Y', localtime(time));
  my $stom    = strftime('%d.%m.%Y', localtime(time+86400));
  my $stwo    = strftime('%d.%m.%Y', localtime(time+2*86400));
  
  #-- workday has lowest priority
  $todaytype = "workday";
  $hash->{DATA}{"DD"}[0]{"date"}      = $stoday;
  $hash->{DATA}{"DD"}[0]{"weekday"}   = (strftime('%w', localtime(time))+6)%7;
  $hash->{DATA}{"DD"}[0]{"daytype"}   = "workday";
  $hash->{DATA}{"DD"}[0]{"desc"}      = $yaahm_tt->{"workday"}[0];
  $hash->{DATA}{"DD"}[0]{"vacflag"}   = 0; 
  
  $tomtype = "workday";
  $hash->{DATA}{"DD"}[1]{"date"}      = $stom;
  $hash->{DATA}{"DD"}[1]{"weekday"}   = (strftime('%w', localtime(time+86400))+6)%7;
  $hash->{DATA}{"DD"}[1]{"daytype"}   = "workday";
  $hash->{DATA}{"DD"}[1]{"desc"}      = $yaahm_tt->{"workday"}[0];
  $hash->{DATA}{"DD"}[1]{"vacflag"}   = 0;
  
  $twotype = "workday";
  $hash->{DATA}{"DD"}[2]{"date"}      = $stwo;
  $hash->{DATA}{"DD"}[2]{"weekday"}   = (strftime('%w', localtime(time+2*86400))+6)%7;
  $hash->{DATA}{"DD"}[2]{"daytype"}   = "workday";
  $hash->{DATA}{"DD"}[2]{"desc"}      = $yaahm_tt->{"workday"}[0];
  $hash->{DATA}{"DD"}[2]{"vacflag"}   = 0;

  #-- vacation has higher priority
  my $vacdayDevs = AttrVal( $name, "vacationDevices", "" );
  foreach my $vacdayDev ( split( /,/, $vacdayDevs ) ) {
    #-- device of type holiday 
    if( IsDevice( $vacdayDev, "holiday" )){      
      $stoday = strftime('%m-%d', localtime(time));
      $stom   = strftime('%m-%d', localtime(time+86400));
      $stwo   = strftime('%m-%d', localtime(time+2*86400));
      my $tod = holiday_refresh( $vacdayDev, $stoday );
      if ( $tod ne "none" ) {
        $todaydesc = $tod;
        $todaytype = "vacation";
        Log3 $name, 5,"[YAAHM] found today=vacation \"$todaydesc\" in holiday $vacdayDev";
      }
      $tod = holiday_refresh( $vacdayDev, $stom );
      if ( $tod ne "none" ) {
        $tomdesc = $tod;
        $tomtype = "vacation";
        Log3 $name, 5,"[YAAHM] found tomorrow=vacation \"$tomdesc\" in holiday $vacdayDev";
      } 
      $tod = holiday_refresh( $vacdayDev, $stwo );
      if ( $tod ne "none" ) {
        $twodesc = $tod;
        $twotype = "vacation";
        Log3 $name, 5,"[YAAHM] found twodays=vacation \"$twodesc\" in holiday $vacdayDev";
      } 
    #-- device of type calendar
    }elsif( IsDevice($vacdayDev, "Calendar" )){
      $stoday  = strftime('%d.%m.%Y', localtime(time));
      $stom    = strftime('%d.%m.%Y', localtime(time+86400));
      $stwo    = strftime('%d.%m.%Y', localtime(time+2*86400));
      @tday  = split('\.',$stoday);
      @tmor  = split('\.',$stom);
      @ttwo  = split('\.',$stwo);
      #-- more complicated to check here
      $fline=Calendar_Get($defs{$vacdayDev},"get","events","format:full filter:mode=~'alarm|start|upcoming'");
      #-- more complicated to check here,
      #   format is '<id>          start/end    <datestart>  <timestart>-<dateend> <timeend> [<description>]
      #             58b54d...4b    end          22.05.2018   00:00-03.06.2018      00:00     Pfingstferien 
      if($fline){
        #chomp($fline);
        @lines = split('\n',$fline);
        foreach $fline (@lines){
          chomp($fline);
          @chunks = split(' ',$fline);
          @sday   = split('\.',$chunks[2]);
          @eday   = split('\.',substr($chunks[3],6,10));
          
          #-- today
          my $rets  = ($sday[2]-$tday[2])*365+($sday[1]-$tday[1])*31+($sday[0]-$tday[0]);
          my $rete  = ($eday[2]-$tday[2])*365+($eday[1]-$tday[1])*31+($eday[0]-$tday[0]);
          if( ($rete>=0) && ($rets<=0) ){
            $todaydesc = $chunks[5];
            $todaytype = "vacation";
            Log3 $name, 1,"[YAAHM] found today=vacation \"$todaydesc\" in calendar $vacdayDev";
          }    
          $rets  = ($sday[2]-$tmor[2])*365+($sday[1]-$tmor[1])*31+($sday[0]-$tmor[0]);
          $rete  = ($eday[2]-$tmor[2])*365+($eday[1]-$tmor[1])*31+($eday[0]-$tmor[0]);
          if( ($rete>=0) && ($rets<=0) ){
            $tomdesc = $chunks[5];
            $tomtype = "vacation";
            Log3 $name, 1,"[YAAHM] found tomorrow=vacation \"$tomdesc\" in calendar $vacdayDev";
          }
          $rets  = ($sday[2]-$ttwo[2])*365+($sday[1]-$ttwo[1])*31+($sday[0]-$ttwo[0]);
          $rete  = ($eday[2]-$ttwo[2])*365+($eday[1]-$ttwo[1])*31+($eday[0]-$ttwo[0]);
          if( ($rete>=0) && ($rets<=0) ){
            $twodesc = $chunks[5];
            $twotype = "vacation";
            Log3 $name, 1,"[YAAHM] found twodays=vacation \"$twodesc\" in calendar $vacdayDev";
          }
        }
      }  
    }else{
      Log3 $name, 1,"[YAAHM] unknown vacation device $vacdayDev";
    }
  }
  #-- put into readings
  if( $todaytype eq "vacation" ){
    $hash->{DATA}{"DD"}[0]{"daytype"}    = "vacation";
    $hash->{DATA}{"DD"}[0]{"desc"}       = $todaydesc;
    $hash->{DATA}{"DD"}[0]{"vacflag"}    = 1;
  }
  if( $tomtype eq "vacation" ){
    $hash->{DATA}{"DD"}[1]{"daytype"}    = "vacation";
    $hash->{DATA}{"DD"}[1]{"desc"}       = $tomdesc;
    $hash->{DATA}{"DD"}[1]{"vacflag"}    = 1;
  }
  if( $twotype eq "vacation" ){
    $hash->{DATA}{"DD"}[2]{"daytype"}    = "vacation";
    $hash->{DATA}{"DD"}[2]{"desc"}       = $twodesc;
    $hash->{DATA}{"DD"}[2]{"vacflag"}    = 1;
  }
  
  #-- weekend has higher priority 
  if( strftime('%u', localtime(time)) > 5){
    $todaytype = "weekend";
    if( $hash->{DATA}{"DD"}[0]{"daytype"} ne "workday" ){
      $hash->{DATA}{"DD"}[0]{"desc"}       = $yaahm_tt->{"weekend"}[0].", ".$hash->{DATA}{"DD"}[0]{"desc"};
    }else{
      $hash->{DATA}{"DD"}[0]{"desc"}       = $yaahm_tt->{"weekend"}[0];
    }
    $hash->{DATA}{"DD"}[0]{"daytype"}    = "weekend";
  }
  
  if( strftime('%u', localtime(time+86400)) > 5){
    $tomtype = "weekend";
    if( $hash->{DATA}{"DD"}[1]{"daytype"} ne "workday" ){
      $hash->{DATA}{"DD"}[1]{"desc"}       = $yaahm_tt->{"weekend"}[0].", ".$hash->{DATA}{"DD"}[1]{"desc"};
    }else{
      $hash->{DATA}{"DD"}[1]{"desc"}       = $yaahm_tt->{"weekend"}[0];
    }
    $hash->{DATA}{"DD"}[1]{"daytype"}   = "weekend";
  }
  
  if( strftime('%u', localtime(time+2*86400)) > 5){
    $twotype = "weekend";
    if( $hash->{DATA}{"DD"}[2]{"daytype"} ne "workday" ){
      $hash->{DATA}{"DD"}[2]{"desc"}       = $yaahm_tt->{"weekend"}[0].", ".$hash->{DATA}{"DD"}[2]{"desc"};
    }else{
      $hash->{DATA}{"DD"}[2]{"desc"}       = $yaahm_tt->{"weekend"}[0];
    }
    $hash->{DATA}{"DD"}[2]{"daytype"}   = "weekend";
  }
    
  #-- holidays have the highest priority
  my $holidayDevs = AttrVal( $name, "holidayDevices", "" );
  foreach my $holidayDev ( split( /,/, $holidayDevs ) ) {
  
    #-- device of type holiday 
    if( IsDevice( $holidayDev, "holiday" )){      
      $stoday = strftime('%m-%d', localtime(time));
      $stom   = strftime('%m-%d', localtime(time+86400));
      $stwo   = strftime('%m-%d', localtime(time+2*86400));
      my $tod = holiday_refresh( $holidayDev, $stoday );
      if ( $tod ne "none" ) {
        $todaydesc = $tod;
        $todaytype = "holiday";
        Log3 $name, 5,"[YAAHM] found today=holiday \"$todaydesc\" in holiday $holidayDev";
      }
      $tod = holiday_refresh( $holidayDev, $stom );
      if ( $tod ne "none" ) {
        $tomdesc = $tod;
        $tomtype = "holiday";
        Log3 $name, 5,"[YAAHM] found tomorrow=holiday \"$tomdesc\" in holiday $holidayDev";
      }
      $tod = holiday_refresh( $holidayDev, $stwo );
      if ( $tod ne "none" ) {
        $twodesc = $tod;
        $twotype = "holiday";
        Log3 $name, 5,"[YAAHM] found twodays=holiday \"$twodesc\" in holiday $holidayDev";
      }
       
    #-- device of type calendar
    }elsif( IsDevice($holidayDev, "Calendar" )){
      $stoday  = strftime('%d.%m.%Y', localtime(time));
      $stom    = strftime('%d.%m.%Y', localtime(time+86400));
      $stwo    = strftime('%d.%m.%Y', localtime(time+2*86400));
      $line=Calendar_Get($defs{$holidayDev},"get","events","format:text filter:mode=~'alarm|start|upcoming'");
      #-- more complicated to check here,
      #   format is <datestart>  <timestart>-<dateend> <timeend> [<description>]
      #             03.10.2018   00:00-                          Tag der Deutschen Einheit 
      if($line){
        chomp($line);
        @lines = split('\n',$line);
        foreach $line (@lines){
          chomp($line);
          $date  = substr($line,0,10);
          if( $date eq $stoday ){
            $todaydesc = substr($line,17);
            $todaytype = "holiday";
            Log3 $name, 1,"[YAAHM] found today=holiday $date \"$todaydesc\" in calendar $holidayDev";
          }
          if( $date eq $stom ){
            $tomdesc = substr($line,17);
            $tomtype = "holiday";
            Log3 $name, 1,"[YAAHM] found tomorrow=holiday $date \"$tomdesc\" in calendar $holidayDev";
          }
          if( $date eq $stwo ){
            $twodesc = substr($line,17);
            $twotype = "holiday";
            Log3 $name, 1,"[YAAHM] found twodays=holiday $date \"$twodesc\" in calendar $holidayDev";
          }
        }
      }
    }else{
      Log3 $name, 1,"[YAAHM] unknown holiday device $holidayDev";
    }      
  }
  
  #-- put into store
  if( $todaytype eq "holiday" ){
    if( $hash->{DATA}{"DD"}[0]{"daytype"} ne "workday" ){
      $hash->{DATA}{"DD"}[0]{"desc"}       = $todaydesc.", ".$hash->{DATA}{"DD"}[0]{"desc"};
    }else{
      $hash->{DATA}{"DD"}[0]{"desc"}       = $todaydesc;
    }
    $hash->{DATA}{"DD"}[0]{"daytype"}    = "holiday";
  }
  if( $tomtype eq "holiday" ){
    if( $hash->{DATA}{"DD"}[1]{"daytype"} ne "workday" ){
      $hash->{DATA}{"DD"}[1]{"desc"}       = $tomdesc.", ".$hash->{DATA}{"DD"}[1]{"desc"};
    }else{
      $hash->{DATA}{"DD"}[1]{"desc"}       = $tomdesc;
    }
    $hash->{DATA}{"DD"}[1]{"daytype"}    = "holiday";
  }
  if( $twotype eq "holiday" ){
    if( $hash->{DATA}{"DD"}[2]{"daytype"} ne "workday" ){
      $hash->{DATA}{"DD"}[2]{"desc"}       = $twodesc.", ".$hash->{DATA}{"DD"}[2]{"desc"};
    }else{
      $hash->{DATA}{"DD"}[2]{"desc"}       = $twodesc;
    }
    $hash->{DATA}{"DD"}[2]{"daytype"}    = "holiday";
  }
 
  #-- sunrise, sunset and the offsets 
  YAAHM_sun($hash);
  YAAHM_sunoffsets($hash);
 
  readingsBeginUpdate($hash);
  #-- and do not forget to put them into readings, because these are read by the timer
  foreach my $key (sort YAAHM_dsort keys %defaultdailytable){

    my $f1 = defined($defaultdailytable{$key}[0]);
    my $f2 = defined($defaultdailytable{$key}[1]);
    #-- entries in the default table with no entry are single-timers
    if( !$f1 and !$f2 ){
      readingsBulkUpdate( $hash, "s_".$key, $hash->{DATA}{"DT"}{$key}[0] );
        
    #-- entries in the default table with only first time are single-timers
    }elsif( $f1 and !$f2 ){
      readingsBulkUpdate( $hash, "s_".$key, $hash->{DATA}{"DT"}{$key}[0] );
        
    #-- entries in the default table with only second time are single-timer offsets
    }elsif( !$f1 and $f2 ){
      readingsBulkUpdate( $hash, "s_".$key, $hash->{DATA}{"DT"}{$key}[0] );
        
    #-- entries in the default table with first and second time are two-timer periods
    }elsif( $f1 and $f2 ){
      readingsBulkUpdate( $hash, "s_".$key, $hash->{DATA}{"DT"}{$key}[0] );
      readingsBulkUpdate( $hash, "t_".$key, $hash->{DATA}{"DT"}{$key}[1] );
   
    #-- something wrong
    }else{
      my $msg = "Readings update failed, something wrong with entry ".$key;
      Log 1,"[YAAHM_GetDayStatus] ".$msg;
      return $msg;
    }
  }
  
  readingsBulkUpdateIfChanged( $hash, "todayType",$todaytype );
  readingsBulkUpdateIfChanged( $hash, "tr_todayType",$yaahm_tt->{$hash->{DATA}{"DD"}[0]{"daytype"}}[0] );
  if( $todaytype eq "workday"){
    readingsBulkUpdateIfChanged( $hash, "todayDesc","--" )
  }elsif( $todaytype eq "vacation"){
    readingsBulkUpdateIfChanged( $hash, "todayDesc",$hash->{DATA}{"DD"}[0]{"desc"} )
  }elsif( $todaytype eq "weekend"){
    readingsBulkUpdateIfChanged( $hash, "todayDesc","--" )
  }else{
    readingsBulkUpdateIfChanged( $hash, "todayDesc",$hash->{DATA}{"DD"}[0]{"desc"} )
  }
  
  readingsBulkUpdateIfChanged( $hash, "tomorrowType",$tomtype );
  readingsBulkUpdateIfChanged( $hash, "tr_tomorrowType",$yaahm_tt->{$hash->{DATA}{"DD"}[1]{"daytype"}}[0] );
  if( $tomtype eq "workday"){
    readingsBulkUpdateIfChanged( $hash, "tomorrowDesc","--" )
  }elsif( $tomtype eq "vacation"){
    readingsBulkUpdateIfChanged( $hash, "tomorrowDesc",$hash->{DATA}{"DD"}[1]{"desc"} )
  }elsif( $tomtype eq "weekend"){
    readingsBulkUpdateIfChanged( $hash, "tomorrowDesc","--" )
  }else{
    readingsBulkUpdateIfChanged( $hash, "tomorrowDesc",$hash->{DATA}{"DD"}[1]{"desc"} )
  }
  
  readingsBulkUpdateIfChanged( $hash, "twodaysType",$tomtype );
  readingsBulkUpdateIfChanged( $hash, "tr_twodaysType",$yaahm_tt->{$hash->{DATA}{"DD"}[2]{"daytype"}}[0] );
  if( $tomtype eq "workday"){
    readingsBulkUpdateIfChanged( $hash, "twodaysDesc","--" )
  }elsif( $tomtype eq "vacation"){
    readingsBulkUpdateIfChanged( $hash, "twodaysDesc",$hash->{DATA}{"DD"}[2]{"desc"} )
  }elsif( $tomtype eq "weekend"){
    readingsBulkUpdateIfChanged( $hash, "twodaysDesc","--" )
  }else{
    readingsBulkUpdateIfChanged( $hash, "twodaysDesc",$hash->{DATA}{"DD"}[2]{"desc"} )
  }
  
  YAAHM_setWeeklyTime($hash);
  
  readingsEndUpdate($hash,1);
  
  return undef;

}

#########################################################################################
#
# YAAHM_sun - obtain time offsets for midnight etc. sunrise and sunset
# 
# Parameter hash = hash of device addressed
#
#########################################################################################

sub YAAHM_sun($) {
  my ($hash) = @_;
  my $name = $hash->{NAME};
  
  #-- sunrise and sunset today and tomorrow and in two days
  my ($sttoday,$sttom,$sttwo);
  my $count   = 0;
  my $strise0 = "";
  my $strise1 = "";
  my $strise2 = "";
  my ($msg,$stset0,$stseas0,$stset1,$stseas1,$stset2,$stseas2);
  
  my $sunsetf  = AttrVal($name,"sunset","SunSet");
  my $sunrisef = AttrVal($name,"sunrise","SunRise");
  
  $sttoday = strftime('%Y-%m-%d', localtime(time));
  
  #-- since the Astro module sometimes gives us strange results, we need to do this more than once
  while( $strise0 !~ /^\d\d:\d\d:\d\d/ && $count < 5){
    $strise0 = Astro_Get($hash,"dummy","text", $sunrisef,$sttoday).":00";
    $count++;
    select(undef,undef,undef,0.01);
  }
  if( $count == 5 ){
    $msg = "Error, no proper sunrise today return from Astro module in 5 attempts";
    Log3 $name,1,"[YAAHM_sun] ".$msg;
    $strise0 = "06:00:00";
  }
  my ($hour,$min) = split(":",$strise0);
  $hash->{DATA}{"DD"}[0]{"sunrise"} = sprintf("%02d:%02d",$hour,$min);
 
  
  $stset0  = Astro_Get($hash,"dummy","text", $sunsetf,$sttoday).":00";
  ($hour,$min) = split(":",$stset0);
  $hash->{DATA}{"DD"}[0]{"sunset"} = sprintf("%02d:%02d",$hour,$min);
  
  $stseas0 = Astro_Get($hash,"dummy","text", "ObsSeasonN",$sttoday);
  $hash->{DATA}{"DD"}[0]{"season"}    = $seasons[$stseas0];   
  
  $sttom = strftime('%Y-%m-%d', localtime(time+86400));
  $count = 0;
  $msg   = "";
  #-- since the Astro module sometimes gives us strange results, we need to do this more than once
  while( $strise1 !~ /^\d\d:\d\d:\d\d/ && $count < 5){
    $strise1 = Astro_Get($hash,"dummy","text", $sunrisef,$sttom).":00";
    $count++;
    select(undef,undef,undef,0.01);
  }
  if( $count == 5 ){
    $msg = "Error, no proper sunrise tomorrow return from Astro module in 5 attempts";
    Log3 $name,1,"[YAAHM_sun] ".$msg;
    $strise1 = "06:00:00";
  }
  ($hour,$min) = split(":",$strise1);
  $hash->{DATA}{"DD"}[1]{"sunrise"} = sprintf("%02d:%02d",$hour,$min);
  
  $stset1  = Astro_Get($hash,"dummy","text", $sunsetf,$sttom).":00";
  ($hour,$min) = split(":",$stset1);
  $hash->{DATA}{"DD"}[1]{"sunset"} = sprintf("%02d:%02d",$hour,$min);
  
  $stseas1 = Astro_Get($hash,"dummy","text", "ObsSeasonN",$sttom);
  $hash->{DATA}{"DD"}[1]{"season"}    = $seasons[$stseas1]; 
  
  $sttwo = strftime('%Y-%m-%d', localtime(time+2*86400));
  $count = 0;
  $msg   = "";
  #-- since the Astro module sometimes gives us strange results, we need to do this more than once
  while( $strise2 !~ /^\d\d:\d\d:\d\d/ && $count < 5){
    $strise2 = Astro_Get($hash,"dummy","text", $sunrisef,$sttwo).":00";
    $count++;
    select(undef,undef,undef,0.01);
  }
  if( $count == 5 ){
    $msg = "Error, no proper sunrise twodays return from Astro module in 5 attempts";
    Log3 $name,1,"[YAAHM_sun] ".$msg;
    $strise2 = "06:00:00";
  }
  ($hour,$min) = split(":",$strise2);
  $hash->{DATA}{"DD"}[2]{"sunrise"} = sprintf("%02d:%02d",$hour,$min);
  
  $stset2  = Astro_Get($hash,"dummy","text", $sunsetf,$sttom).":00";
  ($hour,$min) = split(":",$stset2);
  $hash->{DATA}{"DD"}[2]{"sunset"} = sprintf("%02d:%02d",$hour,$min);
  
  $stseas2 = Astro_Get($hash,"dummy","text", "ObsSeasonN",$sttwo);
  $hash->{DATA}{"DD"}[2]{"season"}    = $seasons[$stseas2]; 
}

#########################################################################################
#
# YAAHM_sunoffsets - obtain time offsets for midnight etc. sunrise and sunset
# 
# Parameter hash = hash of device addressed
#
#########################################################################################

sub YAAHM_sunoffsets($) {
  my ($hash) = @_;
  
  #-- sunrise
  my $st = $hash->{DATA}{"DD"}[0]{"sunrise"};
  
  my ($hour,$min) = split(":",$st);
  $hash->{DATA}{"DT"}{"sunrise"}[0] = sprintf("%02d:%02d",$hour,$min); 
  
  #-- before sunrise
  my ($ofh,$ofm);
  my $of =  $hash->{DATA}{"DT"}{"beforesunrise"}[1];
  if( $of !~ /\d\d:\d\d/){
    Log 1,"[YAAHM] Offset before sunrise not in format hh:mm, using 00:00";
    $ofh = 0;
    $ofm = 0;
  }else{
    ($ofh,$ofm) = split(":",$of);
  }
  $ofm = $min-$ofm;
  $ofh = $hour-$ofh;
  if( $ofm < 0 ){
    $ofh--;
    $ofm +=60;
  }
  $hash->{DATA}{"DT"}{"beforesunrise"}[0] = sprintf("%02d:%02d",$ofh,$ofm);
  
  #-- after sunrise
  $of =  $hash->{DATA}{"DT"}{"aftersunrise"}[1];
  if( $of !~ /\d\d:\d\d/){
    Log 1,"[YAAHM] Offset after sunrise not in format hh:mm, using 00:00";
    $ofh = 0;
    $ofm = 0;
  }else{
    ($ofh,$ofm) = split(":",$of);
  }
  $ofm = $min+$ofm;
  $ofh = $hour+$ofh;
  if( $ofm > 59 ){
    $ofh++;
    $ofm -=60;
  }
  $hash->{DATA}{"DT"}{"aftersunrise"}[0] = sprintf("%02d:%02d",$ofh,$ofm); 
  
  #-- sunset
  $st = $hash->{DATA}{"DD"}[0]{"sunset"};
  ($hour,$min) = split(":",$st);
  $hash->{DATA}{"DT"}{"sunset"}[0] = sprintf("%02d:%02d",$hour,$min);
  
  #-- before sunset
  $of =  $hash->{DATA}{"DT"}{"beforesunset"}[1];
  if( $of !~ /\d\d:\d\d/){
    Log 1,"[YAAHM] Offset before sunset not in format hh:mm, using 00:00";
    $ofh = 0;
    $ofm = 0;
  }else{
    ($ofh,$ofm) = split(":",$of);
  }
  $ofm = $min-$ofm;
  $ofh = $hour-$ofh;
  if( $ofm < 0 ){
    $ofh--;
    $ofm +=60;
  }
  $hash->{DATA}{"DT"}{"beforesunset"}[0] = sprintf("%02d:%02d",$ofh,$ofm); 
  
  #-- after sunset
  $of =  $hash->{DATA}{"DT"}{"aftersunset"}[1];
  if( $of !~ /\d\d:\d\d/){
    Log 1,"[YAAHM] Offset after sunset not in format hh:mm, using 00:00";
    $ofh = 0;
    $ofm = 0;
  }else{
    ($ofh,$ofm) = split(":",$of);
  }
  $ofm = $min+$ofm;
  $ofh = $hour+$ofh;
  if( $ofm > 59 ){
    $ofh++;
    $ofm -=60;
  }
  $hash->{DATA}{"DT"}{"aftersunset"}[0] = sprintf("%02d:%02d",$ofh,$ofm);
  
  #-- before midnight
  $hour = 24;
  $min  = 0;
  $of =  $hash->{DATA}{"DT"}{"beforemidnight"}[1];
  if( $of !~ /\d\d:\d\d/){
    Log 1,"[YAAHM] Offset before midnight not in format hh:mm, using 00:05";
    $ofh = 0;
    $ofm = 5;
  }else{
    ($ofh,$ofm) = split(":",$of);
  }
  $ofm = $min-$ofm;
  $ofh = $hour-$ofh;
  if( $ofm < 0 ){
    $ofh--;
    $ofm +=60;
  }
  $hash->{DATA}{"DT"}{"beforemidnight"}[0] = sprintf("%02d:%02d",$ofh,$ofm); 
  
  #-- after midnight
  $hour = 0;
  $min  = 0;
  $of =  $hash->{DATA}{"DT"}{"aftermidnight"}[1];
  if( $of !~ /\d\d:\d\d/){
    Log 1,"[YAAHM] Offset after midnight not in format hh:mm, using 00:05";
    $ofh = 0;
    $ofm = 5;
  }else{
    ($ofh,$ofm) = split(":",$of);
  }
  $ofm = $min+$ofm;
  $ofh = $hour+$ofh;
  if( $min > 59 ){
    $ofh++;
    $ofm -=60;
  }
  $hash->{DATA}{"DT"}{"aftermidnight"}[0] = sprintf("%02d:%02d",$ofh,$ofm); 
}

#########################################################################################
#
# YAAHM_statewidget - returns SVG code for inclusion into page
# 
# Parameter hash = hash of device addressed
#
#########################################################################################

sub YAAHM_statewidget($){
   my ($hash) = @_;
   
   my $name = $hash->{NAME};
   return "" 
     if( AttrVal($name,"noicons",0) == 1);
   
   my $state = $hash->{DATA}{"HSM"}{"state"};
   my ($color,$locks,$unlocks,$bells,$eyes);
   if( $state eq "unsecured" ){
     $color=$csstate[0];
     $locks="hidden";
     $unlocks="visible";
     $bells="hidden";
     $eyes="hidden";
  }elsif( $state eq "secured" ){
     $color=$csstate[1];
     $locks="visible";
     $unlocks="hidden";
     $bells="hidden";
     $eyes="hidden";
   }elsif( $state eq "protected" ){
     $color=$csstate[2];
     $locks="visible";
     $unlocks="hidden";
     $bells="visible";
     $eyes="hidden";
   }elsif( $state eq "guarded" ){
     $color=$csstate[3];
     $locks="visible";
     $unlocks="hidden";
     $bells="visible";
     $eyes="visible";
   }else{
     Log 1,"[YAAHM_statewidget] Error, housestate $state not defined";
     return;
   }

   my $ret = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 40" width="40px" height="40px">';
   $ret .= '<g transform="translate(5,0)">\n';
   #-- shield  
   $ret .='<g transform="scale(0.1,0.1)">\n'.
          '<path class="hs_is" fill="'.$color.'" d="M179.6,13c0,0-50.1,44.5-146.1,48.5c0,0,13.5,158,50.5,197s95.6,80,95.6,80s78.9-55.5,98.9-81.5 s37.5-75,47-196.5C325.5,60.5,251.8,64,179.6,13z"/>'.
          '<path style="fill:none;stroke:black;stroke-width:10" d="M179.6,13c0,0-50.1,44.5-146.1,48.5c0,0,13.5,158,50.5,197s95.6,80,95.6,80s78.9-55.5,98.9-81.5 s37.5-75,47-196.5C325.5,60.5,251.8,64,179.6,13z"/></g>'; 
   #-- small bell
   $ret .=  '<g class="hs_smb" transform="translate(0,23) scale(0.28,0.28)" visibility="'.$bells.'">\n';
   $ret .=  '<path d="M 25 6 C 23.354545 6 22 7.3545455 22 9 L 22 10.365234 C 17.172775 11.551105 14.001117 15.612755 14.001953 21.0625 '.
            'L 14.001953 28.863281 C 14.001953 31.035281 12.718469 33.494563 11.980469 34.726562 L 10.167969 37.445312 C 9.9629687 37.751312 9.9431875 '.
            '38.147656 10.117188 38.472656 C 10.291188 38.797656 10.631 39 11 39 L 39 39 C 39.369 39 39.708813 38.797656 39.882812 38.472656 C 40.056813 '.
            '38.147656 40.037031 37.752313 39.832031 37.445312 L 38.044922 34.767578 C 36.668922 32.473578 36 30.587 36 29 L 36 21.199219 C 36 15.68167 '.
            '32.827303 11.569596 28 10.369141 L 28 9 C 28 7.3545455 26.645455 6 25 6 z M 25 8 C 25.554545 8 26 8.4454545 26 9 L 26 10.044922 C 25.671339 '.
            '10.019952 25.339787 10 25 10 C 24.660213 10 24.328661 10.020256 24 10.044922 L 24 9 C 24 8.4454545 24.445455 8 25 8 z " fill="black" stroke="black"/>'.
            '.<path d="M 20.423828 41 C 21.197828 42.763 22.955 44 25 44 C 27.045 44 28.802172 42.763 29.576172 41 L 20.423828 41 z" fill="black"/></g>\n';
   #-- lock 
    $ret .= '<g transform="translate(1,-2) scale(0.1,0.1)" visibility="visible" style="fill:black">\n';
    $ret .= '<path d="M 130.57422 130.58594 C 129.00209 130.6591 127.9626 130.81157 126.67383 131.14062 C 121.6497 132.42339 117.28863 136.02241 114.93164 140.83398 '. 
            'C 114.02534 142.68411 113.52297 144.27216 113.15234 146.45508 C 113.00288 147.33557 112.9931 149.48213 112.9668 187.17578 C 112.9473 215.14019 '.
            '112.96786 227.3203 113.03516 228.16016 C 113.33148 231.85916 114.6641 235.33647 116.91797 238.29492 C 117.57258 239.15416 119.29708 240.86998 '.
            '120.20508 241.56445 C 122.81931 243.56391 125.66412 244.76433 128.79688 245.18945 C 130.22882 245.38381 208.07219 245.39507 209.54102 245.20117 '.
            'C 217.01971 244.21392 223.13119 238.65732 224.92969 231.21289 C 225.49437 228.87561 225.45703 232.00604 225.45703 187.94336 C 225.45703 161.07427 '.
            '225.42603 147.57463 225.36523 147.07227 C 225.02812 144.2871 223.98281 141.29331 222.58203 139.10742 C 219.44374 134.21016 214.3933 131.11459 '.
            '208.72656 130.61328 C 208.60764 130.60277 208.27712 130.59537 208.06445 130.58594 L 191.28711 130.58594 L 191.28711 130.60938 L 169.33203 130.60938 '. 
            'L 147.37695 130.60938 L 147.37695 130.58594 L 130.57422 130.58594 z M 168.84766 141.69531 C 196.24408 141.67681 207.96833 141.69697 208.37305 141.76367 '. 
            'C 209.88322 142.01259 211.23437 142.69523 212.37109 143.78125 C 213.56262 144.91963 214.28722 146.23107 214.60742 147.82812 C 214.73627 148.47097 '.
            '214.74661 152.13826 214.72461 188.36914 L 214.70117 228.20312 L 214.5 228.85352 C 213.61281 231.71117 211.36106 233.77649 208.56055 234.30469 C '.
            '207.89347 234.43005 204.00466 234.44545 169.125 234.43945 C 131.56507 234.4334 130.40611 234.42765 129.63281 234.26562 C 128.63219 234.05598 127.28912 '. 
            '233.40183 126.47852 232.73047 C 124.95438 231.46815 123.97606 229.64008 123.74609 227.625 C 123.67879 227.03543 123.65738 215.18032 123.67578 187.48438 '.
            'L 123.70312 148.18164 L 123.90234 147.47266 C 124.36618 145.82739 125.37129 144.27333 126.59375 143.31055 C 127.28146 142.76892 128.48475 142.14943 '.
            '129.36719 141.88281 C 129.87599 141.72912 131.53564 141.72051 168.84766 141.69531 z "/>\n'.
            '<path d="m 168.43291,207.79319 c -2.82175,-0.41393 -5.20902,-2.19673 -6.45085,-4.81746 -0.18456,-0.38949 -0.42714,-1.02683 -0.53907,-1.41632 -0.20211,-0.70332 '.
            '-0.20369,-0.74985 -0.23134,-6.79219 l -0.0278,-6.08403 -0.4938,-0.46648 c -1.94776,-1.84005 -3.29729,-4.28865 -3.89177,-7.06126 -0.22834,-1.06501 '.
            '-0.23065,-3.78941 -0.004,-4.90967 0.5504,-2.72228 1.69072,-4.87295 3.59555,-6.78128 1.86685,-1.87027 3.93834,-2.98308 6.53099,-3.50847 1.14974,-0.23298 '.
            '3.66048,-0.21247 4.804,0.0393 5.18176,1.14065 9.02113,5.15685 9.96535,10.42433 0.21336,1.19023 0.21526,3.4008 0.004,4.5588 -0.4602,2.5216 -1.68503,4.94293 '.
            '-3.41861,6.75821 -0.69412,0.72682 -0.76553,0.83257 -0.69333,1.02659 0.0464,0.1247 0.0688,2.7301 0.0528,6.15217 -0.027,5.78112 -0.0327,5.95363 -0.22,6.61733 '.
            '-0.66956,2.3726 -2.29646,4.38412 -4.40661,5.44839 -0.87624,0.44194 -1.4689,0.63145 -2.43431,0.77844 -0.91656,0.13954 -1.37046,0.14668 -2.14096,0.0337 l 0,0 z"/></g>\n'; 
    $ret .= '<g class="hs_unlocked" transform="translate(1,-2) scale(0.1,0.1)" visibility="'.$unlocks.'" style="fill:black">\n';
    $ret .= '<path d="M 170.82812 73.273438 C 169.18654 73.276141 168.63971 73.313421 167.69531 73.492188 C 165.61131 73.886674 163.21555 74.79455 161.46875 75.849609 '.
            'C 159.08962 77.286589 156.84235 79.476504 155.35742 81.806641 C 154.71611 82.812977 143.83472 103.12552 143.69141 103.58398 C 143.32362 104.76045 143.9985 '.
            '106.3 145.13867 106.88867 C 145.89649 107.27994 146.17527 107.28572 149.68359 106.98633 C 153.46023 106.66405 153.66989 106.60755 154.45508 105.72266 C '.
            '154.74018 105.40138 156.38998 102.44246 159.67383 96.359375 C 164.73578 86.982504 164.89996 86.708871 166.08984 85.746094 C 168.20634 84.033559 171.35111 '.
            '83.652548 173.67188 84.828125 C 175.01748 85.50974 200.19425 99.256274 200.56836 99.513672 C 201.52002 100.16843 202.5089 101.37978 203 102.49023 C 203.13162 '.
            '102.78785 203.32969 103.40656 203.43945 103.86523 C 203.70946 104.99358 203.65191 106.59046 203.30273 107.66992 C 203.08072 108.35626 193.2629 127.83267 '.
            '192.83203 128.44141 L 192.7168 128.60352 L 204.32227 128.60352 C 204.34489 128.54135 206.0865 125.32409 208.24219 121.36133 C 210.41184 117.37291 212.41514 '. 
            '113.62986 212.69531 113.04297 C 216.53579 104.99821 213.90717 95.127045 206.625 90.25 C 205.84937 89.730545 181.06362 76.260203 178.6582 75.050781 C 177.5495 '.
            '74.493339 176.37806 74.054405 175.24219 73.771484 C 173.49309 73.335818 172.90843 73.270038 170.82812 73.273438 z"/></g>\n';
    $ret .= '<g class="hs_locked" transform="translate(1,-2) scale(0.1,0.1)" visibility="'.$locks.'" style="fill:black">\n';
    $ret .= '<path d="M 169.33398 90.152344 C 161.36399 90.152344 153.39548 90.185221 152.80078 90.25 C 145.74301 91.018795 139.82758 95.841827 137.60547 102.63867 C '.
            '137.17355 103.9598 136.90608 105.2186 136.76367 106.60938 C 136.70267 107.20469 136.66992 111.55655 136.66992 119.02344 L 136.66992 130.49805 L 147.37695 '.
            '130.49805 L 147.40234 118.94727 L 147.42773 107.28516 L 147.62109 106.60352 C 148.34477 104.05797 150.12767 102.25431 152.73633 101.42969 L 153.5332 101.17773 '. 
            'L 169.24609 101.17773 L 184.95898 101.17773 L 185.70703 101.37695 C 186.11913 101.48679 186.71238 101.69727 187.02539 101.84375 C 189.21729 102.86946 190.84344 '.
            '105.12709 191.19141 107.62891 C 191.25571 108.09078 191.28711 111.96821 191.28711 119.46289 L 191.28711 130.49805 L 201.99805 130.49805 L 201.99805 119.11719 C '.
            '201.99805 111.72973 201.9653 107.37447 201.9043 106.74805 C 201.77551 105.42445 201.44824 103.83653 201.06445 102.67773 C 200.64348 101.40669 199.67547 99.408912 '.
            '198.95703 98.326172 C 195.91418 93.74044 191.20002 90.830687 185.86914 90.25 C 185.27445 90.185221 177.30398 90.152344 169.33398 90.152344 z"/></g>\n';
    #-- eye
    $ret .= '<g class="hs_eye" transform="translate(18,24) scale(0.014,0.014)" visibility="'.$eyes.'" style="fill:black">\n';
    $ret .= '<path d="M493.6,794C196.9,794,10,576.3,10,518.6C10,460.8,196.9,206,493.6,206C790.2,206,990,444,990,518.6C990,593.1,790.2,794,493.6,794z M480.2,368.2c-43.3,0-78.4,'.
            '36.3-78.4,81c0,44.7,35.1,81,78.4,81c43.3,0,78.4-36.3,78.4-81C558.6,404.4,523.5,368.2,480.2,368.2z M715.6,327.7c28.6,39.3,48,79.2,48,132.1c0,129.9-102.1,235.2-228.1,'.
            '235.2c-125.9,0-228-105.3-228-235.2c0-80.3,15.4-130.2,74.9-172.7C194.4,316,76,472.2,76,514.9c0,46.8,155.7,217.2,414.2,217.2c258.5,0,427.8-156.8,427.8-217.2C918,475.6,'.
            '873.8,393.3,715.6,327.7z"/></g>\n';
   $ret .=  '</g></svg>';
   
   return $ret
}


#########################################################################################
#
# YAAHM_modewidget - returns SVG code for inclusion into page
# 
# Parameter hash = hash of device addressed
#
#########################################################################################

sub YAAHM_modewidget($){
   my ($hash) = @_;
   
   my $name = $hash->{NAME};
   return "" 
     if( AttrVal($name,"noicons",0) == 1);
   
   my $mode = $hash->{DATA}{"HSM"}{"mode"};
   my ($color,$normals,$absents,$partys,$dnds);
   if( $mode eq "normal" ){
     $color=$csmode[0];
     $normals="visible";
     $partys="hidden";
     $absents="hidden";
     $dnds="hidden";
  }elsif( $mode eq "party" ){
     $color=$csmode[1];
     $normals="hidden";
     $partys="visible";
     $absents="hidden";
     $dnds="hidden";
   }elsif( $mode eq "absence" ){
     $color=$csmode[2];
     $normals="hidden";
     $partys="hidden";
     $absents="visible";
     $dnds="hidden";
   }elsif( $mode eq "donotdisturb" ){
     $color=$csmode[3];
     $normals="hidden";
     $partys="hidden";
     $absents="hidden";
     $dnds="visible";
   }else{
     Log 1,"[YAAHM_modewidget] Error, housemode $mode not defined";
     return;
   }

   my $ret = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 40" width="40px" height="40px">';
   $ret .= ' <g transform="translate(6,5) scale(0.8,0.8)">';
   $ret .= ' <circle class="hm_is" r="20" cx="20" cy="20" fill="'.$color.'" stroke="none"/>'.
           ' <circle r="20" cx="20" cy="20" style="fill:none;stroke:black"/>';
   $ret .= ' <g class="hm_n" transform="translate(0,-6) scale(0.08,0.08)" style="fill:black" visibility="'.$normals.'">'.
           '<path d="m 313.166,240.194 c 16.213,0 29.35,-13.139 29.35,-29.351 0,-16.213 -13.137,-29.351 -29.35,-29.351 -16.214,0 -29.351,13.138 -29.351,29.351 0,16.212 13.137,29.351 29.351,29.351 z"/>'.
           '<path d="m 346.165,252.835 c -1.794,-4.361 -6.008,-6.992 -10.449,-6.989 -0.034,-0.002 -0.069,-0.005 -0.103,-0.005 l -44.897,0 c -0.05,0 -0.099,0.005 -0.148,0.007 -4.462,-0.026 -8.704,2.607 '.
           '  -10.506,6.987 l -34.027,82.713 -34.013,-82.677 c -1.156,-2.809 -4.349,-7.03 -10.858,-7.03 0,0 -33.673,0 -44.897,0 -0.041,0 -0.081,0.005 -0.121,0.006 -4.446,0.057 -8.666,2.623 -10.463,6.989 '.
           '  l -41.854,101.739 c -2.371,5.764 0.379,12.359 6.143,14.73 1.405,0.578 2.859,0.852 4.289,0.852 4.438,0 8.647,-2.636 10.441,-6.995 l 18.433,-44.807 0,7.792 -21.053,65.773 c -3.541,11.061 '.
           '  4.711,22.368 16.326,22.368 l 4.727,0 0,52.187 c 0,8.382 6.944,15.141 15.393,14.841 8.047,-0.287 14.308,-7.145 14.308,-15.197 l 0,-51.831 11.758,0 0,52.187 c 0,8.381 6.943,15.141 '.
           '  15.392,14.841 8.048,-0.286 14.309,-7.145 14.309,-15.197 l 0,-51.83 4.727,0 c 11.614,0 19.866,-11.307 16.326,-22.368 l -21.053,-65.773 0,-8.423 18.707,45.473 c 1.793,4.359 '.
           '  6.003,6.995 10.441,6.995 0.887,0 1.782,-0.119 2.671,-0.337 0.84,0.194 1.687,0.301 2.525,0.301 4.438,0 8.647,-2.636 10.441,-6.995 l 18.504,-44.979 0,148.292 c 0,8.382 6.944,15.141 '. 
           '  15.393,14.841 8.047,-0.287 14.308,-7.145 14.308,-15.197 l 0,-80.144 c 0,-3.132 2.363,-5.866 5.488,-6.068 3.424,-0.221 6.27,2.49 6.27,5.866 l 0,80.701 c 0,8.381 6.944,15.141 15.392,14.841 '. 
           '  8.048,-0.286 14.309,-7.145 14.309,-15.197 l 0,-147.689 18.402,44.732 c 1.793,4.359 6.003,6.995 10.441,6.995 1.43,0 2.885,-0.274 4.29,-0.852 5.764,-2.371 8.514,-8.966 6.143,-14.73 L '.
           '  346.165,252.835 Z"/>'.
           '<path d="m 178.716,240.194 c 16.213,0 29.35,-13.139 29.35,-29.351 0,-16.213 -13.137,-29.351 -29.35,-29.351 -16.214,0 -29.351,13.138 -29.351,29.351 0,16.212 13.138,29.351 29.351,29.351 z"/></g>';
   $ret .= '<g class="hm_a" transform="translate(2.5,0) scale(0.125,0.125)" style="fill:black" visibility="'.$absents.'">'.
           '<path d="M59.717,110.045L53.353,98.45c-6.704,3.681-13.257,7.81-19.482,12.274l7.711,10.746     C47.376,117.315,53.476,113.47,59.717,110.045z" />'.
           '<path d="M99.411,94.105l-3.415-12.779c-7.389,1.975-14.738,4.424-21.841,7.277l4.929,12.274     C85.699,98.22,92.535,95.943,99.411,94.105z" />'.
           '<path d="M230.536,95.09c-6.834-3.415-13.958-6.452-21.186-9.029l-4.44,12.459c6.726,2.396,13.356,5.222,19.714,8.401     L230.536,95.09z" />'.
           '<path d="M285.464,136.504l-9.739,8.943c4.823,5.251,9.373,10.85,13.528,16.632L300,154.368     C295.538,148.152,290.649,142.14,285.464,136.504z" />'.
           '<path d="M243.18,117.654c5.932,3.935,11.694,8.28,17.115,12.909l8.588-10.059c-5.826-4.977-12.016-9.646-18.398-13.874     L243.18,117.654z" />'.
           '<path d="M0,141.823l10.054,8.593c4.629-5.416,9.64-10.605,14.888-15.422l-8.943-9.741C10.358,130.426,4.977,136.003,0,141.823z" />'.
           '<path d="M106.286,100.191l6.644,0.004l8.061-12.223l25.91,0.181l-11.593,39.963c0,1.166,0.948,2.116,2.114,2.116h10.66     l22.266-41.295l20.437,0.679c5.817,0,10.524-4.455,'.
           '   10.524-9.951c0.004-5.491-4.711-9.946-10.519-9.946l-20.589,0.688     l-22.117-41.023l-10.665-0.002c-1.166,0.002-2.114,0.952-2.114,2.118l11.513,39.685l-25.97,'.
           '   0.225l-7.923-11.987l-6.644,0.002     c-0.884,0-1.598,0.712-1.598,1.594v37.582C104.688,99.479,105.404,100.196,106.286,100.191z" />'.
           '<path d="M171.31,150.616c-8.657-1.973-17.503-2.974-26.307-2.974c-55.361,0-102.631,37.757-114.949,91.814     c-2.361,10.361-3.28,20.82-2.863,31.161h13.237v-0.003c-0.425-9.353,'.
           ' 0.379-18.823,2.515-28.201     c4.329,1.122,23.682,6.492,23.067,12.719c-0.518,5.222-2.198,11.17-0.8,15.481h12.166c1.671-1.217,3.282-1.797,4.858-0.139     c0.042,0.046,0.097,'.
           '  0.093,0.141,0.139h96.071c-22.612-14.403-25.811-39.848-25.811-39.848c-1.596-0.694,2.969-18.768-4.14-20.939     c-7.12-2.169-11.608-0.43-21.691-4.929'.
           '  c-10.096-4.499-6.316-10.786-4.658-25.789c0.708-6.402,2.337-12.133,4.413-16.636     c5.998-1.056,12.159-1.607,18.442-1.607c7.812,0,15.678,0.888,23.373,2.641c27.292,6.216,'.
           ' 50.529,22.69,65.43,46.38     c11.233,17.864,16.705,38.217,16.059,58.848c-0.864,0.628-1.792,1.254-2.762,1.883h15.907     c1.049-23.743-5.088-47.224-18.01-67.771C228.221,'.
           ' 176.164,202.05,157.617,171.31,150.616z" /></g>';
   $ret .= '<g class="hm_p" transform="translate(7,4) scale(0.027,0.027)" style="fill:black" visibility="'.$partys.'">'.
            '<path d="M64.6,951.8l114.8,36.8c16.1,5.1,33.2-3.7,38.5-19.8l0,0c5.1-16.1-3.7-33.2-19.8-38.5l-26.2-8.4l47.9-147.1c-10.3-1.8-20.5-4.3-30.5-7.5c-10.9-3.5-21.3-7.7-31.3-12.7l-48,'.
            '  147.4l-26.5-8.5c-16.1-5.1-33.2,3.7-38.5,19.8l0,0C39.7,929.4,48.5,946.6,64.6,951.8z" />'.
            '<path d="M167.2,725.7c26.3,13.8,61,22.3,90.8,22.3c58.8,0,115.7-27.5,152.3-73.6c33.4-42,43.9-96,52.9-147.6c4.7-27.1,20.8-142.7,21.4-152.9c0.5-8.4,'.
            '  1.3-19.4-3-26.9c-3.7-6.7-10-11.8-17.3-14.1l-246.9-79c-3.1-1-6.2-1.5-9.3-1.5c-10.9,0-21.2,5.8-26.7,15.7c-31.4,56.6-62.7,113.8-88.9,173C78,473.2,64.9,506.3,63,'.
            '  541.9c-1.7,29.8,3.7,60,15.4,87.4C96,670.5,127.5,704.9,167.2,725.7z M222.6,319.7l199,63.7c-9.8,82.7-19.7,145.2-28.9,183.5l-95.5-30.5l-62-19.8l-95.5-30.5C154.4,449.3,'.
            '  182.6,392.8,222.6,319.7z" />'.
            '<path d="M916.8,893.5l-26.5,8.5l-48-147.4c-10,4.9-20.4,9.2-31.3,12.7c-10,3.2-20.2,5.7-30.5,7.5l47.9,147l-26.2,8.4c-16.1,5.1-24.9,22.3-19.8,38.5l0,0c5.1,16.1,22.3,24.9,38.5,'.
            '  19.8l114.8-36.8c16.1-5.1,24.9-22.3,19.8-38.5l0,0C950.1,897.2,932.9,888.4,916.8,893.5z" />'.
            '<path d="M515.2,355.5c-0.7,3.1-0.9,6.4-0.5,9.8c0.1,1.2,15.4,132,28.5,195.1c7,34,15.8,67.9,34.7,97.4c15.9,24.9,37.5,46.1,62.7,61.4c30.4,18.6,65.8,28.6,101.5,28.6c20.2,0,'.
            '  40.5-3.2,59.7-9.3c10.9-3.5,21.2-7.8,31-13c52.9-27.6,90.7-79.6,101.4-138.2c11.3-62.4-13.8-120.8-40.2-175.8c-23.4-48.8-49.2-96.3-75.4-143.6c-5.5-9.9-15.8-15.7-26.7-15.7c-3.1,'.
            '  0-6.2,0.5-9.3,1.5l-246.9,79C525.1,336.2,517.5,345,515.2,355.5z M777.4,319.7c40.1,73.1,68.3,129.6,83,166.1l-95.5,30.5l-62,19.8l-95.5,30.5c-9.2-38.3-19.1-100.6-28.9-183.5L777.4,319.7z" /></g>';           
    $ret .= '<g class="hm_dnd" transform="translate(8,8) scale(0.05,0.05)" style="fill:white" visibility="'.$dnds.'">'.
            '<path d="M471,330v82h41V289H41V121c0-5.336-2-10.169-6-14.5c-4-4.333-8.833-6.5-14.5-6.5 S10,102.167,6,106.5s-6,9.167-6,14.5v291h41v-82H471z"/>'.
            '<path d="M105.5,205c10.333,0,19.333-3.667,27-11c7.667-7.334,11.5-16.168,11.5-26.5     c0-10.335-3.833-19.168-11.5-26.5c-7.667-7.333-16.667-11-27-11s-19.167,3.667-26.5,11s-11,'.
             ' 16.167-11,26.5s3.667,19.167,11,26.5     C86.333,201.333,95.167,205,105.5,205z"/>'.
            '<path d="M512,258v-50c0-8-2.833-14.5-8.5-19.5c-5.67-5-12.837-8.167-21.5-9.5l-297-29h-2 c-5.333,0-9.833,1.833-13.5,5.5s-5.5,8.167-5.5,13.5v58H88c-12.667,0-19,5.167-19,'.
            '  15.5S75.333,258,88,258H512z"/></g></g>';
    $ret .=  '</svg>';
   
   return $ret 
 }          
            
#########################################################################################
#
# YAAHM_timewidget - returns SVG code for inclusion into any room page
#
# Parameter name = name of the YAAHM definition
#
#########################################################################################

sub YAAHM_timewidget($){
  my ($arg) = @_;
  my $name = $FW_webArgs{name};
  $name    =~ s/'//g;
  
  my $sz = ($FW_webArgs{size} ? $FW_webArgs{size} : '400x400');
  $sz    =~ s/'//g;
  my @size=split('x',$sz);
  
  $FW_RETTYPE = "image/svg+xml";
  $FW_RET="";
  FW_pO '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 800" width="'.$size[0].'px" height="'.$size[1].'px">';
 
  my $hash = $defs{$name};	         
  my $radius    = 250;
  
  my ($sec, $min, $hour, $day, $month, $year, $wday,$yday,$isdst) = localtime(time);
  my $t_now      = sprintf("%02d:%02d",$hour,$min);
  my $a_now  = (60*$hour + $min)/1440 * 2 * pi;
  my $x_now  = -int(sin($a_now)*$radius*100)/100;
  my $y_now  =  int(cos($a_now)*$radius*100)/100;
  
  my $t_sunrise  = defined($hash->{DATA}{"DD"}[0]{"sunrise"}) ? $hash->{DATA}{"DD"}[0]{"sunrise"} : "06:00";
  $t_sunrise     =~ s/^0//;
  ($hour,$min) = split(":",$t_sunrise);
  my $sr         = $hour + $min*60;
  my $a_sunrise  = (60*$hour + $min)/1440 * 2 * pi;
  my $x_sunrise  = -int(sin($a_sunrise)*$radius*100)/100;
  my $y_sunrise  =  int(cos($a_sunrise)*$radius*100)/100;
  
  my $t_morning  = defined($hash->{DATA}{"DT"}{"morning"}[0]) ? $hash->{DATA}{"DT"}{"morning"}[0] : "08:00";
  $t_morning     =~ s/^0//;
  ($hour,$min) = split(":",$t_morning);
  my $mo         = $hour + $min*60;
  my $a_morning  = (60*$hour + $min)/1440 * 2 * pi;
  my $x_morning  = -int(sin($a_morning)*$radius*100)/100;
  my $y_morning  =  int(cos($a_morning)*$radius*100)/100;
  
  my $t_noon  = defined($hash->{DATA}{"DT"}{"noon"}[0]) ? $hash->{DATA}{"DT"}{"noon"}[0] : "12:00";
  $t_noon     =~ s/^0//;
  ($hour,$min) = split(":",$t_noon);
  my $a_noon  = (60*$hour + $min)/1440 * 2 * pi;
  my $x_noon  = -int(sin($a_noon)*$radius*100)/100;
  my $y_noon  =  int(cos($a_noon)*$radius*100)/100;
  
  my $t_afternoon  = defined($hash->{DATA}{"DT"}{"afternoon"}[0]) ? $hash->{DATA}{"DT"}{"afternoon"}[0] : "14:00";
  $t_afternoon     =~ s/^0//;
  ($hour,$min) = split(":",$t_afternoon);
  my $a_afternoon  = (60*$hour + $min)/1440 * 2 * pi;
  my $x_afternoon  = -int(sin($a_afternoon)*$radius*100)/100;
  my $y_afternoon  =  int(cos($a_afternoon)*$radius*100)/100;
  
  my $t_sunset  = defined($hash->{DATA}{"DD"}[0]{"sunset"}) ? $hash->{DATA}{"DD"}[0]{"sunset"} : "18:00";
  $t_sunset     =~ s/^0//;
  ($hour,$min) = split(":",$t_sunset);
  my $ss         = $hour + $min*60;
  my $a_sunset  = (60*$hour + $min)/1440 * 2 * pi;
  my $x_sunset  = -int(sin($a_sunset)*$radius*100)/100;
  my $y_sunset  =  int(cos($a_sunset)*$radius*100)/100;
    
  my $t_evening  = defined($hash->{DATA}{"DT"}{"evening"}[0]) ? $hash->{DATA}{"DT"}{"evening"}[0] : "19:00";
  $t_evening     =~ s/^0//;
  ($hour,$min) = split(":",$t_evening);
  my $ev         = $hour + $min*60;
  my $a_evening  = (60*$hour + $min)/1440 * 2 * pi;
  my $x_evening  = -int(sin($a_evening)*$radius*100)/100;
  my $y_evening  =  int(cos($a_evening)*$radius*100)/100;
  
  my $t_night  = defined($hash->{DATA}{"DT"}{"night"}[0]) ? $hash->{DATA}{"DT"}{"night"}[0] : "22:00";
  $t_night     =~ s/^0//;
  ($hour,$min) = split(":",$t_night);
  my $a_night  = (60*$hour + $min)/1440 * 2 * pi;
  my $x_night  = -int(sin($a_night)*$radius*100)/100;
  my $y_night  =  int(cos($a_night)*$radius*100)/100;
  
  my $t_midnight  = "0:00";
  $t_midnight     =~ s/^0//;
  ($hour,$min) = split(":",$t_midnight);
  my $a_midnight  = 0.0;
  my $x_midnight  = 0.0;
  my $y_midnight  = $radius;
  FW_pO  '<defs>'.
         sprintf('<linearGradient id="grad1" x1="0%%" y1="0%%" x2="%d%%" y2="%d%%">',int(-$x_noon/$radius*100),int(-$y_noon/$radius*100)).
         '<stop offset="0%" style="stop-color:rgb(255,255,0);stop-opacity:1" />'.
         '<stop offset="100%" style="stop-color:rgb(255,100,0);stop-opacity:1" />'.
         '</linearGradient>'.
           sprintf('<linearGradient id="grad2" x1="%d%%" y1="%d%%" x2="0%%" y2="0%%">',int(-$x_noon/$radius*100),int(-$y_noon/$radius*100)).
         '<stop offset="0%" style="stop-color:rgb(70,70,100);stop-opacity:1" />'.
         '<stop offset="100%" style="stop-color:rgb(255,150,0);stop-opacity:1" />'.
         '</linearGradient>'.
           sprintf('<linearGradient id="grad3" x1="%d%%" y1="%d%%" x2="0%%" y2="0%%">',int(-$x_noon/$radius*100),int(-$y_noon/$radius*100)).
         '<stop offset="0%" style="stop-color:rgb(80,80,80);stop-opacity:1" />'.
         '<stop offset="100%" style="stop-color:rgb(120,120,100);stop-opacity:1" />'.
         '</linearGradient>'.
         '</defs>';
	         
  FW_pO      '<g id="Ebene_1" transform="translate(400,400)">';
  
  #-- daytime arc
  FW_pO      '<path d="M 0 0 '.($x_morning*1.1).' '.($y_morning*1.1). ' A '.($radius*1.1).' '.($radius*1.1).' 0 1 1 '.($x_night*1.1).' '.($y_night*1.1).' Z" fill="none" stroke="rgb(0,255,200)" stroke-width="15" />';
  
  #-- sunset to sunrise sector. We need a workaround here for the broken SVG engine of Firefox, splitting this in two arcs
  FW_pO 	 '<path d="M 0 0 '.$x_sunset.  ' '.$y_sunset.   ' A '.$radius.' '.$radius.' 0 0 1 '.$x_midnight.' '.$y_midnight.' Z" fill="rgb(70,70,100)"/>'; 
  FW_pO 	 '<path d="M 0 0 '.$x_midnight.' '.$y_midnight. ' A '.$radius.' '.$radius.' 0 0 1 '.$x_sunrise.' '. $y_sunrise. ' Z" fill="rgb(70,70,100)"/>'; 
    
  #-- sunrise to morning sector
  my $dir = ( $sr < $mo ) ? 0 : 1;
  FW_pO 	 '<path d="M 0 0 '.$x_sunrise.' '.$y_sunrise.' A '.$radius.' '.$radius.' 0 0 '.$dir.' '.$x_morning.' '.$y_morning.' Z" fill="url(#grad2)"/>';
  
  #-- morning to evening sector
  FW_pO 	 '<path d="M 0 0 '.$x_morning.' '.$y_morning.' A '.$radius.' '.$radius.' 0 0 1 '.$x_evening.' '.$y_evening.' Z" fill="url(#grad1)"/>';
  
  #-- evening to sunset sector
  $dir = ( $ss > $ev ) ? 1 : 0;
  FW_pO 	 '<path d="M 0 0 '.$x_evening.' '.$y_evening.' A '.$radius.' '.$radius.' 0 0 '.$dir.' '.$x_sunset.' '.$y_sunset.' Z" fill="url(#grad2)"/>';
  
  #-- midnight line
  FW_pO 	 '<line x1="0" y1="0" x2="0" y2="'.($radius*1.2).'" style="stroke:rgb(75, 75, 75);stroke-width:2" />';
  FW_pO      '<text x="-30" y="'.($radius*1.25).'" fill="rgb(75, 75, 75)" style="font-family:Helvetica;font-size:36px;font-weight:bold">0:00</text>';
  
  #--sunrise line
  FW_pO 	 '<line x1="0" y1="0" x2="'.($x_sunrise*1.2).'" y2="'.($y_sunrise*1.2).'" style="stroke:rgb(75, 75, 75);stroke-width:2" />';
  FW_pO      '<text x="'.($x_sunrise*1.25-30).'" y="'.($y_sunrise*1.25).'" fill="rgb(75, 75, 75)" style="font-family:Helvetica;font-size:36px;font-weight:bold">'.$t_sunrise.'</text>';
  
  #--morning line
  FW_pO 	 '<line x1="0" y1="0" x2="'.($x_morning*1.2).'" y2="'.($y_morning*1.2).'" style="stroke:rgb(75, 75, 75);stroke-width:2" />';
  FW_pO      '<text x="'.($x_morning*1.25-30).'" y="'.($y_morning*1.25).'" fill="rgb(75, 75, 75)" style="font-family:Helvetica;font-size:36px;font-weight:bold">'.$t_morning.'</text>';
  
  #--noon line
  FW_pO 	 '<line x1="0" y1="0" x2="'.($x_noon*1.2) .'" y2="'.($y_noon*1.2) .'" style="stroke:rgb(75, 75, 75);stroke-width:2" />';
  FW_pO      '<text x="'.($x_noon*1.25).'" y="'.($y_noon*1.25).'" fill="rgb(75, 75, 75)" style="font-family:Helvetica;font-size:36px;font-weight:bold">'.$t_noon.'</text>';
  
  #--afternoon line
  FW_pO 	 '<line x1="0" y1="0" x2="'.($x_afternoon*1.2) .'" y2="'.($y_afternoon*1.2) .'" style="stroke:rgb(75, 75, 75);stroke-width:2" />';
  FW_pO      '<text x="'.($x_afternoon*1.25).'" y="'.($y_afternoon*1.25).'" fill="rgb(75, 75, 75)" style="font-family:Helvetica;font-size:36px;font-weight:bold">'.$t_afternoon.'</text>';
  
  #--sunset line
  FW_pO 	 '<line x1="0" y1="0" x2="'.($x_sunset*1.2) .'" y2="'.($y_sunset*1.2) .'" style="stroke:rgb(75, 75, 75);stroke-width:2" />';
  FW_pO      '<text x="'.($x_sunset*1.25).'" y="'.($y_sunset*1.25).'" fill="rgb(75, 75, 75)" style="font-family:Helvetica;font-size:36px;font-weight:bold">'.$t_sunset.'</text>';
  
  #--evening line
  FW_pO 	 '<line x1="0" y1="0" x2="'.($x_evening*1.2) .'" y2="'.($y_evening*1.2) .'" style="stroke:rgb(75, 75, 75);stroke-width:2" />';
  FW_pO      '<text x="'.($x_evening*1.25).'" y="'.($y_evening*1.25).'" fill="rgb(75, 75, 75)" style="font-family:Helvetica;font-size:36px;font-weight:bold">'.$t_evening.'</text>';
  
  #--night line
  FW_pO 	 '<line x1="0" y1="0" x2="'.($x_night*1.2) .'" y2="'.($y_night*1.2) .'" style="stroke:rgb(75, 75, 75);stroke-width:2" />';
  FW_pO      '<text x="'.($x_night*1.25).'" y="'.($y_night*1.25).'" fill="rgb(75, 75, 75)" style="font-family:Helvetica;font-size:36px;font-weight:bold">'.$t_night.'</text>';
  
  #--now line
  FW_pO 	 '<line x1="0" y1="0" x2="'.($x_now*1.2) .'" y2="'.($y_now*1.2) .'" style="stroke:rgb(255,0,0);stroke-width:4" />';
  FW_pO      '<text x="'.($x_now*1.25).'" y="'.($y_now*1.25).'" fill="rgb(255,0,0)" style="font-family:Helvetica;font-size:36px;font-weight:bold">'.$t_now.'</text>';
  
  
  FW_pO      '</g>';
  FW_pO      '</svg>';
  return ($FW_RETTYPE, $FW_RET);
}

#########################################################################################
#
# YAAHM_toptable - returns incomplete HTML code for inclusion into any room page
#                  (action and overview fields)
# 
# Parameter name = name of the YAAHM definition
#
#########################################################################################

sub YAAHM_toptable($){
	my ($name) = @_; 

    my $hash = $defs{$name};
    
    if( !defined($yaahm_tt) ){
      #-- readjust language
      my $lang = AttrVal("global","language","EN");
      if( $lang eq "DE"){
        $yaahm_tt = \%yaahm_transtable_DE;
      }else{
        $yaahm_tt = \%yaahm_transtable_EN;
      }
    }
    
    #-- something's rotten in the state of denmark
    my $st = $hash->{DATA}{"DD"}[0]{"sunrise"};
    my $ts;
    my ($styl,$stym,$styr);
    my $ret = "";
    ###YAAHM_GetDayStatus($hash);
    #--
    my $lockstate = ($hash->{READINGS}{lockstate}{VAL}) ? $hash->{READINGS}{lockstate}{VAL} : "unlocked";
    my $showhelper = ($lockstate eq "unlocked") ? 1 : 0; 
    
    %dailytable = %{$hash->{DATA}{"DT"}};
    
    #-- number of action devices
    my $devactno;
    my @actdevlist;
    my $avl  = AttrVal($name,"deviceActions",undef);
    if( !$avl){
      $devactno = 0;
    }else{
      @actdevlist = split(',',$avl);
      $devactno=int(@actdevlist);
    }
    
    #-- temporary code to rewrite deviceactions array into a hash
    my $xt = $hash->{DATA}{"XT"};
    if( ref $xt eq ref {}){
    }else{
      Log 1,"[Temporary code] changing XT array into hash";
      my %xtn={};
      for(my $i=0;$i<$devactno;$i++){
        my $dea=$actdevlist[$i];
        my %deb=%{$hash->{DATA}{"XT"}[$i]};
        #Log 1,"++++> Transferring key $dea";
        $xtn{$dea}=\%deb;
      }
      $hash->{DATA}{"XT"}=\%xtn;
    }
    
    my $dailyno    = scalar keys %dailytable;
    my $weeklyno   = int( @{$hash->{DATA}{"WT"}} );
    
    #--
    $ret .= "<script type=\"text/javascript\" src=\"$FW_ME/pgm2/yaahm.js\"></script><script type=\"text/javascript\">\n";
    
    $ret .= "var csmode = [\"".$csmode[0]."\",\"".$csmode[1]."\",\"".$csmode[2]."\",\"".$csmode[3]."\"];";
    $ret .= "var csstate = [\"".$csstate[0]."\",\"".$csstate[1]."\",\"".$csstate[2]."\",\"".$csstate[3]."\"];";
    
    $ret .= "var blinking = 0;\n";
    $ret .= "var hscolor = \"".$csstate[0]."\";\n";
    
    $ret .= "var devactno    = ".$devactno.";\n";
    
    $ret .= "var dailyno     = ".$dailyno.";\n";
    $ret .= "var dailykeys   = [\"".join("\",\"",(sort YAAHM_dsort keys %dailytable))."\"];\n";
    
    $ret .= "var weeklyno    = ".$weeklyno.";\n"; 
    $ret .= "var weeklykeys  = [\"".join("\",\"",@weeklytable)."\"];\n";  # Day names !!!
    $ret .= "var weeklynames = [";
    for( my $i=0;$i<$weeklyno;$i++){ 
      $ret .= ","
        if( $i!=0 );
      $ret .= "\"".$hash->{DATA}{"WT"}[$i]{"name"}."\"";
    } 
    $ret .= "];\n";
    
    #-- watcher for next hidden divisions
    for( my $i=2;$i<$weeklyno;$i++){ 
      $ret .= "\$(\"body\").on('DOMSubtreeModified', \"#wt".$i."_o\",function () {nval = document.getElementById(\"wt".$i."_o\").innerHTML;document.getElementById(\"wt".$i."_n\").value = nval;})\n";
    }
    $ret .= "</script>\n";
  
    $ret .= "<div informId=\"$name-housestate\" style=\"display:none\" id=\"hid_hs\">".ReadingsVal($name,"housestate",undef)."</div>".
            "<div informId=\"$name-housemode\" style=\"display:none\" id=\"hid_hm\">".ReadingsVal($name,"housemode",undef)."</div>";
            
    #-- formats for table borders
    my ($stopleft,$stopmid,$stopright,$sbotleft,$sbotmid,$sbotright,$smidleft,$smidmid,$smidright,$saround);
    $stopleft = "border-left:1px solid gray;border-top:1px solid gray;border-top-left-radius:10px;border-top-right-radius:0px;border-bottom-left-radius:0px;";  
    $stopmid  = "border-top:1px solid gray;border-radius:0px;";
    $stopright= "border-right:1px solid gray;border-top:1px solid gray;border-top-right-radius:10px;border-top-left-radius:0px;border-bottom-right-radius:0px;";
    $sbotleft = "border-left:1px solid gray;border-bottom:1px solid gray;border-bottom-left-radius:10px;border-bottom-right-radius:0px;border-top-left-radius:0px;";
    $sbotmid  = "border-bottom:1px solid gray;border-radius:0px;";
    $sbotright= "border-right:1px solid gray;border-bottom:1px solid gray;border-bottom-right-radius:10px;border-top-right-radius:0px;border-bottom-left-radius:0px;";
    $smidleft = "border-left:1px solid gray;border-radius:0px;";
    $smidmid  = "border:none";
    $smidright= "border-right:1px solid gray;border-radius:0px;";
    $saround  = "padding:5px;vertical-align:top;border:1px solid gray;border-radius:10px;";
                   
    ### main table ############################################################################################ 
    $ret .= "<table class=\"roomoverview\">\n";
   
    ### action ################################################################################################
    #   spanning 3 cols of main table
    $ret .= "<tr><td colspan=\"3\"><div class=\"devType\" style=\"font-weight:bold\">".$yaahm_tt->{"action"}.
      "</div> <div informId=\"$name-tr_errmsg\" class=\"devType\" style=\"font-weight:normal\">".ReadingsVal($name,"tr_errmsg",undef)."</div></td></tr>\n";
    
    #-- mode/state table, spanning 3 cols of main table
    my $cols = max(max(int(@modes),int(@states)),$weeklyno);
    $ret .= "<tr><td colspan=\"3\" style=\"align:left\"><table class=\"readings\" style=\"border:1px solid gray;border-radius:10px\">".
            "<tr><td rowspan=\"2\" height=\"40\" valign=\"bottom\" id=\"wid_hm\">".YAAHM_modewidget($hash)."</td><td colspan=\"5\" height=\"20\"></td></tr>".
            "<tr class=\"odd\"><td width=\"100px\" class=\"dname\" style=\"padding:5px;\">".$yaahm_tt->{"mode"}."</td>".
            "<td width=\"120px\"><div class=\"dval\" informId=\"$name-tr_housemode\">".ReadingsVal($name,"tr_housemode",undef)."</div></td><td></td>";
            for( my $i=0; $i<$cols; $i++){
              if( $i < int(@modes)){
                $ret .= "<td width=\"120px\"><input type=\"button\" id=\"b_".$modes[$i]."\" value=\"".$yaahm_tt->{$modes[$i]}.
                        "\" style=\"width:120px;\" onclick=\"javascript:yaahm_mode('$name','".$modes[$i]."')\"/></td>";
              }else{
                $ret .= "<td width=\"120px\"></td>";
              }
            }
    $ret .= "</tr>";
    $ret .= "<tr class=\"even\"><td rowspan=\"2\" height=\"40\" id=\"wid_hs\">".YAAHM_statewidget($hash)."</td>".
            "<td class=\"dname\" style=\"padding:5px;\">".$yaahm_tt->{"state"}."</td>".
            "<td><div informId=\"$name-tr_housestate\">".ReadingsVal($name,"tr_housestate",undef).
            "</div></td><td style=\"width:20px\"><div id=\"sym_hs\" informId=\"$name-sym_housestate\" style=\"align:center\">".ReadingsVal($name,"sym_housestate",undef)."</div></td>";
            for( my $i=0; $i<$cols; $i++){
              if( $i < int(@states)){
                $ret .= "<td width=\"120px\"><input type=\"button\" id=\"b_".$states[$i]."\" value=\"".$yaahm_tt->{$states[$i]}.
                        "\" style=\"width:120px;\" onclick=\"javascript:yaahm_state('$name','".$states[$i]."')\"/></td>";
              }else{
                $ret .= "<td width=\"120px\"></td>";
              }
            }
            #style=\"height:20px;border-bottom: 10px solid #333333;background-image: linear-gradient(#e5e5e5,#ababab);\"
    $ret .= "</tr><td colspan=\"5\" height=\"20\"></td></tr>";
    $ret .= "</table><br/>";
    
    #-- manual next time table, just below mode/state table
    $ret .= "<table class=\"readings\">";   
    my $nval  = "";
    my $wupn;
    $ret .= "<tr class=\"odd\"><td class=\"col1\" style=\"padding:5px; border-left: 1px solid gray; border-top:1px solid gray; border-bottom:1px solid gray; border-bottom-left-radius:10px; border-top-left-radius:10px;\">".$yaahm_tt->{"manual"}."</td>\n";
    for (my $i=0;$i<$weeklyno;$i++){
      if($i<$weeklyno-1){
        $styl= "border-bottom:1px solid gray;border-top:1px solid gray";
      }else{
        $styl= "border-bottom:1px solid gray;border-top:1px solid gray;border-right:1px solid gray;border-bottom-right-radius:10px;border-top-right-radius:10px";
      }
      $wupn = $hash->{DATA}{"WT"}[$i]{"name"};
      $nval = ( defined($hash->{DATA}{"WT"}[$i]{"next"}) ) ? $hash->{DATA}{"WT"}[$i]{"next"} : "";
      $ret .= sprintf("<td class=\"col2\" style=\"text-align:left;padding:5px;padding-left:10px;padding-right:10px;$styl\">$wupn<br/>".
              "<div style=\"display:none\" id=\"wt%d_o\" informId=\"$name-next_$i\">$nval</div><input type=\"text\" id=\"wt%d_n\" size=\"4\" maxlength=\"120\" value=\"$nval\" onchange=\"javascript:yaahm_setnext('$name',%d)\"/></td>\n",$i,$i,$i);
    }
    $ret .= "</tr>\n";
    $ret .= "</table><br/></td></tr>";
    
    ### daily overview ################################################################################################
    #   spanning 3 cols of main table
     $ret .= "<tr><td colspan=\"3\"><div class=\"devType\" style=\"font-weight:bold\">".$yaahm_tt->{"overview"}."</div></td></tr>\n";   
    #-- widget/state table, spanning 2 cols of main table
    $ret .= "<tr><td colspan=\"2\"><table>";
    
    #-- time widget  
    $ret .= "<tr><td rowspan=\"8\" width=\"200\" style=\"padding-right:50px\"><img src=\"/fhem/YAAHM_timewidget?name='".$name."'&amp;size='200x200'\" type=\"image/svg+xml\" ></td>";
    
    #-- continue summary with headers
    $ret .= "<td colspan=\"2\" width=\"150\" style=\"$stopleft\"></td><td width=\"120\" style=\"$stopmid\">".$yaahm_tt->{"today"}."</td><td width=\"120\" style=\"$stopright\">".$yaahm_tt->{"tomorrow"}."</td>";
    
    ### device states inserted as new td spanning 8 rows ####################################################################################
    $ret .= "<td rowspan=\"8\" style=\"$saround\"><table><tr><td height=\"20px\"><b>".
            $yaahm_tt->{"state"}."</b></td></tr><tr><td height=\"20px\">".
            "<div class=\"dval\" informId=\"$name-tr_housestate\">".ReadingsVal($name,"tr_housestate",undef)."</div></td></tr><tr><td>&#x2192;".
            $yaahm_tt->{"secstate"}."<div class=\"dval\" informId=\"$name-sdev_housestate\">".ReadingsVal($name,"sdev_housestate","")."</div></td></tr></table></td>";
            
    ### device action table inserted as new td spanning 10 rows ################################################################################################
    if( $avl ){   
      my ($dea,$dev,$tim);
      $ret .= sprintf("<td rowspan=\"%d\" style=\"$saround\"><table>",$weeklyno+8);
      $ret .= "<tr><td class=\"col1\" height=\"20\"><b>".$yaahm_tt->{"deviceactions"}."</b></td>";
      $ret .= "<td class=\"col2\"></td>";
      $ret .= "<td class=\"col2\"></td></tr>";
      for( my $i=0;$i<$devactno;$i++){
      
        #-- timer status
        my $ts;
        if( defined($defs{$name.".xtimer_".$i.".IF"})){
          if( ReadingsVal($name.".xtimer_".$i.".IF","state","") ne "inactive" ){
            $ts = "<div style=\"color:green\">&#x2713;</div>";
          }else{
            $ts = "<div style=\"color:red\">&#x274c;</div>";
          }
        }else{
          $ts = "";
        }   
        $dea  = $actdevlist[$i];
        $dev  = $hash->{DATA}{"XT"}{$dea}{"name"};   
        Log3 $name,1,"[YAAHM_toptable] key $dea not equal to name $dev"
          if( $dea ne $dev); 
        $ret .= "<tr><td class=\"col1\" height=\"20\" style=\"padding-right:5px\">".$dev."</td>";
        $ret .= "<td class=\"col2\" style=\"padding:5px;\">$ts</td></tr>";
      }
    
      $ret .= "</table></td>";
    }        
    $ret .= "</tr>\n";

    ### next lines of state summary ########################################################
    $ret .= "<tr><td colspan=\"2\" style=\"$smidleft\"></td><td style=\"padding:5px;$smidmid\">".$yaahm_tt->{$weeklytable[$hash->{DATA}{"DD"}[0]{"weekday"}]}[0] .         
                                  "</td><td style=\"padding:5px;$smidright\">".$yaahm_tt->{$weeklytable[$hash->{DATA}{"DD"}[1]{"weekday"}]}[0]."</td></tr>"; 
    #-- continue summary with entries
    $ret .= "<tr><td colspan=\"2\" style=\"$smidleft\"></td><td style=\"padding:5px;$smidmid\">".$hash->{DATA}{"DD"}[0]{"date"}.         
                                  "</td><td style=\"padding:5px;$smidright\">".$hash->{DATA}{"DD"}[1]{"date"}."</td></tr>\n";
    $ret .= "<tr><td colspan=\"2\" class=\"dname\" style=\"padding:5px;$smidleft\">".$yaahm_tt->{"daylight"}."</td><td style=\"padding:5px;$smidmid\">".$hash->{DATA}{"DD"}[0]{"sunrise"}."-".$hash->{DATA}{"DD"}[0]{"sunset"}.         
                                  "</td><td style=\"padding:5px;$smidright\">".$hash->{DATA}{"DD"}[1]{"sunrise"}."-".$hash->{DATA}{"DD"}[1]{"sunset"}."</td></tr>\n";
    $ret .= "<tr><td colspan=\"2\" class=\"dname\" style=\"padding:5px;$smidleft\">".$yaahm_tt->{"daytime"}."</td><td style=\"padding:5px;$smidmid\">".$hash->{DATA}{"DT"}{"morning"}[0]."-".
                                   $hash->{DATA}{"DT"}{"night"}[0]."</td><td style=\"$smidright\"></td></tr>\n";
    $ret .= "<tr><td colspan=\"2\" class=\"dname\" style=\"padding:5px;$smidleft\">".$yaahm_tt->{"daytype"}."</td><td style=\"padding:5px;$smidmid\">".$yaahm_tt->{$hash->{DATA}{"DD"}[0]{"daytype"}}[0].         
                                                         "</td><td style=\"padding:5px;$smidright\">".$yaahm_tt->{$hash->{DATA}{"DD"}[1]{"daytype"}}[0]."</td></tr>\n";
    $ret .= "<tr><td colspan=\"2\" class=\"dname\" style=\"padding:5px;$smidleft\">".$yaahm_tt->{"description"}."</td><td style=\"padding:5px;$smidmid\">".$hash->{DATA}{"DD"}[0]{"desc"}.                         
                                                                "</td><td style=\"padding:5px;width:100px;$smidright\">".$hash->{DATA}{"DD"}[1]{"desc"}."</td></tr>\n";                                                           
    $ret .= "<tr><td colspan=\"2\" class=\"dname\" style=\"padding:5px;$sbotleft\">".$yaahm_tt->{"date"}."</td><td style=\"padding:5px;width:100px;$sbotmid\">".$hash->{DATA}{"DD"}[0]{"special"}.                         
                                                                "</td><td style=\"padding:5px;width:100px;$sbotright\">".$hash->{DATA}{"DD"}[1]{"special"}."</td></tr>\n";
                                                                
    #-- housetime/phase
    $ret .= "<tr><td rowspan=\"".$weeklyno."\" style=\"text-align:center; white-space:nowrap;max-height:20px\">".
            "<label><div class=\"dval\" informId=\"$name-tr_housetime\">".ReadingsVal($name,"tr_housetime","").
            "</div>&nbsp;<div class=\"dval\" informId=\"$name-tr_housephase\">".ReadingsVal($name,"tr_housephase","")."</div></label></td>";
   
    #-- weekly timers
    for( my $i=0;$i<$weeklyno;$i++ ){
      $wupn  = $hash->{DATA}{"WT"}[$i]{"name"};
    
      #-- timer status
      if( defined($defs{$name.".wtimer_".$i.".IF"})){
        if( ReadingsVal($name.".wtimer_".$i.".IF","mode","") ne "disabled" ){
          $ts = "<div style=\"color:green\">&#x2713;</div>";
        }else{
          $ts = "<div style=\"color:red\">&#x274c;</div>";
        }
      }else{
        $ts = "";
      }   

      #-- ring times
      my $ring_0x   = $hash->{DATA}{"WT"}[$i]{"ring_0x"}; 
      my $ring_1x   = $hash->{DATA}{"WT"}[$i]{"ring_1x"};
      my $wake      = $hash->{DATA}{"WT"}[$i]{"wake"};
      
      #-- border styles
      if( $i==0 ){
        $styl=$stopleft;
        $stym=$stopmid;
        $styr=$stopright;
      }elsif( $i == $weeklyno-1 ){
        $styl=$sbotleft;
        $stym=$sbotmid;
        $styr=$sbotright;
      }else{
        $styl=$smidleft;
        $stym=$smidmid;
        $styr=$smidright;
      }  
      $ret.="<td style=\"padding:5px;$styl\">".$wupn.
            "</td><td style=\"text-align:center;width:30px;padding:5px;$stym\">$ts</td>".
            "<td style=\"padding:5px;$stym\"><div class=\"dval\" informId=\"$name-ring_".$i."x\">".$ring_0x."</div></td>".
            "<td style=\"padding:5px;$stym\"><div class=\"dval\" informId=\"$name-ring_".$i."_1x\">".$ring_1x."</div></td>".
            "<td style=\"padding:5px;$styr\"><div class=\"dval\" informId=\"$name-tr_wake_$i\">".$wake."</div></td></tr>\n";
    }
    $ret .= "</table></td></tr>\n";
    
    return $ret;
    
 }

#########################################################################################
#
# YAAHM_Shorttable - returns complete HTML code for inclusion into any room page
#                  (action and overview fields)
# 
# Parameter name = name of the YAAHM definition
#
#########################################################################################

sub YAAHM_Shorttable($){
    my ($name) = @_; 

    my $ret = YAAHM_toptable($name);
    
    #-- complete the code of the page
    $ret .= "</table>";
    InternalTimer(gettimeofday()+ 1, "YAAHM_informer", $defs{$FW_cname},0);
    return $ret;
}

#########################################################################################
#
# YAAHM_Longtable - returns complete HTML code for the full YAAHM page
#              (action, overview, daily and weekly profile)
# 
# Parameter name = name of the YAAHM definition
#
#########################################################################################

sub YAAHM_Longtable($){
	my ($name) = @_; 

    my $ret = "";
 
    my $hash = $defs{$name};
    my $id   = $defs{$name}{NR};
 
    #--
    my $lockstate = ($hash->{READINGS}{lockstate}{VAL}) ? $hash->{READINGS}{lockstate}{VAL} : "unlocked";
    my $showhelper = ($lockstate eq "unlocked") ? 1 : 0; 
    
    %dailytable = %{$hash->{DATA}{"DT"}};
    my $dailyno    = scalar keys %dailytable;
    my $weeklyno   = int( @{$hash->{DATA}{"WT"}} );

    #--
    $ret = YAAHM_toptable($name);
    
    ### device action table ################################################################################################
    my $avl  = AttrVal($name,"deviceActions",undef);
    if( $avl){
      $ret .= "<tr><td colspan=\"4\"><div class=\"devType\" style=\"font-weight:bold; white-space:nowrap;\">".$yaahm_tt->{"deviceaction"}.$yaahm_tt->{"profile"};
      $ret .= "&nbsp;&nbsp;<input type=\"button\" value=\"".$yaahm_tt->{"start"}." ".$yaahm_tt->{"deviceactions"}."\" onclick=\"javascript:yaahm_startDeviceAction('$name')\"/></td>\n";   
      $ret .= "<tr><td colspan=\"3\">\n";
   
      #-- number of action devices
      my $devactno;  
      my @actdevlist = split(',',$avl);
      $devactno=int(@actdevlist);
   
      my ($dea,$dev,$eval,$lval,$xval,$evt);
      my ($styl,$stym,$styr);
      $ret .= "<table class=\"block wide\" ><tr><td style=\"text-align:left;padding-left:5px\"><b>".$yaahm_tt->{"name"}."</b></td><td></td><td></td><td style=\"text-align:left;padding-left:5px\"><b>".$yaahm_tt->{"event"}."</b></td>";
      $ret .= "<td style=\"text-align:left;padding-left:5px\"><b>".$yaahm_tt->{"earliest"}."</b></td><td style=\"text-align:left;padding-left:5px\"><b>".$yaahm_tt->{"latest"}."</b></td><td style=\"text-align:left;padding-left:5px\"><b>".$yaahm_tt->{"action"}."</b></td></tr>";
      for( my $i=0;$i<$devactno;$i++){
        $dea  = $actdevlist[$i];
        $dev  = $hash->{DATA}{"XT"}{$dea}{"name"};
        #-- Here we may have a new and therefore empty deviceaction
        if( !defined($dev) || $dev eq "" ){ 
          $hash->{DATA}{"XT"}{$dea}{"name"}=$dea;
          $dev = $dea;
        }
        $evt  = $hash->{DATA}{"XT"}{$dea}{"event"};
        $eval = $hash->{DATA}{"XT"}{$dea}{"earliest"};
        $lval = $hash->{DATA}{"XT"}{$dea}{"latest"};
        $xval = $hash->{DATA}{"XT"}{$dea}{"cmd"};
      
        $ret .= sprintf("<tr><td class=\"col1\" style=\"text-align:left;padding-left:5px\"><label id=\"xt%d_n\">".$dev."</label></td>",$i);
        $ret .= "<td class=\"col2\" style=\"padding:5px;\"><a href=\"/fhem?detail=$name.xtimer_".$i.".IF\">$name.xtimer_".$i.".IF</a></td>";
        #-- timer status
        my $ts;
        if( defined($defs{$name.".xtimer_".$i.".IF"})){
          if( ReadingsVal($name.".xtimer_".$i.".IF","state","") ne "inactive" ){
            $ts = "<div style=\"color:green\">&#x2713;</div>";
          }else{
            $ts = "<div style=\"color:red\">&#x274c;</div>";
          }
        }else{
          $ts = "";
        }   
        $ret .= "<td class=\"col2\" style=\"padding:5px;\">$ts</td>";     
        $ret .= sprintf("<td><select id=\"xt%d_v\">",$i);

        my @keys = keys(%defaultdailytable);
        #-- iterate over daily times (including wakeup/sleep)
        for(my $j=0;$j<int(@keys);$j++){
          #if(  $keys[$j] !~ /(wakeu/ ){
            if( $keys[$j] eq $evt ){
              $ret .= "<option selected=\"selected\" value=\"".$keys[$j]."\">";
            }else{
              $ret .= "<option value=\"".$keys[$j]."\">"
            }
            $ret .= $yaahm_tt->{$keys[$j]}."</option>";
          #}
        }
        #-- iterate over timers
        #for( my $i=2;$i<int( @{$hash->{DATA}{"WT"}} );$i++){
        #  my $name = $hash->{DATA}{"WT"}[$i]{ "name" };
        #  if( $name eq $evt ){
        #    $ret .= "<option selected=\"selected\" value=\"".$name."\">";
        #  }else{
        #    $ret .= "<option value=\"".$name."\">"
        #  }
        #  $ret .= $name."</option>";
        #}
        
        $ret .= "</select></td>";
        $ret .= sprintf("<td class=\"col2\" style=\"text-align:left;padding-left:5px\"><input type=\"text\" id=\"xt%d_e\" size=\"4\" maxlength=\"120\" value=\"$eval\"/></td>",$i);
        $ret .= sprintf("<td class=\"col2\" style=\"text-align:left;padding-left:5px\"><input type=\"text\" id=\"xt%d_l\" size=\"4\" maxlength=\"120\" value=\"$lval\"/></td>",$i);
        $ret .= sprintf("<td class=\"col2\" style=\"text-align:left;padding-left:5px\"><input type=\"text\" id=\"xt%d_x\" size=\"30\" maxlength=\"512\" value=\"$xval\"/></td></tr>",$i);
      }
    
      $ret .= "</table></td></tr>";
    }
    
    ### daily profile table ################################################################################################
    my $row   = 1;
    my $event = "";
    my $sval  = "";
    my $eval  = "";
    my $xval  = "";
 
    my $dh = (defined($attr{$name}{"timeHelper"})) ? $attr{$name}{"timeHelper"} : undef;
    
    #-- global status of timer
    my ($tl,$ts);
    if( defined($defs{$name.".dtimer.IF"})){
      $tl = "<a href=\"/fhem?detail=$name.dtimer.IF\">$name.dtimer.IF</a>";
      #-- green hook
      if( ReadingsVal($name.".dtimer.IF","mode","") ne "disabled"  ){
        $ts = "<td style=\"color:green;padding-left:5px\">&#x2713;</td>\n";
      #-- red cross
      }else{
        $ts = "<td style=\"color:red;padding-left:5px\">&#x274c;</td>\n";
      }
    }else{
      $tl= $yaahm_tt->{"notstarted"};
      $ts ="<td></td>";
    }    
    
    #-- name link button status
    $ret .= "<tr><td colspan=\"3\"><div class=\"devType\" style=\"font-weight:bold; white-space:nowrap;\">".$yaahm_tt->{"daily"}.$yaahm_tt->{"profile"}."\n".
            "<table><tr><td style=\"text-align:center;vertical-align:middle;white-space:nowrap;padding-left:5px\"><div id=\"dtlink\" style=\"font-weight:normal\">$tl</div></td>$ts";
    $ret .= "<td style=\"vertical-align:middle;;padding-left:5px\"><input type=\"button\" value=\"".$yaahm_tt->{"start"}." ".$yaahm_tt->{"daily"}.$yaahm_tt->{"timer"}."\" onclick=\"javascript:yaahm_startDayTimer('$name')\"/></td>\n";
    $ret .= "</tr></table></div></td></tr>";            
    
    #-- header line             
    $ret .= "<tr><td colspan=\"3\"><table class=\"block wide\" id=\"dailytable\">\n"; 
    $ret .= "<tr style=\"font-weight:bold\"><td rowspan=\"2\" class=\"devType col1\" style=\"min-width:120px;\">".$yaahm_tt->{"event"}."</td><td class=\"devType,col2\" style=\"text-align:right;min-width:180px;white-space:nowrap;\">".
            $yaahm_tt->{"time"}." [hh:mm]&nbsp;&nbsp;&nbsp;</td>".
            "<td rowspan=\"2\" class=\"devType col3\" style=\"min-width:200px;\">".$yaahm_tt->{"action"}."</td>".
            "</tr>".
            "<tr style=\"font-weight:bold\"><td class=\"devType col2\" style=\"text-align:right\">Start/Offset&nbsp;&nbsp;&nbsp;End&nbsp;&nbsp;&nbsp;</td></tr>\n";
            
    #-- iterate through table        
    foreach my $key (sort YAAHM_dsort keys %dailytable){
      $row++;
      $event= $yaahm_tt->{$key};
      $sval = $dailytable{$key}[0];
      $eval = $dailytable{$key}[1];
      $xval = $dailytable{$key}[2];
      $xval = "" if( !defined($xval) );
      
      #--
      if( $dh ){
        #-- timeHelper not in command list
        if( $xval !~ /^{$dh/ ){
          if( defined($xval) && length($xval)>0 ){
            $xval ="{".$dh."('".$key."')},".$xval;
          }else{
            $xval ="{".$dh."('".$key."')}";
          }
        }
      }
      
      $ret .= sprintf("<tr class=\"%s\"><td class=\"col1\">$event</td>\n", ($row&1)?"odd":"even"); 
      #-- First field
      #-- Only reference for wakeup
      if( $key =~ /^wakeup.*/ ){
        $ret .= "<td class=\"col2\" style=\"text-align:left\">".$yaahm_tt->{"weekly"}.$yaahm_tt->{"profile"}."</td><td></td><td></td></tr>\n";
        next;
      #-- Only reference for sleep
      }elsif( $key =~ /^sleep.*/ ){
        $ret .= "<td class=\"col2\" style=\"text-align:left\">".$yaahm_tt->{"weekly"}.$yaahm_tt->{"profile"}."</td><td></td><td></td></tr>\n";
        next;
      #-- calculated value for sunrise/sunset
      }elsif( $key =~ /.*((sunrise)|(sunset)|(midnight)).*/ ){
        my $pre;
        if( $key =~ /.*sunrise.*/ ){
          $pre   = $hash->{DATA}{"DD"}[0]{"sunrise"}
        }elsif( $key =~ /.*sunset.*/ ){
          $pre   = $hash->{DATA}{"DD"}[0]{"sunset"}
        }else{
          $pre   = "00:00";
        }
        $ret    .= "<td class=\"col2\" style=\"text-align:right\">";
        if( $key =~ /.*before.*/ ){
          $ret .= "$pre - &nbsp;<input type=\"text\" id=\"dt".$key."_e\" size=\"4\" maxlength=\"120\" value=\"$eval\"/>&nbsp;=&nbsp;$sval&nbsp;&nbsp;&nbsp;&nbsp;</td>"
        }elsif( $key =~ /.*after.*/ ){
          $ret .= "$pre + &nbsp;<input type=\"text\" id=\"dt".$key."_e\" size=\"4\" maxlength=\"120\" value=\"$eval\"/>&nbsp;=&nbsp;$sval&nbsp;&nbsp;&nbsp;&nbsp;</td>"
        }else{
          $ret .= "$pre&nbsp;&nbsp;&nbsp;&nbsp;</td>"
        }
      #-- normal input of one time
      }else{
        $ret .= "<td class=\"col2\" style=\"text-align:right\"><input type=\"text\" id=\"dt".$key."_s\" size=\"4\" maxlength=\"120\" value=\"$sval\"/></td>";
      }
      #-- Second field 
      $ret .= "<td class=\"col3\"><input type=\"text\" id=\"dt".$key."_x\" size=\"28\" maxlength=\"512\" value=\"$xval\"/></td></tr>\n";
    }    
    $ret .= "</table></td></tr></tr>";
    
   ### weekly profile table ################################################################################################
    $row   = 1;
    $event = "";
    $sval  = "";
    my $asg   = "";
    my $ast   = "";
    my $ass;
    my $acc;
   
    #--header 
    my $wupn;    
    my $wt = ( $weeklyno == 1) ? $yaahm_tt->{"profile"} :$yaahm_tt->{"profiles"};
            
    $ret .= "<tr><td colspan=\"3\"><div class=\"devType\" style=\"font-weight:bold; white-space: nowrap;\">".$yaahm_tt->{"weekly"}.$wt.
            "&nbsp;&nbsp;<input type=\"button\" value=\"".$yaahm_tt->{"start"}." ".$yaahm_tt->{"weekly"}.$yaahm_tt->{"timer"}."\" onclick=\"javascript:yaahm_startWeeklyTimer('$name')\"/></div></td></tr>";  
            
    $ret .= "<tr><td><table class=\"block wide\" \" id=\"weeklytable\">\n"; 

    #-- repeat name for every weekly table  
    $ret .= "<tr class=\"odd\"><td class=\"col1\" style=\"font-weight:bold;text-align:left;padding:5px\">".$yaahm_tt->{"name"}."</td>";      
    for (my $i=0;$i<$weeklyno;$i++){
      $wupn = $hash->{DATA}{"WT"}[$i]{"name"};
      $ret .= "<td class=\"col2\" style=\"text-align:left;padding:5px\">$wupn</td>";
    }
    $ret .= "</tr>\n";

    #-- repeat link for every weekly table     
    $ret .= "<tr class=\"even\"><td class=\"col1\" style=\"font-weight:bold;text-align:left;padding:5px\">".$yaahm_tt->{"timer"}."</td>";  
    
    #-- timer status
    my $tss;    
    for (my $i=0;$i<$weeklyno;$i++){
      $wupn = $hash->{DATA}{"WT"}[$i]{"name"};
      #-- timer status
      if( defined($defs{$name.".wtimer_".$i.".IF"})){
        $tl = "<a href=\"/fhem?detail=".$name.".wtimer_".$i.".IF\">".$name.".wtimer_".$i.".IF</a>";
        if( ReadingsVal($name.".wtimer_".$i.".IF","mode","") ne "disabled" ){
          $tss="<div style=\"color:green\">&#x2713;</div>";
        }else{
          $tss="<div style=\"color:red\">&#x274c;</div>";
        }
      }else{
        $tl = $yaahm_tt->{"notstarted"};
        $tss= "";
      }   
      $ret .= sprintf("<td class=\"col2\" style=\"text-align:left;padding:5px\"><div id=\"wt%dlink\">%s%s</div></td>",$i,$tl,$tss);
    }
    $ret .= "</tr>\n";
    
    #-- repeat action for every weekly table      
    $ret .= "<tr class=\"odd\"><td class=\"col1\" style=\"font-weight:bold;text-align:left;padding:5px\">".$yaahm_tt->{"action"}."</td>";
    for (my $i=0;$i<$weeklyno;$i++){
      $xval = $hash->{DATA}{"WT"}[$i]{"action"};
      #--
      if( $dh && $i<2 ){
        #-- timeHelper not in command list
        $wupn = ($i==0) ? "wakeup" : "sleep";
        if( $xval !~ /^{$dh/ ){
          if( defined($xval) && length($xval)>0 ){
            $xval ="{".$dh."('".$wupn."')},".$xval;
          }else{
            $xval ="{".$dh."('".$wupn."')}";
          }
        }
      }
      $ret .= sprintf("<td class=\"col2\" style=\"text-align:left;padding:5px\"><input class=\"expand\" type=\"text\" id=\"wt%d_x\" size=\"10\" maxlength=\"512\" value=\"$xval\"/></td>",$i);
    }
    $ret .= "</tr>\n";
    
    #-- specialday header  
    $ret .= "<tr class=\"even\"><td class=\"col1\" style=\"font-weight:bold;text-align:left;padding:5px\">".$yaahm_tt->{"daytype"}."</td>";
    for (my $i=0;$i<$weeklyno;$i++){
      $ret .= "<td class=\"col2\" style=\"text-align:left;padding:5px\">".$yaahm_tt->{"time"}." [hh:mm]</td>";
    }
    $ret .= "</tr>\n";
    
    #-- repeat specialday entry every weekly table         
    for (my $j=7;$j<9;$j++){
      my $key = $weeklytable[$j];
      $row++;
      $event  = $yaahm_tt->{$key}[0];

      $ret .= sprintf("<tr class=\"%s\"><td class=\"col1\" style=\"text-align:left;padding-left:5px\">$event</td>\n", ($row&1)?"odd":"even"); 
      for (my $i=0;$i<$weeklyno;$i++){
        $sval = $hash->{DATA}{"WT"}[$i]{$key};
        $sval = ""
          if(!$sval);
        #-- check if weekday profile active here or not
        $ass =  ( defined($hash->{DATA}{"WT"}[$i]{"acti_d"}) ) ? $hash->{DATA}{"WT"}[$i]{"acti_d"} : "";
        $acc = ( $ass =~ /.*$key.*/ ) ? "disabled=\"disabled\"" : "";
        $ret .= sprintf("<td class=\"col2\" style=\"text-align:left;padding-left:5px\"><input type=\"text\" id=\"wt%s%d_s\" size=\"4\" maxlength=\"120\" value=\"$sval\" $acc/></td>",$key,$i);
      }
      $ret .= "</tr>\n";
    }    
    
    #-- weekday header  
    $ret .= "<tr class=\"even\"><td class=\"col1\" style=\"font-weight:bold;text-align:left;padding:5px\">".$yaahm_tt->{"weekday"}."</td>";
    for (my $i=0;$i<$weeklyno;$i++){
      $ret .= "<td class=\"col2\" style=\"text-align:left;padding:5px\">".$yaahm_tt->{"time"}." [hh:mm]</td>";
    }
    $ret .= "</tr>\n";
    
    #-- checkboxes for every weekly table  
    for(my $i=0;$i<int(@profmode);$i++){
      $asg .= substr($yaahm_tt->{$profmode[$i]},0,3)."&nbsp;";
      $ast .= $yaahm_tt->{$profmode[$i]}." ";
    }
    for(my $i=0;$i<int(@profday);$i++){
      $asg .= $yaahm_tt->{$profday[$i]}[1]."&nbsp;";
      $ast .= $yaahm_tt->{$profday[$i]}." ";
    }
    $ret .= "<tr class=\"odd\"><td class=\"col1\" style=\"text-align:left;padding:5px\">".$yaahm_tt->{"active"}."<br/><div title=\".$ast.\" >".$asg."</div></td>";      
    for (my $i=0;$i<$weeklyno;$i++){
      $wupn = $hash->{DATA}{"WT"}[$i]{"name"};
      $ret .= "<td class=\"col2\" style=\"text-align:left;padding:5px\">";
    
      $asg = "";
      $ass =  ( defined($hash->{DATA}{"WT"}[$i]{"acti_m"}) ) ? $hash->{DATA}{"WT"}[$i]{"acti_m"} : "";
      for( my $j=0;$j<int(@profmode);$j++ ){
        $acc = $profmode[$j];
        $acc = ( $ass =~ /.*$acc.*/ ) ? " checked=\"checked\"" : "";
        $asg .= sprintf("<input type=\"checkbox\" name=\"acti_%d_m\" value=\"".$profmode[$j]."\" $acc/>&nbsp;",$i);
      }
      $ass =  ( defined($hash->{DATA}{"WT"}[$i]{"acti_d"}) ) ? $hash->{DATA}{"WT"}[$i]{"acti_d"} : "";
      for( my $j=0;$j<int(@profday);$j++ ){
        $acc = $profday[$j];
        $acc = ( $ass =~ /.*$acc.*/ ) ? " checked=\"checked\"" : "";
        $asg .= sprintf("<input type=\"checkbox\" name=\"acti_%d_d\" id=\"acti_%s%d_d\" value=\"".$profday[$j]."\" $acc onclick=\"yaahm_dtlogic(%d,'%s')\"/>&nbsp;",$i,$profday[$j],$i,$i,$profday[$j]);
      }
      $ret .= "$asg</td>";
    }
    $ret .= "</tr>\n";
    
    #-- repeat weekday entry every weekly table            
    for (my $j=0;$j<7;$j++){
      my $key = $weeklytable[$j];
      $row++;
      $event  = $yaahm_tt->{$key}[0];

      $ret .= sprintf("<tr class=\"%s\"><td class=\"col1\" style=\"text-align:left;padding-left:5px\">$event</td>\n", ($row&1)?"odd":"even"); 
      for (my $i=0;$i<$weeklyno;$i++){
        $sval = $hash->{DATA}{"WT"}[$i]{$key};
        $ret .= sprintf("<td class=\"col2\" style=\"text-align:left;padding-left:5px\"><input type=\"text\" id=\"wt%s%d_s\" size=\"4\" maxlength=\"120\" value=\"$sval\"/></td>",$key,$i);
      }
      $ret .= "</tr>\n";
    }    
    $ret .= "</table></td></tr>";
    
    #-- complete the code of the page
	$ret .= "</table>";
	#InternalTimer(gettimeofday()+ 3, "YAAHM_informer", $defs{$FW_cname},0);
 
 return $ret; 
}

1;

=pod
=item helper
=item summary admimistration of profiles for daily, weekly and monthly processes 
=item summary_DE Verwaltung von Profilen für tägliche, wöchentliche und monatliche Abläufe
=begin html

   <a name="YAAHM"></a>
        <h3>YAAHM</h3>
        <ul>
        <p> Yet Another Auto Home Module to set up a cyclic processing of commands (daily, weekly, monthly, yearly profile)</p>
          <a name="YAAHMusage"></a>
        <h4>Usage</h4>
        See <a href="http://www.fhemwiki.de/wiki/Modul_YAAHM">German Wiki page</a>
        <br/>
        <a name="YAAHMdefine"></a>
        <h4>Define</h4>
        <p>
            <code>define &lt;name&gt; YAAHM</code>
            <br />Defines the YAAHM system. </p>
        Notes: <ul>
        <li>This module uses the global attribute <code>language</code> to determine its output data<br/>
         (default: EN=english). For German output set <code>attr global language DE</code>.</li>
         <li>This module needs the JSON package</li>
         </ul>
        <a name="YAAHMset"></a>
        <h4>Set</h4>
        <ul>
             <li><a name="yaahm_time">
                    <code>set &lt;name&gt; time &lt;timeevent&gt;</code></a><br/>
                    Set the current house time (event), i.e. one of several values:
                    <ul>
                    <li>(after|before) midnight | [before|after] sunrise | [before|after] sunset are calculated from astronomical data (&pm;offset). 
                    These values vary from day to day, only the offset can be specified in the daily profile. </li>
                    <li>morning | noon | afternoon | evening | night are fixed time events specified in the daily profile. 
                    The time phase between events morning and night is called <i>daytime</i>, the 
                    time phase between events night and morning is called <i>nighttime</i></li>
                    <li>wakeup|sleep are time events specified in the weekly default profiles <i>Wakeup</i> and <i>Sleep</i>, i.e. the value may change from day to day.</li>
                    </ul>
                    The actual changes to certain devices are made by the functions in the command field, or by an external <a href="#yaahm_timehelper">timeHelper function</a>.
                  </li>
             <li><a name="yaahm_manualnext"></a>
                    <code>set &lt;name&gt; manualnext &lt;timernumber&gt; &lt;time&gt;</code><br/>
                    <code>set &lt;name&gt; manualnext &lt;timername&gt; &lt;time&gt;</code><br/>
                    For the weekly timer identified by its number (starting at 0) or its name, set the next ring time manually. The time specification &lt;time&gt;must be in the format hh:mm, or "off", or "default".
                    <ul>
                    <li>If the time specification &lt;time&gt; is later than the current time, it will be used for today. If it is earlier than the current time, it will be used tomorrow.</li>
                    <li>If the time specification is "off", the next pending waketime will be ignored.</li>
                   <li>If the time specification id "default", the manual waketime is removed and the value from the weekly schedule will be used.</li>
                   </ul>
                  </li>
             <li><a name="yaahm_mode">
                    <code>set &lt;name&gt; mode normal | party | absence | donotdisturb</code>
                </a>
                <br />Set the current house mode, i.e. one of several values:
                <ul>
                <li>normal - normal daily and weekly time profiles apply</li>
                <li>party - can be used in the timeHelper function to suppress certain actions, like e.g. those that set the house (security) state to <i>secured</i> or the house time event to <i>night</i>.</li>
                <li>absence - can be used in the timeHelper function to suppress certain actions. Valid until manual mode change</li>
                <li>donotodisturb - can be used in the timeHelper function to suppress certain actions. Valid until manual mode change</li>
                </ul>
                House modes are valid until manual mode change. If the attribute <i>modeAuto</i> is set (see below), mode will change automatically at certain time events.
                The actual changes to certain devices are made by an external <a href="#yaahm_modehelper">modeHelper function</a>.
                </li>   
              <li><a name="yaahm_state">
                    <code>set &lt;name&gt; state unsecured | secured | protected | guarded</code>
                </a>
                <br/>Set house (security) state, i.e. one of several values:
                  <ul>
                    <li> unsecured - Example: doors etc. 
                    </li>
                    <li> secured - Example: doors etc. are locked, windows may not be open
                    </li>
                    <li> protected - Example: doors etc. are locked, windows may not be open, alarm system is armed
                    </li>
                    <li> guarded - Example: doors etc. are locked, windows may not be open, alarm is armed, a periodic house check is run and a simulation as well
                    </li>
                  </ul>
                  House (security) states are valid until manual change. If the attribute <i>stateAuto</i> is set (see below), state will change automatically at certain times.
                  The actual changes to certain devices are made by an external <a href="#yaahm_statehelper">stateHelper function</a>. If these external devices are in their proper state 
                  for a particular house (security) state can be checked automatically, see the attribute  <a href="#yaahm_statedevices">stateDevices</a>
                </li>      
              <li><a name="yaahm_checkstate">
                    <code>set &lt;name&gt; checkstate 0|5|10</code>
                </a>
                <br/>Check the house (security) state for each of the devices defined in the stateDevices attribute in 0, 5 or 10 seconds from now</li>
              <li><a name="yaahm_correctstate">
                    <code>set &lt;name&gt; correctstate</code>
                </a>
                <br/>Try to correct the house (security) state, by issueing a FHEM command <i>set &lt;device&gt; &lt;targetstate&gt;</i> 
                for each of the devices defined in the stateDevices attribute and not in the proper state for the given house (security) state</li>
             <li><a name="yaahm_createweekly">
                    <code>set &lt;name&gt; createWeekly &lt;string&gt;</code>
                </a>
                <br/>Create a new weekly profile &lt;string&gt;</li>
            <li><a name="yaahm_deleteweekly">
                    <code>set &lt;name&gt; deleteWeekly &lt;string&gt;</code>
                </a>
                <br/>Delete the weekly profile &lt;string&gt;</li>
            <li><a name="yaahm_initialize">
                    <code>set &lt;name&gt; initialize</code>
                </a>
                <br/>Restart the internal timers</li>
            <li><a name="yaahm_lock">
                    <code>set &lt;name&gt; locked|unlocked</code>
                </a>
                <br />Set the lockstate of the yaahm module to <i>locked</i> (i.e., yaahm setups
                may not be changed) resp. <i>unlocked</i> (i.e., yaahm setups may be changed>)</li>
            <li><a name="yaahm_save">
                    <code>set &lt;name&gt; save|restore</code>
                </a>
                <br />Manually save/restore the complete profile data to/from the external file YAAHMFILE (save done automatically at each timer start, restore at FHEM start)</li>
        </ul>
        <a name="YAAHMget"></a>
        <h4>Get</h4>
        <ul>
            <li><a name="yaahm_next"></a>
                    <code>get &lt;name&gt; next &lt;timernumber&gt;</code><br/>
                    <code>get &lt;name&gt; next &lt;timername&gt;</code><br/>
                    For the weekly timer identified by its number (starting at 0) or its name, get the next ring time in a format suitable for text devices.</li>
           <li><a name="yaahm_saynext"></a>
                    <code>get &lt;name&gt; sayNext &lt;timernumber&gt;</code><br/>
                    <code>get &lt;name&gt; sayNext &lt;timername&gt;</code><br/>
                    For the weekly timer identified by its number (starting at 0) or its name, get the next ring time in a format suitable for speech devices.</li>
            <li><a name="yaahm_version"></a>
                <code>get &lt;name&gt; version</code>
                <br />Display the version of the module</li>
            <li><a name="yaahm_template"></a>
                <code>get &lt;name&gt; template</code>
                <br />Return an (empty) perl subroutine for the helper functions</li>
        </ul>
        <a name="YAAHMattr"></a>
        <h4>Attributes</h4>
        <ul>
            <li><a name="yaahm_linkname"><code>attr &lt;name&gt; linkname
                    &lt;string&gt;</code></a>
                <br />Name for yaahm web link, default:
                Profile</li>
            <li><a name="yaahm_hiddenroom"><code>attr &lt;name&gt; hiddenroom
                    &lt;string&gt;</code></a>
                <br />Room name for hidden yaahm room (containing only the YAAHM device), default:
                ProfileRoom</li>
            <li><a name="yaahm_lockstate"><code>attr &lt;name&gt; lockstate
                    locked|unlocked</code></a>
                <br /><i>locked</i> means that yaahm setups may not be changed, <i>unlocked</i>
                means that yaahm setups may be changed</li>
            <li><a name="yaahm_simulation"><code>attr &lt;name&gt; simulation
                    0|1</code></a>
                <br />a value of 1 means that commands issued directly on the device as "set ... " will not be executed, but only simulated. Does <i>not</i> prevent the button 
                click commands from the interactive web page to be executed.</li>
            <li><a name="yaahm_noicons"><code>attr &lt;name&gt; noicons
                    0|1</code></a>
                <br />when set to 1, animated icons are suppressed</li>
            <li><a name="yaahm_modecolor"><code>attr &lt;name&gt; modecolor[0|1|2|3] <i>color</i></code></a>
                <br />four color specifications to signal the modes normal (default <span style="color:#53f3c7">#53f3c7</span>), 
                 party (default <span style="color:#8bfa56">#8bfa56</span>), absence (default <span style="color:#ff9458">#ff9458</span>), 
                 donotodisturb (default <span style="color:#fd5777">#fd5777</span>), </li>
            <li><a name="yaahm_statecolor"><code>attr &lt;name&gt; statecolor[0|1|2|3] <i>color</i></code></a>
                <br />four color specifications to signal the states unsecured (default <span style="color:#53f3c7">#53f3c7</span>), 
                secured (default <span style="color:#ff9458">#ff9458</span>), 
                protected (default <span style="color:#f554e2">#f554e2</span>) and guarded (default <span style="color:#fd5777">#fd5777</span>)</li>
            <li><a name="yaahm_timehelper"><code>attr &lt;name&gt; timeHelper &lt;name of perl program&gt;</code></a>
                <br />name of a perl function that is called at each time step of the daily profile and for the two default weekly profiles</li>
            <li><a name="yaahm_modehelper"><code>attr &lt;name&gt; modeHelper &lt;name of perl program&gt;</code></a>
                <br />name of a perl function that is called at every change of the house mode</li>
             <li><a name="yaahm_modeauto"><code>attr &lt;name&gt; modeAuto 0|1</code></a>
                <br />If this attribute is set to 1, the house mode changes automatically at certain time events.
                <ul>
                <li>On time (event) <i>sleep</i> or <i>morning</i>, <i>party</i> mode will be reset to <i>normal</i> mode.</li>
                <li>On time (event) <i>wakeup</i>, <i>absence</i> mode will be reset to <i>normal</i> mode.</li>
                <li>On <i>any</i> time (event), <i>donotdisturb</i> mode will be reset to <i>normal</i> mode.</li>
                </ul>
                </li>    
            <li><a name="yaahm_sunsetrise"></a><code>attr &lt;name&gt; sunrise SunRise|AstroTwilightMorning|NauticTwilightMorning|CivilTwilightMorning|CustomTwilightMorning </code></br>
                <code>attr &lt;name&gt; sunset SunSet|AstroTwilightEvening|NauticTwilightEvening|CivilTwilightEvening|CustomTwilightEvening</code></br>
                Use different definitions for sunset and sunrise, see Module Astro</li>         
            <li><a name="yaahm_norepeat"><code>attr &lt;name&gt; norepeat 0|1</code></a>
                <br/> if set to 1, repeated executions of wakeup, sleep and other timer events from the weekly programme will be suppressed.</li>      
            <li><a name="yaahm_statedevices"><code>attr &lt;name&gt; stateDevices (&lt;device&gt;:&lt;state-unsecured&gt;:&lt;state-secured&gt;:&lt;state-protected&gt;:&lt;state-guarded&gt;,)*</code></a>
                <br />comma separated list of devices and their state in each of the house (security) states. Each of the listed devices will be checked in the interval given by the <i>stateInterval</i> attribute
                for its proper state, and a <i>stateWarning</i> function will be called if it is not in the proper state.</li>
            <li><a name="yaahm_stateinterval"><code>attr &lt;name&gt; stateInterval &lt;integer&gt;</code></a>
                <br />interval in minutes for checking all <i>stateDevices</i> for their proper state according of the house (security) state. Default 60 minutes.</li>
            <li><a name="yaahm_statewarning"><code>attr &lt;name&gt; stateWarning &lt;name of perl program&gt;</code></a>
                <br />name of a perl function that is called as <i>stateWarning('device','desired state','actual state')</i>if a device is not in the desired state.</li>
            <li><a name="yaahm_statehelper"><code>attr &lt;name&gt; stateHelper &lt;name of perl program&gt;</code></a>
                <br />name of a perl function that is called as <i>stateHelper('event')</i> at every change of the house (security) state</li>
            <li><a name="yaahm_stateauto"><code>attr &lt;name&gt; stateAuto 0|1</code></a>
                <br />If this attribute is set to 1, the house state changes automatically if certain modes are set or at certain time events
                <ul>
                <li>If leaving <i>party</i> mode and time event <i>sleep</i>, and currently in (security) state <i>unsecured</i>, the state will change to <i>secured</i>.</li>
                <li>If in <i>normal</i> mode and time event <i>sleep</i> or <i>night</i>, and currently in (security) state <i>unsecured</i>, the state will change to <i>secured</i>.</li>
                </ul>
                </li>
            <li><a name="yaahm_deviceactions"><code>attr &lt;name&gt; deviceActions &lt;comma-separated list of virtual device actions&gt; </code></a>
                <br />list of virtual device actions that yaahm is performing, e.g. roller_up, roller_down etc.</a></li>
            <li><a name="yaahm_holidaydevices"><code>attr &lt;name&gt; holidayDevices &lt;comma-separated list of devices&gt; </code></a>
                <br />list of devices that provide holiday information. The devices may be 
                <a href="#holiday">holiday devices</a> or <a href="#Calendar">Calendar devices</a></li>
            <li><a name="yaahm_vacationdevices"><code>attr &lt;name&gt; vacationDevices &lt;comma-separated list of devices&gt; </code></a>
                <br />list of devices that provide vacation information. The devices may be 
                <a href="#holiday">holiday devices</a> or <a href="#Calendar">Calendar devices</a></li>
            <li><a name="yaahm_specialdevices"><code>attr &lt;name&gt; specialDevices &lt;comma-separated list of devices&gt; </code></a>
                <br />list of devices that provide special date information (like e.g. garbage collection). The devices may be 
                <a href="#holiday">holiday devices</a> or <a href="#Calendar">Calendar devices</a></li>
        </ul>
        </ul>
=end html
=begin html_DE

<a name="YAAHM"></a>
<h3>YAAHM</h3>
<ul>
<a href="https://wiki.fhem.de/wiki/Modul_YAAHM">Deutsche Dokumentation im Wiki</a> vorhanden, die englische Version gibt es hier: <a href="commandref.html#YAAHM">YAAHM</a> 
</ul>
=end html_DE
=cut
