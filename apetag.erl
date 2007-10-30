-module(apetag).
-export([add_apeitem/3, add_apeitem/4, add_apeitems/2, get_fields/1, get_tag_information/1, new/1, new/2, pretty_print/1, raw/1, remove/1, remove_apeitem/2, remove_apeitems/2, update/2]).
-export([new_apeitem/3, raw_apeitem/1, validate_apeitem/1, parse_apeitem/2]). % For testing internals
-include_lib("apetag.hrl").
-define(APE_PREAMBLE, <<"APETAGEX",208,7,0,0>>).
-define(APE_HEADER_FLAGS, <<0,0,0,160>>).
-define(APE_FOOTER_FLAGS, <<0,0,0,128>>).
-define(APE_YEAR_RE, "[0-9][0-9][0-9][0-9]").
-define(ELSE, true).

access_file(ApeTag, _Mode, Fun) when is_record(ApeTag, apetag), ApeTag#apetag.file /= nil ->
    Fun(ApeTag);
access_file(OldApeTag, Mode, Fun) when is_record(OldApeTag, apetag), is_list(OldApeTag#apetag.filename) ->
    {ok, File} = file:open(OldApeTag#apetag.filename, Mode),
    ApeTag = Fun(OldApeTag#apetag{file=File}),
    ok = file:close(ApeTag#apetag.file),
    ApeTag#apetag{file=nil}.

add_apeitem(Key, Values, Fields) ->
    add_apeitem(Key, Values, 0, Fields).

add_apeitem(Key, Values, Flags, Fields) when is_list(Key), is_list(Values), is_number(Flags), is_tuple(Fields) ->
    ApeItem = new_apeitem(Key, Values, Flags),
    dict:store(ApeItem#apeitem.lowercase_key, ApeItem, Fields).

add_apeitems(Items, Fields) when is_list(Items), is_tuple(Fields) ->
    lists:foldl(fun(Item, F) ->
        case Item of
            {Key, Values} -> add_apeitem(Key, Values, F);
            {Key, Values, Flags} -> add_apeitem(Key, Values, Flags, F)
        end
    end, Fields, Items).

genre_id(Genre) when is_list(Genre) ->
    genre_id_r(Genre, ?GENRES, 0).

genre_id_r(Genre, [], Num) when is_list(Genre), is_integer(Num) ->
    255;
genre_id_r(Genre, Genres, Num) when is_list(Genre), is_list(Genres), is_integer(Num) ->
    if Genre == hd(Genres) ->
        Num;
    ?ELSE ->
        genre_id_r(Genre, tl(Genres), Num+1)
    end.

get_ape_information(ApeTag) when is_record(ApeTag, apetag) ->
    ID3Len = size(ApeTag#apetag.id3),
    FileSize = ApeTag#apetag.file_size,
    if  FileSize >= ID3Len + 64 ->
        {ok, _Pos} = file:position(ApeTag#apetag.file, {eof, -32-ID3Len}),
        {ok, Footer} = file:read(ApeTag#apetag.file, 32),
        <<FooterPreamble:12/binary, FooterSize:4/little-unit:8, FooterItemCount:4/little-unit:8, FooterFlags:4/binary, _/binary>> = Footer,
        if ?APE_PREAMBLE == FooterPreamble, ?APE_FOOTER_FLAGS == FooterFlags ->
            if FooterSize < 32 -> erlang:error("Tag size smaller than minimum size");
               FooterSize + ID3Len + 32 > FileSize -> erlang:error("Tag size larger than possible");
               FooterSize + 32 > ?APE_MAX_SIZE -> erlang:error("Tag size larger than APE_MAX_SIZE");
               FooterItemCount > ?APE_MAX_ITEM_COUNT -> erlang:error("Tag item count larger than APE_MAX_ITEM_COUNT");
               FooterItemCount > (FooterSize - 32)/?APE_ITEM_MIN_SIZE -> erlang:error("Tag item count larger than possible");
            ?ELSE -> nil
            end,
            {ok, _} = file:position(ApeTag#apetag.file, {eof, -32-FooterSize-ID3Len}),
            {ok, Header} = file:read(ApeTag#apetag.file, 32),
            <<HeaderPreamble:12/binary, HeaderSize:4/little-unit:8, HeaderItemCount:4/little-unit:8, HeaderFlags:4/binary, _/binary>> = Header,
            {ok, Data} = file:read(ApeTag#apetag.file, FooterSize - 32),
            if not (?APE_PREAMBLE == HeaderPreamble) -> erlang:error("Missing header preamble");
               not (?APE_HEADER_FLAGS == HeaderFlags) -> erlang:error("Missing header flags");
               not (FooterSize == HeaderSize) -> erlang:error("Header and footer size do not match");
               not (FooterItemCount == HeaderItemCount) -> erlang:error("Header and footer item count do not match");
            ?ELSE -> nil
            end,
            ApeTag#apetag{tag_footer = Footer, tag_size = FooterSize + 32, tag_item_count = FooterItemCount, tag_start = FileSize-32-FooterSize-ID3Len, tag_header = Header, tag_data = Data, has_tag = true};
        ?ELSE ->
            ApeTag#apetag{tag_start = FileSize - ID3Len, has_tag = false, tag_header = <<>>, tag_footer = <<>>, tag_data = <<>>, tag_size = 0, tag_item_count = 0}
        end;
    ?ELSE ->
        ApeTag#apetag{tag_start = FileSize - ID3Len, has_tag = false, tag_header = <<>>, tag_footer = <<>>, tag_data = <<>>, tag_size = 0, tag_item_count = 0}
    end.

get_fields(ApeTag) when is_list(ApeTag) ->
    get_fields(new(ApeTag));
get_fields(ApeTag) when is_record(ApeTag, apetag), is_tuple(ApeTag#apetag.fields) ->
    ApeTag;
get_fields(ApeTag) when is_record(ApeTag, apetag), ApeTag#apetag.tag_data == nil ->
    get_fields(get_tag_information(ApeTag));
get_fields(ApeTag) when is_record(ApeTag, apetag), ApeTag#apetag.fields == nil ->
    ApeTag#apetag{fields = get_fields_r(dict:new(), ApeTag#apetag.tag_item_count, binary_to_list(ApeTag#apetag.tag_data), size(ApeTag#apetag.tag_data))}.

get_fields_r(Fields, 0, [], 0) ->
    Fields;
get_fields_r(_Fields, 0, _Data, _DataLen) ->
    erlang:error("Data remaining after specified number of items parsed");
get_fields_r(_Fields, _ItemsRemaining, [], 0) ->
    erlang:error("End of tag reached but more items specified");
get_fields_r(_Fields, ItemsRemaining, _Data, DataLen) when DataLen < ItemsRemaining * ?APE_ITEM_MIN_SIZE ->
    erlang:error("Not enough data for fill remaining tag items");
get_fields_r(Fields, ItemsRemaining, Data, DataLen) ->
    {Item, NewData, NewLen} = parse_apeitem(Data, DataLen),
    HasKey = dict:is_key(Item#apeitem.lowercase_key, Fields),
    if HasKey ->
        erlang:error("Multiple items with the same key");
    ?ELSE ->
        get_fields_r(dict:store(Item#apeitem.lowercase_key, Item, Fields), ItemsRemaining - 1, NewData, NewLen)
    end.

get_file_size(ApeTag) when is_record(ApeTag, apetag), ApeTag#apetag.file == nil ->
    get_file_size(get_tag_information(ApeTag));
get_file_size(ApeTag) when is_record(ApeTag, apetag) ->
    {ok, Pos} = file:position(ApeTag#apetag.file, eof),
    ApeTag#apetag{file_size = Pos}.

get_id3_information(ApeTag) when is_record(ApeTag, apetag) ->
    Filesize = ApeTag#apetag.file_size,
    if Filesize >= 128, ApeTag#apetag.check_id3 == true ->
        {ok, _Pos} = file:position(ApeTag#apetag.file, {eof, -128}),
        {ok, Data} = file:read(ApeTag#apetag.file, 128),
        case Data of
            <<"TAG",_Rest/binary>> ->
                ApeTag#apetag{id3 = Data};
            <<_Rest/binary>> ->
                ApeTag#apetag{id3 = <<>>}
        end;
    ?ELSE ->
        ApeTag#apetag{id3 = <<>>}
    end.

get_tag_information(ApeTag) when is_list(ApeTag) ->
    get_tag_information(new(ApeTag));
get_tag_information(ApeTag) when is_record(ApeTag, apetag), is_binary(ApeTag#apetag.tag_data) ->
    ApeTag;
get_tag_information(ApeTag) when is_record(ApeTag, apetag), ApeTag#apetag.tag_data == nil ->
    access_file(ApeTag, [read, binary], fun(AT) -> get_ape_information(get_id3_information(get_file_size(AT))) end).

id3_value(Key, Dict, Num) when is_list(Key), is_tuple(Dict), is_integer(Num) ->
    case dict:find(Key, Dict) of
        {ok, Value} ->
            ValueLen = length(Value),
            if ValueLen >= Num ->
                string:substr(Value, 1, Num);
            ?ELSE ->
                Value ++ string:copies("\0", Num - ValueLen)
            end;
        error ->
            string:copies("\0", Num)
    end.

new(Filename) when is_list(Filename) ->
    #apetag{filename=Filename}.

new(Filename, CheckID3) when is_list(Filename), is_boolean(CheckID3) ->
    #apetag{filename=Filename, check_id3=CheckID3}.

new_apeitem(Key, Values, Flags) when is_list(Key), is_list(Values), is_integer(Flags) ->
    case lists:splitwith(fun(X) -> is_integer(X) end, Values) of
        {[], []} -> Vals = [];
        {String, []} -> Vals = [String];
        {[], Values} -> Vals = Values;
        {String, Lists} -> Vals = [String|Lists]
    end,
    #apeitem{key=Key, values=Vals, flags=Flags, lowercase_key=string:to_lower(Key)}.

parse_apeitem(Data, DataLen) when is_list(Data), is_integer(DataLen) ->
    {LenFlags, KeyValue} = lists:split(8, Data),
    <<ValueLen:4/little-unit:8, Flags:4/unit:8>> = list_to_binary(LenFlags),
    if ValueLen + ?APE_ITEM_MIN_SIZE > DataLen ->
        erlang:error("Invalid item length before taking key length into account");
    Flags > 7 ->
        erlang:error("Invalid item flags");
    ?ELSE ->
        nil
    end,
    KeyLen = string:chr(KeyValue, 0) - 1,
    RestLen = DataLen - (KeyLen + ValueLen + 9),
    if KeyLen == -1 ->
        erlang:error("Missing key-value separator");
    RestLen < 0 ->
        erlang:error("Invalid item length after taking key length into account");
    ?ELSE ->
        nil
    end,
    {Key, Val} = lists:split(KeyLen, KeyValue),
    {Value, Rest} = lists:split(ValueLen, tl(Val)),
    Values = string:tokens(Value, "\0"),
    RestLen = length(Rest),
    Item = new_apeitem(Key, Values, Flags),
    validate_apeitem(Item),
    {Item, Rest, RestLen}.

pretty_print(ApeTag) when is_list(ApeTag) ->
    pretty_print(new(ApeTag));
pretty_print(ApeTag) when is_record(ApeTag, apetag), is_tuple(ApeTag#apetag.fields) ->
    string_join(lists:sort(dict:to_list(ApeTag#apetag.fields)), io_lib:nl(), fun({_Key, ApeItem}) ->
        [ApeItem#apeitem.key, ": ", string_join(ApeItem#apeitem.values, ", ")]
    end);
pretty_print(ApeTag) when is_record(ApeTag, apetag), ApeTag#apetag.fields == nil ->
    pretty_print(get_fields(ApeTag)).

raw(ApeTag) when is_list(ApeTag) ->
    raw(new(ApeTag));
raw(ApeTag) when is_record(ApeTag, apetag), is_binary(ApeTag#apetag.tag_data) ->
    list_to_binary([ApeTag#apetag.tag_header, ApeTag#apetag.tag_data, ApeTag#apetag.tag_footer, ApeTag#apetag.id3]);
raw(ApeTag) when is_record(ApeTag, apetag) ->
    raw(get_tag_information(ApeTag)).

raw_apeitem(ApeItem) when is_record(ApeItem, apeitem) ->
    RawValue = string_join(ApeItem#apeitem.values, 0),
    ValueLen = length(RawValue),
    Flags = ApeItem#apeitem.flags,
    list_to_binary([<<ValueLen:4/little-unit:8,Flags:4/unit:8>>, ApeItem#apeitem.key, 0, RawValue]).

remove(ApeTag) when is_list(ApeTag) ->
    remove(new(ApeTag));
remove(ApeTag) when is_record(ApeTag, apetag), is_integer(ApeTag#apetag.tag_start) ->
    access_file(ApeTag, [read, write, binary], fun(AT) ->
        {ok, Pos} = file:position(AT#apetag.file, AT#apetag.tag_start),
        ok = file:truncate(AT#apetag.file),
        AT#apetag{has_tag = false,  file_size = Pos, tag_start = Pos, tag_size = 0, tag_item_count = 0, tag_header = <<>>, tag_data = <<>>, tag_footer = <<>>, id3 = <<>>, fields = dict:new()}
    end);
remove(ApeTag) when is_record(ApeTag, apetag), ApeTag#apetag.tag_start == nil ->
    remove(get_tag_information(ApeTag)).

remove_apeitem(Key, Fields) when is_list(Key), is_tuple(Fields) ->
    dict:erase(string:to_lower(Key), Fields).

remove_apeitems(Keys, Fields) when is_list(Keys), is_tuple(Fields) ->
    lists:foldl(fun(Key, F) -> remove_apeitem(Key, F) end, Fields, Keys).

string_join([], _) ->
    "";
string_join(Strings, Join) when is_list(Strings), is_list(Join) ->
    lists:nthtail(length(Join), lists:flatten(lists:foldl(fun(String, Acc) ->
        [Acc,Join,String]
    end, "", Strings)));
string_join(Strings, Join) when is_list(Strings), is_integer(Join), Join >= 0, Join < 256 ->
    tl(lists:flatten(lists:foldl(fun(String, Acc) ->
        [Acc,Join,String]
    end, "", Strings))).
    
string_join([], _, _) ->
    "";
string_join(Values, Join, Fun) when is_list(Values), is_list(Join), is_function(Fun) ->
    tl(lists:flatten(lists:foldl(fun(Value, Acc) ->
        [Acc,Join,Fun(Value)]
    end, "", Values))).

update(ApeTag, Fun) when is_list(ApeTag) ->
    update(new(ApeTag), Fun);
update(ApeTag, Fun) when is_record(ApeTag, apetag), is_function(Fun), is_tuple(ApeTag#apetag.fields) ->
    Fields = Fun(ApeTag#apetag.fields),
    access_file(ApeTag, [read, write, binary], fun(AT) ->
        validate_apeitems(Fields),
        write_tag(update_ape(update_id3(AT#apetag{fields = Fields})))
    end);
update(ApeTag, Fun) when is_record(ApeTag, apetag), is_function(Fun), ApeTag#apetag.fields == nil ->
    update(get_fields(ApeTag), Fun).

update_ape(ApeTag) when is_record(ApeTag, apetag) ->
    Items = lists:sort(fun(A,B) ->
        SizeA = size(A),
        SizeB = size(B),
        if SizeA == SizeB ->
            A < B;
        ?ELSE ->
            SizeA < SizeB
        end
    end, dict:fold(fun(_Key, ApeItem, Items) ->
            [raw_apeitem(ApeItem)|Items]
        end, [], ApeTag#apetag.fields)
    ),
    ItemCount = length(Items),
    TagData = list_to_binary(Items),
    TagSize = size(TagData) + 64,
    if ItemCount > ?APE_MAX_ITEM_COUNT ->
        erlang:error("Updated tag has too many items");
    TagSize > ?APE_MAX_SIZE ->
        erlang:error("Updated tag too large");
    ?ELSE ->
        nil
    end,
    Base = list_to_binary([?APE_PREAMBLE, <<(TagSize-32):4/little-unit:8,ItemCount:4/little-unit:8>>]),
    ApeTag#apetag{tag_item_count=ItemCount, tag_data=TagData, tag_size=TagSize, tag_header=(list_to_binary([Base, ?APE_HEADER_FLAGS, "\0\0\0\0\0\0\0\0"])), tag_footer=(list_to_binary([Base, ?APE_FOOTER_FLAGS, "\0\0\0\0\0\0\0\0"]))}.

update_id3(ApeTag) when is_record(ApeTag, apetag) ->
    if not ApeTag#apetag.check_id3 ->
        ApeTag#apetag{id3 = <<>>};
    ApeTag#apetag.id3 == <<>>, ApeTag#apetag.has_tag ->
        ApeTag;
    ?ELSE ->
        ID3 = dict:fold(fun(Key, ApeItem, Dict) ->
            Value = string_join(ApeItem#apeitem.values, ", "),
            if (Key == "title") or (Key == "artist") or (Key == "album") or (Key == "year") or (Key == "comment") ->
                dict:store(Key, Value, Dict);
            Key == "date" ->
                case regexp:match(Value, ?APE_YEAR_RE) of
                    {match, Start, 4} ->
                        dict:store("year", string:substr(Value, Start, 4), Dict);
                    nomatch ->
                        Dict;
                    {error, _} ->
                        erlang:error("Bad APE_YEAR_RE")
                end;
            ?ELSE ->
                case string:substr(Key, 1, 5) of
                    "track"->
                        case string:to_integer(Value) of
                            {error, _} ->
                                Dict;
                            {Track, _} ->
                                if Track >= 0, Track < 256 ->
                                    dict:store("track", [Track], Dict);
                                ?ELSE ->
                                    Dict
                                end
                        end;
                    "genre" ->
                        dict:store("genre", [genre_id(hd(ApeItem#apeitem.values))], Dict);
                    _ ->
                        Dict
                end
            end
        end, dict:store("genre", [255], dict:new()), ApeTag#apetag.fields),
        ApeTag#apetag{id3=list_to_binary("TAG" ++ id3_value("title", ID3, 30) ++ id3_value("artist", ID3, 30) ++ id3_value("album", ID3, 30) ++ id3_value("year", ID3, 4) ++ id3_value("comment", ID3, 28) ++ "\0" ++ id3_value("track", ID3, 1) ++ id3_value("genre", ID3, 1))}
    end.

validate_apeitem(ApeItem) when not is_record(ApeItem, apeitem) ->
    erlang:error("Not an ApeItem");
validate_apeitem(ApeItem) when not is_list(ApeItem#apeitem.key) ->
    erlang:error("Invalid ApeItem key type");
validate_apeitem(ApeItem) when length(ApeItem#apeitem.key) < 2 ->
    erlang:error("Invalid ApeItem key length (too short)");
validate_apeitem(ApeItem) when length(ApeItem#apeitem.key) > 255 ->
    erlang:error("Invalid ApeItem key length (too long)");
validate_apeitem(ApeItem) when not is_integer(ApeItem#apeitem.flags) ->
    erlang:error("Invalid ApeItem flags type");
validate_apeitem(ApeItem) when ApeItem#apeitem.flags < 0 ->
    erlang:error("Invalid ApeItem flags (< 0)");
validate_apeitem(ApeItem) when ApeItem#apeitem.flags > 7 ->
    erlang:error("Invalid ApeItem flags (> 7)");
validate_apeitem(ApeItem) when not is_list(ApeItem#apeitem.values) ->
    erlang:error("Invalid ApeItem values type");
validate_apeitem(ApeItem) when not is_list(ApeItem#apeitem.lowercase_key) ->
    erlang:error("Invalid ApeItem lowercase_key type");
validate_apeitem(ApeItem) when (ApeItem#apeitem.lowercase_key == "id3") or (ApeItem#apeitem.lowercase_key == "tag") or (ApeItem#apeitem.lowercase_key == "oggs") or (ApeItem#apeitem.lowercase_key == "mp+") ->
    erlang:error("Invalid ApeItem lowercase_key value");
validate_apeitem(ApeItem) ->
    lists:foreach(fun(Char) ->
        if (not is_integer(Char)) or (Char < 32) or (Char >= 128) ->
            erlang:error("Invalid ApeItem key character");
        ?ELSE ->
            nil
        end 
    end, ApeItem#apeitem.key),
    LCKey = string:to_lower(ApeItem#apeitem.key),
    if ApeItem#apeitem.lowercase_key /= LCKey ->
        erlang:error("Lowercase key doesn't match key");
    ?ELSE ->
        nil
    end,
    lists:foreach(fun(String) ->
        if not is_list(String) ->
            erlang:error("Invalid ApeItem value type");
        ?ELSE ->
            lists:foreach(fun(Char) ->
                if (not is_integer(Char)) ->
                    erlang:error("Invalid ApeItem value character type");
                ?ELSE ->
                    nil
                end 
            end, String)
        end,
        if (ApeItem#apeitem.flags == 0) or (ApeItem#apeitem.flags == 1) or (ApeItem#apeitem.flags == 4) or (ApeItem#apeitem.flags == 5) ->
            ValidUTF8 = valid_utf8(String),
            if ValidUTF8 ->
                nil;
            ?ELSE ->
                erlang:error("Invalid ApeItem value, not UTF8")
            end;
        ?ELSE ->
            nil
        end
    end, ApeItem#apeitem.values).

validate_apeitems(Fields) when is_tuple(Fields) ->
    dict:fold(fun(Key, Value, nil) ->
        validate_apeitem(Value),
        if Key /= Value#apeitem.lowercase_key ->
            erlang:error("Dictionary key doesn't match ApeItem lowercase key");
        ?ELSE ->
            nil
        end
    end, nil, Fields).

valid_utf8("") ->
    true;
valid_utf8(String) when is_list(String) ->
    Char = hd(String),
    if (not is_integer(Char)) or (Char < 0) or (Char > 255) ->
        false;
    Char >= 0, Char < 128 ->
        valid_utf8(tl(String));
    (Char < 194) or (Char > 245) ->
        false;
    Char >= 194, Char < 244 ->
        valid_utf8(tl(String), 1);
    Char >= 224, Char < 240 ->
        valid_utf8(tl(String), 2);
    Char >= 240, Char < 245 ->
        valid_utf8(tl(String), 3);
    ?ELSE ->
        false
    end.
    
valid_utf8(String, 0) when is_list(String) ->
    valid_utf8(String);
valid_utf8(String, Num) when is_list(String), is_integer(Num) ->
    Char = hd(String),
    if not is_integer(Char) ->
        false;
    (Char < 128) or (Char >= 192) ->
        false;
    ?ELSE ->
        valid_utf8(tl(String), Num - 1)
    end.

write_tag(ApeTag) when is_record(ApeTag, apetag) ->
    {ok, Pos} = file:position(ApeTag#apetag.file, ApeTag#apetag.tag_start),
    Raw = raw(ApeTag),
    ok = file:write(ApeTag#apetag.file, Raw),
    ok = file:truncate(ApeTag#apetag.file),
    ApeTag#apetag{has_tag=true, file_size = Pos + size(Raw)}.
