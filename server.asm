
%ifndef SERVER_ASM
%define SERVER_ASM

%define TESTMAIN_SERVER

%include "./string.asm"

%ifndef STARTALLFOO
%define STARTALLFOO
%macro STARTFOO 0
        endbr64
        push rbp
        mov rbp, rsp
%endmacro
%endif

%ifndef GXOR_ALL
%define GXOR_ALL
%macro GXOR 0
        xor rax, rax
        xor rbx, rbx
        xor rcx, rcx
        xor rdx, rdx
%endmacro
%endif

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

%ifndef EXIT_SUCCESS
%define EXIT_SUCCESS 0
%endif

%ifndef EXIT_FAILURE
%define EXIT_FAILURE 1
%endif

%ifndef ENDL
%define ENDL 0x0d, 0x0a
%endif


%ifndef SYS_READ
%define SYS_READ 0x00
%endif

; proprieta' file
%define O_WRONLY 0o010
%define O_RDONLY 0o100
%define O_TRUNC  0o001


section .bss
        fd_buffer               resb 4096
        file_buffer             resb 4096
	digitSpace 	        resb 100
	digitSpacePos 	        resb 8
        request_path_buffer     resb 512
section .data

        %ifdef TESTMAIN_SERVER
                argc dq 1
                argv dq 1
                envp dq 1
        %endif

        %ifndef SOCKADDR_IN
        %define SOCKADDR_IN
        sockaddr_in:
                .sin_family:     db AF_INET, 0x00               ; 4 bytes
                .sin_port:       db 0x23, 0x28                  ; porta 9000 (in big endian)
                .ip_addr:        db 0x7f, 0x00, 0x00, 0x01      ; 4 bytes
                .pad:            dq 0x00                        ; padding di 8 bytes
        end_sockaddr_in:
        %endif

        msg_after_bind_correct  db "http://127.0.0.1:9000", ENDL, 0x00
        msg_err_socket          db "Impossibile creare la socket", ENDL, 0x00
        msg_err_bind            db "impossibile assegnare la porta e ip", ENDL, 0x00
        msg_err_listen          db "Impossibile mettersi in ascolto", ENDL, 0x00
        msg_err_accept          db "Impossibile accettare la connessione", ENDL, 0x00
        msg_accept              db "connessione accettata", ENDL, 0x00
        msg_err_open_file       db "errore nel tentativo di aprire il file", ENDL, 0x00
        msg_err_read_file       db "errore nel tentativo di lettura del file html", ENDL, 0x00

        ;        response db "HTTP/1.1 200 OK", ENDL
        ;               db "Content-Type: text/html", ENDL
        ;               db "Content-Length: 55", ENDL
        ;               db ENDL
        ;               db "<html><body><h1>Lorem Ipsum dolorem</h1></body></html>", ENDL, 0

        response: 
                .status: db "HTTP/1.1 200 OK", ENDL, 0x00
                .type:   db "Content-Type: text/html", ENDL, 0x00
                .length: db "Content-Length: ", 0x00
                .head4:  db ENDL, ENDL, 0x00
                .body:   dq 0x00         ; string* che contiene il corpo del file html
        end_response:

        response_x_index_GET    dq 0x00
        response_x_lol_GET      dq 0x00
        response_x_err_404      dq 0x00

        endln_str               db 0x0d, 0x0a, 0x00
        str_to_int              dq 0x00
        content_page_ptr        dq 0x00


        %ifdef TESTMAIN_SERVER
                index_path      db "./index.html", 0x00
                page_two        db "./lol.html", 0x00
                err_html        db "./error.html", 0x00

                path_index_to_match     db "/", 0x00
                path_lol_to_match       db "/lol", 0x00
        %endif
        empty_string: db 0
        null_terminator: db 0


section .text
global _start


;offsets struct response
%define status  end_response - response
%define type    end_response - response.type
%define length  end_response - response.length
%define head4   end_response - response.head4
%define body    end_response - response.body


; offsets struct sockaddr_in 
%define len_sockaddr_in end_sockaddr_in - sockaddr_in
%define off_sin_family  end_sockaddr_in - sockaddr_in.sin_family
%define off_sin_port    end_sockaddr_in - sockaddr_in.sin_port
%define off_ip_addr     end_sockaddr_in - sockaddr_in.ip_addr
%define off_pad         end_sockaddr_in - sockaddr_in.pad


; int int_to_str(int n);
int_to_str:
        push rbp
        mov rbp, rsp
        push r12
        push r13

        push rdi
        mov rdi, digitSpace
        mov rsi, 0x00
        mov rdx, 100
        call memset
        pop rdi

        mov rax, rdi
        mov r12, digitSpace
        mov r13, r12
        mov rbx, 10
        mov byte [r13], 0    ; Terminatore null

        .convert_loop:
                xor rdx, rdx
                div rbx
                add dl, '0'
                dec r13
                mov [r13], dl
                test rax, rax
                jnz .convert_loop

        mov rax, r13
        pop r13
        pop r12
        leave
        ret


; int socket(int rdi, int rsi, int rdx)
socket: ; funzione che restituisce un file descriptor
        ; rax >= 0 IF OK
        STARTFOO
        mov rax, 41
        syscall
        test rax, rax
        js .error
        
        leave
        ret
        .error: mov rdi, msg_err_socket
                call print

                mov rdi, 1
                call _exit


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

        .error: mov rdi, msg_err_bind
                call print
                mov rdi, 1
                call _exit


; int listen(int socket_fd, int backlog)
listen: ; consente a una socket di mettersi in modalita di ascolto per accettare
        ; connessioni in arrivo
        ; ret: rax == 0 if OK 
        STARTFOO
 
        mov rax, 50
        syscall
        test rax, rax
        js .error

        leave
        ret

        .error: mov rdi, msg_err_listen
                call print
                mov rdi, 1
                call _exit


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
        .error: mov rdi, msg_err_accept
                call print
                mov rdi, 1
                call _exit


; void close(long int rdi)
close:  STARTFOO
        cmp rdi, 0x00
        je .NULL
        mov rax, 3
        syscall
        .NULL:  leave
                ret

fork:   STARTFOO
        mov rax, 57
        syscall
        leave
        ret


; FILE* open(char* rdi, long int rsi, long int rdx)
open:   STARTFOO
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
                mov rdi, msg_err_open_file
                call print
                mov rdi, EXIT_FAILURE
                call _exit


read_page:
        STARTFOO
        push rsi
        push rdi
        push rdx
        push r15
        push rbx
        
        ; Apri il file
        mov rsi, O_RDONLY
        mov rdx, 0o000
        call open
        mov r15, rax     ; file descriptor
        
        ; Inizializza content_page_ptr se non esiste
        mov rdi, [content_page_ptr]
        test rdi, rdi
        jnz .read_loop
        
        ; Crea una stringa vuota
        mov rdi, empty_string
        call String
        mov [content_page_ptr], rax

        .read_loop:
                ; Leggi un chunk dal file
                mov rdi, r15     ; fd
                mov rsi, file_buffer
                mov rdx, 4096
                mov rax, SYS_READ
                syscall

                ; Controlla errori
                test rax, rax
                js .error_read
                jz .done         ; EOF

                ; Aggiungi terminatore al buffer
                mov byte [rsi + rax], 0

                ; Aggiungi al content_page_ptr
                mov rdi, [content_page_ptr]
                mov rsi, file_buffer
                call [rdi + append_str]
                jmp .read_loop

        .done:
                ; Chiudi il file
                mov rdi, r15
                call close
                
                ; Aggiungi terminazione alla stringa finale
                mov rdi, [content_page_ptr]
                mov rsi, null_terminator
                call [rdi + append_str]

                pop rbx
                pop r15
                pop rdx
                pop rdi
                pop rsi
                leave
                ret

        .error_read:
                mov rdi, msg_err_read_file
                call print
                mov rdi, EXIT_FAILURE
                call _exit


; void prepare_request(void* rdi, char* page)
prepare_request:
        STARTFOO
        mov rbx, rsi    ; salvo la path della pagina
        push rbx
        mov r13, rdi 
        
        push r13
        ; append the status
        mov rdi, response.status
        call String
        pop r13

        mov [r13], rax

        ; append the type of response
        push r13
        mov rdi, [r13]
        mov rsi, response.type
        call [rdi + append_str]
        pop r13

        ; append del messaggio "Content-Length: "
        push r13
        mov rdi, [r13]
        mov rsi, response.length
        call [rdi + append_str]
        pop r13

        pop rbx
        push r13

        ; lettura del file index.html
        mov rdi, rbx            ; path a file html
        call read_page          ; return a string ptr

        ; calcolo la len del contenuto
        mov rdi, [content_page_ptr]
        mov rdi, [rdi + content]
        call special_strlen
        mov rbx, rax

        ; converto la len in stringa
        ; mov rdi, rax
        mov rdi, rbx
        call int_to_str

        pop r13
        ; append il numero a "Content-Length: "                        
        push r13
        mov rdi, [r13]
        mov rsi, rax
        call [rdi + append_str]
        pop r13

        ; aggiungi due newline per separare header dal body
        push r13
        mov rdi, [r13]
        mov rsi, response.head4
        call [rdi + append_str]
        pop r13

        push r13
        ; aggiungo 0x0d, 0x0a, 0x00 al body 
        
        mov rdi, [content_page_ptr]
        mov rsi, endln_str
        call [rdi + append_str]
        
        ; append del contenuto della pagina html
        pop r13
        mov rdi, [r13]
        mov rsi, [content_page_ptr]
        mov rsi, [rsi + content]
        call [rdi + append_str]

        mov rdi, digitSpace
        mov rsi, 0x00
        mov rdx, 100
        call memset

        leave
        ret


; void get_path(char* rdi)
get_path:
        ; es: GET / HTTP/1.1
        STARTFOO
        ; salvo i registri che vengono usati in questa funzione che sono considerati "caldi"
        push r15
        push r14
        push r13
        push rsi
        push rdi

        mov rax, -0x01
        ; loop per scartare "GET "
        ; while (*(rdi + rax++) != 32) ;
        .loop:  inc rax
                cmp byte[rdi + rax], 32 ; e' (rdi == ' ')? 
                jne .loop

        inc rax
        mov r15, rax    ; len(method_request + ' ')

        mov rax, -0x01
        .find_end_line:
                inc rax
                cmp byte[rdi + rax], 0x0d
                jne .find_end_line

        dec rax
        push rax        ; len(char* rdi) - 1

        ; trovo la fine della path all'interno del vettore
        ; partendo dalla fine
        .serch_end_path: 
                cmp byte[rdi + rax], 32
                je .found_end_path
                dec rax
                jmp .serch_end_path

        .found_end_path:
                mov r14, rax ; len("GET / HTTP/1.1") - len(" HTTP/1.1")
                pop rax
                mov r13, r15
                ; r15 == inizio path
                ; r13 == r15
                ; r14 == fine path
                ; rax == len totale del parametro passato
        
                mov rsi, request_path_buffer

                .copy_path:
                        cmp r15, r14
                        je .done

                        mov al, byte[rdi + r15]
                        ; inserisco il char senza considerare il tipo di richiesta
                        mov byte[rsi], al
                        inc rsi
                        inc r15

                        jmp .copy_path
                .done:  mov rdi, request_path_buffer
                        call print

                        pop rdi 
                        pop rsi 
                        pop r13
                        pop r14
                        pop r15
                        leave
                        ret

strcmp: STARTFOO
        .loop:
                mov al, byte [rdi]
                mov bl, byte [rsi]
                cmp al, bl
                jne .fail
                test al, al
                je .success
                inc rdi
                inc rsi
                jmp .loop

        .success:
                leave
                xor rax, rax
                ret
        .fail:  leave
                mov rax, 1
                ret


; string compare_with_paths(char* path)
compare_with_paths:
        STARTFOO
        ;       path_index_to_match     db "/", 0x00
        ;       path_lol_to_match       db "/lol", 0x00
        
        push rdi

        mov rsi, path_index_to_match
        call strcmp
        cmp rax, 0x00
        je .is_index

        mov rsi, path_lol_to_match
        call strcmp
        cmp rax, 0x00
        je .is_lol

        jmp .bad_end
        .is_index:
                mov rax, response_x_index_GET
                jmp .done
        .is_lol:
                mov rax, response_x_lol_GET
                jmp .done
        .bad_end:
                mov rax, response_x_err_404
                jmp .done
        .done:  pop rdi
                leave
                ret


; void children_handle()
children_handle:
        ;;      DA TOGLIERE IN PRODUZIONE       ;;
        mov rdi, response_x_index_GET
        mov rsi, index_path
        call prepare_request

        ; lettura del fd del client (restituito da accept)
        mov rax, 0
        mov rdi, r15
        mov rsi, fd_buffer
        mov rdx, 4096
        syscall

        ;; PARSING PER LEGGERE IL PATH ;;
        mov rdi, fd_buffer
        call get_path

        push r15        ; salvo il fd del client

        ;; CALCOLO DELLA RESPONSE ;;
        ;mov rdi, request_path_buffer
        ;call compare_with_paths

        ;; RESTITUISCE LA RESPONSE AL CLIENT ;;

        ;push rax
        ;mov rdi, [rax]
        ;mov rdi, [rax + content]
        ;call print
        ;pop rax


        ;push rax                ; salvo il ptr a string
        mov rdi, [response_x_index_GET]
        call [rdi + len]

        mov rdi, rax
        call int_to_str

        mov rdi, digitSpace
        call print

        mov rdi, [response_x_index_GET]
        call [rdi + len]

        pop r15                         ; ripristino il fd
        mov rdi, r15                    ; fd client
        mov rdx, rax                    ; len msg HTTP
        ;pop rax                        ; ripristino il ptr string
        mov rsi, [response_x_index_GET] ; msg HTTP
        mov rsi, [rsi + content]
        mov rax, 1                      ; sysWrite
        syscall

        mov rdi, r15
        call close

        ; mov rdi, [str_to_int]
        ; call free

        mov rdi, [response_x_index_GET]
        call [rdi + __del__]

        mov rdi, request_path_buffer
        mov rsi, 0x00
        mov rdx, 512
        call memset

        mov rdi, file_buffer
        mov rsi, 0x00
        mov rdx, 4096
        call memset
        
        mov rdi, EXIT_SUCCESS
        call _exit


%ifdef TESTMAIN_SERVER
main:   STARTFOO

        mov rdi, request_path_buffer
        mov rsi, 0x00
        mov rdx, 512
        call memset

        mov rdi, file_buffer
        mov rsi, 0x00
        mov rdx, 4096
        call memset

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
        mov rsi, 10     ; numero massimo di client che si mettono in coda sul socket
        call listen     

        push rdi
        push rsi
        push rdx

        mov rdi, msg_after_bind_correct
        call print

        pop rdx
        pop rsi
        pop rdi

;        mov rdi, response_x_index_GET
;        mov rsi, index_path
;        call prepare_request

        ;mov rdi, response_x_lol_GET
        ;mov rsi, page_two
        ;call prepare_request

        ;mov rdi, response_x_err_404
        ;mov rsi, err_html
        ;call prepare_request

        ;mov rdi, response_x_index_GET
        ;mov rdi, [rdi + content]
        ;call print


        .loop:  mov rdi, r9
                xor rsi, rsi
                xor rdx, rdx
                call accept     ; int new_fd = accept(fd, NULL, NULL);
                mov r15, rax

                call fork
                cmp rax, 0x00
                je .children_do_request
                jmp .loop

                .children_do_request: 
                        call children_handle

        mov rax, 0
        leave
        ret


_start: endbr64
        mov [argc], rdi
        mov [argv], rsi
        mov [envp], rdx
        GXOR
        call main
        mov rdi, rax
        call _exit
%endif

%ifndef _EXIT
%define _EXIT
_exit:  endbr64
        mov rax, 60
        syscall
%endif


%endif
