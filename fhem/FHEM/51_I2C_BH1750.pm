# $Id: 51_I2C_BH1750.pm 12274 2016-10-05 09:45:28Z arnoaugustin $
##############################################################################
#
#     51_I2C_BH1750.pm
#
#     This file is part of FHEM.
#
#     Fhem is free software: you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation, either version 2 of the License, or
#     (at your option) any later version.
#
#     BDKM is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
#
#     You should have received a copy of the GNU General Public License
#     along with FHEM.  If not, see <http://www.gnu.org/licenses/>.
#
#     Written by Arno Augustin
##############################################################################


package main;

use strict;
use warnings;

use Time::HiRes qw(tv_interval);

# BH1750 chip constants
use constant 
{
    # I2C addresses
    BH1750_ADDR_DEFAULT          => 0x23,
    BH1750_ADDR_OTHER            => 0x5C,

    # I2C registers
    BH1750_RAW_VALUE             => 0x00,
    BH1750_POWER_DOWN            => 0x00,
    BH1750_POWER_ON              => 0x01,
    BH1750_RESET                 => 0x07,
    BH1750_H_MODE                => 0x10,
    BH1750_H_MODE2               => 0x11,
    BH1750_L_MODE                => 0x13,
    BH1750_H_MODE_ONCE           => 0x20,
    BH1750_H_MODE2_ONCE          => 0x21,
    BH1750_L_MODE_ONCE           => 0x23,

    BH1750_MT_MIN                => 31,
    BH1750_MT_DEFAULT            => 69,
    BH1750_MT_MAX                => 254,
};

#state
use constant
{
    BH1750_STATE_DEFINED     => 'Defined',
    BH1750_STATE_I2C_ERROR   => 'I2C Error',
    BH1750_STATE_SATURATED   => 'Saturated',
    BH1750_STATE_OK          => 'Ok'
};

# PollState
use constant
{
    BH1750_POLLSTATE_IDLE            => 0,
    BH1750_POLLSTATE_START_MEASURE   => 1,
    BH1750_POLLSTATE_PRE_LUX_WAIT    => 2,
    BH1750_POLLSTATE_PRE_LUX_DONE    => 3,
    BH1750_POLLSTATE_LUX_WAIT        => 4,
    BH1750_POLLSTATE_LUX_DONE        => 5
};

# chip parameter selection for different LUX values
# BH1750 has the following limitations:
# MODE_L,  MT= 31, LUX 0-121556, res. >8 LUX
# MODE_L,  MT= 69, LUX 0- 54612, res. >4 LUX
# MODE2_H, MT= 31, LUX 0- 60778, res. >1 LUX
# MODE2_H, MT= 69, LUX 0- 27306, res. >0.5 LUX
# MODE2_H, MT=254, LUX 0- 7417,  res. >0.11 LUX

my @I2C_BH1750_ranges=(
    # RAWVAL MT   MODE
    [  3000, 254, BH1750_H_MODE2_ONCE],
    [  6000, 127, BH1750_H_MODE2_ONCE],
    [ 12000,  69, BH1750_H_MODE2_ONCE],
    [ 26000,  31, BH1750_H_MODE2_ONCE]
    # else use 31, BH1750_L_MODE_ONCE
);

sub I2C_BH1750_Initialize($);
sub I2C_BH1750_Define($$);
sub I2C_BH1750_Attr(@);
sub I2C_BH1750_Poll($);
sub I2C_BH1750_Restart_Measure($$);
sub I2C_BH1750_Set($@);
sub I2C_BH1750_Get($);
sub I2C_BH1750_Undef($$);

sub I2C_BH1750_Initialize($) 
{
    my ($hash) = @_;
    
    $hash->{STATE}    = "Init";
    $hash->{DefFn}    = "I2C_BH1750_Define";
    $hash->{UndefFn}  = "I2C_BH1750_Undef";
    $hash->{InitFn}   = "I2C_BH1750_IoInit";
    $hash->{AttrFn}   = "I2C_BH1750_Attr";
    $hash->{SetFn}    = "I2C_BH1750_Set";
    $hash->{I2CRecFn} = 'I2C_BH1750_I2CRec';
    $hash->{AttrList} = "poll_interval:0.1,0.2,0.5,1,2,5,10,20,30,60 IODev percentdelta correction ". 
        $readingFnAttributes;
    $hash->{VERSION}  = '$Id: 51_I2C_BH1750.pm 12274 2016-10-05 09:45:28Z arnoaugustin $';
}

sub I2C_BH1750_Define($$) 
{
    my ($hash, $def) = @_;
    my @a            = split(/\s+/, $def);
    my $name         = shift(@a);
    my $device=0;

    my $usage=sprintf "usage: \"define <devicename> I2C_BH1750 [devicename] [0x%x|0x%x]\"\n", 
    BH1750_ADDR_DEFAULT,BH1750_ADDR_OTHER;
    
    $hash->{I2C_Address}=BH1750_ADDR_DEFAULT; # default

    Log3 ($hash, 3, $hash->{NAME} . ': ' . "define $def");
    shift(@a);
    @a > 1 and return $usage;
    if(defined ($_=$a[0])) {
        /0x(5c|23)/i or return $usage;
        $hash->{I2C_Address}=hex($_);
    }
    
    $hash->{BASEINTERVAL} = 0;
    $hash->{RESTARTDELAY} = 10;
    $hash->{DELTA}        = 0;   
    $hash->{PollState}    = BH1750_POLLSTATE_IDLE; 
    $hash->{CORRECTION}   = 1; 
    
    readingsSingleUpdate($hash, 'state', BH1750_STATE_DEFINED, 1);

    my $ret = undef;
    if ($main::init_done) {
        eval {I2C_BH1750_IoInit($hash, \@a);};
        if($@) {
            $ret = I2C_BH1750_Catch($@);
            Log3 ($hash, 1, $hash->{NAME} . ': ' . $ret);
        }
    }

    return $ret;
}

sub I2C_BH1750_IoInit($$) 
{
    my ($hash, $args) = @_;
    my $name = $hash->{NAME};
    
    eval { AssignIoPort($hash, AttrVal($hash->{NAME},"IODev",undef)); };
    $@ and return I2C_BH1750_Catch($@);

    return undef;
}

sub I2C_BH1750_Catch($) 
{
    my $exception = shift;
    if ($exception) {
        $exception =~ /^(.*)( at.*FHEM.*)$/;
        return $1;
    }
    return undef;
}



sub I2C_BH1750_Attr (@) 
{
    my ($cmd,$name,$attr,$val)  = @_;
    my $hash                    = $defs{$name};
    my $error                   = "$name: ERROR attribute $attr ";
    my $del                     = $cmd =~ /del/;
    local $_;

    Log3 $name, 3, "$name I2C_BH1750_Attr $cmd,$name,$attr,$val";

    if ($attr eq "correction") {
        if($del) {
            $val = 1; # default
        } else {
            $val =~ /^(12|[012]+\.[0-9]+)$/ and $val >= 0.5 
                and $val <=2 or return $error."needs numeric value between 0.5 and 2";
        }
        $hash->{CORRECTION} = $val;
    } elsif ($attr eq "percentdelta") {
        if($del) {
            $val = 0; # default
        } else {
            $val =~ /^([0-9]+|[0-9]+\.?[0.9]+)$/ or return $error."needs numeric value";
        }
        $hash->{DELTA} = $val/100;
    } elsif ($attr eq "poll_interval") {
        RemoveInternalTimer($hash);
        if($del) {
            $hash->{BASEINTERVAL} = 0;   
            $hash->{PollState}    = BH1750_POLLSTATE_IDLE; 
        } else {
            if($val !~ /^\d+/) {
                return $error."needs numeric value";
            } else {
                $hash->{BASEINTERVAL} = 60*$val;   
                I2C_BH1750_Restart_Measure($hash,$hash->{RESTARTDELAY});
            } 
        }
    } elsif ($attr eq "IODev") {
        eval {
            if ($main::init_done and (!defined ($hash->{IODev}) or $hash->{IODev}->{NAME} ne $val)) {
     		my @def = split (' ',$hash->{DEF});
                return I2C_BH1750_IoInit($hash,\@def);
            };
        };
    }


    return undef;
}

sub I2C_BH1750_Restart_Measure($$)
{
    my ($hash,$delay) =  @_;
    my $name = $hash->{NAME};
    RemoveInternalTimer($hash);
    $hash->{PollState} = BH1750_POLLSTATE_IDLE;
    I2C_BH1750_i2cwrite($hash, BH1750_POWER_DOWN);
    $delay and InternalTimer(gettimeofday() + $delay, 'I2C_BH1750_Poll', $hash, 0);
}


sub I2C_BH1750_Poll($)
{
    my ($hash) =  @_;
    my $name = $hash->{NAME};

    Log3 $name, 4, "$name I2C_BH1750_Poll ".gettimeofday()." PollState=$hash->{PollState}";
    RemoveInternalTimer($hash);
    my $delay=$hash->{BASEINTERVAL};
    $hash->{PollState} == BH1750_POLLSTATE_IDLE and $hash->{PollState}++;
    my $state = $hash->{PollState};
    if ($state == BH1750_POLLSTATE_START_MEASURE) {
        I2C_BH1750_i2cwrite($hash, BH1750_POWER_ON);
        # check in lowest resolution first
        $delay = I2C_BH1750_start_measure($hash,BH1750_MT_MIN,BH1750_L_MODE_ONCE);
        $hash->{PollState} = BH1750_POLLSTATE_PRE_LUX_WAIT;
    } elsif($state == BH1750_POLLSTATE_PRE_LUX_WAIT) {
        I2C_BH1750_request_measure($hash);
    } elsif($state == BH1750_POLLSTATE_PRE_LUX_DONE) {
        my $raw=$hash->{RAWVAL};
        if($hash->{RAWVAL} == 0xFFFF) {
            $hash->{SATURATED} = 1;
        } else {
            $hash->{SATURATED} = 0;
        }
            
        my $i;
        for($i=0; $i<@I2C_BH1750_ranges; $i++) {
            $raw <= $I2C_BH1750_ranges[$i][0] and last;
        } 
        if($i == @I2C_BH1750_ranges) {
            # no finer resolution possible, no further poll
            $hash->{PollState} = BH1750_POLLSTATE_LUX_DONE;
            return I2C_BH1750_Poll($hash);
        } else {
            # do finer reading
            my (undef,$mt,$mode)=@{$I2C_BH1750_ranges[$i]};
            Log3 $name, 4, "$name I2C_BH1750_Poll using mt=$mt, mode=$mode";
            $delay=I2C_BH1750_start_measure($hash,$mt,$mode);
            $hash->{PollState} = BH1750_POLLSTATE_LUX_WAIT;
        } 
    } elsif($state == BH1750_POLLSTATE_LUX_WAIT) {
        I2C_BH1750_request_measure($hash);
    } elsif($state == BH1750_POLLSTATE_LUX_DONE) {
        if($hash->{SATURATED}) {
            readingsSingleUpdate($hash, 'state', BH1750_STATE_SATURATED, 1);
            Log3 $hash, 4, "$name sensor saturated ";
        } else {
            readingsSingleUpdate($hash, 'state', BH1750_STATE_OK, 1);
        }
        I2C_BH1750_update_lux($hash);
        $hash->{PollState} = BH1750_POLLSTATE_IDLE;
        I2C_BH1750_i2cwrite($hash, BH1750_POWER_DOWN);
    } else {
         Log3 $name, 1, "$name I2C_BH1750_Poll wrong state state=$state";
        $hash->{PollState} = BH1750_POLLSTATE_IDLE;
    }
    
    $delay and InternalTimer(gettimeofday() + $delay, 'I2C_BH1750_Poll', $hash, 0);
    
    return undef;
}

sub I2C_BH1750_Set($@) 
{
    my ( $hash, @args ) = @_;
    my $name = $hash->{NAME};
    my $cmd = $args[1];
    
    if($cmd eq "update") {
        RemoveInternalTimer($hash);
        $hash->{PollState} = BH1750_POLLSTATE_START_MEASURE; 
        I2C_BH1750_Poll($hash);
    } elsif($cmd eq "deleteminmax") {
        delete($hash->{READINGS}{minimum});
        delete($hash->{READINGS}{maximum});
    } else {
        return "Unknown argument ".$cmd.", choose one of update deleteminmax";
    }
    
    return undef;
}

sub I2C_BH1750_Undef($$)
{
    my ($hash, $arg) = @_;
    
    RemoveInternalTimer($hash);
    
    return undef;
}


sub I2C_BH1750_i2cread($$$) 
{
    my ($hash, $reg, $nbyte) = @_;

    my $name = $hash->{NAME};

    Log3 $name, 5, "$name I2C_BH1750_i2cread $reg,$nbyte";
    
    if (defined (my $iodev = $hash->{IODev})) {
        eval {
            CallFn($iodev->{NAME}, "I2CWrtFn", $iodev, 
                   {
                       direction => "i2cread",
                       i2caddress => $hash->{I2C_Address},
                       reg => $reg,
                       nbyte => $nbyte
                   });
        };
        my $sendStat = $hash->{$iodev->{NAME}.'_SENDSTAT'};
        if (defined($sendStat) && $sendStat eq 'error') {
            readingsSingleUpdate($hash, 'state', BH1750_STATE_I2C_ERROR, 1);
            Log3 ($hash, 3, $hash->{NAME} . ": i2cread on $iodev->{NAME} failed");
            return 0;
        } 
    } else {
        Log3 ($hash, 1, $hash->{NAME} . ': ' . "no IODev assigned to '$hash->{NAME}'");
        return 0;
    }
    
    return 1;
}

sub I2C_BH1750_i2cwrite
{
    my ($hash, $reg, @data) = @_;
    my $name = $hash->{NAME};

    Log3 $name, 5, "$name I2C_BH1750_i2write $reg,@data";

    if (defined (my $iodev = $hash->{IODev})) {
        eval {
            CallFn($iodev->{NAME}, "I2CWrtFn", $iodev, {
                direction => "i2cwrite",
                i2caddress => $hash->{I2C_Address},
                reg => $reg,
                data => join (' ',@data), 
                   });
        };
        my $sendStat = $hash->{$iodev->{NAME}.'_SENDSTAT'};
        if (defined($sendStat) && $sendStat eq 'error') {
            readingsSingleUpdate($hash, 'state', BH1750_STATE_I2C_ERROR, 1);
            Log3 ($hash, 3, $hash->{NAME} . ": i2cwrite on $iodev->{NAME} failed");
            return 0;
        }
    } else {
        Log3 ($hash, 1, $hash->{NAME} . ': ' . "no IODev assigned to '$hash->{NAME}'");
        return 0;
    }
    
    return 1;
}

sub I2C_BH1750_I2CRec ($$) 
{
    my ($hash, $clientmsg) = @_;
    my $name = $hash->{NAME};
    
    Log3 $name, 5, "$name I2C_BH1750_i2Rec";
    my $pname = undef;
    my $phash = $hash->{IODev};
    $pname = $phash->{NAME};
    while (my ( $k, $v ) = each %$clientmsg) { 
        $hash->{$k} = $v if $k =~ /^$pname/;
        Log3 $name, 5, "$name I2C_BH1750_i2Rec $k $v";
    }
    if($clientmsg->{$pname . "_SENDSTAT"} ne "Ok") {
        Log3 $name, 3, "$name I2C_BH1750_i2Rec bad sendstat: ".$clientmsg->{$pname."_SENDSTAT"};
        if($clientmsg->{direction} eq "i2cread" or $clientmsg->{reg}) {
            # avoid recoursion on power down, power down has $clientmsg->{reg} == 0
            I2C_BH1750_Restart_Measure($hash,$hash->{RESTARTDELAY});
        }
        return undef;
    }
    if ( $clientmsg->{direction} eq "i2cread" && defined($clientmsg->{received})) {
        my $register = $clientmsg->{reg};
        Log3 $hash, 4, "$name RX register $register, $clientmsg->{nbyte} byte: $clientmsg->{received}";
        my @raw = split(" ", $clientmsg->{received});
        if ($register == BH1750_RAW_VALUE && $clientmsg->{nbyte} == 2) {
            my $word = $raw[0] << 8 | $raw[1];
            $hash->{RAWVAL}=$word;
            Log3 $name, 4, "$name I2C_BH1750_I2CRec: rawval=$word";
            if($hash->{PollState} == BH1750_POLLSTATE_PRE_LUX_WAIT || 
               $hash->{PollState} == BH1750_POLLSTATE_LUX_WAIT) {
                $hash->{PollState}++;
                I2C_BH1750_Poll($hash);
            }
        }
    }
    return undef;
}

sub I2C_BH1750_update_lux
{ 
    my($hash)=@_;
    my $name=$hash->{NAME};
    my $lux;
    my $delta=$hash->{DELTA};
    
    # lux calculation see manual manual:
    $lux = $hash->{RAWVAL}/1.2*(69/$hash->{MT_VAL})/$hash->{MODE};
    $lux *= $hash->{CORRECTION};

    if($delta) { # update only if delta large enough
        my $lastlux=ReadingsNum($name,"luminosity",1000000);
        $lux == $lastlux and return; # no delta, no update
        
        # check if we have too less delta and return
        if($lastlux > $lux) {
            ($lastlux-$lastlux*$delta < $lux) and return;
        } else {
            ($lastlux+$lastlux*$delta > $lux) and return;
        }
    }
    # round value
    if($lux < 100) {
        $lux = int($lux*10+0.5)/10;
    } elsif($lux < 1000) {
        $lux=int($lux+0.5);
    } elsif($lux < 10000) {
        $lux=int($lux/10+0.5); $lux *= 10;
    } elsif($lux < 100000) {
        $lux=int($lux/100+0.5); $lux *= 100;
    }  else {
        $lux=int($lux/1000+0.5); $lux *= 1000;
    }
    Log3 $name, 4, "$name I2C_BH1750_update_lux: luminosity=$lux";
    readingsBeginUpdate($hash);
    readingsBulkUpdate($hash, "luminosity", $lux);
    $lux < ReadingsNum($name,"minimum", 1000000) and readingsBulkUpdate($hash, "minimum", $lux);
    $lux > ReadingsNum($name,"maximum",-1000000) and readingsBulkUpdate($hash, "maximum", $lux);
    readingsEndUpdate($hash, 1);
}

sub  I2C_BH1750_request_measure
{
    my ($hash) =  @_;
    I2C_BH1750_i2cread($hash,BH1750_RAW_VALUE,2);
}


sub I2C_BH1750_start_measure
{
    my ($hash,$mt,$mode)=@_;
    my $name = $hash->{NAME};
    $hash->{MT_VAL} = $mt;
    $hash->{MODE}   = ($mode ==  BH1750_H_MODE2 || $mode ==  BH1750_H_MODE2_ONCE) ? 2 : 1;
    my $hi=($mt>>5) | 0x40;
    my $lo=($mt&0x1F) | 0x60;
    I2C_BH1750_i2cwrite($hash,BH1750_RESET);
    I2C_BH1750_i2cwrite($hash,$hi); # set MT value
    I2C_BH1750_i2cwrite($hash,$lo);
    I2C_BH1750_i2cwrite($hash,$mode);
    my $mindelay = ($mode == BH1750_L_MODE || $mode == BH1750_L_MODE_ONCE) ? 24 : 180;
    $mindelay = $mindelay * ($mt/BH1750_MT_DEFAULT);
    Log3 $name, 5, "$name I2C_BH1750_start_measure: duration ".int($mindelay)."ms";
    $mindelay /=1000; # seconds

    return $mindelay;
}

sub I2C_BH1750_sleep
{
    select(undef, undef, undef, $_[0]);
}

1;

=pod
=item device
=item summary support for the BH1750 I2C light sensor
=item summary_DE Unterst&uuml;tzung f&uuml;r den BH1750 I2C Lichtsensor
=begin html

<a name="I2C_BH1750"></a>
<h3>I2C_BH1750</h3>
<ul>
  <a name="I2C_BH1750"></a>
  <p>
    Module for the I<sup>2</sup>C BH1750 light sensor.

    The BH1750 sensor supports a luminous flux from 0 up to 120k lx 
    and a resolution up to 0.11lx. 
    It supports different modes to be able to cover this large range of 
    data. <br>
    The I2C_BH1750 module tries always to get
    the luminosity data from the sensor as good as possible. To achieve 
    this the module first reads flux data in the least sensitive mode and then
    decides which mode to take to get best results.
    
    <br><br>
    
    For the I<sup>2</sup>C bus the same things are valid as described in the 
    <a href="#I2C_TSL2561">I2C_TSL2561</a> &nbsp;
    module.<br>

    <b>Define</b>
    <ul>
      <code>define BH1750 I2C_BH1750 [I2C address]</code><br><br>
      I2C address must be 0x23 or 0x5C (if omitted default address 0x23 is used)
      <br>
      Examples:
      <pre>
        # define IO-Module:
        define I2C_2 RPII2C 2
        # Use IODev I2C_2 with default i2c address 0x23
        # set poll interval to 1 min
        # generate luminosity value only if difference to last value is at least 10%
        define BH1750 I2C_BH1750
        attr BH1750 IODev I2C_2
        attr BH1750 poll_interval 1
        attr BH1750 percentdelta 10
      </pre>
    </ul>

    <b>Set</b>
    <ul>
      <li><code>set &lt;device name&gt; update</code><br>
        Force immediate illumination measurement and restart a 
        new poll_interval.
        Note that the new readings are not yet available after set returns 
        because the
        measurement is performed asynchronously. Depending on the flux value
        this may require more than one second to complete.<br>
      </li>
      <li><code>set &lt;device name&gt; deleteminmax</code><br>
        Delete the minimum maximum readings to start new
        min/max measurement
      </li>
    </ul>
  <p>

    <b>Readings</b>
    <ul>
      <li>luminosity<br>
        Illumination measurement in the range of 0 to 121557 lx.<br>
        The generated luminosity value is stored with up to one 
        fractional digit for values below 100 and 
        rounded to 3 significant digits for all other values. 
        Compared with the accuracy of the sensor it makes no 
        sense to store the values with more precision.
      </li>
      <li>minimum<br>
        minimum of measured luminosity
      </li>
      <li>maximum<br>
        maximum of measured luminosity
      </li>
      <li>state<br>
        Default: Defined, Ok, Saturated, I2C Error
      </li>
    </ul>
  <p>
    
    <a name="I2C_BH1750attr"></a>
    <b>Attributes</b>
    <ul>
      <li>IODev<br>
        Set the name of an IODev module like RPII2C<br>
        Default: undefined<br>
      </li>
      <li>poll_interval<br>
        Set the polling interval in minutes to query the sensor for new measured  values.
        By changing this attribute a new illumination measurement will be triggered.<br>
        valid values: 0.1, 0.2, 0.5, 1, 2, 5, 10, 20, 30, 60<br>
      </li>
      <li>percentdelta<br>
        If set a luminosity reading is only generated if 
        the difference between the current luminosity value and the last reading is 
        at least percentdelta percents.<br>
      </li>
      <li>correction<br>
        Linear correction factor to be applied to the sensor value.
        Compared with a commercial light meter it seems that the values for my 
        BH1750 are about 25% to low in day light (correction 1.25). 
        The TLS2561 compares much better with the light meter but has the disadvantage 
        that it saturates at about 40k lux.<br>
        The correction factor can also be used if your sensor is behind an opal glass.<br>
        valid range: 0.5 to 2.0<br>
      </li>
    </ul>
  <p>
    <br>
</ul>
=end html

=cut
