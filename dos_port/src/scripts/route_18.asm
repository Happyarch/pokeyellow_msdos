; Route18.asm — translated from pret scripts/Route18.asm by dos_port/tools/sm83xlat.
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


global Route18CooltrainerM1Text
global Route18CooltrainerM2Text
global Route18CooltrainerM3Text
global Route18_Script

extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern Route18CooltrainerM1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route18CooltrainerM1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route18CooltrainerM1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route18CooltrainerM2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route18CooltrainerM2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route18CooltrainerM2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route18CooltrainerM3AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route18CooltrainerM3BattleText   ; NOT YET DEFINED IN THE PORT
extern Route18CooltrainerM3EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route18CyclingRoadSignText   ; NOT YET DEFINED IN THE PORT
extern Route18SignText   ; NOT YET DEFINED IN THE PORT
extern Route18TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern Route18TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern Route18TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern Route18TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern Route18_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern Route18_TextPointers   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_ROUTE18_DEFAULT                         equ 0
SCRIPT_ROUTE18_START_BATTLE                    equ 1
SCRIPT_ROUTE18_END_BATTLE                      equ 2
TEXT_ROUTE18_COOLTRAINER_M1                    equ 1
TEXT_ROUTE18_COOLTRAINER_M2                    equ 2
TEXT_ROUTE18_COOLTRAINER_M3                    equ 3
TEXT_ROUTE18_SIGN                              equ 4
TEXT_ROUTE18_CYCLING_ROAD_SIGN                 equ 5

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wRoute18CurScript                              equ 0xD626

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

Route18_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route18TrainerHeaders
    mov edi, Route18_ScriptPointers   ; pret: ld de, Route18_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRoute18CurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRoute18CurScript], al
    ret

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route18_ScriptPointers (scripts/Route18.asm:11-32) — a generated asset already defines Route18_ScriptPointers
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	def_script_pointers
; PRET| 	dw_const CheckFightingMapTrainers,              SCRIPT_ROUTE18_DEFAULT
; PRET| 	dw_const DisplayEnemyTrainerTextAndStartBattle, SCRIPT_ROUTE18_START_BATTLE
; PRET| 	dw_const EndTrainerBattle,                      SCRIPT_ROUTE18_END_BATTLE
; PRET| 
; PRET| Route18_TextPointers:
; PRET| 	def_text_pointers
; PRET| 	dw_const Route18CooltrainerM1Text,   TEXT_ROUTE18_COOLTRAINER_M1
; PRET| 	dw_const Route18CooltrainerM2Text,   TEXT_ROUTE18_COOLTRAINER_M2
; PRET| 	dw_const Route18CooltrainerM3Text,   TEXT_ROUTE18_COOLTRAINER_M3
; PRET| 	dw_const Route18SignText,            TEXT_ROUTE18_SIGN
; PRET| 	dw_const Route18CyclingRoadSignText, TEXT_ROUTE18_CYCLING_ROAD_SIGN
; PRET| 
; PRET| Route18TrainerHeaders:
; PRET| 	def_trainers
; PRET| Route18TrainerHeader0:
; PRET| 	trainer EVENT_BEAT_ROUTE_18_TRAINER_0, 3, Route18CooltrainerM1BattleText, Route18CooltrainerM1EndBattleText, Route18CooltrainerM1AfterBattleText
; PRET| Route18TrainerHeader1:
; PRET| 	trainer EVENT_BEAT_ROUTE_18_TRAINER_1, 3, Route18CooltrainerM2BattleText, Route18CooltrainerM2EndBattleText, Route18CooltrainerM2AfterBattleText
; PRET| Route18TrainerHeader2:
; PRET| 	trainer EVENT_BEAT_ROUTE_18_TRAINER_2, 4, Route18CooltrainerM3BattleText, Route18CooltrainerM3EndBattleText, Route18CooltrainerM3AfterBattleText
; PRET| 	db -1 ; end

Route18CooltrainerM1Text:
    mov esi, Route18TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route18CooltrainerM1BattleText (scripts/Route18.asm:41-50) — a generated asset already defines Route18CooltrainerM1BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route18CooltrainerM1BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route18CooltrainerM1EndBattleText:
; PRET| 	text_far _Route18CooltrainerM1EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route18CooltrainerM1AfterBattleText:
; PRET| 	text_far _Route18CooltrainerM1AfterBattleText
; PRET| 	text_end

Route18CooltrainerM2Text:
    mov esi, Route18TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route18CooltrainerM2BattleText (scripts/Route18.asm:59-68) — a generated asset already defines Route18CooltrainerM2BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route18CooltrainerM2BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route18CooltrainerM2EndBattleText:
; PRET| 	text_far _Route18CooltrainerM2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route18CooltrainerM2AfterBattleText:
; PRET| 	text_far _Route18CooltrainerM2AfterBattleText
; PRET| 	text_end

Route18CooltrainerM3Text:
    mov esi, Route18TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route18CooltrainerM3BattleText (scripts/Route18.asm:77-94) — a generated asset already defines Route18CooltrainerM3BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route18CooltrainerM3BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route18CooltrainerM3EndBattleText:
; PRET| 	text_far _Route18CooltrainerM3EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route18CooltrainerM3AfterBattleText:
; PRET| 	text_far _Route18CooltrainerM3AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route18SignText:
; PRET| 	text_far _Route18SignText
; PRET| 	text_end
; PRET| 
; PRET| Route18CyclingRoadSignText:
; PRET| 	text_far _Route18CyclingRoadSignText
; PRET| 	text_end
