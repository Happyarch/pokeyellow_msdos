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
global OaksLabChoseStarterScript
global OaksLabDefaultScript
global OaksLabFollowedOakScript
global OaksLabNoopScript
global OaksLabOak2Text
global OaksLabOakChooseMonSpeechScript
global OaksLabOakEntersLabScript
global OaksLabPikachuDislikesPokeballsScript
global OaksLabPikachuEscapesPokeballScript
global OaksLabPikachuMovementData1
global OaksLabPikachuMovementData2
global OaksLabPikachuMovementScript
global OaksLabPlayerDontGoAwayScript
global OaksLabPlayerForcedToWalkBackScript
global OaksLabPlayerReceivedMonText
global OaksLabPlayerReceivesPikachuScript
global OaksLabRLE_PlayerWalksToOak
global OaksLabRivalEndBattleScript
global OaksLabRivalExclamationScript
global OaksLabRivalFaceUpOakFaceDownScript
global OaksLabRivalReceivedMonText
global OaksLabRivalStartBattleScript
global OaksLabRivalStartsExitScript
global OaksLabRivalTakesPokeballScript
global OaksLabScript_RemoveParcel
global OaksLabToggleOaksScript
global OaksLab_Script
global OaksLab_ScriptPointers
global OaksLab_TextPointers
global OaksLab_TextPointers2
global PlayerEntryMovementRLE

extern AddPartyMon   ; NOT YET DEFINED IN THE PORT
extern Bankswitch   ; NOT YET DEFINED IN THE PORT
extern CalcPositionOfPlayerRelativeToNPC   ; NOT YET DEFINED IN THE PORT
extern CallFunctionInTable   ; NOT YET DEFINED IN THE PORT
extern CountSetBits   ; NOT YET DEFINED IN THE PORT
extern DecodeRLEList   ; NOT YET DEFINED IN THE PORT
extern Delay3   ; NOT YET DEFINED IN THE PORT
extern DelayFrame   ; NOT YET DEFINED IN THE PORT
extern DelayFrames   ; NOT YET DEFINED IN THE PORT
extern DisablePikachuOverworldSpriteDrawing   ; NOT YET DEFINED IN THE PORT
extern DisplayDexRating   ; NOT YET DEFINED IN THE PORT
extern DisplayTextID   ; NOT YET DEFINED IN THE PORT
extern EmotionBubble   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EnablePikachuOverworldSpriteDrawing   ; NOT YET DEFINED IN THE PORT
extern FillMemory   ; NOT YET DEFINED IN THE PORT
extern FindPathToPlayer   ; NOT YET DEFINED IN THE PORT
extern GetMonName   ; NOT YET DEFINED IN THE PORT
extern GetSpritePosition1   ; NOT YET DEFINED IN THE PORT
extern GiveItem   ; NOT YET DEFINED IN THE PORT
extern HealParty   ; NOT YET DEFINED IN THE PORT
extern HideObject   ; NOT YET DEFINED IN THE PORT
extern IsItemInBag   ; NOT YET DEFINED IN THE PORT
extern MoveSprite   ; NOT YET DEFINED IN THE PORT
extern Music_RivalAlternateStart   ; NOT YET DEFINED IN THE PORT
extern OaksLabCalcRivalMovementScript   ; NOT YET DEFINED IN THE PORT
extern OaksLabEeveePokeBallText   ; NOT YET DEFINED IN THE PORT
extern OaksLabGirlText   ; NOT YET DEFINED IN THE PORT
extern OaksLabLoadTextPointers2Script   ; NOT YET DEFINED IN THE PORT
extern OaksLabOak1Text   ; NOT YET DEFINED IN THE PORT
extern OaksLabOakBePatientText   ; NOT YET DEFINED IN THE PORT
extern OaksLabOakChooseMonText   ; NOT YET DEFINED IN THE PORT
extern OaksLabOakDontGoAwayYetText   ; NOT YET DEFINED IN THE PORT
extern OaksLabOakGivesPokedexScript   ; NOT YET DEFINED IN THE PORT
extern OaksLabOakGivesText   ; NOT YET DEFINED IN THE PORT
extern OaksLabOakGotPokedexText   ; NOT YET DEFINED IN THE PORT
extern OaksLabOakIHaveARequestText   ; NOT YET DEFINED IN THE PORT
extern OaksLabOakMyInventionPokedexText   ; NOT YET DEFINED IN THE PORT
extern OaksLabOakThatWasMyDreamText   ; NOT YET DEFINED IN THE PORT
extern OaksLabPikachuDislikesPokeballsText1   ; NOT YET DEFINED IN THE PORT
extern OaksLabPikachuDislikesPokeballsText2   ; NOT YET DEFINED IN THE PORT
extern OaksLabPlayerEntersLabScript   ; NOT YET DEFINED IN THE PORT
extern OaksLabPlayerWalksToOakScript   ; NOT YET DEFINED IN THE PORT
extern OaksLabPlayerWatchRivalExitScript   ; NOT YET DEFINED IN THE PORT
extern OaksLabPokedexText   ; NOT YET DEFINED IN THE PORT
extern OaksLabReceivedText   ; NOT YET DEFINED IN THE PORT
extern OaksLabRivalAmIGreatOrWhatText   ; NOT YET DEFINED IN THE PORT
extern OaksLabRivalArrivesAtOaksRequestScript   ; NOT YET DEFINED IN THE PORT
extern OaksLabRivalChallengesPlayerScript   ; NOT YET DEFINED IN THE PORT
extern OaksLabRivalFedUpWithWaitingText   ; NOT YET DEFINED IN THE PORT
extern OaksLabRivalGrampsText   ; NOT YET DEFINED IN THE PORT
extern OaksLabRivalIPickedTheWrongPokemonText   ; NOT YET DEFINED IN THE PORT
extern OaksLabRivalIllTakeYouOnText   ; NOT YET DEFINED IN THE PORT
extern OaksLabRivalLeaveItAllToMeText   ; NOT YET DEFINED IN THE PORT
extern OaksLabRivalLeavesWithPokedexScript   ; NOT YET DEFINED IN THE PORT
extern OaksLabRivalMyPokemonHasGrownStrongerText   ; NOT YET DEFINED IN THE PORT
extern OaksLabRivalSmellYouLaterText   ; NOT YET DEFINED IN THE PORT
extern OaksLabRivalTakesText1   ; NOT YET DEFINED IN THE PORT
extern OaksLabRivalTakesText2   ; NOT YET DEFINED IN THE PORT
extern OaksLabRivalTakesText3   ; NOT YET DEFINED IN THE PORT
extern OaksLabRivalTakesText4   ; NOT YET DEFINED IN THE PORT
extern OaksLabRivalTakesText5   ; NOT YET DEFINED IN THE PORT
extern OaksLabRivalText   ; NOT YET DEFINED IN THE PORT
extern OaksLabRivalWhatAboutMeText   ; NOT YET DEFINED IN THE PORT
extern OaksLabScientistText   ; NOT YET DEFINED IN THE PORT
extern PlayDefaultMusic   ; NOT YET DEFINED IN THE PORT
extern PlayMusic   ; NOT YET DEFINED IN THE PORT
extern PlayPikachuSoundClip   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern RemoveItemFromInventory   ; NOT YET DEFINED IN THE PORT
extern SaveEndBattleTextPointers   ; NOT YET DEFINED IN THE PORT
extern SchedulePikachuSpawnForAfterText   ; NOT YET DEFINED IN THE PORT
extern SetSpriteFacingDirectionAndDelay   ; NOT YET DEFINED IN THE PORT
extern SetSpritePosition1   ; NOT YET DEFINED IN THE PORT
extern ShowObject   ; NOT YET DEFINED IN THE PORT
extern StartSimulatingJoypadStates   ; NOT YET DEFINED IN THE PORT
extern StopAllMusic   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern TryApplyPikachuMovementData   ; NOT YET DEFINED IN THE PORT
extern UpdateSprites   ; NOT YET DEFINED IN THE PORT
extern _OaksLabGirlText   ; NOT YET DEFINED IN THE PORT
extern _OaksLabOak1DeliverParcelText   ; NOT YET DEFINED IN THE PORT
extern _OaksLabOak1GoAheadItsYours   ; NOT YET DEFINED IN THE PORT
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
extern _OaksLabRivalMyPokemonHasGrownStrongerText   ; NOT YET DEFINED IN THE PORT
extern _OaksLabRivalMyPokemonLooksStrongerText   ; NOT YET DEFINED IN THE PORT
extern _OaksLabRivalSmellYouLaterText   ; NOT YET DEFINED IN THE PORT
extern _OaksLabRivalTakesText1   ; NOT YET DEFINED IN THE PORT
extern _OaksLabRivalTakesText2   ; NOT YET DEFINED IN THE PORT
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
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and the predef id is not left in A because no reader is live; evidence=PredefPointers is unported and the flat model needs no bank switch, dataflow shows A dead after this site; lifetime=retired when PredefPointers is ported}
    call ShowObject
    mov esi, W_STATUS_FLAGS_4
    and byte [ebp + esi], ~(1 << (BIT_NO_BATTLES)) & 0xFF
    mov al, SCRIPT_OAKSLAB_OAK_ENTERS_LAB
    mov [ebp + wOaksLabCurScript], al
    ret

OaksLabOakEntersLabScript:
    mov al, 6
    mov [ebp + hSpriteIndex], al
    mov edi, OakEntryMovement   ; pret: ld de, OakEntryMovement — MoveSprite takes it in EDI
    call MoveSprite
    mov al, SCRIPT_OAKSLAB_TOGGLE_OAKS
    mov [ebp + wOaksLabCurScript], al
    ret

OakEntryMovement:
    db NPC_MOVEMENT_UP
    db NPC_MOVEMENT_UP
    db NPC_MOVEMENT_UP
    db -1

OaksLabToggleOaksScript:
    mov al, [ebp + wStatusFlags5]
    test al, (1 << (BIT_SCRIPTED_NPC_MOVEMENT))
    jz .nr_74
        ret
.nr_74:
    mov al, 48
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and the predef id is not left in A because no reader is live; evidence=PredefPointers is unported and the flat model needs no bank switch, dataflow shows A dead after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
    mov al, 45
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and the predef id is not left in A because no reader is live; evidence=PredefPointers is unported and the flat model needs no bank switch, dataflow shows A dead after this site; lifetime=retired when PredefPointers is ported}
    call ShowObject
    mov al, SCRIPT_OAKSLAB_PLAYER_ENTERS_LAB
    mov [ebp + wOaksLabCurScript], al
    ret

; ---------------------------------------------------------------------------
; BAIL[host-pointer-in-16bit-reg] OaksLabPlayerEntersLabScript (scripts/OaksLab.asm:87-107) — at scripts/OaksLab.asm:89: de cannot hold the 32-bit address of PlayerEntryMovementRLE; callee DecodeRLEList has no abi.json entry
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	call Delay3
; PRET| 	ld hl, wSimulatedJoypadStatesEnd
; PRET| 	ld de, PlayerEntryMovementRLE
; PRET| 	call DecodeRLEList
; PRET| 	dec a
; PRET| 	ld [wSimulatedJoypadStatesIndex], a
; PRET| 	call StartSimulatingJoypadStates
; PRET| 	ld a, OAKSLAB_RIVAL
; PRET| 	ldh [hSpriteIndex], a
; PRET| 	xor a
; PRET| 	ldh [hSpriteFacingDirection], a
; PRET| 	call SetSpriteFacingDirectionAndDelay
; PRET| 	ld a, OAKSLAB_OAK1
; PRET| 	ldh [hSpriteIndex], a
; PRET| 	xor a
; PRET| 	ldh [hSpriteFacingDirection], a
; PRET| 	call SetSpriteFacingDirectionAndDelay
; PRET| 
; PRET| 	ld a, SCRIPT_OAKSLAB_FOLLOWED_OAK
; PRET| 	ld [wOaksLabCurScript], a
; PRET| 	ret

PlayerEntryMovementRLE:
    db PAD_UP, 8
    db -1

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

OaksLabChoseStarterScript:
    mov al, 1
    mov [ebp + hSpriteIndex], al
    mov edi, .RivalPushesPlayerAwayFromEeveeBall   ; pret: ld de, .RivalPushesPlayerAwayFromEeveeBall — MoveSprite takes it in EDI
    call MoveSprite
    mov al, SCRIPT_OAKSLAB_RIVAL_TAKES_POKEBALL
    mov [ebp + wOaksLabCurScript], al
    ret

.RivalPushesPlayerAwayFromEeveeBall:
    db 0x00
    db 0x07
    db 0x07
    db 0x07
    db 0xFF

OaksLabRivalTakesPokeballScript:
    mov al, [ebp + wStatusFlags5]
    test al, (1 << (BIT_SCRIPTED_NPC_MOVEMENT))
    jnz .asm_1c564
    mov al, 44
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and the predef id is not left in A because no reader is live; evidence=PredefPointers is unported and the flat model needs no bank switch, dataflow shows A dead after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
    mov al, 1
    mov [ebp + hSpriteIndex], al
    mov al, SPRITE_FACING_UP
    mov [ebp + hSpriteFacingDirection], al
    call SetSpriteFacingDirectionAndDelay
    mov al, 1
    mov [ebp + W_RIVAL_STARTER], al
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

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] OaksLabPlayerWalksToOakScript (scripts/OaksLab.asm:263-270) — at scripts/OaksLab.asm:265: .asm_1c599 is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wYCoord]
; PRET| 	cp 4
; PRET| 	jr z, .asm_1c599
; PRET| 	ld a, $1
; PRET| 	ld [wSimulatedJoypadStatesIndex], a
; PRET| 	ld a, PAD_LEFT
; PRET| 	ld [wSimulatedJoypadStatesEnd], a
; PRET| 	jr .asm_1c5a6

; ---------------------------------------------------------------------------
; BAIL[host-pointer-in-16bit-reg] OaksLabPlayerWalksToOakScript.asm_1c599 (scripts/OaksLab.asm:273-282) — at scripts/OaksLab.asm:274: de cannot hold the 32-bit address of OaksLabRLE_PlayerWalksToOak; callee DecodeRLEList has no abi.json entry
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, wSimulatedJoypadStatesEnd
; PRET| 	ld de, OaksLabRLE_PlayerWalksToOak
; PRET| 	call DecodeRLEList
; PRET| 	dec a
; PRET| 	ld [wSimulatedJoypadStatesIndex], a
; PRET| .asm_1c5a6
; PRET| 	call StartSimulatingJoypadStates
; PRET| 	ld a, SCRIPT_OAKSLAB_PLAYER_RECEIVES_PIKACHU
; PRET| 	ld [wOaksLabCurScript], a
; PRET| 	ret

OaksLabRLE_PlayerWalksToOak:
    db PAD_UP, 2
    db PAD_LEFT, 3
    db PAD_DOWN, 1
    db PAD_LEFT, 1
    db 0xFF

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

; ---------------------------------------------------------------------------
; BAIL[bank-expression] OaksLabRivalChallengesPlayerScript (scripts/OaksLab.asm:306-338) — at scripts/OaksLab.asm:316: BANK(Music_MeetRival)
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wYCoord]
; PRET| 	cp 6
; PRET| 	ret nz
; PRET| 	ld a, PLAYER_DIR_UP
; PRET| 	ld [wPlayerMovingDirection], a
; PRET| 	ld a, OAKSLAB_RIVAL
; PRET| 	ldh [hSpriteIndex], a
; PRET| 	xor a ; SPRITE_FACING_DOWN
; PRET| 	ldh [hSpriteFacingDirection], a
; PRET| 	call SetSpriteFacingDirectionAndDelay
; PRET| 	ld c, BANK(Music_MeetRival)
; PRET| 	ld a, MUSIC_MEET_RIVAL
; PRET| 	call PlayMusic
; PRET| 	ld a, TEXT_OAKSLAB_RIVAL_ILL_TAKE_YOU_ON
; PRET| 	ldh [hTextID], a
; PRET| 	call DisplayTextID
; PRET| 	ld a, $1
; PRET| 	ldh [hNPCPlayerRelativePosPerspective], a
; PRET| 	ld a, $1
; PRET| 	swap a
; PRET| 	ldh [hNPCPlayerYDistance], a
; PRET| 	predef CalcPositionOfPlayerRelativeToNPC
; PRET| 	ldh a, [hNPCPlayerYDistance]
; PRET| 	dec a
; PRET| 	ldh [hNPCPlayerYDistance], a
; PRET| 	predef FindPathToPlayer
; PRET| 	ld de, wNPCMovementDirections2
; PRET| 	ld a, OAKSLAB_RIVAL
; PRET| 	ldh [hSpriteIndex], a
; PRET| 	call MoveSprite
; PRET| 	ld a, SCRIPT_OAKSLAB_RIVAL_START_BATTLE
; PRET| 	ld [wOaksLabCurScript], a
; PRET| 	ret

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
    mov [ebp + W_RIVAL_STARTER], al
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
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and the predef id is not left in A because no reader is live; evidence=PredefPointers is unported and the flat model needs no bank switch, dataflow shows A dead after this site; lifetime=retired when PredefPointers is ported}
    call HealParty
    SetEvent EVENT_BATTLED_RIVAL_IN_OAKS_LAB
    mov al, SCRIPT_OAKSLAB_RIVAL_STARTS_EXIT
    mov [ebp + wOaksLabCurScript], al
    ret

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

.moveLeft:
    mov al, NPC_MOVEMENT_LEFT
.next:
    mov [ebp + wNPCMovementDirections], al
    mov al, SCRIPT_OAKSLAB_PLAYER_WATCH_RIVAL_EXIT
    mov [ebp + wOaksLabCurScript], al
    ret

.RivalExitMovement:
    db NPC_CHANGE_FACING
    db NPC_MOVEMENT_DOWN
    db 0x04
    db 0x04
    db 0x04
    db 0x04
    db 0x04
    db -1

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] OaksLabPlayerWatchRivalExitScript (scripts/OaksLab.asm:439-450) — at scripts/OaksLab.asm:441: .checkRivalPosition is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wStatusFlags5]
; PRET| 	bit BIT_SCRIPTED_NPC_MOVEMENT, a
; PRET| 	jr nz, .checkRivalPosition
; PRET| 	ld a, PAD_SELECT | PAD_START | PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 	ld a, TOGGLE_OAKS_LAB_RIVAL
; PRET| 	ld [wToggleableObjectIndex], a
; PRET| 	predef HideObject
; PRET| 	call PlayDefaultMusic
; PRET| 	ld a, SCRIPT_OAKSLAB_PIKACHU_ESCAPES_POKEBALL
; PRET| 	ld [wOaksLabCurScript], a
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] OaksLabPlayerWatchRivalExitScript.checkRivalPosition (scripts/OaksLab.asm:453-460) — at scripts/OaksLab.asm:458: .turnPlayerLeft is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wNPCNumScriptedSteps]
; PRET| 	cp $5
; PRET| 	jr nz, .turnPlayerDown
; PRET| 	ld a, [wXCoord]
; PRET| 	cp 4
; PRET| 	jr nz, .turnPlayerLeft
; PRET| 	ld a, SPRITE_FACING_RIGHT
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] OaksLabPlayerWatchRivalExitScript.turnPlayerLeft (scripts/OaksLab.asm:462-463) — at scripts/OaksLab.asm:463: .done is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, SPRITE_FACING_LEFT
; PRET| 	jr .done

.turnPlayerDown:
    cmp al, 0x4
    jz .nr_466
        ret
.nr_466:
    xor al, al
.done:
    mov [ebp + wSpritePlayerStateData1FacingDirection], al
    ret

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
; BAIL[predef-leaves-id-in-a] OaksLabOakGivesPokedexScript (scripts/OaksLab.asm:542-613) — at scripts/OaksLab.asm:573: predef HideObject
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

; ---------------------------------------------------------------------------
; BAIL[event-byte-assembly-state] OaksLabRivalLeavesWithPokedexScript (scripts/OaksLab.asm:616-634) — at scripts/OaksLab.asm:624: ResetEventReuseHL EVENT_2ND_ROUTE22_RIVAL_BATTLE
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wStatusFlags5]
; PRET| 	bit BIT_SCRIPTED_NPC_MOVEMENT, a
; PRET| 	ret nz
; PRET| 	call PlayDefaultMusic
; PRET| 	ld a, TOGGLE_OAKS_LAB_RIVAL
; PRET| 	ld [wToggleableObjectIndex], a
; PRET| 	predef HideObject
; PRET| 	SetEvent EVENT_1ST_ROUTE22_RIVAL_BATTLE
; PRET| 	ResetEventReuseHL EVENT_2ND_ROUTE22_RIVAL_BATTLE
; PRET| 	SetEventReuseHL EVENT_ROUTE22_RIVAL_WANTS_BATTLE
; PRET| 	ld a, TOGGLE_ROUTE_22_RIVAL_1
; PRET| 	ld [wToggleableObjectIndex], a
; PRET| 	predef ShowObject
; PRET| 	xor a
; PRET| 	ld [wJoyIgnore], a
; PRET| 
; PRET| 	ld a, SCRIPT_OAKSLAB_NOOP
; PRET| 	ld [wOaksLabCurScript], a
; PRET| 	ret

OaksLabNoopScript:
    ret

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

.foundParcel:
    mov esi, wNumBagItems
    mov al, bl
    mov [ebp + wWhichPokemon], al
    mov al, 1
    mov [ebp + wItemQuantity], al
    call RemoveItemFromInventory
    ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] OaksLabCalcRivalMovementScript (scripts/OaksLab.asm:661-672) — at scripts/OaksLab.asm:667: .not_below_oak is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, $7c
; PRET| 	ldh [hSpriteScreenYCoord], a
; PRET| 	ld a, 8
; PRET| 	ldh [hSpriteMapXCoord], a
; PRET| 	ld a, [wYCoord]
; PRET| 	cp 3
; PRET| 	jr nz, .not_below_oak
; PRET| 	ld a, $4
; PRET| 	ld [wNPCMovementDirections2Index], a
; PRET| 	ld a, $30
; PRET| 	ld b, 11
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] OaksLabCalcRivalMovementScript.not_below_oak (scripts/OaksLab.asm:674-680) — at scripts/OaksLab.asm:675: .not_above_oak is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	cp 1
; PRET| 	jr nz, .not_above_oak
; PRET| 	ld a, $2
; PRET| 	ld [wNPCMovementDirections2Index], a
; PRET| 	ld a, $30
; PRET| 	ld b, 9
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] OaksLabCalcRivalMovementScript.not_above_oak (scripts/OaksLab.asm:682-689) — at scripts/OaksLab.asm:689: .done is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, $3
; PRET| 	ld [wNPCMovementDirections2Index], a
; PRET| 	ld b, 10
; PRET| 	ld a, [wXCoord]
; PRET| 	cp 4
; PRET| 	jr nz, .not_left_of_oak
; PRET| 	ld a, $40
; PRET| 	jr .done

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

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] OaksLabRivalText (scripts/OaksLab.asm:752-756) — at scripts/OaksLab.asm:753: .beforeChooseMon is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_FOLLOWED_OAK_INTO_LAB_2
; PRET| 	jr nz, .beforeChooseMon
; PRET| 	ld hl, .GrampsIsntAroundText
; PRET| 	call PrintText
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[event-byte-assembly-state] OaksLabRivalText.beforeChooseMon (scripts/OaksLab.asm:758-762) — at scripts/OaksLab.asm:758: CheckEventReuseA EVENT_GOT_STARTER
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEventReuseA EVENT_GOT_STARTER
; PRET| 	jr nz, .afterChooseMon
; PRET| 	ld hl, .IllGetABetterPokemonThanYou
; PRET| 	call PrintText
; PRET| 	jr .done

.afterChooseMon:
    mov esi, .MyPokemonLooksStrongerText
    call PrintText
.done:
    jmp TextScriptEnd

.GrampsIsntAroundText:
    text_far _OaksLabRivalGrampsIsntAroundText
    text_end
.IllGetABetterPokemonThanYou:
    text_far _OaksLabRivalIllGetABetterPokemonThanYou
    text_end
.MyPokemonLooksStrongerText:
    text_far _OaksLabRivalMyPokemonLooksStrongerText
    text_end

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] OaksLabEeveePokeBallText (scripts/OaksLab.asm:783-791) — at scripts/OaksLab.asm:789: .Text is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, $1
; PRET| 	ld [wDoNotWaitForButtonPressAfterDisplayingText], a
; PRET| 	CheckEvent EVENT_OAK_ASKED_TO_CHOOSE_MON
; PRET| 	jr nz, OaksLabRivalExclamationScript
; PRET| 	ld a, $0
; PRET| 	ld [wDoNotWaitForButtonPressAfterDisplayingText], a
; PRET| 	ld hl, .Text
; PRET| 	call PrintText
; PRET| 	jp TextScriptEnd

.Text:
    text_far _OaksLabThatsAPokeball
    text_end

OaksLabRivalExclamationScript:
    mov al, 1
    mov [ebp + wEmotionBubbleSpriteIndex], al
    xor al, al
    mov [ebp + wWhichEmotionBubble], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and the predef id is not left in A because no reader is live; evidence=PredefPointers is unported and the flat model needs no bank switch, dataflow shows A dead after this site; lifetime=retired when PredefPointers is ported}
    call EmotionBubble
    mov al, SCRIPT_OAKSLAB_CHOSE_STARTER_SCRIPT
    mov [ebp + wOaksLabCurScript], al
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] OaksLabOak1Text (scripts/OaksLab.asm:809-823) — at scripts/OaksLab.asm:810: .already_got_poke_balls is defined in a region that bailed
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

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] OaksLabOak1Text.check_for_poke_balls (scripts/OaksLab.asm:825-845) — at scripts/OaksLab.asm:827: .come_see_me_sometimes is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld b, POKE_BALL
; PRET| 	call IsItemInBag
; PRET| 	jr nz, .come_see_me_sometimes
; PRET| 	ld hl, wPokedexOwned
; PRET| 	ld b, wPokedexOwnedEnd - wPokedexOwned
; PRET| 	call CountSetBits
; PRET| 	ld a, [wNumSetBits]
; PRET| 	cp 2
; PRET| 	jr nc, .come_see_me_sometimes
; PRET| 	CheckEvent EVENT_BEAT_ROUTE22_RIVAL_1ST_BATTLE
; PRET| 	jr nz, .give_poke_balls
; PRET| 	CheckEvent EVENT_GOT_POKEDEX
; PRET| 	jr nz, .mon_around_the_world
; PRET| 	CheckEventReuseA EVENT_BATTLED_RIVAL_IN_OAKS_LAB
; PRET| 	jr nz, .check_got_parcel
; PRET| 	ld a, [wStatusFlags4]
; PRET| 	bit BIT_GOT_STARTER, a
; PRET| 	jr nz, .already_got_pokemon
; PRET| 	ld hl, .GoAheadItsYours
; PRET| 	call PrintText
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] OaksLabOak1Text.already_got_pokemon (scripts/OaksLab.asm:847-849) — at scripts/OaksLab.asm:847: .YourPokemonCanFightText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .YourPokemonCanFightText
; PRET| 	call PrintText
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] OaksLabOak1Text.check_got_parcel (scripts/OaksLab.asm:851-856) — at scripts/OaksLab.asm:853: .got_parcel is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld b, OAKS_PARCEL
; PRET| 	call IsItemInBag
; PRET| 	jr nz, .got_parcel
; PRET| 	ld hl, .YouShouldTalkToIt
; PRET| 	call PrintText
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] OaksLabOak1Text.got_parcel (scripts/OaksLab.asm:858-863) — at scripts/OaksLab.asm:858: .DeliverParcelText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .DeliverParcelText
; PRET| 	call PrintText
; PRET| 	call OaksLabScript_RemoveParcel
; PRET| 	ld a, SCRIPT_OAKSLAB_RIVAL_ARRIVES_AT_OAKS_REQUEST
; PRET| 	ld [wOaksLabCurScript], a
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] OaksLabOak1Text.mon_around_the_world (scripts/OaksLab.asm:865-867) — at scripts/OaksLab.asm:865: .PokemonAroundTheWorldText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .PokemonAroundTheWorldText
; PRET| 	call PrintText
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] OaksLabOak1Text.give_poke_balls (scripts/OaksLab.asm:869-875) — at scripts/OaksLab.asm:870: .come_see_me_sometimes is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckAndSetEvent EVENT_GOT_POKEBALLS_FROM_OAK
; PRET| 	jr nz, .come_see_me_sometimes
; PRET| 	lb bc, POKE_BALL, 5
; PRET| 	call GiveItem
; PRET| 	ld hl, .GivePokeballsText
; PRET| 	call PrintText
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] OaksLabOak1Text.come_see_me_sometimes (scripts/OaksLab.asm:877-880) — at scripts/OaksLab.asm:877: .ComeSeeMeSometimesText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .ComeSeeMeSometimesText
; PRET| 	call PrintText
; PRET| .done
; PRET| 	jp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[text-sound-command-unported] OaksLabOak1Text.GoAheadItsYours (scripts/OaksLab.asm:883-916) — at scripts/OaksLab.asm:896: sound_get_key_item
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _OaksLabOak1GoAheadItsYours
; PRET| 	text_end
; PRET| 
; PRET| .YourPokemonCanFightText:
; PRET| 	text_far _OaksLabOak1YourPokemonCanFightText
; PRET| 	text_end
; PRET| 
; PRET| .YouShouldTalkToIt:
; PRET| 	text_far _OaksLabOak1YouShouldTalkToIt
; PRET| 	text_end
; PRET| 
; PRET| .DeliverParcelText:
; PRET| 	text_far _OaksLabOak1DeliverParcelText
; PRET| 	sound_get_key_item
; PRET| 	text_far _OaksLabOak1ParcelThanksText
; PRET| 	text_end
; PRET| 
; PRET| .PokemonAroundTheWorldText:
; PRET| 	text_far _OaksLabOak1PokemonAroundTheWorldText
; PRET| 	text_end
; PRET| 
; PRET| .GivePokeballsText:
; PRET| 	text_far _OaksLabOak1ReceivedPokeballsText
; PRET| 	sound_get_key_item
; PRET| 	text_far _OaksLabGivePokeballsExplanationText
; PRET| 	text_end
; PRET| 
; PRET| .ComeSeeMeSometimesText:
; PRET| 	text_far _OaksLabOak1ComeSeeMeSometimesText
; PRET| 	text_end
; PRET| 
; PRET| .HowIsYourPokedexComingText:
; PRET| 	text_far _OaksLabOak1HowIsYourPokedexComingText
; PRET| 	text_end

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] OaksLabPokedexText (scripts/OaksLab.asm:920-922) — at scripts/OaksLab.asm:920: .Text is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .Text
; PRET| 	call PrintText
; PRET| 	jp TextScriptEnd

.Text:
    text_far _OaksLabPokedexText
    text_end
OaksLabOak2Text:
    text_far _OaksLabOak2Text
    text_end

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] OaksLabGirlText (scripts/OaksLab.asm:934-936) — at scripts/OaksLab.asm:934: .Text is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .Text
; PRET| 	call PrintText
; PRET| 	jp TextScriptEnd

.Text:
    text_far _OaksLabGirlText
    text_end

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] OaksLabRivalFedUpWithWaitingText (scripts/OaksLab.asm:944-946) — at scripts/OaksLab.asm:944: .Text is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .Text
; PRET| 	call PrintText
; PRET| 	jp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[local-label-scope-collision] OaksLabRivalFedUpWithWaitingText.Text (scripts/OaksLab.asm:949-950)
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _OaksLabRivalFedUpWithWaitingText
; PRET| 	text_end

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] OaksLabOakChooseMonText (scripts/OaksLab.asm:954-956) — at scripts/OaksLab.asm:954: .Text is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .Text
; PRET| 	call PrintText
; PRET| 	jp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[local-label-scope-collision] OaksLabOakChooseMonText.Text (scripts/OaksLab.asm:959-960)
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _OaksLabOakChooseMonText
; PRET| 	text_end

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] OaksLabRivalWhatAboutMeText (scripts/OaksLab.asm:964-966) — at scripts/OaksLab.asm:964: .Text is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .Text
; PRET| 	call PrintText
; PRET| 	jp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[local-label-scope-collision] OaksLabRivalWhatAboutMeText.Text (scripts/OaksLab.asm:969-970)
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _OaksLabRivalWhatAboutMeText
; PRET| 	text_end

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] OaksLabOakBePatientText (scripts/OaksLab.asm:974-976) — at scripts/OaksLab.asm:974: .Text is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .Text
; PRET| 	call PrintText
; PRET| 	jp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[local-label-scope-collision] OaksLabOakBePatientText.Text (scripts/OaksLab.asm:979-980)
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _OaksLabOakBePatientText
; PRET| 	text_end

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

; ---------------------------------------------------------------------------
; BAIL[text-sound-command-unported] OaksLabRivalTakesText1 (scripts/OaksLab.asm:997-1015) — at scripts/OaksLab.asm:1002: sound_get_key_item
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _OaksLabRivalTakesText1
; PRET| 	text_end
; PRET| 
; PRET| OaksLabRivalTakesText2:
; PRET| 	text_far _OaksLabRivalTakesText2
; PRET| 	sound_get_key_item
; PRET| 	text_end
; PRET| 
; PRET| OaksLabRivalTakesText3:
; PRET| 	text_far _OaksLabRivalTakesText3
; PRET| 	text_end
; PRET| 
; PRET| OaksLabRivalTakesText4:
; PRET| 	text_far _OaksLabRivalTakesText4
; PRET| 	text_end
; PRET| 
; PRET| OaksLabRivalTakesText5:
; PRET| 	text_far _OaksLabRivalTakesText5
; PRET| 	text_end

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
    mov esi, W_STATUS_FLAGS_4
    or byte [ebp + esi], (1 << (3))
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[text-sound-command-unported] OaksLabOakGivesText (scripts/OaksLab.asm:1046-1052) — at scripts/OaksLab.asm:1051: sound_get_key_item
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _OaksLabOakGivesText
; PRET| 	text_end
; PRET| 
; PRET| OaksLabReceivedText:
; PRET| 	text_far _OaksLabReceivedText
; PRET| 	sound_get_key_item
; PRET| 	text_end

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] OaksLabOakDontGoAwayYetText (scripts/OaksLab.asm:1056-1058) — at scripts/OaksLab.asm:1056: .Text is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .Text
; PRET| 	call PrintText
; PRET| 	jp TextScriptEnd

.Text:
    text_far _OaksLabOakDontGoAwayYetText
    text_end

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] OaksLabRivalIllTakeYouOnText (scripts/OaksLab.asm:1066-1068) — at scripts/OaksLab.asm:1066: .Text is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .Text
; PRET| 	call PrintText
; PRET| 	jp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[local-label-scope-collision] OaksLabRivalIllTakeYouOnText.Text (scripts/OaksLab.asm:1071-1080)
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _OaksLabRivalIllTakeYouOnText
; PRET| 	text_end
; PRET| 
; PRET| OaksLabRivalIPickedTheWrongPokemonText:
; PRET| 	text_far _OaksLabRivalIPickedTheWrongPokemonText
; PRET| 	text_end
; PRET| 
; PRET| OaksLabRivalAmIGreatOrWhatText:
; PRET| 	text_far _OaksLabRivalAmIGreatOrWhatText
; PRET| 	text_end

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] OaksLabRivalSmellYouLaterText (scripts/OaksLab.asm:1084-1086) — at scripts/OaksLab.asm:1084: .Text is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .Text
; PRET| 	call PrintText
; PRET| 	jp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[local-label-scope-collision] OaksLabRivalSmellYouLaterText.Text (scripts/OaksLab.asm:1089-1090)
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _OaksLabRivalSmellYouLaterText
; PRET| 	text_end

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

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] OaksLabPikachuDislikesPokeballsText2 (scripts/OaksLab.asm:1106-1108) — at scripts/OaksLab.asm:1106: .Text is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .Text
; PRET| 	call PrintText
; PRET| 	jp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[text-sound-command-unported] OaksLabPikachuDislikesPokeballsText2.Text (scripts/OaksLab.asm:1111-1141) — at scripts/OaksLab.asm:1132: sound_get_key_item
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _OaksLabPikachuDislikesPokeballsText2
; PRET| 	text_end
; PRET| 
; PRET| OaksLabRivalGrampsText:
; PRET| 	text_far _OaksLabRivalGrampsText
; PRET| 	text_end
; PRET| 
; PRET| OaksLabRivalMyPokemonHasGrownStrongerText:
; PRET| 	text_far _OaksLabRivalMyPokemonHasGrownStrongerText
; PRET| 	text_end
; PRET| 
; PRET| OaksLabOakIHaveARequestText:
; PRET| 	text_far _OaksLabOakIHaveARequestText
; PRET| 	text_end
; PRET| 
; PRET| OaksLabOakMyInventionPokedexText:
; PRET| 	text_far _OaksLabOakMyInventionPokedexText
; PRET| 	text_end
; PRET| 
; PRET| OaksLabOakGotPokedexText:
; PRET| 	text_far _OaksLabOakGotPokedexText
; PRET| 	sound_get_key_item
; PRET| 	text_end
; PRET| 
; PRET| OaksLabOakThatWasMyDreamText:
; PRET| 	text_far _OaksLabOakThatWasMyDreamText
; PRET| 	text_end
; PRET| 
; PRET| OaksLabRivalLeaveItAllToMeText:
; PRET| 	text_far _OaksLabRivalLeaveItAllToMeText
; PRET| 	text_end

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] OaksLabScientistText (scripts/OaksLab.asm:1145-1147) — at scripts/OaksLab.asm:1145: .Text is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .Text
; PRET| 	call PrintText
; PRET| 	jp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[local-label-scope-collision] OaksLabScientistText.Text (scripts/OaksLab.asm:1150-1151)
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _OaksLabScientistText
; PRET| 	text_end

OaksLabPikachuMovementScript:
    mov al, [ebp + wYCoord]
    cmp al, 3
    jz .movement2
    mov bh, SPRITE_FACING_DOWN
    mov esi, OaksLabPikachuMovementData1
    call TryApplyPikachuMovementData
    ret

.movement2:
    mov bh, SPRITE_FACING_LEFT
    mov esi, OaksLabPikachuMovementData2
    call TryApplyPikachuMovementData
    ret

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
