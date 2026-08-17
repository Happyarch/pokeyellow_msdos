; CinnabarLabMetronomeRoom.asm — translated from pret scripts/CinnabarLabMetronomeRoom.asm by dos_port/tools/sm83xlat.
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


global CinnabarLabMetronomeRoom_Script
global CinnabarLabMetronomeRoom_TextPointers

extern CinnabarLabMetronomeRoomAmberPipeText   ; NOT YET DEFINED IN THE PORT
extern CinnabarLabMetronomeRoomPCText   ; NOT YET DEFINED IN THE PORT
extern CinnabarLabMetronomeRoomScientist1Text   ; NOT YET DEFINED IN THE PORT
extern CinnabarLabMetronomeRoomScientist2Text   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern GiveItem   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern _CinnabarLabMetronomeRoomScientist1ReceivedTM35Text   ; NOT YET DEFINED IN THE PORT
extern _CinnabarLabMetronomeRoomScientist1Text   ; NOT YET DEFINED IN THE PORT

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
CinnabarLabMetronomeRoom_Script:
    jmp EnableAutoTextBoxDrawing

%assign event_byte -1
CinnabarLabMetronomeRoom_TextPointers:
    dd CinnabarLabMetronomeRoomScientist1Text
    dd CinnabarLabMetronomeRoomScientist2Text
    dd CinnabarLabMetronomeRoomPCText
    dd CinnabarLabMetronomeRoomPCText
    dd CinnabarLabMetronomeRoomAmberPipeText

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] CinnabarLabMetronomeRoomScientist1Text (scripts/CinnabarLabMetronomeRoom.asm:14-24) — at scripts/CinnabarLabMetronomeRoom.asm:15: .got_item is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_GOT_TM35
; PRET| 	jr nz, .got_item
; PRET| 	ld hl, .Text
; PRET| 	call PrintText
; PRET| 	lb bc, TM_METRONOME, 1
; PRET| 	call GiveItem
; PRET| 	jr nc, .bag_full
; PRET| 	ld hl, .ReceivedTM35Text
; PRET| 	call PrintText
; PRET| 	SetEvent EVENT_GOT_TM35
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] CinnabarLabMetronomeRoomScientist1Text.bag_full (scripts/CinnabarLabMetronomeRoom.asm:26-28) — at scripts/CinnabarLabMetronomeRoom.asm:26: .TM35NoRoomText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .TM35NoRoomText
; PRET| 	call PrintText
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] CinnabarLabMetronomeRoomScientist1Text.got_item (scripts/CinnabarLabMetronomeRoom.asm:30-33) — at scripts/CinnabarLabMetronomeRoom.asm:30: .TM35ExplanationText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .TM35ExplanationText
; PRET| 	call PrintText
; PRET| .done
; PRET| 	jp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[text-sound-command-unported] CinnabarLabMetronomeRoomScientist1Text.Text (scripts/CinnabarLabMetronomeRoom.asm:36-62) — at scripts/CinnabarLabMetronomeRoom.asm:41: sound_get_item_1
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _CinnabarLabMetronomeRoomScientist1Text
; PRET| 	text_end
; PRET| 
; PRET| .ReceivedTM35Text:
; PRET| 	text_far _CinnabarLabMetronomeRoomScientist1ReceivedTM35Text
; PRET| 	sound_get_item_1
; PRET| 	text_end
; PRET| 
; PRET| .TM35ExplanationText:
; PRET| 	text_far _CinnabarLabMetronomeRoomScientist1TM35ExplanationText
; PRET| 	text_end
; PRET| 
; PRET| .TM35NoRoomText:
; PRET| 	text_far _CinnabarLabMetronomeRoomScientist1TM35NoRoomText
; PRET| 	text_end
; PRET| 
; PRET| CinnabarLabMetronomeRoomScientist2Text:
; PRET| 	text_far _CinnabarLabMetronomeRoomScientist2Text
; PRET| 	text_end
; PRET| 
; PRET| CinnabarLabMetronomeRoomPCText:
; PRET| 	text_far _CinnabarLabMetronomeRoomPCText
; PRET| 	text_end
; PRET| 
; PRET| CinnabarLabMetronomeRoomAmberPipeText:
; PRET| 	text_far _CinnabarLabMetronomeRoomAmberPipeText
; PRET| 	text_end
