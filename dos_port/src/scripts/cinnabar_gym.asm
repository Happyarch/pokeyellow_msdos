; CinnabarGym.asm — translated from pret scripts/CinnabarGym.asm, scripts/CinnabarGym_2.asm, scripts/CinnabarGym_3.asm by dos_port/tools/sm83xlat.
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
%include "assets/gym_names.inc"

global CinnabarGymBlainePostBattleScript
global CinnabarGymBlaineReceivedTM38Text
global CinnabarGymBlaineTM38NoRoomText
global CinnabarGymBlaineText
global CinnabarGymBlaineVolcanoBadgeInfoText
global CinnabarGymFlagAction
global CinnabarGymGetOpponentTextScript
global CinnabarGymGymGuideText
global CinnabarGymOpenGateScript
global CinnabarGymPrintGymGuideText
global CinnabarGymReceiveTM38
global CinnabarGymResetScripts
global CinnabarGymScript_74fa3
global CinnabarGymScript_75023
global CinnabarGymScript_75032
global CinnabarGymScript_75041
global CinnabarGymScript_753de
global CinnabarGymScript_753e9
global CinnabarGymScript_753f3
global CinnabarGymSetTrainerHeader
global CinnabarGymStartBattleScript
global CinnabarGymSuperNerd1
global CinnabarGymSuperNerd2
global CinnabarGymSuperNerd3
global CinnabarGymSuperNerd4
global CinnabarGymSuperNerd5
global CinnabarGymSuperNerd6
global CinnabarGymSuperNerd7
global CinnabarGymText_f2169
global CinnabarGymText_f216e
global CinnabarGymText_f2173
global CinnabarGymText_f2178
global CinnabarGymText_f217d
global CinnabarGymText_f2182
global CinnabarGymText_f2187
global CinnabarGym_Script
global CinnabarGym_ScriptPointers
global CinnabarGym_TextPointers
global MovementNpcToLeft
global MovementNpcToLeftAndUp
global PikachuMovementData_74f97
global PikachuMovementData_74f9e
global TextPointers_f215d

extern ApplyPikachuMovementData   ; NOT YET DEFINED IN THE PORT
extern Bankswitch   ; NOT YET DEFINED IN THE PORT
extern CallFunctionInTable   ; NOT YET DEFINED IN THE PORT
extern CinnabarGymDefaultScript   ; NOT YET DEFINED IN THE PORT
extern CinnabarGymSetMapAndTiles   ; NOT YET DEFINED IN THE PORT
extern DelayFrames   ; NOT YET DEFINED IN THE PORT
extern DisableWaitingAfterTextDisplay   ; NOT YET DEFINED IN THE PORT
extern DisplayTextID   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EngageMapTrainer   ; NOT YET DEFINED IN THE PORT
extern FlagActionPredef   ; NOT YET DEFINED IN THE PORT
extern Func_f2150   ; NOT YET DEFINED IN THE PORT
extern GetPikachuFacingDirectionAndReturnToE   ; NOT YET DEFINED IN THE PORT
extern GiveItem   ; NOT YET DEFINED IN THE PORT
extern InitBattleEnemyParameters   ; NOT YET DEFINED IN THE PORT
extern LoadGymLeaderAndCityName   ; NOT YET DEFINED IN THE PORT
extern MoveSprite   ; NOT YET DEFINED IN THE PORT
extern PlaySound   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern SaveEndBattleTextPointers   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern UpdateCinnabarGymGateTileBlocks   ; NOT YET DEFINED IN THE PORT
extern WaitForSoundToFinish   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymBlainePostBattleAdviceText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymBlainePreBattleText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymBlaineReceivedTM38Text   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymBlaineReceivedVolcanoBadgeText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymBlaineTM38ExplanationText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymBlaineTM38NoRoomText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymBlaineVolcanoBadgeInfoText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymGymGuideBeatBlaineText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymGymGuideChampInMakingText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymSuperNerd1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymSuperNerd1BattleText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymSuperNerd1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymSuperNerd2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymSuperNerd2BattleText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymSuperNerd2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymSuperNerd3AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymSuperNerd3BattleText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymSuperNerd3EndBattleText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymSuperNerd4AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymSuperNerd4BattleText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymSuperNerd4EndBattleText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymSuperNerd5AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymSuperNerd5BattleText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymSuperNerd5EndBattleText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymSuperNerd6AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymSuperNerd6BattleText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymSuperNerd6EndBattleText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymSuperNerd7AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymSuperNerd7BattleText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymSuperNerd7EndBattleText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymText_1   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymText_2   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymText_3   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymText_4   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymText_5   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymText_6   ; NOT YET DEFINED IN THE PORT
extern _CinnabarGymText_7   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_CINNABARGYM_DEFAULT                     equ 0
SCRIPT_CINNABARGYM_GET_OPPONENT_TEXT           equ 1
SCRIPT_CINNABARGYM_OPEN_GATE                   equ 2
SCRIPT_CINNABARGYM_BLAINE_POST_BATTLE          equ 3
TEXT_CINNABARGYM_BLAINE_VOLCANO_BADGE_INFO     equ 10
TEXT_CINNABARGYM_BLAINE_RECEIVED_TM38          equ 11
TEXT_CINNABARGYM_BLAINE_TM38_NO_ROOM           equ 12

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
hGymGateIndex                                  equ 0xFFDB
wBeatGymFlags                                  equ 0xD729
wCinnabarGymCurScript                          equ 0xD65D
wOpponentAfterWrongAnswer                      equ 0xDA37
wPikachuSpawnStateFlags                        equ 0xD471
wd474                                          equ 0xD474

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
CinnabarGym_Script:
    call CinnabarGymSetMapAndTiles
    call EnableAutoTextBoxDrawing
    mov esi, CinnabarGym_ScriptPointers
    mov al, [ebp + wCinnabarGymCurScript]
    jmp CallFunctionInTable

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] CinnabarGymSetMapAndTiles (scripts/CinnabarGym.asm:9-19) — at scripts/CinnabarGym.asm:13: CinnabarGymSetMapAndTiles.LoadNames is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, wCurrentMapScriptFlags
; PRET| 	bit BIT_CUR_MAP_LOADED_2, [hl]
; PRET| 	res BIT_CUR_MAP_LOADED_2, [hl]
; PRET| 	push hl
; PRET| 	call nz, .LoadNames
; PRET| 	pop hl
; PRET| 	bit BIT_CUR_MAP_LOADED_1, [hl]
; PRET| 	res BIT_CUR_MAP_LOADED_1, [hl]
; PRET| 	call nz, UpdateCinnabarGymGateTileBlocks
; PRET| 	ResetEvent EVENT_2A7
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[host-pointer-in-16bit-reg] CinnabarGymSetMapAndTiles.LoadNames (scripts/CinnabarGym.asm:22-24) — at scripts/CinnabarGym.asm:23: de cannot hold the 32-bit address of .LeaderName; callee <none in range> has no abi.json entry
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .CityName
; PRET| 	ld de, .LeaderName
; PRET| 	jp LoadGymLeaderAndCityName

%assign event_byte -1
%assign event_byte_a -1
.CityName:
    TEXT_CinnabarGymSetMapAndTiles_CityName
.LeaderName:
    TEXT_CinnabarGymSetMapAndTiles_LeaderName

%assign event_byte -1
%assign event_byte_a -1
CinnabarGymResetScripts:
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov [ebp + wCinnabarGymCurScript], al
    mov [ebp + wCurMapScript], al
    mov [ebp + wOpponentAfterWrongAnswer], al
    ret

%assign event_byte -1
%assign event_byte_a -1
CinnabarGymSetTrainerHeader:
    mov al, [ebp + hTextID]
    mov [ebp + wTrainerHeaderFlagBit], al
    ret

%assign event_byte -1
%assign event_byte_a -1
CinnabarGymFlagAction:
; DEVIATION{class=banking; pret=macros/predef.asm:predef_jump; behavior=Predef dispatch replaced by a direct jmp, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    jmp FlagActionPredef

%assign event_byte -1
%assign event_byte_a -1
CinnabarGym_ScriptPointers:
    dd CinnabarGymDefaultScript
    dd CinnabarGymGetOpponentTextScript
    dd CinnabarGymOpenGateScript
    dd CinnabarGymBlainePostBattleScript

; ---------------------------------------------------------------------------
; BAIL[host-pointer-in-16bit-reg] CinnabarGymDefaultScript (scripts/CinnabarGym.asm:56-68) — at scripts/CinnabarGym.asm:67: de cannot hold the 32-bit address of MovementNpcToLeftAndUp; callee <none in range> has no abi.json entry
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wOpponentAfterWrongAnswer]
; PRET| 	and a
; PRET| 	ret z
; PRET| 	ldh [hSpriteIndex], a
; PRET| 	cp CINNABARGYM_SUPER_NERD3
; PRET| 	jr nz, .not_super_nerd3
; PRET| 	ld a, PLAYER_DIR_DOWN
; PRET| 	ld [wPlayerMovingDirection], a
; PRET| 	ld hl, PikachuMovementData_74f97
; PRET| 	ld b, SPRITE_FACING_DOWN
; PRET| 	call CinnabarGymScript_74fa3
; PRET| 	ld de, MovementNpcToLeftAndUp
; PRET| 	jr .MoveSprite

%assign event_byte -1
%assign event_byte_a -1
.not_super_nerd3:
    mov al, PLAYER_DIR_RIGHT
    mov [ebp + wPlayerMovingDirection], al
    mov esi, PikachuMovementData_74f9e
    mov bh, SPRITE_FACING_RIGHT
    call CinnabarGymScript_74fa3
    mov edi, MovementNpcToLeft   ; pret: ld de, MovementNpcToLeft — MoveSprite takes it in EDI
.MoveSprite:
    call MoveSprite
    mov al, SCRIPT_CINNABARGYM_GET_OPPONENT_TEXT
    mov [ebp + wCinnabarGymCurScript], al
    mov [ebp + wCurMapScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
MovementNpcToLeftAndUp:
    db NPC_MOVEMENT_LEFT
    db NPC_MOVEMENT_UP
    db -1
PikachuMovementData_74f97:
    db 0x00
    db 0x20
    db 0x1e
    db 0x35
    db 0x3f
MovementNpcToLeft:
    db NPC_MOVEMENT_LEFT
    db -1
PikachuMovementData_74f9e:
    db 0x00
    db 0x1d
    db 0x1f
    db 0x38
    db 0x3f

%assign event_byte -1
%assign event_byte_a -1
CinnabarGymScript_74fa3:
    mov al, [ebp + wPikachuSpawnStateFlags]
    test al, (1 << (7))
    jnz .nr_109
        ret
.nr_109:
    push esi
    push ebx
; DEVIATION{class=banking; pret=macros/farcall.asm:callfar; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call GetPikachuFacingDirectionAndReturnToE
    pop ebx
    pop esi
    mov al, bh
    cmp al, dl
    jz .nr_117
        ret
.nr_117:
    call ApplyPikachuMovementData
    ret

%assign event_byte -1
%assign event_byte_a -1
CinnabarGymGetOpponentTextScript:
    mov al, [ebp + wStatusFlags5]
    test al, (1 << (BIT_SCRIPTED_NPC_MOVEMENT))
    jz .nr_124
        ret
.nr_124:
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov al, [ebp + wOpponentAfterWrongAnswer]
    mov [ebp + wTrainerHeaderFlagBit], al
    mov [ebp + hTextID], al
    jmp DisplayTextID

%assign event_byte -1
%assign event_byte_a -1
CinnabarGymOpenGateScript:
    call CinnabarGymScript_753e9
    mov al, [ebp + wIsInBattle]
    cmp al, 0xff
    jz CinnabarGymResetScripts
    mov al, [ebp + wTrainerHeaderFlagBit]
    sub al, 0x2
    mov bl, al
    mov bh, FLAG_TEST
    mov esi, wEventFlags + EVENT_BYTE(EVENT_CINNABAR_GYM_GATE0_UNLOCKED)
    %assign event_byte EVENT_BYTE(EVENT_CINNABAR_GYM_GATE0_UNLOCKED)
    call CinnabarGymFlagAction
    mov al, bl
    test al, al
    jnz .no_sound
    mov al, [ebp + wTrainerHeaderFlagBit]
    cmp al, 2
    jz .no_sound
    mov bl, 30
    call DelayFrames
    call CinnabarGymScript_75023
    call CinnabarGymScript_75041
    call WaitForSoundToFinish
    mov al, SFX_GO_INSIDE
    call PlaySound
    call WaitForSoundToFinish
    jmp .asm_75013

%assign event_byte -1
%assign event_byte_a -1
.no_sound:
    call CinnabarGymScript_75023
    call CinnabarGymScript_75041
.asm_75013:
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov [ebp + wOpponentAfterWrongAnswer], al
    mov al, SCRIPT_CINNABARGYM_DEFAULT
    mov [ebp + wCinnabarGymCurScript], al
    mov [ebp + wCurMapScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
CinnabarGymScript_75023:
    mov al, [ebp + wTrainerHeaderFlagBit]
    mov [ebp + hGymGateIndex], al
    mov bl, al
    mov bh, FLAG_SET
    mov esi, wEventFlags + EVENT_BYTE(EVENT_BEAT_CINNABAR_GYM_TRAINER_0)
    %assign event_byte EVENT_BYTE(EVENT_BEAT_CINNABAR_GYM_TRAINER_0)
    call CinnabarGymFlagAction
    ret

%assign event_byte -1
%assign event_byte_a -1
CinnabarGymScript_75032:
    mov al, [ebp + wTrainerHeaderFlagBit]
    mov [ebp + hGymGateIndex], al
    mov bl, al
    mov bh, FLAG_TEST
    mov esi, wEventFlags + EVENT_BYTE(EVENT_BEAT_CINNABAR_GYM_TRAINER_0)
    %assign event_byte EVENT_BYTE(EVENT_BEAT_CINNABAR_GYM_TRAINER_0)
    call CinnabarGymFlagAction
    ret

%assign event_byte -1
%assign event_byte_a -1
CinnabarGymScript_75041:
    mov al, [ebp + wTrainerHeaderFlagBit]
    sub al, 2
    mov bl, al
    mov bh, FLAG_SET
    mov esi, wEventFlags + EVENT_BYTE(EVENT_CINNABAR_GYM_GATE0_UNLOCKED)
    %assign event_byte EVENT_BYTE(EVENT_CINNABAR_GYM_GATE0_UNLOCKED)
    call CinnabarGymFlagAction
    call UpdateCinnabarGymGateTileBlocks
    ret

%assign event_byte -1
%assign event_byte_a -1
CinnabarGymBlainePostBattleScript:
    call CinnabarGymScript_753e9
    mov al, [ebp + wIsInBattle]
    cmp al, 0xff
    jz CinnabarGymResetScripts
    mov al, PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
CinnabarGymReceiveTM38:
    mov al, TEXT_CINNABARGYM_BLAINE_VOLCANO_BADGE_INFO
    mov [ebp + hTextID], al
    call DisplayTextID
    pushfd    ; SM83 form writes no flags
        SetEvent EVENT_BEAT_BLAINE
    popfd
    mov bx, ((240) << 8) | (1)
    call GiveItem
    jae .BagFull
    mov al, TEXT_CINNABARGYM_BLAINE_RECEIVED_TM38
    mov [ebp + hTextID], al
    call DisplayTextID
    SetEvent EVENT_GOT_TM38
    jmp .gymVictory

%assign event_byte -1
%assign event_byte_a -1
.BagFull:
    mov al, TEXT_CINNABARGYM_BLAINE_TM38_NO_ROOM
    mov [ebp + hTextID], al
    call DisplayTextID
.gymVictory:
    mov esi, wObtainedBadges
    or byte [ebp + esi], (1 << (6))
    mov esi, wBeatGymFlags
    or byte [ebp + esi], (1 << (6))
    SetEventRange EVENT_BEAT_CINNABAR_GYM_TRAINER_0, EVENT_BEAT_CINNABAR_GYM_TRAINER_6
    mov esi, wCurrentMapScriptFlags
    or byte [ebp + esi], (1 << (BIT_CUR_MAP_LOADED_1))
    jmp CinnabarGymResetScripts

%assign event_byte -1
%assign event_byte_a -1
CinnabarGym_TextPointers:
    dd CinnabarGymBlaineText
    dd CinnabarGymSuperNerd1
    dd CinnabarGymSuperNerd2
    dd CinnabarGymSuperNerd3
    dd CinnabarGymSuperNerd4
    dd CinnabarGymSuperNerd5
    dd CinnabarGymSuperNerd6
    dd CinnabarGymSuperNerd7
    dd CinnabarGymGymGuideText
    dd CinnabarGymBlaineVolcanoBadgeInfoText
    dd CinnabarGymBlaineReceivedTM38Text
    dd CinnabarGymBlaineTM38NoRoomText

%assign event_byte -1
%assign event_byte_a -1
CinnabarGymStartBattleScript:
    mov al, [ebp + hSpriteIndex]
    mov [ebp + wSpriteIndex], al
    call EngageMapTrainer
    call InitBattleEnemyParameters
    mov esi, wStatusFlags3
    or byte [ebp + esi], (1 << (BIT_TALKED_TO_TRAINER))
    or byte [ebp + esi], (1 << (BIT_PRINT_END_BATTLE_TEXT))
    mov al, [ebp + wSpriteIndex]
    cmp al, 1
    jz .blaine
    mov al, SCRIPT_CINNABARGYM_OPEN_GATE
    jmp .not_blaine

%assign event_byte -1
%assign event_byte_a -1
.blaine:
    mov al, SCRIPT_CINNABARGYM_BLAINE_POST_BATTLE
.not_blaine:
    mov [ebp + wCinnabarGymCurScript], al
    mov [ebp + wCurMapScript], al
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
CinnabarGymBlaineText:
    CheckEvent EVENT_BEAT_BLAINE
    jz .beforeBeat
    CheckEventReuseA EVENT_GOT_TM38
    jnz .afterBeat
    jnz .sk_278
        call CinnabarGymReceiveTM38
.sk_278:
    call DisableWaitingAfterTextDisplay
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.afterBeat:
    mov esi, .PostBattleAdviceText
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.beforeBeat:
    mov esi, .PreBattleText
    call PrintText
    mov esi, .ReceivedVolcanoBadgeText
    mov edx, .ReceivedVolcanoBadgeText   ; pret: ld de, .ReceivedVolcanoBadgeText — SaveEndBattleTextPointers takes it in EDX
    call SaveEndBattleTextPointers
    mov al, 0x7
    mov [ebp + wGymLeaderNo], al
    jmp CinnabarGymStartBattleScript

%assign event_byte -1
%assign event_byte_a -1
.PreBattleText:
    text_far _CinnabarGymBlainePreBattleText
    text_end
.ReceivedVolcanoBadgeText:
    text_far _CinnabarGymBlaineReceivedVolcanoBadgeText
    sound_get_key_item
    text_waitbutton
    text_end
.PostBattleAdviceText:
    text_far _CinnabarGymBlainePostBattleAdviceText
    text_end
CinnabarGymBlaineVolcanoBadgeInfoText:
    text_far _CinnabarGymBlaineVolcanoBadgeInfoText
    text_end
CinnabarGymBlaineReceivedTM38Text:
    text_far _CinnabarGymBlaineReceivedTM38Text
    sound_get_item_1
    text_far _CinnabarGymBlaineTM38ExplanationText
    text_end
CinnabarGymBlaineTM38NoRoomText:
    text_far _CinnabarGymBlaineTM38NoRoomText
    text_end

%assign event_byte -1
%assign event_byte_a -1
CinnabarGymSuperNerd1:
    call CinnabarGymSetTrainerHeader
    CheckEvent EVENT_BEAT_CINNABAR_GYM_TRAINER_0
    jnz .defeated
    mov esi, .BattleText
    call PrintText
    mov esi, .EndBattleText
    mov edx, .EndBattleText   ; pret: ld de, .EndBattleText — SaveEndBattleTextPointers takes it in EDX
    call SaveEndBattleTextPointers
    jmp CinnabarGymStartBattleScript

%assign event_byte -1
%assign event_byte_a -1
.defeated:
    mov esi, .AfterBattleText
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.BattleText:
    text_far _CinnabarGymSuperNerd1BattleText
    text_end
.EndBattleText:
    text_far _CinnabarGymSuperNerd1EndBattleText
    text_end
.AfterBattleText:
    text_far _CinnabarGymSuperNerd1AfterBattleText
    text_end

%assign event_byte -1
%assign event_byte_a -1
CinnabarGymSuperNerd2:
    call CinnabarGymSetTrainerHeader
    CheckEvent EVENT_BEAT_CINNABAR_GYM_TRAINER_1
    jnz .defeated
    call CinnabarGymScript_753f3
    jnz .asm_75196
    CheckEvent EVENT_CINNABAR_GYM_GATE1_UNLOCKED
    jnz .asm_75196
    mov dl, 0x00
    jmp CinnabarGymScript_753de

%assign event_byte -1
%assign event_byte_a -1
.asm_75196:
    mov esi, .BattleText
    call PrintText
    mov esi, .EndBattleText
    mov edx, .EndBattleText   ; pret: ld de, .EndBattleText — SaveEndBattleTextPointers takes it in EDX
    call SaveEndBattleTextPointers
    jmp CinnabarGymStartBattleScript

%assign event_byte -1
%assign event_byte_a -1
.defeated:
    mov esi, .AfterBattleText
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.BattleText:
    text_far _CinnabarGymSuperNerd2BattleText
    text_end
.EndBattleText:
    text_far _CinnabarGymSuperNerd2EndBattleText
    text_end
.AfterBattleText:
    text_far _CinnabarGymSuperNerd2AfterBattleText
    text_end

%assign event_byte -1
%assign event_byte_a -1
CinnabarGymSuperNerd3:
    call CinnabarGymSetTrainerHeader
    CheckEvent EVENT_BEAT_CINNABAR_GYM_TRAINER_2
    jnz .defeated
    call CinnabarGymScript_753f3
    jnz .asm_751dc
    CheckEvent EVENT_CINNABAR_GYM_GATE2_UNLOCKED
    jnz .asm_751dc
    mov dl, 0x1
    jmp CinnabarGymScript_753de

%assign event_byte -1
%assign event_byte_a -1
.asm_751dc:
    mov esi, .BattleText
    call PrintText
    mov esi, .EndBattleText
    mov edx, .EndBattleText   ; pret: ld de, .EndBattleText — SaveEndBattleTextPointers takes it in EDX
    call SaveEndBattleTextPointers
    jmp CinnabarGymStartBattleScript

%assign event_byte -1
%assign event_byte_a -1
.defeated:
    mov esi, .AfterBattleText
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.BattleText:
    text_far _CinnabarGymSuperNerd3BattleText
    text_end
.EndBattleText:
    text_far _CinnabarGymSuperNerd3EndBattleText
    text_end
.AfterBattleText:
    text_far _CinnabarGymSuperNerd3AfterBattleText
    text_end

%assign event_byte -1
%assign event_byte_a -1
CinnabarGymSuperNerd4:
    call CinnabarGymSetTrainerHeader
    CheckEvent EVENT_BEAT_CINNABAR_GYM_TRAINER_3
    jnz .defeated
    call CinnabarGymScript_753f3
    jnz .asm_75222
    CheckEvent EVENT_CINNABAR_GYM_GATE3_UNLOCKED
    jnz .asm_75222
    mov dl, 0x2
    jmp CinnabarGymScript_753de

%assign event_byte -1
%assign event_byte_a -1
.asm_75222:
    mov esi, .BattleText
    call PrintText
    mov esi, .EndBattleText
    mov edx, .EndBattleText   ; pret: ld de, .EndBattleText — SaveEndBattleTextPointers takes it in EDX
    call SaveEndBattleTextPointers
    jmp CinnabarGymStartBattleScript

%assign event_byte -1
%assign event_byte_a -1
.defeated:
    mov esi, .AfterBattleText
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.BattleText:
    text_far _CinnabarGymSuperNerd4BattleText
    text_end
.EndBattleText:
    text_far _CinnabarGymSuperNerd4EndBattleText
    text_end
.AfterBattleText:
    text_far _CinnabarGymSuperNerd4AfterBattleText
    text_end

%assign event_byte -1
%assign event_byte_a -1
CinnabarGymSuperNerd5:
    call CinnabarGymSetTrainerHeader
    CheckEvent EVENT_BEAT_CINNABAR_GYM_TRAINER_4
    jnz .defeated
    call CinnabarGymScript_753f3
    jnz .asm_75222
    CheckEvent EVENT_CINNABAR_GYM_GATE4_UNLOCKED
    jnz .asm_75222
    mov dl, 0x3
    jmp CinnabarGymScript_753de

%assign event_byte -1
%assign event_byte_a -1
.asm_75222:
    mov esi, .BattleText
    call PrintText
    mov esi, .EndBattleText
    mov edx, .EndBattleText   ; pret: ld de, .EndBattleText — SaveEndBattleTextPointers takes it in EDX
    call SaveEndBattleTextPointers
    jmp CinnabarGymStartBattleScript

%assign event_byte -1
%assign event_byte_a -1
.defeated:
    mov esi, .AfterBattleText
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.BattleText:
    text_far _CinnabarGymSuperNerd5BattleText
    text_end
.EndBattleText:
    text_far _CinnabarGymSuperNerd5EndBattleText
    text_end
.AfterBattleText:
    text_far _CinnabarGymSuperNerd5AfterBattleText
    text_end

%assign event_byte -1
%assign event_byte_a -1
CinnabarGymSuperNerd6:
    call CinnabarGymSetTrainerHeader
    CheckEvent EVENT_BEAT_CINNABAR_GYM_TRAINER_5
    jnz .defeated
    call CinnabarGymScript_753f3
    jnz .asm_75222
    CheckEvent EVENT_CINNABAR_GYM_GATE5_UNLOCKED
    jnz .asm_75222
    mov dl, 0x4
    jmp CinnabarGymScript_753de

%assign event_byte -1
%assign event_byte_a -1
.asm_75222:
    mov esi, .BattleText
    call PrintText
    mov esi, .EndBattleText
    mov edx, .EndBattleText   ; pret: ld de, .EndBattleText — SaveEndBattleTextPointers takes it in EDX
    call SaveEndBattleTextPointers
    jmp CinnabarGymStartBattleScript

%assign event_byte -1
%assign event_byte_a -1
.defeated:
    mov esi, .AfterBattleText
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.BattleText:
    text_far _CinnabarGymSuperNerd6BattleText
    text_end
.EndBattleText:
    text_far _CinnabarGymSuperNerd6EndBattleText
    text_end
.AfterBattleText:
    text_far _CinnabarGymSuperNerd6AfterBattleText
    text_end

%assign event_byte -1
%assign event_byte_a -1
CinnabarGymSuperNerd7:
    call CinnabarGymSetTrainerHeader
    CheckEvent EVENT_BEAT_CINNABAR_GYM_TRAINER_6
    jnz .defeated
    call CinnabarGymScript_753f3
    jnz .asm_75222
    CheckEvent EVENT_CINNABAR_GYM_GATE6_UNLOCKED
    jnz .asm_75222
    mov dl, 0x5
    jmp CinnabarGymScript_753de

%assign event_byte -1
%assign event_byte_a -1
.asm_75222:
    mov esi, .BattleText
    call PrintText
    mov esi, .EndBattleText
    mov edx, .EndBattleText   ; pret: ld de, .EndBattleText — SaveEndBattleTextPointers takes it in EDX
    call SaveEndBattleTextPointers
    jmp CinnabarGymStartBattleScript

%assign event_byte -1
%assign event_byte_a -1
.defeated:
    mov esi, .AfterBattleText
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.BattleText:
    text_far _CinnabarGymSuperNerd7BattleText
    text_end
.EndBattleText:
    text_far _CinnabarGymSuperNerd7EndBattleText
    text_end
.AfterBattleText:
    text_far _CinnabarGymSuperNerd7AfterBattleText
    text_end

%assign event_byte -1
%assign event_byte_a -1
CinnabarGymGymGuideText:
; DEVIATION{class=banking; pret=macros/farcall.asm:callfar; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call CinnabarGymPrintGymGuideText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
CinnabarGymScript_753de:
; DEVIATION{class=banking; pret=macros/farcall.asm:callfar; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call Func_f2150
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
CinnabarGymScript_753e9:
    push esi
    mov esi, wd474
    test byte [ebp + esi], (1 << (7))
    and byte [ebp + esi], ~(1 << (7)) & 0xFF
    pop esi
    ret

%assign event_byte -1
%assign event_byte_a -1
CinnabarGymScript_753f3:
    push esi
    mov esi, wd474
    test byte [ebp + esi], (1 << (7))
    pop esi
    ret

%assign event_byte -1
%assign event_byte_a -1
CinnabarGymPrintGymGuideText:
    CheckEvent EVENT_BEAT_BLAINE
    jnz .afterBeat
    mov esi, .ChampInMakingText
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.afterBeat:
    mov esi, .BeatBlaineText
.done:
    call PrintText
    ret

%assign event_byte -1
%assign event_byte_a -1
.ChampInMakingText:
    text_far _CinnabarGymGymGuideChampInMakingText
    text_end
.BeatBlaineText:
    text_far _CinnabarGymGymGuideBeatBlaineText
    text_end

; ---------------------------------------------------------------------------
; BAIL[add-hl-r16] Func_f2150 (scripts/CinnabarGym_3.asm:21-28) — at scripts/CinnabarGym_3.asm:23: hl de
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, TextPointers_f215d
; PRET| 	ld d, 0
; PRET| 	add hl, de
; PRET| 	add hl, de
; PRET| 	ld a, [hli]
; PRET| 	ld h, [hl]
; PRET| 	ld l, a
; PRET| 	jp PrintText

%assign event_byte -1
%assign event_byte_a -1
TextPointers_f215d:
    dd CinnabarGymText_f2169
    dd CinnabarGymText_f216e
    dd CinnabarGymText_f2173
    dd CinnabarGymText_f2178
    dd CinnabarGymText_f217d
    dd CinnabarGymText_f2182
CinnabarGymText_f2169:
    text_far _CinnabarGymText_1
    text_end
CinnabarGymText_f216e:
    text_far _CinnabarGymText_2
    text_end
CinnabarGymText_f2173:
    text_far _CinnabarGymText_3
    text_end
CinnabarGymText_f2178:
    text_far _CinnabarGymText_4
    text_end
CinnabarGymText_f217d:
    text_far _CinnabarGymText_5
    text_end
CinnabarGymText_f2182:
    text_far _CinnabarGymText_6
    text_end
CinnabarGymText_f2187:
    text_far _CinnabarGymText_7
    text_end
