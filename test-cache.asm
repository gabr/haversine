global cacheTest

section .text

; rdi - n - how much bytes to read
; rsi - data base pointer
; rdx - mask over data offset
cacheTest:
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

