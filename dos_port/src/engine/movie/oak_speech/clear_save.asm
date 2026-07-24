; clear_save.asm — the title screen's CLEAR ALL SAVE DATA dialog.
;
; Source: engine/movie/oak_speech/clear_save.asm (pret/pokeyellow). Reached from
; DisplayTitleScreen's UP+SELECT+B reset-save combo (engine/movie/title.asm
; .doClearSaveDialogue — pret farjp, so there is no return address).
;
; Build: nasm -f coff -I include/ -o clear_save.o clear_save.asm

bits 32

extern Init                          ; home/init.asm

section .text

; ---------------------------------------------------------------------------
; DoClearSaveDialogue — pret shows the "CLEAR ALL SAVE DATA?" yes/no dialog and
; erases SRAM on confirm, then resets.
;
; DEVIATION{class=temporary; pret=engine/movie/oak_speech/clear_save.asm:DoClearSaveDialogue; behavior=jump straight to Init (a plain reset) instead of showing the clear-save yes/no dialog and erasing SRAM; evidence=save/SRAM is Phase 5 and there is no save file to clear yet, so the dialog would erase nothing, the reset tail is pret's terminal behavior either way; lifetime=until Phase 5 ports the SRAM clear and the dialog body}
; ---------------------------------------------------------------------------
global DoClearSaveDialogue
DoClearSaveDialogue:
    jmp Init
