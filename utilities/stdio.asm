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



%ifndef STDIO_ASM
%define STDIO_ASM

%include "./utilities/macro.asm"

section .data 
section .bss
%ifndef DIGITSPACE
        %define DIGITSPACE
        digitSpace 	        resb 100
%endif

%ifndef DIGITSPACEPOS
%define DIGITSPACEPOS
        digitSpacePos 	        resb 8
%endif

section .text


; void input(char* rdi, size_t rsi)
input:  
    STARTFOO
    push rdi
    push rsi
    push rdx

    mov rdx, rsi
    mov rsi, rdi
    mov rdi, stdin
    mov rax, SYS_READ
    syscall
    
    pop rdx
    pop rsi
    pop rdi

    leave
    ret


print:  
    STARTFOO
    call strlen

    push rdx
    push rsi
    push rdi

    mov rdx, rax 
    mov rsi, rdi 
    mov rdi, stdout
    mov rax, SYS_WRITE
    syscall

    pop rdi
    pop rsi
    pop rdx
 
    leave
    ret


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

; char* int_to_str(int)
int_to_str:
    ; NB: restituisce memoria allocata dinamicamente 
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14
    push rbx
    push rdi

    mov r12, rdi        ; r12 = numero da convertire, SALVATO PRIMA DI MODIFICARE RDI

    mov rdi, 100        ; numero di byte da allocare
    call calloc
    mov r14, rax        ; r14 = ptr buffer
    mov r13, r14
    add r13, 100        ; punta alla fine del buffer
    mov byte [r13], 0   ; terminatore null

    cmp r12, 0
    jne .convert_loop
    dec r13
    mov byte [r13], '0'
    jmp .done

    .convert_loop:
        xor rdx, rdx
        mov rax, r12
        mov rbx, 10
        div rbx
        add dl, '0'
        dec r13
        mov [r13], dl
        mov r12, rax
        test r12, r12
        jnz .convert_loop

    .done:
        mov rax, r13         ; ritorna puntatore alla stringa
        pop rdi
        pop rbx
        pop r14
        pop r13
        pop r12
        leave
        ret

%endif
