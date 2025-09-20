%ifndef RODATA_THINGS_ASM
%define RODATA_THINGS_ASM

section .rodata

    path_index  db "/templates/index.html", 0x00
    ; path_page2  db "./templates/page2.html", 0x00
    ; path_page3  db "./templates/page3.html", 0x00
    path_404        db "./templates/page404.html", 0x00
    home_path       db "/", 0x00

    ; per nessuna ragione l'utente deve poter inserire roba come
    ; http://<ip>:<port>/../../file.txt
    sub_path_for_fuck_me db "..", 0x00

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
 
    end:        db ");", 0x00

%endif