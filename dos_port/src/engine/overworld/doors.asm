; doors.asm — pret: engine/overworld/doors.asm
;
; Faithful translation (pret cross-reference maintained):
;   IsPlayerStandingOnDoorTile   engine/overworld/doors.asm:2
;
; pret's file ends with INCLUDE "data/tilesets/door_tile_ids.asm"; the port's
; equivalent (DoorTileTable) is the .data table at the end of this file, so the
; routine and its data stay together exactly as pret has them.
;
; Register map (SM83 -> x86): A->AL, B->BL, HL->ESI; RAM is EBP-relative
; [ebp + SYM] with SYM from gb_memmap.inc.
;
; Build: nasm -f coff -I include/ -I . -o doors.o \
;             src/engine/overworld/doors.asm
; ---------------------------------------------------------------------------

bits 32

%include "gb_memmap.inc"

global IsPlayerStandingOnDoorTile

section .text

; ---------------------------------------------------------------------------
; IsPlayerStandingOnDoorTile — check if the player's current tile is a door tile.
; Returns CF=1 if yes, CF=0 otherwise (stair, ladder, or unknown tileset).
; Reads W_CUR_MAP_TILESET, looks up DoorTileTable, then checks W_TILEMAP at
; PLAYER_STANDING_ROW/COL (the tile directly under the player sprite).
; All registers preserved.
; Pret ref: engine/overworld/doors.asm:IsPlayerStandingOnDoorTile
; ---------------------------------------------------------------------------
IsPlayerStandingOnDoorTile:
    push eax
    push esi

    movzx eax, byte [ebp + W_CUR_MAP_TILESET]
    mov esi, DoorTileTable

.search_tileset:
    cmp byte [esi], 0xFF               ; end of table → tileset not listed
    je .not_door
    cmp byte [esi], al                 ; tileset match?
    je .found_tileset
    inc esi                            ; skip tileset byte, then scan past 0-terminated tile list
.skip_tiles:
    cmp byte [esi], 0
    je .skip_done
    inc esi
    jmp .skip_tiles
.skip_done:
    inc esi                            ; skip the 0 terminator
    jmp .search_tileset

.found_tileset:
    inc esi                            ; ESI now points at first tile ID for this tileset
    movzx eax, byte [ebp + W_TILEMAP + PLAYER_STANDING_ROW * SCREEN_TILES_W + PLAYER_STANDING_COL]
.check_tile:
    cmp byte [esi], 0
    je .not_door
    cmp [esi], al
    je .is_door
    inc esi
    jmp .check_tile

.is_door:
    pop esi
    pop eax
    stc
    ret
.not_door:
    pop esi
    pop eax
    clc
    ret

section .data

; Door tile IDs per tileset — pret ref: data/tilesets/door_tile_ids.asm
; Format: tileset_id, tile_id..., 0  (one entry per tileset); 0xFF = end table.
; IsPlayerStandingOnDoorTile scans this to decide whether the arrival tile
; after a warp is a building entrance/exit (needs auto-walk) or a stair/ladder (skip).
DoorTileTable:
    db  0, 0x1B, 0x58, 0       ; OVERWORLD
    db  2, 0x5E, 0             ; MART
    db  3, 0x3A, 0             ; FOREST
    db  8, 0x54, 0             ; HOUSE
    db  9, 0x3B, 0             ; FOREST_GATE
    db 10, 0x3B, 0             ; MUSEUM
    db 12, 0x3B, 0             ; GATE
    db 13, 0x1E, 0             ; SHIP
    db 16, 0x04, 0x15, 0       ; INTERIOR
    db 18, 0x1C, 0x38, 0x1A, 0 ; LOBBY
    db 19, 0x1A, 0x1C, 0x53, 0 ; MANSION
    db 20, 0x34, 0             ; LAB
    db 22, 0x43, 0x58, 0x1B, 0 ; FACILITY
    db 23, 0x3B, 0x1B, 0       ; PLATEAU
    db 0xFF                     ; end
