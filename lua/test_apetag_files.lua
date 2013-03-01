require('test_shared')

CHECK_ID3 = true

function tagname(file)
    return '../test-files/' .. file .. '.tag'
end

function tag(file)
    return ApeTag:new{filename=tagname(file), check_id3=CHECK_ID3}
end

function corrupt(file, msg)
    r, f = pcall(function() return tag(file):fields() end)
    assert(not r, 'No error raised, expected: ' .. msg)
    assert(string.find(f, msg, 1, true), 'Expected error: ' .. msg .. '\nReceived error: ' .. f)
    ASSERTIONS = ASSERTIONS + 2
end

function assert_has_field(file, field, values, flags)
    local i = tag(file):fields()[field]
    assert_equal(field, i.key)
    assert_equal(flags, i.flags)
    assert_arrays_equal(values, i)
end

function assert_files_equal(from, to, f)
    os.execute("cp " .. tagname(from) .. ' ' .. tagname('test'))
    f(tag('test'))
    local ret
    if _VERSION == 'Lua 5.1' then
      ret = 0
    else
      ret = true
    end
    assert_equal(ret, os.execute("cmp -s " .. tagname(to) .. ' ' .. tagname('test')))
    os.remove(tagname('test'))
end

function assert_update_raises(msg, f)
    os.execute("cp " .. tagname('good-empty') .. ' ' .. tagname('test'))
    r, errmsg = pcall(function() tag('test'):update(f) end)
    assert(not r, 'No error raised, expected: ' .. msg)
    assert(string.find(errmsg, msg, 1, true), 'Expected error: ' .. msg .. '\nReceived error: ' .. errmsg)
    ASSERTIONS = ASSERTIONS + 2
end

TestApeTag = {}

function TestApeTag.test_corrupt()
    corrupt("corrupt-count-larger-than-possible", "Item count is larger than possible")
    corrupt("corrupt-count-mismatch", "Header and footer item count does not match")
    corrupt("corrupt-count-over-max-allowed", "Item count is larger than than MAX_ITEM_COUNT")
    corrupt("corrupt-data-remaining", "Data remaining after specified number of items parsed")
    corrupt("corrupt-duplicate-item-key", "Multiple items with the same key")
    corrupt("corrupt-finished-without-parsing-all-items", "End of tag reached but more items specified")
    corrupt("corrupt-footer-flags", "Tag footer flags incorrect")
    corrupt("corrupt-header", "Missing header")
    corrupt("corrupt-item-flags-invalid", "Invalid item flags")
    corrupt("corrupt-item-length-invalid", "Invalid item length before taking key length into account")
    corrupt("corrupt-key-invalid", "Invalid ApeItem")
    corrupt("corrupt-key-too-short", "Invalid ApeItem")
    corrupt("corrupt-key-too-long", "Invalid ApeItem")
    corrupt("corrupt-min-size", "Tag size smaller than minimum size")
    corrupt("corrupt-next-start-too-large", "Invalid item length after taking key length into account")
    corrupt("corrupt-size-larger-than-possible", "Tag size larger than possible")
    corrupt("corrupt-size-mismatch", "Header and footer size does not match")
    corrupt("corrupt-size-over-max-allowed", "Tag size larger than possible")
    corrupt("corrupt-value-not-utf8", "Invalid ApeItem")
    corrupt("corrupt-missing-key-value-separator", "Missing key-value separator")
end

function TestApeTag.test_exists()
    assert_equal(tag('missing-ok'):exists(), false)
    assert_equal(tag('good-empty'):exists(), true)
    assert_equal(tag('good-empty-id3-only'):exists(), false)
    assert_equal(tag('good-empty-id3'):exists(), true)
end

function TestApeTag.test_fields()
    assert_tables_equal({}, tag('good-empty'):fields())
    assert_has_field('good-simple-1', 'name', {'value'}, 0)
    assert_tables_equal(tag('good-simple-1'):fields().Name, tag('good-simple-1'):fields().name)

    assert_has_field('good-many-items', '0n', {''}, 0)
    assert_has_field('good-many-items', '1n', {'a'}, 0)
    assert_has_field('good-many-items', '62n', {'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'}, 0)

    assert_has_field('good-multiple-values', 'name', {'va', 'ue'}, 0)
    assert_has_field('good-simple-1-ro-external', 'name', {'value'}, 5)
    assert_has_field('good-binary-non-utf8-value', 'name', {"v\129lue"}, 2)
end

function TestApeTag.test_remove()
    assert_files_equal('good-empty', 'missing-ok', function(tag) tag:remove() end)
    assert_files_equal('good-empty-id3', 'missing-ok', function(tag) tag:remove() end)
    assert_files_equal('good-empty-id3-only', 'missing-ok', function(tag) tag:remove() end)
    assert_files_equal('missing-10k', 'missing-10k', function(tag) tag:remove() end)
end

function TestApeTag.test_update()
    CHECK_ID3 = false
    assert_files_equal('good-empty', 'good-empty', function(tag) tag:update(function(fields) end) end)
    assert_files_equal('missing-ok', 'good-empty', function(tag) tag:update(function(fields) end) end)
    assert_files_equal('good-empty', 'good-simple-1', function(tag) tag:update(function(fields) fields.name = 'value' end) end)
    assert_files_equal('good-simple-1', 'good-empty', function(tag) tag:update(function(fields) fields.name = nil end) end)
    assert_files_equal('good-simple-1', 'good-empty', function(tag) tag:update(function(fields) fields.Name = nil end) end)
    assert_files_equal('good-empty', 'good-simple-1-ro-external', function(tag) tag:update(function(fields) fields.name = ApeItem:new('name', {'value'}, 5) end) end)
    assert_files_equal('good-empty', 'good-binary-non-utf8-value', function(tag) tag:update(function(fields) fields.name = ApeItem:new('name', {'v\129lue'}, 2) end) end)

    assert_files_equal('good-empty', 'good-many-items', function(tag) tag:update(function(fields)
      for i=0,62 do
        fields[i .. "n"] = string.rep("a", i)
      end
    end) end)

    assert_files_equal('good-empty', 'good-multiple-values', function(tag) tag:update(function(fields) fields.name = {'va', 'ue'} end) end)
    assert_files_equal('good-multiple-values', 'good-simple-1-uc', function(tag) tag:update(function(fields) fields.NAME = 'value' end) end)
    assert_files_equal('missing-ok', 'good-simple-1-utf8', function(tag) tag:update(function(fields) fields.name = 'v\195\130\195\149' end) end)

    assert_update_raises('Updated tag has too many items', function(fields)
      for i=0,64 do
        fields[i .. "n"] = string.rep("a", i)
      end
    end)
    assert_update_raises('Updated tag too large', function(fields) fields.xn = string.rep("a", 8118) end)
    assert_update_raises('Invalid ApeItem', function(fields) fields.n = 'a' end)
    assert_update_raises('Invalid ApeItem', function(fields) fields[string.rep("a", 256)] = 'a' end)
    assert_update_raises('Invalid ApeItem', function(fields) fields["v\0"] = 'a' end)
    assert_update_raises('Invalid ApeItem', function(fields) fields["v\31"] = 'a' end)
    assert_update_raises('Invalid ApeItem', function(fields) fields["v\129"] = 'a' end)
    assert_update_raises('Invalid ApeItem', function(fields) fields["v\255"] = 'a' end)
    assert_update_raises('Invalid ApeItem', function(fields) fields.tag = 'a' end)
    assert_update_raises('Invalid ApeItem', function(fields) fields.ab = 'v\129' end)
    assert_update_raises('Invalid ApeItem', function(fields) fields.name = ApeItem:new('name', {'value'}, 8) end)

    CHECK_ID3 = true

    assert_files_equal('missing-ok', 'good-empty-id3', function(tag) tag:update(function(fields) end) end)
    assert_files_equal('good-empty-id3-only', 'good-empty-id3', function(tag) tag:update(function(fields) end) end)

    assert_files_equal('good-empty-id3', 'good-simple-4', function(tag) tag:update(function(fields)
      fields.track = 1
      fields.genre = 'Game'
      fields.year = 1999
      fields.title = "Test Title"
      fields.artist = "Test Artist"
      fields.album = "Test Album"
      fields.comment = "Test Comment"
    end) end)

    assert_files_equal('good-empty-id3', 'good-simple-4-uc', function(tag) tag:update(function(fields)
      fields.Track = 1
      fields.Genre = 'Game'
      fields.Year = 1999
      fields.Title = "Test Title"
      fields.Artist = "Test Artist"
      fields.Album = "Test Album"
      fields.Comment = "Test Comment"
    end) end)

    assert_files_equal('good-empty-id3', 'good-simple-4-date', function(tag) tag:update(function(fields)
      fields.track = 1
      fields.genre = 'Game'
      fields.date = '12/31/1999'
      fields.title = "Test Title"
      fields.artist = "Test Artist"
      fields.album = "Test Album"
      fields.comment = "Test Comment"
    end) end)

    assert_files_equal('good-empty-id3', 'good-simple-4-long', function(tag) tag:update(function(fields)
      fields.track = 1
      fields.genre = 'Game'
      fields.year = 19991999
      fields.title = string.rep("Test Title", 5)
      fields.artist = string.rep("Test Artist", 5)
      fields.album = string.rep("Test Album", 5)
      fields.comment = string.rep("Test Comment", 5)
    end) end)

end

run_tests('test_apetag_files.lua')
