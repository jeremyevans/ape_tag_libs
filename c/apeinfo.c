#include <apetag.h>
#include <err.h>
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>

int ApeInfo_process(char *);
void ApeTag_print(struct ApeTag *tag);
void ApeItem_print(struct ApeItem *item);

/* Process all files on the command line */
int main(int argc, char *argv[]) {
    int ret = 0;
    int i;
    
    if (argc > 1) {
        for (i=1; i<argc; i++) {
            if (ApeInfo_process(argv[i]) != 0) {
                ret = 1;
            }
        }
    }
    else {
        printf("usage: %s file [...]\n", argv[0]);
    }
    
    return ret;
}

/* Print out the items in the file */
int ApeInfo_process(char *filename) {
    int ret;
    int status;
    FILE *file;
    struct ApeTag *tag = NULL;
    
    if ((file = fopen(filename, "r")) == NULL) {
        warn("%s", filename);
        ret = 1;
        goto apeinfo_process_error;
    }
    
    if ((tag = ApeTag_new(file, 0)) == NULL) {
        warn(NULL);
        ret = 1;
        goto apeinfo_process_error;
    }
    
    status = ApeTag_parse(tag);
    if (status == -1) {
        warnx("%s: %s", filename, ApeTag_error(tag));
        ret = 1;
        goto apeinfo_process_error;
    }
    
    if (ApeTag_exists(tag)) {
        printf("%s (%i items):\n", filename, ApeTag_item_count(tag));
        ApeTag_print(tag);
    } else {
        printf("%s: no ape tag\n\n", filename);
    }
    
    ret = 0;
    
    apeinfo_process_error:
    ApeTag_free(tag);
    if (file != NULL) {
        if (fclose(file) != 0) {
            warn("%s", filename);
        }
    }
    
    return ret;
}

int ApeTag_iter_print(struct ApeTag *tag, struct ApeItem *item, void *data) {
    ApeItem_print(item);
}

/* Prints all items in the tag, one per line. */
void ApeTag_print(struct ApeTag *tag) {
    assert(tag != NULL);

    if (ApeTag_iter_items(tag, ApeTag_iter_print, NULL) < 0) {
       printf("Error getting items: %s", ApeTag_error(tag));
    }

    printf("\n");
}

/* 
Prints a line with the key and value of the item separated by a colon. Includes
information about the tags flags unless they are the default (read-write UTF8).
*/
void ApeItem_print(struct ApeItem *item) {
    u_int32_t i;
    char c;
    
    assert(item != NULL);
    assert(item->key != NULL);
    assert(item->value != NULL);

    printf("%s: ", item->key);
    if ((item->flags & APE_ITEM_TYPE_FLAGS) == APE_ITEM_BINARY) {
        printf("[BINARY DATA]");
    } else if ((item->flags & APE_ITEM_TYPE_FLAGS) == APE_ITEM_RESERVED) {
        printf("[RESERVED]");
    } else {
        if ((item->flags & APE_ITEM_TYPE_FLAGS) == APE_ITEM_EXTERNAL) {
            printf("[EXTERNAL LOCATION] ");
        }
        for (i=0; i < item->size; i++) {
            c = *((char *)(item->value)+i);
            if (c == '\0') {
                printf(", ");
            } else if (c < '\40') {
                printf("\\%o", c);
            } else if (c == '\\') {
                printf("\\\\");
            } else {
                printf("%c", c);
            }
        }
    }
    if (item->flags & APE_ITEM_READ_ONLY) {
        printf(" [READ_ONLY]");
    }
    printf("\n");
}
