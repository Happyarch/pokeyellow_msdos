; RockTunnelB1F.asm — translated from pret scripts/RockTunnelB1F.asm by dos_port/tools/sm83xlat.
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


global RockTunnelB1FCooltrainerF1Text
global RockTunnelB1FCooltrainerF2Text
global RockTunnelB1FHiker1Text
global RockTunnelB1FHiker2Text
global RockTunnelB1FHiker3Text
global RockTunnelB1FSuperNerd1Text
global RockTunnelB1FSuperNerd2Text
global RockTunnelB1FSuperNerd3Text
global RockTunnelB1F_Script

extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern RockTunnel2TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern RockTunnel2TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern RockTunnel2TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern RockTunnel2TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern RockTunnel2TrainerHeader4   ; NOT YET DEFINED IN THE PORT
extern RockTunnel2TrainerHeader5   ; NOT YET DEFINED IN THE PORT
extern RockTunnel2TrainerHeader6   ; NOT YET DEFINED IN THE PORT
extern RockTunnel2TrainerHeader7   ; NOT YET DEFINED IN THE PORT
extern RockTunnel2TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1FCooltrainerF1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1FCooltrainerF1BattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1FCooltrainerF1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1FCooltrainerF2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1FCooltrainerF2BattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1FCooltrainerF2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1FHiker1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1FHiker1BattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1FHiker1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1FHiker2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1FHiker2BattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1FHiker2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1FHiker3AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1FHiker3BattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1FHiker3EndBattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1FSuperNerd1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1FSuperNerd1BattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1FSuperNerd1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1FSuperNerd2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1FSuperNerd2BattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1FSuperNerd2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1FSuperNerd3AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1FSuperNerd3BattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1FSuperNerd3EndBattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1F_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern RockTunnelB1F_TextPointers   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_ROCKTUNNELB1F_DEFAULT                   equ 0
SCRIPT_ROCKTUNNELB1F_START_BATTLE              equ 1
SCRIPT_ROCKTUNNELB1F_END_BATTLE                equ 2
TEXT_ROCKTUNNELB1F_COOLTRAINER_F1              equ 1
TEXT_ROCKTUNNELB1F_HIKER1                      equ 2
TEXT_ROCKTUNNELB1F_SUPER_NERD1                 equ 3
TEXT_ROCKTUNNELB1F_SUPER_NERD2                 equ 4
TEXT_ROCKTUNNELB1F_HIKER2                      equ 5
TEXT_ROCKTUNNELB1F_COOLTRAINER_F2              equ 6
TEXT_ROCKTUNNELB1F_HIKER3                      equ 7
TEXT_ROCKTUNNELB1F_SUPER_NERD3                 equ 8

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wRockTunnelB1FCurScript                        equ 0xD61F

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

RockTunnelB1F_Script:
    call EnableAutoTextBoxDrawing
    mov esi, RockTunnel2TrainerHeaders
    mov edi, RockTunnelB1F_ScriptPointers   ; pret: ld de, RockTunnelB1F_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRockTunnelB1FCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRockTunnelB1FCurScript], al
    ret

; ---------------------------------------------------------------------------
; RockTunnelB1F_ScriptPointers (scripts/RockTunnelB1F.asm:11-45) — Tier-1 data: RockTunnel2TrainerHeaders is generated into assets/trainer_headers.inc.

RockTunnelB1FCooltrainerF1Text:
    mov esi, RockTunnel2TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

RockTunnelB1FHiker1Text:
    mov esi, RockTunnel2TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

RockTunnelB1FSuperNerd1Text:
    mov esi, RockTunnel2TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

RockTunnelB1FSuperNerd2Text:
    mov esi, RockTunnel2TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

RockTunnelB1FHiker2Text:
    mov esi, RockTunnel2TrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

RockTunnelB1FCooltrainerF2Text:
    mov esi, RockTunnel2TrainerHeader5
    call TalkToTrainer
    jmp TextScriptEnd

RockTunnelB1FHiker3Text:
    mov esi, RockTunnel2TrainerHeader6
    call TalkToTrainer
    jmp TextScriptEnd

RockTunnelB1FSuperNerd3Text:
    mov esi, RockTunnel2TrainerHeader7
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; RockTunnelB1FCooltrainerF1BattleText (scripts/RockTunnelB1F.asm:96-189) — Tier-1 data: RockTunnelB1FCooltrainerF1BattleText is generated into assets/trainer_headers.inc.
