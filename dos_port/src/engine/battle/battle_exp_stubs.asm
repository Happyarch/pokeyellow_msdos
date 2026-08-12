; battle_exp_stubs.asm — link-only stubs for GainExperience's deferred UI/display
; externs (Wave 2, Stage 3). The EXP/stat/level data update in GainExperience is
; live, but these no-op providers are not uniformly cosmetic:
; CalculateModifiedStats affects the active battle-mon stats after a level-up,
; and DoubleOrHalveSelectedStats restores selected Reflect/Light Screen stats
; after an in-battle status cure. Current scenarios do not enter either branch.
; PrintEmptyString is presentation-only but executes on the faint path. See the
; measured stub table in docs/current_plan_battle_completion.md.
;
; LATENT COLLISION (intentional, documented): ApplyBadgeStatBoosts (badge_boosts.asm),
; ApplyBurnAndParalysisPenaltiesToPlayer (status_penalties.asm) and LearnMoveFromLevelUp
; (evolution.asm/evos_moves.asm) have REAL bodies in check-only backend files that are
; not yet linked. When the level-up-DISPLAY step wires those real routines in, delete
; the matching stubs here (and PrintStatsBox/CalculateModifiedStats/DrawPlayerHUDAndHPBar
; once the front end implements them) to avoid duplicate-symbol link errors.

bits 32

section .text

; GetPartyMonName is now REAL (home/pokemon.asm, Wave 5/M5.2) — no longer stubbed.
global ModifyPikachuHappiness
; SaveScreenTilesToBuffer1 / LoadScreenTilesFromBuffer1 are now REAL (battle_menu.asm) —
; no longer stubbed (they snapshot/restore the battle screen for the EXP display too).
; PrintEmptyString is now REAL (engine/battle/core.asm, the pret mirror — it prints a
; zero-length stream so PrintText redraws the battle message box) — no longer stubbed.
global CalculateModifiedStats
; RespawnOverworldPikachu (pret engine/pikachu/pikachu_movement.asm) is reached by
; ItemUseMedicine (engine/items/item_use.asm) whenever a fainted mon is revived or
; a mon levels up (Yellow re-places the overworld Pikachu).
; DoubleOrHalveSelectedStats is now REAL (engine/battle/core.asm, the pret mirror,
; over the two bodies in unused_stats_functions.asm) — no longer stubbed. It was
; blocked on the in-battle ITEM menu, which landed with battle plan 2c.
; TODO(pikachu):     RespawnOverworldPikachu — with the Yellow Pikachu-follow engine.
global RespawnOverworldPikachu
; DrawPlayerHUDAndHPBar is now REAL (engine/battle/core.asm — alias → battle_hud.asm
; DrawPlayerHUD) — no longer stubbed here (retired with the enemy-side
; DrawEnemyHUDAndHPBar pattern).
; LoadMonData is now REAL (src/home/pokemon.asm wrapper → LoadMonData_) — no longer stubbed;
; it populates wLoadedMon so GainExperience's CalcLevelFromExperience reads the right mon.
; ApplyBadgeStatBoosts (badge_boosts.asm) and ApplyBurnAndParalysisPenaltiesToPlayer
; (status_penalties.asm) are now REAL + linked via the move-effect scaffold — no longer
; stubbed here (the documented latent collision is resolved by deleting these stubs).
; LearnMoveFromLevelUp is now REAL (evos_moves.asm) — no longer stubbed.

ModifyPikachuHappiness:
CalculateModifiedStats:
RespawnOverworldPikachu:
    ret
