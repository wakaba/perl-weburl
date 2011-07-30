package Web::DomainName::Punycode;
use strict;
use warnings;
our $VERSION = '1.0';
use Net::LibIDN;
use Encode;
use Exporter::Lite;

our @EXPORT = qw(encode_punycode decode_punycode);

sub encode_punycode ($) {
  local $@;
  return eval { Encode::decode 'utf-8', Net::LibIDN::idn_punycode_encode $_[0], 'utf-8' };
} # encode_punycode

sub decode_punycode ($) {
  local $@;
  return eval { Encode::decode 'utf-8', Net::LibIDN::idn_punycode_decode $_[0], 'utf-8' };
} # decode_punycode

=head1 LICENSE

Copyright 2011 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
