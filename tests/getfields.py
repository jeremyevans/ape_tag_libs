from apev2tag import getid3fields, getapev2fields
from walktree import walktree

def test(filename, printoutput):
    apev2 = getapev2fields(filename)
    id3 = getid3fields(filename)
    if printoutput:
        print 'Tag Fields for', filename
        print 'ID3: %s' % id3
        print 'APEv2: %s' % apev2
        print ' '

if __name__ == '__main__':
    walktree(test)
