; PokemonTower4F.asm — translated from pret scripts/PokemonTower4F.asm by dos_port/tools/sm83xlat.
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


global PokemonTower4FChanneler1Text
global PokemonTower4FChanneler2Text
global PokemonTower4FChanneler3Text
global PokemonTower4F_Script

extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern PickUpItemText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower4FChanneler1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower4FChanneler1BattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower4FChanneler1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower4FChanneler2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower4FChanneler2BattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower4FChanneler2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower4FChanneler3AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower4FChanneler3BattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower4FChanneler3EndBattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower4F_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern PokemonTower4F_TextPointers   ; NOT YET DEFINED IN THE PORT
extern PokemonTower4TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern PokemonTower4TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern PokemonTower4TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern PokemonTower4TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_POKEMONTOWER4F_DEFAULT                  equ 0
SCRIPT_POKEMONTOWER4F_START_BATTLE             equ 1
SCRIPT_POKEMONTOWER4F_END_BATTLE               equ 2
TEXT_POKEMONTOWER4F_CHANNELER1                 equ 1
TEXT_POKEMONTOWER4F_CHANNELER2                 equ 2
TEXT_POKEMONTOWER4F_CHANNELER3                 equ 3
TEXT_POKEMONTOWER4F_ELIXER                     equ 4
TEXT_POKEMONTOWER4F_AWAKENING                  equ 5
TEXT_POKEMONTOWER4F_HP_UP                      equ 6

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wPokemonTower4FCurScript                       equ 0xD62C

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

PokemonTower4F_Script:
    call EnableAutoTextBoxDrawing
    mov esi, PokemonTower4TrainerHeaders
    mov edi, PokemonTower4F_ScriptPointers   ; pret: ld de, PokemonTower4F_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wPokemonTower4FCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wPokemonTower4FCurScript], al
    ret

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] PokemonTower4F_ScriptPointers (scripts/PokemonTower4F.asm:11-33) — a generated asset already defines PokemonTower4TrainerHeaders
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	def_script_pointers
; PRET| 	dw_const CheckFightingMapTrainers,              SCRIPT_POKEMONTOWER4F_DEFAULT
; PRET| 	dw_const DisplayEnemyTrainerTextAndStartBattle, SCRIPT_POKEMONTOWER4F_START_BATTLE
; PRET| 	dw_const EndTrainerBattle,                      SCRIPT_POKEMONTOWER4F_END_BATTLE
; PRET| 
; PRET| PokemonTower4F_TextPointers:
; PRET| 	def_text_pointers
; PRET| 	dw_const PokemonTower4FChanneler1Text, TEXT_POKEMONTOWER4F_CHANNELER1
; PRET| 	dw_const PokemonTower4FChanneler2Text, TEXT_POKEMONTOWER4F_CHANNELER2
; PRET| 	dw_const PokemonTower4FChanneler3Text, TEXT_POKEMONTOWER4F_CHANNELER3
; PRET| 	dw_const PickUpItemText,               TEXT_POKEMONTOWER4F_ELIXER
; PRET| 	dw_const PickUpItemText,               TEXT_POKEMONTOWER4F_AWAKENING
; PRET| 	dw_const PickUpItemText,               TEXT_POKEMONTOWER4F_HP_UP
; PRET| 
; PRET| PokemonTower4TrainerHeaders:
; PRET| 	def_trainers
; PRET| PokemonTower4TrainerHeader0:
; PRET| 	trainer EVENT_BEAT_POKEMONTOWER_4_TRAINER_0, 2, PokemonTower4FChanneler1BattleText, PokemonTower4FChanneler1EndBattleText, PokemonTower4FChanneler1AfterBattleText
; PRET| PokemonTower4TrainerHeader1:
; PRET| 	trainer EVENT_BEAT_POKEMONTOWER_4_TRAINER_1, 2, PokemonTower4FChanneler2BattleText, PokemonTower4FChanneler2EndBattleText, PokemonTower4FChanneler2AfterBattleText
; PRET| PokemonTower4TrainerHeader2:
; PRET| 	trainer EVENT_BEAT_POKEMONTOWER_4_TRAINER_2, 2, PokemonTower4FChanneler3BattleText, PokemonTower4FChanneler3EndBattleText, PokemonTower4FChanneler3AfterBattleText
; PRET| 	db -1 ; end

PokemonTower4FChanneler1Text:
    mov esi, PokemonTower4TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

PokemonTower4FChanneler2Text:
    mov esi, PokemonTower4TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

PokemonTower4FChanneler3Text:
    mov esi, PokemonTower4TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] PokemonTower4FChanneler1BattleText (scripts/PokemonTower4F.asm:54-87) — a generated asset already defines PokemonTower4FChanneler1BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _PokemonTower4FChanneler1BattleText
; PRET| 	text_end
; PRET| 
; PRET| PokemonTower4FChanneler1EndBattleText:
; PRET| 	text_far _PokemonTower4FChanneler1EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| PokemonTower4FChanneler1AfterBattleText:
; PRET| 	text_far _PokemonTower4FChanneler1AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| PokemonTower4FChanneler2BattleText:
; PRET| 	text_far _PokemonTower4FChanneler2BattleText
; PRET| 	text_end
; PRET| 
; PRET| PokemonTower4FChanneler2EndBattleText:
; PRET| 	text_far _PokemonTower4FChanneler2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| PokemonTower4FChanneler2AfterBattleText:
; PRET| 	text_far _PokemonTower4FChanneler2AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| PokemonTower4FChanneler3BattleText:
; PRET| 	text_far _PokemonTower4FChanneler3BattleText
; PRET| 	text_end
; PRET| 
; PRET| PokemonTower4FChanneler3EndBattleText:
; PRET| 	text_far _PokemonTower4FChanneler3EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| PokemonTower4FChanneler3AfterBattleText:
; PRET| 	text_far _PokemonTower4FChanneler3AfterBattleText
; PRET| 	text_end
