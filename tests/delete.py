from ApeTag import deletetags
from walktree import walktree

def test(filename, printoutput):
    deletetags(filename)
    if printoutput:
        print 'Deleted tag for %s' % filename

if __name__ == '__main__':
    walktree(test)
