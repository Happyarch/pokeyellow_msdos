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


global VermilionOldRodHouseFishingGuruText
global VermilionOldRodHouse_Script
global VermilionOldRodHouse_TextPointers

extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern GiveItem   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern YesNoChoice   ; NOT YET DEFINED IN THE PORT
extern _VermilionOldRodHouseFishingGuruDoYouLikeToFishText   ; NOT YET DEFINED IN THE PORT
extern _VermilionOldRodHouseFishingGuruFishingIsAWayOfLifeText   ; NOT YET DEFINED IN THE PORT
extern _VermilionOldRodHouseFishingGuruHowAreTheFishBitingText   ; NOT YET DEFINED IN THE PORT
extern _VermilionOldRodHouseFishingGuruNoRoomText   ; NOT YET DEFINED IN THE PORT
extern _VermilionOldRodHouseFishingGuruTakeThisText   ; NOT YET DEFINED IN THE PORT
extern _VermilionOldRodHouseFishingGuruThatsSoDisappointingText   ; NOT YET DEFINED IN THE PORT

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
VermilionOldRodHouse_Script:
    jmp EnableAutoTextBoxDrawing

%assign event_byte -1
%assign event_byte_a -1
VermilionOldRodHouse_TextPointers:
    dd VermilionOldRodHouseFishingGuruText

%assign event_byte -1
%assign event_byte_a -1
VermilionOldRodHouseFishingGuruText:
    mov al, [ebp + wStatusFlags1]
    test al, (1 << (3))
    jnz .got_old_rod
    mov esi, .DoYouLikeToFishText
    call PrintText
    call YesNoChoice
    mov al, [ebp + wCurrentMenuItem]
    test al, al
    jnz .refused
    mov bx, ((OLD_ROD) << 8) | (1)
    call GiveItem
    jae .bag_full
    mov esi, wStatusFlags1
    or byte [ebp + esi], (1 << (3))
    mov esi, .TakeThisText
    jmp .print_text

%assign event_byte -1
%assign event_byte_a -1
.bag_full:
    mov esi, .NoRoomText
    jmp .print_text

%assign event_byte -1
%assign event_byte_a -1
.refused:
    mov esi, .ThatsSoDisappointingText
    jmp .print_text

%assign event_byte -1
%assign event_byte_a -1
.got_old_rod:
    mov esi, .HowAreTheFishBitingText
.print_text:
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.DoYouLikeToFishText:
    text_far _VermilionOldRodHouseFishingGuruDoYouLikeToFishText
    text_end
.TakeThisText:
    text_far _VermilionOldRodHouseFishingGuruTakeThisText
    sound_get_item_1
    text_far _VermilionOldRodHouseFishingGuruFishingIsAWayOfLifeText
    text_end
.ThatsSoDisappointingText:
    text_far _VermilionOldRodHouseFishingGuruThatsSoDisappointingText
    text_end
.HowAreTheFishBitingText:
    text_far _VermilionOldRodHouseFishingGuruHowAreTheFishBitingText
    text_end
.NoRoomText:
    text_far _VermilionOldRodHouseFishingGuruNoRoomText
    text_end
