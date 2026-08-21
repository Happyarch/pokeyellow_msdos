; OaksLab.asm — translated from pret scripts/OaksLab.asm, scripts/OaksLab_2.asm by dos_port/tools/sm83xlat.
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
%include "assets/script_constants.inc"

%include "assets/audio_constants.inc"
%include "assets/pika_pcm.inc"

global OaksLabPikachuDislikesPokeballsText1
global OakEntryMovement
global OaksLabCalcRivalMovementScript
global OaksLabChoseStarterScript
global OaksLabDefaultScript
global OaksLabEeveePokeBallText
global OaksLabFollowedOakScript
global OaksLabGirlText
global OaksLabLoadTextPointers2Script
global OaksLabNoopScript
global OaksLabOak1Text
global OaksLabOak2Text
global OaksLabOakBePatientText
global OaksLabOakChooseMonSpeechScript
global OaksLabOakChooseMonText
global OaksLabOakDontGoAwayYetText
global OaksLabOakEntersLabScript
global OaksLabOakGivesPokedexScript
global OaksLabOakGivesText
global OaksLabOakGotPokedexText
global OaksLabOakIHaveARequestText
global OaksLabOakMyInventionPokedexText
global OaksLabOakThatWasMyDreamText
global OaksLabPikachuDislikesPokeballsScript
global OaksLabPikachuDislikesPokeballsText2
global OaksLabPikachuEscapesPokeballScript
global OaksLabPikachuMovementData1
global OaksLabPikachuMovementData2
global OaksLabPikachuMovementScript
global OaksLabPlayerDontGoAwayScript
global OaksLabPlayerEntersLabScript
global OaksLabPlayerForcedToWalkBackScript
global OaksLabPlayerReceivedMonText
global OaksLabPlayerReceivesPikachuScript
global OaksLabPlayerWalksToOakScript
global OaksLabPlayerWatchRivalExitScript
global OaksLabPokedexText
global OaksLabRLE_PlayerWalksToOak
global OaksLabReceivedText
global OaksLabRivalAmIGreatOrWhatText
global OaksLabRivalArrivesAtOaksRequestScript
global OaksLabRivalChallengesPlayerScript
global OaksLabRivalEndBattleScript
global OaksLabRivalExclamationScript
global OaksLabRivalFaceUpOakFaceDownScript
global OaksLabRivalFedUpWithWaitingText
global OaksLabRivalGrampsText
global OaksLabRivalIPickedTheWrongPokemonText
global OaksLabRivalIllTakeYouOnText
global OaksLabRivalLeaveItAllToMeText
global OaksLabRivalLeavesWithPokedexScript
global OaksLabRivalMyPokemonHasGrownStrongerText
global OaksLabRivalReceivedMonText
global OaksLabRivalSmellYouLaterText
global OaksLabRivalStartBattleScript
global OaksLabRivalStartsExitScript
global OaksLabRivalTakesPokeballScript
global OaksLabRivalTakesText1
global OaksLabRivalTakesText2
global OaksLabRivalTakesText3
global OaksLabRivalTakesText4
global OaksLabRivalTakesText5
global OaksLabRivalText
global OaksLabRivalWhatAboutMeText
global OaksLabScientistText
global OaksLabScript_RemoveParcel
global OaksLabToggleOaksScript
global OaksLab_Script
global OaksLab_ScriptPointers
global OaksLab_TextPointers
global OaksLab_TextPointers2
global PlayerEntryMovementRLE

extern AddPartyMon
extern Bankswitch
extern CalcPositionOfPlayerRelativeToNPC
extern CallFunctionInTable
extern CountSetBits
extern DecodeRLEList
extern Delay3
extern DelayFrame
extern DelayFrames
extern DisablePikachuOverworldSpriteDrawing
extern DisplayDexRating
extern DisplayTextID
extern EmotionBubble
extern EnableAutoTextBoxDrawing
extern EnablePikachuOverworldSpriteDrawing
extern FillMemory
extern FindPathToPlayer
extern GetMonName
extern GetSpritePosition1
extern GiveItem
extern HealParty
extern HideObject
extern IsItemInBag
extern MoveSprite
extern Music_RivalAlternateStart
extern PlayDefaultMusic
extern PlayMusic
extern PlayPikachuSoundClip
extern PrintText
extern RemoveItemFromInventory
extern SaveEndBattleTextPointers
extern SchedulePikachuSpawnForAfterText   ; NOT YET DEFINED IN THE PORT
extern SetSpriteFacingDirectionAndDelay   ; NOT YET DEFINED IN THE PORT
extern SetSpritePosition1
extern ShowObject
extern StartSimulatingJoypadStates
extern StopAllMusic
extern TextScriptEnd
extern TryApplyPikachuMovementData   ; NOT YET DEFINED IN THE PORT
extern UpdateSprites

; Script constants — pret defines these via dw_const in this file.
SCRIPT_OAKSLAB_OAK_ENTERS_LAB                  equ 1
SCRIPT_OAKSLAB_TOGGLE_OAKS                     equ 2
SCRIPT_OAKSLAB_PLAYER_ENTERS_LAB               equ 3
SCRIPT_OAKSLAB_FOLLOWED_OAK                    equ 4
SCRIPT_OAKSLAB_OAK_CHOOSE_MON_SPEECH           equ 5
SCRIPT_OAKSLAB_PLAYER_DONT_GO_AWAY_SCRIPT      equ 6
SCRIPT_OAKSLAB_PLAYER_FORCED_TO_WALK_BACK_SCRIPT equ 7
SCRIPT_OAKSLAB_CHOSE_STARTER_SCRIPT            equ 8
SCRIPT_OAKSLAB_RIVAL_TAKES_POKEBALL            equ 9
SCRIPT_OAKSLAB_PLAYER_WALKS_TO_OAK             equ 10
SCRIPT_OAKSLAB_PLAYER_RECEIVES_PIKACHU         equ 11
SCRIPT_OAKSLAB_RIVAL_CHALLENGES_PLAYER         equ 12
SCRIPT_OAKSLAB_RIVAL_START_BATTLE              equ 13
SCRIPT_OAKSLAB_RIVAL_END_BATTLE                equ 14
SCRIPT_OAKSLAB_RIVAL_STARTS_EXIT               equ 15
SCRIPT_OAKSLAB_PLAYER_WATCH_RIVAL_EXIT         equ 16
SCRIPT_OAKSLAB_PIKACHU_ESCAPES_POKEBALL        equ 17
SCRIPT_OAKSLAB_PIKACHU_DISLIKES_POKEBALLS      equ 18
SCRIPT_OAKSLAB_RIVAL_ARRIVES_AT_OAKS_REQUEST   equ 19
SCRIPT_OAKSLAB_OAK_GIVES_POKEDEX               equ 20
SCRIPT_OAKSLAB_RIVAL_LEAVES_WITH_POKEDEX       equ 21
SCRIPT_OAKSLAB_NOOP                            equ 22
TEXT_OAKSLAB_OAK_DONT_GO_AWAY_YET              equ 10
TEXT_OAKSLAB_RIVAL_ILL_TAKE_YOU_ON             equ 11
TEXT_OAKSLAB_RIVAL_SMELL_YOU_LATER             equ 12
TEXT_OAKSLAB_RIVAL_FED_UP_WITH_WAITING         equ 13
TEXT_OAKSLAB_OAK_CHOOSE_MON                    equ 14
TEXT_OAKSLAB_RIVAL_WHAT_ABOUT_ME               equ 15
TEXT_OAKSLAB_OAK_BE_PATIENT                    equ 16
TEXT_OAKSLAB_RIVAL_RECEIVED_MON                equ 17
TEXT_OAKSLAB_PLAYER_RECEIVED_MON               equ 18
TEXT_OAKSLAB_RIVAL_GRAMPS                      equ 19
TEXT_OAKSLAB_RIVAL_MY_POKEMON_HAS_GROWN_STRONGER equ 20
TEXT_OAKSLAB_OAK_I_HAVE_A_REQUEST              equ 21
TEXT_OAKSLAB_OAK_MY_INVENTION_POKEDEX          equ 22
TEXT_OAKSLAB_OAK_GOT_POKEDEX                   equ 23
TEXT_OAKSLAB_OAK_THAT_WAS_MY_DREAM             equ 24
TEXT_OAKSLAB_RIVAL_LEAVE_IT_ALL_TO_ME          equ 25
TEXT_OAKSLAB_PIKACHU_DISLIKES_POKEBALLS1       equ 26
TEXT_OAKSLAB_PIKACHU_DISLIKES_POKEBALLS2       equ 27
SCRIPT_VIRIDIANCITY_AFTER_POKEDEX              equ 1

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
; Far text streams for this map — pret text/oaks_lab, generated by
; tools/generators/gen_map_text.py. Defined HERE because every one is used
; only by this script, exactly as pret keeps text/<Map>.asm beside scripts/<Map>.asm.
section .data
%include "assets/map_text/OaksLab.inc"

section .text

%assign event_byte -1
%assign event_byte_a -1
OaksLab_Script:
    CheckEvent EVENT_PALLET_AFTER_GETTING_POKEBALLS_2
    jz .sk_3
        call OaksLabLoadTextPointers2Script
.sk_3:
    mov al, 1 << BIT_NO_AUTO_TEXT_BOX
    mov [ebp + wAutoTextBoxDrawingControl], al
    xor al, al
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    mov esi, OaksLab_ScriptPointers
    mov al, [ebp + wOaksLabCurScript]
    call CallFunctionInTable
    ret

%assign event_byte -1
%assign event_byte_a -1
OaksLab_ScriptPointers:
    dd OaksLabDefaultScript
    dd OaksLabOakEntersLabScript
    dd OaksLabToggleOaksScript
    dd OaksLabPlayerEntersLabScript
    dd OaksLabFollowedOakScript
    dd OaksLabOakChooseMonSpeechScript
    dd OaksLabPlayerDontGoAwayScript
    dd OaksLabPlayerForcedToWalkBackScript
    dd OaksLabChoseStarterScript
    dd OaksLabRivalTakesPokeballScript
    dd OaksLabPlayerWalksToOakScript
    dd OaksLabPlayerReceivesPikachuScript
    dd OaksLabRivalChallengesPlayerScript
    dd OaksLabRivalStartBattleScript
    dd OaksLabRivalEndBattleScript
    dd OaksLabRivalStartsExitScript
    dd OaksLabPlayerWatchRivalExitScript
    dd OaksLabPikachuEscapesPokeballScript
    dd OaksLabPikachuDislikesPokeballsScript
    dd OaksLabRivalArrivesAtOaksRequestScript
    dd OaksLabOakGivesPokedexScript
    dd OaksLabRivalLeavesWithPokedexScript
    dd OaksLabNoopScript

%assign event_byte -1
%assign event_byte_a -1
OaksLabDefaultScript:
    CheckEvent EVENT_OAK_APPEARED_IN_PALLET
    jnz .nr_41
        ret
.nr_41:
    mov al, [ebp + wNPCMovementScriptFunctionNum]
    test al, al
    jz .nr_44
        ret
.nr_44:
    mov al, TOGGLE_OAKS_LAB_OAK_2
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call ShowObject
    mov esi, wStatusFlags4
    and byte [ebp + esi], ~(1 << (BIT_NO_BATTLES)) & 0xFF
    mov al, SCRIPT_OAKSLAB_OAK_ENTERS_LAB
    mov [ebp + wOaksLabCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
OaksLabOakEntersLabScript:
    mov al, 6
    mov [ebp + hSpriteIndex], al
    mov edi, OakEntryMovement   ; pret: ld de, OakEntryMovement — MoveSprite takes it in EDI
    call MoveSprite
    mov al, SCRIPT_OAKSLAB_TOGGLE_OAKS
    mov [ebp + wOaksLabCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
OakEntryMovement:
    db NPC_MOVEMENT_UP
    db NPC_MOVEMENT_UP
    db NPC_MOVEMENT_UP
    db -1

%assign event_byte -1
%assign event_byte_a -1
OaksLabToggleOaksScript:
    mov al, [ebp + wStatusFlags5]
    test al, (1 << (BIT_SCRIPTED_NPC_MOVEMENT))
    jz .nr_74
        ret
.nr_74:
    mov al, TOGGLE_OAKS_LAB_OAK_2
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
    mov al, TOGGLE_OAKS_LAB_OAK_1
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call ShowObject
    mov al, SCRIPT_OAKSLAB_PLAYER_ENTERS_LAB
    mov [ebp + wOaksLabCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
OaksLabPlayerEntersLabScript:
    call Delay3
    mov esi, wSimulatedJoypadStatesEnd
    mov edi, PlayerEntryMovementRLE   ; pret: ld de, PlayerEntryMovementRLE — DecodeRLEList takes it in EDI
    call DecodeRLEList
    dec al
    mov [ebp + wSimulatedJoypadStatesIndex], al
    call StartSimulatingJoypadStates
    mov al, 1
    mov [ebp + hSpriteIndex], al
    xor al, al
    mov [ebp + hSpriteFacingDirection], al
    call SetSpriteFacingDirectionAndDelay
    mov al, 3
    mov [ebp + hSpriteIndex], al
    xor al, al
    mov [ebp + hSpriteFacingDirection], al
    call SetSpriteFacingDirectionAndDelay
    mov al, SCRIPT_OAKSLAB_FOLLOWED_OAK
    mov [ebp + wOaksLabCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
PlayerEntryMovementRLE:
    db PAD_UP, 8
    db -1

%assign event_byte -1
%assign event_byte_a -1
OaksLabFollowedOakScript:
    mov al, [ebp + wSimulatedJoypadStatesIndex]
    test al, al
    jz .nr_116
        ret
.nr_116:
    SetEvent EVENT_FOLLOWED_OAK_INTO_LAB
    SetEvent EVENT_FOLLOWED_OAK_INTO_LAB_2
    mov al, 1
    mov [ebp + hSpriteIndex], al
    mov al, SPRITE_FACING_UP
    mov [ebp + hSpriteFacingDirection], al
    call SetSpriteFacingDirectionAndDelay
    mov esi, wStatusFlags7
    and byte [ebp + esi], ~(1 << (BIT_NO_MAP_MUSIC)) & 0xFF
    call PlayDefaultMusic
    mov al, SCRIPT_OAKSLAB_OAK_CHOOSE_MON_SPEECH
    mov [ebp + wOaksLabCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
OaksLabOakChooseMonSpeechScript:
    SetEvent EVENT_OAK_ASKED_TO_CHOOSE_MON
    mov al, PAD_SELECT | PAD_START | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, TEXT_OAKSLAB_RIVAL_FED_UP_WITH_WAITING
    mov [ebp + hTextID], al
    call DisplayTextID
    call Delay3
    mov al, TEXT_OAKSLAB_OAK_CHOOSE_MON
    mov [ebp + hTextID], al
    call DisplayTextID
    call Delay3
    mov al, 0x2
    mov [ebp + wSprite01StateData1MovementStatus], al
    mov al, SPRITE_FACING_UP
    mov [ebp + wSprite01StateData1FacingDirection], al
    mov al, TEXT_OAKSLAB_RIVAL_WHAT_ABOUT_ME
    mov [ebp + hTextID], al
    call DisplayTextID
    call Delay3
    mov al, TEXT_OAKSLAB_OAK_BE_PATIENT
    mov [ebp + hTextID], al
    call DisplayTextID
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov al, SCRIPT_OAKSLAB_PLAYER_DONT_GO_AWAY_SCRIPT
    mov [ebp + wOaksLabCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
OaksLabPlayerDontGoAwayScript:
    mov al, [ebp + wYCoord]
    cmp al, 6
    jz .nr_165
        ret
.nr_165:
    mov al, 3
    mov [ebp + hSpriteIndex], al
    xor al, al
    mov [ebp + hSpriteFacingDirection], al
    call SetSpriteFacingDirectionAndDelay
    mov al, 1
    mov [ebp + hSpriteIndex], al
    xor al, al
    mov [ebp + hSpriteFacingDirection], al
    call SetSpriteFacingDirectionAndDelay
    call UpdateSprites
    mov al, TEXT_OAKSLAB_OAK_DONT_GO_AWAY_YET
    mov [ebp + hTextID], al
    call DisplayTextID
    mov al, 0x1
    mov [ebp + wSimulatedJoypadStatesIndex], al
    mov al, PAD_UP
    mov [ebp + wSimulatedJoypadStatesEnd], al
    call StartSimulatingJoypadStates
    mov al, PLAYER_DIR_UP
    mov [ebp + wPlayerMovingDirection], al
    mov al, SCRIPT_OAKSLAB_PLAYER_FORCED_TO_WALK_BACK_SCRIPT
    mov [ebp + wOaksLabCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
OaksLabPlayerForcedToWalkBackScript:
    mov al, [ebp + wSimulatedJoypadStatesIndex]
    test al, al
    jz .nr_195
        ret
.nr_195:
    call Delay3
    mov al, SCRIPT_OAKSLAB_PLAYER_DONT_GO_AWAY_SCRIPT
    mov [ebp + wOaksLabCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
OaksLabChoseStarterScript:
    mov al, 1
    mov [ebp + hSpriteIndex], al
    mov edi, .RivalPushesPlayerAwayFromEeveeBall   ; pret: ld de, .RivalPushesPlayerAwayFromEeveeBall — MoveSprite takes it in EDI
    call MoveSprite
    mov al, SCRIPT_OAKSLAB_RIVAL_TAKES_POKEBALL
    mov [ebp + wOaksLabCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
.RivalPushesPlayerAwayFromEeveeBall:
    db 0x00
    db 0x07
    db 0x07
    db 0x07
    db 0xFF

%assign event_byte -1
%assign event_byte_a -1
OaksLabRivalTakesPokeballScript:
    mov al, [ebp + wStatusFlags5]
    test al, (1 << (BIT_SCRIPTED_NPC_MOVEMENT))
    jnz .asm_1c564
    mov al, TOGGLE_STARTER_BALL_1
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
    mov al, 1
    mov [ebp + hSpriteIndex], al
    mov al, SPRITE_FACING_UP
    mov [ebp + hSpriteFacingDirection], al
    call SetSpriteFacingDirectionAndDelay
    mov al, 1
    mov [ebp + wRivalStarter], al
    mov al, EEVEE
    mov [ebp + wNamedObjectIndex], al
    call GetMonName
    mov al, PAD_SELECT | PAD_START | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, TEXT_OAKSLAB_RIVAL_RECEIVED_MON
    mov [ebp + hTextID], al
    call DisplayTextID
    mov al, SCRIPT_OAKSLAB_PLAYER_WALKS_TO_OAK
    mov [ebp + wOaksLabCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
.asm_1c564:
    mov al, [ebp + wYCoord]
    cmp al, 4
    jz .nr_248
        ret
.nr_248:
    mov al, [ebp + wNPCNumScriptedSteps]
    cmp al, 1
    jz .nr_251
        ret
.nr_251:
    mov al, PLAYER_DIR_LEFT
    mov [ebp + wPlayerMovingDirection], al
    mov al, 0x2
    mov [ebp + wSimulatedJoypadStatesIndex], al
    mov al, PAD_RIGHT
    mov [ebp + wSimulatedJoypadStatesEnd], al
    mov [ebp + wSimulatedJoypadStatesEnd + 1], al
    call StartSimulatingJoypadStates
    ret

%assign event_byte -1
%assign event_byte_a -1
OaksLabPlayerWalksToOakScript:
    mov al, [ebp + wYCoord]
    cmp al, 4
    jz .asm_1c599
    mov al, 0x1
    mov [ebp + wSimulatedJoypadStatesIndex], al
    mov al, PAD_LEFT
    mov [ebp + wSimulatedJoypadStatesEnd], al
    jmp .asm_1c5a6

%assign event_byte -1
%assign event_byte_a -1
.asm_1c599:
    mov esi, wSimulatedJoypadStatesEnd
    mov edi, OaksLabRLE_PlayerWalksToOak   ; pret: ld de, OaksLabRLE_PlayerWalksToOak — DecodeRLEList takes it in EDI
    call DecodeRLEList
    dec al
    mov [ebp + wSimulatedJoypadStatesIndex], al
.asm_1c5a6:
    call StartSimulatingJoypadStates
    mov al, SCRIPT_OAKSLAB_PLAYER_RECEIVES_PIKACHU
    mov [ebp + wOaksLabCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
OaksLabRLE_PlayerWalksToOak:
    db PAD_UP, 2
    db PAD_LEFT, 3
    db PAD_DOWN, 1
    db PAD_LEFT, 1
    db 0xFF

%assign event_byte -1
%assign event_byte_a -1
OaksLabPlayerReceivesPikachuScript:
    mov al, [ebp + wSimulatedJoypadStatesIndex]
    test al, al
    jz .nr_294
        ret
.nr_294:
    mov al, TEXT_OAKSLAB_PLAYER_RECEIVED_MON
    mov [ebp + hTextID], al
    call DisplayTextID
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov al, SCRIPT_OAKSLAB_RIVAL_CHALLENGES_PLAYER
    mov [ebp + wOaksLabCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
OaksLabRivalChallengesPlayerScript:
    mov al, [ebp + wYCoord]
    cmp al, 6
    jz .nr_308
        ret
.nr_308:
    mov al, PLAYER_DIR_UP
    mov [ebp + wPlayerMovingDirection], al
    mov al, 1
    mov [ebp + hSpriteIndex], al
    xor al, al
    mov [ebp + hSpriteFacingDirection], al
    call SetSpriteFacingDirectionAndDelay
    mov bl, 2
    mov al, MUSIC_MEET_RIVAL
    call PlayMusic
    mov al, TEXT_OAKSLAB_RIVAL_ILL_TAKE_YOU_ON
    mov [ebp + hTextID], al
    call DisplayTextID
    mov al, 0x1
    mov [ebp + hNPCPlayerRelativePosPerspective], al
    mov al, 0x1
    rol al, 4
    test al, al   ; swap sets Z, clears C
    mov [ebp + hNPCPlayerYDistance], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call CalcPositionOfPlayerRelativeToNPC
    mov al, [ebp + hNPCPlayerYDistance]
    dec al
    mov [ebp + hNPCPlayerYDistance], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call FindPathToPlayer
    mov dx, wNPCMovementDirections2
    mov al, 1
    mov [ebp + hSpriteIndex], al
    call MoveSprite
    mov al, SCRIPT_OAKSLAB_RIVAL_START_BATTLE
    mov [ebp + wOaksLabCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
OaksLabRivalStartBattleScript:
    mov al, [ebp + wStatusFlags5]
    test al, (1 << (BIT_SCRIPTED_NPC_MOVEMENT))
    jz .nr_343
        ret
.nr_343:
    mov al, 1
    mov [ebp + wSpriteIndex], al
    call GetSpritePosition1
    mov al, OPP_RIVAL1
    mov [ebp + wCurOpponent], al
    mov al, 0x1
    mov [ebp + wTrainerNo], al
    mov esi, OaksLabRivalIPickedTheWrongPokemonText
    mov edx, OaksLabRivalAmIGreatOrWhatText   ; pret: ld de, OaksLabRivalAmIGreatOrWhatText — SaveEndBattleTextPointers takes it in EDX
    call SaveEndBattleTextPointers
    mov esi, wStatusFlags3
    or byte [ebp + esi], (1 << (BIT_TALKED_TO_TRAINER))
    or byte [ebp + esi], (1 << (BIT_PRINT_END_BATTLE_TEXT))
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov al, PLAYER_DIR_UP
    mov [ebp + wPlayerMovingDirection], al
    mov al, SCRIPT_OAKSLAB_RIVAL_END_BATTLE
    mov [ebp + wOaksLabCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
OaksLabRivalEndBattleScript:
    mov al, PAD_BUTTONS | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, [ebp + wBattleResult]
    test al, al
    mov bh, 3
    jnz .got_rival_starter
    mov bh, 2
.got_rival_starter:
    mov al, bh
    mov [ebp + wRivalStarter], al
    mov al, PAD_SELECT | PAD_START | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, PLAYER_DIR_UP
    mov [ebp + wPlayerMovingDirection], al
    call UpdateSprites
    mov al, 1
    mov [ebp + wSpriteIndex], al
    call SetSpritePosition1
    mov al, 0x2
    mov [ebp + wSprite01StateData1MovementStatus], al
    xor al, al
    mov [ebp + wSprite01StateData1FacingDirection], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call HealParty
    SetEvent EVENT_BATTLED_RIVAL_IN_OAKS_LAB
    mov al, SCRIPT_OAKSLAB_RIVAL_STARTS_EXIT
    mov [ebp + wOaksLabCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
OaksLabRivalStartsExitScript:
    mov bl, 20
    call DelayFrames
    mov al, TEXT_OAKSLAB_RIVAL_SMELL_YOU_LATER
    mov [ebp + hTextID], al
    call DisplayTextID
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call Music_RivalAlternateStart
    mov al, 1
    mov [ebp + hSpriteIndex], al
    mov edi, .RivalExitMovement   ; pret: ld de, .RivalExitMovement — MoveSprite takes it in EDI
    call MoveSprite
    mov al, [ebp + wXCoord]
    cmp al, 4
    jnz .moveLeft
    mov al, NPC_MOVEMENT_RIGHT
    jmp .next

%assign event_byte -1
%assign event_byte_a -1
.moveLeft:
    mov al, NPC_MOVEMENT_LEFT
.next:
    mov [ebp + wNPCMovementDirections], al
    mov al, SCRIPT_OAKSLAB_PLAYER_WATCH_RIVAL_EXIT
    mov [ebp + wOaksLabCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
.RivalExitMovement:
    db NPC_CHANGE_FACING
    db NPC_MOVEMENT_DOWN
    db 0x04
    db 0x04
    db 0x04
    db 0x04
    db 0x04
    db -1

%assign event_byte -1
%assign event_byte_a -1
OaksLabPlayerWatchRivalExitScript:
    mov al, [ebp + wStatusFlags5]
    test al, (1 << (BIT_SCRIPTED_NPC_MOVEMENT))
    jnz .checkRivalPosition
    mov al, PAD_SELECT | PAD_START | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, TOGGLE_OAKS_LAB_RIVAL
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
    call PlayDefaultMusic
    mov al, SCRIPT_OAKSLAB_PIKACHU_ESCAPES_POKEBALL
    mov [ebp + wOaksLabCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
.checkRivalPosition:
    mov al, [ebp + wNPCNumScriptedSteps]
    cmp al, 0x5
    jnz .turnPlayerDown
    mov al, [ebp + wXCoord]
    cmp al, 4
    jnz .turnPlayerLeft
    mov al, SPRITE_FACING_RIGHT
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.turnPlayerLeft:
    mov al, SPRITE_FACING_LEFT
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.turnPlayerDown:
    cmp al, 0x4
    jz .nr_466
        ret
.nr_466:
    xor al, al
.done:
    mov [ebp + wSpritePlayerStateData1FacingDirection], al
    ret

%assign event_byte -1
%assign event_byte_a -1
OaksLabPikachuEscapesPokeballScript:
    mov al, SPRITE_FACING_UP
    mov [ebp + wSpritePlayerStateData1FacingDirection], al
    mov al, 0x2
    mov [ebp + wPikachuSpawnState], al
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call SchedulePikachuSpawnForAfterText
    call EnablePikachuOverworldSpriteDrawing
    mov al, TEXT_OAKSLAB_PIKACHU_DISLIKES_POKEBALLS1
    mov [ebp + hTextID], al
    call DisplayTextID
    mov al, SCRIPT_OAKSLAB_PIKACHU_DISLIKES_POKEBALLS
    mov [ebp + wOaksLabCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
OaksLabPikachuDislikesPokeballsScript:
    mov al, TEXT_OAKSLAB_PIKACHU_DISLIKES_POKEBALLS2
    mov [ebp + hTextID], al
    call DisplayTextID
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov al, SCRIPT_OAKSLAB_NOOP
    mov [ebp + wOaksLabCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
; HL domain: GB. The only value loaded into HL in this region is
; `ld hl, wNPCMovementDirections2` (pret :516), a WRAM address, and the
; dereference the bail flagged (pret :518 `ld [hl], $ff`) is the next use of it
; after FillMemory. There is no other path into this label.
OaksLabRivalArrivesAtOaksRequestScript:
    xor al, al
    mov [ebp + hJoyHeld], al
    call EnableAutoTextBoxDrawing
    call StopAllMusic
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call Music_RivalAlternateStart
    mov al, TEXT_OAKSLAB_RIVAL_GRAMPS
    mov [ebp + hTextID], al
    call DisplayTextID
; DEVIATION{class=banking; pret=macros/farcall.asm:callfar; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call OaksLabPikachuMovementScript
    call OaksLabCalcRivalMovementScript
    mov al, TOGGLE_OAKS_LAB_RIVAL                               ; TOGGLE_OAKS_LAB_RIVAL ($2B)
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call ShowObject
    mov al, [ebp + wNPCMovementDirections2Index]
    mov [ebp + wSavedNPCMovementDirections2Index], al
    mov bh, 0                                ; ld b, 0
    mov bl, al                               ; ld c, a
    mov esi, wNPCMovementDirections2
    mov al, NPC_MOVEMENT_UP
    call FillMemory
    ; pret's FillMemory leaves HL at start+count (`ld [hli], a`, home/copy2.asm:150);
    ; the PORT's PRESERVES ESI by design (src/home/copy2.asm:184 "Out: ESI/EBX/EAX
    ; unchanged"), so the terminator address is re-formed here. Without this the
    ; `ld [hl], $ff` would overwrite the FIRST direction byte instead of appending.
    movzx ecx, bx
    add esi, ecx
    mov byte [ebp + esi], 0xff
    mov al, 1                                ; OAKSLAB_RIVAL
    mov [ebp + hSpriteIndex], al
    lea edi, [ebp + wNPCMovementDirections2] ; pret: ld de — MoveSprite takes a FLAT pointer in EDI
    call MoveSprite

    mov al, SCRIPT_OAKSLAB_OAK_GIVES_POKEDEX
    mov [ebp + wOaksLabCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
OaksLabRivalFaceUpOakFaceDownScript:
    mov al, 1
    mov [ebp + hSpriteIndex], al
    mov al, SPRITE_FACING_UP
    mov [ebp + hSpriteFacingDirection], al
    call SetSpriteFacingDirectionAndDelay
    mov al, 6
    mov [ebp + hSpriteIndex], al
    xor al, al
    mov [ebp + hSpriteFacingDirection], al
    call SetSpriteFacingDirectionAndDelay
    ret

%assign event_byte -1
%assign event_byte_a -1
; HL domain: GB. The only value loaded into HL in this region is
; `ld hl, wNPCMovementDirections2` (pret :601), a WRAM address, and the
; dereference the bail flagged (pret :603 `ld [hl], $ff`) is the next use of it
; after FillMemory. There is no other path into this label. (The SetEvent macros
; own their own HL; they do not leave it live across this point.)
OaksLabOakGivesPokedexScript:
    mov al, [ebp + wStatusFlags5]
    test al, (1 << (BIT_SCRIPTED_NPC_MOVEMENT))
    jz .nr_544
        ret
.nr_544:
    call EnableAutoTextBoxDrawing
    call PlayDefaultMusic
    mov al, PAD_SELECT | PAD_START | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    call OaksLabRivalFaceUpOakFaceDownScript
    mov al, TEXT_OAKSLAB_RIVAL_MY_POKEMON_HAS_GROWN_STRONGER
    mov [ebp + hTextID], al
    call DisplayTextID
    call DelayFrame
    call OaksLabRivalFaceUpOakFaceDownScript
    mov al, TEXT_OAKSLAB_OAK_I_HAVE_A_REQUEST
    mov [ebp + hTextID], al
    call DisplayTextID
    call DelayFrame
    call OaksLabRivalFaceUpOakFaceDownScript
    mov al, TEXT_OAKSLAB_OAK_MY_INVENTION_POKEDEX
    mov [ebp + hTextID], al
    call DisplayTextID
    call DelayFrame
    mov al, TEXT_OAKSLAB_OAK_GOT_POKEDEX
    mov [ebp + hTextID], al
    call DisplayTextID
    call Delay3
    mov al, TOGGLE_POKEDEX_1                               ; TOGGLE_POKEDEX_1 ($2E)
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
    mov al, TOGGLE_POKEDEX_2                               ; TOGGLE_POKEDEX_2 ($2F)
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
    call OaksLabRivalFaceUpOakFaceDownScript
    mov al, TEXT_OAKSLAB_OAK_THAT_WAS_MY_DREAM
    mov [ebp + hTextID], al
    call DisplayTextID
    mov al, 1                                ; OAKSLAB_RIVAL
    mov [ebp + hSpriteIndex], al
    mov al, SPRITE_FACING_RIGHT
    mov [ebp + hSpriteFacingDirection], al
    call SetSpriteFacingDirectionAndDelay
    call Delay3
    mov al, TEXT_OAKSLAB_RIVAL_LEAVE_IT_ALL_TO_ME
    mov [ebp + hTextID], al
    call DisplayTextID
    SetEvent EVENT_GOT_POKEDEX
    mov al, SCRIPT_VIRIDIANCITY_AFTER_POKEDEX
    mov [ebp + wViridianCityCurScript], al
    SetEvent EVENT_OAK_GOT_PARCEL
    mov al, TOGGLE_LYING_OLD_MAN                                ; TOGGLE_LYING_OLD_MAN ($01)
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
    mov al, TOGGLE_OLD_MAN_2                                ; TOGGLE_OLD_MAN_2 ($03)
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call ShowObject
    mov al, [ebp + wSavedNPCMovementDirections2Index]
    mov bh, 0                                ; ld b, 0
    mov bl, al                               ; ld c, a
    mov esi, wNPCMovementDirections2
    xor al, al                               ; NPC_MOVEMENT_DOWN
    call FillMemory
    ; pret's FillMemory leaves HL at start+count (`ld [hli], a`, home/copy2.asm:150);
    ; the PORT's PRESERVES ESI by design (src/home/copy2.asm:184 "Out: ESI/EBX/EAX
    ; unchanged"), so the terminator address is re-formed here. Without this the
    ; `ld [hl], $ff` would overwrite the FIRST direction byte instead of appending.
    movzx ecx, bx
    add esi, ecx
    mov byte [ebp + esi], 0xff
    call StopAllMusic
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call Music_RivalAlternateStart
    mov al, 1                                ; OAKSLAB_RIVAL
    mov [ebp + hSpriteIndex], al
    lea edi, [ebp + wNPCMovementDirections2] ; pret: ld de — MoveSprite takes a FLAT pointer in EDI
    call MoveSprite

    mov al, SCRIPT_OAKSLAB_RIVAL_LEAVES_WITH_POKEDEX
    mov [ebp + wOaksLabCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
OaksLabRivalLeavesWithPokedexScript:
    mov al, [ebp + wStatusFlags5]
    test al, (1 << (BIT_SCRIPTED_NPC_MOVEMENT))
    jz .nr_618
        ret
.nr_618:
    call PlayDefaultMusic
    mov al, TOGGLE_OAKS_LAB_RIVAL
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
    SetEvent EVENT_1ST_ROUTE22_RIVAL_BATTLE
    ResetEventReuseHL EVENT_2ND_ROUTE22_RIVAL_BATTLE
    SetEventReuseHL EVENT_ROUTE22_RIVAL_WANTS_BATTLE
    mov al, TOGGLE_ROUTE_22_RIVAL_1
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call ShowObject
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov al, SCRIPT_OAKSLAB_NOOP
    mov [ebp + wOaksLabCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
OaksLabNoopScript:
    ret

%assign event_byte -1
%assign event_byte_a -1
OaksLabScript_RemoveParcel:
    mov esi, wBagItems
    mov bx, 0
.loop:
    mov al, [ebp + esi]
    lea esi, [esi+1]
    cmp al, 0xff
    jnz .nr_645
        ret
.nr_645:
    cmp al, 70
    jz .foundParcel
    lea esi, [esi+1]
    inc bl
    jmp .loop

%assign event_byte -1
%assign event_byte_a -1
.foundParcel:
    mov esi, wNumBagItems
    mov al, bl
    mov [ebp + wWhichPokemon], al
    mov al, 1
    mov [ebp + wItemQuantity], al
    call RemoveItemFromInventory
    ret

%assign event_byte -1
%assign event_byte_a -1
OaksLabCalcRivalMovementScript:
    mov al, 0x7c
    mov [ebp + hSpriteScreenYCoord], al
    mov al, 8
    mov [ebp + hSpriteMapXCoord], al
    mov al, [ebp + wYCoord]
    cmp al, 3
    jnz .not_below_oak
    mov al, 0x4
    mov [ebp + wNPCMovementDirections2Index], al
    mov al, 0x30
    mov bh, 11
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.not_below_oak:
    cmp al, 1
    jnz .not_above_oak
    mov al, 0x2
    mov [ebp + wNPCMovementDirections2Index], al
    mov al, 0x30
    mov bh, 9
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.not_above_oak:
    mov al, 0x3
    mov [ebp + wNPCMovementDirections2Index], al
    mov bh, 10
    mov al, [ebp + wXCoord]
    cmp al, 4
    jnz .not_left_of_oak
    mov al, 0x40
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.not_left_of_oak:
    mov al, 0x20
.done:
    mov [ebp + hSpriteScreenXCoord], al
    mov al, bh
    mov [ebp + hSpriteMapYCoord], al
    mov al, 1
    mov [ebp + wSpriteIndex], al
    call SetSpritePosition1
    ret

%assign event_byte -1
%assign event_byte_a -1
; `ld a, l` / `ld a, h` on a flat program pointer: same idiom, same callee
; contract, as the already-emitted ViridianMartCheckParcelDeliveredScript
; (src/scripts/viridian_mart.asm:90-94). wCurMapTextPtr stays pret's 2-byte GB
; field and receives the low 16 bits; the port does not dereference it as a GB
; pointer (src/home/text_script.asm:126-138, home/predef_text.asm:8).
OaksLabLoadTextPointers2Script:
    mov esi, OaksLab_TextPointers2
    mov eax, esi   ; pret: ld a, l / ld a, h — ESI holds HL
    mov [ebp + wCurMapTextPtr], al
    mov [ebp + wCurMapTextPtr + 1], ah
    mov al, ah     ; pret: at ret, a holds h
    ret

%assign event_byte -1
%assign event_byte_a -1
OaksLab_TextPointers:
    dd OaksLabRivalText
    dd OaksLabEeveePokeBallText
    dd OaksLabOak1Text
    dd OaksLabPokedexText
    dd OaksLabPokedexText
    dd OaksLabOak2Text
    dd OaksLabGirlText
    dd OaksLabScientistText
    dd OaksLabScientistText
    dd OaksLabOakDontGoAwayYetText
    dd OaksLabRivalIllTakeYouOnText
    dd OaksLabRivalSmellYouLaterText
    dd OaksLabRivalFedUpWithWaitingText
    dd OaksLabOakChooseMonText
    dd OaksLabRivalWhatAboutMeText
    dd OaksLabOakBePatientText
    dd OaksLabRivalReceivedMonText
    dd OaksLabPlayerReceivedMonText
    dd OaksLabRivalGrampsText
    dd OaksLabRivalMyPokemonHasGrownStrongerText
    dd OaksLabOakIHaveARequestText
    dd OaksLabOakMyInventionPokedexText
    dd OaksLabOakGotPokedexText
    dd OaksLabOakThatWasMyDreamText
    dd OaksLabRivalLeaveItAllToMeText
    dd OaksLabPikachuDislikesPokeballsText1
    dd OaksLabPikachuDislikesPokeballsText2
OaksLab_TextPointers2:
    dd OaksLabRivalText
    dd OaksLabEeveePokeBallText
    dd OaksLabOak1Text
    dd OaksLabPokedexText
    dd OaksLabPokedexText
    dd OaksLabOak2Text
    dd OaksLabGirlText
    dd OaksLabScientistText
    dd OaksLabScientistText

%assign event_byte -1
%assign event_byte_a -1
OaksLabRivalText:
    CheckEvent EVENT_FOLLOWED_OAK_INTO_LAB_2
    jnz .beforeChooseMon
    mov esi, .GrampsIsntAroundText
    call PrintText
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.beforeChooseMon:
    CheckEventReuseA EVENT_GOT_STARTER
    jnz .afterChooseMon
    mov esi, .IllGetABetterPokemonThanYou
    call PrintText
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.afterChooseMon:
    mov esi, .MyPokemonLooksStrongerText
    call PrintText
.done:
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.GrampsIsntAroundText:
    text_far _OaksLabRivalGrampsIsntAroundText
    text_end
.IllGetABetterPokemonThanYou:
    text_far _OaksLabRivalIllGetABetterPokemonThanYou
    text_end
.MyPokemonLooksStrongerText:
    text_far _OaksLabRivalMyPokemonLooksStrongerText
    text_end

%assign event_byte -1
%assign event_byte_a -1
OaksLabEeveePokeBallText:
    mov al, 0x1
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    CheckEvent EVENT_OAK_ASKED_TO_CHOOSE_MON
    jnz OaksLabRivalExclamationScript
    mov al, 0x0
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    mov esi, .Text
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.Text:
    text_far _OaksLabThatsAPokeball
    text_end

%assign event_byte -1
%assign event_byte_a -1
OaksLabRivalExclamationScript:
    mov al, 1
    mov [ebp + wEmotionBubbleSpriteIndex], al
    xor al, al
    mov [ebp + wWhichEmotionBubble], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call EmotionBubble
    mov al, SCRIPT_OAKSLAB_CHOSE_STARTER_SCRIPT
    mov [ebp + wOaksLabCurScript], al
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
OaksLabOak1Text:
    CheckEvent EVENT_PALLET_AFTER_GETTING_POKEBALLS
    jnz .already_got_poke_balls
    mov esi, wPokedexOwned
    mov bh, wPokedexOwnedEnd - wPokedexOwned
    call CountSetBits
    mov al, [ebp + wNumSetBits]
    cmp al, 2
    jb .check_for_poke_balls
.already_got_poke_balls:
    mov esi, .HowIsYourPokedexComingText
    call PrintText
    mov al, 0x1
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call DisplayDexRating
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.check_for_poke_balls:
    mov bh, POKE_BALL
    call IsItemInBag
    jnz .come_see_me_sometimes
    mov esi, wPokedexOwned
    mov bh, wPokedexOwnedEnd - wPokedexOwned
    call CountSetBits
    mov al, [ebp + wNumSetBits]
    cmp al, 2
    jae .come_see_me_sometimes
    CheckEvent EVENT_BEAT_ROUTE22_RIVAL_1ST_BATTLE
    jnz .give_poke_balls
    CheckEvent EVENT_GOT_POKEDEX
    jnz .mon_around_the_world
    CheckEventReuseA EVENT_BATTLED_RIVAL_IN_OAKS_LAB
    jnz .check_got_parcel
    mov al, [ebp + wStatusFlags4]
    test al, (1 << (BIT_GOT_STARTER))
    jnz .already_got_pokemon
    mov esi, .GoAheadItsYours
    call PrintText
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.already_got_pokemon:
    mov esi, .YourPokemonCanFightText
    call PrintText
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.check_got_parcel:
    mov bh, 70
    call IsItemInBag
    jnz .got_parcel
    mov esi, .YouShouldTalkToIt
    call PrintText
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.got_parcel:
    mov esi, .DeliverParcelText
    call PrintText
    call OaksLabScript_RemoveParcel
    mov al, SCRIPT_OAKSLAB_RIVAL_ARRIVES_AT_OAKS_REQUEST
    mov [ebp + wOaksLabCurScript], al
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.mon_around_the_world:
    mov esi, .PokemonAroundTheWorldText
    call PrintText
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.give_poke_balls:
    CheckAndSetEvent EVENT_GOT_POKEBALLS_FROM_OAK
    jnz .come_see_me_sometimes
    mov bx, ((POKE_BALL) << 8) | (5)
    call GiveItem
    mov esi, .GivePokeballsText
    call PrintText
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.come_see_me_sometimes:
    mov esi, .ComeSeeMeSometimesText
    call PrintText
.done:
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.GoAheadItsYours:
    text_far _OaksLabOak1GoAheadItsYours
    text_end
.YourPokemonCanFightText:
    text_far _OaksLabOak1YourPokemonCanFightText
    text_end
.YouShouldTalkToIt:
    text_far _OaksLabOak1YouShouldTalkToIt
    text_end
.DeliverParcelText:
    text_far _OaksLabOak1DeliverParcelText
    sound_get_key_item
    text_far _OaksLabOak1ParcelThanksText
    text_end
.PokemonAroundTheWorldText:
    text_far _OaksLabOak1PokemonAroundTheWorldText
    text_end
.GivePokeballsText:
    text_far _OaksLabOak1ReceivedPokeballsText
    sound_get_key_item
    text_far _OaksLabGivePokeballsExplanationText
    text_end
.ComeSeeMeSometimesText:
    text_far _OaksLabOak1ComeSeeMeSometimesText
    text_end
.HowIsYourPokedexComingText:
    text_far _OaksLabOak1HowIsYourPokedexComingText
    text_end

%assign event_byte -1
%assign event_byte_a -1
OaksLabPokedexText:
    mov esi, .Text
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.Text:
    text_far _OaksLabPokedexText
    text_end
OaksLabOak2Text:
    text_far _OaksLabOak2Text
    text_end

%assign event_byte -1
%assign event_byte_a -1
OaksLabGirlText:
    mov esi, .Text
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.Text:
    text_far _OaksLabGirlText
    text_end

%assign event_byte -1
%assign event_byte_a -1
OaksLabRivalFedUpWithWaitingText:
    mov esi, .Text
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.Text:
    text_far _OaksLabRivalFedUpWithWaitingText
    text_end

%assign event_byte -1
%assign event_byte_a -1
OaksLabOakChooseMonText:
    mov esi, .Text
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.Text:
    text_far _OaksLabOakChooseMonText
    text_end

%assign event_byte -1
%assign event_byte_a -1
OaksLabRivalWhatAboutMeText:
    mov esi, .Text
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.Text:
    text_far _OaksLabRivalWhatAboutMeText
    text_end

%assign event_byte -1
%assign event_byte_a -1
OaksLabOakBePatientText:
    mov esi, .Text
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.Text:
    text_far _OaksLabOakBePatientText
    text_end

%assign event_byte -1
%assign event_byte_a -1
OaksLabRivalReceivedMonText:
    mov esi, OaksLabRivalTakesText1
    call PrintText
    mov esi, OaksLabRivalTakesText2
    call PrintText
    mov esi, OaksLabRivalTakesText3
    call PrintText
    mov esi, OaksLabRivalTakesText4
    call PrintText
    mov esi, OaksLabRivalTakesText5
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
OaksLabRivalTakesText1:
    text_far _OaksLabRivalTakesText1
    text_end
OaksLabRivalTakesText2:
    text_far _OaksLabRivalTakesText2
    sound_get_key_item
    text_end
OaksLabRivalTakesText3:
    text_far _OaksLabRivalTakesText3
    text_end
OaksLabRivalTakesText4:
    text_far _OaksLabRivalTakesText4
    text_end
OaksLabRivalTakesText5:
    text_far _OaksLabRivalTakesText5
    text_end

%assign event_byte -1
%assign event_byte_a -1
OaksLabPlayerReceivedMonText:
    mov al, STARTER_PIKACHU
    mov [ebp + wPlayerStarter], al
    mov [ebp + wNamedObjectIndex], al
    call GetMonName
    mov al, 0x1
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    mov esi, OaksLabOakGivesText
    call PrintText
    mov esi, OaksLabReceivedText
    call PrintText
    xor al, al
    mov [ebp + wMonDataLocation], al
    mov al, 5
    mov [ebp + wCurEnemyLevel], al
    mov al, STARTER_PIKACHU
    mov [ebp + wPokedexNum], al
    mov [ebp + wCurPartySpecies], al
    call AddPartyMon
    mov al, 163
    mov [ebp + wPartyMon1CatchRate], al
    call DisablePikachuOverworldSpriteDrawing
    SetEvent EVENT_GOT_STARTER
    mov esi, wStatusFlags4
    or byte [ebp + esi], (1 << (BIT_GOT_STARTER))
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
OaksLabOakGivesText:
    text_far _OaksLabOakGivesText
    text_end
OaksLabReceivedText:
    text_far _OaksLabReceivedText
    sound_get_key_item
    text_end

%assign event_byte -1
%assign event_byte_a -1
OaksLabOakDontGoAwayYetText:
    mov esi, .Text
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.Text:
    text_far _OaksLabOakDontGoAwayYetText
    text_end

%assign event_byte -1
%assign event_byte_a -1
OaksLabRivalIllTakeYouOnText:
    mov esi, .Text
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.Text:
    text_far _OaksLabRivalIllTakeYouOnText
    text_end
OaksLabRivalIPickedTheWrongPokemonText:
    text_far _OaksLabRivalIPickedTheWrongPokemonText
    text_end
OaksLabRivalAmIGreatOrWhatText:
    text_far _OaksLabRivalAmIGreatOrWhatText
    text_end

%assign event_byte -1
%assign event_byte_a -1
OaksLabRivalSmellYouLaterText:
    mov esi, .Text
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.Text:
    text_far _OaksLabRivalSmellYouLaterText
    text_end

%assign event_byte -1
%assign event_byte_a -1
OaksLabPikachuDislikesPokeballsText1:
; ldpikacry lowers to a LITERAL: pret's macro is `(X_id - PikachuCriesPointerTable) / 3`,
; a cross-object-file difference NASM cannot fold. It does not need to — measured
; against audio/pikachu_cries_pointers.asm, the table is strictly ordinal across all
; 42 entries (zero violations), so PikachuCryN is index N-1. Same lowering the port
; already uses at celadon_mansion_1f.asm:98 for PikachuCry23 -> 22.
    mov dl, 1                                     ; ldpikacry e, PikachuCry2 (0-based clip index)
; DEVIATION{class=banking; pret=macros/farcall.asm:callfar; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call PlayPikachuSoundClip                     ; callfar PlayPikachuSoundClip
    mov esi, OaksLabPikachuDislikesPokeballsText1.Text ; ld hl, .Text
    call PrintText                                ; call PrintText
    jmp TextScriptEnd                             ; jp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
; The pret name is kept EXACTLY — `OaksLabPikachuDislikesPokeballsText1.Text` —
; but written out in full rather than as a bare `.Text:`. NASM binds a bare local
; to the last non-local label above it, which here is OaksLabRivalSmellYouLaterText
; (OaksLabPikachuDislikesPokeballsText1 itself is a deliberate pikachu-table-index
; refusal a few lines up and defines no symbol), and
; OaksLabRivalSmellYouLaterText.Text already exists — that is the collision. The
; explicit qualification names the pret symbol unambiguously without renaming it.
OaksLabPikachuDislikesPokeballsText1.Text:
    text_far _OaksLabPikachuDislikesPokeballsText1
    text_end

%assign event_byte -1
%assign event_byte_a -1
OaksLabPikachuDislikesPokeballsText2:
    mov esi, .Text
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.Text:
    text_far _OaksLabPikachuDislikesPokeballsText2
    text_end
OaksLabRivalGrampsText:
    text_far _OaksLabRivalGrampsText
    text_end
OaksLabRivalMyPokemonHasGrownStrongerText:
    text_far _OaksLabRivalMyPokemonHasGrownStrongerText
    text_end
OaksLabOakIHaveARequestText:
    text_far _OaksLabOakIHaveARequestText
    text_end
OaksLabOakMyInventionPokedexText:
    text_far _OaksLabOakMyInventionPokedexText
    text_end
OaksLabOakGotPokedexText:
    text_far _OaksLabOakGotPokedexText
    sound_get_key_item
    text_end
OaksLabOakThatWasMyDreamText:
    text_far _OaksLabOakThatWasMyDreamText
    text_end
OaksLabRivalLeaveItAllToMeText:
    text_far _OaksLabRivalLeaveItAllToMeText
    text_end

%assign event_byte -1
%assign event_byte_a -1
OaksLabScientistText:
    mov esi, .Text
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.Text:
    text_far _OaksLabScientistText
    text_end

%assign event_byte -1
%assign event_byte_a -1
OaksLabPikachuMovementScript:
    mov al, [ebp + wYCoord]
    cmp al, 3
    jz .movement2
    mov bh, SPRITE_FACING_DOWN
    mov esi, OaksLabPikachuMovementData1
    call TryApplyPikachuMovementData
    ret

%assign event_byte -1
%assign event_byte_a -1
.movement2:
    mov bh, SPRITE_FACING_LEFT
    mov esi, OaksLabPikachuMovementData2
    call TryApplyPikachuMovementData
    ret

%assign event_byte -1
%assign event_byte_a -1
OaksLabPikachuMovementData1:
    db 0x00
    db 0x1f
    db 0x1e
    db 0x38
    db 0x3f
OaksLabPikachuMovementData2:
    db 0x00
    db 0x1d
    db 0x20
    db 0x36
    db 0x3f
