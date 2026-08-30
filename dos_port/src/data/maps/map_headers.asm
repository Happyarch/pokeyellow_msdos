; map_headers.asm — map header pointers, tileset dispatch tables, map header
; blob, and the non-overworld tileset / indoor blk asset blobs.
;
; pret ref: data/maps/map_header_pointers.asm (MapHeaderPointers); the rest of
; the generated region projects data/maps/headers/*.asm, data/maps/objects/*.asm
; and the tileset gfx/blockset/collision data into the port's flat model.
;
; Moved here 2026-08-04 from src/engine/overworld/overworld.asm, which is a CODE
; file. `lint_pret_labels` reported MapHeaderPointers as [aux_misplaced]: a pret
; data/ label must live under dos_port/src/data/ or in a generated assets/*.inc.
; This finishes the move MapSongBanks made in the 2026-08-02 sweep (see
; map_songs.asm beside this file, which records why MapHeaderPointers could not
; follow at the time).
;
; That old blocker was DISPROVEN 2026-08-04: a NASM/COFF `equ` DOES cross object
; files — it is emitted as an absolute external symbol and every *linear* use
; (`mov ecx, SYM`, `dd SYM`, `cmp reg, K + SYM`) resolves through an ordinary
; dir32 relocation, exactly how home/overworld.asm has always consumed
; OVERWORLD_BLOCKS_SIZE from another TU. The genuine limitation is only
; NON-LINEAR assembly-time arithmetic on an external symbol (division, %if,
; times counts) — that is what welds the pokedex tile blob to its routine
; (POKEDEX_TILE_GFX_SIZE / 4 in load_pokedex_tiles.asm). No use in the map
; region is non-linear, so the whole region relocates cleanly.
;
; Cross-TU surface (all globals are declared generator-side, in the .inc that
; defines them — the gen_globals.py rule):
;   exported by assets/map_headers.inc: MapHeaderPointers (LoadMapHeader),
;     TilesetGfx/Blocks/Coll Ptrs + Gfx/Blocks Sizes (LoadTilesetHeader),
;     IndoorMapBlkPtrs/Sizes + map_headers_data + MAP_HEADERS_DATA_SIZE
;     (LoadOverworldAssets in src/home/init.asm);
;   exported by the OVERWORLD tileset triple + outdoor blk set below:
;     consumed as immediates by LoadOverworldAssets (init.asm) and by
;     cut.asm / home/overworld.asm for tile clamp checks.
;   D.1: the OVERWORLD triple and the entire outdoor .blk set (pallet_town
;     through route25, plus route23/indigo_plateau via extra_includes.inc)
;     now live here instead of src/engine/overworld/overworld.asm.
;
; Embedded data goes in .data per the linker rule in docs/assembly.md.
;
; Build: nasm -f coff -I include/ -I . -o map_headers.o map_headers.asm
; ---------------------------------------------------------------------------
bits 32

%include "gb_memmap.inc"                  ; OW_*_GBADDR equs (assets/rom_window.inc)
                                           ; consumed by map_headers_data's dw rows

section .data
align 4

; D.1 — OVERWORLD tileset assets (previously in overworld.asm)
%include "assets/overworld_gfx.inc"
%include "assets/overworld_blocks.inc"
%include "assets/overworld_coll.inc"
global MapBorderOverridePointers
%include "assets/map_border_overrides.inc"

; D.1 — outdoor block maps (previously in overworld.asm; route23/indigo_plateau
; were already here via extra_includes.inc but are now exported directly)
%include "assets/pallet_town_blk.inc"
%include "assets/route1_blk.inc"
%include "assets/route21_blk.inc"
%include "assets/viridian_city_blk.inc"
%include "assets/pewter_city_blk.inc"
%include "assets/cerulean_city_blk.inc"
%include "assets/lavender_town_blk.inc"
%include "assets/vermilion_city_blk.inc"
%include "assets/celadon_city_blk.inc"
%include "assets/fuchsia_city_blk.inc"
%include "assets/cinnabar_island_blk.inc"
%include "assets/saffron_city_blk.inc"
%include "assets/route2_blk.inc"
%include "assets/route3_blk.inc"
%include "assets/route4_blk.inc"
%include "assets/route5_blk.inc"
%include "assets/route6_blk.inc"
%include "assets/route7_blk.inc"
%include "assets/route8_blk.inc"
%include "assets/route9_blk.inc"
%include "assets/route10_blk.inc"
%include "assets/route11_blk.inc"
%include "assets/route12_blk.inc"
%include "assets/route13_blk.inc"
%include "assets/route14_blk.inc"
%include "assets/route15_blk.inc"
%include "assets/route16_blk.inc"
%include "assets/route17_blk.inc"
%include "assets/route18_blk.inc"
%include "assets/route19_blk.inc"
%include "assets/route20_blk.inc"
%include "assets/route22_blk.inc"
%include "assets/route24_blk.inc"
%include "assets/route25_blk.inc"

%include "assets/map_headers.inc"
%include "assets/extra_includes.inc"
