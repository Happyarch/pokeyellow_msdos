; UndergroundPathRoute5.asm — translated from pret scripts/UndergroundPathRoute5.asm by dos_port/tools/sm83xlat.
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

%include "assets/map_dims.inc"

global UndergroundPathEntranceRoute5_TextScriptEndingText
global UndergroundPathRoute5LittleGirlText
global UndergroundPathRoute5_Script
global UndergroundPathRoute5_TextPointers

extern DoInGameTradeDialogue   ; NOT YET DEFINED IN THE PORT

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
UndergroundPathRoute5_Script:
    mov al, ROUTE_5
    mov [ebp + wLastMap], al
    ret

%assign event_byte -1
%assign event_byte_a -1
UndergroundPathEntranceRoute5_TextScriptEndingText:
    text_end
UndergroundPathRoute5_TextPointers:
    dd UndergroundPathRoute5LittleGirlText

%assign event_byte -1
%assign event_byte_a -1
UndergroundPathRoute5LittleGirlText:
    mov al, 9
    mov [ebp + wWhichTrade], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call DoInGameTradeDialogue
    mov esi, UndergroundPathEntranceRoute5_TextScriptEndingText
    ret
