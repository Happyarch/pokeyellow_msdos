; MtMoon1F.asm — translated from pret scripts/MtMoon1F.asm by dos_port/tools/sm83xlat.
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


global MtMoon1FCooltrainerF1Text
global MtMoon1FCooltrainerF2Text
global MtMoon1FHikerText
global MtMoon1FSuperNerdText
global MtMoon1FYoungster1Text
global MtMoon1FYoungster2Text
global MtMoon1FYoungster3Text
global MtMoon1F_Script
global MtMoon1TalkToTrainer

extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern MtMoon1FBewareZubatSign   ; NOT YET DEFINED IN THE PORT
extern MtMoon1FCooltrainerF1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern MtMoon1FCooltrainerF1BattleText   ; NOT YET DEFINED IN THE PORT
extern MtMoon1FCooltrainerF1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern MtMoon1FCooltrainerF2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern MtMoon1FCooltrainerF2BattleText   ; NOT YET DEFINED IN THE PORT
extern MtMoon1FCooltrainerF2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern MtMoon1FHikerAfterBattleText   ; NOT YET DEFINED IN THE PORT
extern MtMoon1FHikerBattleText   ; NOT YET DEFINED IN THE PORT
extern MtMoon1FHikerEndBattleText   ; NOT YET DEFINED IN THE PORT
extern MtMoon1FSuperNerdAfterBattleText   ; NOT YET DEFINED IN THE PORT
extern MtMoon1FSuperNerdBattleText   ; NOT YET DEFINED IN THE PORT
extern MtMoon1FSuperNerdEndBattleText   ; NOT YET DEFINED IN THE PORT
extern MtMoon1FYoungster1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern MtMoon1FYoungster1BattleText   ; NOT YET DEFINED IN THE PORT
extern MtMoon1FYoungster1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern MtMoon1FYoungster2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern MtMoon1FYoungster2BattleText   ; NOT YET DEFINED IN THE PORT
extern MtMoon1FYoungster2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern MtMoon1FYoungster3AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern MtMoon1FYoungster3BattleText   ; NOT YET DEFINED IN THE PORT
extern MtMoon1FYoungster3EndBattleText   ; NOT YET DEFINED IN THE PORT
extern MtMoon1F_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern MtMoon1F_TextPointers   ; NOT YET DEFINED IN THE PORT
extern MtMoon1TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern MtMoon1TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern MtMoon1TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern MtMoon1TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern MtMoon1TrainerHeader4   ; NOT YET DEFINED IN THE PORT
extern MtMoon1TrainerHeader5   ; NOT YET DEFINED IN THE PORT
extern MtMoon1TrainerHeader6   ; NOT YET DEFINED IN THE PORT
extern MtMoon1TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern PickUpItemText   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_MTMOON1F_DEFAULT                        equ 0
SCRIPT_MTMOON1F_START_BATTLE                   equ 1
SCRIPT_MTMOON1F_END_BATTLE                     equ 2
TEXT_MTMOON1F_HIKER                            equ 1
TEXT_MTMOON1F_YOUNGSTER1                       equ 2
TEXT_MTMOON1F_COOLTRAINER_F1                   equ 3
TEXT_MTMOON1F_SUPER_NERD                       equ 4
TEXT_MTMOON1F_COOLTRAINER_F2                   equ 5
TEXT_MTMOON1F_YOUNGSTER2                       equ 6
TEXT_MTMOON1F_YOUNGSTER3                       equ 7
TEXT_MTMOON1F_POTION1                          equ 8
TEXT_MTMOON1F_MOON_STONE                       equ 9
TEXT_MTMOON1F_RARE_CANDY                       equ 10
TEXT_MTMOON1F_ESCAPE_ROPE                      equ 11
TEXT_MTMOON1F_POTION2                          equ 12
TEXT_MTMOON1F_TM_WATER_GUN                     equ 13
TEXT_MTMOON1F_BEWARE_ZUBAT_SIGN                equ 14

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wMtMoon1FCurScript                             equ 0xD605

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

MtMoon1F_Script:
    call EnableAutoTextBoxDrawing
    mov esi, MtMoon1TrainerHeaders
    mov edi, MtMoon1F_ScriptPointers   ; pret: ld de, MtMoon1F_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wMtMoon1FCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wMtMoon1FCurScript], al
    ret

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] MtMoon1F_ScriptPointers (scripts/MtMoon1F.asm:11-49) — a generated asset already defines MtMoon1TrainerHeaders
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	def_script_pointers
; PRET| 	dw_const CheckFightingMapTrainers,              SCRIPT_MTMOON1F_DEFAULT
; PRET| 	dw_const DisplayEnemyTrainerTextAndStartBattle, SCRIPT_MTMOON1F_START_BATTLE
; PRET| 	dw_const EndTrainerBattle,                      SCRIPT_MTMOON1F_END_BATTLE
; PRET| 
; PRET| MtMoon1F_TextPointers:
; PRET| 	def_text_pointers
; PRET| 	dw_const MtMoon1FHikerText,         TEXT_MTMOON1F_HIKER
; PRET| 	dw_const MtMoon1FYoungster1Text,    TEXT_MTMOON1F_YOUNGSTER1
; PRET| 	dw_const MtMoon1FCooltrainerF1Text, TEXT_MTMOON1F_COOLTRAINER_F1
; PRET| 	dw_const MtMoon1FSuperNerdText,     TEXT_MTMOON1F_SUPER_NERD
; PRET| 	dw_const MtMoon1FCooltrainerF2Text, TEXT_MTMOON1F_COOLTRAINER_F2
; PRET| 	dw_const MtMoon1FYoungster2Text,    TEXT_MTMOON1F_YOUNGSTER2
; PRET| 	dw_const MtMoon1FYoungster3Text,    TEXT_MTMOON1F_YOUNGSTER3
; PRET| 	dw_const PickUpItemText,            TEXT_MTMOON1F_POTION1
; PRET| 	dw_const PickUpItemText,            TEXT_MTMOON1F_MOON_STONE
; PRET| 	dw_const PickUpItemText,            TEXT_MTMOON1F_RARE_CANDY
; PRET| 	dw_const PickUpItemText,            TEXT_MTMOON1F_ESCAPE_ROPE
; PRET| 	dw_const PickUpItemText,            TEXT_MTMOON1F_POTION2
; PRET| 	dw_const PickUpItemText,            TEXT_MTMOON1F_TM_WATER_GUN
; PRET| 	dw_const MtMoon1FBewareZubatSign,   TEXT_MTMOON1F_BEWARE_ZUBAT_SIGN
; PRET| 
; PRET| MtMoon1TrainerHeaders:
; PRET| 	def_trainers
; PRET| MtMoon1TrainerHeader0:
; PRET| 	trainer EVENT_BEAT_MT_MOON_1_TRAINER_0, 2, MtMoon1FHikerBattleText, MtMoon1FHikerEndBattleText, MtMoon1FHikerAfterBattleText
; PRET| MtMoon1TrainerHeader1:
; PRET| 	trainer EVENT_BEAT_MT_MOON_1_TRAINER_1, 3, MtMoon1FYoungster1BattleText, MtMoon1FYoungster1EndBattleText, MtMoon1FYoungster1AfterBattleText
; PRET| MtMoon1TrainerHeader2:
; PRET| 	trainer EVENT_BEAT_MT_MOON_1_TRAINER_2, 3, MtMoon1FCooltrainerF1BattleText, MtMoon1FCooltrainerF1EndBattleText, MtMoon1FCooltrainerF1AfterBattleText
; PRET| MtMoon1TrainerHeader3:
; PRET| 	trainer EVENT_BEAT_MT_MOON_1_TRAINER_3, 3, MtMoon1FSuperNerdBattleText, MtMoon1FSuperNerdEndBattleText, MtMoon1FSuperNerdAfterBattleText
; PRET| MtMoon1TrainerHeader4:
; PRET| 	trainer EVENT_BEAT_MT_MOON_1_TRAINER_4, 3, MtMoon1FCooltrainerF2BattleText, MtMoon1FCooltrainerF2EndBattleText, MtMoon1FCooltrainerF2AfterBattleText
; PRET| MtMoon1TrainerHeader5:
; PRET| 	trainer EVENT_BEAT_MT_MOON_1_TRAINER_5, 3, MtMoon1FYoungster2BattleText, MtMoon1FYoungster2EndBattleText, MtMoon1FYoungster2AfterBattleText
; PRET| MtMoon1TrainerHeader6:
; PRET| 	trainer EVENT_BEAT_MT_MOON_1_TRAINER_6, 3, MtMoon1FYoungster3BattleText, MtMoon1FYoungster3EndBattleText, MtMoon1FYoungster3AfterBattleText
; PRET| 	db -1 ; end

MtMoon1FHikerText:
    mov esi, MtMoon1TrainerHeader0
    jmp MtMoon1TalkToTrainer

MtMoon1FYoungster1Text:
    mov esi, MtMoon1TrainerHeader1
    jmp MtMoon1TalkToTrainer

MtMoon1FCooltrainerF1Text:
    mov esi, MtMoon1TrainerHeader2
    jmp MtMoon1TalkToTrainer

MtMoon1FSuperNerdText:
    mov esi, MtMoon1TrainerHeader3
    jmp MtMoon1TalkToTrainer

MtMoon1FCooltrainerF2Text:
    mov esi, MtMoon1TrainerHeader4
    jmp MtMoon1TalkToTrainer

MtMoon1FYoungster2Text:
    mov esi, MtMoon1TrainerHeader5
    jmp MtMoon1TalkToTrainer

MtMoon1FYoungster3Text:
    mov esi, MtMoon1TrainerHeader6
MtMoon1TalkToTrainer:
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] MtMoon1FHikerBattleText (scripts/MtMoon1F.asm:89-174) — a generated asset already defines MtMoon1FHikerBattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _MtMoon1FHikerBattleText
; PRET| 	text_end
; PRET| 
; PRET| MtMoon1FHikerEndBattleText:
; PRET| 	text_far _MtMoon1FHikerEndBattleText
; PRET| 	text_end
; PRET| 
; PRET| MtMoon1FHikerAfterBattleText:
; PRET| 	text_far _MtMoon1FHikerAfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| MtMoon1FYoungster1BattleText:
; PRET| 	text_far _MtMoon1FYoungster1BattleText
; PRET| 	text_end
; PRET| 
; PRET| MtMoon1FYoungster1EndBattleText:
; PRET| 	text_far _MtMoon1FYoungster1EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| MtMoon1FYoungster1AfterBattleText:
; PRET| 	text_far _MtMoon1FYoungster1AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| MtMoon1FCooltrainerF1BattleText:
; PRET| 	text_far _MtMoon1FCooltrainerF1BattleText
; PRET| 	text_end
; PRET| 
; PRET| MtMoon1FCooltrainerF1EndBattleText:
; PRET| 	text_far _MtMoon1FCooltrainerF1EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| MtMoon1FCooltrainerF1AfterBattleText:
; PRET| 	text_far _MtMoon1FCooltrainerF1AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| MtMoon1FSuperNerdBattleText:
; PRET| 	text_far _MtMoon1FSuperNerdBattleText
; PRET| 	text_end
; PRET| 
; PRET| MtMoon1FSuperNerdEndBattleText:
; PRET| 	text_far _MtMoon1FSuperNerdEndBattleText
; PRET| 	text_end
; PRET| 
; PRET| MtMoon1FSuperNerdAfterBattleText:
; PRET| 	text_far _MtMoon1FSuperNerdAfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| MtMoon1FCooltrainerF2BattleText:
; PRET| 	text_far _MtMoon1FCooltrainerF2BattleText
; PRET| 	text_end
; PRET| 
; PRET| MtMoon1FCooltrainerF2EndBattleText:
; PRET| 	text_far _MtMoon1FCooltrainerF2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| MtMoon1FCooltrainerF2AfterBattleText:
; PRET| 	text_far _MtMoon1FCooltrainerF2AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| MtMoon1FYoungster2BattleText:
; PRET| 	text_far _MtMoon1FYoungster2BattleText
; PRET| 	text_end
; PRET| 
; PRET| MtMoon1FYoungster2EndBattleText:
; PRET| 	text_far _MtMoon1FYoungster2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| MtMoon1FYoungster2AfterBattleText:
; PRET| 	text_far _MtMoon1FYoungster2AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| MtMoon1FYoungster3BattleText:
; PRET| 	text_far _MtMoon1FYoungster3BattleText
; PRET| 	text_end
; PRET| 
; PRET| MtMoon1FYoungster3EndBattleText:
; PRET| 	text_far _MtMoon1FYoungster3EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| MtMoon1FYoungster3AfterBattleText:
; PRET| 	text_far _MtMoon1FYoungster3AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| MtMoon1FBewareZubatSign:
; PRET| 	text_far _MtMoon1FBewareZubatSign
; PRET| 	text_end
