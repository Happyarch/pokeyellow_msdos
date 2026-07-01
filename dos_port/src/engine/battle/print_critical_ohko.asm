; print_critical_ohko.asm — PrintCriticalOHKOText (move-effect translation swarm).
;
; Faithful translation of engine/battle/core.asm:3967 PrintCriticalOHKOText (pret/pokeyellow).
; Prints "Critical hit!" or "One-hit KO!" (or nothing) based on wCriticalHitOrOHKO,
; then clears the flag and falls through to a fixed 20-frame delay.
;
; Register map: A=AL, B=BH, C=BL (BC=BX), HL=ESI, EBP=GB base.
; GB memory at [EBP+addr]; battle_text streams are flat program addresses.
;
; STRUCTURAL PORT ADAPTATION (not a behavior divergence): pret indexes a `dw`
; (2-byte) pointer table with `(wCriticalHitOrOHKO-1)*2`. This port's text labels
; are 32-bit flat addresses, so CriticalOHKOTextPointers is a `dd` (4-byte) table
; and the index is `(wCriticalHitOrOHKO-1)*4`. The selection logic (which entry,
; under what condition) is unchanged.
;
; Build: nasm -f coff -I include/ -I . -o print_critical_ohko.o print_critical_ohko.asm

bits 32

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"

section .data

; STRUCTURAL PORT ADAPTATION: dw->dd flat pointer table (index *2 -> *4).
; pret: CriticalOHKOTextPointers: dw CriticalHitText, dw OHKOText (engine/battle/core.asm)
CriticalOHKOTextPointers:
    dd CriticalHitText
    dd OHKOText

section .text

global PrintCriticalOHKOText

; --- shared scaffold externs (§4: call, never define) ---
extern PrintText                    ; move_effect_helpers.asm — ESI = flat text stream
extern DelayFrames                  ; frame.asm — BL = frame count
; --- battle_text.inc streams (global, assets/battle_text.inc) ---
extern CriticalHitText
extern OHKOText

; ===========================================================================
; PrintCriticalOHKOText — pret engine/battle/core.asm:3967
;
;	ld a, [wCriticalHitOrOHKO]
;	and a
;	jr z, .done
;	dec a
;	add a                    ; *2 (port: *4)
;	ld hl, CriticalOHKOTextPointers
;	ld b, $0
;	ld c, a
;	add hl, bc
;	ld a, [hli]
;	ld h, [hl]
;	ld l, a
;	call PrintText
;	xor a
;	ld [wCriticalHitOrOHKO], a
;.done
;	ld c, 20
;	jp DelayFrames
; ===========================================================================
PrintCriticalOHKOText:
    mov al, [ebp + wCriticalHitOrOHKO]
    and al, al
    jz .done                            ; no crit / no OHKO -> nothing to print
    dec al                              ; a -= 1  (1=crit -> 0, 2=OHKO -> 1)
    movzx eax, al                       ; widen index byte, zero upper bits
    mov esi, [CriticalOHKOTextPointers + eax*4]   ; *4: dd flat-pointer table (was *2 dw in pret)
    call PrintText
    mov byte [ebp + wCriticalHitOrOHKO], 0
.done:
    mov bl, 20                          ; PORT: DelayFrames reads BL, not C
    jmp DelayFrames                     ; tail call (pret: jp DelayFrames)
