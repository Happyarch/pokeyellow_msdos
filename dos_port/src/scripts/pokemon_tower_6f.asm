; PokemonTower6F.asm — translated from pret scripts/PokemonTower6F.asm by dos_port/tools/sm83xlat.
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


global PokemonTower6FChanneler1Text
global PokemonTower6FChanneler2Text
global PokemonTower6FChanneler3Text
global PokemonTower6FDefaultScript
global PokemonTower6FMarowakBattleScript
global PokemonTower6FMarowakCoords
global PokemonTower6FMarowakDepartedText
global PokemonTower6FPlayerMovingScript
global PokemonTower6FSetDefaultScript
global PokemonTower6F_Script
global PokemonTower6F_ScriptPointers

extern ArePlayerCoordsInArray   ; NOT YET DEFINED IN THE PORT
extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern Delay3   ; NOT YET DEFINED IN THE PORT
extern DelayFrames   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern DisplayTextID   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern PickUpItemText   ; NOT YET DEFINED IN THE PORT
extern PlayCry   ; NOT YET DEFINED IN THE PORT
extern PokemonTower6FBeGoneText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower6FChanneler1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower6FChanneler1BattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower6FChanneler1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower6FChanneler2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower6FChanneler2BattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower6FChanneler2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower6FChanneler3AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower6FChanneler3BattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower6FChanneler3EndBattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower6FGhostWasCubonesMotherText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower6FSoulWasCalmedText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower6F_TextPointers   ; NOT YET DEFINED IN THE PORT
extern PokemonTower6TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern PokemonTower6TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern PokemonTower6TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern PokemonTower6TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern UpdateSprites   ; NOT YET DEFINED IN THE PORT
extern WaitForSoundToFinish   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_POKEMONTOWER6F_DEFAULT                  equ 0
SCRIPT_POKEMONTOWER6F_PLAYER_MOVING            equ 3
SCRIPT_POKEMONTOWER6F_MAROWAK_BATTLE           equ 4
TEXT_POKEMONTOWER6F_CHANNELER1                 equ 1
TEXT_POKEMONTOWER6F_CHANNELER2                 equ 2
TEXT_POKEMONTOWER6F_CHANNELER3                 equ 3
TEXT_POKEMONTOWER6F_RARE_CANDY                 equ 4
TEXT_POKEMONTOWER6F_X_ACCURACY                 equ 5
TEXT_POKEMONTOWER6F_BEGONE                     equ 6
TEXT_POKEMONTOWER6F_MAROWAK_DEPARTED           equ 7

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wPokemonTower6FCurScript                       equ 0xD62E
wSpritePlayerStateData2MovementByte1           equ 0xC206

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

PokemonTower6F_Script:
    call EnableAutoTextBoxDrawing
    mov esi, PokemonTower6TrainerHeaders
    mov edi, PokemonTower6F_ScriptPointers   ; pret: ld de, PokemonTower6F_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wPokemonTower6FCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wPokemonTower6FCurScript], al
    ret

PokemonTower6FSetDefaultScript:
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov [ebp + wPokemonTower6FCurScript], al
    mov [ebp + wCurMapScript], al
    ret

PokemonTower6F_ScriptPointers:
    dd PokemonTower6FDefaultScript
    dd DisplayEnemyTrainerTextAndStartBattle
    dd EndTrainerBattle
    dd PokemonTower6FPlayerMovingScript
    dd PokemonTower6FMarowakBattleScript

PokemonTower6FDefaultScript:
    CheckEvent EVENT_BEAT_GHOST_MAROWAK
    jnz CheckFightingMapTrainers
    mov esi, PokemonTower6FMarowakCoords
    call ArePlayerCoordsInArray
    jae CheckFightingMapTrainers
    xor al, al
    mov [ebp + hJoyHeld], al
    mov al, TEXT_POKEMONTOWER6F_BEGONE
    mov [ebp + hTextID], al
    call DisplayTextID
    mov al, RESTLESS_SOUL
    mov [ebp + wCurOpponent], al
    mov al, 30
    mov [ebp + wCurEnemyLevel], al
    mov al, SCRIPT_POKEMONTOWER6F_MAROWAK_BATTLE
    mov [ebp + wPokemonTower6FCurScript], al
    mov [ebp + wCurMapScript], al
    ret

PokemonTower6FMarowakCoords:
    db 16, 10
    db -1

PokemonTower6FMarowakBattleScript:
    mov al, [ebp + wIsInBattle]
    cmp al, 0xff
    jz PokemonTower6FSetDefaultScript
    mov al, PAD_BUTTONS | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, [ebp + wStatusFlags3]
    test al, (1 << (BIT_TALKED_TO_TRAINER))
    jz .nr_57
        ret
.nr_57:
    call UpdateSprites
    mov al, PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, [ebp + wBattleResult]
    test al, al
    jnz .did_not_defeat
    SetEvent EVENT_BEAT_GHOST_MAROWAK
    mov al, TEXT_POKEMONTOWER6F_MAROWAK_DEPARTED
    mov [ebp + hTextID], al
    call DisplayTextID
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov al, SCRIPT_POKEMONTOWER6F_DEFAULT
    mov [ebp + wPokemonTower6FCurScript], al
    mov [ebp + wCurMapScript], al
    ret

.did_not_defeat:
    mov al, 0x1
    mov [ebp + W_SIMULATED_JOYPAD_STATES_INDEX], al
    mov al, PAD_RIGHT
    mov [ebp + W_SIMULATED_JOYPAD_STATES_END], al
    xor al, al
    mov [ebp + wSpritePlayerStateData2MovementByte1], al
    mov [ebp + W_OVERRIDE_SIMULATED_JOYPAD_STATES_MASK], al
    mov esi, wStatusFlags5
    or byte [ebp + esi], (1 << (BIT_SCRIPTED_MOVEMENT_STATE))
    mov al, SCRIPT_POKEMONTOWER6F_PLAYER_MOVING
    mov [ebp + wPokemonTower6FCurScript], al
    mov [ebp + wCurMapScript], al
    ret

PokemonTower6FPlayerMovingScript:
    mov al, [ebp + W_SIMULATED_JOYPAD_STATES_INDEX]
    test al, al
    jz .nr_92
        ret
.nr_92:
    call Delay3
    xor al, al
    mov [ebp + wPokemonTower6FCurScript], al
    mov [ebp + wCurMapScript], al
    ret

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] PokemonTower6F_TextPointers (scripts/PokemonTower6F.asm:100-117) — a generated asset already defines PokemonTower6TrainerHeaders
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	def_text_pointers
; PRET| 	dw_const PokemonTower6FChanneler1Text,      TEXT_POKEMONTOWER6F_CHANNELER1
; PRET| 	dw_const PokemonTower6FChanneler2Text,      TEXT_POKEMONTOWER6F_CHANNELER2
; PRET| 	dw_const PokemonTower6FChanneler3Text,      TEXT_POKEMONTOWER6F_CHANNELER3
; PRET| 	dw_const PickUpItemText,                    TEXT_POKEMONTOWER6F_RARE_CANDY
; PRET| 	dw_const PickUpItemText,                    TEXT_POKEMONTOWER6F_X_ACCURACY
; PRET| 	dw_const PokemonTower6FBeGoneText,          TEXT_POKEMONTOWER6F_BEGONE
; PRET| 	dw_const PokemonTower6FMarowakDepartedText, TEXT_POKEMONTOWER6F_MAROWAK_DEPARTED
; PRET| 
; PRET| PokemonTower6TrainerHeaders:
; PRET| 	def_trainers
; PRET| PokemonTower6TrainerHeader0:
; PRET| 	trainer EVENT_BEAT_POKEMONTOWER_6_TRAINER_0, 3, PokemonTower6FChanneler1BattleText, PokemonTower6FChanneler1EndBattleText, PokemonTower6FChanneler1AfterBattleText
; PRET| PokemonTower6TrainerHeader1:
; PRET| 	trainer EVENT_BEAT_POKEMONTOWER_6_TRAINER_1, 3, PokemonTower6FChanneler2BattleText, PokemonTower6FChanneler2EndBattleText, PokemonTower6FChanneler2AfterBattleText
; PRET| PokemonTower6TrainerHeader2:
; PRET| 	trainer EVENT_BEAT_POKEMONTOWER_6_TRAINER_2, 2, PokemonTower6FChanneler3BattleText, PokemonTower6FChanneler3EndBattleText, PokemonTower6FChanneler3AfterBattleText
; PRET| 	db -1 ; end

PokemonTower6FChanneler1Text:
    mov esi, PokemonTower6TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

PokemonTower6FChanneler2Text:
    mov esi, PokemonTower6TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

PokemonTower6FChanneler3Text:
    mov esi, PokemonTower6TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

PokemonTower6FMarowakDepartedText:
    mov esi, PokemonTower6FGhostWasCubonesMotherText
    call PrintText
    mov al, RESTLESS_SOUL
    call PlayCry
    call WaitForSoundToFinish
    mov bl, 30
    call DelayFrames
    mov esi, PokemonTower6FSoulWasCalmedText
    call PrintText
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] PokemonTower6FGhostWasCubonesMotherText (scripts/PokemonTower6F.asm:151-196) — a generated asset already defines PokemonTower6FChanneler1BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _PokemonTower6FGhostWasCubonesMotherText
; PRET| 	text_end
; PRET| 
; PRET| PokemonTower6FSoulWasCalmedText:
; PRET| 	text_far _PokemonTower6FSoulWasCalmedText
; PRET| 	text_end
; PRET| 
; PRET| PokemonTower6FChanneler1BattleText:
; PRET| 	text_far _PokemonTower6FChanneler1BattleText
; PRET| 	text_end
; PRET| 
; PRET| PokemonTower6FChanneler1EndBattleText:
; PRET| 	text_far _PokemonTower6FChanneler1EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| PokemonTower6FChanneler1AfterBattleText:
; PRET| 	text_far _PokemonTower6FChanneler1AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| PokemonTower6FChanneler2BattleText:
; PRET| 	text_far _PokemonTower6FChanneler2BattleText
; PRET| 	text_end
; PRET| 
; PRET| PokemonTower6FChanneler2EndBattleText:
; PRET| 	text_far _PokemonTower6FChanneler2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| PokemonTower6FChanneler2AfterBattleText:
; PRET| 	text_far _PokemonTower6FChanneler2AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| PokemonTower6FChanneler3BattleText:
; PRET| 	text_far _PokemonTower6FChanneler3BattleText
; PRET| 	text_end
; PRET| 
; PRET| PokemonTower6FChanneler3EndBattleText:
; PRET| 	text_far _PokemonTower6FChanneler3EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| PokemonTower6FChanneler3AfterBattleText:
; PRET| 	text_far _PokemonTower6FChanneler3AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| PokemonTower6FBeGoneText:
; PRET| 	text_far _PokemonTower6FBeGoneText
; PRET| 	text_end
