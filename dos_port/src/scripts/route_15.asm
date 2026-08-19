; Route15.asm — translated from pret scripts/Route15.asm by dos_port/tools/sm83xlat.
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
extern Route15_ScriptPointers ; assets/map_script_tables.inc
; Trainer headers and battle text are DEFINED once, by the single carrier
; src/data/trainer_headers.asm. Declare what this script uses; do NOT %include
; assets/trainer_headers.inc here — the asset DEFINES all 1302 symbols, so an
; include makes every one of them a duplicate global the moment a second script
; links. (That is what kept 202 link-ready scripts out of the build.)
extern Route15CooltrainerF1BattleText ; assets/trainer_headers.inc
extern Route15TrainerHeader0          ; assets/trainer_headers.inc
extern Route15TrainerHeader1          ; assets/trainer_headers.inc
extern Route15TrainerHeader2          ; assets/trainer_headers.inc
extern Route15TrainerHeader3          ; assets/trainer_headers.inc
extern Route15TrainerHeader4          ; assets/trainer_headers.inc
extern Route15TrainerHeader5          ; assets/trainer_headers.inc
extern Route15TrainerHeader6          ; assets/trainer_headers.inc
extern Route15TrainerHeader7          ; assets/trainer_headers.inc
extern Route15TrainerHeader8          ; assets/trainer_headers.inc
extern Route15TrainerHeader9          ; assets/trainer_headers.inc
extern Route15TrainerHeaders          ; assets/trainer_headers.inc

global Route15Beauty1Text
global Route15Beauty2Text
global Route15Biker1Text
global Route15Biker2Text
global Route15CooltrainerF1Text
global Route15CooltrainerF2Text
global Route15CooltrainerF3Text
global Route15CooltrainerF4Text
global Route15CooltrainerM1Text
global Route15CooltrainerM2Text
global Route15TalkToTrainer
global Route15_Script

extern EnableAutoTextBoxDrawing
extern ExecuteCurMapScriptInTable
extern Route15CooltrainerF1BattleText
extern Route15TrainerHeader0
extern Route15TrainerHeader1
extern Route15TrainerHeader2
extern Route15TrainerHeader3
extern Route15TrainerHeader4
extern Route15TrainerHeader5
extern Route15TrainerHeader6
extern Route15TrainerHeader7
extern Route15TrainerHeader8
extern Route15TrainerHeader9
extern Route15TrainerHeaders
extern Route15_ScriptPointers
extern TalkToTrainer
extern TextScriptEnd

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
Route15_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route15TrainerHeaders
    mov edi, Route15_ScriptPointers   ; pret: ld de, Route15_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRoute15CurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRoute15CurScript], al
    ret

; Route15_ScriptPointers (scripts/Route15.asm:11-53) — not re-emitted: Route15_ScriptPointers is already defined in assets/map_script_tables.inc.

%assign event_byte -1
%assign event_byte_a -1
Route15CooltrainerF1Text:
    mov esi, Route15TrainerHeader0
    jmp Route15TalkToTrainer

%assign event_byte -1
%assign event_byte_a -1
Route15CooltrainerF2Text:
    mov esi, Route15TrainerHeader1
    jmp Route15TalkToTrainer

%assign event_byte -1
%assign event_byte_a -1
Route15CooltrainerM1Text:
    mov esi, Route15TrainerHeader2
    jmp Route15TalkToTrainer

%assign event_byte -1
%assign event_byte_a -1
Route15CooltrainerM2Text:
    mov esi, Route15TrainerHeader3
    jmp Route15TalkToTrainer

%assign event_byte -1
%assign event_byte_a -1
Route15Beauty1Text:
    mov esi, Route15TrainerHeader4
    jmp Route15TalkToTrainer

%assign event_byte -1
%assign event_byte_a -1
Route15Beauty2Text:
    mov esi, Route15TrainerHeader5
    jmp Route15TalkToTrainer

%assign event_byte -1
%assign event_byte_a -1
Route15Biker1Text:
    mov esi, Route15TrainerHeader6
    jmp Route15TalkToTrainer

%assign event_byte -1
%assign event_byte_a -1
Route15Biker2Text:
    mov esi, Route15TrainerHeader7
    jmp Route15TalkToTrainer

%assign event_byte -1
%assign event_byte_a -1
Route15CooltrainerF3Text:
    mov esi, Route15TrainerHeader8
    jmp Route15TalkToTrainer

%assign event_byte -1
%assign event_byte_a -1
Route15CooltrainerF4Text:
    mov esi, Route15TrainerHeader9
Route15TalkToTrainer:
    call TalkToTrainer
    jmp TextScriptEnd

; Route15CooltrainerF1BattleText (scripts/Route15.asm:108-229) — not re-emitted: Route15CooltrainerF1BattleText is already defined in assets/trainer_headers.inc.
