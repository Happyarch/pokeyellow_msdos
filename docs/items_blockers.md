# Items-layer dependency ledger

Current open dependencies for `docs/current_plan_items.md`, refreshed
2026-07-15 against the linked build and generated project state. This is an
open-only ledger: resolved B1/B2/B4/B7/B8 history remains in git and archived
plans, not in the active handoff.

Verification terms are deliberate. `defined`, `linked`, `executed`, and
`golden-matched` are different claims. Re-run the cited generated commands
before acting; this document is a handoff, not authority.

## Blocks remaining item implementation

### Itemfinder — hidden-object data and dispatch are not live

**Generated state:** `project_state ItemUseItemfinder HiddenItemNear` reports a
linked `ItemUseItemfinder` stub and an unlisted `HiddenItemNear` implementation
with no callers. `itemfinder.asm` references `HiddenItemCoords`, for which the
port has no provider. Overworld-events Stage 4 likewise records the missing
generated hidden-object table and A-press dispatch.

**Owner split:** `docs/current_plan_overworld_events.md` Stage 4 owns
`gen_hidden_events.py`/`assets/hidden_events.inc`, hidden-event dispatch, and
promoting `itemfinder.asm`. The items plan owns `ItemUseItemfinder` once that
interface exists.

**Unblocked when:** generated coordinates are linked, `HiddenItemNear` has a
real caller, and the handler can distinguish nearby unobtained items from
nothing nearby without mutating the found flag. Acceptance needs must-hit
coverage for `ItemUseItemfinder` and `HiddenItemNear`, including both outcomes.

### Surfboard — two pret dependencies are absent

**Generated state:** `project_state` reports `ItemUseSurfboard` as a linked
stub and reports `IsSpriteInFrontOfPlayer2` and `SurfingAttemptFailed` missing.
It reports `IsSurfingAllowed`, `IsNextTileShoreOrWater`,
`CheckForTilePairCollisions`, `IsTilePassable`, and
`LoadWalkingPlayerSpriteGraphics` implemented/relocated and linked. The
simulated-input machinery also exists in `src/home/simulate_joypad.asm`.

**Owner split:** overworld-events owns the sprite/front-tile interaction and
movement integration; the items plan owns the pret `ItemUseSurfboard` mount,
dismount, failure, music, graphics, and forced-step flow.

**Unblocked when:** the two missing labels have faithful providers and the
simulated forward step is reachable from the normal overworld loop. Acceptance
must hit mount, dismount, and failure paths and observe the resulting
`wWalkBikeSurfState`, graphics, collision, and movement behavior.

## Blocks end-to-end reachability or fidelity

### Repel expiry text — `DisplayTextID` still resolves to a stand-in

**Generated state:** `project_state DisplayTextID` reports the translated body
check-only; `label_status --callers DisplayTextID` reports the linked provider
in `home_stubs.asm` and the `TryDoWildEncounter` caller. The stand-in returns
without displaying `_RepelWoreOffText`.

**Current behavior:** Repel counters decrement and suppress encounters, but the
last-step message is absent. Do not special-case the text in
`wild_encounters.asm`; overworld-events Stage 2 owns linking the real
`DisplayTextID` closure and retiring the stub.

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
- **Snorlax encounters:** Poké Flute sets the Route 12/16 fight events, but the
  map scripts that consume them belong to overworld-events.
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
