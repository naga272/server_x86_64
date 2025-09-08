%ifndef PATHS_ASM
%define PATHS_ASM

%include "./utilities/macro.asm"
%include "./utilities/sstring.asm"
%include "./utilities/stdio.asm"
%include "./utilities/stdlib.asm"


section .rodata
section .data
section .bss
section .text

; char* str_prepend(char*, char)
str_prepend:
    STARTFOO
    push rbx
    push rdi
    push rsi

    mov rbx, rdi        ; rbx = string originale
    movzx rsi, sil      ; rsi = carattere (zero-extended)

    ; calcola nuova lunghezza
    mov rdi, rbx
    call strlen
    add rax, 2          ; +1 char extra, +1 terminatore

    ; alloca
    mov rdi, rax
    call calloc
    push rax

    mov rcx, rax        ; rcx = nuova stringa allocata
    ; scrivi il char davanti
    mov rdx, rsi
    mov byte [rcx], dl
    inc rcx

    ; copia l’originale
.copy_loop:
    mov al, [rbx]
    mov [rcx], al
    inc rcx
    inc rbx
    test al, al
    jnz .copy_loop

    pop rax
    pop rsi
    pop rdi
    pop rbx
    leave
    ret


get_path:
    STARTFOO
    push rdi
    push rsi
    push rbx
    push r15
    push r14
    push r13

    mov r14, rdi

    .search_first_space:
        cmp byte[r14], 32
        je .found_first_space
        inc r14
        jmp .search_first_space

    .found_first_space:
        inc r14         ; salto ' '
        mov r15, rdi

    .search_first_endl:
        cmp byte[r15], 0x0d
        je .search_second_space
        inc r15
        jmp .search_first_endl

    .search_second_space:
        cmp byte[r15], 32
        je .found_second_space

        dec r15
        jmp .search_second_space

    .found_second_space:
        mov rdi, r15
        sub rdi, r14    ; len path
        call calloc

        mov r13, rax
        mov rbx, 0
    .copy:
        cmp r15, r14    ; r14 punta allo stesso indirizzo di r15?
        je .done
        mov al, byte[r14]

        mov byte[r13 + rbx], al

        inc rbx
        inc r14
        jmp .copy
    .done:
        inc rbx
        mov al, byte[r15]
        mov byte[r13 + rbx], al
        mov rax, r13

        pop r13
        pop r14
        pop r15
        pop rbx
        pop rsi
        pop rdi
        leave
        ret

%endif