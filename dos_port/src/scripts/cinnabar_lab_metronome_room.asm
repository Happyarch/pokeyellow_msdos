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


global CinnabarLabMetronomeRoomAmberPipeText
global CinnabarLabMetronomeRoomPCText
global CinnabarLabMetronomeRoomScientist1Text
global CinnabarLabMetronomeRoomScientist2Text
global CinnabarLabMetronomeRoom_Script
global CinnabarLabMetronomeRoom_TextPointers

extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern GiveItem   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern _CinnabarLabMetronomeRoomAmberPipeText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarLabMetronomeRoomPCText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarLabMetronomeRoomScientist1ReceivedTM35Text   ; NOT YET DEFINED IN THE PORT
extern _CinnabarLabMetronomeRoomScientist1TM35ExplanationText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarLabMetronomeRoomScientist1TM35NoRoomText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarLabMetronomeRoomScientist1Text   ; NOT YET DEFINED IN THE PORT
extern _CinnabarLabMetronomeRoomScientist2Text   ; NOT YET DEFINED IN THE PORT

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

%assign event_byte -1
CinnabarLabMetronomeRoomScientist1Text:
    CheckEvent EVENT_GOT_TM35
    jnz .got_item
    mov esi, .Text
    call PrintText
    mov bx, ((237) << 8) | (1)
    call GiveItem
    jae .bag_full
    mov esi, .ReceivedTM35Text
    call PrintText
    SetEvent EVENT_GOT_TM35
    jmp .done

%assign event_byte -1
.bag_full:
    mov esi, .TM35NoRoomText
    call PrintText
    jmp .done

%assign event_byte -1
.got_item:
    mov esi, .TM35ExplanationText
    call PrintText
.done:
    jmp TextScriptEnd

%assign event_byte -1
.Text:
    text_far _CinnabarLabMetronomeRoomScientist1Text
    text_end
.ReceivedTM35Text:
    text_far _CinnabarLabMetronomeRoomScientist1ReceivedTM35Text
    sound_get_item_1
    text_end
.TM35ExplanationText:
    text_far _CinnabarLabMetronomeRoomScientist1TM35ExplanationText
    text_end
.TM35NoRoomText:
    text_far _CinnabarLabMetronomeRoomScientist1TM35NoRoomText
    text_end
CinnabarLabMetronomeRoomScientist2Text:
    text_far _CinnabarLabMetronomeRoomScientist2Text
    text_end
CinnabarLabMetronomeRoomPCText:
    text_far _CinnabarLabMetronomeRoomPCText
    text_end
CinnabarLabMetronomeRoomAmberPipeText:
    text_far _CinnabarLabMetronomeRoomAmberPipeText
    text_end
