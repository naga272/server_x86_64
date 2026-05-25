
section .data
section .rodata



section .text


; 	r0: GET / HTTP/1.1
; 	r1: Host: 127.0.0.1:9000
; 	r2: User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0
; 	r3: Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8
; 	r4: Accept-Language: en-US,en;q=0.5
; 	r5: Accept-Encoding: gzip, deflate, br, zstd
; 	r6: Connection: keep-alive
; -> 	r7: Cookie: csrftoken=mOmuRdLUQOxhEpjMmtRbTOXZFlviMzPZ
; Upgrade-Insecure-Requests: 1
; Sec-Fetch-Dest: document
; Sec-Fetch-Mode: navigate
; Sec-Fetch-Site: none
; Sec-Fetch-User: ?1
; Priority: u=0, i
; Pragma: no-cache
; Cache-Control: no-cache


%include "./utilities/macro.asm"
%include "./utilities/sstring.asm"
%include "./utilities/stdlib.asm"


; size_t strlen_to_limiter(char*, char)
strlen_to_limiter:
	STARTFOO

	push rdi

	mov cl, byte[rsi]
	xor rax, rax
	.loop:	cmp byte[rdi], cl
		je .endloop
		inc rax
		inc rdi
		jmp .loop
	.endloop:
	
	pop rdi
	leave
	ret


; char* strcat_to_limiter(char* rdi, char *rsi, char rdx)
strcat_to_limiter:
	STARTFOO
	.loop:
		cmp byte[rdi + rax], dl
		je .end_loop

		mov bl, byte[rsi + rax]
		mov byte[rdi + rax], bl

		inc rax
		jmp .loop
	.end_loop:	
		leave
		ret


; char* get_csrf_token(char* r7)
get_csrf_token:
	STARTFOO

	push rdi

	; prendo fino al char '=' di r7
	mov rsi, 0x3d
	call strlen_to_limiter
	add rdi, rax	; rdi -> '='
	inc rdi

	mov rsi, 0x0a
	call strlen_to_limiter
	inc rax

	mov r8, rax

	push rdi

	mov rdi, r8
	call malloc

	mov byte[rax + r8], 0x00
	
	pop rdi  ; ripristino r7-> '=' + 1
	pop rdi

	leave
	ret


; char* get_cookie(char* fd_content)
get_cookie:
	STARTFOO
	
	push rdi
	push rcx

	; a ogni 
	xor rax, rax
	mov cl, 0x0a 

	.loop: 	cmp rax, 0x06
		je .endloop
		
		.loop_new_line:
			cmp byte[rdi], cl
			je .endloop_new_line

			inc rdi
			jmp .loop_new_line
		.endloop_new_line:
			inc rdi
			inc rax
			jmp .loop
	.endloop:		
		; punto al primo carattere della row 7 
		call get_csrf_token
		
		pop rcx
		pop rdi	; ripristino offset iniziale fd client
		
		leave
		ret


