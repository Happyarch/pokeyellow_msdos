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

extern Bankswitch   ; NOT YET DEFINED IN THE PORT
extern CallFunctionInTable   ; NOT YET DEFINED IN THE PORT
extern Delay3   ; NOT YET DEFINED IN THE PORT
extern DelayFrames   ; NOT YET DEFINED IN THE PORT
extern DisplayTextID   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern GiveItem   ; NOT YET DEFINED IN THE PORT
extern HideObject   ; NOT YET DEFINED IN THE PORT
extern MartSignText   ; NOT YET DEFINED IN THE PORT
extern MoveSprite   ; NOT YET DEFINED IN THE PORT
extern PokeCenterSignText   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern SetSpriteFacingDirectionAndDelay   ; NOT YET DEFINED IN THE PORT
extern StartSimulatingJoypadStates   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern TryApplyPikachuMovementData   ; NOT YET DEFINED IN THE PORT
extern UpdateSprites   ; NOT YET DEFINED IN THE PORT
extern ViridianCityFisherYouCanHaveThisText   ; NOT YET DEFINED IN THE PORT
extern ViridianCityPostInitialCatchTraining   ; NOT YET DEFINED IN THE PORT
extern ViridianCityPrintFisherText   ; NOT YET DEFINED IN THE PORT
extern ViridianCityYoungster2CaterpieAndWeedleDescriptionText   ; NOT YET DEFINED IN THE PORT
extern ViridianCityYoungster2OkThenText   ; NOT YET DEFINED IN THE PORT
extern YesNoChoice   ; NOT YET DEFINED IN THE PORT
extern _ViridianCityFisherReceivedTM42Text   ; NOT YET DEFINED IN THE PORT
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

ViridianCity_Script:
    call EnableAutoTextBoxDrawing
    mov esi, ViridianCity_ScriptPointers
    mov al, [ebp + wViridianCityCurScript]
    call CallFunctionInTable
    ret

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

ViridianCityDefaultScript:
    call ViridianCityCheckGymOpenScript
    call ViridianCityCheckSleepingOldMan
    ret

ViridianCityAfterPokedexScript:
    call ViridianCityCheckWaitingOldMan
ViridianCityPostCatchTraining:
    call ViridianCityCheckGymOpenScript
    ret

ViridianCityCheckGymOpenScript:
    CheckEvent EVENT_VIRIDIAN_GYM_OPEN
    jz .nr_35
        ret
.nr_35:
    mov al, [ebp + W_OBTAINED_BADGES]
    cmp al, ~(1 << 7)
    jnz .gym_closed
    SetEvent EVENT_VIRIDIAN_GYM_OPEN
    ret

.gym_closed:
    mov al, [ebp + W_Y_COORD]
    cmp al, 8
    jz .nr_44
        ret
.nr_44:
    mov al, [ebp + W_X_COORD]
    cmp al, 32
    jz .nr_47
        ret
.nr_47:
    mov al, TEXT_VIRIDIANCITY_GYM_LOCKED
    mov [ebp + hTextID], al
    call DisplayTextID
    call StartSimulatingJoypadStates
    mov al, 0x1
    mov [ebp + W_SIMULATED_JOYPAD_STATES_INDEX], al
    mov al, PAD_DOWN
    mov [ebp + W_SIMULATED_JOYPAD_STATES_END], al
    xor al, al
    mov [ebp + wSpritePlayerStateData1FacingDirection], al
    mov [ebp + wJoyIgnore], al
    mov [ebp + hJoyHeld], al
    mov al, SCRIPT_VIRIDIANCITY_PLAYER_MOVING_DOWN_POST_TRAINING
    mov [ebp + wViridianCityCurScript], al
    ret

ViridianCityPlayerMovingDownPostTrainingScript:
    mov al, [ebp + W_SIMULATED_JOYPAD_STATES_INDEX]
    test al, al
    jz .nr_67
        ret
.nr_67:
    call Delay3
    mov al, SCRIPT_VIRIDIANCITY_POST_CATCH_TRAINING
    mov [ebp + wViridianCityCurScript], al
    ret

ViridianCityCheckSleepingOldMan:
    mov al, [ebp + W_Y_COORD]
    cmp al, 9
    jz .nr_76
        ret
.nr_76:
    mov al, [ebp + W_X_COORD]
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

ViridianCityOldManStartCatchTrainingScript:
    call .SetupSprite
    call .SetupBattle
    ResetEvent EVENT_INITIAL_CATCH_TRAINING
    mov al, SCRIPT_VIRIDIANCITY_OLD_MAN_END_CATCH_TRAINING
    mov [ebp + wViridianCityCurScript], al
    ret

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

ViridianCityPlayerMovingDownScript:
    mov al, [ebp + W_SIMULATED_JOYPAD_STATES_INDEX]
    test al, al
    jz .nr_151
        ret
.nr_151:
    call Delay3
    mov al, SCRIPT_VIRIDIANCITY_DEFAULT
    mov [ebp + wViridianCityCurScript], al
    ret

ViridianCityMovePlayerDownScript:
    call StartSimulatingJoypadStates
    mov al, 0x1
    mov [ebp + W_SIMULATED_JOYPAD_STATES_INDEX], al
    mov al, PAD_DOWN
    mov [ebp + W_SIMULATED_JOYPAD_STATES_END], al
    xor al, al
    mov [ebp + wSpritePlayerStateData1FacingDirection], al
    mov [ebp + wJoyIgnore], al
    ret

ViridianCityCheckWaitingOldMan:
    CheckEvent EVENT_COMPLETED_CATCH_TRAINING
    jz .nr_170
        ret
.nr_170:
    mov al, [ebp + W_Y_COORD]
    cmp al, 9
    jz .nr_173
        ret
.nr_173:
    mov al, [ebp + W_X_COORD]
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

ViridianCityOldManInitialCatchTrainingScript:
    call ViridianCityOldManStartCatchTrainingScript.SetupSprite
    call ViridianCityOldManStartCatchTrainingScript.SetupBattle
    SetEvent EVENT_INITIAL_CATCH_TRAINING
    mov al, PAD_SELECT | PAD_START | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, SCRIPT_VIRIDIANCITY_OLD_MAN_END_INITIAL_CATCH_TRAINING
    mov [ebp + wViridianCityCurScript], al
    ret

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

; ---------------------------------------------------------------------------
; BAIL[host-pointer-in-16bit-reg] ViridianCityPostInitialCatchTraining (scripts/ViridianCity.asm:220-232) — at scripts/ViridianCity.asm:220: de cannot hold the 32-bit address of ViridianCityOldManMovementData2; callee <none in range> has no abi.json entry
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld de, ViridianCityOldManMovementData2
; PRET| 	ld a, [wXCoord]
; PRET| 	cp 19
; PRET| 	jr z, .move_old_man
; PRET| 	callfar ViridianCityMovePikachu
; PRET| 	ld de, ViridianCityOldManMovementData1
; PRET| .move_old_man
; PRET| 	ld a, VIRIDIANCITY_OLD_MAN2
; PRET| 	ldh [hSpriteIndex], a
; PRET| 	call MoveSprite
; PRET| 	ld a, SCRIPT_VIRIDIANCITY_OLD_MAN_MOVING_DOWN
; PRET| 	ld [wViridianCityCurScript], a
; PRET| 	ret

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

ViridianCityOldManMovingDownScript:
    mov al, [ebp + wStatusFlags5]
    test al, (1 << (BIT_SCRIPTED_NPC_MOVEMENT))
    jz .nr_248
        ret
.nr_248:
    mov al, 3
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and the predef id is not left in A because no reader is live; evidence=PredefPointers is unported and the flat model needs no bank switch, dataflow shows A dead after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov al, SCRIPT_VIRIDIANCITY_POST_CATCH_TRAINING
    mov [ebp + wViridianCityCurScript], al
    ret

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

ViridianCityYoungster1Text:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call ViridianCityPrintYoungster1Text
    jmp TextScriptEnd

ViridianCityGambler1Text:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call ViridianCityPrintGambler1Text
    jmp TextScriptEnd

ViridianCityYoungster2Text:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call ViridianCityPrintYoungster2Text
    jmp TextScriptEnd

ViridianCityGirlText:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call ViridianCityPrintGirlText
    jmp TextScriptEnd

ViridianCityOldManSleepyText:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call ViridianCityPrintOldManSleepyText
    jmp TextScriptEnd

ViridianCityFisherText:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call ViridianCityPrintFisherText
    jmp TextScriptEnd

ViridianCityOldManText:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call ViridianCityPrintOldManText
    jmp TextScriptEnd

ViridianCityOldManYouNeedToWeakenTheTargetText:
    text_far _ViridianCityOldManYouNeedToWeakenTheTargetText
    text_end

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

.completed_training:
    mov esi, .LosingMyTouchText
    call PrintText
.done:
    jmp TextScriptEnd

.HadMyCoffeeNowText:
    text_far _ViridianCityOldManHadMyCoffeeNowText
    text_end
.LosingMyTouchText:
    text_far _ViridianCityOldManLosingMyTouchText
    text_end

ViridianCitySignText:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call ViridianCityPrintSignText
    jmp TextScriptEnd

ViridianCityTrainerTips1Text:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call ViridianCityPrintTrainerTips1Text
    jmp TextScriptEnd

ViridianCityTrainerTips2Text:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call ViridianCityPrintTrainerTips2Text
    jmp TextScriptEnd

ViridianCityGymSignText:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call ViridianCityPrintGymSignText
    jmp TextScriptEnd

ViridianCityGymLockedText:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call ViridianCityPrintGymLockedText
    jmp TextScriptEnd

ViridianCityPrintYoungster1Text:
    mov esi, .text
    call PrintText
    ret

.text:
    text_far _ViridianCityYoungster1Text
    text_end

ViridianCityPrintGambler1Text:
    mov esi, .GymLeaderReturnedText
    mov al, [ebp + W_OBTAINED_BADGES]
    cmp al, ~(1 << 7)
    jz .print_text
    CheckEvent EVENT_BEAT_VIRIDIAN_GYM_GIOVANNI
    jnz .print_text
    mov esi, .GymAlwaysClosedText
.print_text:
    call PrintText
    ret

.GymAlwaysClosedText:
    text_far _ViridianCityGambler1GymAlwaysClosedText
    text_end
.GymLeaderReturnedText:
    text_far _ViridianCityGambler1GymLeaderReturnedText
    text_end

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

.YouWantToKnowAboutText:
    text_far _ViridianCityYoungster2YouWantToKnowAboutText
    text_end
.OkThenText:
    text_far ViridianCityYoungster2OkThenText
    text_end
.CaterpieAndWeedleDescriptionText:
    text_far ViridianCityYoungster2CaterpieAndWeedleDescriptionText
    text_end

ViridianCityPrintGirlText:
    mov esi, .WhenIGoShopText
    CheckEvent EVENT_GOT_POKEDEX
    jnz .got_pokedex
    mov esi, .HasntHadHisCoffeeYetText
.got_pokedex:
    call PrintText
    ret

.HasntHadHisCoffeeYetText:
    text_far _ViridianCityGirlHasntHadHisCoffeeYetText
    text_end
.WhenIGoShopText:
    text_far _ViridianCityGirlWhenIGoShopText
    text_end

ViridianCityPrintOldManSleepyText:
    mov esi, .PrivatePropertyText
    call PrintText
    call StartSimulatingJoypadStates
    mov al, 0x1
    mov [ebp + W_SIMULATED_JOYPAD_STATES_INDEX], al
    mov al, PAD_DOWN
    mov [ebp + W_SIMULATED_JOYPAD_STATES_END], al
    mov al, SCRIPT_VIRIDIANCITY_PLAYER_MOVING_DOWN
    mov [ebp + wViridianCityCurScript], al
    ret

.PrivatePropertyText:
    text_far _ViridianCityOldManSleepyPrivatePropertyText
    text_end

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] ViridianCityPrintFisherText (scripts/ViridianCity_2.asm:89-99) — at scripts/ViridianCity_2.asm:90: .got_item is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_GOT_TM42
; PRET| 	jr nz, .got_item
; PRET| 	ld hl, .YouCanHaveThisText
; PRET| 	call PrintText
; PRET| 	lb bc, TM_DREAM_EATER, 1
; PRET| 	call GiveItem
; PRET| 	jr nc, .bag_full
; PRET| 	ld hl, .ReceivedTM42Text
; PRET| 	call PrintText
; PRET| 	SetEvent EVENT_GOT_TM42
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] ViridianCityPrintFisherText.bag_full (scripts/ViridianCity_2.asm:101-103) — at scripts/ViridianCity_2.asm:101: .TM42NoRoomText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .TM42NoRoomText
; PRET| 	call PrintText
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] ViridianCityPrintFisherText.got_item (scripts/ViridianCity_2.asm:105-107) — at scripts/ViridianCity_2.asm:105: .TM42ExplanationText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .TM42ExplanationText
; PRET| 	call PrintText
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[text-sound-command-unported] ViridianCityPrintFisherText.YouCanHaveThisText (scripts/ViridianCity_2.asm:110-124) — at scripts/ViridianCity_2.asm:115: sound_get_item_2
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far ViridianCityFisherYouCanHaveThisText
; PRET| 	text_end
; PRET| 
; PRET| .ReceivedTM42Text:
; PRET| 	text_far _ViridianCityFisherReceivedTM42Text
; PRET| 	sound_get_item_2
; PRET| 	text_end
; PRET| 
; PRET| .TM42ExplanationText:
; PRET| 	text_far _ViridianCityFisherTM42ExplanationText
; PRET| 	text_end
; PRET| 
; PRET| .TM42NoRoomText:
; PRET| 	text_far _ViridianCityFisherTM42NoRoomText
; PRET| 	text_end

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

.refused:
    mov esi, .NotGoodEnoughForYouText
    call PrintText
.done:
    ret

.WantMeToShowYouAgainText:
    text_far _ViridianCityOldManWantMeToShowYouAgainText
    text_end
.WatchCloselyText:
    text_far _ViridianCityOldManWatchCloselyText
    text_end
.NotGoodEnoughForYouText:
    text_far _ViridianCityOldManNotGoodEnoughForYouText
    text_end

ViridianCityPrintSignText:
    mov esi, .text
    call PrintText
    ret

.text:
    text_far _ViridianCitySignText
    text_end

ViridianCityPrintTrainerTips1Text:
    mov esi, .text
    call PrintText
    ret

.text:
    text_far _ViridianCityTrainerTips1Text
    text_end

ViridianCityPrintTrainerTips2Text:
    mov esi, .text
    call PrintText
    ret

.text:
    text_far _ViridianCityTrainerTips2Text
    text_end

ViridianCityPrintGymSignText:
    mov esi, .text
    call PrintText
    ret

.text:
    text_far _ViridianCityGymSignText
    text_end

ViridianCityPrintGymLockedText:
    mov esi, .text
    call PrintText
    ret

.text:
    text_far _ViridianCityGymLockedText
    text_end

ViridianCityMovePikachu:
    mov esi, ViridianCityPikachuMovementData
    mov bh, SPRITE_FACING_RIGHT
    call TryApplyPikachuMovementData
    ret

ViridianCityPikachuMovementData:
    db 0x00
    db 0x1d
    db 0x1f
    db 0x38
    db 0x3f
