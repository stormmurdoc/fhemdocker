##############################################
# $Id: 00_HMLAN.pm 18152 2019-01-05 23:18:38Z martinp876 $
package main;


use strict;
use warnings;
use Time::HiRes qw(gettimeofday time);
use Digest::MD5 qw(md5);

sub HMLAN_Initialize($);
sub HMLAN_Define($$);
sub HMLAN_Undef($$);
sub HMLAN_RemoveHMPair($);
sub HMLAN_Attr(@);
sub HMLAN_Set($@);
sub HMLAN_ReadAnswer($$$);
sub HMLAN_Write($$$);
sub HMLAN_Read($);
sub HMLAN_uptime($@);
sub HMLAN_Parse($$);
sub HMLAN_Ready($);
sub HMLAN_SimpleWrite(@);
sub HMLAN_DoInit($);
sub HMLAN_KeepAlive($);
sub HMLAN_secSince2000();
sub HMLAN_relOvrLd($);
sub HMLAN_condUpdate($$);
sub HMLAN_getVerbLvl ($$$$);

my %sets = ( "open"         => ""
            ,"close"        => ""
            ,"reopen"       => ""
            ,"restart"      => ""
            ,"hmPairForSec" => "HomeMatic"
            ,"hmPairSerial" => "HomeMatic"
            ,"reassignIDs"  => ""
);
my %gets = ( "assignIDs"    => ""
);
my %HMcond = ( 0  =>'ok'
              ,2  =>'Warning-HighLoad'
              ,4  =>'ERROR-Overload'
              ,251=>'dummy'
              ,252=>'timeout'
              ,253=>'disconnected'
              ,254=>'Overload-released'
              ,255=>'init');

my $HMmlSlice = 12; # number of messageload slices per hour (10 = 6min)

sub HMLAN_Initialize($) {
  my ($hash) = @_;

  require "$attr{global}{modpath}/FHEM/DevIo.pm";

# Provider
  $hash->{ReadFn}  = "HMLAN_Read";
  $hash->{WriteFn} = "HMLAN_Write";
  $hash->{ReadyFn} = "HMLAN_Ready";
  $hash->{SetFn}   = "HMLAN_Set";
  $hash->{GetFn}   = "HMLAN_Get";
  $hash->{NotifyFn}= "HMLAN_Notify";
  $hash->{AttrFn}  = "HMLAN_Attr";
  $hash->{Clients} = ":CUL_HM:";
  my %mc = (
    "1:CUL_HM" => "^A......................",
  );
  $hash->{MatchList} = \%mc;

# Normal devices
  $hash->{DefFn}   = "HMLAN_Define";
  $hash->{UndefFn} = "HMLAN_Undef";
  $hash->{AttrList}= "do_not_notify:1,0 dummy:1,0 " .
                     "addvaltrigger " .
                     "hmId hmKey hmKey2 hmKey3 ".#hmKey4 hmKey5 " .
                     "respTime " .
                     "hmProtocolEvents:0_off,1_dump,2_dumpFull,3_dumpTrigger ".
                     "hmMsgLowLimit ".
                     "loadLevel ".
                     "hmLanQlen:1_min,2_low,3_normal,4_high,5_critical ".
                     "wdTimer:5,10,15,20,25 ".
                     "logIDs:multiple,sys,all,broadcast ".
                     $readingFnAttributes;
}
sub HMLAN_Define($$) {#########################################################
  my ($hash, $def) = @_;
  my @a = split("[ \t][ \t]*", $def);

  if(@a != 3) {
    my $msg = "wrong syntax: define <name> HMLAN ip[:port]";
    Log3 $hash, 2, $msg;
    return $msg;
  }
  DevIo_CloseDev($hash);

  my $name = $a[0];
  my $dev = $a[2];
  $dev .= ":1000" if($dev !~ m/:/ && $dev ne "none" && $dev !~ m/\@/);

  if($dev eq "none") {
    Log3 $hash, 1, "$name device is none, commands will be echoed only";
    $attr{$name}{dummy} = 1;
    return undef;
  }
  $attr{$name}{hmLanQlen} = "1_min"; #max message queue length in HMLan

  no warnings 'numeric';
  $hash->{helper}{q}{hmLanQlen} = int($attr{$name}{hmLanQlen})+0;
  use warnings 'numeric';
  $hash->{DeviceName} = $dev;
  $hash->{msgKeepAlive} = "";   # delay of trigger Alive messages
  $hash->{helper}{k}{DlyMax} = 0;
  $hash->{helper}{k}{BufMin} = 30;

  $hash->{helper}{q}{answerPend} = 0;#pending answers from LANIf
  my @arr = ();
  @{$hash->{helper}{q}{apIDs}} = \@arr;

  $hash->{helper}{q}{scnt}        = 0;
  $hash->{helper}{q}{loadNo}      = 0;
  $hash->{helper}{q}{loadLastMax} = 0;   # max load in last slice
  my @ald = ("0") x $HMmlSlice;
  $hash->{helper}{q}{ald}         = \@ald;  # array of load events  
  $hash->{msgLoadCurrent}         = 0;
  
  $defs{$name}{helper}{log}{all} = 0;# selective log support
  $defs{$name}{helper}{log}{sys} = 0;
  my @al = ();
  @{$hash->{helper}{log}{ids}} = \@al;

  $hash->{assignedIDsCnt}   = 0;#define hash
  $hash->{helper}{assIdRep} = 0;
  $hash->{helper}{assIdCnt} = 0;
  HMLAN_condUpdate($hash,253);#set disconnected
  readingsSingleUpdate($hash,"state","disconnected",1);
  $hash->{owner} = "";
  HMLAN_Attr("delete",$name,"loadLevel");

  my $ret = DevIo_OpenDev($hash, 0, "HMLAN_DoInit");
  return $ret;
}
sub HMLAN_Undef($$) {##########################################################
  my ($hash, $arg) = @_;
  my $name = $hash->{NAME};

  foreach my $d (sort keys %defs) {
    if(defined($defs{$d}) &&
       defined($defs{$d}{IODev}) &&
       $defs{$d}{IODev} == $hash){
        Log3 $hash, 2, "deleting port for $d";
        delete $defs{$d}{IODev};
      }
  }
  DevIo_CloseDev($hash);
  return undef;
}
sub HMLAN_RemoveHMPair($) {####################################################
  my($in ) = shift;
  my(undef,$name) = split(':',$in);
  my $hash = $defs{$name};
  RemoveInternalTimer("hmPairForSec:$name");
  delete($hash->{hmPair});
  delete($hash->{hmPairSerial});
}
sub HMLAN_Notify(@) {##########################################################
  my ($hash,$dev) = @_;
  if ($dev->{NAME} eq "global" && grep (m/^INITIALIZED$/,@{$dev->{CHANGED}})){
    if ($hash->{helper}{attrPend}){
      my $aVal = AttrVal($hash->{NAME},"logIDs","");
      HMLAN_Attr("set",$hash->{NAME},"logIDs",$aVal) if($aVal);
      delete $hash->{helper}{attrPend};
    }
    HMLAN_writeAesKey($hash->{NAME});
  }
  elsif ($dev->{NAME} eq $hash->{NAME}){
    foreach (grep (m/CONNECTED$/,@{$dev->{CHANGED}})) { # connect/disconnect
      if    ($_ eq "DISCONNECTED") {HMLAN_condUpdate($hash,253);}
#      elsif ($_ eq "CONNECTED")    {covered by init;}
    }
  }
  return;
}
sub HMLAN_Attr(@) {############################################################
  my ($cmd,$name, $aName,$aVal) = @_;
  if   ($aName eq "wdTimer" && $cmd eq "set"){#allow between 5 and 25 second
    return "select wdTimer between 5 and 25 seconds" if ($aVal>30 || $aVal<5);
    $attr{$name}{wdTimer} = $aVal;
    $defs{$name}{helper}{k}{Start} = 0;
   }
  elsif($aName eq "hmLanQlen"){
    if ($cmd eq "set"){
      no warnings 'numeric';
      $defs{$name}{helper}{q}{hmLanQlen} = int($aVal)+0;
      use warnings 'numeric';
    }
    else{
      $defs{$name}{helper}{q}{hmLanQlen} = 1;
    }
  }
  elsif($aName =~ m /^hmKey/){
    my $retVal= "";
    if ($cmd eq "set"){
      # eQ3 default key A4E375C6B09FD185F27C4E96FC273AE4
      my $kno = ($aName eq "hmKey")?1:substr($aName,5,1);
      my ($no,$val) = (sprintf("%02X",$kno),$aVal);
      if ($aVal =~ m/:/){#number given
        ($no,$val) = split ":",$aVal;
        return "illegal number:$no" if (hex($no) < 1 || hex($no) > 255 || length($no) != 2);
      }
      $attr{$name}{$aName} = "$no:".
                               (($val =~ m /^[0-9A-Fa-f]{32}$/ )
                                 ? $val
                                 : unpack('H*', md5($val)));
      $retVal = "$aName set to $attr{$name}{$aName}"
            if($aVal ne $attr{$name}{$aName});
    }
    else{
      delete $attr{$name}{$aName};
    }
    HMLAN_writeAesKey($name);
    return $retVal;
  }
  elsif($aName eq "hmMsgLowLimit"){
    if ($cmd eq "set"){
      return "hmMsgLowLimit:please add integer between 10 and 100"
          if (  $aVal !~ m/^(\d+)$/
              ||$aVal<10
              ||$aVal >100 );
      delete $defs{$name}{helper}{loadLvl}{h}{$aVal};
      my %lvlHr = reverse %{$defs{$name}{helper}{loadLvl}{h}};
      $lvlHr{batchLevel} = $aVal;
      my %lvlH = reverse %lvlHr;
      $defs{$name}{helper}{loadLvl}{h} = \%lvlH;
      my @a = sort { $b <=> $a } keys %lvlH;
      $defs{$name}{helper}{loadLvl}{a} = \@a;
      $attr{$name}{loadLevel} = join(",",map{"$_:$lvlH{$_}"}sort keys%lvlH);
      $defs{$name}{helper}{loadLvl}{bl} = $aVal;
    }
    if ($init_done){
      return "better use loadLevel batchLevel";
    }
  }
  elsif($aName eq "hmId"){
    if ($cmd eq "set"){
      my $owner_ccu = InternalVal($name,"owner_CCU",undef);
      return "device owned by $owner_ccu" if ($owner_ccu);
      return "wrong syntax: hmId must be 6-digit-hex-code (3 byte)"
        if ($aVal !~ m/^[A-F0-9]{6}$/i);
    }
  }
  elsif($aName eq "logIDs"){
    HMLAN_UpdtLogId();
    if ($cmd eq "set"){
      if ($init_done){
        if ($aVal){
          my @ids = split",",$aVal;
          my @idName;
          if (grep /sys/,@ids){
            push @idName,"sys";
            $defs{$name}{helper}{log}{sys}=1;
          }
          else{
            $defs{$name}{helper}{log}{sys}=0;
          }
          if (grep /all/,@ids){
            push @idName,"all";
            $defs{$name}{helper}{log}{all}=1;
          }
          else{
            $defs{$name}{helper}{log}{all}=0;
            for (@ids) {s/broadcast/000000/g};
            $_=substr(CUL_HM_name2Id($_),0,6) foreach(grep !/^$/,@ids);
            $_="" foreach(grep !/^[A-F0-9]{6}$/,@ids);
            @ids = HMLAN_noDup(@ids);
            push @idName,CUL_HM_id2Name($_) foreach(@ids);
            for (@idName) {s/000000/broadcast/g};
          }
          $attr{$name}{$aName} = join(",",@idName);
          @{$defs{$name}{helper}{log}{ids}}=grep !/^(sys|all)$/,@ids;
        }
        else{
          $attr{$name}{$aName} = "";
          @{$defs{$name}{helper}{log}{ids}}=();          
        }
      }
      else{
        $defs{$name}{helper}{attrPend} = 1;
        return;
      }
    }
    else{
      my @ids = ();
      $defs{$name}{helper}{log}{sys}=0;
      $defs{$name}{helper}{log}{all}=0;
      @{$defs{$name}{helper}{log}{ids}}=grep !/^(sys|all)$/,@ids;
    }
    return "logging set to $attr{$name}{$aName}"
        if ($aVal && $attr{$name}{$aName} ne $aVal);
  }
  elsif($aName eq "loadLevel"){
    my %lvlH;
    my $batchLevel = 40;#defailt batch level
    if ($cmd eq "set"){
      foreach my $lvl(sort split(",",$aVal)){
        next if(!$lvl);
        my @lvlSp = split(":",$lvl);
        return "$lvl not parsed. Only one Level per Entry:".scalar @lvlSp if (scalar @lvlSp != 2);
        return "$lvlSp[0] must be between 0 and 100" if (  $lvlSp[0] !~ m/^(\d+)$/
                                                                    ||$lvlSp[0]<0
                                                                    ||$lvlSp[0] >100 );
        $lvlH{$lvlSp[0]+0} = $lvlSp[1];
      }
      my %lvlHr = reverse %lvlH;
      $lvlH{0}  = "low"        if (!defined $lvlH{0});
      if (!defined $lvlHr{batchLevel}){
        $lvlH{$batchLevel} = "batchLevel";
      }
      else{
        $batchLevel = $lvlHr{batchLevel};
      }
    }
    else{#delete
      $lvlH{0}  = "low";
      $lvlH{$batchLevel} = "batchLevel";
      $lvlH{90} = "high";
      $lvlH{99} = "suspended";
    }
    $defs{$name}{helper}{loadLvl}{h} = \%lvlH;
    my @a = sort { $b <=> $a } keys %lvlH;
    $defs{$name}{helper}{loadLvl}{a} = \@a;
    $defs{$name}{helper}{loadLvl}{bl} = $batchLevel;
    $attr{$name}{loadLevel} = join(",",map{"$_:$lvlH{$_}"}sort keys%lvlH) if ($cmd ne "set");
  }
  elsif($aName eq "dummy"){
    if ($cmd eq "set" && $aVal != 0){
      RemoveInternalTimer( "keepAliveCk:".$name);
      RemoveInternalTimer( "keepAlive:".$name);
      DevIo_CloseDev($defs{$name});
      HMLAN_condUpdate($defs{$name},251);#state: dummy
    }
    else{
      if ($cmd eq "set"){
        $attr{$name}{$aName} = $aVal;
      }
      else{
        delete $attr{$name}{$aName};
      }
      DevIo_OpenDev($defs{$name}, 1, "HMLAN_DoInit");
    }
  }
  return;
}

sub HMLAN_UpdtLogId() {####################################################
  $modules{HMLAN}{AttrList} =~ s/logIDs:.*? //;
  $modules{HMLAN}{AttrList} =~ s/logIDs:.*?$//;
  $modules{HMLAN}{AttrList} .= " logIDs:multiple,sys,all,broadcast,"
                               .join(",",(devspec2array("TYPE=CUL_HM:FILTER=DEF=......:FILTER=model!=ActionDetector")));
  return;
}


sub HMLAN_UpdtMsgLoad($$) {####################################################
  my($name,$val) = @_;
  my $hash = $defs{$name};
  my $hashQ = $defs{$name}{helper}{q};

  $hash->{msgLoadCurrent} = $val;
  my ($r) = grep { $_ <= $val } @{$hash->{helper}{loadLvl}{a}};
  readingsSingleUpdate($hash,"loadLvl",$hash->{helper}{loadLvl}{h}{$r},1);
  
  $hashQ->{loadLastMax} = $val if ($hashQ->{loadLastMax} < $val);
  my $t = int(gettimeofday()/(3600/$HMmlSlice))%$HMmlSlice;
  if ($hashQ->{loadNo} != $t){
    $hashQ->{loadNo} = $t;    

    unshift @{$hashQ->{ald}},$hashQ->{loadLastMax};
    #relative history my @a = map{$hashQ->{ald}[$_] - 
    #relative history             $hashQ->{ald}[$_ + 1]} (0..($HMmlSlice-1));
    #relative history $hash->{msgLoadHistory}    = (60/$HMmlSlice)."min steps: ".join("/",@a);
    pop @{$hashQ->{ald}};
    
    $hash->{msgLoadHistoryAbs} = (60/$HMmlSlice)."min steps: ".join("/",@{$hashQ->{ald}});
       # try to release high-load condition with a dummy message
       # one a while
    if (ReadingsVal($name,"cond","") =~ m /(Warning-HighLoad|ERROR-Overload)/){
      $hash->{helper}{recoverTest} = 1;
      HMLAN_Write($hash,"","As09998112"
                         .AttrVal($name,"hmId","999999")
                         ."000000");
    }
    $hashQ->{loadLastMax} = 0;
  }  
  return;
}

sub HMLAN_Get($@) {############################################################
  my ($hash, @a) = @_;
  my $ret = "";
  return "\"get $hash->{NAME}\" no command given" if(@a < 2);
  return "Unknown argument $a[1], choose one of " . join(" ", sort keys %gets)
      if(!defined($gets{$a[1]}));

  my $name = shift @a;
  my $cmd = shift @a;
  my $arg = join("", @a);
  if($cmd eq "assignIDs") { #--------------------------------------
    return "set $name $cmd doesn't support parameter" if(scalar(@a));
    my @aIds = map{CUL_HM_id2Name($_)}  keys %{$hash->{helper}{ids}};
    @aIds = map{CUL_HM_name2Id($_)." : $_"} sort @aIds;
   $ret = "assignedIDs: ".scalar(@aIds)."\n".join("\n", @aIds);
  }
  return ($ret);# no not generate trigger outof command
}
sub HMLAN_Set($@) {############################################################
  my ($hash, @a) = @_;

  return "\"set $hash->{NAME}\" no command given" if(@a < 2);
  return "Unknown argument $a[1], choose one of " . join(" ", sort keys %sets)
      if(!defined($sets{$a[1]}));

  my $name = shift @a;
  my $cmd = shift @a;
  my $arg = join("", @a);
  if   ($cmd eq "hmPairForSec") { #################################
    $arg = 60    if(!$arg || $arg !~ m/^\d+$/);
    HMLAN_RemoveHMPair("hmPairForSec:$name");
    $hash->{hmPair} = 1;
    InternalTimer(gettimeofday()+$arg, "HMLAN_RemoveHMPair", "hmPairForSec:$name", 1);
  }
  elsif($cmd eq "hmPairSerial") { #################################
    return "Usage: set $name hmPairSerial <10-character-serialnumber>"
        if(!$arg || $arg !~ m/^.{10}$/);

    my $id = InternalVal($hash->{NAME}, "owner", "123456");
    $hash->{HM_CMDNR} = $hash->{HM_CMDNR} ? ($hash->{HM_CMDNR}+1)%256 : 1;

    HMLAN_Write($hash, undef, sprintf("As15%02XC401%s000000010A%s",
                    $hash->{HM_CMDNR}, $id, uc unpack('H*', $arg)));
    HMLAN_RemoveHMPair("hmPairForSec:$name");
    $hash->{hmPair} = 1;
    $hash->{hmPairSerial} = $arg;
    InternalTimer(gettimeofday()+20, "HMLAN_RemoveHMPair", "hmPairForSec:".$name, 1);
  }
  elsif($cmd eq "reassignIDs")  { #################################
    return "set $name $cmd doesn't support parameter" if(scalar(@a));
    HMLAN_assignIDs($hash);
  }
  elsif($cmd eq "reopen")       { #################################
    DevIo_CloseDev($hash);
    HMLAN_condUpdate($hash,253);#set disconnected
    DevIo_OpenDev($hash, 0, "HMLAN_DoInit");
  }
  elsif($cmd eq "restart")      { #################################
    HMLAN_SimpleWrite($hash, "Y05,");
    HMLAN_condUpdate($hash,253);#set disconnected
  }
  elsif($cmd eq "close")        { #################################
    DevIo_CloseDev($hash);
    HMLAN_condUpdate($hash,253);#set disconnected
  }
  elsif($cmd eq "open")         { #################################
    DevIo_OpenDev($hash, 0, "HMLAN_DoInit");
  }

  return ("",1);# no not generate trigger outof command
}

sub HMLAN_ReadAnswer($$$) {# This is a direct read for commands like get
  my ($hash, $arg, $regexp) = @_;
  my $type = $hash->{TYPE};

  return ("No FD", undef)
        if(!$hash && !defined($hash->{FD}));

  my ($mdata, $rin) = ("", '');
  my $buf;
  my $to = 3;                                         # 3 seconds timeout
  $to = $hash->{RA_Timeout} if($hash->{RA_Timeout});  # ...or less
  for(;;) {

    return ("Device lost when reading answer for get $arg", undef)
      if(!$hash->{FD});
    vec($rin, $hash->{FD}, 1) = 1;
    my $nfound = select($rin, undef, undef, $to);
    if($nfound < 0) {
      next if ($! == EAGAIN() || $! == EINTR() || $! == 0);
      my $err = $!;
      DevIo_Disconnected($hash);
      HMLAN_condUpdate($hash,253);
      return("HMLAN_ReadAnswer $arg: $err", undef);
    }
    return ("Timeout reading answer for get $arg", undef) if($nfound == 0);
    $buf = DevIo_SimpleRead($hash);# and now read
    return ("No data", undef) if(!defined($buf));

    if($buf) {
      Log3 $hash, 5, "HMLAN/RAW (ReadAnswer): $buf";
      $mdata .= $buf;
    }
    if($mdata =~ m/\r\n/) {
      if($regexp && $mdata !~ m/$regexp/) {
        HMLAN_Parse($hash, $mdata);
      }
      else {
        return (undef, $mdata);
      }
    }
  }
}

sub HMLAN_Write($$$) {#########################################################
  my ($hash,$fn,$msg) = @_;
  return if(!defined $msg);
  if (defined($fn) && $fn eq "cmd"){
    HMLAN_SimpleWrite($hash,$msg);
    return;
  }
  if (length($msg)>21){
    my ($mtype,$src,$dst) = (substr($msg, 8, 2),
                             substr($msg, 10, 6),
                             substr($msg, 16, 6));

    if (   $mtype eq "02" && $src eq $hash->{owner} && length($msg) == 24
        && defined $hash->{helper}{ids}{$dst}){
      # Acks are generally send by HMLAN autonomously
      # Special
      Log3 $hash, 5, "HMLAN: Skip ACK";
      return;
    }
#   my $IDHM  = '+'.$dst.',01,00,F1EF'; # used by HMconfig - meaning??
#   my $IDadd = '+'.$dst;               # guess: add ID?
#   my $IDack = '+'.$dst.',02,00,';     # guess: ID acknowledge
#   my $IDack = '+'.$dst.',FF,00,';     # guess: ID acknowledge
#   my $IDsub = '-'.$dst;               # guess: ID remove?
#   my $IDnew = '+'.$dst.',00,01,';     # newChannel- trailing 01 to be sent if talk to neu channel
    my $IDadd = '+'.$dst.',00,00,';     # guess: add ID?

    if (!$hash->{helper}{ids}{$dst} && $dst ne "000000"){
      HMLAN_SimpleWrite($hash, $IDadd);
      $hash->{helper}{ids}{$dst}{name} = CUL_HM_id2Name($dst);
      $hash->{helper}{assIdCnt} = scalar(keys %{$hash->{helper}{ids}});
      $hash->{assignedIDsCnt} = $hash->{helper}{assIdCnt}
              .(($hash->{helper}{assIdCnt} eq $hash->{helper}{assIdRep})
                  ?""
                  :" report:$hash->{helper}{assIdRep}")
              ;
    }
  }
  elsif(length($msg)<5){
    Log3 $hash, 2, "HMLAN_Send:  cmd too short:".($fn?$fn:"noFn").":".($msg?$msg:"no_msg");
  }
  elsif($msg =~ m /init:(......)/){
    my $dst = $1;
    if ($modules{CUL_HM}{defptr}{$dst} &&
        $modules{CUL_HM}{defptr}{$dst}{helper}{io}{newChn} ){
      HMLAN_SimpleWrite($hash,$modules{CUL_HM}{defptr}{$dst}{helper}{io}{newChn});
      $hash->{helper}{ids}{$dst}{cfg}  = $modules{CUL_HM}{defptr}{$dst}{helper}{io}{newChn};
      $hash->{helper}{ids}{$dst}{name} = CUL_HM_id2Name($dst);
      $hash->{helper}{assIdCnt} = scalar(keys %{$hash->{helper}{ids}});
      $hash->{assignedIDsCnt} = $hash->{helper}{assIdCnt}
              .(($hash->{helper}{assIdCnt} eq $hash->{helper}{assIdRep})
                  ?""
                  :" report:$hash->{helper}{assIdRep}")
              ;
    }
    return;
  }
  elsif($msg =~ m /remove:(......)/){
    my $dst = $1;
    if ($modules{CUL_HM}{defptr}{$dst} &&
        $modules{CUL_HM}{defptr}{$dst}{helper}{io}{newChn} ){
      HMLAN_SimpleWrite($hash,"-$dst");
      delete $hash->{helper}{ids}{$dst};
      $hash->{helper}{assIdCnt} = scalar(keys %{$hash->{helper}{ids}});
      $hash->{assignedIDsCnt} = $hash->{helper}{assIdCnt}
              .(($hash->{helper}{assIdCnt} eq $hash->{helper}{assIdRep})
                  ?""
                  :" report:$hash->{helper}{assIdRep}")
              ;
    }
    return;
  }
  my $tm = int(gettimeofday()*1000) % 0xffffffff;
  $msg = sprintf("S%08X,00,00000000,01,%08X,%s",$tm, $tm, substr($msg, 4));
  HMLAN_SimpleWrite($hash, $msg);
}
sub HMLAN_Read($) {############################################################
# called from the global loop, when the select for hash->{FD} reports data
  my ($hash) = @_;
  my $buf = DevIo_SimpleRead($hash);
  return "" if(!defined($buf));
  my $name = $hash->{NAME};

  my $hmdata = $hash->{PARTIAL};
  Log3 $hash, 5, "HMLAN/RAW: $hmdata/$buf";
  $hmdata .= $buf;

  while($hmdata =~ m/\n/) {
    my $rmsg;
    ($rmsg,$hmdata) = split("\n", $hmdata, 2);
    $rmsg =~ s/\r//;
    HMLAN_Parse($hash, $rmsg) if($rmsg);
  }
  $hash->{PARTIAL} = $hmdata;
}
sub HMLAN_uptime($@) {#########################################################
  my ($hmtC,$hash) = @_;  # hmTime Current

  $hmtC = hex($hmtC);

  if ($hash && $hash->{helper}{ref}){ #will calculate new ref-time
    my $ref = $hash->{helper}{ref};#shortcut
    my $sysC = int(time()*1000);   #current systime in ms
    my $offC = $sysC - $hmtC;      #offset calc between time and HM-stamp
    if ($ref->{hmtL} && ($hmtC > $ref->{hmtL})){
      if (($sysC - $ref->{kTs})<20){ #if delay is more then 20ms, we dont trust
        if ($ref->{sysL}){
          $ref->{drft} = ($offC - $ref->{offL})/($sysC - $ref->{sysL});
        }
        $ref->{sysL} = $sysC;
        $ref->{offL} = $offC;
      }
    }
    else{# hm had a skip in time, start over calculation
      delete $hash->{helper}{ref};
    }
    $hash->{helper}{ref}{hmtL} = $hmtC;
    $hash->{helper}{ref}{kTs} = 0;
  }

  my $sec = int($hmtC/1000);
  return sprintf("%03d %02d:%02d:%02d.%03d",
                  int($hmtC/86400000), int($sec/3600),
                  int(($sec%3600)/60), $sec%60, $hmtC % 1000);
}
sub HMLAN_Parse($$) {##########################################################
  my ($hash, $rmsg) = @_;
  my $name = $hash->{NAME};
  my @mFld = split(',', $rmsg);
  my $letter = substr($mFld[0],0,1); # get leading char

  if ($letter =~ m/^[ER]/){#@mFld=($src, $status, $msec, $d2, $rssi, $msg)
    # max speed for devices is 100ms after receive - example:TC
    my ($mNo,$flg,$type,$src,$dst,$p) = unpack('A2A2A2A6A6A*',$mFld[5]);
    my $mLen = length($mFld[5])/2;
    my $CULinfo = "";

    Log3 $hash,  HMLAN_getVerbLvl ($hash,$src,$dst,"5")
                    , "HMLAN_Parse: $name R:".$mFld[0]
                                   .(($mFld[0] =~ m/^E/)?'  ':'')
                                   .' stat:' .$mFld[1]
                                   .' t:'    .$mFld[2]
                                   .' d:'    .$mFld[3]
                                   .' r:'    .$mFld[4]
                                   .'     m:'.$mNo
                                   .' '.$flg.$type
                                   .' '.$src
                                   .' '.$dst
                                   .' '.$p;

    # handle status.
    #HMcnd stat
    #    00 00= msg without relation
    #    00 01= ack that HMLAN waited for
    #    00 02= msg send, no ack requested
    #    00 08= nack - ack was requested, msg repeated 3 times, still no ack
    #    00 21= ??(seen with 'R') - see below
    #    00 2x= should: AES was accepted, here is the response
    #    00 30= should: AES response failed
    #    00 4x= AES response accepted
    #    00 50= ??(seen with 'R')
    #    00 8x= response to a message send autonomous by HMLAN (e.g. A112 -> wakeup)
    #    01 xx= ?? 0100 AES response send (gen autoMsgSent)
    #    02 xx= prestate to 04xx. Message is still sent. This is a warning
    #    04 xx= nothing sent anymore. Any restart unsuccessful except power
    #
    #  parameter 'cond'- condition of the IO device
    #  Cond text
    #     0 ok
    #     1 AES request by HMLAN pending
    #     2 Warning-HighLoad
    #     4 Overload condition - no send anymore
    #
    my ($HMcnd,$stat) = map{hex($_)} unpack('A2A2',($mFld[1]));

    if ($HMcnd == 0x01){#HMLAN responded to AES request
      $CULinfo = ($mFld[3] eq "FF")?"AESpending"
                                   :"AESKey-".$mFld[3];
    }
    
    # config message: reset timer handling
    $hash->{helper}{ids}{$src}{flg} = 0 if ($type eq "00");

    if ($stat){# message with status information
      HMLAN_condUpdate($hash,$HMcnd) if ($hash->{helper}{q}{HMcndN} != $HMcnd);
      my $myId = $attr{$name}{hmId};
      if    ($stat & 0x03 && $dst eq $myId){HMLAN_qResp($hash,$src,0);}
      elsif ($stat & 0x08 && $src eq $myId){HMLAN_qResp($hash,$dst,0);}

      $hash->{helper}{ids}{$dst}{flg} = 0 if(defined $hash->{helper}{ids}{$dst});
                                           #got response => unblock sending
      if     ($stat & 0x0A){#08 and 02 dont need to go to CUL, internal ack only
        Log3 $hash, HMLAN_getVerbLvl ($hash,$src,$dst,"5")
                  , "HMLAN_Parse: $name no ACK from $dst"   if($stat & 0x08);
        return;
      }
      elsif (($stat & 0x70) == 0x30){Log3 $hash, HMLAN_getVerbLvl ($hash,$src,$dst,"5") 
                                                , "HMLAN_Parse: $name AES code rejected for $dst $stat";
                                      $CULinfo = "AESerrReject";
                                      HMLAN_qResp($hash,$src,0);
      }
      elsif (($stat & 0x70) == 0x20){$CULinfo = "AESCom-ok";                         }
      elsif ( $stat & 0x40)         {$CULinfo = "AESCom-".($stat & 0x10?"fail":"ok");}
    }

    my $rssi = hex($mFld[4])-65536;
     #update some User information ------
    $hash->{uptime} = HMLAN_uptime($mFld[2]);
    $hash->{RSSI}   = $rssi;
    $hash->{RAWMSG} = $rmsg;
    $hash->{"${name}_MSGCNT"}++;
    $hash->{"${name}_TIME"} = TimeNow();

    my $dly = 0; #--------- calc messageDelay ----------
    if ($hash->{helper}{ref} && $hash->{helper}{ref}{drft}){
      my $ref = $hash->{helper}{ref};#shortcut
      my $sysC = int(time()*1000);   #current systime in ms
      $dly = int($sysC - (hex($mFld[2]) + $ref->{offL} + $ref->{drft}*($sysC - $ref->{sysL})));

      $hash->{helper}{dly}{lst} = $dly;
      my $dlyP = $hash->{helper}{dly};
      $dlyP->{min} = $dly if (!$dlyP->{min} || $dlyP->{min}>$dly);
      $dlyP->{max} = $dly if (!$dlyP->{max} || $dlyP->{max}<$dly);
      if ($dlyP->{cnt}) {$dlyP->{cnt}++} else {$dlyP->{cnt} = 1} ;

      $hash->{msgParseDly} =   "min:" .$dlyP->{min}
                             ." max:" .$dlyP->{max}
                             ." last:".$dlyP->{lst}
                             ." cnt:" .$dlyP->{cnt};
      ################# debugind help
      #my $st = $sysC - $dly;#time send
      #my $stms = sprintf("%03d",$st%1000);
      #my @slt = localtime(int($st/1000));
      #Log 1,"HMLAN dlyTime      st:$slt[2]:$slt[1]:$slt[0].".$stms."  dly:$dly";
      #################
      $dly = 0 if ($dly<0);
    }

    # HMLAN sends ACK for flag 'A0' but not for 'A4'(config mode)-
    # we ack ourself an long as logic is uncertain - also possible is 'A6' for RHS

    my $wait = 0.100 - $dly/1000;
    $modules{CUL_HM}{defptr}{$src}{helper}{io}{nextSend} = gettimeofday()+$wait
              if ($modules{CUL_HM}{defptr}{$src} && $wait > 0);

    if (hex($flg)&0xA4 == 0xA4 && $hash->{owner} eq $dst){
      Log3 $hash, HMLAN_getVerbLvl ($hash,$src,$dst,"5")
                , "HMLAN_Parse: $name ACK config";
      HMLAN_Write($hash,undef, "As15".$mNo."8002".$dst.$src."00");
    }

    if ($letter eq 'R' && $hash->{helper}{ids}{$src}{flg}){
      $hash->{helper}{ids}{$src}{flg} = 0 if($dst ne "000000"); #release send-holdoff
      if ($hash->{helper}{ids}{$src}{msg}){                #send delayed msg if any
        Log3 $hash, HMLAN_getVerbLvl ($hash,$src,$dst,"5")
                  ,"HMLAN_SdDly: $name $src";
        HMLAN_SimpleWrite($hash, $hash->{helper}{ids}{$src}{msg});
      }
      $hash->{helper}{ids}{$src}{msg} = "";                #clear message
    }
    # prepare dispatch-----------
    # HM format A<len><msg>:<info>:<RSSI>:<IOname>  Info is not used anymore
    my $dmsg = sprintf("A%02X%s:$CULinfo:$rssi:$name",
                         $mLen, uc($mFld[5]));
    my %addvals = (RAWMSG => $rmsg, RSSI => hex($mFld[4])-65536);

    Dispatch($hash, $dmsg, \%addvals) if($mFld[5] !~ m/99.112999999000000/);#ignore overload test
  }
  elsif($mFld[0] =~ m /HHM-(LAN|USB)-IF/){#HMLAN version info
    $hash->{IFmodel} = $1;
    $hash->{uptime} = HMLAN_uptime($mFld[5],$hash);
    
    $hash->{helper}{assIdRep} = hex($mFld[6]);
    $hash->{assignedIDsCnt} = $hash->{helper}{assIdCnt}
              .(($hash->{helper}{assIdCnt} eq $hash->{helper}{assIdRep})
                  ?""
                  :" report:$hash->{helper}{assIdRep}")
              ;

    $hash->{helper}{q}{keepAliveRec} = 1;
    $hash->{helper}{q}{keepAliveRpt} = 0;
    my $load = defined $mFld[7] ? hex($mFld[7]):0;
    Log3 $hash, ($hash->{helper}{log}{sys}?0:5)
              , 'HMLAN_Parse: '.$name.                 " V:$mFld[1]"
                                   ." sNo:$mFld[2] d:$mFld[3]"
                                   ." O:$mFld[4] t:$mFld[5] IDcnt:$mFld[6] L:$load %";
    HMLAN_UpdtMsgLoad($name,$load);
    my $myId = AttrVal($name, "hmId", "");
    $myId = $attr{$name}{hmId} = $mFld[4] if (!$myId);
    
    my (undef,$info) = unpack('A11A29',$rmsg);
    if (!$hash->{helper}{info} || $hash->{helper}{info} ne $info){
      my $fwVer = hex($mFld[1]);
      $fwVer = sprintf("%d.%d", ($fwVer >> 12) & 0xf, $fwVer & 0xffff);
      $hash->{owner} = $mFld[4];
      readingsBeginUpdate($hash);
      readingsBulkUpdate($hash,"D-firmware"    ,$fwVer);
      readingsBulkUpdate($hash,"D-serialNr"    ,$mFld[2]);
      readingsBulkUpdate($hash,"D-HMIdOriginal",$mFld[3]);
      readingsBulkUpdate($hash,"D-HMIdAssigned",$mFld[4]);
      readingsEndUpdate($hash,1);
      $hash->{helper}{info} = $info;
    }

    if($mFld[4] ne $myId && !AttrVal($name, "dummy", 0)) {
      Log3 $hash, 1, 'HMLAN setting owner to '.$myId.' from '.$mFld[4];
      HMLAN_SimpleWrite($hash, "A$myId");
    }
  }
  elsif($rmsg =~ m/^I00.*/) {;
    # Ack from the HMLAN
  }
  else {
    Log3 $hash, 5, "$name Unknown msg >$rmsg<";
  }
}
sub HMLAN_Ready($) {###########################################################
  my ($hash) = @_;
  return DevIo_OpenDev($hash, 1, "HMLAN_DoInit");
}
sub HMLAN_SimpleWrite(@) {#####################################################
  my ($hash, $msg, $nonl) = @_;
  return if(!$hash || AttrVal($hash->{NAME}, "dummy", 0) != 0);

  my $name = $hash->{NAME};
  my $len = length($msg);

  # It is not possible to answer befor 100ms
  if ($len>51){
    if($hash->{helper}{q}{HMcndN}){
      my $HMcnd = $hash->{helper}{q}{HMcndN};
      return if (  ($HMcnd == 4 || $HMcnd == 253)
                  && !$hash->{helper}{recoverTest});# no send if overload or disconnect
      delete $hash->{helper}{recoverTest}; # test done
    }
    my ($s,undef,$stat,undef,$t,undef,$d,undef,$r,undef,$no,$flg,$typ,$src,$dst,$p) =
       unpack('A9A1A2A1A8A1A2A1A8A1A2A2A2A6A6A*',$msg);

    my $hmId = AttrVal($name,"hmId","");
    my $hDst = $hash->{helper}{ids}{$dst};# shortcut
    my $tn = gettimeofday();
    
    if($modules{CUL_HM}{defptr}{$dst} && 
       $modules{CUL_HM}{defptr}{$dst}{helper}{io}
       ){
      if ($modules{CUL_HM}{defptr}{$dst}{helper}{io}{nextSend}){
        my $dDly = $modules{CUL_HM}{defptr}{$dst}{helper}{io}{nextSend} - $tn;
        #$dDly -= 0.05 if ($typ eq "02");# delay at least 50ms for ACK, but not 100
        select(undef, undef, undef, (($dDly > 0.1)?0.1:$dDly))
              if ($dDly > 0.01);
      }
    }
    if ($dst ne $hmId){  #delay send if answer is pending
      if ( $hDst->{flg} &&                #HMLAN's ack pending
          ($hDst->{to} > $tn)){#won't wait forever! check timeout
        $hDst->{msg} = $msg;              #postpone  message
        Log3 $hash, HMLAN_getVerbLvl($hash,$src,$dst,"5"),"HMLAN_Delay: $name $dst";
        return;
      }
      if ($src eq $hmId){
        $hDst->{flg} = (hex($flg)&0x20)?1:0;# answer expected?
        $hDst->{to} = $tn + 2;# flag timeout after 2 sec
        $hDst->{msg} = "";
        HMLAN_qResp($hash,$dst,1) if ($hDst->{flg} == 1);
      }
    }

    if ($len > 52){#channel information included, send sone kind of clearance
      my $chn = substr($msg,52,2);
      if (!$hDst->{chn} || $hDst->{chn} ne $chn){
        my $updt = $modules{CUL_HM}{defptr}{$dst}{helper}{io}{newChn};
        if ($updt && (!$hDst->{cfg} || $updt ne $hDst->{cfg})){
          Log3 $hash,  HMLAN_getVerbLvl($hash,$src,$dst,"5")
                  , 'HMLAN_Send:  '.$name.' S:'.$updt;
          syswrite($hash->{TCPDev}, $updt."\r\n")     if($hash->{TCPDev});
          $hDst->{cfg} = $updt;
        }
      }
      $hDst->{chn} = $chn;
    }
    Log3 $hash,  HMLAN_getVerbLvl($hash,$src,$dst,"5")
            , 'HMLAN_Send:  '.$name.' S:'.$s
                             .' stat:  ' .$stat
                             .' t:'      .$t
                             .' d:'      .$d
                             .' r:'      .$r
                             .' m:'      .$no
                             .' '        .$flg.$typ
                             .' '        .$src
                             .' '        .$dst
                             .' '        .$p;

    $hash->{helper}{q}{scnt}++;  
  }
  else{
    Log3 $hash, ($hash->{helper}{log}{sys}?0:5), 'HMLAN_Send:  '.$name.' I:'.$msg;
  }

  $msg .= "\r\n" unless($nonl);
  syswrite($hash->{TCPDev}, $msg)     if($hash->{TCPDev});
  if ($hash->{helper}{q}{scnt} == 10){
    $hash->{helper}{q}{scnt} = 0;
    HMLAN_KeepAlive("x:$name") ;
  }
}

sub HMLAN_DoInit($) {##########################################################
  my ($hash) = @_;
  my $name = $hash->{NAME};

  my $id  = AttrVal($name, "hmId", "999999");
#  readingsSingleUpdate($hash,"state","init",1);

  HMLAN_SimpleWrite($hash, "A$id") if($id ne "999999");
  HMLAN_assignIDs($hash);
  HMLAN_writeAesKey($name);
  my $s2000 = sprintf("%02X", HMLAN_secSince2000());
  HMLAN_SimpleWrite($hash, "T$s2000,02,00,00000000");
  $hash->{helper}{setTime} = int(gettimeofday())>>15;

  delete $hash->{helper}{ref};

  HMLAN_condUpdate($hash,255);

  $hash->{helper}{q}{keepAliveRec} = 1; # ok for first time
  $hash->{helper}{q}{keepAliveRpt} = 0; # ok for first time

  my $tn = gettimeofday();
  my $wdTimer = AttrVal($name,"wdTimer",25);
  $hash->{helper}{k}{Start} = $tn;
  $hash->{helper}{k}{Next} = $tn + $wdTimer;

  RemoveInternalTimer( "keepAliveCk:".$name);# avoid duplicate timer
  RemoveInternalTimer( "keepAlive:".$name);# avoid duplicate timer
  InternalTimer($tn+$wdTimer, "HMLAN_KeepAlive", "keepAlive:".$name, 0);
  # send first message to retrieve HMLAN condition
  HMLAN_Write($hash,"","As09998112".$id."000000");

  return undef;
}
sub HMLAN_assignIDs($){
  # remove all assigned IDs and assign the ones from list
  my ($hash) = @_;
  HMLAN_SimpleWrite($hash, "C"); #clear all assigned IDs

  HMLAN_Write($hash,"","init:$_") foreach(keys %{$hash->{helper}{ids}});
}

sub HMLAN_writeAesKey($) {#####################################################
  my ($name) = @_;
  return if (!$name || !$defs{$name} || $defs{$name}{TYPE} ne "HMLAN");
  my %keys = ();
  my $vccu = InternalVal($name,"owner_CCU",$name);
  $vccu = $name if(!AttrVal($vccu,"hmKey",""));
  foreach my $i (1..3){
     my ($kNo,$k) = split(":",AttrVal($vccu,"hmKey".($i== 1?"":$i),""));
     if (defined($kNo) && defined($k)) {
       $keys{$kNo} = $k;
     }
  }
  my  @kNos = reverse(sort(keys(%keys)));
  foreach my $i (1..3){
    my $k;
    my $kNo;
    if (defined($kNos[$i-1])) {
      $kNo = $kNos[$i-1];
      $k = $keys{$kNo};
    }
    HMLAN_SimpleWrite($defs{$name}, "Y0$i,".($k?"$kNo,$k":"00,"));
  }
}

sub HMLAN_KeepAlive($) {#######################################################
  my($in ) = shift;
  my(undef,$name) = split(':',$in);
  my $hash = $defs{$name};
  $hash->{helper}{q}{keepAliveRec} = 0; # reset indicator

  return if(!$hash->{FD});
  
  my $tn = gettimeofday();
  my $wdTimer = AttrVal($name,"wdTimer",25);
  my $rht = int($tn)>>15 ;
  if( $rht != $hash->{helper}{setTime}){# reset HMLAN watch about each 10h
    $hash->{helper}{setTime} =  $rht;
    my $s2000 = sprintf("%02X", HMLAN_secSince2000());
    HMLAN_SimpleWrite($hash, "T$s2000,02,00,00000000");
  }
  HMLAN_SimpleWrite($hash, "K");

  my $kDly =  int(($tn - $hash->{helper}{k}{Next})*1000)/1000;
  $hash->{helper}{k}{DlyMax} =  $kDly if($hash->{helper}{k}{DlyMax} < $kDly);

  if ($hash->{helper}{k}{Start}){
    my $kBuf =  int($hash->{helper}{k}{Start} + 30 - $tn);
    $hash->{helper}{k}{BufMin} =  $kBuf if($hash->{helper}{k}{BufMin} > $kBuf);
  }
  else{
    $hash->{helper}{k}{BufMin} =  30;
  }

  $hash->{msgKeepAlive} = "dlyMax:".$hash->{helper}{k}{DlyMax}
                         ." bufferMin:". $hash->{helper}{k}{BufMin};
  $hash->{helper}{k}{Start} = $tn;
  $hash->{helper}{k}{Next} = $tn + $wdTimer;
  $hash->{helper}{ref}{kTs} = int($tn*1000);

  my $rt = AttrVal($name,"respTime",1);
  InternalTimer($tn+$rt,"HMLAN_KeepAliveCheck","keepAliveCk:".$name,1);
  RemoveInternalTimer( "keepAlive:".$name);# avoid duplicate timer
  InternalTimer($tn+$wdTimer,"HMLAN_KeepAlive", "keepAlive:".$name, 1);
}
sub HMLAN_KeepAliveCheck($) {##################################################
  my($in ) = shift;
  my(undef,$name) = split(':',$in);
  my $hash = $defs{$name};
  if ($hash->{helper}{q}{keepAliveRec} != 1){# no answer
    if ($hash->{helper}{q}{keepAliveRpt} >2){# give up here
      HMLAN_condUpdate($hash,253);# trigger timeout event
      DevIo_Disconnected($hash);
    }
    else{
      $hash->{helper}{q}{keepAliveRpt}++;
      HMLAN_KeepAlive("keepAlive:".$name);#repeat
    }
  }
  else{
    $hash->{helper}{q}{keepAliveRpt} = 0;
    HMLAN_condUpdate($hash,0) if ($hash->{helper}{q}{HMcndN} == 255);
  }
}
sub HMLAN_secSince2000() {#####################################################
  # Calculate the local time in seconds from 2000.
  my $t = time();
  my @l = localtime($t);
  my @g = gmtime($t);
  $t += 60*(($l[2]-$g[2] + ((($l[5]<<9)|$l[7]) <=> (($g[5]<<9)|$g[7])) * 24) * 60 + $l[1]-$g[1])
                           # timezone and daylight saving...
        - 946684800        # seconds between 01.01.2000, 00:00 and THE EPOCH (1970)
        - 3600;            # time zone
  return $t;
}
sub HMLAN_qResp($$$) {#response-waiting queue##################################
  my($hash,$id,$cmd) = @_;
  my $hashQ = $hash->{helper}{q};
  if ($cmd){
    $hashQ->{answerPend} ++;
    push @{$hashQ->{apIDs}},$id;
    if ($hashQ->{answerPend} >= $hashQ->{hmLanQlen}){
      $hash->{XmitOpen} = 2;#delay further sending
      RemoveInternalTimer("hmClearQ:$hash->{NAME}");
      InternalTimer(gettimeofday()+10, "HMLAN_clearQ", "hmClearQ:$hash->{NAME}", 0);
    }
  }
  else{
    $hashQ->{answerPend}-- if ($hashQ->{answerPend}>0);
    @{$hashQ->{apIDs}}=grep !/$id/,@{$hashQ->{apIDs}};
    RemoveInternalTimer("hmClearQ:$hash->{NAME}")if ($hash->{XmitOpen} == 0);

    if ($hashQ->{HMcndN} == 4 ||
        $hashQ->{HMcndN} == 253){                      $hash->{XmitOpen} = 0;}
    elsif($hashQ->{answerPend} >= $hashQ->{hmLanQlen}){$hash->{XmitOpen} = 2;}
    else{                                              $hash->{XmitOpen} = 1;}
  }
}
sub HMLAN_clearQ($) {#clear pending acks due to timeout########################
  my($in ) = shift;
  my(undef,$name) = split(':',$in);
  my $hash = $defs{$name};
  @{$hash->{helper}{q}{apIDs}} = (); #clear Q-status
  $hash->{helper}{q}{answerPend} = 0;
  Log3 $hash, 4, "HMLAN_ack: timeout - clear queue";
  my $HMcnd = $hash->{helper}{q}{HMcndN};
  if ($HMcnd == 4 || $HMcnd == 253) {$hash->{XmitOpen} = 0;
  }else{                             $hash->{XmitOpen} = 1;}
}

sub HMLAN_condUpdate($$) {#####################################################
  my($hash,$HMcnd) = @_;
  my $name = $hash->{NAME};
  if (AttrVal($name,"dummy",undef)){
    readingsSingleUpdate($hash,"state","disconnected",1);
    $hash->{XmitOpen} = 0;
    return;
  }
  my $hashCnd = $hash->{helper}{cnd};#short to helper
  my $hashQ   = $hash->{helper}{q};#short to helper
  $hash->{helper}{cnd}{$HMcnd} = 0 if (!$hash->{helper}{cnd} || 
                                       !$hash->{helper}{cnd}{$HMcnd});
  $hash->{helper}{cnd}{$HMcnd}++;
  readingsBeginUpdate($hash);
  if ($HMcnd == 4){#HMLAN needs a rest. Supress all sends exept keep alive
    readingsBulkUpdate($hash,"state","overload");
  }
  elsif ($HMcnd == 251 || $HMcnd == 253){#HMLAN dummy/disconnected
    readingsBulkUpdate($hash,"state","disconnected");
  }
  else{# revert from overload
    readingsBulkUpdate($hash,"state","opened")
          if (InternalVal($name,"STATE","") eq "overload");
  }

  my $HMcndTxt = $HMcond{$HMcnd} ? $HMcond{$HMcnd} : "Unknown:$HMcnd";
  Log3 $hash, 1, "HMLAN_Parse: $name new condition $HMcndTxt";
  my $txt;
  $txt .= $HMcond{$_}.":".$hash->{helper}{cnd}{$_}." "
                            foreach (keys%{$hash->{helper}{cnd}});

  readingsBulkUpdate($hash,"cond",$HMcndTxt);
  readingsBulkUpdate($hash,"Xmit-Events",$txt);
  readingsBulkUpdate($hash,"prot_".$HMcndTxt,"last");

  $hashQ->{HMcndN} = $HMcnd;

  if ($HMcnd == 4 || $HMcnd == 251|| $HMcnd == 253 || $HMcnd == 255) {#transmission down
    $hashQ->{answerPend} = 0;
    @{$hashQ->{apIDs}} = ();       #clear Q-status
    $hash->{XmitOpen} = 0;         #deny transmit
    readingsBulkUpdate($hash,"prot_keepAlive","last")
        if (   $HMcnd == 253
            && $hash->{helper}{k}{Start}
            &&(gettimeofday() - 29) > $hash->{helper}{k}{Start});
  }
  else{
    $hash->{XmitOpen} = ($hashQ->{answerPend} < $hashQ->{hmLanQlen})?"1":"2";#allow transmit
  }
  readingsEndUpdate($hash,1);
  my $ccu = InternalVal($name,"owner_CCU","");
  CUL_HM_UpdtCentralState($ccu) if ($ccu);
}

sub HMLAN_noDup(@) {#return list with no duplicates
  my %all;
  return "" if (scalar(@_) == 0);
  $all{$_}=0 foreach (grep !/^$/,@_);
  delete $all{""}; #remove empties if present
  return (sort keys %all);
}
sub HMLAN_getVerbLvl ($$$$){#get verboseLevel for message
  my ($hash,$src,$dst,$def) = @_;
  return ($hash->{helper}{log}{all}||
          (grep /($src|$dst)/,@{$hash->{helper}{log}{ids}}))?0:$def;
}

1;

=pod
=item device
=item summary    IO device for wireless homematic
=item summary_DE IO device für funkgesteuerte Homematic Devices
=begin html

<a name="HMLAN"></a>
<h3>HMLAN</h3>
<ul>
    The HMLAN is the fhem module for the eQ-3 HomeMatic LAN Configurator.<br>
    A description on how to use  <a href="https://git.zerfleddert.de/cgi-bin/gitweb.cgi/hmcfgusb">hmCfgUsb</a> can be found follwing the link.<br/>
    <br/>
    The fhem module will emulate a CUL device, so the <a href="#CUL_HM">CUL_HM</a> module can be used to define HomeMatic devices.<br/>
    <br>
    In order to use it with fhem you <b>must</b> disable the encryption first with the "HomeMatic Lan Interface Configurator"<br>
    (which is part of the supplied Windows software), by selecting the device, "Change IP Settings", and deselect "AES Encrypt Lan Communication".<br/>
    <br/>
    This device can be used in parallel with a CCU and (readonly) with fhem. To do this:
    <ul>
        <li>start the fhem/contrib/tcptee.pl program</li>
        <li>redirect the CCU to the local host</li>
        <li>disable the LAN-Encryption on the CCU for the Lan configurator</li>
        <li>set the dummy attribute for the HMLAN device in fhem</li>
    </ul>
    <br/><br/>

    <a name="HMLANdefine"><b>Define</b></a>
    <ul>
        <code>define &lt;name&gt; HMLAN &lt;ip-address&gt;[:port]</code><br>
        <br>
        port is 1000 by default.<br/>
        If the ip-address is called none, then no device will be opened, so you can experiment without hardware attached.
    </ul>
    <br><br>

    <a name="HMLANset"><b>Set</b></a>
    <ul>
        <li><a href="#hmPairForSec">hmPairForSec</a></li>
        <li><a href="#hmPairSerial">hmPairSerial</a></li>
        <li><a href="#hmreopen">reopen</a>
           reconnect the device
           </li>
        <li><a href="#hmrestart">restart</a>
          Restart the device
          </li>
        <li><a href="#HMLANset_reassignIDs">reassignIDs</a>
          Syncs the IDs between HMLAN and the FHEM list. 
          Usually this is done automatically and only is recomended if there is a difference in counts.
          </li>
    <br><br>
    </ul>
    <a name="HMLANget"><b>Get</b></a>
    <ul>
        <li><a href="#HMLANgetassignIDs">assignIDs</a>
          Gibt eine Liste aller diesem IO zugewiesenen IOs aus.
          </li>
    </ul>
    <br><br>

    <a name="HMLANattr"><b>Attributes</b></a>
    <ul>
        <li><a href="#addvaltrigger">addvaltrigger</a></li>
        <li><a href="#do_not_notify">do_not_notify</a></li>
        <li><a href="#attrdummy">dummy</a></li>
        <li><a href="#HMLANlogIDs">logIDs</a><br>
           enables selective logging of HMLAN messages. A list of HMIds or names can be
           entered, comma separated, which shall be logged.<br>
           The attribute only allows device-IDs, not channel IDs.
           Channel-IDs will be modified to device-IDs automatically.
           <b>all</b> will log raw messages for all HMIds<br>
           <b>sys</b> will log system related messages like keep-alive<br>
           in order to enable all messages set "<b>all,sys</b>"<br>
        </li>
        <li><a name="HMLANloadLevel">loadLevel</a><br>
            loadlevel will be mapped to reading vaues. <br>
            0:low,30:mid,40:batchLevel,90:high,99:suspended<br>
            the batchLevel value will be set to 40 if not entered. This is the level at which
            background message generation e.g. for autoReadReg will be stopped<br>
            </li>
        <li><a href="#hmId">hmId</a></li>
        <li><a name="HMLANhmKey">hmKey</a></li>
        <li><a name="HMLANhmKey2">hmKey2</a></li>
        <li><a name="HMLANhmKey3">hmKey3</a></li>
        <li><a name="HMLANhmKey4">hmKey4</a></li>
        <li><a name="HMLANhmKey5">hmKey5</a><br>
            AES keys for the HMLAN adapter. <br>
            The key is converted to a hash. If a hash is given directly it is not converted but taken directly.
            Therefore the original key cannot be converted back<br>
        </li>
        <li><a href="#hmProtocolEvents">hmProtocolEvents</a></li><br>
        <li><a name="HMLANrespTime">respTime</a><br>
            Define max response time of the HMLAN adapter in seconds. Default is 1 sec.<br/>
            Longer times may be used as workaround in slow/instable systems or LAN configurations.</li>
        <li><a name="HMLAN#wdTimer">wdTimer</a><br>
            Time in sec to trigger HMLAN. Values between 5 and 25 are allowed, 25 is default.<br>
            It is <B>not recommended</B> to change this timer. If problems are detected with <br>
            HLMLAN disconnection it is advisable to resolve the root-cause of the problem and not symptoms.</li>
        <li><a name="HMLANhmLanQlen">hmLanQlen</a><br>
            defines queuelength of HMLAN interface. This is therefore the number of
            simultanously send messages. increasing values may cause higher transmission speed.
            It may also cause retransmissions up to data loss.<br>
            Effects can be observed by watching protocol events<br>
            1 - is a conservatibe value, and is default<br>
            5 - is critical length, likely cause message loss</li>
    </ul><br>
    <a name="HMLANparameter"><b>parameter</b></a>
    <ul>
      <li><B>assignedIDsCnt</B><br>
          number of IDs that are assigned to HMLAN by FHEM.
          If the number reported by HMLAN differ it will be reported as 'reported'.<br>
          It is recommended to resync HMLAN using the command 'assignIDs'.
          </li>
      <li><B>msgKeepAlive</B><br>
          performance of keep-alive messages. <br>
          <B>dlyMax</B>: maximum delay of sheduled message-time to actual message send.<br>
          <B>bufferMin</B>: minimal buffer left to before HMLAN would likely disconnect
          due to missing keepAlive message. bufferMin will be reset to 30sec if
          attribut wdTimer is changed.<br>
          if dlyMax is high (several seconds) or bufferMin goes to "0" (normal is 4) the system
          suffers on internal delays. Reasons for the delay might be explored. As a quick solution
          wdTimer could be decreased to trigger HMLAN faster.</li>
      <li><B>msgLoadCurrent</B><br>
          Current transmit load of HMLAN. When capacity reaches 100% HMLAN stops sending and waits for 
          reduction. See also:
          <a href="#HMLANloadLevel">loadLevel</a><br></li>
      <li><B>msgLoadHistoryAbs</B><br>
          Historical transmition load of IO.</li>
      <li><B>msgParseDly</B><br>
          calculates the delay of messages in ms from send in HMLAN until processing in FHEM.
          It therefore gives an indication about FHEM system performance.
          </li>
    </ul><br>
    <a name="HMLANreadings"><b>parameter and readings</b></a>
    <ul>
      <li><B>prot_disconnect</B>       <br>recent HMLAN disconnect</li>
      <li><B>prot_init</B>             <br>recent HMLAN init</li>
      <li><B>prot_keepAlive</B>        <br>HMLAN disconnect likely do to slow keep-alive sending</li>
      <li><B>prot_ok</B>               <br>recent HMLAN ok condition</li>
      <li><B>prot_timeout</B>          <br>recent HMLAN timeout</li>
      <li><B>prot_Warning-HighLoad</B> <br>high load condition entered - HMLAN has about 10% performance left</li>
      <li><B>prot_ERROR-Overload</B>   <br>overload condition - HMLAN will receive bu tno longer transmitt messages</li>
      <li><B>prot_Overload-released</B><br>overload condition released - normal operation possible</li>
    </ul>

</ul>

=end html
=begin html_DE

<a name="HMLAN"></a>
<h3>HMLAN</h3>
<ul>
    Das HMLAN ist das fhem-Modul f&uuml;r den eQ-3 HomeMatic LAN Configurator welcher als IO 
    in FHEM fungiert. Siehe <a href="http://www.fhemwiki.de/wiki/HM-CFG-LAN_LAN_Konfigurations-Adapter">HM-CFG-LAN_LAN_Konfigurations-Adapter</a> zur Konfiguration.<br>
    Eine weitere Beschreibung, wie der HomeMatic USB Konfigurations-Adapter 
    <a href="https://git.zerfleddert.de/cgi-bin/gitweb.cgi/hmcfgusb">(HM-CFG-USB)</a> 
    verwendet werden kann, ist unter dem angegebenen Link zu finden.<br/>
    <br>
    Dieses Ger&auml;t kann gleichzeitig mit einer CCU und (nur lesend) mit FHEM verwendet werden. 
    Hierf&uuml;r ist wie folgt vorzugehen:
    <ul>
        <li>Starten des fhem/contrib/tcptee.pl Programms</li>
        <li>Umleiten der CCU zum local host</li>
        <li>Ausschalten der LAN-Encryption auf der CCU f&uuml;r den LAN-Configurator</li>
        <li>Setzen des dummy Attributes f&uuml;r das HMLAN Ger&auml;t in FHEM</li>
    </ul>
    <br><br>

    <a name="HMLANdefine"><b>Define</b></a>
    <ul>
        <code>define &lt;name&gt; HMLAN &lt;ip-address&gt;[:port]</code><br>
        <br>
        Der Standard-Port lautet: 1000.<br/>
        Wenn keine IP-Adresse angegeben wird, wird auch kein Ger&auml;t ge&ouml;ffnet; man kann 
	also auch ohne angeschlossene Hardware experimentieren.
    </ul>
    <br><br>

    <a name="HMLANset"><b>Set</b></a>
    <ul>
        <li><a href="#hmPairForSec">hmPairForSec</a></li>
        <li><a href="#hmPairSerial">hmPairSerial</a></li>
        <li><a href="#hmreopen">reopen</a>
           Connection zum IO device neu starten</li>
        <li><a href="#hmrestart">restart</a>
           Neustart des IOdevice
           </li>
        <li><a href="#HMLANset_reassignIDs">reassignIDs</a>
          Synchronisiert die im HMLAN eingetragenen IDs mit der von FHEM verwalteten Liste. 
          I.a. findet dies automatisch statt, koennte aber in reset Fällen abweichen.
          </li>
    </ul>
    <br><br>
    <a name="HMLANget"><b>Get</b></a>
    <ul>
        <li><a href="#HMLANgetassignIDs">assignIDs</a>
          Gibt eine Liste aller diesem IO zugewiesenen IOs aus.
          </li>
    </ul>
    <br><br>

    <a name="HMLANattr"><b>Attributes</b></a>
    <ul>
        <li><a href="#do_not_notify">do_not_notify</a></li><br>
        <li><a href="#attrdummy">dummy</a></li><br>
        <li><a href="#addvaltrigger">addvaltrigger</a></li><br>
        <li><a href="#HMLANlogIDs">logIDs</a><br>
           Schaltet selektives Aufzeichnen der HMLAN Meldungen ein. Eine Liste der 
           HMIds oder Namen, die aufgezeichnet werden sollen, k&ouml;nnen - getrennt durch 
           Kommata - eingegeben werden.<br>
           Die Attribute erlauben ausschließlich die Angabe von Device-IDs und keine Kanal-IDs. 
           Die Kanal-IDs werden automatisch in Device-IDs umgewandelt.<br>
           <b>all</b> zeichnet die Original-Meldungen f&uuml;r alle HMIds auf.<br>
           <b>sys</b> zeichnet alle systemrelevanten Meldungen wie keep-alive auf.<br>
           <b>all,sys</b> damit wird die Aufzeichnung aller Meldungen eingeschaltet<br>
        </li>
        <li><a name="HMLANloadLevel">loadLevel</a><br>
            loadlevel mapped den Auslastungslevel auf die Namen in ein Reading. <br>
            0:low,30:mid,40:batchLevel,90:high,99:suspended<br>
            Der batchLevel Wert wird auf 40 gesetzt., sollte er fehlen. 
            Das ist der Levelbei dem die Hintergrundnachrichten z.B. durch autoReadReg gestoppt werden<br>
        </li><br>
        <li><a href="#hmId">hmId</a></li><br>
        <li><a name="HMLANhmKey">hmKey</a></li><br>
        <li><a name="HMLANhmKey2">hmKey2</a></li><br>
        <li><a name="HMLANhmKey3">hmKey3</a></li><br>
        <li><a name="HMLANhmKey4">hmKey4</a></li><br>
        <li><a name="HMLANhmKey5">hmKey5</a><br>
          AES Schl&uuml;ssel f&uuml;r den HMLAN Adapter. <br>
          Der Schl&uuml;ssel wird in eine hash-Zeichenfolge umgewandelt. Wenn eine Hash-Folge unmittelbar 
          eingegeben wird, erfolgt keine Umwandlung, sondern eine eine direkte Benutzung der Hash-Folge. 
          Deshalb kann der Originalschl&uuml;ssel auch nicht entschl&uuml;sselt werden.<br>
        </li>
        <li><a href="#hmProtocolEvents">hmProtocolEvents</a></li><br>
        <li><a name="HMLANrespTime">respTime</a><br>
          Definiert die maximale Antwortzeit des HMLAN-Adapters in Sekunden. Standardwert ist 1 Sekunde.<br/>
          L&auml;ngere Zeiten k&ouml;nnen &uuml;bergangsweise in langsamen und instabilen Systemen oder in
          LAN-Konfigurationen verwendet werden.</li>
        <li><a name="HMLAN#wdTimer">wdTimer</a><br>
          Zeit in Sekunden, um den HMLAN zu triggern. Werte zwischen 5 und 25 sind zul&auml;ssig. 
          Standardwert ist 25 Sekunden.<br>
          Es wird <B>davon abgeraten</B> diesen Timer zu ver&auml;ndern. Wenn Probleme mit 
          HMLAN-Abbr&uuml;chen bestehen wird empfohlen die Ursache des Problems zu finden 
          und zu beheben und nicht die Symptom.</li>
        <li><a name="HMLANhmLanQlen">hmLanQlen</a><br>
          Definiert die L&auml;nge der Warteschlange des HMLAN Interfaces. Es ist deshalb die Anzahl 
          der gleichzeitig zu sendenden Meldungen. Erh&ouml;hung des Wertes kann eine Steigerung der
          &Uuml;bertragungsgeschwindigkeit verursachen, ebenso k&ouml;nnen wiederholte Aussendungen 
          Datenverlust bewirken.<br>
          Die Auswirkungen werden durch die Ereignisse im Protokoll sichtbar.<br>
          1 - ist ein Wert auf der sicheren Seite und deshalb der Standardwert<br>
          5 - ist eine kritische L&auml;nge und verursacht wahrscheinlich Meldungsverluste</li>
    </ul>
    <a name="HMLANparameter"><b>parameter</b></a>
    <ul>
      <li><B>assignedIDsCnt</B><br>
          Anzahl der IDs, die von FHEM einem HMLAN zugeordnet sind. 
          Sollte die Anzahl von der im HMLAN abweichen wird dies als 'reported' gemeldet.<br>
          Wird eine Abweichung festgestellt kann man mit dem Kommando assignIDs das HMLAN synchronisieren.
          </li>
      <li><B>msgKeepAlive</B><br>
          G&uuml;te der keep-alive Meldungen. <br>
          <B>dlyMax</B>: maximale Verz&ouml;gerungsdauer zwischen dem geplanten Meldungszeitpunkt 
          und der tats&auml;chlich gesendeten Meldung.<br>
          <B>bufferMin</B>: minimal verf&uuml;gbarer Speicher bevor HMLAN voraussichtlich 
          unterbrochen wird bedingt durch die fehlende keepAlive Meldung. bufferMin 
          wird auf 30 Sekunden zur&uuml;ckgesetzt wenn das Attribut wdTimer ver&auml;ndert wird.<br>
          Wenn dlyMax hoch ist (mehrere Sekunden) oder bufferMin geht gegen "0" (normal ist 4) 
          leidet das System unter den internen Verz&ouml;gerungen. Den Gr&uuml;nden hierf&uuml;r muss 
          nachgegangen werdensystem. Als schnelle L&ouml;sung kann der Wert f&uuml;r wdTimer 
          verkleinert werden, um HMLAN schneller zu triggern.</li>
      <li><B>msgLoadCurrent</B><br>
          Aktuelle Funklast des HMLAN. Da HMLAN nur eine begrenzte Kapzit&auml;t je Stunde hat 
          Telegramme abzusetzen stellt es bei 100% das Senden ein. Siehe auch
          <a href="#loadLevel">loadLevel</a><br></li>
      <li><B>msgLoadHistoryAbs</B><br>
          IO Funkbelastung vergangener Zeitabschnitte.</li>
      <li><B>msgParseDly</B><br>
          Kalkuliert die Verz&ouml;gerungen einer Meldung vom Zeitpunkt des Abschickens im HMLAN 
          bis zu Verarbeitung in FHEM. Deshalb ist dies ein Indikator f&uuml;r die Leistungsf&auml;higkeit 
          des Systems  von FHEM.
          </li>
    </ul>
    <a name="HMLANreadings"><b>Parameter und Readings</b></a>
    <ul>
      <li><B>prot_disconnect</B>       <br>letzter HMLAN disconnect</li>
      <li><B>prot_init</B>             <br>letzter HMLAN init</li>
      <li><B>prot_keepAlive</B>        <br>HMLAN unterbrochen, wahrscheinlich um langsame 
      keep-alive Meldungen zu senden.</li>
      <li><B>prot_ok</B>               <br>letzte HMLAN ok Bedingung</li>
      <li><B>prot_timeout</B>          <br>letzter HMLAN Timeout</li>
      <li><B>prot_Warning-HighLoad</B> <br>hohe Auslastung erreicht -  
        HMLAN hat nur noch 10% seiner Leistungsf&auml;higkeit &uuml;brig</li>
      <li><B>prot_ERROR-Overload</B>   <br>&Uuml;berlastung - 
        HMLAN wird zwar Meldungen empfangen aber keine Meldungen mehr absenden</li>
      <li><B>prot_Overload-released</B><br>&Uuml;berlastung beendet - normale Arbeitsweise ist m&ouml;glich</li>
    </ul>

</ul>
=end html_DE
=cut
