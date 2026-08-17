; RocketHideoutB2F.asm — translated from pret scripts/RocketHideoutB2F.asm by dos_port/tools/sm83xlat.
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

global RocketHideout2ArrowMovement1
global RocketHideout2ArrowMovement10
global RocketHideout2ArrowMovement11
global RocketHideout2ArrowMovement12
global RocketHideout2ArrowMovement13
global RocketHideout2ArrowMovement14
global RocketHideout2ArrowMovement15
global RocketHideout2ArrowMovement16
global RocketHideout2ArrowMovement17
global RocketHideout2ArrowMovement18
global RocketHideout2ArrowMovement19
global RocketHideout2ArrowMovement2
global RocketHideout2ArrowMovement20
global RocketHideout2ArrowMovement21
global RocketHideout2ArrowMovement22
global RocketHideout2ArrowMovement23
global RocketHideout2ArrowMovement24
global RocketHideout2ArrowMovement25
global RocketHideout2ArrowMovement26
global RocketHideout2ArrowMovement27
global RocketHideout2ArrowMovement28
global RocketHideout2ArrowMovement29
global RocketHideout2ArrowMovement3
global RocketHideout2ArrowMovement30
global RocketHideout2ArrowMovement31
global RocketHideout2ArrowMovement32
global RocketHideout2ArrowMovement33
global RocketHideout2ArrowMovement34
global RocketHideout2ArrowMovement35
global RocketHideout2ArrowMovement36
global RocketHideout2ArrowMovement4
global RocketHideout2ArrowMovement5
global RocketHideout2ArrowMovement6
global RocketHideout2ArrowMovement7
global RocketHideout2ArrowMovement8
global RocketHideout2ArrowMovement9
global RocketHideout2ArrowTilePlayerMovement
global RocketHideoutB2FDefaultScript
global RocketHideoutB2FPlayerSpinningScript
global RocketHideoutB2FRocketText
global RocketHideoutB2F_Script
global RocketHideoutB2F_ScriptPointers

extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DecodeArrowMovementRLE   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern LoadSpinnerArrowTiles   ; NOT YET DEFINED IN THE PORT
extern PlaySound   ; NOT YET DEFINED IN THE PORT
extern RocketHideout2TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern RocketHideout2TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern RocketHideoutB2FRocketBattleText   ; NOT YET DEFINED IN THE PORT
extern RocketHideoutB2F_TextPointers   ; NOT YET DEFINED IN THE PORT
extern StartSimulatingJoypadStates   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_ROCKETHIDEOUTB2F_DEFAULT                equ 0
SCRIPT_ROCKETHIDEOUTB2F_PLAYER_SPINNING        equ 3

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wRocketHideoutB2FCurScript                     equ 0xD631

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

RocketHideoutB2F_Script:
    call EnableAutoTextBoxDrawing
    mov esi, RocketHideout2TrainerHeaders
    mov edi, RocketHideoutB2F_ScriptPointers   ; pret: ld de, RocketHideoutB2F_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRocketHideoutB2FCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRocketHideoutB2FCurScript], al
    ret

RocketHideoutB2F_ScriptPointers:
    dd RocketHideoutB2FDefaultScript
    dd DisplayEnemyTrainerTextAndStartBattle
    dd EndTrainerBattle
    dd RocketHideoutB2FPlayerSpinningScript

RocketHideoutB2FDefaultScript:
    mov al, [ebp + wYCoord]
    mov bh, al
    mov al, [ebp + wXCoord]
    mov bl, al
    mov esi, RocketHideout2ArrowTilePlayerMovement
    call DecodeArrowMovementRLE
    cmp al, 0xff
    jz CheckFightingMapTrainers
    mov esi, wMovementFlags
    or byte [ebp + esi], (1 << (BIT_SPINNING))
    call StartSimulatingJoypadStates
    mov al, SFX_ARROW_TILES
    call PlaySound
    mov al, PAD_BUTTONS | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, SCRIPT_ROCKETHIDEOUTB2F_PLAYER_SPINNING
    mov [ebp + wCurMapScript], al
    ret

RocketHideout2ArrowTilePlayerMovement:
    db 9, 4
    dd RocketHideout2ArrowMovement1
    db 11, 4
    dd RocketHideout2ArrowMovement2
    db 15, 4
    dd RocketHideout2ArrowMovement3
    db 16, 4
    dd RocketHideout2ArrowMovement4
    db 19, 4
    dd RocketHideout2ArrowMovement1
    db 22, 4
    dd RocketHideout2ArrowMovement5
    db 14, 5
    dd RocketHideout2ArrowMovement6
    db 22, 6
    dd RocketHideout2ArrowMovement7
    db 24, 6
    dd RocketHideout2ArrowMovement8
    db 9, 8
    dd RocketHideout2ArrowMovement9
    db 12, 8
    dd RocketHideout2ArrowMovement10
    db 15, 8
    dd RocketHideout2ArrowMovement8
    db 19, 8
    dd RocketHideout2ArrowMovement9
    db 23, 8
    dd RocketHideout2ArrowMovement11
    db 14, 9
    dd RocketHideout2ArrowMovement12
    db 22, 9
    dd RocketHideout2ArrowMovement12
    db 9, 10
    dd RocketHideout2ArrowMovement13
    db 10, 10
    dd RocketHideout2ArrowMovement14
    db 15, 10
    dd RocketHideout2ArrowMovement15
    db 17, 10
    dd RocketHideout2ArrowMovement16
    db 19, 10
    dd RocketHideout2ArrowMovement17
    db 25, 10
    dd RocketHideout2ArrowMovement2
    db 14, 11
    dd RocketHideout2ArrowMovement18
    db 16, 11
    dd RocketHideout2ArrowMovement19
    db 18, 11
    dd RocketHideout2ArrowMovement12
    db 9, 12
    dd RocketHideout2ArrowMovement20
    db 11, 12
    dd RocketHideout2ArrowMovement21
    db 13, 12
    dd RocketHideout2ArrowMovement22
    db 17, 12
    dd RocketHideout2ArrowMovement23
    db 10, 13
    dd RocketHideout2ArrowMovement24
    db 12, 13
    dd RocketHideout2ArrowMovement25
    db 16, 13
    dd RocketHideout2ArrowMovement26
    db 18, 13
    dd RocketHideout2ArrowMovement27
    db 19, 13
    dd RocketHideout2ArrowMovement28
    db 22, 13
    dd RocketHideout2ArrowMovement29
    db 23, 13
    dd RocketHideout2ArrowMovement30
    db 17, 14
    dd RocketHideout2ArrowMovement31
    db 16, 15
    dd RocketHideout2ArrowMovement12
    db 14, 16
    dd RocketHideout2ArrowMovement32
    db 16, 16
    dd RocketHideout2ArrowMovement33
    db 18, 16
    dd RocketHideout2ArrowMovement34
    db 10, 17
    dd RocketHideout2ArrowMovement35
    db 11, 17
    dd RocketHideout2ArrowMovement36
    db -1
RocketHideout2ArrowMovement1:
    db PAD_LEFT, 2
    db -1
RocketHideout2ArrowMovement2:
    db PAD_RIGHT, 4
    db -1
RocketHideout2ArrowMovement3:
    db PAD_UP, 4
    db PAD_RIGHT, 4
    db -1
RocketHideout2ArrowMovement4:
    db PAD_UP, 4
    db PAD_RIGHT, 4
    db PAD_UP, 1
    db -1
RocketHideout2ArrowMovement5:
    db PAD_LEFT, 2
    db PAD_UP, 3
    db -1
RocketHideout2ArrowMovement6:
    db PAD_DOWN, 2
    db PAD_RIGHT, 4
    db -1
RocketHideout2ArrowMovement7:
    db PAD_UP, 2
    db -1
RocketHideout2ArrowMovement8:
    db PAD_UP, 4
    db -1
RocketHideout2ArrowMovement9:
    db PAD_LEFT, 6
    db -1
RocketHideout2ArrowMovement10:
    db PAD_UP, 1
    db -1
RocketHideout2ArrowMovement11:
    db PAD_LEFT, 6
    db PAD_UP, 4
    db -1
RocketHideout2ArrowMovement12:
    db PAD_DOWN, 2
    db -1
RocketHideout2ArrowMovement13:
    db PAD_LEFT, 8
    db -1
RocketHideout2ArrowMovement14:
    db PAD_LEFT, 8
    db PAD_UP, 1
    db -1
RocketHideout2ArrowMovement15:
    db PAD_LEFT, 8
    db PAD_UP, 6
    db -1
RocketHideout2ArrowMovement16:
    db PAD_UP, 2
    db PAD_RIGHT, 4
    db -1
RocketHideout2ArrowMovement17:
    db PAD_UP, 2
    db PAD_RIGHT, 4
    db PAD_UP, 2
    db -1
RocketHideout2ArrowMovement18:
    db PAD_DOWN, 2
    db PAD_RIGHT, 4
    db PAD_DOWN, 2
    db -1
RocketHideout2ArrowMovement19:
    db PAD_DOWN, 2
    db PAD_RIGHT, 4
    db -1
RocketHideout2ArrowMovement20:
    db PAD_LEFT, 10
    db -1
RocketHideout2ArrowMovement21:
    db PAD_LEFT, 10
    db PAD_UP, 2
    db -1
RocketHideout2ArrowMovement22:
    db PAD_LEFT, 10
    db PAD_UP, 4
    db -1
RocketHideout2ArrowMovement23:
    db PAD_UP, 2
    db PAD_RIGHT, 2
    db -1
RocketHideout2ArrowMovement24:
    db PAD_RIGHT, 1
    db PAD_DOWN, 2
    db -1
RocketHideout2ArrowMovement25:
    db PAD_RIGHT, 1
    db -1
RocketHideout2ArrowMovement26:
    db PAD_DOWN, 2
    db PAD_RIGHT, 2
    db -1
RocketHideout2ArrowMovement27:
    db PAD_DOWN, 2
    db PAD_LEFT, 2
    db -1
RocketHideout2ArrowMovement28:
    db PAD_UP, 2
    db PAD_RIGHT, 4
    db PAD_UP, 2
    db PAD_LEFT, 3
    db -1
RocketHideout2ArrowMovement29:
    db PAD_DOWN, 2
    db PAD_LEFT, 4
    db -1
RocketHideout2ArrowMovement30:
    db PAD_LEFT, 6
    db PAD_UP, 4
    db PAD_LEFT, 5
    db -1
RocketHideout2ArrowMovement31:
    db PAD_UP, 2
    db -1
RocketHideout2ArrowMovement32:
    db PAD_UP, 1
    db -1
RocketHideout2ArrowMovement33:
    db PAD_UP, 3
    db -1
RocketHideout2ArrowMovement34:
    db PAD_UP, 5
    db -1
RocketHideout2ArrowMovement35:
    db PAD_RIGHT, 1
    db PAD_DOWN, 2
    db PAD_LEFT, 4
    db -1
RocketHideout2ArrowMovement36:
    db PAD_LEFT, 10
    db PAD_UP, 2
    db PAD_LEFT, 5
    db -1

RocketHideoutB2FPlayerSpinningScript:
    mov al, [ebp + wSimulatedJoypadStatesIndex]
    test al, al
    jnz LoadSpinnerArrowTiles
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov esi, wMovementFlags
    and byte [ebp + esi], ~(1 << (BIT_SPINNING)) & 0xFF
    mov al, SCRIPT_ROCKETHIDEOUTB2F_DEFAULT
    mov [ebp + wCurMapScript], al
    ret

; RocketHideoutB2F_TextPointers (scripts/RocketHideoutB2F.asm:274-285) — not re-emitted: RocketHideout2TrainerHeaders is already defined in assets/trainer_headers.inc.

RocketHideoutB2FRocketText:
    mov esi, RocketHideout2TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; RocketHideoutB2FRocketBattleText (scripts/RocketHideoutB2F.asm:294-303) — not re-emitted: RocketHideoutB2FRocketBattleText is already defined in assets/trainer_headers.inc.
