from ApeTag import getrawid3, getrawape
from walktree import walktree

def test(filename, printoutput):
    apev2 = getrawape(filename)
    id3 = getrawid3(filename)
    if printoutput:
        print 'Raw Tag for', filename
        print 'ID3: %r' % id3
        print 'APEv2: %r' % apev2
        print ' '

if __name__ == '__main__':
    walktree(test)
