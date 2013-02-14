#!/usr/bin/env io

doFile("apetag.io")

t := UnitTest clone

test_file_ext := ".tag"
  
tagName := method(name,
  "../test-files/" .. name .. if(name == "test",
    test_file_ext,
    ".tag"
  )
)

tag := method(name,
  ApeTag withFile(tagName(name))
)

assertException := method(msg,
  e := try(call evalArgAt(1))
  if(e == nil,
    Exception raise("Exception not raised: #{msg}" interpolate)
  )
  if(e error containsSeq(msg) == false,
    msg println
    e error println
    e raise
  )
)

withTestFile := method(name,
  File with(tagName("test")) remove
  File with(tagName("test")) create
  File with(tagName(name)) copyToPath(tagName("test"))
  call evalArgAt(1)
  File with(tagName("test")) remove
)

corrupt := method(name, msg,
  assertException(msg, tag(name) fields)
)

assertUpdateRaises := method(name, msg,
  withTestFile(name,
    assertException(msg, call evalArgAt(2) update)
  )
)

assertAddItemRaises := method(msg,
  withTestFile("missing-ok",
    assertException(msg, call evalArgAt(1))
  )
)

assertFilesEqual := method(name1, name2,
  withTestFile(name1,
    call evalArgAt(2)
    t assertTrue(File with(tagName("test")) openForReading readToEnd == File with(tagName(name2)) openForReading readToEnd)
  )
)

corrupt("corrupt-count-larger-than-possible", "tag item count larger than possible")
corrupt("corrupt-count-mismatch", "header item count does not match footer item count")
corrupt("corrupt-count-over-max-allowed", "tag item count larger than maximum allowed")
corrupt("corrupt-data-remaining", "data remaining after specified number of items parsed")
corrupt("corrupt-duplicate-item-key", "duplicate item key")
corrupt("corrupt-finished-without-parsing-all-items", "end of tag reached without parsing all items")
corrupt("corrupt-footer-flags", "bad APE footer flags")
corrupt("corrupt-header", "missing or corrupt tag header")
corrupt("corrupt-item-flags-invalid", "invalid item flags")
corrupt("corrupt-item-length-invalid", "invalid item length")
corrupt("corrupt-key-invalid", "invalid item key ")
corrupt("corrupt-key-too-short", "item key too short")
corrupt("corrupt-key-too-long", "item key too long")
corrupt("corrupt-min-size", "tag size smaller than minimum size")
corrupt("corrupt-missing-key-value-separator", "missing key-value separator")
corrupt("corrupt-next-start-too-large", "invalid item length")
corrupt("corrupt-size-larger-than-possible", "tag size larger than possible")
corrupt("corrupt-size-mismatch", "header size does not match footer size")
corrupt("corrupt-size-over-max-allowed", "tag size larger than maximum allowed")
corrupt("corrupt-value-not-utf8", "non-UTF8 character found in item value")

t assertFalse(tag("missing-ok") hasId3)
t assertFalse(tag("good-empty") hasId3)
t assertTrue(tag("good-empty-id3-only") hasId3)
t assertTrue(tag("good-empty-id3") hasId3)

t assertFalse(tag("missing-ok") hasApe)
t assertTrue(tag("good-empty") hasApe)
t assertFalse(tag("good-empty-id3-only") hasApe)
t assertTrue(tag("good-empty-id3") hasApe)

t assertEquals(tag("missing-ok") filename, "../test-files/missing-ok.tag")

t assertEquals(tag("good-empty") fields slotNames, list)
t assertEquals(tag("good-simple-1") fields slotNames, list("name"))
t assertEquals(tag("good-simple-1") fields name, list("value"))
t assertEquals(tag("good-simple-1") fields Name, list("value"))

t assertEquals(tag("good-many-items") fields slotNames size, 63)
t assertEquals(tag("good-many-items") fields getSlot("0n"), list(""))
t assertEquals(tag("good-many-items") fields getSlot("1n"), list("a"))
t assertEquals(tag("good-many-items") fields getSlot("62n"), list("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"))

t assertEquals(tag("good-multiple-values") fields slotNames, list("name"))
t assertEquals(tag("good-multiple-values") fields name, list("va", "ue"))

t assertEquals(tag("good-empty") items, list)
t assertEquals(tag("good-simple-1") items size, 1)
t assertEquals(tag("good-simple-1") items at(0) key, "name")
t assertEquals(tag("good-simple-1") items at(0) values, list("value"))
t assertEquals(tag("good-simple-1") items at(0) readOnly, false)
t assertEquals(tag("good-simple-1") items at(0) flags, 0)

t assertEquals(tag("good-simple-1-ro-external") items size, 1)
t assertEquals(tag("good-simple-1-ro-external") items at(0) readOnly, true)
t assertEquals(tag("good-simple-1-ro-external") items at(0) flags, 2)

t assertEquals(tag("good-binary-non-utf8-value") items at(0) values, list("v" .. (0x81 asCharacter) .. "lue"))
t assertEquals(tag("good-binary-non-utf8-value") items at(0) readOnly, false)
t assertEquals(tag("good-binary-non-utf8-value") items at(0) flags, 1)

items := tag("good-many-items") items sortBy(block(a,b, a values at(0) < b values at(0)))
t assertEquals(items size, 63)
t assertEquals(items at(0) key, "0n")
t assertEquals(items at(0) values, list(""))
t assertEquals(items at(1) key, "1n")
t assertEquals(items at(1) values, list("a"))
t assertEquals(items at(62) key, "62n")
t assertEquals(items at(62) values, list("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"))

t assertEquals(tag("good-multiple-values") items size, 1)
t assertEquals(tag("good-multiple-values") items at(0) key, "name")
t assertEquals(tag("good-multiple-values") items at(0) values, list("va", "ue"))

t assertEquals(ApeTag withFile(File with(tagName("good-simple-1")) openForReading) fields slotNames, list("name"))
t assertEquals(ApeTag withFile(File with(tagName("good-simple-1")) openForReading) fields name, list("value"))

assertFilesEqual("good-empty", "missing-ok", tag("test") removeTag)
assertFilesEqual("good-empty-id3", "missing-ok", tag("test") removeTag)
assertFilesEqual("good-empty-id3-only", "missing-ok", tag("test") removeTag)
assertFilesEqual("missing-10k", "missing-10k", tag("test") removeTag)
assertFilesEqual("good-empty-id3", "missing-ok", ApeTag withFile(File with(tagName("test")) openForReading) removeTag)

assertFilesEqual("good-empty", "good-empty", tag("test") update)
assertFilesEqual("missing-ok", "good-empty", tag("test") update)
assertFilesEqual("good-empty", "good-simple-1", tag("test") addItem("name", "value") update)
assertFilesEqual("good-simple-1", "good-empty", tag("test") removeItem("name") update)
assertFilesEqual("good-simple-1", "good-empty", tag("test") removeItem("Name") update)
assertFilesEqual("good-empty", "good-simple-1-ro-external", tag("test") addItem("name", "value", 2, true) update)
assertFilesEqual("good-empty", "good-binary-non-utf8-value", tag("test") addItem("name", list("v" .. (0x81 asCharacter) .. "lue"), 1) update)

assertFilesEqual("good-empty", "good-many-items",
  tg := tag("test")
  for(i, 0, 62, tg addItem("#{i}n" interpolate, "a" repeated(i)))
  tg update
)
assertFilesEqual("missing-ok", "good-multiple-values", tag("test") addItem("name", list("va", "ue")) update)
assertFilesEqual("good-multiple-values", "good-simple-1-uc", tag("test") addItem("NAME", "value") update)
assertFilesEqual("missing-ok", "good-simple-1-utf8", tag("test") addItem("name", list(118, 0xc3, 0x82, 0xc3, 0x95) map(asCharacter) join) update)

assertUpdateRaises("missing-ok", "tag has more than max allowed items",
  tg := tag("test")
  for(i, 0, 64, tg addItem("#{i}n" interpolate, "a" repeated(i)))
  tg
)

assertUpdateRaises("missing-ok", "tag is larger than max allowed size", tag("test") addItem("xn", "a" repeated(8118)))

assertAddItemRaises("item key too short", tag("test") addItem("n", "a"))
assertAddItemRaises("item key too long", tag("test") addItem("n" repeated(256), "a"))
assertAddItemRaises("invalid item key", tag("test") addItem(list(118, 0) map(asCharacter) join, "a"))
assertAddItemRaises("invalid item key", tag("test") addItem(list(118, 0x1f) map(asCharacter) join, "a"))
assertAddItemRaises("invalid item key", tag("test") addItem(list(118, 0x80) map(asCharacter) join, "a"))
assertAddItemRaises("invalid item key", tag("test") addItem(list(118, 0xff) map(asCharacter) join, "a"))
assertAddItemRaises("invalid item key", tag("test") addItem("tag", "a"))
assertAddItemRaises("non-UTF8 character found in item value", tag("test") addItem("ab", list(118, 0xff) map(asCharacter) join))
assertAddItemRaises("invalid item type", tag("test") addItem("name", "value", 5))

assertFilesEqual("good-empty", "good-simple-1",
  file := File with(tagName("test")) openForUpdating
  ApeTag withFile(file) addItem("name", "value") update
  file close
)


assertFilesEqual("missing-ok", "good-empty", tag("test") update)

test_file_ext = ".mp3"
assertFilesEqual("missing-ok", "good-empty-id3", tag("test") update)
assertFilesEqual("missing-ok", "good-empty",
  tg := tag("test")
  tg checkId3 = false
  tg update
)

test_file_ext = ".tag"
assertFilesEqual("missing-ok", "good-empty-id3",
  tg = tag("test")
  tg checkId3 = true
  tg update
)
assertFilesEqual("good-empty-id3-only", "good-empty-id3", tag("test") update)

assertFilesEqual("good-empty-id3", "good-simple-4", tag("test") addItem("track", "1") addItem("genre", "Game") addItem("year", "1999") addItem("title", "Test Title") addItem("artist", "Test Artist") addItem("album", "Test Album") addItem("comment", "Test Comment") update)
assertFilesEqual("good-empty-id3", "good-simple-4-uc", tag("test") addItem("Track", "1") addItem("Genre", "Game") addItem("Year", "1999") addItem("Title", "Test Title") addItem("Artist", "Test Artist") addItem("Album", "Test Album") addItem("Comment", "Test Comment") update)
assertFilesEqual("good-empty-id3", "good-simple-4-date", tag("test") addItem("track", "1") addItem("genre", "Game") addItem("date", "12/31/1999") addItem("title", "Test Title") addItem("artist", "Test Artist") addItem("album", "Test Album") addItem("comment", "Test Comment") update)
assertFilesEqual("good-empty-id3", "good-simple-4-long", tag("test") addItem("track", "1") addItem("genre", "Game") addItem("year", "1999" repeated(2)) addItem("title", "Test Title" repeated(5)) addItem("artist", "Test Artist" repeated(5)) addItem("album", "Test Album" repeated(5)) addItem("comment", "Test Comment" repeated(5)) update)

tg := tag("good-empty-id3")
tg checkId3 = false
t assertFalse(tg hasId3)
t assertFalse(tg hasApe)

"All tests passed" println
