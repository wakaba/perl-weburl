all: \
  results/web-url-parser-core.txt \
  results/web-url-parser-bc.txt \
  results/web-url-parser-a.txt \
  results/web-url-parser-misc.txt

results/corebc: web-url-parser.t ../lib/Web/URL/Parser.pm data/*.dat
	-TEST_BROWSER=chrome TEST_METHOD=_canon_core perl $< &> results/web-url-parser-core-chrome.txt
	-TEST_BROWSER=gecko TEST_METHOD=_canon_core perl $< &> results/web-url-parser-core-gecko.txt
	-TEST_BROWSER=ie TEST_METHOD=_canon_core perl $< &> results/web-url-parser-core-ie.txt
	-TEST_BROWSER=chrome TEST_METHOD=_canon_bc perl $< &> results/web-url-parser-bc-chrome.txt
	-TEST_BROWSER=gecko TEST_METHOD=_canon_bc perl $< &> results/web-url-parser-bc-gecko.txt
	-TEST_BROWSER=ie TEST_METHOD=_canon_bc perl $< &> results/web-url-parser-bc-ie.txt

results/a: web-url-parser.t ../lib/Web/URL/Parser.pm data/*.dat
	-TEST_BROWSER=chrome TEST_METHOD=_canon_a perl $< &> results/web-url-parser-a-chrome.txt
	-TEST_BROWSER=gecko TEST_METHOD=_canon_a perl $< &> results/web-url-parser-a-gecko.txt
	-TEST_BROWSER=ie TEST_METHOD=_canon_a perl $< &> results/web-url-parser-a-ie.txt

results/web-url-parser-core.txt: web-url-parser.t \
  ../lib/Web/URL/Parser.pm \
  data/*.dat
	-TEST_BROWSER=this TEST_METHOD=_canon_core perl $< &> $@

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
