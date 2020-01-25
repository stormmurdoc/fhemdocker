package main;

use strict;
use warnings;
use HTTP::Request;
use LWP::UserAgent;
use IO::Socket::SSL;
use utf8;
use Crypt::CBC;
use Crypt::Cipher::AES;

sub gcmsend_Initialize($)
{
    my ($hash) = @_;
    $hash->{DefFn} = "gcmsend_Define";
    $hash->{NotifyFn} = "gcmsend_notify";
    $hash->{AttrFn} = "gcmsend_attr";
    $hash->{SetFn} = "gcmsend_set";
    $hash->{AttrList} = "loglevel:0,1,2,3,4,5 regIds apiKey stateFilter vibrate deviceFilter cryptKey";
}

sub gcmsend_attr {
    my ($cmd, $name, $aName, $aVal) = @_;
    if (not $aName eq "cryptKey") {
        return undef;
    }
    $aVal = sprintf("%016s", $aVal);
    $aVal = substr $aVal, length($aVal) - 16, 16;
    $_[3] = $aVal;
    return undef;
}

sub gcmsend_set {
    my ($hash, @a) = @_;
    my $v = @a[1];
    if ($v eq "delete_saved_states") {
        $hash->{STATES} = { };
        return "deleted";
    } elsif ($v eq "send") {
        my $msg = "";
        for (my $i = 2; $i < int(@a); $i++) {
            if (!($msg eq "")) {
                $msg .= " ";
            }
            $msg .= @a[$i];
        }
        return gcmsend_sendMessage($hash, $msg);
    } else {
        return "unknown set value, choose one of delete_saved_states send";
    }
}

sub gcmsend_Define($$)
{
    my ($hash, $def) = @_;

    my @args = split("[ \t]+", $def);

    if (int(@args) < 1)
    {
        return "gcmsend_Define: too many arguments. Usage:\n".
            "define <name> gcmsend";
    }
    return "Invalid arguments. Usage: \n define <name> gcmsend" if (int(@args) != 2);

    $hash->{STATE} = 'Initialized';

    return undef;
}

sub gcmsend_array_to_json(@) {
    my (@array) = @_;
    my $ret = "";

    for (my $i = 0; $i < int(@array); $i++) {
        if ($i != 0) {
            $ret .= ",";
        }
        my $value = @array[$i];
        $ret .= ("\"".$value."\"");
    }

    return "[".$ret."]";
}

sub gcmsend_sendPayload($%) {
    my ($hash, %payload) = @_;
    my %generalPayload = gcmsend_getGeneralPayload($hash);
    my %toSendPayload = (%generalPayload, %payload);
    my %encryptedPayload = gcmsend_encrypt($hash, %toSendPayload);

    my $jsonPayload = gcmsend_toJson(%encryptedPayload);

    my $name = $hash->{NAME};

    my $logLevel = GetLogLevel($name, 5);

    my $client = LWP::UserAgent->new();
    my $regIdsText = AttrVal($name, "regIds", "");

    my $apikey = AttrVal($name, "apiKey", "");
    my @registrationIds = split(/\|/, $regIdsText);

    if (int(@registrationIds) == 0) {
        Log $logLevel, "$name no registrationIds set.";
        return undef;
    }
    return undef if (int(@registrationIds) == 0);

    my $data =
        "{".
            "\"registration_ids\":".gcmsend_array_to_json(@registrationIds).",".
	    "\"priority\": \"high\"" . "," .
            "\"data\": $jsonPayload".
            "}";

    Log $logLevel, "data is $jsonPayload";

    my $req = HTTP::Request->new( POST => "https://android.googleapis.com/gcm/send" );
    $req->header( Authorization => 'key='.$apikey );
    $req->header( 'Content-Type' => 'application/json; charset=UTF-8' );
    $req->content( $data );

    my $response = $client->request( $req );
    if (!$response->is_success) {
        Log $logLevel, "error during request: ".$response->status_line;
        $hash->{STATE} = $response->status_line;
    }
    $hash->{STATE} = "OK";
    return undef;
}

sub gcmsend_getGeneralPayload($) {
    my ($hash) = @_;

    my $name = $hash->{NAME};

    my $vibrate = "false";
    if (AttrVal($name, "vibrate", "false") eq "true") {
        $vibrate = "true";
    }

    my $gcmName = $hash->{NAME};

    my %generalPayload = (
        "source"        => "gcmsend_fhem",
        "gcmDeviceName" => $gcmName,
        "vibrate"       => "$vibrate"
    );
    return %generalPayload;
}

sub gcmsend_sendNotify($$$) {
    my ($hash, $deviceName, $changes) = @_;
    my %payload = (
        "deviceName" => $deviceName,
        "changes"    => $changes,
        "type"       => "notify"
    );
    gcmsend_sendPayload($hash, %payload);
}

sub gcmsend_toJson(%) {
    my (%hash) = @_;
    my @entries = ();

    while (my ($key, $value) = each %hash) {
        my $entry = "\"$key\":\"$value\"";
        push @entries, $entry;
    }
    return "{".join(", ", @entries)."}";
}

my %gcmsend_encrypt_keys = ("type" => "", "notifyId" => "", "changes" => "", "deviceName" => "",
    "tickerText"                   => "", "contentText" => "", "contentTitle" => "");
sub gcmsend_encrypt($%) {
    my ($hash, %payload) = @_;
    my $key = AttrVal($hash->{NAME}, "cryptKey", "");
    if ($key eq "") {
        return %payload;
    }

    my $cipher = Crypt::CBC->new(
        -cipher      => 'Crypt::Cipher::AES',
        -key         => $key,
        -iv          => $key,
        -padding     => 'standard',
        -header      => 'none',
        -blocksize   => '16',
        -literal_key => 1,
        -keysize     => 16
    );
    my %newPayload = ();
    while (my ($key, $value) = each %payload) {
        if (exists(%gcmsend_encrypt_keys->{$key})) {
            my $padded = sprintf '%16s', $value;
            my $length = length($padded);

            %newPayload->{$key} = $cipher->encrypt_hex( $value );
        } else {
            %newPayload->{$key} = $value;
        }
    }
    return %newPayload;
}

sub gcmsend_sendMessage($$) {
    my ($hash, $message) = @_;

    my @parts = split(/\|/, $message);

    my $tickerText;
    my $contentTitle;
    my $contentText;
    my $notifyId = 1;

    my $length = int(@parts);

    if ($length == 3 || $length == 4) {
        $tickerText = @parts[0];
        $contentTitle = @parts[1];
        $contentText = @parts[2];

        if ($length == 4) {
            my $notifyIdText = @parts[3];
            if (!(@parts[3] =~ m/[1-9][0-9]*/)) {
                return "notifyId must be numeric and positive";
            }
            $notifyId = @parts[3];
        }
    } else {
        return "Illegal message format. Required format is \r\n ".
            "tickerText|contentTitle|contentText[|NotifyID]";
    }
    my %payload = (
        "tickerText"   => $tickerText,
        "contentTitle" => $contentTitle,
        "contentText"  => $contentText,
        "notifyId"     => $notifyId,
        "type"         => "message"
    );
    gcmsend_sendPayload($hash, %payload);

    return undef;
}


sub gcmsend_getLastDeviceStatesFor($$)
{
    my ($gcm, $deviceName) = @_;

    if (!$gcm->{STATES}) {
        $gcm->{STATES} = { };
    }

    my $states = $gcm->{STATES};
    if (!$states->{$deviceName}) {
        $states->{$deviceName} = { };
    }

    return $states->{$deviceName};
}

sub gcmsend_notify($$)
{
    my ($gcm, $dev) = @_;

    my $logLevel = GetLogLevel($gcm, 5);

    my $name = $dev->{NAME};
    my $gcmName = $gcm->{NAME};

    my $deviceFilter = AttrVal($gcm->{NAME}, "deviceFilter", "");

    return if $name eq $gcmName;
    return if (!$dev->{CHANGED}); # Some previous notify deleted the array.
    return if (!($deviceFilter eq "") && !($name =~ m/$deviceFilter/));

    my $stateFilter = AttrVal($gcm->{NAME}, "stateFilter", "");

    my $lastDeviceStates = gcmsend_getLastDeviceStatesFor($gcm, $name);

    my $val = "";
    my $nrOfFieldChanges = int(@{$dev->{CHANGED}});
    my $sendFieldCount = 0;

    for (my $i = 0; $i < $nrOfFieldChanges; $i++) {
        my @keyValue = split(":", $dev->{CHANGED}[$i]);
        my $change = $dev->{CHANGED}[$i];


        # We need to find out a key and a value for each field update.
        # For state updates, we have not field, which is why we simply
        # put it to "state".
        # For all other updates the notify value is delimited by ":",
        # which we use to find out the value and the key.
        my $key;
        my $value;
        my $position = index($change, ':');
        if ($position == -1) {
            $key = "state";
            $value = $keyValue[0];
        } else {
            $key = substr($change, 0, $position);
            $value = substr($change, $position + 2, length($change));
        }

        if (!($stateFilter eq "") && !($value =~ m/$stateFilter/)) {
            Log $logLevel,
                "$gcmName $name: ignoring $key, as value $value is blocked by stateFilter regexp.";
        } elsif ($value eq "") {
            Log $logLevel, "$gcmName $name: ignoring $key, as value is empty.";
        } elsif ($lastDeviceStates->{$key} && $lastDeviceStates->{$key} eq $value) {
            my $savedValue = $lastDeviceStates->{$key};
            Log $logLevel,
                "$gcmName $name: ignoring $key, save value is $savedValue, value is $value";
        } else {
            $lastDeviceStates->{$key} = $value;
            # Multiple field updates are separated by <|>.
            if ($sendFieldCount != 0) {
                $val .= "<|>";
            }
            $sendFieldCount += 1;
            $val .= "$key:$value";
        }
    }
    if ($sendFieldCount > 0) {
        gcmsend_sendNotify($gcm, $name, $val);
    }
}

1;

=pod
=begin html

<a name="GCMSend"></a>
<h3>GCMSend</h3>
<ul>
  Google Cloud Messaging (GCM) is a toolset to send push notifications to Android handset
  devices. This can be used to refresh the internal state of, for example, andFHEM to achieve
  a nearly up-to-date internal state of other applications. <br/>
  The module pushes any internal updates to GCM, which can be used by other apps. As payload,
  there is a data hash including the deviceName, the source (which is always gcmsend_fhem) and
  an amount of changes. The changes are concatenated by "<|>", whereas each change itself is formatted
  like "key:value". <br />
  For instance, the changes could look like: "state:on<|>measured:2013-08-11".
  <br />
  Note: If not receiving messages, make sure to increase the log level of this device. Afterwards,
  have a look at the log messages - the module is quite verbose.
  <br><br>

  <a name="GCMSenddefine"></a>
  <h4>Define</h4>
  <ul>
    <code>define &lt;name&gt; gcmsend</code>
    <br><br>

    Defines a GCMSend device.<br><br>

    Example:
    <ul>
      <code>define gcm gcmsend</code><br>
    </ul>
    Notes:
    <ul>
      <li>Module to send messages to GCM (Google Cloud Messaging).</li>
      <li>Prerequisite is a GCM Account (see <a href="https://code.google.com/apis/console/">Google API Console</a></li>
      <li>Futhermore <code>Crypt::CBC</code> and <code>Crypt::Cipher::AES</code> Perl modules have to be installed 
    </ul>
  </ul>

  <a name="GCMSendSet"></a>
  <h4>Set </h4>
  <ul>
    <code>set &lt;name&gt; &lt;value&gt;</code>
    <br><br>
    where <code>value</code> is one of:<br>
    <pre>
    delete_saved_states    # deletes all saved states
    send                   # send a message (tickerText|contentTitle|contentText[|NotifyID])
    </pre>

    Examples:
    <ul>
      <code>set gcm delete_saved_states</code><br>
      <code>set gcm send ticker text|my title|my text|5</code><br/>
    </ul>
  </ul>

  <a name="GCMSendAttr"></a>
  <h4>Attributes</h4> 
  <ul>
    <li><a name="gcmsend_regIds"><code>attr &lt;name&gt; regIds &lt;string&gt;</code></a>
                <br />Registration IDs Google sends the messages to (multiple values separated by "|"</li>
    <li><a name="gcmsend_apiKey"><code>attr &lt;name&gt; apiKey &lt;string&gt;</code></a>
                <br />API-Key for GCM (can be found within the Google API Console)</li>
    <li><a name="gcmsend_stateFilter"><code>attr &lt;name&gt; stateFilter &lt;regexp&gt;</code></a>
                <br />Send a GCM message only if the attribute matches the attribute filter regexp</li>
    <li><a name="gcmsend_vibrate"><code>attr &lt;name&gt; vibrate (true|false)</a>
                <br />Make the receiving device vibrate upon receiving the message. Must be true or false.</li>
    <li><a name="gcmsend_deviceFilter"><code>attr &lt;name&gt; deviceFilter &lt;regexp&gt;</a>
                <br />Send a GCM notify only is the device name matches the given filter regexp.</li>
    <li><a name="gcmsend_cryptKey"><code>attr &lt;name&gt; cryptKey &lt;key&gt;</a> <br/>Some key to encrypt message content. The key must have a size of 16 bytes. If the key length does not match it will be either cut or padded to the required length. As encryption algorithm AES is used.</li>
  </ul>
</ul>

=end html
=cut


