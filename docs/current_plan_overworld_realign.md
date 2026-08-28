# Current Plan: home/overworld.asm pret realignment

> Born 2026-08-28 from a full-file audit: pret `home/overworld.asm` (2,325 lines)
> and `dos_port/src/home/overworld.asm` (5,098 lines) read end-to-end and compared
> routine-by-routine, with every load-bearing claim re-verified against the
> supporting code on both sides (`engine/overworld/advance_player_sprite.asm`,
> `engine/overworld/overworld.asm`, `engine/overworld/map_sprites.asm`,
> `engine/joypad.asm`, `home/joypad.asm`, `home/play_time.asm`,
> `engine/events/poison.asm`, `engine/items/item_effects.asm`, `ram/hram.asm`,
> `include/gb_memmap.inc`, constants). The port logic-matches pret almost
> everywhere; what remains is one misordered seam (the step-completion pipeline),
> a set of unwired/restored-late behaviors, bespoke leftovers from the
> display-dispatcher split, stale comments describing placements the
> 2026-08-21/22 restoration pass already fixed, and free-form divergence prose
> that should be machine-parsed `DEVIATION{}`.

**Scope rule (maintainer): everything realigns except the data model and the flat
model.** Data-model bakes (generated `MapScriptPointers` / `w_map_text_table_ptr`
tables, `wWarpEntries`-sourced `LoadDestinationWarpPosition`, host-BSS
`wMapSpriteData`/`h_load_sprite_temp1/2`) and flat-model elisions (bank switches,
`FarCopyData` bank arg) are accepted and are NOT changed here — where they are
the *reason* a line cannot be literal, they get a structured annotation instead.
The two out-of-map clamps are PERMANENT (maintainer decision 2026-08-16) and stay.

**Adopted from the retired overworld-events plan (2026-08-28).**
`docs/current_plan_overworld_events.md` is archived at
`docs/plans/overworld_events.md`; this plan adopted its overworld-seam work
(Stage J below): the trainer-sight hook retirement and its Stage 5a wiring
prerequisites, the P3c comment residue + `ResetMapTrainerState`, the
`wEnteringCableClub` hold-open on the A-path, and the club-map warp's overworld
half. Its non-adopted tails (Oak-intro golden, field-move must-hit evidence,
`dex_rating` gate, story-ordered rollout) moved to backlog #37; the in-club
trade/battle sessions stay with `docs/current_plan_link_cable.md` Stages 3-4.

**The walk cadence is NOT a finding:** pret's mid-walk frames return via
`.didNotEnterConnectedMap: jp OverworldLoop` (2 DelayFrames per advance), which
the port's `jne OverworldLoop` reproduces. `DEBUG_WALKSPEED`'s 16 ticks/tile is
the correct pret calibration. Do not "fix" it.

## Gate

For every commit under this plan:
1. `nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 -o /dev/null <file>` per
   touched file, then `dos_port/tools/faithdiff <Label>` for each changed pret
   label (justify every unsuppressed call delta in the commit message), then
   `dos_port/tools/lint_pret_labels --no-scan --strict-claims` (exit 0), then
   `dos_port/tools/static_gate`.
2. Behavior moves pixels or WRAM bytes → `make -C dos_port fidelity` (core);
   full tier for the seam stages (A, B, C). Judge by reported=N/N nonzero=0.
3. Run `memory_search regression overworld` before editing; if a change lands a
   fix a regression memory knows about, close the memory in the same commit.
4. One commit per numbered item or tightly-coupled pair; narrative in the commit
   message (the translation log is closed — do not resurrect it).

Archive to `docs/plans/overworld_realign.md` when all stages are `[x]`.

## Findings ledger

Functional (logic, not baking):

- **A1** map-crossing detection moved into `_AdvancePlayerSprite`
  (`advance_player_sprite.asm:56-57` `call CheckMapConnections / jc
  .transitionExit`; loop `jc .mapTransition` at `home/overworld.asm:1934`).
  Pret detects a crossing only at the warp-scan tail (`jp CheckMapConnections`),
  which runs AFTER `StepCountCheck` / `SafariZoneCheckSteps` / `NewBattle`
  (pret's mid-walk `jp nz, CheckMapConnections` is dead by its own comment). Net
  today: a crossing step preempts the step counters, the Safari countdown and the
  wild-encounter roll; the post-battle 3-step no-encounter window lasts one step
  longer; the Safari final step can be eaten by a crossing. Unannotated.
- **A2** post-step poison seam absent: pret `:257-264` (`wIsInBattle` guard →
  `predef ApplyOutOfBattlePoisonDamage` → `wOutOfBattleBlackout` →
  `HandleBlackOut`) is missing between `.notSafariZone` and `NewBattle`
  (`home/overworld.asm:1964`). The routine is translated and linked
  (`engine/events/poison.asm:52`, "NOT YET WIRED") and `wOutOfBattleBlackout`'s
  only writer is that unwired routine. Out-of-battle poison never ticks; no
  poison blackout. No `DEVIATION{}` at the seam.
- **A3** `res 5, [wPikachuOverworldStateFlags]` (the only ROM-wide clear of the
  "Pikachu hidden" bit, pret `advance_player_sprite.asm:10-11`) dropped at walk
  completion. Surf mount/dismount sets bit 5 (`item_effects.asm:674`,
  `overworld.asm:4139`); nothing clears it → starter Pikachu never reappears
  after a surf dismount. Self-admitted in the file header, still outstanding.
- **A4** `IsSurfingPikachuInParty` called only in `EnterMap` (`:1253`); pret
  calls it every loop iteration (`OverworldLoopLessDelay:47`) →
  `wPikachuSpawnStateFlags` goes stale until the next map entry (wrong
  surfing-Pikachu sprite selection if Surf is taught mid-route). Loop comment at
  `:1549` admits the drop but understates it as a "Pikachu-follower path" issue.
- **A5** `UpdateSprites` hoisted to the top of `OverworldLoop` (`:1515`)
  replacing pret's four late sites (`.noDirectionButtonsPressed`,
  `.noDirectionChange`, `.moveAhead`, `.displayDialogue`). Per-iteration call
  count is equal, but the sampling point differs: the port renders the walk
  state from iteration k−1 before iteration k's two frames; pret samples after
  them. Player sprite runs ~2 px ahead and one walk-anim step early for the
  whole walk; turn-only frames render the new facing one iteration early
  (`.handleDirection` also writes the facing byte directly at `:1840`, which
  pret never does — `UpdateSprites` derives it next frame).
- **A6** `.displayDialogue` gates swallowed by the display-dispatcher split:
  pret's shared START/A tail does `predef GetTileAndCoordsInFrontOfPlayer`,
  `call UpdateSprites`, `bit BIT_TURNING → .checkForOpponent`,
  `bit BIT_SEEN_BY_TRAINER → .checkForOpponent`, `lda_coord 8,9 →
  wTilePlayerStandingOn`, then `DisplayTextID` and the `wEnteringCableClub`
  re-entry, ending in `.checkForOpponent` (poll `wCurOpponent` → `.newBattle`,
  else `OverworldLoop`). The port's START path (`:1722-1727`) and A→sign/NPC
  paths have none of this: START opens within ~2 frames of a 180° turn,
  talking works after a trainer has spotted you, and a dialog-seeded
  `wCurOpponent` is only picked up next iteration after an extra
  `RunMapScript`/`SafariZoneCheck` pass instead of `.checkForOpponent`'s
  same-frame `.newBattle`. Both bits are live in the port (turn `:1862`,
  `trainer_sight.asm`). Equivalent parts verified: the whole-branch
  `BIT_DISABLE_JOYPAD` gate ≡ pret's A-only `BIT_UNKNOWN_5_2` + joypad-level
  `DiscardButtonPresses` (three bits set/cleared in lockstep:
  `IgnoreInputForHalfSecond` sets 5|2|1, `CountDownIgnoreInputBitReset` clears
  all three — checked both sides); the A-path additionally drops pret's
  `IsPlayerCharacterBeingControlledByGame` 3-condition gate (faithful version
  exists and `NewBattle` uses it — the split treatment is the tell).
- **A7** beaten trainers: port `CheckNPCInteraction` returns "not found"
  (`bt word [npc_beaten_flags], dx / jc .not_found`, `map_sprites.asm`) — no
  response at all; pret `TalkToTrainer` prints `TRAINER_AFTER_BATTLE_TEXT`
  (battle skipped, dialog printed).
- **A8** idle battle-entry poll (`:1646-1650`): pret's `jp nz, .newBattle`
  shares the post-step tail (`res BIT_STANDING_ON_WARP` on both arms → `jp nc,
  CheckWarpsNoCollision`); the port's CF=0 arm falls straight into input
  handling — no `res`, no warp scan, no `CheckMapConnections`. Reachable while a
  trainer-seeded `wCurOpponent` is suppressed (`BIT_NO_BATTLES`, scripted
  movement, dungeon warp).
- **A9** START/A read `hJoyHeld` (level) instead of `hJoyPressed` (edge) —
  `movzx eax, byte [ebp + hJoyHeld]` `:1706` — plus `.waitAReleased`
  DelayFrame-only stalls (`:1796-1805`). Two net effects: (a) a held A re-runs
  the hidden-event + sign/sprite scans every idle frame, and a no-op A-press
  falls through to D-pad processing where pret consumes the frame
  (`jp z, OverworldLoop`); (b) after any dialog/hidden event the overworld
  (UpdateSprites/LoadGBPal/HandleMidJump) freezes for the release stall. Also
  **N5**: during `BIT_SCRIPTED_MOVEMENT_STATE` the port skips the START check
  entirely (`jnz .checkPADDown`, `:1709`); pret's scripted arm still reads
  `hJoyHeld` and processes START (a real, override-masked START press opens the
  menu mid-scripted-walk on GB).

New findings (not in the 2026-08-28 review memo):

- **N1** `.noDirection` (`:1903-1910`) drops three pret behaviors from
  `.noDirectionButtonsPressed`: (a) `res BIT_TURNING, [wMiscFlags]` — the port
  clears BIT_TURNING only at `.moveAhead2`, so after a turn-only press with no
  following walk the bit stays SET (GBSTATE-visible; and once A6's gates are
  restored it would wrongly discard START/A forever); (b) `xor a / ld
  [wPikachuCollisionCounter], a` — the turn-armed grace counter (8) survives
  idle frames instead of resetting; (c) pret saves `wPlayerLastStopDirection`
  only when `wPlayerMovingDirection != 0` (`and a / jr z .overworldloop`) — the
  port saves unconditionally, so after ≥2 idle frames lastStop is zeroed and a
  same-direction re-press costs an extra turn-only frame (pret walks at once).
- **N2** `CheckMapConnections` (`:2479-2650`): (a) adds `MAP_NO_CONNECTION`
  guards pret does not have — pret would "enter map $FF" on an unconnected-edge
  crossing (glitch-city class); the port no-ops. Unannotated; (b) checks
  east→west→south→north; pret checks west→east→north→south (functionally
  near-equivalent — the four conditions are mutually exclusive — but realign);
  (c) recomputes `wCurrentMapHeight2/Width2` at entry, masking the fact that
  pret computes them in `LoadMapHeader:1902-1907` (documented only as a
  free-form "DIVERGENCE (verified safe)" note at `:4385`).
- **N3** `CollisionCheckOnLand` carries a dead duplicate epilogue
  (`:3442-3467`): `.blocked:` alias + unreachable `.blockedSetCarry` block
  + `; pret ... (.collision)` commentary, with `.passable:` defined TWICE under
  `%ifdef DEBUG_NOCLIP` (duplicate label → NASM error; DEBUG_NOCLIP builds are
  currently unassemblable).
- **N4** `wTilePlayerStandingOn` is never written in the port. Pret writes it in
  `.displayDialogue` (`:111`) and `CheckForTilePairCollisions2` (`:1299`); the
  port reads the tilemap directly into DH (`mov dh, [ebp + STANDING_TILE_OFF]`,
  `:3533`). Pret's only reader (`:1317`) is always preceded by its own write, so
  this is latent — but the WRAM byte diverges from the ROM in state compares,
  and any future verbatim reader (surf's forbidden tile pairs) would read a
  stale value.
- **N6** `LoadMapData` (`:4500`) drops the `hLoadedROMBank` save/restore pair
  pret brackets the routine with (`ldh a,[hLoadedROMBank] / push af … pop af /
  call BankswitchCommon`); `ReloadMapAfterSurfingMinigame`/`ReloadMapAfterPrinter`
  keep theirs. Unannotated inconsistency in the same file.
- **N7** E/W connected-map width stored in `hMapWidth` (0xFF8C,
  `LoadTileBlockMap` west/east arms `:3124`,`:3133`) where pret uses
  `hEastWestConnectedMapWidth` (0xFF8B, the `hMapStride` union byte —
  `ram/hram.asm:55-60`). N/S arms match pret's bytes exactly. Writer and reader
  agree within the port (functionally equivalent, GBSTATE-byte divergence); this
  is precisely the union-trap class `asm-translation` warns about.

Stale comments (claimed state ≠ actual state):

- **S1** the two "PLACEMENT DEVIATION" notes (fly/dungeon-warp test `:1577`,
  Safari `:1590`) say the tests "sit at the top of the idle branch instead" —
  but the code now runs exactly pret's order (JoypadOverworld → SafariZoneCheck
  → script-warp → fly/dungeon-warp → poll). The formerly-unfaithful-now-faithful
  case; rewrite to record the restored order.
- **S2** "inert" claims now false: `DoBikeSpeedup` header (`:2455`) and
  `.walkStart` (`:1878` "nothing sets state 2 until Surf item-use /
  ForceBikeOrSurf links") — Bicycle is live in the dispatch table
  (`item_effects.asm:911`), surfboard live (`item_effects.asm:644`), and
  `ForceBikeOrSurf` is called from `EnterMap`. Also resolve DoBikeSpeedup's
  "Revisit the crossing-mid-speedup case when biking goes live" note (A1 settles
  it: the inner advance's CF is discarded exactly as pret discards it).
- **S3** file-header relocation-debt sentence (`:14-18`): "REMAINING labels
  still live in engine/overworld/overworld.asm … see
  tools/pret_label_allowlist.json" — measured: **0** of pret's 87 top-level
  labels are defined in the engine file; all live in the port mirror; the
  allowlist carries zero overworld entries. Delete/replace with a completion
  note. (The allowlist file itself exists; the pointer is dangling, not the
  file.)
- **S4** `engine/overworld/overworld.asm:1-26` header lists "Faithful
  translations: ResetMapVariables / DrawTileBlock / LoadCurrentMapView /
  LoadTilesetTilePatternData / LoadTileBlockMap / LoadScreenRelatedData /
  LoadMapData" (all relocated to the mirror) and a "Phase 2 scaffold … EnterMap /
  OverworldLoop / LoadPlayerSpriteGraphics" (the real ones live in the mirror;
  this file holds `EnterMapBoot`). Same file `:764`: "pret copies wTileMap
  (25×40) to vBGMap0" — pret's `wTileMap` is 20×18; 25×40 is the port's own
  geometry (self-misattribution inside a DIVERGENCE note).
- **S5** `CheckNPCInteraction` extern comment in overworld.asm (`:174`)
  "(re-detects, then displays)" vs the routine's own "No block-coord re-scan".
- **S6** `.mapTransition` scroll-reset rationale (`:2010-2016`) cites
  `CopyMapViewToVRAM` "always writes GB_TILEMAP0", "the PPU must start reading
  from row 0", "`RedrawRowOrColumn` uses the correct base address" — none of
  those mechanisms exist in the port. The reset itself is required by the
  surface renderer; the justification must describe the renderer.
- **S7** `engine/events/poison.asm:13-19` cross-reference: "the seam marked
  'poison/safari, deferred' (src/home/overworld.asm:1492)" — Safari was restored
  2026-08-21 and line 1492 is now a DEBUG gate. Update when A2 lands.
- **S8** free-form divergence prose that must become machine-parsed
  `DEVIATION{}` (per project-conventions; `--strict-claims` is the ratchet):
  StopMusic "DIVERGENCE 1/2" (`:2830-2860`), LoadMapHeader "DIVERGENCE
  (verified safe)" wCurrentMapHeight2 (`:4385`), InitSprites "DIVERGENCE (port
  ext)" ISTRAINER (`:4940`), DisableRegularSprites "DIVERGENCE (harness-only)"
  (`:4980`), LoadDestinationWarpPosition "PROJ divergence" (`:5085`),
  PlayMapChangeSound "; PROJ:" unverified-door-row note (`:2670`), LoadMapData's
  uncommented `GBPalNormal` addition (`:4525`), ResetMapVariables' window reset
  (`:4630-4638`), the `.mapTransition` port-only resets, and
  `_AdvancePlayerSprite`'s wMapViewVRAMPointer-slide drop (covered only by the
  Schedule*-redraw DEVIATION's evidence text).
- **S9** clamp wording: `LoadCurrentMapView` "STOPGAP … remove once map data is
  extended" (`:3590`) and `DrawTileBlock` "TEMPORARY … the plan is to extend the
  map data" (`:3889`) contradict CLAUDE.md's PERMANENT decision (2026-08-16).
  Clamps stay; comments and annotations must say permanent + why.
- **S10** `SwitchToMapRomBank` doc (`:4670`): "In: AL = map bank id" — every
  caller passes the map NUMBER and the port records that number into
  `hLoadedROMBank` (pret's routine looks up `MapHeaderBanks` internally and
  stores the BANK). Port readers use it only for save/restore bookkeeping
  (unobservable today) — fix the contract text and flag the semantic shift.
  Also: `RunMapScript` (`:4172`) and `LoadTileBlockMap`'s strip arms dropped the
  call entirely (TODO-HW prose) while `Reload*` keep it — pick one treatment and
  annotate.
- **S11** loop-header cadence/coverage notes (`:1502-1513`, `:1549`, M7.1 seam
  `:1941` citing "pret :249-268" as covered while poison is not) — refresh as
  A2/A4/A5 land.
- **S12** `PlayMapChangeSound` "fronts are ±2 rows" phrasing (`:2668`) — the
  projection (row-1 above the standing tile) is correct; tighten the wording,
  keep the no-golden-warp caveat until the Stage I scenario exists.

Bespoke-coupling remnants (verified closed or latent — realign the documented
ones only):

- **B1** `W_OBJECT_DATA_PTR_TEMP` holds the sprite-count byte offset; pret's
  `wObjectDataPointerTemp` holds the object-data BASE (write-only in pret, so
  unobservable in the ROM — but the WRAM bytes diverge and a future verbatim
  reader is off by `2+4W+1+3S` bytes). Realign: store pret's base in the WRAM
  pair; pass the count position to `InitSprites` via a port-local (register or
  BSS), keeping the pret label and contract comment.
- **B2** N7's E/W width byte (see above) — realign to the 0xFF8B union byte
  under pret's `hEastWestConnectedMapWidth` name.

Verified faithful (no action — do not re-audit): EnterMap reset ladder (incl.
`test/setnz cl` res-latches), `StepCountCheck`, `NewBattle` guards/CF contract,
`AllPokemonFainted`, both warp scans + `Retry1/2/Continue` + held-D-pad +
`BIT_FORCED_WARP` arms (Joypad drop DEVIATION-annotated), `CheckWarpsCollision`
(BL live into WarpFound2), `WarpFound2` three branches + both projection
DEVIATIONs, `CheckIfInOutsideMap`, `ExtraWarpCheck` map/tileset list,
`MapEntryAfterBattle`, `HandleBlackOut`, `HandleFlyWarpOrDungeonWarp`,
`StopBikeSurf`, `LeaveMapAnim`, `LoadPlayerSpriteGraphics` dispatcher,
`IsBikeRidingAllowed`, `LoadTilesetTilePatternData` ($600), `LoadTileBlockMap`
body + N/S strips + `ApplyMapBorderOverrides` ordering, both strip loaders,
`IsSpriteOrSignInFrontOfPlayer` (sign branch, counter range, load-bearing
fallthrough), `IsSpriteInFrontOfPlayer` (8-bit L-wrap exit, wd435, useless-read
elision commented), `SignLoop`, `CollisionCheckOnLand` order incl. stale-data
`and`/`nop` quirk, `CheckTilePassable`, `CheckForJumpingAndTilePairCollisions`
incl. both ESI quirks, `LoadCurrentMapView`/`RefreshCollisionTileMap` scaling,
`AdvancePlayerSprite` wrapper, `DrawTileBlock` (×16 scale, 45 stride),
`JoypadOverworld` (restored seams), `ForceBikeDown`, `AreInputsSimulated`,
`GetSimulatedInput` (8-bit dec/$FF wrap), `CollisionCheckOnWater` incl. the
unreferenced `.checkIfVermilionDockTileset`, `RunMapScript` body, walk-gfx
loaders + Common, `LoadMapHeader` (10-byte copy, connection gating, warp/sign
copies, `InitSprites`/`SchedulePikachuSpawnForAfterText` battle-gating,
`LoadWildData`, MapSongBanks; `BIT_NO_PREVIOUS_MAP` early-return deferral is a
documented TODO(OW-A.5/verify)), `CopyMapConnectionHeader`, `CopySignData`,
`LoadScreenRelatedData`, `ReloadMapAfter*`/`FinishReloadingMap`,
`CopyMapViewToVRAM/2` mirrors (deliberately unreached, GB geometry — documented),
`GetMapHeaderPointer`, `IgnoreInputForHalfSecond` (mask 5|2|1),
`ResetUsingStrengthOutOfBattleBit`, `ForceBikeOrSurf`, `HandleMidJump`,
`IsSpinning`, `Func_0ffe`, `InitSprites` arithmetic, `ZeroSpriteStateData`,
`LoadSprite` (incl. the "appears pointless" write), `CheckForUserInterruption`,
`CountDownIgnoreInputBitReset`/`TrackPlayTime`, `joypad_update` ↔
`DiscardButtonPresses`, `IsPlayerCharacterBeingControlledByGame` (3 conditions),
`Func_fcc08`, walk cadence (2 DelayFrames/advance both sides).

## Stage A — the step-completion seam (A1, A2, A3, A4)

Pret order at walk completion: `StepCountCheck` → Safari steps → `wIsInBattle`
guard → poison predef → blackout check → `NewBattle` → `res
BIT_STANDING_ON_WARP` (both arms) → `jp nc, CheckWarpsNoCollision` → (scan) →
`CheckMapConnections` (crossing fires HERE, after the checks) → `.loadNewMap`.

- [x] A1.1 `_AdvancePlayerSprite`: delete `call CheckMapConnections / jc
  .transitionExit` and the `.transitionExit` block (restore always-clear CF);
  keep the coord commit at counter==0.
- [x] A1.2 loop `.moveAhead2`: replace `jc .mapTransition` + `cmp/jne
  OverworldLoop` with pret's shape — `cmp wWalkCounter,0 / jne
  WarpScanToMapConnections` (pret's dead-scan path: mid-walk coords can never
  match, same net destination `jp OverworldLoop`).
- [x] A1.3 post-step tail now ends `jnc CheckWarpsNoCollision` →
  `WarpScanToMapConnections` holds the only crossing exit (`jc
  OverworldLoopLessDelay.mapTransition`); confirm `.mapTransition` is reached
  exactly where pret's `.loadNewMap` runs (after the checks, once).
- [x] A1.4 rewire the CF-reading debug harnesses (`DEBUG_SEAMWALK`
  `.seam_crossed`, `DEBUG_WALK_NORTH` `.wn_crossed`, SEAMLOG's `pushf/jc`) to
  detect the crossing by `wCurMap` change (or WarpScanToMapConnections CF at
  its new owner); keep the 3 FRAME.BIN baselines byte-identical.
- [x] A1.5 update the `WarpScanToMapConnections` header (its "if it had fired
  there" paragraph now describes the removed call) and DoBikeSpeedup's
  "crossing-mid-speedup" note (inner CF discarded = pret).
- [x] A2.1 insert the poison seam at `.notSafariZone`: `cmp byte
  [wIsInBattle],0 / jne CheckWarpsNoCollision` → `call
  ApplyOutOfBattlePoisonDamage` (flat direct call; verify its register contract
  against the pret predef clobber set — nothing live across the seam) → `cmp
  byte [wOutOfBattleBlackout],0 / jne HandleBlackOut`.
- [x] A2.2 fix the M7.1 seam comment (range now actually covered) and
  poison.asm's header/cross-ref (S7) in the same commit.
- [x] A3.1 `_AdvancePlayerSprite` completion branch: `and byte
  [wPikachuOverworldStateFlags], ~0x20 & 0xFF` placed before the coord commit
  (pret order); drop the "Pikachu overworld-state flag" admission from the
  header (IsSpinning is already back).
- [x] A4.1 restore `call IsSurfingPikachuInParty` at the top of
  `OverworldLoopLessDelay` (after `DelayFrame`, before `LoadGBPal`); rewrite
  the `:1549` comment.

## Stage B — input, dialog and idle-path structure (A5, A6, A9, N1, N5)

- [x] B.1 delete the top-of-loop `call UpdateSprites`; restore pret's four
  sites: `.noDirection` (after the res/zero block), `.walkStart` head
  (.noDirectionChange position — before the surf-state test), `.moveAhead`
  (after `IsSpinning`), and the dialog path (B.4). Drop `.handleDirection`'s
  direct facing/anim writes (`mov [W_SPRITE_PLAYER_FACING_DIR], dh` and the
  `.checkPADDown` dh setup) — pret lets the next `UpdateSprites` derive facing.
- [x] B.2 snapshot the joypad edge for the loop: capture `hJoyPressed` into a
  port-local latch right after `OverworldLoop`'s first `DelayFrame` (before the
  second `DelayFrame`'s `joypad_update` clears it), and read START/A from that
  latch on the non-simulated path (pret: `hJoyPressed`), from `hJoyHeld` on the
  scripted path. Update the `:1706` rationale comment; keep the
  `DiscardButtonPresses` mirror (joypad-level) as the DISABLE_JOYPAD answer and
  delete the whole-branch `.checkJoyDisable` gate once B.4's A-path gates
  exist (lockstep equivalence verified — see ledger A6).
- [x] B.3 during `BIT_SCRIPTED_MOVEMENT_STATE`, run the START check (pret's
  scripted arm reads `hJoyHeld` and does NOT skip it); A still falls to the
  D-pad path via the restored `IsPlayerCharacterBeingControlledByGame` gate.
- [x] B.4 restore the `.displayDialogue` tail shared by START and A paths:
  `call GetTileAndCoordsInFrontOfPlayer` (predef → direct-entry per port
  convention), `call UpdateSprites`, `bit BIT_TURNING → .checkForOpponent`,
  `bit BIT_SEEN_BY_TRAINER → .checkForOpponent`, standing-tile store
  (`wTilePlayerStandingOn`, N4's dialog half), then the display call, then the
  `wEnteringCableClub` check → `EnterMap` (the club-map warp's overworld
  trigger — owned here since the events plan retired, see J.5), then
  `.checkForOpponent`: `cmp wCurOpponent,0 / jne <battle tail> / jmp
  OverworldLoop` — replacing the "restart loop and let the poll catch it"
  path for dialog-seeded battles.
- [x] B.5 A-path pret shape before the hidden-event scan: `bit
  BIT_UNKNOWN_5_2 → .noDirection` (or rely on the joypad mirror — pick one,
  annotate), `call IsPlayerCharacterBeingControlledByGame / jnz
  .checkForOpponent`, then the scan. Keep the DoSignInteraction /
  CheckNPCInteraction split (DEVIATION{temporary} already on DoSignInteraction).
- [x] B.6 no-op outcomes return like pret: hidden-event handled → `jmp
  OverworldLoop` (frame consumed); scan found nothing → `jmp OverworldLoop`
  (pret `jp z, OverworldLoop`), NOT fall-through to D-pad; delete
  `.waitAReleased` and the `.interactionDone` stall (edge latch makes them
  unnecessary). Keep the DEBUG dump hooks (re-point them at the new tail).
- [x] B.7 N1 `.noDirection`: add `and byte [wMiscFlags], ~(1<<BIT_TURNING)
  & 0xFF`, `mov byte [wPikachuCollisionCounter], 0`, and make the lastStop
  save conditional (`mov al,[wPlayerMovingDirection] / test al,al / jz
  .overworldLoop` shape).
- [x] B.8 refresh the loop-header comment block (`:1502-1513`) and the
  trade_golden dump note (it leans on the top-of-loop UpdateSprites).

## Stage C — battle-entry and warp-scan tails (A8, S5)

- [x] C.1 idle poll: adopt pret's shared tail — `call NewBattle` → `pushf /
  and movement-flags ~BIT_STANDING_ON_WARP / popf` (both arms; the existing
  post-step idiom) → `jnc CheckWarpsNoCollision` → `jmp .battleOccurred`.
  Update the Stage-1b comment (it documents only the CF=1 arm today).
- [x] C.2 A7: beaten trainers print their after-battle text — move
  `CheckNPCInteraction`'s `npc_beaten_flags` gate from the not-found head into
  the TRAINER TALK dispatch: beaten → print `TRAINER_AFTER_BATTLE_TEXT` via the
  dialog path (battle skipped), exactly pret `TalkToTrainer`; unbeaten flow
  unchanged. Fix the S5 extern comment in the same commit.

## Stage D — CheckMapConnections realignment (N2)

- [x] D.1 reorder the four arms to pret: west, east, north, south (renaming the
  port locals to `.checkWestMap` etc.); keep the pointer-adjustment loops and
  `.savePointerN` structure as-is (verified faithful).
- [x] D.2 move the `wCurrentMapHeight2/Width2` recompute back into
  `LoadMapHeader` (pret :1902-1907) and delete it from `CheckMapConnections`;
  drop the free-form "DIVERGENCE (verified safe)" note (S8 overlap — nothing
  diverges any more).
- [x] D.3 keep the `MAP_NO_CONNECTION` guards but annotate:
  `DEVIATION{class=data-model; pret=home/overworld.asm:CheckMapConnections;
  behavior=an edge crossing with no connection no-ops instead of pret's
  transition into map $FF garbage; evidence=flat model has no ROM garbage
  header at $FF to enter and pret's behavior is the glitch-city class, map
  headers are generated data that ends at the real map count; lifetime=permanent,
  un-reproducible glitch behavior}` (no `;`/`}` inside fields).

## Stage E — collision & tile-pair details (N3, N4, predef shape)

- [ ] E.1 delete the dead `.blocked`/`.blockedSetCarry`/duplicate-`.passable`
  block (`:3442-3467`); verify `DEBUG_NOCLIP` builds assemble again
  (`nasm -D DEBUG_NOCLIP …` on the file or a make target that defines it).
- [ ] E.2 N4: restore `mov al, [ebp + STANDING_TILE_OFF] / mov [ebp +
  wTilePlayerStandingOn], al` in `CheckForTilePairCollisions2` (keep the DH
  copy the scan reads), plus the `.displayDialogue` store from B.4 — the WRAM
  byte then tracks the ROM.
- [ ] E.3 restore pret's internal tile fetch in
  `CheckForJumpingAndTilePairCollisions` (`call _GetTileAndCoordsInFrontOfPlayer`
  before `HandleLedges`, caller-precondition comments deleted), removing the
  documented call-order dependency; keep the caller-side `LoadCurrentMapView`
  port-constraint calls (renderer, documented). Re-run the
  `regression-overworld-watercollision-stale-tile` repro after.

## Stage F — label/HRAM semantics & banking bookkeeping (N6, N7, B1, S10)

- [ ] F.1 N7/B2: `gb_memmap.inc`: add `hEastWestConnectedMapWidth equ 0xFF8B`
  (documenting the pret union with hMapStride/hNorthSouthConnectionStripWidth);
  `LoadTileBlockMap` W/E arms store the connected width there;
  `LoadEastWestConnectionsTileMap` reads it. (N/S bytes already match pret.)
- [ ] F.2 B1: `LoadMapHeader` stores pret's object-data base into
  `W_OBJECT_DATA_PTR_TEMP`; `InitSprites` receives the sprite-count position
  via a port-local (register on entry or a BSS byte) — update both headers and
  the OW-A.2 comment that documents the shift.
- [ ] F.3 S10: fix `SwitchToMapRomBank`'s contract comment (In: AL = map
  NUMBER; the MapHeaderBanks lookup is elided flat-model bookkeeping and
  `hLoadedROMBank` therefore holds the map number, unobservable to its port
  readers); pick one treatment for the dropped calls in `RunMapScript` /
  `LoadTileBlockMap` (call it for line-fidelity like `Reload*` do, or keep
  dropped + commented) and make it consistent.
- [ ] F.4 N6: restore `LoadMapData`'s `hLoadedROMBank` save/restore bracket
  (flat no-op `BankswitchCommon` pair, matching `Reload*`), or annotate the
  omission — prefer restoring for line-fidelity.

## Stage G — stale-comment sweep (S1-S4, S6, S9, S11, S12) — S5 FIXED C.2, S7 FIXED A2.2

One commit, comments only (no code bytes change):

- [ ] G.1 rewrite the two PLACEMENT DEVIATION notes (S1) to state the restored
  pret order and keep only the still-true equivalence argument.
- [ ] G.2 delete/replace the "inert" claims (S2: DoBikeSpeedup header,
  `.walkStart`) with the live bike/surf facts.
- [ ] G.3 file header (S3): replace the relocation-debt sentence with a
  completion note (all pret labels mirrored; allowlist carries none).
- [ ] G.4 rewrite `engine/overworld/overworld.asm`'s header (S4) to the current
  layout (port-only glue, `EnterMapBoot`, seam helpers, asset blobs) and fix
  the `:764` "wTileMap (25×40)" self-misattribution (pret is 20×18).
- [ ] G.5 rewrite `.mapTransition`'s scroll-reset rationale (S6) for the
  surface renderer (stale `hSCX/hSCY` would offset `render_bg`'s blit window
  after the walk; `wMapViewVRAMPointer` kept in lockstep with the other reset
  sites).
- [ ] G.6 clamp comments (S9): STOPGAP/TEMPORARY → PERMANENT with the
  maintainer decision + date; the "remove once map data is extended" clauses
  go (CLAUDE.md forbids that plan).
- [ ] G.7 S12 wording tighten in `PlayMapChangeSound` (drop "fronts are ±2
  rows", state row-1-above-standing); keep the unverified caveat until I.5.
- [ ] G.8 sweep the file for any other comment citing routines/orders the
  2026-08-21/22 pass changed (`grep -n "further down\|now restored\|still
  dropped\|not yet\|TODO-HW" src/home/overworld.asm`) and align each with the
  tree.

## Stage H — structured-annotation sweep (S8)

- [ ] H.1 convert each S8 free-form note to `DEVIATION{class=…; pret=…;
  behavior=…; evidence=…; lifetime=…}` on one line, no `;`/`}` in values:
  StopMusic ×2 (class=HAL), LoadMapData GBPalNormal (class=HAL),
  ResetMapVariables window reset (class=HAL), InitSprites ISTRAINER
  (class=data-model), DisableRegularSprites $FF→0 seed (class=data-model),
  LoadDestinationWarpPosition (class=projection), PlayMapChangeSound door-row
  projection (class=projection), `.mapTransition` port-only resets
  (class=projection), `_AdvancePlayerSprite` wMapViewVRAMPointer-slide drop
  (extend the existing HAL DEVIATION's behavior field instead of a new one).
- [ ] H.2 run `lint_pret_labels --no-scan --strict-claims` (zero
  legacy_annotation / zero violations) and `static_gate`.

## Stage I — verification, goldens, regression hygiene

- [ ] I.1 per-label faithdiff for every touched label (expect deltas at
  `OverworldLoop`/`OverworldLoopLessDelay`/`_AdvancePlayerSprite`/
  `CheckMapConnections`/`LoadMapHeader`/`CheckNPCInteraction` — justify each in
  the commit messages); `static_gate` green.
- [ ] I.2 `make -C dos_port fidelity` (core) after each stage; full tier after
  A/B/C. Known-sensitive scenarios: `ledge_hop`, `surf_round_trip`,
  `route17_trainer_battle`, `safari_game_over`, `trainer_route`,
  `cable_club_nolink`, `sign_pallet`, `overworld_pallet` (+ transition/walk
  baselines byte-identical).
- [ ] I.3 new golden: poison overworld tick (poisoned party mon, walk 4 steps
  → HP loss + "is poisoned" flash; step to blackout → HandleBlackOut path) —
   drives A2 end-to-end on both sides.
- [ ] I.4 new golden: map-connection crossing step (walk off a connected edge;
  assert `wStepCounter` decremented and no encounter roll skipped on the
  crossing step — pins A1's ordering).
- [ ] I.5 new golden: warp through a door (pins `PlayMapChangeSound`'s door-row
  projection and retires its "unverified" caveat).
- [ ] I.6 new golden: re-talk a beaten trainer (after-battle text prints, no
  battle) — pins A7.
- [ ] I.7 add `DEBUG_NOCLIP` to an assembly smoke (or CI matrix entry) so the
  duplicate-label class cannot recur (N3's regression).
- [ ] I.8 record regression memories for behavior changes that supersede old
  notes (A1 ordering, A9 edge reads) in the same commits; purge/overwrite stale
  claims per the memory rules; queue via `docs/stigmergy_outbox.jsonl` if no
  stigmergy access in the session.
- [ ] I.9 final sweep: re-read the three seam comment blocks (loop head,
  M7.1/.notSafariZone, WarpScanToMapConnections) against the landed code;
  archive this plan to `docs/plans/overworld_realign.md`.

## Stage J — adopted from the retired overworld-events plan

Source: `docs/plans/overworld_events.md` (retired 2026-08-28; its header
records the full adoption map). Stage 5a's wiring plus its tail, the P3c
residue, and the club-map warp's overworld half. J.1/J.2 are generator/script
work with no dependency on stages A–I; J.3 depends on C.2 (the beaten-trainer
flow must be pret-shaped before the bespoke state dies); J.5 depends on B.4.

- [ ] J.1 wire the last two standard maps, **CERULEAN_CAVE_B1F** and
  **POWER_PLANT** (`WIRED_MAPS` rows in `gen_map_script_tables.py` + sight
  goldens). Both owe the **truncated-tail decision** first:
  `gen_trainer_headers.py` cannot represent a `text_asm` tail with side
  effects and truncates `MewtwoBattleText` / `PowerPlantZapdosBattleText` (it
  prints each on every run). Either the header generator gains an optional
  per-header "post-end-battle event" field consumed after `PrintEndBattleText`,
  or these two get bespoke hand-ports. Tileset residency is NOT a blocker (the
  sight goldens are wram-only; VIRIDIAN_FOREST wired with FOREST) — but the
  maps' tilesets (CAVERN/FACILITY) are not yet LOADABLE, so their goldens must
  not compare rendered tiles until the per-map tileset dispatch exists.
- [ ] J.2 the four near-miss maps (**FightingDojo, Route12, Route16, Route24** —
  skeleton body, non-standard pointer tables) still engage trainers ONLY
  through the bespoke hook: measured — none is in `WIRED_MAPS`, and the gate
  skips the hook only when `MapScriptPointers[wCurMap] == TrainerMapScript`.
  The retired plan's "all 17 standard maps wired ⇒ all three are dead code"
  claim was false as written; deleting the hook without these four regresses
  them. Driver-extension per-map tails (not `WIRED_MAPS` forcing) or bespoke
  hand-ports, each with its sight golden.
- [ ] J.3 measure the TRUE retirement set: enumerate every map carrying
  trainer headers whose `MapScriptPointers` row is not `TrainerMapScript`
  (generator output + `scripts/` trainer-header tables), and wire or
  consciously annotate each. Then delete, in one commit: the sight gate in
  `OverworldLoopLessDelay` (`home/overworld.asm` `.noTrainerSight` block),
  `CheckTrainerSight` + `TrainerEncounterFlow` (`map_sprites.asm`), BOTH
  `DEVIATION{class=temporary}` annotations (the loop's and
  `EndTrainerBattle`'s at `map_sprites.asm:1056`), and the bespoke
  `ResetMapTrainerState` call in the `InitMapSprites` wrapper
  (+ its `npc_beaten_flags`/`w_trainer_enc_slot`/`w_player_frozen` state once
  C.2's event-flag flow replaces the last readers). Run
  `label_status --callers` on every deleted label, update the label DB,
  faithdiff with justification. `route*_sight` goldens are a regression floor
  only (they never entered the loop); the witness is `trainer_battle_route`.
- [ ] J.4 P3c residue: the de-bespoke LANDED (measured — no slot-populate
  writes remain anywhere in the `InitMapSprites` path) but three comments
  still describe the double-populate: `home/overworld.asm` LoadMapHeader's
  "still the driver until P3c … clears+repopulates the same slots … redundant
  but harmless", `engine/overworld/overworld.asm` InitSprites header's "Until
  P3c retires the bespoke InitMapSprites", and the InitSprites ISTRAINER
  note's "the bespoke InitMapSprites used to set this". Delete/rewrite all
  three (folds into G's sweep if it lands first); keep the ISTRAINER
  port-ext itself until J.3/C.2 remove its bespoke consumers, with its
  DEVIATION re-anchored from H.1's sweep.
- [ ] J.5 **club-map warp (overworld half), adopted.** With B.4's
  `wEnteringCableClub` hold-open restored on the A-path, drive the connected
  receptionist flow end-to-end and witness the warp: `CableClubNPC`'s
  connected path sets `wEnteringCableClub` (port writer
  `engine/menus/link_menu.asm:1241` ≡ pret `:795`), the restored post-dialog
  check re-enters `EnterMap`, `SpecialEnterMap` honors the flag
  (`engine/menus/main_menu.asm:431` arm ≡ pret's `ret nz` club hold), and the
  club map loads through the real path. Scenario via the two-instance
  machinery (linkcheck.sh / nullmodem) or a seeded-peer gate; the in-club
  trade/battle sessions remain link-cable Stages 3-4's scope — this item ends
  at "player standing in the club map, both sides' WRAM matched". Update
  `cable_club_npc.asm`'s "Stage 3 validates that flow end to end" note to
  split the ownership (realign = warp + hold-open; link-cable = session).

## Sequencing

A → (B, C, D, E, F in any order, B before C.2's comment fix if convenient) →
G (after all code stages, so comments describe the final state) → H → I
(continuous; I.3-I.6 land with their stages). A1 first: B.6/C.1's tails and
I.4 both depend on the seam's final shape. Stage J runs independently of A–F
(J.1/J.2 can start immediately); J.3 waits on C.2, J.5 waits on B.4.
