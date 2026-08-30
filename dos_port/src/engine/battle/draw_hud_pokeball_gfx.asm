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
%include "gb_constants.inc"           ; PARTY_LENGTH, PARTYMON_STRUCT_LENGTH, MON_STATUS

; Ball tile ids, pret's own ($31-$34). They lived in the port-only pokeballs.asm
; while the tile-choosing logic did; they belong with PickPokeball, which is now
; here under pret's name.
%define BALL_OK       0x31
%define BALL_STATUS   0x32
%define BALL_FAINTED  0x33
%define BALL_EMPTY    0x34
%define UI_LAYOUT_EQUATES_ONLY 1
%include "assets/ui_layout_battle.inc"

extern CopyVideoData            ; home/copy2.asm — arms g_tilecache_dirty itself
extern PrepareStaticOAM         ; engine/gfx/sprite_oam.asm — publish OBJ positions

global PokeballTileGraphics
global PokeballTileGraphicsEnd
global LoadPartyPokeballGfx
global PlaceHUDTiles
global PlacePlayerHUDTiles
global PlaceEnemyHUDTiles
global PlayerBattleHUDGraphicsTiles
global EnemyBattleHUDGraphicsTiles
global SetupPlayerAndEnemyPokeballs

; The $73 connector sits at the RIGHT end of the player HUD frame element; the
; shelf row is one canvas row below it. Same expression core.asm uses for
; DrawPlayerHUDAndHPBar's own connector — it is the projected form of pret's
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
    mov esi, wTileMap + P_FRAME_CONN + SCREEN_WIDTH
    mov edx, -1                                   ; ld de, -1 — underline marches left
    jmp PlaceHUDTiles                             ; jr

PlaceEnemyHUDTiles:
    mov esi, EnemyBattleHUDGraphicsTiles
    lea edi, [ebp + wHUDGraphicsTiles]
    mov ecx, wHUDGraphicsTilesEnd - wHUDGraphicsTiles
    rep movsb
    mov esi, wTileMap + UI_ENEMY_HUD_FRAME_OFS   ; PROJ — pret `hlcoord 1, 2`
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

; ===========================================================================
; SetupPokeballs / PickPokeball — pret engine/battle/draw_hud_pokeball_gfx.asm.
;
; FORK RETIREMENT, step 2 (battle plan 4c). The tile-choosing logic lived in
; pokeballs.asm's port-only `build_ball_row`, fused into its OAM writer and
; indexed by slot instead of walking the party structs. These two are pret's own
; split restored under pret's names: SetupPokeballs fills wBuffer[0..5] with the
; empty-ball tile and then calls PickPokeball once per live mon; PickPokeball
; chooses ok / status / fainted for one mon and advances to the next struct.
; The OAM writer is NOT moved here yet — it is the next step, and keeping the
; steps separable is what made step 1 land with zero golden movement.
;
; In:  ESI = HL = party struct base (wPartyMons / wEnemyMons)
;      EDX = DE = address of the party COUNT byte
; Out: wBuffer[0..PARTY_LENGTH-1] = one ball tile id per slot.
; ===========================================================================
global SetupPokeballs
SetupPokeballs:
    mov al, [ebp + edx]                  ; ld a, [de]
    push eax                             ; push af
    mov edx, wBuffer                     ; ld de, wBuffer
    mov bl, PARTY_LENGTH                 ; ld c, PARTY_LENGTH
    mov al, BALL_EMPTY                   ; ld a, $34 ; empty pokeball
.emptyloop:
    mov [ebp + edx], al                  ; ld [de], a
    lea edx, [edx + 1]                   ; inc de
    dec bl                               ; dec c — 8-bit, as pret
    jnz .emptyloop
    pop eax                              ; pop af
    mov edx, wBuffer                     ; ld de, wBuffer
    ; pret guards nothing here: a count of 0 would run the loop 256 times, as on
    ; the GB. Every caller passes wPartyCount / wEnemyPartyCount, which are >= 1
    ; whenever a ball row is drawn, so the boundary is not reachable — and `dec al`
    ; reproduces pret's 8-bit bound exactly rather than a widened one.
.monloop:
    push eax                             ; push af
    call PickPokeball
    lea edx, [edx + 1]                   ; inc de
    pop eax                              ; pop af
    dec al                               ; dec a — 8-bit, as pret
    jnz .monloop
    ret

; ---------------------------------------------------------------------------
; PickPokeball — one mon's ball tile.
; In:  ESI = HL positioned at the mon struct, EDX = DE = wBuffer slot.
; Out: [DE] = tile id; ESI advanced to the next mon struct.
;
; FLAG PRESERVATION, and this routine is dense with it: pret's `ld b, $33` and
; `ld b, $32` sit BETWEEN the `and a` and the `jr z`/`jr nz` that read it, which
; is legal because `ld r, n` writes no flags on SM83 — and `mov bh, imm` writes
; none in x86 either, so the order is kept verbatim. Every pointer step uses
; `lea` rather than `inc`: pret's `inc hl` is flag-neutral on SM83 while `inc esi`
; writes ZF, which is the defect class swept in e85b7fd44.
; ---------------------------------------------------------------------------
global PickPokeball
PickPokeball:
    lea esi, [esi + 1]                   ; inc hl
    mov al, [ebp + esi]                  ; ld a, [hli]
    lea esi, [esi + 1]
    test al, al                          ; and a
    jnz .alive                           ; jr nz, .alive
    mov al, [ebp + esi]                  ; ld a, [hl]
    test al, al                          ; and a
    mov bh, BALL_FAINTED                 ; ld b, $33 — flag-neutral, as pret
    jz .done_fainted                     ; jr z, .done_fainted
.alive:
    lea esi, [esi + 2]                   ; inc hl / inc hl
    mov al, [ebp + esi]                  ; ld a, [hl] ; status
    test al, al                          ; and a
    mov bh, BALL_STATUS                  ; ld b, $32 — flag-neutral, as pret
    jnz .done                            ; jr nz, .done
    dec bh                               ; dec b ; regular ball
    jmp .done                            ; jr .done
.done_fainted:
    lea esi, [esi + 2]                   ; inc hl / inc hl
.done:
    mov al, bh                           ; ld a, b
    mov [ebp + edx], al                  ; ld [de], a
    add esi, PARTYMON_STRUCT_LENGTH - MON_STATUS   ; add hl, bc — next mon struct
    ret

; ===========================================================================
; WritePokeballOAMData — pret engine/battle/draw_hud_pokeball_gfx.asm.
;
; FORK RETIREMENT, step 3 (battle plan 4c). This was the second half of the
; port-only `build_ball_row`: an OAM loop driven by file-local pb_x / pb_y /
; pb_step scratch. It is pret's own loop now, reading pret's own WRAM variables
; (wBaseCoordX / wBaseCoordY / wHUDPokeballGfxOffsetX / wdef4) and consuming the
; wBuffer tiles SetupPokeballs wrote.
;
; DEVIATION{class=projection; pret=engine/battle/draw_hud_pokeball_gfx.asm:WritePokeballOAMData; behavior=the routine is literal but its callers seed wBaseCoordX/wBaseCoordY with the port's widescreen OAM coordinates from the generated battle layout instead of pret's $60/$60 and $48/$20; evidence=the port composites a 40-tile-wide canvas so every battle element carries a projected coordinate and the golden differ reconciles the two sides through its oam_window projection which is why battle_intro compares OAM and passes with the projected values; lifetime=retire if the port ever composites at the GB's 20-tile width}
;
; In: ESI = HL = OAM write cursor (GB offset of the first entry to write).
; ===========================================================================
global WritePokeballOAMData
WritePokeballOAMData:
    mov edx, wBuffer                     ; ld de, wBuffer
    mov bl, PARTY_LENGTH                 ; ld c, PARTY_LENGTH — 8-bit, as pret
.loop:
    mov al, [ebp + wBaseCoordY]          ; ld a, [wBaseCoordY]
    mov [ebp + esi], al                  ; ld [hli], a
    lea esi, [esi + 1]
    mov al, [ebp + wBaseCoordX]          ; ld a, [wBaseCoordX]
    mov [ebp + esi], al                  ; ld [hli], a
    lea esi, [esi + 1]
    mov al, [ebp + edx]                  ; ld a, [de]  — the tile PickPokeball chose
    mov [ebp + esi], al                  ; ld [hli], a
    lea esi, [esi + 1]
    mov al, [ebp + wdef4]                ; ld a, [wdef4] — OAM attribute
    mov [ebp + esi], al                  ; ld [hli], a
    lea esi, [esi + 1]
    mov al, [ebp + wBaseCoordX]          ; ld a, [wBaseCoordX]
    mov bh, al                           ; ld b, a
    mov al, [ebp + wHUDPokeballGfxOffsetX] ; ld a, [wHUDPokeballGfxOffsetX]
    add al, bh                           ; add b
    mov [ebp + wBaseCoordX], al          ; ld [wBaseCoordX], a
    lea edx, [edx + 1]                   ; inc de
    dec bl                               ; dec c — 8-bit, as pret
    jnz .loop
    ret

; ===========================================================================
; DrawAllPokeballs / SetupOwnPartyPokeballs / SetupEnemyPartyPokeballs —
; pret engine/battle/draw_hud_pokeball_gfx.asm.
;
; FORK RETIREMENT, step 5 and last of the routine half (battle plan 4c). These
; three composed the ball rows and were the only part still living inline in the
; port-only DrawBattlePokeballs. `DrawAllPokeballs` was 4c's named blocker for
; PrintBeginningBattleText; with these it is `translated`.
;
; PROJECTED INPUTS, same deviation WritePokeballOAMData carries: pret's $60/$60
; and $48/$20 become the generated battle layout's widescreen OAM coordinates,
; and pret's wShadowOAM / wShadowOAMSprite06 destinations become GB_OAM and
; GB_OAM + 6*4. The destination is NOT a free choice — src/home/vblank.asm's
; update_oam SKIPS the shadow->$FE00 DMA while wUpdateSpritesEnabled == $FF,
; precisely so this row is not overwritten, so writing $FE00 directly is what
; makes the row survive. Recorded in the pokeballs memory as a measured
; constraint, honoured here rather than crossed.
;
; DEVIATION{class=projection; pret=engine/battle/draw_hud_pokeball_gfx.asm:SetupOwnPartyPokeballs; behavior=the pokeball row coordinates are the port's widescreen layout values instead of pret's $60/$60 and $48/$20 and the OAM destination is GB_OAM instead of wShadowOAM; evidence=the port composites a 40-tile-wide canvas so every battle element carries a projected coordinate and update_oam deliberately skips the shadow to FE00 DMA while the ball row is up which makes the shadow buffer the wrong destination on this port; lifetime=retire if the port ever composites at the GB width and runs the shadow OAM DMA during the battle intro}
; ===========================================================================
%define PB_X   UI_PLAYER_BALLS_OAM_X
%define PB_Y   UI_PLAYER_BALLS_OAM_Y
%define EB_X   (UI_ENEMY_BALLS_OAM_X + (UI_ENEMY_BALLS_GBW - 1) * 8)
%define EB_Y   UI_ENEMY_BALLS_OAM_Y

global DrawAllPokeballs
global DrawBattlePokeballs
DrawBattlePokeballs:
DrawAllPokeballs:
    ; DEVIATION{class=HAL; pret=engine/battle/draw_hud_pokeball_gfx.asm:DrawAllPokeballs; behavior=zeroes GB_OAM before composing, publishes valid entries to the DOS compositor via PrepareStaticOAM and enables IO_OBP0 / LCDCF_OBJ_ON; evidence=the port has no hardware OAM DMA so shadow OAM must be published explicitly to spr_dos_sx/sy for the software compositor; lifetime=permanent}
    lea edi, [ebp + GB_OAM]
    xor eax, eax
    mov ecx, 40 * 4 / 4
    rep stosd
    call LoadPartyPokeballGfx
    call SetupOwnPartyPokeballs
    cmp byte [ebp + wIsInBattle], 2      ; trainer battle has both player and enemy rows
    jne .wild
    call SetupEnemyPartyPokeballs
    mov ecx, 12
    jmp .publish
.wild:
    mov ecx, 6
.publish:
    call PrepareStaticOAM
    mov byte [ebp + IO_OBP0], 0xE4
    or byte [ebp + IO_LCDC], LCDCF_OBJ_ON
    ret

; ---------------------------------------------------------------------------
; DrawEnemyPokeballs — pret's enemy-only entry.
; ---------------------------------------------------------------------------
global DrawEnemyPokeballs
DrawEnemyPokeballs:
    call LoadPartyPokeballGfx
    call SetupEnemyPartyPokeballs
    mov ecx, 6
    call PrepareStaticOAM
    mov byte [ebp + IO_OBP0], 0xE4
    or byte [ebp + IO_LCDC], LCDCF_OBJ_ON
    ret

extern ClearSprites                     ; src/home/clear_sprites.asm
global HideBattlePokeballs
HideBattlePokeballs:
    jmp ClearSprites

global SetupOwnPartyPokeballs
SetupOwnPartyPokeballs:
    call PlacePlayerHUDTiles
    mov esi, wPartyMons                  ; ld hl, wPartyMons
    mov edx, wPartyCount                 ; ld de, wPartyCount
    call SetupPokeballs
    mov byte [ebp + wBaseCoordX], PB_X   ; PROJ — pret ld a, $60 / ld [hli], a
    mov byte [ebp + wBaseCoordY], PB_Y   ; PROJ — pret ld [hl], a
    mov byte [ebp + wHUDPokeballGfxOffsetX], 8
    mov byte [ebp + wdef4], 0            ; xor a / ld [wdef4], a
    mov esi, GB_OAM                      ; PROJ — pret ld hl, wShadowOAM
    jmp WritePokeballOAMData             ; jp WritePokeballOAMData

global SetupEnemyPartyPokeballs
SetupEnemyPartyPokeballs:
    call PlaceEnemyHUDTiles
    mov esi, wEnemyMons                  ; ld hl, wEnemyMons
    mov edx, wEnemyPartyCount            ; ld de, wEnemyPartyCount
    call SetupPokeballs
    mov byte [ebp + wBaseCoordX], EB_X   ; PROJ — pret ld a, $48
    mov byte [ebp + wBaseCoordY], EB_Y   ; PROJ — pret ld [hl], $20
    mov byte [ebp + wHUDPokeballGfxOffsetX], -8
    mov byte [ebp + wdef4], 1            ; ld a, $1 / ld [wdef4], a
    mov esi, GB_OAM + 6 * 4              ; PROJ — pret ld hl, wShadowOAMSprite06
    jmp WritePokeballOAMData             ; jp WritePokeballOAMData

; ===========================================================================
; SetupPlayerAndEnemyPokeballs — pret engine/battle/draw_hud_pokeball_gfx.asm:170
; Sets up OAM for both player and enemy pokeball rows on the link-battle versus screen.
;
; DEVIATION{class=projection; pret=engine/battle/draw_hud_pokeball_gfx.asm:SetupPlayerAndEnemyPokeballs; behavior=the pokeball row coordinates are center-projected ($A0/$58 and $A0/$80) instead of pret's $50/$40 and $50/$68, OAM destination is GB_OAM instead of wShadowOAM, and PrepareStaticOAM publishes the entries to the software renderer; evidence=the port composites a 40x25 canvas with uniform battle center projection (X+80, Y+24) and update_oam skips shadow-to-FE00 DMA when wUpdateSpritesEnabled is 0, matching SetupOwnPartyPokeballs; lifetime=retire if the port ever composites at the GB width and runs the shadow OAM DMA}
; ===========================================================================
SetupPlayerAndEnemyPokeballs:
    call LoadPartyPokeballGfx
    mov esi, wPartyMons                  ; ld hl, wPartyMons
    mov edx, wPartyCount                 ; ld de, wPartyCount
    call SetupPokeballs
    mov byte [ebp + wBaseCoordX], 0xA0   ; PROJ — pret ld a, $50 / ld [hli], a ($50+80=160=$A0)
    mov byte [ebp + wBaseCoordY], 0x58   ; PROJ — pret ld [hl], $40 ($40+24=88=$58)
    mov byte [ebp + wHUDPokeballGfxOffsetX], 8
    mov byte [ebp + wdef4], 0            ; xor a / ld [wdef4], a
    mov esi, GB_OAM                      ; PROJ — pret ld hl, wShadowOAM
    call WritePokeballOAMData
    mov esi, wEnemyMons                  ; ld hl, wEnemyMons
    mov edx, wEnemyPartyCount            ; ld de, wEnemyPartyCount
    call SetupPokeballs
    mov byte [ebp + wBaseCoordX], 0xA0   ; PROJ — pret ld a, $50
    mov byte [ebp + wBaseCoordY], 0x80   ; PROJ — pret ld [hl], $68 ($68+24=128=$80)
    mov byte [ebp + wHUDPokeballGfxOffsetX], 8
    mov byte [ebp + wdef4], 1            ; ld a, $1 / ld [wdef4], a
    mov esi, GB_OAM + 6 * 4              ; PROJ — pret ld hl, wShadowOAMSprite06
    call WritePokeballOAMData
    mov ecx, 12
    jmp PrepareStaticOAM                 ; publish 12 entries to software renderer

