###############################################################################
#
# Developed with Kate
#
#  (c) 2017-2019 Copyright: Marko Oldenburg (leongaultier at gmail dot com)
#  All rights reserved
#
#   Special thanks goes to:
#       - Dusty Wilson      Inspiration and parts of Code
#                           http://search.cpan.org/~wilsond/Linux-APT-0.02/lib/Linux/APT.pm
#
#
#  This script is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  any later version.
#
#  The GNU General Public License can be found at
#  http://www.gnu.org/copyleft/gpl.html.
#  A copy is found in the textfile GPL.txt and important notices to the license
#  from the author is found in LICENSE.txt distributed with these scripts.
#
#  This script is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#
# $Id: 42_AptToDate.pm 19639 2019-06-18 13:43:31Z CoolTux $
#
###############################################################################

## unserer packagename
package FHEM::AptToDate;

use strict;
use warnings;
use POSIX;
use FHEM::Meta;

use GPUtils qw(GP_Import)
  ;    # wird für den Import der FHEM Funktionen aus der fhem.pl benötigt

use Data::Dumper;    #only for Debugging
our $VERSION = 'v1.4.5';

# try to use JSON::MaybeXS wrapper
#   for chance of better performance + open code
eval {
    require JSON::MaybeXS;
    import JSON::MaybeXS qw( decode_json encode_json );
    1;
};

if ($@) {
    $@ = undef;

    # try to use JSON wrapper
    #   for chance of better performance
    eval {

        # JSON preference order
        local $ENV{PERL_JSON_BACKEND} =
          'Cpanel::JSON::XS,JSON::XS,JSON::PP,JSON::backportPP'
          unless ( defined( $ENV{PERL_JSON_BACKEND} ) );

        require JSON;
        import JSON qw( decode_json encode_json );
        1;
    };

    if ($@) {
        $@ = undef;

        # In rare cases, Cpanel::JSON::XS may
        #   be installed but JSON|JSON::MaybeXS not ...
        eval {
            require Cpanel::JSON::XS;
            import Cpanel::JSON::XS qw(decode_json encode_json);
            1;
        };

        if ($@) {
            $@ = undef;

            # In rare cases, JSON::XS may
            #   be installed but JSON not ...
            eval {
                require JSON::XS;
                import JSON::XS qw(decode_json encode_json);
                1;
            };

            if ($@) {
                $@ = undef;

                # Fallback to built-in JSON which SHOULD
                #   be available since 5.014 ...
                eval {
                    require JSON::PP;
                    import JSON::PP qw(decode_json encode_json);
                    1;
                };

                if ($@) {
                    $@ = undef;

                    # Fallback to JSON::backportPP in really rare cases
                    require JSON::backportPP;
                    import JSON::backportPP qw(decode_json encode_json);
                    1;
                }
            }
        }
    }
}

## Import der FHEM Funktionen
#-- Run before package compilation
BEGIN {

    # Import from main context
    GP_Import(
        qw(readingsSingleUpdate
          readingsBulkUpdate
          readingsBulkUpdateIfChanged
          readingsBeginUpdate
          readingsEndUpdate
          ReadingsTimestamp
          defs
          readingFnAttributes
          modules
          Log3
          CommandAttr
          attr
          AttrVal
          ReadingsVal
          Value
          IsDisabled
          deviceEvents
          init_done
          gettimeofday
          InternalTimer
          RemoveInternalTimer)
    );
}

# _Export - Export references to main context using a different naming schema
sub _Export {
    no strict qw/refs/;    ## no critic
    my $pkg  = caller(0);
    my $main = $pkg;
    $main =~ s/^(?:.+::)?([^:]+)$/main::$1\_/g;
    foreach (@_) {
        *{ $main . $_ } = *{ $pkg . '::' . $_ };
    }
}

#-- Export to main context with different name
_Export(
    qw(
      Initialize
      )
);

my %regex = (
    'en' => {
        'update'  => '^Reading package lists...$',
        'upgrade' => '^Unpacking (\S+)\s\((\S+)\)\s+over\s+\((\S+)\)'
    },
    'de' => {
        'update'  => '^Paketlisten werden gelesen...$',
        'upgrade' => '^Entpacken von (\S+)\s\((\S+)\)\s+über\s+\((\S+)\)'
    }
);

sub Initialize($) {

    my ($hash) = @_;

    $hash->{SetFn}    = "FHEM::AptToDate::Set";
    $hash->{GetFn}    = "FHEM::AptToDate::Get";
    $hash->{DefFn}    = "FHEM::AptToDate::Define";
    $hash->{NotifyFn} = "FHEM::AptToDate::Notify";
    $hash->{UndefFn}  = "FHEM::AptToDate::Undef";
    $hash->{AttrFn}   = "FHEM::AptToDate::Attr";
    $hash->{AttrList} =
        "disable:1 "
      . "disabledForIntervals "
      . "upgradeListReading:1 "
      . "distupgrade:1 "
      . $readingFnAttributes;

    foreach my $d ( sort keys %{ $modules{AptToDate}{defptr} } ) {
        my $hash = $modules{AptToDate}{defptr}{$d};
        $hash->{VERSION} = $VERSION;
    }
    
    return FHEM::Meta::InitMod( __FILE__, $hash );
}

sub Define($$) {

    my ( $hash, $def ) = @_;
    my @a = split( "[ \t][ \t]*", $def );

    return $@ unless ( FHEM::Meta::SetInternals($hash) );
    return "too few parameters: define <name> AptToDate <HOST>" if ( @a != 3 );

    my $name = $a[0];
    my $host = $a[2];

    $hash->{VERSION}   = $VERSION;
    $hash->{HOST}      = $host;
    $hash->{NOTIFYDEV} = "global,$name";

    readingsSingleUpdate( $hash, "state", "initialized", 1 )
      if ( ReadingsVal( $name, 'state', 'none' ) ne 'none' );
    CommandAttr( undef, $name . ' room AptToDate' )
      if ( AttrVal( $name, 'room', 'none' ) eq 'none' );
    CommandAttr( undef,
        $name
          . ' devStateIcon system.updates.available:security@red system.is.up.to.date:security@green .*in.progress:system_fhem_reboot@orange errors:message_attention@red'
    ) if ( AttrVal( $name, 'devStateIcon', 'none' ) eq 'none' );

    Log3 $name, 3, "AptToDate ($name) - defined";

    $modules{AptToDate}{defptr}{ $hash->{HOST} } = $hash;

    return undef;
}

sub Undef($$) {

    my ( $hash, $arg ) = @_;

    my $name = $hash->{NAME};

    if ( exists( $hash->{".fhem"}{subprocess} ) ) {
        my $subprocess = $hash->{".fhem"}{subprocess};
        $subprocess->terminate();
        $subprocess->wait();
    }

    RemoveInternalTimer($hash);

    delete( $modules{AptToDate}{defptr}{ $hash->{HOST} } );
    Log3 $name, 3, "Sub AptToDate ($name) - delete device $name";
    return undef;
}

sub Attr(@) {

    my ( $cmd, $name, $attrName, $attrVal ) = @_;
    my $hash = $defs{$name};

    if ( $attrName eq "disable" ) {
        if ( $cmd eq "set" and $attrVal eq "1" ) {
            RemoveInternalTimer($hash);

            readingsSingleUpdate( $hash, "state", "disabled", 1 );
            Log3 $name, 3, "AptToDate ($name) - disabled";
        }

        elsif ( $cmd eq "del" ) {
            Log3 $name, 3, "AptToDate ($name) - enabled";
        }
    }

    elsif ( $attrName eq "disabledForIntervals" ) {
        if ( $cmd eq "set" ) {
            return
"check disabledForIntervals Syntax HH:MM-HH:MM or 'HH:MM-HH:MM HH:MM-HH:MM ...'"
              unless ( $attrVal =~ /^((\d{2}:\d{2})-(\d{2}:\d{2})\s?)+$/ );
            Log3 $name, 3, "AptToDate ($name) - disabledForIntervals";
            readingsSingleUpdate( $hash, "state", "disabled", 1 );
        }

        elsif ( $cmd eq "del" ) {
            Log3 $name, 3, "AptToDate ($name) - enabled";
            readingsSingleUpdate( $hash, "state", "active", 1 );
        }
    }

    return undef;
}

sub Notify($$) {

    my ( $hash, $dev ) = @_;
    my $name = $hash->{NAME};
    return if ( IsDisabled($name) );

    my $devname = $dev->{NAME};
    my $devtype = $dev->{TYPE};
    my $events  = deviceEvents( $dev, 1 );
    return if ( !$events );

    Log3 $name, 5, "AptToDate ($name) - Notify: " . Dumper $events; # mit Dumper

    if (
        (
            (
                grep /^DEFINED.$name$/,
                @{$events}
                or grep /^DELETEATTR.$name.disable$/,
                @{$events}
                or grep /^ATTR.$name.disable.0$/,
                @{$events}
            )
            and $devname eq 'global'
            and $init_done
        )
        or (
            (
                grep /^INITIALIZED$/,
                @{$events}
                or grep /^REREADCFG$/,
                @{$events}
                or grep /^MODIFIED.$name$/,
                @{$events}
            )
            and $devname eq 'global'
        )
        or grep /^os-release_language:.(de|en)$/,
        @{$events}
      )
    {

        if (
            ref(
                eval { decode_json( ReadingsVal( $name, '.upgradeList', '' ) ) }
            ) eq "HASH"
          )
        {
            $hash->{".fhem"}{aptget}{packages} =
              eval { decode_json( ReadingsVal( $name, '.upgradeList', '' ) ) }
              ->{packages};
        }
        elsif (
            ref(
                eval { decode_json( ReadingsVal( $name, '.updatedList', '' ) ) }
            ) eq "HASH"
          )
        {
            $hash->{".fhem"}{aptget}{updatedpackages} =
              eval { decode_json( ReadingsVal( $name, '.updatedList', '' ) ) }
              ->{packages};
        }

        if ( ReadingsVal( $name, 'os-release_language', 'none' ) ne 'none' ) {
            ProcessUpdateTimer($hash);

        }
        else {
            $hash->{".fhem"}{aptget}{cmd} = 'getDistribution';
            AsynchronousExecuteAptGetCommand($hash);
        }
    }

    if (
        $devname eq $name
        and (
            grep /^repoSync:.fetched.done$/,
            @{$events} or grep /^toUpgrade:.successful$/,
            @{$events}
        )
      )
    {
        $hash->{".fhem"}{aptget}{cmd} = 'getUpdateList';
        AsynchronousExecuteAptGetCommand($hash);
    }

    return;
}

sub Set($$@) {

    my ( $hash, $name, @aa ) = @_;

    my ( $cmd, @args ) = @aa;

    if ( $cmd eq 'repoSync' ) {
        return "usage: $cmd" if ( @args != 0 );

        $hash->{".fhem"}{aptget}{cmd} = $cmd;

    }
    elsif ( $cmd eq 'toUpgrade' ) {
        return "usage: $cmd" if ( @args != 0 );

        $hash->{".fhem"}{aptget}{cmd} = $cmd;

    }
    else {
        my $list = "repoSync:noArg";
        $list .= " toUpgrade:noArg"
          if ( defined( $hash->{".fhem"}{aptget}{packages} )
            and scalar keys %{ $hash->{".fhem"}{aptget}{packages} } > 0 );

        return "Unknown argument $cmd, choose one of $list";
    }

    if (   ReadingsVal( $name, 'os-release_language', 'none' ) eq 'de'
        or ReadingsVal( $name, 'os-release_language', 'none' ) eq 'en' )
    {
        AsynchronousExecuteAptGetCommand($hash);
    }
    else {
        readingsSingleUpdate( $hash, "state", "language not supported", 1 );
        Log3 $name, 2,
          "AptToDate ($name) - sorry, your systems language is not supported";
    }

    return undef;
}

sub Get($$@) {

    my ( $hash, $name, @aa ) = @_;

    my ( $cmd, @args ) = @aa;

    if ( $cmd eq 'showUpgradeList' ) {
        return "usage: $cmd" if ( @args != 0 );

        my $ret = CreateUpgradeList( $hash, $cmd );
        return $ret;

    }
    elsif ( $cmd eq 'showUpdatedList' ) {
        return "usage: $cmd" if ( @args != 0 );

        my $ret = CreateUpgradeList( $hash, $cmd );
        return $ret;

    }
    elsif ( $cmd eq 'showWarningList' ) {
        return "usage: $cmd" if ( @args != 0 );

        my $ret = CreateWarningList($hash);
        return $ret;

    }
    elsif ( $cmd eq 'showErrorList' ) {
        return "usage: $cmd" if ( @args != 0 );

        my $ret = CreateErrorList($hash);
        return $ret;
    }
    elsif ( $cmd eq 'distributionInfo' ) {
        return "usage: $cmd" if ( @args != 0 );

        $hash->{".fhem"}{aptget}{cmd} = 'getDistribution';
        AsynchronousExecuteAptGetCommand($hash);
    }
    else {
        my $list = "";
        $list .= " distributionInfo:noArg"
          unless ( ReadingsVal( $name, 'os-release_language', 'none' ) eq 'none' );
        $list .= " showUpgradeList:noArg"
          if ( defined( $hash->{".fhem"}{aptget}{packages} )
            and scalar keys %{ $hash->{".fhem"}{aptget}{packages} } > 0 );
        $list .= " showUpdatedList:noArg"
          if ( defined( $hash->{".fhem"}{aptget}{updatedpackages} )
            and scalar
            keys %{ $hash->{".fhem"}{aptget}{updatedpackages} } > 0 );
        $list .= " showWarningList:noArg"
          if ( defined( $hash->{".fhem"}{aptget}{'warnings'} )
            and scalar @{ $hash->{".fhem"}{aptget}{'warnings'} } > 0 );
        $list .= " showErrorList:noArg"
          if ( defined( $hash->{".fhem"}{aptget}{'errors'} )
            and scalar @{ $hash->{".fhem"}{aptget}{'errors'} } > 0 );

        return "Unknown argument $cmd, choose one of $list";
    }
}

###################################
sub ProcessUpdateTimer($) {

    my $hash = shift;

    my $name = $hash->{NAME};

    RemoveInternalTimer($hash);
    InternalTimer(
        gettimeofday() + 14400,
        "FHEM::AptToDate::ProcessUpdateTimer",
        $hash, 0
    );
    Log3 $name, 4, "AptToDate ($name) - stateRequestTimer: Call Request Timer";

    if (   ReadingsVal( $name, 'os-release_language', 'none' ) eq 'de'
        or ReadingsVal( $name, 'os-release_language', 'none' ) eq 'en' )
    {
        if ( !IsDisabled($name) ) {
            if ( exists( $hash->{".fhem"}{subprocess} ) ) {
                Log3 $name, 2,
                  "AptToDate ($name) - update in progress, process aborted.";
                return 0;
            }

            readingsSingleUpdate( $hash, "state", "ready", 1 )
              if ( ReadingsVal( $name, 'state', 'none' ) eq 'none'
                or ReadingsVal( $name, 'state', 'none' ) eq 'initialized' );

            if (
                ToDay() ne (
                    split(
                        ' ',
                        ReadingsTimestamp( $name, 'repoSync', '1970-01-01' )
                    )
                )[0]
              )
            {
                $hash->{".fhem"}{aptget}{cmd} = 'repoSync';
                AsynchronousExecuteAptGetCommand($hash);
            }
        }
    }
    else {
        readingsSingleUpdate( $hash, "state", "language not supported", 1 );
        Log3 $name, 2,
          "AptToDate ($name) - sorry, your systems language is not supported";
    }
}

sub CleanSubprocess($) {

    my $hash = shift;

    my $name = $hash->{NAME};

    delete( $hash->{".fhem"}{subprocess} );
    Log3 $name, 4, "AptToDate ($name) - clean Subprocess";
}

use constant POLLINTERVAL => 1;

sub AsynchronousExecuteAptGetCommand($) {

    require "SubProcess.pm";
    my ($hash) = shift;

    my $name = $hash->{NAME};
    $hash->{".fhem"}{aptget}{lang} =
      ReadingsVal( $name, 'os-release_language', 'none' );

    my $subprocess = SubProcess->new( { onRun => \&OnRun } );
    $subprocess->{aptget} = $hash->{".fhem"}{aptget};
    $subprocess->{aptget}{host} = $hash->{HOST};
    $subprocess->{aptget}{debug} =
      ( AttrVal( $name, 'verbose', 0 ) > 3 ? 1 : 0 );
    $subprocess->{aptget}{distupgrade} =
      ( AttrVal( $name, 'distupgrade', 0 ) == 1 ? 1 : 0 );
    my $pid = $subprocess->run();

    readingsSingleUpdate( $hash, 'state',
        $hash->{".fhem"}{aptget}{cmd} . ' in progress', 1 );

    if ( !defined($pid) ) {
        Log3 $name, 1,
          "AptToDate ($name) - Cannot execute command asynchronously";

        CleanSubprocess($hash);
        readingsSingleUpdate( $hash, 'state',
            'Cannot execute command asynchronously', 1 );
        return undef;
    }

    Log3 $name, 4,
      "AptToDate ($name) - execute command asynchronously (PID= $pid)";

    $hash->{".fhem"}{subprocess} = $subprocess;

    InternalTimer( gettimeofday() + POLLINTERVAL,
        "FHEM::AptToDate::PollChild", $hash, 0 );
    Log3 $hash, 4, "AptToDate ($name) - control passed back to main loop.";
}

sub PollChild($) {

    my $hash = shift;

    my $name       = $hash->{NAME};
    
    if ( defined($hash->{".fhem"}{subprocess}) ) {
        my $subprocess = $hash->{".fhem"}{subprocess};
        my $json       = $subprocess->readFromChild();

        if ( !defined($json) ) {
            Log3 $name, 5, "AptToDate ($name) - still waiting ("
            . $subprocess->{lasterror} . ").";
            InternalTimer( gettimeofday() + POLLINTERVAL,
                "FHEM::AptToDate::PollChild", $hash, 0 );
            return;
        }
        else {
            Log3 $name, 4,
            "AptToDate ($name) - got result from asynchronous parsing.";
            $subprocess->wait();
            Log3 $name, 4, "AptToDate ($name) - asynchronous finished.";

            CleanSubprocess($hash);
            PreProcessing( $hash, $json );
        }
    }
}

######################################
# Begin Childprozess
######################################

sub OnRun() {

    my $subprocess = shift;

    my $response = ExecuteAptGetCommand( $subprocess->{aptget} );

    my $json = eval { encode_json($response) };
    if ($@) {
        Log3 'AptToDate OnRun', 3, "AptToDate - JSON error: $@";
        $json = '{"jsonerror":"$@"}';
    }

    $subprocess->writeToParent($json);
}

sub ExecuteAptGetCommand($) {

    my $aptget = shift;

    my $apt = {};
    $apt->{lang}  = $aptget->{lang};
    $apt->{debug} = $aptget->{debug};

    if ( $aptget->{host} ne 'localhost' ) {

        $apt->{aptgetupdate} =
          'ssh ' . $aptget->{host} . ' \'echo n | sudo apt-get -q update\'';
        $apt->{distri} = 'ssh ' . $aptget->{host} . ' cat /etc/os-release |';
        $apt->{'locale'} = 'ssh ' . $aptget->{host} . ' locale';
        $apt->{aptgetupgrade} = 'ssh '
          . $aptget->{host}
          . ' \'echo n | sudo apt-get -s -q -V upgrade\'';
        $apt->{aptgettoupgrade} = 'ssh '
          . $aptget->{host}
          . ' \'echo n | sudo apt-get -y -q -V upgrade\''
          if ( $aptget->{distupgrade} == 0 );
        $apt->{aptgettoupgrade} = 'ssh '
          . $aptget->{host}
          . ' \'echo n | sudo apt-get -y -q -V dist-upgrade\''
          if ( $aptget->{distupgrade} == 1 );

    }
    else {

        $apt->{aptgetupdate}    = 'echo n | sudo apt-get -q update';
        $apt->{distri}          = '</etc/os-release';
        $apt->{'locale'}        = 'locale';
        $apt->{aptgetupgrade}   = 'echo n | sudo apt-get -s -q -V upgrade';
        $apt->{aptgettoupgrade} = 'echo n | sudo apt-get -y -q -V upgrade'
          if ( $aptget->{distupgrade} == 0 );
        $apt->{aptgettoupgrade} = 'echo n | sudo apt-get -y -q -V dist-upgrade'
          if ( $aptget->{distupgrade} == 1 );
    }

    my $response;

    if ( $aptget->{cmd} eq 'repoSync' ) {
        $response = AptUpdate($apt);
    }
    elsif ( $aptget->{cmd} eq 'getUpdateList' ) {
        $response = AptUpgradeList($apt);
    }
    elsif ( $aptget->{cmd} eq 'getDistribution' ) {
        $response = GetDistribution($apt);
    }
    elsif ( $aptget->{cmd} eq 'toUpgrade' ) {
        $response = AptToUpgrade($apt);
    }

    return $response;
}

sub GetDistribution($) {

    my $apt = shift;

    my $update = {};

    if ( open( DISTRI, "$apt->{distri}" ) ) {
        while ( my $line = <DISTRI> ) {

            chomp($line);
            print qq($line\n) if ( $apt->{debug} == 1 );
            if ( $line =~ m#^(.*)="?(.*)"$#i or $line =~ m#^(.*)=([a-z]+)$#i ) {
                $update->{'os-release'}{ 'os-release_' . $1 } = $2;
                Log3 'Update', 4, "Distribution Daten erhalten";
            }
        }

        close(DISTRI);
    }
    else {
        die "Couldn't use DISTRI: $!\n";
        $update->{error} = 'Couldn\'t use DISTRI: ' . $;;
    }

    if ( open( LOCALE, "$apt->{'locale'} 2>&1 |" ) ) {
        while ( my $line = <LOCALE> ) {

            chomp($line);
            print qq($line\n) if ( $apt->{debug} == 1 );
            if ( $line =~ m#^LANG=([a-z]+).*$# ) {
                $update->{'os-release'}{'os-release_language'} = $1;
                Log3 'Update', 4, "Language Daten erhalten";
            }
        }

        $update->{'os-release'}{'os-release_language'} = 'en'
          if ( not defined( $update->{'os-release'}{'os-release_language'} ) );
        close(LOCALE);
    }
    else {
        die "Couldn't use APT: $!\n";
        $update->{error} = 'Couldn\'t use LOCALE: ' . $;;
    }

    return $update;
}

sub AptUpdate($) {

    my $apt = shift;

    my $update = {};

    if ( open( APT, "$apt->{aptgetupdate} 2>&1 | " ) ) {
        while ( my $line = <APT> ) {
            chomp($line);
            print qq($line\n) if ( $apt->{debug} == 1 );
            if ( $line =~ m#$regex{$apt->{lang}}{update}#i ) {
                $update->{'state'} = 'done';
                Log3 'Update', 4, "Daten erhalten";

            }
            elsif ( $line =~ s#^E: ## ) {    # error
                my $error = {};
                $error->{message} = $line;
                push( @{ $update->{error} }, $error );
                $update->{'state'} = 'errors';
                Log3 'Update', 4, "Error";

            }
            elsif ( $line =~ s#^W: ## ) {    # warning
                my $warning = {};
                $warning->{message} = $line;
                push( @{ $update->{warning} }, $warning );
                $update->{'state'} = 'warnings';
                Log3 'Update', 4, "Warning";
            }
        }

        close(APT);
    }
    else {
        die "Couldn't use APT: $!\n";
        $update->{error} = 'Couldn\'t use APT: ' . $;;
    }

    return $update;
}

sub AptUpgradeList($) {

    my $apt = shift;

    my $updates = {};

    if ( open( APT, "$apt->{aptgetupgrade} 2>&1 |" ) ) {
        while ( my $line = <APT> ) {
            chomp($line);
            print qq($line\n) if ( $apt->{debug} == 1 );

            if ( $line =~ m#^\s+(\S+)\s+\((\S+)\s+=>\s+(\S+)\)# ) {
                my $update  = {};
                my $package = $1;
                $update->{current}               = $2;
                $update->{new}                   = $3;
                $updates->{packages}->{$package} = $update;

            }
            elsif ( $line =~ s#^W: ## ) {    # warning
                my $warning = {};
                $warning->{message} = $line;
                push( @{ $updates->{warning} }, $warning );

            }
            elsif ( $line =~ s#^E: ## ) {    # error
                my $error = {};
                $error->{message} = $line;
                push( @{ $updates->{error} }, $error );
            }
        }

        close(APT);
    }
    else {
        die "Couldn't use APT: $!\n";
        $updates->{error} = 'Couldn\'t use APT: ' . $;;
    }

    return $updates;
}

sub AptToUpgrade($) {

    my $apt = shift;

    my $updates = {};

    if ( open( APT, "$apt->{aptgettoupgrade} 2>&1 |" ) ) {
        while ( my $line = <APT> ) {
            chomp($line);
            print qq($line\n) if ( $apt->{debug} == 1 );

            if ( $line =~ m#$regex{$apt->{lang}}{upgrade}# ) {
                my $update  = {};
                my $package = $1;
                $update->{new}                   = $2;
                $update->{current}               = $3;
                $updates->{packages}->{$package} = $update;

            }
            elsif ( $line =~ s#^W: ## ) {    # warning
                my $warning = {};
                $warning->{message} = $line;
                push( @{ $updates->{warning} }, $warning );

            }
            elsif ( $line =~ s#^E: ## ) {    # error
                my $error = {};
                $error->{message} = $line;
                push( @{ $updates->{error} }, $error );
            }
        }

        close(APT);
    }
    else {
        die "Couldn't use APT: $!\n";
        $updates->{error} = 'Couldn\'t use APT: ' . $;;
    }

    return $updates;
}

####################################################
# End Childprozess
####################################################

sub PreProcessing($$) {

    my ( $hash, $json ) = @_;

    my $name = $hash->{NAME};

    my $decode_json = eval { decode_json($json) };
    if ($@) {
        Log3 $name, 2, "AptToDate ($name) - JSON error: $@";
        return;
    }

    Log3 $hash, 4, "AptToDate ($name) - JSON: $json";

    if ( $hash->{".fhem"}{aptget}{cmd} eq 'getUpdateList' ) {
        $hash->{".fhem"}{aptget}{packages} = $decode_json->{packages};
        readingsSingleUpdate( $hash, '.upgradeList', $json, 0 );
    }
    elsif ( $hash->{".fhem"}{aptget}{cmd} eq 'toUpgrade' ) {
        $hash->{".fhem"}{aptget}{updatedpackages} = $decode_json->{packages};
        readingsSingleUpdate( $hash, '.updatedList', $json, 0 );
    }

    if (   defined( $decode_json->{warning} )
        or defined( $decode_json->{error} ) )
    {
        $hash->{".fhem"}{aptget}{'warnings'} = $decode_json->{warning}
          if ( defined( $decode_json->{warning} ) );
        $hash->{".fhem"}{aptget}{errors} = $decode_json->{error}
          if ( defined( $decode_json->{error} ) );
    }
    else {
        delete $hash->{".fhem"}{aptget}{'warnings'};
        delete $hash->{".fhem"}{aptget}{errors};
    }

    WriteReadings( $hash, $decode_json );
}

sub WriteReadings($$) {

    my ( $hash, $decode_json ) = @_;

    my $name = $hash->{NAME};

    Log3 $hash, 4, "AptToDate ($name) - Write Readings";
    Log3 $hash, 5, "AptToDate ($name) - " . Dumper $decode_json;
    Log3 $hash, 5, "AptToDate ($name) - Packges Anzahl: " . scalar
      keys %{ $decode_json->{packages} };
    Log3 $hash, 5, "AptToDate ($name) - Inhalt aptget cmd: " . scalar
      keys %{ $decode_json->{packages} };

    readingsBeginUpdate($hash);

    if ( $hash->{".fhem"}{aptget}{cmd} eq 'repoSync' ) {
        readingsBulkUpdate(
            $hash,
            'repoSync',
            (
                defined( $decode_json->{'state'} )
                ? 'fetched ' . $decode_json->{'state'}
                : 'fetched error'
            )
        );
        $hash->{helper}{lastSync} = ToDay();
    }

    readingsBulkUpdateIfChanged( $hash, 'updatesAvailable',
        scalar keys %{ $decode_json->{packages} } )
      if ( $hash->{".fhem"}{aptget}{cmd} eq 'getUpdateList' );
      
    if ( scalar keys%{ $hash->{".fhem"}{aptget}{packages} } > 0 ) {
        readingsBulkUpdateIfChanged( $hash, 'upgradeListAsJSON',
            eval { encode_json( $hash->{".fhem"}{aptget}{packages} ) } )
        if ( AttrVal( $name, 'upgradeListReading', 'none' ) ne 'none' );
    }
    else { readingsBulkUpdateIfChanged( $hash, 'upgradeListAsJSON', '' )
        if ( AttrVal( $name, 'upgradeListReading', 'none' ) ne 'none' );
    }
    
    readingsBulkUpdate( $hash, 'toUpgrade', 'successful' )
      if (  $hash->{".fhem"}{aptget}{cmd} eq 'toUpgrade'
        and not defined( $hash->{".fhem"}{aptget}{'errors'} )
        and not defined( $hash->{".fhem"}{aptget}{'warnings'} ) );

    if ( $hash->{".fhem"}{aptget}{cmd} eq 'getDistribution' ) {
        while ( my ( $r, $v ) = each %{ $decode_json->{'os-release'} } ) {
            readingsBulkUpdateIfChanged( $hash, $r, $v );
        }
    }

    if ( defined( $decode_json->{error} ) ) {
        readingsBulkUpdate( $hash, 'state',
            $hash->{".fhem"}{aptget}{cmd} . ' Errors (get showErrorList)' );
        readingsBulkUpdate( $hash, 'state', 'errors' );
    }
    elsif ( defined( $decode_json->{warning} ) ) {
        readingsBulkUpdate( $hash, 'state',
            $hash->{".fhem"}{aptget}{cmd} . ' Warnings (get showWarningList)' );
        readingsBulkUpdate( $hash, 'state', 'warnings' );
    }
    else {

        readingsBulkUpdate(
            $hash, 'state',
            (
                (scalar keys %{ $decode_json->{packages} } > 0
                or scalar keys%{ $hash->{".fhem"}{aptget}{packages} } > 0)
                ? 'system updates available'
                : 'system is up to date'
            )
        );
    }

    readingsEndUpdate( $hash, 1 );

    ProcessUpdateTimer($hash)
      if ( $hash->{".fhem"}{aptget}{cmd} eq 'getDistribution' );
}

sub CreateUpgradeList($$) {

    my ( $hash, $getCmd ) = @_;

    my $packages;
    $packages = $hash->{".fhem"}{aptget}{packages}
      if ( $getCmd eq 'showUpgradeList' );
    $packages = $hash->{".fhem"}{aptget}{updatedpackages}
      if ( $getCmd eq 'showUpdatedList' );

    my $ret = '<html><table><tr><td>';
    $ret .= '<table class="block wide">';
    $ret .= '<tr class="even">';
    $ret .= "<td><b>Packagename</b></td>";
    $ret .= "<td><b>Current Version</b></td>"
      if ( $getCmd eq 'showUpgradeList' );
    $ret .= "<td><b>Over Version</b></td>" if ( $getCmd eq 'showUpdatedList' );
    $ret .= "<td><b>New Version</b></td>";
    $ret .= "<td></td>";
    $ret .= '</tr>';

    if ( ref($packages) eq "HASH" ) {

        my $linecount = 1;
        foreach my $package ( keys( %{$packages} ) ) {
            if ( $linecount % 2 == 0 ) {
                $ret .= '<tr class="even">';
            }
            else {
                $ret .= '<tr class="odd">';
            }

            $ret .= "<td>$package</td>";
            $ret .= "<td>$packages->{$package}{current}</td>";
            $ret .= "<td>$packages->{$package}{new}</td>";

            $ret .= '</tr>';
            $linecount++;
        }
    }

    $ret .= '</table></td></tr>';
    $ret .= '</table></html>';

    return $ret;
}

sub CreateWarningList($) {

    my $hash = shift;

    my $warnings = $hash->{".fhem"}{aptget}{'warnings'};

    my $ret = '<html><table><tr><td>';
    $ret .= '<table class="block wide">';
    $ret .= '<tr class="even">';
    $ret .= "<td><b>Warning List</b></td>";
    $ret .= "<td></td>";
    $ret .= '</tr>';

    if ( ref($warnings) eq "ARRAY" ) {

        my $linecount = 1;
        foreach my $warning ( @{$warnings} ) {
            if ( $linecount % 2 == 0 ) {
                $ret .= '<tr class="even">';
            }
            else {
                $ret .= '<tr class="odd">';
            }

            $ret .= "<td>$warning->{message}</td>";

            $ret .= '</tr>';
            $linecount++;
        }
    }

    $ret .= '</table></td></tr>';
    $ret .= '</table></html>';

    return $ret;
}

sub CreateErrorList($) {

    my $hash = shift;

    my $errors = $hash->{".fhem"}{aptget}{'errors'};

    my $ret = '<html><table><tr><td>';
    $ret .= '<table class="block wide">';
    $ret .= '<tr class="even">';
    $ret .= "<td><b>Error List</b></td>";
    $ret .= "<td></td>";
    $ret .= '</tr>';

    if ( ref($errors) eq "ARRAY" ) {

        my $linecount = 1;
        foreach my $error ( @{$errors} ) {
            if ( $linecount % 2 == 0 ) {
                $ret .= '<tr class="even">';
            }
            else {
                $ret .= '<tr class="odd">';
            }

            $ret .= "<td>$error->{message}</td>";

            $ret .= '</tr>';
            $linecount++;
        }
    }

    $ret .= '</table></td></tr>';
    $ret .= '</table></html>';

    return $ret;
}

#### my little helper
sub ToDay() {

    my ( $sec, $min, $hour, $mday, $month, $year, $wday, $yday, $isdst ) =
      localtime( gettimeofday() );

    $month++;
    $year += 1900;

    my $today = sprintf( '%04d-%02d-%02d', $year, $month, $mday );

    return $today;
}

1;

=pod
=item device
=item summary       Modul to retrieves apt information about Debian update state
=item summary_DE    Modul um apt Updateinformationen von Debian Systemen zu bekommen

=begin html

<a name="AptToDate"></a>
<h3>Apt Update Information</h3>
<ul>
  <u><b>AptToDate - Retrieves apt information about Debian update state state</b></u>
  <br>
  With this module it is possible to read the apt update information from a Debian System.</br>
  It's required to insert "fhem    ALL=NOPASSWD:   /usr/bin/apt-get" via "visudo".
  <br><br>
  <a name="AptToDatedefine"></a>
  <b>Define</b>
  <ul><br>
    <code>define &lt;name&gt; AptToDate &lt;HOST&gt;</code>
    <br><br>
    Example:
    <ul><br>
      <code>define fhemServer AptToDate localhost</code><br>
    </ul>
    <br>
    This statement creates a AptToDate Device with the name fhemServer and the Host localhost.<br>
    After the device has been created the Modul is fetch all information about update state. This will need a moment.
  </ul>
  <br><br>
  <a name="AptToDatereadings"></a>
  <b>Readings</b>
  <ul>
    <li>state - update status about the server</li>
    <li>os-release_ - all information from /etc/os-release</li>
    <li>repoSync - status about last repository sync.</li>
    <li>toUpgrade - status about last upgrade</li>
    <li>updatesAvailable - number of available updates</li>
  </ul>
  <br><br>
  <a name="AptToDateset"></a>
  <b>Set</b>
  <ul>
    <li>repoSync - fetch information about update state</li>
    <li>toUpgrade - to run update process. this will take a moment</li>
    <br>
  </ul>
  <br><br>
  <a name="AptToDateget"></a>
  <b>Get</b>
  <ul>
    <li>showUpgradeList - list about available updates</li>
    <li>showUpdatedList - list about updated packages, from old version to new version</li>
    <li>showWarningList - list of all last warnings</li>
    <li>showErrorList - list of all last errors</li>
    <br>
  </ul>
  <br><br>
  <a name="AptToDate attribut"></a>
  <b>Attributes</b>
  <ul>
    <li>disable - disables the device</li>
    <li>upgradeListReading - add Upgrade List Reading as JSON</li>
    <li>distupgrade - change upgrade prozess to dist-upgrade</li>
    <li>disabledForIntervals - disable device for interval time (13:00-18:30 or 13:00-18:30 22:00-23:00)</li>
  </ul>
</ul>

=end html

=begin html_DE

<a name="AptToDate"></a>
<h3>Apt Update Information</h3>
<ul>
  <u><b>AptToDate - Stellt aktuelle Update Informationen von apt Debian Systemen bereit</b></u>
  <br>
  Das Modul synct alle Repositotys und stellt dann Informationen &uuml;ber zu aktualisierende Packete bereit.</br>
  Es ist Voraussetzung das folgende Zeile via "visudo" eingef&uuml;gt wird: "fhem    ALL=NOPASSWD:   /usr/bin/apt-get".
  <br><br>
  <a name="AptToDatedefine"></a>
  <b>Define</b>
  <ul><br>
    <code>define &lt;name&gt; AptToDate &lt;HOST&gt;</code>
    <br><br>
    Beispiel:
    <ul><br>
      <code>define fhemServer AptToDate localhost</code><br>
    </ul>
    <br>
    Der Befehl erstellt eine AptToDate Instanz mit dem Namen fhemServer und dem Host localhost.<br>
    Nachdem die Instanz erstellt wurde werden die ben&ouml;tigten Informationen geholt und als Readings angezeigt.
    Dies kann einen Moment dauern.
  </ul>
  <br><br>
  <a name="AptToDatereadings"></a>
  <b>Readings</b>
  <ul>
    <li>state - update Status des Servers, liegen neue Updates an oder nicht</li>
    <li>os-release_ - alle Informationen aus /etc/os-release</li>
    <li>repoSync - status des letzten repository sync.</li>
    <li>toUpgrade - status des letzten upgrade Befehles</li>
    <li>updatesAvailable - Anzahl der verf&uuml;gbaren Paketupdates</li>
  </ul>
  <br><br>
  <a name="AptToDateset"></a>
  <b>Set</b>
  <ul>
    <li>repoSync - holt aktuelle Informationen &uuml;ber den Updatestatus</li>
    <li>toUpgrade - f&uuml;hrt den upgrade prozess aus.</li>
    <br>
  </ul>
  <br><br>
  <a name="AptToDateget"></a>
  <b>Get</b>
  <ul>
    <li>showUpgradeList - Paketiste aller zur Verf&uuml;gung stehender Updates</li>
    <li>showUpdatedList - Liste aller als letztes aktualisierter Pakete, von der alten Version zur neuen Version</li>
    <li>showWarningList - Liste der letzten Warnings</li>
    <li>showErrorList - Liste der letzten Fehler</li>
    <li>getDistribution - fetch new distribution information</li>
    <br>
  </ul>
  <br><br>
  <a name="AptToDate attribut"></a>
  <b>Attributes</b>
  <ul>
    <li>disable - Deaktiviert das Device</li>
    <li>upgradeListReading - f&uuml;gt die Upgrade Liste als ein zus&auml;iches Reading im JSON Format ein.</li>
    <li>distupgrade - wechselt den upgrade Prozess nach dist-upgrade</li>
    <li>disabledForIntervals - Deaktiviert das Device f&uuml;r eine bestimmte Zeit (13:00-18:30 or 13:00-18:30 22:00-23:00)</li>
  </ul>
</ul>

=end html_DE

=for :application/json;q=META.json 42_AptToDate.pm
{
  "abstract": "Modul to retrieves apt information about Debian update state",
  "x_lang": {
    "de": {
      "abstract": "Modul um apt Updateinformationen von Debian Systemen zu bekommen"
    }
  },
  "keywords": [
    "fhem-mod-device",
    "fhem-core",
    "Debian",
    "apt",
    "apt-get",
    "dpkg",
    "Package"
  ],
  "release_status": "stable",
  "license": "GPL_2",
  "author": [
    "Marko Oldenburg <leongaultier@gmail.com>"
  ],
  "x_fhem_maintainer": [
    "CoolTux"
  ],
  "x_fhem_maintainer_github": [
    "LeonGaultier"
  ],
  "prereqs": {
    "runtime": {
      "requires": {
        "FHEM": 5.00918799,
        "perl": 5.016, 
        "Meta": 0,
        "SubProcess": 0,
        "JSON": 0
      },
      "recommends": {
      },
      "suggests": {
      }
    }
  }
}
=end :application/json;q=META.json

=cut
