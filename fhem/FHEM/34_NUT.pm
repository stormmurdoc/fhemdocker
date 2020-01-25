#
# $Id: 34_NUT.pm 9023 2015-08-05 09:00:12Z narsskrarc $
#
# Abfrage einer UPS über die Network UPS Tools (www.networkupstools.org)
#
# 05.08.2015
#

# DEFINE bla NUT <upsname> [<host>[:<port>]]
# Readings:
#  Da sind alle realisierbar, die die USV liefert.
#  Auf jeden Fall dabei ist
#    ups.status
#  da das auch den Status des Geräts ergibt.
#  Weitere sind mit dem Attribut asReadings definierbar (s.a. TODO).
#
# Attrs:
#  disable:0,1	Polling abklemmen
#  pollState	Häufigkeit, mit der der Status der USV abgefragt wird (Default 5 sec)
#  pollVal	Häufigkeit, mit der die anderen Readings abgefragt werden (Default 60 sec, Vielfaches von pollState)
#  asReadings	Mit Kommata getrennte Liste der Werte der USV, die als Readings zur Verfügung stehen sollen
#  $readingFnAttributes
#
#

#
# TODO
# A - Alive setzen
# A - Sollte man als Reading einfach die Bezeichnung der USV nehmen (also z.B. input.voltage) oder 
#     Aliase nehmen (z.B. voltage) bzw. modifizierte Bezeichnungen (z.B. inputVoltage)?
# B - attr pollInterval: Wertebereich prüfen (min. 5, max. ?)
# B - Zugriff auf Attribute per AttrVal
# C - per GET könnte man alle Werte der USV verfügbar machen
# D - SET implementieren, um diverse Dinge mit der USV anstellen zu können (Test, Ausschalten, ...)
# D - Für die Web-Oberfläche wäre es vermutlich schick, wenn man die veränderbaren Variablen auch verändern könnte,
#     inklusive den ENUMs und RANGEs, die NUT für die Werte anbietet
#
#
# FIXME
# - Fehlermeldung in fhem.log: "Notify Loop for..." Wieso?
#


package main;
use strict;
use warnings;
use POSIX;


sub NUT_Initialize($);
sub NUT_Define($$);
sub NUT_Undef($$);
sub NUT_Ready($);
sub NUT_DevInit($);
sub NUT_Read($);
sub NUT_ListVar($);
sub NUT_Auswertung($);
sub NUT_makeReadings($);




sub NUT_Initialize($) {
  my ($hash) = @_;

  require "$attr{global}{modpath}/FHEM/DevIo.pm";

  $hash->{DefFn}   = "NUT_Define";
  $hash->{UndefFn} = "NUT_Undef";
  $hash->{ReadyFn} = "NUT_Ready";
  $hash->{ReadFn}  = "NUT_Read";

  $hash->{AttrList} = "disable:0,1 pollState pollVal asReadings ".
                      $readingFnAttributes;
}


sub NUT_Define($$) {
  my ( $hash, $def ) = @_;
  my @a = split( "[ \t][ \t]*", $def );


  # Syntaxprüfung

  if (@a < 3 or @a > 4) {
    my $msg = "wrong syntax: define <name> NUT <upsname> [<host>[:<port>]]";
    Log3 $hash, 2, $msg;
    return $msg;
  }
  DevIo_CloseDev($hash);


  # Parameter auswerten

  my $name = $a[0];
  $hash->{UpsName} = $a[2];

  my $dev = $a[3];
  if (defined $dev) {
     $dev .= ":3493" if ($dev !~ m/:/);
  } else {
     $dev = "localhost:3493";
  }
  $hash->{DeviceName} = $dev;
  $hash->{buffer} = '';

  # Defaults setzen

  $attr{$name}{pollState} = 10;
  $attr{$name}{pollVal} = 60;
  $attr{$name}{disable} = 0;
  $attr{$name}{asReadings} = 'battery.charge,battery.runtime,input.voltage,ups.load,ups.power,ups.realpower';

  $hash->{pollValState} = 0;
  $hash->{lastStatus} = "";

  return DevIo_OpenDev($hash, 0, "NUT_DevInit");
}


sub NUT_Undef($$) {
  my ($hash, $arg) = @_;
  my $name = $hash->{NAME};
  RemoveInternalTimer("pollTimer:".$name);
  DevIo_CloseDev($hash);
  return undef;
}


sub NUT_Ready($) {
  my ($hash) = @_;
  return DevIo_OpenDev($hash, 1, "NUT_DevInit");
}


sub NUT_DevInit($) {
  my ($hash) = @_;

  $hash->{pollValState} = 0;
  delete $hash->{WaitForAnswer};
  NUT_ListVar($hash);

  return undef;
}


sub NUT_Read($) {
  my ($hash) = @_;
  my $name = $hash->{NAME};
	
  # read from serial device
  my $buf = DevIo_SimpleRead($hash);		
  return '' if (!defined($buf));

  $hash->{buffer} .= $buf;
#  Log3 $name, 5, "Current buffer content: " . $hash->{buffer};
  NUT_Auswertung($hash);

  return '';
}


sub NUT_ListVar($) {
  my ($hash) = @_;
  my $name = $hash->{NAME};

  if (not defined $attr{$name}{disable} or $attr{$name}{disable} == 0) {

    if ($hash->{STATE} eq 'disconnected') {
      # Verbindung scheint nicht zu bestehen
      # Alles abbrechen, ich verlasse mich auf DevIo_OpenDev, dass es alles wieder anwirft, sobald die Verbindung wieder steht
      $hash->{pollValState} = 0;
      RemoveInternalTimer("pollTimer:".$name);
      DevIo_OpenDev($hash, 1, "NUT_DevInit");
      return;
    }

    if (defined $hash->{WaitForAnswer}) {
      # Keine Antwort auf die letzte Frage -> NUT nicht mehr erreichbar!
      Log3 $name, 3, "NUT antwortet nicht";
      DevIo_Disconnected($hash);
      delete $hash->{DevIoJustClosed};
      $hash->{pollValState} = 0;
      delete $hash->{WaitForAnswer};
      RemoveInternalTimer("pollTimer:".$name);
      DevIo_OpenDev($hash, 1, "NUT_DevInit");
      return;
    }

    my $ups = $hash->{UpsName};
    if ($hash->{pollValState} == 0) {
      # Kompletten Datensatz anfordern
      Log3 $name, 5, "Sending 'LIST VAR $ups'...";
      DevIo_SimpleWrite($hash, "LIST VAR $ups\n", 0);
    } else {
      # Nur Status anfordern
      Log3 $name, 5, "Sending 'GET VAR $ups ups.status'...";
      DevIo_SimpleWrite($hash, "GET VAR $ups ups.status\n", 0);
    }
    $hash->{WaitForAnswer} = 1;

  } else {
    Log3 $name, 5, "NUT polling disabled.";
    delete $hash->{WaitForAnswer};
  }

  RemoveInternalTimer("pollTimer:".$name);
  InternalTimer(gettimeofday() + $attr{$name}{pollState}, "NUT_PollTimer", "pollTimer:".$name, 0);

  $hash->{pollValState} += $attr{$name}{pollState};
  $hash->{pollValState} = 0 if $hash->{pollValState} >= $attr{$name}{pollVal};
}


sub NUT_PollTimer($) {
  my $in = shift;
  my (undef,$name) = split(':',$in);
  my $hash = $defs{$name};

  NUT_ListVar($hash);
}



sub NUT_Auswertung($) {
  my ($hash) = @_;
  my $name = $hash->{NAME};
  my $buf = $hash->{buffer};

  my @lines = split /\n/, $buf;

  if (substr($buf, -1) ne "\n") {
    # Letzte Zeile ist noch unvollständig
    $hash->{buffer} = $lines[$#lines];
    $lines[$#lines] = '';
    if (length($hash->{buffer}) > 1024) {
       # Notbremse, wenn eine Zeile zu lange wird
       Log3 $name, 1, "NUT: Zeile > 1024 Zeichen!";
       $hash->{buffer} = '';
    }
  } else {
    $hash->{buffer} = '';
  }

  foreach my $line (@lines) {
    if (length($line) > 0) {
      Log3 $name, 5, "NUT RX: $line";
      my $arg = '';
      if ($line =~ m/(.*) "(.*)"/) {
        # Argument in "
        $line = $1;
        $arg = $2;
      }

      my @words = split / /, $line;

      if ($words[0] eq 'VAR') {
        # Variable erkannt
        if ($words[1] eq $hash->{UpsName}) {
          my $var = $words[2];
          $hash->{helper}{$var} = $arg;
          # Sonderfälle
          if ($var eq 'ups.status') {
            # Status wird sofort übernommen
            readingsSingleUpdate($hash, 'state', $hash->{helper}{'ups.status'}, 1);
            $hash->{lastStatus} = $hash->{helper}{'ups.status'};
          }
        } else {
          Log3 $name, 1, "NUT $hash->{UpsName}: VAR from wrong UPS $words[1]";
        }

      } elsif ($words[0] eq 'BEGIN') {
        # Anfang einer Liste
        if ($words[2] eq 'VAR') {
          # Hier werden die alten Daten gelöscht.
          # Das ist notwendig, da sonst nicht entschieden werden kann, welche Daten die USV liefert
          # und welche berechnet werden müssen.
          # FIXME Problem: Wenn in der Zeit, bis END LIST VAR durch ist, per GET Werte abgefragt werden sollen,
          #       dann fehlen die möglicherweise. GET ist aber noch nicht implementiert.
          #       Mögliche Lösung: Neue Werte in z.B. {helper}{NEW} einlesen und bei END LIST VAR umschieben.
          delete $hash->{helper};
        }

      } elsif ($words[0] eq 'END') {
        # Ende einer Liste
        if ($words[2] eq 'VAR') {
          # Ende einer Variablen-Liste
          # Umwidmen der Variablen in Readings
          NUT_makeReadings($hash);
        }

      } elsif ($words[0] eq 'ERR') {
        # Fehlermeldungen
        my $err = $words[1];
        Log3 $name, 2, "NUT Error: $err";
        readingsSingleUpdate($hash, 'lastError', $err, 1);
        readingsSingleUpdate($hash, 'state', $err, 1);
        if ($err=~ m/(ACCESS-DENIED|UNKNOWN-UPS)/) {
           # Das sind Fehlermeldungen, die keine Hoffnung machen, dass es noch funktionieren könnte
           $attr{$name}{disable} = 1;
        }

      } else {
        # TODO Es gibt noch viele Antworten, die interessant sein könnten...
        # http://www.networkupstools.org/docs/developer-guide.chunked/ar01s09.html
        Log3 $name, 5, "NUT: not implemented: $line";
      }

      delete $hash->{WaitForAnswer};

    } # if len > 0
  } # foreach

}



sub NUT_makeReadings($) {
  my ($hash) = @_;
  my $name = $hash->{NAME};

  # Die USV-Variablen en bloc in Readings überführen
  # FIXME Woher kommt die Fehlermeldung 'Notify loop for...' im Log?

  readingsBeginUpdate($hash);
  foreach (split (',', $attr{$name}{asReadings})) {
    s/^\s+//;
    s/\s+$//;
    readingsBulkUpdate($hash, $_, $hash->{helper}{$_}) if defined $hash->{helper}{$_};
  }
  readingsEndUpdate($hash, 1);

}


1;

=pod
=begin html

<a name="NUT"></a>
<h3>NUT</h3>
<ul>
  The Network UPS Tools (<a href="http://www.networkupstools.org">www.networkupstools.org</a>) provide support for Uninterruptable Power Supplies and the like.
  This module gives access to a running nut server. You can read data (status, runtime, input voltage, sometimes even temperature and so on). In the future it will
  also be possible to control the UPS (start test, switch off).<br>
  Which values you can use as readings is set with <a href="#NUT_asReadings">asReadings</a>. Which values are available with this UPS, you can check with 
  <code>list theUPS</code>. Only ups.status is always read and used as the status of the device.<br>

  <br><br>

  <a name=NUTdefine"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; NUT &lt;ups&gt; [&lt;host&gt;[:&lt;port&gt;]]</code> <br>
    <br>
    &lt;ups&gt; is the name of a ups defined in the nut server.
    <br>
    [&lt;host&gt;[:&lt;port&gt;]] is the host of the nut server. If omitted, <code>localhost:3493</code> is used.
    <br><br>
      Example: <br>
    <code>define theUPS NUT myups otherserver</code>
      <br>
  </ul>
  <br>

  <a name="NUTset"></a>
  <b>Set</b> <ul>N/A</ul><br>

  <a name="NUTget"></a>
  <b>Get</b> <ul>N/A</ul><br>

  <a name="NUTattr"></a>
  <b>Attributes</b>
  <ul>
    <li><a href="#disable">disable</a></li><br>
    <li><a href="#readingFnAttributes">readingFnAttributes</a></li><br>
    <li><a name="">pollState</a><br>
        Polling interval in seconds for the state of the ups. Default: 10</li><br>
    <li><a name="">pollVal</a><br>
        Polling interval in seconds of the other Readings. This should be a multiple of pollState. Default: 60</li><br>
    <li><a name="#NUT_asReadings">asReadings</a><br>
        Values of the UPS which are used as Readings (ups.status is read anyway)<br>
        Example:<br>
        <code>attr theUPS asReadings battery.charge,battery.runtime,input.voltage,ups.load,ups.power,ups.realpower</code> </li><br>
  </ul>
</ul>

=end html

=begin html_DE

<a name="NUT"></a>
<h3>NUT</h3>
<ul>
  Die Network UPS Tools (<a href="http://www.networkupstools.org">www.networkupstools.org</a>) bieten Unterstützung für Unterbrechungsfreie Stromversorgungen (USV)
  und ähnliches. Dieses Modul ermöglicht den Zugriff auf einen NUT-Server, womit man Daten auslesen kann (z.B. den Status, Restlaufzeit, Eingangsspannung, manchmal
  auch Temperatur u.ä.) und zukünftig die USV auch steuern kann (Test aktivieren, USV herunterfahren u.ä.).<br>
  Welche Readings zur Verfügung stehen, bestimmt das Attribut <a href="#NUT_asReadings">asReadings</a>. Welche Werte eine USV zur Verfügung stellt, kann man mit
  <code>list dieUSV</code> unter <i>Helper:</i> ablesen. Nur ups.status wird immer ausgelesen und ergibt den Status des Geräts.<br>

  <br><br>

  <a name=NUTdefine"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; NUT &lt;ups&gt; [&lt;host&gt;[:&lt;port&gt;]]</code> <br>
    <br>
    &lt;ups&gt; ist der im NUT-Server definierte Name der USV.
    <br>
    [&lt;host&gt;[:&lt;port&gt;]] ist Host und Port des NUT-Servers. Default ist <code>localhost:3493</code>.
    <br><br>
      Beispiel: <br>
    <code>define dieUSV NUT myups einserver</code>
      <br>
  </ul>
  <br>

  <a name="NUTset"></a>
  <b>Set</b> <ul>N/A</ul><br>

  <a name="NUTget"></a>
  <b>Get</b> <ul>N/A</ul><br>

  <a name="NUTattr"></a>
  <b>Attributes</b>
  <ul>
    <li><a href="#disable">disable</a></li><br>
    <li><a href="#readingFnAttributes">readingFnAttributes</a></li><br>
    <li><a name="">pollState</a><br>
        Polling-Intervall in Sekunden für den Status der USV. Default: 10</li><br>
    <li><a name="">pollVal</a><br>
        Polling-Intervall für die anderen Werte. Dieser Wert wird auf ein Vielfaches von pollState gerundet. Default: 60</li><br>
    <li><a name="NUT_asReadings">asReadings</a><br>
        Mit Kommata getrennte Liste der USV-Werte, die als Readings verwendet werden sollen (ups.status wird auf jeden Fall gelesen).<br>
        Beispiel:<br>
        <code>attr dieUSV asReadings battery.charge,battery.runtime,input.voltage,ups.load,ups.power,ups.realpower</code> </li><br>
  </ul>
</ul>

=end html_DE
=cut

