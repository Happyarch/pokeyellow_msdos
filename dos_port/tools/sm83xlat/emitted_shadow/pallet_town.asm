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

global PalletTownAfterPikachuBattleScript
global PalletTownDefaultScript
global PalletTownFisherText
global PalletTownGirlText
global PalletTownNoopScript
global PalletTownOakComeWithMe
global PalletTownOakGreetsPlayerScript
global PalletTownOakHeyWaitScript
global PalletTownOakNotSafeComeWithMeScript
global PalletTownOakText
global PalletTownOakWalksToPlayerScript
global PalletTownOaksLabSignText
global PalletTownPikachuBattleScript
global PalletTownPlayerFollowsOakScript
global PalletTownPlayersHouseSignText
global PalletTownRivalsHouseSignText
global PalletTown_Script
global PalletTown_ScriptPointers
global PalletTown_TextPointers

extern CalcPositionOfPlayerRelativeToNPC
extern CallFunctionInTable
extern Delay3
extern DelayFrames
extern DisplayTextID
extern EmotionBubble
extern EnableAutoTextBoxDrawing
extern FindPathToPlayer
extern HideObject
extern MoveSprite
extern PalletTownDaisyScript   ; NOT YET DEFINED IN THE PORT
extern PalletTownSignText   ; NOT YET DEFINED IN THE PORT
extern PlayMusic
extern PrintText
extern ShowObject
extern StopAllMusic
extern TextScriptEnd
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
SCRIPT_PALLETTOWN_OAK_HEY_WAIT                 equ 1
SCRIPT_PALLETTOWN_OAK_WALKS_TO_PLAYER          equ 2
SCRIPT_PALLETTOWN_OAK_GREETS_PLAYER            equ 3
SCRIPT_PALLETTOWN_PIKACHU_BATTLE               equ 4
SCRIPT_PALLETTOWN_AFTER_PIKACHU_BATTLE         equ 5
SCRIPT_PALLETTOWN_OAK_NOT_SAFE_COME_WITH_ME    equ 6
SCRIPT_PALLETTOWN_PLAYER_FOLLOWS_OAK           equ 7
SCRIPT_PALLETTOWN_DAISY                        equ 8
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

%assign event_byte -1
%assign event_byte_a -1
PalletTown_Script:
    CheckEvent EVENT_GOT_POKEBALLS_FROM_OAK
    jz .next
    SetEvent EVENT_PALLET_AFTER_GETTING_POKEBALLS
.next:
    call EnableAutoTextBoxDrawing
    mov esi, PalletTown_ScriptPointers
    mov al, [ebp + wPalletTownCurScript]
    jmp CallFunctionInTable

%assign event_byte -1
%assign event_byte_a -1
PalletTown_ScriptPointers:
    dd PalletTownDefaultScript
    dd PalletTownOakHeyWaitScript
    dd PalletTownOakWalksToPlayerScript
    dd PalletTownOakGreetsPlayerScript
    dd PalletTownPikachuBattleScript
    dd PalletTownAfterPikachuBattleScript
    dd PalletTownOakNotSafeComeWithMeScript
    dd PalletTownPlayerFollowsOakScript
    dd PalletTownDaisyScript
    dd PalletTownNoopScript

%assign event_byte -1
%assign event_byte_a -1
PalletTownDefaultScript:
    CheckEvent EVENT_FOLLOWED_OAK_INTO_LAB
    jz .nr_26
        ret
.nr_26:
    mov al, [ebp + wYCoord]
    cmp al, 0
    jz .nr_29
        ret
.nr_29:
    ResetEvent EVENT_PLAYER_AT_RIGHT_EXIT_TO_PALLET_TOWN
    mov al, [ebp + wXCoord]
    cmp al, 10
    jz .asm_18e40
    SetEventReuseHL EVENT_PLAYER_AT_RIGHT_EXIT_TO_PALLET_TOWN
.asm_18e40:
    xor al, al
    mov [ebp + hJoyHeld], al
    mov al, PAD_BUTTONS | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, PLAYER_DIR_UP
    mov [ebp + wPlayerMovingDirection], al
    call StopAllMusic
    mov al, 2
    mov bl, al
    mov al, MUSIC_MEET_PROF_OAK
    call PlayMusic
    SetEvent EVENT_OAK_APPEARED_IN_PALLET
    mov al, SCRIPT_PALLETTOWN_OAK_HEY_WAIT
    mov [ebp + wPalletTownCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
PalletTownOakHeyWaitScript:
    mov al, PAD_SELECT | PAD_START | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    xor al, al
    mov [ebp + wOakWalkedToPlayer], al
    mov al, TEXT_PALLETTOWN_OAK
    mov [ebp + hTextID], al
    call DisplayTextID
    mov al, PAD_BUTTONS | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov esi, wSprite01StateData2MapY
    mov al, 8
    mov [ebp + esi], al
    lea esi, [esi+1]
    mov al, 14
    mov [ebp + esi], al
    mov al, TOGGLE_PALLET_TOWN_OAK
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call ShowObject
    mov al, 0x2
    mov [ebp + wSprite01StateData1MovementStatus], al
    mov al, SPRITE_FACING_UP
    mov [ebp + wSprite01StateData1FacingDirection], al
    mov al, SCRIPT_PALLETTOWN_OAK_WALKS_TO_PLAYER
    mov [ebp + wPalletTownCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
PalletTownOakWalksToPlayerScript:
    call Delay3
    mov al, 0
    mov [ebp + wYCoord], al
    mov al, 1
    mov [ebp + hNPCPlayerRelativePosPerspective], al
    mov al, 1
    rol al, 4
    test al, al   ; swap sets Z, clears C
    mov [ebp + hNPCSpriteOffset], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call CalcPositionOfPlayerRelativeToNPC
    mov esi, hNPCPlayerYDistance
    dec byte [ebp + esi]
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call FindPathToPlayer
    mov dx, wNPCMovementDirections2
    mov al, 1
    mov [ebp + hSpriteIndex], al
    call MoveSprite
    mov al, SCRIPT_PALLETTOWN_OAK_GREETS_PLAYER
    mov [ebp + wPalletTownCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
PalletTownOakGreetsPlayerScript:
    mov al, [ebp + wStatusFlags5]
    test al, (1 << (BIT_SCRIPTED_NPC_MOVEMENT))
    jz .nr_108
        ret
.nr_108:
    mov al, PAD_SELECT | PAD_START | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, 1
    mov [ebp + wOakWalkedToPlayer], al
    mov al, 0x2
    mov [ebp + wSprite01StateData1MovementStatus], al
    mov al, SPRITE_FACING_UP
    mov [ebp + wSprite01StateData1FacingDirection], al
    mov al, TEXT_PALLETTOWN_OAK
    mov [ebp + hTextID], al
    call DisplayTextID
    mov al, PAD_BUTTONS | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, 0x2
    mov [ebp + wSprite01StateData1MovementStatus], al
    CheckEvent EVENT_PLAYER_AT_RIGHT_EXIT_TO_PALLET_TOWN
    mov al, SPRITE_FACING_RIGHT
    jz .asm_18f01
    mov al, SPRITE_FACING_LEFT
.asm_18f01:
    mov [ebp + wSprite01StateData1FacingDirection], al
    mov al, SCRIPT_PALLETTOWN_PIKACHU_BATTLE
    mov [ebp + wPalletTownCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
PalletTownPikachuBattleScript:
    mov al, PAD_SELECT | PAD_START | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    xor al, al
    mov [ebp + wListScrollOffset], al
    mov al, BATTLE_TYPE_PIKACHU
    mov [ebp + wBattleType], al
    mov al, STARTER_PIKACHU
    mov [ebp + wCurOpponent], al
    mov al, 5
    mov [ebp + wCurEnemyLevel], al
    mov al, SCRIPT_PALLETTOWN_AFTER_PIKACHU_BATTLE
    mov [ebp + wPalletTownCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
PalletTownAfterPikachuBattleScript:
    mov al, 2
    mov [ebp + wOakWalkedToPlayer], al
    mov al, TEXT_PALLETTOWN_OAK
    mov [ebp + hTextID], al
    call DisplayTextID
    mov al, 0x2
    mov [ebp + wSprite01StateData1MovementStatus], al
    mov al, SPRITE_FACING_UP
    mov [ebp + wSprite01StateData1FacingDirection], al
    mov al, TEXT_PALLETTOWN_OAK_COME_WITH_ME
    mov [ebp + hTextID], al
    call DisplayTextID
    mov al, PAD_BUTTONS | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, SCRIPT_PALLETTOWN_OAK_NOT_SAFE_COME_WITH_ME
    mov [ebp + wPalletTownCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
PalletTownOakNotSafeComeWithMeScript:
    xor al, al
    mov [ebp + wSpritePlayerStateData1FacingDirection], al
    mov al, 1
    mov [ebp + wSpriteIndex], al
    xor al, al
    mov [ebp + wNPCMovementScriptFunctionNum], al
    mov al, 1
    mov [ebp + wNPCMovementScriptPointerTableNum], al
    mov al, [ebp + hLoadedROMBank]
    mov [ebp + wNPCMovementScriptBank], al
    mov al, SCRIPT_PALLETTOWN_PLAYER_FOLLOWS_OAK
    mov [ebp + wPalletTownCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
PalletTownPlayerFollowsOakScript:
    mov al, [ebp + wNPCMovementScriptPointerTableNum]
    test al, al
    jz .nr_196
        ret
.nr_196:
    mov al, SCRIPT_PALLETTOWN_DAISY
    mov [ebp + wPalletTownCurScript], al
    ret

; ---------------------------------------------------------------------------
; BAIL[event-macro-reuse-a-hint] PalletTownDaisyScript (scripts/PalletTown.asm:204-214) — at scripts/PalletTown.asm:206: CheckBothEventsSet EVENT_GOT_TOWN_MAP, EVENT_ENTERED_BLUES_HOUSE, 1
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

%assign event_byte -1
%assign event_byte_a -1
.next:
    CheckEvent EVENT_GOT_POKEBALLS_FROM_OAK
    jnz .nr_217
        ret
.nr_217:
    SetEvent EVENT_PALLET_AFTER_GETTING_POKEBALLS_2
PalletTownNoopScript:
    ret

%assign event_byte -1
%assign event_byte_a -1
PalletTown_TextPointers:
    dd PalletTownOakText
    dd PalletTownGirlText
    dd PalletTownFisherText
    dd PalletTownOaksLabSignText
    dd PalletTownSignText
    dd PalletTownPlayersHouseSignText
    dd PalletTownRivalsHouseSignText
    dd PalletTownOakComeWithMe

%assign event_byte -1
%assign event_byte_a -1
PalletTownOakText:
    mov al, [ebp + wOakWalkedToPlayer]
    test al, al
    jnz .next
    mov al, 1
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    mov esi, .HeyWaitDontGoOutText
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.next:
    dec al
    jnz .whew
    mov esi, .ThatWasCloseText
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.whew:
    mov esi, .WhewText
.done:
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.HeyWaitDontGoOutText:
    text_far _PalletTownOakHeyWaitDontGoOutText

%assign event_byte -1
%assign event_byte_a -1
    mov bl, 10
    call DelayFrames
    mov al, PLAYER_DIR_DOWN
    mov [ebp + wPlayerMovingDirection], al
    mov al, 0
    mov [ebp + wEmotionBubbleSpriteIndex], al
    mov al, 0
    mov [ebp + wWhichEmotionBubble], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call EmotionBubble
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
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
