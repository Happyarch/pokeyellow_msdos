; overworld_stubs.asm — ret-only stubs for overworld sprite dispatch targets that
; are referenced (via jmp) by the live _UpdateSprites branches (Wave 6/M6.2) but
; not yet implemented. Keeping the faithful dispatch structure requires these
; symbols to resolve at link; each stub just returns, so the branch is inert until
; the real routine lands. Remove a stub when its wave provides the real one.
;
; Register map: A→AL, HL→ESI, BC→BX, DE→DX; GB mem = [ebp+SYM] (gb_memmap.inc).

bits 32

section .text

; SpawnPikachu — pret home/pikachu.asm:SpawnPikachu (Pikachu-follower FSM).
; TODO(home-rectify Wave 9/M9.1): replace this stub with the real follower spawn.
; Reached only when a sprite slot's offset == $f0 (slot 15), which no current map
; activates, so this is never called in the live build.
global SpawnPikachu
SpawnPikachu:
    ret

; DoScriptedNPCMovement — pret engine/overworld/movement.asm:DoScriptedNPCMovement
; (walk-a-scripted-NPC-in-sync stepper). TODO(home-rectify follow-up): implement the
; stepper consuming M3.3's wNPCMovementDirections + BIT_SCRIPTED_NPC_MOVEMENT (see
; M6.2 divergence note re: bit-0 vs pret's bit-7/wNPCMovementScriptSpriteOffset split).
; Reached only when BIT_SCRIPTED_NPC_MOVEMENT is set, whose only setter (MoveSprite)
; is check-only, so this is never called in the live build.
global DoScriptedNPCMovement
DoScriptedNPCMovement:
    ret

; InitializeToggleableObjectsFlags — pret engine/overworld/toggleable_objects.asm:
; InitializeToggleableObjectsFlags (clears the per-map missable/hidden-object show
; flags for a new game). Tail-called by InitPlayerData2. TODO(overworld): port the
; real toggleable-object flag reset with the hidden-object tables. Until then a new
; game leaves those flags at their (now zero-filled by wGameProgressFlags) state;
; harmless for the current maps. Keep the pret name so InitPlayerData2's jp resolves.
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

; EnterMapAnim — pret engine/overworld/player_animations.asm:EnterMapAnim (fly/warp
; arrival animation: Pikachu/player descend, door-open, etc.). Reached only when
; wStatusFlags6 (FLY_WARP|DUNGEON_WARP) is set, never at boot. TODO(faithful): port
; the arrival animation once the player-animation subsystem lands.
global EnterMapAnim
EnterMapAnim:
    ret

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
; OverworldLoop), so it runs at boot, but the Pikachu-follower spawn FSM (SpawnPikachu,
; also stubbed above) is not implemented, so the flags it would set are unused today.
; TODO(faithful): port with the Pikachu-follower subsystem.
global IsSurfingPikachuInParty
IsSurfingPikachuInParty:
    ret
