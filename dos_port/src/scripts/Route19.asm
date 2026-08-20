; Route19.asm — translated from pret scripts/Route19.asm by dos_port/tools/sm83xlat.
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
extern Route19_ScriptPointers ; assets/map_script_tables.inc
; Trainer headers and battle text are DEFINED once, by the single carrier
; src/data/trainer_headers.asm. Declare what this script uses; do NOT %include
; assets/trainer_headers.inc here — the asset DEFINES all 1302 symbols, so an
; include makes every one of them a duplicate global the moment a second script
; links. (That is what kept 202 link-ready scripts out of the build.)
extern Route19CooltrainerM1BattleText ; assets/trainer_headers.inc
extern Route19TrainerHeader0          ; assets/trainer_headers.inc
extern Route19TrainerHeader1          ; assets/trainer_headers.inc
extern Route19TrainerHeader2          ; assets/trainer_headers.inc
extern Route19TrainerHeader3          ; assets/trainer_headers.inc
extern Route19TrainerHeader4          ; assets/trainer_headers.inc
extern Route19TrainerHeader5          ; assets/trainer_headers.inc
extern Route19TrainerHeader6          ; assets/trainer_headers.inc
extern Route19TrainerHeader7          ; assets/trainer_headers.inc
extern Route19TrainerHeader8          ; assets/trainer_headers.inc
extern Route19TrainerHeader9          ; assets/trainer_headers.inc
extern Route19TrainerHeaders          ; assets/trainer_headers.inc

global Route19CooltrainerM1Text
global Route19CooltrainerM2Text
global Route19Swimmer1Text
global Route19Swimmer2Text
global Route19Swimmer3Text
global Route19Swimmer4Text
global Route19Swimmer5Text
global Route19Swimmer6Text
global Route19Swimmer7Text
global Route19Swimmer8Text
global Route19_Script
global Route19_TalkToTrainer

extern EnableAutoTextBoxDrawing
extern ExecuteCurMapScriptInTable
extern Route19CooltrainerM1BattleText
extern Route19TrainerHeader0
extern Route19TrainerHeader1
extern Route19TrainerHeader2
extern Route19TrainerHeader3
extern Route19TrainerHeader4
extern Route19TrainerHeader5
extern Route19TrainerHeader6
extern Route19TrainerHeader7
extern Route19TrainerHeader8
extern Route19TrainerHeader9
extern Route19TrainerHeaders
extern Route19_ScriptPointers
extern TalkToTrainer
extern TextScriptEnd

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
Route19_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route19TrainerHeaders
    mov edi, Route19_ScriptPointers   ; pret: ld de, Route19_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRoute19CurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRoute19CurScript], al
    ret

; Route19_ScriptPointers (scripts/Route19.asm:11-52) — not re-emitted: Route19_ScriptPointers is already defined in assets/map_script_tables.inc.

%assign event_byte -1
%assign event_byte_a -1
Route19CooltrainerM1Text:
    mov esi, Route19TrainerHeader0
    jmp Route19_TalkToTrainer

%assign event_byte -1
%assign event_byte_a -1
Route19CooltrainerM2Text:
    mov esi, Route19TrainerHeader1
    jmp Route19_TalkToTrainer

%assign event_byte -1
%assign event_byte_a -1
Route19Swimmer1Text:
    mov esi, Route19TrainerHeader2
    jmp Route19_TalkToTrainer

%assign event_byte -1
%assign event_byte_a -1
Route19Swimmer2Text:
    mov esi, Route19TrainerHeader3
    jmp Route19_TalkToTrainer

%assign event_byte -1
%assign event_byte_a -1
Route19Swimmer3Text:
    mov esi, Route19TrainerHeader4
    jmp Route19_TalkToTrainer

%assign event_byte -1
%assign event_byte_a -1
Route19Swimmer4Text:
    mov esi, Route19TrainerHeader5
    jmp Route19_TalkToTrainer

%assign event_byte -1
%assign event_byte_a -1
Route19Swimmer5Text:
    mov esi, Route19TrainerHeader6
    jmp Route19_TalkToTrainer

%assign event_byte -1
%assign event_byte_a -1
Route19Swimmer6Text:
    mov esi, Route19TrainerHeader7
    jmp Route19_TalkToTrainer

%assign event_byte -1
%assign event_byte_a -1
Route19Swimmer7Text:
    mov esi, Route19TrainerHeader8
    jmp Route19_TalkToTrainer

%assign event_byte -1
%assign event_byte_a -1
Route19Swimmer8Text:
    mov esi, Route19TrainerHeader9
Route19_TalkToTrainer:
    call TalkToTrainer
    jmp TextScriptEnd

; Route19CooltrainerM1BattleText (scripts/Route19.asm:107-228) — not re-emitted: Route19CooltrainerM1BattleText is already defined in assets/trainer_headers.inc.
