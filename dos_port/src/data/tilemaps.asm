; tilemaps.asm — TileIDListPointerTable and the tile-ID list blobs
; (pret data/tilemaps.asm; Tier-1, data layer).
;
; battle-animations plan Stage 4. The mon-pic helpers in
; src/engine/battle/animations.asm (GetTileIDList / CopyPicTiles / CopyTileIDs)
; index this table by TILEMAP_* id.
;
; PLACEMENT: pret files these labels under data/, so lint_pret_labels'
; aux_misplaced rule requires src/data/ (or a generated assets/*.inc). The table
; itself is HAND-WRITTEN here rather than generated, exactly as
; src/data/move_effect_pointers.asm and src/data/battle_anim_dispatch.asm are:
; its rows hold flat program-image addresses of blobs incbin'd in this file, which
; no generator can derive. The blob BYTES are pret's, incbin'd from the read-only
; pret gfx/ tree — never transcribed.
;
; ROW LAYOUT DIVERGES FROM PRET, deliberately:
;   pret:  dw <ptr> + dn <height>, <width>   = 3 bytes/row  (16-bit ROM pointer)
;   port:  dd <ptr> + db (height<<4)|width   = 5 bytes/row  (32-bit flat address)
; so GetTileIDList indexes by 5, not 3. Same flat-pointer model as every other
; battle-animation table (see the header of src/engine/battle/animations.asm).
; The size byte keeps pret's nibble packing verbatim — low nibble = width
; (columns, pret's c), high nibble = height (rows, pret's b).
bits 32

%include "assets/battle_anim_constants.inc"   ; TILEMAP_* / NUM_TILEMAPS

global TileIDListPointerTable
global DownscaledMonTiles_5x5
global DownscaledMonTiles_3x3
global MonTiles
global SlideDownMonTiles_7x5
global SlideDownMonTiles_7x3
global GengarIntroTiles1
global GengarIntroTiles2
global GengarIntroTiles3
global GameBoyTiles
global LinkCableTiles

; tile_ids — port form of pret data/tilemaps.asm's MACRO of the same name.
; Args match pret's order: pointer, width, height.
%macro tile_ids 3
    dd %1
    db ((%3) << 4) | (%2)
%endmacro

section .data

TileIDListPointerTable:
; entries correspond to TILEMAP_* constants (constants/gfx_constants.asm)
    ; tilemap pointer, width, height
    tile_ids MonTiles,               7,  7
    tile_ids SlideDownMonTiles_7x5,  7,  5
    tile_ids SlideDownMonTiles_7x3,  7,  3
    tile_ids GengarIntroTiles1,      7,  7
    tile_ids GengarIntroTiles2,      7,  7
    tile_ids GengarIntroTiles3,      7,  7
    tile_ids GameBoyTiles,           6,  8
    tile_ids LinkCableTiles,        12,  3
TileIDListPointerTableEnd:
%if (TileIDListPointerTableEnd - TileIDListPointerTable) != NUM_TILEMAPS * 5
    %error "TileIDListPointerTable row count does not match NUM_TILEMAPS"
%endif

DownscaledMonTiles_5x5:
    incbin "../gfx/pokemon/downscaled_5x5.tilemap"

DownscaledMonTiles_3x3:
    incbin "../gfx/pokemon/downscaled_3x3.tilemap"

MonTiles:
    incbin "../gfx/pokemon/front.tilemap"

SlideDownMonTiles_7x5:
    incbin "../gfx/pokemon/slide_down_7x5.tilemap"

SlideDownMonTiles_7x3:
    incbin "../gfx/pokemon/slide_down_7x3.tilemap"

GengarIntroTiles1:
    incbin "../gfx/intro/gengar_1.tilemap"

GengarIntroTiles2:
    incbin "../gfx/intro/gengar_2.tilemap"

GengarIntroTiles3:
    incbin "../gfx/intro/gengar_3.tilemap"

GameBoyTiles:
    incbin "../gfx/trade/game_boy.tilemap"

LinkCableTiles:
    incbin "../gfx/trade/link_cable.tilemap"
