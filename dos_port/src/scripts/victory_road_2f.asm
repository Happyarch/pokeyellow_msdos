; VictoryRoad2F.asm — translated from pret scripts/VictoryRoad2F.asm by dos_port/tools/sm83xlat.
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


global VictoryRoad2FCooltrainerMText
global VictoryRoad2FHikerText
global VictoryRoad2FMoltresText
global VictoryRoad2FSuperNerd1Text
global VictoryRoad2FSuperNerd2Text
global VictoryRoad2FSuperNerd3Text
global VictoryRoad2F_Script
global VictoryRoad2F_ScriptPointers

extern CheckBoulderCoords   ; NOT YET DEFINED IN THE PORT
extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern MoltresTrainerHeader   ; NOT YET DEFINED IN THE PORT
extern PickUpItemText   ; NOT YET DEFINED IN THE PORT
extern PlayCry   ; NOT YET DEFINED IN THE PORT
extern ReplaceTileBlock   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad2FCheckBoulderEventScript   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad2FCooltrainerMAfterBattleText   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad2FCooltrainerMBattleText   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad2FCooltrainerMEndBattleText   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad2FDefaultScript   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad2FHikerAfterBattleText   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad2FHikerBattleText   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad2FHikerEndBattleText   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad2FMoltresBattleText   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad2FReplaceTileBlockScript   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad2FResetBoulderEventScript   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad2FSuperNerd1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad2FSuperNerd1BattleText   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad2FSuperNerd1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad2FSuperNerd2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad2FSuperNerd2BattleText   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad2FSuperNerd2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad2FSuperNerd3AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad2FSuperNerd3BattleText   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad2FSuperNerd3EndBattleText   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad2F_TextPointers   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad2TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad2TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad2TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad2TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad2TrainerHeader4   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad2TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern WaitForSoundToFinish   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
TEXT_VICTORYROAD2F_HIKER                       equ 1
TEXT_VICTORYROAD2F_SUPER_NERD1                 equ 2
TEXT_VICTORYROAD2F_COOLTRAINER_M               equ 3
TEXT_VICTORYROAD2F_SUPER_NERD2                 equ 4
TEXT_VICTORYROAD2F_SUPER_NERD3                 equ 5
TEXT_VICTORYROAD2F_MOLTRES                     equ 6
TEXT_VICTORYROAD2F_TM_SUBMISSION               equ 7
TEXT_VICTORYROAD2F_FULL_HEAL                   equ 8
TEXT_VICTORYROAD2F_TM_MEGA_KICK                equ 9
TEXT_VICTORYROAD2F_GUARD_SPEC                  equ 10
TEXT_VICTORYROAD2F_BOULDER1                    equ 11
TEXT_VICTORYROAD2F_BOULDER2                    equ 12
TEXT_VICTORYROAD2F_BOULDER3                    equ 13

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wCoordIndex                                    equ 0xCD3D
wVictoryRoad2FCurScript                        equ 0xD63E

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

VictoryRoad2F_Script:
    mov esi, W_CURRENT_MAP_SCRIPT_FLAGS
    test byte [ebp + esi], (1 << (BIT_CUR_MAP_LOADED_2))
    pushfd    ; SM83 form writes no flags
        and byte [ebp + esi], ~(1 << (BIT_CUR_MAP_LOADED_2)) & 0xFF
    popfd
    jz .sk_5
        call VictoryRoad2FResetBoulderEventScript
.sk_5:
    mov esi, W_CURRENT_MAP_SCRIPT_FLAGS
    test byte [ebp + esi], (1 << (BIT_CUR_MAP_LOADED_1))
    pushfd    ; SM83 form writes no flags
        and byte [ebp + esi], ~(1 << (BIT_CUR_MAP_LOADED_1)) & 0xFF
    popfd
    jz .sk_9
        call VictoryRoad2FCheckBoulderEventScript
.sk_9:
    call EnableAutoTextBoxDrawing
    mov esi, VictoryRoad2TrainerHeaders
    mov edi, VictoryRoad2F_ScriptPointers   ; pret: ld de, VictoryRoad2F_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wVictoryRoad2FCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wVictoryRoad2FCurScript], al
    ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] VictoryRoad2FResetBoulderEventScript (scripts/VictoryRoad2F.asm:19-37) — at scripts/VictoryRoad2F.asm:23: .not_on_switch is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ResetEvent EVENT_VICTORY_ROAD_1_BOULDER_ON_SWITCH
; PRET| ; fallthrough
; PRET| VictoryRoad2FCheckBoulderEventScript:
; PRET| 	CheckEvent EVENT_VICTORY_ROAD_2_BOULDER_ON_SWITCH1
; PRET| 	jr z, .not_on_switch
; PRET| 	push af
; PRET| 	ld a, $15
; PRET| 	lb bc, 4, 3
; PRET| 	call VictoryRoad2FReplaceTileBlockScript
; PRET| 	pop af
; PRET| .not_on_switch
; PRET| 	CheckEventReuseA EVENT_VICTORY_ROAD_2_BOULDER_ON_SWITCH2
; PRET| 	ret z
; PRET| 	ld a, $1d
; PRET| 	lb bc, 7, 11
; PRET| VictoryRoad2FReplaceTileBlockScript:
; PRET| 	ld [wNewTileBlockID], a
; PRET| 	predef ReplaceTileBlock
; PRET| 	ret

VictoryRoad2F_ScriptPointers:
    dd VictoryRoad2FDefaultScript
    dd DisplayEnemyTrainerTextAndStartBattle
    dd EndTrainerBattle

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] VictoryRoad2FDefaultScript (scripts/VictoryRoad2F.asm:46-59) — at scripts/VictoryRoad2F.asm:46: .SwitchCoords is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .SwitchCoords
; PRET| 	call CheckBoulderCoords
; PRET| 	jp nc, CheckFightingMapTrainers
; PRET| 	ldh a, [hSpriteIndex]
; PRET| 	cp PIKACHU_SPRITE_INDEX
; PRET| 	jp z, CheckFightingMapTrainers
; PRET| 	EventFlagAddress hl, EVENT_VICTORY_ROAD_2_BOULDER_ON_SWITCH1
; PRET| 	ld a, [wCoordIndex]
; PRET| 	cp $2
; PRET| 	jr z, .second_switch
; PRET| 	CheckEventReuseHL EVENT_VICTORY_ROAD_2_BOULDER_ON_SWITCH1
; PRET| 	SetEventReuseHL EVENT_VICTORY_ROAD_2_BOULDER_ON_SWITCH1
; PRET| 	ret nz
; PRET| 	jr .set_script_flag

; ---------------------------------------------------------------------------
; BAIL[event-byte-assembly-state] VictoryRoad2FDefaultScript.second_switch (scripts/VictoryRoad2F.asm:61-67) — at scripts/VictoryRoad2F.asm:61: CheckEventAfterBranchReuseHL EVENT_VICTORY_ROAD_2_BOULDER_ON_SWITCH2, EVENT_VICTORY_ROAD_2_BOULDER_ON_SWITCH1
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEventAfterBranchReuseHL EVENT_VICTORY_ROAD_2_BOULDER_ON_SWITCH2, EVENT_VICTORY_ROAD_2_BOULDER_ON_SWITCH1
; PRET| 	SetEventReuseHL EVENT_VICTORY_ROAD_2_BOULDER_ON_SWITCH2
; PRET| 	ret nz
; PRET| .set_script_flag
; PRET| 	ld hl, wCurrentMapScriptFlags
; PRET| 	set BIT_CUR_MAP_LOADED_1, [hl]
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] VictoryRoad2FDefaultScript.SwitchCoords (scripts/VictoryRoad2F.asm:70-104) — a generated asset already defines VictoryRoad2TrainerHeaders
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	dbmapcoord  1, 16
; PRET| 	dbmapcoord  9, 16
; PRET| 	db -1 ; end
; PRET| 
; PRET| VictoryRoad2F_TextPointers:
; PRET| 	def_text_pointers
; PRET| 	dw_const VictoryRoad2FHikerText,        TEXT_VICTORYROAD2F_HIKER
; PRET| 	dw_const VictoryRoad2FSuperNerd1Text,   TEXT_VICTORYROAD2F_SUPER_NERD1
; PRET| 	dw_const VictoryRoad2FCooltrainerMText, TEXT_VICTORYROAD2F_COOLTRAINER_M
; PRET| 	dw_const VictoryRoad2FSuperNerd2Text,   TEXT_VICTORYROAD2F_SUPER_NERD2
; PRET| 	dw_const VictoryRoad2FSuperNerd3Text,   TEXT_VICTORYROAD2F_SUPER_NERD3
; PRET| 	dw_const VictoryRoad2FMoltresText,      TEXT_VICTORYROAD2F_MOLTRES
; PRET| 	dw_const PickUpItemText,                TEXT_VICTORYROAD2F_TM_SUBMISSION
; PRET| 	dw_const PickUpItemText,                TEXT_VICTORYROAD2F_FULL_HEAL
; PRET| 	dw_const PickUpItemText,                TEXT_VICTORYROAD2F_TM_MEGA_KICK
; PRET| 	dw_const PickUpItemText,                TEXT_VICTORYROAD2F_GUARD_SPEC
; PRET| 	dw_const BoulderText,                   TEXT_VICTORYROAD2F_BOULDER1
; PRET| 	dw_const BoulderText,                   TEXT_VICTORYROAD2F_BOULDER2
; PRET| 	dw_const BoulderText,                   TEXT_VICTORYROAD2F_BOULDER3
; PRET| 
; PRET| VictoryRoad2TrainerHeaders:
; PRET| 	def_trainers
; PRET| VictoryRoad2TrainerHeader0:
; PRET| 	trainer EVENT_BEAT_VICTORY_ROAD_2_TRAINER_0, 4, VictoryRoad2FHikerBattleText, VictoryRoad2FHikerEndBattleText, VictoryRoad2FHikerAfterBattleText
; PRET| VictoryRoad2TrainerHeader1:
; PRET| 	trainer EVENT_BEAT_VICTORY_ROAD_2_TRAINER_1, 3, VictoryRoad2FSuperNerd1BattleText, VictoryRoad2FSuperNerd1EndBattleText, VictoryRoad2FSuperNerd1AfterBattleText
; PRET| VictoryRoad2TrainerHeader2:
; PRET| 	trainer EVENT_BEAT_VICTORY_ROAD_2_TRAINER_2, 3, VictoryRoad2FCooltrainerMBattleText, VictoryRoad2FCooltrainerMEndBattleText, VictoryRoad2FCooltrainerMAfterBattleText
; PRET| VictoryRoad2TrainerHeader3:
; PRET| 	trainer EVENT_BEAT_VICTORY_ROAD_2_TRAINER_3, 1, VictoryRoad2FSuperNerd2BattleText, VictoryRoad2FSuperNerd2EndBattleText, VictoryRoad2FSuperNerd2AfterBattleText
; PRET| VictoryRoad2TrainerHeader4:
; PRET| 	trainer EVENT_BEAT_VICTORY_ROAD_2_TRAINER_4, 3, VictoryRoad2FSuperNerd3BattleText, VictoryRoad2FSuperNerd3EndBattleText, VictoryRoad2FSuperNerd3AfterBattleText
; PRET| MoltresTrainerHeader:
; PRET| 	trainer EVENT_BEAT_MOLTRES, 0, VictoryRoad2FMoltresBattleText, VictoryRoad2FMoltresBattleText, VictoryRoad2FMoltresBattleText
; PRET| 	db -1 ; end

VictoryRoad2FHikerText:
    mov esi, VictoryRoad2TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

VictoryRoad2FSuperNerd1Text:
    mov esi, VictoryRoad2TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

VictoryRoad2FCooltrainerMText:
    mov esi, VictoryRoad2TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

VictoryRoad2FSuperNerd2Text:
    mov esi, VictoryRoad2TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

VictoryRoad2FSuperNerd3Text:
    mov esi, VictoryRoad2TrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

VictoryRoad2FMoltresText:
    mov esi, MoltresTrainerHeader
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] VictoryRoad2FMoltresBattleText (scripts/VictoryRoad2F.asm:143-143) — a generated asset already defines VictoryRoad2FMoltresBattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _VictoryRoad2FMoltresBattleText

    mov al, 73
    call PlayCry
    call WaitForSoundToFinish
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] VictoryRoad2FHikerBattleText (scripts/VictoryRoad2F.asm:151-208) — a generated asset already defines VictoryRoad2FHikerBattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _VictoryRoad2FHikerBattleText
; PRET| 	text_end
; PRET| 
; PRET| VictoryRoad2FHikerEndBattleText:
; PRET| 	text_far _VictoryRoad2FHikerEndBattleText
; PRET| 	text_end
; PRET| 
; PRET| VictoryRoad2FHikerAfterBattleText:
; PRET| 	text_far _VictoryRoad2FHikerAfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| VictoryRoad2FSuperNerd1BattleText:
; PRET| 	text_far _VictoryRoad2FSuperNerd1BattleText
; PRET| 	text_end
; PRET| 
; PRET| VictoryRoad2FSuperNerd1EndBattleText:
; PRET| 	text_far _VictoryRoad2FSuperNerd1EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| VictoryRoad2FSuperNerd1AfterBattleText:
; PRET| 	text_far _VictoryRoad2FSuperNerd1AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| VictoryRoad2FCooltrainerMBattleText:
; PRET| 	text_far _VictoryRoad2FCooltrainerMBattleText
; PRET| 	text_end
; PRET| 
; PRET| VictoryRoad2FCooltrainerMEndBattleText:
; PRET| 	text_far _VictoryRoad2FCooltrainerMEndBattleText
; PRET| 	text_end
; PRET| 
; PRET| VictoryRoad2FCooltrainerMAfterBattleText:
; PRET| 	text_far _VictoryRoad2FCooltrainerMAfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| VictoryRoad2FSuperNerd2BattleText:
; PRET| 	text_far _VictoryRoad2FSuperNerd2BattleText
; PRET| 	text_end
; PRET| 
; PRET| VictoryRoad2FSuperNerd2EndBattleText:
; PRET| 	text_far _VictoryRoad2FSuperNerd2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| VictoryRoad2FSuperNerd2AfterBattleText:
; PRET| 	text_far _VictoryRoad2FSuperNerd2AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| VictoryRoad2FSuperNerd3BattleText:
; PRET| 	text_far _VictoryRoad2FSuperNerd3BattleText
; PRET| 	text_end
; PRET| 
; PRET| VictoryRoad2FSuperNerd3EndBattleText:
; PRET| 	text_far _VictoryRoad2FSuperNerd3EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| VictoryRoad2FSuperNerd3AfterBattleText:
; PRET| 	text_far _VictoryRoad2FSuperNerd3AfterBattleText
; PRET| 	text_end
