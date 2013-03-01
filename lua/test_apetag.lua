require('test_shared')

EMPTY_APE_TAG = "APETAGEX\208\7\0\0 \0\0\0\0\0\0\0\0\0\0\160\0\0\0\0\0\0\0\0APETAGEX\208\7\0\0 \0\0\0\0\0\0\0\0\0\0\128\0\0\0\0\0\0\0\0TAG\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\255"
EXAMPLE_APE_TAG = "APETAGEX\208\7\0\0\176\0\0\0\6\0\0\0\0\0\0\160\0\0\0\0\0\0\0\0\1\0\0\0\0\0\0\0Track\0001\4\0\0\0\0\0\0\0Date\0002007\9\0\0\0\0\0\0\0Comment\0XXXX-0000\11\0\0\0\0\0\0\0Title\0Love Cheese\11\0\0\0\0\0\0\0Artist\0Test Artist\22\0\0\0\0\0\0\0Album\0Test Album\0Other AlbumAPETAGEX\208\7\0\0\176\0\0\0\6\0\0\0\0\0\0\128\0\0\0\0\0\0\0\0TAGLove Cheese\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0Test Artist\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0Test Album\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0002007XXXX-0000\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\1\255"
EXAMPLE_APE_TAG2 = "APETAGEX\208\7\0\0\153\0\0\0\5\0\0\0\0\0\0\160\0\0\0\0\0\0\0\0\4\0\0\0\0\0\0\0Blah\0Blah\4\0\0\0\0\0\0\0Date\0002007\9\0\0\0\0\0\0\0Comment\0XXXX-0000\11\0\0\0\0\0\0\0Artist\0Test Artist\22\0\0\0\0\0\0\0Album\0Test Album\0Other AlbumAPETAGEX\208\7\0\0\153\0\0\0\5\0\0\0\0\0\0\128\0\0\0\0\0\0\0\0TAG\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0Test Artist\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0Test Album\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0002007XXXX-0000\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\255"
EMPTY_APE_ONLY_TAG = string.sub(EMPTY_APE_TAG, 1,-129)
EXAMPLE_APE_ONLY_TAG = string.sub(EXAMPLE_APE_TAG, 1,-129)
EXAMPLE_APE_ONLY_TAG2 =  string.sub(EXAMPLE_APE_TAG2, 1,-129)
EXAMPLE_APE_FIELDS = {Track={"1"}, Comment={"XXXX-0000"}, Album={"Test Album", "Other Album"}, Title={"Love Cheese"}, Artist={"Test Artist"}, Date={"2007"}}
EXAMPLE_APE_FIELDS2 = {Blah={"Blah"}, Comment={"XXXX-0000"}, Album={"Test Album", "Other Album"}, Artist={"Test Artist"}, Date={"2007"}}
EXAMPLE_APE_TAG_PRETTY_PRINT = "Album: Test Album, Other Album\nArtist: Test Artist\nComment: XXXX-0000\nDate: 2007\nTitle: Love Cheese\nTrack: 1"
FILENAME = 'test.apetag'

function AT(t)
    if getmetatable(t) == ApeTag then
        return t
    else
        return ApeTag:new(t)
    end
end

function SIZE(t)
    return AT(t):file_size()
end

function table.replace(start, finish)
    for k,v in pairs(start) do
        start[k] = nil
    end
    for k,v in pairs(finish) do
        start[k] = v
    end
    return start
end

function write_tag_file(data, changes)
    local f = io.open(FILENAME, 'wb')
    f:write(data)
    if changes then
        for i,change in ipairs(changes) do
            f:seek('set', change.at)
            f:write(change.write)
        end
    end
    f:close()
    return io.open(FILENAME, 'r+b')
end

function item_test(tag)
    local t = tag
    local c = t.check_id3
    local id3_size = 0
    if c then
        id3_size = 128
    end
    assert_equal(AT(t):exists(), false)
    local size = SIZE(t)
    assert_equal(AT(t):raw(), '')
    assert_equal(SIZE(t), size)
    assert_equal(AT(t):remove(), nil)
    assert_equal(SIZE(t), size)
    assert_tables_equal(AT(t):fields(),{})
    assert_equal(SIZE(t), size)
    assert_arrays_equal(AT(t):update(function(f) end),{})
    size = size + 64 + id3_size
    assert_equal(SIZE(t), size)
    assert_equal(AT(t):exists(), true)
    assert_equal(SIZE(t), size)
    assert_equal(AT(t):raw(), c and EMPTY_APE_TAG or EMPTY_APE_ONLY_TAG)
    assert_equal(SIZE(t), size)
    assert_tables_equal(AT(t):fields(),{})
    assert_equal(SIZE(t), size)
    assert_arrays_equal(AT(t):update(function(f) end),{})
    assert_equal(SIZE(t), size)
    assert_equal(AT(t):remove(), nil)
    size = size - 64 - id3_size
    assert_equal(SIZE(t), size)
    assert_arrays_equal(AT(t):update(function(f) table.replace(f, EXAMPLE_APE_FIELDS) end), EXAMPLE_APE_FIELDS)
    size = size + 208 + id3_size
    assert_equal(SIZE(t), size)
    assert_equal(AT(t):pretty_print(), EXAMPLE_APE_TAG_PRETTY_PRINT)
    assert_equal(SIZE(t), size)
    assert_equal(AT(t):exists(), true)
    assert_equal(SIZE(t), size)
    assert_equal(AT(t):raw(), c and EXAMPLE_APE_TAG or EXAMPLE_APE_ONLY_TAG)
    assert_equal(SIZE(t), size)
    assert_arrays_equal(AT(t):fields(), EXAMPLE_APE_FIELDS)
    assert_equal(SIZE(t), size)
    assert_arrays_equal(AT(t):update(function(f) end), EXAMPLE_APE_FIELDS)
    assert_equal(SIZE(t), size)
    assert_arrays_equal(AT(t):update(function(f) f.Track = nil f.Title = nil f.Blah = 'Blah' end), EXAMPLE_APE_FIELDS2)
    size = size - 23
    assert_equal(SIZE(t), size)
    assert_equal(AT(t):exists(), true)
    assert_equal(SIZE(t), size)
    assert_equal(AT(t):raw(), c and EXAMPLE_APE_TAG2 or EXAMPLE_APE_ONLY_TAG2)
    assert_equal(SIZE(t), size)
    assert_arrays_equal(AT(t):fields(), EXAMPLE_APE_FIELDS2)
    assert_equal(SIZE(t), size)
    assert_arrays_equal(AT(t):update(function(f) end), EXAMPLE_APE_FIELDS2)
    assert_equal(SIZE(t), size)
    assert_equal(AT(t):remove(), nil)
    size = size - 185 - id3_size
    assert_equal(SIZE(t), size)
    assert_equal(AT(t):raw(), '')
    assert_equal(SIZE(t), size)
end

TestApeTag = {}

-- Test to make sure different file sizes don't cause any problems.
-- Use both files and filenames.
-- Use both a single ApeTag for each test and a new ApeTag for each to test
-- that ApeTag state is created and saved correctly.
function TestApeTag.test_suite_with_many_permutations()
    local f
    for i,x in ipairs{0,1,63,64,65,127,128,129,191,192,193,8191,8192,8193} do
        for j,check_id3 in ipairs{true, false} do
            f = write_tag_file(string.rep(' ', x))
            item_test{file=f, check_id3=check_id3}
            item_test(ApeTag:new{file=f, check_id3=check_id3})
            f:close()
            item_test{filename=FILENAME, check_id3=check_id3}
            item_test(ApeTag:new{filename=FILENAME, check_id3=check_id3})
            os.remove(FILENAME)
        end
    end
end

-- Test ApeItem methods
function TestApeTag.test_ape_item_validations()
    local ai = ApeItem:new('BlaH', {'BlAh'})
    -- Test valid defaults
    assert_arrays_equal(ai, {'BlAh'})
    assert_equal(ai.flags, 0)
    assert_equal(ai.key, 'BlaH')
    assert_equal(ai:raw(), '\4\0\0\0\0\0\0\0BlaH\0BlAh')
    assert_no_error(function() ai:validate() end)
    
    -- Test flags
    for i,x in ipairs{1,2,3,4,5,6,7} do
        ai.flags = x
        assert_no_error(function() ai:validate() end)
        assert_equal(ai:raw(), '\4\0\0\0' .. string.pack(false, '4', ai.flags) .. 'BlaH\0BlAh')
    end
    for i,x in ipairs{-100, -1, 8, 9, 100} do
        ai.flags = x
        assert_error(function() ai:validate() end)
    end
    ai.flags = 0
    assert_no_error(function() ai:validate() end)
    
    -- Test keys
    for i=0,31 do
        ai.key = string.pack(true, '1', i) .. '  '
        assert_error(function() ai:validate() end)
    end
    for i=128,255 do
        ai.key = string.pack(true, '1', i) .. '  '
        assert_error(function() ai:validate() end)
    end
    for i,v in pairs{1, '', 'x',  string.rep('x', 256), 'id3', 'tag', 'oggs', 'mp+'} do
        ai.key = v
        assert_error(function() ai:validate() end)
    end
    for i=32,127 do
        ai.key = string.pack(true, '1', i) .. '  '
        assert_no_error(function() ai:validate() end)
    end
    for i,v in pairs{'id3', 'tag', 'oggs', 'mp+'} do
        ai.key = v .. ' '
        assert_no_error(function() ai:validate() end)
    end
    for i,v in pairs{'xx',  string.rep('x', 255)} do
        ai.key = v
        assert_no_error(function() ai:validate() end)
    end
    ai.key = 'BlaH'
    assert_no_error(function() ai:validate() end)
    
    -- Test raw with different values
    assert_equal(ai:raw(), '\4\0\0\0\0\0\0\0BlaH\0BlAh')
    table.insert(ai, 'XYZ')
    assert_equal(ai:raw(), '\8\0\0\0\0\0\0\0BlaH\0BlAh\0XYZ')
    
    -- Test invalid value
    table.insert(ai, '\255')
    assert_error(function() ai:validate() end)
end

function TestApeTag.test_ape_item_new()
    local ai = ApeItem:new('BlaH', {'BlAh'})
    -- Test with ApeItem
    local ac = ApeItem:new('BlaH', ai)
    assert_equal(ai.flags, ac.flags)
    assert_equal(ai.key, ac.key)
    assert_tables_equal(ai, ac)
    
    -- Test with table
    ac = ApeItem:new('BlaH', {})
    assert_equal(0, ac.flags)
    assert_equal('BlaH', ac.key)
    assert_arrays_equal({}, ac)
    assert_equal(ac:raw(), '\0\0\0\0\0\0\0\0BlaH\0')
    
    -- Test with string
    ac = ApeItem:new('BlaH', 'Blah')
    assert_equal(0, ac.flags)
    assert_equal('BlaH', ac.key)
    assert_arrays_equal({'Blah'}, ac)
    assert_equal(ac:raw(), '\4\0\0\0\0\0\0\0BlaH\0Blah')
    
    -- Test with number and flags
    ac = ApeItem:new('BlaH', 1, 1)
    assert_equal(1, ac.flags)
    assert_equal('BlaH', ac.key)
    assert_arrays_equal({'1'}, ac)
    assert_equal(string.len(ac:raw()), string.len('\1\0\0\0\0\0\0\0BlaH\0001'))
    assert_equal(ac:raw(), '\1\0\0\0\0\0\0\1BlaH\0001')
    
    -- Test with table with numbers and strings
    ac = ApeItem:new('BlaH', {1, 'a', 2, 'b'}, 7)
    assert_equal(7, ac.flags)
    assert_equal('BlaH', ac.key)
    assert_arrays_equal({'1', 'a', '2', 'b'}, ac)
    assert_equal(ac:raw(), '\7\0\0\0\0\0\0\7BlaH\0001\0a\0002\0b')
end

function TestApeTag.test_ape_item_parse()
    local data = "\8\0\0\0\0\0\0\7BlaH\0BlAh\0XYZ"
    -- Test simple item parsing
    local ai, offset = ApeItem:parse(data, 1)
    assert_equal(7, ai.flags)
    assert_equal(offset - 1, string.len(data))
    assert_equal('BlaH', ai.key)
    assert_arrays_equal({'BlAh', 'XYZ'}, ai)
    
    -- Test parsing with bad key
    assert_error(function() ApeItem:parse('\0\0\0\0\0\0\0\7x\0', 1) end)
    
    -- Test parsing with no key end
    assert_error(function() ApeItem:parse(string.sub(data, 1, -2), 1) end)
    
    -- Test parsing with bad start value
    assert_error(function() ApeItem:parse(data, 2) end)
    
    -- Test parsing bad flags
    assert_error(function() ApeItem:parse("\8\0\0\0\0\0\0\8BlaH\0BlAh\0XYZ", 1) end)
    
    -- Test parsing with length longer than string
    assert_error(function() ApeItem:parse("\9\0\0\0\0\0\0\0BlaH\0BlAh\0XYZ", 1) end)
    
    -- Test parsing with length shorter than string gives valid ApeItem
    -- Of course, the next item will probably be parsed incorrectly
    ai, offset = ApeItem:parse("\3\0\0\0\0\0\0\7BlaH\0BlAh\0XYZ", 1)
    assert_equal(7, ai.flags)
    assert_equal(offset, 17)
    assert_equal('BlaH', ai.key)
    assert_arrays_equal({'BlA'}, ai)
    
    -- Test parsing gets correct key end
    ai, offset = ApeItem:parse("\3\0\0\0\0\0\0\7BlaH3BlAh\0XYZ", 1)
    assert_equal(7, ai.flags)
    assert_equal(offset, 22)
    assert_equal('BlaH3BlAh', ai.key)
    assert_arrays_equal({'XYZ'}, ai)
   
    -- Test parsing of invalid UTF8
    assert_error(function() ApeItem:parse("\10\0\0\0\0\0\0\0BlaH\0BlAh\0XYZ\0\255", 1) end)
end

function TestApeTag.test_bad_tags()
    -- Test default case OK
    assert_no_error(function() ApeTag:new{file=write_tag_file(EMPTY_APE_TAG)}:raw() end)

    -- Test read only tags work
    assert_no_error(function() ApeTag:new{file=write_tag_file(EMPTY_APE_TAG, {{at=20, write='\1'}})}:raw() end)
    assert_no_error(function() ApeTag:new{file=write_tag_file(EMPTY_APE_TAG, {{at=52, write='\1'}})}:raw() end)

    -- Test other flag values don't work
    for i=2,255 do
        assert_error(function() ApeTag:new{file=write_tag_file(EMPTY_APE_TAG, {{at=20, write=string.char(i)}})}:raw() end)
        assert_error(function() ApeTag:new{file=write_tag_file(EMPTY_APE_TAG, {{at=52, write=string.char(i)}})}:raw() end)
        assert_error(function() ApeTag:new{file=write_tag_file(EMPTY_APE_TAG, {{at=20, write=string.char(i)}, {at=52, write=string.char(i)}})}:raw() end)
    end
    
    -- Test footer size less than minimum size (32)
    assert_error(function() ApeTag:new{file=write_tag_file(EMPTY_APE_TAG, {{at=44, write='\31'}})}:raw() end)
    assert_error(function() ApeTag:new{file=write_tag_file(EMPTY_APE_TAG, {{at=44, write='\0'}})}:raw() end)
    
    -- Test tag size > 8192, when both larger than file and smaller than file
    assert_error(function() ApeTag:new{file=write_tag_file(EMPTY_APE_TAG, {{at=44, write='\225\31'}})}:raw() end)
    assert_error(function() ApeTag:new{file=write_tag_file(string.rep('', 8192) .. EMPTY_APE_TAG, {{at=44, write='\225\31'}})}:raw() end)
    
    -- Test unmatching header and footer tag size, with footer size wrong
    assert_error(function() ApeTag:new{file=write_tag_file(EMPTY_APE_TAG, {{at=44, write='\33'}})}:raw() end)
    
    -- Test matching header and footer but size to large for file
    assert_error(function() ApeTag:new{file=write_tag_file(EMPTY_APE_TAG, {{at=44, write='\33'}, {at=12, write='\33'}})}:raw() end)
    
    -- Test that header and footer size isn't too large for file, but doesn't find the header
    assert_error(function() ApeTag:new{file=write_tag_file(' ' .. EMPTY_APE_TAG, {{at=45, write='\33'}, {at=13, write='\33'}})}:raw() end)
    
    -- Test unmatching header and footer tag size, with header size wrong
    assert_error(function() ApeTag:new{file=write_tag_file(' ' .. EMPTY_APE_TAG, {{at=45, write='\32'}, {at=13, write='\33'}})}:raw() end)
    
    -- Test item count greater than maximum (64)
    assert_error(function() ApeTag:new{file=write_tag_file(EMPTY_APE_TAG, {{at=48, write='\65'}})}:raw() end)
    
    -- Test item count greater than possible given tag size
    assert_error(function() ApeTag:new{file=write_tag_file(EMPTY_APE_TAG, {{at=48, write='\1'}})}:raw() end)
    
    -- Test unmatched header and footer item count, header size wrong
    assert_error(function() ApeTag:new{file=write_tag_file(EMPTY_APE_TAG, {{at=16, write='\1'}})}:raw() end)
    
    -- Test unmatched header and footer item count, footer size wrong
    assert_error(function() ApeTag:new{file=write_tag_file(EXAMPLE_APE_TAG, {{at=208-16, write='\5'}})}:raw() end)
    
    -- Test missing/corrupt header
    assert_error(function() ApeTag:new{file=write_tag_file(EMPTY_APE_TAG, {{at=0, write='\0'}})}:raw() end)
    
    -- Test parsing bad first item size
    assert_error(function() ApeTag:new{file=write_tag_file(EXAMPLE_APE_TAG, {{at=32, write='\2'}})}:fields() end)
    
    -- Test parsing bad first item invalid key
    assert_error(function() ApeTag:new{file=write_tag_file(EXAMPLE_APE_TAG, {{at=40, write='\0'}})}:fields() end)
    
    -- Test parsing bad first item key end
    assert_error(function() ApeTag:new{file=write_tag_file(EXAMPLE_APE_TAG, {{at=40, write='\1'}})}:fields() end)
    
    -- Test parsing bad second item length too long
    assert_error(function() ApeTag:new{file=write_tag_file(EXAMPLE_APE_TAG, {{at=47, write='\255'}})}:fields() end)
    
    -- Test parsing case insensitive duplicate keys 
    assert_error(function() ApeTag:new{file=write_tag_file(EXAMPLE_APE_TAG, {{at=40, write='Album'}})}:fields() end)
    assert_error(function() ApeTag:new{file=write_tag_file(EXAMPLE_APE_TAG, {{at=40, write='ALBUM'}})}:fields() end)
    assert_error(function() ApeTag:new{file=write_tag_file(EXAMPLE_APE_TAG, {{at=40, write='album'}})}:fields() end)
    
    -- Test parsing incorrect item counts
    assert_error(function() ApeTag:new{file=write_tag_file(EXAMPLE_APE_TAG, {{at=16, write='\5'}, {at=192, write='\5'}})}:fields() end)
    assert_error(function() ApeTag:new{file=write_tag_file(EXAMPLE_APE_TAG, {{at=16, write='\7'}, {at=192, write='\7'}})}:fields() end)
    
    -- Test updating works in a case insensitive manner
    assert_arrays_equal({'blah'}, ApeTag:new{file=write_tag_file(EXAMPLE_APE_TAG)}:update(function(f) f.album='blah' end).ALBUM)
    assert_arrays_equal({'blah'}, ApeTag:new{file=write_tag_file(EXAMPLE_APE_TAG)}:update(function(f) f.ALBUM='blah' end).album)
    assert_arrays_equal({'blah'}, ApeTag:new{file=write_tag_file(EXAMPLE_APE_TAG)}:update(function(f) f.ALbUM='blah' end).albuM)
    
    -- Test updating with an invalid value
    assert_error(function() ApeTag:new{file=write_tag_file(EMPTY_APE_TAG)}:update(function(f) f.album='\254' end) end)
    
    -- Test updating with an invalid key
    assert_error(function() ApeTag:new{file=write_tag_file(EMPTY_APE_TAG)}:update(function(f) f.x='' end) end)
    
    -- Test updating with too many items
    assert_error(function() ApeTag:new{file=write_tag_file(EMPTY_APE_TAG)}:update(function(f) for i=1,65 do f[string.format('blah%s', i)] = '' end end) end)
    -- Test updating with just enough items
    assert_no_error(function() ApeTag:new{file=write_tag_file(EMPTY_APE_TAG)}:update(function(f) for i=1,64 do f[string.format('blah%s', i)] = '' end end) end)
    
    -- Test updating with too large a tag
    assert_error(function() ApeTag:new{file=write_tag_file(EMPTY_APE_TAG)}:update(function(f) f.xx = string.rep(' ', 8118) end) end)
    -- Test updating with a just large enough tag
    assert_no_error(function() ApeTag:new{file=write_tag_file(EMPTY_APE_TAG)}:update(function(f) f.xx = string.rep(' ', 8117) end) end)
    
    os.remove(FILENAME)
end

function TestApeTag.test_check_id3()
    local file=write_tag_file('')
    assert_equal(0, ApeTag:new{file=file}:file_size())
    -- Test ApeTag defaults to adding id3s on file objects without ape tags
    ApeTag:new{file=file}:update(function(f) end)
    assert_equal(192, ApeTag:new{file=file}:file_size())
    -- Test ApeTag doesn't if not checking id3s and and id3 is present
    ApeTag:new{file=file, check_id3=false}:remove()
    assert_equal(192, ApeTag:new{file=file}:file_size())
    -- Test ApeTag doesn't add id3s if ape tag exists but id3 does not
    io.truncate(file, 64)
    assert_equal(64, ApeTag:new{file=file}:file_size())
    ApeTag:new{file=file}:update(function(f) end)
    assert_equal(64, ApeTag:new{file=file}:file_size())
    ApeTag:new{file=file}:remove()
    assert_equal(0, ApeTag:new{file=file}:file_size())
    
    -- Test ApeTag without checking doesn't add id3
    ApeTag:new{file=file, check_id3=false}:update(function(f) end)
    assert_equal(64, ApeTag:new{file=file}:file_size())
    ApeTag:new{file=file}:remove()
    assert_equal(0, ApeTag:new{file=file}:file_size())
    
    -- Test ApeTag with explicit check_id3 argument works
    ApeTag:new{file=file, check_id3=true}:update(function(f) end)
    assert_equal(192, ApeTag:new{file=file}:file_size())
    ApeTag:new{file=file}:update(function(f) end)
    assert_equal(192, ApeTag:new{file=file}:file_size())
    ApeTag:new{file=file}:remove()
    assert_equal(0, ApeTag:new{file=file}:file_size())
    
    -- Test whether check_id3 class variable works
    ApeTag.CHECK_ID3 = false
    ApeTag:new{file=file}:update(function(f) end)
    assert_equal(64, ApeTag:new{file=file}:file_size())
    ApeTag:new{file=file}:remove()
    assert_equal(0, ApeTag:new{file=file}:file_size())
    ApeTag.CHECK_ID3 = true
    
    file:close()
    
    -- Test non-mp3 filename defaults to no id3
    local filename = FILENAME
    ApeTag:new(filename):update(function(f) end)
    assert_equal(64, ApeTag:new(filename):file_size())
    ApeTag:new(filename):remove()
    assert_equal(0, ApeTag:new(filename):file_size())
    os.remove(filename)
    
    -- Test mp3 filename defaults to id3
    filename = filename .. '.mp3'
    io.open(filename, 'wb'):close()
    ApeTag:new(filename):update(function(f) end)
    assert_equal(192, ApeTag:new(filename):file_size())
    ApeTag:new(filename):remove()
    assert_equal(0, ApeTag:new(filename):file_size())
    os.remove(filename)
end

run_tests('test_apetag.lua')
