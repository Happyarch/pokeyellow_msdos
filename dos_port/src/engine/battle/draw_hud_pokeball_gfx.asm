; draw_hud_pokeball_gfx.asm — mirror of pret engine/battle/draw_hud_pokeball_gfx.asm.
;
; Holds the file's DATA label: PokeballTileGraphics (+ PokeballTileGraphicsEnd),
; the four battle-HUD ball tiles (regular / black status / crossed fainted /
; empty slot), incbin'd from the rgbgfx-rendered gfx/battle/balls.2bpp exactly
; as pret INCBINs it. Consumers:
;   * engine/gfx/load_pokedex_tiles.asm — copies tile 0 to vChars2 $72 (the
;     CONTENTS caught marker), as pret LoadPokedexTilePatterns does.
;   * engine/pokemon/bills_pc.asm:BillsPCMenu — copies tile 0 to vChars2 $78,
;     as pret does.
;
; The rest of the ROUTINE half of pret's file (DrawAllPokeballs / SetupPokeballs
; / PickPokeball / WritePokeballOAMData / PlaceHUDTiles ...) is NOT here yet:
; engine/battle/pokeballs.asm carries a faithful-in-spirit bespoke (port-only
; names) that predates the mirror rule — pre-existing debt owned by the
; battle-completion plan, not grown here. Its retirement is in progress; the
; first label came home on 2026-08-12 (below), and the ORDER is not arbitrary —
; see the note on LoadPartyPokeballGfx for why this one had to be first.

bits 32

%include "gb_memmap.inc"

extern CopyVideoData            ; home/copy2.asm — arms g_tilecache_dirty itself

global PokeballTileGraphics
global PokeballTileGraphicsEnd
global LoadPartyPokeballGfx

section .data

; four tiles: pokeball, black pokeball (status ailment), crossed out pokeball
; (fainted) and pokeball slot (no mon) — pret's own comment, byte-for-byte blob
PokeballTileGraphics:
    incbin "../gfx/battle/balls.2bpp"
PokeballTileGraphicsEnd:

section .text

; ---------------------------------------------------------------------------
; LoadPartyPokeballGfx — pret draw_hud_pokeball_gfx.asm:13. Copies the four ball
; tiles to OBJ tile $31.
;
;   ld de, PokeballTileGraphics
;   ld hl, vSprites tile $31
;   lb bc, BANK(...), (PokeballTileGraphicsEnd - PokeballTileGraphics) / TILE_SIZE
;   jp CopyVideoData
;
; WHY THIS LABEL CAME HOME FIRST, and it is a constraint rather than a
; preference: the tile COUNT is `(End - Start) / TILE_SIZE` — a DIVISION of a
; difference of two labels. CLAUDE.md records that a `global`'d NASM `equ`
; relocates fine for LINEAR uses, but that non-linear assembly-time arithmetic
; on an external (division, `%if`, `times`) is genuinely impossible. So this
; routine can only compute its own size where the blob is DEFINED — here. Had it
; stayed in pokeballs.asm it would have needed either a hand-written literal
; count (a second thing to keep in sync with the .2bpp) or the private copy of
; the blob it actually had.
;
; THE PRIVATE COPY IS WHAT THIS RETIRES. pokeballs.asm carried its own
; `ball_gfx: incbin "../gfx/battle/balls.2bpp"` — the SAME file, incbin'd a
; second time under a port-only name, six lines from a mirror file whose own
; header comment complained about exactly that. Two copies of one asset is not a
; style nit: it is a silent divergence waiting for someone to regenerate the
; graphics and update only one of them.
;
; The hand-rolled `rep movsd` it replaces also had to arm `g_tilecache_dirty`
; by hand. Routing through CopyVideoData makes that correct by construction —
; the routine arms the flag itself.
; ---------------------------------------------------------------------------
LoadPartyPokeballGfx:
    mov edx, PokeballTileGraphics                 ; ld de — SOURCE, flat (.data)
    mov esi, GB_VCHARS0 + 0x31 * TILE_SIZE        ; ld hl, vSprites tile $31 — DEST, GB offset
    mov bh, 0                                     ; BANK(): no-op under the flat model
    mov bl, (PokeballTileGraphicsEnd - PokeballTileGraphics) / TILE_SIZE
    jmp CopyVideoData                             ; jp (tail call)
