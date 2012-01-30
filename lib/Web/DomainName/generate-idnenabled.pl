#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;

my $tlds = {};

while (<>) {
  if (m{pref\("network.IDN.whitelist.([0-9a-zA-Z-]+)", true\)}) {
    $tlds->{lc $1} = 1;
  }
}

print q{package Web::DomainName::IDNEnabled;
$VERSION = '1.0.}.time.q{';
$TIMESTAMP = }.time.q{;

## This module is automatically generated.  Don't edit!

$TLDs =
};

print Dumper $tlds;

print q{

=head1 NAME

Web::DomainName::IDNEnabled - List of IDN-enabled TLDs

=head1 SYNOPSIS

  use Web::DomainName::IDNEnabled;
  ok $Web::DomainName::IDNEnabled::TLDs->{jp};
  ng $Web::DomainName::IDNEnabled::TLDs->{fr};

=head1 DESCRIPTION

The C<Web::DomainName::IDNEnabled> module provides a list of IDN-enabled
TLDs.  It contains TLDs listed in the I<IDN-enabled TLDs> (as of
}.(sprintf '%04d-%02d-%02d', [gmtime]->[5] + 1900, [gmtime]->[4] + 1,
[gmtime]->[3]).q{) maintained by the Mozilla project.

=head1 VARIABLE

The module defines a variable: C<$Web::DomainName::IDNEnabled::TLDs>.  It
is a hash reference.  Keys of the hash are IDN-enabled TLDs in
lowercase and is encoded in Punycode if necessary.  Values for
existing keys are always true.

=head1 SEE ALSO

IDN-enabled TLDs
<http://www.mozilla.org/projects/security/tld-idn-policy-list.html>.

<http://mxr.mozilla.org/mozilla-central/source/modules/libpref/src/init/all.js>.
(Search for "network.IDN.whitelist.".)

=head1 AUTHOR

Wakaba <w@suika.fam.cx>.

The C<Web::DomainName::IDNEnabled> module contains data extracted from
files maintained by the Mozilla project.

=head1 LICENSE

Copyright 2011 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
};
