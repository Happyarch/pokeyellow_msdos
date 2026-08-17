; SilphCo7F.asm — translated from pret scripts/SilphCo7F.asm by dos_port/tools/sm83xlat.
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

global SilphCo7FDefaultScript
global SilphCo7FRivalAfterBattleScript
global SilphCo7FRivalDefeatedText
global SilphCo7FRivalExitScript
global SilphCo7FRivalGoodLuckToYouText
global SilphCo7FRivalStartBattleScript
global SilphCo7FRivalText
global SilphCo7FRivalVictoryText
global SilphCo7FRivalWaitedHereText
global SilphCo7FRocket1Text
global SilphCo7FRocket2Text
global SilphCo7FRocket3Text
global SilphCo7FScientistText
global SilphCo7FSetCurScript
global SilphCo7FSetDefaultScript
global SilphCo7FSilphWorkerM1Text
global SilphCo7FSilphWorkerM2Text
global SilphCo7FSilphWorkerM3Text
global SilphCo7FSilphWorkerM4Text
global SilphCo7F_GateCallbackScript
global SilphCo7F_Script
global SilphCo7F_ScriptPointers
global SilphCo7F_SetCardKeyDoorYScript
global SilphCo7F_UnlockedDoorEventScript

extern ArePlayerCoordsInArray
extern Bankswitch
extern CheckFightingMapTrainers
extern Delay3
extern DisplayEnemyTrainerTextAndStartBattle
extern DisplayTextID
extern EnableAutoTextBoxDrawing
extern EndTrainerBattle
extern ExecuteCurMapScriptInTable
extern GivePokemon
extern HideObject
extern MoveSprite
extern Music_RivalAlternateStart
extern PlayDefaultMusic
extern PlayMusic
extern PrintText
extern ReplaceTileBlock
extern SaveEndBattleTextPointers
extern SetSpriteFacingDirectionAndDelay   ; NOT YET DEFINED IN THE PORT
extern SetSpriteMovementBytesToFF
extern SilphCo7FRocket1BattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo7FRocket2BattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo7FRocket3BattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo7FScientistBattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo7F_TextPointers   ; NOT YET DEFINED IN THE PORT
extern SilphCo7TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern SilphCo7TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern SilphCo7TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern SilphCo7TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern SilphCo7TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern StopAllMusic
extern TalkToTrainer
extern TextScriptEnd
extern WaitForTextScrollButtonPress
extern _SilphCo7FRivalDefeatedText   ; NOT YET DEFINED IN THE PORT
extern _SilphCo7FRivalGoodLuckToYouText   ; NOT YET DEFINED IN THE PORT
extern _SilphCo7FRivalText   ; NOT YET DEFINED IN THE PORT
extern _SilphCo7FRivalVictoryText   ; NOT YET DEFINED IN THE PORT
extern _SilphCo7FRivalWaitedHereText   ; NOT YET DEFINED IN THE PORT
extern _SilphCo7FSilphWorkerM1HaveThisPokemonText   ; NOT YET DEFINED IN THE PORT
extern _SilphCo7FSilphWorkerM1IsOurPresidentOkText   ; NOT YET DEFINED IN THE PORT
extern _SilphCo7FSilphWorkerM1LaprasDescriptionText   ; NOT YET DEFINED IN THE PORT
extern _SilphCo7FSilphWorkerM1SavedText   ; NOT YET DEFINED IN THE PORT
extern _SilphCo7FSilphWorkerM2AfterTheMasterBallText   ; NOT YET DEFINED IN THE PORT
extern _SilphCo7FSilphWorkerM2CancelledMasterBallText   ; NOT YET DEFINED IN THE PORT
extern _SilphCo7FSilphWorkerM3ItWouldBeBadText   ; NOT YET DEFINED IN THE PORT
extern _SilphCo7FSilphWorkerM3YouChasedOffTeamRocketText   ; NOT YET DEFINED IN THE PORT
extern _SilphCo7FSilphWorkerM4ItsReallyDangerousHereText   ; NOT YET DEFINED IN THE PORT
extern _SilphCo7FSilphWorkerM4SafeAtLastText   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_SILPHCO7F_RIVAL_START_BATTLE            equ 3
SCRIPT_SILPHCO7F_RIVAL_AFTER_BATTLE            equ 4
SCRIPT_SILPHCO7F_RIVAL_EXIT                    equ 5
TEXT_SILPHCO7F_RIVAL                           equ 9
TEXT_SILPHCO7F_RIVAL_WAITED_HERE               equ 13
TEXT_SILPHCO7F_RIVAL_GOOD_LUCK_TO_YOU          equ 15

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
hSpriteFacingDirection                         equ 0xFF8D
hUnlockedSilphCoDoors                          equ 0xFFE0
wAddedToParty                                  equ 0xCCD3
wCoordIndex                                    equ 0xCD3D
wSavedCoordIndex                               equ 0xCF0D
wSilphCo7FCurScript                            equ 0xD647

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
SilphCo7F_Script:
    call SilphCo7F_GateCallbackScript
    call EnableAutoTextBoxDrawing
    mov esi, SilphCo7TrainerHeaders
    mov edi, SilphCo7F_ScriptPointers   ; pret: ld de, SilphCo7F_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wSilphCo7FCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wSilphCo7FCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
SilphCo7F_GateCallbackScript:
    mov esi, wCurrentMapScriptFlags
    test byte [ebp + esi], (1 << (BIT_CUR_MAP_LOADED_1))
    pushfd    ; SM83 form writes no flags
        and byte [ebp + esi], ~(1 << (BIT_CUR_MAP_LOADED_1)) & 0xFF
    popfd
    jnz .nr_15
        ret
.nr_15:
    mov esi, .GateCoordinates
    call SilphCo7F_SetCardKeyDoorYScript
    call SilphCo7F_UnlockedDoorEventScript
    CheckEvent EVENT_SILPH_CO_7_UNLOCKED_DOOR1
    jnz .unlock_door1
    pushfd
    push eax
    mov al, 0x54
    mov [ebp + wNewTileBlockID], al
    mov bx, ((3) << 8) | (5)
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call ReplaceTileBlock
    pop eax
    popfd
.unlock_door1:
    CheckEventAfterBranchReuseA EVENT_SILPH_CO_7_UNLOCKED_DOOR2, EVENT_SILPH_CO_7_UNLOCKED_DOOR1
    jnz .unlock_door2
    pushfd
    push eax
    mov al, 0x54
    mov [ebp + wNewTileBlockID], al
    mov bx, ((2) << 8) | (10)
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call ReplaceTileBlock
    pop eax
    popfd
.unlock_door2:
    CheckEventAfterBranchReuseA EVENT_SILPH_CO_7_UNLOCKED_DOOR3, EVENT_SILPH_CO_7_UNLOCKED_DOOR2
    jz .nr_38
        ret
.nr_38:
    mov al, 0x54
    mov [ebp + wNewTileBlockID], al
    mov bx, ((6) << 8) | (10)
; DEVIATION{class=banking; pret=macros/predef.asm:predef_jump; behavior=Predef dispatch replaced by a direct jmp, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    jmp ReplaceTileBlock

%assign event_byte -1
%assign event_byte_a -1
.GateCoordinates:
    db 3, 5
    db 2, 10
    db 6, 10
    db -1

%assign event_byte -1
%assign event_byte_a -1
SilphCo7F_SetCardKeyDoorYScript:
    push esi
    mov esi, wCardKeyDoorY
    mov al, [ebp + esi]
    lea esi, [esi+1]
    mov bh, al
    mov al, [ebp + esi]
    mov bl, al
    xor al, al
    mov [ebp + hUnlockedSilphCoDoors], al
    pop esi
.loop_check_doors:
    mov al, [esi]
    lea esi, [esi+1]
    cmp al, 0xff
    jz .exit_loop
    push esi
    mov esi, hUnlockedSilphCoDoors
    inc byte [ebp + esi]
    pop esi
    cmp al, bh
    jz .check_y_coord
    lea esi, [esi+1]
    jmp .loop_check_doors

%assign event_byte -1
%assign event_byte_a -1
.check_y_coord:
    mov al, [esi]
    lea esi, [esi+1]
    cmp al, bl
    jnz .loop_check_doors
    mov esi, wCardKeyDoorY
    xor al, al
    mov [ebp + esi], al
    lea esi, [esi+1]
    mov [ebp + esi], al
    ret

%assign event_byte -1
%assign event_byte_a -1
.exit_loop:
    xor al, al
    mov [ebp + hUnlockedSilphCoDoors], al
    ret

%assign event_byte -1
%assign event_byte_a -1
SilphCo7F_UnlockedDoorEventScript:
    mov esi, wEventFlags + EVENT_BYTE(EVENT_SILPH_CO_7_UNLOCKED_DOOR1)
    %assign event_byte EVENT_BYTE(EVENT_SILPH_CO_7_UNLOCKED_DOOR1)
    mov al, [ebp + hUnlockedSilphCoDoors]
    test al, al
    jnz .nr_90
        ret
.nr_90:
    cmp al, 0x1
    jnz .unlock_door1
    SetEventReuseHL EVENT_SILPH_CO_7_UNLOCKED_DOOR1
    ret

%assign event_byte -1
%assign event_byte_a -1
.unlock_door1:
    cmp al, 0x2
    jnz .unlock_door2
    SetEventAfterBranchReuseHL EVENT_SILPH_CO_7_UNLOCKED_DOOR2, EVENT_SILPH_CO_7_UNLOCKED_DOOR1
    ret

%assign event_byte -1
%assign event_byte_a -1
.unlock_door2:
    SetEventAfterBranchReuseHL EVENT_SILPH_CO_7_UNLOCKED_DOOR3, EVENT_SILPH_CO_7_UNLOCKED_DOOR1
    ret

%assign event_byte -1
%assign event_byte_a -1
SilphCo7FSetDefaultScript:
    xor al, al
    mov [ebp + wJoyIgnore], al
SilphCo7FSetCurScript:
    mov [ebp + wSilphCo7FCurScript], al
    mov [ebp + wCurMapScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
SilphCo7F_ScriptPointers:
    dd SilphCo7FDefaultScript
    dd DisplayEnemyTrainerTextAndStartBattle
    dd EndTrainerBattle
    dd SilphCo7FRivalStartBattleScript
    dd SilphCo7FRivalAfterBattleScript
    dd SilphCo7FRivalExitScript

%assign event_byte -1
%assign event_byte_a -1
SilphCo7FDefaultScript:
    CheckEvent EVENT_BEAT_SILPH_CO_RIVAL
    jnz CheckFightingMapTrainers
    mov esi, .RivalEncounterCoordinates
    call ArePlayerCoordsInArray
    jae CheckFightingMapTrainers
    xor al, al
    mov [ebp + hJoyHeld], al
    mov al, PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, PLAYER_DIR_DOWN
    mov [ebp + wPlayerMovingDirection], al
    call StopAllMusic
    mov bl, 2
    mov al, MUSIC_MEET_RIVAL
    call PlayMusic
    mov al, TEXT_SILPHCO7F_RIVAL
    mov [ebp + hTextID], al
    call DisplayTextID
    mov al, 9
    mov [ebp + hSpriteIndex], al
    call SetSpriteMovementBytesToFF
    mov edi, .RivalMovementUp   ; pret: ld de, .RivalMovementUp — MoveSprite takes it in EDI
    mov al, [ebp + wCoordIndex]
    mov [ebp + wSavedCoordIndex], al
    cmp al, 1
    jz .full_rival_movement
    inc dx
.full_rival_movement:
    mov al, 9
    mov [ebp + hSpriteIndex], al
    call MoveSprite
    mov al, SCRIPT_SILPHCO7F_RIVAL_START_BATTLE
    jmp SilphCo7FSetCurScript

%assign event_byte -1
%assign event_byte_a -1
.RivalEncounterCoordinates:
    db 2, 3
    db 3, 3
    db -1
.RivalMovementUp:
    db NPC_MOVEMENT_UP
    db NPC_MOVEMENT_UP
    db NPC_MOVEMENT_UP
    db NPC_MOVEMENT_UP
    db -1

%assign event_byte -1
%assign event_byte_a -1
SilphCo7FRivalStartBattleScript:
    mov al, [ebp + wStatusFlags5]
    test al, (1 << (BIT_SCRIPTED_NPC_MOVEMENT))
    jz .nr_172
        ret
.nr_172:
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov al, TEXT_SILPHCO7F_RIVAL_WAITED_HERE
    mov [ebp + hTextID], al
    call DisplayTextID
    call Delay3
    mov esi, wStatusFlags3
    or byte [ebp + esi], (1 << (BIT_TALKED_TO_TRAINER))
    or byte [ebp + esi], (1 << (BIT_PRINT_END_BATTLE_TEXT))
    mov esi, SilphCo7FRivalDefeatedText
    mov edx, SilphCo7FRivalVictoryText   ; pret: ld de, SilphCo7FRivalVictoryText — SaveEndBattleTextPointers takes it in EDX
    call SaveEndBattleTextPointers
    mov al, OPP_RIVAL2
    mov [ebp + wCurOpponent], al
    mov al, [ebp + wRivalStarter]
    add al, 4
    mov [ebp + wTrainerNo], al
    mov al, SCRIPT_SILPHCO7F_RIVAL_AFTER_BATTLE
    call SilphCo7FSetCurScript
    ret

%assign event_byte -1
%assign event_byte_a -1
SilphCo7FRivalAfterBattleScript:
    mov al, [ebp + wIsInBattle]
    cmp al, 0xff
    jz SilphCo7FSetDefaultScript
    mov al, PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    SetEvent EVENT_BEAT_SILPH_CO_RIVAL
    mov al, PLAYER_DIR_DOWN
    mov [ebp + wPlayerMovingDirection], al
    mov al, 9
    mov [ebp + hSpriteIndex], al
    mov al, SPRITE_FACING_UP
    mov [ebp + hSpriteFacingDirection], al
    call SetSpriteFacingDirectionAndDelay
    mov al, TEXT_SILPHCO7F_RIVAL_GOOD_LUCK_TO_YOU
    mov [ebp + hTextID], al
    call DisplayTextID
    call StopAllMusic
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call Music_RivalAlternateStart
    mov edi, .RivalWalkAroundPlayerMovement   ; pret: ld de, .RivalWalkAroundPlayerMovement — MoveSprite takes it in EDI
    mov al, [ebp + wSavedCoordIndex]
    cmp al, 1
    jnz .walk_around_player
    mov edi, .RivalExitRightMovement   ; pret: ld de, .RivalExitRightMovement — MoveSprite takes it in EDI
.walk_around_player:
    mov al, 9
    mov [ebp + hSpriteIndex], al
    call MoveSprite
    mov al, SCRIPT_SILPHCO7F_RIVAL_EXIT
    jmp SilphCo7FSetCurScript

%assign event_byte -1
%assign event_byte_a -1
.RivalExitRightMovement:
    db NPC_MOVEMENT_RIGHT
    db NPC_MOVEMENT_RIGHT
    db -1
.RivalWalkAroundPlayerMovement:
    db NPC_MOVEMENT_LEFT
    db NPC_MOVEMENT_UP
    db NPC_MOVEMENT_UP
    db NPC_MOVEMENT_RIGHT
    db NPC_MOVEMENT_RIGHT
    db NPC_MOVEMENT_RIGHT
    db NPC_MOVEMENT_DOWN
    db -1

%assign event_byte -1
%assign event_byte_a -1
SilphCo7FRivalExitScript:
    mov al, [ebp + wStatusFlags5]
    test al, (1 << (BIT_SCRIPTED_NPC_MOVEMENT))
    jz .nr_243
        ret
.nr_243:
    mov al, 171
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
    call PlayDefaultMusic
    xor al, al
    mov [ebp + wJoyIgnore], al
    jmp SilphCo7FSetCurScript

; SilphCo7F_TextPointers (scripts/SilphCo7F.asm:253-280) — not re-emitted: SilphCo7TrainerHeaders is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
SilphCo7FSilphWorkerM1Text:
    mov al, [ebp + wStatusFlags4]
    setc ah                     ; SM83 `bit` preserves C — stash it
    test al, (1 << (0))
    bt   eax, 8                 ; CF = AH bit 0 = saved C; ZF untouched
    jz .give_lapras
    CheckEvent EVENT_BEAT_SILPH_CO_GIOVANNI
    jnz .saved_silph
    mov esi, .IsOurPresidentOkText
    call PrintText
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.give_lapras:
    mov esi, .HaveThisPokemonText
    call PrintText
    mov bx, ((19) << 8) | (15)
    call GivePokemon
    jae .done
    mov al, [ebp + wAddedToParty]
    test al, al
    jnz .sk_301
        call WaitForTextScrollButtonPress
.sk_301:
    call EnableAutoTextBoxDrawing
    mov esi, .LaprasDescriptionText
    call PrintText
    mov esi, wStatusFlags4
    or byte [ebp + esi], (1 << (0))
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.saved_silph:
    mov esi, .SavedText
    call PrintText
.done:
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.HaveThisPokemonText:
    text_far _SilphCo7FSilphWorkerM1HaveThisPokemonText
    text_end
.LaprasDescriptionText:
    text_far _SilphCo7FSilphWorkerM1LaprasDescriptionText
    text_end
.IsOurPresidentOkText:
    text_far _SilphCo7FSilphWorkerM1IsOurPresidentOkText
    text_end
.SavedText:
    text_far _SilphCo7FSilphWorkerM1SavedText
    text_end

%assign event_byte -1
%assign event_byte_a -1
SilphCo7FSilphWorkerM2Text:
    CheckEvent EVENT_BEAT_SILPH_CO_GIOVANNI
    jnz .saved_silph
    mov esi, .AfterTheMasterBallText
    call PrintText
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.saved_silph:
    mov esi, .CancelledTheMasterBallText
    call PrintText
.done:
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.AfterTheMasterBallText:
    text_far _SilphCo7FSilphWorkerM2AfterTheMasterBallText
    text_end
.CancelledTheMasterBallText:
    text_far _SilphCo7FSilphWorkerM2CancelledMasterBallText
    text_end

%assign event_byte -1
%assign event_byte_a -1
SilphCo7FSilphWorkerM3Text:
    CheckEvent EVENT_BEAT_SILPH_CO_GIOVANNI
    jnz .saved_silph
    mov esi, .ItWouldBeBadText
    call PrintText
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.saved_silph:
    mov esi, .YouChasedOffTeamRocketText
    call PrintText
.done:
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.ItWouldBeBadText:
    text_far _SilphCo7FSilphWorkerM3ItWouldBeBadText
    text_end
.YouChasedOffTeamRocketText:
    text_far _SilphCo7FSilphWorkerM3YouChasedOffTeamRocketText
    text_end

%assign event_byte -1
%assign event_byte_a -1
SilphCo7FSilphWorkerM4Text:
    CheckEvent EVENT_BEAT_SILPH_CO_GIOVANNI
    jnz .saved_silph
    mov esi, .ItsReallyDangerousHereText
    call PrintText
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.saved_silph:
    mov esi, .SafeAtLastText
    call PrintText
.done:
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.ItsReallyDangerousHereText:
    text_far _SilphCo7FSilphWorkerM4ItsReallyDangerousHereText
    text_end
.SafeAtLastText:
    text_far _SilphCo7FSilphWorkerM4SafeAtLastText
    text_end

%assign event_byte -1
%assign event_byte_a -1
SilphCo7FRocket1Text:
    mov esi, SilphCo7TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; SilphCo7FRocket1BattleText (scripts/SilphCo7F.asm:400-409) — not re-emitted: SilphCo7FRocket1BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
SilphCo7FScientistText:
    mov esi, SilphCo7TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; SilphCo7FScientistBattleText (scripts/SilphCo7F.asm:418-427) — not re-emitted: SilphCo7FScientistBattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
SilphCo7FRocket2Text:
    mov esi, SilphCo7TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; SilphCo7FRocket2BattleText (scripts/SilphCo7F.asm:436-445) — not re-emitted: SilphCo7FRocket2BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
SilphCo7FRocket3Text:
    mov esi, SilphCo7TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

; SilphCo7FRocket3BattleText (scripts/SilphCo7F.asm:454-463) — not re-emitted: SilphCo7FRocket3BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
SilphCo7FRivalText:
    mov esi, .Text
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.Text:
    text_far _SilphCo7FRivalText
    text_end
SilphCo7FRivalWaitedHereText:
    text_far _SilphCo7FRivalWaitedHereText
    text_end
SilphCo7FRivalDefeatedText:
    text_far _SilphCo7FRivalDefeatedText
    text_end
SilphCo7FRivalVictoryText:
    text_far _SilphCo7FRivalVictoryText
    text_end
SilphCo7FRivalGoodLuckToYouText:
    text_far _SilphCo7FRivalGoodLuckToYouText
    text_end
