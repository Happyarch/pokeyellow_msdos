; Route19.asm — translated from pret scripts/Route19.asm by dos_port/tools/sm83xlat.
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


global Route19CooltrainerM1Text
global Route19CooltrainerM2Text
global Route19Swimmer1Text
global Route19Swimmer2Text
global Route19Swimmer3Text
global Route19Swimmer4Text
global Route19Swimmer5Text
global Route19Swimmer6Text
global Route19Swimmer7Text
global Route19Swimmer8Text
global Route19_Script
global Route19_TalkToTrainer

extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern Route19CooltrainerM1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route19CooltrainerM1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route19CooltrainerM1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route19CooltrainerM2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route19CooltrainerM2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route19CooltrainerM2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route19SignText   ; NOT YET DEFINED IN THE PORT
extern Route19Swimmer1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route19Swimmer1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route19Swimmer1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route19Swimmer2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route19Swimmer2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route19Swimmer2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route19Swimmer3AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route19Swimmer3BattleText   ; NOT YET DEFINED IN THE PORT
extern Route19Swimmer3EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route19Swimmer4AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route19Swimmer4BattleText   ; NOT YET DEFINED IN THE PORT
extern Route19Swimmer4EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route19Swimmer5AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route19Swimmer5BattleText   ; NOT YET DEFINED IN THE PORT
extern Route19Swimmer5EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route19Swimmer6AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route19Swimmer6BattleText   ; NOT YET DEFINED IN THE PORT
extern Route19Swimmer6EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route19Swimmer7AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route19Swimmer7BattleText   ; NOT YET DEFINED IN THE PORT
extern Route19Swimmer7EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route19Swimmer8AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route19Swimmer8BattleText   ; NOT YET DEFINED IN THE PORT
extern Route19Swimmer8EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route19TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern Route19TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern Route19TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern Route19TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern Route19TrainerHeader4   ; NOT YET DEFINED IN THE PORT
extern Route19TrainerHeader5   ; NOT YET DEFINED IN THE PORT
extern Route19TrainerHeader6   ; NOT YET DEFINED IN THE PORT
extern Route19TrainerHeader7   ; NOT YET DEFINED IN THE PORT
extern Route19TrainerHeader8   ; NOT YET DEFINED IN THE PORT
extern Route19TrainerHeader9   ; NOT YET DEFINED IN THE PORT
extern Route19TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern Route19_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern Route19_TextPointers   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_ROUTE19_DEFAULT                         equ 0
SCRIPT_ROUTE19_START_BATTLE                    equ 1
SCRIPT_ROUTE19_END_BATTLE                      equ 2
TEXT_ROUTE19_COOLTRAINER_M1                    equ 1
TEXT_ROUTE19_COOLTRAINER_M2                    equ 2
TEXT_ROUTE19_SWIMMER1                          equ 3
TEXT_ROUTE19_SWIMMER2                          equ 4
TEXT_ROUTE19_SWIMMER3                          equ 5
TEXT_ROUTE19_SWIMMER4                          equ 6
TEXT_ROUTE19_SWIMMER5                          equ 7
TEXT_ROUTE19_SWIMMER6                          equ 8
TEXT_ROUTE19_SWIMMER7                          equ 9
TEXT_ROUTE19_SWIMMER8                          equ 10
TEXT_ROUTE19_SIGN                              equ 11

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wRoute19CurScript                              equ 0xD61C

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

Route19_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route19TrainerHeaders
    mov edi, Route19_ScriptPointers   ; pret: ld de, Route19_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRoute19CurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRoute19CurScript], al
    ret

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route19_ScriptPointers (scripts/Route19.asm:11-52) — a generated asset already defines Route19_ScriptPointers
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	def_script_pointers
; PRET| 	dw_const CheckFightingMapTrainers,              SCRIPT_ROUTE19_DEFAULT
; PRET| 	dw_const DisplayEnemyTrainerTextAndStartBattle, SCRIPT_ROUTE19_START_BATTLE
; PRET| 	dw_const EndTrainerBattle,                      SCRIPT_ROUTE19_END_BATTLE
; PRET| 
; PRET| Route19_TextPointers:
; PRET| 	def_text_pointers
; PRET| 	dw_const Route19CooltrainerM1Text, TEXT_ROUTE19_COOLTRAINER_M1
; PRET| 	dw_const Route19CooltrainerM2Text, TEXT_ROUTE19_COOLTRAINER_M2
; PRET| 	dw_const Route19Swimmer1Text,      TEXT_ROUTE19_SWIMMER1
; PRET| 	dw_const Route19Swimmer2Text,      TEXT_ROUTE19_SWIMMER2
; PRET| 	dw_const Route19Swimmer3Text,      TEXT_ROUTE19_SWIMMER3
; PRET| 	dw_const Route19Swimmer4Text,      TEXT_ROUTE19_SWIMMER4
; PRET| 	dw_const Route19Swimmer5Text,      TEXT_ROUTE19_SWIMMER5
; PRET| 	dw_const Route19Swimmer6Text,      TEXT_ROUTE19_SWIMMER6
; PRET| 	dw_const Route19Swimmer7Text,      TEXT_ROUTE19_SWIMMER7
; PRET| 	dw_const Route19Swimmer8Text,      TEXT_ROUTE19_SWIMMER8
; PRET| 	dw_const Route19SignText,          TEXT_ROUTE19_SIGN
; PRET| 
; PRET| Route19TrainerHeaders:
; PRET| 	def_trainers
; PRET| Route19TrainerHeader0:
; PRET| 	trainer EVENT_BEAT_ROUTE_19_TRAINER_0, 4, Route19CooltrainerM1BattleText, Route19CooltrainerM1EndBattleText, Route19CooltrainerM1AfterBattleText
; PRET| Route19TrainerHeader1:
; PRET| 	trainer EVENT_BEAT_ROUTE_19_TRAINER_1, 4, Route19CooltrainerM2BattleText, Route19CooltrainerM2EndBattleText, Route19CooltrainerM2AfterBattleText
; PRET| Route19TrainerHeader2:
; PRET| 	trainer EVENT_BEAT_ROUTE_19_TRAINER_2, 3, Route19Swimmer1BattleText, Route19Swimmer1EndBattleText, Route19Swimmer1AfterBattleText
; PRET| Route19TrainerHeader3:
; PRET| 	trainer EVENT_BEAT_ROUTE_19_TRAINER_3, 4, Route19Swimmer2BattleText, Route19Swimmer2EndBattleText, Route19Swimmer2AfterBattleText
; PRET| Route19TrainerHeader4:
; PRET| 	trainer EVENT_BEAT_ROUTE_19_TRAINER_4, 4, Route19Swimmer3BattleText, Route19Swimmer3EndBattleText, Route19Swimmer3AfterBattleText
; PRET| Route19TrainerHeader5:
; PRET| 	trainer EVENT_BEAT_ROUTE_19_TRAINER_5, 4, Route19Swimmer4BattleText, Route19Swimmer4EndBattleText, Route19Swimmer4AfterBattleText
; PRET| Route19TrainerHeader6:
; PRET| 	trainer EVENT_BEAT_ROUTE_19_TRAINER_6, 3, Route19Swimmer5BattleText, Route19Swimmer5EndBattleText, Route19Swimmer5AfterBattleText
; PRET| Route19TrainerHeader7:
; PRET| 	trainer EVENT_BEAT_ROUTE_19_TRAINER_7, 4, Route19Swimmer6BattleText, Route19Swimmer6EndBattleText, Route19Swimmer6AfterBattleText
; PRET| Route19TrainerHeader8:
; PRET| 	trainer EVENT_BEAT_ROUTE_19_TRAINER_8, 4, Route19Swimmer7BattleText, Route19Swimmer7EndBattleText, Route19Swimmer7AfterBattleText
; PRET| Route19TrainerHeader9:
; PRET| 	trainer EVENT_BEAT_ROUTE_19_TRAINER_9, 4, Route19Swimmer8BattleText, Route19Swimmer8EndBattleText, Route19Swimmer8AfterBattleText
; PRET| 	db -1 ; end

Route19CooltrainerM1Text:
    mov esi, Route19TrainerHeader0
    jmp Route19_TalkToTrainer

Route19CooltrainerM2Text:
    mov esi, Route19TrainerHeader1
    jmp Route19_TalkToTrainer

Route19Swimmer1Text:
    mov esi, Route19TrainerHeader2
    jmp Route19_TalkToTrainer

Route19Swimmer2Text:
    mov esi, Route19TrainerHeader3
    jmp Route19_TalkToTrainer

Route19Swimmer3Text:
    mov esi, Route19TrainerHeader4
    jmp Route19_TalkToTrainer

Route19Swimmer4Text:
    mov esi, Route19TrainerHeader5
    jmp Route19_TalkToTrainer

Route19Swimmer5Text:
    mov esi, Route19TrainerHeader6
    jmp Route19_TalkToTrainer

Route19Swimmer6Text:
    mov esi, Route19TrainerHeader7
    jmp Route19_TalkToTrainer

Route19Swimmer7Text:
    mov esi, Route19TrainerHeader8
    jmp Route19_TalkToTrainer

Route19Swimmer8Text:
    mov esi, Route19TrainerHeader9
Route19_TalkToTrainer:
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route19CooltrainerM1BattleText (scripts/Route19.asm:107-228) — a generated asset already defines Route19CooltrainerM1BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route19CooltrainerM1BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route19CooltrainerM1EndBattleText:
; PRET| 	text_far _Route19CooltrainerM1EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route19CooltrainerM1AfterBattleText:
; PRET| 	text_far _Route19CooltrainerM1AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route19CooltrainerM2BattleText:
; PRET| 	text_far _Route19CooltrainerM2BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route19CooltrainerM2EndBattleText:
; PRET| 	text_far _Route19CooltrainerM2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route19CooltrainerM2AfterBattleText:
; PRET| 	text_far _Route19CooltrainerM2AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route19Swimmer1BattleText:
; PRET| 	text_far _Route19Swimmer1BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route19Swimmer1EndBattleText:
; PRET| 	text_far _Route19Swimmer1EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route19Swimmer1AfterBattleText:
; PRET| 	text_far _Route19Swimmer1AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route19Swimmer2BattleText:
; PRET| 	text_far _Route19Swimmer2BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route19Swimmer2EndBattleText:
; PRET| 	text_far _Route19Swimmer2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route19Swimmer2AfterBattleText:
; PRET| 	text_far _Route19Swimmer2AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route19Swimmer3BattleText:
; PRET| 	text_far _Route19Swimmer3BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route19Swimmer3EndBattleText:
; PRET| 	text_far _Route19Swimmer3EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route19Swimmer3AfterBattleText:
; PRET| 	text_far _Route19Swimmer3AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route19Swimmer4BattleText:
; PRET| 	text_far _Route19Swimmer4BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route19Swimmer4EndBattleText:
; PRET| 	text_far _Route19Swimmer4EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route19Swimmer4AfterBattleText:
; PRET| 	text_far _Route19Swimmer4AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route19Swimmer5BattleText:
; PRET| 	text_far _Route19Swimmer5BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route19Swimmer5EndBattleText:
; PRET| 	text_far _Route19Swimmer5EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route19Swimmer5AfterBattleText:
; PRET| 	text_far _Route19Swimmer5AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route19Swimmer6BattleText:
; PRET| 	text_far _Route19Swimmer6BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route19Swimmer6EndBattleText:
; PRET| 	text_far _Route19Swimmer6EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route19Swimmer6AfterBattleText:
; PRET| 	text_far _Route19Swimmer6AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route19Swimmer7BattleText:
; PRET| 	text_far _Route19Swimmer7BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route19Swimmer7EndBattleText:
; PRET| 	text_far _Route19Swimmer7EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route19Swimmer7AfterBattleText:
; PRET| 	text_far _Route19Swimmer7AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route19Swimmer8BattleText:
; PRET| 	text_far _Route19Swimmer8BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route19Swimmer8EndBattleText:
; PRET| 	text_far _Route19Swimmer8EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route19Swimmer8AfterBattleText:
; PRET| 	text_far _Route19Swimmer8AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route19SignText:
; PRET| 	text_far _Route19SignText
; PRET| 	text_end
