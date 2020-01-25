##############################################
# $Id: 99_SUNRISE_EL.pm 18732 2019-02-25 13:15:34Z rudolfkoenig $
# This code is derived from DateTime::Event::Sunrise, version 0.0501.
# Simplified and removed further package # dependency (DateTime,
# Params::Validate, etc). For comments see the original code.
#

package main;
use strict;
use warnings;
use Math::Trig;

sub sr($$$$$$);
sub sunrise_rel(@);
sub sunset_rel(@);
sub sunrise_abs(@);
sub sunset_abs(@);
sub isday(@);
sub sunrise_coord($$$);

sub SUNRISE_Initialize($);

# See perldoc DateTime::Event::Sunrise for details
my $long;
my $lat;
my $tz     = ""; # will be overwritten
my $defaultaltit  = "-6";        # Civil twilight
my $RADEG  = ( 180 / 3.1415926 );
my $DEGRAD = ( 3.1415926 / 180 );
my $INV360 = ( 1.0 / 360.0 );
my %alti = (REAL => 0, CIVIL => -6, NAUTIC => -12, ASTRONOMIC => -16); # or HORIZON <number>


sub
SUNRISE_EL_Initialize($)
{
  my ($hash) = @_;
}


##########################
# Compute the _next_ event
# rise:  1: event is sunrise (else sunset)
# isrel: 1: relative times
# seconds: second offset to event
# daycheck: if set, then return 1 if the sun is visible, 0 else
sub
sr($$$$$$)
{
  my ($rise, $seconds, $isrel, $daycheck, $min, $max) = @_;
  sr_alt(time(), $rise, $isrel, $daycheck, 1, $defaultaltit,$seconds,$min,$max);
}

sub
sr_alt($$$$$$$$$)
{
  my $nt=shift;
  my $rise=shift;
  my $isrel=shift;
  my $daycheck=shift;
  my $nextDay=shift;
  my $altit = defined($_[0]) ? $_[0] : "";
  if(exists $alti{uc($altit)}) {
      $altit=$alti{uc($altit)};
      shift;
  } elsif($altit =~ /HORIZON=([\-\+]*[0-9\.]+)/i) {
      $altit=$1;
      shift;
  } else {
      $altit=-6; #default
  }
  my($seconds, $min, $max)=@_;
  my $needrise = ($rise || $daycheck) ? 1 : 0;
  my $needset = (!$rise || $daycheck) ? 1 : 0;
  $seconds = 0 if(!$seconds);

   ############################
   # If set in global, use longitude/latitude
   # from global, otherwise set Frankfurt/Germany as
   # default
   $long = AttrVal("global", "longitude", "8.686");
   $lat  = AttrVal("global", "latitude", "50.112");
   Log3 undef, 5, "Compute sunrise/sunset for latitude $lat , longitude $long";
 

  #my $nt = time;
  my @lt = localtime($nt);
  my $gmtoff = _calctz($nt,@lt); # in hour

  my ($rt,$st) = _sr_alt($altit,$needrise,$needset,
                        $lt[5]+1900,$lt[4]+1,$lt[3], $gmtoff);
  my $sst = ($rise ? $rt : $st) + ($seconds/3600);

  my $nh = $lt[2] + $lt[1]/60 + $lt[0]/3600;    # Current hour since midnight
  if($daycheck) {
    if(defined($min) && defined($max)) { #Forum #43742
      $min = hms2h($min); $max = hms2h($max);
      if($min < $max) {
        $rt = $min if($rt < $min);
        $st = $max if($st > $max);
      } else {
        $rt = $max if($rt > $max);
        $st = $min if($st < $min);
      }
    }
    return 1 if($rt <= $nh && $nh <= $st);
    return 0;
  }

  $sst = hms2h($min) if(defined($min) && (hms2h($min) > $sst));
  $sst = hms2h($max) if(defined($max) && (hms2h($max) < $sst));

  my $diff = 0;
  if (($data{AT_RECOMPUTE} ||                     # compute it for tommorow
    int(($nh-$sst)*3600) >= 0) && $nextDay)  {    # if called a subsec earlier
    $nt += 86400;
    @lt = localtime($nt);
    my $ngmtoff = _calctz($nt,@lt); # in hour
    $diff = 24;

    ($rt,$st) = _sr_alt($altit,$needrise,$needset,
                        $lt[5]+1900,$lt[4]+1,$lt[3], $ngmtoff);
    $sst = ($rise ? $rt : $st) + ($seconds/3600);

    $sst = hms2h($min) if(defined($min) && (hms2h($min) > $sst));
    $sst = hms2h($max) if(defined($max) && (hms2h($max) < $sst));
  }

  $sst += $diff if($isrel);
  $sst -= $nh if($isrel == 1);

  return h2hms_fmt($sst);
}

sub
_sr_alt($$$$$$$)
{
  my ($altit,$needrise, $needset, $y, $m, $dy, $offset) = @_;

  my $d = _days_since_2000_Jan_0($y,$m,$dy) + 0.5 - $long / 360.0;
  my ( $tmp_rise_1, $tmp_set_1 ) =
    _sunrise_sunset( $d, $long, $lat, $altit, 15.04107 );

  my ($tmp_rise_2, $tmp_rise_3) = (0,0);

  if($needrise) {
    $tmp_rise_2 = 9; $tmp_rise_3 = 0;
    until ( _equal( $tmp_rise_2, $tmp_rise_3, 8 ) ) {

        my $d_sunrise_1 = $d + $tmp_rise_1 / 24.0;
        ( $tmp_rise_2, undef ) =
          _sunrise_sunset( $d_sunrise_1, $long, $lat, $altit, 15.04107 );
        $tmp_rise_1 = $tmp_rise_3;
        my $d_sunrise_2 = $d + $tmp_rise_2 / 24.0;
        ( $tmp_rise_3, undef ) =
          _sunrise_sunset( $d_sunrise_2, $long, $lat, $altit, 15.04107 );
    }
  }

  my ($tmp_set_2, $tmp_set_3) = (0,0);
  if($needset) {
    $tmp_set_2 = 9; $tmp_set_3 = 0;
    until ( _equal( $tmp_set_2, $tmp_set_3, 8 ) ) {

        my $d_sunset_1 = $d + $tmp_set_1 / 24.0;
        ( undef, $tmp_set_2 ) =
          _sunrise_sunset( $d_sunset_1, $long, $lat, $altit, 15.04107 );
        $tmp_set_1 = $tmp_set_3;
        my $d_sunset_2 = $d + $tmp_set_2 / 24.0;
        ( undef, $tmp_set_3 ) =
          _sunrise_sunset( $d_sunset_2, $long, $lat, $altit, 15.04107 );

    }
  }

  return $tmp_rise_3+$offset, $tmp_set_3+$offset;
}



sub
_sunrise_sunset($$$$$)
{
  my ( $d, $lon, $lat, $altit, $h ) = @_;

  my $sidtime = _revolution( _GMST0($d) + 180.0 + $lon );

  # Compute Sun's RA + Decl + distance at this moment
  my ( $sRA, $sdec, $sr ) = _sun_RA_dec($d);

  # Compute time when Sun is at south - in hours UT
  my $tsouth  = 12.0 - _rev180( $sidtime - $sRA ) / $h;

  # Compute the diurnal arc that the Sun traverses to reach 
  # the specified altitude altit: 
  my $cost =
    ( sind($altit) - sind($lat) * sind($sdec) ) /
    ( cosd($lat) * cosd($sdec) );

  my $t;
  if ( $cost >= 1.0 ) {
      $t = 0.0;    # Sun always below altit
  }
  elsif ( $cost <= -1.0 ) {
      $t = 12.0;    # Sun always above altit
  }
  else {
      $t = acosd($cost) / 15.0;    # The diurnal arc, hours
  }

  # Store rise and set times - in hours UT 

  my $hour_rise_ut = $tsouth - $t;
  my $hour_set_ut  = $tsouth + $t;
  return ( $hour_rise_ut, $hour_set_ut );

}

sub
_GMST0($)
{
  my ($d) = @_;

  my $sidtim0 =
    _revolution( ( 180.0 + 356.0470 + 282.9404 ) +
    ( 0.9856002585 + 4.70935E-5 ) * $d );
  return $sidtim0;

}

sub
_sunpos($)
{
  my ($d) = @_;

  my $Mean_anomaly_of_sun = _revolution( 356.0470 + 0.9856002585 * $d );
  my $Mean_longitude_of_perihelion = 282.9404 + 4.70935E-5 * $d;
  my $Eccentricity_of_Earth_orbit  = 0.016709 - 1.151E-9 * $d;

  # Compute true longitude and radius vector 
  my $Eccentric_anomaly =
    $Mean_anomaly_of_sun + $Eccentricity_of_Earth_orbit * $RADEG *
    sind($Mean_anomaly_of_sun) *
    ( 1.0 + $Eccentricity_of_Earth_orbit * cosd($Mean_anomaly_of_sun) );

  my $x = cosd($Eccentric_anomaly) - $Eccentricity_of_Earth_orbit;

  my $y =
    sqrt( 1.0 - $Eccentricity_of_Earth_orbit * $Eccentricity_of_Earth_orbit )
    * sind($Eccentric_anomaly);

  my $Solar_distance = sqrt( $x * $x + $y * $y );    # Solar distance
  my $True_anomaly = atan2d( $y, $x );               # True anomaly

  my $True_solar_longitude =
    $True_anomaly + $Mean_longitude_of_perihelion;    # True solar longitude

  if ( $True_solar_longitude >= 360.0 ) {
      $True_solar_longitude -= 360.0;    # Make it 0..360 degrees
  }

  return ( $Solar_distance, $True_solar_longitude );
}


# Sun's Right Ascension (RA), Declination (dec) and distance (r)
sub
_sun_RA_dec($)
{
  my ($d) = @_;

  my ( $r, $lon ) = _sunpos($d);

  my $x = $r * cosd($lon);
  my $y = $r * sind($lon);

  my $obl_ecl = 23.4393 - 3.563E-7 * $d;

  my $z = $y * sind($obl_ecl);
  $y = $y * cosd($obl_ecl);

  my $RA  = atan2d( $y, $x );
  my $dec = atan2d( $z, sqrt( $x * $x + $y * $y ) );

  return ( $RA, $dec, $r );
}

sub
_days_since_2000_Jan_0($$$)
{
  my ($y, $m, $d) = @_;
  my @mn = (31,28,31,30,31,30,31,31,30,31,30,31);
  
  my $ms = 0;
  for(my $i = 0; $i < $m-1; $i++) {
    $ms += $mn[$i];
  }
  my $x = ($y-2000)*365.25 + $ms + $d;
  $x++ if($m > 2 && ($y%4) == 0);
  return int($x);
}

sub sind($) { sin( ( $_[0] ) * $DEGRAD ); }
sub cosd($) { cos( ( $_[0] ) * $DEGRAD ); }
sub tand($) { tan( ( $_[0] ) * $DEGRAD ); }
sub atand($) { ( $RADEG * atan( $_[0] ) ); }
sub asind($) { ( $RADEG * asin( $_[0] ) ); }
sub acosd($) { ( $RADEG * acos( $_[0] ) ); }
sub atan2d($$) { ( $RADEG * atan2( $_[0], $_[1] ) ); }

sub
_revolution($)
{
  my $x = $_[0];
  return ( $x - 360.0 * int( $x * $INV360 ) );
}

sub
_rev180($)
{
  my ($x) = @_;
  return ( $x - 360.0 * int( $x * $INV360 + 0.5 ) );
}

sub
_equal($$$)
{
  my ( $A, $B, $dp ) = @_;
  return sprintf( "%.${dp}g", $A ) eq sprintf( "%.${dp}g", $B );
}

sub
_calctz($@)
{
  my ($nt,@lt) = @_;

  my $off = $lt[2]*3600+$lt[1]*60+$lt[0];
  $off = 12*3600-$off;
  $nt += $off;  # This is noon, localtime

  my @gt = gmtime($nt);

  return (12-$gt[2]);
}
  

sub
hms2h($)
{
  my $in = shift;
  my @a = split(":", $in);
  return 0 if(int(@a) < 2 || $in !~ m/^[\d:]*$/);
  return $a[0]+$a[1]/60 + ($a[2] ? $a[2]/3600 : 0);
}

sub
h2hms($)
{
  my ($in) = @_;
  my ($h,$m,$s);
  $h = int($in);
  $m = int(60*($in-$h));
  $s = int(3600*($in-$h)-60*$m);
  return ($h, $m, $s);
}

sub
h2hms_fmt($)
{
  my ($in) = @_;
  my ($h,$m,$s) = h2hms($in);
  return sprintf("%02d:%02d:%02d", $h, $m, $s);
}

sub
sr_noon($)
{
  my ($date) = @_;
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($date);
  return $date - $hour*3600 - $min*60 - $sec + 12*3600;
}

sub sunrise_coord($$$) { ($long, $lat, $tz) = @_; return undef; }

sub sunrise_rel(@) { return sr_alt(time(),1,1,0,1,shift,shift,shift,shift); }
sub sunset_rel (@) { return sr_alt(time(),0,1,0,1,shift,shift,shift,shift); }
sub sunrise_abs(@) { return sr_alt(time(),1,0,0,0,shift,shift,shift,shift); }
sub sunset_abs (@) { return sr_alt(time(),0,0,0,0,shift,shift,shift,shift); }
sub sunrise    (@) { return sr_alt(time(),1,2,0,1,shift,shift,shift,shift); }
sub sunset     (@) { return sr_alt(time(),0,2,0,1,shift,shift,shift,shift); }
sub isday      (@) { return sr_alt(time(),1,0,1,1,shift,shift,shift,shift); }

sub sunrise_abs_dat(@) {
  return sr_alt(sr_noon(shift),1,0,0,0,shift,shift,shift,shift);
}
sub sunset_abs_dat (@) {
  return sr_alt(sr_noon(shift),0,0,0,0,shift,shift,shift,shift);
}

1;

=pod
=item helper
=item summary    perl functions to compute the sun position
=item summary_DE perl Funktionen f&uuml;r die Sonnenstandsberechnung
=begin html

<a name="SUNRISE_EL"></a>
<h3>SUNRISE_EL</h3>
<ul>
  This module is used to define the functions<pre>
sunrise, sunset,
sunrise_rel, sunset_rel
sunrise_abs, sunset_abs
isday</pre>
  perl functions, to be used in <a href="#at">at</a> or FS20 on-till commands.
  <br>
  First you should set the longitude and latitude global attributes to the
  exact longitude and latitude values (see e.g. maps.google.com for the exact
  values, which should be in the form of a floating point value).  The default
  value is Frankfurt am Main, Germany.
  <br><br>
  The default altitude ($defaultaltit in SUNRISE_EL.pm) defines the
  sunrise/sunset for Civil twilight (i.e. one can no longer read outside
  without artificial illumination), which differs from sunrise/sunset times
  found on different websites.  See perldoc "DateTime::Event::Sunrise" for
  alternatives.  <br><br>

  sunrise() and sunset() return the absolute time of the next sunrise/sunset,
  adding 24 hours if the next event is tomorrow, to use it in the timespec of
  an at device or for the on-till command for FS20 devices.<br>

  sunrise_rel() and sunset_rel() return the relative time to the next
  sunrise/sunset. <br>
  sunrise_abs() and sunset_abs() return the absolute time of the corresponding
  event today (no 24 hours added).<br>
  sunrise_abs_dat() and sunset_abs_dat() return the absolute time of the
  corresponding event to a given date(no 24 hours added).<br>

  All functions take up to three arguments:<br>
  <ul>
    <li>The first specifies an offset (in seconds), which will be added to the
    event.</li>
    <li>The second and third specify min and max values (format: "HH:MM").</li>
  </ul>
  <br>
  isday() can be used in some notify or at commands to check if the sun is up
  or down. isday() ignores the seconds parameter, but respects min and max.
  If min < max, than the day starts not before min, and ends not after max.
  If min > max, than the day starts not after max, and ends not before min.
  <br><br>

  Optionally, for all functions you can set first argument which defines a
  horizon value which then is used instead of the $defaultaltit in
  SUNRISE_EL.pm.<br> Possible values are: "REAL", "CIVIL", "NAUTIC",
  "ASTRONOMIC" or a positive or negative number preceded by "HORIZON="<br> REAL
  is 0, CIVIL is -6, NAUTIC is -12, ASTRONOMIC is -18 degrees above
  horizon.<br><br>

  Examples:<br>
  <ul>
  <PRE>
    # When sun is 6 degrees below horizon - same as sunrise();
    sunrise("CIVIL");

    # When sun is 3 degrees below horizon (between real and civil sunset)
    sunset("HORIZON=-3");

    # When sun is 1 degree above horizon
    sunset("HORIZON=1");

    # Switch lamp1 on at real sunset, not before 18:00 and not after 21:00
    define a15 at *{sunset("REAL",0,"18:00","21:00")} set lamp1 on
  </PRE>
  </ul>
  
  The functions sunrise_abs_dat()/sunset_abs_dat() need as a very first
  parameter the date(format epoch: time()) for which the events should be
  calculated.
  <br><br>
  Examples:
  <br>
  <ul>
  <PRE>
    # to calculate the sunrise of today + 7 days
    my $date = time() + 7*86400;
    sunrise_abs_dat($date);
    
    # to calculate the sunrise of today + 7 days 6 degrees below horizon 
    my $date = time() + 7*86400;
    sunrise_abs_dat($date, "CIVIL");    
  </ul>
  </PRE>  
  
  <b>Define</b> <ul>N/A</ul><br>

  <b>Set</b> <ul>N/A</ul><br>

  <b>Get</b> <ul>N/A</ul><br>

  <b>Attributes</b><br>
  <ul>
    <li><a href="#latitude">latitude</a></li>
    <li><a href="#longitude">longitude</a></li>
  </ul><br>

</ul>

=end html

=begin html_DE

<a name="SUNRISE_EL"></a>
<h3>SUNRISE_EL</h3>
<ul>
    SUNRISE_EL definiert eine Reihe von Perl-Subroutinen (z.B. zur Nutzung mit
    <a href="#at">at</a>):
    <ul>
        <li><code>sunrise()</code> - absolute Zeit des n&auml;chsten
        Sonnenaufgangs (+ 24 h, wenn am n&auml;chsten Tag)</li>

        <li><code>sunset()</code> - absolute Zeit des n&auml;chsten
        Sonnenuntergangs (+ 24 h, wenn am n&auml;chsten Tag)</li>

        <li><code>sunrise_rel()</code> - relative Zeit des n&auml;chsten
        Sonnenaufgangs</li>

        <li><code>sunset_rel()</code> - relative Zeit des n&auml;chsten
        Sonnenuntergangs</li>

        <li><code>sunrise_abs()</code> - absolute Zeit des n&auml;chsten
        Sonnenaufgangs (ohne Stundenzuschlag)</li>

        <li><code>sunset_abs()</code> - absolute Zeit des n&auml;chsten
        Sonnenuntergangs (ohne Stundenzuschlag)</li>

        <li><code>sunrise_abs_dat()</code> - absolute Zeit des n&auml;chsten
        Sonnenaufgangs an einem bestimmten Tag</li>

        <li><code>sunset_abs_dat()</code> - absolute Zeit des n&auml;chsten
        Sonnenuntergangs an einem bestimmten Tag</li>

        <li><code>isday()</code> - Tag oder Nacht</li>
    </ul>

    <h4>Breite, L&auml;nge und H&ouml;henwinkel</h4>
        Bevor du SUNRISE_EL verwendest, solltest du im <a href="#global">global-Device</a> die
        Werte f&uuml;r latitude (geographische Breite) und longitude (geographische L&auml;nge) entsprechend
        deines Standorts setzen.
    
    <div>
        Die Voreinstellung ist 50.112, 8.686 (Frankfurt am Main).
    </div>
    
    SUNRISE_EL geht von einem H&ouml;henwinkel der Sonne bezogen zum Horizont,
    h, von -6&deg; aus. Dieser Wert bedeutet, dass die Sonne 6&deg; unter dem
    Horizont steht und Lesen im Freien ohne k&uuml;nstliche Beleuchtung nicht
    mehr m&ouml;glich ist (civil twilight, b&uuml;rgerliche D&auml;mmerung).
    SUNRISE_EL speichert diesen Wert in <code>$defaultaltit</code>.

    Siehe auch <a href="http://search.cpan.org/~jforget/DateTime-Event-Sunrise-0.0505/lib/DateTime/Event/Sunrise.pm">perldoc DateTime::Event::Sunrise</a> f&uuml;r
    weitere Hinweise.


    <h5>Parameter</h5>
    Jede der folgenden Funktionen akzeptiert bis zu vier (bzw. f&uuml;nf)
    Parameter in der angegebenen Reihenfolge:
    <ul>
      <li>unix timestamp<br>
        Ausschlie&szlig;lich <code>sunrise_abs_dat()</code> &amp;
        <code>sunset_abs_dat()</code> erwarten als ersten Parameter  einen
        Unix-Timestamp (Unix-Epoche) in Sekunden, der ein Datum spezifiziert.
        Andere Subroutinen erwarten diesen Parameter nicht!
        </li></br>

      <li>altitude<br>
        Eine der folgenden Zeichenketten, die unterschiedliche H&ouml;henwinkel h definieren und den Wert
        von <code>$defaultaltit</code> ver&auml;ndern.<br>
        Erlaubte Werte sind:<br>
        <ul>
           <li><code>REAL</code>, h = 0&deg;,
             </li>
           <li><code>CIVIL</code>, h = -6&deg;,
             </li>
           <li><code>NAUTIC</code>, h = -12&deg;,
             </li>
           <li><code>ASTRONOMIC</code>, h = -18&deg;,
             </li>
           <li>oder <code>HORIZON=</code>, gefolgt von einer positiven oder
             negativen Zahl ohn Gradzeichen, die einen H&ouml;henwinkel angibt.
             </li>
        </ul>
        </li></br>

      <li>offset<br>
        Offset in Sekunden, der zu dem R&uuml;ckgabewert der Funktion addiert
        wird.<br>
        <code>isday()</code> ignoriert diesen Wert.
        </li></br>

      <li>min<br>
        Einen Zeitstempel im Format hh:mm, vor dem keine Aktion ausgef&uuml;hrt
        werden soll.  <code>isday()</code> wird (int) 0 zur&uuml;ckliefern,
        wenn min gesetzt und der aktuelle Zeitstempel kleiner ist.
        </li><br>

      <li>max<br>
        Einen Zeitstempel im Format hh:mm, nach dem keine Aktion
        ausgef&uuml;hrt werden soll.  <code>isday()</code> wird (int) 0
        zur&uuml;ckliefern, wenn max gesetzt und der aktuelle Zeitstempel
        gr&ouml;&szlig;er ist.
        </li>
    </ul>

    <h5>Subroutinen</h5>
    <ul>
      <li><code>sunrise(), sunset()</code><br>
        liefern den absoluten Wert des n&auml;chsten Sonnenauf- bzw.
        -untergangs zur&uuml;ck, wobei 24 Stunden zu diesem Wert addiert
        werden, wenn der Zeitpunkt am n&auml;chsten Tag sein wird, im Format
        hh:mm:ss.
        </li><br>

      <li><code>sunrise_rel(), sunset_rel()</code><br>
        liefern die relative Zeit bis zum n&auml;chsten Sonnenauf- bzw.
        -untergang im Format hh:mm:ss.
        </li><br>
        
      <li><code>sunrise_abs(), sunset_abs()</code><br>
        liefern den n&auml;chsten absoluten Zeitpunkt des n&auml;chsten
        Sonnenauf- bzw. -untergangs ohne 24 Stunden zu addieren im Format
        hh:mm:ss.
        </li><br>
        
      <li><code>sunrise_abs_dat(), sunset_abs()_dat</code><br>
        liefern den n&auml;chsten absoluten Zeitpunkt des n&auml;chsten
        Sonnenauf- bzw. -untergangs ohne 24 Stunden zu addieren im Format
        hh:mm:ss zu einem als ersten Parameter angegebenen Datum.
        </li><br>

      <li><code>isday()</code><br>
        liefert (int) 1 wenn Tag ist, (int) 0 wenn Nacht ist.
        </li><br>
    </ul>

    <h5>Beispiele</h5>
    <ul>
        <li><code>sunrise("CIVIL");</code><br>
          Zeitpunkt des Sonnenaufgangs bei einem H&ouml;henwinkel der Sonne von
          -6&deg; unter dem Horizont (identisch zu <code>sunrise()</code>).
          </li><br>
            
        <li><code>sunset("HORIZON=-3");</code><br>
          Zeitpunkt des Sonnenuntergangs bei einem H&ouml;henwinkel der Sonne
          von 3&deg; unter dem Horizont (zwischen <code>REAL</code> und
          <code>CIVIL</code>).
          </li><br>
      
        <li><code>sunset("HORIZON=1");</code><br>
          Zeitpunkt des Sonnenaufgangs bei einem H&ouml;henwinkel der Sonne von
          1&deg; &uuml;ber dem Horizont.
          </li><br>
            
        <li><code>defmod a15 at *{sunset("REAL",0,"18:00","21:00")} set lamp1 on</code><br>
          Schalte lamp1 an, sobald die Sonne unter den Horizont sinkt (h &le;
          0), jedoch nicht vor 18:00 und nicht nach 21:00.
          </li><br>

        <li><code>sunrise_abs_dat(time() + 7*86400);</code><br>
          Berechne den Sonnenaufgang von heute + sieben Tage.
          </li></br>
            
        <li><code>sunrise_abs_dat(time() + 7*86400, "CIVIL");</code><br>
          Berechne den Sonnenaufgang von heute + sieben Tage mit einem
          H&ouml;henwinkel h = -6&deg;.
          </li></br>
    </ul>

    <h4>Define</h4>
        SUNRISE_EL kann nicht explizit als Device definiert werden,
        sondern bietet die oben genannten Subroutinen.
    
    <h4>Set</h4>
        SUNRISE_EL unterst&uuml;tzt set nicht.
    
    <h4>Get</h4>
        SUNRISE_EL unterst&uuml;tzt get nicht.

    <h4>Attribute</h4>
        Diese Attribute m&uuml;ssen im <a href="#global">global</a>-Device
        gesetzt werden!
      <ul>
        <li><a href="#latitude">latitude</a></li>
        <li><a href="#longitude">longitude</a></li>
      </ul>
</ul>

=end html_DE

=cut
