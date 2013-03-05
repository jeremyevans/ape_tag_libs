all: apetag.beam

apetag.beam:
	erlc apetag.erl

clean:
	rm -f *.beam erl_crash.dump test.apetag

regress: apetag.beam test_apetag.beam
	erl -s c c apetag -run test_apetag -run init stop -noinput

test_apetag.beam:
	erlc test_apetag.erl
	
