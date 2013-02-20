module ApeTag
( ApeItem
, ApeItemFlag(..)
, ApeTag
, ApeParseError(..)
, fromString
, fromHandle
, fromFile
, removeFromHandle
, removeFromFile
, apeItemKV1
, apeItemKV
, apeItem
, fileHasID3
, fileHasAPE
, handleHasID3
, handleHasAPE
, kvMapFromTag
, kv1MapFromTag
, addApeItem
, removeApeItem
, toHandle
, toHandleWithID3
, toFile
, toFileWithID3
) where

-- Imports

import Text.ParserCombinators.Parsec (GenParser, ParseError, count, anyChar,
       many, noneOf, oneOf, string, char, getState, setState, runParser)
import Data.Char (toLower, chr, ord, isDigit)
import qualified Data.Char as Char
import Data.Bits ((.&.), shift)
import Data.List (sortBy, intercalate)
import System.IO (hSeek, hGetChar, hFileSize, openFile, hClose, hPutStr,
       SeekMode (SeekFromEnd), Handle, IOMode (ReadMode, ReadWriteMode), hTell, hSetFileSize)
import Codec.Binary.UTF8.String (isUTF8Encoded)
import qualified Data.Map as Map

-- Types

-- |The data structure used for storing APE items.
-- Each item has a String itemKey, and a List of String itemValues.
-- There is also an itemFlags attribute that gives the type of the
-- item (e.g. UTF-8 or binary), as well as a read-only setting.
data ApeItem = ApeItem { itemKey :: String
                       , itemValues :: [String]
                       , itemFlags :: ApeItemFlag
                       , itemReadOnly :: Bool
                       } deriving (Show, Eq, Ord)
data ApeParseState = ApeParseState { totalSize :: Int
                                   , totalItems :: Int
                                   , remainingSize :: Int
                                   , remainingItems :: Int
                                   , itemSize :: Int
                                   , stateTag :: ApeTag
                                   } deriving (Show)
-- |Abstract data type representing different types of errors.
-- ApeParsecErrors are used if the tag cannot be parsed because it is
-- not correctly formed.  ApeParseErrors are used if the tag is
-- invalid for other reasons (such as going over the allowed size or
-- number of items).  NoApeTag is used if there was no tag in the file.
data ApeParseError = ApeParsecError ParseError | ApeParseError String | NoApeTag String deriving (Show)

-- |A flag value that notates the type of the item.
-- FlagUTF8 is the most common, used for plain text in UTF-8 format.
-- FlagBinary is used for binary data.
-- FlagExternal is used if the values point to an external location for
-- the data (in which case the values should be in UTF-8 format).
-- FlagReserved shouldn't be used.
data ApeItemFlag = FlagUTF8 | FlagBinary | FlagExternal | FlagReserved deriving (Show, Eq, Ord)

-- |The primary data type used by the library, a simple map of lowercase
-- String keys to ApeItem values.
type ApeTag = Map.Map String ApeItem

-- |Data type returned by kvMapFromTag, giving a map of String keys to
-- List of value Strings.
type ApeMap = Map.Map String [String]

-- |Data type returned by kv1MapFromTag, giving a map of String keys to
-- a single value String.  If the related item has multiple values they
-- will be joined into a single value using ", ".
type ApeMap1 = Map.Map String String

-- |Maps ID3 Genre strings to an Int, used when generating ID3 tags for
-- an ApeTag.
type ID3Genres = Map.Map String Int

-- Constants

_buildID3Genres :: Int -> [String] -> ID3Genres -> ID3Genres
_buildID3Genres _ [] a = a
_buildID3Genres i (s:ss) a = _buildID3Genres (i + 1) ss $ Map.insert s i a
buildID3Genres ss = _buildID3Genres 0 ss Map.empty

id3Genres = buildID3Genres ["Blues", "Classic Rock", "Country", "Dance", "Disco", "Funk", "Grunge", "Hip-Hop", "Jazz", "Metal", "New Age", "Oldies", "Other", "Pop", "R & B", "Rap", "Reggae", "Rock", "Techno", "Industrial", "Alternative", "Ska", "Death Metal", "Prank", "Soundtrack", "Euro-Techno", "Ambient", "Trip-Hop", "Vocal", "Jazz + Funk", "Fusion", "Trance", "Classical", "Instrumental", "Acid", "House", "Game", "Sound Clip", "Gospel", "Noise", "Alternative Rock", "Bass", "Soul", "Punk", "Space", "Meditative", "Instrumental Pop", "Instrumental Rock", "Ethnic", "Gothic", "Darkwave", "Techno-Industrial", "Electronic", "Pop-Fol", "Eurodance", "Dream", "Southern Rock", "Comedy", "Cult", "Gangsta", "Top 40", "Christian Rap", "Pop/Funk", "Jungle", "Native US", "Cabaret", "New Wave", "Psychadelic", "Rave", "Showtunes", "Trailer", "Lo-Fi", "Tribal", "Acid Punk", "Acid Jazz", "Polka", "Retro", "Musical", "Rock & Roll", "Hard Rock", "Folk", "Folk-Rock", "National Folk", "Swing", "Fast Fusion", "Bebop", "Latin", "Revival", "Celtic", "Bluegrass", "Avantgarde", "Gothic Rock", "Progressive Rock", "Psychedelic Rock", "Symphonic Rock", "Slow Rock", "Big Band", "Chorus", "Easy Listening", "Acoustic", "Humour", "Speech", "Chanson", "Opera", "Chamber Music", "Sonata", "Symphony", "Booty Bass", "Primus", "Porn Groove", "Satire", "Slow Jam", "Club", "Tango", "Samba", "Folklore", "Ballad", "Power Ballad", "Rhytmic Soul", "Freestyle", "Duet", "Punk Rock", "Drum Solo", "Acapella", "Euro-House", "Dance Hall", "Goa", "Drum & Bass", "Club-House", "Hardcore", "Terror", "Indie", "BritPop", "Negerpunk", "Polsk Punk", "Beat", "Christian Gangsta Rap", "Heavy Metal", "Black Metal", "Crossover", "Contemporary Christian", "Christian Rock", "Merengue", "Salsa", "Thrash Metal", "Anime", "Jpop", "Synthpop"]

apePreamble = "APETAGEX\208\7\0\0"
apeHeaderFlags = "\0\0\160"
apeFooterFlags = "\0\0\128"

-- |The maximum size allowed for tags.  The library will not read nor
-- write tags longer than this.
apeMaxSize = 8192

-- |The maximum number of items allowed in a single tag.  The library
-- will not read nor write tags with more items than this.
apeMaxItems = 64

-- Helper Functions

-- |Returns the first four-digit substring of the given string,
-- or the empty string if no four-digit substring exists.
match4 :: String -> String
match4 (a:b:c:d:ss) = 
  if and (map Char.isDigit [a, b, c, d])
  then [a, b, c, d]
  else match4 (b:c:d:ss)
match4 ss = ""

_stringMul :: String -> String -> Int -> String
_stringMul a s 0 = a
_stringMul a s i = _stringMul (s ++ a) s (i - 1)
-- |Given a string an number of repititions, returns a new string
-- with the given string repeated that many times.
stringMul = _stringMul ""

-- |Given an integer and a string, returns a string with exactly
-- that length, either chopping the existing string to that length
-- if it is longer, or padding the string with NUL bytes if it is
-- shorter.
padChop :: Int -> String -> String
padChop i s =
  let l = length s
      add = i - l
      sm = stringMul "\0" add
  in
    if l < i
    then s ++ sm
    else if l > i
      then take i s
      else s

-- |Interpret 4-byte string as Int packed in little-endian format.
word32le :: String -> Int
word32le = word32le_ 0

word32le_ :: Int -> String -> Int
word32le_ _ [] = 0
word32le_ p (x:xs) = (2 ^ p) * Char.ord(x) + word32le_ (p+8) xs

-- |Interpret 4-byte string as Int packed in big-endian format.
word32be :: String -> Int
word32be = word32be_ 24

word32be_ :: Int -> String -> Int
word32be_ _ [] = 0
word32be_ p (x:xs) = (2 ^ p) * Char.ord(x) + word32be_ (p-8) xs

-- |Pack an Int into a 4-byte string in big-endian format.
be32word :: Int -> String
be32word = be32word_ ""

be32word_ :: String -> Int -> String
be32word_ (a:b:c:d:[]) _ = (a:b:c:d:[])
be32word_ xs n = 
  let (r,m) = divMod n 256
      x = Char.chr m in
  be32word_ (x:xs) r

-- |Pack an Int into a 4-byte string in little-endian format.
le32word :: Int -> String
le32word = reverse . be32word

-- |Read and return a given number of bytes from the handle.
hReadN :: Handle -> Int -> IO String
hReadN _ 0 = return []
hReadN h i = do
  c <- hGetChar h
  s <- hReadN h (i - 1)
  return (c:s)

_split0 :: String -> String -> [String] -> [String]
_split0 "" current previous = (current:previous)
_split0 ('\0':cs) current previous = _split0 cs "" (current:previous)
_split0 (c:cs) current previous = _split0 cs (c:current) previous

-- |Split the given String into a List of String on the NUL byte.
split0 :: String -> [String]
split0 cs = reverse $ map reverse $ _split0 cs "" []

flagFromInt :: Int -> Maybe ApeItemFlag
flagFromInt 0 = Just FlagUTF8
flagFromInt 1 = Just FlagBinary
flagFromInt 2 = Just FlagExternal
flagFromInt 3 = Just FlagReserved
flagFromInt _ = Nothing

flagToInt :: ApeItemFlag -> Int
flagToInt FlagUTF8 = 0
flagToInt FlagBinary = 1
flagToInt FlagExternal = 2
flagToInt FlagReserved = 3

-- Parsec Functions

parseApeTag :: GenParser Char ApeParseState ApeTag
parseApeTag = do
  (headerSize, headerItems) <- parseApeHeaderFooter apeHeaderFlags
  state <- getState
  setState (ApeParseState headerSize headerItems headerSize headerItems 0 (stateTag state))
  parseApeItems
  (footerSize, footerItems) <- parseApeHeaderFooter apeFooterFlags
  state <- getState
  if headerSize /= footerSize || headerItems /= footerItems
  then fail "mismatch in the header/footer size and number of items"
  else return (stateTag state)

parseApeHeaderFooter :: String -> GenParser Char ApeParseState (Int, Int)
parseApeHeaderFooter flags = do
  string apePreamble
  size <- parseWord32le
  items <- parseWord32le
  oneOf "\0\1"
  string flags
  count 8 (char '\0')
  return (size, items)

parseApeItems :: GenParser Char ApeParseState ()
parseApeItems = do
  state <- getState
  if (remainingItems state) <= 0
  then
    return ()
  else do
    size <- parseWord32le
    flagInt <- parseWord32be
    key <- parseApeItemKey
    char '\0'
    state <- getState
    setState state { itemSize = size }
    values <- parseApeItemValues
    let maybeFlags = flagFromInt (flagInt `shift` (-1))
        readOnly = flagInt .&. 1 == 1
        (Right item) = eitherItem
        (Just flags) = maybeFlags
        eitherItem = apeItem key values flags readOnly
        tag = stateTag state
        lc_key = map toLower key
    if maybeFlags == Nothing
    then fail ("invalid item flags: " ++ (show flagInt))
    else do
      case eitherItem of (Left x) -> fail "invalid item key or values"
                         otherwise ->  do                     
                           if Map.member lc_key tag
                           then fail "duplicate item key"
                           else do
                             setState (state { remainingItems = (remainingItems state) - 1
                                            , remainingSize = (remainingSize state) - size
                                            , stateTag = Map.insert lc_key item tag})
                             parseApeItems
  
parseWord32le :: GenParser Char ApeParseState Int
parseWord32le = do
  chars <- count 4 anyChar
  return (word32le chars)

parseWord32be :: GenParser Char ApeParseState Int
parseWord32be = do
  chars <- count 4 anyChar
  return (word32be chars)

parseApeItemKey :: GenParser Char ApeParseState String
parseApeItemKey = 
  many (noneOf "\0")

parseApeItemValues :: GenParser Char ApeParseState [String]
parseApeItemValues = do
  state <- getState
  value <- count (itemSize state) anyChar
  return (split0 value)

-- Parsing from Handle functions

hasID3_ :: Handle -> Int -> IO Bool
hasID3_ h size = do
  if size < 128
  then return False
  else do
    hSeek h SeekFromEnd (-128)
    id3 <- hReadN h 3
    if id3 == "TAG"
    then return True
    else return False

-- Parsing glue functions

runApeParser :: String -> String -> Either ApeParseError ApeTag
runApeParser filename input = 
  let x = runParser parseApeTag (ApeParseState 0 0 0 0 0 Map.empty) filename input
  in case x of (Left p) -> Left (ApeParsecError p)
               (Right o) -> Right o

offsetsFromHandle :: Handle -> IO (Either ApeParseError (Int, Int))
offsetsFromHandle h = do
  size <- hFileSize h
  id3 <- hasID3_ h (fromIntegral size)
  let minApeSize = 64
      id3Size = if id3 then 128 else 0
      minTagSize = minApeSize + id3Size
      footerOffset = ((-id3Size) - 32)
  if size < fromIntegral minTagSize
  then return $ Left $ NoApeTag "file too small for tag"
  else do
    hSeek h SeekFromEnd (fromIntegral footerOffset)
    t <- hReadN h 16
    let preamble = take 12 t
        sizeChars = take 4 (drop 12 t)
        headerOffset = footerOffset - word32le sizeChars
        absHeaderOffset = abs headerOffset
    if preamble /= apePreamble
    then return $ Left $ NoApeTag "No footer preamble"
    else do
      size <- hFileSize h
      if absHeaderOffset > (fromIntegral size) || absHeaderOffset > apeMaxSize
      then return $ Left $ ApeParseError "tag size over file size or max allowed size"
      else return $ Right (headerOffset, footerOffset)

parseFromHandleWithFilename :: String -> Handle -> IO (Either ApeParseError ApeTag)
parseFromHandleWithFilename filename h = do
  offsets <- offsetsFromHandle h
  case offsets of (Left (ApeParseError x)) -> return $ Left $ ApeParseError x
                  (Left (NoApeTag x)) -> return $ Left $ NoApeTag x
                  (Right (headerOffset, footerOffset)) -> do
                    hSeek h SeekFromEnd (fromIntegral headerOffset)
                    t <- hReadN h (footerOffset - headerOffset + 32)
                    return (runApeParser filename t)

-- Public parsing functions

-- |Given a String containing the APE tag (which must start at the start of
-- the string, parse the string and return a (Right ApeTag) if parsing is
-- successful
fromString :: String -> Either ApeParseError ApeTag
fromString = runApeParser "(string)"

-- |Using the given file handle, attempt to parse an APE tag from the end
-- of the file.
fromHandle :: Handle -> IO (Either ApeParseError ApeTag)
fromHandle = parseFromHandleWithFilename "(handle)"

-- |Using the given filename, open a new handle with it and attempt to
-- parse an APE tag from the end of the file.
fromFile :: String -> IO (Either ApeParseError ApeTag)
fromFile f = do
  h <- openFile f ReadMode
  at <- parseFromHandleWithFilename f h
  hClose h
  return at

-- Public removing functions

-- | Using the given handle, remove any ID3v1 or APEv2 tag from the file.
-- Returns True if an APE or ID3 tag was removed, and False otherwise.
removeFromHandle :: Handle -> IO (Either ApeParseError Bool)
removeFromHandle h = do
  offsets <- offsetsFromHandle h
  case offsets of (Left (ApeParseError x)) -> return $ Left $ ApeParseError x
                  (Left (NoApeTag x)) -> do
                    hasID3 <- handleHasID3 h
                    if hasID3 then do
                      hSeek h SeekFromEnd (-128)
                      pos <- hTell h
                      hSetFileSize h pos
                      return $ Right True
                    else return $ Right False
                  (Right (headerOffset, footerOffset)) -> do
                    hSeek h SeekFromEnd (fromIntegral headerOffset)
                    pos <- hTell h
                    hSetFileSize h pos
                    return $ Right True

-- |Remove any ID3v1 or APEv2 tag from the file with the given filename.
removeFromFile :: String -> IO (Either ApeParseError Bool)
removeFromFile f = do
  h <- openFile f ReadWriteMode
  at <- removeFromHandle h
  hClose h
  return at

-- Public writing functions

writeToHandle :: Bool -> ApeTag -> Handle -> IO (Either ApeParseError ApeTag)
writeToHandle id3 at h =
  let s = rawApeTag at
      (Left ls) = s
      (Right rs) = s
      rid3 = rawID3 at
  in do
    case s of (Left _) -> do return $ Left $ ApeParseError ls
              (Right _) -> do
                hPutStr h rs
                if id3
                then do
                  hPutStr h rid3
                  return $ Right at
                else return $ Right at

_toHandle :: Bool -> ApeTag -> Handle -> IO (Either ApeParseError ApeTag)
_toHandle id3 at h = do
  hasID3 <- handleHasID3 h
  offsets <- offsetsFromHandle h
  case offsets of (Left (ApeParseError x)) -> return $ Left $ ApeParseError x
                  (Left (NoApeTag x)) ->
                    if hasID3 then do
                      hSeek h SeekFromEnd (-128)
                      pos <- hTell h
                      hSetFileSize h pos
                      hSeek h SeekFromEnd 0
                      writeToHandle (or [id3, hasID3]) at h
                    else do
                      hSeek h SeekFromEnd 0
                      writeToHandle id3 at h
                  (Right (headerOffset, footerOffset)) -> do
                    hSeek h SeekFromEnd (fromIntegral headerOffset)
                    pos <- hTell h
                    hSetFileSize h pos
                    hSeek h SeekFromEnd 0
                    writeToHandle (or [id3, hasID3]) at h

-- |Given an ApeTag and a file handle, write the tag to the file, overwriting
-- any ID3 or APE tag already there.  If an ID3v1 tag already exists, a new
-- one will be written.  Otherwise, only an APEv2 tag will be written.
toHandle :: ApeTag -> Handle -> IO (Either ApeParseError ApeTag)
toHandle = _toHandle False

-- |Given an ApeTag and a file handle, write both an APEv2 and an ID3v1 tag
-- to the end of the file.
toHandleWithID3 :: ApeTag -> Handle -> IO (Either ApeParseError ApeTag)
toHandleWithID3 = _toHandle True

_toFile fn at f = do
  h <- openFile f ReadWriteMode
  at2 <- fn at h
  hClose h
  return at2

-- |Given an ApeTag and a filename, write the tag to the file, overwriting
-- any ID3 or APE tag already there.  If an ID3v1 tag already exists, a new
-- one will be written.  Otherwise, only an APEv2 tag will be written.
toFile :: ApeTag -> String -> IO (Either ApeParseError ApeTag)
toFile = _toFile toHandle

-- |Given an ApeTag and a filename, write both an APEv2 and an ID3v1 tag
-- to the end of the file.
toFileWithID3 :: ApeTag -> String -> IO (Either ApeParseError ApeTag)
toFileWithID3 = _toFile toHandleWithID3

-- Public convenience functions

-- |Check the file with the given filename for an APEv2 tag.
fileHasAPE :: String -> IO Bool
fileHasAPE f = do
  h <- openFile f ReadMode
  b <- handleHasAPE h
  hClose h
  return b

-- |Check the given file handle for an APEv2 tag.
handleHasAPE :: Handle -> IO Bool
handleHasAPE h = do
  x <- fromHandle h
  case x of (Left (NoApeTag _)) -> return False
            (Right _) -> return True

-- |Check the file with the given filename for an ID3v1 tag.
fileHasID3 :: String -> IO Bool
fileHasID3 f = do
  h <- openFile f ReadMode
  b <- handleHasID3 h
  hClose h
  return b

-- |Check the given file handle for an ID3v1 tag.
handleHasID3 :: Handle -> IO Bool
handleHasID3 h = do
  size <- hFileSize h
  hasID3_ h $ fromIntegral size

-- Data.Map public convenience functions

-- |Given an ApeTag, return a simpler ApeMap that just maps key strings to
-- lists of value strings.  
kvMapFromTag :: ApeTag -> ApeMap
kvMapFromTag = Map.map itemValues

-- |Given an ApeTag, return a simpler ApeMap1 that just maps key strings to
-- a single value string, joining multiple value strings with ", ".
kv1MapFromTag :: ApeTag -> ApeMap1
kv1MapFromTag = Map.map ((intercalate ", ") . itemValues) 

-- ApeItem helper functions

validKey :: String -> Bool
validKey k =
  let l = length k in
  if l < 2
  then False
  else
    if l > 255
    then False
    else
      if (map toLower k) `elem` ["id3", "tag", "oggs", "mp+"]
      then False
      else
        if any (`elem` (map chr ([0..31] ++ [128..255]))) k 
        then False
        else True

validValues :: ApeItemFlag -> [String] -> Bool
validValues f = all (validValue f)

validValue :: ApeItemFlag -> String -> Bool
validValue f v =
 if f == FlagUTF8 || f == FlagExternal
 then isUTF8Encoded v
 else True

-- ApeItem creation functions

-- |Create a UTF-8 read-write ApeItem with a key and a single value string.
apeItemKV1 :: String -> String -> Either String ApeItem
apeItemKV1 k v = apeItemKV k [v]

-- |Create a UTF-8 read-write ApeItem with a key and a multiple value strings.
apeItemKV :: String -> [String] -> Either String ApeItem
apeItemKV k v = apeItem k v FlagUTF8 False

-- |Fully specify ApeItem creation by providing key string, list of value
-- strings, the item type, and whether the item is read-only.
apeItem :: String -> [String] -> ApeItemFlag -> Bool -> Either String ApeItem
apeItem k v f r = 
  if validKey k && validValues f v
  then Right (ApeItem k v f r)
  else Left "Invalid key or value"

-- ApeTag modification functions

-- |Given an ApeTag and ApeItem, add the item to the tag, overwriting any
-- existing item with the same lowercase key.
addApeItem :: ApeTag -> ApeItem -> ApeTag
addApeItem tag item = 
  let lc_key = map toLower $ itemKey item in
  Map.insert lc_key item tag

-- |Given an ApeTag and a string, remove the matching item by key (if any)
-- from the ApeTag.
removeApeItem :: ApeTag -> String -> ApeTag
removeApeItem tag key =
  let lc_key = map toLower key in
  Map.delete key tag

-- raw ApeTag string generation functions

itemReadOnlyNum :: ApeItem -> Int
itemReadOnlyNum item =
  if itemReadOnly item
  then 1
  else 0

itemFlagNum :: ApeItem -> Int
itemFlagNum item = 
  let ro = itemReadOnlyNum item
      flags = itemFlags item
      flagsi = flagToInt flags
      flagsi2 = flagsi * 2 in
  flagsi2 + ro

rawApeItem :: ApeItem -> String
rawApeItem item =
  let sv = intercalate "\0" $ itemValues item
      svl = length sv
      svls = le32word svl
      flags = itemFlagNum item
      flagss = be32word flags
      k = itemKey item in
      svls ++ flagss ++ k ++ "\0" ++ sv

rawItemSorter :: String -> String -> Ordering
rawItemSorter a b =
  let lena = length a
      lenb = length b in
  if lena == lenb
  then compare a b
  else compare lena lenb

rawApeTag :: ApeTag -> Either String String
rawApeTag tag =
  let num_items = Map.size tag
      items = Map.elems tag
      raw_items = sortBy rawItemSorter $ map rawApeItem items
      raw_item_string = intercalate "" raw_items
      tag_size = (length raw_item_string) + 64
      tag_stored_size = tag_size - 32
      tag_size_s = le32word tag_stored_size
      num_items_s = le32word num_items
      base_start = apePreamble ++ tag_size_s ++ num_items_s ++ "\0"
      base_end = "\0\0\0\0\0\0\0\0"
      tag_header = base_start ++ apeHeaderFlags ++ base_end
      tag_footer = base_start ++ apeFooterFlags ++ base_end
      tag_raw = tag_header ++ raw_item_string ++ tag_footer
     in
  if tag_size > apeMaxSize
  then  Left ("Resulting tag too large: " ++ (show tag_size))
  else if num_items > apeMaxItems
    then Left ("Resulting tag too many items: " ++ (show num_items))
    else Right tag_raw

rawID3 :: ApeTag -> String
rawID3 tag =
  let f2 (Just v) = itemValues v
      f2 x = []
      lk k = map toLower k
      f k = f2 $ Map.lookup (lk k) tag
      j k = intercalate ", " $ f k
      year "" = match4 $ j "date"
      year s = s
      p i "year" = padChop i $ year $ j "year"
      p i k = padChop i $ j k
      title = j "title"
      hoe [] = ""
      hoe (s:ss) = s
      ps a [] = reverse a 
      ps a ((i, k):ks) = ps ((p i k):a) ks
      tr = (reads $ hoe $ f "track") :: [(Int, String)]
      tr2 [] = 0
      tr2 [(i, s)] = i
      track = [Char.chr $ tr2 tr]
      genre = [Char.chr $ Map.findWithDefault 255 (hoe $ f "genre") id3Genres]
  in do
    "TAG" ++ (intercalate "" $ ps [] [(30, "title"), (30, "artist"), (30, "album"), (4, "year"), (28, "comment")]) ++ "\0" ++ track ++ genre
