ApeTagFields := Object clone
ApeTagFields do(
  forward := method(
    name := call message name
    lcName := name asLowercase
    realName := self slotNames select(asLowercase == lcName) at(0)
    if(realName,
      self getSlot(realName),
      nil
    )
  )
)

ApeItem := Object clone
ApeItem do(
  flags := nil
  key := nil
  values := nil
  readOnly := nil
  invalidKeys := list("id3", "tag", "oggs", "mp+")

  check := method(
    if(flags == 0 or flags == 2,
      values foreach(v,
        if(v != v asMutable setEncoding("utf8") asUCS4 asUTF8,
          Exception raise("ApeTag: non-UTF8 character found in item value")
        )
      )
    )
    if (key size < 2,
      Exception raise("ApeTag: item key too short")
    )
    if (key size > 255,
      Exception raise("ApeTag: item key too long")
    )
    if (invalidKeys contains(key asLowercase),
      Exception raise("ApeTag: invalid item key character")
    )
    key foreach(v,
      if(v <= 0x1f or v >= 0x80,
        Exception raise("ApeTag: invalid item key character")
      )
    )
    if (flags < 0 or flags > 3,
      Exception raise("ApeTag: invalid item type")
    )
  )

  _fromParse := method(flags, key, data,
    item := ApeItem clone
    item flags = flags >>(1)
    item readOnly = flags bitwiseAnd(1) > 0
    item key = key
    item values = data split(ApeTag ASCII_NUL)
    if(item values == list(),
      item values = list("" asMutable)
    )
    item check
    item
  )

  raw := method(
    rawValues := values join(ApeTag ASCII_NUL)
    ApeTag _pack4le(rawValues size) .. ApeTag _pack4be((flags <<(1)) + if(readOnly, 1, 0)) .. key .. ApeTag ASCII_NUL .. rawValues
  )
)

ApeTag := Object clone
ApeTag do(
  PREAMBLE := "APETAGEX" .. list(0xD0, 7, 0, 0) map(asCharacter) join
  HEADER_FLAGS := list(0, 0, 0xa0) map(asCharacter) join
  FOOTER_FLAGS := list(0, 0, 0x80) map(asCharacter) join
  MAX_SIZE := 8192
  MAX_ITEM_COUNT := 64
  ASCII_NUL := list(0 asCharacter) join
  SAVE_SLOTS := list("_file", "filename", "checkId3")
  EMPTY8 := ASCII_NUL repeated(8)
  ID3_GENRES := list("Blues", "Classic Rock", "Country", "Dance", "Disco", "Funk", "Grunge",
    "Hip-Hop", "Jazz", "Metal", "New Age", "Oldies", "Other", "Pop", "R & B", "Rap", "Reggae",
    "Rock", "Techno", "Industrial", "Alternative", "Ska", "Death Metal", "Prank", "Soundtrack",
    "Euro-Techno", "Ambient", "Trip-Hop", "Vocal", "Jazz + Funk", "Fusion", "Trance",
    "Classical", "Instrumental", "Acid", "House", "Game", "Sound Clip", "Gospel", "Noise",
    "Alternative Rock", "Bass", "Soul", "Punk", "Space", "Meditative", "Instrumental Pop",
    "Instrumental Rock", "Ethnic", "Gothic", "Darkwave", "Techno-Industrial", "Electronic",
    "Pop-Fol", "Eurodance", "Dream", "Southern Rock", "Comedy", "Cult", "Gangsta", "Top 40",
    "Christian Rap", "Pop/Funk", "Jungle", "Native US", "Cabaret", "New Wave", "Psychadelic",
    "Rave", "Showtunes", "Trailer", "Lo-Fi", "Tribal", "Acid Punk", "Acid Jazz", "Polka",
    "Retro", "Musical", "Rock & Roll", "Hard Rock", "Folk", "Folk-Rock", "National Folk",
    "Swing", "Fast Fusion", "Bebop", "Latin", "Revival", "Celtic", "Bluegrass", "Avantgarde",
    "Gothic Rock", "Progressive Rock", "Psychedelic Rock", "Symphonic Rock", "Slow Rock",
    "Big Band", "Chorus", "Easy Listening", "Acoustic", "Humour", "Speech", "Chanson", "Opera",
    "Chamber Music", "Sonata", "Symphony", "Booty Bass", "Primus", "Porn Groove", "Satire",
    "Slow Jam", "Club", "Tango", "Samba", "Folklore", "Ballad", "Power Ballad", "Rhytmic Soul",
    "Freestyle", "Duet", "Punk Rock", "Drum Solo", "Acapella", "Euro-House", "Dance Hall",
    "Goa", "Drum & Bass", "Club-House", "Hardcore", "Terror", "Indie", "BritPop", "Negerpunk",
    "Polsk Punk", "Beat", "Christian Gangsta Rap", "Heavy Metal", "Black Metal",
    "Crossover", "Contemporary Christian", "Christian Rock", "Merengue", "Salsa",
    "Thrash Metal", "Anime", "Jpop", "Synthpop") map(asLowercase)

  filename := nil
  _hasId3 := nil
  _hasApe := nil
  _gotInfo := false
  _file := nil
  _filesize := nil
  _tagStart := nil
  _tagSize := nil
  _tagData := nil
  _itemCount := nil
  _fields := nil

  _ensure := method(
    e := try(call evalArgAt(0))
    call evalArgAt(1)
    e ifNonNil(e pass)
  )

  _unpack4le := method(seq,
    seq asStruct(list("uint32", "x")) x
  )

  _unpack4be := method(seq,
    _unpack4le(seq reverse)
  )

  _pack4le := method(num,
    num asUint32Buffer
  )

  _pack4be := method(num,
    _pack4le(num) reverse
  )

  _withFile := method(accessType,
    if(_file, return(call evalArgAt(1)))
    self _file = File with(filename)
    if(accessType == "write",
      _file openForUpdating,
      _file openForReading
    )
    _ensure(call evalArgAt(1),
      _file close
      self _file = nil)
  )

  _id3Length := method(
    if(_hasId3, 128, 0)
  )

  _getInfo := method(
    if(_gotInfo, return)
    _withFile("read",
      self _gotInfo = true
      self _filesize = _file size

      if(_filesize < 64,
        self _hasId3 = false
        self _hasApe = false
        self _tagStart = _filesize
        return
      )

      if(_filesize < 128 or checkId3 == false,
        self _hasId3 = false,
      # else
        _file setPosition(_filesize - 128)
        self _hasId3 = (_file readStringOfLength(3) == "TAG")
        if (hasId3 and _filesize < 192,
          self _hasApe = false
          self _tagStart = _filesize - _id3Length
          return
        )
      )

      _file setPosition(_filesize - 32 - _id3Length)
      footer := _file readStringOfLength(32)
      if(footer beginsWithSeq(PREAMBLE) not,
        self _hasApe = false
        self _tagStart = _filesize - _id3Length
        return
      )

      if((list(0, 1) contains(footer at(20)) and footer exclusiveSlice(21, 24) == FOOTER_FLAGS) not,
        Exception raise("ApeTag: bad APE footer flags")
      )

      size := _unpack4le(footer exclusiveSlice(12, 16)) 
      self _tagSize = size + 32
      self _itemCount = _unpack4le(footer exclusiveSlice(16, 20))

      if(_tagSize < 64,
        Exception raise("ApeTag: tag size smaller than minimum size")
      )
      if(_tagSize > MAX_SIZE,
        Exception raise("ApeTag: tag size larger than maximum allowed")
      )
      if(_tagSize + _id3Length > _filesize,
        Exception raise("ApeTag: tag size larger than possible")
      )
      if(_itemCount > MAX_ITEM_COUNT,
        Exception raise("ApeTag: tag item count larger than maximum allowed")
      )
      if(_itemCount > (_tagSize - 64)/11,
        Exception raise("ApeTag: tag item count larger than possible")
      )

      self _tagStart := _filesize - _tagSize - _id3Length
      _file setPosition(_tagStart)
      header := _file readStringOfLength(32)

      if((header beginsWithSeq(PREAMBLE) and list(0, 1) contains(header at(20)) and header exclusiveSlice(21, 24) == HEADER_FLAGS) not,
        Exception raise("ApeTag: missing or corrupt tag header")
      )
      if(_tagSize != _unpack4le(header exclusiveSlice(12, 16)) + 32,
        Exception raise("ApeTag: header size does not match footer size")
      )
      if(_itemCount != _unpack4le(header exclusiveSlice(16, 20)),
        Exception raise("ApeTag: header item count does not match footer item count")
      )

      self _tagData = _file readStringOfLength(_tagSize - 64)
      self _hasApe = true
    )
  )

  _getFields := method(
    if(_fields, return)
    _getInfo
    if(hasApe == false or _tagData == nil,
      self _fields := Object clone
      return
    )

    fields := Object clone
    offset := 0
    length := nil
    flags := nil
    keyEnd := nil
    nextStart := nil
    key := nil
    lcKey := nil
    data := _tagData
    dataLen := data sizeInBytes
    lastItemStart := dataLen - 11

    for(i, 1, _itemCount, 
      if(offset > lastItemStart,
        Exception raise("end of tag reached without parsing all items")
      )
      length = _unpack4le(data exclusiveSlice(offset, offset+4))
      flags = _unpack4be(data exclusiveSlice(offset+4, offset+8))
      if(length + offset + 11 > dataLen,
        Exception raise("ApeTag: invalid item length")
      )
      if(flags > 7,
        Exception raise("ApeTag: invalid item flags")
      )
      offset = offset + 8
      keyEnd = data findSeq(ASCII_NUL, offset)
      if(keyEnd == nil,
        Exception raise("ApeTag: missing key-value separator")
      )
      nextStart = length + keyEnd + 1
      if(nextStart > dataLen,
        Exception raise("ApeTag: invalid item length")
      )
      key = data exclusiveSlice(offset, keyEnd)
      lcKey = key asLowercase
      if(fields getSlot(lcKey),
        Exception raise("ApeTag: duplicate item key")
      )
      fields setSlot(lcKey, ApeItem _fromParse(flags, key, data exclusiveSlice(keyEnd+1, nextStart)))
      offset = nextStart
    )
    if(offset != dataLen,
      Exception raise("ApeTag: data remaining after specified number of items parsed")
    )

    self _fields := fields
  )

  _clear := method(
    slotNames select(v, SAVE_SLOTS contains(v) == false) foreach(v,
      self removeSlot(v)
    )
  )

  _rawApe := method(
    sortedItems := items sortBy(block(a,b,
      v := a raw size compare(b raw size)
      if(v == 0,
        a key < b key,
        v < 0
      )
    ))
    rawItems := sortedItems map(raw) join
    rawSize := rawItems size + 32
    itemCount := sortedItems size

    if(rawSize + 32 > MAX_SIZE,
      Exception raise("tag is larger than max allowed size")
    )
    if(itemCount > MAX_ITEM_COUNT,
      Exception raise("tag has more than max allowed items")
    )

    start := PREAMBLE  .. _pack4le(rawSize) .. _pack4le(itemCount)
    start .. ASCII_NUL .. HEADER_FLAGS .. EMPTY8 .. rawItems .. start .. ASCII_NUL .. FOOTER_FLAGS .. EMPTY8
  )

  _padr := method(length, seq,
    if(seq == nil,
      seq = "",
      seq = seq join
    )
    if(seq sizeInBytes >= length,
      seq exclusiveSlice(0, length),
      seq .. ASCII_NUL repeated(length - seq sizeInBytes)
    )
  )

  _rawId3 := method(
    if(_hasId3 or checkId3,
      track := fields track
      if(track,
        track = track join asNumber
      )
      track = if(track >= 0 and track <= 255,
        track asCharacter,
        ASCII_NUL
      )

      genre := fields genre
      if (genre,
        genre := ID3_GENRES indexOf(genre join asLowercase)
      )
      if(genre == nil,
        genre = 255
      )
      genre = genre asCharacter

      year := fields year
      if(year == nil and fields date,
        date := ""
        numbers := "0123456789" asList
        fields date join asList foreach(v,
          if(numbers contains(v),
            date = date .. v,
            date = ""
          )
          if(date size == 4,
            year = list(date)
            break
          )
        )
      )

      "TAG" .. _padr(30, fields title) .. _padr(30, fields artist) .. _padr(30, fields album) .. _padr(4, year) .. _padr(28, fields comment) .. ASCII_NUL .. track .. genre 
      ,
      ""
    )
  )

  withFile := method(filename,
    tag := self clone
    if(filename type == "File",
      tag _file = filename,
      tag filename = filename
    )
    return tag
  )

  checkId3 := method(
    if(filename,
      if(filename endsWithSeq(".mp3"),
        true,
        nil
      ),
      nil
    )
  )

  hasId3 := method(
    _getInfo
    _hasId3
  )

  hasApe := method(
    _getInfo
    _hasApe
  )

  fields := method(
    _getFields
    fields := ApeTagFields clone 
    _fields slotNames foreach(name,
      item := _fields getSlot(name)
      fields setSlot(item key, item values)
    )
    fields
  )

  items := method(
    _getFields
    items := list
    _fields slotNames foreach(name,
      items append(_fields getSlot(name))
    )
    items
  )

  removeTag := method(
    _getInfo
    if(hasApe or hasId3,
      _withFile("write",
        _file truncateToSize(_tagStart)
      )
      _clear
      true,
      false
    )
    self
  )

  removeItem := method(key,
    _getFields
    _fields removeSlot(key asLowercase)
    self
  )

  addItem := method(key, values, flags, readOnly,
    _getFields
    item := ApeItem clone
    item key = key
    item values = if(values type != "List",
      list(values),
      values
    )
    item flags = if(flags,
      flags,
      0
    )
    item readOnly = if(readOnly,
      readOnly,
      false
    )
    item check
    _fields setSlot(key asLowercase, item)
    self
  )

  update := method(
    _getFields
    raw := _rawApe .. _rawId3
    _withFile("write",
      _file truncateToSize(_tagStart)
      _file setPosition(_tagStart)
      _file write(raw)
    )
    _clear
    self
  )
)
