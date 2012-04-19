all: IDNEnabled.pm

IDNEnabled.pm: mozilla-pref.js generate-idnenabled.pl
	perl generate-idnenabled.pl mozilla-pref.js > $@

mozilla-pref.js: always
	wget -O $@.new http://mxr.mozilla.org/mozilla-central/source/modules/libpref/src/init/all.js\?raw=1
	diff $@ $@.new || cp $@.new $@

clean:

clean-for-update: clean
	rm -f IDNEnabled.pm

always:

## License: Public Domain.
