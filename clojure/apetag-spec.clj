(ns apetag-spec
  (:import
    (java.io File)
    (java.lang StringBuffer)
    (java.nio ByteBuffer)
    (java.nio CharBuffer)
    (java.nio.charset Charset)
    (java.nio.channels FileChannel)
    (java.nio.file StandardOpenOption)
    (java.nio.file.attribute FileAttribute)))

(use 'apetag)
(use 'clojure.test)

(def EMPTY-TAG "APETAGEX\320\7\0\0 \0\0\0\0\0\0\0\0\0\0\240\0\0\0\0\0\0\0\000APETAGEX\320\7\0\0 \0\0\0\0\0\0\0\0\0\0\200\0\0\0\0\0\0\0\000TAG\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\377")
(def EXAMPLE-TAG "APETAGEX\320\7\0\0\260\0\0\0\6\0\0\0\0\0\0\240\0\0\0\0\0\0\0\0\1\0\0\0\0\0\0\000Track\0001\4\0\0\0\0\0\0\000Date\0002007\11\0\0\0\0\0\0\000Comment\000XXXX-0000\13\0\0\0\0\0\0\000Title\000Love Cheese\13\0\0\0\0\0\0\000Artist\000Test Artist\26\0\0\0\0\0\0\000Album\000Test Album\000Other AlbumAPETAGEX\320\7\0\0\260\0\0\0\6\0\0\0\0\0\0\200\0\0\0\0\0\0\0\000TAGLove Cheese\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\000Test Artist\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\000Test Album, Other Album\0\0\0\0\0\0\0002007XXXX-0000\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\1\377")
(def EXAMPLE-TAG2 "APETAGEX\320\7\0\0\231\0\0\0\5\0\0\0\0\0\0\240\0\0\0\0\0\0\0\0\4\0\0\0\0\0\0\000Blah\000Blah\4\0\0\0\0\0\0\000Date\0002007\11\0\0\0\0\0\0\000Comment\000XXXX-0000\13\0\0\0\0\0\0\000Artist\000Test Artist\26\0\0\0\0\0\0\000Album\000Test Album\000Other AlbumAPETAGEX\320\7\0\0\231\0\0\0\5\0\0\0\0\0\0\200\0\0\0\0\0\0\0\000TAG\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\000Test Artist\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\000Test Album, Other Album\0\0\0\0\0\0\0002007XXXX-0000\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\377")
(def EMPTY-TAG-AO (subs EMPTY-TAG 0 (- (count EMPTY-TAG) 128)))
(def EXAMPLE-TAG-AO (subs EXAMPLE-TAG 0 (- (count EXAMPLE-TAG) 128)))
(def EXAMPLE-TAG2-AO (subs EXAMPLE-TAG2 0 (- (count EXAMPLE-TAG2) 128)))
(def EXAMPLE-ITEMS {"Track" '("1"), "Comment" '("XXXX-0000"), "Album" '("Test Album", "Other Album"), "Title" '("Love Cheese"), "Artist" '("Test Artist"), "Date" '("2007")})
(def EXAMPLE-ITEMS2 {"Blah" '("Blah"), "Comment" '("XXXX-0000"), "Album" '("Test Album", "Other Album"), "Artist" '("Test Artist"), "Date" '("2007")})
(def EXAMPLE-PRETTY-PRINT "Album: Test Album, Other Album\nArtist: Test Artist\nComment: XXXX-0000\nDate: 2007\nTitle: Love Cheese\nTrack: 1")
(def TEST-TAG "APETAGEX\320\7\0\0\65\0\0\0\1\0\0\0\0\0\0\240\0\0\0\0\0\0\0\000\010\0\0\0\0\0\0\007BlaH\000BlAh\000XYZAPETAGEX\320\7\0\0\65\0\0\0\1\0\0\0\0\0\0\200\0\0\0\0\0\0\0\0")


(defn- with-file-channel [filename options f]
    (with-open [
      fc (FileChannel/open
         (.toPath (File. filename))
         (into-array StandardOpenOption options))
     ]
      (f fc)))

(defn- seek-read [fc seek read]
     (let [bb (ByteBuffer/allocate read)]
      (.position fc (long (- (.size fc) seek)))
      (.read fc bb)
      (.rewind bb)
      (str (.decode ISO8859 bb))))

(defn- seek-write [filename seek string]
  (with-file-channel filename (list StandardOpenOption/READ StandardOpenOption/WRITE)
    #(
     (let [
       len (count string)
       bb (.encode ISO8859 string)
      ]
      (.position % (long (- (.size %) seek)))
      (.write % bb)
      (fn [] nil)))))

(defn- seek-write-truncate [filename seek string]
  (with-file-channel filename (list StandardOpenOption/READ StandardOpenOption/WRITE)
    #(
     (let [
       len (count string)
       bb (.encode ISO8859 string)
      ]
      (.position % (long (- (.size %) seek)))
      (.write % bb)
      (.truncate % (.position %))
      (fn [] nil)))))
      
(defn- file-from-string [filename string]
  (.delete (File. filename))
  (.createFile (.toPath (File. filename)) (into-array FileAttribute '()))
  (seek-write-truncate filename 0 string))

(defn- empty-string [size]
  (let [sb (StringBuffer. size)]
  (loop [i size]
    (if (zero? i)
      (.toString sb)
      (do
        (.append sb " ")
        (recur (dec i)))))))

(defn file-size [filename]
  (.length (File. filename)))

(defn file-contents [filename]
  (let [size (file-size filename)]
  (with-file-channel filename '() #(seek-read % size size))))

(defn item-test [filename check-id3]
  (let [
    id3s (if (= true check-id3) 128 0)
    size (file-size filename)
  ]
  (is (= false (apetag/exists? filename check-id3)))
  (is (= {} (apetag/items filename check-id3)))
  (is (= size (file-size filename)))
  (is (= false (apetag/remove-tag filename check-id3)))
  (is (= {} (apetag/items filename check-id3)))
  (is (= size (file-size filename)))
  (is (= {} (apetag/update (fn [at items] at) filename check-id3)))
  (is (= (+ size 64 id3s) (file-size filename)))
  (is (= true (apetag/exists? filename check-id3)))
  (is (= (if check-id3 EMPTY-TAG EMPTY-TAG-AO) (apetag/raw filename check-id3)))
  (is (= {} (apetag/items filename check-id3)))
  (is (= {} (apetag/update (fn [at items] at) filename check-id3)))
  (is (= (+ size 64 id3s) (file-size filename)))
  (is (= true (apetag/remove-tag filename check-id3)))
  (is (= {} (apetag/items filename check-id3)))
  (is (= size (file-size filename)))
  (is (= false (apetag/exists? filename check-id3)))
  (is (= EXAMPLE-ITEMS (apetag/update (fn [at items] (apetag/add-items at EXAMPLE-ITEMS)) filename check-id3)))
  (is (= (+ size 208 id3s) (file-size filename)))
  (is (= true (apetag/exists? filename check-id3)))
  (is (= (if check-id3 EXAMPLE-TAG EXAMPLE-TAG-AO) (apetag/raw filename check-id3)))
  (is (= EXAMPLE-PRETTY-PRINT (apetag/print-tag filename check-id3)))
  (is (= EXAMPLE-ITEMS (apetag/items filename check-id3)))
  (is (= EXAMPLE-ITEMS (apetag/update (fn [at items] at) filename check-id3)))
  (is (= (+ size 208 id3s) (file-size filename)))
  (is (= EXAMPLE-ITEMS2 (apetag/update (fn [at items] (apetag/remove-items (apetag/add-item at "Blah" "Blah") "Track" "Title")) filename check-id3)))
  (is (= EXAMPLE-ITEMS2 (apetag/items filename check-id3)))
  (is (= EXAMPLE-ITEMS2 (apetag/update (fn [at items] at) filename check-id3)))
  (is (= true (apetag/exists? filename check-id3)))
  (is (= (+ size 185 id3s) (file-size filename)))
  (is (= (if check-id3 EXAMPLE-TAG2 EXAMPLE-TAG2-AO) (apetag/raw filename check-id3)))
  (is (= true (apetag/remove-tag filename check-id3)))
  (is (= "" (apetag/raw filename check-id3)))
  (is (= size (file-size filename)))
))

(defn blank-apetag []
  (with-local-vars [a nil]
  (let [filename "test.apetag"]
  (file-from-string filename "")
  (apetag/update (fn [at items] (var-set a at) at) filename)
  (.delete (File. filename)))
  (var-get a)))
  
(defn str-rep
  ([s start rep]
    (str (subs s 0 start) rep (subs s (+ start (count rep)))))
  ([s start rep & body]
    (apply str-rep (str-rep s start rep) (first body) (second body) (rest (rest body)))))

(println "Starting Testing...")

(testing "General usage and edge conditions for small files"
  (let [filename (str "test.apetag")]
  (doseq [i (list 0 1 63 64 65 127 128 129 191 192 193 8191 8192 8193)]
    (doseq [ci (list true false)]
      (file-from-string filename (empty-string i))
      (item-test filename ci)
      (.delete (File. filename))))))

(testing "APE item restrictions"
  (let [at (blank-apetag)]
  ; Read Only Flag
  (apetag/add-item at "Key" "Value" "utf8" true)
  (apetag/add-item at "Key" "Value" "utf8" false)
  (is (thrown-with-msg? Error #"Invalid item read-only flag" (apetag/add-item at "Key" "Value" "utf8" nil)))
  (is (thrown-with-msg? Error #"Invalid item read-only flag" (apetag/add-item at "Key" "Value" "utf8" "Blah")))
  ; Type
  (doseq [type apetag/ITEM-TYPES] (apetag/add-item at "Key" "Value" type))
  (is (thrown-with-msg? Error #"Invalid item type" (apetag/add-item at "Key" "Value" "Blah")))
  ; Key
  (doseq [key (concat (map #(str "  " (char %)) (concat (range 0 32) (range 128 256))) (list nil 1 "" "x" (reduce (fn [s _] (str s "x")) (range 256)) "id3" "tag" "oggs" "mp+"))]
    (is (thrown-with-msg? Error #"Invalid item key" (apetag/add-item at key "Value"))))
  (doseq [key (concat (map #(str "  " (char %)) (range 32 128)) (list (reduce (fn [s _] (str s "x")) (range 255)) "id3  " "tag  " "oggs  " "mp+  " "xx"))]
    (apetag/add-item at key "Value"))
  ; Value
  (doseq [v (list nil '(nil) '() {} "blah" '("blah" "blah"))]
    (apetag/add-item at "xx" v))
  (is (thrown-with-msg? Error #"Invalid item value encoding.*" (apetag/add-item at "xx" "\376")))))

(testing "Valid and Corrupt tag parsing"
  (let [filename (str "test.apetag")]
  ; Default OK
  (file-from-string filename TEST-TAG)
  (is (= {"blah" {:key "BlaH", :values (list "BlAh" "XYZ"), :read-only true, :type "reserved"}} (apetag/full-items filename)))
  ; Bad Key
  (file-from-string filename (str-rep TEST-TAG 32 "\011\0\0\0\0\0\0\000id3\000BlAh\000XYZx"))
  (is (thrown-with-msg? Error #"Invalid item key" (apetag/items filename)))
  ; No Key-Value Separator
  (file-from-string filename (str-rep TEST-TAG 32 "\0\0\0\0\0\0\0\000id3aBlAhbXYZx"))
  (is (thrown-with-msg? Error #"Missing item key-value separator" (apetag/items filename)))
  ; Bad Start Value
  (file-from-string filename (str-rep TEST-TAG 32 "\0\0\0\0\0\0\000id3aBlAhbXYZx\0"))
  (is (thrown-with-msg? Error #"Invalid item flags" (apetag/items filename)))
  (file-from-string filename (str-rep TEST-TAG 32 "\011\0\0\0\0\0\0\010jd3\000BlAh\000XYZx"))
  (is (thrown-with-msg? Error #"Invalid item flags" (apetag/items filename)))
  ; Item length too long
  (file-from-string filename (str-rep TEST-TAG 32 "\012\0\0\0\0\0\0\000jd3\000BlAh\000XYZx"))
  (is (thrown-with-msg? Error #"Invalid item length" (apetag/items filename)))
  ; More items than in tag
  (file-from-string filename (str-rep TEST-TAG 32 "\4\0\0\0\0\0\0\000jd3\000BlAh\000XYZx"))
  (is (thrown-with-msg? Error #"Data remaining after specified number of items parsed" (apetag/items filename)))
  ; Invalid UTF8
  (file-from-string filename (str-rep TEST-TAG 32 "\011\0\0\0\0\0\0\000jd3\000BlAh\300XYZx"))
  (is (thrown-with-msg? Error #"Invalid item value encoding.*" (apetag/items filename)))
  ; Read-Only Tag Flag Works
  (file-from-string filename (str-rep EMPTY-TAG-AO 20 "\1"))
  (is (= {} (apetag/items filename)))
  (doseq [s (map #(str (char %)) (range 2 256))]
    (file-from-string filename (str-rep EMPTY-TAG-AO 20 s))
    (is (thrown-with-msg? Error #"Tag has bad header flags" (apetag/items filename)))
    (file-from-string filename (str-rep EMPTY-TAG-AO 52 s))
    (is (thrown-with-msg? Error #"Tag has bad footer flags" (apetag/items filename)))
    (file-from-string filename (str-rep EMPTY-TAG-AO 20 s 52 s))
    (is (thrown-with-msg? Error #"Tag has bad footer flags" (apetag/items filename))))
  ; Footer size less than minimum
  (file-from-string filename (str-rep EMPTY-TAG-AO 44 "\37"))
  (is (thrown-with-msg? Error #"Tag size smaller than minimum size.*" (apetag/items filename)))
  (file-from-string filename (str-rep EMPTY-TAG-AO 44 "\0"))
  (is (thrown-with-msg? Error #"Tag size smaller than minimum size.*" (apetag/items filename)))
  ; Footer size greater than file size
  (file-from-string filename (str-rep EMPTY-TAG-AO 44 "\41"))
  (is (thrown-with-msg? Error #"Tag size larger than file size" (apetag/items filename)))
  ; Footer size greater than maximum allowed
  (file-from-string filename (str (empty-string 8192) (str-rep EMPTY-TAG-AO 44 "\341\37")))
  (is (thrown-with-msg? Error #"Tag size larger than maximum allowed size" (apetag/items filename)))
  ; Unmatched header and footer size
  (file-from-string filename (str " " (str-rep EMPTY-TAG-AO 12 "\41")))
  (is (thrown-with-msg? Error #"Tag header size does not match tag footer size" (apetag/items filename)))
  (file-from-string filename (str " " (str-rep EMPTY-TAG-AO 44 "\41")))
  (is (thrown-with-msg? Error #"Missing tag header" (apetag/items filename)))
  (file-from-string filename (str (subs EMPTY-TAG-AO 0 32) " " (str-rep (subs EMPTY-TAG-AO 32) 12 "\41")))
  (is (thrown-with-msg? Error #"Tag header size does not match tag footer size" (apetag/items filename)))
  ; Unaccounted for data in tag
  (file-from-string filename (str (str-rep (subs EMPTY-TAG-AO 0 32) 12 "\41") " " (str-rep (subs EMPTY-TAG-AO 32) 12 "\41")))
  (is (thrown-with-msg? Error #"Data remaining after specified number of items parsed" (apetag/items filename)))
  ; Maximum number of allowed items exceeded
  (file-from-string filename (str " " (str-rep EMPTY-TAG-AO 48 "\101")))
  (is (thrown-with-msg? Error #"Tag item count larger than maximum allowed item count" (apetag/items filename)))
  ; Number of items not possible given tag size
  (file-from-string filename (str " " (str-rep EMPTY-TAG-AO 48 "\1")))
  (is (thrown-with-msg? Error #"Tag item count larger than possible" (apetag/items filename)))
  ; Wrong item count in header
  (file-from-string filename (str " " (str-rep EMPTY-TAG-AO 16 "\1")))
  (is (thrown-with-msg? Error #"Tag header item count does not match tag footer item count" (apetag/items filename)))
  ; Wrong item count in footer
  (file-from-string filename (str " " (str-rep EXAMPLE-TAG-AO (- (count EXAMPLE-TAG-AO) 16) "\1")))
  (is (thrown-with-msg? Error #"Tag header item count does not match tag footer item count" (apetag/items filename)))
  ; Corrupt header
  (file-from-string filename (str-rep EMPTY-TAG-AO 0 "\0"))
  (is (thrown-with-msg? Error #"Missing tag header" (apetag/items filename)))
  ; Bad item size
  (file-from-string filename (str-rep EXAMPLE-TAG-AO 32 "\2"))
  (is (thrown-with-msg? Error #"Invalid item flags" (apetag/items filename)))
  ; Invalid key
  (file-from-string filename (str-rep EXAMPLE-TAG-AO 40 "\0"))
  (is (thrown-with-msg? Error #"Invalid item key" (apetag/items filename)))
  ; Invalid key-value separator
  (file-from-string filename (str-rep EXAMPLE-TAG-AO 45 " "))
  (is (thrown-with-msg? Error #"Invalid item key" (apetag/items filename)))
  ; Second item too long
  (file-from-string filename (str-rep EXAMPLE-TAG-AO 47 "\377"))
  (is (thrown-with-msg? Error #"Invalid item length" (apetag/items filename)))
  ; Duplicate item keys
  (file-from-string filename (str-rep EXAMPLE-TAG-AO 40 "Album"))
  (is (thrown-with-msg? Error #"Multiple items with the same key" (apetag/items filename)))
  (file-from-string filename (str-rep EXAMPLE-TAG-AO 40 "album"))
  (is (thrown-with-msg? Error #"Multiple items with the same key" (apetag/items filename)))
  (file-from-string filename (str-rep EXAMPLE-TAG-AO 40 "ALBUM"))
  (is (thrown-with-msg? Error #"Multiple items with the same key" (apetag/items filename)))
  ; Invalid item counts
  (file-from-string filename (str-rep EXAMPLE-TAG-AO 16 "\7" 192 "\7"))
  (is (thrown-with-msg? Error #"End of tag reached but more items specified" (apetag/items filename)))
  (file-from-string filename (str-rep EXAMPLE-TAG-AO 16 "\5" 192 "\5"))
  (is (thrown-with-msg? Error #"Data remaining after specified number of items parsed" (apetag/items filename)))
  ; Updating with case insensitive keys
  (file-from-string filename EXAMPLE-TAG-AO)
  (is (= (list "blah") ((apetag/update (fn [at is] (apetag/add-item at "album" "blah")) filename) "album")))
  (is (= (list "blah") ((apetag/update (fn [at is] (apetag/add-item at "ALBUM" "blah")) filename) "ALBUM")))
  (is (= (list "blah") ((apetag/update (fn [at is] (apetag/add-item at "AlBuM" "blah")) filename) "AlBuM")))
  ; Adding too many items
  (file-from-string filename EMPTY-TAG-AO)
  (is (thrown-with-msg? Error #"Updated tag has too many items" (apetag/update (fn [at is] (reduce #(apetag/add-item %1 (str %2 "  ") "blah") at (range 65))) filename)))
  ; Adding just enough items
  (file-from-string filename EMPTY-TAG-AO)
  (apetag/update (fn [at is] (reduce #(apetag/add-item %1 (str %2 "  ") "blah") at (range 64))) filename)
  ; Adding too large tag
  (file-from-string filename EMPTY-TAG-AO)
  (is (thrown-with-msg? Error #"Updated tag too large" (apetag/update (fn [at is] (apetag/add-item at "xx" (empty-string 8118))) filename)))
  ; Adding just large enough tag
  (file-from-string filename EMPTY-TAG-AO)
  (apetag/update (fn [at is] (apetag/add-item at "xx" (empty-string 8117))) filename)
  (.delete (File. filename))))

(testing "check-id3 automatic handling"
  (let [mp3 (str "test.mp3"), ape (str "test.ape")]
  ; Non-mp3 file defaults to check-id3 false
  (file-from-string ape EMPTY-TAG)
  (is (not (apetag/exists? ape)))
  (is (apetag/exists? ape true))
  (file-from-string ape EMPTY-TAG-AO)
  (is (apetag/exists? ape))
  (is (apetag/exists? ape true))
  ; Non-mp3 file will not add ID3 tag if no tags present
  (file-from-string ape "")
  (apetag/update (fn [at is] at) ape)
  (is (= 64 (file-size ape)))
  ; mp3 file defaults to check-id3 true
  (file-from-string mp3 EMPTY-TAG)
  (is (apetag/exists? mp3))
  (is (not (apetag/exists? mp3 false)))
  ; mp3 file will add ID3 tag if no tags present
  (file-from-string mp3 "")
  (apetag/update (fn [at is] at) mp3)
  (is (= 192 (file-size mp3)))
  ; Non-mp3 with check-id3 true will add ID3 if no tags present
  (file-from-string ape "")
  (apetag/update (fn [at is] at) ape true)
  (is (= 192 (file-size ape)))
  ; Either will not add ID3 if no ID3 tag already present
  (file-from-string mp3 EMPTY-TAG-AO)
  (apetag/update (fn [at is] at) mp3)
  (is (= 64 (file-size mp3)))
  (file-from-string ape EMPTY-TAG-AO)
  (apetag/update (fn [at is] at) ape)
  (is (= 64 (file-size ape)))
  ; Either will add new ID3 if ID3 tag already present
  (file-from-string mp3 EMPTY-TAG)
  (apetag/update (fn [at is] at) mp3)
  (is (= 192 (file-size mp3)))
  (file-from-string ape EMPTY-TAG)
  (apetag/update (fn [at is] at) ape true)
  (is (= 192 (file-size ape)))
  (.delete (File. ape))
  (.delete (File. mp3))))

(println "Finished Testing.")
