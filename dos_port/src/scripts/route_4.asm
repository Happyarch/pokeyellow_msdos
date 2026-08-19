; Route4.asm — translated from pret scripts/Route4.asm by dos_port/tools/sm83xlat.
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

; Map script-pointer tables are DEFINED once, by the single carrier
; src/data/map_script_tables.asm. Declare what this script uses; do NOT %include
; assets/map_script_tables.inc here — the asset DEFINES every table, so an include
; makes them duplicate globals as soon as a second script links.
extern Route4_ScriptPointers ; assets/map_script_tables.inc
; Trainer headers and battle text are DEFINED once, by the single carrier
; src/data/trainer_headers.asm. Declare what this script uses; do NOT %include
; assets/trainer_headers.inc here — the asset DEFINES all 1302 symbols, so an
; include makes every one of them a duplicate global the moment a second script
; links. (That is what kept 202 link-ready scripts out of the build.)
extern Route4CooltrainerF2BattleText ; assets/trainer_headers.inc
extern Route4TrainerHeader0          ; assets/trainer_headers.inc
extern Route4TrainerHeaders          ; assets/trainer_headers.inc

global Route4CooltrainerF2Text
global Route4_Script

extern EnableAutoTextBoxDrawing
extern ExecuteCurMapScriptInTable
extern Route4CooltrainerF2BattleText
extern Route4TrainerHeader0
extern Route4TrainerHeaders
extern Route4_ScriptPointers
extern TalkToTrainer
extern TextScriptEnd

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
Route4_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route4TrainerHeaders
    mov edi, Route4_ScriptPointers   ; pret: ld de, Route4_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRoute4CurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRoute4CurScript], al
    ret

; Route4_ScriptPointers (scripts/Route4.asm:11-33) — not re-emitted: Route4_ScriptPointers is already defined in assets/map_script_tables.inc.

%assign event_byte -1
%assign event_byte_a -1
Route4CooltrainerF2Text:
    mov esi, Route4TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; Route4CooltrainerF2BattleText (scripts/Route4.asm:42-59) — not re-emitted: Route4CooltrainerF2BattleText is already defined in assets/trainer_headers.inc.
