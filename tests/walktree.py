from ApeTag import TagError
from os import walk
from os.path import join as joinpath
fields = {'Title':'Test Create Title', 'Artist':'Test Create Artist',
    'Track':'0' }

def walktree(function, printoutput = True, tagdir = 'tagtest'):
    for root, dirs, files in walk(tagdir, topdown=False):
        for filename in files:
            if not (filename.endswith('.mp3') or filename.endswith('.mpc')):
                continue
            try:
                function(joinpath(root, filename), printoutput)
            except TagError, error:
                if printoutput:
                    print error, filename
