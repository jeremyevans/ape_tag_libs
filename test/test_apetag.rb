#!/usr/bin/env ruby
require 'apetag'
require 'stringio'
require 'test/unit'

EMPTY_APE_TAG = "APETAGEX\320\a\0\0 \0\0\0\0\0\0\0\0\0\0\240\0\0\0\0\0\0\0\0APETAGEX\320\a\0\0 \0\0\0\0\0\0\0\0\0\0\200\0\0\0\0\0\0\0\0TAG\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\377"
EXAMPLE_APE_TAG = "APETAGEX\xd0\x07\x00\x00\xb0\x00\x00\x00\x06\x00\x00\x00\x00\x00\x00\xa0\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00Track\x001\x04\x00\x00\x00\x00\x00\x00\x00Date\x002007\t\x00\x00\x00\x00\x00\x00\x00Comment\x00XXXX-0000\x0b\x00\x00\x00\x00\x00\x00\x00Title\x00Love Cheese\x0b\x00\x00\x00\x00\x00\x00\x00Artist\x00Test Artist\x16\x00\x00\x00\x00\x00\x00\x00Album\x00Test Album\x00Other AlbumAPETAGEX\xd0\x07\x00\x00\xb0\x00\x00\x00\x06\x00\x00\x00\x00\x00\x00\x80\x00\x00\x00\x00\x00\x00\x00\x00TAGLove Cheese\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00Test Artist\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00Test Album, Other Album\x00\x00\x00\x00\x00\x00\x002007XXXX-0000\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\xff"
EXAMPLE_APE_TAG2 = "APETAGEX\xd0\x07\x00\x00\x99\x00\x00\x00\x05\x00\x00\x00\x00\x00\x00\xa0\x00\x00\x00\x00\x00\x00\x00\x00\x04\x00\x00\x00\x00\x00\x00\x00Blah\x00Blah\x04\x00\x00\x00\x00\x00\x00\x00Date\x002007\t\x00\x00\x00\x00\x00\x00\x00Comment\x00XXXX-0000\x0b\x00\x00\x00\x00\x00\x00\x00Artist\x00Test Artist\x16\x00\x00\x00\x00\x00\x00\x00Album\x00Test Album\x00Other AlbumAPETAGEX\xd0\x07\x00\x00\x99\x00\x00\x00\x05\x00\x00\x00\x00\x00\x00\x80\x00\x00\x00\x00\x00\x00\x00\x00TAG\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00Test Artist\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00Test Album, Other Album\x00\x00\x00\x00\x00\x00\x002007XXXX-0000\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff"
EMPTY_APE_ONLY_TAG, EXAMPLE_APE_ONLY_TAG, EXAMPLE_APE_ONLY_TAG2 = [EMPTY_APE_TAG, EXAMPLE_APE_TAG, EXAMPLE_APE_TAG2].collect{|x|x[0...-128]}
EXAMPLE_APE_FIELDS = {"Track"=>["1"], "Comment"=>["XXXX-0000"], "Album"=>["Test Album", "Other Album"], "Title"=>["Love Cheese"], "Artist"=>["Test Artist"], "Date"=>["2007"]}
EXAMPLE_APE_FIELDS2 = {"Blah"=>["Blah"], "Comment"=>["XXXX-0000"], "Album"=>["Test Album", "Other Album"], "Artist"=>["Test Artist"], "Date"=>["2007"]}
EXAMPLE_APE_TAG_PRETTY_PRINT = "Album: Test Album, Other Album\nArtist: Test Artist\nComment: XXXX-0000\nDate: 2007\nTitle: Love Cheese\nTrack: 1"

class ApeTagTest < Test::Unit::TestCase
  def get_ape_tag(f, check_id3)
    f.is_a?(ApeTag) ? f : ApeTag.new(f, check_id3)
  end
  
  def get_size(x)
    get_ape_tag(x, nil).send :file_size
  end

  def item_test(item, check_id3)
    f = item
    id3_size = check_id3 ? 128 : 0
    size = get_size(f)
    assert_equal false, get_ape_tag(f, check_id3).exists?
    assert_equal size, get_size(f)
    assert_equal true, get_ape_tag(f, check_id3).remove!
    assert_equal size, get_size(f)
    assert_equal "", get_ape_tag(f, check_id3).raw
    assert_equal size, get_size(f)
    assert_equal Hash.new, get_ape_tag(f, check_id3).fields
    assert_equal size, get_size(f)
    assert_equal Hash.new, get_ape_tag(f, check_id3).update{|x|}
    assert_equal (size+=64+id3_size), get_size(f)
    assert_equal true, get_ape_tag(f, check_id3).exists?
    assert_equal size, get_size(f)
    assert_equal (check_id3 ? EMPTY_APE_TAG : EMPTY_APE_ONLY_TAG), get_ape_tag(f, check_id3).raw, "#{item.inspect} #{check_id3}"
    assert_equal size, get_size(f)
    assert_equal Hash.new, get_ape_tag(f, check_id3).fields
    assert_equal size, get_size(f)
    assert_equal Hash.new, get_ape_tag(f, check_id3).update{|x|}
    assert_equal size, get_size(f)
    assert_equal true, get_ape_tag(f, check_id3).remove!
    assert_equal (size-=64+id3_size), get_size(f)
    assert_equal EXAMPLE_APE_FIELDS, get_ape_tag(f, check_id3).update{|x| x.replace(EXAMPLE_APE_FIELDS)}
    assert_equal (size+=208+id3_size), get_size(f)
    assert_equal true, get_ape_tag(f, check_id3).exists?
    assert_equal size, get_size(f)
    assert_equal (check_id3 ? EXAMPLE_APE_TAG : EXAMPLE_APE_ONLY_TAG), get_ape_tag(f, check_id3).raw
    assert_equal EXAMPLE_APE_TAG_PRETTY_PRINT, get_ape_tag(f, check_id3).pretty_print
    assert_equal size, get_size(f)
    assert_equal EXAMPLE_APE_FIELDS, get_ape_tag(f, check_id3).fields
    assert_equal size, get_size(f)
    assert_equal EXAMPLE_APE_FIELDS, get_ape_tag(f, check_id3).update{|x|}
    assert_equal size, get_size(f)
    assert_equal EXAMPLE_APE_FIELDS2, get_ape_tag(f, check_id3).update {|x| x.delete('Track'); x.delete('Title'); x['Blah']='Blah'}
    assert_equal (size-=23), get_size(f)
    assert_equal true, get_ape_tag(f, check_id3).exists?
    assert_equal size, get_size(f)
    assert_equal (check_id3 ? EXAMPLE_APE_TAG2 : EXAMPLE_APE_ONLY_TAG2), get_ape_tag(f, check_id3).raw
    assert_equal size, get_size(f)
    assert_equal EXAMPLE_APE_FIELDS2, get_ape_tag(f, check_id3).fields
    assert_equal size, get_size(f)
    assert_equal EXAMPLE_APE_FIELDS2, get_ape_tag(f, check_id3).update{|x|}
    assert_equal size, get_size(f)
    assert_equal true, get_ape_tag(f, check_id3).remove!
    assert_equal "", get_ape_tag(f, check_id3).raw
    assert_equal (size-=185+id3_size), get_size(f)
  end

  # Test to make sure different file sizes don't cause any problems.
  # Use both StringIOs, Files, and Strings.
  # Use both a single ApeTag for each test and a new ApeTag for each to test
  # that ApeTag state is created and saved correctly.
  def test_blanks
    filename = 'test.apetag'
    File.new(filename,'wb').close
    [0,1,63,64,65,127,128,129,191,192,193,8191,8192,8193].each do |x|
      [true, false].each do |check_id3|
        s = StringIO.new(' ' * x)
        item_test(s, check_id3)
        item_test(ApeTag.new(s, check_id3), check_id3)
        f = File.new(filename,'rb+')
        f.write(' ' * x)
        item_test(f, check_id3)
        item_test(ApeTag.new(f, check_id3), check_id3)
        f.close()
        item_test(filename, check_id3)
        item_test(ApeTag.new(filename, check_id3), check_id3)
      end
    end
    File.delete(filename)
  end
  
  # Test ApeItem instance methods
  def test_ape_item
    ai = ApeItem.new('BlaH', ['BlAh'])
    # Test valid defaults
    assert_equal ['BlAh'], ai
    assert_equal false, ai.read_only
    assert_equal 'utf8', ai.ape_type
    assert_equal 'BlaH', ai.key
    assert_equal 'BlAh', ai.string_value
    assert_equal "\04\0\0\0\0\0\0\0BlaH\0BlAh", ai.raw
    assert_equal true, ai.valid?
    
    # Test valid read_only settings
    assert_nothing_raised{ai.read_only=true}
    assert_nothing_raised{ai.read_only=false}
    assert_raises(ApeTagError){ai.read_only=nil}
    assert_raises(ApeTagError){ai.read_only='Blah'}
    assert_equal true, ai.valid?
    
    # Test valid ape_type settings
    ApeItem::ITEM_TYPES.each{|type| assert_nothing_raised{ai.ape_type=type}}
    assert_raises(ApeTagError){ai.ape_type='Blah'}
    
    # Test valid key settings
    ((("\0".."\x1f").to_a+("\x80".."\xff").to_a).collect{|x|"#{x}  "} +
      [nil, 1, '', 'x', 'x'*256, 'id3', 'tag', 'oggs', 'mp+']).each{|x|assert_raises(ApeTagError){ai.key=x}}
    ("\x20".."\x7f").to_a.collect{|x|"#{x}  "}+['id3', 'tag', 'oggs', 'mp+'].collect{|x|"#{x}  "} +
      ['xx', 'x'*255].each{|x| assert_nothing_raised{ai.key=x}}
    
    # Test valid raw and string value for different settings
    ai.key="BlaH"
    assert_equal "\04\0\0\0\0\0\0\06BlaH\0BlAh", ai.raw
    assert_equal 'BlAh', ai.string_value
    ai.read_only=true
    assert_equal "\04\0\0\0\0\0\0\07BlaH\0BlAh", ai.raw
    assert_equal 'BlAh', ai.string_value
    ai << 'XYZ'
    assert_equal "\010\0\0\0\0\0\0\07BlaH\0BlAh\0XYZ", ai.raw
    assert_equal "BlAh\0XYZ", ai.string_value
  end
  
  # Test ApeItem.create methods
  def test_ape_item_create
    ai = ApeItem.new('BlaH', ['BlAh'])
    ac = ApeItem.create('BlaH', ai)
    # Test same key and ApeItem passed gives same item with key
    assert_equal ai.object_id, ac.object_id
    assert_equal 'BlaH', ai.key
    assert_equal 'BlaH', ac.key
    # Test different key and ApeItem passed gives same item with different key
    ac = ApeItem.create('XXX', ai)
    assert_equal ai.object_id, ac.object_id
    assert_equal 'XXX', ai.key
    assert_equal 'XXX', ac.key
    
    # Test create fails with invalid key
    assert_raises(ApeTagError){ApeItem.create('', ai)}
    # Test create fails with invalid UTF-8 value
    assert_raises(ApeTagError){ApeItem.create('xx',["\xfe"])}
    # Test create doesn't fail with valid UTF-8 value
    assert_nothing_raised{ApeItem.create('xx',[[12345, 1345].pack('UU')])}
    
    # Test create with empty array
    ac = ApeItem.create('Blah', [])
    assert_equal ApeItem, ac.class
    assert_equal 0, ac.length
    assert_equal '', ac.string_value
    
    # Test create works with string
    ac = ApeItem.create('Blah', 'Blah')
    assert_equal ApeItem, ac.class
    assert_equal 1, ac.length
    assert_equal 'Blah', ac.string_value
    
    # Test create works with random object (Hash in this case)
    ac = ApeItem.create('Blah', 'xfe'=>132)
    assert_equal ApeItem, ac.class
    assert_equal 1, ac.length
    assert_equal 'xfe132', ac.string_value
    
    # Test create works with array of mixed objects
    ac = ApeItem.create('Blah', ['sadf', 'adsfas', 11, {'xfe'=>132}])
    assert_equal ApeItem, ac.class
    assert_equal 4, ac.length
    assert_equal "sadf\0adsfas\00011\0xfe132", ac.string_value
  end
  
  # Test ApeItem.parse
  def test_ape_item_parse
    data = "\010\0\0\0\0\0\0\07BlaH\0BlAh\0XYZ"
    # Test simple item parsing
    ai, offset = ApeItem.parse(data, 0)
    assert_equal 2, ai.length
    assert_equal offset, data.length
    assert_equal "BlAh\0XYZ", ai.string_value
    assert_equal true, ai.read_only
    assert_equal 'reserved', ai.ape_type
    assert_equal 'BlaH', ai.key
    
    # Test parsing with bad key
    assert_raises(ApeTagError){ApeItem.parse("\0\0\0\0\0\0\0\07x\0", 0)}
    
    # Test parsing with no key end
    assert_raises(ApeTagError){ApeItem.parse(data[0...-1], 0)}
    
    # Test parsing with bad start value
    assert_raises(ApeTagError){ApeItem.parse(data, 1)}
    
    # Test parsing with bad/good flags
    data[4] = 8
    assert_raises(ApeTagError){ApeItem.parse(data, 0)}
    data[4] = 0
    assert_nothing_raised{ApeItem.parse(data, 0)}
    
    # Test parsing with length longer than string
    data[0] = 9
    assert_raises(ApeTagError){ApeItem.parse(data, 0)}
    
    # Test parsing with length shorter than string gives valid ApeItem
    # Of course, the next item will probably be parsed incorrectly
    data[0] = 3
    assert_nothing_raised{ai, offset = ApeItem.parse(data, 0)}
    assert_equal 16, offset
    assert_equal "BlaH", ai.key
    assert_equal "BlA", ai.string_value
    
    # Test parsing gets correct key end
    data[12] = '3'
    assert_nothing_raised{ai, offset = ApeItem.parse(data, 0)}
    assert_equal "BlaH3BlAh", ai.key
    assert_equal "XYZ", ai.string_value
    
    # Test parsing of invalid UTF-8
    data = "\012\0\0\0\07\0\0\0BlaH\0BlAh\0XYZ\0\xff"
    assert_raises(ApeTagError){ApeItem.parse(data, 0)}
  end
  
  # Test parsing of whole tags that have been monkeyed with
  def test_bad_tags
    data = EMPTY_APE_TAG.dup
    # Test default case OK
    assert_nothing_raised{ApeTag.new(StringIO.new(data)).raw}
    
    # Test footer size less than minimum size (32)
    data[44] = 31
    assert_raises(ApeTagError){ApeTag.new(StringIO.new(data)).raw}
    data[44] = 0
    assert_raises(ApeTagError){ApeTag.new(StringIO.new(data)).raw}
    
    # Test tag size > 8192, when both larger than file and smaller than file
    data[44] = 225
    data[45] = 31
    assert_raises(ApeTagError){ApeTag.new(StringIO.new(data)).raw}
    assert_raises(ApeTagError){ApeTag.new(StringIO.new(' '*8192+data)).raw}
    
    data = EMPTY_APE_TAG.dup
    # Test unmatching header and footer tag size, with footer size wrong
    data[44] = 33
    assert_raises(ApeTagError){ApeTag.new(StringIO.new(data)).raw}
    
    # Test matching header and footer but size to large for file
    data[12] = 33
    assert_raises(ApeTagError){ApeTag.new(StringIO.new(data)).raw}
    
    # Test that header and footer size isn't too large for file, but doesn't
    # find the header
    data=" #{data}"
    assert_raises(ApeTagError){ApeTag.new(StringIO.new(data)).raw}
    
    # Test unmatching header and footer tag size, with header size wrong
    data[45] = 32
    assert_raises(ApeTagError){ApeTag.new(StringIO.new(data)).raw}
    
    data = EMPTY_APE_TAG.dup
    # Test item count greater than maximum (64)
    data[48] = 65
    assert_raises(ApeTagError){ApeTag.new(StringIO.new(data)).raw}
    
    # Test item count greater than possible given tag size
    data[48] = 1
    assert_raises(ApeTagError){ApeTag.new(StringIO.new(data)).raw}
    
    # Test unmatched header and footer item count, header size wrong
    data[48] = 0
    data[16] = 1
    assert_raises(ApeTagError){ApeTag.new(StringIO.new(data)).raw}
    
    # Test unmatched header and footer item count, footer size wrong
    data = EXAMPLE_APE_TAG.dup
    data[48] -=1
    assert_raises(ApeTagError){ApeTag.new(StringIO.new(data)).fields}
    
    # Test missing/corrupt header
    data = EMPTY_APE_TAG.dup
    data[0] = 0
    assert_raises(ApeTagError){ApeTag.new(StringIO.new(data)).fields}
    
    # Test parsing bad first item size
    data = EXAMPLE_APE_TAG.dup
    data[32] +=1
    assert_raises(ApeTagError){ApeTag.new(StringIO.new(data)).fields}
    
    # Test parsing bad first item invalid key
    data = EXAMPLE_APE_TAG.dup
    data[40] = 0
    assert_raises(ApeTagError){ApeTag.new(StringIO.new(data)).fields}
    
    # Test parsing bad first item key end
    data = EXAMPLE_APE_TAG.dup
    data[45] = 1
    assert_raises(ApeTagError){ApeTag.new(StringIO.new(data)).fields}
    
    # Test parsing bad second item length too long
    data = EXAMPLE_APE_TAG.dup
    data[47] = 255
    assert_raises(ApeTagError){ApeTag.new(StringIO.new(data)).fields}

    # Test parsing case insensitive duplicate keys 
    data = EXAMPLE_APE_TAG.dup
    data[40...45] = 'Album'
    assert_raises(ApeTagError){ApeTag.new(StringIO.new(data)).fields}
    data[40...45] = 'album'
    assert_raises(ApeTagError){ApeTag.new(StringIO.new(data)).fields}
    data[40...45] = 'ALBUM'
    assert_raises(ApeTagError){ApeTag.new(StringIO.new(data)).fields}
    
    # Test parsing incorrect item counts
    data = EXAMPLE_APE_TAG.dup
    data[16] -= 1
    data[192] -= 1
    assert_raises(ApeTagError){ApeTag.new(StringIO.new(data)).fields}
    data[16] += 2
    data[192] += 2
    assert_raises(ApeTagError){ApeTag.new(StringIO.new(data)).fields}
    
    # Test updating works in case insensitive manner 
    assert_equal ['blah'], ApeTag.new(StringIO.new(EXAMPLE_APE_TAG.dup)).update{|x| x['album']='blah'}['ALBUM']
    assert_equal ['blah'], ApeTag.new(StringIO.new(EXAMPLE_APE_TAG.dup)).update{|x| x['ALBUM']='blah'}['album']
    assert_equal ['blah'], ApeTag.new(StringIO.new(EXAMPLE_APE_TAG.dup)).update{|x| x['ALbUM']='blah'}['albuM']
    
    # Test updating an existing ApeItem via various array methods
    assert_nothing_raised{ApeTag.new(StringIO.new(EXAMPLE_APE_TAG.dup)).update{|x| x['Album'] += ['blah']}}
    assert_nothing_raised{ApeTag.new(StringIO.new(EXAMPLE_APE_TAG.dup)).update{|x| x['Album'] << 'blah'}}
    assert_nothing_raised{ApeTag.new(StringIO.new(EXAMPLE_APE_TAG.dup)).update{|x| x['Album'].replace(['blah'])}}
    assert_nothing_raised{ApeTag.new(StringIO.new(EXAMPLE_APE_TAG.dup)).update{|x| x['Album'].pop}}
    assert_nothing_raised{ApeTag.new(StringIO.new(EXAMPLE_APE_TAG.dup)).update{|x| x['Album'].shift}}
    
    # Test updating with invalid value
    assert_raises(ApeTagError){ApeTag.new(StringIO.new(EMPTY_APE_TAG.dup)).update{|x| x['Album']="\xfe"}}
    
    # Test updating with invalid key
    assert_raises(ApeTagError){ApeTag.new(StringIO.new(EMPTY_APE_TAG.dup)).update{|x| x['x']=""}}
    
    # Test updating with too many items 
    assert_raises(ApeTagError){ApeTag.new(StringIO.new(EMPTY_APE_TAG.dup)).update{|x| 65.times{|i|x["blah#{i}"]=""}}}
    # Test updating with just enough items
    assert_nothing_raised{ApeTag.new(StringIO.new(EMPTY_APE_TAG.dup)).update{|x| 64.times{|i|x["blah#{i}"]=""}}}
    
    # Test updating with too large a tag
    assert_raises(ApeTagError){ApeTag.new(StringIO.new(EMPTY_APE_TAG.dup)).update{|x| x['xx']=' '*8118}}
    # Test updating with just enough tag
    assert_nothing_raised{ApeTag.new(StringIO.new(EMPTY_APE_TAG.dup)).update{|x| x['xx']=' '*8117}}
  end
  
  def test_check_id3
    x = StringIO.new()
    assert_equal 0, x.size
    
    # Test ApeTag defaults to adding id3s on file objects without ape tags
    ApeTag.new(x).update{}
    assert_equal 192, x.size
    # Test ApeTag doesn't find tag if not checking id3s and and id3 is present
    ApeTag.new(x, false).remove!
    assert_equal 192, x.size
    # Test ApeTag doesn't add id3s if ape tag exists but id3 does not
    x.truncate(64)
    assert_equal 64, x.size
    ApeTag.new(x).update{}
    assert_equal 64, x.size
    ApeTag.new(x).remove!
    assert_equal 0, x.size
    
    # Test ApeTag without checking doesn't add id3
    ApeTag.new(x, false).update{}
    assert_equal 64, x.size
    ApeTag.new(x).remove!
    assert_equal 0, x.size
    
    # Test ApeTag with explicit check_id3 argument works
    ApeTag.new(x, true).update{}
    assert_equal 192, x.size
    ApeTag.new(x, false).remove!
    assert_equal 192, x.size
    ApeTag.new(x).remove!
    assert_equal 0, x.size
    
    # Test whether check_id3 class variable works
    ApeTag.check_id3 = false
    ApeTag.new(x).update{}
    assert_equal 64, x.size
    ApeTag.new(x).remove!
    assert_equal 0, x.size
    ApeTag.check_id3 = true
    assert_raises(ApeTagError){ApeTag.check_id3 = 0}
    
    # Test non-mp3 filename defaults to no id3
    filename = 'test.apetag'
    File.new(filename,'wb').close
    ApeTag.new(filename).update{}
    assert_equal 64, get_size(filename)
    ApeTag.new(filename).remove!
    assert_equal 0, get_size(filename)
    File.delete(filename)
    
    # Test mp3 filename defaults to id3
    filename = 'test.apetag.mp3'
    File.new(filename,'wb').close
    ApeTag.new(filename).update{}
    assert_equal 192, get_size(filename)
    ApeTag.new(filename).remove!
    assert_equal 0, get_size(filename)
    File.delete(filename)
  end
end
