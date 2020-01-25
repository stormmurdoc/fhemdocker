##############################################
# $Id: DevIo.pm 20174 2019-09-16 18:04:03Z rudolfkoenig $
package main;

sub DevIo_CloseDev($@);
sub DevIo_Disconnected($);
sub DevIo_Expect($$$);
sub DevIo_OpenDev($$$;$);
sub DevIo_SetHwHandshake($);
sub DevIo_SimpleRead($);
sub DevIo_SimpleReadWithTimeout($$);
sub DevIo_SimpleWrite($$$;$);
sub DevIo_TimeoutRead($$;$$);

sub
DevIo_setStates($$)
{
  my ($hash, $val) = @_;
  $hash->{STATE} = $val;
  setReadingsVal($hash, "state", $val, TimeNow());
}

########################
# Try to read once from the device.
# "private" function
sub
DevIo_DoSimpleRead($)
{
  my ($hash) = @_;
  my ($buf, $res);

  if($hash->{USBDev}) {
    $buf = $hash->{USBDev}->input();

  } elsif($hash->{DIODev}) {
    $res = sysread($hash->{DIODev}, $buf, 4096);
    $buf = undef if(!defined($res));

  } elsif($hash->{TCPDev}) {
    $res = sysread($hash->{TCPDev}, $buf, 4096);
    $buf = "" if(!defined($res));

  } elsif($hash->{IODev}) {

    if($hash->{IOReadFn}) {
      $buf = CallFn($hash->{IODev}{NAME},"IOReadFn",$hash);

    } else {
      $buf = $hash->{IODevRxBuffer};
      $hash->{IODevRxBuffer} = "";
      $buf = "" if(!defined($buf));
    }

  }
  return $buf;
}

########################
# This is the function to read data, to be called in ReadFn.
# If there is no data, sets the device to disconnected, which results in
# polling via ReadyFn, trying to open it.
sub
DevIo_SimpleRead($)
{
  my ($hash) = @_;
  my $buf = DevIo_DoSimpleRead($hash);

  ###########
  # Lets' try again: Some drivers return len(0) on the first read...
  if(defined($buf) && length($buf) == 0) {
    $buf = DevIo_SimpleReadWithTimeout($hash, 0.01); # Forum #57806
  }

  if(!defined($buf) || length($buf) == 0) {
    DevIo_Disconnected($hash);
    return undef;
  }
  return $buf;
}

########################
# wait at most timeout seconds until the file handle gets ready
# for reading; returns undef on timeout
# NOTE1: FHEM can be blocked for $timeout seconds, DO NOT USE IT!
# NOTE2: This works on Windows only for TCP connections
sub
DevIo_SimpleReadWithTimeout($$)
{
  my ($hash, $timeout) = @_;

  my $rin = "";
  vec($rin, $hash->{FD}, 1) = 1;
  my $nfound = select($rin, undef, undef, $timeout);
  return DevIo_DoSimpleRead($hash) if($nfound> 0);
  return undef;
}

########################
# Read until the timeout occures
# NOTE1: FHEM WILL be blocked for $timeout seconds, DO NOT USE IT!
# NOTE2: This works on Windows only for TCP connections
sub
DevIo_TimeoutRead($$;$$)
{
  my ($hash, $timeout, $maxlen, $regexp) = @_;

  my $answer = "";
  $timeout = 1 if(!$timeout);
  $maxlen = 1024 if(!$maxlen);    # Avoid endless loop
  for(;;) {
    my $rin = "";
    vec($rin, $hash->{FD}, 1) = 1;
    my $nfound = select($rin, undef, undef, $timeout);
    last if($nfound <= 0);      # timeout
    my $r = DevIo_DoSimpleRead($hash);
    last if(!defined($r) || ($r == "" && $hash->{TCPDev}));
    $answer .= $r;
    last if(length($anser) >= $maxlen || ($regexp && $answer =~ m/$regexp/));
  }
  return $answer;
}

########################
# Function to write data
sub
DevIo_SimpleWrite($$$;$)
{
  my ($hash, $msg, $type, $addnl) = @_; # Type: 0:binary, 1:hex, 2:ASCII
  return if(!$hash);

  my $name = $hash->{NAME};
  Log3 ($name, 5, $type ? "SW: $msg" : "SW: ".unpack("H*",$msg));

  $msg = pack('H*', $msg) if($type && $type == 1);
  $msg .= "\n" if($addnl);
  if($hash->{USBDev}){
    $hash->{USBDev}->write($msg);

  } elsif($hash->{TCPDev}) {
    syswrite($hash->{TCPDev}, $msg);

  } elsif($hash->{DIODev}) { 
    syswrite($hash->{DIODev}, $msg);

  } elsif($hash->{IODev}) { 
    CallFn($hash->{IODev}{NAME},"IOWriteFn",$hash,$msg);

  }
  select(undef, undef, undef, 0.001);
}

########################
# Write something, then read something
# reopen device if timeout occurs and write again, then read again
# NOTE1: FHEM can be blocked for $timeout seconds, DO NOT USE IT!
sub
DevIo_Expect($$$)
{
  my ($hash, $msg, $timeout) = @_;
  my $name= $hash->{NAME};
  
  my $state= $hash->{STATE};
  if($state ne "opened") {
    Log3 $name, 2, "Attempt to write to $state device.";
    return undef;
  }
  # write something
  return undef unless defined(DevIo_SimpleWrite($hash, $msg, 0));
  # read answer
  my $answer= DevIo_SimpleReadWithTimeout($hash, $timeout);
  return $answer unless($answer eq "");
    # the device has failed to deliver a result
  DevIo_setStates($hash, "failed");
  DoTrigger($name, "FAILED");

  # reopen device
  # unclear how to know whether the following succeeded
  Log3 $name, 2, "$name: first attempt to read timed out, ".
                        "trying to close and open the device.";

  # The next two lines are required to avoid a deadlock when the remote end
  # closes the connection upon DevIo_OpenDev, as e.g. netcat -l <port> does.
  DevIo_CloseDev($hash);
  DevIo_OpenDev($hash, 0, undef); # where to get the initfn from? 

  # write something again
  return undef unless defined(DevIo_SimpleWrite($hash, $msg, 0));

  # read answer again
  $answer= DevIo_SimpleReadWithTimeout($hash, $timeout);

  # success
  if($answer ne "") {
    DevIo_setStates($hash, "opened");
    DoTrigger($name, "CONNECTED");
    return $answer;
  }

  # ultimate failure
  Log3 $name, 2,
    "$name: second attempt to read timed out, this is an unrecoverable error.";
  DoTrigger($name, "DISCONNECTED");
  return undef; # undef means ultimate failure
}


########################
# Open a device for reading/writing data.
# Possible values for $hash->{DeviceName}:
# - device@baud[78][NEO][012] => open device, set serial-line parameters
# - hostname:port => TCP/IP client connection
# - device@directio => open device without additional "magic"
# - UNIX:(SEQPACKET|STREAM):filename => Open filename as a UNIX socket
# - FHEM:DEVIO:IoDev[:IoPort] => Cascade I/O over another FHEM Device
#
# callback is only meaningful for TCP/IP (in which case a nonblocking connect
# is executed) every cases. It will be called with $hash and a (potential)
# error message. If $hash->{SSL} is set, SSL encryption is activated.
sub
DevIo_OpenDev($$$;$)
{
  my ($hash, $reopen, $initfn, $callback) = @_;
  my $dev = $hash->{DeviceName};
  my $name = $hash->{NAME};
  my $po;
  my $baudrate;
  ($dev, $baudrate) = split("@", $dev);
  my ($databits, $parity, $stopbits) = (8, 'none', 1);
  my $nextOpenDelay = ($hash->{nextOpenDelay} ? $hash->{nextOpenDelay} : 60);

  # Call the callback if specified, simply return in other cases
  my $doCb = sub ($) {
    my ($r) = @_;
    Log3 $name, 1, "$name: Can't connect to $dev: $r" if(!$reopen && $r);
    $callback->($hash,$r) if($callback);
    return $r;
  };

  # Call initFn
  # if fails: disconnect, schedule the next polltime for reopen
  # if ok: log message, trigger CONNECTED on reopen
  my $doTailWork = sub {
    DevIo_setStates($hash, "opened");

    my $ret;
    if($initfn) {
      my $hadFD = defined($hash->{FD});
      $ret = &$initfn($hash);
      if($ret) {
        if($hadFD && !defined($hash->{FD})) { # Forum #54732 / ser2net
          DevIo_Disconnected($hash);
          $hash->{NEXT_OPEN} = time() + $nextOpenDelay;

        } else {
          DevIo_CloseDev($hash);
          Log3 $name, 1, "Cannot init $dev, ignoring it ($name)";
        }
      }
    }

    if(!$ret) {
      my $l = $hash->{devioLoglevel}; # Forum #61970
      if($reopen) {
        Log3 $name, ($l ? $l:1), "$dev reappeared ($name)";
      } else {
        Log3 $name, ($l ? $l:3), "$name device opened" if(!$hash->{DevioText});
      }
    }

    DoTrigger($name, "CONNECTED") if(!$ret);
    return undef;
  };
  
  if($baudrate =~ m/(\d+)(,([78])(,([NEO])(,([012]))?)?)?/) {
    $baudrate = $1 if(defined($1));
    $databits = $3 if(defined($3));
    $parity = 'odd'  if(defined($5) && $5 eq 'O');
    $parity = 'even' if(defined($5) && $5 eq 'E');
    $stopbits = $7 if(defined($7));
  }

  if($hash->{DevIoJustClosed}) {
    delete $hash->{DevIoJustClosed};
    return &$doCb(undef);
  }

  $hash->{PARTIAL} = "";
  Log3 $name, 3, ($hash->{DevioText} ? $hash->{DevioText} : "Opening").
       " $name device ". (AttrVal($name,"privacy",0) ? "(private)" : $dev)
       if(!$reopen);

  if($dev =~ m/^UNIX:(SEQPACKET|STREAM):(.*)$/) { # FBAHA
    my ($type, $fname) = ($1, $2);
    my $conn;
    eval {
      require IO::Socket::UNIX;
      $conn = IO::Socket::UNIX->new(
        Type=>($type eq "STREAM" ? SOCK_STREAM:SOCK_SEQPACKET), Peer=>$fname);
    };
    if($@) {
      Log3 $name, 1, $@;
      return &$doCb($@);
    }

    if(!$conn) {
      Log3 $name, 1, "$name: Can't connect to $dev: $!" if(!$reopen);
      $readyfnlist{"$name.$dev"} = $hash;
      DevIo_setStates($hash, "disconnected");
      return &$doCb("");
    }
    $hash->{TCPDev} = $conn;
    $hash->{FD} = $conn->fileno();
    delete($readyfnlist{"$name.$dev"});
    $selectlist{"$name.$dev"} = $hash;

  } elsif($dev =~ m/^FHEM:DEVIO:(.*)(:(.*))/) {      # Forum #46276
    my ($devName, $devPort) = ($1, $3);
    AssignIoPort($hash, $devName);
    if (defined($hash->{IODev})) {
      ($dev, $baudrate) = split("@", $hash->{DeviceName});
      $hash->{IODevPort} = $devPort if (defined($devPort));
      $hash->{IODevParameters} = $baudrate if (defined($baudrate));
      if (!CallFn($devName, "IOOpenFn", $hash)) {
        Log3 $name, 1, "$name: Can't open $dev!";
        DevIo_setStates($hash, "disconnected");
        return &$doCb("");
      }
    } else {
      DevIo_setStates($hash, "disconnected");
      return &$doCb("");
    }
  } elsif($dev =~ m/^(.+):([0-9]+)$/) {       # host:port

    # This part is called every time the timeout (5sec) is expired _OR_
    # somebody is communicating over another TCP connection. As the connect
    # for non-existent devices has a delay of 3 sec, we are sitting all the
    # time in this connect. NEXT_OPEN tries to avoid this problem.
    if($hash->{NEXT_OPEN} && time() < $hash->{NEXT_OPEN}) {
      return &$doCb(undef); # Forum 53309
    }

    delete($readyfnlist{"$name.$dev"});
    my $timeout = $hash->{TIMEOUT} ? $hash->{TIMEOUT} : 3;

    
    # Do common TCP/IP "afterwork":
    # if connected: set keepalive, fill selectlist, FD, TCPDev.
    # if not: report the error and schedule reconnect
    my $doTcpTail = sub($) {
      my ($conn) = @_;
      if($conn) {
        delete($hash->{NEXT_OPEN});
        $conn->setsockopt(SOL_SOCKET, SO_KEEPALIVE, 1) if(defined($conn));

      } else {
        Log3 $name, 1, "$name: Can't connect to $dev: $!" if(!$reopen && $!);
        $readyfnlist{"$name.$dev"} = $hash;
        DevIo_setStates($hash, "disconnected");
        DoTrigger($name, "DISCONNECTED") if(!$reopen);
        $hash->{NEXT_OPEN} = time() + $nextOpenDelay;
        return 0;
      }

      $hash->{TCPDev} = $conn;
      $hash->{FD} = $conn->fileno();
      $hash->{CD} = $conn;
      $selectlist{"$name.$dev"} = $hash;
      return 1;
    };

    if($callback) { # reuse the nonblocking connect from HttpUtils.
      use HttpUtils;
      my $err = HttpUtils_Connect({     # Nonblocking
        timeout => $timeout,
        url     => $hash->{SSL} ? "https://$dev/" : "http://$dev/",
        NAME    => $hash->{NAME},
        sslargs => $hash->{sslargs} ? $hash->{sslargs} : {},
        noConn2 => 1,
        callback=> sub() {
          my ($h, $err, undef) = @_;
          &$doTcpTail($err ? undef : $h->{conn});
          return &$doCb($err ? $err : &$doTailWork());
        }
      });
      return &$doCb($err) if($err);
      return undef;     # no double callback: connect is running in bg now

    } else {    # blocking connect
      my $conn = $haveInet6 ? 
          IO::Socket::INET6->new(PeerAddr => $dev, Timeout => $timeout) :
          IO::Socket::INET ->new(PeerAddr => $dev, Timeout => $timeout);
      return "" if(!&$doTcpTail($conn)); # no callback: no doCb
    }

  } elsif($baudrate && lc($baudrate) eq "directio") { # w/o Device::SerialPort

    if(!open($po, "+<$dev")) {
      return &$doCb(undef) if($reopen);
      Log3 $name, 1, "$name: Can't open $dev: $!";
      $readyfnlist{"$name.$dev"} = $hash;
      DevIo_setStates($hash, "disconnected");
      return &$doCb("");
    }

    $hash->{DIODev} = $po;

    if( $^O =~ /Win/ ) {
      $readyfnlist{"$name.$dev"} = $hash;
    } else {
      $hash->{FD} = fileno($po);
      delete($readyfnlist{"$name.$dev"});
      $selectlist{"$name.$dev"} = $hash;
    }


  } else {                              # USB/Serial device

    if ($^O=~/Win/) {
     eval {
       require Win32::SerialPort;
       $po = new Win32::SerialPort ($dev);
     }
    } else  {
     eval {
       require Device::SerialPort;
       $po = new Device::SerialPort ($dev);
     }
    }
    if($@) {
      Log3 $name,  1, $@;
      return &$doCb($@);
    }

    if(!$po) {
      return &$doCb(undef) if($reopen);
      Log3 $name, 1, "$name: Can't open $dev: $!";
      $readyfnlist{"$name.$dev"} = $hash;
      DevIo_setStates($hash, "disconnected");
      return &$doCb("");
    }
    $hash->{USBDev} = $po;
    if( $^O =~ /Win/ ) {
      $readyfnlist{"$name.$dev"} = $hash;
    } else {
      $hash->{FD} = $po->FILENO;
      delete($readyfnlist{"$name.$dev"});
      $selectlist{"$name.$dev"} = $hash;
    }

    if($baudrate) {
      $po->reset_error();
      my $p = ($parity eq "none" ? "N" : ($parity eq "odd" ? "O" : "E"));
      Log3 $name, 3, "Setting $name serial parameters to ".
                    "$baudrate,$databits,$p,$stopbits" if(!$hash->{DevioText});
      $po->baudrate($baudrate);
      $po->databits($databits);
      $po->parity($parity);
      $po->stopbits($stopbits);
      $po->handshake('none');

      # This part is for some Linux kernel versions whih has strange default
      # settings.  Device::SerialPort is nice: if the flag is not defined for
      # your OS then it will be ignored.

      $po->stty_icanon(0);
      #$po->stty_parmrk(0); # The debian standard install does not have it
      $po->stty_icrnl(0);
      $po->stty_echoe(0);
      $po->stty_echok(0);
      $po->stty_echoctl(0);

      # Needed for some strange distros
      $po->stty_echo(0);
      $po->stty_icanon(0);
      $po->stty_isig(0);
      $po->stty_opost(0);
      $po->stty_icrnl(0);
    }

    $po->write_settings;
  }

  return &$doCb(&$doTailWork());
}

sub
DevIo_SetHwHandshake($)
{
  my ($hash) = @_;
  $hash->{USBDev}->can_dtrdsr();
  $hash->{USBDev}->can_rtscts();
}

########################
# close the device, remove it from selectlist, 
# delete DevIo specific internals from $hash
sub
DevIo_CloseDev($@)
{
  my ($hash,$isFork) = @_;
  my $name = $hash->{NAME};
  my $dev = $hash->{DeviceName};

  return if(!$dev);
  
  if($hash->{TCPDev}) {
    if($isFork && $hash->{SSL}) { # Forum #94219
      $hash->{TCPDev}->close(SSL_no_shutdown => 1);
    } else {
      $hash->{TCPDev}->close();
    }
    delete($hash->{TCPDev});

  } elsif($hash->{USBDev}) {
    if($isFork) { # SerialPort close resets the serial parameters.
      POSIX::close($hash->{USBDev}{FD});
    } else {
      $hash->{USBDev}->close() ;
    }
    delete($hash->{USBDev});

  } elsif($hash->{DIODev}) {
    close($hash->{DIODev});
    delete($hash->{DIODev});

  } elsif($hash->{IODev}) {
    eval {
      CallFn($hash->{IODev}{NAME}, "IOCloseFn", $hash);
    }; # ignore closing errors (e.g. caused by fork)
    delete($hash->{IODevParameters});
    delete($hash->{IODevPort});
    delete($hash->{IODevRxBuffer});
    delete($hash->{IODev});
    
  }
  ($dev, undef) = split("@", $dev); # Remove the baudrate
  delete($selectlist{"$name.$dev"});
  delete($readyfnlist{"$name.$dev"});
  delete($hash->{FD});
  delete($hash->{EXCEPT_FD});
  delete($hash->{PARTIAL});
  delete($hash->{NEXT_OPEN});
}

sub
DevIo_IsOpen($)
{
  my ($hash) = @_;
  return ($hash->{TCPDev} || 
          $hash->{USBDev} || 
          $hash->{DIODev} || 
          $hash->{IODevPort});
}


# Close the device, schedule the reopen via ReadyFn, trigger DISCONNECTED
sub
DevIo_Disconnected($)
{
  my $hash = shift;
  my $dev = $hash->{DeviceName};
  my $name = $hash->{NAME};
  my $baudrate;
  ($dev, $baudrate) = split("@", $dev);

  return if(!defined($hash->{FD}));                 # Already deleted or RFR

  my $l = $hash->{devioLoglevel}; # Forum #61970
  Log3 $name, ($l ? $l:1), "$dev disconnected, waiting to reappear ($name)";
  DevIo_CloseDev($hash);
  $readyfnlist{"$name.$dev"} = $hash;               # Start polling
  DevIo_setStates($hash, "disconnected");
  $hash->{DevIoJustClosed} = 1;                     # Avoid a direct reopen

  DoTrigger($name, "DISCONNECTED");
}

1;
