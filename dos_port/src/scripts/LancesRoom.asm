; LancesRoom.asm — translated from pret scripts/LancesRoom.asm by dos_port/tools/sm83xlat.
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
; Trainer headers and battle text are DEFINED once, by the single carrier
; src/data/trainer_headers.asm. Declare what this script uses; do NOT %include
; assets/trainer_headers.inc here — the asset DEFINES all 1302 symbols, so an
; include makes every one of them a duplicate global the moment a second script
; links. (That is what kept 202 link-ready scripts out of the build.)
extern LancesRoomLanceBeforeBattleText ; assets/trainer_headers.inc
extern LancesRoomTrainerHeader0        ; assets/trainer_headers.inc
extern LancesRoomTrainerHeaders        ; assets/trainer_headers.inc

global LanceShowOrHideEntranceBlocks
global LanceTriggerMovementCoords
global LancesRoomDefaultScript
global LancesRoomLanceEndBattleScript
global LancesRoomLanceText
global LancesRoomNoopScript
global LancesRoomPlayerIsMovingScript
global LancesRoom_Script
global LancesRoom_ScriptPointers
global ResetLanceScript
global WalkToLance
global WalkToLance_RLEList

extern ArePlayerCoordsInArray
extern CheckFightingMapTrainers
extern DecodeRLEList
extern Delay3
extern DisplayEnemyTrainerTextAndStartBattle
extern DisplayTextID
extern EnableAutoTextBoxDrawing
extern EndTrainerBattle
extern ExecuteCurMapScriptInTable
extern LancesRoomLanceBeforeBattleText
extern LancesRoomTrainerHeader0
extern LancesRoomTrainerHeaders
extern LancesRoom_TextPointers   ; NOT YET DEFINED IN THE PORT
extern PlaySound
extern ReplaceTileBlock
extern StartSimulatingJoypadStates
extern TalkToTrainer
extern TextScriptEnd

; Script constants — pret defines these via dw_const in this file.
SCRIPT_LANCESROOM_PLAYER_IS_MOVING             equ 3
TEXT_LANCESROOM_LANCE                          equ 1

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
LancesRoom_Script:
    call LanceShowOrHideEntranceBlocks
    call EnableAutoTextBoxDrawing
    mov esi, LancesRoomTrainerHeaders
    mov edi, LancesRoom_ScriptPointers   ; pret: ld de, LancesRoom_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wLancesRoomCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wLancesRoomCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
LanceShowOrHideEntranceBlocks:
    mov esi, wCurrentMapScriptFlags
    test byte [ebp + esi], (1 << (BIT_CUR_MAP_LOADED_1))
    pushfd    ; SM83 form writes no flags
        and byte [ebp + esi], ~(1 << (BIT_CUR_MAP_LOADED_1)) & 0xFF
    popfd
    jnz .nr_15
        ret
.nr_15:
    CheckEvent EVENT_LANCES_ROOM_LOCK_DOOR
    jnz .closeEntrance
    mov al, 0x31
    mov bh, 0x32
    jmp .setEntranceBlocks

%assign event_byte -1
%assign event_byte_a -1
.closeEntrance:
    mov al, 0x72
    mov bh, 0x73
.setEntranceBlocks:
    push ebx
    mov [ebp + wNewTileBlockID], al
    mov bx, ((6) << 8) | (2)
    call .SetEntranceBlock
    pop ebx
    mov al, bh
    mov [ebp + wNewTileBlockID], al
    mov bx, ((6) << 8) | (3)
.SetEntranceBlock:
; DEVIATION{class=banking; pret=macros/predef.asm:predef_jump; behavior=Predef dispatch replaced by a direct jmp, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    jmp ReplaceTileBlock

%assign event_byte -1
%assign event_byte_a -1
ResetLanceScript:
    xor al, al
    mov [ebp + wLancesRoomCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
LancesRoom_ScriptPointers:
    dd LancesRoomDefaultScript
    dd DisplayEnemyTrainerTextAndStartBattle
    dd LancesRoomLanceEndBattleScript
    dd LancesRoomPlayerIsMovingScript
    dd LancesRoomNoopScript

%assign event_byte -1
%assign event_byte_a -1
LancesRoomNoopScript:
    ret

%assign event_byte -1
%assign event_byte_a -1
LancesRoomDefaultScript:
    CheckEvent EVENT_BEAT_LANCE
    jz .nr_56
        ret
.nr_56:
    mov esi, LanceTriggerMovementCoords
    call ArePlayerCoordsInArray
    jae CheckFightingMapTrainers
    xor al, al
    mov [ebp + hJoyHeld], al
    mov al, [ebp + wCoordIndex]
    cmp al, 0x3
    jae .notStandingNextToLance
    mov al, TEXT_LANCESROOM_LANCE
    mov [ebp + hTextID], al
    jmp DisplayTextID

%assign event_byte -1
%assign event_byte_a -1
.notStandingNextToLance:
    cmp al, 0x5
    jz WalkToLance
    CheckAndSetEvent EVENT_LANCES_ROOM_LOCK_DOOR
    jz .nr_72
        ret
.nr_72:
    mov esi, wCurrentMapScriptFlags
    or byte [ebp + esi], (1 << (BIT_CUR_MAP_LOADED_1))
    mov al, SFX_GO_INSIDE
    call PlaySound
    jmp LanceShowOrHideEntranceBlocks

%assign event_byte -1
%assign event_byte_a -1
LanceTriggerMovementCoords:
    db 1, 5
    db 2, 6
    db 11, 5
    db 11, 6
    db 16, 24
    db -1

%assign event_byte -1
%assign event_byte_a -1
LancesRoomLanceEndBattleScript:
    call EndTrainerBattle
    mov al, [ebp + wIsInBattle]
    cmp al, 0xff
    jz ResetLanceScript
    mov al, TEXT_LANCESROOM_LANCE
    mov [ebp + hTextID], al
    jmp DisplayTextID

%assign event_byte -1
%assign event_byte_a -1
WalkToLance:
    mov al, PAD_BUTTONS | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov esi, wSimulatedJoypadStatesEnd
    mov edi, WalkToLance_RLEList   ; pret: ld de, WalkToLance_RLEList — DecodeRLEList takes it in EDI
    call DecodeRLEList
    dec al
    mov [ebp + wSimulatedJoypadStatesIndex], al
    call StartSimulatingJoypadStates
    mov al, SCRIPT_LANCESROOM_PLAYER_IS_MOVING
    mov [ebp + wLancesRoomCurScript], al
    mov [ebp + wCurMapScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
WalkToLance_RLEList:
    db PAD_UP, 13
    db PAD_LEFT, 12
    db PAD_DOWN, 7
    db PAD_LEFT, 6
    db -1

%assign event_byte -1
%assign event_byte_a -1
LancesRoomPlayerIsMovingScript:
    mov al, [ebp + wSimulatedJoypadStatesIndex]
    test al, al
    jz .nr_121
        ret
.nr_121:
    call Delay3
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov [ebp + wLancesRoomCurScript], al
    mov [ebp + wCurMapScript], al
    ret

; LancesRoom_TextPointers (scripts/LancesRoom.asm:130-137) — not re-emitted: LancesRoomTrainerHeaders is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
LancesRoomLanceText:
    mov esi, LancesRoomTrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; LancesRoomLanceBeforeBattleText (scripts/LancesRoom.asm:146-154) — not re-emitted: LancesRoomLanceBeforeBattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
    SetEvent EVENT_BEAT_LANCE
    jmp TextScriptEnd
