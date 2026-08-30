; battle_exp_stubs.asm — former link-only stubs for GainExperience's deferred
; UI/display externs (Wave 2, Stage 3). All stubs formerly here have been retired
; to their pret-mirrored homes and the file now contributes no symbols:
;   GetPartyMonName → home/pokemon.asm (Wave 5/M5.2)
;   SaveScreenTilesToBuffer1 / LoadScreenTilesFromBuffer1 → battle_menu.asm
;   PrintEmptyString → engine/battle/core.asm
;   RespawnOverworldPikachu → engine/pikachu/respawn_overworld_pikachu.asm (Phase 3)
;   DoubleOrHalveSelectedStats / CalculateModifiedStats → engine/battle/core.asm (2026-08-12)
;   DrawPlayerHUDAndHPBar → engine/battle/core.asm (2026-08-13 alias-fork retirement)
;   LoadMonData → home/pokemon.asm (LoadMonData_)
;   ApplyBadgeStatBoosts / ApplyBurnAndParalysisPenaltiesToPlayer → badge_boosts.asm / status_penalties.asm
;   LearnMoveFromLevelUp → evos_moves.asm
; Retained as an empty linked placeholder (see LINK_SRCS in the Makefile) so
; build order remains stable; future EXP display wiring reuses real files
; directly rather than adding stubs here.

bits 32

section .text

; No stubs remain — all providers are now real and linked. This section is
; intentionally empty and contributes no symbols.
