#!/usr/bin/perl
use strict;
use warnings;
use Encode;

sub htescape ($) {
  my $s = $_[0];
  $s =~ s/&/&amp;/g;
  $s =~ s/</&lt;/g;
  $s =~ s/>/&gt;/g;
  $s =~ s/\x22/&quot;/g;
  return $s;
} # htescape

my $q = $ENV{QUERY_STRING} || '';

if ($q =~ /^u=([^&]+)&b=([^&]+)$/) {
  my $url = $1;
  my $base = $2;
  for ($url, $base) {
    s/%([0-9A-Fa-f]{2})/pack 'C', hex $1/ge;
    $_ = decode 'utf-8', $_;
  }
  my $s = sprintf q{<!DOCTYPE HTML><base href="%s"><a href="%s">xx</a>},
      htescape $base, htescape $url;
  print "Content-Type: text/html; charset=euc-jp\n\n";
  print scalar encode 'euc-jp', $s;
} else {
  print "Status: 404 Not found\n\n";
}
