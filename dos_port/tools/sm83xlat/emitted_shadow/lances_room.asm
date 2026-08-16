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

%include "assets/audio_constants.inc"

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
global WalkToLance_RLEList

extern ArePlayerCoordsInArray   ; NOT YET DEFINED IN THE PORT
extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DecodeRLEList   ; NOT YET DEFINED IN THE PORT
extern Delay3   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern DisplayTextID   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern LancesRoomLanceAfterBattleText   ; NOT YET DEFINED IN THE PORT
extern LancesRoomLanceBeforeBattleText   ; NOT YET DEFINED IN THE PORT
extern LancesRoomLanceEndBattleText   ; NOT YET DEFINED IN THE PORT
extern LancesRoomTrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern LancesRoomTrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern LancesRoom_TextPointers   ; NOT YET DEFINED IN THE PORT
extern PlaySound   ; NOT YET DEFINED IN THE PORT
extern ReplaceTileBlock   ; NOT YET DEFINED IN THE PORT
extern StartSimulatingJoypadStates   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern WalkToLance   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_LANCESROOM_PLAYER_IS_MOVING             equ 3
TEXT_LANCESROOM_LANCE                          equ 1

; pret RAM names the port still spells in SCREAMING_SNAKE. Guarded, so
; this file assembles both before and after the memmap rename lands.
%ifndef wCurrentMapScriptFlags
wCurrentMapScriptFlags                         equ W_CURRENT_MAP_SCRIPT_FLAGS
%endif
%ifndef wNewTileBlockID
wNewTileBlockID                                equ W_NEW_TILE_BLOCK_ID
%endif
%ifndef wSimulatedJoypadStatesEnd
wSimulatedJoypadStatesEnd                      equ W_SIMULATED_JOYPAD_STATES_END
%endif
%ifndef wSimulatedJoypadStatesIndex
wSimulatedJoypadStatesIndex                    equ W_SIMULATED_JOYPAD_STATES_INDEX
%endif

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wCoordIndex                                    equ 0xCD3D
wLancesRoomCurScript                           equ 0xD652

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

LancesRoom_Script:
    call LanceShowOrHideEntranceBlocks
    call EnableAutoTextBoxDrawing
    mov esi, LancesRoomTrainerHeaders
    mov edi, LancesRoom_ScriptPointers   ; pret: ld de, LancesRoom_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wLancesRoomCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wLancesRoomCurScript], al
    ret

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
; DEVIATION{class=banking; pret=macros/predef.asm:predef_jump; behavior=Predef dispatch replaced by a direct jmp, and the predef id is not left in A because no reader is live; evidence=PredefPointers is unported and the flat model needs no bank switch, dataflow shows A dead after this site; lifetime=retired when PredefPointers is ported}
    jmp ReplaceTileBlock

ResetLanceScript:
    xor al, al
    mov [ebp + wLancesRoomCurScript], al
    ret

LancesRoom_ScriptPointers:
    dd LancesRoomDefaultScript
    dd DisplayEnemyTrainerTextAndStartBattle
    dd LancesRoomLanceEndBattleScript
    dd LancesRoomPlayerIsMovingScript
    dd LancesRoomNoopScript

LancesRoomNoopScript:
    ret

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

LanceTriggerMovementCoords:
    db 1, 5
    db 2, 6
    db 11, 5
    db 11, 6
    db 16, 24
    db -1

LancesRoomLanceEndBattleScript:
    call EndTrainerBattle
    mov al, [ebp + wIsInBattle]
    cmp al, 0xff
    jz ResetLanceScript
    mov al, TEXT_LANCESROOM_LANCE
    mov [ebp + hTextID], al
    jmp DisplayTextID

; ---------------------------------------------------------------------------
; BAIL[host-pointer-in-16bit-reg] WalkToLance (scripts/LancesRoom.asm:98-109) — at scripts/LancesRoom.asm:101: de cannot hold the 32-bit address of WalkToLance_RLEList; callee DecodeRLEList has no abi.json entry
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, PAD_BUTTONS | PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 	ld hl, wSimulatedJoypadStatesEnd
; PRET| 	ld de, WalkToLance_RLEList
; PRET| 	call DecodeRLEList
; PRET| 	dec a
; PRET| 	ld [wSimulatedJoypadStatesIndex], a
; PRET| 	call StartSimulatingJoypadStates
; PRET| 	ld a, SCRIPT_LANCESROOM_PLAYER_IS_MOVING
; PRET| 	ld [wLancesRoomCurScript], a
; PRET| 	ld [wCurMapScript], a
; PRET| 	ret

WalkToLance_RLEList:
    db PAD_UP, 13
    db PAD_LEFT, 12
    db PAD_DOWN, 7
    db PAD_LEFT, 6
    db -1

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

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] LancesRoom_TextPointers (scripts/LancesRoom.asm:130-137) — a generated asset already defines LancesRoomTrainerHeaders
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	def_text_pointers
; PRET| 	dw_const LancesRoomLanceText, TEXT_LANCESROOM_LANCE
; PRET| 
; PRET| LancesRoomTrainerHeaders:
; PRET| 	def_trainers
; PRET| LancesRoomTrainerHeader0:
; PRET| 	trainer EVENT_BEAT_LANCES_ROOM_TRAINER_0, 0, LancesRoomLanceBeforeBattleText, LancesRoomLanceEndBattleText, LancesRoomLanceAfterBattleText
; PRET| 	db -1 ; end

LancesRoomLanceText:
    mov esi, LancesRoomTrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] LancesRoomLanceBeforeBattleText (scripts/LancesRoom.asm:146-154) — a generated asset already defines LancesRoomLanceBeforeBattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _LancesRoomLanceBeforeBattleText
; PRET| 	text_end
; PRET| 
; PRET| LancesRoomLanceEndBattleText:
; PRET| 	text_far _LancesRoomLanceEndBattleText
; PRET| 	text_end
; PRET| 
; PRET| LancesRoomLanceAfterBattleText:
; PRET| 	text_far _LancesRoomLanceAfterBattleText

    SetEvent EVENT_BEAT_LANCE
    jmp TextScriptEnd
