all:
	erlc apetag.erl

clean:
	-rm *.beam erl_crash.dump test.apetag

regress: test_apetag.beam
	erl -s c c apetag -run test_apetag -run init stop -noinput

test_apetag.beam:
	erlc test_apetag.erl
	