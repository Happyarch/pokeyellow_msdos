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

extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern PickUpItemText   ; NOT YET DEFINED IN THE PORT
extern Route15Beauty1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route15Beauty1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route15Beauty1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route15Beauty2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route15Beauty2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route15Beauty2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route15Biker1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route15Biker1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route15Biker1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route15Biker2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route15Biker2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route15Biker2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route15CooltrainerF1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route15CooltrainerF1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route15CooltrainerF1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route15CooltrainerF2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route15CooltrainerF2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route15CooltrainerF2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route15CooltrainerF3AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route15CooltrainerF3BattleText   ; NOT YET DEFINED IN THE PORT
extern Route15CooltrainerF3EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route15CooltrainerF4AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route15CooltrainerF4BattleText   ; NOT YET DEFINED IN THE PORT
extern Route15CooltrainerF4EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route15CooltrainerM1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route15CooltrainerM1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route15CooltrainerM1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route15CooltrainerM2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route15CooltrainerM2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route15CooltrainerM2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route15SignText   ; NOT YET DEFINED IN THE PORT
extern Route15TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern Route15TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern Route15TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern Route15TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern Route15TrainerHeader4   ; NOT YET DEFINED IN THE PORT
extern Route15TrainerHeader5   ; NOT YET DEFINED IN THE PORT
extern Route15TrainerHeader6   ; NOT YET DEFINED IN THE PORT
extern Route15TrainerHeader7   ; NOT YET DEFINED IN THE PORT
extern Route15TrainerHeader8   ; NOT YET DEFINED IN THE PORT
extern Route15TrainerHeader9   ; NOT YET DEFINED IN THE PORT
extern Route15TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern Route15_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern Route15_TextPointers   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_ROUTE15_DEFAULT                         equ 0
SCRIPT_ROUTE15_START_BATTLE                    equ 1
SCRIPT_ROUTE15_END_BATTLE                      equ 2
TEXT_ROUTE15_COOLTRAINER_F1                    equ 1
TEXT_ROUTE15_COOLTRAINER_F2                    equ 2
TEXT_ROUTE15_COOLTRAINER_M1                    equ 3
TEXT_ROUTE15_COOLTRAINER_M2                    equ 4
TEXT_ROUTE15_BEAUTY1                           equ 5
TEXT_ROUTE15_BEAUTY2                           equ 6
TEXT_ROUTE15_BIKER1                            equ 7
TEXT_ROUTE15_BIKER2                            equ 8
TEXT_ROUTE15_COOLTRAINER_F3                    equ 9
TEXT_ROUTE15_COOLTRAINER_F4                    equ 10
TEXT_ROUTE15_TM_RAGE                           equ 11
TEXT_ROUTE15_SIGN                              equ 12

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wRoute15CurScript                              equ 0xD624

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

Route15_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route15TrainerHeaders
    mov edi, Route15_ScriptPointers   ; pret: ld de, Route15_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRoute15CurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRoute15CurScript], al
    ret

; ---------------------------------------------------------------------------
; Route15_ScriptPointers (scripts/Route15.asm:11-53) — Tier-1 data: Route15_ScriptPointers is generated into assets/map_script_tables.inc.

Route15CooltrainerF1Text:
    mov esi, Route15TrainerHeader0
    jmp Route15TalkToTrainer

Route15CooltrainerF2Text:
    mov esi, Route15TrainerHeader1
    jmp Route15TalkToTrainer

Route15CooltrainerM1Text:
    mov esi, Route15TrainerHeader2
    jmp Route15TalkToTrainer

Route15CooltrainerM2Text:
    mov esi, Route15TrainerHeader3
    jmp Route15TalkToTrainer

Route15Beauty1Text:
    mov esi, Route15TrainerHeader4
    jmp Route15TalkToTrainer

Route15Beauty2Text:
    mov esi, Route15TrainerHeader5
    jmp Route15TalkToTrainer

Route15Biker1Text:
    mov esi, Route15TrainerHeader6
    jmp Route15TalkToTrainer

Route15Biker2Text:
    mov esi, Route15TrainerHeader7
    jmp Route15TalkToTrainer

Route15CooltrainerF3Text:
    mov esi, Route15TrainerHeader8
    jmp Route15TalkToTrainer

Route15CooltrainerF4Text:
    mov esi, Route15TrainerHeader9
Route15TalkToTrainer:
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route15CooltrainerF1BattleText (scripts/Route15.asm:108-229) — Tier-1 data: Route15CooltrainerF1BattleText is generated into assets/trainer_headers.inc.
