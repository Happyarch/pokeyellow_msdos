; overworld_stubs.asm — ret-only stubs for overworld sprite dispatch targets that
; are referenced (via jmp) by the live _UpdateSprites branches (Wave 6/M6.2) but
; not yet implemented. Keeping the faithful dispatch structure requires these
; symbols to resolve at link; each stub just returns, so the branch is inert until
; the real routine lands. Remove a stub when its wave provides the real one.
;
; Register map: A→AL, HL→ESI, BC→BX, DE→DX; GB mem = [ebp+SYM] (gb_memmap.inc).

bits 32

section .text

; SpawnPikachu stub retired (OW-7.2, 2026-07-10) — the real follower FSM in
; pikachu.asm is now LINKED (GAME_SRCS). Still only reached when a sprite
; slot's offset == $f0 (slot 15), which no current map activates.

; UpdateCGBPal_OBP1 — pret home/cgb_palettes.asm:UpdateCGBPal_OBP1 (apply the
; OBP1 DMG palette register to the CGB OBJ palette set). TODO-HW: the port has
; no CGB palette engine yet (Phase 5 colorization); every OBP write is already
; a `[ebp+IO_OBP1]` TODO-HW mirror, so this is a no-op by design today — same
; translation boundary as RunDefaultPaletteCommand. Reached from the linked
; healing_machine.asm flash loop (and cut/cut2/dust_smoke once those promote).
; TODO(Phase 5 palettes): replace with the real CGB palette apply, then delete.
global UpdateCGBPal_OBP1
UpdateCGBPal_OBP1:
    ret

; ApplyPikachuMovementData_ — pret engine/pikachu/pikachu_movement.asm:ApplyPikachuMovementData_
; (the Pikachu movement-data interpreter: wCurPikaMovementData union, step timers, sprite
; placement). DEFERRED — needs the pikachu_movement subsystem + staged Pikachu overworld gfx.
; OW-A.11 relocated this ret-stub out of pikachu.asm (stub convention: a ret-only body never
; lives in the file mirroring its pret source). Called only by pikachu.asm:ApplyPikachuMovementData
; (linked since OW-7.2), still unreachable while the follower is disabled (SpawnPikachu's
; slot-15 gate never fires on current maps), so inert in the live build.
; TODO(retire M9.1): replace with the real interpreter, then delete this stub.
global ApplyPikachuMovementData_
ApplyPikachuMovementData_:
    ret

; DoScriptedNPCMovement retired — real body ported into movement.asm (OW-2.1),
; with pret's per-slot wNPCMovementScriptSpriteOffset dispatch gate.

; InitializeToggleableObjectsFlags — pret engine/overworld/toggleable_objects.asm:
; InitializeToggleableObjectsFlags (clears the per-map missable/hidden-object show
; flags for a new game). Tail-called by InitPlayerData2. The port's DOCUMENTED
; DIVERGENCE (OW-3.2): toggleable flags live in the flat `g_toggleable_flags`
; array, seeded from toggleable_default_flags by map_sprites.asm:
; InitToggleableObjectFlags at game start — that covers this routine's new-game
; reset, so the pret-named entry stays a deliberate no-op landing for
; InitPlayerData2's jp (NOT a pending port; see toggleable_objects.asm header).
; Retires only if the toggleable subsystem is ever re-derived to pret's
; ebp-relative wToggleableObjectFlags model.
global InitializeToggleableObjectsFlags
InitializeToggleableObjectsFlags:
    ret

; --- EnterMap re-entry leaves (OW-A.4) -------------------------------------
; The faithful EnterMap body (src/engine/overworld/overworld.asm) calls these on
; its fly/warp/battle-return branches. All are inert on the first-boot path:
; MapEntryAfterBattle/EnterMapAnim sit behind status-flag branches that are 0 at
; boot; ResetUsingStrengthOutOfBattleBit and IsSurfingPikachuInParty DO run on the
; boot path but their real effects (clearing wStatusFlags1 BIT_STRENGTH_ACTIVE /
; seeding wPikachuSpawnStateFlags) are no-ops on a fresh, zero-filled game state.

; MapEntryAfterBattle — pret home/overworld.asm:MapEntryAfterBattle. Re-enables warp
; testing (IsPlayerStandingOnWarp) and fades the map back in (GBFadeInFromWhite /
; LoadGBPal) after a battle. Reached only via EnterMap's `call nz` when wStatusFlags4
; BIT_BATTLE_OVER_OR_BLACKOUT is set — i.e. only on post-battle re-entry (OW-A.4(b)),
; never at boot. TODO(OW-A.4(b)/faithful): port the warp-test + fade-in.
global MapEntryAfterBattle
MapEntryAfterBattle:
    ret

; EmotionBubble — pret engine/overworld/trainer_engine.asm:EmotionBubble (draws the
; "!" / "?" / heart bubble over a sprite, via predef). Its REAL body is already
; translated in engine/overworld/trainer_engine.asm — that file is still check-only
; (HOME_CHECK_SRCS), so there is no duplicate-global shadow; this stub only exists to
; close the link now that player_animations.asm is linked (B1).
; NOT REACHED in the live build: player_animations.asm's only call site is FishingAnim
; (the "!" on a bite), and the fishing rods are themselves still ret-stubs (blocker B7,
; docs/items_blockers.md). TODO(overworld-port): delete this stub when trainer_engine.asm
; is promoted to GAME_SRCS — its real EmotionBubble then takes over with no other change.
global EmotionBubble
EmotionBubble:
    ret

; EnterMapAnim — RETIRED (B1, 2026-07-13). The real body was already translated in
; engine/overworld/player_animations.asm; that file was merely never LINKED (it sat in
; HOME_CHECK_SRCS), so this ret-stub silently shadowed it. player_animations.asm is now
; in GAME_SRCS and owns EnterMapAnim.

; ResetUsingStrengthOutOfBattleBit — pret home/overworld.asm:ResetUsingStrengthOutOfBattleBit.
; Clears wStatusFlags1 BIT_STRENGTH_ACTIVE. Reached on EnterMap's `call z` (the
; non-battle-return path, which IS taken at boot), but the bit is already 0 on a
; fresh game, so the ret-stub is behavior-equivalent there. TODO(faithful): res the
; bit once wStatusFlags1 STRENGTH handling exists (needs field-move Strength).
global ResetUsingStrengthOutOfBattleBit
ResetUsingStrengthOutOfBattleBit:
    ret

; IsSurfingPikachuInParty — pret home/map_objects.asm:IsSurfingPikachuInParty. Sets
; wPikachuSpawnStateFlags BIT_PIKACHU_SPAWN_STARTER / _SURFING by scanning the party
; for a starter Pikachu (with Surf). Called unconditionally by EnterMap (and pret's
; OverworldLoop), so it runs at boot. The real SpawnPikachu FSM is linked (pikachu.asm,
; OW-7.2) but its slot-15 gate never fires on current maps, so the flags this would
; set remain unused today.
; TODO(faithful): port with the Pikachu-follower subsystem.
global IsSurfingPikachuInParty
IsSurfingPikachuInParty:
    ret

; LoadHoppingShadowOAM — pret engine/overworld/ledges.asm:LoadHoppingShadowOAM.
; The ledge-hop shadow sprite. pret loads shadow.1bpp to vChars1 tile $7f and two
; OAM entries (wShadowOAMSprite36/37) with 38/39 Y=$a0. Called by HandleLedges
; (src/engine/overworld/ledges.asm, linked since OW-7.2). The port's OAM path
; (PrepareOAMData over wSpriteStateData) models sprites differently and has no
; dedicated shadow slots yet; the shadow is purely cosmetic and does not affect the
; ledge-jump logic, so this is a no-op for now.
; Filed here (not in ledges.asm) per the stub convention: a stub never lives in the
; file that mirrors its own pret source.
; TODO(retire): replace with the real shadow-OAM load once PrepareOAMData models
; shadow-OAM slots (tile→vChars1 $7f + 2 shadow-OAM entries); then delete this stub
; and restore the body in ledges.asm.
global LoadHoppingShadowOAM
LoadHoppingShadowOAM:
    ret

; AnimCut — RETIRED OW-6.1: the faithful body now lives in
; src/engine/overworld/cut2.asm (AnimCut / AnimCutGrass_UpdateOAMEntries /
; _SwapOAMEntries). Its only caller (UsedCut, cut.asm) is check-only, so no
; linked caller depended on this stub — deleted cleanly (no dup_def).
