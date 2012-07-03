#ifndef _APETAG_H_
#define _APETAG_H_

#include <sys/types.h>
#include <stdio.h>

#ifdef USE_DB_185
#include <db_185.h>
#else
#include <db.h>
#endif

#define APE_DEFAULT_FLAGS      0
#define APE_CHECKED_APE        1 << 0
#define APE_CHECKED_OFFSET     1 << 1
#define APE_CHECKED_FIELDS     1 << 2
#define APE_HAS_APE            1 << 3
#define APE_HAS_ID3            1 << 4
#define APE_NO_ID3             1 << 5

#define APE_ITEM_READ_FLAGS    1
#define APE_ITEM_READ_WRITE    0
#define APE_ITEM_READ_ONLY     1

#define APE_ITEM_TYPE_FLAGS    6
#define APE_ITEM_UTF8          0
#define APE_ITEM_BINARY        2
#define APE_ITEM_EXTERNAL      4
#define APE_ITEM_RESERVED      6

/* Structures */

typedef struct {
    uint32_t size;        /* Size of the value */
    uint32_t flags;       /* Flags on the item */
    char* key;             /* NULL-terminated string */
    char* value;           /* Unterminated string */
} ApeItem;

typedef struct {
    FILE* file;           /* file containing tag */
    DB* fields;           /* DB_HASH format database */
                          /* Keys are NULL-terminated */
                          /* Values are ApeItem** */
    char* tag_header;     /* Tag Header data */
    char* tag_data;       /* Tag body data */
    char* tag_footer;     /* Tag footer data */
    char* id3;            /* ID3 data, if any */
    char* error;          /* String for last error */
    uint32_t flags;      /* Internal tag flags */
    uint32_t size;       /* On disk size in bytes */
    uint32_t item_count; /* On disk item count */
    uint32_t num_fields; /* In database item count */
    off_t offset;          /* Start of tag in file */
} ApeTag;

/* Public functions */

ApeTag* ApeTag_new(FILE* file, uint32_t flags);
int ApeTag_free(ApeTag* tag);

int ApeTag_exists(ApeTag* tag);
int ApeTag_remove(ApeTag* tag);
int ApeTag_raw(ApeTag* tag, char** raw);
int ApeTag_parse(ApeTag* tag);
int ApeTag_update(ApeTag* tag);

int ApeTag_add_field(ApeTag* tag, ApeItem* item);
int ApeTag_remove_field(ApeTag* tag, const char* key);
int ApeTag_clear_fields(ApeTag* tag);

void ApeTag_set_max_size(uint32_t size);
void ApeTag_set_max_item_count(uint32_t item_count);

#endif /* !_APETAG_H_ */
