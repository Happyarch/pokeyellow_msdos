; load_pokedex_tiles.asm — LoadPokedexTilePatterns.
;
; Mirror of pret engine/gfx/load_pokedex_tiles.asm, whose ONLY label this is.
; Carried by src/engine/menus/pokedex.asm until chunk 18 of the relocated-label
; grind; both callers there now reach it as an extern.
;
; Register map: A=AL, B=BH, C=BL (BC=BX), D=DH, E=DL (DE=EDX), HL=ESI, EBP=GB base.
;
; Build: nasm -f coff -I include/ -I . -o load_pokedex_tiles.o load_pokedex_tiles.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

global LoadPokedexTilePatterns

extern LoadHpBarAndStatusTilePatterns  ; src/home/load_font.asm
extern g_tilecache_dirty               ; src/ppu/ppu.asm

; The tile blob travels WITH the routine: POKEDEX_TILE_GFX_SIZE is
; `PokedexTileGraphicsEnd - PokedexTileGraphics`, assembly-time arithmetic that an
; extern cannot satisfy. Same exception ARROW_OFF forced in chunk 16.
section .data
%include "assets/pokedex_tiles.inc"

section .text

; ===========================================================================
; LoadPokedexTilePatterns — load the pokédex interface tileset into VRAM.
; pret: engine/gfx/load_pokedex_tiles.asm:LoadPokedexTilePatterns —
;   1. LoadHpBarAndStatusTilePatterns (fills $62-$7F; the dex tiles then
;      overwrite $60-$71, exactly as on the GB),
;   2. PokedexTileGraphics (18 tiles: frame/line tiles + the ′″ height
;      glyphs) → vChars2 tile $60,
;   3. PokeballTileGraphics (1 tile) → vChars2 tile $72 (caught marker).
; Used by both halves of this file (ShowPokedexMenu.setUpGraphics and ShowPokedexData).
; NB: this clobbers the box tiles $79-$7E via step 1 — the dex exit path
; (ShowPokedexMenu.exitPokedex → ReloadMapData) reloads LoadTextBoxTilePatterns
; + the map tileset, faithfully to pret. All registers preserved.
; ===========================================================================
LoadPokedexTilePatterns:
    call LoadHpBarAndStatusTilePatterns
    mov byte [g_tilecache_dirty], 1     ; VRAM tile data changes → rebuild cache
    push ecx
    push esi
    push edi
    mov esi, PokedexTileGraphics
    lea edi, [ebp + GB_VCHARS2 + 0x60 * TILE_SIZE]
    mov ecx, POKEDEX_TILE_GFX_SIZE / 4
    rep movsd
    mov esi, PokeballTileGraphics
    lea edi, [ebp + GB_VCHARS2 + 0x72 * TILE_SIZE]
    mov ecx, POKEBALL_TILE_SIZE / 4
    rep movsd
    pop edi
    pop esi
    pop ecx
    ret
