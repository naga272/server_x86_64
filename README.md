# Server in asm
![Platform](https://img.shields.io/badge/OS%20platform%20supported-Linux-green?style=flat)

![Language](https://img.shields.io/badge/Language-nasm_x86_64-black?style=flat)  

![Language](https://img.shields.io/badge/Language-ld-white?style=flat)  

![Testing](https://img.shields.io/badge/Test-Pass-green)

## Descrizione

Lo scopo di questo progetto è capire sul serio come funziona un server web, andando oltre le solite librerie e tutorial pieni di magia nera non spiegata.

Online si trova tanta roba, ma spesso è confusa, astratta o semplicemente scritta da chi non ha mai davvero messo le mani nel silicio o guardato cosa succede davvero quando una richiesta HTTP arriva.

Personalmente mi ha sempre fatto incazzare il fatto che nessuno spiega chiaramento cosa succede al livello del silicio, quindi ho deciso di scrivermelo da solo nel tentativo di aiutare anche altre persone che sono curiose a capire meglio.

## **REQUISITI**

- OS **Linux-like** (**quando quelli di Microsoft smetteranno di tenersi la documentazione seria di quei .dll tutta per se', magari farò una versione anche per Windows.**)
- assembler **nasm x86_64** (**sudo apt install nasm**)
- linker **ld** (**sudo apt install binutils**)
- (opzionale) make (**sudo apt install make**)

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
- creazione della socket (syscall 41)
- avvio del bind (syscall 49)
- listening (syscall 59)
- accept (syscall 43)
- read/write dal/sul client (syscall 0/1)
- close della connessione del client (syscall 3)

all'inizio di main possiamo vedere la macro STARTFOO:

```asm
%macro STARTFOO 0
        endbr64
        push rbp
        mov rbp, rsp
%endmacro
```

endbr64: non ha scopi di migliorare l'efficienza del programma, ma di aumentare la sicurezza. Questa istruzione consente di evitare attacchi di tipo ROP e JOP, dove in pratica i malintenzionati senza questa istruzione possono eseguire dei jmp alterando il flusso del codice.
con push rbp e mov rbp, rsp si setta semplicemente lo stack.

## Creazione socket

Il primo step di cui ci dobbiamo occupare è la creazione di un socket. Per visualizzare meglio il concetto di socket, possiamo vederlo come un tunnel dove i dati vengono instradati verso un qualcosa.

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
una volta passato AF_INET, SOCK_STREAM, TCP a questa syscall viene restituito un file descriptor che identifica quella socket in rax (in pratica, il file descriptor è rappresentato tramite valore numerico intero). In caso di errore, il registro rax avrà un valore negativo, di conseguenza dato che non si è riusciti a creare la socket si fa un jmp all'etichetta .error e permette l'uscita dal programma.
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

Per avviare una connessione non basta avere un tunnel, bisogna avere anche un'uscita. La funzione bind si occupa proprio di questo, aprire un buco alla fine del tunnel per poter far entrare i dati.
NB: si occupa **SOLO** di aprire la porta al tunnel.

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
end_sockaddr_in:

```

- sin_family: è 2 bytes, contiene il tipo di ip che vogliamo usare(1° byte) e il protocollo (2° byte)
- sin_port: 2 bytes, il primo rappresenta la parte alta della porta e l'altro byte la parte basse
- ip_addr: 4 bytes, ogni byte corrisponde a un ottetto di bit dell'ip
- padd: è del semplice padding, deve essere di 8 bytes, serve per l'allineamento, è riempito semplicemento con valore 0x00

Per ottenere sizeof(sockaddr_in) basta fare:

```asm
%define len_sockaddr_in end_sockaddr_in - sockaddr_in
```

quindi, come parametri alla chiamata bind possiamo passare:

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
Accetta backlog richieste in coda, in caso che il numero di richieste in coda viene sorpassato, per il client la macchina sarà irraggiungibile.

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

In questa fase, il server rimane in attesa che un client mandi una richiesta, e in caso in cui avviene, comincia ad eserguire delle operazioni. Fino a quel momento, il server rimane in ascolto, non farà assolutamente nulla.

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
Per fare questo, si usa la syscall numero 47 fork().
Il processo padre e figlio non condividono i valori dei registri della cpu, sono due processi separati e per distinguerli, gli sviluppatori di linux hanno pensato che quando si ritorna dalla syscall fork il figlio ha nel registro della cpu rax il valore 0, mentre il processo padre ha un valore > 0.

```asm

call fork
test rax, rax
jz .children    ; il processo figlio salta all'etichetta ".children"
jmp .loop       ; il processo padre si occupa di ritornare in fase di accept()
.children:
        ; il processo figlio si occupa di rispondere al client

        ; ...

        ; una volta risposto il processo figlio deve essere ucciso
        ; tramite la funzione _exit()
        mov rdi, 0
        call _exit
```

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

il messaggio response è strutturato nel seguente modo:

```asm
response db "HTTP/1.1 200 OK", 13, 10
         db "Content-Type: text/html", 13, 10
         db "Content-Length: 53", 13, 10
         db 13, 10
         db "<html><body><h1>Lorem Ipsum dolorem</h1></body></html>", 0
```

**NB**: LA STRUTTURA DEVE AVERE QUESTO FORMATO, E' IMPORTANTISSIMO ALTRIMENTI NON FUNZIONERA'. RISPETTA **TUTTI** I NEW LINE. CONTENT-LENGTH VUOLE LA LEN DEL BODY, ESCLUDENDO I CHAR \r

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


## STEP SUCCESSIVO (SEND PAGE HTML)

Dato che il codice della funzione main sta diventando grande, è il caso di prendere in considerazione la possibilità di spezzare il codice. N
el main quindi arriviamo alla fork, e per il codice del figlio assegnamo la funzione childrend_handle

```asm

children_handle: STARTFOO
        ; resto del codice da eseguire per il processo figlio
        leave
        ret


main:   STARTFOO
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
```


Per continuare col porgramma, abbiamo bisogno di una libreria minimale per la gestione di oggetti di tipo string.

```asm
%include "./string.asm"
```

In questa libreria, è stata dichiarata una classe con i seguenti attributi e metodi:
```python

        String():
                def __init__(self, msg: str):
                       self.content = msg
                       self.size_content = len(msg)
                def len(self) -> long int                               # return @self.content length
                def append(self, msg_to_append: str) -> None            # append msg_to_append to @self.content
                def remove(self, n: int) -> None                        # remove n chars from @self.content
                def startswith(self, msg: str) -> long int              # verifica che la stringa comincia con msg
                def endswith(self, msg: str) -> long int                # verifica che la stringa finisce con msg
                def replace(self, substring: str, rep: str) -> None     # replace a substring of self.content with rep 
                def __del__(self) -> None                               # delete the String object


```
Per istanziare degli oggetti, basta chiamare la funzione String passando come parametro un puntatore a vettori di caratteri.

```asm
mov rdi, response.status
call String
```

Con questo tipo di dati, possiamo con molta facilità modificare il contenuto di un vettore dinamicamente.
Quello che dobbiamo fare è ricreare la risposta con gli headers e body basandoci sulla grandezza del file HTML e sul suo contenuto, quindi modifichiamo la struttura response nel seguente modo:

```asm
response: 
        .status: db "HTTP/1.1 200 OK", ENDL, 0x00
        .type:   db "Content-Type: text/html", ENDL, 0x00
        .length: db "Content-Length: ", 0x00
        .head4:  db ENDL, ENDL, 0x00
        .body:   dq 0x00         ; string* che contiene il corpo del file html
end_response:
```

Man mano, aggiungiamo alla variabile di tipo string il contenuto di response usando il metodo append dell'oggetto string.

```asm
        ; Create the string obj and than append the status of response
        mov rdi, response.status
        call String
        mov [literally_the_response], rax ; ptr in .data

        ; append the type of response
        mov rdi, [literally_the_response]
        mov rsi, response.type
        call [rdi + append_str]

        ; append del messaggio "Content-Length: "
        mov rdi, [literally_the_response]
        mov rsi, response.length
        call [rdi + append_str]
```

Ora, odbbiamo calcolare la len del file html. 
Per fare questo, ho creato la funzione read_page, che prende come parametro il percorso del file, restituendo nella variabile content_page_ptr un ptr a un oggetto string.
In content_page_ptr ora abbiamo un problema. i new-line vengono riscritti in "\r\n", quindi considerati due char. 
Invece, Content-Length di response vuole considerati i new-line del body un solo char. 
Per questo, ho costruito una strlen speciale che non conta il char '\r' del vettore passato come parametro  

```asm
; long int special_strlen(char *rdi)
special_strlen:
        STARTFOO
        push rcx
        push rdi        ; non si sa mai
        xor rax, rax
        xor rcx, rcx

        .loop:  prefetcht0[rdi + rax + 128]
                cmp byte[rdi + rax], 0x00
                je .done

                cmp byte[rdi + rax], 0x0d
                je .no_update_rcx

                inc rcx
        .no_update_rcx:
                inc rax
                jmp .loop

        .done:  mov rax, rcx
                pop rdi
                pop rcx
                leave
                ret
```

Ora, ci basterà passare il contenuto puntato da content_page_ptr a special_strlen per ottenere la len del body senza considerare i \r:

```asm
        ; calcolo la len del contenuto
        mov rdi, [content_page_ptr]
        mov rdi, [rdi + content]
        call special_strlen
        mov rbx, rax
```

Fatto questo, dobbiamo converti il numero intero in stringa usando la funzione int_to_str:

```asm
        ; converto la len in stringa
        ; mov rdi, rax
        mov rdi, rbx
        call int_to_str ; restituisce nella variabile DigitSpace la str
```

e fare un append a literally_the_response:
```asm
        ; append il numero a "Content-Length: "                        
        mov rdi, [literally_the_response]
        mov rsi, rax
        call [rdi + append_str]
```

Ora, lo standard dello response dopo la length vuole obbligatoriamente due new-line:

```asm
        ; aggiungi due newline per separare header dal body
        mov rdi, [literally_the_response]
        mov rsi, response.head4
        call [rdi + append_str]
```

E anche il contenuto della pagina html vuole un end-line finale (non deve venir considerato nella length).

```asm
        ; aggiungo 0x0d, 0x0a, 0x00 al body 
        mov rdi, [content_page_ptr]
        mov rsi, endln_str
        call [rdi + append_str]
```

e infine facciamo l'append del contenuto puntato da content_page_ptr in literally_the_response:

```asm
        ; append del contenuto della pagina html
        mov rdi, [literally_the_response]
        mov rsi, [content_page_ptr]
        mov rsi, [rsi + content]
        call [rdi + append_str]
```

Ora dobbiamo ricalcolare la len di tutto il contenuto di literally_the_response (dobbiamo considerare anche i \r questa volta), per farlo possiamo usare il metodo len, che restituisce in modo efficiente la len del contenuto dell'oggetto:
```asm
        mov rdi, [literally_the_response]
        call [rdi + len]
```

e restituire la risposta al client:
```asm
        ; restituisco al client la risposta
        pop r15
        mov rdx, rax                            ; len msg HTTP
        mov rdi, r15                            ; fd client
        mov rsi, [literally_the_response]       ; msg HTTP
        mov rsi, [rsi + content]
        mov rax, 1                              ; sysWrite
        syscall
```

Ora bisogna deallocare le risorse allocate e uccidere il processo figlio:
```asm
        mov rdi, r15
        call close

        ; libero l'heap prima di uccidere il processo figlio
        mov rdi, [literally_the_response]
        call free

        mov rdi, [content_page_ptr]
        call free 

        ; mov rdi, [str_to_int]
        ; call free

        mov rdi, file_buffer
        mov rsi, 0x00
        mov rdx, 4096
        call memset
        
        mov rdi, EXIT_SUCCESS
        call _exit
```


## STEP SUCESSIVO: Mostra il contenuto in base al percorso richiesto

**work in progress...**

## Tags

nasm ld socket bind accept listen read write syscall Linux server malloc realloc free OOP C++ fork

## author

- naga272