# Copyright (c) 2004-2005 Quasi Reality
#
# Permission is hereby granted, free of charge, to any person obtaining a copy 
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights 
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell 
# copies of the Software, and to permit persons to whom the Software is 
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in 
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE 
# SOFTWARE.

'''Module for manipulating APE and ID3v1 tags

Public Function Arguments
-------------------------
fil: filename string OR already opened file or file-like object that supports
    flush, seek, read, truncate, tell, and write
fields: dictionary like object of tag fields that has an iteritems method
    which is an iterator of key, value tuples. 
    APE:
        key: must be a regular string with length 2-255 inclusive, containing
            only characters in the range 0x20-0x7f
        value: must be a string or a list or tuple of them, or an ApeItem
    ID3:
        key: must be title, artist, album, year, comment, genre, or track*
            (i.e. track or tracknumber)
        value: should be a string except for track* and genre
            track*: integer or sting representation of one
            genre: integer or string (if string, must be a case insensitive
                match for one of the strings in id3genres to be recognized)

Public Functions Return
-----------------------
0 on success of delete functions
string on success of getraw functions
dict on success of create, update, replace, or getfields
    key is the field name as a string
    (APE) value is an ApeItem, which is a list subclass with the field values
        stored in the list as unicode strings, and the following special attrs:
        key: same as key of dict
        readonly: whether the field was marked read only
        type: type of tag field (utf8, binary, external, or reserved)
    (ID3) value is a regular string
    
Public Functions Raise
----------------------
IOError on problem accessing file (make sure read/write access is allowed
    for the file if you are trying to modify the tag)
(APE functions only) UnicodeError on problems converting regular strings to
    UTF-8 (See note, or just use unicode strings)
TagError on other errors
    
Notes
-----
When using functions that modify both tags, the accepted arguments and return
    value are the same for the APE funtion.
Raising errors other than IOError, UnicodeError, or TagError is considered a
    bug unless the program using this library is specifically designed to raise
    other errors.
Only APEv2 tags are supported. APEv1 tags without a header are not supported.
Only writes ID3v1.1 tags.  Assumes all tags are ID3v1.1.  The only exception to
    this is when it detects an ID3v1.0 tag, it will return 0 as the track
    number in getfields.
The APE tag is appended to the end of the file.  If the file already has an 
    ID3v1 tag at the end, it is recognized and the APE tag is placed directly 
    before it.  
Default maximum size for the APE tag is 8192 bytes, as recommended by the APE
    spec.  This can be changed by modifying the _maxapesize variable.  
Read-only flags can be read, created, and modified (they are not respected).
If you are storing non 7-bit ASCII data in a tag, you should pass in unicode
    strings instead of regular strings, or pass in an already created ApeItem.
Inserting binary data into tags is "strongly unrecommended."
Official APEv2 specification is here:
    http://www.personal.uni-jena.de/~pfk/mpp/sv8/apetag.html
Cached version located here:
    http://www.ikol.dk/~jan/musepack/klemm/www.personal.uni-jena.de/~pfk/mpp/sv8/apetag.html
'''

from struct import pack as _pack, unpack as _unpack
from os.path import isfile as _isfile

# Variable definitions

__version__ = '0.9'
_maxapesize = 8192
_commands = 'create update replace delete getfields getrawtag'.split()
_tagmustexistcommands = 'update getfields getrawtag'.split()
_filelikeattrs = 'flush read seek tell truncate write'.split()
_badapeitemkeys = 'id3 tag oggs mp+'.split()
_badapeitemkeychars = ''.join([chr(x) for x in range(32) + range(128,256)])
_apeitemtypes = 'utf8 binary external reserved'.split()
_apeheaderflags = "\x00\x00\x00\xA0"
_apefooterflags = "\x00\x00\x00\x80"
_apepreamble = "APETAGEX\xD0\x07\x00\x00"
_apetypeflags = {"utf8":"\x00\x00\x00\x00", "binary":"\x00\x00\x00\x02",
                 "external":"\x00\x00\x00\x04" }
_id3tagformat = 'TAG%(title)s%(artist)s%(album)s%(year)s%(comment)s' \
                '\x00%(track)s%(genre)s'
_id3fields = {'title': (3,33), 'artist': (33,63), 'album': (63,93), 
              'year': (93,97), 'comment': (97,125) } # (start, end)
_id3genresstr = '''Blues, Classic Rock, Country, Dance, Disco, Funk, Grunge, 
    Hip-Hop, Jazz, Metal, New Age, Oldies, Other, Pop, R & B, Rap, Reggae, 
    Rock, Techno, Industrial, Alternative, Ska, Death Metal, Prank, Soundtrack,
    Euro-Techno, Ambient, Trip-Hop, Vocal, Jazz + Funk, Fusion, Trance, 
    Classical, Instrumental, Acid, House, Game, Sound Clip, Gospel, Noise, 
    Alternative Rock, Bass, Soul, Punk, Space, Meditative, Instrumental Pop, 
    Instrumental Rock, Ethnic, Gothic, Darkwave, Techno-Industrial, Electronic,
    Pop-Fol, Eurodance, Dream, Southern Rock, Comedy, Cult, Gangsta, Top 40,
    Christian Rap, Pop/Funk, Jungle, Native US, Cabaret, New Wave, Psychadelic,
    Rave, Showtunes, Trailer, Lo-Fi, Tribal, Acid Punk, Acid Jazz, Polka, 
    Retro, Musical, Rock & Roll, Hard Rock, Folk, Folk-Rock, National Folk, 
    Swing, Fast Fusion, Bebop, Latin, Revival, Celtic, Bluegrass, Avantgarde, 
    Gothic Rock, Progressive Rock, Psychedelic Rock, Symphonic Rock, Slow Rock,
    Big Band, Chorus, Easy Listening, Acoustic, Humour, Speech, Chanson, Opera,
    Chamber Music, Sonata, Symphony, Booty Bass, Primus, Porn Groove, Satire, 
    Slow Jam, Club, Tango, Samba, Folklore, Ballad, Power Ballad, Rhytmic Soul,
    Freestyle, Duet, Punk Rock, Drum Solo, Acapella, Euro-House, Dance Hall, 
    Goa, Drum & Bass, Club-House, Hardcore, Terror, Indie, BritPop, Negerpunk, 
    Polsk Punk, Beat, Christian Gangsta Rap, Heavy Metal, Black Metal, 
    Crossover, Contemporary Christian, Christian Rock, Merengue, Salsa, 
    Trash Meta, Anime, Jpop, Synthpop'''
_apeitemkeys = '''Title, Artist, Album, Year, Comment, Genre, Track, 
    Debut Album, Subtitle, Publisher, Conductor, Composer, Copyright, 
    Publicationright, File, EAN/UPC, ISBN, Catalog, LC, Record Date, 
    Record Location, Media, Index, Related, ISRC, Abstract, Language, 
    Bibliography, Introplay, Dummy'''
id3genres = [x.strip() for x in _id3genresstr.split(',')]
_id3genresdict = {}
for i, x in enumerate(id3genres):
    _id3genresdict[x.lower()] = i
apeitemkeys = [x.strip() for x in _apeitemkeys.split(',')]
del x
del i

# Classes

class TagError(StandardError):
    '''Raised when there is an error during a tagging operation'''
    pass

class ApeItem(list):
    '''Contains individual APE tag items'''
    def __init__(self, key = None, values = []):
        list.__init__(self)
        if key is None:
            return
        if not self.validkey(key):
            raise TagError, 'Invalid item key for ape tag item: %r' % key
        self.key = key
        self.readonly = False
        self.type = 'utf8'
        if isinstance(values, basestring):
            values = [values]
        self.extend([unicode(value) for value in values])
    
    def maketag(self):
        '''Return on disk representation of tag item
        
        self.parsetag(self.maketag(), 0) should result in no change to self
        '''
        values = '\x00'.join([value.encode('utf8') for value in self])
        size = _pack("<i",len(values))
        flags = chr(int(self.readonly) + 2 * (_apeitemtypes.index(self.type)))
        return '%s\x00\x00\x00%s%s\x00%s' % (size, flags, self.key, values)
    
    def parsetag(self, data, curpos):
        '''Parse next tag from data string, starting at current position'''
        del self[:]
        itemlength = _unpack("<i",data[curpos:curpos+4])[0]
        if itemlength < 0:
            raise TagError, 'Corrupt tag, invalid item length at position ' \
                            '%i: %i bytes' % (curpos, itemlength)
        if data[curpos+4:curpos+7] != '\x00\x00\x00':
            raise TagError, 'Corrupt tag, invalid item flags, bits 8-31 ' \
                            'nonzero at position %i' % curpos
        type, readonly = divmod(ord(data[curpos+7]), 2)
        if type > 3:
            raise TagError, 'Corrupt tag, invalid item flags, bits 3-7 ' \
                            'nonzero at position %i' % curpos
        self.type = _apeitemtypes[type]
        self.readonly = bool(readonly)
        curpos += 8
        keyend = data.find("\x00", curpos)
        if keyend < curpos:
            raise TagError, 'Corrupt tag, unterminated item key at position ' \
                            '%i' % curpos
        itemkey = data[curpos:keyend]
        if not self.validkey(itemkey):
            raise TagError, 'Corrupt tag, invalid item key at position ' \
                            '%i: %r' % (curpos, itemkey)
        self.key = itemkey
        curpos = keyend + itemlength + 1
        itemvalue = data[keyend+1:curpos]
        if self.type == 'binary':
            self.append(itemvalue)
        else:
            self.extend(itemvalue.decode('utf8').split('\x00'))
        return curpos
    
    def validkey(self, key):
        '''Check key to make sure it is a valid ApeItem key'''
        return isinstance(key, str) and 2 <= len(key) <= 255 \
            and not _stringoverlaps(key, _badapeitemkeychars) \
            and key.lower() not in _badapeitemkeys

# Private functions

def _ape(fil, fields, action, removefields = []):
    '''Get or Modify APE tag for file'''
    if not hasattr(removefields, '__iter__') \
       or not callable(removefields.__iter__):
        raise TagError, "removefields is not an iterable"
    
    apesize = 0
    filesize, id3data = _getfilesizeandid3(fil)    
    data = fil.read(32)

    if _apepreamble != data[:12] or _apefooterflags != data[20:24]:
        if action in _tagmustexistcommands:
            raise TagError, "Nonexistant or corrupt tag, can't %s" % action
        elif action == "delete":
            return 0
        data = ''
    else:
        # file has a valid APE footer
        apesize = _unpack("<i",data[12:16])[0] + 32
        if apesize > _maxapesize:
            raise TagError, 'Existing tag is too large: %i bytes' % apesize
        if apesize + len(id3data) > filesize:
            raise TagError, 'Existing tag says it is larger than the file: ' \
                            '%i bytes' % apesize
        fil.seek(-1 * apesize, 1)
        data = fil.read(apesize)
        if _apepreamble != data[:12] or _apeheaderflags != data[20:24]:
            return TagError, 'Nonexistent or corrupt tag, missing tag header'
        fil.seek(-1 * apesize, 1)
        if action == "delete":
            fil.truncate(fil.tell())
            fil.seek(0,2)
            fil.write(id3data)
            return 0
            
    if action == "getrawtag":
        return data
    if action == "getfields":
        return _restoredictcase(_parseapetag(data))
    
    if not data or action == "replace":
        apeitems = {}
    else:
        apeitems = _parseapetag(data)
        _removeapeitems(apeitems, removefields)

    # Add requested items to tag
    for key, value in fields.iteritems():
        if isinstance(value, ApeItem):
            apeitems[value.key.lower()] = value
        else:
            apeitems[key.lower()] = ApeItem(key, value)
     
    newtag = _makeapev2tag(apeitems)

    if len(newtag) > _maxapesize:
        raise TagError, 'New tag is too large: %i bytes' % len(data)
    # truncate does not seem to work properly in all cases without 
    # explicitly given the position
    fil.truncate(fil.tell())
    # Must seek to end of file as truncate appears to modify the file's
    # current position in certain cases
    fil.seek(0,2)
    fil.write(newtag + id3data)
    fil.flush()
    return _restoredictcase(apeitems)

def _apefieldstoid3fields(fields):
    '''Convert APE tag fields to ID3 tag fields '''
    id3fields = {}
    for key, value in fields.iteritems():
        if not isinstance(key, str):
            raise TagError, 'Invalid tag field: %r' % key
        key = key.lower()
        if key.startswith('track'):
            try:
                id3fields['track'] = int(value)
            except ValueError:
                pass
        elif key == 'genre':
            if not isinstance(value, basestring):
                raise TagError, 'Invalid tag value for genre: %r' % value
            id3fields[key] = value
        elif key in _id3fields:
            if isinstance(value, (list, tuple)):
                try:
                    value = ', '.join(value)
                except ValueError:
                    raise TagError, 'Invalid tag value for %s field: %r' \
                                    % (key, value)
            if isinstance(value, unicode):
                value = value.encode('utf8')
            id3fields[key] = value
    return id3fields

_apelengthreduce = lambda i1, i2: i1 + len(i2)

def _checkargs(fil, fields, action):
    '''Check that arguments are valid, convert them, or raise an error'''
    if not (isinstance(action,str) and action.lower() in _commands):
        raise TagError, "%r is not a valid action" % action
    action = action.lower()
    fil = _getfileobj(fil, action)
    for attr in _filelikeattrs:
        if not hasattr(fil, attr) or not callable(getattr(fil, attr)):
            raise TagError, "fil does not support method %r" % attr
    if not hasattr(fields, 'items') or not callable(fields.items):
        raise TagError, "fields does not support method 'items'"
    return fil, fields, action

def _getfileobj(fil, action):
    '''Return a file object if given a filename, otherwise return file'''
    if isinstance(fil, basestring) and _isfile(fil):
        if action in ('getfields', 'getrawtag'):
            mode = 'rb'
        else:
            mode = 'r+b'
        return file(fil, mode)
    return fil

def _getfilesizeandid3(fil):
    '''Return file size and ID3 tag if it exists, and seek to start of APE footer'''
    fil.seek(0, 2)
    filesize = fil.tell()
    fil.seek(-1 * 128, 1)
    data = fil.read(128)
    if data[:3] != 'TAG':
        fil.seek(-1 * 32, 1)
        data = ''
    else:
        fil.seek(-1 * 160, 1)
    return filesize, data

def _id3(fil, fields, action):
    '''Get or Modify ID3 tag for file'''
    origfil = fil
    fil, fields, action = _checkargs(fil, fields, action)
    
    fil.seek(-128, 2)
    data = fil.read(128)
    
    # See if tag exists
    if data[0:3] != 'TAG':
        if action == "delete":
            return 0
        if action in _tagmustexistcommands: 
            raise TagError, "Nonexistant or corrupt tag, can't %s" % action
        data = ''
    else:      
        if action == "delete":
            fil.truncate(fil.tell() - 128)
            return 0
    
    if action == "getrawtag":
        return data 
    if action == "getfields":
        return _parseid3tag(data)
    
    if not data or action == "replace":
        tagfields = {}
    else:
        tagfields = _parseid3tag(data)
        
    for field, value in fields.iteritems():
       if isinstance(field, str):
           tagfields[field.lower()] = value
    
    newtag = _makeid3tag(tagfields)

    if data:
        fil.truncate(fil.tell() - 128)
    fil.seek(0, 2)
    fil.write(newtag)
    fil.flush()
    if isinstance(origfil, basestring):
        # filename given as an argument, close file object
        fil.close()
    return _parseid3tag(newtag)

def _makeapev2tag(apeitems):
    '''Construct an APE tag string from a dict of ApeItems'''
    apeentries = [item.maketag() for item in apeitems.itervalues()]
    apeentries.sort(_sortapeitems)
    apesize = _pack("<i",reduce(_apelengthreduce, apeentries, 32))
    numitems = _pack("<i",len(apeentries))
    headerfooter = _apepreamble + apesize + numitems
    apeentries.insert(0, headerfooter + _apeheaderflags + "\x00" * 8)
    apeentries.append(headerfooter + _apefooterflags + "\x00" * 8)
    return "".join(apeentries)

def _makeid3tag(fields):
    '''Make an ID3 tag from the given dictionary'''
    newfields = {}
    for field, value in fields.iteritems():
        if not isinstance(field, str):
            continue
        newfields[field.lower()] = fields[field]
        field = field.lower()
        if field.startswith('track'):
            try:
                newfields['track'] = chr(int(value))
            except ValueError:
                raise TagError, '%r is an invalid value for %r' % (value, field)
        elif field == 'genre':
            if not isinstance(value, int):
                if not isinstance(value, basestring):
                    raise TagError, "%r is an invalid value for 'genre'" % value
                value = value.lower()
                if value in _id3genresdict:
                    value = _id3genresdict[value]
                else:
                    value = 255
            elif not (0 <= value < 256):
                value = 255
            newfields[field] = chr(value)
    for field, (startpos, endpos) in _id3fields.items():
        maxlength = endpos - startpos
        if field in newfields:
            fieldlength = len(newfields[field])
            if fieldlength > maxlength:
                newfields[field] = newfields[field][:maxlength]
            elif fieldlength < maxlength:
                newfields[field] = newfields[field] + \
                '\x00' * (maxlength - fieldlength)
            # If fieldlength = maxlength, no changes need to be made
        else:
            newfields[field] = '\x00' * maxlength
    if 'track' not in newfields:
        newfields['track'] = '\x00'
    if 'genre' not in newfields:
        newfields['genre'] = '\xff'
    return _id3tagformat % newfields

def _parseapetag(data):
    '''Parse an APEv2 tag and return a dictionary of tag fields'''
    apeitems = {}
    numitems = _unpack("<i",data[16:20])[0]
    # 32 is size of footer, 11 is minimum item length item
    if numitems > (len(data) - 32)/11:
        raise TagError, 'Corrupt tag, specifies more items that is possible ' \
                        'given space remaining: %i items' % numitems
    curpos = 32
    tagitemend = len(data) - 32
    for x in range(numitems):
        if curpos >= tagitemend:
            raise TagError, 'Corrupt tag, end of tag reached with more items' \
                            'specified'
        item = ApeItem()
        curpos = item.parsetag(data, curpos)
        itemkey = item.key.lower()
        if itemkey in apeitems:
            raise TagError, 'Corrupt tag, duplicate item key: %r' % itemkey
        apeitems[itemkey] = item
    if tagitemend - curpos:
        raise TagError, 'Corrupt tag, parsing complete but not at end ' \
            'of input: %i bytes remaining' % (len(data) - curpos)
    return apeitems

def _parseid3tag(data):
    '''Parse an ID3 tag and return a dictionary of tag fields'''
    fields = {}
    for key,(start,end) in _id3fields.items():
        fields[key] = data[start:end].rstrip("\x00")
    if data[125] == "\x00":
        # ID3v1.1 tags have tracks
        fields["track"] = str(ord(data[126]))
    else:
        fields["track"] = '0'
    genreid = ord(data[127])
    if genreid < len(id3genres):
        fields["genre"] = id3genres[genreid]
    else:
        fields["genre"] = ''
    return fields

def _removeapeitems(apeitems, removefields):
    '''Remove items from the APE tag'''
    for itemkey in removefields:
        if not isinstance(itemkey, str):
            raise TagError, "Invalid entry in removeitems: %r" % itemkey
        itemkey = itemkey.lower()
        if itemkey in apeitems.keys():
            del apeitems[itemkey]
            
def _restoredictcase(apeitems):
    '''Restore the case of the dictionary keys for the ApeItems'''
    fixeditems = {}
    for value in apeitems.itervalues():
        fixeditems[value.key] = value
    return fixeditems

def _stringoverlaps(string1, string2):
    '''Check if any character in either string is in the other string'''
    if len(string1) > len(string2):
        string1, string2 = string2, string1
    for char in string1:
        if char in string2:
            return True
    return False

_sortapeitems = lambda a, b: cmp(len(a), len(b))

def _tag(function, fil, fields = {}, action = "update", *args):
    '''Preform tagging operation, check args, open/close file if necessary'''
    origfil = fil
    fil, fields, action = _checkargs(fil, fields, action)
    try:
        return function(fil, fields, action, *args)
    finally:
        if isinstance(origfil, basestring):
            # filename given as an argument, close file object
            fil.close()

# Public functions

def createape(fil, fields = {}):
    '''Create/update APE tag in fil with the information in fields'''
    return _tag(_ape, fil, fields, 'create')
    
def createid3(fil, fields = {}):
    '''Create/update ID3v1 tag in fil with the information in fields'''
    return _tag(_id3, fil, fields, 'create')
    
def createtags(fil, fields = {}):
    '''Create/update both APE and ID3v1 tags on fil with the information in fields'''
    createid3(fil, _apefieldstoid3fields(fields))
    return createape(fil, fields)

def deleteape(fil):
    '''Delete APE tag from fil if it exists'''
    return _tag(_ape, fil, action='delete')
    
def deleteid3(fil):
    '''Delete ID3v1 tag from fil if it exists'''
    return _tag(_id3, fil, action='delete')
    
def deletetags(fil):
    '''Delete APE and ID3v1 tags from fil if either exists'''
    deleteid3(fil)
    return deleteape(fil)

def getapefields(fil):
    '''Return fields from APE tag in fil'''
    return _tag(_ape, fil, action='getfields')
    
def getid3fields(fil):
    '''Return fields from ID3v1 tag in fil (including blank fields)'''
    return _tag(_id3, fil, action='getfields')

def getrawape(fil):
    '''Return raw APE tag from fil'''
    return _tag(_ape, fil, action='getrawtag')
    
def getrawid3(fil):
    '''Return raw ID3v1 tag from fil'''
    return _tag(_id3, fil, action='getrawtag')

def replaceape(fil, fields = {}):
    '''Replace/create APE tag in fil with the information in fields'''
    return _tag(_ape, fil, fields, action='replace')
    
def replaceid3(fil, fields = {}):
    '''Replace/create ID3v1 tag in fil with the information in fields'''
    return _tag(_id3, fil, fields, 'replace')
    
def replacetags(fil, fields = {}):
    '''Replace/create both APE and ID3v1 tags on fil with the information in fields'''
    replaceid3(fil, _apefieldstoid3fields(fields))
    return replaceape(fil, fields)

def updateape(fil, fields = {}, removefields = []):
    '''Update APE tag in fil with the information in fields
    
    removefields: iterable yielding strings of tag fields to remove
    '''
    return _tag(_ape, fil, fields, 'update', removefields)
    
def updateid3(fil, fields = {}):
    '''Update ID3v1 tag in fil with the information in fields'''
    return _tag(_id3, fil, fields, 'update')
    
def updatetags(fil, fields = {}, removefields = []):
    '''Update both APE and ID3v1 tags on fil with the information in fields
    
    removefields: iterable yielding strings of APE tag fields to remove
    '''
    updateid3(fil, _apefieldstoid3fields(fields))
    return updateape(fil, fields, removefields)
