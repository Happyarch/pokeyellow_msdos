; BrunosRoom.asm — translated from pret scripts/BrunosRoom.asm by dos_port/tools/sm83xlat.
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

%include "assets/trainer_headers.inc"

global BrunoEntranceCoords
global BrunoScriptWalkIntoRoom
global BrunoShowOrHideExitBlock
global BrunosRoomBrunoEndBattleScript
global BrunosRoomBrunoText
global BrunosRoomDefaultScript
global BrunosRoomNoopScript
global BrunosRoomPlayerIsMovingScript
global BrunosRoom_Script
global BrunosRoom_ScriptPointers
global ResetBrunoScript

extern ArePlayerCoordsInArray   ; NOT YET DEFINED IN THE PORT
extern BrunoBeforeBattleText   ; NOT YET DEFINED IN THE PORT
extern BrunosRoomTrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern BrunosRoomTrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern BrunosRoom_TextPointers   ; NOT YET DEFINED IN THE PORT
extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern Delay3   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern DisplayTextID   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern ReplaceTileBlock   ; NOT YET DEFINED IN THE PORT
extern StartSimulatingJoypadStates   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_BRUNOSROOM_PLAYER_IS_MOVING             equ 3
TEXT_BRUNOSROOM_BRUNO                          equ 1
TEXT_BRUNOSROOM_BRUNO_DONT_RUN_AWAY            equ 2

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wBrunosRoomCurScript                           equ 0xD64D
wCoordIndex                                    equ 0xCD3D

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
BrunosRoom_Script:
    call BrunoShowOrHideExitBlock
    call EnableAutoTextBoxDrawing
    mov esi, BrunosRoomTrainerHeaders
    mov edi, BrunosRoom_ScriptPointers   ; pret: ld de, BrunosRoom_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wBrunosRoomCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wBrunosRoomCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
BrunoShowOrHideExitBlock:
    mov esi, wCurrentMapScriptFlags
    test byte [ebp + esi], (1 << (BIT_CUR_MAP_LOADED_1))
    pushfd    ; SM83 form writes no flags
        and byte [ebp + esi], ~(1 << (BIT_CUR_MAP_LOADED_1)) & 0xFF
    popfd
    jnz .nr_16
        ret
.nr_16:
    CheckEvent EVENT_BEAT_BRUNOS_ROOM_TRAINER_0
    jz .blockExitToNextRoom
    mov al, 0x5
    jmp .setExitBlock

%assign event_byte -1
%assign event_byte_a -1
.blockExitToNextRoom:
    mov al, 0x24
.setExitBlock:
    mov [ebp + wNewTileBlockID], al
    mov bx, ((0) << 8) | (2)
; DEVIATION{class=banking; pret=macros/predef.asm:predef_jump; behavior=Predef dispatch replaced by a direct jmp, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    jmp ReplaceTileBlock

%assign event_byte -1
%assign event_byte_a -1
ResetBrunoScript:
    xor al, al
    mov [ebp + wBrunosRoomCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
BrunosRoom_ScriptPointers:
    dd BrunosRoomDefaultScript
    dd DisplayEnemyTrainerTextAndStartBattle
    dd BrunosRoomBrunoEndBattleScript
    dd BrunosRoomPlayerIsMovingScript
    dd BrunosRoomNoopScript

%assign event_byte -1
%assign event_byte_a -1
BrunosRoomNoopScript:
    ret

%assign event_byte -1
%assign event_byte_a -1
BrunoScriptWalkIntoRoom:
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
    mov al, SCRIPT_BRUNOSROOM_PLAYER_IS_MOVING
    mov [ebp + wBrunosRoomCurScript], al
    mov [ebp + wCurMapScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
BrunosRoomDefaultScript:
    mov esi, BrunoEntranceCoords
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
    CheckAndSetEvent EVENT_AUTOWALKED_INTO_BRUNOS_ROOM
    jz BrunoScriptWalkIntoRoom
.stopPlayerFromLeaving:
    mov al, TEXT_BRUNOSROOM_BRUNO_DONT_RUN_AWAY
    mov [ebp + hTextID], al
    call DisplayTextID
    mov al, PAD_UP
    mov [ebp + wSimulatedJoypadStatesEnd], al
    mov al, 0x1
    mov [ebp + wSimulatedJoypadStatesIndex], al
    call StartSimulatingJoypadStates
    mov al, SCRIPT_BRUNOSROOM_PLAYER_IS_MOVING
    mov [ebp + wBrunosRoomCurScript], al
    mov [ebp + wCurMapScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
BrunoEntranceCoords:
    db 10, 4
    db 10, 5
    db 11, 4
    db 11, 5
    db -1

%assign event_byte -1
%assign event_byte_a -1
BrunosRoomPlayerIsMovingScript:
    mov al, [ebp + wSimulatedJoypadStatesIndex]
    test al, al
    jz .nr_100
        ret
.nr_100:
    call Delay3
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov [ebp + wBrunosRoomCurScript], al
    mov [ebp + wCurMapScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
BrunosRoomBrunoEndBattleScript:
    call EndTrainerBattle
    mov al, [ebp + wIsInBattle]
    cmp al, 0xff
    jz ResetBrunoScript
    mov al, TEXT_BRUNOSROOM_BRUNO
    mov [ebp + hTextID], al
    jmp DisplayTextID

; BrunosRoom_TextPointers (scripts/BrunosRoom.asm:118-126) — not re-emitted: BrunosRoomTrainerHeaders is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
BrunosRoomBrunoText:
    mov esi, BrunosRoomTrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; BrunoBeforeBattleText (scripts/BrunosRoom.asm:135-148) — not re-emitted: BrunoBeforeBattleText is already defined in assets/trainer_headers.inc.
