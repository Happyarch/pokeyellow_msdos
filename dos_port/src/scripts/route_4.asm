; Route4.asm — translated from pret scripts/Route4.asm by dos_port/tools/sm83xlat.
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


global Route4CooltrainerF2Text
global Route4_Script

extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern PickUpItemText   ; NOT YET DEFINED IN THE PORT
extern Route4CooltrainerF1Text   ; NOT YET DEFINED IN THE PORT
extern Route4CooltrainerF2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route4CooltrainerF2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route4CooltrainerF2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route4MtMoonSignText   ; NOT YET DEFINED IN THE PORT
extern Route4SignText   ; NOT YET DEFINED IN THE PORT
extern Route4TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern Route4TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern Route4_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern Route4_TextPointers   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_ROUTE4_DEFAULT                          equ 0
SCRIPT_ROUTE4_START_BATTLE                     equ 1
SCRIPT_ROUTE4_END_BATTLE                       equ 2
TEXT_ROUTE4_COOLTRAINER_F1                     equ 1
TEXT_ROUTE4_COOLTRAINER_F2                     equ 2
TEXT_ROUTE4_TM_WHIRLWIND                       equ 3
TEXT_ROUTE4_POKECENTER_SIGN                    equ 4
TEXT_ROUTE4_MT_MOON_SIGN                       equ 5
TEXT_ROUTE4_SIGN                               equ 6

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wRoute4CurScript                               equ 0xD5F8

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

Route4_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route4TrainerHeaders
    mov edi, Route4_ScriptPointers   ; pret: ld de, Route4_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRoute4CurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRoute4CurScript], al
    ret

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route4_ScriptPointers (scripts/Route4.asm:11-33) — a generated asset already defines Route4_ScriptPointers
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	def_script_pointers
; PRET| 	dw_const CheckFightingMapTrainers,              SCRIPT_ROUTE4_DEFAULT
; PRET| 	dw_const DisplayEnemyTrainerTextAndStartBattle, SCRIPT_ROUTE4_START_BATTLE
; PRET| 	dw_const EndTrainerBattle,                      SCRIPT_ROUTE4_END_BATTLE
; PRET| 
; PRET| Route4_TextPointers:
; PRET| 	def_text_pointers
; PRET| 	dw_const Route4CooltrainerF1Text, TEXT_ROUTE4_COOLTRAINER_F1
; PRET| 	dw_const Route4CooltrainerF2Text, TEXT_ROUTE4_COOLTRAINER_F2
; PRET| 	dw_const PickUpItemText,          TEXT_ROUTE4_TM_WHIRLWIND
; PRET| 	dw_const PokeCenterSignText,      TEXT_ROUTE4_POKECENTER_SIGN
; PRET| 	dw_const Route4MtMoonSignText,    TEXT_ROUTE4_MT_MOON_SIGN
; PRET| 	dw_const Route4SignText,          TEXT_ROUTE4_SIGN
; PRET| 
; PRET| Route4TrainerHeaders:
; PRET| 	def_trainers 2
; PRET| Route4TrainerHeader0:
; PRET| 	trainer EVENT_BEAT_ROUTE_4_TRAINER_0, 3, Route4CooltrainerF2BattleText, Route4CooltrainerF2EndBattleText, Route4CooltrainerF2AfterBattleText
; PRET| 	db -1 ; end
; PRET| 
; PRET| Route4CooltrainerF1Text:
; PRET| 	text_far _Route4CooltrainerF1Text
; PRET| 	text_end

Route4CooltrainerF2Text:
    mov esi, Route4TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route4CooltrainerF2BattleText (scripts/Route4.asm:42-59) — a generated asset already defines Route4CooltrainerF2BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route4CooltrainerF2BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route4CooltrainerF2EndBattleText:
; PRET| 	text_far _Route4CooltrainerF2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route4CooltrainerF2AfterBattleText:
; PRET| 	text_far _Route4CooltrainerF2AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route4MtMoonSignText:
; PRET| 	text_far _Route4MtMoonSignText
; PRET| 	text_end
; PRET| 
; PRET| Route4SignText:
; PRET| 	text_far _Route4SignText
; PRET| 	text_end
