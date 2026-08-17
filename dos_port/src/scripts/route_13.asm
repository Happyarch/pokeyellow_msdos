; Route13.asm — translated from pret scripts/Route13.asm by dos_port/tools/sm83xlat.
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


global Route13Beauty1Text
global Route13Beauty2Text
global Route13BikerText
global Route13CooltrainerF1Text
global Route13CooltrainerF2Text
global Route13CooltrainerF3Text
global Route13CooltrainerF4Text
global Route13CooltrainerM1Text
global Route13CooltrainerM2Text
global Route13CooltrainerM3Text
global Route13_Script

extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern Route13Beauty1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route13Beauty1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route13Beauty1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route13Beauty2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route13Beauty2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route13Beauty2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route13BikerAfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route13BikerBattleText   ; NOT YET DEFINED IN THE PORT
extern Route13BikerEndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route13CooltrainerF1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route13CooltrainerF1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route13CooltrainerF1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route13CooltrainerF2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route13CooltrainerF2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route13CooltrainerF2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route13CooltrainerF3AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route13CooltrainerF3BattleText   ; NOT YET DEFINED IN THE PORT
extern Route13CooltrainerF3EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route13CooltrainerF4AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route13CooltrainerF4BattleText   ; NOT YET DEFINED IN THE PORT
extern Route13CooltrainerF4EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route13CooltrainerM1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route13CooltrainerM1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route13CooltrainerM1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route13CooltrainerM2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route13CooltrainerM2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route13CooltrainerM2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route13CooltrainerM3AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route13CooltrainerM3BattleText   ; NOT YET DEFINED IN THE PORT
extern Route13CooltrainerM3EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route13SignText   ; NOT YET DEFINED IN THE PORT
extern Route13TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern Route13TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern Route13TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern Route13TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern Route13TrainerHeader4   ; NOT YET DEFINED IN THE PORT
extern Route13TrainerHeader5   ; NOT YET DEFINED IN THE PORT
extern Route13TrainerHeader6   ; NOT YET DEFINED IN THE PORT
extern Route13TrainerHeader7   ; NOT YET DEFINED IN THE PORT
extern Route13TrainerHeader8   ; NOT YET DEFINED IN THE PORT
extern Route13TrainerHeader9   ; NOT YET DEFINED IN THE PORT
extern Route13TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern Route13TrainerTips1Text   ; NOT YET DEFINED IN THE PORT
extern Route13TrainerTips2Text   ; NOT YET DEFINED IN THE PORT
extern Route13_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern Route13_TextPointers   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_ROUTE13_DEFAULT                         equ 0
SCRIPT_ROUTE13_START_BATTLE                    equ 1
SCRIPT_ROUTE13_END_BATTLE                      equ 2
TEXT_ROUTE13_COOLTRAINER_M1                    equ 1
TEXT_ROUTE13_COOLTRAINER_F1                    equ 2
TEXT_ROUTE13_COOLTRAINER_F2                    equ 3
TEXT_ROUTE13_COOLTRAINER_F3                    equ 4
TEXT_ROUTE13_COOLTRAINER_F4                    equ 5
TEXT_ROUTE13_COOLTRAINER_M2                    equ 6
TEXT_ROUTE13_BEAUTY1                           equ 7
TEXT_ROUTE13_BEAUTY2                           equ 8
TEXT_ROUTE13_BIKER                             equ 9
TEXT_ROUTE13_COOLTRAINER_M3                    equ 10
TEXT_ROUTE13_TRAINER_TIPS1                     equ 11
TEXT_ROUTE13_TRAINER_TIPS2                     equ 12
TEXT_ROUTE13_SIGN                              equ 13

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wRoute13CurScript                              equ 0xD619

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

Route13_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route13TrainerHeaders
    mov edi, Route13_ScriptPointers   ; pret: ld de, Route13_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRoute13CurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRoute13CurScript], al
    ret

; ---------------------------------------------------------------------------
; Route13_ScriptPointers (scripts/Route13.asm:11-54) — Tier-1 data: Route13_ScriptPointers is generated into assets/map_script_tables.inc.

Route13CooltrainerM1Text:
    mov esi, Route13TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route13CooltrainerM1BattleText (scripts/Route13.asm:63-72) — Tier-1 data: Route13CooltrainerM1BattleText is generated into assets/trainer_headers.inc.

Route13CooltrainerF1Text:
    mov esi, Route13TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route13CooltrainerF1BattleText (scripts/Route13.asm:81-90) — Tier-1 data: Route13CooltrainerF1BattleText is generated into assets/trainer_headers.inc.

Route13CooltrainerF2Text:
    mov esi, Route13TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route13CooltrainerF2BattleText (scripts/Route13.asm:99-108) — Tier-1 data: Route13CooltrainerF2BattleText is generated into assets/trainer_headers.inc.

Route13CooltrainerF3Text:
    mov esi, Route13TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route13CooltrainerF3BattleText (scripts/Route13.asm:117-126) — Tier-1 data: Route13CooltrainerF3BattleText is generated into assets/trainer_headers.inc.

Route13CooltrainerF4Text:
    mov esi, Route13TrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route13CooltrainerF4BattleText (scripts/Route13.asm:135-144) — Tier-1 data: Route13CooltrainerF4BattleText is generated into assets/trainer_headers.inc.

Route13CooltrainerM2Text:
    mov esi, Route13TrainerHeader5
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route13CooltrainerM2BattleText (scripts/Route13.asm:153-162) — Tier-1 data: Route13CooltrainerM2BattleText is generated into assets/trainer_headers.inc.

Route13Beauty1Text:
    mov esi, Route13TrainerHeader6
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route13Beauty1BattleText (scripts/Route13.asm:171-180) — Tier-1 data: Route13Beauty1BattleText is generated into assets/trainer_headers.inc.

Route13Beauty2Text:
    mov esi, Route13TrainerHeader7
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route13Beauty2BattleText (scripts/Route13.asm:189-198) — Tier-1 data: Route13Beauty2BattleText is generated into assets/trainer_headers.inc.

Route13BikerText:
    mov esi, Route13TrainerHeader8
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route13BikerBattleText (scripts/Route13.asm:207-216) — Tier-1 data: Route13BikerBattleText is generated into assets/trainer_headers.inc.

Route13CooltrainerM3Text:
    mov esi, Route13TrainerHeader9
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route13CooltrainerM3BattleText (scripts/Route13.asm:225-246) — Tier-1 data: Route13CooltrainerM3BattleText is generated into assets/trainer_headers.inc.
