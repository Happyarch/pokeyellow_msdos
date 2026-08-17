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
global CeruleanCityCooltrainerMText
global CeruleanCityCoords1
global CeruleanCityCoords2
global CeruleanCityDefaultScript
global CeruleanCityElectrodeText
global CeruleanCityFaceRivalScript
global CeruleanCityGuardText
global CeruleanCityGymSign
global CeruleanCityMovement1
global CeruleanCityMovement3
global CeruleanCityMovement4
global CeruleanCityRivalBattleScript
global CeruleanCityRivalCleanupScript
global CeruleanCityRivalDefeatedScript
global CeruleanCityRivalDefeatedText
global CeruleanCityRivalIWentToBillsText
global CeruleanCityRivalText
global CeruleanCityRivalVictoryText
global CeruleanCityRocketDefeatedScript
global CeruleanCityRocketText
global CeruleanCitySignText
global CeruleanCitySuperNerd1Text
global CeruleanCitySuperNerd2Text
global CeruleanCitySuperNerd3Text
global CeruleanCityTrainerTipsText
global CeruleanCity_Script
global CeruleanCity_ScriptPointers
global CeruleanCity_TextPointers
global CeruleanHideRocket

extern ArePlayerCoordsInArray
extern Bankswitch
extern CallFunctionInTable
extern Delay3
extern DisplayTextID
extern EnableAutoTextBoxDrawing
extern EngageMapTrainer
extern GBFadeInFromBlack
extern GBFadeOutToBlack
extern GetPointerWithinSpriteStateData2   ; NOT YET DEFINED IN THE PORT
extern GiveItem
extern HideObject
extern InitBattleEnemyParameters
extern MartSignText   ; NOT YET DEFINED IN THE PORT
extern MoveSprite
extern Music_RivalAlternateStart
extern PlayDefaultMusic
extern PlayMusic
extern PokeCenterSignText   ; NOT YET DEFINED IN THE PORT
extern PrintText
extern SaveEndBattleTextPointers
extern SetSpriteFacingDirectionAndDelay   ; NOT YET DEFINED IN THE PORT
extern SetSpriteMovementBytesToFF
extern ShowObject
extern StopAllMusic
extern TextScriptEnd
extern _CeruleanCityBikeShopSign   ; NOT YET DEFINED IN THE PORT
extern _CeruleanCityCooltrainerF1ElectrodePunchText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanCityCooltrainerF1ElectrodeUseSonicboomText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanCityCooltrainerF1ElectrodeWithdrawText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanCityCooltrainerF2Text   ; NOT YET DEFINED IN THE PORT
extern _CeruleanCityCooltrainerMText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanCityElectrodeIgnoredOrdersText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanCityElectrodeIsLoafingAroundText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanCityElectrodeTookASnoozeText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanCityElectrodeTurnedAwayText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanCityGuardText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanCityGymSign   ; NOT YET DEFINED IN THE PORT
extern _CeruleanCityRivalDefeatedText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanCityRivalIWentToBillsText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanCityRivalPreBattleText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanCityRivalVictoryText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanCityRocketIBetterGetMovingText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanCityRocketIGiveUpText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanCityRocketIllReturnTheTMText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanCityRocketReceivedTM28Text   ; NOT YET DEFINED IN THE PORT
extern _CeruleanCityRocketTM28NoRoomText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanCityRocketText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanCitySignText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanCitySuperNerd1Text   ; NOT YET DEFINED IN THE PORT
extern _CeruleanCitySuperNerd2Text   ; NOT YET DEFINED IN THE PORT
extern _CeruleanCitySuperNerd3Text   ; NOT YET DEFINED IN THE PORT
extern _CeruleanCityTrainerTipsText   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
CERULEANCITY_RIVAL                             equ 1
SCRIPT_CERULEANCITY_DEFAULT                    equ 0
SCRIPT_CERULEANCITY_RIVAL_BATTLE               equ 1
SCRIPT_CERULEANCITY_RIVAL_DEFEATED             equ 2
SCRIPT_CERULEANCITY_RIVAL_CLEANUP              equ 3
SCRIPT_CERULEANCITY_ROCKET_DEFEATED            equ 4
TEXT_CERULEANCITY_RIVAL                        equ 1
TEXT_CERULEANCITY_ROCKET                       equ 2
TOGGLE_CERULEAN_RIVAL                          equ 6

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
%assign event_byte_a -1
CeruleanCity_Script:
    call EnableAutoTextBoxDrawing
    mov esi, CeruleanCity_ScriptPointers
    mov al, [ebp + wCeruleanCityCurScript]
    jmp CallFunctionInTable

%assign event_byte -1
%assign event_byte_a -1
CeruleanCityClearScripts:
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov [ebp + wCeruleanCityCurScript], al
    mov al, 6
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef_jump; behavior=Predef dispatch replaced by a direct jmp, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    jmp HideObject

%assign event_byte -1
%assign event_byte_a -1
CeruleanCity_ScriptPointers:
    dd CeruleanCityDefaultScript
    dd CeruleanCityRivalBattleScript
    dd CeruleanCityRivalDefeatedScript
    dd CeruleanCityRivalCleanupScript
    dd CeruleanCityRocketDefeatedScript

%assign event_byte -1
%assign event_byte_a -1
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

%assign event_byte -1
%assign event_byte_a -1
CeruleanCityDefaultScript:
    CheckEvent EVENT_BEAT_CERULEAN_ROCKET_THIEF
    jnz .skipRocketThiefEncounter
    mov esi, CeruleanCityCoords1
    call ArePlayerCoordsInArray
    jnc .skipRocketThiefEncounter
    mov al, [ebp + wCoordIndex]
    cmp al, 0x1
    mov al, PLAYER_DIR_UP
    mov bh, SPRITE_FACING_DOWN
    jnz .playerBelowRocketThief
    mov al, PLAYER_DIR_DOWN
    mov bh, SPRITE_FACING_UP
.playerBelowRocketThief:
    mov [ebp + wPlayerMovingDirection], al
    mov al, bh
    mov [ebp + wSprite02StateData1FacingDirection], al
    call Delay3
    mov al, TEXT_CERULEANCITY_ROCKET
    mov [ebp + hTextID], al
    jmp DisplayTextID

%assign event_byte -1
%assign event_byte_a -1
.skipRocketThiefEncounter:
    CheckEvent EVENT_BEAT_CERULEAN_RIVAL
    jz .nr_rival_event
        ret
.nr_rival_event:
    mov esi, CeruleanCityCoords2
    call ArePlayerCoordsInArray
    jb .nr_rival_coords
        ret
.nr_rival_coords:
    mov al, [ebp + wWalkBikeSurfState]
    test al, al
    jz .walking
    call StopAllMusic
.walking:
    mov bl, 2
    mov al, MUSIC_MEET_RIVAL
    call PlayMusic
    xor al, al
    mov [ebp + hJoyHeld], al
    mov al, PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, [ebp + wXCoord]
    cmp al, 20   ; is the player standing on the right side of the bridge?
    jz .playerOnRightSideOfBridge
    mov al, CERULEANCITY_RIVAL
    mov [ebp + hSpriteIndex], al
    mov al, SPRITESTATEDATA2_MAPX
    mov [ebp + hSpriteDataOffset], al
    call GetPointerWithinSpriteStateData2
    mov byte [ebp + esi], 25
.playerOnRightSideOfBridge:
    mov al, TOGGLE_CERULEAN_RIVAL
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call ShowObject
    mov edi, CeruleanCityMovement1   ; pret: ld de, CeruleanCityMovement1 — MoveSprite takes it in EDI
    mov al, CERULEANCITY_RIVAL
    mov [ebp + hSpriteIndex], al
    call MoveSprite
    mov al, SCRIPT_CERULEANCITY_RIVAL_BATTLE
    mov [ebp + wCeruleanCityCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
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
%assign event_byte_a -1
CeruleanCityFaceRivalScript:
    mov al, 1
    mov [ebp + hSpriteIndex], al
    xor al, al
    mov [ebp + hSpriteFacingDirection], al
    jmp SetSpriteFacingDirectionAndDelay

%assign event_byte -1
%assign event_byte_a -1
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

%assign event_byte -1
%assign event_byte_a -1
CeruleanCityRivalDefeatedScript:
    mov al, [ebp + wIsInBattle]
    cmp al, 0xff
    jz CeruleanCityClearScripts
    call CeruleanCityFaceRivalScript
    mov al, PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    SetEvent EVENT_BEAT_CERULEAN_RIVAL
    mov al, TEXT_CERULEANCITY_RIVAL
    mov [ebp + hTextID], al
    call DisplayTextID
    call StopAllMusic
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call Music_RivalAlternateStart
    mov al, 1
    mov [ebp + hSpriteIndex], al
    call SetSpriteMovementBytesToFF
    mov al, [ebp + wXCoord]
    cmp al, 20
    jnz .playerOnRightSideOfBridge
    mov edi, CeruleanCityMovement4   ; pret: ld de, CeruleanCityMovement4 — MoveSprite takes it in EDI
    jmp .skip

%assign event_byte -1
%assign event_byte_a -1
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
%assign event_byte_a -1
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
%assign event_byte_a -1
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
%assign event_byte_a -1
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
%assign event_byte_a -1
CeruleanCityRivalText:
    CheckEvent EVENT_BEAT_CERULEAN_RIVAL
    jz .PreBattle
    mov esi, CeruleanCityRivalIWentToBillsText
    call PrintText
    jmp .end

%assign event_byte -1
%assign event_byte_a -1
.PreBattle:
    mov esi, .PreBattleText
    call PrintText
.end:
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
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

%assign event_byte -1
%assign event_byte_a -1
CeruleanCityRocketText:
    CheckEvent EVENT_BEAT_CERULEAN_ROCKET_THIEF
    jnz .beatRocketThief
    mov esi, .Text
    call PrintText
    mov esi, wStatusFlags3
    or byte [ebp + esi], (1 << (BIT_TALKED_TO_TRAINER))
    or byte [ebp + esi], (1 << (BIT_PRINT_END_BATTLE_TEXT))
    mov esi, .IGiveUpText
    mov edx, .IGiveUpText   ; pret: ld de, .IGiveUpText — SaveEndBattleTextPointers takes it in EDX
    call SaveEndBattleTextPointers
    mov al, [ebp + hTextID]
    mov [ebp + wSpriteIndex], al
    call EngageMapTrainer
    call InitBattleEnemyParameters
    mov al, SCRIPT_CERULEANCITY_ROCKET_DEFEATED
    mov [ebp + wCeruleanCityCurScript], al
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.beatRocketThief:
    mov esi, .IllReturnTheTMText
    call PrintText
    mov bx, ((230) << 8) | (1)
    call GiveItem
    jb .Success
    mov esi, .TM28NoRoomText
    call PrintText
    jmp .Done

%assign event_byte -1
%assign event_byte_a -1
.Success:
    mov al, 0x1
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    mov esi, .ReceivedTM28Text
    call PrintText
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call CeruleanHideRocket
.Done:
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.Text:
    text_far _CeruleanCityRocketText
    text_end
.ReceivedTM28Text:
    text_far _CeruleanCityRocketReceivedTM28Text
    sound_get_item_1
    text_far _CeruleanCityRocketIBetterGetMovingText
    text_waitbutton
    text_end
.TM28NoRoomText:
    text_far _CeruleanCityRocketTM28NoRoomText
    text_end
.IGiveUpText:
    text_far _CeruleanCityRocketIGiveUpText
    text_end
.IllReturnTheTMText:
    text_far _CeruleanCityRocketIllReturnTheTMText
    text_end
CeruleanCityCooltrainerMText:
    text_far _CeruleanCityCooltrainerMText
    text_end
CeruleanCitySuperNerd1Text:
    text_far _CeruleanCitySuperNerd1Text
    text_end
CeruleanCitySuperNerd2Text:
    text_far _CeruleanCitySuperNerd2Text
    text_end
CeruleanCityGuardText:
    text_far _CeruleanCityGuardText
    text_end

%assign event_byte -1
%assign event_byte_a -1
CeruleanCityCooltrainerF1Text:
    mov al, [ebp + hRandomAdd]
    cmp al, 180
    jb .notFirstText
    mov esi, .ElectrodeUseSonicboomText
    call PrintText
    jmp .end

%assign event_byte -1
%assign event_byte_a -1
.notFirstText:
    cmp al, 100
    jb .notSecondText
    mov esi, .ElectrodePunchText
    call PrintText
    jmp .end

%assign event_byte -1
%assign event_byte_a -1
.notSecondText:
    mov esi, .ElectrodeWithdrawText
    call PrintText
.end:
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
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
%assign event_byte_a -1
CeruleanCityElectrodeText:
    mov al, [ebp + hRandomAdd]
    cmp al, 180
    jb .notFirstText
    mov esi, .TookASnoozeText
    call PrintText
    jmp .end

%assign event_byte -1
%assign event_byte_a -1
.notFirstText:
    cmp al, 120
    jb .notSecondText
    mov esi, .IsLoafingAroundText
    call PrintText
    jmp .end

%assign event_byte -1
%assign event_byte_a -1
.notSecondText:
    cmp al, 60
    jb .notThirdText
    mov esi, .TurnedAwayText
    call PrintText
    jmp .end

%assign event_byte -1
%assign event_byte_a -1
.notThirdText:
    mov esi, .IgnoredOrdersText
    call PrintText
.end:
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
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
%assign event_byte_a -1
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
