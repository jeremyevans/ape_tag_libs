from apev2tag import getrawid3, getrawapev2
from walktree import walktree

def test(filename, printoutput):
    apev2 = getrawapev2(filename)
    id3 = getrawid3(filename)
    if printoutput:
        print 'Raw Tag for', filename
        print 'ID3:', id3
        print 'APEv2:', apev2
        print ' '

if __name__ == '__main__':
    walktree(test)
