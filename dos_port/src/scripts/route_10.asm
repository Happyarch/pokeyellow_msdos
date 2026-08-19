; Route10.asm — translated from pret scripts/Route10.asm by dos_port/tools/sm83xlat.
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
extern Route10_ScriptPointers ; assets/map_script_tables.inc
; Trainer headers and battle text are DEFINED once, by the single carrier
; src/data/trainer_headers.asm. Declare what this script uses; do NOT %include
; assets/trainer_headers.inc here — the asset DEFINES all 1302 symbols, so an
; include makes every one of them a duplicate global the moment a second script
; links. (That is what kept 202 link-ready scripts out of the build.)
extern Route10CooltrainerF1BattleText ; assets/trainer_headers.inc
extern Route10CooltrainerF2BattleText ; assets/trainer_headers.inc
extern Route10Hiker1BattleText        ; assets/trainer_headers.inc
extern Route10Hiker2BattleText        ; assets/trainer_headers.inc
extern Route10SuperNerd1BattleText    ; assets/trainer_headers.inc
extern Route10SuperNerd2BattleText    ; assets/trainer_headers.inc
extern Route10TrainerHeader0          ; assets/trainer_headers.inc
extern Route10TrainerHeader1          ; assets/trainer_headers.inc
extern Route10TrainerHeader2          ; assets/trainer_headers.inc
extern Route10TrainerHeader3          ; assets/trainer_headers.inc
extern Route10TrainerHeader4          ; assets/trainer_headers.inc
extern Route10TrainerHeader5          ; assets/trainer_headers.inc
extern Route10TrainerHeaders          ; assets/trainer_headers.inc

global Route10CooltrainerF1Text
global Route10CooltrainerF2Text
global Route10Hiker1Text
global Route10Hiker2Text
global Route10SuperNerd1Text
global Route10SuperNerd2Text
global Route10_Script

extern EnableAutoTextBoxDrawing
extern ExecuteCurMapScriptInTable
extern Route10CooltrainerF1BattleText
extern Route10CooltrainerF2BattleText
extern Route10Hiker1BattleText
extern Route10Hiker2BattleText
extern Route10SuperNerd1BattleText
extern Route10SuperNerd2BattleText
extern Route10TrainerHeader0
extern Route10TrainerHeader1
extern Route10TrainerHeader2
extern Route10TrainerHeader3
extern Route10TrainerHeader4
extern Route10TrainerHeader5
extern Route10TrainerHeaders
extern Route10_ScriptPointers
extern TalkToTrainer
extern TextScriptEnd

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
Route10_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route10TrainerHeaders
    mov edi, Route10_ScriptPointers   ; pret: ld de, Route10_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRoute10CurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRoute10CurScript], al
    ret

; Route10_ScriptPointers (scripts/Route10.asm:11-43) — not re-emitted: Route10_ScriptPointers is already defined in assets/map_script_tables.inc.

%assign event_byte -1
%assign event_byte_a -1
Route10SuperNerd1Text:
    mov esi, Route10TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; Route10SuperNerd1BattleText (scripts/Route10.asm:52-61) — not re-emitted: Route10SuperNerd1BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route10Hiker1Text:
    mov esi, Route10TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; Route10Hiker1BattleText (scripts/Route10.asm:70-79) — not re-emitted: Route10Hiker1BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route10SuperNerd2Text:
    mov esi, Route10TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; Route10SuperNerd2BattleText (scripts/Route10.asm:88-97) — not re-emitted: Route10SuperNerd2BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route10CooltrainerF1Text:
    mov esi, Route10TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

; Route10CooltrainerF1BattleText (scripts/Route10.asm:106-115) — not re-emitted: Route10CooltrainerF1BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route10Hiker2Text:
    mov esi, Route10TrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

; Route10Hiker2BattleText (scripts/Route10.asm:124-133) — not re-emitted: Route10Hiker2BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route10CooltrainerF2Text:
    mov esi, Route10TrainerHeader5
    call TalkToTrainer
    jmp TextScriptEnd

; Route10CooltrainerF2BattleText (scripts/Route10.asm:142-159) — not re-emitted: Route10CooltrainerF2BattleText is already defined in assets/trainer_headers.inc.
