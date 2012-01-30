package test::Web::DomainName::Punycode::common;
use strict;
use warnings;
use base qw(Test::Class);
use Test::More;
use Web::DomainName::Punycode;
use Encode;

my $SupportLong = $Web::DomainName::Punycode::UsedModule =~ /URI::_punycode/;

sub _encode_punycode : Test(19) {
  for (
    [undef, undef],
    ['', ''],
    ['-', '--'],
    ['123', '123-'],
    ['abcdef' => 'abcdef-'],
    ['AbcDef' => 'AbcDef-'],
    ["\x{1000}ab" => 'ab-ezj'],
    ["x\x{4000}\x{1000}" => 'x-1qg7797a'],
    ['a-b-', 'a-b--'],
    ['-abc', '-abc-'],
    ["\x{1000}", 'nid'],
    [(encode 'utf-8', "\x{1000}"), 'aa30a'],
    ['xn--abcc', 'xn--abcc-'],
    ["\x{61}\x{1F62}\x{03B9}\x{62}" => 'ab-09b734z'],
    ["\x{61}\x{1F62}\x{62}" => 'ab-ymt'],
    ['a' x 1000, ('a' x 1000) . '-'],
    ["\x{1000}" . ('a' x 1000), ('a' x 1000) . '-2o653a'],
    ['a' x 10000, $SupportLong ? ('a' x 10000) . '-' : undef],
    ["\x{1000}" . ('a' x 10000), $SupportLong ? ('a' x 10000) . '-xc9053a' : undef],
  ) {
    my $out = encode_punycode $_->[0];
    is $out, $_->[1];
  }
} # _encode_punycode

sub _decode_punycode : Test(23) {
  for (
    [undef, undef],
    ['', ''],
    ['1234', undef],
    ['nid', "\x{1000}"],
    ['aa30a', "\x{E1}\x{80}\x{80}"],
    ['xn--nid', "\x{0460}xn-"],
    ['abcdef-', 'abcdef'],
    ['-', undef], # Spec is unclear for this case
    ['--', '-'],
    ['---', '--'],
    ['-> $1.00 <--', '-> $1.00 <-'],
    ["\x{1000}", undef],
    ["\x{1000}-", undef],
    ["-\x{1000}", undef],
    ["-abc\x{1000}xyz", undef],
    ['--abcde', "\x{82}\x{80}\x{81}-\x{80}\x{82}"],
    ['ab-09b734z' => "\x{61}\x{1F62}\x{03B9}\x{62}"],
    ['ab-ymt' => "\x{61}\x{1F62}\x{62}"],
    [('a' x 1000) . '-', ('a' x 1000)],
    [('a' x 1000) . '-2o653a', "\x{1000}" . ('a' x 1000)],
    ["\x{1000}" . ('a' x 1000), undef],
    [('a' x 10000) . '-', $SupportLong ? ('a' x 10000) : undef],
    ["\x{1000}" . ('a' x 10000), undef],
  ) {
    my $out = decode_punycode $_->[0];
    is $out, $_->[1];
  }
} # _decode_punycode

=head1 LICENSE

Copyright 2011-2012 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
