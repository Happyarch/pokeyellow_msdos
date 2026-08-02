# Items-layer dependency ledger

Current open dependencies for `docs/current_plan_items.md`, re-measured
2026-08-02 against the tree at `3fad3249` (linked build and generated project
state), per the maintainer directive to re-derive open items from generated
state. Every stale claim this pass found had made the plan look MORE blocked
than the tree actually is (Surfboard and fishing are both closer to done than
this file said) — none understated remaining work. This is an
open-only ledger: resolved B1/B2/B4/B7/B8 history remains in git and archived
plans, not in the active handoff.

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

### Surfboard — item and overworld dependencies are split

**Generated state:** `project_state` reports `ItemUseSurfboard` as a linked
stub and reports `SurfingAttemptFailed` missing. `IsSpriteInFrontOfPlayer2` is
DONE — re-measured 2026-08-02: `implementation / linked /
statically-reached-from-start`, provider `src/home/overworld.asm`, 2 callers —
delivered by the overworld-events boulder work 2026-07-16; this file's earlier
"missing" reading predated it and is corrected here (see
`docs/current_plan_items.md` for the single canonical statement of this
closure). It reports `IsSurfingAllowed`, `IsNextTileShoreOrWater`,
`CheckForTilePairCollisions`, `IsTilePassable`, and
`LoadWalkingPlayerSpriteGraphics` implemented/relocated and linked. The
simulated-input machinery also exists (in `src/home/map_objects.asm` since
2026-07-26; it was `src/home/simulate_joypad.asm`, now deleted).

**Owner split:** overworld-events owns the pret
`IsSpriteInFrontOfPlayer2` query and normal-loop consumption of the simulated
forward step. The items plan owns pret's `ItemUseSurfboard` and
`SurfingAttemptFailed`, including mount, dismount, failure text, music,
graphics, state writes, and arming the forced step.

**Unblocked when:** `IsSpriteInFrontOfPlayer2`'s faithful provider condition is
already met (see above); the remaining condition is that the simulated forward
step be consumed by the normal overworld loop, and the items workstream can
land `SurfingAttemptFailed` alongside the handler. Joint acceptance must hit
mount, dismount, and failure paths, and must observe the resulting
`wWalkBikeSurfState`, graphics, collision, and forced movement rather than
stopping after the item code arms state. The mount/dismount runtime scenario
also provides first coverage of the overworld-owned `CollisionCheckOnWater` /
`LoadSurfingPlayerSpriteGraphics` path — write it once, in the items plan.

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
- **Fishing header-layout defect:** `FishingAnim` is linked and makes rods
  implementable now (its `EmotionBubble` call is fully resolved — linked at
  its pret mirror since the 2026-07-24 M8.2 promotion, not a blocker). The
  real open dependency, measured 2026-08-02 and not previously recorded here,
  is a header-shape mismatch between `FishingAnim`'s call to
  `LoadAnimSpriteGfx` and `RedFishingTiles`'s layout; see
  `docs/current_plan_items.md` → Fishing rods for the full detail. A related
  `wRodResponse` memmap-promotion note for the same handler family is tracked
  in `docs/current_plan_backlog.md`.

## Cleared prerequisites now owned by the items plan

These are active item tasks, not blockers:

- **Fishing rods:** promote the check-only `ReadSuperRodData` provider and port
  the three handlers plus `FishingInit`.
- **PP items:** the linked `MoveSelectionMenu` and `SelectMenuItem` now include
  the type-2 party-mon/relearn path. Port `ItemUsePPUp` and
  `ItemUsePPRestore`; do not cite the former battle-only menu as a blocker.

Any future blocker entry must include the generated/repository evidence, the
owning plan, the exact interface that clears it, and must-hit acceptance. Do
not add resolved narratives or unsupported negative claims.
