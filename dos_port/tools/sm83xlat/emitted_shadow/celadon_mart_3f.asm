; CeladonMart3F.asm — translated from pret scripts/CeladonMart3F.asm, scripts/CeladonMart3F_2.asm by dos_port/tools/sm83xlat.
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


global CeladonMart3FClerkText
global CeladonMart3FCurrentFloorSignText
global CeladonMart3FFightingGameText
global CeladonMart3FGameBoyKid1Text
global CeladonMart3FGameBoyKid2Text
global CeladonMart3FGameBoyKid3Text
global CeladonMart3FLittleBoyText
global CeladonMart3FPokemonPosterText
global CeladonMart3FPuzzleGameText
global CeladonMart3FRPGText
global CeladonMart3FSNESText
global CeladonMart3FSportsGameText
global CeladonMart3F_Script
global CeladonMart3F_TextPointers

extern Bankswitch   ; NOT YET DEFINED IN THE PORT
extern CeladonMart3FPrintClerkText   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern GiveItem   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern _CeladonMart3FClerkReceivedTM18Text   ; NOT YET DEFINED IN THE PORT
extern _CeladonMart3FClerkTM18PreReceiveText   ; NOT YET DEFINED IN THE PORT
extern _CeladonMart3FCurrentFloorSignText   ; NOT YET DEFINED IN THE PORT
extern _CeladonMart3FFightingGameText   ; NOT YET DEFINED IN THE PORT
extern _CeladonMart3FGameBoyKid1Text   ; NOT YET DEFINED IN THE PORT
extern _CeladonMart3FGameBoyKid2Text   ; NOT YET DEFINED IN THE PORT
extern _CeladonMart3FGameBoyKid3Text   ; NOT YET DEFINED IN THE PORT
extern _CeladonMart3FLittleBoyText   ; NOT YET DEFINED IN THE PORT
extern _CeladonMart3FPokemonPosterText   ; NOT YET DEFINED IN THE PORT
extern _CeladonMart3FPuzzleGameText   ; NOT YET DEFINED IN THE PORT
extern _CeladonMart3FRPGText   ; NOT YET DEFINED IN THE PORT
extern _CeladonMart3FSNESText   ; NOT YET DEFINED IN THE PORT
extern _CeladonMart3FSportsGameText   ; NOT YET DEFINED IN THE PORT

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

CeladonMart3F_Script:
    jmp EnableAutoTextBoxDrawing

CeladonMart3F_TextPointers:
    dd CeladonMart3FClerkText
    dd CeladonMart3FGameBoyKid1Text
    dd CeladonMart3FGameBoyKid2Text
    dd CeladonMart3FGameBoyKid3Text
    dd CeladonMart3FLittleBoyText
    dd CeladonMart3FSNESText
    dd CeladonMart3FRPGText
    dd CeladonMart3FSNESText
    dd CeladonMart3FSportsGameText
    dd CeladonMart3FSNESText
    dd CeladonMart3FPuzzleGameText
    dd CeladonMart3FSNESText
    dd CeladonMart3FFightingGameText
    dd CeladonMart3FCurrentFloorSignText
    dd CeladonMart3FPokemonPosterText
    dd CeladonMart3FPokemonPosterText
    dd CeladonMart3FPokemonPosterText

CeladonMart3FClerkText:
; DEVIATION{class=banking; pret=macros/farcall.asm:callfar; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call CeladonMart3FPrintClerkText
    jmp TextScriptEnd

CeladonMart3FGameBoyKid1Text:
    text_far _CeladonMart3FGameBoyKid1Text
    text_end
CeladonMart3FGameBoyKid2Text:
    text_far _CeladonMart3FGameBoyKid2Text
    text_end
CeladonMart3FGameBoyKid3Text:
    text_far _CeladonMart3FGameBoyKid3Text
    text_end
CeladonMart3FLittleBoyText:
    text_far _CeladonMart3FLittleBoyText
    text_end
CeladonMart3FSNESText:
    text_far _CeladonMart3FSNESText
    text_end
CeladonMart3FRPGText:
    text_far _CeladonMart3FRPGText
    text_end
CeladonMart3FSportsGameText:
    text_far _CeladonMart3FSportsGameText
    text_end
CeladonMart3FPuzzleGameText:
    text_far _CeladonMart3FPuzzleGameText
    text_end
CeladonMart3FFightingGameText:
    text_far _CeladonMart3FFightingGameText
    text_end
CeladonMart3FCurrentFloorSignText:
    text_far _CeladonMart3FCurrentFloorSignText
    text_end
CeladonMart3FPokemonPosterText:
    text_far _CeladonMart3FPokemonPosterText
    text_end

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] CeladonMart3FPrintClerkText (scripts/CeladonMart3F_2.asm:2-11) — at scripts/CeladonMart3F_2.asm:3: .got_item is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_GOT_TM18
; PRET| 	jr nz, .got_item
; PRET| 	ld hl, .TM18PreReceiveText
; PRET| 	call PrintText
; PRET| 	lb bc, TM_COUNTER, 1
; PRET| 	call GiveItem
; PRET| 	jr nc, .bag_full
; PRET| 	SetEvent EVENT_GOT_TM18
; PRET| 	ld hl, .ReceivedTM18Text
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] CeladonMart3FPrintClerkText.bag_full (scripts/CeladonMart3F_2.asm:13-14) — at scripts/CeladonMart3F_2.asm:13: .TM18NoRoomText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .TM18NoRoomText
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] CeladonMart3FPrintClerkText.got_item (scripts/CeladonMart3F_2.asm:16-19) — at scripts/CeladonMart3F_2.asm:16: .TM18ExplanationText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .TM18ExplanationText
; PRET| .done
; PRET| 	call PrintText
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[text-sound-command-unported] CeladonMart3FPrintClerkText.TM18PreReceiveText (scripts/CeladonMart3F_2.asm:22-36) — at scripts/CeladonMart3F_2.asm:27: sound_get_item_1
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _CeladonMart3FClerkTM18PreReceiveText
; PRET| 	text_end
; PRET| 
; PRET| .ReceivedTM18Text:
; PRET| 	text_far _CeladonMart3FClerkReceivedTM18Text
; PRET| 	sound_get_item_1
; PRET| 	text_end
; PRET| 
; PRET| .TM18ExplanationText:
; PRET| 	text_far _CeladonMart3FClerkTM18ExplanationText
; PRET| 	text_end
; PRET| 
; PRET| .TM18NoRoomText:
; PRET| 	text_far _CeladonMart3FClerkTM18NoRoomText
; PRET| 	text_end
