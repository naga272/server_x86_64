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



%ifndef MACRO_ASM
%define MACRO_ASM

%ifndef sizeof
%define sizeof(x) x %+ _size
%endif

%ifndef STARTALLFOO
%define STARTALLFOO
%macro STARTFOO 0
        endbr64
        push rbp
        mov rbp, rsp
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


%ifndef stdin
%define stdin 0
%endif


%ifndef stdout
%define stdout 1
%endif


%ifndef stderr
%define stderr 2
%endif

; SYSCALLS STD ;
%ifndef SYS_WRITE
%define SYS_WRITE       0x01
%endif

%ifndef SYS_READ
%define SYS_READ 0x00
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


%endif

