=for comment

# $Id: 98_uptime.pm 14706 2017-07-13 17:22:27Z betateilchen $

This script free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
any later version.

The GNU General Public License can be found at
http://www.gnu.org/copyleft/gpl.html.
A copy is found in the textfile GPL.txt and important notices to the license
from the author is found in LICENSE.txt distributed with these scripts.

This script is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

=cut

package main;
use strict;
use warnings;

sub uptime_Initialize($$) {
  my %hash = (
    Fn  => "CommandUptime",
    Hlp => ",show FHEM uptime",
  );
  $cmds{uptime} = \%hash;
}

sub CommandUptime($$) {
  my ($cl,$param) = @_;
  my @args = split("[ \t]+", $param);
  $args[0] = defined($args[0]) ? lc($args[0]) : "";

  my $diff = time - $fhem_started;
  return $diff if(lc($args[0]) eq 'raw');

  my ($d,$h,$m,$ret);
  ($d,$diff) = _upT_Div($diff,86400);
  ($h,$diff) = _upT_Div($diff,3600);
  ($m,$diff) = _upT_Div($diff,60);

  $ret  = "";
  $ret .= "$d days, " if($d >  1);
  $ret .= "1 day, "   if($d == 1);
  $ret .= sprintf("%02s:%02s:%02s", $h, $m, $diff);

  return $ret;
}

sub _upT_Div($$) {
  my ($p1,$p2) = @_;
  return (int($p1/$p2), $p1 % $p2);
}

1;

=pod
=item command
=item summary    show FHEM uptime
=item summary_DE zeigt FHEM Laufzeit an
=begin html

<a name="uptime"></a>
<h3>uptime</h3>
<ul>
  <code>uptime [raw]</code><br/>
  <br/>
    uptime shows FHEM uptime since last FHEM (re-)start.<br/>
    if called with optional parameter "raw" only seconds will be shown,<br/>
    without any fomatting.<br/>
</ul>

=end html
=cut
