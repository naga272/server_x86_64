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


%ifndef SERVER_ASM
%define SERVER_ASM

%include "./utilities/sstring.asm"
%include "./utilities/thread.asm"
%include "./utilities/stdio.asm"
%include "./utilities/paths.asm"
%include "./utilities/net.asm"


section .rodata
    path_index  db "/templates/index.html", 0x00
    ; path_page2  db "./templates/page2.html", 0x00
    ; path_page3  db "./templates/page3.html", 0x00
    path_404        db "./templates/page404.html", 0x00
    home_path       db "/", 0x00

section .data

argc: dq 0x00
argv: dq 0x00
envp: dq 0x00

section .bss
section .text
global _start
;
;
;
; char* get_content_file(char* path)
get_content_file:
    STARTFOO
    push rdi
    push rsi 
    push rdx
    push r10
    push r13

    mov rsi, O_RDONLY
    mov rdx, CLASSIS
    call open
    cmp rax, -1
    je .page_not_found
    .continue:
    mov r10, rax

    ; max 124000 char per pagina
    mov rdi, 124000
    call calloc
    mov r13, rax

    mov rsi, r13
    mov rdx, 124000
    mov rdi, r10
    mov rax, 0
    syscall

    ; char* container ora punta al contenuto del file html
    ; NB: liberare l'heap

    mov rdi, r10
    call close

    ;mov rdi, r13
    ;call print

    mov rax, r13
    pop r13
    pop r10
    pop rdx
    pop rsi
    pop rdi
    leave
    ret
    .page_not_found:
        mov rdi, path_404
        ; call print
 
        mov rsi, O_RDONLY
        mov rdx, CLASSIS
        call open
        test rax, rax
        js .error
        jmp .continue 

    .error:
        mov rdi, EXIT_FAILURE
        call _exit
;
;
;
;
; char* calculate_response(char* rdi)
calculate_response:
    STARTFOO
    push r12
    push r13
    push r14

    ; mov rdi, path_index
    call get_content_file
    mov r14, rax            ; r14 = content allocato dinamicamente

    mov rdi, r14
    call strlen
    mov r13, rax            ; r13 = lunghezza contenuto

    ; ===  BUFFER PER RESPONSE  ===
    mov rdi, 125000           ; header + spazio per content html
    add rdi, r13
    call calloc
    mov r12, rax

    ; ORA MI OCCUPO DI COSTRUIRE L'HEADER DEL PACCHETTO
    mov rdi, r12
    mov rsi, response.status
    call strcat

    mov rdi, r12
    mov rsi, response.type
    call strcat

    mov rdi, r12
    mov rsi, response.length
    call strcat

    ; aggiungo la lunghezza del body
    mov rdi, r13
    call int_to_str
    mov rsi, rax
    mov rdi, r12
    call strcat

    push rsi
    mov rdi, rsi
    call free
    pop rsi
    
    mov rdi, r12
    mov rsi, response.conn
    call strcat

    mov rdi, r12
    mov rsi, response.keep
    call strcat
    
    mov rdi, r12
    mov rsi, response.cache
    call strcat
    
    mov rdi, r12
    mov rsi, response.server
    call strcat
    
    ; aggiungo i due NewLine
    mov rdi, r12
    mov rsi, response.head4
    call strcat

    ; aggiungo il body
    mov rdi, r12
    mov rsi, r14
    call strcat

    ; free content html letto
    mov rdi, r14
    call free

    mov rax, r12

    pop r14
    pop r13
    pop r12
    leave
    ret

;
;
;
;
; void children_handle(char* rdi, long fd_client)
children_handle:
    STARTFOO
    ; salvo fd client
    mov r12, rsi     
    ; non posso usare variabili globali,
    ; altrimenti rischio che i thread si rubano i dati
    ; quindi uso una variabile locale per inserire un ptr a heap
    ; oltre a 8 byte per il ptr al contenuto del fd,
    ; ho bisogno di 8 bytes per il ptr al contenuto della pagina
    ; html richiesta dal client

    mov rdi, 4096
    call calloc
    mov r13, rax    ; -> char* content_fd_client

    ; lettura dal socket
    mov rdi, r12        ; fd client
    mov rsi, r13        ; buffer
    mov rdx, 4096       ; lascia spazio per il null terminator
    mov rax, 0
    syscall

    ; Caso errore non mando nessuna risposta
    test rax, rax
    jle .end

    ; inserisco il null terminator
    ; (rax contiene il no. di bytes letti da fd client)
    mov byte[r13 + rax - 1], 0x00

    mov rdi, r13
    call get_path

    mov rdi, rax
    mov rsi, home_path
    call strcmp

    mov rsi, path_index
    test rax, rax
    cmove rdi, rsi

    ; aggiungo all'inizio del percorso richiesto il char '.'
    ; questo perchè fd_client contiene percorsi come "/templates/index.html"
    ; e quindi non finisce nella cartella templates del progetto
    mov rsi, 46
    call str_prepend
    
    mov r14, rax
    mov rdi, rax
    call calculate_response

    mov rdi, rax
    call strlen

    mov rdx, rax 
    mov rsi, rdi
    mov rdi, r12
    mov rax, 1
    syscall
    
    .end:
        ; ripristino heap e stack
        call free

        mov rdi, r14
        call free

        mov rdi, r13
        call free

        ; chiudo fd client
        mov rdi, r12
        call close

        leave
        ret
;
;
;
main:   
    STARTFOO

    mov rdi, AF_INET
    mov rsi, SOCK_STREAM
    mov rdx, TCP
    call socket
    mov r9, rax                     ; salvo in r9 il fd

    mov rdi, r9                     ; socket fd
    mov rsi, sockaddr_in            ; (struct sockaddr_in*) &rsi
    mov rdx, len_sockaddr_in        ; sizeof(struct sockadd_in)
    call bind

    mov rdi, r9     ; socket fd
    mov rsi, 1     ; numero massimo di client che si mettono in coda sul socket
    call listen

    push rdi
    push rsi
    push rdx
    mov rdi, in_ascolto
    call print
    pop rdx
    pop rsi
    pop rdi

    .loop:  push r9

        mov rdi, r9
        xor rsi, rsi
        xor rdx, rdx
        call accept     ; int new_fd = accept(fd_sock, NULL, NULL);

        test rax, rax
        js .loop        ; skip se accept fallisce

        mov rdi, children_handle
        mov rsi, accepted_request
        mov rdx, rax
        call create_thread

        pop r9
        jmp .loop

    mov rax, 0
    leave
    ret


testing:
    STARTFOO

    call get_path
    mov r14, rax

    mov rdi, rax
    mov rsi, 46
    call str_prepend

    mov rdi, rax
    call calculate_response

    mov rdi, rax
    call print

    call free

    mov rdi, r14
    call free

    leave
    ret


_start:
    mov [argc], rdi
    mov [argv], rsi
    mov [envp], rdx
    GXOR
    call main
    ; mov rdi, 100
    ; call int_to_str
    ; mov rdi, test_path
    ; call testing
    mov rdi, rax
    call _exit


%endif