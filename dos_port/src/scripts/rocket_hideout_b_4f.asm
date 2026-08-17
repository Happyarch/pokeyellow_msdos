; RocketHideoutB4F.asm — translated from pret scripts/RocketHideoutB4F.asm by dos_port/tools/sm83xlat.
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
%include "assets/trainer_headers.inc"

global RocketHideoutB4FBeatGiovanniScript
global RocketHideoutB4FGiovanniHopeWeMeetAgainText
global RocketHideoutB4FGiovanniText
global RocketHideoutB4FJessieJamesEndBattleText
global RocketHideoutB4FJessieJamesMovementData_45605
global RocketHideoutB4FJessieJamesMovementData_45606
global RocketHideoutB4FResetScripts
global RocketHideoutB4FRocketText
global RocketHideoutB4FScript10
global RocketHideoutB4FScript11
global RocketHideoutB4FScript12
global RocketHideoutB4FScript13
global RocketHideoutB4FScript8
global RocketHideoutB4FScript9
global RocketHideoutB4FScript_455a5
global RocketHideoutB4FScript_HideJessieJames
global RocketHideoutB4FScript_HideObject
global RocketHideoutB4FScript_ShowObject
global RocketHideoutB4FSetScript
global RocketHideoutB4FText12
global RocketHideoutB4FText13
global RocketHideoutB4F_Script
global RocketHideoutB4F_ScriptPointers

extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern Delay3   ; NOT YET DEFINED IN THE PORT
extern DelayFrames   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern DisplayTextID   ; NOT YET DEFINED IN THE PORT
extern EmotionBubble   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern EngageMapTrainer   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern GBFadeInFromBlack   ; NOT YET DEFINED IN THE PORT
extern GBFadeOutToBlack   ; NOT YET DEFINED IN THE PORT
extern HideObject   ; NOT YET DEFINED IN THE PORT
extern InitBattleEnemyParameters   ; NOT YET DEFINED IN THE PORT
extern MoveSprite   ; NOT YET DEFINED IN THE PORT
extern PlayDefaultMusic   ; NOT YET DEFINED IN THE PORT
extern PlayMusic   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern RocketHideout4TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern RocketHideout4TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern RocketHideoutB4FDefaultScript   ; NOT YET DEFINED IN THE PORT
extern RocketHideoutB4FRocketAfterBattleText   ; NOT YET DEFINED IN THE PORT
extern RocketHideoutB4FRocketBattleText   ; NOT YET DEFINED IN THE PORT
extern RocketHideoutB4FScript4   ; NOT YET DEFINED IN THE PORT
extern RocketHideoutB4FScript5   ; NOT YET DEFINED IN THE PORT
extern RocketHideoutB4FScript6   ; NOT YET DEFINED IN THE PORT
extern RocketHideoutB4FScript7   ; NOT YET DEFINED IN THE PORT
extern RocketHideoutB4F_TextPointers   ; NOT YET DEFINED IN THE PORT
extern SaveEndBattleTextPointers   ; NOT YET DEFINED IN THE PORT
extern ShowObject   ; NOT YET DEFINED IN THE PORT
extern StopAllMusic   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern UpdateSprites   ; NOT YET DEFINED IN THE PORT
extern _RocketHideoutB4FGiovanniHopeWeMeetAgainText   ; NOT YET DEFINED IN THE PORT
extern _RocketHideoutB4FGiovanniImpressedYouGotHereText   ; NOT YET DEFINED IN THE PORT
extern _RocketHideoutB4FGiovanniWhatCannotBeText   ; NOT YET DEFINED IN THE PORT
extern _RocketHideoutB4FRocketAfterBattleText   ; NOT YET DEFINED IN THE PORT
extern _RocketHideoutJessieJamesText2   ; NOT YET DEFINED IN THE PORT
extern _RocketHideoutJessieJamesText3   ; NOT YET DEFINED IN THE PORT
extern _RocketHideoutJessieJamesText4   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_ROCKETHIDEOUTB4F_DEFAULT                equ 0
SCRIPT_ROCKETHIDEOUTB4F_BEAT_GIOVANNI          equ 3
SCRIPT_ROCKETHIDEOUTB4F_SCRIPT4                equ 4
SCRIPT_ROCKETHIDEOUTB4F_SCRIPT5                equ 5
SCRIPT_ROCKETHIDEOUTB4F_SCRIPT8                equ 8
SCRIPT_ROCKETHIDEOUTB4F_SCRIPT11               equ 11
SCRIPT_ROCKETHIDEOUTB4F_SCRIPT12               equ 12
SCRIPT_ROCKETHIDEOUTB4F_SCRIPT13               equ 13
TEXT_ROCKETHIDEOUTB4F_GIOVANNI_HOPE_WE_MEET_AGAIN equ 10
TEXT_ROCKETHIDEOUTB4F_TEXT11                   equ 11
TEXT_ROCKETHIDEOUTB4F_TEXT12                   equ 12
TEXT_ROCKETHIDEOUTB4F_TEXT13                   equ 13

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wRocketHideoutB4FCurScript                     equ 0xD633
wSprite02StateData1FacingDirection             equ 0xC129
wSprite02StateData1MovementStatus              equ 0xC121
wSprite03StateData1FacingDirection             equ 0xC139
wSprite03StateData1MovementStatus              equ 0xC131

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
RocketHideoutB4F_Script:
    call EnableAutoTextBoxDrawing
    mov esi, RocketHideout4TrainerHeaders
    mov edi, RocketHideoutB4F_ScriptPointers   ; pret: ld de, RocketHideoutB4F_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRocketHideoutB4FCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRocketHideoutB4FCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
RocketHideoutB4FResetScripts:
    CheckAndResetEvent EVENT_6A0
    jz .sk_12
        call RocketHideoutB4FScript_HideJessieJames
.sk_12:
    xor al, al
    mov [ebp + wJoyIgnore], al
RocketHideoutB4FSetScript:
    mov [ebp + wRocketHideoutB4FCurScript], al
    mov [ebp + wCurMapScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
RocketHideoutB4FScript_HideJessieJames:
    mov al, 134
    call RocketHideoutB4FScript_HideObject
    mov al, 135
    call RocketHideoutB4FScript_HideObject
    ret

%assign event_byte -1
%assign event_byte_a -1
RocketHideoutB4F_ScriptPointers:
    dd RocketHideoutB4FDefaultScript
    dd DisplayEnemyTrainerTextAndStartBattle
    dd EndTrainerBattle
    dd RocketHideoutB4FBeatGiovanniScript
    dd RocketHideoutB4FScript4
    dd RocketHideoutB4FScript5
    dd RocketHideoutB4FScript6
    dd RocketHideoutB4FScript7
    dd RocketHideoutB4FScript8
    dd RocketHideoutB4FScript9
    dd RocketHideoutB4FScript10
    dd RocketHideoutB4FScript11
    dd RocketHideoutB4FScript12
    dd RocketHideoutB4FScript13

%assign event_byte -1
%assign event_byte_a -1
RocketHideoutB4FBeatGiovanniScript:
    mov al, [ebp + wIsInBattle]
    cmp al, 0xff
    jz RocketHideoutB4FResetScripts
    mov al, PAD_SELECT | PAD_START | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    SetEvent EVENT_BEAT_ROCKET_HIDEOUT_GIOVANNI
    mov al, TEXT_ROCKETHIDEOUTB4F_GIOVANNI_HOPE_WE_MEET_AGAIN
    mov [ebp + hTextID], al
    call DisplayTextID
    call GBFadeOutToBlack
    mov al, 133
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
    mov al, 139
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call ShowObject
    call UpdateSprites
    call GBFadeInFromBlack
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov esi, wCurrentMapScriptFlags
    or byte [ebp + esi], (1 << (BIT_CUR_MAP_LOADED_1))
    mov al, SCRIPT_ROCKETHIDEOUTB4F_DEFAULT
    mov [ebp + wRocketHideoutB4FCurScript], al
    mov [ebp + wCurMapScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
    CheckEvent EVENT_BEAT_ROCKET_HIDEOUT_4_JESSIE_JAMES
    jnz .sk_78
        call RocketHideoutB4FScript_455a5
.sk_78:
    CheckEvent EVENT_BEAT_ROCKET_HIDEOUT_4_TRAINER_2
    jnz .sk_80
        call CheckFightingMapTrainers
.sk_80:
    ret

%assign event_byte -1
%assign event_byte_a -1
RocketHideoutB4FScript_455a5:
    mov al, [ebp + wYCoord]
    cmp al, 0xe
    jz .nr_86
        ret
.nr_86:
    ResetEvent EVENT_ROCKET_HIDEOUT_4_JESSIE_JAMES_ON_LEFT
    mov al, [ebp + wXCoord]
    cmp al, 0x18
    jz .asm_455c2
    mov al, [ebp + wXCoord]
    cmp al, 0x19
    jz .nr_93
        ret
.nr_93:
    SetEvent EVENT_ROCKET_HIDEOUT_4_JESSIE_JAMES_ON_LEFT
.asm_455c2:
    xor al, al
    mov [ebp + hJoyHeld], al
    mov al, PAD_SELECT | PAD_START | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    call StopAllMusic
    mov bl, 32
    mov al, MUSIC_MEET_JESSIE_JAMES
    call PlayMusic
    call UpdateSprites
    call Delay3
    call UpdateSprites
    call Delay3
    mov al, 0x1
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    mov al, TEXT_ROCKETHIDEOUTB4F_TEXT11
    mov [ebp + hTextID], al
    call DisplayTextID
    xor al, al
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    mov al, PAD_BUTTONS | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, 134
    call RocketHideoutB4FScript_ShowObject
    mov al, 135
    call RocketHideoutB4FScript_ShowObject
    mov al, SCRIPT_ROCKETHIDEOUTB4F_SCRIPT4
    call RocketHideoutB4FSetScript
    ret

%assign event_byte -1
%assign event_byte_a -1
RocketHideoutB4FJessieJamesMovementData_45605:
    db 0x4
RocketHideoutB4FJessieJamesMovementData_45606:
    db 0x4
    db 0x4
    db 0x4
    db 0xff

; ---------------------------------------------------------------------------
; BAIL[host-pointer-in-16bit-reg] RocketHideoutB4FScript4 (scripts/RocketHideoutB4F.asm:134-146) — at scripts/RocketHideoutB4F.asm:134: de cannot hold the 32-bit address of RocketHideoutB4FJessieJamesMovementData_45605; callee <none in range> has no abi.json entry
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld de, RocketHideoutB4FJessieJamesMovementData_45605
; PRET| 	CheckEvent EVENT_ROCKET_HIDEOUT_4_JESSIE_JAMES_ON_LEFT
; PRET| 	jr z, .asm_45617
; PRET| 	ld de, RocketHideoutB4FJessieJamesMovementData_45606
; PRET| .asm_45617
; PRET| 	ld a, ROCKETHIDEOUTB4F_JAMES
; PRET| 	ldh [hSpriteIndex], a
; PRET| 	call MoveSprite
; PRET| 	ld a, PAD_BUTTONS | PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 	ld a, SCRIPT_ROCKETHIDEOUTB4F_SCRIPT5
; PRET| 	call RocketHideoutB4FSetScript
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] RocketHideoutB4FScript5 (scripts/RocketHideoutB4F.asm:149-180) — at scripts/RocketHideoutB4F.asm:160: .asm_4564a is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, PAD_BUTTONS | PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 	ld a, [wStatusFlags5]
; PRET| 	bit BIT_SCRIPTED_NPC_MOVEMENT, a
; PRET| 	ret nz
; PRET| RocketHideoutB4FScript6:
; PRET| 	ld a, $2
; PRET| 	ld [wSprite02StateData1MovementStatus], a
; PRET| 	ld a, SPRITE_FACING_LEFT
; PRET| 	ld [wSprite02StateData1FacingDirection], a
; PRET| 	CheckEvent EVENT_ROCKET_HIDEOUT_4_JESSIE_JAMES_ON_LEFT
; PRET| 	jr z, .asm_4564a
; PRET| 	ld a, SPRITE_FACING_DOWN
; PRET| 	ld [wSprite02StateData1FacingDirection], a
; PRET| .asm_4564a
; PRET| 	call Delay3
; PRET| 	ld a, PAD_SELECT | PAD_START | PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| RocketHideoutB4FScript7:
; PRET| 	ld de, RocketHideoutB4FJessieJamesMovementData_45606
; PRET| 	CheckEvent EVENT_ROCKET_HIDEOUT_4_JESSIE_JAMES_ON_LEFT
; PRET| 	jr z, .asm_4565f
; PRET| 	ld de, RocketHideoutB4FJessieJamesMovementData_45605
; PRET| .asm_4565f
; PRET| 	ld a, ROCKETHIDEOUTB4F_JESSIE
; PRET| 	ldh [hSpriteIndex], a
; PRET| 	call MoveSprite
; PRET| 	ld a, PAD_BUTTONS | PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 	ld a, SCRIPT_ROCKETHIDEOUTB4F_SCRIPT8
; PRET| 	call RocketHideoutB4FSetScript
; PRET| 	ret

%assign event_byte -1
%assign event_byte_a -1
RocketHideoutB4FScript8:
    mov al, PAD_BUTTONS | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, [ebp + wStatusFlags5]
    test al, (1 << (BIT_SCRIPTED_NPC_MOVEMENT))
    jz .nr_187
        ret
.nr_187:
    mov al, PAD_SELECT | PAD_START | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
RocketHideoutB4FScript9:
    mov al, 0x2
    mov [ebp + wSprite03StateData1MovementStatus], al
    mov al, SPRITE_FACING_DOWN
    mov [ebp + wSprite03StateData1FacingDirection], al
    CheckEvent EVENT_ROCKET_HIDEOUT_4_JESSIE_JAMES_ON_LEFT
    jz .asm_45697
    mov al, SPRITE_FACING_RIGHT
    mov [ebp + wSprite03StateData1FacingDirection], al
.asm_45697:
    call Delay3
    mov al, TEXT_ROCKETHIDEOUTB4F_TEXT12
    mov [ebp + hTextID], al
    call DisplayTextID
RocketHideoutB4FScript10:
    mov esi, wStatusFlags3
    or byte [ebp + esi], (1 << (BIT_TALKED_TO_TRAINER))
    or byte [ebp + esi], (1 << (BIT_PRINT_END_BATTLE_TEXT))
    mov esi, RocketHideoutB4FJessieJamesEndBattleText
    mov edx, RocketHideoutB4FJessieJamesEndBattleText   ; pret: ld de, RocketHideoutB4FJessieJamesEndBattleText — SaveEndBattleTextPointers takes it in EDX
    call SaveEndBattleTextPointers
    mov al, OPP_ROCKET
    mov [ebp + wCurOpponent], al
    mov al, 0x2b
    mov [ebp + wTrainerNo], al
    xor al, al
    mov [ebp + hJoyHeld], al
    mov [ebp + wJoyIgnore], al
    SetEvent EVENT_6A0
    mov al, SCRIPT_ROCKETHIDEOUTB4F_SCRIPT11
    call RocketHideoutB4FSetScript
    ret

%assign event_byte -1
%assign event_byte_a -1
RocketHideoutB4FScript11:
    mov al, PAD_BUTTONS | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, [ebp + wIsInBattle]
    cmp al, 0xff
    jz RocketHideoutB4FResetScripts
    mov al, 0x2
    mov [ebp + wSprite02StateData1MovementStatus], al
    mov [ebp + wSprite03StateData1MovementStatus], al
    xor al, al
    mov [ebp + wSprite02StateData1FacingDirection], al
    mov [ebp + wSprite03StateData1FacingDirection], al
    mov al, PAD_SELECT | PAD_START | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, 0x1
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    mov al, TEXT_ROCKETHIDEOUTB4F_TEXT13
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
    mov al, SCRIPT_ROCKETHIDEOUTB4F_SCRIPT12
    call RocketHideoutB4FSetScript
    ret

%assign event_byte -1
%assign event_byte_a -1
RocketHideoutB4FScript12:
    mov al, PAD_BUTTONS | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    call GBFadeOutToBlack
    mov al, 134
    call RocketHideoutB4FScript_HideObject
    mov al, 135
    call RocketHideoutB4FScript_HideObject
    call UpdateSprites
    call Delay3
    call GBFadeInFromBlack
    mov al, SCRIPT_ROCKETHIDEOUTB4F_SCRIPT13
    call RocketHideoutB4FSetScript
    ret

%assign event_byte -1
%assign event_byte_a -1
RocketHideoutB4FScript13:
    call PlayDefaultMusic
    xor al, al
    mov [ebp + hJoyHeld], al
    mov [ebp + wJoyIgnore], al
    SetEvent EVENT_BEAT_ROCKET_HIDEOUT_4_JESSIE_JAMES
    mov al, SCRIPT_ROCKETHIDEOUTB4F_DEFAULT
    call RocketHideoutB4FSetScript
    ret

%assign event_byte -1
%assign event_byte_a -1
RocketHideoutB4FScript_ShowObject:
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call ShowObject
    call UpdateSprites
    call Delay3
    ret

%assign event_byte -1
%assign event_byte_a -1
RocketHideoutB4FScript_HideObject:
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
    ret

; RocketHideoutB4F_TextPointers (scripts/RocketHideoutB4F.asm:292-317) — not re-emitted: RocketHideout4TrainerHeaders is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
    mov bl, 10
    call DelayFrames
    mov al, 0x8
    mov [ebp + wPlayerMovingDirection], al
    mov al, 0x0
    mov [ebp + wEmotionBubbleSpriteIndex], al
    mov al, 0
    mov [ebp + wWhichEmotionBubble], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call EmotionBubble
    mov bl, 20
    call DelayFrames
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
RocketHideoutB4FText12:
    text_far _RocketHideoutJessieJamesText2
    text_end
RocketHideoutB4FJessieJamesEndBattleText:
    text_far _RocketHideoutJessieJamesText3
    text_end
RocketHideoutB4FText13:
    text_far _RocketHideoutJessieJamesText4

%assign event_byte -1
%assign event_byte_a -1
    mov bl, 64
    call DelayFrames
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
RocketHideoutB4FGiovanniText:
    CheckEvent EVENT_BEAT_ROCKET_HIDEOUT_GIOVANNI
    jnz .beat_giovanni
    mov esi, .ImpressedYouGotHereText
    call PrintText
    mov esi, wStatusFlags3
    or byte [ebp + esi], (1 << (BIT_TALKED_TO_TRAINER))
    or byte [ebp + esi], (1 << (BIT_PRINT_END_BATTLE_TEXT))
    mov esi, .WhatCannotBeText
    mov edx, .WhatCannotBeText   ; pret: ld de, .WhatCannotBeText — SaveEndBattleTextPointers takes it in EDX
    call SaveEndBattleTextPointers
    mov al, [ebp + hSpriteIndex]
    mov [ebp + wSpriteIndex], al
    call EngageMapTrainer
    call InitBattleEnemyParameters
    xor al, al
    mov [ebp + hJoyHeld], al
    mov al, SCRIPT_ROCKETHIDEOUTB4F_BEAT_GIOVANNI
    mov [ebp + wRocketHideoutB4FCurScript], al
    mov [ebp + wCurMapScript], al
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.beat_giovanni:
    mov esi, RocketHideoutB4FGiovanniHopeWeMeetAgainText
    call PrintText
.done:
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.ImpressedYouGotHereText:
    text_far _RocketHideoutB4FGiovanniImpressedYouGotHereText
    text_end
.WhatCannotBeText:
    text_far _RocketHideoutB4FGiovanniWhatCannotBeText
    text_end
RocketHideoutB4FGiovanniHopeWeMeetAgainText:
    text_far _RocketHideoutB4FGiovanniHopeWeMeetAgainText
    text_end

%assign event_byte -1
%assign event_byte_a -1
RocketHideoutB4FRocketText:
    mov esi, RocketHideout4TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; RocketHideoutB4FRocketBattleText (scripts/RocketHideoutB4F.asm:394-399) — not re-emitted: RocketHideoutB4FRocketBattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
    SetEvent EVENT_ROCKET_DROPPED_LIFT_KEY
    mov al, 140
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call ShowObject
    jmp TextScriptEnd

; RocketHideoutB4FRocketAfterBattleText (scripts/RocketHideoutB4F.asm:409-411) — not re-emitted: RocketHideoutB4FRocketAfterBattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
.Text:
    text_far _RocketHideoutB4FRocketAfterBattleText
    text_end
