package test::Web::DomainName::IDNEnabled;
use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->subdir ('lib')->stringify;
use base qw(Test::Class);
use Web::DomainName::IDNEnabled;
use Test::More;

sub _versions : Test(2) {
  ok $Web::DomainName::IDNEnabled::VERSION;
  ok $Web::DomainName::IDNEnabled::TIMESTAMP;
} # _versions

sub _tlds : Test(2) {
  ok $Web::DomainName::IDNEnabled::TLDs->{jp};
  ok !$Web::DomainName::IDNEnabled::TLDs->{fr};
} # _tlds

__PACKAGE__->runtests;

1;

=head1 LICENSE

Copyright 2011 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
