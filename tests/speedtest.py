def test(testname = 'getfields', numtimes = 1):
    from timeit import Timer
    t = Timer('%s.test(False)' % testname, 'import %s' % testname)
    print '%s to run %s %i times' % (t.timeit(numtimes), testname, numtimes)

if __name__ == '__main__':
    test()
