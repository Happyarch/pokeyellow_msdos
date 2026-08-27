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
; TrainerNamePointers : tools/generators/gen_trainer_names.py
;     (from data/trainers/name_pointers.asm; 47 flat dd rows, fixed strings +
;      0xFFFFFFFF marker for wTrainerName — see DEVIATION in save_trainer_name.asm).
;
; TrainerClassMoveChoiceModifications used to ride this file; it moved to its own
; mirrored carrier src/data/trainers/move_choices.asm on 2026-08-16
; (docs/current_plan_data_path_mirror.md).
;
; The included .inc files declare their own `global`s, so this wrapper declares
; none itself.
;
; Build: nasm -f coff -I include/ -I . -o trainer_data.o trainer_data.asm

bits 32

section .data
align 4

%include "assets/trainer_parties.inc"
%include "assets/trainer_names.inc"
%include "assets/trainer_name_pointers.inc"
