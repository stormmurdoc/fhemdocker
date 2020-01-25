
# $Id: 36_EC3000.pm 12057 2016-08-22 19:31:37Z justme1968 $
#
# TODO:

package main;

use strict;
use warnings;
use SetExtensions;

sub EC3000_Parse($$);

sub
EC3000_Initialize($)
{
  my ($hash) = @_;

  $hash->{Match}     = "^\\S+\\s+22";
  #$hash->{SetFn}     = "EC3000_Set";
  #$hash->{GetFn}     = "EC3000_Get";
  $hash->{DefFn}     = "EC3000_Define";
  $hash->{UndefFn}   = "EC3000_Undef";
  $hash->{FingerprintFn}   = "EC3000_Fingerprint";
  $hash->{ParseFn}   = "EC3000_Parse";
  $hash->{AttrFn}    = "EC3000_Attr";
  $hash->{AttrList}  = "IODev".
                       " offLevel".
                       " $readingFnAttributes";
}

sub
EC3000_Define($$)
{
  my ($hash, $def) = @_;
  my @a = split("[ \t][ \t]*", $def);

  if(@a != 3 ) {
    my $msg = "wrong syntax: define <name> EC3000 <addr>";
    Log3 undef, 2, $msg;
    return $msg;
  }

  $a[2] =~ m/^([\da-f]{4})$/i;
  return "$a[2] is not a valid EC3000 address" if( !defined($1) );

  my $name = $a[0];
  my $addr = $a[2];

  #return "$addr is not a 1 byte hex value" if( $addr !~ /^[\da-f]{2}$/i );
  #return "$addr is not an allowed address" if( $addr eq "00" );

  return "EC3000 device $addr already used for $modules{EC3000}{defptr}{$addr}->{NAME}." if( $modules{EC3000}{defptr}{$addr}
                                                                                             && $modules{EC3000}{defptr}{$addr}->{NAME} ne $name );

  $hash->{addr} = $addr;

  $modules{EC3000}{defptr}{$addr} = $hash;

  AssignIoPort($hash);
  if(defined($hash->{IODev}->{NAME})) {
    Log3 $name, 3, "$name: I/O device is " . $hash->{IODev}->{NAME};
  } else {
    Log3 $name, 1, "$name: no I/O device";
  }

  $attr{$name}{stateFormat} = 'state (power W)' if( !defined( $attr{$name}{stateFormat} ) );

  return undef;
}

#####################################
sub
EC3000_Undef($$)
{
  my ($hash, $arg) = @_;
  my $name = $hash->{NAME};
  my $addr = $hash->{addr};

  delete( $modules{EC3000}{defptr}{$addr} );

  return undef;
}

#####################################
sub
EC3000_Get($@)
{
  my ($hash, $name, $cmd, @args) = @_;

  return "\"get $name\" needs at least one parameter" if(@_ < 3);

  my $list = "";

  return "Unknown argument $cmd, choose one of $list";
}

sub
EC3000_Fingerprint($$)
{
  my ($name, $msg) = @_;

  return ( "", $msg );
}


sub
EC3000_Parse($$)
{
  my ($hash, $msg) = @_;
  my $name = $hash->{NAME};

  #return undef if( $msg !~ m/^[\dA-F]{12,}$/ );

  my( @bytes, $addr,$secondsTotal,$secondsOn,$consumptionTotal,$power,$powerMax,$resets,$reception );
  if( $msg =~ m/^OK/ ) {
    @bytes = split( ' ', substr($msg, 6) );

    $addr = sprintf( "%02X%02X", $bytes[0], $bytes[1] );
    $secondsTotal = ($bytes[2]<<24) + ($bytes[3]<<16) + ($bytes[4]<<8) + $bytes[5];
    $secondsOn = ($bytes[6]<<24) + ($bytes[7]<<16) + ($bytes[8]<<8) + $bytes[9];
    $consumptionTotal = ( ($bytes[10]<<24) + ($bytes[11]<<16) + ($bytes[12]<<8) + $bytes[13] )/1000.0;
    $power = ( ($bytes[14]<<8) + $bytes[15] )/10.0;
    $powerMax = ( ($bytes[16]<<8) + $bytes[17] )/10.0;
    $resets = $bytes[18];
    $reception = $bytes[19];
  } else {
    DoTrigger($name, "UNKNOWNCODE $msg");
    Log3 $name, 3, "$name: Unknown code $msg, help me!";
    return undef;
  }

  my $raddr = $addr;
  my $rhash = $modules{EC3000}{defptr}{$raddr};
  my $rname = $rhash?$rhash->{NAME}:$raddr;

   if( !$modules{EC3000}{defptr}{$raddr} ) {
     Log3 $name, 3, "EC3000 Unknown device $rname, please define it";
     #return undef if( $raddr eq "00" );

     return "UNDEFINED EC3000_$rname EC3000 $raddr";
   }

  #CommandAttr( undef, "$rname userReadings consumptionTotal:consumption monotonic {ReadingsVal($rname,'consumption',0)}" ) if( !defined( $attr{$rname}{userReadings} ) );

  my @list;
  push(@list, $rname);

  $rhash->{EC3000_lastRcv} = TimeNow();
  $rhash->{resets} = $resets;
  $rhash->{reception} = $reception;
  $rhash->{secondsOn} = $secondsOn;
  $rhash->{secondsTotal} = $secondsTotal;

  readingsBeginUpdate($rhash);
  #readingsBulkUpdate($rhash, "secondsTotal", $secondsTotal);
  #readingsBulkUpdate($rhash, "secondsOn", $secondsOn);
  readingsBulkUpdate($rhash, "consumption", $consumptionTotal);
  readingsBulkUpdate($rhash, "power", $power);
  readingsBulkUpdate($rhash, "powerMax", $powerMax);

  my $state = "on";
  $state = "off" if( $power <= AttrVal($rname, "offLevel", 0) );
  readingsBulkUpdate($rhash, "state", $state);

  readingsEndUpdate($rhash,1);

  return @list;
}

sub
EC3000_Attr(@)
{
  my ($cmd, $name, $attrName, $attrVal) = @_;

  return undef;
}

1;

=pod
=item summary    Energy Count 3000 (EC3000) devices
=item summary_DE Energy Count 3000 (EC3000) Ger&auml;te
=begin html

<a name="EC3000"></a>
<h3>EC3000</h3>
<ul>
  The Energy Count 3000 is a AC mains plug with integrated power meter functionality from CONRAD.<br><br>

  It can be integrated in to FHEM via a <a href="#JeeLink">JeeLink</a> as the IODevice.<br><br>

  <a name="EC3000Define"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; EC3000 &lt;addr&gt;</code> <br>
    <br>
    addr is a 4 digit hex number to identify the EC3000 device.
    Note: devices are autocreated on reception of the first message.<br>
  </ul>
  <br>

  <a name="EC3000_Set"></a>
  <b>Set</b>
  <ul>
  </ul><br>

  <a name="EC3000_Get"></a>
  <b>Get</b>
  <ul>
  </ul><br>

  <a name="EC3000_Readings"></a>
  <b>Readings</b>
  <ul>
    <li>consumption</li>
    <li>consumptionMax</li>
    <li>consumptionNow</li>
  </ul><br>

  <a name="EC3000_Attr"></a>
  <b>Attributes</b>
  <ul>
    <li>offLevel<br>
      a power level less or equal <code>offLevel</code> is considered to be off</li>
  </ul><br>
</ul>

=end html
=cut
