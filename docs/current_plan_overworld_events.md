# Current Plan: Overworld Events — story scripts and interaction services

> **Rewritten 2026-08-17.** The previous revision was 1151 lines, most of it dated
> session handoffs and retraction-of-a-retraction narratives. Those are deleted, not
> struck through: they are in git history, and a plan that carries its own diary
> stops being readable as a statement of what is open. What survives is the current
> state, the open work, and the small number of lessons that would cost a future
> session real time to rediscover. Several items were also **stale in the tree** —
> each correction is noted inline where it changes what someone would do.

## Gate

`dos_port/tools/static_gate` runs both linter modes plus `test_label_db.py` and
`validate_scenarios.py`, and `.githooks/pre-commit` invokes it whenever anything
under `dos_port/` is staged (install: `make -C dos_port install-hooks`).

`lint_pret_labels` **must exit 0**, and as of 2026-08-17 it does, in both plain and
`--strict-claims` modes, with an empty `static_gate` baseline. *(Corrected: this
section used to say "it does not today" and listed `aux_misplaced` /
`hand_encoded_text` / `local_shadow` as outstanding. That debt is cleared.)* Do not
read that as permission to relax — re-measure rather than trusting this paragraph,
and a class sitting at baseline is unfixed debt, never sanction.

For every commit under this plan:
1. A green static gate proves **no structural or bookkeeping drift and nothing about
   behaviour.** If the change can move a pixel or a WRAM byte, run
   `make -C dos_port fidelity` (core) or `fidelity-full`.
2. Moving a routine between files silently invalidates `extern` provider comments
   elsewhere — collateral visible only under `--strict-claims`.
3. Judge a suite run by `reported=N/N nonzero=0`, not by PASS counts: a scenario that
   never runs emits neither PASS nor FAIL.

**The allowlist is not yours to grow.** `dos_port/tools/pret_label_allowlist.json` is
hash-locked legacy debt, not precedent. New relocations are forbidden; the pre-commit
hook refuses added keys and names them. If the linter says `mirror`, move the complete
routine to `dos_port/src/<pret path>`.

## Status

Complete: the script/event foundation, the sign milestone, Pallet's Oak-intro state
machine, the `DisplayTextID` dispatcher, all of Stage 3, and Stage 4's
Strength/boulder, Cut, Ledge and Surf tails.

Open: the Oak-intro golden, the real service-dialog bodies (mart transaction loop,
nurse, vending, prize, Safari, Pikachu), must-hit coverage for the linked-but-unwitnessed
field moves, the last two standard-map wires, the story-ordered map rollout, and the
final stub sweep.

**`[x]` means linked and structurally verified — not executed.** Several bullets are
`[x]` with runtime evidence openly deferred because nothing in the current build state
can reach them. Each says so. Do not upgrade one to "working" without its scenario.

Archive to `docs/plans/overworld_events.md` when the stages below are complete.

## Standing rules and ownership

- Preserve pret labels and control/data flow. Human-rendered dialog is generated
  Tier-1 data; `_Script` state machines, `text_asm` tails, dispatch tables and
  handlers are hand-written Tier-2 code.
- Before asserting a dependency is missing, stubbed, check-only, unreachable or
  callerless, rerun `dos_port/tools/project_state` and use `label_status
  --callers/--callees`. Inspect `%ifdef` guards directly — static scanning can see a
  definition the default build excludes.
- **`not-proven-reached` is never proof of unreachability.** `dd Label` dispatch
  tables and address-taken operands emit no edge, so map script tables,
  `HiddenEventMaps` handlers, `.outOfBattleMovePointers` and both ISRs read
  unreached while provably live. Cite `--callers` or runtime evidence. (This is now
  a standing rule in CLAUDE.md; the long incident narrative that established it is
  in `docs/plans/label_db_reachability.md`.)
- **No scenario, no wire** (`faithfulness-review` skill). One golden per wired map.
- Ownership: `docs/plans/items.md` delivered the `ItemUse*` bodies including
  `ItemUseSurfboard`, `SurfingAttemptFailed`, `ItemUseItemfinder` and
  `HiddenItemNear`. This plan owns map/event data and dispatch, movement consumers
  and story-script consumers. `docs/current_plan_battle_completion.md` Stage 1 owns
  trainer-battle activation/exit and beaten flags; its Stage 4 owns special
  battle-type behaviour. Map scripts seed battle state, hand off, and consume results
  without duplicating battle logic.

## Completed foundation

- [x] Event flags, generated event constants, generated map text tables,
      `ShowTextStream`, `RunMapScript`, `CallFunctionInTable` and the default per-map
      no-op dispatch are linked.
- [x] Pallet Town has the first linked `_Script`/`text_asm` skeleton; Oak cutscene
      states 0–8 have code and state 9 is the real no-op tail. It is no longer the
      only registered map — `assets/map_scripts.inc` now has **16** non-default rows
      of 249: `PalletTown_Script` plus 15 maps pointing at the generic
      `TrainerMapScript`. Register new maps through `gen_map_script_tables.py`, not
      per-map skeletons. Do not quote that count; the generator prints it.
- [x] Scripted NPC movement, pathfinding, `MoveSprite`, simulated joypad support and
      the per-map movement-script table are linked. Infrastructure, not evidence that
      a cutscene has executed.
- [x] Sign interaction is live through the A-press path
      (`IsSpriteOrSignInFrontOfPlayer` → `SignLoop` → `DoSignInteraction` →
      `DisplaySignText`), golden-matched by `sign_pallet`.
- [x] The party-menu field-move dispatcher and badge gates are present, and every
      field move behind them is linked — Cut, Strength, Surf, Fly, Flash, Dig,
      Teleport and Softboiled (`src/engine/menus/start_sub_menus.asm:393-586`).
      *(Corrected: this bullet used to end "Cut, Fly, Surfboard, and boulder movement
      remain open below" — all four have since landed. What is open for them is
      evidence, not code; see Stage 4.)*
- [x] `player_animations.asm`, `LoadAnimSpriteGfx`, screen-buffer helpers, Town Map,
      `PlayerPC` and `ActivatePC` are linked.

## Stage 1 — Oak intro and Pallet state machine

- [x] pret states 0–8 replace the cutscene stub, with the north-exit trigger, Oak
      approach, scripted movement, dialog, Lab transition, Pikachu battle seed and
      post-battle advancement.
- [x] Preserve the port's movement ABI and drain multi-step paths through the linked
      simulated-input machinery. `PlayerStepOutFromDoor` stores the pret-style
      `wJoyIgnore` mask and relies on `AreInputsSimulated.doneSimulating` to clear it.
- [x] Keep the cross-plan boundary explicit: the script seeds `wCurOpponent`,
      `wBattleType` and `wCurEnemyLevel`; battle-completion supplies
      `BATTLE_TYPE_PIKACHU` behaviour and battle exit semantics.
- [ ] **Add a deterministic Pallet Oak-intro scenario.** The harness exists and is
      unregistered: gate `DEBUG_PALLET_OAK` (`dos_port/Makefile:1206`) drives
      `RunOakIntroTest` (`src/debug/debug_dump.asm:596`), called from
      `src/home/overworld.asm:623`. No manifest row uses it.
      **`oak_intro` (id 29) is NOT this** — it is the menu-intro plan's Prof. Oak
      opening speech (`must_hit = OakSpeech / PrepareOakSpeech / FadeInIntroPic /
      DisplayPicCenteredOrUpperRight`), a different thing that merely shares the name.
      The new scenario needs a non-colliding name, and its must-hit list must name the
      Pallet script state and the scripted-movement consumer.

## Stage 2 — `DisplayTextID` and overworld service dialogs

`DisplayTextID` is real and linked (`src/home/text_script.asm:94`). Genuinely
unfinished services are structured stubs in their owning subsystem — five in
`src/engine/menus/main_menu_stubs.asm` (`DisplayPokemartDialogue_`,
`DisplayPokemonCenterDialogue_`, `VendingMachineMenu`, `CeladonPrizeMenu`,
`CableClubNPC`) and two in `src/engine/overworld/overworld_stubs.asm`
(`TalkToPikachu`, `PrintSafariGameOverText`). All seven carry `STUB{}` annotations
naming their retirement.

- [x] Reconcile the port's flat map-text table with pret's `wCurMapTextPtr` lookup,
      bind the ISR-backed joypad interface, generate the missing far text, link
      `text_script.asm`, and retire the stand-in and its stale extern trails.
- [x] `PlayerPC`, `ActivatePC` and `BillsPC_` are real implementations
      (`src/engine/pokemon/bills_pc.asm:299`, covered by the `bills_pc_ops` and
      `box_change_roundtrip` goldens). The blanket `M72_OVERWORLD_TEXTSCRIPTS` guard
      is retired.
- [x] Replace blanket service guards and sentinel-byte fallbacks with structured
      owning-subsystem stubs.
- [ ] **Port `DisplayPokemartDialogue_` and the buy/sell transaction loops.** The data
      half is DONE as of 2026-08-17: `gen_marts.py` → `assets/marts.inc` → carrier
      `src/data/items/marts.asm` supplies all 16 pret mart inventories under their
      pret label names, and dispatch is live — `text_script.asm:251` routes
      `TX_SCRIPT_MART` into the real `DisplayPokemartDialogue`, which prints the
      greeting and calls `LoadItemList` before hitting the stub. **So the greeting and
      inventory load work today; only the priced-list menu and the transaction loop are
      missing.** Add a scenario hitting the dispatcher plus a successful and a refused
      purchase.
- [ ] Port `DisplayPokemonCenterDialogue_`, the nurse heal flow and the Pokémon Center
      PC shell. Verify party healing and the rendered dialog, not merely menu entry.
- [ ] Port the vending, prize, Safari and Pikachu tails, replacing their stubs with
      real providers plus must-hit scenarios.
      **Cable is explicitly NOT in this list any more.** Maintainer directive
      2026-08-17: the link-cable layer is not to be wired for the foreseeable future.
      `CableClubNPC` keeps its stub; see stigmergy `link-layer-planned-transports`.

**Known gap, not a bullet:** `ShowTextStream`
(`src/engine/overworld/map_sprites.asm:991`) unconditionally calls
`npc_dialog_wait_impl` and never reads `wDoNotWaitForButtonPressAfterDisplayingText`,
so Oak's first line is shown but does not auto-advance as pret does. `DisplayTextID`
reads the flag correctly at `text_script.asm:285`; the two paths are separate.

**`PrintPredefTextID` works and is linked** (`src/home/predef_text.asm:71`), with
`TextPredefs` at `src/data/text_predef_pointers.asm:64`. *(Corrected: this plan
carried a prominent 2026-07-28 warning that the `TEXT_PREDEF` branch "does not work,
and cannot as written", and warned against supplying a flat table. The resolution
shipped and the warning now misleads — the fix was not to replace the GB pointer but
to publish a side-channel flat pointer `w_predef_text_table_ptr`, while
`SetMapTextPointer` still stores the truncated 16-bit value that
`RestoreMapTextPointer` and `ChangeBox` depend on. Nothing dereferences the truncated
value. Plan archived at `docs/plans/predef_text.md`.)*

## Stage 3 — hidden interactions and ground items

All three bullets are complete and linked. **Re-measured 2026-08-21: 29 per-object
handlers remain** Tier-2 ret-stubs in `src/engine/overworld/hidden_object_stubs.asm`
(it read 35 when this paragraph was written), each documenting which subsystem
retires it. The engine/events fan-out (`359ad2dc2`) retired six of them with real
bodies at their pret mirrors — `PrintBlackboardLinkCableText`, `PrintNotebookText`,
`PrintCinnabarQuiz`, `UpdateCinnabarGymGateTileBlocks_`, `GymTrashScript` and
`PrintTrashText` — and ten stubs remain in the sibling
`src/engine/events/hidden_events/hidden_events_stubs.asm`. **None of that discharges
the runtime evidence the bullets below ask for:** the handlers are linked, not
witnessed. Two golden scenarios were authored (`dex_rating_oak_pc.lua`,
`safari_game_over.lua`) and are committed UNRUN and unregistered, because every one
of them needs a port-side entry gate in `src/debug/debug_dump.asm` plus the
`EnterMap` dispatch in `src/home/overworld.asm`, and registering a manifest row
without committed golden artifacts fails `validate_scenarios.py` for everyone.
That gate is the single thing standing between this stage and its evidence.

`PrintBookshelfText`'s stub is deliberately functional (it sets
`hInteractedWithBookshelf = $ff` so the sprite/sign scan still runs — a plain `ret`
there silently suppresses NPC and sign interaction).

- [x] Generate hidden-event map/coordinate/argument data into `assets/hidden_events.inc`,
      keep per-object handlers in Tier-2 code, and wire
      `CheckForHiddenEventOrBookshelfOrCardKeyDoor` first in the pret A-press order.
- [x] Publish the generated `HiddenItemCoords` interface; `HiddenItemNear` is linked
      at `src/engine/items/itemfinder.asm`.
- [x] Port `PickUpItem` (`src/engine/events/pick_up_item.asm`), generate pickup text,
      and route `PickUpItemText` through the live text-script path.

**Runtime evidence owed:** pickup success / bag-full, and itemfinder near / nothing.
Measured 2026-08-17: no scenario in the 85-row manifest has a must-hit naming
`PickUpItem`, `HiddenItemNear` or `ItemUseItemfinder`. No reachable map carries an
item ball and ITEMFINDER is not obtainable, so both land with Stage 5.

## Stage 4 — field-move tails

- [x] **Strength / boulders** — `TryPushingBoulder` and `DoBoulderDustAnimation` are
      linked and run per-frame, with the shared OAM substrate
      (`AdjustOAMBlock{X,Y}Pos(2)`, `WriteOAMBlock`) in
      `src/engine/battle/animations.asm`. **Push and blocked-push are NOT witnessed**
      and cannot be: nothing arms `BIT_STRENGTH_ACTIVE` and no reachable map carries a
      boulder, so `TryPushingBoulder` returns at its first test every frame. Lands with
      Stage 5 (Seafoam / Victory Road).
- [x] **Cut** — `StartMenu_Pokemon.cut` calls pret's real tail and `UsedCut` has its
      caller. **The cut animation and tree-tile replacement are NOT witnessed** — every
      added line sits behind the `CASCADEBADGE` gate plus a mon knowing CUT. Lands with
      Stage 5 (Viridian). The party-menu compositor teardown projected into `UsedCut`
      (`.canCut`) is **reasoned from a port invariant, not observed**, and is the first
      thing that scenario should confirm or correct.
- [x] **Ledges — DONE 2026-08-03 (`3f0afc9e`), gated by `ledge_hop` (id 41).**
      `must_hit = HandleLedges / HandleMidJump / _HandleMidJump`. Residual: the hop ARC
      is not drawn and `LoadHoppingShadowOAM` is a ret-stub — compositor work, tracked
      as `docs/current_plan_backlog.md` #29.
- [x] **Surf — DONE, gated by `surf_round_trip` (id 40, `must_hit =
      ItemUseSurfboard`, build flag `DEBUG_SURF=1`).** *(Corrected: this bullet was
      `[ ]` and described the SURF consumer as the missing piece. The consumer landed
      with the items plan and has had a passing golden since.)*
      `IsSpriteInFrontOfPlayer2` lives in `src/home/overworld.asm` and already executes
      on the A-press counter-tile branch.
- [~] **Fly** — implemented and linked end to end, including the arrival: menu leg
      (`start_sub_menus.asm:393`) → `HandleFlyWarpOrDungeonWarp`
      (`src/home/overworld.asm:2111`) → `PrepareForSpecialWarp`
      (`src/engine/overworld/special_warps.asm:109`) → `SpecialEnterMap`
      (`src/engine/menus/main_menu.asm:428`). Nothing on that chain is a stub.
      **What is open is evidence, not code: no scenario exercises Fly, and none
      exercises any warp at all** — measured against all 85 must-hit lists 2026-08-17.
      The arrival page-fault previously seen under `DEBUG_SEED_PARTY` was suspected to
      be a debug-seed / new-game player-state artifact rather than Fly logic; that is
      an untested theory about a build state that has since moved, so re-measure
      against the current binary rather than acting on it.
- [ ] **Flash, Dig, Teleport, Softboiled** — linked, and none has must-hit coverage
      (measured 2026-08-17: no manifest must-hit names any of them). This plan owns the
      `HandleFlyWarpOrDungeonWarp` arrival consumer and the end-to-end warp scenario. A
      generic overworld regression run is not execution evidence.

**Register contract worth not re-deriving:** `AdjustOAMBlock{X,Y}Pos(2)` take **BL**
(pret's `c`, entry count) — the project map is BC→BX. `dust_smoke.asm` shipped `CL` and
was a latent bug precisely because it had never linked. The non-`2` entries take the
pointer in **EDX** and copy it to ESI; the `…2` entries expect **ESI** already loaded.

**`jp CloseTextDisplay` → `jmp CloseStartMenu` in `.cut` is PERMANENT.** pret runs its
START menu inside `DisplayTextID`'s frame, so `CloseTextDisplay`'s closing `pop af`
partners a push the port never makes — the port opens the menu from `OverworldLoop`
under its own `pushad`. Jumping there would eat a pushad register. Do not "fix" it.

## Stage 5 — story-ordered map rollout

### Stage 5a — the `TrainerMapScript` driver rollout

A "standard trainer map" is one whose whole script layer is pret's seven-instruction
boilerplate **and** a three-entry pointer table. Seventeen maps qualify; they get a
`WIRED_MAPS` row in `gen_map_script_tables.py` rather than per-map assembly.

**15 of 17 are wired.** Regenerate rather than trusting any list:
`python3 dos_port/tools/generators/gen_map_script_tables.py`.

- [x] **ROUTE_3, ROUTE_6, ROUTE_11** (ids 30/31/32) — landed by the archived
      `docs/plans/map_script_fidelity.md`.
- [x] **ROUTE_4, ROUTE_8, ROUTE_9, ROUTE_10** (ids 47–50) — chosen for the branch each
      adds: R9 the first LEFT-facing trainer, R8 the first UP-facing, so both signs of
      both axes are covered; R10 the first tall map; R4 the widest.
- [x] **ROUTE_13, ROUTE_14, ROUTE_15, ROUTE_18, ROUTE_19, ROUTE_21** (ids 52–58) —
      chosen for what a facing cannot reach: R13 and R18 bracket the header-table walk
      at both extremes (last of ten, last of three); R14 is the only tile whose scan
      reaches a *range* rejection before the real match, so a port ignoring range
      engages the wrong trainer rather than nobody; R15 engages at exactly the view
      range, pinning `CheckSpriteCanSeePlayer`'s `cp b`/`jr nc` as inclusive; R19 adds
      the right map edge; R21 adds magnitude.
- [x] **VIRIDIAN_FOREST** (id 86) — wired 2026-08-15 after a maintainer found its five
      trainers could be talked to but never fought.
- [x] **ROUTE_17 — WIRED 2026-08-16 (`ea6d5f9cc`), on the third attempt.**
      *(Corrected: this was a long `[ ]` bullet reading "wired, BACKED OUT, and blocked
      on a newly measured port gap".)* Scenario `route17_trainer_battle` (id 55) drives
      the **real `OverworldLoop`** and must-hits `ForceBikeDown` explicitly. The first
      two attempts used `route17_sight`, which could never witness it:
      `RunMapScriptSightTest` runs `UpdateSprites` → `RunMapScript` → `DelayFrame` and
      by design never enters `OverworldLoopLessDelay`, where the joypad path lives.
      **The lesson, which is why this bullet survives: a diagnosis that names a real
      missing routine is not finished until you check that the failing scenario could
      observe the fix.** Two golden runs were spent proving a correct fix against a
      blind harness. Memory `regression-overworld-forcebikedown-missing` is closed
      FIXED.
      Also recorded: a mask for `wYCoord` / `wTrainerScreenY` was **offered and
      declined**, and the boundary generalises — take the mask when the divergent field
      is one the scenario was not built to test; refuse it when the divergent field IS
      the scenario's reason for existing. `wTrainerScreenY` is exactly the field that
      would reveal a view-pointer error at y=120, and magnitude is why ROUTE_17 was
      chosen.
- [ ] **The last two standard maps: CERULEAN_CAVE_B1F and POWER_PLANT.** Both owe the
      **truncated-tail decision**: `gen_trainer_headers.py` cannot represent a
      `text_asm` tail with side effects in a data stream and truncates seven of them
      (it prints each on every run). Verified 2026-08-17 by mapping each truncated
      label to its owning script: `MewtwoBattleText` → CeruleanCaveB1F,
      `PowerPlantZapdosBattleText` → PowerPlant, plus VictoryRoad2F, LancesRoom,
      RocketHideoutB1F and RocketHideoutB4F — and only the first two are
      standard-shape, so they are the only truncated-tail maps the driver can reach.
      Either the header generator gains an optional per-header "post-end-battle event"
      field consumed after `PrintEndBattleText`, or these two get bespoke hand-ports.
      **Tileset residency is NOT a wiring blocker, and this plan used to say it was.**
      VIRIDIAN_FOREST uses the `FOREST` tileset, which is no more resident than CAVERN
      or FACILITY, and it wired anyway with a passing golden — because the sight
      goldens are **wram-only** and never compare rendered tiles. Tileset residency
      blocks *rendering* these maps, not wiring or gating them.
      **And the residency gap is smaller than it looks — measured 2026-08-17.**
      `gen_all_assets.py` already generates all **21** tileset gfx blobs into
      `assets/*_gfx.inc` — `cavern_gfx.inc`,
      `facility_gfx.inc`, `forest_gfx.inc` and the rest all exist after `make assets`.
      What is missing is not the DATA but the wiring: only `overworld_gfx.inc` is
      `%include`d by any source (`src/engine/overworld/overworld.asm:1171`), so
      `cavern_gfx` and its 19 siblings are generated and then dropped on the floor —
      none of them is a defined symbol in the build. So the remaining work is a
      per-map tileset dispatch and the VRAM load that selects it, not asset
      production. (The superseded `gen_overworld_assets.py`, whose docstring was the
      source of the old "embeds exactly one of pret's 20 tilesets" framing, was
      deleted 2026-08-17 — it had not been invoked by anything for some time.)
- [ ] **The four near-miss maps** (FightingDojo, Route12, Route16 at 4 pointers,
      Route24 at 5) have the skeleton body but non-standard pointer tables, so the
      driver needs a per-map tail. They are driver-EXTENSION candidates, not wiring
      candidates — do not force them into `WIRED_MAPS`.

**Counting note added 2026-08-17:** `assets/map_script_tables.inc` now emits **40**
`<Map>_ScriptPointers` jumptables, not 17. The generator was extended to emit a table
for every map whose pointer table is standard, independently of whether its `_Script`
body is the driver skeleton — 23 such maps have bespoke bodies hand-ported in
`src/scripts/` and get a table and nothing else. **Driver eligibility is still 17 and
wiring is still 15**; do not count tables in the `.inc` to measure this stage's
progress.

#### Stage 5a tail — retire the bespoke trainer-sight hook

- [ ] **When all 17 standard maps dispatch to `TrainerMapScript`, delete the sight gate
      in `OverworldLoopLessDelay` together with `CheckTrainerSight` and
      `TrainerEncounterFlow` (`src/engine/overworld/map_sprites.asm:1075` and `:1197`)
      and both `DEVIATION`s.** All three are then dead code, and leaving them linked is
      itself the divergence this plan removes.

      The port-only pair is a second, bespoke sight path predating the driver; on a
      wired map both were armed and the bespoke one won the race. Battle work
      (`f36dd6bf`) landed the gating: the hook is skipped when
      `MapScriptPointers[wCurMap] == TrainerMapScript`, keyed on `TrainerMapScript`
      specifically and **not** on `!= DefaultMapScript` — PALLET_TOWN already has a
      non-default non-trainer script and Stage 5b adds many more, every one of which the
      naive predicate would have silently disabled the hook on.

      **The coupling to watch, because this plan is what can break it:** the gate is
      data-driven off the table `WIRED_MAPS` emits, so each wire shrinks the hook's
      domain with no edit on either side. That holds only while "wired" means "points at
      `TrainerMapScript`". If a Stage 5b map ever needs a different entry point while
      still carrying trainer headers, re-check the predicate in `map_sprites.asm`
      **before** it lands.

      **Do not read the `route*_sight` goldens as evidence the gate works** — they drive
      `RunMapScript`, not `OverworldLoop`, which is exactly why they are insensitive to
      it. They are a regression floor. The witness is `trainer_battle_route` (id 51),
      green since 2026-08-05.

### Stage 5b — story legs (bespoke scripts)

**Prerequisite MET 2026-08-05:** live trainer battles set the beaten flag on the real
loop path (`TRAINER_BATTLE_LIVE` is retired), gated by `trainer_battle_route` (id 51).

- [ ] **Pallet/Viridian:** Oak's Lab starter/rival flow, Route 1, Viridian City and
      Mart, Oak's Parcel round trip.
- [ ] **Forest/Pewter:** Viridian Forest, Pewter City/Gym, Route 2, gates, museum/gym
      scripted movement.
- [ ] **Mt. Moon/Cerulean:** Mt. Moon, Cerulean, Nugget Bridge, Bill.
- [ ] Continue in story order through Vermilion/S.S. Anne, Rock Tunnel/Lavender,
      Celadon, Fuchsia/Safari, Saffron/Silph, Cinnabar, Victory Road, Indigo. Each batch
      registers its map scripts and `text_asm` overrides, generates all text/data, and
      ends with a deterministic state scenario plus a live traversal.
- [ ] In the Route 12/16 batches, consume the fight events written by the item-owned
      Poké Flute handler and hand off to battle-completion for Snorlax. Do not duplicate
      the flute effect in map scripts.
- [ ] Viridian's catching tutorial, Pokémon Tower's Ghost Marowak and the Safari story
      batches seed/consume map state here, while battle-completion Stages 4b–4d own the
      battle behaviour. Each side needs its own must-hit evidence.

**Script linkability, measured 2026-08-17:** 199 of the 225 translated files in
`dos_port/src/scripts/` resolve every symbol they reference, up from 160 that morning.
Linkable is necessary but not sufficient — only 16 of 249 maps dispatch to anything
other than `DefaultMapScript`, so wiring is what Stage 5b is actually about.

## Stage 6 — retirement and archival

- [ ] Remove temporary guards and stand-ins whose real providers landed; run
      `label_status --callers` for every retired stub; update the label DB; run both
      lint modes plus `fidelity_gate`; and sweep related `STUB`, `TODO`,
      extern-provider, allowlist, plan, skill and stigmergy claims. Archive only after
      the generated plan inventory reports no open items here.

## Fidelity and acceptance

The manifest is the authority and this section is deliberately not a roster —
`python3 dos_port/tools/generators/gen_scenario_registry.py --names full`, or read
`dos_port/tools/scenario_manifest.json`. As of 2026-08-17 it holds 85 scenarios, of
which these are overworld-facing: `overworld_pallet` and `sign_pallet` (core), the 15
wired-map goldens, `ledge_hop`, `surf_round_trip`, `fish_old_rod` and
`trainer_battle_route`.

**Two limits of the `route*_sight` goldens, neither visible from a green run:**

1. **They stop AT engagement.** Each asserts only that `w<Map>CurScript` left 0 and
   dumps there, so `DisplayEnemyTrainerTextAndStartBattle`, `StartTrainerBattle` and
   battle entry are untested by them. Not hypothetical: the port was measured exiting
   silently on exactly that stretch on ROUTE_3, a defect every sight golden stays green
   over. A green sight golden means that map's trainer ENGAGEMENT state matches, not
   that its trainer flow works.
2. **They drive `RunMapScript`, not `OverworldLoop`** — a regression floor for the
   bespoke-sight gate rather than a witness of it, and wram-only, so they compare no
   rendered tiles.

**Not covered by anything today** (measured against all 85 must-hit lists, 2026-08-17):
Oak's Pallet cutscene, the service menus, hidden events, item pickup, itemfinder, Cut,
Strength/boulder, Fly, Flash, Dig, Teleport, Softboiled, and any warp.

For each remaining capability:

1. Establish providers/callers with `project_state` and `label_status`, then inspect
   conditional guards and indirect tables directly.
2. Run `fidelity_gate` for the changed files and justify every ADDED/DROPPED call in
   the commit message.
3. Add or extend a deterministic scenario whose must-hit markers identify the changed
   dispatcher and the downstream behaviour being claimed.
4. Run targeted `goldencheck`, the core tier, and `fidelity-full` when the affected
   surface is long-tail. Run `goldens-verify` whenever scenario or golden artifacts
   change.
5. Use live DOSBox-X for continuous choreography, movement, warps and story traversal
   that no single terminal dump can represent, and report it as visually observed
   rather than golden-matched.
