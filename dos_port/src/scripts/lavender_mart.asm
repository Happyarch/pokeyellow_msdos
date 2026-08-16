; LavenderMart.asm — translated from pret scripts/LavenderMart.asm by dos_port/tools/sm83xlat.
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


global LavenderMartBaldingGuyText
global LavenderMartCooltrainerMText
global LavenderMart_Script
global LavenderMart_TextPointers

extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern LavenderMartClerkText   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern _LavenderMartBaldingGuyText   ; NOT YET DEFINED IN THE PORT
extern _LavenderMartCooltrainerMNuggetText   ; NOT YET DEFINED IN THE PORT
extern _LavenderMartCooltrainerMReviveText   ; NOT YET DEFINED IN THE PORT

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

LavenderMart_Script:
    jmp EnableAutoTextBoxDrawing

LavenderMart_TextPointers:
    dd LavenderMartClerkText
    dd LavenderMartBaldingGuyText
    dd LavenderMartCooltrainerMText
LavenderMartBaldingGuyText:
    text_far _LavenderMartBaldingGuyText
    text_end

LavenderMartCooltrainerMText:
    CheckEvent EVENT_RESCUED_MR_FUJI
    jnz .Nugget
    mov esi, .ReviveText
    call PrintText
    jmp .done

.Nugget:
    mov esi, .NuggetText
    call PrintText
.done:
    jmp TextScriptEnd

.ReviveText:
    text_far _LavenderMartCooltrainerMReviveText
    text_end
.NuggetText:
    text_far _LavenderMartCooltrainerMNuggetText
    text_end
