HARUSAME = harusame

all: doc/README.ja.html doc/README.en.html

doc/README.en.html: doc/README.html.src
	$(HARUSAME) --lang en < $< > $@

doc/README.ja.html: doc/README.html.src
	$(HARUSAME) --lang ja < $< > $@

## License: Public Domain.
