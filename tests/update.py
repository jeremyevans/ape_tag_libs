import apev2tag
import os
tagdir = 'tagtest'
for path, dirs, files in os.walk(tagdir, topdown=False):
    for fil in files:
        try:
            fname = os.path.normpath(os.path.join(path, fil))
            f = file(fname,'r+b')
            d = apev2tag.apev2tag(f,action="getfields")
            if 'Title' in d and 'Comment' in d:
                d["Title"], d["Artist"] = d["Artist"], d["Title"]
            apev2tag.apev2tag(f,d)
            d = apev2tag.id3tag(f,action="getfields")
            d["title"], d["artist"] = d["artist"], d["title"]
            apev2tag.id3tag(f,d)
            print 'Updated tag for %s' % fname
        except apev2tag.TagError, error:
            print error, error.getmoreinfo(), fname
