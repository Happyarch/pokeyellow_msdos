# Items-layer dependency ledger

Current open dependencies for `docs/current_plan_items.md`, refreshed
2026-07-15 against the linked build and generated project state. This is an
open-only ledger: resolved B1/B2/B4/B7/B8 history remains in git and archived
plans, not in the active handoff.

Verification terms are deliberate. `defined`, `linked`, `executed`, and
`golden-matched` are different claims. Re-run the cited generated commands
before acting; this document is a handoff, not authority.

## Blocks remaining item implementation

### Itemfinder — RESOLVED 2026-07-16 (except runtime evidence)

Cleared by a cross-cut from `docs/current_plan_overworld_events.md` Stage 3:
`HiddenItemCoords` is generated (`tools/gen_hidden_item_coords.py` →
`assets/hidden_item_coords.inc`, linked via `src/data/hidden_events_data.asm`);
`src/engine/items/itemfinder.asm` (`HiddenItemNear`/`Sub5ClampTo0`) is linked
(`ITEMS_SRCS`); `IsInRestOfArray` was promoted with `vcopy.asm` into `HOME_SRCS`;
and `ItemUseItemfinder` is a real body in `item_effects.asm` (no longer the
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
stub and reports `IsSpriteInFrontOfPlayer2` and `SurfingAttemptFailed` missing.
It reports `IsSurfingAllowed`, `IsNextTileShoreOrWater`,
`CheckForTilePairCollisions`, `IsTilePassable`, and
`LoadWalkingPlayerSpriteGraphics` implemented/relocated and linked. The
simulated-input machinery also exists in `src/home/simulate_joypad.asm`.

**Owner split:** overworld-events owns the pret
`IsSpriteInFrontOfPlayer2` query and normal-loop consumption of the simulated
forward step. The items plan owns pret's `ItemUseSurfboard` and
`SurfingAttemptFailed`, including mount, dismount, failure text, music,
graphics, state writes, and arming the forced step.

**Unblocked when:** `IsSpriteInFrontOfPlayer2` has a faithful provider and the
simulated forward step is consumed by the normal overworld loop; the items
workstream can land `SurfingAttemptFailed` alongside the handler. Joint
acceptance must hit mount, dismount, and failure paths, and must observe the
resulting `wWalkBikeSurfState`, graphics, collision, and forced movement rather
than stopping after the item code arms state.

## Blocks end-to-end reachability or fidelity

### Repel expiry text — scenario coverage still open

**Generated state:** `project_state DisplayTextID` reports the translated body
linked from `src/home/text_script.asm`; `label_status --callers DisplayTextID`
reports the `TryDoWildEncounter` caller.

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
- **Pikachu happiness:** `ModifyPikachuHappiness` is a linked stub with seven
  callers. Medicine, TM/HM, and X-item call sites are already placed; retiring
  the one stub activates them together.
- **Snorlax encounters:** Poké Flute owns setting the Route 12/16 fight events;
  overworld-events owns the map-script consumers that turn those events into
  encounters.
- **Fishing bubble:** `FishingAnim` is linked and makes rods implementable now.
  Its `EmotionBubble` call resolves to a linked stand-in while the translated
  trainer-engine body remains check-only, so a bite omits only the cosmetic
  "!" bubble until that closure is promoted.

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
