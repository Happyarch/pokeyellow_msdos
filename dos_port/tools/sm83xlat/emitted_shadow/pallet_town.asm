; PalletTown.asm — translated from pret scripts/PalletTown.asm by dos_port/tools/sm83xlat.
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

global PalletTownFisherText
global PalletTownGirlText
global PalletTownOakComeWithMe
global PalletTownOaksLabSignText
global PalletTownPlayersHouseSignText
global PalletTownRivalsHouseSignText
global PalletTown_TextPointers

extern CalcPositionOfPlayerRelativeToNPC   ; NOT YET DEFINED IN THE PORT
extern CallFunctionInTable   ; NOT YET DEFINED IN THE PORT
extern Delay3   ; NOT YET DEFINED IN THE PORT
extern DelayFrames   ; NOT YET DEFINED IN THE PORT
extern DisplayTextID   ; NOT YET DEFINED IN THE PORT
extern EmotionBubble   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern FindPathToPlayer   ; NOT YET DEFINED IN THE PORT
extern HideObject   ; NOT YET DEFINED IN THE PORT
extern MoveSprite   ; NOT YET DEFINED IN THE PORT
extern PalletTownAfterPikachuBattleScript   ; NOT YET DEFINED IN THE PORT
extern PalletTownDaisyScript   ; NOT YET DEFINED IN THE PORT
extern PalletTownDefaultScript   ; NOT YET DEFINED IN THE PORT
extern PalletTownNoopScript   ; NOT YET DEFINED IN THE PORT
extern PalletTownOakGreetsPlayerScript   ; NOT YET DEFINED IN THE PORT
extern PalletTownOakHeyWaitScript   ; NOT YET DEFINED IN THE PORT
extern PalletTownOakNotSafeComeWithMeScript   ; NOT YET DEFINED IN THE PORT
extern PalletTownOakText   ; NOT YET DEFINED IN THE PORT
extern PalletTownOakWalksToPlayerScript   ; NOT YET DEFINED IN THE PORT
extern PalletTownPikachuBattleScript   ; NOT YET DEFINED IN THE PORT
extern PalletTownPlayerFollowsOakScript   ; NOT YET DEFINED IN THE PORT
extern PalletTownSignText   ; NOT YET DEFINED IN THE PORT
extern PalletTown_Script   ; NOT YET DEFINED IN THE PORT
extern PalletTown_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern PlayMusic   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern ShowObject   ; NOT YET DEFINED IN THE PORT
extern StopAllMusic   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern _PalletTownFisherText   ; NOT YET DEFINED IN THE PORT
extern _PalletTownGirlText   ; NOT YET DEFINED IN THE PORT
extern _PalletTownOakComeWithMe   ; NOT YET DEFINED IN THE PORT
extern _PalletTownOakHeyWaitDontGoOutText   ; NOT YET DEFINED IN THE PORT
extern _PalletTownOakThatWasCloseText   ; NOT YET DEFINED IN THE PORT
extern _PalletTownOakWhewText   ; NOT YET DEFINED IN THE PORT
extern _PalletTownOaksLabSignText   ; NOT YET DEFINED IN THE PORT
extern _PalletTownPlayersHouseSignText   ; NOT YET DEFINED IN THE PORT
extern _PalletTownRivalsHouseSignText   ; NOT YET DEFINED IN THE PORT
extern _PalletTownSignText   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_PALLETTOWN_DEFAULT                      equ 0
SCRIPT_PALLETTOWN_OAK_HEY_WAIT                 equ 1
SCRIPT_PALLETTOWN_OAK_WALKS_TO_PLAYER          equ 2
SCRIPT_PALLETTOWN_OAK_GREETS_PLAYER            equ 3
SCRIPT_PALLETTOWN_PIKACHU_BATTLE               equ 4
SCRIPT_PALLETTOWN_AFTER_PIKACHU_BATTLE         equ 5
SCRIPT_PALLETTOWN_OAK_NOT_SAFE_COME_WITH_ME    equ 6
SCRIPT_PALLETTOWN_PLAYER_FOLLOWS_OAK           equ 7
SCRIPT_PALLETTOWN_DAISY                        equ 8
SCRIPT_PALLETTOWN_NOOP                         equ 9
TEXT_PALLETTOWN_OAK                            equ 1
TEXT_PALLETTOWN_OAK_COME_WITH_ME               equ 8

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wOakWalkedToPlayer                             equ 0xCF0D
wSprite01StateData1FacingDirection             equ 0xC119
wSprite01StateData1MovementStatus              equ 0xC111
wSprite01StateData2MapY                        equ 0xC214
wSpritePlayerStateData1FacingDirection         equ 0xC109

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] PalletTown_Script (scripts/PalletTown.asm:2-9) — a generated asset already defines PalletTown_Script
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_GOT_POKEBALLS_FROM_OAK
; PRET| 	jr z, .next
; PRET| 	SetEvent EVENT_PALLET_AFTER_GETTING_POKEBALLS
; PRET| .next
; PRET| 	call EnableAutoTextBoxDrawing
; PRET| 	ld hl, PalletTown_ScriptPointers
; PRET| 	ld a, [wPalletTownCurScript]
; PRET| 	jp CallFunctionInTable

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] PalletTown_ScriptPointers (scripts/PalletTown.asm:12-22) — a generated asset already defines PalletTown_ScriptPointers
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	def_script_pointers
; PRET| 	dw_const PalletTownDefaultScript,              SCRIPT_PALLETTOWN_DEFAULT
; PRET| 	dw_const PalletTownOakHeyWaitScript,           SCRIPT_PALLETTOWN_OAK_HEY_WAIT
; PRET| 	dw_const PalletTownOakWalksToPlayerScript,     SCRIPT_PALLETTOWN_OAK_WALKS_TO_PLAYER
; PRET| 	dw_const PalletTownOakGreetsPlayerScript,      SCRIPT_PALLETTOWN_OAK_GREETS_PLAYER
; PRET| 	dw_const PalletTownPikachuBattleScript,        SCRIPT_PALLETTOWN_PIKACHU_BATTLE
; PRET| 	dw_const PalletTownAfterPikachuBattleScript,   SCRIPT_PALLETTOWN_AFTER_PIKACHU_BATTLE
; PRET| 	dw_const PalletTownOakNotSafeComeWithMeScript, SCRIPT_PALLETTOWN_OAK_NOT_SAFE_COME_WITH_ME
; PRET| 	dw_const PalletTownPlayerFollowsOakScript,     SCRIPT_PALLETTOWN_PLAYER_FOLLOWS_OAK
; PRET| 	dw_const PalletTownDaisyScript,                SCRIPT_PALLETTOWN_DAISY
; PRET| 	dw_const PalletTownNoopScript,                 SCRIPT_PALLETTOWN_NOOP

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] PalletTownDefaultScript (scripts/PalletTown.asm:25-52) — a generated asset already defines PalletTownDefaultScript
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_FOLLOWED_OAK_INTO_LAB
; PRET| 	ret nz
; PRET| 	ld a, [wYCoord]
; PRET| 	cp 0 ; is player at north exit?
; PRET| 	ret nz
; PRET| 	ResetEvent EVENT_PLAYER_AT_RIGHT_EXIT_TO_PALLET_TOWN
; PRET| 	ld a, [wXCoord]
; PRET| 	cp 10
; PRET| 	jr z, .asm_18e40
; PRET| 	SetEventReuseHL EVENT_PLAYER_AT_RIGHT_EXIT_TO_PALLET_TOWN
; PRET| .asm_18e40
; PRET| 	xor a
; PRET| 	ldh [hJoyHeld], a
; PRET| 	ld a, PAD_BUTTONS | PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 	ld a, PLAYER_DIR_UP
; PRET| 	ld [wPlayerMovingDirection], a
; PRET| 	call StopAllMusic
; PRET| 	ld a, BANK(Music_MeetProfOak)
; PRET| 	ld c, a
; PRET| 	ld a, MUSIC_MEET_PROF_OAK ; "oak appears" music
; PRET| 	call PlayMusic
; PRET| 	SetEvent EVENT_OAK_APPEARED_IN_PALLET
; PRET| 
; PRET| 	; trigger the next script
; PRET| 	ld a, SCRIPT_PALLETTOWN_OAK_HEY_WAIT
; PRET| 	ld [wPalletTownCurScript], a
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] PalletTownOakHeyWaitScript (scripts/PalletTown.asm:55-80) — a generated asset already defines PalletTownOakHeyWaitScript
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, PAD_SELECT | PAD_START | PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 	xor a
; PRET| 	ld [wOakWalkedToPlayer], a
; PRET| 	ld a, TEXT_PALLETTOWN_OAK
; PRET| 	ldh [hTextID], a
; PRET| 	call DisplayTextID
; PRET| 	ld a, PAD_BUTTONS | PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 	ld hl, wSprite01StateData2MapY
; PRET| 	ld a, 8
; PRET| 	ld [hli], a ; SPRITESTATEDATA2_MAPY
; PRET| 	ld a, 14
; PRET| 	ld [hl], a ; SPRITESTATEDATA2_MAPX
; PRET| 	ld a, TOGGLE_PALLET_TOWN_OAK
; PRET| 	ld [wToggleableObjectIndex], a
; PRET| 	predef ShowObject
; PRET| 	ld a, $2
; PRET| 	ld [wSprite01StateData1MovementStatus], a
; PRET| 	ld a, SPRITE_FACING_UP
; PRET| 	ld [wSprite01StateData1FacingDirection], a
; PRET| 
; PRET| 	; trigger the next script
; PRET| 	ld a, SCRIPT_PALLETTOWN_OAK_WALKS_TO_PLAYER
; PRET| 	ld [wPalletTownCurScript], a
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] PalletTownOakWalksToPlayerScript (scripts/PalletTown.asm:83-103) — a generated asset already defines PalletTownOakWalksToPlayerScript
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	call Delay3
; PRET| 	ld a, 0
; PRET| 	ld [wYCoord], a
; PRET| 	ld a, 1
; PRET| 	ldh [hNPCPlayerRelativePosPerspective], a
; PRET| 	ld a, 1
; PRET| 	swap a
; PRET| 	ldh [hNPCSpriteOffset], a
; PRET| 	predef CalcPositionOfPlayerRelativeToNPC
; PRET| 	ld hl, hNPCPlayerYDistance
; PRET| 	dec [hl]
; PRET| 	predef FindPathToPlayer ; load Oak's movement into wNPCMovementDirections2
; PRET| 	ld de, wNPCMovementDirections2
; PRET| 	ld a, PALLETTOWN_OAK
; PRET| 	ldh [hSpriteIndex], a
; PRET| 	call MoveSprite
; PRET| 
; PRET| 	; trigger the next script
; PRET| 	ld a, SCRIPT_PALLETTOWN_OAK_GREETS_PLAYER
; PRET| 	ld [wPalletTownCurScript], a
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] PalletTownOakGreetsPlayerScript (scripts/PalletTown.asm:106-135) — a generated asset already defines PalletTownOakGreetsPlayerScript
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wStatusFlags5]
; PRET| 	bit BIT_SCRIPTED_NPC_MOVEMENT, a
; PRET| 	ret nz
; PRET| 	ld a, PAD_SELECT | PAD_START | PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 	ld a, 1
; PRET| 	ld [wOakWalkedToPlayer], a
; PRET| 	ld a, $2
; PRET| 	ld [wSprite01StateData1MovementStatus], a
; PRET| 	ld a, SPRITE_FACING_UP
; PRET| 	ld [wSprite01StateData1FacingDirection], a
; PRET| 	ld a, TEXT_PALLETTOWN_OAK
; PRET| 	ldh [hTextID], a
; PRET| 	call DisplayTextID
; PRET| 	; oak faces the horizontally adjacent patch of grass to face pikachu
; PRET| 	ld a, PAD_BUTTONS | PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 	ld a, $2
; PRET| 	ld [wSprite01StateData1MovementStatus], a
; PRET| 	CheckEvent EVENT_PLAYER_AT_RIGHT_EXIT_TO_PALLET_TOWN
; PRET| 	ld a, SPRITE_FACING_RIGHT
; PRET| 	jr z, .asm_18f01
; PRET| 	ld a, SPRITE_FACING_LEFT
; PRET| .asm_18f01
; PRET| 	ld [wSprite01StateData1FacingDirection], a
; PRET| 
; PRET| 	; trigger the next script
; PRET| 	ld a, SCRIPT_PALLETTOWN_PIKACHU_BATTLE
; PRET| 	ld [wPalletTownCurScript], a
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] PalletTownPikachuBattleScript (scripts/PalletTown.asm:139-153) — a generated asset already defines PalletTownPikachuBattleScript
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, PAD_SELECT | PAD_START | PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 	xor a
; PRET| 	ld [wListScrollOffset], a
; PRET| 	ld a, BATTLE_TYPE_PIKACHU
; PRET| 	ld [wBattleType], a
; PRET| 	ld a, STARTER_PIKACHU
; PRET| 	ld [wCurOpponent], a
; PRET| 	ld a, 5
; PRET| 	ld [wCurEnemyLevel], a
; PRET| 
; PRET| 	; trigger the next script
; PRET| 	ld a, SCRIPT_PALLETTOWN_AFTER_PIKACHU_BATTLE
; PRET| 	ld [wPalletTownCurScript], a
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] PalletTownAfterPikachuBattleScript (scripts/PalletTown.asm:156-174) — a generated asset already defines PalletTownAfterPikachuBattleScript
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, 2
; PRET| 	ld [wOakWalkedToPlayer], a
; PRET| 	ld a, TEXT_PALLETTOWN_OAK
; PRET| 	ldh [hTextID], a
; PRET| 	call DisplayTextID
; PRET| 	ld a, $2
; PRET| 	ld [wSprite01StateData1MovementStatus], a
; PRET| 	ld a, SPRITE_FACING_UP
; PRET| 	ld [wSprite01StateData1FacingDirection], a
; PRET| 	ld a, TEXT_PALLETTOWN_OAK_COME_WITH_ME
; PRET| 	ldh [hTextID], a
; PRET| 	call DisplayTextID
; PRET| 	ld a, PAD_BUTTONS | PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 
; PRET| 	; trigger the next script
; PRET| 	ld a, SCRIPT_PALLETTOWN_OAK_NOT_SAFE_COME_WITH_ME
; PRET| 	ld [wPalletTownCurScript], a
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] PalletTownOakNotSafeComeWithMeScript (scripts/PalletTown.asm:177-191) — a generated asset already defines PalletTownOakNotSafeComeWithMeScript
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	xor a
; PRET| 	ld [wSpritePlayerStateData1FacingDirection], a
; PRET| 	ld a, PALLETTOWN_OAK
; PRET| 	ld [wSpriteIndex], a
; PRET| 	xor a
; PRET| 	ld [wNPCMovementScriptFunctionNum], a
; PRET| 	ld a, 1
; PRET| 	ld [wNPCMovementScriptPointerTableNum], a
; PRET| 	ldh a, [hLoadedROMBank]
; PRET| 	ld [wNPCMovementScriptBank], a
; PRET| 
; PRET| 	; trigger the next script
; PRET| 	ld a, SCRIPT_PALLETTOWN_PLAYER_FOLLOWS_OAK
; PRET| 	ld [wPalletTownCurScript], a
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] PalletTownPlayerFollowsOakScript (scripts/PalletTown.asm:194-201) — a generated asset already defines PalletTownPlayerFollowsOakScript
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wNPCMovementScriptPointerTableNum]
; PRET| 	and a ; is the movement script over?
; PRET| 	ret nz
; PRET| 
; PRET| 	; trigger the next script
; PRET| 	ld a, SCRIPT_PALLETTOWN_DAISY
; PRET| 	ld [wPalletTownCurScript], a
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] PalletTownDaisyScript (scripts/PalletTown.asm:204-214) — a generated asset already defines PalletTownDaisyScript
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_DAISY_WALKING
; PRET| 	jr nz, .next
; PRET| 	CheckBothEventsSet EVENT_GOT_TOWN_MAP, EVENT_ENTERED_BLUES_HOUSE, 1
; PRET| 	jr nz, .next
; PRET| 	SetEvent EVENT_DAISY_WALKING
; PRET| 	ld a, TOGGLE_DAISY_SITTING
; PRET| 	ld [wToggleableObjectIndex], a
; PRET| 	predef HideObject
; PRET| 	ld a, TOGGLE_DAISY_WALKING
; PRET| 	ld [wToggleableObjectIndex], a
; PRET| 	predef_jump ShowObject

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] PalletTownDaisyScript.next (scripts/PalletTown.asm:216-220) — a generated asset already defines PalletTownNoopScript
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_GOT_POKEBALLS_FROM_OAK
; PRET| 	ret z
; PRET| 	SetEvent EVENT_PALLET_AFTER_GETTING_POKEBALLS_2
; PRET| PalletTownNoopScript:
; PRET| 	ret

PalletTown_TextPointers:
    dd PalletTownOakText
    dd PalletTownGirlText
    dd PalletTownFisherText
    dd PalletTownOaksLabSignText
    dd PalletTownSignText
    dd PalletTownPlayersHouseSignText
    dd PalletTownRivalsHouseSignText
    dd PalletTownOakComeWithMe

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] PalletTownOakText (scripts/PalletTown.asm:235-241) — a generated asset already defines PalletTownOakText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wOakWalkedToPlayer]
; PRET| 	and a
; PRET| 	jr nz, .next
; PRET| 	ld a, 1
; PRET| 	ld [wDoNotWaitForButtonPressAfterDisplayingText], a
; PRET| 	ld hl, .HeyWaitDontGoOutText
; PRET| 	jr .done

.next:
    dec al
    jnz .whew
    mov esi, .ThatWasCloseText
    jmp .done

.whew:
    mov esi, .WhewText
.done:
    call PrintText
    jmp TextScriptEnd

.HeyWaitDontGoOutText:
    text_far _PalletTownOakHeyWaitDontGoOutText

    mov bl, 10
    call DelayFrames
    mov al, PLAYER_DIR_DOWN
    mov [ebp + W_PLAYER_MOVING_DIRECTION], al
    mov al, 0
    mov [ebp + wEmotionBubbleSpriteIndex], al
    mov al, 0
    mov [ebp + wWhichEmotionBubble], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and the predef id is not left in A because no reader is live; evidence=PredefPointers is unported and the flat model needs no bank switch, dataflow shows A dead after this site; lifetime=retired when PredefPointers is ported}
    call EmotionBubble
    jmp TextScriptEnd

.ThatWasCloseText:
    text_far _PalletTownOakThatWasCloseText
    text_end
.WhewText:
    text_far _PalletTownOakWhewText
    text_end
PalletTownOakComeWithMe:
    text_far _PalletTownOakComeWithMe
    text_end
PalletTownGirlText:
    text_far _PalletTownGirlText
    text_end
PalletTownFisherText:
    text_far _PalletTownFisherText
    text_end
PalletTownOaksLabSignText:
    text_far _PalletTownOaksLabSignText
    text_end
    text_far _PalletTownSignText
    text_end
PalletTownPlayersHouseSignText:
    text_far _PalletTownPlayersHouseSignText
    text_end
PalletTownRivalsHouseSignText:
    text_far _PalletTownRivalsHouseSignText
    text_end
