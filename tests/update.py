from apev2tag import updatetags
from walktree import walktree, fields

def test(filename, printoutput):
    updatetags(filename, fields)
    if printoutput:
        print 'Updated tag for %s' % filename

if __name__ == '__main__':
    walktree(test)
