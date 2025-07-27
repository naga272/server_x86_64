
%ifndef STRING_ASM
%define STRING_ASM

; %define TESTMAIN_STRING

%ifndef STARTALLFOO
%define STARTALLFOO
%macro STARTFOO 0
        endbr64
        push rbp
        mov rbp, rsp
%endmacro
%endif


%ifndef GPUSH
%define GPUSH  ; general PUSH   
%macro GPUSH 0
        push rax
        push rbx
        push rcx
        push rdx
%endmacro
%endif


%ifndef GPOP
%define GPOP  ; general POP    
%macro GPOP 0
        pop rdx
        pop rcx
        pop rbx
        pop rax
        pop rdi
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


%ifndef EXIT_SUCCESS
%define EXIT_SUCCESS 0
%endif


%ifndef EXIT_FAILURE
%define EXIT_FAILURE 1
%endif


%ifndef ENDL
%define ENDL 0x0d, 0x0a
%endif


section .rodata
        msg_err_malloc          db "Si e' verificato un'errore nel tentativo di allocazione della memoria", ENDL, 0x00     
        msg_error_remove_size   db "Hai tentato di rimuovere piu caratteri di quelli presenti nella stringa! stupid bastard.", ENDL, 0x00

section .data

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       String():
;               def __init__(self, msg: str):
;                       self.content = msg
;                       self.size_content = len(msg)
;               def len(self) -> long int                               # return @self.content length
;               def append(self, msg_to_append: str) -> None            # append msg_to_append to @self.content
;               def remove(self, n: int) -> None                        # remove n chars from @self.content
;               def startswith(self, msg: str) -> long int              # verifica che la stringa comincia con msg
;               def endswith(self, msg: str) -> long int                # verifica che la stringa finisce con msg
;               def replace(self, substring: str, rep: str) -> None     # replace a substring of self.content with rep 
;               def __del__(self) -> None                               # delete the String object
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

string:
        .content:        dq 0x00        ; char *ptr
        .size_content:   dq 0x00        ; long int size_content
        .len:            dq 0x00        ; long int      (*__len)        (struct string* rdi)
        .append_str:     dq 0x00        ; void          (*__append_str) (struct string* rdi, char* rsi)
        .append_chr      dq 0x00        ; void          (*__append_chr) (struct string* rdi, char rsi)
        .remove:         dq 0x00        ; void          (*__pop)        (struct string* rdi, long int rsi)
        .replace:        dq 0x00        ; void          (*__replace)    (struct string* rdi, char* rsi, char* rdx)
        .reverse:        dq 0x00        ; void          (*__reverse)    (struct string* rdi)
        .startswith:     dq 0x00        ; long int      (*__startswith) (struct string* rdi, char* rsi)
        .endswith:       dq 0x00        ; long int      (*__endswith)   (struct string* rdi, char* rsi)
        .__del__:        dq 0x00        ; void          (*del)          (struct string* rdi)
end_string:


%ifdef TESTMAIN_STRING          ; usato per il testing di questo modulo
obj_string      dq 0x00
msg             db "Hello world", ENDL, 0x00
strcat_msg      db "sono in strcat", ENDL, 0x00
%endif

section .bss

%ifdef TESTMAIN_STRING          ; usato per il testing di questo modulo
        digitSpace      resb 100	; usata per print_int
	digitSpacePos	resb 8		; usata per print_int
%endif

section .text
        global _start


%ifndef size_struct_string
%define size_struct_string      end_string - string
%endif


%ifndef content
%define content                 end_string - string.content
%endif


%ifndef size_content
%define size_content            end_string - string.size_content
%endif


; metodi
%ifndef append_str
%define append_str              end_string - string.append_str
%endif

%ifndef append_chr
%define append_chr              end_string - string.append_chr
%endif

%ifndef reverse
%define reverse                 end_string - string.reverse
%endif

%ifndef len
%define len                     end_string - string.len
%endif


%ifndef remove
%define remove                  end_string - string.remove
%endif


%ifndef replace
%define replace                 end_string - string.replace
%endif


%ifndef startswith
%define startswith              end_string - string.startswith
%endif


%ifndef endswith
%define endswith                end_string - string.endswith
%endif


%ifndef __del__
%define __del__                 end_string - string.__del__
%endif


%ifndef stdin
%define stdin 0
%endif


%ifndef stdout
%define stdout 1
%endif


%ifndef stderr
%define stderr 2
%endif


; flags per mmap
%define MAP_PRIVATE     0x02      ; Cambi locali, niente sync su file
%define MAP_ANONYMOUS   0x20      ; Nessun file backing (solo RAM)
%define MAP_STACK       0x20000   ; Allocazione ottimizzata per stack
%define MAP_GROWSDOWN   0x00100   ; Stack cresce verso indirizzi bassi


%ifndef PROT_READ
%define PROT_READ       0x1
%endif


%ifndef PROT_WRITE
%define PROT_WRITE      0x2
%endif


%ifndef PROT_EXEC
%define PROT_EXEC       0x4
%endif


%ifndef PROT_NONE
%define PROT_NONE       0x8
%endif


%ifndef SYS_WRITE
%define SYS_WRITE       0x01
%endif


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


; long int strlen(char *rdi)
strlen: STARTFOO
        push rdi
        mov rax, -0x01
        .repeat:prefetcht0[rdi + rax + 128]
                inc rax
                cmp byte[rdi + rax], 0x00
                jne .repeat

        .done:  pop rdi
                leave
                ret


; long int print(char *rdi)
print:  STARTFOO
        push rdi
        push rsi
        push rcx

        call strlen

        mov rdx, rax
        mov rax, SYS_WRITE
        mov rsi, rdi
        mov rdi, stdout
        syscall

        pop rcx
        pop rsi
        pop rdi
        mov rax, rdx
        leave
        ret


%ifdef TESTMAIN_STRING
; int print_int(int rdi);
print_int:	
        ; funzione che stampa a schermo un numero intero,
        ; accetta come parametro un solo intero
        STARTFOO
        push rbx
        push rcx
        push rdx        
        push rdi
        push rsi
        
        mov rax, rdi         ; carico l'intero passato come argomento

        mov rcx, digitSpace	    ; carico l'indirizzo di digitSpace (e' un vettore di 100 elementi)	
        mov rbx, 10		    ; base 10
        mov [rcx], rbx              ; inizializzo la base nel buffer 
        inc rcx                     ; avanzo la posizione del buffer
        mov [digitSpacePos], rcx    ; salvo la posizione

        .st_loop:	
                xor rdx, rdx		; mi preparo per la divisione
                div rbx			; divido il contenuto di rax per rbx
                push rax                ; salvo il quoziente nello stack (il resto si trova in rdx)
                add rdx, 48             ; (0 <= rdx <= 9) + 48, mi consente di trovare il carattere ascii che corrisponde al numero

                mov rcx, [digitSpacePos]    ; carico la posizione corrente nel buffer
                mov [rcx], dl               ; il carattere lo vado a memorizzare nel buffer
                inc rcx
                mov [digitSpacePos], rcx    ; vado ad aggiornale la posizione

                pop rax
                cmp rax, 0                  ; se il quoziente risulta 0 significa che ho finito 
                jne .st_loop

        ; a questo punto digitSpace contiene il numero in ordine inverso (centinaia, decine, unita') -> (unita', decine, centinaia)
        .end_loop:
                mov rax, 1
                mov rdx, 1
                mov rdi, stdout
                mov rsi, rcx
                syscall

                mov rcx, [digitSpacePos]
                dec rcx

                mov [digitSpacePos], rcx

                cmp rcx, digitSpace
                jge .end_loop

        pop rsi
        pop rdi
        pop rdx
        pop rcx
        pop rbx
        mov rax, EXIT_SUCCESS
        leave
        ret
%endif


mmap:   STARTFOO

        mov rax, 9
        syscall

        leave
        ret


; void* malloc(size_t rdi)
malloc: STARTFOO
        push r9
        push r8
        push r10
 
        mov rsi, rdi
        mov rdi, 0x00
        mov rdx, PROT_WRITE | PROT_READ         ; 0b0011
        mov r10, 0x22
        mov r8, -1
        mov r9, 0x00
        call mmap
        
        test rax, rax

        pop r10
        pop r8
        pop r9

        js .error
        leave
        ret
        .error: mov rdi, msg_err_malloc
                call print
                mov rdi, EXIT_FAILURE
                call _exit


; void* memset(void* rdi, long int rsi, long int rdx)
memset: STARTFOO
        push rcx

        mov rcx, -0x1
        .loop:  prefetcht0[rdi + rax + 128]
                inc rcx
                mov byte[rdi + rcx], sil
                
                cmp rcx, rdx
                jns .loop

        mov rax, rdi

        pop rcx
        leave
        ret


; void* calloc(size_t rdi)
calloc: STARTFOO
        push rdi
        call malloc
        pop rdi

        mov rdx, rdi    ; size_t
        mov rsi, 0x0    ; int n
        mov rdi, rax    ; void*
       
        call memset
        leave
        ret


; void* strcat(char* rdi, char* rsi)
strcat: STARTFOO
        push r15
        push rsi 
        push rbx
        push rdi            ; salviamo rdi originale (dest) per ripristinarlo

        mov r15, rdi        ; salviamo dest in r15

        call strlen         ; strlen(dest) -> rax = len(dest)

        mov rdi, r15        ; ripristina rdi (dest)

        dec rsi
        .to_copy:
                prefetcht0[rsi + rax + 128]
                inc rsi
                mov bl, byte [rsi]
                mov byte [rdi + rax], bl

                inc rax
                cmp bl, 0
                jne .to_copy

        pop rdi
        pop rbx
        pop rsi
        pop r15
        leave
        ret


; void* realloc(void* rdi, size_t rsi)
; rsi e' la nuova grandezza
realloc: STARTFOO
        push r14
        push rcx

        push rdi        ; salvo il ptr attuale
        mov rdi, rsi    ; nuova grandezza
        call calloc
        pop rdi         ; ripristino il ptr passato come parametro

        push rdi        ; salvo void* ptr passato come parametro a realloc

        ; void* strcat(char* rdi, char* rsi)
        mov rsi, rdi    ; ptr passato come parametro a realloc
        mov rdi, rax    ; nuovo ptr allocato
        call strcat
        mov r14, rdi

        pop rdi         ; ripristino il ptr passato come parametro a realloc
        call free       ; libero la zona allocata del ptr passato come parametro a realloc

        mov rdi, r14
        mov rax, rdi
        pop rcx
        pop r14
        leave
        ret


; void munmap(void* rdi)
munmap: STARTFOO

        cmp rdi, 0x00
        je .NULL

        mov rax, 11
        syscall
        
        .NULL:  leave
                ret


; void free(void* rdi)
free:   STARTFOO

        cmp rdi, 0x00
        je .NULL        ; in caso si tenta di fare la free di un ptr nullo
        call munmap
        
        .NULL:  leave
                ret


; void __append_chr(struct string* rdi, char rsi)
foo_append_chr:
        STARTFOO
        push rdi
        push rbx
        push rdx
        push rsi

        mov rbx, rdi ; ptr a struct string*        

        mov rdi, [rdi + content]
        call strlen

        mov rdx, [rbx + size_content]   ; total
        sub rdx, rax                    ; total number of free char 
        cmp rdx, 0x00
        jge .create_space
        .continue:
                mov rdi, [rbx + content]
                call strlen
                pop rsi                         ; ripristino param. char
                mov byte[rdi + rax], sil        ; lo inserisco come ultimo char

                pop rdx
                pop rbx
                pop rdi
                leave
                ret
        .create_space:

                mov rdi, [rbx + content]
                mov rsi, [rbx + size_content]
                inc rsi
                call realloc

                mov [rbx + content], rax        ; new ptr
                inc qword[rbx + size_content]   ; add 1 alla lunghezza totale
                jmp .continue 


; void __append_str(struct string* rdi, char* rsi)
foo_append_str: 
        STARTFOO
        push rbx
        push rcx
        push r15

        mov rbx, rdi                            ; rbx = struct string* rdi
        mov r15, rbx
        mov rcx, rsi                            ; rcx = char* rsi

        mov rdi, [rbx + content]
        call strlen                             ; calcolo la len di rdi->content

        push r10 
        mov r10, rax                            ; salvo la len di rdi->content in r10 temporaneamente

        mov rdi, rcx                            ; calcolo la len della stringa da appendere a rdi->content
        call strlen

        sub r10, [rbx + size_content]           ; trovo il numero di bytes liberi in rdi->content (quelli che hanno 0x00)
        cmp r10, rax                            ; confronto per vedere se rdi->content puo' contenere tutti i caratteri di rsi 
        js .create_new_space                    ; in caso non e' così realloco i bytes che mi servono
        .do_append:
                mov rdi, [rbx + content]
                mov rsi, rcx            ; rsi = char* rsi

                call strcat
                ;
                mov [rbx + content], rdi
                pop r10                 ; ripristino r10
                pop r15                 ; ripristino r15
                pop rcx                 ; ripristino rcx
                pop rbx                 ; ripristino rbx

                leave
                ret
        .create_new_space:
                ; nuova size da allocare per rdi->content
                ; void* realloc(void* rdi, size_t rsi)
                mov rdi, [rbx + content]                    ; ptr a rdi->content
                mov rsi, [rbx + size_content]               ; len di rdi->content
                add rsi, rax                                    ; len(rdi->content) + len(char* rcx)
                inc rsi                                         ; len(rdi->content) + len(char* rcx) + len('\0')
                
                push rsi                                        ; salvo la nuova size per la stringa
                push rcx
                call realloc                                    ; realloc restituisce in rax il new ptr
                mov [rbx + content], rax

                pop rcx
                pop rsi                                         ; ripristino la size della stringa
                mov [rbx + size_content], rsi               ; aggiorno con la nuova len della stringa

                jmp .do_append


; void __remove(struct string* rdi, long int rsi)
foo_remove: STARTFOO
        ; funzione che rimuove rsi caratteri finali da @content
        cmp rsi, 0x00
        je .error

        push rax
        push r10
        mov r10, [rdi + content]
        add r10, size_content

        mov rax, -0x01
        .loop:  inc rax
                mov byte[r10], 0x00
                dec r10
                cmp rax, rsi
                jne .loop
        pop r10
        pop rax
        leave
        ret
        .error: mov rdi, msg_error_remove_size
                call print
                mov rdi, EXIT_FAILURE
                call _exit


; void __del__(struct string* rdi)
foo_del:  STARTFOO
        push rdi
        mov rdi, qword[rdi + content]    ; libero la memoria puntata a rdi->content
        call free

        pop rdi
        call free       ; libero la struct allocata

        leave
        ret


; long int foo_len (struct string* rdi)
foo_len:STARTFOO
        mov rax, [rdi + size_content]
        leave
        ret


; void foo_replace (struct string* rdi, char* rsi, char* rdx)
foo_replace:
        STARTFOO
        push rdi
        GPUSH

        GXOR_ALL

        mov rax, -0x01 
        xor rbx, rbx
        xor rcx, rcx       
        xor rdx, rdx

        mov rdi, rsi
        call strlen

        cmp rax, 0x00   ; (rsi == NULL)?
        je .end
        
        mov rcx, rax    ; len secondo vettore
        .loop:  inc rax
                ; caso fine stringa rdi
                cmp byte[rdi + rax], 0x00 
                je .end

                ; mov r15, byte[rsi + rbx]
                ; cmp byte[rdi + rax], r15
                jne .resetR15

                ; caso in cui la sottostringa sta apparendo nella stringa, 
                ; ma deve ancora terminare di matchare
                inc rbx
                cmp rcx, rbx
                jne .loop

                

                ; caso rsi != rdi azzero il contatore rbx
                .resetR15:
                        xor rbx, rbx
                        jmp .loop

        .end:   GPOP
                pop rdi
                leave
                ret


; long int foo_startswith(struct string* rdi, char *rsi)
foo_startswith:
        ; rdi inizia con char* rsi? 0x00 if true, -0x01 if false
        STARTFOO
        push rdi
        push r10

        mov r10, rsi
        mov rax, -0x01
        ; while(*rsi)
        .loop:  inc rax

                mov bl, byte[rsi + rax]
                cmp bl, 0x00            ; (*rsi == NULL)?
                je .GG

                cmp bl, byte[rdi + rax] ; (*rsi == *rdi)?
                jne .bad_end

                jmp .loop

        .GG:    mov rax, 0x00
                jmp .done

        .bad_end: mov rax, -0x01
        .done:  pop r10
                pop rdi
                leave
                ret


; long int foo_endswith(struct string* rdi, char *rsi)
foo_endswith:
        ; rdi finisce con char* rsi?
        STARTFOO
        
        GPUSH
        push rdi
        push rsi

        mov rdi, rsi
        call strlen
        pop rdi
        mov rdx, rax                    ; len(rsi)

        mov rcx, [rdi + content]
        add rcx, [rdi + size_content]
        sub rcx, rdx
        sub rsi, -0x01
        ; while (*rsi)
        .loop:  inc rsi
                cmp byte[rsi], 0x00
                je .GG
                mov bl, byte[rdi]
                cmp bl, byte[rsi] 
                inc rsi
                jmp .loop
        .bad_ending:
                mov rax, 0x00
                jmp .done
        .GG:    mov rax, 0x01
        .done:  pop rsi
                pop rdi
                GPOP
                leave
                ret


; void foo_reverse(struct string* rdi)
foo_reverse:
        STARTFOO
        push rdi            ; salva rdi (puntatore originale)

        ; Trova la lunghezza della stringa
        mov rsi, rdi        ; copia il puntatore
                .find_len:
                cmp byte [rsi], 0
                je .len_found
                inc rsi
                jmp .find_len

        .len_found:
                dec rsi             ; ora rsi punta all'ultimo carattere (non '\0')

        ; Scambio in-place tra inizio (rdi) e fine (rsi)
        .reverse_loop:
                cmp rdi, rsi
                jge .done

                ; scambia byte [rdi] <-> byte [rsi]
                mov al, [rdi]
                mov bl, [rsi]
                mov [rdi], bl
                mov [rsi], al

                inc rdi
                dec rsi
                jmp .reverse_loop

        .done:  pop rdi
                ret


; struct string* String(char *rdi)
String: STARTFOO
        ; NB:
        ; per la creazione degli oggetti String,
        ; vengono modificati i valori dei registri r9, rbx, r12
        ; per questo ho deciso di pusharli nello stack
        push r9
        push rbx
        push r12
        mov r12, rdi                    ; salvo il ptr a stringa originale

        ; alloco struct
        mov rdi, size_struct_string
        call calloc

        mov rbx, rax
        ; inizializzazione dei puntatori a funzione
        mov qword [rbx + remove], foo_remove
        mov qword [rbx + len], foo_len
        mov qword [rbx + replace], foo_replace
        mov qword [rbx + startswith], foo_startswith
        mov qword [rbx + endswith], foo_endswith
        mov qword [rbx + reverse], foo_reverse
        mov qword [rbx + append_str], foo_append_str
        mov qword [rbx + append_chr], foo_append_chr
        mov qword [rbx + __del__], foo_del

        ; allocazione e inizializzazione di object->content
        
        cmp r12, 0x00
        je .min_size                    ; grandezza minima (evito errori in casi come rdi == '')

        mov rdi, r12
        call strlen
        inc rax                         ; spazio per il null terminator
        jmp .normal_continue

        .min_size:
                mov rax, 20
        .normal_continue:
                mov [rbx + size_content], rax
                mov rdi, rax
                call calloc

                mov [rbx + content], rax

                mov rdi, rax
                mov rsi, r12
                call strcat

                mov rax, rbx                    ; return string*
                pop r12
                pop rbx
                pop r9
                leave
                ret


%ifdef TESTMAIN_STRING  ; usato per il testing di questo modulo
main:   STARTFOO
        mov rdi, msg
        call String
        mov [obj_string], rax           ; salva l'oggetto

        mov rdi, [obj_string]           ; struct string* self
        mov rsi, msg                    ; vettore da appendere 
        call [rdi + append_str] 

        mov rdi, [obj_string]
        mov rsi, 48
        call [rdi + append_chr]

        ; stampa il contenuto di size_content
        mov rdi, [obj_string]                           ; object puntato con var obj_string
        mov rdi, [rdi + size_content]
        call print_int

        mov rbx, [obj_string]
        mov rdi, [rbx + content]
        call print

        mov rdi, [obj_string]
        call [rdi + __del__]

        mov rax, EXIT_SUCCESS
        leave
        ret


_start: endbr64
        GXOR
        call main
        mov rdi, rax
        call _exit


%ifndef _EXIT
%define _EXIT
_exit:  endbr64
        mov rax, 60
        syscall
%endif

%endif

%endif
