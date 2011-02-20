all: results/web-url-parser.txt

results/web-url-parser.txt: web-url-parser.t ../lib/Web/URL/Parser.pm
	-perl $< &> $@

test:
	prove *.t
