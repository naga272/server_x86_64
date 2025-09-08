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


%ifndef STDLIB_ASM
%define STDLIB_ASM

%include "./utilities/macro.asm"
%include "./utilities/sstring.asm"

; Access mode (mutuamente esclusivi)
%ifndef O_RDONLY
%define O_RDONLY      0o000000    ; sola lettura
%endif

%ifndef O_WRONLY
%define O_WRONLY      0o000001    ; sola scrittura
%endif

%ifndef O_RDWR
%define O_RDWR        0o000002    ; lettura e scrittura
%endif

%ifndef O_ACCMODE
%define O_ACCMODE     0o000003    ; mask per i 3 sopra
%endif

%define CLASSIS 0o644   ; lettura / scrittura file di testo classici
%define BINARY  0o755   ; eseguibile pubblico
%define O_OWNER 0o600   ; solo owner

%define S_IRUSR 0o400   ; read by owner
%define S_IWUSR 0o200   ; write by owner
%define S_IXUSR 0o100   ; execute by owner

%define S_IRGRP 0o040   ; read by group
%define S_IWGRP 0o020   ; write by group
%define S_IXGRP 0o010   ; execute by group

%define S_IROTH 0o004   ; read by others
%define S_IWOTH 0o002   ; write by others
%define S_IXOTH 0o001   ; execute by others


; File creation / status flags
%ifndef O_CREAT
%define O_CREAT       0o000100    ; crea se non esiste
%endif

%ifndef O_EXCL
%define O_EXCL        0o000200    ; con O_CREAT: fallisce se il file esiste
%endif

%ifndef O_NOCTTY
%define O_NOCTTY      0o000400    ; non diventare controlling tty
%endif

%ifndef O_TRUNC
%define O_TRUNC       0o001000    ; tronca il file se già esiste
%endif

; File status flags
%ifndef O_APPEND
%define O_APPEND      0o002000    ; scrittura in append
%endif

%ifndef O_NONBLOCK
%define O_NONBLOCK    0o004000    ; I/O non bloccante
%endif

%ifndef O_DSYNC
%define O_DSYNC       0o010000    ; scritture sincrone (data)
%endif

%ifndef FASYNC
%define FASYNC        0o020000    ; notifica asincrona (obsolete)
%endif

%ifndef O_DIRECT
%define O_DIRECT      0o040000    ; I/O diretto (salta il cache)
%endif

%ifndef O_LARGEFILE
%define O_LARGEFILE   0o100000    ; (compatibilità 32-bit)
%endif

; Directory e symlink handling
%ifndef O_DIRECTORY
%define O_DIRECTORY   0o200000    ; deve essere una directory
%endif

%ifndef O_NOFOLLOW
%define O_NOFOLLOW    0o400000    ; non seguire symlink
%endif

%ifndef O_CLOEXEC
%define O_CLOEXEC     0o2000000   ; close-on-exec (FD_CLOEXEC)
%endif

; flags per mmap
%ifndef MAP_PRIVATE
%define MAP_PRIVATE     0x02      ; Cambi locali, niente sync su file
%endif

%ifndef MAP_ANONYMOUS
%define MAP_ANONYMOUS   0x20      ; Nessun file backing (solo RAM)
%endif


%ifndef MAP_STACK
%define MAP_STACK       0x20000   ; Allocazione ottimizzata per stack
%endif


%ifndef MAP_GROWSDOWN
%define MAP_GROWSDOWN   0x00100   ; Stack cresce verso indirizzi bassi
%endif

; FLAGS X MEM PROT ;
%ifndef PROT_READ
%define PROT_READ       0x1
%endif


%ifndef PROT_WRITE
%define PROT_WRITE      0x2
%endif


%ifndef PROT_EXEC
%define PROT_EXEC       0x4
%endif


%ifndef PROT_NONE
%define PROT_NONE       0x8
%endif


; BLOCKS
%define HEAP_BLOCK_SIZE 4096
%define STD_HEAP_MAX_BLOCK_SIZE_PROGRAM (104857600 / HEAP_BLOCK_SIZE)


section .rodata
    msg_err_malloc          db "Si e' verificato un'errore nel tentativo di allocazione della memoria", ENDL, 0x00
    msg_err_open_file       db "errore nel tentativo di aprire il file", ENDL, 0x00

section .text

mmap:   
    STARTFOO

    mov rax, 9
    syscall

    leave
    ret


; void* malloc(size_t rdi)
malloc: STARTFOO
    push r9
    push r8
    push r10
    push rsi

    mov rsi, rdi
    mov rdi, 0x00
    mov rdx, PROT_WRITE | PROT_READ         ; 0b0011
    mov r10, 0x22
    mov r8, -1
    mov r9, 0x00
    call mmap
    
    test rax, rax

    pop rsi
    pop r10
    pop r8
    pop r9

    js .error
    leave
    ret
    .error: lea rdi, [rel msg_err_malloc]
            call print
            mov rdi, EXIT_FAILURE
            call _exit


; void* memset(void* rdi, char sil, long int rdx)
memset:
    STARTFOO
    push rcx
    push rdx

    mov al, sil      ; byte da scrivere
    mov rcx, rdx     ; numero di byte
    cld              ; direzione crescente
    rep stosb        ; scrivi RCX volte AL in [RDI]
    mov rax, rdi     ; ritorna puntatore originale

    pop rdx
    pop rcx
    leave
    ret


; void* calloc(size_t rdi)
calloc: STARTFOO
    push rsi

    push rdi
    call malloc
    pop rdi

    mov rdx, rdi    ; size_t
    mov rsi, 0x0    ; int n
    mov rdi, rax    ; void*
    
    call memset
    pop rsi
    leave
    ret


; void* realloc(void* rdi, size_t rsi)
; rsi e' la nuova grandezza
realloc: STARTFOO
    push r14
    push rcx

    push rdi        ; salvo il ptr attuale
    mov rdi, rsi    ; nuova grandezza
    call calloc
    pop rdi         ; ripristino il ptr passato come parametro

    push rdi        ; salvo void* ptr passato come parametro a realloc

    ; void* strcat(char* rdi, char* rsi)
    mov rsi, rdi    ; ptr passato come parametro a realloc
    mov rdi, rax    ; nuovo ptr allocato
    call strcat
    mov r14, rdi

    pop rdi         ; ripristino il ptr passato come parametro a realloc
    call free       ; libero la zona allocata del ptr passato come parametro a realloc

    mov rdi, r14
    mov rax, rdi
    pop rcx
    pop r14
    leave
    ret


; void munmap(void* rdi)
munmap:
    STARTFOO

    cmp rdi, 0x00
    je .NULL

    mov rax, 11
    syscall

    .NULL:
        leave
        ret


; void free(void* rdi)
free:
    STARTFOO

    cmp rdi, 0x00
    je .NULL        ; in caso si tenta di fare la free di un ptr nullo
    call munmap

    .NULL:
        leave
        ret


; FILE* open(char* PATH, long int FLAGS, long int mode)
open:   
    STARTFOO
    ; proprieta' file
    ; %define O_WRONLY 0o010
    ; %define O_RDONLY 0o100
    ; %define O_TRUNC  0o001

    mov rax, 2
    syscall
    test rax, rax
    js .error_fd

    leave
    ret
    .error_fd:
        mov rax, -1
        leave
        ret


; void close(long int rdi)
close:  STARTFOO
        cmp rdi, 0x00
        je .NULL
        mov rax, 3
        syscall
        .NULL:  leave
                ret


; void _exit(long int rdi)
_exit: 
    STARTFOO
    mov rax, 60
    syscall

%endif
