#include <stdio.h>
#include <stdlib.h>
#include <string.h>


typedef struct PatriciaNode {
    char *prefix;                // prefisso
    char *value;                 // valore associato (es. handler)
    struct PatriciaNode **children;
    size_t child_count;
} PatriciaNode;


PatriciaNode* create_node(const char *prefix, const char *value)
{
    PatriciaNode *node = malloc(sizeof(PatriciaNode));
    node->prefix = strdup(prefix);
    node->value = value ? strdup(value) : NULL;
    node->children = NULL;
    node->child_count = 0;
    return node;
}


void add_child(PatriciaNode *parent, PatriciaNode *child)
{
    parent->children = realloc(parent->children, sizeof(PatriciaNode*) * (parent->child_count + 1));
    parent->children[parent->child_count++] = child;
}


size_t common_prefix(const char *a, const char *b)
{
    size_t i = 0;
    while (a[i] && b[i] && a[i] == b[i]) i++;
    return i;
}


void patricia_insert(PatriciaNode *root, const char *key, const char *value)
{
    for (size_t i = 0; i < root->child_count; i++) {
        PatriciaNode *child = root->children[i];
        size_t prefix_len = common_prefix(key, child->prefix);
        if (prefix_len == 0) continue;

        if (prefix_len < strlen(child->prefix)) {
            // split nodo
            PatriciaNode *split = create_node(child->prefix + prefix_len, child->value);
            split->children = child->children;
            split->child_count = child->child_count;

            child->prefix[prefix_len] = '\0';
            child->children = NULL;
            child->child_count = 0;
            child->value = NULL;

            add_child(child, split);
        }

        if (prefix_len < strlen(key)) {
            patricia_insert(child, key + prefix_len, value);
        } else {
            child->value = strdup(value);
        }
        return;
    }

    // nessun prefisso comune allora nuovo figlio
    add_child(root, create_node(key, value));
}


char* patricia_search(PatriciaNode *root, const char *key)
{
    for (size_t i = 0; i < root->child_count; i++) {
        PatriciaNode *child = root->children[i];
        size_t prefix_len = common_prefix(key, child->prefix);
        if (prefix_len == 0) continue;

        if (prefix_len == strlen(key) && prefix_len == strlen(child->prefix)) {
            return child->value;
        } else if (prefix_len < strlen(child->prefix)) {
            return NULL; // non trovato
        } else {
            return patricia_search(child, key + prefix_len);
        }
    }
    return NULL;
}
