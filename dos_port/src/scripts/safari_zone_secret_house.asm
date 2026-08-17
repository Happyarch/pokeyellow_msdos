; SafariZoneSecretHouse.asm — translated from pret scripts/SafariZoneSecretHouse.asm by dos_port/tools/sm83xlat.
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


global SafariZoneSecretHouse_Script
global SafariZoneSecretHouse_TextPointers

extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern GiveItem   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern SafariZoneSecretHouseFishingGuruText   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern _SafariZoneSecretHouseFishingGuruReceivedHM03Text   ; NOT YET DEFINED IN THE PORT
extern _SafariZoneSecretHouseFishingGuruYouHaveWonText   ; NOT YET DEFINED IN THE PORT

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
SafariZoneSecretHouse_Script:
    jmp EnableAutoTextBoxDrawing

%assign event_byte -1
SafariZoneSecretHouse_TextPointers:
    dd SafariZoneSecretHouseFishingGuruText

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] SafariZoneSecretHouseFishingGuruText (scripts/SafariZoneSecretHouse.asm:10-20) — at scripts/SafariZoneSecretHouse.asm:11: .got_item is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_GOT_HM03
; PRET| 	jr nz, .got_item
; PRET| 	ld hl, .YouHaveWonText
; PRET| 	call PrintText
; PRET| 	lb bc, HM_SURF, 1
; PRET| 	call GiveItem
; PRET| 	jr nc, .bag_full
; PRET| 	ld hl, .ReceivedHM03Text
; PRET| 	call PrintText
; PRET| 	SetEvent EVENT_GOT_HM03
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] SafariZoneSecretHouseFishingGuruText.bag_full (scripts/SafariZoneSecretHouse.asm:22-24) — at scripts/SafariZoneSecretHouse.asm:22: .HM03NoRoomText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .HM03NoRoomText
; PRET| 	call PrintText
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] SafariZoneSecretHouseFishingGuruText.got_item (scripts/SafariZoneSecretHouse.asm:26-29) — at scripts/SafariZoneSecretHouse.asm:26: .HM03ExplanationText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .HM03ExplanationText
; PRET| 	call PrintText
; PRET| .done
; PRET| 	jp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[text-sound-command-unported] SafariZoneSecretHouseFishingGuruText.YouHaveWonText (scripts/SafariZoneSecretHouse.asm:32-46) — at scripts/SafariZoneSecretHouse.asm:37: sound_get_item_1
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _SafariZoneSecretHouseFishingGuruYouHaveWonText
; PRET| 	text_end
; PRET| 
; PRET| .ReceivedHM03Text:
; PRET| 	text_far _SafariZoneSecretHouseFishingGuruReceivedHM03Text
; PRET| 	sound_get_item_1
; PRET| 	text_end
; PRET| 
; PRET| .HM03ExplanationText:
; PRET| 	text_far _SafariZoneSecretHouseFishingGuruHM03ExplanationText
; PRET| 	text_end
; PRET| 
; PRET| .HM03NoRoomText:
; PRET| 	text_far _SafariZoneSecretHouseFishingGuruHM03NoRoomText
; PRET| 	text_end
