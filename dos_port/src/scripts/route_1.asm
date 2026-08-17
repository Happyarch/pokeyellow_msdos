; Route1.asm — translated from pret scripts/Route1.asm, scripts/Route1_2.asm by dos_port/tools/sm83xlat.
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


global Route1PrintSignText
global Route1PrintYoungster1Text
global Route1PrintYoungster2Text
global Route1SignText
global Route1Youngster1Text
global Route1Youngster2Text
global Route1_Script
global Route1_TextPointers

extern Bankswitch
extern EnableAutoTextBoxDrawing
extern GiveItem
extern PrintText
extern TextScriptEnd
extern _Route1SignText   ; NOT YET DEFINED IN THE PORT
extern _Route1Youngster1AlsoGotPokeballsText   ; NOT YET DEFINED IN THE PORT
extern _Route1Youngster1GotPotionText   ; NOT YET DEFINED IN THE PORT
extern _Route1Youngster1MartSampleText   ; NOT YET DEFINED IN THE PORT
extern _Route1Youngster1NoRoomText   ; NOT YET DEFINED IN THE PORT
extern _Route1Youngster2Text   ; NOT YET DEFINED IN THE PORT

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
Route1_Script:
    call EnableAutoTextBoxDrawing
    ret

%assign event_byte -1
%assign event_byte_a -1
Route1_TextPointers:
    dd Route1Youngster1Text
    dd Route1Youngster2Text
    dd Route1SignText

%assign event_byte -1
%assign event_byte_a -1
Route1Youngster1Text:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call Route1PrintYoungster1Text
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
Route1Youngster2Text:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call Route1PrintYoungster2Text
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
Route1SignText:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call Route1PrintSignText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
Route1PrintYoungster1Text:
    CheckAndSetEvent EVENT_GOT_POTION_SAMPLE
    jnz .got_item
    mov esi, .MartSampleText
    call PrintText
    mov bx, ((POTION) << 8) | (1)
    call GiveItem
    jae .bag_full
    mov esi, .GotPotionText
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.bag_full:
    mov esi, .NoRoomText
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.got_item:
    mov esi, .AlsoGotPokeballsText
.done:
    call PrintText
    ret

%assign event_byte -1
%assign event_byte_a -1
.MartSampleText:
    text_far _Route1Youngster1MartSampleText
    text_end
.GotPotionText:
    text_far _Route1Youngster1GotPotionText
    sound_get_item_1
    text_end
.AlsoGotPokeballsText:
    text_far _Route1Youngster1AlsoGotPokeballsText
    text_end
.NoRoomText:
    text_far _Route1Youngster1NoRoomText
    text_end

%assign event_byte -1
%assign event_byte_a -1
Route1PrintYoungster2Text:
    mov esi, .text
    call PrintText
    ret

%assign event_byte -1
%assign event_byte_a -1
.text:
    text_far _Route1Youngster2Text
    text_end

%assign event_byte -1
%assign event_byte_a -1
Route1PrintSignText:
    mov esi, .text
    call PrintText
    ret

%assign event_byte -1
%assign event_byte_a -1
.text:
    text_far _Route1SignText
    text_end
