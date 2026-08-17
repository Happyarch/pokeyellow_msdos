; AgathasRoom.asm — translated from pret scripts/AgathasRoom.asm by dos_port/tools/sm83xlat.
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

%include "assets/trainer_headers.inc"

global AgathaEntranceCoords
global AgathaScriptWalkIntoRoom
global AgathaShowOrHideExitBlock
global AgathasRoomAgathaEndBattleScript
global AgathasRoomAgathaText
global AgathasRoomDefaultScript
global AgathasRoomNoopScript
global AgathasRoomPlayerIsMovingScript
global AgathasRoom_Script
global AgathasRoom_ScriptPointers
global ResetAgathaScript

extern AgathaBeforeBattleText   ; NOT YET DEFINED IN THE PORT
extern AgathasRoomTrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern AgathasRoomTrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern AgathasRoom_TextPointers   ; NOT YET DEFINED IN THE PORT
extern ArePlayerCoordsInArray
extern CheckFightingMapTrainers
extern Delay3
extern DisplayEnemyTrainerTextAndStartBattle
extern DisplayTextID
extern EnableAutoTextBoxDrawing
extern EndTrainerBattle
extern ExecuteCurMapScriptInTable
extern ReplaceTileBlock
extern StartSimulatingJoypadStates
extern TalkToTrainer
extern TextScriptEnd

; Script constants — pret defines these via dw_const in this file.
SCRIPT_AGATHASROOM_PLAYER_IS_MOVING            equ 3
TEXT_AGATHASROOM_AGATHA                        equ 1
TEXT_AGATHASROOM_AGATHA_DONT_RUN_AWAY          equ 2
SCRIPT_CHAMPIONSROOM_PLAYER_ENTERS             equ 1

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wAgathasRoomCurScript                          equ 0xD64E
wChampionsRoomCurScript                        equ 0xD64B
wCoordIndex                                    equ 0xCD3D

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
AgathasRoom_Script:
    call AgathaShowOrHideExitBlock
    call EnableAutoTextBoxDrawing
    mov esi, AgathasRoomTrainerHeaders
    mov edi, AgathasRoom_ScriptPointers   ; pret: ld de, AgathasRoom_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wAgathasRoomCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wAgathasRoomCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
AgathaShowOrHideExitBlock:
    mov esi, wCurrentMapScriptFlags
    test byte [ebp + esi], (1 << (BIT_CUR_MAP_LOADED_1))
    pushfd    ; SM83 form writes no flags
        and byte [ebp + esi], ~(1 << (BIT_CUR_MAP_LOADED_1)) & 0xFF
    popfd
    jnz .nr_16
        ret
.nr_16:
    CheckEvent EVENT_BEAT_AGATHAS_ROOM_TRAINER_0
    jz .blockExitToNextRoom
    mov al, 0xe
    jmp .setExitBlock

%assign event_byte -1
%assign event_byte_a -1
.blockExitToNextRoom:
    mov al, 0x3b
.setExitBlock:
    mov [ebp + wNewTileBlockID], al
    mov bx, ((0) << 8) | (2)
; DEVIATION{class=banking; pret=macros/predef.asm:predef_jump; behavior=Predef dispatch replaced by a direct jmp, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    jmp ReplaceTileBlock

%assign event_byte -1
%assign event_byte_a -1
ResetAgathaScript:
    xor al, al
    mov [ebp + wAgathasRoomCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
AgathasRoom_ScriptPointers:
    dd AgathasRoomDefaultScript
    dd DisplayEnemyTrainerTextAndStartBattle
    dd AgathasRoomAgathaEndBattleScript
    dd AgathasRoomPlayerIsMovingScript
    dd AgathasRoomNoopScript

%assign event_byte -1
%assign event_byte_a -1
AgathasRoomNoopScript:
    ret

%assign event_byte -1
%assign event_byte_a -1
AgathaScriptWalkIntoRoom:
    mov esi, wSimulatedJoypadStatesEnd
    mov al, PAD_UP
    mov [ebp + esi], al
    lea esi, [esi+1]
    mov [ebp + esi], al
    lea esi, [esi+1]
    mov [ebp + esi], al
    lea esi, [esi+1]
    mov [ebp + esi], al
    lea esi, [esi+1]
    mov [ebp + esi], al
    lea esi, [esi+1]
    mov [ebp + esi], al
    mov al, 0x6
    mov [ebp + wSimulatedJoypadStatesIndex], al
    call StartSimulatingJoypadStates
    mov al, SCRIPT_AGATHASROOM_PLAYER_IS_MOVING
    mov [ebp + wAgathasRoomCurScript], al
    mov [ebp + wCurMapScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
AgathasRoomDefaultScript:
    mov esi, AgathaEntranceCoords
    call ArePlayerCoordsInArray
    jae CheckFightingMapTrainers
    xor al, al
    mov [ebp + hJoyPressed], al
    mov [ebp + hJoyHeld], al
    mov [ebp + wSimulatedJoypadStatesEnd], al
    mov [ebp + wSimulatedJoypadStatesIndex], al
    mov al, [ebp + wCoordIndex]
    cmp al, 0x3
    jb .stopPlayerFromLeaving
    CheckAndSetEvent EVENT_AUTOWALKED_INTO_AGATHAS_ROOM
    jz AgathaScriptWalkIntoRoom
.stopPlayerFromLeaving:
    mov al, TEXT_AGATHASROOM_AGATHA_DONT_RUN_AWAY
    mov [ebp + hTextID], al
    call DisplayTextID
    mov al, PAD_UP
    mov [ebp + wSimulatedJoypadStatesEnd], al
    mov al, 0x1
    mov [ebp + wSimulatedJoypadStatesIndex], al
    call StartSimulatingJoypadStates
    mov al, SCRIPT_AGATHASROOM_PLAYER_IS_MOVING
    mov [ebp + wAgathasRoomCurScript], al
    mov [ebp + wCurMapScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
AgathaEntranceCoords:
    db 10, 4
    db 10, 5
    db 11, 4
    db 11, 5
    db -1

%assign event_byte -1
%assign event_byte_a -1
AgathasRoomPlayerIsMovingScript:
    mov al, [ebp + wSimulatedJoypadStatesIndex]
    test al, al
    jz .nr_100
        ret
.nr_100:
    call Delay3
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov [ebp + wAgathasRoomCurScript], al
    mov [ebp + wCurMapScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
AgathasRoomAgathaEndBattleScript:
    call EndTrainerBattle
    mov al, [ebp + wIsInBattle]
    cmp al, 0xff
    jz ResetAgathaScript
    mov al, TEXT_AGATHASROOM_AGATHA
    mov [ebp + hTextID], al
    call DisplayTextID
    mov al, SCRIPT_CHAMPIONSROOM_PLAYER_ENTERS
    mov [ebp + wChampionsRoomCurScript], al
    ret

; AgathasRoom_TextPointers (scripts/AgathasRoom.asm:121-129) — not re-emitted: AgathasRoomTrainerHeaders is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
AgathasRoomAgathaText:
    mov esi, AgathasRoomTrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; AgathaBeforeBattleText (scripts/AgathasRoom.asm:138-151) — not re-emitted: AgathaBeforeBattleText is already defined in assets/trainer_headers.inc.
