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
; The ROUTINE half of pret's file (DrawAllPokeballs / LoadPartyPokeballGfx /
; SetupPokeballs / PickPokeball / WritePokeballOAMData / PlaceHUDTiles ...) is
; NOT here: engine/battle/pokeballs.asm carries a faithful-in-spirit bespoke
; (port-only names, its own private copy of this blob) that predates the mirror
; rule — pre-existing debt owned by the battle-completion plan, not grown here.

bits 32

global PokeballTileGraphics
global PokeballTileGraphicsEnd

section .data

; four tiles: pokeball, black pokeball (status ailment), crossed out pokeball
; (fainted) and pokeball slot (no mon) — pret's own comment, byte-for-byte blob
PokeballTileGraphics:
    incbin "../gfx/battle/balls.2bpp"
PokeballTileGraphicsEnd:
