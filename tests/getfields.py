def test(printoutput = True):
    import apev2tag
    import os
    tagdir = 'tagtest'
    for path, dirs, files in os.walk(tagdir, topdown=False):
        for fil in files:
            try:
                fname = os.path.normpath(os.path.join(path, fil))
                f = file(fname,'rb')
                apev2 = apev2tag.apev2tag(f,action="getfields")
                id3 = apev2tag.id3tag(f,action="getfields")
                if printoutput:
                    print 'Tag Fields for %s' % fname
                    print 'ID3: %s' % id3
                    print 'APEv2: %s' % apev2
                    print ' '
            except apev2tag.TagError, error:
                if printoutput:
                    print error, error.getmoreinfo(), fname

if __name__ == '__main__':
    test()
