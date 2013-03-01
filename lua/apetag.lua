require('io_truncate')

--- True if the string is valid UTF-8, and false if not.
-- The algorithm is borrowed from the libapetag C library.
-- @params s string to check
-- @return boolean
function string.is_utf8(s)
    local i = 1
    local c = nil
    local b = nil
    local l = string.len(s)
    while i <= l do 
        c = string.byte(s, i)
        if c >= 128 then
            if c < 194 or c > 245 then
                return false
            end
            if c >= 194 and c < 224 then
                b = 1
            elseif c >= 224 and c < 240 then
                b = 2
            elseif c >= 240 and c <= 244 then
                b = 3
            else
                return false
            end
            
            if b + i > l then
                return false
            end
            for j=(i+1),(i+b) do
                c = string.byte(s, j)
                if c < 128 or c >= 192 then
                    return false
                end
            end
            i = i + b + 1
        else
            i = i + 1
        end
    end
    return true
end

--- Pad a string to the right with '\0' to length n.
-- If n is less than the size of s, returns the first n characters.  Otherwise,
-- it pads the string with '\0' to n characters.
-- @params s string to pad
-- @params n length of string to return
-- @return string
function string.padzr(s, n)
    local l = string.len(s)
    if l > n then
        s = string.sub(s, 1, n)
    else
        s = s .. string.rep('\0', n-l)
    end
    return s
end

--- Pack a series of numbers into a binary string
-- From http://lua-users.org/wiki/ReadWriteFormat
-- This format function packs a list of integers into a binary string.
-- The sizes of the integers can be specified, both little and big endian
-- ordering are supported.
-- Example:
--   string.pack(true, "421", 0x12345678, 0x432931, 0x61) returns "xV4.1)a",
--     a 7 bytes string whose characters are in hex: 78 56 45 12 31 29 61
-- @params little_endian true if packing in little endian format, false for big
--         endian format
-- @params format string composed of ASCII digit numbers, the size in bytes of
--         the corresponding value
-- @return string
function string.pack(little_endian, format, ...)
  local res = ''
  local values = {...}
  for i=1,#format do
    local size = tonumber(format:sub(i,i))
    local value = values[i]
    local str = ""
    for j=1,size do
      str = str .. string.char(value % 256)
      value = math.floor(value / 256)
    end
    if not little_endian then
      str = string.reverse(str)
    end
    res = res .. str
  end
  return res
end

-- Unpack a string and return all numbers
-- From http://lua-users.org/wiki/ReadWriteFormat
-- This format function does the inverse of string.pack. It unpacks a binary
-- string into a list of integers of specified size, supporting big and little 
-- endian ordering. Example:
--   string.unpack(true, "421", "xV4.1)a") returns 0x12345678, 0x2931 and 0x61.
-- @params little_endian true if unpacking in little endian format, false for 
--         big endian format
-- @params format string composed of ASCII digit numbers, the size in bytes of
--         the corresponding value
-- @return number, ...
function string.unpack(little_endian, format, str)
  local idx = 0
  local res = {}
  for i=1,#format do
    local size = tonumber(format:sub(i,i))
    local val = str:sub(idx+1,idx+size)
    local value = 0
    idx = idx + size
    if little_endian then
      val = string.reverse(val)
    end
    for j=1,size do
      value = value * 256 + val:byte(j)
    end
    res[i] = value
  end
  return unpack(res)
end

--- Individual items in the tag
-- @class
ApeItem = {
    MIN_SIZE=11,
    BAD_KEY_RE='[%z\1-\31\128-\255]',
    BAD_KEYS={id3 = true, tag=true, oggs=true,},
}
ApeItem.__index = ApeItem
ApeItem.BAD_KEYS['mp+'] = true

-- Create an ApeItem with the given key, values, and flags
-- @param key string
-- @param values string or number or an array of either/both
-- @param flags 0 <= number <= 7
-- @return ApeItem
function ApeItem:new(key, values, flags)
    local fields = {key=tostring(key), flags=(flags or 0)}
    if type(values) ~= 'table' then
        values = {tostring(values)}
    elseif values.flags then
        fields.flags = values.flags
    end
    for i,value in ipairs(values) do
        table.insert(fields, tostring(value))
    end
    setmetatable(fields, self)
    return fields
end

--- Parse an ApeItem from the given string at the given offset
-- Raises an error if the parsing does not result in a valid ApeItem.
-- @param data raw tag data string
-- @param offset numeric offset from start of string
-- @return ApeItem, new_offset
function ApeItem:parse(data, offset)
    local data_length = string.len(data)
    local length = string.unpack(true, '4', string.sub(data, offset, offset+3))
    local flags = string.unpack(false, '4', string.sub(data, offset+4, offset+7))
    if length + offset + ApeItem.MIN_SIZE > data_length then
        error('Invalid item length before taking key length into account')
    end
    if flags > 7 then
        error('Invalid item flags')
    end
    offset = offset + 8
    local key_end = string.find(data, '\0', offset, true)
    if not key_end then
        error('Missing key-value separator')
    end
    key_end = key_end - 1
    local next_item_start = length + key_end + 2
    if next_item_start > data_length + 1 then
        error('Invalid item length after taking key length into account')
    end
    local values = {}
    for v in string.gmatch(string.sub(data, key_end+2, next_item_start - 1), '[^%z]+') do 
        table.insert(values,v)
    end
    if table.maxn(values) == 0 then
        table.insert(values, '')
    end
    local item = ApeItem:new(string.sub(data, offset, key_end), values, flags)
    item:validate()
    return item, next_item_start
end

--- Raw data string representing ApeItem
-- @return string
function ApeItem:raw()
    local raw = ''
    for i,value in ipairs(self) do
        if raw ~= '' then
            raw = raw .. '\0'
        end
        raw = raw .. value
    end
    return string.pack(true, '4', string.len(raw)) .. string.pack(false, '4', self.flags) .. self.key .. '\0' .. raw
end

--- Raise an error if the item is invalid
-- @return nil
function ApeItem:validate()
    if not (type(self.key) == 'string' and string.len(self.key) >= 2 and string.len(self.key) <= 255 and
    not string.match(self.key, self.BAD_KEY_RE) and not self.BAD_KEYS[string.lower(self.key)] and
    self.flags >= 0 and self.flags <= 7 and self:valid_value()) then
        error('Invalid ApeItem')
    end
end

--- Whether the item's value is valid (UTF8 if flags specify it)
-- @return boolean
function ApeItem:valid_value()
    if self.flags == 0 or self.flags == 1 or self.flags == 4 or self.flags == 5 then
        for i,value in ipairs(self) do
            if not string.is_utf8(value) then
                return false
            end
        end
    end
    return true
end

--- Holds multiple ApeItems, with case independent access
-- Item keys are stored lower case with an _ prefixing them.
-- Therefore, one should not use examplekey and _examplekey at the same time.
-- @class
ApeFields = {}
function ApeFields:new()
    local fields = {}
    setmetatable(fields, self)
    return fields
end

--- Return value matching key in a case insensitive manner
-- @param t ApeFields
-- @param key string
-- @return ApeItem
function ApeFields.__index(t, key)
    return rawget(t, '_' .. string.lower(key))
end

--- Set the value of the entry in the table for the given key
-- @param t ApeFields
-- @param key string
-- @param value string, number, or array of either/both (or nil to unset)
-- @return ApeItem
function ApeFields.__newindex(t, key, value)
    if value == nil then
        return rawset(t, '_' .. string.lower(key), nil)
    end
    return rawset(t, '_' .. string.lower(key), ApeItem:new(key, value))
end

--- The entire tag
-- @class
ApeTag = {
    MAX_SIZE=8192, 
    MAX_ITEM_COUNT=64, 
    HEADER_FLAGS = "\0\0\160",
    FOOTER_FLAGS = "\0\0\128",
    PREAMBLE = "APETAGEX\208\7\0\0",
    RECOMMENDED_KEYS = {'Title', 'Artist', 'Album', 'Year', 'Comment', 'Genre',
        'Track', 'Subtitle', 'Publisher', 'Conductor', 'Composer', 'Copyright',
        'Publicationright', 'File', 'EAN/UPC', 'ISBN', 'Catalog', 'LC',
        'Media', 'Index', 'Related', 'ISRC', 'Abstract', 'Language',
        'Bibliography', 'Introplay', 'Dummy', 'Debut Album', 'Record Date',
        'Record Location'},
    ID3_GENRES = {'Blues', 'Classic Rock', 'Country', 'Dance', 'Disco', 'Funk', 'Grunge', 
        'Hip-Hop', 'Jazz', 'Metal', 'New Age', 'Oldies', 'Other', 'Pop', 'R & B', 'Rap', 'Reggae',
        'Rock', 'Techno', 'Industrial', 'Alternative', 'Ska', 'Death Metal', 'Prank', 'Soundtrack',
        'Euro-Techno', 'Ambient', 'Trip-Hop', 'Vocal', 'Jazz + Funk', 'Fusion', 'Trance',
        'Classical', 'Instrumental', 'Acid', 'House', 'Game', 'Sound Clip', 'Gospel', 'Noise',
        'Alternative Rock', 'Bass', 'Soul', 'Punk', 'Space', 'Meditative', 'Instrumental Pop',
        'Instrumental Rock', 'Ethnic', 'Gothic', 'Darkwave', 'Techno-Industrial', 'Electronic',
        'Pop-Fol', 'Eurodance', 'Dream', 'Southern Rock', 'Comedy', 'Cult', 'Gangsta', 'Top 40',
        'Christian Rap', 'Pop/Funk', 'Jungle', 'Native US', 'Cabaret', 'New Wave', 'Psychadelic',
        'Rave', 'Showtunes', 'Trailer', 'Lo-Fi', 'Tribal', 'Acid Punk', 'Acid Jazz', 'Polka',
        'Retro', 'Musical', 'Rock & Roll', 'Hard Rock', 'Folk', 'Folk-Rock', 'National Folk',
        'Swing', 'Fast Fusion', 'Bebop', 'Latin', 'Revival', 'Celtic', 'Bluegrass', 'Avantgarde',
        'Gothic Rock', 'Progressive Rock', 'Psychedelic Rock', 'Symphonic Rock', 'Slow Rock',
        'Big Band', 'Chorus', 'Easy Listening', 'Acoustic', 'Humour', 'Speech', 'Chanson', 'Opera',
        'Chamber Music', 'Sonata', 'Symphony', 'Booty Bass', 'Primus', 'Porn Groove', 'Satire',
        'Slow Jam', 'Club', 'Tango', 'Samba', 'Folklore', 'Ballad', 'Power Ballad', 'Rhytmic Soul',
        'Freestyle', 'Duet', 'Punk Rock', 'Drum Solo', 'Acapella', 'Euro-House', 'Dance Hall',
        'Goa', 'Drum & Bass', 'Club-House', 'Hardcore', 'Terror', 'Indie', 'BritPop', 'Negerpunk',
        'Polsk Punk', 'Beat', 'Christian Gangsta Rap', 'Heavy Metal', 'Black Metal',
        'Crossover', 'Contemporary Christian', 'Christian Rock', 'Merengue', 'Salsa',
        'Thrash Metal', 'Anime', 'Jpop', 'Synthpop'},
    ID3_GENRES_HASH = {},
    YEAR_RE = '%d%d%d%d',
    MP3_RE = '%.mp3$',
    CHECK_ID3 = true
}
for k,v in ipairs(ApeTag.ID3_GENRES) do
    ApeTag.ID3_GENRES_HASH[v] = string.char(k - 1)
end
ApeTag.__index = ApeTag

--- Initialize an ApeTag with the given filename or table
-- This doesn't do any checking of the file or filename, not even whether or
-- not it exists.
-- @param filename string representing filename or table with the following
--                 possible keys (file, filename, check_id3)
-- @return ApeTag
function ApeTag:new(filename)
    local tag = {}
    if type(filename) == 'table' then
        tag.file = filename.file
        tag.filename = filename.filename
        tag.check_id3 = filename.check_id3 
    else
        tag.filename = filename
    end
    if not (tag.file or tag.filename) then
        error('ApeTag:new: no buffer or filename provided')
    end
    if type(tag.check_id3) == 'nil' then
        if tag.file then
            tag.check_id3 = ApeTag.CHECK_ID3
        elseif string.match(tag.filename, ApeTag.MP3_RE) then
            tag.check_id3 = true
        else
            tag.check_id3 = false
        end
    end
    
    setmetatable(tag, self)
    return tag
end

--- Whether there is already an ApeTag for the file
-- @return boolean
function ApeTag:exists()
    return self:has_tag()
end

--- The fields in the tag, or an empty ApeFields if the tag doesn't exist
-- @return ApeFields
function ApeTag:fields()
    if not self._fields then
        self:access_file('rb', function() self:get_fields() end)
    end
    return self._fields
end

--- String suitable for pretty printing of the tag's fields
-- @return string
function ApeTag:pretty_print()
    local noerr, fields = pcall(self.fields, self)
    if noerr then
        local items = {}
        for i,item in pairs(fields) do
            local value = ''
            for j,v in pairs(item) do
                if type(j) == 'number' then
                    if value ~= '' then
                        value = value .. ', '
                    end
                    value = value .. v
                end
            end
            table.insert(items, string.format('%s: %s', item.key, value))
        end
        table.sort(items)
        return(table.concat(items, "\n"))
    else
        return(fields)
    end
end

--- The raw binary string for the tag
-- @return string
function ApeTag:raw()
    self:has_tag()
    return (self._tag_header or '') .. (self._tag_data or '') .. (self._tag_footer or '') .. self:id3()
end

--- Remove the tag from the string
-- @return nil
function ApeTag:remove()
    if self:has_tag() or (string.len(self._id3) ~= 0) then
        self:access_file('r+b', function() io.truncate(self.file, self._tag_start) end)
    end
    for i,v in pairs({'_has_tag', '_fields', '_id3', '_tag_size', '_tag_start', 
            '_tag_data', '_tag_header', '_tag_footer', '_tag_item_count', '_file_size'}) do
        self[v] = nil
    end
end

--- Update the tag using the given function
-- @param f function which takes accepts value, the tag's fields, and modifies
--          those fields.  The fields must be modified directly, you cannot
--          return a new table with fields
-- @return ApeFields
function ApeTag:update(f)
    self:access_file('r+b', function()
        f(self:fields())
        self:validate_items()
        self:update_id3()
        self:update_ape()
        self:write_tag()
    end)
    return self:fields()
end

--- Make sure that a file object is available when running function
-- (*Private method*) If a filename was used instead of a file, open the file
-- before the running of function and close it afterward.
-- @param mode mode in which to open the file
-- @param f function to run after the file has been opened
-- @return f()
function ApeTag:access_file(mode, f)
    if not self.file then
        self.file = io.open(self.filename, mode)
        if not self.file then
            error("Cannot open file")
        end
        noerr, ret = pcall(f)
        self.file:close()
        self.file = nil
        if not noerr then
            error(ret)
        end
        return ret
    else
        return f()
    end
end

--- Get the file size for the file
-- (*Private method*)
-- @return number
function ApeTag:file_size()
    if not self._file_size then
        self:access_file('rb', function() 
            local pos = self.file:seek() 
            self._file_size = self.file:seek('end')
            self.file:seek('set', pos) 
        end)
    end
    return self._file_size
end

--- Parse the tag data to get the fields
-- (*Private method*)
-- @return nil
function ApeTag:get_fields()
    local fields = ApeFields:new()
    if self:has_tag() then
        local offset = 1
        local item = nil
        local tag_data_len = string.len(self._tag_data)
        local last_possible_item_start = tag_data_len - ApeItem.MIN_SIZE
        for i=1,self._tag_item_count do
            if offset > last_possible_item_start then
                error('End of tag reached but more items specified')
            end
            item, offset = ApeItem:parse(self._tag_data, offset)
            if fields[item.key] then
                error('Multiple items with the same key')
            end
            fields[item.key] = item
        end
        if offset ~= tag_data_len + 1 then
            error('Data remaining after specified number of items parsed')
        end
    end
    self._fields = fields
end

--- Parse the tag header and footer to get the basic tag information
-- (*Private method*)
-- @return nil
function ApeTag:get_tag_information()
    local id3len = string.len(self:id3())
    local file_size = self:file_size()
    if file_size < id3len + 64 then
        self._has_tag = false
        self._tag_start = file_size - id3len
        return
    end
    self.file:seek('end', -32-id3len)
    local tag_footer = self.file:read(32)
    if string.sub(tag_footer, 1, 12) ~= self.PREAMBLE then
        self.file:seek('set', 0)
        self._has_tag = false
        self._tag_start = file_size - id3len
        return
    end
    if string.sub(tag_footer, 22, 24) ~= self.FOOTER_FLAGS or (string.sub(tag_footer, 21, 21) ~= "\0" and string.sub(tag_footer, 21, 21) ~= "\1") then
        error('Tag footer flags incorrect')
    end
    self._tag_footer = tag_footer
    self._tag_size, self._tag_item_count = string.unpack(true, '44', string.sub(tag_footer, 13, 20))
    self._tag_size = self._tag_size + 32
    if self._tag_size < 64 then
        error('Tag size smaller than minimum size')
    end
    if self._tag_size + id3len > file_size then
        error('Tag size larger than possible')
    end
    if self._tag_size > self.MAX_SIZE then
        error('Tag size is larger than MAX_SIZE')
    end
    if self._tag_item_count > self.MAX_ITEM_COUNT then
        error('Item count is larger than than MAX_ITEM_COUNT')
    end
    if self._tag_item_count > (self._tag_size-64)/ApeItem.MIN_SIZE then
        error('Item count is larger than possible')
    end
    self._tag_start = self.file:seek('end', -self._tag_size - id3len)
    self._tag_header = self.file:read(32)
    self._tag_data = self.file:read(self._tag_size - 64)
    if string.sub(self._tag_header, 1, 12) ~= self.PREAMBLE or string.sub(self._tag_header, 22, 24) ~= self.HEADER_FLAGS or (string.sub(self._tag_header, 21, 21) ~= "\0" and string.sub(self._tag_header, 21, 21) ~= "\1") then
        error('Missing header')
    end
    local x = string.unpack(true, '4', string.sub(self._tag_header, 13, 16)) + 32
    if self._tag_size ~= x then
        error('Header and footer size does not match')
    end
    x = string.unpack(true, '4', string.sub(self._tag_header, 17, 20))
    if self._tag_item_count ~= x then
        error('Header and footer item count does not match')
    end
    self._has_tag = true
end

--- Check whether the file already has a tag
-- (*Private method*)
-- @return boolean
function ApeTag:has_tag()
    if type(self._has_tag) == 'nil' then
        self:access_file('rb', function() self:get_tag_information() end)
    end
    return self._has_tag
end

--- The raw ID3 data string for the tag
-- (*Private method*)
-- @return string
function ApeTag:id3()
    if not self._id3 then
        if (self:file_size() < 128) or (not self.check_id3) then
            self._id3 = ''
        else
            self.file:seek('end', -128)
            local data = self.file:read(128)
            if string.match(data, '^TAG') then
                self._id3 = data
            else
                self._id3 = ''
            end
        end
    end
    return self._id3
end

--- Update the tag information with the new fields
-- (*Private method*)
-- @return nil
function ApeTag:update_ape()
    local item_count = 0
    local items = {}
    for x,item in pairs(self:fields()) do
        item_count = item_count + 1
        table.insert(items, item:raw())
    end
    table.sort(items, function(a,b) return string.len(a) < string.len(b) or (string.len(a) == string.len(b) and a < b) end)
    self._tag_item_count = item_count
    self._tag_data = table.concat(items)
    self._tag_size = string.len(self._tag_data) + 64
    local base_start = self.PREAMBLE .. string.pack(true, '44', self._tag_size - 32, item_count)
    self._tag_header = base_start .. '\0' .. self.HEADER_FLAGS .. '\0\0\0\0\0\0\0\0'
    self._tag_footer = base_start .. '\0' .. self.FOOTER_FLAGS .. '\0\0\0\0\0\0\0\0'
    if item_count > self.MAX_ITEM_COUNT then
        error('Updated tag has too many items')
    end
    if self._tag_size > self.MAX_SIZE then
        error('Updated tag too large')
    end
end

--- Update the id3 string with the new fields
-- (*Private method*)
-- @return nil
function ApeTag:update_id3()
    if not self.check_id3 then
        self._id3 = ''
    elseif not (self._id3 == '' and self._has_tag) then
        local id3_fields = {title='', artist='', album='', year='', comment='', track='\0', genre='\255'}
        for key,value in pairs(self:fields()) do
            local key = string.sub(key, 2)
            if string.find(key, '^track') then
                local track = tonumber(value[1])
                if track ~= nil and track >= 0 and track <= 255 then
                    id3_fields.track = string.char(track)
                end
            elseif string.find(key, '^genre') then
                id3_fields.genre = self.ID3_GENRES_HASH[value[1]] or '\255'
            elseif key == 'date' then
                local year = string.match(value[1], self.YEAR_RE)
                if year ~= nil then
                    id3_fields.year = year
                end
            elseif id3_fields[key] then
                id3_fields[key] = value[1]
            end
        end
        self._id3 = 'TAG' .. string.padzr(id3_fields.title, 30) .. string.padzr(id3_fields.artist, 30) .. string.padzr(id3_fields.album, 30) .. string.padzr(id3_fields.year, 4) .. string.padzr(id3_fields.comment, 28) .. '\0' .. id3_fields.track .. id3_fields.genre
    end
end

--- Validate all of the items in the fields
-- (*Private method*)
-- @return nil
function ApeTag:validate_items()
    for key,item in pairs(self:fields()) do
        item:validate()
    end
end

--- Write the tag to the file
-- (*Private method*)
-- @return nil
function ApeTag:write_tag()
    self.file:seek('set', self._tag_start)
    self.file:write(self:raw())
    self._file_size = self.file:seek()
    io.truncate(self.file, self._file_size)
    self._has_tag = true
end


if arg and string.find(arg[0], 'apetag.lua') then
    for i,filename in ipairs(arg) do
        if i > 0 then
            print(filename)
            print(string.rep('-', string.len(filename)))
            print(ApeTag:new(filename):pretty_print())
            print('')
        end
    end
end 
