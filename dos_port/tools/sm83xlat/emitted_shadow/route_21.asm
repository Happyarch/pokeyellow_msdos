; Route21.asm — translated from pret scripts/Route21.asm by dos_port/tools/sm83xlat.
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


global Route21Fisher1Text
global Route21Fisher2Text
global Route21Fisher3Text
global Route21Fisher4Text
global Route21Swimmer1Text
global Route21Swimmer2Text
global Route21Swimmer3Text
global Route21Swimmer4Text
global Route21Swimmer5Text
global Route21_Script

extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern Route21Fisher1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Fisher1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Fisher1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Fisher2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Fisher2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Fisher2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Fisher3AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Fisher3BattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Fisher3EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Fisher4AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Fisher4BattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Fisher4EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Swimmer1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Swimmer1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Swimmer1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Swimmer2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Swimmer2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Swimmer2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Swimmer3AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Swimmer3BattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Swimmer3EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Swimmer4AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Swimmer4BattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Swimmer4EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Swimmer5AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Swimmer5BattleText   ; NOT YET DEFINED IN THE PORT
extern Route21Swimmer5EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route21TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern Route21TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern Route21TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern Route21TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern Route21TrainerHeader4   ; NOT YET DEFINED IN THE PORT
extern Route21TrainerHeader5   ; NOT YET DEFINED IN THE PORT
extern Route21TrainerHeader6   ; NOT YET DEFINED IN THE PORT
extern Route21TrainerHeader7   ; NOT YET DEFINED IN THE PORT
extern Route21TrainerHeader8   ; NOT YET DEFINED IN THE PORT
extern Route21TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern Route21_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern Route21_TextPointers   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_ROUTE21_DEFAULT                         equ 0
SCRIPT_ROUTE21_START_BATTLE                    equ 1
SCRIPT_ROUTE21_END_BATTLE                      equ 2
TEXT_ROUTE21_FISHER1                           equ 1
TEXT_ROUTE21_FISHER2                           equ 2
TEXT_ROUTE21_SWIMMER1                          equ 3
TEXT_ROUTE21_SWIMMER2                          equ 4
TEXT_ROUTE21_SWIMMER3                          equ 5
TEXT_ROUTE21_SWIMMER4                          equ 6
TEXT_ROUTE21_SWIMMER5                          equ 7
TEXT_ROUTE21_FISHER3                           equ 8
TEXT_ROUTE21_FISHER4                           equ 9

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wRoute21CurScript                              equ 0xD61D

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

Route21_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route21TrainerHeaders
    mov edi, Route21_ScriptPointers   ; pret: ld de, Route21_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRoute21CurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRoute21CurScript], al
    ret

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route21_ScriptPointers (scripts/Route21.asm:11-48) — a generated asset already defines Route21_ScriptPointers
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	def_script_pointers
; PRET| 	dw_const CheckFightingMapTrainers,              SCRIPT_ROUTE21_DEFAULT
; PRET| 	dw_const DisplayEnemyTrainerTextAndStartBattle, SCRIPT_ROUTE21_START_BATTLE
; PRET| 	dw_const EndTrainerBattle,                      SCRIPT_ROUTE21_END_BATTLE
; PRET| 
; PRET| Route21_TextPointers:
; PRET| 	def_text_pointers
; PRET| 	dw_const Route21Fisher1Text,  TEXT_ROUTE21_FISHER1
; PRET| 	dw_const Route21Fisher2Text,  TEXT_ROUTE21_FISHER2
; PRET| 	dw_const Route21Swimmer1Text, TEXT_ROUTE21_SWIMMER1
; PRET| 	dw_const Route21Swimmer2Text, TEXT_ROUTE21_SWIMMER2
; PRET| 	dw_const Route21Swimmer3Text, TEXT_ROUTE21_SWIMMER3
; PRET| 	dw_const Route21Swimmer4Text, TEXT_ROUTE21_SWIMMER4
; PRET| 	dw_const Route21Swimmer5Text, TEXT_ROUTE21_SWIMMER5
; PRET| 	dw_const Route21Fisher3Text,  TEXT_ROUTE21_FISHER3
; PRET| 	dw_const Route21Fisher4Text,  TEXT_ROUTE21_FISHER4
; PRET| 
; PRET| Route21TrainerHeaders:
; PRET| 	def_trainers
; PRET| Route21TrainerHeader0:
; PRET| 	trainer EVENT_BEAT_ROUTE_21_TRAINER_0, 0, Route21Fisher1BattleText, Route21Fisher1EndBattleText, Route21Fisher1AfterBattleText
; PRET| Route21TrainerHeader1:
; PRET| 	trainer EVENT_BEAT_ROUTE_21_TRAINER_1, 0, Route21Fisher2BattleText, Route21Fisher2EndBattleText, Route21Fisher2AfterBattleText
; PRET| Route21TrainerHeader2:
; PRET| 	trainer EVENT_BEAT_ROUTE_21_TRAINER_2, 4, Route21Swimmer1BattleText, Route21Swimmer1EndBattleText, Route21Swimmer1AfterBattleText
; PRET| Route21TrainerHeader3:
; PRET| 	trainer EVENT_BEAT_ROUTE_21_TRAINER_3, 4, Route21Swimmer2BattleText, Route21Swimmer2EndBattleText, Route21Swimmer2AfterBattleText
; PRET| Route21TrainerHeader4:
; PRET| 	trainer EVENT_BEAT_ROUTE_21_TRAINER_4, 4, Route21Swimmer3BattleText, Route21Swimmer3EndBattleText, Route21Swimmer3AfterBattleText
; PRET| Route21TrainerHeader5:
; PRET| 	trainer EVENT_BEAT_ROUTE_21_TRAINER_5, 4, Route21Swimmer4BattleText, Route21Swimmer4EndBattleText, Route21Swimmer4AfterBattleText
; PRET| Route21TrainerHeader6:
; PRET| 	trainer EVENT_BEAT_ROUTE_21_TRAINER_6, 3, Route21Swimmer5BattleText, Route21Swimmer5EndBattleText, Route21Swimmer5AfterBattleText
; PRET| Route21TrainerHeader7:
; PRET| 	trainer EVENT_BEAT_ROUTE_21_TRAINER_7, 0, Route21Fisher3BattleText, Route21Fisher3EndBattleText, Route21Fisher3AfterBattleText
; PRET| Route21TrainerHeader8:
; PRET| 	trainer EVENT_BEAT_ROUTE_21_TRAINER_8, 0, Route21Fisher4BattleText, Route21Fisher4EndBattleText, Route21Fisher4AfterBattleText
; PRET| 	db -1 ; end

Route21Fisher1Text:
    mov esi, Route21TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

Route21Fisher2Text:
    mov esi, Route21TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

Route21Swimmer1Text:
    mov esi, Route21TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

Route21Swimmer2Text:
    mov esi, Route21TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

Route21Swimmer3Text:
    mov esi, Route21TrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

Route21Swimmer4Text:
    mov esi, Route21TrainerHeader5
    call TalkToTrainer
    jmp TextScriptEnd

Route21Swimmer5Text:
    mov esi, Route21TrainerHeader6
    call TalkToTrainer
    jmp TextScriptEnd

Route21Fisher3Text:
    mov esi, Route21TrainerHeader7
    call TalkToTrainer
    jmp TextScriptEnd

Route21Fisher4Text:
    mov esi, Route21TrainerHeader8
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route21Fisher1BattleText (scripts/Route21.asm:105-210) — a generated asset already defines Route21Fisher1BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route21Fisher1BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route21Fisher1EndBattleText:
; PRET| 	text_far _Route21Fisher1EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route21Fisher1AfterBattleText:
; PRET| 	text_far _Route21Fisher1AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route21Fisher2BattleText:
; PRET| 	text_far _Route21Fisher2BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route21Fisher2EndBattleText:
; PRET| 	text_far _Route21Fisher2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route21Fisher2AfterBattleText:
; PRET| 	text_far _Route21Fisher2AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route21Swimmer1BattleText:
; PRET| 	text_far _Route21Swimmer1BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route21Swimmer1EndBattleText:
; PRET| 	text_far _Route21Swimmer1EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route21Swimmer1AfterBattleText:
; PRET| 	text_far _Route21Swimmer1AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route21Swimmer2BattleText:
; PRET| 	text_far _Route21Swimmer2BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route21Swimmer2EndBattleText:
; PRET| 	text_far _Route21Swimmer2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route21Swimmer2AfterBattleText:
; PRET| 	text_far _Route21Swimmer2AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route21Swimmer3BattleText:
; PRET| 	text_far _Route21Swimmer3BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route21Swimmer3EndBattleText:
; PRET| 	text_far _Route21Swimmer3EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route21Swimmer3AfterBattleText:
; PRET| 	text_far _Route21Swimmer3AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route21Swimmer4BattleText:
; PRET| 	text_far _Route21Swimmer4BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route21Swimmer4EndBattleText:
; PRET| 	text_far _Route21Swimmer4EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route21Swimmer4AfterBattleText:
; PRET| 	text_far _Route21Swimmer4AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route21Swimmer5BattleText:
; PRET| 	text_far _Route21Swimmer5BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route21Swimmer5EndBattleText:
; PRET| 	text_far _Route21Swimmer5EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route21Swimmer5AfterBattleText:
; PRET| 	text_far _Route21Swimmer5AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route21Fisher3BattleText:
; PRET| 	text_far _Route21Fisher3BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route21Fisher3EndBattleText:
; PRET| 	text_far _Route21Fisher3EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route21Fisher3AfterBattleText:
; PRET| 	text_far _Route21Fisher3AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route21Fisher4BattleText:
; PRET| 	text_far _Route21Fisher4BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route21Fisher4EndBattleText:
; PRET| 	text_far _Route21Fisher4EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route21Fisher4AfterBattleText:
; PRET| 	text_far _Route21Fisher4AfterBattleText
; PRET| 	text_end
