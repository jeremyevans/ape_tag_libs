#include <apetag.c>
#include <err.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int assertions = 0;

#define CHECK(RESULT) assertions++; if (!(RESULT)) { return __LINE__; }
#define EQUAL(MSG, EXPECT, ACTUAL) assertions++; if ((EXPECT) != (ACTUAL)) { printf("%s: expected: %i, received %i\n", (MSG), (EXPECT), (ACTUAL)); return __LINE__; }

int run_tests(void);
int test_ApeTag_corrupt(void);
int test_ApeTag_exists(void);
int test_ApeTag_exists_id3(void);
int test_ApeTag_parse(void);
int test_ApeTag_remove(void);
int test_ApeTag_update(void);

#ifndef TEST_TAGS_DIR
#  define TEST_TAGS_DIR "../test-files"
#endif

int main(void) {
    int num_failures = 0;

    CHECK(ApeTag_mt_init() == 0);

    if (chdir(TEST_TAGS_DIR) != 0) {
        err(1, NULL);
    }
    num_failures = run_tests();
    
    if (num_failures == 0) {
        printf("\nAll Tests Successful (%i assertions).\n", assertions);
        system("rm test.tag");
    } else {
        printf("\n%i Failed Tests (%i assertions).\n", num_failures, assertions);
        return 1;
    }
    return 0;
}

int run_tests(void) {
    int failures = 0;
    int line = 0;
    
    #define CHECK_FAILURE(FUNCTION) \
        if ((line = FUNCTION())) { \
            failures ++; \
            printf(#FUNCTION " failed on line %i\n", line) ; \
        }
            
    CHECK_FAILURE(test_ApeTag_corrupt);
    CHECK_FAILURE(test_ApeTag_exists);
    CHECK_FAILURE(test_ApeTag_exists_id3);
    CHECK_FAILURE(test_ApeTag_parse);
    CHECK_FAILURE(test_ApeTag_remove);
    CHECK_FAILURE(test_ApeTag_update);

    return failures;
}

int test_ApeTag_corrupt(void) {
    struct ApeTag *tag;
    FILE *file;
    
    #define TEST_CORRUPT(FILENAME, MSG) \
        CHECK(file = fopen(FILENAME, "r+")); \
        CHECK(tag = ApeTag_new(file, 0)); \
        CHECK(ApeTag_parse(tag) == -1); \
        if(strcmp(ApeTag_error(tag), MSG) != 0){printf("Received: %s\nExpected: %s\n", ApeTag_error(tag), MSG);} \
        CHECK(strcmp(ApeTag_error(tag), MSG) == 0);
     
    TEST_CORRUPT("corrupt-count-larger-than-possible.tag", "tag item count larger than possible")
    TEST_CORRUPT("corrupt-count-mismatch.tag", "header and footer item count does not match")
    TEST_CORRUPT("corrupt-count-over-max-allowed.tag", "tag item count larger than allowed")
    TEST_CORRUPT("corrupt-data-remaining.tag", "data remaining after specified number of items parsed")
    TEST_CORRUPT("corrupt-duplicate-item-key.tag", "duplicate item in tag")
    TEST_CORRUPT("corrupt-finished-without-parsing-all-items.tag", "end of tag reached but more items specified")
    TEST_CORRUPT("corrupt-footer-flags.tag", "bad tag footer flags")
    TEST_CORRUPT("corrupt-header.tag", "missing APE header")
    TEST_CORRUPT("corrupt-item-flags-invalid.tag", "invalid item flags")
    TEST_CORRUPT("corrupt-item-length-invalid.tag", "impossible item length (greater than remaining space)")
    TEST_CORRUPT("corrupt-key-invalid.tag", "invalid item key character")
    TEST_CORRUPT("corrupt-key-too-short.tag", "invalid item key (too short)")
    TEST_CORRUPT("corrupt-key-too-long.tag", "invalid item key (too long)")
    TEST_CORRUPT("corrupt-min-size.tag", "tag smaller than minimum possible size")
    TEST_CORRUPT("corrupt-missing-key-value-separator.tag", "invalid item length (longer than remaining data)")
    TEST_CORRUPT("corrupt-next-start-too-large.tag", "invalid item length (longer than remaining data)")
    TEST_CORRUPT("corrupt-size-larger-than-possible.tag", "tag larger than possible size")
    TEST_CORRUPT("corrupt-size-mismatch.tag", "header and footer size does not match")
    TEST_CORRUPT("corrupt-size-over-max-allowed.tag", "tag larger than maximum allowed size")
    TEST_CORRUPT("corrupt-value-not-utf8.tag", "invalid utf8 value")
    
    #undef TEST_CORRUPT
    
    return 0;
}


int test_ApeTag_exists(void) {
    struct ApeTag *tag;
    FILE *file;
    
    #define TEST_EXIST(FILENAME, EXIST) \
        CHECK(file = fopen(FILENAME, "r+")); \
        CHECK(tag = ApeTag_new(file, 0)); \
        CHECK(ApeTag_exists(tag) == EXIST);
    
    TEST_EXIST("missing-ok.tag", 0);
    TEST_EXIST("good-empty.tag", 1);
    TEST_EXIST("good-empty-id3-only.tag", 0);
    TEST_EXIST("good-empty-id3.tag", 1);
    
    #undef TEST_EXIST
    
    return 0;
}

int test_ApeTag_exists_id3(void) {
    struct ApeTag *tag;
    FILE *file;
    
    #define TEST_EXIST(FILENAME, EXIST) \
        CHECK(file = fopen(FILENAME, "r+")); \
        CHECK(tag = ApeTag_new(file, 0)); \
        CHECK(ApeTag_exists_id3(tag) == EXIST);
    
    TEST_EXIST("missing-ok.tag", 0);
    TEST_EXIST("good-empty.tag", 0);
    TEST_EXIST("good-empty-id3-only.tag", 1);
    TEST_EXIST("good-empty-id3.tag", 1);
    
    #undef TEST_EXIST

    return 0;
}

int test_ApeTag_parse(void) {
    struct ApeTag *tag;
    struct ApeItem *item;
    FILE *file;
    
    #define TEST_PARSE(FILENAME, ITEMS) \
        CHECK(file = fopen(FILENAME, "r+")); \
        CHECK(tag = ApeTag_new(file, 0)); \
        CHECK(ApeTag_parse(tag) == 0 && ITEMS == ApeTag_file_item_count(tag));
    
    #define HAS_FIELD(FIELD, VALUE, SIZE, FLAGS) \
        CHECK((item = ApeTag_get_item(tag, FIELD)) != NULL); \
        CHECK(item->size == SIZE); \
        CHECK(item->flags == FLAGS); \
        CHECK(memcmp(VALUE, item->value, SIZE) == 0); \
    
    TEST_PARSE("good-empty.tag", 0);

    TEST_PARSE("good-simple-1.tag", 1);
    HAS_FIELD("name", "value", 5, 0);
    HAS_FIELD("Name", "value", 5, 0);
    
    TEST_PARSE("good-many-items.tag", 63);
    HAS_FIELD("0n", "", 0, 0);
    HAS_FIELD("1n", "a", 1, 0);
    HAS_FIELD("62n", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", 62, 0);
    
    TEST_PARSE("good-multiple-values.tag", 1);
    HAS_FIELD("name", "va\0ue", 5, 0);
    
    TEST_PARSE("good-simple-1-ro-external.tag", 1);
    HAS_FIELD("name", "value", 5, 5);
    
    TEST_PARSE("good-binary-non-utf8-value.tag", 1);
    HAS_FIELD("name", "v\x81lue", 5, 2);
    
    #undef HAS_FIELD
    #undef TEST_PARSE
    
    return 0;
}

int test_ApeTag_remove(void) {
    struct ApeTag *tag;
    FILE *file;
    
    #define TEST_REMOVE(FROM, TO, EXISTS) \
        system("cp " FROM " test.tag"); \
        CHECK(file = fopen("test.tag", "r+")); \
        CHECK(tag = ApeTag_new(file, 0)); \
        EQUAL("remove", EXISTS, ApeTag_remove(tag)); \
        EQUAL("cmp", 0, system("cmp -s " TO " test.tag")); \
    
    TEST_REMOVE("missing-ok.tag", "missing-ok.tag", 1);
    TEST_REMOVE("good-empty.tag", "missing-ok.tag", 0);
    TEST_REMOVE("good-empty-id3.tag", "missing-ok.tag", 0);
    TEST_REMOVE("good-empty-id3-only.tag", "missing-ok.tag", 0);
    TEST_REMOVE("missing-10k.tag", "missing-10k.tag", 1);
    
    #undef TEST_REMOVE
    
    return 0;
}

int test_ApeTag_update(void) {
    struct ApeTag *tag;
    struct ApeItem *item;
    FILE *file;
    int i;
    char key[4];
    char value[] = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    char *v;
    
    #define SETUP(FROM, FLAGS) \
        system("cp " FROM " test.tag"); \
        CHECK(file = fopen("test.tag", "r+")); \
        CHECK(tag = ApeTag_new(file, FLAGS));

    #define ADD_ITEM(KEY, VALUE, SIZE, FLAGS) \
        item = malloc(sizeof(struct ApeItem)); \
        item->size = SIZE; \
        item->flags = FLAGS; \
        item->key = malloc(strlen(KEY)+1); \
        item->value = malloc(SIZE); \
        memcpy(item->key, KEY, strlen(KEY)+1); \
        memcpy(item->value, VALUE, SIZE); \
        EQUAL("add_item", 0, ApeTag_add_item(tag, item));
        
    #define UPDATE_ERROR(MSG) \
        EQUAL("update", -1, ApeTag_update(tag)); \
        if(strcmp(ApeTag_error(tag), MSG) != 0){printf("Received: %s\nExpected: %s\n", ApeTag_error(tag), MSG);} \
        CHECK(strcmp(ApeTag_error(tag), MSG) == 0);
    
    #define ADD_ITEM_ERROR(KEY, VALUE, SIZE, FLAGS, MSG) \
        item = malloc(sizeof(struct ApeItem)); \
        item->size = SIZE; \
        item->flags = FLAGS; \
        item->key = malloc(strlen(KEY)+1); \
        item->value = malloc(SIZE); \
        memcpy(item->key, KEY, strlen(KEY)+1); \
        memcpy(item->value, VALUE, SIZE); \
        i = ApeTag_add_item(tag, item); \
        EQUAL("add_item", -1, i); \
        if(strcmp(ApeTag_error(tag), MSG) != 0){printf("Received: %s\nExpected: %s\n", ApeTag_error(tag), MSG);} \
        CHECK(strcmp(ApeTag_error(tag), MSG) == 0);
        
    #define TEST_UPDATE(TO) \
        EQUAL("update", 0, ApeTag_update(tag)); \
        EQUAL("cmp", 0, system("cmp -s " TO " test.tag"));
    
    SETUP("good-empty.tag", 0);
    TEST_UPDATE("good-empty.tag");
    
    SETUP("missing-ok.tag", APE_NO_ID3);
    TEST_UPDATE("good-empty.tag");
    
    SETUP("good-empty.tag", 0);
    ADD_ITEM("name", "value", 5, 0);
    TEST_UPDATE("good-simple-1.tag");
    
    SETUP("good-simple-1.tag", 0);
    ApeTag_remove_item(tag, "name");
    TEST_UPDATE("good-empty.tag");

    SETUP("good-simple-1.tag", 0);
    ApeTag_remove_item(tag, "Name");
    TEST_UPDATE("good-empty.tag");

    SETUP("good-empty.tag", 0);
    ADD_ITEM("name", "value", 5, 5);
    TEST_UPDATE("good-simple-1-ro-external.tag");
    
    SETUP("good-empty.tag", 0);
    ADD_ITEM("name", "v\x81lue", 5, 2);
    TEST_UPDATE("good-binary-non-utf8-value.tag");
    
    SETUP("good-empty.tag", 0);
    for(i=0; i < 63; i++) {
      snprintf(key, 4, "%in", i);
      ADD_ITEM(key, value, i, 0);
    }
    TEST_UPDATE("good-many-items.tag");
    
    SETUP("good-empty.tag", 0);
    ADD_ITEM("name", "va\0ue", 5, 0);
    TEST_UPDATE("good-multiple-values.tag");
    
    SETUP("good-multiple-values.tag", 0);
    ADD_ITEM("NAME", "value", 5, 0);
    TEST_UPDATE("good-simple-1-uc.tag");

    SETUP("missing-ok.tag", APE_NO_ID3);
    ADD_ITEM("name", "v\xc3\x82\xc3\x95", 5, 0);
    TEST_UPDATE("good-simple-1-utf8.tag");

    SETUP("missing-ok.tag", APE_NO_ID3);
    for(i=0; i < 64; i++) {
      snprintf(key, 4, "%in", i);
      ADD_ITEM(key, value, i, 0);
    }
    ADD_ITEM_ERROR("name", "value", 5, 0, "maximum item count exceeded");
    
    SETUP("missing-ok.tag", APE_NO_ID3);
    v = malloc(8118);
    ADD_ITEM("xn", v, 8118, 0);
    UPDATE_ERROR("tag larger than maximum possible size");
    
    SETUP("missing-ok.tag", APE_NO_ID3);
    ADD_ITEM_ERROR("n", "a", 1, 0, "invalid item key (too short)");
    ADD_ITEM_ERROR("nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", "a", 1, 0, "invalid item key (too long)");
    ADD_ITEM_ERROR("n\1", "a", 1, 0, "invalid item key character");
    ADD_ITEM_ERROR("n\x1f", "a", 1, 0, "invalid item key character");
    ADD_ITEM_ERROR("n\x80", "a", 1, 0, "invalid item key character");
    ADD_ITEM_ERROR("n\xff", "a", 1, 0, "invalid item key character");
    ADD_ITEM_ERROR("tag", "a", 1, 0, "invalid item key (id3|tag|mp+|oggs)");
    ADD_ITEM_ERROR("name", "n\xff", 2, 0, "invalid utf8 value");
    ADD_ITEM_ERROR("name", "a", 1, 8, "invalid item flags");

    SETUP("missing-ok.tag", 0);
    TEST_UPDATE("good-empty-id3.tag");
    
    SETUP("good-empty-id3-only.tag", 0);
    TEST_UPDATE("good-empty-id3.tag");
    
    SETUP("good-empty-id3.tag", 0);
    ADD_ITEM("track", "1", 1, 0);
    ADD_ITEM("genre", "Game", 4, 0);
    ADD_ITEM("year", "1999", 4, 0);
    ADD_ITEM("title", "Test Title", 10, 0);
    ADD_ITEM("artist", "Test Artist", 11, 0);
    ADD_ITEM("album", "Test Album", 10, 0);
    ADD_ITEM("comment", "Test Comment", 12, 0);
    TEST_UPDATE("good-simple-4.tag");

    SETUP("good-empty-id3.tag", 0);
    ADD_ITEM("Track", "1", 1, 0);
    ADD_ITEM("Genre", "Game", 4, 0);
    ADD_ITEM("Year", "1999", 4, 0);
    ADD_ITEM("Title", "Test Title", 10, 0);
    ADD_ITEM("Artist", "Test Artist", 11, 0);
    ADD_ITEM("Album", "Test Album", 10, 0);
    ADD_ITEM("Comment", "Test Comment", 12, 0);
    TEST_UPDATE("good-simple-4-uc.tag");

    SETUP("good-empty-id3.tag", 0);
    ADD_ITEM("track", "1", 1, 0);
    ADD_ITEM("genre", "Game", 4, 0);
    ADD_ITEM("date", "12/31/1999", 10, 0);
    ADD_ITEM("title", "Test Title", 10, 0);
    ADD_ITEM("artist", "Test Artist", 11, 0);
    ADD_ITEM("album", "Test Album", 10, 0);
    ADD_ITEM("comment", "Test Comment", 12, 0);
    TEST_UPDATE("good-simple-4-date.tag");

    SETUP("good-empty-id3.tag", 0);
    ADD_ITEM("track", "1", 1, 0);
    ADD_ITEM("genre", "Game", 4, 0);
    ADD_ITEM("year", "19991999", 8, 0);
    ADD_ITEM("title", "Test TitleTest TitleTest TitleTest TitleTest Title", 50, 0);
    ADD_ITEM("artist", "Test ArtistTest ArtistTest ArtistTest ArtistTest Artist", 55, 0);
    ADD_ITEM("album", "Test AlbumTest AlbumTest AlbumTest AlbumTest Album", 50, 0);
    ADD_ITEM("comment", "Test CommentTest CommentTest CommentTest CommentTest Comment", 60, 0);
    TEST_UPDATE("good-simple-4-long.tag");

    #undef SETUP
    #undef ADD_ITEM
    #undef UPDATE_ERROR
    #undef ADD_ITEM_ERROR
    #undef TEST_UPDATE
    
    return 0;
}

