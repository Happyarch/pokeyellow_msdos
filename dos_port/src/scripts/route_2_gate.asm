; Route2Gate.asm — translated from pret scripts/Route2Gate.asm by dos_port/tools/sm83xlat.
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


global Route2GateOaksAideText
global Route2GateYoungsterText
global Route2Gate_Script
global Route2Gate_TextPointers

extern CopyData   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern GetItemName   ; NOT YET DEFINED IN THE PORT
extern OaksAideScript   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern _Route2GateOaksAideFlashExplanationText   ; NOT YET DEFINED IN THE PORT
extern _Route2GateYoungsterText   ; NOT YET DEFINED IN THE PORT

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
hOaksAideRequirement                           equ 0xFFDB
hOaksAideResult                                equ 0xFFDB
hOaksAideRewardItem                            equ 0xFFDC
wOaksAideRewardItemName                        equ 0xCC5B

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
Route2Gate_Script:
    jmp EnableAutoTextBoxDrawing

%assign event_byte -1
Route2Gate_TextPointers:
    dd Route2GateOaksAideText
    dd Route2GateYoungsterText

%assign event_byte -1
Route2GateOaksAideText:
    CheckEvent EVENT_GOT_HM05
    jnz .got_item
    mov al, 10
    mov [ebp + hOaksAideRequirement], al
    mov al, 201
    mov [ebp + hOaksAideRewardItem], al
    mov [ebp + wNamedObjectIndex], al
    call GetItemName
    mov esi, wNameBuffer
    mov dx, wOaksAideRewardItemName
    mov bx, 13
    call CopyData
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call OaksAideScript
    mov al, [ebp + hOaksAideResult]
    cmp al, 1
    jnz .no_item
    SetEvent EVENT_GOT_HM05
.got_item:
    mov esi, .FlashExplanationText
    call PrintText
.no_item:
    jmp TextScriptEnd

%assign event_byte -1
.FlashExplanationText:
    text_far _Route2GateOaksAideFlashExplanationText
    text_end
Route2GateYoungsterText:
    text_far _Route2GateYoungsterText
    text_end
