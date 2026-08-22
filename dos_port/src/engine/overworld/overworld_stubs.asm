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

; InitializeToggleableObjectsFlags — RETIRED 2026-08-22. The port's flat-model
; realization already existed under the forked name InitToggleableObjectFlags in
; map_sprites.asm; it has been renamed to pret's label and moved to its pret mirror
; src/engine/overworld/toggleable_objects.asm, so InitPlayerData2's tail jump now
; reaches a real body instead of this `ret`. The stub's own text argued the no-op
; was correct because EnterMap seeds the flags anyway — true for the flags, but it
; also meant InitPlayerData2 silently skipped the wEventFlags clear.

; --- EnterMap re-entry leaves (OW-A.4) -------------------------------------
; The faithful EnterMap body (src/engine/overworld/overworld.asm) calls these on
; its fly/warp/battle-return branches. All are inert on the first-boot path:
; MapEntryAfterBattle/EnterMapAnim sit behind status-flag branches that are 0 at
; boot; ResetUsingStrengthOutOfBattleBit and IsSurfingPikachuInParty DO run on the
; boot path but their real effects (clearing wStatusFlags1 BIT_STRENGTH_ACTIVE /
; seeding wPikachuSpawnStateFlags) are no-ops on a fresh, zero-filled game state.

; MapEntryAfterBattle — RETIRED 2026-08-22. The real body now lives at its pret
; mirror src/home/overworld.asm, with the IsPlayerStandingOnWarp call the ret-stub
; was silently dropping (which left BIT_STANDING_ON_WARP cleared after a battle
; fought on a warp tile, so the collision-exit path could not fire).

; EmotionBubble — RETIRED (M8.2 promotion, 2026-07-24). The real faithful body is
; now LINKED at its pret mirror src/engine/overworld/emotion_bubbles.asm (carved
; out of the dissolved check-only trainer_engine.asm bundle), so the ret-stub that
; existed to close player_animations.asm's link is deleted per its own note.

; EnterMapAnim — RETIRED (B1, 2026-07-13). The real body was already translated in
; engine/overworld/player_animations.asm; that file was merely never LINKED (it sat in
; HOME_CHECK_SRCS), so this ret-stub silently shadowed it. player_animations.asm is now
; in GAME_SRCS and owns EnterMapAnim.

; ResetUsingStrengthOutOfBattleBit — RETIRED 2026-08-22. The real one-instruction
; body now lives at its pret mirror src/home/overworld.asm. The stub's own
; justification ("the bit is already 0 on a fresh game") stopped holding once
; field_move_messages.asm:PrintStrengthText began setting it.

; IsSurfingPikachuInParty retired — real body ported into src/home/map_objects.asm (follower_pikachu Phase 3).

; LoadHoppingShadowOAM — RETIRED 2026-08-22. The real body now lives at its pret
; mirror src/engine/overworld/ledges.asm, with the shadow tile and the two OAM
; records generated into assets/ledge_shadow.inc. The stub's stated blocker — "the
; port's OAM path has no dedicated shadow slots yet" — was false: PrepareOAMData
; already stops its unused-entry clear at wShadowOAMSprite36 while
; BIT_LEDGE_OR_FISHING is set, i.e. it was reserving four slots for a shadow
; nothing wrote.

; AnimCut — RETIRED OW-6.1: the faithful body now lives in
; src/engine/overworld/cut2.asm (AnimCut / AnimCutGrass_UpdateOAMEntries /
; _SwapOAMEntries). Its only caller (UsedCut, cut.asm) is check-only, so no
; linked caller depended on this stub — deleted cleanly (no dup_def).

; TalkToPikachu retired — real body ported into src/engine/pikachu/pikachu_emotions.asm (follower_pikachu Phase 3).

