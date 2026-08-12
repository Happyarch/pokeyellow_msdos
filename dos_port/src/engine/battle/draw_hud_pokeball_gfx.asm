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
%define UI_LAYOUT_EQUATES_ONLY 1
%include "assets/ui_layout_battle.inc"

extern CopyVideoData            ; home/copy2.asm — arms g_tilecache_dirty itself

global PokeballTileGraphics
global PokeballTileGraphicsEnd
global LoadPartyPokeballGfx
global PlaceHUDTiles
global PlacePlayerHUDTiles
global PlaceEnemyHUDTiles
global PlayerBattleHUDGraphicsTiles
global EnemyBattleHUDGraphicsTiles

; The $73 connector sits at the RIGHT end of the player HUD frame element; the
; shelf row is one canvas row below it. Same expression battle_hud.asm uses for
; DrawPlayerHUD's own connector — it is the projected form of pret's
; `hlcoord 18, 10`.
%define P_FRAME_CONN (UI_PLAYER_HUD_FRAME_OFS + UI_PLAYER_HUD_FRAME_GBW - 1)

section .data

; four tiles: pokeball, black pokeball (status ailment), crossed out pokeball
; (fainted) and pokeball slot (no mon) — pret's own comment, byte-for-byte blob
PokeballTileGraphics:
    incbin "../gfx/battle/balls.2bpp"
PokeballTileGraphicsEnd:

; The tile numbers for specific parts of the battle display — pret's own
; comments, and pret's own byte values (verified against the immediates
; battle_hud.asm previously hardcoded: $77/$6F and $74/$78 respectively).
PlayerBattleHUDGraphicsTiles:
    db 0x73     ; unused ($73 is hardcoded into the routine that uses these bytes)
    db 0x77     ; lower-right corner tile of the HUD
    db 0x6F     ; lower-left triangle tile of the HUD

EnemyBattleHUDGraphicsTiles:
    db 0x73     ; unused ($73 is hardcoded in the routine that uses these bytes)
    db 0x74     ; lower-left corner tile of the HUD
    db 0x78     ; lower-right triangle tile of the HUD

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

; ---------------------------------------------------------------------------
; PlacePlayerHUDTiles / PlaceEnemyHUDTiles / PlaceHUDTiles — pret
; draw_hud_pokeball_gfx.asm:115, :132, :149. The HUD "shelf": a $73 connector
; with, on the row below, corner + 8x$76 underline + triangle. The player's
; marches LEFT from its connector, the enemy's marches RIGHT.
;
; RETIRED FROM battle_hud.asm 2026-08-12 (pokeballs fork, step 2), where these
; lived as the port-only DrawPlayerHUDFrame / DrawEnemyHUDFrame /
; place_hud_frame. The tile VALUES there were already correct — this is a naming
; and data-model fork, not a value bug, and that was checked byte by byte
; against pret's two tables before moving.
;
; THE DATA-MODEL HALF IS THE REAL CHANGE. pret copies a 3-byte table into
; wHUDGraphicsTiles and reads the corner and triangle back OUT of WRAM;
; battle_hud.asm passed them as immediates in BH/BL and never touched that WRAM.
; Restoring the WRAM path is what makes wHUDCornerTile / wHUDTriangleTile hold
; what hardware holds — see the equates in gb_memmap.inc, whose addresses were
; confirmed against pokeyellow.sym.
;
; DEVIATION{class=banking; pret=engine/battle/draw_hud_pokeball_gfx.asm:PlacePlayerHUDTiles; behavior=the 3-byte HUD tile table is copied to wHUDGraphicsTiles with an inline rep movsb instead of through CopyData; evidence=pret reaches the table through a ROM bank mapped inside the GB address space so its CopyData is a GB-to-GB copy, and the port has no ROM banks - the table is a flat .data label outside the EBP window - so home/copy.asm CopyData, which does lea esi [ebp+esi] on its source, structurally cannot express it, measured across all 20 of its call sites which pass a GB address without exception; lifetime=permanent while ROM data lives outside the emulated GB address space}
; ---------------------------------------------------------------------------
PlacePlayerHUDTiles:
    mov esi, PlayerBattleHUDGraphicsTiles         ; ld hl — flat .data, see DEVIATION
    lea edi, [ebp + wHUDGraphicsTiles]            ; ld de, wHUDGraphicsTiles
    mov ecx, wHUDGraphicsTilesEnd - wHUDGraphicsTiles   ; ld bc
    rep movsb                                     ; call CopyData
    ; PROJ battle: pret `hlcoord 18, 10`. The raw GB column would land in the
    ; middle of the 40-wide canvas — see regression-battle-second-battle-hud-tile-band,
    ; where exactly that mistake left a ghost tile band at cols 12-18.
    mov esi, W_TILEMAP + P_FRAME_CONN + SCREEN_WIDTH
    mov edx, -1                                   ; ld de, -1 — underline marches left
    jmp PlaceHUDTiles                             ; jr

PlaceEnemyHUDTiles:
    mov esi, EnemyBattleHUDGraphicsTiles
    lea edi, [ebp + wHUDGraphicsTiles]
    mov ecx, wHUDGraphicsTilesEnd - wHUDGraphicsTiles
    rep movsb
    mov esi, W_TILEMAP + UI_ENEMY_HUD_FRAME_OFS   ; PROJ — pret `hlcoord 1, 2`
    mov edx, 1                                    ; ld de, $1 — marches right
    ; pret writes `jr PlaceHUDTiles` here because EnemyBattleHUDGraphicsTiles
    ; sits BETWEEN the two routines in its file. The port keeps that data in
    ; .data, so this would fall straight through — but the jump is written out
    ; anyway, because falling through would DROP a call edge pret has and
    ; faithdiff would (correctly) report it.
    jmp PlaceHUDTiles                             ; jr PlaceHUDTiles

; In: ESI = GB offset of the $73 connector (pret HL), EDX = signed step (pret DE).
;
; EDX carries pret's DE as a FULL 32-BIT signed step rather than DX. pret's
; `add hl, de` is 16-bit with de = $FFFF for -1; here ESI is a 32-bit canvas
; offset, so the step must sign-extend across the whole register or a westward
; walk would add $0000FFFF instead of subtracting one. The two callers above are
; the only ones, and both set EDX with a 32-bit immediate.
PlaceHUDTiles:
    mov byte [ebp + esi], 0x73                    ; ld [hl], $73
    add esi, SCREEN_WIDTH                         ; ld bc, SCREEN_WIDTH / add hl, bc
    mov al, [ebp + wHUDCornerTile]                ; leftmost tile
    mov [ebp + esi], al
    mov al, 8
.loop:
    add esi, edx                                  ; add hl, de
    mov byte [ebp + esi], 0x76
    dec al                                        ; dec a — 8-bit, entered at 8
    jnz .loop
    add esi, edx
    mov al, [ebp + wHUDTriangleTile]              ; rightmost tile
    mov [ebp + esi], al
    ret
