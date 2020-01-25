##############################################
# $Id: 16_STACKABLE_CC.pm 18467 2019-01-31 08:02:51Z rudolfkoenig $
package main;
use strict;
use warnings;

#####################################
sub
STACKABLE_CC_Initialize($)
{
  my ($hash) = @_;
  LoadModule("CUL");

  $hash->{Match}     = "^\\*";
  $hash->{DefFn}     = "STACKABLE_CC_Define";
  $hash->{UndefFn}   = "STACKABLE_CC_Undef";
  $hash->{ParseFn}   = "STACKABLE_CC_Parse";
  $hash->{NotifyFn}  = "STACKABLE_CC_Notify";
  $hash->{AttrFn}    = "CUL_Attr";
  $hash->{AttrList}  = "IODev ignore:0,1 ".$modules{CUL}{AttrList};

  $hash->{WriteFn}   = "STACKABLE_CC_Write";
  $hash->{GetFn}     = "CUL_Get";
  $hash->{SetFn}     = "CUL_Set";
  $hash->{AddPrefix} = "STACKABLE_CC_AddPrefix"; 
  $hash->{DelPrefix} = "STACKABLE_CC_DelPrefix"; 
  $hash->{noRawInform} = 1;     # Our message was already sent as raw.
  $hash->{noAutocreatedFilelog} = 1;

  $hash->{IOOpenFn}  = "STACKABLE_CC_IOOpenFn";
  $hash->{IOReadFn}  = "STACKABLE_CC_IOReadFn";
  $hash->{IOWriteFn} = "STACKABLE_CC_IOWriteFn";
}

#####################################
sub
STACKABLE_CC_Define($$)
{
  my ($hash, $def) = @_;
  my @a = split("[ \t][ \t]*", $def);

  $hash->{TCM} = pop @a if(int(@a) == 4 && $a[3] eq "TCM");

  return "wrong syntax: define <name> STACKABLE_CC [CUL|SCC] [TCM]"
    if(int(@a) != 3);

  my $io = $defs{$a[2]};
  return "$a[2] is not a CUL/STACKABLE_CC"
    if(!$io || $io->{TYPE} !~ m/^(CUL|TSCUL|STACKABLE_CC|TSSTACKED)$/);

  return "$io->{NAME} has alread a stacked device: $io->{STACKED}"
    if($io->{STACKED});

  $io->{STACKED} = $hash->{NAME};
  $hash->{IODev} = $io;
  delete($io->{".clientArray"}); # Force a recompute

  if(!$hash->{TCM}) {
    $hash->{initString} = $io->{initString};
    $hash->{CMDS} = "";
    $hash->{Clients} = $io->{Clients};
    $hash->{MatchList} = $io->{MatchList};
    CUL_DoInit($hash);
  }

  $hash->{StackLevel} = $io->{StackLevel} ? $io->{StackLevel}+1 : 1;
  $hash->{STATE} = "Defined";

  notifyRegexpChanged($hash, $a[2]);

  return undef;
}

sub
STACKABLE_CC_DoNotify($)
{
  my ($ntfy) = @_;
  DoTrigger($ntfy->{NAME}, $ntfy->{TriggerText});
  delete $ntfy->{TriggerText};
}

sub
STACKABLE_CC_Notify($$)
{
  my ($ntfy, $dev) = @_;
  my $events = deviceEvents($dev, 0);

  for(my $i = 0; $i < @{$events}; $i++) {

    if($events->[$i] eq "DISCONNECTED") {
      $ntfy->{STATE} = "disconnected";
      setReadingsVal($ntfy, "state", "disconnected", TimeNow());
      $ntfy->{TriggerText} = $events->[$i];
      InternalTimer(gettimeofday()+0.1, "STACKABLE_CC_DoNotify", $ntfy, 0);

    } elsif($events->[$i] eq "CONNECTED") {
      CUL_DoInit($ntfy);
      $ntfy->{TriggerText} = $events->[$i];
      InternalTimer(gettimeofday()+0.001, "STACKABLE_CC_DoNotify", $ntfy, 0);

    }
  }
}

#####################################
sub
STACKABLE_CC_Write($$)
{
  my ($hash,$fn,$msg) = @_;

  ($fn, $msg) = CUL_WriteTranslate($hash, $fn, $msg);
  return if(!defined($fn));
  IOWrite($hash, "", ($hash->{TCM} ? "%":"*")."$fn$msg"); # No more translations
}

#####################################
sub
STACKABLE_CC_Parse($$)
{
  my ($iohash,$msg) = @_;

  $msg =~ s/^.//; # Cut off prefix *
  my $name = $iohash->{STACKED} ? $iohash->{STACKED} : "";

  my $id = $iohash->{StackLevel} ? $iohash->{StackLevel}+1 : 1;
  return "UNDEFINED STACKABLE_CC_$id STACKABLE_CC $iohash->{NAME}"
    if(!$name);

  return "" if(IsIgnored($name));

  my $sh = $defs{$name};
  if($sh && $sh->{TCM}) {
    my $th = $sh->{TCMHash};
    if($th) {
      delete $th->{IOReadFn};
      $th->{IODevRxBuffer} = pack("H*", $msg);
      CallFn($th->{NAME}, "ReadFn", $th);
      $th->{IOReadFn} = "STACKABLE_CC_IOReadFn";
    } else {
      Log 1, "$name: no TCM device assigned";
    }
    
  } else {
    CUL_Parse($defs{$name}, $iohash, $name, $msg);
  }
  return "";
}

sub
STACKABLE_CC_DelPrefix($$)
{
  my ($hash, $msg) = @_;
  $msg =~ s/^[^A-Z0-9]//i;
  return $msg;
}

sub
STACKABLE_CC_AddPrefix($$)
{
  my ($hash, $msg) = @_;
  return "*$msg";
}

sub
STACKABLE_CC_Undef($$)
{
  my ($hash, $arg) = @_;
  CUL_SimpleWrite($hash, "X00");
  delete $hash->{IODev}{STACKED};
  return undef;
}

sub
STACKABLE_CC_IOOpenFn($)
{
  my ($hash) = @_;
  $hash->{FD} = $hash->{IODev}{IODev}{FD};     # Lets fool the TCM
  $hash->{IODev}{TCMHash} = $hash;
  $hash->{IOReadFn} = "STACKABLE_CC_IOReadFn";
  return 1;
}

sub
STACKABLE_CC_IOReadFn($)
{
  my ($hash) = @_;
  my $me = $hash->{IODev};
  my $buf = "";
  while($buf !~ m/\n/) {
    $buf .= DevIo_SimpleRead($me->{IODev}); # may block
  }
  $buf =~ s/[\r\n]//g;
  $buf = STACKABLE_CC_DelPrefix($me, $buf);
  return pack("H*",$buf);
}

sub
STACKABLE_CC_IOWriteFn($$)
{
  my ($hash, $msg) = @_;
  return IOWrite($hash, "", unpack("H*",$msg));
}

1;


=pod
=item summary    Busware Stackable CC (SCC) base module
=item summary_DE Busware Stackabble CC (SCC) basis Modul
=begin html

<a name="STACKABLE_CC"></a>
<h3>STACKABLE_CC</h3>
<ul>
  This module handles the stackable CC1101 devices for the Raspberry PI from
  busware.de. You can attach a lot of CUL-Type devices to a single RPi this way.
  The first device is defined as a CUL, the rest of them as STACKABLE_CC.
  <br><br>

  <a name="STACKABLE_CCdefine"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; STACKABLE_CC &lt;Base-Device-Name&gt;</code> <br>
    <br>
    &lt;Base-Device-Name&gt; is the name of the device, which this device is
    attached on, the first one has to be defined as a CUL device<br>
    Example:
    <ul><code>
      define SCC0 CUL /dev/ttyAMA0@38400<br>
      attr SCC0 rfmode SlowRF<br>
      define SCC1 STACKABLE_CC SCC0<br>
      attr SCC1 rfmode HomeMatic<br>
      define SCC2 STACKABLE_CC SCC1<br>
      attr SCC2 rfmode Max<br>
    </code></ul>
    <b>Important:</b>
    <ul>
      <li>The rfmode has to be specified explicitely (valid for the STACKABLE_CC
        types only, not for the first, which is defined as a CUL).</li>
      <li>In case of SlowRF, the FHTID has to be specified explicitely with the
        command "set SCCX raw T01HHHH". Again, this is valid for the STACKABLE_CC
        types only.</li>
      <li>If you rename the base CUL or a STACKABLE_CC, which is a base for
        another one, the define of the next one has to be adjusted, and FHEM has to be
        restarted.</li>
    </ul>
  </ul>

  <a name="STACKABLE_CCset"></a>
  <b>Set</b> <ul>Same as for the <a href="#CULset">CUL</a>.</ul><br>

  <a name="STACKABLE_CCget"></a>
  <b>Get</b> <ul>Same as for the <a href="#CULget">CUL</a>.</ul><br>

  <a name="STACKABLE_CCattr"></a>
  <b>Attributes</b>
  <ul>
    <li><a href="#IODev">IODev</a></li><br>
    <li><a href="#ignore">ignore</a></li><br>
    The rest of the attributes is the same as for the <a href="#CULattr">CUL</a>.
  </ul>
</ul>

=end html

=begin html_DE

<a name="STACKABLE_CC"></a>
<h3>STACKABLE_CC</h3>
<ul>
  Mit Hilfe dieses Moduls kann man die "Stackable CC" Ger&auml;te von busware.de in
  FHEM integrieren. Diese Ger&auml;te erm&ouml;glichen eine Menge von CULs an einem RPi
  anzuschliessen.
  Das erste Ger&auml;t wird als CUL definiert, alle nachfolgenden als STACKABLE_CC.
  <br><br>

  <a name="STACKABLE_CCdefine"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; STACKABLE_CC &lt;Base-Device-Name&gt;</code> <br>
    <br>
    &lt;Base-Device-Name&gt; ist der Name des Ger&auml;tes, der als Basis f&uuml;r das
    aktuelle Ger&auml;t dient.<br>
    Beispiel:
    <ul><code>
      define SCC0 CUL /dev/ttyAMA0@38400<br>
      attr SCC0 rfmode SlowRF<br>
      define SCC1 STACKABLE_CC SCC0<br>
      attr SCC1 rfmode HomeMatic<br>
      define SCC2 STACKABLE_CC SCC1<br>
      attr SCC2 rfmode Max<br>
    </code></ul>
    <b>Wichtig:</b>
    <ul>
      <li>Das rfmode Attribut muss explizit spezifiziert werden. Das gilt nur
        f&uuml;r die STACKABLE_CC Definitionen, und nicht f&uuml;r die erste, die
        als CUL definiert wurde.</li>
      <li>Falls SlowRF spezifiziert wurde, dann muss das FHTID explizit gesetzt
        werden, mit folgendem Kommando: "set SCCX raw T01HHHH". Auch das ist nur
        f&uuml;r die STACKABLE_CC n&ouml;tig.</li>
      <li>Falls ein Ger&auml;t umbenannt wird, was als Basis f&uuml;r ein STACKABLE_CC
        dient, dann muss es auch in der Definition des abh&auml;ngigen Ger&auml;tes
        umbenannt werden, und FHEM muss neugestartet werden.</li>
    </ul>
  </ul>

  <a name="STACKABLE_CCset"></a>
  <b>Set</b> <ul>Die gleichen wie f&uuml;r das <a href="#CULset">CUL</a>.</ul><br>

  <a name="STACKABLE_CCget"></a>
  <b>Get</b> <ul>Die gleichen wie f&uuml;r das <a href="#CULget">CUL</a>.</ul><br>

  <a name="STACKABLE_CCattr"></a>
  <b>Attributes</b>
  <ul>
    <li><a href="#IODev">IODev</a></li><br>
    <li><a href="#ignore">ignore</a></li><br>
    Die anderen Attribute sind die gleichen wie f&uuml;r das <a href="#CULattr">CUL</a>.
  </ul>
</ul>
=end html_DE

=cut
