from ApeTag import getid3fields, getapefields
from walktree import walktree

def test(filename, printoutput):
    apev2 = getapefields(filename)
    id3 = getid3fields(filename)
    if printoutput:
        print 'Tag Fields for', filename
        print 'ID3: %s' % id3
        print 'APEv2: %s' % apev2
        print ' '

if __name__ == '__main__':
    walktree(test)
