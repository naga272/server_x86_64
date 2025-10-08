%ifndef NET_ASM
%define NET_ASM


; Ritchie non guardare questa barbaria ti prego
%macro MAYBE_FAILCASE 0
	test rax, rax
	js .error
%endmacro


section .rodata
    neg_res_sock            db "errore nel tantito di creare una socket", ENDL, 0x00
    neg_res_bind            db "errore durante la fase di binding", ENDL, 0x00
    neg_res_listen          db "errore nel tentativo di mettersi in ascolto", ENDL, 0x00
    neg_res_accept          db "Impossibile accettare la connessione", ENDL, 0x00
    neg_res_fd_client       db "impossibile leggere il contenuto del fd del client", ENDL, 0x00    
    neg_res_recv	    db "impossibile ricevere i dati", ENDL, 0x00
    neg_res_recvmsg	    db "Impossibile eseguire la recvmsg", ENDL, 0x00
    neg_res_connect	    db "Impossibile eseguire la connect", ENDL, 0x00
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

socket: 
    ; Nel kernel Linux, un socket è una rappresentazione strutturata 
    ; (struct socket) di un endpoint di comunicazione gestito dal sottosistema di rete,
    ; interfacciato al VFS come file e associato a un’implementazione di protocollo
    ; (struct sock) attraverso operazioni definite in struct proto_ops
    STARTFOO
    mov rax, 41
    syscall

    MAYBE_FAILCASE
    leave
    ret
    .error: mov rdi, neg_res_sock
            call print
            mov rdi, EXIT_FAILURE
            call _exit


; int bind(int sock_fd, struct sockaddr_in* rsi, size_t rdx);
bind:
    ; Nel kernel Linux, bind è l’operazione che associa
    ; un socket a un indirizzo locale del sistema,
    ; registrando nella struttura sock i parametri di indirizzamento (IP, porta o path)
    ; e inserendo il socket nelle tabelle di binding del protocollo,
    ; rendendolo identificabile all’interno dello stack di rete.
    ; rax == 0 if OK
    STARTFOO

    mov rax, 49
    syscall
    MAYBE_FAILCASE
    leave
    ret

    .error: mov rdi, neg_res_bind
            call print
            mov rdi, EXIT_FAILURE
            call _exit


listen: 
    ; Nel kernel Linux, listen è l’operazione che trasforma un socket
    ; precedentemente associato a un indirizzo in un endpoint passivo,
    ; configurando le code di connessioni (accept queue) e modificando
    ; lo stato interno della struct sock in modalità di ascolto,
    ; così che il protocollo possa accodare richieste di connessione entranti.
    STARTFOO
    mov rax, 50
    syscall
    MAYBE_FAILCASE    
    leave
    ret

    .error: mov rdi, neg_res_listen
            call print
            mov rdi, EXIT_FAILURE
            call _exit


; int accept(int sock_fd, struct sockaddr_in* rsi, size_t rdx); 
accept:
    ; Nel kernel Linux, accept è l’operazione che estrae una connessione
    ; completata dalla coda di ascolto di un socket passivo,
    ; istanzia una nuova struct socket e una nuova struct sock per il canale stabilito,
    ; e restituisce al processo un nuovo file descriptor rappresentante il socket
    ; figlio dedicato alla comunicazione con il peer remoto.
    ; ret: rax >= 0 IF OK
    STARTFOO
    mov rax, 43
    syscall 
    MAYBE_FAILCASE

    leave
    ret
    .error: mov rdi, neg_res_accept
            call print
            mov rdi, EXIT_FAILURE
            call _exit


; int connect(int sockfd, const struct sockaddr *addr, socklen_t addrlen);
connect:
	; Nel kernel Linux, connect è l’operazione che inizializza 
    ; l’associazione attiva tra un socket locale e un endpoint remoto,
    ; impostando nella struct sock i parametri di destinazione e avviando
    ; la procedura di connessione definita dal protocollo (ad esempio il three-way handshake per TCP).
    ; Durante l’esecuzione, il socket transita in stato di connessione (TCP_SYN_SENT o equivalente) e,
    ; al completamento del collegamento, viene marcato come connesso,
    ; consentendo lo scambio bidirezionale di dati attraverso il canale stabilito.

    STARTFOO
	MAYBE_FAILCASE	
	leave
	ret
	.error: mov rdi, neg_res_connect 
		call print
		mov rdi, EXIT_FAILURE
		call _exit



; ssize_t recv(int sockfd, void *buf, size_t len, int flags)
recv:
    ; Nel kernel Linux, recv è l’operazione che legge i dati già ricevuti
    ; dallo stack di rete e memorizzati nei buffer di ricezione associati alla struct sock.
    ; Essa interagisce con i meccanismi di coda del protocollo
    ; (ad esempio la receive queue TCP o UDP),
    ; copia i dati nello spazio utente e aggiorna gli indicatori di avanzamento del buffer,
    ; rispettando i flag di blocking, non-blocking o peeking definiti per il socket.
    STARTFOO
    mov rax, 47
	syscall
	MAYBE_FAILCASE
	mov rax, EXIT_SUCCESS
	leave
	ret
	.error: mov rdi, neg_res_recv
		call print
		mov rdi, EXIT_FAILURE
		call _exit


; ssize_t recvmsg(int socket, struct msghdr *message, int flags);
recvmsg:
    ; Nel kernel Linux, recvmsg è l’operazione generica di ricezione che estende recv
    ; consentendo la lettura strutturata di messaggi e metadati di controllo.
    ; Essa interagisce direttamente con la funzione sock_recvmsg() e con le operazioni proto_ops->recvmsg,
    ; permettendo di ricevere dati, indirizzi sorgente, e ancillary data (control messages) in una struttura msghdr,
    ; mantenendo la semantica di basso livello coerente con il protocollo sottostante.    
    STARTFOO

	mov rax, 47
	syscall
	MAYBE_FAILCASE	
	leave
	ret
	.error: mov rdi, neg_res_recvmsg
		call print
		mov rdi, EXIT_FAILURE
		call _exit
		

%undef MAYBE_FAILCASE

%endif



