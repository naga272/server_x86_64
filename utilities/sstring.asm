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



; Static String Library assembly

%ifndef SSTRING_ASM
%define SSTRING_ASM

%include "./utilities/macro.asm"

section .data
section .bss
section .text

; void *strcat(char *dest, const char *src)
; ret: ptr a dest in rax
strcat:
    STARTFOO

    push rbx
    push rdi
    push rsi
    push rdx

    mov  rbx, rdi            ; rbx = dest originale (per il return)
    mov  rdx, rdi            ; rdx = cursore su dest per cercare '\0'

    .find_end:
        mov  al, [rdx]           ; carica byte corrente
        test al, al              ; è zero?
        je   .copy_start
        inc  rdx
        jmp  .find_end

    .copy_start:
    ; Copia src -> (fine di dest), includendo il terminatore
    .copy_loop:
        mov  al, [rsi]           ; al = *src
        mov  [rdx], al           ; *dest_end = al
        inc  rsi
        inc  rdx
        test al, al              ; se non era '\0', continua
        jne  .copy_loop

    mov  rax, rbx
    pop  rdx
    pop  rsi
    pop  rdi
    pop  rbx
    leave
    ret


; char* add_chr(char*, char)
add_chr:
    STARTFOO

    call strlen

    mov al, byte[rsi]
    mov byte[rdi + rax], al
    mov byte[rdi + rax + 1], 0x00

    mov rax, rdi
    leave
    ret


; char* add_chr(char*)
add_nl:
    ; aggiunge alla riga \r\d
    STARTFOO
    push rsi

    mov rsi, 0x0d
    call add_chr

    mov rsi, 0x0a
    call add_chr

    pop rsi
    leave
    ret


; strlen: versione ottimizzata AVX2 per x86-64 (System V ABI)
; input: RDI -> puntatore a stringa terminata da 0
; output: RAX = lunghezza (numero di byte prima del byte 0)
; requisito: CPU con AVX2, NASM/YASM, Linux x86-64
; note: non salva registri callee-saved (usi caller-saved solo), chiama vzeroupper prima del return.
strlen:
    ; rdi = ptr
    xor     rax, rax            ; offset accumulato (usato come contatore di lunghezza)
    vxorps  ymm1, ymm1, ymm1    ; ymm1 = 0 (usato per confronto)

    .loop:
        vmovdqu ymm0, [rdi + rax]   ; carica 32 byte non-allineati
        vpcmpeqb ymm2, ymm0, ymm1   ; confronta ogni byte con 0 => byte = 0 ? 0xFF : 0x00
        vpmovmskb edx, ymm2         ; riduce i 32 byte in una maschera a 32 bit (LSB corrisponde al byte 0)
        test    edx, edx
        jnz     .found              ; se qualche zero è presente, trova la posizione
        add     rax, 32
        jmp     .loop

    .found:
        bsf     ecx, edx            ; trova l'indice del primo byte zero (0..31)
        add     rax, rcx            ; lunghezza = offset + indice
        vzeroupper                  ; evita penalty di transizione AVX->SSE
        ret


; int strcmp(char*, char*)
strcmp:
    ; se sono uguali restituisce 0
    STARTFOO
    push rdi
    push rsi
    push rdx

    .loop:
        movzx rax, byte[rdi]
        movzx rdx, byte[rsi]
        cmp al, dl
        jne .diff
        test al, al
        je .equal
        inc rdi
        inc rsi
        jmp .loop

    .diff:
        ; rax contiene *s1, rdx contiene *s2
        ; (int)(rax - rdx)
        sub rax, rdx
    .end: 
        pop rdx
        pop rsi
        pop rdi
        leave
        ret

    .equal:
        xor rax, rax
        jmp .end

%endif
