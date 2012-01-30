package test::Web::DomainName::Punycode::webdomainnameuripunycode;
use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->subdir ('lib')->stringify;
use Test::More;

BEGIN {
  no warnings 'once';
  $Web::DomainName::Punycode::RequestedModule = 'Web::DomainName::URI::_punycode';
  require (file (__FILE__)->dir->file ('web-domainname-punycode-common.pl'));
}

use base qw(test::Web::DomainName::Punycode::common);

sub _module : Test(1) {
  is $Web::DomainName::Punycode::UsedModule,
      'Web::DomainName::URI::_punycode';
} # _module

__PACKAGE__->runtests;

=head1 LICENSE

Copyright 2012 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
