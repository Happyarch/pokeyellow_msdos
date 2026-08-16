; ViridianSchoolHouse.asm — translated from pret scripts/ViridianSchoolHouse.asm, scripts/ViridianSchoolHouse_2.asm by dos_port/tools/sm83xlat.
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


global ViridianSchoolHouseBrunetteGirlText
global ViridianSchoolHouseCooltrainerFText
global ViridianSchoolHouseLittleGirlText
global ViridianSchoolHousePrintCooltrainerFText
global ViridianSchoolHousePrintLittleGirlText
global ViridianSchoolHouse_Script
global ViridianSchoolHouse_TextPointers

extern Bankswitch   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern _ViridianSchoolHouseBrunetteGirlText   ; NOT YET DEFINED IN THE PORT
extern _ViridianSchoolHouseCooltrainerFText   ; NOT YET DEFINED IN THE PORT
extern _ViridianSchoolHouseLittleGirlText   ; NOT YET DEFINED IN THE PORT

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

ViridianSchoolHouse_Script:
    call EnableAutoTextBoxDrawing
    ret

ViridianSchoolHouse_TextPointers:
    dd ViridianSchoolHouseBrunetteGirlText
    dd ViridianSchoolHouseCooltrainerFText
    dd ViridianSchoolHouseLittleGirlText
ViridianSchoolHouseBrunetteGirlText:
    text_far _ViridianSchoolHouseBrunetteGirlText
    text_end

ViridianSchoolHouseCooltrainerFText:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call ViridianSchoolHousePrintCooltrainerFText
    jmp TextScriptEnd

ViridianSchoolHouseLittleGirlText:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call ViridianSchoolHousePrintLittleGirlText
    jmp TextScriptEnd

ViridianSchoolHousePrintLittleGirlText:
    mov esi, .text
    call PrintText
    ret

.text:
    text_far _ViridianSchoolHouseLittleGirlText
    text_end

ViridianSchoolHousePrintCooltrainerFText:
    mov esi, .text
    call PrintText
    ret

.text:
    text_far _ViridianSchoolHouseCooltrainerFText
    text_end
