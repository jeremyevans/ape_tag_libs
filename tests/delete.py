def test(printoutput = True):
    import apev2tag
    import os
    tagdir = 'tagtest'
    for path, dirs, files in os.walk(tagdir, topdown=False):
        for fil in files:
            try:
                fname = os.path.normpath(os.path.join(path, fil))
                f = file(fname,'r+b')
                apev2tag.apev2tag(f,action="delete")
                apev2tag.id3tag(f,action="delete")
                if printoutput:
                    print 'Deleted tag for %s' % fname
            except apev2tag.TagError, error:
                if printoutput:
                    print error, error.getmoreinfo(), fname

if __name__ == '__main__':
    test()
    