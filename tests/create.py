def test(printoutput = True):
    import apev2tag
    import os
    tagdir = 'tagtest'
    for path, dirs, files in os.walk(tagdir, topdown=False):
        for fil in files:
            try:
                fname = os.path.normpath(os.path.join(path, fil))
                f = file(fname,'r+b')
                d = {'TestTitle':'Test Create Title',
                     'TestArtist':'Test Create Artist'}
                apev2tag.apev2tag(f,d, action="create")
                d = {'track':0}
                apev2tag.id3tag(f,d,action="create")
                if printoutput:
                    print 'Created tag for %s' % fname
            except apev2tag.TagError, error:
                if printoutput:
                    print error, error.getmoreinfo(), fname

if __name__ == '__main__':
    test()
