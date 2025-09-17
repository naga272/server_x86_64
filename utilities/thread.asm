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


global create_thread
; global _start
default rel

; https://man7.org/linux/man-pages/man2/clone.2.html

%ifndef THREAD_ASM
%define THREAD_ASM

%define CLONE_VM        0x00000100 ; Condivide lo spazio di indirizzi (memoria) tra padre e figlio
%define CLONE_FS        0x00000200 ; Condivide info filesystem (cwd, umask)
%define CLONE_FILES     0x00000400 ; Condivide file descriptors
%define CLONE_SIGHAND   0x00000800 ;Condivide signal handlers

%define SIGHUP	    1	; Hangup (controllo terminale chiuso)
%define SIGINT	    2	; Interruzione (Ctrl+C)
%define SIGQUIT	    3	; Uscita (Ctrl+)
%define SIGILL	    4	; Istruzione illegale
%define SIGTRAP	    5	; Trap (trappola)
%define SIGABRT	    6	; Aborto
%define SIGBUS	    7	; Errore di bus
%define SIGFPE	    8	; Eccezione in virgola mobile
%define SIGKILL     9   ; Terminazione forzata, non catturabile
%define SIGUSR1     10  ; Segnale utente definito dall’applicazione
%define SIGSEGV	    11	; Violazione di segmentazione
%define SIGUSR2     12  ; Altro segnale utente definito dall’applicazione
%define SIGPIPE	    13	; Pipe rotta
%define SIGALRM	    14	; Timer scaduto
%define SIGTERM     15  ; Terminazione richiesta
%define SIGSTKFLT	16	; Errore di stack sul coprocessore
%define SIGCHLD     17  ; Il figlio è terminato
%define SIGCONT	    18	; Continua l'esecuzione
%define SIGSTOP	    19	; Ferma l'esecuzione (non catturabile)
%define SIGTSTP	    20	; Ferma l'esecuzione (Ctrl+Z)
%define SIGTTIN	    21	; Lettura in background da terminale
%define SIGTTOU	    22	; Scrittura in background su terminale
%define SIGURG	    23	; Dati urgenti disponibili su socket
%define SIGXCPU	    24	; Limite di tempo CPU superato
%define SIGXFSZ	    25	; Limite di dimensione file superato
%define SIGVTALRM	26	; Timer virtuale scaduto
%define SIGPROF	    27	; Timer di profiling scaduto
%define SIGWINCH	28	; Cambio di dimensione finestra terminale
%define SIGPOLL	    29	; Evento pollable
%define SIGIO	    29	; I/O ora possibile
%define SIGPWR	    30	; Guasto di alimentazione
%define SIGSYS	    31	; Chiamata di sistema non valida
%define CHILD_STACK_SIZE (16*1024)  ; stack per il figlio


%define ECHILD -10

%include "./utilities/stdlib.asm"
%include "./utilities/mutex.asm"

section .data

args:
    .rdx:       dq 0x00
    .rdi:       dq 0x00
    .rsi:       dq 0x00
    .r8:        dq 0x00
    .r9:        dq 0x00
    ; usabili in caso di variadic foo
    .r10:       dq 0x00
    .r11:       dq 0x00
    .r12:       dq 0x00
    .r13:       dq 0x00
    .r14:       dq 0x00
    .r15:       dq 0x00
    .args_del:  dq 0x00
    .end:

; sizeof(struct clone_args)
%define len_clone_args clone_args.end - clone_args

; sizeof(struct args)
%define len_struct_args args.end - args ; 88 + padding
%define off_rdx 0
%define off_rdi 8 
%define off_rsi 16
%define off_r8  24
%define off_r9  32
%define off_r10 40
%define off_r11 48
%define off_r12 56
%define off_r13 64
%define off_r14 72
%define off_r15 80
%define __del__ 88


section .rodata
err_clone  db "clone() failed", ENDL, 0

section .bss
    ; stato terminazione dei figli
    status resd 1
section .text


fork: endbr64
    push rbp
    mov rbp, rsp

    mov rax, 57
    syscall

    leave
    ret


; rdi = funzione da chiamare
; rsi = args* (struct con registri/parametri)
do_clone:
    endbr64
    push rbp
    mov rbp, rsp

    mov r15, rdi ; void (*foo)()
    mov r14, rsi ; args*

    mov rdi, CHILD_STACK_SIZE
    call malloc

    ; ----- clone(child_func, stack_top, SIGCHLD, arg); -----

    ; salvo il ptr a heap (perche' dovro' fare la free)
    mov r12, rax
    ; foo ptr
    ; STACK: lo stack cresce verso il basso, quindi devo passare
    ; a clone il punto piu' alto
    mov rsi, rax
    add rsi, CHILD_STACK_SIZE
    and  rsi, -16                ; allinea a 16

    ; flags
    ; NB: senza SIGCHLD il kernel non li considera "veri e propri figli", li vede
    ; come dei figliastri di cui vergognarsi
    mov rdi, CLONE_VM | CLONE_SIGHAND | CLONE_FILES | CLONE_FS | SIGCHLD
    xor rdx, rdx 
    xor r10, r10
    xor r8, r8
    xor r9, r9
    ; sys_clone
    mov rax, 56
    syscall

    test rax, rax
    js .error
    jz .child

    mov rdi, r12
    call free

    leave
    ret
    .error:
        lea rdi, [rel err_clone]
        call print
        mov rdi, EXIT_FAILURE
        call _exit
    .child:
        ; r15 = fn (salvato PRIMA della syscall)
        ; r14 = args* (puntatore a struct args)
        ; rsp è lo stack del child (fornito a clone)

        ; salva fn da qualche parte sicuro (sul suo stack)
        push    r15                ; fn_saved
        mov     rbx, r14           ; rbx = args*

        ; ripristino i registri
        mov     rdi, [rbx + off_rdi]
        mov     rsi, [rbx + off_rsi]
        mov     rdx, [rbx + off_rdx]
        mov     r8,  [rbx + off_r8]
        mov     r9,  [rbx + off_r9]
        mov     r10, [rbx + off_r10]
        mov     r11, [rbx + off_r11]
        mov     r12, [rbx + off_r12]
        mov     r13, [rbx + off_r13]
        mov     r14, [rbx + off_r14]
        mov     r15, [rbx + off_r15]
        mov     rax, [rbx + __del__]   ; rax = args_del (fptr)
        
        ; eliminazione oggetto args
        ; in __del__ viene usato rdi
        push    rdi
        mov     rdi, rbx               ; primo arg per args_del = args*
        call    rax                    ; free(*args)
        pop     rdi

        ; ripristino il ptr a funzione
        ; e faccio la chiamata
        pop     rax
        call    rax

        mov rdi, EXIT_SUCCESS
        call _exit


; void args_del(args*)
args_del: 
    endbr64
    push rbp
    mov rbp, rsp

    call free

    leave
    ret


save_register:
    endbr64
    push rbp
    mov rbp, rsp

    mov rdi, len_struct_args
    call calloc ; rax = void*
    mov qword[rax + __del__], args_del

    leave
    ret


; void create_thread(void (*fn)(int, ...), arg1, arg2, arg3, ...)
create_thread:
    endbr64
    push rbp
    mov rbp, rsp

    push rdi
    push rsi
    push rdx
    push r8
    push r9
    push r10
    push r11
    ; mov rdi, rsi
    call save_register ; rax = register*
    pop r11
    pop r10
    pop r9
    pop r8
    pop rdx
    pop rsi
    pop rdi

    ; salvo gli argomenti passati a create_thread per farglieli
    ; eseguire al thread quando entra la funzione
    mov [rax + off_rdi], rsi
    mov [rax + off_rsi], rdx
    mov [rax + off_rdx], r8
    mov [rax + off_r8], r9
    mov [rax + off_r9], r10
    mov [rax + off_r10], r11
    mov [rax + off_r11], r12
    mov [rax + off_r12], r13
    mov [rax + off_r13], r14
    mov [rax + off_r14], r15

    ; do_clone(void (*rdi)(), args* rsi)
    mov rsi, rax
    call do_clone

    leave
    ret


; pid_t wait4(pid_t pid, int *status, int options, struct rusage *rusage);
waitpid:
    ; NB: sys_wait4 corrompe il contenuto dei registri
    STARTFOO
    push rdi
    push rsi
    push rdx
    push r10

    mov rax, 61 ; sys_wait4
    syscall

    pop r10
    pop rdx
    pop rsi
    pop rdi
    leave
    ret


waitallpid:
    STARTFOO
    mov rdi, -1             ; pid = -1 -> qualunque figlio
    lea rsi, [rel status]   ; puntatore a status
    xor rdx, rdx            ; options = 0
    xor r10, r10            ; rusage = NULL

    .loop:
        ; NB: sys_wait4 corrompe il contenuto dei registri
        call waitpid

        cmp rax, ECHILD
        je .done                ; nessun figlio rimasto
        jmp .loop
    .done:
        leave
        ret


%endif