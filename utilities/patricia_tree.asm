; ======================================================================================
;
; Copyright (c) 2025, Bastianello Federico
; All rights reserved.
;
; Redistribution and use in source and binary forms, with or without modification, 
; are permitted provided that the following conditions are met:
;
; 1. Redistributions of source code must retain the above copyright notice, 
;   this list of conditions and the following disclaimer.
;
; 2. Redistributions in binary form must reproduce the above copyright notice, 
;   this list of conditions and the following disclaimer in the documentation 
;   and/or other materials provided with the distribution.
;
; THIS SOFTWARE IS PROVIDED "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES ARE 
; DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER BE LIABLE FOR ANY DAMAGES 
; ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE.
; Contributions and original code available at: https://github.com/naga272/server_x86_64
;
;
; ======================================================================================


%ifndef PATRICIA_TREE
%define PATRICIA_TREE
;
;   WARNING: NON ANCORA COMPLETATO
;
;
; Una Patricia Tree è un albero dove ogni nodo rappresenta un prefisso comune delle chiavi.
; Invece di avere un nodo per ogni carattere (come un trie classico), i nodi compressi contengono sequenze di caratteri comuni.
; Serve a lookup molto veloce di stringhe e a risparmiare memoria.
;
; ===== CARATTERISTICHE NODI =====
; @prefix: la stringa compressa (più caratteri insieme)
; @children: ptr a nodi figli
; @value: opzionale, il dato associato se il nodo è un termine di chiave
; @bit/char index: talvolta per decidere quale branch prendere
;
; Inseriamo: "home", "home/about", "home/blog"
;
;        "home"
;        /    \
;  "/about"  "/blog"
;
; - "home" è il prefisso comune -> nodo compressato
; - I suffissi diversi -> nodi figli
;
; STEPS
; - Parti dalla radice
; - Confronta il prefisso del nodo con la stringa da inserire
; - Trova il punto di divergenza
; - Se necessario, splitta il nodo in due parti:
;       - Prefisso comune
;       - Restante dei vecchi figli
;       - Nuova chiave come figlio separato

%include "./utilities/macro.asm"
%include "./utilities/stdio.asm"
%include "./utilities/sstring.asm"
%include "./utilities/stdlib.asm"
%include "./utilities/string.asm"

section .rodata

%ifndef struct_patricia_node
%define struct_patricia_node

struct_PatriciaNode:
    .prefix:        dq 0x00     ; String* prefix
    .value:         dq 0x00     ; String* value
    .children:      dq 0x00     ; struct PatriciaNode **children
    .child_count:   dq 0x00     ; long child_count
    .struct_endPatriciaNode:
%endif

section .data
section .bss
section .text
global _start

%define len_struct_patricianode struct_PatriciaNode.struct_endPatriciaNode - struct_PatriciaNode 
%define off_prefix      struct_PatriciaNode.struct_endPatriciaNode - struct_PatriciaNode.prefix
%define off_value       struct_PatriciaNode.struct_endPatriciaNode - struct_PatriciaNode.value
%define off_children    struct_PatriciaNode.struct_endPatriciaNode - struct_PatriciaNode.children
%define off_child_count struct_PatriciaNode.struct_endPatriciaNode - struct_PatriciaNode.child_count


; struct_PatriciaNode* create_node(char* prefix, char* value)
create_node:
    STARTFOO

    push r12
    push r13
    ; rdi = prefix (char*), rsi = value (char* or 0)
    mov r12, rdi   ; save prefix param
    mov r13, rsi   ; save value param

    ; create String from prefix
    mov rdi, r12
    call String
    mov r14, rax   ; prefix string*

    ; allocate node
    mov rdi, len_struct_patricianode
    call calloc
    mov r15, rax

    mov [r15 + off_prefix], r14

    ; create value String if non-null
    mov rdi, r13
    test rdi, rdi
    jz .no_value
    call String
    mov [r15 + off_value], rax
    jmp .cont
    .no_value:
        mov qword [r15 + off_value], 0

    .cont:
        mov qword [r15 + off_children], 0
        mov qword [r15 + off_child_count], 0
        mov rax, r15

        pop r13
        pop r12
        pop rbp
        leave
        ret


; void add_child(PatriciaNode *parent, PatriciaNode *child)
add_child:
    STARTFOO

    push rbx
    push r12
    push r13

    mov r12, rdi    ; parent
    mov r13, rsi    ; child

    ; old_count = parent->child_count
    mov rbx, [r12 + off_child_count]
    mov rdi, [r12 + off_children]   ; ptr (may be NULL)
    mov rsi, rbx
    inc rsi
    imul rsi, 8                     ; (old_count + 1) * sizeof(ptr)
    call realloc
    ; rax = new pointer to array (or NULL on OOM)
    test rax, rax
    je .oom                         ; (optional) handle OOM

    ; store returned pointer back into parent->children
    mov [r12 + off_children], rax

    ; compute insertion address: rax + old_count*8
    mov rcx, rbx
    imul rcx, 8
    add rax, rcx
    mov [rax], r13                  ; array[old_count] = child

    ; increment parent->child_count
    inc qword [r12 + off_child_count]

    pop r13
    pop r12
    pop rbx

    leave
    ret

    .oom:
        ; here just return (no change) — caller must check
        pop r13
        pop r12
        pop rbx

        leave
        ret

    

; size_t common_prefix(const char *a, const char *b)
; rdi = char* a
; rsi = String* b
; ritorna in rax = lunghezza prefisso comune
common_prefix:
    STARTFOO
    push rbx
    xor rax, rax          ; i = 0
    .loop:
        mov bl, byte[rdi + rax]
        mov bh, byte[rsi + rax]
        test bl, bl           ; a[i] != 0 ?
        jz .done
        test bh, bh           ; b[i] != 0 ?
        jz .done
        cmp bl, bh            ; a[i] == b[i] ?
        jne .done
        inc rax
        jmp .loop
    .done:
        pop rbx
        leave
        ret


; void patricia_insert(PatriciaNode *root, char* key, String* value)
; PatriciaNode rdi = root
; char* rsi = key
; String* rdx = value

; void patricia_insert(PatriciaNode *root, char* key, String* value)
; rdi = root
; rsi = key   (char*)
; rdx = value (String*)
patricia_insert:
    STARTFOO
    ; prologo: salvo i callee-saved che uso

    push rbx
    push r12
    push r13
    push r14
    push r15

    ; salvo parametri in registri non-clobberati dalle chiamate
    mov r11, rdi        ; r11 = root (lo userò sempre come base)
    mov r12, rsi        ; r12 = key (char*)
    mov r13, rdx        ; r13 = value (pass-through)

    xor rcx, rcx        ; rcx = i = 0 (index)

    .for_loop:
        ; if (i >= root->child_count) goto no_child_match
        mov rax, [r11 + off_child_count]
        cmp rcx, rax
        jae .no_child_match

        ; child = root->children[i]
        mov rax, [r11 + off_children]     ; rax = ptr to array
        mov r14, [rax + rcx*8]            ; r14 = child

        ; prefix_len = common_prefix(key, child->prefix->content)
        mov rdi, r12                       ; arg1 = key (char*)
        mov rsi, [r14 + off_prefix]        ; rsi = String*
        mov rsi, [rsi + content]           ; rsi = child->prefix->content (char*)
        call common_prefix
        mov rbx, rax                       ; rbx = prefix_len

        cmp rbx, 0
        je .next_child                     ; if prefix_len == 0 -> continue

        ; len_child_prefix = strlen(child->prefix->content)
        mov rdi, [r14 + off_prefix]
        mov rdi, [rdi + content]
        call strlen
        mov rdx, rax                       ; rdx = len_child_prefix

        cmp rbx, rdx
        jae .no_split                      ; if prefix_len >= len_child_prefix -> no split

        ; ==== SPLIT NODE ====
        ; create_node(child->prefix->content + prefix_len, child->value ? child->value->content : NULL)
        ; prepare rdi = child->prefix->content + prefix_len

        mov rdi, [r14 + off_prefix]
        mov rdi, [rdi + content]
        add rdi, rbx                       ; rdi = pointer to suffix

        ; prepare rsi = child->value ? child->value->content : 0
        xor rsi, rsi
        mov rax, [r14 + off_value]
        test rax, rax
        jz .skip_value_for_split
        mov rsi, [rax + content]

    .skip_value_for_split:
        call create_node                    ; returns new node in rax
        mov r15, rax                        ; r15 = split node

        ; split->children = child->children
        mov rax, [r14 + off_children]
        mov [r15 + off_children], rax

        ; split->child_count = child->child_count
        mov rax, [r14 + off_child_count]
        mov [r15 + off_child_count], rax

        ; truncate original child's prefix: child->prefix->content[prefix_len] = '\0'
        mov rax, [r14 + off_prefix]
        mov rax, [rax + content]
        add rax, rbx
        mov byte [rax], 0

        ; reset child fields (it becomes internal node)
        mov qword [r14 + off_children], 0
        mov qword [r14 + off_child_count], 0
        mov qword [r14 + off_value], 0

        ; add_child(child, split)
        mov rdi, r14
        mov rsi, r15
        call add_child

    .no_split:
        ; len_key = strlen(key)
        mov rdi, r12
        call strlen
        mov rax, rax        ; rax = len_key

        cmp rbx, rax
        jb .recurse_child   ; if prefix_len < len_key -> recurse into child

        ; else exact match (prefix_len >= len_key) -> set child->value = String(value)
        mov rdi, r13        ; rdi = value (char* or String arg depending on your String constructor)
        call String
        mov [r14 + off_value], rax
        jmp .done

    .recurse_child:
        ; patricia_insert(child, key + prefix_len, value)
        mov rdi, r14
        mov rsi, r12
        add rsi, rbx
        mov rdx, r13
        call patricia_insert
        jmp .done

    .next_child:
        inc rcx
        jmp .for_loop

    .no_child_match:
        ; add_child(root, create_node(key, value))
        ; we clobbered rdi earlier, restore from r11
        push r11             ; salva root (r11) sullo stack temporaneamente
        mov rdi, r12         ; arg1 = key
        mov rsi, r13         ; arg2 = value
        call create_node     ; returns node* in rax
        mov rsi, rax         ; rsi = new node pointer for add_child
        pop rdi              ; rdi = root (originario)
        call add_child
        ; dopo add_child continui e poi usciamo

    .done:
        ; epilogo
        pop r15
        pop r14
        pop r13
        pop r12
        pop rbx

        leave
        ret


; String* patricia_search(PatriciaNode *root, const char *key)
patricia_search:
    STARTFOO
    push rdi
    push rsi
    push rcx
    push r11
    push r12
    push r13
    push r14

    xor rax, rax               ; return NULL di default
    xor rcx, rcx               ; i = 0
    mov r12, rdi               ; root
    mov r13, rsi               ; key

    .main_for:
        cmp rcx, [r12 + off_child_count]
        jae .done                   ; fine for

        mov r14, [r12 + off_children]
        mov r14, [r14 + rcx*8]      ; child = root->children[i]

        ; prefix_len = common_prefix(key, child->prefix)
        mov rdi, r13
        mov rsi, [r14 + off_prefix]
        mov rsi, [rsi + content]
        call common_prefix
        mov r11, rax                ; prefix_len

        cmp r11, 0
        je .next_child               ; if (prefix_len == 0) continue;

        ; if (prefix_len == strlen(key))
        mov rdi, r13
        call strlen
        cmp r11, rax
        jne .else_if

        ; if (prefix_len == strlen(child->prefix))
        mov rdi, [r14 + off_prefix]
        mov rdi, [rdi + content]
        call strlen
        cmp r11, rax
        jne .else_if

        mov rax, [r14 + off_value]   ; return child->value
        jmp .done

    .else_if:
        mov rdi, [r14 + off_prefix]
        mov rdi, [rdi + content]
        call strlen
        cmp r11, rax
        jb .return_null              ; if (prefix_len < strlen(prefix)) return NULL;

        ; else → ricorsione
        mov rdi, r14
        mov rsi, r13
        add rsi, r11
        call patricia_search
        jmp .done

    .return_null:
        xor rax, rax
        jmp .done

    .next_child:
        inc rcx
        jmp .main_for

    .done:
        pop r14
        pop r13
        pop r12
        pop r11
        pop rcx
        pop rsi
        pop rdi
        leave
        ret


section .data
    root dq 0x00


main:
    STARTFOO
    
    mov rdi, 0x00
    mov rsi, 0x00
    call create_node
    mov qword[root], rax

    call patricia_insert
    call patricia_insert
    call patricia_insert
    mov rdi, rax
    call free
    
    leave
    ret


_start: endbr64
    call main
    mov rdi, rax
    call _exit


%endif

