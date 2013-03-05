-module(test_apetag_files).
-include_lib("apetag.hrl").
-export([start/0]).
-define(DIR, "../test-files/").
-define(ELSE, true).
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

tagname(T) ->
  ?DIR ++ T ++ ".tag".

tag(T) ->
  apetag:get_fields(tagname(T)).

fields(T) ->
  AT = tag(T),
  AT#apetag.fields.

field(T, Field) ->
  Item = dict:fetch(Field, fields(T)),
  {Item#apeitem.key, Item#apeitem.values, Item#apeitem.flags}.

has_tag(T) ->
  AT = tag(T),
  AT#apetag.has_tag.

has_id3(T) ->
  AT = tag(T),
  AT#apetag.id3 /= <<>>.

corrupt(T) ->
  assert_error(fun() -> tag(T) end).

cmp_file(Before, After, F) ->
  os:cmd("cp " ++ tagname(Before) ++ " " ++ tagname("test")),
  F(),
  "" = os:cmd("cmp " ++ tagname(After) ++ " " ++ tagname("test")),
  os:cmd("rm " ++ tagname("test")).

update(Before, After, F) ->
  cmp_file(Before, After, fun() -> apetag:update(apetag:new(tagname("test"), false), F) end).

update_id3(Before, After, F) ->
  cmp_file(Before, After, fun() -> apetag:update(apetag:new(tagname("test")), F) end).

update_error(F) ->
  os:cmd("cp " ++ tagname("missing-ok") ++ " " ++ tagname("test")),
  assert_error(fun () -> apetag:update(apetag:new(tagname("test"), false), F) end),
  os:cmd("rm " ++ tagname("test")).

tests() ->
[
% test corrupt
fun() ->
    corrupt("corrupt-count-larger-than-possible"),
    corrupt("corrupt-count-mismatch"),
    corrupt("corrupt-count-over-max-allowed"),
    corrupt("corrupt-data-remaining"),
    corrupt("corrupt-duplicate-item-key"),
    corrupt("corrupt-finished-without-parsing-all-items"),
    corrupt("corrupt-footer-flags"),
    corrupt("corrupt-header"),
    corrupt("corrupt-item-flags-invalid"),
    corrupt("corrupt-item-length-invalid"),
    corrupt("corrupt-key-invalid"),
    corrupt("corrupt-key-too-short"),
    corrupt("corrupt-key-too-long"),
    corrupt("corrupt-min-size"),
    corrupt("corrupt-missing-key-value-separator"),
    corrupt("corrupt-next-start-too-large"),
    corrupt("corrupt-size-larger-than-possible"),
    corrupt("corrupt-size-mismatch"),
    corrupt("corrupt-size-over-max-allowed"),
    corrupt("corrupt-value-not-utf8")
end,

% test exists
fun() ->
    false = has_tag("missing-ok"),
    true = has_tag("good-empty"),
    false = has_tag("good-empty-id3-only"),
    true = has_tag("good-empty-id3"),

    false = has_id3("missing-ok"),
    false = has_id3("good-empty"),
    true = has_id3("good-empty-id3-only"),
    true = has_id3("good-empty-id3")
end,

% test fields
fun() ->
    EMPTY_DICT = dict:new(),
    EMPTY_DICT = fields("missing-ok"),
    EMPTY_DICT = fields("good-empty"),

    ["name"] = dict:fetch_keys(fields("good-simple-1")),
    {"name", ["value"], 0} = field("good-simple-1", "name"),

    63 = dict:size(fields("good-many-items")),
    {"0n", [], 0} = field("good-many-items", "0n"),
    {"1n", ["a"], 0} = field("good-many-items", "1n"),
    {"62n", ["aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"], 0} = field("good-many-items", "62n"),

    ["name"] = dict:fetch_keys(fields("good-multiple-values")),
    {"name", ["va", "ue"], 0} = field("good-multiple-values", "name"),

    ["name"] = dict:fetch_keys(fields("good-simple-1-ro-external")),
    {"name", ["value"], 5} = field("good-simple-1-ro-external", "name"),

    ["name"] = dict:fetch_keys(fields("good-binary-non-utf8-value")),
    {"name", ["v\201lue"], 2} = field("good-binary-non-utf8-value", "name")
end,

% test remove
fun() ->
    cmp_file("missing-ok", "missing-ok", fun() -> apetag:remove(tagname("test")) end),
    cmp_file("good-empty", "missing-ok", fun() -> apetag:remove(tagname("test")) end),
    cmp_file("good-empty-id3", "missing-ok", fun() -> apetag:remove(tagname("test")) end),
    cmp_file("good-empty-id3-only", "missing-ok", fun() -> apetag:remove(tagname("test")) end),
    cmp_file("missing-10k", "missing-10k", fun() -> apetag:remove(tagname("test")) end)
end,

% test update
fun() ->
    update("missing-ok", "good-empty", fun(F) -> F end),
    update("good-empty", "good-empty", fun(F) -> F end),
    update("good-empty", "good-simple-1", fun(F) -> apetag:add_apeitem("name", "value", F) end),
    update("good-simple-1", "good-empty", fun(F) -> apetag:remove_apeitem("name", F) end),
    update("good-simple-1", "good-empty", fun(F) -> apetag:remove_apeitem("Name", F) end),
    update("good-empty", "good-simple-1-ro-external", fun(F) -> apetag:add_apeitem("name", "value", 5, F) end),
    update("good-empty", "good-binary-non-utf8-value", fun(F) -> apetag:add_apeitem("name", "v\201lue", 2, F) end),
    update("good-empty", "good-many-items", fun(F) -> apetag:add_apeitems(lists:map(fun(I) -> {integer_to_list(I) ++ "n", string:copies("a", I)} end, lists:seq(0,62)), F) end),
    update("missing-ok", "good-multiple-values", fun(F) -> apetag:add_apeitem("name", ["va", "ue"], F) end),
    update("good-multiple-values", "good-simple-1-uc", fun(F) -> apetag:add_apeitem("NAME", "value", F) end),
    update("missing-ok", "good-simple-1-utf8", fun(F) -> apetag:add_apeitem("name", "v\303\202\303\225", F) end),

    update_error(fun(F) -> apetag:add_apeitems(lists:map(fun(I) -> {integer_to_list(I) ++ "n", string:copies("a", I)} end, lists:seq(0,65)), F) end),
    update_error(fun(F) -> apetag:add_apeitem("xn", string:copies("a", 8118), F) end),
    update_error(fun(F) -> apetag:add_apeitem("n", "a", F) end),
    update_error(fun(F) -> apetag:add_apeitem(string:copies("n", 256), "a", F) end),
    update_error(fun(F) -> apetag:add_apeitem("n\000", "a", F) end),
    update_error(fun(F) -> apetag:add_apeitem("n\037", "a", F) end),
    update_error(fun(F) -> apetag:add_apeitem("x\200", "a", F) end),
    update_error(fun(F) -> apetag:add_apeitem("x\377", "a", F) end),
    update_error(fun(F) -> apetag:add_apeitem("tag", "a", F) end),
    update_error(fun(F) -> apetag:add_apeitem("ab" "a\377", F) end),
    update_error(fun(F) -> apetag:add_apeitem("name", "value", 8, F) end)
end,

% test update id3
fun() ->
    update_id3("missing-ok", "good-empty-id3", fun(F) -> F end),
    update_id3("good-empty-id3-only", "good-empty-id3", fun(F) -> F end),
    update_id3("good-empty-id3", "good-simple-4", fun(F) -> apetag:add_apeitems([{"track", "1"}, {"genre", "Game"}, {"year", "1999"}, {"title", "Test Title"}, {"artist", "Test Artist"}, {"album", "Test Album"}, {"comment", "Test Comment"}], F) end),
    update_id3("good-empty-id3", "good-simple-4-uc", fun(F) -> apetag:add_apeitems([{"Track", "1"}, {"Genre", "Game"}, {"Year", "1999"}, {"Title", "Test Title"}, {"Artist", "Test Artist"}, {"Album", "Test Album"}, {"Comment", "Test Comment"}], F) end),
    update_id3("good-empty-id3", "good-simple-4-date", fun(F) -> apetag:add_apeitems([{"track", "1"}, {"genre", "Game"}, {"date", "12/31/1999"}, {"title", "Test Title"}, {"artist", "Test Artist"}, {"album", "Test Album"}, {"comment", "Test Comment"}], F) end),
    update_id3("good-empty-id3", "good-simple-4-long", fun(F) -> apetag:add_apeitems([{"track", "1"}, {"genre", "Game"}, {"year", string:copies("1999", 2)}, {"title", string:copies("Test Title", 5)}, {"artist", string:copies("Test Artist", 5)}, {"album", string:copies("Test Album", 5)}, {"comment", string:copies("Test Comment", 5)}], F) end)
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
