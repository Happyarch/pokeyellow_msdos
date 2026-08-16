; Route14.asm — translated from pret scripts/Route14.asm by dos_port/tools/sm83xlat.
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


global Route14Biker1Text
global Route14Biker2Text
global Route14Biker3Text
global Route14Biker4Text
global Route14CooltrainerM1Text
global Route14CooltrainerM2Text
global Route14CooltrainerM3Text
global Route14CooltrainerM4Text
global Route14CooltrainerM5Text
global Route14CooltrainerM6Text
global Route14_Script

extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern Route14Biker1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route14Biker1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route14Biker1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route14Biker2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route14Biker2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route14Biker2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route14Biker3AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route14Biker3BattleText   ; NOT YET DEFINED IN THE PORT
extern Route14Biker3EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route14Biker4AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route14Biker4BattleText   ; NOT YET DEFINED IN THE PORT
extern Route14Biker4EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route14CooltrainerM1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route14CooltrainerM1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route14CooltrainerM1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route14CooltrainerM2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route14CooltrainerM2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route14CooltrainerM2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route14CooltrainerM3AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route14CooltrainerM3BattleText   ; NOT YET DEFINED IN THE PORT
extern Route14CooltrainerM3EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route14CooltrainerM4AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route14CooltrainerM4BattleText   ; NOT YET DEFINED IN THE PORT
extern Route14CooltrainerM4EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route14CooltrainerM5AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route14CooltrainerM5BattleText   ; NOT YET DEFINED IN THE PORT
extern Route14CooltrainerM5EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route14CooltrainerM6AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route14CooltrainerM6BattleText   ; NOT YET DEFINED IN THE PORT
extern Route14CooltrainerM6EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route14SignText   ; NOT YET DEFINED IN THE PORT
extern Route14TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern Route14TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern Route14TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern Route14TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern Route14TrainerHeader4   ; NOT YET DEFINED IN THE PORT
extern Route14TrainerHeader5   ; NOT YET DEFINED IN THE PORT
extern Route14TrainerHeader6   ; NOT YET DEFINED IN THE PORT
extern Route14TrainerHeader7   ; NOT YET DEFINED IN THE PORT
extern Route14TrainerHeader8   ; NOT YET DEFINED IN THE PORT
extern Route14TrainerHeader9   ; NOT YET DEFINED IN THE PORT
extern Route14TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern Route14_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern Route14_TextPointers   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_ROUTE14_DEFAULT                         equ 0
SCRIPT_ROUTE14_START_BATTLE                    equ 1
SCRIPT_ROUTE14_END_BATTLE                      equ 2
TEXT_ROUTE14_COOLTRAINER_M1                    equ 1
TEXT_ROUTE14_COOLTRAINER_M2                    equ 2
TEXT_ROUTE14_COOLTRAINER_M3                    equ 3
TEXT_ROUTE14_COOLTRAINER_M4                    equ 4
TEXT_ROUTE14_COOLTRAINER_M5                    equ 5
TEXT_ROUTE14_COOLTRAINER_M6                    equ 6
TEXT_ROUTE14_BIKER1                            equ 7
TEXT_ROUTE14_BIKER2                            equ 8
TEXT_ROUTE14_BIKER3                            equ 9
TEXT_ROUTE14_BIKER4                            equ 10
TEXT_ROUTE14_SIGN                              equ 11

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wRoute14CurScript                              equ 0xD61A

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

Route14_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route14TrainerHeaders
    mov edi, Route14_ScriptPointers   ; pret: ld de, Route14_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRoute14CurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRoute14CurScript], al
    ret

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route14_ScriptPointers (scripts/Route14.asm:11-52) — a generated asset already defines Route14_ScriptPointers
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	def_script_pointers
; PRET| 	dw_const CheckFightingMapTrainers,              SCRIPT_ROUTE14_DEFAULT
; PRET| 	dw_const DisplayEnemyTrainerTextAndStartBattle, SCRIPT_ROUTE14_START_BATTLE
; PRET| 	dw_const EndTrainerBattle,                      SCRIPT_ROUTE14_END_BATTLE
; PRET| 
; PRET| Route14_TextPointers:
; PRET| 	def_text_pointers
; PRET| 	dw_const Route14CooltrainerM1Text, TEXT_ROUTE14_COOLTRAINER_M1
; PRET| 	dw_const Route14CooltrainerM2Text, TEXT_ROUTE14_COOLTRAINER_M2
; PRET| 	dw_const Route14CooltrainerM3Text, TEXT_ROUTE14_COOLTRAINER_M3
; PRET| 	dw_const Route14CooltrainerM4Text, TEXT_ROUTE14_COOLTRAINER_M4
; PRET| 	dw_const Route14CooltrainerM5Text, TEXT_ROUTE14_COOLTRAINER_M5
; PRET| 	dw_const Route14CooltrainerM6Text, TEXT_ROUTE14_COOLTRAINER_M6
; PRET| 	dw_const Route14Biker1Text,        TEXT_ROUTE14_BIKER1
; PRET| 	dw_const Route14Biker2Text,        TEXT_ROUTE14_BIKER2
; PRET| 	dw_const Route14Biker3Text,        TEXT_ROUTE14_BIKER3
; PRET| 	dw_const Route14Biker4Text,        TEXT_ROUTE14_BIKER4
; PRET| 	dw_const Route14SignText,          TEXT_ROUTE14_SIGN
; PRET| 
; PRET| Route14TrainerHeaders:
; PRET| 	def_trainers
; PRET| Route14TrainerHeader0:
; PRET| 	trainer EVENT_BEAT_ROUTE_14_TRAINER_0, 2, Route14CooltrainerM1BattleText, Route14CooltrainerM1EndBattleText, Route14CooltrainerM1AfterBattleText
; PRET| Route14TrainerHeader1:
; PRET| 	trainer EVENT_BEAT_ROUTE_14_TRAINER_1, 2, Route14CooltrainerM2BattleText, Route14CooltrainerM2EndBattleText, Route14CooltrainerM2AfterBattleText
; PRET| Route14TrainerHeader2:
; PRET| 	trainer EVENT_BEAT_ROUTE_14_TRAINER_2, 4, Route14CooltrainerM3BattleText, Route14CooltrainerM3EndBattleText, Route14CooltrainerM3AfterBattleText
; PRET| Route14TrainerHeader3:
; PRET| 	trainer EVENT_BEAT_ROUTE_14_TRAINER_3, 3, Route14CooltrainerM4BattleText, Route14CooltrainerM4EndBattleText, Route14CooltrainerM4AfterBattleText
; PRET| Route14TrainerHeader4:
; PRET| 	trainer EVENT_BEAT_ROUTE_14_TRAINER_4, 3, Route14CooltrainerM5BattleText, Route14CooltrainerM5EndBattleText, Route14CooltrainerM5AfterBattleText
; PRET| Route14TrainerHeader5:
; PRET| 	trainer EVENT_BEAT_ROUTE_14_TRAINER_5, 4, Route14CooltrainerM6BattleText, Route14CooltrainerM6EndBattleText, Route14CooltrainerM6AfterBattleText
; PRET| Route14TrainerHeader6:
; PRET| 	trainer EVENT_BEAT_ROUTE_14_TRAINER_6, 4, Route14Biker1BattleText, Route14Biker1EndBattleText, Route14Biker1AfterBattleText
; PRET| Route14TrainerHeader7:
; PRET| 	trainer EVENT_BEAT_ROUTE_14_TRAINER_7, 4, Route14Biker2BattleText, Route14Biker2EndBattleText, Route14Biker2AfterBattleText
; PRET| Route14TrainerHeader8:
; PRET| 	trainer EVENT_BEAT_ROUTE_14_TRAINER_8, 3, Route14Biker3BattleText, Route14Biker3EndBattleText, Route14Biker3AfterBattleText
; PRET| Route14TrainerHeader9:
; PRET| 	trainer EVENT_BEAT_ROUTE_14_TRAINER_9, 4, Route14Biker4BattleText, Route14Biker4EndBattleText, Route14Biker4AfterBattleText
; PRET| 	db -1 ; end

Route14CooltrainerM1Text:
    mov esi, Route14TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route14CooltrainerM1BattleText (scripts/Route14.asm:61-70) — a generated asset already defines Route14CooltrainerM1BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route14CooltrainerM1BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route14CooltrainerM1EndBattleText:
; PRET| 	text_far _Route14CooltrainerM1EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route14CooltrainerM1AfterBattleText:
; PRET| 	text_far _Route14CooltrainerM1AfterBattleText
; PRET| 	text_end

Route14CooltrainerM2Text:
    mov esi, Route14TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route14CooltrainerM2BattleText (scripts/Route14.asm:79-88) — a generated asset already defines Route14CooltrainerM2BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route14CooltrainerM2BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route14CooltrainerM2EndBattleText:
; PRET| 	text_far _Route14CooltrainerM2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route14CooltrainerM2AfterBattleText:
; PRET| 	text_far _Route14CooltrainerM2AfterBattleText
; PRET| 	text_end

Route14CooltrainerM3Text:
    mov esi, Route14TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route14CooltrainerM3BattleText (scripts/Route14.asm:97-106) — a generated asset already defines Route14CooltrainerM3BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route14CooltrainerM3BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route14CooltrainerM3EndBattleText:
; PRET| 	text_far _Route14CooltrainerM3EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route14CooltrainerM3AfterBattleText:
; PRET| 	text_far _Route14CooltrainerM3AfterBattleText
; PRET| 	text_end

Route14CooltrainerM4Text:
    mov esi, Route14TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route14CooltrainerM4BattleText (scripts/Route14.asm:115-124) — a generated asset already defines Route14CooltrainerM4BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route14CooltrainerM4BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route14CooltrainerM4EndBattleText:
; PRET| 	text_far _Route14CooltrainerM4EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route14CooltrainerM4AfterBattleText:
; PRET| 	text_far _Route14CooltrainerM4AfterBattleText
; PRET| 	text_end

Route14CooltrainerM5Text:
    mov esi, Route14TrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route14CooltrainerM5BattleText (scripts/Route14.asm:133-142) — a generated asset already defines Route14CooltrainerM5BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route14CooltrainerM5BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route14CooltrainerM5EndBattleText:
; PRET| 	text_far _Route14CooltrainerM5EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route14CooltrainerM5AfterBattleText:
; PRET| 	text_far _Route14CooltrainerM5AfterBattleText
; PRET| 	text_end

Route14CooltrainerM6Text:
    mov esi, Route14TrainerHeader5
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route14CooltrainerM6BattleText (scripts/Route14.asm:151-160) — a generated asset already defines Route14CooltrainerM6BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route14CooltrainerM6BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route14CooltrainerM6EndBattleText:
; PRET| 	text_far _Route14CooltrainerM6EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route14CooltrainerM6AfterBattleText:
; PRET| 	text_far _Route14CooltrainerM6AfterBattleText
; PRET| 	text_end

Route14Biker1Text:
    mov esi, Route14TrainerHeader6
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route14Biker1BattleText (scripts/Route14.asm:169-178) — a generated asset already defines Route14Biker1BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route14Biker1BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route14Biker1EndBattleText:
; PRET| 	text_far _Route14Biker1EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route14Biker1AfterBattleText:
; PRET| 	text_far _Route14Biker1AfterBattleText
; PRET| 	text_end

Route14Biker2Text:
    mov esi, Route14TrainerHeader7
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route14Biker2BattleText (scripts/Route14.asm:187-196) — a generated asset already defines Route14Biker2BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route14Biker2BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route14Biker2EndBattleText:
; PRET| 	text_far _Route14Biker2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route14Biker2AfterBattleText:
; PRET| 	text_far _Route14Biker2AfterBattleText
; PRET| 	text_end

Route14Biker3Text:
    mov esi, Route14TrainerHeader8
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route14Biker3BattleText (scripts/Route14.asm:205-214) — a generated asset already defines Route14Biker3BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route14Biker3BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route14Biker3EndBattleText:
; PRET| 	text_far _Route14Biker3EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route14Biker3AfterBattleText:
; PRET| 	text_far _Route14Biker3AfterBattleText
; PRET| 	text_end

Route14Biker4Text:
    mov esi, Route14TrainerHeader9
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route14Biker4BattleText (scripts/Route14.asm:223-236) — a generated asset already defines Route14Biker4BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route14Biker4BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route14Biker4EndBattleText:
; PRET| 	text_far _Route14Biker4EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route14Biker4AfterBattleText:
; PRET| 	text_far _Route14Biker4AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route14SignText:
; PRET| 	text_far _Route14SignText
; PRET| 	text_end
