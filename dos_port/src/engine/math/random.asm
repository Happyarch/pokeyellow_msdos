; dos_port/src/util/random.asm

%include "gb_macros.inc"
%include "gb_memmap.inc"

section .text

global Random_

; -----------------------------------------------------------------------------
; Random_
;
; Generates a pseudo-random number based on the DIV register and previous
; pseudo-random state. Stores the results in H_RANDOM_ADD and H_RANDOM_SUB.
; Note: In the DOS port, reading IO_DIV may currently return 0 or need to be
; updated by the main loop to simulate the Game Boy divider.
; -----------------------------------------------------------------------------
Random_:
    ; The GB DIV register free-runs at 16384 Hz, so it differs between reads even
    ; inside a tight synchronous loop (e.g. RandomizeDamage's 217..255 rejection
    ; loop). The port has no such passively-incrementing register, so advance IO_DIV
    ; on each call here — otherwise the PRNG never churns and that loop hangs.
    add byte [ebp + IO_DIV], 0x25      ; odd step → cycles through all 256 DIV values

    ; ldh a, [rDIV]
    mov al, byte [ebp + IO_DIV]
    mov bl, al

    ; ldh a, [hRandomAdd]
    mov al, byte [ebp + H_RANDOM_ADD]

    ; adc b
    add al, bl ; adc requires carry flag handling if needed, but the original logic just did adc from whatever carry was left?
    ; Wait, the original Game Boy code just does `adc b` right after `ld b, a`.
    ; `ld b, a` doesn't affect flags. So it uses the carry flag left over from whoever called Random_!
    ; To preserve this exact behavior, we must use adc.
    adc al, bl
    
    ; ldh [hRandomAdd], a
    mov byte [ebp + H_RANDOM_ADD], al
    
    ; ldh a, [rDIV]
    mov al, byte [ebp + IO_DIV]
    mov bl, al
    
    ; ldh a, [hRandomSub]
    mov al, byte [ebp + H_RANDOM_SUB]
    
    ; sbc b
    ; sbc uses the carry flag from the `adc al, bl` above!
    sbb al, bl
    
    ; ldh [hRandomSub], a
    mov byte [ebp + H_RANDOM_SUB], al
    
    ret
