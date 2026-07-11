; dos_port/src/pokemon/experience.asm

%include "gb_macros.inc"
%include "gb_memmap.inc"

section .text

global CalcLevelFromExperience
global CalcExperience
global CalcDSquared

extern GetMonHeader
extern Multiply
extern Divide
extern GrowthRateTable

; -----------------------------------------------------------------------------
; CalcLevelFromExperience
;
; Calculates the level a mon should be based on its current exp.
; -----------------------------------------------------------------------------
CalcLevelFromExperience:
    ; wLoadedMonSpecies -> wCurSpecies
    mov al, byte [ebp + wLoadedMonSpecies]
    mov byte [ebp + wCurSpecies], al
    call GetMonHeader
    
    mov dh, 1 ; dh = level (d in GB)

.loop:
    inc dh
    call CalcExperience
    
    ; compare exp needed for level (hExperience) with current exp (wLoadedMonExp)
    ; hExperience is 3 bytes big-endian.
    ; wLoadedMonExp is 3 bytes big-endian.
    ; We can do a 24-bit compare.
    ; Wait, we can just load them into 32-bit registers!
    movzx eax, byte [ebp + hExperience + 0]
    shl eax, 8
    mov al, byte [ebp + hExperience + 1]
    shl eax, 8
    mov al, byte [ebp + hExperience + 2]
    
    movzx ecx, byte [ebp + wLoadedMonExp + 0]
    shl ecx, 8
    mov cl, byte [ebp + wLoadedMonExp + 1]
    shl ecx, 8
    mov cl, byte [ebp + wLoadedMonExp + 2]
    
    cmp ecx, eax
    jnc .loop ; if current exp >= needed exp, try next level

    dec dh ; go back to previous level
    ret

; -----------------------------------------------------------------------------
; CalcExperience
;
; Calculates the amount of experience needed for level in DH.
; -----------------------------------------------------------------------------
; Faithful rewrite (2026-06-25). The previous swarm-translated body misread the
; SM83 `hli` (read [hl], THEN increment) as "increment, THEN read" throughout, so
; the numerator/denominator, the squared-term sign byte, and the linear/const
; coefficients were all taken from the wrong GrowthRateTable bytes (e.g. Medium
; Fast divided by 0). Each `ld a,[hli]` below is `mov al,[esi]` then `inc esi`.
; GrowthRateTable entry: byte0=(num<<4)|den ; byte1=±n^2 coef ; byte2=n ; byte3=const.
CalcExperience:
    mov al, byte [ebp + wMonHGrowthRate]
    shl al, 2                          ; index = growthRate * 4
    movzx ecx, al
    lea esi, [GrowthRateTable]
    add esi, ecx                       ; esi -> entry byte0

    ; --- cubed term: (num/den) * n^3 ---
    call CalcDSquared                  ; product = n^2 (low 3 bytes -> next multiplicand)
    mov al, dh
    mov byte [ebp + hMultiplier], al
    call Multiply                      ; product = n^3
    mov al, byte [esi]           ; byte0
    and al, 0xF0
    shr al, 4                          ; numerator (high nibble)
    mov byte [ebp + hMultiplier], al
    call Multiply                      ; n^3 * num
    mov al, byte [esi]           ; byte0 again (ld a,[hli])
    inc esi                            ;   then advance to byte1
    and al, 0x0F                       ; denominator (low nibble of byte0)
    mov byte [ebp + hDivisor], al
    mov bh, 4
    call Divide                        ; (n^3 * num) / den
    
    ; push hQuotient 1, 2, 3
    mov al, byte [ebp + hQuotient + 1]
    push ax
    mov al, byte [ebp + hQuotient + 2]
    push ax
    mov al, byte [ebp + hQuotient + 3]
    push ax
    
    call CalcDSquared
    
    mov al, byte [esi]
    and al, 0x7F
    mov byte [ebp + hMultiplier], al
    call Multiply
    
    ; push hProduct 1, 2, 3
    mov al, byte [ebp + hProduct + 1]
    push ax
    mov al, byte [ebp + hProduct + 2]
    push ax
    mov al, byte [ebp + hProduct + 3]
    push ax
    
    mov al, byte [esi]           ; byte1 again (ld a,[hli]) — n^2 sign byte
    inc esi                            ;   then advance to byte2
    push ax

    mov byte [ebp + hMultiplicand], 0
    mov byte [ebp + hMultiplicand + 1], 0
    mov al, dh
    mov byte [ebp + hMultiplicand + 2], al

    mov al, byte [esi]           ; byte2 (linear coef, ld a,[hli])
    inc esi                            ;   then advance to byte3
    mov byte [ebp + hMultiplier], al
    call Multiply

    ; GLITCH: "Experience Underflow -> Lv 100" — for a level-1 Medium-Slow mon
    ; the linear/const-term subtraction below can underflow this 24-bit
    ; hProduct/hExperience accumulator, producing a huge wrapped "EXP needed
    ; for level 2" threshold; CalcLevelFromExperience's compare loop above then
    ; concludes the mon has already passed every level and reports Lv 100.
    ; Functional speedrun exploit (no ACE). Same root cause underlies the
    ; Save/SRAM-category "Experience PC Withdrawing Softlock" BUG(critical) —
    ; a level-1 Medium-Slow mon withdrawn from the PC re-runs this same
    ; underflowing calc in a context that softlocks instead of just mis-leveling
    ; (that call site is not yet ported — see docs/bug_categorization.md).
    ; Gen-1 behavior, preserved verbatim. pret ref: engine/pokemon/experience.asm:
    ; CalcExperience, docs/references/yellow_glitches.md#battle-system
    ; (Experience Underflow -> Lv 100) and #save--sram (Experience PC
    ; Withdrawing Softlock). Safety: safe under DPMI (bounded WRAM arithmetic,
    ; no ACE potential).
    mov bl, byte [esi]           ; byte3 (const)
    mov al, byte [ebp + hProduct + 3]
    sub al, bl
    mov byte [ebp + hProduct + 3], al
    
    mov bl, 0
    mov al, byte [ebp + hProduct + 2]
    sbb al, bl
    mov byte [ebp + hProduct + 2], al
    
    mov al, byte [ebp + hProduct + 1]
    sbb al, bl
    mov byte [ebp + hProduct + 1], al
    
    pop ax
    test al, 0x80
    jnz .subtractSquaredTerm
    
    pop bx ; b = product 3
    mov al, byte [ebp + hExperience + 2]
    add al, bl
    mov byte [ebp + hExperience + 2], al
    
    pop bx ; b = product 2
    mov al, byte [ebp + hExperience + 1]
    adc al, bl
    mov byte [ebp + hExperience + 1], al
    
    pop bx ; b = product 1
    mov al, byte [ebp + hExperience]
    adc al, bl
    mov byte [ebp + hExperience], al
    jmp .addCubedTerm

.subtractSquaredTerm:
    pop bx
    mov al, byte [ebp + hExperience + 2]
    sub al, bl
    mov byte [ebp + hExperience + 2], al
    
    pop bx
    mov al, byte [ebp + hExperience + 1]
    sbb al, bl
    mov byte [ebp + hExperience + 1], al
    
    pop bx
    mov al, byte [ebp + hExperience]
    sbb al, bl
    mov byte [ebp + hExperience], al

.addCubedTerm:
    pop bx
    mov al, byte [ebp + hExperience + 2]
    add al, bl
    mov byte [ebp + hExperience + 2], al
    
    pop bx
    mov al, byte [ebp + hExperience + 1]
    adc al, bl
    mov byte [ebp + hExperience + 1], al
    
    pop bx
    mov al, byte [ebp + hExperience]
    adc al, bl
    mov byte [ebp + hExperience], al
    ret

; -----------------------------------------------------------------------------
; CalcDSquared
;
; Calculates d*d (DH * DH).
; -----------------------------------------------------------------------------
CalcDSquared:
    mov byte [ebp + hMultiplicand], 0
    mov byte [ebp + hMultiplicand + 1], 0
    mov al, dh
    mov byte [ebp + hMultiplicand + 2], al
    mov byte [ebp + hMultiplier], al
    jmp Multiply
