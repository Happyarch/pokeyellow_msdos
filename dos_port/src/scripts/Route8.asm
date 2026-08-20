; Route8.asm — translated from pret scripts/Route8.asm by dos_port/tools/sm83xlat.
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
extern Route8_ScriptPointers ; assets/map_script_tables.inc
; Trainer headers and battle text are DEFINED once, by the single carrier
; src/data/trainer_headers.asm. Declare what this script uses; do NOT %include
; assets/trainer_headers.inc here — the asset DEFINES all 1302 symbols, so an
; include makes every one of them a duplicate global the moment a second script
; links. (That is what kept 202 link-ready scripts out of the build.)
extern Route8CooltrainerF1BattleText ; assets/trainer_headers.inc
extern Route8CooltrainerF2BattleText ; assets/trainer_headers.inc
extern Route8CooltrainerF3BattleText ; assets/trainer_headers.inc
extern Route8CooltrainerF4BattleText ; assets/trainer_headers.inc
extern Route8Gambler1BattleText      ; assets/trainer_headers.inc
extern Route8Gambler2BattleText      ; assets/trainer_headers.inc
extern Route8SuperNerd1BattleText    ; assets/trainer_headers.inc
extern Route8SuperNerd2BattleText    ; assets/trainer_headers.inc
extern Route8SuperNerd3BattleText    ; assets/trainer_headers.inc
extern Route8TrainerHeader0          ; assets/trainer_headers.inc
extern Route8TrainerHeader1          ; assets/trainer_headers.inc
extern Route8TrainerHeader2          ; assets/trainer_headers.inc
extern Route8TrainerHeader3          ; assets/trainer_headers.inc
extern Route8TrainerHeader4          ; assets/trainer_headers.inc
extern Route8TrainerHeader5          ; assets/trainer_headers.inc
extern Route8TrainerHeader6          ; assets/trainer_headers.inc
extern Route8TrainerHeader7          ; assets/trainer_headers.inc
extern Route8TrainerHeader8          ; assets/trainer_headers.inc
extern Route8TrainerHeaders          ; assets/trainer_headers.inc

global Route8CooltrainerF1Text
global Route8CooltrainerF2Text
global Route8CooltrainerF3Text
global Route8CooltrainerF4Text
global Route8Gambler1Text
global Route8Gambler2Text
global Route8SuperNerd1Text
global Route8SuperNerd2Text
global Route8SuperNerd3Text
global Route8_Script

extern EnableAutoTextBoxDrawing
extern ExecuteCurMapScriptInTable
extern Route8CooltrainerF1BattleText
extern Route8CooltrainerF2BattleText
extern Route8CooltrainerF3BattleText
extern Route8CooltrainerF4BattleText
extern Route8Gambler1BattleText
extern Route8Gambler2BattleText
extern Route8SuperNerd1BattleText
extern Route8SuperNerd2BattleText
extern Route8SuperNerd3BattleText
extern Route8TrainerHeader0
extern Route8TrainerHeader1
extern Route8TrainerHeader2
extern Route8TrainerHeader3
extern Route8TrainerHeader4
extern Route8TrainerHeader5
extern Route8TrainerHeader6
extern Route8TrainerHeader7
extern Route8TrainerHeader8
extern Route8TrainerHeaders
extern Route8_ScriptPointers
extern TalkToTrainer
extern TextScriptEnd

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
Route8_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route8TrainerHeaders
    mov edi, Route8_ScriptPointers   ; pret: ld de, Route8_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRoute8CurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRoute8CurScript], al
    ret

; Route8_ScriptPointers (scripts/Route8.asm:11-49) — not re-emitted: Route8_ScriptPointers is already defined in assets/map_script_tables.inc.

%assign event_byte -1
%assign event_byte_a -1
Route8SuperNerd1Text:
    mov esi, Route8TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; Route8SuperNerd1BattleText (scripts/Route8.asm:58-67) — not re-emitted: Route8SuperNerd1BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route8Gambler1Text:
    mov esi, Route8TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; Route8Gambler1BattleText (scripts/Route8.asm:76-85) — not re-emitted: Route8Gambler1BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route8SuperNerd2Text:
    mov esi, Route8TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; Route8SuperNerd2BattleText (scripts/Route8.asm:94-103) — not re-emitted: Route8SuperNerd2BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route8CooltrainerF1Text:
    mov esi, Route8TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

; Route8CooltrainerF1BattleText (scripts/Route8.asm:112-121) — not re-emitted: Route8CooltrainerF1BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route8SuperNerd3Text:
    mov esi, Route8TrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

; Route8SuperNerd3BattleText (scripts/Route8.asm:130-139) — not re-emitted: Route8SuperNerd3BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route8CooltrainerF2Text:
    mov esi, Route8TrainerHeader5
    call TalkToTrainer
    jmp TextScriptEnd

; Route8CooltrainerF2BattleText (scripts/Route8.asm:148-157) — not re-emitted: Route8CooltrainerF2BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route8CooltrainerF3Text:
    mov esi, Route8TrainerHeader6
    call TalkToTrainer
    jmp TextScriptEnd

; Route8CooltrainerF3BattleText (scripts/Route8.asm:166-175) — not re-emitted: Route8CooltrainerF3BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route8Gambler2Text:
    mov esi, Route8TrainerHeader7
    call TalkToTrainer
    jmp TextScriptEnd

; Route8Gambler2BattleText (scripts/Route8.asm:184-193) — not re-emitted: Route8Gambler2BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route8CooltrainerF4Text:
    mov esi, Route8TrainerHeader8
    call TalkToTrainer
    jmp TextScriptEnd

; Route8CooltrainerF4BattleText (scripts/Route8.asm:202-215) — not re-emitted: Route8CooltrainerF4BattleText is already defined in assets/trainer_headers.inc.
