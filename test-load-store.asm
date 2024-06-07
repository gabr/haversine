global read_1
global read_2
global read_3
global read_4
global stor_1
global stor_2
global stor_3
global stor_4


section .text

read_1:
	align 64
.loop:
    mov rax, [rsi]
    sub rdi, 1
    jnle .loop
    ret

read_2:
	align 64
.loop:
    mov rax, [rsi]
    mov rax, [rsi]
    sub rdi, 2
    jnle .loop
    ret

read_3:
	align 64
.loop:
    mov rax, [rsi]
    mov rax, [rsi]
    mov rax, [rsi]
    sub rdi, 3
    jnle .loop
    ret

read_4:
	align 64
.loop:
    mov rax, [rsi]
    mov rax, [rsi]
    mov rax, [rsi]
    mov rax, [rsi]
    sub rdi, 4
    jnle .loop
    ret


stor_1:
	align 64
    mov rax, 1
.loop:
    mov [rsi], rax
    sub rdi, 1
    jnle .loop
    ret

stor_2:
	align 64
    mov rax, 1
.loop:
    mov [rsi], rax
    mov [rsi], rax
    sub rdi, 2
    jnle .loop
    ret

stor_3:
	align 64
    mov rax, 1
.loop:
    mov [rsi], rax
    mov [rsi], rax
    mov [rsi], rax
    sub rdi, 3
    jnle .loop
    ret

stor_4:
	align 64
    mov rax, 1
.loop:
    mov [rsi], rax
    mov [rsi], rax
    mov [rsi], rax
    mov [rsi], rax
    sub rdi, 4
    jnle .loop
    ret

