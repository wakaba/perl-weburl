package Web::DomainName::Canonicalize;
use strict;
use warnings;
our $VERSION = '1.0';
use Web::IPAddr::Canonicalize;
use Exporter::Lite;

our @EXPORT = qw(
  canonicalize_url_host
);

sub canonicalize_url_host ($;%) {
  my %args = @_[1..$#_];
  return to_ascii($_[0], $args{is_file});
} # canonicalize_url_host

use Net::LibIDN;
use Encode;

sub encode_punycode ($) {
  # XXX
  return eval { Encode::decode 'utf-8', Net::LibIDN::idn_punycode_encode $_[0], 'utf-8' };
} # encode_punycode

sub decode_punycode ($) {
  # XXX
  return eval { Encode::decode 'utf-8', Net::LibIDN::idn_punycode_decode $_[0], 'utf-8' };
} # decode_punycode

use Unicode::Normalize;
use Unicode::Stringprep;
*nameprepmapping = Unicode::Stringprep->new
    (3.2,
     [\@Unicode::Stringprep::Mapping::B1,
      \@Unicode::Stringprep::Mapping::B2],
     '',
     [],
     0, 0);
*nameprepprohibited = Unicode::Stringprep->new
    (3.2,
     [],
     '',
     [\@Unicode::Stringprep::Prohibited::C12,
      \@Unicode::Stringprep::Prohibited::C22,
      \@Unicode::Stringprep::Prohibited::C3,
      \@Unicode::Stringprep::Prohibited::C4,
      \@Unicode::Stringprep::Prohibited::C5,
      \@Unicode::Stringprep::Prohibited::C6,
      \@Unicode::Stringprep::Prohibited::C7,
      \@Unicode::Stringprep::Prohibited::C8,
      \@Unicode::Stringprep::Prohibited::C9],
     0, 0);
*nameprepunassigned = Unicode::Stringprep->new
    (3.2,
     [],
     '',
     [],
     0, 1);
use Char::Prop::Unicode::BidiClass;

sub nameprep ($;%) {
  my $label = shift;
  my %args = @_;
  
  $label =~ tr{\x{2F868}\x{2F874}\x{2F91F}\x{2F95F}\x{2F9BF}}
      {\x{36FC}\x{5F53}\x{243AB}\x{7AEE}\x{45D7}};
  $label = nameprepmapping ($label);

  my $has_unassigned = not defined eval { nameprepunassigned ($label); 1 };
  $label = NFKC ($label);
  if ($has_unassigned) {
    $label = nameprepmapping ($label);
    $label = NFKC $label;
  }
  
  if (not defined eval { nameprepprohibited ($label); 1 }) {
    return undef;
  }
  return $label;
} # nameprep

sub nameprep_bidi ($) {
  my $label = shift;

  my @char = split //, $label;
  if (@char) {
    my $has_randalcat;
    my $has_l;
    my $first;
    my $last;
    for (split //, $label) {
      my $class = unicode_bidi_class_c $_;
      if ($class eq 'R' or $class eq 'AL') {
        $has_randalcat = 1;
      } elsif ($class eq 'L') {
        $has_l = 1;
      }
      $first ||= $class;
      $last = $class;
    }
    if ($has_randalcat) {
      return undef if $has_l;
      return undef if $first ne 'R' and $first ne 'AL';
      return undef if $last ne 'R' and $last ne 'AL';
    }
  }
  
  return $label;
} # nameprep_bidi

sub to_ascii ($$) {
  my ($s, $is_file) = @_;

  my $fallback = undef;

  return undef if $s =~ m{^%5[Bb]};

  $s = Encode::encode ('utf-8', $s);
  $s =~ s{%([0-9A-Fa-f]{2})}{pack 'C', hex $1}ge;
  $s = Encode::decode ('utf-8', $s); # XXX error-handling

  my $need_punycode = $s =~ /[^\x00-\x7F]/;

  my $has_root_dot;
  
  $s = nameprep $s;
  return $fallback unless defined $s;

  $s =~ tr/\x{3002}\x{FF0E}\x{FF61}/.../;

  $has_root_dot = 1 if $s =~ s/[.]\z//;

  my @label = split /\./, $s, -1;
  @label = ('') unless @label;

  if ($need_punycode) {
    @label = map {
        my $label = $_;

        $label = nameprep_bidi $label;
        return $fallback unless defined $label;

        if ($label =~ /[^\x00-\x7F]/) {
          return undef if $label =~ /^xn--/;
          $label = eval { encode_punycode $label };
          return $fallback unless defined $label;
          $label = 'xn--' . $label;
          return $fallback if length $label > 63;
        } else {
          return undef if $label eq '';
          return undef if length $label > 63;
        }
        $label;
    } @label;
  }

  push @label, '' if $has_root_dot;
  $s = join '.', @label;

  if ($s =~ /\A\[/ and $s =~ /\]\z/) {
    my $t = canonicalize_ipv6_addr substr $s, 1, -2 + length $s;
    return '[' . $t . ']' if defined $t;
  } else {
    unless ($is_file) {
      return undef if $s =~ /:/;
    }
  }

  my $ipv4 = canonicalize_ipv4_addr $s;
  return $ipv4 if defined $ipv4;
  
  if ($s =~ /[\x00\x25\x2F\x5C]/) {
    return undef;
  }

  $s =~ s{([\x00-\x2A\x2C\x2F\x3B-\x3F\x5C\x5E\x60\x7B-\x7D\x7F])}{
    sprintf '%%%02X', ord $1;
  }ge;
  $s =~ s{\@}{%40}g unless $is_file;
  
  return $s;
} # to_ascii

1;

