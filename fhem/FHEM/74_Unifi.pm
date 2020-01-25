  ##############################################################################
# $Id: 74_Unifi.pm 19989 2019-08-12 18:25:21Z wuehler $

# CHANGED
##############################################################################
# V 2.0
#  - feature: 74_Unifi: add new set commands to block/unblock clients,
#                       enable/disable WLAN, new client-Reading essid
# V 2.1
#  - feature: 74_Unifi: add new set command to en-/disable Site Status-LEDs
# V 2.1.1
#  - bugfix:  74_Unifi: fixed blockClient
# V 2.1.2
#  - feature: 74_Unifi: new Readings for WLAN-states, fixed Warning
# V 2.1.3
#  - change:  74_Unifi: SSIDs-Readings and drop-downs use goodReadingName()
# V 2.1.4
#  - feature: 74_Unifi: added voucher-functions
# V 2.2
#  - feature: 74_Unifi: added set updateClien, encrypt user and password
# V 2.2.1
#  - feature: 74_Unifi: update VC-readings immediately when getting voucher
# V 2.2.2
#  - fixed:   74_Unifi: restart-typo in poe
# V 2.2.3
#  - fixed:   74_Unifi: Cookies for UnifiController 5.9.4
# V 2.2.4
#  - fixed:   74_Unifi: import encode_json for newest libs 
# V 3.0
#  - feature: 74_Unifi: new child-Module UnifiSwitch
# V 3.0.1
#  - feature: 74_Unifi: new reading UC_newClients for new clients 
#  - feature: 74_Unifi: block clients by mac-address 
# V 3.0.2
#  - fixed:   74_Unifi: Minor bugfix in notify-function
# V 3.0.3
#  - fixed:   74_Unifi: Minor loglevel-bugfix
# V 3.0.4
#  - fixed:   74_Unifi: Readingname -UC_newClients with leading -
#  - changed: 74_Unifi: Reading(name) for Utilization of APs with UC V 5.7/8.x
# V 3.0.5
#  - feature: 74_Unifi: Added readings for wan_ip and results of speedtest
# V 3.1.0
#  - changed: 74_Unifi: removed deprecated UnifiSwitch-functions!
# V 3.2.0
#  - changed: 74_Unifi: removed UCv3 support
# V 3.2.1
#  - feature: 74_Unifi: new attribute customClientReadings
# V 3.2.2
#  - feature: 74_Unifi: textField-long support for customClientReadings
# V 3.2.3
#  - feature: 74_Unifi: new customClientReading _f_last_seen_duration
# V 3.2.4
#  - feature: 74_Unifi: new attribute customClientNames
# V 3.2.5
#  - fixed:   74_Unifi: fixed createVoucher and (un-)blockClient for UC-V5.10
# V 3.2.6
#  - fixed:   74_Unifi: fixed locate/restartAP and disconnectClient for UC-V5.10
# V 3.2.7
#  - fixed:   74_Unifi: fixed reading-Update for disconnected clients
# V 3.2.8
#  - feature: 74_Unifi: read the client insights to update blocked reading 
# V 3.3.0
#  - feature: 74_Unifi: supports new module UnifiClient
#  - feature: 74_Unifi: read usergroups at define-module, new setter "refreshUsergroups" 
#  - feature: 74_Unifi: new setter "removeClientReadings" 
#  - feature: 74_Unifi: persist disconnected clients and rebuild them after fhem-restart
# V 3.3.1
#  - fixed:   74_Unifi: fixed Loglevel
# V 3.3.2
#  - fixed:   74_Unifi: fixed restore clients at fhem restart
# V 3.3.3
#  - fixed:   74_Unifi: fixed (un)blockClient for UC Version 5.10.24
# V 3.3.4
#  - fixed:   74_Unifi: fixed AP-Readingnames (use makeReadingName())
# V 3.4.0
#  - feature: 74_Unifi: new setter to start RF-Scan


package main;
my $version="3.4.0";
# Default f�r clientReadings setzen. Die Readings waren der Standard vor Einf�hrung des Attributes customClientReadings.
# Eine �nderung hat Auswirkungen auf (alte) Moduldefinitionen ohne dieses Attribut.
my $defaultClientReadings=".:^accesspoint|^essid|^hostname|^last_seen|^snr|^uptime"; #ist wegen snr vs rssi nur halb korrekt, wird aber auch nicht wirklich verwendet ;-)
my $customClientName="";
use strict;
use warnings;
use HttpUtils;
use POSIX;
use JSON qw(decode_json);
use JSON qw(encode_json);
##############################################################################}

###  Forward declarations ####################################################{
sub Unifi_Initialize($$);
sub Unifi_Define($$);
sub Unifi_Undef($$);
sub Unifi_Notify($$);
sub Unifi_Set($@);
sub Unifi_Get($@);
sub Unifi_Attr(@);
sub Unifi_Write($@);
sub Unifi_DoUpdate($@);
sub Unifi_Login_Send($);
sub Unifi_Login_Receive($);
sub Unifi_GetClients_Send($);
sub Unifi_GetClients_Receive($);
sub Unifi_GetClientInsights_Send($);
sub Unifi_GetClientInsights_Receive($);
sub Unifi_GetWlans_Send($);
sub Unifi_GetWlans_Receive($);
sub Unifi_GetHealth_Send($);
sub Unifi_GetHealth_Receive($);
sub Unifi_GetSysinfo_Send($);
sub Unifi_GetSysinfo_Receive($);
sub Unifi_GetWlanGroups_Send($);
sub Unifi_GetWlanGroups_Receive($);
sub Unifi_GetUnarchivedAlerts_Send($);
sub Unifi_GetUnarchivedAlerts_Receive($);
sub Unifi_GetEvents_Send($);
sub Unifi_GetEvents_Receive($);
sub Unifi_GetAccesspoints_Send($);
sub Unifi_GetAccesspoints_Receive($);
sub Unifi_ProcessUpdate($);
sub Unifi_SetClientReadings($$);
sub Unifi_SetHealthReadings($);
sub Unifi_SetAccesspointReadings($);
sub Unifi_SetWlanReadings($);
sub Unifi_DisconnectClient_Send($@);
sub Unifi_DisconnectClient_Receive($);
sub Unifi_ApCmd_Send($$@);
sub Unifi_DeviceRestJson_Send($$$);
sub Unifi_UserRestJson_Send($$$);
sub Unifi_DeviceCmd_Receive($);
sub Unifi_UsergroupRestJson_Send($);
sub Unifi_UsergroupRestJson_Receive($);
sub Unifi_ArchiveAlerts_Send($);
sub Unifi_Cmd_Receive($);
sub Unifi_ClientNames($@);
sub Unifi_ApNames($@);
sub Unifi_SSIDs($@);
sub Unifi_BlockClient_Send($$);
sub Unifi_BlockClient_Receive($);
sub Unifi_UnblockClient_Send($$);
sub Unifi_UnblockClient_Receive($);
sub Unifi_UpdateClient_Send($$);
sub Unifi_UpdateClient_Receive($);
sub Unifi_SwitchSiteLEDs_Send($$);
sub Unifi_SwitchSiteLEDs_Receive($);
sub Unifi_WlanconfRest_Send($$@);
sub Unifi_WlanconfRest_Receive($);
sub Unifi_GetVoucherList_Send($);
sub Unifi_GetVoucherList_Receive($);
sub Unifi_CreateVoucher_Send($%);
sub Unifi_CreateVoucher_Receive($);
sub Unifi_SetVoucherReadings($);
sub Unifi_initVoucherCache($);
sub Unifi_isUCversionHigherThan($$);
sub Unifi_initCustomClientReadings($);
sub Unifi_getNextVoucherForNote($$);
sub Unifi_NextUpdateFn($$);
sub Unifi_ReceiveFailure($$);
sub Unifi_CONNECTED($@);
sub Unifi_encrypt($);
sub Unifi_encrypt($);
sub Unifi_Whoami();
sub Unifi_Whowasi();
##############################################################################}

sub Unifi_Initialize($$) { 
    my ($hash) = @_; 
    $hash->{DefFn}     = "Unifi_Define";
    $hash->{WriteFn}   = "Unifi_Write";
    $hash->{UndefFn}   = "Unifi_Undef";
    $hash->{SetFn}     = "Unifi_Set";
    $hash->{GetFn}     = "Unifi_Get";
    $hash->{AttrFn}    = 'Unifi_Attr';
    $hash->{NotifyFn}  = "Unifi_Notify";
    $hash->{AttrList}  = "disable:1,0 "
                         ."devAlias "
                         ."ignoreWiredClients:1,0 "
                         ."ignoreWirelessClients:1,0 "
                         ."httpLoglevel:1,2,3,4,5 "
                         ."eventPeriod "
                         ."voucherCache "
                         ."customClientReadings:textField-long "
						 ."customClientNames "
	#					 ."readClientInsights "
                         .$readingFnAttributes;
                         
	$hash->{Clients} = "UnifiSwitch:UnifiClient";
  $hash->{MatchList} = { 	"1:UnifiSwitch"      => "^UnifiSwitch",
							"2:UnifiClient"      => "^UnifiClient"};
}
###############################################################################

sub Unifi_Define($$) {
    my ($hash, $def) = @_;
    my @a = split("[ \t][ \t]*", $def);
    return "Wrong syntax: use define <name> Unifi <ip> <port> <username> <password> [<interval> [<siteID>]]" if(int(@a) < 6);
    return "Wrong syntax: <port> is not a number!"                           if(!looks_like_number($a[3]));
    return "Wrong syntax: <interval> is not a number!"                       if($a[6] && !looks_like_number($a[6]));
    return "Wrong syntax: <interval> too small, must be at least 5"          if($a[6] && $a[6] < 5);
    
    my $name = $a[0];
    %$hash = (   %$hash,
        NOTIFYDEV => 'global',
        unifi     => { 
            CONNECTED   => 0,
            eventPeriod => int(AttrVal($name,"eventPeriod",24)),
            interval    => $a[6] || 30,
            url         => "https://".$a[2].(($a[3] == 443) ? '' : ':'.$a[3]).'/api/s/'.(($a[7]) ? $a[7] : 'default').'/',
        },
    );
    $hash->{httpParams} = {
        hash            => $hash,
        timeout         => 5,
        method          => "POST",
        noshutdown      => 0,
        ignoreredirects => 1,
        loglevel        => AttrVal($name,"httpLoglevel",5),
        sslargs         => { SSL_verify_mode => 0 },
    };
    
    $hash->{VERSION}=$version;
    $hash->{UC_VERSION}="unknown";
    my $username = Unifi_encrypt($a[4]);
    my $password = Unifi_encrypt($a[5]);    
    $hash->{helper}{username} = $username;
    $hash->{helper}{password} = $password;
    my $define="$a[2] $a[3] $username $password";
    $define.=" $a[6]" if($a[6]);
    $define.=" $a[7]" if($a[7]);
    $hash->{DEF} = $define;
	
    Log3 $name, 5, "$name: Defined with url:$hash->{unifi}->{url}, interval:$hash->{unifi}->{interval}";
    return undef;
}
###############################################################################

sub Unifi_Undef($$) {
    my ($hash,$arg) = @_;
    
    RemoveInternalTimer($hash);
    return undef;
}
###############################################################################

sub Unifi_Notify($$) {
    my ($hash,$dev) = @_;
    my ($name,$self) = ($hash->{NAME},Unifi_Whoami());
    Log3 $name, 5, "$name ($self) - executed.";

    return if($dev->{NAME} ne "global");
	
    return if(!grep(m/^DEFINED $name|MODIFIED $name|INITIALIZED|REREADCFG$/, @{$dev->{CHANGED}}));

	#restore clients
	for my $readingName (keys %{$hash->{READINGS}}) {
		Log3 $name, 5, "$name ($self) - checking 1 $readingName";
		if($readingName =~ m/\..*_mac$/){
			Log3 $name, 5, "$name ($self) - found 1 $readingName";
			my $mac=ReadingsVal($name,$readingName,"");		
			$hash->{restoreClients}->{$mac} = 1;
		}
	}
	
    if(AttrVal($name, "disable", 0)) {
        Log3 $name, 5, "$name ($self) - executed. - Device '$name' is disabled, do nothing...";
        Unifi_CONNECTED($hash,'disabled');
    } else {
        Log3 $name, 5, "$name ($self) - executed. - Remove all Timers & Call DoUpdate...";
        Unifi_CONNECTED($hash,'initialized');
        Unifi_DoUpdate($hash);
    }
	
	if($dev->{NAME} eq "global"){ #INITIALIZED|REREADCFG
		$hash->{unifi}->{customClientReadings}->{attr_value} = AttrVal($name,"customClientReadings",$defaultClientReadings); 
		Unifi_initCustomClientReadings($hash);
		
		
		# TODO: der folgende Block kann Ende 2019 entfernt werden. Es ist der alte Restore-Mechanismus
		# Dieser wurde ersetzt durch de restore von mac-Adressen und anschlie�endem updateClient in doUpdate()
		#for my $readingName (keys %{$hash->{READINGS}}) {
		#	#Log3 $name, 1, "$name ($self) - checking 1 $readingName";
		#	if($readingName =~ m/\..*_id$/){
		#		#Log3 $name, 1, "$name ($self) - found 1 $readingName";
		#		my $readingValue=ReadingsVal($name,$readingName,"");
		#		if($readingValue =~ m/^[a-fA-F0-9]*$/g){
		#			my $clientName=substr($readingName,1,index($readingName,"_id")-1);
		#			$hash->{clients}->{$readingValue}->{name} = $clientName;
		#			Log3 $name, 5, "$name ($self) - restored client $clientName with ID $readingValue";
		#		}
		#	}
		#}
		#for my $clientID (keys %{$hash->{clients}}) {
		#	my $clientName=$hash->{clients}->{$clientID}->{name}."_";
		#	# TODO: Pr�fen, ob es f�r $clientName ein UnifiClient-Devices gibt und die Werte aus den Readings des UnifiClients wiederherstellen.
		#	for my $readingName (keys %{$hash->{READINGS}}) {
		#		#Log3 $name, 1, "$name ($self) - checking 2 $readingName for $clientName";
		#		if($readingName =~ m/^$clientName.*/){
		#			#Log3 $name, 1, "$name ($self) - found 2 $readingName";
		#			my $readingValue=ReadingsVal($name,$readingName,"");
		#			my $readingName=substr($readingName,length($clientName));
		#			$hash->{clients}->{$clientID}->{$readingName} = $readingValue;
		#			Log3 $name, 5, "$name ($self) - restored internal $readingName = $readingValue for client $clientName";
		#		}
		#	}
		#}
	}
	
    return undef;
}
###############################################################################

sub Unifi_Set($@) {
    my ($hash,@a) = @_;
    return "\"set $hash->{NAME}\" needs at least an argument" if ( @a < 2 );
    # setVal4 enth�lt nur erstes Wort der note f�r voucher!!! 
    # in Doku aufgenommen, dass genau drei Leerzeichen enthalten sein m�ssen, also note keine Leerzeichen enthalten kann
    my ($name,$setName,$setVal,$setVal2,$setVal3,$setVal4) = @a;

    Log3 $name, 5, "$name: set called with $setName " . ($setVal ? $setVal : "") if ($setName ne "?");

    if(Unifi_CONNECTED($hash) eq 'disabled' && $setName !~ /clear/) {
        return "Unknown argument $setName, choose one of clear:all,readings,clientData,voucherCache";
        Log3 $name, 5, "$name: set called with $setName but device is disabled!" if($setName ne "?");
        return undef;
    }
    my $blockedClientNames ="";
    my $unblockedClientNames ="";
    my $connectedClientNames ="";
    my $disconnectedClientNames ="";
	my $clientName="";
	for my $clientID (keys %{$hash->{clients}}) {
		my $clientName=Unifi_ClientNames($hash,$clientID,'makeAlias');
		if(defined $hash->{clients}->{$clientID}->{blocked} && $hash->{clients}->{$clientID}->{blocked} eq JSON::true){
			$blockedClientNames.=$clientName.',';
		}else{
			$unblockedClientNames.=$clientName.',';	  
		}
		if(defined $hash->{unifi}->{connectedClients}->{$clientID}){
			$connectedClientNames.=$clientName.',';
		}else{
			$disconnectedClientNames.=$clientName.',';	  
		}
	}
	$blockedClientNames =~ s/.$//;
	$unblockedClientNames =~ s/.$//;
	$connectedClientNames =~ s/.$//;
	$disconnectedClientNames =~ s/.$//;
		
    #my $clientNames = Unifi_ClientNames($hash);
    my $apNames = Unifi_ApNames($hash); # TODO: $apNames in $deviceNames umbenennen
    my $SSIDs = Unifi_SSIDs($hash);
	
	my $aps = '';
	for my $apID (keys %{$hash->{accespoints}}) {
		my $apName=Unifi_ApNames($hash,$apID,'makeName');
		my $essid_Reading=ReadingsVal($name, '-AP_'.$apName.'_essid', undef);
		my $has_essid=0;
		$has_essid=1 if(defined $essid_Reading && $essid_Reading ne 'none');
		if ($has_essid){
			$aps .= $apName.',';
		}
	}
	$aps =~ s/.$//;
	
    if($setName !~ /archiveAlerts|restartAP|setLocateAP|unsetLocateAP|startRFScan|disconnectClient|update|updateClient|clear|blockClient|unblockClient|enableWLAN|disableWLAN|switchSiteLEDs|createVoucher|removeClientReadings|refreshUsergroups/) {
        return "Unknown argument $setName, choose one of update:noArg "
               ."clear:all,readings,clientData,allData,voucherCache "
               .((defined $hash->{alerts_unarchived}[0] && scalar @{$hash->{alerts_unarchived}}) ? "archiveAlerts:noArg " : "")
               .(($apNames && Unifi_CONNECTED($hash)) ? "restartAP:all,$apNames setLocateAP:all,$apNames unsetLocateAP:all,$apNames startRFScan:$aps " : "")
               .(($connectedClientNames && Unifi_CONNECTED($hash)) ? "disconnectClient:all,$connectedClientNames " : "")
               .(($disconnectedClientNames && Unifi_CONNECTED($hash)) ? "removeClientReadings:$disconnectedClientNames " : "")
               .(($unblockedClientNames && Unifi_CONNECTED($hash)) ? "blockClient:$unblockedClientNames " : "")
               .(($blockedClientNames && Unifi_CONNECTED($hash)) ? "unblockClient:$blockedClientNames " : "")
               ."createVoucher enableWLAN:$SSIDs disableWLAN:$SSIDs "
               ."switchSiteLEDs:on,off updateClient refreshUsergroups:noArg";
    }
    else {
        Log3 $name, 4, "$name: set $setName";
        
        if (Unifi_CONNECTED($hash)) {
            if ($setName eq 'disconnectClient') {
                if ($setVal && $setVal ne 'all') {
                    $setVal = Unifi_ClientNames($hash,$setVal,'makeID');
                    if (defined $hash->{clients}->{$setVal}) {
                        Unifi_DisconnectClient_Send($hash,$setVal);
                    }
                    else {
                        return "$hash->{NAME}: Unknown client '$setVal' in command '$setName', choose one of: all,$connectedClientNames";
                    }
                }
                elsif (!$setVal || $setVal eq 'all') {
                    Unifi_DisconnectClient_Send($hash,keys(%{$hash->{clients}}));
                }
            }
            elsif ($setName eq 'blockClient') {
                my $id = Unifi_ClientNames($hash,$setVal,'makeID');
                my $mac = "x";
                if (defined $hash->{clients}->{$id}) {
                    $mac = $hash->{clients}->{$id}->{mac};
                }elsif($setVal =~ m/^[a-fA-F0-9:]{17}$/g){
                    $mac = $setVal;
                }
                if($mac ne "x"){
                    Unifi_BlockClient_Send($hash,$mac);
					$hash->{clients}->{$id}->{blocked}=JSON::true; # eigentlich vorauseilender Gehorsam, aber leider kommt beim blockClient_Receive keine ID zur�ck um dort zu setzen.
					delete $hash->{unifi}->{connectedClients}->{$id};
                }else {
                    return "$hash->{NAME}: Unknown client '$setVal' in command '$setName', use mac or choose one of: $unblockedClientNames";
                }
            }
            elsif ($setName eq 'unblockClient') {
                my $id = Unifi_ClientNames($hash,$setVal,'makeID');
                my $mac = "x";
                if (defined $hash->{clients}->{$id}) {
                    $mac = $hash->{clients}->{$id}->{mac};
                }elsif($setVal =~ m/^[a-fA-F0-9:]{17}$/g){
                    $mac = $setVal;
                }
                if($mac ne "x"){
                    Unifi_UnblockClient_Send($hash,$mac);
					$hash->{clients}->{$id}->{blocked}=JSON::false; # eigentlich vorauseilender Gehorsam, aber leider kommt beim unblockClient_Receive keine ID zur�ck um dort zu setzen.           
                }else {
                    return "$hash->{NAME}: Unknown client '$setVal' in command '$setName', use mac or choose one of: $blockedClientNames";
                }
            }
            elsif ($setName eq 'switchSiteLEDs') {
                my $state="true";
                if ($setVal && $setVal eq 'off') {
                    $state="false";
                }
                Unifi_SwitchSiteLEDs_Send($hash,$state);
            }
            elsif ($setName eq 'disableWLAN') {
                my $wlanid = Unifi_SSIDs($hash,$setVal,'makeID');
                if (defined $hash->{wlans}->{$wlanid}) {
                    my $wlanconf = $hash->{wlans}->{$wlanid};
                    $wlanconf->{enabled}=JSON::false;
                    Unifi_WlanconfRest_Send($hash,$wlanid,$wlanconf);
                }
                else {
                    return "$hash->{NAME}: Unknown SSID '$setVal' in command '$setName', choose one of: all,$SSIDs";
                }
            }
            elsif ($setName eq 'enableWLAN') {
                my $wlanid = Unifi_SSIDs($hash,$setVal,'makeID');
                if (defined $hash->{wlans}->{$wlanid}) {
                    my $wlanconf = $hash->{wlans}->{$wlanid};
                    $wlanconf->{enabled}=JSON::true;
                    Unifi_WlanconfRest_Send($hash,$wlanid,$wlanconf);
                }
                else {
                    return "$hash->{NAME}: Unknown SSID '$setVal' in command '$setName', choose one of: all,$SSIDs";
                }
            }
            elsif ($setName eq 'updateClient') {
                return "enter mac of client" if( ! defined $setVal);
                Unifi_UpdateClient_Send($hash,$setVal);
            }
            elsif ($setName eq 'archiveAlerts' && defined $hash->{alerts_unarchived}[0]) {
                Unifi_ArchiveAlerts_Send($hash);
                undef @{$hash->{alerts_unarchived}};
            }
            elsif ($setName eq 'restartAP') {
                if ($setVal && $setVal ne 'all') {
                    $setVal = Unifi_ApNames($hash,$setVal,'makeID');
                    if (defined $hash->{accespoints}->{$setVal}) {
                        Unifi_ApCmd_Send($hash,'restart',$setVal);
                    }
                    else {
                        return "$hash->{NAME}: Unknown accesspoint '$setVal' in command '$setName', choose one of: all,$apNames";
                    }
                }
                elsif (!$setVal || $setVal eq 'all') {
                    Unifi_ApCmd_Send($hash,'restart',keys(%{$hash->{accespoints}}));
                }
            }
            elsif ($setName eq 'setLocateAP') {
                if ($setVal && $setVal ne 'all') {
                    $setVal = Unifi_ApNames($hash,$setVal,'makeID');
                    if (defined $hash->{accespoints}->{$setVal}) {
                        Unifi_ApCmd_Send($hash,'set-locate',$setVal);
                    }
                    else {
                        return "$hash->{NAME}: Unknown accesspoint '$setVal' in command '$setName', choose one of: all,$apNames";
                    }
                }
                elsif (!$setVal || $setVal eq 'all') {
                    Unifi_ApCmd_Send($hash,'set-locate',keys(%{$hash->{accespoints}}));
                }
            }
            elsif ($setName eq 'unsetLocateAP') {
                if ($setVal && $setVal ne 'all') {
                    $setVal = Unifi_ApNames($hash,$setVal,'makeID');
                    if (defined $hash->{accespoints}->{$setVal}) {
                        Unifi_ApCmd_Send($hash,'unset-locate',$setVal);
                    }
                    else {
                        return "$hash->{NAME}: Unknown accesspoint '$setVal' in command '$setName', choose one of: all,$apNames";
                    }
                }
                elsif (!$setVal || $setVal eq 'all') {
                    Unifi_ApCmd_Send($hash,'unset-locate',keys(%{$hash->{accespoints}}));
                }
            }
            elsif ($setName eq 'startRFScan') {
				$setVal = Unifi_ApNames($hash,$setVal,'makeID');
				if (defined $hash->{accespoints}->{$setVal}) {
					Unifi_ApCmd_Send($hash,'spectrum-scan',$setVal);
				}
				else {
					return "$hash->{NAME}: Unknown accesspoint '$setVal' in command '$setName', choose one of: $aps";
				}
            }
            elsif ($setName eq 'removeClientReadings') {
				if($setVal && $setVal ne ""){
					my $id = Unifi_ClientNames($hash,$setVal,'makeID');
					if(defined $hash->{clients}->{$id}){
						readingsDelete($hash, $setVal);
						my $readingspec= '^' . $setVal . '_.*$';
						foreach my $reading (grep { /$readingspec/ }
										keys %{$hash->{READINGS}}) {
							readingsDelete($hash, $reading);
						}
						delete $hash->{clients}->{$id};
					}else{
                        return "$hash->{NAME}: Unknown clientName '$setVal' in command '$setName', choose one of: $disconnectedClientNames";
					}
				}else{
					return "$hash->{NAME}: No clientName in command '$setName', choose one of: $disconnectedClientNames";
				}
            }
            elsif ($setName eq 'createVoucher') {
                if (!looks_like_number($setVal) || int($setVal) < 1 || 
                    !looks_like_number($setVal2) || int($setVal2) < 1 || 
                    !looks_like_number($setVal3) || int($setVal3) < 1 || 
                    $setVal4 eq "") {
                    return "$hash->{NAME} $setName: First three arguments (expire, n, quota) must be numeric. Forth argument is note of voucher."
                }
                if ($setVal4 =~ /,/) {
                    return "$hash->{NAME} $setName: Note of voucher has invalid character (,)."
                }
                my %params=("expire"=>$setVal,"n"=>$setVal2,"quota"=>$setVal3,"note"=>$setVal4);
                Unifi_CreateVoucher_Send($hash, %params);
            }
            elsif ($setName eq 'refreshUCversion') {
                Unifi_GetSysinfo_Send($hash);
			}
            elsif ($setName eq 'refreshUsergroups') {
				Unifi_UsergroupRestJson_Send($hash);
			}
        } 
        if ($setName eq 'update') {
            RemoveInternalTimer($hash);
            Unifi_DoUpdate($hash,1);
        } 
        elsif ($setName eq 'clear') {
            if ($setVal eq 'readings' || $setVal eq 'all') {
                for (keys %{$hash->{READINGS}}) {
                    delete $hash->{READINGS}->{$_} if($_ ne 'state');
                }
            }
            if ($setVal eq 'clientData') {
                %{$hash->{clients}} = ();
            }
            if ($setVal eq 'allData' || $setVal eq 'all') {
                %{$hash->{clients}} = ();
                %{$hash->{wlans}} = ();
                %{$hash->{wlan_health}} = ();
                %{$hash->{accespoints}} = ();
                # %{$hash->{events}} = ();
                %{$hash->{wlangroups}} = ();
                # %{$hash->{alerts_unarchived}} = ();
            }
            if ($setVal eq 'voucherCache' || $setVal eq 'all') {
                my $cache_attr_value=$hash->{hotspot}->{voucherCache}->{attr_value};
                %{$hash->{hotspot}->{voucherCache}} = ();
                $hash->{hotspot}->{voucherCache}->{attr_value} = $cache_attr_value;
                Unifi_initVoucherCache($hash);
            }
        }
    }
    return undef;
}
###############################################################################

sub Unifi_Get($@) {
    my ($hash,@a) = @_;
	return "\"get $hash->{NAME}\" needs at least one argument" if ( @a < 2 );
    my ($name,$getName,$getVal) = @a;
    if (defined $getVal){
        Log3 $name, 5, "$name: get called with $getName $getVal." ;
    }else{
        Log3 $name, 5, "$name: get called with $getName.";
    }
    
    my %voucherNotesHash= ();
    my $voucherNote = '';
    if(defined $hash->{hotspot}->{vouchers}[0]){
        for my $voucher (@{$hash->{hotspot}->{vouchers}}) {
            if(defined $voucher->{note} && $voucher->{note} =~ /^((?!,).)*$/ && $voucher->{note} ne ""){
                $voucherNote = $voucher->{note};
                $voucherNote =~ s/( )/&nbsp;/og;
                $voucherNotesHash{$voucherNote}=$voucherNote;
            }else{
                Log3 $name, 4, "$name Info: vouchers without note or containing comma(,) in note or with empty note are ignored in drop-downs.";
            }
        }
    }
    my $voucherNotes=join(",", keys %voucherNotesHash);
    
    my $clientNames = Unifi_ClientNames($hash);
    
    if($getName !~ /events|clientData|unarchivedAlerts|voucherList|voucher|showAccount/) {
        return "Unknown argument $getName, choose one of "
               .((defined $hash->{events}[0] && scalar @{$hash->{events}}) ? "events:noArg " : "")
               .((defined $hash->{alerts_unarchived}[0] && scalar @{$hash->{alerts_unarchived}}) ? "unarchivedAlerts:noArg " : "")
               .(($clientNames) ? "clientData:all,$clientNames " : "")
               ."voucherList:all,$voucherNotes voucher:$voucherNotes showAccount";
    }
    elsif ($getName eq 'unarchivedAlerts' && defined $hash->{alerts_unarchived}[0] && scalar @{$hash->{alerts_unarchived}}) {
        my $alerts = "====================================================\n";
        for my $alert (@{$hash->{alerts_unarchived}}) {
            for (sort keys %{$alert}) {
                if ($_ !~ /^(archived|_id|handled_admin_id|site_id|datetime|handled_time)$/) {
                    $alert->{$_} = strftime "%Y-%m-%d %H:%M:%S",localtime($alert->{$_} / 1000) if($_ eq 'time');
                    $alerts .= "$_ = ".((defined $alert->{$_}) ? $alert->{$_} : '')."\n";
                }
            }
            $alerts .= "====================================================\n";
        }
        return $alerts;
    }
    elsif ($getName eq 'events' && defined $hash->{events}[0] && scalar @{$hash->{events}}) {
        my $events = "==================================================================\n";
        for my $event (@{$hash->{events}}) {
            for (sort keys %{$event}) {
                if ($_ !~ /^(_id|site_id|subsystem|datetime|is_admin)$/) {
                    $event->{$_} = strftime "%Y-%m-%d %H:%M:%S",localtime($event->{$_} / 1000) if($_ eq 'time');
                    $events .= "$_ = ".((defined $event->{$_}) ? $event->{$_} : '')."\n";
                }
            }
            $events .= "==================================================================\n";
        }
        return $events;
    }
    elsif ($getName eq 'clientData' && $clientNames) {
        my $clientData = '';
        if ($getVal && $getVal ne 'all') {
            $getVal = Unifi_ClientNames($hash,$getVal,'makeID');
        } 
        if (!$getVal || $getVal eq 'all') {
            $clientData .= "======================================\n";
            for my $client (sort keys %{$hash->{clients}}) {
                for (sort keys %{$hash->{clients}->{$client}}) {
                    $clientData .= "$_ = ".((defined($hash->{clients}->{$client}->{$_})) ? $hash->{clients}->{$client}->{$_} : '')."\n";
                }
                $clientData .= "======================================\n";
            }
            return $clientData;
        } 
        elsif(defined($hash->{clients}->{$getVal})) {
            $clientData .= "======================================\n";
            for (sort keys %{$hash->{clients}->{$getVal}}) {
                $clientData .= "$_ = ".((defined($hash->{clients}->{$getVal}->{$_})) ? $hash->{clients}->{$getVal}->{$_} : '')."\n";
            }
            $clientData .= "======================================\n";
            return $clientData;
        } 
        else {
            return "$hash->{NAME}: Unknown client '$getVal' in command '$getName', choose one of: all,$clientNames";
        }
    }
    elsif ($getName eq 'voucherList' && defined $hash->{hotspot}->{vouchers}[0]) {
        my $anzahl=0;
        my $vouchers = "==================================================================\n";
        for my $voucher (@{$hash->{hotspot}->{vouchers}}) {
            my $note= '';
            if(defined $voucher->{note}){
                $note=$voucher->{note};
            }
            my $gv=$getVal;
            $note =~ tr/a-zA-Z�������_0-9.,//cd;
            $gv =~ tr/a-zA-Z�������_0-9.,//cd;
     
            if($gv eq 'all' || ( ($gv =~ /^$note/) && $note ne '')){
                for (sort keys %{$voucher}) {
                    if ($_ !~ /^(_id|admin_name|for_hotspot|qos_overwrite|site_id|create_time)$/) {
                        $vouchers .= "$_ = ".((defined $voucher->{$_}) ? $voucher->{$_} : '')."\n";
                    }
                }
                if(defined $hash->{hotspot}->{voucherCache}->{$note}->{$voucher->{_id}}->{delivered_at}){
                        $vouchers .= "delivered_at = ".localtime($hash->{hotspot}->{voucherCache}->{$note}->{$voucher->{_id}}->{delivered_at})."\n";
                }
                $vouchers .= "==================================================================\n";
                $anzahl+=1;
            }
        }
        $vouchers .= "Count: ".$anzahl."\n";
        return $vouchers;
    }
    elsif ($getName eq 'voucher' && defined $hash->{hotspot}->{vouchers}[0]) {
        my $returnedVoucher = Unifi_getNextVoucherForNote($hash,$getVal);
        if ($returnedVoucher eq ""){
            return "No voucher with note: $getVal!";
        }
        my $returnedVoucherCode = "";
        if(defined $returnedVoucher->{_id}){
            $returnedVoucherCode = $returnedVoucher->{code};
            if (defined $hash->{hotspot}->{voucherCache}->{$getVal}->{setCmd}){
              $hash->{hotspot}->{voucherCache}->{$getVal}->{$returnedVoucher->{_id}}->{delivered_at} = time();
              readingsSingleUpdate($hash,"-VC_".$getVal,Unifi_getNextVoucherForNote($hash,$getVal)->{code},1);
            }
        }
        return $returnedVoucherCode;
    }
    elsif( $getName eq 'showAccount' ) {
      my $user = $hash->{helper}{username};
      my $password = $hash->{helper}{password};

      return 'no user set' if( !$user );
      return 'no password set' if( !$password );

      $user = Unifi_decrypt( $user );
      $password = Unifi_decrypt( $password );

      return "user: $user\npassword: $password";
    }
    return undef;
}
###############################################################################

sub Unifi_Attr(@) {
    my ($cmd,$name,$attr_name,$attr_value) = @_;
    my $hash = $defs{$name};
    
    if($cmd eq "set") {
        if($attr_name eq "disable") {
            if($attr_value == 1) {
                Unifi_CONNECTED($hash,'disabled');
            }
            elsif($attr_value == 0 && Unifi_CONNECTED($hash) eq "disabled") {
                Unifi_CONNECTED($hash,'initialized');
                Unifi_DoUpdate($hash);
            }
        }
        elsif($attr_name eq "devAlias") {
            if (!$attr_value) {
                CommandDeleteAttr(undef, $name.' '.$attr_name);
                return 1;
            }
            elsif ($attr_value !~ /^([\w\.\-]+:[\w\.\-]+\s?)+$/) {
                return "$name: Value \"$attr_value\" is not allowed for devAlias!\n"
                       ."Must be \"<ID>:<ALIAS> <ID2>:<ALIAS2>\", e.g. 123abc:MyIphone\n"
                       ."Only these characters are allowed: [alphanumeric - _ .]";
            }
        }
        elsif($attr_name eq "httpLoglevel") {
            $hash->{httpParams}->{loglevel} = $attr_value;
        }
        elsif($attr_name eq "eventPeriod") {
            if (!looks_like_number($attr_value) || int($attr_value) < 1 || int($attr_value) > 168) {
                return "$name: Value \"$attr_value\" is not allowed.\n"
                       ."eventPeriod must be a number between 1 and 168."
            }
            $hash->{unifi}->{eventPeriod} = int($attr_value);
        }
        elsif($attr_name eq "voucherCache") {
            #ToDo: n�chste Zeile entfernen wenn in Unifi_initVoucherCache das L�schen alter Caches implementiert ist
            # So l�scht man die delivery_at der verbleibenden Caches mit
            # Ist aber ja nur ein kurzzeitiges Problem, da die delivery_at eh nach 2 Stunden entfernt werden, daher egal.
            $hash->{hotspot}->{voucherCache}=();
            $hash->{hotspot}->{voucherCache}->{attr_value} = $attr_value;
            return Unifi_initVoucherCache($hash);
        }
        elsif($attr_name eq "customClientReadings") {
            $hash->{unifi}->{customClientReadings} = ();
            $hash->{unifi}->{customClientReadings}->{attr_value} = $attr_value;
			Unifi_initCustomClientReadings($hash);
        }
        elsif($attr_name eq "customClientNames") {
            $hash->{unifi}->{customClientNames}->{attr_value} = $attr_value;
        } 
        #elsif($attr_name eq "readClientInsights") {
        #    if (!looks_like_number($attr_value) || int($attr_value) < 1 || int($attr_value) > 365) {
        #        return "$name: Value \"$attr_value\" is not allowed.\n"
        #               ."readClientInsights must be a number between 1 and 365."
        #    }
        #    $hash->{unifi}->{readClientInsights}->{attr_value} = $attr_value*24;
        #} 
    }
    elsif($cmd eq "del") {
        if($attr_name eq "disable" && Unifi_CONNECTED($hash) eq "disabled") {
            Unifi_CONNECTED($hash,'initialized');
            Unifi_DoUpdate($hash);
        }
        elsif($attr_name eq "httpLoglevel") {
            $hash->{httpParams}->{loglevel} = 5;
        }
        elsif($attr_name eq "eventPeriod") {
            $hash->{unifi}->{eventPeriod} = 24;
        }
        elsif($attr_name eq "voucherCache") {
            %{$hash->{hotspot}->{voucherCache}} = ();
        }
        elsif($attr_name eq "customClientReadings") {
            $hash->{unifi}->{customClientReadings} = ();
            $hash->{unifi}->{customClientReadings}->{attr_value} = $defaultClientReadings;
			Unifi_initCustomClientReadings($hash);
        }
        elsif($attr_name eq "customClientNames") {
            $hash->{unifi}->{customClientNames}->{attr_value} = $customClientName;
        }
        #elsif($attr_name eq "readClientInsights") {
        #    $hash->{unifi}->{readClientInsights} = undef;
        #} 
    }
    return undef;
}

###############################################################################
sub Unifi_Write($@){
	my ($hash, @args) = @_;
	my ($type, $id, $data)=@args;
	my ($name,$self) = ($hash->{NAME},Unifi_Whoami());
	Log3 $name, 4, "$name ($self) - executed with ".$type;
	if($type eq "Unifi_DeviceRestJson_Send"){
		Unifi_DeviceRestJson_Send($hash, $id, {port_overrides => $data });#id=ap_id
	}elsif($type eq "Unifi_ApJson_Send"){
		Unifi_ApJson_Send($hash, $data);
	}elsif($type eq "Unifi_BlockClient_Send"){
		Unifi_BlockClient_Send($hash, $id); # id=mac
	}elsif($type eq "Unifi_UnblockClient_Send"){
		Unifi_UnblockClient_Send($hash, $id); # id=mac
	}elsif($type eq "Unifi_UserRestJson_Send"){
		Unifi_UserRestJson_Send($hash, $id, $data); # id=_id
	}elsif($type eq "Unifi_UpdateClient_Send"){
		Unifi_UpdateClient_Send($hash, $id); # id=mac
	}
  
	return undef;
}
###############################################################################

sub Unifi_DoUpdate($@) {
    my ($hash,$manual) = @_;
    my ($name,$self) = ($hash->{NAME},Unifi_Whoami());
    Log3 $name, 5, "$name ($self) - executed.";
    
    if (Unifi_CONNECTED($hash) eq "disabled") {
        Log3 $name, 5, "$name ($self) - Device '$name' is disabled, End now...";
        return undef;
    }
    
    if (Unifi_CONNECTED($hash)) {
		# nach Neustart wird restoreClients in notify gef�llt. Muss beim ersten Update nach dem Login erledigt werden
		if (defined $hash->{restoreClients}){
			Log3 $name, 5, "$name ($self) - restore clients";
			for my $mac (keys %{$hash->{restoreClients}}) {
				Log3 $name, 5, "$name ($self) - restore mac $mac";
                Unifi_UpdateClient_Send($hash,$mac);			
			}
			delete $hash->{restoreClients};
		}
        $hash->{unifi}->{updateStartTime} = time();
        $hash->{updateDispatch} = {  # {updateDispatch}->{callFn}[callFnRef,'receiveFn',receiveFnRef]
            Unifi_GetClients_Send => [\&Unifi_GetClients_Send,'Unifi_GetClients_Receive',\&Unifi_GetClients_Receive],
            Unifi_GetClientInsights_Send => [\&Unifi_GetClientInsights_Send,'Unifi_GetClientInsights_Receive',\&Unifi_GetClientInsights_Receive],
			#Unifi_UsergroupRestJson_Send => [\&Unifi_UsergroupRestJson_Send,'Unifi_UsergroupRestJson_Receive',\&Unifi_UsergroupRestJson_Receive],
            Unifi_GetAccesspoints_Send => [\&Unifi_GetAccesspoints_Send,'Unifi_GetAccesspoints_Receive',\&Unifi_GetAccesspoints_Receive],
            Unifi_GetWlans_Send => [\&Unifi_GetWlans_Send,'Unifi_GetWlans_Receive',\&Unifi_GetWlans_Receive],
            Unifi_GetVoucherList_Send => [\&Unifi_GetVoucherList_Send,'Unifi_GetVoucherList_Receive',\&Unifi_GetVoucherList_Receive],
            Unifi_GetUnarchivedAlerts_Send => [\&Unifi_GetUnarchivedAlerts_Send,'Unifi_GetUnarchivedAlerts_Receive',\&Unifi_GetUnarchivedAlerts_Receive],
            Unifi_GetEvents_Send => [\&Unifi_GetEvents_Send,'Unifi_GetEvents_Receive',\&Unifi_GetEvents_Receive],
            # Unifi_GetWlanGroups_Send => [\&Unifi_GetWlanGroups_Send,'Unifi_GetWlanGroups_Receive',\&Unifi_GetWlanGroups_Receive],
            Unifi_GetHealth_Send => [\&Unifi_GetHealth_Send,'Unifi_GetHealth_Receive',\&Unifi_GetHealth_Receive],
            Unifi_ProcessUpdate   => [\&Unifi_ProcessUpdate,''],
        };
        Unifi_NextUpdateFn($hash,$self);
    }
    else {
        Unifi_CONNECTED($hash,'disconnected');
        Unifi_Login_Send($hash)
    }
    return undef;
}
###############################################################################

sub Unifi_Login_Send($) {
    my ($hash) = @_;
    my ($name,$self) = ($hash->{NAME},Unifi_Whoami());
    Log3 $name, 5, "$name ($self) - executed.";

    my ($loginurl,$logindata);
    my $user = $hash->{helper}{username};
    my $password = $hash->{helper}{password};
    $user = Unifi_decrypt( $user );
    $password = Unifi_decrypt( $password );
    ( $loginurl = $hash->{unifi}->{url} ) =~ s/api\/s.+/api\/login/;
    $logindata = '{"username":"'.$user.'", "password":"'.$password.'"}';
    
    HttpUtils_NonblockingGet( {
                 %{$hash->{httpParams}},
        url      => $loginurl,
        data     => $logindata,
        callback => \&Unifi_Login_Receive
    } );
    return undef;
}
sub Unifi_Login_Receive($) {
    my ($param, $err, $data) = @_;
    my ($name,$self,$hash) = ($param->{hash}->{NAME},Unifi_Whoami(),$param->{hash});
    Log3 $name, 5, "$name ($self) - executed.";
    
    if ($err ne "") {
        Log3 $name, 5, "$name ($self) - Error while requesting ".$param->{url}." - $err";
    }
    elsif ($data ne "" ) { 
        if ($param->{code} == 200 || $param->{code} == 400 || $param->{code} == 401 || $param->{code} == 200) {
            eval { $data = decode_json($data); 1; } or do { $data = { meta => {rc => 'error.decode_json', msg => $@} }; };
            
            if ($data->{meta}->{rc} eq "ok") { 
                Log3 $name, 5, "$name ($self) - state=ok";
                $hash->{httpParams}->{header} = '';
                for (split("\r\n",$param->{httpheader})) {
                    if(/^Set-Cookie/) {
                        s/Set-Cookie:\s(.*?);.*/Cookie: $1/;
                        $hash->{httpParams}->{header} .= 'Cookie: '.$1.';\r\n';
                    }
                }
                if($hash->{httpParams}->{header} ne '') {
                    $hash->{httpParams}->{header} =~ s/\\r\\n$//;
                    Log3 $name, 5, "$name ($self) - Login successfully!  $hash->{httpParams}->{header}";
                    Unifi_CONNECTED($hash,'connected');
					Unifi_GetSysinfo_Send($hash);
					Unifi_UsergroupRestJson_Send($hash);
					#Unifi_DoUpdate($hash);
                    InternalTimer(time()+$hash->{unifi}->{interval}, 'Unifi_DoUpdate', $hash, 0);
                    return undef;
                } else {
                    $hash->{httpParams}->{header} = undef;
                    Log3 $name, 5, "$name ($self) - Something went wrong, login seems ok but no cookies received.";
                }
            }
            else {
                if (defined($data->{meta}->{msg})) {
                    if ($data->{meta}->{msg} eq 'api.err.Invalid') {
                        Log3 $name, 1, "$name ($self) - Login Failed! Invalid username or password!"
                                       ." - state:'$data->{meta}->{rc}' - msg:'$data->{meta}->{msg}'";
                    } elsif ($data->{meta}->{msg} eq 'api.err.LoginRequired') {
                        Log3 $name, 1, "$name ($self) - Login Failed! - state:'$data->{meta}->{rc}' - msg:'$data->{meta}->{msg}' -"
                                       ." This error while login indicates that you use an unsupported UnifiController-version";
                    } else {
                        Log3 $name, 5, "$name ($self) - Login Failed! - state:'$data->{meta}->{rc}' - msg:'$data->{meta}->{msg}'";
                    }
                } else {
                    Log3 $name, 5, "$name ($self) - Login Failed (without msg)! - state:'$data->{meta}->{rc}'";
                }
                $hash->{httpParams}->{header} = undef;
            }
        } else {
            Log3 $name, 5, "$name ($self) - Failed with HTTP Code $param->{code}!";
        }
    } else {
        Log3 $name, 5, "$name ($self) - Failed because no data was received!";
    }
    Log3 $name, 5, "$name ($self) - Connect/Login to Unifi-Controller failed. Will try again after interval...";
    Unifi_CONNECTED($hash,'disconnected');
    InternalTimer(time()+$hash->{unifi}->{interval}, 'Unifi_Login_Send', $hash, 0);
    return undef;
}
###############################################################################

sub Unifi_GetClients_Send($) {
    my ($hash) = @_;
    my ($name,$self) = ($hash->{NAME},Unifi_Whoami());
    Log3 $name, 5, "$name ($self) - executed.";
    
    HttpUtils_NonblockingGet( {
                 %{$hash->{httpParams}},
        method   => "GET",
        url      => $hash->{unifi}->{url}."stat/sta",
        callback => $hash->{updateDispatch}->{$self}[2]
    } );
    return undef;
}
###############################################################################
sub Unifi_GetClients_Receive($) {
    my ($param, $err, $data) = @_;
    my ($name,$self,$hash) = ($param->{hash}->{NAME},Unifi_Whoami(),$param->{hash});
    Log3 $name, 5, "$name ($self) - executed.";
    
    if ($err ne "") {
        Unifi_ReceiveFailure($hash,{rc => 'Error while requesting', msg => $param->{url}." - $err"});
    }
    elsif ($data ne "") {
        if ($param->{code} == 200 || $param->{code} == 400  || $param->{code} == 401) {
            eval { $data = decode_json($data); 1; } or do { $data = { meta => {rc => 'error.decode_json', msg => $@} }; };
            
            if ($data->{meta}->{rc} eq "ok") {
                Log3 $name, 5, "$name ($self) - state:'$data->{meta}->{rc}'";
				                
                $hash->{unifi}->{connectedClients} = undef;
                for my $h (@{$data->{data}}) {
                    $hash->{unifi}->{connectedClients}->{$h->{user_id}} = 1;
                    $hash->{clients}->{$h->{user_id}} = $h;
					
					# mergen mit den clientInsights. ACHTUNG: dasselbe muss aufgrund unbekannter Reihenfolge der Aufrufe auch in GetClientInsights_Receive und UpdateClient_Receive durchgef�hrt werden.
					if (defined $hash->{unifi}->{clientInsights}->{$h->{user_id}}){						
						if (defined $hash->{unifi}->{clientInsights}->{$h->{user_id}}->{blocked} && $hash->{unifi}->{clientInsights}->{$h->{user_id}}->{blocked} eq JSON::true){
							$hash->{clients}->{$h->{user_id}}->{blocked}=JSON::true;
						}else{
							$hash->{clients}->{$h->{user_id}}->{blocked}=JSON::false;
						}
					}
                }
            }
            else { Unifi_ReceiveFailure($hash,$data->{meta}); }
        } else {
            Unifi_ReceiveFailure($hash,{rc => $param->{code}, msg => "Failed with HTTP Code $param->{code}."});
        }
    }
    Unifi_NextUpdateFn($hash,$self);
    return undef;
}
###############################################################################

sub Unifi_GetClientInsights_Send($) {
    my ($hash) = @_;
    my ($name,$self) = ($hash->{NAME},Unifi_Whoami());
    Log3 $name, 5, "$name ($self) - executed.";
	#my $within=$hash->{unifi}->{readClientInsights}->{attr_value} if defined $hash->{unifi}->{readClientInsights};
    #if (defined $within){
		HttpUtils_NonblockingGet( {
					 %{$hash->{httpParams}},
			method   => "GET",
			url      => $hash->{unifi}->{url}."stat/alluser?within=".(365*24),
			callback => \&Unifi_GetClientInsights_Receive,
		} );
	#}
    return undef;
}
sub Unifi_GetClientInsights_Receive($) {
    my ($param, $err, $data) = @_;
    my ($name,$self,$hash) = ($param->{hash}->{NAME},Unifi_Whoami(),$param->{hash});
    Log3 $name, 5, "$name ($self) - executed.";
    
    if ($err ne "") {
        Unifi_ReceiveFailure($hash,{rc => 'Error while requesting', msg => $param->{url}." - $err"});
    }
    elsif ($data ne "") {
        if ($param->{code} == 200 || $param->{code} == 400  || $param->{code} == 401) {
            eval { $data = decode_json($data); 1; } or do { $data = { meta => {rc => 'error.decode_json', msg => $@} }; };
            
            if ($data->{meta}->{rc} eq "ok") {
                Log3 $name, 5, "$name ($self) - state:'$data->{meta}->{rc}'";
                
                $hash->{unifi}->{clientInsights} = undef;
                for my $h (@{$data->{data}}) {
					$hash->{unifi}->{clientInsights}->{$h->{_id}} = $h;
					
					# mergen mit den clients. ACHTUNG: dasselbe muss aufgrund unbekannter Reihenfolge der Aufrufe auch in GetClients_Receive und UpdateClient_Receive durchgef�hrt werden.
					if (defined $hash->{clients}->{$h->{_id}}){						
						if (defined $h->{blocked} && $h->{blocked} eq JSON::true){
							$hash->{clients}->{$h->{_id}}->{blocked}=JSON::true;
						}else{
							$hash->{clients}->{$h->{_id}}->{blocked}=JSON::false;
						}
					}
                }
            }
            else { Unifi_ReceiveFailure($hash,$data->{meta}); }
        } else {
            Unifi_ReceiveFailure($hash,{rc => $param->{code}, msg => "Failed with HTTP Code $param->{code}."});
        }
    }
    
    Unifi_NextUpdateFn($hash,$self);
    return undef;
}
###############################################################################

sub Unifi_UpdateClient_Send($$) {
    my ($hash,$mac) = @_;
    my ($name,$self) = ($hash->{NAME},Unifi_Whoami());
    if (defined $mac && $mac ne ""){
		Log3 $name, 5, "$name ($self) - executed with mac ".$mac;
		HttpUtils_NonblockingGet( {
					 %{$hash->{httpParams}},
			method   => "GET",
			url      => $hash->{unifi}->{url}."stat/user/".$mac,
			callback => \&Unifi_UpdateClient_Receive
		} );
	}else{
		Log3 $name, 4, "$name ($self) - executed without mac.";
	}
    return undef;
}
###############################################################################
sub Unifi_UpdateClient_Receive($) {
    my ($param, $err, $data) = @_;
    my ($name,$self,$hash) = ($param->{hash}->{NAME},Unifi_Whoami(),$param->{hash});
    Log3 $name, 5, "$name ($self) - executed.";
    #Log3 $name, 1, "$name ($self) - executed. $data";
    
    if ($err ne "") {
        Unifi_ReceiveFailure($hash,{rc => 'Error while requesting', msg => $param->{url}." - $err"});
    }
    elsif ($data ne "") {
        if ($param->{code} == 200 || $param->{code} == 400  || $param->{code} == 401) {
            eval { $data = decode_json($data); 1; } or do { $data = { meta => {rc => 'error.decode_json', msg => $@} }; };
            
            if ($data->{meta}->{rc} eq "ok") {
                Log3 $name, 5, "$name ($self) - state:'$data->{meta}->{rc}'";
                                
                for my $h (@{$data->{data}}) {
					if (defined $h->{ip}){
						$hash->{unifi}->{connectedClients}->{$h->{_id}} = 1;
					}else{
						delete $hash->{unifi}->{connectedClients}->{$h->{_id}};
					}
                    $hash->{clients}->{$h->{_id}} = $h;
					# mergen mit den clientInsights. ACHTUNG: dasselbe muss aufgrund unbekannter Reihenfolge der Aufrufe auch in GetClientInsights_Receive und GetClients_Receive durchgef�hrt werden.
					if (defined $hash->{unifi}->{clientInsights}->{$h->{_id}}){						
						if (defined $hash->{unifi}->{clientInsights}->{$h->{_id}}->{blocked} && $hash->{unifi}->{clientInsights}->{$h->{_id}}->{blocked} eq JSON::true){
							$hash->{clients}->{$h->{_id}}->{blocked}=JSON::true;
						}else{
							$hash->{clients}->{$h->{_id}}->{blocked}=JSON::false;
						}
					}
                    readingsBeginUpdate($hash);
                    Unifi_SetClientReadings($hash, $h->{_id});					
                    readingsEndUpdate($hash,1);
                }
            }
            else { Unifi_ReceiveFailure($hash,$data->{meta}); }
        } else {
            Unifi_ReceiveFailure($hash,{rc => $param->{code}, msg => "Failed with HTTP Code $param->{code}."});
        }
    }
    return undef;
}
###############################################################################
sub Unifi_GetWlans_Send($) {
    my ($hash) = @_;
    my ($name,$self) = ($hash->{NAME},Unifi_Whoami());
    Log3 $name, 5, "$name ($self) - executed.";
    
    HttpUtils_NonblockingGet( {
                 %{$hash->{httpParams}},
        method   => "GET",
        url      => $hash->{unifi}->{url}."list/wlanconf",
        callback => $hash->{updateDispatch}->{$self}[2],
    } );
    return undef;
}
sub Unifi_GetWlans_Receive($) {
    my ($param, $err, $data) = @_;
    my ($name,$self,$hash) = ($param->{hash}->{NAME},Unifi_Whoami(),$param->{hash});
    Log3 $name, 5, "$name ($self) - executed.";
    
    if ($err ne "") {
        Unifi_ReceiveFailure($hash,{rc => 'Error while requesting', msg => $param->{url}." - $err"});
    }
    elsif ($data ne "") {
        if ($param->{code} == 200 || $param->{code} == 400  || $param->{code} == 401) {
            eval { $data = decode_json($data); 1; } or do { $data = { meta => {rc => 'error.decode_json', msg => $@} }; };
            
            if ($data->{meta}->{rc} eq "ok") {
                Log3 $name, 5, "$name ($self) - state:'$data->{meta}->{rc}'";
                
                for my $h (@{$data->{data}}) {
                    $hash->{wlans}->{$h->{_id}} = $h;
                    #TODO: Passphrase ggf. verschl�sseln?!
                    #Ich musste diese Zeile rausnehmen, sonst ist das Json f�r enable/disableWLAN bei offenem WLAN (ohne Passphrase) falsch 
                    #Aussternen geht nicht, sonst wird das PW unter Umst�nden darauf ge�ndert.
                    #$hash->{wlans}->{$h->{_id}}->{x_passphrase} = '***'; # Don't show passphrase in list
                    delete $hash->{wlans}->{$h->{_id}}->{x_passphrase};
                }
            }
            else { Unifi_ReceiveFailure($hash,$data->{meta}); }
        } else {
            Unifi_ReceiveFailure($hash,{rc => $param->{code}, msg => "Failed with HTTP Code $param->{code}."});
        }
    }
    
    Unifi_NextUpdateFn($hash,$self);
    return undef;
}
###############################################################################
sub Unifi_GetHealth_Send($) {
    my ($hash) = @_;
    my ($name,$self) = ($hash->{NAME},Unifi_Whoami());
    Log3 $name, 5, "$name ($self) - executed.";
    
    HttpUtils_NonblockingGet( {
                 %{$hash->{httpParams}},
        method   => "GET",
        url      => $hash->{unifi}->{url}."stat/health",
        callback => $hash->{updateDispatch}->{$self}[2],
    } );
    return undef;
}
sub Unifi_GetHealth_Receive($) {
    my ($param, $err, $data) = @_;
    my ($name,$self,$hash) = ($param->{hash}->{NAME},Unifi_Whoami(),$param->{hash});
    Log3 $name, 5, "$name ($self) - executed.";
    
    if ($err ne "") {
        Unifi_ReceiveFailure($hash,{rc => 'Error while requesting', msg => $param->{url}." - $err"});
    }
    elsif ($data ne "") {
        if ($param->{code} == 200 || $param->{code} == 400  || $param->{code} == 401) {
            eval { $data = decode_json($data); 1; } or do { $data = { meta => {rc => 'error.decode_json', msg => $@} }; };
            
            if ($data->{meta}->{rc} eq "ok") {
                Log3 $name, 5, "$name ($self) - state:'$data->{meta}->{rc}'";
                
                for my $h (@{$data->{data}}) {
                    if (defined($h->{subsystem}) && $h->{subsystem} eq 'wlan') {
                        $hash->{wlan_health} = $h;
                    }
                    if (defined($h->{subsystem}) && $h->{subsystem} eq 'www') {
                        $hash->{www_health} = $h;
                    }
                    if (defined($h->{subsystem}) && $h->{subsystem} eq 'wan') {
                        $hash->{wan_health} = $h;
                    }
                }
            }
            else { Unifi_ReceiveFailure($hash,$data->{meta}); }
        } else {
            Unifi_ReceiveFailure($hash,{rc => $param->{code}, msg => "Failed with HTTP Code $param->{code}."});
        }
    }
    
    Unifi_NextUpdateFn($hash,$self);
    return undef;
}
###############################################################################
sub Unifi_GetSysinfo_Send($) {
    my ($hash) = @_;
    my ($name,$self) = ($hash->{NAME},Unifi_Whoami());
    Log3 $name, 5, "$name ($self) - executed.";
    
    HttpUtils_NonblockingGet( {
                 %{$hash->{httpParams}},
        method   => "GET",
        url      => $hash->{unifi}->{url}."stat/sysinfo",
        callback => \&Unifi_GetSysinfo_Receive,
    } );
    return undef;
}
sub Unifi_GetSysinfo_Receive($) {
    my ($param, $err, $data) = @_;
    my ($name,$self,$hash) = ($param->{hash}->{NAME},Unifi_Whoami(),$param->{hash});
    Log3 $name, 5, "$name ($self) - executed.";
    
    if ($err ne "") {
        Unifi_ReceiveFailure($hash,{rc => 'Error while requesting', msg => $param->{url}." - $err"});
    }
    elsif ($data ne "") {
        if ($param->{code} == 200 || $param->{code} == 400  || $param->{code} == 401) {
            eval { $data = decode_json($data); 1; } or do { $data = { meta => {rc => 'error.decode_json', msg => $@} }; };
            
            if ($data->{meta}->{rc} eq "ok") {
                Log3 $name, 5, "$name ($self) - state:'$data->{meta}->{rc}'";
				
                for my $h (@{$data->{data}}) {
					$hash->{UC_VERSION}=$h->{version} if defined $h->{version};
					Log3 $name, 5, "$name ($self) - uc_version: ".$hash->{UC_VERSION};
				}
            }
            else { Unifi_ReceiveFailure($hash,$data->{meta}); }
        } else {
            Unifi_ReceiveFailure($hash,{rc => $param->{code}, msg => "Failed with HTTP Code $param->{code}."});
        }
    }
    
    Unifi_NextUpdateFn($hash,$self);
    return undef;
}
###############################################################################
sub Unifi_GetWlanGroups_Send($) {
    my ($hash) = @_;
    my ($name,$self) = ($hash->{NAME},Unifi_Whoami());
    Log3 $name, 5, "$name ($self) - executed.";
    
    HttpUtils_NonblockingGet( {
                 %{$hash->{httpParams}},
        method   => "GET",
        url      => $hash->{unifi}->{url}."list/wlangroup",
        callback => $hash->{updateDispatch}->{$self}[2],
    } );
    return undef;
}
sub Unifi_GetWlanGroups_Receive($) {
    my ($param, $err, $data) = @_;
    my ($name,$self,$hash) = ($param->{hash}->{NAME},Unifi_Whoami(),$param->{hash});
    Log3 $name, 5, "$name ($self) - executed.";
    
    if ($err ne "") {
        Unifi_ReceiveFailure($hash,{rc => 'Error while requesting', msg => $param->{url}." - $err"});
    }
    elsif ($data ne "") {
        if ($param->{code} == 200 || $param->{code} == 400  || $param->{code} == 401) {
            eval { $data = decode_json($data); 1; } or do { $data = { meta => {rc => 'error.decode_json', msg => $@} }; };
            
            if ($data->{meta}->{rc} eq "ok") {
                Log3 $name, 5, "$name ($self) - state:'$data->{meta}->{rc}'";
                
                for my $h (@{$data->{data}}) {
                    $hash->{wlangroup}->{$h->{_id}} = $h;
                }
            }
            else { Unifi_ReceiveFailure($hash,$data->{meta}); }
        } else {
            Unifi_ReceiveFailure($hash,{rc => $param->{code}, msg => "Failed with HTTP Code $param->{code}."});
        }
    }
    
    Unifi_NextUpdateFn($hash,$self);
    return undef;
}
###############################################################################
sub Unifi_GetUnarchivedAlerts_Send($) {
    my ($hash) = @_;
    my ($name,$self) = ($hash->{NAME},Unifi_Whoami());
    Log3 $name, 5, "$name ($self) - executed.";
    
    HttpUtils_NonblockingGet( {
                 %{$hash->{httpParams}},
        url      => $hash->{unifi}->{url}."list/alarm",
        callback => $hash->{updateDispatch}->{$self}[2],
        data     => "{\"_sort\":\"-time\", \"archived\":false}",
    } );
    return undef;
}
sub Unifi_GetUnarchivedAlerts_Receive($) {
    my ($param, $err, $data) = @_;
    my ($name,$self,$hash) = ($param->{hash}->{NAME},Unifi_Whoami(),$param->{hash});
    Log3 $name, 5, "$name ($self) - executed.";
    
    if ($err ne "") {
        Unifi_ReceiveFailure($hash,{rc => 'Error while requesting', msg => $param->{url}." - $err"});
    }
    elsif ($data ne "") {
        if ($param->{code} == 200 || $param->{code} == 400  || $param->{code} == 401) {
            eval { $data = decode_json($data); 1; } or do { $data = { meta => {rc => 'error.decode_json', msg => $@} }; };
            
            if ($data->{meta}->{rc} eq "ok") {
                Log3 $name, 5, "$name ($self) - state:'$data->{meta}->{rc}'";
                
                $hash->{alerts_unarchived} = $data->{data}; #array
            }
            else { Unifi_ReceiveFailure($hash,$data->{meta}); }
        } else {
            Unifi_ReceiveFailure($hash,{rc => $param->{code}, msg => "Failed with HTTP Code $param->{code}."});
        }
    }
    
    Unifi_NextUpdateFn($hash,$self);
    return undef;
}
###############################################################################
sub Unifi_GetEvents_Send($) {
    my ($hash) = @_;
    my ($name,$self) = ($hash->{NAME},Unifi_Whoami());
    Log3 $name, 5, "$name ($self) - executed.";
    
    HttpUtils_NonblockingGet( {
                 %{$hash->{httpParams}},
        url      => $hash->{unifi}->{url}."stat/event",
        callback => $hash->{updateDispatch}->{$self}[2],
        data     => "{\"_sort\":\"-time\", \"within\":".$hash->{unifi}->{eventPeriod}."}",    # last 24 hours
    } );
    return undef;
}
sub Unifi_GetEvents_Receive($) {
    my ($param, $err, $data) = @_;
    my ($name,$self,$hash) = ($param->{hash}->{NAME},Unifi_Whoami(),$param->{hash});
    Log3 $name, 5, "$name ($self) - executed.";
    
    if ($err ne "") {
        Unifi_ReceiveFailure($hash,{rc => 'Error while requesting', msg => $param->{url}." - $err"});
    }
    elsif ($data ne "") {
        if ($param->{code} == 200 || $param->{code} == 400  || $param->{code} == 401) {
            eval { $data = decode_json($data); 1; } or do { $data = { meta => {rc => 'error.decode_json', msg => $@} }; };
            
            if ($data->{meta}->{rc} eq "ok") {
                Log3 $name, 5, "$name ($self) - state:'$data->{meta}->{rc}'";
                
                $hash->{events} = $data->{data}; #array
            }
            else { Unifi_ReceiveFailure($hash,$data->{meta}); }
        } else {
            Unifi_ReceiveFailure($hash,{rc => $param->{code}, msg => "Failed with HTTP Code $param->{code}."});
        }
    }
    
    Unifi_NextUpdateFn($hash,$self);
    return undef;
}
###############################################################################
sub Unifi_GetAccesspoints_Send($) { # TODO Umbenennen in Unifi_GetDevices_Send. Dann muss man auch an Get_ApNames() ran, da dort nicht nur APs sondern auch usg und switch drin sind.
									# Waren wohl fr�her in Version 1 des Moduls nur APs unter devices
    my ($hash) = @_;
    my ($name,$self) = ($hash->{NAME},Unifi_Whoami());
    Log3 $name, 5, "$name ($self) - executed.";
    
    HttpUtils_NonblockingGet( {
                 %{$hash->{httpParams}},
        url      => $hash->{unifi}->{url}."stat/device",
        callback => $hash->{updateDispatch}->{$self}[2],
        data     => "{\"_depth\":2, \"test\":0}",
    } );
    return undef;
}
sub Unifi_GetAccesspoints_Receive($) {# TODO Umbenennen in Unifi_GetDevices_Receive
    my ($param, $err, $data) = @_;
    my ($name,$self,$hash) = ($param->{hash}->{NAME},Unifi_Whoami(),$param->{hash});
    Log3 $name, 5, "$name ($self) - executed.";
    
    if ($err ne "") {
        Unifi_ReceiveFailure($hash,{rc => 'Error while requesting', msg => $param->{url}." - $err"});
    }
    elsif ($data ne "") {
        if ($param->{code} == 200 || $param->{code} == 400  || $param->{code} == 401) {
            eval { $data = decode_json($data); 1; } or do { $data = { meta => {rc => 'error.decode_json', msg => $@} }; };
            
            if ($data->{meta}->{rc} eq "ok") {
                Log3 $name, 5, "$name ($self) - state:'$data->{meta}->{rc}'";
                
                for my $h (@{$data->{data}}) {
                    $hash->{accespoints}->{$h->{_id}} = $h;
                    #TODO: Switch-Modelle anders festlegen ? Oder passt usw?
                    if (defined $h->{model} && $h->{type} eq "usw"){
                        my $usw_name="";
                        if (defined $h->{name}){
                          $usw_name=makeDeviceName($h->{name});
                        }else{
                          $usw_name=makeDeviceName($h->{ip});
                        }
                        Dispatch($hash,"UnifiSwitch_".$usw_name.encode_json($h),undef);
                    }
                }
            }
            else { Unifi_ReceiveFailure($hash,$data->{meta}); }
        } else {
            Unifi_ReceiveFailure($hash,{rc => $param->{code}, msg => "Failed with HTTP Code $param->{code}."});
        }
    }
    
    Unifi_NextUpdateFn($hash,$self);
    return undef;
}
###############################################################################

sub Unifi_ProcessUpdate($) {
    my ($hash) = @_;
    my ($name,$self) = ($hash->{NAME},Unifi_Whoami());
    Log3 $name, 5, "$name ($self) - executed after ".sprintf('%.4f',time() - $hash->{unifi}->{updateStartTime})." seconds.";
    
    readingsBeginUpdate($hash);
    #'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''#
    Unifi_SetHealthReadings($hash);
    Unifi_SetClientReadings($hash, undef);
    Unifi_SetAccesspointReadings($hash);
    Unifi_SetWlanReadings($hash);
    Unifi_SetVoucherReadings($hash);
    ## WLANGROUPS ???
    #'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''#
    readingsEndUpdate($hash,1);
    
    Log3 $name, 5, "$name ($self) - finished after ".sprintf('%.4f',time() - $hash->{unifi}->{updateStartTime})." seconds.";
    InternalTimer(time()+$hash->{unifi}->{interval}, 'Unifi_DoUpdate', $hash, 0);
    
    return undef;
}
###############################################################################

sub Unifi_SetClientReadings($$) {
    my ($hash, $updatedClientID) = @_;
    my ($name,$self) = ($hash->{NAME},Unifi_Whoami());
    Log3 $name, 5, "$name ($self) - executed.";
	
    my $apNames = {};
    for my $apID (keys %{$hash->{accespoints}}) {
      my $apRef = $hash->{accespoints}->{$apID};
      $apNames->{$apRef->{mac}} = $apRef->{name} ? $apRef->{name} : $apRef->{ip};
    }

    my $ignoreWired = AttrVal($name,"ignoreWiredClients",undef);
    my $ignoreWireless = AttrVal($name,"ignoreWirelessClients",undef);

    my ($apName,$clientName,$clientRef);
    my $newClients="";
    my $blockedClients="";
    for my $clientID (keys %{$hash->{clients}}) {
        $clientRef = $hash->{clients}->{$clientID};
		if(! defined $updatedClientID || $updatedClientID eq $clientID){
			$clientName = Unifi_ClientNames($hash,$clientID,'makeAlias');
			
			next if( $ignoreWired && $clientRef->{is_wired} );
			next if( $ignoreWireless && !$clientRef->{is_wired} );
			
			{
				$apName = "unknown";
				if ($clientRef->{is_wired}
					&&  defined $clientRef->{sw_mac} && defined($apNames->{$clientRef->{sw_mac}}) ) {
				  $apName = $apNames->{$clientRef->{sw_mac}};
				} elsif (defined $clientRef->{ap_mac} && defined($apNames->{$clientRef->{ap_mac}}) ) {
				  $apName = $apNames->{$clientRef->{ap_mac}};
				}
				$clientRef->{accesspoint}=$apName;
				
				# ein paar Daten auch formatiert zur Verf�gung stellen
				# falls man Sonderzeichen im WLAN-Namen hat und damit auf ein entsprechendes WLAN-Reading zugreifen m�chte
				$clientRef->{_f_essid}=makeReadingName($clientRef->{essid}); 
				# Einige Zeitformatierungen:
				$clientRef->{_f_last_seen}=strftime "%Y-%m-%d %H:%M:%S",localtime($clientRef->{last_seen}) if defined $clientRef->{last_seen};
				$clientRef->{_f_latest_assoc_time}=strftime "%Y-%m-%d %H:%M:%S",localtime($clientRef->{latest_assoc_time}) if defined $clientRef->{latest_assoc_time};
				$clientRef->{_f_first_seen}=strftime "%Y-%m-%d %H:%M:%S",localtime($clientRef->{first_seen}) if defined $clientRef->{first_seen};
				$clientRef->{_f_last_seen_by_usw}=strftime "%Y-%m-%d %H:%M:%S",localtime($clientRef->{_last_seen_by_usw}) if defined $clientRef->{_last_seen_by_usw};
				$clientRef->{_f_last_seen_by_ugw}=strftime "%Y-%m-%d %H:%M:%S",localtime($clientRef->{_last_seen_by_ugw}) if defined $clientRef->{_last_seen_by_ugw};
				$clientRef->{_f_last_seen_by_uap}=strftime "%Y-%m-%d %H:%M:%S",localtime($clientRef->{_last_seen_by_uap}) if defined $clientRef->{_last_seen_by_uap};
				if (defined $clientRef->{last_seen}){
					my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)= gmtime(time() - $clientRef->{last_seen});
					$clientRef->{_f_last_seen_duration}=$yday."d ".$hour."h ".$min."m ".$sec."s";
				}
				if (defined $clientRef->{uptime}){
					my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)= gmtime($clientRef->{uptime});
					$clientRef->{_f_uptime}=$yday."d ".$hour."h ".$min."m ".$sec."s";
				}
				if (defined $clientRef->{dhcpend_time}){
					my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)= gmtime($clientRef->{dhcpend_time});
					$clientRef->{_f_dhcpend_time}=$yday."d ".$hour."h ".$min."m ".$sec."s";
				}
				if (defined $clientRef->{assoc_time}){
					my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)= gmtime($clientRef->{assoc_time});
					$clientRef->{_f_assoc_time}=$yday."d ".$hour."h ".$min."m ".$sec."s";
				}
				if (defined $clientRef->{_uptime_by_usw}){
					my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)= gmtime($clientRef->{_uptime_by_usw});
					$clientRef->{_f_uptime_by_usw}=$yday."d ".$hour."h ".$min."m ".$sec."s";
				}
				if (defined $clientRef->{_uptime_by_ugw}){
					my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)= gmtime($clientRef->{_uptime_by_ugw});
					$clientRef->{_f_uptime_by_ugw}=$yday."d ".$hour."h ".$min."m ".$sec."s";
				}
				if (defined $clientRef->{_uptime_by_uap}){
					my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)= gmtime($clientRef->{_uptime_by_uap});
					$clientRef->{_f_uptime_by_uap}=$yday."d ".$hour."h ".$min."m ".$sec."s";
				}
				my $tx=ReadingsVal($name,$clientName."_tx_bytes","");
				if ($tx ne "" && defined $clientRef->{tx_bytes}){
					$clientRef->{_f_diff_tx_bytes}=($clientRef->{tx_bytes})-($tx);
				}
				
				if (defined $clientRef->{usergroup_id} && defined $hash->{unifi}->{usergroups}->{$clientRef->{usergroup_id}}){	
					$clientRef->{_f_usergroup_name}=$hash->{unifi}->{usergroups}->{$clientRef->{usergroup_id}}->{name};
				}else{
					$clientRef->{_f_usergroup_name}="Default";
				}
				
				$clientRef->{fhem_clientName}=$clientName;
			}
			
			if (defined $hash->{unifi}->{connectedClients}->{$clientID}) {			
				if (! defined ReadingsVal($hash->{NAME},$clientName,undef)){
				  $newClients.=$clientName.",";
				}
				$clientRef->{fhem_state}="connected";
				readingsBulkUpdate($hash,$clientName,'connected');		
				#readingsBulkUpdate($hash,".".$clientName."_id",$clientRef->{_id});	
				
				# mac-Adresse in den Readings versteckt (statet mit .) speichern, um nach einem Neustart den client restoren zu k�nnen
				readingsBulkUpdate($hash,".".$clientName."_mac",$clientRef->{mac}) if defined $clientRef->{mac};			
			}
			elsif ((!defined($hash->{READINGS}->{$clientName})) || (defined($hash->{READINGS}->{$clientName}) && $hash->{READINGS}->{$clientName} ne "disconnected")) {
				Log3 $name, 5, "$name ($self) - Client '$clientName' previously connected is now disconnected.";
				if(defined $clientRef->{blocked} && $clientRef->{blocked} eq JSON::true){
					$blockedClients.=$clientName.',';
				}
				$clientRef->{fhem_state}="disconnected";
				readingsBulkUpdate($hash,$clientName,'disconnected');
			}
			
			# altes Standardverhalten kann man auch ohne RegEx-Auswertungen beibehalten
			if(AttrVal($name,"customClientReadings",$defaultClientReadings) eq $defaultClientReadings){ 
				readingsBulkUpdate($hash,$clientName."_hostname",(defined $clientRef->{hostname}) ? $clientRef->{hostname} : (defined $clientRef->{ip}) ? $clientRef->{ip} : 'Unknown');
				readingsBulkUpdate($hash,$clientName."_last_seen",strftime "%Y-%m-%d %H:%M:%S",localtime($clientRef->{last_seen}));
				readingsBulkUpdate($hash,$clientName."_uptime",$clientRef->{uptime});
				readingsBulkUpdate($hash,$clientName."_snr",$clientRef->{rssi});
				# Da essid auch im Readingnamen bei WLAN verwendet wird, wird aus Konsistenzgr�nden hier beim ReadingValue ebenfalls makeReadingName() verwendet.
				readingsBulkUpdate($hash,$clientName."_essid",makeReadingName($clientRef->{essid})); 
				readingsBulkUpdate($hash,$clientName."_accesspoint",$clientRef->{accesspoint});
			}
			else{ # Auswerten des Attribute customClientReadings
				for my $customClientReadingsPart (keys %{$hash->{unifi}->{customClientReadings}->{parts}}) {
					my $reName = "";
					my $nameRegEx=$hash->{unifi}->{customClientReadings}->{parts}->{$customClientReadingsPart}->{nameRegEx};
					eval { $reName = qr/$nameRegEx/; };
					if ($@){
						Log3 $name, 2, "$name ($self) - Wrong RegEx (".$nameRegEx.") in name-part in attribute customClientReadings!";
					}
					else{
						if($clientName =~ m/$reName/){ #matched der ClientName?
							my $reReading = "";
							my $readingRegEx=$hash->{unifi}->{customClientReadings}->{parts}->{$customClientReadingsPart}->{ReadingRegEx};
							eval { $reReading = qr/($readingRegEx)/; };
							if ($@){
								Log3 $name, 2, "$name ($self) - Wrong RegEx (".$readingRegEx.") in reading-part in attribute customClientReadings!";
							}
							else{
								for my $readingName (sort keys %{$clientRef	}) {
									if($readingName =~ m/$reReading/){ #matched der ReadingName?
										my $readingData = ((defined($clientRef->{$readingName})) ? $clientRef->{$readingName} : '');
										readingsBulkUpdate($hash,$clientName."_".$readingName,$readingData);
									}
								}
							}
						}
					}
				}
			}
			
			Log3 $name, 5, "$name ($self) - Dispatch: ".$clientName;
			Dispatch($hash,"UnifiClient_".$clientName.encode_json($clientRef),undef);
		}
    }
	
	$newClients =~ s/.$// if $newClients  ne "";
	$blockedClients =~ s/.$// if $blockedClients  ne "";
    readingsBulkUpdate($hash,"-UC_newClients",$newClients);
    readingsBulkUpdate($hash,"-UC_blockedClients",$blockedClients);
    
    return undef;
}
###############################################################################
sub Unifi_SetHealthReadings($) {
    my ($hash) = @_;
    my ($name,$self) = ($hash->{NAME},Unifi_Whoami());
    Log3 $name, 5, "$name ($self) - executed.";
    
    if(defined($hash->{www_health})){
      readingsBulkUpdate($hash,'-UC_speed_ping',$hash->{www_health}->{speedtest_ping});
      readingsBulkUpdate($hash,'-UC_speed_down',$hash->{www_health}->{xput_down});
      readingsBulkUpdate($hash,'-UC_speed_up',$hash->{www_health}->{xput_up});
    }
    if(defined($hash->{wan_health})){
      readingsBulkUpdate($hash,'-UC_wan_ip',$hash->{wan_health}->{wan_ip});
    }
    readingsBulkUpdate($hash,'-UC_wlan_state',$hash->{wlan_health}->{status});
    readingsBulkUpdate($hash,'-UC_wlan_users',$hash->{wlan_health}->{num_user});
    readingsBulkUpdate($hash,'-UC_wlan_accesspoints',$hash->{wlan_health}->{num_ap});
    readingsBulkUpdate($hash,'-UC_wlan_guests',$hash->{wlan_health}->{num_guest});
    readingsBulkUpdate($hash,'-UC_unarchived_alerts',scalar @{$hash->{alerts_unarchived}}) if(ref($hash->{alerts_unarchived}) eq 'ARRAY'); 
    readingsBulkUpdate($hash,'-UC_events',scalar(@{$hash->{events}}).' (last '.$hash->{unifi}->{eventPeriod}.'h)') if(ref($hash->{events}) eq 'ARRAY');
    
    return undef;
}
###############################################################################
sub Unifi_SetAccesspointReadings($) {
    my ($hash) = @_;
    my ($name,$self) = ($hash->{NAME},Unifi_Whoami());
    Log3 $name, 5, "$name ($self) - executed.";

    my ($apName,$apRef,$essid);
    my $utiliz;
    for my $apID (keys %{$hash->{accespoints}}) {
        $essid = '';
        $utiliz = '';
        $apRef = $hash->{accespoints}->{$apID};
        $apName = ($apRef->{name}) ? makeReadingName($apRef->{name}) : $apRef->{ip};

        if (defined $apRef->{vap_table} && scalar @{$apRef->{vap_table}}) {
            for my $vap (@{$apRef->{vap_table}}) {
                $essid .= makeReadingName($vap->{essid}).',';
            }
            $essid =~ s/.$//;
        } else {
            my $essid = 'none';
        }

        #nochmal genauer ins json schauen, ob hier wirklich eine Schleife notwendig ist. (cu_total mehrfach vorhanden?)
        if (defined $apRef->{'radio_table_stats'} ) {
            for my $rts (@{$apRef->{'radio_table_stats'}}) {
                $utiliz .= makeReadingName($rts->{'cu_total'}).','; # TODO: hier nicht unbedingt notwendig, aufgrund des funktionierenden schnellen fixes wegen neuer controller-Version bleibt es aber erstmal so drin.
            }
            $utiliz =~ s/.$//;
        } else {
            my $utiliz = 'none';
        }

        readingsBulkUpdate($hash,'-AP_'.$apName.'_state',($apRef->{state} == 1) ? 'ok' : 'error');
        readingsBulkUpdate($hash,'-AP_'.$apName.'_clients',$apRef->{'num_sta'});
        if( $apRef->{type} eq 'uap' ) {
          readingsBulkUpdate($hash,'-AP_'.$apName.'_essid',$essid);
          readingsBulkUpdate($hash,'-AP_'.$apName.'_utilization',$utiliz) if ($utiliz ne '');
          readingsBulkUpdate($hash,'-AP_'.$apName.'_utilizationNA',$apRef->{'na_cu_total'}) if( defined($apRef->{'na_cu_total'}) );
          readingsBulkUpdate($hash,'-AP_'.$apName.'_utilizationNG',$apRef->{'ng_cu_total'}) if( defined($apRef->{'ng_cu_total'}) );
        }
        readingsBulkUpdate($hash,'-AP_'.$apName.'_locate',(!defined $apRef->{locating}) ? 'unknown' : ($apRef->{locating}) ? 'on' : 'off');
        #my $poe_power;
        #for my $port (@{$apRef->{port_table}}) {
        #  next if( !$port->{port_poe} );
        #  $poe_power += $port->{poe_power} if( defined($port->{poe_power}) );
        #}
        #readingsBulkUpdate($hash,'-AP_'.$apName.'_poePower', $poe_power) if( defined($poe_power) );

        # readingsBulkUpdate($hash,'-AP_'.$apName.'_guests',$apRef->{'guest-num_sta'});
        # readingsBulkUpdate($hash,'-AP_'.$apName.'_users',$apRef->{'user-num_sta'});
        # readingsBulkUpdate($hash,'-AP_'.$apName.'_last_seen',$apRef->{'last_seen'});
    }

    return undef;
}

###############################################################################
sub Unifi_SetWlanReadings($) {
    my ($hash) = @_;
    my ($name,$self) = ($hash->{NAME},Unifi_Whoami());
    Log3 $name, 5, "$name ($self) - executed.";
    
    my ($wlanName,$wlanRef);
    for my $wlanID (keys %{$hash->{wlans}}) {
        $wlanRef = $hash->{wlans}->{$wlanID};
        $wlanName = makeReadingName($wlanRef->{name});        
        readingsBulkUpdate($hash,'-WLAN_'.$wlanName.'_state',($wlanRef->{enabled} eq JSON::true) ? 'enabled' : 'disabled');
    }
    
    return undef;
}

###############################################################################

sub Unifi_SetVoucherReadings($) {
    my ($hash) = @_;
    my ($name,$self) = ($hash->{NAME},Unifi_Whoami());
    Log3 $name, 5, "$name ($self) - executed.";
    #f�r jeden Vouchercache den n�chsten Vouchercode als Reading anzeigen
    for my $cache (keys %{$hash->{hotspot}->{voucherCache}}) {
        if(ref($hash->{hotspot}->{voucherCache}->{$cache}) eq "HASH"){
            if(defined $hash->{hotspot}->{voucherCache}->{$cache}->{setCmd}){
                my $voucher=Unifi_getNextVoucherForNote($hash,$cache);
                if(ref($voucher) eq "HASH"){
                    readingsBulkUpdate($hash,"-VC_".$cache,$voucher->{code});
                }else{
                    readingsBulkUpdate($hash,"-VC_".$cache,"-");
                }
            }
        }
    }
}
###############################################################################

sub Unifi_DisconnectClient_Send($@) {
    my ($hash,@clients) = @_;
    my ($name,$self) = ($hash->{NAME},Unifi_Whoami());
    Log3 $name, 5, "$name ($self) - executed with count:'".scalar(@clients)."', ID:'".$clients[0]."'";
    
    my $id = shift @clients;
    HttpUtils_NonblockingGet( {
                 %{$hash->{httpParams}},
        url      => $hash->{unifi}->{url}."cmd/stamgr",
        callback => \&Unifi_DisconnectClient_Receive,
        clients  => [@clients],
        data     => "{\"mac\":\"".$hash->{clients}->{$id}->{mac}."\", \"cmd\":\"kick-sta\"}",
    } );
    
    return undef;
}
###############################################################################
sub Unifi_DisconnectClient_Receive($) {
    my ($param, $err, $data) = @_;
    my ($name,$self,$hash) = ($param->{hash}->{NAME},Unifi_Whoami(),$param->{hash});
    Log3 $name, 5, "$name ($self) - executed.";
    
    if ($err ne "") {
        Unifi_ReceiveFailure($hash,{rc => 'Error while requesting', msg => $param->{url}." - $err"});
    }
    elsif ($data ne "") {
        if ($param->{code} == 200 || $param->{code} == 400  || $param->{code} == 401) {
            eval { $data = decode_json($data); 1; } or do { $data = { meta => {rc => 'error.decode_json', msg => $@} }; };
            
            if ($data->{meta}->{rc} eq "ok") {
                Log3 $name, 5, "$name ($self) - state:'$data->{meta}->{rc}'";
            }
            else { Unifi_ReceiveFailure($hash,$data->{meta}); }
        } else {
            Unifi_ReceiveFailure($hash,{rc => $param->{code}, msg => "Failed with HTTP Code $param->{code}."});
        }
    }
    
    if (scalar @{$param->{clients}}) {
        Unifi_DisconnectClient_Send($hash,@{$param->{clients}});
    }
    
    return undef;
}
###############################################################################

sub Unifi_BlockClient_Send($$) {
  my ($hash,$mac) = @_;
  my ($name,$self) = ($hash->{NAME},Unifi_Whoami());
  Log3 $name, 5, "$name ($self) - executed with mac: '".$mac."'";
  HttpUtils_NonblockingGet( {
    %{$hash->{httpParams}},
    url   => $hash->{unifi}->{url}."cmd/stamgr",
    callback => \&Unifi_BlockClient_Receive,
    data => "{\"cmd\":\"block-sta\", \"mac\":\"".$mac."\"}",
  } );
  
  return undef;
}

###############################################################################
sub Unifi_BlockClient_Receive($) {
  my ($param, $err, $data) = @_;
  my ($name,$self,$hash) = ($param->{hash}->{NAME},Unifi_Whoami(),$param->{hash});
  Log3 $name, 5, "$name ($self) - executed.";

  if ($err ne "") {
    Unifi_ReceiveFailure($hash,{rc => 'Error while requesting', msg => $param->{url}." - $err"});
  }
  elsif ($data ne "") {
    if ($param->{code} == 200 || $param->{code} == 400 || $param->{code} == 401) {
      eval { $data = decode_json($data); 1; } or do { $data = { meta => {rc => 'error.decode_json', msg => $@} }; };

      if ($data->{meta}->{rc} eq "ok") {
        Log3 $name, 5, "$name ($self) - state:'$data->{meta}->{rc}'";
      }
      else { Unifi_ReceiveFailure($hash,$data->{meta}); }
    } else {
      Unifi_ReceiveFailure($hash,{rc => $param->{code}, msg => "Failed with HTTP Code $param->{code}."});
    }
  }

  return undef;
}

###############################################################################
sub Unifi_UnblockClient_Send($$) {
  my ($hash,$mac) = @_;
  my ($name,$self) = ($hash->{NAME},Unifi_Whoami());
  Log3 $name, 5, "$name ($self) - executed with mac: '".$mac."'";
  HttpUtils_NonblockingGet( {
    %{$hash->{httpParams}},
    url   => $hash->{unifi}->{url}."cmd/stamgr",
    callback => \&Unifi_UnblockClient_Receive,
    data => "{\"cmd\":\"unblock-sta\", \"mac\":\"".$mac."\"}",
  } );	
  return undef;
}
###############################################################################
sub Unifi_UnblockClient_Receive($) {
  my ($param, $err, $data) = @_;
  my ($name,$self,$hash) = ($param->{hash}->{NAME},Unifi_Whoami(),$param->{hash});
  Log3 $name, 5, "$name ($self) - executed.";

  if ($err ne "") {
    Unifi_ReceiveFailure($hash,{rc => 'Error while requesting', msg => $param->{url}." - $err"});
  }
  elsif ($data ne "") {
    if ($param->{code} == 200 || $param->{code} == 400 || $param->{code} == 401) {
      eval { $data = decode_json($data); 1; } or do { $data = { meta => {rc => 'error.decode_json', msg => $@} }; };

      if ($data->{meta}->{rc} eq "ok") {
        Log3 $name, 5, "$name ($self) - state:'$data->{meta}->{rc}'";
      }
      else { Unifi_ReceiveFailure($hash,$data->{meta}); }
    } else {
      Unifi_ReceiveFailure($hash,{rc => $param->{code}, msg => "Failed with HTTP Code $param->{code}."});
    }
  }

  return undef;
}

###############################################################################
sub Unifi_SwitchSiteLEDs_Send($$) {
  my ($hash,$state) = @_;
  my ($name,$self) = ($hash->{NAME},Unifi_Whoami());
  Log3 $name, 5, "$name ($self) - executed with command: '".$state."'";

  HttpUtils_NonblockingGet( {
    %{$hash->{httpParams}},
    url   => $hash->{unifi}->{url}."set/setting/mgmt",
    callback => \&Unifi_SwitchSiteLEDs_Receive,
    data => "{\"led_enabled\":".$state."}",
  } );
  return undef;
}
###############################################################################
sub Unifi_SwitchSiteLEDs_Receive($) {
  my ($param, $err, $data) = @_;
  my ($name,$self,$hash) = ($param->{hash}->{NAME},Unifi_Whoami(),$param->{hash});
  Log3 $name, 5, "$name ($self) - executed.";

  if ($err ne "") {
    Unifi_ReceiveFailure($hash,{rc => 'Error while requesting', msg => $param->{url}." - $err"});
  }
  elsif ($data ne "") {
    if ($param->{code} == 200 || $param->{code} == 400 || $param->{code} == 401) {
      eval { $data = decode_json($data); 1; } or do { $data = { meta => {rc => 'error.decode_json', msg => $@} }; };

      if ($data->{meta}->{rc} eq "ok") {
        Log3 $name, 5, "$name ($self) - state:'$data->{meta}->{rc}'";
      }
      else { Unifi_ReceiveFailure($hash,$data->{meta}); }
    } else {
      Unifi_ReceiveFailure($hash,{rc => $param->{code}, msg => "Failed with HTTP Code $param->{code}."});
    }
  }

  return undef;
}
###############################################################################
sub Unifi_WlanconfRest_Send($$@) {
    my ($hash,$id,$data) = @_;
    my ($name,$self) = ($hash->{NAME},Unifi_Whoami());
    my $json = encode_json( $data );
    Log3 $name, 5, "$name ($self) - executed with $json.";
    HttpUtils_NonblockingGet( {
                 %{$hash->{httpParams}},
        method   => "PUT",
        url      => $hash->{unifi}->{url}."rest/wlanconf/".$id,
        callback => \&Unifi_WlanconfRest_Receive,
        aps      => [],
        data     => $json,
    } );
    return undef;
}

sub Unifi_WlanconfRest_Receive($) {     
    my ($param, $err, $data) = @_;
    my ($name,$self,$hash) = ($param->{hash}->{NAME},Unifi_Whoami(),$param->{hash});
    Log3 $name, 5, "$name ($self) - executed.";
    
    if ($err ne "") {
        Unifi_ReceiveFailure($hash,{rc => 'Error while requesting', msg => $param->{url}." - $err"});
    }
    elsif ($data ne "") {
        if ($param->{code} == 200 || $param->{code} == 400  || $param->{code} == 401) {
            eval { $data = decode_json($data); 1; } or do { $data = { meta => {rc => 'error.decode_json', msg => $@} }; };
        } else {
            Unifi_ReceiveFailure($hash,{rc => $param->{code}, msg => "Failed with HTTP Code $param->{code}."});
        }
    }
    return undef;
}

###############################################################################
sub Unifi_GetVoucherList_Send($) {
    my ($hash) = @_;
    my ($name,$self) = ($hash->{NAME},Unifi_Whoami());
    Log3 $name, 5, "$name ($self) - executed.";
    
    HttpUtils_NonblockingGet( {
                 %{$hash->{httpParams}},
        method   => "GET",
        url      => $hash->{unifi}->{url}."stat/voucher",
        callback => \&Unifi_GetVoucherList_Receive,
    } );
    return undef;
}
#######################################

sub Unifi_GetVoucherList_Receive($) {
    my ($param, $err, $data) = @_;
    my ($name,$self,$hash) = ($param->{hash}->{NAME},Unifi_Whoami(),$param->{hash});
    Log3 $name, 5, "$name ($self) - executed.";
    
    if ($err ne "") {
        Unifi_ReceiveFailure($hash,{rc => 'Error while requesting', msg => $param->{url}." - $err"});
    }
    elsif ($data ne "") {
        my $dataString=$data;
        if ($param->{code} == 200 || $param->{code} == 400  || $param->{code} == 401) {
            eval { $data = decode_json($data); 1; } or do { $data = { meta => {rc => 'error.decode_json', msg => $@} }; };
            if ($data->{meta}->{rc} eq "ok") {
                Log3 $name, 5, "$name ($self) - state:'$data->{meta}->{rc}'";              
                $hash->{hotspot}->{vouchers} = $data->{data}; #array
            }
            else { Unifi_ReceiveFailure($hash,$data->{meta}); }
        } else {
            Unifi_ReceiveFailure($hash,{rc => $param->{code}, msg => "Failed with HTTP Code $param->{code}."});
        }
        # VoucherCache bereinigen um bereits verwendete / zu lange gecachte Voucher
        my $cachetime=time() - 2 * 60 * 60; #Maximal zwei Stunden
        for my $cache (keys %{$hash->{hotspot}->{voucherCache}}) {
            my $expand=0;
            if(ref($hash->{hotspot}->{voucherCache}->{$cache}) eq "HASH"){
                for my $voucher (keys %{$hash->{hotspot}->{voucherCache}->{$cache}}) {
                    if(ref($hash->{hotspot}->{voucherCache}->{$cache}->{$voucher}) eq "HASH" && defined $hash->{hotspot}->{voucherCache}->{$cache}->{$voucher}->{delivered_at}){
                        if($hash->{hotspot}->{voucherCache}->{$cache}->{$voucher}->{delivered_at} lt $cachetime){
                            delete $hash->{hotspot}->{voucherCache}->{$cache}->{$voucher};
                        }
                    }
                }
                #wenn Cache zu leer neue Voucher anlegen
                if($expand==0){ #Der Unifi-Controller mag es nicht, wenn man kurz  hintereinander zwei requests sendet, daher gleich mehrere auf einmal
                    my $minSize=$hash->{hotspot}->{voucherCache}->{$cache}->{minSize};
                    my $aktSize=$dataString =~ s/note.{1,5}$cache//g;
                    if(defined $minSize && $aktSize<$minSize){
                        my $setCmd=$hash->{hotspot}->{voucherCache}->{$cache}->{setCmd};
                        my @words=split("[ \t][ \t]*", $setCmd);
                        my %params=("expire"=>$words[0],"n"=>$words[1],"quota"=>$words[2],"note"=>$words[3]);
                        Log3 $name, 4, "$name ($self) - expand VoucherCache ($cache).";
                        Unifi_CreateVoucher_Send($hash, %params);
                        $expand=1;
                    }
                }
            }
        }
    }
    Unifi_NextUpdateFn($hash,$self);
    return undef;
}
###############################################################################

sub Unifi_CreateVoucher_Send($%) {
    my ($hash,%a)=@_;
    my $expire = $a{"expire"};
    my $n = $a{"n"};
    my $quota = $a{"quota"};
    my $note = $a{"note"};
    my ($name,$self) = ($hash->{NAME},Unifi_Whoami());
    Log3 $name, 5, "$name ($self) - executed. expire: ".$expire." - n: ".$n." - quota: ".$quota." - note: ".$note."    -    ".%a;
        
    HttpUtils_NonblockingGet( {
                 %{$hash->{httpParams}},
        url      => $hash->{unifi}->{url}."cmd/hotspot",
        callback => \&Unifi_CreateVoucher_Receive,
        data     => "{\"cmd\":\"create-voucher\", \"expire\":".$expire.", \"n\":".$n.", \"quota\":".$quota.", \"note\":\"".$note."\"}",
    } );
   
    return undef;
}
#######################################

sub Unifi_CreateVoucher_Receive($) {
    my ($param, $err, $data) = @_;
    my ($name,$self,$hash) = ($param->{hash}->{NAME},Unifi_Whoami(),$param->{hash});
    Log3 $name, 5, "$name ($self) - executed.";
    
    if ($err ne "") {
        Unifi_ReceiveFailure($hash,{rc => 'Error while requesting', msg => $param->{url}." - $err"});
    }
    elsif ($data ne "") {
        if ($param->{code} == 200 || $param->{code} == 400  || $param->{code} == 401) {
            eval { $data = decode_json($data); 1; } or do { $data = { meta => {rc => 'error.decode_json', msg => $@} }; };
        } else {
            Unifi_ReceiveFailure($hash,{rc => $param->{code}, msg => "Failed with HTTP Code $param->{code}."});
        }
    }
    # der Voucher ist im Unifi-Modul dann erst mit dem n�chsten Update enthalten.
    return undef;
}
###############################################################################

sub Unifi_ApCmd_Send($$@) {     #cmd: 'set-locate', 'unset-locate', 'restart', 'startRFScan'
    my ($hash,$cmd,@aps) = @_;
    my ($name,$self) = ($hash->{NAME},Unifi_Whoami());
    Log3 $name, 5, "$name ($self) - executed with cmd:'".$cmd."', count:'".scalar(@aps)."', ID:'".$aps[0]."'";
    
    my $id = shift @aps;
    HttpUtils_NonblockingGet( {
                 %{$hash->{httpParams}},
        url      => $hash->{unifi}->{url}."cmd/devmgr",
        callback => \&Unifi_DeviceCmd_Receive,
        aps      => [@aps],
        cmd      => $cmd,
        data     => "{\"mac\":\"".$hash->{accespoints}->{$id}->{mac}."\", \"cmd\":\"".$cmd."\"}",
    } );
    return undef;
}
sub Unifi_ApJson_Send($$) {
    my ($hash,$data) = @_;
    my ($name,$self) = ($hash->{NAME},Unifi_Whoami());
    my $json = encode_json( $data );
    Log3 $name, 5, "$name ($self) - executed with $json.";
    HttpUtils_NonblockingGet( {
                 %{$hash->{httpParams}},
        url      => $hash->{unifi}->{url}."cmd/devmgr",
        callback => \&Unifi_DeviceCmd_Receive,
        aps      => [],
        data     => $json,
    } );
    return undef;
}
sub Unifi_DeviceRestJson_Send($$$) {
    my ($hash,$id,$data) = @_;
    my ($name,$self) = ($hash->{NAME},Unifi_Whoami());
    my $json = encode_json( $data );
    Log3 $name, 5, "$name ($self) - executed with $json.";
    HttpUtils_NonblockingGet( {
                 %{$hash->{httpParams}},
        method   => "PUT",
        url      => $hash->{unifi}->{url}."rest/device/".$id,
        callback => \&Unifi_DeviceCmd_Receive,
        aps      => [],
        data     => $json,
    } );
    return undef;
}
sub Unifi_UserRestJson_Send($$$) {
    my ($hash,$id,$json) = @_;
    my ($name,$self) = ($hash->{NAME},Unifi_Whoami());
    Log3 $name, 5, "$name ($self) - executed for id $id with $json.";
    HttpUtils_NonblockingGet( {
                 %{$hash->{httpParams}},
        method   => "PUT",
        url      => $hash->{unifi}->{url}."rest/user/".$id,
        callback => \&Unifi_DeviceCmd_Receive,
        aps      => [],
        data     => $json,
    } );
    return undef;
}
###############################################################################
sub Unifi_DeviceCmd_Receive($) {
    my ($param, $err, $data) = @_;
    my ($name,$self,$hash) = ($param->{hash}->{NAME},Unifi_Whoami(),$param->{hash});
    Log3 $name, 5, "$name ($self) - executed.";
    
    if ($err ne "") {
        Unifi_ReceiveFailure($hash,{rc => 'Error while requesting', msg => $param->{url}." - $err"});
    }
    elsif ($data ne "") {
        if ($param->{code} == 200 || $param->{code} == 400  || $param->{code} == 401) {
            eval { $data = decode_json($data); 1; } or do { $data = { meta => {rc => 'error.decode_json', msg => $@} }; };
            
            if ($data->{meta}->{rc} eq "ok") {
                Log3 $name, 5, "$name ($self) - state:'$data->{meta}->{rc}'";
            }
            else { Unifi_ReceiveFailure($hash,$data->{meta}); }
        } else {
            Unifi_ReceiveFailure($hash,{rc => $param->{code}, msg => "Failed with HTTP Code $param->{code}."});
        }
    }
    
    if (scalar @{$param->{aps}}) {
        Unifi_ApCmd_Send($hash,$param->{cmd},@{$param->{aps}});
    }
    
    return undef;
}
###############################################################################
sub Unifi_UsergroupRestJson_Send($) {
    my ($hash) = @_;
    my ($name,$self) = ($hash->{NAME},Unifi_Whoami());
    Log3 $name, 5, "$name ($self) - executed.";
    HttpUtils_NonblockingGet( {
                 %{$hash->{httpParams}},
        method   => "GET",
        url      => $hash->{unifi}->{url}."rest/usergroup/",
        callback => \&Unifi_UsergroupRestJson_Receive,
    } );
    return undef;
}
sub Unifi_UsergroupRestJson_Receive($) {
    my ($param, $err, $data) = @_;
    my ($name,$self,$hash) = ($param->{hash}->{NAME},Unifi_Whoami(),$param->{hash});
    Log3 $name, 5, "$name ($self) - executed.";
    
    if ($err ne "") {
        Unifi_ReceiveFailure($hash,{rc => 'Error while requesting', msg => $param->{url}." - $err"});
    }
    elsif ($data ne "") {
        if ($param->{code} == 200 || $param->{code} == 400  || $param->{code} == 401) {
            eval { $data = decode_json($data); 1; } or do { $data = { meta => {rc => 'error.decode_json', msg => $@} }; };
            
            if ($data->{meta}->{rc} eq "ok") {
                Log3 $name, 5, "$name ($self) - state:'$data->{meta}->{rc}'";
                for my $h (@{$data->{data}}) {
                    $hash->{unifi}->{usergroups}->{$h->{_id}} = $h;					
                }
            }
            else { Unifi_ReceiveFailure($hash,$data->{meta}); }
        } else {
            Unifi_ReceiveFailure($hash,{rc => $param->{code}, msg => "Failed with HTTP Code $param->{code}."});
        }
    }
    
    return undef;
}
###############################################################################

sub Unifi_ArchiveAlerts_Send($) {
    my ($hash) = @_;
    my ($name,$self) = ($hash->{NAME},Unifi_Whoami());
    Log3 $name, 5, "$name ($self) - executed.";
    
    HttpUtils_NonblockingGet( {
                 %{$hash->{httpParams}},
        url      => $hash->{unifi}->{url}."cmd/evtmgr",
        callback => \&Unifi_Cmd_Receive,
        data     => "{\"cmd\":\"archive-all-alarms\"}",
    } );
    return undef;
}
###############################################################################

sub Unifi_Cmd_Receive($) {
    my ($param, $err, $data) = @_;
    my ($name,$self,$hash) = ($param->{hash}->{NAME},Unifi_Whoami(),$param->{hash});
    Log3 $name, 5, "$name ($self) - executed.";
    
    if ($err ne "") {
        Unifi_ReceiveFailure($hash,{rc => 'Error while requesting', msg => $param->{url}." - $err"});
    }
    elsif ($data ne "") {
        if ($param->{code} == 200 || $param->{code} == 400  || $param->{code} == 401) {
            eval { $data = decode_json($data); 1; } or do { $data = { meta => {rc => 'error.decode_json', msg => $@} }; };
            
            if ($data->{meta}->{rc} eq "ok") {
                Log3 $name, 5, "$name ($self) - state:'$data->{meta}->{rc}'";
            }
            else { Unifi_ReceiveFailure($hash,$data->{meta}); }
        } else {
            Unifi_ReceiveFailure($hash,{rc => $param->{code}, msg => "Failed with HTTP Code $param->{code}."});
        }
    }
    
    return undef;
}
###############################################################################

sub Unifi_ClientNames($@) {
    my ($hash,$ID,$W) = @_;
    
    my $clientRef;
    my $devAliases = AttrVal($hash->{NAME},"devAlias",0);
	my $attrCustomClientNames = AttrVal($hash->{NAME},"customClientNames",0);
    
    if(defined $ID && defined $W && $W eq 'makeAlias') {   # Return Alias from ID
        $clientRef = $hash->{clients}->{$ID};
        if (   ($devAliases && $devAliases =~ /$ID:(.+?)(\s|$)/)
            || ($devAliases && defined $clientRef->{name} && $devAliases =~ /$clientRef->{name}:(.+?)(\s|$)/)
            || ($devAliases && defined $clientRef->{hostname} && $devAliases =~ /$clientRef->{hostname}:(.+?)(\s|$)/)
           ) {
            $ID = $1;
        }elsif ( $attrCustomClientNames && defined $clientRef->{$attrCustomClientNames}){
            $ID = makeReadingName($clientRef->{$attrCustomClientNames});
		}elsif ( (defined $clientRef->{name} && $clientRef->{name} =~ /^([\w\.\-]+)$/)
              || (defined $clientRef->{hostname} && $clientRef->{hostname} =~ /^([\w\.\-]+)$/)
			){
            $ID = $1;
		}
        return $ID;
    }
    elsif (defined $ID && defined $W && $W eq 'makeID') {   # Return ID from Alias
        for my $clientID (keys %{$hash->{clients}}) {
            $clientRef = $hash->{clients}->{$clientID};
            my $goodName=makeReadingName($clientRef->{name}) if defined $clientRef->{name};
            my $goodHostname=makeReadingName($clientRef->{hostname}) if defined $clientRef->{hostname};
            if (   ($devAliases && $devAliases =~ /$clientID:$ID/)
                || ($devAliases && defined $clientRef->{name} && ($devAliases =~ /$clientRef->{name}:$ID/ || $devAliases =~ /$goodName:$ID/) )
                || ($devAliases && defined $clientRef->{hostname} && ($devAliases =~ /$clientRef->{hostname}:$ID/ || $devAliases =~ /$goodHostname:$ID/) )
			   ) {
                $ID = $clientID;
                last;
			}elsif ( $attrCustomClientNames && defined $clientRef->{$attrCustomClientNames} && $ID eq makeReadingName($clientRef->{$attrCustomClientNames})){
                $ID = $clientID;
                last;
            } elsif ( (defined $clientRef->{name} && ($clientRef->{name} eq $ID || $goodName eq $ID) ) 
                   || (defined $clientRef->{hostname} && ($clientRef->{hostname} eq $ID || $goodHostname eq $ID) )
               ) {
                $ID = $clientID;
                last;
            }
        }
        return $ID;
    }
    else {  # Return all clients in a scalar
        my $clients = '';
        for my $clientID (keys %{$hash->{clients}}) {
            $clients .= Unifi_ClientNames($hash,$clientID,'makeAlias').',';
        }
        $clients =~ s/.$//;
        
        return $clients;
    }
}
###############################################################################
sub Unifi_SSIDs($@){
    my ($hash,$ID,$W) = @_;
    
    my $wlanRef;
    
    if(defined $ID && defined $W && $W eq 'makeName') {   # Return Name from ID
        $wlanRef = $hash->{wlans}->{$ID};
        if (defined $wlanRef->{name} ){ #&& $wlanRef->{name} =~ /^([\w\.\-]+)$/) {
            $ID = makeReadingName($wlanRef->{name});
        }
        return $ID;
    }
    elsif (defined $ID && defined $W && $W eq 'makeID') {   # Return ID from Name 
        for (keys %{$hash->{wlans}}) {
            $wlanRef = $hash->{wlans}->{$_};
            if (defined $wlanRef->{name} && makeReadingName($wlanRef->{name}) eq $ID) {
                $ID = $_;
                last;
            }
        }
        return $ID;
    }
    else {  # Return all wlans in a scalar
        my $wlans = '';
        for my $wlanID (keys %{$hash->{wlans}}) {
            $wlans .= Unifi_SSIDs($hash,$wlanID,'makeName').',';
        }
        $wlans =~ s/.$//;
        
        return $wlans;
    }
}
###############################################################################
sub Unifi_ApNames($@) {
    my ($hash,$ID,$W) = @_;
    
    my $apRef;
    
    if(defined $ID && defined $W && $W eq 'makeName') {   # Return Name or IP from ID
        $apRef = $hash->{accespoints}->{$ID};
        if (   (defined $apRef->{name} && $apRef->{name} =~ /^([\w\.\-]+)$/) 
            || (defined $apRef->{ip} && $apRef->{ip} =~ /^([\w\.\-]+)$/)
           ) {
            $ID = $1;
        }
        return $ID;
    }
    elsif (defined $ID && defined $W && $W eq 'makeID') {   # Return ID from Name or IP
        for (keys %{$hash->{accespoints}}) {
            $apRef = $hash->{accespoints}->{$_};
            if (   (defined $apRef->{name} && $apRef->{name} eq $ID) 
                || (defined $apRef->{ip} && $apRef->{ip} eq $ID)
               ) {
                $ID = $_;
                last;
            }
        }
        return $ID;
    }
    else {  # Return all aps in a scalar
        my $aps = '';
        for my $apID (keys %{$hash->{accespoints}}) {
            $aps .= Unifi_ApNames($hash,$apID,'makeName').',';
        }
        $aps =~ s/.$//;
        
        return $aps;
    }
}
###############################################################################
sub Unifi_isUCversionHigherThan($$){
    my ($hash,$check) = @_;
	my ($name,$self) = ($hash->{NAME},Unifi_Whoami());
	my $ucversion=$hash->{UC_VERSION};
	if($ucversion eq "unknown"){
		Log3 $name, 2, "$name ($self) - unknown UC-Version. Please use set refreshUCversion";
		return 1; # Trotzdem true zur�ckgeben, k�nnte ja auch daran liegen, dass sysinfo bei neuer Version anders funktioniert
	}else{
		my($majorCheck, $minorCheck, $patchCheck)=split(/./,$ucversion);
		my($majorUC, $minorUC, $patchUC)=split(/./,$ucversion);
		if (defined $majorCheck && defined $majorUC && looks_like_number($majorCheck) && looks_like_number($majorUC) && $majorCheck < $majorUC){
			return 0;
		}elsif (defined $minorCheck && defined $minorUC && looks_like_number($minorCheck) && looks_like_number($minorUC) && $minorCheck < $minorUC){
			return 0;		
		}elsif (defined $patchCheck && defined $patchUC && looks_like_number($patchCheck) && looks_like_number($patchUC) && $patchCheck < $patchUC){
			return 0;		
		}
	}
	return 1;
}

###############################################################################

sub Unifi_initCustomClientReadings($){
    my ($hash) = @_;
	my ($name,$self) = ($hash->{NAME},Unifi_Whoami());
	my $ccr=$hash->{unifi}->{customClientReadings}->{attr_value};
	
	my @clientNameRegEx;
	my @parts=split(/ /,$ccr);
	if (scalar @parts < 1){
		return "Attr customClientReadings: Define at least one customClientReadings-part!";
	}
	my $partCount=0;
	foreach (@parts){
		my @part=split(/:/,$_);
		if (scalar @part > 2 ||scalar @part < 1 ){
			return "Attr customClientReadings: Exactly one : per part allowed!";
		}
		elsif(scalar @part == 1 ){
			push @part, "";
		}
		push @clientNameRegEx, $part[0];
		Log3 $name, 5, "$name ($self) - parsed part: $part[0]  ->  $part[1]";
		my $pc=substr("00000000".$partCount."_part", -12);
		$hash->{unifi}->{customClientReadings}->{parts}->{$pc}->{nameRegEx}=$part[0];
		$hash->{unifi}->{customClientReadings}->{parts}->{$pc}->{ReadingRegEx}=$part[1];
		$partCount++;
	}
	
    my $json = encode_json( $hash->{unifi}->{customClientReadings} );
    Log3 $name, 5, "$name ($self) - parsed Attribute customClientReadings: $json.";
    return undef;
}
###############################################################################

sub Unifi_initVoucherCache($){
    my ($hash) = @_;
    #return if ( ! defined $hash->{hotspot}->{voucherCache}->{attr_value});
    my @voucherCaches=split(/,/, $hash->{hotspot}->{voucherCache}->{attr_value});
    my @notes=();
    foreach(@voucherCaches){
        my $voucherCache=$_;
        my @words=split("[ \t][ \t]*", $voucherCache);
        if (scalar(@words) !=4){
            return "$hash->{NAME} voucherCache: Four arguments per cache needed!."
        }
        if (!looks_like_number($words[0]) || int($words[0]) < 1 || 
            !looks_like_number($words[1]) || int($words[1]) < 1 || 
            !looks_like_number($words[2]) || int($words[2]) < 1 
            ) {
            return "$hash->{NAME} voucherCache: First three arguments (expire, n, quota) must be numeric."
        }
        my $note=$words[3];
        push(@notes,$note);
        $hash->{hotspot}->{voucherCache}->{$note}->{setCmd} = $voucherCache;
        $hash->{hotspot}->{voucherCache}->{$note}->{minSize} = $words[1];
    }
    #ToDo: L�schen nicht mehr verwendeter Caches
    # dazu iterieren �ber $hash->{hotspot}->{voucherCache}
    # immer wenn es darin setCmd gibt ist oder war es ein Cache, ansonsten ist es attr_value
    # wenn $hash->{hotspot}->{voucherCache}->{$note} nicht in @notes, dann l�schen
    return undef;
}

###############################################################################

sub Unifi_getNextVoucherForNote($$){
    my ($hash,$getVal)=@_;
    my $deliverytime=time();
    my $returnedVoucher="";
    for my $voucher (@{$hash->{hotspot}->{vouchers}}) {
        my $note= '';
        if(defined $voucher->{note}){
            $note=$voucher->{note};
        }
        my $gv=$getVal;
        $note =~ tr/a-zA-Z�������_0-9.,//cd;
        $gv =~ tr/a-zA-Z�������_0-9.,//cd;
 
        if($gv eq 'all' || ( ($gv =~ /^$note/) && $note ne '')){
            if(! defined $hash->{hotspot}->{voucherCache}->{$getVal}->{$voucher->{_id}}->{delivered_at}){
                $returnedVoucher=$voucher;
                last;
            }else{
                if($hash->{hotspot}->{voucherCache}->{$getVal}->{$voucher->{_id}}->{delivered_at} < $deliverytime){
                    $deliverytime=$hash->{hotspot}->{voucherCache}->{$getVal}->{$voucher->{_id}}->{delivered_at};
                    $returnedVoucher=$voucher;
                }
            }
        }
    }
    return $returnedVoucher;
}
###############################################################################

sub Unifi_NextUpdateFn($$) {
    my ($hash,$fn) = @_;
    
    my $NextUpdateFn = 0;
    for (keys %{$hash->{updateDispatch}}) {   # {updateDispatch}->{callFn}[callFnRef,'receiveFn',receiveFnRef]
        if($hash->{updateDispatch}->{$_}[1] && $hash->{updateDispatch}->{$_}[1] eq $fn) {
            delete $hash->{updateDispatch}->{$_};
        } elsif(!$NextUpdateFn && $hash->{updateDispatch}->{$_}[0] && $_ ne 'Unifi_ProcessUpdate') {
            $NextUpdateFn = $hash->{updateDispatch}->{$_}[0];
        }
    }
    if (!$NextUpdateFn && $hash->{updateDispatch}->{Unifi_ProcessUpdate}[0]) {
        $NextUpdateFn = $hash->{updateDispatch}->{Unifi_ProcessUpdate}[0];
        delete $hash->{updateDispatch}->{Unifi_ProcessUpdate};
    }
    $NextUpdateFn->($hash) if($NextUpdateFn);
    return undef;
}
###############################################################################

sub Unifi_ReceiveFailure($$) {
    my ($hash,$meta) = @_;
    my ($name,$self) = ($hash->{NAME},Unifi_Whowasi());
    
    if (defined $meta->{msg}) {
        if (($meta->{msg} eq 'api.err.LoginRequired') || ($meta->{msg} =~ /Connection refused$/) || ($meta->{msg} =~ /SSL connect attempt failed$/)){
            Log3 $name, 5, "$name ($self) - LoginRequired detected...";
            if(Unifi_CONNECTED($hash)) {
                Log3 $name, 5, "$name ($self) - I am the first who detected LoginRequired. Do re-login...";
                Unifi_CONNECTED($hash,'disconnected');
                Unifi_DoUpdate($hash);
                return undef;
            }
        }
        elsif ($meta->{msg} eq "api.err.NoSiteContext") {
            Log3 $name, 1, "$name ($self) - Failed! - state:'$meta->{rc}' - msg:'$meta->{msg}'"
                           ." - This error indicates that the <siteID> in your definition is wrong."
                           ." Try to modify your definition with <sideID> = default.";
        }
        else {
            Log3 $name, 5, "$name ($self) - Failed! - state:'$meta->{rc}' - msg:'$meta->{msg}'";
        }
    } else {
        Log3 $name, 5, "$name ($self) - Failed (without message)! - state:'$meta->{rc}'";
    }
}
###############################################################################

sub Unifi_CONNECTED($@) {
    my ($hash,$set) = @_;
    
    if ($set) {
        $hash->{unifi}->{CONNECTED} = $set;
        RemoveInternalTimer($hash);
        %{$hash->{updateDispatch}} = ();
        if (!defined($hash->{READINGS}->{state}->{VAL}) || $hash->{READINGS}->{state}->{VAL} ne $set) {
            readingsSingleUpdate($hash,"state",$set,1);
        }
        return undef;
    } 
    else {
        if ($hash->{unifi}->{CONNECTED} eq 'disabled') {
            return 'disabled';
        }
        elsif ($hash->{unifi}->{CONNECTED} eq 'connected') {
            return 1;
        } else {
            return 0;
        }
    }
}

###############################################################################

sub
Unifi_encrypt($)
{
  my ($decoded) = @_;
  my $key = getUniqueId();
  my $encoded;

  return $decoded if( $decoded =~ /^crypt:(.*)/ );

  for my $char (split //, $decoded) {
    my $encode = chop($key);
    $encoded .= sprintf("%.2x",ord($char)^ord($encode));
    $key = $encode.$key;
  }

  return 'crypt:'. $encoded;
}
sub
Unifi_decrypt($)
{
  my ($encoded) = @_;
  my $key = getUniqueId();
  my $decoded;

  $encoded = $1 if( $encoded =~ /^crypt:(.*)/ );

  for my $char (map { pack('C', hex($_)) } ($encoded =~ /(..)/g)) {
    my $decode = chop($key);
    $decoded .= chr(ord($char)^ord($decode));
    $key = $decode.$key;
  }

  return $decoded;
}
###############################################################################

sub Unifi_Whoami()  { return (split('::',(caller(1))[3]))[1] || ''; }
sub Unifi_Whowasi() { return (split('::',(caller(2))[3]))[1] || ''; }
###############################################################################


1;


=pod
=item device
=item summary    Interpret / control of Ubiquiti Networks UniFi-controller
=item summary_DE Auswertung / Steuerung eines Ubiquiti Networks UniFi-Controller
=begin html

<a name="Unifi"></a>
<h3>Unifi</h3>
<ul>

Unifi is the FHEM module for the Ubiquiti Networks (UBNT) - Unifi Controller.<br>
<br>
e.g. you can use the 'presence' function, which will tell you if a device is connected to your WLAN (even in PowerSave Mode!).<br>
Immediately after connecting to your WLAN it will set the device-reading to 'connected' and about 5 minutes after leaving your WLAN it will set the reading to 'disconnected'.<br>
The device will be still connected, even it is in PowerSave-Mode. (In this mode the devices are not pingable, but the connection to the unifi-controller does not break off.)<br>
<br>
Or you can use the other readings or set and get features to control your unifi-controller, accesspoints and wlan-clients.
<br>
<h4>Prerequisites</h4>
  <ul>
      The Perl module JSON is required. <br>
      On Debian/Raspbian: <code>apt-get install libjson-perl </code><br>
      Via CPAN: <code>cpan install JSON</code>
  </ul>

<h4>Define</h4>
<ul>
    <code>define &lt;name&gt; Unifi &lt;ip&gt; &lt;port&gt; &lt;username&gt; &lt;password&gt; [&lt;interval&gt; [&lt;siteID&gt;]]</code>
    <br><br>
	<br>
    &lt;name&gt;:
    <ul>
    <code>The FHEM device name for the device.</code><br>
    </ul>
    &lt;ip&gt;:
    <ul>
    <code>The ip of your unifi-controller.</code><br>
    </ul>
    &lt;port&gt;:
    <ul>
    <code>The port of your unifi-controller. Normally it's 8443 or 443.</code><br>
    </ul>
    &lt;username&gt;:
    <ul>
    <code>The Username to log on.</code><br>
    </ul>
    &lt;password&gt;:
    <ul>
    <code>The password to log on.</code><br>
    </ul>
    [&lt;interval&gt;]:
    <ul>
    <code>(optional without &lt;siteID&gt)<br>
          Interval to fetch the information from the unifi-api. <br>
          default: 30 seconds</code><br>
    </ul>
    [&lt;siteID&gt;]:
    <ul>
    <code>(optional)<br>
          You can find the site-ID by selecting the site in the UniFi web interface.<br>
          e.g. https://192.168.12.13:8443/manage/s/foobar the siteId you must use is: foobar.<br>
          default: default</code><br>
    </ul> <br>

</ul>
<h4>Examples</h4>
<ul>
    <code>define my_unifi_controller Unifi 192.168.1.15 443 admin secret</code><br>
    <br>
    Or with optional parameters &lt;interval&gt; and &lt;siteID&gt; :<br>
    <code>define my_unifi_controller Unifi 192.168.1.15 443 admin secret 30 default</code><br>
</ul>

<h4>Set</h4>
<ul>
    <code>Note: Some setters are not available if controller is not connected, or no data is available for them.</code><br>
    <br>
    <li><code>set &lt;name&gt; update</code><br>
    Makes immediately a manual update. </li>
    <br>
    <li><code>set &lt;name&gt; updateClient &lt;mac&gt;</code><br>
    Makes immediately a manual update of the client specified by MAC-Adress. </li>
    <br>
    <li><code>set &lt;name&gt; clear &lt;readings|clientData|voucherCache|all&gt;</code><br>
    Clears the readings, clientData, voucherCache or all. </li>
    <br>
    <li><code>set &lt;name&gt; archiveAlerts</code><br>
    Archive all unarchived Alerts. </li>
    <br>
    <li><code>set &lt;name&gt; disconnectClient &lt;all|user_id|controllerAlias|hostname|devAlias&gt;</code><br>
    Disconnect one ore all clients. </li>
    <br>
    <li><code>set &lt;name&gt; restartAP &lt;all|_id|name|ip&gt;</code><br>
    Restart one ore all accesspoints. </li>
    <br>
    <li><code>set &lt;name&gt; setLocateAP &lt;all|_id|name|ip&gt;</code><br>
    Start 'locate' on one or all accesspoints.</li>
    <br>
    <li><code>set &lt;name&gt; unsetLocateAP &lt;all|_id|name|ip&gt;</code><br>
    Stop 'locate' on one or all accesspoints. </li>
    <br>
    <li><code>set &lt;name&gt; startRFScan &lt;all|_id|name|ip&gt;</code><br>
    Start 'RF-Scan' on one or all accesspoints. Does not work with 1. Gen APs. </li>
    <br>
    <li><code>set &lt;name&gt; blockClient &lt;clientname&gt;</code><br>
    Block the &lt;clientname&gt;. Can also be called with the mac-address of the client.</li>
    <br>
    <li><code>set &lt;name&gt; unblockClient &lt;clientname&gt;</code><br>
    Unblocks the &lt;clientname&gt;. Can also be called with the mac-address of the client.</li>
    <br>
    <li><code>set &lt;name&gt; disableWLAN &lt;ssid&gt;</code><br>
    Disables WLAN with &lt;ssid&gt;</li>
    <br>
    <li><code>set &lt;name&gt; enableWLAN &lt;ssid&gt;</code><br>
    Enables WLAN with &lt;ssid&gt;</li>
    <br>
    <li><code>set &lt;name&gt; switchSiteLEDs &lt;on|off&gt;</code><br>
    Enables or disables the Status-LED settings of the site.</li>
    <br>
    <li><code>set &lt;name&gt; createVoucher &lt;expire&gt; &lt;n&gt; &lt;quota&gt; &lt;note&gt;</code><br>
    Creates &lt;n&gt; vouchers that expires after &lt;expire&gt; minutes, are usable &lt;quota&gt;-times with a &lt;note&gt;no spaces in note allowed</li>
    <br>
    <li><code>set &lt;name&gt; removeClientReadings &lt;clientname&gt;</code><br>
    Deletes the readings for &lt;clientname&gt;. Only disconnected clients should be removed, because connected clients will create readings in next update-cycle.</li>
    <br>
    <li><code>set &lt;name&gt; refreshUCversion</code><br>
    Refresh the INTERNAL-value for the version of your unifi-controller.</li>
    <br>
    <li><code>set &lt;name&gt; refreshUsergroups</code><br>
    Usergroups won't be updated automatically. Use this setter to update usergroups manually.</li>
    <br>
</ul>


<h4>Get</h4>
<ul>
    <code>Note: Some getters are not available if no data is available for them.</code><br>
    <br>
    <li><code>get &lt;name&gt; clientData &lt;all|user_id|controllerAlias|hostname|devAlias&gt;</code><br>
    Show more details about clients.</li>
    <br>
    <li><code>get &lt;name&gt; events</code><br>
    Show events in specified 'eventPeriod'.</li>
    <br>
    <li><code>get &lt;name&gt; unarchivedAlerts</code><br>
    Show all unarchived Alerts.</li>
    <br>
    <li><code>get &lt;name&gt; voucher [note]</code><br>
    Show next voucher-code with specified note. If &lt;note&gt; is used in voucherCache the voucher will be marked as delivered</li>
    <br>
    <li><code>get &lt;name&gt; voucherList [all|note]</code><br>
    Show list of vouchers (all or with specified note only).</li>
    <br>
    <li><code>get &lt;name&gt; showAccount</code><br>
    Show decrypted user and passwort.</li>
    <br>
</ul>


<h4>Attributes</h4>
<ul>
    <li>attr devAlias<br>
    Can be used to rename device names in the format <code>&lt;user_id|controllerAlias|hostname&gt;:Aliasname.</code><br>
    Separate using blank to rename multiple devices.<br>
    Example (user_id):<code> attr unifi devAlias 5537d138e4b033c1832c5c84:iPhone-Claudiu</code><br>
    Example (controllerAlias):<code> attr unifi devAlias iPhoneControllerAlias:iPhone-Claudiu</code><br>
    Example (hostname):<code> attr unifi devAlias iphone:iPhone-Claudiu</code><br></li>
    <br>
    <li>attr eventPeriod  &lt;1...168&gt;<br>
    Can be used to configure the time-period (hours) of fetched events from controller.<br>
    <code>default: 24</code></li>
    <br>
    <li>attr disable &lt;1|0&gt;<br>
    With this attribute you can disable the whole module. <br>
    If set to 1 the module will be stopped and no updates are performed.<br>
    If set to 0 the automatic updating will performed.</li>
    <br>
    <li>attr ignoreWiredClients &lt;1|0&gt;<br>
    With this attribute you can disable readings for wired clients. <br>
    If set to 1 readings for wired clients are not generated.<br>
    If set to 0 or not defined, readings for wired clients will be generated.</li>
    <br>
    <li>attr ignoreWirelessClients &lt;1|0&gt;<br>
    With this attribute you can disable readings for wireless clients. <br>
    If set to 1 readings for wireless clients are not generated.<br>
    If set to 0 or not defined, readings for wireless clients will be generated.</li>
    <br>
    <li>attr <a href="#verbose">verbose</a> 5<br>
    This attribute will help you if something does not work as espected.</li>
    <br>
    <li>attr httpLoglevel <1,2,3,4,5><br>
    Can be used to debug the HttpUtils-Module. Set it smaller or equal as your 'global verbose level'.<br>
    <code>default: 5</code></li>
    <br>
    <li>attr voucherCache  &lt;expire n quota note, ...&gt;<br>
    Define voucher-cache(s). Comma separeted list of four parameters that are separated by spaces; no spaces in note!.<br>
    By calling <code>get voucher &lt;note&gt;</code> the delivery-time of the voucher will be saved in the cache. 
    The voucher with the oldest delivery-time will be returned by <code>get voucher &lt;note&gt;</code>.
    If the voucher is not used for 2 hours, the delivery-time in the cache will be deleted.<br>
    <code>e.g.: 120 2 1 2h,180 5 2 3h</code> defines two caches.<br>
    The first cache has a min size of 2 vouchers. The vouchers expire after 120 minutes and can be used one-time.<br>
    The second cache has a min size of 5 vouchers. The vouchers expire after 180 minutes and can be used two-times.</li>
    <br>
    <li>attr customClientReadings clientNameRegEx1:ClientReadingRegEx1 clientNameRegEx2:ClientReadingRegEx2 ...<br>
    Can be used to customize the readings for clients. <br>
    <code>default: .:^accesspoint$|^essid$|^hostname$|^last_seen$|^snr$|^uptime$</code> Note: rssi ist called snr in old default before attr customClientReadings.</li>
    <br>
   <li>attr customClientNames &lt;value&gt;<br>
    Can be used to control the naming convention for client readings. Any valid clientData field is allowed, though only <code>mac</code> seems to be useful. For a list, see <code>&lt;unifi&gt; get ClientData all</code>.<br>
    When using formatted readings (reading is named like &lt;clientName&gt;<b>_f_</b>...) with disconnected clients e.g. in DOIF or notifies, also specify the unformatted value as customClientReading.<br> 
	e.g. ^_f_last_seen_duration$|^last_seen$<br>
	Reason: Disconnected clients won't be send by UnifiController and are loosing their values when restarting fhem. 
	The UnifiModul tries to restore the clients from existing readings. This won't work for formatted readings if the unformatted value hasn't a reading itself.<br>
	Client naming follows these rules: 
       <ol> 
          <li><code>devAlias</code> (if present for this client)</li>
          <li>attribute <code>customClientNames</code> (if it is set <i>and</i> the corresponding data field exists for client)</li>
          <li>name (alias) in Unifi-Controller</li>
          <li>hostname of the client</li>
       </ol>
    </li>
    <br>
    <li><a href="#readingFnAttributes">readingFnAttributes</a></li>
</ul>

<h4>Readings</h4>
<ul>
    Note: All readings generate events. You can control this with <a href="#readingFnAttributes">these global attributes</a>.
    <li>When clientnames start with a . (dot), FHEMWEB hides readings for this client when global showInternal Values ne 1.</li>
    <li>Each client has 7 readings for connection-state, SNR, uptime, last_seen-time, connected-AP, essid and hostname if attribute customClientReadings is not used.</li>
    <li><code>-UC_newClients</code>&nbsp;shows names of a new clients, could be a comma-separated list. Will be set to empty at next interval.</li>
    <li><code>-UC_blockedClients</code>&nbsp;shows names of a blocked clients, could be a comma-separated list.</li>
    <li>Each AP has 5 readings for state (can be 'ok' or 'error'), essid's, utilization, locate and count of connected-clients.</li>
    <li>The unifi-controller has 6 readings for event-count in configured 'timePeriod', unarchived-alert count, accesspoint count, overall wlan-state (can be 'ok', 'warning', or other?), connected user count and connected guest count. </li>
    <li>The unifi-controller has also readings for wan_ip and results of the speedtest (UC_speed_ping,UC_speed_down,UC_speed_up). </li>
    <li>The Unifi-device reading 'state' represents the connection-state to the unifi-controller (can be 'connected', 'disconnected', 'initialized' and 'disabled').</li>
    <li>Each voucher-cache has a reading with the next free voucher code.</li>
</ul>
<br>

</ul>

=end html
=cut
