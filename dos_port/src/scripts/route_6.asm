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


global Route6CooltrainerF1Text
global Route6CooltrainerF2Text
global Route6CooltrainerM1Text
global Route6CooltrainerM2Text
global Route6Youngster1Text
global Route6Youngster2Text
global Route6_Script

extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern Route6CooltrainerF1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route6CooltrainerF1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route6CooltrainerF1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route6CooltrainerF2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route6CooltrainerF2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route6CooltrainerF2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route6CooltrainerM1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route6CooltrainerM1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route6CooltrainerM1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route6CooltrainerM2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route6CooltrainerM2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route6CooltrainerM2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route6TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern Route6TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern Route6TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern Route6TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern Route6TrainerHeader4   ; NOT YET DEFINED IN THE PORT
extern Route6TrainerHeader5   ; NOT YET DEFINED IN THE PORT
extern Route6TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern Route6UndergroundPathSignText   ; NOT YET DEFINED IN THE PORT
extern Route6Youngster1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route6Youngster1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route6Youngster1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route6Youngster2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route6Youngster2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route6Youngster2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route6_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern Route6_TextPointers   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_ROUTE6_DEFAULT                          equ 0
SCRIPT_ROUTE6_START_BATTLE                     equ 1
SCRIPT_ROUTE6_END_BATTLE                       equ 2
TEXT_ROUTE6_COOLTRAINER_M1                     equ 1
TEXT_ROUTE6_COOLTRAINER_F1                     equ 2
TEXT_ROUTE6_YOUNGSTER1                         equ 3
TEXT_ROUTE6_COOLTRAINER_M2                     equ 4
TEXT_ROUTE6_COOLTRAINER_F2                     equ 5
TEXT_ROUTE6_YOUNGSTER2                         equ 6
TEXT_ROUTE6_UNDERGROUND_PATH_SIGN              equ 7

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wRoute6CurScript                               equ 0xD5FF

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

Route6_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route6TrainerHeaders
    mov edi, Route6_ScriptPointers   ; pret: ld de, Route6_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRoute6CurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRoute6CurScript], al
    ret

; ---------------------------------------------------------------------------
; Route6_ScriptPointers (scripts/Route6.asm:11-40) — Tier-1 data: Route6_ScriptPointers is generated into assets/map_script_tables.inc.

Route6CooltrainerM1Text:
    mov esi, Route6TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route6CooltrainerM1BattleText (scripts/Route6.asm:49-58) — Tier-1 data: Route6CooltrainerM1BattleText is generated into assets/trainer_headers.inc.

Route6CooltrainerF1Text:
    mov esi, Route6TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route6CooltrainerF1BattleText (scripts/Route6.asm:67-76) — Tier-1 data: Route6CooltrainerF1BattleText is generated into assets/trainer_headers.inc.

Route6Youngster1Text:
    mov esi, Route6TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route6Youngster1BattleText (scripts/Route6.asm:85-94) — Tier-1 data: Route6Youngster1BattleText is generated into assets/trainer_headers.inc.

Route6CooltrainerM2Text:
    mov esi, Route6TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route6CooltrainerM2BattleText (scripts/Route6.asm:103-112) — Tier-1 data: Route6CooltrainerM2BattleText is generated into assets/trainer_headers.inc.

Route6CooltrainerF2Text:
    mov esi, Route6TrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route6CooltrainerF2BattleText (scripts/Route6.asm:121-130) — Tier-1 data: Route6CooltrainerF2BattleText is generated into assets/trainer_headers.inc.

Route6Youngster2Text:
    mov esi, Route6TrainerHeader5
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route6Youngster2BattleText (scripts/Route6.asm:139-152) — Tier-1 data: Route6Youngster2BattleText is generated into assets/trainer_headers.inc.
