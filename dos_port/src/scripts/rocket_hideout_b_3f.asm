; RocketHideoutB3F.asm — translated from pret scripts/RocketHideoutB3F.asm by dos_port/tools/sm83xlat.
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
%include "assets/trainer_headers.inc"

global RocketHideout3ArrowMovement1
global RocketHideout3ArrowMovement10
global RocketHideout3ArrowMovement11
global RocketHideout3ArrowMovement12
global RocketHideout3ArrowMovement2
global RocketHideout3ArrowMovement3
global RocketHideout3ArrowMovement4
global RocketHideout3ArrowMovement5
global RocketHideout3ArrowMovement6
global RocketHideout3ArrowMovement7
global RocketHideout3ArrowMovement8
global RocketHideout3ArrowMovement9
global RocketHideout3ArrowTilePlayerMovement
global RocketHideoutB3FDefaultScript
global RocketHideoutB3FPlayerSpinningScript
global RocketHideoutB3FRocket1Text
global RocketHideoutB3FRocket2Text
global RocketHideoutB3F_Script
global RocketHideoutB3F_ScriptPointers

extern CheckFightingMapTrainers
extern DecodeArrowMovementRLE
extern DisplayEnemyTrainerTextAndStartBattle
extern EnableAutoTextBoxDrawing
extern EndTrainerBattle
extern ExecuteCurMapScriptInTable
extern LoadSpinnerArrowTiles
extern PlaySound
extern RocketHideout3TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern RocketHideout3TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern RocketHideout3TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern RocketHideoutB3FRocket1BattleText   ; NOT YET DEFINED IN THE PORT
extern RocketHideoutB3FRocket2BattleText   ; NOT YET DEFINED IN THE PORT
extern RocketHideoutB3F_TextPointers   ; NOT YET DEFINED IN THE PORT
extern StartSimulatingJoypadStates
extern TalkToTrainer
extern TextScriptEnd

; Script constants — pret defines these via dw_const in this file.
SCRIPT_ROCKETHIDEOUTB3F_DEFAULT                equ 0
SCRIPT_ROCKETHIDEOUTB3F_PLAYER_SPINNING        equ 3

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wRocketHideoutB3FCurScript                     equ 0xD632

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
RocketHideoutB3F_Script:
    call EnableAutoTextBoxDrawing
    mov esi, RocketHideout3TrainerHeaders
    mov edi, RocketHideoutB3F_ScriptPointers   ; pret: ld de, RocketHideoutB3F_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRocketHideoutB3FCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRocketHideoutB3FCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
RocketHideoutB3F_ScriptPointers:
    dd RocketHideoutB3FDefaultScript
    dd DisplayEnemyTrainerTextAndStartBattle
    dd EndTrainerBattle
    dd RocketHideoutB3FPlayerSpinningScript

%assign event_byte -1
%assign event_byte_a -1
RocketHideoutB3FDefaultScript:
    mov al, [ebp + wYCoord]
    mov bh, al
    mov al, [ebp + wXCoord]
    mov bl, al
    mov esi, RocketHideout3ArrowTilePlayerMovement
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
    mov al, SCRIPT_ROCKETHIDEOUTB3F_PLAYER_SPINNING
    mov [ebp + wCurMapScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
RocketHideout3ArrowTilePlayerMovement:
    db 13, 10
    dd RocketHideout3ArrowMovement6
    db 19, 10
    dd RocketHideout3ArrowMovement1
    db 18, 11
    dd RocketHideout3ArrowMovement2
    db 11, 12
    dd RocketHideout3ArrowMovement3
    db 17, 12
    dd RocketHideout3ArrowMovement4
    db 20, 12
    dd RocketHideout3ArrowMovement5
    db 16, 13
    dd RocketHideout3ArrowMovement6
    db 11, 14
    dd RocketHideout3ArrowMovement7
    db 15, 14
    dd RocketHideout3ArrowMovement6
    db 17, 14
    dd RocketHideout3ArrowMovement8
    db 19, 14
    dd RocketHideout3ArrowMovement9
    db 16, 15
    dd RocketHideout3ArrowMovement7
    db 18, 15
    dd RocketHideout3ArrowMovement10
    db 13, 16
    dd RocketHideout3ArrowMovement11
    db 12, 17
    dd RocketHideout3ArrowMovement10
    db 16, 18
    dd RocketHideout3ArrowMovement12
    db -1
RocketHideout3ArrowMovement1:
    db PAD_RIGHT, 4
    db PAD_UP, 4
    db PAD_RIGHT, 4
    db -1
RocketHideout3ArrowMovement2:
    db PAD_DOWN, 4
    db PAD_RIGHT, 4
    db -1
RocketHideout3ArrowMovement3:
    db PAD_LEFT, 2
    db -1
RocketHideout3ArrowMovement4:
    db PAD_RIGHT, 4
    db PAD_UP, 2
    db PAD_RIGHT, 2
    db -1
RocketHideout3ArrowMovement5:
    db PAD_RIGHT, 4
    db PAD_UP, 2
    db PAD_RIGHT, 2
    db PAD_UP, 3
    db -1
RocketHideout3ArrowMovement6:
    db PAD_RIGHT, 4
    db -1
RocketHideout3ArrowMovement7:
    db PAD_RIGHT, 2
    db -1
RocketHideout3ArrowMovement8:
    db PAD_RIGHT, 4
    db PAD_UP, 2
    db -1
RocketHideout3ArrowMovement9:
    db PAD_RIGHT, 4
    db PAD_UP, 4
    db -1
RocketHideout3ArrowMovement10:
    db PAD_DOWN, 4
    db -1
RocketHideout3ArrowMovement11:
    db PAD_UP, 2
    db -1
RocketHideout3ArrowMovement12:
    db PAD_UP, 1
    db -1

%assign event_byte -1
%assign event_byte_a -1
RocketHideoutB3FPlayerSpinningScript:
    mov al, [ebp + wSimulatedJoypadStatesIndex]
    test al, al
    jnz LoadSpinnerArrowTiles
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov esi, wMovementFlags
    and byte [ebp + esi], ~(1 << (BIT_SPINNING)) & 0xFF
    mov al, SCRIPT_ROCKETHIDEOUTB3F_DEFAULT
    mov [ebp + wCurMapScript], al
    ret

; RocketHideoutB3F_TextPointers (scripts/RocketHideoutB3F.asm:129-141) — not re-emitted: RocketHideout3TrainerHeaders is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
RocketHideoutB3FRocket1Text:
    mov esi, RocketHideout3TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; RocketHideoutB3FRocket1BattleText (scripts/RocketHideoutB3F.asm:150-159) — not re-emitted: RocketHideoutB3FRocket1BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
RocketHideoutB3FRocket2Text:
    mov esi, RocketHideout3TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; RocketHideoutB3FRocket2BattleText (scripts/RocketHideoutB3F.asm:168-177) — not re-emitted: RocketHideoutB3FRocket2BattleText is already defined in assets/trainer_headers.inc.
