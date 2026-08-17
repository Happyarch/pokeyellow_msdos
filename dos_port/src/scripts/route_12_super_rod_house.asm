; Route12SuperRodHouse.asm — translated from pret scripts/Route12SuperRodHouse.asm by dos_port/tools/sm83xlat.
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


global Route12SuperRodHouse_Script
global Route12SuperRodHouse_TextPointers

extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern GiveItem   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern Route12SuperRodHouseFishingGuruText   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern YesNoChoice   ; NOT YET DEFINED IN THE PORT
extern _Route12SuperRodHouseFishingGuruDoYouLikeToFishText   ; NOT YET DEFINED IN THE PORT
extern _Route12SuperRodHouseFishingGuruReceivedSuperRodText   ; NOT YET DEFINED IN THE PORT

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
Route12SuperRodHouse_Script:
    jmp EnableAutoTextBoxDrawing

%assign event_byte -1
Route12SuperRodHouse_TextPointers:
    dd Route12SuperRodHouseFishingGuruText

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] Route12SuperRodHouseFishingGuruText (scripts/Route12SuperRodHouse.asm:10-25) — at scripts/Route12SuperRodHouse.asm:12: .got_item is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wStatusFlags1]
; PRET| 	bit BIT_GOT_SUPER_ROD, a
; PRET| 	jr nz, .got_item
; PRET| 	ld hl, .DoYouLikeToFishText
; PRET| 	call PrintText
; PRET| 	call YesNoChoice
; PRET| 	ld a, [wCurrentMenuItem]
; PRET| 	and a
; PRET| 	jr nz, .refused
; PRET| 	lb bc, SUPER_ROD, 1
; PRET| 	call GiveItem
; PRET| 	jr nc, .bag_full
; PRET| 	ld hl, wStatusFlags1
; PRET| 	set BIT_GOT_SUPER_ROD, [hl]
; PRET| 	ld hl, .ReceivedSuperRodText
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] Route12SuperRodHouseFishingGuruText.bag_full (scripts/Route12SuperRodHouse.asm:27-28) — at scripts/Route12SuperRodHouse.asm:27: .NoRoomText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .NoRoomText
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] Route12SuperRodHouseFishingGuruText.refused (scripts/Route12SuperRodHouse.asm:30-31) — at scripts/Route12SuperRodHouse.asm:30: .ThatsDisappointingText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .ThatsDisappointingText
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] Route12SuperRodHouseFishingGuruText.got_item (scripts/Route12SuperRodHouse.asm:33-36) — at scripts/Route12SuperRodHouse.asm:33: .TryFishingText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .TryFishingText
; PRET| .done
; PRET| 	call PrintText
; PRET| 	jp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[text-sound-command-unported] Route12SuperRodHouseFishingGuruText.DoYouLikeToFishText (scripts/Route12SuperRodHouse.asm:39-58) — at scripts/Route12SuperRodHouse.asm:44: sound_get_item_1
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route12SuperRodHouseFishingGuruDoYouLikeToFishText
; PRET| 	text_end
; PRET| 
; PRET| .ReceivedSuperRodText:
; PRET| 	text_far _Route12SuperRodHouseFishingGuruReceivedSuperRodText
; PRET| 	sound_get_item_1
; PRET| 	text_far _Route12SuperRodHouseFishingGuruFishingWayOfLifeText
; PRET| 	text_end
; PRET| 
; PRET| .ThatsDisappointingText:
; PRET| 	text_far _Route12SuperRodHouseFishingGuruThatsDisappointingText
; PRET| 	text_end
; PRET| 
; PRET| .TryFishingText:
; PRET| 	text_far _Route12SuperRodHouseFishingGuruTryFishingText
; PRET| 	text_end
; PRET| 
; PRET| .NoRoomText:
; PRET| 	text_far _Route12SuperRodHouseFishingGuruNoRoomText
; PRET| 	text_end
