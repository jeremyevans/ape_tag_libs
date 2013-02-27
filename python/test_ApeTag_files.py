#!/usr/bin/env python
import ApeTag
import unittest
import os.path
import shutil
import filecmp

os.chdir('../test-files')

class TestApeTagFiles(unittest.TestCase):
    def _assertTagErrorRaised(self, msg, cb):
        try:
            cb()
            self.fail("No error raised")
        except ApeTag.TagError as e:
            self.assertEquals(e.message, msg)
        except UnicodeDecodeError:
            self.assertEquals(UnicodeDecodeError, msg)
        except AssertionError:
            raise
        except Exception as e:
            self.fail("non-TagError raised: " + str(e))

    def corrupt(self, filename, msg):
        self._assertTagErrorRaised(msg, lambda: ApeTag.getapefields(filename + '.tag'))

    def assertTagErrorRaised(self, msg, cb):
        self.withTestFile('good-empty', lambda: self._assertTagErrorRaised(msg, cb))

    def withTestFile(self, filename, cb):
        shutil.copy(filename + '.tag', 'test.tag')
        cb()
        os.remove('test.tag')
            
    def assertFilesEqual(self, before, after, cb):
        def f():
            cb()
            self.assertEquals(True, filecmp.cmp(after + '.tag', 'test.tag'))
        self.withTestFile(before, f)

    def assertRemoved(self, before, after):
        self.assertFilesEqual(before, after, lambda: ApeTag.deletetags('test.tag'))

    def test_corrupt(self):
        self.corrupt("corrupt-count-larger-than-possible", "Corrupt tag, end of tag reached with more items specified")
        self.corrupt("corrupt-count-mismatch", "Corrupt tag, mismatched header and footer item count")
        self.corrupt("corrupt-count-over-max-allowed", "Tag exceeds maximum allowed item count")
        self.corrupt("corrupt-data-remaining", "Corrupt tag, parsing complete but not at end of input: 545 bytes remaining")
        self.corrupt("corrupt-duplicate-item-key", "Corrupt tag, duplicate item key: 'name'")
        self.corrupt("corrupt-finished-without-parsing-all-items", "Corrupt tag, end of tag reached with more items specified")
        self.corrupt("corrupt-footer-flags", "Bad tag footer flags")
        self.corrupt("corrupt-header", "Nonexistent or corrupt tag, missing tag header")
        self.corrupt("corrupt-item-flags-invalid", "Corrupt tag, invalid item flags, bits 3-7 nonzero at position 32")
        self.corrupt("corrupt-key-invalid", "Corrupt tag, invalid item key at position 40: '\\x01ame'")
        self.corrupt("corrupt-key-too-short", "Corrupt tag, invalid item key at position 40: 'a'")
        self.corrupt("corrupt-key-too-long", "Corrupt tag, invalid item key at position 40: 'nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'")
        self.corrupt("corrupt-min-size", "Nonexistent or corrupt tag, missing tag header")
        self.corrupt("corrupt-missing-key-value-separator", "Corrupt tag, invalid item key at position 40: 'name\\x01valueAPETAGEX\\xd0\\x07'")
        self.corrupt("corrupt-next-start-too-large", "Corrupt tag, invalid item key at position 40: 'name\\x01valu'")
        self.corrupt("corrupt-size-larger-than-possible", "Existing tag says it is larger than the file: 65 bytes")
        self.corrupt("corrupt-size-mismatch", "Corrupt tag, header and footer sizes do not match")
        self.corrupt("corrupt-size-over-max-allowed", "Existing tag is too large: 61504 bytes")
        self.corrupt("corrupt-value-not-utf8", UnicodeDecodeError)
        self.corrupt("corrupt-item-length-invalid", UnicodeDecodeError)

    def test_has_ape(self):
        self.assertEquals(False, ApeTag.hasapetag("missing-ok.tag"))
        self.assertEquals(True, ApeTag.hasapetag("good-empty.tag"))
        self.assertEquals(False, ApeTag.hasapetag("good-empty-id3-only.tag"))
        self.assertEquals(True, ApeTag.hasapetag("good-empty-id3.tag"))

    def test_has_id3(self):
        self.assertEquals(False, ApeTag.hasid3tag("missing-ok.tag"))
        self.assertEquals(False, ApeTag.hasid3tag("good-empty.tag"))
        self.assertEquals(True, ApeTag.hasid3tag("good-empty-id3-only.tag"))
        self.assertEquals(True, ApeTag.hasid3tag("good-empty-id3.tag"))

    def test_parse(self):
        self.assertEquals({}, ApeTag.getapefields("good-empty.tag"))
        self.assertEquals({'name': ['value']}, ApeTag.getapefields("good-simple-1.tag"))
        #self.assertEquals(['value'], ApeTag.getapefields("good-simple-1.tag")['Name'])

        self.assertEquals(63, len(ApeTag.getapefields("good-many-items.tag")))
        self.assertEquals([''], ApeTag.getapefields("good-many-items.tag")['0n'])
        self.assertEquals(['a'], ApeTag.getapefields("good-many-items.tag")['1n'])
        self.assertEquals(['a' * 62], ApeTag.getapefields("good-many-items.tag")['62n'])

        self.assertEquals({'name': ['va', 'ue']}, ApeTag.getapefields("good-multiple-values.tag"))

        self.assertEquals('name', ApeTag.getapefields("good-simple-1.tag")['name'].key)
        self.assertEquals('utf8', ApeTag.getapefields("good-simple-1.tag")['name'].type)
        self.assertEquals(False, ApeTag.getapefields("good-simple-1.tag")['name'].readonly)
        
        self.assertEquals('name', ApeTag.getapefields("good-simple-1-ro-external.tag")['name'].key)
        self.assertEquals(['value'], ApeTag.getapefields("good-simple-1.tag")['name'])
        self.assertEquals('external', ApeTag.getapefields("good-simple-1-ro-external.tag")['name'].type)
        self.assertEquals(True, ApeTag.getapefields("good-simple-1-ro-external.tag")['name'].readonly)
        
        self.assertEquals('name', ApeTag.getapefields("good-binary-non-utf8-value.tag")['name'].key)
        self.assertEquals(['v\x81lue'], ApeTag.getapefields("good-binary-non-utf8-value.tag")['name'])
        self.assertEquals('binary', ApeTag.getapefields("good-binary-non-utf8-value.tag")['name'].type)
        self.assertEquals(False, ApeTag.getapefields("good-binary-non-utf8-value.tag")['name'].readonly)

        self.assertEquals({'name': ['value']}, ApeTag.getapefields(file("good-simple-1.tag")))

    def test_remove(self):
        self.assertRemoved('good-empty', 'missing-ok')
        self.assertRemoved('good-empty-id3', 'missing-ok')
        self.assertRemoved('good-empty-id3-only', 'missing-ok')
        self.assertRemoved('missing-10k', 'missing-10k')
        self.assertFilesEqual('good-empty', 'missing-ok', lambda: ApeTag.deletetags(file('test.tag', 'r+b')))

    def test_update(self):
        self.assertFilesEqual('good-empty', 'good-empty', lambda: ApeTag.createape('test.tag'))
        self.assertFilesEqual('missing-ok', 'good-empty', lambda: ApeTag.createape('test.tag'))
        self.assertFilesEqual('good-empty', 'good-simple-1', lambda: ApeTag.createape('test.tag', {'name': 'value'}))
        self.assertFilesEqual('good-simple-1', 'good-empty', lambda: ApeTag.updateape('test.tag', removefields=['name']))
        self.assertFilesEqual('good-simple-1', 'good-empty', lambda: ApeTag.updateape('test.tag', removefields=['Name']))
        self.assertFilesEqual('good-empty', 'good-simple-1-ro-external', lambda: ApeTag.createape('test.tag', {'name': ApeTag.ApeItem('name', ['value'], 'external', True)}))
        self.assertFilesEqual('good-empty', 'good-binary-non-utf8-value', lambda: ApeTag.createape('test.tag', {'name': ApeTag.ApeItem('name', ['v\x81lue'], 'binary')}))
        d = {}
        for i in range(63):
            d["%in" % i] = "a" * i
        self.assertFilesEqual('good-empty', 'good-many-items', lambda: ApeTag.createape('test.tag', d))
        self.assertFilesEqual('good-empty', 'good-multiple-values', lambda: ApeTag.createape('test.tag', {'name': ['va', 'ue']}))
        self.assertFilesEqual('good-multiple-values', 'good-simple-1-uc', lambda: ApeTag.createape('test.tag', {'NAME': 'value'}))
        self.assertFilesEqual('good-empty', 'good-simple-1-utf8', lambda: ApeTag.createape('test.tag', {'name': u'v\xc2\xd5'}))

        d['63n'] = 'a' * 63
        d['64n'] = 'a' * 64
        self.assertTagErrorRaised('New tag has too many items: 65 items', lambda: ApeTag.createape('test.tag', d))
        self.assertTagErrorRaised('New tag is too large: 8193 bytes', lambda: ApeTag.createape('test.tag', {'xn': 'a'*8118}))
        self.assertTagErrorRaised("Invalid item key for ape tag item: 'n'", lambda: ApeTag.createape('test.tag', {'n': 'a'}))
        self.assertTagErrorRaised("Invalid item key for ape tag item: 'n\\x00'", lambda: ApeTag.createape('test.tag', {'n\0': 'a'}))
        self.assertTagErrorRaised("Invalid item key for ape tag item: 'n\\x1f'", lambda: ApeTag.createape('test.tag', {'n\x1f': 'a'}))
        self.assertTagErrorRaised("Invalid item key for ape tag item: 'n\\x80'", lambda: ApeTag.createape('test.tag', {'n\x80': 'a'}))
        self.assertTagErrorRaised("Invalid item key for ape tag item: 'n\\xff'", lambda: ApeTag.createape('test.tag', {'n\xff': 'a'}))
        self.assertTagErrorRaised("Invalid item key for ape tag item: 'tag'", lambda: ApeTag.createape('test.tag', {'tag': 'a'}))
        self.assertTagErrorRaised(UnicodeDecodeError, lambda: ApeTag.createape('test.tag', {'ab': 'v\xff'}))
        self.assertTagErrorRaised("Invalid item type for ape tag item: 'foo'", lambda: ApeTag.createape('test.tag', {'ab': ApeTag.ApeItem('name', ['value'], 'foo')}))

        self.assertFilesEqual('good-empty', 'good-simple-1', lambda: ApeTag.createape(file('test.tag', 'r+b'), {'name': 'value'}))

    def test_id3(self):
        self.assertFilesEqual('missing-ok', 'good-empty-id3', lambda: ApeTag.createtags('test.tag'))
        self.assertFilesEqual('good-empty', 'good-empty-id3', lambda: ApeTag.createtags('test.tag'))
        self.assertFilesEqual('good-empty-id3', 'good-empty-id3', lambda: ApeTag.createtags('test.tag'))
        self.assertFilesEqual('good-empty-id3-only', 'good-empty-id3', lambda: ApeTag.createtags('test.tag'))

        self.assertFilesEqual('good-empty-id3', 'good-simple-4', lambda: ApeTag.createtags('test.tag', {'track':'1', 'genre':'Game', 'year':'1999', 'title':'Test Title', 'artist':'Test Artist', 'album':'Test Album', 'comment':'Test Comment'}))
        self.assertFilesEqual('good-empty-id3', 'good-simple-4-uc', lambda: ApeTag.createtags('test.tag', {'Track':'1', 'Genre':'Game', 'Year':'1999', 'Title':'Test Title', 'Artist':'Test Artist', 'Album':'Test Album', 'Comment':'Test Comment'}))
        self.assertFilesEqual('good-empty-id3', 'good-simple-4-date', lambda: ApeTag.createtags('test.tag', {'track':'1', 'genre':'Game', 'date':'12/31/1999', 'title':'Test Title', 'artist':'Test Artist', 'album':'Test Album', 'comment':'Test Comment'}))
        self.assertFilesEqual('good-empty-id3', 'good-simple-4-long', lambda: ApeTag.createtags('test.tag', {'track':'1', 'genre':'Game', 'year':'1999'*2, 'title':'Test Title'*5, 'artist':'Test Artist'*5, 'album':'Test Album'*5, 'comment':'Test Comment'*5}))
        
if __name__ == '__main__':
    unittest.main()
