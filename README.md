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
- lib c sqlite3 (**sudo apt install libsqlite3-dev**)
- Supporto CPU per operazioni AVX2

## **Esecuzione**

- Assemblare e linkare usando il file ```./build.sh``` (e' importante trovarsi nella stessa directory di server.asm quando si avvia questo file).
- Dopo eseguire l'eseguibile generato ```./server```

## **Come funziona**

Questo progetto si basa su alcuni moduli descritti in /utilities/:

- ```macro.asm```: macro di utilità generale come ```STARTFOO```, ```GXOR```, ```GPUSH```, ```GPOP```, ```stdin```, ```stdout```, ...
- ```mutex.asm```: usato per la mutua esclusione, contiene ```mutex_lock``` e ```mutex_unlock```
- ```net.asm```: contiene funzione ```socket```, ```bind```, ```listen```, ```accept```, ```struct sockaddr_in```
- ```paths.asm```: parsing del fd_client
- ```patricia_tree.asm```: **Non ancora finito**, usato per il routing delle pagine
- ```sqlite3.asm```: libreria usata per interagire col db tipologia sqlite3
- ```sstring.asm (static string)```: usato per operazioni elementari sui char
- ```stdio.asm```: usato per lo standard input output, contiene funzioni come ```input```, ```print```, ```print_int```, ```int_to_str```
- ```stdlib.asm```: usato per ```malloc```, ```calloc```, ```realloc```, ```free```, ```open```, ```close```
- ```thread.asm```: usato per la creazione di thread con ```create_thread```, contiene in oltre funzioni come ```fork```, ```waitpid``` e ```waitallpid```

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

### Definizione formale
```asm
; Nel kernel Linux, un socket è una rappresentazione strutturata 
; (struct socket) di un endpoint di comunicazione gestito dal sottosistema di rete,
; interfacciato al VFS come file e associato a un’implementazione di protocollo
; (struct sock) attraverso operazioni definite in struct proto_ops
```

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
### Definizione formale

```asm
; Nel kernel Linux, bind è l’operazione che associa
; un socket a un indirizzo locale del sistema,
; registrando nella struttura sock i parametri di indirizzamento (IP, porta o path)
; e inserendo il socket nelle tabelle di binding del protocollo,
; rendendolo identificabile all’interno dello stack di rete.
```

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

### Definizione formale
```asm
; Nel kernel Linux, listen è l’operazione che trasforma un socket
; precedentemente associato a un indirizzo in un endpoint passivo,
; configurando le code di connessioni (accept queue) e modificando
; lo stato interno della struct sock in modalità di ascolto,
; così che il protocollo possa accodare richieste di connessione entranti.
```
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

### Definizione formale

```asm
; Nel kernel Linux, accept è l’operazione che estrae una connessione
; completata dalla coda di ascolto di un socket passivo,
; istanzia una nuova struct socket e una nuova struct sock per il canale stabilito,
; e restituisce al processo un nuovo file descriptor rappresentante il socket
; figlio dedicato alla comunicazione con il peer remoto.
```
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
void create_thread(int (fn*)(), ...);
```

Quindi devi passare un ptr a funzione e gli argomenti (se ci sono).

Quindi, il processo padre riesegue il loop, ritornando ad accettare nuovi client,
mentre il figlio esegue children_handle che accetta come parametro accepted_request (un messaggio da stampare in output).

```asm
mov rdi, children_handle
mov rsi, accepted_request
mov rdx, rax
call create_thread
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
        .end_response:
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

per formattare la risposta da inviare al client, ho creato la funzione calculate_response, che prende come parametro il file descriptor del client e restituisce un ptr che punta a una zona allocata dinamicamente:

```asm
; char* && size_t calculate_response(char* rdi)
calculate_response:
    ; restituisce un ptr che punta a una zona allocata dinamicamente.
    ; questo ptr ha formattata la response completa da dare al client.
    ; oltre al ptr (restituito in rax), restituisce in rdx la len di rax
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
```

Funzione get_content_file(char* FILE):

Questa funzione si occupa di ottenere il contenuto di un file, resituendo (se il file esiste) un ptr a una zona allocata dinamicamente.

Analisi step by step:

```asm
    ; rdi = char* path
    mov rsi, O_RDONLY
    mov rdx, CLASSIS
    call open
    cmp rax, -1
    je .page_not_found
    .continue:
        ; ...
```

La funzione open (descritta in stdlib.asm) restituisce -1 nel caso in cui è avvenuto un errore, altriementi resgtituisce un fd > 3 se tutto ok. In questo contesto, se rax == -1, il programma finisce nel branch ```.page_not_found```, creando il fd per la pagina chiamata "page404.html", e ritorna al branch ```.continue```.

Ora, ho bisogno di sapere della grandezza del file, così posso allocare precisamente il numero di bytes che mi servono per contenere tutto il contenuto del file.
Linux mette a disposizione la syscall no. 5, ```sys_fstat``` che passando il fd, un buffer che contiene la ```struct stat``` restituisce tutte le caratteristiche del file, compreso la sua grandezza.

```c
struct stat {
    dev_t     st_dev;        /* 0x00, 8 byte */
    ino_t     st_ino;        /* 0x08, 8 byte */
    nlink_t   st_nlink;      /* 0x10, 8 byte */
    mode_t    st_mode;       /* 0x18, 4 byte */
    uid_t     st_uid;        /* 0x1C, 4 byte */
    gid_t     st_gid;        /* 0x20, 4 byte */
    int       __pad0;        /* 0x24, 4 byte */
    dev_t     st_rdev;       /* 0x28, 8 byte */
    off_t     st_size;       /* 0x30, 8 byte (SIZE DEL FILE) */
    blksize_t st_blksize;    /* 0x38, 8 byte */
    blkcnt_t  st_blocks;     /* 0x40, 8 byte */
    struct timespec st_atim; /* 0x48, 16 byte */
    struct timespec st_mtim; /* 0x58, 16 byte */
    struct timespec st_ctim; /* 0x68, 16 byte */
    long __unused[3];        /* 0x78, 24 byte */
}; // totale: 144 byte
```

Quindi, ci basta fare:
```asm
; ottengo struct stat
; sizeof(struct stat) = 144 + 1 padding (per sicurezza)
mov rdi, 145
call malloc
mov rsi, rax
mov rdi, r10    ; fd
mov rax, 5
syscall

; [rsi + 0x30] == off_t st_size; // 8 bytes
mov rdi, [rsi + 0x30]
call malloc
mov r13, rax

; la struct stat e' allocata dinamicamente
; devo liberarla perche' non mi serve piu'
sub rdi, 0x30
call free
```

I 144 bytes (+1 di padding) allocati sono la ```struct fstat```.

Una volta eseguita la syscall, rsi (che punta alla struct) contiene a offset 
[rsi + 0x30] la len, quindi la passo a rdi e eseguo la malloc.

Dopodichè, leggo il contenuto del fd per il numero preciso di byte:

```
mov rsi, r13
mov rdx, r12
mov rdi, r10
mov rax, 0
syscall

mov rdi, r10
call close
```

Infine restituisco il ptr al content a rax ed esco dalla funzione


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
Sia get_path che str_prepend restituiscono puntatori che puntano a vettori allocati dinamicamente, quindi li devo salvare all'interno dello stack in modo che quando non mi servono più, libero l'heap

```asm
    mov rdi, r13        ; contenuto fd_client
    call get_path
    mov rdi, rax
    push rdi            ; rbp + 8, path richiesto

    mov rsi, home_path
    call strcmp
    
    mov rsi, path_index
    test rax, rax
    cmove rdi, rsi

    mov rdi, rax        ; path
    mov rsi, 46         ; char = '.'
    call str_prepend
    push rax            ; rbp + 16, path richiesto con aggiunto il '.'

    ; restituisco il contenuto del file in base a quello richiesto
    mov r14, rax
    mov rdi, rax
    call calculate_response

    mov r13, rax        ; r13 = *ptr->heap
    mov r14, rdx        ; r14 = len(*ptr->heap)
```

Se la funzione calculate_response non trova il file, formatta la risposta basandosi sul contenuto di './templates/page404.html' e risponde al client:

```asm
    mov rdx, r14 ; r14 = len(*ptr->heap)
    mov rsi, r13 ; r13 = *ptr->heap
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

## Integrazione DataBase sqlite3

Per vedere come funziona il modulo ./utilities/sqlite3.asm, ho creato un'altro readme dove spiego come funziona (vai al link indicato nella sezione README.md).

Ho messo in ```rodata_things.asm``` le variabili globali di tipo rodata solo per comodità. 

Al suo interno ho inserito:

```asm
; ROBA PER DB
db_name_file db "./db_utenti.sqlite3", 0x00

table_user:
        db "CREATE TABLE IF NOT EXISTS user("
        db      "id INTEGER PRIMARY KEY AUTOINCREMENT,"
        db      "nome varchar(32) NOT NULL,"
        db      "cognome varchar(32) NOT NULL"
        db ");", 0x00

formatta_insert: 
        db "INSERT INTO user(nome, cognome)"
        db "VALUES (", 0x00

end:    db ");", 0x00
```

- ```db_name_file```: sarà il nome del db sqlite3 che verrà creato (se non esiste) o aperto.
- ```table_user```: sarà la tabella che si va a creare (se non e' già stata creata) la tabella user per poi popolarla tramite insert (che vanno create dinamicamente quando l'utente fa richieste di tipo post alla pagina ./templates/page2.html) 

All'intero del file server.asm, ho aggiunto le seguenti righe:
```asm
; === START SET database ===
mov rdi, db_name_file
lea rsi, [rel db_obj]
call sqlite3_open

; creo tabella utenti
mov rdi, [db_obj]
mov rsi, table_user
call do_table_sqlite
; === END SET database ===
```

## POST request

quando l'utente chiede il file ```./templates/page2.html```, gli viene restituito:
```html
<!DOCTYPE html>
<html lang="it">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>try post request</title>
        <style>
        </style>
    </head>
    <body>
        <form action="/templates/index.html" method="post">
            <input type="text" name="nome" placeholder="nome">
            <input type="text" name="cognome" placeholder="cognome">
            <input type="submit">
        </form>
    </body>
</html>
```

Quando l'utente compila il form e preme il tasto ```submit```, invia al server una richiesta di tipo POST.
Ovviamente, tutti i dati dell'utente si trovano all'interno del fd che invia ogni volta che fa la richiesta e la cosa non cambia nel caso di richieste di tipo POST. Infatti, i dati che ha inserito nei campi il client si trovano sempre nel fd che viene restituito dalla syscall accept:

```
POST /templates/index.html HTTP/1.1
Host: 127.0.0.1:9000
Connection: keep-alive
Content-Length: 33
Cache-Control: max-age=0
sec-ch-ua: "Chromium";v="140", "Not=A?Brand";v="24", "Google Chrome";v="140"
sec-ch-ua-mobile: ?0
sec-ch-ua-platform: "Windows"
Origin: http://127.0.0.1:9000
Content-Type: application/x-www-form-urlencoded
Upgrade-Insecure-Requests: 1
User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7
Sec-Fetch-Site: same-origin
Sec-Fetch-Mode: navigate
Sec-Fetch-User: ?1
Sec-Fetch-Dest: document
Referer: http://127.0.0.1:9000/templates/page2.html
Accept-Encoding: gzip, deflate, br, zstd
Accept-Language: it-IT,it;q=0.9

nome=lorem&cognome=ipsum
```

Di conseguenza, ci basterà parsificare il fd per ottenere il nome e cognome inserito dall'utente


## Ottimizzazioni SIMD

Ho ottimizzato per ora solo il calcolo della lunghezza di una stringa usando
le istruzioni della famiglia AVX2

## Altri tipi di ottimizzazioni

E' possibile ridurre la latenza usando la syscall setsockopt, passando il flag TCP_NODEALY:

```asm
    sub rsp, 4
    mov dword[rbp + 20], 1                              ; int on = 1;

    mov rdi, [fd_sock]                                  ; fd socket server
    mov rsi, TCP                                        ; Tipo di connessione
    mov rdx, TCP_NODELAY | SO_REUSEPORT | SO_REUSEADDR
    mov r10, rbp                                        ; address stack on
    add r10, 4
    mov r8, 4                                           ; sizeof(int)
    call setsockopt

    mov rdx, r14        ; r14 = len(*ptr->heap)
    mov rsi, r13        ; r13 = *ptr->heap
    mov rdi, r12        ; r12 = fd_client
    mov rax, 1          ; rax = SYS_write
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

```

## Attuale tempo di risposta al client

Alla migliore run (**in locale**) impiega dai 1 a 5 ms (casi piu rari), in media 2-3 ms, ma c'è ancora molto lavoro da fare per renderlo più veloce

## Tags

nasm ld socket bind accept listen read write syscall Linux server OOP C fork do_clone threading html css AVX2 x86_64


## Utilities

- [tabella syscall](https://www.chromium.org/chromium-os/developer-library/reference/linux-constants/syscalls/#x86_64-64-bit)
- [socket](https://man7.org/linux/man-pages/man2/socket.2.html)
- [bind](https://man7.org/linux/man-pages/man2/bind.2.html)
- [listen](https://man7.org/linux/man-pages/man2/listen.2.html)
- [accept](https://man7.org/linux/man-pages/man2/accept.2.html)
- [fstat](https://man7.org/linux/man-pages/man3/fstat.3p.html)
- [clone](https://www.ibm.com/docs/en/zos/3.1.0?topic=functions-clone-create-child-process)

## author

- naga272

