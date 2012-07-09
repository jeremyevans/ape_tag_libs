(ns apetag
  (:import
    (java.io File)
    (java.nio ByteBuffer)
    (java.nio CharBuffer)
    (java.nio.charset Charset)
    (java.nio.channels FileChannel)
    (java.nio.file StandardOpenOption)))

(def PREAMBLE "APETAGEX\320\7\0\0")
(def FOOTER-FLAGS "\0\0\200")
(def HEADER-FLAGS "\0\0\240")
(def END "\0\0\0\0\0\0\0\0")
(def MAX-SIZE 8192)
(def MAX-ITEMS 64)
(def MIN-ITEM-SIZE 11)
(def ITEM-TYPES ["utf8" "binary" "external" "reserved"])
(def ITEM-TYPE-MAP {"utf8" 0, "binary" 1, "external" 2, "reserved" 3})
(def BAD-ITEM-KEY-RE #"[\000-\0037\0200-\0377]|^(?:[iI][Dd]3|[Tt][Aa][Gg]|[Oo][Gg][Gg][Ss]|[Mm][Pp]\+)$" )
(def UTF8 (Charset/forName "UTF-8"))
(def ISO8859 (Charset/forName "ISO-8859-1"))
(def ID3-GENRES ["Blues", "Classic Rock", "Country", "Dance", "Disco", "Funk", "Grunge",
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
    "Thrash Metal", "Anime", "Jpop", "Synthpop"])
(def ID3-GENRES-HASH ((reduce (fn [m g] {:number (+ 1 (m :number)), :hash (assoc (m :hash) (.toLowerCase g) (m :number))}) {:number 0, :hash {}} ID3-GENRES) :hash))

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

(defn- get-int-bytes [s]
  (vec (map #(if (< % 0) (+ 256 %) %) (.getBytes s "ISO-8859-1"))))

(defn- -unpacki [s l]
  (let [b (get-int-bytes s)]
    (int (reduce + (map  #(* (Math/pow 256 (last %)) (b (first %))) l)))))

(defn- unpacki [s]
  (-unpacki s [[0 0] [1 1] [2 2] [3 3]]))
      
(defn- unpackile [s]
  (-unpacki s [[0 3] [1 2] [2 1] [3 0]]))

(defn- -valid-item-key [key]
  (let [c (count key)]
   (and (>= c 2) (<= c 255) (not (re-find BAD-ITEM-KEY-RE key)))))

(defn- -valid-utf8? [string]
  (let [
    size (count string)
    bb (ByteBuffer/allocate (* 4 size))
    cb (CharBuffer/allocate (* 4 size))
    ba (.getBytes string ISO8859)
    utf8dec (.newDecoder UTF8)
  ]
  (doseq [i (range (alength ba))]
    (.put bb (aget ba i)))
  (.rewind bb)
  (if (.isMalformed (.decode utf8dec bb cb true)) ((throw (Error. "Invalid item value encoding (non-UTF8)"))))))

(defn- -valid-item-values [values]
  (doseq [value values] (-valid-utf8? value)))

(defn- -valid-item-type [type]
  (ITEM-TYPE-MAP type))

(defn- -valid-item-read-only [ro]
  (or (= ro false) (= ro true)))

(defn- -add-ape-item 
  ([items key values]
    (-add-ape-item items key values "utf8"))
  ([items key values type]
    (-add-ape-item items key values type false))
  ([items k vals type read-only]
    (do
    (let [
      key (str k)
      values (if (seq? vals) (map #(str %) vals) (list (str vals)))
    ]
    (if-not (-valid-item-key key) (throw (Error. "Invalid item key")))
    (if (and (or (= type "utf8") (= type "external"))) (-valid-item-values values))
    (if-not (-valid-item-type type) (throw (Error. "Invalid item type")))
    (if-not (-valid-item-read-only read-only) (throw (Error. "Invalid item read-only flag")))
    (assoc items (.toLowerCase key) {:key key, :values values, :type type, :read-only read-only})))))
    
(defn- -parse-apetag-items [items data nitems]
  (if (= 0 (.length data))
    (if (= 0 nitems) items (throw (Error. "End of tag reached but more items specified")))
    (do 
     (if (= 0 nitems) (throw (Error. "Data remaining after specified number of items parsed")))
     (let [
          data-length (count data)
          length (unpacki (subs data 0 4))
          flags (unpackile (subs data 4 8))
          key-sep (.indexOf data 0 8)
        ]
     (if (> (+ length MIN-ITEM-SIZE) data-length) (throw (Error. "Invalid item length")))
     (if (> flags 7) (throw (Error. "Invalid item flags")))
     (if (= -1 key-sep) (throw (Error. "Missing item key-value separator")))
     (if (> (+ length key-sep 1) data-length) (throw (Error. "Invalid item length")))
     (let [
          key (subs data 8 key-sep)
          value-start (+ 1 key-sep)
          value-end (+ value-start length)
          value (subs data value-start value-end)
          values (seq (.split value "\0"))
        ]
        (if (items (.toLowerCase key)) (throw (Error. "Multiple items with the same key")))
        (recur (-add-ape-item items key values (ITEM-TYPES (bit-shift-right flags 1)) (odd? flags)) (subs data value-end) (dec nitems)))))))

(defn- -parse-apetag-data [fc at]
  (let [data (seek-read fc (- (at :start) 32) (- (at :size) 64))]
    (assoc at :data data, :items (-parse-apetag-items {} data (at :nitems)))))

(defn- -parse-apetag-header [fc at]
  (let [
        header (seek-read fc (at :start) 32)
        preamble (subs header 0 12)
        size (+ 32 (unpacki (subs header 12 16)))
        nitems (unpacki (subs header 16 20))
        rflag (subs header 20 21)
        flags (subs header 21 24)
    ]
    (when-not (= preamble PREAMBLE) (throw (Error. "Missing tag header")))
    (when-not (= flags HEADER-FLAGS) (throw (Error. "Tag has bad header flags")))
    (when-not (or (= rflag "\0") (= rflag "\1")) (throw (Error. "Tag has bad header flags")))
    (when-not (= size (at :size)) (throw (Error. "Tag header size does not match tag footer size")))
    (when-not (= nitems (at :nitems)) (throw (Error. "Tag header item count does not match tag footer item count")))
    (-parse-apetag-data fc (assoc at :header header, :has-tag true))))

(defn- -parse-apetag-footer [fc at]
  (let [
        footer (at :footer)
        size (+ 32 (unpacki (subs footer 12 16)))
        nitems (unpacki (subs footer 16 20))
        rflag (subs footer 20 21)
        flags (subs footer 21 24)
    ]
    (when-not (= flags FOOTER-FLAGS) (throw (Error. "Tag has bad footer flags")))
    (when-not (or (= rflag "\0") (= rflag "\1")) (throw (Error. "Tag has bad footer flags")))
    (when (< size 64) (throw (Error. "Tag size smaller than minimum size (64)")))
    (when (> (+ size (at :id3-length)) (at :filesize)) (throw (Error. "Tag size larger than file size")))
    (when (> size MAX-SIZE) (throw (Error. "Tag size larger than maximum allowed size")))
    (when (> nitems MAX-ITEMS) (throw (Error. "Tag item count larger than maximum allowed item count")))
    (when (> nitems (/ (- size 64) MIN-ITEM-SIZE)) (throw (Error. "Tag item count larger than possible")))
    (-parse-apetag-header fc (assoc at :size size, :nitems nitems, :start (+ size (at :id3-length))))))

(defn- -parse-apetag-ape-footer-check [fc at]
  (let [
      footer-start (+ (at :id3-length) 32)
      footer (seek-read fc footer-start 32)
    ]
    (if (= PREAMBLE (subs footer 0 12))
      (-parse-apetag-footer fc (assoc at :footer footer))
      (assoc at :has-tag false))))

(defn- -parse-apetag-size-check [fc at]
  (let [
    id3-length (count (at :id3))
    atc (assoc at :id3-length id3-length)
    ]
    (if (<= (+ id3-length 64) (at :filesize))
        (-parse-apetag-ape-footer-check fc atc)
        (assoc atc :has-tag false, :start id3-length))))

(defn- -parse-apetag-id3 [fc at]
  (-parse-apetag-size-check fc
    (assoc at :id3 
      (if (and (at :check-id3) (>= (at :filesize) 128))
        (let [id3 (seek-read fc 128 128)]
          (if (= "TAG" (subs id3 0 3)) id3 ""))
        ""))))

(defn- -parse-apetag
  ([filename]
    (-parse-apetag filename (.endsWith (.toLowerCase filename) ".mp3")))
  ([filename check-id3]
    (with-file-channel filename (list StandardOpenOption/READ)
      #(-parse-apetag-id3 % {:items {}, :check-id3 check-id3, :start 0, :filesize (.size %)}))))

(defn- -apetag-str-join [s body]
  (reduce #(str %1 s %2) (first body) (rest body)))

(defn- -print-apetag [at]
  (when-let [items (at :items)]
    (-apetag-str-join "\n" (sort (map #(str (% :key) ": " (-apetag-str-join ", " (% :values))) (vals items))))))

(defn- -apetag-items-extract [at]
  (reduce (fn [map [key value]] (assoc map (value :key) (value :values))) {} (at :items)))

(defn- -apetag-char-bytes [i]
  (let [
    i1 (quot i 16777216)
    j1 (* i1 16777216)
    i2 (quot (- i j1) 65536)
    j2 (+ j1 (* i2 65536))
    i3 (quot (- i j2) 256)
    j3 (+ j2 (* i3 256))
    i4 (- i j3)
  ]
  (map #(char %) (list i1 i2 i3 i4))))
  
(defn- -apetag-packi [i]
  (apply str (reverse (-apetag-char-bytes i))))
  
(defn- -apetag-packile [i]
  (apply str (-apetag-char-bytes i)))

(defn -apetag-raw [at]
  (str (at :header) (at :data) (at :footer) (at :id3)))

(defn- -apetag-raw-item [item]
  (let [
    flags (+ (* 2 (ITEM-TYPE-MAP (item :type))) (if (item :read-only) 1 0))
    sv (-apetag-str-join "\0" (item :values))
    slv (count sv)
  ]
  (str (-apetag-packi slv) (-apetag-packile flags) (item :key) "\0" sv)))

(defn- -raw-item-compare [i1 i2]
  (let [len1 (count i1), len2 (count i2)]
    (if (= len1 len2)
      (compare i1 i2)
      (- len1 len2))))

(defn- -update-apetag-ape [at]
  (let [
    items (at :items)
    item-strings (map #(-apetag-raw-item %) (vals items))
    data (-apetag-str-join "" (sort -raw-item-compare item-strings))
    nitems (count items)
    size (+ 64 (count data))
    start (str PREAMBLE (-apetag-packi (- size 32)) (-apetag-packi nitems))
    header (str start "\0" HEADER-FLAGS END)
    footer (str start "\0" FOOTER-FLAGS END)
  ]
  (when (> nitems MAX-ITEMS) (throw (Error. "Updated tag has too many items")))
  (when (> size MAX-SIZE) (throw (Error. "Updated tag too large")))
  (assoc at :data data, :header header, :footer footer, :has-tag true, :nitems nitems, :size size)))

(defn- -apetag-rzpad [s n]
  (let [l (count s)]
    (if (> l n)
      (subs s 0 n)
      (reduce (fn [st c] (str st "\0")) s (range (- n l))))))

(defn- -apetag-item-value
  ([items key]
    (-apetag-item-value items key ""))
  ([items key def]
    (-apetag-str-join ", " (or (get-in items (list key :values)) (list def)))))
    
(defn- -apetag-item-padded-value [n & body]
  (-apetag-rzpad (apply -apetag-item-value body) n))

(defn- -generate-apetag-id3-string [hash]
  (str "TAG" (hash :title) (hash :artist) (hash :album) (hash :year) (hash :comment) "\0" (char (hash :track)) (char (hash :genre))))

(defn- -generate-apetag-id3 [items]
  (-generate-apetag-id3-string {:title (-apetag-item-padded-value 30 items "title"),
   :artist (-apetag-item-padded-value 30 items "artist"),
   :album (-apetag-item-padded-value 30 items "album"),
   :year (-apetag-rzpad (or (-apetag-item-value items "date" nil) (-apetag-item-value items "year")) 4),
   :comment (-apetag-item-padded-value 28 items "comment"),
   :genre (or (ID3-GENRES-HASH (.toLowerCase (-apetag-item-value items "genre"))) 255),
   :track (try (Integer/valueOf (-apetag-item-value items "track" "0")) (catch NumberFormatException e 0)),
  }))

(defn- -update-apetag-id3 [at]
  (if (and (= 0 (at :id3-length)) (or (not (at :check-id3)) (at :has-tag)))
    (-update-apetag-ape (assoc at :id3 ""))
    (-update-apetag-ape (assoc at :id3 (-generate-apetag-id3 (at :items))))))

; Public Functions

(defn exists?
  "Whether the file currently has an APE tag:
  Arguments: filename [check-id3]
  Returns: boolean
  Example: (apetag/exists? \"file.mp3\")
  ; => true"
  [& body]
  ((apply -parse-apetag body) :has-tag))

(defn full-items
  "A map of items including item metadata.
  Keys are lowercase strings and values are maps with the following keys:
  * :key - The actual case of the item key (String)
  * :read-only - Whether the item's read-only flag is set (true/false)
  * :type - The type of the item (utf8/binary/external/reserved)
  * :values - The item's values (List of Strings)
  Arguments: filename [check-id3]
  Returns: map
  Example: (apetag/full-items \"file.mp3\")
  ; => {\"artist\" {:key \"Artist\", :values (\"Test Artist\"), :type \"utf8\", :read-only false}}"
  [& body]
  ((apply -parse-apetag body) :items))

(defn items
  "A map of items.  Keys are strings and values are lists of strings.
  Arguments: filename [check-id3]
  Returns: map
  Example: (apetag/items \"file.mp3\")
  ; => {\"Artist\" (\"Test Artist\")}"
  [& body]
  (-apetag-items-extract (apply -parse-apetag body)))

(defn print-tag
  "String representing tag items, suitable for pretty printing.
  Arguments: filename [check-id3]
  Returns: string
  Example: (apetag/print-tag \"file.mp3\")
  ; => \"Artist: Test Artist\""
  [& body]
  (-print-apetag (apply -parse-apetag body)))

(defn add-item
  "Add an item to the opaque tag object, used inside a callback function
  passed to update.
  Arguments: opaque-tag key value [type read-only]
  Returns: opaque-tag"
  [at & body]
  (assoc at :items (apply -add-ape-item (at :items) body)))
  
(defn add-items
  "Add items to the opaque tag object, used inside a callback function
  passed to update.
  Arguments: opaque-tag map
  Returns: opaque-tag"
  [at map]
  (reduce (fn [atc [key value]] (assoc atc :items (-add-ape-item (atc :items) key value))) at map))
  
(defn remove-items
  "Remove item(s) from the opaque tag object, used inside a callback function
  passed to update.
  Arguments: opaque-tag key [...]
  Returns: opaque-tag"
  [at & keys]
  (assoc at :items (apply dissoc (at :items) (map #(.toLowerCase %) keys))))

(defn update
  "Update the tag on the given filename using a callback function.
  The callback function is called with an opaque tag object and a map
  of items (the same as would be returned by apetag/items).
  Arguments: callback-fn filename [check-id3]
  Callback Function Arguments: opaque-tag map
  Returns: map
  Examples:
  (apetag/update (fn [at items] (apetag/add-item at \"Album\" \"Test Album\")) \"file.mp3\")
  ; => {\"Album\" (\"Test Album\")}
  (apetag/update (fn [at items] (apetag/add-items at {\"Album\" \"Test Album\"})) \"file.mp3\")
  ; => {\"Album\" (\"Test Album\")}
  (apetag/update (fn [at items] (apetag/remove-items at \"Album\")) \"file.mp3\")
  ; => {}"
  [f & body]
  (let [
    at (apply -parse-apetag body)
    mat (f at (-apetag-items-extract at))
    uat (-update-apetag-id3 mat)
    new-items (-apetag-items-extract uat)
  ]
  (seek-write-truncate (first body) (uat :start) (-apetag-raw uat))
  new-items))
  
(defn raw
  "Raw tag string, useful mostly for testing.
  Arguments: filename [check-id3]
  Returns: string
  Example: (apetag/raw \"file.mp3\")
  ; => \"\""
  [& body]
  (-apetag-raw (apply -parse-apetag body)))

(defn remove-tag
  "Remove the tag from the filename, returns whether the file had a
  tag to begin with.
  Arguments: filename [check-id3]
  Returns: boolean
  Example: (apetag/remove-tag \"file.mp3\")
  ; => true"
  [& body]
  (let [
    at (apply -parse-apetag body)
    has-tag (at :has-tag)
  ]
  (seek-write-truncate (first body) (at :start) "")
  has-tag))
