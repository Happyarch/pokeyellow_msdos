; Route3.asm — translated from pret scripts/Route3.asm by dos_port/tools/sm83xlat.
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
extern Route3_ScriptPointers ; assets/map_script_tables.inc
; Trainer headers and battle text are DEFINED once, by the single carrier
; src/data/trainer_headers.asm. Declare what this script uses; do NOT %include
; assets/trainer_headers.inc here — the asset DEFINES all 1302 symbols, so an
; include makes every one of them a duplicate global the moment a second script
; links. (That is what kept 202 link-ready scripts out of the build.)
extern Route3CooltrainerF1BattleText ; assets/trainer_headers.inc
extern Route3CooltrainerF2BattleText ; assets/trainer_headers.inc
extern Route3CooltrainerF3BattleText ; assets/trainer_headers.inc
extern Route3TrainerHeader0          ; assets/trainer_headers.inc
extern Route3TrainerHeader1          ; assets/trainer_headers.inc
extern Route3TrainerHeader2          ; assets/trainer_headers.inc
extern Route3TrainerHeader3          ; assets/trainer_headers.inc
extern Route3TrainerHeader4          ; assets/trainer_headers.inc
extern Route3TrainerHeader5          ; assets/trainer_headers.inc
extern Route3TrainerHeader6          ; assets/trainer_headers.inc
extern Route3TrainerHeader7          ; assets/trainer_headers.inc
extern Route3TrainerHeaders          ; assets/trainer_headers.inc
extern Route3Youngster1BattleText    ; assets/trainer_headers.inc
extern Route3Youngster2BattleText    ; assets/trainer_headers.inc
extern Route3Youngster3BattleText    ; assets/trainer_headers.inc
extern Route3Youngster4BattleText    ; assets/trainer_headers.inc
extern Route3Youngster5BattleText    ; assets/trainer_headers.inc

global Route3CooltrainerF1Text
global Route3CooltrainerF2Text
global Route3CooltrainerF3Text
global Route3Youngster1Text
global Route3Youngster2Text
global Route3Youngster3Text
global Route3Youngster4Text
global Route3Youngster5Text
global Route3_Script

extern EnableAutoTextBoxDrawing
extern ExecuteCurMapScriptInTable
extern Route3CooltrainerF1BattleText
extern Route3CooltrainerF2BattleText
extern Route3CooltrainerF3BattleText
extern Route3TrainerHeader0
extern Route3TrainerHeader1
extern Route3TrainerHeader2
extern Route3TrainerHeader3
extern Route3TrainerHeader4
extern Route3TrainerHeader5
extern Route3TrainerHeader6
extern Route3TrainerHeader7
extern Route3TrainerHeaders
extern Route3Youngster1BattleText
extern Route3Youngster2BattleText
extern Route3Youngster3BattleText
extern Route3Youngster4BattleText
extern Route3Youngster5BattleText
extern Route3_ScriptPointers
extern TalkToTrainer
extern TextScriptEnd

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
Route3_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route3TrainerHeaders
    mov edi, Route3_ScriptPointers   ; pret: ld de, Route3_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRoute3CurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRoute3CurScript], al
    ret

; Route3_ScriptPointers (scripts/Route3.asm:11-51) — not re-emitted: Route3_ScriptPointers is already defined in assets/map_script_tables.inc.

%assign event_byte -1
%assign event_byte_a -1
Route3Youngster1Text:
    mov esi, Route3TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; Route3Youngster1BattleText (scripts/Route3.asm:60-69) — not re-emitted: Route3Youngster1BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route3Youngster2Text:
    mov esi, Route3TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; Route3Youngster2BattleText (scripts/Route3.asm:78-87) — not re-emitted: Route3Youngster2BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route3CooltrainerF1Text:
    mov esi, Route3TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; Route3CooltrainerF1BattleText (scripts/Route3.asm:96-105) — not re-emitted: Route3CooltrainerF1BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route3Youngster3Text:
    mov esi, Route3TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

; Route3Youngster3BattleText (scripts/Route3.asm:114-123) — not re-emitted: Route3Youngster3BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route3CooltrainerF2Text:
    mov esi, Route3TrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

; Route3CooltrainerF2BattleText (scripts/Route3.asm:132-141) — not re-emitted: Route3CooltrainerF2BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route3Youngster4Text:
    mov esi, Route3TrainerHeader5
    call TalkToTrainer
    jmp TextScriptEnd

; Route3Youngster4BattleText (scripts/Route3.asm:150-159) — not re-emitted: Route3Youngster4BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route3Youngster5Text:
    mov esi, Route3TrainerHeader6
    call TalkToTrainer
    jmp TextScriptEnd

; Route3Youngster5BattleText (scripts/Route3.asm:168-177) — not re-emitted: Route3Youngster5BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route3CooltrainerF3Text:
    mov esi, Route3TrainerHeader7
    call TalkToTrainer
    jmp TextScriptEnd

; Route3CooltrainerF3BattleText (scripts/Route3.asm:186-199) — not re-emitted: Route3CooltrainerF3BattleText is already defined in assets/trainer_headers.inc.
