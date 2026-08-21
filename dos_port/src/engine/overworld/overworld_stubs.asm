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

; ApplyPikachuMovementData_ retired — real body ported into
; src/engine/pikachu/pikachu_movement.asm (follower_pikachu Phase 2).

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

; EmotionBubble — RETIRED (M8.2 promotion, 2026-07-24). The real faithful body is
; now LINKED at its pret mirror src/engine/overworld/emotion_bubbles.asm (carved
; out of the dissolved check-only trainer_engine.asm bundle), so the ret-stub that
; existed to close player_animations.asm's link is deleted per its own note.

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

; IsSurfingPikachuInParty retired — real body ported into src/home/map_objects.asm (follower_pikachu Phase 3).

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

; TalkToPikachu retired — real body ported into src/engine/pikachu/pikachu_emotions.asm (follower_pikachu Phase 3).

