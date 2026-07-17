; battle_data.asm — Pokémon battle static data tables (battle engine plan).
;
; Holds generated read-only battle data so the engine routines can `extern`
; them. Per the linker rule in docs/assembly.md, embedded data lives in .data
; (not .rodata, which has no output-section rule and reads back as zero).
;
; TypeEffects : tools/generators/gen_type_matchups.py (from data/types/type_matchups.asm).
; MoveNames   : tools/generators/gen_move_names.py   (from data/moves/names.asm; '@'-terminated,
;               walked by GetName — see src/home/names.asm).
;
; Build: nasm -f coff -I include/ -I . -o battle_data.o battle_data.asm

bits 32

global TypeEffects
global HighCriticalMoves
global StatModifierRatios
global MoveNames
global ResidualEffects1
global ResidualEffects2
global SpecialEffects
global SpecialEffectsCont
global AlwaysHappenSideEffects
global SetDamageEffects

section .data
align 4

%include "assets/type_matchups.inc"
%include "assets/move_names.inc"

; Move-effect category lists (data/battle/*.asm; $FF-terminated). Scanned linearly
; by the battle engine to classify a move's effect (residual / special / always-
; happens-on-faint / sets-damage). DATA ONLY — no MoveEffectPointerTable, whose
; handler pointers would dangle until the effect handlers are ported.
%include "assets/effect_categories.inc"

; HighCriticalMoves — moves with a 8× crit ratio (data/battle/critical_hit_moves.asm).
; Scanned by CriticalHitTest; $FF-terminated. Small fixed table, embedded directly
; (translated from pret) rather than generated.
HighCriticalMoves:
    db 0x02     ; KARATE_CHOP
    db 0x4B     ; RAZOR_LEAF
    db 0x98     ; CRABHAMMER
    db 0xA3     ; SLASH
    db 0xFF     ; end

; StatModifierRatios — numerator/denominator pairs indexed by stat stage 1..13
; (data/battle/stat_modifiers.asm). Used by CalcHitChance and the stat-stage
; recompute. 13 entries × 2 bytes.
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
