; save_trainer_name.asm — SaveTrainerName.
;
; Source (faithful translation): engine/battle/save_trainer_name.asm.
;
; Copies the engaged trainer class's display name into wNameBuffer, which
; _TrainerNameText (a TX_RAM wNameBuffer stream, generated into
; assets/trainer_text.inc) then prints as the "<TRAINER>: " prefix of the
; end-battle text. Sole caller: PrintEndBattleText (src/home/trainers.asm).
;
; RETIRED THE STUB 2026-08-11 (battle plan 1d). The ret-only stand-in in
; battle_stubs.asm carried the justification "The real body needs the Tier-1
; TrainerNamePointers name table (pret data/trainers/name_pointers.asm), not yet
; generated." That was FALSE at the time it was read: the names ARE generated —
; assets/trainer_names.inc holds all 47 in trainer-class order, emitted by
; tools/generators/gen_trainer_names.py, and src/home/names2.asm already binds
; that blob as name list 7 (TRAINER_NAME).
;
; DEVIATION{class=data-model; pret=engine/battle/save_trainer_name.asm:SaveTrainerName; behavior=selects the trainer name through GetName with wNameListType TRAINER_NAME instead of indexing a TrainerNamePointers pointer table inline and copying the string by hand; evidence=the port generates TrainerNames as one flat blob of variable-length terminated strings rather than pret's pointer table so there is no table to index, and src/home/names2.asm already registers that blob as list 7 and performs the same walk for GetTrainerName_ - duplicating the walk here would fork the one place that knows the layout; lifetime=permanent while TrainerNames is generated as a flat blob}
;
; Register map (CLAUDE.md): A=AL, HL=ESI, EBP=GB base, [ebp+addr].
;
; Build: nasm -f coff -I include/ -I . -o save_trainer_name.o save_trainer_name.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

extern GetName                      ; src/home/names2.asm — name list -> wNameBuffer

global SaveTrainerName

section .text

SaveTrainerName:
    ; pret: ld hl, TrainerNamePointers / ld a,[wTrainerClass] / dec a / index the
    ; table / copy the '@'-terminated string to wNameBuffer.
    ;
    ; wTrainerClass goes in UNDECREMENTED. pret does `dec a` because it indexes a
    ; 0-based pointer table; the port's GetName instead WALKS the flat blob
    ; counting '@' terminators and its loop is 1-BASED — src/home/names2.asm
    ; comments the register outright: `bl = wanted entry (1-based)`, and it stops
    ; when the terminator count equals bl. GetTrainerName_ passes wTrainerClass
    ; through the same way. Pre-decrementing here would name the previous class.
    mov al, [ebp + wTrainerClass]
    mov [ebp + wNameListIndex], al
    mov byte [ebp + wNameListType], TRAINER_NAME
    mov byte [ebp + wPredefBank], 0     ; BANK(TrainerNames) — flat model, ignored
    jmp GetName                         ; tail: leaves the name in wNameBuffer
