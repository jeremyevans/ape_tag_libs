#!/usr/bin/env python
import ApeTag
import cStringIO
import unittest
import os.path

EMPTY_APE_TAG = "APETAGEX\320\a\0\0 \0\0\0\0\0\0\0\0\0\0\240\0\0\0\0\0\0\0\0APETAGEX\320\a\0\0 \0\0\0\0\0\0\0\0\0\0\200\0\0\0\0\0\0\0\0TAG\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\377"
EXAMPLE_APE_TAG = "APETAGEX\xd0\x07\x00\x00\xb0\x00\x00\x00\x06\x00\x00\x00\x00\x00\x00\xa0\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00Track\x001\x04\x00\x00\x00\x00\x00\x00\x00Date\x002007\t\x00\x00\x00\x00\x00\x00\x00Comment\x00XXXX-0000\x0b\x00\x00\x00\x00\x00\x00\x00Title\x00Love Cheese\x0b\x00\x00\x00\x00\x00\x00\x00Artist\x00Test Artist\x16\x00\x00\x00\x00\x00\x00\x00Album\x00Test Album\x00Other AlbumAPETAGEX\xd0\x07\x00\x00\xb0\x00\x00\x00\x06\x00\x00\x00\x00\x00\x00\x80\x00\x00\x00\x00\x00\x00\x00\x00TAGLove Cheese\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00Test Artist\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00Test Album, Other Album\x00\x00\x00\x00\x00\x00\x002007XXXX-0000\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\xff"
EXAMPLE_APE_TAG2 = "APETAGEX\xd0\x07\x00\x00\x99\x00\x00\x00\x05\x00\x00\x00\x00\x00\x00\xa0\x00\x00\x00\x00\x00\x00\x00\x00\x04\x00\x00\x00\x00\x00\x00\x00Blah\x00Blah\x04\x00\x00\x00\x00\x00\x00\x00Date\x002007\t\x00\x00\x00\x00\x00\x00\x00Comment\x00XXXX-0000\x0b\x00\x00\x00\x00\x00\x00\x00Artist\x00Test Artist\x16\x00\x00\x00\x00\x00\x00\x00Album\x00Test Album\x00Other AlbumAPETAGEX\xd0\x07\x00\x00\x99\x00\x00\x00\x05\x00\x00\x00\x00\x00\x00\x80\x00\x00\x00\x00\x00\x00\x00\x00TAG\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00Test Artist\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00Test Album, Other Album\x00\x00\x00\x00\x00\x00\x002007XXXX-0000\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff"
EMPTY_ID3_FIELDS = {'album': '', 'comment': '', 'title': '', 'track': '0', 'artist': '', 'year': '', 'genre': ''}
EXAMPLE_ID3_FIELDS = {'album': 'Test Album, Other Album', 'comment': 'XXXX-0000', 'title': 'Love Cheese', 'track': '1', 'artist': 'Test Artist', 'year': '2007', 'genre': ''}
EXAMPLE_ID3_FIELDS2 = {'album': 'Test Album, Other Album', 'comment': 'XXXX-0000', 'title': '', 'track': '0', 'artist': 'Test Artist', 'year': '2007', 'genre': ''}
EXAMPLE_APE_FIELDS = {"Track":["1"], "Comment":["XXXX-0000"], "Album":["Test Album", "Other Album"], "Title":["Love Cheese"], "Artist":["Test Artist"], "Date":["2007"]}
EXAMPLE_APE_FIELDS2 = {"Blah":["Blah"], "Comment":["XXXX-0000"], "Album":["Test Album", "Other Album"], "Artist":["Test Artist"], "Date":["2007"]}
EXAMPLE_APE_TAG_PRETTY_PRINT = "Album: Test Album, Other Album\nArtist: Test Artist\nComment: XXXX-0000\nDate: 2007\nTitle: Love Cheese\nTrack: 1"

# Replace character
def rc(string, position, character, io = True):
    s = '%s%s%s' % (string[:position], chr(character), string[position+1:])
    if io:
        return sio(s)
    return s
    
# Replace range of characters
def rr(string, position, characters, io = True):
    s = '%s%s%s' % (string[:position], characters, string[position+len(characters):])
    if io:
        return sio(s)
    return s
    
def sio(string):
    x = cStringIO.StringIO()
    x.write(string)
    return x

def filesize(f):
    if hasattr(f, 'seek'):
        f.seek(0,2) 
        return f.tell()
    return os.path.getsize(f)

class TestApeTag(unittest.TestCase):
    def tag_test(self, f):
        size = filesize(f)
        self.assertEqual(False, ApeTag.hasapetag(f))
        self.assertEqual(size, filesize(f))
        self.assertEqual(False, ApeTag.hasid3tag(f))
        self.assertEqual(size, filesize(f))
        self.assertEqual(False, ApeTag.hastags(f))
        self.assertEqual(size, filesize(f))

        self.assertEqual(0, ApeTag.deleteape(f))
        self.assertEqual(size, filesize(f))
        self.assertEqual(0, ApeTag.deleteid3(f))
        self.assertEqual(size, filesize(f))
        self.assertEqual(0, ApeTag.deletetags(f))
        self.assertEqual(size, filesize(f))
        
        self.assertRaises(ApeTag.TagError, ApeTag.getrawape, f)
        self.assertRaises(ApeTag.TagError, ApeTag.getrawid3, f)
        self.assertRaises(ApeTag.TagError, ApeTag.getrawtags, f)
        self.assertRaises(ApeTag.TagError, ApeTag.printapetag, f)
        self.assertRaises(ApeTag.TagError, ApeTag.printid3tag, f)
        self.assertRaises(ApeTag.TagError, ApeTag.printtags, f)
        self.assertRaises(ApeTag.TagError, ApeTag.updateape, f)
        self.assertRaises(ApeTag.TagError, ApeTag.updateid3, f)
        self.assertRaises(ApeTag.TagError, ApeTag.updatetags, f)
        
        self.assertEqual({}, ApeTag.createape(f, {}))
        self.assertEqual({}, ApeTag.getapefields(f))
        self.assertEqual(True, ApeTag.hasapetag(f))
        self.assertEqual(False, ApeTag.hasid3tag(f))
        self.assertEqual(False, ApeTag.hastags(f))
        self.assertEqual(size+64, filesize(f))
        self.assertEqual(EMPTY_APE_TAG[:64], ApeTag.getrawape(f))
        self.assertEqual(0, ApeTag.deleteape(f))
        self.assertEqual(size, filesize(f))
        
        self.assertEqual(EMPTY_ID3_FIELDS, ApeTag.createid3(f, {}))
        self.assertEqual(EMPTY_ID3_FIELDS, ApeTag.getid3fields(f))
        self.assertEqual(False, ApeTag.hasapetag(f))
        self.assertEqual(True, ApeTag.hasid3tag(f))
        self.assertEqual(False, ApeTag.hastags(f))
        self.assertEqual(size+128, filesize(f))
        self.assertEqual(EMPTY_APE_TAG[64:], ApeTag.getrawid3(f))
        self.assertEqual(0, ApeTag.deleteid3(f))
        self.assertEqual(size, filesize(f))
        
        self.assertEqual({}, ApeTag.createtags(f, {}))
        self.assertEqual(({},EMPTY_ID3_FIELDS), ApeTag.gettagfields(f))
        self.assertEqual(True, ApeTag.hasapetag(f))
        self.assertEqual(True, ApeTag.hasid3tag(f))
        self.assertEqual(True, ApeTag.hastags(f))
        self.assertEqual(size+192, filesize(f))
        self.assertEqual((EMPTY_APE_TAG[:64], EMPTY_APE_TAG[64:]), ApeTag.getrawtags(f))
        self.assertEqual(0, ApeTag.deletetags(f))
        self.assertEqual(size, filesize(f))
        
        
        self.assertEqual(EXAMPLE_APE_FIELDS, ApeTag.createape(f, EXAMPLE_APE_FIELDS))
        self.assertEqual(EXAMPLE_APE_FIELDS, ApeTag.getapefields(f))
        self.assertEqual(EXAMPLE_APE_FIELDS, ApeTag.createape(f, EXAMPLE_APE_FIELDS))
        self.assertEqual(True, ApeTag.hasapetag(f))
        self.assertEqual(False, ApeTag.hasid3tag(f))
        self.assertEqual(False, ApeTag.hastags(f))
        self.assertEqual(size+208, filesize(f))
        self.assertEqual(EXAMPLE_APE_TAG[:-128], ApeTag.getrawape(f))
        self.assertEqual(0, ApeTag.deleteape(f))
        self.assertEqual(size, filesize(f))
        
        self.assertEqual(EXAMPLE_ID3_FIELDS, ApeTag.createid3(f, EXAMPLE_ID3_FIELDS))
        self.assertEqual(EXAMPLE_ID3_FIELDS, ApeTag.getid3fields(f))
        self.assertEqual(EXAMPLE_ID3_FIELDS, ApeTag.createid3(f, EXAMPLE_ID3_FIELDS))
        self.assertEqual(False, ApeTag.hasapetag(f))
        self.assertEqual(True, ApeTag.hasid3tag(f))
        self.assertEqual(False, ApeTag.hastags(f))
        self.assertEqual(size+128, filesize(f))
        self.assertEqual(EXAMPLE_APE_TAG[-128:], ApeTag.getrawid3(f))
        self.assertEqual(0, ApeTag.deleteid3(f))
        self.assertEqual(size, filesize(f))
        
        self.assertEqual(EXAMPLE_APE_FIELDS, ApeTag.createtags(f, EXAMPLE_APE_FIELDS))
        self.assertEqual((EXAMPLE_APE_FIELDS,EXAMPLE_ID3_FIELDS), ApeTag.gettagfields(f))
        self.assertEqual(EXAMPLE_APE_FIELDS, ApeTag.createtags(f, EXAMPLE_APE_FIELDS))
        self.assertEqual(True, ApeTag.hasapetag(f))
        self.assertEqual(True, ApeTag.hasid3tag(f))
        self.assertEqual(True, ApeTag.hastags(f))
        self.assertEqual(size+336, filesize(f))
        self.assertEqual((EXAMPLE_APE_TAG[:-128], EXAMPLE_APE_TAG[-128:]), ApeTag.getrawtags(f))
        self.assertEqual(0, ApeTag.deletetags(f))
        self.assertEqual(size, filesize(f))
        
        
        self.assertEqual(EXAMPLE_APE_FIELDS, ApeTag.createape(f, EXAMPLE_APE_FIELDS))
        self.assertEqual(EXAMPLE_APE_FIELDS2, ApeTag.updateape(f, {'Blah':'Blah'}, ['Track', 'Title']))
        self.assertEqual(EXAMPLE_APE_FIELDS2, ApeTag.getapefields(f))
        self.assertEqual(True, ApeTag.hasapetag(f))
        self.assertEqual(False, ApeTag.hasid3tag(f))
        self.assertEqual(False, ApeTag.hastags(f))
        self.assertEqual(size+185, filesize(f))
        self.assertEqual(EXAMPLE_APE_TAG2[:-128], ApeTag.getrawape(f))
            
        self.assertEqual(EXAMPLE_APE_FIELDS, ApeTag.replaceape(f, EXAMPLE_APE_FIELDS))
        self.assertEqual(EXAMPLE_APE_FIELDS, ApeTag.getapefields(f))
        self.assertEqual(True, ApeTag.hasapetag(f))
        self.assertEqual(False, ApeTag.hasid3tag(f))
        self.assertEqual(False, ApeTag.hastags(f))
        self.assertEqual(size+208, filesize(f))
        self.assertEqual(EXAMPLE_APE_TAG[:-128], ApeTag.getrawape(f))
        self.assertEqual(EXAMPLE_APE_FIELDS2, ApeTag.updateape(f, {'Blah':'Blah'}, ['track', 'title']))
        self.assertEqual(EXAMPLE_APE_TAG2[:-128], ApeTag.getrawape(f))
        self.assertEqual(0, ApeTag.deleteape(f))
        self.assertEqual(size, filesize(f))
        
        self.assertEqual(EXAMPLE_ID3_FIELDS, ApeTag.createid3(f, EXAMPLE_ID3_FIELDS))
        self.assertEqual(EXAMPLE_ID3_FIELDS2, ApeTag.updateid3(f, {'Track':0, 'Title':''}))
        self.assertEqual(EXAMPLE_ID3_FIELDS2, ApeTag.getid3fields(f))
        self.assertEqual(False, ApeTag.hasapetag(f))
        self.assertEqual(True, ApeTag.hasid3tag(f))
        self.assertEqual(False, ApeTag.hastags(f))
        self.assertEqual(size+128, filesize(f))
        self.assertEqual(EXAMPLE_APE_TAG2[-128:], ApeTag.getrawid3(f))
            
        self.assertEqual(EXAMPLE_ID3_FIELDS, ApeTag.replaceid3(f, EXAMPLE_ID3_FIELDS))
        self.assertEqual(EXAMPLE_ID3_FIELDS, ApeTag.getid3fields(f))
        self.assertEqual(False, ApeTag.hasapetag(f))
        self.assertEqual(True, ApeTag.hasid3tag(f))
        self.assertEqual(False, ApeTag.hastags(f))
        self.assertEqual(size+128, filesize(f))
        self.assertEqual(EXAMPLE_APE_TAG[-128:], ApeTag.getrawid3(f))
        self.assertEqual(0, ApeTag.deleteid3(f))
        self.assertEqual(size, filesize(f))
        
        self.assertEqual(EXAMPLE_APE_FIELDS, ApeTag.createtags(f, EXAMPLE_APE_FIELDS))
        self.assertEqual(EXAMPLE_APE_FIELDS2, ApeTag.updatetags(f, {'Blah':'Blah'}, ['Track', 'Title']))
        self.assertEqual((EXAMPLE_APE_FIELDS2, EXAMPLE_ID3_FIELDS2), ApeTag.gettagfields(f))
        self.assertEqual(True, ApeTag.hasapetag(f))
        self.assertEqual(True, ApeTag.hasid3tag(f))
        self.assertEqual(True, ApeTag.hastags(f))
        self.assertEqual(size+313, filesize(f))
        self.assertEqual((EXAMPLE_APE_TAG2[:-128], EXAMPLE_APE_TAG2[-128:]), ApeTag.getrawtags(f))
            
        self.assertEqual(EXAMPLE_APE_FIELDS, ApeTag.replacetags(f, EXAMPLE_APE_FIELDS))
        self.assertEqual((EXAMPLE_APE_FIELDS, EXAMPLE_ID3_FIELDS), ApeTag.gettagfields(f))
        self.assertEqual(True, ApeTag.hasapetag(f))
        self.assertEqual(True, ApeTag.hasid3tag(f))
        self.assertEqual(True, ApeTag.hastags(f))
        self.assertEqual(size+336, filesize(f))
        self.assertEqual((EXAMPLE_APE_TAG[:-128], EXAMPLE_APE_TAG[-128:]), ApeTag.getrawtags(f))
        self.assertEqual(EXAMPLE_APE_FIELDS2, ApeTag.updatetags(f, {'Blah':'Blah'}, ['track', 'title']))
        self.assertEqual((EXAMPLE_APE_TAG2[:-128], EXAMPLE_APE_TAG2[-128:]), ApeTag.getrawtags(f))
        self.assertEqual(0, ApeTag.deletetags(f))
        self.assertEqual(size, filesize(f))
        
    def test_multiple_sizes(self):
        filename = 'test.apetag'
        file(filename, 'wb').close()
        for x in [0,1,63,64,65,127,128,129,191,192,193,8191,8192,8193]:
            s = ' ' * x
            f = sio(s)
            self.tag_test(f)
            f = file(filename,'r+b')
            f.write(s)
            self.tag_test(f)
            f.close()
            self.tag_test(filename)
        os.remove(filename)
    
    def test_ape_item_init(self):
        ai = ApeTag.ApeItem()
        self.assertEqual([], ai)
        
        ai = ApeTag.ApeItem('BlaH')
        self.assertEqual(False, ai.readonly)
        self.assertEqual('utf8', ai.type)
        self.assertEqual('BlaH', ai.key)
        self.assertEqual([], ai)
        
        ai = ApeTag.ApeItem('BlaH', ['BlAh'])
        self.assertEqual(False, ai.readonly)
        self.assertEqual('utf8', ai.type)
        self.assertEqual('BlaH', ai.key)
        self.assertEqual(['BlAh'], ai)
        
        ai = ApeTag.ApeItem('BlaH', ['BlAh'], 'external')
        self.assertEqual(False, ai.readonly)
        self.assertEqual('external', ai.type)
        self.assertEqual('BlaH', ai.key)
        self.assertEqual(['BlAh'], ai)
        
        ai = ApeTag.ApeItem('BlaH', ['BlAh'], 'external', True)
        self.assertEqual(True, ai.readonly)
        self.assertEqual('external', ai.type)
        self.assertEqual('BlaH', ai.key)
        self.assertEqual(['BlAh'], ai)
        
    def test_ape_item_valid_key(self):
        ai = ApeTag.ApeItem()
        # Test bad keys
        for x in [None, 1, '', 'x', 'x'*256]+["%s  " % c for c in ApeTag._badapeitemkeychars]+ApeTag._badapeitemkeys:
            self.assertEqual(False, ai.validkey(x))
        # Test good keys
        for x in ['xx', 'x'*255]+["%s  " % chr(c) for c in range(32,128)]+["%s  " % c for c in ApeTag._badapeitemkeys]:
            self.assertEqual(True, ai.validkey(x))
            
    def test_ape_item_maketag(self):
        ai = ApeTag.ApeItem('BlaH', ['BlAh'])
        self.assertEqual("\04\0\0\0\0\0\0\0BlaH\0BlAh", ai.maketag())
        ai.readonly=True
        self.assertEqual("\04\0\0\0\0\0\0\01BlaH\0BlAh", ai.maketag())
        ai.type='external'
        self.assertEqual("\04\0\0\0\0\0\0\05BlaH\0BlAh", ai.maketag())
        ai.append('XYZ')
        self.assertEqual("\010\0\0\0\0\0\0\05BlaH\0BlAh\0XYZ", ai.maketag())
        
    def test_ape_item_parsetag(self):
        data = "\010\0\0\0\0\0\0\05BlaH\0BlAh\0XYZ"
        # Test simple parsing
        ai = ApeTag.ApeItem()
        cp = ai.parsetag(data, 0)
        self.assertEqual(2, len(ai))
        self.assertEqual(len(data), cp)
        self.assertEqual(True, ai.readonly)
        self.assertEqual('external', ai.type)
        self.assertEqual('BlaH', ai.key)
        
        # Test parsing with bad key
        self.assertRaises(ApeTag.TagError, ApeTag.ApeItem().parsetag, "\0\0\0\0\0\0\0\0x\0", 0)
        
        # Test parsing with no key end
        self.assertRaises(ApeTag.TagError, ApeTag.ApeItem().parsetag, "\0\0\0\0\0\0\0\0xx", 0)
        
        # Test parsing with bad start value
        self.assertRaises(ApeTag.TagError, ApeTag.ApeItem().parsetag, data, 1)
        
        # Test parsing with bad flags
        self.assertRaises(ApeTag.TagError, ApeTag.ApeItem().parsetag, "\0\0\0\0\0\0\0\010xx\0", 1)
        
        # Test parsing with length longer than string
        self.assertRaises(ApeTag.TagError, ApeTag.ApeItem().parsetag, "\01\0\0\0\0\0\0\010xx\0", 1)
        
        # Test parsing with length shorter than string gives valid ApeItem
        # Of course, the next item will probably be parsed incorrectly
        ai = ApeTag.ApeItem()
        cp = ai.parsetag('\03'+data[1:], 0)
        self.assertEqual(16, cp)
        self.assertEqual('BlaH', ai.key)
        self.assertEqual(['BlA'], ai)
        
        # Test parsing of invalid UTF-8
        self.assertRaises(ApeTag.TagError, ApeTag.ApeItem().parsetag, "\01\0\0\0\0\0\0\010xx\0\x83", 1)
        
    def test_bad_tags(self):
        # Test read only tag flag works
        ro_tag = rc(rc(EMPTY_APE_TAG, 20, 1, False), 52, 1)
        ro_tag.seek(0)
        ro_tag = ro_tag.read()
        self.assertEqual(''.join(ApeTag.getrawtags(rc(rc(EMPTY_APE_TAG, 20, 1, False), 52, 1))), ro_tag)
        # Test bad tag flags
        for i in range(2,256):
            self.assertRaises(ApeTag.TagError, ApeTag.getrawtags, rc(EMPTY_APE_TAG, 20, i))
            self.assertRaises(ApeTag.TagError, ApeTag.getrawtags, rc(EMPTY_APE_TAG, 52, i))
            self.assertRaises(ApeTag.TagError, ApeTag.getrawtags, rc(rc(EMPTY_APE_TAG, 20, i, False), 52, i))

        # Test footer size less than minimum size (32)
        self.assertRaises(ApeTag.TagError, ApeTag.getrawtags, rc(EMPTY_APE_TAG, 44, 31))
        self.assertRaises(ApeTag.TagError, ApeTag.getrawtags, rc(EMPTY_APE_TAG, 44, 0))
        
        # Test tag size > 8192, when both larger than file and smaller than file
        large = rc(rc(EMPTY_APE_TAG, 44, 225, False), 45, 31, False)
        self.assertRaises(ApeTag.TagError, ApeTag.getrawtags, sio(large))
        self.assertRaises(ApeTag.TagError, ApeTag.getrawtags, sio(' '*8192+large))
        
        # Test unmatching header and footer tag size, with footer size wrong
        self.assertRaises(ApeTag.TagError, ApeTag.getrawtags, rc(EMPTY_APE_TAG, 44, 33))
        
        # Test matching header and footer but size to large for file
        wrong = rc(rc(EMPTY_APE_TAG, 12, 33, False), 44, 33, False)
        self.assertRaises(ApeTag.TagError, ApeTag.getrawtags, sio(wrong))
        
        # Test that header and footer size isn't too large for file, but doesn't 
        # find the header
        wrong=" "+wrong
        self.assertRaises(ApeTag.TagError, ApeTag.getrawtags, sio(wrong))
        
        # Test unmatching header and footer tag size, with header size wrong
        self.assertRaises(ApeTag.TagError, ApeTag.getrawtags, rc(EMPTY_APE_TAG, 45, 32))
        
        # Test item count greater than possible given tag size
        self.assertRaises(ApeTag.TagError, ApeTag.gettagfields, rc(EMPTY_APE_TAG, 48, 1))
        
        # Test unmatched header and footer item size, header size wrong
        self.assertRaises(ApeTag.TagError, ApeTag.gettagfields, rc(EMPTY_APE_TAG, 16, 1))
        
        # Test unmatched header and footer item size, footer size wrong
        self.assertRaises(ApeTag.TagError, ApeTag.gettagfields, rc(EXAMPLE_APE_TAG, 192, ord(EXAMPLE_APE_TAG[192])-1))
        
        # Test missing/corrupt header
        self.assertRaises(ApeTag.TagError, ApeTag.gettagfields, rc(EMPTY_APE_TAG, 0, 0))
        
        # Test parsing bad first item size
        self.assertRaises(ApeTag.TagError, ApeTag.gettagfields, rc(EXAMPLE_APE_TAG, 32, ord(EXAMPLE_APE_TAG[32])+1))
        
        # Test parsing bad first item invalid key
        self.assertRaises(ApeTag.TagError, ApeTag.gettagfields, rc(EXAMPLE_APE_TAG, 40, 0))
        
        # Test parsing bad first item key end
        self.assertRaises(ApeTag.TagError, ApeTag.gettagfields, rc(EXAMPLE_APE_TAG, 45, 1))
        
        # Test parsing bad second item length too long
        self.assertRaises((ApeTag.TagError, UnicodeDecodeError), ApeTag.gettagfields, rc(EXAMPLE_APE_TAG, 47, 255))
        
        # Test parsing case insensitive duplicate keys
        self.assertRaises(ApeTag.TagError, ApeTag.gettagfields, rr(EXAMPLE_APE_TAG, 40, 'Album'))
        self.assertRaises(ApeTag.TagError, ApeTag.gettagfields, rr(EXAMPLE_APE_TAG, 40, 'album'))
        self.assertRaises(ApeTag.TagError, ApeTag.gettagfields, rr(EXAMPLE_APE_TAG, 40, 'ALBUM'))
        
        # Test parsing incorrect item counts
        self.assertRaises(ApeTag.TagError, ApeTag.gettagfields, rc(rc(EXAMPLE_APE_TAG, 16, ord(EXAMPLE_APE_TAG[16])+1, False), 192, ord(EXAMPLE_APE_TAG[192])+1))
        self.assertRaises(ApeTag.TagError, ApeTag.gettagfields, rc(rc(EXAMPLE_APE_TAG, 16, ord(EXAMPLE_APE_TAG[16])-1, False), 192, ord(EXAMPLE_APE_TAG[192])-1))
        
        # Test updating with invalid key
        self.assertRaises(ApeTag.TagError, ApeTag.updatetags, sio(EXAMPLE_APE_TAG), {'x':'x'})
        
        # Test updating with too large a tag
        self.assertRaises(ApeTag.TagError, ApeTag.updatetags, sio(EXAMPLE_APE_TAG), {'x':'x'*8192})
    
    def test_ape_to_id3_fields_conversion(self):
        pass
        
if __name__ == '__main__':
    unittest.main()
