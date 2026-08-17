; CeladonDiner.asm — translated from pret scripts/CeladonDiner.asm, scripts/CeladonDiner_2.asm by dos_port/tools/sm83xlat.
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


global CeladonDinerCookText
global CeladonDinerFisherText
global CeladonDinerGymGuideText
global CeladonDinerMiddleAgedManText
global CeladonDinerMiddleAgedWomanText
global CeladonDiner_Script
global CeladonDiner_TextPointers

extern Bankswitch   ; NOT YET DEFINED IN THE PORT
extern CeladonDinerPrintGymGuideText   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern GiveItem   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern _CeladonDinerCookText   ; NOT YET DEFINED IN THE PORT
extern _CeladonDinerFisherText   ; NOT YET DEFINED IN THE PORT
extern _CeladonDinerGymGuideImFlatOutBustedText   ; NOT YET DEFINED IN THE PORT
extern _CeladonDinerGymGuideReceivedCoinCaseText   ; NOT YET DEFINED IN THE PORT
extern _CeladonDinerMiddleAgedManText   ; NOT YET DEFINED IN THE PORT
extern _CeladonDinerMiddleAgedWomanText   ; NOT YET DEFINED IN THE PORT

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
CeladonDiner_Script:
    call EnableAutoTextBoxDrawing
    ret

%assign event_byte -1
CeladonDiner_TextPointers:
    dd CeladonDinerCookText
    dd CeladonDinerMiddleAgedWomanText
    dd CeladonDinerMiddleAgedManText
    dd CeladonDinerFisherText
    dd CeladonDinerGymGuideText
CeladonDinerCookText:
    text_far _CeladonDinerCookText
    text_end
CeladonDinerMiddleAgedWomanText:
    text_far _CeladonDinerMiddleAgedWomanText
    text_end
CeladonDinerMiddleAgedManText:
    text_far _CeladonDinerMiddleAgedManText
    text_end
CeladonDinerFisherText:
    text_far _CeladonDinerFisherText
    text_end

%assign event_byte -1
CeladonDinerGymGuideText:
; DEVIATION{class=banking; pret=macros/farcall.asm:callfar; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call CeladonDinerPrintGymGuideText
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] CeladonDinerPrintGymGuideText (scripts/CeladonDiner_2.asm:2-12) — at scripts/CeladonDiner_2.asm:3: .got_item is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_GOT_COIN_CASE
; PRET| 	jr nz, .got_item
; PRET| 	ld hl, .ImFlatOutBustedText
; PRET| 	call PrintText
; PRET| 	lb bc, COIN_CASE, 1
; PRET| 	call GiveItem
; PRET| 	jr nc, .bag_full
; PRET| 	SetEvent EVENT_GOT_COIN_CASE
; PRET| 	ld hl, .ReceivedCoinCaseText
; PRET| 	call PrintText
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] CeladonDinerPrintGymGuideText.bag_full (scripts/CeladonDiner_2.asm:14-16) — at scripts/CeladonDiner_2.asm:14: .CoinCaseNoRoomText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .CoinCaseNoRoomText
; PRET| 	call PrintText
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] CeladonDinerPrintGymGuideText.got_item (scripts/CeladonDiner_2.asm:18-21) — at scripts/CeladonDiner_2.asm:18: .WinItBackText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .WinItBackText
; PRET| 	call PrintText
; PRET| .done
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[text-sound-command-unported] CeladonDinerPrintGymGuideText.ImFlatOutBustedText (scripts/CeladonDiner_2.asm:24-38) — at scripts/CeladonDiner_2.asm:29: sound_get_key_item
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _CeladonDinerGymGuideImFlatOutBustedText
; PRET| 	text_end
; PRET| 
; PRET| .ReceivedCoinCaseText:
; PRET| 	text_far _CeladonDinerGymGuideReceivedCoinCaseText
; PRET| 	sound_get_key_item
; PRET| 	text_end
; PRET| 
; PRET| .CoinCaseNoRoomText:
; PRET| 	text_far _CeladonDinerGymGuideCoinCaseNoRoomText
; PRET| 	text_end
; PRET| 
; PRET| .WinItBackText:
; PRET| 	text_far _CeladonDinerGymGuideWinItBackText
; PRET| 	text_end
