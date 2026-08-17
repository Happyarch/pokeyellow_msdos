; FuchsiaGoodRodHouse.asm — translated from pret scripts/FuchsiaGoodRodHouse.asm by dos_port/tools/sm83xlat.
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


global FuchsiaGoodRodHouse_Script
global FuchsiaGoodRodHouse_TextPointers

extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern FuchsiaGoodRodHouseFishingGuruText   ; NOT YET DEFINED IN THE PORT
extern GiveItem   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern YesNoChoice   ; NOT YET DEFINED IN THE PORT
extern _FuchsiaGoodRodHouseFishingGuruReceivedGoodRodText   ; NOT YET DEFINED IN THE PORT
extern _FuchsiaGoodRodHouseFishingGuruText   ; NOT YET DEFINED IN THE PORT

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
FuchsiaGoodRodHouse_Script:
    jmp EnableAutoTextBoxDrawing

%assign event_byte -1
FuchsiaGoodRodHouse_TextPointers:
    dd FuchsiaGoodRodHouseFishingGuruText

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] FuchsiaGoodRodHouseFishingGuruText (scripts/FuchsiaGoodRodHouse.asm:10-25) — at scripts/FuchsiaGoodRodHouse.asm:12: .got_item is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wStatusFlags1]
; PRET| 	bit BIT_GOT_GOOD_ROD, a
; PRET| 	jr nz, .got_item
; PRET| 	ld hl, .Text
; PRET| 	call PrintText
; PRET| 	call YesNoChoice
; PRET| 	ld a, [wCurrentMenuItem]
; PRET| 	and a
; PRET| 	jr nz, .refused
; PRET| 	lb bc, GOOD_ROD, 1
; PRET| 	call GiveItem
; PRET| 	jr nc, .bag_full
; PRET| 	ld hl, wStatusFlags1
; PRET| 	set BIT_GOT_GOOD_ROD, [hl]
; PRET| 	ld hl, .ReceivedGoodRodText
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] FuchsiaGoodRodHouseFishingGuruText.bag_full (scripts/FuchsiaGoodRodHouse.asm:27-28) — at scripts/FuchsiaGoodRodHouse.asm:27: .NoRoomText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .NoRoomText
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] FuchsiaGoodRodHouseFishingGuruText.refused (scripts/FuchsiaGoodRodHouse.asm:30-31) — at scripts/FuchsiaGoodRodHouse.asm:30: .ThatsSoDisappointingText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .ThatsSoDisappointingText
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] FuchsiaGoodRodHouseFishingGuruText.got_item (scripts/FuchsiaGoodRodHouse.asm:33-36) — at scripts/FuchsiaGoodRodHouse.asm:33: .HowAreTheFishText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .HowAreTheFishText
; PRET| .done
; PRET| 	call PrintText
; PRET| 	jp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[inline-text-db] FuchsiaGoodRodHouseFishingGuruText.Text (scripts/FuchsiaGoodRodHouse.asm:39-67) — at scripts/FuchsiaGoodRodHouse.asm:48: para "つり　こそ"
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _FuchsiaGoodRodHouseFishingGuruText
; PRET| 	text_end
; PRET| 
; PRET| .ReceivedGoodRodText:
; PRET| 	text_far _FuchsiaGoodRodHouseFishingGuruReceivedGoodRodText
; PRET| 	sound_get_item_1
; PRET| 	text_end
; PRET| 
; PRET| .UnusedText:
; PRET| 	para "つり　こそ"
; PRET| 	line "おとこの　ロマン　だ！"
; PRET| 
; PRET| 	para "へぼいつりざおは"
; PRET| 	line "コイキングしか　つれ　なんだが"
; PRET| 	line "この　いいつりざおなら"
; PRET| 	line "もっと　いいもんが　つれるんじゃ！"
; PRET| 	done
; PRET| 
; PRET| .ThatsSoDisappointingText:
; PRET| 	text_far _FuchsiaGoodRodHouseFishingGuruThatsSoDisappointingText
; PRET| 	text_end
; PRET| 
; PRET| .HowAreTheFishText:
; PRET| 	text_far _FuchsiaGoodRodHouseFishingGuruHowAreTheFishText
; PRET| 	text_end
; PRET| 
; PRET| .NoRoomText:
; PRET| 	text_far _FuchsiaGoodRodHouseFishingGuruNoRoomText
; PRET| 	text_end
