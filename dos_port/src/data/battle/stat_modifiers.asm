; stat_modifiers.asm — numerator/denominator pairs indexed by stat stage 1..13. Used by
; CalcHitChance and the stat-stage recompute. 13 entries x 2 bytes.
;
; pret ref: data/battle/stat_modifiers.asm:StatModifierRatios
;
; Hand-written rows translated from pret (small fixed table, not worth a
; generator). This carrier sits at the mirrored path dos_port/src/data/battle/stat_modifiers.asm; it was
; part of src/data/battle_data.asm until 2026-08-16
; (docs/current_plan_data_path_mirror.md).
;
; Embedded data goes in .data per the linker rule in docs/assembly.md.
bits 32

global StatModifierRatios

section .data

StatModifierRatios:
    db 25, 100  ; 0.25
    db 28, 100  ; 0.28
    db 33, 100  ; 0.33
    db 40, 100  ; 0.40
    db 50, 100  ; 0.50
    db 66, 100  ; 0.66
    db  1,   1  ; 1.00
    db 15,  10  ; 1.50
    db  2,   1  ; 2.00
    db 25,  10  ; 2.50
    db  3,   1  ; 3.00
    db 35,  10  ; 3.50
    db  4,   1  ; 4.00

