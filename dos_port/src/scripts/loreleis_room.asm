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

extern ArePlayerCoordsInArray   ; NOT YET DEFINED IN THE PORT
extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern Delay3   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern DisplayTextID   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern LoreleisRoomLoreleiAfterBattleText   ; NOT YET DEFINED IN THE PORT
extern LoreleisRoomLoreleiBeforeBattleText   ; NOT YET DEFINED IN THE PORT
extern LoreleisRoomLoreleiDontRunAwayText   ; NOT YET DEFINED IN THE PORT
extern LoreleisRoomLoreleiEndBattleText   ; NOT YET DEFINED IN THE PORT
extern LoreleisRoomTrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern LoreleisRoomTrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern LoreleisRoom_TextPointers   ; NOT YET DEFINED IN THE PORT
extern ReplaceTileBlock   ; NOT YET DEFINED IN THE PORT
extern StartSimulatingJoypadStates   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

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

LoreleisRoom_Script:
    call LoreleiShowOrHideExitBlock
    call EnableAutoTextBoxDrawing
    mov esi, LoreleisRoomTrainerHeaders
    mov edi, LoreleisRoom_ScriptPointers   ; pret: ld de, LoreleisRoom_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wLoreleisRoomCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wLoreleisRoomCurScript], al
    ret

LoreleiShowOrHideExitBlock:
    mov esi, wCurrentMapScriptFlags
    test byte [ebp + esi], (1 << (BIT_CUR_MAP_LOADED_1))
    pushfd    ; SM83 form writes no flags
        and byte [ebp + esi], ~(1 << (BIT_CUR_MAP_LOADED_1)) & 0xFF
    popfd
    jnz .nr_16
        ret
.nr_16:
    mov esi, W_ELITE4_FLAGS
    or byte [ebp + esi], (1 << (1))
    CheckEvent EVENT_BEAT_LORELEIS_ROOM_TRAINER_0
    jz .blockExitToNextRoom
    mov al, 0x5
    jmp .setExitBlock

.blockExitToNextRoom:
    mov al, 0x24
.setExitBlock:
    mov [ebp + wNewTileBlockID], al
    mov bx, ((0) << 8) | (2)
; DEVIATION{class=banking; pret=macros/predef.asm:predef_jump; behavior=Predef dispatch replaced by a direct jmp, and the predef id is not left in A because no reader is live; evidence=PredefPointers is unported and the flat model needs no bank switch, dataflow shows A dead after this site; lifetime=retired when PredefPointers is ported}
    jmp ReplaceTileBlock

ResetLoreleiScript:
    xor al, al
    mov [ebp + wLoreleisRoomCurScript], al
    ret

LoreleisRoom_ScriptPointers:
    dd LoreleisRoomDefaultScript
    dd DisplayEnemyTrainerTextAndStartBattle
    dd LoreleisRoomLoreleiEndBattleScript
    dd LoreleisRoomPlayerIsMovingScript
    dd LoreleisRoomNoopScript

LoreleisRoomNoopScript:
    ret

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

LoreleiEntranceCoords:
    db 10, 4
    db 10, 5
    db 11, 4
    db 11, 5
    db -1

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

LoreleisRoomLoreleiEndBattleScript:
    call EndTrainerBattle
    mov al, [ebp + wIsInBattle]
    cmp al, 0xff
    jz ResetLoreleiScript
    mov al, TEXT_LORELEISROOM_LORELEI
    mov [ebp + hTextID], al
    jmp DisplayTextID

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] LoreleisRoom_TextPointers (scripts/LoreleisRoom.asm:120-128) — a generated asset already defines LoreleisRoomTrainerHeaders
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	def_text_pointers
; PRET| 	dw_const LoreleisRoomLoreleiText,            TEXT_LORELEISROOM_LORELEI
; PRET| 	dw_const LoreleisRoomLoreleiDontRunAwayText, TEXT_LORELEISROOM_DONT_RUN_AWAY
; PRET| 
; PRET| LoreleisRoomTrainerHeaders:
; PRET| 	def_trainers
; PRET| LoreleisRoomTrainerHeader0:
; PRET| 	trainer EVENT_BEAT_LORELEIS_ROOM_TRAINER_0, 0, LoreleisRoomLoreleiBeforeBattleText, LoreleisRoomLoreleiEndBattleText, LoreleisRoomLoreleiAfterBattleText
; PRET| 	db -1 ; end

LoreleisRoomLoreleiText:
    mov esi, LoreleisRoomTrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] LoreleisRoomLoreleiBeforeBattleText (scripts/LoreleisRoom.asm:137-150) — a generated asset already defines LoreleisRoomLoreleiBeforeBattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _LoreleisRoomLoreleiBeforeBattleText
; PRET| 	text_end
; PRET| 
; PRET| LoreleisRoomLoreleiEndBattleText:
; PRET| 	text_far _LoreleisRoomLoreleiEndBattleText
; PRET| 	text_end
; PRET| 
; PRET| LoreleisRoomLoreleiAfterBattleText:
; PRET| 	text_far _LoreleisRoomLoreleiAfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| LoreleisRoomLoreleiDontRunAwayText:
; PRET| 	text_far _LoreleisRoomLoreleiDontRunAwayText
; PRET| 	text_end
