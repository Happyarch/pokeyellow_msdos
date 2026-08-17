; Route16Gate2F.asm — translated from pret scripts/Route16Gate2F.asm by dos_port/tools/sm83xlat.
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


global Route16Gate2FLeftBinocularsText
global Route16Gate2FLittleBoyText
global Route16Gate2FLittleGirlText
global Route16Gate2FRightBinocularsText
global Route16Gate2F_Script
global Route16Gate2F_TextPointers

extern DisableAutoTextBoxDrawing
extern GateUpstairsScript_PrintIfFacingUp   ; NOT YET DEFINED IN THE PORT
extern PrintText
extern TextScriptEnd
extern _Route16Gate2FLeftBinocularsText   ; NOT YET DEFINED IN THE PORT
extern _Route16Gate2FLittleBoyText   ; NOT YET DEFINED IN THE PORT
extern _Route16Gate2FLittleGirlText   ; NOT YET DEFINED IN THE PORT
extern _Route16Gate2FRightBinocularsText   ; NOT YET DEFINED IN THE PORT

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
Route16Gate2F_Script:
    jmp DisableAutoTextBoxDrawing

%assign event_byte -1
%assign event_byte_a -1
Route16Gate2F_TextPointers:
    dd Route16Gate2FLittleBoyText
    dd Route16Gate2FLittleGirlText
    dd Route16Gate2FLeftBinocularsText
    dd Route16Gate2FRightBinocularsText

%assign event_byte -1
%assign event_byte_a -1
Route16Gate2FLittleBoyText:
    mov esi, .Text
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.Text:
    text_far _Route16Gate2FLittleBoyText
    text_end

%assign event_byte -1
%assign event_byte_a -1
Route16Gate2FLittleGirlText:
    mov esi, .Text
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.Text:
    text_far _Route16Gate2FLittleGirlText
    text_end

%assign event_byte -1
%assign event_byte_a -1
Route16Gate2FLeftBinocularsText:
    mov esi, .Text
    jmp GateUpstairsScript_PrintIfFacingUp

%assign event_byte -1
%assign event_byte_a -1
.Text:
    text_far _Route16Gate2FLeftBinocularsText
    text_end

%assign event_byte -1
%assign event_byte_a -1
Route16Gate2FRightBinocularsText:
    mov esi, .Text
    jmp GateUpstairsScript_PrintIfFacingUp

%assign event_byte -1
%assign event_byte_a -1
.Text:
    text_far _Route16Gate2FRightBinocularsText
    text_end
