HARUSAME = harusame
POD2HTML = pod2html --css "http://suika.fam.cx/www/style/html/pod.css" \
  --htmlroot "../.."
SED = sed
PERL_VERSION = latest
PERL_PATH = $(abspath local/perlbrew/perls/perl-$(PERL_VERSION)/bin)
PROVE = prove

all: doc/README.ja.html doc/README.en.html \
  lib/Web/URL/Canonicalize.html \
  lib/Web/IPAddr/Canonicalize.html \
  lib/Web/DomainName/Canonicalize.html \
  lib/Web/DomainName/IDNEnabled.html \
  lib/Web/Encoding.html

doc/README.en.html: doc/README.html.src
	$(HARUSAME) --lang en < $< > $@

doc/README.ja.html: doc/README.html.src
	$(HARUSAME) --lang ja < $< > $@

%.html: %.pod
	$(POD2HTML) $< | $(SED) -e 's/<link rev="made" href="mailto:[^"]\+" \/>/<link rel=author href="#author">/' > $@

lib/Web/DomainName/IDNEnabled.html: %.html: %.pm
	$(POD2HTML) $< | $(SED) -e 's/<link rev="made" href="mailto:[^"]\+" \/>/<link rel=author href="#author">/' > $@

test: carton-install config/perl/libs.txt
	PATH=$(PERL_PATH):$(PATH) PERL5LIB=$(shell cat config/perl/libs.txt) \
	    $(PROVE) t/*.t

Makefile-setupenv: Makefile.setupenv
	$(MAKE) --makefile Makefile.setupenv setupenv-update \
            SETUPENV_MIN_REVISION=20120313

Makefile.setupenv:
	wget -O $@ https://raw.github.com/wakaba/perl-setupenv/master/Makefile.setupenv

remotedev-test remotedev-reset remotedev-reset-setupenv \
config/perl/libs.txt \
carton-install carton-update carton-install-module \
local-submodules \
local-perl perl-version perl-exec: %: Makefile-setupenv
	$(MAKE) --makefile Makefile.setupenv $@

## License: Public Domain.
