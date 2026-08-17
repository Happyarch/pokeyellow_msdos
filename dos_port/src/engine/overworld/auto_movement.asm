; auto_movement.asm — scripted "guide NPC walks you there" movement scripts:
; the Pallet Town Prof. Oak walk-to-lab cutscene and the Pewter museum/gym guides.
;
; Intended repo path: dos_port/src/engine/overworld/auto_movement.asm
; pret source: engine/overworld/auto_movement.asm
;
; Each per-map movement-script pointer table is a list of function pointers
; dispatched by RunNPCMovementScript (overworld.asm) → CallFunctionInTable
; (run_map_script.asm), indexed by wNPCMovementScriptFunctionNum. The scripts
; advance a small state machine, decoding canned RLE movement streams into the
; simulated-joypad queue (player) and wNPCMovementDirections2 (the NPC).
;
; Register map (SM83 -> x86): A->AL, HL->ESI, B->BH, C->BL. RAM is EBP-relative.
; pret's embedded `dw <label>` pointer tables become `dd` (flat host pointers),
; matching CallFunctionInTable's [esi+ecx*4] and RunNPCMovementScript's *4 index.
; MoveSprite and the SetSpriteMovementBytes*/GetSpriteMovementByte*Pointer family
; take the sprite selector as a RAW slot in hSpriteIndex, exactly as pret. Only
; the per-frame stepper keeps a pre-swapped offset, in
; wNPCMovementScriptSpriteOffset / hCurrentSpriteOffset (= slot<<4).
;
; LINKED (GAME_SRCS, since OW-7.2). The per-map movement-script pointer tables here
; are dispatched by RunNPCMovementScript, but the machinery stays inert until a map
; script sets wNPCMovementScriptPointerTableNum nonzero (OW-2.5 Oak cutscene wires
; the first one) — HideObject is likewise an unported predef (extern).
;
; pret's PlayerStepOutFromDoor is the first routine in this file and lives here.
;
; Build (check): nasm -f coff -I include/ -I . -o auto_movement.o \
;                     src/engine/overworld/auto_movement.asm
; ---------------------------------------------------------------------------

%include "gb_memmap.inc"
%include "gb_macros.inc"
%include "gb_constants.inc"
%include "assets/audio_constants.inc"

global PlayerStepOutFromDoor
global _EndNPCMovementScript
global PalletMovementScriptPointerTable
global PewterMuseumGuyMovementScriptPointerTable
global PewterGymGuyMovementScriptPointerTable

extern EndNPCMovementScript         ; src/home/npc_movement.asm
extern FillMemory                  ; home/copy2.asm
extern MoveSprite                  ; src/home/pathfinding.asm
extern ConvertNPCMovementDirectionsToJoypadMasks ; pathfinding.asm (pret: predef)
extern DecodeRLEList               ; src/home/map_objects.asm
extern StartSimulatingJoypadStates ; src/home/map_objects.asm
extern PlayMusic                   ; src/home/audio.asm (real gateway)
extern PewterGuys                  ; src/engine/events/pewter_guys.asm
extern HideObject                  ; src/engine/overworld/toggleable_objects.asm (OW-3.2)
extern IsPlayerStandingOnDoorTile  ; src/engine/overworld/doors.asm

section .text

; ---------------------------------------------------------------------------
; PlayerStepOutFromDoor — force one auto-step south off a warp-arrival tile.
; Called by RunNPCMovementScript when BIT_STANDING_ON_DOOR is detected.
; Calls IsPlayerStandingOnDoorTile first: if not a door tile (stair/ladder),
; clears the flags with no auto-walk. If on a door tile, sets BIT_EXITING_DOOR
; (marks auto-walk in progress) and BIT_SCRIPTED_MOVEMENT_STATE (injects PAD_DOWN
; into the idle-path direction logic; .handleDirection bypasses the turn-delay and
; fires the collision-exit warp). Pret ref: engine/overworld/auto_movement.asm:PlayerStepOutFromDoor
; ---------------------------------------------------------------------------
PlayerStepOutFromDoor:
    ; pret auto_movement.asm:PlayerStepOutFromDoor entry — clear BIT_UNKNOWN_5_1 in
    ; wStatusFlags5 unconditionally (both door and non-door paths run through here).
    and byte [ebp + wStatusFlags5], ~(1 << BIT_UNKNOWN_5_1)
    call IsPlayerStandingOnDoorTile
    jnc .notStandingOnDoor
    ; Door tile — set up one forced south step to walk off the arrival warp tile.
    mov byte [ebp + wJoyIgnore], PAD_SELECT | PAD_START | PAD_CTRL_PAD
    or byte [ebp + wMovementFlags], (1 << BIT_EXITING_DOOR)
    mov byte [ebp + wSimulatedJoypadStatesIndex], 1
    mov byte [ebp + wSimulatedJoypadStatesEnd], PAD_DOWN
    xor al, al
    mov [ebp + wSpritePlayerStateData1ImageIndex], al       ; pret: wSpritePlayerStateData1ImageIndex = 0
    ; StartSimulatingJoypadStates zeroes the override mask + slot-0 movement byte 1 and
    ; sets BIT_SCRIPTED_MOVEMENT_STATE so AreInputsSimulated feeds this one PAD_DOWN.
    ; wJoyIgnore now matches pret and is cleared by AreInputsSimulated.doneSimulating
    ; after the one-step queue drains, sharing the same ownership model as the
    ; multi-step Pallet/Pewter scripted-input machinery.
    call StartSimulatingJoypadStates
    ret
.notStandingOnDoor:
    ; Stair/ladder arrival — no auto-walk. Clear standing and exiting flags.
    ; pret: engine/overworld/auto_movement.asm:PlayerStepOutFromDoor:.notStandingOnDoor
    ; Zero the simulated-joypad fields first: otherwise a stale index/queued PAD_* byte
    ; leaks into AreInputsSimulated and would replay a phantom step on the next frame.
    xor al, al
    mov byte [ebp + wUnusedOverrideSimulatedJoypadStatesIndex], al
    mov byte [ebp + wSimulatedJoypadStatesIndex], al
    mov byte [ebp + wSimulatedJoypadStatesEnd],   al
    and byte [ebp + wMovementFlags], ~((1 << BIT_STANDING_ON_DOOR) | (1 << BIT_EXITING_DOOR))
    and byte [ebp + wStatusFlags5], ~(1 << BIT_SCRIPTED_MOVEMENT_STATE)
    ret

; ---------------------------------------------------------------------------
; _EndNPCMovementScript — tear down all scripted-movement state.
; pret: engine/overworld/auto_movement.asm:_EndNPCMovementScript
; ---------------------------------------------------------------------------
_EndNPCMovementScript:
    and byte [ebp + wStatusFlags5], (~(1 << BIT_SCRIPTED_MOVEMENT_STATE)) & 0xFF
    and byte [ebp + wStatusFlags4], (~(1 << BIT_INIT_SCRIPTED_MOVEMENT)) & 0xFF
    and byte [ebp + wMovementFlags], (~((1 << BIT_STANDING_ON_DOOR) | (1 << BIT_EXITING_DOOR))) & 0xFF
    xor al, al
    mov [ebp + wNPCMovementScriptSpriteOffset], al
    mov [ebp + wNPCMovementScriptFunctionNum], al
    mov [ebp + wNPCMovementScriptPointerTableNum], al
    mov [ebp + wUnusedOverrideSimulatedJoypadStatesIndex], al
    mov [ebp + wSimulatedJoypadStatesIndex], al
    mov [ebp + wSimulatedJoypadStatesEnd], al
    ret

; ===========================================================================
; Pallet Town — Prof. Oak walks the player to his lab.
; ===========================================================================
PalletMovementScript_OakMoveLeft:
    mov al, [ebp + wXCoord]
    sub al, 0x0a
    mov [ebp + wNumStepsToTake], al            ; ld doesn't disturb ZF from sub
    jz .playerOnLeftTile
; Player on the right tile; Oak (below) steps left (xcoord-10) times.
    movzx ebx, al                              ; bc = step count (b=0, c=a)
    mov esi, wNPCMovementDirections2
    mov al, NPC_MOVEMENT_LEFT
    call FillMemory                            ; fill LEFT × BX at [ESI] (ESI/EBX preserved)
    add esi, ebx                               ; hl -> end of filled region
    mov byte [ebp + esi], 0xff                 ; ld [hl],$ff
    mov al, [ebp + wSpriteIndex]
    mov [ebp + hSpriteIndex], al               ; ldh [hSpriteIndex], a — raw slot, as pret
    lea edi, [ebp + wNPCMovementDirections2]   ; de = movement stream (flat = ebp + WRAM offset)
    call MoveSprite
    mov byte [ebp + wNPCMovementScriptFunctionNum], 1
    jmp .setMusic
; Player on the left tile; Oak is already positioned.
.playerOnLeftTile:
    mov byte [ebp + wNPCMovementScriptFunctionNum], 3
.setMusic:
    mov bl, MUSIC_MUSEUM_GUY_BANK              ; c = audio ROM bank
    mov al, MUSIC_MUSEUM_GUY
    call PlayMusic
    or byte [ebp + wStatusFlags7], (1 << BIT_NO_MAP_MUSIC)
    mov byte [ebp + wJoyIgnore], PAD_SELECT | PAD_START | PAD_CTRL_PAD
    ret

PalletMovementScript_PlayerMoveLeft:
    test byte [ebp + wStatusFlags5], (1 << BIT_SCRIPTED_NPC_MOVEMENT)
    jnz .ret                                   ; return if Oak is still moving
    mov al, [ebp + wNumStepsToTake]
    mov [ebp + wSimulatedJoypadStatesIndex], al
    mov [ebp + hNPCMovementDirections2Index], al
    call ConvertNPCMovementDirectionsToJoypadMasks ; pret: predef (banking elided)
    call StartSimulatingJoypadStates
    mov byte [ebp + wNPCMovementScriptFunctionNum], 2
.ret:
    ret

PalletMovementScript_WaitAndWalkToLab:
    cmp byte [ebp + wSimulatedJoypadStatesIndex], 0 ; is the player done moving left?
    jz PalletMovementScript_WalkToLab          ; done -> walk to lab (pret: fall through)
    ret

PalletMovementScript_WalkToLab:
    mov byte [ebp + wOverrideSimulatedJoypadStatesMask], 0
    mov al, [ebp + wSpriteIndex]
    shl al, 4                                  ; swap a
    mov [ebp + wNPCMovementScriptSpriteOffset], al
    mov byte [ebp + wSpriteStateData2 + SPRITESTATEDATA2_MOVEMENTBYTE1], 0 ; wSpritePlayerStateData2MovementByte1
    mov esi, wSimulatedJoypadStatesEnd
    mov edi, RLEList_PlayerWalkToLab
    call DecodeRLEList
    dec al
    mov [ebp + wSimulatedJoypadStatesIndex], al
    mov esi, wNPCMovementDirections2
    mov edi, RLEList_ProfOakWalkToLab
    call DecodeRLEList
    and byte [ebp + wStatusFlags4], (~(1 << BIT_INIT_SCRIPTED_MOVEMENT)) & 0xFF
    or  byte [ebp + wStatusFlags5], (1 << BIT_SCRIPTED_MOVEMENT_STATE)
    mov byte [ebp + wNPCMovementScriptFunctionNum], 4
    ret

PalletMovementScript_Done:
    cmp byte [ebp + wSimulatedJoypadStatesIndex], 0
    jnz .ret
    mov byte [ebp + wToggleableObjectIndex], TOGGLE_PALLET_TOWN_OAK
    call HideObject                            ; pret: predef (banking elided; HideObject unported)
    and byte [ebp + wStatusFlags5], (~(1 << BIT_SCRIPTED_MOVEMENT_STATE)) & 0xFF
    and byte [ebp + wStatusFlags4], (~(1 << BIT_INIT_SCRIPTED_MOVEMENT)) & 0xFF
    jmp EndNPCMovementScript
.ret:
    ret

; ===========================================================================
; Pewter City — the museum guy / gym guy guides.
; ===========================================================================
PewterMovementScript_WalkToMuseum:
    mov bl, MUSIC_MUSEUM_GUY_BANK
    mov al, MUSIC_MUSEUM_GUY
    call PlayMusic
    mov al, [ebp + wSpriteIndex]
    shl al, 4                                  ; swap a
    mov [ebp + wNPCMovementScriptSpriteOffset], al
    call StartSimulatingJoypadStates
    mov esi, wSimulatedJoypadStatesEnd
    mov edi, RLEList_PewterMuseumPlayer
    call DecodeRLEList
    dec al
    mov [ebp + wSimulatedJoypadStatesIndex], al
    mov byte [ebp + wWhichPewterGuy], 0
    call PewterGuys
    mov esi, wNPCMovementDirections2
    mov edi, RLEList_PewterMuseumGuy
    call DecodeRLEList
    and byte [ebp + wStatusFlags4], (~(1 << BIT_INIT_SCRIPTED_MOVEMENT)) & 0xFF
    mov byte [ebp + wNPCMovementScriptFunctionNum], 1
    ret

PewterMovementScript_Done:
    cmp byte [ebp + wSimulatedJoypadStatesIndex], 0
    jnz .ret
    and byte [ebp + wStatusFlags5], (~(1 << BIT_SCRIPTED_MOVEMENT_STATE)) & 0xFF
    and byte [ebp + wStatusFlags4], (~(1 << BIT_INIT_SCRIPTED_MOVEMENT)) & 0xFF
    jmp EndNPCMovementScript
.ret:
    ret

PewterMovementScript_WalkToGym:
    mov bl, MUSIC_MUSEUM_GUY_BANK
    mov al, MUSIC_MUSEUM_GUY
    call PlayMusic
    mov al, [ebp + wSpriteIndex]
    shl al, 4                                  ; swap a
    mov [ebp + wNPCMovementScriptSpriteOffset], al
    mov byte [ebp + wSpriteStateData2 + SPRITESTATEDATA2_MOVEMENTBYTE1], 0 ; wSpritePlayerStateData2MovementByte1
    mov esi, wSimulatedJoypadStatesEnd
    mov edi, RLEList_PewterGymPlayer
    call DecodeRLEList
    dec al
    mov [ebp + wSimulatedJoypadStatesIndex], al
    mov byte [ebp + wWhichPewterGuy], 1
    call PewterGuys
    mov esi, wNPCMovementDirections2
    mov edi, RLEList_PewterGymGuy
    call DecodeRLEList
    and byte [ebp + wStatusFlags4], (~(1 << BIT_INIT_SCRIPTED_MOVEMENT)) & 0xFF
    or  byte [ebp + wStatusFlags5], (1 << BIT_SCRIPTED_MOVEMENT_STATE)
    mov byte [ebp + wNPCMovementScriptFunctionNum], 1
    ret

section .rodata

; pret `dw <label>` pointer tables flat-adapted to `dd`.
PalletMovementScriptPointerTable:
    dd PalletMovementScript_OakMoveLeft
    dd PalletMovementScript_PlayerMoveLeft
    dd PalletMovementScript_WaitAndWalkToLab
    dd PalletMovementScript_WalkToLab
    dd PalletMovementScript_Done

PewterMuseumGuyMovementScriptPointerTable:
    dd PewterMovementScript_WalkToMuseum
    dd PewterMovementScript_Done

PewterGymGuyMovementScriptPointerTable:
    dd PewterMovementScript_WalkToGym
    dd PewterMovementScript_Done

; RLE movement streams: <byte value>, <run length>, ... , -1 ($ff) terminator.
RLEList_ProfOakWalkToLab:
    db NPC_MOVEMENT_DOWN, 6                     ; differs from red
    db NPC_MOVEMENT_LEFT, 1
    db NPC_MOVEMENT_DOWN, 5
    db NPC_MOVEMENT_RIGHT, 3
    db NPC_MOVEMENT_UP, 1
    db NPC_CHANGE_FACING, 1
    db 0xff

RLEList_PlayerWalkToLab:
    db PAD_UP, 2
    db PAD_RIGHT, 3
    db PAD_DOWN, 5
    db PAD_LEFT, 1
    db PAD_DOWN, 7                              ; differs from red
    db 0xff

RLEList_PewterMuseumPlayer:
    db NO_INPUT, 1
    db PAD_UP, 3
    db PAD_LEFT, 13
    db PAD_UP, 6
    db 0xff

RLEList_PewterMuseumGuy:
    db NPC_MOVEMENT_UP, 6
    db NPC_MOVEMENT_LEFT, 13
    db NPC_MOVEMENT_UP, 3
    db NPC_MOVEMENT_LEFT, 1
    db 0xff

RLEList_PewterGymPlayer:
    db NO_INPUT, 1
    db PAD_RIGHT, 2
    db PAD_DOWN, 5
    db PAD_LEFT, 11
    db PAD_UP, 5
    db PAD_LEFT, 15
    db 0xff

RLEList_PewterGymGuy:
    db NPC_MOVEMENT_DOWN, 2
    db NPC_MOVEMENT_LEFT, 15
    db NPC_MOVEMENT_UP, 5
    db NPC_MOVEMENT_LEFT, 11
    db NPC_MOVEMENT_DOWN, 5
    db NPC_MOVEMENT_RIGHT, 3
    db 0xff
