; trainer_data.asm — generated trainer roster + class-name tables (battle engine).
;
; Holds generated read-only trainer data so the engine routines can `extern` them.
; Per the linker rule in docs/assembly.md, embedded data lives in .data (not .rodata,
; which has no output-section rule and reads back as zero).
;
; TrainerDataPointers / SpecialTrainerMoves : tools/generators/gen_trainer_parties.py
;     (from data/trainers/parties.asm + special_moves.asm; consumed by
;      src/engine/battle/read_trainer_party.asm).
; TrainerNames : tools/generators/gen_trainer_names.py
;     (from data/trainers/names.asm; '@'-terminated, walked by GetName — see
;      src/home/names.asm / src/engine/battle/get_trainer_name.asm).
;
; TrainerClassMoveChoiceModifications is NOT generated — it is the one table in
; this file still hand-written, moved here 2026-08-02 from
; src/engine/battle/trainer_ai.asm to clear its [aux_misplaced] finding (a pret
; data/trainers/ label must live in the data layer). pret builds it with the
; variadic `move_choices` macro, so promoting it to a generator means expanding
; that macro rather than copying rows — tracked as a follow-up, not done here.
;
; The included .inc files declare their own `global`s, so this wrapper declares
; only the one symbol it defines directly.
;
; Build: nasm -f coff -I include/ -I . -o trainer_data.o trainer_data.asm

bits 32

global TrainerClassMoveChoiceModifications

section .data
align 4

%include "assets/trainer_parties.inc"
%include "assets/trainer_names.inc"

; ===========================================================================
; TrainerClassMoveChoiceModifications — flat data table
; ---------------------------------------------------------------------------
; Null-terminated modifier-id sequences, one per trainer class (order 1..47).
; AIEnemyTrainerChooseMoves skips (class-1) entries then reads the current one.
; Pret ref: data/trainers/move_choices.asm via `move_choices` macro.
; ===========================================================================
TrainerClassMoveChoiceModifications:
    db 0             ; YOUNGSTER      ($01)
    db 1, 0          ; BUG_CATCHER    ($02)
    db 1, 0          ; LASS           ($03)
    db 1, 3, 0       ; SAILOR         ($04)
    db 1, 0          ; JR_TRAINER_M   ($05)
    db 1, 0          ; JR_TRAINER_F   ($06)
    db 1, 2, 3, 0    ; POKEMANIAC     ($07)
    db 1, 2, 0       ; SUPER_NERD     ($08)
    db 1, 0          ; HIKER          ($09)
    db 1, 0          ; BIKER          ($0A)
    db 1, 3, 0       ; BURGLAR        ($0B)
    db 1, 0          ; ENGINEER       ($0C)
    db 1, 2, 0       ; UNUSED_JUGGLER ($0D)
    db 1, 3, 0       ; FISHER         ($0E)
    db 1, 3, 0       ; SWIMMER        ($0F)
    db 0             ; CUE_BALL       ($10)
    db 1, 0          ; GAMBLER        ($11)
    db 1, 3, 0       ; BEAUTY         ($12)
    db 1, 2, 0       ; PSYCHIC_TR     ($13)
    db 1, 0          ; ROCKER         ($14)
    db 1, 0          ; JUGGLER        ($15)
    db 1, 0          ; TAMER          ($16)
    db 1, 0          ; BIRD_KEEPER    ($17)
    db 1, 0          ; BLACKBELT      ($18)
    db 1, 0          ; RIVAL1         ($19)
    db 1, 3, 0       ; PROF_OAK       ($1A)
    db 1, 2, 0       ; CHIEF          ($1B)
    db 1, 2, 0       ; SCIENTIST      ($1C)
    db 1, 3, 0       ; GIOVANNI       ($1D)
    db 1, 0          ; ROCKET         ($1E)
    db 1, 3, 0       ; COOLTRAINER_M  ($1F)
    db 1, 3, 0       ; COOLTRAINER_F  ($20)
    db 1, 0          ; BRUNO          ($21)
    db 1, 0          ; BROCK          ($22)
    db 1, 3, 0       ; MISTY          ($23)
    db 1, 0          ; LT_SURGE       ($24)
    db 1, 3, 0       ; ERIKA          ($25)
    db 1, 3, 0       ; KOGA           ($26)
    db 1, 0          ; BLAINE         ($27)
    db 1, 0          ; SABRINA        ($28)
    db 1, 2, 0       ; GENTLEMAN      ($29)
    db 1, 3, 0       ; RIVAL2         ($2A)
    db 1, 3, 0       ; RIVAL3         ($2B)
    db 1, 2, 3, 0    ; LORELEI        ($2C)
    db 1, 0          ; CHANNELER      ($2D)
    db 1, 0          ; AGATHA         ($2E)
    db 1, 3, 0       ; LANCE          ($2F)
