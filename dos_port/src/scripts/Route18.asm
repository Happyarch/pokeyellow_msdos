; Route18.asm — translated from pret scripts/Route18.asm by dos_port/tools/sm83xlat.
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
extern Route18_ScriptPointers ; assets/map_script_tables.inc
; Trainer headers and battle text are DEFINED once, by the single carrier
; src/data/trainer_headers.asm. Declare what this script uses; do NOT %include
; assets/trainer_headers.inc here — the asset DEFINES all 1302 symbols, so an
; include makes every one of them a duplicate global the moment a second script
; links. (That is what kept 202 link-ready scripts out of the build.)
extern Route18CooltrainerM1BattleText ; assets/trainer_headers.inc
extern Route18CooltrainerM2BattleText ; assets/trainer_headers.inc
extern Route18CooltrainerM3BattleText ; assets/trainer_headers.inc
extern Route18TrainerHeader0          ; assets/trainer_headers.inc
extern Route18TrainerHeader1          ; assets/trainer_headers.inc
extern Route18TrainerHeader2          ; assets/trainer_headers.inc
extern Route18TrainerHeaders          ; assets/trainer_headers.inc

global Route18CooltrainerM1Text
global Route18CooltrainerM2Text
global Route18CooltrainerM3Text
global Route18_Script

extern EnableAutoTextBoxDrawing
extern ExecuteCurMapScriptInTable
extern Route18CooltrainerM1BattleText
extern Route18CooltrainerM2BattleText
extern Route18CooltrainerM3BattleText
extern Route18TrainerHeader0
extern Route18TrainerHeader1
extern Route18TrainerHeader2
extern Route18TrainerHeaders
extern Route18_ScriptPointers
extern TalkToTrainer
extern TextScriptEnd

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
Route18_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route18TrainerHeaders
    mov edi, Route18_ScriptPointers   ; pret: ld de, Route18_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRoute18CurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRoute18CurScript], al
    ret

; Route18_ScriptPointers (scripts/Route18.asm:11-32) — not re-emitted: Route18_ScriptPointers is already defined in assets/map_script_tables.inc.

%assign event_byte -1
%assign event_byte_a -1
Route18CooltrainerM1Text:
    mov esi, Route18TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; Route18CooltrainerM1BattleText (scripts/Route18.asm:41-50) — not re-emitted: Route18CooltrainerM1BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route18CooltrainerM2Text:
    mov esi, Route18TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; Route18CooltrainerM2BattleText (scripts/Route18.asm:59-68) — not re-emitted: Route18CooltrainerM2BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route18CooltrainerM3Text:
    mov esi, Route18TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; Route18CooltrainerM3BattleText (scripts/Route18.asm:77-94) — not re-emitted: Route18CooltrainerM3BattleText is already defined in assets/trainer_headers.inc.
