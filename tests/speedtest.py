from timeit import Timer
import ApeTag, create, delete, getfields, getrawtag, replace, update, walktree

def test(testname = 'getfields', numtimes = 1):
    t = Timer('walktree(test, False)', 'from walktree import walktree\nfrom %s import test' % testname)
    print '%s to run %s %i times' % (t.timeit(numtimes), testname, numtimes)

def testall():
    for testname in 'delete create replace update getfields getrawtag'.split():
        test(testname)

if __name__ == '__main__':
    testall()
