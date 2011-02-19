all: results/web-url-parser.txt

results/web-url-parser.txt: web-url-parser.t
	perl $< > $@

test:
	prove *.t
