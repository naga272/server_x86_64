%ifndef NET_ASM
%define NET_ASM

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
        ;   OPZIONALI   ;
        .conn:   db "Connection: keep-alive", ENDL, 0x00
        .keep:   db "Keep-Alive: timeout=5, max=100", ENDL, 0x00
        .cache:  db "Cache-Control: public, max-age=31536000", ENDL, 0x00
        .server: db "Server: AssemblyServer/0.1", ENDL, 0x00
        ; ------------- ;
        .head4:  db ENDL, ENDL, 0x00
        .body:   dq 0x00         ; string* che contiene il corpo del file html
    end_response:

    ; offsets struct response
    %define status  end_response - response
    %define type    end_response - response.type
    %define length  end_response - response.length
    %define head4   end_response - response.head4
    %define body    end_response - response.body

section .data

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

section .text

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

%endif
