# Current Plan: Items Layer — make USE actually work

Status: Stages 1–4 (inventory, static data, effect cores, money/TOSS) are
**complete** — compressed record below. The remaining work is everything after
"the player picks USE": the `UseItem_`/`ItemUsePtrTable` dispatcher and the
per-family `ItemUse*` handlers. Rewritten 2026-07-12 from the engine-gap
survey (ground truth: today USE in the bag is a literal `jmp ItemMenuLoop`
no-op at `src/engine/menus/start_sub_menus.asm:473-478`).

Archive to `docs/plans/items.md` when complete.

## Conventions (same as before, two loud reminders)

- Faithful pret translation, pret label names, sym-pinned WRAM addresses,
  native ELF32 + `gcc -m32` validation for pure-math routines, faithdiff +
  lint_pret_labels per pret-labeled routine, stubs only in `*_stubs.asm`.
- **TEXT RULE — this plan is text-heavy, do not slip:** every refusal/usage
  string ("OAK: this isn't the time to use that!", "It won't have any
  effect.", "<MON> knows <MOVE>!", ball-throw messages, "No! There's no
  cure!", …) is Tier-1 DATA → a `gen_*.py` generator (extend `gen_items.py`
  or a sibling modeled on `gen_battle_text.py`) → `assets/*.inc` → `%include`.
  Never `db 0x…` charmap hex in a `.asm`. Watch for pret's `text_far` +
  `text_asm` composites (the `gen_battle_text.py` truncation bug from the
  battle audit) — hand-author those as Tier-2 code over generated fragments.
- **Gen-2 struct rule:** any code that adds/copies a mon (the catch path!)
  carries `MON_CATCH_RATE` (struct offset 7) through verbatim.

## Completed (Stages 1–4, compressed record)

- [x] **Stage 1 — inventory bookkeeping.** `src/engine/items/inventory.asm`:
  `AddItemToInventory_`/`RemoveItemFromInventory_` (stacking, 99-cap overflow,
  shift-up removal, bag-vs-PC capacity). Native-validated; linked (`ITEMS_SRCS`).
- [x] **Stage 2 — static data.** `tools/gen_items.py` → `assets/items.inc`:
  `ItemNames`, `ItemPrices` (BCD), `KeyItemFlags`, `MartInventories` +
  `MartPointers`, `TechnicalMachinePrices`. Exposed via `src/data/item_data.asm`.
- [x] **Stage 3 — effect cores (no UI).** `src/engine/items/item_effects.asm`:
  `ApplyHealingItem`, `CureStatusAilment`, `RestorePPAmount` (**faithful
  Max-Ether PP-Up-bit bug preserved**), `WakeUpEntireParty`, `ApplyVitamin`
  (+2560 stat-exp big-endian MSB, 25600 cap), `RareCandyLevelUp` (level+exp+
  CalcStats+HP delta). Native-validated (38 checks); linked. Deferred from this
  stage: `Func_d85d` evo-stone applicability (→ Stage 8).
- [x] **Stage 4 — money/TOSS glue.** `SubtractAmountPaidFromMoney_`/
  `AddAmountSoldToMoney_` (BCD), `GetItemPrice`/`GetMachinePrice`; TOSS wired
  live in the bag (USE/TOSS sub-menu, key-item/HM guard, qty chooser, YES/NO,
  `RemoveItemFromInventory_`). Harnesses: `DEBUG_BAGMENU_LIVE` (interactive),
  `DEBUG_BAGMENU`/`DEBUG_BAGMENU_CONFIRM` (FRAME.BIN). Native-validated (14
  checks); linked.

## Scope boundaries (cross-plan interfaces)

- **Mart transaction body** (`DisplayPokemartDialogue_`, priced list menu,
  `subtract_paid_money.asm` linking) — **overworld-events plan**. Our price/
  mart data and money math serve it.
- **Field-move EXECUTION** (Cut/Surf/Fly/Strength/Flash… from the party menu)
  — **overworld-events plan**. `ItemUseSurfboard` here only guards + hands off.
- **In-battle ITEM menu chrome** (`BattleItemMenu` destub) — **battle plan**.
  It calls our `UseItem_` with battle context; we own everything from
  `UseItem_` down, including `ItemUseBall`.
- **Hidden-object data** (Itemfinder's target list) — overworld-events plan
  owns `gen_hidden_events.py`; Stage 11 consumes it.

## Stages

- [ ] **Stage 5 — `UseItem_`/`ItemUsePtrTable` dispatcher + context guards +
  medicine family (first playable value).**
  - `src/engine/items/item_use.asm`: `UseItem_` (init
    `wActionResultOrTookBattleTurn=1`; `cp HM01 → jp nc ItemUseTMHM` — stub to
    Stage 7; else index `ItemUsePtrTable`). The table is a **Tier-2
    hand-written flat `dd` table** in the `.asm` (pointer tables are code, not
    generated data — two-tier rule), one entry per item id 1..68, initially
    pointing unported families at per-family stubs in
    `src/engine/items/item_use_stubs.asm` (each with pret ref + retirement
    TODO per stub conventions).
  - Context-guard primitives: `ItemUseNotTime` ("OAK: this isn't the time to
    use that!" — generated text), `ItemUseNotYoursToUse`, `UnusableItem`, and
    the `wIsInBattle` checks each handler opens with. Also the common tails
    `ItemUseFailed`/`GotOutOfSafariZone`-style resets pret shares.
  - `ItemUseMedicine`: party-mon select (reuse the live `DisplayPartyMenu`
    with `USE_ITEM_PARTY_MENU`), branch potion/status/revive/PP/vitamin/Rare
    Candy onto the **already-linked cores**, refusal paths ("It won't have any
    effect."), consumption via `RemoveItemFromInventory_`, post-vitamin
    `GetMonHeader`+`CalcStats` recalc, Rare Candy's move-learn hand-off to
    `LearnMove` (already complete) and evolution hand-off (`EvolutionAfterBattle`
    family exists — check the out-of-battle wrapper pret uses).
  - Wire the three call sites: bag USE (`start_sub_menus.asm:473-478` stub +
    the Bicycle `.useItem_closeMenu` stub — Bicycle body itself waits for
    Stage 11, route it through the dispatcher now), party-menu item-on-mon
    path, and export the entry the battle plan's `BattleItemMenu` will call.
  - Verify: `DEBUG_BAGMENU_LIVE` — Potion heals a damaged seeded mon, Antidote
    refuses on a healthy mon, item count decrements, key items don't consume.
- [ ] **Stage 6 — `ItemUseBall` (catching).** The Gen-1 catch algorithm +
  `ThrowBallAtTrainerMon` refusal + party/box add on success.
  - Pure-math core (catch-rate RNG chain, ball factors, wobble count formula)
    → **native ELF32 validation** against known vectors before wiring.
  - Out-of-battle guard (`ItemUseNotTime`) is testable from the bag
    immediately; in-battle throw needs the battle plan's `BattleItemMenu`
    (interface). Safari branch decrements `wNumSafariBalls` (Safari mechanics
    beyond that are the battle plan's).
  - On capture: `wCapturedMonSpecies`, pokédex set, nickname prompt (existing
    naming UI), `_AddPartyMon` (exists) or box add — **offset 7 / catch-rate
    byte verbatim** (Gen-2 rule); ball consumed.
  - Tag the "Index #000 Post-Capture" bug-ledger row (`BUG(critical)` +
    `BUG_FIX_LEVEL` block) at the capture-to-party site — see
    `docs/bug_categorization.md` battle table.
  - Verify: live wild battle (needs battle ITEM menu) or a `DEBUG_*` harness
    that seeds `wIsInBattle=1` + enemy data and drives one throw; goldencheck
    unaffected.
- [ ] **Stage 7 — `ItemUseTMHM` (teaching).** Link `tms.asm` + `tmhm.asm` out
  of `ITEMS_CHECK_SRCS` (`CanLearnTM`, `TMToMove`, `CheckIfMoveIsKnown` — the
  latter's `_AlreadyKnowsText` extern is commented out; generate that text
  now). "Booted up a TM/HM" + "teach X?" prompts (generated), party select,
  compatibility refusal, hand off to the complete `LearnMove` UI, consume TM /
  keep HM (`IsItemHM` exists).
  - Verify: seeded bag TM teaches a compatible move, refuses an incompatible
    mon, HM not consumed.
- [ ] **Stage 8 — `ItemUseEvoStone`.** Port `Func_d85d` (stone-applicability
  scan) against the port's **flat `EvosMovesPointerTable`** (inline .data
  table — never `call` it), trigger the evolution path used by level-up
  evolution, consume on success / "It won't have any effect." on failure.
- [ ] **Stage 9 — Repel family + Escape Rope.** `ItemUseRepel`/`Super`/`Max`
  → `ItemUseRepelCommon` writing `wRepelRemainingSteps` (first-ever writer —
  the `wild_encounters.asm` `.lastRepelStep` branch and its `DisplayTextID`
  call go live; coordinate with the overworld plan's `DisplayTextID` destub,
  or route the wore-off text through the port's text path if that lands
  first). `ItemUseEscapeRope`: dungeon check, warp to last-heal map (blackout
  warp machinery exists in `black_out.asm`).
- [ ] **Stage 10 — battle items.** `ItemUseXAccuracy`/`ItemUseXStat`/
  `ItemUseDireHit`/`ItemUseGuardSpec`/`ItemUsePokeDoll`: `wIsInBattle` gate +
  `wPlayerBattleStatus2` bit sets / `StatModifierUpEffect` calls (all exist in
  the battle engine). Small; sequence after the battle plan's ITEM menu so
  they're reachable. Poké Doll's Ghost-Marowak skip rides with the battle
  plan's scripted-battle work (note only).
- [ ] **Stage 11 — key items + rods** (independent sub-checkboxes; do
  opportunistically):
  - [ ] Bicycle: real mount/dismount (`wWalkBikeSurfState` toggle + walk-speed
    plumbing; replace the `.useItem_closeMenu` stub and the "no cycling here"
    guard text).
  - [ ] Poké Flute: in-battle wake (calls the linked `WakeUpEntireParty` core /
    enemy wake) + overworld Snorlax hook (event-coupled; the Snorlax script is
    the overworld plan's — leave the map-side TODO there).
  - [ ] Town Map: link `town_map.asm` out of `ITEMS_CHECK_SRCS` (it's coded +
    data generated; "intentionally dangling" per its port note — resolve the
    palette/video deps that kept it dangling).
  - [ ] Itemfinder: add `itemfinder.asm` to the Makefile (currently orphaned —
    in no SRCS list at all), `ItemUseItemfinder` proximity check + SFX;
    needs overworld hidden-object data (interface).
  - [ ] Fishing rods: `ItemUseOldRod`/`GoodRod`/`SuperRod` + `FishingInit`;
    link `super_rod.asm` (check-only, data already generated). Rod-cast
    facing-water check + encounter start couple to the overworld/battle
    boundary — flag both plans when wiring.
  - [ ] Card Key / Coin Case / Oak's Parcel: thin, event-coupled; Card Key
    door needs the overworld hidden-object/door path (interface).
  - [ ] Surfboard: guard + refusal only; execution = overworld Surf.
- [ ] **Stage 12 — stub retirement sweep.** `item_use_stubs.asm` empty,
  `label_status --callers` on each retired stub, `update_label_db`,
  `lint_pret_labels` 0, `ITEMS_CHECK_SRCS` reduced to whatever genuinely
  remains, ledger rows in `docs/bug_categorization.md` re-checked ("ws# #m#",
  "Item slot $FF" become tag-able once the dispatcher exists — tag them).

## Verification (every stage)

`make -C dos_port` + `make check` green; `faithdiff <Label>` per pret-labeled
routine + justify in the commit message; `lint_pret_labels` exit 0;
`update_label_db` after stub add/retire; FRAME.BIN harnesses
(`DEBUG_BAGMENU*`) for menu-visible changes; `make fidelity` goldens
unaffected; native ELF32 tests for the pure-math cores (catch algorithm
especially). Build reminder: live testing needs
`make SKIP_TITLE=1 DEBUG_SEED_PARTY=1` (empty-party wild battles crash in
LoadMonBackPic).
