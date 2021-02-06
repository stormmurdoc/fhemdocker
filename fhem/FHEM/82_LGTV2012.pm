# $Id: 82_LGTV2012.pm 2 2014-03-17 11:05:19Z juliantatsch $
##############################################################################
#
# 82_LGTV2012.pm
#
# a module to send messages or commands to a LG TV Model Year 2012
#
# written 2014 by Julian Tatsch <tatsch at gmail.com>>
#
# $Id$
#
# Version = 0.3
#
##############################################################################
#
# define <name> LGTV2012 <HOST>
#
# set <name> <command>
# e.g set <name> mute
# get <name> <command>
# e.g. get <name> inputSourceName
##############################################################################

package main;

use warnings;
use strict;
use LWP::UserAgent;
use HTTP::Request::Common;
use XML::Simple;


sub LGTV2012_displayPairingCode($);
sub LGTV2012_Pair($);
sub LGTV2012_getInfo($$);
sub LGTV2012_sendCommand($$);

my %sets = (
    displayPairingCode=>-1,
    power_on=>-1,
    pair=>-1,
	power=>1,
    number0=>2,
	number1=>3,
	number2=>4,
	number3=>5,
	number4=>6,
	number5=>7,
	number6=>8,
	number7=>9,
	number8=>10,
	number9=>11,
	up=>12,
	down=>13,
	left=>14,
	right=>15,
	ok=>20,
	home=>21,
	menu=>22,
	previous=>23,
	volume_up=>24,
	volume_down=>25,
	mute=>26,
	ch_up=>27,
	ch_down=>28,
	blue=>29,
	green=>30,
	red=>31,
	yellow=>32,
	play=>33,
	pause=>34,
	stop=>35,
	fastforward=>36,
	rewind=>37,
	skip_fw=>38,
	skip_bw=>39,
	record=>40,
	recordinglist=>41,
	repeat=>42,
	livetv=>43,
	epg=>44,
	currentproginfo=>45,
	aspectratio=>46,
	externalinput=>47,
	pip_secondaryvideo=>48,
	subtitle=>49,
	proglist=>50,
	teletext=>51,
	mark=>52,
	threedvideo=>400,
	threed_L_R=>401,
	dash=>402,
	prevchannel=>403,
	favchanel=>404,
	quickmenu=>405,
	textoption=>406,
	audiodescription=>407,
	netcast=>408,
	energysaving=>409,
	a_v_mode=>410,
	simplink=>411,
	exit=>412,
	reservationproglist=>413,
	pip_channel_up=>414,
	pip_channel_down=>415,
	switch_pri_sec_video=>416,
	myapps=>417,
);

my %gets = (
    inputSourceName=>-1,
);

my $userAgent = LWP::UserAgent->new;
$userAgent->agent('Linux/2.6.18 UDAP/2.0 CentOS/5.8');


sub
LGTV2012_Initialize($)
{
my ($hash) = @_;
    
 $hash->{DefFn}    = "LGTV2012_Define";
 $hash->{UndefFn}  = "LGTV2012_Undefine";
 $hash->{SetFn}    = "LGTV2012_Set";
 $hash->{GetFn}    = "LGTV2012_Get";
 $hash->{NotifyFn}    = "LGTV2012_Notify";
 $hash->{AttrList} = "pairingcode presencedevice poweroncmd verbose:0,1,2,3,4,5 ".$readingFnAttributes;

}

sub
LGTV2012_Define($$)
{
    my ($hash, $def) = @_;
    my @args = split("[ \t]+", $def);
    my $name = $hash->{NAME};
    if (int(@args) < 2)
    {
        return "LGTV2012: not enough arguments. Usage: " .
        "define <name> LGTV2012 <HOST>";
    }
    
    $hash->{HOST} = $args[2];
    $hash->{PORT} = "8080";
    $hash->{INTERVAL} = 30;
    
    Log3 $name, 2, "LGTV2012: Created new device ".$hash->{NAME}." ".$hash->{HOST}.":".$hash->{PORT};
    $hash->{STATE} = 'defined';
    return undef;
}

sub
LGTV2012_Get($@)
{
  my ($hash, @args) = @_;
  my $name = $hash->{NAME};
  return "Unknown argument $args[1], choose one of ".join(" ", sort keys %gets)
    if(!defined($gets{$args[1]}));
  my $what = $args[1];
  my $state = $args[2];
  my $value = $args[3];
  if($what eq "inputSourceName"){
  	return LGTV2012_getInfo($hash,$gets{$what});
  }
  return undef;
}

sub
LGTV2012_Set($@)
{
  my ($hash, @args) = @_;
  my $name = $hash->{NAME};
  return "Unknown argument $args[1], choose one of ".join(" ", sort keys %sets)
    if(!defined($sets{$args[1]}));
  my $what = $args[1];
  my $state = $args[2];
  my $value = $args[3];
    
  if($what eq "displayPairingCode"){
      LGTV2012_displayPairingCode($hash);
  } elsif ($what eq "power_on") {
  		system(AttrVal($name,"poweroncmd",undef));
  } else {
      LGTV2012_sendCommand($hash,$sets{$what});
  }
  return undef;
}

sub
LGTV2012_Notify($$)
{
  my ($hash, $dev) = @_;
  my $name = $hash->{NAME};
  return "" if(AttrVal($name, "disable", undef));
  return "" if(!defined(AttrVal($name,"presencedevice",undef)));
  my $devName = $dev->{NAME};
  my $presencedevice = $attr{$name}{presencedevice};
  my $max = int(@{$dev->{CHANGED}});
  my $tn;
  my $myIdx = $max;

  for (my $i = 0; $i < $max; $i++) {
    my $s = $dev->{CHANGED}[$i];

    ################
    # Filtering
    next if(!defined($s));
    my ($evName, $val) = split(" ", $s, 2); # resets $1
    if($devName eq $presencedevice)
    {
    	if($s eq "present")
    	{
        	Log3 $name, 2, "LGTV2012: Presence indicated device is back, re-pairing...";
        	$hash->{STATE} = 'present';
    		LGTV2012_Pair($hash);
    		InternalTimer(gettimeofday()+$hash->{INTERVAL}, "LGTV2012_getUpdate", $hash, 0);
    	} else {
    		RemoveInternalTimer($hash);
    		$hash->{STATE} = 'absent';
    	}
    }
    }
    return undef;
}


sub
LGTV2012_Undefine($$)
{
  my ($hash,$args) = @_;
  my $name = $hash->{NAME};
  my $path="/udap/api/pairing";
  my $byeReq='<?xml version="1.0" encoding="utf-8"?><envelope><api type="pairing"><name>byebye</name><port>8080</port></api></envelope>';
  my $postUrl="http://".$hash->{HOST}.":".$hash->{PORT}.$path;
  my $response = $userAgent->request(POST($postUrl, Content_Type => 'text/xml', Content => $byeReq));
  if( $response->is_success ){
        Log3 $name, 2, "LGTV2012: Ended Pairing Successfuly";
        Log3 $name, 2, "LGTV2012: TV Response :".$response->decoded_content;
        $hash->{STATE} = 'defined';
    } else {
    	if($response->status_line eq "400 Bad Request"){
    		Log3 $name, 2, "LGTV2012: HTTP/1.1 400 Bad Request, The byebye request is transmitted in an incorrect format.";
    	} elsif ($response->status_line eq "401 Unauthorized"){
    		Log3 $name, 2, "LGTV2012: HTTP/1.1 401 Unauthorized, The byebye request is transmitted from a Controller that is not paired.";
    	} else {
    	    Log3 $name, 2, "LGTV2012: An unknown error has occured";
    	}
        Log3 $name, 2, "LGTV2012: Could not send byebye request";
        Log3 $name, 2, "LGTV2012: TV Response :".$response->decoded_content;
    }
    RemoveInternalTimer($hash);
    return undef;
}


sub
LGTV2012_displayPairingCode($)
{
    my ($hash) = @_;
    my $name = $hash->{NAME};
    my $path="/udap/api/pairing";
    my $AUTHKEYReq='<?xml version="1.0" encoding="utf-8"?><envelope><api type="pairing"><name>showKey</name></api></envelope>';
    my $postUrl="http://".$hash->{HOST}.":".$hash->{PORT}.$path;
    Log3 $name, 4, "LGTV2012: Displaying pairing code at ".$postUrl;
    my $response = $userAgent->request(POST($postUrl, Content_Type => 'text/xml', Content => $AUTHKEYReq));
    if( $response->is_success ){
        Log3 $name, 4, "LGTV2012: Displaying pairing code successful";
    } else {
        Log3 $name, 4, "LGTV2012: Could not display pairing code. You may have to restart your TV.";
        Log3 $name, 4, "LGTV2012: TV Response :".$response->decoded_content;
    }
    return undef;
}

sub
LGTV2012_Pair($)
{
    my ($hash) = @_;
    my $name = $hash->{NAME};
    if(!defined(AttrVal($name,"pairingcode",undef))){
    	LGTV2012_displayPairingCode($hash);
    	return "LGTV2012: Cannot pair without pairingcode, please add a pairingcode attribute";
    }
    my $pairingcode = $attr{$name}{pairingcode};
    my $path="/udap/api/pairing";
    my $authReq='<?xml version="1.0" encoding="utf-8"?><envelope><api type="pairing"><name>hello</name><value>'.$pairingcode.'</value><port>8080</port></api></envelope>';
    my $postUrl="http://".$hash->{HOST}.":".$hash->{PORT}.$path;
    Log3 $name, 2, "LGTV2012: Pairing request with key ".$pairingcode." at ".$postUrl;
    my $response = $userAgent->request(POST($postUrl, Content_Type => 'text/xml', Content => $authReq));
    if( $response->is_success ){
        Log3 $name, 2, "LGTV2012: Pairing Successful";
        Log3 $name, 4, "LGTV2012: TV Response :".$response->decoded_content;
        $hash->{STATE} = 'paired';
    } else {
    	if($response->status_line eq "400 Bad Request"){
    		Log3 $name, 2, "LGTV2012: HTTP/1.1 400 Bad Request, the command format is not valid or it has an incorrect value";
    	} elsif ($response->status_line eq "401 Unauthorized"){
    		Log3 $name, 2, "LGTV2012: HTTP/1.1 401 Unauthorized, a command is sent when a Host and a Controller are not paired.";
    	} elsif ($response->status_line eq "404 Not Found"){
    		Log3 $name, 2, "LGTV2012: HTTP/1.1 404 Not Found, the POST path of a command is incorrect.";
    	} elsif ($response->status_line eq "500 Internal Server Error"){
    	    Log3 $name, 2, "LGTV2012: HTTP/1.1 500 Internal Server Error, the command execution has failed.";
    	} else {
    	    Log3 $name, 2, "LGTV2012: An unknown error has occured.";
    	}
        Log3 $name, 2, "LGTV2012: Could not send pairing request.";
        Log3 $name, 2, "LGTV2012: TV Response :".$response->decoded_content;
    }
    return undef;
}

sub
LGTV2012_getUpdate($)
{
  my ($hash) = @_;
  my $name = $hash->{NAME};
  LGTV2012_getInfo($hash,"inputSourceName");
  if(ReadingsVal($name,"presence",undef)){
  	InternalTimer(gettimeofday()+$hash->{INTERVAL}, "LGTV2012_getUpdate", $hash, 0);
  }

  return undef;
}

sub
LGTV2012_getInfo($$)
{
    my ($hash,$command) = @_;
    my $name = $hash->{NAME};
    if($hash->{STATE} ne 'paired'){
        LGTV2012_Pair($hash);
    }
    my $path="/udap/api/data?target=cur_channel";
    my $postUrl="http://".$hash->{HOST}.":".$hash->{PORT}.$path;
    my $response = $userAgent->get($postUrl);
    if($response->is_success){
        Log3 $name, 4, "LGTV2012: Received info :".$response->decoded_content;
        my $xml = XMLin($response->content,SuppressEmpty => undef);
        my $inputSourceName = $xml->{dataList}->{data}->{inputSourceName};
        Log3 $name, 2, "LGTV2012: Current inputSourceName :".$inputSourceName;
        if(!$inputSourceName){
            $inputSourceName="Unknown";
        }
        readingsBeginUpdate($hash);
        readingsBulkUpdate($hash, "inputSourceName", $inputSourceName);
        readingsEndUpdate($hash, 1);
		return $inputSourceName;
    } else {
        if($response->status_line eq "400 Bad Request"){
    		Log3 $name, 2, "LGTV2012: HTTP/1.1 400 Bad Request, the command format is not valid or it has an incorrect value.";
    	} elsif ($response->status_line eq "401 Unauthorized"){
    		Log3 $name, 2, "LGTV2012: HTTP/1.1 401 Unauthorized, info is requested when a Host and a Controller are not paired.";
    		LGTV2012_Pair($hash);
    		getInfo($hash,$command);
    	} elsif ($response->status_line eq "404 Not Found"){
    		Log3 $name, 2, "LGTV2012: HTTP/1.1 404 Not Found, the GET path of a command is incorrect.";
    	} elsif ($response->status_line eq "500 Internal Server Error"){
    	    Log3 $name, 2, "LGTV2012: HTTP/1.1 500 Internal Server Error, the command execution has failed.";
    	} else {
    	    Log3 $name, 2, "LGTV2012: An unknown error has occured.";
    	}
        Log3 $name, 2, "LGTV2012: Could not get info";
        Log3 $name, 4, "LGTV2012: TV Response :".$response->decoded_content;
    }
    return undef;
}

sub
LGTV2012_sendCommand($$)
{
    my ($hash,$command) = @_;
    my $name = $hash->{NAME};
    if($hash->{STATE} ne 'paired'){
        LGTV2012_Pair($hash);
    }
    my $handleInput='<?xml version="1.0" encoding="utf-8"?><envelope><api type="command"><name>HandleKeyInput</name><value>'.$command.'</value></api></envelope>';
    Log3 $name, 2, "LGTV2012: Now sending command ".$command;
    Log3 $name, 2, "LGTV2012: HandleInput ".$handleInput;
    my $path="/udap/api/command";
    my $postUrl="http://".$hash->{HOST}.":".$hash->{PORT}.$path;
    my $response = $userAgent->request(POST($postUrl, Content_Type => 'text/xml', Content => $handleInput));
    if($response->is_success){
        Log3 $name, 2, "LGTV2012: Command sent successfully";
        Log3 $name, 2, "LGTV2012: TV Response :".$response->decoded_content;
    } else {
        if($response->status_line eq "400 Bad Request"){
    		Log3 $name, 2, "LGTV2012: HTTP/1.1 400 Bad Request, the command format is not valid or it has an incorrect value.";
    	} elsif ($response->status_line eq "401 Unauthorized"){
    		Log3 $name, 2, "LGTV2012: HTTP/1.1 401 Unauthorized, a command is sent when a Host and a Controller are not paired.";
    		LGTV2012_Pair($hash);
    		sendCommand($hash,$command);
    	} elsif ($response->status_line eq "404 Not Found"){
    		Log3 $name, 2, "LGTV2012: HTTP/1.1 404 Not Found, the POST path of a command is incorrect.";
    	} elsif ($response->status_line eq "500 Internal Server Error"){
    	    Log3 $name, 2, "LGTV2012: HTTP/1.1 500 Internal Server Error, the command execution has failed.";
    	} else {
    	    Log3 $name, 2, "LGTV2012: An unknown error has occured";
    	}
        Log3 $name, 2, "LGTV2012: Could not send command.";
        Log3 $name, 2, "LGTV2012: TV Response :".$response->decoded_content;
    }
    return undef;
}

1;

=pod
=begin html

<a name="LGTV2012"></a>

<h3>LGTV2012</h3>
<ul><p>
This module supports sending remote commands over ethernet/wifi to LGTVs of the 2012 and 2013 Series.<br>
</p>
 <b>Define</b><br>
  <code>define &lt;name&gt; LGTV2012 &lt;HOST&gt;]</code><br>
  <p>
  Example:<br>
  define myTV LGTV2012 192.168.178.20 <br>
  </p>
 <b>Get</b><br>
  get &lt;name&gt; &lt;value&gt; &lt;nummber&gt;<br>where value is one of:<br><br>
  <ul>
  <li><code>inputSourceName</code> </li>
  </ul>
  <b>Set</b><br>
  set &lt;name&gt; &lt;value&gt; &lt;nummber&gt;<br>where value is one of:<br><br>
  <ul>
  <li><code>displayPairingCode</code> </li>
  <li><code>play</code> </li>
  <li><code>pause</code> </li>
  <li><code>mute</code> </li>
  </ul>

   
=end html
=cut

