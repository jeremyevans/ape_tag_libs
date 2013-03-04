(ns apetag-spec-files)

(use 'apetag)
(use 'clojure.test)
(use '[clojure.java.shell :only [sh]])

(defn- tagname [name]
  (str "../test-files/" name ".tag"))

(defn- corrupt [name, msg]
  (is (thrown-with-msg? Error (re-pattern msg) (apetag/items (tagname name)))))

(defn- cmp-file [from, to, f]
  (sh "cp" (tagname from) (tagname "test"))
  (f)
  (let [x (:exit (sh "cmp" "-s" (tagname to) (tagname "test")))]
    (sh "rm" (tagname "test"))
    x))

(defn- update-tag [from, to, f]
  (cmp-file from to #(apetag/update (fn [at _] (f at)) (tagname "test"))))

(defn- update-tag-id3 [from, to, f]
  (cmp-file from to #(apetag/update (fn [at _] (f at)) (tagname "test") true)))

(defn- update-throws [msg, f]
  (sh "cp" (tagname "missing-ok") (tagname "test"))
  (is (thrown-with-msg? Error (re-pattern msg) (apetag/update (fn [at _] (f at)) (tagname "test"))))
  (sh "rm" (tagname "test")))

(defn- repeat-string [times s]
  (apply str (repeat times s)))

(println "Starting Testing...")

(corrupt "corrupt-count-larger-than-possible" "Tag item count larger than possible")
(corrupt "corrupt-count-mismatch" "Tag header item count does not match tag footer item count")
(corrupt "corrupt-count-over-max-allowed" "Tag item count larger than maximum allowed item count")
(corrupt "corrupt-data-remaining" "Data remaining after specified number of items parsed")
(corrupt "corrupt-duplicate-item-key" "Multiple items with the same key")
(corrupt "corrupt-finished-without-parsing-all-items" "End of tag reached but more items specified")
(corrupt "corrupt-footer-flags" "Tag has bad footer flags")
(corrupt "corrupt-header" "Missing tag header")
(corrupt "corrupt-item-flags-invalid" "Invalid item flags")
(corrupt "corrupt-item-length-invalid" "Invalid item length")
(corrupt "corrupt-key-invalid" "Invalid item key")
(corrupt "corrupt-key-too-short" "Invalid item key")
(corrupt "corrupt-key-too-long" "Invalid item key")
(corrupt "corrupt-min-size" "Tag size smaller than minimum size \\(64\\)")
(corrupt "corrupt-missing-key-value-separator" "Missing item key-value separator")
(corrupt "corrupt-next-start-too-large" "Invalid item length")
(corrupt "corrupt-size-larger-than-possible" "Tag size larger than file size")
(corrupt "corrupt-size-mismatch" "Tag header size does not match tag footer size")
(corrupt "corrupt-size-over-max-allowed" "Tag size larger than file size")
(corrupt "corrupt-value-not-utf8" "Invalid item value encoding \\(non-UTF8\\)")

(is (= false (apetag/exists? (tagname "missing-ok") true)))
(is (= true (apetag/exists? (tagname "good-empty") true)))
(is (= false (apetag/exists? (tagname "good-empty-id3-only") true)))
(is (= true (apetag/exists? (tagname "good-empty-id3") true)))

(is (= {} (apetag/items (tagname "good-empty"))))
(is (= {"name" '("value")} (apetag/items (tagname "good-simple-1"))))
(is (= (reduce #(assoc %1 (str (. Integer toString %2 10) "n") (list (repeat-string %2 "a"))) {} (range 63)) (apetag/items (tagname "good-many-items"))))
(is (= {"name" '("va" "ue")} (apetag/items (tagname "good-multiple-values"))))

(is (= {} (apetag/full-items (tagname "good-empty"))))
(is (= {"name" {:key "name", :values '("value"), :type "utf8", :read-only false}} (apetag/full-items (tagname "good-simple-1"))))
(is (= (reduce #(assoc %1 (str (. Integer toString %2 10) "n") {:key (str (. Integer toString %2 10) "n"), :values (list (repeat-string %2 "a")), :type "utf8", :read-only false}) {} (range 63)) (apetag/full-items (tagname "good-many-items"))))
(is (= {"name" {:key "name", :values '("va" "ue"), :type "utf8", :read-only false}} (apetag/full-items (tagname "good-multiple-values"))))
(is (= {"name" {:key "name", :values '("value"), :type "external", :read-only true}} (apetag/full-items (tagname "good-simple-1-ro-external"))))
(is (= {"name" {:key "name", :values '("v\201lue"), :type "binary", :read-only false}} (apetag/full-items (tagname "good-binary-non-utf8-value"))))

(is (= 0 (cmp-file "good-empty" "missing-ok" #(apetag/remove-tag (tagname "test")))))
(is (= 0 (cmp-file "good-empty-id3" "missing-ok" #(apetag/remove-tag (tagname "test") true))))
(is (= 0 (cmp-file "good-empty-id3-only" "missing-ok" #(apetag/remove-tag (tagname "test") true))))
(is (= 0 (cmp-file "missing-10k" "missing-10k" #(apetag/remove-tag (tagname "test")))))

(is (= 0 (update-tag "good-empty" "good-empty" (fn [at] at))))
(is (= 0 (update-tag "missing-ok" "good-empty" (fn [at] at))))
(is (= 0 (update-tag "good-empty" "good-simple-1" #(apetag/add-item % "name" "value"))))
(is (= 0 (update-tag "good-simple-1" "good-empty" #(apetag/remove-items % "name"))))
(is (= 0 (update-tag "good-simple-1" "good-empty" #(apetag/remove-items % "Name"))))
(is (= 0 (update-tag "good-empty" "good-simple-1-ro-external" #(apetag/add-item % "name" "value" "external" true))))
(is (= 0 (update-tag "good-empty" "good-binary-non-utf8-value" #(apetag/add-item % "name" "v\201lue" "binary"))))
(is (= 0 (update-tag "good-empty" "good-many-items" (fn [at] (apetag/add-items at (reduce #(assoc %1 (str (. Integer toString %2 10) "n") (list (repeat-string %2 "a"))) {} (range 63)))))))
(is (= 0 (update-tag "missing-ok" "good-multiple-values" #(apetag/add-item % "name" '("va" "ue")))))
(is (= 0 (update-tag "good-multiple-values" "good-simple-1-uc" #(apetag/add-item % "NAME" "value"))))
(is (= 0 (update-tag "missing-ok" "good-simple-1-utf8" #(apetag/add-item % "name" "v\303\202\303\225"))))

(update-throws "Updated tag has too many items" (fn [at] (apetag/add-items at (reduce #(assoc %1 (str (. Integer toString %2 10) "n") (list (repeat-string %2 "a"))) {} (range 65)))))
(update-throws "Updated tag too large" #(apetag/add-item % "xn" (repeat-string 8118 "a")))
(update-throws "Invalid item key" #(apetag/add-item % (repeat-string 256 "n") "a"))
(update-throws "Invalid item key" #(apetag/add-item % "n\000" "a"))
(update-throws "Invalid item key" #(apetag/add-item % "n\037" "a"))
(update-throws "Invalid item key" #(apetag/add-item % "n\200" "a"))
(update-throws "Invalid item key" #(apetag/add-item % "n\377" "a"))
(update-throws "Invalid item key" #(apetag/add-item % "tag" "a"))
(update-throws "Invalid item value encoding \\(non-UTF8\\)" #(apetag/add-item % "ab" "n\377"))
(update-throws "Invalid item type" #(apetag/add-item % "name" "value" "foo"))

(is (= 0 (update-tag-id3 "good-empty-id3-only" "good-empty-id3" (fn [at] at))))
(is (= 0 (update-tag-id3 "good-empty-id3" "good-simple-4" #(apetag/add-items % {"track" "1", "genre" "Game", "year" "1999", "title" "Test Title", "artist" "Test Artist", "album" "Test Album", "comment" "Test Comment"}))))
(is (= 0 (update-tag-id3 "good-empty-id3" "good-simple-4-uc" #(apetag/add-items % {"Track" "1", "Genre" "Game", "Year" "1999", "Title" "Test Title", "Artist" "Test Artist", "Album" "Test Album", "Comment" "Test Comment"}))))
(is (= 0 (update-tag-id3 "good-empty-id3" "good-simple-4-long" #(apetag/add-items % {"track" "1", "genre" "Game", "year" (repeat-string 2 "1999"), "title" (repeat-string 5 "Test Title"), "artist" (repeat-string 5 "Test Artist"), "album" (repeat-string 5 "Test Album"), "comment" (repeat-string 5 "Test Comment")}))))
(is (= 0 (update-tag-id3 "good-empty-id3" "good-simple-4-date" #(apetag/add-items % {"track" "1", "genre" "Game", "date" "12/31/1999", "title" "Test Title", "artist" "Test Artist", "album" "Test Album", "comment" "Test Comment"}))))

(println "Finished Testing.")
(System/exit 0)
