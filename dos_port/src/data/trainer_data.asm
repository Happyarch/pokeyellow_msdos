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
; The included .inc files declare their own `global`s, so this wrapper does not.
;
; Build: nasm -f coff -I include/ -I . -o trainer_data.o trainer_data.asm

bits 32

section .data
align 4

%include "assets/trainer_parties.inc"
%include "assets/trainer_names.inc"
