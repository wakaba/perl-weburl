package test::Web::URL::Parser;
use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->subdir ('lib')->stringify;
use lib file (__FILE__)->dir->parent->subdir ('modules', 'testdataparser', 'lib')->stringify;
use lib file (__FILE__)->dir->parent->subdir ('modules', 'charclass', 'lib')->stringify;
use base qw(Test::Class);
use Test::Differences;
use Test::HTCT::Parser;
use Web::URL::Parser;

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
#line 1 "_parse"
    eq_or_diff
        +Web::URL::Parser->parse_absolute_url
            ($test->{data}->[0]),
        $result;
  }
} # _parse

sub _resolve : Tests {
  for_each_test $resolve_data_f->stringify, {
    data => {is_prefixed => 1},
    path