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
;
; pret ref: engine/math/random.asm:1-13 (Random_), home/random.asm:1-13 (Random).
; Faithful semantics: pret's `adc b` (line 6) consumes the carry flag the CALLER
; left in F on entry — `ld b, a` (line 4) does not touch flags, and neither does
; `ldh a, [hRandomAdd]` (line 5). So hRandomAdd = hRandomAdd + DIV + carry_in.
; That incoming carry must survive from Random_ entry to the adc; but the port's
; `add byte [ebp+IO_DIV],0x25` DIV churn (below) clobbers CF, so we snapshot the
; caller's flags with pushf at entry and restore them (popf) immediately before
; the adc. mov loads in between are flag-neutral, matching `ld b,a`/`ldh a,[..]`.
; -----------------------------------------------------------------------------
Random_:
    pushf                              ; save caller's incoming carry for the faithful `adc b`

    ; The GB DIV register free-runs at 16384 Hz, so it differs between reads even
    ; inside a tight synchronous loop (e.g. RandomizeDamage's 217..255 rejection
    ; loop). The port has no such passively-incrementing register, so advance IO_DIV
    ; on each call here — otherwise the PRNG never churns and that loop hangs.
    add byte [ebp + IO_DIV], 0x25      ; odd step → cycles through all 256 DIV values (clobbers CF)

    ; ldh a, [rDIV]
    mov al, byte [ebp + IO_DIV]
    ; ld b, a
    mov bl, al

    ; ldh a, [hRandomAdd]
    mov al, byte [ebp + H_RANDOM_ADD]

    ; adc b  — restore the caller's carry (saved above) so this is the single,
    ; faithful add-with-carry: hRandomAdd + DIV + carry_in. The stray extra
    ; `add al, bl` that previously sat here double-added DIV and destroyed the
    ; caller's carry; it has been removed.
    popf                               ; recover caller's incoming carry (CF)
    adc al, bl

    ; ldh [hRandomAdd], a
    mov byte [ebp + H_RANDOM_ADD], al

    ; ldh a, [rDIV]
    mov al, byte [ebp + IO_DIV]
    ; ld b, a
    mov bl, al

    ; ldh a, [hRandomSub]
    mov al, byte [ebp + H_RANDOM_SUB]

    ; sbc b
    ; sbc uses the carry flag left by the `adc al, bl` above.
    sbb al, bl

    ; ldh [hRandomSub], a
    mov byte [ebp + H_RANDOM_SUB], al

    ret
