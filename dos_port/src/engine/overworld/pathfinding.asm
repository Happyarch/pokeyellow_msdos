; dos_port/src/engine/overworld/pathfinding.asm
; ============================================================
; Mirror of pret engine/overworld/pathfinding.asm. Holds every label of that
; file, in pret order: FindPathToPlayer, CalcPositionOfPlayerRelativeToNPC,
; ConvertNPCMovementDirectionsToJoypadMasks,
; ConvertNPCMovementDirectionToJoypadMask, and the
; NPCMovementDirectionsToJoypadMasksTable data. Nothing of that pret file is
; left elsewhere.
;
; They arrived from src/home/pathfinding.asm, which is the mirror of the
; SEPARATE pret home/pathfinding.asm (CalcDifference, MoveSprite, MoveSprite_,
; DivideBytes) and had been carrying both files under one name. The two
; coord-delta helpers this file calls, CalcDifference and DivideBytes, stay
; there and are imported.
;
; Higher-level path chooser + relative-position calc + the direction->joypad
; conversion used to drive a scripted NPC toward the player. hNPCSpriteOffset and
; the hFindPath* HRAM cells are set by the callers.
;
; Register map (SM83 -> x86): A->AL, HL->ESI, B->BH, C->BL (see CLAUDE.md).
; RAM is EBP-relative; the direction/joypad table is FLAT program-image data.
;
; Build: nasm -f coff -I include/ -I . -o pathfinding.o \
;             src/engine/overworld/pathfinding.asm

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"

global FindPathToPlayer
global CalcPositionOfPlayerRelativeToNPC
global ConvertNPCMovementDirectionsToJoypadMasks
global ConvertNPCMovementDirectionToJoypadMask

extern CalcDifference                 ; src/home/pathfinding.asm
extern DivideBytes                    ; src/home/pathfinding.asm

section .text

; ---------------------------------------------------------------------------
; FindPathToPlayer — build a movement-direction path from the NPC toward the
; player into wNPCMovementDirections2, terminated by $ff. Greedily reduces
; whichever of the X/Y step-distances is currently larger.
; pret: engine/overworld/pathfinding.asm:FindPathToPlayer
; In:  hNPCPlayerYDistance/XDistance (steps), hNPCPlayerRelativePosFlags
; Out: wNPCMovementDirections2 = NPC_MOVEMENT_* stream + $ff; hFindPathNumSteps
; Clobbers: AL, BH, DX, ESI, flags
; ---------------------------------------------------------------------------
FindPathToPlayer:
    xor al, al
    mov [ebp + hFindPathNumSteps], al
    mov [ebp + hFindPathFlags], al
    mov [ebp + hFindPathYProgress], al
    mov [ebp + hFindPathXProgress], al
    mov esi, wNPCMovementDirections2          ; hl = output list (GB offset)
    xor edx, edx                              ; de = 0 (d=Y diff, e=X diff scratch)
.loop:
    mov al, [ebp + hFindPathYProgress]
    mov bh, al
    mov al, [ebp + hNPCPlayerYDistance]
    call CalcDifference                        ; al = |Yprogress - Ydist|
    mov dh, al                                 ; d = remaining Y distance
    test al, al
    jnz .stillHasYProgress
    or byte [ebp + hFindPathFlags], (1 << BIT_PATH_FOUND_Y)
.stillHasYProgress:
    mov al, [ebp + hFindPathXProgress]
    mov bh, al
    mov al, [ebp + hNPCPlayerXDistance]
    call CalcDifference                        ; al = |Xprogress - Xdist|
    mov dl, al                                 ; e = remaining X distance
    test al, al
    jnz .stillHasXProgress
    or byte [ebp + hFindPathFlags], (1 << BIT_PATH_FOUND_X)
.stillHasXProgress:
    mov al, [ebp + hFindPathFlags]
    cmp al, (1 << BIT_PATH_FOUND_X) | (1 << BIT_PATH_FOUND_Y)
    je .done
; Reduce whichever distance is greater. e < d -> Y is greater.
    mov al, dl                                 ; a = e (X remaining)
    cmp al, dh                                 ; cp d (Y remaining)
    jc .yDistanceGreater
; X distance greater
    test byte [ebp + hNPCPlayerRelativePosFlags], (1 << BIT_PLAYER_LOWER_X)
    jnz .playerIsLeftOfNPC
    mov dh, NPC_MOVEMENT_RIGHT
    jmp .next1
.playerIsLeftOfNPC:
    mov dh, NPC_MOVEMENT_LEFT
.next1:
    mov al, [ebp + hFindPathXProgress]
    add al, 1
    mov [ebp + hFindPathXProgress], al
    jmp .storeDirection
.yDistanceGreater:
    test byte [ebp + hNPCPlayerRelativePosFlags], (1 << BIT_PLAYER_LOWER_Y)
    jnz .playerIsAboveNPC
    mov dh, NPC_MOVEMENT_DOWN
    jmp .next2
.playerIsAboveNPC:
    mov dh, NPC_MOVEMENT_UP
.next2:
    mov al, [ebp + hFindPathYProgress]
    add al, 1
    mov [ebp + hFindPathYProgress], al
.storeDirection:
    mov al, dh                                 ; a = d (chosen direction)
    mov [ebp + esi], al
    inc esi
    mov al, [ebp + hFindPathNumSteps]
    inc al
    mov [ebp + hFindPathNumSteps], al
    jmp .loop
.done:
    mov byte [ebp + esi], 0xff
    ret

; ---------------------------------------------------------------------------
; CalcPositionOfPlayerRelativeToNPC — compute the player's step-distance and
; N/S,E/W relationship to the NPC at hNPCSpriteOffset.
; pret: engine/overworld/pathfinding.asm:CalcPositionOfPlayerRelativeToNPC
; Out: hNPCPlayerYDistance/XDistance (pixels/16), hNPCPlayerRelativePosFlags
;      (BIT_PLAYER_LOWER_Y/X); flags are inverted (& 3) if perspective != 0.
; Clobbers: AL, BH, DX, ESI, flags (DivideBytes/CalcDifference leave ESI intact)
; ---------------------------------------------------------------------------
CalcPositionOfPlayerRelativeToNPC:
    mov byte [ebp + hNPCPlayerRelativePosFlags], 0
    mov dh, [ebp + W_SPRITE_PLAYER_Y_PIXELS]   ; d = player Y pixels
    mov dl, [ebp + W_SPRITE_PLAYER_X_PIXELS]   ; e = player X pixels
    movzx esi, byte [ebp + hNPCSpriteOffset]
    add esi, W_SPRITE_STATE_DATA_1 + SPRITESTATEDATA1_YPIXELS  ; hl -> NPC YPIXELS
; --- Y axis ---
    mov bh, dh                                 ; b = player Y
    mov al, [ebp + esi]                        ; a = NPC screen Y
    call CalcDifference                        ; |NPC-player|, CF set = NPC north of player
    jc .NPCNorthOfPlayer
    and byte [ebp + hNPCPlayerRelativePosFlags], (~(1 << BIT_PLAYER_LOWER_Y)) & 0xFF
    jmp .divideYDistance
.NPCNorthOfPlayer:
    or byte [ebp + hNPCPlayerRelativePosFlags], (1 << BIT_PLAYER_LOWER_Y)
.divideYDistance:
    mov [ebp + hDividend2], al
    mov byte [ebp + hDivisor2], 16
    call DivideBytes                           ; |dY| / 16
    mov al, [ebp + hQuotient2]
    mov [ebp + hNPCPlayerYDistance], al
; --- X axis (pret: inc hl to reach XPIXELS = YPIXELS+2) ---
    mov bh, dl                                 ; b = player X
    mov al, [ebp + esi + (SPRITESTATEDATA1_XPIXELS - SPRITESTATEDATA1_YPIXELS)] ; NPC screen X
    call CalcDifference                        ; CF set = NPC west of player
    jc .NPCWestOfPlayer
    and byte [ebp + hNPCPlayerRelativePosFlags], (~(1 << BIT_PLAYER_LOWER_X)) & 0xFF
    jmp .divideXDistance
.NPCWestOfPlayer:
    or byte [ebp + hNPCPlayerRelativePosFlags], (1 << BIT_PLAYER_LOWER_X)
.divideXDistance:
    mov [ebp + hDividend2], al
    mov byte [ebp + hDivisor2], 16
    call DivideBytes                           ; |dX| / 16
    mov al, [ebp + hQuotient2]
    mov [ebp + hNPCPlayerXDistance], al
    mov al, [ebp + hNPCPlayerRelativePosPerspective]
    test al, al
    jz .retDone                                ; perspective 0 (player->NPC): keep flags
    mov al, [ebp + hNPCPlayerRelativePosFlags]  ; perspective 1 (NPC->player): invert
    not al                                     ; cpl
    and al, 0x3
    mov [ebp + hNPCPlayerRelativePosFlags], al
.retDone:
    ret

; ---------------------------------------------------------------------------
; ConvertNPCMovementDirectionsToJoypadMasks — convert the hNPCMovementDirections2Index
; direction bytes at wNPCMovementDirections2 (walked downward) into PAD_* masks
; written upward from wSimulatedJoypadStatesEnd.
; pret: engine/overworld/pathfinding.asm:ConvertNPCMovementDirectionsToJoypadMasks
; In:  hNPCMovementDirections2Index = count; wNPCMovementDirections2 = NPC_MOVEMENT_* list
; Out: wNPCMovementDirections2Index = count; wSimulatedJoypadStatesEnd.. = PAD_* masks
; Clobbers: AL, BH, ECX, ESI, EDI, flags
; ---------------------------------------------------------------------------
ConvertNPCMovementDirectionsToJoypadMasks:
    mov al, [ebp + hNPCMovementDirections2Index]
    mov [ebp + wNPCMovementDirections2Index], al
    movzx esi, al
    dec esi                                    ; index - 1
    add esi, wNPCMovementDirections2           ; hl = &wNPCMovementDirections2[index-1]
    mov edi, wSimulatedJoypadStatesEnd     ; de = output offset
.loop:
    mov al, [ebp + esi]                        ; ld a, [hld]
    dec esi
    call ConvertNPCMovementDirectionToJoypadMask
    mov [ebp + edi], al                        ; ld [de], a
    inc edi
    mov al, [ebp + hNPCMovementDirections2Index]
    dec al
    mov [ebp + hNPCMovementDirections2Index], al
    jnz .loop
    ret

; ---------------------------------------------------------------------------
; ConvertNPCMovementDirectionToJoypadMask — map one NPC_MOVEMENT_* byte (AL) to
; its PAD_* mask via NPCMovementDirectionsToJoypadMasksTable; AL = $ff if no match.
; pret: engine/overworld/pathfinding.asm:ConvertNPCMovementDirectionToJoypadMask
; In:  AL = NPC_MOVEMENT_*   Out: AL = PAD_* mask (or $ff)
; Clobbers: AL, BH, ECX, flags (ESI/EDI preserved for the caller loop)
; ---------------------------------------------------------------------------
ConvertNPCMovementDirectionToJoypadMask:
    mov bh, al                                 ; b = direction to match
    mov ecx, NPCMovementDirectionsToJoypadMasksTable
.cvtLoop:
    mov al, [ecx]                              ; ld a, [hli] (direction entry)
    cmp al, 0xff
    je .cvtDone                                ; end of table -> AL = $ff
    cmp al, bh
    je .loadJoypadMask
    add ecx, 2                                 ; skip mask byte (pret: hli already past dir, inc hl)
    jmp .cvtLoop
.loadJoypadMask:
    mov al, [ecx + 1]                          ; ld a, [hl] (the PAD_* mask)
.cvtDone:
    ret

section .rodata

; pret: engine/overworld/pathfinding.asm:NPCMovementDirectionsToJoypadMasksTable
NPCMovementDirectionsToJoypadMasksTable:
    db NPC_MOVEMENT_UP,    PAD_UP
    db NPC_MOVEMENT_DOWN,  PAD_DOWN
    db NPC_MOVEMENT_LEFT,  PAD_LEFT
    db NPC_MOVEMENT_RIGHT, PAD_RIGHT
    db 0xff
