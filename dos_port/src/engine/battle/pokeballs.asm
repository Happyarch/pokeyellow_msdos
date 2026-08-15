; pokeballs.asm — battle party-status pokéballs: the port-only OAM HAL around
; pret's DrawAllPokeballs.
;
; DrawAllPokeballs / SetupPokeballs / PickPokeball / WritePokeballOAMData / the
; HUD-tile placers are now ALL translated under their own pret names in the
; mirror file, engine/battle/draw_hud_pokeball_gfx.asm (fork-retirement steps
; 1-3 and 5, landed 2026-08-12). What is left here — DrawBattlePokeballs and
; HideBattlePokeballs — has no pret counterpart at all (grepped the pret tree:
; no such labels exist upstream); they are the port's own glue around the OAM
; compositor, documented below with DEVIATION annotations rather than folded
; into the mirror, because there is nothing pret-named to fold them under.
;
; Wild battle: only the player's balls (pret returns early inside
; DrawAllPokeballs). Trainer battle (wIsInBattle == 2): the enemy's row too.
;
; Register map: a=AL, EBP=GB base; GB memory [EBP+addr]. OAM/params via .bss/.data.

bits 32

%include "gb_memmap.inc"

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
;
; DEVIATION{class=HAL; pret=engine/battle/draw_hud_pokeball_gfx.asm:DrawAllPokeballs; behavior=callers use this port-only wrapper where pret directly calls or falls into DrawAllPokeballs, adding a $FE00 pre-clear, a PrepareStaticOAM entry-count publish, and an explicit OBP0/LCDC OBJ-enable around pret own composition; evidence=on real hardware the shadow-OAM DMA and the always-on OBJ bit give pret those effects for free, the port instead composites OAM through spr_dos_sx/sy plus spr_oam_valid via PrepareStaticOAM and DMAs FE00 conditionally from update_oam, so nothing draws unless a routine on this side performs the publish and enable explicitly; lifetime=permanent while the port's OAM path is PrepareStaticOAM-driven rather than a literal shadow-OAM DMA}
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
; intro → battle handoff): clears both the shadow OAM and $FE00 directly. Does
; NOT touch LCDCF_OBJ_ON any more — see the NOTE below, that bit stays enabled
; through the whole battle now that move animations draw OAM particles.
;
; DEVIATION{class=HAL; pret=home/clear_sprites.asm:ClearSprites; behavior=callers use this port-only wrapper where pret calls ClearSprites, adding an explicit $FE00 zero-fill on top of the shadow-OAM clear; evidence=on real hardware a cleared shadow OAM reads as hidden the moment the next VBlank DMA runs it to FE00, but the port's update_oam DMA is itself gated on wUpdateSpritesEnabled and was skipped while the ball row was up, so FE00 still held the last published ball entries until this routine clears it directly, measured against the battle_menu golden first-diff; lifetime=permanent while update_oam conditionally skips the shadow-to-FE00 DMA during the battle intro}
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

