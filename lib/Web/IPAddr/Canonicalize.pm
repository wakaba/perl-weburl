package Web::IPAddr::Canonicalize;
use strict;
use warnings;
our $VERSION = '1.0';
use Exporter::Lite;

our @EXPORT = qw(
  canonicalize_ipv4_addr
  canonicalize_ipv6_addr
);

# XXX handling of large number
sub _to_number ($) {
  if ($_[0] =~ /\A0[Xx]([0-9A-Fa-f]*)\z/) {
    return hex $1;
  } elsif ($_[0] =~ /\A0+([0-9]+)\z/) {
    my $v = $1;
    return undef if $v =~ /[89]/;
    return oct $v;
  } elsif ($_[0] =~ /\A[0-9]+\z/) {
    return 0+$_[0];
  } else {
    return undef;
  }
} # _to_number

sub canonicalize_ipv4_addr ($) {
  return undef unless defined $_[0];
  my @label = split /\./, $_[0], -1;
  @label = map { _to_number ($_) } @label;
  if (@label == 4) {
    if (defined $label[0] and
        defined $label[1] and
        defined $label[2] and
        defined $label[3] and
        $label[0] <= 0xFF and
        $label[1] <= 0xFF and
        $label[2] <= 0xFF and
        $label[3] <= 0xFF) {
      #
    } else {
      return undef;
    }
  } elsif (@label == 3) {
    if (defined $label[0] and
        defined $label[1] and
        defined $label[2] and
        $label[0] <= 0xFF and
        $label[1] <= 0xFF and
        $label[2] <= 0xFFFF) {
      $label[3] = $label[2] & 0xFF;
      $label[2] = $label[2] >> 8;
    } else {
      return undef;
    }
  } elsif (@label == 2) {
    if (defined $label[0] and
        defined $label[1] and
        $label[0] <= 0xFF and
        $label[1] <= 0xFFFFFF) {
      $label[3] = $label[1] & 0xFF;
      $label[2] = ($label[1] >> 8) & 0xFF;
      $label[1] = $label[1] >> 16;
    } else {
      return undef;
    }
  } elsif (@label == 1) {
    if (defined $label[0] and
        $label[0] <= 0xFFFFFFFF) {
      $label[3] = $label[0] & 0xFF;
      $label[2] = ($label[0] >> 8) & 0xFF;
      $label[1] = ($label[0] >> 16) & 0xFF;
      $label[0] = $label[0] >> 24;
    } else {
      return undef;
    }
  } else {
    return undef;
  }
  return join '.', @label;
} # canonicalize_ipv4_addr

sub canonicalize_ipv6_addr ($) {
  my $s = shift;

  my ($h, $l) = split /::/, $s, 2;
  ($h, $l) = (undef, $h) if not defined $l;
  
  my @h = defined $h ? (split /:/, $h, -1) : ();
  my @l = defined $l ? (split /:/, $l, -1) : ();

  my @v4;
  if (@l and $l[-1] =~ /\A([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\z/) {
    return undef if $1 > 255 or $2 > 255 or $3 > 255 or $4 > 255;
    push @v4, pack 'n', ($1 << 8) + $2;
    push @v4, pack 'n', ($3 << 8) + $4;
    pop @l;
  }

  return undef if grep { not /\A[0-9A-Fa-f]{1,4}\z/ } @h, @l;

  @h = map { pack 'n', hex $_ } @h;
  @l = map { pack 'n', hex $_ } @l;

  my $length = 8 - @h - @l - @v4;
  return undef if $length < 0;
  return undef if $length and not defined $h;
  return undef if defined $h and $length == 0;

  push @h, ("\x00\x00" x $length);

  my $ip = sprintf "%x:%x:%x:%x:%x:%x:%x:%x",
      unpack "n8", join '', @h, @l, @v4;
  $ip =~ s/   ^  0:0:0:0:0:0:0:0    $   /::/x or
  $ip =~ s/(?:^|:) 0:0:0:0:0:0:0 (?:$|:)/::/x or
  $ip =~ s/(?:^|:)   0:0:0:0:0:0 (?:$|:)/::/x or
  $ip =~ s/(?:^|:)     0:0:0:0:0 (?:$|:)/::/x or
  $ip =~ s/(?:^|:)       0:0:0:0 (?:$|:)/::/x or
  $ip =~ s/(?:^|:)         0:0:0 (?:$|:)/::/x or
  $ip =~ s/(?:^|:)           0:0 (?:$|:)/::/x;
  return $ip
} # canonicalize_ipv6_addr

1;

=head1 LICENSE

Copyright 2011 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
