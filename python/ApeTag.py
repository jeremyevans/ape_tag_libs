#!/usr/bin/env python
# Copyright (c) 2004-2007 Jeremy Evans
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
            only ASCII characters in the range 0x20-0x7f
        value: must be a string or a list or tuple of them, or an ApeItem
    ID3:
        key: must be title, artist, album, year, comment, genre, or track*
            (i.e. track or tracknumber)
        value: should be a string except for track* and genre
            track*: integer or sting representation of one
            genre: integer or string (if string, must be a case insensitive
                match for one of the strings in id3genres to be recognized)
removefields (updateape and updatetags): iterable of fields to remove from the
    APE tag (and set to blank in the ID3 tag).

Public Functions Return
-----------------------
0 on success of delete functions
bool on success of has functions
string on success of getraw functions
dict on success of create, update, replace, modify, or getfields
    key is the field name as a string
    (APE) value is an ApeItem, which is a list subclass with the field values
        stored in the list as strings, and the following special attributes:
        key: same as key of dict
        readonly: whether the field was marked read only
        type: type of tag field (utf8, binary, external, or reserved),
              utf8 type means values in list are unicode strings
    (ID3) value is a regular string
    
Public Functions Raise
----------------------
IOError on problem accessing file (make sure read/write access is allowed
    for the file if you are trying to modify the tag)
(APE functions only) UnicodeError on problems converting regular strings to
    UTF-8 (See note, or just use unicode strings)
TagError on other errors

Callback Functions
------------------
The modify* functions take callback functions and extra keyword arguments.
The callback functions are called with the tag dictionary and any extra keyword
arguments given in the call to modify*.  This dictionary should be modified and
must be returned by the callback functions.  There isn't much error checking
done after this stage, so incorrectly written callback functions may result in
corrupt tags or exceptions being raised elsewhere in the module.  The 
modifytags function takes two separate callback functions, one for the APE tag
and one for the ID3 tag.  See the _update*tagcallback functions for examples of
how callback functions should be written.
    
Notes
-----
When using functions that modify both tags, the accepted arguments and return
    value are the same for the APE funtion.
Raising errors other than IOError, UnicodeError, or TagError is considered a
    bug unless fields contains a non-basestring (or a list containing a
    non-basestring).
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
This library doesn't check to make sure that tag items marked as external are
    in the proper format.
APEv2 specification is here:
    http://wiki.hydrogenaudio.org/index.php?title=APEv2_specification
'''

from os.path import isfile as _isfile
from struct import pack as _pack, unpack as _unpack

# Variable definitions

__version__ = '1.2'
_maxapesize = 8192
_commands = '''create update replace delete getfields getrawtag getnewrawtag
  hastag'''.split()
_tagmustexistcommands = 'update getfields getrawtag'.split()
_stringallowedcommands = 'getrawtag getnewrawtag getfields hastag'.split()
_filelikeattrs = 'flush read seek tell truncate write'.split()
_badapeitemkeys = 'id3 tag oggs mp+'.split()
_badapeitemkeychars = ''.join([chr(x) for x in range(32) + range(128,256)])
_apeitemtypes = 'utf8 binary external reserved'.split()
_apeheaderflags = "\x00\x00\xA0"
_apefooterflags = "\x00\x00\x80"
_apepreamble = "APETAGEX\xD0\x07\x00\x00"
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
    def __init__(self, key = None, values = [], type = 'utf8', readonly = False):
        list.__init__(self)
        if key is None:
            return
        if not self.validkey(key):
            raise TagError, 'Invalid item key for ape tag item: %r' % key
        if type not in _apeitemtypes:
            raise TagError, 'Invalid item type for ape tag item: %r' % type
        self.key = key
        self.readonly = bool(readonly)
        self.type = type
        if isinstance(values, basestring):
            values = [values]
        if type == 'utf8' or type == 'external':
            values = [unicode(value) for value in values]
        self.extend(values)
    
    def maketag(self):
        '''Return on disk representation of tag item
        
        self.parsetag(self.maketag(), 0) should result in no change to self
        '''
        if self.type == 'utf8' or self.type == 'external':
            values = '\x00'.join([value.encode('utf8') for value in self])
        else:
            values = '\x00'.join(self)
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
        if self.type == 'utf8' or self.type == 'external':
            self.extend(itemvalue.decode('utf8').split('\x00'))
        else:
            self.append(itemvalue)
        return curpos
    
    def validkey(self, key):
        '''Check key to make sure it is a valid ApeItem key'''
        return isinstance(key, str) and 2 <= len(key) <= 255 \
            and not _stringoverlaps(key, _badapeitemkeychars) \
            and key.lower() not in _badapeitemkeys

# Private functions

def _ape(fil, action, callback = None, callbackkwargs = {}, updateid3 = False):
    '''Get or Modify APE tag for file'''            
    apesize = 0
    tagstart = None
    filesize, id3data, data = _getfilesizeandid3andapefooter(fil)

    if _apepreamble != data[:12]:
        if action in _tagmustexistcommands:
            raise TagError, "Nonexistant or corrupt tag, can't %s" % action
        elif action == "delete":
            return 0
        data = ''
        tagstart = filesize - len(id3data)
    elif _apefooterflags != data[21:24] or \
        (data[20] != '\0' and data[20] != '\1'):
            raise TagError, "Bad tag footer flags"
    else:
        # file has a valid APE footer
        apesize = _unpack("<i",data[12:16])[0] + 32
        if apesize > _maxapesize:
            raise TagError, 'Existing tag is too large: %i bytes' % apesize
        if apesize + len(id3data) > filesize:
            raise TagError, 'Existing tag says it is larger than the file: ' \
                            '%i bytes' % apesize
        fil.seek(-apesize - len(id3data), 2)
        tagstart = fil.tell()
        data = fil.read(apesize)
        if _apepreamble != data[:12] or _apeheaderflags != data[21:24] or \
           (data[20] != '\0' and data[20] != '\1'):
            raise TagError, 'Nonexistent or corrupt tag, missing tag header'
        if apesize != _unpack("<i",data[12:16])[0] + 32:
            raise TagError, 'Corrupt tag, header and footer sizes do not match'
        if action == "delete":
            fil.seek(tagstart)
            if not updateid3:
                fil.write(id3data)
            fil.truncate()
            fil.flush()
            return 0
            
    if action == "hastag":
        if updateid3:
            return bool(data) and bool(id3data)
        return bool(data)
    if action == "getrawtag":
        if updateid3:
            return data, id3data
        return data
    if action == "getfields":
        if updateid3:
            return _restoredictcase(_parseapetag(data)), \
              _id3(id3data, "getfields")
        return _restoredictcase(_parseapetag(data))
    if not data or action == "replace":
        apeitems = {}
    else:
        apeitems = _parseapetag(data)
    
    if callable(callback):
        apeitems = callback(apeitems, **callbackkwargs)
            
    newtag = _makeapev2tag(apeitems)
    
    if action == "getnewrawtag":
        if updateid3:
            return newtag, _id3(id3data, "getnewrawtag")
        return newtag
    
    if len(newtag) > _maxapesize:
        raise TagError, 'New tag is too large: %i bytes' % len(data)
    
    if updateid3:
        if action == 'replace':
            id3data = ''
        elif action != 'create' and not id3data:
            raise TagError, "Nonexistant or corrupt tag, can't %s" % action
        if callable(updateid3):
            id3data = _id3(id3data, "getnewrawtag", updateid3, callbackkwargs)
        else:
            callbackkwargs['convertfromape'] = True
            id3data = _id3(id3data, "getnewrawtag", _updateid3tagcallback, 
              callbackkwargs)
    
    fil.seek(tagstart)
    fil.write(newtag + id3data)
    fil.truncate()
    fil.flush()
    return _restoredictcase(apeitems)

def _apefieldstoid3fields(fields):
    '''Convert APE tag fields to ID3 tag fields '''
    id3fields = {}
    for key, value in fields.iteritems():
        key = key.lower()
        if isinstance(value, (list, tuple)):
            if not value:
                value = ''
            else:
                value = ', '.join(value)
        if key.startswith('track'):
            try:
                value = int(value)
            except ValueError:
                value = 0
            if (0 <= value < 256):
                id3fields['track'] = value
            else:
                id3fields['track'] = 0
        elif key == 'genre':
            if isinstance(value, basestring) and value.lower() in _id3genresdict:
                id3fields[key] = value
            else:
                id3fields[key] = ''
        elif key == 'date':
            try:
                id3fields['year'] = str(int(value))
            except ValueError:
                pass
        elif key in _id3fields:
            if isinstance(value, unicode):
                value = value.encode('utf8')
            id3fields[key] = value
    return id3fields

_apelengthreduce = lambda i1, i2: i1 + len(i2)

def _checkargs(fil, action):
    '''Check that arguments are valid, convert them, or raise an error'''
    if not (isinstance(action,str) and action.lower() in _commands):
        raise TagError, "%r is not a valid action" % action
    action = action.lower()
    fil = _getfileobj(fil, action)
    for attr in _filelikeattrs:
        if not hasattr(fil, attr) or not callable(getattr(fil, attr)):
            raise TagError, "fil does not support method %r" % attr
    return fil, action
    
def _checkfields(fields):
    '''Check that the fields quacks like a dict'''
    if not hasattr(fields, 'items') or not callable(fields.items):
        raise TagError, "fields does not support method 'items'"
    
def _checkremovefields(removefields):
    '''Check that removefields is iterable'''
    if not hasattr(removefields, '__iter__') \
       or not callable(removefields.__iter__):
        raise TagError, "removefields is not an iterable"

def _getfileobj(fil, action):
    '''Return a file object if given a filename, otherwise return file'''
    if isinstance(fil, basestring) and _isfile(fil):
        if action in _stringallowedcommands:
            mode = 'rb'
        else:
            mode = 'r+b'
        return file(fil, mode)
    return fil

def _getfilesizeandid3andapefooter(fil):
    '''Return file size and ID3 tag if it exists, and seek to start of APE footer'''
    fil.seek(0, 2)
    filesize = fil.tell()
    id3 = ''
    apefooter = ''
    if filesize < 64: #No possible APE or ID3 tag
        apefooter = ''
    elif filesize < 128: #No possible ID3 tag
        fil.seek(filesize - 32)
        apefooter = fil.read(32)
    else:
        fil.seek(filesize - 128)
        data = fil.read(128)
        if data[:3] != 'TAG':
            apefooter = data[96:]
        else:
            id3 = data
            if filesize >= 160:
                fil.seek(filesize - 160)
                apefooter = fil.read(32)
    return filesize, id3, apefooter

def _id3(fil, action, callback = None, callbackkwargs={}):
    '''Get or Modify ID3 tag for file'''
    if isinstance(fil, str):
        if action not in _stringallowedcommands:
            raise TagError, "String not allowed for %s action" % action
        data = fil
    else:
        fil.seek(0, 2)
        tagstart = fil.tell() 
        if tagstart < 128:
            data = ''
        else:
            fil.seek(-128,2)
            data = fil.read(128)
        if data[0:3] != 'TAG':
            # Tag doesn't exist
            if action == "delete":
                return 0
            if action in _tagmustexistcommands: 
                raise TagError, "Nonexistant or corrupt tag, can't %s" % action
            data = ''
        else:      
            tagstart -= 128
            if action == "delete":
                fil.truncate(tagstart)
                return 0

    if action == "hastag":
        return bool(data) 
    if action == "getrawtag":
        return data 
    if action == "getfields":
        return _parseid3tag(data)
    
    if not data or action == "replace":
        tagfields = {}
    else:
        tagfields = _parseid3tag(data)
        
    if callable(callback):
        tagfields = callback(tagfields, **callbackkwargs)
    
    newtag = _makeid3tag(tagfields)

    if action == "getnewrawtag":
        return newtag

    fil.seek(tagstart)
    fil.write(newtag)
    fil.flush()
    return _parseid3tag(newtag)

def _makeapev2tag(apeitems):
    '''Construct an APE tag string from a dict of ApeItems'''
    apeentries = [item.maketag() for item in apeitems.itervalues()]
    apeentries.sort(_sortapeitems)
    apesize = _pack("<i",reduce(_apelengthreduce, apeentries, 32))
    numitems = _pack("<i",len(apeentries))
    headerfooter = _apepreamble + apesize + numitems
    apeentries.insert(0, headerfooter + '\0' + _apeheaderflags + "\x00" * 8)
    apeentries.append(headerfooter + '\0' + _apefooterflags + "\x00" * 8)
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
                if not value:
                    value = 0
                newfields['track'] = chr(int(value))
            except ValueError:
                raise TagError, '%r is an invalid value for %r' % (value, field)
        elif field == 'genre':
            if not isinstance(value, int):
                if not isinstance(value, basestring):
                    raise TagError, "%r is an invalid value for 'genre'" % value
                value = value.lower()
                if not value:
                    value = 255
                elif value in _id3genresdict:
                    value = _id3genresdict[value]
                else:
                    raise TagError, "%r is an invalid value for 'genre'" % value
            elif not (0 <= value < 256):
                value = 255
            newfields[field] = chr(value)
    for field, (startpos, endpos) in _id3fields.iteritems():
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
    if numitems != _unpack("<i",data[-16:-12])[0]:
        raise TagError, 'Corrupt tag, mismatched header and footer item count' 
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
    for key,(start,end) in _id3fields.iteritems():
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

def _printapeitems(apeitems):
    '''Pretty print given APE Items'''
    items = apeitems.items()
    items.sort()
    print 'APE Tag\n-------'
    for key, value in items:
        if value.readonly:
            key = '[read only] %s' % key
        if value.type == 'utf8':
            value = u', '.join([v.encode('ascii', 'replace') for v in value])
        else:
            key = '[%s] %s' % (value.type, key)
            if value.type == 'binary':
                value = '[binary data]'
            else:
                value = ', '.join(value)
        print '%s: %s' % (key, value)

def _printid3items(tagfields):
    '''Pretty print given ID3 Fields'''
    items = tagfields.items()
    items.sort()
    print 'ID3 Tag\n-------'
    for key, value in items:
        if value:
            print '%s: %s' % (key, value)

def _removeapeitems(apeitems, removefields):
    '''Remove items from the APE tag'''
    for key in [key.lower() for key in removefields if hasattr(key, 'lower')]:
        if key in apeitems:
            del apeitems[key]
            
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

def _tag(function, fil, action="update", *args, **kwargs):
    '''Preform tagging operation, check args, open/close file if necessary'''
    origfil = fil
    fil, action = _checkargs(fil, action)
    if 'callbackkwargs' in kwargs:
        if 'fields' in kwargs['callbackkwargs']:
            _checkfields(kwargs['callbackkwargs']['fields'])
    try:
        return function(fil, action, *args, **kwargs)
    finally:
        if isinstance(origfil, basestring):
            # filename given as an argument, close file object
            fil.close()
    
def _updateapeitems(apeitems, fields):
    '''Add/Update apeitems using data from fields'''
    for key, value in fields.iteritems():
        if isinstance(value, ApeItem):
            apeitems[value.key.lower()] = value
        else:
            apeitems[key.lower()] = ApeItem(key, value)
    return apeitems

def _updateapetagcallback(apeitems, fields={}, removefields=[]):
    '''Add and/or remove fields from the apeitems'''
    if removefields:
        _removeapeitems(apeitems, removefields)
    return _updateapeitems(apeitems, fields)

def _updateid3fields(tagfields, fields):
    '''Update ID3v1 tagfields using fields'''
    for field, value in fields.iteritems():
       if isinstance(field, str):
           tagfields[field.lower()] = value
    return tagfields

def _updateid3tagcallback(tagfields, fields={}, removefields=[], 
  convertfromape = False):
    '''Add and/or remove fields from the ID3v1 tagfields'''
    if convertfromape:
        fields = _apefieldstoid3fields(fields)
    for field in removefields:
        if field.lower() in tagfields:
            tagfields[field.lower()] = ''
    return _updateid3fields(tagfields, fields)

# Public functions

def createape(fil, fields = {}):
    '''Create/update APE tag in fil with the information in fields'''
    return _tag(_ape, fil, 'create', callback=_updateapetagcallback, 
      callbackkwargs={'fields':fields})
    
def createid3(fil, fields = {}):
    '''Create/update ID3v1 tag in fil with the information in fields'''
    return _tag(_id3, fil, 'create', callback=_updateid3tagcallback, 
      callbackkwargs={'fields':fields})
    
def createtags(fil, fields = {}):
    '''Create/update both APE and ID3v1 tags on fil with the information in fields'''
    return _tag(_ape, fil, 'create', callback=_updateapetagcallback, 
      callbackkwargs={'fields':fields}, updateid3=True)

def deleteape(fil):
    '''Delete APE tag from fil if it exists'''
    return _tag(_ape, fil, action='delete')
    
def deleteid3(fil):
    '''Delete ID3v1 tag from fil if it exists'''
    return _tag(_id3, fil, action='delete')
    
def deletetags(fil):
    '''Delete APE and ID3v1 tags from fil if either exists'''
    deleteid3(fil)
    return _tag(_ape, fil, action='delete', updateid3=True)

def getapefields(fil):
    '''Return fields from APE tag in fil'''
    return _tag(_ape, fil, action='getfields')
    
def getid3fields(fil):
    '''Return fields from ID3v1 tag in fil (including blank fields)'''
    return _tag(_id3, fil, action='getfields')

def gettagfields(fil):
    '''Get APE and ID3v1 tag fields tuple'''
    return _tag(_ape, fil, action='getfields', updateid3=True)

def getrawape(fil):
    '''Return raw APE tag from fil'''
    return _tag(_ape, fil, action='getrawtag')
    
def getrawid3(fil):
    '''Return raw ID3v1 tag from fil'''
    return _tag(_id3, fil, action='getrawtag')

def getrawtags(fil):
    '''Get raw APE and ID3v1 tag tuple'''
    return _tag(_ape, fil, action='getrawtag', updateid3=True)
    
def hasapetag(fil):
    '''Return raw APE tag from fil'''
    return _tag(_ape, fil, action='hastag')
    
def hasid3tag(fil):
    '''Return raw ID3v1 tag from fil'''
    return _tag(_id3, fil, action='hastag')

def hastags(fil):
    '''Get raw APE and ID3v1 tag tuple'''
    return _tag(_ape, fil, action='hastag', updateid3=True)
    
def modifyape(fil, callback, action='update', **kwargs):
    '''Modify APE tag using user-defined callback and kwargs'''
    return _tag(_ape, fil, action=action, callback=callback, 
      callbackkwargs=kwargs)
    
def modifyid3(fil, callback, action='update', **kwargs):
    '''Modify ID3v1 tag using user-defined callback and kwargs'''
    return _tag(_id3, fil, action=action, callback=callback, 
      callbackkwargs=kwargs)
    
def modifytags(fil, apecallback, id3callback=True, action='update', **kwargs):
    '''Modify APE and ID3v1 tags using user-defined callbacks and kwargs
    
    Both apecallback and id3callback receive the same kwargs provided, so they
    need to have the same interface.
    '''
    return _tag(_ape, fil, action=action, callback=apecallback, 
      updateid3=id3callback, callbackkwargs=kwargs)
      
def printapetag(fil):
    '''Print APE tag fields for fil'''
    _printapeitems(getapefields(fil))
    
def printid3tag(fil):
    '''Print ID3 tag fields for fil'''
    _printid3items(getid3fields(fil))
    
def printtags(fil):
    '''Print APE and ID3 tag fields for fil'''
    apeitems, tagfields = gettagfields(fil)
    _printapeitems(apeitems)
    _printid3items(tagfields)

def replaceape(fil, fields = {}):
    '''Replace/create APE tag in fil with the information in fields'''
    return _tag(_ape, fil, 'replace', callback=_updateapetagcallback, 
      callbackkwargs={'fields':fields})
    
def replaceid3(fil, fields = {}):
    '''Replace/create ID3v1 tag in fil with the information in fields'''
    return _tag(_id3, fil, 'replace', callback=_updateid3tagcallback, 
      callbackkwargs={'fields':fields})
    
def replacetags(fil, fields = {}):
    '''Replace/create both APE and ID3v1 tags on fil with the information in fields'''
    return _tag(_ape, fil, 'replace', callback=_updateapetagcallback, 
      callbackkwargs={'fields':fields}, updateid3=True)

def updateape(fil, fields = {}, removefields = []):
    '''Update APE tag in fil with the information in fields'''
    _checkremovefields(removefields)
    return _tag(_ape, fil, 'update', callback=_updateapetagcallback, 
      callbackkwargs={'fields':fields, 'removefields':removefields})
    
def updateid3(fil, fields = {}):
    '''Update ID3v1 tag in fil with the information in fields'''
    return _tag(_id3, fil, 'update', callback=_updateid3tagcallback, 
      callbackkwargs={'fields':fields})
    
def updatetags(fil, fields = {}, removefields = []):
    '''Update both APE and ID3v1 tags on fil with the information in fields'''
    _checkremovefields(removefields)
    return _tag(_ape, fil, 'update', callback=_updateapetagcallback, 
      callbackkwargs={'fields':fields, 'removefields':removefields}, 
      updateid3=True)

if __name__ == '__main__':
    import sys
    for filename in sys.argv[1:]:
        if _isfile(filename):
            print '\n%s' % filename
            try:
                printtags(filename)
            except TagError:
                print 'Missing APE or ID3 Tag'
        else:
            print "%s: file doesn't exist" % filename
