; Route21.asm — translated from pret scripts/Route21.asm by dos_port/tools/sm83xlat.
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

%include "assets/map_script_tables.inc"
%include "assets/trainer_headers.inc"

global Route21Fisher1Text
global Route21Fisher2Text
global Route21Fisher3Text
global Route21Fisher4Text
global Route21Swimmer1Text
global Route21Swimmer2Text
global Route21Swimmer3Text
global Route21Swimmer4Text
global Route21Swimmer5Text
global Route21_Script

extern EnableAutoTextBoxDrawing
extern ExecuteCurMapScriptInTable
extern Route21Fisher1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route21TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern Route21TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern Route21TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern Route21TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern Route21TrainerHeader4   ; NOT YET DEFINED IN THE PORT
extern Route21TrainerHeader5   ; NOT YET DEFINED IN THE PORT
extern Route21TrainerHeader6   ; NOT YET DEFINED IN THE PORT
extern Route21TrainerHeader7   ; NOT YET DEFINED IN THE PORT
extern Route21TrainerHeader8   ; NOT YET DEFINED IN THE PORT
extern Route21TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern Route21_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer
extern TextScriptEnd

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wRoute21CurScript                              equ 0xD61D

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
Route21_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route21TrainerHeaders
    mov edi, Route21_ScriptPointers   ; pret: ld de, Route21_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRoute21CurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRoute21CurScript], al
    ret

; Route21_ScriptPointers (scripts/Route21.asm:11-48) — not re-emitted: Route21_ScriptPointers is already defined in assets/map_script_tables.inc.

%assign event_byte -1
%assign event_byte_a -1
Route21Fisher1Text:
    mov esi, Route21TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
Route21Fisher2Text:
    mov esi, Route21TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
Route21Swimmer1Text:
    mov esi, Route21TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
Route21Swimmer2Text:
    mov esi, Route21TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
Route21Swimmer3Text:
    mov esi, Route21TrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
Route21Swimmer4Text:
    mov esi, Route21TrainerHeader5
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
Route21Swimmer5Text:
    mov esi, Route21TrainerHeader6
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
Route21Fisher3Text:
    mov esi, Route21TrainerHeader7
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
Route21Fisher4Text:
    mov esi, Route21TrainerHeader8
    call TalkToTrainer
    jmp TextScriptEnd

; Route21Fisher1BattleText (scripts/Route21.asm:105-210) — not re-emitted: Route21Fisher1BattleText is already defined in assets/trainer_headers.inc.
