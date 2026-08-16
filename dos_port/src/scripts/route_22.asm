; Route22.asm — translated from pret scripts/Route22.asm, scripts/Route22_2.asm by dos_port/tools/sm83xlat.
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

global Route22NoopScript
global Route22PokemonLeagueSignText
global Route22PrintPokemonLeagueSignText
global Route22PrintRival1Text
global Route22PrintRival2Text
global Route22Rival1DefeatedText
global Route22Rival1ExitMovementData1
global Route22Rival1ExitMovementData2
global Route22Rival1Text
global Route22Rival1VictoryText
global Route22Rival2DefeatedText
global Route22Rival2ExitMovementData1
global Route22Rival2ExitMovementData2
global Route22Rival2Text
global Route22Rival2VictoryText
global Route22RivalAfterBattleText1
global Route22RivalAfterBattleText2
global Route22RivalBeforeBattleText1
global Route22RivalBeforeBattleText2
global Route22RivalMovementData
global Route22Script_50ed6
global Route22Script_50ee1
global Route22SetDefaultScript
global Route22_Script
global Route22_ScriptPointers
global Route22_TextPointers

extern ArePlayerCoordsInArray   ; NOT YET DEFINED IN THE PORT
extern Bankswitch   ; NOT YET DEFINED IN THE PORT
extern CallFunctionInTable   ; NOT YET DEFINED IN THE PORT
extern DisplayTextID   ; NOT YET DEFINED IN THE PORT
extern EmotionBubble   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern HideObject   ; NOT YET DEFINED IN THE PORT
extern MoveSprite   ; NOT YET DEFINED IN THE PORT
extern Music_RivalAlternateStart   ; NOT YET DEFINED IN THE PORT
extern Music_RivalAlternateStartAndTempo   ; NOT YET DEFINED IN THE PORT
extern Music_RivalAlternateTempo   ; NOT YET DEFINED IN THE PORT
extern PlayDefaultMusic   ; NOT YET DEFINED IN THE PORT
extern PlayMusic   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern Route22DefaultScript   ; NOT YET DEFINED IN THE PORT
extern Route22FirstRivalBattleScript   ; NOT YET DEFINED IN THE PORT
extern Route22MoveRival1   ; NOT YET DEFINED IN THE PORT
extern Route22MoveRival2   ; NOT YET DEFINED IN THE PORT
extern Route22MoveRivalRightScript   ; NOT YET DEFINED IN THE PORT
extern Route22Rival1AfterBattleScript   ; NOT YET DEFINED IN THE PORT
extern Route22Rival1ExitScript   ; NOT YET DEFINED IN THE PORT
extern Route22Rival1StartBattleScript   ; NOT YET DEFINED IN THE PORT
extern Route22Rival2AfterBattleScript   ; NOT YET DEFINED IN THE PORT
extern Route22Rival2ExitScript   ; NOT YET DEFINED IN THE PORT
extern Route22Rival2StartBattleScript   ; NOT YET DEFINED IN THE PORT
extern Route22SecondRivalBattleScript   ; NOT YET DEFINED IN THE PORT
extern SaveEndBattleTextPointers   ; NOT YET DEFINED IN THE PORT
extern SetSpriteFacingDirectionAndDelay   ; NOT YET DEFINED IN THE PORT
extern StopAllMusic   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern _Route22PokemonLeagueSignText   ; NOT YET DEFINED IN THE PORT
extern _Route22Rival1DefeatedText   ; NOT YET DEFINED IN THE PORT
extern _Route22Rival1VictoryText   ; NOT YET DEFINED IN THE PORT
extern _Route22Rival2DefeatedText   ; NOT YET DEFINED IN THE PORT
extern _Route22Rival2VictoryText   ; NOT YET DEFINED IN THE PORT
extern _Route22RivalAfterBattleText1   ; NOT YET DEFINED IN THE PORT
extern _Route22RivalAfterBattleText2   ; NOT YET DEFINED IN THE PORT
extern _Route22RivalBeforeBattleText1   ; NOT YET DEFINED IN THE PORT
extern _Route22RivalBeforeBattleText2   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_ROUTE22_DEFAULT                         equ 0
SCRIPT_ROUTE22_RIVAL1_START_BATTLE             equ 1
SCRIPT_ROUTE22_RIVAL1_AFTER_BATTLE             equ 2
SCRIPT_ROUTE22_RIVAL1_EXIT                     equ 3
SCRIPT_ROUTE22_RIVAL2_START_BATTLE             equ 4
SCRIPT_ROUTE22_RIVAL2_AFTER_BATTLE             equ 5
SCRIPT_ROUTE22_RIVAL2_EXIT                     equ 6
SCRIPT_ROUTE22_NOOP                            equ 7
TEXT_ROUTE22_RIVAL1                            equ 1
TEXT_ROUTE22_RIVAL2                            equ 2

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
hSpriteFacingDirection                         equ 0xFF8D
wCoordIndex                                    equ 0xCD3D
wRoute22CurScript                              equ 0xD609
wSavedCoordIndex                               equ 0xCF0D
wSpritePlayerStateData1FacingDirection         equ 0xC109

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

Route22_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route22_ScriptPointers
    mov al, [ebp + wRoute22CurScript]
    jmp CallFunctionInTable

Route22_ScriptPointers:
    dd Route22DefaultScript
    dd Route22Rival1StartBattleScript
    dd Route22Rival1AfterBattleScript
    dd Route22Rival1ExitScript
    dd Route22Rival2StartBattleScript
    dd Route22Rival2AfterBattleScript
    dd Route22Rival2ExitScript
    dd Route22NoopScript

Route22SetDefaultScript:
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov [ebp + wRoute22CurScript], al
Route22NoopScript:
    ret

Route22Script_50ed6:
    mov al, OPP_RIVAL1
    mov [ebp + wCurOpponent], al
    mov al, 0x2
    mov [ebp + wTrainerNo], al
    ret

Route22Script_50ee1:
    mov al, OPP_RIVAL2
    mov [ebp + wCurOpponent], al
    mov al, [ebp + W_RIVAL_STARTER]
    add al, 7
    mov [ebp + wTrainerNo], al
    ret

; ---------------------------------------------------------------------------
; BAIL[host-pointer-in-16bit-reg] Route22MoveRivalRightScript (scripts/Route22.asm:41-50) — at scripts/Route22.asm:41: de cannot hold the 32-bit address of Route22RivalMovementData; callee <none in range> has no abi.json entry
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld de, Route22RivalMovementData
; PRET| 	ld a, [wSavedCoordIndex]
; PRET| 	cp $1
; PRET| 	jr z, .skip_first_right
; PRET| 	inc de
; PRET| .skip_first_right
; PRET| 	call MoveSprite
; PRET| 	ld a, SPRITE_FACING_RIGHT
; PRET| 	ldh [hSpriteFacingDirection], a
; PRET| 	jp SetSpriteFacingDirectionAndDelay

Route22RivalMovementData:
    db NPC_MOVEMENT_RIGHT
    db NPC_MOVEMENT_RIGHT
    db NPC_MOVEMENT_RIGHT
    db NPC_MOVEMENT_RIGHT
    db -1

; ---------------------------------------------------------------------------
; BAIL[event-byte-assembly-state] Route22DefaultScript (scripts/Route22.asm:60-77) — at scripts/Route22.asm:75: CheckEventReuseA EVENT_2ND_ROUTE22_RIVAL_BATTLE
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_ROUTE22_RIVAL_WANTS_BATTLE
; PRET| 	ret z
; PRET| 	ld hl, .Route22RivalBattleCoords
; PRET| 	call ArePlayerCoordsInArray
; PRET| 	ret nc
; PRET| 	ld a, [wCoordIndex]
; PRET| 	ld [wSavedCoordIndex], a
; PRET| 	xor a
; PRET| 	ldh [hJoyHeld], a
; PRET| 	ld a, PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 	ld a, PLAYER_DIR_LEFT
; PRET| 	ld [wPlayerMovingDirection], a
; PRET| 	CheckEvent EVENT_1ST_ROUTE22_RIVAL_BATTLE
; PRET| 	jr nz, Route22FirstRivalBattleScript
; PRET| 	CheckEventReuseA EVENT_2ND_ROUTE22_RIVAL_BATTLE
; PRET| 	jp nz, Route22SecondRivalBattleScript
; PRET| 	ret

.Route22RivalBattleCoords:
    db 4, 29
    db 5, 29
    db -1

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] Route22FirstRivalBattleScript (scripts/Route22.asm:85-103) — at scripts/Route22.asm:92: .walking is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, ROUTE22_RIVAL1
; PRET| 	ld [wEmotionBubbleSpriteIndex], a
; PRET| 	xor a ; EXCLAMATION_BUBBLE
; PRET| 	ld [wWhichEmotionBubble], a
; PRET| 	predef EmotionBubble
; PRET| 	ld a, [wWalkBikeSurfState]
; PRET| 	and a
; PRET| 	jr z, .walking
; PRET| 	call StopAllMusic
; PRET| .walking
; PRET| 	ld c, BANK(Music_MeetRival)
; PRET| 	ld a, MUSIC_MEET_RIVAL
; PRET| 	call PlayMusic
; PRET| 	ld a, ROUTE22_RIVAL1
; PRET| 	ldh [hSpriteIndex], a
; PRET| 	call Route22MoveRivalRightScript
; PRET| 	ld a, SCRIPT_ROUTE22_RIVAL1_START_BATTLE
; PRET| 	ld [wRoute22CurScript], a
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] Route22Rival1StartBattleScript (scripts/Route22.asm:106-115) — at scripts/Route22.asm:115: .set_rival_facing_direction is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wStatusFlags5]
; PRET| 	bit BIT_SCRIPTED_NPC_MOVEMENT, a
; PRET| 	ret nz
; PRET| 	ld a, [wSavedCoordIndex]
; PRET| 	cp 1 ; index of second, lower entry in Route22DefaultScript.Route22RivalBattleCoords
; PRET| 	jr nz, .set_rival_facing_right
; PRET| 	ld a, PLAYER_DIR_DOWN
; PRET| 	ld [wPlayerMovingDirection], a
; PRET| 	ld a, SPRITE_FACING_UP
; PRET| 	jr .set_rival_facing_direction

.set_rival_facing_right:
    mov al, SPRITE_FACING_RIGHT
.set_rival_facing_direction:
    mov [ebp + hSpriteFacingDirection], al
    mov al, 1
    mov [ebp + hSpriteIndex], al
    call SetSpriteFacingDirectionAndDelay
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov al, TEXT_ROUTE22_RIVAL1
    mov [ebp + hTextID], al
    call DisplayTextID
    mov esi, wStatusFlags3
    or byte [ebp + esi], (1 << (BIT_TALKED_TO_TRAINER))
    or byte [ebp + esi], (1 << (BIT_PRINT_END_BATTLE_TEXT))
    mov esi, Route22Rival1DefeatedText
    mov edx, Route22Rival1VictoryText   ; pret: ld de, Route22Rival1VictoryText — SaveEndBattleTextPointers takes it in EDX
    call SaveEndBattleTextPointers
    call Route22Script_50ed6
    mov al, SCRIPT_ROUTE22_RIVAL1_AFTER_BATTLE
    mov [ebp + wRoute22CurScript], al
    ret

Route22Rival1DefeatedText:
    text_far _Route22Rival1DefeatedText
    text_end
Route22Rival1VictoryText:
    text_far _Route22Rival1VictoryText
    text_end

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] Route22Rival1AfterBattleScript (scripts/Route22.asm:148-161) — at scripts/Route22.asm:153: .keep_rival_starter is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wIsInBattle]
; PRET| 	cp $ff
; PRET| 	jp z, Route22SetDefaultScript
; PRET| 	ld a, [wRivalStarter]
; PRET| 	cp RIVAL_STARTER_FLAREON
; PRET| 	jr nz, .keep_rival_starter
; PRET| 	ld a, RIVAL_STARTER_JOLTEON
; PRET| 	ld [wRivalStarter], a
; PRET| .keep_rival_starter
; PRET| 	ld a, [wSpritePlayerStateData1FacingDirection]
; PRET| 	and a ; cp SPRITE_FACING_DOWN
; PRET| 	jr nz, .not_facing_down
; PRET| 	ld a, SPRITE_FACING_UP
; PRET| 	jr .set_rival_facing

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] Route22Rival1AfterBattleScript.not_facing_down (scripts/Route22.asm:163-181) — at scripts/Route22.asm:179: .exit_movement_2 is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, SPRITE_FACING_RIGHT
; PRET| .set_rival_facing
; PRET| 	ldh [hSpriteFacingDirection], a
; PRET| 	ld a, ROUTE22_RIVAL1
; PRET| 	ldh [hSpriteIndex], a
; PRET| 	call SetSpriteFacingDirectionAndDelay
; PRET| 	ld a, PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 	SetEvent EVENT_BEAT_ROUTE22_RIVAL_1ST_BATTLE
; PRET| 	ld a, TEXT_ROUTE22_RIVAL1
; PRET| 	ldh [hTextID], a
; PRET| 	call DisplayTextID
; PRET| 	call StopAllMusic
; PRET| 	farcall Music_RivalAlternateStart
; PRET| 	ld a, [wSavedCoordIndex]
; PRET| 	cp 1 ; index of second, lower entry in Route22DefaultScript.Route22RivalBattleCoords
; PRET| 	jr nz, .exit_movement_2
; PRET| 	call .RivalExit1Script
; PRET| 	jr .next_script

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] Route22Rival1AfterBattleScript.exit_movement_2 (scripts/Route22.asm:183-187) — at scripts/Route22.asm:183: .RivalExit2Script is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	call .RivalExit2Script
; PRET| .next_script
; PRET| 	ld a, SCRIPT_ROUTE22_RIVAL1_EXIT
; PRET| 	ld [wRoute22CurScript], a
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[host-pointer-in-16bit-reg] Route22Rival1AfterBattleScript.RivalExit1Script (scripts/Route22.asm:190-191) — at scripts/Route22.asm:190: de cannot hold the 32-bit address of Route22Rival1ExitMovementData1; callee <none in range> has no abi.json entry
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld de, Route22Rival1ExitMovementData1
; PRET| 	jr Route22MoveRival1

; ---------------------------------------------------------------------------
; BAIL[host-pointer-in-16bit-reg] Route22Rival1AfterBattleScript.RivalExit2Script (scripts/Route22.asm:194-198) — at scripts/Route22.asm:194: de cannot hold the 32-bit address of Route22Rival1ExitMovementData2; callee <none in range> has no abi.json entry
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld de, Route22Rival1ExitMovementData2
; PRET| Route22MoveRival1:
; PRET| 	ld a, ROUTE22_RIVAL1
; PRET| 	ldh [hSpriteIndex], a
; PRET| 	jp MoveSprite

Route22Rival1ExitMovementData1:
    db NPC_MOVEMENT_RIGHT
    db NPC_MOVEMENT_RIGHT
    db NPC_MOVEMENT_DOWN
    db NPC_MOVEMENT_DOWN
    db NPC_MOVEMENT_DOWN
    db NPC_MOVEMENT_DOWN
    db NPC_MOVEMENT_DOWN
    db -1
Route22Rival1ExitMovementData2:
    db NPC_MOVEMENT_UP
    db NPC_MOVEMENT_RIGHT
    db NPC_MOVEMENT_RIGHT
    db NPC_MOVEMENT_RIGHT
    db NPC_MOVEMENT_DOWN
    db NPC_MOVEMENT_DOWN
    db NPC_MOVEMENT_DOWN
    db NPC_MOVEMENT_DOWN
    db NPC_MOVEMENT_DOWN
    db NPC_MOVEMENT_DOWN
    db -1

; ---------------------------------------------------------------------------
; BAIL[predef-leaves-id-in-a] Route22Rival1ExitScript (scripts/Route22.asm:224-236) — at scripts/Route22.asm:231: predef HideObject
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wStatusFlags5]
; PRET| 	bit BIT_SCRIPTED_NPC_MOVEMENT, a
; PRET| 	ret nz
; PRET| 	xor a
; PRET| 	ld [wJoyIgnore], a
; PRET| 	ld a, TOGGLE_ROUTE_22_RIVAL_1
; PRET| 	ld [wToggleableObjectIndex], a
; PRET| 	predef HideObject
; PRET| 	call PlayDefaultMusic
; PRET| 	ResetEvents EVENT_1ST_ROUTE22_RIVAL_BATTLE, EVENT_ROUTE22_RIVAL_WANTS_BATTLE
; PRET| 	ld a, SCRIPT_ROUTE22_DEFAULT
; PRET| 	ld [wRoute22CurScript], a
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] Route22SecondRivalBattleScript (scripts/Route22.asm:239-256) — at scripts/Route22.asm:246: .walking is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, ROUTE22_RIVAL2
; PRET| 	ld [wEmotionBubbleSpriteIndex], a
; PRET| 	xor a ; EXCLAMATION_BUBBLE
; PRET| 	ld [wWhichEmotionBubble], a
; PRET| 	predef EmotionBubble
; PRET| 	ld a, [wWalkBikeSurfState]
; PRET| 	and a
; PRET| 	jr z, .walking
; PRET| 	call StopAllMusic
; PRET| .walking
; PRET| 	call StopAllMusic
; PRET| 	farcall Music_RivalAlternateTempo
; PRET| 	ld a, ROUTE22_RIVAL2
; PRET| 	ldh [hSpriteIndex], a
; PRET| 	call Route22MoveRivalRightScript
; PRET| 	ld a, SCRIPT_ROUTE22_RIVAL2_START_BATTLE
; PRET| 	ld [wRoute22CurScript], a
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] Route22Rival2StartBattleScript (scripts/Route22.asm:259-270) — at scripts/Route22.asm:266: .set_player_direction_left is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wStatusFlags5]
; PRET| 	bit BIT_SCRIPTED_NPC_MOVEMENT, a
; PRET| 	ret nz
; PRET| 	ld a, ROUTE22_RIVAL2
; PRET| 	ldh [hSpriteIndex], a
; PRET| 	ld a, [wSavedCoordIndex]
; PRET| 	cp 1 ; index of second, lower entry in Route22DefaultScript.Route22RivalBattleCoords
; PRET| 	jr nz, .set_player_direction_left
; PRET| 	ld a, PLAYER_DIR_DOWN
; PRET| 	ld [wPlayerMovingDirection], a
; PRET| 	ld a, SPRITE_FACING_UP
; PRET| 	jr .set_rival_facing_direction

.set_player_direction_left:
    mov al, PLAYER_DIR_LEFT
    mov [ebp + wPlayerMovingDirection], al
    mov al, SPRITE_FACING_RIGHT
.set_rival_facing_direction:
    mov [ebp + hSpriteFacingDirection], al
    call SetSpriteFacingDirectionAndDelay
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov al, TEXT_ROUTE22_RIVAL2
    mov [ebp + hTextID], al
    call DisplayTextID
    mov esi, wStatusFlags3
    or byte [ebp + esi], (1 << (BIT_TALKED_TO_TRAINER))
    or byte [ebp + esi], (1 << (BIT_PRINT_END_BATTLE_TEXT))
    mov esi, Route22Rival2DefeatedText
    mov edx, Route22Rival2VictoryText   ; pret: ld de, Route22Rival2VictoryText — SaveEndBattleTextPointers takes it in EDX
    call SaveEndBattleTextPointers
    call Route22Script_50ee1
    mov al, SCRIPT_ROUTE22_RIVAL2_AFTER_BATTLE
    mov [ebp + wRoute22CurScript], al
    ret

Route22Rival2DefeatedText:
    text_far _Route22Rival2DefeatedText
    text_end
Route22Rival2VictoryText:
    text_far _Route22Rival2VictoryText
    text_end

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] Route22Rival2AfterBattleScript (scripts/Route22.asm:303-314) — at scripts/Route22.asm:310: .set_player_direction_left is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wIsInBattle]
; PRET| 	cp $ff
; PRET| 	jp z, Route22SetDefaultScript
; PRET| 	ld a, ROUTE22_RIVAL2
; PRET| 	ldh [hSpriteIndex], a
; PRET| 	ld a, [wSavedCoordIndex]
; PRET| 	cp 1 ; index of second, lower entry in Route22DefaultScript.Route22RivalBattleCoords
; PRET| 	jr nz, .set_player_direction_left
; PRET| 	ld a, PLAYER_DIR_DOWN
; PRET| 	ld [wPlayerMovingDirection], a
; PRET| 	ld a, SPRITE_FACING_UP
; PRET| 	jr .set_rival_facing_direction

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] Route22Rival2AfterBattleScript.set_player_direction_left (scripts/Route22.asm:316-334) — at scripts/Route22.asm:332: .exit_movement_2 is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, PLAYER_DIR_LEFT
; PRET| 	ld [wPlayerMovingDirection], a
; PRET| 	ld a, SPRITE_FACING_RIGHT
; PRET| .set_rival_facing_direction
; PRET| 	ldh [hSpriteFacingDirection], a
; PRET| 	call SetSpriteFacingDirectionAndDelay
; PRET| 	ld a, PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 	SetEvent EVENT_BEAT_ROUTE22_RIVAL_2ND_BATTLE
; PRET| 	ld a, TEXT_ROUTE22_RIVAL2
; PRET| 	ldh [hTextID], a
; PRET| 	call DisplayTextID
; PRET| 	call StopAllMusic
; PRET| 	farcall Music_RivalAlternateStartAndTempo
; PRET| 	ld a, [wSavedCoordIndex]
; PRET| 	cp 1 ; index of second, lower entry in Route22DefaultScript.Route22RivalBattleCoords
; PRET| 	jr nz, .exit_movement_2
; PRET| 	call .RivalExit1Script
; PRET| 	jr .next_script

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] Route22Rival2AfterBattleScript.exit_movement_2 (scripts/Route22.asm:336-340) — at scripts/Route22.asm:336: .RivalExit2Script is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	call .RivalExit2Script
; PRET| .next_script
; PRET| 	ld a, SCRIPT_ROUTE22_RIVAL2_EXIT
; PRET| 	ld [wRoute22CurScript], a
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[host-pointer-in-16bit-reg] Route22Rival2AfterBattleScript.RivalExit1Script (scripts/Route22.asm:343-344) — at scripts/Route22.asm:343: de cannot hold the 32-bit address of Route22Rival2ExitMovementData1; callee <none in range> has no abi.json entry
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld de, Route22Rival2ExitMovementData1
; PRET| 	jr Route22MoveRival2

; ---------------------------------------------------------------------------
; BAIL[host-pointer-in-16bit-reg] Route22Rival2AfterBattleScript.RivalExit2Script (scripts/Route22.asm:347-351) — at scripts/Route22.asm:347: de cannot hold the 32-bit address of Route22Rival2ExitMovementData2; callee <none in range> has no abi.json entry
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld de, Route22Rival2ExitMovementData2
; PRET| Route22MoveRival2:
; PRET| 	ld a, ROUTE22_RIVAL2
; PRET| 	ldh [hSpriteIndex], a
; PRET| 	jp MoveSprite

Route22Rival2ExitMovementData1:
    db NPC_MOVEMENT_LEFT
Route22Rival2ExitMovementData2:
    db NPC_MOVEMENT_LEFT
    db NPC_MOVEMENT_LEFT
    db NPC_MOVEMENT_LEFT
    db -1

; ---------------------------------------------------------------------------
; BAIL[predef-leaves-id-in-a] Route22Rival2ExitScript (scripts/Route22.asm:362-374) — at scripts/Route22.asm:369: predef HideObject
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wStatusFlags5]
; PRET| 	bit BIT_SCRIPTED_NPC_MOVEMENT, a
; PRET| 	ret nz
; PRET| 	xor a
; PRET| 	ld [wJoyIgnore], a
; PRET| 	ld a, TOGGLE_ROUTE_22_RIVAL_2
; PRET| 	ld [wToggleableObjectIndex], a
; PRET| 	predef HideObject
; PRET| 	call PlayDefaultMusic
; PRET| 	ResetEvents EVENT_2ND_ROUTE22_RIVAL_BATTLE, EVENT_ROUTE22_RIVAL_WANTS_BATTLE
; PRET| 	ld a, SCRIPT_ROUTE22_NOOP
; PRET| 	ld [wRoute22CurScript], a
; PRET| 	ret

Route22_TextPointers:
    dd Route22Rival1Text
    dd Route22Rival2Text
    dd Route22PokemonLeagueSignText

Route22Rival1Text:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call Route22PrintRival1Text
    jmp TextScriptEnd

Route22Rival2Text:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call Route22PrintRival2Text
    jmp TextScriptEnd

Route22PokemonLeagueSignText:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call Route22PrintPokemonLeagueSignText
    jmp TextScriptEnd

Route22PrintRival1Text:
    CheckEvent EVENT_BEAT_ROUTE22_RIVAL_1ST_BATTLE
    jz .before_battle
    mov esi, Route22RivalAfterBattleText1
    call PrintText
    jmp .text_script_end

.before_battle:
    mov esi, Route22RivalBeforeBattleText1
    call PrintText
.text_script_end:
    ret

Route22RivalBeforeBattleText1:
    text_far _Route22RivalBeforeBattleText1
    text_end
Route22RivalAfterBattleText1:
    text_far _Route22RivalAfterBattleText1
    text_end

Route22PrintRival2Text:
    CheckEvent EVENT_BEAT_ROUTE22_RIVAL_2ND_BATTLE
    jz .before_battle
    mov esi, Route22RivalAfterBattleText2
    call PrintText
    jmp .text_script_end

.before_battle:
    mov esi, Route22RivalBeforeBattleText2
    call PrintText
.text_script_end:
    ret

Route22RivalBeforeBattleText2:
    text_far _Route22RivalBeforeBattleText2
    text_end
Route22RivalAfterBattleText2:
    text_far _Route22RivalAfterBattleText2
    text_end

Route22PrintPokemonLeagueSignText:
    mov esi, .text
    call PrintText
    ret

.text:
    text_far _Route22PokemonLeagueSignText
    text_end
