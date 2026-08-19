; Route6.asm — translated from pret scripts/Route6.asm by dos_port/tools/sm83xlat.
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
extern Route6_ScriptPointers ; assets/map_script_tables.inc
; Trainer headers and battle text are DEFINED once, by the single carrier
; src/data/trainer_headers.asm. Declare what this script uses; do NOT %include
; assets/trainer_headers.inc here — the asset DEFINES all 1302 symbols, so an
; include makes every one of them a duplicate global the moment a second script
; links. (That is what kept 202 link-ready scripts out of the build.)
extern Route6CooltrainerF1BattleText ; assets/trainer_headers.inc
extern Route6CooltrainerF2BattleText ; assets/trainer_headers.inc
extern Route6CooltrainerM1BattleText ; assets/trainer_headers.inc
extern Route6CooltrainerM2BattleText ; assets/trainer_headers.inc
extern Route6TrainerHeader0          ; assets/trainer_headers.inc
extern Route6TrainerHeader1          ; assets/trainer_headers.inc
extern Route6TrainerHeader2          ; assets/trainer_headers.inc
extern Route6TrainerHeader3          ; assets/trainer_headers.inc
extern Route6TrainerHeader4          ; assets/trainer_headers.inc
extern Route6TrainerHeader5          ; assets/trainer_headers.inc
extern Route6TrainerHeaders          ; assets/trainer_headers.inc
extern Route6Youngster1BattleText    ; assets/trainer_headers.inc
extern Route6Youngster2BattleText    ; assets/trainer_headers.inc

global Route6CooltrainerF1Text
global Route6CooltrainerF2Text
global Route6CooltrainerM1Text
global Route6CooltrainerM2Text
global Route6Youngster1Text
global Route6Youngster2Text
global Route6_Script

extern EnableAutoTextBoxDrawing
extern ExecuteCurMapScriptInTable
extern Route6CooltrainerF1BattleText
extern Route6CooltrainerF2BattleText
extern Route6CooltrainerM1BattleText
extern Route6CooltrainerM2BattleText
extern Route6TrainerHeader0
extern Route6TrainerHeader1
extern Route6TrainerHeader2
extern Route6TrainerHeader3
extern Route6TrainerHeader4
extern Route6TrainerHeader5
extern Route6TrainerHeaders
extern Route6Youngster1BattleText
extern Route6Youngster2BattleText
extern Route6_ScriptPointers
extern TalkToTrainer
extern TextScriptEnd

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
Route6_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route6TrainerHeaders
    mov edi, Route6_ScriptPointers   ; pret: ld de, Route6_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRoute6CurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRoute6CurScript], al
    ret

; Route6_ScriptPointers (scripts/Route6.asm:11-40) — not re-emitted: Route6_ScriptPointers is already defined in assets/map_script_tables.inc.

%assign event_byte -1
%assign event_byte_a -1
Route6CooltrainerM1Text:
    mov esi, Route6TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; Route6CooltrainerM1BattleText (scripts/Route6.asm:49-58) — not re-emitted: Route6CooltrainerM1BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route6CooltrainerF1Text:
    mov esi, Route6TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; Route6CooltrainerF1BattleText (scripts/Route6.asm:67-76) — not re-emitted: Route6CooltrainerF1BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route6Youngster1Text:
    mov esi, Route6TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; Route6Youngster1BattleText (scripts/Route6.asm:85-94) — not re-emitted: Route6Youngster1BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route6CooltrainerM2Text:
    mov esi, Route6TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

; Route6CooltrainerM2BattleText (scripts/Route6.asm:103-112) — not re-emitted: Route6CooltrainerM2BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route6CooltrainerF2Text:
    mov esi, Route6TrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

; Route6CooltrainerF2BattleText (scripts/Route6.asm:121-130) — not re-emitted: Route6CooltrainerF2BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route6Youngster2Text:
    mov esi, Route6TrainerHeader5
    call TalkToTrainer
    jmp TextScriptEnd

; Route6Youngster2BattleText (scripts/Route6.asm:139-152) — not re-emitted: Route6Youngster2BattleText is already defined in assets/trainer_headers.inc.
