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
;     (LoadOverworldAssets / the indoor blk loader in overworld.asm);
;   exported by route23_blk.inc / indigo_plateau_blk.inc (below, via
;     extra_includes.inc): consumed as immediates by LoadOverworldAssets;
;   imported from overworld.asm's TU: the OVERWORLD tileset triple, which stays
;     with its engine loader while the dispatch tables here point at it.
;
; Embedded data goes in .data per the linker rule in docs/assembly.md.
;
; Build: nasm -f coff -I include/ -I . -o map_headers.o map_headers.asm
; ---------------------------------------------------------------------------
bits 32

%include "gb_memmap.inc"                  ; OW_*_GBADDR equs (assets/rom_window.inc)
                                          ; consumed by map_headers_data's dw rows

; OVERWORLD tileset blobs stay in src/engine/overworld/overworld.asm's TU;
; the TilesetGfx/Blocks/Coll rows for tileset 0 reference them cross-object.
extern overworld_gfx                      ; overworld.asm (assets/overworld_gfx.inc)
extern OVERWORLD_GFX_SIZE                 ; overworld.asm (assets/overworld_gfx.inc)
extern overworld_blocks                   ; overworld.asm (assets/overworld_blocks.inc)
extern OVERWORLD_BLOCKS_SIZE              ; overworld.asm (assets/overworld_blocks.inc)
extern overworld_coll                     ; overworld.asm (assets/overworld_coll.inc)
extern OVERWORLD_COLL_SIZE                ; overworld.asm (assets/overworld_coll.inc)

section .data
align 4

%include "assets/map_headers.inc"
%include "assets/extra_includes.inc"
