; UndergroundPathRoute7Copy.asm — translated from pret scripts/UndergroundPathRoute7Copy.asm by dos_port/tools/sm83xlat.
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

global UndergroundPathRoute7CopyUnusedGirlText
global UndergroundPathRoute7CopyUnusedGoesUnderSaffronText
global UndergroundPathRoute7CopyUnusedMiddleAgedManText
global UndergroundPathRoute7CopyUnusedTeamRocketHadAHideoutText
global UndergroundPathRoute7Copy_Script
global UndergroundPathRoute7Copy_TextPointers

extern _UndergroundPathRoute7CopyUnusedGirlText   ; NOT YET DEFINED IN THE PORT
extern _UndergroundPathRoute7CopyUnusedGoesUnderSaffronText   ; NOT YET DEFINED IN THE PORT
extern _UndergroundPathRoute7CopyUnusedMiddleAgedManText   ; NOT YET DEFINED IN THE PORT
extern _UndergroundPathRoute7CopyUnusedTeamRocketHadAHideoutText   ; NOT YET DEFINED IN THE PORT

; pret RAM names the port still spells in SCREAMING_SNAKE. Guarded, so
; this file assembles both before and after the memmap rename lands.
%ifndef wLastMap
wLastMap                                       equ W_LAST_MAP
%endif

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

UndergroundPathRoute7Copy_Script:
    mov al, ROUTE_7
    mov [ebp + wLastMap], al
    ret

UndergroundPathRoute7Copy_TextPointers:
    dd UndergroundPathRoute7CopyUnusedGirlText
    dd UndergroundPathRoute7CopyUnusedMiddleAgedManText
UndergroundPathRoute7CopyUnusedGirlText:
    text_far _UndergroundPathRoute7CopyUnusedGirlText
    text_end
UndergroundPathRoute7CopyUnusedTeamRocketHadAHideoutText:
    text_far _UndergroundPathRoute7CopyUnusedTeamRocketHadAHideoutText
    text_end
UndergroundPathRoute7CopyUnusedMiddleAgedManText:
    text_far _UndergroundPathRoute7CopyUnusedMiddleAgedManText
    text_end
UndergroundPathRoute7CopyUnusedGoesUnderSaffronText:
    text_far _UndergroundPathRoute7CopyUnusedGoesUnderSaffronText
    text_end
