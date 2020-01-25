##############################################
#
# fhem driver for MySensors serial or network gateway (see http://mysensors.org)
#
# Copyright (C) 2014 Norbert Truchsess
# Copyright (C) 2019 Hauswart@forum.fhem.de
# Copyright (C) 2019 Beta-User@forum.fhem.de
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
# $Id: 00_MYSENSORS.pm 20188 2019-09-18 14:21:36Z Beta-User $
#
##############################################

my %sets = (
  "connect" => [],
  "disconnect" => [],
  "inclusion-mode" => [qw(on off)],
);

my %gets = (
  "version"   => ""
);

my @clients = qw(
  MYSENSORS_DEVICE
);

sub MYSENSORS_Initialize($) {

  my $hash = shift @_;

  require "$main::attr{global}{modpath}/FHEM/DevIo.pm";

  # Provider
  $hash->{Clients} = join (':',@clients);
  $hash->{ReadyFn} = "MYSENSORS::Ready";
  $hash->{ReadFn}  = "MYSENSORS::Read";

  # Consumer
  $hash->{DefFn}    = "MYSENSORS::Define";
  $hash->{UndefFn}  = "MYSENSORS::Undef";
  $hash->{SetFn}    = "MYSENSORS::Set";
  $hash->{AttrFn}   = "MYSENSORS::Attr";
  $hash->{NotifyFn} = "MYSENSORS::Notify";

   my @attrList = qw(
    autocreate:1
    requestAck:1
    first-sensorid
    last-sensorid
    stateFormat
    OTA_firmwareConfig
  );
  $hash->{AttrList} = $hash->{AttrList} = join(" ", @attrList)
}

  
package MYSENSORS;

use Exporter ('import');
@EXPORT = ();
@EXPORT_OK = qw(
                sendMessage
                getFirmwareTypes
                getLatestFirmware
            );
%EXPORT_TAGS = (all => [@EXPORT_OK]);

use strict;
use warnings;

use GPUtils qw(:all);

use Device::MySensors::Constants qw(:all);
use Device::MySensors::Message qw(:all);

BEGIN {GP_Import(qw(
  CommandDefine
  CommandModify
  CommandAttr
  gettimeofday
  readingsSingleUpdate
  DevIo_OpenDev
  DevIo_SimpleWrite
  DevIo_SimpleRead
  DevIo_CloseDev
  RemoveInternalTimer
  InternalTimer
  AttrVal
  Log3
  FileRead
  ))};

my %sensorAttr = (
  LIGHT => ['setCommands on:V_LIGHT:1 off:V_LIGHT:0' ],
  ARDUINO_NODE => [ 'config M' ],
  ARDUINO_REPEATER_NODE => [ 'config M' ],
);

sub Define($$) {
  my ( $hash, $def ) = @_;

  $hash->{NOTIFYDEV} = "global";

  if ($main::init_done) {
    return Start($hash);
  } else {
    return undef;
  }
}

sub Undef($) {
  Stop(shift);
  return undef;
}

sub Set($@) {
  my ($hash, @a) = @_;
  return "Need at least one parameters" if(@a < 2);
  return "Unknown argument $a[1], choose one of " . join(" ", map {@{$sets{$_}} ? $_.':'.join ',', @{$sets{$_}} : $_} sort keys %sets)
    if(!defined($sets{$a[1]}));
  my $command = $a[1];
  my $value = $a[2];

  COMMAND_HANDLER: {
    $command eq "connect" and do {
      Start($hash);
      last;
    };
    $command eq "disconnect" and do {
      Stop($hash);
      last;
    };
    $command eq "inclusion-mode" and do {
      sendMessage($hash,radioId => 0, childId => 0, cmd => C_INTERNAL, ack => 0, subType => I_INCLUSION_MODE, payload => $value eq 'on' ? 1 : 0);
      $hash->{'inclusion-mode'} = $value eq 'on' ? 1 : 0;
      last;
    };
  };
}

sub Attr($$$$) {
  my ($command,$name,$attribute,$value) = @_;

  my $hash = $main::defs{$name};
  ATTRIBUTE_HANDLER: {
    $attribute eq "autocreate" and do {
      if ($main::init_done) {
        my $mode = $command eq "set" ? 1 : 0;
        sendMessage($hash,radioId => $hash->{radioId}, childId => $hash->{childId}, ack => 0, subType => I_INCLUSION_MODE, payload => $mode);
        $hash->{'inclusion-mode'} = $mode;
      }
      last;
    };
    $attribute eq "requestAck" and do {
      if ($command eq "set") {
        $hash->{ack} = 1;
      } else {
        $hash->{ack} = 0;
        $hash->{messages} = {};
        $hash->{outstandingAck} = 0;
      }
      last;
    };
    $attribute eq "OTA_firmwareConfig" and do {
      last;
    };  
  }
}

sub Notify($$) {
  my ($hash,$dev) = @_;
  if( grep(m/^(INITIALIZED|REREADCFG)$/, @{$dev->{CHANGED}}) ) {
    Start($hash);
  } elsif( grep(m/^SAVE$/, @{$dev->{CHANGED}}) ) {
  }
}

sub Start($) {
  my $hash = shift;
  my ($dev) = split("[ \t]+", $hash->{DEF});
  $hash->{DeviceName} = $dev;
  CommandAttr(undef, "$hash->{NAME} stateFormat connection") unless AttrVal($hash->{NAME},"stateFormat",undef);
  DevIo_CloseDev($hash);
  return DevIo_OpenDev($hash, 0, "MYSENSORS::Init");
}

sub Stop($) {
  my $hash = shift;
  DevIo_CloseDev($hash);
  RemoveInternalTimer($hash);
  readingsSingleUpdate($hash,"connection","disconnected",1);
}

sub Ready($) {
  my $hash = shift;
  return DevIo_OpenDev($hash, 1, "MYSENSORS::Init") if($hash->{STATE} eq "disconnected");
    if(defined($hash->{USBDev})) {
    my $po = $hash->{USBDev};
    my ( $BlockingFlags, $InBytes, $OutBytes, $ErrorFlags ) = $po->status;
    return ( $InBytes > 0 );
    }
}

sub Init($) {
  my $hash = shift;
  my $name = $hash->{NAME};
  $hash->{'inclusion-mode'} = AttrVal($name,"autocreate",0);
  $hash->{ack} = AttrVal($name,"requestAck",0);
  $hash->{outstandingAck} = 0;
  if ($hash->{ack}) {
    GP_ForallClients($hash,sub {
      my $client = shift;
      $hash->{messagesForRadioId}->{$client->{radioId}} = {
        lastseen => -1,
        nexttry  => -1,
        numtries => 1,
        messages => [],
      };
    });
  }
  readingsSingleUpdate($hash,"connection","connected",1);
  sendMessage($hash, radioId => 0, childId => 0, cmd => C_INTERNAL, ack => 0, subType => I_VERSION, payload => '');
  return undef;
}


# GetConnectStatus
sub GetConnectStatus($){
    my ($hash) = @_;
    my $name = $hash->{NAME};
    Log3 $name, 4, "MySensors: GetConnectStatus called ...";
    
    #query heartbeat from gateway 
    sendMessage($hash, radioId => 0, childId => 0, cmd => C_INTERNAL, ack => 0, subType => I_HEARTBEAT_REQUEST, payload => '');
 
    # neuen Timer starten in einem konfigurierten Interval.
    InternalTimer(gettimeofday()+300, "MYSENSORS::GetConnectStatus", $hash);# Restart check in 5 mins again
    InternalTimer(gettimeofday()+5, "MYSENSORS::Start", $hash);  #Start timer for reset if after 5 seconds RESPONSE is not received
    
}

sub Timer($) {
  my $hash = shift;
  my $now = time;
  foreach my $radioid (keys %{$hash->{messagesForRadioId}}) {
    my $msgsForId = $hash->{messagesForRadioId}->{$radioid};
    if ($now > $msgsForId->{nexttry}) {
      foreach my $msg (@{$msgsForId->{messages}}) {
        my $txt = createMsg(%$msg);
        Log3 ($hash->{NAME},5,"MYSENSORS outstanding ack, re-send: ".dumpMsg($msg));
        DevIo_SimpleWrite($hash,"$txt\n",undef);
      }
      $msgsForId->{numtries}++;
      $msgsForId->{nexttry} = gettimeofday()+$msgsForId->{numtries};
    }
  }
  _scheduleTimer($hash);
}

sub Read {
  my ($hash) = @_;
  my $name = $hash->{NAME};

  my $buf = DevIo_SimpleRead($hash);
  return "" if(!defined($buf));

  my $data = $hash->{PARTIAL};
  Log3 ($name, 4, "MYSENSORS/RAW: $data/$buf");
  $data .= $buf;

  while ($data =~ m/\n/) {
    my $txt;
    ($txt,$data) = split("\n", $data, 2);
    $txt =~ s/\r//;
    if (my $msg = parseMsg($txt)) {
      Log3 ($name,4,"MYSENSORS Read: ".dumpMsg($msg));
      if ($msg->{ack}) {
        onAcknowledge($hash,$msg);
      }
      RemoveInternalTimer($hash,"MYSENSORS::GetConnectStatus");
      InternalTimer(gettimeofday()+300, "MYSENSORS::GetConnectStatus", $hash);# Restart check in 5 mins again
      
      my $type = $msg->{cmd};
      MESSAGE_TYPE: {
        $type == C_PRESENTATION and do {
          onPresentationMsg($hash,$msg);
          last;
        };
        $type == C_SET and do {
          onSetMsg($hash,$msg);
          last;
        };
        $type == C_REQ and do {
          onRequestMsg($hash,$msg);
          last;
        };
        $type == C_INTERNAL and do {
          onInternalMsg($hash,$msg);
          last;
        };
        $type == C_STREAM and do {
          onStreamMsg($hash,$msg);
          last;
        };
      }
    } else {
      Log3 ($name,5,"MYSENSORS Read: ".$txt."is no parsable mysensors message");
    }
  }
  $hash->{PARTIAL} = $data;
  return undef;
};

sub onPresentationMsg($$) {
  my ($hash,$msg) = @_;
  my $client = matchClient($hash,$msg);
  my $clientname;
  my $sensorType = $msg->{subType};
  unless ($client) {
    if ($hash->{'inclusion-mode'}) {
      $clientname = "MYSENSOR_$msg->{radioId}";
      $clientname = "$hash->{NAME}_DEVICE_0"if defined $main::defs{$clientname}; 
      CommandDefine(undef,"$clientname MYSENSORS_DEVICE $msg->{radioId}");
      CommandAttr(undef,"$clientname IODev $hash->{NAME}");
      CommandAttr(undef,"$clientname room MYSENSORS_DEVICE");
      $client = $main::defs{$clientname};
      return unless ($client);
    } else {
      Log3($hash->{NAME},3,"MYSENSORS: ignoring presentation-msg from unknown radioId $msg->{radioId}, childId $msg->{childId}, sensorType $sensorType");
      return;
    }
  }
  MYSENSORS::DEVICE::onPresentationMessage($client,$msg);
};

sub onSetMsg($$) {
  my ($hash,$msg) = @_;
  if (my $client = matchClient($hash,$msg)) {
    MYSENSORS::DEVICE::onSetMessage($client,$msg);
  } else {
    Log3($hash->{NAME},3,"MYSENSORS: ignoring set-msg from unknown radioId $msg->{radioId}, childId $msg->{childId} for ".variableTypeToStr($msg->{subType}));
  }
};

sub onRequestMsg($$) {
  my ($hash,$msg) = @_;
  if (my $client = matchClient($hash,$msg)) {
    MYSENSORS::DEVICE::onRequestMessage($client,$msg);
  } else {
    Log3($hash->{NAME},3,"MYSENSORS: ignoring req-msg from unknown radioId $msg->{radioId}, childId $msg->{childId} for ".variableTypeToStr($msg->{subType}));
  }
};

sub onInternalMsg($$) {
  my ($hash,$msg) = @_;
  my $address = $msg->{radioId};
  my $type = $msg->{subType};
  if ($address == 0 or $address == 255) { #msg to or from gateway
    TYPE: {
      $type == I_INCLUSION_MODE and do {
        if (AttrVal($hash->{NAME},"autocreate",0)) { #if autocreate is switched on, keep gateways inclusion-mode active
          if ($msg->{payload} == 0) {
            sendMessage($hash,radioId => $msg->{radioId}, childId => $msg->{childId}, ack => 0, subType => I_INCLUSION_MODE, payload => 1);
          }
        } else {
          $hash->{'inclusion-mode'} = $msg->{payload};
        }
        last;
      };
      $type == I_GATEWAY_READY and do {
        readingsSingleUpdate($hash,'connection','startup complete',1);
        GP_ForallClients($hash,sub {
          my $client = shift;
          MYSENSORS::DEVICE::onGatewayStarted($client);
        });
        InternalTimer(gettimeofday()+300, "MYSENSORS::GetConnectStatus", $hash);
        last;
      };
      $type == I_HEARTBEAT_RESPONSE and do {
         RemoveInternalTimer($hash,"MYSENSORS::Start"); ## Reset reconnect because timeout was not reached
         readingsSingleUpdate($hash, "heartbeat", "alive", 0);
         if (my $client = matchClient($hash,$msg)){ MYSENSORS::DEVICE::onInternalMessage($client,$msg) };
      };
      $type == I_VERSION and do {
        $hash->{version} = $msg->{payload};
        last;
      };
      $type == I_LOG_MESSAGE and do {
        Log3($hash->{NAME},5,"MYSENSORS gateway $hash->{NAME}: $msg->{payload}");
        last;
      };
      $type == I_ID_REQUEST and do {
        if ($hash->{'inclusion-mode'}) {
          my %nodes = map {$_ => 1} (AttrVal($hash->{NAME},"first-sensorid",20) ... AttrVal($hash->{NAME},"last-sensorid",254));
          GP_ForallClients($hash,sub {
            my $client = shift;
            delete $nodes{$client->{radioId}};
          });
          if (keys %nodes) {
            my $newid = (sort keys %nodes)[0];
            sendMessage($hash,radioId => 255, childId => 255, cmd => C_INTERNAL, ack => 0, subType => I_ID_RESPONSE, payload => $newid);
            Log3($hash->{NAME},4,"MYSENSORS $hash->{NAME} assigned new nodeid $newid");
          } else {
            Log3($hash->{NAME},4,"MYSENSORS $hash->{NAME} cannot assign new nodeid");
          }
        } else {
          Log3($hash->{NAME},4,"MYSENSORS: ignoring id-request-msg from unknown radioId $msg->{radioId}");
        }
        last;
      };
    }
  } elsif (my $client = matchClient($hash,$msg)) {
    MYSENSORS::DEVICE::onInternalMessage($client,$msg);
  } elsif ($client = matchChan76GWClient($hash,$msg)) {
    Log3($hash->{NAME}, 4, "$hash->{NAME}: received stream message for $client - Chan76-IODev");
    MYSENSORS::DEVICE::onInternalMessage($client,$msg);
  } else {
    Log3($hash->{NAME},3,"MYSENSORS: ignoring internal-msg from unknown radioId $msg->{radioId}, childId $msg->{childId} for ".internalMessageTypeToStr($msg->{subType}));
  }
};

sub onStreamMsg($$) {
  my ($hash,$msg) = @_;
  my $client;
  if ($client = matchClient($hash, $msg)) {
    Log3($hash->{NAME}, 4, "$hash->{NAME}: received stream message for $client - regular IODev");
    MYSENSORS::DEVICE::onStreamMessage($client, $msg);
  } elsif ($client = matchChan76GWClient($hash,$msg)) {
    Log3($hash->{NAME}, 4, "$hash->{NAME}: received stream message for $client - Chan76-IODev");
    MYSENSORS::DEVICE::onStreamMessage($client,$msg);
  } else {
    Log3($hash->{NAME},3,"MYSENSORS: ignoring stream-msg from unknown radioId $msg->{radioId}, childId $msg->{childId} for ".datastreamTypeToStr($msg->{subType}));
  }
}

sub onAcknowledge($$) {
  my ($hash,$msg) = @_;
  my $ack;
  if (defined (my $outstanding = $hash->{messagesForRadioId}->{$msg->{radioId}}->{messages})) {
    my @remainMsg = grep {
         $_->{childId} != $msg->{childId}
      or $_->{cmd}     != $msg->{cmd}
      or $_->{subType} != $msg->{subType}
      or $_->{payload} ne $msg->{payload}
    } @$outstanding;
    if ($ack = @remainMsg < @$outstanding) {
      $hash->{outstandingAck} -= 1;
      @$outstanding = @remainMsg;
    }
    $hash->{messagesForRadioId}->{$msg->{radioId}}->{numtries} = 1;
  }
  Log3 ($hash->{NAME},4,"MYSENSORS Read: unexpected ack ".dumpMsg($msg)) unless $ack;
}

sub getFirmwareTypes($) {
  my ($hash) = @_;
  my $name = $hash->{NAME};
  my @fwTypes = ();
  my $filename = AttrVal($name, "OTA_firmwareConfig", undef);
  if (defined($filename)) {  
    my ($err, @lines) = FileRead({FileName => "./FHEM/firmware/" . $filename, 
                                  ForceType => "file"}); 
    if (defined($err) && $err) {
      Log3($name, 2, "$name: could not read MySensor firmware configuration file - $err");
    } else {
      for (my $i = 0; $i < @lines ; $i++) {
        chomp(my $row = $lines[$i]);
        if (index($row, "#") != 0) {
          my @tokens = split(",", $row);
          push(@fwTypes, $tokens[0]);
        }
      }
    }
  }
  Log3($name, 5, "$name: getFirmwareTypes - list contains: @fwTypes");
  return @fwTypes;
}

sub getLatestFirmware($$) {
  my ($hash, $type) = @_;
  my $name = $hash->{NAME};
  my $cfgfilename = AttrVal($name, "OTA_firmwareConfig", undef);
  my $version = undef;
  $name = undef;
  my $filename = undef;
  if (defined($cfgfilename)) {  
    my ($err, @lines) = FileRead({FileName => "./FHEM/firmware/" . $cfgfilename, 
                                  ForceType => "file"}); 
    if (defined($err) && $err) {
      Log3($name, 2, "$name: could not read MySensor firmware configuration file - $err");
    } else {
      for (my $i = 0; $i < @lines ; $i++) {
        chomp(my $row = $lines[$i]);
        if (index($row, "#") != 0) {
          my @tokens = split(",", $row);
          if ($tokens[0] eq $type) {
            if ((not defined $version) || ($tokens[2] > $version)) {
              $name = $tokens[1];
              $version = $tokens[2];
              $filename = $tokens[3];
            }
          }
        }
      }
    }
  }
  return ($version, $filename, $name);
}


sub sendMessage($%) {
  my ($hash,%msg) = @_;
  $msg{ack} = $hash->{ack} unless defined $msg{ack};
  my $txt = createMsg(%msg);
  Log3 ($hash->{NAME},5,"MYSENSORS send: ".dumpMsg(\%msg));
  DevIo_SimpleWrite($hash,"$txt\n",undef);
  if ($msg{ack}) {
    my $messagesForRadioId = $hash->{messagesForRadioId}->{$msg{radioId}};
    unless (defined $messagesForRadioId) {
      $messagesForRadioId = {
        lastseen => -1,
        numtries => 1,
        messages => [],
      };
      $hash->{messagesForRadioId}->{$msg{radioId}} = $messagesForRadioId;
    }
    my $messages = $messagesForRadioId->{messages};
    @$messages = grep {
         $_->{childId} != $msg{childId}
      or $_->{cmd}     != $msg{cmd}
      or $_->{subType} != $msg{subType}
    } @$messages;
    push @$messages,\%msg;

    $messagesForRadioId->{nexttry} = gettimeofday()+$messagesForRadioId->{numtries};
    _scheduleTimer($hash);
  }
};

sub _scheduleTimer($) {
  my ($hash) = @_;
  $hash->{outstandingAck} = 0;
  RemoveInternalTimer($hash,"MYSENSORS::Timer");
  my $next;
  foreach my $radioid (keys %{$hash->{messagesForRadioId}}) {
    my $msgsForId = $hash->{messagesForRadioId}->{$radioid};
    $hash->{outstandingAck} += @{$msgsForId->{messages}};
    $next = $msgsForId->{nexttry} unless (defined $next and $next < $msgsForId->{nexttry});
  };
  InternalTimer($next, "MYSENSORS::Timer", $hash, 0) if (defined $next);
}

sub matchClient($$) {
  my ($hash,$msg) = @_;
  my $radioId = $msg->{radioId};
  my $found;
  GP_ForallClients($hash,sub {
    return if $found;
    my $client = shift;
    if ($client->{radioId} == $radioId) {
      $found = $client;
    }
  });
  return $found;
}

sub matchChan76GWClient($$) {
  my ($hash,$msg) = @_;
  my $radioId = $msg->{radioId};
  my $found;
  foreach my $d ( sort keys %main::defs ) {
    if ( defined( $main::defs{$d} )
      && defined( $main::defs{$d}{radioId} )
      && $main::defs{$d}{radioId} == $radioId ) {
        my $clientname = $main::defs{$d}->{NAME};
        my $name = $hash->{NAME};
        $found = $main::defs{$d} if AttrVal($clientname,"OTA_Chan76_IODev","") eq $name;
    }
  }
  Log3($hash->{NAME}, 4, "$hash->{NAME}: matched firmware config request to hash $found, name: $found->{NAME}") if $found;
  return $found if $found;
  return undef;
}

1;

=pod
=item device
=item summary includes a MYSENSORS gateway
=item summary_DE integriert ein MYSENSORS Gateway

=begin html

<a name="MYSENSORS"></a>
<h3>MYSENSORS</h3>
<ul>
  <p>connects fhem to <a href="http://MYSENSORS.org">MYSENSORS</a>.</p>
  <p>A single MYSENSORS device can serve multiple <a href="#MYSENSORS_DEVICE">MYSENSORS_DEVICE</a> clients.<br/>
     Each <a href="#MYSENSORS_DEVICE">MYSENSORS_DEVICE</a> represents a mysensors node.<br/>
  <a name="MYSENSORSdefine"></a>
  <p><b>Define</b></p>
  <ul>
    <p><code>define &lt;name&gt; MYSENSORS &lt;serial device&gt|&lt;ip:port&gt;</code></p>
    <p>Specifies the MYSENSORS device.</p>
  </ul>
  <a name="MYSENSORSset"></a>
  <p><b>Set</b></p>
  <ul>
    <li>
      <p><code>set &lt;name&gt; connect</code><br/>
         (re-)connects the MYSENSORS-device to the MYSENSORS-gateway</p>
    </li>
    <li>
      <p><code>set &lt;name&gt; disconnect</code><br/>
         disconnects the MYSENSORS-device from the MYSENSORS-gateway</p>
    </li>
    <li>
      <p><code>set &lt;name&gt; inclusion-mode on|off</code><br/>
         turns the gateways inclusion-mode on or off</p>
    </li>
  </ul>
  <a name="MYSENSORSattr"></a>
  <p><b>Attributes</b></p>
  <ul>
    <li>
      <p><code>attr &lt;name&gt; autocreate</code><br/>
         enables auto-creation of MYSENSOR_DEVICE-devices on receival of presentation-messages</p>
    </li>
    <li>
      <p><code>attr &lt;name&gt; requestAck</code><br/>
         request acknowledge from nodes.<br/>
         if set the Readings of nodes are updated not before requested acknowledge is received<br/>
         if not set the Readings of nodes are updated immediatly (not awaiting the acknowledge).
         May also be configured for individual nodes if not set for gateway.</p>
    </li>
    <li>
      <p><code>attr &lt;name&gt; first-sensorid <&lt;number &lth; 255&gt;></code><br/>
         configures the lowest node-id assigned to a mysensor-node on request (defaults to 20)</p>
    </li>
    <li>
      <p><code>attr &lt;name&gt; OTA_firmwareConfig &lt;filename&gt;</code><br/>
         specifies a configuration file for the <a href="https://www.mysensors.org/about/fota">FOTA</a>
         (firmware over the air - wireless programming of the nodes) configuration. It must be stored 
         in the folder FHEM/firmware. The format of the configuration file is the following (csv):</p>
      <p><code>#Type,Name,Version,File,Comments</code><br/>
         <code>10,Blink,1,Blink.hex,blinking example</code><br/></p>
      <p>The meaning of the columns is the following:</br>
         <dl>
           <dt><code>Type</code></dt>
           <dd>a numeric value (range 0 .. 65536) - each node will be assigned a firmware type</dd>
           <dt><code>Name</code></dt>
           <dd>a short name for this type</dd>
           <dt><code>Version</code></dt> 
           <dd>a numeric value (range 0 .. 65536) - the version of the firmware (may be different 
               to the value that is send during the node presentation)</dd>
           <dt><code>File</code></dt>
           <dd>the filename containing the firmware - must also be stored in the folder FHEM/firmware</dd>
           <dt><code>Comments</code></dt>
           <dd>a description / comment for the firmware</dd>
         </dl></p>
    </li>
  </ul>
</ul>

=end html
=cut
