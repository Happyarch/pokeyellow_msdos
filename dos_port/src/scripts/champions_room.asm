; ChampionsRoom.asm — translated from pret scripts/ChampionsRoom.asm by dos_port/tools/sm83xlat.
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


global ChampionsRoomCleanupScript
global ChampionsRoomDefaultScript
global ChampionsRoomOakArrivesScript
global ChampionsRoomOakComeWithMeScript
global ChampionsRoomOakComeWithMeText
global ChampionsRoomOakCongratulatesPlayerScript
global ChampionsRoomOakCongratulatesPlayerText
global ChampionsRoomOakDisappointedWithRivalScript
global ChampionsRoomOakDisappointedWithRivalText
global ChampionsRoomOakExitsScript
global ChampionsRoomOakText
global ChampionsRoomPlayerEntersScript
global ChampionsRoomPlayerFollowsOakScript
global ChampionsRoomRivalAfterBattleText
global ChampionsRoomRivalDefeatedScript
global ChampionsRoomRivalReadyToBattleScript
global ChampionsRoomRivalText
global ChampionsRoom_DisplayTextID_AllowABSelectStart
global ChampionsRoom_Script
global ChampionsRoom_ScriptPointers
global ChampionsRoom_TextPointers
global OakEntranceAfterVictoryMovement
global OakExitChampionsRoomMovement
global ResetRivalScript
global RivalDefeatedText
global RivalEntrance_RLEMovement
global RivalVictoryText
global WalkToHallOfFame_RLEMovement

extern Bankswitch   ; NOT YET DEFINED IN THE PORT
extern CallFunctionInTable   ; NOT YET DEFINED IN THE PORT
extern DecodeRLEList   ; NOT YET DEFINED IN THE PORT
extern Delay3   ; NOT YET DEFINED IN THE PORT
extern DisplayTextID   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern GetMonName   ; NOT YET DEFINED IN THE PORT
extern HideObject   ; NOT YET DEFINED IN THE PORT
extern MoveSprite   ; NOT YET DEFINED IN THE PORT
extern Music_Cities1AlternateTempo   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern SaveEndBattleTextPointers   ; NOT YET DEFINED IN THE PORT
extern SetSpriteFacingDirectionAndDelay   ; NOT YET DEFINED IN THE PORT
extern SetSpriteMovementBytesToFF   ; NOT YET DEFINED IN THE PORT
extern ShowObject   ; NOT YET DEFINED IN THE PORT
extern StartSimulatingJoypadStates   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern UpdateSprites   ; NOT YET DEFINED IN THE PORT
extern _ChampionsRoomOakComeWithMeText   ; NOT YET DEFINED IN THE PORT
extern _ChampionsRoomOakCongratulatesPlayerText   ; NOT YET DEFINED IN THE PORT
extern _ChampionsRoomOakDisappointedWithRivalText   ; NOT YET DEFINED IN THE PORT
extern _ChampionsRoomOakText   ; NOT YET DEFINED IN THE PORT
extern _ChampionsRoomRivalAfterBattleText   ; NOT YET DEFINED IN THE PORT
extern _ChampionsRoomRivalIntroText   ; NOT YET DEFINED IN THE PORT
extern _RivalDefeatedText   ; NOT YET DEFINED IN THE PORT
extern _RivalVictoryText   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_CHAMPIONSROOM_DEFAULT                   equ 0
SCRIPT_CHAMPIONSROOM_RIVAL_READY_TO_BATTLE     equ 2
SCRIPT_CHAMPIONSROOM_RIVAL_DEFEATED            equ 3
SCRIPT_CHAMPIONSROOM_OAK_ARRIVES               equ 4
SCRIPT_CHAMPIONSROOM_OAK_CONGRATULATES_PLAYER  equ 5
SCRIPT_CHAMPIONSROOM_OAK_DISAPPOINTED_WITH_RIVAL equ 6
SCRIPT_CHAMPIONSROOM_OAK_COME_WITH_ME          equ 7
SCRIPT_CHAMPIONSROOM_OAK_EXITS                 equ 8
SCRIPT_CHAMPIONSROOM_PLAYER_FOLLOWS_OAK        equ 9
SCRIPT_CHAMPIONSROOM_CLEANUP_SCRIPT            equ 10
TEXT_CHAMPIONSROOM_RIVAL                       equ 1
TEXT_CHAMPIONSROOM_OAK                         equ 2
TEXT_CHAMPIONSROOM_OAK_CONGRATULATES_PLAYER    equ 3
TEXT_CHAMPIONSROOM_OAK_DISAPPOINTED_WITH_RIVAL equ 4
TEXT_CHAMPIONSROOM_OAK_COME_WITH_ME            equ 5

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
hSpriteFacingDirection                         equ 0xFF8D
wChampionsRoomCurScript                        equ 0xD64B
wPlayerStarter                                 equ 0xD716

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
ChampionsRoom_Script:
    call EnableAutoTextBoxDrawing
    mov esi, ChampionsRoom_ScriptPointers
    mov al, [ebp + wChampionsRoomCurScript]
    call CallFunctionInTable
    ret

%assign event_byte -1
ResetRivalScript:
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov [ebp + wChampionsRoomCurScript], al
    ret

%assign event_byte -1
ChampionsRoom_ScriptPointers:
    dd ChampionsRoomDefaultScript
    dd ChampionsRoomPlayerEntersScript
    dd ChampionsRoomRivalReadyToBattleScript
    dd ChampionsRoomRivalDefeatedScript
    dd ChampionsRoomOakArrivesScript
    dd ChampionsRoomOakCongratulatesPlayerScript
    dd ChampionsRoomOakDisappointedWithRivalScript
    dd ChampionsRoomOakComeWithMeScript
    dd ChampionsRoomOakExitsScript
    dd ChampionsRoomPlayerFollowsOakScript
    dd ChampionsRoomCleanupScript

%assign event_byte -1
ChampionsRoomDefaultScript:
    ret

%assign event_byte -1
ChampionsRoomPlayerEntersScript:
    mov al, PAD_BUTTONS | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov esi, wSimulatedJoypadStatesEnd
    mov edi, RivalEntrance_RLEMovement   ; pret: ld de, RivalEntrance_RLEMovement — DecodeRLEList takes it in EDI
    call DecodeRLEList
    dec al
    mov [ebp + wSimulatedJoypadStatesIndex], al
    call StartSimulatingJoypadStates
    mov al, SCRIPT_CHAMPIONSROOM_RIVAL_READY_TO_BATTLE
    mov [ebp + wChampionsRoomCurScript], al
    ret

%assign event_byte -1
RivalEntrance_RLEMovement:
    db PAD_UP, 1
    db PAD_RIGHT, 1
    db PAD_UP, 3
    db -1

%assign event_byte -1
ChampionsRoomRivalReadyToBattleScript:
    mov al, [ebp + wSimulatedJoypadStatesIndex]
    test al, al
    jz .nr_53
        ret
.nr_53:
    call Delay3
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov esi, wOptions
    and byte [ebp + esi], ~(1 << (BIT_BATTLE_ANIMATION)) & 0xFF
    mov al, TEXT_CHAMPIONSROOM_RIVAL
    mov [ebp + hTextID], al
    call DisplayTextID
    call Delay3
    mov esi, wStatusFlags3
    or byte [ebp + esi], (1 << (BIT_TALKED_TO_TRAINER))
    or byte [ebp + esi], (1 << (BIT_PRINT_END_BATTLE_TEXT))
    mov esi, RivalDefeatedText
    mov edx, RivalVictoryText   ; pret: ld de, RivalVictoryText — SaveEndBattleTextPointers takes it in EDX
    call SaveEndBattleTextPointers
    mov al, OPP_RIVAL3
    mov [ebp + wCurOpponent], al
    mov al, [ebp + wRivalStarter]
    add al, 0x0
    mov [ebp + wTrainerNo], al
    xor al, al
    mov [ebp + hJoyHeld], al
    mov al, SCRIPT_CHAMPIONSROOM_RIVAL_DEFEATED
    mov [ebp + wChampionsRoomCurScript], al
    ret

%assign event_byte -1
ChampionsRoomRivalDefeatedScript:
    mov al, [ebp + wIsInBattle]
    cmp al, 0xff
    jz ResetRivalScript
    call UpdateSprites
    SetEvent EVENT_BEAT_CHAMPION_RIVAL
    mov al, PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, TEXT_CHAMPIONSROOM_RIVAL
    mov [ebp + hTextID], al
    call ChampionsRoom_DisplayTextID_AllowABSelectStart
    mov al, 1
    mov [ebp + hSpriteIndex], al
    call SetSpriteMovementBytesToFF
    mov al, SCRIPT_CHAMPIONSROOM_OAK_ARRIVES
    mov [ebp + wChampionsRoomCurScript], al
    ret

%assign event_byte -1
ChampionsRoomOakArrivesScript:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call Music_Cities1AlternateTempo
    mov al, TEXT_CHAMPIONSROOM_OAK
    mov [ebp + hTextID], al
    call ChampionsRoom_DisplayTextID_AllowABSelectStart
    mov al, 2
    mov [ebp + hSpriteIndex], al
    call SetSpriteMovementBytesToFF
    mov edi, OakEntranceAfterVictoryMovement   ; pret: ld de, OakEntranceAfterVictoryMovement — MoveSprite takes it in EDI
    mov al, 2
    mov [ebp + hSpriteIndex], al
    call MoveSprite
    mov al, 222
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call ShowObject
    mov al, SCRIPT_CHAMPIONSROOM_OAK_CONGRATULATES_PLAYER
    mov [ebp + wChampionsRoomCurScript], al
    ret

%assign event_byte -1
OakEntranceAfterVictoryMovement:
    db NPC_MOVEMENT_UP
    db NPC_MOVEMENT_UP
    db NPC_MOVEMENT_UP
    db NPC_MOVEMENT_UP
    db NPC_MOVEMENT_UP
    db -1

%assign event_byte -1
ChampionsRoomOakCongratulatesPlayerScript:
    mov al, [ebp + wStatusFlags5]
    test al, (1 << (BIT_SCRIPTED_NPC_MOVEMENT))
    jz .nr_131
        ret
.nr_131:
    mov al, PLAYER_DIR_LEFT
    mov [ebp + wPlayerMovingDirection], al
    mov al, 1
    mov [ebp + hSpriteIndex], al
    mov al, SPRITE_FACING_LEFT
    mov [ebp + hSpriteFacingDirection], al
    call SetSpriteFacingDirectionAndDelay
    mov al, 2
    mov [ebp + hSpriteIndex], al
    xor al, al
    mov [ebp + hSpriteFacingDirection], al
    call SetSpriteFacingDirectionAndDelay
    mov al, TEXT_CHAMPIONSROOM_OAK_CONGRATULATES_PLAYER
    mov [ebp + hTextID], al
    call ChampionsRoom_DisplayTextID_AllowABSelectStart
    mov al, SCRIPT_CHAMPIONSROOM_OAK_DISAPPOINTED_WITH_RIVAL
    mov [ebp + wChampionsRoomCurScript], al
    ret

%assign event_byte -1
ChampionsRoomOakDisappointedWithRivalScript:
    mov al, 2
    mov [ebp + hSpriteIndex], al
    mov al, SPRITE_FACING_RIGHT
    mov [ebp + hSpriteFacingDirection], al
    call SetSpriteFacingDirectionAndDelay
    mov al, TEXT_CHAMPIONSROOM_OAK_DISAPPOINTED_WITH_RIVAL
    mov [ebp + hTextID], al
    call ChampionsRoom_DisplayTextID_AllowABSelectStart
    mov al, SCRIPT_CHAMPIONSROOM_OAK_COME_WITH_ME
    mov [ebp + wChampionsRoomCurScript], al
    ret

%assign event_byte -1
ChampionsRoomOakComeWithMeScript:
    mov al, 2
    mov [ebp + hSpriteIndex], al
    xor al, al
    mov [ebp + hSpriteFacingDirection], al
    call SetSpriteFacingDirectionAndDelay
    mov al, TEXT_CHAMPIONSROOM_OAK_COME_WITH_ME
    mov [ebp + hTextID], al
    call ChampionsRoom_DisplayTextID_AllowABSelectStart
    mov edi, OakExitChampionsRoomMovement   ; pret: ld de, OakExitChampionsRoomMovement — MoveSprite takes it in EDI
    mov al, 2
    mov [ebp + hSpriteIndex], al
    call MoveSprite
    mov al, SCRIPT_CHAMPIONSROOM_OAK_EXITS
    mov [ebp + wChampionsRoomCurScript], al
    ret

%assign event_byte -1
OakExitChampionsRoomMovement:
    db NPC_MOVEMENT_UP
    db NPC_MOVEMENT_UP
    db -1

%assign event_byte -1
ChampionsRoomOakExitsScript:
    mov al, [ebp + wStatusFlags5]
    test al, (1 << (BIT_SCRIPTED_NPC_MOVEMENT))
    jz .nr_189
        ret
.nr_189:
    mov al, 222
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
    mov al, SCRIPT_CHAMPIONSROOM_PLAYER_FOLLOWS_OAK
    mov [ebp + wChampionsRoomCurScript], al
    ret

%assign event_byte -1
ChampionsRoomPlayerFollowsOakScript:
    mov al, PAD_BUTTONS | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov esi, wSimulatedJoypadStatesEnd
    mov edi, WalkToHallOfFame_RLEMovement   ; pret: ld de, WalkToHallOfFame_RLEMovement — DecodeRLEList takes it in EDI
    call DecodeRLEList
    dec al
    mov [ebp + wSimulatedJoypadStatesIndex], al
    call StartSimulatingJoypadStates
    mov al, SCRIPT_CHAMPIONSROOM_CLEANUP_SCRIPT
    mov [ebp + wChampionsRoomCurScript], al
    ret

%assign event_byte -1
WalkToHallOfFame_RLEMovement:
    db PAD_UP, 4
    db PAD_LEFT, 1
    db -1

%assign event_byte -1
ChampionsRoomCleanupScript:
    mov al, [ebp + wSimulatedJoypadStatesIndex]
    test al, al
    jz .nr_218
        ret
.nr_218:
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov al, SCRIPT_CHAMPIONSROOM_DEFAULT
    mov [ebp + wChampionsRoomCurScript], al
    ret

%assign event_byte -1
ChampionsRoom_DisplayTextID_AllowABSelectStart:
    mov al, PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    call DisplayTextID
    mov al, PAD_BUTTONS | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    ret

%assign event_byte -1
ChampionsRoom_TextPointers:
    dd ChampionsRoomRivalText
    dd ChampionsRoomOakText
    dd ChampionsRoomOakCongratulatesPlayerText
    dd ChampionsRoomOakDisappointedWithRivalText
    dd ChampionsRoomOakComeWithMeText

%assign event_byte -1
ChampionsRoomRivalText:
    CheckEvent EVENT_BEAT_CHAMPION_RIVAL
    mov esi, .IntroText
    jz .printText
    mov esi, ChampionsRoomRivalAfterBattleText
.printText:
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
.IntroText:
    text_far _ChampionsRoomRivalIntroText
    text_end
RivalDefeatedText:
    text_far _RivalDefeatedText
    text_end
RivalVictoryText:
    text_far _RivalVictoryText
    text_end
ChampionsRoomRivalAfterBattleText:
    text_far _ChampionsRoomRivalAfterBattleText
    text_end
ChampionsRoomOakText:
    text_far _ChampionsRoomOakText
    text_end

%assign event_byte -1
ChampionsRoomOakCongratulatesPlayerText:
    mov al, [ebp + wPlayerStarter]
    mov [ebp + wNamedObjectIndex], al
    call GetMonName
    mov esi, .Text
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
.Text:
    text_far _ChampionsRoomOakCongratulatesPlayerText
    text_end
ChampionsRoomOakDisappointedWithRivalText:
    text_far _ChampionsRoomOakDisappointedWithRivalText
    text_end
ChampionsRoomOakComeWithMeText:
    text_far _ChampionsRoomOakComeWithMeText
    text_end
