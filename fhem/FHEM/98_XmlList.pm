##############################################
# $Id: 98_XmlList.pm 13128 2017-01-17 21:40:09Z rudolfkoenig $
package main;
use strict;
use warnings;
use POSIX;

sub CommandXmlList($$);
sub XmlEscape($);


#####################################
sub
XmlList_Initialize($$)
{
  my %lhash = ( Fn=>"CommandXmlList",
                Hlp=>",list definitions and status info as xml" );
  $cmds{xmllist} = \%lhash;
}


#####################################
sub
XmlEscape($)
{
  my $a = shift;
  return "" if(!defined($a));
  $a =~ s/\\\n/<br>/g;  # Multi-line
  $a =~ s/&/&amp;/g;
  $a =~ s/"/&quot;/g;
  $a =~ s/</&lt;/g;
  $a =~ s/>/&gt;/g;
  # Not needed since we've gone UTF-8
  # $a =~ s/([^ -~])/sprintf("&#%02x;", ord($1))/ge;
  # Esacape characters 0-31, as they are not part of UTF-8
  $a =~ s/([\x00-\x07])//g; # Forum #37955. Chrome wont accept 5 & 6.

  return $a;
}

#####################################
sub
CommandXmlList($$)
{
  my ($cl, $param) = @_;
  my $str = "<FHZINFO>\n";
  my $lt = "";
  my %filter;

  $cl->{contenttype} = "application/xml; charset=utf-8" if($cl);

  my @arr = devspec2array($param ? $param : ".*", $cl); # for Authorize
  map { $filter{$_} = 1 } @arr;

  for my $d (sort { my $x = $modules{$defs{$a}{TYPE}}{ORDER}.$defs{$a}{TYPE} cmp
    		            $modules{$defs{$b}{TYPE}}{ORDER}.$defs{$b}{TYPE};
    		    $x = ($a cmp $b) if($x == 0); $x; } keys %defs) {

      next if(IsIgnored($d) || !$filter{$d});
      my $p = $defs{$d};
      my $t = $p->{TYPE};
      if($t ne $lt) {
        $str .= "\t</${lt}_LIST>\n" if($lt);
        $str .= "\t<${t}_LIST>\n";
      }
      $lt = $t;
 
      my $a1 = XmlEscape($p->{STATE});
      my $a2 = XmlEscape(getAllSets($d));
      my $a3 = XmlEscape(getAllAttr($d));
 
      $str .= "\t\t<$t name=\"$d\" state=\"$a1\" sets=\"$a2\" attrs=\"$a3\">\n";
      my $si = AttrVal("global", "showInternalValues", 0);
 
      foreach my $c (sort keys %{$p}) {
        next if(ref($p->{$c}));
        next if(!$si && $c =~ m/^\./);
        $str .= sprintf("\t\t\t<INT key=\"%s\" value=\"%s\"/>\n",
                        XmlEscape($c), XmlEscape($p->{$c}));
      }
      $str .= sprintf("\t\t\t<INT key=\"IODev\" value=\"%s\"/>\n",
                        $p->{IODev}{NAME}) if($p->{IODev} && $p->{IODev}{NAME});
 
      foreach my $c (sort keys %{$attr{$d}}) {
        next if(!$si && $c =~ m/^\./);
        $str .= sprintf("\t\t\t<ATTR key=\"%s\" value=\"%s\"/>\n",
                        XmlEscape($c), XmlEscape($attr{$d}{$c}));
      }
 
      my $r = $p->{READINGS};
      if($r) {
        foreach my $c (sort keys %{$r}) {
          next if(!$si && $c =~ m/^\./);
          my $h = $r->{$c};
          next if(!defined($h->{VAL}) || !defined($h->{TIME}));
          $str .=
            sprintf("\t\t\t<STATE key=\"%s\" value=\"%s\" measured=\"%s\"/>\n",
                XmlEscape($c), XmlEscape($h->{VAL}), $h->{TIME});
        }
      }
      $str .= "\t\t</$t>\n";
  }
  $str .= "\t</${lt}_LIST>\n" if($lt);
  $str .= "</FHZINFO>\n";
  return $str;
}


1;

=pod
=item command
=item summary    show device data in XML format
=item summary_DE zeigt Ger&auml;tedaten in XML Format an
=begin html

<a name="XmlList"></a>
<h3>xmllist</h3>
<ul>
  <code>xmllist [devspec]</code>
  <br><br>
  Returns an XML tree of device definitions. <a href="#devspec">devspec</a> is
  optional, and restricts the list of devices if specified. 
  <br><br>
  Example:
  <code>
  <ul>
  fhem> xmllist<br>
  &lt;FHZINFO&gt;<br>
    <ul>
    &lt;internal_LIST&gt;<br>
      <ul>
      &lt;internal name="global" state="internal" sets="" attrs="room configfile logfile ..."&gt;<br>
        <ul>
          &lt;INT key="DEF" value="&lt;no definition&gt;"/&gt;<br>
          &lt;INT key="NR" value="0"/&gt;<br>
          &lt;INT key="STATE" value="internal"/&gt;<br>
        </ul>
      [...]<br>
      </ul>
    </ul>
  </ul></code>
</ul>

=end html
=cut
