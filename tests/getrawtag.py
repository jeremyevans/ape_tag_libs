from ApeTag import getrawtags
from walktree import walktree

def test(filename, printoutput):
    ape, id3 = getrawtags(filename)
    if printoutput:
        print 'Raw Tag for %s\nID3: %r\nAPE: %r\n' % (filename, id3, ape)

if __name__ == '__main__':
    walktree(test)
