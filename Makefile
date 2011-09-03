HARUSAME = harusame
POD2HTML = pod2html --css "http://suika.fam.cx/www/style/html/pod.css" \
  --htmlroot "../../../"
SED = sed

all: doc/README.ja.html doc/README.en.html \
  lib/Web/URL/Canonicalize.html \
  lib/Web/IPAddr/Canonicalize.html \
  lib/Web/DomainName/Canonicalize.html \
  lib/Web/DomainName/IDNEnabled.html

doc/README.en.html: doc/README.html.src
	$(HARUSAME) --lang en < $< > $@

doc/README.ja.html: doc/README.html.src
	$(HARUSAME) --lang ja < $< > $@

%.html: %.pod
	$(POD2HTML) $< | $(SED) -e 's/<link rev="made" href="mailto:[^"]\+" \/>/<link rel=author href="#author">/' > $@

lib/Web/DomainName/IDNEnabled.html: %.html: %.pm
	$(POD2HTML) $< | $(SED) -e 's/<link rev="made" href="mailto:[^"]\+" \/>/<link rel=author href="#author">/' > $@

## License: Public Domain.
