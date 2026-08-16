; SilphCo7F.asm — translated from pret scripts/SilphCo7F.asm by dos_port/tools/sm83xlat.
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

global SilphCo7FRivalDefeatedText
global SilphCo7FRivalGoodLuckToYouText
global SilphCo7FRivalStartBattleScript
global SilphCo7FRivalText
global SilphCo7FRivalVictoryText
global SilphCo7FRivalWaitedHereText
global SilphCo7FRocket1Text
global SilphCo7FRocket2Text
global SilphCo7FRocket3Text
global SilphCo7FScientistText
global SilphCo7FSetCurScript
global SilphCo7FSetDefaultScript
global SilphCo7FSilphWorkerM2Text
global SilphCo7FSilphWorkerM3Text
global SilphCo7FSilphWorkerM4Text
global SilphCo7F_Script
global SilphCo7F_ScriptPointers

extern ArePlayerCoordsInArray   ; NOT YET DEFINED IN THE PORT
extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern Delay3   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern DisplayTextID   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern GivePokemon   ; NOT YET DEFINED IN THE PORT
extern HideObject   ; NOT YET DEFINED IN THE PORT
extern MoveSprite   ; NOT YET DEFINED IN THE PORT
extern Music_RivalAlternateStart   ; NOT YET DEFINED IN THE PORT
extern PickUpItemText   ; NOT YET DEFINED IN THE PORT
extern PlayDefaultMusic   ; NOT YET DEFINED IN THE PORT
extern PlayMusic   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern ReplaceTileBlock   ; NOT YET DEFINED IN THE PORT
extern SaveEndBattleTextPointers   ; NOT YET DEFINED IN THE PORT
extern SetSpriteFacingDirectionAndDelay   ; NOT YET DEFINED IN THE PORT
extern SetSpriteMovementBytesToFF   ; NOT YET DEFINED IN THE PORT
extern SilphCo7FDefaultScript   ; NOT YET DEFINED IN THE PORT
extern SilphCo7FRivalAfterBattleScript   ; NOT YET DEFINED IN THE PORT
extern SilphCo7FRivalExitScript   ; NOT YET DEFINED IN THE PORT
extern SilphCo7FRocket1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo7FRocket1BattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo7FRocket1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo7FRocket2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo7FRocket2BattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo7FRocket2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo7FRocket3AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo7FRocket3BattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo7FRocket3EndBattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo7FScientistAfterBattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo7FScientistBattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo7FScientistEndBattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo7FSilphWorkerM1Text   ; NOT YET DEFINED IN THE PORT
extern SilphCo7F_GateCallbackScript   ; NOT YET DEFINED IN THE PORT
extern SilphCo7F_SetCardKeyDoorYScript   ; NOT YET DEFINED IN THE PORT
extern SilphCo7F_TextPointers   ; NOT YET DEFINED IN THE PORT
extern SilphCo7F_UnlockedDoorEventScript   ; NOT YET DEFINED IN THE PORT
extern SilphCo7TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern SilphCo7TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern SilphCo7TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern SilphCo7TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern SilphCo7TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern StopAllMusic   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern WaitForTextScrollButtonPress   ; NOT YET DEFINED IN THE PORT
extern _SilphCo7FRivalDefeatedText   ; NOT YET DEFINED IN THE PORT
extern _SilphCo7FRivalGoodLuckToYouText   ; NOT YET DEFINED IN THE PORT
extern _SilphCo7FRivalText   ; NOT YET DEFINED IN THE PORT
extern _SilphCo7FRivalVictoryText   ; NOT YET DEFINED IN THE PORT
extern _SilphCo7FRivalWaitedHereText   ; NOT YET DEFINED IN THE PORT
extern _SilphCo7FSilphWorkerM1HaveThisPokemonText   ; NOT YET DEFINED IN THE PORT
extern _SilphCo7FSilphWorkerM1IsOurPresidentOkText   ; NOT YET DEFINED IN THE PORT
extern _SilphCo7FSilphWorkerM1LaprasDescriptionText   ; NOT YET DEFINED IN THE PORT
extern _SilphCo7FSilphWorkerM1SavedText   ; NOT YET DEFINED IN THE PORT
extern _SilphCo7FSilphWorkerM2AfterTheMasterBallText   ; NOT YET DEFINED IN THE PORT
extern _SilphCo7FSilphWorkerM2CancelledMasterBallText   ; NOT YET DEFINED IN THE PORT
extern _SilphCo7FSilphWorkerM3ItWouldBeBadText   ; NOT YET DEFINED IN THE PORT
extern _SilphCo7FSilphWorkerM3YouChasedOffTeamRocketText   ; NOT YET DEFINED IN THE PORT
extern _SilphCo7FSilphWorkerM4ItsReallyDangerousHereText   ; NOT YET DEFINED IN THE PORT
extern _SilphCo7FSilphWorkerM4SafeAtLastText   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_SILPHCO7F_RIVAL_START_BATTLE            equ 3
SCRIPT_SILPHCO7F_RIVAL_AFTER_BATTLE            equ 4
SCRIPT_SILPHCO7F_RIVAL_EXIT                    equ 5
TEXT_SILPHCO7F_SILPH_WORKER_M1                 equ 1
TEXT_SILPHCO7F_SILPH_WORKER_M2                 equ 2
TEXT_SILPHCO7F_SILPH_WORKER_M3                 equ 3
TEXT_SILPHCO7F_SILPH_WORKER_M4                 equ 4
TEXT_SILPHCO7F_ROCKET1                         equ 5
TEXT_SILPHCO7F_SCIENTIST                       equ 6
TEXT_SILPHCO7F_ROCKET2                         equ 7
TEXT_SILPHCO7F_ROCKET3                         equ 8
TEXT_SILPHCO7F_RIVAL                           equ 9
TEXT_SILPHCO7F_CALCIUM                         equ 10
TEXT_SILPHCO7F_TM_SWORDS_DANCE                 equ 11
TEXT_SILPHCO7F_UNREFERENCED_ITEM               equ 12
TEXT_SILPHCO7F_RIVAL_WAITED_HERE               equ 13
TEXT_SILPHCO7F_RIVAL_DEFEATED                  equ 14
TEXT_SILPHCO7F_RIVAL_GOOD_LUCK_TO_YOU          equ 15

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
hSpriteFacingDirection                         equ 0xFF8D
hUnlockedSilphCoDoors                          equ 0xFFE0
wAddedToParty                                  equ 0xCCD3
wCoordIndex                                    equ 0xCD3D
wSavedCoordIndex                               equ 0xCF0D
wSilphCo7FCurScript                            equ 0xD647

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

SilphCo7F_Script:
    call SilphCo7F_GateCallbackScript
    call EnableAutoTextBoxDrawing
    mov esi, SilphCo7TrainerHeaders
    mov edi, SilphCo7F_ScriptPointers   ; pret: ld de, SilphCo7F_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wSilphCo7FCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wSilphCo7FCurScript], al
    ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] SilphCo7F_GateCallbackScript (scripts/SilphCo7F.asm:12-42) — at scripts/SilphCo7F.asm:20: .unlock_door1 is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, wCurrentMapScriptFlags
; PRET| 	bit BIT_CUR_MAP_LOADED_1, [hl]
; PRET| 	res BIT_CUR_MAP_LOADED_1, [hl]
; PRET| 	ret z
; PRET| 	ld hl, .GateCoordinates
; PRET| 	call SilphCo7F_SetCardKeyDoorYScript
; PRET| 	call SilphCo7F_UnlockedDoorEventScript
; PRET| 	CheckEvent EVENT_SILPH_CO_7_UNLOCKED_DOOR1
; PRET| 	jr nz, .unlock_door1
; PRET| 	push af
; PRET| 	ld a, $54
; PRET| 	ld [wNewTileBlockID], a
; PRET| 	lb bc, 3, 5
; PRET| 	predef ReplaceTileBlock
; PRET| 	pop af
; PRET| .unlock_door1
; PRET| 	CheckEventAfterBranchReuseA EVENT_SILPH_CO_7_UNLOCKED_DOOR2, EVENT_SILPH_CO_7_UNLOCKED_DOOR1
; PRET| 	jr nz, .unlock_door2
; PRET| 	push af
; PRET| 	ld a, $54
; PRET| 	ld [wNewTileBlockID], a
; PRET| 	lb bc, 2, 10
; PRET| 	predef ReplaceTileBlock
; PRET| 	pop af
; PRET| .unlock_door2
; PRET| 	CheckEventAfterBranchReuseA EVENT_SILPH_CO_7_UNLOCKED_DOOR3, EVENT_SILPH_CO_7_UNLOCKED_DOOR2
; PRET| 	ret nz
; PRET| 	ld a, $54
; PRET| 	ld [wNewTileBlockID], a
; PRET| 	lb bc, 6, 10
; PRET| 	predef_jump ReplaceTileBlock

.GateCoordinates:
    db 3, 5
    db 2, 10
    db 6, 10
    db -1

; ---------------------------------------------------------------------------
; BAIL[pointer-domain-unknown] SilphCo7F_SetCardKeyDoorYScript (scripts/SilphCo7F.asm:51-71) — at scripts/SilphCo7F.asm:61: HL domain is top at a dereference
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	push hl
; PRET| 	ld hl, wCardKeyDoorY
; PRET| 	ld a, [hli]
; PRET| 	ld b, a
; PRET| 	ld a, [hl]
; PRET| 	ld c, a
; PRET| 	xor a
; PRET| 	ldh [hUnlockedSilphCoDoors], a
; PRET| 	pop hl
; PRET| .loop_check_doors
; PRET| 	ld a, [hli]
; PRET| 	cp $ff
; PRET| 	jr z, .exit_loop
; PRET| 	push hl
; PRET| 	ld hl, hUnlockedSilphCoDoors
; PRET| 	inc [hl]
; PRET| 	pop hl
; PRET| 	cp b
; PRET| 	jr z, .check_y_coord
; PRET| 	inc hl
; PRET| 	jr .loop_check_doors

; ---------------------------------------------------------------------------
; BAIL[pointer-domain-unknown] SilphCo7F_SetCardKeyDoorYScript.check_y_coord (scripts/SilphCo7F.asm:73-80) — at scripts/SilphCo7F.asm:73: HL domain is top at a dereference
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [hli]
; PRET| 	cp c
; PRET| 	jr nz, .loop_check_doors
; PRET| 	ld hl, wCardKeyDoorY
; PRET| 	xor a
; PRET| 	ld [hli], a
; PRET| 	ld [hl], a
; PRET| 	ret

.exit_loop:
    xor al, al
    mov [ebp + hUnlockedSilphCoDoors], al
    ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] SilphCo7F_UnlockedDoorEventScript (scripts/SilphCo7F.asm:87-94) — at scripts/SilphCo7F.asm:92: .unlock_door1 is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	EventFlagAddress hl, EVENT_SILPH_CO_7_UNLOCKED_DOOR1
; PRET| 	ldh a, [hUnlockedSilphCoDoors]
; PRET| 	and a
; PRET| 	ret z
; PRET| 	cp $1
; PRET| 	jr nz, .unlock_door1
; PRET| 	SetEventReuseHL EVENT_SILPH_CO_7_UNLOCKED_DOOR1
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] SilphCo7F_UnlockedDoorEventScript.unlock_door1 (scripts/SilphCo7F.asm:96-99) — at scripts/SilphCo7F.asm:97: .unlock_door2 is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	cp $2
; PRET| 	jr nz, .unlock_door2
; PRET| 	SetEventAfterBranchReuseHL EVENT_SILPH_CO_7_UNLOCKED_DOOR2, EVENT_SILPH_CO_7_UNLOCKED_DOOR1
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[event-byte-assembly-state] SilphCo7F_UnlockedDoorEventScript.unlock_door2 (scripts/SilphCo7F.asm:101-102) — at scripts/SilphCo7F.asm:101: SetEventAfterBranchReuseHL EVENT_SILPH_CO_7_UNLOCKED_DOOR3, EVENT_SILPH_CO_7_UNLOCKED_DOOR1
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	SetEventAfterBranchReuseHL EVENT_SILPH_CO_7_UNLOCKED_DOOR3, EVENT_SILPH_CO_7_UNLOCKED_DOOR1
; PRET| 	ret

SilphCo7FSetDefaultScript:
    xor al, al
    mov [ebp + wJoyIgnore], al
SilphCo7FSetCurScript:
    mov [ebp + wSilphCo7FCurScript], al
    mov [ebp + wCurMapScript], al
    ret

SilphCo7F_ScriptPointers:
    dd SilphCo7FDefaultScript
    dd DisplayEnemyTrainerTextAndStartBattle
    dd EndTrainerBattle
    dd SilphCo7FRivalStartBattleScript
    dd SilphCo7FRivalAfterBattleScript
    dd SilphCo7FRivalExitScript

; ---------------------------------------------------------------------------
; BAIL[bank-expression] SilphCo7FDefaultScript (scripts/SilphCo7F.asm:123-155) — at scripts/SilphCo7F.asm:135: BANK(Music_MeetRival)
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_BEAT_SILPH_CO_RIVAL
; PRET| 	jp nz, CheckFightingMapTrainers
; PRET| 	ld hl, .RivalEncounterCoordinates
; PRET| 	call ArePlayerCoordsInArray
; PRET| 	jp nc, CheckFightingMapTrainers
; PRET| 	xor a
; PRET| 	ldh [hJoyHeld], a
; PRET| 	ld a, PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 	ld a, PLAYER_DIR_DOWN
; PRET| 	ld [wPlayerMovingDirection], a
; PRET| 	call StopAllMusic
; PRET| 	ld c, BANK(Music_MeetRival)
; PRET| 	ld a, MUSIC_MEET_RIVAL
; PRET| 	call PlayMusic
; PRET| 	ld a, TEXT_SILPHCO7F_RIVAL
; PRET| 	ldh [hTextID], a
; PRET| 	call DisplayTextID
; PRET| 	ld a, SILPHCO7F_RIVAL
; PRET| 	ldh [hSpriteIndex], a
; PRET| 	call SetSpriteMovementBytesToFF
; PRET| 	ld de, .RivalMovementUp
; PRET| 	ld a, [wCoordIndex]
; PRET| 	ld [wSavedCoordIndex], a
; PRET| 	cp 1 ; index of second, lower entry in .RivalEncounterCoordinates
; PRET| 	jr z, .full_rival_movement
; PRET| 	inc de
; PRET| .full_rival_movement
; PRET| 	ld a, SILPHCO7F_RIVAL
; PRET| 	ldh [hSpriteIndex], a
; PRET| 	call MoveSprite
; PRET| 	ld a, SCRIPT_SILPHCO7F_RIVAL_START_BATTLE
; PRET| 	jp SilphCo7FSetCurScript

.RivalEncounterCoordinates:
    db 2, 3
    db 3, 3
    db -1
.RivalMovementUp:
    db NPC_MOVEMENT_UP
    db NPC_MOVEMENT_UP
    db NPC_MOVEMENT_UP
    db NPC_MOVEMENT_UP
    db -1

SilphCo7FRivalStartBattleScript:
    mov al, [ebp + wStatusFlags5]
    test al, (1 << (BIT_SCRIPTED_NPC_MOVEMENT))
    jz .nr_172
        ret
.nr_172:
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov al, TEXT_SILPHCO7F_RIVAL_WAITED_HERE
    mov [ebp + hTextID], al
    call DisplayTextID
    call Delay3
    mov esi, wStatusFlags3
    or byte [ebp + esi], (1 << (BIT_TALKED_TO_TRAINER))
    or byte [ebp + esi], (1 << (BIT_PRINT_END_BATTLE_TEXT))
    mov esi, SilphCo7FRivalDefeatedText
    mov edx, SilphCo7FRivalVictoryText   ; pret: ld de, SilphCo7FRivalVictoryText — SaveEndBattleTextPointers takes it in EDX
    call SaveEndBattleTextPointers
    mov al, OPP_RIVAL2
    mov [ebp + wCurOpponent], al
    mov al, [ebp + W_RIVAL_STARTER]
    add al, 4
    mov [ebp + wTrainerNo], al
    mov al, SCRIPT_SILPHCO7F_RIVAL_AFTER_BATTLE
    call SilphCo7FSetCurScript
    ret

; ---------------------------------------------------------------------------
; BAIL[host-pointer-in-16bit-reg] SilphCo7FRivalAfterBattleScript (scripts/SilphCo7F.asm:195-223) — at scripts/SilphCo7F.asm:213: de cannot hold the 32-bit address of .RivalWalkAroundPlayerMovement; callee <none in range> has no abi.json entry
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wIsInBattle]
; PRET| 	cp $ff
; PRET| 	jp z, SilphCo7FSetDefaultScript
; PRET| 	ld a, PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 	SetEvent EVENT_BEAT_SILPH_CO_RIVAL
; PRET| 	ld a, PLAYER_DIR_DOWN
; PRET| 	ld [wPlayerMovingDirection], a
; PRET| 	ld a, SILPHCO7F_RIVAL
; PRET| 	ldh [hSpriteIndex], a
; PRET| 	ld a, SPRITE_FACING_UP
; PRET| 	ldh [hSpriteFacingDirection], a
; PRET| 	call SetSpriteFacingDirectionAndDelay
; PRET| 	ld a, TEXT_SILPHCO7F_RIVAL_GOOD_LUCK_TO_YOU
; PRET| 	ldh [hTextID], a
; PRET| 	call DisplayTextID
; PRET| 	call StopAllMusic
; PRET| 	farcall Music_RivalAlternateStart
; PRET| 	ld de, .RivalWalkAroundPlayerMovement
; PRET| 	ld a, [wSavedCoordIndex]
; PRET| 	cp 1 ; index of second, lower entry in SilphCo7FDefaultScript.RivalEncounterCoordinates
; PRET| 	jr nz, .walk_around_player
; PRET| 	ld de, .RivalExitRightMovement
; PRET| .walk_around_player
; PRET| 	ld a, SILPHCO7F_RIVAL
; PRET| 	ldh [hSpriteIndex], a
; PRET| 	call MoveSprite
; PRET| 	ld a, SCRIPT_SILPHCO7F_RIVAL_EXIT
; PRET| 	jp SilphCo7FSetCurScript

.RivalExitRightMovement:
    db NPC_MOVEMENT_RIGHT
    db NPC_MOVEMENT_RIGHT
    db -1
.RivalWalkAroundPlayerMovement:
    db NPC_MOVEMENT_LEFT
    db NPC_MOVEMENT_UP
    db NPC_MOVEMENT_UP
    db NPC_MOVEMENT_RIGHT
    db NPC_MOVEMENT_RIGHT
    db NPC_MOVEMENT_RIGHT
    db NPC_MOVEMENT_DOWN
    db -1

; ---------------------------------------------------------------------------
; BAIL[predef-leaves-id-in-a] SilphCo7FRivalExitScript (scripts/SilphCo7F.asm:241-250) — at scripts/SilphCo7F.asm:246: predef HideObject
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wStatusFlags5]
; PRET| 	bit BIT_SCRIPTED_NPC_MOVEMENT, a
; PRET| 	ret nz
; PRET| 	ld a, TOGGLE_SILPH_CO_7F_RIVAL
; PRET| 	ld [wToggleableObjectIndex], a
; PRET| 	predef HideObject
; PRET| 	call PlayDefaultMusic
; PRET| 	xor a
; PRET| 	ld [wJoyIgnore], a
; PRET| 	jp SilphCo7FSetCurScript

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] SilphCo7F_TextPointers (scripts/SilphCo7F.asm:253-280) — a generated asset already defines SilphCo7TrainerHeaders
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	def_text_pointers
; PRET| 	dw_const SilphCo7FSilphWorkerM1Text,      TEXT_SILPHCO7F_SILPH_WORKER_M1
; PRET| 	dw_const SilphCo7FSilphWorkerM2Text,      TEXT_SILPHCO7F_SILPH_WORKER_M2
; PRET| 	dw_const SilphCo7FSilphWorkerM3Text,      TEXT_SILPHCO7F_SILPH_WORKER_M3
; PRET| 	dw_const SilphCo7FSilphWorkerM4Text,      TEXT_SILPHCO7F_SILPH_WORKER_M4
; PRET| 	dw_const SilphCo7FRocket1Text,            TEXT_SILPHCO7F_ROCKET1
; PRET| 	dw_const SilphCo7FScientistText,          TEXT_SILPHCO7F_SCIENTIST
; PRET| 	dw_const SilphCo7FRocket2Text,            TEXT_SILPHCO7F_ROCKET2
; PRET| 	dw_const SilphCo7FRocket3Text,            TEXT_SILPHCO7F_ROCKET3
; PRET| 	dw_const SilphCo7FRivalText,              TEXT_SILPHCO7F_RIVAL
; PRET| 	dw_const PickUpItemText,                  TEXT_SILPHCO7F_CALCIUM
; PRET| 	dw_const PickUpItemText,                  TEXT_SILPHCO7F_TM_SWORDS_DANCE
; PRET| 	dw_const PickUpItemText,                  TEXT_SILPHCO7F_UNREFERENCED_ITEM ; unreferenced
; PRET| 	dw_const SilphCo7FRivalWaitedHereText,    TEXT_SILPHCO7F_RIVAL_WAITED_HERE
; PRET| 	dw_const SilphCo7FRivalDefeatedText,      TEXT_SILPHCO7F_RIVAL_DEFEATED
; PRET| 	dw_const SilphCo7FRivalGoodLuckToYouText, TEXT_SILPHCO7F_RIVAL_GOOD_LUCK_TO_YOU
; PRET| 
; PRET| SilphCo7TrainerHeaders:
; PRET| 	def_trainers 5
; PRET| SilphCo7TrainerHeader0:
; PRET| 	trainer EVENT_BEAT_SILPH_CO_7F_TRAINER_0, 2, SilphCo7FRocket1BattleText, SilphCo7FRocket1EndBattleText, SilphCo7FRocket1AfterBattleText
; PRET| SilphCo7TrainerHeader1:
; PRET| 	trainer EVENT_BEAT_SILPH_CO_7F_TRAINER_1, 3, SilphCo7FScientistBattleText, SilphCo7FScientistEndBattleText, SilphCo7FScientistAfterBattleText
; PRET| SilphCo7TrainerHeader2:
; PRET| 	trainer EVENT_BEAT_SILPH_CO_7F_TRAINER_2, 3, SilphCo7FRocket2BattleText, SilphCo7FRocket2EndBattleText, SilphCo7FRocket2AfterBattleText
; PRET| SilphCo7TrainerHeader3:
; PRET| 	trainer EVENT_BEAT_SILPH_CO_7F_TRAINER_3, 4, SilphCo7FRocket3BattleText, SilphCo7FRocket3EndBattleText, SilphCo7FRocket3AfterBattleText
; PRET| 	db -1 ; end

; ---------------------------------------------------------------------------
; BAIL[bit-clobbers-live-carry] SilphCo7FSilphWorkerM1Text (scripts/SilphCo7F.asm:285-292) — at scripts/SilphCo7F.asm:286: bit BIT_GOT_LAPRAS, a
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wStatusFlags4]
; PRET| 	bit BIT_GOT_LAPRAS, a
; PRET| 	jr z, .give_lapras
; PRET| 	CheckEvent EVENT_BEAT_SILPH_CO_GIOVANNI
; PRET| 	jr nz, .saved_silph
; PRET| 	ld hl, .IsOurPresidentOkText
; PRET| 	call PrintText
; PRET| 	jr .done

.give_lapras:
    mov esi, .HaveThisPokemonText
    call PrintText
    mov bx, ((19) << 8) | (15)
    call GivePokemon
    jae .done
    mov al, [ebp + wAddedToParty]
    test al, al
    jnz .sk_301
        call WaitForTextScrollButtonPress
.sk_301:
    call EnableAutoTextBoxDrawing
    mov esi, .LaprasDescriptionText
    call PrintText
    mov esi, wStatusFlags4
    or byte [ebp + esi], (1 << (0))
    jmp .done

.saved_silph:
    mov esi, .SavedText
    call PrintText
.done:
    jmp TextScriptEnd

.HaveThisPokemonText:
    text_far _SilphCo7FSilphWorkerM1HaveThisPokemonText
    text_end
.LaprasDescriptionText:
    text_far _SilphCo7FSilphWorkerM1LaprasDescriptionText
    text_end
.IsOurPresidentOkText:
    text_far _SilphCo7FSilphWorkerM1IsOurPresidentOkText
    text_end
.SavedText:
    text_far _SilphCo7FSilphWorkerM1SavedText
    text_end

SilphCo7FSilphWorkerM2Text:
    CheckEvent EVENT_BEAT_SILPH_CO_GIOVANNI
    jnz .saved_silph
    mov esi, .AfterTheMasterBallText
    call PrintText
    jmp .done

.saved_silph:
    mov esi, .CancelledTheMasterBallText
    call PrintText
.done:
    jmp TextScriptEnd

.AfterTheMasterBallText:
    text_far _SilphCo7FSilphWorkerM2AfterTheMasterBallText
    text_end
.CancelledTheMasterBallText:
    text_far _SilphCo7FSilphWorkerM2CancelledMasterBallText
    text_end

SilphCo7FSilphWorkerM3Text:
    CheckEvent EVENT_BEAT_SILPH_CO_GIOVANNI
    jnz .saved_silph
    mov esi, .ItWouldBeBadText
    call PrintText
    jmp .done

.saved_silph:
    mov esi, .YouChasedOffTeamRocketText
    call PrintText
.done:
    jmp TextScriptEnd

.ItWouldBeBadText:
    text_far _SilphCo7FSilphWorkerM3ItWouldBeBadText
    text_end
.YouChasedOffTeamRocketText:
    text_far _SilphCo7FSilphWorkerM3YouChasedOffTeamRocketText
    text_end

SilphCo7FSilphWorkerM4Text:
    CheckEvent EVENT_BEAT_SILPH_CO_GIOVANNI
    jnz .saved_silph
    mov esi, .ItsReallyDangerousHereText
    call PrintText
    jmp .done

.saved_silph:
    mov esi, .SafeAtLastText
    call PrintText
.done:
    jmp TextScriptEnd

.ItsReallyDangerousHereText:
    text_far _SilphCo7FSilphWorkerM4ItsReallyDangerousHereText
    text_end
.SafeAtLastText:
    text_far _SilphCo7FSilphWorkerM4SafeAtLastText
    text_end

SilphCo7FRocket1Text:
    mov esi, SilphCo7TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] SilphCo7FRocket1BattleText (scripts/SilphCo7F.asm:400-409) — a generated asset already defines SilphCo7FRocket1BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _SilphCo7FRocket1BattleText
; PRET| 	text_end
; PRET| 
; PRET| SilphCo7FRocket1EndBattleText:
; PRET| 	text_far _SilphCo7FRocket1EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| SilphCo7FRocket1AfterBattleText:
; PRET| 	text_far _SilphCo7FRocket1AfterBattleText
; PRET| 	text_end

SilphCo7FScientistText:
    mov esi, SilphCo7TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] SilphCo7FScientistBattleText (scripts/SilphCo7F.asm:418-427) — a generated asset already defines SilphCo7FScientistBattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _SilphCo7FScientistBattleText
; PRET| 	text_end
; PRET| 
; PRET| SilphCo7FScientistEndBattleText:
; PRET| 	text_far _SilphCo7FScientistEndBattleText
; PRET| 	text_end
; PRET| 
; PRET| SilphCo7FScientistAfterBattleText:
; PRET| 	text_far _SilphCo7FScientistAfterBattleText
; PRET| 	text_end

SilphCo7FRocket2Text:
    mov esi, SilphCo7TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] SilphCo7FRocket2BattleText (scripts/SilphCo7F.asm:436-445) — a generated asset already defines SilphCo7FRocket2BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _SilphCo7FRocket2BattleText
; PRET| 	text_end
; PRET| 
; PRET| SilphCo7FRocket2EndBattleText:
; PRET| 	text_far _SilphCo7FRocket2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| SilphCo7FRocket2AfterBattleText:
; PRET| 	text_far _SilphCo7FRocket2AfterBattleText
; PRET| 	text_end

SilphCo7FRocket3Text:
    mov esi, SilphCo7TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] SilphCo7FRocket3BattleText (scripts/SilphCo7F.asm:454-463) — a generated asset already defines SilphCo7FRocket3BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _SilphCo7FRocket3BattleText
; PRET| 	text_end
; PRET| 
; PRET| SilphCo7FRocket3EndBattleText:
; PRET| 	text_far _SilphCo7FRocket3EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| SilphCo7FRocket3AfterBattleText:
; PRET| 	text_far _SilphCo7FRocket3AfterBattleText
; PRET| 	text_end

SilphCo7FRivalText:
    mov esi, .Text
    call PrintText
    jmp TextScriptEnd

.Text:
    text_far _SilphCo7FRivalText
    text_end
SilphCo7FRivalWaitedHereText:
    text_far _SilphCo7FRivalWaitedHereText
    text_end
SilphCo7FRivalDefeatedText:
    text_far _SilphCo7FRivalDefeatedText
    text_end
SilphCo7FRivalVictoryText:
    text_far _SilphCo7FRivalVictoryText
    text_end
SilphCo7FRivalGoodLuckToYouText:
    text_far _SilphCo7FRivalGoodLuckToYouText
    text_end
