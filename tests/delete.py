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
            print 'Deleted tag for %s' % fname
        except apev2tag.TagError, error:
            print error, error.getmoreinfo(), fname