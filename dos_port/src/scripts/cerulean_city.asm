; CeruleanCity.asm — translated from pret scripts/CeruleanCity.asm, scripts/CeruleanCity_2.asm by dos_port/tools/sm83xlat.
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

global CeruleanCityBikeShopSign
global CeruleanCityClearScripts
global CeruleanCityCooltrainerF1Text
global CeruleanCityCooltrainerF2Text
global CeruleanCityCoords1
global CeruleanCityCoords2
global CeruleanCityElectrodeText
global CeruleanCityFaceRivalScript
global CeruleanCityGymSign
global CeruleanCityMovement1
global CeruleanCityMovement3
global CeruleanCityMovement4
global CeruleanCityRivalBattleScript
global CeruleanCityRivalCleanupScript
global CeruleanCityRivalDefeatedText
global CeruleanCityRivalIWentToBillsText
global CeruleanCityRivalText
global CeruleanCityRivalVictoryText
global CeruleanCityRocketDefeatedScript
global CeruleanCitySignText
global CeruleanCitySuperNerd3Text
global CeruleanCityTrainerTipsText
global CeruleanCity_Script
global CeruleanCity_ScriptPointers
global CeruleanCity_TextPointers
global CeruleanHideRocket

extern ArePlayerCoordsInArray   ; NOT YET DEFINED IN THE PORT
extern CallFunctionInTable   ; NOT YET DEFINED IN THE PORT
extern CeruleanCityCooltrainerMText   ; NOT YET DEFINED IN THE PORT
extern CeruleanCityDefaultScript   ; NOT YET DEFINED IN THE PORT
extern CeruleanCityGuardText   ; NOT YET DEFINED IN THE PORT
extern CeruleanCityRivalDefeatedScript   ; NOT YET DEFINED IN THE PORT
extern CeruleanCityRocketText   ; NOT YET DEFINED IN THE PORT
extern CeruleanCitySuperNerd1Text   ; NOT YET DEFINED IN THE PORT
extern CeruleanCitySuperNerd2Text   ; NOT YET DEFINED IN THE PORT
extern Delay3   ; NOT YET DEFINED IN THE PORT
extern DisplayTextID   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EngageMapTrainer   ; NOT YET DEFINED IN THE PORT
extern GBFadeInFromBlack   ; NOT YET DEFINED IN THE PORT
extern GBFadeOutToBlack   ; NOT YET DEFINED IN THE PORT
extern GiveItem   ; NOT YET DEFINED IN THE PORT
extern HideObject   ; NOT YET DEFINED IN THE PORT
extern InitBattleEnemyParameters   ; NOT YET DEFINED IN THE PORT
extern MartSignText   ; NOT YET DEFINED IN THE PORT
extern MoveSprite   ; NOT YET DEFINED IN THE PORT
extern Music_RivalAlternateStart   ; NOT YET DEFINED IN THE PORT
extern PlayDefaultMusic   ; NOT YET DEFINED IN THE PORT
extern PlayMusic   ; NOT YET DEFINED IN THE PORT
extern PokeCenterSignText   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern SaveEndBattleTextPointers   ; NOT YET DEFINED IN THE PORT
extern SetSpriteFacingDirectionAndDelay   ; NOT YET DEFINED IN THE PORT
extern SetSpriteMovementBytesToFF   ; NOT YET DEFINED IN THE PORT
extern ShowObject   ; NOT YET DEFINED IN THE PORT
extern StopAllMusic   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern _CeruleanCityBikeShopSign   ; NOT YET DEFINED IN THE PORT
extern _CeruleanCityCooltrainerF1ElectrodePunchText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanCityCooltrainerF1ElectrodeUseSonicboomText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanCityCooltrainerF1ElectrodeWithdrawText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanCityCooltrainerF2Text   ; NOT YET DEFINED IN THE PORT
extern _CeruleanCityElectrodeIgnoredOrdersText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanCityElectrodeIsLoafingAroundText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanCityElectrodeTookASnoozeText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanCityElectrodeTurnedAwayText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanCityGymSign   ; NOT YET DEFINED IN THE PORT
extern _CeruleanCityRivalDefeatedText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanCityRivalIWentToBillsText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanCityRivalPreBattleText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanCityRivalVictoryText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanCityRocketReceivedTM28Text   ; NOT YET DEFINED IN THE PORT
extern _CeruleanCityRocketText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanCitySignText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanCitySuperNerd3Text   ; NOT YET DEFINED IN THE PORT
extern _CeruleanCityTrainerTipsText   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_CERULEANCITY_DEFAULT                    equ 0
SCRIPT_CERULEANCITY_RIVAL_BATTLE               equ 1
SCRIPT_CERULEANCITY_RIVAL_DEFEATED             equ 2
SCRIPT_CERULEANCITY_RIVAL_CLEANUP              equ 3
SCRIPT_CERULEANCITY_ROCKET_DEFEATED            equ 4
TEXT_CERULEANCITY_RIVAL                        equ 1
TEXT_CERULEANCITY_ROCKET                       equ 2

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
hSpriteDataOffset                              equ 0xFF8B
hSpriteFacingDirection                         equ 0xFF8D
wCeruleanCityCurScript                         equ 0xD60E
wCoordIndex                                    equ 0xCD3D
wSprite02StateData1FacingDirection             equ 0xC129

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
CeruleanCity_Script:
    call EnableAutoTextBoxDrawing
    mov esi, CeruleanCity_ScriptPointers
    mov al, [ebp + wCeruleanCityCurScript]
    jmp CallFunctionInTable

%assign event_byte -1
CeruleanCityClearScripts:
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov [ebp + wCeruleanCityCurScript], al
    mov al, 6
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef_jump; behavior=Predef dispatch replaced by a direct jmp, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    jmp HideObject

%assign event_byte -1
CeruleanCity_ScriptPointers:
    dd CeruleanCityDefaultScript
    dd CeruleanCityRivalBattleScript
    dd CeruleanCityRivalDefeatedScript
    dd CeruleanCityRivalCleanupScript
    dd CeruleanCityRocketDefeatedScript

%assign event_byte -1
CeruleanCityRocketDefeatedScript:
    mov al, [ebp + wIsInBattle]
    cmp al, 0xff
    jz CeruleanCityClearScripts
    mov al, PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    SetEvent EVENT_BEAT_CERULEAN_ROCKET_THIEF
    mov al, TEXT_CERULEANCITY_ROCKET
    mov [ebp + hTextID], al
    call DisplayTextID
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov [ebp + wCeruleanCityCurScript], al
    ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] scripts/CeruleanCity.asm:anon (scripts/CeruleanCity.asm:43-62) — at scripts/CeruleanCity.asm:44: .skipRocketThiefEncounter is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_BEAT_CERULEAN_ROCKET_THIEF
; PRET| 	jr nz, .skipRocketThiefEncounter
; PRET| 	ld hl, CeruleanCityCoords1
; PRET| 	call ArePlayerCoordsInArray
; PRET| 	jr nc, .skipRocketThiefEncounter
; PRET| 	ld a, [wCoordIndex]
; PRET| 	cp $1
; PRET| 	ld a, PLAYER_DIR_UP
; PRET| 	ld b, SPRITE_FACING_DOWN
; PRET| 	jr nz, .playerBelowRocketThief
; PRET| 	ld a, PLAYER_DIR_DOWN
; PRET| 	ld b, SPRITE_FACING_UP
; PRET| .playerBelowRocketThief
; PRET| 	ld [wPlayerMovingDirection], a
; PRET| 	ld a, b
; PRET| 	ld [wSprite02StateData1FacingDirection], a
; PRET| 	call Delay3
; PRET| 	ld a, TEXT_CERULEANCITY_ROCKET
; PRET| 	ldh [hTextID], a
; PRET| 	jp DisplayTextID

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] CeruleanCityDefaultScript.skipRocketThiefEncounter (scripts/CeruleanCity.asm:64-100) — at scripts/CeruleanCity.asm:71: .walking is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_BEAT_CERULEAN_RIVAL
; PRET| 	ret nz
; PRET| 	ld hl, CeruleanCityCoords2
; PRET| 	call ArePlayerCoordsInArray
; PRET| 	ret nc
; PRET| 	ld a, [wWalkBikeSurfState]
; PRET| 	and a
; PRET| 	jr z, .walking
; PRET| 	call StopAllMusic
; PRET| .walking
; PRET| 	ld c, BANK(Music_MeetRival)
; PRET| 	ld a, MUSIC_MEET_RIVAL
; PRET| 	call PlayMusic
; PRET| 	xor a
; PRET| 	ldh [hJoyHeld], a
; PRET| 	ld a, PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 	ld a, [wXCoord]
; PRET| 	cp 20 ; is the player standing on the right side of the bridge?
; PRET| 	jr z, .playerOnRightSideOfBridge
; PRET| 	ld a, CERULEANCITY_RIVAL
; PRET| 	ldh [hSpriteIndex], a
; PRET| 	ld a, SPRITESTATEDATA2_MAPX
; PRET| 	ldh [hSpriteDataOffset], a
; PRET| 	call GetPointerWithinSpriteStateData2
; PRET| 	ld [hl], 25
; PRET| .playerOnRightSideOfBridge
; PRET| 	ld a, TOGGLE_CERULEAN_RIVAL
; PRET| 	ld [wToggleableObjectIndex], a
; PRET| 	predef ShowObject
; PRET| 	ld de, CeruleanCityMovement1
; PRET| 	ld a, CERULEANCITY_RIVAL
; PRET| 	ldh [hSpriteIndex], a
; PRET| 	call MoveSprite
; PRET| 	ld a, SCRIPT_CERULEANCITY_RIVAL_BATTLE
; PRET| 	ld [wCeruleanCityCurScript], a
; PRET| 	ret

%assign event_byte -1
CeruleanCityCoords1:
    db 7, 30
    db 9, 30
    db -1
CeruleanCityCoords2:
    db 6, 20
    db 6, 21
    db -1
CeruleanCityMovement1:
    db NPC_MOVEMENT_DOWN
    db NPC_MOVEMENT_DOWN
    db NPC_MOVEMENT_DOWN
    db -1

%assign event_byte -1
CeruleanCityFaceRivalScript:
    mov al, 1
    mov [ebp + hSpriteIndex], al
    xor al, al
    mov [ebp + hSpriteFacingDirection], al
    jmp SetSpriteFacingDirectionAndDelay

%assign event_byte -1
CeruleanCityRivalBattleScript:
    mov al, [ebp + wStatusFlags5]
    test al, (1 << (BIT_SCRIPTED_NPC_MOVEMENT))
    jz .nr_128
        ret
.nr_128:
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov al, TEXT_CERULEANCITY_RIVAL
    mov [ebp + hTextID], al
    call DisplayTextID
    mov esi, wStatusFlags3
    or byte [ebp + esi], (1 << (BIT_TALKED_TO_TRAINER))
    or byte [ebp + esi], (1 << (BIT_PRINT_END_BATTLE_TEXT))
    mov esi, CeruleanCityRivalDefeatedText
    mov edx, CeruleanCityRivalVictoryText   ; pret: ld de, CeruleanCityRivalVictoryText — SaveEndBattleTextPointers takes it in EDX
    call SaveEndBattleTextPointers
    mov al, OPP_RIVAL1
    mov [ebp + wCurOpponent], al
    mov al, 3
    mov [ebp + wTrainerNo], al
    xor al, al
    mov [ebp + hJoyHeld], al
    call CeruleanCityFaceRivalScript
    mov al, SCRIPT_CERULEANCITY_RIVAL_DEFEATED
    mov [ebp + wCeruleanCityCurScript], al
    ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] CeruleanCityRivalDefeatedScript (scripts/CeruleanCity.asm:152-171) — at scripts/CeruleanCity.asm:169: .playerOnRightSideOfBridge is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wIsInBattle]
; PRET| 	cp $ff
; PRET| 	jp z, CeruleanCityClearScripts
; PRET| 	call CeruleanCityFaceRivalScript
; PRET| 	ld a, PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 	SetEvent EVENT_BEAT_CERULEAN_RIVAL
; PRET| 	ld a, TEXT_CERULEANCITY_RIVAL
; PRET| 	ldh [hTextID], a
; PRET| 	call DisplayTextID
; PRET| 	call StopAllMusic
; PRET| 	farcall Music_RivalAlternateStart
; PRET| 	ld a, CERULEANCITY_RIVAL
; PRET| 	ldh [hSpriteIndex], a
; PRET| 	call SetSpriteMovementBytesToFF
; PRET| 	ld a, [wXCoord]
; PRET| 	cp 20 ; is the player standing on the right side of the bridge?
; PRET| 	jr nz, .playerOnRightSideOfBridge
; PRET| 	ld de, CeruleanCityMovement4
; PRET| 	jr .skip

%assign event_byte -1
.playerOnRightSideOfBridge:
    mov edi, CeruleanCityMovement3   ; pret: ld de, CeruleanCityMovement3 — MoveSprite takes it in EDI
.skip:
    mov al, 1
    mov [ebp + hSpriteIndex], al
    call MoveSprite
    mov al, SCRIPT_CERULEANCITY_RIVAL_CLEANUP
    mov [ebp + wCeruleanCityCurScript], al
    ret

%assign event_byte -1
CeruleanCityMovement3:
    db NPC_MOVEMENT_LEFT
    db NPC_MOVEMENT_DOWN
    db NPC_MOVEMENT_DOWN
    db NPC_MOVEMENT_DOWN
    db NPC_MOVEMENT_DOWN
    db NPC_MOVEMENT_DOWN
    db NPC_MOVEMENT_DOWN
    db -1
CeruleanCityMovement4:
    db NPC_MOVEMENT_RIGHT
    db NPC_MOVEMENT_DOWN
    db NPC_MOVEMENT_DOWN
    db NPC_MOVEMENT_DOWN
    db NPC_MOVEMENT_DOWN
    db NPC_MOVEMENT_DOWN
    db NPC_MOVEMENT_DOWN
    db -1

%assign event_byte -1
CeruleanCityRivalCleanupScript:
    mov al, [ebp + wStatusFlags5]
    test al, (1 << (BIT_SCRIPTED_NPC_MOVEMENT))
    jz .nr_205
        ret
.nr_205:
    mov al, 6
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
    xor al, al
    mov [ebp + wJoyIgnore], al
    call PlayDefaultMusic
    mov al, SCRIPT_CERULEANCITY_DEFAULT
    mov [ebp + wCeruleanCityCurScript], al
    ret

%assign event_byte -1
CeruleanCity_TextPointers:
    dd CeruleanCityRivalText
    dd CeruleanCityRocketText
    dd CeruleanCityCooltrainerMText
    dd CeruleanCitySuperNerd1Text
    dd CeruleanCitySuperNerd2Text
    dd CeruleanCityGuardText
    dd CeruleanCityCooltrainerF1Text
    dd CeruleanCityElectrodeText
    dd CeruleanCityCooltrainerF2Text
    dd CeruleanCitySuperNerd3Text
    dd CeruleanCityGuardText
    dd CeruleanCitySignText
    dd CeruleanCityTrainerTipsText
    dd MartSignText
    dd PokeCenterSignText
    dd CeruleanCityBikeShopSign
    dd CeruleanCityGymSign

%assign event_byte -1
CeruleanCityRivalText:
    CheckEvent EVENT_BEAT_CERULEAN_RIVAL
    jz .PreBattle
    mov esi, CeruleanCityRivalIWentToBillsText
    call PrintText
    jmp .end

%assign event_byte -1
.PreBattle:
    mov esi, .PreBattleText
    call PrintText
.end:
    jmp TextScriptEnd

%assign event_byte -1
.PreBattleText:
    text_far _CeruleanCityRivalPreBattleText
    text_end
CeruleanCityRivalDefeatedText:
    text_far _CeruleanCityRivalDefeatedText
    text_end
CeruleanCityRivalVictoryText:
    text_far _CeruleanCityRivalVictoryText
    text_end
CeruleanCityRivalIWentToBillsText:
    text_far _CeruleanCityRivalIWentToBillsText
    text_end

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] CeruleanCityRocketText (scripts/CeruleanCity.asm:269-285) — at scripts/CeruleanCity.asm:270: .beatRocketThief is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_BEAT_CERULEAN_ROCKET_THIEF
; PRET| 	jr nz, .beatRocketThief
; PRET| 	ld hl, .Text
; PRET| 	call PrintText
; PRET| 	ld hl, wStatusFlags3
; PRET| 	set BIT_TALKED_TO_TRAINER, [hl]
; PRET| 	set BIT_PRINT_END_BATTLE_TEXT, [hl]
; PRET| 	ld hl, .IGiveUpText
; PRET| 	ld de, .IGiveUpText
; PRET| 	call SaveEndBattleTextPointers
; PRET| 	ldh a, [hTextID]
; PRET| 	ld [wSpriteIndex], a
; PRET| 	call EngageMapTrainer
; PRET| 	call InitBattleEnemyParameters
; PRET| 	ld a, SCRIPT_CERULEANCITY_ROCKET_DEFEATED
; PRET| 	ld [wCeruleanCityCurScript], a
; PRET| 	jp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] CeruleanCityRocketText.beatRocketThief (scripts/CeruleanCity.asm:287-294) — at scripts/CeruleanCity.asm:287: .IllReturnTheTMText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .IllReturnTheTMText
; PRET| 	call PrintText
; PRET| 	lb bc, TM_DIG, 1
; PRET| 	call GiveItem
; PRET| 	jr c, .Success
; PRET| 	ld hl, .TM28NoRoomText
; PRET| 	call PrintText
; PRET| 	jr .Done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] CeruleanCityRocketText.Success (scripts/CeruleanCity.asm:296-302) — at scripts/CeruleanCity.asm:298: .ReceivedTM28Text is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, $1
; PRET| 	ld [wDoNotWaitForButtonPressAfterDisplayingText], a
; PRET| 	ld hl, .ReceivedTM28Text
; PRET| 	call PrintText
; PRET| 	farcall CeruleanHideRocket
; PRET| .Done
; PRET| 	jp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[text-sound-command-unported] CeruleanCityRocketText.Text (scripts/CeruleanCity.asm:305-341) — at scripts/CeruleanCity.asm:310: sound_get_item_1
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _CeruleanCityRocketText
; PRET| 	text_end
; PRET| 
; PRET| .ReceivedTM28Text:
; PRET| 	text_far _CeruleanCityRocketReceivedTM28Text
; PRET| 	sound_get_item_1
; PRET| 	text_far _CeruleanCityRocketIBetterGetMovingText
; PRET| 	text_waitbutton
; PRET| 	text_end
; PRET| 
; PRET| .TM28NoRoomText:
; PRET| 	text_far _CeruleanCityRocketTM28NoRoomText
; PRET| 	text_end
; PRET| 
; PRET| .IGiveUpText:
; PRET| 	text_far _CeruleanCityRocketIGiveUpText
; PRET| 	text_end
; PRET| 
; PRET| .IllReturnTheTMText:
; PRET| 	text_far _CeruleanCityRocketIllReturnTheTMText
; PRET| 	text_end
; PRET| 
; PRET| CeruleanCityCooltrainerMText:
; PRET| 	text_far _CeruleanCityCooltrainerMText
; PRET| 	text_end
; PRET| 
; PRET| CeruleanCitySuperNerd1Text:
; PRET| 	text_far _CeruleanCitySuperNerd1Text
; PRET| 	text_end
; PRET| 
; PRET| CeruleanCitySuperNerd2Text:
; PRET| 	text_far _CeruleanCitySuperNerd2Text
; PRET| 	text_end
; PRET| 
; PRET| CeruleanCityGuardText:
; PRET| 	text_far _CeruleanCityGuardText
; PRET| 	text_end

%assign event_byte -1
CeruleanCityCooltrainerF1Text:
    mov al, [ebp + hRandomAdd]
    cmp al, 180
    jb .notFirstText
    mov esi, .ElectrodeUseSonicboomText
    call PrintText
    jmp .end

%assign event_byte -1
.notFirstText:
    cmp al, 100
    jb .notSecondText
    mov esi, .ElectrodePunchText
    call PrintText
    jmp .end

%assign event_byte -1
.notSecondText:
    mov esi, .ElectrodeWithdrawText
    call PrintText
.end:
    jmp TextScriptEnd

%assign event_byte -1
.ElectrodeUseSonicboomText:
    text_far _CeruleanCityCooltrainerF1ElectrodeUseSonicboomText
    text_end
.ElectrodePunchText:
    text_far _CeruleanCityCooltrainerF1ElectrodePunchText
    text_end
.ElectrodeWithdrawText:
    text_far _CeruleanCityCooltrainerF1ElectrodeWithdrawText
    text_end

%assign event_byte -1
CeruleanCityElectrodeText:
    mov al, [ebp + hRandomAdd]
    cmp al, 180
    jb .notFirstText
    mov esi, .TookASnoozeText
    call PrintText
    jmp .end

%assign event_byte -1
.notFirstText:
    cmp al, 120
    jb .notSecondText
    mov esi, .IsLoafingAroundText
    call PrintText
    jmp .end

%assign event_byte -1
.notSecondText:
    cmp al, 60
    jb .notThirdText
    mov esi, .TurnedAwayText
    call PrintText
    jmp .end

%assign event_byte -1
.notThirdText:
    mov esi, .IgnoredOrdersText
    call PrintText
.end:
    jmp TextScriptEnd

%assign event_byte -1
.TookASnoozeText:
    text_far _CeruleanCityElectrodeTookASnoozeText
    text_end
.IsLoafingAroundText:
    text_far _CeruleanCityElectrodeIsLoafingAroundText
    text_end
.TurnedAwayText:
    text_far _CeruleanCityElectrodeTurnedAwayText
    text_end
.IgnoredOrdersText:
    text_far _CeruleanCityElectrodeIgnoredOrdersText
    text_end
CeruleanCityCooltrainerF2Text:
    text_far _CeruleanCityCooltrainerF2Text
    text_end
CeruleanCitySuperNerd3Text:
    text_far _CeruleanCitySuperNerd3Text
    text_end
CeruleanCitySignText:
    text_far _CeruleanCitySignText
    text_end
CeruleanCityTrainerTipsText:
    text_far _CeruleanCityTrainerTipsText
    text_end
CeruleanCityBikeShopSign:
    text_far _CeruleanCityBikeShopSign
    text_end
CeruleanCityGymSign:
    text_far _CeruleanCityGymSign
    text_end

%assign event_byte -1
CeruleanHideRocket:
    call GBFadeOutToBlack
    mov al, 8
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call ShowObject
    mov al, 10
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
    mov al, 7
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
    call GBFadeInFromBlack
    ret
