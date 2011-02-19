package Web::URL::Parser;
use strict;
use warnings;

our $IsHierarchicalScheme = {
  http => 1,
  https => 1,
  ftp => 1,
};

sub parse_url ($$) {
  my ($class, $input) = @_;
  my $result = {};

  $class->find_scheme (\$input => $result);
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
    $class->find_authority_path_query_fragment (\$input => $result);
    if (defined $result->{authority}) {
      $class->find_user_info_host_port (\($result->{authority}) => $result);
      delete $result->{authority};
    }
    if (defined $result->{user_info}) {
      ($result->{user}, $result->{password}) = split /:/, $result->{user_info}, 2;
      delete $result->{password} unless defined $result->{password};
      delete $result->{user_info};
    }
    return $result;
  }

  $result->{path} = $input;
  return $result;
} # parse_url

sub find_scheme ($$) {
  my ($class, $inputref => $result) = @_;
  
  ## Control characters
  $$inputref =~ s/\A[\x00-\x20]+//;
  $$inputref =~ s/[\x00-\x20]+\z//;

  if ($$inputref =~ s/^([^:]+)://) {
    $result->{scheme} = $1;
    $result->{scheme_normalized} = $result->{scheme};
    $result->{scheme_normalized} =~ tr/A-Z/a-z/;
  } else {
    $result->{invalid} = 1;
  }
} # find_scheme

sub find_authority_path_query_fragment ($$$) {
  my ($class, $inputref => $result) = @_;

  $$inputref =~ s{\A/+}{};

  ## Authority terminating characters
  if ($$inputref =~ s{\A([^/?\#;]*)(?=[/?\#;])}{}) {
    $result->{authority} = $1;
  } else {
    $result->{authority} = $$inputref;
    $result->{path} = ''; # Not in url-spec
    return;
  }

  if ($$inputref =~ s{\A\#(.*)}{}) {
    $result->{fragment} = $1;
  }

  if ($$inputref =~ s{\A\?([^\#]*)}{}) {
    $result->{query} = $1;
  }

  $result->{path} = $$inputref;
} # find_authority_path_query_fragment

sub find_user_info_host_port ($$$) {
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

  if ($input =~ /:([^:]*)\z/) {
    $result->{port} = $1;
  }

  $result->{host} = $input;
} # find_user_info_host_port

1;
