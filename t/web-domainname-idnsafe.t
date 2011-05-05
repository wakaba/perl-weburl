package test::Web::DomainName::IDNSafe;
use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->subdir ('lib')->stringify;
use base qw(Test::Class);
use Web::DomainName::IDNSafe;
use Test::More;

sub _versions : Test(2) {
  ok $Web::DomainName::IDNSafe::VERSION;
  ok $Web::DomainName::IDNSafe::TIMESTAMP;
} # _versions

sub _tlds : Test(2) {
  ok $Web::DomainName::IDNSafe::TLDs->{jp};
  ok !$Web::DomainName::IDNSafe::TLDs->{fr};
} # _tlds

__PACKAGE__->runtests;

1;

=head1 LICENSE

Copyright 2011 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
