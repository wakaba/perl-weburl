package Web::DomainName::IDNSafe;
$VERSION = '1.0.1304581417';
$TIMESTAMP = 1304581417;

## This module is automatically generated.  Don't edit!

$TLDs =
$VAR1 = {
          'ac' => 1,
          'ar' => 1,
          'at' => 1,
          'biz' => 1,
          'br' => 1,
          'cat' => 1,
          'ch' => 1,
          'cl' => 1,
          'cn' => 1,
          'de' => 1,
          'dk' => 1,
          'es' => 1,
          'fi' => 1,
          'gr' => 1,
          'hu' => 1,
          'il' => 1,
          'info' => 1,
          'io' => 1,
          'ir' => 1,
          'is' => 1,
          'jp' => 1,
          'kr' => 1,
          'li' => 1,
          'lt' => 1,
          'lu' => 1,
          'museum' => 1,
          'no' => 1,
          'nu' => 1,
          'nz' => 1,
          'org' => 1,
          'pl' => 1,
          'pr' => 1,
          'se' => 1,
          'sh' => 1,
          'tel' => 1,
          'th' => 1,
          'tm' => 1,
          'tw' => 1,
          'ua' => 1,
          'vn' => 1,
          'xn--0zwm56d' => 1,
          'xn--11b5bs3a9aj6g' => 1,
          'xn--80akhbyknj4f' => 1,
          'xn--9t4b11yi5a' => 1,
          'xn--deba0ad' => 1,
          'xn--fiqs8s' => 1,
          'xn--fiqz9s' => 1,
          'xn--g6w251d' => 1,
          'xn--hgbk6aj7f53bba' => 1,
          'xn--hlcj6aya9esc7a' => 1,
          'xn--j6w193g' => 1,
          'xn--jxalpdlp' => 1,
          'xn--kgbechtv' => 1,
          'xn--kprw13d' => 1,
          'xn--kpry57d' => 1,
          'xn--mgba3a4f16a' => 1,
          'xn--mgba3a4fra' => 1,
          'xn--mgbaam7a8h' => 1,
          'xn--mgbayh7gpa' => 1,
          'xn--mgberp4a5d4a87g' => 1,
          'xn--mgberp4a5d4ar' => 1,
          'xn--mgbqly7c0a67fbc' => 1,
          'xn--mgbqly7cvafr' => 1,
          'xn--p1ai' => 1,
          'xn--wgbh1c' => 1,
          'xn--wgbl6a' => 1,
          'xn--zckzah' => 1
        };


=head1 NAME

Web::DomainName::IDNSafe - List of IDN-safe TLDs

=head1 SYNOPSIS

  use Web::DomainName::IDNSafe;
  ok $Web::DomainName::IDNSafe::TLDs->{jp};
  ng $Web::DomainName::IDNSafe::TLDs->{fr};

=head1 DESCRIPTION

The C<Web::DomainName::IDNSafe> module provides a list of IDN-safe
TLDs.  It contains TLDs listed in the I<IDN-enabled TLDs> (as of
2011-05-05) maintained by the Mozilla project.

=head1 VARIABLE

The module defines a variable: C<$Web::DomainName::IDNSafe::TLDs>.  It
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

The C<Web::DomainName::IDNSafe> module contains data extracted from
files maintained by the Mozilla project.

=head1 LICENSE

Copyright 2011 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
