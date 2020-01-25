################################################################################################
#
# $Id: 24_Iluminize.pm 17537 2018-10-15 16:08:23Z vk $
#
#
#  Copyright notice
#
#  Release 2018-10 First version
#
#  (c) 2018 Copyright: Volker Kettenbach
#  e-mail: volker at kettenbach minus it dot de
#
#  Description:
#  This is an FHEM-Module for the Iluinize LED Stripes,
#
#  Requirements:
#  This module requires:
#  	Perl Module: IO::Socket::INET
#  	Perl Module: IO::Socket::Timeout
#  On a Debian (based) system, these requirements can be fullfilled by:
#   apt-get install install libio-socket-inet6-perl libio-socket-timeout-perl
#
#  Origin:
#  https://gitlab.com/volkerkettenbach/FHEM-Iluminize
#
#  Support: https://forum.fhem.de/index.php/topic,92007.0.html
#
#
#################################################################################################

package main;

use strict;
use warnings;

sub Iluminize_Initialize($)
{
    my ($hash) = @_;

    $hash->{DefFn}      = "Iluminize::Define";
    $hash->{ReadFn}     = "Iluminize::Get";
    $hash->{SetFn}      = "Iluminize::Set";
    $hash->{UndefFn}    = "Iluminize::Undefine";
    $hash->{DeleteFn}   = "Iluminize::Delete";
    $hash->{AttrFn}     = "Iluminize::Attr";
    $hash->{AttrList}   = "$readingFnAttributes";
}



package Iluminize;

use strict;
use warnings;
use POSIX;
use IO::Socket::INET;
use IO::Socket::Timeout;
use SetExtensions;
use GPUtils qw(:all);  # wird für den Import der FHEM Funktionen aus der fhem.pl benötigt

## Import der FHEM Funktionen
BEGIN {
    GP_Import(qw(
        readingsSingleUpdate
        readingsBulkUpdate
        readingsBulkUpdateIfChanged
        readingsBeginUpdate
        readingsEndUpdate
        Log3
        CommandAttr
        AttrVal
        ReadingsVal
        CommandDefMod
        modules
        setKeyValue
        getKeyValue
        getUniqueId
        RemoveInternalTimer
        InternalTimer
        defs
        init_done
        IsDisabled
        deviceEvents
        HttpUtils_NonblockingGet
        gettimeofday
        Dispatch
        SetExtensions
    ))
};

my $on =
    chr(hex("55")) .
    chr(hex("99")) .
    chr(hex("5e")) .
    chr(hex("bb")) .
    chr(hex("01")) .
    chr(hex("02")) .
    chr(hex("02")) .
    chr(hex("12")) .
    chr(hex("ab")) .
    chr(hex("c2")) .
    chr(hex("aa")) .
    chr(hex("aa"));

my $off=
    chr(hex("55")) .
    chr(hex("99")) .
    chr(hex("5e")) .
    chr(hex("bb")) .
    chr(hex("01")) .
    chr(hex("02")) .
    chr(hex("02")) .
    chr(hex("12")) .
    chr(hex("a9")) .
    chr(hex("c0")) .
    chr(hex("aa")) .
    chr(hex("aa"));


sub Define($$)
{
    my ($hash, $def) = @_;
    my $name= $hash->{NAME};

    my @a = split( "[ \t][ \t]*", $def );
    return "Wrong syntax: use define <name> Iluminize <hostname/ip> " if (int(@a) != 3);

    $hash->{HOST}=$a[2];

    Log3 $hash, 0, "Iluminize: $name defined.";

    return undef;
}

# No get so far
sub Get($$) {}


sub Set($$)
{
    my ($hash, $name, $cmd, @args) = @_;
    my $cmdList = "on off";

    my $remote_host = $hash->{HOST};
    my $remote_port = 8899;

    Log3 $hash, 3, "Iluminize: $name Set <". $cmd ."> called" if ($cmd !~ /\?/);

    return "\"set $name\" needs at least one argument" unless(defined($cmd));

    my $command;
    if ($cmd eq "on") {
        $command = $on;
        readingsSingleUpdate($hash, "state", "on", 1);
    } elsif($cmd eq "off") {
        $command = $off;
        readingsSingleUpdate($hash, "state", "off", 1);
    } else {
        return SetExtensions($hash, $cmdList, $name, $cmd, @args);
    }

    my $socket = IO::Socket::INET->new(PeerAddr => $remote_host,
        PeerPort => $remote_port,
        Proto    => 'tcp',
        Type     => SOCK_STREAM,
        Timeout  => 2 )
        or return "Couldn't connect to $remote_host:$remote_port: $@\n";

    $socket->write($command);

    return undef;
}


sub Undefine($$)
{
    my ($hash, $arg) = @_;
    my $name= $hash->{NAME};
    Log3 $hash, 4, "Iluminize: $name undefined.";
    return;
}



sub Delete($$) {
    my ($hash, $arg) = @_;
    my $name= $hash->{NAME};
    Log3 $hash, 0, "Ilumnize: $name deleted.";
    return undef;
}



sub Attr($$$$) {
    my ($cmd, $name, $aName, $aVal) = @_;
    my $hash = $defs{$name};

    return undef;
}

1;


=pod
=item summary Support for Iluminize wifi controlled led stripe
=item summary_DE Support für die Iluminize wlan LED-Produkte

=begin html

<a name="Iluminize"></a>
<h3>Iluminize</h3>
  <br>
    <a name="Iluminize"></a>
    <b>Define</b>
    <code>define &lt;name&gt; Iluminize &lt;ip/hostname&gt;</code><br>
    	<br>
    	Defines a wifi controlled Iluminize LED light

=end html

=begin html_DE

<a name="Iluminize"></a>
<h3>Iluminize</h3>
  <br>
    <a name="Iluminize"></a>
    <b>Define</b>
    <code>define &lt;name&gt; Iluminize &lt;ip/hostname&gt;</code><br>
    	<br>
    	Definiert ein Iluminize LED Wifi-Licht

=end html_DE

