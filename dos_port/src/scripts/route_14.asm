; Route14.asm — translated from pret scripts/Route14.asm by dos_port/tools/sm83xlat.
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
extern Route14_ScriptPointers ; assets/map_script_tables.inc
; Trainer headers and battle text are DEFINED once, by the single carrier
; src/data/trainer_headers.asm. Declare what this script uses; do NOT %include
; assets/trainer_headers.inc here — the asset DEFINES all 1302 symbols, so an
; include makes every one of them a duplicate global the moment a second script
; links. (That is what kept 202 link-ready scripts out of the build.)
extern Route14Biker1BattleText        ; assets/trainer_headers.inc
extern Route14Biker2BattleText        ; assets/trainer_headers.inc
extern Route14Biker3BattleText        ; assets/trainer_headers.inc
extern Route14Biker4BattleText        ; assets/trainer_headers.inc
extern Route14CooltrainerM1BattleText ; assets/trainer_headers.inc
extern Route14CooltrainerM2BattleText ; assets/trainer_headers.inc
extern Route14CooltrainerM3BattleText ; assets/trainer_headers.inc
extern Route14CooltrainerM4BattleText ; assets/trainer_headers.inc
extern Route14CooltrainerM5BattleText ; assets/trainer_headers.inc
extern Route14CooltrainerM6BattleText ; assets/trainer_headers.inc
extern Route14TrainerHeader0          ; assets/trainer_headers.inc
extern Route14TrainerHeader1          ; assets/trainer_headers.inc
extern Route14TrainerHeader2          ; assets/trainer_headers.inc
extern Route14TrainerHeader3          ; assets/trainer_headers.inc
extern Route14TrainerHeader4          ; assets/trainer_headers.inc
extern Route14TrainerHeader5          ; assets/trainer_headers.inc
extern Route14TrainerHeader6          ; assets/trainer_headers.inc
extern Route14TrainerHeader7          ; assets/trainer_headers.inc
extern Route14TrainerHeader8          ; assets/trainer_headers.inc
extern Route14TrainerHeader9          ; assets/trainer_headers.inc
extern Route14TrainerHeaders          ; assets/trainer_headers.inc

global Route14Biker1Text
global Route14Biker2Text
global Route14Biker3Text
global Route14Biker4Text
global Route14CooltrainerM1Text
global Route14CooltrainerM2Text
global Route14CooltrainerM3Text
global Route14CooltrainerM4Text
global Route14CooltrainerM5Text
global Route14CooltrainerM6Text
global Route14_Script

extern EnableAutoTextBoxDrawing
extern ExecuteCurMapScriptInTable
extern Route14Biker1BattleText
extern Route14Biker2BattleText
extern Route14Biker3BattleText
extern Route14Biker4BattleText
extern Route14CooltrainerM1BattleText
extern Route14CooltrainerM2BattleText
extern Route14CooltrainerM3BattleText
extern Route14CooltrainerM4BattleText
extern Route14CooltrainerM5BattleText
extern Route14CooltrainerM6BattleText
extern Route14TrainerHeader0
extern Route14TrainerHeader1
extern Route14TrainerHeader2
extern Route14TrainerHeader3
extern Route14TrainerHeader4
extern Route14TrainerHeader5
extern Route14TrainerHeader6
extern Route14TrainerHeader7
extern Route14TrainerHeader8
extern Route14TrainerHeader9
extern Route14TrainerHeaders
extern Route14_ScriptPointers
extern TalkToTrainer
extern TextScriptEnd

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
Route14_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route14TrainerHeaders
    mov edi, Route14_ScriptPointers   ; pret: ld de, Route14_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRoute14CurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRoute14CurScript], al
    ret

; Route14_ScriptPointers (scripts/Route14.asm:11-52) — not re-emitted: Route14_ScriptPointers is already defined in assets/map_script_tables.inc.

%assign event_byte -1
%assign event_byte_a -1
Route14CooltrainerM1Text:
    mov esi, Route14TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; Route14CooltrainerM1BattleText (scripts/Route14.asm:61-70) — not re-emitted: Route14CooltrainerM1BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route14CooltrainerM2Text:
    mov esi, Route14TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; Route14CooltrainerM2BattleText (scripts/Route14.asm:79-88) — not re-emitted: Route14CooltrainerM2BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route14CooltrainerM3Text:
    mov esi, Route14TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; Route14CooltrainerM3BattleText (scripts/Route14.asm:97-106) — not re-emitted: Route14CooltrainerM3BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route14CooltrainerM4Text:
    mov esi, Route14TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

; Route14CooltrainerM4BattleText (scripts/Route14.asm:115-124) — not re-emitted: Route14CooltrainerM4BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route14CooltrainerM5Text:
    mov esi, Route14TrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

; Route14CooltrainerM5BattleText (scripts/Route14.asm:133-142) — not re-emitted: Route14CooltrainerM5BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route14CooltrainerM6Text:
    mov esi, Route14TrainerHeader5
    call TalkToTrainer
    jmp TextScriptEnd

; Route14CooltrainerM6BattleText (scripts/Route14.asm:151-160) — not re-emitted: Route14CooltrainerM6BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route14Biker1Text:
    mov esi, Route14TrainerHeader6
    call TalkToTrainer
    jmp TextScriptEnd

; Route14Biker1BattleText (scripts/Route14.asm:169-178) — not re-emitted: Route14Biker1BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route14Biker2Text:
    mov esi, Route14TrainerHeader7
    call TalkToTrainer
    jmp TextScriptEnd

; Route14Biker2BattleText (scripts/Route14.asm:187-196) — not re-emitted: Route14Biker2BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route14Biker3Text:
    mov esi, Route14TrainerHeader8
    call TalkToTrainer
    jmp TextScriptEnd

; Route14Biker3BattleText (scripts/Route14.asm:205-214) — not re-emitted: Route14Biker3BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route14Biker4Text:
    mov esi, Route14TrainerHeader9
    call TalkToTrainer
    jmp TextScriptEnd

; Route14Biker4BattleText (scripts/Route14.asm:223-236) — not re-emitted: Route14Biker4BattleText is already defined in assets/trainer_headers.inc.
