from ApeTag import TagError, ApeItem
from os import walk
from os.path import join as joinpath
fields = {'Title':'Test Create Title'.split(), 'Artist':['Test Create Artist'],
    'Track':'1024', 'Genre':['Blarg', 'Rock'], 'Album':'Test Album',
    'Test Ape Item':ApeItem('Ape Item', 'Ape Item Test'.split())}

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
