package test::Web::DomainName::Punycode;
use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->subdir ('lib')->stringify;
use Test::More;

BEGIN {
  no warnings 'once';
  undef $Web::DomainName::Punycode::RequestedModule;
  require (file (__FILE__)->dir->file ('web-domainname-punycode-common.pl'));
}

use base qw(test::Web::DomainName::Punycode::common);

sub _module : Test(1) {
  if (eval q{ use Net::LibIDN; 1 }) {
    is $Web::DomainName::Punycode::UsedModule, 'Net::LibIDN';
  } else {
    is $Web::DomainName::Punycode::UsedModule, 'URI::_punycode';
  }
} # _module

__PACKAGE__->runtests;

=head1 LICENSE

Copyright 2011 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
