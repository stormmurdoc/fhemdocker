##############################################################################
#
#  88_HMCCU.pm
#
#  $Id: 88_HMCCU.pm 18745 2019-02-26 17:33:23Z zap $
#
#  Version 4.4.000
#
#  Module for communication between FHEM and Homematic CCU2/3.
#
#  Supports BidCos-RF, BidCos-Wired, HmIP-RF, virtual CCU channels,
#  CCU group devices, HomeGear, CUxD, Osram Lightify, Homematic Virtual Layer
#  and Philips Hue (not tested)
#
#  (c) 2020 by zap (zap01 <at> t-online <dot> de)
#
##############################################################################
#
#  Verbose levels:
#
#  0 = Log start/stop and initialization messages
#  1 = Log errors
#  2 = Log counters and warnings
#  3 = Log events and runtime information
#
##############################################################################

package main;

no if $] >= 5.017011, warnings => 'experimental::smartmatch';

use strict;
use warnings;
# use Data::Dumper;
# use Time::HiRes qw(usleep);
use IO::File;
use Fcntl 'SEEK_END', 'SEEK_SET', 'O_CREAT', 'O_RDWR';
use RPC::XML::Client;
use RPC::XML::Server;
use HttpUtils;
use SetExtensions;
use SubProcess;
use HMCCUConf;

# Import configuration data
my $HMCCU_CHN_DEFAULTS = \%HMCCUConf::HMCCU_CHN_DEFAULTS;
my $HMCCU_DEV_DEFAULTS = \%HMCCUConf::HMCCU_DEV_DEFAULTS;
my $HMCCU_SCRIPTS = \%HMCCUConf::HMCCU_SCRIPTS;

# Custom configuration data
my %HMCCU_CUST_CHN_DEFAULTS;
my %HMCCU_CUST_DEV_DEFAULTS;

# HMCCU version
my $HMCCU_VERSION = '4.4.000';

# Constants and default values
my $HMCCU_MAX_IOERRORS = 100;
my $HMCCU_MAX_QUEUESIZE = 500;
my $HMCCU_TIME_WAIT = 100000;
my $HMCCU_TIME_TRIGGER = 10;

# RPC ping interval for default interface, should be smaller than HMCCU_TIMEOUT_EVENT
my $HMCCU_TIME_PING = 300;

my $HMCCU_TIMEOUT_CONNECTION = 10;
my $HMCCU_TIMEOUT_WRITE = 0.001;
my $HMCCU_TIMEOUT_ACCEPT = 1;
my $HMCCU_TIMEOUT_EVENT = 600;
my $HMCCU_STATISTICS = 500;
my $HMCCU_TIMEOUT_REQUEST = 4;

# ReGa Ports
my %HMCCU_REGA_PORT = (
	'http' => 8181, 'https' => '48181'
);

# RPC interface priority
my @HMCCU_RPC_PRIORITY = ('BidCos-RF', 'HmIP-RF', 'BidCos-Wired');

# RPC port name by port number
my %HMCCU_RPC_NUMPORT = (
	2000 => 'BidCos-Wired', 2001 => 'BidCos-RF', 2010 => 'HmIP-RF', 9292 => 'VirtualDevices',
	2003 => 'Homegear', 8701 => 'CUxD', 7000 => 'HVL'
);

# RPC port number by port name
my %HMCCU_RPC_PORT = (
   'BidCos-Wired', 2000, 'BidCos-RF', 2001, 'HmIP-RF', 2010, 'VirtualDevices', 9292,
   'Homegear', 2003, 'CUxD', 8701, 'HVL', 7000
);

# RPC flags
my %HMCCU_RPC_FLAG = (
	2000 => 'forceASCII', 2001 => 'forceASCII', 2003 => '_', 2010 => 'forceASCII',
	7000 => 'forceInit', 8701 => 'forceInit', 9292 => '_'
);

my %HMCCU_RPC_SSL = (
	2000 => 1, 2001 => 1, 2010 => 1, 9292 => 1,
	'BidCos-Wired' => 1, 'BidCos-RF' => 1, 'HmIP-RF' => 1, 'VirtualDevices' => 1
);

# Initial intervals for registration of RPC callbacks and reading RPC queue
#
# X                      = Start RPC server
# X+HMCCU_INIT_INTERVAL1 = Register RPC callback
# X+HMCCU_INIT_INTERVAL2 = Read RPC Queue
#
my $HMCCU_INIT_INTERVAL0 = 12;
my $HMCCU_INIT_INTERVAL1 = 7;
my $HMCCU_INIT_INTERVAL2 = 5;

# Default values for delayed initialization during FHEM startup
my $HMCCU_CCU_PING_TIMEOUT = 1;
my $HMCCU_CCU_BOOT_DELAY = 180;
my $HMCCU_CCU_DELAYED_INIT = 59;
my $HMCCU_CCU_RPC_OFFSET = 20;

# Number of arguments in RPC events
my %rpceventargs = (
	"EV", 3,		# Datapoint value updated
	"ND", 6,		# New device created
	"DD", 1,		# Device deleted
	"RD", 2,		# Device renamed
	"RA", 1,		# Device readded
	"UD", 2,		# Device updated
	"IN", 3,		# RPC init
	"EX", 3,		# Exit RPC server
	"SL", 2,		# RPC server loop
	"ST", 10		# Status
);

# Datapoint operations
my $HMCCU_OPER_READ  = 1;
my $HMCCU_OPER_WRITE = 2;
my $HMCCU_OPER_EVENT = 4;

# Datapoint types
my $HMCCU_TYPE_BINARY  = 2;
my $HMCCU_TYPE_FLOAT   = 4;
my $HMCCU_TYPE_INTEGER = 16;
my $HMCCU_TYPE_STRING  = 20;

# Flags for CCU object specification
my $HMCCU_FLAG_NAME      = 1;
my $HMCCU_FLAG_CHANNEL   = 2;
my $HMCCU_FLAG_DATAPOINT = 4;
my $HMCCU_FLAG_ADDRESS   = 8;
my $HMCCU_FLAG_INTERFACE = 16;
my $HMCCU_FLAG_FULLADDR  = 32;

# Valid flag combinations
my $HMCCU_FLAGS_IACD = $HMCCU_FLAG_INTERFACE | $HMCCU_FLAG_ADDRESS |
	$HMCCU_FLAG_CHANNEL | $HMCCU_FLAG_DATAPOINT;
my $HMCCU_FLAGS_IAC = $HMCCU_FLAG_INTERFACE | $HMCCU_FLAG_ADDRESS | $HMCCU_FLAG_CHANNEL;
my $HMCCU_FLAGS_ACD = $HMCCU_FLAG_ADDRESS | $HMCCU_FLAG_CHANNEL | $HMCCU_FLAG_DATAPOINT;
my $HMCCU_FLAGS_AC  = $HMCCU_FLAG_ADDRESS | $HMCCU_FLAG_CHANNEL;
my $HMCCU_FLAGS_ND  = $HMCCU_FLAG_NAME | $HMCCU_FLAG_DATAPOINT;
my $HMCCU_FLAGS_NC  = $HMCCU_FLAG_NAME | $HMCCU_FLAG_CHANNEL;
my $HMCCU_FLAGS_NCD = $HMCCU_FLAG_NAME | $HMCCU_FLAG_CHANNEL | $HMCCU_FLAG_DATAPOINT;

# Flags for address/name checks
my $HMCCU_FL_STADDRESS = 1;
my $HMCCU_FL_NAME      = 2;
my $HMCCU_FL_EXADDRESS = 4;
my $HMCCU_FL_ADDRESS   = 5;
my $HMCCU_FL_ALL       = 7;

# Default values
my $HMCCU_DEF_HMSTATE = '^0\.UNREACH!(1|true):unreachable;^[0-9]\.LOW_?BAT!(1|true):warn_battery';

# Placeholder for external addresses (i.e. HVL)
my $HMCCU_EXT_ADDR = 'ZZZ0000000';

# Binary RPC data types
my $BINRPC_INTEGER = 1;
my $BINRPC_BOOL    = 2;
my $BINRPC_STRING  = 3;
my $BINRPC_DOUBLE  = 4;
my $BINRPC_BASE64  = 17;
my $BINRPC_ARRAY   = 256;
my $BINRPC_STRUCT  = 257;

# Declare functions

# FHEM standard functions
sub HMCCU_Initialize ($);
sub HMCCU_Define ($$);
sub HMCCU_InitDevice ($);
sub HMCCU_Undef ($$);
sub HMCCU_DelayedShutdown ($);
sub HMCCU_Shutdown ($);
sub HMCCU_Set ($@);
sub HMCCU_Get ($@);
sub HMCCU_Attr ($@);
sub HMCCU_AttrInterfacesPorts ($$$);
sub HMCCU_Notify ($$);
sub HMCCU_Detail ($$$$);

# Aggregation
sub HMCCU_AggregateReadings ($$);
sub HMCCU_AggregationRules ($$);

# Handling of default attributes
sub HMCCU_DetectDefaults ($$);
sub HMCCU_ExportDefaults ($$);
sub HMCCU_ExportDefaultsCSV ($$);
sub HMCCU_ImportDefaults ($);
sub HMCCU_FindDefaults ($$);
sub HMCCU_GetDefaults ($$);
sub HMCCU_SetDefaults ($);

# Status and logging functions
sub HMCCU_Trace ($$$$);
sub HMCCU_Log ($$$;$);
sub HMCCU_LogError ($$$);
sub HMCCU_SetError ($@);
sub HMCCU_SetState ($@);
sub HMCCU_SetRPCState ($@);

# Filter and modify readings
sub HMCCU_FilterReading ($$$);
sub HMCCU_FormatReadingValue ($$$);
sub HMCCU_GetReadingName ($$$$$$$);
sub HMCCU_ScaleValue ($$$$$);
sub HMCCU_Substitute ($$$$$);
sub HMCCU_SubstRule ($$$);
sub HMCCU_SubstVariables ($$$);

# Update client device readings
sub HMCCU_BulkUpdate ($$$$);
sub HMCCU_GetUpdate ($$$);
sub HMCCU_UpdateCB ($$$);
sub HMCCU_UpdateClients ($$$$$$);
sub HMCCU_UpdateInternalValues ($$$$);
sub HMCCU_UpdateMultipleDevices ($$);
sub HMCCU_UpdatePeers ($$$$);
sub HMCCU_UpdateSingleDatapoint ($$$$);
sub HMCCU_UpdateSingleDevice ($$$$);

# RPC functions
sub HMCCU_EventsTimedOut ($);
sub HMCCU_GetRPCCallbackURL ($$$$$);
sub HMCCU_GetRPCDevice ($$$);
sub HMCCU_GetRPCInterfaceList ($);
sub HMCCU_GetRPCPortList ($);
sub HMCCU_GetRPCServerInfo ($$$);
sub HMCCU_IsRPCServerRunning ($$$);
sub HMCCU_IsRPCType ($$$);
sub HMCCU_IsRPCStateBlocking ($);
sub HMCCU_ResetCounters ($);
sub HMCCU_RPCDeRegisterCallback ($);
sub HMCCU_RPCRegisterCallback ($);
sub HMCCU_RPCRequest ($$$$$;$);
sub HMCCU_StartExtRPCServer ($);
sub HMCCU_StartIntRPCServer ($);
sub HMCCU_StopExtRPCServer ($;$);
sub HMCCU_StopRPCServer ($);

# Parse and validate names and addresses
sub HMCCU_ParseObject ($$$);
sub HMCCU_IsDevAddr ($$);
sub HMCCU_IsChnAddr ($$);
sub HMCCU_SplitChnAddr ($);
sub HMCCU_SplitDatapoint ($;$);

# FHEM device handling functions
sub HMCCU_AssignIODevice ($$$);
sub HMCCU_FindClientDevices ($$$$);
sub HMCCU_FindIODevice ($);
sub HMCCU_GetHash ($@);
sub HMCCU_GetAttribute ($$$$);
sub HMCCU_GetFlags ($);
sub HMCCU_GetAttrReadingFormat ($$);
sub HMCCU_GetAttrStripNumber ($);
sub HMCCU_GetAttrSubstitute ($$);
sub HMCCU_IODeviceStates ();
sub HMCCU_IsFlag ($$);

# Handle interfaces, devices and channels
sub HMCCU_AddDeviceDesc ($$$$);
sub HMCCU_AddDeviceModel ($$$$$$);
sub HMCCU_CreateDevice ($$$$$);
sub HMCCU_DeleteDevice ($);
sub HMCCU_ExistsDeviceModel ($$$;$);
sub HMCCU_FormatDeviceInfo ($);
sub HMCCU_GetAddress ($$$$);
sub HMCCU_GetAffectedAddresses ($);
sub HMCCU_GetCCUDeviceParam ($$);
sub HMCCU_GetChannelName ($$$);
sub HMCCU_GetClientDeviceModel ($;$);
sub HMCCU_GetDefaultInterface ($);
sub HMCCU_GetDeviceAddresses ($;$$);
sub HMCCU_GetDeviceChannels ($$$);
sub HMCCU_GetDeviceDesc ($;$$);
sub HMCCU_GetDeviceInfo ($$$);
sub HMCCU_GetDeviceInterface ($$$);
sub HMCCU_GetDeviceList ($);
sub HMCCU_GetDeviceModel ($$$;$);
sub HMCCU_GetDeviceName ($$$);
sub HMCCU_GetDeviceType ($$$);
sub HMCCU_GetFirmwareVersions ($$);
sub HMCCU_GetGroupMembers ($$);
sub HMCCU_GetMatchingDevices ($$$$);
sub HMCCU_IsValidChannel ($$$);
sub HMCCU_IsValidDevice ($$$);
sub HMCCU_IsValidDeviceOrChannel ($$$);
sub HMCCU_ResetDeviceTables ($$);
sub HMCCU_UpdateDeviceTable ($$);

# Handle datapoints
sub HMCCU_FindDatapoint ($$$$$);
sub HMCCU_GetDatapoint ($@);
sub HMCCU_GetDatapointAttr ($$$$$);
sub HMCCU_GetDatapointCount ($$$);
sub HMCCU_GetDatapointList ($$$);
sub HMCCU_GetSpecialDatapoints ($$$$$);
sub HMCCU_GetSwitchDatapoint ($$$);
sub HMCCU_GetValidDatapoints ($$$$$);
sub HMCCU_IsValidDatapoint ($$$$$);
# sub HMCCU_SetDatapoint ($$$);
sub HMCCU_SetMultipleDatapoints ($$);
sub HMCCU_SetMultipleParameters ($$$);

# Internal RPC server functions
sub HMCCU_ResetRPCQueue ($$);
sub HMCCU_ReadRPCQueue ($);
sub HMCCU_ProcessEvent ($$);

# Homematic script and variable functions
sub HMCCU_GetVariables ($$);
sub HMCCU_HMCommand ($$$);
sub HMCCU_HMCommandCB ($$$);
sub HMCCU_HMCommandNB ($$$);
sub HMCCU_HMScriptExt ($$$$$);
sub HMCCU_SetVariable ($$$$$);
sub HMCCU_UpdateVariables ($);

# File queue functions
sub HMCCU_QueueOpen ($$);
sub HMCCU_QueueClose ($);
sub HMCCU_QueueReset ($);
sub HMCCU_QueueEnq ($$);
sub HMCCU_QueueDeq ($);

# Helper functions
sub HMCCU_BitsToStr ($$);
sub HMCCU_BuildURL ($$);
sub HMCCU_CalculateReading ($$);
sub HMCCU_CorrectName ($);
sub HMCCU_Encrypt ($);
sub HMCCU_Decrypt ($);
sub HMCCU_DeleteReadings ($$);
sub HMCCU_EncodeEPDisplay ($);
sub HMCCU_ExprMatch ($$$);
sub HMCCU_ExprNotMatch ($$$);
sub HMCCU_GetDutyCycle ($);
sub HMCCU_GetHMState ($$$);
sub HMCCU_GetIdFromIP ($$);
sub HMCCU_GetTimeSpec ($);
sub HMCCU_FlagsToStr ($$$;$$);
sub HMCCU_MaxHashEntries ($$);
sub HMCCU_RefToString ($);
sub HMCCU_ResolveName ($$);
sub HMCCU_TCPConnect ($$);
sub HMCCU_TCPPing ($$$);

# Subprocess functions of internal RPC server
sub HMCCU_CCURPC_Write ($$);
sub HMCCU_CCURPC_OnRun ($);
sub HMCCU_CCURPC_OnExit ();
sub HMCCU_CCURPC_NewDevicesCB ($$$);
sub HMCCU_CCURPC_DeleteDevicesCB ($$$);
sub HMCCU_CCURPC_UpdateDeviceCB ($$$$);
sub HMCCU_CCURPC_ReplaceDeviceCB ($$$$);
sub HMCCU_CCURPC_ReaddDevicesCB ($$$);
sub HMCCU_CCURPC_EventCB ($$$$$);
sub HMCCU_CCURPC_ListDevicesCB ($$);


##################################################
# Initialize module
##################################################

sub HMCCU_Initialize ($)
{
	my ($hash) = @_;

	$hash->{DefFn} = "HMCCU_Define";
	$hash->{UndefFn} = "HMCCU_Undef";
	$hash->{SetFn} = "HMCCU_Set";
	$hash->{GetFn} = "HMCCU_Get";
	$hash->{ReadFn} = "HMCCU_Read";
	$hash->{AttrFn} = "HMCCU_Attr";
	$hash->{NotifyFn} = "HMCCU_Notify";
	$hash->{ShutdownFn} = "HMCCU_Shutdown";
	$hash->{DelayedShutdownFn} = "HMCCU_DelayedShutdown";
	$hash->{FW_detailFn} = "HMCCU_Detail";
	$hash->{parseParams} = 1;

	$hash->{AttrList} = "stripchar stripnumber ccuaggregate:textField-long".
		" ccudefaults rpcinterfaces:multiple-strict,".join(',',sort keys %HMCCU_RPC_PORT).
		" ccudef-hmstatevals:textField-long ccudef-substitute:textField-long".
		" ccudef-readingname:textField-long ccudef-readingfilter:textField-long".
		" ccudef-readingformat:name,namelc,address,addresslc,datapoint,datapointlc".
		" ccudef-stripnumber".
		" ccuflags:multiple-strict,procrpc,dptnocheck,logCommand,noagg,nohmstate,".
		"logEvents,noEvents,noInitialUpdate,noReadings,nonBlocking,reconnect,logPong,trace".
		" ccuReqTimeout ccuGetVars rpcinterval:2,3,5,7,10 rpcqueue rpcPingCCU".
		" rpcport:multiple-strict,".join(',',sort keys %HMCCU_RPC_NUMPORT).
		" rpcserver:on,off rpcserveraddr rpcserverport rpctimeout rpcevtimeout substitute".
		" ccuget:Value,State ".
		$readingFnAttributes;
}

######################################################################
# Define device
######################################################################

sub HMCCU_Define ($$)
{
	my ($hash, $a, $h) = @_;
	my $name = $hash->{NAME};

	return "Specify CCU hostname or IP address as a parameter" if (scalar (@$a) < 3);

	# Setup http or ssl connection	
	if ($$a[2] =~ /^(https?):\/\/(.+)/) {
		$hash->{prot} = $1;
		$hash->{host} = $2;
	}
	else {
		$hash->{prot} = 'http';
		$hash->{host} = $$a[2];
	}

	$hash->{Clients} = ':HMCCUDEV:HMCCUCHN:HMCCURPC:HMCCURPCPROC:';
	$hash->{hmccu}{ccu}{delay} = exists ($h->{ccudelay}) ? $h->{ccudelay} : $HMCCU_CCU_BOOT_DELAY;
	$hash->{hmccu}{ccu}{timeout} = exists ($h->{waitforccu}) ? $h->{waitforccu} : $HMCCU_CCU_PING_TIMEOUT;
	$hash->{hmccu}{ccu}{delayed} = 0;
	
	# Check if TCL-Rega process is running on CCU (CCU reachable)
	if (exists ($h->{delayedinit}) && $h->{delayedinit} > 0) {
		return "Value for delayed initialization must be greater than $HMCCU_CCU_DELAYED_INIT"
			if ($h->{delayedinit} <= $HMCCU_CCU_DELAYED_INIT);
		$hash->{hmccu}{ccu}{delay} = $h->{delayedinit};
		$hash->{ccustate} = 'unreachable';
		HMCCU_Log ($hash, 1, "Forced delayed initialization");
	}
	else {
		if (HMCCU_TCPPing ($hash->{host}, $HMCCU_REGA_PORT{$hash->{prot}}, $hash->{hmccu}{ccu}{timeout})) {
			$hash->{ccustate} = 'active';
		}
		else {
			$hash->{ccustate} = 'unreachable';
			HMCCU_Log ($hash, 1, "CCU port ".$HMCCU_REGA_PORT{$hash->{prot}}." is not reachable");
		}
	}

	# Get CCU IP address
	$hash->{ccuip} = HMCCU_ResolveName ($hash->{host}, 'N/A');

	# Get CCU number (if more than one)
	if (scalar (@$a) >= 4) {
		return "CCU number must be in range 1-9" if ($$a[3] < 1 || $$a[3] > 9);
		$hash->{CCUNum} = $$a[3];
	}
	else {
		# Count CCU devices
		my $ccucount = 0;
		foreach my $d (keys %defs) {
			my $ch = $defs{$d};
			next if (!exists ($ch->{TYPE}));
			$ccucount++ if ($ch->{TYPE} eq 'HMCCU' && $ch != $hash);
		}
		$hash->{CCUNum} = $ccucount+1;
	}

	$hash->{version} = $HMCCU_VERSION;
	$hash->{ccutype} = 'CCU2/3';
	$hash->{RPCState} = "inactive";
	$hash->{NOTIFYDEV} = "global,TYPE=(HMCCU|HMCCUDEV|HMCCUCHN)";
	$hash->{hmccu}{defInterface} = $HMCCU_RPC_PRIORITY[0];
	$hash->{hmccu}{defPort} = $HMCCU_RPC_PORT{$hash->{hmccu}{defInterface}};
	$hash->{hmccu}{rpcports} = undef;

	HMCCU_Log ($hash, 1, "Initialized version $HMCCU_VERSION");
	
	my $rc = 0;
	if ($hash->{ccustate} eq 'active') {
		# If CCU is alive read devices, channels, interfaces and groups
		HMCCU_Log ($hash, 1, "HMCCU: Initializing device");
		$rc = HMCCU_InitDevice ($hash);
	}
	
	if ($hash->{ccustate} ne 'active' || $rc > 0) {
		# Schedule update of CCU assets if CCU is not active during FHEM startup
		if (!$init_done) {
			$hash->{hmccu}{ccu}{delayed} = 1;
			HMCCU_Log ($hash, 1, "Scheduling delayed initialization in ".$hash->{hmccu}{ccu}{delay}." seconds");
			InternalTimer (gettimeofday()+$hash->{hmccu}{ccu}{delay}, "HMCCU_InitDevice", $hash);
		}
	}
	
	$hash->{hmccu}{evtime} = 0;
	$hash->{hmccu}{evtimeout} = 0;
	$hash->{hmccu}{updatetime} = 0;
	$hash->{hmccu}{rpccount} = 0;

	readingsBeginUpdate ($hash);
	readingsBulkUpdate ($hash, "state", "Initialized");
	readingsBulkUpdate ($hash, "rpcstate", "inactive");
	readingsEndUpdate ($hash, 1);

	$attr{$name}{stateFormat} = "rpcstate/state";
	
	return undef;
}

######################################################################
# Initialization of FHEM device.
# Called during Define() or by HMCCU after CCU ready.
# Return 0 on successful initialization or >0 on error:
# 1 = CCU port 8181 or 48181 is not reachable.
# 2 = Error while reading device list from CCU.
######################################################################

sub HMCCU_InitDevice ($)
{
	my ($hash) = @_;
	my $name = $hash->{NAME};

	if ($hash->{hmccu}{ccu}{delayed} == 1) {
		HMCCU_Log ($hash, 1, "HMCCU: Initializing devices");
		if (!HMCCU_TCPPing ($hash->{host}, $HMCCU_REGA_PORT{$hash->{prot}}, $hash->{hmccu}{ccu}{timeout})) {
			$hash->{ccustate} = 'unreachable';
			HMCCU_Log ($hash, 1, "HMCCU: CCU port ".$HMCCU_REGA_PORT{$hash->{prot}}." is not reachable");
			return 1;
		}
	}
	
	my ($devcnt, $chncnt, $ifcount, $prgcount, $gcount) = HMCCU_GetDeviceList ($hash);
	if ($devcnt >= 0) {
		HMCCU_Log ($hash, 1, "HMCCU: Read $devcnt devices with $chncnt channels from CCU ".$hash->{host});
		HMCCU_Log ($hash, 1, "HMCCU: Read $ifcount interfaces from CCU ".$hash->{host});
		HMCCU_Log ($hash, 1, "HMCCU: Read $prgcount programs from CCU ".$hash->{host});
		HMCCU_Log ($hash, 1, "HMCCU: Read $gcount virtual groups from CCU ".$hash->{host});
		return 0;
	}
	else {
		HMCCU_Log ($hash, 1, "HMCCU: Error while reading device list from CCU ".$hash->{host});
		return 2;
	}
}

######################################################################
# Set or delete attribute
######################################################################

sub HMCCU_Attr ($@)
{
	my ($cmd, $name, $attrname, $attrval) = @_;
	my $hash = $defs{$name};
	my $rc = 0;

	if ($cmd eq 'set') {
		if ($attrname eq 'ccudefaults') {
			$rc = HMCCU_ImportDefaults ($attrval);
			return HMCCU_SetError ($hash, -16) if ($rc == 0);
			if ($rc < 0) {
				$rc = -$rc;
				return HMCCU_SetError ($hash,
					"Syntax error in default attribute file $attrval line $rc");
			}
		}
		elsif ($attrname eq 'ccuaggregate') {
			$rc = HMCCU_AggregationRules ($hash, $attrval);
			return HMCCU_SetError ($hash, "Syntax error in attribute ccuaggregate") if ($rc == 0);
		}
		elsif ($attrname eq 'ccuackstate') {
			return "HMCCU: Attribute ccuackstate is depricated. Use ccuflags with 'ackState' instead";
		}
		elsif ($attrname eq 'ccureadings') {
			return "HMCCU: Attribute ccureadings is depricated. Use ccuflags with 'noReadings' instead";
		}
		elsif ($attrname eq 'ccuflags') {
			my $ccuflags = AttrVal ($name, 'ccuflags', 'null');
			my @flags = ($attrval =~ /(intrpc|extrpc|procrpc)/g);
			return "Flags extrpc, procrpc and intrpc cannot be combined" if (scalar (@flags) > 1);
# 			if ($attrval =~ /(extrpc|intrpc|procrpc)/) {
# 				my $rpcmode = $1;
# 				if ($ccuflags !~ /$rpcmode/) { 
# 					return "Stop RPC server before switching RPC server"
# 						if (HMCCU_IsRPCServerRunning ($hash, undef, undef));
# 				}
# 			}
			if ($attrval =~ /(intrpc|extrpc)/) {
				HMCCU_Log ($hash, 1, "RPC server mode $1 no longer supported. Using procrpc instead");
				$attrval =~ s/(extrpc|intrpc)/procrpc/;
				$_[3] = $attrval;
			}
		}
		elsif ($attrname eq 'ccuGetVars') {
			my ($interval, $pattern) = split /:/, $attrval;
			$pattern = '.*' if (!defined ($pattern));
			$hash->{hmccu}{ccuvarspat} = $pattern;
			$hash->{hmccu}{ccuvarsint} = $interval;
			RemoveInternalTimer ($hash, "HMCCU_UpdateVariables");
			if ($interval > 0) {
				HMCCU_Log ($hash, 2, "Updating CCU system variables every $interval seconds");
				InternalTimer (gettimeofday()+$interval, "HMCCU_UpdateVariables", $hash);
			}
		}
		elsif ($attrname eq 'rpcdevice') {
			return "HMCCU: Attribute rpcdevice is depricated. Please remove it";
		}
		elsif ($attrname eq 'rpcinterfaces' || $attrname eq 'rpcport') {
			if ($hash->{hmccu}{ccu}{delayed} == 0) {
				my $msg = HMCCU_AttrInterfacesPorts ($hash, $attrname, $attrval);
				return $msg if ($msg ne '');
			}
		}
	}
	elsif ($cmd eq 'del') {
		if ($attrname eq 'ccuaggregate') {
			HMCCU_AggregationRules ($hash, '');			
		}
		elsif ($attrname eq 'ccuGetVars') {
			RemoveInternalTimer ($hash, "HMCCU_UpdateVariables");
		}
		elsif ($attrname eq 'rpcdevice') {
			delete $hash->{RPCDEV} if (exists ($hash->{RPCDEV}));
		}
		elsif ($attrname eq 'rpcport' || $attrname eq 'rpcinterfaces') {
			my ($defInterface, $defPort) = HMCCU_GetDefaultInterface ($hash);
			$hash->{hmccu}{rpcports} = undef;
			delete $attr{$name}{'rpcinterfaces'} if ($attrname eq 'rpcport');
			delete $attr{$name}{'rpcport'} if ($attrname eq 'rpcinterfaces');
		}
	}
	
	return undef;
}

######################################################################
# Set attributes rpcinterfaces and rpcport.
# Return empty string on success or error message on error.
######################################################################

sub HMCCU_AttrInterfacesPorts ($$$)
{
	my ($hash, $attr, $attrval) = @_;
	my $name = $hash->{NAME};
	
	if ($attr eq 'rpcinterfaces') {
		my @ilist = split (',', $attrval);
		my @plist = ();
		foreach my $p (@ilist) {
			my ($pn, $dc) = HMCCU_GetRPCServerInfo ($hash, $p, 'port,devcount');
			return "HMCCU: Illegal RPC interface $p" if (!defined ($pn));
			return "HMCCU: No devices assigned to interface $p" if ($dc == 0);
			push (@plist, $pn);
		}
		return "No RPC interface specified" if (scalar (@plist) == 0);
		$hash->{hmccu}{rpcports} = join (',', @plist);
		$attr{$name}{"rpcport"} = $hash->{hmccu}{rpcports};
	}
	elsif ($attr eq 'rpcport') {
		my @plist = split (',', $attrval);
		my @ilist = ();
		foreach my $p (@plist) {
			my ($in, $dc) = HMCCU_GetRPCServerInfo ($hash, $p, 'name,devcount');
			return "HMCCU: Illegal RPC port $p" if (!defined ($in));
			return "HMCCU: No devices assigned to interface $in" if ($dc == 0);
			push (@ilist, $in);
		}
		return "No RPC port specified" if (scalar (@ilist) == 0);
		$hash->{hmccu}{rpcports} = $attrval;
		$attr{$name}{"rpcinterfaces"} = join (',', @ilist);
	}
	
	return '';
}

######################################################################
# Parse aggregation rules for readings.
# Syntax of aggregation rule is:
# FilterSpec[;...]
# FilterSpec := {Name|Filt|Read|Cond|Else|Pref|Coll|Html}[,...]
# Name := name:Name
# Filt := filter:{name|type|group|room|alias}=Regexp[!Regexp]
# Read := read:Regexp
# Cond := if:{any|all|min|max|sum|avg|gt|lt|ge|le}=Value
# Else := else:Value
# Pref := prefix:{RULE|Prefix}
# Coll := coll:{NAME|Attribute}
# Html := html:Template
######################################################################

sub HMCCU_AggregationRules ($$)
{
	my ($hash, $rulestr) = @_;
	my $name = $hash->{NAME};

	# Delete existing aggregation rules
	if (exists ($hash->{hmccu}{agg})) {
		delete $hash->{hmccu}{agg};
	}
	return if ($rulestr eq '');
	
	my @pars = ('name', 'filter', 'if', 'else');

	# Extract aggregation rules
	my $cnt = 0;
	my @rules = split (/[;\n]+/, $rulestr);
	foreach my $r (@rules) {
		$cnt++;
		
		# Set default rule parameters. Can be modified later
		my %opt = ( 'read' => 'state', 'prefix' => 'RULE', 'coll' => 'NAME' );

		# Parse aggregation rule
		my @specs = split (',', $r);		
		foreach my $spec (@specs) {
			if ($spec =~ /^(name|filter|read|if|else|prefix|coll|html):(.+)$/) {
				$opt{$1} = $2;
			}
		}
		
		# Check if mandatory parameters are specified
		foreach my $p (@pars) {
			return HMCCU_Log ($hash, 1, "Parameter $p is missing in aggregation rule $cnt.")
				if (!exists ($opt{$p}));
		}
		
		my $fname = $opt{name};
		my ($fincl, $fexcl) = split ('!', $opt{filter});
		my ($ftype, $fexpr) = split ('=', $fincl);
		return 0 if (!defined ($fexpr));
		my ($fcond, $fval) = split ('=', $opt{if});
		return 0 if (!defined ($fval));
		my ($fcoll, $fdflt) = split ('!', $opt{coll});
		$fdflt = 'no match' if (!defined ($fdflt));
		my $fhtml = exists ($opt{'html'}) ? $opt{'html'} : '';
		
		# Read HTML template (optional)
		if ($fhtml ne '') {
			my %tdef;
			my @html;
			
			# Read template file
			if (open (TEMPLATE, "<$fhtml")) {
				@html = <TEMPLATE>;
				close (TEMPLATE);
			}
			else {
				return HMCCU_Log ($hash, 1, "Can't open file $fhtml.");
			}

			# Parse template
			foreach my $line (@html) {
				chomp $line;
				my ($key, $h) = split /:/, $line, 2;
				next if (!defined ($h) || $key =~ /^#/);
				$tdef{$key} = $h;
			}

			# Some syntax checks
			return HMCCU_Log ($hash, 1, "Missing definition row-odd in template file.")
				if (!exists ($tdef{'row-odd'}));

			# Set default values
			$tdef{'begin-html'} = '' if (!exists ($tdef{'begin-html'}));
			$tdef{'end-html'} = '' if (!exists ($tdef{'end-html'}));
			$tdef{'begin-table'} = "<table>" if (!exists ($tdef{'begin-table'}));
			$tdef{'end-table'} = "</table>" if (!exists ($tdef{'end-table'}));
			$tdef{'default'} = 'no data' if (!exists ($tdef{'default'}));;
			$tdef{'row-even'} = $tdef{'row-odd'} if (!exists ($tdef{'row-even'}));
			
			foreach my $t (keys %tdef) {
				$hash->{hmccu}{agg}{$fname}{fhtml}{$t} = $tdef{$t};
			}
		}

		$hash->{hmccu}{agg}{$fname}{ftype} = $ftype;
		$hash->{hmccu}{agg}{$fname}{fexpr} = $fexpr;
		$hash->{hmccu}{agg}{$fname}{fexcl} = (defined ($fexcl) ? $fexcl : '');
		$hash->{hmccu}{agg}{$fname}{fread} = $opt{'read'};
		$hash->{hmccu}{agg}{$fname}{fcond} = $fcond;
		$hash->{hmccu}{agg}{$fname}{ftrue} = $fval;
		$hash->{hmccu}{agg}{$fname}{felse} = $opt{'else'};
		$hash->{hmccu}{agg}{$fname}{fpref} = $opt{prefix} eq 'RULE' ? $fname : $opt{prefix};
		$hash->{hmccu}{agg}{$fname}{fcoll} = $fcoll;
		$hash->{hmccu}{agg}{$fname}{fdflt} = $fdflt;
	}
	
	return 1;
}

######################################################################
# Export default attributes.
######################################################################

sub HMCCU_ExportDefaults ($$)
{
	my ($filename, $all) = @_;

	return 0 if (!open (DEFFILE, ">$filename"));

	print DEFFILE "# HMCCU default attributes for channels\n";
	foreach my $t (keys %{$HMCCU_CHN_DEFAULTS}) {
		print DEFFILE "\nchannel:$t\n";
		foreach my $a (sort keys %{$HMCCU_CHN_DEFAULTS->{$t}}) {
			print DEFFILE "$a=".$HMCCU_CHN_DEFAULTS->{$t}{$a}."\n";
		}
	}

	print DEFFILE "\n# HMCCU default attributes for devices\n";
	foreach my $t (keys %{$HMCCU_DEV_DEFAULTS}) {
		print DEFFILE "\ndevice:$t\n";
		foreach my $a (sort keys %{$HMCCU_DEV_DEFAULTS->{$t}}) {
			print DEFFILE "$a=".$HMCCU_DEV_DEFAULTS->{$t}{$a}."\n";
		}
	}
	
	if ($all) {
		print DEFFILE "# HMCCU custom default attributes for channels\n";
		foreach my $t (keys %HMCCU_CUST_CHN_DEFAULTS) {
			print DEFFILE "\nchannel:$t\n";
			foreach my $a (sort keys %{$HMCCU_CUST_CHN_DEFAULTS{$t}}) {
				print DEFFILE "$a=".$HMCCU_CUST_CHN_DEFAULTS{$t}{$a}."\n";
			}
		}

		print DEFFILE "\n# HMCCU custom default attributes for devices\n";
		foreach my $t (keys %HMCCU_CUST_DEV_DEFAULTS) {
			print DEFFILE "\ndevice:$t\n";
			foreach my $a (sort keys %{$HMCCU_CUST_DEV_DEFAULTS{$t}}) {
				print DEFFILE "$a=".$HMCCU_CUST_DEV_DEFAULTS{$t}{$a}."\n";
			}
		}
	}

	close (DEFFILE);

	return 1;
}

######################################################################
# Export default attributes as CSV file.
######################################################################

sub HMCCU_ExportDefaultsCSV ($$)
{
	my ($filename, $all) = @_;
	
	my %attrlist = (
		'_type' => '', '_description' => '', '_channels' => '',
		'ccureadingfilter' => '', 'ccureadingname' => '', 'ccuscaleval' => '', 'cmdIcon' => '', 'controldatapoint' => '',
		'eventMap' => '', 'event-on-change-reading' => '', 'event-on-update-reading' => '', 
		'genericDeviceType' => '',
		'hmstatevals' => '',
		'statedatapoint' => '', 'statevals' => '', 'stripnumber' => '', 'substexcl' => '', 'substitute' => '',
		'webCmd' => '', 'widgetOverride' => ''
	);
	
	return 0 if (!open (DEFFILE, ">$filename"));

	# Write header
	print DEFFILE "_flag,".join (',', sort keys %attrlist)."\n";

	# Write channel configurations
	foreach my $t (keys %{$HMCCU_CHN_DEFAULTS}) {
		print DEFFILE "C";
		$attrlist{'_type'} = $t;
		foreach $a (sort keys %attrlist) {
			my $v = exists ($HMCCU_CHN_DEFAULTS->{$t}{$a}) ? $HMCCU_CHN_DEFAULTS->{$t}{$a} : $attrlist{$a};
			print DEFFILE ",\"$v\"";
		}
		print DEFFILE "\n";
	}

	# Write device configurations
	foreach my $t (keys %{$HMCCU_DEV_DEFAULTS}) {
		print DEFFILE "D";
		$attrlist{'_type'} = $t;
		foreach $a (sort keys %attrlist) {
			my $v = exists ($HMCCU_DEV_DEFAULTS->{$t}{$a}) ? $HMCCU_DEV_DEFAULTS->{$t}{$a} : $attrlist{$a};
			print DEFFILE ",\"$v\"";
		}
		print DEFFILE "\n";
	}
	
	if ($all) {
		# Write channel configurations
		foreach my $t (keys %HMCCU_CUST_CHN_DEFAULTS) {
			print DEFFILE "C";
			$attrlist{'_type'} = $t;
			foreach $a (sort keys %attrlist) {
				my $v = exists ($HMCCU_CUST_CHN_DEFAULTS{$t}{$a}) ? $HMCCU_CUST_CHN_DEFAULTS{$t}{$a} : $attrlist{$a};
				print DEFFILE ",\"$v\"";
			}
			print DEFFILE "\n";
		}

		# Write device configurations
		foreach my $t (keys %HMCCU_CUST_DEV_DEFAULTS) {
			print DEFFILE "D";
			$attrlist{'_type'} = $t;
			foreach $a (sort keys %attrlist) {
				my $v = exists ($HMCCU_CUST_DEV_DEFAULTS{$t}{$a}) ? $HMCCU_CUST_DEV_DEFAULTS{$t}{$a} : $attrlist{$a};
				print DEFFILE ",\"$v\"";
			}
			print DEFFILE "\n";
		}
	}

	close (DEFFILE);

	return 1;
}

######################################################################
# Import customer default attributes
# Returns 1 on success. Returns negative line number on syntax errors.
# Returns 0 on file open error.
######################################################################
 
sub HMCCU_ImportDefaults ($)
{
	my ($filename) = @_;
	my $modtype = '';
	my $ccutype = '';
	my $line = 0;

	return 0 if (!open (DEFFILE, "<$filename"));
	my @defaults = <DEFFILE>;
	close (DEFFILE);
	chomp (@defaults);

	%HMCCU_CUST_CHN_DEFAULTS = ();
	%HMCCU_CUST_DEV_DEFAULTS = ();
	
	foreach my $d (@defaults) {
		$line++;
		next if ($d eq '' || $d =~ /^#/);

		if ($d =~ /^(channel|device):/) {
			my @t = split (':', $d, 2);
			if (scalar (@t) != 2) {
				close (DEFFILE);
				return -$line;
			}
			$modtype = $t[0];
			$ccutype = $t[1];
			next;
		}

		if ($ccutype eq '' || $modtype eq '') {
			close (DEFFILE);
			return -$line;
		}

		my @av = split ('=', $d, 2);
		if (scalar (@av) != 2) {
			close (DEFFILE);
			return -$line;
		}

		if ($modtype eq 'channel') {
			$HMCCU_CUST_CHN_DEFAULTS{$ccutype}{$av[0]} = $av[1];
		}
		else {
			$HMCCU_CUST_DEV_DEFAULTS{$ccutype}{$av[0]} = $av[1];
		}
	}

	return 1;
}

######################################################################
# Find default attributes
# Return template reference.
######################################################################

sub HMCCU_FindDefaults ($$)
{
	my ($hash, $common) = @_;
	my $type = $hash->{TYPE};
	my $ccutype = $hash->{ccutype};

	if ($type eq 'HMCCUCHN') {
		my ($adr, $chn) = split (':', $hash->{ccuaddr});

		foreach my $deftype (keys %HMCCU_CUST_CHN_DEFAULTS) {
			my @chnlst = split (',', $HMCCU_CUST_CHN_DEFAULTS{$deftype}{_channels});
			return \%{$HMCCU_CUST_CHN_DEFAULTS{$deftype}}
				if ($ccutype =~ /^($deftype)$/i && grep { $_ eq $chn} @chnlst);
		}
		
		foreach my $deftype (keys %{$HMCCU_CHN_DEFAULTS}) {
			my @chnlst = split (',', $HMCCU_CHN_DEFAULTS->{$deftype}{_channels});
			return \%{$HMCCU_CHN_DEFAULTS->{$deftype}}
				if ($ccutype =~ /^($deftype)$/i && grep { $_ eq $chn} @chnlst);
		}
	}
	elsif ($type eq 'HMCCUDEV' || $type eq 'HMCCU') {
		foreach my $deftype (keys %HMCCU_CUST_DEV_DEFAULTS) {
			return \%{$HMCCU_CUST_DEV_DEFAULTS{$deftype}} if ($ccutype =~ /^($deftype)$/i);
		}

		foreach my $deftype (keys %{$HMCCU_DEV_DEFAULTS}) {
			return \%{$HMCCU_DEV_DEFAULTS->{$deftype}} if ($ccutype =~ /^($deftype)$/i);
		}
	}

	return undef;	
}

######################################################################
# Set default attributes from template
######################################################################

sub HMCCU_SetDefaultsTemplate ($$)
{
	my ($hash, $template) = @_;
	my $name = $hash->{NAME};
	
	foreach my $a (keys %{$template}) {
		next if ($a =~ /^_/);
		my $v = $template->{$a};
		CommandAttr (undef, "$name $a $v");
	}
}

######################################################################
# Set default attributes
######################################################################

sub HMCCU_SetDefaults ($)
{
	my ($hash) = @_;
	my $name = $hash->{NAME};

	# Set type specific attributes	
	my $template = HMCCU_FindDefaults ($hash, 0);
	return 0 if (!defined ($template));
	
	HMCCU_SetDefaultsTemplate ($hash, $template);
	return 1;
}

######################################################################
# List default attributes for device type (mode = 0) or all
# device types (mode = 1) with default attributes available.
######################################################################

sub HMCCU_GetDefaults ($$)
{
	my ($hash, $mode) = @_;
	my $name = $hash->{NAME};
	my $type = $hash->{TYPE};
	my $ccutype = $hash->{ccutype};
	my $result = '';
	my $deffile = '';
	
	if ($mode == 0) {
		my $template = HMCCU_FindDefaults ($hash, 0);
		return ($result eq '' ? "No default attributes defined" : $result) if (!defined ($template));
	
		foreach my $a (keys %{$template}) {
			next if ($a =~ /^_/);
			my $v = $template->{$a};
			$result .= $a." = ".$v."\n";
		}
	}
	else {
		$result = "HMCCU Channels:\n------------------------------\n";
		foreach my $deftype (sort keys %{$HMCCU_CHN_DEFAULTS}) {
			my $tlist = $deftype;
			$tlist =~ s/\|/,/g;
			$result .= $HMCCU_CHN_DEFAULTS->{$deftype}{_description}." ($tlist), channels ".
				$HMCCU_CHN_DEFAULTS->{$deftype}{_channels}."\n";
		}
		$result .= "\nHMCCU Devices:\n------------------------------\n";
		foreach my $deftype (sort keys %{$HMCCU_DEV_DEFAULTS}) {
			my $tlist = $deftype;
			$tlist =~ s/\|/,/g;
			$result .= $HMCCU_DEV_DEFAULTS->{$deftype}{_description}." ($tlist)\n";
		}
		$result .= "\nCustom Channels:\n-----------------------------\n";
		foreach my $deftype (sort keys %HMCCU_CUST_CHN_DEFAULTS) {
			my $tlist = $deftype;
			$tlist =~ s/\|/,/g;
			$result .= $HMCCU_CUST_CHN_DEFAULTS{$deftype}{_description}." ($tlist), channels ".
				$HMCCU_CUST_CHN_DEFAULTS{$deftype}{_channels}."\n";
		}
		$result .= "\nCustom Devices:\n-----------------------------\n";
		foreach my $deftype (sort keys %HMCCU_CUST_DEV_DEFAULTS) {
			my $tlist = $deftype;
			$tlist =~ s/\|/,/g;
			$result .= $HMCCU_CUST_DEV_DEFAULTS{$deftype}{_description}." ($tlist)\n";
		}
	}
	
	return $result;	
}

######################################################################
# Try to detect default attributes
######################################################################

sub HMCCU_DetectDefaults ($$)
{
	my ($hash, $object) = @_;
	
	my $response = HMCCU_GetDeviceInfo ($hash, $object, 'Value');
}

######################################################################
# Handle FHEM events
######################################################################

sub HMCCU_Notify ($$)
{
	my ($hash, $devhash) = @_;
	my $name = $hash->{NAME};
	my $devname = $devhash->{NAME};
	my $devtype = $devhash->{TYPE};

	my $disable = AttrVal ($name, 'disable', 0);
	my $rpcserver = AttrVal ($name, 'rpcserver', 'off');
	my $ccuflags = HMCCU_GetFlags ($name);

	return if ($disable);
		
	my $events = deviceEvents ($devhash, 1);
	return if (! $events);

	# Process events
	foreach my $event (@{$events}) {	
		if ($devname eq 'global') {
			if ($event eq 'INITIALIZED') {
				return if ($rpcserver eq 'off');
				my $delay = $hash->{ccustate} eq 'active' && $hash->{hmccu}{ccu}{delayed} == 0 ?
					$HMCCU_INIT_INTERVAL0 : $hash->{hmccu}{ccu}{delay}+$HMCCU_CCU_RPC_OFFSET;
				HMCCU_Log ($hash, 0, "Start of RPC server after FHEM initialization in $delay seconds");
# 				if ($ccuflags =~ /(extrpc|procrpc)/) {
					InternalTimer (gettimeofday()+$delay, "HMCCU_StartExtRPCServer", $hash, 0);
# 				}
# 				else {
# 					InternalTimer (gettimeofday()+$delay, "HMCCU_StartIntRPCServer", $hash, 0);
# 				}
			}
		}
		else {
			return if ($devtype ne 'HMCCUDEV' && $devtype ne 'HMCCUCHN');
			my ($r, $v) = split (": ", $event);
			return if (!defined ($v));
			return if ($ccuflags =~ /noagg/);

			foreach my $rule (keys %{$hash->{hmccu}{agg}}) {
				my $ftype = $hash->{hmccu}{agg}{$rule}{ftype};
				my $fexpr = $hash->{hmccu}{agg}{$rule}{fexpr};
				my $fread = $hash->{hmccu}{agg}{$rule}{fread};
				next if ($r !~ $fread);
				next if ($ftype eq 'name' && $devname !~ /$fexpr/);
				next if ($ftype eq 'type' && $devhash->{ccutype} !~ /$fexpr/);
				next if ($ftype eq 'group' && AttrVal ($devname, 'group', 'null') !~ /$fexpr/);
				next if ($ftype eq 'room' && AttrVal ($devname, 'room', 'null') !~ /$fexpr/);
				next if ($ftype eq 'alias' && AttrVal ($devname, 'alias', 'null') !~ /$fexpr/);
			
				HMCCU_AggregateReadings ($hash, $rule);
			}
		}
	}

	return;
}

######################################################################
# Enhance device details in FHEM WEB
######################################################################

sub HMCCU_Detail ($$$$)
{
	my ($FW_Name, $Device, $Room, $pageHash) = @_;
	my $hash = $defs{$Device};

	return defined ($hash->{host}) ? qq(
	<span class='mkTitle'>CCU Administration</span>
	<table class="block wide">
	<tr class="odd">
	<td><div class="col1">
	&gt; <a target="_blank" href="$hash->{prot}://$hash->{host}">CCU WebUI</a>
	</div></td>
	</tr>
	<tr class="odd">
	<td><div class="col1">
	&gt; <a target="_blank" href="$hash->{prot}://$hash->{host}/addons/cuxd/index.ccc">CUxD Config</a>
	</div></td>
	</tr>
	</table>
	) : '';
}

######################################################################
# Calculate reading aggregations.
# Called by Notify or via command get aggregation.
######################################################################

sub HMCCU_AggregateReadings ($$)
{
	my ($hash, $rule) = @_;
	
	my $dc = 0;
	my $mc = 0;
	my $result = '';
	my $rl = '';
	my $table = '';

	# Get rule parameters
	my $ftype = $hash->{hmccu}{agg}{$rule}{ftype};
	my $fexpr = $hash->{hmccu}{agg}{$rule}{fexpr};
	my $fexcl = $hash->{hmccu}{agg}{$rule}{fexcl};
	my $fread = $hash->{hmccu}{agg}{$rule}{fread};
	my $fcond = $hash->{hmccu}{agg}{$rule}{fcond};
	my $ftrue = $hash->{hmccu}{agg}{$rule}{ftrue};
	my $felse = $hash->{hmccu}{agg}{$rule}{felse};
	my $fpref = $hash->{hmccu}{agg}{$rule}{fpref};
	my $fhtml = exists ($hash->{hmccu}{agg}{$rule}{fhtml}) ? 1 : 0;

	my $resval;
	$resval = $ftrue if ($fcond =~ /^(max|min|sum|avg)$/);
	
	my @devlist = HMCCU_FindClientDevices ($hash, "(HMCCUDEV|HMCCUCHN)", undef, undef);
	foreach my $d (@devlist) {
		my $ch = $defs{$d};
		my $cn = $ch->{NAME};
		my $ct = $ch->{TYPE};
		
		my $fmatch = '';
		$fmatch = $cn if ($ftype eq 'name');
		$fmatch = $ch->{ccutype} if ($ftype eq 'type');
		$fmatch = AttrVal ($cn, 'group', '') if ($ftype eq 'group');
		$fmatch = AttrVal ($cn, 'room', '') if ($ftype eq 'room');
		$fmatch = AttrVal ($cn, 'alias', '') if ($ftype eq 'alias');		
		next if (!defined ($fmatch) || $fmatch eq '' || $fmatch !~ /$fexpr/ || ($fexcl ne '' && $fmatch =~ /$fexcl/));
		
		my $fcoll = $hash->{hmccu}{agg}{$rule}{fcoll} eq 'NAME' ?
			$cn : AttrVal ($cn, $hash->{hmccu}{agg}{$rule}{fcoll}, $cn);
		
		# Compare readings
		foreach my $r (keys %{$ch->{READINGS}}) {
			next if ($r !~ /$fread/);
			my $rv = $ch->{READINGS}{$r}{VAL};
			my $f = 0;
			
			if (($fcond eq 'any' || $fcond eq 'all') && $rv =~ /$ftrue/) {
				$mc++;
				$f = 1;
			}
			if ($fcond eq 'max' && $rv > $resval) {
				$resval = $rv;
				$mc = 1;
				$f = 1;
			}
			if ($fcond eq 'min' && $rv < $resval) {
				$resval = $rv;
				$mc = 1;
				$f = 1;
			}
			if ($fcond eq 'sum' || $fcond eq 'avg') {
				$resval += $rv;
				$mc++;
				$f = 1;
			}
			if (($fcond eq 'gt' && $rv > $ftrue) ||
			    ($fcond eq 'lt' && $rv < $ftrue) ||
			    ($fcond eq 'ge' && $rv >= $ftrue) ||
			    ($fcond eq 'le' && $rv <= $ftrue)) {
				$mc++;
				$f = 1;
			}
			if ($f) {
				$rl .= ($mc > 1 ? ",$fcoll" : $fcoll);
				last;
			}
		}
		$dc++;
	}
	
	$rl =  $hash->{hmccu}{agg}{$rule}{fdflt} if ($rl eq '');

	# HTML code generation
	if ($fhtml) {
		if ($rl ne '') {
			$table = $hash->{hmccu}{agg}{$rule}{fhtml}{'begin-html'}.
				$hash->{hmccu}{agg}{$rule}{fhtml}{'begin-table'};
			$table .= $hash->{hmccu}{agg}{$rule}{fhtml}{'header'}
				if (exists ($hash->{hmccu}{agg}{$rule}{fhtml}{'header'}));

			my $row = 1;
			foreach my $v (split (",", $rl)) {
				my $t_row = ($row % 2) ? $hash->{hmccu}{agg}{$rule}{fhtml}{'row-odd'} :
					$hash->{hmccu}{agg}{$rule}{fhtml}{'row-even'};
				$t_row =~ s/\<reading\/\>/$v/;
				$table .= $t_row;
				$row++;
			}

			$table .= $hash->{hmccu}{agg}{$rule}{fhtml}{'end-table'}.
				$hash->{hmccu}{agg}{$rule}{fhtml}{'end-html'};
		}
		else {
			$table = $hash->{hmccu}{agg}{$rule}{fhtml}{'begin-html'}.
				$hash->{hmccu}{agg}{$rule}{fhtml}{'default'}.
				$hash->{hmccu}{agg}{$rule}{fhtml}{'end-html'};
		}
	}

	if ($fcond eq 'any') {
		$result = $mc > 0 ? $ftrue : $felse;
	}
	elsif ($fcond eq 'all') {
		$result = $mc == $dc ? $ftrue : $felse;
	}
	elsif ($fcond eq 'min' || $fcond eq 'max' || $fcond eq 'sum') {
		$result = $mc > 0 ? $resval : $felse;
	}
	elsif ($fcond eq 'avg') {
		$result = $mc > 0 ? $resval/$mc : $felse;
	}
	elsif ($fcond =~ /^(gt|lt|ge|le)$/) {
		$result = $mc;
	}
	
	# Set readings
	readingsBeginUpdate ($hash);
	readingsBulkUpdate ($hash, $fpref.'state', $result);
	readingsBulkUpdate ($hash, $fpref.'match', $mc);
	readingsBulkUpdate ($hash, $fpref.'count', $dc);
	readingsBulkUpdate ($hash, $fpref.'list', $rl);
	readingsBulkUpdate ($hash, $fpref.'table', $table) if ($fhtml);
	readingsEndUpdate ($hash, 1);
	
	return $result;
}

######################################################################
# Delete device
######################################################################

sub HMCCU_Undef ($$)
{
	my ($hash, $arg) = @_;

#	HMCCU_Log ($hash, 3, "Undef()");

	# Shutdown RPC server
	HMCCU_Shutdown ($hash);

	# Delete reference to IO module in client devices
	my @keylist = keys %defs;
	foreach my $d (@keylist) {
		if (exists ($defs{$d}) && exists($defs{$d}{IODev}) &&
		    $defs{$d}{IODev} == $hash) {
        		delete $defs{$d}{IODev};
		}
	}

	return undef;
}

######################################################################
# Delayed shutdown FHEM
######################################################################

sub HMCCU_DelayedShutdown ($)
{
	my ($hash) = @_;
	my $name = $hash->{NAME};
	
#	HMCCU_Log ($hash, 3, "DelayedShutdown()");
	
	my $delay = max (AttrVal ("global", "maxShutdownDelay", 10)-2, 0);

	# Shutdown RPC server
	if (!exists ($hash->{hmccu}{delayedShutdown})) {
		$hash->{hmccu}{delayedShutdown} = $delay;
		HMCCU_Log ($hash, 1, "Graceful shutdown in $delay seconds");
# 		if (HMCCU_IsFlag ($name, "(extrpc|procrpc)")) {
			HMCCU_StopExtRPCServer ($hash, 0);
# 		}
# 		else {
# 			HMCCU_StopRPCServer ($hash);
# 		}
	}
	else {
		HMCCU_Log ($hash, 1, "Graceful shutdown already in progress");
	}
	
	return 1;
}

######################################################################
# Shutdown FHEM
######################################################################

sub HMCCU_Shutdown ($)
{
	my ($hash) = @_;
	my $name = $hash->{NAME};

#	HMCCU_Log ($hash, 3, "Shutdown()");

	# Shutdown RPC server
	if (!exists ($hash->{hmccu}{delayedShutdown})) {
		HMCCU_Log ($hash, 1, "Immediate shutdown");
# 		if (HMCCU_IsFlag ($name, "(extrpc|procrpc)")) {
			HMCCU_StopExtRPCServer ($hash, 0);
# 		}
# 		else {
# 			HMCCU_StopRPCServer ($hash);
# 		}
	}
	else {
		HMCCU_Log ($hash, 1, "Graceful shutdown");
	}
		
	# Remove existing timer functions
	RemoveInternalTimer ($hash);

	return undef;
}

######################################################################
# Set commands
######################################################################

sub HMCCU_Set ($@)
{
	my ($hash, $a, $h) = @_;
	my $name = shift @$a;
	my $opt = shift @$a;
	my $options = "var clear delete execute hmscript cleardefaults:noArg datapoint defaults:noArg ".
		"importdefaults rpcregister:all rpcserver:on,off,restart ackmessages:noArg authentication ".
		"prgActivate prgDeactivate";

	return "No set command specified" if (!defined ($opt));
	
	my @ifList = HMCCU_GetRPCInterfaceList ($hash);
	if (scalar (@ifList) > 0) {
		my $ifStr = join (',', @ifList);
		$options =~ s/rpcregister:all/rpcregister:all,$ifStr/;
	}
	my $host = $hash->{host};

	$options = "initialize:noArg" if (exists ($hash->{hmccu}{ccu}{delayed}) &&
		$hash->{hmccu}{ccu}{delayed} == 1 && $hash->{ccustate} eq 'unreachable');
#	return undef if ($hash->{ccustate} ne 'active');
	return "HMCCU: CCU busy, choose one of rpcserver:off"
		if ($opt ne 'rpcserver' && HMCCU_IsRPCStateBlocking ($hash));

	my $usage = "HMCCU: Unknown argument $opt, choose one of $options";

	my $ccuflags = HMCCU_GetFlags ($name);
	my $stripchar = AttrVal ($name, "stripchar", '');
	my $ccureadings = AttrVal ($name, "ccureadings", $ccuflags =~ /noReadings/ ? 0 : 1);
	my $ccureqtimeout = AttrVal ($name, "ccuReqTimeout", $HMCCU_TIMEOUT_REQUEST);
	my $readingformat = HMCCU_GetAttrReadingFormat ($hash, $hash);
	my $substitute = HMCCU_GetAttrSubstitute ($hash, $hash);
	my $result;

	# Add program names to command execute
	if (exists ($hash->{hmccu}{prg})) {
		my @progs = ();
		my @aprogs = ();
		my @iprogs = ();
		foreach my $p (keys %{$hash->{hmccu}{prg}}) {
			if ($hash->{hmccu}{prg}{$p}{internal} eq 'false' && $p !~ /^\$/) {
				push (@progs, $p);
				push (@aprogs, $p) if ($hash->{hmccu}{prg}{$p}{active} eq 'true');
				push (@iprogs, $p) if ($hash->{hmccu}{prg}{$p}{active} eq 'false');
			}
		}
		if (scalar (@progs) > 0) {
			my $prgopt = "execute:".join(',', @progs);
			my $prgact = "prgActivate:".join(',', @iprogs);
			my $prgdac = "prgDeactivate:".join(',', @aprogs);
			$options =~ s/execute/$prgopt/;
			$options =~ s/prgActivate/$prgact/;
			$options =~ s/prgDeactivate/$prgdac/;
			$usage =~ s/execute/$prgopt/;
			$usage =~ s/prgActivate/$prgact/;
			$usage =~ s/prgDeactivate/$prgdac/;
		}
	}
	
	if ($opt eq 'var') {
		my $vartype;
		$vartype = shift @$a if (scalar (@$a) == 3);
		my $objname = shift @$a;
		my $objvalue = shift @$a;
		$usage = "set $name $opt [{'bool'|'list'|'number'|'text'}] variable value [param=value [...]]";
		
		return HMCCU_SetError ($hash, $usage) if (!defined ($objvalue));

		$objname =~ s/$stripchar$// if ($stripchar ne '');
		$objvalue =~ s/\\_/%20/g;
		$h->{name} = $objname if (!defined ($h) && defined ($vartype));
		
		$result = HMCCU_SetVariable ($hash, $objname, $objvalue, $vartype, $h);

		return HMCCU_SetError ($hash, $result) if ($result < 0);
		return HMCCU_SetState ($hash, "OK");
	}
	elsif ($opt eq 'initialize') {
		return HMCCU_SetError ($hash, "State of CCU must be unreachable")
			if ($hash->{ccustate} ne 'unreachable');
		my $err = HMCCU_InitDevice ($hash);
		return HMCCU_SetError ($hash, "CCU not reachable") if ($err == 1);
		return HMCCU_SetError ($hash, "Can't read device list from CCU") if ($err == 2);
		return HMCCU_SetState ($hash, "OK");
	}
	elsif ($opt eq 'authentication') {
		my $username = shift @$a;
		my $password = shift @$a;
		$usage = "set $name $opt username password";

		if (!defined ($username)) {
			setKeyValue ($name."_username", undef);
			setKeyValue ($name."_password", undef);
			return "Credentials for CCU authentication deleted";
		}
		
		return HMCCU_SetError ($hash, $usage) if (!defined ($password));

		my $encuser = HMCCU_Encrypt ($username);
		my $encpass = HMCCU_Encrypt ($password);
		return HMCCU_SetError ($hash, "Encryption of credentials failed") if ($encuser eq '' || $encpass eq '');
		
		my $err = setKeyValue ($name."_username", $encuser);
		return HMCCU_SetError ($hash, "Can't store credentials. $err") if (defined ($err));
		$err = setKeyValue ($name."_password", $encpass);
		return HMCCU_SetError ($hash, "Can't store credentials. $err") if (defined ($err));
		
		return "Credentials for CCU authentication stored";			
	}
	elsif ($opt eq 'clear') {
		my $rnexp = shift @$a;
		HMCCU_DeleteReadings ($hash, $rnexp);
		return HMCCU_SetState ($hash, "OK");
	}
	elsif ($opt eq 'datapoint') {
		$usage = "set $name $opt DevSpec [Channel].Datapoint=Value [...]\n";
		my $devSpec = shift @$a;
		
		return HMCCU_SetError ($hash, $usage) if (scalar (keys %$h) < 1 || !defined($devSpec));

		my $cmd = 1;
		my %dpValues;
		
		my @devList = devspec2array ($devSpec);
		return HMCCU_SetError ($hash, "No FHEM device matching $devSpec in command set datapoint")
			if (scalar (@devList) == 0);
		
		foreach my $dptSpec (keys %$h) {
			my $adr;
			my $chn;
			my $dpt;
			my ($t1, $t2) = split (/\./, $dptSpec);
			
			foreach my $devName (@devList) {
				my $dh = $defs{$devName};
				my $ccuif = $dh->{ccuif};

				if ($dh->{TYPE} eq 'HMCCUCHN') {
					if (defined ($t2)) {
						HMCCU_Log ($hash, 3, "Ignored channel in set datapoint for device $devName");
						$dpt = $t2;
					}
					else {
						$dpt = $t1;
					}
					($adr, $chn) = HMCCU_SplitChnAddr ($dh->{ccuaddr});
				}
				elsif ($dh->{TYPE} eq 'HMCCUDEV') {
					return HMCCU_SetError ($hash, "Missing channel number for device $devName")
						if (!defined ($t2));
					return HMCCU_SetError ($hash, "Invalid channel number specified for device $devName")
						if ($t1 !~ /^[0-9]+$/ || $t1 > $dh->{channels});
					$adr = $dh->{ccuaddr};
					$chn = $t1;
					$dpt = $t2;
				}
				else {
					return HMCCU_SetError ($hash, "FHEM device $devName has illegal type");
				}

				return HMCCU_SetError ($hash, "Invalid datapoint $dpt specified for device $devName")
					if (!HMCCU_IsValidDatapoint ($dh, $dh->{ccutype}, $chn, $dpt, 2));
				
				my $statevals = AttrVal ($dh->{NAME}, 'statevals', '');

				my $no = sprintf ("%03d", $cmd);
				$dpValues{"$no.$ccuif.$devName:$chn.$dpt"} = HMCCU_Substitute ($h->{$dptSpec}, $statevals, 1, undef, '');
				$cmd++;
			}
		}
		
		my $rc = HMCCU_SetMultipleDatapoints ($hash, \%dpValues);
		return HMCCU_SetError ($hash, $rc) if ($rc < 0);
		return HMCCU_SetState ($hash, "OK");		
	}
	elsif ($opt eq 'delete') {
		my $objname = shift @$a;
		my $objtype = shift @$a;
		$objtype = "OT_VARDP" if (!defined ($objtype));
		$usage = "Usage: set $name $opt ccuobject ['OT_VARDP'|'OT_DEVICE']";

		return HMCCU_SetError ($hash, $usage)
			if (!defined ($objname) || $objtype !~ /^(OT_VARDP|OT_DEVICE)$/);
		
		$result = HMCCU_HMScriptExt ($hash, "!DeleteObject", { name => $objname, type => $objtype },
			undef, undef);

		return HMCCU_SetError ($hash, -2) if ($result =~ /^ERROR:.*/);
		return HMCCU_SetState ($hash, "OK");
	}
	elsif ($opt eq 'execute') {
		my $program = shift @$a;
		$program .= ' '.join(' ', @$a) if (scalar (@$a) > 0);
		my $response;
		$usage = "Usage: set $name $opt program-name";

		return HMCCU_SetError ($hash, $usage) if (!defined ($program));

		my $cmd = qq(dom.GetObject("$program").ProgramExecute());
		my $value = HMCCU_HMCommand ($hash, $cmd, 1);
		
		return HMCCU_SetState ($hash, "OK") if (defined ($value));
		return HMCCU_SetError ($hash, "Program execution error");
	}
	elsif ($opt eq 'prgActivate' || $opt eq 'prgDeactivate') {
		my $program = shift @$a;
		my $mode = $opt eq 'prgActivate' ? 'true' : 'false';
		$usage = "Usage: set $name $opt program-name";
		
		return HMCCU_SetError ($hash, $usage) if (!defined ($program));
		
		$result = HMCCU_HMScriptExt ($hash, "!ActivateProgram", { name => $program, mode => $mode },
			undef, undef);

		return HMCCU_SetError ($hash, -2) if ($result =~ /^ERROR:.*/);
		return HMCCU_SetState ($hash, "OK");	
	}
	elsif ($opt eq 'hmscript') {
		my $script = shift @$a;
		my $dump = shift @$a;
		my $response = '';
		my %objects = ();
		my $objcount = 0;
		$usage = "Usage: set $name $opt {file|!function|'['code']'} ['dump'] [parname=value [...]]";
		
		# If no parameter is specified list available script functions
		if (!defined ($script)) {
			$response = "Available HomeMatic script functions:\n".
							"-------------------------------------\n";
			foreach my $scr (keys %{$HMCCU_SCRIPTS}) {
				$response .= "$scr ".$HMCCU_SCRIPTS->{$scr}{syntax}."\n".
					$HMCCU_SCRIPTS->{$scr}{description}."\n\n";
			}
			
			$response .= $usage;
			return $response;
		}
		
		return HMCCU_SetError ($hash, $usage) if (defined ($dump) && $dump ne 'dump');

		# Execute script
		$response = HMCCU_HMScriptExt ($hash, $script, $h, undef, undef);
		return HMCCU_SetError ($hash, -2, $response) if ($response =~ /^ERROR:/);

		HMCCU_SetState ($hash, "OK");
		return $response if (! $ccureadings || defined ($dump));

		foreach my $line (split /[\n\r]+/, $response) {
			my @tokens = split /=/, $line;
			next if (@tokens != 2);
			my $reading;
			my ($int, $add, $chn, $dpt, $nam, $flags) = HMCCU_ParseObject ($hash, $tokens[0],
				$HMCCU_FLAG_INTERFACE);
			($add, $chn) = HMCCU_GetAddress ($hash, $nam, '', '') if ($flags == $HMCCU_FLAGS_NCD);
			
			if ($flags == $HMCCU_FLAGS_IACD || $flags == $HMCCU_FLAGS_NCD) {
				$objects{$add}{$chn}{$dpt} = $tokens[1];
				$objcount++;
			}
			else {
				# If output is not related to a channel store reading in I/O device
				my $Value = HMCCU_Substitute ($tokens[1], $substitute, 0, undef, $tokens[0]);
				my $rn = HMCCU_CorrectName ($tokens[0]);
				readingsSingleUpdate ($hash, $rn, $Value, 1);
			}
		}
		
		HMCCU_UpdateMultipleDevices ($hash, \%objects) if ($objcount > 0);

		return defined ($dump) ? $response : undef;
	}
	elsif ($opt eq 'rpcregister') {
# 		return HMCCU_SetError ($hash, "HMCCU: Command not supported by internal RPC server")
# 			if ($ccuflags !~ /procrpc/);
			
		my $ifName = shift @$a;
		$result = '';
		@ifList = (defined ($ifName) && $ifName ne 'all') ? ($ifName) : HMCCU_GetRPCInterfaceList ($hash);
		
		foreach my $i (@ifList) {
			my ($rpcdev, $save) = HMCCU_GetRPCDevice ($hash, 0, $i);
			if ($rpcdev eq '') {
				HMCCU_Log ($hash, 2, "Can't find HMCCURPCPROC device for interface $i");
				next;
			}
			my $res = AnalyzeCommandChain (undef, "set $rpcdev register");
			$result .= $res if (defined ($res));
		}
		return HMCCU_SetState ($hash, "OK", $result);
	}
	elsif ($opt eq 'rpcserver') {
		my $action = shift @$a;
		$action = shift @$a if ($action eq $opt);
		$usage = "Usage: set $name $opt {'on'|'off'|'restart'}";

		return HMCCU_SetError ($hash, $usage)
			if (!defined ($action) || $action !~ /^(on|off|restart)$/);
		   
		if ($action eq 'on') {
# 			if ($ccuflags =~ /(extrpc|procrpc)/) {
				return HMCCU_SetError ($hash, "Start of RPC server failed")
				   if (!HMCCU_StartExtRPCServer ($hash));
# 			}
# 			else {
# 				return HMCCU_SetError ($hash, "Start of RPC server failed")
# 				   if (!HMCCU_StartIntRPCServer ($hash));
# 			}
		}
		elsif ($action eq 'off') {
# 			if ($ccuflags =~ /(extrpc|procrpc)/) {
				return HMCCU_SetError ($hash, "Stop of RPC server failed")
					if (!HMCCU_StopExtRPCServer ($hash));
# 			}
# 			else {
# 				return HMCCU_SetError ($hash, "Stop of RPC server failed")
# 					if (!HMCCU_StopRPCServer ($hash));
# 			}
		}
		elsif ($action eq 'restart') {
			return "HMCCU: No RPC server running" if (!HMCCU_IsRPCServerRunning ($hash, undef, undef));
			
# 			if ($ccuflags !~ /(extrpc|procrpc)/) {
# 				return "HMCCU: Can't stop RPC server" if (!HMCCURPC_StopRPCServer ($hash));
# 				HMCCU_SetRPCState ($hash, 'restarting');
# 				DoTrigger ($name, "RPC server restarting");
# 			}
# 			else {
				return HMCCU_SetError ($hash, "HMCCU: restart not supported by external RPC server");
# 			}
		}
		
		return HMCCU_SetState ($hash, "OK");
	}
	elsif ($opt eq 'ackmessages') {
		my $response = HMCCU_HMScriptExt ($hash, "!ClearUnreachable", undef, undef, undef);
		return HMCCU_SetError ($hash, -2, $response) if ($response =~ /^ERROR:/);
		return HMCCU_SetState ($hash, "OK", "Unreach errors in CCU cleared");
	}
	elsif ($opt eq 'defaults') {
		my $rc = HMCCU_SetDefaults ($hash);
		return HMCCU_SetError ($hash, "HMCCU: No default attributes found") if ($rc == 0);
		return HMCCU_SetState ($hash, "OK");
	}
	elsif ($opt eq 'cleardefaults') {
		%HMCCU_CUST_CHN_DEFAULTS = ();
		%HMCCU_CUST_DEV_DEFAULTS = ();
		
		return HMCCU_SetState ($hash, "OK", "Default attributes deleted");
	}
	elsif ($opt eq 'importdefaults') {
		my $filename = shift @$a;
		$usage = "Usage: set $name $opt filename";

		return HMCCU_SetError ($hash, $usage) if (!defined ($filename));
			
		my $rc = HMCCU_ImportDefaults ($filename);
		return HMCCU_SetError ($hash, -16) if ($rc == 0);
		if ($rc < 0) {
			$rc = -$rc;
			return HMCCU_SetError ($hash, "Syntax error in default attribute file $filename line $rc");
		}
		
		return HMCCU_SetState ($hash, "OK", "Default attributes read from file $filename");
	}
	else {
		return $usage;
	}
}

######################################################################
# Get commands
######################################################################

sub HMCCU_Get ($@)
{
	my ($hash, $a, $h) = @_;
	my $name = shift @$a;
	my $opt = shift @$a;

	return "No get command specified" if (!defined ($opt));

	my $options = "defaults:noArg exportdefaults devicelist dump dutycycle:noArg vars update".
		" updateccu configdesc firmware rpcevents:noArg rpcstate:noArg deviceinfo".
		" ccumsg:alarm,service";
	my $usage = "HMCCU: Unknown argument $opt, choose one of $options";
	my $host = $hash->{host};

	return undef if ($hash->{hmccu}{ccu}{delayed} || $hash->{ccustate} ne 'active');
	return "HMCCU: CCU busy, choose one of rpcstate:noArg"
		if ($opt ne 'rpcstate' && HMCCU_IsRPCStateBlocking ($hash));

	my $ccuflags = HMCCU_GetFlags ($name);
	my $ccureadings = AttrVal ($name, "ccureadings", $ccuflags =~ /noReadings/ ? 0 : 1);

	my $readname;
	my $readaddr;
	my $result = '';
	my $rc;

	if ($opt eq 'dump') {
		my $content = shift @$a;
		my $filter = shift @$a;
		$filter = '.*' if (!defined ($filter));
		$usage = "Usage: get $name dump {'datapoints'|'devtypes'} [filter]";
		
		my %foper = (1, "R", 2, "W", 4, "E", 3, "RW", 5, "RE", 6, "WE", 7, "RWE");
		my %ftype = (2, "B", 4, "F", 16, "I", 20, "S");
		
		return HMCCU_SetError ($hash, $usage) if (!defined ($content));
		
		if ($content eq 'devtypes') {
			foreach my $devtype (sort keys %{$hash->{hmccu}{dp}}) {
				$result .= $devtype."\n" if ($devtype =~ /$filter/);
			}
		}
		elsif ($content eq 'datapoints') {
			foreach my $devtype (sort keys %{$hash->{hmccu}{dp}}) {
				next if ($devtype !~ /$filter/);
				foreach my $chn (sort keys %{$hash->{hmccu}{dp}{$devtype}{ch}}) {
					foreach my $dpt (sort keys %{$hash->{hmccu}{dp}{$devtype}{ch}{$chn}}) {
						my $t = $hash->{hmccu}{dp}{$devtype}{ch}{$chn}{$dpt}{type};
						my $o = $hash->{hmccu}{dp}{$devtype}{ch}{$chn}{$dpt}{oper};
						$result .= $devtype.".".$chn.".".$dpt." [".
						   (exists($ftype{$t}) ? $ftype{$t} : $t)."] [".
						   (exists($foper{$o}) ? $foper{$o} : $o)."]\n";
					}
				}
			}
		}
		else {
			return HMCCU_SetError ($hash, $usage);
		}
		
		return HMCCU_SetState ($hash, "OK", ($result eq '') ? "No data found" : $result);
	}
	elsif ($opt eq 'vars') {
		my $varname = shift @$a;
		$usage = "Usage: get $name vars {regexp}[,...]";
		return HMCCU_SetError ($hash, $usage) if (!defined ($varname));

		($rc, $result) = HMCCU_GetVariables ($hash, $varname);
		return HMCCU_SetError ($hash, $rc, $result) if ($rc < 0);

		return HMCCU_SetState ($hash, "OK", $ccureadings ? undef : $result);
	}
	elsif ($opt eq 'update' || $opt eq 'updateccu') {
		my $devexp = shift @$a;
		$devexp = '.*' if (!defined ($devexp));
		$usage = "Usage: get $name $opt [device-expr [{'State'|'Value'}]]";
		my $ccuget = shift @$a;
		$ccuget = 'Attr' if (!defined ($ccuget));
		return HMCCU_SetError ($hash, $usage) if ($ccuget !~ /^(Attr|State|Value)$/);
		my $nonBlocking = HMCCU_IsFlag ($name, 'nonBlocking') ? 1 : 0;

		HMCCU_UpdateClients ($hash, $devexp, $ccuget, ($opt eq 'updateccu') ? 1 : 0, undef, 0);
		return HMCCU_SetState ($hash, "OK");
	}
	elsif ($opt eq 'deviceinfo') {
		my $device = shift @$a;
		$usage = "Usage: get $name $opt device [{'State'|'Value'}]";

		return HMCCU_SetError ($hash, $usage) if (!defined ($device));

		my $ccuget = shift @$a;
		$ccuget = 'Attr' if (!defined ($ccuget));
		return HMCCU_SetError ($hash, $usage) if ($ccuget !~ /^(Attr|State|Value)$/);

		return HMCCU_SetError ($hash, -1) if (!HMCCU_IsValidDeviceOrChannel ($hash, $device, $HMCCU_FL_ALL));
		$result = HMCCU_GetDeviceInfo ($hash, $device, $ccuget);
		return HMCCU_SetError ($hash, -2) if ($result eq '' || $result =~ /^ERROR:.*/);
		HMCCU_SetState ($hash, "OK");
		return HMCCU_FormatDeviceInfo ($result);
	}
	elsif ($opt eq 'rpcevents') {
# 		if ($ccuflags =~ /(extrpc|procrpc)/) {
			$result = '';
			my @iflist = HMCCU_GetRPCInterfaceList ($hash);
			foreach my $ifname (@iflist) {
				my ($rpcdev, $save) = HMCCU_GetRPCDevice ($hash, 0, $ifname);
				if ($rpcdev eq '') {
					HMCCU_Log ($hash, 2, "Can't find HMCCURPCPROC device for interface $ifname");
					next;
				}
				my $res = AnalyzeCommandChain (undef, "get $rpcdev rpcevents");
				$result .= $res if (defined ($result));
			}
			return HMCCU_SetState ($hash, "OK", $result) if ($result ne '');
			return HMCCU_SetError ($hash, "No event statistics available");
# 		}
# 		else {
# 			return HMCCU_SetError ($hash, "No event statistics available")
# 				if (!exists ($hash->{hmccu}{evs}) || !exists ($hash->{hmccu}{evr}));
# 			foreach my $stkey (sort keys %{$hash->{hmccu}{evr}}) {
# 				$result .= "S: ".$stkey." = ".$hash->{hmccu}{evs}{$stkey}."\n";
# 				$result .= "R: ".$stkey." = ".$hash->{hmccu}{evr}{$stkey}."\n";
# 			}
# 			return HMCCU_SetState ($hash, "OK", $result);
# 		}
	}
	elsif ($opt eq 'rpcstate') {
		my @hm_pids = ();
		my @hm_tids = ();
		$result = "No RPC processes or threads are running";

		if (HMCCU_IsRPCServerRunning ($hash, \@hm_pids, \@hm_tids)) {
			$result = "RPC process(es) running with pid(s) ".
				join (',', @hm_pids) if (scalar (@hm_pids) > 0);
			$result = "RPC thread(s) running with tid(s) ".
				join (',', @hm_tids) if (scalar (@hm_tids) > 0);
		}
		
		return HMCCU_SetState ($hash, "OK", $result);
	}
	elsif ($opt eq 'devicelist') {
		my ($devcount, $chncount, $ifcount, $prgcount, $gcount) = HMCCU_GetDeviceList ($hash);
		return HMCCU_SetError ($hash, -2) if ($devcount < 0);
		return HMCCU_SetError ($hash, "No devices received from CCU") if ($devcount == 0);
		$result = "Read $devcount devices with $chncount channels from CCU";

		my $optcmd = shift @$a;
		if (defined ($optcmd)) {
			if ($optcmd eq 'dump') {
				$result .= "\n-----------------------------------------\n";
				my $n = 0;
				foreach my $add (sort keys %{$hash->{hmccu}{dev}}) {
					if ($hash->{hmccu}{dev}{$add}{addtype} eq 'dev') {
						$result .= "Device ".'"'.$hash->{hmccu}{dev}{$add}{name}.'"'." [".$add."] ".
							"Type=".$hash->{hmccu}{dev}{$add}{type}."\n";
						$n = 0;
					}
					else {
						$result .= "  Channel $n ".'"'.$hash->{hmccu}{dev}{$add}{name}.'"'.
							" [".$add."]\n";
						$n++;
					}
				}
				return $result;
			}
			elsif ($optcmd eq 'create') {
				$usage = "Usage: get $name create {devexp|chnexp} [t={'chn'|'dev'|'all'}] [s=suffix] ".
					"[p=prefix] [f=format] ['defattr'] ['duplicates'] [save] [attr=val [...]]";
				my $devdefaults = 0;
				my $duplicates = 0;
				my $savedef = 0;
				my $newcount = 0;

				# Process command line parameters				
				my $devspec = shift @$a;
				my $devprefix = exists ($h->{p})   ? $h->{p}   : '';
				my $devsuffix = exists ($h->{'s'}) ? $h->{'s'} : '';
				my $devtype   = exists ($h->{t})   ? $h->{t}   : 'dev';
				my $devformat = exists ($h->{f})   ? $h->{f}   : '%n';
				return HMCCU_SetError ($hash, $usage)
					if ($devtype !~ /^(dev|chn|all)$/ || !defined ($devspec));
				foreach my $defopt (@$a) {
					if ($defopt eq 'defattr') { $devdefaults = 1; }
					elsif ($defopt eq 'duplicates') { $duplicates = 1; }
					elsif ($defopt eq 'save') { $savedef = 1; }
					else { return HMCCU_SetError ($hash, $usage); }
				}

				# Get list of existing client devices
				my @devlist = HMCCU_FindClientDevices ($hash, "(HMCCUDEV|HMCCUCHN)", undef, undef);

				foreach my $add (sort keys %{$hash->{hmccu}{dev}}) {
					my $defmod = $hash->{hmccu}{dev}{$add}{addtype} eq 'dev' ? 'HMCCUDEV' : 'HMCCUCHN';
					my $ccuname = $hash->{hmccu}{dev}{$add}{name};	
					my $ccudevname = HMCCU_GetDeviceName ($hash, $add, $ccuname);
					next if ($devtype ne 'all' && $devtype ne $hash->{hmccu}{dev}{$add}{addtype});
					next if (HMCCU_ExprNotMatch ($ccuname, $devspec, 1));
					
					# Build FHEM device name
					my $devname = $devformat;
					$devname = $devprefix.$devname.$devsuffix;
					$devname =~ s/%n/$ccuname/g;
					$devname =~ s/%d/$ccudevname/g;
					$devname =~ s/%a/$add/g;
					$devname =~ s/[^A-Za-z\d_\.]+/_/g;
					
					# Check for duplicate device definitions
					if (!$duplicates) {
						next if (exists ($defs{$devname}));
						my $devexists = 0;
						foreach my $exdev (@devlist) {
							if ($defs{$exdev}->{ccuaddr} eq $add) {
								$devexists = 1;
								last;
							}
						}
						next if ($devexists);
					}
					
					# Define new client device
					my $ret = CommandDefine (undef, $devname." $defmod ".$add);
					if ($ret) {
						HMCCU_Log ($hash, 2, "Define command failed $devname $defmod $ccuname. $ret");
						$result .= "\nCan't create device $devname. $ret";
						next;
					}
					
					# Set device attributes
					HMCCU_SetDefaults ($defs{$devname}) if ($devdefaults);
					foreach my $da (keys %$h) {
						next if ($da =~ /^[pstf]$/);
						$ret = CommandAttr (undef, "$devname $da ".$h->{$da});
						HMCCU_Log ($hash, 2, "Attr command failed $devname $da ".$h->{$da}.". $ret")
							if ($ret);
					}
					HMCCU_Log ($hash, 2, "Created device $devname");
					$result .= "\nCreated device $devname";
					$newcount++;
				}

				CommandSave (undef, undef) if ($newcount > 0 && $savedef);				
				$result .= "\nCreated $newcount client devices";
			}
		}

		return HMCCU_SetState ($hash, "OK", $result);
	}
	elsif ($opt eq 'dutycycle') {
		my $dc = HMCCU_GetDutyCycle ($hash);
		return HMCCU_SetState ($hash, "OK");
	}
	elsif ($opt eq 'firmware') {
		my $devtype = shift @$a;
		$devtype = '.*' if (!defined ($devtype));
		my $dtexp = $devtype;
		$dtexp = '.*' if ($devtype eq 'full');
		my $dc = HMCCU_GetFirmwareVersions ($hash, $dtexp);
		return "Found no firmware downloads" if ($dc == 0);
		$result = "Found $dc firmware downloads. Click on the new version number for download\n\n";
		if ($devtype eq 'full') {
			$result .= 
				"Type                 Available Date\n".
				"-----------------------------------------\n"; 
			foreach my $ct (keys %{$hash->{hmccu}{type}}) {
				$result .= sprintf "%-20s <a href=\"http://www.eq-3.de/%s\">%-9s</a> %-10s\n",
					$ct, $hash->{hmccu}{type}{$ct}{download},
					$hash->{hmccu}{type}{$ct}{firmware}, $hash->{hmccu}{type}{$ct}{date};
			}
		}
		else {
			my @devlist = HMCCU_FindClientDevices ($hash, "(HMCCUDEV|HMCCUCHN)", undef, undef);
			return $result if (scalar (@devlist) == 0);
			$result .= 
				"Device                    Type                 Current Available Date\n".
				"---------------------------------------------------------------------------\n"; 
			foreach my $dev (@devlist) {
				my $ch = $defs{$dev};
				my $ct = uc($ch->{ccutype});
				my $fw = defined ($ch->{firmware}) ? $ch->{firmware} : 'N/A';
				next if (!exists ($hash->{hmccu}{type}{$ct}) || $ct !~ /$dtexp/);
				$result .= sprintf "%-25s %-20s %-7s <a href=\"http://www.eq-3.de/%s\">%-9s</a> %-10s\n",
					$ch->{NAME}, $ct, $fw, $hash->{hmccu}{type}{$ct}{download},
					$hash->{hmccu}{type}{$ct}{firmware}, $hash->{hmccu}{type}{$ct}{date};
			}
		}
				
		return HMCCU_SetState ($hash, "OK", $result);
	}
	elsif ($opt eq 'defaults') {
		$result = HMCCU_GetDefaults ($hash, 1);
		return HMCCU_SetState ($hash, "OK", $result);
	}
	elsif ($opt eq 'exportdefaults') {
		my $filename = shift @$a;
		$usage = "Usage: get $name $opt filename ['all'] ['csv']";	
		my $csv = 0;
		my $all = 0;
		
		foreach my $defopt (@$a) {
			if ($defopt eq 'csv') { $csv = 1; }
			elsif ($defopt eq 'all') { $all = 1; }
			else { return HMCCU_SetError ($hash, $usage); }
		}
		
		return HMCCU_SetError ($hash, $usage) if (!defined ($filename));

		my $rc = $csv ? HMCCU_ExportDefaultsCSV ($filename, $all) : HMCCU_ExportDefaults ($filename, $all);
		return HMCCU_SetError ($hash, -16) if ($rc == 0);
		return HMCCU_SetState ($hash, "OK", "Default attributes written to $filename");
	}
	elsif ($opt eq 'aggregation') {
		my $rule = shift @$a;
		$usage = "Usage: get $name $opt {'all'|'rule'}";	
		return HMCCU_SetError ($hash, $usage) if (!defined ($rule));
			
		if ($rule eq 'all') {
			foreach my $r (keys %{$hash->{hmccu}{agg}}) {
				my $rc = HMCCU_AggregateReadings ($hash, $r);
				$result .= "$r = $rc\n";
			}
		}
		else {
			return HMCCU_SetError ($hash, "HMCCU: Aggregation rule does not exist")
				if (!exists ($hash->{hmccu}{agg}{$rule}));
			$result = HMCCU_AggregateReadings ($hash, $rule);
			$result = "$rule = $result";			
		}

		return HMCCU_SetState ($hash, "OK", $ccureadings ? undef : $result);
	}
	elsif ($opt eq 'configdesc') {
		my $ccuobj = shift @$a;
		$usage = "Usage: get $name $opt {device|channel}";
		return HMCCU_SetError ($hash, $usage) if (!defined ($ccuobj));

		my $res = "MASTER:\n";
		my ($rc, $result) = HMCCU_RPCRequest ($hash, "getParamsetDescription", $ccuobj, "MASTER", undef);
		return HMCCU_SetError ($hash, $rc, $result) if ($rc < 0);
		$res .= "$result\nLINK:\n";
		($rc, $result) = HMCCU_RPCRequest ($hash, "getParamsetDescription", $ccuobj, "LINK", undef);
		return HMCCU_SetError ($hash, $rc, $result) if ($rc < 0);
		$res .= $result;
		return HMCCU_SetState ($hash, "OK", $res);
	}
	elsif ($opt eq 'ccumsg') {
		my $msgtype = shift @$a;
		$usage = "Usage: get $name $opt {service|alarm}";
		return HMCCU_SetError ($hash, $usage) if (!defined ($msgtype));

		my $script = ($msgtype eq 'service') ? "!GetServiceMessages" : "!GetAlarms";
		my $res = HMCCU_HMScriptExt ($hash, $script, undef, undef, undef);
		
		return HMCCU_SetError ($hash, "Error") if ($res eq '' || $res =~ /^ERROR:.*/);
		
		# Generate event for each message
		foreach my $msg (split /[\n\r]+/, $res) {
			next if ($msg =~ /^[0-9]+$/);
			DoTrigger ($name, $msg);
		}
		
		return HMCCU_SetState ($hash, "OK", $res);
	}
	else {
		if (exists ($hash->{hmccu}{agg})) {
			my @rules = keys %{$hash->{hmccu}{agg}};
			$usage .= " aggregation:all,".join (',', @rules) if (scalar (@rules) > 0);
		}
		return $usage;
	}
}

######################################################################
# Parse CCU object specification.
#
# Supported address types:
#   Classic Homematic and Homematic-IP addresses.
#   Team addresses with leading * for BidCos-RF.
#   CCU virtual remote addresses (BidCoS:ChnNo)
#   OSRAM lightify addresses (OL-...)
#   Homematic virtual layer addresses (if known by HMCCU)
#
# Possible syntax for datapoints:
#   Interface.Address:Channel.Datapoint
#   Address:Channel.Datapoint
#   Channelname.Datapoint
#
# Possible syntax for channels:
#   Interface.Address:Channel
#   Address:Channel
#   Channelname
#
# If object name doesn't match the rules above it's treated as name.
# With parameter flags one can specify if result is filled up with
# default values for interface or datapoint.
#
# Return list of detected attributes (empty string if attribute is
# not detected):
#   (Interface, Address, Channel, Datapoint, Name, Flags)
#   Flags is a bitmask of detected attributes.
######################################################################

sub HMCCU_ParseObject ($$$)
{
	my ($hash, $object, $flags) = @_;
	my ($i, $a, $c, $d, $n, $f) = ('', '', '', '', '', '', 0);
	my $extaddr;
	
	my ($defInterface, $defPort) = HMCCU_GetDefaultInterface ($hash);
	
	# "ccu:" is default. Remove it.
	$object =~ s/^ccu://g;
	
	# Check for FHEM device
	if ($object =~ /^hmccu:/) {
		my ($hmccu, $fhdev, $fhcdp) = split(':', $object);
		return ($i, $a, $c, $d, $n, $f) if (!defined ($fhdev));
		my $cl_hash = $defs{$fhdev};
		return ($i, $a, $c, $d, $n, $f) if (!defined ($cl_hash) ||
			($cl_hash->{TYPE} ne 'HMCCUDEV' && $cl_hash->{TYPE} ne 'HMCCUCHN'));
		$object = $cl_hash->{ccuaddr};
		$object .= ":$fhcdp" if (defined ($fhcdp));
	}
	
	# Check if address is already known by HMCCU. Substitute device address by ZZZ0000000
	# to allow external addresses like HVL
	if ($object =~ /^.+\.(.+):[0-9]{1,2}\..+$/ ||
		$object =~ /^.+\.(.+):[0-9]{1,2}$/ ||
		$object =~ /^(.+):[0-9]{1,2}\..+$/ ||
		$object =~ /^(.+):[0-9]{1,2}$/ ||
		$object =~ /^(.+)$/) {
		$extaddr = $1;
		if (!HMCCU_IsDevAddr ($extaddr, 0) &&
			exists ($hash->{hmccu}{dev}{$extaddr}) && $hash->{hmccu}{dev}{$extaddr}{valid}) {
			$object =~ s/$extaddr/$HMCCU_EXT_ADDR/;
		}
	}

	if ($object =~ /^(.+?)\.([\*]*[A-Z]{3}[0-9]{7}):([0-9]{1,2})\.(.+)$/ ||
		$object =~ /^(.+?)\.([0-9A-F]{12,14}):([0-9]{1,2})\.(.+)$/ ||
		$object =~ /^(.+?)\.(OL-.+):([0-9]{1,2})\.(.+)$/ ||
		$object =~ /^(.+?)\.(BidCoS-RF):([0-9]{1,2})\.(.+)$/) {
		#
		# Interface.Address:Channel.Datapoint [30=11110]
		#
		$f = $HMCCU_FLAGS_IACD;
		($i, $a, $c, $d) = ($1, $2, $3, $4);
	}
	elsif ($object =~ /^(.+)\.([\*]*[A-Z]{3}[0-9]{7}):([0-9]{1,2})$/ ||
		$object =~ /^(.+)\.([0-9A-F]{12,14}):([0-9]{1,2})$/ ||
		$object =~ /^(.+)\.(OL-.+):([0-9]{1,2})$/ ||
		$object =~ /^(.+)\.(BidCoS-RF):([0-9]{1,2})$/) {
		#
		# Interface.Address:Channel [26=11010]
		#
		$f = $HMCCU_FLAGS_IAC | ($flags & $HMCCU_FLAG_DATAPOINT);
		($i, $a, $c, $d) = ($1, $2, $3, $flags & $HMCCU_FLAG_DATAPOINT ? '.*' : '');
	}
	elsif ($object =~ /^([\*]*[A-Z]{3}[0-9]{7}):([0-9]{1,2})\.(.+)$/ ||
		$object =~ /^([0-9A-F]{12,14}):([0-9]{1,2})\.(.+)$/ ||
		$object =~ /^(OL-.+):([0-9]{1,2})\.(.+)$/ ||
		$object =~ /^(BidCoS-RF):([0-9]{1,2})\.(.+)$/) {
		#
		# Address:Channel.Datapoint [14=01110]
		#
		$f = $HMCCU_FLAGS_ACD;
		($a, $c, $d) = ($1, $2, $3);
	}
	elsif ($object =~ /^([\*]*[A-Z]{3}[0-9]{7}):([0-9]{1,2})$/ ||
		$object =~ /^([0-9A-Z]{12,14}):([0-9]{1,2})$/ ||
		$object =~ /^(OL-.+):([0-9]{1,2})$/ ||
		$object =~ /^(BidCoS-RF):([0-9]{1,2})$/) {
		#
		# Address:Channel [10=01010]
		#
		$f = $HMCCU_FLAGS_AC | ($flags & $HMCCU_FLAG_DATAPOINT);
		($a, $c, $d) = ($1, $2, $flags & $HMCCU_FLAG_DATAPOINT ? '.*' : '');
	}
	elsif ($object =~ /^([\*]*[A-Z]{3}[0-9]{7})$/ ||
		$object =~ /^([0-9A-Z]{12,14})$/ ||
		$object =~ /^(OL-.+)$/ ||
		$object eq 'BidCoS') {
		#
		# Address
		#
		$f = $HMCCU_FLAG_ADDRESS;
		$a = $1;
	}
	elsif ($object =~ /^(.+?)\.([A-Z_]+)$/) {
		#
		# Name.Datapoint
		#
		$f = $HMCCU_FLAGS_ND;
		($n, $d) = ($1, $2);
	}
	elsif ($object =~ /^.+$/) {
		#
		# Name [1=00001]
		#
		$f = $HMCCU_FLAG_NAME | ($flags & $HMCCU_FLAG_DATAPOINT);
		($n, $d) = ($object, $flags & $HMCCU_FLAG_DATAPOINT ? '.*' : '');
	}
	else {
		$f = 0;
	}
	
	# Restore external address (i.e. HVL device address)
	$a = $extaddr if ($a eq $HMCCU_EXT_ADDR);

	# Check if name is a valid channel name
	if ($f & $HMCCU_FLAG_NAME) {
		my ($add, $chn) = HMCCU_GetAddress ($hash, $n, '', '');
		if ($chn ne '') {
			$f = $f | $HMCCU_FLAG_CHANNEL;
		}
		if ($flags & $HMCCU_FLAG_FULLADDR) {
			($i, $a, $c) = (HMCCU_GetDeviceInterface ($hash, $add, $defInterface), $add, $chn);
			$f |= $HMCCU_FLAG_INTERFACE;
			$f |= $HMCCU_FLAG_ADDRESS if ($add ne '');
			$f |= $HMCCU_FLAG_CHANNEL if ($chn ne '');
		}
	}
	elsif ($f & $HMCCU_FLAG_ADDRESS && $i eq '' &&
	   ($flags & $HMCCU_FLAG_FULLADDR || $flags & $HMCCU_FLAG_INTERFACE)) {
		$i = HMCCU_GetDeviceInterface ($hash, $a, $defInterface);
		$f |= $HMCCU_FLAG_INTERFACE;
	}

	return ($i, $a, $c, $d, $n, $f);
}

######################################################################
# Filter reading by datapoint and optionally by channel name or
# channel address.
# Parameter channel can be a channel name or a channel address without
# interface specification.
# Filter rule syntax is either:
#   [N:]{Channel-Number|Channel-Name-Expr}!Datapoint-Expr
# or
#   [N:][Channel-Number.]Datapoint-Expr
# Multiple filter rules must be separated by ;
######################################################################
 
sub HMCCU_FilterReading ($$$)
{
	my ($hash, $chn, $dpt) = @_;
	my $name = $hash->{NAME};
	my $fnc = "FilterReading";

	my $hmccu_hash = HMCCU_GetHash ($hash);
	return 1 if (!defined ($hmccu_hash));

	my $grf = AttrVal ($hmccu_hash->{NAME}, 'ccudef-readingfilter', '.*');
	my $rf = AttrVal ($name, 'ccureadingfilter', $grf);
	$rf = $grf.";".$rf if ($rf ne $grf && $grf ne '.*');

	my $chnnam = '';
	my $chnnum = '';
	my $devadd = '';

	# Get channel name and channel number
	if (HMCCU_IsValidChannel ($hmccu_hash, $chn, $HMCCU_FL_ADDRESS)) {
		$chnnam = HMCCU_GetChannelName ($hmccu_hash, $chn, '');
		($devadd, $chnnum) = HMCCU_SplitChnAddr ($chn);
	}
	else {
		($devadd, $chnnum) = HMCCU_GetAddress ($hash, $chn, '', '');
		$chnnam = $chn;
	}
 
 	HMCCU_Trace ($hash, 2, $fnc, "chn=$chn, chnnam=$chnnam chnnum=$chnnum dpt=$dpt, rules=$rf");
       
	foreach my $r (split (';', $rf)) {
		my $rm = 1;
		my $cn = '';
		
		# Negative filter
		if ($r =~ /^N:/) {
			$rm = 0;
			$r =~ s/^N://;
		}
		
		# Get filter criteria
		my ($c, $f) = split ("!", $r);
		if (defined ($f)) {
			next if ($c eq '' || $chnnam eq '' || $chnnum eq '');
			$cn = $c if ($c =~ /^([0-9]{1,2})$/);
		}
		else {
			$c = '';
			if ($r =~ /^([0-9]{1,2})\.(.+)$/) {
				$cn = $1;
				$f = $2;
			}
			else {
				$cn = '';
				$f = $r;
			}
		}

		HMCCU_Trace ($hash, 2, undef, "    check rm=$rm f=$f cn=$cn c=$c");
		# Positive filter
		return 1 if (
			$rm && (
				(
					($cn ne '' && "$chnnum" eq "$cn") ||
					($c ne '' && $chnnam =~ /$c/) ||
					($cn eq '' && $c eq '')
				) && $dpt =~ /$f/
			)
		);
		# Negate filter
		return 1 if (
			!$rm && (
				($cn ne '' && "$chnnum" ne "$cn") ||
				($c ne '' && $chnnam !~ /$c/) ||
				$dpt !~ /$f/
			)
		);
		HMCCU_Trace ($hash, 2, undef, "    check result false");
	}

	return 0;
}

######################################################################
# Build reading name
#
# Parameters:
#
#   Interface,Address,ChannelNo,Datapoint,ChannelNam,Format
#   Format := { name[lc] | datapoint[lc] | address[lc] | formatStr }
#   formatStr := Any text containing at least one format pattern
#   pattern := { %a, %c, %n, %d, %A, %C, %N, %D }
#
# Valid combinations:
#
#   ChannelName,Datapoint
#   Address,Datapoint
#   Address,ChannelNo,Datapoint
#
# Reading names can be modified or new readings can be added by
# setting attribut ccureadingname.
# Returns list of readings names.
######################################################################

sub HMCCU_GetReadingName ($$$$$$$)
{
	my ($hash, $i, $a, $c, $d, $n, $rf) = @_;
	my $name = $hash->{NAME};

	my $ioHash = HMCCU_GetHash ($hash);
	return '' if (!defined ($ioHash));
	
	my $rn = '';
	my @rnlist;

#	Log3 $name, 1, "HMCCU: ChannelNo undefined: Addr=".$a if (!defined ($c));

	$rf = HMCCU_GetAttrReadingFormat ($hash, $ioHash) if (!defined ($rf));
	my $gsr = AttrVal ($ioHash->{NAME}, 'ccudef-readingname', '');
	my $sr = AttrVal ($name, 'ccureadingname', $gsr);
	$sr .= ";".$gsr if ($sr ne $gsr && $gsr ne '');
	
	# Datapoint is mandatory
	return '' if ($d eq '');

	# Complete missing values
	$c = '' if (!defined ($c));
	$i = '' if (!defined ($i));
	if ($n eq '' && $a ne '') {
		$n = ($c ne '') ?
			HMCCU_GetChannelName ($ioHash, $a.':'.$c, '') :
			HMCCU_GetDeviceName ($ioHash, $a, '');
	}
	elsif ($n ne '' && $a eq '') {
		($a, $c) = HMCCU_GetAddress ($ioHash, $n, '', '');
	}
	if ($i eq '' && $a ne '') {
		$i = HMCCU_GetDeviceInterface ($ioHash, $a, '');
	}
			
	if ($rf eq 'datapoint' || $rf =~ /^datapoint(lc|uc)$/) {
		$rn = $c ne '' ? $c.'.'.$d : $d;
	}
	elsif ($rf eq 'name' || $rf =~ /^name(lc|uc)$/) {
		return '' if ($n eq '');
		$rn = $n.'.'.$d;
	}
	elsif ($rf eq 'address' || $rf =~ /^address(lc|uc)$/) {
		return '' if ($a eq '');
		my $t = $a;
		$t = $i.'.'.$t if ($i ne '');
		$t = $t.'.'.$c if ($c ne '');
		$rn = $t.'.'.$d;
	}
	elsif ($rf =~ /\%/) {
		$rn = $1;
		$rn =~ s/\%a/lc($a)/ge if ($a ne '');
		$rn =~ s/\%A/uc($a)/ge if ($a ne '');
		$rn =~ s/\%n/lc($n)/ge if ($n ne '');
		$rn =~ s/\%N/uc($n)/ge if ($n ne '');
		$rn =~ s/\%c/lc($c)/ge if ($c ne '');
		$rn =~ s/\%C/uc($c)/ge if ($c ne '');
		$rn =~ s/\%d/lc($d)/ge;
		$rn =~ s/\%D/uc($d)/ge;
	}
	
	push (@rnlist, $rn);
	
	# Rename and/or add reading names
	if ($sr ne '') {
		my @rules = split (';', $sr);
		foreach my $rr (@rules) {
			my ($rold, $rnew) = split (':', $rr);
			next if (!defined ($rnew));
			my @rnewList = split (',', $rnew);
			next if (scalar (@rnewList) < 1);
			if ($rnlist[0] =~ /$rold/) {
				foreach my $rnew (@rnewList) {
					if ($rnew =~ /^\+(.+)$/) {
						my $radd = $1;
						$radd =~ s/$rold/$radd/;
						push (@rnlist, $radd);
					}
					else {
						$rnlist[0] =~ s/$rold/$rnew/;
						last;
					}
				}
			}
		}
	}
	
	# Convert to lower or upper case
	$rnlist[0] = lc($rnlist[0]) if ($rf =~ /^(datapoint|name|address)lc$/);
	$rnlist[0] = uc($rnlist[0]) if ($rf =~ /^(datapoint|name|address)uc$/);

	# Return array of corrected reading names
	return map { HMCCU_CorrectName ($_) } @rnlist;
}

######################################################################
# Format reading value depending on attribute stripnumber.
# Syntax of attribute stripnumber:
#   [datapoint-expr!]format[;...]
# Valid formats:
#   0 = Remove all digits
#   1 = Preserve 1 digit
#   2 = Remove trailing zeroes
#   -n = Round value to specified number of digits (-0 is allowed)
#   %f = Format for numbers. String suffix is allowed.
######################################################################

sub HMCCU_FormatReadingValue ($$$)
{
	my ($hash, $value, $dpt) = @_;
	my $name = $hash->{NAME};
	my $fnc = "FormatReadingValue";

	my $stripnumber = HMCCU_GetAttrStripNumber ($hash);
	
	if ($stripnumber ne 'null' && $value =~ /^[+-]?\d*\.?\d+(?:(?:e|E)\d+)?$/) {
		my $isint = $value =~ /^[+-]?[0-9]+$/ ? 1 : 0;
	
		foreach my $sr (split (';', $stripnumber)) {
			my ($d, $s) = split ('!', $sr);
			if (defined ($s)) {
				next if ($d eq '' || $dpt !~ /$d/);
			}
			else {
				$s = $sr;
			}
		
			if ($s eq '0' && !$isint)             { return sprintf ("%d", $value); }
			elsif ($s eq '1' && !$isint)          { return sprintf ("%.1f", $value); }
			elsif ($s eq '2' && !$isint)          { return sprintf ("%g", $value); }
			elsif ($s =~ /^-([0-9])$/ && !$isint) { my $f = '%.'.$1.'f'; return sprintf ($f, $value); }
			elsif ($s =~ /^%.+$/)                 { return sprintf ($s, $value); }
		}
	
		HMCCU_Trace ($hash, 2, $fnc, "sn = $stripnumber, dpt=$dpt, isint=$isint, value $value not changed");	
	}
	else {
		my $h = unpack "H*", $value;
		HMCCU_Trace ($hash, 2, $fnc, "sn = $stripnumber, Value $value $h not changed");
	}

	return $value;
}

######################################################################
# Log message if trace flag is set.
# Will output multiple log file entries if parameter msg is separated
# by <br>
######################################################################

sub HMCCU_Trace ($$$$)
{
	my ($hash, $level, $fnc, $msg) = @_;
	my $name = $hash->{NAME};
	my $type = $hash->{TYPE};
	
	return if (!HMCCU_IsFlag ($name, "trace"));	
	
	foreach my $m (split ("<br>", $msg)) {
		$m = "[$name] $fnc: $m" if (defined ($fnc) && $fnc ne '');	
		Log3 $name, $level, "$type: $m";
	}
}

######################################################################
# Log message with module type, device name and process id.
# Return parameter rc or 0.
# Parameter source can be a device hash reference, a string reference
# or a string.
######################################################################

sub HMCCU_Log ($$$;$)
{
	my ($source, $level, $msg, $rc) = @_;
	
	my $r = ref($source);
	my $pid = $$;
	my $name = "n/a";
	my $type = "n/a";

	$rc = 0 if (!defined($rc));
	if ($r eq 'HASH') {
		$name = $source->{NAME} if (exists ($source->{NAME}));
		$type = $source->{TYPE} if (exists ($source->{TYPE}));
	}
	elsif ($r eq 'SCALAR') {
		$name = $$source;
		$type = $defs{$name}->{TYPE} if (exists ($defs{$name}));
	}
	else {
		$name = $source;
		$type = $defs{$name}->{TYPE} if (exists ($defs{$name}));
	}

	Log3 $name, $level, "$type: [$name : $pid] $msg";
	
	return $rc;
}

######################################################################
# Log message and return message preceded by string "ERROR: ".
######################################################################

sub HMCCU_LogError ($$$)
{
	my ($hash, $level, $msg) = @_;
	
	HMCCU_Log ($hash, $level, $msg, undef);
	
	return "ERROR: $msg";
}

######################################################################
# Set error state and write log file message
# Parameter text can be an error code (integer <= 0) or an error text.
# If text is 0 or 'OK' call HMCCU_SetState which returns undef.
# Otherwise error message is returned.
# Parameter addinfo is optional.
######################################################################

sub HMCCU_SetError ($@)
{
	my ($hash, $text, $addinfo) = @_;
	my $name = $hash->{NAME};
	my $type = $hash->{TYPE};
	my $msg;
	my %errlist = (
	   -1 => 'Invalid device/channel name or address',
	   -2 => 'Execution of CCU script or command failed',
	   -3 => 'Cannot detect IO device',
	   -4 => 'Device deleted in CCU',
	   -5 => 'No response from CCU',
	   -6 => 'Update of readings disabled. Set attribute ccureadings first',
	   -7 => 'Invalid channel number',
	   -8 => 'Invalid datapoint',
	   -9 => 'Interface does not support RPC calls',
	   -10 => 'No readable datapoints found',
	   -11 => 'No state channel defined',
	   -12 => 'No control channel defined',
	   -13 => 'No state datapoint defined',
	   -14 => 'No control datapoint defined',
	   -15 => 'No state values defined',
	   -16 => 'Cannot open file',
	   -17 => 'Cannot detect or create external RPC device',
	   -18 => 'Type of system variable not supported',
	   -19 => 'Device not initialized',
	   -20 => 'Invalid or unknown device interface',
	   -21 => 'Device disabled'
	);

	if ($text ne 'OK' && $text ne '0') {
		$msg = exists ($errlist{$text}) ? $errlist{$text} : $text;
		$msg = $type.": ".$name." ". $msg;
		if (defined ($addinfo) && $addinfo ne '') {
			$msg .= ". $addinfo";
		}
		HMCCU_Log ($hash, 1, $msg);
		return HMCCU_SetState ($hash, "Error", $msg);
	}
	else {
		return HMCCU_SetState ($hash, "OK");
	}
}

######################################################################
# Set state of device if attribute ccuflags = ackState
# Return undef or $retval
######################################################################

sub HMCCU_SetState ($@)
{
	my ($hash, $text, $retval) = @_;
	my $name = $hash->{NAME};

	my $ccuflags = HMCCU_GetFlags ($name);
	$ccuflags .= ',ackState' if ($hash->{TYPE} eq 'HMCCU' && $ccuflags !~ /ackState/);
	
	if (defined ($hash) && defined ($text) && $ccuflags =~ /ackState/) {
		readingsSingleUpdate ($hash, 'state', $text, 1)
			if (ReadingsVal ($name, 'state', '') ne $text);
	}

	return $retval;
}

######################################################################
# Set state of RPC server. Update all client devices if overall state
# is 'running'.
# Parameters iface and msg are optional. If iface is set function
# was called by HMCCURPCPROC device.
######################################################################

sub HMCCU_SetRPCState ($@)
{
	my ($hash, $state, $iface, $msg) = @_;
	my $name = $hash->{NAME};

	my $ccuflags = HMCCU_GetFlags ($name);
	my $filter;
	my $rpcstate = $state;
	
# 	if ($ccuflags =~ /intrpc/ || $ccuflags !~ /(intrpc|extrpc|procrpc)/) {
# 		if ($state ne $hash->{RPCState}) {
# 			$hash->{RPCState} = $state;
# 			readingsSingleUpdate ($hash, "rpcstate", $state, 1);
# 			HMCCU_Log ($hash, 4, "Set rpcstate to $state");
# 			HMCCU_Log ($hash, 1, $msg) if (defined ($msg));
# 			HMCCU_Log ($hash, 1, "All RPC servers $state");
# 			DoTrigger ($name, "RPC server $state");
# 			if ($state eq 'running') {
# 				HMCCU_UpdateClients ($hash, '.*', 'Value', 0, $filter, 1);
# 			}
# 		}
# 	}
# 	elsif (defined ($iface) && $ccuflags =~ /(procrpc|extrpc)/) {
	if (defined ($iface)) {
		# Set interface state
		my ($ifname) = HMCCU_GetRPCServerInfo ($hash, $iface, 'name');
		$hash->{hmccu}{interfaces}{$ifname}{state} = $state if (defined ($ifname));
		
		# Count number of processes in state running, error or inactive
		# Prepare filter for updating client devices
		my %stc = ("running" => 0, "error" => 0, "inactive" => 0);
		my @iflist = HMCCU_GetRPCInterfaceList ($hash);
		foreach my $i (@iflist) {
			my $st = $hash->{hmccu}{interfaces}{$i}{state};
			$stc{$st}++ if (exists ($stc{$st}));
			if ($hash->{hmccu}{interfaces}{$i}{manager} eq 'HMCCU' && $ccuflags !~ /noInitialUpdate/) {
				my $rpcFlags = AttrVal ($hash->{hmccu}{interfaces}{$i}{device}, 'ccuflags', 'null');
				if ($rpcFlags !~ /noInitialUpdate/) {
					$filter = defined ($filter) ? "$filter|$i" : $i;
				}
			}
		}
		
		# Determine overall process state
		my $rpcstate = 'null';
		$rpcstate = "running" if ($stc{"running"} == scalar (@iflist));
		$rpcstate = "inactive" if ($stc{"inactive"} == scalar (@iflist));
		$rpcstate = "error" if ($stc{"error"} == scalar (@iflist));

		if ($rpcstate =~ /^(running|inactive|error)$/) {
			if ($rpcstate ne $hash->{RPCState}) {
				$hash->{RPCState} = $rpcstate;
				readingsSingleUpdate ($hash, "rpcstate", $rpcstate, 1);
				HMCCU_Log ($hash, 4, "Set rpcstate to $rpcstate");
				HMCCU_Log ($hash, 1, $msg, undef) if (defined ($msg));
				HMCCU_Log ($hash, 1, "All RPC servers $rpcstate");
				DoTrigger ($name, "RPC server $rpcstate");
				if ($rpcstate eq 'running' && defined ($filter)) {
					HMCCU_UpdateClients ($hash, '.*', 'Value', 0, $filter, 1);
				}
			}
		}
	}

	# Set I/O device state
	if ($rpcstate eq 'running' || $rpcstate eq 'inactive') {
		HMCCU_SetState ($hash, "OK");
	}
	elsif ($rpcstate eq 'error') {
		HMCCU_SetState ($hash, "error");
	}
	else {
		HMCCU_SetState ($hash, "busy");
	}
	
	return undef;
}

######################################################################
# Substitute first occurrence of regular expression or fixed string.
# Floating point values are ignored without datapoint specification.
# Integer values are compared with complete value.
# mode: 0=Substitute regular expression, 1=Substitute text
######################################################################

sub HMCCU_Substitute ($$$$$)
{
	my ($value, $substrule, $mode, $chn, $dpt) = @_;
	my $rc = 0;
	my $newvalue;

	return $value if (!defined ($substrule) || $substrule eq '');

	# Remove channel number from datapoint if specified
	if ($dpt =~ /^([0-9]{1,2})\.(.+)$/) {
		($chn, $dpt) = ($1, $2);
	}

	my @rulelist = split (';', $substrule);
	foreach my $rule (@rulelist) {
		my @ruletoks = split ('!', $rule);
		if (@ruletoks == 2 && $dpt ne '' && $mode == 0) {
			my @dptlist = split (',', $ruletoks[0]);
			foreach my $d (@dptlist) {
				my $c = -1;
				if ($d =~ /^([0-9]{1,2})\.(.+)$/) {
					($c, $d) = ($1, $2);
				}
				if ($d eq $dpt && ($c == -1 || !defined($chn) || $c == $chn)) {
					($rc, $newvalue) = HMCCU_SubstRule ($value, $ruletoks[1], $mode);
					return $newvalue;
				}
			}
		}
		elsif (@ruletoks == 1) {
			return $value if ($value !~ /^[+-]?\d+$/ && $value =~ /^[+-]?\d*\.?\d+(?:(?:e|E)\d+)?$/);
			($rc, $newvalue) = HMCCU_SubstRule ($value, $ruletoks[0], $mode);
			return $newvalue if ($rc == 1);
		}
	}

	return $value;
}

######################################################################
# Execute substitution list.
# Syntax for single substitution: {#n-n|regexp|text}:newtext
#   mode=0: Substitute regular expression
#   mode=1: Substitute text (for setting statevals)
# newtext can contain ':'. Parameter ${value} in newtext is
# substituted by original value.
# Return (status, value)
#   status=1: value = substituted value
#   status=0: value = original value
######################################################################

sub HMCCU_SubstRule ($$$)
{
	my ($value, $substitutes, $mode ) = @_;
	my $rc = 0;

	$substitutes =~ s/\$\{value\}/$value/g;
	
	my @sub_list = split /,/,$substitutes;
	foreach my $s (@sub_list) {
		my ($regexp, $text) = split /:/,$s,2;
		next if (!defined ($regexp) || !defined($text));
		if ($regexp =~ /^#([+-]?\d*\.?\d+?)\-([+-]?\d*\.?\d+?)$/) {
			my ($mi, $ma) = ($1, $2);
			if ($value =~ /^\d*\.?\d+?$/ && $value >= $mi && $value <= $ma) {
				$value = $text;
				$rc = 1;
			}
		}
		elsif ($mode == 0 && $value =~ /$regexp/ && $value !~ /^[+-]?\d+$/) {
			my $x = eval { $value =~ s/$regexp/$text/ };
			$rc = 1 if (defined ($x));
			last;
		}
		elsif (($mode == 1 || $value =~ /^[+-]?\d+$/) && $value =~ /^$regexp$/) {
			my $x = eval { $value =~ s/^$regexp$/$text/ };
			$rc = 1 if (defined ($x));
			last;
		}
	}

	return ($rc, $value);
}

######################################################################
# Substitute datapoint variables in string by datapoint value. The
# value depends on the character preceding the variable name. Syntax
# of variable names is:
#   {$|$$|%|%%}{[cn.]Name}
#   {$|$$|%|%%}[cn.]Name
# %  = Original / raw value
# %% = Previous original / raw value
# $  = Converted / formatted value
# $$ = Previous converted / formatted value
# Parameter dplist is a comma separated list of value keys in format
# [address:]Channel.Datapoint.
######################################################################

sub HMCCU_SubstVariables ($$$)
{
	my ($clhash, $text, $dplist) = @_;
	my $fnc = "HMCCU_SubstVariables";
	
	my @varlist;
	if (defined ($dplist)) {
		@varlist = split (',', $dplist);
	}
	else {
		@varlist = keys %{$clhash->{hmccu}{dp}};
	}

	HMCCU_Trace ($clhash, 2, $fnc, "text=$text");
	
	# Substitute datapoint variables by value
	foreach my $dp (@varlist) {
		my ($chn, $dpt) = split (/\./, $dp);
		
		HMCCU_Trace ($clhash, 2, $fnc, "var=$dp");

		if (defined ($clhash->{hmccu}{dp}{$dp}{OSVAL})) {
			$text =~ s/\$\$\{?$dp\}?/$clhash->{hmccu}{dp}{$dp}{OSVAL}/g;
			$text =~ s/\$\$\{?$dpt\}?/$clhash->{hmccu}{dp}{$dp}{OSVAL}/g;
		}
		if (defined ($clhash->{hmccu}{dp}{$dp}{SVAL})) {
			$text =~ s/\$\{?$dp\}?/$clhash->{hmccu}{dp}{$dp}{SVAL}/g;
			$text =~ s/\$\{?$dpt\}?/$clhash->{hmccu}{dp}{$dp}{SVAL}/g;
		}
		if (defined ($clhash->{hmccu}{dp}{$dp}{OVAL})) {
			$text =~ s/\%\%\{?$dp\}?/$clhash->{hmccu}{dp}{$dp}{OVAL}/g;
			$text =~ s/\%\%\{?$dpt\}?/$clhash->{hmccu}{dp}{$dp}{OVAL}/g;
		}
		if (defined ($clhash->{hmccu}{dp}{$dp}{VAL})) {
			$text =~ s/\%\{?$dp\}?/$clhash->{hmccu}{dp}{$dp}{VAL}/g;
			$text =~ s/\%\{?$dpt\}?/$clhash->{hmccu}{dp}{$dp}{VAL}/g;
			$text =~ s/$dp/$clhash->{hmccu}{dp}{$dp}{VAL}/g;
		}
	}

	HMCCU_Trace ($clhash, 2, $fnc, "text=$text");
	
	return $text;
}

######################################################################
# Update all datapoint/readings of all client devices matching
# specified regular expression. Update will fail if device is deleted
# or disabled or if attribute ccureadings of a device is set to 0.
# If fromccu is 1 regular expression is compared to CCU device name.
# Otherwise it's compared to FHEM device name. If ifname is specified
# only devices belonging to interface ifname are updated.
######################################################################

sub HMCCU_UpdateClients ($$$$$$)
{
	my ($hash, $devexp, $ccuget, $fromccu, $ifname, $nonBlock) = @_;
	my $fhname = $hash->{NAME};
	my $c = 0;
	my $dc = 0;
	my $filter = "ccudevstate=active";
	$filter .= ",ccuif=$ifname" if (defined ($ifname));
	$ccuget = AttrVal ($fhname, 'ccuget', 'Value') if ($ccuget eq 'Attr');
	my $list = '';

	if ($fromccu) {
		foreach my $name (sort keys %{$hash->{hmccu}{adr}}) {
			next if ($name !~ /$devexp/ || !($hash->{hmccu}{adr}{$name}{valid}));

			my @devlist = HMCCU_FindClientDevices ($hash, "(HMCCUDEV|HMCCUCHN)", undef, $filter);	
			$dc += scalar(@devlist);
			foreach my $d (@devlist) {
				my $ch = $defs{$d};
				next if (!defined ($ch->{IODev}) || !defined ($ch->{ccuaddr}));
				next if ($ch->{ccuaddr} ne $hash->{hmccu}{adr}{$name}{address});
				next if ($ch->{ccuif} eq 'fhem');
				next if (!HMCCU_IsValidDeviceOrChannel ($hash, $ch->{ccuaddr}, $HMCCU_FL_ADDRESS));
				$list .= ($list eq '') ? $name : ",$name";
				$c++;
			}
		}
	}
	else {
		my @devlist = HMCCU_FindClientDevices ($hash, "(HMCCUDEV|HMCCUCHN)", $devexp, $filter);
		$dc = scalar(@devlist);
		foreach my $d (@devlist) {
			my $ch = $defs{$d};
			next if (!defined ($ch->{IODev}) || !defined ($ch->{ccuaddr}) || $ch->{ccuif} eq 'fhem');			
			next if (!HMCCU_IsValidDeviceOrChannel ($hash, $ch->{ccuaddr}, $HMCCU_FL_ADDRESS));
			my $name = HMCCU_GetDeviceName ($hash, $ch->{ccuaddr}, '');
			next if ($name eq '');
			$list .= ($list eq '') ? $name : ",$name";
			$c++;
		}
	}

	return HMCCU_Log ($hash, 2, "HMCCU: Found no devices to update") if ($c == 0);
	HMCCU_Log ($hash, 2, "Updating $c of $dc client devices matching devexp=$devexp filter=$filter");
	
	if (HMCCU_IsFlag ($fhname, 'nonBlocking') || $nonBlock) {
		HMCCU_HMScriptExt ($hash, '!GetDatapointsByDevice', { list => $list, ccuget => $ccuget },
			\&HMCCU_UpdateCB, { logCount => 1, devCount => $c });
		return 1;
	}
	else {
		my $response = HMCCU_HMScriptExt ($hash, '!GetDatapointsByDevice',
			{ list => $list, ccuget => $ccuget }, undef, undef);
		return -2 if ($response eq '' || $response =~ /^ERROR:.*/);

		HMCCU_UpdateCB ({ ioHash => $hash, logCount => 1, devCount => $c }, undef, $response);
		return 1;
	}
}

##########################################################################
# Create virtual device in internal device tables.
# If sourceAddr is specified, parameter newType will be ignored.
# Return 0 on success or error code:
# 1 = newType not defined
# 2 = Device with newType not found in internal tables
##########################################################################

sub HMCCU_CreateDevice ($$$$$)
{
	my ($hash, $newAddr, $newName, $newType, $sourceAddr) = @_;
	
	my %object;
	
	if (!defined ($sourceAddr)) {
		# Search for type in device table
		return 1 if (!defined ($newType));
		foreach my $da (keys %{$hash->{hmccu}{dev}}) {
			if ($hash->{hmccu}{dev}{$da}{type} eq $newType) {
				$sourceAddr = $da;
				last;
			}
		}
		return 2 if (!defined ($sourceAddr));
	}
	else {
		$newType = $hash->{hmccu}{dev}{$sourceAddr}{type};
	}
	
	# Device attributes
	$object{$newAddr}{flag}      = 'N';
	$object{$newAddr}{addtype}   = 'dev';
	$object{$newAddr}{channels}  = $hash->{hmccu}{dev}{$sourceAddr}{channels};
	$object{$newAddr}{name}      = $newName;
	$object{$newAddr}{type}      = $newType;
   $object{$newAddr}{interface} = 'fhem';
	$object{$newAddr}{direction} = 0;
	
	# Channel attributes
	for (my $chn=0; $chn<$object{$newAddr}{channels}; $chn++) {
		my $ca = "$newAddr:$chn";
		$object{$ca}{flag}     = 'N';
		$object{$ca}{addtype}  = 'chn';
		$object{$ca}{channels} = 1;
		$object{$ca}{name}     = "$newName:$chn";
		$object{$ca}{direction} = $hash->{hmccu}{dev}{"$sourceAddr:$chn"}{direction};
		$object{$ca}{rxmode}   = $hash->{hmccu}{dev}{"$sourceAddr:$chn"}{rxmode};
		$object{$ca}{usetype}  = $hash->{hmccu}{dev}{"$sourceAddr:$chn"}{usetype};
	}
	
	HMCCU_UpdateDeviceTable ($hash, \%object);
		
	return 0;
}

##########################################################################
# Remove virtual device from internal device tables.
##########################################################################

sub HMCCU_DeleteDevice ($)
{
	my ($clthash) = @_;
	my $name = $clthash->{NAME};
	
	return if (!exists ($clthash->{IODev}) || !exists ($clthash->{ccuif}) ||
		!exists ($clthash->{ccuaddr}));
	return if ($clthash->{ccuif} ne 'fhem');
		
	my $hmccu_hash = $clthash->{IODev};
	my $devaddr = $clthash->{ccuaddr};
	my $channels = exists ($clthash->{channels}) ? $clthash->{channels} : 0;

	# Delete device address entries
	if (exists ($hmccu_hash->{hmccu}{dev}{$devaddr})) {
		delete $hmccu_hash->{hmccu}{dev}{$devaddr};
	}
	
	# Delete channel address and name entries
	for (my $chn=0; $chn<=$channels; $chn++) {
		if (exists ($hmccu_hash->{hmccu}{dev}{"$devaddr:$chn"})) {
			delete $hmccu_hash->{hmccu}{dev}{"$devaddr:$chn"};
		}
		if (exists ($hmccu_hash->{hmccu}{adr}{"$name:$chn"})) {
			delete $hmccu_hash->{hmccu}{adr}{"$name:$chn"};
		}
	}
	
	# Delete device name entries
	if (exists ($hmccu_hash->{hmccu}{adr}{$name})) {
		delete $hmccu_hash->{hmccu}{adr}{$name};
	}
}

##########################################################################
# Update parameters in internal device tables and client devices.
# Parameter devices is a hash reference with following keys:
#  {address}
#  {address}{flag}        := [N, D, R] (N=New, D=Deleted, R=Renamed)
#  {address}{addtype}     := [chn, dev] for channel or device
#  {address}{channels}    := Number of channels
#  {address}{name}        := Device or channel name
#  {address}{type}        := Homematic device type
#  {address}{usetype}     := Usage type
#  {address}{interface}   := Device interface ID
#  {address}{firmware}    := Firmware version of device
#  {address}{version}     := Version of RPC device description
#  {address}{rxmode}      := Transmit mode
#  {address}{direction}   := Channel direction: 0=none, 1=sensor, 2=actor
#  {address}{paramsets}   := Comma separated list of supported paramsets
#  {address}{sourceroles} := Link sender roles
#  {address}{targetroles} := Link receiver roles
#  {address}{children}    := Comma separated list of channels
#  {address}{parent}      := Parent device
#  {address}{aes}         := AES flag
# If flag is 'D' the hash must contain an entry for the device address
# and for each channel address.
##########################################################################

sub HMCCU_UpdateDeviceTable ($$)
{
	my ($hash, $devices) = @_;
	my $name = $hash->{NAME};
	my $devcount = 0;
	my $chncount = 0;

	# Update internal device table
	foreach my $da (keys %{$devices}) {
		my $nm = $hash->{hmccu}{dev}{$da}{name} if (defined ($hash->{hmccu}{dev}{$da}{name}));
		$nm = $devices->{$da}{name} if (defined ($devices->{$da}{name}));

		if ($devices->{$da}{flag} eq 'N' && defined ($nm)) {
			my $at = '';
			if (defined ($devices->{$da}{addtype})) {
				$at = $devices->{$da}{addtype};
			}
			else {
				$at = 'chn' if (HMCCU_IsChnAddr ($da, 0));
				$at = 'dev' if (HMCCU_IsDevAddr ($da, 0));
			}
			if ($at eq '') {
				HMCCU_Log ($hash, 2, "Cannot detect type of address $da. Ignored.");
				next;
			}
			HMCCU_Log ($hash, 2, "Duplicate name for device/channel $nm address=$da in CCU.")			
				if (exists ($hash->{hmccu}{adr}{$nm}) && $at ne $hash->{hmccu}{adr}{$nm}{addtype});

			# Updated or new device/channel
			$hash->{hmccu}{dev}{$da}{addtype}   = $at;
			$hash->{hmccu}{dev}{$da}{valid}     = 1;
			
			foreach my $k ('channels', 'type', 'usetype', 'interface', 'version',
				'firmware', 'rxmode', 'direction', 'paramsets', 'sourceroles', 'targetroles',
				'children', 'parent', 'aes') {
				$hash->{hmccu}{dev}{$da}{$k} = $devices->{$da}{$k}
					if (defined ($devices->{$da}{$k}));
			}
			
			if (defined ($nm)) {
				$hash->{hmccu}{dev}{$da}{name}      = $nm;
				$hash->{hmccu}{adr}{$nm}{address}   = $da;
				$hash->{hmccu}{adr}{$nm}{addtype}   = $hash->{hmccu}{dev}{$da}{addtype};
				$hash->{hmccu}{adr}{$nm}{valid}     = 1;
			}
		}
		elsif ($devices->{$da}{flag} eq 'D' && exists ($hash->{hmccu}{dev}{$da})) {
			# Device deleted, mark as invalid
			$hash->{hmccu}{dev}{$da}{valid} = 0;
			$hash->{hmccu}{adr}{$nm}{valid} = 0 if (defined ($nm));
		}
		elsif ($devices->{$da}{flag} eq 'R' && exists ($hash->{hmccu}{dev}{$da})) {
			# Device replaced, change address
			my $na = $devices->{hmccu}{newaddr};
			# Copy device entries and delete old device entries
			foreach my $k (keys %{$hash->{hmccu}{dev}{$da}}) {
				$hash->{hmccu}{dev}{$na}{$k} = $hash->{hmccu}{dev}{$da}{$k};
			}
			$hash->{hmccu}{adr}{$nm}{address} = $na;
			delete $hash->{hmccu}{dev}{$da};
		}
	}

	# Delayed initialization if CCU was not ready during FHEM start
	if ($hash->{hmccu}{ccu}{delayed} == 1) {
		# Initialize interface and port lists
		HMCCU_AttrInterfacesPorts ($hash, 'rpcinterfaces', $attr{$name}{rpcinterfaces})
			if (exists ($attr{$name}{rpcinterfaces}));
		HMCCU_AttrInterfacesPorts ($hash, 'rpcport', $attr{$name}{rpcport})
			if (exists ($attr{$name}{rpcport}));
			
		# Initialize pending client devices
		my @cdev = HMCCU_FindClientDevices ($hash, '(HMCCUDEV|HMCCUCHN|HMCCURPCPROC)', undef, 'ccudevstate=pending');
		if (scalar (@cdev) > 0) {
			HMCCU_Log ($hash, 2, "Initializing ".scalar(@cdev)." client devices in state 'pending'");
			foreach my $cd (@cdev) {
				my $ch = $defs{$cd};
				my $ct = $ch->{TYPE};
				my $rc = 0;
				if ($ct eq 'HMCCUDEV') {
					$rc = HMCCUDEV_InitDevice ($hash, $ch);
				}
				elsif ($ct eq 'HMCCUCHN') {
					$rc = HMCCUCHN_InitDevice ($hash, $ch);
				}
				elsif ($ct eq 'HMCCURPCPROC') {
					$rc = HMCCURPCPROC_InitDevice ($hash, $ch);
				}
				HMCCU_Log ($hash, 3, "Can't initialize client device ".$ch->{NAME}) if ($rc > 0);
			}
		}
		
		$hash->{hmccu}{ccu}{delayed} = 0;
	}

	# Update client devices
	my @devlist = HMCCU_FindClientDevices ($hash, "(HMCCUDEV|HMCCUCHN)", undef, undef);
	foreach my $d (@devlist) {
		my $ch = $defs{$d};
		my $ct = $ch->{TYPE};
		next if (!exists ($ch->{ccuaddr}));
		my $ca = $ch->{ccuaddr};
		next if (!exists ($devices->{$ca}));
		if ($devices->{$ca}{flag} eq 'N') {
			# New device or new device information
			$ch->{ccudevstate} = 'active';
			if ($ct eq 'HMCCUDEV') {
				$ch->{ccutype} = $hash->{hmccu}{dev}{$ca}{type} 
					if (defined ($hash->{hmccu}{dev}{$ca}{type}));
				$ch->{firmware} = $devices->{$ca}{firmware}
					if (defined ($devices->{$ca}{firmware}));
			}
			else {
				$ch->{chntype} = $devices->{$ca}{usetype}
					if (defined ($devices->{$ca}{usetype}));
				my ($add, $chn) = HMCCU_SplitChnAddr ($ca);
				$ch->{ccutype} = $devices->{$add}{type}
					if (defined ($devices->{$add}{type}));
				$ch->{firmware} = $devices->{$add}{firmware}
					if (defined ($devices->{$add}{firmware}));
			}
			$ch->{ccuname} = $hash->{hmccu}{dev}{$ca}{name}
				if (defined ($hash->{hmccu}{dev}{$ca}{name}));
			$ch->{ccuif} = $hash->{hmccu}{dev}{$ca}{interface}
				if (defined ($devices->{$ca}{interface}));
			$ch->{channels} = $hash->{hmccu}{dev}{$ca}{channels}
				if (defined ($hash->{hmccu}{dev}{$ca}{channels}));
		}
		elsif ($devices->{$ca}{flag} eq 'D') {
			# Deleted device
			$ch->{ccudevstate} = 'deleted';
		}
		elsif ($devices->{$ca}{flag} eq 'R') {
			# Replaced device
			$ch->{ccuaddr} = $devices->{$ca}{newaddr};
		}
	}
	
	# Update internals of I/O device
	foreach my $adr (keys %{$hash->{hmccu}{dev}}) {
		if (exists ($hash->{hmccu}{dev}{$adr}{addtype})) {
			$devcount++ if ($hash->{hmccu}{dev}{$adr}{addtype} eq 'dev');
			$chncount++ if ($hash->{hmccu}{dev}{$adr}{addtype} eq 'chn');
		}
	}
	$hash->{ccudevices} = $devcount;
	$hash->{ccuchannels} = $chncount;
	
	return ($devcount, $chncount);
}

######################################################################
# Delete device table entries
######################################################################

sub HMCCU_ResetDeviceTables ($$)
{
	my ($hash, $iface) = @_;
	
	if (defined($iface)) {
		$hash->{hmccu}{device}{$iface} = ();
	}
	else {
		$hash->{hmccu}{device} = ();
	}
	
	$hash->{hmccu}{model} = ();
}

######################################################################
# Add new device.
# Arrays are converted to a comma separated string. Device description
# is stored in $hash->{hmccu}{device}.
# Address type and name of interface will be added to standard device
# description in hash elements "_addtype" and "_interface".
# Parameters:
#   $desc  - Hash reference with RPC device description.
#   $key   - Key of device description hash (i.e. "ADDRESS").
#   $iface - RPC interface name (i.e. "BidCos-RF").
######################################################################

sub HMCCU_AddDeviceDesc ($$$$)
{
	my ($hash, $desc, $key, $iface) = @_;

	return 0 if (!exists ($desc->{$key}));

	my $k = $desc->{$key};

	foreach my $p (keys %$desc) {
		if (ref($desc->{$p}) eq 'ARRAY') {
			$hash->{hmccu}{device}{$iface}{$k}{$p} = join(',', @{$desc->{$p}});
		}
		elsif ($p ne $key) {
			$hash->{hmccu}{device}{$iface}{$k}{$p} = $desc->{$p};
		}
	}
	
	$hash->{hmccu}{device}{$iface}{$k}{_interface} = $iface;
	if (defined($desc->{PARENT}) && $desc->{PARENT} ne '') {
		$hash->{hmccu}{device}{$iface}{$k}{_addtype} = 'chn';
		$hash->{hmccu}{device}{$iface}{$k}{_fw_ver} = $hash->{hmccu}{device}{$iface}{$desc->{PARENT}}{_fw_ver};
		$hash->{hmccu}{device}{$iface}{$k}{_model} = $hash->{hmccu}{device}{$iface}{$desc->{PARENT}}{_model};
		$hash->{hmccu}{device}{$iface}{$k}{_name} = HMCCU_GetChannelName ($hash, $k, '');
	}
	else {
		$hash->{hmccu}{device}{$iface}{$k}{_addtype} = 'dev';
		my $fw_ver = $desc->{FIRMWARE};
		$fw_ver =~ s/[-\.]/_/g;
		$hash->{hmccu}{device}{$iface}{$k}{_fw_ver} = $fw_ver."-".$desc->{VERSION};
		$hash->{hmccu}{device}{$iface}{$k}{_model} = $desc->{TYPE};
		$hash->{hmccu}{device}{$iface}{$k}{_name} = HMCCU_GetDeviceName ($hash, $k, '');
	}
	
	return 1;
}

######################################################################
# Get device description
# Parameters:
#   $hash - Hash reference of IO device or client device. For client
#      devices the parameters $iface and $address are taken from
#      client device hash if set to undef.
#   $iface - Interface name.
#   $address - Address of device or channel.
# Return hash reference for device description or undef on error.
######################################################################

sub HMCCU_GetDeviceDesc ($;$$)
{
	my ($hash, $iface, $address) = @_;
	my $ioHash = HMCCU_GetHash ($hash);
	
	if ($hash->{TYPE} eq 'HMCCUDEV' || $hash->{TYPE} eq 'HMCCUCHN') {
		$iface = $hash->{ccuif} if (!defined($iface));
		$address = $hash->{ccuaddr} if (!defined($address));
	}
	else {
		return undef if (!defined($iface) || !defined($address));
	}

	return (exists ($ioHash->{hmccu}{device}{$iface}{$address}) ?
		$ioHash->{hmccu}{device}{$iface}{$address} : undef);
}

######################################################################
# Get device addresses.
# Parameters:
#   $iface - Interface name. If set to undef, all devices are
#      returned.
#   $filter - Filter expression in format Attribute=RegExp[,...].
#      Attribute is a valid device description parameter name or
#      "_addtype" or "_interface".
# Return array with addresses.
######################################################################

sub HMCCU_GetDeviceAddresses ($;$$)
{
	my ($hash, $iface, $filter) = @_;
	
	my @addList = ();
	my @ifaceList = ();
	
	if (defined($iface)) {
		push (@ifaceList, $iface);
	}
	else {
		push (@ifaceList, keys %{$hash->{hmccu}{device}});
	}
	
	if (defined($filter)) {
		my %f = ();
		foreach my $fd (split (',', $filter)) {
			my ($fa, $fv) = split ('=', $fd);
			$f{$fa} = $fv if (defined($fv));
		}
		return undef if (scalar(keys(%f)) == 0);

		foreach my $i (@ifaceList) {		
			foreach my $a (keys %{$hash->{hmccu}{device}{$i}}) {
				my $n = 0;
				foreach my $fr (keys(%f)) {
					if (HMCCU_ExprNotMatch ($hash->{hmccu}{device}{$i}{$a}{$fr}, $f{$fr}, 1)) {
						$n = 1;
						last;
					}
				}
				push (@addList, $a) if ($n == 0);
			}
		}
	}
	else {
		foreach my $i (@ifaceList) {
			push (@addList, keys %{$hash->{hmccu}{device}{$i}});
		}
	}
	
	return @addList;
}

######################################################################
# Check if device model is already known by HMCCU
#   $type - The device model
#   $fw_ver - combined key of firmware and description version
#   $chnNo - Channel number or 'd' for device
######################################################################

sub HMCCU_ExistsDeviceModel ($$$;$)
{
	my ($hash, $type, $fw_ver, $chnNo) = @_;
	
	if (defined($chnNo)) {
		return (exists($hash->{hmccu}{model}{$type}) && exists($hash->{hmccu}{model}{$type}{$fw_ver}) &&
			exists($hash->{hmccu}{model}{$type}{$fw_ver}{$chnNo}) ? 1 : 0);
	}
	else {
		return (exists($hash->{hmccu}{model}{$type}) && exists($hash->{hmccu}{model}{$type}{$fw_ver}) ? 1 : 0);
	}
}

######################################################################
# Add new device model
# Parameters:
#   $desc - Hash reference with paramset description
#   $type - The device model
#   $fw_ver - combined key of firmware and description version
#   $paramset - Name of parameter set
#   $chnNo - Channel number or 'd' for device
######################################################################

sub HMCCU_AddDeviceModel ($$$$$$)
{
	my ($hash, $desc, $type, $fw_ver, $paramset, $chnNo) = @_;
	
	# Process list of parameter names
	foreach my $p (keys %$desc) {	
		# Process parameter attributes
		foreach my $a (keys %{$desc->{$p}}) {
			if (ref($desc->{$p}{$a}) eq 'HASH') {
				# Process sub attributes
				foreach my $s (keys %{$desc->{$p}{$a}}) {
					if (ref($desc->{$p}{$a}{$s}) eq 'ARRAY') {
						$hash->{hmccu}{model}{$type}{$fw_ver}{$chnNo}{$paramset}{$p}{$a}{$s} = join(',', @{$desc->{$p}{$a}{$s}});
					}
					else {
						$hash->{hmccu}{model}{$type}{$fw_ver}{$chnNo}{$paramset}{$p}{$a}{$s} = $desc->{$p}{$a}{$s};
					}
				}
			}
			elsif (ref($desc->{$p}{$a}) eq 'ARRAY') {
				$hash->{hmccu}{model}{$type}{$fw_ver}{$chnNo}{$paramset}{$p}{$a} = join(',', @{$desc->{$p}{$a}});
			}
			else {
				$hash->{hmccu}{model}{$type}{$fw_ver}{$chnNo}{$paramset}{$p}{$a} = $desc->{$p}{$a};
			}
		}
	}
}

######################################################################
# Get device model
# Parameters:
#   $chnNo - Channel number. Use 'd' for device entry. If not defined
#     a reference to the master entry is returned.
######################################################################

sub HMCCU_GetDeviceModel ($$$;$)
{
	my ($hash, $type, $fw_ver, $chnNo) = @_;
	
	if (defined($chnNo)) {
		return (exists($hash->{hmccu}{model}{$type}{$fw_ver}{$chnNo}) ?
			$hash->{hmccu}{model}{$type}{$fw_ver}{$chnNo} : undef);
	}
	else {
		return (exists($hash->{hmccu}{model}{$type}{$fw_ver}) ?
			$hash->{hmccu}{model}{$type}{$fw_ver} : undef);
	}
}

######################################################################
# Get device model for client device
# Parameters:
#   $hash - Hash reference for device of type HMCCUCHN or HMCCUDEV.
#   $chnNo - Channel number. Use 'd' for device entry. If not defined
#     a reference to the master entry is returned.
######################################################################

sub HMCCU_GetClientDeviceModel ($;$)
{
	my ($hash, $chnNo) = @_;
	
	return undef if ($hash->{TYPE} ne 'HMCCUCHN' && $hash->{TYPE} ne 'HMCCUDEV');
	
	my $ioHash = HMCCU_GetHash ($hash);
	my $devDesc = HMCCU_GetDeviceDesc ($hash);
	
	return defined($devDesc) ? 
		HMCCU_GetDeviceModel ($ioHash, $devDesc->{_model}, $devDesc->{_fw_ver}, $chnNo) : undef;
}

#######################################################################
# Convert bitmask to text
# Parameters:
#   $set - 'device' or 'model'.
#   $flag - Name of parameter.
#   $value - Value of parameter.
#   $sep - String separator. Default = ''.
#   $default - Default value is returned if no bit is set.
# Return empty string on error or if no bit set.
######################################################################

sub HMCCU_FlagsToStr ($$$;$$)
{
	my ($set, $flag, $value, $sep, $default) = @_;
	
	$default = '' if (!defined($default));
	$sep = '' if (!defined($sep));
	
	my %bitmasks = (
		'device' => {
			'FLAGS' =>     { 1 => "Visible", 2 => "Internal", 8 => "DontDelete" },
			'DIRECTION' => { 0 => "NONE", 1 => "SENDER", 2 => "RECEIVER" },
			'RX_MODE' =>   { 1 => "ALWAYS", 2 => "BURST", 4 => "CONFIG", 8 => "WAKEUP", 16 => "LAZY_CONFIG" }
		},
		'model' => {
			'FLAGS' =>      { 1 => "Visible", 2 => "Internal", 4 => "Transform", 8 => "Service", 16 => "Sticky" },
			'OPERATIONS' => { 1 => 'R', 2 => 'W', 4 => 'E' }
		}
	);
	
	return '' if (!exists($bitmasks{$set}{$flag}));
	
	my @list = ();
	foreach my $b (sort keys %{$bitmasks{$set}{$flag}}) {
		push (@list, $bitmasks{$set}{$flag}{$b}) if ($value & $b);
	}
	
	return scalar(@list) == 0 ? $default : join($sep, @list);
}

######################################################################
# Update a single client device datapoint considering scaling, reading
# format and value substitution.
# Return stored value.
######################################################################

sub HMCCU_UpdateSingleDatapoint ($$$$)
{
	my ($hash, $chn, $dpt, $value) = @_;

	my $hmccu_hash = HMCCU_GetHash ($hash);
	return $value if (!defined ($hmccu_hash));
	
	my %objects;
	
	my $ccuaddr = $hash->{ccuaddr};
	my ($devaddr, $chnnum) = HMCCU_SplitChnAddr ($ccuaddr);
	$objects{$devaddr}{$chn}{$dpt} = $value;
	
#	my $rc = HMCCU_UpdateMultipleDevices ($hmccu_hash, \%objects);
	my $rc = HMCCU_UpdateSingleDevice ($hmccu_hash, $hash, \%objects, undef);
	return (ref ($rc)) ? $rc->{$devaddr}{$chn}{$dpt} : $value;
}

######################################################################
# Update readings of client device.
# Parameter objects is a hash reference which contains updated data
# for devices:
#   {devaddr}{channelno}{datapoint} = value
# If client device is virtual device group: check if group members are
# affected by updates and update readings in virtual group device.
# Return a hash reference with datapoints and new values:
#   {devaddr}{datapoint} = value
######################################################################

sub HMCCU_UpdateSingleDevice ($$$$)
{
	my ($ccuhash, $clthash, $objects, $alref) = @_;
	my $ccuname = $ccuhash->{NAME};
	my $cltname = $clthash->{NAME};
	my $clttype = $clthash->{TYPE};
	my $fnc = "UpdateSingleDevice";

	return 0 if (!defined ($clthash->{IODev}) || !defined ($clthash->{ccuaddr}));
	return 0 if ($clthash->{IODev} != $ccuhash);

	# Build list of relevant addresses in object data hash
 	my ($devaddr, $cnum) = HMCCU_SplitChnAddr ($clthash->{ccuaddr});
	my @addlist = defined ($alref) ? @$alref : ($devaddr);

	# Check if update of device allowed
	my $disable = AttrVal ($cltname, 'disable', 0);
	my $update = AttrVal ($cltname, 'ccureadings', 1);
	next if ($update == 0 || $disable == 1 || $clthash->{ccudevstate} ne 'active');

	# Get device parameters and attributes
	my $ccuflags = HMCCU_GetFlags ($ccuname);
	my $cf = HMCCU_GetFlags ($cltname);
	my $peer = AttrVal ($cltname, 'peer', 'null');
	my $crf = HMCCU_GetAttrReadingFormat ($clthash, $ccuhash);
	my $substitute = HMCCU_GetAttrSubstitute ($clthash, $ccuhash);
	my ($sc, $st, $cc, $cd, $ss, $cs) = HMCCU_GetSpecialDatapoints ($clthash, '', 'STATE', '', '');

	# Virtual device flag
	my $vg = 0;
	$vg = 1 if (($clthash->{ccuif} eq 'VirtualDevices' || $clthash->{ccuif} eq 'fhem') &&
		exists ($clthash->{ccugroup}));

	HMCCU_Trace ($clthash, 2, $fnc, "$cltname Objects = ".join(',', @addlist));
	
	# Store the resulting readings
	my %results;
	
	# Updated internal values
	my @chkeys = ();
	
	# Update readings of client device with data from address list
	readingsBeginUpdate ($clthash);
	
	foreach my $addr (@addlist) {
		next if (!exists ($objects->{$addr}));
		
		HMCCU_Trace ($clthash, 2, $fnc, "Processing object $addr");
		
		# Update channels of device
		foreach my $chnnum (keys (%{$objects->{$addr}})) {
			next if ($clttype eq 'HMCCUCHN' && "$chnnum" ne "$cnum" && "$chnnum" ne "0");
			next if ("$chnnum" eq "0" && $cf =~ /nochn0/);
			my $chnadd = "$addr:$chnnum";
		
			# Update datapoints of channel
			foreach my $dpt (keys (%{$objects->{$addr}{$chnnum}})) {
				my $value = $objects->{$addr}{$chnnum}{$dpt};
				next if (!defined ($value));
				
				# Key for storing values in client hash. Indirect updates of virtual devices
				# are stored with device address in key.
				my $chkey = $devaddr ne $addr ? "$chnadd.$dpt" : "$chnnum.$dpt";
				
				# Store datapoint raw value in device hash
				HMCCU_UpdateInternalValues ($clthash, $chkey, 'VAL', $value);

				HMCCU_Trace ($clthash, 2, $fnc, "dev=$cltname, chnadd/object=$chnadd, dpt=$dpt, key=$chkey, value=$value");

				if (HMCCU_FilterReading ($clthash, $chnadd, $dpt)) {
					# Modify reading name and value
					my @readings = HMCCU_GetReadingName ($clthash, '', $addr, $chnnum, $dpt, '', $crf);
					my $svalue   = HMCCU_ScaleValue ($clthash, $chnnum, $dpt, $value, 0);	
					my $fvalue   = HMCCU_FormatReadingValue ($clthash, $svalue, $dpt);
					my $cvalue   = HMCCU_Substitute ($fvalue, $substitute, 0, $chnnum, $dpt);
#					my %calcs    = HMCCU_CalculateReading ($clthash, $chkey);

					# Store the resulting value after scaling, formatting and substitution
					HMCCU_UpdateInternalValues ($clthash, $chkey, 'SVAL', $cvalue);
					push @chkeys, $chkey;
					
					# Store result, but not for indirect updates of virtual devices
					$results{$devaddr}{$chnnum}{$dpt} = $cvalue if ($devaddr eq $addr);

					HMCCU_Trace ($clthash, 2, $fnc,
						"device=$cltname, readings=".join(',', @readings).
						", orgvalue=$value value=$cvalue peer=$peer");

					# Update readings
					foreach my $rn (@readings) {
						HMCCU_BulkUpdate ($clthash, $rn, $fvalue, $cvalue) if ($rn ne '');
					}
# 					foreach my $clcr (keys %calcs) {
# 						HMCCU_BulkUpdate ($clthash, $clcr, $calcs{$clcr}, $calcs{$clcr});
# 					}
					HMCCU_BulkUpdate ($clthash, 'control', $fvalue, $cvalue)
						if ($cd ne '' && $dpt eq $cd && $chnnum eq $cc);
					HMCCU_BulkUpdate ($clthash, 'state', $fvalue, $cvalue)
						if ($dpt eq $st && ($sc eq '' || $sc eq $chnnum));
					
					# Update peers
					HMCCU_UpdatePeers ($clthash, "$chnnum.$dpt", $cvalue, $peer) if (!$vg && $peer ne 'null');
				}
			}
		}		
	}
	
	if (scalar (@chkeys) > 0) {
		my %calcs = HMCCU_CalculateReading ($clthash, \@chkeys);
		foreach my $clcr (keys %calcs) {
			HMCCU_BulkUpdate ($clthash, $clcr, $calcs{$clcr}, $calcs{$clcr});
		}
	}
	
	# Calculate and update HomeMatic state
	if ($ccuflags !~ /nohmstate/) {
		my ($hms_read, $hms_chn, $hms_dpt, $hms_val) = HMCCU_GetHMState ($cltname, $ccuname, undef);
		HMCCU_BulkUpdate ($clthash, $hms_read, $hms_val, $hms_val) if (defined ($hms_val));
	}

	readingsEndUpdate ($clthash, 1);
	
	return \%results;
}

######################################################################
# Store datapoint values in device hash.
# Parameter type is VAL or SVAL.
######################################################################

sub HMCCU_UpdateInternalValues ($$$$)
{
	my ($ch, $chkey, $type, $value) = @_;	
	my $otype = "O".$type;
	
	# Save old value
	if (exists ($ch->{hmccu}{dp}{$chkey}{$type})) {
		$ch->{hmccu}{dp}{$chkey}{$otype} = $ch->{hmccu}{dp}{$chkey}{$type};
	}
	else {
		$ch->{hmccu}{dp}{$chkey}{$otype} = $value;
	}
	
	# Store new value
	$ch->{hmccu}{dp}{$chkey}{$type} = $value;
}

######################################################################
# Update readings of multiple client devices.
# Parameter objects is a hash reference:
#   {devaddr}
#   {devaddr}{channelno}
#   {devaddr}{channelno}{datapoint} = value
# Return number of updated devices.
######################################################################

sub HMCCU_UpdateMultipleDevices ($$)
{
	my ($hash, $objects) = @_;
	my $name = $hash->{NAME};
	my $fnc = "UpdateMultipleDevices";
	my $c = 0;
	
	# Check syntax
	return 0 if (!defined ($hash) || !defined ($objects));

	# Update reading in matching client devices
	my @devlist = HMCCU_FindClientDevices ($hash, "(HMCCUDEV|HMCCUCHN)", undef,
		"ccudevstate=active");
	foreach my $d (@devlist) {
		my $ch = $defs{$d};
		if (!defined ($ch)) {
			HMCCU_Log ($name, 2, "Can't find hash for device $d");
			next;
		}
	 	my @addrlist = HMCCU_GetAffectedAddresses ($ch);
		next if (scalar (@addrlist) == 0);
		foreach my $addr (@addrlist) {
			if (exists ($objects->{$addr})) {
				my $rc = HMCCU_UpdateSingleDevice ($hash, $ch, $objects, \@addrlist);
				$c++ if (ref ($rc));
				last;
			}
		}
	}

	return $c;
}

######################################################################
# Get list of device addresses including group device members.
######################################################################

sub HMCCU_GetAffectedAddresses ($)
{
	my ($clthash) = @_;
	my @addlist = ();
	
	if ($clthash->{TYPE} eq 'HMCCUDEV' || $clthash->{TYPE} eq 'HMCCUCHN') {
		if (exists ($clthash->{ccuaddr})) {
			my ($devaddr, $cnum) = HMCCU_SplitChnAddr ($clthash->{ccuaddr});
			push @addlist, $devaddr;
		}
		if (($clthash->{ccuif} eq 'VirtualDevices' || $clthash->{ccuif} eq 'fhem') &&
			exists ($clthash->{ccugroup})) {
			push @addlist, split (',', $clthash->{ccugroup});
		}
	}
	
	return @addlist;
}

######################################################################
# Update peer devices.
# Syntax of peer definitions is:
# channel.datapoint[,...]:condition:type:action
# condition := valid perl expression. Any channel.datapoint
#    combination is substituted by the corresponding value. If channel
#    is preceded by a % it's substituted by the raw value. If it's
#    preceded by a $ it's substituted by the formated/converted value.
#    If % or $ is doubled the old values are used.
# type := type of action. Valid types are ccu, hmccu and fhem.
# action := Action to be performed if result of condition is true.
#    Depending on type action type this could be an assignment or a
#    FHEM command. If action contains $value this parameter is 
#    substituted by the original value of the datapoint which has
#    triggered the action.
# assignment := channel.datapoint=expression
######################################################################

sub HMCCU_UpdatePeers ($$$$)
{
	my ($clt_hash, $chndpt, $val, $peerattr) = @_;
	my $fnc = "UpdatePeers";

	my $io_hash = HMCCU_GetHash ($clt_hash);

	HMCCU_Trace ($clt_hash, 2, $fnc, "chndpt=$chndpt val=$val peer=$peerattr");
	
	my @rules = split (/[;\n]+/, $peerattr);
	foreach my $r (@rules) {
		HMCCU_Trace ($clt_hash, 2, $fnc, "rule=$r");
		my ($vars, $cond, $type, $act) = split (/:/, $r, 4);
		next if (!defined ($act));
		HMCCU_Trace ($clt_hash, 2, $fnc, "vars=$vars, cond=$cond, type=$type, act=$act");
		next if ($cond !~ /$chndpt/);
		
		# Check if rule is affected by datapoint update
		my $ex = 0;
		foreach my $dpt (split (",", $vars)) {
			HMCCU_Trace ($clt_hash, 2, $fnc, "dpt=$dpt");
			$ex = 1 if ($ex == 0 && $dpt eq $chndpt);
			if (!exists ($clt_hash->{hmccu}{dp}{$dpt})) {
				HMCCU_Trace ($clt_hash, 2, $fnc, "Datapoint $dpt does not exist on hash");
			}
			last if ($ex == 1);
		}
		next if (! $ex);

		# Substitute variables and evaluate condition		
		$cond = HMCCU_SubstVariables ($clt_hash, $cond, $vars);
		my $e = eval "$cond";
		HMCCU_Trace ($clt_hash, 2, $fnc, "eval $cond = $e") if (defined ($e));
		HMCCU_Trace ($clt_hash, 2, $fnc, "Error in eval $cond") if (!defined ($e));
		HMCCU_Trace ($clt_hash, 2, $fnc, "NoMatch in eval $cond") if (defined ($e) && $e eq '');
		next if (!defined ($e) || $e eq '');

		# Substitute variables and execute action	
		if ($type eq 'ccu' || $type eq 'hmccu') {
			my ($aobj, $aexp) = split (/=/, $act);
			$aexp =~ s/\$value/$val/g;
			$aexp = HMCCU_SubstVariables ($clt_hash, $aexp, $vars);
			HMCCU_Trace ($clt_hash, 2, $fnc, "set $aobj to $aexp");
			my ($int, $add, $chn, $dpt, $nam, $flags) = HMCCU_ParseObject ($io_hash, "$type:$aobj",
				$HMCCU_FLAG_INTERFACE);
			next if ($flags != $HMCCU_FLAGS_IACD && $flags != $HMCCU_FLAGS_NCD);
			HMCCU_SetMultipleDatapoints ($clt_hash, { "001.$int.$add:$chn.$dpt" => $aexp });
		}
		elsif ($type eq 'fhem') {
			$act =~ s/\$value/$val/g;
			$act = HMCCU_SubstVariables ($clt_hash, $act, $vars);
			HMCCU_Trace ($clt_hash, 2, $fnc, "Execute command $act");
			AnalyzeCommandChain (undef, $act);
		}
	}
}

######################################################################
# Get list of valid RPC interfaces.
# Binary interfaces are ignored if internal RPC server is used.
######################################################################

sub HMCCU_GetRPCInterfaceList ($)
{
	my ($hash) = @_;
	my $name = $hash->{NAME};
	
	my ($defInterface, $defPort) = HMCCU_GetDefaultInterface ($hash);
	my @interfaces = ();
	
	my $ccuflags = HMCCU_GetFlags ($name);
	
	if (defined ($hash->{hmccu}{rpcports})) {
		foreach my $p (split (',', $hash->{hmccu}{rpcports})) {
			my ($ifname, $iftype) = HMCCU_GetRPCServerInfo ($hash, $p, 'name,type');
			next if (!defined ($ifname) || !defined ($iftype));
# 			push (@interfaces, $ifname) if ($iftype ne 'B' || $ccuflags =~ /(extrpc|procrpc)/);
			push (@interfaces, $ifname);
		}
	}
	else {
		@interfaces = ($defInterface);		
	}
	
	return @interfaces;
}

######################################################################
# Get list of valid RPC ports.
# Binary interfaces are ignored if internal RPC server is used.
######################################################################

sub HMCCU_GetRPCPortList ($)
{
	my ($hash) = @_;
	my $name = $hash->{NAME};
	
	my ($defInterface, $defPort) = HMCCU_GetDefaultInterface ($hash);
	my @ports = ();
	
	my $ccuflags = HMCCU_GetFlags ($name);
	
	if (defined ($hash->{hmccu}{rpcports})) {
		foreach my $p (split (',', $hash->{hmccu}{rpcports})) {
			my ($ifname, $iftype) = HMCCU_GetRPCServerInfo ($hash, $p, 'name,type');
			next if (!defined ($ifname) || !defined ($iftype));
# 			push (@ports, $p) if ($iftype ne 'B' || $ccuflags =~ /(extrpc|procrpc)/);
			push (@ports, $p);
		}
	}
	else {
		@ports = ($defPort);
	}
	
	return @ports;
}

######################################################################
# Called by HMCCURPCPROC device of default interface 
# when no events from CCU were received for a specified time span.
# Return 1 if all RPC servers have been registered successfully.
# Return 0 if at least one RPC server failed to register or the
# corresponding HMCCURPCPROC device was not found.
######################################################################

sub HMCCU_EventsTimedOut ($)
{
	my ($hash) = @_;
	my $name = $hash->{NAME};
	
	return 1 if (!HMCCU_IsFlag ($name, 'reconnect'));
	
	HMCCU_Log ($hash, 2, "Reconnecting to CCU");
	
	# Register callback for each interface
	my $rc = 1;
	my @iflist = HMCCU_GetRPCInterfaceList ($hash);
	foreach my $ifname (@iflist) {
		my ($rpcdev, $save) = HMCCU_GetRPCDevice ($hash, 0, $ifname);
		if ($rpcdev eq '') {
			HMCCU_Log ($hash, 0, "Can't find RPC device for interface $ifname");
			$rc = 0;
			next;
		}
		my $cl_hash = $defs{$rpcdev};
		# Check if CCU interface is reachable before registering callback
		my ($nrc, $msg) = HMCCURPCPROC_RegisterCallback ($cl_hash, 2);
		$rc &= $nrc;
		if ($nrc) {
			$cl_hash->{ccustate} = 'active';
		}
		else {
			HMCCU_Log ($cl_hash, 1, $msg);
		}
	}
	
	return $rc;
}

######################################################################
# Build RPC callback URL
# Parameter hash might be a HMCCU or a HMCCURPC hash.
######################################################################

sub HMCCU_GetRPCCallbackURL ($$$$$)
{
	my ($hash, $localaddr, $cbport, $clkey, $iface) = @_;

	return undef if (!defined ($hash));
	
	my $hmccu_hash = $hash->{TYPE} eq 'HMCCURPC' ? $hash->{IODev} : $hash;
	
	return undef if (!exists ($hmccu_hash->{hmccu}{interfaces}{$iface}) &&
		!exists ($hmccu_hash->{hmccu}{ifports}{$iface}));
	
	my $ifname = $iface =~ /^[0-9]+$/ ? $hmccu_hash->{hmccu}{ifports}{$iface} : $iface;
	return undef if (!exists ($hmccu_hash->{hmccu}{interfaces}{$ifname}));

	my $url = $hmccu_hash->{hmccu}{interfaces}{$ifname}{prot}."://$localaddr:$cbport/fh".
		$hmccu_hash->{hmccu}{interfaces}{$ifname}{port};
	$url =~ s/^https/http/;
	
	return $url;
}

######################################################################
# Get RPC server information.
# Parameter iface can be a port number or an interface name.
# Parameter info is a comma separated list of info tokens.
# Valid values for info are:
# url, port, prot, host, type, name, flags, device, devcount.
# Return undef for invalid interface or info token.
######################################################################

sub HMCCU_GetRPCServerInfo ($$$)
{
	my ($hash, $iface, $info) = @_;
	my @result = ();
	
#	HMCCU_Log ($hash, 2, "Get RPC server info $info for port/interface $iface", 0);
	
	return @result if (!defined ($hash));
	return @result if (!exists ($hash->{hmccu}{interfaces}{$iface}) &&
		!exists ($hash->{hmccu}{ifports}{$iface}));
	
	my $ifname = $iface =~ /^[0-9]+$/ ? $hash->{hmccu}{ifports}{$iface} : $iface;
	return @result if (!exists ($hash->{hmccu}{interfaces}{$ifname}));
	
#	HMCCU_Log ($hash, 2, "Interface name = $ifname", 0);
	
	foreach my $i (split (',', $info)) {
#		HMCCU_Log ($hash, 2, "Infotoken = $i", 0);
		if ($i eq 'name') {
			push (@result, $ifname);
		}
		else {
			my $v = exists ($hash->{hmccu}{interfaces}{$ifname}{$i}) ?
				$hash->{hmccu}{interfaces}{$ifname}{$i} : undef;
#			HMCCU_Log ($hash, 2, "Tokenvalue = $v", 0);
			push @result, $v;
		}
	}
	
	return @result;
}

######################################################################
# Check if RPC interface is of specified type.
# Parameter type is A for XML or B for binary.
######################################################################

sub HMCCU_IsRPCType ($$$)
{
	my ($hash, $iface, $type) = @_;
	
	my ($rpctype) = HMCCU_GetRPCServerInfo ($hash, $iface, 'type');
	return 0 if (!defined ($rpctype));
	
	return $rpctype eq $type ? 1 : 0;
}

######################################################################
# Register RPC callbacks at CCU if RPC-Server already in server loop
######################################################################

sub HMCCU_RPCRegisterCallback ($)
{
	my ($hash) = @_;
	my $name = $hash->{NAME};
	my $localaddr = $hash->{hmccu}{localaddr};

	my $rpcinterval = AttrVal ($name, 'rpcinterval', $HMCCU_INIT_INTERVAL2);
	my @rpcports = HMCCU_GetRPCPortList ($hash);

	foreach my $port (@rpcports) {
		my $clkey = 'CB'.$port;
		my $cburl = HMCCU_GetRPCCallbackURL ($hash, $localaddr, $hash->{hmccu}{rpc}{$clkey}{cbport},
			$clkey, $port);
		next if (!defined ($cburl));
		my ($url, $rpcflags) = HMCCU_GetRPCServerInfo ($hash, $port, 'url,flags');
		next if (!defined ($url) || !defined ($rpcflags));
		if ($hash->{hmccu}{rpc}{$clkey}{loop} == 1 ||
			$hash->{hmccu}{rpc}{$clkey}{state} eq "register") {		
			$hash->{hmccu}{rpc}{$clkey}{port} = $port;
			$hash->{hmccu}{rpc}{$clkey}{clurl} = $url;
			$hash->{hmccu}{rpc}{$clkey}{cburl} = $cburl;
			$hash->{hmccu}{rpc}{$clkey}{loop} = 2;
			$hash->{hmccu}{rpc}{$clkey}{state} = $rpcflags =~ /forceInit/ ? "running" : "registered";

			Log3 $name, 1, "HMCCU: Registering callback $cburl with ID $clkey at $url";
			my $rpcclient = RPC::XML::Client->new ($url);
			$rpcclient->send_request ("init", $cburl, $clkey);
			Log3 $name, 1, "HMCCU: RPC callback with URL $cburl initialized";
		}
	}
	
	# Schedule reading of RPC queue
	InternalTimer (gettimeofday()+$rpcinterval, 'HMCCU_ReadRPCQueue', $hash, 0);
}

######################################################################
# Deregister RPC callbacks at CCU
######################################################################

sub HMCCU_RPCDeRegisterCallback ($)
{
	my ($hash) = @_;
	my $name = $hash->{NAME};
	
	foreach my $clkey (keys %{$hash->{hmccu}{rpc}}) {
		my $rpchash = \%{$hash->{hmccu}{rpc}{$clkey}};
		if (exists ($rpchash->{cburl}) && $rpchash->{cburl} ne '') {
			my $port = $rpchash->{port};
			my $rpcclient = RPC::XML::Client->new ($rpchash->{clurl});
			Log3 $name, 1, "HMCCU: Deregistering RPC server ".$rpchash->{cburl}.
			   " at ".$rpchash->{clurl};
			$rpcclient->send_request("init", $rpchash->{cburl});
			$rpchash->{cburl} = '';
			$rpchash->{clurl} = '';
			$rpchash->{cbport} = 0;
		}
	}
}

######################################################################
# Initialize statistic counters
######################################################################

sub HMCCU_ResetCounters ($)
{
	my ($hash) = @_;
	my @counters = ('total', 'EV', 'ND', 'IN', 'DD', 'RA', 'RD', 'UD', 'EX', 'SL', 'ST');
	
	foreach my $cnt (@counters) {
		$hash->{hmccu}{ev}{$cnt} = 0;
	}
	delete $hash->{hmccu}{evs};
	delete $hash->{hmccu}{evr};

	$hash->{hmccu}{evtimeout} = 0;
	$hash->{hmccu}{evtime} = 0;
}

######################################################################
# Start external RPC server via RPC device.
# Return number of RPC servers or 0 on error.
######################################################################

sub HMCCU_StartExtRPCServer ($)
{
	my ($hash) = @_;
	my $name = $hash->{NAME};

	my $ccuflags = AttrVal ($name, 'ccuflags', 'null');
	my $attrset = 0;

	# Change RPC type to procrpc
	if ($ccuflags =~ /(extrpc|intrpc)/) {
		$ccuflags =~ s/(extrpc|intrpc)/procrpc/g;
		CommandAttr (undef, "$name ccuflags $ccuflags");
		$attrset = 1;
		
		# Disable existing devices of type HMCCURPC
		foreach my $d (keys %defs) {
			my $ch = $defs{$d};
			next if (!exists ($ch->{TYPE}) || !exists ($ch->{NAME}));
			next if ($ch->{TYPE} ne 'HMCCURPC');
			CommandAttr (undef, $ch->{NAME}." disable 1") if (IsDisabled ($ch->{NAME}) != 1);
		}
	}
	
	my $c = 0;
	my $d = 0;
	my $s = 0;
	my @iflist = HMCCU_GetRPCInterfaceList ($hash);
	foreach my $ifname1 (@iflist) {
		HMCCU_Log ($hash, 2, "Get RPC device for interface $ifname1");
		my ($rpcdev, $save) = HMCCU_GetRPCDevice ($hash, 1, $ifname1);
		next if ($rpcdev eq '' || !defined ($hash->{hmccu}{interfaces}{$ifname1}{device}));
		$d++;
		$s++ if ($save);
	}

	# Save FHEM config if new RPC devices were defined or attribute has changed
	if ($s > 0 || $attrset) {
		HMCCU_Log ($hash, 1, "Saving FHEM config");
		CommandSave (undef, undef);
	}

	if ($d == scalar (@iflist)) {
		foreach my $ifname2 (@iflist) {
			my $dh = $defs{$hash->{hmccu}{interfaces}{$ifname2}{device}};
			$hash->{hmccu}{interfaces}{$ifname2}{manager} = 'HMCCU';
			my ($rc, $msg) = HMCCURPCPROC_StartRPCServer ($dh);
			if (!$rc) {
				HMCCU_SetRPCState ($hash, 'error', $ifname2, $msg);
			}
			else {
				$c++;
			}
		}
		HMCCU_SetRPCState ($hash, 'starting') if ($c > 0);
		return $c;
	}
	else {
		HMCCU_Log ($hash, 0, "Definition of some RPC devices failed");
	}
	
	return 0;
}

######################################################################
# Stop external RPC server via RPC device.
######################################################################

sub HMCCU_StopExtRPCServer ($;$)
{
	my ($hash, $wait) = @_;
	my $name = $hash->{NAME};

# 	if (HMCCU_IsFlag ($name, "(extrpc|procrpc)")) {
		return HMCCU_Log ($hash, 0, "Module HMCCURPCPROC not loaded") if (!exists ($modules{'HMCCURPCPROC'}));
		HMCCU_SetRPCState ($hash, 'stopping');

		my $rc = 1;
		my @iflist = HMCCU_GetRPCInterfaceList ($hash);
		foreach my $ifname (@iflist) {
			my ($rpcdev, $save) = HMCCU_GetRPCDevice ($hash, 0, $ifname);
			if ($rpcdev eq '') {
				HMCCU_Log ($hash, 0, "HMCCU: Can't find RPC device");
				next;
			}
			$hash->{hmccu}{interfaces}{$ifname}{manager} = 'HMCCU';
			$rc &= HMCCURPCPROC_StopRPCServer ($defs{$rpcdev}, $wait);
		}
		
		return $rc;
# 	}
}

######################################################################
# Start internal file queue based RPC server.
# Return number of RPC server processes or 0 on error.
######################################################################

sub HMCCU_StartIntRPCServer ($)
{
	my ($hash) = @_;
	my $name = $hash->{NAME};

	# Timeouts
	my $timeout = AttrVal ($name, 'rpctimeout', '0.01,0.25');
	my ($to_read, $to_write) = split (",", $timeout);
	$to_write = $to_read if (!defined ($to_write));
	
	# Address and ports
	my $rpcqueue = AttrVal ($name, 'rpcqueue', '/tmp/ccuqueue');
	my $localaddr = AttrVal ($name, 'rpcserveraddr', '');
	my $rpcserverport = AttrVal ($name, 'rpcserverport', 5400);
	my $rpcinterval = AttrVal ($name, 'rpcinterval', $HMCCU_INIT_INTERVAL1);
	my @rpcportlist = HMCCU_GetRPCPortList ($hash);
	my ($serveraddr) = HMCCU_GetRPCServerInfo ($hash, $rpcportlist[0], 'host');
	my $fork_cnt = 0;

	HMCCU_Log ($hash, 1, "Internal RPC server is depricated and will be removed soon. Set ccuflags to procrpc");
	
	# Check for running RPC server processes	
	my @hm_pids;
	my @hm_tids;
	HMCCU_IsRPCServerRunning ($hash, \@hm_pids, \@hm_tids);
	if (scalar (@hm_pids) > 0) {
		return HMCCU_Log ($hash, 0, "RPC server(s) already running with PIDs ".join (',', @hm_pids),
			scalar (@hm_pids));
	}
	elsif (scalar (@hm_tids) > 0) {
		return HMCCU_Log ($hash, 1, "RPC server(s) already running with TIDs ".join (',', @hm_tids),
			0);
	}

	# Detect local IP address
	if ($localaddr eq '') {
		$localaddr = HMCCU_TCPConnect ($serveraddr, $rpcportlist[0]);
		return HMCCU_Log ($hash, 1, "Can't connect to RPC host $serveraddr port".$rpcportlist[0], 0)
			if ($localaddr eq '');
	}
	$hash->{hmccu}{localaddr} = $localaddr;

	my $ccunum = $hash->{CCUNum};
	
	# Fork child processes
	foreach my $port (@rpcportlist) {
		my $clkey = 'CB'.$port;
		my $rpcqueueport = $rpcqueue."_".$port."_".$ccunum;
		my $callbackport = $rpcserverport+$port+($ccunum*10);

		# Clear event queue
		HMCCU_ResetRPCQueue ($hash, $port);
		
		# Create child process
		Log3 $name, 2, "HMCCU: Create child process with timeouts $to_read and $to_write";
		my $child = SubProcess->new ({ onRun => \&HMCCU_CCURPC_OnRun,
			onExit => \&HMCCU_CCURPC_OnExit, timeoutread => $to_read, timeoutwrite => $to_write });
		$child->{serveraddr}   = $serveraddr;
		$child->{serverport}   = $port;
		$child->{callbackport} = $callbackport;
		$child->{devname}      = $name;
		$child->{queue}        = $rpcqueueport;
		
		# Start child process
		my $pid = $child->run ();
		if (!defined ($pid)) {
			Log3 $name, 1, "HMCCU: No RPC process for server $clkey started";
			next;
		}
		
		Log3 $name, 0, "HMCCU: Child process for server $clkey started with PID $pid";
		$fork_cnt++;

		# Store child process parameters
		$hash->{hmccu}{rpc}{$clkey}{child}  = $child;
		$hash->{hmccu}{rpc}{$clkey}{cbport} = $callbackport;
		$hash->{hmccu}{rpc}{$clkey}{loop}   = 0;
		$hash->{hmccu}{rpc}{$clkey}{pid}    = $pid;
		$hash->{hmccu}{rpc}{$clkey}{queue}  = $rpcqueueport;
		$hash->{hmccu}{rpc}{$clkey}{state}  = "starting";
		push (@hm_pids, $pid);
	}

	$hash->{hmccu}{rpccount}  = $fork_cnt;

	if ($fork_cnt > 0) {	
		# Set internals
		$hash->{RPCPID} = join (',', @hm_pids);
		$hash->{RPCPRC} = "internal";
		
		HMCCU_SetRPCState ($hash, 'starting');

		# Initialize statistic counters
		HMCCU_ResetCounters ($hash);
	
		Log3 $name, 0, "HMCCU: [$name] RPC server(s) starting";
		DoTrigger ($name, "RPC server starting");

		InternalTimer (gettimeofday()+$rpcinterval, 'HMCCU_ReadRPCQueue', $hash, 0);
	}
		
	return $fork_cnt;
}

######################################################################
# Stop RPC server(s) by sending SIGINT to process(es)
######################################################################

sub HMCCU_StopRPCServer ($)
{
	my ($hash) = @_;
	my $name = $hash->{NAME};
	my $pid = 0;

	# Deregister callback URLs in CCU
	HMCCU_RPCDeRegisterCallback ($hash);
		
	# Send signal SIGINT to RPC server processes
	foreach my $clkey (keys %{$hash->{hmccu}{rpc}}) {
		my $rpchash = \%{$hash->{hmccu}{rpc}{$clkey}};
		if (exists ($rpchash->{pid}) && $rpchash->{pid} != 0) {
			Log3 $name, 0, "HMCCU: Stopping RPC server $clkey with PID ".$rpchash->{pid};
			kill ('INT', $rpchash->{pid});
			$rpchash->{state} = "stopping";
		}
		else {
			$rpchash->{state} = "inactive";
		}
	}
	
	# Update status
	HMCCU_SetRPCState ($hash, 'stopping') if ($hash->{hmccu}{rpccount} > 0);
	
	# Wait
	sleep (1);
	
	# Check if processes were terminated
	my @hm_pids;
	my @hm_tids;
	HMCCU_IsRPCServerRunning ($hash, \@hm_pids, \@hm_tids);
	if (scalar (@hm_pids) > 0) {
		foreach my $pid (@hm_pids) {
			Log3 $name, 0, "HMCCU: Stopping RPC server with PID $pid";
			kill ('INT', $pid);
		}
	}
	Log3 $name, 0, "HMCCU: Externally launched RPC server detected." if (scalar (@hm_tids) > 0);
	
	# Wait
	sleep (1);
	
	# Kill the rest
	@hm_pids = ();
	@hm_tids = ();
	if (HMCCU_IsRPCServerRunning ($hash, \@hm_pids, \@hm_tids)) {
		foreach my $pid (@hm_pids) {
			kill ('KILL', $pid);
		}
	}

	# Store number of running RPC servers
	$hash->{hmccu}{rpccount} = HMCCU_IsRPCServerRunning ($hash, undef, undef);

	return $hash->{hmccu}{rpccount} > 0 ? 0 : 1;
}

######################################################################
# Check status of RPC server depending on internal RPCState.
# Return 1 if RPC server is stopping, starting or restarting. During
# this phases CCU reacts very slowly so any get or set command from
# HMCCU devices are disabled.
######################################################################

sub HMCCU_IsRPCStateBlocking ($)
{
	my ($hash) = @_;

	if ($hash->{RPCState} eq "starting" ||
	    $hash->{RPCState} eq "restarting" ||
	    $hash->{RPCState} eq "stopping") {
		return 1;
	}
	else {
		return 0;
	}
}

######################################################################
# Check if RPC servers are running. 
# Return number of running RPC servers. If paramters pids or tids are
# defined also return process or thread IDs.
######################################################################

sub HMCCU_IsRPCServerRunning ($$$)
{
	my ($hash, $pids, $tids) = @_;
	my $name = $hash->{NAME};
	my $c = 0;
	
	my $ccuflags = HMCCU_GetFlags ($name);

# 	if (HMCCU_IsFlag ($name, "(extrpc|procrpc)")) {
		@$pids = () if (defined ($pids));
		my @iflist = HMCCU_GetRPCInterfaceList ($hash);
		foreach my $ifname (@iflist) {
			my ($rpcdev, $save) = HMCCU_GetRPCDevice ($hash, 0, $ifname);
			next if ($rpcdev eq '');
			my $rc = HMCCURPCPROC_CheckProcessState ($defs{$rpcdev}, 'running');
			if ($rc < 0 || $rc > 1) {
				push (@$pids, $rc);
				$c++;
			}
		}
# 	}
# 	else {
# 		@$pids = () if (defined ($pids));
# 		foreach my $clkey (keys %{$hash->{hmccu}{rpc}}) {
# 			if (defined ($hash->{hmccu}{rpc}{$clkey}{pid})) {
# 			   my $pid = $hash->{hmccu}{rpc}{$clkey}{pid};
# 			   if ($pid != 0 && kill (0, $pid)) {
# 			   	push (@$pids, $pid) if (defined ($pids));
# 			   	$c++;
# 			   }
# 			}
# 		}
# 	}
	
	return $c;
}

######################################################################
# Get channels and datapoints of CCU device
######################################################################

sub HMCCU_GetDeviceInfo ($$$)
{
	my ($hash, $device, $ccuget) = @_;
	my $name = $hash->{NAME};
	my $devname = '';
	my $response = '';

	my $hmccu_hash = HMCCU_GetHash ($hash);
	return '' if (!defined ($hmccu_hash));

	my @devlist;
	if ($hash->{ccuif} eq 'fhem' && exists ($hash->{ccugroup})) {
		push @devlist, split (",", $hash->{ccugroup}); 
	}
	else {
		push @devlist, $device;
	}
	return '' if (scalar (@devlist) == 0);
	
	$ccuget = HMCCU_GetAttribute ($hmccu_hash, $hash, 'ccuget', 'Value') if ($ccuget eq 'Attr');

	foreach my $dev (@devlist) {
		my ($int, $add, $chn, $dpt, $nam, $flags) = HMCCU_ParseObject ($hmccu_hash, $dev, 0);
		if ($flags == $HMCCU_FLAG_ADDRESS) {
			$devname = HMCCU_GetDeviceName ($hmccu_hash, $add, '');
			return '' if ($devname eq '');
		}
		else {
			$devname = $nam;
		}

		$response .= HMCCU_HMScriptExt ($hmccu_hash, "!GetDeviceInfo", 
			{ devname => $devname, ccuget => $ccuget }, undef, undef);
		HMCCU_Trace ($hash, 2, undef,
			"Device=$devname Devname=$devname<br>".
			"Script response = \n".$response."<br>".
			"Script = GetDeviceInfo");
	}

	return $response;
}

######################################################################
# Make device info readable
# n=number, b=bool, f=float, i=integer, s=string, a=alarm, p=presence
# e=enumeration
######################################################################

sub HMCCU_FormatDeviceInfo ($)
{
	my ($devinfo) = @_;
	
	my %vtypes = (0, "n", 2, "b", 4, "f", 6, "a", 8, "n", 11, "s", 16, "i", 20, "s", 23, "p", 29, "e");
	my $result = '';
	my $c_oaddr = '';
	
	foreach my $dpspec (split ("\n", $devinfo)) {
		my ($c, $c_addr, $c_name, $d_name, $d_type, $d_value, $d_flags) = split (";", $dpspec);
		if ($c_addr ne $c_oaddr) {
			$result .= "CHN $c_addr $c_name\n";
			$c_oaddr = $c_addr;
		}
		my $t = exists ($vtypes{$d_type}) ? $vtypes{$d_type} : $d_type;
		$result .= "  DPT {$t} $d_name = $d_value [$d_flags]\n";
	}
	
	return $result;
}

######################################################################
# Get available firmware versions from EQ-3 server.
# Firmware version, date and download link are stored in hash
# {hmccu}{type}{$type} in elements {firmware}, {date} and {download}.
# Parameter type can be a regular expression matching valid Homematic
# device types in upper case letters. Default is '.*'. 
# Return number of available firmware downloads.
######################################################################

sub HMCCU_GetFirmwareVersions ($$)
{
	my ($hash, $type) = @_;
	my $name = $hash->{NAME};
	my $ccureqtimeout = AttrVal ($name, "ccuReqTimeout", $HMCCU_TIMEOUT_REQUEST);
	
	my $url = "http://www.eq-3.de/service/downloads.html";
	my $response = GetFileFromURL ($url, $ccureqtimeout, "suchtext=&suche_in=&downloadart=11");
	my @download = $response =~ m/<a.href="(Downloads\/Software\/Firmware\/[^"]+)/g;
	my $dc = 0;
	my @ts = localtime (time);
	$ts[4] += 1;
	$ts[5] += 1900;
	
	foreach my $dl (@download) {
		my $dd = $ts[3];
		my $mm = $ts[4];
		my $yy = $ts[5];
		my $fw;
		my $date = "$dd.$mm.$yy";

		my @path = split (/\//, $dl);
		my $file = pop @path;
		next if ($file !~ /(\.tgz|\.tar\.gz)/);
		
		$file =~ s/_update_V?/\|/;
		my ($dt, $rest) = split (/\|/, $file);
		next if (!defined ($rest));
		$dt =~ s/_/-/g;
		$dt = uc($dt);
		
		next if ($dt !~ /$type/);
		
		if ($rest =~ /^([\d_]+)([0-9]{2})([0-9]{2})([0-9]{2})\./) {
			# Filename with version and date
			($fw, $yy, $mm, $dd) = ($1, $2, $3, $4);
			$yy += 2000 if ($yy < 100);
			$date = "$dd.$mm.$yy";
			$fw =~ s/_$//;
		}
		elsif ($rest =~ /^([\d_]+)\./) {
			# Filename with version
			$fw = $1;
		}
		else {
			$fw = $rest;
		}
		$fw =~ s/_/\./g;

		# Compare firmware dates
		if (exists ($hash->{hmccu}{type}{$dt}{date})) {
			my ($dd1, $mm1, $yy1) = split (/\./, $hash->{hmccu}{type}{$dt}{date});
			my $v1 = $yy1*10000+$mm1*100+$dd1;
			my $v2 = $yy*10000+$mm*100+$dd;
			next if ($v1 > $v2);
		}

		$dc++;		
		$hash->{hmccu}{type}{$dt}{firmware} = $fw;
		$hash->{hmccu}{type}{$dt}{date} = $date;
		$hash->{hmccu}{type}{$dt}{download} = $dl;
	}
	
	return $dc;
}

######################################################################
# Read CCU device identified by device or channel name via Homematic
# Script.
# Return (device count, channel count) or (-1, -1) on error.
######################################################################

sub HMCCU_GetDevice ($$)
{
	my ($hash, $name) = @_;
	
	my $devcount = 0;
	my $chncount = 0;
	my $devname;
	my $devtype;
	my %objects = ();
	
	my $response = HMCCU_HMScriptExt ($hash, "!GetDevice", { name => $name }, undef, undef);
	return (-1, -1) if ($response eq '' || $response =~ /^ERROR:.*/);
	
	my @scrlines = split /[\n\r]+/,$response;
	foreach my $hmdef (@scrlines) {
		my @hmdata = split /;/,$hmdef;
		next if (scalar (@hmdata) == 0);
		my $typeprefix = '';

		if ($hmdata[0] eq 'D') {
			next if (scalar (@hmdata) != 6);
			# 1=Interface 2=Device-Address 3=Device-Name 4=Device-Type 5=Channel-Count
			$objects{$hmdata[2]}{addtype}   = 'dev';
			$objects{$hmdata[2]}{channels}  = $hmdata[5];
			$objects{$hmdata[2]}{flag}      = 'N';
			$objects{$hmdata[2]}{interface} = $hmdata[1];
			$objects{$hmdata[2]}{name}      = $hmdata[3];
			$typeprefix = "CUX-" if ($hmdata[2] =~ /^CUX/);
			$typeprefix = "HVL-" if ($hmdata[1] eq 'HVL');
			$objects{$hmdata[2]}{type}      = $typeprefix . $hmdata[4];
			$objects{$hmdata[2]}{direction} = 0;
			$devname = $hmdata[3];
			$devtype = $typeprefix . $hmdata[4];
		}
		elsif ($hmdata[0] eq 'C') {
			next if (scalar (@hmdata) != 4);
			# 1=Channel-Address 2=Channel-Name 3=Direction
			$objects{$hmdata[1]}{addtype}   = 'chn';
			$objects{$hmdata[1]}{channels}  = 1;
			$objects{$hmdata[1]}{flag}      = 'N';
			$objects{$hmdata[1]}{name}      = $hmdata[2];
			$objects{$hmdata[1]}{valid}     = 1;
			$objects{$hmdata[1]}{direction} = $hmdata[3];
		}
	}

	if (scalar (keys %objects) > 0) {
		# Update HMCCU device tables
		($devcount, $chncount) = HMCCU_UpdateDeviceTable ($hash, \%objects);

		# Read available datapoints for device type
		HMCCU_GetDatapointList ($hash, $devname, $devtype) if (defined ($devname) && defined ($devtype));
	}

	return ($devcount, $chncount);
}

######################################################################
# Read list of CCU devices, channels, interfaces, programs and groups
# via Homematic Script.
# Update data of client devices if not current.
# Return counters (devices, channels, interfaces, programs, groups)
# or (-1, -1, -1, -1, -1) on error.
######################################################################

sub HMCCU_GetDeviceList ($)
{
	my ($hash) = @_;
	my $name = $hash->{NAME};
	
	my $devcount = 0;
	my $chncount = 0;
	my $ifcount = 0;
	my $prgcount = 0;
	my $gcount = 0;
	my %objects = ();
	
	# Read devices, channels, interfaces and groups from CCU
	my $response = HMCCU_HMScriptExt ($hash, "!GetDeviceList", undef, undef, undef);
	return (-1, -1, -1, -1, -1) if ($response eq '' || $response =~ /^ERROR:.*/);
	my $groups = HMCCU_HMScriptExt ($hash, "!GetGroupDevices", undef, undef, undef);
	
	# CCU is reachable
	$hash->{ccustate} = 'active';
	
	# Delete old entries
	%{$hash->{hmccu}{dev}} = ();
	%{$hash->{hmccu}{adr}} = ();
	%{$hash->{hmccu}{interfaces}} = ();
	%{$hash->{hmccu}{grp}} = ();
	%{$hash->{hmccu}{prg}} = ();
	$hash->{hmccu}{updatetime} = time ();

#  Device hash elements for HMCCU_UpdateDeviceTable():
#
#  {address}{flag}      := [N, D, R]
#  {address}{addtype}   := [chn, dev]
#  {address}{channels}  := Number of channels
#  {address}{name}      := Device or channel name
#  {address}{type}      := Homematic device type
#  {address}{usetype}   := Usage type
#  {address}{interface} := Device interface ID
#  {address}{firmware}  := Firmware version of device
#  {address}{version}   := Version of RPC device description
#  {address}{rxmode}    := Transmit mode
#  {address}{direction} := Channel direction: 1=sensor 2=actor 0=none

	my @scrlines = split /[\n\r]+/,$response;
	foreach my $hmdef (@scrlines) {
		my @hmdata = split /;/,$hmdef;
		next if (scalar (@hmdata) == 0);
		my $typeprefix = '';

		if ($hmdata[0] eq 'D') {
			# Device
			next if (scalar (@hmdata) != 6);
			# @hmdata: 1=Interface 2=Device-Address 3=Device-Name 4=Device-Type 5=Channel-Count
			$objects{$hmdata[2]}{addtype}   = 'dev';
			$objects{$hmdata[2]}{channels}  = $hmdata[5];
			$objects{$hmdata[2]}{flag}      = 'N';
			$objects{$hmdata[2]}{interface} = $hmdata[1];
			$objects{$hmdata[2]}{name}      = $hmdata[3];
			$typeprefix = "CUX-" if ($hmdata[2] =~ /^CUX/);
			$typeprefix = "HVL-" if ($hmdata[1] eq 'HVL');
			$objects{$hmdata[2]}{type}      = $typeprefix . $hmdata[4];
			$objects{$hmdata[2]}{direction} = 0;
			# CCU information (address = BidCoS-RF)
			if ($hmdata[2] eq 'BidCoS-RF') {
				$hash->{ccuname} = $hmdata[3];
				$hash->{ccuaddr} = $hmdata[2];
				$hash->{ccuif}   = $hmdata[1];
			}
			# Count devices per interface
			if (exists ($hash->{hmccu}{interfaces}{$hmdata[1]}) &&
				exists ($hash->{hmccu}{interfaces}{$hmdata[1]}{devcount})) {
				$hash->{hmccu}{interfaces}{$hmdata[1]}{devcount}++;
			}
			else {
				$hash->{hmccu}{interfaces}{$hmdata[1]}{devcount} = 1;
			}
		}
		elsif ($hmdata[0] eq 'C') {
			# Channel
			next if (scalar (@hmdata) != 4);
			# @hmdata: 1=Channel-Address 2=Channel-Name 3=Direction
			$objects{$hmdata[1]}{addtype}   = 'chn';
			$objects{$hmdata[1]}{channels}  = 1;
			$objects{$hmdata[1]}{flag}      = 'N';
			$objects{$hmdata[1]}{name}      = $hmdata[2];
			$objects{$hmdata[1]}{valid}     = 1;
			$objects{$hmdata[1]}{direction} = $hmdata[3];
		}
		elsif ($hmdata[0] eq 'I') {
			# Interface
			next if (scalar (@hmdata) != 4);
			# 1=Interface-Name 2=Interface Info 3=URL
			my $ifurl = $hmdata[3];
			if ($ifurl =~ /^([^:]+):\/\/([^:]+):([0-9]+)/) {
				my ($prot, $ipaddr, $port) = ($1, $2, $3);
				next if (!defined ($port) || $port eq '');
				if ($port >= 10000) {
					$port -= 30000;
					$ifurl =~ s/:3$port/:$port/;
				}
				if ($hash->{ccuip} ne 'N/A') {
					$ifurl =~ s/127\.0\.0\.1/$hash->{ccuip}/;
					$ipaddr =~ s/127\.0\.0\.1/$hash->{ccuip}/;					
				}
				else {
					$ifurl =~ s/127\.0\.0\.1/$hash->{host}/;
					$ipaddr =~ s/127\.0\.0\.1/$hash->{host}/;					
				}
				if ($HMCCU_RPC_FLAG{$port} =~ /forceASCII/) {
					$ifurl =~ s/xmlrpc_bin/xmlrpc/;
					$prot = "xmlrpc";
				}
				# Perl module RPC::XML::Client.pm does not support URLs starting with xmlrpc://
				$ifurl =~ s/xmlrpc:/http:/;
				$prot =~ s/^xmlrpc$/http/;
				
				$hash->{hmccu}{interfaces}{$hmdata[1]}{url}     = $ifurl;
				$hash->{hmccu}{interfaces}{$hmdata[1]}{prot}    = $prot;
				$hash->{hmccu}{interfaces}{$hmdata[1]}{type}    = $prot eq 'http' ? 'A' : 'B';
				$hash->{hmccu}{interfaces}{$hmdata[1]}{port}    = $port;
				$hash->{hmccu}{interfaces}{$hmdata[1]}{host}    = $ipaddr;
				$hash->{hmccu}{interfaces}{$hmdata[1]}{state}   = 'inactive';
				$hash->{hmccu}{interfaces}{$hmdata[1]}{manager} = 'null';
				$hash->{hmccu}{interfaces}{$hmdata[1]}{flags}   = $HMCCU_RPC_FLAG{$port};
				if (!exists ($hash->{hmccu}{interfaces}{$hmdata[1]}{devcount})) {
					$hash->{hmccu}{interfaces}{$hmdata[1]}{devcount} = 0;
				}
				$hash->{hmccu}{ifports}{$port} = $hmdata[1];
				$ifcount++;
			}
		}
		elsif ($hmdata[0] eq 'P') {
			# Program
			next if (scalar (@hmdata) != 4);
			# 1=Program-Name 2=Active-Flag 3=Internal-Flag
			$hash->{hmccu}{prg}{$hmdata[1]}{active} = $hmdata[2]; 
			$hash->{hmccu}{prg}{$hmdata[1]}{internal} = $hmdata[3];
			$prgcount++;
		}
	}

	if (scalar (keys %objects) > 0) {
		if ($ifcount > 0) {
			# Configure interfaces and RPC ports
			my $defInterface = $hash->{hmccu}{defInterface};
			my $f = 0;
			$hash->{ccuinterfaces} = join (',', keys %{$hash->{hmccu}{interfaces}});
			if (!exists ($hash->{hmccu}{interfaces}{$defInterface}) ||
				$hash->{hmccu}{interfaces}{$defInterface}{devcount} == 0) {
				HMCCU_Log ($hash, 1, "Default interface $defInterface does not exist or has no devices assigned. Changing default interface."); 
				foreach my $i (@HMCCU_RPC_PRIORITY) {
					if ("$i" ne "$defInterface" && exists ($hash->{hmccu}{interfaces}{$i}) &&
						$hash->{hmccu}{interfaces}{$i}{devcount} > 0) {
						$hash->{hmccu}{defInterface} = $i;
						$hash->{hmccu}{defPort} = $HMCCU_RPC_PORT{$i};
						$f = 1;
						HMCCU_Log ($hash, 1, "Changed default interface from $defInterface to $i");
						last;
					}
				}
				if ($f == 0) {
					HMCCU_Log ($hash, 1, "None of interfaces ".join(',', @HMCCU_RPC_PRIORITY)." exist on CCU");
					return (-1, -1, -1, -1, -1);
				}
			}
			
			# Remove invalid RPC ports
			if (defined ($hash->{hmccu}{rpcports})) {
				my @plist = ();
				foreach my $p (split (',', $hash->{hmccu}{rpcports})) {
					push (@plist, $p) if (exists ($hash->{hmccu}{interfaces}{$HMCCU_RPC_NUMPORT{$p}}));
				}
				$hash->{hmccu}{rpcports} = join (',', @plist);
			}
		}
		else {
			HMCCU_Log ($hash, 1, "Found no interfaces on CCU");
			return (-1, -1, -1, -1, -1);
		}

		# Update HMCCU device tables
		($devcount, $chncount) = HMCCU_UpdateDeviceTable ($hash, \%objects);

		# Read available datapoints for each device type
		# This will lead to problems if some devices have different firmware versions
		# or links to system variables !
		HMCCU_GetDatapointList ($hash, undef, undef);
	}
	
	# Store group configurations
	if ($groups !~ /^ERROR:.*/ && $groups ne '') {
		my @gnames = ($groups =~ m/"NAME":"([^"]+)"/g);
		my @gmembers = ($groups =~ m/"groupMembers":\[[^\]]+\]/g);
		my @gtypes = ($groups =~ m/"groupType":\{"id":"([^"]+)"/g);
	
		foreach my $gm (@gmembers) {
			my $gn = shift @gnames;
			my $gt = shift @gtypes;
			my @ml = ($gm =~ m/,"id":"([^"]+)"/g);
			$hash->{hmccu}{grp}{$gn}{type} = $gt;
			$hash->{hmccu}{grp}{$gn}{devs} = join (',', @ml);
			$gcount++;
		}
	}

	# Store asset counters
	$hash->{hmccu}{ccu}{devcount} = $devcount;
	$hash->{hmccu}{ccu}{chncount} = $chncount;
	$hash->{hmccu}{ccu}{ifcount} = $ifcount;
	$hash->{hmccu}{ccu}{prgcount} = $prgcount;
	$hash->{hmccu}{ccu}{gcount} = $gcount;
	readingsBeginUpdate ($hash);
	readingsBulkUpdate ($hash, "count_devices", $devcount);
	readingsBulkUpdate ($hash, "count_channels", $chncount);
	readingsBulkUpdate ($hash, "count_interfaces", $ifcount);
	readingsBulkUpdate ($hash, "count_programs", $prgcount);
	readingsBulkUpdate ($hash, "count_groups", $gcount);
	readingsEndUpdate ($hash, 1);
	
	return ($devcount, $chncount, $ifcount, $prgcount, $gcount);
}

######################################################################
# Read list of datapoints for all or one CCU device type(s).
# Function must not be called before GetDeviceList.
# Return number of datapoints read.
######################################################################

sub HMCCU_GetDatapointList ($$$)
{
	my ($hash, $devname, $devtype) = @_;
	my $name = $hash->{NAME};

	my @devunique;

	if (defined ($devname) && defined ($devtype)) {
		return 0 if (exists ($hash->{hmccu}{dp}{$devtype}));
		push @devunique, $devname;
	}
	else {
		if (exists ($hash->{hmccu}{dp})) {
			delete $hash->{hmccu}{dp};
		}

		# Select one device for each device type
		my %alltypes;
		foreach my $add (sort keys %{$hash->{hmccu}{dev}}) {
			next if ($hash->{hmccu}{dev}{$add}{addtype} ne 'dev');
			my $dt = $hash->{hmccu}{dev}{$add}{type};
			if (defined ($dt)) {
				if ($dt ne '' && !exists ($alltypes{$dt})) {
					$alltypes{$dt} = 1;
					push @devunique, $hash->{hmccu}{dev}{$add}{name};
				}
			}
			else {
				HMCCU_Log ($hash, 2, "Corrupt or invalid entry in device table for device $add");
			}
		}
	}

	return HMCCU_Log ($hash, 2, "No device types found in device table. Cannot read datapoints.", 0)
		if (scalar (@devunique) == 0);
	
	my $devlist = join (',', @devunique);
	my $response = HMCCU_HMScriptExt ($hash, "!GetDatapointList",
		{ list => $devlist }, undef, undef);
	return HMCCU_Log ($hash, 2, "Cannot get datapoint list", 0)
		if ($response eq '' || $response =~ /^ERROR:.*/);

	my $c = 0;	
	foreach my $dpspec (split /[\n\r]+/,$response) {
		my ($iface, $chna, $devt, $devc, $dptn, $dptt, $dpto) = split (";", $dpspec);
		$devt = "CUX-".$devt if ($iface eq 'CUxD');
		$devt = "HVL-".$devt if ($iface eq 'HVL');
		$hash->{hmccu}{dp}{$devt}{spc}{ontime} = $devc.".".$dptn if ($dptn eq "ON_TIME");
		$hash->{hmccu}{dp}{$devt}{spc}{ramptime} = $devc.".".$dptn if ($dptn eq "RAMP_TIME");
		$hash->{hmccu}{dp}{$devt}{spc}{submit} = $devc.".".$dptn if ($dptn eq "SUBMIT");
		$hash->{hmccu}{dp}{$devt}{spc}{level} = $devc.".".$dptn if ($dptn eq "LEVEL");		
		$hash->{hmccu}{dp}{$devt}{ch}{$devc}{$dptn}{type} = $dptt;
		$hash->{hmccu}{dp}{$devt}{ch}{$devc}{$dptn}{oper} = $dpto;
		if (exists ($hash->{hmccu}{dp}{$devt}{cnt}{$dptn})) {
			$hash->{hmccu}{dp}{$devt}{cnt}{$dptn}++;
		}
		else {
			$hash->{hmccu}{dp}{$devt}{cnt}{$dptn} = 1;
		}
		$c++;
	}
	
	return $c;
}

######################################################################
# Check if device/channel name or address is valid and refers to an
# existing device or channel.
# mode: Bit combination: 1=Address 2=Name 4=Special address
######################################################################

sub HMCCU_IsValidDeviceOrChannel ($$$)
{
	my ($hash, $param, $mode) = @_;

	return HMCCU_IsValidDevice ($hash, $param, $mode) || HMCCU_IsValidChannel ($hash, $param, $mode) ? 1 : 0;
}

######################################################################
# Check if device name or address is valid and refers to an existing
# device.
# mode: Bit combination: 1=Address 2=Name 4=Special address
######################################################################

sub HMCCU_IsValidDevice ($$$)
{
	my ($hash, $param, $mode) = @_;

	# Address
	if ($mode & $HMCCU_FL_STADDRESS) {
		my $i;
		my $a = 'null';
		
		# Address with interface
		if (HMCCU_IsDevAddr ($param, 1)) {
			($i, $a) = split (/\./, $param);
		}
		elsif (HMCCU_IsDevAddr ($param, 0)) {
			$a = $param;
		}
# 		else {
# 			HMCCU_Log ($hash, 3, "$param is not a valid address", 0);
# 		}

		if (exists ($hash->{hmccu}{dev}{$a})) {
			return $hash->{hmccu}{dev}{$a}{valid};		
		}
# 		else {
# 			HMCCU_Log ($hash, 3, "Address $param not found", 0);
# 		}
		
		# Special address for Non-Homematic devices
		if (($mode & $HMCCU_FL_EXADDRESS) && exists ($hash->{hmccu}{dev}{$param})) {
			return $hash->{hmccu}{dev}{$param}{valid} && $hash->{hmccu}{dev}{$param}{addtype} eq 'dev' ? 1 : 0;
		}
		
# 		HMCCU_Log ($hash, 3, "Invalid address $param", 0);
	}
	
	# Name
	if (($mode & $HMCCU_FL_NAME)) {
		if (exists ($hash->{hmccu}{adr}{$param})) {
			return $hash->{hmccu}{adr}{$param}{valid} && $hash->{hmccu}{adr}{$param}{addtype} eq 'dev' ? 1 : 0;
		}
# 		else {
# 			HMCCU_Log ($hash, 3, "Device $param not found", 0);
# 		}
	}

	return 0;
}

######################################################################
# Check if channel name or address is valid and refers to an existing
# channel.
# mode: Bit combination: 1=Address 2=Name 4=Special address
######################################################################

sub HMCCU_IsValidChannel ($$$)
{
	my ($hash, $param, $mode) = @_;

	# Standard address for Homematic devices
	if ($mode & $HMCCU_FL_STADDRESS) {
		# Address with interface
		if (($mode & $HMCCU_FL_STADDRESS) && HMCCU_IsChnAddr ($param, 1)) {
			my ($i, $a) = split (/\./, $param);
			return 0 if (! exists ($hash->{hmccu}{dev}{$a}));
			return $hash->{hmccu}{dev}{$a}{valid};		
		}
	
		# Address without interface
		if (HMCCU_IsChnAddr ($param, 0)) {
			return 0 if (! exists ($hash->{hmccu}{dev}{$param}));
			return $hash->{hmccu}{dev}{$param}{valid};
		}
	}

	# Special address for Non-Homematic devices
	if (($mode & $HMCCU_FL_EXADDRESS) && exists ($hash->{hmccu}{dev}{$param})) {
		return $hash->{hmccu}{dev}{$param}{valid} && $hash->{hmccu}{dev}{$param}{addtype} eq 'chn' ? 1 : 0;
	}

	# Name
	if (($mode & $HMCCU_FL_NAME) && exists ($hash->{hmccu}{adr}{$param})) {
		return $hash->{hmccu}{adr}{$param}{valid} && $hash->{hmccu}{adr}{$param}{addtype} eq 'chn' ? 1 : 0;
	}

	return 0;
}

######################################################################
# Get CCU parameters of device or channel.
# Returns list containing interface, deviceaddress, name, type and
# channels.
######################################################################

sub HMCCU_GetCCUDeviceParam ($$)
{
	my ($hash, $param) = @_;
	my $name = $hash->{NAME};
	my $devadd;
	my $add = undef;
	my $chn = undef;

	if (HMCCU_IsDevAddr ($param, 1) || HMCCU_IsChnAddr ($param, 1)) {
		my $i;
		($i, $add) = split (/\./, $param);
	}
	else {
		if (HMCCU_IsDevAddr ($param, 0) || HMCCU_IsChnAddr ($param, 0)) {
			$add = $param;
		}
		else {
			if (exists ($hash->{hmccu}{adr}{$param})) {
				# param is a device name
				$add = $hash->{hmccu}{adr}{$param}{address};
			}
			elsif (exists ($hash->{hmccu}{dev}{$param})) {
				# param is a non standard device or channel address
				$add = $param;
			}
		}
	}
	
	return (undef, undef, undef, undef) if (!defined ($add));
	($devadd, $chn) = split (':', $add);
	return (undef, undef, undef, undef) if (!defined ($devadd) ||
		!exists ($hash->{hmccu}{dev}{$devadd}) || $hash->{hmccu}{dev}{$devadd}{valid} == 0);
	
	return ($hash->{hmccu}{dev}{$devadd}{interface}, $add, $hash->{hmccu}{dev}{$add}{name},
		$hash->{hmccu}{dev}{$devadd}{type}, $hash->{hmccu}{dev}{$add}{channels});
}

######################################################################
# Get list of valid datapoints for device type.
# hash = hash of client or IO device
# devtype = Homematic device type
# chn = Channel number, -1=all channels
# oper = Valid operation: 1=Read, 2=Write, 4=Event
# dplistref = Reference for array with datapoints.
# Return number of datapoints.
######################################################################

sub HMCCU_GetValidDatapoints ($$$$$)
{
	my ($hash, $devtype, $chn, $oper, $dplistref) = @_;
	
	my $hmccu_hash = HMCCU_GetHash ($hash);
	
	return 0 if (HMCCU_IsFlag ($hmccu_hash->{NAME}, "dptnocheck"));
	return 0 if (!exists ($hmccu_hash->{hmccu}{dp}));
	return HMCCU_Log ($hash, 2, "chn undefined") if (!defined ($chn));
	
	if ($chn >= 0) {
		if (exists ($hmccu_hash->{hmccu}{dp}{$devtype}{ch}{$chn})) {
			foreach my $dp (sort keys %{$hmccu_hash->{hmccu}{dp}{$devtype}{ch}{$chn}}) {
				if ($hmccu_hash->{hmccu}{dp}{$devtype}{ch}{$chn}{$dp}{oper} & $oper) {
					push @$dplistref, $dp;
				}
			}
		}
	}
	else {
		if (exists ($hmccu_hash->{hmccu}{dp}{$devtype})) {
			foreach my $ch (sort keys %{$hmccu_hash->{hmccu}{dp}{$devtype}{ch}}) {
				foreach my $dp (sort keys %{$hmccu_hash->{hmccu}{dp}{$devtype}{ch}{$ch}}) {
					if ($hmccu_hash->{hmccu}{dp}{$devtype}{ch}{$ch}{$dp}{oper} & $oper) {
						push @$dplistref, $ch.".".$dp;
					}
				}
			}
		}
	}
	
	return scalar (@$dplistref);
}

######################################################################
# Get datapoint attribute.
# Valid attributes are 'oper' or 'type'.
######################################################################

sub HMCCU_GetDatapointAttr ($$$$$)
{
	my ($hash, $devtype, $chnno, $dpt, $attr) = @_;
	
	return undef if ($attr ne 'oper' && $attr ne 'type');
	return undef if (!exists ($hash->{hmccu}{dp}{$devtype}));
	return undef if (!exists ($hash->{hmccu}{dp}{$devtype}{ch}{$chnno}));
	return undef if (!exists ($hash->{hmccu}{dp}{$devtype}{ch}{$chnno}{$dpt}));
	return $hash->{hmccu}{dp}{$devtype}{ch}{$chnno}{$dpt}{$attr};
}

######################################################################
# Find a datapoint for device type.
# hash = hash of client or IO device
# devtype = Homematic device type
# chn = Channel number, -1=all channels
# oper = Valid operation: 1=Read, 2=Write, 4=Event
# Return channel of first match or -1.
######################################################################

sub HMCCU_FindDatapoint ($$$$$)
{
	my ($hash, $devtype, $chn, $dpt, $oper) = @_;
	
	my $hmccu_hash = HMCCU_GetHash ($hash);

	return -1 if (!exists ($hmccu_hash->{hmccu}{dp}));
	
	if ($chn >= 0) {
		if (exists ($hmccu_hash->{hmccu}{dp}{$devtype}{ch}{$chn})) {
			foreach my $dp (sort keys %{$hmccu_hash->{hmccu}{dp}{$devtype}{ch}{$chn}}) {
				return $chn if ($dp eq $dpt &&
					$hmccu_hash->{hmccu}{dp}{$devtype}{ch}{$chn}{$dp}{oper} & $oper);
			}
		}
	}
	else {
		if (exists ($hmccu_hash->{hmccu}{dp}{$devtype})) {
			foreach my $ch (sort keys %{$hmccu_hash->{hmccu}{dp}{$devtype}{ch}}) {
				foreach my $dp (sort keys %{$hmccu_hash->{hmccu}{dp}{$devtype}{ch}{$ch}}) {
					return $ch if ($dp eq $dpt &&
						$hmccu_hash->{hmccu}{dp}{$devtype}{ch}{$ch}{$dp}{oper} & $oper);
				}
			}
		}
	}
	
	return -1;
}

######################################################################
# Get channel number and datapoint name for special datapoint.
# Valid modes are ontime, ramptime, submit, level
######################################################################

sub HMCCU_GetSwitchDatapoint ($$$)
{
	my ($hash, $devtype, $mode) = @_;

	my $hmccu_hash = HMCCU_GetHash ($hash);
		
	if (exists ($hmccu_hash->{hmccu}{dp}{$devtype}{spc}{$mode})) {
		return $hmccu_hash->{hmccu}{dp}{$devtype}{spc}{$mode};
	}
	else {
		return '';
	}
}

######################################################################
# Check if datapoint is valid.
# Parameter chn can be a channel address or a channel number. If dpt
# contains a channel number parameter chn should be set to undef.
# Parameter dpt can contain a channel number.
# Parameter oper specifies access flag:
#   1 = datapoint readable
#   2 = datapoint writeable
# Return 1 if ccuflags is set to dptnocheck or datapoint is valid.
# Otherwise 0.
######################################################################

sub HMCCU_IsValidDatapoint ($$$$$)
{
	my ($hash, $devtype, $chn, $dpt, $oper) = @_;
	my $fnc = "IsValidDatapoint";
	
	my $hmccu_hash = HMCCU_GetHash ($hash);
	return 0 if (!defined ($hmccu_hash));
	
	if ($hash->{TYPE} eq 'HMCCU' && !defined ($devtype)) {
		$devtype = HMCCU_GetDeviceType ($hmccu_hash, $chn, 'null');
	}
	
	return 1 if (HMCCU_IsFlag ($hmccu_hash->{NAME}, "dptnocheck"));
	return 1 if (!exists ($hmccu_hash->{hmccu}{dp}));

	my $chnno;
	if (defined ($chn)) {
		if ($chn =~ /^[0-9]{1,2}$/) {
			$chnno = $chn;
		}
		elsif (HMCCU_IsValidChannel ($hmccu_hash, $chn, $HMCCU_FL_ADDRESS)) {
			my ($a, $c) = split(":",$chn);
			$chnno = $c;
		}
		else {
			HMCCU_Trace ($hash, 2, $fnc, "$chn is not a valid channel address or number");
			return 0;
		}
	}
	elsif ($dpt =~ /^([0-9]{1,2})\.(.+)$/) {
		$chnno = $1;
		$dpt = $2;
	}
	else {
		HMCCU_Trace ($hash, 2, $fnc, "channel number missing in datapoint $dpt");
		return 0;
	}
	
	
	my $v = (exists ($hmccu_hash->{hmccu}{dp}{$devtype}{ch}{$chnno}{$dpt}) &&
	   ($hmccu_hash->{hmccu}{dp}{$devtype}{ch}{$chnno}{$dpt}{oper} & $oper)) ? 1 : 0;
	HMCCU_Trace ($hash, 2, $fnc, "devtype=$devtype, chnno=$chnno, dpt=$dpt, valid=$v");
	
	return $v;
}

######################################################################
# Get list of device or channel addresses for which device or channel
# name matches regular expression.
# Parameter mode can be 'dev' or 'chn'.
# Return number of matching entries.
######################################################################

sub HMCCU_GetMatchingDevices ($$$$)
{
	my ($hash, $regexp, $mode, $listref) = @_;
	my $c = 0;

	foreach my $name (sort keys %{$hash->{hmccu}{adr}}) {
		next if ($name !~/$regexp/ || $hash->{hmccu}{adr}{$name}{addtype} ne $mode ||
		   $hash->{hmccu}{adr}{$name}{valid} == 0);
		push (@$listref, $hash->{hmccu}{adr}{$name}{address});
		$c++;
	}

	return $c;
}

######################################################################
# Get name of a CCU device by address.
# Channel number will be removed if specified.
######################################################################

sub HMCCU_GetDeviceName ($$$)
{
	my ($hash, $addr, $default) = @_;

	if (HMCCU_IsValidDeviceOrChannel ($hash, $addr, $HMCCU_FL_ADDRESS)) {
		$addr =~ s/:[0-9]+$//;
		return $hash->{hmccu}{dev}{$addr}{name};
	}

	return $default;
}

######################################################################
# Get name of a CCU device channel by address.
######################################################################

sub HMCCU_GetChannelName ($$$)
{
	my ($hash, $addr, $default) = @_;

	if (HMCCU_IsValidChannel ($hash, $addr, $HMCCU_FL_ADDRESS)) {
		return $hash->{hmccu}{dev}{$addr}{name};
	}

	return $default;
}

######################################################################
# Get type of a CCU device by address.
# Channel number will be removed if specified.
######################################################################

sub HMCCU_GetDeviceType ($$$)
{
	my ($hash, $addr, $default) = @_;

	if (HMCCU_IsValidDeviceOrChannel ($hash, $addr, $HMCCU_FL_ADDRESS)) {
		$addr =~ s/:[0-9]+$//;
		return $hash->{hmccu}{dev}{$addr}{type};
	}

	return $default;
}


######################################################################
# Get number of channels of a CCU device.
# Channel number will be removed if specified.
######################################################################

sub HMCCU_GetDeviceChannels ($$$)
{
	my ($hash, $addr, $default) = @_;

	if (HMCCU_IsValidDeviceOrChannel ($hash, $addr, $HMCCU_FL_ADDRESS)) {
		$addr =~ s/:[0-9]+$//;
		return $hash->{hmccu}{dev}{$addr}{channels};
	}

	return 0;
}

######################################################################
# Get default RPC interface and port
######################################################################

sub HMCCU_GetDefaultInterface ($)
{
	my ($hash) = @_;
	
	my $ifname = exists ($hash->{hmccu}{defInterface}) ? $hash->{hmccu}{defInterface} : $HMCCU_RPC_PRIORITY[0];
	my $ifport = $HMCCU_RPC_PORT{$ifname};
	
	return ($ifname, $ifport);
}

######################################################################
# Get interface of a CCU device by address.
# Channel number will be removed if specified.
######################################################################

sub HMCCU_GetDeviceInterface ($$$)
{
	my ($hash, $addr, $default) = @_;

	if (HMCCU_IsValidDeviceOrChannel ($hash, $addr, $HMCCU_FL_ADDRESS)) {
		$addr =~ s/:[0-9]+$//;
		return $hash->{hmccu}{dev}{$addr}{interface};
	}

	return $default;
}

######################################################################
# Get address of a CCU device or channel by CCU name or FHEM device
# name defined via HMCCUCHN or HMCCUDEV. FHEM device names must be
# preceded by "hmccu:". CCU names can be preceded by "ccu:".
# Return array with device address and channel no. If name is not
# found or refers to a device the specified default values will be
# returned. 
######################################################################

sub HMCCU_GetAddress ($$$$)
{
	my ($hash, $name, $defadd, $defchn) = @_;
	my $add = $defadd;
	my $chn = $defchn;
	my $chnno = $defchn;
	my $addr = '';
	my $type = '';

	if ($name =~ /^hmccu:.+$/) {
		# Name is a FHEM device name
		$name =~ s/^hmccu://;
		if ($name =~ /^([^:]+):([0-9]{1,2})$/) {
			$name = $1;
			$chnno = $2;
		}
		return ($defadd, $defchn) if (!exists ($defs{$name}));
		my $dh = $defs{$name};
		return ($defadd, $defchn) if ($dh->{TYPE} ne 'HMCCUCHN' && $dh->{TYPE} ne 'HMCCUDEV');
		($add, $chn) = HMCCU_SplitChnAddr ($dh->{ccuaddr});
		$chn = $chnno if ($chn eq '');
		return ($add, $chn);
	}
	elsif ($name =~ /^ccu:.+$/) {
		# Name is a CCU device or channel name
		$name =~ s/^ccu://;
	}

	if (exists ($hash->{hmccu}{adr}{$name})) {
		# Name known by HMCCU
		$addr = $hash->{hmccu}{adr}{$name}{address};
		$type = $hash->{hmccu}{adr}{$name}{addtype};
	}
	elsif (exists ($hash->{hmccu}{dev}{$name})) {
		# Address known by HMCCU
		$addr = $name;
		$type = $hash->{hmccu}{dev}{$name}{addtype};
	}
	else {
		# Address not known. Query CCU
		my ($dc, $cc) = HMCCU_GetDevice ($hash, $name);
		if ($dc > 0 && $cc > 0 && exists ($hash->{hmccu}{adr}{$name})) {
			$addr = $hash->{hmccu}{adr}{$name}{address};
			$type = $hash->{hmccu}{adr}{$name}{addtype};
		}
	}
	
	if ($addr ne '') {
		if ($type eq 'chn') {
			($add, $chn) = split (":", $addr);
		}
		else {
			$add = $addr;
		}
	}

	return ($add, $chn);
}

######################################################################
# Get addresses of group member devices.
# Group 'virtual' is ignored.
# Return list of device addresses or empty list on error.
######################################################################

sub HMCCU_GetGroupMembers ($$)
{
	my ($hash, $group) = @_;
	
	return $group ne 'virtual' && exists ($hash->{hmccu}{grp}{$group}) ?
		split (',', $hash->{hmccu}{grp}{$group}{devs}) : ();
}

######################################################################
# Check if parameter is a channel address (syntax)
# f=1: Interface required.
######################################################################

sub HMCCU_IsChnAddr ($$)
{
	my ($id, $f) = @_;

	if ($f) {
		return ($id =~ /^.+\.[\*]*[A-Z]{3}[0-9]{7}:[0-9]{1,2}$/ ||
		   $id =~ /^.+\.[0-9A-F]{12,14}:[0-9]{1,2}$/ ||
		   $id =~ /^.+\.OL-.+:[0-9]{1,2}$/ ||
		   $id =~ /^.+\.BidCoS-RF:[0-9]{1,2}$/) ? 1 : 0;
	}
	else {
		return ($id =~ /^[\*]*[A-Z]{3}[0-9]{7}:[0-9]{1,2}$/ ||
		   $id =~ /^[0-9A-F]{12,14}:[0-9]{1,2}$/ ||
		   $id =~ /^OL-.+:[0-9]{1,2}$/ ||
		   $id =~ /^BidCoS-RF:[0-9]{1,2}$/) ? 1 : 0;
	}
}

######################################################################
# Check if parameter is a device address (syntax)
# f=1: Interface required.
######################################################################

sub HMCCU_IsDevAddr ($$)
{
	my ($id, $f) = @_;

	if ($f) {
		return ($id =~ /^.+\.[\*]*[A-Z]{3}[0-9]{7}$/ ||
		   $id =~ /^.+\.[0-9A-F]{12,14}$/ ||
		   $id =~ /^.+\.OL-.+$/ ||
		   $id =~ /^.+\.BidCoS-RF$/) ? 1 : 0;
	}
	else {
		return ($id =~ /^[\*]*[A-Z]{3}[0-9]{7}$/ ||
		   $id =~ /^[0-9A-F]{12,14}$/ ||
		   $id =~ /^OL-.+$/ ||
		   $id eq 'BidCoS-RF') ? 1 : 0;
	}
}

######################################################################
# Split channel address into device address and channel number.
# Returns device address only if parameter is already a device address.
######################################################################

sub HMCCU_SplitChnAddr ($)
{
	my ($addr) = @_;

	my ($dev, $chn) = split (':', $addr);
	$chn = '' if (!defined ($chn));

	return ($dev, $chn);
}

sub HMCCU_SplitDatapoint ($;$)
{
	my ($dpt, $defchn) = @_;
	
	my @t = split ('.', $dpt);
	
	return (scalar (@t) > 1) ? @t : ($defchn, $t[0]);
}

######################################################################
# Get list of client devices matching the specified criteria.
# If no criteria is specified all device names will be returned.
# Parameters modexp and namexp are regular expressions for module
# name and device name. Parameter internal contains a comma separated
# list of expressions like internal=valueexp.
# All parameters can be undefined. In this case all devices will be
# returned.
######################################################################
 
sub HMCCU_FindClientDevices ($$$$)
{
	my ($hash, $modexp, $namexp, $internal) = @_;
	my @devlist = ();

	foreach my $d (keys %defs) {
		my $ch = $defs{$d};
		my $m = 1;
		next if (!defined ($ch->{TYPE}) || !defined ($ch->{NAME}));
		next if (defined ($modexp) && $ch->{TYPE} !~ /$modexp/);
		next if (defined ($namexp) && $ch->{NAME} !~ /$namexp/);
		next if (defined ($hash) && exists ($ch->{IODev}) && $ch->{IODev} != $hash);
		if (defined ($internal)) {
			foreach my $intspec (split (',', $internal)) {
				my ($i, $v) = split ('=', $intspec);
				if (defined ($v) && exists ($ch->{$i}) && $ch->{$i} !~ /$v/) {
					$m = 0;
					last;
				}
			}
		}
		push @devlist, $ch->{NAME} if ($m == 1);
	}

	return @devlist;
}

######################################################################
# Get name of assigned client device of type HMCCURPCPROC.
# Create a RPC device of type HMCCURPCPROC if none is found and
# parameter create is set to 1.
# Return (devname, create).
# Return empty string for devname if RPC device cannot be identified
# or created. Return (devname,1) if device has been created and
# configuration should be saved.
######################################################################

sub HMCCU_GetRPCDevice ($$$)
{
	my ($hash, $create, $ifname) = @_;
	my $name = $hash->{NAME};
	my $rpcdevname;
	my $rpcdevtype = 'HMCCURPCPROC';
	my $rpchost = $hash->{host};
	my $rpcprot = $hash->{prot};
	
	my $ccuflags = HMCCU_GetFlags ($name);

# 	if ($ccuflags =~ /(procrpc|extrpc)/) {
		return (HMCCU_Log ($hash, 1, "Interface not defined for RPC server of type HMCCURPCPROC", ''))
			if (!defined ($ifname));
		($rpcdevname, $rpchost) = HMCCU_GetRPCServerInfo ($hash, $ifname, 'device,host');
		return ($rpcdevname, 0) if (defined ($rpcdevname));
		return ('', 0) if (!defined ($rpchost));
#		$rpcdevtype = 'HMCCURPCPROC';
# 	}
# 	elsif ($ccuflags =~ /extrpc/) {
# 		if (defined ($hash->{RPCDEV})) {
# 			if (exists ($defs{$hash->{RPCDEV}})) {
# 				my $rpchash = $defs{$hash->{RPCDEV}};
# 				return (HMCCU_Log ($hash, 1, "RPC device ".$hash->{RPCDEV}." is not assigned to $name", ''), 0)
# 					if (!defined ($rpchash->{IODev}) || $rpchash->{IODev} != $hash);
# 			}
# 			else {
# 				return (HMCCU_Log ($hash, 1, "RPC device ".$hash->{RPCDEV}." not found", ''), 0);
# 			}		
# 			return $hash->{RPCDEV};
# 		}
# 	}
# 	else {
# 		return (HMCCU_Log ($hash, 1, "No need for RPC device when using internal RPC server", ''));
# 	}
	
	# Search for RPC devices associated with I/O device
	my @devlist;
	foreach my $dev (keys %defs) {
		my $devhash = $defs{$dev};
		next if ($devhash->{TYPE} ne $rpcdevtype);
		my $ip = 'null';
		if (!exists ($devhash->{rpcip})) {
			$ip = HMCCU_Resolve ($devhash->{host}, 'null');
		}
		else {
			$ip = $devhash->{rpcip};
		}
		next if ($devhash->{host} ne $rpchost && $ip ne $rpchost);
#		next if ($rpcdevtype eq 'HMCCURPCPROC' && $devhash->{rpcinterface} ne $ifname);
		next if ($devhash->{rpcinterface} ne $ifname);
		push @devlist, $devhash->{NAME};
	}
	my $devcnt = scalar (@devlist);
	if ($devcnt == 1) {
# 		if ($ccuflags =~ /extrpc/) {
# 			$hash->{RPCDEV} = $devlist[0];
# 		}
# 		else {
			$hash->{hmccu}{interfaces}{$ifname}{device} = $devlist[0];
#		}
		return ($devlist[0], 0);
	}
	elsif ($devcnt > 1) {
		return (HMCCU_Log ($hash, 2, "Found more than one RPC device for interface $ifname", ''));
	}
	
	HMCCU_Log ($hash, 1, "No RPC device defined for interface $ifname");
	
	# Create RPC device
	if ($create) {
		my $alias = "CCU RPC $ifname";
		my $rpccreate = '';
		$rpcdevname = "d_rpc";

		# Ensure unique device name by appending last 2 digits of CCU IP address
		$rpcdevname .= HMCCU_GetIdFromIP ($hash->{ccuip}, '') if (exists ($hash->{ccuip}));

		# Build device name and define command
		$rpcdevname = makeDeviceName ($rpcdevname.$ifname);
		$rpccreate = "$rpcdevname $rpcdevtype $rpcprot://$rpchost $ifname";
		return (HMCCU_Log ($hash, 2, "Device $rpcdevname already exists. Please delete or rename it.", ''))
			if (exists ($defs{"$rpcdevname"}));

		# Create RPC device
		HMCCU_Log ($hash, 1, "Creating new RPC device $rpcdevname");
		my $ret = CommandDefine (undef, $rpccreate);
		if (!defined ($ret)) {
			# RPC device created. Set/copy some attributes from HMCCU device
			my %rpcdevattr = ('room' => 'copy', 'group' => 'copy', 'icon' => 'copy',
				'stateFormat' => 'rpcstate/state', 'eventMap' => '/rpcserver on:on/rpcserver off:off/',
				'verbose' => 2, 'alias' => $alias );
			foreach my $a (keys %rpcdevattr) {
				my $v = $rpcdevattr{$a} eq 'copy' ? AttrVal ($name, $a, '') : $rpcdevattr{$a};
				CommandAttr (undef, "$rpcdevname $a $v") if ($v ne '');
			}
#			$hash->{RPCDEV} = $rpcdevname if ($ccuflags =~ /extrpc/);
			return ($rpcdevname, 1);
		}
		else {
			HMCCU_Log ($hash, 1, "Definition of RPC device failed. $ret");
		}
	}
	
	return ('', 0);
}

######################################################################
# Assign IO device to client device.
# Wrapper function for AssignIOPort()
# Parameter $hash refers to a client device of type HMCCURPCPROC,
# HMCCUDEV or HMCCUCHN.
# Parameters ioname and ifname are optional.
# Return 1 on success or 0 on error.
######################################################################

sub HMCCU_AssignIODevice ($$$)
{
	my ($hash, $ioName, $ifName) = @_;
	my $type = $hash->{TYPE};
	my $name = $hash->{NAME};
	my $ioHash;
	
	AssignIoPort ($hash, $ioName);
	
	$ioHash = $hash->{IODev} if (exists ($hash->{IODev}));
	return HMCCU_Log ($hash, 1, "Can't assign I/O device", 0)
		if (!defined ($ioHash) || !exists ($ioHash->{TYPE}) || $ioHash->{TYPE} ne 'HMCCU');
	
	if ($type eq 'HMCCURPCPROC' && defined ($ifName) && exists ($ioHash->{hmccu}{interfaces}{$ifName})) {
		# Register RPC device
		$ioHash->{hmccu}{interfaces}{$ifName}{device} = $name;
	}
	
	return 1;
}

######################################################################
# Get hash of HMCCU IO device which is responsible for device or
# channel specified by parameter. If param is undef the first device
# of type HMCCU will be returned.
######################################################################

sub HMCCU_FindIODevice ($)
{
	my ($param) = @_;
	
	foreach my $dn (sort keys %defs) {
		my $ch = $defs{$dn};
		next if (!exists ($ch->{TYPE}));
		next if ($ch->{TYPE} ne 'HMCCU');
		my $disabled = AttrVal ($ch->{NAME}, 'disable', 0);
		next if ($disabled);
		
		return $ch if (!defined ($param));
		return $ch if (HMCCU_IsValidDeviceOrChannel ($ch, $param, $HMCCU_FL_ALL));
	}
	
	return undef;
}

######################################################################
# Get states of IO devices
######################################################################

sub HMCCU_IODeviceStates ()
{
	my $active = 0;
	my $inactive = 0;
	
	# Search for first HMCCU device
	foreach my $dn (sort keys %defs) {
		my $ch = $defs{$dn};
		next if (!exists ($ch->{TYPE}));
		next if ($ch->{TYPE} ne 'HMCCU');
		if (exists ($ch->{ccustate}) && $ch->{ccustate} eq 'active') {
			$active++;
		}
		else {
			$inactive++;
		}
	}	
	
	return ($active, $inactive);
}

######################################################################
# Get hash of HMCCU IO device. Useful for client devices. Accepts hash
# of HMCCU, HMCCUDEV or HMCCUCHN device as parameter.
# If hash is 0 or undefined the hash of the first device of type HMCCU
# will be returned.
######################################################################

sub HMCCU_GetHash ($@)
{
	my ($hash) = @_;

	if (defined ($hash) && $hash != 0) {
		if ($hash->{TYPE} eq 'HMCCUDEV' || $hash->{TYPE} eq 'HMCCUCHN') {
			return $hash->{IODev} if (exists ($hash->{IODev}));
			return HMCCU_FindIODevice ($hash->{ccuaddr}) if (exists ($hash->{ccuaddr}));
		}
		elsif ($hash->{TYPE} eq 'HMCCU') {
			return $hash;
		}
	}

	# Search for first HMCCU device
	foreach my $dn (sort keys %defs) {
		my $ch = $defs{$dn};
		next if (!exists ($ch->{TYPE}));
		return $ch if ($ch->{TYPE} eq 'HMCCU');
	}

	return undef;
}

######################################################################
# Get attribute of client device. Fallback to attribute of IO device.
######################################################################

sub HMCCU_GetAttribute ($$$$)
{
	my ($hmccu_hash, $cl_hash, $attr_name, $attr_def) = @_;

	my $value = AttrVal ($cl_hash->{NAME}, $attr_name, '');
	$value = AttrVal ($hmccu_hash->{NAME}, $attr_name, $attr_def) if ($value eq '');

	return $value;
}

######################################################################
# Get number of occurrences of datapoint.
# Return 0 if datapoint does not exist.
######################################################################

sub HMCCU_GetDatapointCount ($$$)
{
	my ($hash, $devtype, $dpt) = @_;
	
	if (exists ($hash->{hmccu}{dp}{$devtype}{cnt}{$dpt})) {
		return $hash->{hmccu}{dp}{$devtype}{cnt}{$dpt};
	}
	else {
		return 0;
	}
}

######################################################################
# Get channels and datapoints from attributes statechannel,
# statedatapoint and controldatapoint.
# Return attribute values. Attribute controldatapoint is splitted into
# controlchannel and datapoint name. If attribute statedatapoint
# contains channel number it is splitted into statechannel and
# datapoint name.
# If controldatapoint is not specified it will synchronized with
# statedatapoint.
######################################################################

sub HMCCU_GetSpecialDatapoints ($$$$$)
{
#	my ($hash, $defsc, $defsd, $defcc, $defcd) = @_;
	my ($hash, $sc, $sd, $cc, $cd) = @_;
	my $name = $hash->{NAME};
	my $type = $hash->{TYPE};

	my $statedatapoint = AttrVal ($name, 'statedatapoint', '');
	my $statechannel = AttrVal ($name, 'statechannel', '');
	my $controldatapoint = AttrVal ($name, 'controldatapoint', $statedatapoint);
	
	if ($statedatapoint ne '') {
		if ($statedatapoint =~ /^([0-9]+)\.(.+)$/) {
			($sc, $sd) = ($1, $2);
		}
		else {
			$sd = $statedatapoint;
		}
	}
	$sc = $statechannel if ($statechannel ne '' && $sc eq '');

	if ($controldatapoint ne '') {
		if ($controldatapoint =~ /^([0-9]+)\.(.+)$/) {
			($cc, $cd) = ($1, $2);
		}
		else {
			$cd = $controldatapoint;
		}
	}
	
	# For devices of type HMCCUCHN extract channel numbers from CCU device address
	if ($type eq 'HMCCUCHN') {
		$sc = $hash->{ccuaddr};
		$sc =~ s/^[\*]*[0-9A-Z]+://;
		$cc = $sc;
	}
	
	# Try to find state channel
	my $c = -1;
	if ($sc eq '' && $sd ne '') {
		$c = HMCCU_FindDatapoint ($hash, $hash->{ccutype}, -1, $sd, 3);
		$sc = $c if ($c >= 0);
	}
	
	# Try to find control channel
	if ($cc eq '' && $cd ne '') {
		$c = HMCCU_FindDatapoint  ($hash, $hash->{ccutype}, -1, $cd, 3);
		$cc = $c if ($c >= 0);
	}
	
	# By default set control channel and datapoint to state channel and datapoint
	$cc = $sc if ($cc eq '');
	$cd = $sd if ($cd eq '');

	return ($sc, $sd, $cc, $cd);
}

######################################################################
# Get attribute ccuflags.
# Default value is 'null'. With version 4.4 flags intrpc and extrpc
# are substituted by procrpc.
######################################################################

sub HMCCU_GetFlags ($)
{
	my ($name) = @_;
	
	my $ccuflags = AttrVal ($name, 'ccuflags', 'null');
	$ccuflags =~ s/(extrpc|intrpc)/procrpc/g;
	return $ccuflags;
}

######################################################################
# Check if specific CCU flag is set.
######################################################################

sub HMCCU_IsFlag ($$)
{
	my ($name, $flag) = @_;

	my $ccuflags = AttrVal ($name, 'ccuflags', 'null');
	return $ccuflags =~ /$flag/ ? 1 : 0;
}

######################################################################
# Get reading format considering default attribute
# ccudef-readingformat defined in I/O device.
# Default reading format for virtual groups is always 'name'.
######################################################################

sub HMCCU_GetAttrReadingFormat ($$)
{
	my ($clhash, $iohash) = @_;
	
	my $clname = $clhash->{NAME};
	my $ioname = $iohash->{NAME};
	my $rfdef = '';
	
	if (exists ($clhash->{ccutype}) && $clhash->{ccutype} =~ /^HM-CC-VG/) {
		$rfdef = 'name';
	}
	else {
		$rfdef = AttrVal ($ioname, 'ccudef-readingformat', 'datapoint');
	}
	
	return  AttrVal ($clname, 'ccureadingformat', $rfdef);
}

######################################################################
# Get number format considering default attribute ccudef-stripnumber,
# Default is null
######################################################################

sub HMCCU_GetAttrStripNumber ($)
{
	my ($hash) = @_;
	my $fnc = "GetAttrStripNumber";

	my $snDef = 'null';
	
	if ($hash->{TYPE} ne 'HMCCU') {
		my $ioHash = HMCCU_GetHash ($hash);
		if (defined ($ioHash)) {
			$snDef = AttrVal ($ioHash->{NAME}, 'ccudef-stripnumber', 'null');
		}
	}
	else {
		$snDef = AttrVal ($hash->{NAME}, 'ccudef-stripnumber', 'null');
	}
	
	my $stripnumber = AttrVal ($hash->{NAME}, 'stripnumber', $snDef);
	
	HMCCU_Trace ($hash, 2, $fnc, "stripnumber = $stripnumber");

	return $stripnumber;
}

######################################################################
# Get attributes substitute and substexcl considering default
# attribute ccudef-substitute defined in I/O device.
# Substitute ${xxx} by datapoint value.
######################################################################

sub HMCCU_GetAttrSubstitute ($$)
{
	my ($clhash, $iohash) = @_;
	my $fnc = "GetAttrSubstitute";
	
	my $clname = $clhash->{NAME};
	my $ioname = $iohash->{NAME};

	my $substdef = AttrVal ($ioname, 'ccudef-substitute', '');
	my $subst = AttrVal ($clname, 'substitute', $substdef);
	$subst .= ";$substdef" if ($subst ne $substdef && $substdef ne '');
	HMCCU_Trace ($clhash, 2, $fnc, "subst = $subst");
	
	return $subst if ($subst !~ /\$\{.+\}/);

	$subst = HMCCU_SubstVariables ($clhash, $subst, undef);

	HMCCU_Trace ($clhash, 2, $fnc, "subst_vars = $subst");
	
	return $subst;
}

######################################################################
# Clear RPC queue
######################################################################

sub HMCCU_ResetRPCQueue ($$)
{
	my ($hash, $port) = @_;
	my $name = $hash->{NAME};

	my $rpcqueue = AttrVal ($name, 'rpcqueue', '/tmp/ccuqueue');
	my $clkey = 'CB'.$port;

	if (HMCCU_QueueOpen ($hash, $rpcqueue."_".$port."_".$hash->{CCUNum})) {
		HMCCU_QueueReset ($hash);
		while (defined (HMCCU_QueueDeq ($hash))) { }
		HMCCU_QueueClose ($hash);
	}
	$hash->{hmccu}{rpc}{$clkey}{queue} = '' if (exists ($hash->{hmccu}{rpc}{$clkey}{queue}));
}

######################################################################
# Process RPC server event
######################################################################

sub HMCCU_ProcessEvent ($$)
{
	my ($hash, $event) = @_;
	my $name = $hash->{NAME};
	my $rh = \%{$hash->{hmccu}{rpc}};
	
	return undef if (!defined ($event) || $event eq '');

	my @t = split (/\|/, $event);
	my $tc = scalar (@t);

	# Update statistic counters
	if (exists ($hash->{hmccu}{ev}{$t[0]})) {
		$hash->{hmccu}{evtime} = time ();
		$hash->{hmccu}{ev}{total}++;
		$hash->{hmccu}{ev}{$t[0]}++;
		$hash->{hmccu}{evtimeout} = 0 if ($hash->{hmccu}{evtimeout} == 1);
	}
	else {
		my $errtok = $t[0];
		$errtok =~ s/([\x00-\xFF])/sprintf("0x%X ",ord($1))/eg;
		return HMCCU_Log ($hash, 2, "Received unknown event from CCU: ".$errtok);
	}
	
	# Check event syntax
	return HMCCU_Log ($hash, 2, "Wrong number of parameters in event $event")
		if (exists ($rpceventargs{$t[0]}) && ($tc-1) != $rpceventargs{$t[0]});
		
	if ($t[0] eq 'EV') {
		#
		# Update of datapoint
		# Input:  EV|Adress|Datapoint|Value
		# Output: EV, DevAdd, ChnNo, Reading='', Value
		#
		return HMCCU_Log ($hash, 2, "Invalid channel ".$t[1])
			if (!HMCCU_IsValidChannel ($hash, $t[1], $HMCCU_FL_ADDRESS));
		my ($add, $chn) = split (/:/, $t[1]);
		return ($t[0], $add, $chn, $t[2], $t[3]);
	}
	elsif ($t[0] eq 'SL') {
		#
		# RPC server enters server loop
		# Input:  SL|Pid|Servername
		# Output: SL, Servername, Pid
		#
		my $clkey = $t[2];
		return HMCCU_Log ($hash, 0, "Received SL event for unknown RPC server $clkey")
			if (!exists ($rh->{$clkey}));
		Log3 $name, 0, "HMCCU: Received SL event. RPC server $clkey enters server loop";
		$rh->{$clkey}{loop} = 1 if ($rh->{$clkey}{pid} == $t[1]);
		return ($t[0], $clkey, $t[1]);
	}
	elsif ($t[0] eq 'IN') {
		#
		# RPC server initialized
		# Input:  IN|INIT|State|Servername
		# Output: IN, Servername, Running, NotRunning, ClientsUpdated, UpdateErrors
		#
		my $clkey = $t[3];
		my $norun = 0;
		my $run = 0;
		return HMCCU_Log ($hash, 0, "Received IN event for unknown RPC server $clkey")
			if (!exists ($rh->{$clkey}));
		Log3 $name, 0, "HMCCU: Received IN event. RPC server $clkey initialized.";
		$rh->{$clkey}{state} = $rh->{$clkey}{pid} != 0 ? "running" : "initialized";
		
		# Check if all RPC servers were initialized. Set overall status
		foreach my $ser (keys %{$rh}) {
			$norun++ if ($rh->{$ser}{state} ne "running" && $rh->{$ser}{pid} != 0);
			$norun++ if ($rh->{$ser}{state} ne "initialized" && $rh->{$ser}{pid} == 0);
			$run++ if ($rh->{$ser}{state} eq "running");
		}
		HMCCU_SetRPCState ($hash, 'running') if ($norun == 0);
		$hash->{hmccu}{rpcinit} = $run;
		return ($t[0], $clkey, $run, $norun);
	}
	elsif ($t[0] eq 'EX') {
		#
		# RPC server shutdown
		# Input:  EX|SHUTDOWN|Pid|Servername
		# Output: EX, Servername, Pid, Flag, Run
		#
		my $clkey = $t[3];
		my $run = 0;
		return HMCCU_Log ($hash, 0, "Received EX event for unknown RPC server $clkey")
			if (!exists ($rh->{$clkey}));
		
		Log3 $name, 0, "HMCCU: Received EX event. RPC server $clkey terminated.";
		my $f = $hash->{RPCState} eq "restarting" ? 2 : 1;
		delete $rh->{$clkey};
	
		# Check if all RPC servers were terminated. Set overall status
		foreach my $ser (keys %{$rh}) {
			$run++ if ($rh->{$ser}{state} ne "inactive");
		}
		if ($run == 0) {
			HMCCU_SetRPCState ($hash, 'inactive') if ($f == 1);
			$hash->{RPCPID} = '0';
		}
		$hash->{hmccu}{rpccount} = $run;
		$hash->{hmccu}{rpcinit} = $run;
		return ($t[0], $clkey, $t[2], $f, $run);
	}
	elsif ($t[0] eq 'ND') {
		#
		# CCU device added
		# Input:  ND|C/D|Address|Type|Version|Firmware|RxMode
		# Output: ND, DevAdd, C/D, Type, Version, Firmware, RxMode
		#
		return ($t[0], $t[2], $t[1], $t[3], $t[4], $t[5], $t[6]);
	}
	elsif ($t[0] eq 'DD' || $t[0] eq 'RA') {
		#
		# CCU device added, deleted or readded
		# Input:  {DD,RA}|Address
		# Output: {DD,RA}, DevAdd
		#
		return ($t[0], $t[1]);
	}
	elsif ($t[0] eq 'UD') {
		#
		# CCU device updated
		# Input:  UD|Address|Hint
		# Output: UD, DevAdd, Hint
		#
		return ($t[0], $t[1], $t[2]);
	}
	elsif ($t[0] eq 'RD') {
		#
		# CCU device replaced
		# Input:  RD|Address1|Address2
		# Output: RD, Address1, Address2
		#
		return ($t[0], $t[1], $t[2]);
	}
	elsif ($t[0] eq 'ST') {
		#
		# Statistic data. Store snapshots of sent and received events.
		# Input:  ST|nTotal|nEV|nND|nDD|nRD|nRA|nUD|nIN|nSL|nEX
		# Output: ST, ...
		#
		my @stkeys = ('total', 'EV', 'ND', 'DD', 'RD', 'RA', 'UD', 'IN', 'SL', 'EX');
		for (my $i=0; $i<10; $i++) {
			$hash->{hmccu}{evs}{$stkeys[$i]} = $t[$i+1];
			$hash->{hmccu}{evr}{$stkeys[$i]} = $hash->{hmccu}{ev}{$stkeys[$i]};
		}
		return @t;
	}
	else {
		my $errtok = $t[0];
		$errtok =~ s/([\x00-\xFF])/sprintf("0x%X ",ord($1))/eg;
		Log3 $name, 2, "HMCCU: Received unknown event from CCU: ".$errtok;
	}
	
	return undef;
}

######################################################################
# Timer function for reading RPC queue
######################################################################

sub HMCCU_ReadRPCQueue ($)
{
	my ($hash) = @_;
	my $name = $hash->{NAME};
	my $eventno = 0;
	my $f = 0;
 	my @newdevices;
 	my @deldevices;
	my @termpids;
	my $newcount = 0;
	my $devcount = 0;
	my %events = ();
	my %devices = ();
	
	my $ccuflags = HMCCU_GetFlags ($name);
	my $rpcinterval = AttrVal ($name, 'rpcinterval', 5);
	my $rpcqueue = AttrVal ($name, 'rpcqueue', '/tmp/ccuqueue');
	my $rpcevtimeout = AttrVal ($name, 'rpcevtimeout', $HMCCU_TIMEOUT_EVENT);
	my $maxevents = $rpcinterval*10;
	$maxevents = 50 if ($maxevents > 50);
	$maxevents = 10 if ($maxevents < 10);

	my @portlist = HMCCU_GetRPCPortList ($hash);
	foreach my $port (@portlist) {
		my $clkey = 'CB'.$port;
		next if (!exists ($hash->{hmccu}{rpc}{$clkey}{queue}));
		my $queuename = $hash->{hmccu}{rpc}{$clkey}{queue};
		next if ($queuename eq '');
		if (!HMCCU_QueueOpen ($hash, $queuename)) {
			Log3 $name, 1, "HMCCU: Can't open file queue $queuename";
			next;
		}

		my $element = HMCCU_QueueDeq ($hash);
		while (defined ($element)) {
			Log3 $name, 2, "HMCCU: Event = $element" if ($ccuflags =~ /logEvents/);
			my ($et, @par) = HMCCU_ProcessEvent ($hash, $element);
			if (defined ($et)) {
				if ($et eq 'EV') {
					$events{$par[0]}{$par[1]}{$par[2]} = $par[3];
					$eventno++;
					last if ($eventno == $maxevents);
				}
				elsif ($et eq 'ND') {
#					push (@newdevices, $par[1]);
					$newcount++ if (!exists ($hash->{hmccu}{dev}{$par[0]}));
#					$hash->{hmccu}{dev}{$par[1]}{chntype} = $par[3];
					$devices{$par[0]}{flag} = 'N';
					$devices{$par[0]}{version} = $par[3];
					if ($par[1] eq 'D') {
						$devices{$par[0]}{addtype} = 'dev';
						$devices{$par[0]}{type} = $par[2];
						$devices{$par[0]}{firmware} = $par[4];
						$devices{$par[0]}{rxmode} = $par[5];
					}
					else {
						$devices{$par[0]}{addtype} = 'chn';
						$devices{$par[0]}{usetype} = $par[2];
					}
					$devcount++;
				}
				elsif ($et eq 'DD') {
#					push (@deldevices, $par[0]);
					$devices{$par[0]}{flag} = 'D';
					$devcount++;
#					$delcount++;
				}
				elsif ($et eq 'RD') {
					$devices{$par[0]}{flag} = 'R';
					$devices{$par[0]}{newaddr} = $par[1];			
					$devcount++;
				}
				elsif ($et eq 'SL') {
					InternalTimer (gettimeofday()+$HMCCU_INIT_INTERVAL1,
					   'HMCCU_RPCRegisterCallback', $hash, 0);
					$f = -1;
					last;
				}
				elsif ($et eq 'EX') {
					push (@termpids, $par[1]);
					$f = $par[2];
					last;
				}
			}

			last if ($f == -1);
			
			# Read next element from queue
			$element = HMCCU_QueueDeq ($hash);
		}

		HMCCU_QueueClose ($hash);
	}

	# Update readings
	HMCCU_UpdateMultipleDevices ($hash, \%events) if ($eventno > 0);

	# Update device table and client device parameter
	HMCCU_UpdateDeviceTable ($hash, \%devices) if ($devcount > 0);
	
	return if ($f == -1);
	
	# Check if events from CCU timed out
	if ($hash->{hmccu}{evtime} > 0 && time()-$hash->{hmccu}{evtime} > $rpcevtimeout &&
	   $hash->{hmccu}{evtimeout} == 0) {
	   $hash->{hmccu}{evtimeout} = 1;
		$hash->{ccustate} = HMCCU_TCPConnect ($hash->{host}, $HMCCU_REGA_PORT{$hash->{prot}}) ne '' ? 'timeout' : 'unreachable';
		Log3 $name, 2, "HMCCU: Received no events from CCU since $rpcevtimeout seconds";
		DoTrigger ($name, "No events from CCU since $rpcevtimeout seconds");
	}
	else {
		$hash->{ccustate} = 'active' if ($hash->{ccustate} ne 'active');
	}

	my @hm_pids;
	my @hm_tids;
	HMCCU_IsRPCServerRunning ($hash, \@hm_pids, \@hm_tids);
	my $nhm_pids = scalar (@hm_pids);
	my $nhm_tids = scalar (@hm_tids);
	Log3 $name, 1, "HMCCU: Externally launched RPC server(s) detected. f=$f" if ($nhm_tids > 0);

	if ($f > 0) {
		# At least one RPC server has been stopped. Update PID list
		$hash->{RPCPID} = $nhm_pids > 0 ? join(',',@hm_pids) : '0';
		Log3 $name, 0, "HMCCU: RPC server(s) with PID(s) ".join(',',@termpids)." shut down. f=$f";
			
		# Output statistic counters
		foreach my $cnt (sort keys %{$hash->{hmccu}{ev}}) {
			Log3 $name, 3, "HMCCU: Eventcount $cnt = ".$hash->{hmccu}{ev}{$cnt};
		}
	}

	if ($f == 2 && $nhm_pids == 0) {
		# All RPC servers terminated and restart flag set
		if ($ccuflags !~ /(extrpc|procrpc)/) {
			return if (HMCCU_StartIntRPCServer ($hash));
		}
		Log3 $name, 0, "HMCCU: Restart of RPC server failed";
	}

	if ($nhm_pids > 0) {
		# Reschedule reading of RPC queues if at least one RPC server is running
		InternalTimer (gettimeofday()+$rpcinterval, 'HMCCU_ReadRPCQueue', $hash, 0);
	}
	else {
		# No more RPC servers active
		Log3 $name, 0, "HMCCU: Periodical check found no RPC Servers";
		# Deregister existing callbacks
		HMCCU_RPCDeRegisterCallback ($hash);
		
		# Cleanup hash variables
		my @clkeylist = keys %{$hash->{hmccu}{rpc}};
		foreach my $clkey (@clkeylist) {
			delete $hash->{hmccu}{rpc}{$clkey};
		}
		$hash->{hmccu}{rpccount} = 0;
		$hash->{hmccu}{rpcinit} = 0;

		$hash->{RPCPID} = '0';
		$hash->{RPCPRC} = 'none';

		HMCCU_SetRPCState ($hash, 'inactive');
		Log3 $name, 0, "HMCCU: All RPC servers stopped";
		DoTrigger ($name, "All RPC servers stopped");
	}
}

######################################################################
# Execute Homematic command on CCU (blocking).
# If parameter mode is 1 an empty string is a valid result.
# Return undef on error.
######################################################################

sub HMCCU_HMCommand ($$$)
{
	my ($cl_hash, $cmd, $mode) = @_;
	my $cl_name = $cl_hash->{NAME};
	my $fnc = "HMCommand";
	
	my $io_hash = HMCCU_GetHash ($cl_hash);
	my $ccureqtimeout = AttrVal ($io_hash->{NAME}, "ccuReqTimeout", $HMCCU_TIMEOUT_REQUEST);
	my $url = HMCCU_BuildURL ($io_hash, 'rega');
	my $value;

	HMCCU_Trace ($cl_hash, 2, $fnc, "URL=$url, cmd=$cmd");

	my $param = { url => $url, timeout => $ccureqtimeout, data => $cmd, method => "POST" };
	$param->{sslargs} = { SSL_verify_mode => 0 };
	my ($err, $response) = HttpUtils_BlockingGet ($param);
	
	if ($err eq '') {
		$value = $response;
		$value =~ s/<xml>(.*)<\/xml>//;
		$value =~ s/\r//g;
		HMCCU_Trace ($cl_hash, 2, $fnc, "Response=$response, Value=".(defined ($value) ? $value : "undef"));
	}
	else {
		HMCCU_Log ($io_hash, 2, "Error during HTTP request: $err");
		HMCCU_Trace ($cl_hash, 2, $fnc, "Response=$response");
		return undef;
	}

	if ($mode == 1) {
		return (defined ($value) && $value ne 'null') ? $value : undef;
	}
	else {
		return (defined ($value) && $value ne '' && $value ne 'null') ? $value : undef;		
	}
}

######################################################################
# Execute Homematic command on CCU (non blocking).
######################################################################

sub HMCCU_HMCommandNB ($$$)
{
	my ($cl_hash, $cmd, $cbfunc) = @_;
	my $cl_name = $cl_hash->{NAME};
	my $fnc = "HMCommandNB";

	my $io_hash = HMCCU_GetHash ($cl_hash);
	my $ccureqtimeout = AttrVal ($io_hash->{NAME}, "ccuReqTimeout", $HMCCU_TIMEOUT_REQUEST);
	my $url = HMCCU_BuildURL ($io_hash, 'rega');

	HMCCU_Trace ($cl_hash, 2, $fnc, "URL=$url");

	if (defined ($cbfunc)) {
		my $param = { url => $url, timeout => $ccureqtimeout, data => $cmd, method => "POST",
			callback => $cbfunc, devhash => $cl_hash };
		$param->{sslargs} = { SSL_verify_mode => 0 };
		HttpUtils_NonblockingGet ($param);
	}
	else {
		my $param = { url => $url, timeout => $ccureqtimeout, data => $cmd, method => "POST",
			callback => \&HMCCU_HMCommandCB, devhash => $cl_hash };
		$param->{sslargs} = { SSL_verify_mode => 0 };
		HttpUtils_NonblockingGet ($param);
	}
}

######################################################################
# Default callback function for non blocking CCU request.
######################################################################

sub HMCCU_HMCommandCB ($$$)
{
	my ($param, $err, $data) = @_;
	my $hash = $param->{devhash};
	my $fnc = "HMCommandCB";

	HMCCU_Log ($hash, 2, "Error during CCU request. $err") if ($err ne '');
	HMCCU_Trace ($hash, 2, $fnc, "URL=".$param->{url}."<br>Response=$data");
}

######################################################################
# Execute Homematic script on CCU.
# Parameters: device-hash, script-code or script-name, parameter-hash
# If content of hmscript starts with a ! the following text is treated
# as name of an internal HomeMatic script function defined in
# HMCCUConf.pm.
# If content of hmscript is enclosed in [] the content is treated as
# HomeMatic script code. Characters [] will be removed.
# Otherwise hmscript is the name of a file containing Homematic script
# code.
# Return script output or error message starting with "ERROR:".
######################################################################
 
sub HMCCU_HMScriptExt ($$$$$)
{
	my ($hash, $hmscript, $params, $cbFunc, $cbParam) = @_;
	my $name = $hash->{NAME};
	my $code = $hmscript;
	my $scrname = '';
	
	return HMCCU_LogError ($hash, 2, "CCU host name not defined") if (!exists ($hash->{host}));
	my $host = $hash->{host};

	my $ccureqtimeout = AttrVal ($hash->{NAME}, "ccuReqTimeout", $HMCCU_TIMEOUT_REQUEST);

	if ($hmscript =~ /^!(.*)$/) {
		# Internal script
		$scrname = $1;
		return "ERROR: Can't find internal script $scrname" if (!exists ($HMCCU_SCRIPTS->{$scrname}));
		$code = $HMCCU_SCRIPTS->{$scrname}{code};
	}
	elsif ($hmscript =~ /^\[(.*)\]$/) {
		# Script code
		$code = $1;
	}
	else {
		# Script file
		if (open (SCRFILE, "<$hmscript")) {
			my @lines = <SCRFILE>;
			$code = join ("\n", @lines);
			close (SCRFILE);
		}
		else {
			return "ERROR: Can't open script file";
		}
	}
 
	# Check and replace variables
	if (defined ($params)) {
		my @parnames = keys %{$params};
		if ($scrname ne '') {
			if (scalar (@parnames) != $HMCCU_SCRIPTS->{$scrname}{parameters}) {
				return "ERROR: Wrong number of parameters. Usage: $scrname ".
					$HMCCU_SCRIPTS->{$scrname}{syntax};
			}
			foreach my $p (split (/[, ]+/, $HMCCU_SCRIPTS->{$scrname}{syntax})) {
				return "ERROR: Missing definition of parameter $p" if (!exists ($params->{$p}));
			}
		}
		foreach my $svar (keys %{$params}) {
			next if ($code !~ /\$$svar/);
			$code =~ s/\$$svar/$params->{$svar}/g;
		}
	}
	else {
		if ($scrname ne '' && $HMCCU_SCRIPTS->{$scrname}{parameters} > 0) {
			return "ERROR: Wrong number of parameters. Usage: $scrname ".
				$HMCCU_SCRIPTS->{$scrname}{syntax};
		}
	}
	
	HMCCU_Trace ($hash, 2, "HMScriptEx", $code);
	
	# Execute script on CCU
	my $url = HMCCU_BuildURL ($hash, 'rega');
	if (defined ($cbFunc)) {
		my $param = { url => $url, timeout => $ccureqtimeout, data => $code, method => "POST",
			callback => $cbFunc, ioHash => $hash };
		if (defined ($cbParam)) {
			foreach my $p (keys %{$cbParam}) {
				$param->{$p} = $cbParam->{$p};
			}
		}
		$param->{sslargs} = { SSL_verify_mode => 0 };
		HttpUtils_NonblockingGet ($param);
		return ''
	}
	else {
		my $param = { url => $url, timeout => $ccureqtimeout, data => $code, method => "POST" };
		$param->{sslargs} = { SSL_verify_mode => 0 };
		my ($err, $response) = HttpUtils_BlockingGet ($param);
	
		if ($err eq '') {
			my $output = $response;
			$output =~ s/<xml>.*<\/xml>//;
			$output =~ s/\r//g;
			return $output;
		}
		else {
			HMCCU_Log ($hash, 2, "HMScript failed. $err");
			return "ERROR: HMScript failed. $err";
		}
	}
}

######################################################################
# Bulk update of reading considering attribute substexcl.
######################################################################

sub HMCCU_BulkUpdate ($$$$)
{
	my ($hash, $reading, $orgval, $subval) = @_;
	my $name = $hash->{NAME};
	
	my $excl = AttrVal ($name, 'substexcl', '');
#
# For later use: Suppress reading update 
#
# 	my $suppress = AttrVal ($name, 'ccusuppress', '');
# 
# 	if ($suppress ne '') {
# 		my $ct = time();
# 		my @srules = split (";", $suppress);
# 	
# 		foreach my $sr (@srules) {
# 			my ($rnexp, $to) = split (":", $sr);
# 			next if (!defined ($to));
# 			if ($reading =~ /$rnexp/) {
# 				my $rt = ReadingsTimestamp ($name, $reading, '');
# 				return if ($rt ne '' && $ct-time_str2num($rt) < $to);
# 			}
# 		}
# 	}

	readingsBulkUpdate ($hash, $reading, ($excl ne '' && $reading =~ /$excl/ ? $orgval : $subval));
}

######################################################################
# Get datapoint value from CCU and optionally update reading.
# If parameter noupd is defined and > 0 no readings will be updated.
######################################################################

sub HMCCU_GetDatapoint ($@)
{
	my ($cl_hash, $param, $noupd) = @_;
	my $cl_name = $cl_hash->{NAME};
	my $fnc = "GetDatapoint";
	my $value = '';

	my $io_hash = HMCCU_GetHash ($cl_hash);
	return (-3, $value) if (!defined ($io_hash));
	return (-4, $value) if ($cl_hash->{TYPE} ne 'HMCCU' && $cl_hash->{ccudevstate} eq 'deleted');

	my $readingformat = HMCCU_GetAttrReadingFormat ($cl_hash, $io_hash);
	my $substitute = HMCCU_GetAttrSubstitute ($cl_hash, $io_hash);
	my ($statechn, $statedpt, $controlchn, $controldpt) = HMCCU_GetSpecialDatapoints (
	   $cl_hash, '', 'STATE', '', '');
	my $ccuget = HMCCU_GetAttribute ($io_hash, $cl_hash, 'ccuget', 'Value');
	my $ccureqtimeout = AttrVal ($io_hash->{NAME}, "ccuReqTimeout", $HMCCU_TIMEOUT_REQUEST);

	my $cmd = '';
	my ($int, $add, $chn, $dpt, $nam, $flags) = HMCCU_ParseObject ($io_hash, $param,
		$HMCCU_FLAG_INTERFACE);
	return (-1, $value) if ($flags != $HMCCU_FLAGS_IACD && $flags != $HMCCU_FLAGS_NCD);

	if ($flags == $HMCCU_FLAGS_IACD) {
		$cmd = 'Write((datapoints.Get("'.$int.'.'.$add.':'.$chn.'.'.$dpt.'")).'.$ccuget.'())';
	}
	elsif ($flags == $HMCCU_FLAGS_NCD) {
		$cmd = 'Write((dom.GetObject(ID_CHANNELS)).Get("'.$nam.'").DPByHssDP("'.$dpt.'").'.$ccuget.'())';
		($add, $chn) = HMCCU_GetAddress ($io_hash, $nam, '', '');
	}

	HMCCU_Trace ($cl_hash, 2, $fnc, "CMD=$cmd, param=$param, ccuget=$ccuget");

	$value = HMCCU_HMCommand ($cl_hash, $cmd, 1);

	if (defined ($value) && $value ne '' && $value ne 'null') {
		if (!defined ($noupd) || $noupd == 0) {
			$value = HMCCU_UpdateSingleDatapoint ($cl_hash, $chn, $dpt, $value);
		}
		else {
			my $svalue = HMCCU_ScaleValue ($cl_hash, $chn, $dpt, $value, 0);	
			$value = HMCCU_Substitute ($svalue, $substitute, 0, $chn, $dpt);
		}
		HMCCU_Trace ($cl_hash, 2, $fnc, "Value of $chn.$dpt = $value"); 
		return (1, $value);
	}
	else {
		HMCCU_Log ($cl_hash, 1, "Error CMD = $cmd");
		return (-2, '');
	}
}

######################################################################
# Set multiple values of parameter set.
# Parameter params is a hash reference. Keys are datapoint names.
# Parameter address must be a channel address.
######################################################################

sub HMCCU_SetMultipleParameters ($$$)
{
	my ($clHash, $address, $params) = @_;
	
	my ($add, $chn) = HMCCU_SplitChnAddr ($address);
	return -1 if (!defined ($chn));
	
	foreach my $p (sort keys %$params) {
		return -8 if (!HMCCU_IsValidDatapoint ($clHash, $clHash->{ccutype}, $chn, $p, 2));
		$params->{$p} = HMCCU_ScaleValue ($clHash, $chn, $p, $params->{$p}, 1);
	}
	
	return HMCCU_RPCRequest ($clHash, "putParamset", $address, 'VALUES', $params);
}

######################################################################
# Set multiple datapoints on CCU in a single request.
# Parameter params is a hash reference. Keys are full qualified CCU
# datapoint specifications in format:
#   no.interface.{address|fhemdev}:channelno.datapoint
# Parameter no defines the command order.
######################################################################

sub HMCCU_SetMultipleDatapoints ($$) {
	my ($clHash, $params) = @_;
	my $fnc = "SetMultipleDatapoints";
	my $mdFlag = $clHash->{TYPE} eq 'HMCCU' ? 1 : 0;
	my $ioHash;

	if ($mdFlag) {
		$ioHash = $clHash;
	}
	else {
		$ioHash = HMCCU_GetHash ($clHash);
		return -3 if (!defined ($ioHash));
	}
	
	my $ioName = $ioHash->{NAME};
	my $clName = $clHash->{NAME};
	my $ccuFlags = HMCCU_GetFlags ($ioName);
	
	# Build Homematic script
	my $cmd = '';
	foreach my $p (sort keys %$params) {
		my $v = $params->{$p};

		# Check address. dev is either a device address or a FHEM device name
		my ($no, $int, $addchn, $dpt) = split (/\./, $p);
		return -1 if (!defined ($dpt));
		my ($dev, $chn) = split (':', $addchn);
		return -1 if (!defined ($chn));
		my $add = $dev;
		
		# Get hash of FHEM device
		if ($mdFlag) {
			return -1 if (!exists ($defs{$dev}));
			$clHash = $defs{$dev};
			($add, undef) = HMCCU_SplitChnAddr ($clHash->{ccuaddr});
		}

		# Device has been deleted or is disabled
		return -4 if (exists ($clHash->{ccudevstate}) && $clHash->{ccudevstate} eq 'deleted');
		return -21 if (IsDisabled ($clHash->{NAME}));
	
		HMCCU_Trace ($clHash, 2, $fnc, "dpt=$p, value=$v");

		# Check client device type and datapoint
		my $clType = $clHash->{TYPE};
		my $ccuType = $clHash->{ccutype};
		return -1 if ($clType ne 'HMCCUCHN' && $clType ne 'HMCCUDEV');
		return -8 if (!HMCCU_IsValidDatapoint ($clHash, $ccuType, $chn, $dpt, 2));
		
		my $ccuVerify = AttrVal ($clName, 'ccuverify', 0);
		my $ccuChange = AttrVal ($clName, 'ccuSetOnChange', 'null');

		# Build device address list considering group devices
		my @addrList = $clHash->{ccuif} eq 'fhem' ? split (',', $clHash->{ccugroup}) : ($add);
		return -1 if (scalar (@addrList) < 1);
		
		foreach my $a (@addrList) {
			# Override address and interface of group device with address of group members
			if ($clHash->{ccuif} eq 'fhem') {
				($add, undef) = HMCCU_SplitChnAddr ($a);
				$int = HMCCU_GetDeviceInterface ($ioHash, $a, '');
				return -20 if ($int eq '');
			}

			if ($ccuType eq 'HM-Dis-EP-WM55' && $dpt eq 'SUBMIT') {
				$v = HMCCU_EncodeEPDisplay ($v);
			}
			else {
				$v = HMCCU_ScaleValue ($clHash, $chn, $dpt, $v, 1);
			}

			my $dptType = HMCCU_GetDatapointAttr ($ioHash, $ccuType, $chn, $dpt, 'type');
			$v = "'".$v."'" if (defined ($dptType) && $dptType == $HMCCU_TYPE_STRING);
			my $c = '(datapoints.Get("'.$int.'.'.$add.':'.$chn.'.'.$dpt.'")).State('.$v.");\n";

			if ($dpt =~ /$ccuChange/) {
				$cmd .= 'if((datapoints.Get("'.$int.'.'.$add.':'.$chn.'.'.$dpt.'")).Value() != '.$v.") {\n$c}\n";
			}
			else {
				$cmd .= $c;
			}
		}
	}
	
	if ($ccuFlags =~ /nonBlocking/) {
		# Execute command (non blocking)
		HMCCU_HMCommandNB ($clHash, $cmd, undef);
		return 0;
	}
	else {
		# Execute command (blocking)
		my $response = HMCCU_HMCommand ($clHash, $cmd, 1);
		return defined ($response) ? 0 : -2;
		# Datapoint verification ???
	}
}

######################################################################
# Set datapoint on CCU.
# Parameter param is a valid CCU or FHEM datapoint specification:
#   [ccu:]address:channelnumber.datapoint
#   [ccu:]channelname.datapoint
#   hmccu:hmccudev_name.channelnumber.datapoint
#   hmccu:hmccuchn_name.datapoint
######################################################################

# sub HMCCU_SetDatapoint ($$$)
# {
# 	my ($hash, $param, $value) = @_;
# 	my $fnc = "SetDatapoint";
# 	my $type = $hash->{TYPE};
# 
# 	my $hmccu_hash = HMCCU_GetHash ($hash);
# 	return -3 if (!defined ($hmccu_hash));
# 	return -4 if (exists ($hash->{ccudevstate}) && $hash->{ccudevstate} eq 'deleted');
# 	my $name = $hmccu_hash->{NAME};
# 	my $cdname = $hash->{NAME};
# 	
# 	my $ccureqtimeout = AttrVal ($name, "ccuReqTimeout", $HMCCU_TIMEOUT_REQUEST);
# 	my $ccuflags = HMCCU_GetFlags ($name);
# 	my $readingformat = HMCCU_GetAttrReadingFormat ($hash, $hmccu_hash);
# 	my $ccuverify = AttrVal ($cdname, 'ccuverify', 0); 
# 
# 	HMCCU_Trace ($hash, 2, $fnc, "param=$param, value=$value");
# 	
# 	if ($param =~ /^hmccu:.+$/) {
# 		my @t = split (/\./, $param);
# 		return -1 if (scalar (@t) < 2 || scalar (@t) > 3);
# 		my $fhdpt = pop @t;
# 		my ($fhadd, $fhchn) = HMCCU_GetAddress ($hmccu_hash, $t[0], '', '');
# 		$fhchn = $t[1] if (scalar (@t) == 2);
# 		return -1 if ($fhadd eq '' || $fhchn eq '');
# 		$param = "$fhadd:$fhchn.$fhdpt";
# 	}
# 	elsif ($param =~ /^ccu:(.+)$/) {
# 		$param = $1;
# 	}
# 
# 	my $cmd = '';
# 	my ($int, $add, $chn, $dpt, $nam, $flags) = HMCCU_ParseObject ($hmccu_hash, $param,
# 		$HMCCU_FLAG_INTERFACE);
# 	return -1 if ($flags != $HMCCU_FLAGS_IACD && $flags != $HMCCU_FLAGS_NCD);
# 	
# 	if ($hash->{ccutype} eq 'HM-Dis-EP-WM55' && $dpt eq 'SUBMIT') {
# 		$value = HMCCU_EncodeEPDisplay ($value);
# 	}
# 	else {
# 		$value = HMCCU_ScaleValue ($hash, $chn, $dpt, $value, 1);
# 	}
# 	
# 	my $dpttype = HMCCU_GetDatapointAttr ($hmccu_hash, $hash->{ccutype}, $chn, $dpt, 'type');
# 	if (defined ($dpttype) && $dpttype == $HMCCU_TYPE_STRING) {
# 		$value = "'".$value."'";
# 	}
# 	
# 	if ($flags == $HMCCU_FLAGS_IACD) {
# #		$cmd = '(datapoints.Get("'.$int.'.'.$add.':'.$chn.'.'.$dpt.'")).State('.$value.')';
# 		$nam = HMCCU_GetChannelName ($hmccu_hash, $add.":".$chn, '');
# 	}
# 	elsif ($flags == $HMCCU_FLAGS_NCD) {
# #		$cmd = '(dom.GetObject(ID_CHANNELS)).Get("'.$nam.'").DPByHssDP("'.$dpt.'").State('.$value.')';
# 		($add, $chn) = HMCCU_GetAddress ($hmccu_hash, $nam, '', '');
# 	}
# 
# 	if ($type eq 'HMCCUDEV' && $hash->{ccuif} eq 'fhem' && $hash->{ccutype} ne 'n/a' && exists ($hash->{ccugroup})) {
# 		foreach my $gaddr (split (',', $hash->{ccugroup})) {
# 			$cmd .= '(datapoints.Get("'.$int.'.'.$gaddr.':'.$chn.'.'.$dpt.'")).State('.$value.");\n";
# 		}
# 	}
# 	else {
# 		$cmd = '(datapoints.Get("'.$int.'.'.$add.':'.$chn.'.'.$dpt.'")).State('.$value.')';
# 	}
# 	
# 	my $addr = $add.":".$chn;
# 
# 	if ($ccuflags =~ /nonBlocking/) {
# 		HMCCU_HMCommandNB ($hash, $cmd, undef);
# 		return 0;
# 	}
# 
# 	# Execute command (blocking)
# 	my $response = HMCCU_HMCommand ($hash, $cmd, 1);
# 	HMCCU_Trace ($hash, 2, $fnc,
# 		"Addr=$addr Name=$nam<br>".
# 		"Script response = \n".(defined ($response) ? $response: 'undef')."<br>".
# 		"Script = \n".$cmd);
# 	return -2 if (!defined ($response));
# 
# 	# Verify setting of datapoint value or update reading with new datapoint value
# 	if (HMCCU_IsValidDatapoint ($hash, $hash->{ccutype}, $addr, $dpt, 1)) {
# 		if ($ccuverify == 1) {
# 			my ($rc, $result) = HMCCU_GetDatapoint ($hash, $param, 0);
# 			return $rc;
# 		}
# 		elsif ($ccuverify == 2) {
# 			HMCCU_UpdateSingleDatapoint ($hash, $chn, $dpt, $value);
# 		}
# 	}
# 	
# 	return 0;
# }

######################################################################
# Scale, spread and/or shift datapoint value.
# Mode: 0 = Get/Divide, 1 = Set/Multiply
# Supports reversing of value if value range is specified. Syntax for
# Rule is:
#   [ChannelNo.]Datapoint:Factor
#   [!][ChannelNo.]Datapoint:Min:Max:Range1:Range2
# If Datapoint name starts with a ! the value is reversed. In case of
# an error original value is returned.
######################################################################

sub HMCCU_ScaleValue ($$$$$)
{
	my ($hash, $chnno, $dpt, $value, $mode) = @_;
	my $name = $hash->{NAME};
	
	my $ccuscaleval = AttrVal ($name, 'ccuscaleval', '');	
	return $value if ($ccuscaleval eq '');

	my @sl = split (',', $ccuscaleval);
	foreach my $sr (@sl) {
		my $f = 1.0;
		my @a = split (':', $sr);
		my $n = scalar (@a);
		next if ($n != 2 && $n != 5);

		my $rev = 0;
		my $dn = $a[0];
		my $cn = $chnno;
		if ($dn =~ /^\!(.+)$/) {
			# Invert
			$dn = $1;
			$rev = 1;
		}
		if ($dn =~ /^([0-9]{1,2})\.(.+)$/) {
			# Compare channel number
			$cn = $1;
			$dn = $2;
		}
		next if ($dpt ne $dn || ($chnno ne '' && $cn ne $chnno));
			
		if ($n == 2) {
			$f = ($a[1] == 0.0) ? 1.0 : $a[1];
			return ($mode == 0) ? $value/$f : $value*$f;
		}
		else {
			# Do not scale if value out of range or interval wrong
			return $value if ($a[1] > $a[2] || $a[3] > $a[4]);
			return $value if ($mode == 0 && ($value < $a[1] || $value > $a[2]));
			return $value if ($mode == 1 && ($value < $a[3] || $value > $a[4]));
				
			# Reverse value 
			if ($rev) {
				my $dr = ($mode == 0) ? $a[1]+$a[2] : $a[3]+$a[4];
				$value = $dr-$value;
			}
				
			my $d1 = $a[2]-$a[1];
			my $d2 = $a[4]-$a[3];
			return $value if ($d1 == 0.0 || $d2 == 0.0);
			$f = $d1/$d2;
			return ($mode == 0) ? $value/$f+$a[3] : ($value-$a[3])*$f;
		}
	}
	
	return $value;
}

######################################################################
# Get CCU system variables and update readings.
# System variable readings are stored in I/O device. Unsupported
# characters in variable names are substituted.
######################################################################

sub HMCCU_GetVariables ($$)
{
	my ($hash, $pattern) = @_;
	my $name = $hash->{NAME};
	my $count = 0;
	my $result = '';

	my $ccureadings = AttrVal ($name, 'ccureadings', HMCCU_IsFlag ($name, "noReadings") ? 0 : 1);

	my $response = HMCCU_HMScriptExt ($hash, "!GetVariables", undef, undef, undef);
	return (-2, $response) if ($response eq '' || $response =~ /^ERROR:.*/);
  
	readingsBeginUpdate ($hash) if ($ccureadings);

	foreach my $vardef (split /[\n\r]+/, $response) {
		my @vardata = split /=/, $vardef;
		next if (@vardata != 3);
		next if ($vardata[0] !~ /$pattern/);
		my $rn = HMCCU_CorrectName ($vardata[0]);
		my $value = HMCCU_FormatReadingValue ($hash, $vardata[2], $vardata[0]);
		readingsBulkUpdate ($hash, $rn, $value) if ($ccureadings); 
		$result .= $vardata[0].'='.$vardata[2]."\n";
		$count++;
	}

	readingsEndUpdate ($hash, 1) if ($ccureadings);

	return ($count, $result);
}

######################################################################
# Timer function for periodic update of CCU system variables.
######################################################################

sub HMCCU_UpdateVariables ($)
{
	my ($hash) = @_;
	
	if (exists ($hash->{hmccu}{ccuvarspat})) {
		HMCCU_GetVariables ($hash, $hash->{hmccu}{ccuvarspat});
		InternalTimer (gettimeofday ()+$hash->{hmccu}{ccuvarsint}, "HMCCU_UpdateVariables", $hash);
	}
}

######################################################################
# Set CCU system variable. If parameter vartype is undefined system
# variable must exist in CCU. Following variable types are supported:
# bool, list, number, text. Parameter params is a hash reference of
# script parameters.
# Return 0 on success, error code on error.
######################################################################

sub HMCCU_SetVariable ($$$$$)
{
	my ($hash, $varname, $value, $vartype, $params) = @_;
	my $name = $hash->{NAME};
	
	my $ccureqtimeout = AttrVal ($name, "ccuReqTimeout", $HMCCU_TIMEOUT_REQUEST);
	
	my %varfnc = (
		"bool" => "!CreateBoolVariable", "list", "!CreateListVariable",
		"number" => "!CreateNumericVariable", "text", "!CreateStringVariable"
	);

	if (!defined ($vartype)) {
		my $cmd = qq(dom.GetObject("$varname").State("$value"));
		my $response = HMCCU_HMCommand ($hash, $cmd, 1);
		return HMCCU_Log ($hash, 1, "CMD=$cmd", -2) if (!defined ($response));
	}
	else {
		return -18 if (!exists ($varfnc{$vartype}));

		# Set default values for variable attributes
		$params->{name} = $varname if (!exists ($params->{name}));
		$params->{init} = $value if (!exists ($params->{init}));
		$params->{unit} = "" if (!exists ($params->{unit}));
		$params->{desc} = "" if (!exists ($params->{desc}));
		$params->{min} = "0" if ($vartype eq 'number' && !exists ($params->{min}));
		$params->{max} = "65000" if ($vartype eq 'number' && !exists ($params->{max}));
		$params->{list} = $value if ($vartype eq 'list' && !exists ($params->{list}));
		$params->{valtrue} = "ist wahr" if ($vartype eq 'bool' && !exists ($params->{valtrue}));
		$params->{valfalse} = "ist falsch" if ($vartype eq 'bool' && !exists ($params->{valfalse}));
		
		my $rc = HMCCU_HMScriptExt ($hash, $varfnc{$vartype}, $params, undef, undef);
		return HMCCU_Log ($hash, 1, $rc, -2) if ($rc =~ /^ERROR:.*/);
	}

	return 0;
}

######################################################################
# Update all datapoints / readings of device or channel considering
# attribute ccureadingfilter.
# Parameter $ccuget can be 'State', 'Value' or 'Attr'.
# Return 1 on success, <= 0 on error
######################################################################

sub HMCCU_GetUpdate ($$$)
{
	my ($cl_hash, $addr, $ccuget) = @_;
	my $name = $cl_hash->{NAME};
	my $type = $cl_hash->{TYPE};
	my $fnc = "GetUpdate";

	my $disable = AttrVal ($name, 'disable', 0);
	return 1 if ($disable == 1);

	my $hmccu_hash = HMCCU_GetHash ($cl_hash);
	return -3 if (!defined ($hmccu_hash));
	return -4 if ($type ne 'HMCCU' && $cl_hash->{ccudevstate} eq 'deleted');

	my $nam = '';
	my $list = '';
	my $script = '';

	$ccuget = HMCCU_GetAttribute ($hmccu_hash, $cl_hash, 'ccuget', 'Value') if ($ccuget eq 'Attr');

	if (HMCCU_IsValidChannel ($hmccu_hash, $addr, $HMCCU_FL_ADDRESS)) {
		$nam = HMCCU_GetChannelName ($hmccu_hash, $addr, '');
		return -1 if ($nam eq '');
		my ($stadd, $stchn) = split (':', $addr);
		my $stnam = HMCCU_GetChannelName ($hmccu_hash, "$stadd:0", '');
		$list = $stnam eq '' ? $nam : $stnam . "," . $nam;
		$script = "!GetDatapointsByChannel";
	}
	elsif (HMCCU_IsValidDevice ($hmccu_hash, $addr, $HMCCU_FL_ADDRESS)) {
		$nam = HMCCU_GetDeviceName ($hmccu_hash, $addr, '');
		return -1 if ($nam eq '');
		$list = $nam if ($cl_hash->{ccuif} ne 'fhem');
		$script = "!GetDatapointsByDevice";

		# Consider members of group device
		if ($type eq 'HMCCUDEV' &&
			($cl_hash->{ccuif} eq 'VirtualDevices' || $cl_hash->{ccuif} eq 'fhem') &&
			exists ($cl_hash->{ccugroup})) {
			foreach my $gd (split (",", $cl_hash->{ccugroup})) {
				$nam = HMCCU_GetDeviceName ($hmccu_hash, $gd, '');
				$list .= ','.$nam if ($nam ne '');
			}
		}
	}
	else {
		return -1;
	}

	if (HMCCU_IsFlag ($hmccu_hash->{NAME}, 'nonBlocking')) {
		HMCCU_HMScriptExt ($hmccu_hash, $script, { list => $list, ccuget => $ccuget },
			\&HMCCU_UpdateCB, undef);
		return 1;
	}
	else {
		my $response = HMCCU_HMScriptExt ($hmccu_hash, $script,
			{ list => $list, ccuget => $ccuget }, undef, undef);
		HMCCU_Trace ($cl_hash, 2, $fnc, "Addr=$addr Name=$nam Script=$script<br>".
			"Script response = \n".$response);
		return -2 if ($response eq '' || $response =~ /^ERROR:.*/);

		HMCCU_UpdateCB ({ ioHash => $hmccu_hash }, undef, $response);
		return 1;
	}
	
# 	my @dpdef = split /\n/, $response;
# 	my $count = pop (@dpdef);
# 	return -10 if (!defined ($count) || $count == 0);
# 
# 	my %events = ();
# 	foreach my $dp (@dpdef) {
# 		my ($chnname, $dpspec, $value) = split /=/, $dp;
# 		next if (!defined ($value));
# 		my ($iface, $chnadd, $dpt) = split /\./, $dpspec;
# 		next if (!defined ($dpt));
# 		my ($add, $chn) = ('', '');
# 		if ($iface eq 'sysvar' && $chnadd eq 'link') {
# 			($add, $chn) = HMCCU_GetAddress ($hmccu_hash, $chnname, '', '');
# 		}
# 		else {
# 			($add, $chn) = HMCCU_SplitChnAddr ($chnadd);
# 		}
# 		next if ($chn eq '');
# 		$events{$add}{$chn}{$dpt} = $value;
# 	}

# 	if ($cl_hash->{ccuif} eq 'fhem') {
# 		# Calculate datapoints of virtual group device
# 		if ($cl_hash->{ccutype} ne 'n/a') {
# 			foreach my $da (split (",", $cl_hash->{ccugroup})) {
# 				foreach my $cn (keys %{$events{$da}}) {
# 					foreach my $dp (keys %{$events{$da}{$cn}}) {
# 						if (defined ($events{$da}{$cn}{$dp})) {
# 							$events{$cl_hash->{ccuaddr}}{$cn}{$dp} = $events{$da}{$cn}{$dp}
# 						}
# 					}
# 				}
# 			}
# 		}
# 	}
	
#	HMCCU_UpdateMultipleDevices ($hmccu_hash, \%events);

	return 1;
}

######################################################################
# Generic reading update callback function for non blocking HTTP
# requests.
# Format of $data: Newline separated list of datapoint values.
#    ChannelName=Interface.ChannelAddress.Datapoint=Value
# Optionally last line can contain the number of datapoint lines.
######################################################################

sub HMCCU_UpdateCB ($$$)
{
	my ($param, $err, $data) = @_;
	
	if (!exists ($param->{ioHash})) {
		Log3 1, undef, "HMCCU: Missing parameter ioHash in update callback";
		return;
	}

	my $hash = $param->{ioHash};
	my $logcount = 0;
	$logcount = 1 if (exists ($param->{logCount}) && $param->{logCount} == 1);
	
	my $count = 0;
	my @dpdef = split /[\n\r]+/, $data;
	my $lines = scalar (@dpdef);
	$count = ($lines > 0 && $dpdef[$lines-1] =~ /^[0-9]+$/) ? pop (@dpdef) : $lines;
	return if ($count == 0);

	my %events = ();
	foreach my $dp (@dpdef) {
		my ($chnname, $dpspec, $value) = split /=/, $dp;
		next if (!defined ($value));
		my ($iface, $chnadd, $dpt) = split /\./, $dpspec;
		next if (!defined ($dpt));
		my ($add, $chn) = ('', '');
		if ($iface eq 'sysvar' && $chnadd eq 'link') {
			($add, $chn) = HMCCU_GetAddress ($hash, $chnname, '', '');
		}
		else {
			($add, $chn) = HMCCU_SplitChnAddr ($chnadd);
		}
		next if ($chn eq '');
		$events{$add}{$chn}{$dpt} = $value;
	}
	
	my $c_ok = HMCCU_UpdateMultipleDevices ($hash, \%events);
	my $c_err = 0;
	$c_err = max($param->{devCount}-$c_ok, 0) if (exists ($param->{devCount}));
	HMCCU_Log ($hash, 2, "Update success=$c_ok failed=$c_err") if ($logcount);
}

######################################################################
# Execute RPC request
# Parameters:
#  $method - RPC request method. Use listParamset as an alias for
#     getParamset if readings should not be updated.
#  $address  - Device address.
#  $paramset - paramset name: VALUE, MASTER, LINK, ...
#  $parref   - Hash reference with parameter/value pairs (optional).
#  $filter   - Regular expression for filtering response (default = .*).
# Return (retCode, result).
#  retCode = 0 - Success
#  retCode < 0 - Error, result contains error message
######################################################################

sub HMCCU_RPCRequest ($$$$$;$)
{
	my ($clHash, $method, $address, $paramset, $parref, $filter) = @_;
	my $name = $clHash->{NAME};
	my $type = $clHash->{TYPE};
	my $fnc = "RPCRequest";

	my $reqMethod = $method eq 'listParamset' ? 'getParamset' : $method;
	$filter = '.*' if (!defined ($filter));
	my $addr = '';
	my $result = '';
	
	my $ioHash = HMCCU_GetHash ($clHash);
	return (-3, $result) if (!defined ($ioHash));
	return (-4, $result) if ($type ne 'HMCCU' && $clHash->{ccudevstate} eq 'deleted');

	# Get flags and attributes
	my $ioFlags = HMCCU_GetFlags ($ioHash->{NAME});
	my $clFlags = HMCCU_GetFlags ($name);
	my $ccureadings = AttrVal ($name, 'ccureadings', $clFlags =~ /noReadings/ ? 0 : 1);
	my $readingformat = HMCCU_GetAttrReadingFormat ($clHash, $ioHash);
	my $substitute = HMCCU_GetAttrSubstitute ($clHash, $ioHash);
	
	# Parse address, complete address information
	my ($int, $add, $chn, $dpt, $nam, $flags) = HMCCU_ParseObject ($ioHash, $address,
		$HMCCU_FLAG_FULLADDR);
	return (-1, $result) if (!($flags & $HMCCU_FLAG_ADDRESS));
	$addr = $add;
	$addr .= ':'.$chn if ($flags & $HMCCU_FLAG_CHANNEL);

	# Get RPC type and port for interface of device address
	my ($rpcType, $rpcPort) = HMCCU_GetRPCServerInfo ($ioHash, $int, 'type,port');
	return (-9, '') if (!defined ($rpcType) || !defined ($rpcPort));

	# Search RPC device, do not create one
	my ($rpcDevice, $save) = HMCCU_GetRPCDevice ($ioHash, 0, $int);
	return (-17, $result) if ($rpcDevice eq '');
	my $rpcHash = $defs{$rpcDevice};
	
	# Build parameter array: (Address, Paramset [, Parameter ...])
	# Paramset := VALUE | MASTER | LINK or any paramset supported by device
	# Parameter := Name=Value
	my @parArray = ($addr, $paramset);
	if (defined ($parref)) {
		foreach my $k (keys %{$parref}) { push @parArray, "$k=$parref->{$k}"; };
	}
	
	# Submit RPC request
	my $reqResult = HMCCURPCPROC_SendRequest ($rpcHash, $reqMethod, @parArray);
	return (-5, "Function not available") if (!defined ($reqResult));
	
	HMCCU_Trace ($clHash, 2, $fnc,
		"Dump of RPC request $method $addr. Result type=".ref($reqResult)."<br>".
		HMCCU_RefToString ($reqResult));	

	my $parCount = 0;
	
	if (ref ($reqResult) eq 'HASH') {
		if (exists ($reqResult->{faultString})) {
			HMCCU_Log ($rpcHash, 1, $reqResult->{faultString});
			return (-2, $reqResult->{faultString});
		}
		else {
			$parCount = keys %{$reqResult};
		}
	}
#	else {
#		return (-2, defined ($RPC::XML::ERROR) ? $RPC::XML::ERROR : 'RPC request failed');
#	}	

	if ($method eq 'listParamset') {
		$result = join ("\n", map { $_ =~ /$filter/ ? $_.'='.$reqResult->{$_} : () } keys %$reqResult);
	}
	elsif ($method eq 'getDeviceDescription') {
		$result = '';
		foreach my $k (sort keys %$reqResult) {
			if (ref($reqResult->{$k}) eq 'ARRAY') {
				$result .= "$k=".join(',', @{$reqResult->{$k}})."\n";
			}
			else {
				$result .= "$k=".$reqResult->{$k}."\n";
			}
		}
	}
	elsif ($method eq 'getParamsetDescription') {
		my %operFlags = ( 1 => 'R', 2 => 'W', 4 => 'E' );
		$result = join ("\n", 
			map {
				$_.': '.
				$reqResult->{$_}->{TYPE}.
				" [".HMCCU_BitsToStr(\%operFlags,$reqResult->{$_}->{OPERATIONS})."]".
				" FLAGS=".sprintf("%#b", $reqResult->{$_}->{FLAGS}).
				" RANGE=".$reqResult->{$_}->{MIN}."-".$reqResult->{$_}->{MAX}.
				" DFLT=".$reqResult->{$_}->{DEFAULT}.
				" UNIT=".$reqResult->{$_}->{UNIT}
			} sort keys %$reqResult);		
	}
	elsif ($method eq 'getParamset') {
		readingsBeginUpdate ($clHash) if ($ccureadings);

		foreach my $k (sort keys %$reqResult) {
			next if ($k !~ /$filter/);
			my $value = $reqResult->{$k};
			$result .= "$k=$value\n";
			if ($ccureadings) {			
				$value = HMCCU_FormatReadingValue ($clHash, $value, $k);
				$value = HMCCU_Substitute ($value, $substitute, 0, $chn, $k);
				my @readings = HMCCU_GetReadingName ($clHash, $int, $add, $chn, $k, $nam, $readingformat);
				foreach my $rn (@readings) {
					next if ($rn eq '');
					$rn = "R-".$rn;
					readingsBulkUpdate ($clHash, $rn, $value);
				}
			}
		}

		readingsEndUpdate ($clHash, 1) if ($ccureadings);
	}
	
	return (0, $result);
}

######################################################################
#                  *** FILEQUEUE FUNCTIONS ***
######################################################################

######################################################################
# Open file queue
######################################################################

sub HMCCU_QueueOpen ($$)
{
	my ($hash, $queue_file) = @_;
	
	my $idx_file = $queue_file . '.idx';
	$queue_file .= '.dat';
	my $mode = '0666';

	umask (0);
	
	$hash->{hmccu}{queue}{block_size} = 64;
	$hash->{hmccu}{queue}{seperator} = "\n";
	$hash->{hmccu}{queue}{sep_length} = length $hash->{hmccu}{queue}{seperator};

	$hash->{hmccu}{queue}{queue_file} = $queue_file;
	$hash->{hmccu}{queue}{idx_file} = $idx_file;

	$hash->{hmccu}{queue}{queue} = new IO::File $queue_file, O_CREAT | O_RDWR, oct($mode) or return 0;
	$hash->{hmccu}{queue}{idx} = new IO::File $idx_file, O_CREAT | O_RDWR, oct($mode) or return 0;

	### Default ptr to 0, replace it with value in idx file if one exists
	$hash->{hmccu}{queue}{idx}->sysseek(0, SEEK_SET); 
	$hash->{hmccu}{queue}{idx}->sysread($hash->{hmccu}{queue}{ptr}, 1024);
	$hash->{hmccu}{queue}{ptr} = '0' unless $hash->{hmccu}{queue}{ptr};
  
	if($hash->{hmccu}{queue}{ptr} > -s $queue_file)
	{
		$hash->{hmccu}{queue}{idx}->truncate(0) or return 0;
		$hash->{hmccu}{queue}{idx}->sysseek(0, SEEK_SET); 
		$hash->{hmccu}{queue}{idx}->syswrite('0') or return 0;
	}
	
	return 1;
}

######################################################################
# Close file queue
######################################################################

sub HMCCU_QueueClose ($)
{
	my ($hash) = @_;
	
	if (exists ($hash->{hmccu}{queue})) {
		$hash->{hmccu}{queue}{idx}->close();
		$hash->{hmccu}{queue}{queue}->close();
		delete $hash->{hmccu}{queue};
	}
}

sub HMCCU_QueueReset ($)
{
	my ($hash) = @_;

	$hash->{hmccu}{queue}{idx}->truncate(0) or return 0;
	$hash->{hmccu}{queue}{idx}->sysseek(0, SEEK_SET); 
	$hash->{hmccu}{queue}{idx}->syswrite('0') or return 0;

	$hash->{hmccu}{queue}{queue}->sysseek($hash->{hmccu}{queue}{ptr} = 0, SEEK_SET); 
  
	return 1;
}

######################################################################
# Put value in file queue
######################################################################

sub HMCCU_QueueEnq ($$)
{
	my ($hash, $element) = @_;

	return 0 if (!exists ($hash->{hmccu}{queue}));
	
	$hash->{hmccu}{queue}{queue}->sysseek(0, SEEK_END); 
	$element =~ s/$hash->{hmccu}{queue}{seperator}//g;
	$hash->{hmccu}{queue}{queue}->syswrite($element.$hash->{hmccu}{queue}{seperator}) or return 0;
  
	return 1;  
}

######################################################################
# Return next value in file queue
######################################################################

sub HMCCU_QueueDeq ($)
{
	my ($hash) = @_;
	my $name = $hash->{NAME};
	my $sep_length = $hash->{hmccu}{queue}{sep_length};
	my $element = '';

	return undef if (!exists ($hash->{hmccu}{queue}));

	$hash->{hmccu}{queue}{queue}->sysseek($hash->{hmccu}{queue}{ptr}, SEEK_SET);

	my $i;
	while($hash->{hmccu}{queue}{queue}->sysread($_, $hash->{hmccu}{queue}{block_size})) {
		$i = index($_, $hash->{hmccu}{queue}{seperator});
		if($i != -1) {
			$element .= substr($_, 0, $i);
			$hash->{hmccu}{queue}{ptr} += $i + $sep_length;
			$hash->{hmccu}{queue}{queue}->sysseek($hash->{hmccu}{queue}{ptr}, SEEK_SET);
			last;
		}
		else {
			# Seperator not found, go back 'sep_length' spaces to ensure we don't miss it between reads
			Log3 $name, 2, "HMCCU: HMCCU_QueueDeq seperator not found";
			$element .= substr($_, 0, -$sep_length, '');
			$hash->{hmccu}{queue}{ptr} += $hash->{hmccu}{queue}{block_size} - $sep_length;
			$hash->{hmccu}{queue}{queue}->sysseek($hash->{hmccu}{queue}{ptr}, SEEK_SET);
		}
	}

	## If queue seek pointer is at the EOF, truncate the queue file
	if($hash->{hmccu}{queue}{queue}->sysread($_, 1) == 0)
	{
		$hash->{hmccu}{queue}{queue}->truncate(0) or return undef;
		$hash->{hmccu}{queue}{queue}->sysseek($hash->{hmccu}{queue}{ptr} = 0, SEEK_SET);
	}

	## Set idx file contents to point to the current seek position in queue file
	$hash->{hmccu}{queue}{idx}->truncate(0) or return undef;
	$hash->{hmccu}{queue}{idx}->sysseek(0, SEEK_SET);
	$hash->{hmccu}{queue}{idx}->syswrite($hash->{hmccu}{queue}{ptr}) or return undef;

	return ($element ne '') ? $element : undef;
}

######################################################################
#                     *** HELPER FUNCTIONS ***
######################################################################

######################################################################
# Determine HomeMatic state considering datapoint values specified
# in attributes ccudef-hmstatevals and hmstatevals.
# Return (reading, channel, datapoint, value)
######################################################################

sub HMCCU_GetHMState ($$$)
{
	my ($name, $ioname, $defval) = @_;
	my @hmstate = ('hmstate', undef, undef, $defval);
	my $fnc = "GetHMState";

	my $clhash = $defs{$name};
	my $cltype = $clhash->{TYPE};
	return @hmstate if ($cltype ne 'HMCCUDEV' && $cltype ne 'HMCCUCHN');
	
	my $ghmstatevals = AttrVal ($ioname, 'ccudef-hmstatevals', $HMCCU_DEF_HMSTATE);
	my $hmstatevals = AttrVal ($name, 'hmstatevals', $ghmstatevals);
	$hmstatevals .= ";".$ghmstatevals if ($hmstatevals ne $ghmstatevals);
	
	# Get reading name
	if ($hmstatevals =~ /^=([^;]*);/) {
		$hmstate[0] = $1;
		$hmstatevals =~ s/^=[^;]*;//;
	}
	
	# Default hmstate is equal to state
	$hmstate[3] = ReadingsVal ($name, 'state', undef) if (!defined ($defval));

	# Substitute variables	
	$hmstatevals = HMCCU_SubstVariables ($clhash, $hmstatevals, undef);

	my @rulelist = split (";", $hmstatevals);
	foreach my $rule (@rulelist) {
		my ($dptexpr, $subst) = split ('!', $rule, 2);
		my $dp = '';
		next if (!defined ($dptexpr) || !defined ($subst));
		HMCCU_Trace ($clhash, 2, $fnc, "rule=$rule, dptexpr=$dptexpr, subst=$subst");
		foreach my $d (keys %{$clhash->{hmccu}{dp}}) {
			HMCCU_Trace ($clhash, 2, $fnc, "Check $d match $dptexpr");
			if ($d =~ /$dptexpr/) {
				$dp = $d;
				last;
			}
		}
		next if ($dp eq '');
		my ($chn, $dpt) = split (/\./, $dp);
		my $value = HMCCU_FormatReadingValue ($clhash, $clhash->{hmccu}{dp}{$dp}{VAL}, $hmstate[0]);
		my ($rc, $newvalue) = HMCCU_SubstRule ($value, $subst, 0);
		return ($hmstate[0], $chn, $dpt, $newvalue) if ($rc);
	}

	return @hmstate;
}

######################################################################
# Calculate time difference in seconds between current time and
# specified timestamp
######################################################################

sub HMCCU_GetTimeSpec ($)
{
	my ($ts) = @_;
	
	return -1 if ($ts !~ /^[0-9]{2}:[0-9]{2}$/ && $ts !~ /^[0-9]{2}:[0-9]{2}:[0-9]{2}$/);
	
	my (undef, $h, $m, $s)  = GetTimeSpec ($ts);
	return -1 if (!defined ($h));
	
	$s += $h*3600+$m*60;
	my @lt = localtime;
	my $cs = $lt[2]*3600+$lt[1]*60+$lt[0];
	$s += 86400 if ($cs > $s);
	
	return ($s-$cs);
}

######################################################################
# Build ReGa or RPC client URL
# Parameter backend specifies type of URL, 'rega' or name or port of
# RPC interface.
# Return empty string on error.
######################################################################

sub HMCCU_BuildURL ($$)
{
	my ($hash, $backend) = @_;
	my $name = $hash->{NAME};
	
	my $url = '';
	my $username = '';
	my $password = '';
	my ($erruser, $encuser) = getKeyValue ($name."_username");
	my ($errpass, $encpass) = getKeyValue ($name."_password");	
	if (!defined ($erruser) && !defined ($errpass) && defined ($encuser) && defined ($encpass)) {
		$username = HMCCU_Decrypt ($encuser);
		$password = HMCCU_Decrypt ($encpass);
	}
	my $auth = ($username ne '' && $password ne '') ? "$username:$password".'@' : '';
		
	if ($backend eq 'rega') {
		$url = $hash->{prot}."://$auth".$hash->{host}.":".
			$HMCCU_REGA_PORT{$hash->{prot}}."/tclrega.exe";
	}
	else {
		($url) = HMCCU_GetRPCServerInfo ($hash, $backend, 'url');
		if (defined ($url)) {
			if (exists ($HMCCU_RPC_SSL{$backend})) {
				my $p = $hash->{prot} eq 'https' ? '4' : '';
 				$url =~ s/^http:\/\//$hash->{prot}:\/\/$auth/;
				$url =~ s/:([0-9]+)/:$p$1/;
			}
		}
		else {
			$url = '';
		}
	}
	
	HMCCU_Log ($hash, 4, "Build URL = $url");
	return $url;
}

######################################################################
# Calculate special readings. Requires hash of client device, channel
# number and datapoint. Supported functions:
#  dewpoint, absolute humidity, increasing/decreasing counters,
#  minimum/maximum, average, sum, set.
# Return readings array with reading/value pairs.
######################################################################

sub HMCCU_CalculateReading ($$)
{
	my ($cl_hash, $chkeys) = @_;
	my $name = $cl_hash->{NAME};
	my $fnc = "HMCCU_CalculateReading";
	
	my @result = ();
	
	my $ccucalculate = AttrVal ($name, 'ccucalculate', '');
	return @result if ($ccucalculate eq '');
	
	my @calclist = split (/[;\n]+/, $ccucalculate);
	foreach my $calculation (@calclist) {
		my ($vt, $rn, $dpts) = split (':', $calculation, 3);
		next if (!defined ($dpts));
		my $tmpdpts = ",$dpts,";
		$tmpdpts =~ s/[\$\%\{\}]+//g;
		HMCCU_Trace ($cl_hash, 2, $fnc, "vt=$vt, rn=$rn, dpts=$dpts, tmpdpts=$tmpdpts");
		my $f = 0;
		foreach my $chkey (@$chkeys) {
			if ($tmpdpts =~ /,$chkey,/) {
				$f = 1;
				last;
			}
		}
		next if ($f == 0);
		my @dplist = split (',', $dpts);

		# Get parameters values stored in device hash
		my $newdpts = HMCCU_SubstVariables ($cl_hash, $dpts, undef);
		my @pars = split (',', $newdpts);
		my $pc = scalar (@pars);
		next if ($pc != scalar(@dplist));
		$f = 0;
		for (my $i=0; $i<$pc; $i++) {
			$pars[$i] =~ s/^#//;
			if ($pars[$i] eq $dplist[$i]) {
				$f = 1;
				last;
			}
		}
		next if ($f);
		
		if ($vt eq 'dewpoint' || $vt eq 'abshumidity') {
			# Dewpoint and absolute humidity
			next if ($pc < 2);
			my ($tmp, $hum) = @pars;
			if ($tmp >= 0.0) {
				$a = 7.5;
				$b = 237.3;
			}
			else {
				$a = 7.6;
				$b = 240.7;
			}

			my $sdd = 6.1078*(10.0**(($a*$tmp)/($b+$tmp)));
			my $dd = $hum/100.0*$sdd;
			if ($dd != 0.0) {
				if ($vt eq 'dewpoint') {
					my $v = log($dd/6.1078)/log(10.0);
					my $td = $b*$v/($a-$v);
					push (@result, $rn, (sprintf "%.1f", $td));
				}
				else {
					my $af = 100000.0*18.016/8314.3*$dd/($tmp+273.15);
					push (@result, $rn, (sprintf "%.1f", $af));
				}
			}
		}
		elsif ($vt eq 'equ') {
			# Set reading to value if all variables have the same value
			next if ($pc < 1);
			my $curval = shift @pars;
			my $f = 1;
			foreach my $newval (@pars) {
				$f = 0 if ("$newval" ne "$curval");
			}
			push (@result, $rn, $f ? $curval : "n/a");
		}
		elsif ($vt eq 'min' || $vt eq 'max') {
			# Minimum or maximum values
			next if ($pc < 1);
			my $curval = $pc > 1 ? shift @pars : ReadingsVal ($name, $rn, 0);
			foreach my $newval (@pars) {
				$curval = $newval if ($vt eq 'min' && $newval < $curval);
				$curval = $newval if ($vt eq 'max' && $newval > $curval);
			}
			push (@result, $rn, $curval);
		}
		elsif ($vt eq 'inc' || $vt eq 'dec') {
			# Increasing or decreasing values without reset
			next if ($pc < 1);
			my $newval = shift @pars;
			my $oldval = ReadingsVal ($name, $rn."_old", 0);
			my $curval = ReadingsVal ($name, $rn, 0);
			if (($vt eq 'inc' && $newval < $curval) || ($vt eq 'dec' && $newval > $curval)) {
				$oldval = $curval;
				push (@result, $rn."_old", $oldval);
			}
			$curval = $newval+$oldval;
			push (@result, $rn, $curval);
 		}
		elsif ($vt eq 'avg') {
			# Average value
			next if ($pc < 1);
			if ($pc == 1) {
				my $newval = shift @pars;
				my $cnt = ReadingsVal ($name, $rn."_cnt", 0);
				my $sum = ReadingsVal ($name, $rn."_sum", 0);
				$cnt++;
				$sum += $newval;
				my $curval = $sum/$cnt;
				push (@result, $rn."_cnt", $cnt, $rn."_sum", $sum, $rn, $curval);
			}
			else {
				my $sum = 0;
				foreach my $p (@pars) { $sum += $p; }
				push (@result, $rn, $sum/scalar(@pars));
			}
		}
		elsif ($vt eq 'sum') {
			# Sum of values
			next if ($pc < 1);
			my $curval = $pc > 1 ? 0 : ReadingsVal ($name, $rn, 0);
			foreach my $newval (@pars) {
				$curval += $newval;
			}
			push (@result, $rn, $curval);
		}
		elsif ($vt eq 'or') {
			# Logical OR
			next if ($pc < 1);
			my $curval = $pc > 1 ? 0 : ReadingsVal ($name, $rn, 0);
			foreach my $newval (@pars) {
				$curval |= $newval;
			}
			push (@result, $rn, $curval);
		}
		elsif ($vt eq 'and') {
			# Logical AND
			next if ($pc < 1);
			my $curval = $pc > 1 ? 1 : ReadingsVal ($name, $rn, 1);
			foreach my $newval (@pars) {
				$curval &= $newval;
			}
			push (@result, $rn, $curval);
		}
		elsif ($vt eq 'set') {
			# Set reading to value
			next if ($pc < 1);
			push (@result, $rn, join('', @pars));
		}
	}
	
	return @result;
}

######################################################################
# Encrypt string with FHEM unique ID
######################################################################

sub HMCCU_Encrypt ($)
{
	my ($istr) = @_;
	my $ostr = '';
	
	my $id = getUniqueId();
	return '' if (!defined ($id) || $id eq '');
	
	my $key = $id;
	foreach my $c (split //, $istr) {
		my $k = chop($key);
		if ($k eq '') {
			$key = $id;
			$k = chop($key);
		}
		$ostr .= sprintf ("%.2x",ord($c)^ord($k));
	}

	return $ostr;	
}

######################################################################
# Decrypt string with FHEM unique ID
######################################################################

sub HMCCU_Decrypt ($)
{
	my ($istr) = @_;
	my $ostr = '';

	my $id = getUniqueId();
	return '' if (!defined ($id) || $id eq '');

	my $key = $id;
	for my $c (map { pack('C', hex($_)) } ($istr =~ /(..)/g)) {
		my $k = chop($key);
		if ($k eq '') {
			$key = $id;
			$k = chop($key);
		}
		$ostr .= chr(ord($c)^ord($k));
	}

	return $ostr;
}

######################################################################
# Delete readings matching regular expression.
# Default for rnexp is .*
# Readings 'state' and 'control' are ignored.
######################################################################

sub HMCCU_DeleteReadings ($$)
{
	my ($hash, $rnexp) = @_;

	$rnexp = '.*' if (!defined ($rnexp));
	my @readlist = keys %{$hash->{READINGS}};
	foreach my $rd (@readlist) {
		delete ($hash->{READINGS}{$rd}) if ($rd ne 'state' && $rd ne 'control' && $rd =~ /$rnexp/);
	}
}

######################################################################
# Encode command string for e-paper display
#
# Parameters:
#
#  msg := parameter=value[,...]
#
#  text1-3=Text
#  icon1-3=IconName
#  sound=SoundName
#  signal=SignalName
#  pause=1-160
#  repeat=0-15
#
# Returns undef on error or encoded string on success
######################################################################

sub HMCCU_EncodeEPDisplay ($)
{
	my ($msg) = @_;
	
	# set defaults
	$msg = '' if (!defined ($msg));
	
	my %disp_icons = (
		ico_off    => '0x80', ico_on => '0x81', ico_open => '0x82', ico_closed => '0x83',
		ico_error  => '0x84', ico_ok => '0x85', ico_info => '0x86', ico_newmsg => '0x87',
		ico_svcmsg => '0x88'
	);

	my %disp_sounds = (
		snd_off        => '0xC0', snd_longlong => '0xC1', snd_longshort  => '0xC2',
		snd_long2short => '0xC3', snd_short    => '0xC4', snd_shortshort => '0xC5',
		snd_long       => '0xC6'
	);

	my %disp_signals = (
		sig_off => '0xF0', sig_red => '0xF1', sig_green => '0xF2', sig_orange => '0xF3'
	);

	# Parse command string
	my @text = ('', '', '');
	my @icon = ('', '', '');
	my %conf = (sound => 'snd_off', signal => 'sig_off', repeat => 1, pause => 10);
	foreach my $tok (split (',', $msg)) {
		my ($par, $val) = split ('=', $tok);
		next if (!defined ($val));
		if ($par =~ /^text([1-3])$/) {
			$text[$1-1] = substr ($val, 0, 12);
		}
		elsif ($par =~ /^icon([1-3])$/) {
			$icon[$1-1] = $val;
		}
		elsif ($par =~ /^(sound|pause|repeat|signal)$/) {
			$conf{$1} = $val;
		}
	}
	
	my $cmd = '0x02,0x0A';

	for (my $c=0; $c<3; $c++) {
		if ($text[$c] ne '' || $icon[$c] ne '') {
			$cmd .= ',0x12';
			
			# Hex code
			if ($text[$c] =~ /^0x[0-9A-F]{2}$/) {
				$cmd .= ','.$text[$c];
			}
			# Predefined text code #0-9
			elsif ($text[$c] =~ /^#([0-9])$/) {
				$cmd .= sprintf (",0x8%1X", $1);
			}
			# Convert string to hex codes
			else {
				$text[$c] =~ s/\\_/ /g;
				foreach my $ch (split ('', $text[$c])) {
					$cmd .= sprintf (",0x%02X", ord ($ch));
				}
			}
			
			# Icon
			if ($icon[$c] ne '' && exists ($disp_icons{$icon[$c]})) {
				$cmd .= ',0x13,'.$disp_icons{$icon[$c]};
			}
		}
		
		$cmd .= ',0x0A';
	}
	
	# Sound
	my $snd = $disp_sounds{snd_off};
	$snd = $disp_sounds{$conf{sound}} if (exists ($disp_sounds{$conf{sound}}));
	$cmd .= ',0x14,'.$snd.',0x1C';

	# Repeat
	my $rep = $conf{repeat} if ($conf{repeat} >= 0 && $conf{repeat} <= 15);
	$rep = 1 if ($rep < 0);
	$rep = 15 if ($rep > 15);
	if ($rep == 0) {
		$cmd .= ',0xDF';
	}
	else {
		$cmd .= sprintf (",0x%02X", 0xD0+$rep-1);
	}
	$cmd .= ',0x1D';
	
	# Pause
	my $pause = $conf{pause};
	$pause = 1 if ($pause < 1);
	$pause = 160 if ($pause > 160);
	$cmd .= sprintf (",0xE%1X,0x16", int(($pause-1)/10));
	
	# Signal
	my $sig = $disp_signals{sig_off};
	$sig = $disp_signals{$conf{signal}} if (exists ($disp_signals{$conf{signal}}));
	$cmd .= ','.$sig.',0x03';
	
	return $cmd;
}

######################################################################
# Convert reference to string recursively
# Supports reference to ARRAY, HASH and SCALAR and scalar values.
######################################################################

sub HMCCU_RefToString ($)
{
	my ($r) = @_;
	
	my $result = '';
	
	if (ref ($r) eq 'ARRAY') {
		$result .= "[\n";
		foreach my $e (@$r) {
			$result .= "," if ($result ne '[');
			$result .= HMCCU_RefToString ($e);
		}
		$result .= "\n]";
	}
	elsif (ref ($r) eq 'HASH') {
		$result .= "{\n";
		foreach my $k (sort keys %$r) {
			$result .= "," if ($result ne '{');
			$result .= "$k=".HMCCU_RefToString ($r->{$k});
		}
		$result .= "\n}";
	}
	elsif (ref ($r) eq 'SCALAR') {
		$result .= $$r;
	}
	else {
		$result .= $r;
	}
	
	return $result;
}

sub HMCCU_BitsToStr ($$)
{
	my ($chrMap, $bMask) = @_;
	
	my $r = '';
	foreach my $bVal (sort keys %$chrMap) {
		$r .= $chrMap->{$bVal} if ($bMask & $bVal);
	}
	
	return $r;
}

######################################################################
# Match string with regular expression considering illegal regular
# expressions.
# Return parameter e if regular expression is incorrect.
######################################################################

sub HMCCU_ExprMatch ($$$)
{
	my ($t, $r, $e) = @_;

	my $x = eval { $t =~ /$r/ };
	return $e if (!defined ($x));
	return "$x" eq '' ? 0 : 1;
}

sub HMCCU_ExprNotMatch ($$$)
{
	my ($t, $r, $e) = @_;

	my $x = eval { $t !~ /$r/ };
	return $e if (!defined ($x));
	return "$x" eq '' ? 0 : 1;
}

######################################################################
# Read duty cycles of interfaces 2001 and 2010 and update readings.
######################################################################

sub HMCCU_GetDutyCycle ($)
{
	my ($hash) = @_;
	my $name = $hash->{NAME};
	
	my $dc = 0;
	my @rpcports = HMCCU_GetRPCPortList ($hash);
	
	readingsBeginUpdate ($hash);
	
	foreach my $port (@rpcports) {
		next if ($port != 2001 && $port != 2010);
		my $url = HMCCU_BuildURL ($hash, $port);
		next if (!defined ($url));
		my $rpcclient = RPC::XML::Client->new ($url);
		my $response = $rpcclient->simple_request ("listBidcosInterfaces");
		next if (!defined ($response) || ref($response) ne 'ARRAY');
		foreach my $iface (@$response) {
			next if (ref ($iface) ne 'HASH');
			next if (!exists ($iface->{DUTY_CYCLE}));
			$dc++;
			my $type;
			if (exists ($iface->{TYPE})) {
				$type = $iface->{TYPE}
			}
			else {
				($type) = HMCCU_GetRPCServerInfo ($hash, $port, 'name');
			}
			readingsBulkUpdate ($hash, "iface_addr_$dc", $iface->{ADDRESS});
			readingsBulkUpdate ($hash, "iface_conn_$dc", $iface->{CONNECTED});
			readingsBulkUpdate ($hash, "iface_type_$dc", $type);
			readingsBulkUpdate ($hash, "iface_ducy_$dc", $iface->{DUTY_CYCLE});
		}
	}
	
	readingsEndUpdate ($hash, 1);
	
	return $dc;
}

######################################################################
# Check if TCP port is reachable.
# Parameter timeout should be a multiple of 20 plus 5.
######################################################################

sub HMCCU_TCPPing ($$$)
{
	my ($addr, $port, $timeout) = @_;
	
	if ($timeout > 0) {
		my $t = time ();
	
		while (time () < $t+$timeout) {
			return 1 if (HMCCU_TCPConnect ($addr, $port) ne '');
			sleep (20);
		}
		
		return 0;
	}
	else {
		return HMCCU_TCPConnect ($addr, $port) eq '' ? 0 : 1;
	}
}

######################################################################
# Check if TCP connection to specified host and port is possible.
# Return empty string on error or local IP address on success.
######################################################################

sub HMCCU_TCPConnect ($$)
{
	my ($addr, $port) = @_;
	
	my $socket = IO::Socket::INET->new (PeerAddr => $addr, PeerPort => $port);
	if ($socket) {
		my $ipaddr = $socket->sockhost ();
		close ($socket);
		return $ipaddr if (defined ($ipaddr));
	}

	return '';
}

######################################################################
# Generate a 6 digit Id from last 2 segments of IP address
######################################################################

sub HMCCU_GetIdFromIP ($$)
{
	my ($ip, $default) = @_;

	my @ipseg = split (/\./, $ip);
	if (scalar (@ipseg) == 4) {
		return sprintf ("%03d%03d", $ipseg[2], $ipseg[3]);
	}
	else {
		return $default;
	}
}
	
######################################################################
# Resolve hostname.
# Return value defip if hostname can't be resolved.
######################################################################

sub HMCCU_ResolveName ($$)
{
	my ($hname, $defip) = @_;
	
	my $ip = $defip;
	my $addrnum = inet_aton ($hname);
	$ip = inet_ntoa ($addrnum) if (defined ($addrnum));
	
	return $ip;
}

######################################################################
# Substitute invalid characters in reading name.
# Substitution rules: ':' => '.', any other illegal character => '_'
######################################################################

sub HMCCU_CorrectName ($)
{
	my ($rn) = @_;
	$rn =~ s/\:/\./g;
	$rn =~ s/[^A-Za-z\d_\.-]+/_/g;
	return $rn;
}

######################################################################
# Get N biggest hash entries
# Format of returned hash is
#   {0..entries-1}{k} = Key of hash entry
#   {0..entries-1}{v} = Value of hash entry
######################################################################

sub HMCCU_MaxHashEntries ($$)
{
	my ($hash, $entries) = @_;
	my %result;

	while (my ($key, $value) = each %$hash) {
		for (my $i=0; $i<$entries; $i++) {
			if (!exists ($result{$i}) || $value > $result{$i}{v}) {
				for (my $j=$entries-1; $j>$i; $j--) {
					if (exists ($result{$j-1})) {
						$result{$j}{k} = $result{$j-1}{k};
						$result{$j}{v} = $result{$j-1}{v};
					}
				}
				$result{$i}{v} = $value;
				$result{$i}{k} = $key;
				last;
			}
		}
	}

	return \%result;
}

######################################################################
#                     *** SUBPROCESS PART ***
######################################################################

# Child process. Must be global to allow access by RPC callbacks
my $hmccu_child;

# Queue file
my %child_queue;
my $cpqueue = \%child_queue;

# Statistic data of child process
my %child_hash = (
	"total", 0,
	"writeerror", 0,
	"EV", 0,
	"ND", 0,
	"DD", 0,
	"RD", 0,
	"RA", 0,
	"UD", 0,
	"IN", 0,
	"EX", 0,
	"SL", 0
);
my $cphash = \%child_hash;


######################################################################
# Subprocess: Write event to parent process
######################################################################

sub HMCCU_CCURPC_Write ($$)
{
	my ($et, $msg) = @_;
	my $name = $hmccu_child->{devname};

	$cphash->{total}++;
	$cphash->{$et}++;

	HMCCU_QueueEnq ($cpqueue, $et."|".$msg);
}

######################################################################
# Subprocess: Initialize RPC server. Return 1 on success.
######################################################################

sub HMCCU_CCURPC_OnRun ($)
{
	$hmccu_child = shift;
	my $name = $hmccu_child->{devname};
	my $serveraddr = $hmccu_child->{serveraddr};
	my $serverport = $hmccu_child->{serverport};
	my $callbackport = $hmccu_child->{callbackport};
	my $queuefile = $hmccu_child->{queue};
	my $clkey = "CB".$serverport;
	my $ccurpc_server;

	# Create, open and reset queue file
 	Log3 $name, 0, "CCURPC: $clkey Creating file queue $queuefile";
 	if (!HMCCU_QueueOpen ($cpqueue, $queuefile)) {
 		Log3 $name, 0, "CCURPC: $clkey Can't create queue";
 		return 0;
 	}

	# Reset event queue
 	HMCCU_QueueReset ($cpqueue);
 	while (defined (HMCCU_QueueDeq ($cpqueue))) { }

	# Create RPC server
	Log3 $name, 0, "CCURPC: Initializing RPC server $clkey";
	$ccurpc_server = RPC::XML::Server->new (port=>$callbackport);
	if (!ref($ccurpc_server))
	{
		Log3 $name, 0, "CCURPC: Can't create RPC callback server on port $callbackport. Port in use?";
		return 0;
	}
	else {
		Log3 $name, 0, "CCURPC: Callback server created listening on port $callbackport";
	}
	
	# Format of signature:
	# string par1 ... parN
	
	# Callback for events
	# Parameters: Server, InterfaceId, Address, ValueKey, Value
	Log3 $name, 1, "CCURPC: $clkey Adding callback for events";
	$ccurpc_server->add_method (
	   { name=>"event",
	     signature=> ["string string string string string","string string string string int","string string string string double","string string string string boolean","string string string string i4"],
	     code=>\&HMCCU_CCURPC_EventCB
	   }
	);

	# Callback for new devices
	# Parameters: Server, InterfaceId, DeviceDescriptions[]
	Log3 $name, 1, "CCURPC: $clkey Adding callback for new devices";
	$ccurpc_server->add_method (
	   { name=>"newDevices",
	     signature=>["string string array"],
             code=>\&HMCCU_CCURPC_NewDevicesCB
	   }
	);

	# Callback for deleted devices
	# Parameters: Server, InterfaceId, Addresses[]
	Log3 $name, 1, "CCURPC: $clkey Adding callback for deleted devices";
	$ccurpc_server->add_method (
	   { name=>"deleteDevices",
	     signature=>["string string array"],
             code=>\&HMCCU_CCURPC_DeleteDevicesCB
	   }
	);

	# Callback for modified devices
	# Parameters: Server, InterfaceId, Address, Hint
	Log3 $name, 1, "CCURPC: $clkey Adding callback for modified devices";
	$ccurpc_server->add_method (
	   { name=>"updateDevice",
	     signature=>["string string string int"],
	     code=>\&HMCCU_CCURPC_UpdateDeviceCB
	   }
	);

	# Callback for replaced devices
	# Parameters: Server, InterfaceId, OldAddress, NewAddress
	Log3 $name, 1, "CCURPC: $clkey Adding callback for replaced devices";
	$ccurpc_server->add_method (
	   { name=>"replaceDevice",
	     signature=>["string string string string"],
	     code=>\&HMCCU_CCURPC_ReplaceDeviceCB
	   }
	);

	# Callback for readded devices
	# Parameters: Server, InterfaceId, Addresses[]
	Log3 $name, 1, "CCURPC: $clkey Adding callback for readded devices";
	$ccurpc_server->add_method (
	   { name=>"replaceDevice",
	     signature=>["string string array"],
	     code=>\&HMCCU_CCURPC_ReaddDeviceCB
	   }
	);
	
	# Dummy implementation, always return an empty array
	# Parameters: Server, InterfaceId
	Log3 $name, 1, "CCURPC: $clkey Adding callback for list devices";
	$ccurpc_server->add_method (
	   { name=>"listDevices",
	     signature=>["string string"],
	     code=>\&HMCCU_CCURPC_ListDevicesCB
	   }
	);

	# Enter server loop
	HMCCU_CCURPC_Write ("SL", "$$|$clkey");

	Log3 $name, 0, "CCURPC: $clkey Entering server loop";
	$ccurpc_server->server_loop;
	Log3 $name, 0, "CCURPC: $clkey Server loop terminated";
	
	# Server loop exited by SIGINT
	HMCCU_CCURPC_Write ("EX", "SHUTDOWN|$$|$clkey");

	return 1;
}

######################################################################
# Subprocess: Called when RPC server loop is terminated
######################################################################

sub HMCCU_CCURPC_OnExit ()
{
	# Output statistics
	foreach my $et (sort keys %child_hash) {
		Log3 $hmccu_child->{devname}, 2, "CCURPC: Eventcount $et = ".$cphash->{$et};
	}
}

######################################################################
# Subprocess: Callback for new devices
######################################################################

sub HMCCU_CCURPC_NewDevicesCB ($$$)
{
	my ($server, $cb, $a) = @_;
	my $devcount = scalar (@$a);
	my $name = $hmccu_child->{devname};
	my $c = 0;
	my $msg = '';
	
	Log3 $name, 2, "CCURPC: $cb NewDevice received $devcount device specifications";	
	foreach my $dev (@$a) {
		my $msg = '';
		if ($dev->{ADDRESS} =~ /:[0-9]{1,2}$/) {
			$msg = "C|".$dev->{ADDRESS}."|".$dev->{TYPE}."|".$dev->{VERSION}."|null|null";
		}
		else {
			# Wired devices do not have a RX_MODE attribute
			my $rx = exists ($dev->{RX_MODE}) ? $dev->{RX_MODE} : 'null';
			$msg = "D|".$dev->{ADDRESS}."|".$dev->{TYPE}."|".$dev->{VERSION}."|".
				$dev->{FIRMWARE}."|".$rx;
		}
		HMCCU_CCURPC_Write ("ND", $msg);
	}

	return;
}

######################################################################
# Subprocess: Callback for deleted devices
######################################################################

sub HMCCU_CCURPC_DeleteDevicesCB ($$$)
{
	my ($server, $cb, $a) = @_;
	my $name = $hmccu_child->{devname};
	my $devcount = scalar (@$a);
	
	Log3 $name, 2, "CCURPC: $cb DeleteDevice received $devcount device addresses";
	foreach my $dev (@$a) {
		HMCCU_CCURPC_Write ("DD", $dev);
	}

	return;
}

######################################################################
# Subprocess: Callback for modified devices
######################################################################

sub HMCCU_CCURPC_UpdateDeviceCB ($$$$)
{
	my ($server, $cb, $devid, $hint) = @_;
	
	HMCCU_CCURPC_Write ("UD", $devid."|".$hint);

	return;
}

######################################################################
# Subprocess: Callback for replaced devices
######################################################################

sub HMCCU_CCURPC_ReplaceDeviceCB ($$$$)
{
	my ($server, $cb, $devid1, $devid2) = @_;
	
	HMCCU_CCURPC_Write ("RD", $devid1."|".$devid2);

	return;
}

######################################################################
# Subprocess: Callback for readded devices
######################################################################

sub HMCCU_CCURPC_ReaddDevicesCB ($$$)
{
	my ($server, $cb, $a) = @_;
	my $name = $hmccu_child->{devname};
	my $devcount = scalar (@$a);
	
	Log3 $name, 2, "CCURPC: $cb ReaddDevice received $devcount device addresses";
	foreach my $dev (@$a) {
		HMCCU_CCURPC_Write ("RA", $dev);
	}

	return;
}

######################################################################
# Subprocess: Callback for handling CCU events
######################################################################

sub HMCCU_CCURPC_EventCB ($$$$$)
{
	my ($server, $cb, $devid, $attr, $val) = @_;
	my $name = $hmccu_child->{devname};
	
	HMCCU_CCURPC_Write ("EV", $devid."|".$attr."|".$val);
	if (($cphash->{EV} % 500) == 0) {
		Log3 $name, 3, "CCURPC: $cb Received 500 events from CCU since last check";
		my @stkeys = ('total', 'EV', 'ND', 'DD', 'RD', 'RA', 'UD', 'IN', 'SL', 'EX');
		my $msg = '';
		foreach my $stkey (@stkeys) {
			$msg .= '|' if ($msg ne '');
			$msg .= $cphash->{$stkey};
		}
		HMCCU_CCURPC_Write ("ST", $msg);
	}

	# Never remove this statement!
	return;
}

######################################################################
# Subprocess: Callback for list devices
######################################################################

sub HMCCU_CCURPC_ListDevicesCB ($$)
{
	my ($server, $cb) = @_;
	my $name = $hmccu_child->{devname};
	
	$cb = "unknown" if (!defined ($cb));
	Log3 $name, 1, "CCURPC: $cb ListDevices. Sending init to HMCCU";
	HMCCU_CCURPC_Write ("IN", "INIT|1|$cb");

	return RPC::XML::array->new();
}


1;


=pod
=item device
=item summary provides interface between FHEM and Homematic CCU2
=begin html

<a name="HMCCU"></a>
<h3>HMCCU</h3>
<ul>
   The module provides an interface between FHEM and a Homematic CCU2. HMCCU is the 
   I/O device for the client devices HMCCUDEV and HMCCUCHN. The module requires the
   additional Perl modules IO::File, RPC::XML::Client, RPC::XML::Server and SubProcess
   (part of FHEM).
   </br></br>
   <a name="HMCCUdefine"></a>
   <b>Define</b><br/><br/>
   <ul>
      <code>define &lt;name&gt; HMCCU [&lt;Protocol&gt;://]&lt;HostOrIP&gt; [&lt;ccu-number&gt;] [waitforccu=&lt;timeout&gt;]
      [ccudelay=&lt;delay&gt;] [delayedinit=&lt;delay&gt;]</code>
      <br/><br/>
      Example:<br/>
      <code>define myccu HMCCU https://192.168.1.10 ccudelay=180</code>
      <br/><br/>
      The parameter <i>HostOrIP</i> is the hostname or IP address of a Homematic CCU2 or CCU3. Optionally
      the <i>protocol</i> 'http' or 'https' can be specified. Default protocol is 'http'.<br/>
      If you have more than one CCU you can specifiy a unique CCU number with parameter <i>ccu-number</i>.
      With option <i>waitforccu</i> HMCCU will wait for the specified time if CCU is not reachable.
      Parameter <i>timeout</i> should be a multiple of 20 in seconds. Warning: This option will 
      block the start of FHEM for <i>timeout</i> seconds.<br/>
      The option <i>ccudelay</i> specifies the time for delayed initialization of CCU environment if
      the CCU is not reachable during FHEM startup (i.e. in case of a power failure). The default value
      for <i>delay</i> is 180 seconds. Increase this value if your CCU needs more time to start up
      after a power failure. This option will not block the start of FHEM.<br/>
      With option <i>delayedinit</i> the CCU ennvironment will be initialized after the specified time,
      no matter if CCU is reachable or not. As long as CCU environment is not initialized all client
      devices of type HMCCUCHN or HMCCUDEV are in state 'pending' and all commands are disabled.<br/><br/>
      For automatic update of Homematic device datapoints and FHEM readings one have to:
      <br/><br/>
      <ul>
      <li>Define used RPC interfaces with attribute 'rpcinterfaces'</li>
      <li>Start RPC servers with command 'set rpcserver on'</li>
      <li>Optionally enable automatic start of RPC servers with attribute 'rpcserver'</li>
      </ul><br/>
      Then start with the definition of client devices using modules HMCCUDEV (CCU devices)
      and HMCCUCHN (CCU channels) or with command 'get devicelist create'.<br/>
      Maybe it's helpful to set the following FHEM standard attributes for the HMCCU I/O
      device:<br/><br/>
      <ul>
      <li>Shortcut for RPC server control: eventMap /rpcserver on:on/rpcserver off:off/</li>
      </ul>
   </ul>
   <br/>
   
   <a name="HMCCUset"></a>
   <b>Set</b><br/><br/>
   <ul>
      <li><b>set &lt;name&gt; ackmessages</b><br/>
      	Acknowledge device was unreachable messages in CCU.
      </li><br/>
      <li><b>set &lt;name&gt; authentication [&lt;username&gt; &lt;password&gt;]</b><br/>
      	Set credentials for CCU authentication. Authentication must be activated by setting 
      	attribute ccuflags to 'authenticate'.<br/>
      	When executing this command without arguments credentials are deleted.
      </li><br/>
      <li><b>set &lt;name&gt; clear [&lt;reading-exp&gt;]</b><br/>
         Delete readings matching specified reading name expression. Default expression is '.*'.
         Readings 'state' and 'control' are not deleted.
      </li><br/>
		<li><b>set &lt;name&gt; cleardefaults</b><br/>
			Clear default attributes imported from file.
		</li><br/>
		<li><b>set &lt;name&gt; datapoint &lt;FHEM-DevSpec&gt; [&lt;channel-number&gt;].&lt;datapoint&gt;=&ltvalue&gt;</b><br/>
			Set datapoint values on multiple devices. If <i>FHEM-Device</i> is of type HMCCUDEV
			a <i>channel-number</i> must be specified. The channel number is ignored for devices of
			type HMCCUCHN.
		</li><br/>
		<li><b>set &lt;name&gt; defaults</b><br/>
		   Set default attributes for I/O device.
		</li><br/>
		<li><b>set &lt;name&gt; delete &lt;ccuobject&gt; [&lt;objecttype&gt;]</b><br/>
			Delete object in CCU. Default object type is OT_VARDP. Valid object types are<br/>
			OT_DEVICE=device, OT_VARDP=variable.
		</li><br/>
      <li><b>set &lt;name&gt; execute &lt;program&gt;</b><br/>
         Execute a CCU program.
         <br/><br/>
         Example:<br/>
         <code>set d_ccu execute PR-TEST</code>
      </li><br/>
      <li><b>set &lt;name&gt; hmscript {&lt;script-file&gt;|'!'&lt;function&gt;|'['&lt;code&gt;']'} [dump] 
         [&lt;parname&gt;=&lt;value&gt; [...]]</b><br/>
         Execute Homematic script on CCU. If script code contains parameter in format $parname
         they are substituted by corresponding command line parameters <i>parname</i>.<br/>
         If output of script contains lines in format Object=Value readings in existing
         corresponding FHEM devices will be set. <i>Object</i> can be the name of a CCU system
         variable or a valid channel and datapoint specification. Readings for system variables
         are set in the I/O device. Datapoint related readings are set in client devices. If option
         'dump' is specified the result of script execution is displayed in FHEM web interface.
         Execute command without parameters will list available script functions.
      </li><br/>
      <li><b>set &lt;name&gt; importdefaults &lt;filename&gt;</b><br/>
      	Import default attributes from file.
      </li><br/>
      <li><b>set &lt;name&gt; initialize</b><br/>
      	Initialize I/O device if state of CCU is unreachable.
      </li><br/>
      <li><b>set &lt;name&gt; prgActivate &lt;program&gt;</b><br/>
         Activate a CCU program.
      </li><br/>
      <li><b>set &lt;name&gt; prgDeactivate &lt;program&gt;</b><br/>
         Deactivate a CCU program.
      </li><br/>
      <li><b>set &lt;name&gt; rpcregister [{all | &lt;interface&gt;}]</b><br/>
      	Register RPC servers at CCU.
      </li><br/>
      <li><b>set &lt;name&gt; rpcserver {on | off | restart}</b><br/>
         Start, stop or restart RPC server(s). This command executed with option 'on'
         will fork a RPC server process for each RPC interface defined in attribute 'rpcinterfaces'.
         Until operation is completed only a few set/get commands are available and you
         may get the error message 'CCU busy'.
      </li><br/>
      <li><b>set &lt;name&gt; var &lt;variable&gt; &lt;Value&gt;</b><br/>
        Set CCU system variable value. Special characters \_ in <i>value</i> are
        substituted by blanks.
      </li>
   </ul>
   <br/>
   
   <a name="HMCCUget"></a>
   <b>Get</b><br/><br/>
   <ul>
      <li><b>get &lt;name&gt; aggregation {&lt;rule&gt;|all}</b><br/>
      	Process aggregation rule defined with attribute ccuaggregate.
      </li><br/>
      <li><b>get &lt;name&gt; ccumsg {service|alarm}</b><br/>
      	Query active service or alarm messages from CCU. Generate FHEM event for each message.
      </li><br/>
      <li><b>get &lt;name&gt; configdesc {&lt;device&gt;|&lt;channel&gt;}</b><br/>
         Get configuration parameter description of CCU device or channel (similar
         to device settings in CCU). Not every CCU device or channel provides a configuration
         parameter description. So result may be empty.
      </li><br/>
      <li><b>get &lt;name&gt; defaults</b><br/>
      	List device types and channels with default attributes available.
      </li><br/>
      <li><b>get &lt;name&gt; deviceinfo &lt;device-name&gt; [{State | <u>Value</u>}]</b><br/>
         List device channels and datapoints. If option 'State' is specified the device is
         queried directly. Otherwise device information from CCU is listed.
      </li><br/>
      <li><b>get &lt;name&gt; devicelist [dump]</b><br/>
         Read list of devices and channels from CCU. This command is executed automatically
         after the definition of an I/O device. It must be executed manually after
         module HMCCU is reloaded or after devices have changed in CCU (added, removed or
         renamed). With option 'dump' devices are displayed in browser window. If a RPC
         server is running HMCCU will raise events "<i>count</i> devices added in CCU" or
         "<i>count</i> devices deleted in CCU". It's recommended to set up a notification
         which reacts with execution of command 'get devicelist' on these events.
      </li><br/>
      <li><b>get &lt;name&gt; devicelist create &lt;devexp&gt; [t={chn|<u>dev</u>|all}]
      	[p=&lt;prefix&gt;] [s=&lt;suffix&gt;] [f=&lt;format&gt;] [defattr] [duplicates] 
      	[save] [&lt;attr&gt;=&lt;value&gt; [...]]</b><br/>
         With option 'create' HMCCU will automatically create client devices for all CCU devices
         and channels matching specified regular expression. With option t=chn or t=dev (default) 
         the creation of devices is limited to CCU channels or devices.<br/>
         Optionally a <i>prefix</i> and/or a
         <i>suffix</i> for the FHEM device name can be specified. The parameter <i>format</i>
         defines a template for the FHEM device names. Prefix, suffix and format can contain
         format identifiers which are substituted by corresponding values of the CCU device or
         channel: %n = CCU object name (channel or device), %d = CCU device name, %a = CCU address.
         In addition a list of default attributes for the created client devices can be specified.
         If option 'defattr' is specified HMCCU tries to set default attributes for device. 
         With option 'duplicates' HMCCU will overwrite existing devices and/or create devices 
         for existing device addresses. Option 'save' will save FHEM config after device definition.
      </li><br/>
      <li><b>get &lt;name&gt; dump {datapoints|devtypes} [&lt;filter&gt;]</b><br/>
      	Dump all Homematic devicetypes or all devices including datapoints currently
      	defined in FHEM.
      </li><br/>
      <li><b>get &lt;name&gt; dutycycle</b><br/>
         Read CCU interface and gateway information. For each interface/gateway the following
         information is stored in readings:<br/>
         iface_addr_n = interface address<br/>
         iface_type_n = interface type<br/>
         iface_conn_n = interface connection state (1=connected, 0=disconnected)<br/>
         iface_ducy_n = duty cycle of interface (0-100)
      </li><br/>
      <li><b>get &lt;name&gt; exportdefaults &lt;filename&gt; [csv] [all]</b><br/>
      	Export default attributes into file. If option <i>all</i> is specified, also defaults imported
      	by customer will be exported.
      </li><br/>
      <li><b>get &lt;name&gt; firmware [{&lt;type-expr&gt; | full}]</b><br/>
      	Get available firmware downloads from eq-3.de. List FHEM devices with current and available
      	firmware version. By default only firmware version of defined HMCCUDEV or HMCCUCHN
      	devices are listet. With option 'full' all available firmware versions are listed.
      	With parameter <i>type-expr</i> one can filter displayed firmware versions by 
      	Homematic device type.
      </li><br/>
      <li><b>get &lt;name&gt; rpcstate</b><br/>
         Check if RPC server process is running.
      </li><br/>
      <li><b>get &lt;name&gt; update [&lt;devexp&gt; [{State | <u>Value</u>}]]</b><br/>
         Update all datapoints / readings of client devices with <u>FHEM device name</u>(!) matching
         <i>devexp</i>. With option 'State' all CCU devices are queried directly. This can be
         time consuming.
      </li><br/>
      <li><b>get &lt;name&gt; updateccu [&lt;devexp&gt; [{State | <u>Value</u>}]]</b><br/>
         Update all datapoints / readings of client devices with <u>CCU device name</u>(!) matching
         <i>devexp</i>. With option 'State' all CCU devices are queried directly. This can be
         time consuming.
      </li><br/>
      <li><b>get &lt;name&gt; vars &lt;regexp&gt;</b><br/>
         Get CCU system variables matching <i>regexp</i> and store them as readings.
      </li>
   </ul>
   <br/>
   
   <a name="HMCCUattr"></a>
   <b>Attributes</b><br/>
   <br/>
   <ul>
      <li><b>ccuaggregate &lt;rule&gt;[;...]</b><br/>
      	Define aggregation rules for client device readings. With an aggregation rule
      	it's easy to detect if some or all client device readings are set to a specific
      	value, i.e. detect all devices with low battery or detect all open windows.<br/>
      	Aggregation rules are automatically executed as a reaction on reading events of
      	HMCCU client devices. An aggregation rule consists of several parameters separated
      	by comma:<br/><br/>
      	<ul>
      	<li><b>name:&lt;rule-name&gt;</b><br/>
      	Name of aggregation rule</li>
      	<li><b>filter:{name|alias|group|room|type}=&lt;incl-expr&gt;[!&lt;excl-expr&gt;]</b><br/>
      	Filter criteria, i.e. "type=^HM-Sec-SC.*"</li>
      	<li><b>read:&lt;read-expr&gt;</b><br/>
      	Expression for reading names, i.e. "STATE"</li>
      	<li><b>if:{any|all|min|max|sum|avg|lt|gt|le|ge}=&lt;value&gt;</b><br/>
      	Condition, i.e. "any=open" or initial value, i.e. max=0</li>
      	<li><b>else:&lt;value&gt;</b><br/>
      	Complementary value, i.e. "closed"</li>
      	<li><b>prefix:{&lt;text&gt;|RULE}</b><br/>
      	Prefix for reading names with aggregation results</li>
      	<li><b>coll:{&lt;attribute&gt;|NAME}[!&lt;default-text&gt;]</b><br/>
      	Attribute of matching devices stored in aggregation results. Default text in case
      	of no matching devices found is optional.</li>
      	<li><b>html:&lt;template-file&gt;</b><br/>
      	Create HTML code with matching devices.</li>
      	</ul><br/>
      	Aggregation results will be stored in readings <i>prefix</i>count, <i>prefix</i>list,
      	<i>prefix</i>match, <i>prefix</i>state and <i>prefix</i>table.<br/><br/>
      	Format of a line in <i>template-file</i> is &lt;keyword&gt;:&lt;html-code&gt;. See
      	FHEM Wiki for an example. Valid keywords are:<br/><br/>
      	<ul>
      	<li><b>begin-html</b>: Start of html code.</li>
      	<li><b>begin-table</b>: Start of table (i.e. the table header)</li>
      	<li><b>row-odd</b>: HTML code for odd lines. A tag &lt;reading/&gt is replaced by a matching device.</li>
      	<li><b>row-even</b>: HTML code for event lines.</li>
      	<li><b>end-table</b>: End of table.</li>
      	<li><b>default</b>: HTML code for no matches.</li>
      	<li><b>end-html</b>: End of html code.</li>
      	</ul><br/>
      	Example: Find open windows<br/>
      	name=lock,filter:type=^HM-Sec-SC.*,read:STATE,if:any=open,else:closed,prefix:lock_,coll:NAME!All windows closed<br/><br/>
      	Example: Find devices with low batteries. Generate reading in HTML format.<br/>
      	name=battery,filter:name=.*,read:(LOWBAT|LOW_BAT),if:any=yes,else:no,prefix:batt_,coll:NAME!All batteries OK,html:/home/battery.cfg<br/>
      </li><br/>
      <li><b>ccudef-hmstatevals &lt;subst-rule[;...]&gt;</b><br/>
      	Set global rules for calculation of reading hmstate.
      </li><br/>
      <li><b>ccudef-readingfilter &lt;filter-rule[;...]&gt;</b><br/>
         Set global reading/datapoint filter. This filter is added to the filter specified by
         client device attribute 'ccureadingfilter'.
      </li><br/>
      <li><b>ccudef-readingformat {name | address | <u>datapoint</u> | namelc | addresslc |
		   datapointlc}</b><br/>
		   Set global reading format. This format is the default for all readings except readings
		   of virtual device groups.
		</li><br/>
      <li><b>ccudef-readingname &lt;old-readingname-expr&gt;:[+]&lt;new-readingname&gt;
         [;...]</b><br/>
         Set global rules for reading name substitution. These rules are added to the rules
         specified by client device attribute 'ccureadingname'.
      </li><br/>
      <li><b>ccudef-stripnumber [&lt;datapoint-expr&gt;!]{0|1|2|-n|%fmt}[;...]</b><br/>
         Set global formatting rules for numeric datapoint or config parameter values.
         Default value is 2 (strip trailing zeroes).<br/>
         For details see description of attribute stripnumber in <a href="#HMCCUCHNattr">HMCCUCHN</a>.
      </li>
      <li><b>ccudef-substitute &lt;subst-rule&gt;[;...]</b><br/>
         Set global substitution rules for datapoint value. These rules are added to the rules
         specified by client device attribute 'substitute'.
      </li><br/>
      <li><b>ccudefaults &lt;filename&gt;</b><br/>
      	Load default attributes for HMCCUCHN and HMCCUDEV devices from specified file. Best
      	practice for creating a custom default attribute file is by exporting predefined default
      	attributes from HMCCU with command 'get exportdefaults'.
      </li><br/>
      <li><b>ccuflags {&lt;flags&gt;}</b><br/>
      	Control behaviour of several HMCCU functions. Parameter <i>flags</i> is a comma
      	seperated list of the following strings:<br/>
      	ackState - Acknowledge command execution by setting STATE to error or success.<br/>
      	dptnocheck - Do not check within set or get commands if datapoint is valid<br/>
      	intrpc - No longer supported.<br/>
      	extrpc - No longer supported.<br/>
      	logCommand - Write all set and get commands of all devices to log file with verbose level 3.<br/>
      	logEvents - Write events from CCU into FHEM logfile<br/>
			logPong - Write log message when receiving pong event if verbose level is at least 3.<br/>
      	noEvents - Ignore events / device updates sent by CCU. No readings will be updated!<br/>
      	noInitialUpdate - Do not update datapoints of devices after RPC server start. Overrides 
      	settings in RPC devices.
      	nonBlocking - Use non blocking (asynchronous) CCU requests<br/>
      	noReadings - Do not create or update readings<br/>
      	procrpc - Use external RPC server provided by module HMCCPRPCPROC. During first RPC
      	server start HMCCU will create a HMCCURPCPROC device for each interface confiugured
      	in attribute 'rpcinterface'<br/>
      	reconnect - Automatically reconnect to CCU when events timeout occurred.
      </li><br/>
      <li><b>ccuget {State | <u>Value</u>}</b><br/>
         Set read access method for CCU channel datapoints. Method 'State' is slower than
         'Value' because each request is sent to the device. With method 'Value' only CCU
         is queried. Default is 'Value'. Method for write access to datapoints is always
         'State'.
      </li><br/>
      <li><b>ccuGetVars &lt;interval&gt;[&lt;pattern&gt;]</b><br/>
      	Read CCU system variables periodically and update readings. If pattern is specified
      	only variables matching this expression are stored as readings.
      </li><br/>
      <li><b>ccuReqTimeout &lt;Seconds&gt;</b><br/>
      	Set timeout for CCU request. Default is 4 seconds. This timeout affects several
      	set and get commands, i.e. "set datapoint" or "set var". If a command runs into
      	a timeout FHEM will block for <i>Seconds</i>. To prevent blocking set flag 'nonBlocking'
      	in attribute <i>ccuflags</i>.
      </li><br/>
      <li><b>ccureadings {0 | <u>1</u>}</b><br/>
         Deprecated. Readings are written by default. To deactivate readings set flag noReadings
         in attribute ccuflags.
      </li><br/>
      <li><b>rpcinterfaces &lt;interface&gt;[,...]</b><br/>
   		Specify list of CCU RPC interfaces. HMCCU will register a RPC server for each interface.
   		Either interface BidCos-RF or HmIP-RF (HmIP only) is default. Valid interfaces are:<br/><br/>
   		<ul>
   		<li>BidCos-Wired (Port 2000)</li>
   		<li>BidCos-RF (Port 2001)</li>
   		<li>Homegear (Port 2003)</li>
   		<li>HmIP-RF (Port 2010)</li>
   		<li>HVL (Port 7000)</li>
   		<li>CUxD (Port 8701)</li>
   		<li>VirtualDevice (Port 9292)</li>
   		</ul>
      </li><br/>
      <li><b>rpcinterval &lt;Seconds&gt;</b><br/>
         Specifiy how often RPC queue is read. Default is 5 seconds. Only relevant if internal
         RPC server is used (deprecated).
      </li><br/>
	   <li><b>rpcPingCCU &lt;interval&gt;</b><br/>
	   	Send RPC ping request to CCU every <i>interval</i> seconds. If <i>interval</i> is 0
	   	ping requests are disabled. Default value is 300 seconds. If attribut ccuflags is set
	   	to logPong a log message with level 3 is created when receiving a pong event.
	   </li><br/>
      <li><b>rpcport &lt;value[,...]&gt;</b><br/>
         Deprecated, use attribute 'rpcinterfaces' instead. Specify list of RPC ports on CCU.
         Either port 2001 or 2010 (HmIP only) is default. Valid RPC ports are:<br/><br/>
         <ul>
         <li>2000 = Wired components</li>
         <li>2001 = BidCos-RF (wireless 868 MHz components with BidCos protocol)</li>
         <li>2003 = Homegear (experimental)</li>
         <li>2010 = HM-IP (wireless 868 MHz components with IPv6 protocol)</li>
         <li>7000 = HVL (Homematic Virtual Layer devices)</li>
         <li>8701 = CUxD (only supported with external RPC server HMCCURPC)</li>
         <li>9292 = CCU group devices (especially heating groups)</li>
         </ul>
      </li><br/>
      <li><b>rpcqueue &lt;queue-file&gt;</b><br/>
         Specify name of RPC queue file. This parameter is only a prefix (including the
         pathname) for the queue files with extension .idx and .dat. Default is
         /tmp/ccuqueue. If FHEM is running on a SD card it's recommended that the queue
         files are placed on a RAM disk.
      </li><br/>
      <li><b>rpcserver {on | <u>off</u>}</b><br/>
         Specify if RPC server is automatically started on FHEM startup.
      </li><br/>
      <li><b>rpcserveraddr &lt;ip-or-name&gt;</b><br/>
      	Specify network interface by IP address or DNS name where RPC server should listen
      	on. By default HMCCU automatically detects the IP address. This attribute should be used
      	if the FHEM server has more than one network interface.
      </li><br/>
      <li><b>rpcserverport &lt;base-port&gt;</b><br/>
      	Specify base port for RPC server. The real listening port of an RPC server is
      	calculated by the formula: base-port + rpc-port + (10 * ccu-number). Default
      	value for <i>base-port</i> is 5400.<br/>
      	The value ccu-number is only relevant if more than one CCU is connected to FHEM.
      	Example: If <i>base-port</i> is 5000, protocol is BidCos (rpc-port 2001) and only
      	one CCU is connected the resulting RPC server port is 5000+2001+(10*0) = 7001.
      </li><br/>
      <li><b>substitute &lt;subst-rule&gt;:&lt;substext&gt;[,...]</b><br/>
         Define substitions for datapoint values. Syntax of <i>subst-rule</i> is<br/><br/>
         [[&lt;channelno.&gt;]&lt;datapoint&gt;[,...]!]&lt;{#n1-m1|regexp1}&gt;:&lt;text1&gt;[,...]
      </li><br/>
      <li><b>stripchar &lt;character&gt;</b><br/>
         Strip the specified character from variable or device name in set commands. This
         is useful if a variable should be set in CCU using the reading with trailing colon.
      </li>
   </ul>
</ul>

=end html
=cut

