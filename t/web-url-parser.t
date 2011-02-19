package test::Web::URL::Parser;
use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->subdir ('lib')->stringify;
use base qw(Test::Class);
use Test::Differences;
use Web::URL::Parser;

our $Data = [
  [q<> => {invalid => 1}],
  [q<http://> => {scheme => 'http', host => '', path => ''}],
  [q<HTTP://> => {scheme => 'HTTP', host => '', path => ''}],
  [q<http://www.example.com> => {scheme => 'http', host => 'www.example.com', path => ''}],
  [q<http://www.example.com/> => {scheme => 'http', host => 'www.example.com', path => '/'}],
  [q<HTTP://example.com/> => {scheme => 'HTTP', host => 'example.com', path => '/'}],
]; # $Data

sub _parse : Test(4) {
  for (@$Data) {
    if (defined $_->[1]->{scheme}) {
      $_->[1]->{scheme_normalized} = $_->[1]->{scheme};
      $_->[1]->{scheme_normalized} =~ tr/A-Z/a-z/;
    }
    eq_or_diff +Web::URL::Parser->parse_url ($_->[0]), $_->[1];
  }
} # _parse

__PACKAGE__->runtests;

1;
