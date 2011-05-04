package Web::URL::Parser;
use strict;
use warnings;
use Encode;
require utf8;

our $IsHierarchicalScheme = {
  http => 1,
  https => 1,
  ftp => 1,
  ldap => 1,
};

our $DefaultPort = {
  http => 80,
  https => 443,
};

sub _preprocess_input ($$) {
  if (utf8::is_utf8 ($_[1])) {
    ## Replace surrogate code points, noncharacters, and non-Unicode
    ## characters by U+FFFD REPLACEMENT CHARACTER, as they break
    ## Perl's regular expression character class handling.
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

  ## Remove leading and trailing control characters.
  $_[1] =~ s{\A[\x00-\x20]+}{};
  $_[1] =~ s{[\x00-\x20]+\z}{};
} # _preprocess_input

sub parse_absolute_url ($$) {
  my ($class, $input) = @_;
  my $result = {};

  $class->_preprocess_input ($input);

  $class->_find_scheme (\$input => $result);
  return $result if $result->{invalid};

  if (defined $result->{scheme_normalized} and
      $result->{scheme_normalized} =~ /\A[a-z]\z/) {
    # XXX drive

  }

  if (defined $result->{scheme_normalized} and
      $result->{scheme_normalized} eq 'file') {
    # XXX file: URL

  }

  if (defined $result->{scheme_normalized} and
      $result->{scheme_normalized} eq 'mailto') {
    # XXX mailto: URL

  }

  if (defined $result->{scheme_normalized} and
      $IsHierarchicalScheme->{$result->{scheme_normalized}}) {
    $class->_find_authority_path_query_fragment (\$input => $result);
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
  my ($class, $inputref => $result) = @_;

  ## Slash characters
  $$inputref =~ s{\A[/\\]+}{};

  ## Authority terminating characters (including slash characters)
  if ($$inputref =~ s{\A([^/\\?\#;]*)(?=[/\\?\#;])}{}) {
    $result->{authority} = $1;
  } else {
    $result->{authority} = $$inputref; 
    return;
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

  ## NOTE: Not in the spec.
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

  if ($parsed_spec->{scheme_normalized} eq
      $parsed_base_url->{scheme_normalized} and
      $IsHierarchicalScheme->{$parsed_spec->{scheme_normalized}}) {
    $spec = substr $spec, 1 + length $parsed_spec->{scheme};
    return $class->_resolve_relative_url (\$spec, $parsed_base_url);
  } elsif ($IsHierarchicalScheme->{$parsed_spec->{scheme_normalized}}) {
    if (defined $parsed_spec->{path}) {
      $parsed_spec->{path} = $class->_remove_dot_segments
          ($parsed_spec->{path});
    }
  }

  return $parsed_spec;
} # resolve_url

sub _resolve_relative_url ($$$) {
  my ($class, $specref, $parsed_base_url) = @_;

  # XXX non-hierarchical URL

  if ($$specref eq '') {
    my $url = {%$parsed_base_url};
    delete $url->{fragment};
    return $url;
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
    if ($r_path =~ s{\A([^/\\?\#;]*)(?=[/\\?\#;])}{}) {
      $r_authority = $1;
    } else {
      $r_authority = $r_path;
      $r_path = undef;
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

    my $r_authority = $parsed_base_url->{host};
    $r_authority .= ':' . $parsed_base_url->{port}
        if defined $parsed_base_url->{port};
    $r_authority = $parsed_base_url->{user} .
        (defined $parsed_base_url->{password}
           ? ':' . $parsed_base_url->{password}
           : '') .
        '@' . $r_authority if defined $parsed_base_url->{user};

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
         # XXX This would not save existence of /query/ component
         '?' . (defined $parsed_base_url->{query} ? $parsed_base_url->{query} : '') .
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
      $result->{query} = '' unless defined $result->{query}; # for consistency
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
    next L if s/^\.\.?\///;
    next L if s/^\/\.(?:\/|\z)/\//;
    if (s/^\/\.\.(\/|\z)/\//) {
      $buf =~ s/\/?[^\/]*$//;
      next L;
    }
    last Z if s/^\.\.?\z//;
    s{^(/?(?:(?!/).)*)}{}s;
    $buf .= $1;
  }
  return $buf;
} # _remove_dot_segments

use Net::IDN::Nameprep;
use Net::LibIDN;

sub encode_punycode ($) {
  # XXX
  return eval { Encode::decode 'utf-8', Net::LibIDN::idn_punycode_encode $_[0], 'utf-8' };
} # decode_punycode

my $to_number = sub {
  my $n = shift;
  if ($n =~ /\A0[Xx]([0-9]*)\z/) {
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
use Char::Prop::Unicode::BidiClass;

sub to_ascii ($$) {
  my ($class, $s) = @_;

  ## If chrome:

  $s =~ tr/\x09\x0A\x0D//d;

  if (not 'gecko') {
    $s = Encode::encode ('utf-8', $s);
    $s =~ s{%([0-9A-Fa-f]{2})}{pack 'C', hex $1}ge;
    $s = Encode::decode ('utf-8', $s); # XXX error-handling
    
    if ($s =~ /%/) {
      return undef;
    }
  }

  $s =~ tr/\x{3002}\x{FF0E}\x{FF61}/.../;

  my @label;
  my $need_punycode;
  for my $label (split /\./, $s, -1) {
    if (not 'gecko') {
      $label =~ s{([\x20-\x24\x26-\x2A\x2C\x3C-\x3E\x40\x5E\x60\x7B\x7C\x7D])}{
        sprintf '%%%02X', ord $1;
      }ge;
    }

    if ($label =~ /[^\x00-\x7F]/) {
      $need_punycode = 1;
    }

    $label =~ tr{\x{2F868}\x{2F874}\x{2F91F}\x{2F95F}\x{2F9BF}}
        {\x{2136A}\x{5F33}\x{43AB}\x{7AAE}\x{4D57}};
    $label = nameprepmapping ($label);
    $label = Unicode::Stringprep::_NFKC_3_2 ($label);

    if (not defined eval { nameprepprohibited ($label); 1 }) {
      return undef;
    }

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

    if (not 'gecko') {
      if ($label =~ /^xn--/ and $label =~ /[^\x00-\x7F]/) {
        return undef;
      }
    }

    push @label, $label;
  } # $label

  if ($need_punycode) {
    my $empty = 0;
    @label = map {
      if (/[^\x00-\x7F]/) {
        my $label = 'xn--' . eval { encode_punycode $_ }; # XXX
        
        return undef if length $label > 63;
        $label;
      } elsif ($_ eq '') {
        $empty++;
        $_;
      } else {
        return undef if length $_ > 63;
        $_;
      }
    } @label;
    if ($empty > 1 or 
        ($empty == 1 and (@label == 1 or not $label[-1] eq ''))) {
      return undef;
    }
  }

  $s = join '.', @label;

  if (not 'gecko') {
    $s = encode 'utf-8', $s;
    $s =~ s{%([0-9A-Fa-f]{2})}{encode 'iso-8859-1', chr hex $1}ge;
    $s =~ tr/A-Z/a-z/;
  }

  if ($s =~ /[\x00-\x1F\x25\x2F\x3A\x3B\x3F\x5C\x5E\x7E\x7F]/) {
    return undef;
  }

  if (not 'gecko') {
    $s =~ s{([\x20-\x24\x26-\x2A\x2C\x3C-\x3E\x40\x5E\x60\x7B\x7C\x7D])}{
      sprintf '%%%02X', ord $1;
    }ge;
  }

  if ($s =~ /\A\[/ and $s =~ /\]\z/) {
    # XXX canonicalize as an IPv6 address
    return $s;
  }

  if ($s =~ /\[/ or $s =~ /\]/) {
    return undef;
  }

  # IPv4address
  IPv4: {
    my @label = split /\./, $s, -1;
    last IPv4 unless @label;
    my @addr = (0, 0, 0, 0);
    my $j = 0;
    while (@label) {
      my $n = $to_number->(shift @label);
      if (not defined $n or $n > 0xFFFFFFFF) {
        last IPv4;
      } elsif ($n > 0xFFFFFF) {
        last IPv4 if $j > 0;
        $addr[$j + 0] = ($n >> 24) & 0xFF;
        $addr[$j + 1] = ($n >> 16) & 0xFF;
        $addr[$j + 2] = ($n >>  8) & 0xFF;
        $addr[$j + 3] = ($n >>  0) & 0xFF;
      } elsif ($n > 0xFFFF) {
        last IPv4 if $j > 1;
        $addr[$j + 0] = ($n >> 16) & 0xFF;
        $addr[$j + 1] = ($n >>  8) & 0xFF;
        $addr[$j + 2] = ($n >>  0) & 0xFF;
      } elsif ($n > 0xFF) {
        last IPv4 if $j > 2;
        $addr[$j + 0] = ($n >>  8) & 0xFF;
        $addr[$j + 1] = ($n >>  0) & 0xFF;
      } else {
        last IPv4 if $j > 3;
        $addr[$j + 0] = ($n >>  0) & 0xFF;
      }
      $j++;
    } # $i
    last IPv4 if @label;
    return join '.', @addr;
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
      if ('gecko' and $orig_host !~ /[\x00\x20]/) {
        $parsed_url->{host} = lc $orig_host;
      } else {
        %$parsed_url = (invalid => 1);
        return $parsed_url;
      }
    } elsif ('gecko' and $orig_host =~ /[\x00\x20]/) {
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

  if ($IsHierarchicalScheme->{$parsed_url->{scheme}}) {
    $parsed_url->{path} = '/'
        if not defined $parsed_url->{path} or not length $parsed_url->{path};
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

  if (defined $parsed_url->{query}) {
    my $charset = $charset || 'utf-8';
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
    $parsed_url->{fragment} =~ s{(\x00|\x01|\x02|\x03|\x04|\x05|\x06|\x07|\x08|\x09|\x0A|\x0B|\x0C|\x0D|\x0E|\x0F|\x10|\x11|\x12|\x13|\x14|\x15|\x16|\x17|\x18|\x19|\x1A|\x1B|x1C|\x1D|\x1E|\x1F|\x20|\x22|\x3C|\x3E|\x7F)}{
      sprintf '%%%02X', ord $1;
    }ge;
    $parsed_url->{fragment} =~ s{(\x80|\x81|\x82|\x83|\x84|\x85|\x86|\x87|\x88|\x89|\x8A|\x8B|\x8C|\x8D|\x8E|\x8F|\x90|\x91|\x92|\x93|\x94|\x95|\x96|\x97|\x98|\x99|\x9A|\x9B|\x9C|\x9D|\x9E|\x9F)}{
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
  $u .= $parsed_url->{path} if defined $parsed_url->{path};
  if (defined $parsed_url->{query}) {
    $u .= '?' . $parsed_url->{query};
  }
  if (defined $parsed_url->{fragment}) {
    $u .= '#' . $parsed_url->{fragment};
  }
  return $u;
} # serialize_url

1;
