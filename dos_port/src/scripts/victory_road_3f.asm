; VictoryRoad3F.asm — translated from pret scripts/VictoryRoad3F.asm by dos_port/tools/sm83xlat.
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

%include "assets/map_dims.inc"

global VictoryRoad3FCooltrainerF1Text
global VictoryRoad3FCooltrainerF2Text
global VictoryRoad3FCooltrainerM1Text
global VictoryRoad3FCooltrainerM2Text
global VictoryRoad3F_Script
global VictoryRoad3F_ScriptPointers

extern CheckBoulderCoords   ; NOT YET DEFINED IN THE PORT
extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern HideObject   ; NOT YET DEFINED IN THE PORT
extern IsPlayerOnDungeonWarp   ; NOT YET DEFINED IN THE PORT
extern PickUpItemText   ; NOT YET DEFINED IN THE PORT
extern ReplaceTileBlock   ; NOT YET DEFINED IN THE PORT
extern ShowObject   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad3FCheckBoulderEventScript   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad3FCooltrainerF1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad3FCooltrainerF1BattleText   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad3FCooltrainerF1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad3FCooltrainerF2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad3FCooltrainerF2BattleText   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad3FCooltrainerF2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad3FCooltrainerM1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad3FCooltrainerM1BattleText   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad3FCooltrainerM1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad3FCooltrainerM2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad3FCooltrainerM2BattleText   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad3FCooltrainerM2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad3FDefaultScript   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad3F_TextPointers   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad3TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad3TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad3TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad3TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad3TrainerHeaders   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
TEXT_VICTORYROAD3F_COOLTRAINER_M1              equ 1
TEXT_VICTORYROAD3F_COOLTRAINER_F1              equ 2
TEXT_VICTORYROAD3F_COOLTRAINER_M2              equ 3
TEXT_VICTORYROAD3F_COOLTRAINER_F2              equ 4
TEXT_VICTORYROAD3F_MAX_REVIVE                  equ 5
TEXT_VICTORYROAD3F_TM_EXPLOSION                equ 6
TEXT_VICTORYROAD3F_BOULDER1                    equ 7
TEXT_VICTORYROAD3F_BOULDER2                    equ 8
TEXT_VICTORYROAD3F_BOULDER3                    equ 9
TEXT_VICTORYROAD3F_BOULDER4                    equ 10

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wCoordIndex                                    equ 0xCD3D
wDungeonWarpDestinationMap                     equ 0xD71C
wVictoryRoad3FCurScript                        equ 0xD63F

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

VictoryRoad3F_Script:
    call VictoryRoad3FCheckBoulderEventScript
    call EnableAutoTextBoxDrawing
    mov esi, VictoryRoad3TrainerHeaders
    mov edi, VictoryRoad3F_ScriptPointers   ; pret: ld de, VictoryRoad3F_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wVictoryRoad3FCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wVictoryRoad3FCurScript], al
    ret

; ---------------------------------------------------------------------------
; BAIL[bit-clobbers-live-carry] VictoryRoad3FCheckBoulderEventScript (scripts/VictoryRoad3F.asm:12-21) — at scripts/VictoryRoad3F.asm:13: bit BIT_CUR_MAP_LOADED_1, [hl]
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, wCurrentMapScriptFlags
; PRET| 	bit BIT_CUR_MAP_LOADED_1, [hl]
; PRET| 	res BIT_CUR_MAP_LOADED_1, [hl]
; PRET| 	ret z
; PRET| 	CheckEventHL EVENT_VICTORY_ROAD_3_BOULDER_ON_SWITCH1
; PRET| 	ret z
; PRET| 	ld a, $1d
; PRET| 	ld [wNewTileBlockID], a
; PRET| 	lb bc, 5, 3
; PRET| 	predef_jump ReplaceTileBlock

VictoryRoad3F_ScriptPointers:
    dd VictoryRoad3FDefaultScript
    dd DisplayEnemyTrainerTextAndStartBattle
    dd EndTrainerBattle

; ---------------------------------------------------------------------------
; BAIL[bit-clobbers-live-carry] VictoryRoad3FDefaultScript (scripts/VictoryRoad3F.asm:30-46) — at scripts/VictoryRoad3F.asm:31: bit BIT_PUSHED_BOULDER, [hl]
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, wMiscFlags
; PRET| 	bit BIT_PUSHED_BOULDER, [hl]
; PRET| 	res BIT_PUSHED_BOULDER, [hl]
; PRET| 	jp z, .check_switch_hole
; PRET| 	ld hl, .SwitchOrHoleCoords
; PRET| 	call CheckBoulderCoords
; PRET| 	jp nc, .check_switch_hole
; PRET| 	ld a, [wCoordIndex]
; PRET| 	cp $1
; PRET| 	jr nz, .handle_hole
; PRET| 	ldh a, [hSpriteIndex]
; PRET| 	cp PIKACHU_SPRITE_INDEX
; PRET| 	jp z, .check_switch_hole
; PRET| 	ld hl, wCurrentMapScriptFlags
; PRET| 	set BIT_CUR_MAP_LOADED_1, [hl]
; PRET| 	SetEvent EVENT_VICTORY_ROAD_3_BOULDER_ON_SWITCH1
; PRET| 	ret

.handle_hole:
    CheckAndSetEvent EVENT_VICTORY_ROAD_3_BOULDER_ON_SWITCH2
    jnz .check_switch_hole
    mov al, 124
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and the predef id is not left in A because no reader is live; evidence=PredefPointers is unported and the flat model needs no bank switch, dataflow shows A dead after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
    mov al, 96
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef_jump; behavior=Predef dispatch replaced by a direct jmp, and the predef id is not left in A because no reader is live; evidence=PredefPointers is unported and the flat model needs no bank switch, dataflow shows A dead after this site; lifetime=retired when PredefPointers is ported}
    jmp ShowObject

.SwitchOrHoleCoords:
    db 5, 3
    db 15, 23
    db -1

.check_switch_hole:
    mov al, VICTORY_ROAD_2F
    mov [ebp + wDungeonWarpDestinationMap], al
    mov esi, .SwitchOrHoleCoords
    call IsPlayerOnDungeonWarp
    mov al, [ebp + wCoordIndex]
    cmp al, 0x1
    jnz .hole
    mov esi, wStatusFlags3
    and byte [ebp + esi], ~(1 << (4)) & 0xFF
    mov esi, wStatusFlags6
    and byte [ebp + esi], ~(1 << (BIT_DUNGEON_WARP)) & 0xFF
    ret

.hole:
    mov al, [ebp + wStatusFlags3]
    test al, (1 << (4))
    jz CheckFightingMapTrainers
    ret

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] VictoryRoad3F_TextPointers (scripts/VictoryRoad3F.asm:82-104) — a generated asset already defines VictoryRoad3TrainerHeaders
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	def_text_pointers
; PRET| 	dw_const VictoryRoad3FCooltrainerM1Text, TEXT_VICTORYROAD3F_COOLTRAINER_M1
; PRET| 	dw_const VictoryRoad3FCooltrainerF1Text, TEXT_VICTORYROAD3F_COOLTRAINER_F1
; PRET| 	dw_const VictoryRoad3FCooltrainerM2Text, TEXT_VICTORYROAD3F_COOLTRAINER_M2
; PRET| 	dw_const VictoryRoad3FCooltrainerF2Text, TEXT_VICTORYROAD3F_COOLTRAINER_F2
; PRET| 	dw_const PickUpItemText,                 TEXT_VICTORYROAD3F_MAX_REVIVE
; PRET| 	dw_const PickUpItemText,                 TEXT_VICTORYROAD3F_TM_EXPLOSION
; PRET| 	dw_const BoulderText,                    TEXT_VICTORYROAD3F_BOULDER1
; PRET| 	dw_const BoulderText,                    TEXT_VICTORYROAD3F_BOULDER2
; PRET| 	dw_const BoulderText,                    TEXT_VICTORYROAD3F_BOULDER3
; PRET| 	dw_const BoulderText,                    TEXT_VICTORYROAD3F_BOULDER4
; PRET| 
; PRET| VictoryRoad3TrainerHeaders:
; PRET| 	def_trainers
; PRET| VictoryRoad3TrainerHeader0:
; PRET| 	trainer EVENT_BEAT_VICTORY_ROAD_3_TRAINER_0, 1, VictoryRoad3FCooltrainerM1BattleText, VictoryRoad3FCooltrainerM1EndBattleText, VictoryRoad3FCooltrainerM1AfterBattleText
; PRET| VictoryRoad3TrainerHeader1:
; PRET| 	trainer EVENT_BEAT_VICTORY_ROAD_3_TRAINER_1, 4, VictoryRoad3FCooltrainerF1BattleText, VictoryRoad3FCooltrainerF1EndBattleText, VictoryRoad3FCooltrainerF1AfterBattleText
; PRET| VictoryRoad3TrainerHeader2:
; PRET| 	trainer EVENT_BEAT_VICTORY_ROAD_3_TRAINER_2, 4, VictoryRoad3FCooltrainerM2BattleText, VictoryRoad3FCooltrainerM2EndBattleText, VictoryRoad3FCooltrainerM2AfterBattleText
; PRET| VictoryRoad3TrainerHeader3:
; PRET| 	trainer EVENT_BEAT_VICTORY_ROAD_3_TRAINER_3, 4, VictoryRoad3FCooltrainerF2BattleText, VictoryRoad3FCooltrainerF2EndBattleText, VictoryRoad3FCooltrainerF2AfterBattleText
; PRET| 	db -1 ; end

VictoryRoad3FCooltrainerM1Text:
    mov esi, VictoryRoad3TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

VictoryRoad3FCooltrainerF1Text:
    mov esi, VictoryRoad3TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

VictoryRoad3FCooltrainerM2Text:
    mov esi, VictoryRoad3TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

VictoryRoad3FCooltrainerF2Text:
    mov esi, VictoryRoad3TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] VictoryRoad3FCooltrainerM1BattleText (scripts/VictoryRoad3F.asm:131-176) — a generated asset already defines VictoryRoad3FCooltrainerM1BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _VictoryRoad3FCooltrainerM1BattleText
; PRET| 	text_end
; PRET| 
; PRET| VictoryRoad3FCooltrainerM1EndBattleText:
; PRET| 	text_far _VictoryRoad3FCooltrainerM1EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| VictoryRoad3FCooltrainerM1AfterBattleText:
; PRET| 	text_far _VictoryRoad3FCooltrainerM1AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| VictoryRoad3FCooltrainerF1BattleText:
; PRET| 	text_far _VictoryRoad3FCooltrainerF1BattleText
; PRET| 	text_end
; PRET| 
; PRET| VictoryRoad3FCooltrainerF1EndBattleText:
; PRET| 	text_far _VictoryRoad3FCooltrainerF1EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| VictoryRoad3FCooltrainerF1AfterBattleText:
; PRET| 	text_far _VictoryRoad3FCooltrainerF1AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| VictoryRoad3FCooltrainerM2BattleText:
; PRET| 	text_far _VictoryRoad3FCooltrainerM2BattleText
; PRET| 	text_end
; PRET| 
; PRET| VictoryRoad3FCooltrainerM2EndBattleText:
; PRET| 	text_far _VictoryRoad3FCooltrainerM2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| VictoryRoad3FCooltrainerM2AfterBattleText:
; PRET| 	text_far _VictoryRoad3FCooltrainerM2AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| VictoryRoad3FCooltrainerF2BattleText:
; PRET| 	text_far _VictoryRoad3FCooltrainerF2BattleText
; PRET| 	text_end
; PRET| 
; PRET| VictoryRoad3FCooltrainerF2EndBattleText:
; PRET| 	text_far _VictoryRoad3FCooltrainerF2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| VictoryRoad3FCooltrainerF2AfterBattleText:
; PRET| 	text_far _VictoryRoad3FCooltrainerF2AfterBattleText
; PRET| 	text_end
