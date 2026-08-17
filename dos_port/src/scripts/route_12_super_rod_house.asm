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


global Route12SuperRodHouseFishingGuruText
global Route12SuperRodHouse_Script
global Route12SuperRodHouse_TextPointers

extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern GiveItem   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern YesNoChoice   ; NOT YET DEFINED IN THE PORT
extern _Route12SuperRodHouseFishingGuruDoYouLikeToFishText   ; NOT YET DEFINED IN THE PORT
extern _Route12SuperRodHouseFishingGuruFishingWayOfLifeText   ; NOT YET DEFINED IN THE PORT
extern _Route12SuperRodHouseFishingGuruNoRoomText   ; NOT YET DEFINED IN THE PORT
extern _Route12SuperRodHouseFishingGuruReceivedSuperRodText   ; NOT YET DEFINED IN THE PORT
extern _Route12SuperRodHouseFishingGuruThatsDisappointingText   ; NOT YET DEFINED IN THE PORT
extern _Route12SuperRodHouseFishingGuruTryFishingText   ; NOT YET DEFINED IN THE PORT

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
Route12SuperRodHouse_Script:
    jmp EnableAutoTextBoxDrawing

%assign event_byte -1
%assign event_byte_a -1
Route12SuperRodHouse_TextPointers:
    dd Route12SuperRodHouseFishingGuruText

%assign event_byte -1
%assign event_byte_a -1
Route12SuperRodHouseFishingGuruText:
    mov al, [ebp + wStatusFlags1]
    test al, (1 << (5))
    jnz .got_item
    mov esi, .DoYouLikeToFishText
    call PrintText
    call YesNoChoice
    mov al, [ebp + wCurrentMenuItem]
    test al, al
    jnz .refused
    mov bx, ((SUPER_ROD) << 8) | (1)
    call GiveItem
    jae .bag_full
    mov esi, wStatusFlags1
    or byte [ebp + esi], (1 << (5))
    mov esi, .ReceivedSuperRodText
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.bag_full:
    mov esi, .NoRoomText
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.refused:
    mov esi, .ThatsDisappointingText
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.got_item:
    mov esi, .TryFishingText
.done:
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.DoYouLikeToFishText:
    text_far _Route12SuperRodHouseFishingGuruDoYouLikeToFishText
    text_end
.ReceivedSuperRodText:
    text_far _Route12SuperRodHouseFishingGuruReceivedSuperRodText
    sound_get_item_1
    text_far _Route12SuperRodHouseFishingGuruFishingWayOfLifeText
    text_end
.ThatsDisappointingText:
    text_far _Route12SuperRodHouseFishingGuruThatsDisappointingText
    text_end
.TryFishingText:
    text_far _Route12SuperRodHouseFishingGuruTryFishingText
    text_end
.NoRoomText:
    text_far _Route12SuperRodHouseFishingGuruNoRoomText
    text_end
