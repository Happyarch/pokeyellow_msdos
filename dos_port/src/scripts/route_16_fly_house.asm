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
%include "assets/script_constants.inc"


global Route16FlyHouseBrunetteGirlText
global Route16FlyHouseFearowText
global Route16FlyHouse_Script
global Route16FlyHouse_TextPointers

extern EnableAutoTextBoxDrawing
extern GiveItem
extern PlayCry
extern PrintText
extern TextScriptEnd
extern WaitForSoundToFinish
extern _Route16FlyHouseBrunetteGirlHM02ExplanationText   ; NOT YET DEFINED IN THE PORT
extern _Route16FlyHouseBrunetteGirlHM02NoRoomText   ; NOT YET DEFINED IN THE PORT
extern _Route16FlyHouseBrunetteGirlReceivedHM02Text   ; NOT YET DEFINED IN THE PORT
extern _Route16FlyHouseBrunetteGirlText   ; NOT YET DEFINED IN THE PORT
extern _Route16FlyHouseFearowText   ; NOT YET DEFINED IN THE PORT

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
Route16FlyHouse_Script:
    jmp EnableAutoTextBoxDrawing

%assign event_byte -1
%assign event_byte_a -1
Route16FlyHouse_TextPointers:
    dd Route16FlyHouseBrunetteGirlText
    dd Route16FlyHouseFearowText

%assign event_byte -1
%assign event_byte_a -1
Route16FlyHouseBrunetteGirlText:
    CheckEvent EVENT_GOT_HM02
    mov esi, .HM02ExplanationText
    jnz .got_item
    mov esi, .Text
    call PrintText
    mov bx, (HM_FLY << 8) | (1)   ; pret: lb bc, HM_FLY, 1  (HM02 = $C5)
    call GiveItem
    jae .bag_full
    SetEvent EVENT_GOT_HM02
    mov esi, .ReceivedHM02Text
    jmp .got_item

%assign event_byte -1
%assign event_byte_a -1
.bag_full:
    mov esi, .HM02NoRoomText
.got_item:
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.Text:
    text_far _Route16FlyHouseBrunetteGirlText
    text_end
.ReceivedHM02Text:
    text_far _Route16FlyHouseBrunetteGirlReceivedHM02Text
    sound_get_key_item
    text_end
.HM02ExplanationText:
    text_far _Route16FlyHouseBrunetteGirlHM02ExplanationText
    text_end
.HM02NoRoomText:
    text_far _Route16FlyHouseBrunetteGirlHM02NoRoomText
    text_end

%assign event_byte -1
%assign event_byte_a -1
Route16FlyHouseFearowText:
    mov esi, .Text
    call PrintText
    mov al, FEAROW
    call PlayCry
    call WaitForSoundToFinish
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.Text:
    text_far _Route16FlyHouseFearowText
    text_end
