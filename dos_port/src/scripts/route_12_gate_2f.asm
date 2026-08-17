; Route12Gate2F.asm — translated from pret scripts/Route12Gate2F.asm by dos_port/tools/sm83xlat.
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


global GateUpstairsScript_PrintIfFacingUp
global Route12Gate2FBrunetteGirlText
global Route12Gate2FLeftBinocularsText
global Route12Gate2FRightBinocularsText
global Route12Gate2F_Script
global Route12Gate2F_TextPointers

extern DisableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern GiveItem   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern _Route12Gate2FBrunetteGirlReceivedTM39Text   ; NOT YET DEFINED IN THE PORT
extern _Route12Gate2FBrunetteGirlTM39ExplanationText   ; NOT YET DEFINED IN THE PORT
extern _Route12Gate2FBrunetteGirlTM39NoRoomText   ; NOT YET DEFINED IN THE PORT
extern _Route12Gate2FBrunetteGirlYouCanHaveThisText   ; NOT YET DEFINED IN THE PORT
extern _Route12Gate2FLeftBinocularsText   ; NOT YET DEFINED IN THE PORT
extern _Route12Gate2FRightBinocularsText   ; NOT YET DEFINED IN THE PORT

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wSpritePlayerStateData1FacingDirection         equ 0xC109

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
Route12Gate2F_Script:
    jmp DisableAutoTextBoxDrawing

%assign event_byte -1
%assign event_byte_a -1
Route12Gate2F_TextPointers:
    dd Route12Gate2FBrunetteGirlText
    dd Route12Gate2FLeftBinocularsText
    dd Route12Gate2FRightBinocularsText

%assign event_byte -1
%assign event_byte_a -1
Route12Gate2FBrunetteGirlText:
    CheckEvent EVENT_GOT_TM39, 1
    jb .got_item
    mov esi, .YouCanHaveThisText
    call PrintText
    mov bx, ((241) << 8) | (1)
    call GiveItem
    jae .bag_full
    mov esi, .ReceivedTM39Text
    call PrintText
    SetEvent EVENT_GOT_TM39
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.bag_full:
    mov esi, .TM39NoRoomText
    call PrintText
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.got_item:
    mov esi, .TM39ExplanationText
    call PrintText
.done:
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.YouCanHaveThisText:
    text_far _Route12Gate2FBrunetteGirlYouCanHaveThisText
    text_end
.ReceivedTM39Text:
    text_far _Route12Gate2FBrunetteGirlReceivedTM39Text
    sound_get_item_1
    text_end
.TM39ExplanationText:
    text_far _Route12Gate2FBrunetteGirlTM39ExplanationText
    text_end
.TM39NoRoomText:
    text_far _Route12Gate2FBrunetteGirlTM39NoRoomText
    text_end

%assign event_byte -1
%assign event_byte_a -1
Route12Gate2FLeftBinocularsText:
    mov esi, .Text
    jmp GateUpstairsScript_PrintIfFacingUp

%assign event_byte -1
%assign event_byte_a -1
.Text:
    text_far _Route12Gate2FLeftBinocularsText
    text_end

%assign event_byte -1
%assign event_byte_a -1
Route12Gate2FRightBinocularsText:
    mov esi, .Text
    jmp GateUpstairsScript_PrintIfFacingUp

%assign event_byte -1
%assign event_byte_a -1
.Text:
    text_far _Route12Gate2FRightBinocularsText
    text_end

%assign event_byte -1
%assign event_byte_a -1
GateUpstairsScript_PrintIfFacingUp:
    mov al, [ebp + wSpritePlayerStateData1FacingDirection]
    cmp al, SPRITE_FACING_UP
    jz .up
    mov al, 1
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.up:
    call PrintText
    xor al, al
.done:
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    jmp TextScriptEnd
