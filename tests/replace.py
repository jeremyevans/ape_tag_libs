from apev2tag import replacetags
from walktree import walktree, fields

def test(filename, printoutput):
    replacetags(filename, fields)
    if printoutput:
        print 'Replaced tag for %s' % filename

if __name__ == '__main__':
    walktree(test)
