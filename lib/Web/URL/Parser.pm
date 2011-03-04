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

sub canonicalize_url ($$;$) {
  my ($class, $parsed_url, $charset) = @_;

  return $parsed_url if $parsed_url->{invalid};

  $parsed_url->{scheme} = $parsed_url->{scheme_normalized};

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
