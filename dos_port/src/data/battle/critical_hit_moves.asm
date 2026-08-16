; critical_hit_moves.asm — moves with an 8x crit ratio. Scanned by CriticalHitTest; $FF-terminated.
;
; pret ref: data/battle/critical_hit_moves.asm:HighCriticalMoves
;
; Hand-written rows translated from pret (small fixed table, not worth a
; generator). This carrier sits at the mirrored path dos_port/src/data/battle/critical_hit_moves.asm; it was
; part of src/data/battle_data.asm until 2026-08-16
; (docs/current_plan_data_path_mirror.md).
;
; Embedded data goes in .data per the linker rule in docs/assembly.md.
bits 32

global HighCriticalMoves

section .data

HighCriticalMoves:
    db 0x02     ; KARATE_CHOP
    db 0x4B     ; RAZOR_LEAF
    db 0x98     ; CRABHAMMER
    db 0xA3     ; SLASH
    db 0xFF     ; end

