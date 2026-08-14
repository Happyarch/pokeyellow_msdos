; pokeballs.asm — battle party-status pokéballs (Wave 2, battle-intro polish).
;
; Faithful-in-spirit port of engine/battle/draw_hud_pokeball_gfx.asm (DrawAllPokeballs
; / SetupPokeballs / PickPokeball / WritePokeballOAMData). pret draws the party-status
; balls as OAM sprites; the port's battle screen is BG-tilemap with OAM otherwise off,
; and its $00-$7F BG tile range is fully used, so we keep pret's OAM approach: the four
; ball tiles (gfx/battle/balls.2bpp: ok / status / fainted / empty) load into the free
; OBJ tile area ($8000), the row is written as OAM entries, and PrepareStaticOAM +
; render_sprites composite them. They are an INTRO element (faithful): shown over the
; "Wild X appeared!" screen, then the HP-bar HUD replaces them for the battle proper.
;
; Wild battle: only the player's balls (pret returns early). Trainer battle
; (wIsInBattle == 2): the enemy's row too.
;
; Positions follow pret's OAM coords + the port's battle centering (+80px X, +24px Y).
;
; Register map: a=AL, EBP=GB base; GB memory [EBP+addr]. OAM/params via .bss/.data.

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%define UI_LAYOUT_EQUATES_ONLY 1
%include "assets/ui_layout_battle.inc"

; pret's OBJ tile ids (LoadPartyPokeballGfx loads at vSprites tile $31;
; PickPokeball: $31 regular, $32 black/status, $33 crossed/fainted, $34 empty).
; The port used to park these at tiles $00-$03 — golden-diverged in both the
; OAM tile bytes and the vChars0 slots; pret's slots are free here too.
; The ball tile ids moved to draw_hud_pokeball_gfx.asm with PickPokeball, which
; is the only thing that chose between them. BALL_EMPTY was the last one used
; here and its user is gone too.

; OAM bases from the generated battle layout (the elements are the rows'
; LEFT tiles; OAM = screen px + (8,16), see PrepareStaticOAM).
; PROJ battle: player row = UI_PLAYER_BALLS (OAM base = left ball, marches +8)
%define PB_X   UI_PLAYER_BALLS_OAM_X
%define PB_Y   UI_PLAYER_BALLS_OAM_Y
; PROJ battle: enemy row = UI_ENEMY_BALLS (OAM base = RIGHT-end ball, marches -8)
%define EB_X   (UI_ENEMY_BALLS_OAM_X + (UI_ENEMY_BALLS_GBW - 1) * 8)
%define EB_Y   UI_ENEMY_BALLS_OAM_Y

; NOTE: this file used to carry `ball_gfx: incbin "../gfx/battle/balls.2bpp"` —
; a SECOND copy of the blob the mirror file draw_hud_pokeball_gfx.asm already
; holds as PokeballTileGraphics. Retired 2026-08-12 together with the forked
; LoadPokeballGfx; the loader now lives in the mirror under pret's own name,
; LoadPartyPokeballGfx, because the tile count is a DIVISION of the blob's size
; and that cannot be computed across an object file.

section .bss

section .text

global DrawBattlePokeballs
global HideBattlePokeballs
extern PrepareStaticOAM
extern HideSprites
extern DrawAllPokeballs         ; draw_hud_pokeball_gfx.asm — pret's whole composition

; ---------------------------------------------------------------------------
; DrawBattlePokeballs — load gfx, build the player ball row (and the enemy's in a
; trainer battle), publish them to the OAM compositor, and enable OBJ rendering.
; In: EBP = GB base; wPartyCount/wPartyMons (+ wEnemyPartyCount/wEnemyMons) seeded.
; ---------------------------------------------------------------------------
DrawBattlePokeballs:
    ; PORT-ONLY WRAPPER. Everything pret does now lives in DrawAllPokeballs
    ; (mirror file, pret's own name); what is left here is the port's OAM HAL:
    ; the $FE00 pre-clear, the PrepareStaticOAM publish, and the OBJ enable.
    ;
    ; Zero the whole $FE00 OAM first: the rows overwrite entries 0..5 (0..11 for
    ; a trainer), and everything beyond must read HIDDEN — the GB's shadow OAM
    ; beyond the row holds Y=160-parked leftovers (hidden), and the golden diff
    ; treats hidden-on-both-sides as equal; stale visible-coordinate garbage
    ; from the last overworld OAM DMA is not hidden.
    lea edi, [ebp + GB_OAM]
    xor eax, eax
    mov ecx, 40 * 4 / 4
    rep stosd
    call DrawAllPokeballs                 ; pret's own composition
    ; PrepareStaticOAM needs the entry COUNT, which pret has no notion of — it
    ; DMAs the whole shadow buffer. Re-derive it from the same test
    ; DrawAllPokeballs used.
    mov ecx, 6
    cmp byte [ebp + wIsInBattle], 2
    jne .publish
    mov ecx, 12
.publish:
    call PrepareStaticOAM                 ; ECX entries → DOS position tables
    mov byte [ebp + IO_OBP0], 0xE4        ; identity sprite palette (colors 1-3 visible)
    or byte [ebp + IO_LCDC], LCDCF_OBJ_ON ; enable OBJ rendering
    ret

; ---------------------------------------------------------------------------
; HideBattlePokeballs — remove the ball row when the HP-bar HUD takes over (the
; intro → battle handoff): clear the OAM and turn OBJ rendering back off.
; ---------------------------------------------------------------------------
HideBattlePokeballs:
    call HideSprites                      ; zero shadow OAM + publish 0 valid entries
    ; Zero $FE00 too: DrawBattlePokeballs wrote the ball entries there directly,
    ; and on the GB the cleared shadow OAM is DMA'd over $FE00 at the next
    ; frame — stale visible-coordinate balls in the dump would diverge from the
    ; golden's zeros (measured, battle_menu first-diff).
    lea edi, [ebp + GB_OAM]
    xor eax, eax
    mov ecx, 40 * 4 / 4
    rep stosd
    ; NOTE: this routine used to also clear LCDCF_OBJ_ON here ("battle proper
    ; draws no OBJ"). That assumption died when the move-animation interpreter
    ; went live (1ad2fc46): DrawFrameBlock's OAM particles are battle OBJ, and
    ; the cleared bit kept render_sprites' LCDC gate shut for the whole battle
    ; (measured 2026-08-08: IO_LCDC=$E1 at MoveAnimation publish, spr_oam_valid
    ; =40 intact, zero pixels drawn). On the GB nothing clears the OBJ bit in
    ; battle — hiding is done by the zeroed shadow OAM alone, which the
    ; HideSprites + $FE00 clear above already reproduce. The battle-exit
    ; re-enable in init_battle.asm (W-1 fix) is now redundant defense.
    ret

