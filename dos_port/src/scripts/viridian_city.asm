; ViridianCity.asm — translated from pret scripts/ViridianCity.asm, scripts/ViridianCity_2.asm by dos_port/tools/sm83xlat.
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


global ViridianCityAfterPokedexScript
global ViridianCityCheckGymOpenScript
global ViridianCityCheckSleepingOldMan
global ViridianCityCheckWaitingOldMan
global ViridianCityDefaultScript
global ViridianCityFisherText
global ViridianCityGambler1Text
global ViridianCityGirlText
global ViridianCityGymLockedText
global ViridianCityGymSignText
global ViridianCityMovePikachu
global ViridianCityMovePlayerDownScript
global ViridianCityOldMan2Text
global ViridianCityOldManEndCatchTrainingScript
global ViridianCityOldManEndInitialCatchTrainingScript
global ViridianCityOldManInitialCatchTrainingScript
global ViridianCityOldManMovementData1
global ViridianCityOldManMovementData2
global ViridianCityOldManMovingDownScript
global ViridianCityOldManSleepyText
global ViridianCityOldManStartCatchTrainingScript
global ViridianCityOldManText
global ViridianCityOldManYouNeedToWeakenTheTargetText
global ViridianCityPikachuMovementData
global ViridianCityPlayerMovingDownPostTrainingScript
global ViridianCityPlayerMovingDownScript
global ViridianCityPostCatchTraining
global ViridianCityPostInitialCatchTraining
global ViridianCityPrintFisherText
global ViridianCityPrintGambler1Text
global ViridianCityPrintGirlText
global ViridianCityPrintGymLockedText
global ViridianCityPrintGymSignText
global ViridianCityPrintOldManSleepyText
global ViridianCityPrintOldManText
global ViridianCityPrintSignText
global ViridianCityPrintTrainerTips1Text
global ViridianCityPrintTrainerTips2Text
global ViridianCityPrintYoungster1Text
global ViridianCityPrintYoungster2Text
global ViridianCitySignText
global ViridianCityTrainerTips1Text
global ViridianCityTrainerTips2Text
global ViridianCityYoungster1Text
global ViridianCityYoungster2Text
global ViridianCity_Script
global ViridianCity_ScriptPointers
global ViridianCity_TextPointers

extern Bankswitch
extern CallFunctionInTable
extern Delay3
extern DelayFrames
extern DisplayTextID
extern EnableAutoTextBoxDrawing
extern GiveItem
extern HideObject
extern MartSignText   ; NOT YET DEFINED IN THE PORT
extern MoveSprite
extern PokeCenterSignText   ; NOT YET DEFINED IN THE PORT
extern PrintText
extern SetSpriteFacingDirectionAndDelay   ; NOT YET DEFINED IN THE PORT
extern StartSimulatingJoypadStates
extern TextScriptEnd
extern TryApplyPikachuMovementData   ; NOT YET DEFINED IN THE PORT
extern UpdateSprites
extern ViridianCityFisherYouCanHaveThisText   ; NOT YET DEFINED IN THE PORT
extern ViridianCityYoungster2CaterpieAndWeedleDescriptionText   ; NOT YET DEFINED IN THE PORT
extern ViridianCityYoungster2OkThenText   ; NOT YET DEFINED IN THE PORT
extern YesNoChoice
extern _ViridianCityFisherReceivedTM42Text   ; NOT YET DEFINED IN THE PORT
extern _ViridianCityFisherTM42ExplanationText   ; NOT YET DEFINED IN THE PORT
extern _ViridianCityFisherTM42NoRoomText   ; NOT YET DEFINED IN THE PORT
extern _ViridianCityGambler1GymAlwaysClosedText   ; NOT YET DEFINED IN THE PORT
extern _ViridianCityGambler1GymLeaderReturnedText   ; NOT YET DEFINED IN THE PORT
extern _ViridianCityGirlHasntHadHisCoffeeYetText   ; NOT YET DEFINED IN THE PORT
extern _ViridianCityGirlWhenIGoShopText   ; NOT YET DEFINED IN THE PORT
extern _ViridianCityGymLockedText   ; NOT YET DEFINED IN THE PORT
extern _ViridianCityGymSignText   ; NOT YET DEFINED IN THE PORT
extern _ViridianCityOldManHadMyCoffeeNowText   ; NOT YET DEFINED IN THE PORT
extern _ViridianCityOldManLosingMyTouchText   ; NOT YET DEFINED IN THE PORT
extern _ViridianCityOldManNotGoodEnoughForYouText   ; NOT YET DEFINED IN THE PORT
extern _ViridianCityOldManSleepyPrivatePropertyText   ; NOT YET DEFINED IN THE PORT
extern _ViridianCityOldManWantMeToShowYouAgainText   ; NOT YET DEFINED IN THE PORT
extern _ViridianCityOldManWatchCloselyText   ; NOT YET DEFINED IN THE PORT
extern _ViridianCityOldManYouNeedToWeakenTheTargetText   ; NOT YET DEFINED IN THE PORT
extern _ViridianCitySignText   ; NOT YET DEFINED IN THE PORT
extern _ViridianCityTrainerTips1Text   ; NOT YET DEFINED IN THE PORT
extern _ViridianCityTrainerTips2Text   ; NOT YET DEFINED IN THE PORT
extern _ViridianCityYoungster1Text   ; NOT YET DEFINED IN THE PORT
extern _ViridianCityYoungster2YouWantToKnowAboutText   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_VIRIDIANCITY_DEFAULT                    equ 0
SCRIPT_VIRIDIANCITY_POST_CATCH_TRAINING        equ 2
SCRIPT_VIRIDIANCITY_OLD_MAN_START_CATCH_TRAINING equ 3
SCRIPT_VIRIDIANCITY_OLD_MAN_END_CATCH_TRAINING equ 4
SCRIPT_VIRIDIANCITY_PLAYER_MOVING_DOWN         equ 5
SCRIPT_VIRIDIANCITY_PLAYER_MOVING_DOWN_POST_TRAINING equ 6
SCRIPT_VIRIDIANCITY_OLD_MAN_INITIAL_CATCH_TRAINING equ 7
SCRIPT_VIRIDIANCITY_OLD_MAN_END_INITIAL_CATCH_TRAINING equ 8
SCRIPT_VIRIDIANCITY_POST_INITIAL_CATCH_TRAINING equ 9
SCRIPT_VIRIDIANCITY_OLD_MAN_MOVING_DOWN        equ 10
TEXT_VIRIDIANCITY_OLD_MAN_SLEEPY               equ 5
TEXT_VIRIDIANCITY_OLD_MAN2                     equ 8
TEXT_VIRIDIANCITY_GYM_LOCKED                   equ 15
TEXT_VIRIDIANCITY_OLD_MAN_YOU_NEED_TO_WEAKEN_THE_TARGET equ 16

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
hSpriteFacingDirection                         equ 0xFF8D
hSpriteMapXCoord                               equ 0xFFEE
hSpriteMapYCoord                               equ 0xFFED
hSpriteScreenXCoord                            equ 0xFFEC
hSpriteScreenYCoord                            equ 0xFFEB
wSprite03StateData1XPixels                     equ 0xC136
wSprite03StateData1YPixels                     equ 0xC134
wSprite03StateData2MapX                        equ 0xC235
wSprite03StateData2MapY                        equ 0xC234
wSpritePlayerStateData1FacingDirection         equ 0xC109
wViridianCityCurScript                         equ 0xD5F3

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
ViridianCity_Script:
    call EnableAutoTextBoxDrawing
    mov esi, ViridianCity_ScriptPointers
    mov al, [ebp + wViridianCityCurScript]
    call CallFunctionInTable
    ret

%assign event_byte -1
%assign event_byte_a -1
ViridianCity_ScriptPointers:
    dd ViridianCityDefaultScript
    dd ViridianCityAfterPokedexScript
    dd ViridianCityPostCatchTraining
    dd ViridianCityOldManStartCatchTrainingScript
    dd ViridianCityOldManEndCatchTrainingScript
    dd ViridianCityPlayerMovingDownScript
    dd ViridianCityPlayerMovingDownPostTrainingScript
    dd ViridianCityOldManInitialCatchTrainingScript
    dd ViridianCityOldManEndInitialCatchTrainingScript
    dd ViridianCityPostInitialCatchTraining
    dd ViridianCityOldManMovingDownScript

%assign event_byte -1
%assign event_byte_a -1
ViridianCityDefaultScript:
    call ViridianCityCheckGymOpenScript
    call ViridianCityCheckSleepingOldMan
    ret

%assign event_byte -1
%assign event_byte_a -1
ViridianCityAfterPokedexScript:
    call ViridianCityCheckWaitingOldMan
ViridianCityPostCatchTraining:
    call ViridianCityCheckGymOpenScript
    ret

%assign event_byte -1
%assign event_byte_a -1
ViridianCityCheckGymOpenScript:
    CheckEvent EVENT_VIRIDIAN_GYM_OPEN
    jz .nr_35
        ret
.nr_35:
    mov al, [ebp + wObtainedBadges]
    cmp al, ~(1 << 7)
    jnz .gym_closed
    SetEvent EVENT_VIRIDIAN_GYM_OPEN
    ret

%assign event_byte -1
%assign event_byte_a -1
.gym_closed:
    mov al, [ebp + wYCoord]
    cmp al, 8
    jz .nr_44
        ret
.nr_44:
    mov al, [ebp + wXCoord]
    cmp al, 32
    jz .nr_47
        ret
.nr_47:
    mov al, TEXT_VIRIDIANCITY_GYM_LOCKED
    mov [ebp + hTextID], al
    call DisplayTextID
    call StartSimulatingJoypadStates
    mov al, 0x1
    mov [ebp + wSimulatedJoypadStatesIndex], al
    mov al, PAD_DOWN
    mov [ebp + wSimulatedJoypadStatesEnd], al
    xor al, al
    mov [ebp + wSpritePlayerStateData1FacingDirection], al
    mov [ebp + wJoyIgnore], al
    mov [ebp + hJoyHeld], al
    mov al, SCRIPT_VIRIDIANCITY_PLAYER_MOVING_DOWN_POST_TRAINING
    mov [ebp + wViridianCityCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
ViridianCityPlayerMovingDownPostTrainingScript:
    mov al, [ebp + wSimulatedJoypadStatesIndex]
    test al, al
    jz .nr_67
        ret
.nr_67:
    call Delay3
    mov al, SCRIPT_VIRIDIANCITY_POST_CATCH_TRAINING
    mov [ebp + wViridianCityCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
ViridianCityCheckSleepingOldMan:
    mov al, [ebp + wYCoord]
    cmp al, 9
    jz .nr_76
        ret
.nr_76:
    mov al, [ebp + wXCoord]
    cmp al, 19
    jz .nr_79
        ret
.nr_79:
    mov al, TEXT_VIRIDIANCITY_OLD_MAN_SLEEPY
    mov [ebp + hTextID], al
    call DisplayTextID
    xor al, al
    mov [ebp + hJoyHeld], al
    call ViridianCityMovePlayerDownScript
    mov al, SCRIPT_VIRIDIANCITY_PLAYER_MOVING_DOWN
    mov [ebp + wViridianCityCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
ViridianCityOldManStartCatchTrainingScript:
    call .SetupSprite
    call .SetupBattle
    ResetEvent EVENT_INITIAL_CATCH_TRAINING
    mov al, SCRIPT_VIRIDIANCITY_OLD_MAN_END_CATCH_TRAINING
    mov [ebp + wViridianCityCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
.SetupBattle:
    xor al, al
    mov [ebp + wListScrollOffset], al
    mov al, BATTLE_TYPE_OLD_MAN
    mov [ebp + wBattleType], al
    mov al, 5
    mov [ebp + wCurEnemyLevel], al
    mov al, 165
    mov [ebp + wCurOpponent], al
    ret

%assign event_byte -1
%assign event_byte_a -1
.SetupSprite:
    mov al, [ebp + wSprite03StateData1YPixels]
    mov [ebp + hSpriteScreenYCoord], al
    mov al, [ebp + wSprite03StateData1XPixels]
    mov [ebp + hSpriteScreenXCoord], al
    mov al, [ebp + wSprite03StateData2MapY]
    mov [ebp + hSpriteMapYCoord], al
    mov al, [ebp + wSprite03StateData2MapX]
    mov [ebp + hSpriteMapXCoord], al
    ret

%assign event_byte -1
%assign event_byte_a -1
ViridianCityOldManEndCatchTrainingScript:
    call .SetupSprite
    call UpdateSprites
    call Delay3
    SetEvent EVENT_COMPLETED_CATCH_TRAINING_AGAIN
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov al, TEXT_VIRIDIANCITY_OLD_MAN_YOU_NEED_TO_WEAKEN_THE_TARGET
    mov [ebp + hTextID], al
    call DisplayTextID
    xor al, al
    mov [ebp + wBattleType], al
    mov [ebp + wJoyIgnore], al
    mov al, SCRIPT_VIRIDIANCITY_POST_CATCH_TRAINING
    mov [ebp + wViridianCityCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
.SetupSprite:
    mov al, [ebp + hSpriteScreenYCoord]
    mov [ebp + wSprite03StateData1YPixels], al
    mov al, [ebp + hSpriteScreenXCoord]
    mov [ebp + wSprite03StateData1XPixels], al
    mov al, [ebp + hSpriteMapYCoord]
    mov [ebp + wSprite03StateData2MapY], al
    mov al, [ebp + hSpriteMapXCoord]
    mov [ebp + wSprite03StateData2MapX], al
    ret

%assign event_byte -1
%assign event_byte_a -1
ViridianCityPlayerMovingDownScript:
    mov al, [ebp + wSimulatedJoypadStatesIndex]
    test al, al
    jz .nr_151
        ret
.nr_151:
    call Delay3
    mov al, SCRIPT_VIRIDIANCITY_DEFAULT
    mov [ebp + wViridianCityCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
ViridianCityMovePlayerDownScript:
    call StartSimulatingJoypadStates
    mov al, 0x1
    mov [ebp + wSimulatedJoypadStatesIndex], al
    mov al, PAD_DOWN
    mov [ebp + wSimulatedJoypadStatesEnd], al
    xor al, al
    mov [ebp + wSpritePlayerStateData1FacingDirection], al
    mov [ebp + wJoyIgnore], al
    ret

%assign event_byte -1
%assign event_byte_a -1
ViridianCityCheckWaitingOldMan:
    CheckEvent EVENT_COMPLETED_CATCH_TRAINING
    jz .nr_170
        ret
.nr_170:
    mov al, [ebp + wYCoord]
    cmp al, 9
    jz .nr_173
        ret
.nr_173:
    mov al, [ebp + wXCoord]
    cmp al, 19
    jz .nr_176
        ret
.nr_176:
    mov al, 8
    mov [ebp + hSpriteIndex], al
    mov al, SPRITE_FACING_RIGHT
    mov [ebp + hSpriteFacingDirection], al
    call SetSpriteFacingDirectionAndDelay
    mov al, SPRITE_FACING_LEFT
    mov [ebp + wSpritePlayerStateData1FacingDirection], al
    mov al, TEXT_VIRIDIANCITY_OLD_MAN2
    mov [ebp + hTextID], al
    call DisplayTextID
    mov al, PAD_SELECT | PAD_START | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    ret

%assign event_byte -1
%assign event_byte_a -1
ViridianCityOldManInitialCatchTrainingScript:
    call ViridianCityOldManStartCatchTrainingScript.SetupSprite
    call ViridianCityOldManStartCatchTrainingScript.SetupBattle
    SetEvent EVENT_INITIAL_CATCH_TRAINING
    mov al, PAD_SELECT | PAD_START | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, SCRIPT_VIRIDIANCITY_OLD_MAN_END_INITIAL_CATCH_TRAINING
    mov [ebp + wViridianCityCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
ViridianCityOldManEndInitialCatchTrainingScript:
    call ViridianCityOldManEndCatchTrainingScript.SetupSprite
    call UpdateSprites
    call Delay3
    SetEvent EVENT_COMPLETED_CATCH_TRAINING
    mov al, PAD_SELECT | PAD_START | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, TEXT_VIRIDIANCITY_OLD_MAN2
    mov [ebp + hTextID], al
    call DisplayTextID
    xor al, al
    mov [ebp + wBattleType], al
    dec al
    mov [ebp + wJoyIgnore], al
    mov al, SCRIPT_VIRIDIANCITY_POST_INITIAL_CATCH_TRAINING
    mov [ebp + wViridianCityCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
ViridianCityPostInitialCatchTraining:
    mov edi, ViridianCityOldManMovementData2   ; pret: ld de, ViridianCityOldManMovementData2 — MoveSprite takes EDI
    mov al, [ebp + wXCoord]
    cmp al, 19
    jz .move_old_man
    call ViridianCityMovePikachu   ; pret: callfar ViridianCityMovePikachu
    mov edi, ViridianCityOldManMovementData1   ; pret: ld de, ViridianCityOldManMovementData1 — MoveSprite takes EDI
.move_old_man:
    mov al, 8   ; pret: ld a, VIRIDIANCITY_OLD_MAN2
    mov [ebp + hSpriteIndex], al
    call MoveSprite
    mov al, SCRIPT_VIRIDIANCITY_OLD_MAN_MOVING_DOWN
    mov [ebp + wViridianCityCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
ViridianCityOldManMovementData1:
    db NPC_MOVEMENT_RIGHT
ViridianCityOldManMovementData2:
    db NPC_MOVEMENT_DOWN
    db NPC_MOVEMENT_DOWN
    db NPC_MOVEMENT_DOWN
    db NPC_MOVEMENT_DOWN
    db NPC_MOVEMENT_DOWN
    db NPC_MOVEMENT_DOWN
    db 0xff

%assign event_byte -1
%assign event_byte_a -1
ViridianCityOldManMovingDownScript:
    mov al, [ebp + wStatusFlags5]
    test al, (1 << (BIT_SCRIPTED_NPC_MOVEMENT))
    jz .nr_248
        ret
.nr_248:
    mov al, 3
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov al, SCRIPT_VIRIDIANCITY_POST_CATCH_TRAINING
    mov [ebp + wViridianCityCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
ViridianCity_TextPointers:
    dd ViridianCityYoungster1Text
    dd ViridianCityGambler1Text
    dd ViridianCityYoungster2Text
    dd ViridianCityGirlText
    dd ViridianCityOldManSleepyText
    dd ViridianCityFisherText
    dd ViridianCityOldManText
    dd ViridianCityOldMan2Text
    dd ViridianCitySignText
    dd ViridianCityTrainerTips1Text
    dd ViridianCityTrainerTips2Text
    dd MartSignText
    dd PokeCenterSignText
    dd ViridianCityGymSignText
    dd ViridianCityGymLockedText
    dd ViridianCityOldManYouNeedToWeakenTheTargetText

%assign event_byte -1
%assign event_byte_a -1
ViridianCityYoungster1Text:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call ViridianCityPrintYoungster1Text
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
ViridianCityGambler1Text:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call ViridianCityPrintGambler1Text
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
ViridianCityYoungster2Text:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call ViridianCityPrintYoungster2Text
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
ViridianCityGirlText:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call ViridianCityPrintGirlText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
ViridianCityOldManSleepyText:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call ViridianCityPrintOldManSleepyText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
ViridianCityFisherText:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call ViridianCityPrintFisherText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
ViridianCityOldManText:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call ViridianCityPrintOldManText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
ViridianCityOldManYouNeedToWeakenTheTargetText:
    text_far _ViridianCityOldManYouNeedToWeakenTheTargetText
    text_end

%assign event_byte -1
%assign event_byte_a -1
ViridianCityOldMan2Text:
    CheckEvent EVENT_COMPLETED_CATCH_TRAINING
    jnz .completed_training
    mov esi, .HadMyCoffeeNowText
    call PrintText
    mov bl, 2
    call DelayFrames
    mov al, SCRIPT_VIRIDIANCITY_OLD_MAN_INITIAL_CATCH_TRAINING
    mov [ebp + wViridianCityCurScript], al
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.completed_training:
    mov esi, .LosingMyTouchText
    call PrintText
.done:
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.HadMyCoffeeNowText:
    text_far _ViridianCityOldManHadMyCoffeeNowText
    text_end
.LosingMyTouchText:
    text_far _ViridianCityOldManLosingMyTouchText
    text_end

%assign event_byte -1
%assign event_byte_a -1
ViridianCitySignText:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call ViridianCityPrintSignText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
ViridianCityTrainerTips1Text:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call ViridianCityPrintTrainerTips1Text
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
ViridianCityTrainerTips2Text:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call ViridianCityPrintTrainerTips2Text
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
ViridianCityGymSignText:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call ViridianCityPrintGymSignText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
ViridianCityGymLockedText:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call ViridianCityPrintGymLockedText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
ViridianCityPrintYoungster1Text:
    mov esi, .text
    call PrintText
    ret

%assign event_byte -1
%assign event_byte_a -1
.text:
    text_far _ViridianCityYoungster1Text
    text_end

%assign event_byte -1
%assign event_byte_a -1
ViridianCityPrintGambler1Text:
    mov esi, .GymLeaderReturnedText
    mov al, [ebp + wObtainedBadges]
    cmp al, ~(1 << 7)
    jz .print_text
    CheckEvent EVENT_BEAT_VIRIDIAN_GYM_GIOVANNI
    jnz .print_text
    mov esi, .GymAlwaysClosedText
.print_text:
    call PrintText
    ret

%assign event_byte -1
%assign event_byte_a -1
.GymAlwaysClosedText:
    text_far _ViridianCityGambler1GymAlwaysClosedText
    text_end
.GymLeaderReturnedText:
    text_far _ViridianCityGambler1GymLeaderReturnedText
    text_end

%assign event_byte -1
%assign event_byte_a -1
ViridianCityPrintYoungster2Text:
    mov esi, .YouWantToKnowAboutText
    call PrintText
    call YesNoChoice
    mov al, [ebp + wCurrentMenuItem]
    test al, al
    mov esi, .OkThenText
    jnz .no
    mov esi, .CaterpieAndWeedleDescriptionText
.no:
    call PrintText
    ret

%assign event_byte -1
%assign event_byte_a -1
.YouWantToKnowAboutText:
    text_far _ViridianCityYoungster2YouWantToKnowAboutText
    text_end
.OkThenText:
    text_far ViridianCityYoungster2OkThenText
    text_end
.CaterpieAndWeedleDescriptionText:
    text_far ViridianCityYoungster2CaterpieAndWeedleDescriptionText
    text_end

%assign event_byte -1
%assign event_byte_a -1
ViridianCityPrintGirlText:
    mov esi, .WhenIGoShopText
    CheckEvent EVENT_GOT_POKEDEX
    jnz .got_pokedex
    mov esi, .HasntHadHisCoffeeYetText
.got_pokedex:
    call PrintText
    ret

%assign event_byte -1
%assign event_byte_a -1
.HasntHadHisCoffeeYetText:
    text_far _ViridianCityGirlHasntHadHisCoffeeYetText
    text_end
.WhenIGoShopText:
    text_far _ViridianCityGirlWhenIGoShopText
    text_end

%assign event_byte -1
%assign event_byte_a -1
ViridianCityPrintOldManSleepyText:
    mov esi, .PrivatePropertyText
    call PrintText
    call StartSimulatingJoypadStates
    mov al, 0x1
    mov [ebp + wSimulatedJoypadStatesIndex], al
    mov al, PAD_DOWN
    mov [ebp + wSimulatedJoypadStatesEnd], al
    mov al, SCRIPT_VIRIDIANCITY_PLAYER_MOVING_DOWN
    mov [ebp + wViridianCityCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
.PrivatePropertyText:
    text_far _ViridianCityOldManSleepyPrivatePropertyText
    text_end

%assign event_byte -1
%assign event_byte_a -1
ViridianCityPrintFisherText:
    CheckEvent EVENT_GOT_TM42
    jnz .got_item
    mov esi, .YouCanHaveThisText
    call PrintText
    mov bx, ((244) << 8) | (1)
    call GiveItem
    jae .bag_full
    mov esi, .ReceivedTM42Text
    call PrintText
    SetEvent EVENT_GOT_TM42
    ret

%assign event_byte -1
%assign event_byte_a -1
.bag_full:
    mov esi, .TM42NoRoomText
    call PrintText
    ret

%assign event_byte -1
%assign event_byte_a -1
.got_item:
    mov esi, .TM42ExplanationText
    call PrintText
    ret

%assign event_byte -1
%assign event_byte_a -1
.YouCanHaveThisText:
    text_far ViridianCityFisherYouCanHaveThisText
    text_end
.ReceivedTM42Text:
    text_far _ViridianCityFisherReceivedTM42Text
    sound_get_item_2
    text_end
.TM42ExplanationText:
    text_far _ViridianCityFisherTM42ExplanationText
    text_end
.TM42NoRoomText:
    text_far _ViridianCityFisherTM42NoRoomText
    text_end

%assign event_byte -1
%assign event_byte_a -1
ViridianCityPrintOldManText:
    mov esi, .WantMeToShowYouAgainText
    call PrintText
    mov bl, 2
    call DelayFrames
    call YesNoChoice
    mov al, [ebp + wCurrentMenuItem]
    test al, al
    jnz .refused
    mov esi, .WatchCloselyText
    call PrintText
    mov al, SCRIPT_VIRIDIANCITY_OLD_MAN_START_CATCH_TRAINING
    mov [ebp + wViridianCityCurScript], al
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.refused:
    mov esi, .NotGoodEnoughForYouText
    call PrintText
.done:
    ret

%assign event_byte -1
%assign event_byte_a -1
.WantMeToShowYouAgainText:
    text_far _ViridianCityOldManWantMeToShowYouAgainText
    text_end
.WatchCloselyText:
    text_far _ViridianCityOldManWatchCloselyText
    text_end
.NotGoodEnoughForYouText:
    text_far _ViridianCityOldManNotGoodEnoughForYouText
    text_end

%assign event_byte -1
%assign event_byte_a -1
ViridianCityPrintSignText:
    mov esi, .text
    call PrintText
    ret

%assign event_byte -1
%assign event_byte_a -1
.text:
    text_far _ViridianCitySignText
    text_end

%assign event_byte -1
%assign event_byte_a -1
ViridianCityPrintTrainerTips1Text:
    mov esi, .text
    call PrintText
    ret

%assign event_byte -1
%assign event_byte_a -1
.text:
    text_far _ViridianCityTrainerTips1Text
    text_end

%assign event_byte -1
%assign event_byte_a -1
ViridianCityPrintTrainerTips2Text:
    mov esi, .text
    call PrintText
    ret

%assign event_byte -1
%assign event_byte_a -1
.text:
    text_far _ViridianCityTrainerTips2Text
    text_end

%assign event_byte -1
%assign event_byte_a -1
ViridianCityPrintGymSignText:
    mov esi, .text
    call PrintText
    ret

%assign event_byte -1
%assign event_byte_a -1
.text:
    text_far _ViridianCityGymSignText
    text_end

%assign event_byte -1
%assign event_byte_a -1
ViridianCityPrintGymLockedText:
    mov esi, .text
    call PrintText
    ret

%assign event_byte -1
%assign event_byte_a -1
.text:
    text_far _ViridianCityGymLockedText
    text_end

%assign event_byte -1
%assign event_byte_a -1
ViridianCityMovePikachu:
    mov esi, ViridianCityPikachuMovementData
    mov bh, SPRITE_FACING_RIGHT
    call TryApplyPikachuMovementData
    ret

%assign event_byte -1
%assign event_byte_a -1
ViridianCityPikachuMovementData:
    db 0x00
    db 0x1d
    db 0x1f
    db 0x38
    db 0x3f
