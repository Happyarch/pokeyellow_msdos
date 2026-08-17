; CinnabarLab.asm — translated from pret scripts/CinnabarLab.asm by dos_port/tools/sm83xlat.
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


global CinnabarLabFishingGuruText
global CinnabarLabMeetingRoomSignText
global CinnabarLabPhotoText
global CinnabarLabRAndDSignText
global CinnabarLabTestingRoomSignText
global CinnabarLab_Script
global CinnabarLab_TextPointers

extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern _CinnabarLabFishingGuruText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarLabMeetingRoomSignText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarLabPhotoText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarLabRAndDSignText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarLabTestingRoomSignText   ; NOT YET DEFINED IN THE PORT

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
CinnabarLab_Script:
    call EnableAutoTextBoxDrawing
    ret

%assign event_byte -1
%assign event_byte_a -1
CinnabarLab_TextPointers:
    dd CinnabarLabFishingGuruText
    dd CinnabarLabPhotoText
    dd CinnabarLabMeetingRoomSignText
    dd CinnabarLabRAndDSignText
    dd CinnabarLabTestingRoomSignText
CinnabarLabFishingGuruText:
    text_far _CinnabarLabFishingGuruText
    text_end
CinnabarLabPhotoText:
    text_far _CinnabarLabPhotoText
    text_end
CinnabarLabMeetingRoomSignText:
    text_far _CinnabarLabMeetingRoomSignText
    text_end
CinnabarLabRAndDSignText:
    text_far _CinnabarLabRAndDSignText
    text_end
CinnabarLabTestingRoomSignText:
    text_far _CinnabarLabTestingRoomSignText
    text_end
