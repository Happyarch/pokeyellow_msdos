; indigo_plateau_statues.asm — Indigo Plateau statues hidden-event handler.
;
; Faithful translation of pret `engine/events/hidden_events/indigo_plateau_statues.asm`.
; IndigoPlateauStatues splits on wXCoord parity to show IndigoPlateauStatuesText2
; (odd X) or IndigoPlateauStatuesText3 (even X) after IndigoPlateauStatuesText1.
;
; Register map: A=AL, HL=ESI; GB memory at [EBP + addr].
;
; TEXT STRINGS ARE DATA:
; IndigoPlateauStatuesText1..3 are generated into assets/indigo_plateau_statues_text.inc
; via tools/generators/gen_indigo_plateau_statues_text.py (text_far flattened).
;
; Build: nasm -f coff -I include/ -I . -o indigo_plateau_statues.o \
;            src/engine/events/hidden_events/indigo_plateau_statues.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "assets/indigo_plateau_statues_text.inc"

global IndigoPlateauStatues

extern PrintText                        ; src/home/window.asm
extern TextScriptEnd                    ; src/home/overworld_text.asm

section .text

; ─────────────────────────────────────────────────────────────────────────────
; IndigoPlateauStatues — pret engine/events/hidden_events/indigo_plateau_statues.asm:IndigoPlateauStatues
; ─────────────────────────────────────────────────────────────────────────────
IndigoPlateauStatues:
    ; NO `text_asm` command byte here: TextPredefs row $3C is predef_code (src/data/text_predef_pointers.asm)
    ; and DisplayTextID calls this label directly as x86 code.
    mov esi, IndigoPlateauStatuesText1
    call PrintText
    mov al, [ebp + wXCoord]
    test al, 1                          ; bit 0, a ; even or odd?
    mov esi, IndigoPlateauStatuesText2
    jnz .ok
    mov esi, IndigoPlateauStatuesText3
.ok:
    call PrintText
    jmp TextScriptEnd
