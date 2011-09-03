HARUSAME = harusame

all: README.ja.html README.en.html

README.en.html: README.html.src
	$(HARUSAME) --lang en < $< > $@

README.ja.html: README.html.src
	$(HARUSAME) --lang ja < $< > $@

## License: Public Domain.
