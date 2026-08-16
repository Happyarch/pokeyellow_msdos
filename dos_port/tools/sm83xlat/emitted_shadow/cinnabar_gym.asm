; CinnabarGym.asm — translated from pret scripts/CinnabarGym.asm, scripts/CinnabarGym_2.asm, scripts/CinnabarGym_3.asm by dos_port/tools/sm83xlat.
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

%include "assets/audio_constants.inc"

global CinnabarGymFlagAction
global CinnabarGymGetOpponentTextScript
global CinnabarGymGymGuideText
global CinnabarGymOpenGateScript
global CinnabarGymPrintGymGuideText
global CinnabarGymResetScripts
global CinnabarGymScript_74fa3
global CinnabarGymScript_75023
global CinnabarGymScript_75032
global CinnabarGymScript_75041
global CinnabarGymScript_753de
global CinnabarGymScript_753e9
global CinnabarGymScript_753f3
global CinnabarGymSetTrainerHeader
global CinnabarGymStartBattleScript
global CinnabarGymSuperNerd1
global CinnabarGymSuperNerd2
global CinnabarGymSuperNerd3
global CinnabarGymSuperNerd4
global CinnabarGymSuperNerd5
global CinnabarGymSuperNerd6
global CinnabarGymSuperNerd7
global CinnabarGymText_f2169
global CinnabarGymText_f216e
global CinnabarGymText_f2173
global CinnabarGymText_f2178
global CinnabarGymText_f217d
global CinnabarGymText_f2182
global CinnabarGymText_f2187
global CinnabarGym_Script
global CinnabarGym_ScriptPointers
global CinnabarGym_TextPointers
global MovementNpcToLeft
global MovementNpcToLeftAndUp
global PikachuMovementData_74f97
global PikachuMovementData_74f9e
global TextPointers_f215d

extern ApplyPikachuMovementData   ; NOT YET DEFINED IN THE PORT
extern Bankswitch   ; NOT YET DEFINED IN THE PORT
extern CallFunctionInTable   ; NOT YET DEFINED IN THE PORT
extern CinnabarGymBlainePostBattleScript   ; NOT YET DEFINED IN THE PORT
extern CinnabarGymBlaineReceivedTM38Text   ; NOT YET DEFINED IN THE PORT
extern CinnabarGymBlaineTM38NoRoomText   ; NOT YET DEFINED IN THE PORT
extern CinnabarGymBlaineText   ; NOT YET DEFINED IN THE PORT
extern CinnabarGymBlaineVolcanoBadgeInfoText   ; NOT YET DEFINED IN THE PORT
extern CinnabarGymDefaultScript   ; NOT YET DEFINED IN THE PORT
extern CinnabarGymReceiveTM38   ; NOT YET DEFINED IN THE PORT
extern CinnabarGymSetMapAndTiles   ; NOT YET DEFINED IN THE PORT
extern DelayFrames   ; NOT YET DEFINED IN THE PORT
extern DisplayTextID   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EngageMapTrainer   ; NOT YET DEFINED IN THE PORT
extern FlagActionPredef   ; NOT YET DEFINED IN THE PORT
extern Func_f2150   ; NOT YET DEFINED IN THE PORT
extern GetPikachuFacingDirectionAndReturnToE   ; NOT YET DEFINED IN THE PORT
extern GiveItem   ; NOT YET DEFINED IN THE PORT
extern InitBattleEnemyParameters   ; NOT YET DEFINED IN THE PORT
extern LoadGymLeaderAndCityName   ; NOT YET DEFINED IN THE PORT
extern MoveSprite   ; NOT YET DEFINED IN THE PORT
extern PlaySound   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern SaveEndBattleTextPointers   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern UpdateCinnabarGymGateTileBlocks   ; NOT YET DEFINED IN THE PORT
extern WaitForSoundToFinish   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymBlainePreBattleText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymBlaineReceivedVolcanoBadgeText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymGymGuideBeatBlaineText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymGymGuideChampInMakingText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymSuperNerd1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymSuperNerd1BattleText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymSuperNerd1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymSuperNerd2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymSuperNerd2BattleText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymSuperNerd2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymSuperNerd3AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymSuperNerd3BattleText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymSuperNerd3EndBattleText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymSuperNerd4AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymSuperNerd4BattleText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymSuperNerd4EndBattleText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymSuperNerd5AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymSuperNerd5BattleText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymSuperNerd5EndBattleText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymSuperNerd6AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymSuperNerd6BattleText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymSuperNerd6EndBattleText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymSuperNerd7AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymSuperNerd7BattleText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymSuperNerd7EndBattleText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymText_1   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymText_2   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymText_3   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymText_4   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymText_5   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymText_6   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymText_7   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_CINNABARGYM_DEFAULT                     equ 0
SCRIPT_CINNABARGYM_GET_OPPONENT_TEXT           equ 1
SCRIPT_CINNABARGYM_OPEN_GATE                   equ 2
SCRIPT_CINNABARGYM_BLAINE_POST_BATTLE          equ 3
TEXT_CINNABARGYM_BLAINE_VOLCANO_BADGE_INFO     equ 10
TEXT_CINNABARGYM_BLAINE_RECEIVED_TM38          equ 11
TEXT_CINNABARGYM_BLAINE_TM38_NO_ROOM           equ 12

; pret RAM names the port still spells in SCREAMING_SNAKE. Guarded, so
; this file assembles both before and after the memmap rename lands.
%ifndef wCurrentMapScriptFlags
wCurrentMapScriptFlags                         equ W_CURRENT_MAP_SCRIPT_FLAGS
%endif
%ifndef wObtainedBadges
wObtainedBadges                                equ W_OBTAINED_BADGES
%endif
%ifndef wPlayerMovingDirection
wPlayerMovingDirection                         equ W_PLAYER_MOVING_DIRECTION
%endif

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
hGymGateIndex                                  equ 0xFFDB
wBeatGymFlags                                  equ 0xD729
wCinnabarGymCurScript                          equ 0xD65D
wOpponentAfterWrongAnswer                      equ 0xDA37
wPikachuSpawnStateFlags                        equ 0xD471
wd474                                          equ 0xD474

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

CinnabarGym_Script:
    call CinnabarGymSetMapAndTiles
    call EnableAutoTextBoxDrawing
    mov esi, CinnabarGym_ScriptPointers
    mov al, [ebp + wCinnabarGymCurScript]
    jmp CallFunctionInTable

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] CinnabarGymSetMapAndTiles (scripts/CinnabarGym.asm:9-19) — at scripts/CinnabarGym.asm:13: .LoadNames is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, wCurrentMapScriptFlags
; PRET| 	bit BIT_CUR_MAP_LOADED_2, [hl]
; PRET| 	res BIT_CUR_MAP_LOADED_2, [hl]
; PRET| 	push hl
; PRET| 	call nz, .LoadNames
; PRET| 	pop hl
; PRET| 	bit BIT_CUR_MAP_LOADED_1, [hl]
; PRET| 	res BIT_CUR_MAP_LOADED_1, [hl]
; PRET| 	call nz, UpdateCinnabarGymGateTileBlocks
; PRET| 	ResetEvent EVENT_2A7
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] CinnabarGymSetMapAndTiles.LoadNames (scripts/CinnabarGym.asm:22-24) — at scripts/CinnabarGym.asm:22: .CityName is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .CityName
; PRET| 	ld de, .LeaderName
; PRET| 	jp LoadGymLeaderAndCityName

; ---------------------------------------------------------------------------
; BAIL[inline-text-db] CinnabarGymSetMapAndTiles.CityName (scripts/CinnabarGym.asm:27-30) — at scripts/CinnabarGym.asm:27: db "CINNABAR ISLAND@"
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	db "CINNABAR ISLAND@"
; PRET| 
; PRET| .LeaderName:
; PRET| 	db "BLAINE@"

CinnabarGymResetScripts:
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov [ebp + wCinnabarGymCurScript], al
    mov [ebp + wCurMapScript], al
    mov [ebp + wOpponentAfterWrongAnswer], al
    ret

CinnabarGymSetTrainerHeader:
    mov al, [ebp + hTextID]
    mov [ebp + wTrainerHeaderFlagBit], al
    ret

CinnabarGymFlagAction:
; DEVIATION{class=banking; pret=macros/predef.asm:predef_jump; behavior=Predef dispatch replaced by a direct jmp, and the predef id is not left in A because no reader is live; evidence=PredefPointers is unported and the flat model needs no bank switch, dataflow shows A dead after this site; lifetime=retired when PredefPointers is ported}
    jmp FlagActionPredef

CinnabarGym_ScriptPointers:
    dd CinnabarGymDefaultScript
    dd CinnabarGymGetOpponentTextScript
    dd CinnabarGymOpenGateScript
    dd CinnabarGymBlainePostBattleScript

; ---------------------------------------------------------------------------
; BAIL[host-pointer-in-16bit-reg] CinnabarGymDefaultScript (scripts/CinnabarGym.asm:56-68) — at scripts/CinnabarGym.asm:67: de cannot hold the 32-bit address of MovementNpcToLeftAndUp; callee <none in range> has no abi.json entry
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wOpponentAfterWrongAnswer]
; PRET| 	and a
; PRET| 	ret z
; PRET| 	ldh [hSpriteIndex], a
; PRET| 	cp CINNABARGYM_SUPER_NERD3
; PRET| 	jr nz, .not_super_nerd3
; PRET| 	ld a, PLAYER_DIR_DOWN
; PRET| 	ld [wPlayerMovingDirection], a
; PRET| 	ld hl, PikachuMovementData_74f97
; PRET| 	ld b, SPRITE_FACING_DOWN
; PRET| 	call CinnabarGymScript_74fa3
; PRET| 	ld de, MovementNpcToLeftAndUp
; PRET| 	jr .MoveSprite

.not_super_nerd3:
    mov al, PLAYER_DIR_RIGHT
    mov [ebp + wPlayerMovingDirection], al
    mov esi, PikachuMovementData_74f9e
    mov bh, SPRITE_FACING_RIGHT
    call CinnabarGymScript_74fa3
    mov edi, MovementNpcToLeft   ; pret: ld de, MovementNpcToLeft — MoveSprite takes it in EDI
.MoveSprite:
    call MoveSprite
    mov al, SCRIPT_CINNABARGYM_GET_OPPONENT_TEXT
    mov [ebp + wCinnabarGymCurScript], al
    mov [ebp + wCurMapScript], al
    ret

MovementNpcToLeftAndUp:
    db NPC_MOVEMENT_LEFT
    db NPC_MOVEMENT_UP
    db -1
PikachuMovementData_74f97:
    db 0x00
    db 0x20
    db 0x1e
    db 0x35
    db 0x3f
MovementNpcToLeft:
    db NPC_MOVEMENT_LEFT
    db -1
PikachuMovementData_74f9e:
    db 0x00
    db 0x1d
    db 0x1f
    db 0x38
    db 0x3f

CinnabarGymScript_74fa3:
    mov al, [ebp + wPikachuSpawnStateFlags]
    test al, (1 << (7))
    jnz .nr_109
        ret
.nr_109:
    push esi
    push ebx
; DEVIATION{class=banking; pret=macros/farcall.asm:callfar; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call GetPikachuFacingDirectionAndReturnToE
    pop ebx
    pop esi
    mov al, bh
    cmp al, dl
    jz .nr_117
        ret
.nr_117:
    call ApplyPikachuMovementData
    ret

CinnabarGymGetOpponentTextScript:
    mov al, [ebp + wStatusFlags5]
    test al, (1 << (BIT_SCRIPTED_NPC_MOVEMENT))
    jz .nr_124
        ret
.nr_124:
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov al, [ebp + wOpponentAfterWrongAnswer]
    mov [ebp + wTrainerHeaderFlagBit], al
    mov [ebp + hTextID], al
    jmp DisplayTextID

CinnabarGymOpenGateScript:
    call CinnabarGymScript_753e9
    mov al, [ebp + wIsInBattle]
    cmp al, 0xff
    jz CinnabarGymResetScripts
    mov al, [ebp + wTrainerHeaderFlagBit]
    sub al, 0x2
    mov bl, al
    mov bh, FLAG_TEST
    mov esi, W_EVENT_FLAGS + EVENT_BYTE(EVENT_CINNABAR_GYM_GATE0_UNLOCKED)
    call CinnabarGymFlagAction
    mov al, bl
    test al, al
    jnz .no_sound
    mov al, [ebp + wTrainerHeaderFlagBit]
    cmp al, 2
    jz .no_sound
    mov bl, 30
    call DelayFrames
    call CinnabarGymScript_75023
    call CinnabarGymScript_75041
    call WaitForSoundToFinish
    mov al, SFX_GO_INSIDE
    call PlaySound
    call WaitForSoundToFinish
    jmp .asm_75013

.no_sound:
    call CinnabarGymScript_75023
    call CinnabarGymScript_75041
.asm_75013:
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov [ebp + wOpponentAfterWrongAnswer], al
    mov al, SCRIPT_CINNABARGYM_DEFAULT
    mov [ebp + wCinnabarGymCurScript], al
    mov [ebp + wCurMapScript], al
    ret

CinnabarGymScript_75023:
    mov al, [ebp + wTrainerHeaderFlagBit]
    mov [ebp + hGymGateIndex], al
    mov bl, al
    mov bh, FLAG_SET
    mov esi, W_EVENT_FLAGS + EVENT_BYTE(EVENT_BEAT_CINNABAR_GYM_TRAINER_0)
    call CinnabarGymFlagAction
    ret

CinnabarGymScript_75032:
    mov al, [ebp + wTrainerHeaderFlagBit]
    mov [ebp + hGymGateIndex], al
    mov bl, al
    mov bh, FLAG_TEST
    mov esi, W_EVENT_FLAGS + EVENT_BYTE(EVENT_BEAT_CINNABAR_GYM_TRAINER_0)
    call CinnabarGymFlagAction
    ret

CinnabarGymScript_75041:
    mov al, [ebp + wTrainerHeaderFlagBit]
    sub al, 2
    mov bl, al
    mov bh, FLAG_SET
    mov esi, W_EVENT_FLAGS + EVENT_BYTE(EVENT_CINNABAR_GYM_GATE0_UNLOCKED)
    call CinnabarGymFlagAction
    call UpdateCinnabarGymGateTileBlocks
    ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] CinnabarGymBlainePostBattleScript (scripts/CinnabarGym.asm:199-218) — at scripts/CinnabarGym.asm:213: .BagFull is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	call CinnabarGymScript_753e9
; PRET| 	ld a, [wIsInBattle]
; PRET| 	cp $ff
; PRET| 	jp z, CinnabarGymResetScripts
; PRET| 	ld a, PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| ; fallthrough
; PRET| CinnabarGymReceiveTM38:
; PRET| 	ld a, TEXT_CINNABARGYM_BLAINE_VOLCANO_BADGE_INFO
; PRET| 	ldh [hTextID], a
; PRET| 	call DisplayTextID
; PRET| 	SetEvent EVENT_BEAT_BLAINE
; PRET| 	lb bc, TM_FIRE_BLAST, 1
; PRET| 	call GiveItem
; PRET| 	jr nc, .BagFull
; PRET| 	ld a, TEXT_CINNABARGYM_BLAINE_RECEIVED_TM38
; PRET| 	ldh [hTextID], a
; PRET| 	call DisplayTextID
; PRET| 	SetEvent EVENT_GOT_TM38
; PRET| 	jr .gymVictory

; ---------------------------------------------------------------------------
; BAIL[event-range-macro] CinnabarGymReceiveTM38.BagFull (scripts/CinnabarGym.asm:220-235) — at scripts/CinnabarGym.asm:230: SetEventRange EVENT_BEAT_CINNABAR_GYM_TRAINER_0, EVENT_BEAT_CINNABAR_GYM_TRAINER_6
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, TEXT_CINNABARGYM_BLAINE_TM38_NO_ROOM
; PRET| 	ldh [hTextID], a
; PRET| 	call DisplayTextID
; PRET| .gymVictory
; PRET| 	ld hl, wObtainedBadges
; PRET| 	set BIT_VOLCANOBADGE, [hl]
; PRET| 	ld hl, wBeatGymFlags
; PRET| 	set BIT_VOLCANOBADGE, [hl]
; PRET| 
; PRET| 	; deactivate gym trainers
; PRET| 	SetEventRange EVENT_BEAT_CINNABAR_GYM_TRAINER_0, EVENT_BEAT_CINNABAR_GYM_TRAINER_6
; PRET| 
; PRET| 	ld hl, wCurrentMapScriptFlags
; PRET| 	set BIT_CUR_MAP_LOADED_1, [hl]
; PRET| 
; PRET| 	jp CinnabarGymResetScripts

CinnabarGym_TextPointers:
    dd CinnabarGymBlaineText
    dd CinnabarGymSuperNerd1
    dd CinnabarGymSuperNerd2
    dd CinnabarGymSuperNerd3
    dd CinnabarGymSuperNerd4
    dd CinnabarGymSuperNerd5
    dd CinnabarGymSuperNerd6
    dd CinnabarGymSuperNerd7
    dd CinnabarGymGymGuideText
    dd CinnabarGymBlaineVolcanoBadgeInfoText
    dd CinnabarGymBlaineReceivedTM38Text
    dd CinnabarGymBlaineTM38NoRoomText

CinnabarGymStartBattleScript:
    mov al, [ebp + hSpriteIndex]
    mov [ebp + wSpriteIndex], al
    call EngageMapTrainer
    call InitBattleEnemyParameters
    mov esi, wStatusFlags3
    or byte [ebp + esi], (1 << (BIT_TALKED_TO_TRAINER))
    or byte [ebp + esi], (1 << (BIT_PRINT_END_BATTLE_TEXT))
    mov al, [ebp + wSpriteIndex]
    cmp al, 1
    jz .blaine
    mov al, SCRIPT_CINNABARGYM_OPEN_GATE
    jmp .not_blaine

.blaine:
    mov al, SCRIPT_CINNABARGYM_BLAINE_POST_BATTLE
.not_blaine:
    mov [ebp + wCinnabarGymCurScript], al
    mov [ebp + wCurMapScript], al
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] CinnabarGymBlaineText (scripts/CinnabarGym.asm:274-280) — at scripts/CinnabarGym.asm:275: .beforeBeat is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_BEAT_BLAINE
; PRET| 	jr z, .beforeBeat
; PRET| 	CheckEventReuseA EVENT_GOT_TM38
; PRET| 	jr nz, .afterBeat
; PRET| 	call z, CinnabarGymReceiveTM38
; PRET| 	call DisableWaitingAfterTextDisplay
; PRET| 	jp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] CinnabarGymBlaineText.afterBeat (scripts/CinnabarGym.asm:282-284) — at scripts/CinnabarGym.asm:282: .PostBattleAdviceText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .PostBattleAdviceText
; PRET| 	call PrintText
; PRET| 	jp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] CinnabarGymBlaineText.beforeBeat (scripts/CinnabarGym.asm:286-293) — at scripts/CinnabarGym.asm:286: .PreBattleText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .PreBattleText
; PRET| 	call PrintText
; PRET| 	ld hl, .ReceivedVolcanoBadgeText
; PRET| 	ld de, .ReceivedVolcanoBadgeText
; PRET| 	call SaveEndBattleTextPointers
; PRET| 	ld a, $7
; PRET| 	ld [wGymLeaderNo], a
; PRET| 	jp CinnabarGymStartBattleScript

; ---------------------------------------------------------------------------
; BAIL[text-sound-command-unported] CinnabarGymBlaineText.PreBattleText (scripts/CinnabarGym.asm:296-321) — at scripts/CinnabarGym.asm:301: sound_get_key_item ; actually plays the second channel of SFX_BALL_POOF due to the wrong music bank being loaded
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _CinnabarGymBlainePreBattleText
; PRET| 	text_end
; PRET| 
; PRET| .ReceivedVolcanoBadgeText:
; PRET| 	text_far _CinnabarGymBlaineReceivedVolcanoBadgeText
; PRET| 	sound_get_key_item ; actually plays the second channel of SFX_BALL_POOF due to the wrong music bank being loaded
; PRET| 	text_waitbutton
; PRET| 	text_end
; PRET| 
; PRET| .PostBattleAdviceText:
; PRET| 	text_far _CinnabarGymBlainePostBattleAdviceText
; PRET| 	text_end
; PRET| 
; PRET| CinnabarGymBlaineVolcanoBadgeInfoText:
; PRET| 	text_far _CinnabarGymBlaineVolcanoBadgeInfoText
; PRET| 	text_end
; PRET| 
; PRET| CinnabarGymBlaineReceivedTM38Text:
; PRET| 	text_far _CinnabarGymBlaineReceivedTM38Text
; PRET| 	sound_get_item_1
; PRET| 	text_far _CinnabarGymBlaineTM38ExplanationText
; PRET| 	text_end
; PRET| 
; PRET| CinnabarGymBlaineTM38NoRoomText:
; PRET| 	text_far _CinnabarGymBlaineTM38NoRoomText
; PRET| 	text_end

CinnabarGymSuperNerd1:
    call CinnabarGymSetTrainerHeader
    CheckEvent EVENT_BEAT_CINNABAR_GYM_TRAINER_0
    jnz .defeated
    mov esi, .BattleText
    call PrintText
    mov esi, .EndBattleText
    mov edx, .EndBattleText   ; pret: ld de, .EndBattleText — SaveEndBattleTextPointers takes it in EDX
    call SaveEndBattleTextPointers
    jmp CinnabarGymStartBattleScript

.defeated:
    mov esi, .AfterBattleText
    call PrintText
    jmp TextScriptEnd

.BattleText:
    text_far _CinnabarGymSuperNerd1BattleText
    text_end
.EndBattleText:
    text_far _CinnabarGymSuperNerd1EndBattleText
    text_end
.AfterBattleText:
    text_far _CinnabarGymSuperNerd1AfterBattleText
    text_end

CinnabarGymSuperNerd2:
    call CinnabarGymSetTrainerHeader
    CheckEvent EVENT_BEAT_CINNABAR_GYM_TRAINER_1
    jnz .defeated
    call CinnabarGymScript_753f3
    jnz .asm_75196
    CheckEvent EVENT_CINNABAR_GYM_GATE1_UNLOCKED
    jnz .asm_75196
    mov dl, 0x00
    jmp CinnabarGymScript_753de

.asm_75196:
    mov esi, .BattleText
    call PrintText
    mov esi, .EndBattleText
    mov edx, .EndBattleText   ; pret: ld de, .EndBattleText — SaveEndBattleTextPointers takes it in EDX
    call SaveEndBattleTextPointers
    jmp CinnabarGymStartBattleScript

.defeated:
    mov esi, .AfterBattleText
    call PrintText
    jmp TextScriptEnd

.BattleText:
    text_far _CinnabarGymSuperNerd2BattleText
    text_end
.EndBattleText:
    text_far _CinnabarGymSuperNerd2EndBattleText
    text_end
.AfterBattleText:
    text_far _CinnabarGymSuperNerd2AfterBattleText
    text_end

CinnabarGymSuperNerd3:
    call CinnabarGymSetTrainerHeader
    CheckEvent EVENT_BEAT_CINNABAR_GYM_TRAINER_2
    jnz .defeated
    call CinnabarGymScript_753f3
    jnz .asm_751dc
    CheckEvent EVENT_CINNABAR_GYM_GATE2_UNLOCKED
    jnz .asm_751dc
    mov dl, 0x1
    jmp CinnabarGymScript_753de

.asm_751dc:
    mov esi, .BattleText
    call PrintText
    mov esi, .EndBattleText
    mov edx, .EndBattleText   ; pret: ld de, .EndBattleText — SaveEndBattleTextPointers takes it in EDX
    call SaveEndBattleTextPointers
    jmp CinnabarGymStartBattleScript

.defeated:
    mov esi, .AfterBattleText
    call PrintText
    jmp TextScriptEnd

.BattleText:
    text_far _CinnabarGymSuperNerd3BattleText
    text_end
.EndBattleText:
    text_far _CinnabarGymSuperNerd3EndBattleText
    text_end
.AfterBattleText:
    text_far _CinnabarGymSuperNerd3AfterBattleText
    text_end

CinnabarGymSuperNerd4:
    call CinnabarGymSetTrainerHeader
    CheckEvent EVENT_BEAT_CINNABAR_GYM_TRAINER_3
    jnz .defeated
    call CinnabarGymScript_753f3
    jnz .asm_75222
    CheckEvent EVENT_CINNABAR_GYM_GATE3_UNLOCKED
    jnz .asm_75222
    mov dl, 0x2
    jmp CinnabarGymScript_753de

.asm_75222:
    mov esi, .BattleText
    call PrintText
    mov esi, .EndBattleText
    mov edx, .EndBattleText   ; pret: ld de, .EndBattleText — SaveEndBattleTextPointers takes it in EDX
    call SaveEndBattleTextPointers
    jmp CinnabarGymStartBattleScript

.defeated:
    mov esi, .AfterBattleText
    call PrintText
    jmp TextScriptEnd

.BattleText:
    text_far _CinnabarGymSuperNerd4BattleText
    text_end
.EndBattleText:
    text_far _CinnabarGymSuperNerd4EndBattleText
    text_end
.AfterBattleText:
    text_far _CinnabarGymSuperNerd4AfterBattleText
    text_end

CinnabarGymSuperNerd5:
    call CinnabarGymSetTrainerHeader
    CheckEvent EVENT_BEAT_CINNABAR_GYM_TRAINER_4
    jnz .defeated
    call CinnabarGymScript_753f3
    jnz .asm_75222
    CheckEvent EVENT_CINNABAR_GYM_GATE4_UNLOCKED
    jnz .asm_75222
    mov dl, 0x3
    jmp CinnabarGymScript_753de

.asm_75222:
    mov esi, .BattleText
    call PrintText
    mov esi, .EndBattleText
    mov edx, .EndBattleText   ; pret: ld de, .EndBattleText — SaveEndBattleTextPointers takes it in EDX
    call SaveEndBattleTextPointers
    jmp CinnabarGymStartBattleScript

.defeated:
    mov esi, .AfterBattleText
    call PrintText
    jmp TextScriptEnd

.BattleText:
    text_far _CinnabarGymSuperNerd5BattleText
    text_end
.EndBattleText:
    text_far _CinnabarGymSuperNerd5EndBattleText
    text_end
.AfterBattleText:
    text_far _CinnabarGymSuperNerd5AfterBattleText
    text_end

CinnabarGymSuperNerd6:
    call CinnabarGymSetTrainerHeader
    CheckEvent EVENT_BEAT_CINNABAR_GYM_TRAINER_5
    jnz .defeated
    call CinnabarGymScript_753f3
    jnz .asm_75222
    CheckEvent EVENT_CINNABAR_GYM_GATE5_UNLOCKED
    jnz .asm_75222
    mov dl, 0x4
    jmp CinnabarGymScript_753de

.asm_75222:
    mov esi, .BattleText
    call PrintText
    mov esi, .EndBattleText
    mov edx, .EndBattleText   ; pret: ld de, .EndBattleText — SaveEndBattleTextPointers takes it in EDX
    call SaveEndBattleTextPointers
    jmp CinnabarGymStartBattleScript

.defeated:
    mov esi, .AfterBattleText
    call PrintText
    jmp TextScriptEnd

.BattleText:
    text_far _CinnabarGymSuperNerd6BattleText
    text_end
.EndBattleText:
    text_far _CinnabarGymSuperNerd6EndBattleText
    text_end
.AfterBattleText:
    text_far _CinnabarGymSuperNerd6AfterBattleText
    text_end

CinnabarGymSuperNerd7:
    call CinnabarGymSetTrainerHeader
    CheckEvent EVENT_BEAT_CINNABAR_GYM_TRAINER_6
    jnz .defeated
    call CinnabarGymScript_753f3
    jnz .asm_75222
    CheckEvent EVENT_CINNABAR_GYM_GATE6_UNLOCKED
    jnz .asm_75222
    mov dl, 0x5
    jmp CinnabarGymScript_753de

.asm_75222:
    mov esi, .BattleText
    call PrintText
    mov esi, .EndBattleText
    mov edx, .EndBattleText   ; pret: ld de, .EndBattleText — SaveEndBattleTextPointers takes it in EDX
    call SaveEndBattleTextPointers
    jmp CinnabarGymStartBattleScript

.defeated:
    mov esi, .AfterBattleText
    call PrintText
    jmp TextScriptEnd

.BattleText:
    text_far _CinnabarGymSuperNerd7BattleText
    text_end
.EndBattleText:
    text_far _CinnabarGymSuperNerd7EndBattleText
    text_end
.AfterBattleText:
    text_far _CinnabarGymSuperNerd7AfterBattleText
    text_end

CinnabarGymGymGuideText:
; DEVIATION{class=banking; pret=macros/farcall.asm:callfar; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call CinnabarGymPrintGymGuideText
    jmp TextScriptEnd

CinnabarGymScript_753de:
; DEVIATION{class=banking; pret=macros/farcall.asm:callfar; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call Func_f2150
    jmp TextScriptEnd

CinnabarGymScript_753e9:
    push esi
    mov esi, wd474
    test byte [ebp + esi], (1 << (7))
    and byte [ebp + esi], ~(1 << (7)) & 0xFF
    pop esi
    ret

CinnabarGymScript_753f3:
    push esi
    mov esi, wd474
    test byte [ebp + esi], (1 << (7))
    pop esi
    ret

CinnabarGymPrintGymGuideText:
    CheckEvent EVENT_BEAT_BLAINE
    jnz .afterBeat
    mov esi, .ChampInMakingText
    jmp .done

.afterBeat:
    mov esi, .BeatBlaineText
.done:
    call PrintText
    ret

.ChampInMakingText:
    text_far _CinnabarGymGymGuideChampInMakingText
    text_end
.BeatBlaineText:
    text_far _CinnabarGymGymGuideBeatBlaineText
    text_end

; ---------------------------------------------------------------------------
; BAIL[add-hl-r16] Func_f2150 (scripts/CinnabarGym_3.asm:21-28) — at scripts/CinnabarGym_3.asm:23: hl de
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, TextPointers_f215d
; PRET| 	ld d, 0
; PRET| 	add hl, de
; PRET| 	add hl, de
; PRET| 	ld a, [hli]
; PRET| 	ld h, [hl]
; PRET| 	ld l, a
; PRET| 	jp PrintText

TextPointers_f215d:
    dd CinnabarGymText_f2169
    dd CinnabarGymText_f216e
    dd CinnabarGymText_f2173
    dd CinnabarGymText_f2178
    dd CinnabarGymText_f217d
    dd CinnabarGymText_f2182
CinnabarGymText_f2169:
    text_far _CinnabarGymText_1
    text_end
CinnabarGymText_f216e:
    text_far _CinnabarGymText_2
    text_end
CinnabarGymText_f2173:
    text_far _CinnabarGymText_3
    text_end
CinnabarGymText_f2178:
    text_far _CinnabarGymText_4
    text_end
CinnabarGymText_f217d:
    text_far _CinnabarGymText_5
    text_end
CinnabarGymText_f2182:
    text_far _CinnabarGymText_6
    text_end
CinnabarGymText_f2187:
    text_far _CinnabarGymText_7
    text_end
