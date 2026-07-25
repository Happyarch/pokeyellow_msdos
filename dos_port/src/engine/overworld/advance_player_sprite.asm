; advance_player_sprite.asm — pret: engine/overworld/advance_player_sprite.asm
;
; Faithful translations (pret cross-reference maintained):
;   _AdvancePlayerSprite          engine/overworld/advance_player_sprite.asm:1
;   MoveTileBlockMapPointerEast   engine/overworld/advance_player_sprite.asm:198
;   MoveTileBlockMapPointerWest   engine/overworld/advance_player_sprite.asm:209
;   MoveTileBlockMapPointerSouth  engine/overworld/advance_player_sprite.asm:220
;   MoveTileBlockMapPointerNorth  engine/overworld/advance_player_sprite.asm:233
;
; pret's home-bank wrapper AdvancePlayerSprite lives in src/home/overworld.asm
; (OW-A.3 de-folded the engine body back out of it); it calls _AdvancePlayerSprite
; here, matching pret's `callfar`.
;
; Register map (SM83 -> x86): A->AL, B->BL, C->CL, HL->ESI; RAM is EBP-relative
; [ebp + SYM] with SYM from gb_memmap.inc.
;
; Build: nasm -f coff -I include/ -I . -o advance_player_sprite.o \
;             src/engine/overworld/advance_player_sprite.asm
; ---------------------------------------------------------------------------

bits 32

%include "gb_memmap.inc"

global _AdvancePlayerSprite
; MoveTileBlockMapPointer{East,West,South,North} are pret `::` exports but the
; port's only caller is _AdvancePlayerSprite in this same file, so they stay
; file-local (they were file-local in overworld.asm too).

extern CheckMapConnections                ; src/home/overworld.asm
extern LoadCurrentMapView                 ; src/home/overworld.asm
extern RefreshCollisionTileMap            ; src/engine/overworld/overworld.asm

section .text

; ---------------------------------------------------------------------------
; _AdvancePlayerSprite — engine body.
; pret: engine/overworld/advance_player_sprite.asm:_AdvancePlayerSprite.
;
; Runs once per advanced frame of a walk. Decrements wWalkCounter; on the first
; frame (counter == 7) it slides wMapViewVRAMPointer by 2 tiles, advances the
; tile-block-map pointer when a block boundary is crossed, rebuilds the map view,
; and schedules the newly exposed row/column for VBlank redraw. Every frame it
; scrolls the BG by 2 px (hSCX/hSCY) in the direction of motion.
;
; Remaining Phase-2 omissions vs. pret (inside this body): IsSpinning and the
; Pikachu overworld-state flag.
;
; b (SM83) = wSpritePlayerStateData1YStepVector → kept in BL  (+1 / -1 / 0)
; c (SM83) = wSpritePlayerStateData1XStepVector → kept in CL  (+1 / -1 / 0)
; ---------------------------------------------------------------------------
_AdvancePlayerSprite:
    push eax
    push ebx
    push ecx
    push edx

    mov bl, [ebp + W_SPRITE_PLAYER_Y_STEP_VECTOR]    ; BL = b (Y step)
    mov cl, [ebp + W_SPRITE_PLAYER_X_STEP_VECTOR]    ; CL = c (X step)

    dec byte [ebp + W_WALK_COUNTER]
    jnz .afterUpdateMapCoords
    ; end of animation → commit the player's map coordinates
    mov al, [ebp + W_Y_COORD]
    add al, bl
    mov [ebp + W_Y_COORD], al
    mov al, [ebp + W_X_COORD]
    add al, cl
    mov [ebp + W_X_COORD], al
    call CheckMapConnections
    jc .transitionExit                         ; CF=1 → map changed, abort frame
.afterUpdateMapCoords:
    cmp byte [ebp + W_WALK_COUNTER], 7
    jne .scroll                                       ; only the first frame slides the view

    jmp .adjustXCoordWithinBlock

.adjustXCoordWithinBlock:
    mov al, [ebp + W_X_BLOCK_COORD]
    add al, cl
    mov [ebp + W_X_BLOCK_COORD], al
    cmp al, 0x02
    jne .checkForMoveToWestBlock
    ; crossed into the block to the east
    mov byte [ebp + W_X_BLOCK_COORD], 0
    inc byte [ebp + W_X_OFFSET_SINCE_LAST_SPECIAL_WARP]
    call MoveTileBlockMapPointerEast
    jmp .updateMapView
.checkForMoveToWestBlock:
    cmp al, 0xFF
    jne .adjustYCoordWithinBlock
    ; crossed into the block to the west
    mov byte [ebp + W_X_BLOCK_COORD], 1
    dec byte [ebp + W_X_OFFSET_SINCE_LAST_SPECIAL_WARP]
    call MoveTileBlockMapPointerWest
    jmp .updateMapView
.adjustYCoordWithinBlock:
    mov al, [ebp + W_Y_BLOCK_COORD]
    add al, bl
    mov [ebp + W_Y_BLOCK_COORD], al
    cmp al, 0x02
    jne .checkForMoveToNorthBlock
    ; crossed into the block to the south
    mov byte [ebp + W_Y_BLOCK_COORD], 0
    inc byte [ebp + W_Y_OFFSET_SINCE_LAST_SPECIAL_WARP]
    mov al, [ebp + W_CUR_MAP_WIDTH]
    call MoveTileBlockMapPointerSouth
    jmp .updateMapView
.checkForMoveToNorthBlock:
    cmp al, 0xFF
    jne .refreshTileMap                  ; no block crossing → only resync collision grid
    ; crossed into the block to the north
    mov byte [ebp + W_Y_BLOCK_COORD], 1
    dec byte [ebp + W_Y_OFFSET_SINCE_LAST_SPECIAL_WARP]
    mov al, [ebp + W_CUR_MAP_WIDTH]
    call MoveTileBlockMapPointerNorth

.updateMapView:
    call LoadCurrentMapView              ; rebuilds wSurroundingTiles AND refreshes wTileMap
    jmp .scroll
.refreshTileMap:
    ; Non-crossing step: the player's sub-block coords just changed, so re-copy
    ; wTileMap from the (unchanged) wSurroundingTiles with the new sub-block offset.
    ; Without this, NPC collision reads a stale grid and walks into rendered walls.
    call RefreshCollisionTileMap

.scroll:
    ; Sprite-shift loop: slide each NPC's screen position by 2*step pixels to
    ; keep them world-anchored while the BG scrolls under the player.
    ; Pret ref: engine/overworld/advance_player_sprite.asm lines 162-192.
    push esi
    mov bl, [ebp + W_SPRITE_PLAYER_Y_STEP_VECTOR]
    add bl, bl                                          ; BL = 2 * Ystep (+2/-2/0)
    mov cl, [ebp + W_SPRITE_PLAYER_X_STEP_VECTOR]
    add cl, cl                                          ; CL = 2 * Xstep
    mov esi, W_SPRITE_STATE_DATA_1 + 0x10 + SPRITESTATEDATA1_YPIXELS  ; slot 1 YPixels
    mov edx, 15                                         ; 15 NPC/Pikachu slots
.spriteShift:
    mov al, [ebp + esi]
    sub al, bl
    mov [ebp + esi], al                                 ; YPixels -= 2*Ystep
    mov al, [ebp + esi + 2]                             ; XPixels is YPIXELS+2 in data1
    sub al, cl
    mov [ebp + esi + 2], al                             ; XPixels -= 2*Xstep
    add esi, 0x10                                       ; next slot
    dec edx
    jnz .spriteShift
    pop esi
    ; hSCY += 2*Yvec ; hSCX += 2*Xvec
    mov al, [ebp + W_SPRITE_PLAYER_Y_STEP_VECTOR]
    add al, al
    add [ebp + H_SCY], al
    mov al, [ebp + W_SPRITE_PLAYER_X_STEP_VECTOR]
    add al, al
    add [ebp + H_SCX], al

    pop edx
    pop ecx
    pop ebx
    pop eax
    clc                                        ; CF=0 → no transition
    ret

.transitionExit:
    ; CheckMapConnections set CF=1 → propagate up to caller
    pop edx
    pop ecx
    pop ebx
    pop eax
    stc                                        ; CF=1 → transition occurred
    ret

; ---------------------------------------------------------------------------
; MoveTileBlockMapPointer{East,West,South,North} — faithful translations.
; Pret ref: engine/overworld/advance_player_sprite.asm
;
; Move wCurrentTileBlockMapViewPointer (the upper-left corner of the visible
; block-map region) by one block in the given direction. South/North take the
; row stride (wCurMapWidth + 2*MAP_BORDER) in AL on entry.
; All registers except the pointer are preserved.
; ---------------------------------------------------------------------------
MoveTileBlockMapPointerEast:
    push eax
    mov al, [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR]
    add al, 0x01
    mov [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR], al
    jnc .done
    inc byte [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR + 1]
.done:
    pop eax
    ret

MoveTileBlockMapPointerWest:
    push eax
    mov al, [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR]
    sub al, 0x01
    mov [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR], al
    jnc .done
    dec byte [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR + 1]
.done:
    pop eax
    ret

MoveTileBlockMapPointerSouth:            ; AL = wCurMapWidth
    push eax
    push ebx
    add al, MAP_BORDER * 2                ; AL = row stride
    movzx ebx, al
    mov al, [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR]
    add al, bl
    mov [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR], al
    jnc .done
    inc byte [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR + 1]
.done:
    pop ebx
    pop eax
    ret

MoveTileBlockMapPointerNorth:            ; AL = wCurMapWidth
    push eax
    push ebx
    add al, MAP_BORDER * 2                ; AL = row stride
    movzx ebx, al
    mov al, [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR]
    sub al, bl
    mov [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR], al
    jnc .done
    dec byte [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR + 1]
.done:
    pop ebx
    pop eax
    ret
