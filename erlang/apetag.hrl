-define(APE_MAX_SIZE, 8192).
-define(APE_MAX_ITEM_COUNT, 64).
-define(APE_ITEM_MIN_SIZE, 11).
-define(GENRES, ["Blues", "Classic Rock", "Country", "Dance", "Disco", "Funk", "Grunge", 
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
        "Trash Meta", "Anime", "Jpop", "Synthpop"]).
-record(apetag, {filename, file = nil, check_id3 = true, has_tag = nil,  file_size = nil, tag_start = nil, tag_size = nil, tag_item_count = nil, tag_header = nil, tag_data = nil, tag_footer = nil, id3 = nil, fields = nil}).
-record(apeitem, {key, values, flags, lowercase_key}).
