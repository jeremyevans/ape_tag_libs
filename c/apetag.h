#ifndef _APETAG_H_
#define _APETAG_H_

#include <sys/types.h>
#include <stdint.h>
#include <stdio.h>

/* Specify not to check for or write an ID3 tag */
#define APE_NO_ID3             1 << 5

/* Mask used for struct ApeItem flags for read-only value */
#define APE_ITEM_READ_FLAGS    1

#define APE_ITEM_READ_WRITE    0
#define APE_ITEM_READ_ONLY     1

/* Mask used for struct ApeItem flags for type value */
#define APE_ITEM_TYPE_FLAGS    6

#define APE_ITEM_UTF8          0
#define APE_ITEM_BINARY        2
#define APE_ITEM_EXTERNAL      4
#define APE_ITEM_RESERVED      6

/* Opaque structure used for tag internals */

struct ApeTag; 

/* Public structure for individual items in tag */

struct ApeItem {
    uint32_t size;        /* Size of the value */
    uint32_t flags;       /* Flags on the item */
    char *key;            /* NULL-terminated string */
    char *value;          /* Unterminated string */
};

/* Possible error types for the library */

enum ApeTag_errcode {
    APETAG_NOERR = 0,
    APETAG_FILEERR,
    APETAG_MEMERR,
    APETAG_INTERNALERR,
    APETAG_LIMITEXCEEDED,
    APETAG_DUPLICATEITEM,
    APETAG_CORRUPTTAG,
    APETAG_INVALIDITEM,
    APETAG_ARGERR,
    APETAG_NOTPRESENT,
};

/* Public functions */

struct ApeTag * ApeTag_new(FILE *file, uint32_t flags);
int ApeTag_free(struct ApeTag *tag);

int ApeTag_exists(struct ApeTag *tag);
int ApeTag_exists_id3(struct ApeTag *tag);
int ApeTag_remove(struct ApeTag *tag);
int ApeTag_raw(struct ApeTag *tag, char **raw, uint32_t *raw_size);
int ApeTag_parse(struct ApeTag *tag);

int ApeTag_add_item(struct ApeTag *tag, struct ApeItem *item);
int ApeTag_replace_item(struct ApeTag *tag, struct ApeItem *item);
int ApeTag_remove_item(struct ApeTag *tag, const char *key);
int ApeTag_clear_items(struct ApeTag *tag);
int ApeTag_update(struct ApeTag *tag);

struct ApeItem * ApeTag_get_item(struct ApeTag *tag, const char *key);
struct ApeItem ** ApeTag_get_items(struct ApeTag *tag, uint32_t *item_count);
uint32_t ApeTag_size(struct ApeTag *tag);
uint32_t ApeTag_item_count(struct ApeTag *tag);
uint32_t ApeTag_file_item_count(struct ApeTag *tag);
const char * ApeTag_error(struct ApeTag *tag);
enum ApeTag_errcode ApeTag_error_code(struct ApeTag *tag);

int ApeTag_mt_init(void);

/* Get/set library limits */
size_t ApeTag_get_max_size(void);
size_t ApeTag_get_max_item_count(void);
void ApeTag_set_max_size(uint32_t size);
void ApeTag_set_max_item_count(uint32_t item_count);

#endif /* !_APETAG_H_ */
