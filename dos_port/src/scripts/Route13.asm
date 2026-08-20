; Route13.asm — translated from pret scripts/Route13.asm by dos_port/tools/sm83xlat.
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
extern Route13_ScriptPointers ; assets/map_script_tables.inc
; Trainer headers and battle text are DEFINED once, by the single carrier
; src/data/trainer_headers.asm. Declare what this script uses; do NOT %include
; assets/trainer_headers.inc here — the asset DEFINES all 1302 symbols, so an
; include makes every one of them a duplicate global the moment a second script
; links. (That is what kept 202 link-ready scripts out of the build.)
extern Route13Beauty1BattleText       ; assets/trainer_headers.inc
extern Route13Beauty2BattleText       ; assets/trainer_headers.inc
extern Route13BikerBattleText         ; assets/trainer_headers.inc
extern Route13CooltrainerF1BattleText ; assets/trainer_headers.inc
extern Route13CooltrainerF2BattleText ; assets/trainer_headers.inc
extern Route13CooltrainerF3BattleText ; assets/trainer_headers.inc
extern Route13CooltrainerF4BattleText ; assets/trainer_headers.inc
extern Route13CooltrainerM1BattleText ; assets/trainer_headers.inc
extern Route13CooltrainerM2BattleText ; assets/trainer_headers.inc
extern Route13CooltrainerM3BattleText ; assets/trainer_headers.inc
extern Route13TrainerHeader0          ; assets/trainer_headers.inc
extern Route13TrainerHeader1          ; assets/trainer_headers.inc
extern Route13TrainerHeader2          ; assets/trainer_headers.inc
extern Route13TrainerHeader3          ; assets/trainer_headers.inc
extern Route13TrainerHeader4          ; assets/trainer_headers.inc
extern Route13TrainerHeader5          ; assets/trainer_headers.inc
extern Route13TrainerHeader6          ; assets/trainer_headers.inc
extern Route13TrainerHeader7          ; assets/trainer_headers.inc
extern Route13TrainerHeader8          ; assets/trainer_headers.inc
extern Route13TrainerHeader9          ; assets/trainer_headers.inc
extern Route13TrainerHeaders          ; assets/trainer_headers.inc

global Route13Beauty1Text
global Route13Beauty2Text
global Route13BikerText
global Route13CooltrainerF1Text
global Route13CooltrainerF2Text
global Route13CooltrainerF3Text
global Route13CooltrainerF4Text
global Route13CooltrainerM1Text
global Route13CooltrainerM2Text
global Route13CooltrainerM3Text
global Route13_Script

extern EnableAutoTextBoxDrawing
extern ExecuteCurMapScriptInTable
extern Route13Beauty1BattleText
extern Route13Beauty2BattleText
extern Route13BikerBattleText
extern Route13CooltrainerF1BattleText
extern Route13CooltrainerF2BattleText
extern Route13CooltrainerF3BattleText
extern Route13CooltrainerF4BattleText
extern Route13CooltrainerM1BattleText
extern Route13CooltrainerM2BattleText
extern Route13CooltrainerM3BattleText
extern Route13TrainerHeader0
extern Route13TrainerHeader1
extern Route13TrainerHeader2
extern Route13TrainerHeader3
extern Route13TrainerHeader4
extern Route13TrainerHeader5
extern Route13TrainerHeader6
extern Route13TrainerHeader7
extern Route13TrainerHeader8
extern Route13TrainerHeader9
extern Route13TrainerHeaders
extern Route13_ScriptPointers
extern TalkToTrainer
extern TextScriptEnd

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
Route13_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route13TrainerHeaders
    mov edi, Route13_ScriptPointers   ; pret: ld de, Route13_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRoute13CurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRoute13CurScript], al
    ret

; Route13_ScriptPointers (scripts/Route13.asm:11-54) — not re-emitted: Route13_ScriptPointers is already defined in assets/map_script_tables.inc.

%assign event_byte -1
%assign event_byte_a -1
Route13CooltrainerM1Text:
    mov esi, Route13TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; Route13CooltrainerM1BattleText (scripts/Route13.asm:63-72) — not re-emitted: Route13CooltrainerM1BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route13CooltrainerF1Text:
    mov esi, Route13TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; Route13CooltrainerF1BattleText (scripts/Route13.asm:81-90) — not re-emitted: Route13CooltrainerF1BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route13CooltrainerF2Text:
    mov esi, Route13TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; Route13CooltrainerF2BattleText (scripts/Route13.asm:99-108) — not re-emitted: Route13CooltrainerF2BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route13CooltrainerF3Text:
    mov esi, Route13TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

; Route13CooltrainerF3BattleText (scripts/Route13.asm:117-126) — not re-emitted: Route13CooltrainerF3BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route13CooltrainerF4Text:
    mov esi, Route13TrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

; Route13CooltrainerF4BattleText (scripts/Route13.asm:135-144) — not re-emitted: Route13CooltrainerF4BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route13CooltrainerM2Text:
    mov esi, Route13TrainerHeader5
    call TalkToTrainer
    jmp TextScriptEnd

; Route13CooltrainerM2BattleText (scripts/Route13.asm:153-162) — not re-emitted: Route13CooltrainerM2BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route13Beauty1Text:
    mov esi, Route13TrainerHeader6
    call TalkToTrainer
    jmp TextScriptEnd

; Route13Beauty1BattleText (scripts/Route13.asm:171-180) — not re-emitted: Route13Beauty1BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route13Beauty2Text:
    mov esi, Route13TrainerHeader7
    call TalkToTrainer
    jmp TextScriptEnd

; Route13Beauty2BattleText (scripts/Route13.asm:189-198) — not re-emitted: Route13Beauty2BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route13BikerText:
    mov esi, Route13TrainerHeader8
    call TalkToTrainer
    jmp TextScriptEnd

; Route13BikerBattleText (scripts/Route13.asm:207-216) — not re-emitted: Route13BikerBattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route13CooltrainerM3Text:
    mov esi, Route13TrainerHeader9
    call TalkToTrainer
    jmp TextScriptEnd

; Route13CooltrainerM3BattleText (scripts/Route13.asm:225-246) — not re-emitted: Route13CooltrainerM3BattleText is already defined in assets/trainer_headers.inc.
