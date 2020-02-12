#
#  kaihs@FHEM_Forum (forum.fhem.de)
#
# $Id: 36_WMBUS.pm 21163 2020-02-09 18:41:03Z kaihs $
#
# 

package main;

use strict;
use warnings;
use SetExtensions;
use WMBus;


sub WMBUS_Parse($$);
sub WMBUS_SetReadings($$$);
sub WMBUS_SetRSSI($$$);
sub WMBUS_RSSIAsRaw($);

sub WMBUS_Initialize($) {
  my ($hash) = @_;

  $hash->{Match}     = "^b.*";
  $hash->{SetFn}     = "WMBUS_Set";
  #$hash->{GetFn}     = "WMBUS_Get";
  $hash->{DefFn}     = "WMBUS_Define";
  $hash->{UndefFn}   = "WMBUS_Undef";
  #$hash->{FingerprintFn}   = "WMBUS_Fingerprint";
  $hash->{ParseFn}   = "WMBUS_Parse";
  $hash->{AttrFn}    = "WMBUS_Attr";
  $hash->{AttrList}  = "IODev".
                       " AESkey".
                       " ignore:0,1".
                       " rawmsg_as_reading:0,1".
                       " ignoreUnknownDataBlocks:0,1".
                       " ignoreMasterMessages:0,1".
                       " useVIFasReadingName:0,1".
                       " $readingFnAttributes"
                       ;
}

sub 
WMBUS_HandleEncoding($$)
{
  my ($mb, $msg) = @_;
  my $encoding = "CUL";
  my $rssi;
  
  ($msg, $rssi) = split(/::/,$msg);
  
  if (substr($msg,1,3) eq "AMB") {
    # Amber Wireless AMB8425-M encoding, does not include CRC16
    $encoding = "AMB";
    $mb->setCRCsize(0);
    # message length (first byte) contains 1 byte for rssi,
    # remove it 
    my $msglen = sprintf("%1x", hex(substr($msg,4,1)) - 1);
    $msg = "b" . $msglen . substr($msg,5);
  } else {
    if (substr($msg,1,1) eq "Y") {
      $mb->setFrameType(WMBus::FRAME_TYPE_B);
      $msg = "b" . substr($msg,2);
    }
    $msg .= WMBUS_RSSIAsRaw($rssi);
  }
  return ($msg, $rssi, $encoding);
}

sub
WMBUS_Define($$)
{
  my ($hash, $def) = @_;
  my @a = split("[ \t][ \t]*", $def);
  my $mb;
  my $rssi;

  if(@a != 6 && @a != 3) {
    my $msg = "wrong syntax: define <name> WMBUS <ManufacturerID> <SerialNo> <Version> <Type> [<MessageEncoding>]|b[<MessageEncoding>]<HexMessage>";
    Log3 undef, 2, $msg;
    return $msg;
  }

  my $name = $a[0];

  if (@a == 3) {
    # unparsed message
    my $msg = $a[2];
    $mb = new WMBus;
    
    
    ($msg, $rssi, $hash->{MessageEncoding}) = WMBUS_HandleEncoding($mb, $msg);
    
    my $minSize = ($mb->getCRCsize() + WMBus::TL_BLOCK_SIZE) * 2;
    my $reMinSize = qr/b[a-zA-Z0-9]{${minSize},}/;
    
    return "a WMBus message must be a least $minSize bytes long, $msg" if $msg !~ m/${reMinSize}/;
    
    if ($mb->parseLinkLayer(pack('H*',substr($msg,1)))) {
      $hash->{Manufacturer} = $mb->{manufacturer};
      $hash->{IdentNumber} = $mb->{afield_id};
      $hash->{Version} = $mb->{afield_ver};
      $hash->{DeviceType} = $mb->{afield_type};
      if ($mb->{errormsg}) {
        $hash->{Error} = $mb->{errormsg};
      } else {
        delete $hash->{Error};
      }
      WMBUS_SetRSSI($hash, $mb, $rssi);
    } else {
      my $error = "failed to parse msg: $mb->{errormsg}";
      if ($mb->{errorcode} == WMBus::ERR_MSG_TOO_SHORT && $hash->{MessageEncoding} eq 'CUL') {
        $error .= ". Please make sure that TTY_BUFSIZE in culfw is at least two times the message length + 1";
      }
      return $error;
    }

  } else {
    my $encoding = "CUL";
    # manual specification
    if ($a[2] !~ m/[A-Z]{3}/) {
      return "$a[2] is not a valid WMBUS manufacturer id";
    }

    if ($a[3] !~ m/[0-9]{1,8}/) {
      return "$a[3] is not a valid WMBUS serial number";
    }

    if ($a[4] !~ m/[0-9]{1,2}/) {
      return "$a[4] is not a valid WMBUS version";
    }

    if ($a[5] !~ m/[0-9]{1,2}/) {
      return "$a[5] is not a valid WMBUS type";
    }
    
    if (defined($a[6])) {
      $encoding = $a[6];
    }
    if ($encoding ne "CUL" && $encoding ne "AMB") {
      return "$a[6] isn't a supported encoding, use either CUL or AMB";
    }
    

    $hash->{Manufacturer} = $a[2];
    $hash->{IdentNumber} = sprintf("%08d",$a[3]);
    $hash->{Version} = $a[4];
    $hash->{DeviceType} = $a[5];
    $hash->{MessageEncoding} = $encoding;
    
  }
  my $addr = join("_", $hash->{Manufacturer},$hash->{IdentNumber},$hash->{Version},$hash->{DeviceType}) ;
  
  return "WMBUS device $addr already used for $modules{WMBUS}{defptr}{$addr}->{NAME}." if( $modules{WMBUS}{defptr}{$addr}
                                                                                             && $modules{WMBUS}{defptr}{$addr}->{NAME} ne $name );
  $hash->{addr} = $addr;
  $modules{WMBUS}{defptr}{$addr} = $hash;

  AssignIoPort($hash);
  if(defined($hash->{IODev}->{NAME})) {
    Log3 $name, 3, "$name: I/O device is " . $hash->{IODev}->{NAME};
  } else {
    Log3 $name, 1, "$name: no I/O device";
  }

  $hash->{DEF} = join(" ", $hash->{Manufacturer},$hash->{IdentNumber},$hash->{Version},$hash->{DeviceType});
  
  $hash->{DeviceMedium} = WMBus::->type2string($hash->{DeviceType}); 
  if (defined($mb)) {
  
    if ($mb->parseApplicationLayer()) {
 
      WMBUS_SetReadings($hash, $name, $mb);
    } else {
      $hash->{Error} = $mb->{errormsg};
    }
  }
  return undef;
}

#####################################
sub
WMBUS_Undef($$)
{
  my ($hash, $arg) = @_;
  my $name = $hash->{NAME};
  my $addr = $hash->{addr};

  delete( $modules{WMBUS}{defptr}{$addr} );

  return undef;
}

#####################################
sub
WMBUS_Get($@)
{
  my ($hash, $name, $cmd, @args) = @_;

  return "\"get $name\" needs at least one parameter" if(@_ < 3);

  my $list = "";

  return "Unknown argument $cmd, choose one of $list";
}

sub
WMBUS_Fingerprint($$)
{
  my ($name, $msg) = @_;

  return ( "", $msg );
}


sub
WMBUS_Parse($$)
{
  my ($hash, $rawMsg) = @_;
  my $name = $hash->{NAME};
  my $addr;
  my $rhash;
  my $rssi;
  my $msg;
  
  # $hash is the hash of the IODev!
 
  if( $rawMsg =~ m/^b/ ) {
    # WMBus message received
    
    Log3 $name, 5, "WMBUS raw msg " . $rawMsg;
    
    $hash->{internal}{rawMsg} = $rawMsg;
    
    my $mb = new WMBus;
    
    ($msg, $rssi, $hash->{MessageEncoding}) = WMBUS_HandleEncoding($mb, $rawMsg);
    
    if (uc(substr($msg, 0, 8)) eq "1144FF03") {
      Log3 $name, 2, "received possible KNX-RF message, ignoring it";
      return undef;
    }
    
    if ($mb->parseLinkLayer(pack('H*',substr($msg,1)))) {
      $addr = join("_", $mb->{manufacturer}, $mb->{afield_id}, $mb->{afield_ver}, $mb->{afield_type});  

      $rhash = $modules{WMBUS}{defptr}{$addr};

      if( !$rhash ) {
          Log3 $name, 3, "WMBUS Unknown device $rawMsg, please define it";
      
          return "UNDEFINED WMBUS_$addr WMBUS $rawMsg";
      }
      
      my $rname = $rhash->{NAME};
      return "" if(IsIgnored($rname));
      
      $rhash->{model} =join("_", $mb->{manufacturer}, $mb->{afield_type}, $mb->{afield_ver});
      WMBUS_SetRSSI($rhash, $mb, $rssi);

      my $aeskey;

      if ($aeskey = AttrVal($rname, 'AESkey', undef)) {
        $mb->{aeskey} = pack("H*",$aeskey);
      } else {
        $mb->{aeskey} = undef; 
      }
      if ($mb->parseApplicationLayer()) {
        return WMBUS_SetReadings($rhash, $rname, $mb);
      } else {
        Log3 $rname, 2, "WMBUS $rname Error during ApplicationLayer parse:" . $mb->{errormsg};
        readingsSingleUpdate($rhash, "state",   $mb->{errormsg}, 1);
        return $rname;
      }
    } else {
      # error
      Log3 $name, 2, "WMBUS Error during LinkLayer parse:" . $mb->{errormsg};
      if ($mb->{errorcode} == WMBus::ERR_MSG_TOO_SHORT && $hash->{MessageEncoding} eq 'CUL') {
        Log3 $name, 2, "Please make sure that TTY_BUFSIZE in culfw is at least two times the message length + 1";
      }
      return undef;
    }
  } else {
    DoTrigger($name, "UNKNOWNCODE $rawMsg");
    Log3 $name, 3, "$name: Unknown code $rawMsg, help me!";
    return undef;
  }
}


# if the culfw doesn't send the RSSI value (because it is an old version that doesn't implement this) but 00_CUL.pm already expects it
# one byte is missing from the data which leads to CRC errors
# To avoid this calculate the raw data byte from the RSSI and append it to the data.
# If it is a valid RSSI it will be ignored by the WMBus parser (the data contains the length of the data itself
# and only that much is parsed).
sub WMBUS_RSSIAsRaw($) {
  my $rssi = shift;
  
  if (defined $rssi) {
    if ($rssi < -74) {
      $b = ($rssi+74)*2+256;
    } else {
      $b = ($rssi+74)*2;
    }
    return sprintf("%02X", $b);
  } else {
    return "";
  }
}

sub WMBUS_SetRSSI($$$) {
  my ($hash, $mb, $rssi) = @_;
  
  if (defined $mb->{remainingData} && length($mb->{remainingData}) >= 2) {
    # if there are trailing bytes after the WMBUS message it is the LQI and the RSSI
    readingsBeginUpdate($hash);
    my ($lqi, $rssi) = unpack("CC", $mb->{remainingData});
    $rssi = ($rssi>=128 ? (($rssi-256)/2-74) : ($rssi/2-74));

    readingsBulkUpdate($hash, "RSSI", $rssi);
    readingsBulkUpdate($hash, "LQI", unpack("C", $mb->{remainingData}));
    readingsEndUpdate($hash,1);
  }  
}

sub WMBUS_SetReadings($$$)
{
  my ($hash, $name, $mb) = @_;
  
  my @list;
  push(@list, $name);

  if ($mb->{cifield} == WMBus::CI_RESP_12) { 
    $hash->{Meter_Id} = $mb->{meter_id};
    $hash->{Meter_Manufacturer} = $mb->{meter_manufacturer};
    $hash->{Meter_Version} = $mb->{meter_vers};
    $hash->{Meter_Dev} = $mb->{meter_devtypestring};
    $hash->{Access_No} = $mb->{access_no};
    $hash->{Status} = $mb->{status};
  }  
  
  readingsBeginUpdate($hash);
  
  if ($mb->{decrypted} && 
     # decode messages sent from master to slave/meter only if it is explictly enabled 
      ( $mb->{sent_from_master} == 0 || AttrVal($name, "ignoreMasterMessages", 1) ) 
     )
  {
    my $dataBlocks = $mb->{datablocks};
    my $dataBlock;
    my $readingBase;
    my $useVIFasReadingName = defined($hash->{internal}{useVIFasReadingName}) ?
      $hash->{internal}{useVIFasReadingName} : AttrVal($name, "useVIFasReadingName", 0);
    
    for $dataBlock ( @$dataBlocks ) {
      next if AttrVal($name, "ignoreUnknownDataBlocks", 0) && $dataBlock->{type} eq 'MANUFACTURER SPECIFIC'; #WMBus::VIF_TYPE_MANUFACTURER_SPECIFIC
      if ($useVIFasReadingName) {
        $readingBase = "$dataBlock->{storageNo}_$dataBlock->{type}";
        if (defined($dataBlock->{extension_value})) {
            $readingBase .= "_$dataBlock->{extension_value}";
        }      
      } else {
        $readingBase = $dataBlock->{number};
        readingsBulkUpdate($hash, "${readingBase}_type", $dataBlock->{type}); 
        readingsBulkUpdate($hash, "${readingBase}_storage_no", $dataBlock->{storageNo});
        if (defined($dataBlock->{extension_value})) {
            readingsBulkUpdate($hash, "${readingBase}_extension_value", $dataBlock->{extension_value});
        }      
      }
      readingsBulkUpdate($hash, "${readingBase}_value", $dataBlock->{value}); 
      readingsBulkUpdate($hash, "${readingBase}_unit", $dataBlock->{unit});
      readingsBulkUpdate($hash, "${readingBase}_value_type", $dataBlock->{functionFieldText});
      if (defined($dataBlock->{extension_unit})) {
          readingsBulkUpdate($hash, "${readingBase}_extension_unit", $dataBlock->{extension_unit});
      }      
      if ($dataBlock->{errormsg}) {
        readingsBulkUpdate($hash, "${readingBase}_errormsg", $dataBlock->{errormsg});
      }
    }
    readingsBulkUpdate($hash, "batteryState", $mb->{status} & 4 ? "low" : "ok");

    WMBUS_SetDeviceSpecificReadings($hash, $name, $mb);
  }
  readingsBulkUpdate($hash, "is_encrypted", $mb->{isEncrypted});
  readingsBulkUpdate($hash, "decryption_ok", $mb->{decrypted});
  
  if ($mb->{decrypted}) {
    readingsBulkUpdate($hash, "state", $mb->{statusstring});
  } else {
    readingsBulkUpdate($hash, "state", 'decryption failed');
  }
  
  if (AttrVal($name, "rawmsg_as_reading", 0)) {
    readingsBulkUpdate($hash, "rawmsg", $mb->getFrameType() eq WMBus::FRAME_TYPE_B ? "Y" : "" . unpack("H*",$mb->{msg}));
  }
  
  readingsEndUpdate($hash,1);

  return @list;
  
}

sub WMBUS_SetDeviceSpecificReadings($$$)
{
  my ($hash, $name, $mb) = @_;
  
  if ($mb->{manufacturer} eq 'FFD') {
    # Fast Forward AG
    if ($mb->{afield_ver} == 1) {
      #EnergyCam
      if ($mb->{afield_type} == 2) {
        # electricity
        readingsBulkUpdate($hash, "energy", ReadingsVal($name, "1_value", 0) / 1000);
        readingsBulkUpdate($hash, "unit", "kWh");
      } elsif ($mb->{afield_type} == 3 || $mb->{afield_type} == 7) {
        # gas/water
        readingsBulkUpdate($hash, "volume", ReadingsVal($name, "1_value", 0));
        readingsBulkUpdate($hash, "unit", "m³");
      }
    }
  } elsif ($mb->{afield_type} == 3 || $mb->{afield_type} == 7) {
    # general gas/water meter
    my $dataBlock;
    my $dataBlocks = $mb->{datablocks};
    
    for $dataBlock ( @$dataBlocks ) {
      # search for VIF_VOLUME
      if ($dataBlock->{type} eq 'VIF_VOLUME' && $dataBlock->{functionFieldText} eq "Instantaneous value") {
        readingsBulkUpdate($hash, "volume", $dataBlock->{value});
        readingsBulkUpdate($hash, "unit", $dataBlock->{unit});
      }
    }
  }
}

#####################################
sub
WMBUS_Set($@)
{
  my ($hash, @a) = @_;

  my $name = shift @a;
  my $cmd = shift @a;
  my $arg = join(" ", @a);
  my $list = "rawmsg";

  # only for Letrika solar inverters
  $list .= " requestCurrentPower requestTotalEnergy" if $hash->{Manufacturer} eq 'LET' and $hash->{DeviceType} == 2; 
  return $list if( $cmd eq '?' || $cmd eq '');


  if ($cmd eq 'rawmsg') {
    WMBUS_Parse($hash, 'b'.$arg);
  } elsif ($cmd eq "requestCurrentPower") {
    IOWrite($hash, "", "bss");
  } elsif ($cmd eq "requestTotalEnergy") {
  }
  else {
    return "Unknown argument $cmd, choose one of ".$list;
  }

  return undef;
}

sub
WMBUS_Attr(@)
{
  my ($cmd, $name, $attrName, $attrVal) = @_;
  my $hash = $defs{$name};
  my $msg = '';

  if ($attrName eq 'AESkey') {
      if ($attrVal =~ /^[0-9A-Fa-f]{32}$/) {
        $hash->{wmbus}->{aeskey} = $attrVal;
      } else {
        $msg = "AESkey must be a 32 digit hexadecimal value";
      }
  } elsif ($attrName eq 'useVIFasReadingName') {
    if ($attrVal ne AttrVal($name, 'useVIFasReadingName', '0')) {
      # delete all readings on change of namimg format
      fhem "deletereading $name .*";
      # and recreate them
      if (defined($hash->{internal}{rawMsg})) {
        $hash->{internal}{useVIFasReadingName} = $attrVal;
        WMBUS_Parse($hash, $hash->{internal}{rawMsg});
        delete $hash->{internal}{useVIFasReadingName};
      }
    }
  }
  return ($msg) ? $msg : undef;
}

1;

=pod
=item device
=item summary Reception of Wireless M-Bus messages from e.g. electicity meters
=item summary_DE Empfang von Wireless M-Bus Nachrichten z. B. von Stromzählern
=begin html

<a name="WMBUS"></a>
<h3>WMBUS - Wireless M-Bus</h3>
<ul>
  This module supports Wireless M-Bus meters for e.g. water, heat, gas or electricity.
  Wireless M-Bus is a standard protocol supported by various manufacturers.
  
  It uses the 868 MHz band for radio transmissions.
  Therefore you need a device which can receive Wireless M-Bus messages, e.g. a <a href="#CUL">CUL</a> with culfw >= 1.59 or an AMBER Wireless AMB8465M.
  <br>
  WMBus uses three different radio protocols, T-Mode, S-Mode and C-Mode. The receiver must be configured to use the same protocol as the sender.
  In case of a CUL this can be done by setting <a href="#rfmode">rfmode</a> to WMBus_T, WMBus_S or WMBus_C respectively.
  <br>
  WMBus devices send data periodically depending on their configuration. It can take days between individual messages or they might be sent
  every minute.
  <br>
  WMBus messages can be optionally encrypted. In that case the matching AESkey must be specified with attr AESkey. Otherwise the decryption
  will fail and no relevant data will be available. The module can decrypt messages encrypted according to security profile A or B (mode 5 and 7).
  <br><br>
  <b>Prerequisites</b><br>
  This module requires the perl modules Digest::CRC, Crypt::Mode::CBC, Crypt::Mode::CTR and Digest::CMAC (last three only if encrypted messages should be processed).<br>
  On a debian based system these can be installed with<br>
  <code>
  sudo apt-get install libdigest-crc-perl<br>
  sudo cpan -i Crypt::Mode::CBC Crypt::Mode:CTR Digest::CMAC
  </code>
  <br><br>
  <a name="WMBUSdefine"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; WMBUS [&lt;manufacturer id&gt; &lt;identification number&gt; &lt;version&gt; &lt;type&gt; [&lt;MessageEncoding&gt;]]|&lt;b[&lt;MessageEncoding&gt;]HexCode&gt;</code> <br>
    <br>
    Normally a WMBus device isn't defined manually but automatically through the <a href="#autocreate">autocreate</a> mechanism upon the first reception of a message.
    <br>
    For a manual definition there are two ways.
    <ul>
      <li>
      By specifying a raw WMBus message as received by an IODev. Such a message starts with a lower case 'b' and contains at least 24 hexadecimal digits.
      The WMBUS module extracts all relevant information from such a message.
      </li>
      <li>
      Explictly specify the information that uniquely identifies a WMBus device. <br>
      The manufacturer code, which is is a three letter shortcut of the manufacturer name. See 
      <a href="https://www.dlms.com/flag-id/flag-id-list">dlms.com</a> for a list of registered ids.<br>
      The identification number is the serial no of the meter.<br>
      version is the version code of the meter<br>
      type is the type of the meter, e.g. water or electricity encoded as a number.<br>
      MessageEncoding is either CUL or AMB, depending on which kind of IODev is used. The default encoding is CUL.
      </li>
      <br>
    </ul>
  </ul>
  <br>

  <a name="WMBUSset"></a>
  <b>Set</b> 
  <ul>
  <li>
  rawmsg hexadecimal contents of a raw message (without the leading b)<br>
  Will be parsed as if the message has been received by the IODev. Mainly useful for debugging.
  </li>
  </ul><br>
  <a name="WMBUSget"></a>
  <b>Get</b> <ul>N/A</ul><br>
  
  <a name="WMBUSattr"></a>
  <b>Attributes</b>
  <ul>
    <a name="IODev"></a>
    <li><a href="#IODev">IODev</a><br>
        Set the IO or physical device which should be used for receiving signals
        for this "logical" device. An example for the physical device is a CUL.
   </li><br>
   <a name="AESkey"></a>
   <li>AESkey<br>
      A 16 byte AES-Key in hexadecimal digits. Used to decrypt messages from meters which have encryption enabled.
  </li><br>
  <li>
    <a name="ignore"></a>  
    <a href="#ignore">ignore</a>
  </li><br>
  <a name="rawmsg_as_reading"></a>  
  <li>rawmsg_as_reading<br>
     If set to 1, received raw messages will be stored in the reading rawmsg. This can be used to log raw messages to help with debugging.
  </li><br>
  <a name="ignoreUnknownDataBlocks"></a>
  <li>ignoreUnknownDataBlocks<br>
     If set to 1, datablocks containing unknown/manufacturer specific data will be ignored. This is useful if a meter sends data in different
     formats of which some can be interpreted and some not. This prevents the unknown data overwriting the readings of the data that can be
     interpreted.
  </li><br>
  <a name="ignoreMasterMessages"></a>
  <li>ignoreMasterMessages<br>
     Some devices (e.g. Letrika solar inverters) only send data if they have received a special message from a master device.
     The messages sent by the master are ignored unless explictly enabled by this attribute.
  </li><br>
  <a name="useVIFasReadingName"></a>
  <li>useVIFasReadingName<br>
     Some devices send several types of messages with different logical content. As the readings are normally numbered consecutively they will be overwitten
     by blocks with a different semantic meaning.
     If ths attribute is set to 1 the naming of the readings will be changed to start with storage number and VIF (Value Information Field) name.
     Therefor each semantically different value will get a unique reading name.<br>
     Example:<br>
     <pre>
     1_storage_no 0
     1_type VIF_ENERGY_WATT
     1_unit Wh
     1_value 1234.5
     </pre>
     will be changed to<br>
     <pre>
     0_VIF_ENERGY_WATT_unit Wh
     0_VIF_ENERGY_WATT_value 1234.5
     </pre>
  </li>
  </ul>
  <br>
  <a name="WMBUSreadings"></a>
  <b>Readings</b><br>
  <ul>
  Meters can send a lot of different information depending on their type. An electricity meter will send other data than a water meter.
  The information also depends on the manufacturer of the meter. See the WMBus specification on <a href="http://www.oms-group.org">oms-group.org</a> for details.
  <br><br>
  The readings are generated in blocks starting with block 1. A meter can send several data blocks.
  Each block has at least a type, a value and a unit, e.g. for an electricity meter it might look like<br>
  <ul>
  <code>1_type VIF_ENERGY_WATT</code><br>
  <code>1_unit Wh</code><br>
  <code>1_value 2948787</code><br>
  </ul>
  <br>
  There is also a fixed set of readings.
  <ul>
  <li><code>is_encrypted</code> is 1 if the received message is encrypted.</li>
  <li><code>decryption_ok</code> is 1 if a message has either been successfully decrypted or if it is unencrypted.</li>
  <li><code>state</code> contains the state of the meter and may contain error message like battery low. Normally it contains 'no error'.</li>
  <li><code>batteryState</code> contains ok or low.</li>
  </ul>
  For some well known devices specific readings like the energy consumption in kWh created.
  </ul>
  
  
</ul>

=end html

=begin html_DE

<a name="WMBUS"></a>
<h3>WMBUS - Wireless M-Bus</h3>
<ul>
  Dieses Modul unterst&uuml;tzt Z&auml;hler mit Wireless M-Bus, z. B. f&uuml;r Wasser, Gas oder Elektrizit&auml;t.
  Wireless M-Bus ist ein standardisiertes Protokoll das von unterschiedlichen Herstellern unterst&uuml;tzt wird.

  Es verwendet das 868 MHz Band f&uuml;r Radio&uuml;bertragungen.
  Daher wird ein Ger&auml;t ben&ouml;tigt das die Wireless M-Bus Nachrichten empfangen kann, z. B. ein <a href="#CUL">CUL</a> mit culfw >= 1.59 oder ein AMBER Wireless AMB8465-M.
  <br>
  WMBus verwendet drei unterschiedliche Radioprotokolle, T-Mode, S-Mode und C-Mode. Der Empf&auml;nger muss daher so konfiguriert werden, dass er das selbe Protokoll
  verwendet wie der Sender. Im Falle eines CUL kann das erreicht werden, in dem das Attribut <a href="#rfmode">rfmode</a> auf WMBus_T, WMBus_S bzw. WMBus_C gesetzt wird.
  <br>
  WMBus Ger&auml;te senden Daten periodisch abh&auml;ngig von ihrer Konfiguration. Es k&ouml;nnen u. U. Tage zwischen einzelnen Nachrichten vergehen oder sie k&ouml;nnen im 
  Minutentakt gesendet werden.
  <br>
  WMBus Nachrichten k&ouml;nnen optional verschl&uuml;sselt werden. Bei verschl&uuml;sselten Nachrichten muss der passende Schl&uuml;ssel mit dem Attribut AESkey angegeben werden. 
  Andernfalls wird die Entschl&uuml;sselung fehlschlagen und es k&ouml;nnen keine relevanten Daten ausgelesen werden. Das Modul kann mit Security Profile A oder B (Mode 5 und 7) verschl&uuml;sselte Nachrichten entschl&uuml;sseln.
  <br><br>
  <b>Voraussetzungen</b><br>
  Dieses Modul ben&ouml;tigt die perl Module Digest::CRC, Crypt::Mode::CBC, Crypt::Mode::CTR und Digest::CMAC (die letzten drei Module werden nur ben&ouml;tigt wenn verschl&uuml;sselte Nachrichten verarbeitet werden sollen).<br>
  Bei einem Debian basierten System k&ouml;nnen diese so installiert werden<br>
  <code>
  sudo apt-get install libdigest-crc-perl<br>
  sudo cpan -i Crypt::Mode::CBC Crypt::Mode::CTR Digest::CMAC
  </code>
  <br><br>
  <a name="WMBUSdefine"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; WMBUS [&lt;manufacturer id&gt; &lt;identification number&gt; &lt;version&gt; &lt;type&gt; [&lt;MessageEncoding&gt;]]|&lt;b[<MessageEncoding>]HexCode&gt;</code> <br>
    <br>
    Normalerweise wird ein WMBus Device nicht manuell angelegt. Dies geschieht automatisch bem Empfang der ersten Nachrichten eines Ger&auml;tes &uuml;ber den 
    fhem <a href="#autocreate">autocreate</a> Mechanismus.
    <br>
    F&uuml;r eine manuelle Definition gibt es zwei Wege.
    <ul>
      <li>
      Durch Verwendung einer WMBus Rohnachricht wie sie vom IODev empfangen wurde. So eine Nachricht beginnt mit einem kleinen 'b' und enth&auml;lt mindestens
      24 hexadezimale Zeichen.
      Das WMBUS Modul extrahiert daraus alle ben&ouml;tigten Informationen.
      </li>
      <li>
      Durch explizite Angabe der Informationen die ein WMBus Ger&auml;t eindeutig identfizieren.<br>
      Der Hersteller Code, besteht aus drei Buchstaben als Abk&uuml;rzung des Herstellernamens. Eine Liste der Abk&uuml;rzungen findet sich unter
      <a href="https://www.dlms.com/flag-id/flag-id-list">dlms.com</a><br>
      Die Idenitfikationsnummer ist die Seriennummer des Z&auml;hlers.<br>
      Version ist ein Versionscode des Z&auml;hlers.<br>
      Typ ist die Art des Z&auml;hlers, z. B. Wasser oder Elektrizit&auml;t, kodiert als Zahl.<br>
      MessageEncoding ist entweder CUL oder AMB, je nachdem welche Art von IODev verwendet wird. Wird kein Encoding angegeben so wird CUL verwendet.
      </li>
      <br>
    </ul>
  </ul>
  <br>

  <a name="WMBUSset"></a>
  <b>Set</b> 
  <ul>
  <li>
  rawmsg Hexadezimaler Inhalt einer Rohnachricht (ohne f&uuml;hrendes b)<br>
  Wird interpretiert als ob die Nachricht von einem IODev empfangen worden w&auml;re. Haupts&auml;chlich n&uuml;tzlich zum debuggen.
  </li>
  </ul><br>
  <a name="WMBUSget"></a>
  <b>Get</b> <ul>N/A</ul><br>
  
  <a name="WMBUSattr"></a>
  <b>Attributes</b>
  <ul>
   <a name="IODev"></a>
    <li><a href="#IODev">IODev</a><br>
        Setzt den IO oder physisches Ger&auml;t welches f&uuml;r den Empfang der Signale f&uuml;r dieses 'logische' Ger&auml;t verwendet werden soll.
        Ein Beispiel f&uuml;r ein solches Ger&auml;t ist ein CUL.
   </li><br>
   <a name="AESkey"></a>
   <li>AESKey<br>
      Ein 16 Bytes langer AES-Schl&uuml;ssel in hexadezimaler Schreibweise. Wird verwendet um Nachrichten von Z&auml;hlern zu entschl&uuml;sseln bei denen
      die Verschl&uuml;sselung aktiviert ist.
  </li><br>
  <li>
    <a name="ignore"></a>
    <a href="#ignore">ignore</a>
  </li><br>
  <li>rawmsg_as_reading<br>
     Wenn auf 1 gesetzt so werden empfangene Nachrichten im Reading rawmsg gespeichert. Das kann verwendet werden um Rohnachrichten zu loggen und beim Debugging zu helfen.
  </li><br>
  <a name="rawmsg_as_reading"></a> 
  <li>ignoreUnknownDataBlocks<br>
     Wenn auf 1 gesetzt so werden Datenblocks die unbekannte/herstellerspezifische Daten enthalten ignoriert. Das ist hilfreich wenn ein Z&auml;hler Daten in unterschiedlichen
     Formaten sendet von denen einige nicht interpretiert werden k&ouml;nnen. Es verhindert, dass die unbekannten Daten die Readings der interpretierbaren Daten &uuml;berschreiben.
  </li><br> 
  <a name="ignoreUnknownDataBlocks"></a>
  <li>ignoreMasterMessages
     Einige Geräte (z. B. Letrika Wechselrichter) senden nur dann Daten wenn sie eine spezielle Nachricht von einem Mastergerät erhalten haben.
     Die Nachrichten von dem Master werden ignoriert es sei denn es wird explizit mit diesem Attribut eingeschaltet.
  </li>
  <a name="useVIFasReadingName"></a>
  <li>useVIFasReadingName<br>
     Einige Ger&auml;te senden verschiedene Arten von Nachrichten mit logisch unterschiedlichem Inhalt. Da die Readings normalerweise aufsteigend nummeriert werden
     k&ouml;nnen Readings durch semantisch unterschiedliche Readings &uuml;berschrieben werden.
     Wenn dieses Attribut auf 1 gesetzt ist &auml;ndert sich die Namenskonvention der Readings. Die Namen setzen sich dann aus der Storagenumber und dem 
     VIF (Value Information Field) zusammen. Dadurch bekommt jeder semantisch unterschiedliche Wert einen eindeutigen Readingnamen. 
     Beispiel:<br>
     <pre>
     1_storage_no 0
     1_type VIF_ENERGY_WATT
     1_unit Wh
     1_value 1234.5
     </pre>
     wird zu<br>
     <pre>
     0_VIF_ENERGY_WATT_unit Wh
     0_VIF_ENERGY_WATT_value 1234.5
     </pre>
  </li>
  </ul>
  <br>
  <a name="WMBUSreadings"></a>
  <b>Readings</b><br>
  <ul>
  Z&auml;hler k&ouml;nnen sehr viele unterschiedliche Informationen senden, abh&auml;ngig von ihrem Typ. Ein Elektrizit&auml;tsz&auml;hler wird andere Daten senden als ein
  Wasserz&auml;hler. Die Information h&auml;ngt auch vom Hersteller des Z&auml;hlers ab. F&uuml;r weitere Informationen siehe die WMBus Spezifikation unter
  <a href="http://www.oms-group.org">oms-group.org</a>.
  <br><br>
  Die Readings werden als Block dargestellt, beginnend mit Block 1. Ein Z&auml;hler kann mehrere Bl&ouml;cke senden.
  Jeder Block enth&auml;lt zumindest einen Typ, einen Wert und eine Einheit. F&uuml;r einen Elektrizit&auml;tsz&auml;hler k&ouml;nnte das z. B. so aussehen<br>
  <ul>
  <code>1_type VIF_ENERGY_WATT</code><br>
  <code>1_unit Wh</code><br>
  <code>1_value 2948787</code><br>
  </ul>
  <br>
  Es gibt auch eine Anzahl von festen Readings.
  <ul>
  <li><code>is_encrypted</code> ist 1 wenn die empfangene Nachricht verschl&uuml;sselt ist.</li>
  <li><code>decryption_ok</code> ist 1 wenn die Nachricht entweder erfolgreich entschl&uuml;sselt wurde oder gar nicht verschl&uuml;sselt war.</li>
  <li><code>state</code> enth&auml;lt den Status des Z&auml;hlers und kann Fehlermeldungen wie 'battery low' enthalten. Normalerweise ist der Wert 'no error'.</li>
  <li><code>batteryState</code> enth&auml;lt ok oder low.</li>
  </ul>
  Für einige bekannte Gerätetypen werden zusätzliche Readings wie der Energieverbrauch in kWh erzeugt. 
  </ul>
  
  
</ul>
=end html_DE

=cut
