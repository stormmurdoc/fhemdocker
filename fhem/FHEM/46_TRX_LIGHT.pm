# $Id: 46_TRX_LIGHT.pm 20806 2019-12-22 15:32:53Z KernSani $
##############################################################################
#
#     46_TRX_LIGHT.pm
#     FHEM module for lighting protocols:
#       X10 lighting, ARC, ELRO AB400D, Waveman, Chacon EMW200,
#       IMPULS, AC (KlikAanKlikUit, NEXA, CHACON, HomeEasy UK),
#       HomeEasy EU, ANSLUT, Ikea Koppla
#
#     Copyright (C) 2012-2016 by Willi Herzig (Willi.Herzig@gmail.com)
#	  Maintenance since 2018 by KernSani
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
#
# values for "set global verbose"
# 4: log unknown protocols
# 5: log decoding hexlines for debugging
#
##############################################################################
#
#	CHANGELOG
#	20.12.2019	Fixed ASA (forum #98830)
#				Added Kangtech (forum #105434)
#				Minor Adjustment for DC106 Blinds (enable remote?)
#				Somfy adjusted 
#				Added missing "RFU"
#	29.03.2019	Revised log levels 
#	21.03.2019	Added subtype ASA for RFY
#	26.12.2018	Support for CUVEO devices
#	09.12.2018	Additional commands for RFY (forum #36451)
#				Support for Cuevo (not tested)
#				Fix for Selectplus (forum #71568)
#	25.03.2018	Summary for Commandref
#				Use SetExtensions
#				Fix to trigger events (userreadings) - topic #65899
##############################################################################

package main;

use strict;
use warnings;
use SetExtensions;

my $time_old = 0;

my $TRX_LIGHT_type_default     = "ds10a";
my $TRX_LIGHT_X10_type_default = "x10";

my $DOT = q{_};

my %light_device_codes = (    # HEXSTRING => "NAME", "name of reading",
                              # 0x10: Lighting1
    0x1000 => [ "X10",         "light" ],
    0x1001 => [ "ARC",         "light" ],
    0x1002 => [ "AB400D",      "light" ],
    0x1003 => [ "WAVEMAN",     "light" ],
    0x1004 => [ "EMW200",      "light" ],
    0x1005 => [ "IMPULS",      "light" ],
    0x1006 => [ "RISINGSUN",   "light" ],
    0x1007 => [ "PHILIPS_SBC", "light" ],
    0x1008 => [ "ENER010",     "light" ],    # Energenie ENER010: untested
    0x1009 => [ "ENER5",       "light" ],    # Energenie 5-gang: untested
    0x100A => [ "COCO_GDR2",   "light" ],    # COCO GDR2-2000R: untestedCOCO
                                             # 0x11: Lighting2
    0x1100 => [ "AC",          "light" ],
    0x1101 => [ "HOMEEASY",    "light" ],
    0x1102 => [ "ANSLUT",      "light" ],

    # 0x12: Lighting3
    0x1200 => [ "KOPPLA",       "light" ],    # IKEA Koppla
    # 0x13: Lighting4
    0x1300 => [ "PT2262",       "light" ],    # PT2262 raw messages
    # 0x14: Lighting5
    0x1400 => [ "LIGHTWAVERF",  "light" ],    # LightwaveRF
    0x1401 => [ "EMW100",       "light" ],    # EMW100
    0x1402 => [ "BBSB",         "light" ],    # BBSB
    0x1403 => [ "MDREMOTE",     "light" ],    # MDREMOTE LED dimmer
    0x1404 => [ "RSL2",         "light" ],    # Conrad RSL2
    0x1405 => [ "LIVOLO",       "light" ],    # Livolo
    0x1406 => [ "TRC02",        "light" ],    # RGB TRC02
	0x1411 => [ "KANGTAI",		"light" ],	  # Kangtai,Cotech
    # 0x15: Lighting6
    0x1500 => [ "BLYSS",        "light" ],    # Blyss
    0x1501 => [ "CUVEO",        "light" ],    # Cuveo
                                              # 0x16: Chime
    0x1600 => [ "BYRONSX",      "light" ],    # Byron SX
    0x1601 => [ "BYRONMP",      "chime" ],    # Byron MP001
    0x1602 => [ "SELECTPLUS",   "chime" ],    # SelectPlus
    0x1603 => [ "RFU",          "chime" ],    # RFU
    0x1604 => [ "ENVIVO",       "chime" ],    # Envivo
                                              # 0x17: Fan
    0x1700 => [ "SIEMENS_SF01", "light" ],    # Siemens SF01
                                              # 0x18: Curtain1
    0x1800 => [ "HARRISON",     "light" ],    # Harrison Curtain
                                              # 0x19: Blinds1
    0x1900 => [ "ROLLER_TROL",  "light" ],    # Roller Trol
    0x1901 => [ "HASTA_OLD",    "light" ],    # Hasta old
    0x1902 => [ "AOK_RF01",     "light" ],    # A-OK RF01
    0x1903 => [ "AOK_AC114",    "light" ],    # A-OK AC114
    0x1904 => [ "RAEX_YR1326",  "light" ],    # Raex YR1326
    0x1905 => [ "MEDIA_MOUNT",  "light" ],    # Media Mount
    0x1906 => [ "DC106",        "light" ],    # DC/RMF/Yooda
    0x1907 => [ "FOREST",       "light" ],    # Forest
    0x1A00 => [ "RFY",          "light" ],    # RTS RFY
    0x1A01 => [ "RFY_ext",      "light" ],    # RTS RFY ext
	0x1A03 => [ "ASA",          "light" ],    # ASA
);

my %light_device_commands = (                 # HEXSTRING => commands
                                              # 0x10: Lighting1
    0x1000 => [ "off", "on", "dim", "bright", "", "all_off", "all_on" ],    # X10
    0x1001 => [ "off", "on", "", "", "", "all_off", "all_on", "chime" ],    # ARC
    0x1002 => [ "off", "on" ],                                              # AB400D
    0x1003 => [ "off", "on" ],                                              # WAVEMAN
    0x1004 => [ "off", "on" ],                                              # EMW200
    0x1005 => [ "off", "on" ],                                              # IMPULS
    0x1006 => [ "off", "on" ],                                              # RisingSun
    0x1007 => [ "off", "on", "", "", "", "all_off", "all_on" ],             # Philips SBC
    0x1008 => [ "off", "on", "", "", "", "all_off", "all_on" ],             # Energenie ENER010
    0x1009 => [ "off", "on" ],                                              # Energenie 5-gang
    0x100A => [ "off", "on" ],                                              # COCO GDR2-2000R
                                                                            # 0x11: Lighting2
    0x1100 => [ "off", "on", "level", "all_off", "all_on", "all_level" ],   # AC
    0x1101 => [ "off", "on", "level", "all_off", "all_on", "all_level" ],   # HOMEEASY
    0x1102 => [ "off", "on", "level", "all_off", "all_on", "all_level" ],   # ANSLUT
                                                                            # 0x12: Lighting3
    0x1200 => [
        "bright", "", "", "", "", "", "", "", "dim", "", "", "", "", "", "", "",
        "on", "level1", "level2", "level3", "level4", "level5", "level6", "level7", "level8", "level9", "off", "",
        "program", "", "", "", "",
    ],                                                                      # Koppla
                                                                            # 0x13: Lighting4
    0x1300 => ["Lighting4"],                                                # Lighting4: PT2262
                                                                            # 0x14: Lighting5
    0x1400 => [
        "off",      "on",    "all_off",   "mood1",     "mood2",  "mood3",
        "mood4",    "mood5", "reserved1", "reserved2", "unlock", "lock",
        "all_lock", "close", "stop",      "open",      "level"
    ],                                                                      # LightwaveRF, Siemens
    0x1401 => [ "off", "on", "learn" ],                                     # EMW100 GAO/Everflourish
    0x1402 => [ "off", "on", "all_off", "all_on" ],                         # BBSB new types
    0x1403 => [ "power", "light", "bright", "dim", "100", "50", "25", "mode+", "speed-", "speed+", "mode-" ], # MDREMOTE
    0x1404 => [ "off",     "on",     "all_off", "all_on" ],                           # Conrad RSL
    0x1405 => [ "all_off", "on_off", "dim+",    "dim-" ],                             # Livolo
    0x1406 => [ "off",     "on",     "bright",  "dim", "vivid", "pale", "color" ],    # TRC02
    0x1411 => [ "off", "on", "all_off", "all_on" ],                 	         	  # Kangtai,Cotech
                                                                                      # 0x15: Lighting6
    0x1500 => [ "on",      "off",    "all_on",  "all_off" ],                          # Blyss
    0x1501 => [ "on",      "off",    "all_on",  "all_off" ],                          # Cuveo
                                                                                      # 0x16: Chime
    0x1600 => [
        "",           "tubular3_1", "solo1",    "bigben1", "",  "tubular2_1",
        "tubular2_2", "",           "dingdong", "solo2",   " ", "",
        "",           "tubular3_2"
    ],                                                                                # Byron SX
    0x1601 => ["ring"],                                                               # Byron MP001
    0x1602 => ["ring"],                                                               # SelectPlus
    0x1603 => ["ring"],                                                               # RFU
    0x1604 => ["ring"],                                                               # Envivo
                                                                                      # 0x17: Fan
    0x1700 => [ "", "timer", "-", "learn", "+", "confirm", "light", "on", "off" ],    # Siemens SF01
                                                                                      # 0x18: Curtain1
    0x1800 => [ "open", "close", "stop", "program" ],                                 # Harrison Curtain
                                                                                      # 0x19: Blinds1
    0x1900 => [ "open", "close", "stop", "confirm_pair", "set_limit" ],               # Roller Trol
    0x1901 => [ "open", "close", "stop", "confirm_pair", "set_limit" ],               # Hasta old
    0x1902 => [ "open", "close", "stop", "confirm_pair" ],                            # A-OK RF01
    0x1903 => [ "open", "close", "stop", "confirm_pair" ],                            # A-OK AC114
    0x1904 => [
        "open",            "close",           "stop",          "confirm_pair",
        "set_upper_limit", "set_lower_limit", "delete_limits", "change_dir",
        "left",            "right"
    ],                                                                                # Raex YR1326
    0x1905 => [ "down", "up",    "stop" ],                                            # Media Mount
    0x1906 => [ "open", "close", "stop", "confirm" ],                                 # DC/RMF/Yooda
    0x1907 => [ "open", "close", "stop", "confirm_pair" ],                            # Forest
    0x1A00 => [
        "stop", "up", "", "down", "", "", "", "program", "", "", "", "", "", "", "", "up<0.5s", "down<0.5s", "up>2s",
        "down>2s", "enable_sun+wind", "disable_sun"
    ],                                                                                #RFY, forum #36451
	0x1A01 => [ "stop", "up", "", "down", "", "", "", "program", "", "", "", "", "", "", "", "up_<0.5_seconds", "down_<0.5_seconds", "up_>2_seconds", "down_>2_seconds"], # RTS RFY ext
	0x1A03 => [ "stop", "up",    "", "down", "", "", "", "program" ],                 # ASA
);

my %light_device_c2b;    # DEVICE_TYPE->hash (reverse of light_device_codes)

sub TRX_LIGHT_Initialize($) {
    my ($hash) = @_;

    foreach my $k ( keys %light_device_codes ) {
        $light_device_c2b{ $light_device_codes{$k}->[0] } = $k;
    }

    $hash->{Match}    = "^..(10|11|12|13|14|15|16|17|18|19|1A).*";
    $hash->{SetFn}    = "TRX_LIGHT_Set";
    $hash->{DefFn}    = "TRX_LIGHT_Define";
    $hash->{UndefFn}  = "TRX_LIGHT_Undef";
    $hash->{ParseFn}  = "TRX_LIGHT_Parse";
    $hash->{AttrList} = "IODev ignore:1,0 do_not_notify:1,0 repeat " . $readingFnAttributes;

}

#####################################
sub TRX_LIGHT_SetState($$$$) {
    my ( $hash, $tim, $vt, $val ) = @_;

    $val = $1 if ( $val =~ m/^(.*) \d+$/ );

    # to be done. Just accept everything right now.
    #return "Undefined value $val" if(!defined($fs20_c2b{$val}));
    return undef;
}

###################################
sub TRX_LIGHT_Set($@) {
    my ( $hash, $name, @a ) = @_;
    my $ret = undef;
    my $na  = int(@a);
    return "no set value specified" if ( $na < 1 || $na > 4 );

    # look for device_type

    my $command       = $a[0];
    my $command_state = $a[0];
    my $level         = 0;
    my $color         = 0;
    my $arg3          = "";	

    # special for SetExtensions
    #old TRX_LIGHT used a special on-for-timer notation
    if ( $command eq "on-for-timer" ) {
        my ( $err, $h, $m, $s, $fb ) = GetTimeSpec( $a[1] );
        if ( !defined($err) ) {
            $a[1] = $h * 3600 + $m * 60 + $s;
            Log3 $name, 1,
"TRX_LIGHT is now using SetExtensions. Consider changing [Set $name $command] to a numeric value (seconds) instead of a TimeSpec";
        }
    }

    if ( $na == 2 ) {
        $arg3 = $a[1];
        if ( $na == 2 && $command eq "level" ) {
            $level = $a[1];
        }
        elsif ( $na == 2 && $command eq "color" ) {
            $color = $a[1];
        }
    }

    my $device_type = $hash->{TRX_LIGHT_type};
    my $deviceid    = $hash->{TRX_LIGHT_deviceid};

    if ( $device_type eq "MS14A" ) {
        return "No set implemented for $device_type";
    }

    if (   lc( $hash->{TRX_LIGHT_devicelog} ) eq "window"
        || lc( $hash->{TRX_LIGHT_devicelog} ) eq "door"
        || lc( $hash->{TRX_LIGHT_devicelog} ) eq "motion"
        || lc( $hash->{TRX_LIGHT_devicelog} ) eq "ring"
        || lc( $hash->{TRX_LIGHT_devicelog} ) eq "lightsensor"
        || lc( $hash->{TRX_LIGHT_devicelog} ) eq "photosensor"
        || lc( $hash->{TRX_LIGHT_devicelog} ) eq "lock" )
    {
        return "No set implemented for $device_type";
    }

    my $device_type_num = $light_device_c2b{$device_type};
    if ( !defined($device_type_num) ) {
        return "Unknown device_type, choose one of " . join( " ", sort keys %light_device_c2b );
    }
    my $protocol_type = $device_type_num >> 8;    # high bytes

    # Now check if the command is valid and retrieve the command id:
    my $rec = $light_device_commands{$device_type_num};
    my $i;
    for ( $i = 0 ; $i <= $#$rec && ( $rec->[$i] ne $command ) ; $i++ ) { ; }

    if ( $rec->[0] eq "Lighting4" ) {             # for Lighting4
        my $command_codes = $hash->{TRX_LIGHT_commandcodes} . ",";
        my $l             = $command_codes;
        $l =~ s/([0-9]*):([a-z]*),/$2 /g;
        Log3 $name, 5, "TRX_LIGHT_Set() PT2262: l=$l";

        if ( !( $command =~ /^[0-2]*$/ ) ) {      # if it is base4 just accept it
            if ( $command ne "?" && $command_codes =~ /([0-9]*):$command,/ ) {
                Log3 $name, 5, "TRX_LIGHT_Set() PT2262: arg=$command found=$1";
                $command = $1;
            }
            else {
                Log3 $name, 5, "TRX_LIGHT_Set() PT2262: else arg=$command l='$l'";

                #my $error = "Unknown command $command, choose one of $l ";
                return SetExtensions( $hash, $l, $name, @a );

                #Log3 $name, 1, "TRX_LIGHT_Set() PT2262" . $error if ( $command ne "?" );
                #return $error;
            }
        }
    }
    elsif ( $i > $#$rec ) {
        my $l = join( " ", sort @$rec );
        if ( $device_type eq "AC" || $device_type eq "HOMEEASY" || $device_type eq "ANSLUT" ) {
            $l =~ s/ level / level:slider,0,1,15 /;
        }
        elsif ( $device_type eq "TRC02" ) {
            $l =~ s/ color / color:slider,14,2,128 /;
        }

        #my $error = "Unknown command $command, choose one of $l";
        return SetExtensions( $hash, $l, $name, @a );

        #Log3 $name, 1, "TRX_LIGHT_Set()" . $error if ( $command ne "?" );
        #return $error;
    }

    my $seqnr = 0;
    my $cmnd  = $i;

    my $hex_prefix;
    my $hex_command;
    if ( $protocol_type == 0x10 ) {
        my $house;
        my $unit;
        if ( $deviceid =~ /(.)(.*)/ ) {
            $house = ord("$1");
            $unit  = $2;
        }
        else {
            Log3 $name, 1,
              "TRX_LIGHT_Set() lighting1 wrong deviceid: name=$name device_type=$device_type, deviceid=$deviceid";
            return "error set name=$name  deviceid=$deviceid";
        }

        # lighting1
        $hex_prefix = sprintf "0710";
        $hex_command = sprintf "%02x%02x%02x%02x%02x00", $device_type_num & 0xff, $seqnr, $house, $unit, $cmnd;
        Log3 $name, 5,
"TRX_LIGHT_Set() name=$name device_type=$device_type, deviceid=$deviceid house=$house, unit=$unit command=$command";
        Log3 $name, 5, "TRX_LIGHT_Set hexline=$hex_prefix$hex_command";
    }
    elsif ( $protocol_type == 0x11 ) {

        # lighting2
        if ( uc($deviceid) =~ /^[0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F]$/ ) {
            ;
        }
        else {
            Log3 $name, 1,
              "TRX_LIGHT_Set() lighting2 wrong deviceid: name=$name device_type=$device_type, deviceid=$deviceid";
            return "error set name=$name  deviceid=$deviceid";
        }
        $hex_prefix = sprintf "0B11";
        $hex_command = sprintf "%02x%02x%s%02x%02x00", $device_type_num & 0xff, $seqnr, $deviceid, $cmnd, $level;
        if ( $command eq "level" ) {
            $command .= sprintf " %d", $level;
            $command_state = $command;
        }
        Log3 $name, 5,
          "TRX_LIGHT_Set() lighting2 name=$name device_type=$device_type, deviceid=$deviceid command=$command";
        Log3 $name, 5, "TRX_LIGHT_Set() lighting2 hexline=$hex_prefix$hex_command";
    }
    elsif ( $protocol_type == 0x12 ) {

        # lighting3
        my $koppla_id = "";
        if ( uc($deviceid) =~ /^([0-1][0-9])([0-9A-F])([0-9A-F][0-9A-F])$/ ) {

            # $1 = system, $2 = high bits channel, $3 = low bits channel
            my $koppla_system = $1 - 1;
            if ( $koppla_system > 15 ) {
                return "error set name=$name  deviceid=$deviceid. system must be in range 01-16";
            }
            $koppla_id = sprintf( "%02X", $koppla_system ) . $3 . "0" . $2;
            Log3 $name, 5, "TRX_LIGHT_Set() lighting3: deviceid=$deviceid kopplaid=$koppla_id";
        }
        else {
            Log3 $name, 1,
"TRX_LIGHT_Set() lighting3 wrong deviceid: name=$name device_type=$device_type, deviceid=$deviceid. Wrong deviceid must be 3 digits with range 0000 - f3FF";
            return
"error set name=$name  deviceid=$deviceid. Wrong deviceid must be 5 digits consisting of 2 digit decimal value for system (01-16) and a 3 hex digit channel (000 - 3ff)";
        }
        $hex_prefix = sprintf "0812";
        $hex_command = sprintf "%02x%02x%s%02x00", $device_type_num & 0xff, $seqnr, $koppla_id, $cmnd;
        if ( $command eq "level" ) {
            $command .= sprintf " %d", $level;
            $command_state = $command;
        }
        Log3 $name, 5,
          "TRX_LIGHT_Set() lighting3 name=$name device_type=$device_type, deviceid=$deviceid command=$command";
        Log3 $name, 5, "TRX_LIGHT_Set() lighting3 hexline=$hex_prefix$hex_command";
    }
    elsif ( $protocol_type == 0x13 ) {

        # lighting4 (PT2262)
        my $pt2262_cmd;
        my $base_4;
        my $bindata;
        my $hexdata;

        if ( $command =~ /^[0-3]*$/ ) {    # if it is base4 just append it
            $pt2262_cmd = $deviceid . $command;
        }
        else {

            return "TRX_LIGHT_Set() PT2262: cmd=$command name=$name not found";
        }

        if ( uc($pt2262_cmd) =~ /^[0-3][0-3][0-3][0-3][0-3][0-3][0-3][0-3][0-3][0-3][0-3][0-3]$/ ) {

            $base_4 = $pt2262_cmd;

            # convert base4 to binary:
            my %b42b = ( 0 => "00", 1 => "01", 2 => "10", 3 => "11" );
            ( $bindata = $base_4 ) =~ s/(.)/$b42b{lc $1}/g;
            $hexdata = unpack( "H*", pack( "B*", $bindata ) );
            Log3 $name, 5, "TRX_LIGHT_Set() PT2262: base4='$base_4', binary='$bindata' hex='$hexdata'";

        }
        else {
            Log3 $name, 5,
"TRX_LIGHT_Set() lighting4:PT2262 cmd='$pt2262_cmd' needs to be base4 and has 12 digits (name=$name device_type=$device_type, deviceid=$deviceid)";
            return "error set name=$name deviceid=$pt2262_cmd (needs to be base4 and has 12 digits)";
        }
        $hex_prefix = sprintf "0913";
        $hex_command = sprintf "00%02x%s015E00", $seqnr, $hexdata;
        Log3 $name, 5,
          "TRX_LIGHT_Set() lighting4:PT2262 name=$name cmd=$command cmd_state=$command_state hexdata=$hexdata";
        Log3 $name, 5, "TRX_LIGHT_Set() lighting4:PT2262 hexline=$hex_prefix$hex_command";
    }
    elsif ( $protocol_type == 0x14 ) {

        # lighting5
        if ( uc($deviceid) =~ /^[0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F]$/ ) {
            ;
        }
        else {
            Log3 $name, 1,
              "TRX_LIGHT_Set() lighting5 wrong deviceid: name=$name device_type=$device_type, deviceid=$deviceid";
            return "error set name=$name  deviceid=$deviceid";
        }
        if ( $command eq "color" ) {
            $cmnd = $color;
            $command .= sprintf " %d", $color;
            $command_state = $command;
        }
        $hex_prefix = sprintf "0A14";
        $hex_command = sprintf "%02x%02x%s%02x%02x00", $device_type_num & 0xff, $seqnr, $deviceid, $cmnd, $level;
        if ( $command eq "level" ) {
            $command .= sprintf " %d", $level;
            $command_state = $command;
        }
        Log3 $name, 5,
          "TRX_LIGHT_Set() lighting5 name=$name device_type=$device_type, deviceid=$deviceid command=$command";
        Log3 $name, 5, "TRX_LIGHT_Set() lighting5 hexline=$hex_prefix$hex_command";
    }

    # Lighting6
    elsif ( $protocol_type == 0x15 ) {
        my $id1;
        my $id2;
        my $unit;
        my $group;
        if ( $deviceid =~ /(..)(..)(.)(.)/ ) {
            $id1   = $1;
            $id2   = $2;
            $group = $3;
            $unit  = $4;
        }
        else {
            Log3 $name, 1,
              "TRX_LIGHT_Set() lighting6 wrong deviceid: name=$name device_type=$device_type, deviceid=$deviceid";
            return "error set name=$name  deviceid=$deviceid";
        }
        $hex_prefix = sprintf "0B15";
        $hex_command = sprintf "%02x%02x%s%s%02x%02x%02x%02x0070", $device_type_num & 0xff, $seqnr, $id1, $id2, $group,
          $unit, $cmnd, $cmnd;

        Log3 $name, 5,
          "TRX_LIGHT_Set() lighting6 name=$name device_type=$device_type, deviceid=$deviceid command=$command $id1$id2";
        Log3 $name, 5, "TRX_LIGHT_Set() lighting2 hexline=$hex_prefix$hex_command";

    }
    elsif ( $protocol_type == 0x16 ) {

        # Chime
        if ( uc($deviceid) =~ /^[0-9A-F][0-9A-F]$/ ) {
            $hex_command = sprintf "%02x%02x00%s%02x00", $device_type_num & 0xff, $seqnr, $deviceid, $cmnd;
        }
        elsif ( uc($deviceid) =~ /^[0-9A-F][0-9A-F][0-9A-F][0-9A-F]$/ ) {
            $hex_command = sprintf "%02x%02x00%s00", $device_type_num & 0xff, $seqnr, $deviceid, $cmnd;
        }
        elsif ( uc($deviceid) =~ /^[0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F]$/ ) {
            $hex_command = sprintf "%02x%02x%s00", $device_type_num & 0xff, $seqnr, $deviceid, $cmnd;
        }
        else {
            Log3 $name, 1,
              "TRX_LIGHT_Set() chime wrong deviceid: name=$name device_type=$device_type, deviceid=$deviceid";
            return "error set name=$name  deviceid=$deviceid";
        }
        $hex_prefix = sprintf "0716";
        Log3 $name, 5, "TRX_LIGHT_Set() chime name=$name device_type=$device_type, deviceid=$deviceid command=$command";
        Log3 $name, 5, "TRX_LIGHT_Set() chime hexline=$hex_prefix$hex_command";
    }
    elsif ( $protocol_type == 0x17 ) {

        # fan
        if ( uc($deviceid) =~ /^[0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F]$/ ) {
            ;
        }
        else {
            Log3 $name, 1,
              "TRX_LIGHT_Set() fan wrong deviceid: name=$name device_type=$device_type, deviceid=$deviceid";
            return "error set name=$name  deviceid=$deviceid";
        }
        $hex_prefix = sprintf "0717";
        $hex_command = sprintf "%02x%02x%s%02xx00", $device_type_num & 0xff, $seqnr, $deviceid, $cmnd;
        Log3 $name, 5, "TRX_LIGHT_Set() fan name=$name device_type=$device_type, deviceid=$deviceid command=$command";
        Log3 $name, 5, "TRX_LIGHT_Set() fan hexline=$hex_prefix$hex_command";
    }
    elsif ( $protocol_type == 0x18 ) {

        # curtain1
        my $house;
        my $unit;
        if ( $deviceid =~ /(.)(.*)/ ) {
            $house = ord("$1");
            $unit  = $2;
        }
        else {
            Log3 $name, 1,
              "TRX_LIGHT_Set() curtain1 wrong deviceid: name=$name device_type=$device_type, deviceid=$deviceid";
            return "error set name=$name  deviceid=$deviceid";
        }

        $hex_prefix = sprintf "0718";
        $hex_command = sprintf "%02x%02x%02x%02x%02x00", $device_type_num & 0xff, $seqnr, $house, $unit, $cmnd;
        Log3 $name, 5,
"TRX_LIGHT_Set() curtain1 name=$name device_type=$device_type, deviceid=$deviceid house=$house, unit=$unit command=$command";
        Log3 $name, 5, "TRX_LIGHT_Set curtain1 hexline=$hex_prefix$hex_command";
    }
    elsif ( $protocol_type == 0x19 ) {

        # Blinds1
        if ( uc($deviceid) =~ /^[0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F]$/ ) {
            ;
        }
        else {
            Log3 $name, 1,
              "TRX_LIGHT_Set() Blinds1 wrong deviceid: name=$name device_type=$device_type, deviceid=$deviceid";
            return "error set name=$name  deviceid=$deviceid";
        }
        $hex_prefix = sprintf "0919";
        $hex_command = sprintf "%02x%02x%s%02x00", $device_type_num & 0xff, $seqnr, $deviceid, $cmnd;
        Log3 $name, 5,
          "TRX_LIGHT_Set() Blinds1 name=$name device_type=$device_type, deviceid=$deviceid command=$command";
        Log3 $name, 5, "TRX_LIGHT_Set() Blinds1 hexline=$hex_prefix$hex_command";
    }
    elsif ( $protocol_type == 0x1A ) {
        my $unitid;
        my $unitcode;
        if ( uc($deviceid) =~ /^([0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F])(0[0-9A-F])$/ ) {
            $unitid   = $1;
            $unitcode = $2;
            if ( ( $device_type_num == 0x1A00 ) && !( $unitcode =~ /^0[0-4]$/ ) ) {
                Log3 $name, 1,
"TRX_LIGHT_Set() RFY wrong unitcode: name=$name device_type=$device_type, unitid=$unitid unitcode=$unitcode";
                return "error set name=$name  deviceid=$deviceid";
            }
            elsif ( ( $device_type_num == 0x1A03 ) && !( $unitcode =~ /^0[1-5]$/ ) ) {
                Log3 $name, 1,
"TRX_LIGHT_Set() RFY wrong unitcode: name=$name device_type=$device_type, unitid=$unitid unitcode=$unitcode";
                return "error set name=$name  deviceid=$deviceid";
            }
			
        }
        else {
            Log3 $name, 1,
              "TRX_LIGHT_Set() RFY wrong deviceid: name=$name device_type=$device_type, deviceid=$deviceid";
            return "error set name=$name  deviceid=$deviceid";
        }
        $hex_prefix = sprintf "0C1A";
        $hex_command = sprintf "%02x%02x%s%s%02x0000000000", $device_type_num & 0xff, $seqnr, $unitid, $unitcode, $cmnd;
        Log3 $name, 5,
          "TRX_LIGHT_Set() RFY name=$name device_type=$device_type, unitid=$unitid unitcode=$unitcode command=$command";
        Log3 $name, 5, "TRX_LIGHT_Set() RFY hexline=$hex_prefix$hex_command";
    }
    else {
        return "No set implemented for $device_type . Unknown protocol type";
    }

    for ( my $repeat = $attr{$name}{repeat} || 1 ; $repeat >= 1 ; $repeat = $repeat - 1 ) {
        IOWrite( $hash, $hex_prefix, $hex_command );
    }

    my $tn = TimeNow();
    $hash->{CHANGED}[0]            = $command_state;
    $hash->{STATE}                 = $command_state;
    $hash->{READINGS}{state}{TIME} = $tn;
    $hash->{READINGS}{state}{VAL}  = $command_state;

    # Add readingsupdate to trigger event / KernSani
    readingsBeginUpdate($hash);
    readingsBulkUpdate( $hash, "state", $command_state );
    readingsEndUpdate( $hash, 1 );
    return $ret;
}

#####################################
sub TRX_LIGHT_Define($$) {
    my ( $hash, $def ) = @_;
    my @a = split( "[ \t][ \t]*", $def );

    my $a            = int(@a);
    my $type         = "";
    my $deviceid     = "";
    my $devicelog    = "";
    my $commandcodes = "";

    if ( int(@a) > 2 && uc( $a[2] ) eq "PT2262" ) {
        if ( int(@a) != 3 && int(@a) != 6 ) {
            Log3 $hash, 1,
"TRX_LIGHT_Define() wrong syntax '@a'. \nCorrect syntax is  'define <name> TRX_LIGHT PT2262 [<deviceid> <devicelog> <commandcodes>]'";
            return "wrong syntax: define <name> TRX_LIGHT PT2262 [<deviceid> <devicelog> [<commandcodes>]]";
        }
    }
    elsif ( int(@a) != 5 && int(@a) != 7 ) {
        Log3 $hash, 1,
"TRX_LIGHT_Define() wrong syntax '@a'. \nCorrect syntax is  'define <name> TRX_LIGHT <type> <deviceid> <devicelog> [<deviceid2> <devicelog2>]'";
        return "wrong syntax: define <name> TRX_LIGHT <type> <deviceid> <devicelog> [<deviceid2> <devicelog2>]";
    }

    my $name = $a[0];
    $type      = uc( $a[2] ) if ( int(@a) > 2 );
    $deviceid  = $a[3]       if ( int(@a) > 3 );
    $devicelog = $a[4]       if ( int(@a) > 4 );
    $commandcodes = $a[5] if ( $type eq "PT2262" && int(@a) > 5 );

    if (   $type ne "X10"
        && $type ne "ARC"
        && $type ne "MS14A"
        && $type ne "AB400D"
        && $type ne "WAVEMAN"
        && $type ne "EMW200"
        && $type ne "IMPULS"
        && $type ne "RISINGSUN"
        && $type ne "PHILIPS_SBC"
        && $type ne "AC"
        && $type ne "HOMEEASY"
        && $type ne "ANSLUT"
        && $type ne "KOPPLA"
        && $type ne "LIGHTWAVERF"
        && $type ne "EMW100"
        && $type ne "BBSB"
        && $type ne "TRC02"
        && $type ne "PT2262"
        && $type ne "ENER010"
		&& $type ne "KANGTAI"
        && $type ne "ENER5"
        && $type ne "COCO_GDR2"
        && $type ne "MDREMOTE"
        && $type ne "RSL2"
        && $type ne "LIVOLO"
        && $type ne "BLYSS"
        && $type ne "CUVEO"
        && $type ne "BYRONSX"
        && $type ne "SIEMENS_SF01"
        && $type ne "HARRISON"
        && $type ne "ROLLER_TROL"
        && $type ne "HASTA_OLD"
        && $type ne "AOK_RF01"
        && $type ne "AOK_AC114"
        && $type ne "RAEX_YR1326"
        && $type ne "MEDIA_MOUNT"
        && $type ne "DC106"
        && $type ne "FOREST"
        && $type ne "RFY"
        && $type ne "RFY_ext"
		&& $type ne "ASA"
		&& $type ne "RFU"
        && $type ne "SELECTPLUS" )
    {
        Log3 $name, 1, "TRX_LIGHT_Define() wrong type: $type";
        return "TRX_LIGHT: wrong type: $type";
    }
    my $my_type;
    if ( $type eq "MS14A" ) {
        $my_type = "X10";    # device will be received as X10
    }
    else {
        $my_type = $type;
    }

    my $device_name = "TRX" . $DOT . $my_type;
    if ( $deviceid ne "" ) { $device_name .= $DOT . $deviceid }

    $hash->{TRX_LIGHT_deviceid}     = $deviceid;
    $hash->{TRX_LIGHT_devicelog}    = $devicelog;
    $hash->{TRX_LIGHT_commandcodes} = $commandcodes if ( $type eq "PT2262" );
    $hash->{TRX_LIGHT_type}         = $type;

    #$hash->{TRX_LIGHT_CODE} = $deviceid;
    $modules{TRX_LIGHT}{defptr}{$device_name} = $hash;

    if ( int(@a) == 7 ) {

        # there is a second deviceid:
        #
        my $deviceid2  = $a[5];
        my $devicelog2 = $a[6];

        my $device_name2 = "TRX" . $DOT . $my_type . $DOT . $deviceid2;

        $hash->{TRX_LIGHT_deviceid2}  = $deviceid2;
        $hash->{TRX_LIGHT_devicelog2} = $devicelog2;

        #$hash->{TRX_LIGHT_CODE2} = $deviceid2;
        $modules{TRX_LIGHT}{defptr2}{$device_name2} = $hash;
    }

    AssignIoPort($hash);

    return undef;
}

#####################################
sub TRX_LIGHT_Undef($$) {
    my ( $hash, $name ) = @_;
    delete( $modules{TRX_LIGHT}{defptr}{$name} );
    return undef;
}

############################################
# T R X _ L I G H T _ p a r s e _ X 1 0 ( )
#-------------------------------------------
sub TRX_LIGHT_parse_X10 ($$) {
    my ( $hash, $bytes ) = @_;

    my $error = "";

    #my $device;

    my $type    = $bytes->[0];
    my $subtype = $bytes->[1];
    my $dev_type;
    my $dev_reading;
    my $rest;

    my $type_subtype = ( $type << 8 ) + $subtype;

    if ( exists $light_device_codes{$type_subtype} ) {
        my $rec = $light_device_codes{$type_subtype};
        ( $dev_type, $dev_reading ) = @$rec;
    }
    else {
        $error = sprintf "TRX_LIGHT: error undefined type=%02x, subtype=%02x", $type, $subtype;
        Log3 $hash, 1, "TRX_LIGHT_parse_X10() " . $error;
        return $error;
    }

    if ( $dev_type eq "BBSB" ) { return " "; }    # ignore BBSB messages temporarily because of receiving problems

    my $device;
    my $data;
    if ( $type == 0x10 || $type == 0x18 ) {
        my $dev_first = "?";

        my %x10_housecode = (
            0x41 => "A",
            0x42 => "B",
            0x43 => "C",
            0x44 => "D",
            0x45 => "E",
            0x46 => "F",
            0x47 => "G",
            0x48 => "H",
            0x49 => "I",
            0x4A => "J",
            0x4B => "K",
            0x4C => "L",
            0x4D => "M",
            0x4E => "N",
            0x4F => "O",
            0x50 => "P",
        );
        my $devnr = $bytes->[3];    # housecode
        if ( exists $x10_housecode{$devnr} ) {
            $dev_first = $x10_housecode{$devnr};
        }
        else {
            $error = sprintf "TRX_LIGHT: x10_housecode wrong housecode=%02x", $devnr;
            Log3 $hash, 1, "TRX_LIGHT_parse_X10() " . $error;
            return $error;
        }
        my $unit = $bytes->[4];     # unitcode
        $device = sprintf '%s%0d', $dev_first, $unit;
        $data = $bytes->[5];

    }
    elsif ( $type == 0x11 ) {
        $device = sprintf '%02x%02x%02x%02x%02x', $bytes->[3], $bytes->[4], $bytes->[5], $bytes->[6], $bytes->[7];
        $data = $bytes->[8];
    }
    elsif ( $type == 0x14 ) {
        $device = sprintf '%02x%02x%02x%02x', $bytes->[3], $bytes->[4], $bytes->[5], $bytes->[6];
        $data = $bytes->[7];
    }
    elsif ( $type == 0x15 ) {
        if ( $subtype == 0x00 ) {    #Blyss
            $device = sprintf '%02x%02x%c%d', $bytes->[3], $bytes->[4], $bytes->[5], $bytes->[6];
        }
        else {                       #Cuveo
            $device = sprintf '%02x%02x%d%d', $bytes->[3], $bytes->[4], $bytes->[5], $bytes->[6];
        }
        $data = $bytes->[7];
    }
    elsif ( $type == 0x16 ) {        #Chime
        if ( $subtype == 0x00 ) {
            $device = sprintf '%02x', $bytes->[4];
            $data = $bytes->[5];
        }
        else {
            $device = sprintf '%04x', $bytes->[4], $bytes->[5];    #forum #71568
            $data = 0;
        }
    }
    elsif ( $type == 0x17 ) {                                      # Fan
        $device = sprintf '%02x%02x%02x', $bytes->[3], $bytes->[4], $bytes->[5];
        $data = $bytes->[6];
    }
    elsif ( $type == 0x19 ) {                                      # Blinds1
        $device = sprintf '%02x%02x%02x%02x', $bytes->[3], $bytes->[4], $bytes->[5], $bytes->[6];
        $data = $bytes->[7];
    }
    elsif ( $type == 0x1A ) {                                      # RFY
        $device = printf '%02x%02x%02x%02x', $bytes->[3], $bytes->[4], $bytes->[5], $bytes->[6];
        $data = $bytes->[7];
    }
    else {
        $error = sprintf "TRX_LIGHT: wrong type=%02x", $type;
        Log3 $hash, 1, "TRX_LIGHT_parse_X10() " . $error;
        return $error;
    }
    my $hexdata = sprintf '%02x', $data;

    my $command = "";
    if ( exists $light_device_commands{$type_subtype} ) {
        my $code = $light_device_commands{$type_subtype};
        if ( exists $code->[$data] ) {
            $command = $code->[$data];
        }
        else {
            $error = sprintf "TRX_LIGHT: unknown cmd type_subtype=%02x cmd=%02x", $type_subtype, $data;
            Log3 $hash, 1, "TRX_LIGHT_parse_X10() " . $error;
            return $error;
        }
    }
    else {
        $error = sprintf "TRX_LIGHT: unknown type_subtype %02x data=%02x", $type_subtype, $data;
        Log3 $hash, 1, "TRX_LIGHT_parse_X10() " . $error;
        return $error;
    }

    #my @res;
    my $current = "";

    #--------------
    my $device_name = "TRX" . $DOT . $dev_type . $DOT . $device;
    Log3 $hash, 5, "TRX_LIGHT: device_name=$device_name data=$hexdata";

    my $firstdevice = 1;
    my $def         = $modules{TRX_LIGHT}{defptr}{$device_name};

    #Log3 $hash, 1, "TRX_LIGHT_parse_X10() device $device_name";
    if ( !$def ) {
        $firstdevice = 0;
        $def         = $modules{TRX_LIGHT}{defptr2}{$device_name};
        if ( !$def ) {
            Log3 $hash, 5, "TRX_LIGHT_parse_X10() UNDEFINED $device_name TRX_LIGHT $dev_type $device $dev_reading";
            Log3 $hash, 3, "TRX_LIGHT_parse_X10() Unknown device $device_name, please define it";
            return "UNDEFINED $device_name TRX_LIGHT $dev_type $device $dev_reading";

        }
    }

    # Use $def->{NAME}, because the device may be renamed:
    my $name = $def->{NAME};
    return "" if ( IsIgnored($name) );

    Log3 $name, 5, "TRX_LIGHT_parse_X10() $name devn=$device_name first=$firstdevice command=$command, cmd=$hexdata";

    my $n   = 0;
    my $tm  = TimeNow();
    my $val = "";

    my $device_type = $def->{TRX_LIGHT_type};

    my $sensor = "";

    if ( $device_type eq "MS14A" ) {

        # for ms14a behave like x10
        $device_type = "X10";
    }

    if ( lc( $def->{TRX_LIGHT_devicelog} ) eq "window" || lc( $def->{TRX_LIGHT_devicelog} ) eq "door" ) {
        $command = ( $command eq "on" ) ? "Open" : "Closed";
    }
    elsif ( lc( $def->{TRX_LIGHT_devicelog} ) eq "motion" ) {
        $command = ( $command eq "on" ) ? "alert" : "normal";
    }
    elsif ( lc( $def->{TRX_LIGHT_devicelog} ) eq "lightsensor" || lc( $def->{TRX_LIGHT_devicelog} ) eq "photosensor" ) {
        $command = ( $command eq "on" ) ? "dark" : "bright";
    }
    elsif ( lc( $def->{TRX_LIGHT_devicelog} ) eq "lock" ) {
        $command = ( $command eq "on" ) ? "Closed" : "Open";
    }
    elsif ( lc( $def->{TRX_LIGHT_devicelog} ) eq "ring" ) {
        $command = ( $command eq "on" ) ? "normal" : "alert";
    }

    readingsBeginUpdate($def);

    if ( $type == 0x10 || $type == 0x11 || $type == 0x14 || $type == 0x16 || $type == 0x15  || $type == 0x19 ) {

        # try to use it for all types:
        $current = $command;
        if ( $type == 0x11 && $command eq "level" ) {

            # append level number
            my $level = $bytes->[9];
            $current .= sprintf " %d", $level;
        }
        elsif ( $type == 0x14 && $command eq "level" ) {

            # append level number
            my $level = $bytes->[8];
            $current .= sprintf " %d", $level;
        }

        $sensor = $firstdevice == 1 ? $def->{TRX_LIGHT_devicelog} : $def->{TRX_LIGHT_devicelog2};
        $val .= $current;
        if ( $sensor ne "none" ) { readingsBulkUpdate( $def, $sensor, $current ); }
    }
    else {
        $error = sprintf "TRX_LIGHT: error unknown sensor type=%x device_type=%s devn=%s first=%d command=%s", $type,
          $device_type, $device_name, $firstdevice, $command;
        Log3 $name, 1, "TRX_LIGHT_parse_X10() " . $error;
        return $error;
    }

    if ( ( $firstdevice == 1 ) && $val ) {

        #$def->{STATE} = $val;
        readingsBulkUpdate( $def, "state", $val );
    }

    readingsEndUpdate( $def, 1 );

    return $name;
}

########################################################
# T R X _ L I G H T _ p a r s e _ P T 2 2 6 2 ( )
#-------------------------------------------------------
sub TRX_LIGHT_parse_PT2262 ($$) {
    my ( $hash, $bytes ) = @_;

    my $error = "";

    #my $device;

    my $type    = $bytes->[0];
    my $subtype = $bytes->[1];
    my $dev_type;
    my $dev_reading;
    my $rest;

    my $type_subtype = ( $type << 8 ) + $subtype;

    if ( exists $light_device_codes{$type_subtype} ) {
        my $rec = $light_device_codes{$type_subtype};
        ( $dev_type, $dev_reading ) = @$rec;
    }
    else {
        $error = sprintf "TRX_LIGHT: PT2262 error undefined type=%02x, subtype=%02x", $type, $subtype;
        Log3 $hash, 1, "TRX_LIGHT_parse_PT2262() " . $error;
        return $error;
    }

    my $device;

    $device = "";

    my $command = "error";
    my $current = "";

    my $hexdata    = sprintf '%02x%02x%02x', $bytes->[3], $bytes->[4], $bytes->[5];
    my $hex_length = length($hexdata);
    my $bin_length = $hex_length * 4;
    my $bindata    = unpack( "B$bin_length", pack( "H$hex_length", $hexdata ) );

    #my @a = ($bindata =~ /[0-1]{2}/g);
    my $base_4 = $bindata;
    $base_4 =~ s/(.)(.)/$1*2+$2/eg;

    my $codes = $base_4;

    #$codes =~ tr/0123/UMED/; # Up,Middle,Error,Down
    $codes =~ s/0/up /g;        #
    $codes =~ s/1/middle /g;    #
    $codes =~ s/2/err /g;       #
    $codes =~ s/3/down /g;      #

    my $device_name   = "TRX" . $DOT . $dev_type;
    my $command_codes = "";
    my $command_rest  = "";

    my $def;

    # look for defined device with longest ID matching first:
    for ( my $i = 11 ; $i > 0 ; $i-- ) {
        if ( $modules{TRX_LIGHT}{defptr}{ $device_name . $DOT . substr( $base_4, 0, $i ) } ) {
            $device = substr( $base_4, 0, $i );
            $def           = $modules{TRX_LIGHT}{defptr}{ $device_name . $DOT . substr( $base_4, 0, $i ) };
            $command_codes = $def->{TRX_LIGHT_commandcodes};
            $command_rest  = substr( $base_4, $i );
            Log3 $hash, 5,
"TRX_LIGHT_parse_PT2262() found device_name=$device_name i=$i code=$base_4 commandcodes='$command_codes' command_rest='$command_rest' ";
        }
    }

    #--------------
    if ( $device ne "" ) {

        # found a device
        Log3 $hash, 5, "TRX_LIGHT: PT2262 found device_name=$device_name data=$hexdata";
        $device_name .= $DOT . $device;
    }
    else {
        # no specific device found. Using generic one:
        Log3 $hash, 5, "TRX_LIGHT: PT2262 device_name=$device_name data=$hexdata";
        $def = $modules{TRX_LIGHT}{defptr}{$device_name};
        if ( !$def ) {
            $dev_reading = "";
            Log3 $hash, 5, "TRX_LIGHT_parse_PT2262() UNDEFINED $device_name TRX_LIGHT $dev_type $device $dev_reading";
            Log3 $hash, 3, "TRX_LIGHT_parse_PT2262() Unknown device $device_name, please define it";
            return "UNDEFINED $device_name TRX_LIGHT $dev_type $device $dev_reading";
        }
    }

    # Use $def->{NAME}, because the device may be renamed:
    my $name = $def->{NAME};
    return "" if ( IsIgnored($name) );

    Log3 $name, 5, "TRX_LIGHT_parse_PT2262() $name devn=$device_name command=$command, cmd=$hexdata";

    my $n   = 0;
    my $val = "";

    my $device_type = $def->{TRX_LIGHT_type};
    my $sensor      = $def->{TRX_LIGHT_devicelog};

    readingsBeginUpdate($def);

    $current = $command;

    if ( $device eq "" ) {

        #readingsBulkUpdate($def, "hex", $hexdata);
        #readingsBulkUpdate($def, "bin", $bindata);
        #readingsBulkUpdate($def, "base_4", $base_4);
        #readingsBulkUpdate($def, "codes", $codes);
        $val = $base_4;
    }
    else {
        # look for command code:
        $command_codes .= ",";

        #if ($command_codes =~ /$command_rest:(.*),/o ) {
        if ( $command_codes =~ /$command_rest:([a-z|A-Z]*),/ ) {
            Log3 $name, 5, "PT2262: found=$1";
            $command = $1;
        }
        Log3 $name, 5, "TRX_LIGHT_parse_PT2262() readingsBulkUpdate($def, $sensor, $command)";
        $val = $command;
        if ( $sensor ne "none" ) { readingsBulkUpdate( $def, $sensor, $val ); }
    }

    readingsBulkUpdate( $def, "state", $val );
    readingsEndUpdate( $def, 1 );

    return $name;
}

####################################
# T R X _ L I G H T _ P a r s e ( )
#-----------------------------------
sub TRX_LIGHT_Parse($$) {
    my ( $iohash, $hexline ) = @_;

    my $time = time();

    # convert to binary
    my $msg = pack( 'H*', $hexline );
    if ( $time_old == 0 ) {
        Log3 $iohash, 5, "TRX_LIGHT_Parse() decoding delay=0 hex=$hexline";
    }
    else {
        my $time_diff = $time - $time_old;
        Log3 $iohash, 5, "TRX_LIGHT_Parse() decoding delay=$time_diff hex=$hexline";
    }
    $time_old = $time;

    # convert string to array of bytes. Skip length byte
    my @rfxcom_data_array = ();
    foreach ( split( //, substr( $msg, 1 ) ) ) {
        push( @rfxcom_data_array, ord($_) );
    }

    my $num_bytes = ord($msg);

    if ( $num_bytes < 3 ) {
        return "";
    }

    my $type = $rfxcom_data_array[0];

    #Log3 $iohash, 5, "TRX_LIGHT: num_bytes=$num_bytes hex=$hexline type=$type";
    my $res = "";
    if (   $type == 0x10
        || $type == 0x11
        || $type == 0x12
        || $type == 0x14
        || $type == 0x15
        || $type == 0x16
        || $type == 0x17
        || $type == 0x18
        || $type == 0x19 )
    {
        Log3 $iohash, 5, "TRX_LIGHT_Parse() X10 num_bytes=$num_bytes hex=$hexline";
        $res = TRX_LIGHT_parse_X10( $iohash, \@rfxcom_data_array );
        Log3 $iohash, 1, "TRX_LIGHT_Parse() unsupported hex=$hexline" if ( $res eq "" );
        return $res;
    }
    elsif ( $type == 0x13 ) {
        Log3 $iohash, 5, "TRX_LIGHT_Parse()Lighting4/PT2262 num_bytes=$num_bytes hex=$hexline";
        $res = TRX_LIGHT_parse_PT2262( $iohash, \@rfxcom_data_array );
        Log3 $iohash, 1, "TRX_LIGHT_Parse() unsupported hex=$hexline" if ( $res eq "" );
        return $res;
    }
    else {
        Log3 $iohash, 1, "TRX_LIGHT_Parse() not implemented num_bytes=$num_bytes hex=$hexline";
    }

    return "";
}

1;

=pod
=item device
=item summary Sends and receive messages of lighting devices via TRX (RFXCOM)
=item summary_DE Sendet und empfängt Nachrichten von Schaltaktoren via TRX (RFXCOM)
=begin html

<a name="TRX_LIGHT"></a>
<h3>TRX_LIGHT</h3>
<ul>
  The TRX_LIGHT module receives and sends X10, ARC, ELRO AB400D, Waveman, Chacon EMW200, IMPULS, RisingSun, AC, HomeEasy EU and ANSLUT lighting devices (switches and remote control). Allows to send Philips SBC (receive not possible). ARC is a protocol used by devices from HomeEasy, KlikAanKlikUit, ByeByeStandBy, Intertechno, ELRO, AB600, Duewi, DomiaLite and COCO with address code wheels. AC is the protocol used by different brands with units having a learning mode button:
KlikAanKlikUit, NEXA, CHACON, HomeEasy UK. <br> You need to define an RFXtrx433 transceiver receiver first.
  See <a href="#TRX">TRX</a>.

  <br><br>

  <a name="TRX_LIGHTdefine"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; TRX_LIGHT &lt;type&gt; &lt;deviceid&gt; &lt;devicelog&gt; [&lt;deviceid2&gt; &lt;devicelog2&gt;] </code> <br>
    <code>define &lt;name&gt; TRX_LIGHT PT2262 &lt;deviceid&gt; &lt;devicelog&gt; &lt;commandcodes&gt;</code> <br>
    <br>
    <code>&lt;type&gt;</code>
    <ul>
      specifies the type of the device: <br>
      Lighting devices:
        <ul>
          <li> <code>MS14A</code> (X10 motion sensor. Reports [normal|alert] on the first deviceid (motion sensor) and [on|off] for the second deviceid (light sensor)) </li>
          <li> <code>X10</code> (All other x10 devices. Report [off|on|dim|bright|all_off|all_on] on both deviceids.)</li>
          <li> <code>ARC</code> (ARC devices. ARC is a protocol used by devices from HomeEasy, KlikAanKlikUit, ByeByeStandBy, Intertechno, ELRO, AB600, Duewi, DomiaLite and COCO with address code wheels. Report [off|on|all_off|all_on|chime].)</li>
          <li> <code>AB400D</code> (ELRO AB400D devices. Report [off|on].)</li>
          <li> <code>WAVEMAN</code> (Waveman devices. Report [off|on].)</li>
          <li> <code>EMW200</code> (Chacon EMW200 devices. Report [off|on|all_off|all_on].)</li>
          <li> <code>IMPULS</code> (IMPULS devices. Report [off|on].)</li>
          <li> <code>RISINGSUN</code> (RisingSun devices. Report [off|on].)</li>
          <li> <code>PHILIPS_SBC</code> (Philips SBC devices. Send [off|on|all_off|all_on].)</li>
          <li> <code>ENER010</code> (Energenie ENER010 devices. deviceid: [A-P][1-4]. Send [off|on|all_off|all_on].)</li>
          <li> <code>ENER5</code> (Energenie 5-gang devices. deviceid: [A-P][1-10]. Send [off|on].)</li>
          <li> <code>COCO_GDR2</code> (ECOCO GDR2-2000R devices. deviceid: [A-D][1-4]. Send [off|on].)</li>
          <li> <code>AC</code> (AC devices. AC is the protocol used by different brands with units having a learning mode button: KlikAanKlikUit, NEXA, CHACON, HomeEasy UK. Report [off|on|level &lt;NUM&gt;|all_off|all_on|all_level &lt;NUM&gt;].)</li>
          <li> <code>HOMEEASY</code> (HomeEasy EU devices. Report [off|on|level|all_off|all_on|all_level].)</li>
          <li> <code>ANSLUT</code> (Anslut devices. Report [off|on|level|all_off|all_on|all_level].)</li>
          <li> <code>PT2262</code> (Devices using PT2262/PT2272 (coder/decoder) chip. To use this enable Lighting4 in RFXmngr. Please note that this disables ARC. For more information see <a href="http://www.fhemwiki.de/wiki/RFXtrx#PT2262_empfangen_und_senden_mit_TRX_LIGHT.pm">FHEM-Wiki</a>)</li>
	  <li> <code>LIGHTWAVERF</code> (LightwaveRF devices. Commands ["off", "on", "all_off", "mood1", "mood2", "mood3", "mood4", "mood5", "reserved1", "reserved2", "unlock", "lock", "all_lock", "close", "stop", "open", "level"].)</li>
	  <li> <code>EMW100</code> (EMW100 devices. Commands ["off", "on", "learn"].)</li>
	  <li> <code>BBSB</code> (BBSB devices. Commands ["off", "on", "all_off", "all_on"].)</li>
	  <li> <code>MDREMOTE</code> (MDREMOTE LED dimmer devices. Commands ["power", "light", "bright", "dim", "100", "50", "25", "mode+", "speed-", "speed+", "mode-"].)</li>
	  <li> <code>RSL2</code> (Conrad RSL2 devices. Commands ["off", "on", "all_off", "all_on"].)</li>
	  <li> <code>LIVOLO</code> (Livolo devices. Commands ["all_off", "on_off", "dim+", "dim-"].)</li>
	  <li> <code>TRC02</code> (RGB TRC02 devices. Commands ["off", "on", "bright", "dim", "vivid", "pale", "color"].)</li>
	  <li> <code>BLYSS</code> (Blyss devices. deviceid: [A-P][1-5]. Commands ["off", "on", "all_off", "all_on"].)</li>
	  <li> <code>CUVEO</code> (Cuveo devices. deviceid: [A-P][1-5]. Commands ["off", "on", "all_off", "all_on"].)</li>
	  <li> <code>BYRONSX</code> (Byron SX chime devices. deviceid: 00-FF. Commands [ "tubular3_1", "solo1", "bigben1", "tubular2_1", "tubular2_2", "solo2", "tubular3_2"].)</li>
	  <li> <code>SELECTPLUS</code> (SELECTPLUS] chime devices. deviceid: 0000-FFFF. Commands [ "ring"].)</li>
	  <li> <code>SIEMENS_SF01</code> (Siemens SF01 devices. deviceid: 000000-007FFF. Commands [ "timer", "-", "learn", "+", "confirm", "light", "on", "off" ].)</li>
	  <li> <code>HARRISON</code> (Harrison curtain devices. deviceid: 00-FF. Commands [ "open", "close", "stop", "program" ].)</li>
	  <li> <code>ROLLER_TROL</code> (Roller Trol blind devices. deviceid: 00000100-00FFFF0F. Commands [ "open", "close", "stop", "confirm_pair", "set_limit" ].)</li>
	  <li> <code>HASTA_OLD</code> (Hasta old blind devices. deviceid: 00000100-00FFFF0F. Commands [ "open", "close", "stop", "confirm_pair", "set_limit" ].)</li>
	  <li> <code>AOK_RF01</code> (A-OK RF01 blind devices. deviceid: 00000100-FFFFFF0F. Commands [ "open", "close", "stop", "confirm_pair" ].)</li>
	  <li> <code>AOK_AC114</code> (A-OK AC114 blind devices. deviceid: 00000100-FFFFFF0F. Commands [ "open", "close", "stop", "confirm_pair" ].)</li>
	  <li> <code>RAEX_YR1326</code> (Raex YR1326 blind devices. deviceid: 00000100-FFFFFF0F. Commands [ "open", "close", "stop", "confirm_pair", "set_upper_limit", "set_lower_limit", "delete_limits", "change_dir", "left", "right"].)</li>
	  <li> <code>MEDIA_MOUNT</code> (Media Mount blind devices. deviceid: 00000100-FFFFFF0F. Commands [ "down", "up", "stop" ].)</li>
	  <li> <code>DC106</code> (DC/RMF/Yooda blind devices. deviceid: 00000100-FFFFFFF0. Commands [ "open", "close", "stop", "confirm" ].)</li>
	  <li> <code>FOREST</code> (Forest blind devices. deviceid: 00000100-FFFFFFF0. Commands [ "open", "close", "stop", "confirm_pair" ].)</li>
	  <li> <code>RFY</code> (Somfy RTS devices. deviceid: 000001-0FFFFF, unicode: 01-04 (00 = allunits). Commands [ "up", "down", "stop", "program" ].)</li>
	  <li> <code>RFY_ext</code> (Somfy RTS devices. deviceid: 000001-0FFFFF, unicode: 00-0F. Commands [ "up", "down", "stop", "program" ].)</li>
        </ul>
    </ul>
    <br>
    <code>&lt;deviceid&gt;</code>
    <ul>
    specifies the first device id of the device. <br>
    A lighting device normally has a house code A..P followed by a unitcode 1..16 (example "B1").<br>
    For AC, HomeEasy EU and ANSLUT it is a 10 Character-Hex-String for the deviceid, consisting of <br>
	- unid-id: 8-Char-Hex: 00000001 to 03FFFFFF<br>
	- unit-code: 2-Char-Hex: 01 to 10  <br>
    For LIGHTWAVERF, EMW100, BBSB, MDREMOTE, RSL2, LIVOLO and TRC02 it is a 8 Character-Hex-String for the deviceid, consisting of <br>
	- unid-id: 8-Char-Hex: 000001 to FFFFFF<br>
	- unit-code: 2-Char-Hex: 01 to 10  <br>
    For RFY and RFY-ext it is a 8 Character-Hex-String for the deviceid, consisting of <br>
	- unid-id: 8-Char-Hex: 000001 to FFFFFF<br>
	- unit-code: 2-Char-Hex: 01 to 04 for RFY (00 for all units) and 00 to 0F for RFY_ext  <br>
    </ul>
    <br>
    <code>&lt;devicelog&gt;</code>
    <ul>
    is the name of the Reading used to report. Suggested: "motion" for motion sensors. If you use "none" then no additional Reading is reported. Just the state is used to report the change.
    </ul>
    <br>
    <code>&lt;deviceid2&gt;</code>
    <ul>
    is optional and specifies the second device id of the device if it exists. For example ms14a motion sensors report motion status on the first deviceid and the status of the light sensor on the second deviceid.
    </ul>
    <br>
    <code>&lt;devicelog2&gt;</code>
    <ul>
    is optional for the name used for the Reading of <code>&lt;deviceid2&gt;</code>.If you use "none" then no addional Reading is reported. Just the state is used to report the change.
    </ul>
    <br>
    <code>&lt;commandcodes&gt;</code>
    <ul>
    is used for PT2262 and specifies the possible base4 digits for the command separated by : and a string that specifies a string that is the command. Example '<code>0:off,1:on</code>'.
    </ul>
    <br>
      Example: <br>
    	<code>define motion_sensor2 TRX_LIGHT MS14A A1 motion A2 light</code>
	<br>
    	<code>define Steckdose TRX_LIGHT ARC G2 light</code>
	<br>
    	<code>define light TRX_LIGHT AC 0101010101 light</code>
      <br>
  </ul>
  <br>

  <a name="TRX_LIGHTset"></a>
  <b>Set </b>
  <ul>
    <code>set &lt;name&gt; &lt;value&gt; [&lt;levelnum&gt;]</code>
    <br><br>
    where <code>value</code> is one of:<br>
	<ul>
    <li>off</li>
    <li>on</li>
    <li>dim                # only for X10, KOPPLA</li>
    <li>bright             # only for X10, KOPPLA</li>
    <li>all_off            # only for X10, ARC, EMW200, AC, HOMEEASY, ANSLUT</li>
    <li>all_on             # only for X10, ARC, EMW200, AC, HOMEEASY, ANSLUT</li>
    <li>chime              # only for ARC</li>
    <li>level &lt;levelnum&gt;    # only AC, HOMEEASY, ANSLUT: set level to &lt;levelnum&gt; (range: 0=0% to 15=100%)</li>
    <li>ring              # Byron MP001,SelectPlus, RFU, Envivo</li>
	<li><a href="#setExtensions">setExtensions</a>		# see Notes</li>
	</ul>
      Example: <br>
    	<code>set Steckdose on</code>
      <br>
    <br>
    Notes:
    <ul>
      <li><code>on-for-timer</code> earlier required an absolute time in the "at" format. TRX_LIGHT is now using <a href="#setExtensions">SetExtensions</a>, thus <code>on-for-timer</code> now requires a number (seconds). TimeSpecs in the format (HH:MM:SS|HH:MM) or { &lt;perl code&gt; } are automatically converted, however it is recommended that you adjust your set commands. 
          </li>
    </ul>
  </ul><br>

  <a name="TRX_LIGHTget"></a>
  <b>Get</b> <ul>N/A</ul><br>

  <a name="TRX_LIGHTattr"></a>
  <b>Attributes</b>
  <ul>
    <li><a href="#ignore">ignore</a></li>
    <li><a href="#do_not_notify">do_not_notify</a></li>
    <li><a href="#readingFnAttributes">readingFnAttributes</a></li>
  </ul>

</ul>

=end html
=cut
