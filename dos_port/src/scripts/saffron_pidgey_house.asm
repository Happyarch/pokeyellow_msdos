; SaffronPidgeyHouse.asm — translated from pret scripts/SaffronPidgeyHouse.asm by dos_port/tools/sm83xlat.
;
; ONE-SHOT OUTPUT, NOW HAND-MAINTAINED. The transpiler ran once at the SHA
; recorded in dos_port/tools/sm83xlat/README.md and is not re-run; this file is
; ordinary Tier-2 source and editing it is the normal way it changes. There is
; deliberately no DO NOT EDIT header.
;
; Every pret label is preserved verbatim so the file stays line-for-line
; cross-referenceable against the disassembly.
;
; Regions the tool could not lower WITH CERTAINTY are reproduced below as
; commented pret source under a `; BAIL[reason]` banner, and define NO symbol —
; so a reference to one is a link error rather than a plausible wrong lowering.

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_text.inc"
%include "events.inc"
%include "assets/event_constants.inc"


global SaffronPidgeyHouseBrunetteGirlText
global SaffronPidgeyHousePaperText
global SaffronPidgeyHousePidgeyText
global SaffronPidgeyHouseYoungsterText
global SaffronPidgeyHouse_Script
global SaffronPidgeyHouse_TextPointers

extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern PlayCry   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern _SaffronPidgeyHouseBrunetteGirlText   ; NOT YET DEFINED IN THE PORT
extern _SaffronPidgeyHousePaperText   ; NOT YET DEFINED IN THE PORT
extern _SaffronPidgeyHousePidgeyText   ; NOT YET DEFINED IN THE PORT
extern _SaffronPidgeyHouseYoungsterText   ; NOT YET DEFINED IN THE PORT

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

SaffronPidgeyHouse_Script:
    jmp EnableAutoTextBoxDrawing

SaffronPidgeyHouse_TextPointers:
    dd SaffronPidgeyHouseBrunetteGirlText
    dd SaffronPidgeyHousePidgeyText
    dd SaffronPidgeyHouseYoungsterText
    dd SaffronPidgeyHousePaperText
SaffronPidgeyHouseBrunetteGirlText:
    text_far _SaffronPidgeyHouseBrunetteGirlText
    text_end
SaffronPidgeyHousePidgeyText:
    text_far _SaffronPidgeyHousePidgeyText

    mov al, 36
    call PlayCry
    jmp TextScriptEnd

SaffronPidgeyHouseYoungsterText:
    text_far _SaffronPidgeyHouseYoungsterText
    text_end
SaffronPidgeyHousePaperText:
    text_far _SaffronPidgeyHousePaperText
    text_end
