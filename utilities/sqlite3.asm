%ifndef SQLITE
%define SQLITE

; togli questa macro se vuoi usare questo file come modulo
; %define TESTING_SQLITE

extern sqlite3_open
extern sqlite3_exec
extern sqlite3_close

section .rodata
    error_sqlite_insert db "Errore nel tentativo di inserire una tupla", 0x00
    error_sqlite_create db "Errore nel tentativo di creare una tabella sqlite", 0x00

%ifdef TESTING_SQLITE
global _start
section .data

    dbfile db "anagrafica.sqlite3", 0x00

    citta_table:
        db "CREATE TABLE Citta("
        db      "cod_id int not null,"
        db      "Istat varchar(8) not null,"
        db      "Comune varchar(256) not null,"
        db      "Provincia varchar(256) not null,"
        db      "Regione varchar(256) not null,"
        db      "Prefisso varchar(256) not null,"
        db      "CAP varchar(256) not null,"
        db      "CodFisco varchar(256) UNIQUE not null,"
        db      "Abitanti varchar(256) not null,"
        db      "Link varchar(256) not null,"
        db      "PRIMARY KEY(cod_id)"
        db ");", 0x00


    persone_table:
        db "CREATE TABLE Persone("
        db      "id_pers integer NOT NULL,"
        db      "id_provincia integer NOT NULL,"
        db      "nome varchar(32) NOT NULL,"
        db      "cognome varchar(32) NOT NULL,"
        db      "codFisc varchar(16) NOT NULL,"
        db      "PRIMARY KEY(id_pers, id_provincia),"
        db      "foreign key(id_provincia) REFERENCES Citta(cod_id)"
        db ");", 0x00


    ; ora ci sono i problemi con la traduzione dei metacaratteri, non si puo usare \".
    ; in questi casi uso il metodo "DO KISS", lo rappresento direttamente con il char ASCII (0x22)
    sql_insert_citta:  
        db "INSERT INTO Citta ([cod_id], [Istat], [Comune], [Provincia], [Regione], [Prefisso], [CAP], [CodFisco], [Abitanti], [Link])"
        db "VALUES ("
        db      "0, ", 0x22, "28001", 0x22, ", ", 0x22, "Abano Terme", 0x22, ", ", 0x22, "PD", 0x22, ","
        db      0x22, "VEN", 0x22, ", ", 0x22, "49", 0x22, ", ", 0x22, "35031", 0x22, ","
        db      0x22, "A001", 0x22, ", ", 0x22, "19726", 0x22, ", ", 0x22, "http://www.comuni-italiani.it/028/001/", 0x22, ""
        db ");", 0x00

section .bss
    db_handle   resq 1

%endif

section .text


; void do_insert_sqlite(db_handle*, char*)
do_table_sqlite:
    endbr64
    push rbp
    mov rbp, rsp
    ; sqlite3_exec(db_handle, sql_create, 0, 0, 0)
    xor rdx, rdx
    xor rcx, rcx
    xor r8,  r8
    call sqlite3_exec
    ; != 0 errore
    test eax, eax
    jnz .fail
    leave
    ret
    .fail:
        mov rdi, error_sqlite_create
        call print
        mov rdi, 0x01
        call _exit


; void do_insert_sqlite(db_handle*, char*)
do_insert_sqlite:
    endbr64
    push rbp
    mov rbp, rsp
    ; sqlite3_exec(db_handle, sql_insert, 0, 0, 0)
    xor rdx, rdx
    xor rcx, rcx
    xor r8,  r8
    call sqlite3_exec
    ; != 0 errore
    test eax, eax
    jnz .fail
    leave
    ret
    .fail:
        mov rdi, error_sqlite_insert
        call print
        mov rdi, 0x01
        call _exit

    leave
    ret


%ifdef TESTING_SQLITE
main: endbr64
    push rbp
    mov rbp, rsp

    ; sqlite3_open("<nome_file>.db", &db_handle)
    ; sqlite3_open se il db non viene trovato, lo crea
    mov rdi, dbfile
    lea rsi, [rel db_handle]
    call sqlite3_open

    ; != 0 errore
    test eax, eax
    jnz .fail

    ; creazione della table citta
    mov rdi, [db_handle]
    mov rsi, citta_table
    call do_table_sqlite

    ; creazione table persone
    mov rdi, [db_handle]
    mov rsi, persone_table
    call do_table_sqlite

    ; insert di una tupla nella tabella citta
    mov rdi, [db_handle]
    mov rsi, sql_insert_citta
    call do_insert_sqlite

    ; sqlite3_close(db_handle)
    mov rdi, [db_handle]
    call sqlite3_close

    mov rax, 0x00
    leave
    ret

    .fail:
        mov rax, 0x01
        leave
        ret


_start:
    endbr64
    call main
    mov rdi, rax
    call _exit


_exit:
    endbr64
    mov rax, 60
    syscall

%endif
%endif
