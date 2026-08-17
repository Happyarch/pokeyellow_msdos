; Route17.asm — translated from pret scripts/Route17.asm by dos_port/tools/sm83xlat.
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


global Route17Biker10Text
global Route17Biker1Text
global Route17Biker2Text
global Route17Biker3Text
global Route17Biker4Text
global Route17Biker5Text
global Route17Biker6Text
global Route17Biker7Text
global Route17Biker8Text
global Route17Biker9Text
global Route17_Script

extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern Route17Biker10AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route17Biker10BattleText   ; NOT YET DEFINED IN THE PORT
extern Route17Biker10EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route17Biker1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route17Biker1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route17Biker1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route17Biker2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route17Biker2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route17Biker2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route17Biker3AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route17Biker3BattleText   ; NOT YET DEFINED IN THE PORT
extern Route17Biker3EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route17Biker4AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route17Biker4BattleText   ; NOT YET DEFINED IN THE PORT
extern Route17Biker4EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route17Biker5AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route17Biker5BattleText   ; NOT YET DEFINED IN THE PORT
extern Route17Biker5EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route17Biker6AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route17Biker6BattleText   ; NOT YET DEFINED IN THE PORT
extern Route17Biker6EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route17Biker7AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route17Biker7BattleText   ; NOT YET DEFINED IN THE PORT
extern Route17Biker7EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route17Biker8AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route17Biker8BattleText   ; NOT YET DEFINED IN THE PORT
extern Route17Biker8EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route17Biker9AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route17Biker9BattleText   ; NOT YET DEFINED IN THE PORT
extern Route17Biker9EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route17CyclingRoadEndsSignText   ; NOT YET DEFINED IN THE PORT
extern Route17NoticeSign1Text   ; NOT YET DEFINED IN THE PORT
extern Route17NoticeSign2Text   ; NOT YET DEFINED IN THE PORT
extern Route17SignText   ; NOT YET DEFINED IN THE PORT
extern Route17TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern Route17TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern Route17TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern Route17TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern Route17TrainerHeader4   ; NOT YET DEFINED IN THE PORT
extern Route17TrainerHeader5   ; NOT YET DEFINED IN THE PORT
extern Route17TrainerHeader6   ; NOT YET DEFINED IN THE PORT
extern Route17TrainerHeader7   ; NOT YET DEFINED IN THE PORT
extern Route17TrainerHeader8   ; NOT YET DEFINED IN THE PORT
extern Route17TrainerHeader9   ; NOT YET DEFINED IN THE PORT
extern Route17TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern Route17TrainerTips1Text   ; NOT YET DEFINED IN THE PORT
extern Route17TrainerTips2Text   ; NOT YET DEFINED IN THE PORT
extern Route17_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern Route17_TextPointers   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_ROUTE17_DEFAULT                         equ 0
SCRIPT_ROUTE17_START_BATTLE                    equ 1
SCRIPT_ROUTE17_END_BATTLE                      equ 2
TEXT_ROUTE17_BIKER1                            equ 1
TEXT_ROUTE17_BIKER2                            equ 2
TEXT_ROUTE17_BIKER3                            equ 3
TEXT_ROUTE17_BIKER4                            equ 4
TEXT_ROUTE17_BIKER5                            equ 5
TEXT_ROUTE17_BIKER6                            equ 6
TEXT_ROUTE17_BIKER7                            equ 7
TEXT_ROUTE17_BIKER8                            equ 8
TEXT_ROUTE17_BIKER9                            equ 9
TEXT_ROUTE17_BIKER10                           equ 10
TEXT_ROUTE17_NOTICE_SIGN1                      equ 11
TEXT_ROUTE17_TRAINER_TIPS1                     equ 12
TEXT_ROUTE17_TRAINER_TIPS2                     equ 13
TEXT_ROUTE17_SIGN                              equ 14
TEXT_ROUTE17_NOTICE_SIGN2                      equ 15
TEXT_ROUTE17_CYCLING_ROAD_ENDS_SIGN            equ 16

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wRoute17CurScript                              equ 0xD61B

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

Route17_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route17TrainerHeaders
    mov edi, Route17_ScriptPointers   ; pret: ld de, Route17_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRoute17CurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRoute17CurScript], al
    ret

; ---------------------------------------------------------------------------
; Route17_ScriptPointers (scripts/Route17.asm:11-57) — Tier-1 data: Route17_ScriptPointers is generated into assets/map_script_tables.inc.

Route17Biker1Text:
    mov esi, Route17TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route17Biker1BattleText (scripts/Route17.asm:66-75) — Tier-1 data: Route17Biker1BattleText is generated into assets/trainer_headers.inc.

Route17Biker2Text:
    mov esi, Route17TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route17Biker2BattleText (scripts/Route17.asm:84-93) — Tier-1 data: Route17Biker2BattleText is generated into assets/trainer_headers.inc.

Route17Biker3Text:
    mov esi, Route17TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route17Biker3BattleText (scripts/Route17.asm:102-111) — Tier-1 data: Route17Biker3BattleText is generated into assets/trainer_headers.inc.

Route17Biker4Text:
    mov esi, Route17TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route17Biker4BattleText (scripts/Route17.asm:120-129) — Tier-1 data: Route17Biker4BattleText is generated into assets/trainer_headers.inc.

Route17Biker5Text:
    mov esi, Route17TrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route17Biker5BattleText (scripts/Route17.asm:138-147) — Tier-1 data: Route17Biker5BattleText is generated into assets/trainer_headers.inc.

Route17Biker6Text:
    mov esi, Route17TrainerHeader5
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route17Biker6BattleText (scripts/Route17.asm:156-165) — Tier-1 data: Route17Biker6BattleText is generated into assets/trainer_headers.inc.

Route17Biker7Text:
    mov esi, Route17TrainerHeader6
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route17Biker7BattleText (scripts/Route17.asm:174-183) — Tier-1 data: Route17Biker7BattleText is generated into assets/trainer_headers.inc.

Route17Biker8Text:
    mov esi, Route17TrainerHeader7
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route17Biker8BattleText (scripts/Route17.asm:192-201) — Tier-1 data: Route17Biker8BattleText is generated into assets/trainer_headers.inc.

Route17Biker9Text:
    mov esi, Route17TrainerHeader8
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route17Biker9BattleText (scripts/Route17.asm:210-219) — Tier-1 data: Route17Biker9BattleText is generated into assets/trainer_headers.inc.

Route17Biker10Text:
    mov esi, Route17TrainerHeader9
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route17Biker10BattleText (scripts/Route17.asm:228-261) — Tier-1 data: Route17Biker10BattleText is generated into assets/trainer_headers.inc.
