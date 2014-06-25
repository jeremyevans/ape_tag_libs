\ Extremely basic APE tag parser for pfe forth
\ No error checking 
\ Only handles a single value per item
\ Only works on little endian platforms

: fsize ( file* -- file* s.size)
  dup file-size drop ;
  
: buf ( file* length -- file* c-addr )
  dup allocate drop \ file* length c-addr
  3dup swap rot \ file* length c-addr c-addr length file*
  read-file 2drop \ file* length c-addr
  swap drop ;

: seek-to ( file* -offset -- file* )
  swap fsize \ -offset file* s.size
  3 pick 0 \ -offset file* s.size -o.offset
  d- 2 pick \ -offset *file o.offset file*
  reposition-file drop nip ;

: check ( c-addr1 -- c-addr1 bool )
  dup 8 s" APETAGEX" \ c-addr c-addr 8 c-addr2 8
  compare 0= ; \ c-addr diff#

: apetag-size ( tag-start -- tag-start tag-size )
  dup 12 + @ 32 + ; 

: buf-at ( file* length -- file* c-addr)
   dup rot rot seek-to swap buf ;

: check-buf-at ( file* length -- file* c-addr bool)
  buf-at check ;

: tag-buf ( file* tag-offset c-addr -- tag-start )
  apetag-size swap \ file* tag-offset tag-size tag-start
  free drop + \ file* tag-offset
  dup rot swap \ tag-size file* tag-size
  seek-to \ tag-size file*
  swap buf \ file* c-addr
  swap close-file drop ;
   
: slurp-tag ( filename filename-size -- tag-start )
  r/o open-file drop \ file*
  32 check-buf-at \ file* c-addr bool
  if 
    0 swap tag-buf
  else
    free drop \ file*
    160 check-buf-at \ file* c-addr bool
    if
      128 swap tag-buf
    else
      free drop \ file*
      close-file
      0
    then
  then ;
  
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
  dup 0=
  if
    ." No items in the APEv2 Tag" cr
    exit
  then 0 do parse-apeitem loop drop free drop ; \

: parse-apetag \ filename filename-size --
  2dup type cr
  dup 0 do 45 emit loop cr
  slurp-tag dup 0= if
    ." No APEv2 Tag Present" cr
    drop
  else
    apetag-numitems
    parse-apeitems
  then ;

: parse-apetags
  argc 0 do i argv parse-apetag cr loop ;

parse-apetags
