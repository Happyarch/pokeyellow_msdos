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

extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern Route8CooltrainerF1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route8CooltrainerF1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route8CooltrainerF1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route8CooltrainerF2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route8CooltrainerF2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route8CooltrainerF2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route8CooltrainerF3AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route8CooltrainerF3BattleText   ; NOT YET DEFINED IN THE PORT
extern Route8CooltrainerF3EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route8CooltrainerF4AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route8CooltrainerF4BattleText   ; NOT YET DEFINED IN THE PORT
extern Route8CooltrainerF4EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route8Gambler1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route8Gambler1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route8Gambler1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route8Gambler2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route8Gambler2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route8Gambler2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route8SuperNerd1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route8SuperNerd1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route8SuperNerd1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route8SuperNerd2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route8SuperNerd2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route8SuperNerd2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route8SuperNerd3AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route8SuperNerd3BattleText   ; NOT YET DEFINED IN THE PORT
extern Route8SuperNerd3EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route8TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern Route8TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern Route8TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern Route8TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern Route8TrainerHeader4   ; NOT YET DEFINED IN THE PORT
extern Route8TrainerHeader5   ; NOT YET DEFINED IN THE PORT
extern Route8TrainerHeader6   ; NOT YET DEFINED IN THE PORT
extern Route8TrainerHeader7   ; NOT YET DEFINED IN THE PORT
extern Route8TrainerHeader8   ; NOT YET DEFINED IN THE PORT
extern Route8TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern Route8UndergroundSignText   ; NOT YET DEFINED IN THE PORT
extern Route8_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern Route8_TextPointers   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_ROUTE8_DEFAULT                          equ 0
SCRIPT_ROUTE8_START_BATTLE                     equ 1
SCRIPT_ROUTE8_END_BATTLE                       equ 2
TEXT_ROUTE8_SUPER_NERD1                        equ 1
TEXT_ROUTE8_GAMBLER1                           equ 2
TEXT_ROUTE8_SUPER_NERD2                        equ 3
TEXT_ROUTE8_COOLTRAINER_F1                     equ 4
TEXT_ROUTE8_SUPER_NERD3                        equ 5
TEXT_ROUTE8_COOLTRAINER_F2                     equ 6
TEXT_ROUTE8_COOLTRAINER_F3                     equ 7
TEXT_ROUTE8_GAMBLER2                           equ 8
TEXT_ROUTE8_COOLTRAINER_F4                     equ 9
TEXT_ROUTE8_UNDERGROUND_SIGN                   equ 10

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wRoute8CurScript                               equ 0xD600

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

Route8_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route8TrainerHeaders
    mov edi, Route8_ScriptPointers   ; pret: ld de, Route8_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRoute8CurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRoute8CurScript], al
    ret

; ---------------------------------------------------------------------------
; Route8_ScriptPointers (scripts/Route8.asm:11-49) — Tier-1 data: Route8_ScriptPointers is generated into assets/map_script_tables.inc.

Route8SuperNerd1Text:
    mov esi, Route8TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route8SuperNerd1BattleText (scripts/Route8.asm:58-67) — Tier-1 data: Route8SuperNerd1BattleText is generated into assets/trainer_headers.inc.

Route8Gambler1Text:
    mov esi, Route8TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route8Gambler1BattleText (scripts/Route8.asm:76-85) — Tier-1 data: Route8Gambler1BattleText is generated into assets/trainer_headers.inc.

Route8SuperNerd2Text:
    mov esi, Route8TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route8SuperNerd2BattleText (scripts/Route8.asm:94-103) — Tier-1 data: Route8SuperNerd2BattleText is generated into assets/trainer_headers.inc.

Route8CooltrainerF1Text:
    mov esi, Route8TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route8CooltrainerF1BattleText (scripts/Route8.asm:112-121) — Tier-1 data: Route8CooltrainerF1BattleText is generated into assets/trainer_headers.inc.

Route8SuperNerd3Text:
    mov esi, Route8TrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route8SuperNerd3BattleText (scripts/Route8.asm:130-139) — Tier-1 data: Route8SuperNerd3BattleText is generated into assets/trainer_headers.inc.

Route8CooltrainerF2Text:
    mov esi, Route8TrainerHeader5
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route8CooltrainerF2BattleText (scripts/Route8.asm:148-157) — Tier-1 data: Route8CooltrainerF2BattleText is generated into assets/trainer_headers.inc.

Route8CooltrainerF3Text:
    mov esi, Route8TrainerHeader6
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route8CooltrainerF3BattleText (scripts/Route8.asm:166-175) — Tier-1 data: Route8CooltrainerF3BattleText is generated into assets/trainer_headers.inc.

Route8Gambler2Text:
    mov esi, Route8TrainerHeader7
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route8Gambler2BattleText (scripts/Route8.asm:184-193) — Tier-1 data: Route8Gambler2BattleText is generated into assets/trainer_headers.inc.

Route8CooltrainerF4Text:
    mov esi, Route8TrainerHeader8
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route8CooltrainerF4BattleText (scripts/Route8.asm:202-215) — Tier-1 data: Route8CooltrainerF4BattleText is generated into assets/trainer_headers.inc.
