global read_4x2
global read_8x2
global read_16x2
global read_32x2
global read_64x2

section .text

read_4x2:
	align 64
.loop:
    mov r8d, [rsi]
    mov r8d, [rsi+4]
    sub rdi, 8
    jnle .loop
    ret

read_8x2:
	align 64
.loop:
    mov r8, [rsi]
    mov r8, [rsi+8]
    sub rdi, 16
    jnle .loop
    ret

read_16x2:
	align 64
.loop:
    vmovdqu xmm0, [rsi]
    vmovdqu xmm0, [rsi+16]
    sub rdi, 32
    jnle .loop
    ret

read_32x2:
	align 64
.loop:
    vmovdqu ymm0, [rsi]
    vmovdqu ymm0, [rsi+32]
    sub rdi, 64
    jnle .loop
    ret

read_64x2:
	align 64
.loop:
    vmovdqu64 zmm0{k1}, [rsi]
    vmovdqu64 zmm0{k1}, [rsi+64]
    ;vmovaps zmm0, [rsi]
    ;vmovaps zmm0, [rsi+64]
    sub rdi, 128
    jnle .loop
    ret

