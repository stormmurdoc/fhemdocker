#########################################################################################################################
# $Id: 76_SMAPortal.pm 19815 2019-07-10 22:15:43Z DS_Starter $
#########################################################################################################################
#       76_SMAPortal.pm
#
#       (c) 2019 by Heiko Maaz
#       e-mail: Heiko dot Maaz at t-online dot de
#
#       This module can be used to get data from SMA Portal https://www.sunnyportal.com/Templates/Start.aspx .
# 
#       This script is part of fhem.
#
#       Fhem is free software: you can redistribute it and/or modify
#       it under the terms of the GNU General Public License as published by
#       the Free Software Foundation, either version 2 of the License, or
#       (at your option) any later version.
#
#       Fhem is distributed in the hope that it will be useful,
#       but WITHOUT ANY WARRANTY; without even the implied warranty of
#       MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#       GNU General Public License for more details.
#
#       You should have received a copy of the GNU General Public License
#       along with fhem.  If not, see <http://www.gnu.org/licenses/>.
#
#       Credits (Thanks to all!):
#           Brun von der Gönne <brun at goenne dot de> :  author of 98_SHM.pm
#           BerndArnold                                :  author of 98_SHMForecastRelative.pm
#           Wzut/XGuide                                :  creation of SMAPortal graphics
#       
#       FHEM Forum: http://forum.fhem.de/index.php/topic,27667.0.html 
#
#########################################################################################################################
#
# Definition: define <name> SMAPortal
#
#########################################################################################################################

package main;
use strict;
use warnings;
eval "use FHEM::Meta;1";

###############################################################
#                  SMAPortal Initialize
# Da ich mit package arbeite müssen für die jeweiligen hashFn 
# Funktionen der Funktionsname und davor mit :: getrennt der 
# eigentliche package Name des Modules
###############################################################
sub SMAPortal_Initialize($) {
  my ($hash) = @_;

  $hash->{DefFn}         = "FHEM::SMAPortal::Define";
  $hash->{UndefFn}       = "FHEM::SMAPortal::Undefine";
  $hash->{DeleteFn}      = "FHEM::SMAPortal::Delete"; 
  $hash->{AttrFn}        = "FHEM::SMAPortal::Attr";
  $hash->{SetFn}         = "FHEM::SMAPortal::Set";
  $hash->{GetFn}         = "FHEM::SMAPortal::Get";
  $hash->{DbLog_splitFn} = "FHEM::SMAPortal::DbLog_split";
  $hash->{AttrList}      = "cookieLocation ".
                           "cookielifetime ".
                           "detailLevel:1,2,3,4 ".
                           "disable:0,1 ".
                           "getDataRetries:1,2,3,4,5,6,7,8,9,10 ".
                           "interval ".
                           "showPassInLog:1,0 ".
                           "timeout ". 
                           "userAgent ".
                           "verbose5Data:none,liveData,weatherData,forecastData,consumerLiveData,consumerDayData,consumerMonthData,consumerYearData ".
                           $readingFnAttributes;

  eval { FHEM::Meta::InitMod( __FILE__, $hash ) };          # für Meta.pm (https://forum.fhem.de/index.php/topic,97589.0.html)

return; 
}

###############################################################
#                    Begin Package
###############################################################
package FHEM::SMAPortal;
use strict;
use warnings;
use GPUtils qw(:all);                   # wird für den Import der FHEM Funktionen aus der fhem.pl benötigt
use POSIX;
eval "use FHEM::Meta;1" or my $modMetaAbsent = 1;
use Data::Dumper;
use Blocking;
use Time::HiRes qw(gettimeofday);
use Time::Local;
use LWP::UserAgent;
use HTTP::Cookies;
use JSON qw(decode_json);
use MIME::Base64;
use Encode;

# Run before module compilation
BEGIN {
  # Import from main::
  GP_Import( 
      qw(
          attr
          AttrVal
		  AttrNum
          addToDevAttrList
          addToAttrList
          BlockingCall
          BlockingKill
          BlockingInformParent
          CommandAttr
          CommandDefine
          CommandDeleteAttr
          CommandDeleteReading
          CommandSet
          defs
          delFromDevAttrList
          delFromAttrList
          devspec2array
          deviceEvents
          Debug
          FmtDateTime
          FmtTime
          FW_makeImage
          fhemTimeGm
          getKeyValue
          gettimeofday
          genUUID
          init_done
          InternalTimer
          IsDisabled
          Log
          Log3    
          makeReadingName          
          modules          
          readingsSingleUpdate
          readingsBulkUpdate
          readingsBulkUpdateIfChanged
          readingsBeginUpdate
          readingsDelete
          readingsEndUpdate
          ReadingsNum
          ReadingsTimestamp
          ReadingsVal
          RemoveInternalTimer
          setKeyValue
          sortTopicNum
          TimeNow
          Value
          json2nameValue
          FW_cmd
          FW_directNotify
          FW_ME                                     
          FW_subdir                                 
          FW_room                                  
          FW_detail                                 
          FW_wname           
        )
  );
}

# Standardvariablen und Forward-Deklaration
use vars qw($FW_ME);                                    # webname (default is fhem)

# Versions History intern
our %vNotesIntern = (
  "2.5.0"  => "25.08.2019  change switch consumer to on<->automatic only in graphic overwiev, Forum: https://forum.fhem.de/index.php/topic,102112.msg969002.html#msg969002",
  "2.4.5"  => "22.08.2019  fix some warnings, Forum: https://forum.fhem.de/index.php/topic,102112.msg968829.html#msg968829 ",
  "2.4.4"  => "11.07.2019  fix consinject to show multiple consumer icons if planned ",
  "2.4.3"  => "07.07.2019  change header design of portal graphics again ",
  "2.4.2"  => "02.07.2019  change header design of portal graphics ",
  "2.4.1"  => "01.07.2019  replace space in consumer name by a valid sign for reading creation ",
  "2.4.0"  => "26.06.2019  support for FTUI-Widget ",
  "2.3.7"  => "24.06.2019  replace suggestIcon by consumerAdviceIcon ",
  "2.3.6"  => "21.06.2019  revise commandref ",                        
  "2.3.5"  => "20.06.2019  subroutine consinject added to pv, pvco style ",
  "2.3.4"  => "19.06.2019  change some readingnames, delete L4_plantOid, next04hours_state ",
  "2.3.3"  => "16.06.2019  change verbose 4 output, fix warning if no weather info was got ",
  "2.3.2"  => "14.06.2019  add request string to verbose 5, add battery data to live and historical consumer data ",
  "2.3.1"  => "13.06.2019  switch Credentials read from RAM to verbose 4, changed W/h->Wh and kW/h->kWh in PortalAsHtml ",
  "2.3.0"  => "12.06.2019  add set on,off,automatic cmd for controlled devices ",
  "2.2.0"  => "10.06.2019  relocate RestOfDay and Tomorrow data from level 3 to level 2, change readings to start all with uppercase, ".
                           "add consumer energy data of current day/month/year, new attribute \"verbose5Data\" ",
  "2.1.2"  => "08.06.2019  correct planned time of consumer in PortalAsHtml if planned time is at next day ",
  "2.1.1"  => "08.06.2019  add units to values, some bugs fixed ",
  "2.1.0"  => "07.06.2019  add informations about consumer switch and power state ",
  "2.0.0"  => "03.06.2019  designed for SMAPortalSPG graphics device ",
  "1.8.0"  => "27.05.2019  redesign of SMAPortal graphics by Wzut/XGuide ",
  "1.7.1"  => "01.05.2019  PortalAsHtml: use of colored svg-icons possible ",
  "1.7.0"  => "01.05.2019  code change of PortalAsHtml, new attributes \"portalGraphicColor\" and \"portalGraphicStyle\" ",
  "1.6.0"  => "29.04.2019  function PortalAsHtml ",
  "1.5.5"  => "22.04.2019  fix readings for BattryOut and BatteryIn ",
  "1.5.4"  => "26.03.2019  delete L1_InfoMessages if no info occur ",
  "1.5.3"  => "26.03.2019  delete L1_ErrorMessages, L1_WarningMessages if no errors or warnings occur ",
  "1.5.2"  => "25.03.2019  prevent module from deactivation in case of unavailable Meta.pm ",
  "1.5.1"  => "24.03.2019  fix \$VAR1 problem Forum: #27667.msg922983.html#msg922983 ",
  "1.5.0"  => "23.03.2019  add consumer data ",
  "1.4.0"  => "22.03.2019  add function extractPlantData, DbLog_split, change L2 Readings ",
  "1.3.0"  => "18.03.2019  change module to use package FHEM::SMAPortal and Meta.pm, new sub setVersionInfo ",
  "1.2.3"  => "12.03.2019  make ready for 98_Installer.pm ", 
  "1.2.2"  => "11.03.2019  new Errormessage analyze added, make ready for Meta.pm ", 
  "1.2.1"  => "10.03.2019  behavior of state changed, commandref revised ", 
  "1.2.0"  => "09.03.2019  integrate weather data, minor fixes ",
  "1.1.0"  => "09.03.2019  make get data more stable, new attribute \"getDataRetries\" ",
  "1.0.0"  => "03.03.2019  initial "
);
                                # Web instance

###############################################################
#                         SMAPortal Define
###############################################################
sub Define($$) {
  my ($hash, $def) = @_;
  my @a = split(/\s+/, $def);
  
  return "Wrong syntax: use \"define <name> SMAPortal\" " if(int(@a) < 1);

  $hash->{HELPER}{MODMETAABSENT} = 1 if($modMetaAbsent);   # Modul Meta.pm nicht vorhanden
  
  $hash->{HELPER}{GETTER} = "all";
  $hash->{HELPER}{SETTER} = "none";
  
  setVersionInfo($hash);                                   # Versionsinformationen setzen
  getcredentials($hash,1);                                 # Credentials lesen und in RAM laden ($boot=1)
  CallInfo($hash);                                         # Start Daten Abrufschleife
  delcookiefile($hash);                                    # Start Schleife regelmäßiges Löschen Cookiefile
 
return undef;
}

###############################################################
#                         SMAPortal Undefine
###############################################################
sub Undefine($$) {
  my ($hash, $arg) = @_;

  RemoveInternalTimer($hash);
  BlockingKill($hash->{HELPER}{RUNNING_PID}) if($hash->{HELPER}{RUNNING_PID});

return undef;
}

###############################################################
#                         SMAPortal Delete
###############################################################
sub Delete($$) {
    my ($hash, $arg) = @_;
    my $index = $hash->{TYPE}."_".$hash->{NAME}."_credentials";
    my $name  = $hash->{NAME};
    
    # gespeicherte Credentials löschen
    setKeyValue($index, undef);
    
return undef;
}

###############################################################
#                          SMAPortal Set
###############################################################
sub Set($@) {
  my ($hash, @a) = @_;
  return "\"set X\" needs at least an argument" if ( @a < 2 );
  my $name    = $a[0];
  my $opt     = $a[1];
  my $prop    = $a[2];
  my $prop1   = $a[3];
  my ($setlist,$success);
  my $ad      = "";
    
  return if(IsDisabled($name));
 
  if(!$hash->{CREDENTIALS}) {
      # initiale setlist für neue Devices
      $setlist = "Unknown argument $opt, choose one of ".
	             "credentials "
                 ;  
  } else {
      # erweiterte Setlist wenn Credentials gesetzt
      $setlist = "Unknown argument $opt, choose one of ".
	             "credentials ".
                 "createPortalGraphic:Generation,Consumption,Generation_Consumption,Differential "
                 ;   
      if($hash->{HELPER}{PLANTOID} && $hash->{HELPER}{CONSUMER}) {
          my $lfd = 0;
          foreach my $key (keys %{$hash->{HELPER}{CONSUMER}{$lfd}}) {
              my $dev = $hash->{HELPER}{CONSUMER}{$lfd}{DeviceName};
              if($dev) {
                  $ad .= "|" if($lfd != 0);
                  $ad .= $dev;
              }
              if ($dev && $setlist !~ /$dev/) {
                  $setlist .= "$dev:on,off,auto ";
              }
              $lfd++;
          }
      } 
  }  

  if ($opt eq "credentials") {
      return "Credentials are incomplete, use username password" if (!$prop || !$prop1);    
      ($success) = setcredentials($hash,$prop,$prop1); 
	  
	  if($success) {
          CallInfo($hash);
		  return "Username and Password saved successfully";
	  } else {
		   return "Error while saving Username / Password - see logfile for details";
	  }
			
  } elsif ($opt eq "createPortalGraphic") {
	  if (!$hash->{CREDENTIALS}) {return "Credentials of $name are not set - make sure you've set it with \"set $name credentials username password\"";}
	  my ($htmldev,$ret,$c,$type,$color2);
      
      if ($prop eq "Generation") {
          $htmldev = "SPG1.$name";                                                      # Grafiktyp Generation (Erzeugung)
          $type    = 'pv';        
          $c       = "SMA Sunny Portal Graphics - Forecast Generation";
          $color2  = "000000";                                                          # zweite Farbe als schwarz setzen
      } elsif ($prop eq "Consumption") {
          $htmldev = "SPG2.$name";                                                      # Grafiktyp Consumption (Verbrauch)
          $type    = 'co';    
          $c       = "SMA Sunny Portal Graphics - Forecast Consumption"; 
          $color2  = "000000";                                                          # zweite Farbe als schwarz setzen          
      } elsif ($prop eq "Generation_Consumption") {
          $htmldev = "SPG3.$name";                                                      # Grafiktyp Generation_Consumption (Erzeugung und Verbrauch)
          $type    = 'pvco'; 
          $c       = "SMA Sunny Portal Graphics - Forecast Generation & Consumption";
          $color2  = "FF5C82";                                                          # zweite Farbe als rot setzen          
      } elsif ($prop eq "Differential") {
          $htmldev = "SPG4.$name";                                                      # Grafiktyp Differential (Differenzanzeige)
          $type    = 'diff';   
          $c       = "SMA Sunny Portal Graphics - Forecast Differential";   
          $color2  = "FF5C82";                                                          # zweite Farbe als rot setzen           
      } else {
          return "Invalid portal graphic devicetype ! Use one of \"Generation\", \"Consumption\", \"Generation_Consumption\", \"Differential\". "
      }

      $ret = CommandDefine($hash->{CL},"$htmldev SMAPortalSPG {FHEM::SMAPortal::PortalAsHtml ('$name','$htmldev')}");
      return $ret if($ret);
      
      CommandAttr($hash->{CL},"$htmldev alias $c");                                     # Alias setzen
      
      $c = "This device provides a praphical output of SMA Sunny Portal values.\n". 
           "The device needs to set attribute \"detailLevel\" in device \"$name\" to level \"4\"";
      CommandAttr($hash->{CL},"$htmldev comment $c");     

      # es muß nicht unbedingt jedes der möglichen userattr unbedingt vorbesetzt werden
      # bzw muß überhaupt hier etwas vorbesetzt werden ?
      # alle Werte enstprechen eh den AttrVal/ AttrNum default Werten
      
      CommandAttr($hash->{CL},"$htmldev hourCount 24");
      CommandAttr($hash->{CL},"$htmldev consumerAdviceIcon on");
      CommandAttr($hash->{CL},"$htmldev showHeader 1");
      CommandAttr($hash->{CL},"$htmldev showLink 1");
      CommandAttr($hash->{CL},"$htmldev spaceSize 24");
      CommandAttr($hash->{CL},"$htmldev showWeather 1");
      CommandAttr($hash->{CL},"$htmldev layoutType $type");                             # Anzeigetyp setzen

      # eine mögliche Startfarbe steht beim installiertem f18 Style direkt zur Verfügung
      # ohne vorhanden f18 Style bestimmt später tr.odd aus der Style css die Anfangsfarbe
      my $color;
      my $jh = json2nameValue(AttrVal('WEB','styleData',''));
      if($jh && ref $jh eq "HASH") {
          $color = $jh->{'f18_cols.header'};
      }
      if (defined($color)) {
          CommandAttr($hash->{CL},"$htmldev beamColor $color");
      }
	  
      # zweite Farbe setzen
      CommandAttr($hash->{CL},"$htmldev beamColor2 $color2");

      my $room = AttrVal($name,"room","SMAPortal");
      CommandAttr($hash->{CL},"$htmldev room $room");
      CommandAttr($hash->{CL},"$name detailLevel 4");
      
	  return "SMA Portal Graphics device \"$htmldev\" created and assigned to room \"$room\".";
  
  } elsif ($opt && $ad && $opt =~ /$ad/) {
      # Verbraucher schalten
      $hash->{HELPER}{GETTER} = "none";
      $hash->{HELPER}{SETTER} = "$opt:$prop";
      CallInfo($hash);
      
  } else {
      return "$setlist";
  } 
  
return;
}

###############################################################
#                          SMAPortal Get
###############################################################
sub Get($$) {
 my ($hash, @a) = @_;
 return "\"get X\" needs at least an argument" if ( @a < 2 );
 my $name = shift @a;
 my $opt  = shift @a;
   
 my  $getlist = "Unknown argument $opt, choose one of ".
                "storedCredentials:noArg ".
                "data:noArg ";
                   
 return "module is disabled" if(IsDisabled($name));
  
 if ($opt eq "data") {
     $hash->{HELPER}{GETTER} = "all";
     $hash->{HELPER}{SETTER} = "none";
     CallInfo($hash);
 
 } elsif ($opt eq "storedCredentials") {
	    if(!$hash->{CREDENTIALS}) {return "Credentials of $name are not set - make sure you've set it with \"set $name credentials &lt;username&gt; &lt;password&gt;\"";}
        # Credentials abrufen
        my ($success, $username, $password) = getcredentials($hash,0);
        unless ($success) {return "Credentials couldn't be retrieved successfully - see logfile"};
        
        return "Stored Credentials to access SMA Portal:\n".
               "========================================\n".
               "Username: $username, Password: $password\n".
               "\n";
                
 } else {
     return "$getlist";
 } 
 
return undef;
}

###############################################################
#               SMAPortal DbLog_splitFn
###############################################################
sub DbLog_split($$) {
  my ($event, $device) = @_;
  my $devhash = $defs{$device};
  my ($reading, $value, $unit);

  if($event =~ m/[_\-fd]Consumption|Quote/) {
      $event =~ /^L(.*):\s(.*)\s(.*)/;
      if($1) {
          $reading = "L".$1;
          $value   = $2;
          $unit    = $3;
      }
  }
  if($event =~ m/Power|PV|FeedIn|SelfSupply|Temperature|Total|Energy|Hour:|Hour(\d\d):/) {
      $event   =~ /^L(.*):\s(.*)\s(.*)/;
      if($1) {
          $reading = "L".$1;
          $value   = $2;
          $unit    = $3;
      }
  }   
  if($event =~ m/Next04Hours-IsConsumption|RestOfDay-IsConsumption|Tomorrow-IsConsumption|Battery/) {
      $event =~ /^L(.*):\s(.*)\s(.*)/;
      if($1) {
          $reading = "L".$1;
          $value   = $2;
          $unit    = $3;
      }
  }   
  if($event =~ m/summary/) {
      $event   =~ /(.*):\s(.*)\s(.*)/;
      $reading = $1;
	  $value   = $2;
	  $unit    = $3;
  } 
  
return ($reading, $value, $unit);
}

######################################################################################
#                            Username / Paßwort speichern
######################################################################################
sub setcredentials ($@) {
    my ($hash, @credentials) = @_;
    my $name                 = $hash->{NAME};
    my ($success, $credstr, $index, $retcode);
    my (@key,$len,$i);    
    
    $credstr = encode_base64(join(':', @credentials));
    
    # Beginn Scramble-Routine
    @key = qw(1 3 4 5 6 3 2 1 9);
    $len = scalar @key;  
    $i = 0;  
    $credstr = join "",  
            map { $i = ($i + 1) % $len;  
            chr((ord($_) + $key[$i]) % 256) } split //, $credstr; 
    # End Scramble-Routine    
       
    $index = $hash->{TYPE}."_".$hash->{NAME}."_credentials";
    $retcode = setKeyValue($index, $credstr);
    
    if ($retcode) { 
        Log3($name, 1, "$name - Error while saving the Credentials - $retcode");
        $success = 0;
    } else {
        getcredentials($hash,1);        # Credentials nach Speicherung lesen und in RAM laden ($boot=1)
        $success = 1;
    }

return ($success);
}

######################################################################################
#                             Username / Paßwort abrufen
######################################################################################
sub getcredentials ($$) {
    my ($hash,$boot) = @_;
    my $name         = $hash->{NAME};
    my ($success, $username, $passwd, $index, $retcode, $credstr);
    my (@key,$len,$i);
    
    if ($boot) {
        # mit $boot=1 Credentials von Platte lesen und als scrambled-String in RAM legen
        $index = $hash->{TYPE}."_".$hash->{NAME}."_credentials";
        ($retcode, $credstr) = getKeyValue($index);
    
        if ($retcode) {
            Log3($name, 2, "$name - Unable to read password from file: $retcode");
            $success = 0;
        }  

        if ($credstr) {
            # beim Boot scrambled Credentials in den RAM laden
            $hash->{HELPER}{CREDENTIALS} = $credstr;
    
            # "Credentials" wird als Statusbit ausgewertet. Wenn nicht gesetzt -> Warnmeldung und keine weitere Verarbeitung
            $hash->{CREDENTIALS} = "Set";
            $success = 1;
        }
    } else {
        # boot = 0 -> Credentials aus RAM lesen, decoden und zurückgeben
        $credstr = $hash->{HELPER}{CREDENTIALS};
        
        if($credstr) {
            # Beginn Descramble-Routine
            @key = qw(1 3 4 5 6 3 2 1 9); 
            $len = scalar @key;  
            $i = 0;  
            $credstr = join "",  
            map { $i = ($i + 1) % $len;  
            chr((ord($_) - $key[$i] + 256) % 256) }  
            split //, $credstr;   
            # Ende Descramble-Routine
            
            ($username, $passwd) = split(":",decode_base64($credstr));
            
            my $logpw = AttrVal($name, "showPassInLog", "0") == 1 ? $passwd : "********";
        
            Log3($name, 4, "$name - Credentials read from RAM: $username $logpw");
        
        } else {
            Log3($name, 1, "$name - Credentials not set in RAM !");
        }
        
        $success = (defined($passwd)) ? 1 : 0;
    }

return ($success, $username, $passwd);        
}

###############################################################
#                          SMAPortal Attr
###############################################################
sub Attr($$$$) {
    my ($cmd,$name,$aName,$aVal) = @_;
    my $hash = $defs{$name};
    my ($do,$val);
    
    # $cmd can be "del" or "set"
    # $name is device name
    # aName and aVal are Attribute name and value
    
    if ($aName eq "disable") {
        if($cmd eq "set") {
            $do = ($aVal) ? 1 : 0;
        }
        $do  = 0 if($cmd eq "del");
		$val = ($do == 1 ? "disabled" : "initialized");
        
        if($do) {
            delread($hash);
            delete $hash->{MODE};
            RemoveInternalTimer($hash);            
            delcookiefile($hash,1);            
        } else {
            InternalTimer(gettimeofday()+1.0, "FHEM::SMAPortal::CallInfo", $hash, 0);
            InternalTimer(gettimeofday()+5.0, "FHEM::SMAPortal::delcookiefile", $hash, 0);
        }
	    
        readingsBeginUpdate($hash);
	    readingsBulkUpdate($hash, "state", $val);
	    readingsEndUpdate($hash, 1);
        
        InternalTimer(gettimeofday()+2.0, "FHEM::SMAPortal::SPGRefresh", "$name,0,1", 0);
    }
    
    if ($cmd eq "set") {
        if ($aName =~ m/timeout|interval/) {
            unless ($aVal =~ /^\d+$/) {return " The Value for $aName is not valid. Use only figures 0-9 !";}
        }
        if($aName =~ m/interval/) {
            $_[3] = 120 if($aVal > 0 && $aVal < 120);
            InternalTimer(gettimeofday()+1.0, "FHEM::SMAPortal::CallInfo", $hash, 0);
        }        
    }

return undef;
}

################################################################
##               Hauptschleife BlockingCall
##   $hash->{HELPER}{GETTER} -> Flag für get Informationen
##   $hash->{HELPER}{SETTER} -> Parameter für set-Befehl
################################################################
sub CallInfo($) {
  my ($hash)   = @_;
  my $name     = $hash->{NAME};
  my $timeout  = AttrVal($name, "timeout", 30);
  my $interval = AttrVal($name, "interval", 300);
  my $new;
  
  RemoveInternalTimer($hash,"FHEM::SMAPortal::CallInfo");
  
  if($init_done == 1) {
      if(!$hash->{CREDENTIALS}) {
          Log3($name, 1, "$name - Credentials not set. Set it with \"set $name credentials <username> <password>\""); 
          readingsSingleUpdate($hash, "state", "Credentials not set", 1);    
          return;          
      }
      
      if(!$interval) {
          $hash->{MODE} = "Manual";
      } else {
          $new = gettimeofday()+$interval; 
          InternalTimer($new, "FHEM::SMAPortal::CallInfo", $hash, 0);
          $hash->{MODE} = "Automatic - next polltime: ".FmtTime($new);
      }

      return if(IsDisabled($name));
      
      if ($hash->{HELPER}{RUNNING_PID}) {
          BlockingKill($hash->{HELPER}{RUNNING_PID});
          delete($hash->{HELPER}{RUNNING_PID});
      } 
      
      my $get = $hash->{HELPER}{GETTER};
      my $set = $hash->{HELPER}{SETTER};
      
      Log3 ($name, 4, "$name - ################################################################");
      Log3 ($name, 4, "$name - ###      start of set/get data from SMA Sunny Portal         ###");
      Log3 ($name, 4, "$name - ################################################################"); 
  
	  $hash->{HELPER}{RETRIES} = AttrVal($name, "getDataRetries", 3);
      $hash->{HELPER}{RUNNING_PID} = BlockingCall("FHEM::SMAPortal::GetSetData", "$name|$get|$set", "FHEM::SMAPortal::ParseData", $timeout, "FHEM::SMAPortal::ParseAborted", $hash);
      $hash->{HELPER}{RUNNING_PID}{loglevel} = 5 if($hash->{HELPER}{RUNNING_PID});  # Forum #77057
  
  } else {
      InternalTimer(gettimeofday()+5, "FHEM::SMAPortal::CallInfo", $hash, 0);
  }
    
return;  
}

################################################################
##                  Datenabruf SMA-Portal
##      schaltet auch Verbraucher des Sunny Home Managers
################################################################
sub GetSetData($) {
  my ($string) = @_;
  my ($name,$get,$set) = split("\\|",$string);
  my $hash             = $defs{$name}; 
  my $login_state      = 0;
  my $useragent        = AttrVal($name, "userAgent", "Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.2; Trident/6.0)");
  my $cookieLocation   = AttrVal($name, "cookieLocation", "./log/mycookies.txt");
  my $v5d              = AttrVal($name, "verbose5Data", "none");   
  my ($forecast_content,$weatherdata_content,$consumerlivedata_content,$ccdaydata_content,$ccmonthdata_content) = ("","","","","");
  my ($ccyeardata_content) = ("");
  my $state                = "ok";
  my ($livedata_content,$d,$op); 
  
  if($set ne "none") {
      # Verbraucher soll in den Status $op geschaltet werden
      ($d,$op) = split(":",$set);
  }
  
  Log3 ($name, 5, "$name - Start operation with CookieLocation: $cookieLocation and UserAgent: $useragent");
  Log3 ($name, 5, "$name - data get: $get, data set: ".(($d && $op)?($d." ".$op):$set));
  
  my $ua = LWP::UserAgent->new;

  # Define user agent type
  $ua->agent("$useragent");
  
  # Cookies
  $ua->cookie_jar(HTTP::Cookies->new( file           => "$cookieLocation",
                                      ignore_discard => 1,
                                      autosave       => 1
                                    )
                 );
  
  # Sunny Home Manager Seite abfragen 
  my $livedata = $ua->get('https://www.sunnyportal.com/homemanager');

  if(($livedata->content =~ m/FeedIn/i) && ($livedata->content !~ m/expired/i)) {
      Log3 $name, 4, "$name - Login to SMA-Portal successful";
          # JSON Live Daten
          $livedata_content = $livedata->content;
          $login_state      = 1;
          Log3 ($name, 4, "$name - Getting live data");
          Log3 ($name, 5, "$name - Data received:\n".Dumper decode_json($livedata_content)) if($v5d eq "liveData");
      
      ### einen Verbraucher schalten mit POST 
      if($set ne "none") {                                      
          my ($serial,$id);
          foreach my $key (keys %{$hash->{HELPER}{CONSUMER}}) {
              my $h = $hash->{HELPER}{CONSUMER}{$key}{DeviceName};
              if($h && $h eq $d) {
                  $serial = $hash->{HELPER}{CONSUMER}{$key}{SerialNumber};
                  $id     = $hash->{HELPER}{CONSUMER}{$key}{SUSyID};
              }
          }
          my $plantOid = $hash->{HELPER}{PLANTOID};
          my $res      = $ua->post('https://www.sunnyportal.com/Homan/ConsumerBalance/SetOperatingMode', {'mode' => $op, 'serialNumber' => $serial, 'SUSyID' => $id, 'plantOid' => $plantOid} );
          $res = $res->decoded_content();
          Log3 ($name, 3, "$name - Set \"$d $op\" result: ".$res);
          if($res eq "true") {
              $state = "ok - switched consumer $d to $op";
              BlockingInformParent("FHEM::SMAPortal::setFromBlocking", [$name, "all", "none"], 0);
          } else {
              $state = "Error - couldn't switched consumer $d to $op";
          }
      }
      
      ### Daten abrufen mit GET
      if($get ne "none") {                                   
          
          # JSON Wetterdaten
          Log3 ($name, 4, "$name - Getting weather data");
          my $weatherdata = $ua->get('https://www.sunnyportal.com/Dashboard/Weather');
          $weatherdata_content = $weatherdata->content;
          Log3 ($name, 5, "$name - Data received:\n".Dumper decode_json($weatherdata_content)) if($v5d eq "weatherData");
          
          # JSON Forecast Daten
          my $dl = AttrVal($name, "detailLevel", 1);
          if($dl > 1) {
              Log3 ($name, 4, "$name - Getting forecast data");

              my $forecast_page = $ua->get('https://www.sunnyportal.com/HoMan/Forecast/LoadRecommendationData');
              Log3 ($name, 5, "$name - Return Code: ".$forecast_page->code) if($v5d eq "forecastData"); 

              if ($forecast_page->content =~ m/ForecastChartDataPoint/i) {
                  $forecast_content = $forecast_page->content;
                  Log3 ($name, 5, "$name - Forecast data received:\n".Dumper decode_json($forecast_content)) if($v5d eq "forecastData"); 
              }
          }
          
          # JSON Consumer Livedaten und historische Energiedaten
          if($dl > 2) {
              Log3 ($name, 4, "$name - Getting consumer live data");

              my $consumerlivedata = $ua->get('https://www.sunnyportal.com/Homan/ConsumerBalance/GetLiveProxyValues');
              
              Log3 ($name, 5, "$name - Return Code: ".$consumerlivedata->code) if($v5d eq "consumerLiveData"); 

              if ($consumerlivedata->content =~ m/HoManConsumerLiveData/i) {
                  $consumerlivedata_content = $consumerlivedata->content;
                  Log3 ($name, 5, "$name - Consumer live data received:\n".Dumper decode_json($consumerlivedata_content)) if($v5d eq "consumerLiveData"); 
              }
              
              if($hash->{HELPER}{PLANTOID}) {              
                  my $PlantOid = $hash->{HELPER}{PLANTOID};
                  my $dds      = (split(/\s+/,TimeNow()))[0];
                  my $dde      = (split(/\s+/,FmtDateTime(time()+86400)))[0];
                  $dds         =~ /(.*)-(.*)-(.*)/;
                  my $mds      = "$1-$2-01";
                  my $me       = (($2+1)<=12)?$2+1:1;
                  $me          = sprintf("%02d", $me);
                  my $ye       = ($2>$me)?$1+1:$1;
                  my $mde      = "$ye-$me-01";
                  my $yds      = "$1-01-01";
                  my $yde      = ($1+1)."-01-01";
				  
				  my $ccdd     = 'https://www.sunnyportal.com/Homan/ConsumerBalance/GetMeasuredValues?IntervalId=2&'.$PlantOid.'&StartTime='.$dds.'&EndTime='.$dde.'';
                  my $ccmd     = 'https://www.sunnyportal.com/Homan/ConsumerBalance/GetMeasuredValues?IntervalId=4&'.$PlantOid.'&StartTime='.$mds.'&EndTime='.$mde.'';
				  my $ccyd     = 'https://www.sunnyportal.com/Homan/ConsumerBalance/GetMeasuredValues?IntervalId=5&'.$PlantOid.'&StartTime='.$yds.'&EndTime='.$yde.'';
				  
                  # Energiedaten aktueller Tag
                  Log3 ($name, 4, "$name - Getting consumer energy data of current day");
                  Log3 ($name, 4, "$name - Request date -> start: $dds, end: $dde");
                  Log3 ($name, 5, "$name - Request consumer current day data string ->\n$ccdd");  				  
				  my $ccdaydata = $ua->get($ccdd);
                  
                  Log3 ($name, 5, "$name - Return Code: ".$ccdaydata->code) if($v5d eq "consumerDayData"); 

                  if ($ccdaydata->content =~ m/ConsumerBalanceDeviceInfo/i) {
                      $ccdaydata_content = $ccdaydata->content;
                      Log3 ($name, 5, "$name - Consumer energy data of current day received:\n".Dumper decode_json($ccdaydata_content)) if($v5d eq "consumerDayData"); 
                  }

                  # Energiedaten aktueller Monat
                  Log3 ($name, 4, "$name - Getting consumer energy data of current month");
                  Log3 ($name, 4, "$name - Request date -> start: $mds, end: $mde"); 
				  Log3 ($name, 5, "$name - Request consumer current month data string ->\n$ccmd");
                  my $ccmonthdata = $ua->get($ccmd);
                  
                  Log3 ($name, 5, "$name - Return Code: ".$ccmonthdata->code) if($v5d eq "consumerMonthData"); 

                  if ($ccmonthdata->content =~ m/ConsumerBalanceDeviceInfo/i) {
                      $ccmonthdata_content = $ccmonthdata->content;
                      Log3 ($name, 5, "$name - Consumer energy data of current month received:\n".Dumper decode_json($ccmonthdata_content)) if($v5d eq "consumerMonthData"); 
                  }       

                  # Energiedaten aktuelles Jahr
                  Log3 ($name, 4, "$name - Getting consumer energy data of current year");
                  Log3 ($name, 4, "$name - Request date -> start: $yds, end: $yde"); 
				  Log3 ($name, 5, "$name - Request consumer current year data string ->\n$ccyd");
                  my $ccyeardata = $ua->get($ccyd);
                  
                  Log3 ($name, 5, "$name - Return Code: ".$ccyeardata->code) if($v5d eq "consumerMonthData"); 

                  if ($ccyeardata->content =~ m/ConsumerBalanceDeviceInfo/i) {
                      $ccyeardata_content = $ccyeardata->content;
                      Log3 ($name, 5, "$name - Consumer energy data of current year received:\n".Dumper decode_json($ccyeardata_content)) if($v5d eq "consumerYearData"); 
                  }               
              }
          }
      }
  
  } else {
      my $usernameField = "ctl00\$ContentPlaceHolder1\$Logincontrol1\$txtUserName";
      my $passwordField = "ctl00\$ContentPlaceHolder1\$Logincontrol1\$txtPassword";
      my $loginField    = "__EVENTTARGET";
      my $loginButton   = "ctl00\$ContentPlaceHolder1\$Logincontrol1\$LoginBtn";
      
      Log3 ($name, 3, "$name - not logged in. Try again ...");
      
      # Credentials abrufen
      my ($success, $username, $password) = getcredentials($hash,0);
  
      unless ($success) {
          Log3($name, 1, "$name - Credentials couldn't be retrieved successfully - make sure you've set it with \"set $name credentials <username> <password>\"");   
          $login_state = 0;
      
      } else {    
          my $loginp = $ua->post('https://www.sunnyportal.com/Templates/Start.aspx',[$usernameField => $username, $passwordField => $password, "__EVENTTARGET" => $loginButton]);
        
          Log3 ($name, 4, "$name - ".$loginp->code);
          Log3 ($name, 5, "$name - Login-Page return: ".$loginp->content);
        
          if( $loginp->content =~ /Logincontrol1_ErrorLabel/i ) {
              Log3 ($name, 1, "$name - Error: login to SMA-Portal failed");
              $livedata_content = "{\"Login-Status\":\"failed\"}";
          } else {
              Log3 ($name, 3, "$name - login to SMA-Portal successful ... ");
              $livedata_content = '{"Login-Status":"successful", "InfoMessages":["login to SMA-Portal successful but get data with next data cycle."]}';
              $login_state = 1;
          }

          my $shmp = $ua->get('https://www.sunnyportal.com/FixedPages/HoManLive.aspx');
          Log3 ($name, 5, "$name - ".$shmp->code);
      }
  }
  
  my ($reread,$retry) = analivedat($hash,$livedata_content);

  # Daten müssen als Einzeiler zurückgegeben werden
  my ($st,$lc,$fc,$wc,$cl,$cd,$cm,$cy) = ("","","","","","","","");
  $st = encode_base64($state,"");
  $lc = encode_base64($livedata_content,"");
  $fc = encode_base64($forecast_content,"")         if($forecast_content);
  $wc = encode_base64($weatherdata_content,"")      if($weatherdata_content);
  $cl = encode_base64($consumerlivedata_content,"") if($consumerlivedata_content);
  $cd = encode_base64($ccdaydata_content,"")        if($ccdaydata_content);
  $cm = encode_base64($ccmonthdata_content,"")      if($ccmonthdata_content);
  $cy = encode_base64($ccyeardata_content,"")       if($ccyeardata_content);

return "$name|$login_state|$reread|$retry|$get|$set|$st|$lc|$fc|$wc|$cl|$cd|$cm|$cy";
}

################################################################
##  Verarbeitung empfangene Daten, setzen Readings
################################################################
sub ParseData($) {
  my ($string) = @_;
  my @a = split("\\|",$string);
  my $hash        = $defs{$a[0]};
  my $name        = $hash->{NAME};
  my $login_state = $a[1];
  my $reread      = $a[2];
  my $retry       = $a[3];
  my $get         = $a[4];
  my $set         = $a[5];
  my $state       = decode_base64($a[6]);
  my $lc          = decode_base64($a[7]);
  my $fc          = decode_base64($a[8])  if($a[8]);
  my $wc          = decode_base64($a[9])  if($a[9]);
  my $cl          = decode_base64($a[10]) if($a[10]);
  my $cd          = decode_base64($a[11]) if($a[11]);
  my $cm          = decode_base64($a[12]) if($a[12]);
  my $cy          = decode_base64($a[13]) if($a[13]);
  
  my $livedata_content         = decode_json($lc);
  my $forecast_content         = decode_json($fc) if($fc);
  my $weatherdata_content      = decode_json($wc) if($wc);
  my $consumerlivedata_content = decode_json($cl) if($cl);
  my $ccdaydata_content        = decode_json($cd) if($cd);
  my $ccmonthdata_content      = decode_json($cm) if($cm);
  my $ccyeardata_content       = decode_json($cy) if($cy);
  
  my $timeout = AttrVal($name, "timeout", 30);
  if($reread) {
      # login war erfolgreich, aber Daten müssen jetzt noch gelesen werden
	  delete($hash->{HELPER}{RUNNING_PID});
      readingsSingleUpdate($hash, "L1_Login-Status", "successful", 1);
      $hash->{HELPER}{oldlogintime}          = gettimeofday();
	  $hash->{HELPER}{RUNNING_PID}           = BlockingCall("FHEM::SMAPortal::GetSetData", "$name|$get|$set", "FHEM::SMAPortal::ParseData", $timeout, "FHEM::SMAPortal::ParseAborted", $hash);
      $hash->{HELPER}{RUNNING_PID}{loglevel} = 5 if($hash->{HELPER}{RUNNING_PID});  # Forum #77057
      return;
  }
  if($retry && $hash->{HELPER}{RETRIES}) {
      # Livedaten konnte nicht gelesen werden, neuer Versuch zeitverzögert
	  delete($hash->{HELPER}{RUNNING_PID});
	  $hash->{HELPER}{RETRIES} -= 1;
      InternalTimer(gettimeofday()+5, "FHEM::SMAPortal::retrygetdata", $hash, 0);
      return;
  }  
  
  my $dl = AttrVal($name, "detailLevel", 1);
  delread($hash, $dl+1);
  
  Log3 ($name, 4, "$name - ##### extracting live data #### ");
  
  readingsBeginUpdate($hash);
  
  my ($FeedIn_done,$GridConsumption_done,$PV_done,$AutarkyQuote_done,$SelfConsumption_done) = (0,0,0,0,0);
  my ($SelfConsumptionQuote_done,$SelfSupply_done,$errMsg,$warnMsg,$infoMsg) = (0,0,0,0,0);
  my ($batteryin,$batteryout);
  for my $k (keys %$livedata_content) {
      my $new_val = ""; 
      if (defined $livedata_content->{$k}) {
          if (($livedata_content->{$k} =~ m/ARRAY/i) || ($livedata_content->{$k} =~ m/HASH/i)) {
              Log3 $name, 4, "$name - Livedata content \"$k\": ".($livedata_content->{$k});
              if($livedata_content->{$k} =~ m/ARRAY/i) {
                  my $hd0 = $livedata_content->{$k}[0];
                  if(!defined $hd0) {
                      next;
                  }
                  chomp $hd0;
                  $hd0 =~ s/[;']//g;
                  $hd0 = encode("utf8", $hd0);
                  Log3 $name, 4, "$name - Livedata \"$k\": $hd0";
                  $new_val = $hd0;
              }
		  } else {
              $new_val = $livedata_content->{$k};
          }
        
          if ($new_val && $k !~ /__type/i) {
              if($k =~ /^FeedIn$/) {
                  $new_val = $new_val." W";
                  $FeedIn_done = 1        
              }
              if($k =~ /^GridConsumption$/) {
                  $new_val = $new_val." W";
                  $GridConsumption_done = 1;
              }
              if($k =~ /^PV$/) {
                  $new_val = $new_val." W";
                  $PV_done = 1; 
              }
              if($k =~ /^AutarkyQuote$/) {
                  $new_val = $new_val." %";
                  $AutarkyQuote_done = 1;
              }
              if($k =~ /^SelfConsumption$/) {
                  $new_val = $new_val." W";
                  $SelfConsumption_done = 1;
              } 
              if($k =~ /^SelfConsumptionQuote$/) {              
                  $new_val = $new_val." %";
                  $SelfConsumptionQuote_done = 1; 
              }
              if($k =~ /^SelfSupply$/) {
                  $new_val = $new_val." W";
                  $SelfSupply_done = 1;
              }
              if($k =~ /^TotalConsumption$/) {
                  $new_val = $new_val." W";
              }
              if($k =~ /^BatteryIn$/) {
                  $new_val = $new_val." W";
                  $batteryin = 1;
              }
              if($k =~ /^BatteryOut$/) {
                  $new_val = $new_val." W";
                  $batteryout = 1;
              }        
              
              $errMsg  = 1 if($k =~ /^ErrorMessages$/);
              $warnMsg = 1 if($k =~ /^WarningMessages$/);
              $infoMsg = 1 if($k =~ /^InfoMessages$/);

              Log3 ($name, 4, "$name - $k - $new_val");
              readingsBulkUpdate($hash, "L1_$k", $new_val);
          }
      }
  }
  
  readingsBulkUpdate($hash, "L1_FeedIn",               "0 W") if(!$FeedIn_done);
  readingsBulkUpdate($hash, "L1_GridConsumption",      "0 W") if(!$GridConsumption_done);
  readingsBulkUpdate($hash, "L1_PV",                   "0 W") if(!$PV_done);
  readingsBulkUpdate($hash, "L1_AutarkyQuote",         "0 %") if(!$AutarkyQuote_done);
  readingsBulkUpdate($hash, "L1_SelfConsumption",      "0 W") if(!$SelfConsumption_done);
  readingsBulkUpdate($hash, "L1_SelfConsumptionQuote", "0 %") if(!$SelfConsumptionQuote_done);
  readingsBulkUpdate($hash, "L1_SelfSupply",           "0 W") if(!$SelfSupply_done);
  if(defined $batteryin || defined $batteryout) {
      readingsBulkUpdate($hash, "L1_BatteryIn",        "0 W") if(!$batteryin);
      readingsBulkUpdate($hash, "L1_BatteryOut",       "0 W") if(!$batteryout);
  }  
  readingsEndUpdate($hash, 1);
  
  readingsDelete($hash,"L1_ErrorMessages") if(!$errMsg);
  readingsDelete($hash,"L1_WarningMessages") if(!$warnMsg);
  readingsDelete($hash,"L1_InfoMessages") if(!$infoMsg);
  
  if ($forecast_content && $forecast_content !~ m/undefined/i) {
      # Auswertung der Forecast Daten
      extractForecastData($hash,$forecast_content);
      extractPlantData($hash,$forecast_content);
      extractConsumerData($hash,$forecast_content);
  }
  
  if ($consumerlivedata_content && $consumerlivedata_content !~ m/undefined/i) {
      # Auswertung Consumer Live Daten
      extractConsumerLiveData($hash,$consumerlivedata_content);
  }
  
  if ($ccdaydata_content && $ccdaydata_content !~ m/undefined/i) {
      # Auswertung Consumer Energiedaten des aktuellen Tages
      extractConsumerHistData($hash,$ccdaydata_content,"day");
  }
  
  if ($ccmonthdata_content && $ccmonthdata_content !~ m/undefined/i) {
      # Auswertung Consumer Energiedaten des aktuellen Monats
      extractConsumerHistData($hash,$ccmonthdata_content,"month");
  }
  
  if ($ccyeardata_content && $ccyeardata_content !~ m/undefined/i) {
      # Auswertung Consumer Energiedaten des aktuellen Jahres
      extractConsumerHistData($hash,$ccyeardata_content,"year");
  }
  
  if ($weatherdata_content && $weatherdata_content !~ m/undefined/i) {
      # Auswertung Wetterdaten
      extractWeatherData($hash,$weatherdata_content);
  }
  
  my $pv = ReadingsNum($name, "L1_PV", 0);
  my $fi = ReadingsNum($name, "L1_FeedIn", 0);
  my $gc = ReadingsNum($name, "L1_GridConsumption", 0);
  my $sum = $fi-$gc;
  
  if(!$hash->{HELPER}{RETRIES} && !$pv && !$fi && !$gc) {
      # keine Anlagendaten vorhanden
      $state = "Data can't be retrieved from SMA-Portal. Reread at next scheduled cycle.";
      Log3 ($name, 2, "$name - $state");
  }
  
  readingsBeginUpdate($hash);
  if($login_state) {
      if($set ne "none") {
          my ($d,$op) = split(":",$set);
          $op = ($op eq "auto")?"off (automatic)":$op;
          readingsBulkUpdate($hash, "L3_${d}_Switch", $op);
      }
      readingsBulkUpdate($hash, "state", $state);
      readingsBulkUpdate($hash, "summary", "$sum W");
  } 
  readingsEndUpdate($hash, 1);
  
  delete($hash->{HELPER}{RUNNING_PID});
  $hash->{HELPER}{GETTER} = "all";
  $hash->{HELPER}{SETTER} = "none";
  SPGRefresh($hash,0,1);
  
return;
}

################################################################
##                   Timeout  BlockingCall
################################################################
sub ParseAborted($) {
  my ($hash,$cause) = @_;
  my $name = $hash->{NAME};
   
  $cause = $cause?$cause:"Timeout: process terminated";
  Log3 ($name, 1, "$name - BlockingCall $hash->{HELPER}{RUNNING_PID}{fn} pid:$hash->{HELPER}{RUNNING_PID}{pid} $cause");

  delete($hash->{HELPER}{RUNNING_PID});
  $hash->{HELPER}{GETTER} = "all";
  $hash->{HELPER}{SETTER} = "none";
  
return;
}

################################################################
##             regelmäßig Cookie-Datei löschen
################################################################
sub delcookiefile ($;$) {
   my ($hash,$must) = @_;
   my $name         = $hash->{NAME};
   my ($validperiod, $cookieLocation, $oldlogintime, $delfile);
   
   RemoveInternalTimer($hash,"FHEM::SMAPortal::delcookiefile");
   
   # Gültigkeitsdauer Cookie in Sekunden
   $validperiod    = AttrVal($name, "cookielifetime", 3000);    
   $cookieLocation = AttrVal($name, "cookieLocation", "./log/mycookies.txt"); 
   
   if($must) {
       # Cookie Zwangslöschung
       $delfile = unlink($cookieLocation);
   }
   
   $oldlogintime = $hash->{HELPER}{oldlogintime}?$hash->{HELPER}{oldlogintime}:0;
   
   if($init_done == 1) {
       # Abfrage ob gettimeofday() größer ist als gettimeofday()+$validperiod
       if (gettimeofday() > $oldlogintime+$validperiod) {
            $delfile = unlink($cookieLocation);
       }
   } 
           
   if($delfile) {
       Log3 $name, 3, "$name - cookie file deleted: $cookieLocation";  
   } 
   
   return if(IsDisabled($name));
   
   InternalTimer(gettimeofday()+30, "FHEM::SMAPortal::delcookiefile", $hash, 0);

return;
}

################################################################
##         Auswertung Forecast Daten
################################################################
sub extractForecastData($$) {
  my ($hash,$forecast) = @_;
  my $name = $hash->{NAME};
  
  my $dl = AttrVal($name, "detailLevel", 1);
  
  if($dl <= 1) {
      return;
  }
  
  Log3 ($name, 4, "$name - ##### extracting forecast data #### ");
   
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
  $year    += 1900;
  $mon     += 1;
  my $today = "$year-".sprintf("%02d", $mon)."-".sprintf("%02d", $mday)."T";

  my $PV_sum     = 0;
  my $consum_sum = 0;
  my $sum        = 0;
  
  my $plantOid              = $forecast->{'ForecastTimeframes'}->{'PlantOid'};
  $hash->{HELPER}{PLANTOID} = $plantOid;                                           # wichtig für erweiterte Selektionen
  if ($hash->{HELPER}{PLANTOID}) {
      Log3 ($name, 4, "$name - Plant ID set to: ".$hash->{HELPER}{PLANTOID});
  } else {
      Log3 ($name, 4, "$name - Plant ID  not set !");
  }
  
  
  readingsBeginUpdate($hash);

  # Counter for forecast objects
  my $obj_nr = 0;

  # The next few hours...
  my %nextFewHoursSum = ("PV" => 0, "Consumption" => 0, "Total" => 0, "ConsumpRcmd" => 0);

  # Rest of the day...
  my %restOfDaySum = ("PV" => 0, "Consumption" => 0, "Total" => 0, "ConsumpRcmd" => 0);

  # Tomorrow...
  my %tomorrowSum = ("PV" => 0, "Consumption" => 0, "Total" => 0, "ConsumpRcmd" => 0);

  # Get the current day (for 2016-02-26, this is 26)
  my $current_day = (localtime)[3];

  # Loop through all forecast objects
  # Energie wird als "J" geliefert, Wh = J / 3600
  foreach my $fc_obj (@{$forecast->{'ForecastSeries'}}) {
      my $fc_datetime = $fc_obj->{'TimeStamp'}->{'DateTime'};                       # Example for DateTime: 2016-02-15T23:00:00
      my $tkind       = $fc_obj->{'TimeStamp'}->{'Kind'};                           # Zeitart: Unspecified, Utc

      # Calculate Unix timestamp (month begins at 0, year at 1900)
      my ($fc_year, $fc_month, $fc_day, $fc_hour) = $fc_datetime =~ /^(\d\d\d\d)-(\d\d)-(\d\d)T(\d\d):00:00$/;
      my $fc_uts          = POSIX::mktime( 0, 0, $fc_hour,  $fc_day, $fc_month - 1, $fc_year - 1900 );
      my $fc_diff_seconds = $fc_uts - time + 3600;  # So we go above 0 for the current hour                                                                        
      my $fc_diff_hours   = int( $fc_diff_seconds / 3600 );
      
      # Use also old data to integrate daily PV and Consumption
      if ($current_day == $fc_day) {
         $PV_sum      += int($fc_obj->{'PvMeanPower'}->{'Amount'});                 # integrator of daily PV in Wh
	     $consum_sum  += int($fc_obj->{'ConsumptionForecast'}->{'Amount'}/3600);    # integrator of daily Consumption forecast in Wh
      }

      # Don't use old data
      next if $fc_diff_seconds < 0;

      # Sum up for the next few hours (4 hours total, this is current hour plus the next 3 hours)
      if ($obj_nr < 4) {
         $nextFewHoursSum{'PV'}            += $fc_obj->{'PvMeanPower'}->{'Amount'};                   # Wh
         $nextFewHoursSum{'Consumption'}   += $fc_obj->{'ConsumptionForecast'}->{'Amount'} / 3600;    # Wh
         $nextFewHoursSum{'Total'}         += $fc_obj->{'PvMeanPower'}->{'Amount'} - $fc_obj->{'ConsumptionForecast'}->{'Amount'} / 3600;   # Wh
         $nextFewHoursSum{'ConsumpRcmd'}   += $fc_obj->{'IsConsumptionRecommended'} ? 1 : 0;         
      }

      # If data is for the rest of the current day
      if ( $current_day == $fc_day ) {
         $restOfDaySum{'PV'}            += $fc_obj->{'PvMeanPower'}->{'Amount'};                      # Wh
         $restOfDaySum{'Consumption'}   += $fc_obj->{'ConsumptionForecast'}->{'Amount'} / 3600;       # Wh
         $restOfDaySum{'Total'}         += $fc_obj->{'PvMeanPower'}->{'Amount'} - $fc_obj->{'ConsumptionForecast'}->{'Amount'} / 3600;      # Wh
         $restOfDaySum{'ConsumpRcmd'}   += $fc_obj->{'IsConsumptionRecommended'} ? 1 : 0; 
     }
      
      # If data is for the next day (quick and dirty: current day different from this object's day)
      # Assuming only the current day and the next day are returned from Sunny Portal
      if ( $current_day != $fc_day ) {
         $tomorrowSum{'PV'}            += $fc_obj->{'PvMeanPower'}->{'Amount'} if(exists($fc_obj->{'PvMeanPower'}->{'Amount'}));            # Wh
         $tomorrowSum{'Consumption'}   += $fc_obj->{'ConsumptionForecast'}->{'Amount'} / 3600;                                              # Wh
         $tomorrowSum{'Total'}         += $fc_obj->{'PvMeanPower'}->{'Amount'} - $fc_obj->{'ConsumptionForecast'}->{'Amount'} / 3600 if ($fc_obj->{'PvMeanPower'}->{'Amount'});   # Wh
         $tomorrowSum{'ConsumpRcmd'}   += $fc_obj->{'IsConsumptionRecommended'} ? 1 : 0;
      }
      
      # Update values in Fhem if less than 24 hours in the future
      # TimeStamp Kind:	"Unspecified"
      if($dl >= 2) {
          if ($obj_nr < 24) {
              my $time_str = "ThisHour";
              $time_str = "NextHour".sprintf("%02d", $obj_nr) if($fc_diff_hours>0);
              if($time_str =~ /NextHour/ && $dl >= 4) {
                  readingsBulkUpdate( $hash, "L4_${time_str}_Time", TimeAdjust($hash,$fc_obj->{'TimeStamp'}->{'DateTime'},$tkind) );
                  readingsBulkUpdate( $hash, "L4_${time_str}_PvMeanPower", int( $fc_obj->{'PvMeanPower'}->{'Amount'} )." Wh" );                                     # in W als Durchschnitt geliefet, d.h. eine Stunde -> Wh
                  readingsBulkUpdate( $hash, "L4_${time_str}_Consumption", int( $fc_obj->{'ConsumptionForecast'}->{'Amount'} / 3600 )." Wh" );                      # {'ConsumptionForecast'}->{'Amount'} wird als J = Ws geliefert
                  readingsBulkUpdate( $hash, "L4_${time_str}_IsConsumptionRecommended", ($fc_obj->{'IsConsumptionRecommended'} ? "yes" : "no") );
                  readingsBulkUpdate( $hash, "L4_${time_str}_Total", (int($fc_obj->{'PvMeanPower'}->{'Amount'}) - int($fc_obj->{'ConsumptionForecast'}->{'Amount'} / 3600))." Wh" );
		          
                  # add WeatherId Helper to show weather icon
                  $hash->{HELPER}{"L4_".${time_str}."_WeatherId"} = int($fc_obj->{'WeatherId'}) if(defined $fc_obj->{'WeatherId'});		  
              }
              if($time_str =~ /ThisHour/ && $dl >= 2) {
                  readingsBulkUpdate( $hash, "L2_${time_str}_Time", TimeAdjust($hash,$fc_obj->{'TimeStamp'}->{'DateTime'},$tkind) );
                  readingsBulkUpdate( $hash, "L2_${time_str}_PvMeanPower", int( $fc_obj->{'PvMeanPower'}->{'Amount'} )." Wh" );                                     # in W als Durchschnitt geliefet, d.h. eine Stunde -> Wh
                  readingsBulkUpdate( $hash, "L2_${time_str}_Consumption", int( $fc_obj->{'ConsumptionForecast'}->{'Amount'} / 3600 )." Wh" );                      # {'ConsumptionForecast'}->{'Amount'} wird als J = Ws geliefert
                  readingsBulkUpdate( $hash, "L2_${time_str}_IsConsumptionRecommended", ($fc_obj->{'IsConsumptionRecommended'} ? "yes" : "no") );
                  readingsBulkUpdate( $hash, "L2_${time_str}_Total", (int($fc_obj->{'PvMeanPower'}->{'Amount'}) - int($fc_obj->{'ConsumptionForecast'}->{'Amount'} / 3600))." Wh" );
		          
                  # add WeatherId Helper to show weather icon
		          $hash->{HELPER}{"L2_".${time_str}."_WeatherId"} = int($fc_obj->{'WeatherId'}) if(defined $fc_obj->{'WeatherId'});	           
              }
          }
      }

      # Increment object counter
      $obj_nr++;
  }
  
  if($dl >= 2) {
      readingsBulkUpdate($hash, "L2_Next04Hours_Consumption",              int( $nextFewHoursSum{'Consumption'} )." Wh" );
      readingsBulkUpdate($hash, "L2_Next04Hours_PV",                       int( $nextFewHoursSum{'PV'}          )." Wh" );
      readingsBulkUpdate($hash, "L2_Next04Hours_Total",                    int( $nextFewHoursSum{'Total'}       )." Wh" );
      readingsBulkUpdate($hash, "L2_Next04Hours_IsConsumptionRecommended", int( $nextFewHoursSum{'ConsumpRcmd'} )." h" );
      readingsBulkUpdate($hash, "L2_ForecastToday_Consumption",            $consum_sum." Wh" );                           
      readingsBulkUpdate($hash, "L2_ForecastToday_PV",                     $PV_sum." Wh");                                 
      readingsBulkUpdate($hash, "L2_RestOfDay_Consumption",                int( $restOfDaySum{'Consumption'} )." Wh" );
      readingsBulkUpdate($hash, "L2_RestOfDay_PV",                         int( $restOfDaySum{'PV'}          )." Wh" );
      readingsBulkUpdate($hash, "L2_RestOfDay_Total",                      int( $restOfDaySum{'Total'}       )." Wh" );
      readingsBulkUpdate($hash, "L2_RestOfDay_IsConsumptionRecommended",   int( $restOfDaySum{'ConsumpRcmd'} )." h" );
      readingsBulkUpdate($hash, "L2_Tomorrow_Consumption",                 int( $tomorrowSum{'Consumption'} )." Wh" );
      readingsBulkUpdate($hash, "L2_Tomorrow_PV",                          int( $tomorrowSum{'PV'}          )." Wh" );
      readingsBulkUpdate($hash, "L2_Tomorrow_Total",                       int( $tomorrowSum{'Total'}       )." Wh" );
      readingsBulkUpdate($hash, "L2_Tomorrow_IsConsumptionRecommended",    int( $tomorrowSum{'ConsumpRcmd'} )." h" );
  }

  readingsEndUpdate($hash, 1);

return;
}

################################################################
##         Auswertung Wetterdaten
################################################################
sub extractWeatherData($$) {
  my ($hash,$weather) = @_;
  my $name = $hash->{NAME};
  my ($tsymbol,$ttoday,$ttomorrow);
  
  Log3 ($name, 4, "$name - ##### extracting weather data #### ");
  
  my $dl = AttrVal($name, "detailLevel", 1);
  
  readingsBeginUpdate($hash);
  
  for my $k (keys %$weather) {
      my $new_val = ""; 
      if (defined $weather->{$k}) {
          Log3 $name, 4, "$name - Weatherdata content \"$k\": ".($weather->{$k});
          if ($weather->{$k} =~ m/HASH/i) {
              my $ih = $weather->{$k};
              for my $i (keys %$ih) {
                  my $hd0 = $weather->{$k}{$i};
                  if(!$hd0) {
                      next;
                  }
                  chomp $hd0;
                  $hd0 =~ s/[;']//g;
                  $hd0 = ($hd0 =~ /^undef$/)?"none":$hd0;
                  $hd0 = encode("utf8", $hd0);
                  Log3 $name, 4, "$name - Weatherdata \"$k $i\": $hd0";
                  next if($i =~ /^WeatherIcon$/);
                  $new_val = $hd0;

                  if ($new_val) {
                      if($i =~ /^TemperatureSymbol$/) {
                          $tsymbol = $new_val;
                          next;
                      }
                      if($i =~ /^Temperature$/) {
                          if($k =~ /^today$/) {
                              $ttoday = sprintf("%.1f",$new_val);
                          }
                          if($k =~ /^tomorrow$/) {
                              $ttomorrow = sprintf("%.1f",$new_val);
                          }                          
                          next;
                      } 
                      if($i =~ /^WeatherDescription$/) {
                          $k =~ s/t/T/;
                      }                      
                      
                      Log3 ($name, 4, "$name - ${k}_${i} - $new_val");
                      readingsBulkUpdate($hash, "L1_${k}_${i}", $new_val);
                  }
              }
		  }
      }
  }
  
  readingsBulkUpdate($hash, "L1_Today_Temperature", "$ttoday $tsymbol") if($ttoday && $tsymbol);
  readingsBulkUpdate($hash, "L1_Tomorrow_Temperature", "$ttomorrow $tsymbol") if($ttomorrow && $tsymbol);
  
  readingsEndUpdate($hash, 1); 

return;
}

################################################################
##                     Auswertung Anlagendaten
################################################################
sub extractPlantData($$) {
  my ($hash,$forecast) = @_;
  my $name = $hash->{NAME};
  my ($amount,$unit);
  
  my $dl = AttrVal($name, "detailLevel", 1);
  if($dl <= 1) {
      return;
  }
  
  Log3 ($name, 4, "$name - ##### extracting plant data #### ");
  
  readingsBeginUpdate($hash);
  
  my $ppp = $forecast->{'PlantPeakPower'};
  if($ppp && $dl >= 2) {
      $amount = $forecast->{'PlantPeakPower'}{'Amount'}; 
	  $unit   = $forecast->{'PlantPeakPower'}{'StandardUnit'}{'Symbol'}; 
      Log3 $name, 4, "$name - Plantdata \"PlantPeakPower Amount\": $amount";
	  Log3 $name, 4, "$name - Plantdata \"PlantPeakPower Symbol\": $unit";
  }

  readingsBulkUpdate($hash, "L2_PlantPeakPower", "$amount $unit"); 
  
  readingsEndUpdate($hash, 1); 
  
return;
}

################################################################
##                     Auswertung Consumer Data
################################################################
sub extractConsumerData($$) {
  my ($hash,$forecast) = @_;
  my $name = $hash->{NAME};
  my %consumers;
  my ($key,$val);
  
  my $dl = AttrVal($name, "detailLevel", 1);
  if($dl <= 1) {
      return;
  }
  
  Log3 ($name, 4, "$name - ##### extracting consumer data #### ");
  
  readingsBeginUpdate($hash);
  
  # Schleife über alle Consumer Objekte
  my $i = 0;
  foreach my $c (@{$forecast->{'Consumers'}}) {
      $consumers{"${i}_ConsumerName"} = encode("utf8", $c->{'ConsumerName'} );
      $consumers{"${i}_ConsumerOid"}  = $c->{'ConsumerOid'};
      $i++;
  }
  
  if(%consumers && $forecast->{'ForecastTimeframes'}) {
      # es sind Vorhersagen zu geplanten Verbraucherschaltzeiten vorhanden
      # TimeFrameStart/End Kind: "Utc"
      foreach my $c (@{$forecast->{'ForecastTimeframes'}{'PlannedTimeFrames'}}) {
          my $tkind          = $c->{'TimeFrameStart'}->{'Kind'};                             # Zeitart: Unspecified, Utc
          my $deviceOid      = $c->{'DeviceOid'};   
          my $timeFrameStart = TimeAdjust($hash,$c->{'TimeFrameStart'}{'DateTime'},$tkind);  # wandele UTC        
          my $timeFrameEnd   = TimeAdjust($hash,$c->{'TimeFrameEnd'}{'DateTime'},$tkind);    # wandele UTC
          my $tz             = $c->{'TimeFrameStart'}{'Kind'};
          foreach my $k (keys(%consumers)) {
               $val = $consumers{$k};
               if($val eq $deviceOid) {
                   $k      =~ /^(\d+)_.*$/;
                   my $lfn = $1;
                   # $consumer = $consumers{"${lfn}_ConsumerName"};
                   $consumers{"${lfn}_PlannedOpTimeStart"} = $timeFrameStart;
                   $consumers{"${lfn}_PlannedOpTimeEnd"}   = $timeFrameEnd;
               }
          }          
      }
  }

  if(%consumers) {
      foreach my $key (keys(%consumers)) {
          Log3 $name, 4, "$name - Consumer data \"$key\": ".$consumers{$key};
          if($key =~ /ConsumerName/ && $dl >= 3) {
               $key    =~ /^(\d+)_.*$/;
               my $lfn = $1; 
               my $cn  = $consumers{"${lfn}_ConsumerName"};            # Verbrauchername
               next if(!$cn);
               $cn     = replaceJunkSigns($cn);                        # evtl. Umlaute/Leerzeichen im Verbrauchernamen ersetzen
               my $pos = $consumers{"${lfn}_PlannedOpTimeStart"};      # geplanter Start
               my $poe = $consumers{"${lfn}_PlannedOpTimeEnd"};        # geplantes Ende
               my $rb  = "L3_${cn}_PlannedOpTimeBegin"; 
               my $re  = "L3_${cn}_PlannedOpTimeEnd";
			   my $rp  = "L3_${cn}_Planned";
               if($pos) {             
                   readingsBulkUpdate($hash, $rb, $pos); 
                   readingsBulkUpdate($hash, $rp, "yes");  				   
               } else {
                   readingsBulkUpdate($hash, $rb, "undefined"); 
				   readingsBulkUpdate($hash, $rp, "no");  
               }   
               if($poe) {             
                   readingsBulkUpdate($hash, $re, $poe);          
               } else {
                   readingsBulkUpdate($hash, $re, "undefined");
               }                  
          }
      }
  }
  
  readingsEndUpdate($hash, 1); 
  
return;
} 

################################################################
##          Auswertung Consumer Livedata
################################################################
sub extractConsumerLiveData($$) {
  my ($hash,$clivedata) = @_;
  my $name = $hash->{NAME};
  my %consumers;
  my ($key,$val,$i,$res);
  
  my $dl = AttrVal($name, "detailLevel", 1);
  if($dl <= 2) {
      return;
  }
  
  Log3 ($name, 4, "$name - ##### extracting consumer live data #### ");
  
  readingsBeginUpdate($hash);
  
  # allen Consumer Objekte die ID zuordnen
  $i = 0;
  foreach my $c (@{$clivedata->{'MeasurementData'}}) {
      $consumers{"${i}_ConsumerName"} = encode("utf8", $c->{'DeviceName'} );
      $consumers{"${i}_ConsumerOid"}  = $c->{'Consume'}{'ConsumerOid'};
      $consumers{"${i}_ConsumerLfd"}  = $i;
	  my $cpower                      = $c->{'Consume'}{'Measurement'};           # aktueller Energieverbrauch in W
	  my $cn                          = $consumers{"${i}_ConsumerName"};          # Verbrauchername
      next if(!$cn);
      $cn                             = replaceJunkSigns($cn);
      
      $hash->{HELPER}{CONSUMER}{$i}{DeviceName}   = $cn;
      $hash->{HELPER}{CONSUMER}{$i}{ConsumerOid}  = $consumers{"${i}_ConsumerOid"};
      $hash->{HELPER}{CONSUMER}{$i}{SerialNumber} = $c->{'SerialNumber'};
      $hash->{HELPER}{CONSUMER}{$i}{SUSyID}       = $c->{'SUSyID'};

      readingsBulkUpdate($hash, "L3_${cn}_Power", $cpower." W") if(defined($cpower));      
	  
      $i++;
  }
  
  if(%consumers && $clivedata->{'ParameterData'}) {
      # es sind Daten zu den Verbrauchern vorhanden
      # Kind: "Utc" ?
      $i = 0;
      foreach my $c (@{$clivedata->{'ParameterData'}}) {
          my $tkind            = $c->{'Parameters'}[0]{'Timestamp'}{'Kind'};                               # Zeitart: Unspecified, Utc
          # Log3 ($name, 1, "$name - $tkind");
          my $GriSwStt         = $c->{'Parameters'}[0]{'Value'};                                           # on: 1, off: 0
          my $GriSwAuto        = $c->{'Parameters'}[1]{'Value'};                                           # automatic = 1
          my $OperationAutoEna = $c->{'Parameters'}[2]{'Value'};                                           # Automatic Betrieb erlaubt ?
		  my $ltchange         = TimeAdjust($hash,$c->{'Parameters'}[0]{'Timestamp'}{'DateTime'},$tkind);  # letzter Schaltzeitpunkt der Bluetooth-Steckdose (Verbraucher)
          my $cn  = $consumers{"${i}_ConsumerName"};                                                       # Verbrauchername
          next if(!$cn);
          $cn     = replaceJunkSigns($cn);                                                                 # evtl. Umlaute/Leerzeichen im Verbrauchernamen ersetzen
          
          if(!$GriSwStt && $GriSwAuto) {
              $res = "off (automatic)";
          } elsif (!$GriSwStt && !$GriSwAuto) {
              $res = "off";         
          } elsif ($GriSwStt) {
              $res = "on";           
          } else {
              $res = "undefined";            
          }
          
          readingsBulkUpdate($hash, "L3_${cn}_Switch", $res);
		  readingsBulkUpdate($hash, "L3_${cn}_SwitchLastTime", $ltchange);
          
          $i++;
      }
  }
  
  readingsEndUpdate($hash, 1); 
  
return;
}

################################################################
##          Auswertung Consumer History Energy Data
##          $tf = Time Frame
################################################################
sub extractConsumerHistData($$$) {
  my ($hash,$chdata,$tf) = @_;
  my $name               = $hash->{NAME};
  my ($bdcd,$bcd);
  my %consumers;
  my ($key,$val,$i,$res,$gcr,$gct,$pcr,$pct,$tct,$bcr,$bct);
  
  my $dl = AttrVal($name, "detailLevel", 1);
  if($dl <= 2) {
      return;
  }
  
  Log3 ($name, 4, "$name - ##### extracting consumer history data #### ");
  
  my $bataval = (defined(ReadingsNum($name,"L1_BatteryIn", undef)) || defined(ReadingsNum($name,"L1_BatteryOut", undef)))?1:0;     # Identifikation ist Battery vorhanden ?
      
  readingsBeginUpdate($hash);
  
  # allen Consumer Objekte die ID zuordnen
  $i = 0;
  foreach my $c (@{$chdata->{'Consumers'}}) {
      $consumers{"${i}_ConsumerName"} = encode("utf8", $c->{'DeviceName'} );
      $consumers{"${i}_ConsumerOid"}  = $c->{'ConsumerOid'};
      $consumers{"${i}_ConsumerLfd"}  = $i;
	  my $cpower                      = $c->{'TotalEnergy'}{'Measurement'};    # Energieverbrauch im Timeframe in Wh                                         
	  my $cn                          = $consumers{"${i}_ConsumerName"};       # Verbrauchername
      next if(!$cn);
      $cn                             = replaceJunkSigns($cn);
      
      if($tf =~ /month|year/) {
          $tct = $c->{'TotalEnergyMix'}{'TotalConsumptionTotal'};              # Gesamtverbrauch im Timeframe in Wh
          $gcr = $c->{'TotalEnergyMix'}{'GridConsumptionRelative'};            # Anteil des Netzbezugs im Timeframe am Gesamtverbrauch in %
          $gct = $c->{'TotalEnergyMix'}{'GridConsumptionTotal'};               # Anteil des Netzbezugs im Timeframe am Gesamtverbrauch in Wh
          $pcr = $c->{'TotalEnergyMix'}{'PvConsumptionRelative'};              # Anteil des PV-Nutzung im Timeframe am Gesamtverbrauch in %
          $pct = $c->{'TotalEnergyMix'}{'PvConsumptionTotal'};                 # Anteil des PV-Nutzung im Timeframe am Gesamtverbrauch in Wh
          $bcr = $c->{'TotalEnergyMix'}{'BatteryConsumptionRelative'};         # Anteil der Batterie-Nutzung im Timeframe am Gesamtverbrauch in %
          $bct = $c->{'TotalEnergyMix'}{'BatteryConsumptionTotal'};            # Anteil der Batterie-Nutzung im Timeframe am Gesamtverbrauch in Wh
      }
      
      readingsBulkUpdate($hash, "L3_${cn}_EnergyTotalDay",          sprintf("%.0f", $cpower)." Wh") if(defined($cpower) && $tf eq "day"); 
      readingsBulkUpdate($hash, "L3_${cn}_EnergyTotalMonth",        sprintf("%.0f", $cpower)." Wh") if(defined($cpower) && $tf eq "month");  
      readingsBulkUpdate($hash, "L3_${cn}_EnergyTotalYear",         sprintf("%.0f", $cpower)." Wh") if(defined($cpower) && $tf eq "year");  
	  
      readingsBulkUpdate($hash, "L3_${cn}_EnergyRelativeMonthGrid", sprintf("%.0f", $gcr)." %")     if(defined($gcr) && $tf eq "month");            
      readingsBulkUpdate($hash, "L3_${cn}_EnergyTotalMonthGrid",    sprintf("%.0f", $gct)." Wh")    if(defined($gct) && $tf eq "month");
      readingsBulkUpdate($hash, "L3_${cn}_EnergyRelativeMonthPV",   sprintf("%.0f", $pcr)." %")     if(defined($pcr) && $tf eq "month");                  
      readingsBulkUpdate($hash, "L3_${cn}_EnergyTotalMonthPV",      sprintf("%.0f", $pct)." Wh")    if(defined($pct) && $tf eq "month");
      readingsBulkUpdate($hash, "L3_${cn}_EnergyRelativeMonthBatt", sprintf("%.0f", $bcr)." %")     if(defined($bcr) && $bataval && $tf eq "month");   	
      readingsBulkUpdate($hash, "L3_${cn}_EnergyTotalMonthBatt",    sprintf("%.0f", $bct)." Wh")    if(defined($bct) && $bataval && $tf eq "month");	  

	  readingsBulkUpdate($hash, "L3_${cn}_EnergyRelativeYearGrid",  sprintf("%.0f", $gcr)." %")     if(defined($gcr) && $tf eq "year");            
      readingsBulkUpdate($hash, "L3_${cn}_EnergyTotalYearGrid",     sprintf("%.0f", $gct)." Wh")    if(defined($gct) && $tf eq "year");
      readingsBulkUpdate($hash, "L3_${cn}_EnergyRelativeYearPV",    sprintf("%.0f", $pcr)." %")     if(defined($pcr) && $tf eq "year");                  
      readingsBulkUpdate($hash, "L3_${cn}_EnergyTotalYearPV",       sprintf("%.0f", $pct)." Wh")    if(defined($pct) && $tf eq "year");
      readingsBulkUpdate($hash, "L3_${cn}_EnergyRelativeYearBatt",  sprintf("%.0f", $bcr)." %")     if(defined($bcr) && $bataval && $tf eq "year");  
      readingsBulkUpdate($hash, "L3_${cn}_EnergyTotalYearBatt",     sprintf("%.0f", $bct)." Wh")    if(defined($bct) && $bataval && $tf eq "year");	  
      
      $i++;
  }
    
  readingsEndUpdate($hash, 1); 
  
return;
}

################################################################
# sortiert eine Liste von Versionsnummern x.x.x
# Schwartzian Transform and the GRT transform
# Übergabe: "asc | desc",<Liste von Versionsnummern>
################################################################
sub sortVersionNum (@) {
  my ($sseq,@versions) = @_;

  my @sorted = map {$_->[0]}
			   sort {$a->[1] cmp $b->[1]}
			   map {[$_, pack "C*", split /\./]} @versions;
			 
  @sorted = map {join ".", unpack "C*", $_}
            sort
            map {pack "C*", split /\./} @versions;
  
  if($sseq eq "desc") {
      @sorted = reverse @sorted;
  }
  
return @sorted;
}

################################################################
#               Versionierungen des Moduls setzen
#  Die Verwendung von Meta.pm und Packages wird berücksichtigt
################################################################
sub setVersionInfo($) {
  my ($hash) = @_;
  my $name   = $hash->{NAME};

  my $v                    = (sortTopicNum("desc",keys %vNotesIntern))[0];
  my $type                 = $hash->{TYPE};
  $hash->{HELPER}{PACKAGE} = __PACKAGE__;
  $hash->{HELPER}{VERSION} = $v;
  
  if($modules{$type}{META}{x_prereqs_src} && !$hash->{HELPER}{MODMETAABSENT}) {
	  # META-Daten sind vorhanden
	  $modules{$type}{META}{version} = "v".$v;              # Version aus META.json überschreiben, Anzeige mit {Dumper $modules{SMAPortal}{META}}
	  if($modules{$type}{META}{x_version}) {                                                                             # {x_version} ( nur gesetzt wenn $Id: 76_SMAPortal.pm 19815 2019-07-10 22:15:43Z DS_Starter $ im Kopf komplett! vorhanden )
		  $modules{$type}{META}{x_version} =~ s/1.1.1/$v/g;
	  } else {
		  $modules{$type}{META}{x_version} = $v; 
	  }
	  return $@ unless (FHEM::Meta::SetInternals($hash));                                                                # FVERSION wird gesetzt ( nur gesetzt wenn $Id: 76_SMAPortal.pm 19815 2019-07-10 22:15:43Z DS_Starter $ im Kopf komplett! vorhanden )
	  if(__PACKAGE__ eq "FHEM::$type" || __PACKAGE__ eq $type) {
	      # es wird mit Packages gearbeitet -> Perl übliche Modulversion setzen
		  # mit {<Modul>->VERSION()} im FHEMWEB kann Modulversion abgefragt werden
	      use version 0.77; our $VERSION = FHEM::Meta::Get( $hash, 'version' );                                          
      }
  } else {
	  # herkömmliche Modulstruktur
	  $hash->{VERSION} = $v;
  }
  
return;
}

################################################################
#                 delete Readings
#   $dl = detailLevel ab dem das Reading gelöscht werden soll 
################################################################
sub delread($;$) {
  my ($hash,$dl) = @_;
  my $name   = $hash->{NAME};
  my @allrds = keys%{$defs{$name}{READINGS}};
 
  if($dl) {
      # Readings ab dem angegebenen Detail-Level löschen
      foreach my $key(@allrds) {
          $key =~ m/^L(\d)_.*$/;     
          if($1 && $1 >= $dl) {
              delete($defs{$name}{READINGS}{$key});
          }         
      }
      return;
  } 

  foreach my $key(@allrds) {
      delete($defs{$name}{READINGS}{$key}) if($key ne "state");
  }

return;
}

################################################################
#              
################################################################
sub setFromBlocking($$$) {
  my ($name,$get,$set) = @_;
  my $hash             = $defs{$name};

  $hash->{HELPER}{GETTER} = $get;
  $hash->{HELPER}{SETTER} = $set;

return;
}

################################################################
#                 analysiere Livedaten
################################################################
sub analivedat($$) {
  my ($hash,$lc) = @_;
  my $name       = $hash->{NAME};
  my ($reread,$retry) = (0,0);

  my $livedata_content = decode_json($lc);
  for my $k (keys %$livedata_content) {
      my $new_val = "";
      
      if (defined $livedata_content->{$k}) {
          if (($livedata_content->{$k} =~ m/ARRAY/i) || ($livedata_content->{$k} =~ m/HASH/i)) {
              if($livedata_content->{$k} =~ m/ARRAY/i) {
                  my $hd0 = Dumper($livedata_content->{$k}[0]);
                  if(!$hd0) {
                      next;
                  }
                  chomp $hd0;
                  $hd0 =~ s/[;']//g;
                  $hd0 = ($hd0 =~ /^undef$/)?"none":$hd0;
                  # Log3 $name, 4, "$name - livedata ARRAY content \"$k\": $hd0";
                  $new_val = $hd0;
              }
		  } else {
              $new_val = $livedata_content->{$k};
          }

          if ($new_val && $k !~ /__type/i) {
			  if($k =~ /InfoMessages/ && $new_val =~ /.*login to SMA-Portal successful.*/) {
			      # Login war erfolgreich, Daten neu lesen
			      Log3 $name, 3, "$name - get data again";
				  $reread = 1;
			  }
			  if($k =~ /ErrorMessages/ && $new_val =~ /.*The current data cannot be retrieved from the PV system. Check the cabling and configuration of the following energy meters.*/) {
			      # Energiedaten konnten nicht ermittelt werden, Daten neu lesen mit Zeitverzögerung
			      Log3 $name, 3, "$name - The current data cannot be retrieved from PV system, get data again.";
				  $retry = 1;
			  }
			  if($k =~ /ErrorMessages/ && $new_val =~ /.*Communication with the Sunny Home Manager is currently not possible.*/) {
			      # Energiedaten konnten nicht ermittelt werden, Daten neu lesen mit Zeitverzögerung
			      Log3 $name, 3, "$name - Communication with the Sunny Home Manager currently impossible, get data again.";
				  $retry = 1;
			  }
          }
      }
  }
  
return ($reread,$retry);
}

################################################################
#                    Restart get Data
################################################################
sub retrygetdata($) {
  my ($hash)  = @_;
  my $name    = $hash->{NAME};
  my $timeout = AttrVal($name, "timeout", 30);
  
  my $get = $hash->{HELPER}{GETTER};
  my $set = $hash->{HELPER}{SETTER};

  $hash->{HELPER}{RUNNING_PID} = BlockingCall("FHEM::SMAPortal::GetSetData", "$name|$get|$set", "FHEM::SMAPortal::ParseData", $timeout, "FHEM::SMAPortal::ParseAborted", $hash);
  $hash->{HELPER}{RUNNING_PID}{loglevel} = 5 if($hash->{HELPER}{RUNNING_PID});  # Forum #77057
	  
return;
}

################################################################
#                   Timestamp korrigieren
################################################################
sub TimeAdjust($$$) {
  my ($hash,$t,$tkind) = @_;
  $t =~ s/T/ /;
  my ($datehour, $rest) = split(/:/,$t,2);
  my ($year, $month, $day, $hour) = $datehour =~ /(\d+)-(\d\d)-(\d\d)\s+(\d\d)/;
  
  #  Time::timegm - a UTC version of mktime()
  #  proto: $time = timegm($sec,$min,$hour,$mday,$mon,$year);
  my $epoch = timegm(0,0,$hour,$day,$month-1,$year);
  
  #  proto: ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
  my (undef,undef,undef,undef,undef,undef,undef,undef,$isdst) = localtime(time);
  
  if(lc($tkind) =~ /unspecified/) {
      if($isdst) {
          $epoch = $epoch - 7200;
      } else {
          $epoch = $epoch - 3600;
      }
  }
  
  #  proto: ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
  my ($lyear,$lmonth,$lday,$lhour) = (localtime($epoch))[5,4,3,2];
  
  $lyear += 1900;                  # year is 1900 based
  $lmonth++;                       # month number is zero based
  
  if(AttrVal("global","language","EN") eq "DE") {
	  return (sprintf("%02d.%02d.%04d %02d:%s", $lday,$lmonth,$lyear,$lhour,$rest));
  } else {
	  return (sprintf("%04d-%02d-%02d %02d:%s", $lyear,$lmonth,$lday,$lhour,$rest));
  }
}

###############################################################################
#       Umlaute und ungültige Zeichen für Readingerstellung ersetzen 
###############################################################################
sub replaceJunkSigns ($) { 
  my ($rn) = @_;

  $rn =~ s/ß/ss/g;
  $rn =~ s/ä/ae/g;
  $rn =~ s/ö/oe/g;
  $rn =~ s/ü/ue/g;
  $rn =~ s/Ä/Ae/g;
  $rn =~ s/Ö/Oe/g;
  $rn =~ s/Ü/Ue/g; 
  $rn = makeReadingName($rn);  
  
return($rn);
}

###############################################################################
#                  Subroutine für Portalgrafik
###############################################################################
sub PortalAsHtml ($$;$) { 
  my ($name,$wlname,$ftui) = @_;
  my $hash                 = $defs{$name};
  my $ret                  = "";
  
  my ($i,$icon,$colorv,$colorc,$maxhours,$hourstyle,$header,$legend,$legend_txt,$legend_style);
  my ($val,$height,$fsize,$html_start,$html_end,$wlalias,$weather,$colorw,$maxVal,$show_night,$type,$kw);
  my ($maxDif,$minDif,$maxCon,$v,$z2,$z3,$z4,$show_diff,$width,$w,$hdrDetail,$hdrAlign);
  my $he;                                                                               # Balkenhöhe
  my (%pv,%is,%t,%we,%di,%co);
  my @pgCDev;
  
  # Kontext des aufrufenden SMAPortalSPG-Devices speichern für Refresh
  $hash->{HELPER}{SPGDEV}    = $wlname;                                                 # Name des aufrufenden SMAPortalSPG-Devices
  $hash->{HELPER}{SPGROOM}   = $FW_room?$FW_room:"";                                    # Raum aus dem das SMAPortalSPG-Device die Funktion aufrief
  $hash->{HELPER}{SPGDETAIL} = $FW_detail?$FW_detail:"";                                # Name des SMAPortalSPG-Devices (wenn Detailansicht)
  
  my $dl  = AttrVal($name, "detailLevel", 1);
  my $pv0 = ReadingsNum($name,"L2_ThisHour_PvMeanPower", undef);
  my $pv1 = ReadingsNum($name,"L4_NextHour01_PvMeanPower", undef);
  if(!$hash || !defined($defs{$wlname}) || $dl != 4 || !defined $pv0 || !defined $pv1) {
      $height   = AttrNum($wlname, 'beamHeight', 200);   
      $ret     .= "<table class='roomoverview'>";
      $ret     .= "<tr style='height:".$height."px'>";
      $ret     .= "<td>";
      if(!$hash) {
          $ret .= "Device \"$name\" doesn't exist !";
      } elsif (!defined($defs{$wlname})) {
          $ret .= "Graphic device \"$wlname\" doesn't exist !";
      } elsif ($dl != 4) {
          $ret .= "The attribute \"detailLevel\" of device \"$name\" has to be set to level \"4\" !";
      } elsif (!defined $pv0) {
          $ret .= "Awaiting level 2 data ...";
      } elsif (!defined $pv1) {
          $ret .= "Awaiting level 4 data ...";
      }

      $ret     .= "</td>";
      $ret     .= "</tr>";
      $ret     .= "</table>";
      return $ret;
  }

  @pgCDev = split(',',AttrVal($wlname,"consumerList",""));                              # definierte Verbraucher ermitteln
  ($legend_style, $legend) = split('_',AttrVal($wlname,'consumerLegend','icon_top'));

  $legend = '' if(($legend_style eq 'none') || (!int(@pgCDev)));
  
  # Verbraucherlegende und Steuerung
  if ($legend) {
      foreach (@pgCDev) {
          my($txt,$im) = split(':',$_);                                                 # $txt ist der Verbrauchername
		  my $cmdon   = "\"FW_cmd('$FW_ME$FW_subdir?XHR=1&cmd=set $name $txt on')\"";
          my $cmdoff  = "\"FW_cmd('$FW_ME$FW_subdir?XHR=1&cmd=set $name $txt off')\"";
          my $cmdauto = "\"FW_cmd('$FW_ME$FW_subdir?XHR=1&cmd=set $name $txt auto')\"";
          
          if ($ftui && $ftui eq "ftui") {
              $cmdon   = "\"ftui.setFhemStatus('set $name $txt on')\"";
              $cmdoff  = "\"ftui.setFhemStatus('set $name $txt off')\"";
              $cmdauto = "\"ftui.setFhemStatus('set $name $txt auto')\"";      
          }
          
          my $swstate  = ReadingsVal($name,"L3_".$txt."_Switch", "undef");
		  my $swicon   = "<img src=\"$FW_ME/www/images/default/1px-spacer.png\">";
		  if($swstate eq "off") {
		      $swicon = "<a onClick=$cmdon><img src=\"$FW_ME/www/images/default/10px-kreis-rot.png\"></a>";
		  } elsif ($swstate eq "on") {
		      $swicon = "<a onClick=$cmdauto><img src=\"$FW_ME/www/images/default/10px-kreis-gruen.png\"></a>";
		  } elsif ($swstate =~ /off.*automatic.*/i) {
		      $swicon = "<a onClick=$cmdon><img src=\"$FW_ME/www/images/default/10px-kreis-gelb.png\"></a>";
		  }
		  
          if ($legend_style eq 'icon') {                                                           # mögliche Umbruchstellen mit normalen Blanks vorsehen !
              $legend_txt .= $txt.'&nbsp;'.FW_makeImage($im).' '.$swicon.'&nbsp;&nbsp;'; 
          } else {
              my (undef,$co) = split('\@',$im);
              $co = '#cccccc' if (!$co);                                                           # Farbe per default
              $legend_txt .= '<font color=\''.$co.'\'>'.$txt.'</font> '.$swicon.'&nbsp;&nbsp;';    # hier auch Umbruch erlauben
          }
      }
  }

  # Parameter f. Anzeige extrahieren
  $maxhours   =  AttrNum($wlname, 'hourCount',             24);
  $hourstyle  =  AttrVal($wlname, 'hourStyle',          undef);
  $colorv     =  AttrVal($wlname, 'beamColor',          undef);
  $colorc     =  AttrVal($wlname, 'beamColor2',      '000000');                         # schwarz wenn keine Userauswahl;
  $icon       =  AttrVal($wlname, 'consumerAdviceIcon', undef);
  $html_start =  AttrVal($wlname, 'htmlStart',          undef);                         # beliebige HTML Strings die vor der Grafik ausgegeben werden
  $html_end   =  AttrVal($wlname, 'htmlEnd',            undef);                         # beliebige HTML Strings die nach der Grafik ausgegeben werden

  $type       =  AttrVal($wlname, 'layoutType',          'pv');
  $kw         =  AttrVal($wlname, 'Wh/kWh',              'Wh');

  $height     =  AttrNum($wlname, 'beamHeight',           200);
  $width      =  AttrNum($wlname, 'beamWidth',              6);                         # zu klein ist nicht problematisch
  $w          =  $width*$maxhours;                                                      # gesammte Breite der Ausgabe , WetterIcon braucht ca. 34px
  $fsize      =  AttrNum($wlname, 'spaceSize',             24);
  $maxVal     =  AttrNum($wlname, 'maxPV',                  0);                         # dyn. Anpassung der Balkenhöhe oder statisch ?

  $show_night =  AttrNum($wlname, 'showNight',              0);                         # alle Balken (Spalten) anzeigen ?
  $show_diff  =  AttrVal($wlname, 'showDiff',            'no');                         # zusätzliche Anzeige $di{} in allen Typen
  $weather    =  AttrNum($wlname, 'showWeather',            1);
  $colorw     =  AttrVal($wlname, 'weatherColor',       undef);

  $wlalias    =  AttrVal($wlname, 'alias',            $wlname);
  $header     =  AttrNum($wlname, 'showHeader', 1); 
  $hdrAlign   =  AttrVal($wlname, 'headerAlignment', 'center');  						# ermöglicht per attr die Ausrichtung der Tabelle zu setzen
  $hdrDetail  =  AttrVal($wlname, 'headerDetail', 	    'all'); 						# ermöglicht den Inhalt zu begrenzen, um bspw. passgenau in ftui einzubetten

  # Icon Erstellung, mit @<Farbe> ergänzen falls einfärben
  # Beispiel mit Farbe:  $icon = FW_makeImage('light_light_dim_100.svg@green');
 
  $icon    = FW_makeImage($icon) if (defined($icon));
 
  my $co4h = ReadingsNum($name,"L2_Next04Hours_Consumption", 0);
  my $coRe = ReadingsNum($name,"L2_RestOfDay_Consumption", 0); 
  my $coTo = ReadingsNum($name,"L2_Tomorrow_Consumption", 0);

  my $pv4h = ReadingsNum($name,"L2_Next04Hours_PV", 0);
  my $pvRe = ReadingsNum($name,"L2_RestOfDay_PV", 0); 
  my $pvTo = ReadingsNum($name,"L2_Tomorrow_PV", 0);

  if ($kw eq 'kWh') {
      $co4h = sprintf("%.1f" , $co4h/1000)."&nbsp;kWh";
      $coRe = sprintf("%.1f" , $coRe/1000)."&nbsp;kWh";
      $coTo = sprintf("%.1f" , $coTo/1000)."&nbsp;kWh";
      $pv4h = sprintf("%.1f" , $pv4h/1000)."&nbsp;kWh";
      $pvRe = sprintf("%.1f" , $pvRe/1000)."&nbsp;kWh";
      $pvTo = sprintf("%.1f" , $pvTo/1000)."&nbsp;kWh";
  } else {
      $co4h .= "&nbsp;Wh";
      $coRe .= "&nbsp;Wh";
      $coTo .= "&nbsp;Wh";
      $pv4h .= "&nbsp;Wh";
      $pvRe .= "&nbsp;Wh";
      $pvTo .= "&nbsp;Wh";
  }

  
  # Headerzeile generieren                                                                                                             
  if ($header) {
	  my $lang    = AttrVal("global","language","EN");
      my $alias   = AttrVal($name, "alias", "SMA Sunny Portal");                   # Linktext als Aliasname oder "SMA Sunny Portal"
      my $dlink   = "<a href=\"/fhem?detail=$name\">$alias</a>"; 	  
      my $lup     = ReadingsTimestamp($name, "state", "0000-00-00 00:00:00");      # letzte Updatezeit	
	  
	  my $lupt    = "last update:";  
	  my $lblPv4h = "4h:";
	  my $lblPvRe = "today:";
	  my $lblPvTo = "tomorrow:";
	 
	  if(AttrVal("global","language","EN") eq "DE") {                              # Header globales Sprachschema Deutsch
	    $lupt     = "Stand:"; 
		$lblPvRe  = "heute:";
		$lblPvTo  = "morgen:";
	  }	 

	  $header  = "<table align=\"$hdrAlign\">";	
	  
	  # Header Link + Status 
	  if($hdrDetail eq "all" || $hdrDetail eq "statusLink") {
		my ($year, $month, $day, $hour, $min, $sec) = $lup =~ /(\d+)-(\d\d)-(\d\d)\s+(.*)/;
		$lup     = "$3.$2.$1 $4";
		$header .= "<tr><td colspan=\"3\" align=\"left\"><b>".$dlink."</b></td><td colspan=\"4\" align=\"right\">(".$lupt."&nbsp;".$lup.")</td></tr>";
      }
	  
	  # Header Information pv 
	  if($hdrDetail eq "all" || $hdrDetail eq "pv" || $hdrDetail eq "pvco") {	
		$header .= "<tr> <td><b>PV&nbsp;=></b></td> <td><b>$lblPv4h</b></td> <td align=right>$pv4h</td> <td><b>$lblPvRe</b></td> <td align=right>$pvRe</td> <td><b>$lblPvTo</b></td> <td align=right>$pvTo</td> </tr>";
	  }
	  
	  # Header Information co 
	  if($hdrDetail eq "all" || $hdrDetail eq "co" || $hdrDetail eq "pvco") {
		$header .= "<tr> <td><b>CO&nbsp;=></b></td> <td><b>$lblPv4h</b></td> <td align=right>$co4h</td> <td><b>$lblPvRe</b></td> <td align=right>$coRe</td> <td><b>$lblPvTo</b></td> <td align=right>$coTo</td> </tr>";	
	  }

      $header .= "</table>";	 
  }

  # Werte aktuelle Stunde
  $pv{0} = ReadingsNum($name,"L2_ThisHour_PvMeanPower", 0);
  $co{0} = ReadingsNum($name,"L2_ThisHour_Consumption", 0);
  $di{0} = $pv{0} - $co{0}; 
  $is{0} = (ReadingsVal($name,"L2_ThisHour_IsConsumptionRecommended",'no') eq 'yes' ) ? $icon : undef;  
  $we{0} = $hash->{HELPER}{L2_ThisHour_WeatherId} if($weather);              # für Wettericons 
  $we{0} = $we{0}?$we{0}:0;

  if(AttrVal("global","language","EN") eq "DE") {
      (undef,undef,undef,$t{0}) = ReadingsVal($name,"L2_ThisHour_Time",'0') =~ m/(\d{2}).(\d{2}).(\d{4})\s(\d{2})/;
  } else {
      (undef,undef,undef,$t{0}) = ReadingsVal($name,"L2_ThisHour_Time",'0') =~ m/(\d{4})-(\d{2})-(\d{2})\s(\d{2})/;
  }
  
  $t{0} = int($t{0});                                                        # zum Rechnen Integer ohne führende Null

  ###########################################################
  # get consumer list and display it in portalGraphics 
  foreach (@pgCDev) {
      my ($itemName, undef) = split(':',$_);
      $itemName =~ s/^\s+|\s+$//g;                                           #trim it, if blanks were used
      $_        =~ s/^\s+|\s+$//g;                                           #trim it, if blanks were used
    
      #check if listed device is planned
      if (ReadingsVal($name, "L3_".$itemName."_Planned", "no") eq "yes") {
          #get start and end hour
          my ($start, $end);                                                   # werden auf Balken Pos 0 - 23 umgerechnet, nicht auf Stunde !!, Pos = 24 -> ungültige Pos = keine Anzeige

          if(AttrVal("global","language","EN") eq "DE") {
              (undef,undef,undef,$start) = ReadingsVal($name,"L3_".$itemName."_PlannedOpTimeBegin",'00.00.0000 24') =~ m/(\d{2}).(\d{2}).(\d{4})\s(\d{2})/;
              (undef,undef,undef,$end)   = ReadingsVal($name,"L3_".$itemName."_PlannedOpTimeEnd",'00.00.0000 24')   =~ m/(\d{2}).(\d{2}).(\d{4})\s(\d{2})/;
          } else {
              (undef,undef,undef,$start) = ReadingsVal($name,"L3_".$itemName."_PlannedOpTimeBegin",'0000-00-00 24') =~ m/(\d{4})-(\d{2})-(\d{2})\s(\d{2})/;
              (undef,undef,undef,$end)   = ReadingsVal($name,"L3_".$itemName."_PlannedOpTimeEnd",'0000-00-00 24')   =~ m/(\d{4})-(\d{2})-(\d{2})\s(\d{2})/;
          }

          $start = int($start);
          $end   = int($end);
          my $flag = 0;                                                 # default kein Tagesverschieber

          #correct the hour for accurate display
          if ($start < $t{0}) {                                         # consumption seems to be tomorrow
              $start = 24-$t{0}+$start;
              $flag = 1;
          } else { 
              $start -= $t{0};          
          }

          if ($flag) {                                                  # consumption seems to be tomorrow
              $end = 24-$t{0}+$end;
          } else { 
              $end -= $t{0}; 
          }

          $_ .= ":".$start.":".$end;

      } else { 
          $_ .= ":24:24"; 
      } 
      Log3($name, 4, "$name - Consumer planned data: $_");
  }

  $maxVal = (!$maxVal) ? $pv{0} : $maxVal;                  # Startwert wenn kein Wert bereits via attr vorgegeben ist
  $maxCon = $co{0};                                         # für Typ co
  $maxDif = $di{0};                                         # für Typ diff
  $minDif = $di{0};                                         # für Typ diff

  foreach $i (1..$maxhours-1) {
     $pv{$i} = ReadingsNum($name,"L4_NextHour".sprintf("%02d",$i)."_PvMeanPower",0);             # Erzeugung
     $co{$i} = ReadingsNum($name,"L4_NextHour".sprintf("%02d",$i)."_Consumption",0);             # Verbrauch
     $di{$i} = $pv{$i} - $co{$i};

     $maxVal = $pv{$i} if ($pv{$i} > $maxVal); 
     $maxCon = $co{$i} if ($co{$i} > $maxCon);
     $maxDif = $di{$i} if ($di{$i} > $maxDif);
     $minDif = $di{$i} if ($di{$i} < $minDif);

     $is{$i} = (ReadingsVal($name,"L4_NextHour".sprintf("%02d",$i)."_IsConsumptionRecommended",'no') eq 'yes') ? $icon : undef;
	 $we{$i} = $hash->{HELPER}{"L4_NextHour".sprintf("%02d",$i)."_WeatherId"} if($weather);      # für Wettericons 
	 $we{$i} = $we{$i}?$we{$i}:0;

     if(AttrVal("global","language","EN") eq "DE") {
        (undef,undef,undef,$t{$i}) = ReadingsVal($name,"L4_NextHour".sprintf("%02d",$i)."_Time",'0') =~ m/(\d{2}).(\d{2}).(\d{4})\s(\d{2})/;
     } else {
        (undef,undef,undef,$t{$i}) = ReadingsVal($name,"L4_NextHour".sprintf("%02d",$i)."_Time",'0') =~ m/(\d{4})-(\d{2})-(\d{2})\s(\d{2})/;
     }

     $t{$i} = int($t{$i});                                  # keine führende 0
  }

  ######################################
  # Tabellen Ausgabe erzeugen
  
  # Wenn Table class=block alleine steht, zieht es bei manchen Styles die Ausgabe auf 100% Seitenbreite
  # lässt sich durch einbetten in eine zusätzliche Table roomoverview eindämmen
  # Die Tabelle ist recht schmal angelegt, aber nur so lassen sich Umbrüche erzwingen
   
  $ret  = "<html>";
  $ret .= $html_start if (defined($html_start));
  $ret .= "<style>TD.smaportal {text-align: center; padding-left:1px; padding-right:1px; margin:0px;}</style>";
  $ret .= "<table class='roomoverview' width='$w' style='width:".$w."px'><tr class='devTypeTr'></tr>";
  $ret .= "<tr><td class='smaportal'>";
  $ret .= "\n<table class='block'>";                         # das \n erleichtert das Lesen der debug Quelltextausgabe

  if ($header) {                                             # Header ausgeben 
      $ret .= "<tr class='odd'>";
      # mit einem extra <td></td> ein wenig mehr Platz machen, ergibt i.d.R. weniger als ein Zeichen
      $ret .= "<td colspan='".($maxhours+2)."' align='center' style='word-break: normal'>$header</td></tr>";
  }

  if ($legend_txt && ($legend eq 'top')) {
      $ret .= "<tr class='odd'>";
      $ret .= "<td colspan='".($maxhours+2)."' align='center' style='word-break: normal'>$legend_txt</td></tr>";
  }

  if ($weather) {
	  $ret .= "<tr class='even'><td class='smaportal'></td>";      # freier Platz am Anfang

	  foreach $i (0..$maxhours-1) {                                # keine Anzeige bei Null Ertrag bzw. in der Nacht , Typ pcvo & diff haben aber immer Daten in der Nacht
	      if ($pv{$i} || $show_night || ($type eq 'pvco') || ($type eq 'diff')) {
              # FHEM Wetter Icons (weather_xxx) , Skalierung und Farbe durch FHEM Bordmittel
              my $icon_name = weather_icon($we{$i});               # unknown -> FHEM Icon Fragezeichen im Kreis wird als Ersatz Icon ausgegeben
              Log3($name, 3,"$name - unknown SMA Portal weather id: ".$we{$i}.", please inform the maintainer") if($icon_name eq 'unknown');
              
              $icon_name .='@'.$colorw if (defined($colorw));
              $val       = FW_makeImage($icon_name);
      
              $val  ='<b>???<b/>' if ($val eq $icon_name);         # passendes Icon beim User nicht vorhanden ! ( attr web iconPath falsch/prüfen/update ? )
              $ret .= "<td class='smaportal' width='$width' style='margin:1px; vertical-align:middle align:center; padding-bottom:1px;'>$val</td>";
	      
          } else {                                                 # Kein Ertrag oder show_night = 0
              $ret .= "<td></td>"; $we{$i} = undef; 
          } 
	      # mit $we{$i} = undef kann man unten leicht feststellen ob für diese Spalte bereits ein Icon ausgegeben wurde oder nicht
	  }
	  
      $ret .= "<td class='smaportal'></td></tr>";                  # freier Platz am Ende der Icon Zeile
  }

  if ($show_diff eq 'top') {                                       # Zusätzliche Zeile Ertrag - Verbrauch
      $ret .= "<tr class='even'><td class='smaportal'></td>";      # freier Platz am Anfang
      
      foreach $i (0..$maxhours-1) {
          $val = formatVal6($di{$i},$kw,$we{$i});
          $val = ($di{$i} < 0) ?  '<b>'.$val.'<b/>' : '+'.$val;    # negativ Zahlen in Fettschrift 
          $ret .= "<td class='smaportal' style='vertical-align:middle; text-align:center;'>$val</td>"; 
      }
      $ret .= "<td class='smaportal'></td></tr>"; # freier Platz am Ende 
  }

  $ret .= "<tr class='even'><td class='smaportal'></td>"; # Neue Zeile mit freiem Platz am Anfang

  foreach $i (0..$maxhours-1) {
      # Achtung Falle, Division by Zero möglich, 
      # maxVal kann gerade bei kleineren maxhours Ausgaben in der Nacht leicht auf 0 fallen  
      $height = 200 if (!$height);                                 # Fallback, sollte eigentlich nicht vorkommen, außer der User setzt es auf 0
      $maxVal = 1   if (!$maxVal);
      $maxCon = 1   if (!$maxCon);

      # Der zusätzliche Offset durch $fsize verhindert bei den meisten Skins 
      # dass die Grundlinie der Balken nach unten durchbrochen wird
      if ($type eq 'co') { 
          $he = int(($maxCon-$co{$i})/$maxCon*$height) + $fsize;             # he - freier der Raum über den Balken.
          $z3 = int($height + $fsize - $he);                                 # Resthöhe
      
      } elsif ($type eq 'pv') {
          $he = int(($maxVal-$pv{$i})/$maxVal*$height) + $fsize;
          $z3 = int($height + $fsize - $he);
      
      } elsif ($type eq 'pvco') {
          # Berechnung der Zonen
          # he - freier der Raum über den Balken. fsize wird nicht verwendet, da bei diesem Typ keine Zahlen über den Balken stehen 
          # z2 - der Ertrag ggf mit Icon
          # z3 - der Verbrauch , bei zu kleinem Wert wird der Platz komplett Zone 2 zugeschlagen und nicht angezeigt
          # z2 und z3 nach Bedarf tauschen, wenn der Verbrauch größer als der Ertrag ist

          $maxVal = $maxCon if ($maxCon > $maxVal);                          # wer hat den größten Wert ?

          if ($pv{$i} > $co{$i}) {                                           # pv oben , co unten
              $z2 = $pv{$i}; $z3 = $co{$i}; 
          } else {                                                           # tauschen, Verbrauch ist größer als Ertrag
              $z3 = $pv{$i}; $z2 = $co{$i}; 
          }

          $he = int(($maxVal-$z2)/$maxVal*$height);
          $z2 = int(($z2 - $z3)/$maxVal*$height);

          $z3 = int($height - $he - $z2);                                    # was von maxVal noch übrig ist
          
          if ($z3 < int($fsize/2)) {                                         # dünnen Strichbalken vermeiden / ca. halbe Zeichenhöhe
              $z2 += $z3; $z3 = 0; 
          }                  
      
      } else {                                                               # Typ dif
          # Berechnung der Zonen
          # he - freier der Raum über den Balken , Zahl positiver Wert + fsize
          # z2 - positiver Balken inkl Icon
          # z3 - negativer Balken
          # z4 - Zahl negativer Wert + fsize

          my ($px_pos,$px_neg);
          my $maxPV = 0;                                                     # ToDo:  maxPV noch aus Attribut maxPV ableiten

          if ($maxPV) {                                                      # Feste Aufteilung +/- , jeder 50 % bei maxPV = 0
              $px_pos = int($height/2);
              $px_neg = $height - $px_pos;                                   # Rundungsfehler vermeiden
          
          } else {                                                           # Dynamische hoch/runter Verschiebung der Null-Linie        
              if  ($minDif >= 0 ) {                                          # keine negativen Balken vorhanden, die Positiven bekommen den gesammten Raum
                  $px_neg = 0;
                  $px_pos = $height;
              } else {
                  if ($maxDif > 0) {
                      $px_neg = int($height * abs($minDif) / ($maxDif + abs($minDif)));     # Wieviel % entfallen auf unten ?
                      $px_pos = $height-$px_neg;                                            # der Rest ist oben
                  } else {                                                   # keine positiven Balken vorhanden, die Negativen bekommen den gesammten Raum
                      $px_neg = $height;
                      $px_pos = 0;
                  }
              }
          }

          if ($di{$i} >= 0) {                                                # Zone 2 & 3 mit ihren direkten Werten vorbesetzen
              $z2 = $di{$i};
              $z3 = abs($minDif);
          } else {
              $z2 = $maxDif;
              $z3 = abs($di{$i}); # Nur Betrag ohne Vorzeichen
          }
 
          # Alle vorbesetzen Werte umrechnen auf echte Ausgabe px
          $he = (!$px_pos) ? 0 : int(($maxDif-$z2)/$maxDif*$px_pos);           # Teilung durch 0 vermeiden
          $z2 = ($px_pos - $he) ;

          $z4 = (!$px_neg) ? 0 : int((abs($minDif)-$z3)/abs($minDif)*$px_neg); # Teilung durch 0 unbedingt vermeiden
          $z3 = ($px_neg - $z4);

          # Beiden Zonen die Werte ausgeben könnten muß fsize als zusätzlicher Raum zugeschlagen werden !
          $he += $fsize; 
          $z4 += $fsize if ($z3);                                              # komplette Grafik ohne negativ Balken, keine Ausgabe von z3 & z4
      }

      # das style des nächsten TD bestimmt ganz wesentlich das gesammte Design
      # das \n erleichtert das lesen des Seitenquelltext beim debugging
      # vertical-align:bottom damit alle Balken und Ausgaben wirklich auf der gleichen Grundlinie sitzen

      $ret .="<td style='text-align: center; padding-left:1px; padding-right:1px; margin:0px; vertical-align:bottom; padding-top:0px'>\n";

      if (($type eq 'pv') || ($type eq 'co')) {
          $v   = ($type eq 'co') ? $co{$i} : $pv{$i} ; 
          $v   = 0 if (($type eq 'co') && !$pv{$i} && !$show_night);           # auch bei type co die Nacht ggf. unterdrücken
          $val = formatVal6($v,$kw,$we{$i});

          $ret .="<table width='100%' height='100%'>";                         # mit width=100% etwas bessere Füllung der Balken
          $ret .="<tr class='even' style='height:".$he."px'>";
          $ret .="<td class='smaportal' style='vertical-align:bottom'>".$val."</td></tr>";

          if ($v || $show_night) {
              # Balken nur einfärben wenn der User via Attr eine Farbe vorgibt, sonst bestimmt class odd von TR alleine die Farbe
              my $style = "style=\"padding-bottom:0px; vertical-align:top; margin-left:auto; margin-right:auto;";
              $style   .= (defined($colorv)) ? " background-color:#$colorv\"" : '"';         # Syntaxhilight 

              $ret .= "<tr class='odd' style='height:".$z3."px;'>";
              $ret .= "<td align='center' class='smaportal' ".$style.">";
              
			  my $sicon = 1;                                                    
              $ret .= $is{$i} if (defined ($is{$i}) && $sicon);

              ##################################
              # inject the new icon if defined
              $ret .= consinject($hash,$i,@pgCDev) if($ret);
              
              $ret .= "</td></tr>";
         }           
         
      } elsif ($type eq 'pvco') { 
          my ($color1, $color2, $style1, $style2);

          $ret .="<table width='100%' height='100%'>\n";                      # mit width=100% etwas bessere Füllung der Balken

          if ($he) {                                                          # der Freiraum oben kann beim größten Balken ganz entfallen
              $ret .="<tr class='even' style='height:".$he."px'><td class='smaportal'></td></tr>";
          }

          if ($pv{$i} > $co{$i}) {                                            # wer ist oben, co pder pv ? Wert und Farbe für Zone 2 & 3 vorbesetzen
              $val     = formatVal6($pv{$i},$kw,$we{$i});
              $color1  = $colorv;
              $style1  = "style=\"padding-bottom:0px; padding-top:1px; vertical-align:top; margin-left:auto; margin-right:auto;";
              $style1 .= (defined($color1)) ? " background-color:#$color1\"" : '"';
              if ($z3) {                                                      # die Zuweisung können wir uns sparen wenn Zone 3 nachher eh nicht ausgegeben wird
                  $v       = formatVal6($co{$i},$kw,$we{$i});
                  $color2  = $colorc;
                  $style2  = "style=\"padding-bottom:0px; padding-top:1px; vertical-align:top; margin-left:auto; margin-right:auto;";
                  $style2 .= (defined($color2)) ? " background-color:#$color2\"" : '"';
              }
          
          } else {
              $val     = formatVal6($co{$i},$kw,$we{$i});
              $color1  = $colorc;
              $style1  = "style=\"padding-bottom:0px; padding-top:1px; vertical-align:top; margin-left:auto; margin-right:auto;";
              $style1 .= (defined($color1)) ? " background-color:#$color1\"" : '"';
              if ($z3) {
                  $v       = formatVal6($pv{$i},$kw,$we{$i});
                  $color2  = $colorv;
                  $style2  = "style=\"padding-bottom:0px; padding-top:1px; vertical-align:top; margin-left:auto; margin-right:auto;";
                  $style2 .= (defined($color2)) ? " background-color:#$color2\"" : '"';
              }
          }

         $ret .= "<tr class='odd' style='height:".$z2."px'>";
         $ret .= "<td align='center' class='smaportal' ".$style1.">$val";
				  
         $ret .= $is{$i} if (defined $is{$i});
		 
         ##################################
         # inject the new icon if defined
         $ret .= consinject($hash,$i,@pgCDev) if($ret);
		 
         $ret .= "</td></tr>";

         if ($z3) {                                                         # die Zone 3 lassen wir bei zu kleinen Werten auch ganz weg 
             $ret .= "<tr class='odd' style='height:".$z3."px'>";
             $ret .= "<td align='center' class='smaportal' ".$style2.">$v</td></tr>";
         }
      
      } else {                                                              # Type dif
          my $style  = "style=\"padding-bottom:0px; padding-top:1px; vertical-align:top; margin-left:auto; margin-right:auto;";

          $ret .="<table width='100%' border='0'>\n";                       # Tipp : das nachfolgende border=0 auf 1 setzen hilft sehr Ausgabefehler zu endecken

          $val = ($di{$i} >= 0) ? formatVal6($di{$i},$kw,$we{$i}) : '';
          $val = '&nbsp;&nbsp;&nbsp;0&nbsp;&nbsp;' if ($di{$i} == 0);       # Sonderfall , hier wird die 0 gebraucht !

          if ($val) {
              $ret .="<tr class='even' style='height:".$he."px'>";
              $ret .="<td class='smaportal' style='vertical-align:bottom'>".$val."</td></tr>";
          }

          if ($di{$i} >= 0) {                                               # mit Farbe 1 colorv füllen
              $style .= (defined($colorv)) ? " background-color:#$colorv\"" : '"';
              $z2 = 1 if ($di{$i} == 0);                                    # Sonderfall , 1px dünnen Strich ausgeben
              $ret .= "<tr class='odd' style='height:".$z2."px'>";
              $ret .= "<td align='center' class='smaportal' ".$style.">";
              $ret .= $is{$i} if (defined $is{$i});
              $ret .="</td></tr>";
          
          } else {                                                          # ohne Farbe
              $z2 = 2 if ($di{$i} == 0);                                    # Sonderfall, hier wird die 0 gebraucht !
              if ($z2 && $val) {                                            # z2 weglassen wenn nicht unbedigt nötig bzw. wenn zuvor he mit val keinen Wert hatte
                  $ret .= "<tr class='even' style='height:".$z2."px'>";
                  $ret .="<td class='smaportal'></td></tr>";
              }
          }
     
          if ($di{$i} < 0) {                                                         # Negativ Balken anzeigen ?
              $style .= (defined($colorc)) ? " background-color:#$colorc\"" : '"';   # mit Farbe 2 colorc füllen

              $ret .= "<tr class='odd' style='height:".$z3."px'>";
              $ret .= "<td align='center' class='smaportal' ".$style."></td></tr>";
          
          } elsif ($z3) {                                                            # ohne Farbe
              $ret .="<tr class='even' style='height:".$z3."px'>";
              $ret .="<td class='smaportal'></td></tr>";
          }

          if ($z4) {                                                                 # kann entfallen wenn auch z3 0 ist
              $val = ($di{$i} < 0) ? formatVal6($di{$i},$kw,$we{$i}) : '&nbsp;';
              $ret .="<tr class='even' style='height:".$z4."px'>";
              $ret .="<td class='smaportal' style='vertical-align:top'>".$val."</td></tr>";
          }
      }

      if ($show_diff eq 'bottom') {                                        # zusätzliche diff Anzeige
          $val  = formatVal6($di{$i},$kw,$we{$i});
          $val  = ($di{$i} < 0) ?  '<b>'.$val.'<b/>' : '+'.$val;           # Kommentar siehe oben bei show_diff eq top
          $ret .= "<tr class='even'><td class='smaportal' style='vertical-align:middle; text-align:center;'>$val</td></tr>"; 
      }

      $ret   .= "<tr class='even'><td class='smaportal' style='vertical-align:bottom; text-align:center;'>";
      $t{$i} = $t{$i}.$hourstyle if(defined($hourstyle));                  # z.B. 10:00 statt 10
      $ret  .= $t{$i}."</td></tr></table></td>";                           # Stundenwerte ohne führende 0
  }
  
  $ret .= "<td class='smaportal'></td></tr>";

  ###################
  # Legende unten
  if ($legend_txt && ($legend eq 'bottom')) {
      $ret .= "<tr class='odd'>";
      $ret .= "<td colspan='".($maxhours+2)."' align='center' style='word-break: normal'>";
      $ret .= "$legend_txt</td></tr>";
  }

  $ret .=  "</table></td></tr></table>";
  $ret .= $html_end if (defined($html_end));
  $ret .= "</html>";
  
return $ret;  
}

################################################################
#                 Inject consumer icon
################################################################
sub consinject($$@) {
  my ($hash,$i,@pgCDev) = @_;
  my $name              = $hash->{NAME};
  my $ret               = "";

  foreach (@pgCDev) {
	  if ($_) {
		  my ($cons,$im,$start,$end) = split (':', $_);
		  Log3($name, 4, "$name - Consumer to show -> $cons, relative to current time -> start: $start, end: $end") if($i<1); 
		  if ($im && ($i >= $start) && ($i <= $end)) {
			  $ret .= FW_makeImage($im);
		 }
	  }
  }
	  
return $ret;
}

###############################################################################
#                            Balkenbreite normieren
#
# Die Balkenbreite wird bestimmt durch den Wert.
# Damit alle Balken die gleiche Breite bekommen, müssen die Werte auf 
# 6 Ausgabezeichen angeglichen werden.
# "align=center" gleicht gleicht es aus, alternativ könnte man sie auch 
# komplett rechtsbündig ausgeben.
# Es ergibt bei fast allen Styles gute Ergebnisse, Ausnahme IOS12 & 6, da diese 
# beiden Styles einen recht großen Font benutzen.
# Wird Wetter benutzt, wird die Balkenbreite durch das Icon bestimmt
###############################################################################
sub formatVal6($$;$) {
  my ($v,$kw,$w)  = @_;
  my $n           = '&nbsp;';                               # positive Zahl

  if ($v < 0) {
      $n = '-';                                             # negatives Vorzeichen merken
      $v = abs($v);
  }

  if ($kw eq 'kWh') {                                       # bei Anzeige in kWh muss weniger aufgefüllt werden
      $v  = sprintf('%.1f',($v/1000));
      $v  += 0;                                             # keine 0.0 oder 6.0 etc

      return ($n eq '-') ? ($v*-1) : $v if defined($w) ;

      my $t = $v - int($v);                                 # Nachkommstelle ?

      if (!$t) {                                            # glatte Zahl ohne Nachkommastelle
          if(!$v) { 
              return '&nbsp;';                              # 0 nicht anzeigen, passt eigentlich immer bis auf einen Fall im Typ diff
          } elsif ($v < 10) { 
              return '&nbsp;&nbsp;'.$n.$v.'&nbsp;&nbsp;'; 
          } else { 
              return '&nbsp;&nbsp;'.$n.$v.'&nbsp;'; 
          }
      } else {                                              # mit Nachkommastelle -> zwei Zeichen mehr .X
          if ($v < 10) { 
              return '&nbsp;'.$n.$v.'&nbsp;'; 
          } else { 
              return $n.$v.'&nbsp;'; 
          }
      }
  }

  return ($n eq '-')?($v*-1):$v if defined($w);

  # Werte bleiben in Watt
  if    (!$v)         { return '&nbsp;'; }                            # keine Anzeige bei Null
  elsif ($v <    10)  { return '&nbsp;&nbsp;'.$n.$v.'&nbsp;&nbsp;'; } # z.B. 0
  elsif ($v <   100)  { return '&nbsp;'.$n.$v.'&nbsp;&nbsp;'; }
  elsif ($v <  1000)  { return '&nbsp;'.$n.$v.'&nbsp;'; }
  elsif ($v < 10000)  { return  $n.$v.'&nbsp;'; }
  else                { return  $n.$v; }                              # mehr als 10.000 W :)
}

###############################################################################
#         Zuordungstabelle "WeatherId" angepasst auf FHEM Icons
###############################################################################
sub weather_icon ($) {
  my $id = shift;

  my %weather_ids = (
      '0' => 'weather_sun',         		        # Sonne (klar)   					                    # vorhanden
      '1' => 'weather_cloudy_light',		        # leichte Bewölkung (1/3) 				                # vorhanden
      '2' => 'weather_cloudy', 			            # mittlere Bewölkung (2/3) 				                # vorhanden
      '3' => 'weather_cloudy_heavy',		        # starke Bewölkung (3/3) 				                # vorhanden
     '10' => 'weather_fog',				            # Nebel   						                        # neu
     '11' => 'weather_rain_fog',			        # Nebel mit Regen 					                    # neu
     '20' => 'weather_rain_heavy',  		        # Regen (viel) 						                    # vorhanden
     '21' => 'weather_rain_snow_heavy',  		    # Regen (viel) mit Schneefall 				            # neu
     '30' => 'weather_rain_light',  		        # leichter Regen (1 Tropfen) 				            # vorhanden
     '31' => 'weather_rain', 			            # leichter Regen (2 Tropfen) 				            # vorhanden
     '32' => 'weather_rain_heavy',  		        # leichter Regen (3 Tropfen) 				            # vorhanden
     '40' => 'weather_rain_snow_light',  		    # leichter Regen mit Schneefall (1 Tropfen) 		    # neu
     '41' => 'weather_rain_snow',  			        # leichter Regen mit Schneefall (3 Tropfen) 		    # neu
     '50' => 'weather_snow_light',  		        # bewölkt mit Schneefall (1 Flocke) 			        # vorhanden
     '51' => 'weather_snow', 			            # bewölkt mit Schneefall (2 Flocken) 			        # vorhanden
     '52' => 'weather_snow_heavy',  		        # bewölkt mit Schneefall (3 Flocken) 			        # vorhanden
     '60' => 'weather_rain_light',  		        # Sonne, Wolke mit Regen (1 Tropfen) 			        # vorhanden
     '61' => 'weather_rain', 			            # Sonne, Wolke mit Regen (2 Tropfen) 			        # vorhanden
     '62' => 'weather_rain_heavy',  		        # Sonne, Wolke mit Regen (3 Tropfen) 			        # vorhanden
     '70' => 'weather_snow_light', 			        # Sonne, Wolke mit Schnee (1 Flocke) 			        # vorhanden
     '71' => 'weather_snow_heavy',  		        # Sonne, Wolke mit Schnee (3 Flocken) 			        # vorhanden
     '80' => 'weather_thunderstorm',		        # Wolke mit Blitz 					                    # vorhanden
     '81' => 'weather_storm',  			            # Wolke mit Blitz und Starkregen 			            # vorhanden
     '90' => 'weather_sun',	     			        # Sonne (klar) 						                    # vorhanden
     '91' => 'weather_sun',	     			        # Sonne (klar) wie 90 					                # vorhanden
    '100' => 'weather_night',			            # Mond - Nacht  					                    # neu
    '101' => 'weather_night_cloudy_light',		    # Mond mit Wolken - 					                # neu
    '102' => 'weather_night_cloudy',		        # Wolken mittel (2/2) - Nacht 				            # neu
    '103' => 'weather_night_cloudy_heavy',		    # Wolken stark (3/3) - Nacht 			            	# neu
    '110' => 'weather_night_fog',			        # Nebel - Nacht 					                    # neu
    '111' => 'weather_night_rain_fog',		        # Nebel mit Regen (3 Tropfen) - Nacht 		         	# neu
    '120' => 'weather_night_rain_heavy',		    # Regen (viel) - Nacht 					                # neu
    '121' => 'weather_night_snow_rain_heavy',	    # Regen (viel) mit Schneefall - Nacht 			        # neu
    '130' => 'weather_night_rain_light',		    # leichter Regen (1 Tropfen) - Nacht 			        # neu
    '131' => 'weather_night_rain',			        # leichter Regen (2 Tropfen) - Nacht 			        # neu
    '132' => 'weather_night_rain_heavy',		    # leichter Regen (3 Tropfen) - Nacht 			        # neu
    '140' => 'weather_night_snow_rain_light',	    # leichter Regen mit Schneefall (1 Tropfen) - Nacht 	# neu
    '141' => 'weather_night_snow_rain_heavy',	    # leichter Regen mit Schneefall (3 Tropfen) - Nacht 	# neu
    '150' => 'weather_night_snow_light',		    # bewölkt mit Schneefall (1 Flocke) - Nacht 		    # neu
    '151' => 'weather_night_snow',			        # bewölkt mit Schneefall (2 Flocken) - Nacht 		    # neu
    '152' => 'weather_night_snow_heavy',		    # bewölkt mit Schneefall (3 Flocken) - Nacht 		    # neu
    '160' => 'weather_night_rain_light',		    # Mond, Wolke mit Regen (1 Tropfen) - Nacht 		    # neu
    '161' => 'weather_night_rain',			        # Mond, Wolke mit Regen (2 Tropfen) - Nacht 		    # neu
    '162' => 'weather_night_rain_heavy',		    # Mond, Wolke mit Regen (3 Tropfen) - Nacht 		    # neu
    '170' => 'weather_night_snow_rain',		        # Mond, Wolke mit Schnee (1 Flocke) - Nacht 		    # neu
    '171' => 'weather_night_snow_heavy',		    # Mond, Wolke mit Schnee (3 Flocken) - Nacht		    # neu
    '180' => 'weather_night_thunderstorm_light',	# Wolke mit Blitz - Nacht 				                # neu
    '181' => 'weather_night_thunderstorm'		    # Wolke mit Blitz und Starkregen - Nacht 		        # neu
  );
  
return $weather_ids{$id} if(defined($weather_ids{$id}));
return 'unknown';
}

######################################################################################################
#      Refresh eines Raumes aus $hash->{HELPER}{SPGROOM}
#      bzw. Longpoll von SMAPortal bzw. eines SMAPortalSPG Devices wenn $hash->{HELPER}{SPGDEV} gefüllt 
#      $hash, $pload (1=Page reload), SMAPortalSPG-Event (1=Event)
######################################################################################################
sub SPGRefresh($$$) { 
  my ($hash,$pload,$lpollspg) = @_;
  my $name;
  if (ref $hash ne "HASH") {
    ($name,$pload,$lpollspg) = split ",",$hash;
    $hash = $defs{$name};
  } else {
    $name = $hash->{NAME};
  }
  my $fpr = 0;
  
  # Kontext des SMAPortalSPG-Devices speichern für Refresh
  my $sd  = $hash->{HELPER}{SPGDEV}?$hash->{HELPER}{SPGDEV}:"\"n.a.\"";       # Name des aufrufenden SMAPortalSPG-Devices
  my $sr  = $hash->{HELPER}{SPGROOM}?$hash->{HELPER}{SPGROOM}:"\"n.a.\"";     # Raum aus dem das SMAPortalSPG-Device die Funktion aufrief
  my $sl  = $hash->{HELPER}{SPGDETAIL}?$hash->{HELPER}{SPGDETAIL}:"\"n.a.\""; # Name des SMAPortalSPG-Devices (wenn Detailansicht)
  $fpr    = AttrVal($hash->{HELPER}{SPGDEV},"forcePageRefresh",0) if($hash->{HELPER}{SPGDEV});
  Log3($name, 4, "$name - Refresh - caller: $sd, callerroom: $sr, detail: $sl, pload: $pload, forcePageRefresh: $fpr, event_Spgdev: $lpollspg");
  
  # Page-Reload
  if($pload && ($hash->{HELPER}{SPGROOM} && !$hash->{HELPER}{SPGDETAIL} && !$fpr)) {
      # trifft zu wenn in einer Raumansicht
      my @rooms = split(",",$hash->{HELPER}{SPGROOM});
      foreach (@rooms) {
          my $room = $_;
          { map { FW_directNotify("FILTER=room=$room", "#FHEMWEB:$_", "location.reload('true')", "") } devspec2array("TYPE=FHEMWEB") } 
      }
  } elsif ($pload && (!$hash->{HELPER}{SPGROOM} || $hash->{HELPER}{SPGDETAIL})) {
      # trifft zu bei Detailansicht oder im FLOORPLAN bzw. Dashboard oder wenn Seitenrefresh mit dem 
      # SMAPortalSPG-Attribut "forcePageRefresh" erzwungen wird
      { map { FW_directNotify("#FHEMWEB:$_", "location.reload('true')", "") } devspec2array("TYPE=FHEMWEB") }
  } else {
      if($fpr) {
          { map { FW_directNotify("#FHEMWEB:$_", "location.reload('true')", "") } devspec2array("TYPE=FHEMWEB") }
      }
  }
  
  # parentState des SMAPortalSPG-Device updaten
  my @spgs = devspec2array("TYPE=SMAPortalSPG");
  my $st   = ReadingsVal($name, "state", "initialized");  
  foreach(@spgs) {   
      if($defs{$_}{PARENT} eq $name) {
          next if(IsDisabled($defs{$_}{NAME}));
          readingsBeginUpdate($defs{$_});
          readingsBulkUpdate($defs{$_},"parentState", $st);
          readingsBulkUpdate($defs{$_},"state", "updated");
          readingsEndUpdate($defs{$_}, 1);
      }
  }
        
return;
}

1;

=pod
=encoding utf8
=item summary    Module for communication with the SMA Sunny Portal
=item summary_DE Modul zur Kommunikation mit dem SMA Sunny Portal

=begin html

<a name="SMAPortal"></a>
<h3>SMAPortal</h3>
<ul>

   With this module it is possible to fetch data from the <a href="https://www.sunnyportal.com">SMA Sunny Portal</a> and switch
   consumers (e.g. bluetooth plug sockets) if any are present.
   At the momentent that are the following data: <br><br>
   <ul>
    <ul>
     <li>Live data (Consumption and PV-Generation) </li>
     <li>Battery data (In/Out) and usage data of consumers </li>
     <li>Weather data delivered from SMA for the facility location </li>
     <li>Forecast data (Consumption and PV-Generation) inclusive suggestion times to switch comsumers on </li>
     <li>the planned times by the Sunny Home Manager to switch consumers on and the current state of consumers (if present) </li>
    </ul> 
   </ul>
   <br>
   
   Graphic data can also be integrated into FHEM Tablet UI with the 
   <a href="https://wiki.fhem.de/wiki/FTUI_Widget_SMAPortalSPG">"SMAPortalSPG Widget"</a>. <br>
   <br>
   
   <b>Preparation </b> <br><br>
    
   <ul>   
    This module use the Perl module JSON which has typically to be installed discrete. <br>
	On Debian linux based systems that can be done by command: <br><br>
    
    <code>sudo apt-get install libjson-perl</code>      <br><br>
    
    Subsequent there are an overview of used Perl modules: <br><br>
    
    POSIX           <br>
    JSON            <br>
    Data::Dumper    <br>                  
    Time::HiRes     <br>
    Time::Local     <br>
	Blocking        (FHEM-Modul) <br>
    GPUtils         (FHEM-Modul) <br>
    FHEM::Meta      (FHEM-Modul) <br>
	LWP::UserAgent  <br>
	HTTP::Cookies   <br>
    MIME::Base64    <br>
    Encode          <br>
    
    <br><br>  
   </ul>
  
   <a name="SMAPortalDefine"></a>
   <b>Definition</b>
   <ul>
    <br>
    A SMAPortal device will be defined by: <br><br>
	
    <ul>
      <b><code>define &lt;name&gt; SMAPortal</code></b> <br><br>
    </ul>
   
    After the definition of the device the credentials for the SMA Sunny Portal must be saved with the 
    following command: <br><br>
   
    <ul> 
     set &lt;name&gt; credentials &lt;Username&gt; &lt;Password&gt;
    </ul>     
   </ul>
   <br><br>   
    
   <a name="SMAPortalSet"></a>
   <b>Set </b>
   <ul>
   <br>
     <ul>
     <li><b> set &lt;name&gt; createPortalGraphic &lt;Generation | Consumption | Generation_Consumption | Differential&gt; </b> </li>  
     Creates graphical devices to show the SMA Sunny Portal forecast data in several layouts. 
     The attribute "detailLevel" has to be set to level 4. The command set this attribut to the needed value automatically. <br>
     With the <a href="#SMAPortalSPGattr">"attributes of the graphic device"</a> the appearance and coloration of the forecast 
     data in the created graphic device can be adjusted.     
     </ul>   
     <br>
     
     <ul>
     <li><b> set &lt;name&gt; credentials &lt;username&gt; &lt;password&gt; </b> </li>  
     Set Username / Password used for the login into the SMA Sunny Portal.   
     </ul> 
     <br>
     
     <ul>
     <li><b> set &lt;name&gt; &lt;consumer name&gt; &lt;on | off | auto&gt; </b> </li>  
     If the attribute "detailLevel" is set to 3 or higher, consumer data are fetched from the SMA Sunny Portal.
     Once these data are available, the consumer are shown in the Set and can be switched to on, off or the automatic mode (auto)
     that means the consumer are controlled by the Sunny Home Manager.     
     </ul>
   
   </ul>
   <br><br>
   
   <a name="SMAPortalGet"></a>
   <b>Get</b>
   <ul>
    <br>
    <ul>
      <li><b> get &lt;name&gt; data </b> </li>  
      This command fetch the data from the SMA Sunny Portal manually. 
    </ul>
    <br>
    
    <ul>
      <li><b> get &lt;name&gt; storedCredentials </b> </li>  
      The saved credentials are displayed in a popup window.
    </ul>
   </ul>  
   <br><br>
   
   <a name="SMAPortalAttr"></a>
   <b>Attributes</b>
   <ul>
     <br>
     <ul>
       <a name="cookielifetime"></a>
       <li><b>cookielifetime &lt;Sekunden&gt; </b><br>
       Validity period of a received Cookie (default: 3000 seconds).  
       </li><br>
       
       <a name="cookieLocation"></a>
       <li><b>cookieLocation &lt;Pfad/File&gt; </b><br>
       The path and filename of received Cookies (default: ./log/mycookies.txt).
       <br><br> 
  
        <ul>
		 <b>Example:</b><br>
         attr &lt;name&gt; cookieLocation ./log/cookies.txt <br>    
        </ul>        
       </li><br>
       
       <a name="detailLevel"></a>
       <li><b>detailLevel </b><br>
       Adjust the complexity of the generated data. 
       <br><br>
	
	   <ul>   
	   <table>  
	   <colgroup> <col width=5%> <col width=95%> </colgroup>
		  <tr><td> <b>L1</b>  </td><td>- only live data and weather data are generated. </td></tr>
		  <tr><td> <b>L2</b>  </td><td>- as L1 and additional forecast of the current data, the data of the next 4 hours as well as PV-Generation / Consumption the rest of day and the next day </td></tr>
		  <tr><td> <b>L3</b>  </td><td>- as L2 and additional forecast of the planned switch-on times of consumers, whose current state and energy data as well as their battery usage data </td></tr>
          <tr><td> <b>L4</b>  </td><td>- as L3 and additional a detailed forecast of the next 24 hours </td></tr>
	   </table>
	   </ul>     
	   <br>       
       </li><br>
       
       <a name="disable"></a>
       <li><b>disable</b><br>
       Deactivate/activate the device. </li><br>
       
       <a name="getDataRetries"></a>
       <li><b>getDataRetries &lt;Anzahl&gt; </b><br>
       Number of repetitions (get data) in case of no live data are fetched from the SMA Sunny Portal (default: 3). </li><br>

       <a name="interval"></a>
       <li><b>interval &lt;seconds&gt; </b><br>
       Time interval for continuous data retrieval from the aus dem SMA Sunny Portal (default: 300 seconds). <br>
       if the "interval = 0" is set, no continuous data retrieval is executed and has to be triggered by the 
       "get &lt;name&gt; data" command manually. 
       If a value of 120 seconds or less (but >0) should be set, the value will be corrected to 120 soconds. <br><br>
       
       <b>Note:</b> 
       The retrieval interval should not be less than 120 seconds. As of previous experiences SMA suffers an interval of  
       120 seconds although the SMA terms and conditions don't permit an automatic data fetch by computer programs.
       </li><br>
       
       <a name="showPassInLog"></a>
       <li><b>showPassInLog</b><br>
       If set, the used password will be displayed in Logfile output. 
       (default = 0) </li><br>
       
       <a name="timeout"></a>
       <li><b>timeout &lt;seconds&gt; </b><br>
       Timeout value for HTTP-calls to the SMA Sunny Portal (default: 30 seconds).  
       </li><br>
       
       <a name="userAgent"></a>
       <li><b>userAgent &lt;identifier&gt; </b><br>
       An user agent identifier for identifikation against the SMA Sunny Portal can be specified.
       <br><br> 
  
        <ul>
		 <b>Example:</b><br>
         attr &lt;name&gt; userAgent Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:65.0) Gecko/20100101 Firefox/65.0 <br>    
        </ul>           
       </li><br> 

       <a name="verbose5Data"></a>
       <li><b>verbose5Data </b><br>
       If verbose 5 is set, huge data are generated. With this attribute only the interesting verbose 5 output
       can be specified. (default: none).  
       </li><br>       
   
     </ul>
   </ul>
   <br> 

</ul>


=end html
=begin html_DE

<a name="SMAPortal"></a>
<h3>SMAPortal</h3>
<ul>

   Mit diesem Modul können Daten aus dem <a href="https://www.sunnyportal.com">SMA Sunny Portal</a> abgerufen werden.
   Momentan sind es: <br><br>
   <ul>
    <ul>
     <li>Live-Daten (Verbrauch und PV-Erzeugung) </li>
     <li>Batteriedaten (In/Out) sowie Nutzungsdaten durch Verbraucher </li>
     <li>Wetter-Daten von SMA für den Anlagenstandort </li>
     <li>Prognosedaten (Verbrauch und PV-Erzeugung) inklusive Verbraucherempfehlung </li>
     <li>die durch den Sunny Home Manager geplanten Schaltzeiten und aktuellen Status von Verbrauchern (sofern vorhanden) </li>
    </ul> 
   </ul>
   <br>
   
   Die Portalgrafik kann ebenfalls in FHEM Tablet UI mit dem 
   <a href="https://wiki.fhem.de/wiki/FTUI_Widget_SMAPortalSPG">"SMAPortalSPG Widget"</a> integriert werden. <br>
   <br>
   
   <b>Vorbereitung </b> <br><br>
    
   <ul>   
    Dieses Modul nutzt das Perl-Modul JSON welches üblicherweise nachinstalliert werden muss. <br>
	Auf Debian-Linux basierenden Systemen kann es installiert werden mit: <br><br>
    
    <code>sudo apt-get install libjson-perl</code>      <br><br>
    
    Überblick über die Perl-Module welche von SMAPortal genutzt werden: <br><br>
    
    POSIX           <br>
    JSON            <br>
    Data::Dumper    <br>                  
    Time::HiRes     <br>
    Time::Local     <br>
	Blocking        (FHEM-Modul) <br>
    GPUtils         (FHEM-Modul) <br>
    FHEM::Meta      (FHEM-Modul) <br>
	LWP::UserAgent  <br>
	HTTP::Cookies   <br>
    MIME::Base64    <br>
    Encode          <br>
    
    <br><br>  
   </ul>
  
   <a name="SMAPortalDefine"></a>
   <b>Definition</b>
   <ul>
    <br>
    Ein SMAPortal-Device wird definiert mit: <br><br>
	
    <ul>
      <b><code>define &lt;Name&gt; SMAPortal</code></b> <br><br>
    </ul>
   
    Nach der Definition des Devices müssen die Zugangsparameter für das SMA Sunny Portal gespeichert werden 
    mit dem Befehl: <br><br>
   
    <ul> 
     set &lt;Name&gt; credentials &lt;Username&gt; &lt;Passwort&gt;
    </ul>     
   </ul>
   <br><br>   
    
   <a name="SMAPortalSet"></a>
   <b>Set </b>
   <ul>
   <br>
     <ul>
     <li><b> set &lt;name&gt; createPortalGraphic &lt;Generation | Consumption | Generation_Consumption | Differential&gt; </b> </li>  
     Erstellt Devices zur grafischen Anzeige der SMA Sunny Portal Prognosedaten in verschiedenen Layouts. 
     Das Attribut "detailLevel" muss auf den Level 4 gesetzt sein. Der Befehl setzt dieses Attribut automatisch auf 
     den benötigten Wert.  <br>
     Mit den <a href="#SMAPortalSPGattr">"Attributen des Grafikdevices"</a> können Erscheinungsbild und 
     Farbgebung der Prognosedaten in den erstellten Grafik-Devices angepasst werden.     
     </ul>   
     <br>
     
     <ul>
     <li><b> set &lt;name&gt; credentials &lt;username&gt; &lt;password&gt; </b> </li>  
     Setzt Username / Passwort zum Login in das SMA Sunny Portal.   
     </ul> 
     <br>
     
     <ul>
     <li><b> set &lt;name&gt; &lt;Verbrauchername&gt; &lt;on | off | auto&gt; </b> </li>  
     Ist das Atttribut detailLevel auf 3 oder höher gesetzt, werden Verbraucherdaten aus dem SMA Sunny Portal abgerufen.
     Sobald diese Werte vorliegen, werden die vorhandenen Verbraucher im Set angezeigt und können eingeschaltet, ausgeschaltet
     bzw. auf die Steuerung durch den Sunny Home Manager umgeschaltet werden (auto).     
     </ul>
   
   </ul>
   <br><br>
   
   <a name="SMAPortalGet"></a>
   <b>Get</b>
   <ul>
    <br>
    <ul>
      <li><b> get &lt;name&gt; data </b> </li>  
      Mit diesem Befehl werden die Daten aus dem SMA Sunny Portal manuell abgerufen. 
    </ul>
    <br>
    
    <ul>
      <li><b> get &lt;name&gt; storedCredentials </b> </li>  
      Die gespeicherten Anmeldeinformationen (Credentials) werden in einem Popup als Klartext angezeigt.
    </ul>
   </ul>  
   <br><br>
   
   <a name="SMAPortalAttr"></a>
   <b>Attribute</b>
   <ul>
     <br>
     <ul>
       <a name="cookielifetime"></a>
       <li><b>cookielifetime &lt;Sekunden&gt; </b><br>
       Gültigkeitszeitraum für einen empfangenen Cookie (default: 3000 Sekunden).  
       </li><br>
       
       <a name="cookieLocation"></a>
       <li><b>cookieLocation &lt;Pfad/File&gt; </b><br>
       Angabe von Pfad und Datei zur Abspeicherung des empfangenen Cookies (default: ./log/mycookies.txt).
       <br><br> 
  
        <ul>
		 <b>Beispiel:</b><br>
         attr &lt;name&gt; cookieLocation ./log/cookies.txt <br>    
        </ul>        
       </li><br>
       
       <a name="detailLevel"></a>
       <li><b>detailLevel </b><br>
       Es wird der Umfang der zu generierenden Daten eingestellt. 
       <br><br>
	
	   <ul>   
	   <table>  
	   <colgroup> <col width=5%> <col width=95%> </colgroup>
		  <tr><td> <b>L1</b>  </td><td>- nur Live-Daten und Wetter-Daten werden generiert. </td></tr>
		  <tr><td> <b>L2</b>  </td><td>- wie L1 und zusätzlich Prognose der aktuellen und nächsten 4 Stunden sowie PV-Erzeugung / Verbrauch des Resttages und des Folgetages </td></tr>
		  <tr><td> <b>L3</b>  </td><td>- wie L2 und zusätzlich Prognosedaten der geplanten Einschaltzeiten von Verbrauchern, deren aktueller Status und Energiedaten sowie Batterie-Nutzungsdaten</td></tr>
          <tr><td> <b>L4</b>  </td><td>- wie L3 und zusätzlich die detaillierte Prognose der nächsten 24 Stunden </td></tr>
	   </table>
	   </ul>     
	   <br>       
       </li><br>
       
       <a name="disable"></a>
       <li><b>disable</b><br>
       Deaktiviert das Device. </li><br>
       
       <a name="getDataRetries"></a>
       <li><b>getDataRetries &lt;Anzahl&gt; </b><br>
       Anzahl der Wiederholungen (get data) im Fall dass keine Live-Daten vom SMA Sunny Portal geliefert 
       wurden (default: 3). </li><br>

       <a name="interval"></a>
       <li><b>interval &lt;Sekunden&gt; </b><br>
       Zeitintervall zum kontinuierlichen Datenabruf aus dem SMA Sunny Portal (Default: 300 Sekunden). <br>
       Ist "interval = 0" gesetzt, erfolgt kein automatischer Datenabruf und muss mit "get &lt;name&gt; data" manuell
       erfolgen. Wird ein Wert kleiner 120 Sekunden (aber >0) angegeben, wird der Wert auf 120 Sekunden korrigiert. <br><br>
       
       <b>Hinweis:</b> 
       Das Abfrageintervall sollte nicht kleiner 120 Sekunden sein. Nach bisherigen Erfahrungen toleriert SMA ein 
       Intervall von 120 Sekunden obwohl lt. SMA AGB der automatische Datenabruf untersagt ist.
       </li><br>
       
       <a name="showPassInLog"></a>
       <li><b>showPassInLog</b><br>
       Wenn gesetzt, wird das verwendete Passwort im Logfile angezeigt. 
       (default = 0) </li><br>
       
       <a name="timeout"></a>
       <li><b>timeout &lt;Sekunden&gt; </b><br>
       Timeout-Wert für HTTP-Aufrufe zum SMA Sunny Portal (default: 30 Sekunden).  
       </li><br>
       
       <a name="userAgent"></a>
       <li><b>userAgent &lt;Kennung&gt; </b><br>
       Es kann die User-Agent-Kennung zur Identifikation gegenüber dem SMA Sunny Portal angegeben werden.
       <br><br> 
  
        <ul>
		 <b>Beispiel:</b><br>
         attr &lt;name&gt; userAgent Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:65.0) Gecko/20100101 Firefox/65.0 <br>    
        </ul>           
       </li><br> 

       <a name="verbose5Data"></a>
       <li><b>verbose5Data </b><br>
       Mit dem Attributwert verbose 5 werden zu viele Daten generiert. Mit diesem Attribut können gezielt die interessierenden
       verbose 5 Ausgaben selektiert werden. (default: none).  
       </li><br>       
   
     </ul>
   </ul>
   <br> 
    
</ul>

=end html_DE

=for :application/json;q=META.json 76_SMAPortal.pm
{
  "abstract": "Module for communication with the SMA Sunny Portal",
  "x_lang": {
    "de": {
      "abstract": "Modul zur Kommunikation mit dem SMA Sunny Portal"
    }
  },
  "keywords": [
    "sma",
    "photovoltaik",
    "electricity",
    "portal",
    "smaportal"
  ],
  "version": "v1.1.1",
  "release_status": "stable",
  "author": [
    "Heiko Maaz <heiko.maaz@t-online.de>",
    "Wzut",
    "XGuide",
    null
  ],
  "x_fhem_maintainer": [
    "DS_Starter"
  ],
  "x_fhem_maintainer_github": [
    "nasseeder1"
  ],
  "prereqs": {
    "runtime": {
      "requires": {
        "FHEM": 5.00918799,
        "perl": 5.014,
        "JSON": 0,
        "Encode": 0,
        "POSIX": 0,
        "Data::Dumper": 0,
        "Blocking": 0,
        "GPUtils": 0,
        "Time::HiRes": 0,
        "Time::Local": 0,
        "LWP": 0,
        "HTTP::Cookies": 0,
        "MIME::Base64": 0
      },
      "recommends": {
        "FHEM::Meta": 0
      },
      "suggests": {
      }
    }
  }
}
=end :application/json;q=META.json

=cut