; Route10.asm — translated from pret scripts/Route10.asm by dos_port/tools/sm83xlat.
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


global Route10CooltrainerF1Text
global Route10CooltrainerF2Text
global Route10Hiker1Text
global Route10Hiker2Text
global Route10SuperNerd1Text
global Route10SuperNerd2Text
global Route10_Script

extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern Route10CooltrainerF1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route10CooltrainerF1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route10CooltrainerF1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route10CooltrainerF2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route10CooltrainerF2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route10CooltrainerF2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route10Hiker1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route10Hiker1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route10Hiker1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route10Hiker2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route10Hiker2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route10Hiker2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route10PowerPlantSignText   ; NOT YET DEFINED IN THE PORT
extern Route10RockTunnelSignText   ; NOT YET DEFINED IN THE PORT
extern Route10SuperNerd1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route10SuperNerd1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route10SuperNerd1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route10SuperNerd2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route10SuperNerd2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route10SuperNerd2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route10TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern Route10TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern Route10TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern Route10TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern Route10TrainerHeader4   ; NOT YET DEFINED IN THE PORT
extern Route10TrainerHeader5   ; NOT YET DEFINED IN THE PORT
extern Route10TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern Route10_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern Route10_TextPointers   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_ROUTE10_DEFAULT                         equ 0
SCRIPT_ROUTE10_START_BATTLE                    equ 1
SCRIPT_ROUTE10_END_BATTLE                      equ 2
TEXT_ROUTE10_SUPER_NERD1                       equ 1
TEXT_ROUTE10_HIKER1                            equ 2
TEXT_ROUTE10_SUPER_NERD2                       equ 3
TEXT_ROUTE10_COOLTRAINER_F1                    equ 4
TEXT_ROUTE10_HIKER2                            equ 5
TEXT_ROUTE10_COOLTRAINER_F2                    equ 6
TEXT_ROUTE10_ROCKTUNNEL_NORTH_SIGN             equ 7
TEXT_ROUTE10_POKECENTER_SIGN                   equ 8
TEXT_ROUTE10_ROCKTUNNEL_SOUTH_SIGN             equ 9
TEXT_ROUTE10_POWERPLANT_SIGN                   equ 10

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wRoute10CurScript                              equ 0xD604

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

Route10_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route10TrainerHeaders
    mov edi, Route10_ScriptPointers   ; pret: ld de, Route10_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRoute10CurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRoute10CurScript], al
    ret

; ---------------------------------------------------------------------------
; Route10_ScriptPointers (scripts/Route10.asm:11-43) — Tier-1 data: Route10_ScriptPointers is generated into assets/map_script_tables.inc.

Route10SuperNerd1Text:
    mov esi, Route10TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route10SuperNerd1BattleText (scripts/Route10.asm:52-61) — Tier-1 data: Route10SuperNerd1BattleText is generated into assets/trainer_headers.inc.

Route10Hiker1Text:
    mov esi, Route10TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route10Hiker1BattleText (scripts/Route10.asm:70-79) — Tier-1 data: Route10Hiker1BattleText is generated into assets/trainer_headers.inc.

Route10SuperNerd2Text:
    mov esi, Route10TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route10SuperNerd2BattleText (scripts/Route10.asm:88-97) — Tier-1 data: Route10SuperNerd2BattleText is generated into assets/trainer_headers.inc.

Route10CooltrainerF1Text:
    mov esi, Route10TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route10CooltrainerF1BattleText (scripts/Route10.asm:106-115) — Tier-1 data: Route10CooltrainerF1BattleText is generated into assets/trainer_headers.inc.

Route10Hiker2Text:
    mov esi, Route10TrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route10Hiker2BattleText (scripts/Route10.asm:124-133) — Tier-1 data: Route10Hiker2BattleText is generated into assets/trainer_headers.inc.

Route10CooltrainerF2Text:
    mov esi, Route10TrainerHeader5
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route10CooltrainerF2BattleText (scripts/Route10.asm:142-159) — Tier-1 data: Route10CooltrainerF2BattleText is generated into assets/trainer_headers.inc.
