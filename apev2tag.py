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

'''Module for manipulating APEv2 and ID3v1.1 tags'''

from struct import pack as _pack, unpack as _unpack
from os.path import isfile as _isfile

# Variable definitions
__version__ = '0.8'
_commands = 'create update replace delete getfields getrawtag'.split()
_tagmustexistcommands = 'update getfields getrawtag'.split()
_filelikeattrs = 'flush read seek tell truncate write'.split()
_badapeitemkeys = 'id3 tag oggs mp+'.split()
_nonasciichars = ''.join([chr(x) for x in range(128,256)])
_badapeitemkeychars = _nonasciichars + ''.join([chr(x) for x in range(32)])
_apeheaderflags = "\x00\x00\x00\xA0"
_apefooterflags = "\x00\x00\x00\x80"
_apepreamble = "APETAGEX\xD0\x07\x00\x00"
_apetypeflags = {"utf8":"\x00\x00\x00\x00", "binary":"\x00\x00\x00\x02",
                 "external":"\x00\x00\x00\x04" }
_id3tagformat = 'TAG%(title)s%(artist)s%(album)s%(year)s%(comment)s' \
                '\x00%(track)s%(genre)s'
_id3fields = {'title': (3,33), 'artist': (33,63), 'album': (63,93), 
              'year': (93,97), 'comment': (97,125) } # (start, end)
_id3genres = '''Blues, Classic Rock, Country, Dance, Disco, Funk, Grunge, 
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
id3genres = [x.strip() for x in _id3genres.split(',')]
_id3genreslower = [x.lower() for x in id3genres]
apeitemkeys = [x.strip() for x in _apeitemkeys.split(',')]
del x

# Exception class

class TagError(StandardError):
    '''Raised when there is an error during a tagging operation'''
    pass

# Private Helper functions

def _apefieldstoid3fields(fields):
    '''Convert APEv2 tag fields to ID3 tag fields '''
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
            if value in id3genres:
                id3fields['genre'] = id3genres.index(value)
            elif value in _id3genreslower:
                id3fields['genre'] = _id3genreslower.index(value)
        elif key in _id3fields:
            if isinstance(value, str):
                id3fields[key] = value
            elif isinstance(value, unicode):
                id3fields[key] = value.encode('utf8', 'replace')
            elif isinstance(value, (list, tuple)):
                try:
                    id3fields[key] = ', '.join(value)
                except ValueError:
                    raise TagError, 'Invalid tag value for %s field: %r' % (key, value)
            elif isinstance(value, dict):
                if 'value' not in value or not isinstance(value['value'], str):
                    raise TagError, 'Invalid tag value for %s field: %r' % (key, value)
                id3fields[key] = value['value']
    return id3fields

_apelengthreduce = lambda i1, i2: i1 + 9 + len(i2["key"]) + len(i2["value"])

def _checkargs(fil, fields, action):
    '''Check that arguments are valid, convert them, or raise an error'''
    if not (isinstance(action,str) and action.lower() in _commands):
        raise TagError, "%r is not a valid action" % action
    action = action.lower()
    fil = _getfileobj(fil, action)
    for attr in _filelikeattrs:
        if not hasattr(fil, attr) or not callable(getattr(fil, attr)):
            raise TagError, "file does not support method %r" % attr
    if not hasattr(fields, 'items') or not callable(fields.items):
        raise TagError, "fields does not support method 'items'"
    return fil, fields, action

def _getapefields(apeitems):
    '''Convert internal dictionary of APEv2 tag fields to external format'''
    returnfields = {}
    for item in apeitems.values():
        typeint = ord(item["flags"][3])
        typestring = "utf8"
        itemvalue = item["value"]
        # Check for 8-Bit ASCII characters in string
        nonascii = _stringoverlaps(item["value"], _nonasciichars)
        if typeint & 1:
            # Ignore read only flag
            typeint = typeint - 1
        for flagtype, flagstring in _apetypeflags.items():
            if item["flags"][:3]+chr(typeint) == flagstring:
                typestring = flagtype
                break
        if typestring == "utf8":
            if nonascii:
                itemvalue = item["value"].decode('utf_8')
            if itemvalue.find("\x00") != -1:
                returnfields[item["key"]] = itemvalue.split("\x00")
            else:
                returnfields[item["key"]] = itemvalue
        else:
            returnfields[item["key"]] = {"type":typestring, "value":itemvalue}
    return returnfields

def _getfileobj(fil, action):
    '''Return a file object if given a filename, otherwise return file'''
    if isinstance(fil, basestring) and _isfile(fil):
        if action in ('getfields', 'getrawtag'):
            mode = 'rb'
        else:
            mode = 'r+b'
        return file(fil, mode)
    return fil

def _makeapev2tag(apeitems):
    '''Construct an APEv2 tag string from a list of dictionaries'''
    apeentries = []
    apesize = _pack("<i",reduce(_apelengthreduce, apeitems.values(), 32))
    numitems = _pack("<i",len(apeitems))
    headerfooter = _apepreamble + apesize + numitems
    
    # Add items
    for item in apeitems.values():
        apeentries.append(_pack("<i",len(item["value"])) + \
            item["flags"] + item["key"] + "\x00" + item["value"])
    # Sort items according to their length, per the APEv2 standard
    apeentries.sort(_sortapeitems)
    # Add the header and footer
    apeentries.insert(0, headerfooter + _apeheaderflags + "\x00" * 8)
    apeentries.append(headerfooter + _apefooterflags + "\x00" * 8)
    return "".join(apeentries)

def _makeid3tag(fields):
    '''Make an ID3 tag from the given dictionary'''
    newfields = {}
    newfields.update(fields)
    for field, value in newfields.items():
        if not isinstance(field, str):
            del newfields[field]
        field = field.lower()
        if field.startswith('track'):
            try:
                newfields['track'] = chr(int(value))
            except ValueError:
                raise TagError, '%r is an invalid value for %r' % (value, field)
        elif field == 'genre':
            if not isinstance(value, int):
                if not isinstance(value, str):
                    raise TagError, "%r is an invalid value for 'genre'" % value
                newvalue = value.lower()
                if newvalue in _id3genreslower:
                    newfields[field] = chr(_id3genreslower.index(newvalue))
                else:
                    newfields[field] = '\xff'
    for field, (startpos, endpos) in _id3fields.items():
        maxlength = endpos - startpos
        if field in newfields:
            fieldlength = len(newfields[field])
            if fieldlength > maxlength:
                newfields[field] = newfields[field][:maxlength]
            elif fieldlength < maxlength:
                newfields[field] = newfields[field] + \
                '\x00' * (maxlength - fieldlength)
        else:
            newfields[field] = '\x00' * maxlength
    if 'track' not in newfields:
        newfields['track'] = '\x00'
    if 'genre' not in newfields:
        newfields['genre'] = '\xff'
    return _id3tagformat % newfields

def _parseapev2tag(data):
    '''Parse an APEv2 tag and return a dictionary of tag fields'''
    apeitems = {}
    numitems = _unpack("<i",data[16:20])[0]
    # 64 is size of header + footer, 11 is minimum item length item
    if numitems > (len(data) - 32)/11:
        raise TagError, 'Corrupt tag, specifies more items that is possible ' \
                        'given space remaining: %i items' % numitems
    # Parse each item in the tag
    curpos = 32
    for x in range(numitems):
        itemlength = _unpack("<i",data[curpos:curpos+4])[0]
        itemflags = data[curpos+4:curpos+8]
        curpos += 8
        keyend = data.find("\x00", curpos)
        keylength = keyend - curpos
        itemkey = data[curpos:curpos+keylength]
        curpos += keylength + 1
        itemvalue = data[curpos:curpos+itemlength]
        curpos += itemlength
        apeitems[itemkey.lower()] = \
            {"key":itemkey, "flags":itemflags, "value":itemvalue}
    if len(data) - curpos != 32:
        raise TagError, 'Corrupt tag, parsing complete but not at end ' \
            'of input: %i bytes remaining' % (len(data) - curpos)
    return apeitems

def _parseid3tag(data):
    '''Parse an ID3 tag and return a dictionary of tag fields'''
    fields2return = {}
    for key,(start,end) in _id3fields.items():
        fields2return[key] = data[start:end].rstrip("\x00")
    if data[125] == "\x00": 
        # Only add track if a ID3v1.1 tag
        fields2return["track"] = str(ord(data[126]))
    genreid = ord(data[127])
    if genreid < len(id3genres):
        fields2return["genre"] = id3genres[genreid]
    return fields2return

def _stringoverlaps(string1, string2):
    '''Check if any character in either string is in the other string'''
    if len(string1) > len(string2):
        string1, string2 = string2, string1
    for char in string1:
        if char in string2:
            return True
    return False

_sortapeitems = lambda a, b: cmp(len(a), len(b))

def _validapeitemkey(key):
    '''Checks key to make sure it is a valid APEv2 key'''
    return isinstance(key, str) and 2 <= len(key) <= 255 \
        and not _stringoverlaps(key, _badapeitemkeychars) \
        and key.lower() not in _badapeitemkeys

# Public functions

def apev2tag(fil, fields = {}, removefields = [], action = "update"):
    '''Manipulate APEv2 tag.
    
    Arguments
    ---------
    fil: filename string OR already opened file or file-like object that
        supports flush, seek, read, truncate, tell, and write
    fields: dictionary like object of tag fields that has an items method
        which returns a list of key, value tuples to add/replace.  
        key: must be a regular string with length 2-255 inclusive
        value: must be a string or a list or tuple of them, or a 
            dictionary with the following keys:
                value: value must be a string or a list or tuple of them
                type: value must be either 'utf8', 'binary', or 'external'
    removefields: iterable yielding strings of tag fields to remove
    action should be one of the following strings (update is the default):
        update: Creates or replaces tag fields in fields, 
            removes tag fields in removefields (remaining fields unchanged)
        create: Create tag if it doesn't exist, otherwise update
        replace: Remove APEv2 tag from file (if it exists), create new tag 
        delete: Remove APEv2 tag from file
        getfields: Return a dict with the tag fields (includes empty fields)
        getrawtag: Return raw tag string
    
    Returns
    -------
    0 on success of delete
    string on success of getrawid3
    dict on success of create, update, replace, or getfields
        key is the field name as a string
        value is a string or unicode string or a list of them if it is utf8,
            otherwise it is a dict with a the following keys:
                type: type of field, either 'utf8', 'binary', or 'external'
                value: contents of field as a string or list of strings
                       nonascii values are returned as unicode strings
    
    Raises
    ------
    IOError on problem accessing file (make sure read/write access is allowed
        for the file if you are trying to modify the tag)
    UnicodeError on problems converting regular strings to UTF-8 (See note, or 
        just use unicode strings)
    TagError on other errors
    
    Notes
    -----
    The APEv2 tag is appended to the end of the file.  If the file already
        has id3v1 tag at the end, it is recognized and the APEv2 tag is 
        placed directly before it.  
    APEv1 tags (those without a header) are not supported.
    Maximum allowed size for the APEv2 tag is 8192 bytes, as recommended
        by the creator of the APEv2 spec.
    There is no support for read-only tag fields, since there is no way of
        enforcing the read-only flag.  Read-only flags are already present 
        are ignored.
    APEv2 item values are encoded in UTF-8, so you need to use unicode 
        strings as values if you plan to use ASCII characters greater than 
        0x7F.
    If the 'utf8' type is specified, the value should already be encoded 
        in UTF-8. Do not specify the 'utf8' type unless you have already
        encoded the value in UTF-8.  
    Values in the returned dictionary will be unicode strings if they 
        contain ASCII values over 0x7F.
    List of items (such as multiple artists) are stored as a single string
        separated by null characters, and since binary data can contain
        null characters that don't act as seperators, binary data will
        be returned as a single string, and if given as input in a list, it
        will be joined without a seperator.
    Inserting binary data into tags is "strongly unrecommended."
    Official APEv2 specification is here: 
        http://www.personal.uni-jena.de/~pfk/mpp/sv8/apetag.html
    Cached version located here:
        http://www.ikol.dk/~jan/musepack/klemm/www.personal.uni-jena.de/~pfk/mpp/sv8/apetag.html
    '''
    
    fil, fields, action = _checkargs(fil, fields, action)
    if not hasattr(removefields, '__iter__') or not callable(removefields.__iter__):
        raise TagError, "removefields is not an iterable"

    hasid3 = True
    hasapev2 = True
    id3data = ""
    data = ""
    sep = "\x00"  # Separator for list values in tag
    apesize = 0
    numitems = 0
    maxsize = 8192 # Maximum length of APEv2 tag
    
    fil.seek(0, 2)
    filesize = fil.tell()
    fil.seek(-1 * 128, 1)
    data = fil.read(128)
    if data[:3] != 'TAG':
        hasid3 = False
        fil.seek(-1 * 32, 1)
    else:
        id3data = data
        fil.seek(-1 * 160, 1)
    data = fil.read(32)

    if _apepreamble != data[:12] or _apefooterflags != data[20:24]:
        if action in _tagmustexistcommands:
            raise TagError, "Nonexistant or corrupt tag, can't %s" % action
        elif action == "delete":
            return 0
        hasapev2 = False
    else:
        apesize = _unpack("<i",data[12:16])[0] + 32
        if apesize > maxsize:
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
        return _getapefields(_parseapev2tag(data))
    
    if not hasapev2 or action == "replace":
        apeitems = {}
    else:
        apeitems = _parseapev2tag(data)
        for itemkey in removefields:
            if not isinstance(itemkey, str):
                raise TagError, "Invalid entry in removeitems: %r" % itemkey
            if itemkey.lower() in apeitems.keys():
                del apeitems[itemkey.lower()]

    # Add requested items to tag
    for itemkey, itemvalue in fields.items():
        if not _validapeitemkey(itemkey):
            raise TagError, 'Invalid item key: %r' % itemkey
        itemkeylower = itemkey.lower()
        apeitems[itemkeylower] = {"key":itemkey, "flags":_apetypeflags["utf8"]}
        apeitem = apeitems[itemkeylower]
        if isinstance(itemvalue, basestring):
            apeitem['value'] = itemvalue.encode("utf_8")
        elif isinstance(itemvalue, (list, tuple)):
            try:
                apeitem['value'] =  sep.join(itemvalue).encode("utf_8")
            except (ValueError, TypeError):
                raise TagError, 'Invalid value in list for item: %r' % itemkey
        elif isinstance(itemvalue, dict):
            try:
                apeitem['flags'] = _apetypeflags[itemvalue["type"]]
                if isinstance(itemvalue["value"], basestring):
                    apeitem['value'] = itemvalue["value"].encode("utf_8")
                elif isinstance(itemvalue["value"], (list, tuple)):
                    if itemvalue["type"] == "binary":
                        # Don't encode value, don't use null seperator
                        apeitem['value'] = "".join(itemvalue["value"])
                    else:
                        apeitem['value'] = sep.join(itemvalue["value"])
                        if itemvalue["type"] == "external":
                            apeitem['value'] = apeitem['value'].encode("utf_8")
                else:
                    raise TagError, 'Invalid value inside dictionary item; ' \
                        'not list, tuple, string, or unicode: %r' % itemkey
            except (ValueError, TypeError):
                raise TagError, 'Invalid value in list for item: %r' % itemkey
            except KeyError:
                raise TagError, 'Bad type specified: %r' % itemvalue["type"]
        else:
            raise TagError, 'Invalid value for item; not list, tuple, dict ' \
                            'string, or unicode: %r' % itemkey
     
    newtag = _makeapev2tag(apeitems)

    if len(newtag) > maxsize:
        raise TagError, 'New tag is too large: %i bytes' % len(data)
    # truncate() does not seem to work properly in all cases without 
    #  explicitly given the position
    fil.truncate(fil.tell())
    # Must seek to end of file as truncate appears to modify the file's
    #  current position in certain cases
    fil.seek(0,2)
    fil.write(newtag + id3data)
    fil.flush()
    return _getapefields(apeitems)

def id3tag(fil,fields={},action="update"):
    '''Manipulate ID3v1.1 tag
    
    Arguments
    ---------
    fil: filename string OR already opened file or file-like object that
        supports flush, seek, read, truncate, tell, and write
    fields: dictionary or dictionary like object of tag fields that has an
            items method which returns a list of key, value tuples, with the
            following keys recognized:
                title, artist, album, year, comment: string
                track: integer or sting representation of one
                genre: integer or string (if string, must be a case insensitive
                        match for one of the strings in id3genres to be 
                        recognized)
    action: must be one of the following strings (update is the default):
        update: Updates tag with new fields (remaining fields stay the same)
        create: Create tag if it doesn't exist, update if tag already exists
        replace: Replace tag if it exists using new fields, otherwise create
        delete: Remove tag from file
        getfields: Return a dict with the tag fields (includes empty fields)
        getrawtag: Return raw tag string

    Returns
    -------
    0 on success of delete
    dict on success of create, update, replace, or getfields 
    string on success of getrawtag
    
    Raises
    ------
    IOError on problem accessing file (make sure read/write access is allowed
        for the file if you are trying to modify the tag)
    TagError on other errors
        
    Notes
    -----
    Only writes ID3v1.1 tags.  Assumes all tags are ID3v1.1.  The only 
    exception to this is when it detects an ID3v1.0 tag, it won't return the 
    track number in getfields.  Note that the only difference between ID3v1.0 
    and ID3v1.1 is that the Comment field is 2 characters shorter to make room 
    for the track number, so this shouldn't make any difference to you unless 
    you have comment fields using 29 or 30 characters.
    '''
    
    fil, fields, action = _checkargs(fil, fields, action)
    
    tagexists = True
    fil.seek(-128, 2)
    data = fil.read(128)
    
    # See if tag exists
    if data[0:3] != 'TAG':
        if action == "delete":
            return 0
        if action in _tagmustexistcommands: 
            raise TagError, "Nonexistant or corrupt tag, can't %s" % action
        tagexists = False
    else:      
        if action == "delete":
            fil.truncate(fil.tell() - 128)
            return 0
    
    if action == "getrawtag":
        return data 
    if action == "getfields":
        return _parseid3tag(data)
    
    if not tagexists or action == "replace":
        tagfields = {}
    else:
        tagfields = _parseid3tag(data)
        
    for field, value in fields.items():
       if isinstance(field, str):
           tagfields[field.lower()] = value
    
    newtag = _makeid3tag(tagfields)

    if tagexists:
        fil.truncate(fil.tell() - 128)
    fil.seek(0, 2)
    fil.write(newtag)
    fil.flush()
    return _parseid3tag(newtag)
    
# Public helper functions
# See docstring for apev2tag and id3tag for these functions

def createapev2(fil, fields = {}):
    return apev2tag(fil, fields, action='create')
def createid3(fil, fields = {}):
    return id3tag(fil, fields, 'create')
def createtags(fil, fields = {}):
    createid3(fil, _apefieldstoid3fields(fields))
    return createapev2(fil, fields)

def deleteapev2(fil):
    return apev2tag(fil, action='delete')
def deleteid3(fil):
    return id3tag(fil, action='delete')
def deletetags(fil):
    deleteid3(fil)
    return deleteapev2(fil)

def getapev2fields(fil):
    return apev2tag(fil, action='getfields')
def getid3fields(fil):
    return id3tag(fil, action='getfields')

def getrawapev2(fil):
    return apev2tag(fil, action='getrawtag')
def getrawid3(fil):
    return id3tag(fil, action='getrawtag')

def replaceapev2(fil, fields = {}):
    return apev2tag(fil, fields, action='replace')
def replaceid3(fil, fields = {}):
    return id3tag(fil, fields, 'replace')
def replacetags(fil, fields = {}):
    replaceid3(fil, _apefieldstoid3fields(fields))
    return replaceapev2(fil, fields)

def updateapev2(fil, fields = {}, removefields = []):
    return apev2tag(fil, fields, removefields, 'update')
def updateid3(fil, fields = {}):
    return id3tag(fil, fields, 'update')
def updatetags(fil, fields = {}, removefields = []):
    updateid3(fil, _apefieldstoid3fields(fields))
    return updateapev2(fil, fields, removefields)
