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
; BAIL[owned-by-generated-assets] Route15_ScriptPointers (scripts/Route15.asm:11-53) — a generated asset already defines Route15_ScriptPointers
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	def_script_pointers
; PRET| 	dw_const CheckFightingMapTrainers,              SCRIPT_ROUTE15_DEFAULT
; PRET| 	dw_const DisplayEnemyTrainerTextAndStartBattle, SCRIPT_ROUTE15_START_BATTLE
; PRET| 	dw_const EndTrainerBattle,                      SCRIPT_ROUTE15_END_BATTLE
; PRET| 
; PRET| Route15_TextPointers:
; PRET| 	def_text_pointers
; PRET| 	dw_const Route15CooltrainerF1Text, TEXT_ROUTE15_COOLTRAINER_F1
; PRET| 	dw_const Route15CooltrainerF2Text, TEXT_ROUTE15_COOLTRAINER_F2
; PRET| 	dw_const Route15CooltrainerM1Text, TEXT_ROUTE15_COOLTRAINER_M1
; PRET| 	dw_const Route15CooltrainerM2Text, TEXT_ROUTE15_COOLTRAINER_M2
; PRET| 	dw_const Route15Beauty1Text,       TEXT_ROUTE15_BEAUTY1
; PRET| 	dw_const Route15Beauty2Text,       TEXT_ROUTE15_BEAUTY2
; PRET| 	dw_const Route15Biker1Text,        TEXT_ROUTE15_BIKER1
; PRET| 	dw_const Route15Biker2Text,        TEXT_ROUTE15_BIKER2
; PRET| 	dw_const Route15CooltrainerF3Text, TEXT_ROUTE15_COOLTRAINER_F3
; PRET| 	dw_const Route15CooltrainerF4Text, TEXT_ROUTE15_COOLTRAINER_F4
; PRET| 	dw_const PickUpItemText,           TEXT_ROUTE15_TM_RAGE
; PRET| 	dw_const Route15SignText,          TEXT_ROUTE15_SIGN
; PRET| 
; PRET| Route15TrainerHeaders:
; PRET| 	def_trainers
; PRET| Route15TrainerHeader0:
; PRET| 	trainer EVENT_BEAT_ROUTE_15_TRAINER_0, 2, Route15CooltrainerF1BattleText, Route15CooltrainerF1EndBattleText, Route15CooltrainerF1AfterBattleText
; PRET| Route15TrainerHeader1:
; PRET| 	trainer EVENT_BEAT_ROUTE_15_TRAINER_1, 3, Route15CooltrainerF2BattleText, Route15CooltrainerF2EndBattleText, Route15CooltrainerF2AfterBattleText
; PRET| Route15TrainerHeader2:
; PRET| 	trainer EVENT_BEAT_ROUTE_15_TRAINER_2, 3, Route15CooltrainerM1BattleText, Route15CooltrainerM1EndBattleText, Route15CooltrainerM1AfterBattleText
; PRET| Route15TrainerHeader3:
; PRET| 	trainer EVENT_BEAT_ROUTE_15_TRAINER_3, 3, Route15CooltrainerM2BattleText, Route15CooltrainerM2EndBattleText, Route15CooltrainerM2AfterBattleText
; PRET| Route15TrainerHeader4:
; PRET| 	trainer EVENT_BEAT_ROUTE_15_TRAINER_4, 2, Route15Beauty1BattleText, Route15Beauty1EndBattleText, Route15Beauty1AfterBattleText
; PRET| Route15TrainerHeader5:
; PRET| 	trainer EVENT_BEAT_ROUTE_15_TRAINER_5, 3, Route15Beauty2BattleText, Route15Beauty2EndBattleText, Route15Beauty2AfterBattleText
; PRET| Route15TrainerHeader6:
; PRET| 	trainer EVENT_BEAT_ROUTE_15_TRAINER_6, 3, Route15Biker1BattleText, Route15Biker1EndBattleText, Route15Biker1AfterBattleText
; PRET| Route15TrainerHeader7:
; PRET| 	trainer EVENT_BEAT_ROUTE_15_TRAINER_7, 3, Route15Biker2BattleText, Route15Biker2EndBattleText, Route15Biker2AfterBattleText
; PRET| Route15TrainerHeader8:
; PRET| 	trainer EVENT_BEAT_ROUTE_15_TRAINER_8, 3, Route15CooltrainerF3BattleText, Route15CooltrainerF3EndBattleText, Route15CooltrainerF3AfterBattleText
; PRET| Route15TrainerHeader9:
; PRET| 	trainer EVENT_BEAT_ROUTE_15_TRAINER_9, 3, Route15CooltrainerF4BattleText, Route15CooltrainerF4EndBattleText, Route15CooltrainerF4AfterBattleText
; PRET| 	db -1 ; end

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
; BAIL[owned-by-generated-assets] Route15CooltrainerF1BattleText (scripts/Route15.asm:108-229) — a generated asset already defines Route15CooltrainerF1BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route15CooltrainerF1BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route15CooltrainerF1EndBattleText:
; PRET| 	text_far _Route15CooltrainerF1EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route15CooltrainerF1AfterBattleText:
; PRET| 	text_far _Route15CooltrainerF1AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route15CooltrainerF2BattleText:
; PRET| 	text_far _Route15CooltrainerF2BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route15CooltrainerF2EndBattleText:
; PRET| 	text_far _Route15CooltrainerF2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route15CooltrainerF2AfterBattleText:
; PRET| 	text_far _Route15CooltrainerF2AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route15CooltrainerM1BattleText:
; PRET| 	text_far _Route15CooltrainerM1BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route15CooltrainerM1EndBattleText:
; PRET| 	text_far _Route15CooltrainerM1EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route15CooltrainerM1AfterBattleText:
; PRET| 	text_far _Route15CooltrainerM1AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route15CooltrainerM2BattleText:
; PRET| 	text_far _Route15CooltrainerM2BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route15CooltrainerM2EndBattleText:
; PRET| 	text_far _Route15CooltrainerM2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route15CooltrainerM2AfterBattleText:
; PRET| 	text_far _Route15CooltrainerM2AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route15Beauty1BattleText:
; PRET| 	text_far _Route15Beauty1BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route15Beauty1EndBattleText:
; PRET| 	text_far _Route15Beauty1EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route15Beauty1AfterBattleText:
; PRET| 	text_far _Route15Beauty1AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route15Beauty2BattleText:
; PRET| 	text_far _Route15Beauty2BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route15Beauty2EndBattleText:
; PRET| 	text_far _Route15Beauty2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route15Beauty2AfterBattleText:
; PRET| 	text_far _Route15Beauty2AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route15Biker1BattleText:
; PRET| 	text_far _Route15Biker1BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route15Biker1EndBattleText:
; PRET| 	text_far _Route15Biker1EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route15Biker1AfterBattleText:
; PRET| 	text_far _Route15Biker1AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route15Biker2BattleText:
; PRET| 	text_far _Route15Biker2BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route15Biker2EndBattleText:
; PRET| 	text_far _Route15Biker2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route15Biker2AfterBattleText:
; PRET| 	text_far _Route15Biker2AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route15CooltrainerF3BattleText:
; PRET| 	text_far _Route15CooltrainerF3BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route15CooltrainerF3EndBattleText:
; PRET| 	text_far _Route15CooltrainerF3EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route15CooltrainerF3AfterBattleText:
; PRET| 	text_far _Route15CooltrainerF3AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route15CooltrainerF4BattleText:
; PRET| 	text_far _Route15CooltrainerF4BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route15CooltrainerF4EndBattleText:
; PRET| 	text_far _Route15CooltrainerF4EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route15CooltrainerF4AfterBattleText:
; PRET| 	text_far _Route15CooltrainerF4AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route15SignText:
; PRET| 	text_far _Route15SignText
; PRET| 	text_end
