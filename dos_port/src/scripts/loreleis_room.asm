; LoreleisRoom.asm — translated from pret scripts/LoreleisRoom.asm by dos_port/tools/sm83xlat.
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

global LoreleiEntranceCoords
global LoreleiScriptWalkIntoRoom
global LoreleiShowOrHideExitBlock
global LoreleisRoomDefaultScript
global LoreleisRoomLoreleiEndBattleScript
global LoreleisRoomLoreleiText
global LoreleisRoomNoopScript
global LoreleisRoomPlayerIsMovingScript
global LoreleisRoom_Script
global LoreleisRoom_ScriptPointers
global ResetLoreleiScript

extern ArePlayerCoordsInArray
extern CheckFightingMapTrainers
extern Delay3
extern DisplayEnemyTrainerTextAndStartBattle
extern DisplayTextID
extern EnableAutoTextBoxDrawing
extern EndTrainerBattle
extern ExecuteCurMapScriptInTable
extern LoreleisRoomLoreleiBeforeBattleText   ; NOT YET DEFINED IN THE PORT
extern LoreleisRoomTrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern LoreleisRoomTrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern LoreleisRoom_TextPointers   ; NOT YET DEFINED IN THE PORT
extern ReplaceTileBlock
extern StartSimulatingJoypadStates
extern TalkToTrainer
extern TextScriptEnd

; Script constants — pret defines these via dw_const in this file.
SCRIPT_LORELEISROOM_PLAYER_IS_MOVING           equ 3
TEXT_LORELEISROOM_LORELEI                      equ 1
TEXT_LORELEISROOM_DONT_RUN_AWAY                equ 2

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wCoordIndex                                    equ 0xCD3D
wLoreleisRoomCurScript                         equ 0xD64C

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
LoreleisRoom_Script:
    call LoreleiShowOrHideExitBlock
    call EnableAutoTextBoxDrawing
    mov esi, LoreleisRoomTrainerHeaders
    mov edi, LoreleisRoom_ScriptPointers   ; pret: ld de, LoreleisRoom_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wLoreleisRoomCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wLoreleisRoomCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
LoreleiShowOrHideExitBlock:
    mov esi, wCurrentMapScriptFlags
    test byte [ebp + esi], (1 << (BIT_CUR_MAP_LOADED_1))
    pushfd    ; SM83 form writes no flags
        and byte [ebp + esi], ~(1 << (BIT_CUR_MAP_LOADED_1)) & 0xFF
    popfd
    jnz .nr_16
        ret
.nr_16:
    mov esi, wElite4Flags
    or byte [ebp + esi], (1 << (BIT_STARTED_ELITE_4))
    CheckEvent EVENT_BEAT_LORELEIS_ROOM_TRAINER_0
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
ResetLoreleiScript:
    xor al, al
    mov [ebp + wLoreleisRoomCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
LoreleisRoom_ScriptPointers:
    dd LoreleisRoomDefaultScript
    dd DisplayEnemyTrainerTextAndStartBattle
    dd LoreleisRoomLoreleiEndBattleScript
    dd LoreleisRoomPlayerIsMovingScript
    dd LoreleisRoomNoopScript

%assign event_byte -1
%assign event_byte_a -1
LoreleisRoomNoopScript:
    ret

%assign event_byte -1
%assign event_byte_a -1
LoreleiScriptWalkIntoRoom:
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
    mov al, SCRIPT_LORELEISROOM_PLAYER_IS_MOVING
    mov [ebp + wLoreleisRoomCurScript], al
    mov [ebp + wCurMapScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
LoreleisRoomDefaultScript:
    mov esi, LoreleiEntranceCoords
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
    CheckAndSetEvent EVENT_AUTOWALKED_INTO_LORELEIS_ROOM
    jz LoreleiScriptWalkIntoRoom
.stopPlayerFromLeaving:
    mov al, TEXT_LORELEISROOM_DONT_RUN_AWAY
    mov [ebp + hTextID], al
    call DisplayTextID
    mov al, PAD_UP
    mov [ebp + wSimulatedJoypadStatesEnd], al
    mov al, 0x1
    mov [ebp + wSimulatedJoypadStatesIndex], al
    call StartSimulatingJoypadStates
    mov al, SCRIPT_LORELEISROOM_PLAYER_IS_MOVING
    mov [ebp + wLoreleisRoomCurScript], al
    mov [ebp + wCurMapScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
LoreleiEntranceCoords:
    db 10, 4
    db 10, 5
    db 11, 4
    db 11, 5
    db -1

%assign event_byte -1
%assign event_byte_a -1
LoreleisRoomPlayerIsMovingScript:
    mov al, [ebp + wSimulatedJoypadStatesIndex]
    test al, al
    jz .nr_102
        ret
.nr_102:
    call Delay3
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov [ebp + wLoreleisRoomCurScript], al
    mov [ebp + wCurMapScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
LoreleisRoomLoreleiEndBattleScript:
    call EndTrainerBattle
    mov al, [ebp + wIsInBattle]
    cmp al, 0xff
    jz ResetLoreleiScript
    mov al, TEXT_LORELEISROOM_LORELEI
    mov [ebp + hTextID], al
    jmp DisplayTextID

; LoreleisRoom_TextPointers (scripts/LoreleisRoom.asm:120-128) — not re-emitted: LoreleisRoomTrainerHeaders is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
LoreleisRoomLoreleiText:
    mov esi, LoreleisRoomTrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; LoreleisRoomLoreleiBeforeBattleText (scripts/LoreleisRoom.asm:137-150) — not re-emitted: LoreleisRoomLoreleiBeforeBattleText is already defined in assets/trainer_headers.inc.
