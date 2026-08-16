; SSAnne2F.asm — translated from pret scripts/SSAnne2F.asm by dos_port/tools/sm83xlat.
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

global SSAnne2FNoopScript
global SSAnne2FResetScripts
global SSAnne2FRivalCutMasterText
global SSAnne2FRivalDefeatedText
global SSAnne2FRivalStartBattleScript
global SSAnne2FRivalText
global SSAnne2FRivalVictoryText
global SSAnne2FSetFacingDirectionScript
global SSAnne2FWaiterText
global SSAnne2F_Script
global SSAnne2F_ScriptPointers
global SSAnne2F_TextPointers

extern ArePlayerCoordsInArray   ; NOT YET DEFINED IN THE PORT
extern Bankswitch   ; NOT YET DEFINED IN THE PORT
extern CallFunctionInTable   ; NOT YET DEFINED IN THE PORT
extern Delay3   ; NOT YET DEFINED IN THE PORT
extern DisplayTextID   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern HideObject   ; NOT YET DEFINED IN THE PORT
extern MoveSprite   ; NOT YET DEFINED IN THE PORT
extern Music_RivalAlternateStart   ; NOT YET DEFINED IN THE PORT
extern PlayDefaultMusic   ; NOT YET DEFINED IN THE PORT
extern PlayMusic   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern SSAnne2FDefaultScript   ; NOT YET DEFINED IN THE PORT
extern SSAnne2FRivalAfterBattleScript   ; NOT YET DEFINED IN THE PORT
extern SSAnne2FRivalExitScript   ; NOT YET DEFINED IN THE PORT
extern SaveEndBattleTextPointers   ; NOT YET DEFINED IN THE PORT
extern SetSpriteFacingDirectionAndDelay   ; NOT YET DEFINED IN THE PORT
extern SetSpriteMovementBytesToFF   ; NOT YET DEFINED IN THE PORT
extern ShowObject   ; NOT YET DEFINED IN THE PORT
extern StopAllMusic   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern _SSAnne2FRivalCutMasterText   ; NOT YET DEFINED IN THE PORT
extern _SSAnne2FRivalDefeatedText   ; NOT YET DEFINED IN THE PORT
extern _SSAnne2FRivalText   ; NOT YET DEFINED IN THE PORT
extern _SSAnne2FRivalVictoryText   ; NOT YET DEFINED IN THE PORT
extern _SSAnne2FWaiterText   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_SSANNE2F_RIVAL_START_BATTLE             equ 1
SCRIPT_SSANNE2F_RIVAL_AFTER_BATTLE             equ 2
SCRIPT_SSANNE2F_RIVAL_EXIT                     equ 3
SCRIPT_SSANNE2F_NOOP                           equ 4
TEXT_SSANNE2F_RIVAL                            equ 2
TEXT_SSANNE2F_RIVAL_CUT_MASTER                 equ 3

; pret RAM names the port still spells in SCREAMING_SNAKE. Guarded, so
; this file assembles both before and after the memmap rename lands.
%ifndef wPlayerMovingDirection
wPlayerMovingDirection                         equ W_PLAYER_MOVING_DIRECTION
%endif
%ifndef wXCoord
wXCoord                                        equ W_X_COORD
%endif

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
hSavedCoordIndex                               equ 0xFFDB
hSpriteFacingDirection                         equ 0xFF8D
wCoordIndex                                    equ 0xCD3D
wSSAnne2FCurScript                             equ 0xD664

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

SSAnne2F_Script:
    call EnableAutoTextBoxDrawing
    mov esi, SSAnne2F_ScriptPointers
    mov al, [ebp + wSSAnne2FCurScript]
    jmp CallFunctionInTable

SSAnne2FResetScripts:
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov [ebp + wSSAnne2FCurScript], al
    ret

SSAnne2F_ScriptPointers:
    dd SSAnne2FDefaultScript
    dd SSAnne2FRivalStartBattleScript
    dd SSAnne2FRivalAfterBattleScript
    dd SSAnne2FRivalExitScript
    dd SSAnne2FNoopScript

SSAnne2FNoopScript:
    ret

; ---------------------------------------------------------------------------
; BAIL[bank-expression] SSAnne2FDefaultScript (scripts/SSAnne2F.asm:25-49) — at scripts/SSAnne2F.asm:29: BANK(Music_MeetRival)
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .PlayerCoordinatesArray
; PRET| 	call ArePlayerCoordsInArray
; PRET| 	ret nc
; PRET| 	call StopAllMusic
; PRET| 	ld c, BANK(Music_MeetRival)
; PRET| 	ld a, MUSIC_MEET_RIVAL
; PRET| 	call PlayMusic
; PRET| 	ld a, [wCoordIndex]
; PRET| 	ldh [hSavedCoordIndex], a
; PRET| 	ld a, TOGGLE_SS_ANNE_2F_RIVAL
; PRET| 	ld [wToggleableObjectIndex], a
; PRET| 	predef ShowObject
; PRET| 	call Delay3
; PRET| 	ld a, SSANNE2F_RIVAL
; PRET| 	ldh [hSpriteIndex], a
; PRET| 	call SetSpriteMovementBytesToFF
; PRET| 	xor a
; PRET| 	ldh [hJoyHeld], a
; PRET| 	ld a, PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 	ldh a, [hSavedCoordIndex]
; PRET| 	cp $2
; PRET| 	jr nz, .player_standing_right
; PRET| 	ld de, .RivalDownFourMovement
; PRET| 	jr .move_sprite

.player_standing_right:
    mov edi, .RivalDownThreeMovement   ; pret: ld de, .RivalDownThreeMovement — MoveSprite takes it in EDI
.move_sprite:
    call MoveSprite
    mov al, SCRIPT_SSANNE2F_RIVAL_START_BATTLE
    mov [ebp + wSSAnne2FCurScript], al
    ret

.RivalDownFourMovement:
    db NPC_MOVEMENT_DOWN
.RivalDownThreeMovement:
    db NPC_MOVEMENT_DOWN
    db NPC_MOVEMENT_DOWN
    db NPC_MOVEMENT_DOWN
    db -1
.PlayerCoordinatesArray:
    db 8, 36
    db 8, 37
    db -1

SSAnne2FSetFacingDirectionScript:
    mov al, [ebp + wXCoord]
    cmp al, 37
    jnz .player_standing_left
    mov al, PLAYER_DIR_LEFT
    mov [ebp + wPlayerMovingDirection], al
    mov al, SPRITE_FACING_RIGHT
    jmp .set_facing_direction

.player_standing_left:
    xor al, al
.set_facing_direction:
    mov [ebp + hSpriteFacingDirection], al
    mov al, 2
    mov [ebp + hSpriteIndex], al
    jmp SetSpriteFacingDirectionAndDelay

SSAnne2FRivalStartBattleScript:
    mov al, [ebp + wStatusFlags5]
    test al, (1 << (BIT_SCRIPTED_NPC_MOVEMENT))
    jz .nr_90
        ret
.nr_90:
    call SSAnne2FSetFacingDirectionScript
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov al, TEXT_SSANNE2F_RIVAL
    mov [ebp + hTextID], al
    call DisplayTextID
    call Delay3
    mov al, OPP_RIVAL2
    mov [ebp + wCurOpponent], al
    mov al, 0x1
    mov [ebp + wTrainerNo], al
    call SSAnne2FSetFacingDirectionScript
    mov al, SCRIPT_SSANNE2F_RIVAL_AFTER_BATTLE
    mov [ebp + wSSAnne2FCurScript], al
    ret

; ---------------------------------------------------------------------------
; BAIL[host-pointer-in-16bit-reg] SSAnne2FRivalAfterBattleScript (scripts/SSAnne2F.asm:108-124) — at scripts/SSAnne2F.asm:123: de cannot hold the 32-bit address of .RivalDownFourMovement; callee <none in range> has no abi.json entry
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wIsInBattle]
; PRET| 	cp $ff
; PRET| 	jp z, SSAnne2FResetScripts
; PRET| 	call SSAnne2FSetFacingDirectionScript
; PRET| 	ld a, PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 	ld a, TEXT_SSANNE2F_RIVAL_CUT_MASTER
; PRET| 	ldh [hTextID], a
; PRET| 	call DisplayTextID
; PRET| 	ld a, SSANNE2F_RIVAL
; PRET| 	ldh [hSpriteIndex], a
; PRET| 	call SetSpriteMovementBytesToFF
; PRET| 	ld a, [wXCoord]
; PRET| 	cp 37
; PRET| 	jr nz, .player_standing_left
; PRET| 	ld de, .RivalDownFourMovement
; PRET| 	jr .move_sprite

.player_standing_left:
    mov edi, .RivalWalkAroundPlayerMovement   ; pret: ld de, .RivalWalkAroundPlayerMovement — MoveSprite takes it in EDI
.move_sprite:
    mov al, 2
    mov [ebp + hSpriteIndex], al
    call MoveSprite
    call StopAllMusic
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call Music_RivalAlternateStart
    mov al, SCRIPT_SSANNE2F_RIVAL_EXIT
    mov [ebp + wSSAnne2FCurScript], al
    ret

.RivalWalkAroundPlayerMovement:
    db NPC_MOVEMENT_RIGHT
    db NPC_MOVEMENT_DOWN
.RivalDownFourMovement:
    db NPC_MOVEMENT_DOWN
    db NPC_MOVEMENT_DOWN
    db NPC_MOVEMENT_DOWN
    db NPC_MOVEMENT_DOWN
    db -1

; ---------------------------------------------------------------------------
; BAIL[predef-leaves-id-in-a] SSAnne2FRivalExitScript (scripts/SSAnne2F.asm:148-159) — at scripts/SSAnne2F.asm:155: predef HideObject
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wStatusFlags5]
; PRET| 	bit BIT_SCRIPTED_NPC_MOVEMENT, a
; PRET| 	ret nz
; PRET| 	xor a
; PRET| 	ld [wJoyIgnore], a
; PRET| 	ld a, TOGGLE_SS_ANNE_2F_RIVAL
; PRET| 	ld [wToggleableObjectIndex], a
; PRET| 	predef HideObject
; PRET| 	call PlayDefaultMusic
; PRET| 	ld a, SCRIPT_SSANNE2F_NOOP
; PRET| 	ld [wSSAnne2FCurScript], a
; PRET| 	ret

SSAnne2F_TextPointers:
    dd SSAnne2FWaiterText
    dd SSAnne2FRivalText
    dd SSAnne2FRivalCutMasterText
SSAnne2FWaiterText:
    text_far _SSAnne2FWaiterText
    text_end

SSAnne2FRivalText:
    mov esi, .Text
    call PrintText
    mov esi, wStatusFlags3
    or byte [ebp + esi], (1 << (BIT_TALKED_TO_TRAINER))
    or byte [ebp + esi], (1 << (BIT_PRINT_END_BATTLE_TEXT))
    mov esi, SSAnne2FRivalDefeatedText
    mov edx, SSAnne2FRivalVictoryText   ; pret: ld de, SSAnne2FRivalVictoryText — SaveEndBattleTextPointers takes it in EDX
    call SaveEndBattleTextPointers
    jmp TextScriptEnd

.Text:
    text_far _SSAnne2FRivalText
    text_end
SSAnne2FRivalDefeatedText:
    text_far _SSAnne2FRivalDefeatedText
    text_end
SSAnne2FRivalVictoryText:
    text_far _SSAnne2FRivalVictoryText
    text_end
SSAnne2FRivalCutMasterText:
    text_far _SSAnne2FRivalCutMasterText
    text_end
