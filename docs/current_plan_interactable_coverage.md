# Current Plan: Interactable Coverage — define every object/item/event tile in one sweep

> **Purpose.** The user keeps walking the map to find out whether an object's text has
> been ported, even when its script was wired (Rival's sister not giving the map, the
> `...` placeholders on TV interactions, etc.). This plan makes that check **mechanical
> and scriptable** and lays out the single sweep that wires the whole overworld's
> interactable set. It is written from measurements, not memory.

## Gate

`dos_port/tools/static_gate` runs both `lint_pret_labels` modes plus `test_label_db.py`
and `validate_scenarios.py`; `.githooks/pre-commit` invokes it whenever anything under
`dos_port/` is staged. **`lint_pret_labels` must exit 0.** Every generator change below
must keep the static gate green, and any change that can move a pixel or a WRAM byte
must also run `make -C dos_port fidelity` (core) or `fidelity-full`.

**Re-measure, don't quote.** Numbers in this plan are measurements taken on the
current tree by `dos_port/tools/overworld_inventory.py`. They drift; re-run it.

## The inventory tool

`dos_port/tools/overworld_inventory.py` is a **read-only survey** that reads the pret
source (the spec) plus the port's script layer and classifies every interactable slot.
It needs no build. (`gen_npc_dialogs.py` itself needs `assets/pret_ram.inc` for the
`wOaksLabCurScript` anchor, which is generated from the reference ROM's `pokeyellow.sym`
by `gen_pret_ram.py`; the inventory sidesteps that by reading pret source directly.)

```
python3 dos_port/tools/overworld_inventory.py
```

Writes (under `dos_port/overworld/`):

- `overworld_inventory.json` — every map's warps, object_events, bg_events (signs), dialog
  slots, hidden items, hidden coins, hidden events, wired flag.
- `overworld_inventory.md` — aggregate, per-map breakdown, seen item balls, hidden items
  & coins, hidden events, and the problem-slots table.
- `script_overrides_candidates.py` — emitted only if there are still `PORTED_SCRIPT_UNWIRED`
  slots (auto-discovery normally empties them, so the file is usually absent).

Why this exists: the generator (`gen_npc_dialogs.py`) already produces a per-map dialog
table and emits a `...` byte stream for any slot it cannot resolve to static text or a
`SCRIPT_OVERRIDES` entry. The reason a slot renders `...` is almost never "the text isn't
there" — it is "the generator doesn't know a ported routine exists." The inventory makes
that one question answerable for all 1,251 slots at once.

## What was shipped in the generator sweep

`dos_port/tools/generators/gen_npc_dialogs.py` now:

1. **Auto-wires a ported text_asm script.** A dialog slot whose pret `text_asm` label is a
   `global` in `dos_port/src/scripts/<Map>.asm` (the port keeps pret's label verbatim) is
   emitted as a `SCRIPT_SENTINEL` entry that CALLs the ported routine, instead of the `...`
   placeholder. This replaced the need to hand-keep a ~400-row `SCRIPT_OVERRIDES` identity
   list — it is derived from the port source at generation time. Gyms (leaders + trainers),
   the Elite Four, story NPCs, the Blues House Daisy give-map flow and the Reds House Mom/+
   TV interactions all resolve this way now.
2. **Fixes the `item_id == 0` misclassification.** An `object_event` flagged ITEM with item
   id 0 (Blues House Daisy sitting + Town Map) is now treated as a plain text slot, so it
   routes through static/script resolution rather than the always-`...` item branch.
3. **Resolves shared subsystem far text.** Labels like `BoulderText`, `MartSignText`,
   `PokeCenterSignText`, `ExclamationText`, `GroundRoseText` have their far bodies in
   `data/text/text_*.asm` (ported in `dos_port/src/home/overworld_text.asm`), not in a
   per-map text file. The generator now falls back to a global far-text index, so city signs
   and boulders emit real text instead of `...`.

**Post-fix bucket totals (measured by `dos_port/tools/overworld_inventory.py`):**

| Bucket | Slots | Meaning |
| --- | --- | --- |
| `PORTED_SCRIPT` | **498** | auto-wired via a `SCRIPT (text_asm)` CALL (457 distinct target globals, 0 dangling). |
| `STATIC_TEXT` | 504 | real bytes from the map or shared far-text index. Done. |
| `TRAINER` | 112 | trainer talk routed through the shared `TrainerTalkHook` (TRAINER TALK rows). Done. |
| `TRAINER_STATIC` | 1 | trainer pre-battle text is static text_far. Done. |
| `TRAINER_STUB` | 1 | no static text + no ported routine (`MtMoonB2FSuperNerdText`). |
| `ITEM_MARKED` | 108 | real item balls (id > 0). Separate pickup system. |
| `STUB_PLACEHOLDER` | 27 | genuinely dynamic/unported text_asm (mart clerks, Jessie/James, gate guards, item-flow helpers). |

The **27** `STUB_PLACEHOLDER` are the remaining honest work: mart clerks need the shared
`DisplayPokemartDialogue_` route, and the story NPCs (Jessie/James, Saffron gate guards)
need their text_asm ported. These are deliberate follow-ups, not the `...`-on-a-wired-script
problem the survey was built to surface.

Also: 203 bg_events (signs, mostly `STATIC_TEXT`), 54 hidden items, 12 hidden coins,
200 hidden events, 806 warps, 941 object_events, 217 maps with slots, 17 wired maps.

## The sweep — current status

### Step 1 — SHIPPED: auto-wire ported text_asm scripts

`gen_npc_dialogs.py` auto-discovers a slot whose pret `text_asm` label is a `global` in the
map's `dos_port/src/scripts/<Map>.asm` and emits a `SCRIPT_SENTINEL` CALL entry. 457
distinct targets are now wired and every one is a declared `global` in `dos_port/src` (no
dangling externs). The hand-maintained `SCRIPT_OVERRIDES` dict is retained only for the
explicit multi-map/off-map routings (link receptionists, nurses, Chansey, trades).

Guardrails honored: the auto-discovery only fires for labels in the map's own script file
(never a map-level `_Script`), and only when the pret body is a genuine runtime routine
(`text_asm` or a `script_*` macro) — static `text_far` wrappers AND empty alias bodies
(`text_end`) keep emitting real bytes / staying a stub. The map-label resolution already
exists via `gen_map_headers`.

**Reconciliation (measured after the guardrail fix).** The auto-discovery guard tests the
pret body kind first: a pret `text_asm` routine (even one containing nested `text_far`
sub-labels, e.g. `CeladonGymErikaText`'s `CheckEvent EVENT_BEAT_ERIKA` gate) is NEVER
inlined as a static byte stream — it emits a `SCRIPT` CALL so the battle/reward state
machine runs. Conversely an empty-alias `text_end` body (e.g. `PokemonTower7FJessieJamesText`)
is NOT auto-wired; it stays in the 27 `STUB_PLACEHOLDER`. The inventory's `classify_text_pointer`
was aligned to the same rules, and its `TRAINER_HOOK` detection was tightened to the strict
`ld hl, <Map>TrainerHeaderN / call TalkToTrainer` + `jr <Map>TalkToTrainer` spellings the
generator honours — so non-standard hooks (e.g. Power Plant's `jr PowerPlantInitBattleScript`)
classify as `TEXT_ASM` (→ `PORTED_SCRIPT`) instead of `TRAINER`. With both tools measuring
the same resolved table, every remaining `PORTED_SCRIPT`/`TRAINER` label maps to a real
emitted `SCRIPT`/`TRAINER TALK`/shared-handler row (pokecenter nurse/Chansey/link slots are
wired through the shared `PokecenterNurseScript`/`CableClubReceptionistScript`/`PokecenterChanseyText`
handlers, so the port-local names differ but are still ported).

### Step 2 — SHIPPED: fix the `item_id == 0` misclassification

The generator treats a 7-arg `object_event` with `item_id == 0` as a plain text slot (the
Blues House Daisy + Town Map case), routing it through static/script resolution instead of
the always-`...` item branch. The object data's ITEM flag is unchanged (that is game
semantics); only the dialog classification changed.

### Step 2b — SHIPPED: global shared-far-text fallback

`BoulderText`, `MartSignText`, `PokeCenterSignText`, `ExclamationText`, `GroundRoseText`
(and other shared `data/text/*.asm` labels ported in `home/overworld_text.asm`) were
unresolvable from a per-map `text/<Map>.asm`. The generator now builds a global
far-label→bytes index once and falls back to it, so city signs and boulders emit real text.

### Step 3 — hand-port the 27 `STUB_PLACEHOLDER` slots

These are `text_asm` scripts with no ported routine and no auto-discovery match:

- **Mart clerks** (Viridian, Pewter, Cerulean, Vermilion, Lavender, Celadon 2F/4F/5F,
  Fuchsia, Cinnabar, Saffron, Indigo Plateau Lobby): the port has the clerk text labels in
  `src/data/items/marts.asm` (data) and the transaction loop in
  `src/engine/events/pokemart.asm` (`DisplayPokemartDialogue_`). Wire each clerk's dialog
  slot to route to that handler via a `SCRIPT_OVERRIDES` row (or a shared mart hook), rather
  than the `...` stub.
- **Story NPCs** (Jessie/James in Mt. Moon, Rocket Hideout, Silph Co; Saffron gate guards;
  Pokemon Mansion switches): need their `text_asm` bodies ported (they are state-gated
  battles/conversations).
- **Item-flow helpers** (`PickUpItemText`): a scripted item pickup; the item-ball slots are
  correctly left to the pickup system.

The inventory's "Problem slots" table enumerates each; `src/data/items/marts.asm` is the
natural home for the shared mart-clerk wiring.

### Step 4 — wire the remaining trainer, and note the map-wiring dependency

Only `MtMoonB2FSuperNerdText` remains a pure `TRAINER_STUB`. The reason the other 300+
trainers stopped being stubs once Step 1 is applied is that their ported routines call
`TalkToTrainer` directly (e.g. `CeladonGymErikaText` → `call TalkToTrainer`), so the NPC
talk path enters the trainer battle flow without needing the whole map's `_Script` to be
live. Map-level wiring (`gen_map_script_tables.WIRED_MAPS` + a golden scenario) is still
the path for per-frame map scripts (gym leader re-match gating, map-entry cutscenes), and
the faithfulness-review rule "no scenario, no wire" applies there.

### Step 5 — audit items & event tiles (things that are generated data)

- **Seen item balls** (108): emitted as object_events with `ITEM|id`. The item message
  slot is handled by the pickup system, not the `...` dialog stream, so these are NOT part
  of the `...` problem. Confirm each is reachable and gives the item.
- **Hidden items** (54) / **hidden coins** (12): generated by
  `gen_hidden_item_coords.py` / `gen_hidden_coin_coords.py` into
  `assets/hidden_item_coords.inc` / `hidden_coin_coords.inc`; read by
  `src/engine/items/itemfinder.asm` (`HiddenItemNear`, stride-3 over map_id,y,x). Audit
  that every pret row has a generated counterpart and the entity finds it.
- **Hidden events / event tiles** (200): `gen_hidden_events.py` → `assets/hidden_events.inc`
  with per-map `HiddenEventsFor_<map>` lists; `CheckForHiddenEvent`
  (`src/home/hidden_events.asm`) scans it. Each handler (statues, PCs, switches, slot
  machines, `HiddenItems`, `HiddenCoins`) must be linked; the inventory lists every
  `(map, x, y, handler, arg)` row to walk against `label_status`.
- **bg_events / signs** (203): mostly `STATIC_TEXT`, so already live through the sign
  interaction path (`DoSignInteraction` → `DisplaySignText`). The inventory flags any that
  are `text_asm` (e.g. FuchsiaCity's fossil sign) — those join the `...` sweep.

## Safety and verification

- The inventory is read-only; it never writes to `translation.db` or generated assets.
- Every generator edit must keep `lint_pret_labels` at 0 and, if it changes runtime
  wiring, pass the relevant `make -C dos_port fidelity` scenarios. The generated
  `npc_dialogs/*.inc` are gitignored, so the tracked change is the generator source only.
- **NPC/sign dialog still needs a dialog-bearing scenario** (faithfulness-review skill,
  "Text printers and NPC/sign dialog need `sign_pallet` or a new dialog-bearing
  scenario if `sign_pallet` does not exercise the path"). `sign_pallet` exercises sign
  interaction in Pallet Town only. Auto-wiring 498 NPC talk paths therefore needs a
  strategy, not just the generator rule: add a hand-picked set of dialog scenarios that
  A-press a representative NPC per category (a gym trainer, a mart clerk, a nurse, a story
  NPC such as Daisy/TV). The inventory's per-map breakdown is the pick-list.
- The auto-wired rows are generated Tier-1 data (regenerated from pret by
  `gen_npc_dialogs.py`), so they are not a `mirror`/`relocation` lint concern; what the
  linter checks is that a port symbol borrowing a pret `scripts/` *name* lives in the
  matching `src/scripts/<Map>.asm` (it does, for the auto-discovered routines, since the
  discovery is scoped to that file).
- Post-fix sanity is confirmed: every distinct `SCRIPT (text_asm)` target the generator
  emits is a declared `global` in `dos_port/src` (no dangling extern), and static slots
  (Pallet Town signs + oak, etc.) still emit byte streams unchanged.

## Not in scope

- The cutscene/map-script state machines (they live in the overworld-events /
  script_linking plans and the faithfulness-review "no scenario, no wire" rule).
- Battle logic itself (battle_completion owns trainer-battle activation/exit).
- The Golden run of every new wire; that is the natural follow-up once the sweep lands.

## Owner / how to read

This is the interactable-coverage plan. Adjacent owners:
`docs/current_plan_overworld_events.md` (story scripts + interaction services),
`docs/current_plan_script_linking.md` (map script linking),
`docs/current_plan_viridian_parcel.md` (parcel + interactable coverage).
