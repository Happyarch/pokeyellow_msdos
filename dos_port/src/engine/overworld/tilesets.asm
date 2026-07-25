; tilesets.asm — pret: engine/overworld/tilesets.asm
;
; Faithful translation (pret cross-reference maintained):
;   LoadTilesetHeader   engine/overworld/tilesets.asm:1
;
; pret's file ends with INCLUDE "data/tilesets/dungeon_tilesets.asm" and
; INCLUDE "data/tilesets/tileset_headers.asm"; the port's equivalents of both
; (DungeonTilesets, and the per-tileset grass / animation / counter-tile columns
; the `tileset` macro packs into each header) are the .data tables at the end of
; this file, so the routine and its data stay together exactly as pret has them.
;
; The per-tileset gfx/blockset/collision POINTER tables are generated Tier-1 data
; (tools/generators/gen_map_headers.py -> assets/map_headers.inc); that blob is
; %included by src/engine/overworld/overworld.asm, which owns it, so they are
; externs here rather than a second %include (which would change which object
; file carries the bytes).
;
; Register map (SM83 -> x86): A->AL, B->BL, HL->ESI, DE->EDX; RAM is
; EBP-relative [ebp + SYM] with SYM from gb_memmap.inc.
;
; Build: nasm -f coff -I include/ -I . -o tilesets.o \
;             src/engine/overworld/tilesets.asm
; ---------------------------------------------------------------------------

bits 32

%include "gb_memmap.inc"

global LoadTilesetHeader

extern IsInArray                          ; src/home/array.asm
extern LoadDestinationWarpPosition        ; src/home/overworld.asm
extern g_tilecache_dirty                  ; src/ppu/ppu.asm
; generated Tier-1 tileset pointer/size tables — assets/map_headers.inc,
; %included by (and exported from) src/engine/overworld/overworld.asm
extern TilesetGfxPtrs                     ; src/engine/overworld/overworld.asm
extern TilesetGfxSizes                    ; src/engine/overworld/overworld.asm
extern TilesetBlocksPtrs                  ; src/engine/overworld/overworld.asm
extern TilesetBlocksSizes                 ; src/engine/overworld/overworld.asm
extern TilesetCollPtrs                    ; src/engine/overworld/overworld.asm

section .text

; ---------------------------------------------------------------------------
; LoadTilesetHeader — dynamic dispatch via W_CUR_MAP_TILESET.
; Pret ref: home/overworld.asm:LoadTilesetHeader
; Copies current tileset gfx/blocks/coll from .data section → fixed EBP slots,
; then sets g_tilecache_dirty so render_bg rebuilds the decoded-tile cache.
; ---------------------------------------------------------------------------
LoadTilesetHeader:
    push eax
    push ebx
    push esi
    push edi
    push ecx

    movzx eax, byte [ebp + W_CUR_MAP_TILESET]   ; tileset index 0-24

    ; Copy tileset GFX to fixed EBP slot
    mov esi, [TilesetGfxPtrs + eax*4]
    lea edi, [ebp + OW_GFX_GBADDR]
    mov ecx, [TilesetGfxSizes + eax*4]
    rep movsb

    ; Copy blockset to fixed EBP slot
    mov esi, [TilesetBlocksPtrs + eax*4]
    lea edi, [ebp + OW_BLOCKS_GBADDR]
    mov ecx, [TilesetBlocksSizes + eax*4]
    rep movsb

    ; Copy collision list to fixed EBP slot (max 64 bytes, $FF-terminated)
    mov esi, [TilesetCollPtrs + eax*4]
    lea edi, [ebp + OW_COLL_GBADDR]
    mov ecx, 64
    rep movsb

    ; Mark tile cache dirty — render_bg must rebuild decoded tiles
    mov byte [g_tilecache_dirty], 1

    ; Populate tileset header fields in WRAM.
    ; TODO-HW: wTilesetBank is meaningless under flat memory (no ROM banking) —
    ; left as a fixed no-op write, faithful in spirit to pret's CopyData'd bank
    ; byte, but never consumed as a real bank switch. Pret ref: engine/overworld/
    ; tilesets.asm (ld a,[hl] / ldh [hTileAnimations],a is the real 12th byte;
    ; the bank byte itself is CopyData'd from Tilesets[0]).
    mov byte [ebp + W_TILESET_BANK], 0x01  ; TODO-HW: banking no-op under flat memory
    mov word [ebp + W_TILESET_BLOCKS_PTR], OW_BLOCKS_GBADDR
    mov word [ebp + W_TILESET_GFX_PTR],   OW_GFX_GBADDR
    mov word [ebp + W_TILESET_COLLISION_PTR],  OW_COLL_GBADDR
    ; Per-tileset grass tile + tile-animation kind — pret ref: data/tilesets/
    ; tileset_headers.asm (`tileset` macro \5/\6 fields), inlined below as
    ; TilesetGrassTiles/TilesetAnimations (small pret data tables, EAX still
    ; holds the 0-24 tileset index from the movzx above).
    mov bl, [TilesetGrassTiles + eax]
    mov [ebp + W_GRASS_TILE], bl
    mov bl, [TilesetAnimations + eax]
    mov [ebp + H_TILE_ANIMATIONS], bl

    ; Per-tileset counter ("talking-over") tiles. pret copies these as bytes 7-9 of the
    ; 12-byte tileset header (wTilesetTalkingOverTiles, 3 bytes; part of its $b-byte
    ; CopyData in LoadTilesetHeader). Consumed by IsSpriteOrSignInFrontOfPlayer's
    ; .counterTilesLoop to extend NPC talking range over Pokemart/Pokecenter counters.
    ; Not yet read by the port's bespoke CheckNPCInteraction, but populated here so the
    ; data is correct when talking-range-over-counter lands. Table inlined below;
    ; EAX still holds the 0-24 tileset index (preserved through here for IsInArray).
    lea edi, [eax + eax*2]                       ; EDI = tileset * 3 (row into the table)
    mov bl, [TilesetCounterTiles + edi + 0]
    mov [ebp + W_TILESET_TALKING_OVER_TILES + 0], bl
    mov bl, [TilesetCounterTiles + edi + 1]
    mov [ebp + W_TILESET_TALKING_OVER_TILES + 1], bl
    mov bl, [TilesetCounterTiles + edi + 2]
    mov [ebp + W_TILESET_TALKING_OVER_TILES + 2], bl

    ; -----------------------------------------------------------------------
    ; Pret tail — engine/overworld/tilesets.asm lines 21-47 (previously
    ; silently omitted; see docs/current_plan_overworld_port.md OW-A.1).
    ; Gates the warp-arrival sub-block alignment (wYBlockCoord/wXBlockCoord =
    ; coord & 1) behind a dungeon-tileset check and a "did the tileset change"
    ; compare, exactly as pret does.
    ; -----------------------------------------------------------------------
    mov edx, 1                          ; IsInArray entry stride (1 byte/tileset id)
    mov esi, DungeonTilesets
    call IsInArray                      ; AL (tileset id) still set from the movzx above
    jc .dungeon                         ; pret: jr c, .dungeon

    ; pret: ld a,[wCurMapTileset] / ld b,a / ldh a,[hPreviousTileset] / cp b / jr z,.done
    mov bl, al                           ; BL = current tileset (AL untouched by IsInArray)
    mov al, [ebp + H_PREVIOUS_TILESET]   ; HRAM union w/ hMapStride/hNSConnectionStripWidth — read-only here
    cmp al, bl
    je .done                            ; tileset unchanged and not a dungeon tileset — skip realignment

.dungeon:
    cmp byte [ebp + W_DESTINATION_WARP_ID], 0xFF
    je .done                            ; pret: ld a,[wDestinationWarpID] / cp $ff / jr z,.done

    call LoadDestinationWarpPosition     ; pret: call LoadDestinationWarpPosition
    mov al, [ebp + W_Y_COORD]            ; pret: ld a,[wYCoord] / and $1 / ld [wYBlockCoord],a
    and al, 1
    mov [ebp + W_Y_BLOCK_COORD], al
    mov al, [ebp + W_X_COORD]            ; pret: ld a,[wXCoord] / and $1 / ld [wXBlockCoord],a
    and al, 1
    mov [ebp + W_X_BLOCK_COORD], al

.done:
    pop ecx
    pop edi
    pop esi
    pop ebx
    pop eax
    ret

section .data

; Dungeon-type tilesets — pret ref: data/tilesets/dungeon_tilesets.asm
; (DungeonTilesets). $FF-terminated, stride 1 (searched by LoadTilesetHeader
; via the shared IsInArray, src/home/array.asm).
; Tileset ids per constants/tileset_constants.asm: FOREST=3, MUSEUM=10, SHIP=13,
; CAVERN=17, LOBBY=18, MANSION=19, GATE=12, LAB=20, FACILITY=22, CEMETERY=15,
; GYM=7.
DungeonTilesets:
    db 3            ; FOREST
    db 10           ; MUSEUM
    db 13           ; SHIP
    db 17           ; CAVERN
    db 18           ; LOBBY
    db 19           ; MANSION
    db 12           ; GATE
    db 20           ; LAB
    db 22           ; FACILITY
    db 15           ; CEMETERY
    db 7            ; GYM
    db 0xFF         ; end

; Per-tileset grass tile + tile-animation kind — pret ref: data/tilesets/
; tileset_headers.asm (the `tileset` macro's \5 grass-tile / \6 TILEANIM_*
; fields). Indexed by W_CUR_MAP_TILESET (0-24, constants/tileset_constants.asm
; order); read by LoadTilesetHeader. TILEANIM_NONE=0, TILEANIM_WATER=1,
; TILEANIM_WATER_FLOWER=2 (constants/map_data_constants.asm).
TilesetGrassTiles:
    db 0x52 ; 0  OVERWORLD
    db 0xFF ; 1  REDS_HOUSE_1
    db 0xFF ; 2  MART
    db 0x20 ; 3  FOREST
    db 0xFF ; 4  REDS_HOUSE_2
    db 0xFF ; 5  DOJO
    db 0xFF ; 6  POKECENTER
    db 0xFF ; 7  GYM
    db 0xFF ; 8  HOUSE
    db 0xFF ; 9  FOREST_GATE
    db 0xFF ; 10 MUSEUM
    db 0xFF ; 11 UNDERGROUND
    db 0xFF ; 12 GATE
    db 0xFF ; 13 SHIP
    db 0xFF ; 14 SHIP_PORT
    db 0xFF ; 15 CEMETERY
    db 0xFF ; 16 INTERIOR
    db 0xFF ; 17 CAVERN
    db 0xFF ; 18 LOBBY
    db 0xFF ; 19 MANSION
    db 0xFF ; 20 LAB
    db 0xFF ; 21 CLUB
    db 0xFF ; 22 FACILITY
    db 0x45 ; 23 PLATEAU
    db 0xFF ; 24 BEACH_HOUSE

TilesetAnimations:
    db 2 ; 0  OVERWORLD     TILEANIM_WATER_FLOWER
    db 0 ; 1  REDS_HOUSE_1  TILEANIM_NONE
    db 0 ; 2  MART
    db 1 ; 3  FOREST        TILEANIM_WATER
    db 0 ; 4  REDS_HOUSE_2
    db 2 ; 5  DOJO          TILEANIM_WATER_FLOWER
    db 0 ; 6  POKECENTER
    db 2 ; 7  GYM           TILEANIM_WATER_FLOWER
    db 0 ; 8  HOUSE
    db 0 ; 9  FOREST_GATE
    db 0 ; 10 MUSEUM
    db 0 ; 11 UNDERGROUND
    db 0 ; 12 GATE
    db 1 ; 13 SHIP          TILEANIM_WATER
    db 1 ; 14 SHIP_PORT     TILEANIM_WATER
    db 0 ; 15 CEMETERY
    db 0 ; 16 INTERIOR
    db 1 ; 17 CAVERN        TILEANIM_WATER
    db 0 ; 18 LOBBY
    db 0 ; 19 MANSION
    db 0 ; 20 LAB
    db 0 ; 21 CLUB
    db 1 ; 22 FACILITY      TILEANIM_WATER
    db 1 ; 23 PLATEAU       TILEANIM_WATER
    db 0 ; 24 BEACH_HOUSE

; Per-tileset counter ("talking-over") tiles — pret ref: data/tilesets/
; tileset_headers.asm (the `tileset` macro's \2 \3 \4 fields, "3 counter tiles").
; 3 bytes per tileset ($FF = unused slot), indexed by W_CUR_MAP_TILESET * 3; copied
; into wTilesetTalkingOverTiles by LoadTilesetHeader. These extend NPC talking range
; over Pokemart/Pokecenter/etc. counter tiles (IsSpriteOrSignInFrontOfPlayer).
TilesetCounterTiles:
    db 0xFF, 0xFF, 0xFF ; 0  OVERWORLD
    db 0xFF, 0xFF, 0xFF ; 1  REDS_HOUSE_1
    db 0x18, 0x19, 0x1E ; 2  MART
    db 0xFF, 0xFF, 0xFF ; 3  FOREST
    db 0xFF, 0xFF, 0xFF ; 4  REDS_HOUSE_2
    db 0x3A, 0xFF, 0xFF ; 5  DOJO
    db 0x18, 0x19, 0x1E ; 6  POKECENTER
    db 0x3A, 0xFF, 0xFF ; 7  GYM
    db 0xFF, 0xFF, 0xFF ; 8  HOUSE
    db 0x17, 0x32, 0xFF ; 9  FOREST_GATE
    db 0x17, 0x32, 0xFF ; 10 MUSEUM
    db 0xFF, 0xFF, 0xFF ; 11 UNDERGROUND
    db 0x17, 0x32, 0xFF ; 12 GATE
    db 0xFF, 0xFF, 0xFF ; 13 SHIP
    db 0xFF, 0xFF, 0xFF ; 14 SHIP_PORT
    db 0x12, 0xFF, 0xFF ; 15 CEMETERY
    db 0xFF, 0xFF, 0xFF ; 16 INTERIOR
    db 0xFF, 0xFF, 0xFF ; 17 CAVERN
    db 0x15, 0x36, 0xFF ; 18 LOBBY
    db 0xFF, 0xFF, 0xFF ; 19 MANSION
    db 0xFF, 0xFF, 0xFF ; 20 LAB
    db 0x07, 0x17, 0xFF ; 21 CLUB
    db 0x12, 0xFF, 0xFF ; 22 FACILITY
    db 0xFF, 0xFF, 0xFF ; 23 PLATEAU
    db 0xFF, 0xFF, 0xFF ; 24 BEACH_HOUSE
