all: apetag.beam

.SUFFIXES: .erl .beam

.erl.beam:
	erlc $<

clean:
	rm -f *.beam erl_crash.dump test.apetag

regress: apetag.beam test_apetag.beam test_apetag_files.beam
	erl -s c c apetag -run test_apetag -run init stop -noinput
	erl -s c c apetag -run test_apetag_files -run init stop -noinput

