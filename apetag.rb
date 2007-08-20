#!/usr/bin/env ruby
# This library implements a APEv2 parser/generator.
# If called from the command line, it prints out the contents of the APEv2 tag 
# for the given filename arguments.
#
# ruby-apetag is a pure Ruby library for manipulating APEv2 tags.
# It aims for standards compliance with the APE spec (1). APEv2 is the standard
# tagging format for Musepack (.mpc) and Monkey's Audio files (.ape), and it can
# also be used with mp3s as an alternative to ID3v2.x (technically, it can be 
# used on any file type and is not limited to storing just audio file metadata).
#
# The module is in written in pure Ruby, so it should be useable on all 
# platforms that Ruby supports.  It is developed and tested on OpenBSD.  
# The minimum Ruby version required should be 1.8, but it has only been tested
# on 1.8.4+.  Modifying the code to work with previous version shouldn't be
# difficult, though there aren't any plans to do so.
#
# General Use:
#
#  require 'apetag'
#  a = ApeTag.new('file.mp3')
#  a.exists? # if it already has an APEv2 tag
#  a.raw # the raw APEv2+ID3v1.1 tag string in the file
#  a.fields # a CICPHash of fields, keys are strings, values are list of strings
#  a.pretty_print # string suitable for pretty printing
#  a.update{|fields| fields['Artist']='Test Artist'; fields.delete('Year')}
#   # Update the tag with the added/changed/deleted fields
#   # Note that you should do: a.update{|fields| fields.replace('Test'=>'Test')}
#   # and NOT: a.update{|fields| fields = {'Test'=>'Test'}}
#   # You need to update/modify the fields given, not reassign it
#  a.remove! # remove the APEv2 and ID3v1.1 tags.
#
# To run the tests for the library, run test_apetag.rb.
#
# If you find any bugs, would like additional documentation, or want to submit a
# patch, please use Rubyforge (http://rubyforge.org/projects/apetag/).
#
# The most current source code can be accessed via anonymous SVN at 
# svn://code.jeremyevans.net/ruby-apetag/.  Note that the library isn't modified
# on a regular basis, so it is unlikely to be different from the latest release.
#
# (1) http://wiki.hydrogenaudio.org/index.php?title=APEv2_specification
#
# Copyright (c) 2007 Jeremy Evans
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

require 'set'
require 'cicphash'

# Error raised by the library
class ApeTagError < StandardError
end

# The individual items in the APE tag.
# Because all items can contain a list of values, this is a subclass of Array.
class ApeItem < Array
  MIN_SIZE = 11 # 4+4+2+1 (length, flags, minimum key length, key-value separator)
  BAD_KEY_RE = /[\0-\x1f\x80-\xff]|\A(?:id3|tag|oggs|mp\+)\z/i
  ITEM_TYPES = %w'utf8 binary external reserved'
  
  attr_reader :read_only, :ape_type, :key
  
  # Creates an APE tag with the appropriate key and value.
  # If value is a valid ApeItem, just updates the key.
  # If value is an Array, creates an ApeItem with the key and all of its values.
  # Otherwise, creates an ApeItem with the key and the singular value.
  # Raise ApeTagError if key or or value is invalid.
  def self.create(key, value)
    if value.is_a?(self) && value.valid?
      value.key = key
      return value
    end
    value = [value] unless value.is_a?(Array)
    new(key, value)
  end
  
  # Parse an ApeItem from the given data string starting at the provided offset.
  # Check for validity and populate the object with the parsed data.
  # Return the offset of the next item (or end of string).
  # Raise ApeTagError if the parsed data is invalid.
  def self.parse(data, offset)
    length, flags = data[offset...(offset+8)].unpack('VN')
    raise ApeTagError, "Invalid item length at offset #{offset}" if length + offset + MIN_SIZE > data.length
    raise ApeTagError, "Invalid item flags at offset #{offset}" if flags > 7
    key_end = data.index("\0", offset += 8)
    raise ApeTagError, "Missing key-value separator at offset #{offset}" unless key_end
    raise ApeTagError, "Invalid item length at offset #{offset}" if (next_item_start=length + key_end + 1) > data.length
    item = ApeItem.new(data[offset...key_end], data[(key_end+1)...next_item_start].split("\0"))
    item.read_only = flags & 1 > 0
    item.ape_type = ITEM_TYPES[flags/2]
    return [item, next_item_start]
  end
  
  # Set key and value.
  # Set read_only to false and ape_type to utf8.
  # Raise ApeTagError if key or value is invalid.
  def initialize(key, value)
    self.key = key
    self.read_only = false
    self.ape_type = ITEM_TYPES[0]
    super(value)
    raise ApeTagError, "Invalid item value encoding (non UTF-8)" unless valid_value?
  end
  
  # Set ape_type if valid, otherwise raise ApeTagError.
  def ape_type=(type)
    raise ApeTagError, "Invalid APE type" unless valid_ape_type?(type)
    @ape_type=type
  end
  
  # Set key if valid, otherwise raise ApeTagError.
  def key=(key)
    raise ApeTagError, "Invalid APE key" unless valid_key?(key)
    @key = key
  end
  
  # The on disk representation of the entire ApeItem.
  # Raise ApeTagError if ApeItem is invalid.
  def raw
    raise ApeTagError, "Invalid key, value, APE type, or Read-Only Flag" unless valid? 
    flags = ITEM_TYPES.index(ape_type) * 2 + (read_only ? 1 : 0)
    sv = string_value
    "#{[sv.length, flags].pack('VN')}#{key}\0#{sv}"
  end
  
  # Set read only flag if valid, otherwise raise ApeTagError.
  def read_only=(flag)
    raise ApeTagError, "Invalid Read-Only Flag" unless valid_read_only?(flag)
    @read_only = flag
  end
  
  # The on disk representation of the ApeItem's values.
  def string_value
    join("\0")
  end
  
  # Check if current item is valid
  def valid?
    valid_ape_type?(ape_type) && valid_read_only?(read_only) && valid_key?(key) && valid_value?
  end
  
  # Check if given type is a valid APE type (a member of ApeItem::ITEM_TYPES).
  def valid_ape_type?(type)
    ITEM_TYPES.include?(type)
  end
  
  # Check if the given key is a valid APE key (string, 2 <= length <= 255, not containing invalid characters or keys).
  def valid_key?(key)
    key.is_a?(String) && key.length >= 2 && key.length <= 255 && key !~ BAD_KEY_RE
  end
  
  # Check if the given read only flag is valid (boolean).
  def valid_read_only?(flag)
    [true, false].include?(flag)
  end
  
  # Check if the string value is valid UTF-8.
  def valid_value?
    begin
      string_value.unpack('U*') if ape_type == 'utf8' || ape_type == 'external'
    rescue ArgumentError
      false
    else
      true
    end
  end
end

# Contains all of the ApeItems found in the filename/file given.
# MAX_SIZE and MAX_ITEM_COUNT constants are recommended defaults, they can be
# increased if necessary.
class ApeTag
  MAX_SIZE = 8192
  MAX_ITEM_COUNT = 64
  HEADER_FLAGS = "\x00\x00\x00\xA0"
  FOOTER_FLAGS = "\x00\x00\x00\x80"
  PREAMBLE = "APETAGEX\xD0\x07\x00\x00"
  RECOMMENDED_KEYS = %w'Title Artist Album Year Comment Genre Track Subtitle
    Publisher Conductor Composer Copyright Publicationright File EAN/UPC ISBN
    Catalog LC Media Index Related ISRC Abstract Language Bibliography
    Introplay Dummy' << 'Debut Album' << 'Record Date' << 'Record Location'
  ID3_GENRES = 'Blues, Classic Rock, Country, Dance, Disco, Funk, Grunge, 
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
    Trash Meta, Anime, Jpop, Synthpop'.split(',').collect{|g| g.strip}
  ID3_GENRES_HASH = CICPHash.new(255.chr)
  ID3_GENRES.each_with_index{|g,i| ID3_GENRES_HASH[g] = i.chr }
  FILE_OBJ_METHODS = %w'close seek read pos write truncate'
  YEAR_RE = Regexp.new('\d{4}')
  MP3_RE = Regexp.new('\.mp3\z')
  
  @@check_id3 = true
  
  attr_reader :filename, :file, :tag_size, :tag_start, :tag_data, :tag_header, :tag_footer, :tag_item_count, :check_id3
  
  # Set whether to check for id3 tags by default on file objects (defaults to true)
  def self.check_id3=(flag)
    raise ApeTagError, "check_id3 must be boolean" unless [true, false].include?(flag)
    @@check_id3 = flag
  end
  
  # Set the filename or file object to operate on.  If the object has all methods
  # in FILE_OBJ_METHODS, it is treated as a file, otherwise, it is treated as a filename.
  # If the filename is invalid, Errno::ENOENT or Errno::EINVAL will probably be raised when calling methods.
  # Optional argument check_id3 checks for ID3 tags.
  # If check_id3 is not specified and filename is a file object, the ApeTag default is used.
  # If check_id3 is not specified and filename is a filename, it checks for ID3 tags only if 
  # the filename ends with ".mp3".
  # If files have APE tags but no ID3 tags, ID3 tags will never be added.
  # If files have neither tag, check_id3 will decide whether to add an ID3 tag.
  # If files have both tags, make sure check_id3 is true or it will miss both tags.
  def initialize(filename, check_id3 = nil)
    if FILE_OBJ_METHODS.each{|method| break unless filename.respond_to?(method)}
      @file = filename
      @check_id3 = check_id3.nil? ? @@check_id3 : check_id3 
    else
      @filename = filename.to_s
      @check_id3 = check_id3 unless check_id3.nil?
      @check_id3 = !MP3_RE.match(@filename).nil? if @check_id3.nil?
    end
  end
  
  # Check the file for an APE tag.  Returns true or false. Raises ApeTagError for corrupt tags.  
  def exists?
    @has_tag.nil? ? access_file('rb'){has_tag} : @has_tag
  end
  
  # Remove an APE tag from a file, if one exists.
  # Returns true.  Raises ApeTagError for corrupt tags.
  def remove!
    access_file('rb+'){file.truncate(tag_start) if has_tag}
    @has_tag, @fields, @id3, @tag_size, @tag_start, @tag_data, @tag_header, @tag_footer, @tag_item_count = []
    true
  end
  
  # A CICPHash of ApeItems found in the file, or an empty CICPHash if the file
  # doesn't have an APE tag.  Raises ApeTagError for corrupt tags.
  def fields
    @fields || access_file('rb'){get_fields}
  end
  
  # Pretty print tags, with one line per field, showing key and value.
  def pretty_print
    begin
      fields.values.sort_by{|value| value.key}.collect{|value| "#{value.key}: #{value.join(', ')}"}.join("\n")
    rescue ApeTagError
      "CORRUPT TAG!"
    rescue Errno::ENOENT, Errno::EINVAL
      "FILE NOT FOUND!"
    end
  end
  
  # The raw APEv2 + ID3v1.1 tag.  If one or the other is empty that part will be missing.
  # Raises ApeTagError for corrupt tags.
  def raw
    exists? 
    "#{tag_header}#{tag_data}#{tag_footer}#{id3}"
  end
  
  # Yields a CICPHash of ApeItems found in the file, or an empty CICPHash if the file
  # doesn't have an APE tag.  This hash should be modified (not reassigned) inside
  # the block.  An APEv2+ID3v1.1 tag with the new fields will overwrite the previous
  # tag.  If the file doesn't have an APEv2 tag, one will be created and appended to it.
  # If the file doesn't have an ID3v1.1 tag, one will be generated from the ApeTag fields
  # and appended to it.  If the file already has an ID3v1.1 tag, the data in it is ignored,
  # and it is overwritten.  Raises ApeTagError if either the existing tag is invalid
  # or the tag to be written would be invalid.
  def update(&block)
    access_file('rb+') do 
      yield get_fields
      normalize_fields
      update_id3
      update_ape
      write_tag
    end
    fields
  end
  
  private
    # If working with a file object, yield the object.
    # If working with a filename, open the file to be accessed using the correct mode,
    # yield the file.  Return the value returned by the block passed.
    def access_file(how, &block)
      if @filename
        File.open(filename, how) do |file|
          @file = file
          return_value = yield
          @file.close
          @file = nil
          return_value
        end
      else
        yield
      end
    end  
    
    # If working with a filename, use the file system's size for that filename.
    # If working with a file that has a size method (e.g. StringIO), call that.
    # Otherwise, seek to the end of the file and return the position.
    def file_size
      if @filename
        File.size(filename)
      elsif file.respond_to?(:size)
        file.size
      else
        file.seek(0, IO::SEEK_END) && file.pos
      end
    end
    
    # Parse the raw tag data to get the tag fields (a hash of ApeItems), or an empty hash
    # if the file has no APE tag.
    def get_fields
      return @fields if @fields
      return @fields = CICPHash.new unless has_tag
      ape_items = CICPHash.new
      offset = 0
      last_possible_item_start = tag_data.length - ApeItem::MIN_SIZE
      tag_item_count.times do
        raise ApeTagError, "End of tag reached but more items specified" if offset > last_possible_item_start
        item, offset = ApeItem.parse(tag_data, offset)
        raise ApeTagError, "Multiple items with same key (#{item.key.inspect})" if ape_items.include?(item.key)
        ape_items[item.key] = item
      end
      raise ApeTagError, "Data remaining after specified number of items parsed" if offset != tag_data.length
      @fields = ape_items
    end
    
    # Get various information about the tag (if it exists), and check it for validity if a tag is present.
    def get_tag_information
      unless file_size >= id3.length + 64 
        @has_tag = false
        @tag_start = file_size - id3.length
        return
      end
      file.seek(-32-id3.length, IO::SEEK_END)
      tag_footer = file.read(32)
      unless tag_footer[0...12] == PREAMBLE && tag_footer[20...24] == FOOTER_FLAGS
        @has_tag = false
        @tag_start = file_size - id3.length
        return
      end
      @tag_footer = tag_footer
      @tag_size, @tag_item_count = tag_footer[12...20].unpack('VV')
      @tag_size += 32
      raise ApeTagError, "Tag size (#{tag_size}) smaller than minimum size" if tag_size < 64 
      raise ApeTagError, "Tag size (#{tag_size}) larger than possible" if tag_size + id3.length > file_size
      raise ApeTagError, "Tag size (#{tag_size}) is larger than #{MAX_SIZE}" if tag_size > MAX_SIZE
      raise ApeTagError, "Item count (#{tag_item_count}) is larger than #{MAX_ITEM_COUNT}" if tag_item_count > MAX_ITEM_COUNT
      raise ApeTagError, "Item count (#{tag_item_count}) is larger than possible" if tag_item_count > (tag_size-64)/ApeItem::MIN_SIZE
      file.seek(-tag_size-id3.length, IO::SEEK_END)
      @tag_start=file.pos
      @tag_header=file.read(32)
      @tag_data=file.read(tag_size-64)
      raise ApeTagError, "Missing header" unless tag_header[0...12] == PREAMBLE && tag_header[20...24] == HEADER_FLAGS
      raise ApeTagError, "Header and footer size does match" unless tag_size == tag_header[12...16].unpack('V')[0] + 32
      raise ApeTagError, "Header and footer item count does match" unless tag_item_count == tag_header[16...20].unpack('V')[0]
      @has_tag = true
    end
    
    # Check if the file has a tag or not
    def has_tag
      return @has_tag unless @has_tag.nil?
      get_tag_information
      @has_tag
    end
    
    # Get the raw id3 string for the file (this is ignored).
    # If check_id3 is false, it doesn't check for the ID3, which means that
    # the APE tag will probably not be recognized if the file ends with an ID3 tag.
    def id3
      return @id3 unless @id3.nil?
      return @id3 = '' if file_size < 128 || check_id3 == false
      file.seek(-128, IO::SEEK_END)
      data = file.read(128)
      @id3 = data[0...3] == 'TAG' ? data : ''
    end
    
    # Turn fields hash from a hash of arbitrary objects to a hash of ApeItems
    # Check that multiple identical keys are not present.
    def normalize_fields
      new_fields = CICPHash.new
      fields.each do |key, value|
        new_fields[key] = ApeItem.create(key, value)
      end
      @fields = new_fields
    end
    
    # Update internal variables to reflect the new APE tag.  Check that produced
    # tag is still valid.
    def update_ape
      entries = fields.values.collect{|value| value.raw}.sort{|a,b| x = a.length <=> b.length; x != 0 ? x : a <=> b}
      @tag_data = entries.join
      @tag_item_count = entries.length
      @tag_size = tag_data.length + 64
      base_start = "#{PREAMBLE}#{[tag_size-32, tag_item_count].pack('VV')}"
      base_end = "\0"*8
      @tag_header = "#{base_start}#{HEADER_FLAGS}#{base_end}"
      @tag_footer = "#{base_start}#{FOOTER_FLAGS}#{base_end}"
      raise ApeTagError, "Updated tag has too many items (#{tag_item_count})" if tag_item_count > MAX_ITEM_COUNT
      raise ApeTagError, "Updated tag too large (#{tag_size})" if tag_size > MAX_SIZE
    end
    
    # Update the ID3v1.1 tag variable to use the fields from the APEv2 tag.
    # If the file doesn't have an ID3 and the file already has an APE tag or
    # check_id3 is not set, an ID3 won't be added.
    def update_id3
      return if id3.length == 0 && (has_tag || check_id3 == false)
      id3_fields = CICPHash.new('')
      id3_fields['genre'] = 255.chr
      fields.values.each do |value|
        case value.key
          when /\Atrack/i
            id3_fields['track'] = value.string_value.to_i
            id3_fields['track'] = 0 if id3_fields['track'] > 255
            id3_fields['track'] = id3_fields['track'].chr
          when /\Agenre/i
            id3_fields['genre'] = ID3_GENRES_HASH[value.first]
          when /\Adate\z/i
            match = YEAR_RE.match(value.string_value)
            id3_fields['year'] = match[0] if match 
          when /\A(title|artist|album|year|comment)\z/i
            id3_fields[value.key] = value.join(', ')
        end
      end
      @id3 = ["TAG", id3_fields['title'], id3_fields['artist'], id3_fields['album'],
              id3_fields['year'], id3_fields['comment'], "\0", id3_fields['track'],
              id3_fields['genre']].pack("a3a30a30a30a4a28a1a1a1")
    end
    
    # Write the APEv2 and ID3v1.1 tags to disk.
    def write_tag
      file.seek(tag_start, IO::SEEK_SET)
      file.write(raw)
      file.truncate(file.pos)
      @has_tag = true
    end
end

# If called directly from the command line, treat all arguments as filenames, and pretty print the APE tag's fields for each filename.
if __FILE__ == $0
  ARGV.each do |filename| 
    puts filename, '-'*filename.length, ApeTag.new(filename).pretty_print, ''
  end
end
