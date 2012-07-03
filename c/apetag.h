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

#define APE_PREAMBLE "APETAGEX\320\07\0\0"
#define APE_HEADER_FLAGS "\0\0\240"
#define APE_FOOTER_FLAGS "\0\0\200"

#define ID3_LENGTH(TAG) (u_int32_t)(((TAG->flags & APE_HAS_ID3) && \
                                    !(TAG->flags & APE_NO_ID3)) ? 128 : 0)
#define TAG_LENGTH(TAG) (tag->size + ID3_LENGTH(TAG))

/* Structures */

typedef struct {
    u_int32_t size;        /* Size of the value */
    u_int32_t flags;       /* Flags on the item */
    char* key;             /* NULL-terminated string */
    char* value;           /* Unterminated string */
} ApeItem;
typedef const ApeItem* ApeItem_CP; /* Only needed to avoid cast warnings */

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
    u_int32_t flags;      /* Internal tag flags */
    u_int32_t size;       /* On disk size in bytes */
    u_int32_t item_count; /* On disk item count */
    u_int32_t num_fields; /* In database item count */
    off_t offset;          /* Start of tag in file */
} ApeTag;

/* Public functions */

ApeTag* ApeTag_new(FILE* file, u_int32_t flags);
int ApeTag_free(ApeTag* tag);

int ApeTag_exists(ApeTag* tag);
int ApeTag_remove(ApeTag* tag);
int ApeTag_raw(ApeTag* tag, char** raw);
int ApeTag_parse(ApeTag* tag);
int ApeTag_update(ApeTag* tag);

int ApeTag_add_field(ApeTag* tag, ApeItem* item);
int ApeTag_remove_field(ApeTag* tag, char* key);
int ApeTag_clear_fields(ApeTag* tag);

void ApeTag_set_max_size(u_int32_t size);
void ApeTag_set_max_item_count(u_int32_t item_count);

#endif /* !_APETAG_H_ */
