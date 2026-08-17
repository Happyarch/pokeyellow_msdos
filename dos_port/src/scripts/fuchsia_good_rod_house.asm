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
%include "assets/script_constants.inc"

%include "assets/script_strings.inc"

global FuchsiaGoodRodHouseFishingGuruText
global FuchsiaGoodRodHouse_Script
global FuchsiaGoodRodHouse_TextPointers

extern EnableAutoTextBoxDrawing
extern GiveItem
extern PrintText
extern TextScriptEnd
extern YesNoChoice
extern _FuchsiaGoodRodHouseFishingGuruHowAreTheFishText   ; NOT YET DEFINED IN THE PORT
extern _FuchsiaGoodRodHouseFishingGuruNoRoomText   ; NOT YET DEFINED IN THE PORT
extern _FuchsiaGoodRodHouseFishingGuruReceivedGoodRodText   ; NOT YET DEFINED IN THE PORT
extern _FuchsiaGoodRodHouseFishingGuruText   ; NOT YET DEFINED IN THE PORT
extern _FuchsiaGoodRodHouseFishingGuruThatsSoDisappointingText   ; NOT YET DEFINED IN THE PORT

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
FuchsiaGoodRodHouse_Script:
    jmp EnableAutoTextBoxDrawing

%assign event_byte -1
%assign event_byte_a -1
FuchsiaGoodRodHouse_TextPointers:
    dd FuchsiaGoodRodHouseFishingGuruText

%assign event_byte -1
%assign event_byte_a -1
FuchsiaGoodRodHouseFishingGuruText:
    mov al, [ebp + wStatusFlags1]
    test al, (1 << (BIT_GOT_GOOD_ROD))
    jnz .got_item
    mov esi, .Text
    call PrintText
    call YesNoChoice
    mov al, [ebp + wCurrentMenuItem]
    test al, al
    jnz .refused
    mov bx, ((GOOD_ROD) << 8) | (1)
    call GiveItem
    jae .bag_full
    mov esi, wStatusFlags1
    or byte [ebp + esi], (1 << (BIT_GOT_GOOD_ROD))
    mov esi, .ReceivedGoodRodText
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.bag_full:
    mov esi, .NoRoomText
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.refused:
    mov esi, .ThatsSoDisappointingText
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.got_item:
    mov esi, .HowAreTheFishText
.done:
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.Text:
    text_far _FuchsiaGoodRodHouseFishingGuruText
    text_end
.ReceivedGoodRodText:
    text_far _FuchsiaGoodRodHouseFishingGuruReceivedGoodRodText
    sound_get_item_1
    text_end
.UnusedText:
    TEXT_FuchsiaGoodRodHouseFishingGuruText_UnusedText
.ThatsSoDisappointingText:
    text_far _FuchsiaGoodRodHouseFishingGuruThatsSoDisappointingText
    text_end
.HowAreTheFishText:
    text_far _FuchsiaGoodRodHouseFishingGuruHowAreTheFishText
    text_end
.NoRoomText:
    text_far _FuchsiaGoodRodHouseFishingGuruNoRoomText
    text_end
