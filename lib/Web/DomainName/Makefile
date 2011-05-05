all: IDNSafe.pm

IDNSafe.pm: mozilla-pref.js generate-idnsafe.pl
	perl generate-idnsafe.pl mozilla-pref.js > $@

mozilla-pref.js:
	wget -O $@ http://mxr.mozilla.org/mozilla-central/source/modules/libpref/src/init/all.js\?raw=1

clean:
	rm -f mozilla-pref.js

## License: Public Domain.
