# Copyright (c) 2004 Quasi Reality
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

import struct
import string

_commands = ('create', 'update', 'replace', 'delete', 'getfields', 
               'getrawtag')
#_id3fields[x][0] = start position, _id3fields[x][1] = end position,
_id3fields = {'title': (3,33), 'artist': (33,63), 'album': (63,93), 
             'year': (93,97), 'comment': (97,125) }
# Exercise extreme caution in modifying the tuple below
id3genres = ('Blues', 'Classic Rock', 'Country', 'Dance', 'Disco',  
              'Funk', 'Grunge', 'Hip-Hop', 'Jazz', 'Metal', 'New Age', 
              'Oldies', 'Other', 'Pop', 'R & B', 'Rap', 'Reggae', 'Rock', 
              'Techno', 'Industrial', 'Alternative', 'Ska', 'Death Metal', 
              'Prank', 'Soundtrack', 'Euro-Techno', 'Ambient', 'Trip-Hop', 
              'Vocal', 'Jazz + Funk', 'Fusion', 'Trance', 'Classical', 
              'Instrumental', 'Acid', 'House', 'Game', 'Sound Clip', 
              'Gospel', 'Noise', 'Alternative Rock', 'Bass', 'Soul', 
              'Punk', 'Space', 'Meditative', 'Instrumental Pop', 
              'Instrumental Rock', 'Ethnic', 'Gothic', 'Darkwave', 
              'Techno-Industrial', 'Electronic', 'Pop-Fol', 'Eurodance', 
              'Dream', 'Southern Rock', 'Comedy', 'Cult', 'Gangsta', 
              'Top 40', 'Christian Rap', 'Pop/Funk', 'Jungle', 
              'Native US', 'Cabaret', 'New Wave', 'Psychadelic', 'Rave', 
              'Showtunes', 'Trailer', 'Lo-Fi', 'Tribal', 'Acid Punk', 
              'Acid Jazz', 'Polka', 'Retro', 'Musical', 'Rock & Roll', 
              'Hard Rock', 'Folk', 'Folk-Rock', 'National Folk', 'Swing', 
              'Fast Fusion', 'Bebop', 'Latin', 'Revival', 'Celtic', 
              'Bluegrass', 'Avantgarde', 'Gothic Rock', 
              'Progressive Rock', 'Psychedelic Rock', 'Symphonic Rock', 
              'Slow Rock', 'Big Band', 'Chorus', 'Easy Listening', 
              'Acoustic', 'Humour', 'Speech', 'Chanson', 'Opera', 
              'Chamber Music', 'Sonata', 'Symphony', 'Booty Bass', 
              'Primus', 'Porn Groove', 'Satire', 'Slow Jam', 'Club', 
              'Tango', 'Samba', 'Folklore', 'Ballad', 'Power Ballad', 
              'Rhytmic Soul', 'Freestyle', 'Duet', 'Punk Rock', 
              'Drum Solo', 'Acapella', 'Euro-House', 'Dance Hall', 'Goa', 
              'Drum & Bass', 'Club-House', 'Hardcore', 'Terror', 'Indie', 
              'BritPop', 'Negerpunk', 'Polsk Punk', 'Beat', 
              'Christian Gangsta Rap', 'Heavy Metal', 'Black Metal', 
              'Crossover', 'Contemporary Christian', 'Christian Rock', 
              'Merengue', 'Salsa', 'Trash Meta', 'Anime', 'Jpop', 
              'Synthpop' ) 

_tagerrors = ('Invalid command or argument type', 'Nonexistent or corrupt tag',
              'Specified tag size doesn\'t match actual tag size',
              'Tag too large', 'Error parsing tag', 'Too many items')
              
_baditemkeys = ('id3', 'tag', 'oggs', 'mp+')

# Other item keys can be used, these are just the ones currently defined
apeitemkeys = ('Title', 'Artist', 'Album', 'Year', 'Comment', 'Genre', 'Track',
               'Debut Album', 'Subtitle', 'Publisher', 'Conductor',
               'Composer', 'Copyright', 'Publicationright', 'File', 'EAN/UPC',
               'ISBN', 'Catalog', 'LC', 'Record Date', 'Record Location',
               'Media', 'Index', 'Related', 'ISRC', 'Abstract', 'Language',
               'Bibliography', 'Introplay', 'Dummy')

class TagError(Exception):
    '''Raised when there is an error during a tagging operation'''
    def __init__(self, number, moreinfo=""):
        self.number = number
        self.moreinfo = moreinfo
    def __str__(self):
        return _tagerrors[self.number]
    def getmoreinfo(self):
        return self.moreinfo

def id3(id3file,fields={},action="update"):
    '''Manipulate ID3v1.1 tag.
    
    Arguments
    ---------
    id3file: already opened file object. rb mode necessary to read tags,
        r+b mode necessary to read and write them
    fields: dictionary of tag fields, with the following keys recognized:
        title, artist, album, year, comment: string
        track: integer or sting representation of one
        genre: integer or string (if string, must be a case insensitive
                match for one of the strings in id3genres to be recognized)
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
    IOError on problem accessing file
    TagError on other errors
        
    Notes
    -----
    Only writes ID3v1.1 tags.  Assumes all tags are ID3v1.1.  The only
        exception to this is when it detects an ID3v1.0 tag, it won't
        return the track number in getfields.  Note that the only 
        difference between ID3v1.0 and ID3v1.1 is that the Comment field 
        is 2 characters shorter to make room for the track number, so this 
        shouldn't make any difference to you unless you have comment fields
        using 29 or 30 characters.
    '''
    
    def getfields(data):
        '''Returns a dictionary of tag fields, including empty fields'''
        fields2return = {}
        for key,(start,end) in _id3fields.items():
            fields2return[key] = data[start:end].rstrip("\x00")
        if data[125] == "\x00": 
            # Only add track if a ID3v1.1 tag
            fields2return["track"] = str(ord(data[126]))
        fields2return["genre"] = id3genres[ord(data[127])]
        return fields2return    
    
    if not (isinstance(id3file, file) and isinstance(fields,dict) \
       and isinstance(action,str) and action.lower() in _commands):
        raise TagError(0,"One of the arguments is bad")

    tagexists = True
    id3file.seek(-128, 2)
    data = id3file.read(128)
    # See if tag exists
    if data[0:3] != 'TAG':
        if action == "delete":
            return 0
        if action in ("update", "getfields", "getrawtag"): 
            raise TagError(1, action + ' specified')
        tagexists = False
    else:      
        if action == "delete":
            id3file.truncate(id3file.tell() - 128)
            return 0
    
    if action == "getrawtag":
        return data 
        
    if action == "getfields":
        return getfields(data)
    
    if not tagexists or action == "replace":
        data = 'TAG' + "\x00"*125
   
    fields2add = {}
    for key,value in fields.items():
        if not isinstance(key, str): 
            raise TagError(0, 'One of the keys is not a sting')
        key = key.lower()
        # Check to make sure keys are valid
        if key.lower() in _id3fields.keys():
            if not isinstance(value, str):
                raise TagError(0, value + " isn't a string")
            fields2add[key.lower()] = value
        elif key.lower().startswith('track'):
            if isinstance(value, int):
                try:
                    data = data[:125] + "\x00" + chr(value) + data[127]
                except ValueError:
                    pass
            elif isinstance(value, str):
                try:
                    data = data[:125] + "\x00" + chr(int(value)) + data[127]
                except ValueError:
                    pass
            else:
                raise TagError(0, 'Track is not an int or string')
        elif key.lower() == 'genre':
            if isinstance(value, int):
                # If given an int for the genre, use it
                try: 
                    data = data[:127] + chr(value)
                except ValueError:
                     pass
            elif isinstance(value, str):
                # Otherwise, look up result from id3genres table
                try:
                    data = data[:127] + chr(map(string.lower, 
                           list(id3genres)).index(value.lower()))
                except ValueError:
                    pass
            else:
                raise TagError(0, 'Genre is not an int or string')

    for key,value in fields2add.items():
        key = key.lower()
        # Replace old data with new data
        if len(value) < _id3fields[key][1] - _id3fields[key][0]:
            data = data[:_id3fields[key][0]] + value + \
                   "\x00"*(_id3fields[key][1] - _id3fields[key][0] - \
                   len(value)) + data[_id3fields[key][1]:]
        else:
            data = data[:_id3fields[key][0]] + value[:_id3fields[key][1] - \
                   _id3fields[key][0]] + data[_id3fields[key][1]:]

    if tagexists:
        id3file.truncate(id3file.tell() - 128)
    id3file.seek(0, 2)
    id3file.write(data)
    return getfields(data)

def ape(apefile, addfields = {}, removefields = [], action = "update"):
    '''Manipulate APEv2 tag.
    
    Arguments
    ---------
    apefile: already opened file object. rb mode necessary to read tags,
        r+b mode necessary to read and write them.
    addfields: dictionary of tag fields to add/replace.  
        key: must be a regular string with length 2-255 inclusive
        value: must be a string or a list or tuple of them, or a 
            dictionary with the following keys:
                value: value must be a string or a list or tuple of them
                type: value must be either 'utf8', 'binary', or 'external'
    removefields: list/tuple of tag fields to remove, values must be strings
    action should be one of the following strings (update is the default):
        update: Creates or replaces tag fields in addfields, 
            removes tag fields in removefields (remaining fields unchanged)
        create: Create tag if it doesn't exist, otherwise update
        replace: Remove APEv2 tag from file (if it exists), create new tag 
        delete: Remove APEv2 tag from file
        getfields: Return a dict with the tag fields (includes empty fields)
        getrawtag: Return raw tag string
    
    Returns
    -------
    0 on success of delete
    dict on success of create, update, replace, or getfields
        key is the field name as a string
        value is a string or unicode string or a list of them if it is utf8,
            otherwise it is a dict with a the following keys:
                type: type of field, either 'utf8', 'binary', or 'external'
                value: contents of field as a string or list of strings
                       nonascii values are returned as unicode strings
    string on success of getrawid3
    
    Raises
    ------
    IOError on problem accessing file
    UnicodeDecodeError or UnicodeEncodeError on problems converting 
        regular strings to UTF-8 (See note, or just use unicode strings)
    TagError on other errors
    
    Notes
    -----
    The APEv2 tag is appended to the end of the file.  If the file already
        has id3v1 tag at the end, it is recognized and the APEv2 tag is 
        placed directly before it.  
    APEv2 tags already contained in the file must be appended to the end 
        and possess both a header and a footer in order to be recognized.
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
        be returned as a single string, and if given as input in a list,
        will be joined without a seperator.
    Inserting binary data into tags is "strongly unrecommended."
    Official APEv2 specification is here: 
        http://www.personal.uni-jena.de/~pfk/mpp/sv8/apetag.html
    '''
    
    def getfields(apeitems):
        '''Returns a dictionary of the tag fields'''
        returnfields = {}
        for item in apeitems.values():
            typeint = ord(item["flags"][3])
            typestring = "utf8"
            # Checks for 8-Bit ASCII characters in string
            nonascii = not [c for c in item["value"] if \
               ord(c) not in range(0x00, 0x80)]
            if typeint % 2 != 0:
                typeint = typeint - 1
            for flagtype, flagstring in typeflags.items():
                if item["flags"][0:3]+chr(typeint) == flagstring:
                    typestring = flagtype
            if typestring == "utf8" and nonascii:
                if item["value"].find("\x00") != -1:
                    returnfields[item["key"]] = item["value"].split("\x00")
                else:
                    returnfields[item["key"]] = item["value"]
            elif typestring == "utf8":
                if item["value"].find("\x00") != -1:
                    returnfields[item["key"]] = \
                        item["value"].decode('utf_8').split("\x00")
                else:
                    returnfields[item["key"]] = item["value"].decode('utf_8')         
            elif typestring == "external" and item["value"].find("\x00") != -1:
                returnfields[item["key"]] = {"type":typestring,  
                        "value":item["value"].split("\x00")}
            else:
                returnfields[item["key"]] = {"value":item["value"], 
                    "type":typestring}
        return returnfields
        
    def sortfields(a, b):
        '''Sorts items based on their length'''
        return cmp(len(a), len(b))
        
    def validkey(key):
        '''Checks key to make sure it is a valid APEv2 key'''
        return isinstance(key, str) and 2 <= len(key) <= 255 \
            and not [c for c in key if ord(c) not in range(0x20,0x7F)] \
            and itemkey.lower() not in _baditemkeys
    
    hasid3 = True
    hasapev2 = True
    id3data = ""
    data = ""
    sep = "\x00"  # Separator for list values in tag
    headerflags = "\x00\x00\x00\xA0"
    footerflags = "\x00\x00\x00\x80"
    typeflags = {"utf8":"\x00\x00\x00\x00", "binary":"\x00\x00\x00\x02",
                 "external":"\x00\x00\x00\x04" }
    fields2remove = []
    apeentries = []
    apesize = 0
    numitems = 0
    apeitems = {}
    # 8320 = 8192 (8K) + 128 for the id3v1 tag
    readsize = 8320 
    
    if not (isinstance(apefile, file) and isinstance(addfields, dict) \
       and isinstance(removefields, (list, tuple)) \
       and isinstance(action, str) and action.lower() in _commands):
        raise TagError(0,"One of the arguments is bad")
    
    apefile.seek(-1 * readsize, 2)
    data = apefile.read(readsize)
    if data[-128:-125] != 'TAG':
        hasid3 = False
    else:
        id3data = data[-128:]
        data = data[:-128]

    apetagcount = data.count("APETAGEX\xD0\x07\x00\x00")
    if apetagcount == 0:
        if action in ("update", "getfields", "getrawtag"):
            raise TagError(1, action + ' specified')
        elif action == "delete":
            return 0
        hasapev2 = False
        apetagstart = len(data)
    elif apetagcount == 2:
        apetagstart = data.find("APETAGEX\xD0\x07\x00\x00")
        if action == "delete":
            apefile.seek(-1 * readsize + apetagstart,2)
            apefile.truncate()
            apefile.write(id3data)
            return 0    
    else:
        return TagError(1, " ".join('Either header or footer is missing,',
            'or there are multiple APEv2 tags'))

    if action == "getrawtag":
        return data[apetagstart:] 

    if hasapev2 and action != "replace":
        data = data[apetagstart:]
        apesize = struct.unpack("<i",data[12:16])[0] + 32
        if  apesize != len(data):
            raise TagError(2, 'Specified Size: ' + str(apesize) + \
                              ' Actual Size: ' + str(len(data)))
        
        numitems = struct.unpack("<i",data[16:20])[0]
        # (8192 - 64 (len(header+footer))) / 11 (min len of item) = 738
        if numitems > 738:
            raise TagError(5, 'Tag specified ' + numitems + ' items')
        
        headerflags = data[20:24]
        data = data[32:]
            
        # Parse each item in the tag
        for x in range(numitems):
            itemlength = struct.unpack("<i",data[0:4])[0]
            itemflags = data[4:8]
            data = data[8:]
            keyend = data.find("\x00")
            itemkey = data[:keyend]
            data = data[keyend+1:]
            itemvalue = data[:itemlength]
            data = data[itemlength:]
            apeitems[itemkey.lower()] = \
                {"key":itemkey, "flags":itemflags, "value":itemvalue}
        if len(data) != 32:
            raise TagError(4, " ".join('Tag should be fully parsed, but', 
                str(len(data)), 
                'bytes are still remaining, so tag is probably corrupt'))
            
        if action == "getfields":
            return getfields(apeitems)
        footerflags = data[20:24]
        
        # Remove requested items from tag
        for itemkey in removefields:
            if not isinstance(itemkey, str):
                raise TagError(0, itemkey + " in removeitems is bad")
            if itemkey.lower() in apeitems.keys():
                del apeitems[itemkey.lower()]

    # Add requested items to tag
    for itemkey,itemvalue in addfields.items():
        if not validkey(itemkey):
            raise TagError(0, itemkey + ' in additems is bad')
        if isinstance(itemvalue, (str, unicode)):
            apeitems[itemkey.lower()] = {"key":itemkey, 
                "value":itemvalue.encode("utf_8"), "flags":typeflags["utf8"]}
        elif isinstance(itemvalue, (list, tuple)):
            try:
                apeitems[itemkey.lower()] = {"key":itemkey, 
                    "value":(sep.join(itemvalue)).encode("utf_8"), 
                    "flags":typeflags["utf8"]}
            except ValueError:
                raise TagError(0, itemkey + ' in addfields is bad')
        elif isinstance(itemvalue, dict):
            try:
                if isinstance(itemvalue["value"], (str, unicode)):
                    apeitems[itemkey.lower()] = {"key":itemkey, 
                         "value":itemvalue["value"].encode("utf_8"),
                         "flags":typeflags[itemvalue["type"]]}
                elif isinstance(itemvalue["value"], (list, tuple)):
                    if itemvalue["type"] == "binary":
                        # Don't encode value, don't use null seperator
                        apeitems[str(itemkey).lower()] = {"key":itemkey, 
                        "flags":typeflags[itemvalue["type"]],
                        "value":"".join(itemvalue["value"])}
                    elif itemvalue["type"] == "utf8":
                        # Item already encoded, so don't encode
                        apeitems[str(itemkey).lower()] = {"key":itemkey, 
                        "flags":typeflags[itemvalue["type"]],
                        "value":(sep.join(itemvalue["value"]))}
                    elif itemvalue["type"] == "external":
                        apeitems[str(itemkey).lower()] = {"key":itemkey, 
                        "flags":typeflags[itemvalue["type"]],
                        "value":(sep.join(itemvalue["value"])).encode("utf_8")}
                else:
                    raise TagError(0, itemkey + ' in addfields is bad')
            except (ValueError, TypeError):
                raise TagError(0, itemkey + ' in addfields is bad')
        else:
            raise TagError(0, itemkey + ' in addfields is bad')
    
    apesize = 64
    for item in apeitems.values():
        apesize += 9 + len(item["key"]) + len(item["value"])
    numitems = len(apeitems)
    
    # Construct tag string
    data = "APETAGEX\xD0\x07\x00\x00" + struct.pack("<i",apesize-32) + \
             struct.pack("<i",numitems) + headerflags + "\x00" * 8
    for item in apeitems.values():
        apeentries.append(struct.pack("<i",len(item["value"])) + \
            item["flags"] + item["key"] + "\x00" + item["value"])
    # Sort items according to their length, per the APEv2 standard
    apeentries.sort(sortfields)
    data += "".join(apeentries)
    data += "APETAGEX\xD0\x07\x00\x00" + struct.pack("<i",apesize-32) + \
              struct.pack("<i",numitems) + footerflags + "\x00" * 8
    if len(data) > readsize:
        raise TagError(3, 'New tag is too large: ' + str(len(data)) + ' bytes')
    apefile.seek(-1 * readsize + apetagstart,2)
    apefile.truncate()
    apefile.write(data + id3data)
    return getfields(apeitems)