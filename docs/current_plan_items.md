# Current Plan: Items Layer — finish the remaining USE handlers

> **Gate — the linter is MANDATORY. Rewritten 2026-08-02 against the tooling
> that actually exists; the version this replaces predated `static_gate` and
> told you "nothing runs it for you", which stopped being true on 2026-07-26.**
>
> **What runs automatically.** `dos_port/tools/static_gate` runs BOTH linter
> modes plus `test_label_db.py` and `validate_scenarios.py`, and it is invoked
> by `.githooks/pre-commit` (installed here: `core.hooksPath=.githooks`). It
> fires whenever anything under `dos_port/` is staged. It is a per-class
> RATCHET against a checked-in baseline: it fails a class that GREW.
>
> **What that does NOT mean.** A class sitting at baseline is not sanctioned —
> it is unfixed debt that merely has not gotten worse. `dos_port/tools/lint_pret_labels`
> **must exit 0**; it does not today — a small number of known, unsanctioned
> findings remain (`aux_misplaced` under plain `lint_pret_labels`;
> `--strict-claims` can add `hand_encoded_text` / `local_shadow` on top). None
> of those was ever approved by the maintainer, and the counts move as agents
> clear debt — **run `dos_port/tools/lint_pret_labels --no-scan` and
> `--no-scan --strict-claims` yourself** rather than trusting a number written
> here. Do not cite "at baseline" as permission to leave a class non-zero, and
> do not rewrite the rule to match the breakage.
>
> **For every commit made under this plan:**
> 1. Record the per-class counts from BOTH `lint_pret_labels` and
>    `lint_pret_labels --strict-claims` **before** you start.
> 2. Run both again before committing and compare per class. A class that grew
>    is your regression to fix now, not the next agent's to discover. Moving a
>    routine between files silently invalidates `extern` provider comments
>    elsewhere in the tree — collateral visible **only** under `--strict-claims`.
> 3. A green static gate proves **no structural or bookkeeping drift and nothing
>    about behaviour.** If the change can move a pixel or a WRAM byte, run
>    `make -C dos_port fidelity` (core) or `fidelity-full`, and add a must-hit
>    scenario when no existing one can witness the change.
>
> **The allowlist is not yours to grow.** `dos_port/tools/pret_label_allowlist.json`
> is hash-locked legacy debt, not precedent. New relocations are FORBIDDEN. An
> agent may not add, expand or reinterpret it — including `structural_findings`
> and `suppress` — to make its own work pass. **Any ADDITION requires explicit
> maintainer sign-off and cannot be committed without it**; the pre-commit hook
> refuses added keys outright and names them. If the linter says `mirror`, move
> the complete routine to `dos_port/src/<pret path>` instead.
>
> Do not quote a finding count from this file, CLAUDE.md, AGENTS.md, a skill, or
> a stigmergy memory as evidence that a class is clean — every one of those has
> been wrong before. Re-measure it.

Status: **Stages 1–10 and most of Stage 11 are complete.** The remaining item
work is the three fishing rods and the final stub-retirement sweep. PP Up / PP
restoration and the Surfboard LANDED 2026-08-02 (see their entries below);
Itemfinder landed 2026-07-16 and owes only runtime evidence. Archive this file to
`docs/plans/items.md` when those items are complete.

This status was re-measured 2026-08-02 against the tree at `3fad3249`, per the
maintainer directive to re-derive open items from generated state rather than
carry forward prior narrative — this is a re-measurement pass, not new work.
Every stale claim it found had made this plan look MORE blocked than the tree
actually is (see the Fishing rods, Surfboard, and DisplayTextID entries below);
none understated remaining work. Re-measured against the linked build,
`dos_port/tools/project_state`, the 37-scenario fidelity manifest
(`dos_port/tools/scenario_manifest.json` — cite the file, not this number, next
time), and the operational evidence policy in `AGENTS.md`. Older completion
narratives and resolved blockers remain in git history rather than being
maintained here.

## Standing rules

- Preserve pret labels and byte layout, including the Gen-1 catch-rate byte at
  party/box struct offset 7. Human-rendered strings are generated Tier-1 data;
  item behavior and pointer tables remain hand-written Tier-2 code.
- Before asserting that a dependency is missing, stubbed, check-only,
  unreachable, or callerless, rerun `dos_port/tools/project_state` (and
  `label_status --callers/--callees` when the provider split matters).
- For changed pret code, run `dos_port/tools/fidelity_gate --base <base>`.
  Its clean result means only "no detected structural divergence"; every
  behavior change also needs a runtime scenario whose must-hit list proves the
  changed path executed.
- Keep cross-plan ownership intact: this plan owns `UseItem_`, the item dispatch
  table, every `ItemUse*` body, and item-subsystem helpers such as
  `HiddenItemNear`. Overworld-events owns map/event data and dispatch,
  sprite/front-tile queries, movement consumers, and story scripts. The
  in-battle bag, turn consumption, and item-result battle consumers belong to
  `docs/current_plan_battle_completion.md` Stage 2c. Battle-owned stat and
  happiness helpers used by item effects are closed in its Stage 3d.

## Completed capability

- [x] Inventory bookkeeping, generated item/mart data, effect cores, BCD money
      math, and live TOSS.
- [x] `UseItem_`/`ItemUsePtrTable`, context guards, medicine, balls, TM/HM,
      evolution stones, Repels, Escape Rope, and battle items.
- [x] Bicycle, Coin Case, Oak's Parcel, Pokédex, Poké Flute, Town Map, Card Key,
      and Safari BAIT/ROCK.
- [x] Bag USE now stages the selected item name through `GetItemName` and
      `CopyToStringBuffer`; `ItemUseText00` no longer reads stale item text.
- [x] The obsolete text-stream staging model is gone. `TextCommandProcessor`
      and `PrintText` consume flat streams, while only genuinely WRAM-composed
      streams use the staged path.
- [x] Escape Rope arms and reaches the linked fly/dungeon-warp consumer. Its
      state transition has headless coverage; the complete cave-to-last-heal
      traversal still belongs in a must-hit overworld runtime scenario.

## Remaining Stage 11 work

- [x] **Itemfinder** — done 2026-07-16 via a **cross-cut from
      `docs/current_plan_overworld_events.md` Stage 3** (that session owned the
      `HiddenItemCoords` data contract and did the whole item-side promotion in
      the same pass; recorded here per the cross-cut rule). `HiddenItemCoords` is
      now generated (`tools/generators/gen_hidden_item_coords.py` →
      `assets/hidden_item_coords.inc`, linked via `src/data/hidden_events_data.asm`).
      `src/engine/items/itemfinder.asm` (`HiddenItemNear`/`Sub5ClampTo0`) is
      linked (`ITEMS_SRCS`); `IsInRestOfArray` was promoted into `HOME_SRCS` (it
      has since moved from the `vcopy.asm` util bucket to its pret mirror
      `src/home/array2.asm`). `ItemUseItemfinder` moved from the `item_use_stubs.asm`
      ret-stub to a real body in `item_effects.asm` (`farcall HiddenItemNear` →
      flat `call`; `jp PrintText` → the `iu_print_text` overworld tail;
      `ItemfinderFound{Item,Nothing}Text` were already generated). Build clean,
      `lint_pret_labels` 0, `faithdiff HiddenItemNear`/`ItemUseItemfinder` show
      only the documented predef→`FlagAction` and `iu_print_text` deviations.
      **Open tail:** the "near"/"nothing" must-hit runtime scenario still owes
      evidence — ITEMFINDER is not obtainable in the current build, so acceptance
      (both outcomes, without mutating the found flag) lands with the first
      reachable hidden-item map. See `docs/items_blockers.md` → Itemfinder.

- [x] **Fishing rods — DONE 2026-08-03.** `ItemUseOldRod` / `ItemUseGoodRod` /
      `ItemUseSuperRod` / `RodResponse` / `DoNotGenerateFishingEncounter` /
      `FishingInit` translated faithfully from pret
      `engine/items/item_effects.asm:2026-2140` into their mirror;
      `super_rod.asm` promoted from `ITEMS_CHECK_SRCS` to `ITEMS_SRCS`;
      `GoodRodMons` generated (`gen_super_rod.py` → `assets/good_rod.inc`,
      level-first rows, included at pret's position). The rod ret-stubs were
      the LAST content of `item_use_stubs.asm`, which is deleted — every
      ItemUse* family now has a real body. Backlog #24's two defects on the
      `LoadAnimSpriteGfx` path are fixed caller-side (`RedFishingTiles`
      reshaped to the port's 12-byte header, count passed in full `EAX`), so
      the party-icon path is untouched (`party_menu` golden stays its
      witness). Backlog #25's `wRodResponse` promotion to `gb_memmap.inc`
      0xCD3D (union comment carried) landed first, as filed.

      Runtime evidence: golden scenario **fish_old_rod** (id 42, datastruct)
      drives one `FishingInit` failure (`ItemUseNotTime`) and the
      deterministic OLD ROD bite (MAGIKARP lv 5 armed in
      `wCurOpponent`/`wCurEnemyLevel`, `wRodResponse`=1) through the live bag
      UI on both sides. The Good/Super Rod picks are RNG-gated (free-running
      GB RNG differs across sides) and are deliberately NOT golden-compared —
      they share the whole `FishingInit`/`RodResponse`/`FishingAnim` skeleton
      the scenario pins. The scenario also caught a faithfulness gap kept as
      a known deviation: pret's START-press path refreshes
      `wTileInFrontOfPlayer` (`.displayDialogue`), the port's does not — the
      scenario works around it by facing away from the water for the failure
      use (both sides then agree for opposite reasons; see
      `fish_old_rod.lua`'s header).

- [x] **PP Up and PP restoration — DONE 2026-08-02.** `ItemUsePPUp` and
      `ItemUsePPRestore` are translated faithfully from pret
      `engine/items/item_effects.asm:2170-2390` into their mirror
      `src/engine/items/item_effects.asm`; both ret-stubs are deleted from
      `item_use_stubs.asm`. Measured before starting and confirmed: all 14 call
      targets translated and linked, all 5 text streams already generated into
      `assets/item_text.inc`, every WRAM alias present — the item had zero
      external blockers, as the 2026-08-02 re-measurement predicted.
      pret's Max Ether / Max Elixer PP-Up-bit no-effect bug is preserved and
      tagged `BUG{class=data-model; ...}` with a `%if BUG_FIX_LEVEL >= 2` mask.
      Also deleted: `RestorePPAmount`, a port-only forked partial of
      `ItemUsePPRestore.restorePP` with zero callers, written during the Stage-3
      effect-core pass — exactly the forked-name duplication the
      Preserve-pret-Labels rule exists to prevent.
      **Coverage:** new golden scenario `item_pp_restore` (id 39, tier full,
      datastruct), port gate `DEBUG_ITEMPP` → `RunPPRestoreTest`. It was required:
      `move_selection` drives the REGULAR battle move menu (`wMoveMenuType` 0) and
      nothing in the suite reached `wMoveMenuType` 2. Decomposed rather than
      trusting the PASS — golden and port agree that mon 0's move-slot-0 PP goes
      1 → 11 and `wNumBagItems` goes 16 → 15 with the ETHER consumed.

- [x] **Surfboard — DONE 2026-08-02.** `ItemUseSurfboard` (pret
      `engine/items/item_effects.asm:700-777`) is translated with mount, dismount
      and the "no place to get off" refusal, alongside `SurfingAttemptFailed`,
      which was the only `missing` dependency; the stub is deleted.
      `IsSpriteInFrontOfPlayer2` was NOT re-ported — it landed 2026-07-16 with the
      overworld-events boulder work — but it needed a **repair**: pret advances the
      slot pointer with 8-bit math on `L` alone, so the not-found exit wraps to
      `$C100` (the player's slot), while the port's flat `add` returned `$C200`.
      Latent until now, because `ItemUseSurfboard` is the first caller that
      dereferences `hl` on BOTH exits (`res BIT_FACE_PLAYER, [hl]`). Neither
      existing caller reads `hl`, so no live behaviour changed.
      **Coverage:** new golden scenario `surf_round_trip` (id 40, tier full,
      datastruct), port gate `DEBUG_SURF` + `AUTOKEY_SURF` driving the LIVE
      overworld loop with live collision on both sides. It is also the suite's
      first coverage of `CollisionCheckOnWater` and the surf state machine —
      written once, here, as this plan required. Tile layout measured off
      `maps/PalletTown.blk` + `gfx/blocksets/overworld.bst`: the shore tile
      `(15,4) = $32` is load-bearing, because `CollisionCheckOnWater` auto-dismounts
      the instant the player moves toward passable land, and `ItemUseSurfboard`
      reads `wTileInFrontOfPlayer` STALE.
      **Known open, filed as backlog #33:** with the menus closed the port does not
      consume the dismount's armed simulated step (`wJoyIgnore` stays `$FF`; there
      is no `JoypadOverworld` to clear it). That consumer is overworld-events', so
      the scenario dumps with the bag still open, where both sides have the step
      armed and unconsumed.

- [ ] **Stage 12 — stub and claim retirement.** Empty
      `src/engine/items/item_use_stubs.asm` — measured 2026-08-02, that file
      held six labels aliased onto one `ret`; three of those retired on
      2026-08-02 (`ItemUsePPUp`, `ItemUsePPRestore`, `ItemUseSurfboard`), leaving
      `ItemUse{Old,Good,Super}Rod`. Its
      `TODO(safari, battle plan): ItemUseBait / ItemUseRock` line is stale
      (both are real linked bodies in `item_effects.asm`). Run
      `label_status --callers` for
      every retired provider; update the label DB; run the strict/default label
      lint and `fidelity_gate`; sweep related `STUB`, `TODO`, extern-provider,
      allowlist, plan, skill, and stigmergy claims; then archive this plan.

## Cross-plan reachability and fidelity tails

These do not block implementing the remaining item bodies, but they prevent
some completed effects from being fully reachable or faithful end to end:

- `DisplayTextID` is DONE (re-measured 2026-08-02): `implementation / linked /
  statically-reached-from-start`, provider `src/home/text_script.asm`; the
  `home_stubs` ret-stub is gone and the check-only reading is stale (see the
  reachability note in `src/engine/menus/display_text_id_init.asm:12-21`).
  The whole Repel-expiry path links —
  `TryDoWildEncounter` (`src/engine/battle/wild_encounters.asm:142-147`) sets
  `TEXT_REPEL_WORE_OFF` and calls `DisplayTextID`, which dispatches to
  `DisplayRepelWoreOffText` (`src/home/text_script.asm:155-157, 437-444`).
  What remains is coverage only: no manifest scenario hits `TryDoWildEncounter`,
  so the message is linked-but-unwitnessed. Overworld-events Stage 2 still owns
  that scenario.
- `BattleItemMenu` is a linked ret-only helper. Balls and battle-item effects
  have direct state coverage, but `ball_catch` enters through `UseItem` and
  bypasses that menu. The live battle ITEM button cannot reach the dispatcher
  until battle-completion Stage 2c lands; that stage owns menu/cancel/turn
  semantics rather than duplicating any item handler.
- Poké Flute's Pewter sleeping-Pikachu branch lacks
  `IsPikachuRightNextToPlayer` and `PlaySpecificPikachuEmotion`; the Route
  12/16 Snorlax flags still need their overworld-owned map-script consumers.
  `ModifyPikachuHappiness` is also a linked stub, so all already-placed item
  happiness calls remain inert until battle-completion Stage 3d supplies its
  pret-owned interface. These are owner-plan tails, not reasons to reopen the
  completed item handlers.
- Safari BAIT/ROCK and ball effects are complete item-owned providers. The
  Safari action menu, turn/flee loop, and result consumption belong to
  battle-completion Stage 4d; Safari map/step/story reachability belongs to
  overworld-events.

## Fidelity and acceptance

The scenario manifest currently supplies these item-facing comparisons:

| Scenario | Tier / class | Must-hit evidence | What it proves |
|---|---|---|---|
| `item_tm_teach` | core / datastruct | `RunTMHMTest` | TM/HM post-flow WRAM state |
| `item_stone_evolve` | full / datastruct | `RunStoneTest` | evolution-stone post-flow WRAM state |
| `item_potion_use` | full / datastruct | `UseItem` | medicine post-flow WRAM state |
| `ball_catch` | full / datastruct | `RunBattleTest`, `UseItem` | capture post-flow WRAM state |
| `item_pp_restore` | full / datastruct | `ItemUsePPRestore` | ETHER restores move-slot-0 PP 1 → 11, item consumed |
| `surf_round_trip` | full / datastruct | `ItemUseSurfboard` | mount, one surf step, dismount through the live loop |

Datastruct scenarios intentionally skip tilemap, VRAM, and OAM; they are not UI
proof. `bag_menu`, `battle_menu`, and `move_selection` protect their named
surfaces but do not prove that any unfinished item handler executed.

For each remaining family:

1. Establish current providers/callers with `project_state` and `label_status`.
2. Run `fidelity_gate` for the changed files and review every reported
   ADDED/DROPPED call; put required justifications in the commit message.
3. Add or extend a deterministic scenario whose must-hit markers name the
   changed handler and the downstream behavior being claimed. Compare WRAM and
   rendered surfaces according to what changed.
4. Run targeted `goldencheck`, the core tier, and `fidelity-full` when the
   changed surface is in the long tail. Run `goldens-verify` whenever scenario
   or committed golden artifacts change.
5. Do a live DOSBox-X pass only for behavior not captured at a deterministic
   terminal dump (notably continuous fishing/movement and complete warps), and
   report it as visually observed rather than golden-matched.
