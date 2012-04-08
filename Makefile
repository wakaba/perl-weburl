HARUSAME = harusame
POD2HTML = pod2html --css "http://suika.fam.cx/www/style/html/pod.css" \
  --htmlroot "../.."
SED = sed

PERL = perl
PERL_VERSION = latest
PERL_PATH = $(abspath local/perlbrew/perls/perl-$(PERL_VERSION)/bin)
PROVE = prove

all: config/perl/libs.txt \
  doc/README.ja.html doc/README.en.html \
  lib/Web/URL/Canonicalize.html \
  lib/Web/IPAddr/Canonicalize.html \
  lib/Web/DomainName/Canonicalize.html \
  lib/Web/DomainName/IDNEnabled.html \
  lib/Web/Encoding.html

## ------ Deps ------

Makefile-setupenv: Makefile.setupenv
	make --makefile Makefile.setupenv setupenv-update \
            SETUPENV_MIN_REVISION=20120329

Makefile.setupenv:
	wget -O $@ https://raw.github.com/wakaba/perl-setupenv/master/Makefile.setupenv

config/perl/libs.txt local-perl generatepm \
perl-exec perl-version carton-install carton-update \
: %: Makefile-setupenv
	make --makefile Makefile.setupenv pmbundler-repo-update $@ \
            PMBUNDLER_REPO_URL=$(PMBUNDLER_REPO_URL)

## ------ Documents ------

doc/README.en.html: doc/README.html.src
	$(HARUSAME) --lang en < $< > $@

doc/README.ja.html: doc/README.html.src
	$(HARUSAME) --lang ja < $< > $@

%.html: %.pod
	$(POD2HTML) $< | $(SED) -e 's/<link rev="made" href="mailto:[^"]\+" \/>/<link rel=author href="#author">/' > $@

lib/Web/DomainName/IDNEnabled.html: %.html: %.pm
	$(POD2HTML) $< | $(SED) -e 's/<link rev="made" href="mailto:[^"]\+" \/>/<link rel=author href="#author">/' > $@

## ------ Tests ------

PERL_ENV = PATH=$(PERL_PATH):$(PATH) PERL5LIB=$(shell cat config/perl/libs.txt)

test: safetest

test-deps: carton-install config/perl/libs.txt

safetest: test-deps safetest-main

safetest-main:
	cd t && $(PERL_ENV) $(MAKE) test

## ------ Distribution ------

GENERATEPM = local/generatepm/bin/generate-pm-package
GENERATEPM_ = $(GENERATEPM) --generate-json

dist: generatepm
	mkdir -p dist
	$(GENERATEPM_) config/dist/web-domainname-canonicalize.pi dist
	$(GENERATEPM_) config/dist/web-domainname-idnenabled.pi dist
	$(GENERATEPM_) config/dist/web-domainname-punycode.pi dist
	$(GENERATEPM_) config/dist/web-encoding.pi dist
	$(GENERATEPM_) config/dist/web-ipaddr-canonicalize.pi dist
	$(GENERATEPM_) config/dist/web-url-canonicalize.pi dist

dist-wakaba-packages: local/wakaba-packages dist
	cp dist/*.json local/wakaba-packages/data/perl/
	cp dist/*.tar.gz local/wakaba-packages/perl/
	cd local/wakaba-packages && $(MAKE) all

local/wakaba-packages: always
	git clone "git@github.com:wakaba/packages.git" $@ || (cd $@ && git pull)
	cd $@ && git submodule update --init

always:

## License: Public Domain.
