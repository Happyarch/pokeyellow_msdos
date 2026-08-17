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

extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern Route19CooltrainerM1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route19CooltrainerM1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route19CooltrainerM1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route19CooltrainerM2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route19CooltrainerM2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route19CooltrainerM2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route19SignText   ; NOT YET DEFINED IN THE PORT
extern Route19Swimmer1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route19Swimmer1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route19Swimmer1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route19Swimmer2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route19Swimmer2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route19Swimmer2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route19Swimmer3AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route19Swimmer3BattleText   ; NOT YET DEFINED IN THE PORT
extern Route19Swimmer3EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route19Swimmer4AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route19Swimmer4BattleText   ; NOT YET DEFINED IN THE PORT
extern Route19Swimmer4EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route19Swimmer5AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route19Swimmer5BattleText   ; NOT YET DEFINED IN THE PORT
extern Route19Swimmer5EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route19Swimmer6AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route19Swimmer6BattleText   ; NOT YET DEFINED IN THE PORT
extern Route19Swimmer6EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route19Swimmer7AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route19Swimmer7BattleText   ; NOT YET DEFINED IN THE PORT
extern Route19Swimmer7EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route19Swimmer8AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route19Swimmer8BattleText   ; NOT YET DEFINED IN THE PORT
extern Route19Swimmer8EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route19TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern Route19TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern Route19TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern Route19TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern Route19TrainerHeader4   ; NOT YET DEFINED IN THE PORT
extern Route19TrainerHeader5   ; NOT YET DEFINED IN THE PORT
extern Route19TrainerHeader6   ; NOT YET DEFINED IN THE PORT
extern Route19TrainerHeader7   ; NOT YET DEFINED IN THE PORT
extern Route19TrainerHeader8   ; NOT YET DEFINED IN THE PORT
extern Route19TrainerHeader9   ; NOT YET DEFINED IN THE PORT
extern Route19TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern Route19_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern Route19_TextPointers   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_ROUTE19_DEFAULT                         equ 0
SCRIPT_ROUTE19_START_BATTLE                    equ 1
SCRIPT_ROUTE19_END_BATTLE                      equ 2
TEXT_ROUTE19_COOLTRAINER_M1                    equ 1
TEXT_ROUTE19_COOLTRAINER_M2                    equ 2
TEXT_ROUTE19_SWIMMER1                          equ 3
TEXT_ROUTE19_SWIMMER2                          equ 4
TEXT_ROUTE19_SWIMMER3                          equ 5
TEXT_ROUTE19_SWIMMER4                          equ 6
TEXT_ROUTE19_SWIMMER5                          equ 7
TEXT_ROUTE19_SWIMMER6                          equ 8
TEXT_ROUTE19_SWIMMER7                          equ 9
TEXT_ROUTE19_SWIMMER8                          equ 10
TEXT_ROUTE19_SIGN                              equ 11

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wRoute19CurScript                              equ 0xD61C

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

Route19_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route19TrainerHeaders
    mov edi, Route19_ScriptPointers   ; pret: ld de, Route19_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRoute19CurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRoute19CurScript], al
    ret

; ---------------------------------------------------------------------------
; Route19_ScriptPointers (scripts/Route19.asm:11-52) — Tier-1 data: Route19_ScriptPointers is generated into assets/map_script_tables.inc.

Route19CooltrainerM1Text:
    mov esi, Route19TrainerHeader0
    jmp Route19_TalkToTrainer

Route19CooltrainerM2Text:
    mov esi, Route19TrainerHeader1
    jmp Route19_TalkToTrainer

Route19Swimmer1Text:
    mov esi, Route19TrainerHeader2
    jmp Route19_TalkToTrainer

Route19Swimmer2Text:
    mov esi, Route19TrainerHeader3
    jmp Route19_TalkToTrainer

Route19Swimmer3Text:
    mov esi, Route19TrainerHeader4
    jmp Route19_TalkToTrainer

Route19Swimmer4Text:
    mov esi, Route19TrainerHeader5
    jmp Route19_TalkToTrainer

Route19Swimmer5Text:
    mov esi, Route19TrainerHeader6
    jmp Route19_TalkToTrainer

Route19Swimmer6Text:
    mov esi, Route19TrainerHeader7
    jmp Route19_TalkToTrainer

Route19Swimmer7Text:
    mov esi, Route19TrainerHeader8
    jmp Route19_TalkToTrainer

Route19Swimmer8Text:
    mov esi, Route19TrainerHeader9
Route19_TalkToTrainer:
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route19CooltrainerM1BattleText (scripts/Route19.asm:107-228) — Tier-1 data: Route19CooltrainerM1BattleText is generated into assets/trainer_headers.inc.
