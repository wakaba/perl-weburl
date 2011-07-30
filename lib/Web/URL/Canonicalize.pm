package Web::URL::Canonicalize;
use strict;
use warnings;
our $VERSION = '1.0';
use Encode;
require utf8;
use Web::DomainName::Canonicalize;
use Exporter::Lite;

our @EXPORT = qw(url_to_canon_url);

our @EXPORT_OK = qw(
  parse_url resolve_url canonicalize_parsed_url serialize_parsed_url
);

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
  telnet => 23,
  tn3270 => 23,
  rlogin => 513,
  ws => 80,
  wss => 443,
};

# ------ Parsing ------

sub _preprocess_input ($) {
  $_[0] .= ''; # Stringification

  if (utf8::is_utf8 ($_[0])) {
    ## Replace surrogate code points, noncharacters, and non-Unicode
    ## characters by U+FFFD REPLACEMENT CHARACTER, as they break
    ## Perl's regular expression character class handling in some
    ## versions of Perl.
    my $i = 0;
    pos ($_[0]) = $i;
    while (pos $_[0] < length $_[0]) {
      my $code = ord substr $_[0], pos ($_[0]), 1;
      if ((0xD800 <= $code and $code <= 0xDFFF) or
          (0xFDD0 <= $code and $code <= 0xFDEF) or
          ($code % 0x10000) == 0xFFFE or
          ($code % 0x10000) == 0xFFFF or
          $code > 0x10FFFF
      ) {
        substr ($_[0], pos ($_[0]), 1) = "\x{FFFD}";
      }
      pos ($_[0])++;
    }
  }

  $_[0] =~ s{[\x09\x0A\x0D]+}{}g;
  $_[0] =~ s{\A[\x0B\x0C\x20]+}{};
  $_[0] =~ s{[\x0B\x0C\x20]+\z}{};
} # _preprocess_input

sub _find_authority_path_query_fragment ($$) {
  my ($inputref => $result, %args) = @_;

  if ($$inputref =~ m{\A[/\\]{3}(?![/\\])}) {
    ## Slash characters
    $$inputref =~ s{\A[/\\]{2}}{};
    $result->{authority} = '';
  } elsif ($$inputref =~ m{\A[/\\]{2}}) {
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

sub _find_user_info_host_port ($$) {
  my ($inputref => $result) = @_;
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

sub parse_url ($) {
  my $input = $_[0];
  my $result = {};

  _preprocess_input $input;

  if ($input =~ s{^\\{2,}([^/\\\?\#]*)}{}) {
    $result->{host} = $1;
    $result->{scheme} = 'file';
    $result->{scheme_normalized} = 'file';
    $result->{is_hierarchical} = 1;

    if ($input =~ s{\#(.*)\z}{}s) {
      $result->{fragment} = $1;
    }
    if ($input =~ s{\?(.*)\z}{}s) {
      $result->{query} = $1;
    }

    $result->{path} = $input;
    return $result;
  }

  ## Find the scheme
  if ($input =~ s/\A([A-Za-z0-9.+-]+)://) {
    $result->{scheme} = $1;
    $result->{scheme_normalized} = $result->{scheme};
    $result->{scheme_normalized} =~ tr/A-Z/a-z/;
  } else {
    $result->{invalid} = 1;
  }

  if (defined $result->{scheme_normalized} and
      $result->{scheme_normalized} =~ /\A[a-z]\z/) {
    if ($input =~ s{\#(.*)\z}{}s) {
      $result->{fragment} = $1;
    }
    if ($input =~ s{\?(.*)\z}{}s) {
      $result->{query} = $1;
    }
    $result->{path} = '/' . $result->{scheme} . ':';
    $result->{path} .= '/' unless $input =~ m{\A[/\\]};
    $result->{path} .= $input;
    $result->{scheme} = 'file';
    $result->{scheme_normalized} = 'file';
    $result->{host} = '';
    $result->{is_hierarchical} = 1;
    return $result;
  }

  if (defined $result->{scheme_normalized} and
      $result->{scheme_normalized} eq 'file') {
    if ($input =~ s{\#(.*)\z}{}s) {
      $result->{fragment} = $1;
    }
    if ($input =~ s{\?(.*)\z}{}s) {
      $result->{query} = $1;
    }
    if ($input =~ s{\A[/\\]{3}(?![/\\])}{/}) {
      $result->{host} = '';
      $result->{path} = $input;
    } elsif ($input =~ s{\A[/\\]{2,}([^/\\]*)}{}) {
      $result->{host} = $1;
      $result->{path} = $input;
    } else {
      $result->{path} = $input;
    }
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

  if (not defined $result->{scheme_normalized} or
      (defined $result->{scheme_normalized} and
       not $IsNonHierarchicalScheme->{$result->{scheme_normalized}} and
       $input =~ m{^[/\\]})) {
    $result->{is_hierarchical} = 1;
    _find_authority_path_query_fragment \$input => $result;
    if (defined $result->{authority}) {
      _find_user_info_host_port \($result->{authority}) => $result;
      delete $result->{authority} unless $result->{invalid};
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
} # parse_url

# ------ Resolution ------

sub _remove_dot_segments ($) {
  ## Removing dot-segments (RFC 3986)
  local $_ = $_[0];
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

sub _resolve_relative_url ($$) {
  my ($parsed_spec, $parsed_base_url) = @_;

  unless ($parsed_base_url->{is_hierarchical}) {
    return {invalid => 1};
  }

  if (defined $parsed_spec->{host}) {
    ## Resolve as a scheme-relative URL

    my $url = {%$parsed_base_url};
    for (qw(user password host port query fragment)) {
      if (defined $parsed_spec->{$_}) {
        $url->{$_} = $parsed_spec->{$_};
      } else {
        delete $url->{$_};
      }
    }

    my $r_path = $parsed_spec->{path};
    if (defined $r_path) {
      if ($parsed_base_url->{scheme_normalized} eq 'file') {
        $r_path =~ s{%2[Ff]}{/}g;
        $r_path =~ s{%5[Cc]}{\\}g;
      }
      $r_path = _remove_dot_segments $r_path;
    }

    if ($parsed_base_url->{scheme_normalized} eq 'file') {
      if (defined $parsed_spec->{authority}) {
        delete $url->{user};
        delete $url->{password};
        delete $url->{host};
        delete $url->{port};
        $url->{host} = $parsed_spec->{authority};
      }
    }

    $url->{path} = $r_path;
    return $url;
  } elsif (defined $parsed_spec->{path} and
           $parsed_spec->{path} =~ m{^[/\\]}) {
    ## Resolve as an authority-relative URL
    my $r_path = $parsed_spec->{path};
    if ($parsed_base_url->{scheme_normalized} eq 'file') {
      $r_path =~ s{%2[Ff]}{/}g;
      $r_path =~ s{%5[Cc]}{\\}g;
    }
    $r_path = _remove_dot_segments $r_path;

    my $url = {%$parsed_base_url};
    for (qw(query fragment)) {
      if (defined $parsed_spec->{$_}) {
        $url->{$_} = $parsed_spec->{$_};
      } else {
        delete $url->{$_};
      }
    }
    $url->{path} = $r_path;
    return $url;
  } elsif (defined $parsed_spec->{query} and
           (not defined $parsed_spec->{path} or
            not length $parsed_spec->{path})) {
    ## Resolve as a query-relative URL
    my $url = {%$parsed_base_url};
    for (qw(query fragment)) {
      if (defined $parsed_spec->{$_}) {
        $url->{$_} = $parsed_spec->{$_};
      } else {
        delete $url->{$_};
      }
    }
    return $url;
  } elsif (defined $parsed_spec->{fragment} and 
           (not defined $parsed_spec->{path} or
            not length $parsed_spec->{path})) {
    ## Resolve as a fragment-relative URL
    my $url = {%$parsed_base_url};
    $url->{fragment} = $parsed_spec->{fragment};
    return $url;
  } else {
    ## Resolve as a path-relative URL
    my $url = {%$parsed_base_url};
    for (qw(query fragment)) {
      if (defined $parsed_spec->{$_}) {
        $url->{$_} = $parsed_spec->{$_};
      } else {
        delete $url->{$_};
      }
    }

    my $r_path = $parsed_spec->{path};
    my $b_path = defined $parsed_base_url->{path}
        ? $parsed_base_url->{path} : '';
    if ($url->{scheme_normalized} eq 'file') {
      $r_path =~ s{%2[Ff]}{/}g;
      $r_path =~ s{%5[Cc]}{\\}g;
      if ($r_path =~ m{^(?:[A-Za-z]|%[46][1-9A-Fa-f]|%[57][0-9Aa])(?:[:|]|%3[Aa]|%7[Cc])(?=\z|[/\\])}) {
        delete $url->{user};
        delete $url->{password};
        delete $url->{host};
        delete $url->{port};
        delete $url->{authority};
        $b_path = '';
      }
    }
    {
      ## Merge path (RFC 3986)
      if ($b_path eq '') {
        $r_path = '/'.$r_path;
      } else {
        $b_path =~ s{[^/\\]*\z}{};
        $r_path = $b_path . $r_path;
      }
    }
    $url->{path} = _remove_dot_segments $r_path;
    return $url;
  }
} # _resolve_relative_url

sub resolve_url ($$) {
  my ($spec, $parsed_base_url) = @_;

  if ($parsed_base_url->{invalid}) {
    return {invalid => 1};
  }

  _preprocess_input $spec;

  if ($spec eq '') {
    my $url = {%$parsed_base_url};
    delete $url->{fragment};
    return $url;
  }

  my $parsed_spec = parse_url $spec;
  if ($parsed_spec->{invalid}) { # No scheme
    return _resolve_relative_url $parsed_spec, $parsed_base_url;
  }

  if ($parsed_base_url->{is_hierarchical} and
      $parsed_spec->{scheme_normalized} eq
      $parsed_base_url->{scheme_normalized}) {
    if ((not defined $parsed_spec->{path} or
         not length $parsed_spec->{path}) and
        not defined $parsed_spec->{host} and
        not defined $parsed_spec->{query} and
        not defined $parsed_spec->{fragment}) {
      my $url = {%$parsed_base_url};
      delete $url->{fragment};
      return $url;
    }
    return _resolve_relative_url $parsed_spec, $parsed_base_url;
  }

  if ($parsed_spec->{is_hierarchical}) {
    if (defined $parsed_spec->{path}) {
      if ($parsed_spec->{scheme_normalized} eq 'file') {
        $parsed_spec->{path} =~ s{%2[Ff]}{/}g;
        $parsed_spec->{path} =~ s{%5[Cc]}{\\}g;
      }
      $parsed_spec->{path} = _remove_dot_segments $parsed_spec->{path};
    }
  }

  return $parsed_spec;
} # resolve_url

# ------ Canonicalization ------

sub canonicalize_parsed_url ($;$) {
  my ($parsed_url, $charset) = @_;

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

  HOSTPATH: {
    my $orig_host = $parsed_url->{host};
    my $orig_path = $parsed_url->{path};
    if ($parsed_url->{scheme_normalized} eq 'file') {
      if (defined $parsed_url->{host} and
          $parsed_url->{host} =~ m{\A(?:[A-Za-z]|%[46][1-9A-Fa-f]|%[57][0-9Aa])(?:[:|]|%3[Aa]|%7[Cc])\z}) {
        if (defined $parsed_url->{path}) {
          $parsed_url->{path} = '/' . $parsed_url->{host} .
              ($parsed_url->{path} =~ m{\A[/\\]} ? '' : '/') .
              $parsed_url->{path};
        } else {
          $parsed_url->{path} = '/' . $parsed_url->{host} . '/';
        }
        $parsed_url->{host} = '';
      } else {
        if (not defined $parsed_url->{host} or
            $parsed_url->{host} eq 'localhost') {
          $parsed_url->{host} = '';
        }
        if (defined $parsed_url->{path}) {
          if ($parsed_url->{host} eq '' and
              $parsed_url->{path} =~ s{\A[/\\]{3,}([^/\\]*)}{}) {
            $parsed_url->{host} = $1;
          }
          $parsed_url->{path} =~ s{\A[/\\]?([A-Za-z]|%[46][1-9A-Fa-f]|%[57][0-9Aa])(?:[:\|]|%3[Aa]|%7[Cc])(?:[/\\]|\z)}{
            my $drive = $1;
            $drive =~ s/%([0-9A-Fa-f]{2})/pack 'C', hex $1/ge;
            if ($parsed_url->{host} eq '%3F') {
              $parsed_url->{host} = '';
            }
            '/' . $drive . ':/';
          }e;
        }
      }
    }

    if (defined $parsed_url->{host}) {
      my $orig_host = $parsed_url->{host};
      $parsed_url->{host} = canonicalize_url_host
          ($parsed_url->{host},
           is_file => $parsed_url->{scheme_normalized} eq 'file');
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
        if (not defined $parsed_url->{path} or not length $parsed_url->{path}) {
          $parsed_url->{path} = '/';
        } elsif (not $parsed_url->{path} =~ m{^/}) {
          $parsed_url->{path} = '/' . $parsed_url->{path};
        }
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

    if ($parsed_url->{scheme_normalized} eq 'file') {
      if (not defined $orig_host or
          not defined $orig_path or
          $orig_host ne $parsed_url->{host} or
          $orig_path ne $parsed_url->{path}) {
        redo HOSTPATH;
      }
    }
  } # HOSTPATH

  if (defined $parsed_url->{path} and
      $parsed_url->{path} =~ m{^//} and
      not $IsNonHierarchicalScheme->{$parsed_url->{scheme_normalized}} and
      not (defined $parsed_url->{user} or
           defined $parsed_url->{password} or
           defined $parsed_url->{port} or
           (defined $parsed_url->{host} and length $parsed_url->{host}))) {
    $parsed_url->{path} = '/.' . $parsed_url->{path};
  }

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
} # canonicalize_parsed_url

# ------ Serialization ------

sub serialize_parsed_url ($) {
  my $parsed_url = $_[0];
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
} # serialize_parsed_url

# ------ Integrated ------

## The second argument, the base URL, should be specified; if
## specified, it must be a canonicalized URL.  Otherwise the
## canonicalization process might return an incorrect result.
sub url_to_canon_url ($;$$) {
  my $url;
  my $base_url = parse_url (defined $_[1] ? $_[1] : $_[0]);
  $url = resolve_url $_[0], $base_url;
  return serialize_parsed_url canonicalize_parsed_url $url, $_[2];
} # url_to_canon_url

1;
