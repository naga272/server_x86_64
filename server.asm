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
%include "./utilities/sqlite3.asm"
%include "./utilities/rodata_things.asm"
%include "./utilities/cookies.asm"


section .data

argc: dq 0x00
argv: dq 0x00
envp: dq 0x00
fd_sock: dq 0x00

section .bss
    db_obj resq 1
section .text
global _start


; int && char* && size_t is_cached(char* path)
is_cached:
    ; restituisce in rax 0 se e' stato matchato il percorso
    ; restituisce in rdx il ptr a cached (se rax == 0)
    ; restituisce in rcx la len di rcx
    ;
    ; in caso non trovato restituisce semplicemente -1
    STARTFOO

    mov rsi, path_index
    call strcmp
    je .get_cache_index

    mov rax, -0x01
    .exit:
        leave
        ret
    .get_cache_index:
        mov rax, 0x00               ; stato uscita (IMPORTANTE)
        mov rdx, [cache_index]      ; ptr a heap (char*)

        ; il path potrebbe matchare
        ; ma potrebbe essere che il ptr e' NULL perche' è la prima chiamata
        cmp qword[rdx], 0x00
        jz .not_in_chached
        mov rcx, [cache_index + 8]  ; len(char*)
        jmp .exit

    .not_in_chached:
        mov rax, -0x01
        jmp .exit


; void do_cache(char* path, char* content, size_t len_content)
do_cache:
    STARTFOO
    push r13
    push rdi
    push rsi
    push rdx

    mov rsi, path_index
    call strcmp
    cmp rax, 0x00
    je .set_cache_index

    mov rsi, path_page2
    call strcmp
    cmp rax, 0x00
    je .set_cache_page2

    .end:
        pop rdi
        pop r13
        leave
        ret
    .set_cache_index:
        pop rdx
        pop rsi
        mov r13, path_index
        mov qword[r13], rsi
        mov qword[r13 + 8], rdx
        jmp .end
    .set_cache_page2:
        pop rdx
        pop rsi
        jmp .end


; char* get_content_file(char* path)
get_content_file:
    ; restituisce un ptr che punta a una zona allocata dinamicamente.
    STARTFOO
    push rdi
    push rsi
    push r10
    push r11
    push r12
    push r13

    mov rsi, O_RDONLY
    mov rdx, CLASSIS
    call open
    cmp rax, -1
    je .page_not_found

    .continue:
        mov r10, rax    ; fd

        ; ottengo struct stat
        ; sizeof(struct stat) = 144 + 1 padding (per sicurezza)
        mov rdi, 145
        call malloc
        mov rsi, rax
        mov rdi, r10    ; fd
        mov rax, 5
        syscall

        ; [rax + 0x30] == off_t st_size; // 8 bytes
        mov r12, [rsi + 0x30]
        mov rdi, r12
        call malloc
        mov r13, rax

        ; la struct stat e' allocata dinamicamente
        ; devo liberarla perche' non mi serve piu'
        sub rdi, 0x30
        call free

        mov rsi, r13
        mov rdx, r12
        mov rdi, r10
        mov rax, 0
        syscall

        mov r11, rax
        mov rdi, r10
        call close

        ;mov rdi, r13
        ;call print

        mov rax, r13
        mov rdx, r12
        pop r13
        pop r12
        pop r11
        pop r10
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


; char* && size_t calculate_response(char* rdi)
calculate_response:
    ; restituisce un ptr che punta a una zona allocata dinamicamente.
    ; questo ptr ha formattata la response completa da dare al client.
    STARTFOO
    push r12
    push r13
    push r14

    ; mov rdi, path_index
    call get_content_file
    mov r14, rax            ; r14 = content allocato dinamicamente

    ; ===  BUFFER PER RESPONSE  ===
    mov rdi, rdx            ; len(content html)
    add rdi, 4096           ; header
    push rdi                ; len(header + content)

    call malloc
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

    pop rdi
    mov rdx, rdi
    mov rax, r12

    pop r14
    pop r13
    pop r12
    leave
    ret


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
    call malloc
    mov r13, rax    ; -> char* content_fd_client

    ; lettura dal socket
    mov rdi, r12        ; fd client
    mov rsi, r13        ; buffer
    mov rdx, 4096       ; lascia spazio per il null terminator
    mov rax, 0
    syscall

    mov rdi, rsi
    call print

    ; Caso errore non mando nessuna risposta
    test rax, rax
    jle .end

    ; inserisco il null terminator
    ; (rax contiene il no. di bytes letti da fd client)
    mov byte[r13 + rax - 1], 0x00

	push r13 		; content fd_client
    
	mov rdi, r13
    call get_path
    mov rdi, rax

	pop r13

    push rdi                ; rbp + 8

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
    push rax                ; rbp + 16

    mov r14, rax
    mov rdi, rax
    call calculate_response

    mov r13, rax        ; r13 = *ptr->heap
    mov r14, rdx        ; r14 = len(*ptr->heap)

    sub rsp, 4
    mov dword[rbp + 20], 1   ; int on = 1;

    ; WARNING:
    ; Effetto di questo setsockopt:
    ;   - Normalmente TCP cerca di accorpare pacchetti piccoli (ad esempio risposte HTTP di pochi byte)
    ;       per ridurre l’overhead di rete, introducendo un piccolo ritardo in attesa di più dati da inviare insieme.
    ;   - Con TCP_NODELAY = 1, ordini al kernel di inviare subito ogni pacchetto senza buffering.
    ; Risultato: Latenza ridotta ma se usato per inviare molti pacchetti piccoli viene ridotta l'efficienza
    mov rdi, [fd_sock]                                  ; fd socket server
    mov rsi, TCP                                        ; Tipo di connessione
    mov rdx, TCP_NODELAY | SO_REUSEPORT | SO_REUSEADDR
    mov r10, rbp                                        ; address stack on
    add r10, 4
    mov r8, 4                                           ; sizeof(int)
    call setsockopt

    mov rdx, r14 
    mov rsi, r13
    mov rdi, r12
    mov rax, 1
    syscall

    ; Devo resettare
    mov rdi, [fd_sock]                                      ; fd socket server
    mov dword[rbp + 20], 0                                  ; int on = 0;
    mov rdi, [fd_sock]                                      ; fd_socket
    mov rsi, TCP                                            ; Tipo di connessione
    mov rdx, TCP_NODELAY | SO_REUSEPORT | SO_REUSEADDR
    mov r10, rbp                                            ; address stack on
    add r10, 4
    mov r8, 4                                               ; sizeof(int)
    call setsockopt

    .end:
        ; devo dare priorita' alla chiusara del fd client
        ; poi il resto
        mov rdi, r12
        call close

        mov rdi, qword[rbp + 16]    ; ptr->heap causato da str_prepend 
        call free

        mov rdi, r13                ; ptr->heap causato da calculate_response
        call free

        mov rdi, qword[rbp + 8]     ; ptr->heap causato da get_path
        call free

        add rsp, 20                 ; libero lo stack

        leave
        ret


; int main(int rdi, char **rsi)
main:
    STARTFOO

    ; creo tabella utenti
    ;mov rdi, [db_obj]
    ;mov rsi, table_user
    ;call do_table_sqlite
    ; === END SET database ===

    ; ora mi occupo di mettere on il web server
    mov rdi, AF_INET
    mov rsi, SOCK_STREAM
    mov rdx, TCP
    call socket
    mov [fd_sock], rax
    mov r9, rax                     ; salvo in r9 il fd

    mov rdi, r9                     ; socket fd
    mov rsi, sockaddr_in            ; (struct sockaddr_in*) &rsi
    mov rdx, len_sockaddr_in        ; sizeof(struct sockadd_in)
    call bind

    mov rdi, r9     ; socket fd
    mov rsi, 20     ; numero massimo di client che si mettono in coda sul socket
    call listen

    mov rdi, in_ascolto
    call print

    .loop:
        push r9

        mov rdi, r9
        xor rsi, rsi
        xor rdx, rdx
        call accept     ; int new_fd = accept(fd_sock, NULL, NULL);

        test rax, rax
        js .loop        ; skip se accept fallisce

        mov rdi, children_handle
        mov rdx, rax
        call create_thread

        pop r9
        jmp .loop

    mov rax, 0
    leave
    ret


; ===== SEZIONE TESTING =====
section .data
post_req: db "POST /<path> ", 0x00
section .text
testing:
    STARTFOO

    mov rdi, post_req
    call get_method

    mov rdi, rax
    call print

    call free

    leave
    ret

; ===== FINE SEZIONE TESTING =====


_start:
    mov [argc], rdi
    mov [argv], rsi
    mov [envp], rdx
    GXOR
    call main
    ; call testing
    mov rdi, rax
    call _exit



foo:
    STARTFOO

    call foo
    leave
    ret

%endif
