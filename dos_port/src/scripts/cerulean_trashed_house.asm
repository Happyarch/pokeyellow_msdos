; CeruleanTrashedHouse.asm — translated from pret scripts/CeruleanTrashedHouse.asm by dos_port/tools/sm83xlat.
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


global CeruleanTrashedHouseGirlText
global CeruleanTrashedHouseWallHoleText
global CeruleanTrashedHouse_Script
global CeruleanTrashedHouse_TextPointers

extern CeruleanTrashedHouseFishingGuruText   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern GetQuantityOfItemInBag   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern _CeruleanTrashedHouseFishingGuruTheyStoleATMText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanTrashedHouseFishingGuruWhatsLostIsLostText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanTrashedHouseGirlText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanTrashedHouseWallHoleText   ; NOT YET DEFINED IN THE PORT

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

CeruleanTrashedHouse_Script:
    call EnableAutoTextBoxDrawing
    ret

CeruleanTrashedHouse_TextPointers:
    dd CeruleanTrashedHouseFishingGuruText
    dd CeruleanTrashedHouseGirlText
    dd CeruleanTrashedHouseWallHoleText

; ---------------------------------------------------------------------------
; BAIL[predef-leaves-id-in-a] CeruleanTrashedHouseFishingGuruText (scripts/CeruleanTrashedHouse.asm:13-19) — at scripts/CeruleanTrashedHouse.asm:14: predef GetQuantityOfItemInBag
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld b, TM_DIG
; PRET| 	predef GetQuantityOfItemInBag
; PRET| 	and b
; PRET| 	jr z, .no_dig_tm
; PRET| 	ld hl, .WhatsLostIsLostText
; PRET| 	call PrintText
; PRET| 	jr .done

.no_dig_tm:
    mov esi, .TheyStoleATMText
    call PrintText
.done:
    jmp TextScriptEnd

.TheyStoleATMText:
    text_far _CeruleanTrashedHouseFishingGuruTheyStoleATMText
    text_end
.WhatsLostIsLostText:
    text_far _CeruleanTrashedHouseFishingGuruWhatsLostIsLostText
    text_end
CeruleanTrashedHouseGirlText:
    text_far _CeruleanTrashedHouseGirlText
    text_end
CeruleanTrashedHouseWallHoleText:
    text_far _CeruleanTrashedHouseWallHoleText
    text_end
