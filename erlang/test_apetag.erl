-module(test_apetag).
-include_lib("apetag.hrl").
-export([start/0]).
-define(FILENAME, "test.apetag").
-define(ELSE, true).
-define(APETAG_ATTRS, [filename, file, check_id3, has_tag, file_size, tag_start, tag_size, tag_item_count, tag_header, tag_data, tag_footer, id3, fields]).
-define(EMPTY_APE_TAG, <<"APETAGEX\320\7\0\0 \0\0\0\0\0\0\0\0\0\0\240\0\0\0\0\0\0\0\0APETAGEX\320\7\0\0 \0\0\0\0\0\0\0\0\0\0\200\0\0\0\0\0\0\0\0TAG\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\377">>).
-define(EXAMPLE_APE_TAG, <<"APETAGEX\320\7\0\0\260\0\0\0\6\0\0\0\0\0\0\240\0\0\0\0\0\0\0\0\1\0\0\0\0\0\0\0Track\0001\4\0\0\0\0\0\0\0Date\0002007\11\0\0\0\0\0\0\0Comment\0XXXX-0000\13\0\0\0\0\0\0\0Title\0Love Cheese\13\0\0\0\0\0\0\0Artist\0Test Artist\26\0\0\0\0\0\0\0Album\0Test Album\0Other AlbumAPETAGEX\320\7\0\0\260\0\0\0\6\0\0\0\0\0\0\200\0\0\0\0\0\0\0\0TAGLove Cheese\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0Test Artist\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0Test Album, Other Album\0\0\0\0\0\0\0002007XXXX-0000\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\1\377">>).
-define(EXAMPLE_APE_TAG_TWO, <<"APETAGEX\320\7\0\0\231\0\0\0\5\0\0\0\0\0\0\240\0\0\0\0\0\0\0\0\4\0\0\0\0\0\0\0Blah\0Blah\4\0\0\0\0\0\0\0Date\0002007\11\0\0\0\0\0\0\0Comment\0XXXX-0000\13\0\0\0\0\0\0\0Artist\0Test Artist\26\0\0\0\0\0\0\0Album\0Test Album\0Other AlbumAPETAGEX\320\7\0\0\231\0\0\0\5\0\0\0\0\0\0\200\0\0\0\0\0\0\0\0TAG\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0Test Artist\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0Test Album, Other Album\0\0\0\0\0\0\0002007XXXX-0000\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\377">>).
-define(EXAMPLE_APE_FIELDS, [{"Track", ["1"]}, {"Comment", ["XXXX-0000"]}, {"Album", ["Test Album", "Other Album"]}, {"Title", ["Love Cheese"]}, {"Artist", ["Test Artist"]}, {"Date", ["2007"]}]).
-define(EXAMPLE_APE_FIELDS_TWO, [{"Blah", ["Blah"]}, {"Comment", ["XXXX-0000"]}, {"Album", ["Test Album", "Other Album"]}, {"Artist", ["Test Artist"]}, {"Date", ["2007"]}]).
-define(EXAMPLE_APE_TAG_PRETTY_PRINT, "Album: Test Album, Other Album\nArtist: Test Artist\nComment: XXXX-0000\nDate: 2007\nTitle: Love Cheese\nTrack: 1").
-define(ASSERT_ERROR_TIME, 2000).

receive_messages() ->
    receive
        _ ->
            receive_messages()
    after
        0 ->
            nil
    end.

assert_error(F) ->
    receive_messages(),
    spawn_link(fun() -> F() end),
    process_flag(trap_exit, true),
    receive
        {'EXIT', _, normal} ->
            exit("No error occured");
        {'EXIT', _, _} ->
            nil;
        _ ->
            exit("Bad received message")
    after
        ?ASSERT_ERROR_TIME ->
            exit("No error occured after time allowed")
    end.

write_tag_file(Data) ->
    {ok, File} = file:open(?FILENAME, [read, write, binary]),
    ok = file:write(File, Data),
    File.

write_tag_file(Data, Changes) when is_list(Data) ->
    {ok, File} = file:open(?FILENAME, [read, write, binary]),
    {ok, 0} = file:position(File, bof),
    ok = file:truncate(File),
    ok = file:write(File, Data),
    write_tag_file(File, Changes);
write_tag_file(File, []) ->
    File;
write_tag_file(File, Changes) ->
    {At, Data} = hd(Changes),
    {ok, At} = file:position(File, At),
    ok = file:write(File, Data),
    write_tag_file(File, tl(Changes)).
    

% ApeTag Size
siz(AT) ->
    atv(AT, file_size).

% ApeTag Value Position
atv_pos(Name) ->
    atv_pos_r(?APETAG_ATTRS, Name, 0).
atv_pos_r(Attrs, Name, Num) -> 
    if Name == hd(Attrs) ->
        Num;
    ?ELSE ->
        atv_pos_r(tl(Attrs), Name, Num+1)
    end.

% ApeTag value
atv(AT, Attr) ->
    atv_r(tl(tuple_to_list(apetag:get_fields(AT))), atv_pos(Attr), 0).
atv_r(Values, NumWant, Num) ->
    if Num == NumWant ->
        hd(Values);
    ?ELSE ->
        atv_r(tl(Values), NumWant, Num+1)
    end.

% ApeItem field value
fv(AT, Name) ->
    Item = dict:fetch(string:to_lower(Name), AT#apetag.fields),
    Item#apeitem.values.

% Have equal fields
hef(AT, Items) ->
    lists:foreach(fun(Item) -> 
        {Key, Values} = Item,
        Values = fv(apetag:get_fields(AT), Key)
    end, Items).

% Remove id3 from tag if necessary
rid(BinTag, CID3) ->
    if CID3 == true ->
        BinTag;
    ?ELSE ->
        {BT, _} = split_binary(BinTag, size(BinTag) - 128),
        BT
    end.

tag_test(AT, F) ->
    AT1 = F(AT),
    Size = siz(F(AT1)),
    CID3 = atv(F(AT1), check_id3),
    EMPTY_DICT = dict:new(),
    if CID3 == true ->
        ID3Size = 128;
    ?ELSE ->
        ID3Size = 0
    end,
    false = atv(F(AT1), has_tag),
    <<>> = apetag:raw(F(AT1)),
    Size = siz(F(AT1)),
    AT2 = apetag:remove(F(AT1)),
    Size = siz(F(AT2)),
    EMPTY_DICT = atv(F(AT2), fields),
    AT3 = apetag:update(F(AT2), fun(Fields) -> Fields end),
    Size1 = Size + 64 + ID3Size,
    Size1 = siz(F(AT3)),
    true = atv(F(AT3), has_tag),
    EMPTY_APE_TAG = rid(?EMPTY_APE_TAG, CID3),
    EMPTY_APE_TAG = apetag:raw(F(AT3)),
    EMPTY_DICT = atv(F(AT3), fields),
    AT4 = apetag:update(F(AT3), fun(Fields) -> Fields end),
    Size1 = siz(F(AT4)),
    AT5 = apetag:remove(F(AT4)),
    Size = siz(F(AT5)),
    AT6 = apetag:update(F(AT5), fun(Fields) -> apetag:add_apeitems(?EXAMPLE_APE_FIELDS, Fields) end),
    Size2 = Size + 208 + ID3Size,
    Size2 = siz(F(AT6)),
    hef(F(AT6), ?EXAMPLE_APE_FIELDS),
    ?EXAMPLE_APE_TAG_PRETTY_PRINT = apetag:pretty_print(F(AT6)),
    true = atv(F(AT6), has_tag),
    EXAMPLE_APE_TAG = rid(?EXAMPLE_APE_TAG, CID3),
    EXAMPLE_APE_TAG = apetag:raw(F(AT6)),
    AT7 = apetag:update(F(AT6), fun(Fields) -> Fields end),
    Size2 = siz(F(AT7)),
    hef(F(AT7), ?EXAMPLE_APE_FIELDS),
    AT8 = apetag:update(F(AT7), fun(Fields) -> apetag:remove_apeitems(["Track", "Title"], apetag:add_apeitem("Blah", "Blah", Fields)) end),
    Size3 = Size2 - 23,
    Size3 = siz(F(AT8)),
    hef(F(AT8), ?EXAMPLE_APE_FIELDS_TWO),
    true = atv(F(AT8), has_tag),
    EXAMPLE_APE_TAG2 = rid(?EXAMPLE_APE_TAG_TWO, CID3),
    EXAMPLE_APE_TAG2 = apetag:raw(F(AT8)),
    AT9 = apetag:update(F(AT8), fun(Fields) -> Fields end),
    Size3 = siz(F(AT8)),
    hef(F(AT8), ?EXAMPLE_APE_FIELDS_TWO),
    AT10 = apetag:remove(F(AT9)),
    false = atv(F(AT10), has_tag),
    Size = siz(F(AT10)),
    <<>> = apetag:raw(F(AT10)),
    nil.

tests() ->
[
% test ape item new and validations
fun() ->
    % String value
    AI = apetag:new_apeitem("BlaH", "BlAh", 0),
    "BlaH" = AI#apeitem.key,
    "blah" = AI#apeitem.lowercase_key,
    0 = AI#apeitem.flags,
    ["BlAh"] = AI#apeitem.values,
    <<"\4\0\0\0\0\0\0\0BlaH\0BlAh">> = apetag:raw_apeitem(AI),
    apetag:validate_apeitem(AI),
    % Array of string values and flags
    AI2 = apetag:new_apeitem("BlaH", ["BlAh"], 3),
    "BlaH" = AI2#apeitem.key,
    "blah" = AI2#apeitem.lowercase_key,
    3 = AI2#apeitem.flags,
    ["BlAh"] = AI2#apeitem.values,
    <<"\4\0\0\0\0\0\0\3BlaH\0BlAh">> = apetag:raw_apeitem(AI2),
    apetag:validate_apeitem(AI2),
    % Array of mixed values
    AI3 = apetag:new_apeitem("BlaH", [32, 32, 32, "BlAh"], 7),
    "BlaH" = AI3#apeitem.key,
    "blah" = AI3#apeitem.lowercase_key,
    7 = AI3#apeitem.flags,
    ["   ", "BlAh"] = AI3#apeitem.values,
    <<"\10\0\0\0\0\0\0\7BlaH\0   \0BlAh">> = apetag:raw_apeitem(AI3),
    apetag:validate_apeitem(AI3),
    % Empty array value
    AI4 = apetag:new_apeitem("BlaH", [], 6),
    "BlaH" = AI4#apeitem.key,
    "blah" = AI4#apeitem.lowercase_key,
    6 = AI4#apeitem.flags,
    [] = AI4#apeitem.values,
    %<<"\0\0\0\0\0\0\0\6BlaH\0">> = apetag:raw_apeitem(AI4),
    apetag:validate_apeitem(AI4),
    
    % Test flags
    lists:foreach(fun(Num) ->
        apetag:validate_apeitem(AI#apeitem{flags=Num}),
        Raw = list_to_binary([<<"\4\0\0\0\0\0\0">>, [Num], <<"BlaH\0BlAh">>]),
        Raw = apetag:raw_apeitem(AI#apeitem{flags=Num})
    end, [1,2,3,4,5,6,7]),
    lists:foreach(fun(Num) ->
        assert_error(fun() -> 
            apetag:validate_apeitem(AI#apeitem{flags=Num})
        end)
    end, [-100, -1, 8, 9, 100]),

    % Test keys
    lists:foreach(fun(Num) ->
        assert_error(fun() -> 
            apetag:validate_apeitem(apetag:new_apeitem([Num, 32, 32], "BlAh", 0))
        end)
    end, lists:append([lists:seq(1, 31), lists:seq(128, 255)])),
    lists:foreach(fun(Key) ->
        assert_error(fun() -> 
            apetag:validate_apeitem(apetag:new_apeitem(Key, "BlAh", 0))
        end)
    end, [1, "", "x", string:copies("x", 256), "id3", "tag", "oggs", "mp+"]),
    lists:foreach(fun(Num) ->
        apetag:validate_apeitem(apetag:new_apeitem([Num, 32, 32], "BlAh", 0))
    end, lists:seq(32, 127)),
    lists:foreach(fun(Key) ->
        apetag:validate_apeitem(apetag:new_apeitem(lists:append([Key, "  "]), "BlAh", 0))
    end, ["id3", "tag", "oggs", "mp+"]),
    lists:foreach(fun(Num) ->
        apetag:validate_apeitem(apetag:new_apeitem(string:copies("x", Num), "BlAh", 0))
    end, lists:seq(2, 255)),
    
    % Test raw with multiple values
    <<"\10\0\0\0\0\0\0\0BlaH\0BlAh\0XYZ">> = apetag:raw_apeitem(apetag:new_apeitem("BlaH", ["BlAh", "XYZ"], 0)),
    
    % Test invalid utf8 value when utf8 required
    assert_error(fun() -> 
        apetag:validate_apeitem(apetag:new_apeitem("BlaH", ["BlAh", "X\377Z"], 0))
    end),
    % Test invalid utf8 value when utf8 not required
    apetag:validate_apeitem(apetag:new_apeitem("BlaH", ["BlAh", "X\377Z"], 3))
end,

% test ape item parsing
fun() ->
    Data = "\10\0\0\0\0\0\0\7BlaH\0BlAh\0XYZ",
    {AI, "", 0} = apetag:parse_apeitem(Data, length(Data)),
    7 = AI#apeitem.flags,
    "BlaH" = AI#apeitem.key,
    ["BlAh", "XYZ"] = AI#apeitem.values,
    
    % Check for bad keys, no key ends, bad start point, bad flags, length too
    %   long, and invalid utf8
    lists:foreach(fun(Raw) ->
        assert_error(fun() -> apetag:parse_apeitem(Raw, length(Raw)) end)
    end, ["\0\0\0\0\0\0\0\7x\0", "\10\0\0\0\0\0\0\7BlaHxBlAhxXYZ", 
        "\0\0\0\0\0\0\7BlaH\0BlAh\0XYZ", "\10\0\0\0\0\0\0\10BlaH\0BlAh\0XYZ",
        "\11\0\0\0\0\0\0\10BlaH\0BlAh\0XYZ", 
        "\13\0\0\0\0\0\0\10BlaH\0BlAh\0XYZ\0\377"]),
        
    % Parsing with length shorter than value OK 
    Data1 = "\3\0\0\0\0\0\0\6BlaH\0BlAh\0XYZ",
    {AI1, "h\0XYZ", 5} = apetag:parse_apeitem(Data1, length(Data1)),
    6 = AI1#apeitem.flags,
    "BlaH" = AI1#apeitem.key,
    ["BlA"] = AI1#apeitem.values,
    
    % Parsing with different key end
    Data2 = "\3\0\0\0\0\0\0\3BlaH3BlAh\0XYZ",
    {AI2, "", 0} = apetag:parse_apeitem(Data2, length(Data2)),
    3 = AI2#apeitem.flags,
    "BlaH3BlAh" = AI2#apeitem.key,
    ["XYZ"] = AI2#apeitem.values
end,

% Test bad tags
fun() ->
    E = binary_to_list(?EMPTY_APE_TAG),
    E2 = binary_to_list(?EXAMPLE_APE_TAG),
    apetag:raw(#apetag{file=write_tag_file(E)}),
    apetag:raw(#apetag{file=write_tag_file(E, [{20, [1]}])}),
    apetag:raw(#apetag{file=write_tag_file(E, [{52, [1]}])}),

    lists:foreach(fun(Num) ->
        assert_error(fun() -> apetag:raw(#apetag{file=write_tag_file(E, [{20, [Num]}])}) end),
        assert_error(fun() -> apetag:raw(#apetag{file=write_tag_file(E, [{52, [Num]}])}) end),
        assert_error(fun() -> apetag:raw(#apetag{file=write_tag_file(E, [{20, [Num]}, {52, [Num]}])}) end)
    end, lists:seq(2, 255)),
    
    lists:foreach(fun(Changes) ->
        case Changes of
            {f, Cs} ->
                assert_error(fun() -> apetag:fields(#apetag{file=write_tag_file(E2, Cs)})  end);
            {Data, Cs} ->
                assert_error(fun() -> apetag:raw(#apetag{file=write_tag_file(Data, Cs)})  end);
            Fun when is_function(Fun) ->
                assert_error(fun() -> apetag:update(#apetag{file=write_tag_file(E)}, Fun)  end);
            Changes when is_list(Changes) ->
                assert_error(fun() -> apetag:raw(#apetag{file=write_tag_file(E, Changes)})  end)
        end
    end, [
        [{44, [31]}], % Less than minimum size
        [{44, [0]}], % Less than minimum size
        [{44, [225, 31]}], % > Maximum size when larger than file
        {lists:append([string:copies(" ", ?APE_MAX_SIZE),E]), [{44+?APE_MAX_SIZE, [225, 31]}]}, % > Maximum size when larger than file
        [{44, [33]}], % Unmatched header and footer tag size, footer size wrong
        [{44, [33]}, {12, [33]}], % Matching header and footer tag size, too large for file
        {[32|E], [{45, [33]}, {13, [33]}]}, % Matching header and footer tag size, not too large for file, but can't find header
        {[32|E], [{45, [32]}, {13, [33]}]}, % Unmatched header and footer tag size, header size wrong
        [{48, [65]}], % > Maximum allowed item count
        [{48, [1]}], % Item count greater than possible given tag size
        [{16, [1]}], % Unmatched header and footer item count, header size wrong
        {E2, [{208-16, [5]}]}, % Unmatched header and footer tag size, footer size wrong
        [{0, [0]}], % Missing/corrupt header
        {f, [{32, [2]}]}, % Bad first item size
        {f, [{40, [0]}]}, % Bad first item invalid key
        {f, [{40, [1]}]}, % Bad first item key end
        {f, [{47, [255]}]}, % Bad second item length too long
        {f, [{40, "Album"}]}, % Duplicate case insensitive keys
        {f, [{40, "ALBUM"}]}, % Duplicate case insensitive keys
        {f, [{40, "album"}]}, % Duplicate case insensitive keys
        {f, [{16, [5]}, {192, [5]}]}, % Item count incorrect (too low)
        {f, [{16, [7]}, {192, [7]}]}, % Item count incorrect (too high)
        fun(Fields) -> apetag:add_apeitem("album", [254], Fields) end, % Updating with invalid value
        fun(Fields) -> apetag:add_apeitem("x", "", Fields) end, % Updating with invalid key
        fun(Fields) -> lists:foldl(fun(Num, Acc) -> 
            apetag:add_apeitem([32, 32, Num+32], [], Acc) 
        end, Fields, lists:seq(0, ?APE_MAX_ITEM_COUNT)) end, % Updating with too many items
        fun(Fields) -> apetag:add_apeitem("xx", string:copies(" ", 8118), Fields) end % Updating with tag too large
    ]),
    
    % Test case insensitive key during updates
    lists:foreach(fun(Key) ->
        ApeTag = apetag:update(#apetag{file=write_tag_file(E2, [])}, fun(Fields) -> 
            apetag:add_apeitem(Key, "blah", Fields) 
        end),
        Item = dict:fetch(string:to_lower(Key), ApeTag#apetag.fields),
        Key = Item#apeitem.key
    end, ["album", "ALBUM", "aLbUM"]),
    
    % Test updating works with just enough items
    apetag:update(#apetag{file=write_tag_file(E, [])}, fun(Fields) -> 
        lists:foldl(fun(Num, Acc) -> 
            apetag:add_apeitem([32, 32, Num+32], [], Acc) 
        end, Fields, lists:seq(1, ?APE_MAX_ITEM_COUNT))
    end),
    
    % Test updating with just large enough tag
    apetag:update(#apetag{file=write_tag_file(E, [])}, fun(Fields) -> 
        apetag:add_apeitem("xx", string:copies(" ", 8117), Fields)
    end),
    
    ok = file:delete(?FILENAME)
end,

% test check id3
fun() ->
    File = write_tag_file("", []),
    0 = siz(#apetag{file=File}),
    
    % Test add id3 to files if check_id3 not specified
    AT1 = apetag:update(#apetag{file=File}, fun(F) -> F end),
    192 = siz(AT1),
    
    % Test don't remove tag if id3 tag exists and not checking id3
    AT2 = apetag:remove(#apetag{file=File, check_id3=false}),
    192 = siz(AT2),
    
    % Test don't add id3s if ape tag exists and id3 does not
    {ok, 64} = file:position(File, 64),
    ok = file:truncate(File),
    64 = siz(#apetag{file=File}),
    AT3 = apetag:update(#apetag{file=File}, fun(F) -> F end),
    64 = siz(AT3),
    AT4 = apetag:remove(AT3),
    0 = siz(AT4),
    
    % Test don't add id3 if not checking id3
    AT5 = apetag:update(#apetag{file=File, check_id3=false}, fun(F) -> F end),
    64 = siz(AT5),
    AT6 = apetag:remove(AT5),
    0 = siz(AT6),

    ok = file:close(File),
    ok = file:delete(?FILENAME)
end,

% test suite with many permutations
fun() ->
    lists:foreach(fun(Num) ->
        lists:foreach(fun(CID3) ->
            File = write_tag_file(string:copies(" ", Num)),
            tag_test(#apetag{file=File, check_id3=CID3}, fun(_AT) -> #apetag{file=File, check_id3=CID3} end),
            tag_test(#apetag{file=File, check_id3=CID3}, fun(AT) -> AT end),
            ok = file:close(File),
            tag_test(#apetag{filename=?FILENAME, check_id3=CID3}, fun(_AT) -> #apetag{filename=?FILENAME, check_id3=CID3} end),
            tag_test(#apetag{filename=?FILENAME, check_id3=CID3}, fun(AT) -> AT end),
            ok = file:delete(?FILENAME)
        end, [true, false])
    end, [0,1,63,64,65,127,128,129,191,192,193,8191,8192,8193])
end
].

start() ->
    error_logger:tty(false),
    lists:foldl(fun(Fun, Num) -> 
        io:format("Starting Test ~w ... ", [Num]), 
        Fun(), 
        io:format("Finished Successfully~n"),
        Num + 1 
    end, 1, tests()).
