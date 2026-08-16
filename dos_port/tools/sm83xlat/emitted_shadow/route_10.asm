; Route10.asm — translated from pret scripts/Route10.asm by dos_port/tools/sm83xlat.
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


global Route10CooltrainerF1Text
global Route10CooltrainerF2Text
global Route10Hiker1Text
global Route10Hiker2Text
global Route10SuperNerd1Text
global Route10SuperNerd2Text
global Route10_Script

extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern Route10CooltrainerF1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route10CooltrainerF1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route10CooltrainerF1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route10CooltrainerF2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route10CooltrainerF2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route10CooltrainerF2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route10Hiker1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route10Hiker1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route10Hiker1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route10Hiker2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route10Hiker2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route10Hiker2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route10PowerPlantSignText   ; NOT YET DEFINED IN THE PORT
extern Route10RockTunnelSignText   ; NOT YET DEFINED IN THE PORT
extern Route10SuperNerd1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route10SuperNerd1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route10SuperNerd1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route10SuperNerd2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route10SuperNerd2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route10SuperNerd2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route10TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern Route10TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern Route10TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern Route10TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern Route10TrainerHeader4   ; NOT YET DEFINED IN THE PORT
extern Route10TrainerHeader5   ; NOT YET DEFINED IN THE PORT
extern Route10TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern Route10_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern Route10_TextPointers   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_ROUTE10_DEFAULT                         equ 0
SCRIPT_ROUTE10_START_BATTLE                    equ 1
SCRIPT_ROUTE10_END_BATTLE                      equ 2
TEXT_ROUTE10_SUPER_NERD1                       equ 1
TEXT_ROUTE10_HIKER1                            equ 2
TEXT_ROUTE10_SUPER_NERD2                       equ 3
TEXT_ROUTE10_COOLTRAINER_F1                    equ 4
TEXT_ROUTE10_HIKER2                            equ 5
TEXT_ROUTE10_COOLTRAINER_F2                    equ 6
TEXT_ROUTE10_ROCKTUNNEL_NORTH_SIGN             equ 7
TEXT_ROUTE10_POKECENTER_SIGN                   equ 8
TEXT_ROUTE10_ROCKTUNNEL_SOUTH_SIGN             equ 9
TEXT_ROUTE10_POWERPLANT_SIGN                   equ 10

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wRoute10CurScript                              equ 0xD604

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

Route10_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route10TrainerHeaders
    mov edi, Route10_ScriptPointers   ; pret: ld de, Route10_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRoute10CurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRoute10CurScript], al
    ret

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route10_ScriptPointers (scripts/Route10.asm:11-43) — a generated asset already defines Route10_ScriptPointers
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	def_script_pointers
; PRET| 	dw_const CheckFightingMapTrainers,              SCRIPT_ROUTE10_DEFAULT
; PRET| 	dw_const DisplayEnemyTrainerTextAndStartBattle, SCRIPT_ROUTE10_START_BATTLE
; PRET| 	dw_const EndTrainerBattle,                      SCRIPT_ROUTE10_END_BATTLE
; PRET| 
; PRET| Route10_TextPointers:
; PRET| 	def_text_pointers
; PRET| 	dw_const Route10SuperNerd1Text,     TEXT_ROUTE10_SUPER_NERD1
; PRET| 	dw_const Route10Hiker1Text,         TEXT_ROUTE10_HIKER1
; PRET| 	dw_const Route10SuperNerd2Text,     TEXT_ROUTE10_SUPER_NERD2
; PRET| 	dw_const Route10CooltrainerF1Text,  TEXT_ROUTE10_COOLTRAINER_F1
; PRET| 	dw_const Route10Hiker2Text,         TEXT_ROUTE10_HIKER2
; PRET| 	dw_const Route10CooltrainerF2Text,  TEXT_ROUTE10_COOLTRAINER_F2
; PRET| 	dw_const Route10RockTunnelSignText, TEXT_ROUTE10_ROCKTUNNEL_NORTH_SIGN
; PRET| 	dw_const PokeCenterSignText,        TEXT_ROUTE10_POKECENTER_SIGN
; PRET| 	dw_const Route10RockTunnelSignText, TEXT_ROUTE10_ROCKTUNNEL_SOUTH_SIGN
; PRET| 	dw_const Route10PowerPlantSignText, TEXT_ROUTE10_POWERPLANT_SIGN
; PRET| 
; PRET| Route10TrainerHeaders:
; PRET| 	def_trainers
; PRET| Route10TrainerHeader0:
; PRET| 	trainer EVENT_BEAT_ROUTE_10_TRAINER_0, 4, Route10SuperNerd1BattleText, Route10SuperNerd1EndBattleText, Route10SuperNerd1AfterBattleText
; PRET| Route10TrainerHeader1:
; PRET| 	trainer EVENT_BEAT_ROUTE_10_TRAINER_1, 3, Route10Hiker1BattleText, Route10Hiker1EndBattleText, Route10Hiker1AfterBattleText
; PRET| Route10TrainerHeader2:
; PRET| 	trainer EVENT_BEAT_ROUTE_10_TRAINER_2, 4, Route10SuperNerd2BattleText, Route10SuperNerd2EndBattleText, Route10SuperNerd2AfterBattleText
; PRET| Route10TrainerHeader3:
; PRET| 	trainer EVENT_BEAT_ROUTE_10_TRAINER_3, 3, Route10CooltrainerF1BattleText, Route10CooltrainerF1EndBattleText, Route10CooltrainerF1AfterBattleText
; PRET| Route10TrainerHeader4:
; PRET| 	trainer EVENT_BEAT_ROUTE_10_TRAINER_4, 2, Route10Hiker2BattleText, Route10Hiker2EndBattleText, Route10Hiker2AfterBattleText
; PRET| Route10TrainerHeader5:
; PRET| 	trainer EVENT_BEAT_ROUTE_10_TRAINER_5, 2, Route10CooltrainerF2BattleText, Route10CooltrainerF2EndBattleText, Route10CooltrainerF2AfterBattleText
; PRET| 	db -1 ; end

Route10SuperNerd1Text:
    mov esi, Route10TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route10SuperNerd1BattleText (scripts/Route10.asm:52-61) — a generated asset already defines Route10SuperNerd1BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route10SuperNerd1BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route10SuperNerd1EndBattleText:
; PRET| 	text_far _Route10SuperNerd1EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route10SuperNerd1AfterBattleText:
; PRET| 	text_far _Route10SuperNerd1AfterBattleText
; PRET| 	text_end

Route10Hiker1Text:
    mov esi, Route10TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route10Hiker1BattleText (scripts/Route10.asm:70-79) — a generated asset already defines Route10Hiker1BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route10Hiker1BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route10Hiker1EndBattleText:
; PRET| 	text_far _Route10Hiker1EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route10Hiker1AfterBattleText:
; PRET| 	text_far _Route10Hiker1AfterBattleText
; PRET| 	text_end

Route10SuperNerd2Text:
    mov esi, Route10TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route10SuperNerd2BattleText (scripts/Route10.asm:88-97) — a generated asset already defines Route10SuperNerd2BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route10SuperNerd2BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route10SuperNerd2EndBattleText:
; PRET| 	text_far _Route10SuperNerd2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route10SuperNerd2AfterBattleText:
; PRET| 	text_far _Route10SuperNerd2AfterBattleText
; PRET| 	text_end

Route10CooltrainerF1Text:
    mov esi, Route10TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route10CooltrainerF1BattleText (scripts/Route10.asm:106-115) — a generated asset already defines Route10CooltrainerF1BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route10CooltrainerF1BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route10CooltrainerF1EndBattleText:
; PRET| 	text_far _Route10CooltrainerF1EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route10CooltrainerF1AfterBattleText:
; PRET| 	text_far _Route10CooltrainerF1AfterBattleText
; PRET| 	text_end

Route10Hiker2Text:
    mov esi, Route10TrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route10Hiker2BattleText (scripts/Route10.asm:124-133) — a generated asset already defines Route10Hiker2BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route10Hiker2BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route10Hiker2EndBattleText:
; PRET| 	text_far _Route10Hiker2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route10Hiker2AfterBattleText:
; PRET| 	text_far _Route10Hiker2AfterBattleText
; PRET| 	text_end

Route10CooltrainerF2Text:
    mov esi, Route10TrainerHeader5
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route10CooltrainerF2BattleText (scripts/Route10.asm:142-159) — a generated asset already defines Route10CooltrainerF2BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route10CooltrainerF2BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route10CooltrainerF2EndBattleText:
; PRET| 	text_far _Route10CooltrainerF2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route10CooltrainerF2AfterBattleText:
; PRET| 	text_far _Route10CooltrainerF2AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route10RockTunnelSignText:
; PRET| 	text_far _Route10RockTunnelSignText
; PRET| 	text_end
; PRET| 
; PRET| Route10PowerPlantSignText:
; PRET| 	text_far _Route10PowerPlantSignText
; PRET| 	text_end
