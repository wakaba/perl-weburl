package test::Web::URL::Parser;
use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->subdir ('lib')->stringify;
use lib file (__FILE__)->dir->parent->subdir ('modules', 'testdataparser', 'lib')->stringify;
use base qw(Test::Class);
use Test::Differences;
use Test::HTCT::Parser;
use Web::URL::Parser;

my $data_d = file (__FILE__)->dir->subdir ('data');
my $parse_data_f = $data_d->file ('parsing.dat');
my $resolve_data_f = $data_d->file ('resolving.dat');
my $decomps_data_f = $data_d->file ('decomps.dat');

sub _parse : Tests {
  for_each_test $parse_data_f->stringify, {
    
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
    eq_or_diff
        +Web::URL::Parser->parse_absolute_url
            ($test->{data}->[0]),
        $result;
  }
} # _parse

sub _resolve : Tests {
  for_each_test $resolve_data_f->stringify, {
    data => {is_prefixed => 1},
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
    my $resolved_base_url = Web::URL::Parser->parse_absolute_url ($base_url);
    eq_or_diff
        +Web::URL::Parser->resolve_url
            ($test->{data}->[0], $resolved_base_url),
        $result,
        $test->{data}->[0] . ' - ' . $base_url;
  }
} # _resolve

sub _canon : Tests {
  for_each_test $decomps_data_f->stringify, {
    data => {is_prefixed => 1},
  }, sub ($) {
    my $test = shift;
    my $result = {};
    for (qw(
      scheme user password host port path query fragment invalid canon
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
    my $base_url = $test->{base} && length $test->{base}->[0]
             ? $test->{base}->[0]
             : defined $test->{base}->[1]->[0]
                 ? $test->{base}->[1]->[0] : '';
    my $resolved_base_url = Web::URL::Parser->parse_absolute_url ($base_url);
    my $resolved_url = Web::URL::Parser->resolve_url
        ($test->{data}->[0], $resolved_base_url);
    Web::URL::Parser->canonicalize_url ($resolved_url);
    my $url = Web::URL::Parser->serialize_url ($resolved_url);
    $resolved_url->{canon} = $url;
    eq_or_diff $resolved_url, $result,
        $test->{data}->[0] . ' - ' . $base_url;
  }
}

__PACKAGE__->runtests;

1;
