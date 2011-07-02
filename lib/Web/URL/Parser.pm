package Web::URL::Parser;
use strict;
use warnings;
use Encode;
require utf8;

our $IsHierarchicalScheme = {
  ftp => 1,
  gopher => 1,
  http => 1,
  https => 1,
};

our $IsNonHierarchicalScheme = {
  about => 1,
  data => 1,
  javascript => 1,
  mailto => 1,
  vbscript => 1,
};

our $DefaultPort = {
  ftp => 21,
  gopher => 70,
  http => 80,
  https => 443,
};

sub _preprocess_input ($$) {
  if (utf8::is_utf8 ($_[1])) {
    ## Replace surrogate code points, noncharacters, and non-Unicode
    ## characters by U+FFFD REPLACEMENT CHARACTER, as they break
    ## Perl's regular expression character class handling in some
    ## versions of Perl.
    my $i = 0;
    pos ($_[1]) = $i;
    while (pos $_[1] < length $_[1]) {
      my $code = ord substr $_[1], pos ($_[1]), 1;
      if ((0xD800 <= $code and $code <= 0xDFFF) or
          (0xFDD0 <= $code and $code <= 0xFDEF) or
          ($code % 0x10000) == 0xFFFE or
          ($code % 0x10000) == 0xFFFF or
          $code > 0x10FFFF
      ) {
        substr ($_[1], pos ($_[1]), 1) = "\x{FFFD}";
      }
      pos ($_[1])++;
    }
  }

  $_[1] =~ s{[\x09\x0A\x0D]+}{}g;
  $_[1] =~ s{\A[\x0B\x0C\x20]+}{};
  $_[1] =~ s{[\x0B\x0C\x20]+\z}{};
} # _preprocess_input

sub parse_absolute_url ($$) {
  my ($class, $input) = @_;
  my $result = {};

  $class->_preprocess_input ($input);

  $class->_find_scheme (\$input => $result);
  return $result if $result->{invalid};

  if (defined $result->{scheme_normalized} and
      $result->{scheme_normalized} =~ /\A(?:[a-z]|file)\z/) {
    if ($input =~ s{\#(.*)\z}{}s) {
      $result->{fragment} = $1;
    }
    if ($input =~ s{\?(.*)\z}{}s) {
      $result->{query} = $1;
    }
    if (1 == length $result->{scheme_normalized}) {
      $result->{drive} = $result->{scheme};
      $result->{scheme} = 'file';
      $result->{scheme_normalized} = 'file';
    } else {
      if ($input =~ s{^[/\\]{2,}([^/\\]*)}{}) {
        $result->{host} = $1;
        if ($result->{host} =~ s{^([A-Za-z]|%[46][1-9A-Fa-f]|%[57][0-9Aa])(?:[:|]|%3[Aa]|%7[Cc])?$}{}) {
          $result->{drive} = $1;
          delete $result->{host};
        }
      }
      if (not defined $result->{drive} and
          $input =~ s{^[/\\]?([A-Za-z]|%[46][1-9A-Fa-f]|%[57][0-9Aa])(?:[:|]|%3[Aa]|%7[Cc])(?:\z|[/\\])}{}) {
        $result->{drive} = $1;
      }
    }
    $result->{path} = $input;
    $result->{is_hierarchical} = 1;
    return $result;
  }

  if (defined $result->{scheme_normalized} and
      $result->{scheme_normalized} eq 'mailto') {
    if ($input =~ s{\?(.*)\z}{}s) {
      $result->{query} = $1;
    }
    
    $result->{path} = $input;
    return $result;
  }

  if (defined $result->{scheme_normalized} and
      not $IsNonHierarchicalScheme->{$result->{scheme_normalized}} and
      $input =~ m{^[/\\]}) {
    $result->{is_hierarchical} = 1;
    $class->_find_authority_path_query_fragment
        (\$input => $result);
    if (defined $result->{authority}) {
      $class->_find_user_info_host_port (\($result->{authority}) => $result);
      delete $result->{authority};
    }
    if (defined $result->{user_info}) {
      if ($result->{user_info} eq '') {
        $result->{user} = '';
        delete $result->{user_info};
      } else {
        ($result->{user}, $result->{password}) = split /:/, $result->{user_info}, 2;
        delete $result->{password} unless defined $result->{password};
        delete $result->{user_info};
      }
    }
    return $result;
  }

  if (defined $result->{scheme_normalized} and
      not $IsNonHierarchicalScheme->{$result->{scheme_normalized}}) {
    if ($input =~ s{\#(.*)\z}{}s) {
      $result->{fragment} = $1;
    }
    
    if ($input =~ s{\?(.*)\z}{}s) {
      $result->{query} = $1;
    }
  }

  $result->{path} = $input;
  return $result;
} # parse_absolute_url

sub _find_scheme ($$) {
  my ($class, $inputref => $result) = @_;

  if ($$inputref =~ s/^([^:]+)://) {
    $result->{scheme} = $1;
    $result->{scheme_normalized} = $result->{scheme};
    $result->{scheme_normalized} =~ tr/A-Z/a-z/; # XXX percent-decode
  } else {
    $result->{invalid} = 1;
  }
} # _find_scheme

sub _find_authority_path_query_fragment ($$$) {
  my ($class, $inputref => $result, %args) = @_;

  if ($$inputref =~ m{\A[/\\]{2}}) {
    ## Slash characters
    $$inputref =~ s{\A[/\\]+}{};
    
    ## Authority terminating characters (including slash characters)
    if ($$inputref =~ s{\A([^/\\?\#]*)(?=[/\\?\#])}{}) {
      $result->{authority} = $1;
    } else {
      $result->{authority} = $$inputref; 
      return;
    }
  }

  if ($$inputref =~ s{\#(.*)\z}{}s) {
    $result->{fragment} = $1;
  }

  if ($$inputref =~ s{\?(.*)\z}{}s) {
    $result->{query} = $1;
  }

  $result->{path} = $$inputref;
} # _find_authority_path_query_fragment

sub _find_user_info_host_port ($$$) {
  my ($class, $inputref => $result) = @_;
  my $input = $$inputref;
  if ($input =~ s/\@([^\@]*)\z//) {
    $result->{user_info} = $input;
    $input = $1;
  }
  
  unless ($input =~ /:/) {
    $result->{host} = $input;
    return;
  }

  if ($input =~ /\A\[/ and
      $input =~ /\][^\]:]*\z/) {
    $result->{host} = $input;
    return;
  }

  if ($input =~ s/:([^:]*)\z//) {
    $result->{port} = $1;
  }

  $result->{host} = $input;
} # _find_user_info_host_port

sub resolve_url ($$$) {
  my ($class, $spec, $parsed_base_url) = @_;

  if ($parsed_base_url->{invalid}) {
    return {invalid => 1};
  }

  $class->_preprocess_input ($spec);

  my $parsed_spec = $class->parse_absolute_url ($spec);
  if ($parsed_spec->{invalid} or
      ## Valid scheme characters
      $parsed_spec->{scheme} =~ /[^A-Za-z0-9_.+-]/) {
    return $class->_resolve_relative_url (\$spec, $parsed_base_url);
  }

  if ($parsed_base_url->{is_hierarchical} and
      $parsed_spec->{scheme_normalized} eq
      $parsed_base_url->{scheme_normalized}) {
    $spec = substr $spec, 1 + length $parsed_spec->{scheme};
    return $class->_resolve_relative_url (\$spec, $parsed_base_url);
  }

  if ($parsed_spec->{is_hierarchical}) {
    if (defined $parsed_spec->{path}) {
      $parsed_spec->{path} = $class->_remove_dot_segments
          ($parsed_spec->{path});
    }
  }

  return $parsed_spec;
} # resolve_url

sub _resolve_relative_url ($$$) {
  my ($class, $specref, $parsed_base_url) = @_;

  if ($$specref eq '') {
    my $url = {%$parsed_base_url};
    delete $url->{fragment};
    return $url;
  }

  unless ($parsed_base_url->{is_hierarchical}) {
    return {invalid => 1};
  }
  
  if ($$specref =~ m{\A[/\\][/\\]}) {
    ## Resolve as a scheme-relative URL

    ## XXX It's still unclear how this resolution steps interact with
    ## |file| URL's resolution (which might have special processing
    ## rules in the parsing steps).

    my $r_authority;
    my $r_path = $$specref;
    my $r_query;
    my $r_fragment;
    if ($r_path =~ s{\#(.*)\z}{}s) {
      $r_fragment = $1;
    }
    if ($r_path =~ s{\?(.*)\z}{}s) {
      $r_query = $1;
    }
    if ($r_path =~ s{\A([/\\]{2}[^/\\]*)}{}) {
      $r_authority = $1;
    }

    if (defined $r_path) {
      $r_path = $class->_remove_dot_segments ($r_path);
    }

    my $url = $parsed_base_url->{scheme} . ':' . $r_authority;
    $url .= $r_path if defined $r_path;
    $url .= '?' . $r_query if defined $r_query;
    $url .= '#' . $r_fragment if defined $r_fragment;

    return $class->parse_absolute_url ($url);
  } elsif ($$specref =~ m{\A[/\\]}) {
    ## Resolve as an authority-relative URL

    ## XXX unknown:/hoge/ + /foo/..//bar

    ## XXX It's still unclear how this resolution steps interact with
    ## |file| URL's resolution (which might have special processing
    ## rules in the parsing steps).

    my $r_path = $$specref;
    my $r_query;
    my $r_fragment;
    if ($r_path =~ s{\#(.*)\z}{}s) {
      $r_fragment = $1;
    }
    if ($r_path =~ s{\?(.*)\z}{}s) {
      $r_query = $1;
    }
    $r_path = $class->_remove_dot_segments ($r_path);

    my $r_authority = '';
    if (defined $parsed_base_url->{host} or
        defined $parsed_base_url->{port} or
        defined $parsed_base_url->{user} or
        defined $parsed_base_url->{password}) {
      $r_authority = $parsed_base_url->{host}
          if defined $parsed_base_url->{host};
      $r_authority .= ':' . $parsed_base_url->{port}
          if defined $parsed_base_url->{port};
      $r_authority = $parsed_base_url->{user} .
          (defined $parsed_base_url->{password}
             ? ':' . $parsed_base_url->{password}
             : '') .
          '@' . $r_authority if defined $parsed_base_url->{user};
      $r_authority = '//' . $r_authority;
    }
    my $url = $parsed_base_url->{scheme} . ':' . $r_authority;
    $url .= $r_path if defined $r_path;
    $url .= '?' . $r_query if defined $r_query;
    $url .= '#' . $r_fragment if defined $r_fragment;

    return $class->parse_absolute_url ($url);
  } elsif ($$specref =~ /\A\?/) {
    ## Resolve as a query-relative URL
    my $authority = $parsed_base_url->{host};
    $authority .= ':' . $parsed_base_url->{port}
        if defined $parsed_base_url->{port};
    $authority = $parsed_base_url->{user} .
        (defined $parsed_base_url->{password}
           ? ':' . $parsed_base_url->{password}
           : '') .
        '@' . $authority if defined $parsed_base_url->{user};
    return $class->parse_absolute_url
        ($parsed_base_url->{scheme} . '://' . $authority .
         (defined $parsed_base_url->{path} ? $parsed_base_url->{path} : '') .
         $$specref);
  } elsif ($$specref =~ /\A\#/) {
    ## Resolve as a fragment-relative URL
    my $authority = $parsed_base_url->{host};
    $authority .= ':' . $parsed_base_url->{port}
        if defined $parsed_base_url->{port};
    $authority = $parsed_base_url->{user} .
        (defined $parsed_base_url->{password}
           ? ':' . $parsed_base_url->{password}
           : '') .
        '@' . $authority if defined $parsed_base_url->{user};
    return $class->parse_absolute_url
        ($parsed_base_url->{scheme} . '://' . $authority .
         (defined $parsed_base_url->{path} ? $parsed_base_url->{path} : '') .
         (defined $parsed_base_url->{query} ? '?' . $parsed_base_url->{query} : '') .
         $$specref);
  } else {
    ## Resolve as a path-relative URL

    my $r_path = $$specref;
    my $r_query;
    my $r_fragment;
    if ($r_path =~ s{\#(.*)\z}{}s) {
      $r_fragment = $1;
    }
    if ($r_path =~ s{\?(.*)\z}{}s) {
      $r_query = $1;
    }

    my $result = {%$parsed_base_url};
    my $b_path = defined $parsed_base_url->{path} ? $parsed_base_url->{path} : '';
    {
      ## Merge path (RFC 3986)
      if ($b_path eq '') {
        $r_path = '/'.$r_path;
      } else {
        $b_path =~ s{[^/\\]*\z}{};
        $r_path = $b_path . $r_path;
      }
    }
    $result->{path} = $class->_remove_dot_segments ($r_path);
    if (defined $r_query) {
      $result->{query} = $r_query;
    } else {
      delete $result->{query};
    }
    if (defined $r_fragment) {
      $result->{fragment} = $r_fragment;
    } else {
      delete $result->{fragment};
    }
    return $result;
  }
} # _resolve_relative_url

sub _remove_dot_segments ($$) {
  ## Removing dot-segments (RFC 3986)
  local $_ = $_[1];
  s{\\}{/}g;
  my $buf = '';
  L: while (length $_) {
    next L if s/^(?:\.|%2[Ee])(?:\.|%2[Ee])?\///;
    next L if s/^\/(?:\.|%2[Ee])(?:\/|\z)/\//;
    if (s/^\/(?:\.|%2[Ee])(?:\.|%2[Ee])(\/|\z)/\//) {
      $buf =~ s/\/?[^\/]*$//;
      next L;
    }
    last L if s/^(?:\.|%2[Ee])(?:\.|%2[Ee])?\z//;
    s{^(/?(?:(?!/).)*)}{}s;
    $buf .= $1;
  }
  return $buf;
} # _remove_dot_segments

use Net::IDN::Nameprep ();
use Net::LibIDN;

sub encode_punycode ($) {
  # XXX
  return eval { Encode::decode 'utf-8', Net::LibIDN::idn_punycode_encode $_[0], 'utf-8' };
} # encode_punycode

sub decode_punycode ($) {
  # XXX
  return eval { Encode::decode 'utf-8', Net::LibIDN::idn_punycode_decode $_[0], 'utf-8' };
} # decode_punycode

sub canonicalize_ipv6_addr ($) {
  my $s = shift;

  my ($h, $l) = split /::/, $s, 2;
  ($h, $l) = (undef, $h) if not defined $l;
  
  my @h = defined $h ? (split /:/, $h, -1) : ();
  my @l = split /:/, $l, -1;

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

# XXX large number
my $to_number = sub {
  my $n = shift;
  if ($n =~ /\A0[Xx]([0-9A-Fa-f]*)\z/) {
    return hex $1;
  } elsif ($n =~ /\A0+([0-9]+)\z/) {
    my $v = $1;
    return undef if $v =~ /[89]/;
    return oct $v;
  } elsif ($n =~ /\A[0-9]+\z/) {
    return 0+$n;
  } else {
    return undef;
  }
}; # $to_number

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
*nameprepbidirule = Unicode::Stringprep->new
    (3.2,
     [],
     '',
     [],
     1, 0);
*nameprepunassigned = Unicode::Stringprep->new
    (3.2,
     [],
     '',
     [],
     0, 1);
use Char::Prop::Unicode::BidiClass;

my $browser = $ENV{TEST_BROWSER} || 'this';
sub CHROME () { $browser eq 'chrome' }
sub GECKO () { $browser eq 'gecko' }
sub IE () { $browser eq 'ie' }
sub THIS () { $browser eq 'this' }

sub nameprep ($;%) {
  my $label = shift;
  my %args = @_;
  
  if (GECKO) { # correct (new)
    if ($label =~ /[\x{0340}\x{0341}]/) {
      return undef;
    }

    $label =~ tr{\x{2F868}\x{2F874}\x{2F91F}\x{2F95F}\x{2F9BF}}
        {\x{36FC}\x{5F53}\x{243AB}\x{7AEE}\x{45D7}};
    $label = cor5_reordering ($label);
  } elsif (CHROME) { # wrong (old)
    $label =~ tr{\x{2F868}\x{2F874}\x{2F91F}\x{2F95F}\x{2F9BF}}
        {\x{2136A}\x{5F33}\x{43AB}\x{7AAE}\x{4D57}};
  } elsif (IE) {
    $label =~ tr{\x{2F868}\x{2F874}\x{2F91F}\x{2F95F}\x{2F9BF}}
        {\x{2136A}\x{5F33}\x{43AB}\x{7AAE}\x{4D57}};
  } elsif (THIS) {
    $label =~ tr{\x{2F868}\x{2F874}\x{2F91F}\x{2F95F}\x{2F9BF}}
        {\x{36FC}\x{5F53}\x{243AB}\x{7AEE}\x{45D7}};
  }
  $label = nameprepmapping ($label);

  if (THIS or GECKO) {
    my $has_unassigned = not defined eval { nameprepunassigned ($label); 1 };
    $label = NFKC ($label);
    if ($has_unassigned) {
      $label = nameprepmapping ($label);
      $label = NFKC $label;
    }
  } else {
    $label = Unicode::Stringprep::_NFKC_3_2 ($label);
  }
  
  if (not defined eval { nameprepprohibited ($label); 1 }) {
    return undef;
  }
  return $label;
} # nameprep

sub nameprep_bidi ($) {
  my $label = shift;

  if (GECKO or IE) {
    if (not defined eval { nameprepbidirule ($label); 1 }) {
      return undef;
    }
  } else {
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
  }

  return $label;
} # nameprep_bidi

sub label_nameprep ($;%) {
  my $s = shift;
  my %args = @_;

  $s = nameprep $s;
  return undef unless defined $s;

  unless ($args{no_bidi}) {
    $s = nameprep_bidi $s;
    return undef unless defined $s;
  }

  unless ($args{allow_unassinged}) {
    $s = eval { nameprepunassigned ($s) };
    return undef unless defined $s;
  }
  
  return $s;
} # label_nameprep

sub label_to_ascii ($;%) {
  my $s = shift;
  my %args = @_;
  
  $s =~ tr/\x09\x0A\x0D//d;

  if ($s =~ /[^\x00-\x7F]/) {
    $s = label_nameprep $s,
        allow_unassinged => $args{allow_unassigned},
        no_bidi => $args{no_bidi};
    return undef unless defined $s;
  }

  if ($args{use_std3_ascii_rules}) {
    return undef if $s =~ /[\x00-\x2C\x2E\x2F\x3A-\x40\x5B-\x60\x7B-\x7F]/;
  }

  return undef if $s =~ /\A-/ or $s =~ /-\z/;

  if ($s =~ /[^\x00-\x7F]/) {
    return undef if $s =~ /^[Xx][Nn]--/;

    $s = encode_punycode $s;
    return undef unless defined $s;

    $s = 'xn--' . $s;
  }

  return undef if (length $s) == 0;
  return undef if (length $s) > 63;

  return $s;
} # label_to_ascii

use Web::DomainName::IDNEnabled;
use Char::Class::IDNBlacklist qw(InIDNBlacklistChars);

sub to_ascii ($$) {
  my ($class, $s) = @_;

  my $fallback = GECKO ? $s : undef;
  $fallback =~ tr/A-Z/a-z/ if defined $fallback;

  if (THIS) {
    return undef if $s =~ m{^%5[Bb]};
  }

  if (THIS or CHROME) {
    $s = Encode::encode ('utf-8', $s);
    $s =~ s{%([0-9A-Fa-f]{2})}{pack 'C', hex $1}ge;
    $s = Encode::decode ('utf-8', $s); # XXX error-handling
  }    
  
  if (IE) {
    $s =~ s{%([01][0-9A-Fa-f]|2[02DdEeFf]|3[0-9CcEeFf]|4[1-9A-Fa-f]|5[0-9AaCcEeFf]|6[0-9A-Fa-f]|7[0-9A-Fa-f])}{pack 'C', hex $1}ge;
  }

  my $need_punycode = $s =~ /[^\x00-\x7F]/;

  my $has_root_dot;
  if (IE or CHROME) {
    $has_root_dot = 1 if $s =~ s/[.\x{3002}\x{FF0E}\x{FF61}]\z//;
  }
  
  if (THIS or IE or GECKO) {
    $s = nameprep $s;
    return $fallback unless defined $s;
  }

  if (GECKO) {
    if ($s =~ /[\x00\x20]/) {
      if ($fallback =~ /[\x00\x20]/) {
        return undef;
      } elsif (not defined eval { nameprepprohibited ($fallback); 1 }) {
        return $fallback;
      } 
    }
  }

  return undef if CHROME and $s =~ /%/;

  $s =~ tr/\x{3002}\x{FF0E}\x{FF61}/.../;

  $s =~ s{([\x20-\x24\x26-\x2A\x2C\x3C-\x3E\x40\x5E\x60\x7B\x7C\x7D])}{
    sprintf '%%%02X', ord $1;
  }ge if CHROME;

  $need_punycode = 1 if IE and $s =~ /(?:^|\.)xn--/;

  if (THIS) {
    $has_root_dot = 1 if $s =~ s/[.]\z//;
  }

  my @label = split /\./, $s, -1;
  @label = ('') unless @label;

  if ($need_punycode) {
    my $idn_enabled;
    if (GECKO) {
      my $tld = [grep { length $_ } reverse @label]->[0] || '';
      if ($tld =~ /[^\x00-\x7F]/) {
        $tld = 'xn--' . eval { encode_punycode $tld } || '';
      }
      if ($Web::DomainName::IDNEnabled::TLDs->{$tld}) {
        if ((join '', @label) =~ /\p{InIDNBlacklistChars}/) {
          #
        } else {
          $idn_enabled = 1;
        }
      }
    }

    @label = map {
      if (IE) {
        my $label = $_;
        if ($label =~ /[^\x00-\x7F]/) {
          $label = 'xn--' . eval { encode_punycode $_ };
          return undef unless defined $label;
        }
        {
          my $p_label = $label;
          if ($label =~ /^xn--/) {
            $label =~ s/^xn--//;
            
            $label = decode_punycode $label;
            return undef unless defined $label;
          }
          
          my $a_label = label_to_ascii $label,
              allow_unassinged => 0,
              use_std3_ascii_rules => 1,
              no_bidi => 0;
          return undef unless defined $a_label;
          return undef unless $a_label eq $p_label;
        }
        return undef if $label =~ /\x{3002}/;

        $label;
      } else {
        my $label = $_;

        if (CHROME) {
          $label = nameprep $label;
          return $fallback unless defined $label;
        }

        $label = nameprep_bidi $label;
        return $fallback unless defined $label;

        if ($label =~ /[^\x00-\x7F]/) {
          unless ($idn_enabled) {
            if (THIS or CHROME) {
              return undef if $label =~ /^xn--/;
            }
            $label = eval { encode_punycode $label };
            return $fallback unless defined $label;
            $label = 'xn--' . $label;
            return $fallback if length $label > 63;
          }
        } else {
          $label = substr $label, 0, 62 if GECKO;
          if (THIS or CHROME) {
            return undef if $label eq '';
          }
          return undef if length $label > 63;
        }
        $label;
      }
    } @label;
  }

  push @label, '' if $has_root_dot;
  $s = join '.', @label;

  if (CHROME) {
    $s = encode 'utf-8', $s;
    $s =~ s{%([0-9A-Fa-f]{2})}{encode 'iso-8859-1', chr hex $1}ge;
    $s =~ tr/A-Z/a-z/;
  }

  if ($s =~ /\A\[/ and $s =~ /\]\z/) {
    my $t = canonicalize_ipv6_addr substr $s, 1, -2 + length $s;
    return '[' . $t . ']' if defined $t;
  } elsif (THIS) {
    return undef if $s =~ /:/;
  }
  
  if (THIS) {
    if ($s =~ /[\x00\x25\x2F\x3F\x5C]/) {
      return undef;
    }
  } elsif (CHROME) {
    if ($s =~ /[\x00-\x1F\x25\x2F\x3A\x3B\x3F\x5B-\x5E\x7E\x7F]/) {
      return undef;
    }
  } elsif (IE) {
    if ($s =~ /[\x00\x2F\x3F\x5C]|%00|%(?![0-9A-Fa-f]{2})/) {
      return undef;
    }
  }

  if (THIS) {
    $s =~ s{([\x00-\x2A\x2C\x2F\x3B-\x40\x5C\x5E\x60\x7B-\x7D\x7F])}{
      sprintf '%%%02X', ord $1;
    }ge;
  } elsif (IE) {
    $s =~ s{([\x00-\x20\x22\x3C\x3E\x5C\x5E\x60\x7B-\x7D\x7F])}{
      sprintf '%%%02x', ord $1;
    }ge;
  } elsif (CHROME) {
    $s =~ s{([\x20-\x24\x26-\x2A\x2C\x3C-\x3E\x40\x5E\x60\x7B\x7C\x7D])}{
      sprintf '%%%02X', ord $1;
    }ge;
  }

  # IPv4address
  IPv4: {
    my @label = split /\./, $s, -1;
    @label = map { $to_number->($_) } @label;
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
        last IPv4;
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
        last IPv4;
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
        last IPv4;
      }
    } elsif (@label == 1) {
      if (defined $label[0] and
          $label[0] <= 0xFFFFFFFF) {
        $label[3] = $label[0] & 0xFF;
        $label[2] = ($label[0] >> 8) & 0xFF;
        $label[1] = ($label[0] >> 16) & 0xFF;
        $label[0] = $label[0] >> 24;
      } else {
        last IPv4;
      }
    } else {
      last IPv4;
    }
    return join '.', @label;
  } # IPv4
  
  return $s;
} # to_ascii

sub canonicalize_url ($$;$) {
  my ($class, $parsed_url, $charset) = @_;

  return $parsed_url if $parsed_url->{invalid};

  $parsed_url->{scheme} = $parsed_url->{scheme_normalized};

  if (defined $parsed_url->{password}) {
    if (not length $parsed_url->{password}) {
      delete $parsed_url->{password};
    } else {
      my $s = Encode::encode ('utf-8', $parsed_url->{password});
      $s =~ s{([^\x21\x24-\x2E\x30-\x39\x41-\x5A\x5F\x61-\x7A\x7E])}{
        sprintf '%%%02X', ord $1;
      }ge;
      $parsed_url->{password} = $s;
    }
  }

  if (defined $parsed_url->{user}) {
    if (not length $parsed_url->{user}) {
      delete $parsed_url->{user} unless defined $parsed_url->{password};
    } else {
      my $s = Encode::encode ('utf-8', $parsed_url->{user});
      $s =~ s{([^\x21\x24-\x2E\x30-\x39\x41-\x5A\x5F\x61-\x7A\x7E])}{
        sprintf '%%%02X', ord $1;
      }ge;
      $parsed_url->{user} = $s;
    }
  }

  if (defined $parsed_url->{host}) {
    my $orig_host = $parsed_url->{host};
    $parsed_url->{host} = $class->to_ascii ($parsed_url->{host});
    if (not defined $parsed_url->{host}) {
      %$parsed_url = (invalid => 1);
      return $parsed_url;
    }
  }

  if (defined $parsed_url->{port}) {
    if (not length $parsed_url->{port}) {
      delete $parsed_url->{port};
    } elsif (not $parsed_url->{port} =~ /\A[0-9]+\z/) {
      %$parsed_url = (invalid => 1);
      return $parsed_url;
    } elsif ($parsed_url->{port} > 65535) {
      %$parsed_url = (invalid => 1);
      return $parsed_url;
    } else {
      $parsed_url->{port} += 0;
      my $default = $DefaultPort->{$parsed_url->{scheme_normalized}};
      if (defined $default and $default == $parsed_url->{port}) {
        delete $parsed_url->{port};
      }
    }
  }

  PATH: {
    if ($parsed_url->{is_hierarchical}) {
      $parsed_url->{path} = '/'
          if not defined $parsed_url->{path} or not length $parsed_url->{path};
    } elsif ($parsed_url->{scheme_normalized} eq 'mailto') {
      #
    } else {
      ## Non-hierarchical scheme except for |mailto:|
      $parsed_url->{path} = '' unless defined $parsed_url->{path};
      my $s = Encode::encode ('utf-8', $parsed_url->{path});
      $s =~ s{([^\x20-\x7E])}{
        sprintf '%%%02X', ord $1;
      }ge;
      $parsed_url->{path} = $s;
      last PATH;
    }
    
    if (defined $parsed_url->{path}) {
      my $s = Encode::encode ('utf-8', $parsed_url->{path});
      $s =~ s{([^\x21\x23-\x3B\x3D\x3F-\x5B\x5D\x5F\x61-\x7A\x7E])}{
        sprintf '%%%02X', ord $1;
      }ge;
      $s =~ s{%(3[0-9]|[46][1-9A-Fa-f]|[57][0-9Aa]|2[DdEe]|5[Ff]|7[Ee])}{
        pack 'C', hex $1;
      }ge;
      $parsed_url->{path} = $s;
    }
  } # PATH

  if (defined $parsed_url->{query}) {
    my $charset = $parsed_url->{is_hierarchical} ? $charset || 'utf-8' : 'utf-8';
    if ($charset =~ /^
      utf-8|
      iso-8859-[0-9]+|
      us-ascii|
      shift_jis|
      euc-jp|
      windows-[0-9]+|
      iso-2022-[0-9a-zA-Z-]+|
      hz-gb-2312
    $/xi) { # XXX Web Encodings
      #
    } else {
      $charset = 'utf-8';
    }
    my $s = Encode::encode ($charset, $parsed_url->{query});
    $s =~ s{([^\x21\x23-\x3B\x3D\x3F-\x7E])}{
      sprintf '%%%02X', ord $1;
    }ge;
    $parsed_url->{query} = $s;
  }

  if (defined $parsed_url->{fragment}) {
    $parsed_url->{fragment} =~ s{([\x00-\x1F\x7F-\x9F])}{
      join '',
          map { sprintf '%%%02X', ord $_ }
          split //,
          Encode::encode 'utf-8', $1;
    }ge;
  }

  return $parsed_url;
} # canonicalize_url

sub serialize_url ($$) {
  my ($class, $parsed_url) = @_;

  return undef if $parsed_url->{invalid};

  my $u = $parsed_url->{scheme} . ':';
  if (defined $parsed_url->{host} or
      defined $parsed_url->{port} or
      defined $parsed_url->{user} or
      defined $parsed_url->{password}) {
    $u .= '//';
    if (defined $parsed_url->{user} or
        defined $parsed_url->{password}) {
      $u .= $parsed_url->{user} if defined $parsed_url->{user};
      if (defined $parsed_url->{password}) {
        $u .= ':' . $parsed_url->{password};
      }
      $u .= '@';
    }
    $u .= $parsed_url->{host} if defined $parsed_url->{host};
    if (defined $parsed_url->{port}) {
      $u .= ':' . $parsed_url->{port};
    }
  }
  $u .= '/' . $parsed_url->{drive} . ':' if defined $parsed_url->{drive};
  $u .= $parsed_url->{path} if defined $parsed_url->{path};
  if (defined $parsed_url->{query}) {
    $u .= '?' . $parsed_url->{query};
  }
  if (defined $parsed_url->{fragment}) {
    $u .= '#' . $parsed_url->{fragment};
  }
  return $u;
} # serialize_url

## Following tables are taken from Unicode::Stringprep.

my $is_Combining = Unicode::Stringprep::_compile_set(  0x0300,0x0314, 0x0316,0x0319, 0x031C,0x0320,
    0x0321,0x0322, 0x0323,0x0326, 0x0327,0x0328, 0x0329,0x0333, 0x0334,0x0338,
    0x0339,0x033C, 0x033D,0x0344, 0x0347,0x0349, 0x034A,0x034C, 0x034D,0x034E,
    0x0360,0x0361, 0x0363,0x036F, 0x0483,0x0486, 0x0592,0x0595, 0x0597,0x0599,
    0x059C,0x05A1, 0x05A3,0x05A7, 0x05A8,0x05A9, 0x05AB,0x05AC, 0x0653,0x0654,
    0x06D6,0x06DC, 0x06DF,0x06E2, 0x06E7,0x06E8, 0x06EB,0x06EC, 0x0732,0x0733,
    0x0735,0x0736, 0x0737,0x0739, 0x073B,0x073C, 0x073F,0x0741, 0x0749,0x074A,
    0x0953,0x0954, 0x0E38,0x0E39, 0x0E48,0x0E4B, 0x0EB8,0x0EB9, 0x0EC8,0x0ECB,
    0x0F18,0x0F19, 0x0F7A,0x0F7D, 0x0F82,0x0F83, 0x0F86,0x0F87, 0x20D0,0x20D1,
    0x20D2,0x20D3, 0x20D4,0x20D7, 0x20D8,0x20DA, 0x20DB,0x20DC, 0x20E5,0x20E6,
    0x302E,0x302F, 0x3099,0x309A, 0xFE20,0xFE23,
    0x1D165,0x1D166, 0x1D167,0x1D169, 0x1D16E,0x1D172, 0x1D17B,0x1D182,
    0x1D185,0x1D189, 0x1D18A,0x1D18B, 0x1D1AA,0x1D1AD, 
    map { ($_,$_) } 0x0315, 0x031A, 0x031B, 0x0345, 0x0346, 0x0362, 0x0591,
    0x0596, 0x059A, 0x059B, 0x05AA, 0x05AD, 0x05AE, 0x05AF, 0x05B0, 0x05B1,
    0x05B2, 0x05B3, 0x05B4, 0x05B5, 0x05B6, 0x05B7, 0x05B8, 0x05B9, 0x05BB,
    0x05BC, 0x05BD, 0x05BF, 0x05C1, 0x05C2, 0x05C4, 0x064B, 0x064C, 0x064D,
    0x064E, 0x064F, 0x0650, 0x0651, 0x0652, 0x0655, 0x0670, 0x06E3, 0x06E4,
    0x06EA, 0x06ED, 0x0711, 0x0730, 0x0731, 0x0734, 0x073A, 0x073D, 0x073E,
    0x0742, 0x0743, 0x0744, 0x0745, 0x0746, 0x0747, 0x0748, 0x093C, 0x094D,
    0x0951, 0x0952, 0x09BC, 0x09CD, 0x0A3C, 0x0A4D, 0x0ABC, 0x0ACD, 0x0B3C,
    0x0B4D, 0x0BCD, 0x0C4D, 0x0C55, 0x0C56, 0x0CCD, 0x0D4D, 0x0DCA, 0x0E3A,
    0x0F35, 0x0F37, 0x0F39, 0x0F71, 0x0F72, 0x0F74, 0x0F80, 0x0F84, 0x0FC6,
    0x1037, 0x1039, 0x1714, 0x1734, 0x17D2, 0x18A9, 0x20E1, 0x20E7, 0x20E8,
    0x20E9, 0x20EA, 0x302A, 0x302B, 0x302C, 0x302D, 0xFB1E, 0x1D16D,         );

my $is_HangulLV = Unicode::Stringprep::_compile_set( map { ($_,$_) }     0xAC00, 0xAC1C, 0xAC38,
    0xAC54, 0xAC70, 0xAC8C, 0xACA8, 0xACC4, 0xACE0, 0xACFC, 0xAD18, 0xAD34,
    0xAD50, 0xAD6C, 0xAD88, 0xADA4, 0xADC0, 0xADDC, 0xADF8, 0xAE14, 0xAE30,
    0xAE4C, 0xAE68, 0xAE84, 0xAEA0, 0xAEBC, 0xAED8, 0xAEF4, 0xAF10, 0xAF2C,
    0xAF48, 0xAF64, 0xAF80, 0xAF9C, 0xAFB8, 0xAFD4, 0xAFF0, 0xB00C, 0xB028,
    0xB044, 0xB060, 0xB07C, 0xB098, 0xB0B4, 0xB0D0, 0xB0EC, 0xB108, 0xB124,
    0xB140, 0xB15C, 0xB178, 0xB194, 0xB1B0, 0xB1CC, 0xB1E8, 0xB204, 0xB220,
    0xB23C, 0xB258, 0xB274, 0xB290, 0xB2AC, 0xB2C8, 0xB2E4, 0xB300, 0xB31C,
    0xB338, 0xB354, 0xB370, 0xB38C, 0xB3A8, 0xB3C4, 0xB3E0, 0xB3FC, 0xB418,
    0xB434, 0xB450, 0xB46C, 0xB488, 0xB4A4, 0xB4C0, 0xB4DC, 0xB4F8, 0xB514,
    0xB530, 0xB54C, 0xB568, 0xB584, 0xB5A0, 0xB5BC, 0xB5D8, 0xB5F4, 0xB610,
    0xB62C, 0xB648, 0xB664, 0xB680, 0xB69C, 0xB6B8, 0xB6D4, 0xB6F0, 0xB70C,
    0xB728, 0xB744, 0xB760, 0xB77C, 0xB798, 0xB7B4, 0xB7D0, 0xB7EC, 0xB808,
    0xB824, 0xB840, 0xB85C, 0xB878, 0xB894, 0xB8B0, 0xB8CC, 0xB8E8, 0xB904,
    0xB920, 0xB93C, 0xB958, 0xB974, 0xB990, 0xB9AC, 0xB9C8, 0xB9E4, 0xBA00,
    0xBA1C, 0xBA38, 0xBA54, 0xBA70, 0xBA8C, 0xBAA8, 0xBAC4, 0xBAE0, 0xBAFC,
    0xBB18, 0xBB34, 0xBB50, 0xBB6C, 0xBB88, 0xBBA4, 0xBBC0, 0xBBDC, 0xBBF8,
    0xBC14, 0xBC30, 0xBC4C, 0xBC68, 0xBC84, 0xBCA0, 0xBCBC, 0xBCD8, 0xBCF4,
    0xBD10, 0xBD2C, 0xBD48, 0xBD64, 0xBD80, 0xBD9C, 0xBDB8, 0xBDD4, 0xBDF0,
    0xBE0C, 0xBE28, 0xBE44, 0xBE60, 0xBE7C, 0xBE98, 0xBEB4, 0xBED0, 0xBEEC,
    0xBF08, 0xBF24, 0xBF40, 0xBF5C, 0xBF78, 0xBF94, 0xBFB0, 0xBFCC, 0xBFE8,
    0xC004, 0xC020, 0xC03C, 0xC058, 0xC074, 0xC090, 0xC0AC, 0xC0C8, 0xC0E4,
    0xC100, 0xC11C, 0xC138, 0xC154, 0xC170, 0xC18C, 0xC1A8, 0xC1C4, 0xC1E0,
    0xC1FC, 0xC218, 0xC234, 0xC250, 0xC26C, 0xC288, 0xC2A4, 0xC2C0, 0xC2DC,
    0xC2F8, 0xC314, 0xC330, 0xC34C, 0xC368, 0xC384, 0xC3A0, 0xC3BC, 0xC3D8,
    0xC3F4, 0xC410, 0xC42C, 0xC448, 0xC464, 0xC480, 0xC49C, 0xC4B8, 0xC4D4,
    0xC4F0, 0xC50C, 0xC528, 0xC544, 0xC560, 0xC57C, 0xC598, 0xC5B4, 0xC5D0,
    0xC5EC, 0xC608, 0xC624, 0xC640, 0xC65C, 0xC678, 0xC694, 0xC6B0, 0xC6CC,
    0xC6E8, 0xC704, 0xC720, 0xC73C, 0xC758, 0xC774, 0xC790, 0xC7AC, 0xC7C8,
    0xC7E4, 0xC800, 0xC81C, 0xC838, 0xC854, 0xC870, 0xC88C, 0xC8A8, 0xC8C4,
    0xC8E0, 0xC8FC, 0xC918, 0xC934, 0xC950, 0xC96C, 0xC988, 0xC9A4, 0xC9C0,
    0xC9DC, 0xC9F8, 0xCA14, 0xCA30, 0xCA4C, 0xCA68, 0xCA84, 0xCAA0, 0xCABC,
    0xCAD8, 0xCAF4, 0xCB10, 0xCB2C, 0xCB48, 0xCB64, 0xCB80, 0xCB9C, 0xCBB8,
    0xCBD4, 0xCBF0, 0xCC0C, 0xCC28, 0xCC44, 0xCC60, 0xCC7C, 0xCC98, 0xCCB4,
    0xCCD0, 0xCCEC, 0xCD08, 0xCD24, 0xCD40, 0xCD5C, 0xCD78, 0xCD94, 0xCDB0,
    0xCDCC, 0xCDE8, 0xCE04, 0xCE20, 0xCE3C, 0xCE58, 0xCE74, 0xCE90, 0xCEAC,
    0xCEC8, 0xCEE4, 0xCF00, 0xCF1C, 0xCF38, 0xCF54, 0xCF70, 0xCF8C, 0xCFA8,
    0xCFC4, 0xCFE0, 0xCFFC, 0xD018, 0xD034, 0xD050, 0xD06C, 0xD088, 0xD0A4,
    0xD0C0, 0xD0DC, 0xD0F8, 0xD114, 0xD130, 0xD14C, 0xD168, 0xD184, 0xD1A0,
    0xD1BC, 0xD1D8, 0xD1F4, 0xD210, 0xD22C, 0xD248, 0xD264, 0xD280, 0xD29C,
    0xD2B8, 0xD2D4, 0xD2F0, 0xD30C, 0xD328, 0xD344, 0xD360, 0xD37C, 0xD398,
    0xD3B4, 0xD3D0, 0xD3EC, 0xD408, 0xD424, 0xD440, 0xD45C, 0xD478, 0xD494,
    0xD4B0, 0xD4CC, 0xD4E8, 0xD504, 0xD520, 0xD53C, 0xD558, 0xD574, 0xD590,
    0xD5AC, 0xD5C8, 0xD5E4, 0xD600, 0xD61C, 0xD638, 0xD654, 0xD670, 0xD68C,
    0xD6A8, 0xD6C4, 0xD6E0, 0xD6FC, 0xD718, 0xD734, 0xD750, 0xD76C, 0xD788, );

sub cor5_reordering ($) {
  my $s = shift;
  $s =~ s{
    \x{09C7}$is_Combining+[\x{09BE}\x{09D7}]		| # BENGALI VOWEL SIGN E
    \x{0B47}$is_Combining+[\x{0B3E}\x{0B56}\x{0B57}]	| # ORIYA VOWEL SIGN E
    \x{0BC6}$is_Combining+[\x{0BBE}\x{0BD7}]		| # TAMIL VOWEL SIGN E
    \x{0BC7}$is_Combining+\x{0BBE}			| # TAMIL VOWEL SIGN EE
    \x{0B92}$is_Combining+\x{0BD7}			| # TAMIL LETTER O
    \x{0CC6}$is_Combining+[\x{0CC2}\x{0CD5}\x{0CD6}]	| # KANNADA VOWEL SIGN E
    [\x{0CBF}\x{0CCA}]$is_Combining\x{0CD5}		| # KANNADA VOWEL SIGN I or KANNADA VOWEL SIGN O
    \x{0D47}$is_Combining+\x{0D3E}			| # MALAYALAM VOWEL SIGN EE
    \x{0D46}$is_Combining+[\x{0D3E}\x{0D57}]		| # MALAYALAM VOWEL SIGN E
    \x{1025}$is_Combining+\x{102E}			| # MYANMAR LETTER U
    \x{0DD9}$is_Combining+[\x{0DCF}\x{0DDF}]		| # SINHALA VOWEL SIGN KOMBUVA
    [\x{1100}-\x{1112}]$is_Combining[\x{1161}-\x{1175} ] | # HANGUL CHOSEONG KIYEOK..HIEUH
    ($is_HangulLV|[\x{1100}-\x{1112}][\x{1161}-\x{1175}])($is_Combining)([\x{11A8}-\x{11C2}]) # HANGUL SyllableType=LV
  }{
    my $t = substr $s, $-[0], $+[0] - $-[0];
    substr ($t, -2) = substr ($t, -1, 1) . substr ($t, -2, 1);
    $t;
  }goesx;
  return $s;
}


1;
