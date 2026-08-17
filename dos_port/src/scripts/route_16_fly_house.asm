; Route16FlyHouse.asm — translated from pret scripts/Route16FlyHouse.asm by dos_port/tools/sm83xlat.
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


global Route16FlyHouse_Script
global Route16FlyHouse_TextPointers

extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern GiveItem   ; NOT YET DEFINED IN THE PORT
extern PlayCry   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern Route16FlyHouseBrunetteGirlText   ; NOT YET DEFINED IN THE PORT
extern Route16FlyHouseFearowText   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern WaitForSoundToFinish   ; NOT YET DEFINED IN THE PORT
extern _Route16FlyHouseBrunetteGirlReceivedHM02Text   ; NOT YET DEFINED IN THE PORT
extern _Route16FlyHouseBrunetteGirlText   ; NOT YET DEFINED IN THE PORT
extern _Route16FlyHouseFearowText   ; NOT YET DEFINED IN THE PORT

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
Route16FlyHouse_Script:
    jmp EnableAutoTextBoxDrawing

%assign event_byte -1
Route16FlyHouse_TextPointers:
    dd Route16FlyHouseBrunetteGirlText
    dd Route16FlyHouseFearowText

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] Route16FlyHouseBrunetteGirlText (scripts/Route16FlyHouse.asm:11-21) — at scripts/Route16FlyHouse.asm:12: .HM02ExplanationText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_GOT_HM02
; PRET| 	ld hl, .HM02ExplanationText
; PRET| 	jr nz, .got_item
; PRET| 	ld hl, .Text
; PRET| 	call PrintText
; PRET| 	lb bc, HM_FLY, 1
; PRET| 	call GiveItem
; PRET| 	jr nc, .bag_full
; PRET| 	SetEvent EVENT_GOT_HM02
; PRET| 	ld hl, .ReceivedHM02Text
; PRET| 	jr .got_item

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] Route16FlyHouseBrunetteGirlText.bag_full (scripts/Route16FlyHouse.asm:23-26) — at scripts/Route16FlyHouse.asm:23: .HM02NoRoomText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .HM02NoRoomText
; PRET| .got_item
; PRET| 	call PrintText
; PRET| 	jp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[text-sound-command-unported] Route16FlyHouseBrunetteGirlText.Text (scripts/Route16FlyHouse.asm:29-43) — at scripts/Route16FlyHouse.asm:34: sound_get_key_item
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route16FlyHouseBrunetteGirlText
; PRET| 	text_end
; PRET| 
; PRET| .ReceivedHM02Text:
; PRET| 	text_far _Route16FlyHouseBrunetteGirlReceivedHM02Text
; PRET| 	sound_get_key_item
; PRET| 	text_end
; PRET| 
; PRET| .HM02ExplanationText:
; PRET| 	text_far _Route16FlyHouseBrunetteGirlHM02ExplanationText
; PRET| 	text_end
; PRET| 
; PRET| .HM02NoRoomText:
; PRET| 	text_far _Route16FlyHouseBrunetteGirlHM02NoRoomText
; PRET| 	text_end

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] Route16FlyHouseFearowText (scripts/Route16FlyHouse.asm:47-52) — at scripts/Route16FlyHouse.asm:47: .Text is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .Text
; PRET| 	call PrintText
; PRET| 	ld a, FEAROW
; PRET| 	call PlayCry
; PRET| 	call WaitForSoundToFinish
; PRET| 	jp TextScriptEnd

%assign event_byte -1
.Text:
    text_far _Route16FlyHouseFearowText
    text_end
