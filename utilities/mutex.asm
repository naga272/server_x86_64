
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
; ======================================================================================

; https://man7.org/linux/man-pages/man2/futex.2.html

%ifndef MUTEX_ASM
%define MUTEX_ASM

%include "./utilities/macro.asm"
%include "./utilities/stdio.asm"
%include "./utilities/sstring.asm"
%include "./utilities/thread.asm"

; long sys_futex(u32 *uaddr, int op, u32 val,
;               const struct timespec *timeout,   // o unsigned long per altre op
;               u32 *uaddr2, u32 val3);
;
; sys_futex = 202
; @uaddr    = ptr a un uint32_t, variabile
;             globale che e' il punto di incontro tra piu' thread
; @op       = usando dei Flags si possono rappresentare le operazioni da eseguire:
;              - FUTEX_WAIT = 0 -> mette in stato di sleep il thread solo se *uaddr == val, != altrimenti 
;              - FUTEX_WAKE = 1 -> sveglia fino a val thread addormentati
;              - FUTEX_PRIVATE_FLAG = 128 -> usato per ottimizzare se tutti i processi sono nello stesso processo
; @val      = dipende dai flag passati a op, con FUTEX_WAIT è il valore atteso. Se *uaddr != val non dorme
;             con FUTEX_WAKE il numero massimo di thread da svegliare
; @timeout  = NULL significa senza timeout, passa un (struct timespec*) si determina per quanto tempo deve dormire
; @uaddr    = NULL
; @val3     = NULL
; ret 0 se tutto ok, < 0 in caso di errore, > 0 per rappresentare il numero di thread svegliati
;

%ifndef FUTEX_WAIT
%define FUTEX_WAIT   0
%endif

%ifndef FUTEX_WAKE
%define FUTEX_WAKE   1
%endif

%ifndef FUTEX_PRIVATE_FLAG
%define FUTEX_PRIVATE_FLAG 128
%endif

section .text


; void mutex_lock(int *addr)
mutex_lock:
    STARTFOO
    .spin_try:
        mov eax, 1
        lock xchg dword [rdi], eax
        test eax, eax
        jz .got_lock
    ;   old_value != 0
    .wait_loop:
        mov eax, dword [rdi]
        cmp eax, 1
        jne .spin_try

        ; valore è ancora 1 -> chiamiamo futex WAIT
        ; futex(uaddr=rdi, FUTEX_WAIT, val=1, timeout=NULL, NULL, 0)
        mov rsi, FUTEX_WAIT         ; op
        mov edx, 1                  ; val atteso
        xor r10, r10                ; timeout = NULL
        xor r8, r8
        xor r9, r9
        mov rax, 202
        syscall
        ; futex può ritornare per vari motivi (wake, EINTR, spurious) -> riproviamo
        jmp .spin_try

    .got_lock:
        leave
        ret


; void mutex_unlock(int *addr)
mutex_unlock:
    STARTFOO
    mov dword [rdi], 0
    ; futex(uaddr=rdi, FUTEX_WAKE, nr=1, NULL, NULL, 0)
    mov rsi, FUTEX_WAKE ; op
    mov rdx, 1          ; sveglia massimo 1
    xor r10, r10        ; timeout = NULL
    xor r8, r8
    xor r9, r9
    mov rax, 202
    syscall
    leave
    ret

%endif