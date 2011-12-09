#!/usr/bin/env runhaskell

import Test.HUnit
import ApeTag
import System.Directory
import System.IO
import qualified Data.Map as Map

makeTest ass f = TestLabel f (TestCase $ ass f)
makeTest2 ass f n = TestLabel f (TestCase $ ass f n)
makeTest3 ass f k v = TestLabel f (TestCase $ ass f k v)

aiKV1 :: String -> String -> ApeItem
aiKV1 k v = let (Right x) = apeItemKV1 k v in x

aiKV :: String -> [String] -> ApeItem
aiKV k v = let (Right x) = apeItemKV k v in x

ai :: String -> [String] -> ApeItemFlag -> Bool -> ApeItem
ai k v f r = let (Right x) = apeItem k v f r in x

defaultItem = aiKV1 "foo" "bar"

testFile f = "test-files/" ++ f ++ ".tag"

assertCorruptTag f = do
  x <- fromFile $ testFile $ "corrupt-" ++ f
  case x of (Left (NoApeTag _)) -> assertBool ("Expected corrupt but missing: " ++ f) False 
            (Left _) -> assertBool "" True
            (Right _) -> assertBool ("Expected corrupt but not: " ++ f) False
corruptTest = makeTest assertCorruptTag

assertHasAPETag f = do
  x <- fileHasAPE $ testFile f
  assertBool ("Expected has APE tag, but does not: " ++ f) x
hasAPETest = makeTest assertHasAPETag

assertHasNoAPETag f = do
  x <- fileHasAPE $ testFile f
  assertBool ("Expected has no APE tag, but does: " ++ f) (not x)
hasNoAPETest = makeTest assertHasNoAPETag

assertHasID3Tag f = do
  x <- fileHasID3 $ testFile f
  assertBool ("Expected has ID3 tag, but does not: " ++ f) x
hasID3Test = makeTest assertHasID3Tag

assertHasNoID3Tag f = do
  x <- fileHasID3 $ testFile f
  assertBool ("Expected has no ID3 tag, but does: " ++ f) (not x)
hasNoID3Test = makeTest assertHasNoID3Tag

assertNumFields f n = do
  (Right x) <- fromFile $ testFile f
  assertEqual ("Not the expected size: " ++ f) n (Map.size $ kvMapFromTag x)
hasNumFieldsTest = makeTest2 assertNumFields

assertValueAtKey f k v = do
  (Right x) <- fromFile $ testFile f
  assertEqual ("Not the expected value at key: " ++ f) v (Map.findWithDefault ["foo"] k $ kvMapFromTag x)
hasValueAtKeyTest = makeTest3 assertValueAtKey

assertItemAtKey f k v = do
  (Right x) <- fromFile $ testFile f
  assertEqual ("Not the expected item at key: " ++ f) v (Map.findWithDefault defaultItem k x)
hasItemAtKeyTest = makeTest3 assertItemAtKey

assertRemoved before after b = let tf = testFile "test"
  in do
    copyFile (testFile before) tf
    (Right x) <- removeFromFile tf
    assertEqual ("Not expected result from removeFromFile: " ++ before) x b
    b <- readFile tf
    a <- readFile $ testFile after
    assertEqual ("removeFromFile didn't remove tag: " ++ before) b a
    removeFile tf
removedTest = makeTest3 assertRemoved

assertSameAfter ffn hfn before after fn =
 let tf = testFile "test"
   in do
     -- Test with file names
     (Right at) <- fromFile $ testFile before
     ffn (fn at) tf
     b <- readFile tf
     a <- readFile $ testFile after
     removeFile tf
     assertEqual ("Tag doesn't match after function: " ++ before ++ " " ++ after) b a

     -- Test with handles
     bh <- openFile (testFile before) ReadMode
     th <- openFile tf ReadWriteMode
     (Right at) <- fromHandle bh
     hClose bh
     hfn (fn at) th
     hClose th
     b <- readFile tf
     a <- readFile $ testFile after
     removeFile tf
     assertEqual ("Tag doesn't match after function: " ++ before ++ " " ++ after) b a
sameAfterTest = makeTest3 $ assertSameAfter toFile toHandle
sameAfterWithID3Test = makeTest3 $ assertSameAfter toFileWithID3 toHandleWithID3

assertInvalidItem x = do
  case x of (Left _) -> assertBool "" True
            (Right _) -> assertBool "Expected invalid item but not" False
invalidItemTest ai = TestLabel "" (TestCase $ assertInvalidItem ai)

assertInvalidUpdate f fn =
 let tf = testFile "test"
   in do
     -- Test with file names
     (Right at) <- fromFile $ testFile f
     r <- toFile (fn at) tf
     removeFile tf
     case r of (Left _) -> assertBool "" True
               (Right _) -> assertBool "Expected invalid tag but not" False

     -- Test with handles
     fh <- openFile (testFile f) ReadMode
     th <- openFile tf ReadWriteMode
     (Right at) <- fromHandle fh
     hClose fh
     r <- toHandle (fn at) th
     hClose th
     removeFile tf
     case r of (Left _) -> assertBool "" True
               (Right _) -> assertBool "Expected invalid tag but not" False
invalidUpdateTest = makeTest2 assertInvalidUpdate

addManyItems :: Integer -> Integer -> String -> ApeTag -> ApeTag
addManyItems max i v at =
  if max == i
  then at
  else addManyItems max (i + 1) ('a':v) $ addApeItem at $ aiKV1 ((show i) ++ "n") v

addItemList :: ApeTag -> [(String, String)] -> ApeTag
addItemList at [] = at
addItemList at ((k,v):s) = addItemList (addApeItem at $ aiKV1 k v) s

largeString :: Integer -> String -> String
largeString 0 s = s
largeString i s = largeString (i-1) ('a':s)

_stringMul a s 0 = a
_stringMul a s i = _stringMul (s ++ a) s (i - 1)
stringMul = _stringMul ""

tests = TestList [ corruptTest "header"
                 , corruptTest "value-not-utf8" 
                 , corruptTest "count-larger-than-possible" 
                 , corruptTest "count-mismatch" 
                 , corruptTest "count-over-max-allowed" 
                 , corruptTest "data-remaining" 
                 , corruptTest "duplicate-item-key" 
                 , corruptTest "finished-without-parsing-all-items" 
                 , corruptTest "footer-flags" 
                 , corruptTest "item-flags-invalid" 
                 , corruptTest "item-length-invalid" 
                 , corruptTest "key-invalid" 
                 , corruptTest "key-too-short" 
                 , corruptTest "key-too-long" 
                 , corruptTest "min-size" 
                 , corruptTest "missing-key-value-separator" 
                 , corruptTest "next-start-too-large" 
                 , corruptTest "size-larger-than-possible" 
                 , corruptTest "size-mismatch" 
                 , corruptTest "size-over-max-allowed" 
                 , hasNoAPETest "missing-ok"
                 , hasNoAPETest "good-empty-id3-only"
                 , hasAPETest "good-empty"
                 , hasAPETest "good-empty-id3"
                 , hasNoID3Test "missing-ok"
                 , hasID3Test "good-empty-id3-only"
                 , hasNoID3Test "good-empty"
                 , hasID3Test "good-empty-id3"
                 , hasNumFieldsTest "good-empty" 0
                 , hasNumFieldsTest "good-simple-1" 1
                 , hasNumFieldsTest "good-many-items" 63
                 , hasNumFieldsTest "good-multiple-values" 1
                 , hasValueAtKeyTest "good-simple-1" "name" ["value"]
                 , hasValueAtKeyTest "good-many-items" "0n" [""]
                 , hasValueAtKeyTest "good-many-items" "1n" ["a"]
                 , hasValueAtKeyTest "good-many-items" "62n" ["aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"]
                 , hasValueAtKeyTest "good-multiple-values" "name" ["va", "ue"]
                 , hasItemAtKeyTest "good-simple-1" "name" (aiKV1 "name" "value")
                 , hasItemAtKeyTest "good-many-items" "0n" (aiKV1 "0n" "")
                 , hasItemAtKeyTest "good-many-items" "1n" (aiKV1 "1n" "a")
                 , hasItemAtKeyTest "good-many-items" "62n" (aiKV1 "62n" "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
                 , hasItemAtKeyTest "good-multiple-values" "name" (aiKV "name" ["va", "ue"])
                 , hasItemAtKeyTest "good-simple-1-ro-external" "name" (ai "name" ["value"] FlagExternal True)
                 , hasItemAtKeyTest "good-binary-non-utf8-value" "name" (ai "name" ["v\129lue"] FlagBinary False)
                 , removedTest "good-empty" "missing-ok" True
                 , removedTest "good-empty-id3" "missing-ok" True
                 , removedTest "good-empty-id3-only" "missing-ok" True
                 , removedTest "missing-10k" "missing-10k" False
                 , sameAfterTest "good-empty" "good-empty" (\at -> at)
                 , sameAfterTest "good-empty" "good-simple-1" (\at -> addApeItem at $ aiKV1 "name" "value")
                 , sameAfterTest "good-empty" "good-simple-1-ro-external" (\at -> addApeItem at $ ai "name" ["value"] FlagExternal True)
                 , sameAfterTest "good-simple-1" "good-empty" (\at -> removeApeItem at "name")
                 , sameAfterTest "good-empty" "good-many-items" $ addManyItems 63 0 "" 
                 , sameAfterTest "good-empty" "good-multiple-values" (\at -> addApeItem at $ aiKV "name" ["va", "ue"])
                 , sameAfterTest "good-multiple-values" "good-simple-1-uc" (\at -> addApeItem at $ aiKV1 "NAME" "value")
                 , sameAfterTest "good-empty" "good-simple-1-utf8" (\at -> addApeItem at $ aiKV1 "name" "v\195\130\195\149")
                 , sameAfterWithID3Test "good-empty" "good-empty-id3" (\at -> at)
                 , sameAfterWithID3Test "good-empty" "good-simple-4" (\at -> addItemList at [("track", "1"), ("genre", "Game"), ("year", "1999"), ("title", "Test Title"), ("artist", "Test Artist"), ("album", "Test Album"), ("comment", "Test Comment")])
                 , sameAfterWithID3Test "good-empty" "good-simple-4-uc" (\at -> addItemList at [("Track", "1"), ("Genre", "Game"), ("Year", "1999"), ("Title", "Test Title"), ("Artist", "Test Artist"), ("Album", "Test Album"), ("Comment", "Test Comment")])
                 , sameAfterWithID3Test "good-empty" "good-simple-4-date" (\at -> addItemList at [("track", "1"), ("genre", "Game"), ("date", "12/31/1999"), ("title", "Test Title"), ("artist", "Test Artist"), ("album", "Test Album"), ("comment", "Test Comment")])
                 , sameAfterWithID3Test "good-empty" "good-simple-4-long" (\at -> addItemList at [("track", "1"), ("genre", "Game"), ("year", "19991999"), ("title", stringMul "Test Title" 5), ("artist", stringMul "Test Artist" 5), ("album", stringMul "Test Album" 5), ("comment", stringMul "Test Comment" 5)])
                 , invalidItemTest $ apeItemKV1 "n" ""
                 , invalidItemTest $ apeItemKV1 "n\0" "value"
                 , invalidItemTest $ apeItemKV1 "n\031" "value"
                 , invalidItemTest $ apeItemKV1 "n\128" "value"
                 , invalidItemTest $ apeItemKV1 "n\255" "value"
                 , invalidItemTest $ apeItemKV1 "name" "v\194\213"
                 , invalidUpdateTest "good-empty" $ addManyItems 65 0 ""
                 , invalidUpdateTest "good-empty" (\at -> addApeItem at $ aiKV1 "xn" $ largeString 8118 "")
                 ]


main = do
  runTestTT tests
