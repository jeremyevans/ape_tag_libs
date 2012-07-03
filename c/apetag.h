#ifndef _APETAG_H_
#define _APETAG_H_

#include <sys/types.h>
#include <stdio.h>

/* Specify not to check for or write an ID3 tag */
#define APE_NO_ID3             1 << 5

/* Mask used for ApeItem flags for read-only value */
#define APE_ITEM_READ_FLAGS    1

#define APE_ITEM_READ_WRITE    0
#define APE_ITEM_READ_ONLY     1

/* Mask used for ApeItem flags for type value */
#define APE_ITEM_TYPE_FLAGS    6

#define APE_ITEM_UTF8          0
#define APE_ITEM_BINARY        2
#define APE_ITEM_EXTERNAL      4
#define APE_ITEM_RESERVED      6

/* Structures */

typedef struct {
    uint32_t size;        /* Size of the value */
    uint32_t flags;       /* Flags on the item */
    char* key;            /* NULL-terminated string */
    char* value;          /* Unterminated string */
} ApeItem;

/* Opaque Structure */

struct sApeTag; 
typedef struct sApeTag* ApeTag;

/* Public functions */

ApeTag ApeTag_new(FILE* file, uint32_t flags);
int ApeTag_free(ApeTag tag);

int ApeTag_exists(ApeTag tag);
int ApeTag_exists_id3(ApeTag tag);
int ApeTag_remove(ApeTag tag);
int ApeTag_raw(ApeTag tag, char** raw);
int ApeTag_parse(ApeTag tag);

int ApeTag_add_field(ApeTag tag, ApeItem* item);
int ApeTag_remove_field(ApeTag tag, const char* key);
int ApeTag_clear_fields(ApeTag tag);
int ApeTag_update(ApeTag tag);

int ApeTag_get_field(ApeTag tag, const char *key, ApeItem **item);
int ApeTag_get_fields(ApeTag tag, ApeItem ***items);
uint32_t ApeTag_size(ApeTag tag);
uint32_t ApeTag_item_count(ApeTag tag);
const char* ApeTag_error(ApeTag tag);

/* Override default (very strict) limits */
void ApeTag_set_max_size(uint32_t size);
void ApeTag_set_max_item_count(uint32_t item_count);

#endif /* !_APETAG_H_ */
