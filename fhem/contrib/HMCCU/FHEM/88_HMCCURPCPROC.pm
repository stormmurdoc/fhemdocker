##############################################################################
#
#  88_HMCCURPCPROC.pm
#
#  $Id: 88_HMCCURPCPROC.pm 18745 2019-02-26 17:33:23Z zap $
#
#  Version 4.4.000
#
#  Subprocess based RPC Server module for HMCCU.
#
#  (c) 2020 by zap (zap01 <at> t-online <dot> de)
#
##############################################################################
#
#  Required perl modules:
#
#    RPC::XML::Client
#    RPC::XML::Server
#
##############################################################################


package main;

use strict;
use warnings;

# use Data::Dumper;
use RPC::XML::Client;
use RPC::XML::Server;
use SetExtensions;

require "$attr{global}{modpath}/FHEM/88_HMCCU.pm";


######################################################################
# Constants
######################################################################

# HMCCURPC version
my $HMCCURPCPROC_VERSION = '4.4.000';

# Maximum number of events processed per call of Read()
my $HMCCURPCPROC_MAX_EVENTS = 100;

# Maximum number of errors during socket write before log message is written
my $HMCCURPCPROC_MAX_IOERRORS  = 100;

# Maximum number of elements in queue
my $HMCCURPCPROC_MAX_QUEUESIZE = 500;

# Maximum number of events to be send to FHEM within one function call
my $HMCCURPCPROC_MAX_QUEUESEND = 70;

# Time to wait after data processing loop in microseconds
my $HMCCURPCPROC_TIME_WAIT = 100000;

# RPC ping interval for default interface, should be smaller than HMCCURPCPROC_TIMEOUT_EVENT
my $HMCCURPCPROC_TIME_PING = 300;

# Timeout for established CCU connection in seconds
my $HMCCURPCPROC_TIMEOUT_CONNECTION = 1;

# Timeout for TriggerIO() in seconds
my $HMCCURPCPROC_TIMEOUT_WRITE = 0.001;

# Timeout for accepting incoming connections in seconds (0 = default)
my $HMCCURPCPROC_TIMEOUT_ACCEPT = 1;

# Timeout for incoming CCU events in seconds (0 = ignore timeout)
my $HMCCURPCPROC_TIMEOUT_EVENT = 0;

# Send statistic information after specified amount of events
my $HMCCURPCPROC_STATISTICS = 500;

# Default RPC server base port
my $HMCCURPCPROC_SERVER_PORT = 5400;

# Delay for RPC server start after FHEM is initialized in seconds
my $HMCCURPCPROC_INIT_INTERVAL0 = 12;

# Delay for RPC server cleanup after stop in seconds
my $HMCCURPCPROC_INIT_INTERVAL2 = 30;

# Delay for RPC server functionality check after start in seconds
my $HMCCURPCPROC_INIT_INTERVAL3 = 25;

# BinRPC data types
my $BINRPC_INTEGER = 1;
my $BINRPC_BOOL    = 2;
my $BINRPC_STRING  = 3;
my $BINRPC_DOUBLE  = 4;
my $BINRPC_BASE64  = 17;
my $BINRPC_ARRAY   = 256;
my $BINRPC_STRUCT  = 257;

# BinRPC message types
my $BINRPC_REQUEST        = 0x42696E00;
my $BINRPC_RESPONSE       = 0x42696E01;
my $BINRPC_REQUEST_HEADER = 0x42696E40;
my $BINRPC_ERROR          = 0x42696EFF;

# BinRPC datatype mapping
my %BINRPC_TYPE_MAPPING = (
	"BOOL" => $BINRPC_BOOL,
	"INTEGER" => $BINRPC_INTEGER,
	"STRING" => $BINRPC_STRING,
	"FLOAT" => $BINRPC_DOUBLE,
	"DOUBLE" => $BINRPC_DOUBLE,
	"BASE64" => $BINRPC_BASE64,
	"ARRAY" => $BINRPC_ARRAY,
	"STRUCT" => $BINRPC_STRUCT
);

# Read/Write flags for RPC methods (0=Read, 1=Write)
my %RPC_METHODS = (
	'putParamset' => 1,
	'getParamset' => 0,
	'getParamsetDescription' => 0,
	'setValue' => 1,
	'getValue' => 0
);

######################################################################
# Functions
######################################################################

# Standard functions
sub HMCCURPCPROC_Initialize ($);
sub HMCCURPCPROC_Define ($$);
sub HMCCURPCPROC_InitDevice ($$);
sub HMCCURPCPROC_Undef ($$);
sub HMCCURPCPROC_DelayedShutdown ($);
sub HMCCURPCPROC_Shutdown ($);
sub HMCCURPCPROC_Attr ($@);
sub HMCCURPCPROC_Set ($@);
sub HMCCURPCPROC_Get ($@);
sub HMCCURPCPROC_Read ($);
sub HMCCURPCPROC_SetError ($$$);
sub HMCCURPCPROC_SetState ($$);
sub HMCCURPCPROC_ProcessEvent ($$);

# RPC information
sub HMCCURPCPROC_GetDeviceDesc ($;$);
sub HMCCURPCPROC_GetParamsetDesc ($;$);

# RPC server control functions
sub HMCCURPCPROC_CheckProcessState ($$);
sub HMCCURPCPROC_CleanupIO ($);
sub HMCCURPCPROC_CleanupProcess ($);
sub HMCCURPCPROC_DeRegisterCallback ($$);
sub HMCCURPCPROC_GetRPCServerID ($$);
sub HMCCURPCPROC_Housekeeping ($);
sub HMCCURPCPROC_InitRPCServer ($$$$);
sub HMCCURPCPROC_IsRPCServerRunning ($);
sub HMCCURPCPROC_IsRPCStateBlocking ($);
sub HMCCURPCPROC_RegisterCallback ($$);
sub HMCCURPCPROC_ResetRPCState ($);
sub HMCCURPCPROC_RPCPing ($);
sub HMCCURPCPROC_RPCServerStarted ($);
sub HMCCURPCPROC_RPCServerStopped ($);
sub HMCCURPCPROC_SendRequest ($@);
sub HMCCURPCPROC_SetRPCState ($$$$);
sub HMCCURPCPROC_StartRPCServer ($);
sub HMCCURPCPROC_StopRPCServer ($$);
sub HMCCURPCPROC_TerminateProcess ($);

# Helper functions
sub HMCCURPCPROC_GetAttribute ($$$$);
sub HMCCURPCPROC_HexDump ($$);

# RPC server functions
sub HMCCURPCPROC_ProcessRequest ($$);
sub HMCCURPCPROC_HandleConnection ($$$$);
sub HMCCURPCPROC_SendQueue ($$$$);
sub HMCCURPCPROC_SendData ($$);
sub HMCCURPCPROC_Write ($$$$);
sub HMCCURPCPROC_WriteStats ($$);
sub HMCCURPCPROC_NewDevicesCB ($$$);
sub HMCCURPCPROC_DeleteDevicesCB ($$$);
sub HMCCURPCPROC_UpdateDeviceCB ($$$$);
sub HMCCURPCPROC_ReplaceDeviceCB ($$$$);
sub HMCCURPCPROC_ReaddDevicesCB ($$$);
sub HMCCURPCPROC_EventCB ($$$$$);
sub HMCCURPCPROC_ListDevicesCB ($$);

# RPC encoding functions
sub HMCCURPCPROC_EncValue ($$);
sub HMCCURPCPROC_EncInteger ($);
sub HMCCURPCPROC_EncBool ($);
sub HMCCURPCPROC_EncString ($);
sub HMCCURPCPROC_EncName ($);
sub HMCCURPCPROC_EncDouble ($);
sub HMCCURPCPROC_EncBase64 ($);
sub HMCCURPCPROC_EncArray ($);
sub HMCCURPCPROC_EncStruct ($);
sub HMCCURPCPROC_EncType ($$);
sub HMCCURPCPROC_EncodeRequest ($$);
sub HMCCURPCPROC_EncodeResponse ($$);

# Binary RPC decoding functions
sub HMCCURPCPROC_DecInteger ($$$);
sub HMCCURPCPROC_DecBool ($$);
sub HMCCURPCPROC_DecString ($$);
sub HMCCURPCPROC_DecDouble ($$);
sub HMCCURPCPROC_DecBase64 ($$);
sub HMCCURPCPROC_DecArray ($$);
sub HMCCURPCPROC_DecStruct ($$);
sub HMCCURPCPROC_DecType ($$);
sub HMCCURPCPROC_DecodeRequest ($);
sub HMCCURPCPROC_DecodeResponse ($);


######################################################################
# Initialize module
######################################################################

sub HMCCURPCPROC_Initialize ($)
{
	my ($hash) = @_;

	$hash->{DefFn}      = "HMCCURPCPROC_Define";
	$hash->{UndefFn}    = "HMCCURPCPROC_Undef";
	$hash->{SetFn}      = "HMCCURPCPROC_Set";
	$hash->{GetFn}      = "HMCCURPCPROC_Get";
	$hash->{ReadFn}     = "HMCCURPCPROC_Read";
	$hash->{AttrFn}     = "HMCCURPCPROC_Attr";
	$hash->{ShutdownFn} = "HMCCURPCPROC_Shutdown";
	$hash->{DelayedShutdownFn} = "HMCCURPCPROC_DelayedShutdown";
	
	$hash->{parseParams} = 1;

	$hash->{AttrList} = "ccuflags:multiple-strict,expert,logEvents,ccuInit,queueEvents,noEvents,noInitialUpdate,statistics".
		" rpcMaxEvents rpcQueueSend rpcQueueSize rpcMaxIOErrors". 
		" rpcServerAddr rpcServerPort rpcWriteTimeout rpcAcceptTimeout".
		" rpcConnTimeout rpcStatistics rpcEventTimeout rpcPingCCU ".
		$readingFnAttributes;
}

######################################################################
# Define device
######################################################################

sub HMCCURPCPROC_Define ($$)
{
	my ($hash, $a, $h) = @_;
	my $name = $hash->{NAME};
	my $hmccu_hash;
	my $ioname = '';
	my $rpcip = '';
	my $iface;
	my $usage = "Usage: define $name HMCCURPCPROC { CCUHost | iodev={device} } { RPCPort | RPCInterface }";
	
	$hash->{version} = $HMCCURPCPROC_VERSION;

	if (exists ($h->{iodev})) {
		$ioname = $h->{iodev};
		return $usage if (scalar (@$a) < 3);
		return "HMCCU I/O device $ioname not found" if (!exists ($defs{$ioname}));
		return "Device $ioname is not a HMCCU device" if ($defs{$ioname}->{TYPE} ne 'HMCCU');
		$hmccu_hash = $defs{$ioname};
		if (scalar (@$a) < 4) {
			$hash->{host} = $hmccu_hash->{host};
			$hash->{prot} = $hmccu_hash->{prot};
			$iface = $$a[2];
		}
		else {
			if ($$a[2] =~ /^(https?):\/\/(.+)/) {
				$hash->{prot} = $1;
				$hash->{host} = $2;
			}
			else {
				$hash->{prot} = 'http';
				$hash->{host} = $$a[2];
			}
			$iface = $$a[3];
		}
		$rpcip = HMCCU_ResolveName ($hash->{host}, 'N/A');
	}
	else {
		return $usage if (scalar (@$a) < 4);
		if ($$a[2] =~ /^(https?):\/\/(.+)/) {
			$hash->{prot} = $1;
			$hash->{host} = $2;
		}
		else {
			$hash->{prot} = 'http';
			$hash->{host} = $$a[2];
		}
		$iface = $$a[3];	
		$rpcip = HMCCU_ResolveName ($hash->{host}, 'N/A');

		# Find IO device
		foreach my $d (keys %defs) {
			my $dh = $defs{$d};
			next if (!exists ($dh->{TYPE}) || !exists ($dh->{NAME}));
			next if ($dh->{TYPE} ne 'HMCCU');
			if ($dh->{ccuip} eq $rpcip) {
				$hmccu_hash = $dh;	
				last;
			}
		}
	}

	# Store some definitions for delayed initialization
	$hash->{hmccu}{devspec} = $iface;
	$hash->{rpcip} = $rpcip;
			
	if ($init_done) {
		# Interactive define command while CCU not ready or no IO device defined
		if (!defined ($hmccu_hash)) {
			my ($ccuactive, $ccuinactive) = HMCCU_IODeviceStates ();
			if ($ccuinactive > 0) {
				return "CCU and/or IO device not ready. Please try again later";
			}
			else {
				return "Cannot detect IO device";
			}
		}
	}
	else {
		# CCU not ready during FHEM start
		if (!defined ($hmccu_hash) || $hmccu_hash->{ccustate} ne 'active') {
			HMCCU_Log ($hash, 2, "Cannot detect IO device, maybe CCU not ready. Trying later ...");
			readingsSingleUpdate ($hash, "state", "Pending", 1);
			$hash->{ccudevstate} = 'pending';
			return undef;
		}
	}

	# Initialize FHEM device, set IO device
	my $rc = HMCCURPCPROC_InitDevice ($hmccu_hash, $hash);
	return "Invalid port or interface $iface" if ($rc == 1);
	return "Can't assign I/O device $ioname" if ($rc == 2);
	return "Invalid local IP address ".$hash->{hmccu}{localaddr} if ($rc == 3);
	return "RPC device for CCU/port already exists" if ($rc == 4);
	return "Cannot connect to CCU ".$hash->{host}." interface $iface" if ($rc == 5);

	return undef;
}

######################################################################
# Initialization of FHEM device.
# Called during Define() or by HMCCU during delayed initialization
# after CCU ready.
# Return 0 on successful initialization or >0 on error:
# 1 = Invalid port or interface
# 2 = Cannot assign IO device
# 3 = Invalid local IP address
# 4 = RPC device for CCU/port already exists
# 5 = Cannot connect to CCU
######################################################################

sub HMCCURPCPROC_InitDevice ($$) {
	my ($hmccu_hash, $dev_hash) = @_;
	my $name = $dev_hash->{NAME};
	my $iface = $dev_hash->{hmccu}{devspec};
	
	# Check if interface is valid
	my ($ifname, $ifport) = HMCCU_GetRPCServerInfo ($hmccu_hash, $iface, 'name,port'); 
	return 1 if (!defined ($ifname) || !defined ($ifport));

	# Check if RPC device with same interface already exists
	foreach my $d (keys %defs) {
		my $dh = $defs{$d};
		next if (!exists ($dh->{TYPE}) || !exists ($dh->{NAME}));
		if ($dh->{TYPE} eq 'HMCCURPCPROC' && $dh->{NAME} ne $name && IsDisabled ($dh->{NAME}) != 1) {
			return 4 if ($dev_hash->{host} eq $dh->{host} && exists ($dh->{rpcport}) &&
				$dh->{rpcport} == $ifport);
		}
	}
	
	# Detect local IP address and check if CCU is reachable
	my $localaddr = HMCCU_TCPConnect ($dev_hash->{host}, $ifport);
	return 5 if ($localaddr eq '');
	$dev_hash->{hmccu}{localaddr} = $localaddr;
	$dev_hash->{hmccu}{defaultaddr} = $dev_hash->{hmccu}{localaddr};

	# Get unique ID for RPC server: last 2 segments of local IP address
	# Do not append random digits because of https://forum.fhem.de/index.php/topic,83544.msg797146.html#msg797146
	my $id1 = HMCCU_GetIdFromIP ($dev_hash->{hmccu}{localaddr}, '');
	my $id2 = HMCCU_GetIdFromIP ($hmccu_hash->{ccuip}, '');
	return 3 if ($id1 eq '' || $id2 eq '');
	$dev_hash->{rpcid} = $id1.$id2;
	
	# Set I/O device and store reference for RPC device in I/O device
	my $ioname = $hmccu_hash->{NAME};
	return 2 if (!HMCCU_AssignIODevice ($dev_hash, $ioname, $ifname));

	# Store internals
	$dev_hash->{rpcport}      = $ifport;
	$dev_hash->{rpcinterface} = $ifname;
	$dev_hash->{ccuip}        = $hmccu_hash->{ccuip};
	$dev_hash->{ccutype}      = $hmccu_hash->{ccutype};
	$dev_hash->{CCUNum}       = $hmccu_hash->{CCUNum};
	$dev_hash->{ccustate}     = $hmccu_hash->{ccustate};
	
	HMCCU_Log ($dev_hash, 1, "Initialized version $HMCCURPCPROC_VERSION for interface $ifname with I/O device $ioname");

	# Set some attributes
	if ($init_done) {
		$attr{$name}{stateFormat} = "rpcstate/state";
		$attr{$name}{verbose} = 2;
	}
	
	# Read RPC device descriptions
	if ($dev_hash->{rpcinterface} ne 'CUxD') {
		HMCCU_Log ($dev_hash, 1, "Updating internal device tables");
		HMCCU_ResetDeviceTables ($hmccu_hash, $dev_hash->{rpcinterface});
		my $cd = HMCCURPCPROC_GetDeviceDesc ($dev_hash);
		my $cm = HMCCURPCPROC_GetParamsetDesc ($dev_hash);
		HMCCU_Log ($dev_hash, 1, "Read $cd channel and device descriptions and $cm device models from CCU");
	}
	
	# RPC device ready
	HMCCURPCPROC_ResetRPCState ($dev_hash);
	HMCCURPCPROC_SetState ($dev_hash, 'Initialized');
	
	return 0;
}

######################################################################
# Delete device
######################################################################

sub HMCCURPCPROC_Undef ($$)
{
	my ($hash, $arg) = @_;
	my $name = $hash->{NAME};
	my $hmccu_hash = $hash->{IODev};
	my $ifname = $hash->{rpcinterface};

	# Shutdown RPC server
	HMCCURPCPROC_StopRPCServer ($hash, $HMCCURPCPROC_INIT_INTERVAL2);

	# Delete RPC device name in I/O device
	if (exists ($hmccu_hash->{hmccu}{interfaces}{$ifname}) &&
		exists ($hmccu_hash->{hmccu}{interfaces}{$ifname}{device}) &&
		$hmccu_hash->{hmccu}{interfaces}{$ifname}{device} eq $name) {
		delete $hmccu_hash->{hmccu}{interfaces}{$ifname}{device};
	}
	
	return undef;
}

######################################################################
# Delayed shutdown FHEM
######################################################################

sub HMCCURPCPROC_DelayedShutdown ($)
{
	my ($hash) = @_;
	my $hmccu_hash = $hash->{IODev};
	my $ifname = $hash->{rpcinterface};
	
	my $delay = max (AttrVal ("global", "maxShutdownDelay", 10)-2, 0);

	# Shutdown RPC server
	if (defined ($hmccu_hash) && exists ($hmccu_hash->{hmccu}{interfaces}{$ifname}{manager}) &&
		$hmccu_hash->{hmccu}{interfaces}{$ifname}{manager} eq 'HMCCURPCPROC') {
		if (!exists ($hash->{hmccu}{delayedShutdown})) {
			$hash->{hmccu}{delayedShutdown} = $delay;
			HMCCU_Log ($hash, 1, "Graceful shutdown within $delay seconds");
			HMCCURPCPROC_StopRPCServer ($hash, $delay);
		}
		else {
			HMCCU_Log ($hash, 1, "Graceful shutdown already in progress");
		}
	}
		
	return 1;
}

######################################################################
# Shutdown FHEM
######################################################################

sub HMCCURPCPROC_Shutdown ($)
{
	my ($hash) = @_;
	my $hmccu_hash = $hash->{IODev};
	my $ifname = $hash->{rpcinterface};

	# Shutdown RPC server
	if (defined ($hmccu_hash) && exists ($hmccu_hash->{hmccu}{interfaces}{$ifname}{manager}) &&
		$hmccu_hash->{hmccu}{interfaces}{$ifname}{manager} eq 'HMCCURPCPROC') {
		if (!exists ($hash->{hmccu}{delayedShutdown})) {
			HMCCU_Log ($hash, 1, "Immediate shutdown");
			HMCCURPCPROC_StopRPCServer ($hash, 0);
		}
		else {
			HMCCU_Log ($hash, 1, "Graceful shutdown");
		}
	}
	
	# Remove all internal timers
	RemoveInternalTimer ($hash);

	return undef;
}

######################################################################
# Set attribute
######################################################################

sub HMCCURPCPROC_Attr ($@)
{
	my ($cmd, $name, $attrname, $attrval) = @_;
	my $hash = $defs{$name};
	
	if ($cmd eq 'set') {
		if (($attrname eq 'rpcAcceptTimeout' || $attrname eq 'rpcMaxEvents') && $attrval == 0) {
			return "HMCCURPCPROC: [$name] Value for attribute $attrname must be greater than 0";
		}
		elsif ($attrname eq 'rpcServerAddr') {
			$hash->{hmccu}{localaddr} = $attrval;
		}
		elsif ($attrname eq 'rpcPingCCU') {
			HMCCU_Log ($hash, 1, "Attribute rpcPingCCU ignored. Please set it in I/O device");
		}
		elsif ($attrname eq 'ccuflags' && $attrval =~ /reconnect/) {
			HMCCU_Log ($hash, 1, "Flag reconnect ignored. Please set it in I/O device");
		}
		elsif ($attrname eq 'ccuflags' && $attrval =~ /logPong/) {
			HMCCU_Log ($hash, 1, "Flag logPong ignored. Please set it in I/O device");
		}
	}
	elsif ($cmd eq 'del') {
		if ($attrname eq 'rpcServerAddr') {
			$hash->{hmccu}{localaddr} = $hash->{hmccu}{defaultaddr};
		}
	}
	
	return undef;
}

######################################################################
# Set commands
######################################################################

sub HMCCURPCPROC_Set ($@)
{
	my ($hash, $a, $h) = @_;
	my $hmccu_hash = $hash->{IODev};
	my $name = shift @$a;
	my $opt = shift @$a;

	return "No set command specified" if (!defined ($opt));

	my $ccuflags = AttrVal ($name, 'ccuflags', 'null');
	my $options = $ccuflags =~ /expert/ ?
		"cleanup:noArg deregister:noArg register:noArg rpcrequest rpcserver:on,off" : "";
	my $busyoptions = $ccuflags =~ /expert/ ? "rpcserver:off" : "";

	return "HMCCURPCPROC: CCU busy, choose one of $busyoptions"
		if ($opt ne 'rpcserver' && HMCCURPCPROC_IsRPCStateBlocking ($hash));

	if ($opt eq 'cleanup') {
		HMCCURPCPROC_Housekeeping ($hash);
		return undef;
	}
	elsif ($opt eq 'register') {
		if ($hash->{RPCState} eq 'running') {
			my ($rc, $rcmsg) = HMCCURPCPROC_RegisterCallback ($hash, 2);
			if ($rc) {
				$hash->{ccustate} = 'active';
				return HMCCURPCPROC_SetState ($hash, "OK");
			}
			else {
				return HMCCURPCPROC_SetError ($hash, $rcmsg, 2);
			}
		}
		else {
			return HMCCURPCPROC_SetError ($hash, "RPC server not running", 2);
		}
	}
	elsif ($opt eq 'deregister') {
		my ($rc, $err) = HMCCURPCPROC_DeRegisterCallback ($hash, 1);
		return HMCCURPCPROC_SetError ($hash, $err, 2) if (!$rc);
		return HMCCURPCPROC_SetState ($hash, "OK");
	}
	elsif ($opt eq 'rpcrequest') {
		my $request = shift @$a;
		return HMCCURPCPROC_SetError ($hash, "Usage: set $name rpcrequest {request} [{parameter} ...]", 2)
			if (!defined ($request));

		my $response = HMCCURPCPROC_SendRequest ($hash, $request, @$a);
		return HMCCURPCPROC_SetError ($hash, "RPC request failed", 2) if (!defined ($response));
		return HMCCU_RefToString ($response);
	}
	elsif ($opt eq 'rpcserver') {
		my $action = shift @$a;

		return HMCCURPCPROC_SetError ($hash, "Usage: set $name rpcserver {on|off}", 2)
		   if (!defined ($action) || $action !~ /^(on|off)$/);

		if ($action eq 'on') {
			return HMCCURPCPROC_SetError ($hash, "RPC server already running", 2)
				if ($hash->{RPCState} ne 'inactive' && $hash->{RPCState} ne 'error');
			$hmccu_hash->{hmccu}{interfaces}{$hash->{rpcinterface}}{manager} = 'HMCCURPCPROC';
			my ($rc, $info) = HMCCURPCPROC_StartRPCServer ($hash);
			if (!$rc) {
				HMCCURPCPROC_SetRPCState ($hash, 'error', undef, undef);
				return HMCCURPCPROC_SetError ($hash, $info, 1);
			}
		}
		elsif ($action eq 'off') {
			$hmccu_hash->{hmccu}{interfaces}{$hash->{rpcinterface}}{manager} = 'HMCCURPCPROC';
			HMCCURPCPROC_StopRPCServer ($hash, $HMCCURPCPROC_INIT_INTERVAL2);
		}
		
		return undef;
	}
	else {
		return "HMCCURPCPROC: Unknown argument $opt, choose one of ".$options;
	}
}

######################################################################
# Get commands
######################################################################

sub HMCCURPCPROC_Get ($@)
{
	my ($hash, $a, $h) = @_;
	my $ioHash = $hash->{IODev};
	my $name = shift @$a;
	my $opt = shift @$a;

	return "No get command specified" if (!defined ($opt));

	my $ccuflags = AttrVal ($name, 'ccuflags', 'null');
	my $options = "deviceDesc rpcevents:noArg rpcstate:noArg";

	return "HMCCURPCPROC: CCU busy, choose one of rpcstate:noArg"
		if ($opt ne 'rpcstate' && HMCCURPCPROC_IsRPCStateBlocking ($hash));

	my $result = 'Command not implemented';
	my $rc;

	if ($opt eq 'deviceDesc') {
		my $address = shift @$a;
		HMCCU_ResetDeviceTables ($ioHash, $hash->{rpcinterface});
		my $cd = HMCCURPCPROC_GetDeviceDesc ($hash, $address);
		my $cm = HMCCURPCPROC_GetParamsetDesc ($hash, $address);
		return "Read $cd channel and device descriptions and $cm device models from CCU";
	}
	elsif ($opt eq 'rpcevents') {
		my @eventtypes = ("EV", "ND", "DD", "RD", "RA", "UD", "IN", "EX", "SL", "TO");
		my $clkey = 'CB'.$hash->{rpcport}.$hash->{rpcid};

		$result = "Event statistics for server $clkey\n";
		$result .= "Average event delay = ".$hash->{hmccu}{rpc}{avgdelay}."\n"
			if (defined ($hash->{hmccu}{rpc}{avgdelay}));
		$result .= "========================================\n";
		$result .= "ET Sent by RPC server   Received by FHEM\n";
		$result .= "----------------------------------------\n";
		foreach my $et (@eventtypes) {
			my $snd = exists ($hash->{hmccu}{rpc}{snd}{$et}) ?
				sprintf ("%7d", $hash->{hmccu}{rpc}{snd}{$et}) : "    n/a"; 
			my $rec = exists ($hash->{hmccu}{rpc}{rec}{$et}) ?
				sprintf ("%7d", $hash->{hmccu}{rpc}{rec}{$et}) : "    n/a"; 
			$result .= "$et            $snd            $rec\n\n";
		}
		if ($ccuflags =~ /statistics/ && exists ($hash->{hmccu}{stats}{rcv})) {
			my $eh = HMCCU_MaxHashEntries ($hash->{hmccu}{stats}{rcv}, 3);
			$result .= "========================================\n";
			$result .= "Top Sender\n";
			$result .= "========================================\n";
			for (my $i=0; $i<3; $i++) {
				last if (!exists ($eh->{$i}));
				my $dn = HMCCU_GetDeviceName ($ioHash, $eh->{$i}{k}, '?');
				$result .= "$eh->{$i}{k} / $dn : $eh->{$i}{v}\n";
			}
		}
		return $result eq '' ? "No event statistics found" : $result;
	}
	elsif ($opt eq 'rpcstate') {
		my $clkey = 'CB'.$hash->{rpcport}.$hash->{rpcid};
		$result = "PID   RPC-Process        State   \n";
		$result .= "--------------------------------\n";
		my $sid = defined ($hash->{hmccu}{rpc}{pid}) ? sprintf ("%5d", $hash->{hmccu}{rpc}{pid}) : "N/A  ";
		my $sname = sprintf ("%-10s", $clkey);
		my $cbport = defined ($hash->{hmccu}{rpc}{cbport}) ? $hash->{hmccu}{rpc}{cbport} : "N/A";
		my $addr = defined ($hash->{hmccu}{localaddr}) ? $hash->{hmccu}{localaddr} : "N/A";
		$result .= $sid." ".$sname."      ".$hash->{hmccu}{rpc}{state}."\n\n";
		$result .= "Local address = $addr\n";
		$result .= "Callback port = $cbport\n";
		return $result;
	}
	else {
		return "HMCCURPCPROC: Unknown argument $opt, choose one of ".$options;
	}
}

######################################################################
# Read data from processes
######################################################################

sub HMCCURPCPROC_Read ($)
{
	my ($hash) = @_;
	my $name = $hash->{NAME};
	my $hmccu_hash = $hash->{IODev};
	
	my $eventcount = 0;	# Total number of events
	my $devcount = 0;		# Number of DD, ND or RD events
	my $evcount = 0;		# Number of EV events
	my %events = ();
	my %devices = ();
	
	HMCCU_Log ($hash, 4, "Read called");

	# Check if child socket exists
	if (!defined ($hash->{hmccu}{sockchild})) {
		HMCCU_Log ($hash, 2, "Child socket does not exist");
		return;
	}
	
	# Get attributes
	my $rpcmaxevents = AttrVal ($name, 'rpcMaxEvents', $HMCCURPCPROC_MAX_EVENTS);
	my $ccuflags     = AttrVal ($name, 'ccuflags', 'null');
	my $hmccuflags   = AttrVal ($hmccu_hash->{NAME}, 'ccuflags', 'null');
	my $socktimeout  = AttrVal ($name, 'rpcWriteTimeout',  $HMCCURPCPROC_TIMEOUT_WRITE);
	
	# Read events from queue
	while (1) {
		my ($item, $err) = HMCCURPCPROC_ReceiveData ($hash->{hmccu}{sockchild}, $socktimeout);
		if (!defined ($item)) {
			HMCCU_Log ($hash, 4, "Read stopped after $eventcount events $err");
			last;
		}
		
		HMCCU_Log ($hash, 4, "read $item from queue") if ($ccuflags =~ /logEvents/);
		my ($et, $clkey, @par) = HMCCURPCPROC_ProcessEvent ($hash, $item);
		next if (!defined ($et));
		
		if ($et eq 'EV') {
			$events{$par[0]}{$par[1]}{$par[2]} = $par[3];
			$evcount++;
			$hash->{ccustate} = 'active' if ($hash->{ccustate} ne 'active');
			
			# Count events per device for statistics
			if ($ccuflags =~ /statistics/) {
				if (exists ($hash->{hmccu}{stats}{rcv}{$par[0]})) {
					$hash->{hmccu}{stats}{rcv}{$par[0]}++;
				}
				else {
					$hash->{hmccu}{stats}{rcv}{$par[0]} = 1;
				}
			}
		}
		elsif ($et eq 'EX') {
			# I/O already cleaned up. Leave Read()
			last;
		}
# 		elsif ($et eq 'ND') {
# 			$devices{$par[0]}{flag}      = 'N';
# 			$devices{$par[0]}{version}   = $par[3];
# 			$devices{$par[0]}{paramsets} = $par[6];
# 			if ($par[1] eq 'D') {
# 				$devices{$par[0]}{addtype}  = 'dev';
# 				$devices{$par[0]}{type}     = $par[2];
# 				$devices{$par[0]}{firmware} = $par[4];
# 				$devices{$par[0]}{rxmode}   = $par[5];
# 				$devices{$par[0]}{children} = $par[10];
# 			}
# 			else {
# 				$devices{$par[0]}{addtype}      = 'chn';
# 				$devices{$par[0]}{usetype}      = $par[2];
# 				$devices{$par[0]}{sourceroles}  = $par[7];
# 				$devices{$par[0]}{targetroles}  = $par[8];
# 				$devices{$par[0]}{direction}    = $par[9];
# 				$devices{$par[0]}{parent}       = $par[11];
# 				$devices{$par[0]}{aes}          = $par[12];
# 			}
# 			$devcount++;
# 		}
		elsif ($et eq 'DD') {
			$devices{$par[0]}{flag} = 'D';
			$devcount++;
		}
		elsif ($et eq 'RD') {
			$devices{$par[0]}{flag} = 'R';
			$devices{$par[0]}{newaddr} = $par[1];			
			$devcount++;
		}
		
		$eventcount++;
		if ($eventcount > $rpcmaxevents) {
			HMCCU_Log ($hash, 4, "Read stopped after $rpcmaxevents events");
			last;
		}
	}

	# Update device table and client device readings
	HMCCU_UpdateDeviceTable ($hmccu_hash, \%devices) if ($devcount > 0);
	HMCCU_UpdateMultipleDevices ($hmccu_hash, \%events)
		if ($evcount > 0 && $ccuflags !~ /noEvents/ && $hmccuflags !~ /noEvents/);
	
	HMCCU_Log ($hash, 4, "Read finished");
}

######################################################################
# Set error state and write log file message
# Parameter level is optional. Default value for level is 1.
######################################################################

sub HMCCURPCPROC_SetError ($$$)
{
	my ($hash, $text, $level) = @_;
	my $msg = defined ($text) ? $text : "unknown error";

	HMCCURPCPROC_SetState ($hash, "error");
	HMCCU_Log ($hash, (defined($level) ? $level : 1), $msg);
	
	return $msg;
}

######################################################################
# Set state of device
######################################################################

sub HMCCURPCPROC_SetState ($$)
{
	my ($hash, $state) = @_;
	
	if (defined ($state)) {
		readingsSingleUpdate ($hash, "state", $state, 1);
		HMCCU_Log ($hash, 4, "Set state to $state");
	}

	return undef;
}

######################################################################
# Set state of RPC server
# Parameters msg and level are optional. Default for level is 1.
######################################################################

sub HMCCURPCPROC_SetRPCState ($$$$)
{
	my ($hash, $state, $msg, $level) = @_;
	my $name = $hash->{NAME};
	my $hmccu_hash = $hash->{IODev};
	
	return undef if (exists ($hash->{RPCState}) && $hash->{RPCState} eq $state);

	$hash->{hmccu}{rpc}{state} = $state;
	$hash->{RPCState} = $state;
	
	readingsSingleUpdate ($hash, "rpcstate", $state, 1);
	
	HMCCURPCPROC_SetState ($hash, 'busy') if ($state ne 'running' && $state ne 'inactive' &&
		$state ne 'error' && ReadingsVal ($name, 'state', '') ne 'busy');
		 
	HMCCU_Log ($hash, (defined($level) ? $level : 1), $msg) if (defined ($msg));
	HMCCU_Log ($hash, 4, "Set rpcstate to $state");
	
	# Set state of interface in I/O device
	HMCCU_SetRPCState ($hmccu_hash, $state, $hash->{rpcinterface});
	
	return undef;
}

######################################################################
# Reset RPC State
######################################################################

sub HMCCURPCPROC_ResetRPCState ($)
{
	my ($hash) = @_;

	HMCCU_Log ($hash, 4, "Reset RPC state");
	
	$hash->{RPCPID} = "0";
	$hash->{hmccu}{rpc}{pid} = undef;
	$hash->{hmccu}{rpc}{clkey} = undef;
	$hash->{hmccu}{evtime} = 0;
	$hash->{hmccu}{rpcstarttime} = 0;

	return HMCCURPCPROC_SetRPCState ($hash, 'inactive', undef, undef);
}

######################################################################
# Check if CCU is busy due to RPC start or stop
######################################################################

sub HMCCURPCPROC_IsRPCStateBlocking ($)
{
	my ($hash) = @_;

	return (exists ($hash->{RPCState}) &&
		($hash->{RPCState} eq "running" || $hash->{RPCState} eq "inactive")) ? 0 : 1;
}

######################################################################
# Process RPC server event
######################################################################

sub HMCCURPCPROC_ProcessEvent ($$)
{
	my ($hash, $event) = @_;
	my $name = $hash->{NAME};
	my $rpcname = 'CB'.$hash->{rpcport}.$hash->{rpcid};
	my $rh = \%{$hash->{hmccu}{rpc}};	# Just for code simplification
	my $hmccu_hash = $hash->{IODev};
	my ($defInterface, $defPort) = HMCCU_GetDefaultInterface ($hmccu_hash);

	# Number of arguments in RPC events (without event type and clkey)
	my %rpceventargs = (
		"EV", 4,
		"ND", 13,
		"DD", 1,
		"RD", 2,
		"RA", 1,
		"UD", 2,
		"IN", 2,
		"EX", 2,
		"SL", 1,
		"TO", 1,
		"ST", 11
	);

	my $ccuflags = AttrVal ($name, 'ccuflags', 'null');
	my $ping = AttrVal ($hmccu_hash->{NAME}, 'rpcPingCCU', $HMCCURPCPROC_TIME_PING);
	my $evttimeout = ($ping > 0 && $hash->{rpcinterface} eq $defInterface) ? $ping*2 :
	   HMCCURPCPROC_GetAttribute ($hash, 'rpcEventTimeout', 'rpcevtimeout', $HMCCURPCPROC_TIMEOUT_EVENT);
	                    
	return undef if (!defined ($event) || $event eq '');

	# Log event
	HMCCU_Log ($hash, 2, "CCUEvent = $event") if ($ccuflags =~ /logEvents/);

	# Detect event type and clkey
	my ($et, $clkey, $evdata) = split (/\|/, $event, 3);
	if (!defined ($evdata)) {
		HMCCU_Log ($hash, 2, "Syntax error in RPC event data $event");
		return undef;
	}

	# Check for valid server
	if ($clkey ne $rpcname) {
		HMCCU_Log ($hash, 2, "Received $et event for unknown RPC server $clkey");
		return undef;
	}

	# Check event type
	if (!exists ($rpceventargs{$et})) {
		$et =~ s/([\x00-\xFF])/sprintf("0x%X ",ord($1))/eg;
		HMCCU_Log ($hash, 2, "Received unknown event from CCU: ".$et);
		return undef;
	}

	# Parse event
	my @t = split (/\|/, $evdata, $rpceventargs{$et});
	my $tc = scalar (@t);
	
	# Check event parameters
	if ($tc != $rpceventargs{$et}) {
		HMCCU_Log ($hash, 2, "Wrong number of $tc parameters in event $event. Expected ". 
			$rpceventargs{$et});
		return undef;
	}

	# Update statistic counters
	$rh->{rec}{$et}++;
	$rh->{evtime} = time ();
	
	if ($et eq 'EV') {
		#
		# Update of datapoint
		# Input:  EV|clkey|Time|Address|Datapoint|Value
		# Output: EV, clkey, DevAdd, ChnNo, Datapoint, Value
		#
		my $delay = $rh->{evtime}-$t[0];
		$rh->{sumdelay} += $delay;
		$rh->{avgdelay} = $rh->{sumdelay}/$rh->{rec}{$et};
		$hash->{ccustate} = 'active' if ($hash->{ccustate} ne 'active');
		HMCCU_Log ($hash, 3, "Received CENTRAL event from $clkey. ".$t[2]."=".$t[3])
			if ($t[1] eq 'CENTRAL' && $t[3] eq $rpcname && HMCCU_IsFlag ($hmccu_hash->{NAME}, 'logPong'));
		my ($add, $chn) = split (/:/, $t[1]);
		return defined ($chn) ? ($et, $clkey, $add, $chn, @t[2,3]) : undef;
	}
	elsif ($et eq 'SL') {
		#
		# RPC server enters server loop
		# Input:  SL|clkey|Pid
		# Output: SL, clkey, countWorking
		#
		if ($t[0] == $rh->{pid}) {
			HMCCURPCPROC_SetRPCState ($hash, 'working', "RPC server $clkey enters server loop", 2);
			my ($rc, $rcmsg) = HMCCURPCPROC_RegisterCallback ($hash, 0);
			if (!$rc) {
				HMCCURPCPROC_SetRPCState ($hash, 'error', $rcmsg, 1);
				return ($et, $clkey, 1, 0, 0, 0);
			}
			else {
				HMCCURPCPROC_SetRPCState ($hash, $rcmsg, "RPC server $clkey $rcmsg", 1);
			}
			my $srun = HMCCURPCPROC_RPCServerStarted ($hash);
			return ($et, $clkey, ($srun == 0 ? 1 : 0), $srun);
		}
		else {
			HMCCU_Log ($hash, 0, "Received SL event. Wrong PID=".$t[0]." for RPC server $clkey");
			return undef;
		}
	}
	elsif ($et eq 'IN') {
		#
		# RPC server initialized
		# Input:  IN|clkey|INIT|State
		# Output: IN, clkey, Running, ClientsUpdated, UpdateErrors
		#
		return ($et, $clkey, 0, 0, 0) if ($rh->{state} eq 'running');
		
		HMCCURPCPROC_SetRPCState ($hash, 'running', "RPC server $clkey running.", 1);
		my $run = HMCCURPCPROC_RPCServerStarted ($hash);
		return ($et, $clkey, $run);
	}
	elsif ($et eq 'EX') {
		#
		# Process stopped
		# Input:  EX|clkey|SHUTDOWN|Pid
		# Output: EX, clkey, Pid, Stopped, All
		#
		HMCCURPCPROC_SetRPCState ($hash, 'inactive', "RPC server process $clkey terminated.", 1);
		HMCCURPCPROC_RPCServerStopped ($hash);
		return ($et, $clkey, $t[1], 1, 1);
	}
	elsif ($et eq 'ND') {
		#
		# CCU device added
		# Input:  ND|clkey|C/D|Address|Type|Version|Firmware|RxMode|Paramsets|
		#         LinkSourceRoles|LinkTargetRoles|Direction|Children|Parent|AESActive
		# Output: ND, clkey, DevAdd, C/D, Type, Version, Firmware, RxMode, Paramsets,
		#         LinkSourceRoles, LinkTargetRoles, Direction, Children, Parent, AESActive
		#
		return ($et, $clkey, @t[1,0,2..12]);
	}
	elsif ($et eq 'DD' || $et eq 'RA') {
		#
		# CCU device deleted or readded
		# Input:  {DD,RA}|clkey|Address
		# Output: {DD,RA}, clkey, DevAdd
		#
		return ($et, $clkey, $t[0]);
	}
	elsif ($et eq 'UD') {
		#
		# CCU device updated
		# Input:  UD|clkey|Address|Hint
		# Output: UD, clkey, DevAdd, Hint
		#
		return ($et, $clkey, @t[0,1]);
	}
	elsif ($et eq 'RD') {
		#
		# CCU device replaced
		# Input:  RD|clkey|Address1|Address2
		# Output: RD, clkey, Address1, Address2
		#
		return ($et, $clkey, @t[0,1]);
	}
	elsif ($et eq 'ST') {
		#
		# Statistic data. Store snapshots of sent events.
		# Input:  ST|clkey|nTotal|nEV|nND|nDD|nRD|nRA|nUD|nIN|nEX|nSL
		# Output: ST, clkey, ...
		#
		my @res = ($et, $clkey);
		push (@res, @t);
		my $total = shift @t;
		my @eventtypes = ("EV", "ND", "DD", "RD", "RA", "UD", "IN", "EX", "SL", "TO");
		for (my $i=0; $i<scalar(@eventtypes); $i++) {
			$hash->{hmccu}{rpc}{snd}{$eventtypes[$i]} += $t[$i];
		}
		return @res;
	}
	elsif ($et eq 'TO') {
		#
		# Event timeout
		# Input:  TO|clkey|DiffTime
		# Output: TO, clkey, Port, DiffTime
		#
		if ($evttimeout > 0) {
			HMCCU_Log ($hash, 2, "Received no events from interface $clkey for ".$t[0]." seconds");
			$hash->{ccustate} = 'timeout';
			if ($hash->{RPCState} eq 'running' && $hash->{rpcport} == $defPort) {
				# If interface is default interface inform IO device about timeout
				HMCCU_EventsTimedOut ($hmccu_hash)
			}
			DoTrigger ($name, "No events from interface $clkey for ".$t[0]." seconds");
		}
		return ($et, $clkey, $hash->{rpcport}, $t[0]);
	}

	return undef;
}

######################################################################
# Get attribute with fallback to I/O device attribute
######################################################################

sub HMCCURPCPROC_GetAttribute ($$$$)
{
	my ($hash, $attr, $ioattr, $default) = @_;
	my $name = $hash->{NAME};
	my $hmccu_hash = $hash->{IODev};
	my $value = 'null';
	
	if (defined ($attr)) {
		$value = AttrVal ($name, $attr, 'null');
		return $value if ($value ne 'null');
	}
	
	if (defined ($ioattr)) {
		$value = AttrVal ($hmccu_hash->{NAME}, $ioattr, 'null');
		return $value if ($value ne 'null');
	}
	
	return $default;
}

######################################################################
# Get RPC device descriptions from CCU
# Return number of devices and channels read from CCU.
######################################################################

sub HMCCURPCPROC_GetDeviceDesc ($;$)
{
	my ($hash, $address) = @_;
	my $ioHash = $hash->{IODev};
	
	my $rd;
	my $c = 0;
	
	if (!defined($address)) {
		# All devices
		$rd = HMCCURPCPROC_SendRequest ($hash, "listDevices");
	}
	else {
		# Single device (or channel)
		$rd = HMCCURPCPROC_SendRequest ($hash, "getDeviceDescription", $address);
	}
	
	return HMCCU_Log ($hash, 2, "Can't get device description", 0) if (!defined($rd));

	if (ref($rd) eq 'HASH') {
		return HMCCU_Log ($hash, 2, "Can't get device description. ".$rd->{faultString}, 0)
			if (exists($rd->{faultString}));
			
		if (HMCCU_AddDeviceDesc ($ioHash, $rd, 'ADDRESS', $hash->{rpcinterface})) {
			$c = 1;
			if (defined($rd->{CHILDREN}) && ref($rd->{CHILDREN}) eq 'ARRAY') {
				foreach my $child (@{$rd->{CHILDREN}}) {
					$c += HMCCURPCPROC_GetDeviceDesc ($hash, $child);
				}
			}
		}
	}
	elsif (ref($rd) eq 'ARRAY') {
		foreach my $dev (@$rd) {
			$c++ if (HMCCU_AddDeviceDesc ($ioHash, $dev, 'ADDRESS', $hash->{rpcinterface}));
		}
	}

	return $c;
}

######################################################################
# Get RPC device paramset descriptions from CCU
# Parameters:
#   $address - Device or channel address. If not specified, all
#     addresses known by IO device are used. 
# Return number of devices read from CCU.
######################################################################

sub HMCCURPCPROC_GetParamsetDesc ($;$)
{
	my ($hash, $address) = @_;
	my $ioHash = $hash->{IODev};

	my $c = 0;
	
	if (defined($address)) {
		my $devDesc = HMCCU_GetDeviceDesc ($ioHash, $hash->{rpcinterface}, $address);
		return 0 if (!defined($devDesc) || !defined($devDesc->{PARAMSETS}) || $devDesc->{PARAMSETS} eq '' ||
			!exists($devDesc->{_fw_ver}));
		
		my $chnNo = ($devDesc->{_addtype} eq 'chn') ? $devDesc->{INDEX} : 'd';

		# Check if model already exists
		return 0 if (HMCCU_ExistsDeviceModel ($ioHash, $devDesc->{_model}, $devDesc->{_fw_ver}, $chnNo));
		
		# Read all paramset definitions
		foreach my $ps (split (',', $devDesc->{PARAMSETS})) {
			my $rm = HMCCURPCPROC_SendRequest ($hash, "getParamsetDescription", $address, $ps);
			if (defined($rm) && ref($rm) eq 'HASH' && !exists($rm->{faultString})) {
				HMCCU_AddDeviceModel ($ioHash, $rm, $devDesc->{_model}, $devDesc->{_fw_ver}, $ps, $chnNo);
			}
			else {
				HMCCU_Log ($hash, 2, "Can't get description of paramset $ps for address $a");
			}
		}
		
		$c = 1;
		
		# Read paramset definitions of childs
		if (defined($devDesc->{CHILDREN}) && $devDesc->{CHILDREN} ne '') {
			foreach my $child (split (',', $devDesc->{CHILDREN})) {
				$c += HMCCURPCPROC_GetParamsetDesc ($hash, $child);
			}
		}
	}
	else {
		foreach my $a (HMCCU_GetDeviceAddresses ($ioHash, $hash->{rpcinterface}, "_addtype=dev")) {
			$c += HMCCURPCPROC_GetParamsetDesc ($hash, $a);
		}
	}

	return $c;
}

######################################################################
# Register callback for specified CCU interface port.
# Parameter force:
# 1: callback will be registered even if state is "running". State
#    will not be modified.
# 2: CCU connectivity is checked before registering RPC server.
# Return (1, new state) on success. New state is 'running' if flag
# ccuInit is not set. Otherwise 'registered'.
# Return (0, errormessage) on error.
######################################################################

sub HMCCURPCPROC_RegisterCallback ($$)
{
	my ($hash, $force) = @_;
	my $name = $hash->{NAME};
	my $hmccu_hash = $hash->{IODev};
	
	my $ccuflags = AttrVal ($name, 'ccuflags', 'null');

	my $port = $hash->{rpcport};
	my $serveraddr = $hash->{host};
	my $localaddr = $hash->{hmccu}{localaddr};
	my $clkey = 'CB'.$port.$hash->{rpcid};
	
	return (0, "RPC server $clkey not in state working")
		if ($hash->{hmccu}{rpc}{state} ne 'working' && $force == 0);

	if ($force == 2) {
		return (0, "CCU port $port not reachable") if (!HMCCU_TCPConnect ($hash->{host}, $port));
	}

	my $cburl = HMCCU_GetRPCCallbackURL ($hmccu_hash, $localaddr, $hash->{hmccu}{rpc}{cbport}, $clkey, $port);
	my $clurl = HMCCU_BuildURL ($hmccu_hash, $port);
	my ($rpctype) = HMCCU_GetRPCServerInfo ($hmccu_hash, $port, 'type');
	return (0, "Can't get RPC parameters for ID $clkey") if (!defined ($cburl) || !defined ($clurl) || !defined ($rpctype));
	
	$hash->{hmccu}{rpc}{port} = $port;
	$hash->{hmccu}{rpc}{clurl} = $clurl;
	$hash->{hmccu}{rpc}{cburl} = $cburl;

	HMCCU_Log ($hash, 2, "Registering callback $cburl of type $rpctype with ID $clkey at $clurl");
	my $rc = HMCCURPCPROC_SendRequest ($hash, "init", "$cburl:STRING", "$clkey:STRING");

	if (defined ($rc)) {
		return (1, $ccuflags !~ /ccuInit/ ? 'running' : 'registered');
	}
	else {
		return (0, "Failed to register callback for ID $clkey");
	}
}

######################################################################
# Deregister RPC callbacks at CCU
######################################################################

sub HMCCURPCPROC_DeRegisterCallback ($$)
{
	my ($hash, $force) = @_;
	my $name = $hash->{NAME};
	my $hmccu_hash = $hash->{IODev};
	
	my $port = $hash->{rpcport};
	my $clkey = 'CB'.$port.$hash->{rpcid};
	my $localaddr = $hash->{hmccu}{localaddr};
	my $cburl = '';
	my $clurl = '';
	my $rpchash = \%{$hash->{hmccu}{rpc}};

	return (0, "RPC server $clkey not in state registered or running")
		if ($rpchash->{state} ne 'registered' && $rpchash->{state} ne 'running' && $force == 0);

	$cburl = $rpchash->{cburl} if (exists ($rpchash->{cburl}));
	$clurl = $rpchash->{clurl} if (exists ($rpchash->{clurl}));
	$cburl = HMCCU_GetRPCCallbackURL ($hmccu_hash, $localaddr, $rpchash->{cbport}, $clkey, $port) if ($cburl eq '');
	$clurl = HMCCU_BuildURL ($hmccu_hash, $port) if ($clurl eq '');
	return (0, "Can't get RPC parameters for ID $clkey") if ($cburl eq '' || $clurl eq '');

	HMCCU_Log ($hash, 1, "Deregistering RPC server $cburl with ID $clkey at $clurl");
	
	# Deregister up to 2 times
	for (my $i=0; $i<2; $i++) {
		my $rc = HMCCURPCPROC_SendRequest ($hash, "init", "$cburl:STRING");

		if (defined ($rc)) {
			HMCCURPCPROC_SetRPCState ($hash, $force == 0 ? 'deregistered' : $rpchash->{state},
				"Callback for RPC server $clkey deregistered", 1);

			$rpchash->{cburl} = '';
			$rpchash->{clurl} = '';
			$rpchash->{cbport} = 0;
		
			return (1, 'working');
		}
	}
	
	return (0, "Failed to deregister RPC server $clkey");
}

######################################################################
# Initialize RPC server for specified CCU port
# Return server object or undef on error
######################################################################

sub HMCCURPCPROC_InitRPCServer ($$$$)
{
	my ($name, $clkey, $callbackport, $prot) = @_;
	my $server;

	# Create binary RPC server
	if ($prot eq 'B') {
		$server->{__daemon} = IO::Socket::INET->new (LocalPort => $callbackport,
			Type => SOCK_STREAM, Reuse => 1, Listen => SOMAXCONN);
		if (!($server->{__daemon})) {
			HMCCU_Log ($name, 1, "Can't create RPC callback server $clkey on port $callbackport. Port in use?");
			return undef;
		}
		return $server;
	}
	
	# Create XML RPC server
	$server = RPC::XML::Server->new (port => $callbackport);
	if (!ref($server)) {
		HMCCU_Log ($name, 1, "Can't create RPC callback server $clkey on port $callbackport. Port in use?");
		return undef;
	}
	HMCCU_Log ($name, 2, "Callback server $clkey created. Listening on port $callbackport");

	# Callback for events
	HMCCU_Log ($name, 4, "Adding callback for events for server $clkey");
	$server->add_method (
	   { name=>"event",
	     signature=> ["string string string string string","string string string string int",
		 "string string string string double","string string string string boolean",
		 "string string string string i4"],
	     code=>\&HMCCURPCPROC_EventCB
	   }
	);

	# Callback for new devices
	HMCCU_Log ($name, 4, "Adding callback for new devices for server $clkey");
	$server->add_method (
	   { name=>"newDevices",
	     signature=>["string string array"],
        code=>\&HMCCURPCPROC_NewDevicesCB
	   }
	);

	# Callback for deleted devices
	HMCCU_Log ($name, 4, "Adding callback for deleted devices for server $clkey");
	$server->add_method (
	   { name=>"deleteDevices",
	     signature=>["string string array"],
        code=>\&HMCCURPCPROC_DeleteDevicesCB
	   }
	);

	# Callback for modified devices
	HMCCU_Log ($name, 4, "Adding callback for modified devices for server $clkey");
	$server->add_method (
	   { name=>"updateDevice",
	     signature=>["string string string int", "string string string i4"],
	     code=>\&HMCCURPCPROC_UpdateDeviceCB
	   }
	);

	# Callback for replaced devices
	HMCCU_Log ($name, 4, "Adding callback for replaced devices for server $clkey");
	$server->add_method (
	   { name=>"replaceDevice",
	     signature=>["string string string string"],
	     code=>\&HMCCURPCPROC_ReplaceDeviceCB
	   }
	);

	# Callback for readded devices
	HMCCU_Log ($name, 4, "Adding callback for readded devices for server $clkey");
	$server->add_method (
	   { name=>"readdedDevice",
	     signature=>["string string array"],
	     code=>\&HMCCURPCPROC_ReaddDeviceCB
	   }
	);
	
	# Dummy implementation, always return an empty array
	HMCCU_Log ($name, 4, "Adding callback for list devices for server $clkey");
	$server->add_method (
	   { name=>"listDevices",
	     signature=>["array string"],
	     code=>\&HMCCURPCPROC_ListDevicesCB
	   }
	);

	return $server;
}

######################################################################
# Start RPC server process
# Return (State, Msg)
######################################################################

sub HMCCURPCPROC_StartRPCServer ($)
{
	my ($hash) = @_;
	my $name = $hash->{NAME};
	my $hmccu_hash = $hash->{IODev};
	my ($defInterface, $defPort) = HMCCU_GetDefaultInterface ($hmccu_hash);

	# Local IP address and callback ID should be set during device definition
	return (0, "Local address and/or callback ID not defined")
		if (!exists ($hash->{hmccu}{localaddr}) || !exists ($hash->{rpcid}));
		
	# Check if RPC server is already running
	return (0, "RPC server already running") if (HMCCURPCPROC_CheckProcessState ($hash, 'running'));
	
	# Get parameters and attributes
	my $ping          = AttrVal ($hmccu_hash->{NAME}, 'rpcPingCCU', $HMCCURPCPROC_TIME_PING);
	my $localaddr     = HMCCURPCPROC_GetAttribute ($hash, undef, 'rpcserveraddr', $hash->{hmccu}{localaddr});
	my $rpcserverport = HMCCURPCPROC_GetAttribute ($hash, 'rpcServerPort', 'rpcserverport', $HMCCURPCPROC_SERVER_PORT);
	my $evttimeout    = ($ping > 0 && $hash->{rpcinterface} eq $defInterface) ?
	                    $ping*2 :
	                    HMCCURPCPROC_GetAttribute ($hash, 'rpcEventTimeout', 'rpcevtimeout', $HMCCURPCPROC_TIMEOUT_EVENT);
	my $ccunum        = $hash->{CCUNum};
	my $rpcport       = $hash->{rpcport};
	my ($serveraddr, $interface) = HMCCU_GetRPCServerInfo ($hmccu_hash, $rpcport, 'host,name');
	my $clkey         = 'CB'.$rpcport.$hash->{rpcid};
	$hash->{hmccu}{localaddr} = $localaddr;

	# Store parameters for child process
	my %procpar;
	$procpar{socktimeout} = AttrVal ($name, 'rpcWriteTimeout',  $HMCCURPCPROC_TIMEOUT_WRITE);
	$procpar{conntimeout} = AttrVal ($name, 'rpcConnTimeout',   $HMCCURPCPROC_TIMEOUT_CONNECTION);
	$procpar{acctimeout}  = AttrVal ($name, 'rpcAcceptTimeout', $HMCCURPCPROC_TIMEOUT_ACCEPT);
	$procpar{queuesize}   = AttrVal ($name, 'rpcQueueSize',     $HMCCURPCPROC_MAX_QUEUESIZE);
	$procpar{queuesend}   = AttrVal ($name, 'rpcQueueSend',     $HMCCURPCPROC_MAX_QUEUESEND);
	$procpar{statistics}  = AttrVal ($name, 'rpcStatistics',    $HMCCURPCPROC_STATISTICS);
	$procpar{maxioerrors} = AttrVal ($name, 'rpcMaxIOErrors',   $HMCCURPCPROC_MAX_IOERRORS);
	$procpar{ccuflags}    = AttrVal ($name, 'ccuflags',         'null');
	$procpar{evttimeout}  = $evttimeout;
	$procpar{interface}   = $interface;
	($procpar{flags}, $procpar{type}) = HMCCU_GetRPCServerInfo ($hmccu_hash, $rpcport, 'flags,type');
	$procpar{name}        = $name;
	$procpar{clkey}       = $clkey;
	
	my @eventtypes = ("EV", "ND", "DD", "RD", "RA", "UD", "IN", "EX", "SL", "TO");

	# Reset state of server processes
	$hash->{hmccu}{rpc}{state} = 'inactive';

	# Create socket pair for communication between RPC server process and FHEM process
	my ($sockchild, $sockparent);
	return (0, "Can't create I/O socket pair")
		if (!socketpair ($sockchild, $sockparent, AF_UNIX, SOCK_STREAM, PF_UNSPEC));
	$sockchild->autoflush (1);
	$sockparent->autoflush (1);
	$hash->{hmccu}{sockparent} = $sockparent;
	$hash->{hmccu}{sockchild} = $sockchild;

	# Enable FHEM I/O
	my $pid = $$;
	$hash->{FD} = fileno $sockchild;
	$selectlist{"RPC.$name.$pid"} = $hash; 
	
	# Initialize RPC server
	my $err = '';
	my %srvprocpar;
	my $callbackport = $rpcserverport+$rpcport+($ccunum*10);

	# Start RPC server process
	my $rpcpid = fhemFork ();
	if (!defined ($rpcpid)) {
		close ($sockparent);
		close ($sockchild);
		return (0, "Can't create RPC server process for interface $interface");
	}
		
	if (!$rpcpid) {
		# Child process, only needs parent socket
		HMCCURPCPROC_HandleConnection ($rpcport, $callbackport, $sockparent, \%procpar);
		
		# Connection loop ended. Close sockets and exit child process
		close ($sockparent);
		close ($sockchild);
		exit (0);
	}

	# Parent process
	HMCCU_Log ($hash, 2, "RPC server process started for interface $interface with PID=$rpcpid");

	# Store process parameters
	$hash->{hmccu}{rpc}{clkey}  = $clkey;
	$hash->{hmccu}{rpc}{cbport} = $callbackport;
	$hash->{hmccu}{rpc}{pid}    = $rpcpid;
	$hash->{hmccu}{rpc}{state}  = 'initialized';
		
	# Reset statistic counter
	foreach my $et (@eventtypes) {
		$hash->{hmccu}{rpc}{rec}{$et} = 0;
		$hash->{hmccu}{rpc}{snd}{$et} = 0;
	}
	$hash->{hmccu}{rpc}{sumdelay} = 0;

	$hash->{RPCPID} = $rpcpid;

	# Trigger Timer function for checking successful RPC start
	# Timer will be removed before execution if event 'IN' is reveived
	InternalTimer (gettimeofday()+$HMCCURPCPROC_INIT_INTERVAL3, "HMCCURPCPROC_IsRPCServerRunning",
		$hash, 0);
	
	HMCCURPCPROC_SetRPCState ($hash, "starting", "RPC server starting", 1);	
	DoTrigger ($name, "RPC server starting");
	
	return (1, undef);
}

######################################################################
# Set overall status if all RPC servers are running and update all
# FHEM devices.
# Return (State, updated devices, failed updates)
######################################################################

sub HMCCURPCPROC_RPCServerStarted ($)
{
	my ($hash) = @_;
	my $name = $hash->{NAME};
	my $hmccu_hash = $hash->{IODev};
	my $clkey = 'CB'.$hash->{rpcport}.$hash->{rpcid};
	my $ifname = $hash->{rpcinterface};
	my $ping = AttrVal ($hmccu_hash->{NAME}, 'rpcPingCCU', $HMCCURPCPROC_TIME_PING);
	my ($defInterface, $defPort) = HMCCU_GetDefaultInterface ($hmccu_hash);
	
	# Check if RPC servers are running. Set overall status
	if (HMCCURPCPROC_CheckProcessState ($hash, 'running')) {
		$hash->{hmccu}{rpcstarttime} = time ();
		HMCCURPCPROC_SetState ($hash, "OK");

		# Update client devices if interface is managed by HMCCURPCPROC device.
		# Normally interfaces are managed by HMCCU device.
		if ($hmccu_hash->{hmccu}{interfaces}{$ifname}{manager} eq 'HMCCURPCPROC') {
			HMCCU_UpdateClients ($hmccu_hash, '.*', 'Attr', 0, $ifname, 1);
#			Log3 $name, 2, "HMCCURPCPROC: [$name] Updated devices. Success=$c_ok Failed=$c_err";
		}

		RemoveInternalTimer ($hash, "HMCCURPCPROC_IsRPCServerRunning");
		
		# Activate heartbeat if interface is default interface and rpcPingCCU > 0
		if ($ping > 0 && $ifname eq $defInterface) {
			HMCCU_Log ($hash, 1, "Scheduled CCU ping every $ping seconds", undef);
			InternalTimer (gettimeofday()+$ping, "HMCCURPCPROC_RPCPing", $hash, 0);
		}
		
		DoTrigger ($name, "RPC server $clkey running");
		return 1;
	}
	
	return 0;
}

######################################################################
# Cleanup if RPC server stopped
######################################################################

sub HMCCURPCPROC_RPCServerStopped ($)
{
	my ($hash) = @_;
	my $name = $hash->{NAME};
	my $clkey = 'CB'.$hash->{rpcport}.$hash->{rpcid};

	HMCCURPCPROC_CleanupProcess ($hash);
	HMCCURPCPROC_CleanupIO ($hash);
	
	HMCCURPCPROC_ResetRPCState ($hash);
	HMCCURPCPROC_SetState ($hash, "OK");
	
	RemoveInternalTimer ($hash);
	DoTrigger ($name, "RPC server $clkey stopped");

	# Inform FHEM that instance can be shut down
	HMCCU_Log ($hash, 2, "RPC server stopped. Cancel delayed shutdown.", undef);
	CancelDelayedShutdown ($name) if (exists ($hash->{hmccu}{delayedShutdown}));
}

######################################################################
# Stop I/O Handling
######################################################################

sub HMCCURPCPROC_CleanupIO ($)
{
	my ($hash) = @_;
	my $name = $hash->{NAME};

	my $pid = $$;
	if (exists ($selectlist{"RPC.$name.$pid"})) {
		HMCCU_Log ($hash, 2, "Stop I/O handling", undef);
		delete $selectlist{"RPC.$name.$pid"};
		delete $hash->{FD} if (defined ($hash->{FD}));
	}
	if (defined ($hash->{hmccu}{sockchild})) {
		HMCCU_Log ($hash, 3, "Close child socket", undef);
		$hash->{hmccu}{sockchild}->close ();
		delete $hash->{hmccu}{sockchild};
	}
	if (defined ($hash->{hmccu}{sockparent})) {
		HMCCU_Log ($hash, 3, "Close parent socket", undef);
		$hash->{hmccu}{sockparent}->close ();
		delete $hash->{hmccu}{sockparent};
	}
}

######################################################################
# Terminate RPC server process by sending an INT signal.
# Return 0 if RPC server not running.
######################################################################

sub HMCCURPCPROC_TerminateProcess ($)
{
	my ($hash) = @_;
	my $clkey = 'CB'.$hash->{rpcport}.$hash->{rpcid};
	
#	return 0 if ($hash->{hmccu}{rpc}{state} eq 'inactive');
	
	my $pid = $hash->{hmccu}{rpc}{pid};
	if (defined ($pid) && kill (0, $pid)) {
		HMCCURPCPROC_SetRPCState ($hash, 'stopping', "Sending signal INT to RPC server process $clkey with PID=$pid", 2);
		kill ('INT', $pid);
		return 1;
	}
	else {
		HMCCURPCPROC_SetRPCState ($hash, 'inactive', "RPC server process $clkey not runnning", 1);
		return 0;
	}
}

######################################################################
# Cleanup inactive RPC server process.
# Return 0 if process is running.
######################################################################

sub HMCCURPCPROC_CleanupProcess ($)
{
	my ($hash) = @_;
	my $clkey = 'CB'.$hash->{rpcport}.$hash->{rpcid};
	
#	return 1 if ($hash->{hmccu}{rpc}{state} eq 'inactive');
	
	my $pid = $hash->{hmccu}{rpc}{pid};
	if (defined ($pid) && kill (0, $pid)) {
		HMCCU_Log ($hash, 1, "Process $clkey with PID=$pid still running. Killing it.", undef);
		kill ('KILL', $pid);
		sleep (1);
		if (kill (0, $pid)) {
			HMCCU_Log ($hash, 1, "Can't kill process $clkey with PID=$pid", undef);
			return 0;
		}
	}
	
	HMCCURPCPROC_SetRPCState ($hash, 'inactive', "RPC server process $clkey deleted", 2);
	$hash->{hmccu}{rpc}{pid} = undef;
	
	return 1;
}

######################################################################
# Check if RPC server process is in specified state.
# Parameter state is a regular expression. Valid states are:
#   inactive
#   starting
#   working
#   registered
#   running
#   stopping
# If state is 'running' the process is checked by calling kill() with
# signal 0.
######################################################################

sub HMCCURPCPROC_CheckProcessState ($$)
{
	my ($hash, $state) = @_;
	
#	HMCCU_Log ($hash, 3, "CheckProcessState()");
	
	my $prcname = 'CB'.$hash->{rpcport}.$hash->{rpcid};

	my $pstate = $hash->{hmccu}{rpc}{state};
	if ($state eq 'running' || $state eq '.*') {
		my $pid = $hash->{hmccu}{rpc}{pid};
		return (defined ($pid) && $pid != 0 && kill (0, $pid) && $pstate =~ /$state/) ? $pid : 0
	}
	else {
		return ($pstate =~ /$state/) ? 1 : 0;
	}
}

######################################################################
# Timer function to check if RPC server process is running.
# Call Housekeeping() if process is not running.
######################################################################

sub HMCCURPCPROC_IsRPCServerRunning ($)
{
	my ($hash) = @_;
	
	HMCCU_Log ($hash, 2, "Checking if RPC server process is running", undef);
	if (!HMCCURPCPROC_CheckProcessState ($hash, 'running')) {
		HMCCU_Log ($hash, 1, "RPC server process not running. Cleaning up", undef);
		HMCCURPCPROC_Housekeeping ($hash);
		return 0;
	}

	HMCCU_Log ($hash, 2, "RPC server process running", undef);
	return 1;
}

######################################################################
# Cleanup RPC server environment.
######################################################################

sub HMCCURPCPROC_Housekeeping ($)
{
	my ($hash) = @_;

	HMCCU_Log ($hash, 1, "Housekeeping called. Cleaning up RPC environment", undef);

	# Deregister callback URLs in CCU
	HMCCURPCPROC_DeRegisterCallback ($hash, 0);

	# Terminate process by sending signal INT
	sleep (2) if (HMCCURPCPROC_TerminateProcess ($hash));
	
	# Next call will cleanup IO, processes and reset RPC state
	HMCCURPCPROC_RPCServerStopped ($hash);
}

######################################################################
# Stop RPC server processes.
# If function is called by Shutdown, parameter wait must be 0
######################################################################

sub HMCCURPCPROC_StopRPCServer ($$)
{
	my ($hash, $wait) = @_;
	my $clkey = 'CB'.$hash->{rpcport}.$hash->{rpcid};
	
	HMCCU_Log ($hash, 3, "StopRPCServer()");
	
	$wait = $HMCCURPCPROC_INIT_INTERVAL2 if (!defined ($wait));

	if (HMCCURPCPROC_CheckProcessState ($hash, 'running')) {
		HMCCU_Log ($hash, 1, "Stopping RPC server $clkey");
		HMCCURPCPROC_SetState ($hash, "busy");

		# Deregister callback URLs in CCU
		my ($rc, $err) = HMCCURPCPROC_DeRegisterCallback ($hash, 0);
		HMCCU_Log ($hash, 1, $err) if (!$rc);

		# Stop RPC server process 
 		HMCCURPCPROC_TerminateProcess ($hash);

		# Trigger timer function for checking successful RPC stop
		# Timer will be removed wenn receiving EX event from RPC server process
		if ($wait > 0) {
			HMCCU_Log ($hash, 2, "Scheduling cleanup in $wait seconds");
			InternalTimer (gettimeofday()+$wait, "HMCCURPCPROC_Housekeeping", $hash, 0);
		}
		else {
			HMCCU_Log ($hash, 2, "Cleaning up immediately");
			HMCCURPCPROC_Housekeeping ($hash);
		}
		
		# Give process the chance to terminate
		sleep (1);
		return 1;
	}
	else {
		HMCCU_Log ($hash, 2, "Found no running processes. Cleaning up ...");
		HMCCURPCPROC_Housekeeping ($hash);
		return 0;
	}
}

######################################################################
# Send RPC request to CCU.
# Supports XML and BINRPC requests.
# Parameter $request contains the RPC command (i.e. "init" or
# "putParamset"). If RPC command is a parameter set command, two
# additional parameters address and key (MASTER or VALUE) must be
# specified.
# If RPC command is putParamset or setValue, the remaining elements
# in array @param contains the request parameters in format:
#   ParameterName=Value[:ParameterType]
# For other RPC command the array @param contains the parameters in
# format:
#   Value[:ParameterType]
# For BINRPC interfaces ParameterType is mapped as follows:
#   "INTEGER" = $BINRPC_INTEGER
#   "BOOL"    = $BINRPC_BOOL
#   "STRING"  = $BINRPC_STRING
#   "FLOAT"   = $BINRPC_DOUBLE
#   "DOUBLE"  = $BINRPC_DOUBLE
#   "BASE64"  = $BINRPC_BASE64
#   "ARRAY"   = $BINRPC_ARRAY
#   "STRUCT"  = $BINRPC_STRUCT
# Return response or undef on error.
######################################################################

sub HMCCURPCPROC_SendRequest ($@)
{
	my ($hash, $request, @param) = @_;
	my $name = $hash->{NAME};
	my $ioHash = $hash->{IODev};
	my $port = $hash->{rpcport};
	
	my $rc;
	
	return HMCCU_Log ($hash, 2, "I/O device not found", undef) if (!defined ($ioHash));
	
	my $re = ':('.join('|', keys(%BINRPC_TYPE_MAPPING)).')';

	if (HMCCU_IsRPCType ($ioHash, $port, 'A')) {
		# Use XMLRPC
		my $clurl = HMCCU_BuildURL ($ioHash, $port);
		return HMCCU_Log ($hash, 2, "Can't get client URL for port $port", undef)
			if (!defined ($clurl));
		
		HMCCU_Log ($hash, 4, "Send ASCII RPC request $request to $clurl", undef);
		my $rpcclient = RPC::XML::Client->new ($clurl, useragent => [
			ssl_opts => { verify_hostname => 0, SSL_verify_mode => 0 } ]);

		if (exists ($RPC_METHODS{$request})) {
			# Read or write parameter sets
			my $address = shift @param;
			my $key = shift @param;
			return HMCCU_Log ($hash, 2, "Missing address or key in RPC request $request", undef)
				if (!defined ($key));

			my %hparam;

			# Write requests have at least one parameters
			if ($RPC_METHODS{$request} == 1) {
				# Build a parameter hash
				while (my $p = shift @param) {
					my $pt = "STRING";
					if ($p =~ /${re}/) {
						$pt = $1;
						$p =~ s/${re}//;
					}
					my ($pn, $pv) = split ('=', $p, 2);
					next if (!defined ($pv));
					$hparam{$pn} = HMCCURPCPROC_EncValue ($pv, $pt);
				}
				
				return HMCCU_Log ($hash, 2, "Missing parameter in RPC request $request", undef)
					if (!keys %hparam);
					
				# Submit write paramset request
				$rc = $rpcclient->simple_request ($request, $address, $key, \%hparam);
			}
			else {			
				# Submit read paramset request
				$rc = $rpcclient->simple_request ($request, $address, $key);
			}
		}
		else {
			# RPC commands
			my @aparam = ();

			# Build a parameter array
			while (my $p = shift @param) {
				my $pt = "STRING";
				if ($p =~ /${re}/) {
					$pt = $1;
					$p =~ s/${re}//;
				}
				push (@aparam, HMCCURPCPROC_EncValue ($p, $pt));
			}
			
			# Submit RPC command
			$rc = $rpcclient->simple_request ($request, @aparam);
		}
		
		HMCCU_Log ($hash, 2, "RPC request error ".$RPC::XML::ERROR, undef) if (!defined ($rc));
	}
	elsif (HMCCU_IsRPCType ($ioHash, $port, 'B')) {
		# Use BINRPC
		my ($serveraddr) = HMCCU_GetRPCServerInfo ($ioHash, $port, 'host');
		return HMCCU_Log ($ioHash, 2, "Can't get server address for port $port", undef)
			if (!defined ($serveraddr));
	
		my $ccuflags = AttrVal ($name, 'ccuflags', 'null');
		my $verbose = GetVerbose ($name);
	
		HMCCU_Log ($hash, 4, "Send binary RPC request $request to $serveraddr:$port", undef);
		my $encreq = HMCCURPCPROC_EncodeRequest ($request, \@param);
		return HMCCU_Log ($hash, 2, "Error encoding binary request", undef) if ($encreq eq '');

		# auto-flush on socket
		$| = 1;

		# create a connecting socket
		my $socket = new IO::Socket::INET (PeerHost => $serveraddr, PeerPort => $port,
			Proto => 'tcp');
		return HMCCU_Log ($hash, 2, "Can't create socket for $serveraddr:$port", undef) if (!$socket);
	
		my $size = $socket->send ($encreq);
		if (defined ($size)) {
			my $encresp = '';
			while (my $readData = <$socket>) {
				$encresp .= $readData;
			}
			$socket->close ();
		
			if (defined ($encresp) && $encresp ne '') {
				if ($ccuflags =~ /logEvents/ && $verbose >= 4) {
					HMCCU_Log ($hash, 4, "Response", undef);
					HMCCURPCPROC_HexDump ($name, $encresp);
				}
				my ($response, $err) = HMCCURPCPROC_DecodeResponse ($encresp);
				HMCCU_Log ($hash, 4, "Error while decoding BIN RPC response")
					if (defined($err) && $err == 0);
				return $response;
			}
			else {
				return '';
			}
		}
	
		$socket->close ();
	}
	else {
		HMCCU_Log ($hash, 2, "Unknown RPC server type", undef);
	}
	
	return $rc;
}

######################################################################
# Timer function for RPC Ping
######################################################################

sub HMCCURPCPROC_RPCPing ($)
{
	my ($hash) = @_;
	my $hmccu_hash = $hash->{IODev};
	my $ping = AttrVal ($hmccu_hash->{NAME}, 'rpcPingCCU', $HMCCURPCPROC_TIME_PING);
	my ($defInterface, $defPort) = HMCCU_GetDefaultInterface ($hmccu_hash);
	
	if ($hash->{rpcinterface} eq $defInterface) {
		if ($ping > 0) {
			if ($init_done && HMCCURPCPROC_CheckProcessState ($hash, 'running')) {
				my $clkey = 'CB'.$hash->{rpcport}.$hash->{rpcid};
				HMCCURPCPROC_SendRequest ($hash, "ping", "$clkey:STRING");
			}
			InternalTimer (gettimeofday()+$ping, "HMCCURPCPROC_RPCPing", $hash, 0);
		}
		else {
			HMCCU_Log ($hash, 1, "CCU ping disabled");
		}
	}
}

######################################################################
# Process binary RPC request
######################################################################

sub HMCCURPCPROC_ProcessRequest ($$)
{
	my ($server, $connection) = @_;
	my $name = $server->{hmccu}{name};
	my $clkey = $server->{hmccu}{clkey};
	my @methodlist = ('listDevices', 'listMethods', 'system.multicall');
	my $verbose = GetVerbose ($name);
	
	# Read request
	my $request = '';
	while  (my $packet = <$connection>) {
		$request .= $packet;
	}
	return if (!defined ($request) || $request eq '');
	
	if ($server->{hmccu}{ccuflags} =~ /logEvents/ && $verbose >= 4) {
		HMCCU_Log ($name, 4, "$clkey raw request:");
		HMCCURPCPROC_HexDump ($name, $request);
	}
	
	# Decode request
	my ($method, $params) = HMCCURPCPROC_DecodeRequest ($request);
	return if (!defined ($method));
	HMCCU_Log ($name, 4, "Request method = $method");
	
	if ($method eq 'listmethods') {
		$connection->send (HMCCURPCPROC_EncodeResponse ($BINRPC_ARRAY, \@methodlist));
	}
	elsif ($method eq 'listdevices') {
		HMCCURPCPROC_ListDevicesCB ($server, $clkey);
		$connection->send (HMCCURPCPROC_EncodeResponse ($BINRPC_ARRAY, undef));
	}
	elsif ($method eq 'system.multicall') {
		return if (ref ($params) ne 'ARRAY');
		my $a = $$params[0];
		foreach my $s (@$a) {
			next if (!exists ($s->{methodName}) || !exists ($s->{params}));
			next if ($s->{methodName} ne 'event');
			next if (scalar (@{$s->{params}}) < 4);
 			HMCCURPCPROC_EventCB ($server, $clkey,
 				${$s->{params}}[1], ${$s->{params}}[2], ${$s->{params}}[3]);
 			HMCCU_Log ($name, 4, "Event ".${$s->{params}}[1]." ".${$s->{params}}[2]." "
 				.${$s->{params}}[3]);
		}
	}
}

######################################################################
# Subprocess function for handling incoming RPC requests
######################################################################

sub HMCCURPCPROC_HandleConnection ($$$$)
{
	my ($port, $callbackport, $sockparent, $procpar) = @_;
	my $name = $procpar->{name};
	
	my $iface       = $procpar->{interface};
	my $prot        = $procpar->{type};
	my $evttimeout  = $procpar->{evttimeout};
	my $conntimeout = $procpar->{conntimeout};
	my $acctimeout  = $procpar->{acctimeout};
	my $socktimeout = $procpar->{socktimeout};
	my $maxsnd      = $procpar->{queuesend};
	my $maxioerrors = $procpar->{maxioerrors};
	my $clkey       = $procpar->{clkey};
	
	my $ioerrors = 0;
	my $sioerrors = 0;
	my $run = 1;
	my $pid = $$;
	
	my @eventtypes = ("EV", "ND", "DD", "RD", "RA", "UD", "IN", "EX", "SL", "TO");

	# Initialize RPC server
	HMCCU_Log ($name, 2, "Initializing RPC server $clkey for interface $iface");
	my $rpcsrv = HMCCURPCPROC_InitRPCServer ($name, $clkey, $callbackport, $prot);
	if (!defined ($rpcsrv)) {
		HMCCU_Log ($name, 1, "Can't initialize RPC server $clkey for interface $iface");
		return;
	}
	if (!($rpcsrv->{__daemon})) {
		HMCCU_Log ($name, 1, "Server socket not found for port $port");
		return;
	}
	
	# Event queue
	my @queue = ();
	
	# Store RPC server parameters
	$rpcsrv->{hmccu}{name}       = $name;
	$rpcsrv->{hmccu}{clkey}      = $clkey;
	$rpcsrv->{hmccu}{eventqueue} = \@queue;
	$rpcsrv->{hmccu}{queuesize}  = $procpar->{queuesize};
	$rpcsrv->{hmccu}{sockparent} = $sockparent;
	$rpcsrv->{hmccu}{statistics} = $procpar->{statistics};
	$rpcsrv->{hmccu}{ccuflags}   = $procpar->{ccuflags};
	$rpcsrv->{hmccu}{flags}      = $procpar->{flags};	
	$rpcsrv->{hmccu}{evttime}    = time ();
	
	# Initialize statistic counters
	foreach my $et (@eventtypes) {
		$rpcsrv->{hmccu}{rec}{$et} = 0;
		$rpcsrv->{hmccu}{snd}{$et} = 0;
	}
	$rpcsrv->{hmccu}{rec}{total} = 0;
	$rpcsrv->{hmccu}{snd}{total} = 0;

	# Signal handler
	$SIG{INT} = sub { $run = 0; HMCCU_Log ($name, 2, "$clkey received signal INT"); };	

	HMCCURPCPROC_Write ($rpcsrv, "SL", $clkey, $pid);
	HMCCU_Log ($name, 2, "$clkey accepting connections. PID=$pid");
	
	$rpcsrv->{__daemon}->timeout ($acctimeout) if ($acctimeout > 0.0);

	while ($run) {
		if ($evttimeout > 0) {
			my $difftime = time()-$rpcsrv->{hmccu}{evttime};
			HMCCURPCPROC_Write ($rpcsrv, "TO", $clkey, $difftime) if ($difftime >= $evttimeout);
		}
		
		# Send queue entries to parent process
		if (scalar (@queue) > 0) {
			HMCCU_Log ($name, 4, "RPC server $clkey sending data to FHEM");
			my ($c, $m) = HMCCURPCPROC_SendQueue ($sockparent, $socktimeout, \@queue, $maxsnd);
			if ($c < 0) {
				$ioerrors++;
				$sioerrors++;
				if ($ioerrors >= $maxioerrors || $maxioerrors == 0) {
					HMCCU_Log ($name, 2, "Sending data to FHEM failed $ioerrors times. $m");
					$ioerrors = 0;
				}
			}
		}
				
		# Next statement blocks for rpcAcceptTimeout seconds
		HMCCU_Log ($name, 5, "RPC server $clkey accepting connections");
		my $connection = $rpcsrv->{__daemon}->accept ();
		next if (! $connection);
		last if (! $run);
		$connection->timeout ($conntimeout) if ($conntimeout > 0.0);
		
		HMCCU_Log ($name, 4, "RPC server $clkey processing request");
		if ($prot eq 'A') {
			$rpcsrv->process_request ($connection);
		}
		else {
			HMCCURPCPROC_ProcessRequest ($rpcsrv, $connection);
		}
		
		shutdown ($connection, 2);
		close ($connection);
		undef $connection;
	}

	HMCCU_Log ($name, 1, "RPC server $clkey stopped handling connections. PID=$pid");

	close ($rpcsrv->{__daemon}) if ($prot eq 'B');
	
	# Send statistic info
	HMCCURPCPROC_WriteStats ($rpcsrv, $clkey);

	# Send exit information	
	HMCCURPCPROC_Write ($rpcsrv, "EX", $clkey, "SHUTDOWN|$pid");

	# Send queue entries to parent process. Resend on error to ensure that EX event is sent
	my ($c, $m) = HMCCURPCPROC_SendQueue ($sockparent, $socktimeout, \@queue, 0);
	if ($c < 0) {
		HMCCU_Log ($name, 4, "Sending data to FHEM failed. $m");
		# Wait 1 second and try again
		sleep (1);
		HMCCURPCPROC_SendQueue ($sockparent, $socktimeout, \@queue, 0);
	}
	
	# Log statistic counters
	foreach my $et (@eventtypes) {
		HMCCU_Log ($name, 4, "$clkey event type = $et: ".$rpcsrv->{hmccu}{rec}{$et});
	}
	HMCCU_Log ($name, 2, "Number of I/O errors = $sioerrors");
	
	return;
}

######################################################################
# Send queue data to parent process.
# Return number of queue elements sent to parent process or
# (-1, errormessage) on error.
######################################################################

sub HMCCURPCPROC_SendQueue ($$$$)
{
	my ($sockparent, $socktimeout, $queue, $maxsnd) = @_;

	my $fd = fileno ($sockparent);
	my $msg = '';
	my $win = '';
	vec ($win, $fd, 1) = 1;
	my $nf = select (undef, $win, undef, $socktimeout);
	if ($nf <= 0) {
		$msg = $nf == 0 ? "select found no reader" : $!;
		return (-1, $msg);
	}
	
	my $sndcnt = 0;
	while (my $snddata = shift @{$queue}) {
		my ($bytes, $err) = HMCCURPCPROC_SendData ($sockparent, $snddata);
		if ($bytes == 0) {
			# Put item back in queue
			unshift @{$queue}, $snddata;
			$msg = $err;
			$sndcnt = -1;
			last;
		}
		$sndcnt++;
		last if ($sndcnt == $maxsnd && $maxsnd > 0);
	}
	
	return ($sndcnt, $msg);
}

######################################################################
# Check if file descriptor is writeable and write data.
# Return number of bytes written and error message.
######################################################################

sub HMCCURPCPROC_SendData ($$)
{
	my ($sockparent, $data) = @_;
	
	my $bytes = 0;
	my $err = '';

	my $size = pack ("N", length ($data));
	my $msg = $size . $data;
	$bytes = syswrite ($sockparent, $msg);
	if (!defined ($bytes)) {
		$err = $!;
		$bytes = 0;
	}
	elsif ($bytes != length ($msg)) {
		$err = "Sent incomplete data";
	}
	
	return ($bytes, $err);
}

######################################################################
# Check if file descriptor is readable and read data.
# Return data and error message.
######################################################################

sub HMCCURPCPROC_ReceiveData ($$)
{
	my ($fh, $socktimeout) = @_;
	
	my $header;
	my $data;
	my $err = '';

	# Check if data is available
	my $fd = fileno ($fh);
	my $rin = '';
	vec ($rin, $fd, 1) = 1;
	my $nfound = select ($rin, undef, undef, $socktimeout);
	if ($nfound < 0) {
		return (undef, $!);
	}
	elsif ($nfound == 0) {
		return (undef, "read: no data");
	}
  
	# Read datagram size	
	my $sbytes = sysread ($fh, $header, 4);
	if (!defined ($sbytes)) {
		return (undef, $!);
	}
	elsif ($sbytes != 4) {
		return (undef, "read: short header");
	}

	# Read datagram
	my $size = unpack ('N', $header);	
	my $bytes = sysread ($fh, $data, $size);
	if (!defined ($bytes)) {
		return (undef, $!);
	}
	elsif ($bytes != $size) {
		return (undef, "read: incomplete data");
	}

	return ($data, $err);
}

######################################################################
# Write event into queue.
######################################################################

sub HMCCURPCPROC_Write ($$$$)
{
	my ($server, $et, $cb, $msg) = @_;
	my $name = $server->{hmccu}{name};

	if (defined ($server->{hmccu}{eventqueue})) {
		my $queue = $server->{hmccu}{eventqueue};
		my $ev = $et."|".$cb."|".$msg;

		$server->{hmccu}{evttime} = time ();
		
		if (defined ($server->{hmccu}{queuesize}) &&
			scalar (@{$queue}) >= $server->{hmccu}{queuesize}) {
			HMCCU_Log ($name, 1, "$cb maximum queue size reached. Dropping event.");
			return;
		}

		HMCCU_Log ($name, 2, "Event = $ev") if ($server->{hmccu}{ccuflags} =~ /logEvents/);

		# Try to send events immediately. Put them in queue if send fails
		my $rc = 0;
		my $err = '';
		if ($et ne 'ND' && $server->{hmccu}{ccuflags} !~ /queueEvents/) {
			($rc, $err) = HMCCURPCPROC_SendData ($server->{hmccu}{sockparent}, $ev);
			HMCCU_Log ($name, 3, "SendData $ev $err") if ($rc == 0);
		}
		push (@{$queue}, $ev) if ($rc == 0);
		
		# Event statistics
		$server->{hmccu}{rec}{$et}++;
		$server->{hmccu}{rec}{total}++;
		$server->{hmccu}{snd}{$et}++;
		$server->{hmccu}{snd}{total}++;
		HMCCURPCPROC_WriteStats ($server, $cb)
			if ($server->{hmccu}{snd}{total} % $server->{hmccu}{statistics} == 0);
	}
}

######################################################################
# Write statistics
######################################################################

sub HMCCURPCPROC_WriteStats ($$)
{
	my ($server, $clkey) = @_;
	my $name = $server->{hmccu}{name};
	
	my @eventtypes = ("EV", "ND", "DD", "RD", "RA", "UD", "IN", "EX", "SL", "TO");

	if (defined ($server->{hmccu}{eventqueue})) {
		my $queue = $server->{hmccu}{eventqueue};

		# Send statistic info
		my $st = $server->{hmccu}{snd}{total};
		foreach my $et (@eventtypes) {
			$st .= '|'.$server->{hmccu}{snd}{$et};
			$server->{hmccu}{snd}{$et} = 0;
		}
	
		HMCCU_Log ($name, 4, "Event statistics = $st");
		push (@{$queue}, "ST|$clkey|$st");
	}
}

######################################################################
# Helper functions
######################################################################

######################################################################
# Dump variable content as hex/ascii combination
######################################################################

sub HMCCURPCPROC_HexDump ($$)
{
	my ($name, $data) = @_;
	
	my $offset = 0;

	foreach my $chunk (unpack "(a16)*", $data) {
		my $hex = unpack "H*", $chunk; # hexadecimal magic
		$chunk =~ tr/ -~/./c;          # replace unprintables
		$hex   =~ s/(.{1,8})/$1 /gs;   # insert spaces
		HMCCU_Log ($name, 4, sprintf "0x%08x (%05u)  %-*s %s", $offset, $offset, 36, $hex, $chunk);
		$offset += 16;
	}
}

######################################################################
# Callback functions
######################################################################

######################################################################
# Callback for new devices
# Message format:
#   C|ADDRESS|TYPE|VERSION|null|null|PARAMSETS|
#      LINK_SOURCE_ROLES|LINK_TARGET_ROLES|DIRECTION|
#      null|PARENT|AES_ACTIVE
#   D|ADDRESS|TYPE|VERSION|FIRMWARE|RX_MODE|PARAMSETS|
#      null|null|null|
#      CHILDREN|null|null
######################################################################

sub HMCCURPCPROC_NewDevicesCB ($$$)
{
	my ($server, $cb, $a) = @_;
	my $name = $server->{hmccu}{name};
	my $devcount = scalar (@$a);
	
	HMCCU_Log ($name, 2, "$cb NewDevice received $devcount device and channel specifications");
	
	foreach my $dev (@$a) {
		my $msg = '';
		if (defined($dev->{PARENT}) && $dev->{PARENT} ne '') {
			$msg = "C|".$dev->{ADDRESS}."|".$dev->{TYPE}."|".$dev->{VERSION}.
				"|null|null|".join(',',@{$dev->{PARAMSETS}}).
				"|".join(',',@{$dev->{LINK_SOURCE_ROLES}}).
				"|".join(',',@{$dev->{LINK_TARGET_ROLES}})."|".$dev->{DIRECTION}.
				"|null|".$dev->{PARENT}."|".$dev->{AES_ACTIVE};
		}
		else {
			# Wired devices do not have a RX_MODE attribute
			my $rx = exists ($dev->{RX_MODE}) ? $dev->{RX_MODE} : 'null';
			$msg = "D|".$dev->{ADDRESS}."|".$dev->{TYPE}."|".$dev->{VERSION}."|".
				$dev->{FIRMWARE}."|".$rx."|".join(',',@{$dev->{PARAMSETS}}).
				"|null|null|null".
				"|".join(',',@{$dev->{CHILDREN}})."|null|null";
		}
		HMCCURPCPROC_Write ($server, "ND", $cb, $msg);
	}

	return;
}

##################################################
# Callback for deleted devices
##################################################

sub HMCCURPCPROC_DeleteDevicesCB ($$$)
{
	my ($server, $cb, $a) = @_;
	my $name = $server->{hmccu}{name};
	my $devcount = scalar (@$a);
	
	HMCCU_Log ($name, 2, "$cb DeleteDevice received $devcount device addresses");
	foreach my $dev (@$a) {
		HMCCURPCPROC_Write ($server, "DD", $cb, $dev);
	}

	return;
}

##################################################
# Callback for modified devices
##################################################

sub HMCCURPCPROC_UpdateDeviceCB ($$$$)
{
	my ($server, $cb, $devid, $hint) = @_;
	my $name = $server->{hmccu}{name};

	HMCCU_Log ($name, 2, "$cb updated device $devid with hint $hint");	
	HMCCURPCPROC_Write ($server, "UD", $cb, $devid."|".$hint);

	return;
}

##################################################
# Callback for replaced devices
##################################################

sub HMCCURPCPROC_ReplaceDeviceCB ($$$$)
{
	my ($server, $cb, $devid1, $devid2) = @_;
	my $name = $server->{hmccu}{name};
	
	HMCCU_Log ($name, 2, "$cb device $devid1 replaced by $devid2");
	HMCCURPCPROC_Write ($server, "RD", $cb, $devid1."|".$devid2);

	return;
}

##################################################
# Callback for readded devices
##################################################

sub HMCCURPCPROC_ReaddDevicesCB ($$$)
{
	my ($server, $cb, $a) = @_;
	my $name = $server->{hmccu}{name};
	my $devcount = scalar (@$a);
	
	HMCCU_Log ($name, 2, "$cb ReaddDevice received $devcount device addresses");
	foreach my $dev (@$a) {
		HMCCURPCPROC_Write ($server, "RA", $cb, $dev);
	}

	return;
}

##################################################
# Callback for handling CCU events
##################################################

sub HMCCURPCPROC_EventCB ($$$$$)
{
	my ($server, $cb, $devid, $attr, $val) = @_;
	my $name = $server->{hmccu}{name};
	my $etime = time ();
	
	HMCCURPCPROC_Write ($server, "EV", $cb, $etime."|".$devid."|".$attr."|".$val);

	# Never remove this statement!
	return;
}

##################################################
# Callback for list devices
##################################################

sub HMCCURPCPROC_ListDevicesCB ($$)
{
	my ($server, $cb) = @_;
	my $name = $server->{hmccu}{name};
	
	if ($server->{hmccu}{ccuflags} =~ /ccuInit/) {
		$cb = "unknown" if (!defined ($cb));
		HMCCU_Log ($name, 1, "$cb ListDevices. Sending init to HMCCU");
		HMCCURPCPROC_Write ($server, "IN", $cb, "INIT|1");
	}
	
	return RPC::XML::array->new ();
}

######################################################################
# RPC encoding functions
######################################################################

######################################################################
# Convert value to RPC data type
# Valid types are bool, boolean, int, integer, float, double, string.
# If type is undefined, type is detected. If type cannot be detected
# value is returned as is.
######################################################################

sub HMCCURPCPROC_EncValue ($$)
{
	my ($value, $type) = @_;
	
	# Try to detect type if type not specified
	if (!defined ($type)) {
		if (lc($value) =~ /^(true|false)$/) {
			$type = 'boolean';
		}
		elsif ($value =~ /^[-+]?\d+$/) {
			$type = 'integer';
		}
		elsif ($value =~ /^[-+]?[0-9]*\.[0-9]+$/) {
			# A float must contain at least a dot followed by a digit
			$type = 'float';
		}
		elsif ($value =~ /[a-zA-Z_ ]/ || $value =~ /^'.+'$/ || $value =~ /^".+"$/) {
			$type = 'string';
		}
	}
	
	if (defined ($type)) {
		my $lcType = lc($type);
		if ($lcType =~ /^bool/ && uc($value) =~ /^(TRUE|FALSE|0|1)$/) {
			return RPC::XML::boolean->new ($value);
		}
		elsif ($lcType =~ /^int/ && $value =~ /^[-+]?\d+$/) {
			return RPC::XML::int->new ($value);
		}
		elsif ($lcType =~ /^(float|double)$/ && $value =~ /^[-+]?[0-9]*\.[0-9]+$/) {
			return RPC::XML::double->new ($value);
		}
		elsif ($lcType =~ /^str/) {
			return RPC::XML::string->new ($value);
		}
	}

	return $value;
}

######################################################################
# Encode integer (type = 1)
######################################################################

sub HMCCURPCPROC_EncInteger ($)
{
	my ($v) = @_;
	
	return pack ('Nl', $BINRPC_INTEGER, $v);
}

######################################################################
# Encode bool (type = 2)
######################################################################

sub HMCCURPCPROC_EncBool ($)
{
	my ($v) = @_;
	
	return pack ('NC', $BINRPC_BOOL, $v);
}

######################################################################
# Encode string (type = 3)
# Input is string. Empty string = void
######################################################################

sub HMCCURPCPROC_EncString ($)
{
	my ($v) = @_;
	
	return pack ('NN', $BINRPC_STRING, length ($v)).$v;
}

######################################################################
# Encode name
######################################################################

sub HMCCURPCPROC_EncName ($)
{
	my ($v) = @_;

	return pack ('N', length ($v)).$v;
}

######################################################################
# Encode double (type = 4)
######################################################################

sub HMCCURPCPROC_EncDouble ($)
{
	my ($v) = @_;
 
#	my $s = $v < 0 ? -1.0 : 1.0;
# 	my $l = $v != 0.0 ? log (abs($v))/log (2) : 0.0;
# 	my $f = $l;
#        
# 	if ($l-int ($l) > 0) {
# 		$f = ($l < 0) ? -int (abs ($l)+1.0) : int ($l);
# 	}
# 	my $e = $f+1;
# 	my $m = int ($v*2**-$e*0x40000000);

	my $m = 0;
	my $e = 0;
	
	if ($v != 0.0) {
		$e = int(log(abs($v))/log(2.0))+1;
		$m = int($v/(2**$e)*0x40000000);
	}
	        
	return pack ('NNN', $BINRPC_DOUBLE, $m, $e);
}

######################################################################
# Encode base64 (type = 17)
# Input is base64 encoded string
######################################################################

sub HMCCURPCPROC_EncBase64 ($)
{
	my ($v) = @_;
	
	return pack ('NN', $BINRPC_DOUBLE, length ($v)).$v;
}

######################################################################
# Encode array (type = 256)
# Input is array reference. Array must contain (type, value) pairs
######################################################################

sub HMCCURPCPROC_EncArray ($)
{
	my ($a) = @_;
	
	my $r = '';
	my $s = 0;

	if (defined ($a)) {
		while (my $t = shift @$a) {
			my $e = shift @$a;
			if ($e) {
				$r .= HMCCURPCPROC_EncType ($t, $e);
				$s++;
			}
		}
	}
		
	return pack ('NN', $BINRPC_ARRAY, $s).$r;
}

######################################################################
# Encode struct (type = 257)
# Input is hash reference. Hash elements:
#   hash->{$element}{T} = Type
#   hash->{$element}{V} = Value
######################################################################

sub HMCCURPCPROC_EncStruct ($)
{
	my ($h) = @_;
	
	my $r = '';
	my $s = 0;
	
	foreach my $k (keys %{$h}) {
		$r .= HMCCURPCPROC_EncName ($k);
		$r .= HMCCURPCPROC_EncType ($h->{$k}{T}, $h->{$k}{V});
		$s++;
	}

	return pack ('NN', $BINRPC_STRUCT, $s).$r;
}

######################################################################
# Encode any type
# Input is type and value
# Return encoded data or empty string on error
######################################################################

sub HMCCURPCPROC_EncType ($$)
{
	my ($t, $v) = @_;
	
	return '' if (!defined ($t));
	
	if ($t == $BINRPC_INTEGER) {
		return HMCCURPCPROC_EncInteger ($v);
	}
	elsif ($t == $BINRPC_BOOL) {
		return HMCCURPCPROC_EncBool ($v);
	}
	elsif ($t == $BINRPC_STRING) {
		return HMCCURPCPROC_EncString ($v);
	}
	elsif ($t == $BINRPC_DOUBLE) {
		return HMCCURPCPROC_EncDouble ($v);
	}
	elsif ($t == $BINRPC_BASE64) {
		return HMCCURPCPROC_EncBase64 ($v);
	}
	elsif ($t == $BINRPC_ARRAY) {
		return HMCCURPCPROC_EncArray ($v);
	}
	elsif ($t == $BINRPC_STRUCT) {
		return HMCCURPCPROC_EncStruct ($v);
	}
	else {
		return '';
	}
}

######################################################################
# Encode RPC request with method and optional parameters.
# Headers are not supported.
# Input is method name and reference to parameter array.
# Array must contain parameters in format value[:type]. Default for
# type is STRING. 
# Return encoded data or empty string on error
######################################################################

sub HMCCURPCPROC_EncodeRequest ($$)
{
	my ($method, $args) = @_;

	# Encode method
	my $m = HMCCURPCPROC_EncName ($method);
	
	# Encode parameters
	my $re = ':('.join('|', keys(%BINRPC_TYPE_MAPPING)).')';
	my $r = '';
	my $s = 0;
				
	if (defined ($args)) {
		while (my $p = shift @$args) {
			my $pt = "STRING";
			if ($p =~ /${re}/) {
				$pt = $1;
				$p =~ s/${re}//;
			}
			my ($e, $t) = split (':', $p);
			$r .= HMCCURPCPROC_EncType ($BINRPC_TYPE_MAPPING{uc($pt)}, $p);
			$s++;
		}
	}
	
	# Method, ParameterCount, Parameters
	$r = $m.pack ('N', $s).$r;

	# Identifier, ContentLength, Content
	# Ggf. +8
	$r = pack ('NN', $BINRPC_REQUEST, length ($r)+8).$r;
	
	return $r;
}

######################################################################
# Encode RPC response
# Input is type and value
######################################################################

sub HMCCURPCPROC_EncodeResponse ($$)
{
	my ($t, $v) = @_;

	if (defined ($t) && defined ($v)) {
		my $r = HMCCURPCPROC_EncType ($t, $v);
		# Ggf. +8
		return pack ('NN', $BINRPC_RESPONSE, length ($r)+8).$r;
	}
	else {
		return pack ('NN', $BINRPC_RESPONSE);
	}
}

######################################################################
# Binary RPC decoding functions
######################################################################

######################################################################
# Decode integer (type = 1)
# Return (value, packetsize) or (undef, undef)
######################################################################

sub HMCCURPCPROC_DecInteger ($$$)
{
	my ($d, $i, $u) = @_;

	return ($i+4 <= length ($d)) ? (unpack ($u, substr ($d, $i, 4)), 4) : (undef, undef);
}

######################################################################
# Decode bool (type = 2)
# Return (value, packetsize) or (undef, undef)
######################################################################

sub HMCCURPCPROC_DecBool ($$)
{
	my ($d, $i) = @_;

	return ($i+1 <= length ($d)) ? (unpack ('C', substr ($d, $i, 1)), 1) : (undef, undef);
}

######################################################################
# Decode string or void (type = 3)
# Return (string, packet size) or (undef, undef)
# Return ('', 4) for special type 'void'
######################################################################

sub HMCCURPCPROC_DecString ($$)
{
	my ($d, $i) = @_;

	my ($s, $o) = HMCCURPCPROC_DecInteger ($d, $i, 'N');
	if (defined ($s) && $i+$s+4 <= length ($d)) {
		return $s > 0 ? (substr ($d, $i+4, $s), $s+4) : ('', 4);
	}
	
	return (undef, undef);
}

######################################################################
# Decode double (type = 4)
# Return (value, packetsize) or (undef, undef)
######################################################################

sub HMCCURPCPROC_DecDouble ($$)
{
	my ($d, $i) = @_;

	return (undef, undef) if ($i+8 > length ($d));
	
	my $m = unpack ('l', reverse (substr ($d, $i, 4)));
	my $e = unpack ('l', reverse (substr ($d, $i+4, 4)));	
	$m = $m/(1<<30);
	my $v = $m*(2**$e);

	return (sprintf ("%.6f",$v), 8);
}

######################################################################
# Decode base64 encoded string (type = 17)
# Return (string, packetsize) or (undef, undef)
######################################################################

sub HMCCURPCPROC_DecBase64 ($$)
{
	my ($d, $i) = @_;
	
	return HMCCURPCPROC_DecString ($d, $i);
}

######################################################################
# Decode array (type = 256)
# Return (arrayref, packetsize) or (undef, undef)
######################################################################

sub HMCCURPCPROC_DecArray ($$)
{
	my ($d, $i) = @_;
	my @r = ();

	my ($s, $x) = HMCCURPCPROC_DecInteger ($d, $i, 'N');
	if (defined ($s)) {
		my $j = $x;
		for (my $n=0; $n<$s; $n++) {
			my ($v, $o) = HMCCURPCPROC_DecType ($d, $i+$j);
			return (undef, undef) if (!defined ($o));
			push (@r, $v);
			$j += $o;
		}
		return (\@r, $j);
	}
	
	return (undef, undef);
}

######################################################################
# Decode struct (type = 257)
# Return (hashref, packetsize) or (undef, undef)
######################################################################

sub HMCCURPCPROC_DecStruct ($$)
{
	my ($d, $i) = @_;
	my %r;
	
	my ($s, $x) = HMCCURPCPROC_DecInteger ($d, $i, 'N');
	if (defined ($s)) {
		my $j = $x;
		for (my $n=0; $n<$s; $n++) {
			my ($k, $o1) = HMCCURPCPROC_DecString ($d, $i+$j);
			return (undef, undef) if (!defined ($o1));
			my ($v, $o2) = HMCCURPCPROC_DecType ($d, $i+$j+$o1);
			return (undef, undef) if (!defined ($o2));
			$r{$k} = $v;
			$j += $o1+$o2;
		}
		return (\%r, $j);
	}
	
	return (undef, undef);
}

######################################################################
# Decode any type
# Return (element, packetsize) or (undef, undef)
######################################################################

sub HMCCURPCPROC_DecType ($$)
{
	my ($d, $i) = @_;
	
	return (undef, undef) if ($i+4 > length ($d));

	my @r = ();
	
	my $t = unpack ('N', substr ($d, $i, 4));
	$i += 4;
	
	if ($t == $BINRPC_INTEGER) {
		# Integer
		@r = HMCCURPCPROC_DecInteger ($d, $i, 'N');
	}
	elsif ($t == $BINRPC_BOOL) {
		# Bool
		@r = HMCCURPCPROC_DecBool ($d, $i);
	}
	elsif ($t == $BINRPC_STRING || $t == $BINRPC_BASE64) {
		# String / Base64
		@r = HMCCURPCPROC_DecString ($d, $i);
	}
	elsif ($t == $BINRPC_DOUBLE) {
		# Double
		@r = HMCCURPCPROC_DecDouble ($d, $i);
	}
	elsif ($t == $BINRPC_ARRAY) {
		# Array
		@r = HMCCURPCPROC_DecArray ($d, $i);
	}
	elsif ($t == $BINRPC_STRUCT) {
		# Struct
		@r = HMCCURPCPROC_DecStruct ($d, $i);
	}
	
	$r[1] += 4;

	return @r;
}

######################################################################
# Decode request.
# Return method, arguments. Arguments are returned as array.
######################################################################

sub HMCCURPCPROC_DecodeRequest ($)
{
	my ($data) = @_;

	my @r = ();
	my $i = 8;
	
	return (undef, undef) if (length ($data) < 8);
	
	# Decode method
	my ($method, $o) = HMCCURPCPROC_DecString ($data, $i);
	return (undef, undef) if (!defined ($method));

	$i += $o;
	
	my $c = unpack ('N', substr ($data, $i, 4));
	$i += 4;

	for (my $n=0; $n<$c; $n++) {
		my ($d, $s) = HMCCURPCPROC_DecType ($data, $i);
		return (undef, undef) if (!defined ($d) || !defined ($s));
		push (@r, $d);
		$i += $s;
	}
		
	return (lc ($method), \@r);
}

######################################################################
# Decode response.
# Return (ref, type) or (undef, undef)
# type: 1=ok, 0=error
######################################################################

sub HMCCURPCPROC_DecodeResponse ($)
{
	my ($data) = @_;
	
	return (undef, undef) if (length ($data) < 8);
	
	my $id = unpack ('N', substr ($data, 0, 4));
	if ($id == $BINRPC_RESPONSE) {
		# Data
		my ($result, $offset) = HMCCURPCPROC_DecType ($data, 8);
		return ($result, 1);
	}
	elsif ($id == $BINRPC_ERROR) {
		# Error
		my ($result, $offset) = HMCCURPCPROC_DecType ($data, 8);
		return ($result, 0);
	}
#	Response with header not supported
#	elsif ($id == 0x42696E41) {
#	}
	
	return (undef, undef);
}


1;

=pod
=item device
=item summary provides RPC server for connection between FHEM and Homematic CCU2
=begin html

<a name="HMCCURPCPROC"></a>
<h3>HMCCURPCPROC</h3>
<ul>
	The module provides a subprocess based RPC server for receiving events from HomeMatic CCU2.
	A HMCCURPCPROC device acts as a client device for a HMCCU I/O device. Normally RPC servers of
	type HMCCURPCPROC are started or stopped from HMCCU I/O device via command 'set rpcserver on,off'.
	HMCCURPCPROC devices will be created automatically by I/O device when RPC server is started.
	There should be no need for creating HMCCURPCPROC devices manually.
   </br></br>
   <a name="HMCCURPCPROCdefine"></a>
   <b>Define</b><br/><br/>
   <ul>
      <code>define &lt;name&gt; HMCCURPCPROC {&lt;HostOrIP&gt;|iodev=&lt;DeviceName&gt;} 
      {&lt;port&gt;|&lt;interface&gt;}</code>
      <br/><br/>
      Examples:<br/>
      <code>define myccurpc HMCCURPCPROC 192.168.1.10 2001</code><br/>
      <code>define myccurpc HMCCURPCPROC iodev=myccudev BidCos-RF</code><br/>
      <br/><br/>
      The parameter <i>HostOrIP</i> is the hostname or IP address of a Homematic CCU2.
      The I/O device can also be specified with parameter iodev. If more than one CCU exist
      it's highly recommended to specify IO device with option iodev. Supported interfaces or
      ports are:
      <table>
      <tr><td><b>Port</b></td><td><b>Interface</b></td></tr>
      <tr><td>2000</td><td>BidCos-Wired</td></tr>
      <tr><td>2001</td><td>BidCos-RF</td></tr>
      <tr><td>2010</td><td>HmIP-RF</td></tr>
      <tr><td>7000</td><td>HVL</td></tr>
      <tr><td>8701</td><td>CUxD</td></tr>
      <tr><td>9292</td><td>Virtual</td></tr>
      </table>
   </ul>
   <br/>
   
   <a name="HMCCURPCPROCset"></a>
   <b>Set</b><br/><br/>
   <ul>
      <li><b>set &lt;name&gt; deregister</b><br/>
         Deregister RPC server at CCU.
      </li><br/>
      <li><b>set &lt;name&gt; register</b><br/>
         Register RPC server at CCU. RPC server must be running. Helpful when CCU lost
         connection to FHEM and events timed out.
      </li><br/>
		<li><b>set &lt;name&gt; rpcrequest &lt;method&gt; [&lt;parameters&gt;]</b><br/>
			Send RPC request to CCU. The result is displayed in FHEM browser window. See EQ-3
			RPC XML documentation for mor information about valid methods and requests.
		</li><br/>
		<li><b>set &lt;name&gt; rpcserver { on | off }</b><br/>
			Start or stop RPC server. This command is only available if expert mode is activated.
		</li><br/>
	</ul>
	
	<a name="HMCCURPCPROCget"></a>
	<b>Get</b><br/><br/>
	<ul>
		<li><b>get &lt;name&gt; devicedesc [&lt;address&gt;]</b><br/>
			Read device descriptions from CCU. If no <i>address</i> is specified, all devices are
			read. Parameter <i>address</i> can be a device or a channel address.
		</li><br/>
		<li><b>get &lt;name&gt; rpcevent</b><br/>
			Show RPC server events statistics. If attribute ccuflags contains flag 'statistics'
			the 3 devices which sent most events are listed.
		</li><br/>
		<li><b>get &lt;name&gt; rpcstate</b><br/>
			Show RPC process state.
		</li><br/>
	</ul>
	
	<a name="HMCCURPCPROCattr"></a>
	<b>Attributes</b><br/><br/>
	<ul>
		<li><b>ccuflags { flag-list }</b><br/>
			Set flags for controlling device behaviour. Meaning of flags is:<br/>
			ccuInit - RPC server initialization depends on ListDevice RPC call issued by CCU.
			This flag is not supported by interfaces CUxD and HVL.<br/>
			expert - Activate expert mode<br/>
			logEvents - Events are written into FHEM logfile if verbose is 4<br/>
			noEvents - Ignore events from CCU, do not update client device readings.<br/>
			noInitalUpdate - Do not update devices after RPC server started.<br/>
			queueEvents - Always write events into queue and send them asynchronously to FHEM.
			Frequency of event transmission to FHEM depends on attribute rpcConnTimeout.<br/>
			statistics - Count events per device sent by CCU<br/>
		</li><br/>
		<li><b>rpcAcceptTimeout &lt;seconds&gt;</b><br/>
			Specify timeout for accepting incoming connections. Default is 1 second. Increase this 
			value by 1 or 2 seconds on slow systems.
		</li><br/>
	   <li><b>rpcConnTimeout &lt;seconds&gt;</b><br/>
	   	Specify timeout of incoming CCU connections. Default is 1 second. Value must be greater than 0.
	   </li><br/>
	   <li><b>rpcEventTimeout &lt;seconds&gt;</b><br/>
	   	Specify timeout for CCU events. Default is 0, timeout is ignored. If timeout occurs an event
	   	is triggered. If ccuflag reconnect is set in I/O device the RPC device tries to establish a new
	   	connection to the CCU.
	   </li><br/>
	   <li><b>rpcMaxEvents &lt;count&gt;</b><br/>
	   	Specify maximum number of events read by FHEM during one I/O loop. If FHEM performance
	   	slows down decrease this value and increase attribute rpcQueueSize. Default value is 100.
	   	Value must be greater than 0.
	   </li><br/>
	   <li><b>rpcMaxIOErrors &lt;count&gt;</b><br/>
	   	Specifiy maximum number of I/O errors allowed when sending events to FHEM before a 
	   	message is written into FHEM log file. Default value is 100. Set this attribute to 0
	   	to disable error counting.
	   </li><br/>
	   <li><b>rpcPingCCU &lt;interval&gt;</b><br/>
	   	Ignored. Should be set in I/O device.
	   </li><br/>
	   <li><b>rpcQueueSend &lt;events&gt;</b><br/>
	      Maximum number of events sent to FHEM per accept loop. Default is 70. If set to 0
	      all events in queue are sent to FHEM. Transmission is stopped when an I/O error occurrs
	      or specified number of events has been sent.
	   </li><br/>
	   <li><b>rpcQueueSize &lt;count&gt;</b><br/>
	   	Specify maximum size of event queue. When this limit is reached no more CCU events
	   	are forwarded to FHEM. In this case increase this value or increase attribute
	   	<b>rpcMaxEvents</b>. Default value is 500.
	   </li><br/>
	   <li><b>rpcServerAddr &lt;ip-address&gt;</b><br/>
	   	Set local IP address of RPC servers on FHEM system. If attribute is missing the
	   	corresponding attribute of I/O device (HMCCU device) is used or IP address is
	   	detected automatically. This attribute should be set if FHEM is running on a system
	   	with multiple network interfaces.
	   </li><br/>
	   <li><b>rpcServerPort &lt;port&gt;</b><br/>
	   	Specify TCP port number used for calculation of real RPC server ports. 
	   	If attribute is missing the corresponding attribute of I/O device (HMCCU device)
	   	is used. Default value is 5400.
	   </li><br/>
	   <li><b>rpcStatistics &lt;count&gt;</b><br/>
	   	Specify amount of events after which statistic data is sent to FHEM. Default value
	   	is 500.
	   </li><br/>
		<li><b>rpcWriteTimeout &lt;seconds&gt;</b><br/>
			Wait the specified time for socket to become readable or writeable. Default value
			is 0.001 seconds.
		</li>
	</ul>
</ul>

=end html
=cut


