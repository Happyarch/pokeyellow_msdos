; RockTunnel1F.asm — translated from pret scripts/RockTunnel1F.asm by dos_port/tools/sm83xlat.
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


global RockTunnel1FCooltrainerF1Text
global RockTunnel1FCooltrainerF2Text
global RockTunnel1FCooltrainerF3Text
global RockTunnel1FHiker1Text
global RockTunnel1FHiker2Text
global RockTunnel1FHiker3Text
global RockTunnel1FSuperNerdText
global RockTunnel1FTalkToTrainer
global RockTunnel1F_Script

extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern RockTunnel1FCooltrainerF1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnel1FCooltrainerF1BattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnel1FCooltrainerF1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnel1FCooltrainerF2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnel1FCooltrainerF2BattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnel1FCooltrainerF2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnel1FCooltrainerF3AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnel1FCooltrainerF3BattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnel1FCooltrainerF3EndBattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnel1FHiker1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnel1FHiker1BattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnel1FHiker1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnel1FHiker2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnel1FHiker2BattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnel1FHiker2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnel1FHiker3AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnel1FHiker3BattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnel1FHiker3EndBattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnel1FSignText   ; NOT YET DEFINED IN THE PORT
extern RockTunnel1FSuperNerdAfterBattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnel1FSuperNerdBattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnel1FSuperNerdEndBattleText   ; NOT YET DEFINED IN THE PORT
extern RockTunnel1F_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern RockTunnel1F_TextPointers   ; NOT YET DEFINED IN THE PORT
extern RockTunnel1TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern RockTunnel1TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern RockTunnel1TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern RockTunnel1TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern RockTunnel1TrainerHeader4   ; NOT YET DEFINED IN THE PORT
extern RockTunnel1TrainerHeader5   ; NOT YET DEFINED IN THE PORT
extern RockTunnel1TrainerHeader6   ; NOT YET DEFINED IN THE PORT
extern RockTunnel1TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_ROCKTUNNEL1F_DEFAULT                    equ 0
SCRIPT_ROCKTUNNEL1F_START_BATTLE               equ 1
SCRIPT_ROCKTUNNEL1F_END_BATTLE                 equ 2
TEXT_ROCKTUNNEL1F_HIKER1                       equ 1
TEXT_ROCKTUNNEL1F_HIKER2                       equ 2
TEXT_ROCKTUNNEL1F_HIKER3                       equ 3
TEXT_ROCKTUNNEL1F_SUPER_NERD                   equ 4
TEXT_ROCKTUNNEL1F_COOLTRAINER_F1               equ 5
TEXT_ROCKTUNNEL1F_COOLTRAINER_F2               equ 6
TEXT_ROCKTUNNEL1F_COOLTRAINER_F3               equ 7
TEXT_ROCKTUNNEL1F_SIGN                         equ 8

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wRockTunnel1FCurScript                         equ 0xD620

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

RockTunnel1F_Script:
    call EnableAutoTextBoxDrawing
    mov esi, RockTunnel1TrainerHeaders
    mov edi, RockTunnel1F_ScriptPointers   ; pret: ld de, RockTunnel1F_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRockTunnel1FCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRockTunnel1FCurScript], al
    ret

; ---------------------------------------------------------------------------
; RockTunnel1F_ScriptPointers (scripts/RockTunnel1F.asm:11-43) — Tier-1 data: RockTunnel1TrainerHeaders is generated into assets/trainer_headers.inc.

RockTunnel1FHiker1Text:
    mov esi, RockTunnel1TrainerHeader0
    jmp RockTunnel1FTalkToTrainer

RockTunnel1FHiker2Text:
    mov esi, RockTunnel1TrainerHeader1
    jmp RockTunnel1FTalkToTrainer

RockTunnel1FHiker3Text:
    mov esi, RockTunnel1TrainerHeader2
    jmp RockTunnel1FTalkToTrainer

RockTunnel1FSuperNerdText:
    mov esi, RockTunnel1TrainerHeader3
    jmp RockTunnel1FTalkToTrainer

RockTunnel1FCooltrainerF1Text:
    mov esi, RockTunnel1TrainerHeader4
    jmp RockTunnel1FTalkToTrainer

RockTunnel1FCooltrainerF2Text:
    mov esi, RockTunnel1TrainerHeader5
    jmp RockTunnel1FTalkToTrainer

RockTunnel1FCooltrainerF3Text:
    mov esi, RockTunnel1TrainerHeader6
RockTunnel1FTalkToTrainer:
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; RockTunnel1FHiker1BattleText (scripts/RockTunnel1F.asm:83-168) — Tier-1 data: RockTunnel1FHiker1BattleText is generated into assets/trainer_headers.inc.
