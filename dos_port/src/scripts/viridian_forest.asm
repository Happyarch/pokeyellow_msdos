; ViridianForest.asm — translated from pret scripts/ViridianForest.asm, scripts/ViridianForest_2.asm by dos_port/tools/sm83xlat.
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


global ViridianForestCooltrainerFText
global ViridianForestPrintLeavingSignText
global ViridianForestPrintTrainerTips1Text
global ViridianForestPrintTrainerTips2Text
global ViridianForestPrintTrainerTips3Text
global ViridianForestPrintTrainerTips4Text
global ViridianForestPrintUseAntidoteSignText
global ViridianForestTalkToTrainer
global ViridianForestTrainerTips1Text
global ViridianForestTrainerTips2Text
global ViridianForestTrainerTips3Text
global ViridianForestTrainerTips4Text
global ViridianForestUseAntidoteSignText
global ViridianForestYoungster2Text
global ViridianForestYoungster3Text
global ViridianForestYoungster4Text
global ViridianForestYoungster5Text
global ViridianForest_Script

extern Bankswitch   ; NOT YET DEFINED IN THE PORT
extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern PickUpItemText   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern ViridianForestCooltrainerFAfterBattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianForestCooltrainerFBattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianForestCooltrainerFEndBattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianForestLeavingSignText   ; NOT YET DEFINED IN THE PORT
extern ViridianForestSign_Common   ; NOT YET DEFINED IN THE PORT
extern ViridianForestTrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern ViridianForestTrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern ViridianForestTrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern ViridianForestTrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern ViridianForestTrainerHeader4   ; NOT YET DEFINED IN THE PORT
extern ViridianForestTrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern ViridianForestYoungster1Text   ; NOT YET DEFINED IN THE PORT
extern ViridianForestYoungster2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianForestYoungster2BattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianForestYoungster2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianForestYoungster3AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianForestYoungster3BattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianForestYoungster3EndBattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianForestYoungster4AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianForestYoungster4BattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianForestYoungster4EndBattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianForestYoungster5AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianForestYoungster5BattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianForestYoungster5EndBattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianForestYoungster6Text   ; NOT YET DEFINED IN THE PORT
extern ViridianForest_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern ViridianForest_TextPointers   ; NOT YET DEFINED IN THE PORT
extern _ViridianForestLeavingSignText   ; NOT YET DEFINED IN THE PORT
extern _ViridianForestTrainerTips1Text   ; NOT YET DEFINED IN THE PORT
extern _ViridianForestTrainerTips2Text   ; NOT YET DEFINED IN THE PORT
extern _ViridianForestTrainerTips3Text   ; NOT YET DEFINED IN THE PORT
extern _ViridianForestTrainerTips4Text   ; NOT YET DEFINED IN THE PORT
extern _ViridianForestUseAntidoteSignText   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_VIRIDIANFOREST_DEFAULT                  equ 0
SCRIPT_VIRIDIANFOREST_START_BATTLE             equ 1
SCRIPT_VIRIDIANFOREST_END_BATTLE               equ 2
TEXT_VIRIDIANFOREST_YOUNGSTER1                 equ 1
TEXT_VIRIDIANFOREST_YOUNGSTER2                 equ 2
TEXT_VIRIDIANFOREST_YOUNGSTER3                 equ 3
TEXT_VIRIDIANFOREST_YOUNGSTER4                 equ 4
TEXT_VIRIDIANFOREST_COOLTRAINER_F              equ 5
TEXT_VIRIDIANFOREST_YOUNGSTER5                 equ 6
TEXT_VIRIDIANFOREST_POTION1                    equ 7
TEXT_VIRIDIANFOREST_POTION2                    equ 8
TEXT_VIRIDIANFOREST_POKE_BALL                  equ 9
TEXT_VIRIDIANFOREST_YOUNGSTER6                 equ 10
TEXT_VIRIDIANFOREST_TRAINER_TIPS1              equ 11
TEXT_VIRIDIANFOREST_USE_ANTIDOTE_SIGN          equ 12
TEXT_VIRIDIANFOREST_TRAINER_TIPS2              equ 13
TEXT_VIRIDIANFOREST_TRAINER_TIPS3              equ 14
TEXT_VIRIDIANFOREST_TRAINER_TIPS4              equ 15
TEXT_VIRIDIANFOREST_LEAVING_SIGN               equ 16

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wViridianForestCurScript                       equ 0xD617

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

ViridianForest_Script:
    call EnableAutoTextBoxDrawing
    mov esi, ViridianForestTrainerHeaders
    mov edi, ViridianForest_ScriptPointers   ; pret: ld de, ViridianForest_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wViridianForestCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wViridianForestCurScript], al
    ret

; ---------------------------------------------------------------------------
; ViridianForest_ScriptPointers (scripts/ViridianForest.asm:11-51) — Tier-1 data: ViridianForest_ScriptPointers is generated into assets/map_script_tables.inc.

ViridianForestYoungster2Text:
    mov esi, ViridianForestTrainerHeader0
    jmp ViridianForestTalkToTrainer

ViridianForestYoungster3Text:
    mov esi, ViridianForestTrainerHeader1
    jmp ViridianForestTalkToTrainer

ViridianForestYoungster4Text:
    mov esi, ViridianForestTrainerHeader2
    jmp ViridianForestTalkToTrainer

ViridianForestCooltrainerFText:
    mov esi, ViridianForestTrainerHeader3
    jmp ViridianForestTalkToTrainer

ViridianForestYoungster5Text:
    mov esi, ViridianForestTrainerHeader4
ViridianForestTalkToTrainer:
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; ViridianForestYoungster2BattleText (scripts/ViridianForest.asm:81-142) — Tier-1 data: ViridianForestYoungster2BattleText is generated into assets/trainer_headers.inc.

ViridianForestTrainerTips1Text:
    mov esi, ViridianForestPrintTrainerTips1Text
    jmp ViridianForestSign_Common

ViridianForestUseAntidoteSignText:
    mov esi, ViridianForestPrintUseAntidoteSignText
    jmp ViridianForestSign_Common

ViridianForestTrainerTips2Text:
    mov esi, ViridianForestPrintTrainerTips2Text
    jmp ViridianForestSign_Common

ViridianForestTrainerTips3Text:
    mov esi, ViridianForestPrintTrainerTips3Text
    jmp ViridianForestSign_Common

ViridianForestTrainerTips4Text:
    mov esi, ViridianForestPrintTrainerTips4Text
    jmp ViridianForestSign_Common

; ---------------------------------------------------------------------------
; BAIL[bank-expression] ViridianForestLeavingSignText (scripts/ViridianForest.asm:171-175) — at scripts/ViridianForest.asm:173: BANK(ViridianForestPrintTrainerTips1Text)
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, ViridianForestPrintTrainerTips1Text ; supposed to be ViridianForestPrintLeavingSignText
; PRET| ViridianForestSign_Common:
; PRET| 	ld b, BANK(ViridianForestPrintTrainerTips1Text)
; PRET| 	call Bankswitch
; PRET| 	jp TextScriptEnd

ViridianForestPrintTrainerTips1Text:
    mov esi, .text
    call PrintText
    ret

.text:
    text_far _ViridianForestTrainerTips1Text
    text_end

ViridianForestPrintUseAntidoteSignText:
    mov esi, .text
    call PrintText
    ret

.text:
    text_far _ViridianForestUseAntidoteSignText
    text_end

ViridianForestPrintTrainerTips2Text:
    mov esi, .text
    call PrintText
    ret

.text:
    text_far _ViridianForestTrainerTips2Text
    text_end

ViridianForestPrintTrainerTips3Text:
    mov esi, .text
    call PrintText
    ret

.text:
    text_far _ViridianForestTrainerTips3Text
    text_end

ViridianForestPrintTrainerTips4Text:
    mov esi, .text
    call PrintText
    ret

.text:
    text_far _ViridianForestTrainerTips4Text
    text_end

ViridianForestPrintLeavingSignText:
    mov esi, .text
    call PrintText
    ret

.text:
    text_far _ViridianForestLeavingSignText
    text_end
