##############################################
# $Id: myUtilsTemplate.pm 7570 2015-01-14 18:31:44Z rudolfkoenig $
#
# Save this file as 99_myUtils.pm, and create your own functions in the new
# file. They are then available in every Perl expression.

package main;

use strict;
use warnings;
use POSIX;

sub
myUtils_Initialize($$)
{
  my ($hash) = @_;
}

# Enter you functions below _this_ line.

sub checkAllFritzMACpresent($) {
  # Benötigt: nur die zu suchende MAC ($MAC), 
  # Es werden alle Instanzen vom Type FRITZBOX abgefragt
  #
  # Rückgabe: 1 = Gerät gefunden
  #           0 = Gerät nicht gefunden
  my ($MAC) = @_;
  # Wird in keiner Instanz die MAC Adresse gefunden bleibt der Status 0
  my $Status = 0;
  $MAC =~ tr/:/_/;
  $MAC = "mac_".uc($MAC);
  my @FBS = devspec2array("TYPE=FRITZBOX");
    foreach( @FBS ) {
		my $StatusFritz = ReadingsVal($_, $MAC, "weg");
		if ($StatusFritz eq "weg") {
		} elsif ($StatusFritz eq "inactive") {
		} else {
		  # Reading existiert, Rückgabewert ist nicht "inactive", also ist das Gerät am Netzwerk angemeldet.
		  $Status = 1;
		}
    }
  return $Status
}

1;
