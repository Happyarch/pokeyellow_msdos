; Route3.asm — translated from pret scripts/Route3.asm by dos_port/tools/sm83xlat.
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


global Route3CooltrainerF1Text
global Route3CooltrainerF2Text
global Route3CooltrainerF3Text
global Route3Youngster1Text
global Route3Youngster2Text
global Route3Youngster3Text
global Route3Youngster4Text
global Route3Youngster5Text
global Route3_Script

extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern Route3CooltrainerF1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route3CooltrainerF1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route3CooltrainerF1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route3CooltrainerF2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route3CooltrainerF2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route3CooltrainerF2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route3CooltrainerF3AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route3CooltrainerF3BattleText   ; NOT YET DEFINED IN THE PORT
extern Route3CooltrainerF3EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route3SignText   ; NOT YET DEFINED IN THE PORT
extern Route3SuperNerdText   ; NOT YET DEFINED IN THE PORT
extern Route3TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern Route3TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern Route3TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern Route3TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern Route3TrainerHeader4   ; NOT YET DEFINED IN THE PORT
extern Route3TrainerHeader5   ; NOT YET DEFINED IN THE PORT
extern Route3TrainerHeader6   ; NOT YET DEFINED IN THE PORT
extern Route3TrainerHeader7   ; NOT YET DEFINED IN THE PORT
extern Route3TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern Route3Youngster1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route3Youngster1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route3Youngster1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route3Youngster2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route3Youngster2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route3Youngster2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route3Youngster3AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route3Youngster3BattleText   ; NOT YET DEFINED IN THE PORT
extern Route3Youngster3EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route3Youngster4AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route3Youngster4BattleText   ; NOT YET DEFINED IN THE PORT
extern Route3Youngster4EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route3Youngster5AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route3Youngster5BattleText   ; NOT YET DEFINED IN THE PORT
extern Route3Youngster5EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route3_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern Route3_TextPointers   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_ROUTE3_DEFAULT                          equ 0
SCRIPT_ROUTE3_START_BATTLE                     equ 1
SCRIPT_ROUTE3_END_BATTLE                       equ 2
TEXT_ROUTE3_SUPER_NERD                         equ 1
TEXT_ROUTE3_YOUNGSTER1                         equ 2
TEXT_ROUTE3_YOUNGSTER2                         equ 3
TEXT_ROUTE3_COOLTRAINER_F1                     equ 4
TEXT_ROUTE3_YOUNGSTER3                         equ 5
TEXT_ROUTE3_COOLTRAINER_F2                     equ 6
TEXT_ROUTE3_YOUNGSTER4                         equ 7
TEXT_ROUTE3_YOUNGSTER5                         equ 8
TEXT_ROUTE3_COOLTRAINER_F3                     equ 9
TEXT_ROUTE3_SIGN                               equ 10

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wRoute3CurScript                               equ 0xD5F7

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

Route3_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route3TrainerHeaders
    mov edi, Route3_ScriptPointers   ; pret: ld de, Route3_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRoute3CurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRoute3CurScript], al
    ret

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route3_ScriptPointers (scripts/Route3.asm:11-51) — a generated asset already defines Route3_ScriptPointers
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	def_script_pointers
; PRET| 	dw_const CheckFightingMapTrainers,              SCRIPT_ROUTE3_DEFAULT
; PRET| 	dw_const DisplayEnemyTrainerTextAndStartBattle, SCRIPT_ROUTE3_START_BATTLE
; PRET| 	dw_const EndTrainerBattle,                      SCRIPT_ROUTE3_END_BATTLE
; PRET| 
; PRET| Route3_TextPointers:
; PRET| 	def_text_pointers
; PRET| 	dw_const Route3SuperNerdText,     TEXT_ROUTE3_SUPER_NERD
; PRET| 	dw_const Route3Youngster1Text,    TEXT_ROUTE3_YOUNGSTER1
; PRET| 	dw_const Route3Youngster2Text,    TEXT_ROUTE3_YOUNGSTER2
; PRET| 	dw_const Route3CooltrainerF1Text, TEXT_ROUTE3_COOLTRAINER_F1
; PRET| 	dw_const Route3Youngster3Text,    TEXT_ROUTE3_YOUNGSTER3
; PRET| 	dw_const Route3CooltrainerF2Text, TEXT_ROUTE3_COOLTRAINER_F2
; PRET| 	dw_const Route3Youngster4Text,    TEXT_ROUTE3_YOUNGSTER4
; PRET| 	dw_const Route3Youngster5Text,    TEXT_ROUTE3_YOUNGSTER5
; PRET| 	dw_const Route3CooltrainerF3Text, TEXT_ROUTE3_COOLTRAINER_F3
; PRET| 	dw_const Route3SignText,          TEXT_ROUTE3_SIGN
; PRET| 
; PRET| Route3TrainerHeaders:
; PRET| 	def_trainers 2
; PRET| Route3TrainerHeader0:
; PRET| 	trainer EVENT_BEAT_ROUTE_3_TRAINER_0, 2, Route3Youngster1BattleText, Route3Youngster1EndBattleText, Route3Youngster1AfterBattleText
; PRET| Route3TrainerHeader1:
; PRET| 	trainer EVENT_BEAT_ROUTE_3_TRAINER_1, 3, Route3Youngster2BattleText, Route3Youngster2EndBattleText, Route3Youngster2AfterBattleText
; PRET| Route3TrainerHeader2:
; PRET| 	trainer EVENT_BEAT_ROUTE_3_TRAINER_2, 2, Route3CooltrainerF1BattleText, Route3CooltrainerF1EndBattleText, Route3CooltrainerF1AfterBattleText
; PRET| Route3TrainerHeader3:
; PRET| 	trainer EVENT_BEAT_ROUTE_3_TRAINER_3, 1, Route3Youngster3BattleText, Route3Youngster3EndBattleText, Route3Youngster3AfterBattleText
; PRET| Route3TrainerHeader4:
; PRET| 	trainer EVENT_BEAT_ROUTE_3_TRAINER_4, 4, Route3CooltrainerF2BattleText, Route3CooltrainerF2EndBattleText, Route3CooltrainerF2AfterBattleText
; PRET| Route3TrainerHeader5:
; PRET| 	trainer EVENT_BEAT_ROUTE_3_TRAINER_5, 3, Route3Youngster4BattleText, Route3Youngster4EndBattleText, Route3Youngster4AfterBattleText
; PRET| Route3TrainerHeader6:
; PRET| 	trainer EVENT_BEAT_ROUTE_3_TRAINER_6, 3, Route3Youngster5BattleText, Route3Youngster5EndBattleText, Route3Youngster5AfterBattleText
; PRET| Route3TrainerHeader7:
; PRET| 	trainer EVENT_BEAT_ROUTE_3_TRAINER_7, 2, Route3CooltrainerF3BattleText, Route3CooltrainerF3EndBattleText, Route3CooltrainerF3AfterBattleText
; PRET| 	db -1 ; end
; PRET| 
; PRET| Route3SuperNerdText:
; PRET| 	text_far _Route3Text1
; PRET| 	text_end

Route3Youngster1Text:
    mov esi, Route3TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route3Youngster1BattleText (scripts/Route3.asm:60-69) — a generated asset already defines Route3Youngster1BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route3Youngster1BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route3Youngster1EndBattleText:
; PRET| 	text_far _Route3Youngster1EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route3Youngster1AfterBattleText:
; PRET| 	text_far _Route3Youngster1AfterBattleText
; PRET| 	text_end

Route3Youngster2Text:
    mov esi, Route3TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route3Youngster2BattleText (scripts/Route3.asm:78-87) — a generated asset already defines Route3Youngster2BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route3Youngster2BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route3Youngster2EndBattleText:
; PRET| 	text_far _Route3Youngster2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route3Youngster2AfterBattleText:
; PRET| 	text_far _Route3Youngster2AfterBattleText
; PRET| 	text_end

Route3CooltrainerF1Text:
    mov esi, Route3TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route3CooltrainerF1BattleText (scripts/Route3.asm:96-105) — a generated asset already defines Route3CooltrainerF1BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route3CooltrainerF1BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route3CooltrainerF1EndBattleText:
; PRET| 	text_far _Route3CooltrainerF1EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route3CooltrainerF1AfterBattleText:
; PRET| 	text_far _Route3CooltrainerF1AfterBattleText
; PRET| 	text_end

Route3Youngster3Text:
    mov esi, Route3TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route3Youngster3BattleText (scripts/Route3.asm:114-123) — a generated asset already defines Route3Youngster3BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route3Youngster3BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route3Youngster3EndBattleText:
; PRET| 	text_far _Route3Youngster3EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route3Youngster3AfterBattleText:
; PRET| 	text_far _Route3Youngster3AfterBattleText
; PRET| 	text_end

Route3CooltrainerF2Text:
    mov esi, Route3TrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route3CooltrainerF2BattleText (scripts/Route3.asm:132-141) — a generated asset already defines Route3CooltrainerF2BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route3CooltrainerF2BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route3CooltrainerF2EndBattleText:
; PRET| 	text_far _Route3CooltrainerF2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route3CooltrainerF2AfterBattleText:
; PRET| 	text_far _Route3CooltrainerF2AfterBattleText
; PRET| 	text_end

Route3Youngster4Text:
    mov esi, Route3TrainerHeader5
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route3Youngster4BattleText (scripts/Route3.asm:150-159) — a generated asset already defines Route3Youngster4BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route3Youngster4BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route3Youngster4EndBattleText:
; PRET| 	text_far _Route3Youngster4EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route3Youngster4AfterBattleText:
; PRET| 	text_far _Route3Youngster4AfterBattleText
; PRET| 	text_end

Route3Youngster5Text:
    mov esi, Route3TrainerHeader6
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route3Youngster5BattleText (scripts/Route3.asm:168-177) — a generated asset already defines Route3Youngster5BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route3Youngster5BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route3Youngster5EndBattleText:
; PRET| 	text_far _Route3Youngster5EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route3Youngster5AfterBattleText:
; PRET| 	text_far _Route3Youngster5AfterBattleText
; PRET| 	text_end

Route3CooltrainerF3Text:
    mov esi, Route3TrainerHeader7
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route3CooltrainerF3BattleText (scripts/Route3.asm:186-199) — a generated asset already defines Route3CooltrainerF3BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route3CooltrainerF3BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route3CooltrainerF3EndBattleText:
; PRET| 	text_far _Route3CooltrainerF3EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route3CooltrainerF3AfterBattleText:
; PRET| 	text_far _Route3CooltrainerF3AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route3SignText:
; PRET| 	text_far _Route3SignText
; PRET| 	text_end
