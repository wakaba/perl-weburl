all: \
  results/web-url-parser-core.txt \
  results/web-url-parser-bc.txt \
  results/web-url-parser-a.txt \
  results/web-url-parser-misc.txt

results/web-url-parser-core.txt: web-url-parser.t \
  ../lib/Web/URL/Parser.pm \
  data/*.dat
	-TEST_METHOD=_canon_core perl $< &> $@

results/web-url-parser-bc.txt: web-url-parser.t \
  ../lib/Web/URL/Parser.pm \
  data/*.dat
	-TEST_METHOD=_canon_bc perl $< &> $@

results/web-url-parser-a.txt: web-url-parser.t \
  ../lib/Web/URL/Parser.pm \
  data/*.dat
	-TEST_METHOD=_canon_a perl $< &> $@

results/web-url-parser-misc.txt: web-url-parser.t \
  ../lib/Web/URL/Parser.pm \
  data/*.dat
	-TEST_METHOD="_parse|_resolve" perl $< &> $@

test:
	prove *.t
