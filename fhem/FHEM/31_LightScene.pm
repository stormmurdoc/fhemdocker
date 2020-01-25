
# $Id: 31_LightScene.pm 18765 2019-03-01 09:13:39Z justme1968 $

package main;

use strict;
use warnings;
use POSIX;
#use JSON;
#use Data::Dumper;

use vars qw($FW_ME);
use vars qw($FW_subdir);
use vars qw($FW_wname);
use vars qw($FW_cname);
use vars qw(%FW_webArgs); # all arguments specified in the GET

my $LightScene_hasJSON = 1;
my $LightScene_hasDataDumper = 1;
my $scn = '';             # scene used for edit-table

sub LightScene_Initialize($)
{
  my ($hash) = @_;

  $hash->{DefFn}    = "LightScene_Define";
  $hash->{NotifyFn} = "LightScene_Notify";
  $hash->{UndefFn}  = "LightScene_Undefine";
  $hash->{SetFn}    = "LightScene_Set";
  $hash->{GetFn}    = "LightScene_Get";
  $hash->{AttrFn}   = "LightScene_Attr";
  $hash->{AttrList} = "async_delay followDevices:1,2 lightSceneRestoreOnlyIfChanged:1,0 showDeviceCurrentState:1,0 switchingOrder traversalOrder ". $readingFnAttributes;

  $hash->{FW_detailFn}  = "LightScene_detailFn";
  $data{FWEXT}{"/LightScene"}{FUNC} = "LightScene_CGI"; #mod

  eval "use JSON";
  $LightScene_hasJSON = 0 if($@);

  eval "use Data::Dumper";
  $LightScene_hasDataDumper = 0 if($@);
}

sub LightScene_Define($$)
{
  my ($hash, $def) = @_;

  return "install JSON (or Data::Dumper) to use LightScene" if( !$LightScene_hasJSON && !$LightScene_hasDataDumper );

  my @args = split("[ \t]+", $def);

  return "Usage: define <name> LightScene <device>+"  if(@args < 3);

  my $name = shift(@args);
  my $type = shift(@args);

  $hash->{HAS_JSON} = $LightScene_hasJSON;
  $hash->{HAS_DataDumper} = $LightScene_hasDataDumper;

  my %list;
  foreach my $a (@args) {
    foreach my $d (devspec2array($a)) {
      $list{$d} = 1;

      addToDevAttrList( $d, "lightSceneParamsToSave" );
      addToDevAttrList( $d, "lightSceneRestoreOnlyIfChanged:1,0" );
    }
  }
  $hash->{CONTENT} = \%list;

  if( !defined($hash->{SCENES}) ) {
    my %scenes;
    $hash->{SCENES} = \%scenes;

    LightScene_Load($hash);
  }

  LightScene_updateHelper( $hash, AttrVal($name,"switchingOrder",undef) );

  my @arr = ();
  $hash->{".asyncQueue"} = \@arr;

  $hash->{STATE} = 'Initialized';

  return undef;
}

sub LightScene_Undefine($$)
{
  my ($hash,$arg) = @_;

  delete $hash->{SCENES};

  return undef;
}

sub
LightScene_2html($)
{
  my($hash) = @_;
  $hash = $defs{$hash} if( ref($hash) ne 'HASH' );

  return undef if( !$hash );

  my $name = $hash->{NAME};
  my $room = $FW_webArgs{room};

  my $show_heading = 1;

  my $row = 1;
  my $ret = "";
  $ret .= "<table>";
  $ret .= "<tr><td><div class=\"devType\"><a href=\"$FW_ME?detail=$name\">".AttrVal($name, "alias", $name)."</a></div></td></tr>" if( $show_heading );
  $ret .= "<tr><td><table class=\"block wide\">";

  if( defined($FW_webArgs{detail}) || AttrVal($name,"showDeviceCurrentState",undef) ) {
    $room = "&detail=$FW_webArgs{detail}" if( defined($FW_webArgs{detail}) );

    $ret .= sprintf("<tr class=\"%s\">", ($row&1)?"odd":"even");
    #$row++;
    $ret .= "<td><div></div></td>";
    foreach my $d (sort keys %{ $hash->{CONTENT} }) {
      my %extPage = ();
      my ($allSets, $cmdlist, $txt) = FW_devState($d, $room, \%extPage);
      $ret .= "<td style=\"cursor:pointer\" informId=\"$name-$d.state\">$txt</td>";
    }
  }

  $ret .= sprintf("<tr class=\"%s\">", ($row&1)?"odd":"even");
  $row++;
  $ret .= "<td><div></div></td>";
  foreach my $d (sort keys %{ $hash->{CONTENT} }) {
    $ret .= "<td><div class=\"col2\"><a href=\"$FW_ME?detail=$d\">". AttrVal($d, "alias", $d) ."</a></div></td>";
  }

  foreach my $scene (sort keys %{ $hash->{SCENES} }) {
    $ret .= sprintf("<tr class=\"%s\">", ($row&1)?"odd":"even");
    $row++;

    my $srf = $room ? "&room=$room" : "";
    $srf = $room if( $room && $room =~ m/^&/ );
    my $link = "cmd=set $name scene $scene";
    my $txt = $scene;
    if( 1 ) {
      my ($icon, $link, $isHtml) = FW_dev2image($name, $scene);
      $txt = ($isHtml ? $icon : FW_makeImage($icon, $scene)) if( $icon );
    }
    if( AttrVal($FW_wname, "longpoll", 1)) {
      $txt = "<a style=\"cursor:pointer\" onClick=\"FW_cmd('$FW_ME$FW_subdir?XHR=1&$link')\">$txt</a>";
    } else {
      $txt = "<a href=\"$FW_ME$FW_subdir?$link$srf\">$txt</a>";
    }
    $ret .= "<td><div>$txt</div></td>";

    foreach my $d (sort keys %{ $hash->{CONTENT} }) {
      if( !defined($hash->{SCENES}{$scene}{$d} ) ) {
        $ret .= "<td><div></div></td>";
        next;
      }

      my $icon;
      my $state = $hash->{SCENES}{$scene}{$d};
      $icon = $state->{icon} if( ref($state) eq 'HASH' );
      $state = $state->{state} if( ref($state) eq 'HASH' );

      my ($isHtml);
      $isHtml = 0;

      if( !$icon ) {
        my ($link);
        ($icon, $link, $isHtml) = FW_dev2image($d, $state);
      }
      $icon = FW_iconName($state) if( !$icon );

      if( $icon ) {
        $ret .= "<td><div class=\"col2\">". ($isHtml ? $icon : FW_makeImage($icon, $state)) ."</div></td>";
      } else {
        $ret .= "<td><div>". $state ."</div></td>";
      }
    }
  }

  $ret .= "</table></td></tr>";
  $ret .= "</table>";
  $ret .= "<br>";

  return $ret;
}
sub
LightScene_detailFn()
{
  my ($FW_wname, $d, $room, $pageHash) = @_; # pageHash is set for summaryFn.

  my $hash = $defs{$d};

  $hash->{mayBeVisible} = 1;

  my $html = LightScene_2html($d); #mod
  $html .= LightScene_editTable($hash); #mod
  return $html;
}

sub
LightScene_Notify($$)
{
  my ($hash,$dev) = @_;
  my $name  = $hash->{NAME};
  my $type  = $hash->{TYPE};

  if( grep(m/^INITIALIZED$/, @{$dev->{CHANGED}}) ) {
  } elsif( grep(m/^SAVE$/, @{$dev->{CHANGED}}) ) {
    LightScene_Save();
  }

  return if( !$init_done );
  return if( $dev->{TYPE} eq $hash->{TYPE} );

  my $max = int(@{$dev->{CHANGED}});
  for (my $i = 0; $i < $max; $i++) {
    my $s = $dev->{CHANGED}[$i];
    $s = "" if(!defined($s));

    if($s =~ m/^RENAMED ([^ ]*) ([^ ]*)$/) {
      my ($old, $new) = ($1, $2);
      if( defined($hash->{CONTENT}{$old}) ) {

        $hash->{DEF} =~ s/(^|\s+)$old(\s+|$)/$1$new$2/;

        foreach my $scene (keys %{ $hash->{SCENES} }) {
          $hash->{SCENES}{$scene}{$new} = $hash->{SCENES}{$scene}{$old} if( defined($hash->{SCENES}{$scene}{$old}) );
          delete( $hash->{SCENES}{$scene}{$old} );
        }

        delete( $hash->{CONTENT}{$old} );
        $hash->{CONTENT}{$new} = 1;
      }
    } elsif($s =~ m/^DELETED ([^ ]*)$/) {
      my ($name) = ($1);

      if( defined($hash->{CONTENT}{$name}) ) {

        $hash->{DEF} =~ s/(^|\s+)$name(\s+|$)/ /;
        $hash->{DEF} =~ s/^ //;
        $hash->{DEF} =~ s/ $//;

        foreach my $scene (keys %{ $hash->{SCENES} }) {
          delete( $hash->{SCENES}{$scene}{$name} );
        }

        delete( $hash->{CONTENT}{$name} );
      }
    } else {

      next if (!$hash->{CONTENT}->{$dev->{NAME}});

      if( !defined($hash->{mayBeVisible}) ) {
        Log3 $name, 5, "$name: not on any display, ignoring notify";
        return undef if( !$hash->{followDevices} );
      } else {
        if( defined($FW_visibleDeviceHash{$name}) ) {
        } else {
          Log3 $name, 5, "$name: no longer visible, ignoring notify";
          delete( $hash->{mayBeVisible} );
          return undef if( !$hash->{followDevices} );
        }
      }
      return undef if ( !$hash->{mayBeVisible} && !$hash->{followDevices} );

      my @parts = split(/: /,$s);
      my $reading = shift @parts;
      my $value   = join(": ", @parts);

      #see: https://forum.fhem.de/index.php/topic,33223.msg895357.html#msg895357
      #next if( $value ne "" );
      #$reading = "state";
      #$value = $s;

      $reading = "" if( !defined($reading) );
      $value = "" if( !defined($value) );
      if( $value eq "" ) {
        $reading = "state";
        $value = $s;
      }

      if( $hash->{mayBeVisible} || $hash->{followDevices} ) {
        my $room = AttrVal($name, "room", "");
        my %extPage = ();
        (undef, undef, $value) = FW_devState($dev->{NAME}, $room, \%extPage);

        DoTrigger( $name, "$dev->{NAME}.$reading: <html>$value</html>" );
      }

      if( $hash->{followDevices} ) {
        my %s = ();

        foreach my $d (@{$hash->{devices}}) {
          next if(!$defs{$d});

          my($state,undef,undef) = LightScene_SaveDevice($hash,$d);
          $s{$d} = $state;
        }

        my $matched = 0;
        foreach my $scene (sort keys %{ $hash->{SCENES} }) {
          $matched = (scalar keys %{ $hash->{SCENES}{$scene} } > 0)?1:0;
          foreach my $d (sort keys %{ $hash->{SCENES}{$scene} }) {
            next if( !defined($hash->{SCENES}{$scene}{$d}));
            next if(!$defs{$d});

            my $state = $hash->{SCENES}{$scene}{$d};
            $state = $state->{state} if( ref($state) eq 'HASH' );

            if( ref($state) eq 'ARRAY' ) {
              $matched = 0;
            } elsif( !defined($s{$d}) || $state ne $s{$d} ) {
              $matched = 0;
            }

            last if( !$matched );
          }

          readingsSingleUpdate($hash, "state", $scene, 1 ) if( $matched );
          last if( $matched );
        }
        if( !$matched ) {
          if( $hash->{followDevices} == 2 ) {
            readingsSingleUpdate($hash, "state", "unknown", 1 );
          } else {
            DoTrigger( $name, "nomatch" )
          }
        }
      }
    }
  }

  return undef;
}

sub
myStatefileName()
{
  my $statefile = $attr{global}{statefile};
  my @t = localtime(gettimeofday());
  $statefile = ResolveDateWildcards($statefile, @t);
  $statefile = substr $statefile,0,rindex($statefile,'/')+1;
  return $statefile ."LightScenes.save" if( $LightScene_hasJSON );
  return $statefile ."LightScenes.dd.save" if( $LightScene_hasDataDumper );
}
my $LightScene_LastSaveTime="";
sub
LightScene_Save()
{
  my $time_now = TimeNow();
  return if( $time_now eq $LightScene_LastSaveTime);
  $LightScene_LastSaveTime = $time_now;

  return "No statefile specified" if(!$attr{global}{statefile});
  my $statefile = myStatefileName();

  my $hash;
  for my $d (keys %defs) {
    next if( !$defs{$d}{TYPE} );
    next if( $defs{$d}{TYPE} ne "LightScene" );
    next if( !defined($defs{$d}{SCENES}) );

    $hash->{$d} = $defs{$d}{SCENES} if( keys(%{$defs{$d}{SCENES}}) );
  }

  if(open(FH, ">$statefile")) {
    my $t = localtime;
    print FH "#$t\n";

    if( $LightScene_hasJSON ) {
      print FH encode_json($hash) if( defined($hash) );
    } elsif( $LightScene_hasDataDumper ) {
      my $dumper = Data::Dumper->new([]);
      $dumper->Terse(1);

      $dumper->Values([$hash]);
      print FH $dumper->Dump;
    }

    close(FH);
  } else {

    my $msg = "LightScene_Save: Cannot open $statefile: $!";
    Log3 undef, 1, $msg;
  }

  return undef;
}
sub
LightScene_Load($)
{
  my ($hash) = @_;

  return "No statefile specified" if(!$attr{global}{statefile});
  my $statefile = myStatefileName();

  if(open(FH, "<$statefile")) {
    my $encoded;
    while (my $line = <FH>) {
      chomp $line;
      next if($line =~ m/^#.*$/);
      $encoded .= $line;
    }
    close(FH);

    return if( !defined($encoded) );

    my $decoded;
    if( $LightScene_hasJSON ) {
      $decoded = eval { decode_json($encoded) };
    } elsif( $LightScene_hasDataDumper ) {
      $decoded = eval $encoded;
    }
    $hash->{SCENES} = $decoded->{$hash->{NAME}} if( defined($decoded->{$hash->{NAME}}) );
  } else {
    my $msg = "LightScene_Load: Cannot open $statefile: $!";
    Log3 undef, 1, $msg;
  }
  return undef;
}

sub
LightScene_SaveDevice($$;$$)
{
  my($hash,$d,$scene,$desc) = @_;

  my $state = "";
  my $icon = undef;
  my $id = undef;
  my $type = $defs{$d}->{TYPE};
  $type = "" if( !defined($type) );

  if( my $toSave = AttrVal($d,"lightSceneParamsToSave","") ) {
    $icon = Value($d);
    if( $toSave =~ m/^{.*}$/) {
      my $DEVICE = $d;
      $toSave = eval $toSave;
      $toSave = "state" if( $@ );
    }
    my @sets = split(',', $toSave);
    foreach my $set (@sets) {
      my $saved = "";
      my @params = split(':', $set);
      foreach my $param (@params) {
        $saved .= " : " if( $saved );

        my $use_get = 0;
        my $get = $param;
        my $regex;
        my $set = $param;

        if( $param =~ /(get\s+)?(\S*)(\s*->\s*(set\s+)?)?(\S*)?/ ) {
          $use_get = 1 if( $1 );
          $get = $2 if( $2 );
          $set = $5 if( $5 );
        }
        ($get,$regex) = split('@', $get, 2);
        $set = $get if( $regex && $set eq $param );
        $set = "state" if( $set eq "STATE" );

        $saved .= "$set " if( $set ne "state" );

        my $value;
        if( $use_get ) {
          $value = CommandGet( "", "$d $get" );
        } elsif( $get eq "STATE" ) {
          $value = Value($d);
        } else {
          $value = ReadingsVal($d,$get,undef);
        }
        $value = eval $regex if( $regex );
        Log3 $hash, 2, "$hash->{NAME}: $@" if($@);
        $saved .= $value;
      }

      if( !$state ) {
        $state = $saved;
      } else {
        $state = [$state] if( ref($state) ne 'ARRAY' );
        push( @{$state}, $saved );
      }
    }
  } elsif( $type eq 'CUL_HM' ) {
    #my $subtype = AttrVal($d,"subType","");
    my $subtype = CUL_HM_Get($defs{$d},$d,"param","subType");
    if( $subtype eq "switch" ) {
      $state = Value($d);
    } elsif( $subtype eq "dimmer" ) {
      $state = Value($d);
      if ( $state =~ m/^(\d+)/ ) {
        $icon = $state;
        $state = $1 if ( $state =~ m/^(\d+)/ );
      }
    } else {
      $state = Value($d);
    }
  } elsif( $type eq 'FS20' ) {
      $state = Value($d);
  } elsif( $type eq 'SWAP_0000002200000003' ) {
      $state = Value($d);
      $state = "rgb ". $state if( $state ne "off" );
  } elsif( $type eq 'HUEDevice' ) {
    my $subtype = AttrVal($d,"subType","");
    if( $defs{$d}->{helper}->{devtype} eq "G" ) {

      if( $scene ) {
        if( ref($desc) eq 'HASH' ) {
          $id = $desc->{id} if( $desc->{id} );
          fhem( "set $d deletescene $id" );
        }
        my $name = "FHEM-$hash->{NAME}-$scene";
        my $ret = fhem( "set $d savescene $name" );
        if( $ret =~ m/^created (.*)/ ) {
          $id = $1;
        }
        $state = "scene $id";
      } else {
        $state = "<unknown>";
      }

    } elsif( $subtype eq "switch" || Value($d) eq "off" ) {
      $state = Value($d);

    } elsif( $subtype eq "dimmer" ) {
      $state = "bri ". ReadingsVal($d,'bri',"0");

    } elsif( $subtype =~ m/color|ct/ ) {
      my $cm = ReadingsVal($d,"colormode","");
      if( $cm eq "ct" ) {
        ReadingsVal($d,"ct","") =~ m/(\d+) .*/;
        $state = "bri ". ReadingsVal($d,'bri',"0") ." : ct ". $1;
      } elsif( $cm eq "hs" ) {
        $state = "bri ". ReadingsVal($d,'bri',"0") ." : hue ". ReadingsVal($d,'hue',"") ." : sat ". ReadingsVal($d,'sat',"");
      } else {
        $state = "bri ". ReadingsVal($d,'bri',"0") ." : xy ". ReadingsVal($d,'xy',"");
      }
    }

  } elsif( $type eq 'IT' ) {
    my $subtype = AttrVal($d,"model","");
    if( $subtype eq "itswitch" ) {
      $state = Value($d);
    } elsif( $subtype eq "itdimmer" ) {
      $state = Value($d);
    } else {
      $state = Value($d);
    }
  } elsif( $type eq 'TRX_LIGHT' ) {
    $state = Value($d);
  } else {
    $state = Value($d);
  }

  return($state,$icon,$type,$id);
}

sub
LightScene_RestoreDevice($$$)
{
  my($hash,$d,$cmd) = @_;

  if( AttrVal($d,"lightSceneRestoreOnlyIfChanged", AttrVal($hash->{NAME},"lightSceneRestoreOnlyIfChanged",0) ) > 0 )
    {
      my($state,undef,undef) = LightScene_SaveDevice($hash,$d);

      return ("",0) if( $state eq $cmd );
    }

  my $async_delay = AttrVal($hash->{NAME}, "async_delay", undef);
  my $ret;
  if( $cmd =~m/^;/ ) {
    if(defined($async_delay)) {
      push @{$hash->{".asyncQueue"}}, $cmd;
    } else {
      $ret = AnalyzeCommandChain(undef,$cmd);
    }

  } else {
    if(defined($async_delay)) {
      push @{$hash->{".asyncQueue"}}, "$d $cmd";
    } else {
      $ret = CommandSet(undef,"$d $cmd");
    }

  }

  return ($ret,1);
}

sub
LightScene_Set($@)
{
  my ($hash, $name, $cmd, $scene, @a) = @_;
  my $ret = "";

  if( !defined($cmd) ){ return "$name: set needs at least one parameter" };

  my @sorted = sort keys %{$hash->{SCENES}};

  if( $cmd eq "?" ){ return "Unknown argument ?, choose one of clear remove:".join(",", @sorted) ." rename save set setcmd scene:".join(",", @sorted) ." all nextScene:noArg previousScene:noArg"};

  if( $cmd eq "all" && !defined( $scene ) ) { return "Usage: set $name all <command>" };
  if( $cmd eq "save" && !defined( $scene ) ) { return "Usage: set $name save <scene_name>" };
  if( $cmd eq "scene" && !defined( $scene ) ) { return "Usage: set $name scene <scene_name>" };
  if( $cmd eq "remove" && !defined( $scene ) ) { return "Usage: set $name remove <scene_name>" };
  if( $cmd eq "rename" && !defined( $scene ) ) { return "Usage: set $name rename <scene_alt> <scene_neu>" };

  if( $cmd eq "clear" ) {
    foreach my $s (keys %{ $hash->{SCENES} }) {
      next if( $scene && $s !~ m/^$scene$/ );
      delete  $hash->{SCENES}{$s};
    }
    return undef;

  } elsif( $cmd eq "remove" ) {
    return "no such scene: $scene" if( !defined $hash->{SCENES}{$scene} );
    delete( $hash->{SCENES}{$scene} );
    return undef;

  } elsif( $cmd eq "rename" ) {
    return "no such scene: $scene" if( !defined $hash->{SCENES}{$scene} );
    my ($new) = @a;
    if( !( $new ) ) { return "Usage: set $name rename <scene_alt> <scene_neu>" };

    $hash->{SCENES}{$new} = $hash->{SCENES}{$scene};
    delete( $hash->{SCENES}{$scene} );
    return undef;

  } elsif( $cmd eq "scene" ) {
    return "no such scene: $scene" if( !defined $hash->{SCENES}{$scene} );

  } elsif( $cmd eq "set" || $cmd eq "setcmd" ) {
    my ($d, @args) = @a;

    if( !defined( $scene ) || !defined( $d ) ) { return "Usage: set $name set <scene_name> <device> [<cmd>]" };
    return "no such scene: $scene" if( !defined $hash->{SCENES}{$scene} );
    #return "device >$d< is not a member of scene >$scene<" if( !defined($hash->{CONTENT}{$d} ) );

    if( !@args ) {
      delete $hash->{SCENES}{$scene}{$d};
    } else {
      $hash->{SCENES}{$scene}{$d} = (($cmd eq "setcmd")?';':''). join(" ", @args);
    }

    LightScene_updateHelper( $hash, AttrVal($name,"switchingOrder",undef) );

    return undef;

  } elsif( $cmd eq "updateToJson" && $LightScene_hasDataDumper && $LightScene_hasJSON ) {
    $LightScene_hasJSON = 0;
    LightScene_Load($hash);
    LightScene_updateHelper( $hash, AttrVal($name,"switchingOrder",undef) );
    $LightScene_hasJSON = 1;
    LightScene_Save();
    return undef;

  } elsif( $cmd eq 'nextScene' || $cmd eq 'previousScene' ) {
    my $sorted = \@sorted;
    if( my $list = AttrVal($name, 'traversalOrder', undef ) ) {
      my @parts = split( /[ ,\n]/, $list );
      $sorted = \@parts;
    }
    my $max = scalar @{$sorted}-1;

    return "no scenes defined" if( $max < 0 );
    my $current = ReadingsVal( $name, 'state', '' );
    my( $index )= grep { $sorted->[$_] eq $current } 0..$max;
    $index = -1 if( !defined($index) );

    ++$index if( $cmd eq 'nextScene' );
    --$index if( $cmd eq 'previousScene' );

    return if( $scene && $scene eq 'nowrap' && $index > $max );
    return if( $scene && $scene eq 'nowrap' && $index < 0 );

    $index = 0 if( $index > $max );
    $index = $max if( $index < 0 );

    $cmd = 'scene';
    $scene = $sorted->[$index];

    return "no such scene: $scene" if( !defined $hash->{SCENES}{$scene} );
  }


  $hash->{INSET} = 1;

  my @devices;
  if( ( $cmd eq "scene" || $cmd eq "all" )
      && defined($hash->{switchingOrder}) && defined($hash->{switchingOrder}{$scene}) ) {
    @devices = @{$hash->{switchingOrder}{$scene}};
  } else {
    @devices = @{$hash->{devices}};
  }

  my $count = 0;
  my $async_delay = AttrVal($hash->{NAME}, "async_delay", undef);
  my $asyncQueueLength = @{$hash->{".asyncQueue"}};
  foreach my $d (@devices) {
    next if(!$defs{$d});
    if($defs{$d}{INSET}) {
      Log3 $name, 1, "ERROR: endless loop detected for $d in " . $hash->{NAME};
      next;
    }

    if( $cmd eq "save" ) {
      my($state,$icon,$type,$id) = LightScene_SaveDevice($hash,$d,$scene,$hash->{SCENES}{$scene}{$d});

      if( $icon || ref($state) eq 'ARRAY' || $type eq "SWAP_0000002200000003" || $type eq "HUEDevice"  ) {
        my %desc;
        $desc{state} = $state;
        my ($icon, $link, $isHtml) = FW_dev2image($d);
        $desc{icon} = $icon;
        $desc{id} = $id if( $id );
        $hash->{SCENES}{$scene}{$d} = \%desc;
      } else {
        $hash->{SCENES}{$scene}{$d} = $state;
      }

      $ret .= $d .": ". $state ."\n" if( defined($FW_webArgs{room}) && $FW_webArgs{room} eq "all" ); #only if telnet

    } elsif ( $cmd eq "scene" ) {
      next if( !defined($hash->{SCENES}{$scene}{$d}));

      my $state = $hash->{SCENES}{$scene}{$d};
      $state = $state->{state} if( ref($state) eq 'HASH' );

      if( ref($state) eq 'ARRAY' ) {
        my $r = "";
        foreach my $entry (@{$state}) {
          $r .= "," if( $ret );
          my($rr,$switched) = LightScene_RestoreDevice($hash,$d,$entry);
          $count += $switched;
          $r .= $rr // "";
        }
        $ret .= " " if( $ret );
        $ret .= $r;
      } else {
        $ret .= " " if( $ret );
        my($rr,$switched) = LightScene_RestoreDevice($hash,$d,$state);
        $count += $switched;
        $ret .= $rr // "";
      }

    } elsif ( $cmd eq "all" ) {
      $ret .= " " if( $ret );
      my($rr,$switched) = LightScene_RestoreDevice($hash,$d,"$scene ".join(" ", @a));
      $count += $switched;
      $ret .= $rr // "";

    } else {
      $ret = "Unknown argument $cmd, choose one of save scene";
    }

  }

  if( $cmd eq "scene" ) {
    readingsSingleUpdate($hash, "state", $scene, 1 ) if( !$hash->{followDevices} || $count == 0 );
  } elsif( $cmd eq "all" ) {
    readingsSingleUpdate($hash, "state", "all $scene ".join(" ", @a), 1 ) if( !$hash->{followDevices} || $count == 0 );
  }

  delete($hash->{INSET});
  Log3 $hash, 5, "SET: $ret" if($ret);

  LightScene_updateHelper( $hash, AttrVal($name,"switchingOrder",undef) );

  InternalTimer(gettimeofday()+0, "LightScene_asyncQueue", $hash, 0) if( @{$hash->{".asyncQueue"}} && !$asyncQueueLength );

  return $ret;

  return undef;
}

sub
LightScene_asyncQueue(@)
{
  my ($hash) = @_;

  my $cmd = shift @{$hash->{".asyncQueue"}};
  if(defined $cmd) {
    if( $cmd =~m/^;/ ) {
      AnalyzeCommandChain(undef,$cmd);
    } else {
      CommandSet(undef, $cmd);
    }
    my $async_delay = AttrVal($hash->{NAME}, "async_delay", 0);
    InternalTimer(gettimeofday()+$async_delay,"LightScene_asyncQueue",$hash,0) if( @{$hash->{".asyncQueue"}} );
  }
  return undef;
}

sub
LightScene_Get($@)
{
  my ($hash, @a) = @_;

  my $name = $a[0];
  return "$name: get needs at least one parameter" if(@a < 2);

  my $cmd= $a[1];
  if( $cmd eq "scene" && @a < 3 ) { return "Usage: get scene <scene_name>" };

  my $ret = "";
  if( $cmd eq "html" ) {
    return LightScene_2html($hash);
  } elsif( $cmd eq "scenes" ) {
    foreach my $scene (sort keys %{ $hash->{SCENES} }) {
      $ret .= $scene ."\n";
    }
    return $ret;
  } elsif( $cmd eq "scene" ) {
    my $ret = "";
    my $scene = $a[2];
    if( defined($hash->{SCENES}{$scene}) ) {
      foreach my $d (sort keys %{ $hash->{SCENES}{$scene} }) {
        next if( !defined($hash->{SCENES}{$scene}{$d}));

        my $state = $hash->{SCENES}{$scene}{$d};
        $state = $state->{state} if( ref($state) eq 'HASH' );

        if( ref($state) eq 'ARRAY' ) {
          my $r = "";
          foreach my $entry (@{$state}) {
            $r .= ',' if( $r );
            $r .= $entry;
          }
          $ret .= $d .": $r\n";
        } else {
          $ret .= $d .": $state\n";
        }
      }
    } else {
        $ret = "no scene <$scene> defined";
    }
    return $ret;
  }

  return "Unknown argument $cmd, choose one of html:noArg scenes:noArg scene:".join(",", sort keys %{$hash->{SCENES}});
}
sub
LightScene_updateHelper($$)
{
  my ($hash, $attrVal) = @_;

  my @devices = sort keys %{ $hash->{CONTENT} };
  $hash->{devices} = \@devices;

  if( !$attrVal ) {
    delete $hash->{switchingOrder};
    return;
  }

  my %switchingOrder = ();
  my @parts = split( ' ', $attrVal );
  foreach my $part (@parts) {
    my ($s,$devices) = split( ':', $part,2 );

    my $reverse = 0;
    if( $devices && $devices =~ m/^!(.*)/ ) {
      $reverse = 1;
      $devices = $1;
    }

    foreach my $scene (keys %{ $hash->{SCENES} }) {
      eval { $scene =~ m/$s/ };
      if( $@ ) {
        my $name = $hash->{NAME};
        Log3 $name, 3, $name .": ". $s .": ". $@;
        next;
      }
      next if( $scene !~ m/$s/ );
      next if( $switchingOrder{$scene} );

      my @devs = split( ',', $devices );
      my @devices = ();
      @devices = @{$hash->{devices}} if( $reverse );
      foreach my $d (@devs) {
        foreach my $device (@{$hash->{devices}}) {
          next if( !$reverse && grep { $_ eq $device } @devices );
          eval { $device =~ m/$d/ };
          if( $@ ) {
            my $name = $hash->{NAME};
            Log3 $name, 3, $name .": ". $d .": ". $@;
            next;
          }
          next if( $device !~ m/$d/ );

          @devices = grep { $_ ne $device } @devices if($reverse);
          push( @devices, $device );
        }
      }
      foreach my $device (@{$hash->{devices}}) {
        next if( grep { $_ eq $device } @devices );
        push( @devices, $device );
      }
      $switchingOrder{$scene} = \@devices;
    }
  }

  $hash->{switchingOrder} = \%switchingOrder;
}
sub
LightScene_Attr($@)
{
  my ($cmd, $name, $attrName, $attrVal) = @_;

  if( $attrName eq "followDevices" ) {
    my $hash = $defs{$name};

    if( $cmd eq "set" ) {
      $hash->{followDevices} = $attrVal;
    } else {
      delete $hash->{followDevices};
    }
  } elsif( $attrName eq "switchingOrder" ) {
    my $hash = $defs{$name};

    if( $cmd eq "set" ) {
      LightScene_updateHelper( $hash, $attrVal );
    } else {
      delete $hash->{switchingOrder};
    }
  }

  return;
}
sub
LightScene_CGI {
  my ($cgi) = @_;
  my ($cmd,$c)=FW_digestCgi($cgi);
  $scn =  $FW_webArgs{scn};
  $cmd =~ s/ set / setcmd / if( defined($FW_webArgs{cmd1}) && $FW_webArgs{cmd1} eq 'setcmd' );
# Debug "LS758: cmd: $cmd";
  AnalyzeCommand(undef,$cmd);
  #redirect to return to detail screen
  my $tgt = "?detail=$FW_webArgs{detail}";
  $tgt = $FW_ME.$tgt;
  $c = $defs{$FW_cname}->{CD};
  print $c "HTTP/1.1 302 Found\r\n",
            "Content-Length: 0\r\n",
            "Location: $tgt\r\n",
            "\r\n";
  return;
}
sub
LightScene_editTable($) {
  my ($hash) = @_;
  my $html="\n\n<!--Beginning Edit-Table-->\n";
  my $cmd='scn';
  #make dropdown
  my @tv = (sort keys %{ $hash->{SCENES} });
  unshift (@tv,'Choose scene');
  my $dd.="<form method=\"get\" action=\"" . $FW_ME . "/LightScene\">\n";
  $dd.=FW_select("$hash->{NAME}-$cmd","scn", \@tv, $scn,"dropdown","submit()")."\n";
  $dd.=FW_hidden("detail",$hash->{NAME}) . "\n";
  $dd.="</form>\n";
  # make table
  my @devices;
  if( $scn && defined($hash->{SCENES}{$scn}) ) {
    if( defined($hash->{switchingOrder}) && defined($hash->{switchingOrder}{$scn}) ) {
      @devices = @{$hash->{switchingOrder}{$scn}};
    } else {
      @devices = @{$hash->{devices}};
    }
  } else {
    $scn = '';
  }

  if ($scn eq "Choose scene" || $scn eq '') {
    $html.="<table><tr><td>Edit scene</td><td>$dd</td></tr>";
  } else {
    $html.="<table><tr><td>Edit scene</td><td>$dd</td></tr></table>";
    $html .= '<table class="block wide">';
    $html .= '<tr><th>Device</th><th>Command</th></tr>'."\n";
    my $row=0;
    #table rows
    my @cmds    = qw(set setcmd);
    my $set     = "set $hash->{NAME} set $scn";
    my $setcmd  = '';
    foreach my $dev (@devices) {
      $row+=1;
      $html .= "<tr class=\"".(($row&1)?"odd":"even")."\">";
      $html .= "<td>$dev</td>";
      my $default = $hash->{SCENES}{$scn}{$dev};

      if ($hash->{SCENES}{$scn}{$dev} =~ m/^;/) {
        $default =~ s/^;//;
        $setcmd='setcmd';
      } else {
        $setcmd='set';
      }
      $default = $default->{state} if( ref($default) eq 'HASH' );
      $html.="<td><form method=\"get\" action=\"" . $FW_ME . "/LightScene\">\n";
      $html.=FW_select('',"cmd1", \@cmds, $setcmd, 'select')."\n";
      $html.=FW_textfieldv("val.$dev", 50, 'class',$default)."\n";
      $html.=FW_hidden("dev.$dev", $dev) . "\n";
      $html.=FW_hidden("cmd.$dev", $set) . "\n";
      $html.=FW_submit("lse", 'saveline');
      $html.=FW_hidden("scn", $scn) . "\n";
      $html.=FW_hidden("detail",$hash->{NAME}) . "\n";
      $html .= "</form></td>\n";
    }
  }
  #table end
  $html .= "</table><br>\n";
  $html .= "<!--End Edit-Table-->\n";
  return $html;
}
1;

=pod
=item helper
=item summary   create scenes from multiple fhem devices
=item summary_DE verwaltet Szenen aus mehreren FHEM Ger&auml;ten
=begin html

<a name="LightScene"></a>
<h3>LightScene</h3>
<ul>
  Allows to store the state of a group of lights and other devices and recall it later.
  Multiple states for one group can be stored.

  <br><br>
  <a name="LightScene_Define"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; LightScene [&lt;dev1&gt;] [&lt;dev2&gt;] [&lt;dev3&gt;] ... </code><br>
    <br>

    Examples:
    <ul>
      <code>define light_group LightScene Lampe1 Lampe2 Dimmer1</code><br>
      <code>define kino_group LightScene LampeDecke LampeFernseher Fernseher Verstaerker</code><br>
      <code>define Wohnzimmer LightScene Leinwand Beamer TV Leselampe Deckenlampe</code><br>
    </ul>
  </ul><br>

  The device detail view will show an html overview of the current state of all included devices and all
  configured scenes with the device states for each. The column heading with the device names is clickable
  to go to detail view of this device. The first row that displays the current device state is clickable
  and should react like a click on the device icon in a room overview would. this can be used to interactively
  configure a new scene and save it with the command menu of the detail view. The first column of the table with
  the scene names ic clickable to activate the scene.<br><br>

  A weblink with a scene overview that can be included in any room or a floorplan can be created with:
   <ul><code>define wlScene weblink htmlCode {LightScene_2html("LightSceneName")}</code></ul>

  <a name="LightScene_Set"></a>
    <b>Set</b>
    <ul>
      <li>all &lt;command&gt;<br>
        execute set &lt;command&gt; for alle devices in this LightScene</li>
      <li>save &lt;scene_name&gt;<br>
        save current state for alle devices in this LightScene to &lt;scene_name&gt;</li>
      <li>scene &lt;scene_name&gt;<br>
        shows scene &lt;scene_name&gt; - all devices are switched to the previously saved state</li>
      <li>nextScene [nowrap]<br>
        activates the next scene in alphabetical order after the current scene or the first if no current scene is set.</li>
      <li>previousScene [nowrap]<br>
        activates the previous scene in alphabetical order before the current scene or the last if no current scene is set.</li>
      <li>set &lt;scene_name&gt; &lt;device&gt; [&lt;cmd&gt;]<br>
        set the saved state of &lt;device&gt; in &lt;scene_name&gt; to &lt;cmd&gt;</li>
      <li>setcmd &lt;scene_name&gt; &lt;device&gt; [&lt;cmd&gt;]<br>
        set command to be executed for &lt;device&gt; in &lt;scene_name&gt; to &lt;cmd&gt;.
      &lt;cmd&gt; can be any commandline that fhem understands including multiple commands separated by ;;
      <ul>
        <li>set kino_group setcmd allOff LampeDecke sleep 30 ;; set LampeDecke off</li>
        <li>set light_group setcmd test Lampe1 sleep 10 ;; set Lampe1 on ;; sleep 5 ;; set Lampe1 off</li>
      </ul></li>
      <li>clear [&lt;regex&gt;]<br>
        clears all scenes or all scenes matching &lt;regex&gt; from list of saved scenes</li>
      <li>remove &lt;scene_name&gt;<br>
        remove &lt;scene_name&gt; from list of saved scenes</li>
      <li>rename &lt;scene_old_name&gt; &lt;scene_new_name&gt;<br>
        rename &lt;scene_old_name&gt; to &lt;scene_new_name&gt;</li>
    </ul><br>

  <a name="LightScene_Get"></a>
    <b>Get</b>
    <ul>
      <li>scenes</li>
      <li>scene &lt;scene_name&gt;</li>
    </ul><br>

  <a name="LightScene_Attr"></a>
    <b>Attributes</b>
    <ul>
    <a name="async_delay"></a>
    <li>async_delay<br>
        If this attribute is defined, unfiltered set commands will not be
        executed in the clients immediately. Instead, they are added to a queue
        to be executed later. The set command returns immediately, whereas the
        clients will be set timer-driven, one at a time. The delay between two
        timercalls is given by the value of async_delay (in seconds) and may be
        0 for fastest possible execution.
        </li>
      <li>lightSceneParamsToSave<br>
        this attribute can be set on the devices to be included in a scene. it is set to a comma separated list of readings
        that will be saved. multiple readings separated by : are collated in to a single set command (this has to be supported
        by the device). each reading can have a perl expression appended with '@' that will be used to alter the $value used for
        the set command. this can for example be used to strip a trailing % from a dimmer state. this perl expression must not contain
        spaces,colons or commas.<br>
        in addition to reading names the list can also contain expressions of the form <code>abc -> xyz</code>
        or <code>get cba -> set uvw</code> to map reading abc to set xyz or get cba to set uvw. the list can be given as a
        string or as a perl expression enclosed in {} that returns this string.<br>
        <code>attr myReceiver lightSceneParamsToSave volume,channel</code><br>
        <code>attr myHueDevice lightSceneParamsToSave {(Value($DEVICE) eq "off")?"state":"bri : xy"}</code></li>
        <code>attr myDimmer lightSceneParamsToSave state@{if($value=~m/(\d+)/){$1}else{$value}}</code><br>
      <li>lightSceneRestoreOnlyIfChanged<br>
        this attribute can be set on the lightscene and/or on the individual devices included in a scene.
        the device settings have precedence over the scene setting.<br>
        1 -> for each device do nothing if current device state is the same as the saved state<br>
        0 -> always set the state even if the current state is the same as the saved state. this is the default</li>
      <li>followDevices<br>
        the LightScene tries to follow the switching state of the devices set its state to the name of the scene that matches.<br>
        1 -> if no match is found state will be unchanged and a nomatch event will be triggered.<br>
        2 -> if no match is found state will be set to unknown. depending on the scene and devices state can toggle multiple
             times. use a watchdog if you want to handle this.</li>
      <li>showDeviceCurrentState<br>
        show the current state of member devices in weblink</li>
      <li>switchingOrder<br>
        space separated list of &lt;scene&gt;:&lt;deviceList&gt; items that will give a per scene order
        in which the devices should be switched.<br>
        the devices from &lt;deviceList&gt; will come before all other devices of this LightScene;
        if the first character of the &lt;deviceList&gt; ist a ! the devices from the list will come after
        all other devices from this lightScene.<br>
        &lt;scene&gt; and each element of &lt;deviceList&gt; are treated as a regex.<br>
        Example: To switch a master power outlet before every other device at power on and after every device on power off:<br>
        <code>define media LightScene TV,DVD,Amplifier,masterPower<br>
              attr media switchingOrder .*On:masterPower,.* allOff:!.*,masterPower</code>
        </li>
      <li>traversalOrder<br>
        comma separated list of scene names that should be traversed by the prevoiusScene and nextScene commands.<br>
        default not set -> all scenes will be traversed in alphabetical order
        </li>
      <li><a href="#readingFnAttributes">readingFnAttributes</a></li>
    </ul><br>
</ul>

=end html
=cut
