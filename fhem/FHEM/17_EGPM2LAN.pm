############################################## 
# $Id: 17_EGPM2LAN.pm 14071 2017-04-22 12:13:43Z alexus $
#
#  based / modified Version 98_EGPMS2LAN from ericl
#
#  (c) 2013 - 2017 Copyright: Alex Storny (moselking at arcor dot de)
#  All rights reserved
#
#  This script free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  any later version.
#
#  The GNU General Public License can be found at
#  http://www.gnu.org/copyleft/gpl.html.
#
#  This script is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
################################################################
#  -> Module 70_EGPM.pm (for a single Socket) needed.
################################################################
package main; 

use strict; 
use warnings; 
use HttpUtils;

sub 
EGPM2LAN_Initialize($) 
{ 
  my ($hash) = @_; 
  $hash->{Clients}   = ":EGPM:";
  $hash->{GetFn}     = "EGPM2LAN_Get";
  $hash->{SetFn}     = "EGPM2LAN_Set"; 
  $hash->{DefFn}     = "EGPM2LAN_Define"; 
  $hash->{AttrList}  = "stateDisplay:sockNumber,sockName autocreate:on,off"; 
} 

###################################
sub
EGPM2LAN_Get($@)
{
    my ($hash, @a) = @_;
    my $getcommand;

    return "argument is missing" if(int(@a) != 2);
    
    $getcommand = $a[1];
    
    if($getcommand eq "state")
    {
      if(defined($hash->{STATE})) {
          return $hash->{STATE}; }
    } 
    elsif($getcommand eq "lastcommand")
    {
      if(defined($hash->{READINGS}{lastcommand}{VAL})) { 
          return $hash->{READINGS}{lastcommand}{VAL}; }
    }
    else
    {
         return "Unknown argument $getcommand, choose one of state:noArg lastcommand:noArg".(exists($hash->{READINGS}{output})?" output:noArg":"");
    }
    return "";
}

################################### 
sub 
EGPM2LAN_Set($@) 
{ 
  my ($hash, @a) = @_; 

  return "no set value specified" if(int(@a) < 2); 
  return "Unknown argument $a[1], choose one of on:1,2,3,4,all off:1,2,3,4,all toggle:1,2,3,4 clearreadings:noArg statusrequest:noArg password" if($a[1] eq "?"); 

  my $name = shift @a; 
  my $setcommand = shift @a; 
  my $params = join(" ", @a);
  
  Log3 "EGPM2LAN", 4, "set $name (". $hash->{IP}. ") $setcommand $params";
 
  EGPM2LAN_Login($hash); 
  
  if($setcommand eq "on" || $setcommand eq "off") 
  { 
    if($params eq "all")
	  { #switch all Sockets; thanks to eric!
  	  for (my $count = 1; $count <= 4; $count++)
      {
   	    EGPM2LAN_Switch($hash, $setcommand, $count);
      }
	  }
	  else
	  {  #switch single Socket
       EGPM2LAN_Switch($hash, $setcommand, $params);
    }
    EGPM2LAN_Statusrequest($hash, 1); 
  }   
  elsif($setcommand eq "toggle") 
  { 
    my $currentstate = EGPM2LAN_Statusrequest($hash, 1);
    if(defined($currentstate))
    {
    	my @powerstates = split(",", $currentstate);
    	my $newcommand="off";
    	if($powerstates[$params-1] eq "0")
    	{
    	   $newcommand="on";
    	}
      EGPM2LAN_Switch($hash, $newcommand, $params);
	    EGPM2LAN_Statusrequest($hash, 0); 
    } 
  } 
  elsif($setcommand eq "statusrequest") 
  { 
	   EGPM2LAN_Statusrequest($hash, 1); 
  }
  elsif($setcommand eq "password")
  {
         my $result =  EGPM2LAN_StorePassword($hash, $params);
         Log3 "EGPM2LAN", 1,$result;
         if($params eq ""){
            delete $hash->{PASSWORD} if(defined($hash->{PASSWORD}));
         } else {
            $params="***";
         }
  }
  elsif($setcommand eq "clearreadings") 
  { 
         delete $hash->{READINGS};
  } 
  else 
  { 
     return "unknown argument $setcommand, choose one of on, off, toggle, statusrequest, clearreadings"; 
  } 	
  
  EGPM2LAN_Logoff($hash); 

  $hash->{CHANGED}[0] = $setcommand; 
  $hash->{READINGS}{lastcommand}{TIME} = TimeNow(); 
  $hash->{READINGS}{lastcommand}{VAL} = $setcommand." ".$params; 
  
  return undef; 
} 

################################
sub EGPM2LAN_StorePassword($$)
{
    my ($hash, $password) = @_;

    my $index = $hash->{TYPE}."_".$hash->{NAME}."_passwd";
    my $key = getUniqueId().$index;

    my $enc_pwd = "";

    if(eval "use Digest::MD5;1")
    {
        $key = Digest::MD5::md5_hex(unpack "H*", $key);
        $key .= Digest::MD5::md5_hex($key);
    }

    for my $char (split //, $password)
    {
        my $encode=chop($key);
        $enc_pwd.=sprintf("%.2x",ord($char)^ord($encode));
        $key=$encode.$key;
    }

    Log3 "EGPM2LAN", 4, "write password to file uniqueID";
    my $err = setKeyValue($index, $enc_pwd);
    if(defined($err)){
       #Fallback, if file is not available
       $hash->{PASSWORD}=$password;
       return "EGPM2LAN: Write Password failed!";
    }
    $hash->{PASSWORD}="***" if($password ne "");
    return "EGPM2LAN: Password saved.";
} 

################################
sub EGPM2LAN_ReadPassword($)
{
   my ($hash) = @_;

   #for old installations/fallback to clear-text PWD
   if(defined($hash->{PASSWORD}) && $hash->{PASSWORD} ne "***"){
      return $hash->{PASSWORD};
   }

   my $index = $hash->{TYPE}."_".$hash->{NAME}."_passwd";
   my $key = getUniqueId().$index;
   my ($password, $err);

   Log3 "EGPM2LAN", 3, "Read password from file uniqueID";
   ($err, $password) = getKeyValue($index);

   if ( defined($err) ) {
      Log3 "EGPM2LAN",0, "unable to read password from file: $err";
      return undef;
   }

   if (defined($password) ) {
      if ( eval "use Digest::MD5;1" ) {
         $key = Digest::MD5::md5_hex(unpack "H*", $key);
         $key .= Digest::MD5::md5_hex($key);
      }

      my $dec_pwd = '';

      for my $char (map { pack('C', hex($_)) } ($password =~ /(..)/g)) {
         my $decode=chop($key);
         $dec_pwd.=chr(ord($char)^ord($decode));
         $key=$decode.$key;
      }

      $hash->{PASSWORD}="***";
      return $dec_pwd;
   }
   else {
      Log3 "EGPM2LAN",4 ,"No password in file";
      return "";
   }
}

################################
sub EGPM2LAN_Switch($$$) { 
  my ($hash, $state, $port) = @_; 
  $state = ($state eq "on" ? "1" : "0");
  
  my $fritz = 0; #may be important for FritzBox-users
  my $data = "cte1=" . ($port == "1" ? $state : "") . "&cte2=" . ($port == "2" ? $state : "") . "&cte3=" . ($port == "3" ? $state : "") . "&cte4=". ($port == "4" ? $state : ""); 
  Log3 "EGPM2LAN",5 , $data; 
  eval {
    # Parameter:    $url, $timeout, $data, $noshutdown, $loglevel
    GetFileFromURL("http://".$hash->{IP}."/", 5,$data ,$fritz);
  }; 
  if ($@){ 
    ### catch block 
    Log3 "EGPM2LAN", 1 ,"error: $@"; 
  }; 

  return 1; 
} 

################################
sub EGPM2LAN_Login($) { 
  my ($hash) = @_; 
  my $name = $hash->{NAME};

  my $passwd = EGPM2LAN_ReadPassword($hash);

  Log3 $name,4 , "EGPM2LAN: try to connect ".$hash->{IP};
  eval{
      GetFileFromURLQuiet("http://".$hash->{IP}."/login.html", 5,"pw=" .(defined($passwd) ? $passwd : ""),0 );
  }; 
  if ($@){ 
      ### catch block 
      Log3 $name, 0, "EGPM2LAN Login error: $@";
      return 0; 
  }; 

  return 1; 
} 

################################
sub EGPM2LAN_GetDeviceInfo($$) { 
  my ($hash, $input) = @_;

  #try to read Device Name
  my ($devicename) = $input =~ m/<h2>(.+)<\/h2><\/div>/si;
  $hash->{DEVICENAME} = trim($devicename);

  #try to read Socket Names
  my @socketlist; 
  while ($input =~ m/<h2 class=\"ener\">(.+?)<\/h2>/gi) 
  { 
    my $socketname = trim($1);
    $socketname =~ s/ /_/g;    #remove spaces
    push(@socketlist, $socketname); 
  }

  #check 4 dublicate Names
  my %seen;
  foreach my $entry (@socketlist)
  {
	next unless $seen{$entry}++;
        Log3 "EGPM2LAN", 1, "Sorry! Can't use devicenames. ".trim($entry)." is duplicated.";
	@socketlist = qw(Socket_1 Socket_2 Socket_3 Socket_4);
  } 
  if(int(@socketlist) < 4)
  {
	@socketlist = qw(Socket_1 Socket_2 Socket_3 Socket_4);
  }
  return @socketlist; 
}

################################
sub EGPM2LAN_Statusrequest($$) { 
  my ($hash, $autoCr) = @_;
  my $name = $hash->{NAME}; 
  
  my $response = GetFileFromURL("http://".$hash->{IP}."/", 5,"" , 0);
  if(not defined($response)){
     Log3 $name, 0, "EGPM2LAN: Cant connect to ".$hash->{IP};
     $hash->{STATE} = "Connection failed";
     return 0
  }
  Log3 $name, 5, "EGPM2LAN: $response";

	if($response =~ /.,.,.,./) 
        { 
          my $powerstatestring = $&; 
          Log3 $name, 2, "EGPM2LAN Powerstate: " . $powerstatestring; 
          my @powerstates = split(",", $powerstatestring);

          if(int(@powerstates) == 4) 
          { 
            my $index;
            my $newstatestring;
            my @socketlist = EGPM2LAN_GetDeviceInfo($hash,$response);
            readingsBeginUpdate($hash);
            
	    foreach my $powerstate (@powerstates)
            {
                $index++;
		if(length(trim($socketlist[$index-1]))==0)
		{
		  $socketlist[$index-1]="Socket_".$index;	
		}
                if(AttrVal($name, "stateDisplay", "sockNumber") eq "sockName") {
                  $newstatestring .= $socketlist[$index-1].": ".($powerstates[$index-1] ? "on" : "off")." ";
		} else {
            	  $newstatestring .= $index.": ".($powerstates[$index-1] ? "on" : "off")." ";
		}

                #Create Socket-Object if not available
                my $defptr = $modules{EGPM}{defptr}{$name.$index};

                if($autoCr && AttrVal($name, "autocreate", "on") eq "on" && not defined($defptr))
		{
		   if(Value("autocreate") eq "active")
		   {
		  	Log3 $name, 1, "EGPM2LAN: Autocreate EGPM for Socket $index";
	                CommandDefine(undef, $name."_".$socketlist[$index-1]." EGPM $name $index");
		   }
		   else
		   {
			Log3 $name, 2, "EGPM2LAN: Autocreate disabled in globals section";
                        $attr{$name}{autocreate} = "off"; 
		   }
		}

		#Write state 2 related Socket-Object
		if (defined($defptr))
		{
		   if (ReadingsVal($defptr->{NAME},"state","") ne ($powerstates[$index-1] ? "on" : "off"))
		   {  #check for chages and update -> trigger event
		      Log3 $name, 3, "EGPM2LAN: Update State of ".$defptr->{NAME};
          readingsSingleUpdate($defptr, "state", ($powerstates[$index-1] ? "on" : "off") ,1);
       }
		   $defptr->{DEVICENAME} = $hash->{DEVICENAME};
		   $defptr->{SOCKETNAME} = $socketlist[$index-1];
   	}

         	readingsBulkUpdate($hash, $index."_".$socketlist[$index-1], ($powerstates[$index-1] ? "on" : "off"));
        } 
        readingsBulkUpdate($hash, "state", $newstatestring);
        readingsEndUpdate($hash, 0);

	    #everything is fine
	    return $powerstatestring;
          } 
          else 
          { 
            Log3 $name, 0,"EGPM2LAN: Failed to parse powerstate";
          } 
        }
	else
	{
           $hash->{STATE} = "Login failed";
	   Log3 $name, 0,"EGPM2LAN: Login failed";
	}
   #something went wrong :-( 
   return undef; 
} 

################################
sub EGPM2LAN_Logoff($) {
  my ($hash) = @_; 

  GetFileFromURL("http://".$hash->{IP}."/login.html", 5,"" ,0 ,3);
  return 1; 
} 

################################
sub EGPM2LAN_Define($$) 
{ 
  my ($hash, $def) = @_; 
  my @a = split("[ \t][ \t]*", $def); 
  my $u = "wrong syntax: define <name> EGPM2LAN IP [Password]"; 
  return $u if(int(@a) < 2); 
    
  $hash->{IP} = $a[2];
  if(int(@a) == 4) 
  { 
    EGPM2LAN_StorePassword($hash, $a[3]);
    $hash->{DEF} = $a[2]; ## remove password
  } 
  my $result = EGPM2LAN_Login($hash);
  if($result == 1)
  { 
    $hash->{STATE} = "initialized";
    EGPM2LAN_Statusrequest($hash,0);
    EGPM2LAN_Logoff($hash); 
  }

  return undef; 
} 

1;

=pod
=item device
=item summary controls a LAN-Socket device from Gembird
=item summary_DE steuert eine LAN-Steckdosenleiste von Gembird
=begin html

<a name="EGPM2LAN"></a>
<h3>EGPM2LAN</h3>
<ul>
  <br>
  <a name="EGPM2LANdefine"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; EGPM2LAN &lt;IP-Address&gt;</code><br>
    <br>
    Creates a Gembird &reg; <a href="http://energenie.com/item.aspx?id=7557" >Energenie EG-PM2-LAN</a> device to switch up to 4 sockets over the network.
    If you have more than one device, it is helpful to connect and set names for your sockets over the web-interface first.
    The name settings will be adopted to FHEM and helps you to identify the sockets. Please make sure that you&acute;re logged off from the Energenie web-interface otherwise you can&acute;t control it with FHEM at the same time.<br>
    Create a <a href="#EGPM">EGPM-Module</a> to control a single socket with additional features.<br>
    <b>EG-PMS2-LAN with surge protector feature was not tested until now.</b>
</ul><br>
  <a name="EGPM2LANset"></a>
  <b>Set</b>
  <ul>
    <code>set &lt;name&gt; password [&lt;one-word&gt;]</code><br>
    Encrypt and store device-password in FHEM. Leave empty to remove the password.<br>
    Before 04/2017, the password was stored in clear-text using the DEFINE-Command, but it should not be stored in the config-file.<br>
    <br>
    <code>set &lt;name&gt; &lt;[on|off|toggle]&gt &lt;socketnr.&gt;</code><br>
    Switch the socket on or off.<br>
    <br>
    <code>set &lt;name&gt; &lt;[on|off]&gt &lt;all&gt;</code><br>
    Switch all available sockets on or off.<br>
    <br>
    <code>set &lt;name&gt; &lt;staterequest&gt;</code><br>
    Update the device information and the state of all sockets.<br>
    If <a href="#autocreate">autocreate</a> is enabled, an <a href="#EGPM">EGPM</a> device will be created for each socket.<br>
    <br>
    <code>set &lt;name&gt; &lt;clearreadings&gt;</code><br>
    Removes all readings from the list to get rid of old socketnames.
  </ul>
  <br>
  <a name="EGPM2LANget"></a>
  <b>Get</b>
  <ul><code>get &lt;name&gt; state</code><br>
  Returns a text like this: "1: off 2: on 3: off 4: off" or the last error-message if something went wrong.<br>
  </ul><br>
  <a name="EGPM2LANattr"></a>
  <b>Attributes</b>
  <ul>
    <li>stateDisplay</li>
	  Default: <b>socketNumer</b> changes between <b>socketNumer</b> and <b>socketName</b> in front of the current state. Call <b>set statusrequest</b> to update all states.
    <li>autocreate</li>
    Default: <b>on</b> <a href="#EGPM">EGPM</a>-devices will be created automatically with a <b>set</b>-command.
	  Change this attribute to value <b>off</b> to avoid that mechanism.
    <li><a href="#loglevel">loglevel</a></li>
    <li><a href="#readingFnAttributes">readingFnAttributes</a></li>
  </ul>
  <br>
<br>
   <br>

    Example:
    <ul>
      <code>define mainswitch EGPM2LAN 10.192.192.20</code><br>
      <code>set mainswitch password SecretGarden</code><br>
      <code>set mainswitch on 1</code><br>
    </ul>
</ul>

=end html
=begin html_DE

<a name="EGPM2LAN"></a>
<h3>EGPM2LAN</h3>
<ul>
  <br>
  <a name="EGPM2LANdefine"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; EGPM2LAN &lt;IP-Address&gt;</code><br>
    <br>
    Das Modul erstellt eine Verbindung zu einer Gembird &reg; <a href="http://energenie.com/item.aspx?id=7557" >Energenie EG-PM2-LAN</a> Steckdosenleiste und steuert 4 angeschlossene Ger&auml;te..
    Falls mehrere Steckdosenleisten &uuml;ber das Netzwerk gesteuert werden, ist es ratsam, diese zuerst &uuml;ber die Web-Oberfl&auml;che zu konfigurieren und die einzelnen Steckdosen zu benennen. Die Namen werden dann automatisch in die
    Oberfl&auml;che von FHEM &uuml;bernommen. Bitte darauf achten, die Weboberfl&auml;che mit <i>Logoff</i> wieder zu verlassen, da der Zugriff sonst blockiert wird.
</ul><br>
  <a name="EGPM2LANset"></a>
  <b>Set</b>
  <ul>
    <code>set &lt;name&gt; &lt;[on|off|toggle]&gt &lt;socketnr.&gt;</code><br>
    Schaltet die gew&auml;hlte Steckdose ein oder aus.<br>
    <br>
    <code>set &lt;name&gt; &lt;[on|off]&gt &lt;all&gt;</code><br>
    Schaltet alle Steckdosen gleichzeitig ein oder aus.<br>
    <br>
    <code>set &lt;name&gt; password [&lt;mein-passwort&gt;]</code><br>
    Speichert das Passwort verschl&uuml;sselt in FHEM ab. Zum Entfernen eines vorhandenen Passworts den Befehl ohne Parameter aufrufen.<br>
    Vor 04/2017 wurde das Passwort im Klartext gespeichert und mit dem DEFINE-Command &uuml;bergeben.<br>
    <br>
    <code>set &lt;name&gt; &lt;staterequest&gt;</code><br>
    Aktualisiert die Statusinformation der Steckdosenleiste.<br>
    Wenn das globale Attribut <a href="#autocreate">autocreate</a> aktiviert ist, wird f&uuml;r jede Steckdose ein <a href="#EGPM">EGPM</a>-Eintrag erstellt.<br>
    <br>
    <code>set &lt;name&gt; &lt;clearreadings&gt;</code><br>
    L&ouml;scht alle ung&uuml;ltigen Eintr&auml;ge im Abschnitt &lt;readings&gt;.
  </ul>
  <br>
  <a name="EGPM2LANget"></a>
  <b>Get</b>
  <ul><code>get &lt;name&gt; state</code><br>
  Gibt einen Text in diesem Format aus: "1: off 2: on 3: off 4: off" oder enth&auml;lt die letzte Fehlermeldung.<br>
  </ul><br>

  <a name="EGPM2LANattr"></a>
  <b>Attribute</b>
  <ul>
    <li>stateDisplay</li>
	  Default: <b>socketNumer</b> wechselt zwischen <b>socketNumer</b> and <b>socketName</b> f&uuml;r jeden Statuseintrag. Verwende <b>set statusrequest</b>, um die Anzeige zu aktualisieren.
    <li>autocreate</li>
    Default: <b>on</b> <a href="#EGPM">EGPM</a>-Eintr&auml;ge werden automatisch mit dem <b>set</b>-command erstellt.
    <li><a href="#loglevel">loglevel</a></li>
    <li><a href="#readingFnAttributes">readingFnAttributes</a></li>
  </ul>
  <br>
<br>
   <br>
    Beispiel:
    <ul>
      <code>define sleiste EGPM2LAN 10.192.192.20</code><br>
      <code>set sleiste password SecretGarden</code><br>
      <code>set sleiste on 1</code><br>
    </ul>
</ul>
=end html_DE

=cut

