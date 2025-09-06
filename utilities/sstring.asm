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
global strcat
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


; long int strlen(char *rdi)
strlen: STARTFOO
    push rdi
    push rsi
    push rcx

    mov rsi, rdi
    mov al, 0x00
    mov rcx, 0xffffffffffffffff
    cld
    repne scasb

    not rcx
    dec rcx
    mov rax, rcx

    pop rcx
    pop rsi
    pop rdi
    leave
    ret


%endif
