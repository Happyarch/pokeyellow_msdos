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

- [x] **Stage 5 — `UseItem_`/`ItemUsePtrTable` dispatcher + context guards +
  medicine family (first playable value).** DONE 2026-07-12. Landed in the
  path-mirror file `src/engine/items/item_effects.asm` (not a separate
  `item_use.asm` — `lint_pret_labels` requires the pret source's mirror), with
  the unported families as ret-stubs in `src/engine/items/item_use_stubs.asm`.
  Messages are generated (`tools/gen_item_text.py` → `assets/item_text.inc`),
  as are `VitaminStats` / `UsableItems_CloseMenu` / `UsableItems_PartyMenu`
  (`gen_items.py`). Verified headlessly by the new `DEBUG_ITEMUSE` autokey
  scenario (see below). Four documented DEVIATIONs: no animated `UpdateHPBar2`
  (the final bar is redrawn, and `wHPBarHPDifference` — what PotionText prints —
  is computed directly), `PrintText_Overworld`'s window collapse,
  `RunDefaultPaletteCommand` (TODO-HW Phase 5), and predef → direct call.
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
    DONE, headlessly and repeatably, via **`make DEBUG_ITEMUSE=1
    AUTOKEY_DUMP_FRAME=<n>`** (a scripted-joypad build: seeded party with mon 1
    knocked to 1 HP, then START → ITEM → POTION → USE → mon 1, then ANTIDOTE →
    USE → mon 1). Frame 380 shows "SNORLAX / recovered by 20!" with the party
    HP at 21/362; frame 660 shows "It won't have any effect." for the Antidote;
    frame 760 shows the bag list now headed by ANTIDOTE ×3 — the qty-1 POTION
    was consumed by `RemoveUsedItem`, the no-effect Antidote was not.
- [x] **Stage 6 — `ItemUseBall` (catching).** The Gen-1 catch algorithm +
  `ThrowBallAtTrainerMon` refusal + party/box add on success.
  DONE. Verified headlessly with **`make DEBUG_ITEMBALL=1 [ITEMBALL_ID=…]`** (seeds
  `wIsInBattle=1` + the wild PIDGEY of `RunBattleTest`, drops the party to 5 so the
  capture takes the `AddPartyMon` path, and drives one throw → `DUMP.BIN`).
  Master Ball: `wCapturedMonSpecies`=$24, party 5→6 with PIDGEY in slot 6 and its
  catch-rate byte (**struct offset 7** — the Gen-2 held-item slot) intact at $FF,
  Master Ball 99→98, `wBoxCount` still 0, `wPokedexOwned`/`Seen` bit 15 (dex #016)
  set, the new-species Pokédex entry shown. Poké Ball on a full-HP L13 PIDGEY:
  `wPokeBallAnimData`=$20 (0 shakes), `wCapturedMonSpecies`=0, party stays 5, enemy
  HP/status restored by the `LoadEnemyMonData` round-trip, ball still consumed.
  The "Index #000 Post-Capture" bug-ledger row is tagged `BUG(critical)` at the
  dex-flag site (dex 0 → `dec a` → bit 255 → OOB past `wPokedexOwned`).
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
- [x] **Stage 7 — `ItemUseTMHM` (teaching).** Link `tms.asm` + `tmhm.asm` out
  of `ITEMS_CHECK_SRCS` (`CanLearnTM`, `TMToMove`, `CheckIfMoveIsKnown` — the
  latter's `_AlreadyKnowsText` extern is commented out; generate that text
  now). "Booted up a TM/HM" + "teach X?" prompts (generated), party select,
  compatibility refusal, hand off to the complete `LearnMove` UI, consume TM /
  keep HM (`IsItemHM` exists).
  DONE 2026-07-12. Verified headlessly (`DEBUG_ITEMTM`): TM06 → SNORLAX writes
  TOXIC into the free move slot with base PP 10 and drops the bag 16→15; HM03
  teaches SURF and is *not* consumed; TM02 (Razor Wind) → `CanLearnTM` = 0, so
  the refusal branch is taken. Two bugs fell out of it, both pre-existing and
  neither in the TM/HM code: `PrintBattleText` staged a fixed **80** bytes into
  `NPC_DIALOG_BUF`, truncating the 118-byte `TryingToLearnText` so
  `TextCommandProcessor` walked off the buffer (page fault) — it now copies
  `NPC_DIALOG_LEN` and `gen_battle_text.py` pads the data tail so the last
  label's copy stays in bounds; and `DEBUG_SEED_PARTY` gives SNORLAX four HM
  moves (FLY/CUT/SURF/STRENGTH), which `LearnMove` correctly refuses to delete
  forever — the harness now frees three move slots on the target mon.
  NOT exercised live: the "no" answer to the teach prompt
  (`wActionResultOrTookBattleTurn = 2`) — a 3-instruction path, and the autokey
  driver only presses A.

  Follow-up (own commit): `TextCommandProcessor` reads its stream EBP-relative,
  so every flat `.data` stream must be staged into `NPC_DIALOG_BUF` first — that
  staging is what needed a length pret never had to know. pret reads the stream
  in place. Making TCP take a linear pointer deletes all seven staging copies
  (and `iu_print_text`) and retires this bug class.

  **ATTEMPTED 2026-07-12 AND REVERTED — do not redo it blind.** The change was:
  TCP's stream fetches become `[esi]`; `.cmd_start` passes `esi` straight to
  `PlaceString` and takes back a linear `edx`; `.cmd_far` reads a 32-bit linear
  `dd` (the port's *only* TX_FAR producers — `text_script.asm`,
  `trainer_engine.asm` — already emit `dd`, and both generators flatten
  `text_far` away, so no generated stream reaches `.cmd_far` at all); every
  caller passes linear (`lea esi,[ebp+…]` for WRAM-composed streams); the five
  pure flat→WRAM staging copies are deleted. It **assembles, lints clean, and
  passes `make fidelity` 6/6** — but it regresses live text: the `DEBUG_ITEMTM`
  flow reaches the party menu, then parks on an overworld dialog box rendering
  `REDRED` (two `<PLAYER>` expansions) instead of the TM message, and never
  returns. The goldens do not cover streamed text, so they do not catch it.
  Root cause not found; next attempt should bisect the caller conversions one
  file at a time against `DEBUG_ITEMTM` (which *is* a good oracle here) rather
  than converting all of them at once.
  - Verify: seeded bag TM teaches a compatible move, refuses an incompatible
    mon, HM not consumed.
- [x] **Stage 8 — `ItemUseEvoStone`.** Ported with `Func_d85d` (stone-applicability
  scan) reading the flat `EvosMovesPointerTable` blob in place (DEVIATION 12 — pret
  `FarCopyData`s it to `wEvoDataBuffer`; the port has no bank to copy from). Stone is
  consumed on success, "It won't have any effect." on failure. Harness
  `DEBUG_ITEMSTONE` (`ITEMSTONE_ID` / `ITEMSTONE_SPECIES`): VULPIX + FIRE_STONE →
  NINETALES (species + species-list + FIRE/FIRE types, bag 16→15, item-used flag 1);
  SNORLAX + FIRE_STONE → no effect (species unchanged, stone kept, flag 0).

  **Getting there fixed four real bugs in the (previously never-executed) evolution
  path** — level-up evolution via Rare Candy was equally dead:
  1. `TryEvolvingMon` ended in `ret` instead of falling through into
     `EvolutionAfterBattle` (pret's two labels are contiguous), so every caller just
     set the flag and evolved nothing.
  2. Both flag sites called `FlagActionPredef`, whose first act is
     `GetPredefRegisters` — it overwrote ESI/EBX from the stale `wPredefHL`/`BC`
     slots. Now `FlagAction` directly (the convention `experience.asm` already
     documents). The pokédex seen/owned sites had the same bug, writing flags at a
     garbage address.
  3. The party cursor started at `wPartySpecies`, but the loop's first act is
     `inc` — pret starts at `wPartyCount`, so every mon was tested against the *next*
     mon's evolution data.
  4. `.checkItemEvo` used `inc esi` between the `wIsInBattle` test and its `jnz`,
     clobbering ZF (pret's `ld a, [hli]` there is flag-neutral) — so every item
     evolution was skipped. Now `lea`.
  Plus one forced deviation: the `BaseStats → wMonHeader` copy went through
  `CopyData`, which reads its source EBP-relative; `BaseStats` is a flat `.data`
  table, so it read megabytes past the GB allocation. Copies flat→GB directly now,
  as `GetMonHeader` already does.
- [~] **Stage 9 — Repel family DONE; Escape Rope BLOCKED.**
  `ItemUseRepel`/`SuperRepel`/`MaxRepel` → `ItemUseRepelCommon` +
  `PrintItemUseTextAndRemoveItem` are in and verified (`DEBUG_ITEMSTONE` with
  `ITEMSTONE_ID=0x1E/0x38/0x39`: `wRepelRemainingSteps` = 100/200/250, item
  consumed each time, `wActionResultOrTookBattleTurn`=1). These are the
  **first-ever writers of `wRepelRemainingSteps`**, so `TryDoWildEncounter`'s
  `.lastRepelStep` branch is now live — but the branch calls `DisplayTextID`,
  still a ret-stub owned by the script-engine plan, so the "REPEL's effect wore
  off." message does not display. Step counting and encounter suppression work.
  Two known gaps, both outside the item layer:
    - the bag menu never loads the item name into `wStringBuffer`
      (pret does `GetItemName` + `CopyToStringBuffer` before `UseItem`), so
      `ItemUseText00`'s TX_RAM prints stale bytes for the item name;
    - `ItemUseEscapeRope` is **blocked**: it only sets `BIT_ESCAPE_WARP`/
      `BIT_FLY_WARP` in `wStatusFlags6`, and the consumer that acts on them —
      `HandleFlyWarpOrDungeonWarp` — is **missing** in the port (overworld plan).
      Translating the effect now would give an item that consumes itself and does
      nothing. Sequence it after the overworld plan lands the special-warp handler.

  Original scope: `ItemUseRepel`/`Super`/`Max`
  → `ItemUseRepelCommon` writing `wRepelRemainingSteps` (first-ever writer —
  the `wild_encounters.asm` `.lastRepelStep` branch and its `DisplayTextID`
  call go live; coordinate with the overworld plan's `DisplayTextID` destub,
  or route the wore-off text through the port's text path if that lands
  first). `ItemUseEscapeRope`: dungeon check, warp to last-heal map (blackout
  warp machinery exists in `black_out.asm`).
- [x] **Stage 10 — battle items.** `ItemUseXAccuracy` / `ItemUseGuardSpec` /
  `ItemUseDireHit` / `ItemUseXStat` / `ItemUsePokeDoll` translated; five stubs
  retired. Verified with `DEBUG_ITEMSTONE ITEMSTONE_INBATTLE=1` (seeds
  `wIsInBattle`/`wPlayerMonNumber`/neutral stat stages, then dispatches `UseItem`
  by `wCurItem`): X_ACCURACY $2E → `wPlayerBattleStatus2` bit 0; GUARD_SPEC $37 →
  bit 1 (Mist); DIRE_HIT $3A → bit 2 (Focus Energy); POKE_DOLL $33 →
  `wEscapedFromBattle`=1; X_ATTACK $41 → `wPlayerMonAttackMod` 7→8 via
  `StatModifierUpEffect`. All five consume the item with
  `wActionResultOrTookBattleTurn`=1; out of battle X_ATTACK is refused with
  result=2 and the item kept. `ModifyPikachuHappiness` is still a ret-stub
  (battle_exp_stubs.asm) — the calls are placed faithfully so its destub is a
  one-file change. Poké Doll's Ghost-Marowak special case stays in the battle
  engine (scripted battles), as in pret.

  Caveat: the harness fakes battle state from the overworld — these items are not
  yet reachable from a real battle's ITEM menu (battle-plan work), so the *UI*
  path is unexercised.

  Original scope: `ItemUseXAccuracy`/`ItemUseXStat`/
  `ItemUseDireHit`/`ItemUseGuardSpec`/`ItemUsePokeDoll`: `wIsInBattle` gate +
  `wPlayerBattleStatus2` bit sets / `StatModifierUpEffect` calls (all exist in
  the battle engine). Small; sequence after the battle plan's ITEM menu so
  they're reachable. Poké Doll's Ghost-Marowak skip rides with the battle
  plan's scripted-battle work (note only).
- [ ] **Stage 11 — key items + rods** (independent sub-checkboxes; do
  opportunistically):
  - [x] Bicycle: mount/dismount via `wWalkBikeSurfState`, with
    `IsBikeRidingAllowed` + `NoCyclingAllowedHere` and both bicycle texts.
    Verified (`DEBUG_ITEMSTONE ITEMSTONE_ID=0x06`, Pallet Town): state 0 → 1 and
    the key item is NOT consumed (bag stays 16, slot 0 still BICYCLE). Also landed
    `ItemUseReloadOverworldData` (`LoadCurrentMapView` + `UpdateSprites`), which the
    Escape Rope / Poké Flute paths also need.
  - [x] Coin Case ($45): prints `CoinCaseNumCoinsText` (TX_BCD from `wPlayerCoins`),
    not consumed, `wActionResultOrTookBattleTurn`=1. Verified.
  - [x] Oak's Parcel ($46): → `ItemUseNotYoursToUse`, result=0, not consumed. Verified.
  - [x] Pokédex ($09): → `ShowPokedexMenu` (one-line `jmp`; pret `predef_jump`). Not
    harness-verified — the dex is an interactive screen and the A-only autokey cannot
    exit it (needs B). The dex screen itself has its own coverage (`DEBUG_G1`).
  - [x] Poké Flute. In-battle: wakes the whole player party (+ the enemy party in a
    trainer battle), clears the active mons' Sleep, then plays
    `Music_PokeFluteInBattle` and waits it out. Overworld: Route 12 / Route 16
    coordinate + event checks that set `EVENT_FIGHT_ROUTE{12,16}_SNORLAX`; the flute
    jingle + map-music restore is the `text_asm` tail of `PlayedFluteHadEffectText`,
    translated as code (`iu_played_flute_had_effect`) with the generator emitting the
    printable prefix (new `gen_battle_text.ASM_TAIL_OK` opt-in).
    Verified (`ITEMSTONE_ID=0x49`): out of battle in Pallet Town → no-effect text, key
    item not consumed; in battle with a seeded sleeping mon → `wPartyMon1Status`
    3 → 0 and the "had effect" branch taken (jingle played, wait loop exited).
    Two divergences, both recorded in `docs/items_blockers.md`:
      - **PEWTER_POKECENTER sleeping-Pikachu branch is DEFERRED** —
        `IsPikachuRightNextToPlayer` / `PlaySpecificPikachuEmotion` are not ported. It
        falls into the no-effect message (what pret does on every other map).
      - `LoadScreenTilesFromBuffer2` is not called: the port has no Buffer2 save, by
        the same reasoning `home/start_menu.asm` already documents (menus are a window
        overlay, so the screen underneath was never destroyed).
    The Snorlax that reads the fight event is still a map script (overworld plan), so
    playing the flute on the right tile sets the flag but no Snorlax appears yet.
  - [x] Town Map: `ItemUseTownMap` → `DisplayTownMap`; `town_map.asm` moved into
    `ITEMS_SRCS` and every dangling dep resolved — `FindWildLocationsOfMon` +
    `CheckMapForMon` ported (Nest screen), `BirdSprite` generated from
    `gfx/sprites/bird.2bpp` (Fly screen), `RunPaletteCommand` /
    `RunDefaultPaletteCommand` wired (ret-stubs until Phase 5).
    Port deviations, all commented in-file: the flat-canvas entry (with a
    save/restore of the CALLER's view pointer + scroll + stride, so returning to
    the bag doesn't composite it over block 0), `TOWNMAP_OAM_SINK` (pret discards
    two `ld [hli]` writes through a ROM pointer; a flat host label can't), and
    `tm_publish_oam` (publishes shadow OAM via `PrepareStaticOAM`, and applies the
    GB's own OBJ hide rule — Y = 0 or Y >= 160 — which the 200-row canvas otherwise
    exposes as ghost sprites at row 144).
    `wShadowOAMBackup` had to be RELOCATED (0xC508 → 0xF500): the port's 40×25
    `W_TILEMAP` spans 0xC3A0–0xC787 and swallows pret's address.
  - [ ] Itemfinder: add `itemfinder.asm` to the Makefile (currently orphaned —
    in no SRCS list at all), `ItemUseItemfinder` proximity check + SFX;
    needs overworld hidden-object data (interface). BLOCKED — `docs/items_blockers.md` B5.
  - [ ] Fishing rods: `ItemUseOldRod`/`GoodRod`/`SuperRod` + `FishingInit`.
    **BLOCKED — `docs/items_blockers.md` B7.** Measured: linking `super_rod.asm`
    (`ReadSuperRodData`) + `player_animations.asm` (`FishingAnim`) leaves exactly one
    undefined symbol, `EmotionBubble`, whose file (`trainer_engine.asm`) then wants
    `SaveTrainerName` / `JessieJamesPic` / `TrainerNameText` / `WriteOAMBlock`. All
    trainer-engine work; the item side is a ~60-line translation waiting on it.
  - [x] Card Key ($30). Faithfully **dead**, as on hardware: pret reads
    `[GetTileAndCoordsInFrontOfPlayer]` — the routine's own first opcode byte ($CD) —
    where it meant `[wTileInFrontOfPlayer]`, so no door tile ever matches and it always
    falls to `ItemUseNotTime`; the three `CardKeyTable`s (pret: "unused") are
    unreachable, and `wUnusedCardKeyGateID` / `BIT_UNUSED_CARD_KEY` are, in pret's own
    words, "never checked". Tagged `BUG(2)`: level 0/1 hardcodes the byte the GB reads
    (reading the port's own x86 opcode would be meaningless); level 2 reads the intended
    tile, which only changes the message. Verified (`ITEMSTONE_ID=0x30`): result 0,
    gate id 0, flag clear, key item not consumed.
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
