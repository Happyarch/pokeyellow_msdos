; pathfinding.asm — scripted-NPC movement primitives (home-rectify M3.3).
;
; Intended repo path: dos_port/src/engine/overworld/pathfinding.asm
;
; Translated from pret/pokeyellow:
;   home/pathfinding.asm : CalcDifference, MoveSprite, MoveSprite_, DivideBytes
;   home/map_objects.asm : SetSpriteMovementBytesToFF,
;                          GetSpriteMovementByte1Pointer, GetSpriteMovementByte2Pointer
;
; MoveSprite loads a $ff-terminated movement-direction stream into
; wNPCMovementDirections and arms BIT_SCRIPTED_NPC_MOVEMENT so the per-frame sprite
; updater (_UpdateSprites, M6.2) can step the NPC through it. CalcDifference /
; DivideBytes are the coord-delta helpers the higher-level path chooser uses.
;
; Register map (SM83 -> x86): A->AL, HL->ESI, B->BH, C->BL (see CLAUDE.md).
; RAM is EBP-relative; the movement-data source is a FLAT 32-bit host pointer (EDI).
;
; Sprite selector: the port addresses a sprite slot by its byte offset (slot*0x10)
; held in hCurrentSpriteOffset (H_CURRENT_SPRITE_OFFSET) — the analog of pret's
; `hSpriteIndex` after `swap a`. Callers set it before MoveSprite, matching the
; _UpdateSprites loop convention (see movement.asm).
;
; Build (check): nasm -f coff -I include/ -I . -o pathfinding.o \
;                     src/engine/overworld/pathfinding.asm
; ---------------------------------------------------------------------------

%include "gb_memmap.inc"
%include "gb_macros.inc"

global CalcDifference
global MoveSprite
global MoveSprite_
global DivideBytes
global SetSpriteMovementBytesToFF
global GetSpriteMovementByte1Pointer
global GetSpriteMovementByte2Pointer
; engine section (OW-2.2) — pret engine/overworld/pathfinding.asm
global FindPathToPlayer
global CalcPositionOfPlayerRelativeToNPC
global ConvertNPCMovementDirectionsToJoypadMasks
global ConvertNPCMovementDirectionToJoypadMask

extern wMapSpriteData            ; map_sprites.asm — [movbyte2, textid] per slot (pret wMapSpriteData)

section .text

; ---------------------------------------------------------------------------
; CalcDifference — AL = |AL - BH|, setting CF if the original AL < BH.
; pret: home/pathfinding.asm:CalcDifference (a<b -> cpl+1, scf)
; In:  AL = a, BH = b   Out: AL = |a-b|, CF = (a < b)
; Clobbers: AL, flags
; ---------------------------------------------------------------------------
CalcDifference:
    sub al, bh
    jc .negate                                ; borrow -> a < b
    ret                                       ; a >= b: AL = a-b, CF=0
.negate:
    neg al                                    ; two's complement -> |a-b| (pret: cpl / add 1)
    stc                                       ; a < b
    ret

; ---------------------------------------------------------------------------
; MoveSprite — move sprite [hCurrentSpriteOffset] with the movement stream at EDI.
; Copies the (RLE-free) $ff-terminated direction bytes to wNPCMovementDirections and
; arms scripted-NPC movement. Entry MoveSprite first resets the sprite's movement
; bytes; MoveSprite_ skips that (caller already did it).
;
; pret: home/pathfinding.asm:MoveSprite / MoveSprite_
; In:  EDI = flat pointer to $ff-terminated movement-direction bytes
;      H_CURRENT_SPRITE_OFFSET = sprite slot*0x10
; Out: wNPCMovementDirections filled; wNPCNumScriptedSteps = step count;
;      BIT_SCRIPTED_NPC_MOVEMENT set; sim-joypad override state reset.
; Clobbers: AL, ECX, ESI, EDI, flags
; ---------------------------------------------------------------------------
MoveSprite:
    call SetSpriteMovementBytesToFF
MoveSprite_:
    call GetSpriteMovementByte1Pointer        ; ESI = EBP-rel offset of movement byte 1
    mov byte [ebp + esi], 0                   ; clear movement byte 1
    mov esi, W_NPC_MOVEMENT_DIRECTIONS        ; ESI = GB offset of the output list
    xor ecx, ecx                              ; c = 0 (step counter)
.loop:
    mov al, [edi]
    mov [ebp + esi], al
    inc edi
    inc esi
    inc cl
    cmp al, 0xFF                              ; reached end of movement data?
    jne .loop

    mov [ebp + W_NPC_NUM_SCRIPTED_STEPS], cl  ; number of steps taken
    or byte [ebp + W_STATUS_FLAGS_5], (1 << BIT_SCRIPTED_NPC_MOVEMENT)
    ; reset simulated-joypad override bookkeeping (pret tail of MoveSprite_)
    mov byte [ebp + W_OVERRIDE_SIMULATED_JOYPAD_STATES_MASK], 0
    mov byte [ebp + W_SIMULATED_JOYPAD_STATES_END], 0
    mov byte [ebp + W_JOY_IGNORE], 0xFF                          ; pret: dec a (0 -> $ff)
    mov byte [ebp + W_UNUSED_OVERRIDE_SIMULATED_JOYPAD_STATES_INDEX], 0xFF
    ret

; ---------------------------------------------------------------------------
; DivideBytes — [hQuotient2] = [hDividend2] / [hDivisor2] (repeated subtraction).
; pret: home/pathfinding.asm:DivideBytes
; Clobbers: AL, flags (hl preserved as in pret)
; ---------------------------------------------------------------------------
DivideBytes:
    mov byte [ebp + H_QUOTIENT2], 0
    cmp byte [ebp + H_DIVISOR2], 0
    je .done                                  ; divisor 0 -> quotient stays 0
    mov al, [ebp + H_DIVIDEND2]
.loop:
    sub al, [ebp + H_DIVISOR2]
    jc .done
    inc byte [ebp + H_QUOTIENT2]
    jmp .loop
.done:
    ret

; ---------------------------------------------------------------------------
; SetSpriteMovementBytesToFF — movement byte 1 = STAY ($ff), byte 2 = NONE ($00),
; for sprite [hCurrentSpriteOffset].
; pret: home/map_objects.asm:SetSpriteMovementBytesToFF
; Clobbers: ESI, flags
; ---------------------------------------------------------------------------
SetSpriteMovementBytesToFF:
    call GetSpriteMovementByte1Pointer
    mov byte [ebp + esi], 0xFF                ; STAY
    call GetSpriteMovementByte2Pointer
    mov byte [esi], 0x00                      ; NONE (ESI = flat wMapSpriteData ptr, not EBP-relative)
    ret

; ---------------------------------------------------------------------------
; GetSpriteMovementByte1Pointer — ESI = EBP-rel offset of sprite [hCurrentSpriteOffset]
; movement byte 1 (wSpriteStateData2 + slot*0x10 + 6).
; pret: home/map_objects.asm:GetSpriteMovementByte1Pointer (swap a / add 6)
; Out: ESI = offset   Clobbers: ESI
; ---------------------------------------------------------------------------
GetSpriteMovementByte1Pointer:
    movzx esi, byte [ebp + H_CURRENT_SPRITE_OFFSET]
    add esi, W_SPRITE_STATE_DATA_2 + SPRITESTATEDATA2_MOVEMENTBYTE1
    ret

; ---------------------------------------------------------------------------
; GetSpriteMovementByte2Pointer — ESI = EBP-rel offset of the sprite's movement
; byte 2 (direction constraint).
; pret: home/map_objects.asm:GetSpriteMovementByte2Pointer.
;
; pret stores byte 2 in wMapSpriteData[(slot-1)*2]; OW-A.2 P2 relocated the port's copy
; there too (it had been stashed in SPRITESTATEDATA2 offset 0x1). Since wMapSpriteData is
; a flat .bss array, this returns ESI = flat address (NOT an EBP-relative offset like
; GetSpriteMovementByte1Pointer); callers write [esi], not [ebp+esi].
; Out: ESI = flat wMapSpriteData ptr   Clobbers: ESI, flags
; ---------------------------------------------------------------------------
GetSpriteMovementByte2Pointer:
    movzx esi, byte [ebp + H_CURRENT_SPRITE_OFFSET]  ; slot byte offset (slot*0x10)
    shr esi, 4                                        ; slot number (1-15)
    dec esi
    add esi, esi                                      ; (slot-1)*2 -> wMapSpriteData index
    add esi, wMapSpriteData                           ; flat address; flags dead (ret follows)
    ret

; ===========================================================================
; Engine section (OW-2.2) — pret engine/overworld/pathfinding.asm.
; Higher-level path chooser + relative-position calc + the direction→joypad
; conversion used to drive a scripted NPC toward the player (npc_movement_2 /
; trainer AI). Check-only until npc_movement_2 lands; hNPCSpriteOffset and the
; hFindPath* HRAM cells are set by those (not-yet-ported) callers.
; ===========================================================================

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
    mov [ebp + H_FIND_PATH_NUM_STEPS], al
    mov [ebp + H_FIND_PATH_FLAGS], al
    mov [ebp + H_FIND_PATH_Y_PROGRESS], al
    mov [ebp + H_FIND_PATH_X_PROGRESS], al
    mov esi, wNPCMovementDirections2          ; hl = output list (GB offset)
    xor edx, edx                              ; de = 0 (d=Y diff, e=X diff scratch)
.loop:
    mov al, [ebp + H_FIND_PATH_Y_PROGRESS]
    mov bh, al
    mov al, [ebp + H_NPC_PLAYER_Y_DISTANCE]
    call CalcDifference                        ; al = |Yprogress - Ydist|
    mov dh, al                                 ; d = remaining Y distance
    test al, al
    jnz .stillHasYProgress
    or byte [ebp + H_FIND_PATH_FLAGS], (1 << BIT_PATH_FOUND_Y)
.stillHasYProgress:
    mov al, [ebp + H_FIND_PATH_X_PROGRESS]
    mov bh, al
    mov al, [ebp + H_NPC_PLAYER_X_DISTANCE]
    call CalcDifference                        ; al = |Xprogress - Xdist|
    mov dl, al                                 ; e = remaining X distance
    test al, al
    jnz .stillHasXProgress
    or byte [ebp + H_FIND_PATH_FLAGS], (1 << BIT_PATH_FOUND_X)
.stillHasXProgress:
    mov al, [ebp + H_FIND_PATH_FLAGS]
    cmp al, (1 << BIT_PATH_FOUND_X) | (1 << BIT_PATH_FOUND_Y)
    je .done
; Reduce whichever distance is greater. e < d -> Y is greater.
    mov al, dl                                 ; a = e (X remaining)
    cmp al, dh                                 ; cp d (Y remaining)
    jc .yDistanceGreater
; X distance greater
    test byte [ebp + H_NPC_PLAYER_RELATIVE_POS_FLAGS], (1 << BIT_PLAYER_LOWER_X)
    jnz .playerIsLeftOfNPC
    mov dh, NPC_MOVEMENT_RIGHT
    jmp .next1
.playerIsLeftOfNPC:
    mov dh, NPC_MOVEMENT_LEFT
.next1:
    mov al, [ebp + H_FIND_PATH_X_PROGRESS]
    add al, 1
    mov [ebp + H_FIND_PATH_X_PROGRESS], al
    jmp .storeDirection
.yDistanceGreater:
    test byte [ebp + H_NPC_PLAYER_RELATIVE_POS_FLAGS], (1 << BIT_PLAYER_LOWER_Y)
    jnz .playerIsAboveNPC
    mov dh, NPC_MOVEMENT_DOWN
    jmp .next2
.playerIsAboveNPC:
    mov dh, NPC_MOVEMENT_UP
.next2:
    mov al, [ebp + H_FIND_PATH_Y_PROGRESS]
    add al, 1
    mov [ebp + H_FIND_PATH_Y_PROGRESS], al
.storeDirection:
    mov al, dh                                 ; a = d (chosen direction)
    mov [ebp + esi], al
    inc esi
    mov al, [ebp + H_FIND_PATH_NUM_STEPS]
    inc al
    mov [ebp + H_FIND_PATH_NUM_STEPS], al
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
    mov byte [ebp + H_NPC_PLAYER_RELATIVE_POS_FLAGS], 0
    mov dh, [ebp + W_SPRITE_PLAYER_Y_PIXELS]   ; d = player Y pixels
    mov dl, [ebp + W_SPRITE_PLAYER_X_PIXELS]   ; e = player X pixels
    movzx esi, byte [ebp + H_NPC_SPRITE_OFFSET]
    add esi, W_SPRITE_STATE_DATA_1 + SPRITESTATEDATA1_YPIXELS  ; hl -> NPC YPIXELS
; --- Y axis ---
    mov bh, dh                                 ; b = player Y
    mov al, [ebp + esi]                        ; a = NPC screen Y
    call CalcDifference                        ; |NPC-player|, CF set = NPC north of player
    jc .NPCNorthOfPlayer
    and byte [ebp + H_NPC_PLAYER_RELATIVE_POS_FLAGS], (~(1 << BIT_PLAYER_LOWER_Y)) & 0xFF
    jmp .divideYDistance
.NPCNorthOfPlayer:
    or byte [ebp + H_NPC_PLAYER_RELATIVE_POS_FLAGS], (1 << BIT_PLAYER_LOWER_Y)
.divideYDistance:
    mov [ebp + H_DIVIDEND2], al
    mov byte [ebp + H_DIVISOR2], 16
    call DivideBytes                           ; |dY| / 16
    mov al, [ebp + H_QUOTIENT2]
    mov [ebp + H_NPC_PLAYER_Y_DISTANCE], al
; --- X axis (pret: inc hl to reach XPIXELS = YPIXELS+2) ---
    mov bh, dl                                 ; b = player X
    mov al, [ebp + esi + (SPRITESTATEDATA1_XPIXELS - SPRITESTATEDATA1_YPIXELS)] ; NPC screen X
    call CalcDifference                        ; CF set = NPC west of player
    jc .NPCWestOfPlayer
    and byte [ebp + H_NPC_PLAYER_RELATIVE_POS_FLAGS], (~(1 << BIT_PLAYER_LOWER_X)) & 0xFF
    jmp .divideXDistance
.NPCWestOfPlayer:
    or byte [ebp + H_NPC_PLAYER_RELATIVE_POS_FLAGS], (1 << BIT_PLAYER_LOWER_X)
.divideXDistance:
    mov [ebp + H_DIVIDEND2], al
    mov byte [ebp + H_DIVISOR2], 16
    call DivideBytes                           ; |dX| / 16
    mov al, [ebp + H_QUOTIENT2]
    mov [ebp + H_NPC_PLAYER_X_DISTANCE], al
    mov al, [ebp + H_NPC_PLAYER_RELATIVE_POS_PERSPECTIVE]
    test al, al
    jz .retDone                                ; perspective 0 (player->NPC): keep flags
    mov al, [ebp + H_NPC_PLAYER_RELATIVE_POS_FLAGS]  ; perspective 1 (NPC->player): invert
    not al                                     ; cpl
    and al, 0x3
    mov [ebp + H_NPC_PLAYER_RELATIVE_POS_FLAGS], al
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
    mov al, [ebp + H_NPC_MOVEMENT_DIRECTIONS2_INDEX]
    mov [ebp + wNPCMovementDirections2Index], al
    movzx esi, al
    dec esi                                    ; index - 1
    add esi, wNPCMovementDirections2           ; hl = &wNPCMovementDirections2[index-1]
    mov edi, W_SIMULATED_JOYPAD_STATES_END     ; de = output offset
.loop:
    mov al, [ebp + esi]                        ; ld a, [hld]
    dec esi
    call ConvertNPCMovementDirectionToJoypadMask
    mov [ebp + edi], al                        ; ld [de], a
    inc edi
    mov al, [ebp + H_NPC_MOVEMENT_DIRECTIONS2_INDEX]
    dec al
    mov [ebp + H_NPC_MOVEMENT_DIRECTIONS2_INDEX], al
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
