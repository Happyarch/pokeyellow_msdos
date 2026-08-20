; Route11.asm — translated from pret scripts/Route11.asm by dos_port/tools/sm83xlat.
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
extern Route11_ScriptPointers ; assets/map_script_tables.inc
; Trainer headers and battle text are DEFINED once, by the single carrier
; src/data/trainer_headers.asm. Declare what this script uses; do NOT %include
; assets/trainer_headers.inc here — the asset DEFINES all 1302 symbols, so an
; include makes every one of them a duplicate global the moment a second script
; links. (That is what kept 202 link-ready scripts out of the build.)
extern Route11Gambler1BattleText   ; assets/trainer_headers.inc
extern Route11Gambler2BattleText   ; assets/trainer_headers.inc
extern Route11Gambler3BattleText   ; assets/trainer_headers.inc
extern Route11Gambler4BattleText   ; assets/trainer_headers.inc
extern Route11SuperNerd1BattleText ; assets/trainer_headers.inc
extern Route11SuperNerd2BattleText ; assets/trainer_headers.inc
extern Route11TrainerHeader0       ; assets/trainer_headers.inc
extern Route11TrainerHeader1       ; assets/trainer_headers.inc
extern Route11TrainerHeader2       ; assets/trainer_headers.inc
extern Route11TrainerHeader3       ; assets/trainer_headers.inc
extern Route11TrainerHeader4       ; assets/trainer_headers.inc
extern Route11TrainerHeader5       ; assets/trainer_headers.inc
extern Route11TrainerHeader6       ; assets/trainer_headers.inc
extern Route11TrainerHeader7       ; assets/trainer_headers.inc
extern Route11TrainerHeader8       ; assets/trainer_headers.inc
extern Route11TrainerHeader9       ; assets/trainer_headers.inc
extern Route11TrainerHeaders       ; assets/trainer_headers.inc
extern Route11Youngster1BattleText ; assets/trainer_headers.inc
extern Route11Youngster2BattleText ; assets/trainer_headers.inc
extern Route11Youngster3BattleText ; assets/trainer_headers.inc
extern Route11Youngster4BattleText ; assets/trainer_headers.inc

global Route11Gambler1Text
global Route11Gambler2Text
global Route11Gambler3Text
global Route11Gambler4Text
global Route11SuperNerd1Text
global Route11SuperNerd2Text
global Route11Youngster1Text
global Route11Youngster2Text
global Route11Youngster3Text
global Route11Youngster4Text
global Route11_Script

extern EnableAutoTextBoxDrawing
extern ExecuteCurMapScriptInTable
extern Route11Gambler1BattleText
extern Route11Gambler2BattleText
extern Route11Gambler3BattleText
extern Route11Gambler4BattleText
extern Route11SuperNerd1BattleText
extern Route11SuperNerd2BattleText
extern Route11TrainerHeader0
extern Route11TrainerHeader1
extern Route11TrainerHeader2
extern Route11TrainerHeader3
extern Route11TrainerHeader4
extern Route11TrainerHeader5
extern Route11TrainerHeader6
extern Route11TrainerHeader7
extern Route11TrainerHeader8
extern Route11TrainerHeader9
extern Route11TrainerHeaders
extern Route11Youngster1BattleText
extern Route11Youngster2BattleText
extern Route11Youngster3BattleText
extern Route11Youngster4BattleText
extern Route11_ScriptPointers
extern TalkToTrainer
extern TextScriptEnd

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
Route11_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route11TrainerHeaders
    mov edi, Route11_ScriptPointers   ; pret: ld de, Route11_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRoute11CurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRoute11CurScript], al
    ret

; Route11_ScriptPointers (scripts/Route11.asm:11-52) — not re-emitted: Route11_ScriptPointers is already defined in assets/map_script_tables.inc.

%assign event_byte -1
%assign event_byte_a -1
Route11Gambler1Text:
    mov esi, Route11TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; Route11Gambler1BattleText (scripts/Route11.asm:61-70) — not re-emitted: Route11Gambler1BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route11Gambler2Text:
    mov esi, Route11TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; Route11Gambler2BattleText (scripts/Route11.asm:79-88) — not re-emitted: Route11Gambler2BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route11Youngster1Text:
    mov esi, Route11TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; Route11Youngster1BattleText (scripts/Route11.asm:97-106) — not re-emitted: Route11Youngster1BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route11SuperNerd1Text:
    mov esi, Route11TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

; Route11SuperNerd1BattleText (scripts/Route11.asm:115-124) — not re-emitted: Route11SuperNerd1BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route11Youngster2Text:
    mov esi, Route11TrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

; Route11Youngster2BattleText (scripts/Route11.asm:133-142) — not re-emitted: Route11Youngster2BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route11Gambler3Text:
    mov esi, Route11TrainerHeader5
    call TalkToTrainer
    jmp TextScriptEnd

; Route11Gambler3BattleText (scripts/Route11.asm:151-160) — not re-emitted: Route11Gambler3BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route11Gambler4Text:
    mov esi, Route11TrainerHeader6
    call TalkToTrainer
    jmp TextScriptEnd

; Route11Gambler4BattleText (scripts/Route11.asm:169-178) — not re-emitted: Route11Gambler4BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route11Youngster3Text:
    mov esi, Route11TrainerHeader7
    call TalkToTrainer
    jmp TextScriptEnd

; Route11Youngster3BattleText (scripts/Route11.asm:187-196) — not re-emitted: Route11Youngster3BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route11SuperNerd2Text:
    mov esi, Route11TrainerHeader8
    call TalkToTrainer
    jmp TextScriptEnd

; Route11SuperNerd2BattleText (scripts/Route11.asm:205-214) — not re-emitted: Route11SuperNerd2BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route11Youngster4Text:
    mov esi, Route11TrainerHeader9
    call TalkToTrainer
    jmp TextScriptEnd

; Route11Youngster4BattleText (scripts/Route11.asm:223-236) — not re-emitted: Route11Youngster4BattleText is already defined in assets/trainer_headers.inc.
