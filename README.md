# Server in asm
![Platform](https://img.shields.io/badge/OS%20platform%20supported-Linux-green?style=flat)

![Language](https://img.shields.io/badge/Language-nasm_x86_64-black?style=flat)  

![Language](https://img.shields.io/badge/Language-ld-white?style=flat)  

![Testing](https://img.shields.io/badge/Test-Pass-green)

## **Descrizione**

Lo scopo di questo progetto è capire sul serio come funziona un server web, andando oltre le solite librerie e tutorial pieni di magia nera non spiegata.

Online si trova tanta roba, ma spesso è confusa, astratta o semplicemente scritta da chi non ha mai davvero messo le mani nel silicio o guardato cosa succede davvero quando una richiesta HTTP arriva.

Personalmente mi ha sempre fatto incazzare il fatto che nessuno spiega chiaramento cosa succede al livello del silicio, quindi ho deciso di scrivermelo da solo nel tentativo di aiutare anche altre persone che sono curiose a capire meglio.

## **Requisiti**

- OS **Linux-like**
- assembler **nasm x86_64** (**sudo apt install nasm**)
- linker **ld** (**sudo apt install binutils**)
- (opzionale) make (**sudo apt install make**)

## **Esecuzione**

- assemblare e linkare usando il file ```./build.sh``` (e' importante trovarsi nella stessa directory di server.asm quando si avvia questo file).
Doposiche eseguire l'eseguibile ```./server```

## **Come funziona**

Il programma parte dalla procedura _start, che si occupa di salvare all'interno dei puntatori argc, argv, envp gli argomenti passati da linea di comando.
Il comando GXOR si occupa di azzerare i registri generali della cpu (quindi rax, rbx, rcx, rdx), e' sempre cosa buona e giusta azzerarli a inizio programma.

```asm

%macro GXOR 0
        xor rax, rax
        xor rbx, rbx
        xor rcx, rcx
        xor rdx, rdx
%endmacro

_start: endbr64
        mov [argc], rdi ; numero di argomenti
        mov [argv], rsi ; *argv[] -> parametri passati da cli
        mov [envp], rdx ; *envp[] -> variabili d'ambiente
        GXOR
        call main
        mov rdi, rax
        call _exit
```


la funzione main si occupa delle seguenti funzioni:
```txt
creazione della socket (syscall 41)
avvio del bind (syscall 49)
listening (syscall 59)

while (True):
        accept (syscall 43)
        read dal fd resituito da accept (syscall 0)
        thread(function, fd_client)
        close fd client (syscall 3)

```

all'inizio di main possiamo vedere la macro STARTFOO:

```asm
%macro STARTFOO 0
        endbr64
        push rbp
        mov rbp, rsp
%endmacro
```

endbr64: non ha scopi di migliorare l'efficienza del programma, ma di aumentare la sicurezza.
Questa istruzione consente di evitare attacchi di tipo ROP e JOP, dove in pratica i malintenzionati senza questa istruzione possono eseguire dei jmp alterando il flusso del codice.
con push rbp e mov rbp, rsp si setta semplicemente lo stack.

## Creazione socket

Il primo step di cui ci dobbiamo occupare è la creazione di un socket.
Nei os Linux-like, i socket vengono visti come dei file, di conseguenza una socket si usa come si userebbe un file, si usa un fd

Ora, passiamo alla chiamata di funzione socket:

```asm
    mov rdi, AF_INET
    mov rsi, SOCK_STREAM
    mov rdx, TCP
    call socket
```

- **AF_INET** -> è una macro che ha come valore 0x02 e serve a dire che andremo ad usare indirizzi IPv4.
- **SOCK_STREAM** -> è una macro che ha come valore 0x01, è il valore che identifica il tipo di socket SOCK_STREAM, ossia un tunnel bidirezionale (quindi che accetta pacchetti in in/out) garantendo che i dati arrivino nell'ordine corretto.
Altri tipi di socket sono **SOCK_DGRAM** usato per protocolli udp e **SOCK_RAW** (accesso per i pacchetti grezzi, usato semplicemente per lo sniffing di pacchetti o per protocolli personalizzati)
- **TCP** -> macro che ha come valore 0x00 o 0x06 e che indica il tipo di protocollo che vogliamo usare, se ha valore 0x00 quindi, si sta stabilendo una connessione di tipo TCP.

Ora andiamo nel corpo della funzione socket:

```asm
; long int socket(long int rdi, long int rsi, long int rdx)
socket: ; funzione che restituisce un file descriptor
        ; rax >= 0 IF OK
        STARTFOO
        mov rax, 41
        syscall
        test rax, rax
        js .error

        leave
        ret
        .error: 
            mov rdi, msg_err_socket
            call print

            mov rdi, 1
            call _exit

```

La syscall su Linux x86_64 per la creazione di socket è la numero 41.
una volta passato AF_INET, SOCK_STREAM, TCP a questa syscall viene restituito un file descriptor che identifica quella socket in rax. 
In caso di errore, il registro rax avrà un valore negativo, di conseguenza dato che non si è riusciti a creare la socket si fa un jmp all'etichetta .error e permette l'uscita dal programma.
in C, questo equivale a:

```c
int x = socket(AF_INET, SOCK_STREAM, 0);
if (x < 0) {
        printf("impossibile creare la socket");
        exit(EXIT_FAILURE);
}
```

Una volta generato il fd correttamente, salvo il suo valore all'interno di un'altro registro (questo perchè il registro rax mi serve per altro più avanti), quindi:

```asm
; ...
call socket
mov r9, rax     ; salvo nel registro r9 il fd
```

## Bind

La funzione bind consente di legare il fd del socket a Ip, porta e protocollo

la chiamata di funzione a bind ha bisogno di tre parametri:
- Il fd del socket
- Puntatore alla struct sockaddr_in
- Lunghezza della struct sockaddr_in

La struct sockaddr_in è una struct formata da 16 bytes in questo modo:

```asm
sockaddr_in:
        .sin_family:     db AF_INET, 0x00       ; 2 bytes
        .sin_port:       db 0x23, 0x28          ; 2 bytes (porta 9000 in big endian)
        .ip_addr:        db 127, 0, 0, 1        ; 4 bytes
        .pad:            dq 0x00                ; padding di 8 bytes
        .end_sockaddr_in:

```

- sin_family: è 2 bytes, contiene il tipo di ip che vogliamo usare(1° byte) e il protocollo (2° byte)
- sin_port: 2 bytes, il primo rappresenta la parte alta della porta e l'altro byte la parte basse
- ip_addr: 4 bytes, ogni byte corrisponde a un ottetto di bit dell'ip
- padd: è del semplice padding, deve essere di 8 bytes, serve per l'allineamento, è riempito semplicemento con valore 0x00

Per ottenere sizeof(sockaddr_in) basta fare:

```asm
%define len_sockaddr_in sockaddr_in.end_sockaddr_in - sockaddr_in
```

Quindi, come parametri alla chiamata bind possiamo passare:

```asm
mov rdi, r9                     ; socket fd
mov rsi, sockaddr_in            ; (struct sockaddr_in*) &rsi
mov rdx, len_sockaddr_in        ; sizeof(struct sockadd_in)
call bind
```

la funzione bind è strutturata nel seguente modo:

```asm

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
```

per eseguire bind bisogna chimare la syscall numero 49, che se tutto è andato bene, restituisce nel registro rax il valore 0x00, != in caso di errore.

## Listen
Consente alla macchina di mettersi in ascolto su una porta. 
Accetta backlog richieste in coda, in caso che il numero di richieste in coda viene sorpassato, per il client il server sarà irraggiungibile.

```asm

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

```

La syscall per mettersi in ascolto è la numero 50, e restituisce in rax il valore 0 se è tutto ok, != da 0 in caso di errore.
quindi la chiamata a funzione è la seguente:

```asm
mov rdi, r9     ; socket fd
mov rsi, 10     ; numero massimo di client che si possono mettere in coda sul socket
call listen
```

## Accept

In questa fase, il server rimane in attesa che un client mandi una richiesta, e in caso in cui avviene, comincia ad eserguire delle operazioni.
Fino a quel momento, il server rimane in ascolto, non farà assolutamente nulla.

I parametri della funzione accept sono:

```c
accept(int fd, struct sockaddr_in* rsi, sizeof(struct sockaddr_in));
```

il secondo e terzo parametro se non vogliamo avere informazioni sul client (come l'ip con cui ha mandato la richiesta) possiamo passare tranquillamente 0x00:

```c
accept(int fd, NULL, NULL);
```

Dato che al momento non mi interessa sapere niente del client, faccio questo:

```asm
mov rdi, r9     ; fd descriptor
xor rsi, rsi    ; NULL
xor rdx, rdx    ; NULL
call accept
```

passando al corpo della funzione:

```asm
; int accept(int sock_fd, struct sockaddr_in* rsi, size_t rdx); 
accept: ; quando arriva una richiesta, accept restituisce un nuovo fd
        ; ret: rax >= 0 IF OK
        STARTFOO
        mov rax, 43
        syscall 
        test rax, rax
        js .error

        leave
        ret
        .error: mov rdi, msg_err_accept
                call print
                mov rdi, 1
                call _exit
```

La syscall per accept è la numero 43 e una volta chiamata, il programma si blocca al punto del codice **syscall**.
Quando invece si connette il client, la syscall restituisce un file descriptor che ha come valore >= 0, < 0 in caso di errore.

Questo file descriptor consente di avere delle informazioni utili come per esempio il percorso che l'utente ha richiesto. Es di contenuto del fd:

```txt
GET / HTTP/1.1
Host: 127.0.0.1:9000
Connection: keep-alive
sec-ch-ua: "Not)A;Brand";v="8", "Chromium";v="138", "Google Chrome";v="138"
sec-ch-ua-mobile: ?0
sec-ch-ua-platform: "Windows"
Upgrade-Insecure-Requests: 1
User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7
Sec-Fetch-Site: none
Sec-Fetch-Mode: navigate
Sec-Fetch-User: ?1
Sec-Fetch-Dest: document
Accept-Encoding: gzip, deflate, br, zstd
Accept-Language: it-IT,it;q=0.9

GET /favicon.ico HTTP/1.1
Host: 127.0.0.1:9000
Connection: keep-alive
sec-ch-ua-platform: "Windows"
User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36
sec-ch-ua: "Not)A;Brand";v="8", "Chromium";v="138", "Google Chrome";v="138"
sec-ch-ua-mobile: ?0
Accept: image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8
Sec-Fetch-Site: same-origin
Sec-Fetch-Mode: no-cors
Sec-Fetch-Dest: image
Referer: http://127.0.0.1:9000/
Accept-Encoding: gzip, deflate, br, zstd
Accept-Language: it-IT,it;q=0.9
```

```asm
call accept
mov r10, rax ; passo il fd del client restituito dalla syscall nel registro r10
```

Fatto questo, devo usare il multithreading, questo perchè fintantochè il processo figlio elabora la risposta da dare al singolo client, il server deve ritornare subito nella funzione accept() per accettare altri client, altrimenti gli altri non possono fare richieste.
Per fare questo, ho creato un modulo assembly chiamato thread.asm, che al suo interno contiene le seguenti funzioni:

- create_thread: crea un processo figlio che condivide la memoria col padre.
        il prototype è:

```C        
void create_thread(int (fn*)(), ...)
```

Quindi devi passare un ptr a funzione e se ci sono gli argomenti.


- fork: crea un processo nel modo classico, senza CLONE_VM

```asm

        mov rdi, children_handle
        mov rsi, accepted_request
        mov rdx, rax
        call create_thread
```

quindi, il processo padre riesegue il loop, ritornando ad accettare nuovi client,
mentre il figlio esegue children_handle che accetta come parametro accepted_request (un messaggio da stampare in output).


## write

Il processo figlio ha il compito di rispondere al client, nel nostro caso restituisce del testo HTML.

```asm

mov rdi, response
call strlen             ; calcolo la lunghezza del vettore di char "response"
mov rdx, rax            ; len msg response
mov rdi, r10            ; fd client
mov rsi, response       ; msg HTTP
mov rax, 1              ; sysWrite
syscall

```

il messaggio response deve essere strutturato nel seguente modo:

```asm
response:
        .status: db "HTTP/1.1 200 OK", ENDL
        .type:   db "Content-Type: text/html", ENDL
        .length: db "Content-Length: 53", ENDL
                ;   OPZIONALI   ;
        .conn:   db "Connection: keep-alive", ENDL
        .keep:   db "Keep-Alive: timeout=5, max=100", ENDL
        .cache:  db "Cache-Control: public, max-age=31536000", ENDL
        .server: db "Server: AssemblyServer/0.1", ENDL
        .head4:  db ENDL
        .body:   db "<html><body><h1>Lorem Ipsum dolorem</h1></body></html>", 0
end_response:
```

Dove ENDL è una macro che viene sostituita da i caratteri \r e \n (0x0d, 0x0a).
**NB**: LA STRUTTURA DEVE AVERE QUESTO FORMATO, E' IMPORTANTISSIMO ALTRIMENTI NON FUNZIONERA'. MI RACCOMANDO, RISPETTA **TUTTI I NEW LINE**. 

## close

Una volta inviato il messaggio al client, bisogna chiudere il suo fd tramite la syscall numero 3 chiamata close().


```asm
close:  ; chiusura fd 
        STARTFOO
        mov rax, 3
        syscall
        leave
        ret
```


## SEND PAGE HTML

Il processo figlio ha il compito di:
- leggere dal fd del client (ci servirà più avanti)
- formulare la risposta per il client
- restituire la risposta al client
- liberare la memoria

per formattare la risposta da inviare al client, ho creato la funzione calculate_response:
```asm
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
```


## Mostra il contenuto in base al percorso richiesto

Ora dal contenuto del fd del client bisogna ottenere la path richiesta.
Il contenuto segue il seguente pattern:

```
GET / HTTP/1.1
Host: 127.0.0.1:9000
Connection: keep-alive
sec-ch-ua: "Not)A;Brand";v="8", "Chromium";v="138", "Google Chrome";v="138"
sec-ch-ua-mobile: ?0
sec-ch-ua-platform: "Windows"
Upgrade-Insecure-Requests: 1
User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7
Sec-Fetch-Site: none
Sec-Fetch-Mode: navigate
Sec-Fetch-User: ?1
Sec-Fetch-Dest: document
Accept-Encoding: gzip, deflate, br, zstd
Accept-Language: it-IT,it;q=0.9
```

Come si può notare la prima riga contiene il '/', quindi tramite la funzione get_path, vado a estrarre il percorso richiesto e aggiungo il carattere '.' per rendere il percorso del file relativo.

```asm
    mov rdi, r13        ; contenuto fd_client
    call get_path

    mov rdi, rax        ; path
    mov rsi, 46         ; char = '.'
    call str_prepend

    ; restituisco il contenuto del file in base a quello richiesto
    mov r14, rax
    mov rdi, rax
    call calculate_response
```

Se la funzione calculate_response non trova il file, formatta la risposta basandosi sul contenuto di './templates/page404.html' e risponde al client:

```
    mov rdi, rax
    call strlen

    mov rdx, rax 
    mov rsi, rdi
    mov rdi, r12
    mov rax, 1
    syscall
```

Ricapitolando, se si segue i seguenti link

- http://127.0.0.1:9000/templates/index.html
- http://127.0.0.1:9000/templates/page2.html
- http://127.0.0.1:9000/templates/page3.html
- http://127.0.0.1:9000/templates/page404.html
- http://127.0.0.1:9000

Il server risponde con successo, altrimenti risponde mostrando la pagina 404

## POST request

**prossimamente...**

## Ottimizzazioni SIMD

**prossimamente...**


## Attuale tempo di risposta al client

Alla migliore run impiega 3 millisecondi per ora, ma c'è ancora molto lavoro da fare per renderlo più veloce

## Tags

nasm ld socket bind accept listen read write syscall Linux server OOP C fork do_clone threading html css


## utilities

- https://www.chromium.org/chromium-os/developer-library/reference/linux-constants/syscalls/#x86_64-64-bit
- https://www.ibm.com/docs/en/zos/3.1.0?topic=functions-clone-create-child-process

## author

- naga272