; Route9.asm — translated from pret scripts/Route9.asm by dos_port/tools/sm83xlat.
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


global Route9AJText
global Route9CooltrainerF1Text
global Route9CooltrainerF2Text
global Route9CooltrainerM2Text
global Route9Hiker1Text
global Route9Hiker2Text
global Route9Hiker3Text
global Route9TalkToTrainer
global Route9Youngster1Text
global Route9Youngster2Text
global Route9_Script

extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern PickUpItemText   ; NOT YET DEFINED IN THE PORT
extern Route9AJAfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route9AJBattleText   ; NOT YET DEFINED IN THE PORT
extern Route9AJEndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route9CooltrainerF1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route9CooltrainerF1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route9CooltrainerF1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route9CooltrainerF2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route9CooltrainerF2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route9CooltrainerF2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route9CooltrainerM2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route9CooltrainerM2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route9CooltrainerM2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route9Hiker1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route9Hiker1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route9Hiker1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route9Hiker2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route9Hiker2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route9Hiker2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route9Hiker3AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route9Hiker3BattleText   ; NOT YET DEFINED IN THE PORT
extern Route9Hiker3EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route9SignText   ; NOT YET DEFINED IN THE PORT
extern Route9TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern Route9TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern Route9TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern Route9TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern Route9TrainerHeader4   ; NOT YET DEFINED IN THE PORT
extern Route9TrainerHeader5   ; NOT YET DEFINED IN THE PORT
extern Route9TrainerHeader6   ; NOT YET DEFINED IN THE PORT
extern Route9TrainerHeader7   ; NOT YET DEFINED IN THE PORT
extern Route9TrainerHeader8   ; NOT YET DEFINED IN THE PORT
extern Route9TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern Route9Youngster1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route9Youngster1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route9Youngster1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route9Youngster2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route9Youngster2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route9Youngster2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route9_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern Route9_TextPointers   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_ROUTE9_DEFAULT                          equ 0
SCRIPT_ROUTE9_START_BATTLE                     equ 1
SCRIPT_ROUTE9_END_BATTLE                       equ 2
TEXT_ROUTE9_COOLTRAINER_F1                     equ 1
TEXT_ROUTE9_COOLTRAINER_M1                     equ 2
TEXT_ROUTE9_COOLTRAINER_M2                     equ 3
TEXT_ROUTE9_COOLTRAINER_F2                     equ 4
TEXT_ROUTE9_HIKER1                             equ 5
TEXT_ROUTE9_HIKER2                             equ 6
TEXT_ROUTE9_YOUNGSTER1                         equ 7
TEXT_ROUTE9_HIKER3                             equ 8
TEXT_ROUTE9_YOUNGSTER2                         equ 9
TEXT_ROUTE9_TM_TELEPORT                        equ 10
TEXT_ROUTE9_SIGN                               equ 11

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wRoute9CurScript                               equ 0xD603

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

Route9_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route9TrainerHeaders
    mov edi, Route9_ScriptPointers   ; pret: ld de, Route9_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRoute9CurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRoute9CurScript], al
    ret

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route9_ScriptPointers (scripts/Route9.asm:11-50) — a generated asset already defines Route9_ScriptPointers
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	def_script_pointers
; PRET| 	dw_const CheckFightingMapTrainers,              SCRIPT_ROUTE9_DEFAULT
; PRET| 	dw_const DisplayEnemyTrainerTextAndStartBattle, SCRIPT_ROUTE9_START_BATTLE
; PRET| 	dw_const EndTrainerBattle,                      SCRIPT_ROUTE9_END_BATTLE
; PRET| 
; PRET| Route9_TextPointers:
; PRET| 	def_text_pointers
; PRET| 	dw_const Route9CooltrainerF1Text, TEXT_ROUTE9_COOLTRAINER_F1
; PRET| 	dw_const Route9AJText,            TEXT_ROUTE9_COOLTRAINER_M1
; PRET| 	dw_const Route9CooltrainerM2Text, TEXT_ROUTE9_COOLTRAINER_M2
; PRET| 	dw_const Route9CooltrainerF2Text, TEXT_ROUTE9_COOLTRAINER_F2
; PRET| 	dw_const Route9Hiker1Text,        TEXT_ROUTE9_HIKER1
; PRET| 	dw_const Route9Hiker2Text,        TEXT_ROUTE9_HIKER2
; PRET| 	dw_const Route9Youngster1Text,    TEXT_ROUTE9_YOUNGSTER1
; PRET| 	dw_const Route9Hiker3Text,        TEXT_ROUTE9_HIKER3
; PRET| 	dw_const Route9Youngster2Text,    TEXT_ROUTE9_YOUNGSTER2
; PRET| 	dw_const PickUpItemText,          TEXT_ROUTE9_TM_TELEPORT
; PRET| 	dw_const Route9SignText,          TEXT_ROUTE9_SIGN
; PRET| 
; PRET| Route9TrainerHeaders:
; PRET| 	def_trainers
; PRET| Route9TrainerHeader0:
; PRET| 	trainer EVENT_BEAT_ROUTE_9_TRAINER_0, 3, Route9CooltrainerF1BattleText, Route9CooltrainerF1EndBattleText, Route9CooltrainerF1AfterBattleText
; PRET| Route9TrainerHeader1:
; PRET| 	trainer EVENT_BEAT_ROUTE_9_TRAINER_1, 2, Route9AJBattleText, Route9AJEndBattleText, Route9AJAfterBattleText
; PRET| Route9TrainerHeader2:
; PRET| 	trainer EVENT_BEAT_ROUTE_9_TRAINER_2, 4, Route9CooltrainerM2BattleText, Route9CooltrainerM2EndBattleText, Route9CooltrainerM2AfterBattleText
; PRET| Route9TrainerHeader3:
; PRET| 	trainer EVENT_BEAT_ROUTE_9_TRAINER_3, 2, Route9CooltrainerF2BattleText, Route9CooltrainerF2EndBattleText, Route9CooltrainerF2AfterBattleText
; PRET| Route9TrainerHeader4:
; PRET| 	trainer EVENT_BEAT_ROUTE_9_TRAINER_4, 2, Route9Hiker1BattleText, Route9Hiker1EndBattleText, Route9Hiker1AfterBattleText
; PRET| Route9TrainerHeader5:
; PRET| 	trainer EVENT_BEAT_ROUTE_9_TRAINER_5, 3, Route9Hiker2BattleText, Route9Hiker2EndBattleText, Route9Hiker2AfterBattleText
; PRET| Route9TrainerHeader6:
; PRET| 	trainer EVENT_BEAT_ROUTE_9_TRAINER_6, 4, Route9Youngster1BattleText, Route9Youngster1EndBattleText, Route9Youngster1AfterBattleText
; PRET| Route9TrainerHeader7:
; PRET| 	trainer EVENT_BEAT_ROUTE_9_TRAINER_7, 2, Route9Hiker3BattleText, Route9Hiker3EndBattleText, Route9Hiker3AfterBattleText
; PRET| Route9TrainerHeader8:
; PRET| 	trainer EVENT_BEAT_ROUTE_9_TRAINER_8, 2, Route9Youngster2BattleText, Route9Youngster2EndBattleText, Route9Youngster2AfterBattleText
; PRET| 	db -1 ; end

Route9CooltrainerF1Text:
    mov esi, Route9TrainerHeader0
    jmp Route9TalkToTrainer

Route9AJText:
    mov esi, Route9TrainerHeader1
    jmp Route9TalkToTrainer

Route9CooltrainerM2Text:
    mov esi, Route9TrainerHeader2
    jmp Route9TalkToTrainer

Route9CooltrainerF2Text:
    mov esi, Route9TrainerHeader3
    jmp Route9TalkToTrainer

Route9Hiker1Text:
    mov esi, Route9TrainerHeader4
    jmp Route9TalkToTrainer

Route9Hiker2Text:
    mov esi, Route9TrainerHeader5
    jmp Route9TalkToTrainer

Route9Youngster1Text:
    mov esi, Route9TrainerHeader6
    jmp Route9TalkToTrainer

Route9Hiker3Text:
    mov esi, Route9TrainerHeader7
    jmp Route9TalkToTrainer

Route9Youngster2Text:
    mov esi, Route9TrainerHeader8
Route9TalkToTrainer:
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route9CooltrainerF1BattleText (scripts/Route9.asm:100-209) — a generated asset already defines Route9CooltrainerF1BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route9CooltrainerF1BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route9CooltrainerF1EndBattleText:
; PRET| 	text_far _Route9CooltrainerF1EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route9CooltrainerF1AfterBattleText:
; PRET| 	text_far _Route9CooltrainerF1AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route9AJBattleText:
; PRET| 	text_far _Route9AJBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route9AJEndBattleText:
; PRET| 	text_far _Route9AJEndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route9AJAfterBattleText:
; PRET| 	text_far _Route9AJAfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route9CooltrainerM2BattleText:
; PRET| 	text_far _Route9CooltrainerM2BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route9CooltrainerM2EndBattleText:
; PRET| 	text_far _Route9CooltrainerM2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route9CooltrainerM2AfterBattleText:
; PRET| 	text_far _Route9CooltrainerM2AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route9CooltrainerF2BattleText:
; PRET| 	text_far _Route9CooltrainerF2BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route9CooltrainerF2EndBattleText:
; PRET| 	text_far _Route9CooltrainerF2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route9CooltrainerF2AfterBattleText:
; PRET| 	text_far _Route9CooltrainerF2AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route9Hiker1BattleText:
; PRET| 	text_far _Route9Hiker1BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route9Hiker1EndBattleText:
; PRET| 	text_far _Route9Hiker1EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route9Hiker1AfterBattleText:
; PRET| 	text_far _Route9Hiker1AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route9Hiker2BattleText:
; PRET| 	text_far _Route9Hiker2BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route9Hiker2EndBattleText:
; PRET| 	text_far _Route9Hiker2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route9Hiker2AfterBattleText:
; PRET| 	text_far _Route9Hiker2AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route9Youngster1BattleText:
; PRET| 	text_far _Route9Youngster1BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route9Youngster1EndBattleText:
; PRET| 	text_far _Route9Youngster1EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route9Youngster1AfterBattleText:
; PRET| 	text_far _Route9Youngster1AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route9Hiker3BattleText:
; PRET| 	text_far _Route9Hiker3BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route9Hiker3EndBattleText:
; PRET| 	text_far _Route9Hiker3EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route9Hiker3AfterBattleText:
; PRET| 	text_far _Route9Hiker3AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route9Youngster2BattleText:
; PRET| 	text_far _Route9Youngster2BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route9Youngster2EndBattleText:
; PRET| 	text_far _Route9Youngster2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route9Youngster2AfterBattleText:
; PRET| 	text_far _Route9Youngster2AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route9SignText:
; PRET| 	text_far _Route9SignText
; PRET| 	text_end
