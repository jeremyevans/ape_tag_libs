#include "apetag.h"
#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#ifdef USE_DB_185
#include <db_185.h>
#else
#include <db.h>
#endif

/* Macros */

#define APE_DEFAULT_FLAGS      0
#define APE_CHECKED_APE        1 << 0
#define APE_CHECKED_OFFSET     1 << 1
#define APE_CHECKED_FIELDS     1 << 2
#define APE_HAS_APE            1 << 3
#define APE_HAS_ID3            1 << 4

#define APE_PREAMBLE "APETAGEX\320\07\0\0"
#define APE_HEADER_FLAGS "\0\0\240"
#define APE_FOOTER_FLAGS "\0\0\200"

/* True minimum values */
#define APE_MINIMUM_TAG_SIZE   64
#define APE_ITEM_MINIMUM_SIZE  11

/* Determine endianness */
#ifndef IS_BIG_ENDIAN
#ifdef _BYTE_ORDER
#ifdef _BIG_ENDIAN
#if _BYTE_ORDER == _BIG_ENDIAN
#define IS_BIG_ENDIAN 1
#endif
#endif
#else
#ifdef __BYTE_ORDER
#ifdef __BIG_ENDIAN
#if __BYTE_ORDER == __BIG_ENDIAN
#define IS_BIG_ENDIAN 1
#endif
#endif
#endif
#endif
#endif
/* From OpenBSD */
#ifdef IS_BIG_ENDIAN
#define SWAPEND32(x) \
    (uint32_t)(((uint32_t)(x) & 0xff) << 24 | \
    ((uint32_t)(x) & 0xff00) << 8 | \
    ((uint32_t)(x) & 0xff0000) >> 8 | \
    ((uint32_t)(x) & 0xff000000) >> 24)
#define H2LE32(X) SWAPEND32(X) 
#define LE2H32(X) SWAPEND32(X) 
#else
#define H2LE32(X) (X)
#define LE2H32(X) (X)
#endif

/* Global Variables */

static DB *ID3_GENRES = NULL;
static uint32_t APE_MAXIMUM_TAG_SIZE = 8192;
static uint32_t APE_MAXIMUM_ITEM_COUNT = 64;

static const unsigned char charmap[] = {
    '\000', '\001', '\002', '\003', '\004', '\005', '\006', '\007',
    '\010', '\011', '\012', '\013', '\014', '\015', '\016', '\017',
    '\020', '\021', '\022', '\023', '\024', '\025', '\026', '\027',
    '\030', '\031', '\032', '\033', '\034', '\035', '\036', '\037',
    '\040', '\041', '\042', '\043', '\044', '\045', '\046', '\047',
    '\050', '\051', '\052', '\053', '\054', '\055', '\056', '\057',
    '\060', '\061', '\062', '\063', '\064', '\065', '\066', '\067',
    '\070', '\071', '\072', '\073', '\074', '\075', '\076', '\077',
    '\100', '\141', '\142', '\143', '\144', '\145', '\146', '\147',
    '\150', '\151', '\152', '\153', '\154', '\155', '\156', '\157',
    '\160', '\161', '\162', '\163', '\164', '\165', '\166', '\167',
    '\170', '\171', '\172', '\133', '\134', '\135', '\136', '\137',
    '\140', '\141', '\142', '\143', '\144', '\145', '\146', '\147',
    '\150', '\151', '\152', '\153', '\154', '\155', '\156', '\157',
    '\160', '\161', '\162', '\163', '\164', '\165', '\166', '\167',
    '\170', '\171', '\172', '\173', '\174', '\175', '\176', '\177',
    '\200', '\201', '\202', '\203', '\204', '\205', '\206', '\207',
    '\210', '\211', '\212', '\213', '\214', '\215', '\216', '\217',
    '\220', '\221', '\222', '\223', '\224', '\225', '\226', '\227',
    '\230', '\231', '\232', '\233', '\234', '\235', '\236', '\237',
    '\240', '\241', '\242', '\243', '\244', '\245', '\246', '\247',
    '\250', '\251', '\252', '\253', '\254', '\255', '\256', '\257',
    '\260', '\261', '\262', '\263', '\264', '\265', '\266', '\267',
    '\270', '\271', '\272', '\273', '\274', '\275', '\276', '\277',
    '\300', '\301', '\302', '\303', '\304', '\305', '\306', '\307',
    '\310', '\311', '\312', '\313', '\314', '\315', '\316', '\317',
    '\320', '\321', '\322', '\323', '\324', '\325', '\326', '\327',
    '\330', '\331', '\332', '\333', '\334', '\335', '\336', '\337',
    '\340', '\341', '\342', '\343', '\344', '\345', '\346', '\347',
    '\350', '\351', '\352', '\353', '\354', '\355', '\356', '\357',
    '\360', '\361', '\362', '\363', '\364', '\365', '\366', '\367',
    '\370', '\371', '\372', '\373', '\374', '\375', '\376', '\377',
};

/* Private Structure */

struct ApeTag {
    FILE *file;                  /* file containing tag */
    DB *items;                   /* DB_HASH format database */
                                 /* Keys are NULL-terminated */
                                 /* Values are ApeItem** */
    char *tag_header;            /* Tag Header data */
    char *tag_data;              /* Tag body data */
    char *tag_footer;            /* Tag footer data */
    char *id3;                   /* ID3 data, if any */
    char *error;                 /* String for last error */
    enum ApeTag_errcode errcode; /* Error code for last error */
    uint32_t flags;              /* Internal tag flags */
    uint32_t size;               /* On disk size in bytes */
    uint32_t file_item_count;    /* On disk item count */
    uint32_t item_count;         /* In database item count */
    off_t offset;                /* Start of tag in file */
};

/* Private function prototypes */

static int ApeTag__get_tag_information(struct ApeTag *tag);
static int ApeTag__parse_items(struct ApeTag *tag);
static int ApeTag__parse_item(struct ApeTag *tag, uint32_t *offset);
static int ApeTag__update_id3(struct ApeTag *tag);
static int ApeTag__update_ape(struct ApeTag *tag);
static int ApeTag__write_tag(struct ApeTag *tag);
static uint32_t ApeTag__tag_length(struct ApeTag *tag);
static uint32_t ApeTag__id3_length(struct ApeTag *tag);
static struct ApeItem * ApeTag__get_item(struct ApeTag *tag, const char *key);
static struct ApeItem **ApeTag__get_items(struct ApeTag *tag, uint32_t *item_count);
static int ApeTag__iter_items(struct ApeTag *tag, int iterator(struct ApeTag *tag, struct ApeItem *item, void *data), void *data);

static void ApeItem__free(struct ApeItem **item);
static char * ApeTag__strcasecpy(const char *src, size_t size);
static unsigned char ApeItem__parse_track(uint32_t size, char *value);
static int ApeItem__check_validity(struct ApeTag *tag, struct ApeItem *item);
static int ApeTag__check_valid_utf8(unsigned char *utf8_string, uint32_t size);
static int ApeItem__compare(const void *a, const void *b);
static int ApeTag__lookup_genre(struct ApeTag *tag, struct ApeItem *item, unsigned char *genre_id);
static int ApeTag__load_ID3_GENRES(struct ApeTag *tag);
static int ApeTag__strncasecmp(const char *s1, const char *s2, size_t n);

/* Public Functions */

struct ApeTag * ApeTag_new(FILE *file, uint32_t flags) {
    struct ApeTag *tag;
    
    if (file == NULL) {
        return NULL;
    }
    
    tag = malloc(sizeof(struct ApeTag));

    if (tag != NULL) {
        memset(tag, 0, sizeof(struct ApeTag));
        tag->file = file;
        tag->flags = flags | APE_DEFAULT_FLAGS;
    }
    
    return tag;
}

int ApeTag_free(struct ApeTag *tag) {
    int ret = 0;
    
    if (tag == NULL) {
        return 0;
    }
    
    /* Free the information stored in the database */
    ret = ApeTag_clear_items(tag);
    
    /* Free char* on the heap first, then the tag itself */
    free(tag->id3);
    tag->id3 = NULL;
    free(tag->tag_header);
    tag->tag_header = NULL;
    free(tag->tag_footer);
    tag->tag_footer = NULL;
    free(tag->tag_data);
    tag->tag_data = NULL;
    free(tag);
    tag = NULL;
    
    return ret;
}

int ApeTag_exists(struct ApeTag *tag) {
    if (ApeTag__get_tag_information(tag) != 0) {
        return -1;
    }

    return (tag->flags & APE_HAS_APE) > 0;
}

int ApeTag_exists_id3(struct ApeTag *tag) {
    if (ApeTag__get_tag_information(tag) != 0) {
        return -1;
    }

    return (tag->flags & APE_HAS_ID3) > 0;
}

int ApeTag_remove(struct ApeTag *tag) {
    if (ApeTag__get_tag_information(tag) != 0) {
        return -1;
    }
    
    if (!(tag->flags & APE_HAS_APE)) {
        return 1;
    }

    if (fflush(tag->file) != 0) {
        tag->errcode = APETAG_FILEERR;
        tag->error = "fflush";
        return -1;
    }

    if (ftruncate(fileno(tag->file), tag->offset) != 0) {
        tag->errcode = APETAG_FILEERR;
        tag->error = "ftruncate";
        return -1;
    }
    
    tag->flags &= ~(APE_HAS_APE|APE_HAS_ID3);

    return 0;
}

int ApeTag_raw(struct ApeTag *tag, char **raw, uint32_t *raw_size) {    
    uint32_t r_size; 
    char *r; 

    if (ApeTag__get_tag_information(tag) != 0) {
        return -1;
    }

    if (raw == NULL) {
        tag->errcode = APETAG_ARGERR;
        tag->error = "raw is NULL";
        return -1;
    }
    if (raw_size == NULL) {
        tag->errcode = APETAG_ARGERR;
        tag->error = "raw_size is NULL";
        return -1;
    }

    *raw = NULL;
    *raw_size = 0;
    r_size = ApeTag__tag_length(tag);

    if ((r = malloc(r_size)) == NULL) {
        tag->errcode = APETAG_MEMERR;
        tag->error = "malloc";
        return -1;
    }

    if (tag->flags & APE_HAS_APE) {
        memcpy(r, tag->tag_header, 32);
        memcpy(r+32, tag->tag_data, tag->size-64);
        memcpy(r+tag->size-32, tag->tag_footer, 32);
    }

    if (tag->flags & APE_HAS_ID3 && !(tag->flags & APE_NO_ID3)) {
        memcpy(r+tag->size, tag->id3, ApeTag__id3_length(tag));
    }

    *raw = r;
    *raw_size = r_size;
    
    return 0;
}

int ApeTag_parse(struct ApeTag *tag) {
    if (ApeTag__get_tag_information(tag) != 0) {
        return -1;
    }

    if ((tag->flags & APE_HAS_APE) && !(tag->flags & APE_CHECKED_FIELDS)) {
        if ((ApeTag__parse_items(tag)) != 0) {
            return -1;
        }
    }
    
    return 0;
}

int ApeTag_update(struct ApeTag *tag) {
    if (ApeTag__get_tag_information(tag) != 0) {
        return -1;
    }
    if (ApeTag__update_id3(tag) != 0) {
        return -1;
    }
    if (ApeTag__update_ape(tag) != 0) {
        return -1;
    }
    if (ApeTag__write_tag(tag) != 0) {
        return -1;
    }
    
    return 0;
}

int ApeTag_add_item(struct ApeTag *tag, struct ApeItem *item) {
    int ret;
    DBT key_dbt, value_dbt;

    if (ApeTag__get_tag_information(tag) != 0) {
        return -1;
    }

    value_dbt.size = sizeof(struct ApeItem **);
    value_dbt.data = &item; 
    key_dbt.size = strlen(item->key)+1;
    
    if (item == NULL) {
        tag->errcode = APETAG_INVALIDITEM;
        tag->error = "item pointer is NULL";
        return -1;
    }
    if (item->key == NULL) {
        tag->errcode = APETAG_INVALIDITEM;
        tag->error = "item key is NULL";
        return -1;
    }
    if (item->value == NULL) {
        tag->errcode = APETAG_INVALIDITEM;
        tag->error = "item value is NULL";
        return -1;
    }
    
    /* Don't add invalid items to the database */
    if (ApeItem__check_validity(tag, item) != 0) {
        return -1;
    }
    
    /* Don't exceed the maximum number of items allowed */
    if (tag->item_count == APE_MAXIMUM_ITEM_COUNT) {
        tag->errcode = APETAG_LIMITEXCEEDED;
        tag->error = "maximum item count exceeded";
        return -1;
    }
    
    /* Create the database if it doesn't already exist */
    if (tag->items == NULL) {
        if ((tag->items = dbopen(NULL, O_RDWR|O_CREAT, 0777, DB_HASH, NULL)) == NULL) {
            tag->errcode = APETAG_INTERNALERR;
            tag->error = "dbopen";
            return -1;
        }
    }
    
    /* Apetag keys are case insensitive but case preserving */
    if ((key_dbt.data = ApeTag__strcasecpy(item->key, key_dbt.size)) == NULL) {
        tag->errcode = APETAG_MEMERR;
        tag->error = "malloc";
        goto add_item_error;
    }
    
    /* Add to the database */
    ret = tag->items->put(tag->items, &key_dbt, &value_dbt, R_NOOVERWRITE);
    if (ret == -1) {
        tag->errcode = APETAG_INTERNALERR;
        tag->error = "db->put";
        goto add_item_error;
    } else if (ret == 1) {
        tag->errcode = APETAG_DUPLICATEITEM;
        tag->error = "duplicate item in tag";
        goto add_item_error;
    }

    tag->item_count++;
    free(key_dbt.data);
    return 0;
    
    add_item_error:
    free(key_dbt.data);
    return -1;
}

int ApeTag_replace_item(struct ApeTag *tag, struct ApeItem *item) {
    int existed = 0;
    int ret;

    if (ApeTag__get_tag_information(tag) != 0) {
        return -1;
    }
    
    if ((ret = ApeTag_remove_item(tag, item->key)) < 0) {
        return ret;
    } else if (ret == 0) {
        existed = 1;
    }

    if ((ret = ApeTag_add_item(tag, item)) < 0) {
        return ret;
    }
    
    return existed;
}

int ApeTag_remove_item(struct ApeTag *tag, const char *key) {
    int ret;
    DBT key_dbt;
    struct ApeItem *item;

    if (ApeTag__get_tag_information(tag) != 0) {
        return -1;
    }

    if ((item = ApeTag__get_item(tag, key)) == NULL) {
        if (tag->errcode == APETAG_NOTPRESENT) {
          return 1;
        }
        return -1;
    }

    key_dbt.size = strlen(key) + 1;
    /* APE item keys are case insensitive but case preserving */
    if ((key_dbt.data = ApeTag__strcasecpy(key, key_dbt.size)) == NULL)  {
        tag->errcode = APETAG_MEMERR;
        tag->error = "malloc";
        return -1;
    }
    
    /* Free the item and remove it from the database  */
    ApeItem__free(&item);
    ret = tag->items->del(tag->items, &key_dbt, 0);
    free(key_dbt.data);
    if (ret != 0) {
        if (ret == -1) {
            tag->errcode = APETAG_INTERNALERR;
            tag->error = "db->del";
        } else if (ret == 1) {
            tag->errcode = APETAG_INTERNALERR;
            tag->error = "database modified between get and del";
        }
        return -1;
    }
    
    tag->item_count--;
    return ret;
}

int ApeTag_clear_items(struct ApeTag *tag) {
    int ret = 0;
    DBT key_dbt, value_dbt;
    
    if (tag == NULL) {
        return -1;
    }
    
    if (tag->items != NULL) {
        /* Free all items in the database and then close it */
        if (tag->items->seq(tag->items, &key_dbt, &value_dbt, R_FIRST) == 0) {
            ApeItem__free((struct ApeItem **)(value_dbt.data));
            while (tag->items->seq(tag->items, &key_dbt, &value_dbt, R_NEXT) == 0) {
                ApeItem__free((struct ApeItem **)(value_dbt.data));
            }
        }
        if (tag->items->close(tag->items) == -1) {
            tag->errcode = APETAG_INTERNALERR;
            tag->error = "db->close";
            ret = -1;
            goto clear_items_error;
        }
    }
    
    ret = 0;
    
    clear_items_error:
    tag->items = NULL;
    tag->flags &= ~APE_CHECKED_FIELDS;
    tag->item_count = 0;
    return ret;
}

struct ApeItem * ApeTag_get_item(struct ApeTag *tag, const char *key) {
    if (ApeTag__get_tag_information(tag) != 0) {
        return NULL;
    }

    if (key == NULL) {
        tag->errcode = APETAG_ARGERR;
        tag->error = "key is NULL";
        return NULL;
    }

    return ApeTag__get_item(tag, key);
}

struct ApeItem ** ApeTag_get_items(struct ApeTag *tag, uint32_t *item_count) {
    if (ApeTag__get_tag_information(tag) != 0) {
        return NULL;
    }

    return ApeTag__get_items(tag, item_count);
}

int ApeTag_iter_items(struct ApeTag *tag, int iterator(struct ApeTag *tag, struct ApeItem *item, void *data), void *data) {
    if (ApeTag__get_tag_information(tag) != 0) {
        return -1;
    }

    return ApeTag__iter_items(tag, iterator, data);
}

int ApeTag_mt_init(void) {
    struct ApeTag tag;

    return ApeTag__load_ID3_GENRES(&tag);
}

uint32_t ApeTag_size(struct ApeTag *tag) {
    return tag->size;
}

uint32_t ApeTag_item_count(struct ApeTag *tag) {
    return tag->item_count;
}

uint32_t ApeTag_file_item_count(struct ApeTag *tag) {
    return tag->file_item_count;
}

const char * ApeTag_error(struct ApeTag *tag){
    return tag->error;
}

enum ApeTag_errcode ApeTag_error_code(struct ApeTag *tag) {
    return tag->errcode;
}

size_t ApeTag_get_max_size(void) {
    return APE_MAXIMUM_TAG_SIZE;
}

size_t ApeTag_get_max_item_count(void) {
    return APE_MAXIMUM_ITEM_COUNT;
}

void ApeTag_set_max_size(uint32_t size) {
    APE_MAXIMUM_TAG_SIZE = size;
}

void ApeTag_set_max_item_count(uint32_t item_count) {
    APE_MAXIMUM_ITEM_COUNT = item_count;
}

/* Private Functions */

/*
Parses the header and footer of the tag to get information about it.

Returns 0 on success, <0 on error;
*/
static int ApeTag__get_tag_information(struct ApeTag *tag) {
    int id3_length = 0;
    uint32_t header_check;
    off_t file_size = 0;

    if (tag == NULL) {
        return -1;
    }

    if (tag->flags & APE_CHECKED_APE) {
        return 0;
    }
    
    /* Get file size */
    if (fseeko(tag->file, 0, SEEK_END) == -1) {
        tag->errcode = APETAG_FILEERR;
        tag->error = "fseeko";
        return -1;
    }
    if ((file_size = ftello(tag->file)) == -1) {
        tag->errcode = APETAG_FILEERR;
        tag->error = "ftello";
        return -1;
    } 
    
    /* No ape or id3 tag possible in this size */
    if (file_size < APE_MINIMUM_TAG_SIZE) {
        tag->offset = file_size;
        tag->flags |= APE_CHECKED_APE | APE_CHECKED_OFFSET;
        tag->flags &= ~(APE_HAS_APE | APE_HAS_ID3);
        return 0;
    } 
    
    if (!(tag->flags & APE_NO_ID3)) {
        if (file_size < 128) {
            /* No id3 tag possible in this size */
            tag->flags &= ~APE_HAS_ID3;
        } else {
            /* Check for id3 tag */
            if ((fseeko(tag->file, -128, SEEK_END)) == -1) {
                tag->errcode = APETAG_FILEERR;
                tag->error = "fseeko";
                return -1;
            }
            free(tag->id3);
            if ((tag->id3 = malloc(128)) == NULL) {
                tag->errcode = APETAG_MEMERR;
                tag->error = "malloc";
                return -1;
            }
            if (fread(tag->id3, 1, 128, tag->file) < 128) {
                tag->errcode = APETAG_FILEERR;
                tag->error = "fread";
                return -1;
            }
            if (tag->id3[0] == 'T' && tag->id3[1] == 'A' && 
               tag->id3[2] == 'G' && tag->id3[125] == '\0') {
                id3_length = 128;
                tag->flags |= APE_HAS_ID3;
            } else {
                free(tag->id3);
                tag->id3 = NULL;
                tag->flags &= ~APE_HAS_ID3;
            }
        }
        /* Recheck possibility for ape tag now that id3 presence is known */
        if (file_size < APE_MINIMUM_TAG_SIZE + id3_length) {
            tag->flags &= ~APE_HAS_APE;
            tag->offset = file_size - id3_length;
            tag->flags |= APE_CHECKED_OFFSET | APE_CHECKED_APE;
            return 0;
        }
    }
    
    /* Check for existance of ape tag footer */
    if (fseeko(tag->file, -32-id3_length, SEEK_END) == -1) {
        tag->errcode = APETAG_FILEERR;
        tag->error = "fseeko";
        return -1;
    }
    free(tag->tag_footer);
    if ((tag->tag_footer = malloc(32)) == NULL) {
        tag->errcode = APETAG_MEMERR;
        tag->error = "malloc";
        return -1;
    }
    if (fread(tag->tag_footer, 1, 32, tag->file) < 32) {
        tag->errcode = APETAG_FILEERR;
        tag->error = "fread";
        return -1;
    }
    if (memcmp(APE_PREAMBLE, tag->tag_footer, 12)) {
        tag->flags &= ~APE_HAS_APE;
        tag->offset = file_size - id3_length;
        tag->flags |= APE_CHECKED_OFFSET | APE_CHECKED_APE;
        return 0;
    }
    if (memcmp(APE_FOOTER_FLAGS, tag->tag_footer+21, 3) || \
       ((char)*(tag->tag_footer+20) != '\0' && \
       (char)*(tag->tag_footer+20) != '\1')) {
        tag->errcode = APETAG_CORRUPTTAG;
        tag->error = "bad tag footer flags";
        return -1;
    }
    
    memcpy(&tag->size, tag->tag_footer+12, 4);
    memcpy(&tag->file_item_count, tag->tag_footer+16, 4);
    tag->size = LE2H32(tag->size);
    tag->file_item_count = LE2H32(tag->file_item_count);
    tag->size += 32;
    
    /* Check tag footer for validity */
    if (tag->size < APE_MINIMUM_TAG_SIZE) {
        tag->errcode = APETAG_CORRUPTTAG;
        tag->error = "tag smaller than minimum possible size";
        return -1;
    }
    if (tag->size > APE_MAXIMUM_TAG_SIZE) {
        tag->errcode = APETAG_LIMITEXCEEDED;
        tag->error = "tag larger than maximum allowed size";
        return -1;
    }
    if (tag->size + (off_t)id3_length > file_size) {
        tag->errcode = APETAG_CORRUPTTAG;
        tag->error = "tag larger than possible size";
        return -1;
    }
    if (tag->file_item_count > APE_MAXIMUM_ITEM_COUNT) {
        tag->errcode = APETAG_LIMITEXCEEDED;
        tag->error = "tag item count larger than allowed";
        return -1;
    }
    if (tag->file_item_count > (tag->size - APE_MINIMUM_TAG_SIZE)/APE_ITEM_MINIMUM_SIZE) {
        tag->errcode = APETAG_CORRUPTTAG;
        tag->error = "tag item count larger than possible";
        return -1;
    }
    if (fseeko(tag->file, (-(long)tag->size - id3_length), SEEK_END) == -1) {
        tag->errcode = APETAG_FILEERR;
        tag->error = "fseeko";
        return -1;
    }
    if ((tag->offset = ftello(tag->file)) == -1) {
        tag->errcode = APETAG_FILEERR;
        tag->error = "ftello";
        return -1;
    }
    tag->flags |= APE_CHECKED_OFFSET;
    
    /* Read tag header and data */
    free(tag->tag_header);
    if ((tag->tag_header = malloc(32)) == NULL) {
        tag->errcode = APETAG_MEMERR;
        tag->error = "malloc";
        return -1;
    }
    if (fread(tag->tag_header, 1, 32, tag->file) < 32) {
        tag->errcode = APETAG_FILEERR;
        tag->error = "fread";
        return -1;
    }
    free(tag->tag_data);
    if ((tag->tag_data = malloc(tag->size-64)) == NULL) {
        tag->errcode = APETAG_MEMERR;
        tag->error = "malloc";
        return -1;
    }
    if (fread(tag->tag_data, 1, tag->size-64, tag->file) < tag->size-64) {
        tag->errcode = APETAG_FILEERR;
        tag->error = "fread";
        return -1;
    }
    
    /* Check tag header for validity */
    if (memcmp(APE_PREAMBLE, tag->tag_header, 12) || memcmp(APE_HEADER_FLAGS, tag->tag_header+21, 3) \
      || ((char)*(tag->tag_header+20) != '\0' && (char)*(tag->tag_header+20) != '\1')) {
        tag->errcode = APETAG_CORRUPTTAG;
        tag->error = "missing APE header";
        return -1;
    }
    memcpy(&header_check, tag->tag_header+12, 4);
    if (tag->size != LE2H32(header_check)+32) {
        tag->errcode = APETAG_CORRUPTTAG;
        tag->error = "header and footer size does not match";
        return -1;
    }
    memcpy(&header_check, tag->tag_header+16, 4);
    if (tag->file_item_count != LE2H32(header_check)) {
        tag->errcode = APETAG_CORRUPTTAG;
        tag->error = "header and footer item count does not match";
        return -1;
    }
    
    tag->flags |= APE_CHECKED_APE | APE_HAS_APE;
    return 0;
}

/* 
Parses all items from the tag and puts them in the database.

Returns 0 on success, <0 on error.
*/
static int ApeTag__parse_items(struct ApeTag *tag) {
    uint32_t i;
    uint32_t offset = 0;
    uint32_t last_possible_offset = tag->size - APE_MINIMUM_TAG_SIZE - 
                               APE_ITEM_MINIMUM_SIZE;
    
    assert(tag != NULL);
    
    if (tag->items != NULL) {
        if (ApeTag_clear_items(tag) != 0) {
            return -1;
        }
    }
    
    for (i=0; i < tag->file_item_count; i++) {
        if (offset > last_possible_offset) {
            tag->errcode = APETAG_CORRUPTTAG;
            tag->error = "end of tag reached but more items specified";
            return -1;
        }

        if (ApeTag__parse_item(tag, &offset) != 0) {
            return -1;
        }
    }
    if (offset != tag->size - APE_MINIMUM_TAG_SIZE) {
        tag->errcode = APETAG_CORRUPTTAG;
        tag->error = "data remaining after specified number of items parsed";
        return -1;
    }
    tag->flags |= APE_CHECKED_FIELDS;
    
    return 0;
}

/* 
Parses a single item from the tag at the given offset from the start of the
tag's data.

Returns 0 on success, <0 on error.
*/
static int ApeTag__parse_item(struct ApeTag *tag, uint32_t *offset) {
    char *data = tag->tag_data;
    char *value_start = NULL;
    char *key_start = data+(*offset)+8;
    uint32_t data_size = tag->size - APE_MINIMUM_TAG_SIZE;
    uint32_t key_length;
    struct ApeItem *item = NULL;
    
    if ((item = malloc(sizeof(struct ApeItem))) == NULL) {
        tag->errcode = APETAG_MEMERR;
        tag->error = "malloc";
        return -1;
    }
    
    memcpy(&item->size, data+(*offset), 4);
    memcpy(&item->flags, data+(*offset)+4, 4);
    item->size = LE2H32(item->size);
    item->flags = LE2H32(item->flags);
    item->key = NULL;
    item->value = NULL;
    
    /* Find and check start of value */
    if (item->size + *offset + APE_ITEM_MINIMUM_SIZE > data_size) {
        tag->errcode = APETAG_CORRUPTTAG;
        tag->error = "impossible item length (greater than remaining space)";
        goto parse_error;
    }
    for (value_start=key_start; value_start < key_start+256 && \
        *value_start != '\0'; value_start++) {
        /* Left Blank */
    }
    if (*value_start != '\0') {
        tag->errcode = APETAG_CORRUPTTAG;
        tag->error = "invalid item key length (too long or no end)";
        goto parse_error;
    }
    value_start++;
    key_length = (uint32_t)(value_start - key_start);
    *offset += 8 + key_length + item->size;
    if (*offset > data_size) {
        tag->errcode = APETAG_CORRUPTTAG;
        tag->error = "invalid item length (longer than remaining data)";
        goto parse_error;
    }
    
    /* Copy key and value from tag data to item */
    if ((item->key = malloc(key_length)) == NULL) {
        tag->errcode = APETAG_MEMERR;
        tag->error = "malloc";
        goto parse_error;
    }
    if ((item->value = malloc(item->size)) == NULL) {
        tag->errcode = APETAG_MEMERR;
        tag->error = "malloc";
        goto parse_error;
    }
    memcpy(item->key, key_start, key_length);
    memcpy(item->value, value_start, item->size);
    
    /* Add item to the database */
    if (ApeTag_add_item(tag, item) != 0) {
        goto parse_error;
    }

    return 0;
    
    parse_error:
    free(item->key);
    free(item->value);
    free(item);
    return -1;
}

/* 
Updates the id3 tag using the new ape tag values.  Does not merge it with a
previous id3 tag, it overwrites it completely.

Returns 0 on success, <0 on error.
*/
static int ApeTag__update_id3(struct ApeTag *tag) {
    struct ApeItem *item;
    char *c;
    char *end;
    uint32_t size;
    
    assert (tag != NULL);
    
    free(tag->id3);
    
    if (tag->flags & APE_NO_ID3 || 
       (tag->flags & APE_HAS_APE && !(tag->flags & APE_HAS_ID3))) {
        tag->id3 = NULL;
        return 0;
    }
    
    /* Initialize id3 */
    if ((tag->id3 = malloc(128)) == NULL) {
        tag->errcode = APETAG_MEMERR;
        tag->error = "malloc";
        return -1;
    }
    memcpy(tag->id3, "TAG", 3);
    memset(tag->id3+3, 0, 124);
    *(tag->id3+127) = '\377';
    
    if (tag->items == NULL) {
        return 0;
    }

    /* Easier to use a macro than a function in this case */
    #define APE_FIELD_TO_ID3_FIELD(FIELD, LENGTH, OFFSET) do { \
        if ((item = ApeTag__get_item(tag, FIELD)) != NULL) { \
            size = (item->size < (uint32_t)LENGTH ? item->size : (uint32_t)LENGTH); \
            end = tag->id3 + OFFSET + size; \
            memcpy(tag->id3 + OFFSET, item->value, size); \
            for (c=tag->id3 + OFFSET; c < end; c++) { \
                if (*c == '\0') { \
                    *c = ','; \
                } \
            } \
        } else if (tag->errcode != APETAG_NOTPRESENT) { \
            return -1; \
        } \
    } while (0);

    
    /* 
    ID3v1.1 tag offsets, lengths
    title - 3, 30
    artist - 33, 30
    album - 63, 30
    year - 93, 4
    comment - 97, 28
    track - 126, 1
    genre - 127, 1
    */
    APE_FIELD_TO_ID3_FIELD("title", 30, 3);
    APE_FIELD_TO_ID3_FIELD("artist", 30, 33);
    APE_FIELD_TO_ID3_FIELD("album", 30, 63);
    APE_FIELD_TO_ID3_FIELD("year", 4, 93);
    APE_FIELD_TO_ID3_FIELD("comment", 28, 97);
    
    #undef APE_FIELD_TO_ID3_FIELD
    
    /* Need to handle the track and genre differently, as they are just bytes */
    if ((item = ApeTag__get_item(tag, "track")) != NULL) { 
        *(tag->id3+126) = (char)ApeItem__parse_track(item->size, item->value);
    } else if (tag->errcode != APETAG_NOTPRESENT) {
        return -1;
    }

    if ((item = ApeTag__get_item(tag, "genre")) != NULL) { 
        if (ApeTag__lookup_genre(tag, item, (unsigned char *)(tag->id3+127)) != 0) {
            return -1;
        }
    } else if (tag->errcode != APETAG_NOTPRESENT) {
        return -1;
    }
    
    return 0;
}

/* 
Updates the internal ape tag strings using the value for the database.

Returns 0 on success, <0 on error.
*/
static int ApeTag__update_ape(struct ApeTag *tag) {
    uint32_t i = 0;
    uint32_t key_size;
    char *c;
    uint32_t size;
    uint32_t flags;
    uint32_t tag_size = 64 + 9 * tag->item_count;
    uint32_t num_items;
    struct ApeItem **items;
    
    /* Check that the total number of items in the tag is ok */
    if (tag->item_count > APE_MAXIMUM_ITEM_COUNT) {
        tag->errcode = APETAG_LIMITEXCEEDED;
        tag->error = "tag item count larger than allowed";
        return -1;
    }
    
    /* Get the array of items */
    items = ApeTag__get_items(tag, &num_items);
    if (items == NULL) {
        return -1;
    }
    
    /* Sort the items */
    qsort(items, num_items, sizeof(struct ApeItem *), ApeItem__compare);

    /* Check all of the items for validity and update the total size of the tag*/
    for (i=0; i < num_items; i++) {
        if (ApeItem__check_validity(tag, items[i]) != 0) {
            goto update_ape_error;
        }
        tag_size += items[i]->size + (uint32_t)strlen(items[i]->key);
    }
    
    /* Check that the total size of the tag is ok */
    tag->size = tag_size;
    if (tag->size > APE_MAXIMUM_TAG_SIZE) {
        tag->errcode = APETAG_LIMITEXCEEDED;
        tag->error = "tag larger than maximum possible size";
        goto update_ape_error;
    }
    
    /* Write all of the tag items to the internal tag item string */
    free(tag->tag_data);
    if ((tag->tag_data = malloc(tag->size-64)) == NULL) {
        tag->errcode = APETAG_MEMERR;
        tag->error = "malloc";
        goto update_ape_error;
    }
    for (i=0, c=tag->tag_data; i < num_items; i++) {
        key_size = (uint32_t)strlen(items[i]->key) + 1;
        size = H2LE32(items[i]->size);
        flags = H2LE32(items[i]->flags);
        memcpy(c, &size, 4);
        memcpy(c+=4, &flags, 4);
        memcpy(c+=4, items[i]->key, key_size);
        memcpy(c+=key_size, items[i]->value, items[i]->size);
        c += items[i]->size;
    }
    if ((uint32_t)(c - tag->tag_data) != tag_size - 64) {
        tag->errcode = APETAG_INTERNALERR;
        tag->error = "internal inconsistancy in creating new tag data";
        goto update_ape_error;
    }
    
    free(tag->tag_footer);
    if ((tag->tag_footer = malloc(32)) == NULL) {
        tag->errcode = APETAG_MEMERR;
        tag->error = "malloc";
        goto update_ape_error;
    }
    free(tag->tag_header);
    if ((tag->tag_header = malloc(32)) == NULL) {
        tag->errcode = APETAG_MEMERR;
        tag->error = "malloc";
        goto update_ape_error;
    }
    
    /* Update the internal tag header and footer strings */
    tag_size = H2LE32(tag_size - 32);
    num_items = H2LE32(num_items);
    memcpy(tag->tag_header, APE_PREAMBLE, 12);
    memcpy(tag->tag_footer, APE_PREAMBLE, 12);
    memcpy(tag->tag_header+12, &tag_size, 4);
    memcpy(tag->tag_footer+12, &tag_size, 4);
    memcpy(tag->tag_header+16, &num_items, 4);
    memcpy(tag->tag_footer+16, &num_items,  4);
    *(tag->tag_header+20) = '\0';
    *(tag->tag_footer+20) = '\0';
    memcpy(tag->tag_header+21, APE_HEADER_FLAGS, 4);
    memcpy(tag->tag_footer+21, APE_FOOTER_FLAGS, 4);
    memset(tag->tag_header+24, 0, 8);
    memset(tag->tag_footer+24, 0, 8);
    
    free(items);
    return 0;
    
    update_ape_error:
    free(items);
    return -1;
}

/* 
Writes the tag to the file using the internal tag strings.

Returns 0 on success, <0 on error.
*/
static int ApeTag__write_tag(struct ApeTag *tag) {
    assert(tag->tag_header != NULL);
    assert(tag->tag_data != NULL);
    assert(tag->tag_footer != NULL);
    
    if (fseeko(tag->file, tag->offset, SEEK_SET) == -1) {
        tag->errcode = APETAG_FILEERR;
        tag->error = "fseeko";
        return -1;
    }
    
    if (fwrite(tag->tag_header, 1, 32, tag->file) != 32) {
        tag->errcode = APETAG_FILEERR;
        tag->error = "fwrite";
        return -1;
    }
    if (fwrite(tag->tag_data, 1, tag->size-64, tag->file) != tag->size-64) {
        tag->errcode = APETAG_FILEERR;
        tag->error = "fwrite";
        return -1;
    }
    if (fwrite(tag->tag_footer, 1, 32, tag->file) != 32) {
        tag->errcode = APETAG_FILEERR;
        tag->error = "fwrite";
        return -1;
    }
    if (tag->id3 != NULL && !(tag->flags & APE_NO_ID3)) {
        if (fwrite(tag->id3, 1, 128, tag->file) != 128) {
            tag->errcode = APETAG_FILEERR;
            tag->error = "fwrite";
            return -1;
        }
        tag->flags |= APE_HAS_ID3;
    }

    if (fflush(tag->file) != 0) {
        tag->errcode = APETAG_FILEERR;
        tag->error = "fflush";
        return -1;
    }
    if (ftruncate(fileno(tag->file), (tag->offset + ApeTag__tag_length(tag))) == -1) {
        tag->errcode = APETAG_FILEERR;
        tag->error = "ftruncate";
        return -1;
    }
    tag->file_item_count = tag->item_count;
    tag->flags |= APE_HAS_APE;
    
    return 0;
}

/*
Frees an struct ApeItem and it's key and value, given a pointer to a pointer to it.
*/
static void ApeItem__free(struct ApeItem **item) {
    assert(item != NULL);
    if (*item == NULL) {
        return;
    }
    
    free((*item)->key);
    (*item)->key = NULL;
    free((*item)->value);
    (*item)->value = NULL;
    free(*item);
    *item = NULL;
}

/*
Allocates space for a copy of src, copies src to the newly allocated space
(for the given number of bytes), and converts the copy to lower case.  Size is
an unsigned char because keys cannot be more than 256 bytes (including
terminator).

The caller is responsible for freeing the returned pointer.

Returns pointer to copy on success, NULL pointer on error.
*/
static char* ApeTag__strcasecpy(const char *src, size_t size) {
    char *c, *dest;
    
    assert(src != NULL);
    
    if ((dest = malloc(size)) == NULL) {
        return NULL;
    }
    
    memcpy(dest, src, size);
    for (c = dest; size > 0; size--, c++) {
        if (*c >= 'A' && *c <= 'Z') {
            *c |= 0x20;
        }
    } 
    
    return dest;
}

/*
This is a very simple atoi-like function that takes the size of the string, and
a character pointer.  If the character pointer is a string between "0" and
"255", the unsigned char equivalent is returned; otherwise, 0 is returned.

Returns unsigned char.
*/
static unsigned char ApeItem__parse_track(uint32_t size, char *value) {
    assert(value != NULL);
    
    if (size != 0 && size < 4) {
        if (size == 3) {
            if (*(value) >= '0' && *(value) <= '2' && 
               *(value+1) >= '0' && *(value+1) <= '9' &&
               *(value+2) >= '0' && *(value+2) <= '9') {
                if (*(value) == '2' && ((*(value+1) > '5') ||
                   (*(value+1) == '5' && *(value+2) > '5'))) {
                    /* 3 digit number > 255 won't fit in a char */
                    return 0;
                }
                return (unsigned char)(100 * (*(value) & ~0x30) + 
                       (10 * (*(value+1) & ~0x30)) + 
                       (*(value+2) & ~0x30));                        
            }
        } else if (size == 2) {
            if (*(value) >= '0' && *(value) <= '9' && 
               *(value+1) >= '0' && *(value+1) <= '9') {
                return (unsigned char)(10 * (*(value) & ~0x30) + 
                       (*(value+1) & ~0x30));
            }
        } else if (size == 1) {
            if (*(value) >= '0' && *(value) <= '9') {
                 return (unsigned char)(*(value) & ~0x30);
            }
        }
    }
    return 0;
}

/*
Checks the given struct ApeItem for validity (checking flags, key, and value).

Returns 0 if valid, <0 otherwise.
*/
static int ApeItem__check_validity(struct ApeTag *tag, struct ApeItem *item) {
    unsigned long key_length;
    char *key_end;
    char *c;
    
    assert(tag != NULL);
    assert(item != NULL);
    assert(item->key != NULL);
    assert(item->value != NULL);
    
    /* Check valid flags */
    if (item->flags > 7) {
        tag->errcode = APETAG_INVALIDITEM;
        tag->error = "invalid item flags";
        return -1;
    }
    
    /* Check valid key */
    key_length = strlen(item->key);
    key_end = item->key + (long)key_length;
    if (key_length < 2) {
        tag->errcode = APETAG_INVALIDITEM;
        tag->error = "invalid item key (too short)";
        return -1;
    }
    if (key_length > 255) {
        tag->errcode = APETAG_INVALIDITEM;
        tag->error = "invalid item key (too long)";
        return -1;
    }
    if (key_length == 3 ? ApeTag__strncasecmp(item->key, "id3", 3) == 0 || 
                         ApeTag__strncasecmp(item->key, "tag", 3) == 0 || 
                         ApeTag__strncasecmp(item->key, "mp+", 3) == 0
       : (key_length == 4 ? ApeTag__strncasecmp(item->key, "oggs", 4) == 0 : 0)) {
        tag->errcode = APETAG_INVALIDITEM;
        tag->error = "invalid item key (id3|tag|mp+|oggs)";
        return -1;
    }
    for (c=item->key; c<key_end; c++) {
        if ((unsigned char)(*c) < 0x20 || (unsigned char)(*c) > 0x7f) {
            tag->errcode = APETAG_INVALIDITEM;
            tag->error = "invalid item key character";
            return -1;
        }
    }
    
    /* Check value is utf-8 if flags specify utf8 or external format*/
    if (((item->flags & APE_ITEM_TYPE_FLAGS) & 2) == 0 && 
        ApeTag__check_valid_utf8((unsigned char *)(item->value), item->size) != 0) {
        tag->errcode = APETAG_INVALIDITEM;
        tag->error = "invalid utf8 value";
        return -1;
    }
    
    return 0;
}

/*
Checks the given UTF8 string for validity.

Returns 0 if valid, -1 if not.
*/
static int ApeTag__check_valid_utf8(unsigned char *utf8_string, uint32_t size) {
    unsigned char *utf_last_char;
    unsigned char *c = utf8_string;
    
    assert(utf8_string != NULL);
    
    for (; c < (utf8_string + size); c++) {
        if ((*c & 128) != 0) {
            /* Non ASCII */
            if ((*c < 194) || (*c > 245)) {
                /* Outside of UTF8 Range */
                return -1;
            }
            if ((*c & 224) == 192) {
                /* 2 byte UTF8 char */
                utf_last_char = c + 1;
            } else if ((*c & 240) == 224) {
                /* 3 byte UTF8 char */
                utf_last_char = c + 2;
            } else if ((*c & 248) == 240) {
                /* 4 byte UTF8 char */
                utf_last_char = c + 3;
            } else {
                return -1;
            }
            
            if (utf_last_char >= (utf8_string + size)) {
                return -1;
            }
            /* Check remaining bytes of character */
            for (c++; c <= utf_last_char; c++) {
                if ((*c & 192) != 128) {
                    return -1;
                }
            }
        }
    }
    return 0;
}

/* 
Comparison function for quicksort.  Sorts first based on size and secondly
based on key.  Should be a stable sort, as no two items should have the same
key.

Returns -1 or 1.  Could possibly return 0 if the database has been manually
modified (don't do that!).
*/
static int ApeItem__compare(const void *a, const void *b) {
    const struct ApeItem *ai_a = *(const struct ApeItem * const *)a;
    const struct ApeItem *ai_b = *(const struct ApeItem * const *)b;
    uint32_t size_a;
    uint32_t size_b;
    
    size_a = ai_a->size + (uint32_t)strlen(ai_a->key);
    size_b = ai_b->size + (uint32_t)strlen(ai_b->key);
    if (size_a < size_b) {
        return -1;
    }
    if (size_a > size_b) {
        return 1;
    }
    return strncmp(ai_a->key, ai_b->key, strlen(ai_a->key));
}

/*
Looks up a genre for the correct ID3 genre code.  The genre string is passed
in as the ApeItem's value, and pointer to the genre code is passed.  The ApeItem's
size should not include a terminator for the value, as the entries in the genre
database are not terminated.

Returns 0 on success, -1 on error;
*/
static int ApeTag__lookup_genre(struct ApeTag *tag, struct ApeItem *item, unsigned char *genre_id) {
    int ret = 0;
    DBT key_dbt, value_dbt;

    key_dbt.size = item->size;
    key_dbt.data = item->value;
    
    if (ApeTag__load_ID3_GENRES(tag) != 0) {
        return -1;
    }
    
    ret = ID3_GENRES->get(ID3_GENRES, &key_dbt, &value_dbt, 0);
    if (ret != 0) {
        if (ret == -1) {
            tag->errcode = APETAG_INTERNALERR;
            tag->error = "db->get";
            return -1;
        }
        *genre_id = '\377';
    } else {
        *genre_id = *(unsigned char *)(value_dbt.data);
    }
    
    return 0;
}

/*
Loads the ID3_GENRES global database with all 148 ID3 genres (including the 
Winamp extensions).  This has a possible race condition in multi-threaded
code, since it modifies a global variable, but the worst case scenario is
minor memory leakage, and the window for the race condition is very small,
since it can only occur if ID3_GENRES has not yet been initialized.

Returns 0 on success, -1 on error.
*/
static int ApeTag__load_ID3_GENRES(struct ApeTag *tag) {
    DB* genres;
    DBT key_dbt, value_dbt;
    value_dbt.size = 1;
    
    assert(tag != NULL);
    
    if (ID3_GENRES != NULL) {
        return 0;
    }

    if ((ID3_GENRES = genres = dbopen(NULL, O_RDWR|O_CREAT, 0777, DB_HASH, NULL)) == NULL) {
        tag->errcode = APETAG_INTERNALERR;
        tag->error = "dbopen";
        return -1;
    }
    
    #define ADD_TO_ID3_GENRES(GENRE, VALUE) do { \
        key_dbt.data = (GENRE); \
        key_dbt.size = strlen(GENRE); \
        value_dbt.data = (VALUE); \
        if (genres->put(genres, &key_dbt, &value_dbt, 0) == -1) { \
            tag->errcode = APETAG_INTERNALERR; \
            tag->error = "db->put"; \
            goto load_genres_error; \
        } \
    } while (0)
    

    ADD_TO_ID3_GENRES("Blues", "\0");
    ADD_TO_ID3_GENRES("Classic Rock", "\1");
    ADD_TO_ID3_GENRES("Country", "\2");
    ADD_TO_ID3_GENRES("Dance", "\3");
    ADD_TO_ID3_GENRES("Disco", "\4");
    ADD_TO_ID3_GENRES("Funk", "\5");
    ADD_TO_ID3_GENRES("Grunge", "\6");
    ADD_TO_ID3_GENRES("Hip-Hop", "\7");
    ADD_TO_ID3_GENRES("Jazz", "\10");
    ADD_TO_ID3_GENRES("Metal", "\11");
    ADD_TO_ID3_GENRES("New Age", "\12");
    ADD_TO_ID3_GENRES("Oldies", "\13");
    ADD_TO_ID3_GENRES("Other", "\14");
    ADD_TO_ID3_GENRES("Pop", "\15");
    ADD_TO_ID3_GENRES("R & B", "\16");
    ADD_TO_ID3_GENRES("Rap", "\17");
    ADD_TO_ID3_GENRES("Reggae", "\20");
    ADD_TO_ID3_GENRES("Rock", "\21");
    ADD_TO_ID3_GENRES("Techno", "\22");
    ADD_TO_ID3_GENRES("Industrial", "\23");
    ADD_TO_ID3_GENRES("Alternative", "\24");
    ADD_TO_ID3_GENRES("Ska", "\25");
    ADD_TO_ID3_GENRES("Death Metal", "\26");
    ADD_TO_ID3_GENRES("Prank", "\27");
    ADD_TO_ID3_GENRES("Soundtrack", "\30");
    ADD_TO_ID3_GENRES("Euro-Techno", "\31");
    ADD_TO_ID3_GENRES("Ambient", "\32");
    ADD_TO_ID3_GENRES("Trip-Hop", "\33");
    ADD_TO_ID3_GENRES("Vocal", "\34");
    ADD_TO_ID3_GENRES("Jazz + Funk", "\35");
    ADD_TO_ID3_GENRES("Fusion", "\36");
    ADD_TO_ID3_GENRES("Trance", "\37");
    ADD_TO_ID3_GENRES("Classical", "\40");
    ADD_TO_ID3_GENRES("Instrumental", "\41");
    ADD_TO_ID3_GENRES("Acid", "\42");
    ADD_TO_ID3_GENRES("House", "\43");
    ADD_TO_ID3_GENRES("Game", "\44");
    ADD_TO_ID3_GENRES("Sound Clip", "\45");
    ADD_TO_ID3_GENRES("Gospel", "\46");
    ADD_TO_ID3_GENRES("Noise", "\47");
    ADD_TO_ID3_GENRES("Alternative Rock", "\50");
    ADD_TO_ID3_GENRES("Bass", "\51");
    ADD_TO_ID3_GENRES("Soul", "\52");
    ADD_TO_ID3_GENRES("Punk", "\53");
    ADD_TO_ID3_GENRES("Space", "\54");
    ADD_TO_ID3_GENRES("Meditative", "\55");
    ADD_TO_ID3_GENRES("Instrumental Pop", "\56");
    ADD_TO_ID3_GENRES("Instrumental Rock", "\57");
    ADD_TO_ID3_GENRES("Ethnic", "\60");
    ADD_TO_ID3_GENRES("Gothic", "\61");
    ADD_TO_ID3_GENRES("Darkwave", "\62");
    ADD_TO_ID3_GENRES("Techno-Industrial", "\63");
    ADD_TO_ID3_GENRES("Electronic", "\64");
    ADD_TO_ID3_GENRES("Pop-Fol", "\65");
    ADD_TO_ID3_GENRES("Eurodance", "\66");
    ADD_TO_ID3_GENRES("Dream", "\67");
    ADD_TO_ID3_GENRES("Southern Rock", "\70");
    ADD_TO_ID3_GENRES("Comedy", "\71");
    ADD_TO_ID3_GENRES("Cult", "\72");
    ADD_TO_ID3_GENRES("Gangsta", "\73");
    ADD_TO_ID3_GENRES("Top 40", "\74");
    ADD_TO_ID3_GENRES("Christian Rap", "\75");
    ADD_TO_ID3_GENRES("Pop/Funk", "\76");
    ADD_TO_ID3_GENRES("Jungle", "\77");
    ADD_TO_ID3_GENRES("Native US", "\100");
    ADD_TO_ID3_GENRES("Cabaret", "\101");
    ADD_TO_ID3_GENRES("New Wave", "\102");
    ADD_TO_ID3_GENRES("Psychadelic", "\103");
    ADD_TO_ID3_GENRES("Rave", "\104");
    ADD_TO_ID3_GENRES("Showtunes", "\105");
    ADD_TO_ID3_GENRES("Trailer", "\106");
    ADD_TO_ID3_GENRES("Lo-Fi", "\107");
    ADD_TO_ID3_GENRES("Tribal", "\110");
    ADD_TO_ID3_GENRES("Acid Punk", "\111");
    ADD_TO_ID3_GENRES("Acid Jazz", "\112");
    ADD_TO_ID3_GENRES("Polka", "\113");
    ADD_TO_ID3_GENRES("Retro", "\114");
    ADD_TO_ID3_GENRES("Musical", "\115");
    ADD_TO_ID3_GENRES("Rock & Roll", "\116");
    ADD_TO_ID3_GENRES("Hard Rock", "\117");
    ADD_TO_ID3_GENRES("Folk", "\120");
    ADD_TO_ID3_GENRES("Folk-Rock", "\121");
    ADD_TO_ID3_GENRES("National Folk", "\122");
    ADD_TO_ID3_GENRES("Swing", "\123");
    ADD_TO_ID3_GENRES("Fast Fusion", "\124");
    ADD_TO_ID3_GENRES("Bebop", "\125");
    ADD_TO_ID3_GENRES("Latin", "\126");
    ADD_TO_ID3_GENRES("Revival", "\127");
    ADD_TO_ID3_GENRES("Celtic", "\130");
    ADD_TO_ID3_GENRES("Bluegrass", "\131");
    ADD_TO_ID3_GENRES("Avantgarde", "\132");
    ADD_TO_ID3_GENRES("Gothic Rock", "\133");
    ADD_TO_ID3_GENRES("Progressive Rock", "\134");
    ADD_TO_ID3_GENRES("Psychedelic Rock", "\135");
    ADD_TO_ID3_GENRES("Symphonic Rock", "\136");
    ADD_TO_ID3_GENRES("Slow Rock", "\137");
    ADD_TO_ID3_GENRES("Big Band", "\140");
    ADD_TO_ID3_GENRES("Chorus", "\141");
    ADD_TO_ID3_GENRES("Easy Listening", "\142");
    ADD_TO_ID3_GENRES("Acoustic", "\143");
    ADD_TO_ID3_GENRES("Humour", "\144");
    ADD_TO_ID3_GENRES("Speech", "\145");
    ADD_TO_ID3_GENRES("Chanson", "\146");
    ADD_TO_ID3_GENRES("Opera", "\147");
    ADD_TO_ID3_GENRES("Chamber Music", "\150");
    ADD_TO_ID3_GENRES("Sonata", "\151");
    ADD_TO_ID3_GENRES("Symphony", "\152");
    ADD_TO_ID3_GENRES("Booty Bass", "\153");
    ADD_TO_ID3_GENRES("Primus", "\154");
    ADD_TO_ID3_GENRES("Porn Groove", "\155");
    ADD_TO_ID3_GENRES("Satire", "\156");
    ADD_TO_ID3_GENRES("Slow Jam", "\157");
    ADD_TO_ID3_GENRES("Club", "\160");
    ADD_TO_ID3_GENRES("Tango", "\161");
    ADD_TO_ID3_GENRES("Samba", "\162");
    ADD_TO_ID3_GENRES("Folklore", "\163");
    ADD_TO_ID3_GENRES("Ballad", "\164");
    ADD_TO_ID3_GENRES("Power Ballad", "\165");
    ADD_TO_ID3_GENRES("Rhytmic Soul", "\166");
    ADD_TO_ID3_GENRES("Freestyle", "\167");
    ADD_TO_ID3_GENRES("Duet", "\170");
    ADD_TO_ID3_GENRES("Punk Rock", "\171");
    ADD_TO_ID3_GENRES("Drum Solo", "\172");
    ADD_TO_ID3_GENRES("Acapella", "\173");
    ADD_TO_ID3_GENRES("Euro-House", "\174");
    ADD_TO_ID3_GENRES("Dance Hall", "\175");
    ADD_TO_ID3_GENRES("Goa", "\176");
    ADD_TO_ID3_GENRES("Drum & Bass", "\177");
    ADD_TO_ID3_GENRES("Club-House", "\200");
    ADD_TO_ID3_GENRES("Hardcore", "\201");
    ADD_TO_ID3_GENRES("Terror", "\202");
    ADD_TO_ID3_GENRES("Indie", "\203");
    ADD_TO_ID3_GENRES("BritPop", "\204");
    ADD_TO_ID3_GENRES("Negerpunk", "\205");
    ADD_TO_ID3_GENRES("Polsk Punk", "\206");
    ADD_TO_ID3_GENRES("Beat", "\207");
    ADD_TO_ID3_GENRES("Christian Gangsta Rap", "\210");
    ADD_TO_ID3_GENRES("Heavy Metal", "\211");
    ADD_TO_ID3_GENRES("Black Metal", "\212");
    ADD_TO_ID3_GENRES("Crossover", "\213");
    ADD_TO_ID3_GENRES("Contemporary Christian", "\214");
    ADD_TO_ID3_GENRES("Christian Rock", "\215");
    ADD_TO_ID3_GENRES("Merengue", "\216");
    ADD_TO_ID3_GENRES("Salsa", "\217");
    ADD_TO_ID3_GENRES("Thrash Metal", "\220");
    ADD_TO_ID3_GENRES("Anime", "\221");
    ADD_TO_ID3_GENRES("Jpop", "\222");
    ADD_TO_ID3_GENRES("Synthpop", "\223");
    
    #undef ADD_TO_ID3_GENRES

    return 0;
    
    load_genres_error:
    if (genres != NULL){
        if (genres->close(genres) == -1) {
            tag->errcode = APETAG_INTERNALERR;
            tag->error = "db->close";
        }
        genres = NULL;
    }
    return -1;
}

static uint32_t ApeTag__tag_length(struct ApeTag *tag) {
    return tag->size + ApeTag__id3_length(tag);
}

static uint32_t ApeTag__id3_length(struct ApeTag *tag) {
    if ((tag->flags & APE_HAS_ID3) && !(tag->flags & APE_NO_ID3)) {
        return 128;
    }
    return 0;
}

/* 
Return an ApeItem * corresponding to the passed key, which the caller should not free.

The caller is expected to have checked that tag->items is not NULL.

Returns NULL on error.
*/
static struct ApeItem * ApeTag__get_item(struct ApeTag *tag, const char *key) {
    int ret = 0;
    DBT key_dbt, value_dbt;

    if (tag->items == NULL) {
        tag->errcode = APETAG_NOTPRESENT;
        tag->error = "get_item"; 
        return NULL; 
    }

    key_dbt.size = strlen(key) + 1; 
    if (key_dbt.size > 256) {
        tag->errcode = APETAG_ARGERR;
        tag->error = "key is greater than 255 characters";
        return NULL;
    }
    if ((key_dbt.data = ApeTag__strcasecpy(key, (unsigned char)key_dbt.size)) == NULL) {
        tag->errcode = APETAG_MEMERR;
        tag->error = "malloc";
        return NULL;
    }

    ret = tag->items->get(tag->items, &key_dbt, &value_dbt, 0);
    free(key_dbt.data);
    if (ret == -1) { 
        tag->errcode = APETAG_INTERNALERR;
        tag->error = "db->get"; 
        return NULL; 
    } else if (ret != 0) { 
        tag->errcode = APETAG_NOTPRESENT;
        tag->error = "get_item"; 
        return NULL; 
    } else {
        return *(struct ApeItem **)(value_dbt.data);
    } 
}

/* 
Return an array of ApeItem * for all items in the tag database,
which the caller is responsible for freeing.

Returns NULL on error.
*/
static struct ApeItem ** ApeTag__get_items(struct ApeTag *tag, uint32_t *num_items) {
    uint32_t nitems = tag->item_count;
    struct ApeItem **is;

    if (num_items) {
        *num_items = 0;
    }

    if ((is = calloc(nitems + 1, sizeof(struct ApeItem *))) == NULL) {
        tag->errcode = APETAG_MEMERR;
        tag->error = "calloc";
        return NULL;
    }

    if (nitems > 0) {
        uint32_t i = 0;
        DBT key_dbt, value_dbt;

        if (tag->items == NULL) {
            tag->errcode = APETAG_INTERNALERR;
            tag->error = "internal consistency error: item_count > 0 but items is NULL";
            free(is);
            return NULL;
        }
        
        /* Get all ape items from the database */
        if (tag->items->seq(tag->items, &key_dbt, &value_dbt, R_FIRST) == 0) {
            is[i++] = *(struct ApeItem **)(value_dbt.data);
            while (tag->items->seq(tag->items, &key_dbt, &value_dbt, R_NEXT) == 0) {
                if (i >= nitems) {
                    tag->errcode = APETAG_INTERNALERR;
                    tag->error = "internal consistency error: more items in database than item_count";
                    free(is);
                    return NULL;
                }
                is[i++] = *(struct ApeItem **)(value_dbt.data);
            }
        }
        if (i != nitems) {
            tag->errcode = APETAG_INTERNALERR;
            tag->error = "internal consistency error: fewer items in database than item_count";
            free(is);
            return NULL;
        }
    }

    if (num_items) {
        *num_items = nitems;
    }

    return is;
}

/* 
Iterate over all items in the database, calling the iterator function
with the given tag, the current item, and the given data pointer.

Returns 0 if iteration completes successfully, 1 if iteration is stopped
early, -1 on error.
*/
static int ApeTag__iter_items(struct ApeTag *tag, int iterator(struct ApeTag *tag, struct ApeItem *item, void *data), void *data) {
    if (tag->item_count > 0) {
        DBT key_dbt, value_dbt;

        if (tag->items == NULL) {
            tag->errcode = APETAG_INTERNALERR;
            tag->error = "internal consistency error: item_count > 0 but items is NULL";
            return -1;
        }
        
        /* Call iterator with each item in the database */
        if (tag->items->seq(tag->items, &key_dbt, &value_dbt, R_FIRST) == 0) {
            if (iterator(tag, *(struct ApeItem **)(value_dbt.data), data) != 0) {
                return 1;
            }
            while (tag->items->seq(tag->items, &key_dbt, &value_dbt, R_NEXT) == 0) {
                if (iterator(tag, *(struct ApeItem **)(value_dbt.data), data) != 0) {
                    return 1;
                }
            }
        }
    }

    return 0;
}

/* 
Local ASCII-only version of strncasecmp, since default strncasecmp may
depend on the locale, and this version is only called with APE item keys
(which are limited to ASCII).
*/
static int ApeTag__strncasecmp(const char *s1, const char *s2, size_t n) {
    if (n != 0) {
        const unsigned char *cm = charmap;
        const unsigned char *us1 = (const unsigned char *)s1;
        const unsigned char *us2 = (const unsigned char *)s2;

        do {
            if (cm[*us1] != cm[*us2++])
                return (cm[*us1] - cm[*--us2]);
            if (*us1++ == '\0')
                break;
        } while (--n != 0);
    }
    return (0);
}

