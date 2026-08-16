; Route8.asm — translated from pret scripts/Route8.asm by dos_port/tools/sm83xlat.
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


global Route8CooltrainerF1Text
global Route8CooltrainerF2Text
global Route8CooltrainerF3Text
global Route8CooltrainerF4Text
global Route8Gambler1Text
global Route8Gambler2Text
global Route8SuperNerd1Text
global Route8SuperNerd2Text
global Route8SuperNerd3Text
global Route8_Script

extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern Route8CooltrainerF1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route8CooltrainerF1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route8CooltrainerF1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route8CooltrainerF2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route8CooltrainerF2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route8CooltrainerF2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route8CooltrainerF3AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route8CooltrainerF3BattleText   ; NOT YET DEFINED IN THE PORT
extern Route8CooltrainerF3EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route8CooltrainerF4AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route8CooltrainerF4BattleText   ; NOT YET DEFINED IN THE PORT
extern Route8CooltrainerF4EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route8Gambler1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route8Gambler1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route8Gambler1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route8Gambler2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route8Gambler2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route8Gambler2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route8SuperNerd1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route8SuperNerd1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route8SuperNerd1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route8SuperNerd2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route8SuperNerd2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route8SuperNerd2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route8SuperNerd3AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route8SuperNerd3BattleText   ; NOT YET DEFINED IN THE PORT
extern Route8SuperNerd3EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route8TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern Route8TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern Route8TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern Route8TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern Route8TrainerHeader4   ; NOT YET DEFINED IN THE PORT
extern Route8TrainerHeader5   ; NOT YET DEFINED IN THE PORT
extern Route8TrainerHeader6   ; NOT YET DEFINED IN THE PORT
extern Route8TrainerHeader7   ; NOT YET DEFINED IN THE PORT
extern Route8TrainerHeader8   ; NOT YET DEFINED IN THE PORT
extern Route8TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern Route8UndergroundSignText   ; NOT YET DEFINED IN THE PORT
extern Route8_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern Route8_TextPointers   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_ROUTE8_DEFAULT                          equ 0
SCRIPT_ROUTE8_START_BATTLE                     equ 1
SCRIPT_ROUTE8_END_BATTLE                       equ 2
TEXT_ROUTE8_SUPER_NERD1                        equ 1
TEXT_ROUTE8_GAMBLER1                           equ 2
TEXT_ROUTE8_SUPER_NERD2                        equ 3
TEXT_ROUTE8_COOLTRAINER_F1                     equ 4
TEXT_ROUTE8_SUPER_NERD3                        equ 5
TEXT_ROUTE8_COOLTRAINER_F2                     equ 6
TEXT_ROUTE8_COOLTRAINER_F3                     equ 7
TEXT_ROUTE8_GAMBLER2                           equ 8
TEXT_ROUTE8_COOLTRAINER_F4                     equ 9
TEXT_ROUTE8_UNDERGROUND_SIGN                   equ 10

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wRoute8CurScript                               equ 0xD600

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

Route8_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route8TrainerHeaders
    mov edi, Route8_ScriptPointers   ; pret: ld de, Route8_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRoute8CurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRoute8CurScript], al
    ret

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route8_ScriptPointers (scripts/Route8.asm:11-49) — a generated asset already defines Route8_ScriptPointers
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	def_script_pointers
; PRET| 	dw_const CheckFightingMapTrainers,              SCRIPT_ROUTE8_DEFAULT
; PRET| 	dw_const DisplayEnemyTrainerTextAndStartBattle, SCRIPT_ROUTE8_START_BATTLE
; PRET| 	dw_const EndTrainerBattle,                      SCRIPT_ROUTE8_END_BATTLE
; PRET| 
; PRET| Route8_TextPointers:
; PRET| 	def_text_pointers
; PRET| 	dw_const Route8SuperNerd1Text,      TEXT_ROUTE8_SUPER_NERD1
; PRET| 	dw_const Route8Gambler1Text,        TEXT_ROUTE8_GAMBLER1
; PRET| 	dw_const Route8SuperNerd2Text,      TEXT_ROUTE8_SUPER_NERD2
; PRET| 	dw_const Route8CooltrainerF1Text,   TEXT_ROUTE8_COOLTRAINER_F1
; PRET| 	dw_const Route8SuperNerd3Text,      TEXT_ROUTE8_SUPER_NERD3
; PRET| 	dw_const Route8CooltrainerF2Text,   TEXT_ROUTE8_COOLTRAINER_F2
; PRET| 	dw_const Route8CooltrainerF3Text,   TEXT_ROUTE8_COOLTRAINER_F3
; PRET| 	dw_const Route8Gambler2Text,        TEXT_ROUTE8_GAMBLER2
; PRET| 	dw_const Route8CooltrainerF4Text,   TEXT_ROUTE8_COOLTRAINER_F4
; PRET| 	dw_const Route8UndergroundSignText, TEXT_ROUTE8_UNDERGROUND_SIGN
; PRET| 
; PRET| Route8TrainerHeaders:
; PRET| 	def_trainers
; PRET| Route8TrainerHeader0:
; PRET| 	trainer EVENT_BEAT_ROUTE_8_TRAINER_0, 4, Route8SuperNerd1BattleText, Route8SuperNerd1EndBattleText, Route8SuperNerd1AfterBattleText
; PRET| Route8TrainerHeader1:
; PRET| 	trainer EVENT_BEAT_ROUTE_8_TRAINER_1, 4, Route8Gambler1BattleText, Route8Gambler1EndBattleText, Route8Gambler1AfterBattleText
; PRET| Route8TrainerHeader2:
; PRET| 	trainer EVENT_BEAT_ROUTE_8_TRAINER_2, 4, Route8SuperNerd2BattleText, Route8SuperNerd2EndBattleText, Route8SuperNerd2AfterBattleText
; PRET| Route8TrainerHeader3:
; PRET| 	trainer EVENT_BEAT_ROUTE_8_TRAINER_3, 2, Route8CooltrainerF1BattleText, Route8CooltrainerF1EndBattleText, Route8CooltrainerF1AfterBattleText
; PRET| Route8TrainerHeader4:
; PRET| 	trainer EVENT_BEAT_ROUTE_8_TRAINER_4, 3, Route8SuperNerd3BattleText, Route8SuperNerd3EndBattleText, Route8SuperNerd3AfterBattleText
; PRET| Route8TrainerHeader5:
; PRET| 	trainer EVENT_BEAT_ROUTE_8_TRAINER_5, 3, Route8CooltrainerF2BattleText, Route8CooltrainerF2EndBattleText, Route8CooltrainerF2AfterBattleText
; PRET| Route8TrainerHeader6:
; PRET| 	trainer EVENT_BEAT_ROUTE_8_TRAINER_6, 2, Route8CooltrainerF3BattleText, Route8CooltrainerF3EndBattleText, Route8CooltrainerF3AfterBattleText
; PRET| Route8TrainerHeader7:
; PRET| 	trainer EVENT_BEAT_ROUTE_8_TRAINER_7, 2, Route8Gambler2BattleText, Route8Gambler2EndBattleText, Route8Gambler2AfterBattleText
; PRET| Route8TrainerHeader8:
; PRET| 	trainer EVENT_BEAT_ROUTE_8_TRAINER_8, 4, Route8CooltrainerF4BattleText, Route8CooltrainerF4EndBattleText, Route8CooltrainerF4AfterBattleText
; PRET| 	db -1 ; end

Route8SuperNerd1Text:
    mov esi, Route8TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route8SuperNerd1BattleText (scripts/Route8.asm:58-67) — a generated asset already defines Route8SuperNerd1BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route8SuperNerd1BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route8SuperNerd1EndBattleText:
; PRET| 	text_far _Route8SuperNerd1EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route8SuperNerd1AfterBattleText:
; PRET| 	text_far _Route8SuperNerd1AfterBattleText
; PRET| 	text_end

Route8Gambler1Text:
    mov esi, Route8TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route8Gambler1BattleText (scripts/Route8.asm:76-85) — a generated asset already defines Route8Gambler1BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route8Gambler1BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route8Gambler1EndBattleText:
; PRET| 	text_far _Route8Gambler1EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route8Gambler1AfterBattleText:
; PRET| 	text_far _Route8Gambler1AfterBattleText
; PRET| 	text_end

Route8SuperNerd2Text:
    mov esi, Route8TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route8SuperNerd2BattleText (scripts/Route8.asm:94-103) — a generated asset already defines Route8SuperNerd2BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route8SuperNerd2BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route8SuperNerd2EndBattleText:
; PRET| 	text_far _Route8SuperNerd2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route8SuperNerd2AfterBattleText:
; PRET| 	text_far _Route8SuperNerd2AfterBattleText
; PRET| 	text_end

Route8CooltrainerF1Text:
    mov esi, Route8TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route8CooltrainerF1BattleText (scripts/Route8.asm:112-121) — a generated asset already defines Route8CooltrainerF1BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route8CooltrainerF1BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route8CooltrainerF1EndBattleText:
; PRET| 	text_far _Route8CooltrainerF1EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route8CooltrainerF1AfterBattleText:
; PRET| 	text_far _Route8CooltrainerF1AfterBattleText
; PRET| 	text_end

Route8SuperNerd3Text:
    mov esi, Route8TrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route8SuperNerd3BattleText (scripts/Route8.asm:130-139) — a generated asset already defines Route8SuperNerd3BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route8SuperNerd3BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route8SuperNerd3EndBattleText:
; PRET| 	text_far _Route8SuperNerd3EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route8SuperNerd3AfterBattleText:
; PRET| 	text_far _Route8SuperNerd3AfterBattleText
; PRET| 	text_end

Route8CooltrainerF2Text:
    mov esi, Route8TrainerHeader5
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route8CooltrainerF2BattleText (scripts/Route8.asm:148-157) — a generated asset already defines Route8CooltrainerF2BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route8CooltrainerF2BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route8CooltrainerF2EndBattleText:
; PRET| 	text_far _Route8CooltrainerF2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route8CooltrainerF2AfterBattleText:
; PRET| 	text_far _Route8CooltrainerF2AfterBattleText
; PRET| 	text_end

Route8CooltrainerF3Text:
    mov esi, Route8TrainerHeader6
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route8CooltrainerF3BattleText (scripts/Route8.asm:166-175) — a generated asset already defines Route8CooltrainerF3BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route8CooltrainerF3BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route8CooltrainerF3EndBattleText:
; PRET| 	text_far _Route8CooltrainerF3EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route8CooltrainerF3AfterBattleText:
; PRET| 	text_far _Route8CooltrainerF3AfterBattleText
; PRET| 	text_end

Route8Gambler2Text:
    mov esi, Route8TrainerHeader7
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route8Gambler2BattleText (scripts/Route8.asm:184-193) — a generated asset already defines Route8Gambler2BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route8Gambler2BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route8Gambler2EndBattleText:
; PRET| 	text_far _Route8Gambler2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route8Gambler2AfterBattleText:
; PRET| 	text_far _Route8Gambler2AfterBattleText
; PRET| 	text_end

Route8CooltrainerF4Text:
    mov esi, Route8TrainerHeader8
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route8CooltrainerF4BattleText (scripts/Route8.asm:202-215) — a generated asset already defines Route8CooltrainerF4BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route8CooltrainerF4BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route8CooltrainerF4EndBattleText:
; PRET| 	text_far _Route8CooltrainerF4EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route8CooltrainerF4AfterBattleText:
; PRET| 	text_far _Route8CooltrainerF4AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route8UndergroundSignText:
; PRET| 	text_far _Route8UndergroundSignText
; PRET| 	text_end
