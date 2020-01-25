##############################################################################
#
# 70_STV.pm
#
# a module to send messages or commands to a Samsung TV
#
# written 2012 by Gabriel Bentele <gabriel at bentele.de>>
#
# $Id: 70_STV.pm 12857 2016-12-21 11:59:33Z Zwiebel $
#
# Version = 1.5
#
##############################################################################

package main;
use strict;
use warnings;
use IO::Socket::INET;
use Sys::Hostname;
use MIME::Base64;
use DevIo;

my @gets = ('dummy');

sub
STV_Initialize($)
{
  my ($hash) = @_;
  $hash->{DefFn}    = "STV_Define";
  $hash->{UndefFn}  = "STV_Undefine";
  $hash->{StateFn}  = "STV_SetState";
  $hash->{SetFn}    = "STV_Set";
  $hash->{AttrFn}   = "STV_Attr";
  $hash->{ReadFn}   = "STV_Read";  
  $hash->{ReadyFn}  = "STV_Ready";
  $hash->{AttrList} = "MAC fork:enable,disable setWhenOffline:execute,ignore " . $readingFnAttributes;;
}

sub STV_Undefine($$) 
{
  my ($hash,$arg) = @_;
  DevIo_CloseDev($hash); 
  return undef;
}

sub 
STV_Attr(@)
{
  my @a = @_;
  my $hash = $defs{$a[1]};
  my $mac = AttrVal($a[1], "MAC", undef);
  $hash->{MAC} = $mac if (defined($mac));
  return;
}

sub
STV_SetState($$$$)
{
  my ($hash, $tim, $vt, $val) = @_;
  $val = $1 if($val =~ m/^(.*) \d+$/);
#  return "Undefined value $val" if(!defined($it_c2b{$val}));
  return undef;
}

sub getIP()
{
  my $address = eval {Net::Address::IP::Local->public_ipv4};
  if ($@) {
    $address = 'localhost';
  } 
  return "$address";
}

sub getIP_old()
{
  my $host = hostname();
  my $address = inet_ntoa(scalar gethostbyname(hostname() || 'localhost'));
  if ($@) {
    $address = 'localhost';
  } 
  return "$address";
}

sub getMAC4IP($)
{
  my $IP = shift;
  my @interfaces = IO::Interface::Simple->interfaces;
  foreach my $if (@interfaces) {
    next unless defined ($if->address);
    if ($if->address eq $IP) {
        return $if->hwaddr;
    }
  }
  return "";
}

# Force a connection attempt to STV as soon as possible 
# (e.g. you know you just started it and want to connect immediately without waiting up to 60 s)
sub STV_Connect($)
{
  my ($hash) = @_;
  my $name = $hash->{NAME};
  
  if(AttrVal($hash->{NAME},'fork','disable') eq 'enable') {
    return undef unless $hash->{CHILDPID}; # nothing to do
    # well, the fork process does not respond to SIGTERM
    # so lets use SIGKILL to make things clear to it
    if ((kill SIGKILL, $hash->{CHILDPID}) != 1) { 
      Log3 3, $name, "STV_Connect: ERROR: Unable to kill fork process!";
      return undef;
    }
    $hash->{CHILDPID} = undef; # undefg childpid so the Ready-func will fork again
  } else {
    $hash->{NEXT_OPEN} = 0; # force NEXT_OPEN used in DevIO
  }
    
  return undef;
}

sub STV_Ready($)
{
  my ($hash) = @_;
  if(AttrVal($hash->{NAME},'fork','disable') eq 'enable') {
    if($hash->{CHILDPID} && !(kill 0, $hash->{CHILDPID})) {
      $hash->{CHILDPID} = undef;
      return DevIo_OpenDev($hash, 1, "STV_Init");
    }
    elsif(!$hash->{CHILDPID}) {
      return if($hash->{CHILDPID} = fork);
      my $ppid = getppid();

      ### Copied from Blocking.pm
      foreach my $d (sort keys %defs) {   # Close all kind of FD
        my $h = $defs{$d};
        #the following line was added by vbs to not close parent's DbLog DB handle
        $h->{DBH}->{InactiveDestroy} = 1 if ($h->{TYPE} eq 'DbLog');
        TcpServer_Close($h) if($h->{SERVERSOCKET});
        if($h->{DeviceName}) {
          require "$attr{global}{modpath}/FHEM/DevIo.pm";
          DevIo_CloseDev($h,1);
        }
      }
      ### End of copied from Blocking.pm
  
      while(kill 0, $ppid) {
        DevIo_OpenDev($hash, 1, "STV_ChildExit");
        sleep(5);
      }
      exit(0);
    }
  } else {
    return DevIo_OpenDev($hash, 1, "STV_Init");
  }
  return undef;
}

sub STV_Read($)
{
  my ($hash) = @_;
  my $name = $hash->{NAME};
  
  #we dont really expect data here. Its just to gracefully close the device if the connection was closed
  my $buf = DevIo_SimpleRead($hash);
}

sub STV_Init($) 
{
  my ($hash) = @_;
  return undef;
}

sub STV_ChildExit($) 
{
   exit(0);
}

sub STV_Define($$)
{
  my ($hash, $def) = @_;
  DevIo_CloseDev($hash);
  my @args = split("[ \t]+", $def);

  if (int(@args) < 3)
  {
    return "Define: not enough arguments. Usage:\n" .
         "define <name> STV <host> <port>";
  }

  $hash->{Host} = $args[2];
  if (defined $args[3]) { 
    $hash->{Port} = $args[3];
    $hash->{".validcommands"} = "mute:on,off volume:slider,0,1,100 call sms date";
  } else {
    $hash->{Port} = 52235;
    $hash->{".validcommands"} = "mute:on,off volume:slider,0,1,100 call sms date";
    Log3 undef, 3, "[STV] defined with host: $hash->{Host} port: $hash->{Port}";
  }

  if ( $hash->{Port} eq 55000 ){
      $hash->{".validcommands"} = "0 1 2 3 4 5 6 7 8 9 11 12 3SPEED 4_3 16_9 AD ADDDEL ALT_MHP ANGLE ".
"ANTENA ANYNET ANYVIEW APP_LIST ASPECT AUTO_ARC_ANTENNA_AIR AUTO_ARC_ANTENNA_CABLE AUTO_ARC_ANTENNA_SATELLITE ".
"AUTO_ARC_ANYNET_AUTO_START AUTO_ARC_ANYNET_MODE_OK AUTO_ARC_AUTOCOLOR_FAIL AUTO_ARC_AUTOCOLOR_SUCCESS ".
"AUTO_ARC_CAPTION_ENG AUTO_ARC_CAPTION_KOR AUTO_ARC_CAPTION_OFF AUTO_ARC_CAPTION_ON AUTO_ARC_C_FORCE_AGING ".
"AUTO_ARC_JACK_IDENT AUTO_ARC_LNA_OFF AUTO_ARC_LNA_ON AUTO_ARC_PIP_CH_CHANGE AUTO_ARC_PIP_DOUBLE ".
"AUTO_ARC_PIP_LARGE AUTO_ARC_PIP_LEFT_BOTTOM AUTO_ARC_PIP_LEFT_TOP AUTO_ARC_PIP_RIGHT_BOTTOM ".
"AUTO_ARC_PIP_RIGHT_TOP AUTO_ARC_PIP_SMALL AUTO_ARC_PIP_SOURCE_CHANGE AUTO_ARC_PIP_WIDE AUTO_ARC_RESET ".
"AUTO_ARC_USBJACK_INSPECT AUTO_FORMAT AUTO_PROGRAM AV1 AV2 AV3 BACK_MHP BOOKMARK CALLER_ID CAPTION CATV_MODE ".
"CHDOWN CHUP CH_LIST CLEAR CLOCK_DISPLAY COMPONENT1 COMPONENT2 CONTENTS CONVERGENCE CONVERT_AUDIO_MAINSUB ".
"CUSTOM CYAN DEVICE_CONNECT DISC_MENU DMA DNET DNIe DNSe DOOR DOWN DSS_MODE DTV DTV_LINK DTV_SIGNAL DVD_MODE ".
"DVI DVR DVR_MENU DYNAMIC ENTER ENTERTAINMENT ESAVING EXIT EXT1 EXT2 EXT3 EXT4 EXT5 EXT6 EXT7 EXT8 EXT9 EXT10 ".
"EXT11 EXT12 EXT13 EXT14 EXT15 EXT16 EXT17 EXT18 EXT19 EXT20 EXT21 EXT22 EXT23 EXT24 EXT25 EXT26 EXT27 EXT28 ".
"EXT29 EXT30 EXT31 EXT32 EXT33 EXT34 EXT35 EXT36 EXT37 EXT38 EXT39 EXT40 EXT41 FACTORY FAVCH FF FF_ FM_RADIO ".
"GAME GREEN GUIDE HDMI HDMI1 HDMI2 HDMI3 HDMI4 HELP HOME ID_INPUT ID_SETUP INFO INSTANT_REPLAY LEFT LINK LIVE ".
"MAGIC_BRIGHT MAGIC_CHANNEL MDC MENU MIC MORE MOVIE1 MS MTS MUTE NINE_SEPERATE OPEN PANNEL_CHDOWN PANNEL_CHUP ".
"PANNEL_ENTER PANNEL_MENU PANNEL_POWER PANNEL_SOURCE PANNEL_VOLDOW PANNEL_VOLUP PANORAMA PAUSE PCMODE ".
"PERPECT_FOCUS PICTURE_SIZE PIP_CHDOWN PIP_CHUP PIP_ONOFF PIP_SCAN PIP_SIZE PIP_SWAP PLAY PLUS100 PMODE POWER ".
"POWEROFF POWERON PRECH PRINT PROGRAM QUICK_REPLAY REC RED REPEAT RESERVED1 RETURN REWIND REWIND_ RIGHT RSS ".
"RSURF SCALE SEFFECT SETUP_CLOCK_TIMER SLEEP SOUND_MODE SOURCE SRS STANDARD STB_MODE STILL_PICTURE STOP ".
"SUB_TITLE SVIDEO1 SVIDEO2 SVIDEO3 TOOLS TOPMENU TTX_MIX TTX_SUBFACE TURBO TV TV_MODE UP VCHIP VCR_MODE ".
"VOLDOWN VOLUP WHEEL_LEFT WHEEL_RIGHT W_LINK YELLOW ZOOM1 ZOOM2 ZOOM_IN ZOOM_MOVE ZOOM_OUT connect";

    my $rc = eval
    {
      require Net::Address::IP::Local;
      require IO::Interface::Simple;
      Net::Address::IP::Local->import();
      IO::Interface::Simple->import();
      1;
    };

    if($rc)
    {

      $hash->{MyIP} = getIP();
      $hash->{MAC} = getMAC4IP($hash->{MyIP});
    
      $hash->{DeviceName} = $hash->{Host} . ":" . $hash->{Port};
      my $dev = $hash->{DeviceName};
      $readyfnlist{"$args[0].$dev"} = $hash;
      Log3 undef, 3, "[STV] defined with host: $hash->{Host} port: $hash->{Port} MAC: $hash->{MAC}";
    }else{
      Log3 undef, 3, "[STV] You are using a deprecated MAC detection mechanism using ifconfig.";
      Log3 undef, 3, "[STV] Please install Pearl Modules libnet-address-ip-local-perl and libio-interface-perl";

    my $system = $^O;
    my $result = "";
    if($system =~ m/Win/) {
      $result = `ipconfig /all`;
      my @myarp=split(/\n/,$result);
      foreach (@myarp){
        if ( /([0-9a-f]{2}[:-][0-9a-f]{2}[:-][0-9a-f]{2}[:-][0-9a-f]{2}[:-][0-9a-f]{2}[:-][0-9a-f]{2})$/i )
        {
          $result = $1;
          $result =~ s/-/:/g;
        }
      }
    }
    if($system eq "linux") {
      $result = `ifconfig -a`;
      my @myarp=split(/\n/,$result);
      foreach (@myarp){
        if ( /^(lan|eth0) .*(..:..:..:..:..:..) .*$/ )
        {
          $result = $2;
        }
      }
    }
    # Fritzbox "? (192.168.0.1) at 00:0b:5d:91:fc:bb [ether]  on lan"
    # debian   "192.168.0.1              ether   c0:25:06:1f:3c:14   C                     eth0"
    #$result = "? (192.168.0.1) at 00:0b:5d:91:fc:bb [ether]  on lan";

      $hash->{MAC} = $result;

      $hash->{MyIP} = getIP_old();
    
      $hash->{DeviceName} = $hash->{Host} . ":" . $hash->{Port};
      my $dev = $hash->{DeviceName};
      $readyfnlist{"$args[0].$dev"} = $hash;
	
   }
  } 

  if ( $hash->{Port} != 55000 && $hash->{Port} != 52235 ){
	  return "[STV] Port is not supported";
  }

  $hash->{STATE} = 'Initialized';
  return undef;
}

sub connection($$)
{
  my $tmp =  shift ; 
  Log3 undef, 4, "[STV] connection message: $tmp";
  my $TV = shift;
  my $buffer = "";
  my @tmp2 = "";

  my $sock = new IO::Socket::INET (
          PeerAddr => $TV,
          PeerPort => '52235',
          Proto => 'tcp',
          Timout => 5
        );
  if (defined ($sock)){
    print $sock $tmp;
    my $buff ="";
    while ((read $sock, $buff, 1) > 0){
      $buffer .= $buff;
    }
    @tmp2 = split (/\n/,$buffer);

    $sock->close();
    Log3 undef, 4, "[STV] $TV: socket closed";
  }else{
    Log3 undef, 4, "[STV] $TV: not able to close socket";
  }
}

# new Samsung Models
sub STV_55000($$$)
{
  my ($hash,$name,$cmd) = @_;
  my $par=undef;
  my @ARGV = split(" ",$cmd);
  #### Configuration
  my $tv    = "UE46ES8090";  # Might need changing to match your TV type  #"UE46ES8090"
  my $port  = $hash->{Port}; # TCP port of Samsung TV
  my $tvip  = $hash->{Host}; # IP Address of TV #"192.168.2.124"
  my $myip  = $hash->{MyIP}; # IP Address of FHEM Server
  my $mymac = $hash->{MAC};  # Used for the access control/validation '"24:65:11:80:0D:01"
  my $appstring = "iphone..iapp.samsung"; # What the iPhone app reports
  my $tvappstring = "iphone.".$tv.".iapp.samsung"; # TV type
  my $remotename = "Perl Samsung Remote"; # What gets reported when it asks for permission/also shows in General->Wireless Remote Control menu
  
  #### MAC überprüfen wenn nicht gültig vom attribute übernehmen.
  if ($mymac !~ /^\w\w:\w\w:\w\w:\w\w|\w\w:\w\w:\w\w:\w\w$/) {
    Log3 $name, 3, "[STV] mymac: $mymac invalid format";
  }else{
    # command-line help
    if (!$tv|!$tvip|!$myip|!$mymac) {
      return "[STV] Error - Parameter missing:\nmodel, tvip, myip, mymac.";
    }
    Log3 $name, 5, "[STV] opening socket with tvip: $tvip, cmd: $cmd";
    my $sock = new IO::Socket::INET (
      PeerAddr => $tvip,
      PeerPort => $port,
      Proto => 'tcp',
      Timout => 5
    );
  
    if (defined ($sock)){
        my $messagepart1 = chr(0x64) . chr(0x00) . chr(length(encode_base64($myip, ""))) . chr(0x00) . encode_base64($myip, "") . chr(length(encode_base64($mymac, ""))) . chr(0x00) . encode_base64($mymac, "") . chr(length(encode_base64($remotename, ""))) . chr(0x00) . encode_base64($remotename, "");
        my $part1 = chr(0x00) . chr(length($appstring)) . chr(0x00) . $appstring . chr(length($messagepart1)) . chr(0x00) . $messagepart1;
        print $sock $part1;

        my $messagepart2 = chr(0xc8) . chr(0x00);
        my $part2 = chr(0x00) . chr(length($appstring)) . chr(0x00) . $appstring . chr(length($messagepart2)) . chr(0x00) . $messagepart2;
        print $sock $part2;
        # Preceding sections all first time only

        if (defined($par)) {
         # Send text, e.g. in YouTube app's search, N.B. NOT BBC iPlayer app.
         my $text = $par;
         my $messagepart3 = chr(0x01) . chr(0x00) . chr(length(encode_base64($text, ""))) . chr(0x00) . encode_base64($text, "");
         my $part3 = chr(0x01) . chr(length($appstring)) . chr(0x00) . $appstring . chr(length($messagepart3)) . chr(0x00) . $messagepart3;
         print $sock $part3;
        }
        else {
          foreach my $argnum (0 .. $#ARGV) {
			sleep(1) if ($argnum > 0);
            # Send remote key(s)
            #Log4 $name, 4, "[STV] sending ".uc($ARGV[$argnum]);
            my $key = "KEY_" . uc($ARGV[$argnum]);
            my $messagepart3 = chr(0x00) . chr(0x00) . chr(0x00) . chr(length(encode_base64($key, ""))) . chr(0x00) . encode_base64($key, "");
            my $part3 = chr(0x00) . chr(length($tvappstring)) . chr(0x00) . $tvappstring . chr(length($messagepart3)) . chr(0x00) . $messagepart3;
            print $sock $part3;
        #        select(undef, undef, undef, 0.5);
          }
        }

        close($sock);
    }else{
      #Log5 $name, 3, "[STV] Could not create socket. Aborting." unless $sock;
    }
  }
}

# old Samsung Models
sub STV_52235($@)
{
  my ($hash, @a) = @_;
  my $name = $hash->{NAME};
  my $TV = $hash->{Host};
  my $count = @a;
  my $arg    = lc($a[2]);      # mute volume
  my $cont1  = ucfirst($arg);  # Mute
  my $cont2 = ""; 
  my $cont3 = "";
  my $cont4 = "";
  my $cont5 = "";
  my $cont6 = "";
  my $cont7 = "";
  my $cont8 = "";
  my $cont9 = "";
  
  if (defined $a[3]) { $cont2 = $a[3]}
  if (defined $a[4]) { $cont3 = $a[4]}
  if (defined $a[5]) { $cont4 = $a[5]}
  if (defined $a[6]) { $cont5 = $a[6]}
  if (defined $a[7]) { $cont6 = $a[7]}
  if (defined $a[8]) { $cont7 = $a[8]}
  if (defined $a[9]) { $cont8 = $a[9]}

  my $callsoap = "";
  my $message = "";
  my $head = "";
  my $kind = 0;
  my $size = "";
  my $body = "";

  if ( $arg eq "mute" )
  { 
    $kind = 1;
    if ( $cont2 eq "off" ){
      $cont2 = 0 ;
    }else {
      $cont2 = 1 ;
    }
  }
  if ( $arg eq "volume")
  { 
    if ( $cont2 > 0 and $cont2 < 100 ){
      $kind = 1;
    }else {
      Log3 $name, 3, "[STV] $name Volume: not correct"; 
      $kind = 0;
    }
  }
  if ( $arg eq "call")
  {
    $kind = 2;
    
  }
  if ( $arg eq "sms")
  {
    $kind = 3;
    for my $i (6..$count){
      $body .= $a[$i];
      $body .= " ";
    } 
  }
  if ( $arg eq "date")
  {
    $kind = 4;
    for my $i (10..$count){
      $body .= $a[$i];
      $body .= " ";
    } 
  }

  if ( $kind eq 1){
          $callsoap .= "<?xml version=\"1.0\" encoding=\"utf-8\"?>\r\n";
          $callsoap .= "<s:Envelope s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\">\r\n";
          $callsoap .= "<s:Body>\r\n";
          $callsoap .= "<ns0:Set$cont1 xmlns:ns0=\"urn:schemas-upnp-org:service:RenderingControl:1\">\r\n";
          $callsoap .= "<InstanceID>0</InstanceID>\r\n";
          $callsoap .= "<Desired$cont1>$cont2</Desired$cont1>\r\n";
          $callsoap .= "<Channel>Master</Channel>\r\n";
          $callsoap .= "</ns0:Set$cont1>\r\n";
          $callsoap .= "</s:Body>\r\n";
          $callsoap .= "</s:Envelope>\r\n";

          $size = length($callsoap);

          $head .= "POST /upnp/control/RenderingControl1 HTTP/1.1\r\n";
          $head .= "Content-Type: text/xml; charset=\"utf-8\"\r\n";
          $head .= "SOAPACTION: \"SoapAction:urn:schemas-upnp-org:service:RenderingControl:1#Set$cont1\"\r\n";
          $head .= "Cache-Control: no-cache\r\n";
          $head .= "Host: $TV:52235\r\n";
          $head .= "Content-Length: $size\r\n";
          $head .= "Connection: Close\r\n";
          $head .= "\r\n";

          $message .= $head;
          $message .= $callsoap;
  }

  my $calldate=`date +"%Y-%m-%d"`;
  chomp($calldate);
  my $calltime=`date +"%H:%M:%S"`;
  chomp($calltime);

  if ( $kind eq 2 ){ # CALL
        $callsoap .= "<?xml version=\"1.0\" encoding=\"utf-8\"?>\r\n";
        $callsoap .= "<s:Envelope s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\" >\r\n";
        $callsoap .= "<s:Body>\r\n";
        $callsoap .= "<u:AddMessage xmlns:u=\"urn:samsung.com:service:MessageBoxService:1\\\">\r\n";
        $callsoap .= "<MessageType>text/xml</MessageType>\r\n";
        $callsoap .= "<MessageID>1334799348</MessageID>\r\n";
        $callsoap .= "<Message>\r\n";
        $callsoap .= "&lt;Category&gt;Incoming Call&lt;/Category&gt;\r\n";
        $callsoap .= "&lt;DisplayType&gt;Maximum&lt;/DisplayType&gt;\r\n";
        $callsoap .= "&lt;CallTime&gt;\r\n";
        $callsoap .= "&lt;Date&gt;$calldate&lt;/Date&gt;\r\n";
        $callsoap .= "&lt;Time&gt;$calltime&lt;/Time&gt;\r\n";
        $callsoap .= "&lt;/CallTime&gt;\r\n";
        $callsoap .= "&lt;Callee&gt;\r\n";
        $callsoap .= "&lt;Name&gt;An: $cont4&lt;/Name&gt;\r\n";
        $callsoap .= "&lt;Number&gt;Nr: $cont5&lt;/Number&gt;\r\n";
        $callsoap .= "&lt;/Callee&gt;\r\n";
        $callsoap .= "&lt;Caller&gt;\r\n";
        $callsoap .= "&lt;Name&gt;Von: $cont2&lt;/Name&gt;\r\n";
        $callsoap .= "&lt;Number&gt;Nr: $cont3&lt;/Number&gt;\r\n";
        $callsoap .= "&lt;/Caller&gt;\r\n";
        $callsoap .= "</Message>\r\n";
        $callsoap .= "</u:AddMessage>\r\n";
        $callsoap .= "</s:Body>\r\n";
        $callsoap .= "</s:Envelope>\r\n";

        $size = length($callsoap);
        $head .= "POST /PMR/control/MessageBoxService HTTP/1.1\r\n";
        $head .= "Content-Type: text/xml; charset=\"utf-8\"\r\n";
        $head .= "SOAPACTION: \"urn:samsung.com:service:MessageBoxService:1#AddMessage\"\r\n";
        $head .= "Cache-Control: no-cache\r\n";
        $head .= "Host: $TV:52235\r\n";
        $head .= "Content-Length: $size\r\n";
        $head .= "Connection: Close\r\n";
        $head .= "\r\n";

        $message .= $head;
        $message .= $callsoap;
   }

  if ( $kind eq 3 ){ # SMS
        $callsoap .= "<?xml version=\"1.0\" encoding=\"utf-8\"?>\r\n";
        $callsoap .= "<s:Envelope s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\" >\r\n";
        $callsoap .= "<s:Body>\r\n";
        $callsoap .= "<u:AddMessage xmlns:u=\"urn:samsung.com:service:MessageBoxService:1\\\">\r\n";
        $callsoap .= "<MessageType>text/xml</MessageType>\r\n";
        $callsoap .= "<MessageID>1334799348</MessageID>\r\n";
        $callsoap .= "<Message>\r\n";
        $callsoap .= "&lt;Category&gt;SMS&lt;/Category&gt;\r\n";
        $callsoap .= "&lt;DisplayType&gt;Maximum&lt;/DisplayType&gt;\r\n";
        $callsoap .= "&lt;ReceiveTime&gt;\r\n";
        $callsoap .= "&lt;Date&gt;$calldate&lt;/Date&gt;\r\n";
        $callsoap .= "&lt;Time&gt;$calltime&lt;/Time&gt;\r\n";
        $callsoap .= "&lt;/ReceiveTime&gt;\r\n";
        $callsoap .= "&lt;Receiver&gt;\r\n";
        $callsoap .= "&lt;Name&gt;An: $cont4&lt;/Name&gt;\r\n";
        $callsoap .= "&lt;Number&gt;Nr: $cont5&lt;/Number&gt;\r\n";
        $callsoap .= "&lt;/Receiver&gt;\r\n";
        $callsoap .= "&lt;Sender&gt;\r\n";
        $callsoap .= "&lt;Name&gt;Von: $cont2&lt;/Name&gt;\r\n";
        $callsoap .= "&lt;Number&gt;Nr: $cont3&lt;/Number&gt;\r\n";
        $callsoap .= "&lt;/Sender&gt;\r\n";
        $callsoap .= "&lt;Body&gt;Inhalt: $body&lt;/Body&gt;\r\n";
        $callsoap .= "</Message>\r\n";
        $callsoap .= "</u:AddMessage>\r\n";
        $callsoap .= "</s:Body>\r\n";
        $callsoap .= "</s:Envelope>\r\n";

        $size = length($callsoap);
        $head .= "POST /PMR/control/MessageBoxService HTTP/1.1\r\n";
        $head .= "Content-Type: text/xml; charset=\"utf-8\"\r\n";
        $head .= "SOAPACTION: \"urn:samsung.com:service:MessageBoxService:1#AddMessage\"\r\n";
        $head .= "Cache-Control: no-cache\r\n";
        $head .= "Host: $TV:52235\r\n";
        $head .= "Content-Length: $size\r\n";
        $head .= "Connection: Close\r\n";
        $head .= "\r\n";

        $message .= $head;
        $message .= $callsoap;
   }

  if ( $kind eq 4 ){ # Termin
        $callsoap .= "<?xml version=\"1.0\" encoding=\"utf-8\"?>\r\n";
        $callsoap .= "<s:Envelope s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\" >\r\n";
        $callsoap .= "<s:Body>\r\n";
        $callsoap .= "<u:AddMessage xmlns:u=\"urn:samsung.com:service:MessageBoxService:1\\\">\r\n";
        $callsoap .= "<MessageType>text/xml</MessageType>\r\n";
        $callsoap .= "<MessageID>1334799348</MessageID>\r\n";
        $callsoap .= "<Message>\r\n";
        $callsoap .= "&lt;Category&gt;Schedule Reminder&lt;/Category&gt;\r\n";
        $callsoap .= "&lt;DisplayType&gt;Maximum&lt;/DisplayType&gt;\r\n";
        $callsoap .= "&lt;StartTime&gt;\r\n";
        $callsoap .= "&lt;Date&gt;$cont2&lt;/Date&gt;\r\n";
        $callsoap .= "&lt;Time&gt;$cont3&lt;/Time&gt;\r\n";
        $callsoap .= "&lt;/StartTime&gt;\r\n";
        $callsoap .= "&lt;Owner&gt;\r\n";
        $callsoap .= "&lt;Name&gt;Fr: $cont4&lt;/Name&gt;\r\n";
        $callsoap .= "&lt;Number&gt;Nr: $cont5&lt;/Number&gt;\r\n";
        $callsoap .= "&lt;/Owner&gt;\r\n";
        $callsoap .= "&lt;Subject&gt;Betreff: $cont6&lt;/Subject&gt;\r\n";
        $callsoap .= "&lt;EndTime&gt;\r\n";
        $callsoap .= "&lt;Date&gt;$cont7&lt;/Date&gt;\r\n";
        $callsoap .= "&lt;Time&gt;$cont8&lt;/Time&gt;\r\n";
        $callsoap .= "&lt;/EndTime&gt;\r\n";
        $callsoap .= "&lt;Location&gt;Ort: $cont9&lt;/Location&gt;\r\n";
        $callsoap .= "&lt;Body&gt;Inhalt: $body&lt;/Body&gt;\r\n";
        $callsoap .= "</Message>\r\n";
        $callsoap .= "</u:AddMessage>\r\n";
        $callsoap .= "</s:Body>\r\n";
        $callsoap .= "</s:Envelope>\r\n";

        $size = length($callsoap);
        $head .= "POST /PMR/control/MessageBoxService HTTP/1.1\r\n";
        $head .= "Content-Type: text/xml; charset=\"utf-8\"\r\n";
        $head .= "SOAPACTION: \"urn:samsung.com:service:MessageBoxService:1#AddMessage\"\r\n";
        $head .= "Cache-Control: no-cache\r\n";
        $head .= "Host: $TV:52235\r\n";
        $head .= "Content-Length: $size\r\n";
        $head .= "Connection: Close\r\n";
        $head .= "\r\n";

        $message .= $head;
        $message .= $callsoap;
  }

  if ( $kind ne 0 ){
    connection($message, $TV);
  }else{
    return "Unknown argument $name, choose one of mute:on,off volume:slider,0,1,100 call sms date";
  }
}

sub STV_Set($@)
{
  my ($hash, @a) = @_;
  my $nam = $a[0];
  my $name = $hash->{NAME};
  my $Port = $hash->{Port};
  my $cmd = (defined($a[1]) ? $a[1] : ""); #command
  my $par = (defined($a[2]) ? $a[2] : ""); #parameter
  if ($cmd eq "?" || $cmd eq "") {
       return $hash->{".validcommands"};
  }
  if ($hash->{".validcommands"} =~ /$cmd/) {
    if ($cmd eq "connect") {
        return STV_Connect($hash);
    }

    if ((AttrVal($name, "setWhenOffline", "execute") eq "ignore") and ($hash->{STATE} ne "opened")) {
      Log3 $name, 3, "[STV] Device seems offline. Set command ignored: $cmd";
      return;
    }
    
    if ($Port eq 55000 ){
        STV_55000($hash,$nam,$cmd);
    }
    elsif ($Port eq 52235 ){
        STV_52235($hash,@_);
    }
  } else {
    my $ret = "[STV] Invalid command $cmd. Use any of:\n";
    my @cmds = split(" ",$hash->{".validcommands"});
    foreach my $line (0..$#cmds) {
      $ret .= "\n" if ($line > 1 && $line/10 == int($line/10));
      $ret .= $cmds[$line]." ";
    }
    return $ret;
  }
  return undef;
}

1;

=pod
=item summary device to communicate with an Samsung Television
=begin html

<a name="STV"></a>

<h3>STV</h3>
<ul><p>
This module supports Samsung TV devices.<br>
LEXXBXX (B Series) use port 52235 <br>
LEXXCXX (C|D Series) use port 55000 <br>
</p>
 <b>Define</b><br>
  <code>define &lt;name&gt; STV &lt;host&gt;]</code><br>
  <p>
  Example:<br>
  define Television1 STV 192.168.178.20 <br> or
  define Television2 STV 192.168.178.20 52235 <br>
  define Television2 STV 192.168.178.20 55000 <br>
  </p>
 <b>Set</b><br>
  set &lt;name&gt; &lt;value&gt; &lt;nummber&gt;<br>where value is one of:<br><br>
  <ul>
  <li><code>mute</code> </li>
  <li><code>volume </code> </li>
  <li><code>call</code> </li>
  <li><code>sms  </code> </li>
  <li><code>date </code> </li>
  </ul>
   <br>Example:<br>
  set &lt;name&gt; mute <br>
  set &lt;name&gt; volume 20 <br>
  set &lt;name&gt; call Peter 012345678 Phone 87654321 <br><br>
  
 <b>Get</b><br>
   <ul>N/A</ul><br>
</ul>
   
=end html
=cut
