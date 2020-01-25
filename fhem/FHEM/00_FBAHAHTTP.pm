##############################################
# $Id: 00_FBAHAHTTP.pm 19019 2019-03-24 17:39:43Z rudolfkoenig $
package main;

# Documentation: AHA-HTTP-Interface.pdf, AVM_Technical_Note_-_Session_ID.pdf

use strict;
use warnings;
use Time::HiRes qw(gettimeofday);
use FritzBoxUtils;

sub
FBAHAHTTP_Initialize($)
{
  my ($hash) = @_;
  $hash->{WriteFn}  = "FBAHAHTTP_Write";
  $hash->{DefFn}    = "FBAHAHTTP_Define";
  $hash->{SetFn}    = "FBAHAHTTP_Set";
  $hash->{GetFn}    = "FBAHAHTTP_Get";
  $hash->{AttrFn}   = "FBAHAHTTP_Attr";
  $hash->{ReadyFn}  = "FBAHAHTTP_Ready";
  $hash->{RenameFn} = "FBAHAHTTP_RenameFn";
  $hash->{DeleteFn} = "FBAHAHTTP_Delete";
  $hash->{AttrList} = "dummy:1,0 fritzbox-user polltime async_delay ".
                      "disable:0,1 disabledForIntervals fbTimeout";
}


#####################################
sub
FBAHAHTTP_Define($$)
{
  my ($hash, $def) = @_;
  my @a = split("[ \t][ \t]*", $def);

  return "wrong syntax: define <name> FBAHAHTTP hostname"
    if(@a != 3);

  $hash->{Clients} = ":FBDECT:";
  my %matchList = ( "1:FBDECT" => ".*" );
  $hash->{MatchList} = \%matchList;

  # Moving definition from FBAHA to FBAHAHTTP
  for my $d (devspec2array("TYPE=FBDECT")) {
    if($defs{$d}{IODev} && $defs{$d}{IODev}{TYPE} eq "FBAHA") {
      my $n = $defs{$d}{IODev}{NAME};
      CommandAttr(undef, "$d IODev $hash->{NAME}");
      CommandDelete(undef, $n) if($defs{$n});
      $defs{$d}{IODev} = $hash;

      my $oldNr = $defs{$d}{IODev}{NR}; # Forum #92286
      $hash->{NR} = $oldNr if($hash->{NR} > $oldNr);
    }
  }
  $hash->{CmdStack} = ();

  return undef if($hash->{DEF} eq "none"); # DEBUGGING
  InternalTimer(1, "FBAHAHTTP_Poll", $hash);
  $hash->{STATE} = "defined";
  return undef;
}

#####################################
sub
FBAHAHTTP_Delete($)
{
  my ($hash) = @_;
  my $name = $hash->{NAME};
  my ($err, $fb_pw) = setKeyValue("FBAHAHTTP_PASSWORD_$name", undef);
  return $err;
}

sub
FBAHAHTTP_connect($$)
{
  my ($hash, $doProcess) = @_;
  my $name = $hash->{NAME};
  my $dev = $hash->{DEF};

  my $dr = sub {
    $hash->{STATE} = $_[0];
    Log 2, $hash->{STATE};
    $hash->{CmdStack} = ();
    return $hash->{STATE};
  };

  my $fb_user = AttrVal($name, "fritzbox-user", '');
  return $dr->("MISSING: attr $name fritzbox-user") if(!$fb_user);

  my ($err, $fb_pw) = getKeyValue("FBAHAHTTP_PASSWORD_$name");
  return $dr->("ERROR: $err") if($err);
  return $dr->("MISSING: set $name password") if(!$fb_pw);

  my $sid = FB_doCheckPW($hash->{DEF}, $fb_user, $fb_pw);
  if(!$sid) {
    $hash->{NEXT_OPEN} = time()+60;
    $readyfnlist{"$name.$dev"} = $hash;
    return $dr->("$name error: cannot get SID, ".
                      "check connection/hostname/fritzbox-user/password")
  }

  delete($hash->{RetriedCmd});
  delete($readyfnlist{"$name.$dev"});
  $hash->{".SID"} = $sid;
  $hash->{STATE} = "connected";
  Log3 $name, 4, "FBAHAHTTP_connect $name: got SID $sid";
  FBAHAHTTP_ProcessStack($hash)
        if($doProcess && $hash->{CmdStack} && int(@{$hash->{CmdStack}}));
  return undef;
}

sub
FBAHAHTTP_RenameFn($$)
{
  my ($new, $old) = @_;
  for my $d (devspec2array("TYPE=FBDECT")) {
    my $hash = $defs{$d};
    next if(!$hash);
    $hash->{DEF} =~ s/^$old:/$new:/;
    $attr{$d}{IODev} = $new if(AttrVal($d,"IODev","") eq $old);
  }
  FBDECT_renameIoDev($new, $old);
}

#####################################
sub
FBAHAHTTP_Poll($)
{
  my ($hash) = @_;
  my $name = $hash->{NAME};

  return if(IsDisabled($name));

  if(!$hash->{".SID"}) {
    my $ret = FBAHAHTTP_connect($hash, 0);
    return $ret if($ret);
  }
  my $sid = $hash->{".SID"};
  my $host = ($hash->{DEF} =~ m/^http/i ? $hash->{DEF} : "http://$hash->{DEF}");

  HttpUtils_NonblockingGet({
    url=>"$host/webservices/homeautoswitch.lua?sid=$sid".
         "&switchcmd=getdevicelistinfos",
    loglevel => AttrVal($name, "verbose", 4),
    timeout => AttrVal($name, "fbTimeout", 4),
    callback => sub {
      if($_[1]) {
        Log3 $name, 3, "$name: $_[1]";
        delete $hash->{".SID"};
        return;
      }

      Log 5, $_[2] if(AttrVal($name, "verbose", 1) >= 5);
      if($_[2] !~ m,^<devicelist.*</devicelist>$,s) {
        Log3 $name, 3, "$name: unexpected reply from device: $_[2]";
        delete $hash->{".SID"};
        return;
      }

      $_[2] =~ s+<(device|group) (.*?)</\g1>+
                Dispatch($hash, "<$1 $2</$1>", undef);""+gse;      # Quick&Hack
    }
  });

  my $polltime = AttrVal($name, "polltime", 300);
  RemoveInternalTimer($hash);
  InternalTimer(gettimeofday()+$polltime, "FBAHAHTTP_Poll", $hash);
  return;
}

#####################################
sub
FBAHAHTTP_Ready($)
{
  my ($hash) = @_;

  return if($hash->{NEXT_OPEN} && time() < $hash->{NEXT_OPEN});
  FBAHAHTTP_Poll($hash);
}

#####################################
sub
FBAHAHTTP_Attr($@)
{
  my ($type, $devName, $attrName, @param) = @_;
  my $hash = $defs{$devName};

  if($attrName eq "fritzbox-user") {
    return "Cannot delete fritzbox-user" if($type eq "del");
    if($init_done) {
      delete($hash->{".SID"});
      InternalTimer(1, sub { FBAHAHTTP_Poll($hash); }, 0);
    }
  }
  return undef;
}

#####################################
sub
FBAHAHTTP_Set($@)
{
  my ($hash, @a) = @_;
  my $name = shift @a;
  my %sets = (password=>2, refreshstate=>1,template=>2);

  return "set $name needs at least one parameter" if(@a < 1);
  my $type = shift @a;

  my $tl = ReadingsVal($name,"templateList","");
  my $cmdList = "refreshstate:noArg password".($tl ? " template:$tl" : "");
  return "Unknown argument $type, choose one of $cmdList"
    if(!defined($sets{$type}));
  return "Missing argument for $type" if(int(@a) < $sets{$type}-1);

  if($type eq "password") {
    setKeyValue("FBAHAHTTP_PASSWORD_$name", $a[0]);
    delete($hash->{".SID"});
    FBAHAHTTP_Poll($hash);

  } elsif($type eq "refreshstate") {
    FBAHAHTTP_Poll($hash);

  } elsif($type eq "template") {
    my $cl = $hash->{CL};
    my $doRet = sub($)
    {
      if($cl) {
        asyncOutput($cl, $_[0]);
      } else {
        Log3 $hash, 4, "$_";
      }
    };
    FBAHAHTTP_GetTemplateList($hash, sub($$){
      my ($err, $r) = @_;
      return $doRet->($err) if($err);
      return $doRet->("Unknown template $a[0]") if(!defined($r->{$a[0]}));
      FBAHAHTTP_Write($hash, $r->{$a[0]}, "applytemplate");
    });
  }

  return undef;
}

sub
FBAHAHTTP_GetTemplateList($$)
{
  my ($hash, $callbackFn) = @_;

  my $host = ($hash->{DEF} =~ m/^http/i ? $hash->{DEF}:"http://$hash->{DEF}");
  my $sid = $hash->{".SID"};
  my $name = $hash->{NAME};
  return "No SID found" if(!$sid);
  HttpUtils_NonblockingGet({
    url=>"$host/webservices/homeautoswitch.lua?".
         "sid=$sid&switchcmd=gettemplatelistinfos",
    loglevel => AttrVal($name, "verbose", 4),
    timeout => AttrVal($name, "fbTimeout", 4),
    callback => sub {
      if($_[1]) {
        delete $hash->{".SID"};
        return $callbackFn->("$name: $_[1]");
      }
      my $ret = (defined($_[2]) ? $_[2] : "") ;
      my %r;
      $ret =~ s:<template identifier="([^"]*)".*?<name>([^<]+)</name>:
                $r{$2}=$1:ge;
      $callbackFn->(undef, \%r);
    }
  });
}

#####################################
sub
FBAHAHTTP_Get($@)
{
  my ($hash, @a) = @_;
  my $name = shift @a;
  my %gets = (templatelist=>1);
  return "get $name needs at least one parameter" if(@a < 1);
  my $type = shift @a;
  my $cl = $hash->{CL};

  return "Unknown argument $type, choose one of templatelist:noArg"
    if(!defined($gets{$type}));
  return "Missing argument for $type" if(int(@a) < $gets{$type}-1);

  if($type eq "templatelist") {
    my $doRet = sub($)
    {
      if($cl) {
        asyncOutput($cl, $_[0]);
      } else {
        Log3 $hash, 4, "$_";
      }
    };
    FBAHAHTTP_GetTemplateList($hash, sub($$){
      my ($err, $r) = @_;
      return $doRet->($err) if($err);
      my $str = join(",",sort keys %{$r});
      readingsSingleUpdate($hash, "templateList", $str, 1);
      $doRet->($str);
    });
  }
  return undef;
}

sub
FBAHAHTTP_ProcessStack($)
{
  my ($hash) = @_;
  my $name = $hash->{NAME};
  my $msg = $hash->{CmdStack}->[0];
  my $host = ($hash->{DEF} =~ m/^http/i ? $hash->{DEF} : "http://$hash->{DEF}");
  my $sid = $hash->{".SID"};
  return if(!$sid);
  HttpUtils_NonblockingGet({
    url=>"$host/webservices/homeautoswitch.lua?sid=$sid&$msg",
    loglevel => AttrVal($name, "verbose", 4),
    timeout => AttrVal($name, "fbTimeout", 4),
    callback => sub {
      if($_[1]) {
        Log3 $name, 3, "$name: $_[1]";
        delete $hash->{".SID"};
        $hash->{CmdStack} = ();
        return;
      }
      
      my $ret = (defined($_[2]) ? $_[2] : "") ;
      $ret =~ s/[\r\n]//g;
      Log3 $name, 5, "FBAHAHTTP_Write reply for $name: $ret";
      if($ret eq "") {
        if($hash->{RetriedCmd}) {
          Log3 $name, 1,
                "No sensible response for $msg after reconnect, giving up";
          $hash->{CmdStack} = ();
          return;
        }
        return if(FBAHAHTTP_connect($hash, 0));
        $hash->{RetriedCmd} = $msg;
        FBAHAHTTP_ProcessStack($hash);
        return;
      }

      delete($hash->{RetriedCmd});
      shift @{$hash->{CmdStack}};
      if(@{$hash->{CmdStack}} > 0) {
        my $ad = AttrVal($name, "async_delay", 0);
        InternalTimer(gettimeofday()+$ad, sub(){
          FBAHAHTTP_ProcessStack($hash);
        }, $hash);
      }
    }
  });
}

#####################################
sub
FBAHAHTTP_Write($$$)
{
  my ($hash,$fn,$msg) = @_;
  my $name = $hash->{NAME};

  return if(IsDisabled($name));

  my $sid = $hash->{".SID"};
  if(!$sid) {
    my $ret = FBAHAHTTP_connect($hash, 1);      # try to reconnect
    return $ret if($ret);
    $sid = $hash->{".SID"};
  }
  $fn =~ s/ //g;
  push(@{$hash->{CmdStack}}, "ain=$fn&switchcmd=$msg");
  FBAHAHTTP_ProcessStack($hash) if(@{$hash->{CmdStack}} == 1);
}


1;

=pod
=item summary    connection to the Fritz!OS AHA Server via HTTP
=item summary_DE Anbindung des Fritz!OS AHA Servers &uuml;ber HTTP
=begin html

<a name="FBAHAHTTP"></a>
<h3>FBAHAHTTP</h3>
<ul>
  This module connects to the AHA server (AVM Home Automation) on a FRITZ!Box
  via HTTP, it is a successor/drop-in replacement for the FBAHA module.  It is
  necessary, as the FBAHA interface is deprecated by AVM. Since the AHA HTTP
  interface do not offer any notification mechanism, the module is regularly
  polling the FRITZ!Box.<br>
  Important: For an existing installation with an FBAHA device, defining a
  new FBAHAHTTP device will change the IODev of all FBDECT devices from the
  old FBAHA to this FBAHAHTTP device, and it will delete the FBAHA device.<br>

  This module serves as the "physical" counterpart to the <a
  href="#FBDECT">FBDECT</a> devices. Note: you have to enable the access to
  Smart Home in the FRITZ!Box frontend for the fritzbox-user, and take care
  to configure the login in the home network with username AND password.
  <br><br>
  <a name="FBAHAHTTPdefine"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; FBAHAHTTP &lt;hostname&gt;</code><br>
    <br>
    &lt;hostnamedevice&gt; is most probably fritz.box.
    Example:
    <ul>
      <code>define fb1 FBAHAHTTP fritz.box</code><br>
    </ul>
    Note: to specify HTTPS for the connection use https://fritz.box as
    hostname. To explicitly specify the port, postfix the hostname with :port,
    as in https://fritz.box:443
  </ul>
  <br>

  <a name="FBAHAHTTPset"></a>
  <b>Set</b>
  <ul>
  <li>password &lt;password&gt;<br>
    This is the only way to set the password
    </li>
  <li>refreshstate<br>
    The state of all devices is polled every &lt;polltime&gt; seconds (default
    is 300). This command forces a state-refresh.
    </li>
  <li>template &lt;templateName&gt;<br>
    Set the the template. Note: currently not working, for unknown reason.
    </li>
  </ul>
  <br>

  <a name="FBAHAHTTPget"></a>
  <b>Get</b>
  <ul>
  <li>templateList<br>
    get the list of templates from the Fritz!Box, and store the in the
    templateList reading. Needed for the set template command.
    </li>
  </ul>
  <br>

  <a name="FBAHAHTTPattr"></a>
  <b>Attributes</b>
  <ul>
    <li><a href="#async_delay">async_delay</a><br>
      additional delay inserted, when switching more than one device, default
      is 0.2 seconds. Note: even with async_delay 0 there will be a delay, as
      FHEM avoids sending commands in parallel, to avoid malfunctioning of the
      Fritz!BOX AHA server).
      </li>
    <li><a href="#disable">disable</a></li>
    <li><a href="#disabledForIntervals">disabledForIntervals</a></li>
    <li><a href="#dummy">dummy</a></li>
    <li><a href="#fritzbox-user">fritzbox-user</a></li>
    <li><a name="polltime">polltime</a><br>
      measured in seconds, default is 300 i.e. 5 minutes
      </li>
    <li><a name="fbTimeout">fbTimeout</a><br>
      timeout for getting answer from the Fritz!BOX. Default is 4 (seconds).
      </li>
  </ul>
  <br>
</ul>


=end html

=cut
