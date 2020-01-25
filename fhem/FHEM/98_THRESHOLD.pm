##############################################
#     $Id: 98_THRESHOLD.pm 14179 2017-05-03 20:10:16Z Damian $
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
##############################################################################


package main;
use strict;
use warnings;

sub THRESHOLD_setValue($$);

##########################
sub
THRESHOLD_Initialize($)
{
  my ($hash) = @_;
  $hash->{DefFn}   = "THRESHOLD_Define";
  $hash->{SetFn}   = "THRESHOLD_Set";
  $hash->{AttrFn}   = "THRESHOLD_Attr";
  $hash->{NotifyFn} = "THRESHOLD_Notify";
  $hash->{AttrList} = "disable:0,1 loglevel:0,1,2,3,4,5,6 state_format state_cmd1_gt state_cmd2_lt target_func number_format setOnDeactivated:cmd1_gt,cmd2_lt desiredActivate:0,1";
}


##########################
sub
THRESHOLD_Define($$$)
{
  my ($hash, $def) = @_;
  my @b =split (/\|/,$def);
  my @a = split("[ \t][ \t]*", $b[0]);
  my $cmd1_gt="";
  my $cmd2_lt="";
  my $cmd_default=0;
  my $actor;
  my $init_desired_value;
  my $target_sensor;
  my $target_reading;
  my $offset=0;
  my $pn = $a[0];
    
  if (@b > 6 || @a < 3 || @a > 6) {
    my $msg = "wrong syntax: define <name> THRESHOLD " .
               "<sensor>:<reading1>:<hysteresis>:<target_value>:<offset> AND|OR <sensor2>:<reading2>:<state> ".
         "<actor>|<cmd1_gt>|<cmd2_lt>|<cmd_default_index>|<state_cmd1_gt>:<state_cmd2_lt>|state_format";
    Log3 $pn,2, $msg;
    return $msg if ($init_done);
  } 
  
  # Sensor
  my ($sensor, $reading, $hysteresis,$s4,$s5,$s6) = split(":", $a[2], 6);
  
  if(!$defs{$sensor}) {
    my $msg = "$pn: Unknown sensor device $sensor specified";
    Log3 $pn,2, $msg;
    return $msg if ($init_done);
  }
  
  $reading = "temperature" if (!defined($reading));
   
  if (!defined($hysteresis) or ($hysteresis eq "")) {
    if ($reading eq "temperature" or $reading eq "temp") {
      $hysteresis=1;
    } elsif ($reading eq "humidity") {
        $hysteresis=10;
      } else {
        $hysteresis=0;
      }
  } elsif ($hysteresis !~ m/^[\d\.]*$/ ) {
      my $msg = "$pn: value:$hysteresis, hysteresis needs a numeric parameter";
      Log3 $pn,2, $msg;
      return $msg if ($init_done);
  }	
  if (defined($s6)) { # target_sensor:target_reading:offset
    $target_sensor=$s4;
    $target_reading=$s5;
    $offset=$s6;
  } elsif (defined($s5)) { # init_desired_value:offset or target_sensor:offset or target_sensor:target_reading
      if ($s5 =~ m/^[-\d\.]*$/) { # offset
        $offset=$s5;
      } else { # target_reading
          $target_reading=$s5;
      }
      if ($s4 =~ m/^[-\d\.]*$/) { # init_desired_value
        $init_desired_value=$s4;
      } else { # target_sensor
          $target_sensor=$s4;
      }
    } elsif (defined($s4)) { # target_sensor or init_desired_value
        if ($s4 =~ m/^[-\d\.]*$/) { # init_desired_value
          $init_desired_value=$s4;
        } else { # target_sensor
          $target_sensor=$s4;
          $target_reading="temperature";
        }
      }
  if (defined($target_sensor)) {
    if (!$defs{$target_sensor}) {
        my $msg = "$pn: Unknown sensor device $target_sensor specified";
        Log3 $pn,2, $msg;
        return $msg if ($init_done);
    } 
  }
 
# Modify DEF 
  if ($hash->{sensor})
  {
    delete $hash->{sensor};
    delete $hash->{sensor_reading};
    delete $hash->{hysteresis};
    delete $hash->{target_sensor};
    delete $hash->{target_reading};
    delete $hash->{init_desired_value};
    delete $hash->{offset};
    delete $hash->{cmd1_gt};
    delete $hash->{cmd2_lt};
    delete $hash->{cmd_default};
    delete $hash->{STATE};
    delete $hash->{operator};
    delete $hash->{sensor2};
    delete $hash->{sensor2_reading};
    delete $hash->{sensor2_state};
  }
 
 # Sensor2
  
  if (defined($a[3])) {
    my $operator=$a[3];
    if (($operator eq "AND") or ($operator eq "OR")) {
      my ($sensor2, $sensor2_reading, $state) = split(":", $a[4], 3);
      if (defined ($sensor2)) {
        if(!$defs{$sensor2}) {
        my $msg = "$pn: Unknown sensor2 device $sensor2 specified";
        Log3 $pn,2, $msg;
        return $msg if ($init_done);
        }
      } 
      $sensor2_reading = "state" if (!defined ($sensor2_reading));
      $state = "open" if (!defined ($state));
      $hash->{operator} = $operator;
      $hash->{sensor2} = $sensor2;
      $hash->{sensor2_reading} = $sensor2_reading;
      $hash->{sensor2_state} = $state;
      $actor = $a[5];
    } else {
      $actor = $a[3];
    }
  }
  if (defined ($actor)) {
    if (!$defs{$actor}) {
       my $msg = "$pn: Unknown actor device $actor specified";
       Log3 $pn,2, $msg;
       return $msg if ($init_done);
    }
  }
  if (@b == 1) { # no actor parameters
    if (!defined($actor)) {
       $attr{$pn}{state_cmd1_gt}="off";
       $attr{$pn}{state_cmd2_lt}="on";
       $attr{$pn}{state_format} = "_sc";
       $hysteresis = 0 if (!$hysteresis);
       $cmd_default = 0;
    } else {
      $cmd1_gt = "set $actor off";
      $cmd2_lt = "set $actor on";
      $attr{$pn}{state_cmd1_gt}="off";
      $attr{$pn}{state_cmd2_lt} = "on";
      $cmd_default = 2;
      $attr{$pn}{state_format} = "_m _dv _sc";
      $attr{$pn}{number_format} = "%.1f";
    }
  } else { # actor parameters 
    $cmd1_gt = $b[1] if (defined($b[1]));
    $cmd2_lt = $b[2] if (defined($b[2]));
    $cmd_default = (!($b[3])) ? 0 : $b[3];
    if ($cmd_default !~ m/^[0-2]$/ ) {
         my $msg = "$pn: value:$cmd_default, cmd_default_index needs 0,1,2";
         Log3 $pn,2, $msg;
         return $msg if ($init_done);
    }
    if (defined($b[4])) {
      my ($st_cmd1_gt, $st_cmd2_lt) = split(":", $b[4], 2);
      $attr{$pn}{state_cmd1_gt} = $st_cmd1_gt if (defined($st_cmd1_gt));
      $attr{$pn}{state_cmd2_lt} = $st_cmd2_lt if (defined($st_cmd2_lt));
      $attr{$pn}{state_format} = "_sc";
    }
     
    if (defined($b[5])) {
      $attr{$pn}{state_format} = $b[5];
    } elsif (defined($b[4])){
       $attr{$pn}{state_format} = "_sc";
      } else {
          $attr{$pn}{state_format} = "_m _dv";
          $attr{$pn}{number_format} = "%.1f";
        }
    
  }
  if (defined($actor)) {
    $cmd1_gt =~ s/@/$actor/g;
    $cmd2_lt =~ s/@/$actor/g;
  }
  
  $hash->{sensor} = $sensor;
  $hash->{sensor_reading} = $reading;
  $hash->{hysteresis} = $hysteresis;
  $hash->{target_sensor} = $target_sensor if (defined ($target_sensor));
  $hash->{target_reading} = $target_reading if (defined ($target_reading));
  $hash->{init_desired_value} = $init_desired_value if (defined ($init_desired_value));
  $hash->{offset} = $offset;
  $hash->{cmd1_gt} = SemicolonEscape($cmd1_gt);
  $hash->{cmd2_lt} = SemicolonEscape($cmd2_lt);
  $hash->{cmd_default} = $cmd_default;
  $hash->{STATE} = 'initialized';
  if (defined ($init_desired_value) or defined ($target_sensor)) {
    readingsBeginUpdate  ($hash);
    if (defined ($init_desired_value))
    {
      my $mode="active";
      readingsBulkUpdate   ($hash, "threshold_min", $init_desired_value-$hysteresis+$offset);
      readingsBulkUpdate   ($hash, "threshold_max", $init_desired_value+$offset);
      readingsBulkUpdate   ($hash, "cmd","wait for next cmd");
      readingsBulkUpdate   ($hash, "desired_value", $init_desired_value);
      readingsBulkUpdate   ($hash, "mode", $mode);
    }
    if (defined ($target_sensor))
    {
      my $mode="external";
      readingsBulkUpdate   ($hash, "cmd", "wait for next cmd");
      readingsBulkUpdate   ($hash, "mode",$mode);
    }
    readingsEndUpdate    ($hash, 1);
#    my $msg = THRESHOLD_Check($hash);
#    if ($msg ne "") {
#      return $msg;
#    }
  }  
  return undef;
}

##########################
sub
THRESHOLD_Set($@)
{
  my ($hash, @a) = @_;
  my $pn = $hash->{NAME};
  my $ret="";
  return "$pn, need a parameter for set" if(@a < 2);
  my $arg = $a[1];
  my $value = (defined $a[2]) ? $a[2] : "";
  my $desired_value = ReadingsVal($pn,"desired_value","");
  my $target_sensor =
  my $offset = $hash->{offset};
  my $mode;
  my $state_format = AttrVal($pn, "state_format", "_m _dv");
  my $cmd = AttrVal($pn, "setOnDeactivated", "");
  if ($arg eq "desired" ) {
    return "$pn: set desired value:$value, desired value needs a numeric parameter" if(@a != 3 || $value !~ m/^[-\d\.]*$/);
    
    if ($desired_value ne "") {
      return $ret if ($desired_value == $value);
    }
    Log3 $pn,2, "set $pn $arg $value";
    $mode = "active";
    $state_format =~ s/\_m/$mode/g;
    $state_format =~ s/\_dv/$value/g;
    $state_format =~ s/\_s1v//g;
    $state_format =~ s/\_s2s//g;
    $state_format =~ s/\_sc//g;
    $ret=CommandDeleteAttr(undef, "$pn disable") if (AttrVal($pn, "desiredActivate", ""));
    readingsBeginUpdate  ($hash);
    if (!AttrVal($pn, "disable", "")) {
      readingsBulkUpdate   ($hash, "mode", $mode);
      readingsBulkUpdate   ($hash, "state", $state_format) if (!($state_format =~/^[ ]*$/));
    }
    readingsBulkUpdate   ($hash, "cmd","wait for next cmd");
    readingsBulkUpdate   ($hash, "threshold_min",$value-$hash->{hysteresis}+$offset);
    readingsBulkUpdate   ($hash, "threshold_max", $value+$offset);
    readingsBulkUpdate   ($hash, "desired_value", $value);
    readingsEndUpdate    ($hash, 1);
    return THRESHOLD_Check($hash) if (!AttrVal($pn, "disable", ""));
  } elsif ($arg eq "deactivated" ) {
      $cmd = $value if ($value ne "");
      if ($cmd ne "") {
        if ($cmd eq "cmd1_gt" ) {
            readingsBeginUpdate  ($hash);
            THRESHOLD_setValue   ($hash,1);
            THRESHOLD_set_state  ($hash);
            readingsEndUpdate    ($hash, 1);
        } elsif ($cmd eq "cmd2_lt" ) {
            readingsBeginUpdate  ($hash);
            THRESHOLD_setValue   ($hash,2);
            THRESHOLD_set_state  ($hash);
            readingsEndUpdate    ($hash, 1);
          } else {
            return "$pn: set deactivated: $cmd, unknown command, use: cmd1_gt or cmd2_lt";
          }
      } 
      $ret=CommandAttr(undef, "$pn disable 1");   
  } elsif ($arg eq "active" ) {
      return "$pn: set active, set desired value first" if ($desired_value eq "");
      $ret=CommandDeleteAttr(undef, "$pn disable");
      return THRESHOLD_Check($hash);
  } elsif ($arg eq "external" ) {
      $ret=CommandDeleteAttr(undef, "$pn disable");
      if (!$ret) {
        return "$pn: no target_sensor defined" if (!$hash->{target_sensor});
        $mode="external";
        readingsBeginUpdate  ($hash);
        $state_format =~ s/\_m/$mode/g;
        $state_format =~ s/\_dv//g;
        $state_format =~ s/\_s1v//g;
        $state_format =~ s/\_s2s//g;
        $state_format =~ s/\_sc//g;
        readingsBulkUpdate   ($hash, "mode", $mode);
        readingsBulkUpdate   ($hash, "state", $state_format) if (!($state_format =~/^[ ]*$/));
        readingsBulkUpdate   ($hash, "cmd","wait for next cmd");
        readingsEndUpdate    ($hash, 1);
        return THRESHOLD_Check($hash);
      }
  } elsif ($arg eq "hysteresis" ) {
      return "$pn: set hysteresis value:$value, hysteresis needs a numeric parameter" if (@a != 3  || $value !~ m/^[\d\.]*$/ );
      $hash->{hysteresis} = $value;
      if ($desired_value ne "") {
        readingsBeginUpdate  ($hash);
        readingsBulkUpdate   ($hash, "threshold_min",$desired_value-$hash->{hysteresis}+$offset);
        readingsBulkUpdate   ($hash, "threshold_max", $desired_value+$offset);
        readingsBulkUpdate   ($hash, "cmd","wait for next cmd");
        readingsEndUpdate    ($hash, 1);
        return THRESHOLD_Check($hash);
      }
  } elsif ($arg eq "offset" ) {
      return "$pn: set offset value:$value, offset needs a numeric parameter" if (@a != 3  || $value !~ m/^[-\d\.]*$/ );
      $offset = $value;
      $hash->{offset} = $offset;
      if ($desired_value ne "") {
        readingsBeginUpdate  ($hash);
        readingsBulkUpdate   ($hash, "threshold_min",$desired_value-$hash->{hysteresis}+$offset);
        readingsBulkUpdate   ($hash, "threshold_max", $desired_value+$offset);
        readingsBulkUpdate   ($hash, "cmd","wait for next cmd");
        readingsEndUpdate    ($hash, 1);
        return THRESHOLD_Check($hash);
      }
  } elsif ($arg eq "cmd1_gt" ) {
          readingsBeginUpdate  ($hash);
          THRESHOLD_setValue   ($hash,1);
          THRESHOLD_set_state  ($hash);
          readingsEndUpdate    ($hash, 1);
  } elsif ($arg eq "cmd2_lt" ) {
          readingsBeginUpdate  ($hash);
          THRESHOLD_setValue   ($hash,2);
          THRESHOLD_set_state  ($hash);
          readingsEndUpdate    ($hash, 1);
  }  else {
        return "$pn: unknown argument $a[1], choose one of desired active external deactivated hysteresis offset cmd1_gt cmd2_lt"
          }
  return $ret;
}

##########################
sub
THRESHOLD_Notify($$)
{
  my ($hash, $dev) = @_;
  my $pn = $hash->{NAME};
  return "" if($attr{$pn} && $attr{$pn}{disable});
  my $name = $dev->{NAME};
  my $sensor = $hash->{sensor};
  my $target_sensor = $hash->{target_sensor};
  my $sensor2 = $hash->{sensor2};
 
  SELECT:{
  if (($name eq $sensor) and (ReadingsVal($pn,"desired_value","") ne "")) {last SELECT;}
    if ($sensor2) {
      if (($name eq $sensor2) and (ReadingsVal($pn,"desired_value","") ne "")) {last SELECT;}
    }
    if ($target_sensor) {
      if (ReadingsVal($pn,"mode","") eq "external") { 
        if ($name eq $target_sensor) {last SELECT;}
      }
    }  
    return "";
  }
 return THRESHOLD_Check($hash);
 #return THRESHOLD_Check(@_);
}

##########################
sub
THRESHOLD_Check($)
{
  my ($hash) = @_;
  my $pn = $hash->{NAME};
 
  return "" if (AttrVal($pn, "disable", ""));
 
  my $sensor = $hash->{sensor};
  my $reading = $hash->{sensor_reading};
  my $target_sensor = $hash->{target_sensor};
  my $target_reading = $hash->{target_reading};
  my $sensor2 = $hash->{sensor2};
  my $reading2 = $hash->{sensor2_reading};
  my $s_value;
  my $t_value;
  my $sensor_max;
  my $sensor_min;
  
  if (!($defs{$sensor}{READINGS}{$reading})) {
    my $msg = "$pn: no reading yet for $sensor $reading";
    Log3 $pn,2, $msg;
    return"";
  } else {
    my $instr = $defs{$sensor}{READINGS}{$reading}{VAL};
    $instr =~  /[^\d^\-^.]*([-\d.]*)/;
    $s_value = $1;
  }
  if ($sensor2) {
    if (!($defs{$sensor2}{READINGS}{$reading2})) {
      my $msg = "$pn: no reading yet for $sensor2 $reading2";
      Log3 $pn,2, $msg;
      return"";
    }
  }
  my $mode = ReadingsVal($pn,"mode","");

  #compatibility hack
  if (!$mode) {
    my $desired_value = ReadingsVal($pn,"desired_value","");
    $mode="active";
    my $state_format = AttrVal($pn, "state_format", "_m _dv");
    $state_format =~ s/\_m/$mode/g;
    $state_format =~ s/\_dv/$desired_value/g;
    $state_format =~ s/\_s1v//g;
    $state_format =~ s/\_s2s//g;
    $state_format =~ s/\_sc//g;
    readingsBeginUpdate ($hash);
    readingsBulkUpdate  ($hash, "state", $state_format) if ($state_format);
    readingsBulkUpdate  ($hash, "threshold_min", $desired_value-$hash->{hysteresis}+$hash->{offset});
    readingsBulkUpdate  ($hash, "threshold_max", $desired_value+$hash->{offset});
    readingsBulkUpdate  ($hash, "mode", $mode);
    readingsEndUpdate   ($hash, 1);
  }
  
  if (($target_reading) && $mode eq "external")
  {
    if (!($defs{$target_sensor}{READINGS}{$target_reading})) {
      my $msg = "$pn: no reading yet for $target_sensor $target_reading";
      Log3 $pn,2, $msg;
      return"";
    } else {
      my $instr = $defs{$target_sensor}{READINGS}{$target_reading}{VAL};
      $instr =~  /[^\d^\-^.]*([-\d.]*)/;
      $t_value = $1;
      my $target_func = AttrVal($pn, "target_func", "");
      if ($target_func)
      {
        $target_func =~ s/\_tv/$t_value/g;
        my $ret = eval $target_func;
        if ($@) {
          my $msg = "$pn: error in target_func: $target_func, ".$@;
          Log3 $pn,2, $msg;
          return"";
        }
        $t_value=$ret;
      }
      $sensor_max = $t_value+$hash->{offset};
      $sensor_min = $t_value-$hash->{hysteresis}+$hash->{offset};
    }  
  }
  
  readingsBeginUpdate ($hash);
  readingsBulkUpdate  ($hash, "sensor_value",$s_value) if (defined($s_value) and ($s_value ne ReadingsVal($pn,"sensor_value","")));
  readingsBulkUpdate  ($hash, "desired_value",$t_value) if (defined($t_value) and ($t_value ne ReadingsVal($pn,"desired_value","")));
  
  if (defined ($sensor_max)) {
    readingsBulkUpdate  ($hash, "threshold_max",$sensor_max) if ($sensor_max ne ReadingsVal($pn,"threshold_max",""));
  } else {
    $sensor_max = ReadingsVal($pn,"threshold_max","");
  }
  if (defined ($sensor_min)) {
    readingsBulkUpdate  ($hash, "threshold_min",$sensor_min) if ($sensor_min ne ReadingsVal($pn,"threshold_min",""));
  } else {
    $sensor_min = ReadingsVal($pn,"threshold_min","");
  }
  
  my $cmd_now="";  
  if (($sensor_min ne "") and ($sensor_max ne "") and ($s_value ne ""))
  {
      my $cmd_default = $hash->{cmd_default};
      if (!$hash->{operator}) {
        if ($s_value > $sensor_max) {
          THRESHOLD_setValue($hash,1);
        } elsif ($s_value < $sensor_min) {
            THRESHOLD_setValue($hash,2);
        } else {
            THRESHOLD_setValue($hash,$cmd_default) if (ReadingsVal($pn,"cmd","") eq "wait for next cmd" && $cmd_default != 0);
        }
      } else {
              my $s2_state = $defs{$sensor2}{READINGS}{$reading2}{VAL};
            my $sensor2_state = $hash->{sensor2_state};
            readingsBulkUpdate  ($hash, "sensor2_state",$s2_state) if ($s2_state ne ReadingsVal($pn,"sensor2_state",""));  

            if ($hash->{operator} eq "AND") {
              if (($s_value > $sensor_max) && ($s2_state eq $sensor2_state)) {
                THRESHOLD_setValue($hash,1);
            } elsif (($s_value < $sensor_min)  || ($s2_state ne $sensor2_state)){
                THRESHOLD_setValue($hash,2);
              } else {
                  THRESHOLD_setValue($hash,$cmd_default) if (ReadingsVal($pn,"cmd","") eq "wait for next cmd" && $cmd_default != 0);
                }
            } elsif ($hash->{operator} eq "OR") {
                if (($s_value > $sensor_max) || ($s2_state eq $sensor2_state)) {
                  THRESHOLD_setValue($hash,1);
                } elsif (($s_value < $sensor_min)  && ($s2_state ne $sensor2_state)){
                    THRESHOLD_setValue($hash,2);
                  } else {
                      THRESHOLD_setValue($hash,$cmd_default) if (ReadingsVal($pn,"cmd","") eq "wait for next cmd" && $cmd_default != 0);
                    }
              }
        }
  }
  THRESHOLD_set_state ($hash);
  readingsEndUpdate   ($hash, 1);
  return "";
}

sub
THRESHOLD_Attr(@)
{
  my @a = @_;
  my $hash = $defs{$a[1]};

  if($a[0] eq "set" && $a[2] eq "disable")
  {
    if($a[3] eq "0") {
      readingsBeginUpdate ($hash);
      readingsBulkUpdate  ($hash, "state", "initialized");
      readingsBulkUpdate  ($hash, "mode", "active");
      readingsBulkUpdate  ($hash, "cmd","wait for next cmd");
      readingsEndUpdate   ($hash, 1);
      return THRESHOLD_Check($hash);
    } elsif($a[3] eq "1") {
      readingsBeginUpdate ($hash);
      readingsBulkUpdate  ($hash, "state", "disabled");
      readingsBulkUpdate  ($hash, "mode", "deactivated");
      readingsEndUpdate   ($hash, 1);
    }
  } elsif($a[0] eq "del" && $a[2] eq "disable") {
      readingsBeginUpdate ($hash);
      readingsBulkUpdate  ($hash, "state", "initialized");
      readingsBulkUpdate  ($hash, "mode", "active");
      readingsBulkUpdate   ($hash, "cmd","wait for next cmd");
      readingsEndUpdate   ($hash, 1);
      return THRESHOLD_Check($hash);
  }
  return undef;
} 

sub 
THRESHOLD_set_state($)
{
    my ($hash) = @_;
    my $pn=$hash->{NAME};
    my $state_old = ReadingsVal($pn, "state","");
    my $mode  = ReadingsVal($pn,"mode","");
    my $desired_value = ReadingsVal($pn,"desired_value","");
    my $sensor_value = ReadingsVal($pn,"sensor_value","");
    my $sensor2_state = ReadingsVal($pn,"sensor2_state","");
    my $cmd = ReadingsVal($pn,"cmd","");
#	my %h_state_cmd = (cmd1_gt=>state_cmd1_gt, cmd2_lt=>state_cmd2_lt);
    my $state_cmd = AttrVal ($pn, "state_".$cmd,"");
    my $state_format = AttrVal($pn, "state_format", "_m _dv");
    my $number_format = AttrVal($pn, "number_format", "");
    if ($number_format ne "") {
      $desired_value =sprintf($number_format,$desired_value) if ($desired_value ne "");
      $sensor_value =sprintf($number_format,$sensor_value) if ($sensor_value ne "");
    }     
    $state_format =~ s/\_m/$mode/g;
    $state_format =~ s/\_dv/$desired_value/g;
    $state_format =~ s/\_s1v/$sensor_value/g;
    $state_format =~ s/\_s2s/$sensor2_state/g;
    $state_format =~ s/\_sc/$state_cmd/g;
    if (($state_format) and ($state_old ne $state_format)) {
      readingsBulkUpdate ($hash, "state", $state_format);
    }
}

sub
THRESHOLD_setValue($$)
{
  my ($hash, $cmd_nr) = @_;
  my $pn = $hash->{NAME};
  my @cmd_sym = ("cmd1_gt","cmd2_lt");
  my $cmd_sym_now = $cmd_sym[$cmd_nr-1];

  if (ReadingsVal($pn,"cmd","") ne $cmd_sym_now) {
    my $ret=0;
    my @cmd =($hash->{cmd1_gt},$hash->{cmd2_lt});
    my @state_cmd = (AttrVal($pn,"state_cmd1_gt",""),AttrVal($pn,"state_cmd2_lt",""));
    my $cmd_now = $cmd[$cmd_nr-1];
    my $state_cmd_now = $state_cmd[$cmd_nr-1];
      if ($cmd_now ne "") {
      if ($ret = AnalyzeCommandChain(undef, $cmd_now)) {
        Log3 $pn,2 , "output of $pn $cmd_now: $ret";
      }
    }
    readingsBulkUpdate  ($hash, "cmd",$cmd_sym_now);
  } 
}

1;

=pod
=item helper
=item summary simulation of a thermostat or humidistat
=item summary_DE Simulation eines Zweipunktreglers
=begin html

<a name="THRESHOLD"></a>
<h3>THRESHOLD</h3>
<ul>
  Diverse controls can be realized by means of the module by evaluation of sensor data.
  In the simplest case, this module reads any sensor that provides values in decimal and execute FHEM/Perl commands, if the value of the sensor is higher or lower than the threshold value.
  A typical application is the simulation of a thermostat or humidistat.<br> 
  <br>
  With one or more such modules, complex systems can be implemented for heating, cooling, ventilation, dehumidification or shading.
  But even simple notification when crossing or falling below a specific value can be easily realized. It no if-statements in Perl or notify definitions need to be made.
  This leads to quickly create and clear controls, without having to necessarily go into the Perl matter.<br>
  Some application examples are at the end of the module description.<br>
  <br>
  According to the definition of a module type THRESHOLD eg:<br>
  <br>
    <code>define &lt;name&gt; THRESHOLD &lt;sensor&gt; &lt;actor&gt;</code><br> 
  <br>
  It is controlled by setting a desired value with:<br>
  <br>
  <code>set &lt;name&gt; desired &lt;value&gt;</code><br>
  <br>
  The module begins with the control system only when a desired value is set!<br>
  <br>
  The specification of the desired value may also come from another sensor. This control may take place by the comparison of two sensors.<br>
  <br>
  Likewise, any wall thermostats can be used (eg, HM, MAX, FHT) for the definition of the reference temperature.<br>
  <br>
  The switching behavior can also be influenced by another sensor or sensor group.<br>
  <br>
  The combination of multiple THRESHOLD modules together is possible, see examples below.<br>
  <br>
  </ul>
  <a name="THRESHOLDdefine"></a>
  <b>Define</b>
<ul>
  <br>
    <code>define &lt;name&gt; THRESHOLD &lt;sensor&gt;:&lt;reading&gt;:&lt;hysteresis&gt;:&lt;target_value&gt;:&lt;offset&gt; AND|OR &lt;sensor2&gt;:&lt;reading2&gt;:&lt;state&gt; &lt;actor&gt;|&lt;cmd1_gt&gt;|&lt;cmd2_lt&gt;|&lt;cmd_default_index&gt;|&lt;state_cmd1_gt&gt;:&lt;state_cmd2_lt&gt;|&lt;state_format&gt;</code><br>
  <br>
  <br>
    <li><b>sensor</b><br>
      a defined sensor in FHEM
    </li>
    <br>
    <li><b>reading</b> (optional)<br>
      reading of the sensor, which includes a value in decimal<br>
      default value: temperature
    </li>
    <br>
    <li><b>hysteresis</b> (optional)<br>
    Hysteresis, this provides the threshold_min = desired_value - hysteresis<br>
    default value: 1 at temperature, 10 at huminity
    </li>
    <br>
     <li><b>target_value</b> (optional)<br>
      number: Initial value, if no value is specified, it must be set with "set desired value".<br>
      else:&lt;sensorname&gt;:&lt;reading&gt, an additional sensor can be specified, which sets the target value dynamically.<br>
      default value: no value
    </li>
    <br>
    <li><b>offset</b> (optional)<br>
      Offset to desired value<br>
      This results:<br>
      threshold_max = desired_value + offset and threshold_min = desired_value - hysteresis + offset<br>
      Defaultwert: 0<br>
    </li>
    <br>
    <br>
    <li><b>AND|OR</b> (optional)<br>
    logical operator with an optional second sensor<br>
    </li>
    <br>
    <li><b>sensor2</b> (optional, nur in Verbindung mit AND oder OR)<br>
    the second sensor
    </li>
    <br>
    <li><b>reading2</b> (optional)<br>
    reading of the second sensor<br>
    default value: state
    </li>
    <br>
    <li><b>state</b> (optional)<br>
    state of the second sensor<br>
    default value: open
    </li><br>
    <br>
    <li><b>actor</b> (optional)<br>
    actor device defined in FHEM
    </li>
    <br>
    <li><b>cmd1_gt</b> (optional)<br>
    FHEM/Perl command that is executed, if the value of the sensor is higher than desired value and/or the value of sensor 2 is matchted. @ is a placeholder for the specified actor.<br>
    default value: set actor off, if actor defined
    </li>
    <br>
    <li><b>cmd2_lt</b> (optional)<br>
    FHEM/Perl command that is executed, if the value of the sensor is lower than threshold_min or the value of sensor 2 is not matchted. @ is a placeholder for the specified actor.<br>
    default value: set actor on, if actor defined
    </li>
    <br>
    <li><b>cmd_default_index</b> (optional)<br>
    Index of command that is executed after setting the desired value until the desired value or threshold_min value is reached.<br>
    0 - no command<br>
    1 - cmd1_gt<br>
    2 - cmd2_lt<br>
    default value: 2, if actor defined, else 0<br>
    </li>
    <br>
    <li><b>state_cmd1_gt</b> (optional, is defined as an attribute at the same time and can be changed there)<br>
    state, which is displayed, if FHEM/Perl-command cmd1_gt was executed. If state_cmd1_gt state ist set, other states, such as active or deactivated are suppressed.
    <br>
    default value: none
    </li>
    <br>
    <li><b>state_cmd2_lt</b> (optional, is defined as an attribute at the same time and can be changed there)<br>
    state, which is displayed, if FHEM/Perl-command cmd1_gt was executed. If state_cmd1_gt state ist set, other states, such as active or deactivated are suppressed.
    <br>
    default value: none
    </li>
    <br>
    <li><b>state_format</b> (optional, is defined as an attribute at the same time and can be changed there)<br>
    Format of the state output: arbitrary text with placeholders.<br>
    Possible placeholders:<br>
    _m: mode<br>
    _dv: desired_value<br>
    _s1v: sensor_value<br>
    _s2s: sensor2_state<br>
    _sc: state_cmd<br>
    Default value: _m _dv _sc, _sc when state_cmd1_gt and state_cmd2_lt set without actor.<br><br>
    </li>
    <br>
    <b><u>Examples:</u></b><br>
    <br>
    Example for heating:<br>
    <br>	
    It is heated up to the desired value of 20. If the value below the threshold_min value of 19 (20-1)
    the heating is switched on again.<br>
    <br>
    <code>define thermostat THRESHOLD temp_sens heating</code><br>
    <br>
    <code>set thermostat desired 20</code><br>
    <br>
    <br>
    Example for heating with window contact:<br>
    <br>
    <code>define thermostat THRESHOLD temp_sens OR win_sens heating</code><br>
    <br>
    <br>
    Example for heating with multiple window contacts:<br>
    <br>
    <code>define W_ALL structure W_type W1 W2 W3 ....</code><br>
    <code>attr W_ALL clientstate_behavior relative</code><br>
    <code>attr W_ALL clientstate_priority open closed</code><br>
    <br>
    then: <br>
    <br>
    <code>define thermostat THRESHOLD S1 OR W_ALL heating</code><br>
    <br>
    <br>
    More examples for dehumidification, air conditioning, watering:<br>
    <br>
    <code>define hygrostat THRESHOLD hym_sens:humidity dehydrator|set @ on|set @ off|1</code><br>
    <code>define hygrostat THRESHOLD hym_sens:humidity AND Sensor2:state:close dehydrator|set @ on|set @ off|1</code><br>
    <code>define thermostat THRESHOLD temp_sens:temperature:1 aircon|set @ on|set @ off|1</code><br>
    <code>define thermostat THRESHOLD temp_sens AND Sensor2:state:close aircon|set @ on|set @ off|1</code><br>
    <code>define hygrostat THRESHOLD hym_sens:humidity:20 watering|set @ off|set @ on|2</code><br>
    <br>
    <br>
    It can also FHEM/perl command chains are specified:<br>
    <br>
    Examples:<br>
    <br>
    <code>define thermostat THRESHOLD sensor |set Switch1 on;;set Switch2 on|set Switch1 off;;set Switch2 off|1</code><br>
    <code>define thermostat THRESHOLD sensor alarm|{Log 2,"value is exceeded"}|set @ on;;set Switch2 on</code><br>
    <code>define thermostat THRESHOLD sensor ||{Log 2,"value is reached"}|</code><br>
    <br>
    <br>
    Examples of the reference input by another sensor:<br>
    <br>
    Hot water circulation: The return temperature is 5 degrees (offset) below the hot water tank temperature and can vary by up to 4 degrees (hysteresis).<br>
    <br>
    <code>define TH_water_circulation THRESHOLD return_w:temperature:4:water_storage:temperature:-5 circualtion_pump</code><br>
    <br>
    Control of heating by a wall thermostat with acquisition the desired and actual temperature from the wall thermostat:<br>
    <br>
    <code>define TH_heating THRESHOLD WT:measured-temp:1:WT:desired-temp heating</code><br>
    <br>
    <code>set TH_heating desired 17</code> overrides the desired-values from the wall thermostat until called <code>set TH_heating external</code><br>
    <br>
    <br>
    Examples of customized state output:<br>
    <br>
    <code>define thermostat THRESHOLD sensor aircon|set @ on|set @ off|2|on:off</code><br>
    <br>
    <br>
    Example of state output (eg for state evaluation in other modules) without executing code:<br>
    <br>
    <code>define thermostat THRESHOLD sensor:temperature:0:30</code><br>
    <br>
    by reason of default values​​:<br>
    <br>
    <code>define thermostat THRESHOLD sensor:temperature:0:30||||off:on|_sc</code><br>
    <br>
    <br>
    Example of combining several THRESHOLD modules together:<br>
    <br>
    It should be heated when the room temperature drops below 21 degrees and the outside temperature is below 15 degrees:<br>
    <br>
    <code>define TH_outdoor THRESHOLD outdoor:temperature:0:15</code><br>
    <code>define TH_room THRESHOLD indoor OR TH_outdoor:state:off heating</code><br>
    <code>set TH_room desired 21</code><br>
    <br>
    <br>
    An example of time-dependent heating in combination with DOIF module:<br>
    <br>
    <code>define TH_room THRESHOLD T_living_room heating</code><br>
    <code>define di_room DOIF ([05:30-23:00|8] or [07:00-23:00|7]) (set TH_room desired 20) DOELSE (set TH_room desired 18)</code><br>
    <br>
    <br>
    Examples of customized state output:<br>
    <br>
    State output: &lt;mode&gt; &lt;state_cmd&gt; &lt;desired_value&gt; &lt;sensor_value&gt;<br>
    <br>
    <code>define TH_living_room THRESHOLD T_living_room heating|set @ off|set @ on|2|off:on|_m _sc _dv _s1v</code><br>
    <br>
    or<br>
    <br>
    <code>define TH_living_room THRESHOLD T_living_room heating</code><br>
    <code>attr TH_living_room state_cmd1_gt off</code><br>
    <code>attr TH_living_room state_cmd2_lt on</code><br>
    <code>attr TH_living_room state_format _m _sc _dv _s1v</code><br>
    <br>
  </ul>
    <a name="THRESHOLDset"></a>
  <b>Set </b>
  <ul>
      <li> <code>set &lt;name&gt; desired &lt;value&gt;<br></code>
      Set the desired value. If no desired value is set, the module is not active.
      </li>
      <br>
      <li><code>set &lt;name&gt; deactivated &lt;command&gt;<br></code>
      Module is disabled.<br>
      &lt;command&gt; is optional. It can be "cmd1_gt" or "cmd2_lt" passed in order to achieve a defined state before disabling the module.
      </li>
      <br>
      <li> <code>set &lt;name&gt; active &lt;value&gt;<br></code>
      Module is activated. If under target_value a sensor for reference input has been defined, the current setpoint will be inhibited until set "set <name> external".
      </li>
      <br>
      <li><code>set &lt;name&gt; externel<br></code>
      Module is activated, reference input comes from the target sensor, if a sensor has been defined under target_value.<br>
      </li>
      <br>
      <li> <code>set &lt;name&gt; hysteresis &lt;value&gt;<br></code>
      Set hysteresis value.  
      </li>
      <br>
      <li><code>set &lt;name&gt; offset &lt;value&gt;<br></code>
      Set offset value.<br>
      Defaultwert: 0
      </li>
      <br>
       <li><code>set &lt;name&gt; cmd1_gt</code><br>
      Executes the command defined in cmd1_gt.<br>
      </li>
      <br>
      <li><code>set &lt;name&gt; cmd2_lt</code><br>
      Executes the command defined in cmd2_lt.<br>
      </li>
  </ul>
  <br>

  <a name="THRESHOLDget"></a>
  <b>Get </b>
  <ul>
      N/A
  </ul>
  <br>

  <a name="THRESHOLDattr"></a>
  <b>Attributes</b>
  <ul>
    <li><a href="#disable">disable</a></li>
    <li><a href="#loglevel">loglevel</a></li>
    <li>state_cmd1_gt</li>
    <li>state_cmd2_lt</li>
    <li>state_format</li>
    <li>number_format</li>
    The specified format is used in the state for formatting desired_value (_dv) and Sensor_value (_s1v) using the sprintf function.<br>
    The default value is "% .1f" to one decimal place. Other formatting, see Formatting in the sprintf function in the Perldokumentation.<br>
    If the attribute is deleted, numbers are not formatted in the state.<br>
    <li>target_func</li>
    Here, a Perl expression used to calculate a target value from a value of the external sensor.<br>
    The sensor value is given as "_tv" in the expression.<br>
    Example:<br>
    <code>attr TH_heating target_func -0.578*_tv+33.56</code><br>
    <li>setOnDeactivated</li>
    Command to be executed before deactivating. Possible values: cmd1_gt, cmd2_lt<br>
    <li>desiredActivate</li>
    If the attribute is set to 1, a disabled module is automatically activated by "set ... desired <value>". "set ... active" is not needed in this case.<br>
  </ul>
  <br>
    
=end html
=begin html_DE

<a name="THRESHOLD"></a>
<h3>THRESHOLD</h3>
<ul>
  Vielfältige Steuerungen, bei denen durch die Auswertung von Sensordaten eine Steuerung erfolgen soll, können mit Hilfe dieses Moduls realisiert werden.
  Nach der Definition eines THRESHOLD-Moduls und der Vorgabe eines Sollwertes beginnt bereits das definierte Modul mit der Steuerung. Im einfachsten Fall liest das Modul einen Sensor aus, der Werte als Dezimalzahlen liefert
  und schaltet beim Überschreiten einer definierten Schwellen-Obergrenze (Sollwert)
  bzw. beim Unterschreiten einer Schwellen-Untergrenze einen Aktor oder führt beliebige FHEM/Perl-Befehle aus.
  Typisches Anwendungsgebiet ist z. B. die Nachbildung eines Thermostats oder Hygrostats - auch Zweipunktregler genannt.<br>
  <br>
  Mit Hilfe des Moduls, bzw. vieler solcher Module, lassen sich einfache oder auch komplexe Steuerungen für Heizung, Kühlung, Lüftung, Entfeuchtung, Beschattung oder z. B. einfache Benachrichtung 
  beim Über- oder Unterschreiten eines bestimmten Wertes realisieren. Dabei müssen keine If-Abfragen in Perl oder Notify-Definitionen vorgenommen werden.
  Das führt, nicht nur bei FHEM-Anfängern, zu schnell erstellten und übersichtlichen Steuerungen, ohne zwingend in die Perl-Materie einsteigen zu müssen.<br>
  <br>
  Nach der Definition eines Moduls vom Typ THRESHOLD z. B. mit: <br> 
  <br>
  <code>define &lt;name&gt; THRESHOLD &lt;sensor&gt; &lt;actor&gt;</code><br> 
  <br> 
  erfolgt die eigentliche Steuerung über die Vorgabe eines Sollwertes. Das geschieht über:<br>
  <br>
  <code>set &lt;name&gt; desired &lt;value&gt;</code><br>
  <br>
  Das Modul beginnt mit der Steuerung erst dann, wenn ein Sollwert gesetzt wird!<br>
  <br>
  Die Vorgabe des Sollwertes kann bereits bei der Definition des Moduls angegeben werden. Alternativ kann der Sollwert von einem weiteren Sensor kommen.
  Damit kann eine Steuerung durch den Vergleich zweier Sensoren stattfinden.
  Typisches Anwendungsbeispiel ist z. B. die Steuerung von Umwälz- oder Zirkulationspumpen.<br>
  <br>
  Die Vorgabe der Solltemperatur kann auch von beliebigen Wandthermostaten (z. B. HM, MAX, FHT) genutzt werden.<br>
  <br>
  Das Schaltverhalten des THRESHOLD-Moduls kann zusätzlich durch einen weiteren Sensor oder eine Sensorgruppe,
  definiert über structure (z. B. Fensterkontakte), über eine AND- bzw. OR-Verknüpfung beeinflusst werden.
  Bei komplexeren Bedingungen mit mehreren and- bzw. or-Verknüpfung sollte man das neuere <a href="http://fhem.de/commandref_DE.html#DOIF">DOIF</a>-Modul verwenden.<br>
  <br>
  Es ist ebenfalls die Kombination mehrerer THRESHOLD-Module miteinander möglich.<br>
  <br>
  <br>
  <b><u>Beispiele für Heizungssteuerung:</u></b><br>
  <br>
  <b>Einfaches Heizungsthermostat:</b><br>
  <br>
  Es soll bis 20 Grad geheizt werden. Beim Unterschreiten der Untergrenze von 19=20-1 Grad (Sollwert-Hysterese) wird die Heizung wieder eingeschaltet.<br>
  <br>
  <code>define TH_room THRESHOLD temp_room heating</code><br>
  <code>set TH_room desired 20</code><br>
  <br>
  <b>Zeitgesteuertes Heizen mit Hilfe des DOIF-Moduls:</b><br>
  <br>
  <code>define TH_room THRESHOLD temp_room heating</code><br>
  <code>define di_room DOIF ([05:30-23:00|8] or [07:00-23:00|7]) (set TH_room desired 20) DOELSE (set TH_room desired 18)</code><br>
  <br>
  <b>Steuerung einer Heizung durch ein Wandthermostat mit Übernahme der Soll- und Ist-Temperatur vom Wandthermostat:</b><br>
  <br>
  <code>define TH_Heizung THRESHOLD WT_ch1:measured-temp:1:WT_ch2:desired-temp Heizung</code><br>
  <br>
  Mit <code>set TH_Heizung desired 17</code> wird die Vorgabe vom Wandthermostat übersteuert bis <code>set TH_Heizung external</code> aufgerufen wird.<br>
  <br>
  <b>Heizung in Kombination mit einem Fensterkontakt mit Zuständen: open, closed:</b><br>
  <br>
  <code>define TH_room THRESHOLD temp_room OR win_sens heating</code><br>
  <br>
  <b>Heizung in Kombination mit mehreren Fensterkontakten:</b><br>
  <br>
  <code>define W_ALL structure W_type W1 W2 W3 ....</code><br>
  <code>attr W_ALL clientstate_behavior relative</code><br>
  <code>attr W_ALL clientstate_priority open closed</code><br>
  <br>
  <code>define thermostat THRESHOLD S1 OR W_ALL heating</code><br>
  <br>
  <b>Kombination mehrerer THRESHOLD-Module miteinander:</b><br>
  <br>
  Es soll bis 21 Grad geheizt werden, aber nur, wenn die Außentemperatur unter 15 Grad ist:<br>
  <br>
  <code>define TH_outdoor THRESHOLD outdoor:temperature:0:15</code><br>
  <code>define TH_room THRESHOLD indoor OR TH_outdoor:state:off heating</code><br>
  <code>set TH_room desired 21</code><br>
  <br>
  <b>Steuerung einer Heizung nach einer Heizkennlinie:</b><br>
  <br>
  Berechnung der Solltemperatur für die Vorlauftemperatur für Fußbodenheizung mit Hilfe der 0,8-Heizkennlinie anhand der Außentemperatur :<br>
  <br>
  <code>define TH_heating THRESHOLD flow:temperature:2:outdoor:temperature heating</code><br>
  <code>attr TH_heating target_func -0.578*_tv+33.56</code><br>
  <br>
  Nachtabsenkung lässt sich zeitgesteuert durch das Setzen von "offset" realisieren.<br>
  Von 22:00 bis 5:00 Uhr soll die Vorlauftemperatur um 10 Grad herabgesetzt werden:<br>
  <br>
  <code>define di_heating DOIF ([22:00-05:00]) (set TH_heating offset -10) DOELSE (set TH_heating offset 0)</code><br>
  <br>
  <br>
  <b><u>Beispiele für Belüftungssteuerung:</u></b><br>
  <br>
  <b>Einfache Belüftung anhand der Luftfeuchtigkeit:</b><br>
  <br>
  Es soll gelüftet werden, wenn die Feuchtigkeit im Zimmer über 70 % ist; bei 60 % geht der Lüfter wieder aus.<br>
  <br>
  <code>define TH_hum THRESHOLD sens:humidity:10:70 ventilator|set @ on|set @ off|1</code><br>
  <br>
  <b>Belüftung anhand des Taupunktes, abhängig von der Luftfeuchtigkeit innen:</b><br>
  <br>
  Es soll gelüftet werden, wenn die Luftfeuchtigkeit im Zimmer über 70 % ist und der Taupunkt innen höher ist als außen.<br>
  <br>
  <code>define TH_hum THRESHOLD sens:humidity:10:70||||on:off|_sc</code><br>
  <code>define dewpoint dewpoint indoor</code><br>
  <code>define dewpoint dewpoint outdoor</code><br>
  <code>define TH_room THRESHOLD indoor:dewpoint:0:outdoor:dewpoint AND TH_hum:state:on ventilator|set @ on|set @ off|2</code><br>
  <br>
  Belüftung in Kombination mit einem Lichtschalter mit Nachlaufsteuerung: siehe <a href="http://fhem.de/commandref_DE.html#DOIF">DOIF</a>-Modul.<br>
  <br>
  <b><u>Beispiele für die Steuerung der Warmwasserzirkulation:</u></b><br>
  <br>
  <b>Zeitgesteuerte Warmwasserzirkulation:</b><br>
  <br>
  In der Hauptzeit soll die Wassertemperatur im Rücklauf mindestens 38 Grad betragen.<br>
  <br>
  <code>define TH_circ TRHESHOLD return_w:temperature:0 circ_pump</code><br>
  <code>define di_circ DOIF ([05:30-23:00|8] or [07:00-23:00|7]) (set TH_circ desired 38) DOELSE (set TH_circ desired 15)</code><br>
  <br>
  <b>Alternative Steuerung mit Sollwert-Vorgabe durch einen weiteren Sensor des Warmwasserspeichers:</b><br>
  <br>
  Die Rücklauftemperatur soll 5 Grad (offset) unter der Warmwasserspeichertemperatur liegen und bis zu 4 Grad (Hysterese) schwanken dürfen.<br>
  <br>
  <code>define TH_circ THRESHOLD return_w:temperature:4:water_storage:temperature:-5 circ_pump</code><br>
  <br>
  <br>
  <b><u>Beispiele für Beschattungssteuerung:</u></b><br>
  <br>
  <b>Beispiel für einfache Beschattung im Sommer:</b><br>
  <br>
  Zwischen 12:00 und 20:00 Uhr (potenzielle Sonnengefahr auf der Südseite) wird der Rolladen auf 30 % heruntergefahren,<br>
  wenn die Raumtemperatur über 23 Grad ist und die Sonne scheint. Im Winter, wenn die Zimmertemperatur niedriger ist (< 23),<br>
  will man von der Sonnenenergie profitieren und den Rollladen oben lassen.<br>
  <br>
  <code>define TH_shutter_room THRESHOLD T_room AND sun:state:on shutter_room|set @ 30||2</code><br>
  <code>define di_shutter DOIF ([12:00-20:00]) (set TH_shutter desired 23) DOELSE (set TH_shutter desired 30)</code><br>
  <br>
  Weitere Beispiele für Beschattung mit Verzögerung und automatischem Hochfahren des Rollladens: siehe <a href="http://fhem.de/commandref_DE.html#DOIF">DOIF</a>-Modul.<br>
  <br>
  <br>
  <b><u>Beispiele für die Ausführung beliebiger FHEM/Perl-Befehlsketten:</u></b><br>
  <br>
  <code>define thermostat THRESHOLD sensor |set Switch1 on;;set Switch2 on|set Switch1 off;;set Switch2 off|1</code><br>
  <code>define thermostat THRESHOLD sensor alarm|{Log 2,"Wert überschritten"}|set @ off|</code><br>
  <code>define thermostat THRESHOLD sensor ||{Log 2,"Wert unterschritten"}|</code><br>
  <br>
  <br>
  <b><u>Einige weitere Bespiele für Entfeuchtung, Klimatisierung, Bewässerung:</u></b><br>
  <br>
  <code>define hygrostat THRESHOLD hym_sens:humidity dehydrator|set @ on|set @ off|1</code><br>
  <code>define hygrostat THRESHOLD hym_sens:humidity AND Sensor2:state:closed dehydrator|set @ on|set @ off|1</code><br>
  <code>define thermostat THRESHOLD temp_sens:temperature:1 aircon|set @ on|set @ off|1</code><br>
  <code>define thermostat THRESHOLD temp_sens AND Sensor2:state:closed aircon|set @ on|set @ off|1</code><br>
  <code>define hygrostat THRESHOLD hym_sens:humidity:20 watering|set @ off|set @ on|2</code><br>
  <br>
  <br>
  <b><u>Beispiele für angepasste Statusanzeige des THRESHOLD-Moduls:</u></b><br>
  <br>
  <code>define thermostat THRESHOLD sensor aircon|set @ on|set @ off|2|on:off</code><br>
  <br>
  <b>Beispiel für reine Zustandanzeige (z. B. für Zustandsauswertung in anderen Modulen) ohne Ausführung von Code:</b><br>
  <br>
  <code>define thermostat THRESHOLD sensor:temperature:0:30</code><br>
  <br>
  entspricht wegen Defaultwerte:<br>
  <br>
  <code>define thermostat THRESHOLD sensor:temperature:0:30||||off:on|_sc</code><br>
  <br>
  <b>Es soll der Modus (mode), Status (state_cmd), Sollvorgabewert (desired_value) und Wert des ersten Sensors (sensor_value) angezeigt werden:</b><br>
  <br>
  <code>define TH_living_room THRESHOLD T_living_room heating|set @ off|set @ on|2|off:on|_m _sc _dv _s1v</code><br>
  <br>
  oder<br>
  <br>
  <code>define TH_living_room THRESHOLD T_living_room heating</code><br>
  <code>attr TH_living_room state_cmd1_gt off</code><br>
  <code>attr TH_living_room state_cmd2_lt on</code><br>
  <code>attr TH_living_room state_format _m _sc _dv _s1v</code><br>
  <br>
 </ul>
  <a name="THRESHOLDdefine"></a>
  <b>Define</b>
<ul>
   <br>
     <code>define &lt;name&gt; THRESHOLD &lt;sensor&gt;:&lt;reading&gt;:&lt;hysteresis&gt;:&lt;target_value&gt;:&lt;offset&gt; AND|OR &lt;sensor2&gt;:&lt;reading2&gt;:&lt;state&gt; &lt;actor&gt;|&lt;cmd1_gt&gt;|&lt;cmd2_lt&gt;|&lt;cmd_default_index&gt;|&lt;state_cmd1_gt&gt;:&lt;state_cmd2_lt&gt;|&lt;state_format&gt;</code><br>
  <br>
       <br>
    <li><b>sensor</b><br>
      ein in FHEM definierter Sensor<br>
    </li>
    <br>
    <li><b>reading</b> (optional)<br>
      Reading des Sensors, der einen Wert als Dezimalzahl beinhaltet<br>
      Defaultwert: temperature<br>
    </li>
    <br>
    <li><b>hysteresis</b> (optional)<br>
    Hysterese, daraus errechnet sich die Untergrenze = Sollwert - hysteresis<br>
    Defaultwert: 1 bei Temperaturen, 10 bei Feuchtigkeit<br>
    </li>
    <br>
    <li><b>target_value</b> (optional)<br>
      bei Zahl: Initial-Sollwert, wenn kein Wert vorgegeben wird, muss er mit "set desired value" gesetzt werden.<br>
      sonst: &lt;sensorname&gt;:&lt;reading&gt, hier kann ein weiterer Sensor angegeben werden, der den Sollwert dynamisch vorgibt.<br> 
      Defaultwert: kein<br>
    </li>
    <br>
    <li><b>offset</b> (optional)<br>
      Offset zum Sollwert<br>
      Damit errechnet sich: die Sollwertobergrenze = Sollwert + offset und die Sollwertuntergrenze = Sollwert - Hysterese + offset<br>
      Defaultwert: 0<br>
    </li>
    <br>
    <br>
    <li><b>AND|OR</b> (optional)<br>
    Verknüpfung mit einem optionalen zweiten Sensor<br>
    </li>
    <br>
    <li><b>sensor2</b> (optional, nur in Verbindung mit AND oder OR)<br>
    ein definierter Sensor, dessen Status abgefragt wird<br>
    </li>
    <br>
    <li><b>reading2</b> (optional)<br>
    Reading, der den Status des Sensors beinhaltet<br>
    Defaultwert: state<br>
    </li>
    <br>
    <li><b>state</b> (optional)<br>
    Status des Sensors, der zu einer Aktion führt<br>
    Defaultwert: open<br>
    </li>
    <br>
    <li><b>actor</b> (optional)<br>
    ein in FHEM definierter Aktor<br>
    </li>
    <br>
    <li><b>cmd1_gt</b> (optional)<br>
    FHEM/Perl Befehl, der beim Überschreiten des Sollwertes ausgeführt wird bzw.
    wenn status des sensor2 übereinstimmt. @ ist ein Platzhalter für den angegebenen Aktor.<br>
    Defaultwert: set actor off, wenn Aktor angegeben ist<br>
    </li>
    <br>
    <li><b>cmd2_lt</b> (optional)<br>
    FHEM/Perl Befehl, der beim Unterschreiten der Untergrenze (Sollwert-Hysterese) ausgeführt wird bzw.
    wenn status des sensor2 nicht übereinstimmt. @ ist ein Platzhalter für den angegebenen Aktor.<br>
    Defaultwert: set actor on, wenn Aktor angegeben ist<br>
    </li>
    <br>
    <li><b>cmd_default_index</b> (optional)<br>
    FHEM/Perl Befehl, der nach dem Setzen des Sollwertes ausgeführt wird, bis Sollwert oder die Untergrenze erreicht wird.<br>
    0 - kein Befehl<br>
    1 - cmd1_gt<br>
    2 - cmd2_lt<br>
    Defaultwert: 2, wenn Aktor angegeben ist, sonst 0<br>
    </li>
    <br>
    <li><b>state_cmd1_gt</b> (optional, wird gleichzeitig als Attribut definiert)<br>
    Status, der angezeigt wird, wenn FHEM/Perl-Befehl cmd1_gt ausgeführt wurde.<br>
    Defaultwert: kein<br>
    </li>
    <br>
    <li><b>state_cmd2_lt</b> (optional, wird gleichzeitig als Attribut definiert)<br>
    Status, der angezeigt wird, wenn FHEM/Perl-Befehl cmd2_lt ausgeführt wurde.<br>
    Defaultwert: kein<br>
    </li>
    <br>
    <li><b>state_format</b> (optional, wird gleichzeitig als Attribut definiert und kann dort verändert werden)<br>
    Format der Statusanzeige: beliebiger Text mit Platzhaltern<br>
    Mögliche Platzhalter:<br>
    _m: mode<br>
    _dv: desired_value<br>
    _s1v: sensor_value<br>
    _s2s: sensor2_state<br>
    _sc: state_cmd<br>
    Defaultwert: _m _dv _sc, _sc, wenn state_cmd1_gt und state_cmd2_lt ohne Aktor gesetzt wird.<br>
    </li>
    <br>
    <br>
    </ul>
    <a name="THRESHOLDset"></a>
  <b>Set </b>
  <ul>
      <li><code>set &lt;name&gt; desired &lt;value&gt;<br></code>
      Setzt den Sollwert. Wenn kein Sollwert gesetzt ist, ist das Modul nicht aktiv.
      Sollwert-Vorgabe durch einen Sensor wird hiermit übersteuert, solange bis "set external" gesetzt wird.
      </li>
      <br>
      <li><code>set &lt;name&gt; deactivated &lt;command&gt;<br></code>
      Modul wird deaktiviert.<br>
      &lt;command&gt; ist optional. Es kann "cmd1_gt" oder "cmd2_lt" übergeben werden, um vor dem Deaktivieren des Moduls einen definierten Zustand zu erreichen.
      </li>
      <br>
      <li><code>set &lt;name&gt; active<br></code>
      Modul wird aktiviert, falls unter target_value ein Sensor für die Sollwert-Vorgabe definiert wurde, wird der aktuelle Sollwert solange eingefroren bis "set <name> external" gesetzt wird.<br>
      </li>
      <br>
      <li><code>set &lt;name&gt; externel<br></code>
      Modul wird aktiviert, Sollwert-Vorgabe kommt vom Sensor, falls ein Sensor unter target_value definierte wurde.<br>
      </li>
      <br>
      <li><code>set &lt;name&gt; hysteresis &lt;value&gt;<br></code>
      Setzt Hysterese-Wert.  
      </li>
      <br>
      <li><code>set &lt;name&gt; offset &lt;value&gt;<br></code>
      Setzt Offset-Wert.<br>
      Defaultwert: 0
      </li>
      <br>
       <li><code>set &lt;name&gt; cmd1_gt</code><br>
      Führt das unter cmd1_gt definierte Kommando aus.<br>
      </li>
      <br>
      <li><code>set &lt;name&gt; cmd2_lt</code><br>
      Führt das unter cmd2_lt definierte Kommando aus.<br>
      </li>
  </ul>
  <br>
  <a name="THRESHOLDget"></a>
  <b>Get </b>
  <ul>
      N/A
  </ul>
  <br>

  <a name="THRESHOLDattr"></a>
  <b>Attributes</b>
  <ul>
    <li><a href="#disable">disable</a></li>
    <li><a href="#loglevel">loglevel</a></li>
    <li>state_cmd1_gt</li>
    <li>state_cmd2_lt</li>
    <li>state_format</li>
    <li>number_format</li>
    Das angegebene Format wird im Status für die Formatierung von desired_value (_dv) und sensor_value (_s1v) über die sprintf-Funktion benutzt.<br>
    Voreingestellt ist "%.1f" für eine Nachkommastelle. Für weiter Formatierungen - siehe Formatierung in der sprintf-Funktion in der Perldokumentation.<br>
    Wenn das Attribut gelöscht wird, werden Zahlen im Status nicht formatiert.<br>
    <li>target_func</li>
    Hier kann ein Perlausdruck angegeben werden, um aus dem Vorgabewert eines externen Sensors (target_value) einen Sollwert zu berechnen.<br>
    Der Sensorwert wird mit "_tv" im Ausdruck angegeben. Siehe dazu Beispiele oben zur Steuerung der Heizung nach einer Heizkennlinie.<br>
    <li>setOnDeactivated</li>
    Kommando, welches durch das Deaktivieren per "set ... deactivated" automatisch ausgeführt werden soll. Mögliche Angaben: cmd1_gt, cmd2_lt<br>
    <li>desiredActivate</li>
    Wenn das Attribut auf 1 gesetzt ist, wird ein deaktiviertes Modul durch "set ... desired <value>" automatisch aktiviert. "set ... active" ist dann nicht erforderlich.<br>
   </ul>
  <br>
    
=end html_DE
=cut
