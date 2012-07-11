#include <apetag.c>
#include <err.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int assertions = 0;

#define CHECK(RESULT) assertions++; if (!(RESULT)) { return __LINE__; }

int run_tests(void);
int test_ApeTag_new_free(void);
int test_ApeTag_exists(void);
int test_ApeTag_exists_id3(void);
int test_ApeTag_maximums(void);
int test_ApeTag_remove(void);
int test_ApeTag_raw(void);
int test_ApeTag_parse(void);
int test_ApeTag_update(void);
int test_ApeTag_add_remove_clear_items_update(void);
int test_ApeTag_filesizes(void);
int test_ApeItem_validity(void);
int test_bad_tags(void);
int test_no_id3(void);
int test_ApeTag__strcasecpy(void);
int test_ApeItem__parse_track(void);
int test_ApeItem__compare(void);
int test_ApeTag__lookup_genre(void);

#ifndef TEST_TAGS_DIR
#  define TEST_TAGS_DIR "test/tags"
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
    } else {
        printf("\n%i Failed Tests (%i assertions).\n", num_failures, assertions);
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
            
    CHECK_FAILURE(test_ApeTag_new_free);
    CHECK_FAILURE(test_ApeTag_exists);
    CHECK_FAILURE(test_ApeTag_exists_id3);
    CHECK_FAILURE(test_ApeTag_maximums);
    CHECK_FAILURE(test_ApeTag_remove);
    CHECK_FAILURE(test_ApeTag_raw);
    CHECK_FAILURE(test_ApeTag_parse);
    CHECK_FAILURE(test_ApeTag_update);
    CHECK_FAILURE(test_ApeTag_filesizes);
    CHECK_FAILURE(test_ApeItem_validity);
    CHECK_FAILURE(test_bad_tags);
    CHECK_FAILURE(test_ApeTag_add_remove_clear_items_update);
    CHECK_FAILURE(test_no_id3);
    CHECK_FAILURE(test_ApeTag__strcasecpy);
    CHECK_FAILURE(test_ApeItem__parse_track);
    CHECK_FAILURE(test_ApeItem__compare);
    CHECK_FAILURE(test_ApeTag__lookup_genre);
    
    #undef CHECK_FAILURE
    
    return failures;
}

int test_ApeTag_new_free(void) {
    struct ApeTag *tag;
    FILE *file;
    
    CHECK(ApeTag_new(NULL, 0) == NULL);
    CHECK(file = fopen("example1.tag", "r+"));
    CHECK(tag = ApeTag_new(file, 0));
    CHECK(tag->file == file && tag->items == NULL && tag->tag_header == NULL && \
       tag->tag_data == NULL && tag->tag_footer == NULL && tag->id3 == NULL && \
       ApeTag_error_code(tag) == APETAG_NOERR && \
       ApeTag_error(tag) == NULL && tag->flags == (APE_DEFAULT_FLAGS | 0) && \
       ApeTag_size(tag) == 0 && ApeTag_file_item_count(tag) == 0 && ApeTag_item_count(tag) == 0 && \
       tag->offset == 0);
    
    CHECK(ApeTag_parse(tag) == 0);
    CHECK(ApeTag_free(tag) == 0);
    CHECK(ApeTag_free(NULL) == 0);
    
    return 0;
}

int test_ApeTag_exists(void) {
    struct ApeTag *tag;
    FILE *file;
    
    #define TEST_EXIST(FILENAME, EXIST) \
        CHECK(file = fopen(FILENAME, "r+")); \
        CHECK(tag = ApeTag_new(file, 0)); \
        CHECK(ApeTag_exists(tag) == EXIST);
    
    CHECK(ApeTag_exists(NULL) == -1);
    TEST_EXIST("empty_ape.tag", 1);
    TEST_EXIST("empty_ape_id3.tag", 1);
    TEST_EXIST("empty_file.tag", 0);
    TEST_EXIST("empty_id3.tag", 0);
    TEST_EXIST("example1.tag", 1);
    TEST_EXIST("example1_id3.tag", 1);
    TEST_EXIST("example2.tag", 1);
    TEST_EXIST("example2_id3.tag", 1);
    
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
    
    CHECK(ApeTag_exists_id3(NULL) == -1);
    TEST_EXIST("empty_ape.tag", 0);
    TEST_EXIST("empty_ape_id3.tag", 1);
    TEST_EXIST("empty_file.tag", 0);
    TEST_EXIST("empty_id3.tag", 1);
    TEST_EXIST("example1.tag", 0);
    TEST_EXIST("example1_id3.tag", 1);
    TEST_EXIST("example2.tag", 0);
    TEST_EXIST("example2_id3.tag", 1);
    
    #undef TEST_EXIST
    
    return 0;
}

int test_ApeTag_maximums(void) {
    struct ApeTag *tag;
    FILE *file;
    
    #define TEST_EXIST(FILENAME, EXIST, ERROR) \
        CHECK(file = fopen(FILENAME, "r+")); \
        CHECK(tag = ApeTag_new(file, 0)); \
        CHECK(ApeTag_exists(tag) == EXIST); \
        CHECK(ApeTag_error_code(tag) == ERROR); \
    
    CHECK(ApeTag_get_max_size() == 8192);
    CHECK(ApeTag_get_max_item_count() == 64);

    ApeTag_set_max_item_count(0);
    CHECK(ApeTag_get_max_item_count() == 0);
    TEST_EXIST("empty_ape.tag", 1, APETAG_NOERR);
    TEST_EXIST("example1.tag", -1, APETAG_LIMITEXCEEDED);
    ApeTag_set_max_item_count(64);

    ApeTag_set_max_size(64);
    CHECK(ApeTag_get_max_size() == 64);
    TEST_EXIST("empty_ape.tag", 1, APETAG_NOERR);
    TEST_EXIST("example1.tag", -1, APETAG_LIMITEXCEEDED);
    ApeTag_set_max_size(63);
    TEST_EXIST("empty_ape.tag", -1, APETAG_LIMITEXCEEDED);
    ApeTag_set_max_size(8192);
    
    #undef TEST_EXIST
    
    return 0;
}

int test_ApeTag_remove(void) {
    struct ApeTag *tag;
    FILE *file;
    
    #define TEST_REMOVE(FILENAME, EXIST) \
        system("cp " FILENAME " " FILENAME ".0"); \
        CHECK(file = fopen(FILENAME ".0", "r+")); \
        system("rm " FILENAME ".0"); \
        CHECK(tag = ApeTag_new(file, 0)); \
        CHECK(ApeTag_remove(tag) == EXIST); \
        CHECK(ApeTag_exists(tag) == 0);
    
    CHECK(ApeTag_remove(NULL) == -1);
    TEST_REMOVE("empty_ape.tag", 0);
    TEST_REMOVE("empty_ape_id3.tag", 0);
    TEST_REMOVE("empty_file.tag", 1);
    TEST_REMOVE("empty_id3.tag", 1);
    TEST_REMOVE("example1.tag", 0);
    TEST_REMOVE("example1_id3.tag", 0);
    TEST_REMOVE("example2.tag", 0);
    TEST_REMOVE("example2_id3.tag",0);
    
    #undef TEST_REMOVE
    
    return 0;
}

int test_ApeTag_raw(void) {
    struct ApeTag *tag;
    FILE *file;
    char *raw_tag = NULL;
    char *file_contents = NULL;
    uint32_t raw_size;
    
    #define TEST_RAW(FILENAME, SIZE) \
        CHECK(file = fopen(FILENAME, "r+")); \
        CHECK(tag = ApeTag_new(file, 0)); \
        CHECK(file_contents = malloc(SIZE)); \
        CHECK(SIZE == fread(file_contents, 1, SIZE, file)); \
        CHECK(ApeTag_raw(tag, &raw_tag, &raw_size) == 0 && memcmp(file_contents, raw_tag, SIZE) == 0);
    
    CHECK(ApeTag_raw(NULL, &raw_tag, &raw_size) == -1);
    TEST_RAW("empty_ape.tag", 64);
    TEST_RAW("empty_ape_id3.tag", 192);
    TEST_RAW("empty_file.tag", 0);
    TEST_RAW("empty_id3.tag", 128);
    TEST_RAW("example1.tag", 208);
    TEST_RAW("example1_id3.tag", 336);
    TEST_RAW("example2.tag", 185);
    TEST_RAW("example2_id3.tag", 313);
    
    #undef TEST_RAW
    
    return 0;
}

int test_ApeTag_parse(void) {
    struct ApeTag *tag;
    FILE *file;
    DBT key_dbt, value_dbt;
    
    #define TEST_PARSE(FILENAME, ITEMS) \
        CHECK(file = fopen(FILENAME, "r+")); \
        CHECK(tag = ApeTag_new(file, 0)); \
        CHECK(ApeTag_parse(tag) == 0 && ITEMS == ApeTag_file_item_count(tag));
    
    #define HAS_FIELD(FIELD, KEY_LENGTH, VALUE, VALUE_LENGTH) \
        key_dbt.data = FIELD; \
        key_dbt.size = KEY_LENGTH; \
        CHECK(tag->items->get(tag->items, &key_dbt, &value_dbt, 0) == 0); \
        CHECK(memcmp(VALUE, (*(struct ApeItem **)(value_dbt.data))->value, VALUE_LENGTH) == 0); \
    
    CHECK(ApeTag_parse(NULL) == -1);
    TEST_PARSE("empty_ape.tag", 0);
    TEST_PARSE("empty_ape_id3.tag", 0);
    TEST_PARSE("empty_file.tag", 0);
    TEST_PARSE("empty_id3.tag", 0);
    TEST_PARSE("example1.tag", 6);
    TEST_PARSE("example1_id3.tag", 6);
    
    HAS_FIELD("track", 6, "1", 1);
    HAS_FIELD("comment", 8, "XXXX-0000", 9);
    HAS_FIELD("album", 6, "Test Album\0Other Album", 22);
    HAS_FIELD("title", 6, "Love Cheese", 11);
    HAS_FIELD("artist", 7, "Test Artist", 11);
    HAS_FIELD("date", 5, "2007", 4);
    
    TEST_PARSE("example2.tag", 5);
    TEST_PARSE("example2_id3.tag", 5);
    
    HAS_FIELD("blah", 5, "Blah", 4);
    HAS_FIELD("comment", 8, "XXXX-0000", 9);
    HAS_FIELD("album", 6, "Test Album\0Other Album", 22);
    HAS_FIELD("artist", 7, "Test Artist", 11);
    HAS_FIELD("date", 5, "2007", 4);
    
    #undef HAS_FIELD
    #undef TEST_PARSE
    
    return 0;
}

int test_ApeTag_update(void) {
    struct ApeTag *tag;
    struct ApeItem *item;
    FILE *file;
    char *before;
    char *after;
    char *empty_ape_id3;
    char *example1_id3;
    char *example2_id3;
    
    #define RAW_TAGS(POINTER, FILENAME, SIZE) \
        CHECK(file = fopen(FILENAME, "r")); \
        CHECK(POINTER = malloc(SIZE)); \
        CHECK(SIZE == fread(POINTER, 1, SIZE, file)); \
        CHECK(fclose(file) == 0);
    
    #define TEST_UPDATE(FILENAME, SIZE, CHANGED, ID3) \
        system("cp " FILENAME " " FILENAME ".0"); \
        CHECK(file = fopen(FILENAME ".0", "r+")); \
        system("rm " FILENAME ".0"); \
        CHECK(before = malloc(SIZE)); \
        CHECK(SIZE == fread(before, 1, SIZE, file)); \
        CHECK(tag = ApeTag_new(file, 0)); \
        CHECK(ApeTag_parse(tag) == 0); \
        CHECK(ApeTag_update(tag) == 0); \
        CHECK(fseek(file, 0, SEEK_SET) == 0); \
        CHECK(after = malloc(ApeTag_size(tag)+ID3)); \
        CHECK(ApeTag_size(tag)+ID3 == fread(after, 1, ApeTag_size(tag)+ID3, file)); \
        CHECK(memcmp(CHANGED ? empty_ape_id3 : before, after, ApeTag_size(tag)+ID3) == 0);
        
    #define ADD_FIELD(KEY, VALUE, SIZE) \
        item = malloc(sizeof(struct ApeItem)); \
        item->size = SIZE; \
        item->flags = 0; \
        item->key = malloc(strlen(KEY)+1); \
        item->value = malloc(SIZE); \
        memcpy(item->key, KEY, strlen(KEY)+1); \
        memcpy(item->value, VALUE, SIZE); \
        CHECK(ApeTag_add_item(tag, item) == 0);
        
    #define CHECK_TAG(POINTER, SIZE) \
        CHECK(ApeTag_update(tag) == 0); \
        CHECK(fseek(file, 0, SEEK_SET) == 0); \
        CHECK(after = malloc(SIZE)); \
        CHECK(SIZE == fread(after, 1, SIZE, file)); \
        CHECK(memcmp(POINTER, after, SIZE) == 0);
    
    RAW_TAGS(empty_ape_id3, "empty_ape_id3.tag", 192);
    RAW_TAGS(example1_id3, "example1_id3.tag", 336);
    RAW_TAGS(example2_id3, "example2_id3.tag", 313);
    
    CHECK(ApeTag_update(NULL) == -1);
    TEST_UPDATE("empty_ape.tag", 64, 0, 0);
    TEST_UPDATE("empty_ape_id3.tag", 192, 0, 128);
    TEST_UPDATE("empty_id3.tag", 128, 1, 128);
    TEST_UPDATE("example1.tag", 208, 0, 0);
    TEST_UPDATE("example1_id3.tag", 336, 0, 128);
    TEST_UPDATE("example2.tag", 185, 0, 0);
    TEST_UPDATE("example2_id3.tag", 313, 0, 128);
    TEST_UPDATE("empty_file.tag", 0, 1, 128);
    
    ADD_FIELD("Track", "1", 1);
    ADD_FIELD("Comment", "XXXX-0000", 9);
    ADD_FIELD("Album", "Test Album\0Other Album", 22);
    ADD_FIELD("Title", "Love Cheese", 11);
    ADD_FIELD("Artist", "Test Artist", 11);
    ADD_FIELD("Date", "2007", 4);
    CHECK_TAG(example1_id3, 336);
    
    ApeTag_remove_item(tag, "Title");
    ApeTag_remove_item(tag, "Track");
    ADD_FIELD("Blah", "Blah", 4);
    CHECK_TAG(example2_id3, 313);

    before = malloc(257);
    memset(before, 'a', 256);
    before[256] = '\0';
    CHECK(ApeTag_remove_item(tag, before) == -1);
    CHECK(ApeTag_error_code(tag) == APETAG_ARGERR);
    CHECK(ApeTag_get_item(tag, before) == NULL);
    CHECK(ApeTag_error_code(tag) == APETAG_ARGERR);
     
    #undef CHECK_TAG
    #undef ADD_FIELD
    #undef RAW_TAGS
    #undef TEST_UPDATE
    
    return 0;
}

int test_ApeTag_filesizes(void) {
    struct ApeTag *tag;
    FILE *file;
    int i;
    
    CHECK(file = fopen("new.tag", "w+"));
    system("rm new.tag");
    
    #define TEST_FILESIZE(SIZE) \
        CHECK(tag = ApeTag_new(file, 0)); \
        CHECK(ftruncate(fileno(tag->file), 0) == 0); \
        for (i=0; i<SIZE; i++) { \
            CHECK(1 == fwrite(" ", 1, 1, file)); \
        } \
        CHECK(ApeTag_exists(tag) == 0); \
        CHECK(ApeTag_exists_id3(tag) == 0);
    
    TEST_FILESIZE(0);
    TEST_FILESIZE(1);
    TEST_FILESIZE(63);
    TEST_FILESIZE(64);
    TEST_FILESIZE(65);
    TEST_FILESIZE(127);
    TEST_FILESIZE(128);
    TEST_FILESIZE(129);
    TEST_FILESIZE(191);
    TEST_FILESIZE(192);
    TEST_FILESIZE(193);
    TEST_FILESIZE(8191);
    TEST_FILESIZE(8192);
    TEST_FILESIZE(8193);
    TEST_FILESIZE(8319);
    TEST_FILESIZE(8320);
    TEST_FILESIZE(8321);
    
    #undef TEST_FILESIZE
    
    return 0;
}

int test_ApeItem_validity(void) {
    FILE *file;
    struct ApeTag *tag;
    struct ApeItem item;
    unsigned char i;
    
    item.key = "key";
    item.value = "value";
    item.size = 5;
    item.flags = 0;
    
    CHECK(file = fopen("empty_ape_id3.tag", "r+"));
    CHECK(tag = ApeTag_new(file, 0)); \
    
    #define CHECK_VALIDITY(RESULT) \
        CHECK(ApeItem__check_validity(tag, &item) == (RESULT));
    
    /* Check invalid flags */
    CHECK_VALIDITY(0);
    item.flags = 8;
    CHECK_VALIDITY(-1);
    item.flags = 0;
    
    /* Check invalid keys */
    CHECK_VALIDITY(0);
    item.key="";
    CHECK_VALIDITY(-1);
    item.key="a";
    CHECK_VALIDITY(-1);
    item.key="aa";
    CHECK_VALIDITY(0);
    item.key="tag";
    CHECK_VALIDITY(-1);
    item.key="oggs";
    CHECK_VALIDITY(-1);
    item.key="MP+";
    CHECK_VALIDITY(-1);
    item.key="ID3";
    CHECK_VALIDITY(-1);
    item.key=malloc(260);
    memcpy(item.key, "TAGS", 5);
    CHECK_VALIDITY(0);
    for (i=0; i < 0x20; i++) {
        *(item.key+3) = (char)i;
        CHECK_VALIDITY(-1);
    }
    for (i=0xff; i >= 0x80; i--) {
        *(item.key+3) = (char)i;
        CHECK_VALIDITY(-1);
    }
    for (i=0; i<9; i++) {
        memcpy(item.key+(26*i), "qwertyuiopasdfghjklzxcvbnm", 27);
        CHECK_VALIDITY(0);
    }
    memcpy(item.key+234, "qwertyuiopasdfghjklzxcvbnm", 21);
    CHECK_VALIDITY(0);
    memcpy(item.key+235, "qwertyuiopasdfghjklzxcvbnm", 21);
    CHECK_VALIDITY(-1);
    item.key="ID32";
    CHECK_VALIDITY(0);
    
    /* Check invalid values */
    item.value="abcde";
    CHECK_VALIDITY(0);
    /* Handle 2, 3, and 4 byte UTF8 */
    item.value="abc\322\260";
    CHECK_VALIDITY(0);
    item.value="ab\340\245\240";
    CHECK_VALIDITY(0);
    item.value="a\360\220\207\220";
    CHECK_VALIDITY(0);
    /* End in middle of UTF8 character */
    item.value="ab\360\220\207\220";
    CHECK_VALIDITY(-1);
    /* Bad UTF8 */
    item.value="ab\274\285";
    CHECK_VALIDITY(-1);
    /* Binary means non-UTF8 is ok */
    item.flags = (item.flags & APE_ITEM_TYPE_FLAGS) + APE_ITEM_BINARY;
    CHECK_VALIDITY(0);
    
    #undef CHECK_VALIDITY
    
    return 0;
}

int test_bad_tags(void) {
    struct ApeTag *tag;
    FILE *empty;
    FILE *example1;
    char *empty_raw;
    char *example1_raw;
    unsigned char c;
    int i;
    uint32_t raw_size;
    
    #define OPEN_FILE(FILE, RAW, FILENAME) \
        system("cp " FILENAME " " FILENAME ".0"); \
        CHECK(FILE = fopen(FILENAME ".0", "r+")); \
        system("rm " FILENAME ".0"); \
        CHECK(tag = ApeTag_new(FILE, 0)); \
        CHECK(ApeTag_parse(tag) == 0); \
        CHECK(ApeTag_raw(tag, &RAW, &raw_size) == 0);
    
    #define WRITE_BYTES(FILE, OFFSET, VALUE, LENGTH) \
        CHECK(fseek(FILE, OFFSET, SEEK_SET) == 0); \
        CHECK(LENGTH == fwrite(VALUE, 1, LENGTH, FILE));
        
    #define RESET_FILE(FILE, RAW, LENGTH, PADDING) \
        CHECK(fseek(FILE, 0, SEEK_SET) == 0); \
        for (i = 0; i < PADDING; i++){ \
            CHECK(1 == fwrite(" ", 1, 1, FILE)); \
        } \
        CHECK(LENGTH == fwrite(RAW, 1, LENGTH, FILE)); \
        CHECK(ftruncate(fileno(FILE), LENGTH) == 0);
        
    #define CHECK_PARSE(FILE, VALUE, ERROR) \
        CHECK(tag = ApeTag_new(FILE, 0)); \
        CHECK(ApeTag_parse(tag) == VALUE); \
        CHECK(ApeTag_error_code(tag) == ERROR); \
        CHECK(ApeTag_free(tag) == 0);
    
    /* Open files check good parse */
    OPEN_FILE(empty, empty_raw, "empty_ape_id3.tag");
    CHECK_PARSE(empty, 0, APETAG_NOERR);
    OPEN_FILE(example1, example1_raw, "example1_id3.tag");
    CHECK_PARSE(example1, 0, APETAG_NOERR);

    /* Check works with read only flag, but not other flags */
    WRITE_BYTES(empty, 20, "\1", 1);
    CHECK_PARSE(empty, 0, APETAG_NOERR);
    for (c=255;c>1;c--) {
        WRITE_BYTES(empty, 20, &c, 1);
        CHECK_PARSE(empty, -1, APETAG_CORRUPTTAG);
    } 
    WRITE_BYTES(empty, 20, "\1", 1);
    WRITE_BYTES(empty, 52, "\1", 1);
    CHECK_PARSE(empty, 0, APETAG_NOERR);
    for (c=255;c>1;c--) {
        WRITE_BYTES(empty, 52, &c, 1);
        CHECK_PARSE(empty, -1, APETAG_CORRUPTTAG);
        WRITE_BYTES(empty, 20, &c, 1);
        CHECK_PARSE(empty, -1, APETAG_CORRUPTTAG);
    } 
    WRITE_BYTES(empty, 20, "\1", 1);
    WRITE_BYTES(empty, 52, "\1", 1);
    CHECK_PARSE(empty, 0, APETAG_NOERR);

    /* Test footer size < minimum size*/
    WRITE_BYTES(empty, 44, "\37", 1);
    CHECK_PARSE(empty, -1, APETAG_CORRUPTTAG);
    WRITE_BYTES(empty, 44, "\0", 1);
    CHECK_PARSE(empty, -1, APETAG_CORRUPTTAG);
    
    /* Test footer size > 8192 (APE_MAXIMUM_TAG_SIZE) */
    WRITE_BYTES(empty, 44, "\341\37", 2);
    CHECK_PARSE(empty, -1, APETAG_LIMITEXCEEDED);
    /* Check even when it isn't large than file */
    RESET_FILE(empty, empty_raw, 192, 8192);
    WRITE_BYTES(empty, 8192+44, "\341\37", 2);
    CHECK_PARSE(empty, -1, APETAG_LIMITEXCEEDED);
    
    RESET_FILE(empty, empty_raw, 192, 0);
    /* Check unmatched header and footer, with header size wrong */
    WRITE_BYTES(empty, 12, "\41", 1);
    CHECK_PARSE(empty, -1, APETAG_CORRUPTTAG);
    /* Check matched header and footer size, both wrong */
    WRITE_BYTES(empty, 44, "\41", 1);
    CHECK_PARSE(empty, -1, APETAG_CORRUPTTAG);
    /* Check unmatched header and footer, with footer size wrong */
    WRITE_BYTES(empty, 12, "\40", 1);
    CHECK_PARSE(empty, -1, APETAG_CORRUPTTAG);
    /* Check unmatched header and footer, with footer size wrong,
       not larger than file */
    RESET_FILE(empty, empty_raw, 192, 1);
    WRITE_BYTES(empty, 45, "\41", 1);
    CHECK_PARSE(empty, -1, APETAG_CORRUPTTAG);
    
    /* Check item count greater than 64 (APE_MAXIMUM_ITEM_COUNT) */
    RESET_FILE(empty, empty_raw, 192, 0);
    WRITE_BYTES(empty, 48, "\101", 1);
    CHECK_PARSE(empty, -1, APETAG_LIMITEXCEEDED);
    /* Check item count greater than possible given size */
    WRITE_BYTES(empty, 48, "\1", 1);
    CHECK_PARSE(empty, -1, APETAG_CORRUPTTAG);
    /* Check unmatched header and footer item count, header wrong */
    WRITE_BYTES(empty, 48, "\0", 1);
    WRITE_BYTES(empty, 16, "\1", 1);
    CHECK_PARSE(empty, -1, APETAG_CORRUPTTAG);
    /* Check unmatched header and footer item count, footer wrong */
    WRITE_BYTES(example1, 48, "\1", 1);
    CHECK_PARSE(example1, -1, APETAG_CORRUPTTAG);
    
    /* Check missing/corrupt header */
    RESET_FILE(empty, empty_raw, 192, 0);
    WRITE_BYTES(empty, 0, "\0", 1);
    CHECK_PARSE(empty, -1, APETAG_CORRUPTTAG);
    
    /* Check parsing bad first item size */
    RESET_FILE(example1, example1_raw, 336, 0);
    WRITE_BYTES(example1, 32, "\2", 1);
    CHECK_PARSE(example1, -1, APETAG_INVALIDITEM);
    
    /* Check parsing bad first item invalid key */
    RESET_FILE(example1, example1_raw, 336, 0);
    WRITE_BYTES(example1, 40, "\0", 1);
    CHECK_PARSE(example1, -1, APETAG_INVALIDITEM);
    
    /* Check parsing bad first item key end */
    RESET_FILE(example1, example1_raw, 336, 0);
    WRITE_BYTES(example1, 45, "\1", 1);
    CHECK_PARSE(example1, -1, APETAG_INVALIDITEM);
    
    /* Check parsing bad second item length too long */
    RESET_FILE(example1, example1_raw, 336, 0);
    WRITE_BYTES(example1, 47, "\377", 1);
    CHECK_PARSE(example1, -1, APETAG_CORRUPTTAG);
    
    /* Check parsing case insensitive duplicate keys */
    RESET_FILE(example1, example1_raw, 336, 0);
    WRITE_BYTES(example1, 40, "Album", 5);
    CHECK_PARSE(example1, -1, APETAG_DUPLICATEITEM);
    WRITE_BYTES(example1, 40, "album", 5);
    CHECK_PARSE(example1, -1, APETAG_DUPLICATEITEM);
    WRITE_BYTES(example1, 40, "ALBUM", 5);
    CHECK_PARSE(example1, -1, APETAG_DUPLICATEITEM);
    
    /* Check parsing incorrect item counts */
    RESET_FILE(example1, example1_raw, 336, 0);
    WRITE_BYTES(example1, 16, "\5", 1);
    WRITE_BYTES(example1, 192, "\5", 1);
    CHECK_PARSE(example1, -1, APETAG_CORRUPTTAG);
    WRITE_BYTES(example1, 16, "\7", 1);
    WRITE_BYTES(example1, 192, "\7", 1);
    CHECK_PARSE(example1, -1, APETAG_CORRUPTTAG);
    
    #undef CHECK_PARSE
    #undef RESET_FILE
    #undef WRITE_BYTE
    #undef OPEN_FILE
    
    return 0;
}

int test_ApeTag_add_remove_clear_items_update(void) {
    struct ApeTag *tag;
    FILE *file;
    struct ApeItem *item;
    struct ApeItem *check_item;
    struct ApeItem **items;
    uint32_t items_size;
    int i;
    
    CHECK(ApeTag_clear_items(NULL) == -1);
    CHECK(ApeTag_get_items(NULL, NULL) == NULL);
    CHECK(ApeTag_get_item(NULL, NULL) == NULL);
    CHECK(ApeTag_add_item(NULL, NULL) == -1);
    CHECK(ApeTag_remove_item(NULL, NULL) == -1);
    CHECK(ApeTag_replace_item(NULL, NULL) == -1);

    system("cp example1_id3.tag example1_id3.tag.0");
    CHECK(file = fopen("example1_id3.tag.0", "r+"));
    system("rm example1_id3.tag.0");
        
    /* Test functions before parsing */
    CHECK(tag = ApeTag_new(file, 0));
    CHECK(ApeTag_clear_items(tag) == 0);
    items = ApeTag_get_items(tag, &items_size);
    CHECK(items);
    free(items);
    CHECK(items_size == 0);
    CHECK(item = malloc(sizeof(struct ApeItem)));
    item->size = 5;
    item->flags = 0;
    CHECK(item->key = malloc(6));
    CHECK(item->value = malloc(5));
    memcpy(item->key, "ALBUM", 6);
    memcpy(item->value, "VALUE", 5);
    CHECK(ApeTag_add_item(tag, item) == 0);

    CHECK(ApeTag_get_item(tag, "track") == NULL);
    CHECK(ApeTag_error_code(tag) == APETAG_NOTPRESENT);
    CHECK(check_item = ApeTag_get_item(tag, "album"));
    CHECK(check_item->size == 5);
    CHECK(check_item->flags == 0);
    CHECK(strcmp(check_item->key, "ALBUM") == 0);
    CHECK(memcmp(check_item->value, "VALUE", 5) == 0);

    items = ApeTag_get_items(tag, &items_size);
    CHECK(items != NULL);
    CHECK(items_size == 1);
    CHECK(items[0]->size == 5);
    CHECK(items[0]->flags == 0);
    CHECK(strcmp(items[0]->key, "ALBUM") == 0);
    CHECK(memcmp(items[0]->value, "VALUE", 5) == 0);
    free(items);

    /* ensure we don't crash if we don't care about the item count */
    items = ApeTag_get_items(tag, NULL);
    CHECK(items != NULL);
    CHECK(items[0]->size == 5);
    CHECK(items[0]->flags == 0);
    CHECK(strcmp(items[0]->key, "ALBUM") == 0);
    CHECK(memcmp(items[0]->value, "VALUE", 5) == 0);
    free(items);

    CHECK(item = malloc(sizeof(struct ApeItem)));
    item->size = 3;
    item->flags = 0;
    CHECK(item->key = malloc(6));
    CHECK(item->value = malloc(5));
    memcpy(item->key, "ALBUM", 6);
    memcpy(item->value, "FOO", 3);

    CHECK(ApeTag_add_item(tag, item) == -1);
    CHECK(ApeTag_replace_item(tag, item) == 1);
    CHECK(check_item = ApeTag_get_item(tag, "album"));
    CHECK(check_item->size == 3);
    CHECK(check_item->flags == 0);
    CHECK(strcmp(check_item->key, "ALBUM") == 0);
    CHECK(memcmp(check_item->value, "FOO", 3) == 0);

    CHECK(ApeTag_remove_item(tag, "track") == 1);
    CHECK(ApeTag_error_code(tag) == APETAG_NOTPRESENT);
    CHECK(ApeTag_remove_item(tag, "album") == 0);

    CHECK(item = malloc(sizeof(struct ApeItem)));
    item->size = 3;
    item->flags = 0;
    CHECK(item->key = malloc(6));
    CHECK(item->value = malloc(5));
    memcpy(item->key, "ALBUM", 6);
    memcpy(item->value, "FOO", 3);

    CHECK(ApeTag_replace_item(tag, item) == 0);
    CHECK(check_item = ApeTag_get_item(tag, "album"));
    CHECK(check_item->size == 3);
    CHECK(check_item->flags == 0);
    CHECK(strcmp(check_item->key, "ALBUM") == 0);
    CHECK(memcmp(check_item->value, "FOO", 3) == 0);

    CHECK(ApeTag_clear_items(tag) == 0);
    CHECK(ApeTag_parse(tag) == 0);
    
    /* Test after parsing */
    CHECK(tag = ApeTag_new(file, 0));
    CHECK(ApeTag_parse(tag) == 0);
    CHECK(ApeTag_remove_item(tag, "track") == 0);
    
    /* Check add duplicate key */
    CHECK(item = malloc(sizeof(struct ApeItem)));
    CHECK(item->key = malloc(6));
    CHECK(item->value = malloc(5));
    item->size = 5;
    item->flags = 0;
    memcpy(item->key, "ALBUM", 6);
    memcpy(item->value,"VALUE",  5);
    CHECK(ApeTag_add_item(tag, item) == -1);
    memcpy(item->key, "album", 6);
    CHECK(ApeTag_add_item(tag, item) == -1);
    
    /* Check adding more items than allowed */
    CHECK(ApeTag_clear_items(tag) == 0);
    for (i=0; i < 64; i++) {
        CHECK(item = malloc(sizeof(struct ApeItem)));
        CHECK(item->key = malloc(6));
        CHECK(item->value = malloc(3));
        item->size = 2;
        item->flags = 0;
        snprintf(item->key, 6, "Key%02i", i);
        snprintf(item->value, 3, "%02i", i);
        CHECK(ApeTag_add_item(tag, item) == 0);
    }
    CHECK(item = malloc(sizeof(struct ApeItem)));
    CHECK(item->key = malloc(6));
    CHECK(item->value = malloc(2));
    item->size = 2;
    item->flags = 0;
    snprintf(item->key, 6, "Key65");
    snprintf(item->value, 2, "65");
    CHECK(ApeTag_add_item(tag, item) == -1);
    
    /* Check updating with too large tag not allowed */
    CHECK(tag = ApeTag_new(file, 0));
    CHECK(ApeTag_exists(tag) == 1);
    CHECK(ApeTag_exists_id3(tag) == 1);
    CHECK(item = malloc(sizeof(struct ApeItem)));
    CHECK(item->key = malloc(9));
    CHECK(item->value = malloc(8112));
    item->size = 8112;
    item->flags = 0;
    memcpy(item->key, "Too Big!", 9);
    for (i=0; i < 507; i++) {
        memcpy(item->value+i*16, "0123456789abcdef", 16);
    }
    CHECK(ApeTag_add_item(tag, item) == 0);
    CHECK(ApeTag_update(tag) == -1);

    /* Check fits perfectly */
    item->size = 8111;
    CHECK(ApeTag_update(tag) == 0);
    
    return 0;
}

int test_no_id3(void) {
    struct ApeTag *tag;
    FILE *file;
    char *file_contents;
    char *raw;
    uint32_t raw_size;
    
    #define TEST_INFO_NO_ID3(FILENAME, FLAGS, NO_ID3_FLAGS) \
        system("cp " FILENAME " " FILENAME ".0"); \
        CHECK(file = fopen(FILENAME ".0", "r+")); \
        system("rm " FILENAME ".0"); \
        CHECK(tag = ApeTag_new(file, 0)); \
        CHECK(ApeTag_exists(tag) >= 0); \
        CHECK((tag->flags & (APE_HAS_APE|APE_HAS_ID3)) == (FLAGS)) \
        CHECK(tag = ApeTag_new(file, APE_NO_ID3)); \
        CHECK(ApeTag_exists(tag) >= 0); \
        CHECK((tag->flags & (APE_HAS_APE|APE_HAS_ID3)) == (NO_ID3_FLAGS)); \
        CHECK(0 == ApeTag__id3_length(tag)); \
        if (NO_ID3_FLAGS & APE_HAS_APE) { \
            CHECK(0 == fseek(file, 0, SEEK_SET)); \
            CHECK(file_contents = malloc(ApeTag_size(tag))); \
            CHECK(raw = malloc(ApeTag_size(tag))); \
            CHECK(ApeTag_size(tag) == fread(file_contents, 1, ApeTag_size(tag), file)); \
            CHECK(0 == ApeTag_raw(tag, &raw, &raw_size)); \
            CHECK(0 == memcmp(file_contents, raw, ApeTag_size(tag))); \
            CHECK(0 == ApeTag_parse(tag)); \
            CHECK(0 == ApeTag_update(tag)); \
            CHECK(0 == fseek(file, 0, SEEK_END)); \
            CHECK(ApeTag_size(tag) == (u_int32_t)ftell(file)); \
            CHECK(0 == fseek(file, 0, SEEK_SET)); \
            CHECK(ApeTag_size(tag) == fread(raw, 1, ApeTag_size(tag), file)); \
            CHECK(0 == memcmp(file_contents, raw, ApeTag_size(tag))); \
        }
        
    TEST_INFO_NO_ID3("empty_ape.tag", APE_HAS_APE, APE_HAS_APE);
    TEST_INFO_NO_ID3("empty_ape_id3.tag", APE_HAS_APE|APE_HAS_ID3, 0);
    TEST_INFO_NO_ID3("empty_file.tag", 0, 0);
    TEST_INFO_NO_ID3("empty_id3.tag", APE_HAS_ID3, 0);
    TEST_INFO_NO_ID3("example1.tag", APE_HAS_APE, APE_HAS_APE);
    TEST_INFO_NO_ID3("example1_id3.tag", APE_HAS_APE|APE_HAS_ID3, 0);
    TEST_INFO_NO_ID3("example2.tag", APE_HAS_APE, APE_HAS_APE);
    TEST_INFO_NO_ID3("example2_id3.tag", APE_HAS_APE|APE_HAS_ID3, 0);
    
    #undef TEST_NO_ID3
    
    return 0;
}

int test_ApeTag__strcasecpy(void) {
    int i;
    char s[11];
    
    #define TEST_STRCASECPY(STRING, LENGTH) \
        CHECK(strcasecmp(ApeTag__strcasecpy(STRING, 6), STRING) == 0);
    
    TEST_STRCASECPY("album", 6);
    TEST_STRCASECPY("Album", 6);
    TEST_STRCASECPY("ALBUM", 6);
    
    for (i=1; i <= 255; i++) {
        snprintf(s, 10, "0%caZ9", i);
        CHECK(strcasecmp(ApeTag__strcasecpy(s, 6), s) == 0);
    }

    return 0;
}

int test_ApeItem__parse_track(void) {
    unsigned char i, j, k;
    char s[4];
    
    CHECK(ApeItem__parse_track(0, "1") == 0)
    CHECK(ApeItem__parse_track(4, "1") == 0)
    CHECK(ApeItem__parse_track(1, "a") == 0)
    
    for (i=0; i<10; i++) {
        memset(s, 0, 4);
        s[0] = '0' + i;
        CHECK(i == ApeItem__parse_track(1, s));
        for (j=0; j<10; j++) {
            s[1] = '0' + j;
            CHECK(j+10*i == ApeItem__parse_track(2, s));
            for (k=0; k<10; k++) {
                s[2] = '0' + k;
                if (i > 2 || (i == 2 && (j > 5 || (j == 5 && k > 5)))) {
                    CHECK(0 == ApeItem__parse_track(3, s));
                } else {
                    CHECK(k+10*j+100*i == ApeItem__parse_track(3, s));
                }
                if (k+10*j+100*i < '0' || k+10*j+100*i > '9') {
                    s[2] = k+10*j+100*i;
                    CHECK(0 == ApeItem__parse_track(3, s+2));
                }
            }
        }
    }
    
    return 0;
}

int test_ApeItem__compare(void) {
    struct ApeItem a, b;
    const struct ApeItem *pa = &a, *pb = &b;
    
    a.size = 0;
    b.size = 0;
    a.key = "Key";
    b.key = "Key";
    
    CHECK(0 == ApeItem__compare(&pa, &pb));
    a.size = 1;
    CHECK(1 == ApeItem__compare(&pa, &pb));
    b.size = 2;
    CHECK(-1 == ApeItem__compare(&pa, &pb));
    a.size = 2;
    CHECK(0 == ApeItem__compare(&pa, &pb));
    a.key = "Lex";
    CHECK(1 == ApeItem__compare(&pa, &pb));
    b.key = "Mouse";
    CHECK(-1 == ApeItem__compare(&pa, &pb));
    
    return 0;
}

int test_ApeTag__lookup_genre(void) {
    struct ApeTag tag;
    struct ApeItem item;
    unsigned char genre_id;

    #define LOOKUP_GENRE(GENRE, VALUE) \
        memset(&item, 0, sizeof(struct ApeItem)); \
        item.value = (GENRE); \
        item.size = strlen(GENRE); \
        CHECK(ApeTag__lookup_genre(&tag, &item, &genre_id) == 0); \
        CHECK((unsigned char)(VALUE) == genre_id);
    
    LOOKUP_GENRE("Blues", '\0');
    LOOKUP_GENRE("Classic Rock", '\1');
    LOOKUP_GENRE("Country", '\2');
    LOOKUP_GENRE("Dance", '\3');
    LOOKUP_GENRE("Disco", '\4');
    LOOKUP_GENRE("Funk", '\5');
    LOOKUP_GENRE("Grunge", '\6');
    LOOKUP_GENRE("Hip-Hop", '\7');
    LOOKUP_GENRE("Jazz", '\10');
    LOOKUP_GENRE("Metal", '\11');
    LOOKUP_GENRE("New Age", '\12');
    LOOKUP_GENRE("Oldies", '\13');
    LOOKUP_GENRE("Other", '\14');
    LOOKUP_GENRE("Pop", '\15');
    LOOKUP_GENRE("R & B", '\16');
    LOOKUP_GENRE("Rap", '\17');
    LOOKUP_GENRE("Reggae", '\20');
    LOOKUP_GENRE("Rock", '\21');
    LOOKUP_GENRE("Techno", '\22');
    LOOKUP_GENRE("Industrial", '\23');
    LOOKUP_GENRE("Alternative", '\24');
    LOOKUP_GENRE("Ska", '\25');
    LOOKUP_GENRE("Death Metal", '\26');
    LOOKUP_GENRE("Prank", '\27');
    LOOKUP_GENRE("Soundtrack", '\30');
    LOOKUP_GENRE("Euro-Techno", '\31');
    LOOKUP_GENRE("Ambient", '\32');
    LOOKUP_GENRE("Trip-Hop", '\33');
    LOOKUP_GENRE("Vocal", '\34');
    LOOKUP_GENRE("Jazz + Funk", '\35');
    LOOKUP_GENRE("Fusion", '\36');
    LOOKUP_GENRE("Trance", '\37');
    LOOKUP_GENRE("Classical", '\40');
    LOOKUP_GENRE("Instrumental", '\41');
    LOOKUP_GENRE("Acid", '\42');
    LOOKUP_GENRE("House", '\43');
    LOOKUP_GENRE("Game", '\44');
    LOOKUP_GENRE("Sound Clip", '\45');
    LOOKUP_GENRE("Gospel", '\46');
    LOOKUP_GENRE("Noise", '\47');
    LOOKUP_GENRE("Alternative Rock", '\50');
    LOOKUP_GENRE("Bass", '\51');
    LOOKUP_GENRE("Soul", '\52');
    LOOKUP_GENRE("Punk", '\53');
    LOOKUP_GENRE("Space", '\54');
    LOOKUP_GENRE("Meditative", '\55');
    LOOKUP_GENRE("Instrumental Pop", '\56');
    LOOKUP_GENRE("Instrumental Rock", '\57');
    LOOKUP_GENRE("Ethnic", '\60');
    LOOKUP_GENRE("Gothic", '\61');
    LOOKUP_GENRE("Darkwave", '\62');
    LOOKUP_GENRE("Techno-Industrial", '\63');
    LOOKUP_GENRE("Electronic", '\64');
    LOOKUP_GENRE("Pop-Fol", '\65');
    LOOKUP_GENRE("Eurodance", '\66');
    LOOKUP_GENRE("Dream", '\67');
    LOOKUP_GENRE("Southern Rock", '\70');
    LOOKUP_GENRE("Comedy", '\71');
    LOOKUP_GENRE("Cult", '\72');
    LOOKUP_GENRE("Gangsta", '\73');
    LOOKUP_GENRE("Top 40", '\74');
    LOOKUP_GENRE("Christian Rap", '\75');
    LOOKUP_GENRE("Pop/Funk", '\76');
    LOOKUP_GENRE("Jungle", '\77');
    LOOKUP_GENRE("Native US", '\100');
    LOOKUP_GENRE("Cabaret", '\101');
    LOOKUP_GENRE("New Wave", '\102');
    LOOKUP_GENRE("Psychadelic", '\103');
    LOOKUP_GENRE("Rave", '\104');
    LOOKUP_GENRE("Showtunes", '\105');
    LOOKUP_GENRE("Trailer", '\106');
    LOOKUP_GENRE("Lo-Fi", '\107');
    LOOKUP_GENRE("Tribal", '\110');
    LOOKUP_GENRE("Acid Punk", '\111');
    LOOKUP_GENRE("Acid Jazz", '\112');
    LOOKUP_GENRE("Polka", '\113');
    LOOKUP_GENRE("Retro", '\114');
    LOOKUP_GENRE("Musical", '\115');
    LOOKUP_GENRE("Rock & Roll", '\116');
    LOOKUP_GENRE("Hard Rock", '\117');
    LOOKUP_GENRE("Folk", '\120');
    LOOKUP_GENRE("Folk-Rock", '\121');
    LOOKUP_GENRE("National Folk", '\122');
    LOOKUP_GENRE("Swing", '\123');
    LOOKUP_GENRE("Fast Fusion", '\124');
    LOOKUP_GENRE("Bebop", '\125');
    LOOKUP_GENRE("Latin", '\126');
    LOOKUP_GENRE("Revival", '\127');
    LOOKUP_GENRE("Celtic", '\130');
    LOOKUP_GENRE("Bluegrass", '\131');
    LOOKUP_GENRE("Avantgarde", '\132');
    LOOKUP_GENRE("Gothic Rock", '\133');
    LOOKUP_GENRE("Progressive Rock", '\134');
    LOOKUP_GENRE("Psychedelic Rock", '\135');
    LOOKUP_GENRE("Symphonic Rock", '\136');
    LOOKUP_GENRE("Slow Rock", '\137');
    LOOKUP_GENRE("Big Band", '\140');
    LOOKUP_GENRE("Chorus", '\141');
    LOOKUP_GENRE("Easy Listening", '\142');
    LOOKUP_GENRE("Acoustic", '\143');
    LOOKUP_GENRE("Humour", '\144');
    LOOKUP_GENRE("Speech", '\145');
    LOOKUP_GENRE("Chanson", '\146');
    LOOKUP_GENRE("Opera", '\147');
    LOOKUP_GENRE("Chamber Music", '\150');
    LOOKUP_GENRE("Sonata", '\151');
    LOOKUP_GENRE("Symphony", '\152');
    LOOKUP_GENRE("Booty Bass", '\153');
    LOOKUP_GENRE("Primus", '\154');
    LOOKUP_GENRE("Porn Groove", '\155');
    LOOKUP_GENRE("Satire", '\156');
    LOOKUP_GENRE("Slow Jam", '\157');
    LOOKUP_GENRE("Club", '\160');
    LOOKUP_GENRE("Tango", '\161');
    LOOKUP_GENRE("Samba", '\162');
    LOOKUP_GENRE("Folklore", '\163');
    LOOKUP_GENRE("Ballad", '\164');
    LOOKUP_GENRE("Power Ballad", '\165');
    LOOKUP_GENRE("Rhytmic Soul", '\166');
    LOOKUP_GENRE("Freestyle", '\167');
    LOOKUP_GENRE("Duet", '\170');
    LOOKUP_GENRE("Punk Rock", '\171');
    LOOKUP_GENRE("Drum Solo", '\172');
    LOOKUP_GENRE("Acapella", '\173');
    LOOKUP_GENRE("Euro-House", '\174');
    LOOKUP_GENRE("Dance Hall", '\175');
    LOOKUP_GENRE("Goa", '\176');
    LOOKUP_GENRE("Drum & Bass", '\177');
    LOOKUP_GENRE("Club-House", '\200');
    LOOKUP_GENRE("Hardcore", '\201');
    LOOKUP_GENRE("Terror", '\202');
    LOOKUP_GENRE("Indie", '\203');
    LOOKUP_GENRE("BritPop", '\204');
    LOOKUP_GENRE("Negerpunk", '\205');
    LOOKUP_GENRE("Polsk Punk", '\206');
    LOOKUP_GENRE("Beat", '\207');
    LOOKUP_GENRE("Christian Gangsta Rap", '\210');
    LOOKUP_GENRE("Heavy Metal", '\211');
    LOOKUP_GENRE("Black Metal", '\212');
    LOOKUP_GENRE("Crossover", '\213');
    LOOKUP_GENRE("Contemporary Christian", '\214');
    LOOKUP_GENRE("Christian Rock", '\215');
    LOOKUP_GENRE("Merengue", '\216');
    LOOKUP_GENRE("Salsa", '\217');
    LOOKUP_GENRE("Thrash Metal", '\220');
    LOOKUP_GENRE("Anime", '\221');
    LOOKUP_GENRE("Jpop", '\222');
    LOOKUP_GENRE("Synthpop", '\223');
    
    #undef LOOKUP_GENRE
    
    return 0;
}
