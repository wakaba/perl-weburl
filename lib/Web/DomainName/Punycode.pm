package Web::DomainName::Punycode;
use strict;
use warnings;
our $VERSION = '1.0';
use Encode;
use Exporter::Lite;

our @EXPORT = qw(encode_punycode decode_punycode);

our $RequestedModule ||= '';
our $UsedModule;

if ($RequestedModule eq 'Net::LibIDN' or
    (not $RequestedModule and eval q{ use Net::LibIDN; 1 })) {
  eval q{
    use Net::LibIDN;

    sub encode_punycode ($) {
      return undef unless defined $_[0];
      local $@;
      return eval { Encode::decode 'utf-8', Net::LibIDN::idn_punycode_encode (Encode::encode ('utf-8', $_[0]), 'utf-8') };
    } # encode_punycode
    
    sub decode_punycode ($) {
      return undef unless defined $_[0];
      local $@;
      return eval { Encode::decode 'utf-8', Net::LibIDN::idn_punycode_decode ($_[0], 'utf-8') };
    } # decode_punycode

    1;
  } or die $@;
  $UsedModule = 'Net::LibIDN';
} elsif ($RequestedModule eq 'URI::_punycode' or
         not $RequestedModule) {
  eval q{
    use URI::_punycode ();

    sub encode_punycode ($) {
      return undef if not defined $_[0];
      return '' unless length $_[0];
      unless ($_[0] =~ /[^\x00-\x7F]/) {
        return $_[0] . '-';
      }
      return URI::_punycode::encode_punycode ($_[0]);
    } # encode_punycode
    
    sub decode_punycode ($) {
      return undef if not defined $_[0] or $_[0] eq '-';
      local $@;
      return eval { URI::_punycode::decode_punycode ($_[0]) };
    } # decode_punycode

    1;
  } or die $@;
  $UsedModule = 'URI::_punycode';
} else {
  die "Module |$RequestedModule| is not supported";
}

=head1 LICENSE

Copyright 2011 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
