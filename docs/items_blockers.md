# Completed items-layer dependency ledger

Dependency ledger re-measured 2026-08-02 against the tree at `3fad3249`, then
closed with the last fishing implementation in `fe91b329`. The completed plan
is archived at `docs/plans/items.md`. Remaining tails below explicitly belong to
other subsystems; this file is historical evidence, not an active handoff.

Verification terms are deliberate. `defined`, `linked`, `executed`, and
`golden-matched` are different claims. Re-run the cited generated commands
before acting; this document is a handoff, not authority.

## Blocks remaining item implementation

### Itemfinder — RESOLVED 2026-07-16 (except runtime evidence)

Cleared by a cross-cut from `docs/current_plan_overworld_events.md` Stage 3:
`HiddenItemCoords` is generated (`tools/generators/gen_hidden_item_coords.py` →
`assets/hidden_item_coords.inc`, linked via `src/data/hidden_events_data.asm`);
`src/engine/items/itemfinder.asm` (`HiddenItemNear`/`Sub5ClampTo0`) is linked
(`ITEMS_SRCS`); `IsInRestOfArray` was promoted into `HOME_SRCS` (it has since
moved from the `vcopy.asm` util bucket to its pret mirror
`src/home/array2.asm`); and `ItemUseItemfinder` is a real body in
`item_effects.asm` (no longer the
`item_use_stubs.asm` ret-stub), calling `HiddenItemNear` and the already-generated
`ItemfinderFound{Item,Nothing}Text`. Build clean; `lint_pret_labels` 0;
`faithdiff` shows only the documented predef→`FlagAction` and
`jp PrintText`→`iu_print_text` deviations.

**Remaining tail (not a build blocker):** the must-hit runtime scenario for both
outcomes ("near"/"nothing", without mutating the obtained-item flag during a test)
still owes evidence — ITEMFINDER is not obtainable in the current build, so it
lands with the first reachable hidden-item map.

### Surfboard — RESOLVED 2026-08-02

`ItemUseSurfboard` and `SurfingAttemptFailed` are both real linked bodies in
`src/engine/items/item_effects.asm`; the `item_use_stubs.asm` ret-stub is gone.
Mount, dismount and the "no place to get off" refusal are all ported, and the
golden scenario `surf_round_trip` (id 40) drives mount and dismount through the
LIVE overworld loop with live collision on both sides — which is also the first
coverage of the overworld-owned `CollisionCheckOnWater` /
`LoadSurfingPlayerSpriteGraphics` path, written once as this ledger required.

`IsSpriteInFrontOfPlayer2` was already DONE (2026-07-16) and was not re-ported,
but it did need a repair: its not-found exit returned `$C200` where pret's 8-bit
`L` wrap returns `$C100`. `ItemUseSurfboard` is the first caller to dereference
`hl` on both exits, so the bug was latent until now.

**Remaining tail (not a blocker, and not this plan's):** the dismount arms a
simulated forward step that the port never consumes, because `.stopSurfing` sets
`wJoyIgnore` = `$FF` and there is no `JoypadOverworld` to clear it. Measured stuck
at frames 1180 / 1440 / 1800. Owned by overworld-events; tracked as
`docs/current_plan_backlog.md` #33.

## Blocks end-to-end reachability or fidelity

### Repel expiry text — scenario coverage still open

**Generated state:** `project_state DisplayTextID` reports the translated body
linked from `src/home/text_script.asm`, `implementation / linked /
statically-reached-from-start`; `label_status --callers DisplayTextID` now
reports 7 call sites / 6 unique callers, including `TryDoWildEncounter`
(`src/engine/battle/wild_encounters.asm:147`).

**Current behavior:** Repel counters decrement and suppress encounters, but the
last-step message still needs a must-hit runtime scenario. Do not special-case
the text in `wild_encounters.asm`; overworld-events Stage 2 owns the shared
`DisplayTextID` service path and its coverage.

**Acceptance:** a must-hit runtime scenario must execute
`TryDoWildEncounter`'s last-Repel branch and the real `DisplayTextID`, then
compare the message surface. A generic fidelity pass without those hits is
regression-only evidence.

### In-battle ITEM button — `BattleItemMenu` is ret-only

**Repository state:** the linked `BattleItemMenu` body in
`src/engine/battle/battle_menu.asm` falls through to `BattlePartyMenu: ret`.
`DisplayBattleMenu` calls it when ITEM is selected, so the button currently
reopens the battle menu instead of entering the bag.

**Owner split:** `docs/current_plan_battle_completion.md` Stage 2c owns the
in-battle bag and turn-consumption routing. The items plan already owns and has
state coverage for `UseItem_`, catching, and battle-item effects.

**Acceptance:** real battle navigation must hit `BattleItemMenu`, select an
item, hit `UseItem`, and verify both the effect and whether the turn is consumed.
The existing `battle_menu` golden does not exercise this sub-flow.

## Non-blocking deferred fidelity tails

- **Poké Flute / Pikachu:** `project_state` reports
  `IsPikachuRightNextToPlayer` and `PlaySpecificPikachuEmotion` missing, so the
  Pewter sleeping-Pikachu branch currently follows the ordinary no-effect
  path. Restore it with the Pikachu-emotion subsystem.
- **Pikachu happiness:** `ModifyPikachuHappiness` is a linked stub with 9 call
  sites / 8 unique callers (re-measured 2026-08-02). Medicine, TM/HM, and
  X-item call sites are already placed; retiring the one stub activates them
  together.
- **Snorlax encounters:** Poké Flute owns setting the Route 12/16 fight events;
  overworld-events owns the map-script consumers that turn those events into
  encounters.
- **Fishing header-layout defect — RESOLVED 2026-08-03** with the fishing-rod
  port: `RedFishingTiles` reshaped to `LoadAnimSpriteGfx`'s 12-byte header and
  the count passed in full `EAX` (backlog #24, caller-side fix — party icons
  untouched); `wRodResponse` promoted to `gb_memmap.inc` (#25). Golden
  `fish_old_rod` (id 42) exercises the fixed path.

## Cleared prerequisites delivered by the items plan

These item tasks are complete:

- **Fishing rods: DONE 2026-08-03.** The three handlers + `FishingInit` /
  `RodResponse` are real bodies in `src/engine/items/item_effects.asm`,
  `super_rod.asm` is linked (`ITEMS_SRCS`), `GoodRodMons` is generated, and the
  rod stubs' retirement deleted `item_use_stubs.asm` outright — NO item-handler
  family remains stubbed. Golden `fish_old_rod` (id 42) covers the
  deterministic branches; the Good/Super picks are RNG-gated cross-side and
  share the same skeleton.
- **PP items: DONE 2026-08-02.** `ItemUsePPUp` and `ItemUsePPRestore` are real
  linked bodies in `src/engine/items/item_effects.asm`, both stubs retired, with
  golden scenario `item_pp_restore` (id 39) covering the type-2 move-menu path
  that no existing scenario reached. The re-measurement was right that this had
  zero external blockers.

Any future blocker entry must include the generated/repository evidence, the
owning plan, the exact interface that clears it, and must-hit acceptance. Do
not add resolved narratives or unsupported negative claims.
