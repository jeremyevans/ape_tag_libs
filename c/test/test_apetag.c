#include <apetag.c>
#include <err.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int assertions = 0;

#define CHECK(RESULT) assertions++; if(!(RESULT)) { return __LINE__; }

int run_tests(void);
int test_ApeTag_new_free(void);
int test_ApeTag_exists(void);
int test_ApeTag_remove(void);
int test_ApeTag_raw(void);
int test_ApeTag_parse(void);
int test_ApeTag_update(void);
int test_ApeTag_add_remove_clear_fields_update(void);
int test_ApeTag_filesizes(void);
int test_ApeItem_validity(void);
int test_bad_tags(void);
int test_no_id3(void);
int test_ApeTag__strcasecpy(void);
int test_ApeItem__parse_track(void);
int test_ApeItem__compare(void);
int test_ApeTag__lookup_genre(void);

int main(void) {
    int num_failures = 0;
    
    if(chdir("tags") != 0) {
        err(1, NULL);
    }
    num_failures = run_tests();
    
    if(num_failures == 0) {
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
        if((line = FUNCTION())) { \
            failures ++; \
            printf(#FUNCTION " failed on line %i\n", line) ; \
        }
            
    CHECK_FAILURE(test_ApeTag_new_free);
    CHECK_FAILURE(test_ApeTag_exists);
    CHECK_FAILURE(test_ApeTag_remove);
    CHECK_FAILURE(test_ApeTag_raw);
    CHECK_FAILURE(test_ApeTag_parse);
    CHECK_FAILURE(test_ApeTag_update);
    CHECK_FAILURE(test_ApeTag_filesizes);
    CHECK_FAILURE(test_ApeItem_validity);
    CHECK_FAILURE(test_bad_tags);
    CHECK_FAILURE(test_ApeTag_add_remove_clear_fields_update);
    CHECK_FAILURE(test_no_id3);
    CHECK_FAILURE(test_ApeTag__strcasecpy);
    CHECK_FAILURE(test_ApeItem__parse_track);
    CHECK_FAILURE(test_ApeItem__compare);
    CHECK_FAILURE(test_ApeTag__lookup_genre);
    
    #undef CHECK_FAILURE
    
    return failures;
}

int test_ApeTag_new_free(void) {
    ApeTag* tag;
    FILE* file;
    
    CHECK(file = fopen("example1.tag", "r+"));
    CHECK(tag = ApeTag_new(file, 0));
    CHECK(tag->file == file && tag->fields == NULL && tag->tag_header == NULL && \
       tag->tag_data == NULL && tag->tag_footer == NULL && tag->id3 == NULL && \
       tag->error == NULL && tag->flags == (APE_DEFAULT_FLAGS | 0) && \
       tag->size == 0 && tag->item_count == 0 && tag->num_fields == 0 && \
       tag->offset == 0);
    
    CHECK(ApeTag_parse(tag) == 0);
    CHECK(ApeTag_free(tag) == 0);
    
    return 0;
}

int test_ApeTag_exists(void) {
    ApeTag* tag;
    FILE* file;
    
    #define TEST_EXIST(FILENAME, EXIST) \
        CHECK(file = fopen(FILENAME, "r+")); \
        CHECK(tag = ApeTag_new(file, 0)); \
        CHECK(ApeTag_exists(tag) == EXIST);
    
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

int test_ApeTag_remove(void) {
    ApeTag* tag;
    FILE* file;
    
    #define TEST_REMOVE(FILENAME, EXIST) \
        system("cp " FILENAME " " FILENAME ".0"); \
        CHECK(file = fopen(FILENAME ".0", "r+")); \
        system("rm " FILENAME ".0"); \
        CHECK(tag = ApeTag_new(file, 0)); \
        CHECK(ApeTag_remove(tag) == EXIST); \
        CHECK(ApeTag_exists(tag) == 0);
    
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
    ApeTag* tag;
    FILE* file;
    char* raw_tag = NULL;
    char* file_contents = NULL;
    
    #define TEST_RAW(FILENAME, SIZE) \
        CHECK(file = fopen(FILENAME, "r+")); \
        CHECK(tag = ApeTag_new(file, 0)); \
        CHECK(file_contents = (char *)malloc(SIZE)); \
        CHECK(SIZE == fread(file_contents, 1, SIZE, file)); \
        CHECK(ApeTag_raw(tag, &raw_tag) == 0 && bcmp(file_contents, raw_tag, SIZE) == 0);
    
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
    ApeTag* tag;
    FILE* file;
    DBT key_dbt, value_dbt;
    
    #define TEST_PARSE(FILENAME, ITEMS) \
        CHECK(file = fopen(FILENAME, "r+")); \
        CHECK(tag = ApeTag_new(file, 0)); \
        CHECK(ApeTag_parse(tag) == 0 && ITEMS == tag->item_count);
    
    #define HAS_FIELD(FIELD, KEY_LENGTH, VALUE, VALUE_LENGTH) \
        key_dbt.data = FIELD; \
        key_dbt.size = KEY_LENGTH; \
        CHECK(tag->fields->get(tag->fields, &key_dbt, &value_dbt, 0) == 0); \
        CHECK(bcmp(VALUE, (*(ApeItem **)(value_dbt.data))->value, VALUE_LENGTH) == 0); \
    
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
    ApeTag* tag;
    ApeItem* item;
    FILE* file;
    char* before;
    char* after;
    char* empty_ape_id3;
    char* example1_id3;
    char* example2_id3;
    
    #define RAW_TAGS(POINTER, FILENAME, SIZE) \
        CHECK(file = fopen(FILENAME, "r")); \
        CHECK(POINTER = (char *)malloc(SIZE)); \
        CHECK(SIZE == fread(POINTER, 1, SIZE, file)); \
        CHECK(fclose(file) == 0);
    
    #define TEST_UPDATE(FILENAME, SIZE, CHANGED, ID3) \
        system("cp " FILENAME " " FILENAME ".0"); \
        CHECK(file = fopen(FILENAME ".0", "r+")); \
        system("rm " FILENAME ".0"); \
        CHECK(before = (char *)malloc(SIZE)); \
        CHECK(SIZE == fread(before, 1, SIZE, file)); \
        CHECK(tag = ApeTag_new(file, 0)); \
        CHECK(ApeTag_parse(tag) == 0); \
        CHECK(ApeTag_update(tag) == 0); \
        CHECK(fseek(file, 0, SEEK_SET) == 0); \
        CHECK(after = (char *)malloc(tag->size+ID3)); \
        CHECK(tag->size+ID3 == fread(after, 1, tag->size+ID3, file)); \
        CHECK(bcmp(CHANGED ? empty_ape_id3 : before, after, tag->size+ID3) == 0);
        
    #define ADD_FIELD(KEY, VALUE, SIZE) \
        item = (ApeItem *)malloc(sizeof(ApeItem)); \
        item->size = SIZE; \
        item->flags = 0; \
        item->key = (char *)malloc(strlen(KEY)+1); \
        item->value = (char *)malloc(SIZE); \
        bcopy(KEY, item->key, strlen(KEY)+1); \
        bcopy(VALUE, item->value, SIZE); \
        CHECK(ApeTag_add_field(tag, item) == 0);
        
    #define CHECK_TAG(POINTER, SIZE) \
        CHECK(ApeTag_update(tag) == 0); \
        CHECK(fseek(file, 0, SEEK_SET) == 0); \
        CHECK(after = (char *)malloc(SIZE)); \
        CHECK(SIZE == fread(after, 1, SIZE, file)); \
        CHECK(bcmp(POINTER, after, SIZE) == 0);
    
    RAW_TAGS(empty_ape_id3, "empty_ape_id3.tag", 192);
    RAW_TAGS(example1_id3, "example1_id3.tag", 336);
    RAW_TAGS(example2_id3, "example2_id3.tag", 313);
    
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
    
    ApeTag_remove_field(tag, "Title");
    ApeTag_remove_field(tag, "Track");
    ADD_FIELD("Blah", "Blah", 4);
    CHECK_TAG(example2_id3, 313);
     
    #undef CHECK_TAG
    #undef ADD_FIELD
    #undef RAW_TAGS
    #undef TEST_UPDATE
    
    return 0;
}

int test_ApeTag_filesizes(void) {
    ApeTag* tag;
    FILE* file;
    int i;
    
    CHECK(file = fopen("new.tag", "w+"));
    system("rm new.tag");
    
    #define TEST_FILESIZE(SIZE) \
        CHECK(tag = ApeTag_new(file, 0)); \
        CHECK(ftruncate(fileno(tag->file), 0) == 0); \
        for(i=0; i<SIZE; i++) { \
            CHECK(1 == fwrite(" ", 1, 1, file)); \
        } \
        CHECK(ApeTag_exists(tag) == 0);
    
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
    FILE* file;
    ApeTag* tag;
    ApeItem item;
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
    CHECK_VALIDITY(-3);
    item.flags = 0;
    
    /* Check invalid keys */
    CHECK_VALIDITY(0);
    item.key="";
    CHECK_VALIDITY(-3);
    item.key="a";
    CHECK_VALIDITY(-3);
    item.key="aa";
    CHECK_VALIDITY(0);
    item.key="tag";
    CHECK_VALIDITY(-3);
    item.key="oggs";
    CHECK_VALIDITY(-3);
    item.key="MP+";
    CHECK_VALIDITY(-3);
    item.key="ID3";
    CHECK_VALIDITY(-3);
    item.key=(char *)malloc(260);
    bcopy("TAGS", item.key, 5);
    CHECK_VALIDITY(0);
    for(i=0; i < 0x20; i++) {
        *(item.key+3) = (char)i;
        CHECK_VALIDITY(-3);
    }
    for(i=0xff; i >= 0x80; i--) {
        *(item.key+3) = (char)i;
        CHECK_VALIDITY(-3);
    }
    for(i=0; i<9; i++) {
        bcopy("qwertyuiopasdfghjklzxcvbnm", item.key+(26*i), 27);
        CHECK_VALIDITY(0);
    }
    bcopy("qwertyuiopasdfghjklzxcvbnm", item.key+234, 21);
    CHECK_VALIDITY(0);
    bcopy("qwertyuiopasdfghjklzxcvbnm", item.key+235, 21);
    CHECK_VALIDITY(-3);
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
    CHECK_VALIDITY(-3);
    /* Bad UTF8 */
    item.value="ab\274\285";
    CHECK_VALIDITY(-3);
    /* Binary means non-UTF8 is ok */
    item.flags = (item.flags & APE_ITEM_TYPE_FLAGS) + APE_ITEM_BINARY;
    CHECK_VALIDITY(0);
    
    #undef CHECK_VALIDITY
    
    return 0;
}

int test_bad_tags(void) {
    ApeTag* tag;
    FILE* empty;
    FILE* example1;
    char* empty_raw;
    char* example1_raw;
    char c;
    int i;
    
    #define OPEN_FILE(FILE, RAW, FILENAME) \
        system("cp " FILENAME " " FILENAME ".0"); \
        CHECK(FILE = fopen(FILENAME ".0", "r+")); \
        system("rm " FILENAME ".0"); \
        CHECK(tag = ApeTag_new(FILE, 0)); \
        CHECK(ApeTag_parse(tag) == 0); \
        CHECK(ApeTag_raw(tag, &RAW) == 0);
    
    #define WRITE_BYTES(FILE, OFFSET, VALUE, LENGTH) \
        CHECK(fseek(FILE, OFFSET, SEEK_SET) == 0); \
        CHECK(LENGTH == fwrite(VALUE, 1, LENGTH, FILE));
        
    #define RESET_FILE(FILE, RAW, LENGTH, PADDING) \
        CHECK(fseek(FILE, 0, SEEK_SET) == 0); \
        for(i = 0; i < PADDING; i++){ \
            CHECK(1 == fwrite(" ", 1, 1, FILE)); \
        } \
        CHECK(LENGTH == fwrite(RAW, 1, LENGTH, FILE)); \
        CHECK(ftruncate(fileno(FILE), LENGTH) == 0);
        
    #define CHECK_PARSE(FILE, VALUE) \
        CHECK(tag = ApeTag_new(FILE, 0)); \
        CHECK(ApeTag_parse(tag) == VALUE); \
        CHECK(ApeTag_free(tag) == 0);
    
    /* Open files check good parse */
    OPEN_FILE(empty, empty_raw, "empty_ape_id3.tag");
    CHECK_PARSE(empty, 0);
    OPEN_FILE(example1, example1_raw, "example1_id3.tag");
    CHECK_PARSE(example1, 0);

    /* Check works with read only flag, but not other flags */
    WRITE_BYTES(empty, 20, "\1", 1);
    CHECK_PARSE(empty, 0);
    for(c=255;c>1;c--) {
        WRITE_BYTES(empty, 20, &c, 1);
        CHECK_PARSE(empty, -3);
    } 
    WRITE_BYTES(empty, 20, "\1", 1);
    WRITE_BYTES(empty, 52, "\1", 1);
    CHECK_PARSE(empty, 0);
    for(c=255;c>1;c--) {
        WRITE_BYTES(empty, 52, &c, 1);
        CHECK_PARSE(empty, -3);
        WRITE_BYTES(empty, 20, &c, 1);
        CHECK_PARSE(empty, -3);
    } 
    WRITE_BYTES(empty, 20, "\1", 1);
    WRITE_BYTES(empty, 52, "\1", 1);
    CHECK_PARSE(empty, 0);

    /* Test footer size < minimum size*/
    WRITE_BYTES(empty, 44, "\37", 1);
    CHECK_PARSE(empty, -3);
    WRITE_BYTES(empty, 44, "\0", 1);
    CHECK_PARSE(empty, -3);
    
    /* Test footer size > 8192 (APE_MAXIMUM_TAG_SIZE) */
    WRITE_BYTES(empty, 44, "\341\37", 2);
    CHECK_PARSE(empty, -3);
    /* Check even when it isn't large than file */
    RESET_FILE(empty, empty_raw, 192, 8192);
    WRITE_BYTES(empty, 8192+44, "\341\37", 2);
    CHECK_PARSE(empty, -3);
    
    RESET_FILE(empty, empty_raw, 192, 0);
    /* Check unmatched header and footer, with header size wrong */
    WRITE_BYTES(empty, 12, "\41", 1);
    CHECK_PARSE(empty, -3);
    /* Check matched header and footer size, both wrong */
    WRITE_BYTES(empty, 44, "\41", 1);
    CHECK_PARSE(empty, -3);
    /* Check unmatched header and footer, with footer size wrong */
    WRITE_BYTES(empty, 12, "\40", 1);
    CHECK_PARSE(empty, -3);
    /* Check unmatched header and footer, with footer size wrong,
       not larger than file */
    RESET_FILE(empty, empty_raw, 192, 1);
    WRITE_BYTES(empty, 45, "\41", 1);
    CHECK_PARSE(empty, -3);
    
    /* Check item count greater than 64 (APE_MAXIMUM_ITEM_COUNT) */
    RESET_FILE(empty, empty_raw, 192, 0);
    WRITE_BYTES(empty, 48, "\101", 1);
    CHECK_PARSE(empty, -3);
    /* Check item count greater than possible given size */
    WRITE_BYTES(empty, 48, "\1", 1);
    CHECK_PARSE(empty, -3);
    /* Check unmatched header and footer item count, header wrong */
    WRITE_BYTES(empty, 48, "\0", 1);
    WRITE_BYTES(empty, 16, "\1", 1);
    CHECK_PARSE(empty, -3);
    /* Check unmatched header and footer item count, footer wrong */
    WRITE_BYTES(example1, 48, "\1", 1);
    CHECK_PARSE(example1, -3);
    
    /* Check missing/corrupt header */
    RESET_FILE(empty, empty_raw, 192, 0);
    WRITE_BYTES(empty, 0, "\0", 1);
    CHECK_PARSE(empty, -3);
    
    /* Check parsing bad first item size */
    RESET_FILE(example1, example1_raw, 336, 0);
    WRITE_BYTES(example1, 32, "\2", 1);
    CHECK_PARSE(example1, -3);
    
    /* Check parsing bad first item invalid key */
    RESET_FILE(example1, example1_raw, 336, 0);
    WRITE_BYTES(example1, 40, "\0", 1);
    CHECK_PARSE(example1, -3);
    
    /* Check parsing bad first item key end */
    RESET_FILE(example1, example1_raw, 336, 0);
    WRITE_BYTES(example1, 45, "\1", 1);
    CHECK_PARSE(example1, -3);
    
    /* Check parsing bad second item length too long */
    RESET_FILE(example1, example1_raw, 336, 0);
    WRITE_BYTES(example1, 47, "\377", 1);
    CHECK_PARSE(example1, -3);
    
    /* Check parsing case insensitive duplicate keys */
    RESET_FILE(example1, example1_raw, 336, 0);
    WRITE_BYTES(example1, 40, "Album", 5);
    CHECK_PARSE(example1, -3);
    WRITE_BYTES(example1, 40, "album", 5);
    CHECK_PARSE(example1, -3);
    WRITE_BYTES(example1, 40, "ALBUM", 5);
    CHECK_PARSE(example1, -3);
    
    /* Check parsing incorrect item counts */
    RESET_FILE(example1, example1_raw, 336, 0);
    WRITE_BYTES(example1, 16, "\5", 1);
    WRITE_BYTES(example1, 192, "\5", 1);
    CHECK_PARSE(example1, -3);
    WRITE_BYTES(example1, 16, "\7", 1);
    WRITE_BYTES(example1, 192, "\7", 1);
    CHECK_PARSE(example1, -3);
    
    #undef CHECK_PARSE
    #undef RESET_FILE
    #undef WRITE_BYTE
    #undef OPEN_FILE
    
    return 0;
}

int test_ApeTag_add_remove_clear_fields_update(void) {
    ApeTag* tag;
    FILE* file;
    ApeItem* item;
    int i;
    
    system("cp example1_id3.tag example1_id3.tag.0");
    CHECK(file = fopen("example1_id3.tag.0", "r+"));
    system("rm example1_id3.tag.0");
        
    /* Test functions before parsing */
    CHECK(tag = ApeTag_new(file, 0));
    CHECK(ApeTag_clear_fields(tag) == 0);
    CHECK(item = (ApeItem *)malloc(sizeof(ApeItem)));
    item->size = 5;
    item->flags = 0;
    CHECK(item->key = (char *)malloc(6));
    CHECK(item->value = (char *)malloc(5));
    bcopy("ALBUM", item->key, 6);
    bcopy("VALUE", item->value, 5);
    CHECK(ApeTag_add_field(tag, item) == 0);
    CHECK(ApeTag_remove_field(tag, "track") == 1);
    CHECK(ApeTag_clear_fields(tag) == 0);
    CHECK(ApeTag_parse(tag) == 0);
    
    /* Test after parsing */
    CHECK(tag = ApeTag_new(file, 0));
    CHECK(ApeTag_parse(tag) == 0);
    CHECK(ApeTag_remove_field(tag, "track") == 0);
    
    /* Check add duplicate key */
    CHECK(item = (ApeItem *)malloc(sizeof(ApeItem)));
    CHECK(item->key = (char *)malloc(6));
    CHECK(item->value = (char *)malloc(5));
    item->size = 5;
    item->flags = 0;
    bcopy("ALBUM", item->key, 6);
    bcopy("VALUE", item->value, 5);
    CHECK(ApeTag_add_field(tag, item) == -3);
    bcopy("album", item->key, 6);
    CHECK(ApeTag_add_field(tag, item) == -3);
    
    /* Check adding more fields than allowed */
    CHECK(ApeTag_clear_fields(tag) == 0);
    for(i=0; i < 64; i++) {
        CHECK(item = (ApeItem *)malloc(sizeof(ApeItem)));
        CHECK(item->key = (char *)malloc(6));
        CHECK(item->value = (char *)malloc(3));
        item->size = 2;
        item->flags = 0;
        snprintf(item->key, 6, "Key%02i", i);
        snprintf(item->value, 3, "%02i", i);
        CHECK(ApeTag_add_field(tag, item) == 0);
    }
    CHECK(item = (ApeItem *)malloc(sizeof(ApeItem)));
    CHECK(item->key = (char *)malloc(6));
    CHECK(item->value = (char *)malloc(2));
    item->size = 2;
    item->flags = 0;
    snprintf(item->key, 6, "Key65");
    snprintf(item->value, 2, "65");
    CHECK(ApeTag_add_field(tag, item) == -3);
    
    /* Check updating with too large tag allowed */
    CHECK(tag = ApeTag_new(file, 0));
    CHECK(ApeTag_exists(tag) == 1);
    CHECK(item = (ApeItem *)malloc(sizeof(ApeItem)));
    CHECK(item->key = (char *)malloc(9));
    CHECK(item->value = (char *)malloc(8112));
    item->size = 8112;
    item->flags = 0;
    bcopy("Too Big!", item->key, 9);
    for(i=0; i < 507; i++) {
        bcopy("0123456789abcdef", item->value+i*16, 16);
    }
    CHECK(ApeTag_add_field(tag, item) == 0);
    CHECK(ApeTag_update(tag) == -3);
    /* Check fits perfectly*/
    item->size = 8111;
    CHECK(ApeTag_update(tag) == 0);
    
    return 0;
}

int test_no_id3(void) {
    ApeTag* tag;
    FILE* file;
    char* file_contents;
    char* raw;
    
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
        CHECK(0 == ID3_LENGTH(tag)); \
        if(NO_ID3_FLAGS & APE_HAS_APE) { \
            CHECK(0 == fseek(file, 0, SEEK_SET)); \
            CHECK(file_contents = (char*)malloc(tag->size)); \
            CHECK(raw = (char*)malloc(tag->size)); \
            CHECK(tag->size == fread(file_contents, 1, tag->size, file)); \
            CHECK(0 == ApeTag_raw(tag, &raw)); \
            CHECK(0 == bcmp(file_contents, raw, tag->size)); \
            CHECK(0 == ApeTag_parse(tag)); \
            CHECK(0 == ApeTag_update(tag)); \
            CHECK(0 == fseek(file, 0, SEEK_END)); \
            CHECK(tag->size == (u_int32_t)ftell(file)); \
            CHECK(0 == fseek(file, 0, SEEK_SET)); \
            CHECK(tag->size == fread(raw, 1, tag->size, file)); \
            CHECK(0 == bcmp(file_contents, raw, tag->size)); \
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
    
    for(i=1; i <= 255; i++) {
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
    
    for(i=0; i<10; i++) {
        bzero(s, 4);
        s[0] = '0' + i;
        CHECK(i == ApeItem__parse_track(1, s));
        for(j=0; j<10; j++) {
            s[1] = '0' + j;
            CHECK(j+10*i == ApeItem__parse_track(2, s));
            for(k=0; k<10; k++) {
                s[2] = '0' + k;
                if(i > 2 || (i == 2 && (j > 5 || (j == 5 && k > 5)))) {
                    CHECK(0 == ApeItem__parse_track(3, s));
                } else {
                    CHECK(k+10*j+100*i == ApeItem__parse_track(3, s));
                }
                if(k+10*j+100*i < '0' || k+10*j+100*i > '9') {
                    s[2] = k+10*j+100*i;
                    CHECK(0 == ApeItem__parse_track(3, s+2));
                }
            }
        }
    }
    
    return 0;
}

int test_ApeItem__compare(void) {
    ApeItem a, b;
    const ApeItem *pa = &a, *pb = &b;
    
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
    ApeTag tag;
    DBT key_dbt;
    char genre_id;

    #define LOOKUP_GENRE(GENRE, LENGTH, VALUE) \
        key_dbt.data = GENRE; \
        key_dbt.size = LENGTH; \
        CHECK(ApeTag__lookup_genre(&tag, &key_dbt, &genre_id) == 0); \
        CHECK(VALUE == genre_id);
    
    LOOKUP_GENRE("Blues", 5, '\0');
    LOOKUP_GENRE("Classic Rock", 12, '\1');
    LOOKUP_GENRE("Country", 7, '\2');
    LOOKUP_GENRE("Dance", 5, '\3');
    LOOKUP_GENRE("Disco", 5, '\4');
    LOOKUP_GENRE("Funk", 4, '\5');
    LOOKUP_GENRE("Grunge", 6, '\6');
    LOOKUP_GENRE("Hip-Hop", 7, '\7');
    LOOKUP_GENRE("Jazz", 4, '\10');
    LOOKUP_GENRE("Metal", 5, '\11');
    LOOKUP_GENRE("New Age", 7, '\12');
    LOOKUP_GENRE("Oldies", 6, '\13');
    LOOKUP_GENRE("Other", 5, '\14');
    LOOKUP_GENRE("Pop", 3, '\15');
    LOOKUP_GENRE("R & B", 5, '\16');
    LOOKUP_GENRE("Rap", 3, '\17');
    LOOKUP_GENRE("Reggae", 6, '\20');
    LOOKUP_GENRE("Rock", 4, '\21');
    LOOKUP_GENRE("Techno", 6, '\22');
    LOOKUP_GENRE("Industrial", 10, '\23');
    LOOKUP_GENRE("Alternative", 11, '\24');
    LOOKUP_GENRE("Ska", 3, '\25');
    LOOKUP_GENRE("Death Metal", 11, '\26');
    LOOKUP_GENRE("Prank", 5, '\27');
    LOOKUP_GENRE("Soundtrack", 10, '\30');
    LOOKUP_GENRE("Euro-Techno", 11, '\31');
    LOOKUP_GENRE("Ambient", 7, '\32');
    LOOKUP_GENRE("Trip-Hop", 8, '\33');
    LOOKUP_GENRE("Vocal", 5, '\34');
    LOOKUP_GENRE("Jazz + Funk", 11, '\35');
    LOOKUP_GENRE("Fusion", 6, '\36');
    LOOKUP_GENRE("Trance", 6, '\37');
    LOOKUP_GENRE("Classical", 9, '\40');
    LOOKUP_GENRE("Instrumental", 12, '\41');
    LOOKUP_GENRE("Acid", 4, '\42');
    LOOKUP_GENRE("House", 5, '\43');
    LOOKUP_GENRE("Game", 4, '\44');
    LOOKUP_GENRE("Sound Clip", 10, '\45');
    LOOKUP_GENRE("Gospel", 6, '\46');
    LOOKUP_GENRE("Noise", 5, '\47');
    LOOKUP_GENRE("Alternative Rock", 16, '\50');
    LOOKUP_GENRE("Bass", 4, '\51');
    LOOKUP_GENRE("Soul", 4, '\52');
    LOOKUP_GENRE("Punk", 4, '\53');
    LOOKUP_GENRE("Space", 5, '\54');
    LOOKUP_GENRE("Meditative", 10, '\55');
    LOOKUP_GENRE("Instrumental Pop", 16, '\56');
    LOOKUP_GENRE("Instrumental Rock", 17, '\57');
    LOOKUP_GENRE("Ethnic", 6, '\60');
    LOOKUP_GENRE("Gothic", 6, '\61');
    LOOKUP_GENRE("Darkwave", 8, '\62');
    LOOKUP_GENRE("Techno-Industrial", 17, '\63');
    LOOKUP_GENRE("Electronic", 10, '\64');
    LOOKUP_GENRE("Pop-Fol", 7, '\65');
    LOOKUP_GENRE("Eurodance", 9, '\66');
    LOOKUP_GENRE("Dream", 5, '\67');
    LOOKUP_GENRE("Southern Rock", 13, '\70');
    LOOKUP_GENRE("Comedy", 6, '\71');
    LOOKUP_GENRE("Cult", 4, '\72');
    LOOKUP_GENRE("Gangsta", 7, '\73');
    LOOKUP_GENRE("Top 40", 6, '\74');
    LOOKUP_GENRE("Christian Rap", 13, '\75');
    LOOKUP_GENRE("Pop/Funk", 8, '\76');
    LOOKUP_GENRE("Jungle", 6, '\77');
    LOOKUP_GENRE("Native US", 9, '\100');
    LOOKUP_GENRE("Cabaret", 7, '\101');
    LOOKUP_GENRE("New Wave", 8, '\102');
    LOOKUP_GENRE("Psychadelic", 11, '\103');
    LOOKUP_GENRE("Rave", 4, '\104');
    LOOKUP_GENRE("Showtunes", 9, '\105');
    LOOKUP_GENRE("Trailer", 7, '\106');
    LOOKUP_GENRE("Lo-Fi", 5, '\107');
    LOOKUP_GENRE("Tribal", 6, '\110');
    LOOKUP_GENRE("Acid Punk", 9, '\111');
    LOOKUP_GENRE("Acid Jazz", 9, '\112');
    LOOKUP_GENRE("Polka", 5, '\113');
    LOOKUP_GENRE("Retro", 5, '\114');
    LOOKUP_GENRE("Musical", 7, '\115');
    LOOKUP_GENRE("Rock & Roll", 11, '\116');
    LOOKUP_GENRE("Hard Rock", 9, '\117');
    LOOKUP_GENRE("Folk", 4, '\120');
    LOOKUP_GENRE("Folk-Rock", 9, '\121');
    LOOKUP_GENRE("National Folk", 13, '\122');
    LOOKUP_GENRE("Swing", 5, '\123');
    LOOKUP_GENRE("Fast Fusion", 11, '\124');
    LOOKUP_GENRE("Bebop", 5, '\125');
    LOOKUP_GENRE("Latin", 5, '\126');
    LOOKUP_GENRE("Revival", 7, '\127');
    LOOKUP_GENRE("Celtic", 6, '\130');
    LOOKUP_GENRE("Bluegrass", 9, '\131');
    LOOKUP_GENRE("Avantgarde", 10, '\132');
    LOOKUP_GENRE("Gothic Rock", 11, '\133');
    LOOKUP_GENRE("Progressive Rock", 16, '\134');
    LOOKUP_GENRE("Psychedelic Rock", 16, '\135');
    LOOKUP_GENRE("Symphonic Rock", 14, '\136');
    LOOKUP_GENRE("Slow Rock", 9, '\137');
    LOOKUP_GENRE("Big Band", 8, '\140');
    LOOKUP_GENRE("Chorus", 6, '\141');
    LOOKUP_GENRE("Easy Listening", 14, '\142');
    LOOKUP_GENRE("Acoustic", 8, '\143');
    LOOKUP_GENRE("Humour", 6, '\144');
    LOOKUP_GENRE("Speech", 6, '\145');
    LOOKUP_GENRE("Chanson", 7, '\146');
    LOOKUP_GENRE("Opera", 5, '\147');
    LOOKUP_GENRE("Chamber Music", 13, '\150');
    LOOKUP_GENRE("Sonata", 6, '\151');
    LOOKUP_GENRE("Symphony", 8, '\152');
    LOOKUP_GENRE("Booty Bass", 10, '\153');
    LOOKUP_GENRE("Primus", 6, '\154');
    LOOKUP_GENRE("Porn Groove", 11, '\155');
    LOOKUP_GENRE("Satire", 6, '\156');
    LOOKUP_GENRE("Slow Jam", 8, '\157');
    LOOKUP_GENRE("Club", 4, '\160');
    LOOKUP_GENRE("Tango", 5, '\161');
    LOOKUP_GENRE("Samba", 5, '\162');
    LOOKUP_GENRE("Folklore", 8, '\163');
    LOOKUP_GENRE("Ballad", 6, '\164');
    LOOKUP_GENRE("Power Ballad", 12, '\165');
    LOOKUP_GENRE("Rhytmic Soul", 12, '\166');
    LOOKUP_GENRE("Freestyle", 9, '\167');
    LOOKUP_GENRE("Duet", 4, '\170');
    LOOKUP_GENRE("Punk Rock", 9, '\171');
    LOOKUP_GENRE("Drum Solo", 9, '\172');
    LOOKUP_GENRE("Acapella", 8, '\173');
    LOOKUP_GENRE("Euro-House", 10, '\174');
    LOOKUP_GENRE("Dance Hall", 10, '\175');
    LOOKUP_GENRE("Goa", 3, '\176');
    LOOKUP_GENRE("Drum & Bass", 11, '\177');
    LOOKUP_GENRE("Club-House", 10, '\200');
    LOOKUP_GENRE("Hardcore", 8, '\201');
    LOOKUP_GENRE("Terror", 6, '\202');
    LOOKUP_GENRE("Indie", 5, '\203');
    LOOKUP_GENRE("BritPop", 7, '\204');
    LOOKUP_GENRE("Negerpunk", 9, '\205');
    LOOKUP_GENRE("Polsk Punk", 10, '\206');
    LOOKUP_GENRE("Beat", 4, '\207');
    LOOKUP_GENRE("Christian Gangsta Rap", 21, '\210');
    LOOKUP_GENRE("Heavy Metal", 11, '\211');
    LOOKUP_GENRE("Black Metal", 11, '\212');
    LOOKUP_GENRE("Crossover", 9, '\213');
    LOOKUP_GENRE("Contemporary Christian", 22, '\214');
    LOOKUP_GENRE("Christian Rock", 14, '\215');
    LOOKUP_GENRE("Merengue", 8, '\216');
    LOOKUP_GENRE("Salsa", 5, '\217');
    LOOKUP_GENRE("Trash Meta", 10, '\220');
    LOOKUP_GENRE("Anime", 5, '\221');
    LOOKUP_GENRE("Jpop", 4, '\222');
    LOOKUP_GENRE("Synthpop", 8, '\223');
    
    #undef LOOKUP_GENRE
    
    return 0;
}
