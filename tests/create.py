from apev2tag import createtags
from walktree import walktree, fields

def test(filename, printoutput):
    createtags(filename, fields)
    if printoutput:
        print 'Created tag for %s' % filename

if __name__ == '__main__':
    walktree(test)
