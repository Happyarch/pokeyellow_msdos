; battle_exp_stubs.asm — link-only stubs for GainExperience's deferred UI/display
; externs (Wave 2, Stage 3). The validated EXP/stat/level MATH in experience.asm
; (GainExperience) is wired live on the victory path, but its presentation tail —
; the per-mon "gained EXP" / "grew to level N" text, the level-up stats box, move
; learning, and the in-battle modified-stat recompute — is the bespoke front end's
; job and is still deferred. These symbols are only *referenced* (never reached at
; runtime in a way that matters post-victory: the level-up DATA is updated by the
; real CalcStats inside GainExperience; only the on-screen display is skipped), so a
; bare `ret` satisfies the linker and leaves the data correct. The front end shows
; the gained-EXP text itself (battle_menu.asm:BattleWonGiveExp, reading
; wExpAmountGained).
;
; LATENT COLLISION (intentional, documented): ApplyBadgeStatBoosts (badge_boosts.asm),
; ApplyBurnAndParalysisPenaltiesToPlayer (status_penalties.asm) and LearnMoveFromLevelUp
; (evolution.asm/evos_moves.asm) have REAL bodies in check-only backend files that are
; not yet linked. When the level-up-DISPLAY step wires those real routines in, delete
; the matching stubs here (and PrintStatsBox/CalculateModifiedStats/DrawPlayerHUDAndHPBar
; once the front end implements them) to avoid duplicate-symbol link errors.

bits 32

section .text

global GetPartyMonName
global ModifyPikachuHappiness
; SaveScreenTilesToBuffer1 / LoadScreenTilesFromBuffer1 are now REAL (battle_menu.asm) —
; no longer stubbed (they snapshot/restore the battle screen for the EXP display too).
global PrintEmptyString
global CalculateModifiedStats
global DrawPlayerHUDAndHPBar
; LoadMonData is now REAL (load_mon_data.asm wrapper → LoadMonData_) — no longer stubbed;
; it populates wLoadedMon so GainExperience's CalcLevelFromExperience reads the right mon.
; ApplyBadgeStatBoosts (badge_boosts.asm) and ApplyBurnAndParalysisPenaltiesToPlayer
; (status_penalties.asm) are now REAL + linked via the move-effect scaffold — no longer
; stubbed here (the documented latent collision is resolved by deleting these stubs).
; LearnMoveFromLevelUp is now REAL (battle_menu.asm) — no longer stubbed.

GetPartyMonName:
ModifyPikachuHappiness:
PrintEmptyString:
CalculateModifiedStats:
DrawPlayerHUDAndHPBar:
    ret
