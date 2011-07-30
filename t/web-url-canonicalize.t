package test::Web::URL::Canonicalize;
use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->subdir ('lib')->stringify;
use lib file (__FILE__)->dir->parent->subdir ('modules', 'testdataparser', 'lib')->stringify;
use lib file (__FILE__)->dir->parent->subdir ('modules', 'charclass', 'lib')->stringify;
use base qw(Test::Class);
use Test::More;
use Test::Differences;
use Test::HTCT::Parser;
use Web::URL::Canonicalize qw(
  url_to_canon_url
  parse_url resolve_url canonicalize_parsed_url serialize_parsed_url
);

binmode STDOUT, ':encoding(utf8)';
binmode STDERR, ':encoding(utf8)';

my $data_d = file (__FILE__)->dir->subdir ('data');
my $parse_data_f = $data_d->file ('parsing.dat');
my $resolve_data_f = $data_d->file ('resolving.dat');
my @decomps_data_f = (map { $data_d->file ($_) } qw(

decomps-authority-domain.dat  decomps-file.dat        decomps-query.dat
decomps-authority-ipv4.dat    decomps-fragment.dat    decomps-relative.dat
decomps-authority-ipv6.dat    decomps-javascript.dat  decomps-scheme.dat
decomps-authority.dat         decomps-mailto.dat      decomps.dat
decomps-charsets.dat          decomps-path.dat
decomps-data.dat              decomps-port.dat
decomps-about.dat decomps-ftp.dat

));

my @decomps_data_bc_f = (map { $data_d->file ($_) } qw(

generated/decomps-authority-stringprep-b1-pe.dat
generated/decomps-authority-stringprep-b1.dat
generated/decomps-authority-stringprep-b2-pe.dat
generated/decomps-authority-stringprep-b2.dat

generated/decomps-authority-stringprep-c12-1.dat
generated/decomps-authority-stringprep-c12-pe-1.dat
generated/decomps-authority-stringprep-c22-1.dat
generated/decomps-authority-stringprep-c22-pe-1.dat
generated/decomps-authority-stringprep-c3-1.dat
generated/decomps-authority-stringprep-c3-pe-1.dat
generated/decomps-authority-stringprep-c4-1.dat
generated/decomps-authority-stringprep-c4-pe-1.dat
generated/decomps-authority-stringprep-c5-1.dat
generated/decomps-authority-stringprep-c5-pe-1.dat
generated/decomps-authority-stringprep-c6-1.dat
generated/decomps-authority-stringprep-c6-pe-1.dat
generated/decomps-authority-stringprep-c7-1.dat
generated/decomps-authority-stringprep-c7-pe-1.dat
generated/decomps-authority-stringprep-c8-1.dat
generated/decomps-authority-stringprep-c8-pe-1.dat
generated/decomps-authority-stringprep-c9-1.dat
generated/decomps-authority-stringprep-c9-pe-1.dat

));

my @decomps_data_a_f;
push @decomps_data_a_f,
    map { $data_d->file ($_) }
    qq(generated/decomps-authority-stringprep-a1-$_.dat) for 1..94;

sub _parse : Tests {
  for_each_test $parse_data_f->stringify, {
    data => {is_prefixed => 1},
    path => {is_prefixed => 1},
  }, sub ($) {
    my $test = shift;
    my $result = {};
    for (qw(
      scheme user password host port path query fragment invalid
    )) {
      next unless $test->{$_};
      if (length $test->{$_}->[0]) {
        $result->{$_} = $test->{$_}->[0];
      } else {
        $result->{$_} = $test->{$_}->[1]->[0];
        $result->{$_} = '' unless defined $result->{$_};
      }
    }
    if (defined $result->{scheme}) {
      $result->{scheme_normalized} = $result->{scheme};
      $result->{scheme_normalized} =~ tr/A-Z/a-z/;
    }
    my $actual = parse_url $test->{data}->[0];
    delete $actual->{is_hierarchical};
#line 1 "_parse"
    eq_or_diff $actual, $result;
  }
} # _parse

sub _resolve : Tests {
  for_each_test $resolve_data_f->stringify, {
    data => {is_prefixed => 1},
    path => {is_prefixed => 1},
  }, sub ($) {
    my $test = shift;
    my $result = {};
    for (qw(
      scheme user password host port path query fragment invalid
    )) {
      next unless $test->{$_};
      if (length $test->{$_}->[0]) {
        $result->{$_} = $test->{$_}->[0];
      } else {
        $result->{$_} = $test->{$_}->[1]->[0];
        $result->{$_} = '' unless defined $result->{$_};
      }
    }
    if (defined $result->{scheme}) {
      $result->{scheme_normalized} = $result->{scheme};
      $result->{scheme_normalized} =~ tr/A-Z/a-z/;
    }
    my $base_url = length $test->{base}->[0]
             ? $test->{base}->[0]
             : defined $test->{base}->[1]->[0]
                 ? $test->{base}->[1]->[0] : '';
    my $resolved_base_url = parse_url $base_url;
    my $actual = resolve_url $test->{data}->[0], $resolved_base_url;
    delete $actual->{is_hierarchical};
#line 1 "_resolve"
    eq_or_diff
        $actual, $result,
        $test->{data}->[0] . ' - ' . $base_url;
  }
} # _resolve

our $BROWSER = $ENV{TEST_BROWSER} || 'this';

sub __canon {
  for_each_test $_->stringify, {
    data => {is_prefixed => 1},
    path => {is_prefixed => 1},
  }, sub ($) {
    my $test = shift;
    my $result = {};
    for (qw(
      scheme user password host port path query fragment invalid canon charset
      chrome-invalid chrome-canon chrome-host
      gecko-invalid gecko-not-invalid gecko-canon gecko-host
      ie-invalid ie-canon ie-host
      chrome-not-invalid gecko-not-invalid ie-not-invalid
    )) {
      next unless $test->{$_};

      if ($test->{$_ . 8}) {
        if (length $test->{$_ . 8}->[0]) {
          $result->{$_ . 8} = $test->{$_ . 8}->[0];
        } else {
          $result->{$_ . 8} = $test->{$_ . 8}->[1]->[0];
          $result->{$_ . 8} = '' unless defined $result->{$_ . 8};
        }
        $result->{$_} = $result->{$_ . 8};
        delete $result->{$_ . 8};
      } else {
        if (length $test->{$_}->[0]) {
          $result->{$_} = $test->{$_}->[0];
        } else {
          $result->{$_} = $test->{$_}->[1]->[0];
          $result->{$_} = '' unless defined $result->{$_};
        }
      }
    }
    if ($BROWSER eq 'chrome') {
      for my $key (qw(invalid canon host)) {
        if (defined $result->{'chrome-' . $key}) {
          $result->{$key} = $result->{'chrome-' . $key};
        }
      }
      delete $result->{invalid} if $result->{'chrome-not-invalid'};
    } elsif ($BROWSER eq 'gecko') {
      for my $key (qw(invalid canon host)) {
        if (defined $result->{'gecko-' . $key}) {
          $result->{$key} = $result->{'gecko-' . $key};
        }
      }
      delete $result->{invalid} if $result->{'gecko-not-invalid'};
    } elsif ($BROWSER eq 'ie') {
      for my $key (qw(invalid canon host)) {
        if (defined $result->{'ie-' . $key}) {
          $result->{$key} = $result->{'ie-' . $key};
        }
      }
      delete $result->{invalid} if $result->{'ie-not-invalid'};
    }
    delete $result->{$_} for qw(chrome-invalid chrome-canon chrome-host);
    delete $result->{$_} for qw(gecko-invalid gecko-canon gecko-host);
    delete $result->{$_} for qw(ie-invalid ie-canon ie-host);
    delete $result->{$_} for qw(chrome-not-invalid);
    delete $result->{$_} for qw(gecko-not-invalid ie-not-invalid);
    if ($result->{invalid}) {
      delete $result->{$_} for qw(canon scheme host path query fragment);
    } else {
      delete $result->{invalid};
    }
    my $charset = delete $result->{charset};
    if (defined $result->{scheme}) {
      $result->{scheme_normalized} = $result->{scheme};
      $result->{scheme_normalized} =~ tr/A-Z/a-z/;
    }
    my $base_url = $test->{base} && length $test->{base}->[0]
             ? $test->{base}->[0]
             : defined $test->{base}->[1]->[0]
                 ? $test->{base}->[1]->[0] : '';
    $base_url = $test->{data}->[0] unless length $base_url;
    $result->{canon} = $test->{data}->[0]
        if not defined $result->{canon} and not $result->{invalid};
    my $resolved_base_url = parse_url $base_url;
    my $resolved_url = resolve_url $test->{data}->[0], $resolved_base_url;
    canonicalize_parsed_url $resolved_url, $charset;
    my $url = serialize_parsed_url $resolved_url;
    $resolved_url->{canon} = $url if defined $url;
    delete $resolved_url->{is_hierarchical};
    if (defined $resolved_url->{drive}) {
      $resolved_url->{path} = '/' . $resolved_url->{drive} . ':' . $resolved_url->{path};
      delete $resolved_url->{drive};
    }
#line 1 "_canon"
    eq_or_diff $resolved_url, $result,
        $test->{data}->[0] . ' - ' . $base_url . ($charset ? ' - ' . $charset : '');

    if ($BROWSER eq 'this' and defined $url) {
      my $resolved_url2 = resolve_url $url, $resolved_base_url;
      canonicalize_parsed_url $resolved_url2, $charset;
      my $url2 = serialize_parsed_url $resolved_url2;
#line 1 "_canon_idempotent"
      eq_or_diff $url2, $url,
          $test->{data}->[0] . ' - ' . $base_url . ($charset ? ' - ' . $charset : '') . ' idempotency';
    }
  } for @_;
}

sub _canon_core : Tests {
  __canon @decomps_data_f;
}

sub _canon_bc : Tests {
  __canon @decomps_data_bc_f;
}

sub _canon_a : Tests {
  __canon @decomps_data_a_f;
}

sub _url_to_canon_url : Test(23) {
  for (
    [undef, undef, undef, undef],
    [q<http://foo/bar>, undef, undef, q<http://foo/bar>],
    [q<baz>, q<http://foo/bar>, undef, q<http://foo/baz>],
    [q<hoge>, q<mailto:foo>, undef, undef],
    [qq<abc\x{4e90}>, q<http://foo/>, undef, q<http://foo/abc%E4%BA%90>],
    [qq<??>, q<http://foo/>, undef, q<http://foo/??>],
    [qq<?\x{5050}>, q<http://hoge>, undef, q<http://hoge/?%E5%81%90>],
    [qq<?\x{5050}>, q<http://hoge>, 'utf-8', q<http://hoge/?%E5%81%90>],
    [qq<?\x{5050}>, q<http://hoge>, 'iso-8859-1', q<http://hoge/??>],
    [qq<?\x{5050}>, q<http://hoge>, 'euc-jp', q<http://hoge/?%D0%F4>],
    [q<#>, undef, undef, undef],
    [q<foo>, q<bar>, undef, undef],
    [q<data:foo#bar>, undef, undef, q<data:foo#bar>],
    [q<../../baz>, q<http://hoge/a/b/c/d/e/../../>, undef, q<http://hoge/a/baz>],
    [q<../../baz>, q<http://hoge/a/b/c/d/e/../..>, undef, q<http://hoge/a/b/baz>],
    [q<../../baz>, q<http://hoge/a/b/c/>, undef, q<http://hoge/a/baz>],
    [q<../../../abc>, q<file://c:/windows/>, undef, q<file:///c:/abc>],
    [q<../../../abc>, q<file:///c:/windows/>, undef, q<file:///abc>],
    [q<http://foo/bar/./baz/..>, undef, undef, q<http://foo/bar/>],
    [q<file://c:/windows\\>, undef, undef, q<file:///c:/windows/>],
    [q<file://c:/windows\\>, q<file:///>, undef, q<file:///c:/windows/>],
    [q<http://hoge/a/b/c/d/e/../..>, undef, undef, q<http://hoge/a/b/c/>],
    [q<http://hoge/a/b/c/d/e/../../>, undef, undef, q<http://hoge/a/b/c/>],
  ) {
    my $canon = url_to_canon_url $_->[0], $_->[1], $_->[2];
    is $canon, $_->[3];
  }
} # _url_to_canon_url

__PACKAGE__->runtests;

=head1 LICENSE

Copyright 2011 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
