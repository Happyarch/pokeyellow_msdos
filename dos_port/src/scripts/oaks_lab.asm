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

%include "assets/audio_constants.inc"
%include "assets/pika_pcm.inc"

global OakEntryMovement
global OaksLabCalcRivalMovementScript
global OaksLabChoseStarterScript
global OaksLabDefaultScript
global OaksLabEeveePokeBallText
global OaksLabFollowedOakScript
global OaksLabGirlText
global OaksLabNoopScript
global OaksLabOak2Text
global OaksLabOakBePatientText
global OaksLabOakChooseMonSpeechScript
global OaksLabOakChooseMonText
global OaksLabOakDontGoAwayYetText
global OaksLabOakEntersLabScript
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
extern OaksLabLoadTextPointers2Script   ; NOT YET DEFINED IN THE PORT
extern OaksLabOak1Text   ; NOT YET DEFINED IN THE PORT
extern OaksLabOakGivesPokedexScript   ; NOT YET DEFINED IN THE PORT
extern OaksLabPikachuDislikesPokeballsText1   ; NOT YET DEFINED IN THE PORT
extern OaksLabRivalArrivesAtOaksRequestScript   ; NOT YET DEFINED IN THE PORT
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
extern _OaksLabGirlText   ; NOT YET DEFINED IN THE PORT
extern _OaksLabGivePokeballsExplanationText   ; NOT YET DEFINED IN THE PORT
extern _OaksLabOak1ComeSeeMeSometimesText   ; NOT YET DEFINED IN THE PORT
extern _OaksLabOak1DeliverParcelText   ; NOT YET DEFINED IN THE PORT
extern _OaksLabOak1GoAheadItsYours   ; NOT YET DEFINED IN THE PORT
extern _OaksLabOak1HowIsYourPokedexComingText   ; NOT YET DEFINED IN THE PORT
extern _OaksLabOak1ParcelThanksText   ; NOT YET DEFINED IN THE PORT
extern _OaksLabOak1PokemonAroundTheWorldText   ; NOT YET DEFINED IN THE PORT
extern _OaksLabOak1ReceivedPokeballsText   ; NOT YET DEFINED IN THE PORT
extern _OaksLabOak1YouShouldTalkToIt   ; NOT YET DEFINED IN THE PORT
extern _OaksLabOak1YourPokemonCanFightText   ; NOT YET DEFINED IN THE PORT
extern _OaksLabOak2Text   ; NOT YET DEFINED IN THE PORT
extern _OaksLabOakBePatientText   ; NOT YET DEFINED IN THE PORT
extern _OaksLabOakChooseMonText   ; NOT YET DEFINED IN THE PORT
extern _OaksLabOakDontGoAwayYetText   ; NOT YET DEFINED IN THE PORT
extern _OaksLabOakGivesText   ; NOT YET DEFINED IN THE PORT
extern _OaksLabOakGotPokedexText   ; NOT YET DEFINED IN THE PORT
extern _OaksLabOakIHaveARequestText   ; NOT YET DEFINED IN THE PORT
extern _OaksLabOakMyInventionPokedexText   ; NOT YET DEFINED IN THE PORT
extern _OaksLabOakThatWasMyDreamText   ; NOT YET DEFINED IN THE PORT
extern _OaksLabPikachuDislikesPokeballsText1   ; NOT YET DEFINED IN THE PORT
extern _OaksLabPikachuDislikesPokeballsText2   ; NOT YET DEFINED IN THE PORT
extern _OaksLabPokedexText   ; NOT YET DEFINED IN THE PORT
extern _OaksLabReceivedText   ; NOT YET DEFINED IN THE PORT
extern _OaksLabRivalAmIGreatOrWhatText   ; NOT YET DEFINED IN THE PORT
extern _OaksLabRivalFedUpWithWaitingText   ; NOT YET DEFINED IN THE PORT
extern _OaksLabRivalGrampsIsntAroundText   ; NOT YET DEFINED IN THE PORT
extern _OaksLabRivalGrampsText   ; NOT YET DEFINED IN THE PORT
extern _OaksLabRivalIPickedTheWrongPokemonText   ; NOT YET DEFINED IN THE PORT
extern _OaksLabRivalIllGetABetterPokemonThanYou   ; NOT YET DEFINED IN THE PORT
extern _OaksLabRivalIllTakeYouOnText   ; NOT YET DEFINED IN THE PORT
extern _OaksLabRivalLeaveItAllToMeText   ; NOT YET DEFINED IN THE PORT
extern _OaksLabRivalMyPokemonHasGrownStrongerText   ; NOT YET DEFINED IN THE PORT
extern _OaksLabRivalMyPokemonLooksStrongerText   ; NOT YET DEFINED IN THE PORT
extern _OaksLabRivalSmellYouLaterText   ; NOT YET DEFINED IN THE PORT
extern _OaksLabRivalTakesText1   ; NOT YET DEFINED IN THE PORT
extern _OaksLabRivalTakesText2   ; NOT YET DEFINED IN THE PORT
extern _OaksLabRivalTakesText3   ; NOT YET DEFINED IN THE PORT
extern _OaksLabRivalTakesText4   ; NOT YET DEFINED IN THE PORT
extern _OaksLabRivalTakesText5   ; NOT YET DEFINED IN THE PORT
extern _OaksLabRivalWhatAboutMeText   ; NOT YET DEFINED IN THE PORT
extern _OaksLabScientistText   ; NOT YET DEFINED IN THE PORT
extern _OaksLabThatsAPokeball   ; NOT YET DEFINED IN THE PORT

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

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
hSpriteFacingDirection                         equ 0xFF8D
hSpriteMapXCoord                               equ 0xFFEE
hSpriteMapYCoord                               equ 0xFFED
hSpriteScreenXCoord                            equ 0xFFEC
hSpriteScreenYCoord                            equ 0xFFEB
wOaksLabCurScript                              equ 0xD5EF
wPartyMon1CatchRate                            equ 0xD171
wPlayerStarter                                 equ 0xD716
wSavedNPCMovementDirections2Index              equ 0xD156
wSprite01StateData1FacingDirection             equ 0xC119
wSprite01StateData1MovementStatus              equ 0xC111
wSpritePlayerStateData1FacingDirection         equ 0xC109
wViridianCityCurScript                         equ 0xD5F3

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
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
    mov al, 48
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
    mov al, 48
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
    mov al, 45
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
    mov al, 44
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
    mov al, 102
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
    mov al, 43
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

; ---------------------------------------------------------------------------
; BAIL[pointer-domain-unknown] OaksLabRivalArrivesAtOaksRequestScript (scripts/OaksLab.asm:498-526) — at scripts/OaksLab.asm:518: HL domain is top at a dereference
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	xor a
; PRET| 	ldh [hJoyHeld], a
; PRET| 	call EnableAutoTextBoxDrawing
; PRET| 	call StopAllMusic
; PRET| 	farcall Music_RivalAlternateStart
; PRET| 	ld a, TEXT_OAKSLAB_RIVAL_GRAMPS
; PRET| 	ldh [hTextID], a
; PRET| 	call DisplayTextID
; PRET| 	callfar OaksLabPikachuMovementScript
; PRET| 	call OaksLabCalcRivalMovementScript
; PRET| 	ld a, TOGGLE_OAKS_LAB_RIVAL
; PRET| 	ld [wToggleableObjectIndex], a
; PRET| 	predef ShowObject
; PRET| 	ld a, [wNPCMovementDirections2Index]
; PRET| 	ld [wSavedNPCMovementDirections2Index], a
; PRET| 	ld b, 0
; PRET| 	ld c, a
; PRET| 	ld hl, wNPCMovementDirections2
; PRET| 	ld a, NPC_MOVEMENT_UP
; PRET| 	call FillMemory
; PRET| 	ld [hl], $ff
; PRET| 	ld a, OAKSLAB_RIVAL
; PRET| 	ldh [hSpriteIndex], a
; PRET| 	ld de, wNPCMovementDirections2
; PRET| 	call MoveSprite
; PRET| 
; PRET| 	ld a, SCRIPT_OAKSLAB_OAK_GIVES_POKEDEX
; PRET| 	ld [wOaksLabCurScript], a
; PRET| 	ret

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

; ---------------------------------------------------------------------------
; BAIL[pointer-domain-unknown] OaksLabOakGivesPokedexScript (scripts/OaksLab.asm:542-613) — at scripts/OaksLab.asm:603: HL domain is top at a dereference
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wStatusFlags5]
; PRET| 	bit BIT_SCRIPTED_NPC_MOVEMENT, a
; PRET| 	ret nz
; PRET| 	call EnableAutoTextBoxDrawing
; PRET| 	call PlayDefaultMusic
; PRET| 	ld a, PAD_SELECT | PAD_START | PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 	call OaksLabRivalFaceUpOakFaceDownScript
; PRET| 	ld a, TEXT_OAKSLAB_RIVAL_MY_POKEMON_HAS_GROWN_STRONGER
; PRET| 	ldh [hTextID], a
; PRET| 	call DisplayTextID
; PRET| 	call DelayFrame
; PRET| 	call OaksLabRivalFaceUpOakFaceDownScript
; PRET| 	ld a, TEXT_OAKSLAB_OAK_I_HAVE_A_REQUEST
; PRET| 	ldh [hTextID], a
; PRET| 	call DisplayTextID
; PRET| 	call DelayFrame
; PRET| 	call OaksLabRivalFaceUpOakFaceDownScript
; PRET| 	ld a, TEXT_OAKSLAB_OAK_MY_INVENTION_POKEDEX
; PRET| 	ldh [hTextID], a
; PRET| 	call DisplayTextID
; PRET| 	call DelayFrame
; PRET| 	ld a, TEXT_OAKSLAB_OAK_GOT_POKEDEX
; PRET| 	ldh [hTextID], a
; PRET| 	call DisplayTextID
; PRET| 	call Delay3
; PRET| 	ld a, TOGGLE_POKEDEX_1
; PRET| 	ld [wToggleableObjectIndex], a
; PRET| 	predef HideObject
; PRET| 	ld a, TOGGLE_POKEDEX_2
; PRET| 	ld [wToggleableObjectIndex], a
; PRET| 	predef HideObject
; PRET| 	call OaksLabRivalFaceUpOakFaceDownScript
; PRET| 	ld a, TEXT_OAKSLAB_OAK_THAT_WAS_MY_DREAM
; PRET| 	ldh [hTextID], a
; PRET| 	call DisplayTextID
; PRET| 	ld a, OAKSLAB_RIVAL
; PRET| 	ldh [hSpriteIndex], a
; PRET| 	ld a, SPRITE_FACING_RIGHT
; PRET| 	ldh [hSpriteFacingDirection], a
; PRET| 	call SetSpriteFacingDirectionAndDelay
; PRET| 	call Delay3
; PRET| 	ld a, TEXT_OAKSLAB_RIVAL_LEAVE_IT_ALL_TO_ME
; PRET| 	ldh [hTextID], a
; PRET| 	call DisplayTextID
; PRET| 	SetEvent EVENT_GOT_POKEDEX
; PRET| 	ld a, SCRIPT_VIRIDIANCITY_AFTER_POKEDEX
; PRET| 	ld [wViridianCityCurScript], a
; PRET| 	SetEvent EVENT_OAK_GOT_PARCEL
; PRET| 	ld a, TOGGLE_LYING_OLD_MAN
; PRET| 	ld [wToggleableObjectIndex], a
; PRET| 	predef HideObject
; PRET| 	ld a, TOGGLE_OLD_MAN_2
; PRET| 	ld [wToggleableObjectIndex], a
; PRET| 	predef ShowObject
; PRET| 	ld a, [wSavedNPCMovementDirections2Index]
; PRET| 	ld b, 0
; PRET| 	ld c, a
; PRET| 	ld hl, wNPCMovementDirections2
; PRET| 	xor a ; NPC_MOVEMENT_DOWN
; PRET| 	call FillMemory
; PRET| 	ld [hl], $ff
; PRET| 	call StopAllMusic
; PRET| 	farcall Music_RivalAlternateStart
; PRET| 	ld a, OAKSLAB_RIVAL
; PRET| 	ldh [hSpriteIndex], a
; PRET| 	ld de, wNPCMovementDirections2
; PRET| 	call MoveSprite
; PRET| 
; PRET| 	ld a, SCRIPT_OAKSLAB_RIVAL_LEAVES_WITH_POKEDEX
; PRET| 	ld [wOaksLabCurScript], a
; PRET| 	ret

%assign event_byte -1
%assign event_byte_a -1
OaksLabRivalLeavesWithPokedexScript:
    mov al, [ebp + wStatusFlags5]
    test al, (1 << (BIT_SCRIPTED_NPC_MOVEMENT))
    jz .nr_618
        ret
.nr_618:
    call PlayDefaultMusic
    mov al, 43
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
    SetEvent EVENT_1ST_ROUTE22_RIVAL_BATTLE
    ResetEventReuseHL EVENT_2ND_ROUTE22_RIVAL_BATTLE
    SetEventReuseHL EVENT_ROUTE22_RIVAL_WANTS_BATTLE
    mov al, 35
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

; ---------------------------------------------------------------------------
; BAIL[hl-half-register-access] OaksLabLoadTextPointers2Script (scripts/OaksLab.asm:702-707) — at scripts/OaksLab.asm:703: `l` is a half of ESI and has no flag-safe 8-bit x86 form
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, OaksLab_TextPointers2
; PRET| 	ld a, l
; PRET| 	ld [wCurMapTextPtr], a
; PRET| 	ld a, h
; PRET| 	ld [wCurMapTextPtr + 1], a
; PRET| 	ret

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

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] OaksLabOak1Text (scripts/OaksLab.asm:809-823) — at scripts/OaksLab.asm:810: OaksLabOak1Text.already_got_poke_balls is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_PALLET_AFTER_GETTING_POKEBALLS
; PRET| 	jr nz, .already_got_poke_balls
; PRET| 	ld hl, wPokedexOwned
; PRET| 	ld b, wPokedexOwnedEnd - wPokedexOwned
; PRET| 	call CountSetBits
; PRET| 	ld a, [wNumSetBits]
; PRET| 	cp 2
; PRET| 	jr c, .check_for_poke_balls
; PRET| .already_got_poke_balls
; PRET| 	ld hl, .HowIsYourPokedexComingText
; PRET| 	call PrintText
; PRET| 	ld a, $1
; PRET| 	ld [wDoNotWaitForButtonPressAfterDisplayingText], a
; PRET| 	predef DisplayDexRating
; PRET| 	jp .done

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
    test al, (1 << (3))
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
    or byte [ebp + esi], (1 << (3))
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

; ---------------------------------------------------------------------------
; BAIL[pikachu-table-index] OaksLabPikachuDislikesPokeballsText1 (scripts/OaksLab.asm:1094-1098) — at scripts/OaksLab.asm:1094: ldpikacry needs (X_id - Table) / N across object files
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ldpikacry e, PikachuCry2
; PRET| 	callfar PlayPikachuSoundClip
; PRET| 	ld hl, .Text
; PRET| 	call PrintText
; PRET| 	jp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[local-label-scope-collision] OaksLabPikachuDislikesPokeballsText1.Text (scripts/OaksLab.asm:1101-1102)
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _OaksLabPikachuDislikesPokeballsText1
; PRET| 	text_end

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
