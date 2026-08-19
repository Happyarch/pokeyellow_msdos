; MtMoonB2F.asm — translated from pret scripts/MtMoonB2F.asm, scripts/MtMoonB2F_2.asm by dos_port/tools/sm83xlat.
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
; Trainer headers and battle text are DEFINED once, by the single carrier
; src/data/trainer_headers.asm. Declare what this script uses; do NOT %include
; assets/trainer_headers.inc here — the asset DEFINES all 1302 symbols, so an
; include makes every one of them a duplicate global the moment a second script
; links. (That is what kept 202 link-ready scripts out of the build.)
extern MtMoon3TrainerHeader0      ; assets/trainer_headers.inc
extern MtMoon3TrainerHeader1      ; assets/trainer_headers.inc
extern MtMoon3TrainerHeader2      ; assets/trainer_headers.inc
extern MtMoon3TrainerHeaders      ; assets/trainer_headers.inc
extern MtMoonB2FRocket2BattleText ; assets/trainer_headers.inc

global CoordsData_49dc0
global CoordsData_49dc7
global CoordsData_49dce
global CoordsData_49dd5
global MovementData_49ddc
global MovementData_49ddd
global MovementData_f9e65
global MovementData_f9e66
global MtMoonB2FDefeatedSuperNerdScript
global MtMoonB2FDomeFossilText
global MtMoonB2FFossilAreaCoords
global MtMoonB2FJessieJamesEndBattleText
global MtMoonB2FMoveSuperNerdScript
global MtMoonB2FReceivedFossilText
global MtMoonB2FResetScripts
global MtMoonB2FRocket1Text
global MtMoonB2FRocket2Text
global MtMoonB2FRocket3Text
global MtMoonB2FScript10
global MtMoonB2FScript11
global MtMoonB2FScript12
global MtMoonB2FScript13
global MtMoonB2FScript14
global MtMoonB2FScript15
global MtMoonB2FScript6
global MtMoonB2FScript7
global MtMoonB2FScript8
global MtMoonB2FScript9
global MtMoonB2FScript_49d28
global MtMoonB2FScript_49e15
global MtMoonB2FScript_ApplyPikachuMovementData
global MtMoonB2FScript_HideJessieJames
global MtMoonB2FScript_HideObject
global MtMoonB2FScript_ShowObject
global MtMoonB2FSetScript
global MtMoonB2FSuperNerdTakesOtherFossilScript
global MtMoonB2FTalkToTrainer
global MtMoonB2FText13
global MtMoonB2FText14
global MtMoonB2F_Script
global MtMoonB2F_ScriptPointers
global PikachuMovementData_49dca
global PikachuMovementData_49dd8

extern ApplyPikachuMovementData
extern ArePlayerCoordsInArray
extern Bankswitch
extern CheckFightingMapTrainers
extern Delay3
extern DelayFrames
extern DisplayEnemyTrainerTextAndStartBattle
extern DisplayTextID
extern EmotionBubble
extern EnableAutoTextBoxDrawing
extern EndTrainerBattle
extern EngageMapTrainer
extern ExecuteCurMapScriptInTable
extern GBFadeInFromBlack
extern GBFadeOutToBlack
extern GetPikachuFacingDirectionAndReturnToE   ; NOT YET DEFINED IN THE PORT
extern GiveItem
extern HideObject
extern InitBattleEnemyParameters
extern LoadPikachuShadowIntoVRAM   ; NOT YET DEFINED IN THE PORT
extern MoveSprite
extern MtMoon3TrainerHeader0
extern MtMoon3TrainerHeader1
extern MtMoon3TrainerHeader2
extern MtMoon3TrainerHeaders
extern MtMoonB2FDefaultScript   ; NOT YET DEFINED IN THE PORT
extern MtMoonB2FHelixFossilText   ; NOT YET DEFINED IN THE PORT
extern MtMoonB2FRocket2BattleText
extern MtMoonB2FSuperNerdOkIllShareText   ; NOT YET DEFINED IN THE PORT
extern MtMoonB2FSuperNerdText   ; NOT YET DEFINED IN THE PORT
extern MtMoonB2FSuperNerdTheresAPokemonLabText   ; NOT YET DEFINED IN THE PORT
extern MtMoonB2FSuperNerdTheyreBothMineText   ; NOT YET DEFINED IN THE PORT
extern MtMoonB2FYouHaveNoRoomText   ; NOT YET DEFINED IN THE PORT
extern MtMoonB2F_TextPointers   ; NOT YET DEFINED IN THE PORT
extern MtMoonB2fSuperNerdEachTakeOneText   ; NOT YET DEFINED IN THE PORT
extern PlayDefaultMusic
extern PlayMusic
extern PrintText
extern SaveEndBattleTextPointers
extern SetSpriteMovementBytesToFF
extern ShowObject
extern StartSimulatingJoypadStates
extern StopAllMusic
extern TalkToTrainer
extern TextScriptEnd
extern UpdateSprites
extern YesNoChoice

; Script constants — pret defines these via dw_const in this file.
SCRIPT_MTMOONB2F_DEFAULT                       equ 0
SCRIPT_MTMOONB2F_DEFEATED_SUPER_NERD           equ 3
SCRIPT_MTMOONB2F_MOVE_SUPER_NERD               equ 4
SCRIPT_MTMOONB2F_SUPER_NERD_TAKES_OTHER_FOSSIL equ 5
SCRIPT_MTMOONB2F_SCRIPT6                       equ 6
SCRIPT_MTMOONB2F_SCRIPT7                       equ 7
SCRIPT_MTMOONB2F_SCRIPT10                      equ 10
SCRIPT_MTMOONB2F_SCRIPT13                      equ 13
SCRIPT_MTMOONB2F_SCRIPT14                      equ 14
SCRIPT_MTMOONB2F_SCRIPT15                      equ 15
TEXT_MTMOONB2F_SUPER_NERD                      equ 1
TEXT_MTMOONB2F_SUPER_NERD_THEN_THIS_IS_MINE    equ 11
TEXT_MTMOONB2F_TEXT12                          equ 12
TEXT_MTMOONB2F_TEXT13                          equ 13
TEXT_MTMOONB2F_TEXT14                          equ 14

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
; Far text streams for this map — pret text/mt_moon_b_2f, generated by
; tools/generators/gen_map_text.py. Defined HERE because every one is used
; only by this script, exactly as pret keeps text/<Map>.asm beside scripts/<Map>.asm.
section .data
%include "assets/map_text/mt_moon_b_2f.inc"

section .text

%assign event_byte -1
%assign event_byte_a -1
MtMoonB2F_Script:
    call EnableAutoTextBoxDrawing
    mov esi, MtMoon3TrainerHeaders
    mov edi, MtMoonB2F_ScriptPointers   ; pret: ld de, MtMoonB2F_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wMtMoonB2FCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wMtMoonB2FCurScript], al
    CheckEvent EVENT_BEAT_MT_MOON_EXIT_SUPER_NERD
    jnz .nr_9
        ret
.nr_9:
    mov esi, MtMoonB2FFossilAreaCoords
    call ArePlayerCoordsInArray
    jae .enable_battles
    mov esi, wStatusFlags4
    or byte [ebp + esi], (1 << (BIT_NO_BATTLES))
    ret

%assign event_byte -1
%assign event_byte_a -1
.enable_battles:
    mov esi, wStatusFlags4
    and byte [ebp + esi], ~(1 << (BIT_NO_BATTLES)) & 0xFF
    ret

%assign event_byte -1
%assign event_byte_a -1
MtMoonB2FFossilAreaCoords:
    db 5, 11
    db 5, 12
    db 5, 13
    db 5, 14
    db 6, 11
    db 6, 12
    db 6, 13
    db 6, 14
    db 7, 11
    db 7, 12
    db 7, 13
    db 7, 14
    db 8, 11
    db 8, 12
    db 8, 13
    db 8, 14
    db -1

%assign event_byte -1
%assign event_byte_a -1
MtMoonB2FResetScripts:
    CheckAndResetEvent EVENT_57E
    jz .sk_42
        call MtMoonB2FScript_HideJessieJames
.sk_42:
    xor al, al
    mov [ebp + wJoyIgnore], al
MtMoonB2FSetScript:
    mov [ebp + wMtMoonB2FCurScript], al
    mov [ebp + wCurMapScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
MtMoonB2FScript_HideJessieJames:
    mov al, 109
    call MtMoonB2FScript_HideObject
    mov al, 110
    call MtMoonB2FScript_HideObject
    ret

%assign event_byte -1
%assign event_byte_a -1
MtMoonB2F_ScriptPointers:
    dd MtMoonB2FDefaultScript
    dd DisplayEnemyTrainerTextAndStartBattle
    dd EndTrainerBattle
    dd MtMoonB2FDefeatedSuperNerdScript
    dd MtMoonB2FMoveSuperNerdScript
    dd MtMoonB2FSuperNerdTakesOtherFossilScript
    dd MtMoonB2FScript6
    dd MtMoonB2FScript7
    dd MtMoonB2FScript8
    dd MtMoonB2FScript9
    dd MtMoonB2FScript10
    dd MtMoonB2FScript11
    dd MtMoonB2FScript12
    dd MtMoonB2FScript13
    dd MtMoonB2FScript14
    dd MtMoonB2FScript15

%assign event_byte -1
%assign event_byte_a -1
    CheckEitherEventSet EVENT_GOT_DOME_FOSSIL, EVENT_GOT_HELIX_FOSSIL
    jnz .sk_82
        call MtMoonB2FScript_49d28
.sk_82:
    CheckEvent EVENT_BEAT_MT_MOON_3_JESSIE_JAMES
    jnz .sk_84
        call MtMoonB2FScript_49e15
.sk_84:
    ret

%assign event_byte -1
%assign event_byte_a -1
MtMoonB2FScript_49d28:
    CheckEvent EVENT_BEAT_MT_MOON_EXIT_SUPER_NERD
    jnz .asm_49d4b
    mov al, [ebp + wYCoord]
    cmp al, 8
    jnz .asm_49d4b
    mov al, [ebp + wXCoord]
    cmp al, 13
    jnz .asm_49d4b
    xor al, al
    mov [ebp + hJoyHeld], al
    mov al, TEXT_MTMOONB2F_SUPER_NERD
    mov [ebp + hTextID], al
    call DisplayTextID
    ret

%assign event_byte -1
%assign event_byte_a -1
.asm_49d4b:
    CheckEitherEventSet EVENT_GOT_DOME_FOSSIL, EVENT_GOT_HELIX_FOSSIL
    jz CheckFightingMapTrainers
    ret

%assign event_byte -1
%assign event_byte_a -1
MtMoonB2FDefeatedSuperNerdScript:
    mov al, [ebp + wIsInBattle]
    cmp al, 0xff
    jz MtMoonB2FResetScripts
    call UpdateSprites
    call Delay3
    SetEvent EVENT_BEAT_MT_MOON_EXIT_SUPER_NERD
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov al, SCRIPT_MTMOONB2F_DEFAULT
    call MtMoonB2FSetScript
    ret

%assign event_byte -1
%assign event_byte_a -1
MtMoonB2FMoveSuperNerdScript:
    mov al, 1
    mov [ebp + hSpriteIndex], al
    call SetSpriteMovementBytesToFF
    mov esi, CoordsData_49dc7
    call ArePlayerCoordsInArray
    jb .asm_49da8
    mov esi, CoordsData_49dc0
    call ArePlayerCoordsInArray
    jb .asm_49db0
    mov esi, CoordsData_49dd5
    call ArePlayerCoordsInArray
    jb .asm_49d9b
    mov esi, CoordsData_49dce
    call ArePlayerCoordsInArray
    jb .asm_49da3
    jmp CheckFightingMapTrainers

%assign event_byte -1
%assign event_byte_a -1
.asm_49d9b:
    mov bh, SPRITE_FACING_LEFT
    mov esi, PikachuMovementData_49dd8
    call MtMoonB2FScript_ApplyPikachuMovementData
.asm_49da3:
    mov edi, MovementData_49ddd   ; pret: ld de, MovementData_49ddd — MoveSprite takes it in EDI
    jmp .asm_49db3

%assign event_byte -1
%assign event_byte_a -1
.asm_49da8:
    mov bh, SPRITE_FACING_RIGHT
    mov esi, PikachuMovementData_49dca
    call MtMoonB2FScript_ApplyPikachuMovementData
.asm_49db0:
    mov edi, MovementData_49ddc   ; pret: ld de, MovementData_49ddc — MoveSprite takes it in EDI
.asm_49db3:
    mov al, 1
    mov [ebp + hSpriteIndex], al
    call MoveSprite
    mov al, SCRIPT_MTMOONB2F_SUPER_NERD_TAKES_OTHER_FOSSIL
    call MtMoonB2FSetScript
    ret

%assign event_byte -1
%assign event_byte_a -1
CoordsData_49dc0:
    db 7, 12
    db 6, 11
    db 5, 12
    db -1
CoordsData_49dc7:
    db 7, 12
    db -1
PikachuMovementData_49dca:
    db 0x00
    db 0x35
    db 0x33
    db 0x3f
CoordsData_49dce:
    db 7, 13
    db 6, 14
    db 5, 14
    db -1
CoordsData_49dd5:
    db 7, 13
    db -1
PikachuMovementData_49dd8:
    db 0x00
    db 0x35
    db 0x34
    db 0x3f
MovementData_49ddc:
    db NPC_MOVEMENT_RIGHT
MovementData_49ddd:
    db NPC_MOVEMENT_UP
    db -1

%assign event_byte -1
%assign event_byte_a -1
MtMoonB2FSuperNerdTakesOtherFossilScript:
    mov al, [ebp + wStatusFlags5]
    test al, (1 << (BIT_SCRIPTED_NPC_MOVEMENT))
    jz .nr_202
        ret
.nr_202:
    mov al, PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, 0x1
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    mov al, TEXT_MTMOONB2F_SUPER_NERD_THEN_THIS_IS_MINE
    mov [ebp + hTextID], al
    call DisplayTextID
    CheckEvent EVENT_GOT_HELIX_FOSSIL
    jz .got_helix_fossil
    mov al, 111
    jmp .continue

%assign event_byte -1
%assign event_byte_a -1
.got_helix_fossil:
    mov al, 112
.continue:
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov al, SCRIPT_MTMOONB2F_DEFAULT
    call MtMoonB2FSetScript
    ret

%assign event_byte -1
%assign event_byte_a -1
MtMoonB2FScript_49e15:
    mov al, [ebp + wXCoord]
    cmp al, 0x3
    jz .nr_228
        ret
.nr_228:
    mov al, [ebp + wYCoord]
    cmp al, 0x5
    jz .nr_231
        ret
.nr_231:
    call StopAllMusic
    mov bl, 32
    mov al, MUSIC_MEET_JESSIE_JAMES
    call PlayMusic
    xor al, al
    mov [ebp + hJoyHeld], al
    mov al, PAD_SELECT | PAD_START | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, 109
    call MtMoonB2FScript_ShowObject
    mov al, 110
    call MtMoonB2FScript_ShowObject
    mov al, 0x1
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    mov al, TEXT_MTMOONB2F_TEXT12
    mov [ebp + hTextID], al
    call DisplayTextID
    xor al, al
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    mov al, 0x1
    mov [ebp + wSimulatedJoypadStatesIndex], al
    mov al, PAD_UP
    mov [ebp + wSimulatedJoypadStatesEnd], al
    call StartSimulatingJoypadStates
    mov al, PAD_BUTTONS | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, SCRIPT_MTMOONB2F_SCRIPT6
    call MtMoonB2FSetScript
    ret

%assign event_byte -1
%assign event_byte_a -1
MovementData_f9e65:
    db 0x06
MovementData_f9e66:
    db 0x06
    db 0x06
    db 0x06
    db 0x06
    db 0x06
    db 0xFF

%assign event_byte -1
%assign event_byte_a -1
MtMoonB2FScript6:
    mov al, PAD_BUTTONS | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, [ebp + wSimulatedJoypadStatesIndex]
    test al, al
    jz .nr_277
        ret
.nr_277:
    call Delay3
    mov al, 2
    mov [ebp + hSpriteIndex], al
    mov edi, MovementData_f9e65   ; pret: ld de, MovementData_f9e65 — MoveSprite takes it in EDI
    call MoveSprite
    mov al, PAD_BUTTONS | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, SCRIPT_MTMOONB2F_SCRIPT7
    call MtMoonB2FSetScript
    ret

%assign event_byte -1
%assign event_byte_a -1
MtMoonB2FScript7:
    mov al, PAD_BUTTONS | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, [ebp + wStatusFlags5]
    test al, (1 << (BIT_SCRIPTED_NPC_MOVEMENT))
    jz .nr_294
        ret
.nr_294:
MtMoonB2FScript8:
    mov al, 0x2
    mov [ebp + wSprite02StateData1MovementStatus], al
    mov al, SPRITE_FACING_DOWN
    mov [ebp + wSprite02StateData1FacingDirection], al
MtMoonB2FScript9:
    mov al, 6
    mov [ebp + hSpriteIndex], al
    mov edi, MovementData_f9e66   ; pret: ld de, MovementData_f9e66 — MoveSprite takes it in EDI
    call MoveSprite
    mov al, PAD_BUTTONS | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, SCRIPT_MTMOONB2F_SCRIPT10
    call MtMoonB2FSetScript
    ret

%assign event_byte -1
%assign event_byte_a -1
MtMoonB2FScript10:
    mov al, PAD_BUTTONS | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, [ebp + wStatusFlags5]
    test al, (1 << (BIT_SCRIPTED_NPC_MOVEMENT))
    jz .nr_316
        ret
.nr_316:
MtMoonB2FScript11:
    mov al, 0x2
    mov [ebp + wSprite06StateData1MovementStatus], al
    mov al, SPRITE_FACING_LEFT
    mov [ebp + wSprite06StateData1FacingDirection], al
    call Delay3
    mov al, PAD_SELECT | PAD_START | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, TEXT_MTMOONB2F_TEXT13
    mov [ebp + hTextID], al
    call DisplayTextID
MtMoonB2FScript12:
    mov esi, wStatusFlags3
    or byte [ebp + esi], (1 << (BIT_TALKED_TO_TRAINER))
    or byte [ebp + esi], (1 << (BIT_PRINT_END_BATTLE_TEXT))
    mov esi, MtMoonB2FJessieJamesEndBattleText
    mov edx, MtMoonB2FJessieJamesEndBattleText   ; pret: ld de, MtMoonB2FJessieJamesEndBattleText — SaveEndBattleTextPointers takes it in EDX
    call SaveEndBattleTextPointers
    mov al, OPP_ROCKET
    mov [ebp + wCurOpponent], al
    mov al, 0x2a
    mov [ebp + wTrainerNo], al
    xor al, al
    mov [ebp + hJoyHeld], al
    mov [ebp + wJoyIgnore], al
    SetEvent EVENT_57E
    mov al, SCRIPT_MTMOONB2F_SCRIPT13
    call MtMoonB2FSetScript
    ret

%assign event_byte -1
%assign event_byte_a -1
MtMoonB2FScript13:
    mov al, PAD_BUTTONS | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, [ebp + wIsInBattle]
    cmp al, 0xff
    jz MtMoonB2FResetScripts
    mov al, 0x2
    mov [ebp + wSprite02StateData1MovementStatus], al
    mov [ebp + wSprite06StateData1MovementStatus], al
    xor al, al
    mov [ebp + wSprite02StateData1FacingDirection], al
    mov [ebp + wSprite06StateData1FacingDirection], al
    mov al, PAD_SELECT | PAD_START | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, 0x1
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    mov al, TEXT_MTMOONB2F_TEXT14
    mov [ebp + hTextID], al
    call DisplayTextID
    xor al, al
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    call StopAllMusic
    mov bl, 32
    mov al, MUSIC_MEET_JESSIE_JAMES
    call PlayMusic
    mov al, PAD_BUTTONS | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, SCRIPT_MTMOONB2F_SCRIPT14
    call MtMoonB2FSetScript
    ret

%assign event_byte -1
%assign event_byte_a -1
MtMoonB2FScript14:
    mov al, PAD_BUTTONS | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    call GBFadeOutToBlack
    mov al, 109
    call MtMoonB2FScript_HideObject
    mov al, 110
    call MtMoonB2FScript_HideObject
    call UpdateSprites
    call Delay3
    call GBFadeInFromBlack
    mov al, SCRIPT_MTMOONB2F_SCRIPT15
    call MtMoonB2FSetScript
    ret

%assign event_byte -1
%assign event_byte_a -1
MtMoonB2FScript15:
    call PlayDefaultMusic
    xor al, al
    mov [ebp + hJoyHeld], al
    mov [ebp + wJoyIgnore], al
    SetEvent EVENT_BEAT_MT_MOON_3_JESSIE_JAMES
    ResetEventReuseHL EVENT_57E
    mov al, SCRIPT_MTMOONB2F_DEFAULT
    call MtMoonB2FSetScript
    ret

%assign event_byte -1
%assign event_byte_a -1
MtMoonB2FScript_ShowObject:
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call ShowObject
    call UpdateSprites
    call Delay3
    ret

%assign event_byte -1
%assign event_byte_a -1
MtMoonB2FScript_HideObject:
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
    ret

; MtMoonB2F_TextPointers (scripts/MtMoonB2F.asm:417-447) — not re-emitted: MtMoon3TrainerHeaders is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
    mov bl, 10
    call DelayFrames
    mov al, PLAYER_DIR_UP
    mov [ebp + wPlayerMovingDirection], al
    mov al, 0x0
    mov [ebp + wEmotionBubbleSpriteIndex], al
    mov al, EXCLAMATION_BUBBLE
    mov [ebp + wWhichEmotionBubble], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call EmotionBubble
    mov bl, 20
    call DelayFrames
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
MtMoonB2FText13:
    text_far _MtMoonJessieJamesText2
    text_end
MtMoonB2FJessieJamesEndBattleText:
    text_far _MtMoonJessieJamesText3
    text_end
MtMoonB2FText14:
    text_far _MtMoonJessieJamesText4

%assign event_byte -1
%assign event_byte_a -1
    mov bl, 64
    call DelayFrames
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[event-macro-reuse-a-hint] MtMoonB2FSuperNerdText (scripts/MtMoonB2F.asm:479-485) — at scripts/MtMoonB2F.asm:481: CheckEitherEventSet EVENT_GOT_DOME_FOSSIL, EVENT_GOT_HELIX_FOSSIL, 1
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_BEAT_MT_MOON_EXIT_SUPER_NERD
; PRET| 	jr z, .beat_super_nerd
; PRET| 	CheckEitherEventSet EVENT_GOT_DOME_FOSSIL, EVENT_GOT_HELIX_FOSSIL, 1
; PRET| 	jr nz, .got_a_fossil
; PRET| 	ld hl, MtMoonB2fSuperNerdEachTakeOneText
; PRET| 	call PrintText
; PRET| 	jr .done

%assign event_byte -1
%assign event_byte_a -1
.beat_super_nerd:
    mov esi, MtMoonB2FSuperNerdTheyreBothMineText
    call PrintText
    mov esi, wStatusFlags3
    or byte [ebp + esi], (1 << (BIT_TALKED_TO_TRAINER))
    or byte [ebp + esi], (1 << (BIT_PRINT_END_BATTLE_TEXT))
    mov esi, MtMoonB2FSuperNerdOkIllShareText
    mov edx, MtMoonB2FSuperNerdOkIllShareText   ; pret: ld de, MtMoonB2FSuperNerdOkIllShareText — SaveEndBattleTextPointers takes it in EDX
    call SaveEndBattleTextPointers
    mov al, [ebp + hSpriteIndex]
    mov [ebp + wSpriteIndex], al
    call EngageMapTrainer
    call InitBattleEnemyParameters
    mov al, SCRIPT_MTMOONB2F_DEFEATED_SUPER_NERD
    call MtMoonB2FSetScript
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.got_a_fossil:
    mov esi, MtMoonB2FSuperNerdTheresAPokemonLabText
    call PrintText
.done:
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
MtMoonB2FRocket1Text:
    mov esi, MtMoon3TrainerHeader0
    jmp MtMoonB2FTalkToTrainer

%assign event_byte -1
%assign event_byte_a -1
MtMoonB2FRocket2Text:
    mov esi, MtMoon3TrainerHeader1
    jmp MtMoonB2FTalkToTrainer

%assign event_byte -1
%assign event_byte_a -1
MtMoonB2FRocket3Text:
    mov esi, MtMoon3TrainerHeader2
MtMoonB2FTalkToTrainer:
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
MtMoonB2FDomeFossilText:
    mov al, 0x1
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    mov esi, .YouWantText
    call PrintText
    call YesNoChoice
    mov al, [ebp + wCurrentMenuItem]
    test al, al
    jnz .done
    mov bx, ((41) << 8) | (1)
    call GiveItem
    jae MtMoonB2FYouHaveNoRoomText
    call MtMoonB2FReceivedFossilText
    mov al, 111
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
    SetEvent EVENT_GOT_DOME_FOSSIL
    mov al, SCRIPT_MTMOONB2F_MOVE_SUPER_NERD
    call MtMoonB2FSetScript
.done:
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.YouWantText:
    text_far _MtMoonB2FDomeFossilYouWantText
    text_end

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] MtMoonB2FHelixFossilText (scripts/MtMoonB2F.asm:554-573) — at scripts/MtMoonB2F.asm:556: .YouWantText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, $1
; PRET| 	ld [wDoNotWaitForButtonPressAfterDisplayingText], a
; PRET| 	ld hl, .YouWantText
; PRET| 	call PrintText
; PRET| 	call YesNoChoice
; PRET| 	ld a, [wCurrentMenuItem]
; PRET| 	and a
; PRET| 	jr nz, .done
; PRET| 	lb bc, HELIX_FOSSIL, 1
; PRET| 	call GiveItem
; PRET| 	jp nc, MtMoonB2FYouHaveNoRoomText
; PRET| 	call MtMoonB2FReceivedFossilText
; PRET| 	ld a, TOGGLE_MT_MOON_B2F_FOSSIL_2
; PRET| 	ld [wToggleableObjectIndex], a
; PRET| 	predef HideObject
; PRET| 	SetEvent EVENT_GOT_HELIX_FOSSIL
; PRET| 	ld a, SCRIPT_MTMOONB2F_MOVE_SUPER_NERD
; PRET| 	call MtMoonB2FSetScript
; PRET| .done
; PRET| 	jp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[local-label-scope-collision] MtMoonB2FHelixFossilText.YouWantText (scripts/MtMoonB2F.asm:576-577)
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _MtMoonB2FHelixFossilYouWantText
; PRET| 	text_end

%assign event_byte -1
%assign event_byte_a -1
MtMoonB2FReceivedFossilText:
    mov esi, .Text
    jmp PrintText

%assign event_byte -1
%assign event_byte_a -1
.Text:
    text_far _MtMoonB2FReceivedFossilText
    sound_get_key_item
    text_waitbutton
    text_end

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] MtMoonB2FYouHaveNoRoomText (scripts/MtMoonB2F.asm:590-592) — at scripts/MtMoonB2F.asm:590: .Text is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .Text
; PRET| 	call PrintText
; PRET| 	jp TextScriptEnd

; MtMoonB2FYouHaveNoRoomText.Text (scripts/MtMoonB2F.asm:595-654) — not re-emitted: MtMoonB2FRocket2BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
MtMoonB2FScript_ApplyPikachuMovementData:
    mov al, [ebp + wPikachuSpawnStateFlags]
    test al, (1 << (BIT_PIKACHU_SPAWN_STARTER))
    jnz .nr_4
        ret
.nr_4:
    mov al, [ebp + wWalkBikeSurfState]
    test al, al
    jz .nr_7
        ret
.nr_7:
    push esi
    push ebx
; DEVIATION{class=banking; pret=macros/farcall.asm:callfar; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call GetPikachuFacingDirectionAndReturnToE
    pop ebx
    pop esi
    mov al, bh
    cmp al, dl
    jz .nr_16
        ret
.nr_16:
    push esi
    mov al, [ebp + wUpdateSpritesEnabled]
    pushfd
    push eax
    mov al, 0xff
    mov [ebp + wUpdateSpritesEnabled], al
; DEVIATION{class=banking; pret=macros/farcall.asm:callfar; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call LoadPikachuShadowIntoVRAM
    pop eax
    popfd
    mov [ebp + wUpdateSpritesEnabled], al
    pop esi
    call ApplyPikachuMovementData
    ret
