; nasm -f elf64 test-asm.asm
; objdump -x -D test-asm.o

global add

section .text

add:
    mov rax, rdi
    add rax, rsi
    ret

