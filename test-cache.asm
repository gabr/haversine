global cacheTest1
global cacheTest2
global cacheTest3
global cacheTest4
global cacheTest5

section .text

; rdi - n - how much bytes to read
; rsi - data base pointer
; rdx - mask over data offset
cacheTest1:
	align 64
    xor rax, rax ; data offset
.loop:
    vmovdqu ymm0, [rsi+rax]
    vmovdqu ymm0, [rsi+rax+32]
    add rax, 64
    and rax, rdx
    sub rdi, 64
    jnle .loop
    ret

; rdi - n - how much bytes to read
; rsi - data base pointer
; rdx - mask over data offset
cacheTest2:
	align 64
    xor rax, rax ; data offset
.loop:
    vmovdqu ymm0, [rsi+rax]
    vmovdqu ymm0, [rsi+rax+32]
    vmovdqu ymm0, [rsi+rax+64]
    vmovdqu ymm0, [rsi+rax+128]
    add rax, 128
    and rax, rdx
    sub rdi, 128
    jnle .loop
    ret

; rdi - n - how much bytes to read
; rsi - data base pointer
; rdx - mask over data offset
cacheTest3:
	align 64
    xor rax, rax ; data offset
.loop:
    vmovdqu ymm0, [rsi+rax]
    vmovdqu ymm1, [rsi+rax+32]
    vmovdqu ymm2, [rsi+rax+64]
    vmovdqu ymm3, [rsi+rax+128]
    add rax, 128
    and rax, rdx
    sub rdi, 128
    jnle .loop
    ret

; rdi - n - how much bytes to read
; rsi - data base pointer
; rdx - mask over data offset
cacheTest4:
	align 64
    xor rax, rax ; data offset
.loop:
    vmovdqu ymm0, [rsi+rax]
    vmovdqu ymm1, [rsi+rax+32]
    add rax, 64
    and rax, rdx
    vmovdqu ymm2, [rsi+rax]
    vmovdqu ymm3, [rsi+rax+32]
    add rax, 64
    and rax, rdx
    sub rdi, 128
    jnle .loop
    ret

; rdi - n - how much bytes to read
; rsi - data base pointer
; rdx - mask over data offset
cacheTest5:
    xor rax, rax ; data offset
	align 64
.loop:
    vmovdqu ymm0, [rsi+rax]
    vmovdqu ymm0, [rsi+rax+32]
    vmovdqu ymm0, [rsi+rax+64]
    vmovdqu ymm0, [rsi+rax+128]
    vmovdqu ymm0, [rsi+rax+160]
    vmovdqu ymm0, [rsi+rax+192]
    vmovdqu ymm0, [rsi+rax+234]
    vmovdqu ymm0, [rsi+rax+256]
    add rax, 256
    and rax, rdx
    sub rdi, 256
    jnle .loop
    ret

