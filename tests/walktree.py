from ApeTag import TagError, ApeItem
from os import walk
from os.path import join as joinpath
fields = {'Title':'Test Create Title'.split(), 'Artist':['Test Create Artist'],
    'Track':'1024', 'Genre':['Blarg', 'Rock'], 'Album':'Test Album',
    'Test Ape Item':ApeItem('Ape Item', 'Ape Item Test'.split()),
    '1':ApeItem('External Ape Item', 'External ApeItem', 'external'),
    '2':ApeItem('Binary Ape Item', 'Binary\x01\x02\x03\xf3\x81', 'binary'),
    '3':ApeItem('Reserved Read Only Ape Item', '', 'reserved', True),}

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
