all: IDNEnabled.pm

IDNEnabled.pm: mozilla-pref.js generate-idnenabled.pl
	perl generate-idnenabled.pl mozilla-pref.js > $@

mozilla-pref.js:
	wget -O $@ http://mxr.mozilla.org/mozilla-central/source/modules/libpref/src/init/all.js\?raw=1

clean:
	rm -f mozilla-pref.js

clean-for-update: clean
	rm -f IDNEnabled.pm

## License: Public Domain.
