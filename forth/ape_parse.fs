\ Extremely basic APE tag parser for pfe forth
\ No error checking 
\ Only works on little endian platforms
\ Expects tags in their own file

: slurp-file ( filename filename-size -- tag-start )
  r/o open-file drop \ file*
  dup file-size 2drop \ file* size
  dup allocate drop \ file* size c-addr
  3dup swap rot read-file 2drop \ file* size c-addr
  rot close-file drop swap drop ; \ c-addr

: apetag-numitems ( tag-start -- tag-start num_items )
  dup 16 + @ ; \ c-addr size num_items ;

: find-value-start ( key-start -- value-start )
  1+ begin 1+ dup c@ 0 = 0= while repeat 1+ ;

: parse-apeitem ( item-start -- next-item-start )
  dup @ \ item-start length
  swap 8 + \ length key-start
  dup find-value-start \ length key-start value-start
  swap 2dup - 1- type ." : " \ length value-start
  2dup swap type cr \ length value-start
  + ; \ next-item-start

: parse-apeitems ( tag-start num_items -- )
  over 32 + swap \ tag-start item-start num_items
  0 do parse-apeitem loop drop free drop ; \

: parse-apetag \ filename filename-size --
  2dup type cr
  dup 0 do 45 emit loop cr
  slurp-file apetag-numitems
  parse-apeitems ;

: parse-apetags
  argc 0 do i argv parse-apetag cr loop ;

parse-apetags
