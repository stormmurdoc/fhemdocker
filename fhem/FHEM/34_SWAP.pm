
# $Id: 34_SWAP.pm 12056 2016-08-22 19:30:31Z justme1968 $
#
# TODO:
# transmitted queue -> remove if status is received
# remove old command from send queue if new command for the same register is send
# merge send and trasmit queue
# rename $hash->{product} to $hash->{'.product'}
# rename $hash->{devices} to $hash->{'.devices'}

package main;

use strict;
use warnings;
use SetExtensions;

use Data::Dumper;
use XML::Simple qw(:strict);

sub SWAP_Parse($$);
sub SWAP_Send($$$@);
sub SWAP_PushCmdStack($$$@);
sub SWAP_ProcessCmdStack($);

my %models = (
);

my %function_codes = (
  '00' => 'status',
  '01' => 'query',
  '02' => 'command',
);


use constant  { STATUS  => '00',
                QUERY   => '01',
                COMMAND => '02',
                BIN    => 1,
                NUM    => 2,
                STR => 3,
                STREAM => 4,
                IN  => 1,
                OUT => 2,  };

my %default_registers = (
  0x00 => { name => 'ProductCode', size => 8, endpoints => [ { name => 'ProductCode',    size => 8 },
                                                             { name => 'ManufacturerID', position => 0, size => 4, },
                                                             { name => 'ProductID',      position => 4, size => 4, }, ], },
  0x01 => { name => 'HardwareVersion',    },
  0x02 => { name => 'FirmwareVersion',    },
  0x03 => { name => 'SystemState',        },
  0x04 => { name => 'FrequencyChannel',   },
  0x05 => { name => 'SecurityOption',     },
  0x06 => { name => 'SecurityPassword',   },
  0x07 => { name => 'SecurityNonce',      },
  0x08 => { name => 'NetworkID',          },
  0x09 => { name => 'DeviceAddress',      size => 1, direction => OUT },
  0x0A => { name => 'PeriodicTxInterval', size => 2, direction => OUT },
);

my %system_state = (
  0x00 => 'RESTART',
  0x01 => 'RXON',
  0x02 => 'RXOFF',
  0x03 => 'SYNC',
  0x04 => 'LOWBAT',
  0x05 => 'FLASH',
);

my $developers = {};
my $products = {};

sub
SWAP_Initialize($)
{
  my ($hash) = @_;

  ($developers,$products) = SWAP_loadDevices();

  $hash->{Match}     = ".*";
  $hash->{SetFn}     = "SWAP_Set";
  $hash->{GetFn}     = "SWAP_Get";
  $hash->{DefFn}     = "SWAP_Define";
  $hash->{UndefFn}   = "SWAP_Undef";
  $hash->{FingerprintFn}   = "SWAP_Fingerprint";
  $hash->{ParseFn}   = "SWAP_Parse";
  $hash->{AttrFn}    = "SWAP_Attr";
  $hash->{AttrList}  = "IODev".
                       " ignore:1,0".
                       " createUnknownReadings:1,0".
                       " $readingFnAttributes" .
                       " ProductCode:".join(",", sort keys %{$products});

  #$hash->{FW_summaryFn} = "SWAP_summaryFn";
}

sub
SWAP_loadDevices()
{
  my $_developers = {};
  my $_products = {};

  my $file_name = "$attr{global}{modpath}/FHEM/lib/SWAP/devices.xml";
  if( !SWAP_loadDevicesHelper( $file_name, $_developers, $_products ) ) {
    Log3 undef, 2, "could not read $file_name";
  }

  $file_name = "$attr{global}{modpath}/FHEM/lib/SWAP/devices-local.xml";
  if( !SWAP_loadDevicesHelper( $file_name, $_developers, $_products ) ) {
    Log3 undef, 4, "could not read $file_name";
  }

  return ($_developers,$_products);
}

sub
SWAP_loadDevicesHelper($$$)
{
  my ($file_name, $_developers, $_products) = @_;

  return 0 if( ! -e $file_name );

  my $developers = XMLin($file_name, KeyAttr => { }, ForceArray => [ 'developer', 'dev' ]);

  foreach my $developer (@{$developers->{developer}}){
    my $developer_id = $developer->{id};

    my $_developer = $_developers->{$developer_id} = { name => $developer->{name}, devices => {}, };

    foreach my $device (@{$developer->{dev}}){
      my $id = $device->{id};
      my $name = $device->{name};
      my $label = $device->{label};

      $_developer->{devices}->{$id} = { name => $name, label => $label, };

      my $productcode = sprintf("%08X%08X", $developer_id, $id);
      $_products->{$productcode} = { name => $name, label => $label, };

      #readDeviceXaML( $_products->{$productcode}, "$attr{global}{modpath}/FHEM/lib/SWAP/$_developer->{name}/$name.xml" );
    }
  }

  return 1;
}
sub
readDeviceXML($$)
{
  my ($product, $file_name) = @_;
  my $map = { bin => BIN,
              num => NUM,
              str => STR,
              stream => STREAM,
              inp => IN,
              out => OUT, };

  if( ! -e $file_name ) {
    $product = undef;
    Log3 undef, 2, "could not read $file_name";
    return;
  }

  my $device = XMLin($file_name, KeyAttr => {}, ForceArray => [ 'reg', 'param', 'endpoint', 'unit', ]);

  delete $product->{registers};
  $product->{pwrdownmode} = $device->{pwrdownmode} eq "true"?1:0;
  foreach my $register (@{$device->{config}->{reg}}) {
    my $id = $register->{id};

    my @endpoints = ();
    foreach my $param (@{$register->{param}}){
      my $_endpoint = {};
      $_endpoint->{name} = $param->{name};
      $_endpoint->{name} =~ s/ /_/g;
      $_endpoint->{position} = $param->{position} if( defined($param->{position}) );
      $_endpoint->{size} = 0+$param->{size} if( defined($param->{size}) );
      $_endpoint->{direction} = OUT;
      $_endpoint->{type} = $map->{$param->{type}};
      $_endpoint->{default} = $param->{default};
      $_endpoint->{verif} = $param->{verif};

      push( @endpoints, $_endpoint );
    }

    my $r = { name => $register->{name},
              hwmask => $register->{hwmask},
              swversion => $register->{swversion},
              type => "config",
              endpoints => \@endpoints, };
    if( !defined($product->{registers}->{$id}) ) {
      $product->{registers}->{$id} = $r;
    } elsif( ref($product->{registers}->{$id}) ne 'ARRAY' ) {
      $product->{registers}->{$id} = [$product->{registers}->{$id}];
      push( @{$product->{registers}->{$id}}, $r );
    } else {
      push( @{$product->{registers}->{$id}}, $r );
    }
  }

  foreach my $register (@{$device->{regular}->{reg}}) {
    my $id = $register->{id};

    my @endpoints = ();
    foreach my $endpoint (@{$register->{endpoint}}){
      my $_endpoint = {};
      $_endpoint->{name} = $endpoint->{name};
      $_endpoint->{name} =~ s/ /_/g;
      $_endpoint->{position} = $endpoint->{position} if( defined($endpoint->{position}) );
      $_endpoint->{size} = 0+$endpoint->{size} if( defined($endpoint->{size}) );
      $_endpoint->{direction} = $map->{$endpoint->{dir}};
      $_endpoint->{type} = $map->{$endpoint->{type}};

      $_endpoint->{size} = 1 if( !defined($_endpoint->{size}) && $_endpoint->{direction} == OUT );

      if( defined($endpoint->{units}) && defined($endpoint->{units}->{unit}) ) {
        foreach my $unit (@{$endpoint->{units}->{unit}}){
          push @{$_endpoint->{units}}, $unit;
        }
      }

      push( @endpoints, $_endpoint);
    }

    my $r = { name => $register->{name},
              hwmask => $register->{hwmask},
              swversion => $register->{swversion},
              type => "regular",
              endpoints => \@endpoints, };
    if( !defined($product->{registers}->{$id}) ) {
      $product->{registers}->{$id} = $r;
    } elsif( ref($product->{registers}->{$id}) ne 'ARRAY' ) {
      $product->{registers}->{$id} = [$product->{registers}->{$id}];
      push( @{$product->{registers}->{$id}}, $r );
    } else {
      push( @{$product->{registers}->{$id}}, $r );
    }
  }
}

sub
SWAP_Define($$)
{
  my ($hash, $def) = @_;
  my @a = split("[ \t][ \t]*", $def);

  if(@a != 3 && @a != 4 ) {
    my $msg = "wrong syntax: define <name> SWAP <addr>[.<reg>]";
    Log3 undef, 2, $msg;
    return $msg;
  }

  $a[2] =~ m/^([\da-f]{2})(\.([\da-f]{2}))?$/i;
  #$a[2] =~ m/^([\da-f]{2})(\.([\da-f]{2}(\.[\da-f]+)?))?$/i;
  return "$a[2] is not a valid SWAP address" if( !defined($1) );

  my $name = $a[0];
  my $addr = $1; #substr( $a[2], 0, 2 );
  my $reg = $3; #substr( $a[2], 3, 2 );
  my $productcode = $a[3];

  return "$addr is not a 1 byte hex value" if( $addr !~ /^[\da-f]{2}$/i );
  return "$addr is not an allowed address" if( $addr eq "00" );

  return "$reg not allowed" if( $reg && hex($reg) <= 0x0A );
  #return "please define a SWAP device with  $addr first" if( $reg && !$modules{SWAP}{defptr}{$addr} );

  my $id = $addr;
  $id .= ".". $reg if( $reg );

  return "SWAP device $id already used for $modules{SWAP}{defptr}{$id}->{NAME}." if( $modules{SWAP}{defptr}{$id}
                                                                                         && $modules{SWAP}{defptr}{$id}->{NAME} ne $name );
#  return "SWAP device $addr already used for $modules{SWAP}{defptr}{$addr}->{NAME}." if( $modules{SWAP}{defptr}{$addr}
#                                                                                         && $modules{SWAP}{defptr}{$addr}->{NAME} ne $name );

  delete( $hash->{reg} );
  delete( $hash->{product} ) if( defined($attr{$name}{ProductCode}) && $attr{$name}{ProductCode} ne $productcode );
  delete( $attr{$name}{ProductCode} ) if( defined($attr{$name}{ProductCode}) && $attr{$name}{ProductCode} ne $productcode );

  $hash->{addr} = $addr;
  $hash->{reg} = $reg if( $reg );
  $hash->{devices} = () if( !$reg );

  $modules{SWAP}{defptr}{$id} = $hash;
  $modules{SWAP}{defptr}{$addr}->{devices}{$reg} = $hash if( $reg );

  my $type = $hash->{TYPE};
  $hash->{TYPE} = "SWAP";
  AssignIoPort($hash);
  $hash->{TYPE} = $type;
  if(defined($hash->{IODev}->{NAME})) {
    Log3 $name, 3, "$name: I/O device is " . $hash->{IODev}->{NAME};
  } else {
    Log3 $name, 1, "$name: no I/O device";
  }

  CommandAttr(undef, "$name ProductCode $productcode") if( $productcode );
  if( defined($productcode) && defined($products->{$productcode})
      && !defined($products->{$productcode}->{registers}) ){
    SWAP_readDeviceXML( $hash, $productcode );
  }

  $hash->{product} = $products->{$productcode} if( defined($productcode) && defined($products->{$productcode} ) );

  $hash->{DEF} = $hash->{addr};
  $hash->{DEF} .= $hash->{reg} if( $hash->{reg} );

  SWAP_Send($hash, $addr, QUERY, "00" );

  return undef;
}

#####################################
sub
SWAP_Undef($$)
{
  my ($hash, $arg) = @_;
  my $name = $hash->{NAME};
  my $addr = $hash->{addr};
  my $reg = $hash->{reg};

  my $id = $addr;
  $id .= ".". $reg if( $reg );
  delete( $modules{SWAP}{defptr}{$id} );
  delete($modules{SWAP}{defptr}{$addr}->{devices}{$reg}) if( $reg );

  foreach my $reg (keys %{$hash->{devices}}){
    CommandDelete(undef,$modules{SWAP}{defptr}{$addr.".".$reg}->{NAME})
  }

  return undef;
}

sub
SWAP_getRegister($$)
{
  my ($hash, $reg) = @_;

  my $register = $hash->{product}->{registers}->{$reg};
  return undef if( !defined($register) );

  my $hwversion = $hash->{"SWAP_01-HardwareVersion"};
  my $swversion = $hash->{"SWAP_02-FirmwareVersion"};
  $hwversion = hex($hwversion) if( defined($hwversion) );
  $swversion = hex($swversion) if( defined($swversion) );
  if( ref($register) eq 'ARRAY' ) {
    foreach my $register (@{$register}) {
      next if( !$register->{hwmask} && !$register->{swversion} );
      next if( $hwversion && $register->{hwmask} && ($hwversion & hex($register->{hwmask})) != hex($register->{hwmask}) );
      next if( $swversion && $register->{swversion} && $swversion < hex($register->{swversion}) );

      return $register;
    }

    foreach my $register (@{$register}) {
      next if( $hwversion && $register->{hwmask} && ($hwversion & hex($register->{hwmask})) != hex($register->{hwmask}) );
      next if( $swversion && $register->{swversion} && $swversion < hex($register->{swversion}) );

      return $register;
    }

    return undef;
  }

  return undef if( $hwversion && $register->{hwmask} && ($hwversion & hex($register->{hwmask})) != hex($register->{hwmask}) );
  return undef if( $swversion && $register->{swversion} && $swversion < hex($register->{swversion}) );

  return $register if( defined($register) );

  return undef;
}

#####################################
sub
SWAP_Set($@)
{
  my ($hash, $name, @aa) = @_;

  my $cnt = @aa;

  return "\"set $name\" needs at least one parameter" if($cnt < 1);

  my $cmd = $aa[0];
  my $arg = $aa[1];
  my $arg2 = $aa[2];
  my $arg3 = $aa[3];

  my $list = "regGet regSet";
  $list .= " statusRequest:noArg";
  $list .= " readDeviceXML:noArg";
  $list .= " clearUnconfirmed:noArg";

  if( my $sl = $modules{$hash->{TYPE}}{SWAP_SetList} ) {

    if( $cmd ne '?' ) {
      if( my @a = grep( $_ =~ /^$cmd($|:)/, keys %{$sl} ) ) {
        return "set $cmd requires $sl->{$a[0]} parameter(s)" if( defined($sl->{$cmd}) && $sl->{$cmd} != $cnt-1 );

        if( my $set = $modules{$hash->{TYPE}}{SWAP_SetFn} ) {
          no strict "refs";
          ($cmd, $arg, $arg2, $arg3) = &{$set}(@_);
          use strict "refs";

          return $arg if( !defined($cmd) );

          $cnt = 2 if( defined($arg) );
          $cnt = 3 if( defined($arg2) );
        }
      }
    }

    foreach my $cmd ( sort keys ( %{$sl} ) ) {
      $list .= " ";
      $list .= $cmd;
      $list .= ":noArg" if( defined($sl->{$cmd}) && !$sl->{$cmd} );
    }
    #$list .= " " . join(" ", sort keys %{$sl});
  }

  if( $hash->{reg} ) {
    my $reg = hex($hash->{reg});
    my $register = SWAP_getRegister($hash,$reg);
    if( defined($register)
        && defined($register->{endpoints}->[0])
        && $register->{endpoints}->[0]->{size} == 1 ) {

      my $hasOn  = ($list =~ m/\bon\b/);
      my $hasOff = ($list =~ m/\boff\b/);
      my $hasPct = ($list =~ m/\bpct\b/) || ($register->{endpoints}->[0]->{type} != NUM);

      $list .= " on" if( !$hasOn );
      $list .= " off" if( !$hasOff );
      $list .= " pct:slider,0,1,100" if( !$hasPct );

      if( !$hasOn && $cmd eq "on" ) {
        $cmd = "regSet";
        $arg = $hash->{reg};
        $arg2 = "FF";
        $cnt = 3;
      } elsif( !$hasOff && $cmd eq "off" ) {
        $cmd = "regSet";
        $arg = $hash->{reg};
        $arg2 = "00";
        $cnt = 3;
      } elsif( !$hasPct && $cmd eq "pct" ) {
        $cmd = "regSet";
        $arg2 = sprintf("%02X",$arg*255/100);
        $arg = $hash->{reg}.".1";
        $cnt = 3;
      }
    }
  }

  return "\"set $name $cmd\" needs one argument"  if( $cnt < 2 && ( $cmd eq 'regGet' ) );
  return "\"set $name $cmd\" needs two arguments" if( $cnt < 3 && ( $cmd eq 'regSet' ) );

  if( ($cmd eq "regSet" || $cmd eq "regGet") && $arg !~ m/^[\da-f]{2}(\.([\da-f]+))?$/i ) {
    foreach my $reg ( sort { $a <=> $b } keys ( %default_registers ) ) {
      my $register = $default_registers{$reg};
      if( $register->{name} =~ m/^$arg$/i ) {
        $arg = sprintf("%02X", $reg);
        last;
      }
    }
  }

  if( $cmd eq "regSet" ) {
    $arg =~ m/^([\da-f]{2})(\.([\da-f]+))?$/i;
    return "$arg is not a valid register name for $cmd" if( !defined($1) );

    my $reg = hex($1);
    if( $reg <= 0x0A ) {
      my $register = $default_registers{$reg};
      return "register $arg is readonly" if( !defined($register->{direction}) );
      my $len = $register->{size};
      return "value has to be ". $len ." byte(s) in size" if( $len*2 != length( $arg2 ) );
    } else {
      return "register $arg is not known" if( $hash->{reg} && hex($hash->{reg}) != $reg );
      my $register = SWAP_getRegister($hash,$reg);
      return "register $arg is not known" if( !defined($register) );

      my $hwversion = $hash->{"SWAP_01-HardwareVersion"};
      return "register $arg is unused with HardwareVersion $hwversion" if( $hwversion && $register->{hwmask} && (hex($hwversion) & hex($register->{hwmask})) != hex($register->{hwmask}) );
      my $swversion = $hash->{"SWAP_02-FirmwareVersion"};
      return "register $arg is not available with FirmwareVersion $swversion" if( $swversion && $register->{swversion} && hex($swversion) < hex($register->{swversion}) );

      return "register $arg is readonly" if( $register->{endpoints}->[0]->{direction} != OUT );

      if( defined($3) ) {
        my $ep = hex($3);

        #return "can't write endpoint for sleeping devices" if( $hash->{product}->{pwrdownmode} == 1 );

        return "endpoint $1.0 is not known" if( !defined($register->{endpoints}->[0]) );
        my $endpoint = $register->{endpoints}->[0];
        return "reading for $1 is not available" if( !defined(ReadingsVal( $name, $1."-".$endpoint->{name}, undef)) );

        return "endpoint $1.$3 is not known" if( !defined($register->{endpoints}->[$ep]) );
        return "endpint $1.$3 is readonly" if( $register->{endpoints}->[$ep]->{direction} != OUT );

        my $len = $register->{endpoints}->[$ep]->{size};
        if( $len =~ m/^(\d+)\.(\d+)$/ ) {
          return "only single bit endpoints are supported in regSet" if( $1 != 0 && $2 != 1 );
          return "value has to 0 or 1" if( $arg2 ne "0" && $arg2 ne "1" );
        } else {
          return "value has to be ". $len ." byte(s) in size" if( $len*2 != length( $arg2 ) );
        }
      } else {
        my $len = $register->{size};
        if( !$len  ) {
          my $max_pos = 0;
          my $max_pos_size = 1;
          foreach my $endpoint ( @{$register->{endpoints}} ) {
            if( !defined($endpoint->{position}) ) {
              $len = $endpoint->{size};
              last;
            }

            $max_pos = maxNum( $max_pos, int($endpoint->{position}) );
            $max_pos_size = int($endpoint->{size} + 0.9 );

            $len += $endpoint->{size};
          }

          $len = maxNum( $len, $max_pos+$max_pos_size );
        }

        return "value has to be ". $len ." byte(s) in size" if( $len*2 != length( $arg2 ) );
      }
    }
  } elsif( $cmd eq "regGet" ) {
    $arg =~ m/^([\da-f]{2})$/i;
    return "$arg is not a valid register name for $cmd" if( !defined($1) );

    my $reg = hex($1);
    return "register $arg is not known" if( $hash->{reg} && hex($hash->{reg}) != $reg );

    if( $reg <= 0x0A ) {
    } else {
      my $register = SWAP_getRegister($hash,$reg);
      return "register $arg is not known" if( !defined($register) );

      my $hwversion = $hash->{"SWAP_01-HardwareVersion"};
      return "register $arg is unused with HardwareVersion $hwversion" if( $hwversion && $register->{hwmask} && (hex($hwversion) & hex($register->{hwmask})) != hex($register->{hwmask}) );
      my $swversion = $hash->{"SWAP_02-FirmwareVersion"};
      return "register $arg is not available with FirmwareVersion $swversion" if( $swversion && $register->{swversion} && hex($swversion) < hex($register->{swversion}) );
    }
  }

  readingsSingleUpdate($hash, "state", "set-".$cmd, 1) if( $cmd ne "?" );

  my $addr = $hash->{addr};
  if( $cmd eq "regGet" ) {

    SWAP_Send($hash, $addr, QUERY, sprintf("%02s",$arg) );

  } elsif ( $cmd eq "regSet" ) {

    $arg =~ m/^([\da-f]{2})(\.([\da-f]+))?$/i;
    my $reg = hex($1);
    my $register = SWAP_getRegister($hash,$reg);
    if( defined($3) ) {
      my $ep = hex($3);

      if( defined($register)
          && defined($register->{endpoints})
          && defined($register->{endpoints}->[$ep]) ) {
        my $endpoint = $register->{endpoints}->[0];
        my $value = ReadingsVal( $name, $1."-".$endpoint->{name}, undef );

        $endpoint = $register->{endpoints}->[$ep];

        if( my $position = $endpoint->{position} ) {
          my $size = $endpoint->{size};
          if( $position =~ m/^(\d+)\.(\d+)$/ ) {
            return "only single bit endpoints supported" if( $size ne "0.1" );
            my $bytes = hex(substr($value, $1*2, 2));
            my $mask = 0x01 << $2;
            $bytes &= ~$mask if( $arg2 eq "0" );
            $bytes |=  $mask if( $arg2 eq "1" );
            $bytes &= 0xFF;
            substr( $value, $1*2, 2 , sprintf("%02X",$bytes) );
          } else {
            substr( $value, $endpoint->{position}*2, $endpoint->{size}*2, $arg2 );
          }

          $arg2 = $value;
Log 3, $value;
        }
      }
    }

    #if( defined($register->{endpoints})
    #    && defined($register->{endpoints}->[0]) ) {
    #  if( my $verif = $register->{endpoints}->[0]->{verif} ) {
    #  }
    #}

    if( $hash->{product}->{pwrdownmode} == 1
        && $hash->{"SWAP_03-SystemState"} ne "01"
        && $hash->{"SWAP_03-SystemState"} ne "03" ) {
      SWAP_PushCmdStack($hash, $addr, COMMAND, sprintf("%02X",$reg), sprintf("%02s",$arg2) );
    } else {
      SWAP_Send($hash, $addr, COMMAND, sprintf("%02X",$reg), sprintf("%02s",$arg2) );
    }

#    #change device address
#    if( $reg == 0x09
#        && $hash->{product}->{pwrdownmode} == 0 ) {
#      delete( $modules{SWAP}{defptr}{$addr} );
#
#      $addr = sprintf( "%02s", $arg2 );
#
#      $hash->{DEF} =~ s/^../$addr/;
#      $hash->{addr} = $addr;
#      $hash->{"SWAP_09-DeviceAddress"} = $addr;
#
#      $modules{SWAP}{defptr}{$addr} = $hash;
#    }

    #readingsSingleUpdate($hash, "0B-RGBlevel", $arg2, 1) if( defined($attr{$name}{ProductCode}) && $attr{$name}{ProductCode} eq '0000002200000003' && $reg == 0x0B );

  } elsif( $cmd eq "getConfig" ) {

    foreach my $reg ( sort { $a <=> $b } keys ( %default_registers ) ) {
      SWAP_Send($hash, $addr, QUERY, sprintf( "%02X", $reg ) );
    }

  } elsif( $cmd eq "statusRequest" ) {

    foreach my $reg ( sort { $a <=> $b } keys ( %default_registers ) ) {
      SWAP_Send($hash, $addr, QUERY, sprintf( "%02X", $reg ) );
    }

    if( defined($hash->{product}->{registers} ) ) {
      foreach my $reg ( sort { $a <=> $b } keys ( %{$hash->{product}->{registers}} ) ) {
        my $register = SWAP_getRegister($hash,$reg);
        next if( !defined($register) );

        next if( $hash->{reg} && hex($hash->{reg}) != $reg );
        SWAP_Send($hash, $addr, QUERY, sprintf( "%02X", $reg ) );
      }
    }

  } elsif( $cmd eq "readDeviceXML" ) {
    my $productcode = $attr{$name}{ProductCode} if( defined($attr{$name}{ProductCode} ) );
    if( defined($products->{$productcode} ) ) {
      SWAP_readDeviceXML( $hash, $productcode );
      $hash->{product} = $products->{$productcode} if( defined($productcode) && defined($products->{$productcode} ) );
    } else {
      return "can't read deviceXML for unknown ProductCode";
    }

  } elsif( $cmd eq "clearUnconfirmed" ) {
    delete( $hash->{sentList} );
    delete ($hash->{SWAP_Sent_unconfirmed});

  } elsif( $cmd eq "flash" ) {
    my $firmwareFolder = "./FHEM/firmware/";
    my $hexfile;
    if ($cnt < 2) {
      #No argument to flash
      return "Device has no product code; you need to specify a firmeware to flash" if( !defined($attr{$name}{ProductCode} ) );
      $hexfile = $firmwareFolder . "SWAP_$attr{$name}{ProductCode}.hex";
    } else {
      if ( substr($arg, 0, 1) eq "/" ) {
        #absolute path provided
        $hexfile = $arg;
      } else {
        #Product code provided
        $hexfile = $firmwareFolder . "SWAP_$arg.hex";
      }
    }
    open FILE, $hexfile or return "Could not open $hexfile";
    Log3 $name, 1, "Flashing $hexfile to $name";
    my @a = <FILE>;
    @a = map { substr $_, 3, -1 } @a;
    $hash->{HEXFILE} = [ @a ];
    SWAP_Send($hash, $addr, COMMAND, "03", "05" ); #Set "System State" to "Flash"

  } else {
    return SetExtensions($hash, $list, $name, @aa);
    return "Unknown argument $cmd, choose one of ".$list;
  }

  return undef;
}

#####################################
sub
SWAP_Get($@)
{
  my ($hash, $name, $cmd, @args) = @_;

  return "\"get $name\" needs at least one parameter" if(@_ < 3);

  my $list = "listUnconfirmed:noArg regList:noArg regListAll:noArg deviceXML:noArg products:noArg";

  if( my $gl = $modules{$hash->{TYPE}}{SWAP_GetList} ) {

    if(exists($gl->{$cmd}) ) {
      return "get $cmd requires $gl->{$cmd} parameter(s)" if( defined($gl->{$cmd}) && $gl->{$cmd} != int(@args) );

      if( my $get = $modules{$hash->{TYPE}}{SWAP_GetFn} ) {
        no strict "refs";
        my $ret = &{$get}(@_);
        use strict "refs";

        return $ret;
      }
    }

    foreach my $cmd ( sort keys ( %{$gl} ) ) {
      $list .= " ";
      $list .= $cmd;
      $list .= ":noArg" if( defined($gl->{$cmd}) && !$gl->{$cmd} );
    }
    #$list .= " " . join(" ", sort keys %{$gl});
  }

  return "Unknown argument $cmd, choose one of $list" if( $cmd eq '?' );

  if( $cmd eq 'regList' || $cmd eq 'regListAll' ) {
    my $ret = "";

    $ret .= sprintf( "reg.\t| pos\t| size\t| dir.\t| name\n");

    if( $cmd eq 'regListAll' ) {
      foreach my $reg ( sort { $a <=> $b } keys ( %default_registers ) ) {
        my $register = $default_registers{$reg};
        $ret .= sprintf( "%02X\t| %s\t| %s\t| %s\t|%s\n", $reg,
                                                    "",
                                                    defined($register->{size})?$register->{size}:"",
                                                    defined($register->{direction})?($register->{direction}==OUT?"set":"get"):"",
                                                    $register->{name}  );

        my $i = 0;
        foreach my $endpoint ( @{$register->{endpoints}} ) {
          $ret .= sprintf( "  .%i\t|   %s\t|   %s\t|  %s\n", $i,
                                                         defined($endpoint->{position})?$endpoint->{position}:"",
                                                         defined($endpoint->{size})?$endpoint->{size}:"",
                                                         defined($endpoint->{direction})?($endpoint->{direction}==OUT?"set":"get"):"",
                                                         $endpoint->{name}  ) if($i > 0);
          ++$i;
        }
      }
    }

    if( defined($hash->{product}->{registers} ) ) {
      foreach my $reg ( sort { $a <=> $b } keys ( %{$hash->{product}->{registers}} ) ) {
        next if( $hash->{reg} && hex($hash->{reg}) != $reg );
        my $register = SWAP_getRegister($hash,$reg);
        next if( !defined($register) );

        my $i = 0;
        foreach my $endpoint ( @{$register->{endpoints}} ) {
          $ret .= sprintf( "%02X\t| %s\t| %s\t| %s\t|%s\n", $reg,
                                                      ($i!=0&&defined($endpoint->{position}))?$endpoint->{position}:"",
                                                      defined($register->{size})?$register->{size}:"",
                                                      defined($register->{direction})?($register->{direction}==OUT?"set":"get"):"",
                                                      $register->{name}  ) if($i == 0 && defined($endpoint->{position}));
          $ret .= sprintf( "%02X\t| %s\t| %s\t| %s\t|%s\n", $reg,
                                                      "",
                                                      $endpoint->{size},
                                                      $endpoint->{direction}==OUT?"set":"get",
                                                      $endpoint->{name}  ) if($i == 0 && !defined($endpoint->{position}));
          $ret .= sprintf( "  .%i\t|   %s\t|   %s\t|   %s\t|  %s\n", $i,
                                                         defined($endpoint->{position})?$endpoint->{position}:"",
                                                         $endpoint->{size},
                                                         $endpoint->{direction}==OUT?"set":"get",
                                                         $endpoint->{name}  ) if($i == 0 && defined($endpoint->{position}));
          $ret .= sprintf( "  .%i\t|   %s\t|   %s\t|   %s\t|  %s\n", $i,
                                                         defined($endpoint->{position})?$endpoint->{position}:"",
                                                         $endpoint->{size},
                                                         $endpoint->{direction}==OUT?"set":"get",
                                                         $endpoint->{name}  ) if($i > 0);
          ++$i;
        }
      }
    }

    return $ret;
  } elsif( $cmd eq "listUnconfirmed" ) {
    my $ret;

    foreach my $params (@{$hash->{sentList}}) {
      #$ret .= " ". $params->[0] ."\t". $params->[1] ."\t". $params->[2] ."\t". ($params->[3]?$params->[3]:"") ."\n";
      $ret .= " ". $params->[0] ."\t". $function_codes{$params->[1]} ."\t ". $params->[2] ."\t". ($params->[3]?$params->[3]:"") ."\n";
    }
    $ret = "addr.\t  type\treg.\tdata\n". $ret if( $ret );

    $ret = "no unconfirmed messages" if( !$ret );
    return $ret;
  } elsif( $cmd eq "deviceXML" ) {
    return Dumper $hash->{product};
  } elsif( $cmd eq "products" ) {
    return Dumper $products;
  }

  return "Unknown argument $cmd, choose one of $list";
}

sub
SWAP_regName($$$)
{
  my ($rid, $ep, $endpoint) = @_;

  $ep = "0$ep" if( length($ep) == 0 );

  if( !defined($endpoint) ) {
    return $rid if( $ep == 0 && !defined($endpoint->{position}) );
    return $rid .'.'. $ep;
  }

  return $rid .'-'. $endpoint->{name} if( $ep == 0 && !defined($endpoint->{position}) );
  return $rid .'.'. $ep .'-'. $endpoint->{name};
}
sub
SWAP_readDeviceXML($$)
{
  my ($hash, $productcode) = @_;

  my $developer = $developers->{hex(substr($productcode, 0, 8 ))};
  $hash->{Developer} = $developer->{name} if( defined($developer) );

  my $product = $developer->{devices}->{hex(substr($productcode, 8, 8 ))};
  $hash->{Product} = $product->{label} if( defined($product->{label}) );

  if( defined($developer->{name}) && defined($product->{name}) ) {
    readDeviceXML( $products->{$productcode}, "$attr{global}{modpath}/FHEM/lib/SWAP/$developer->{name}/$product->{name}.xml" );
  } else {
    Log3 $hash->{NAME}, 2, "no device xml found for productcode $productcode";
  }
}

sub
SWAP_Fingerprint($$)
{
  my ($name, $msg) = @_;

  substr( $msg, 2, 2, "--" ); # ignore sender
  substr( $msg, 4, 1, "-" ); # ignore hop count

  return ( "", $msg );
}


sub
SWAP_updateReadings($$$)
{
  my($hash, $rid, $data) = @_;

  return if( !$data );

  my $reg = hex($rid);
  my $name = $hash->{NAME};

  my $register = SWAP_getRegister($hash,$reg);
  if( $hash->{reg} && hex($hash->{reg}) != $reg ) {
    # ignore
  } elsif( defined($register)
           && defined($register->{endpoints} ) ) {
    my $i = 0;
    readingsBeginUpdate($hash);
    #my $nr_endpoints = keys(@{$register->{endpoints}});
    foreach my $endpoint (@{$register->{endpoints}}) {
      my $value = "";
      my $size = $endpoint->{size};
      my $position = 0;
      $position = $endpoint->{position} if( defined($endpoint->{position}) );
      if( $position =~ m/^(\d+)\.(\d+)$/ ) {
        if( $size ne "0.1" ) {
          Log3 $name, 2, "$endpoint->{name}: only single bit endpoints are supported";
          next;
        }

        my $bytes = substr($data, $1*2, 2);
        my $mask = 0x01 << $2;
        $value = "0";
        $value = "1" if( hex($bytes) & $mask );
      } else {
        $value = substr($data, $position*2, $size*2);
      }
      if( $endpoint->{type} == STR ) {
        my $v = "";
        for( my $i = 0; $i < length($value)-6; $i+=2 ) {
          $v .= sprintf( "%c", hex(substr($value, $i, 2)) );
        }
        Log3 $name, 4, "$endpoint->{name}: $v";
        #$value = $v;
        readingsBulkUpdate($hash, lc($endpoint->{name}), $v);
      }
      my $reading = SWAP_regName($rid,$i,$endpoint);
      readingsBulkUpdate($hash, $reading, $value) ;# if( ReadingsVal($name,$reading,"") ne $value );
      ++$i;
    }
    readingsBulkUpdate($hash, "state", (substr($data,0,6) eq "000000"?"off":$data)) if( defined($attr{$name}{ProductCode}) && $attr{$name}{ProductCode} eq '0000002200000003' && $reg == 0x0B );
    readingsBulkUpdate($hash, "state", $data) if( $hash->{reg} && hex($hash->{reg}) == $reg );
    readingsEndUpdate($hash,1);
  } elsif( AttrVal($name, "createUnknownReadings",0 ) )  {
    readingsBeginUpdate($hash);
    readingsBulkUpdate($hash, $rid, $data);
    readingsBulkUpdate($hash, "state", $data) if( $hash->{reg} && hex($hash->{reg}) == $reg );
    readingsEndUpdate($hash,1);
  }
}
sub
SWAP_findFreeAddress($$)
{
  my ($hash, $orig) = @_;

  for( my $i = 0xF0; $i < 0xFF; $i++ ) {
    my $addr = sprintf( "%02X", $i );
    next if( $modules{SWAP}{defptr}{$addr} );

    return $addr;
  }

  return $orig;
}
sub
SWAP_Parse($$)
{
  my ($hash, $msg) = @_;
  my $name = $hash->{NAME};

  return undef if( $msg !~ m/^[\dA-F]{12,}$/ );

  my $dest = substr($msg, 0, 2);
  my $src = substr($msg, 2, 2);
  my $hop = substr($msg, 4, 1);
  my $secu = substr($msg, 5, 1);
  my $nonce = substr($msg, 6, 2);
  my $func = substr($msg, 8, 2);
  my $raddr = substr($msg, 10, 2);
  my $rid = substr($msg, 12, 2);
  my $data = substr($msg, 14);

  my $shash = $modules{SWAP}{defptr}{$src};
  my $dhash = $modules{SWAP}{defptr}{$dest};
  my $rhash = $modules{SWAP}{defptr}{$raddr};

  my $sname = $shash?$shash->{NAME}:$src;
  my $dname = $dest eq "00" ? "broadcast" : ($dhash?$dhash->{NAME}:$dest);
  my $rname = $rhash?$rhash->{NAME}:$raddr;

  my $reg = hex($rid);

  my $regname = $rid;
  #$regname = $default_registers{$reg}->{name} if( defined($default_registers{$reg}) );
  #$regname = $rhash->{product}->{registers}->{$reg}->{name} if( defined($rhash->{product}->{registers}->{$reg}) );

  #device address changed
  if( $reg == 0x09
      && $func == STATUS
      && $raddr ne $data ) {
    Log3 $name, 4, "addr change: ". $raddr ." -> ". $data;

    if( defined( $modules{SWAP}{defptr}{$raddr} ) ) {
      delete( $modules{SWAP}{defptr}{$raddr} );

      my $addr = $data;

      $rhash->{DEF} =~ s/^../$addr/;
      $rhash->{addr} = $addr;
      $rhash->{"SWAP_09-DeviceAddress"} = $addr;

      $modules{SWAP}{defptr}{$addr} = $rhash;
    }

    $raddr = $data;
    $rhash = $modules{SWAP}{defptr}{$raddr};
    $rname = $rhash?$rhash->{NAME}:$raddr;
  }

  if( defined($rhash->{SWAP_nonce})
      && hex($nonce) == hex($rhash->{SWAP_nonce}) ) {
    Log3 $name, 4, "DUP: ". $sname ." -> ". $dname ." ($hop,$secu-$nonce): ". $function_codes{$func} . " ". $rname . " ". $regname . ($data?":":"") . $data;
    return $rname;
  }

  Log3 $name, 4, $sname ." -> ". $dname ." ($hop,$secu-$nonce): ". $function_codes{$func} . " ". $rname . " ". $regname . ($data?":":"") . $data;

  if( $raddr eq "01" and $func == QUERY and $rid eq "0B" and length($data) == 4 ) {
    #Uploading firmware
    my $lineno = hex($data);
    Log3 $name, 4, "Serving firmware request of $src for line no. $lineno";
    if (exists($shash->{HEXFILE})) {
      SWAP_Send($shash, "00", STATUS, "0B", $data.$shash->{HEXFILE}[$lineno] );
    } else {
      Log3 $name, 1, "SWAP device $src is in flash mode, but no hex file is configured. Use 'set $name flash HEXFILE'";
    }
  }


  return $rname if( $raddr eq "01" );
  return $rname if( $func == QUERY );

  if( !$modules{SWAP}{defptr}{$raddr} ) {
    Log3 $name, 3, "SWAP Unknown device $rname, please define it";
    return undef if( $raddr eq "00" );

    $rname = SWAP_findFreeAddress($hash,$raddr) if( $raddr eq "FF" ); #use next free addr as name -> consistent name after change below
    ($developers,$products) = SWAP_loadDevices() if( $reg == 0x00 && defined($modules{"SWAP_$data"}) );
    return "UNDEFINED SWAP_$rname SWAP_$data $raddr $data" if( $reg == 0x00 && defined($modules{"SWAP_$data"}) );
    return "UNDEFINED SWAP_$rname SWAP $raddr $data" if( $reg == 0x00 );
    return "UNDEFINED SWAP_$rname SWAP $raddr";
  }

  $rhash->{SWAP_lastRcv} = TimeNow();

  return $rname if( $func != STATUS );

  #product code
  if( $reg == 0x00 ) {

    my $productcode = $data;
    my $first = !defined($rhash->{"SWAP_00-ProductCode"}) || $rhash->{"SWAP_00-ProductCode"} ne $productcode;

    CommandAttr(undef, "$rname ProductCode $productcode") if( $first );
    CommandSave(undef,undef) if( $first && AttrVal( "autocreate", "autosave", 1 ) );

    if( !defined($products->{$productcode}->{registers}) ){
      SWAP_readDeviceXML( $rhash, $productcode );
    }

    $rhash->{product} = $products->{$productcode} if( defined($productcode) && defined($products->{$productcode} ) );

    if( $first ) {
      my $time = 1+rand(5);
      fhem( "sleep $time; set $rname statusRequest" );
    } else {
      SWAP_Send($rhash, $rhash->{addr}, QUERY, "01" );
      SWAP_Send($rhash, $rhash->{addr}, QUERY, "02" );
    }
  }

  my @list;
  push(@list, $rname);

  if( $reg <= 0x0A ) {
    if( defined( $default_registers{$reg}->{endpoints} ) ) {
      my $i = 0;
      foreach my $endpoint (@{$default_registers{$reg}->{endpoints}}) {
        my $position = 0;
        $position = $endpoint->{position} if( defined($endpoint->{position}) );
        my $value = substr($data, $position*2, $endpoint->{size}*2);
        $rhash->{"SWAP_".SWAP_regName($rid,$i,$endpoint)} = $value;
        ++$i;
      }
    } else {
      $rhash->{"SWAP_".$rid."-".$default_registers{$reg}->{name}} = $data;
    }

    if( $reg == 0x03 ) {
      $data = $system_state{$data} if( defined($system_state{$data}) );
      DoTrigger( $rname, "$default_registers{$reg}->{name}: $data" );
    
    } elsif( $reg == 0x09
        && $data eq "FF" ) {
      my $addr = SWAP_findFreeAddress($hash,$data);
      if( $addr ne $data ) {
        Log3 $rname, 3, "SWAP $rname: changing 09-DeviceAddress from default $data to $addr";
        SWAP_Set( $rhash, $rname, "regSet", "09", "$addr" ); #device should already have consistent name from autocreate above
      }
    } elsif( $reg == 0x0A
             && $data eq "FFFF"
             && $rhash->{product}->{pwrdownmode} == 1 ) {
      Log3 $rname, 3, "SWAP $rname: changing 0A-PeriodicTxInterval from default FFFF to 0384 (900 seconds)";
      SWAP_Set( $rhash, $rname, "regSet", "0A", "0384" );

    }
  } else {
    SWAP_updateReadings( $rhash, $rid, $data );

    if( my $rhash = $modules{SWAP}{defptr}{$raddr.".".$rid} ) {
      push(@list, $rhash->{NAME});

      if( my $parse = $modules{$rhash->{TYPE}}{SWAP_ParseFn} ) {
        no strict "refs";
        &{$parse}($rhash,$reg,$func,$data);
        use strict "refs";
      }

      SWAP_updateReadings( $modules{SWAP}{defptr}{$raddr.".".$rid}, $rid, $data );
    }
  }

  if( my $parse = $modules{$rhash->{TYPE}}{SWAP_ParseFn} ) {
    no strict "refs";
    &{$parse}($rhash,$reg,$func,$data);
    use strict "refs";
  }

  if( !defined($rhash->{SWAP_nonce})
      || hex($nonce) < hex($rhash->{SWAP_nonce}) ) {
    delete( $rhash->{SWAP_MISSED} );
  } elsif( !defined($rhash->{SWAP_MISSED}) ) {
    $rhash->{SWAP_MISSED} = 0;
  } else {
    $rhash->{SWAP_MISSED} += hex($nonce) - hex($rhash->{SWAP_nonce}) - 1;
  }
  $rhash->{SWAP_nonce} = $nonce;

  if( $reg == 0x03
      && $data eq "03" ) {
    SWAP_ProcessCmdStack( $rhash );
  }

  if($rhash->{sentList}){
    my $size = scalar @{$rhash->{sentList}};
    for( my $i = $size-1; $i >= 0; --$i ) {
      my $params = $rhash->{sentList}->[$i];
      if( $params->[0] eq $rhash->{addr}
          && $params->[2] eq $rid ) {
          splice @{$rhash->{sentList}}, $i, 1;
      }
    }

    $rhash->{SWAP_Sent_unconfirmed} = scalar @{$rhash->{sentList}}." Sent_unconfirmed";
  } else {
    delete ($rhash->{SWAP_Sent_unconfirmed});
  }

  return @list;
}
sub
SWAP_Send($$$@)
{
  my ($hash, $dest, $func, $reg, $data) = @_;

  $hash = $modules{SWAP}{defptr}{$hash->{addr}} if( $hash->{reg} );

  $hash->{SWAP_lastSend} = TimeNow();

  my @arr = ();
  $hash->{sentList} = \@arr if(!$hash->{sentList});

  push(@{$hash->{sentList}}, [$dest, $func, $reg, $data]);
  $hash->{SWAP_Sent_unconfirmed} = scalar @{$hash->{sentList}}." Sent_unconfirmed";

  my $nonce = 0;
  if( $func != QUERY ) {
    $nonce = $hash->{IODev}->{nonce};
    $hash->{nonce}++;
    $hash->{nonce} &= 0xFF;
  }

  IOWrite( $hash, $dest, "00". sprintf( "%02X", $nonce) . $func . $dest . $reg ) if( !defined($data) );
  IOWrite( $hash, $dest, "00". sprintf( "%02X", $nonce) . $func . $dest . $reg . $data ) if( $data );

  $hash->{IODev}->{nonce} = $nonce if( $func != QUERY );
}
sub
SWAP_PushCmdStack($$$@)
{
  my ($hash, $dest, $func, $reg, $data) = @_;
  #my $name = $hash->{NAME};

  my @arr = ();
  $hash->{cmdStack} = \@arr if(!$hash->{cmdStack});

  push(@{$hash->{cmdStack}}, [$dest, $func, $reg, $data]);
  $hash->{SWAP_CMDsPending} = scalar @{$hash->{cmdStack}}." CMDs_pending";
}
sub
SWAP_ProcessCmdStack($)
{
  my ($hash) =  @_;
  #my $name = $hash->{NAME};

  my $sent;
  if($hash->{cmdStack}) {
    if(@{$hash->{cmdStack}}) {
      my $params = shift @{$hash->{cmdStack}};
      SWAP_Send($hash, $params->[0], $params->[1], $params->[2], $params->[3]);
      $sent = 1;
      $hash->{SWAP_CMDsPending} = scalar @{$hash->{cmdStack}}." CMDs_pending";
    } elsif(!@{$hash->{cmdStack}}) {
      delete($hash->{cmdStack});
      delete($hash->{SWAP_CMDsPending});
    }
  }

  return $sent;
}


sub
SWAP_Attr(@)
{
  my ($cmd, $name, $attrName, $attrVal) = @_;

  if( $cmd eq "set" && $attrName eq "ProductCode" && defined($attrVal) ) {
    my $hash = $defs{$name};
    my $productcode = $attrVal;

    #Product code changed (due to flash of different firmware or switch of addresses)
    if( defined( $attr{$name}{ProductCode} ) && $attr{$name}{ProductCode} ne $productcode) {
      my $oldproductcode = "None";
      $oldproductcode = $attr{$name}{ProductCode} if( defined( $attr{$name}{ProductCode} ) );
      Log3 $name, 3, "Device $name changed product code from $oldproductcode to $productcode";
      #Delete all SWAP_HEX-
      foreach my $key (keys %{$hash}) {
        if ($key =~ "^SWAP_[0-9A-F][0-9A-F]-") {
          Log3 $name, 5, "Deleting $key";
          delete $hash->{$key};
        }
      }

      #Delete all readings
      foreach my $key (keys %{$hash->{READINGS}}) {
        Log3 $name, 5, "Deleting reading $key";
        delete $hash->{READINGS}{$key};
      }
    }

    if( !defined($products->{$productcode}->{registers}) ){
      SWAP_readDeviceXML( $hash, $productcode );
    }

    $hash->{product} = $products->{$productcode} if( defined($productcode) && defined($products->{$productcode} ) );

    if( !defined($attr{$name}{userReadings})
        && defined($hash->{product}->{registers} ) ) {
      my $str;

      foreach my $reg ( sort { $a <=> $b } keys ( %{$hash->{product}->{registers}} ) ) {
        next if( $hash->{reg} && hex($hash->{reg}) != $reg );
        my $register = SWAP_getRegister($hash,$reg);
        next if( !defined($register) );

        my $i = 0;
        foreach my $endpoint ( @{$register->{endpoints}} ) {
          if( $endpoint->{units} ) {
            my $factor = $endpoint->{units}->[0]->{factor} if( defined($endpoint->{units}->[0]->{factor}) );
            my $offset = $endpoint->{units}->[0]->{offset} if( defined($endpoint->{units}->[0]->{offset}) );
            my $func = "";
            $func .= "*$factor" if( defined($factor) && $factor != 1 );
            $func .= "+$offset" if( defined($offset) && $offset > 0 );
            $func .= "$offset" if( defined($offset) && $offset < 0 );

            $str .= ", " if( $str );
            my $regname = SWAP_regName(sprintf("%02X",$reg),$i,$endpoint);
            $str .= lc($endpoint->{name}) .":". $regname .".* ". "{hex(ReadingsVal(\$name,\"$regname\",\"0\"))$func}";
          }
          ++$i;
        }
      }

      CommandAttr(undef, "$name userReadings $str") if( $str );
    }

  }

  return undef;
}

1;

=pod
=item summary    generic module for SWAP devices
=item summary_DE generisches Modul für SWAP Ger&auml;te
=begin html

<a name="SWAP"></a>
<h3>SWAP</h3>
<ul>
  The SWAP protocoll is used by panStamps (<a href="http://www.panstamp.com">panstamp.com</a>).<br><br>

  This is a generic module that will handle all SWAP devices with known device description files via
  a <a href="#panStamp">panStick</a> as the IODevice.<br><br>

  All communication is done on the SWAP register level. FHEM readings are created for all user registers
  and userReadings are created to map low level SWAP registers to 'human readable' format with the
  mapping from the device descriprion files.<br><br>

  For higher level features like "on,off,on-for-timer,..." specialized modules have to be used.<br><br>

  Messages for devices in power-down-state are queued and send when the device enters SYNC state.
  This typicaly happens during device startup after a reset.

  <br><br>
  Notes:
  <ul>
    <li> This module requires XML::Simple.</li>
    <li>Devices with the default address FF will be changed to the first free address in the range F0-FE.</li>
    <li>For power-down devices the default transmit interval of FFFF will be changed to 0384 (900 seconds).</li>
  </ul>

  <br>
  <br>

  <a name="SWAPDefine"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; SWAP &lt;ID&gt;</code> <br>
    <br>
    The ID is a 2 digit hex number to identify the moth in the panStamp network.
  </ul>
  <br>

  <a name="SWAP_Set"></a>
  <b>Set</b>
  <ul>
    <li>regGet &lt;reg&gt;<br>
        request status message for register id &lt;reg&gt;.
        for system registers the register name can be used instead if the two digit register id in hex.
        </li><br>

    <li>regSet &lt;reg&gt; &lt;data&gt;<br>
        write &lt;data&gt; to register id &lt;reg&gt;.
        for system registers the register name can be used instead if the twi digit register id in hex.
        </li><br>

    <li>regSet &lt;reg&gt;.&lt;ep&gt &lt;data&gt;<br>
        write &lt;data&gt; to endpoint &lt;ep&gt of register &lt;reg&gt;. will not work if no reading for register &lt;reg&gt; is available as all nibbles that are not part of endpoint &lt;ep&gt will be filled from this reading.
        </li><br>

    <li>statusRequest<br>
        request transmision of all registers.
        </li><br>
    <li>readDeviceXML<br>
        reload the device description xml file.
        </li><br>
    <li>clearUnconfirmed<br>
        clears the list of unconfirmed messages.
        </li><br>
    <li>flash [&lt;productCode&gt|&lt;firmwareFile&gt;]<br>
        will initiate an ota firmware update. only possible for panStamp NRG devices.<br>
        no params -> will use the <code>SWAP_&lt;current productCode&gt;.hex</code> file from the FHEM/firmware directory.<br>
        &lt;productCode&gt -> will use the <code>SWAP_&lt;productCode&gt;.hex</code> file from the FHEM/firmware directory.<br>
        &lt;firmwareFile&gt; -> will use &lt;firmwareFile&gt; as the absolute file name of the hex file.<br>
        </li><br>
  </ul>

  <a name="SWAP_Get"></a>
  <b>Get</b>
  <ul>
    <li>regList<br>
        list all non-system registers of this device.
        </li><br>
    <li>regListAll<br>
        list all registers of this device.
        </li><br>
    <li>listUnconfirmed<br>
        list all unconfirmed messages.
        </li><br>
    <li>products<br>
        dumps all known devices.
        </li><br>
    <li>deviceXML<br>
        dumps the device xml data.
        </li><br>
  </ul>

  <a name="SWAP_Attr"></a>
  <b>Attributes</b>
  <ul>
    <li>createUnknownReadings<br>
        Create readings for unknown registers, i.e. registers not defined in the device xml file.
        </li><br>
    <li>ProductCode<br>
        ProductCode of the device. used to read the register configuration from the device definition file.
        hast to be set manualy for devices that are in sleep mode during definition.
        </li><br>
  </ul>
  <br>
</ul>

=end html
=cut
