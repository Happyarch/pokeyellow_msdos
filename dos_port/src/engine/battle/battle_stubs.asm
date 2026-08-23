; battle_stubs.asm — battle front-end link stubs.
;
; CheckTargetSubstitute was stubbed here; it is now the faithful shared helper in
; move_effect_helpers.asm (the move-effect scaffold, deleted in chunk 17), so MoveHitTest's substitute
; check is real. JumpMoveEffect is live in effects.asm.
;
bits 32
section .text

; SaveTrainerName is now REAL (src/engine/battle/save_trainer_name.asm, its pret
; mirror) — no longer stubbed. Its stub's justification ("the Tier-1
; TrainerNamePointers name table ... not yet generated") was stale: the names are
; generated into assets/trainer_names.inc by gen_trainer_names.py.

; PrintSendOutMonMessage — STUB RETIRED 2026-08-18 (battle plan sendout messages).
; The real body is in its pret-mirrored home, src/engine/battle/common_text.asm,
; together with GoText, DoItText, GetmText, EnemysWeakText, and PrintPlayerMon1Text.

; StarterPikachuBattleEntranceAnimation — pret
; StarterPikachuBattleEntranceAnimation — STUB RETIRED 2026-08-23: the real routine
; now links from its pret mirror, src/engine/battle/pikachu_entrance_anim.asm.
; SendOutMon's starter-Pikachu branch draws the entrance for real.

; UseBagItem — STUB RETIRED 2026-08-12 (battle plan 2c). The real body is in its
; pret-mirrored home, src/engine/battle/core.asm, together with BagWasSelected,
; DisplayPlayerBag and DisplayBagMenu. It was added here by 2a purely so
; PartyMenuOrRockOrRun's safari-ROCK arm could keep pret's shape while the
; in-battle bag was unported; that arm now reaches the real routine.

; LinkBattleExchangeData — STUB RETIRED 2026-08-23 (link cable plan Stage 4
; step 2). The real body (the per-turn action exchange, the mid-battle
; disconnect hatch, and the local drain loops) is now in its pret-mirrored
; home, src/engine/battle/core.asm, right after SelectEnemyMove — pret's own
; neighbor of this routine. All six callers (ChooseNextMon,
; ReplaceFaintedEnemyMon, TryRunningFromBattle, SelectEnemyMove,
; EnemySendOutFirstMon are call sites; ExecuteEnemyMove reads the receive
; buffer the others populate) now reach the real exchange.

; SetupPlayerAndEnemyPokeballs — pret engine/battle/draw_hud_pokeball_gfx.asm:170.
; The link-battle "versus" screen's own pokeball-row setup (SEPARATE from the
; regular in-battle HUD ball rows SetupOwnPartyPokeballs/SetupEnemyPartyPokeballs
; already draw, above in this file's pret-mirrored home).
;
; ADDED AS A STUB 2026-08-23 (link cable plan Stage 4 step 2,
; DisplayLinkBattleVersusTextBox). Re-measured whether this routine's own
; dependencies exist, since the header note in draw_hud_pokeball_gfx.asm
; calling it "NOT TRANSLATED, deliberately" predates the pokeballs-fork
; retirement (battle plan 4c): LoadPartyPokeballGfx, SetupPokeballs and
; WritePokeballOAMData — the three routines this one's body calls — are all
; `translated` now. The remaining blocker is NOT a missing dependency, so
; per the implementer spec this is stubbed rather than the scope being
; widened to invent one: pret's own body hardcodes GB-native OAM pixel
; coordinates for this screen ($50/$40 for the player row, $50/$68 for the
; enemy row) that have no widescreen projection decided, and this port's own
; precedent (DrawEnemyPokeballs's header, a few lines below in this file's
; pret-mirrored home; also the battle-completion plan's MarowakAnim OAM-offset
; refusal) explicitly declines to invent one without a scenario that can see
; it. Same call, same reasoning, applied here rather than re-litigated.
; STUB{label=SetupPlayerAndEnemyPokeballs; class=stub; pret=engine/battle/draw_hud_pokeball_gfx.asm:SetupPlayerAndEnemyPokeballs; behavior=return without drawing either pokeball row, so DisplayLinkBattleVersusTextBox's versus screen shows its name/VS text box but no party-roster pokeballs; evidence=label DB reports SetupPlayerAndEnemyPokeballs missing, its three callees (LoadPartyPokeballGfx, SetupPokeballs, WritePokeballOAMData) are all translated so no dependency blocks it, and the only remaining blocker is the undecided widescreen projection of pret's GB-native OAM coordinates ($50/$40, $50/$68) for a screen no current scenario exercises, the same class of decision DrawEnemyPokeballs's header and the battle-completion plan's MarowakAnim note both declined to guess; lifetime=until a widescreen placement for the link-battle versus pokeball rows is decided (maintainer/plan call, not an agent guess)}
global SetupPlayerAndEnemyPokeballs
SetupPlayerAndEnemyPokeballs:
    ret
