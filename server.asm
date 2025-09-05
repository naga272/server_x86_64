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


%ifndef AF_INET
%define AF_INET 2               ; IPV4
%endif

%ifndef SOCK_STREAM
%define SOCK_STREAM 1           ; tipo socket
%endif

%ifndef TCP
%define TCP 6                   ; protocollo TCP
%endif

%ifndef IPPROTO_UDP
%define IPPROTO_UDP 17          ; protocollo UDP
%endif


section .rodata
    neg_res_sock            db "errore nel tantito di creare una socket", ENDL, 0x00
    neg_res_bind            db "errore durante la fase di binding", ENDL, 0x00
    neg_res_listen          db "errore nel tentativo di mettersi in ascolto", ENDL, 0x00
    neg_res_accept          db "Impossibile accettare la connessione", ENDL, 0x00
    neg_res_fd_client       db "impossibile leggere il contenuto del fd del client", ENDL, 0x00 

    suc_res_sock            db "creazione della socket avvenuta con successo", ENDL, 0x00
    suc_res_bind            db "fase binding completata con successo", ENDL, 0x00
    suc_res_listen          db "messo in ascolto correttamente", ENDL, 0x00
    in_ascolto              db "http://127.0.0.1:9000", ENDL, 0x00
    accepted_request        db "richiesta accettata", ENDL, 0x00

    response: 
        .status: db "HTTP/1.1 200 OK", ENDL, 0x00
        .type:   db "Content-Type: text/html", ENDL, 0x00
        .length: db "Content-Length: ", 0x00
        .head4:  db ENDL, ENDL, 0x00
        .body:   dq 0x00         ; string* che contiene il corpo del file html
    end_response:

    path_index db "./index.html", 0x00

section .data


%ifndef sockaddr_in_start
%define sockaddr_in_start

sockaddr_in:
    .sin_fam:       db AF_INET, 0x00
    .porta:         db 0x23, 0x28
    .ip_addr:       db 127, 0, 0, 1
    .padding:       dq 0x00
    .end_sockaddr_in:


; offsets struct sockaddr_in 
%define len_sockaddr_in sockaddr_in.end_sockaddr_in - sockaddr_in
%define off_sin_family  end_sockaddr_in - sockaddr_in.sin_family
%define off_sin_port    end_sockaddr_in - sockaddr_in.sin_port
%define off_ip_addr     end_sockaddr_in - sockaddr_in.ip_addr
%define off_pad         end_sockaddr_in - sockaddr_in.pad

%endif

section .bss
section .text


;offsets struct response
%define status  end_response - response
%define type    end_response - response.type
%define length  end_response - response.length
%define head4   end_response - response.head4
%define body    end_response - response.body


socket: STARTFOO
    mov rax, 41
    syscall

    test rax, rax
    js .error

    leave
    ret
    .error: mov rdi, neg_res_sock
            call print
            mov rdi, EXIT_FAILURE
            call _exit
;
;
;
;
; int bind(int sock_fd, struct sockaddr_in* rsi, size_t rdx);
bind:   ; funzione che assegna ip e porta
    ; rax == 0 if OK
    STARTFOO

    mov rax, 49
    syscall
    test rax, rax
    js .error
    leave
    ret

    .error: mov rdi, neg_res_bind
            call print
            mov rdi, EXIT_FAILURE
            call _exit
;
;
listen: STARTFOO
    mov rax, 50
    syscall
    test rax, rax
    js .error
    leave
    ret

    .error: mov rdi, neg_res_listen
            call print
            mov rdi, EXIT_FAILURE
            call _exit
;
;
;
;
; int accept(int sock_fd, struct sockaddr_in* rsi, size_t rdx); 
accept: ; quando arriva una richiesta, accept restituisce un nuovo fd
    ; ret: rax >= 0 IF OK
    STARTFOO
    mov rax, 43
    syscall 
    test rax, rax
    js .error

    push rax                ; fd >= 0
    ;mov rdi, debug
    ;call print
    pop rax

    leave
    ret
    .error: mov rdi, neg_res_accept
            call print
            mov rdi, EXIT_FAILURE
            call _exit
;
;
;
; char* get_content_file(char* path, char* container)
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
;
;
;
;
; char* calculate_response(FILE* rdi)
calculate_response:
    STARTFOO
    push r12
    push r13
    push r14
    
    mov rdi, path_index
    call get_content_file
    mov r14, rax            ; r14 = content allocato dinamicamente

    ; Calcolo la len del contenuto senza considerare i \r
    mov rdi, r14
    call special_strlen
    mov r13, rax            ; r13 = lunghezza contenuto

    ; ===  BUFFER PER RESPONSE  ===
    mov rdi, 4096           ; header + spazio per content html
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
    ; r13           -> char* content_fd_client

    mov rdi, 4096
    call calloc
    mov r13, rax

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


_start: GXOR
        call main
        ; mov rdi, 100
        ; call int_to_str

        mov rdi, rax
        call _exit


%endif

