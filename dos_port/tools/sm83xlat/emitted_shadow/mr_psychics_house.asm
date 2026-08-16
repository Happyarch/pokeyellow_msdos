; MrPsychicsHouse.asm — translated from pret scripts/MrPsychicsHouse.asm by dos_port/tools/sm83xlat.
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


global MrPsychicsHouse_Script
global MrPsychicsHouse_TextPointers

extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern GiveItem   ; NOT YET DEFINED IN THE PORT
extern MrPsychicsHouseMrPsychicText   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern _MrPsychicsHouseMrPsychicReceivedTM29Text   ; NOT YET DEFINED IN THE PORT
extern _MrPsychicsHouseMrPsychicYouWantedThisText   ; NOT YET DEFINED IN THE PORT

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

MrPsychicsHouse_Script:
    jmp EnableAutoTextBoxDrawing

MrPsychicsHouse_TextPointers:
    dd MrPsychicsHouseMrPsychicText

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] MrPsychicsHouseMrPsychicText (scripts/MrPsychicsHouse.asm:10-20) — at scripts/MrPsychicsHouse.asm:11: .got_item is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_GOT_TM29
; PRET| 	jr nz, .got_item
; PRET| 	ld hl, .YouWantedThisText
; PRET| 	call PrintText
; PRET| 	lb bc, TM_PSYCHIC_M, 1
; PRET| 	call GiveItem
; PRET| 	jr nc, .bag_full
; PRET| 	ld hl, .ReceivedTM29Text
; PRET| 	call PrintText
; PRET| 	SetEvent EVENT_GOT_TM29
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] MrPsychicsHouseMrPsychicText.bag_full (scripts/MrPsychicsHouse.asm:22-24) — at scripts/MrPsychicsHouse.asm:22: .TM29NoRoomText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .TM29NoRoomText
; PRET| 	call PrintText
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] MrPsychicsHouseMrPsychicText.got_item (scripts/MrPsychicsHouse.asm:26-29) — at scripts/MrPsychicsHouse.asm:26: .TM29ExplanationText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .TM29ExplanationText
; PRET| 	call PrintText
; PRET| .done
; PRET| 	jp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[text-sound-command-unported] MrPsychicsHouseMrPsychicText.YouWantedThisText (scripts/MrPsychicsHouse.asm:32-46) — at scripts/MrPsychicsHouse.asm:37: sound_get_item_1
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _MrPsychicsHouseMrPsychicYouWantedThisText
; PRET| 	text_end
; PRET| 
; PRET| .ReceivedTM29Text:
; PRET| 	text_far _MrPsychicsHouseMrPsychicReceivedTM29Text
; PRET| 	sound_get_item_1
; PRET| 	text_end
; PRET| 
; PRET| .TM29ExplanationText:
; PRET| 	text_far _MrPsychicsHouseMrPsychicTM29ExplanationText
; PRET| 	text_end
; PRET| 
; PRET| .TM29NoRoomText:
; PRET| 	text_far _MrPsychicsHouseMrPsychicTM29NoRoomText
; PRET| 	text_end
