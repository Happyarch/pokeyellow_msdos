; Route21.asm — translated from pret scripts/Route21.asm by dos_port/tools/sm83xlat.
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


global Route21Fisher1Text
global Route21Fisher2Text
global Route21Fisher3Text
global Route21Fisher4Text
global Route21Swimmer1Text
global Route21Swimmer2Text
global Route21Swimmer3Text
global Route21Swimmer4Text
global Route21Swimmer5Text
global Route21_Script

extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern Route21Fisher1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Fisher1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Fisher1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Fisher2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Fisher2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Fisher2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Fisher3AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Fisher3BattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Fisher3EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Fisher4AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Fisher4BattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Fisher4EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Swimmer1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Swimmer1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Swimmer1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Swimmer2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Swimmer2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Swimmer2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Swimmer3AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Swimmer3BattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Swimmer3EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Swimmer4AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Swimmer4BattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Swimmer4EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Swimmer5AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Swimmer5BattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Swimmer5EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route21TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern Route21TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern Route21TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern Route21TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern Route21TrainerHeader4   ; NOT YET DEFINED IN THE PORT
extern Route21TrainerHeader5   ; NOT YET DEFINED IN THE PORT
extern Route21TrainerHeader6   ; NOT YET DEFINED IN THE PORT
extern Route21TrainerHeader7   ; NOT YET DEFINED IN THE PORT
extern Route21TrainerHeader8   ; NOT YET DEFINED IN THE PORT
extern Route21TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern Route21_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern Route21_TextPointers   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_ROUTE21_DEFAULT                         equ 0
SCRIPT_ROUTE21_START_BATTLE                    equ 1
SCRIPT_ROUTE21_END_BATTLE                      equ 2
TEXT_ROUTE21_FISHER1                           equ 1
TEXT_ROUTE21_FISHER2                           equ 2
TEXT_ROUTE21_SWIMMER1                          equ 3
TEXT_ROUTE21_SWIMMER2                          equ 4
TEXT_ROUTE21_SWIMMER3                          equ 5
TEXT_ROUTE21_SWIMMER4                          equ 6
TEXT_ROUTE21_SWIMMER5                          equ 7
TEXT_ROUTE21_FISHER3                           equ 8
TEXT_ROUTE21_FISHER4                           equ 9

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wRoute21CurScript                              equ 0xD61D

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

Route21_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route21TrainerHeaders
    mov edi, Route21_ScriptPointers   ; pret: ld de, Route21_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRoute21CurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRoute21CurScript], al
    ret

; ---------------------------------------------------------------------------
; Route21_ScriptPointers (scripts/Route21.asm:11-48) — Tier-1 data: Route21_ScriptPointers is generated into assets/map_script_tables.inc.

Route21Fisher1Text:
    mov esi, Route21TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

Route21Fisher2Text:
    mov esi, Route21TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

Route21Swimmer1Text:
    mov esi, Route21TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

Route21Swimmer2Text:
    mov esi, Route21TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

Route21Swimmer3Text:
    mov esi, Route21TrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

Route21Swimmer4Text:
    mov esi, Route21TrainerHeader5
    call TalkToTrainer
    jmp TextScriptEnd

Route21Swimmer5Text:
    mov esi, Route21TrainerHeader6
    call TalkToTrainer
    jmp TextScriptEnd

Route21Fisher3Text:
    mov esi, Route21TrainerHeader7
    call TalkToTrainer
    jmp TextScriptEnd

Route21Fisher4Text:
    mov esi, Route21TrainerHeader8
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route21Fisher1BattleText (scripts/Route21.asm:105-210) — Tier-1 data: Route21Fisher1BattleText is generated into assets/trainer_headers.inc.
