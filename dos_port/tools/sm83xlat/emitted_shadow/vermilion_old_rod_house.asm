; VermilionOldRodHouse.asm — translated from pret scripts/VermilionOldRodHouse.asm by dos_port/tools/sm83xlat.
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


global VermilionOldRodHouse_Script
global VermilionOldRodHouse_TextPointers

extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern GiveItem   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern VermilionOldRodHouseFishingGuruText   ; NOT YET DEFINED IN THE PORT
extern YesNoChoice   ; NOT YET DEFINED IN THE PORT
extern _VermilionOldRodHouseFishingGuruDoYouLikeToFishText   ; NOT YET DEFINED IN THE PORT
extern _VermilionOldRodHouseFishingGuruTakeThisText   ; NOT YET DEFINED IN THE PORT

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

VermilionOldRodHouse_Script:
    jmp EnableAutoTextBoxDrawing

VermilionOldRodHouse_TextPointers:
    dd VermilionOldRodHouseFishingGuruText

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] VermilionOldRodHouseFishingGuruText (scripts/VermilionOldRodHouse.asm:10-25) — at scripts/VermilionOldRodHouse.asm:12: .got_old_rod is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wStatusFlags1]
; PRET| 	bit BIT_GOT_OLD_ROD, a
; PRET| 	jr nz, .got_old_rod
; PRET| 	ld hl, .DoYouLikeToFishText
; PRET| 	call PrintText
; PRET| 	call YesNoChoice
; PRET| 	ld a, [wCurrentMenuItem]
; PRET| 	and a
; PRET| 	jr nz, .refused
; PRET| 	lb bc, OLD_ROD, 1
; PRET| 	call GiveItem
; PRET| 	jr nc, .bag_full
; PRET| 	ld hl, wStatusFlags1
; PRET| 	set BIT_GOT_OLD_ROD, [hl]
; PRET| 	ld hl, .TakeThisText
; PRET| 	jr .print_text

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] VermilionOldRodHouseFishingGuruText.bag_full (scripts/VermilionOldRodHouse.asm:27-28) — at scripts/VermilionOldRodHouse.asm:27: .NoRoomText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .NoRoomText
; PRET| 	jr .print_text

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] VermilionOldRodHouseFishingGuruText.refused (scripts/VermilionOldRodHouse.asm:30-31) — at scripts/VermilionOldRodHouse.asm:30: .ThatsSoDisappointingText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .ThatsSoDisappointingText
; PRET| 	jr .print_text

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] VermilionOldRodHouseFishingGuruText.got_old_rod (scripts/VermilionOldRodHouse.asm:33-36) — at scripts/VermilionOldRodHouse.asm:33: .HowAreTheFishBitingText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .HowAreTheFishBitingText
; PRET| .print_text
; PRET| 	call PrintText
; PRET| 	jp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[text-sound-command-unported] VermilionOldRodHouseFishingGuruText.DoYouLikeToFishText (scripts/VermilionOldRodHouse.asm:39-58) — at scripts/VermilionOldRodHouse.asm:44: sound_get_item_1
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _VermilionOldRodHouseFishingGuruDoYouLikeToFishText
; PRET| 	text_end
; PRET| 
; PRET| .TakeThisText:
; PRET| 	text_far _VermilionOldRodHouseFishingGuruTakeThisText
; PRET| 	sound_get_item_1
; PRET| 	text_far _VermilionOldRodHouseFishingGuruFishingIsAWayOfLifeText
; PRET| 	text_end
; PRET| 
; PRET| .ThatsSoDisappointingText:
; PRET| 	text_far _VermilionOldRodHouseFishingGuruThatsSoDisappointingText
; PRET| 	text_end
; PRET| 
; PRET| .HowAreTheFishBitingText:
; PRET| 	text_far _VermilionOldRodHouseFishingGuruHowAreTheFishBitingText
; PRET| 	text_end
; PRET| 
; PRET| .NoRoomText:
; PRET| 	text_far _VermilionOldRodHouseFishingGuruNoRoomText
; PRET| 	text_end
