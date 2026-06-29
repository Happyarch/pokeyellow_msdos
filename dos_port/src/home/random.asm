; dos_port/home/random.asm
%include "gb_memmap.inc"        ; hRandomAdd (HRAM equ); was wrongly extern'd while check-only

global Random

extern Random_

bits 32
section .text

; Return a random number in AL.
Random:
    push esi
    push dx
    push bx
    
    call Random_
    
    mov al, [ebp + hRandomAdd]
    
    pop bx
    pop dx
    pop esi
    ret
