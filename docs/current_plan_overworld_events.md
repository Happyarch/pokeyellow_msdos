# Current Plan: Overworld Events — story scripts and interaction services

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

Status: **the script/event foundation, sign milestone, Pallet Oak-intro
state-machine code, core `DisplayTextID` dispatcher, all of Stage 3 (hidden
interactions, hidden-item coords, ground-item pickup), and Stage 4's
Strength/boulder and Cut tails are complete.** The remaining work is active
Oak-intro golden coverage, the real overworld service dialog bodies, the Fly/Surf
field-move tails, the per-map story rollout, and the final stub/claim sweep.
Archive this file to `docs/plans/overworld_events.md` when those stages are
complete.

This status was refreshed 2026-07-16 against the linked build,
`dos_port/tools/project_state`, the 19-scenario fidelity manifest, and the
operational evidence policy (now in **both** `CLAUDE.md` and `AGENTS.md` — it had
been AGENTS-only since 2026-07-14, so Claude Code sessions never saw it; see
stigmergy `claude-md-agents-md-are-separate-files-that-drift`). Superseded execution
narratives remain in git history instead of being maintained here.

**Re-stamped 2026-08-02**: a maintainer-directed re-measurement against generated
state (`project_state --no-scan`, `label_status --callers`, `faithdiff`, the
scenario manifest, and stigmergy) reconciled every open item and corrected two
over-claims (Stage 1 Oak-intro "SUPERSEDED"/Fly commit status — both false in the
"already done" direction) plus several stale sub-claims (`BillsPC_`, the Surf
bullet's file path and caller count, `RunMapScript`'s location, the fidelity
table). This was NOT new work — no build, rescan, or gate was run.

**Evidence caveat carried forward:** several Stage 3/4 bullets are `[x]` with their
must-hit runtime scenarios openly deferred, because nothing in the current build
state can reach them (no item ball, no ITEMFINDER, no Strength, no boulder map).
`[x]` here means *linked and structurally verified*, not *executed* — each such
bullet names what still owes evidence and when it lands. Do not upgrade those to
"working" without the scenario.

## Standing rules and ownership

- Preserve pret labels and control/data flow. Human-rendered dialog is generated
  Tier-1 data (`gen_npc_dialogs.py` or the appropriate sibling generator);
  `_Script` state machines, `text_asm` tails, dispatch tables, and handlers are
  hand-written Tier-2 code.
- Before asserting that a dependency is missing, stubbed, check-only,
  unreachable, or callerless, rerun `dos_port/tools/project_state` and use
  `label_status --callers/--callees` when provider splits matter. Inspect `%ifdef`
  guards directly: static scanning can see a definition that the default build
  excludes.
- For changed pret code, run `dos_port/tools/fidelity_gate --base <base>`.
  A clean result means only "no detected structural divergence"; each behavior
  change also needs a must-hit runtime scenario proving that path executed.
- The completed items plan (`docs/plans/items.md`) delivered `ItemUse*` bodies
  and item-subsystem helpers, including `ItemUseSurfboard`,
  `SurfingAttemptFailed`, `ItemUseItemfinder`, and `HiddenItemNear`. This plan owns map/event data and dispatch,
  `IsSpriteInFrontOfPlayer2`, movement consumers, and story-script consumers.
  `docs/current_plan_battle_completion.md` Stage 1 owns trainer-battle
  activation/exit and victory-dependent beaten flags; Stage 4 owns special
  battle-type behavior. Map scripts seed battle state, hand off, and consume
  results without duplicating battle logic.

## Completed foundation

- [x] Event flags, generated event constants, generated map text tables,
      `ShowTextStream`, `RunMapScript`, `CallFunctionInTable`, and the default
      per-map no-op dispatch are linked.
- [x] Pallet Town has the first linked `_Script`/`text_asm` skeleton. Its Oak
      cutscene states 0–8 now have Stage 1 code; state 9 remains the no-op tail.
      It is no longer the only registered map: `assets/map_scripts.inc` has 4
      non-default rows of 249 — PALLET_TOWN plus ROUTE_3/ROUTE_6/ROUTE_11, which
      run the generic data-driven `TrainerMapScript` landed by the archived
      `docs/plans/map_script_fidelity.md` (COMPLETE 2026-07-24). Stage 5 should
      register new maps through `gen_map_script_tables.py`, not per-map skeletons.
- [x] Scripted NPC movement, pathfinding, `MoveSprite`, simulated joypad support,
      and the per-map movement-script table are linked. They are infrastructure,
      not evidence that a story cutscene has executed.
- [x] Sign interaction is live through the A-press path:
      `IsSpriteOrSignInFrontOfPlayer` → `SignLoop` → `DoSignInteraction` →
      `DisplaySignText`. The `sign_pallet` scenario golden-matches this path.
- [x] The party-menu field-move dispatcher, badge gates, and linked paths for
      Strength, Flash, Dig, Teleport, and Softboiled are present. Cut, Fly,
      Surfboard, and boulder movement remain open below.
- [x] `player_animations.asm`, `LoadAnimSpriteGfx`, screen-buffer helpers, Town
      Map, `PlayerPC`, and `ActivatePC` are linked. Do not reuse the old
      check-only/linkage claims for them.

## Stage 1 — Oak intro and Pallet state machine

- [x] Replace `PalletTownDefaultScript` and the shared
      `PalletTown_CutsceneStub` with pret's states 0–8, keeping state 9 as the
      real no-op. Wire the north-exit trigger, Oak approach, player/Oak scripted
      movement, dialog, Lab transition, Pikachu battle seed, and post-battle
      state advancement.
- [x] Preserve the port's movement ABI: sprite selectors use the verified
      pre-multiplied slot offset where the linked helpers expect it, and
      multi-step paths drain through the linked simulated-input machinery.
      Reconcile `PlayerStepOutFromDoor`'s deferred `wJoyIgnore` store in this
      workstream rather than leaving two scripted-input ownership models.
- [x] Keep the cross-plan boundary explicit: the script seeds
      `wCurOpponent`, `wBattleType`, and `wCurEnemyLevel`; battle-completion
      Stage 4a supplies faithful `BATTLE_TYPE_PIKACHU` behavior, while Stage 1
      supplies battle exit/result semantics. Do not report the cutscene complete
      while that handoff still degrades to a plain wild battle.
- [ ] Add a deterministic Oak-intro scenario whose must-hit list names the
      Pallet state(s) and scripted movement consumer, and whose terminal state
      compares event/script variables plus the rendered scene. Stage 1 preserved
      a disabled scaffold, but the active golden is still
      open because the generated mGBA WRAM state was not valid evidence.
      **RETRACTED 2026-08-02 — the previous "SUPERSEDED: the scenario is ENABLED
      and PASSING" note was a NAME COLLISION, and this bullet is still open.**
      The Pallet scaffold `oak_intro.lua.disabled` was DELETED, not re-enabled:
      `7338860c` ("menu-intro A4") added a different `oak_intro.lua` and its own
      commit message says it "removed the stale oak_intro.lua.disabled (navigated
      the Pallet overworld Oak event, a different thing)". The active row id 29
      gates on `DEBUG_OAKINTRO` (→ `RunOakSpeechCheckpoint`, Prof. Oak's opening
      speech) with `must_hit = OakSpeech / PrepareOakSpeech / FadeInIntroPic /
      DisplayPicCenteredOrUpperRight` — no Pallet script state, no scripted-movement
      consumer. This plan's hook is the SEPARATE gate → `RunOakIntroTest`, still
      unregistered. A new scenario is owed, under a name that does not collide.
      **The gate was RENAMED 2026-08-02 and is now `DEBUG_PALLET_OAK`, not
      `DEBUG_OAK_INTRO`** — measured 2026-08-04 in the tree:
      `dos_port/Makefile:659` is `$(eval $(call dump_gate,DEBUG_PALLET_OAK))`, its
      harness body is `RunOakIntroTest` (`src/debug/debug_dump.asm:452-486`), and
      `DEBUG_OAK_INTRO` appears nowhere in the Makefile. The rename IS the fix for
      the one-underscore collision this bullet describes; `make DEBUG_OAK_INTRO=1`
      now silently builds a normal image.

## Stage 2 — `DisplayTextID` and overworld service dialogs

### Stage 1 handoff for Stage 2 — 2026-07-15

Stage 1 replaced Pallet's shared cutscene stub with real state labels 0–8 in
`dos_port/src/scripts/pallet_town.asm`; `PalletTownNoopScript` remains state 9.
The script now handles the north-exit trigger, Oak appearance/approach,
scripted movement setup/drain, Daisy object toggles, and Pikachu battle seeding
through `wBattleType = BATTLE_TYPE_PIKACHU`, `wCurOpponent = STARTER_PIKACHU`,
and `wCurEnemyLevel = 5`. Battle-completion still owns the faithful special
Pikachu battle behavior and battle exit/result semantics; do not claim the full
cutscene as complete until that cross-plan handoff is closed.

Text remains a critical Stage 2 dependency for the remaining service menus, but
the core `DisplayTextID` dispatcher now links in the default build from
`dos_port/src/home/text_script.asm`; the old `home_stubs.asm` stand-in is
retired. The Stage 1 Pallet-local `DisplayPalletTownTextID` shim is gone; the
Oak text-bearing states now call the shared dispatcher and the generated Pallet
text table includes the script-only `TEXT_PALLETTOWN_OAK_COME_WITH_ME` row. Also
note that `ShowTextStream` currently waits for A/B even when
`wDoNotWaitForButtonPressAfterDisplayingText` is set, so Oak's first
"Hey! Wait!" line is functionally shown but does not yet match pret's
auto-advance timing.

`PlayerStepOutFromDoor` now stores the pret-style `wJoyIgnore` mask before
arming the simulated one-step PAD_DOWN sequence and relies on
`AreInputsSimulated.doneSimulating` to clear it. Preserve that ownership model if
Stage 2 touches text/input waits.

The Oak intro test hook is deliberately retained but not registered as active
golden evidence. The gate still builds and calls `RunOakIntroTest`, and
the attempted mGBA scenario was preserved as a
`.disabled` scaffold. **That re-enabling did NOT happen** — see the retraction on
the Stage 1 scenario bullet above: the scaffold was deleted and its filename reused
by the menu-intro plan for the Prof. Oak *opening speech* golden. The gate
/ `RunOakIntroTest` are still live and still unregistered. `goldens-verify` executes
every active `*.lua` scenario.

**The gate's NAME here is stale: it is `DEBUG_PALLET_OAK` as of 2026-08-02, not
`DEBUG_OAK_INTRO`** (see the Stage 1 bullet above for the measurement). Every
`DEBUG_OAK_INTRO` in this section is history, not a command you can run.

`project_state DisplayTextID` reports the translated implementation linked, and
`label_status --callers DisplayTextID` reports the real `text_script.asm`
provider. `DisplayTextIDInit`, flat map-text table lookup, the ISR-backed
wait/hold path, and the four far-text streams are linked. The Stage 2 service
tails are not done: mart, nurse, vending, cable, Safari, Pikachu, and
prize-service handlers resolve through structured owning-subsystem stubs until
the bullets below replace them with real providers.

### Stage 2 handoff for service-tail work — 2026-07-15

The shared text dispatcher is no longer the blocker. `DisplayTextID` links from
`dos_port/src/home/text_script.asm`; `home_stubs.asm` no longer provides a
ret-only shadow, and `pret_label_allowlist.json` no longer needs a duplicate-def
allowance for it. The ordinary map-text branch reads the generated flat
`w_map_text_table_ptr` rows, while the `TEXT_PREDEF` branch still uses
`wCurMapTextPtr` so `PrintPredefTextID` keeps the pret pointer-table path.

> **UPDATE 2026-07-28 — that TEXT_PREDEF branch does not work, and cannot as
> written.** It is a faithful 16-bit GB-address-space pointer walk, but the port's
> text streams are flat program-image data and `SetMapTextPointer` stores only the
> low 16 bits of `ESI`. Nothing exercises it today (`PrintPredefTextID` is
> unlinked, so nothing sets `BIT_TEXT_PREDEF`), which is why it has never
> surfaced. Do **not** unblock it by supplying a flat `dd` `TextPredefs` table —
> that links cleanly and is runtime garbage. Owner:
> `docs/current_plan_predef_text.md`. Related fix already landed: `5f7aebff`
> corrected `.readFirstByte`, which was reading the ordinary path's *flat* `ESI`
> as `[ebp + esi]`.

Pallet's local text shim is retired. `PalletTownOakHeyWaitScript`,
`PalletTownOakGreetsPlayerScript`, and `PalletTownAfterPikachuBattleScript` call
the shared dispatcher directly. `gen_npc_dialogs.py` now emits rows through the
highest referenced text id, so script-only ids such as
`TEXT_PALLETTOWN_OAK_COME_WITH_ME` are generated data, not hand-maintained table
entries.

The old blanket `M72_OVERWORLD_TEXTSCRIPTS` guard is gone. `TextScript_*` PC and
prize dispatch now assembles unconditionally; genuinely unfinished services are
explicit stubs in their owning subsystem: `DisplayPokemartDialogue_`,
`DisplayPokemonCenterDialogue_`, `VendingMachineMenu`, `CeladonPrizeMenu`, and
`CableClubNPC` in `src/engine/menus/main_menu_stubs.asm`, plus `TalkToPikachu`
and `PrintSafariGameOverText` in `src/engine/overworld/overworld_stubs.asm`.

Verification from the Stage 2 closure: `make -C dos_port`, `make -C dos_port
assets`, `dos_port/tools/update_label_db`, `dos_port/tools/lint_pret_labels`,
`dos_port/tools/project_state DisplayTextID`, `dos_port/tools/label_status
--callers DisplayTextID`, `make -C dos_port goldencheck
SCENARIO=overworld_pallet`, and `make -C dos_port goldencheck
SCENARIO=sign_pallet` all passed. The broad `fidelity_gate --base HEAD` is still
not useful in the dirty tree because it includes unrelated pre-existing
overworld/menu diffs; run focused `faithdiff` for any service label you change
and add a must-hit runtime scenario for the behavior.

- [x] Reconcile the port's flat map-text table with pret's `wCurMapTextPtr`
      lookup, bind the ISR-backed joypad interface, generate the missing far
      text, link `text_script.asm`, and retire the stand-in plus all stale extern
      provider trails.
- [ ] Port `DisplayPokemartDialogue_` and the buy/sell transaction loops using
      the linked item data, price helpers, inventory routines, and BCD money
      math. Add a mart scenario that must hit the service dispatcher and both a
      successful and refusal transaction path.
- [ ] Port `DisplayPokemonCenterDialogue_`, the nurse heal flow, and the
      Pokémon Center PC shell. Verify party healing and the rendered dialog,
      not merely entry into the menu.
- [x] Enable the guarded PC script dispatch only after checking current targets:
      `PlayerPC` and `ActivatePC` are linked; `BillsPC_` is now a REAL implementation
      (`src/engine/pokemon/bills_pc.asm`, commit `0c9afce5`, covered by the
      `bills_pc_ops` and `box_change_roundtrip` goldens), and
      `CeladonPrizeMenu` now has a structured menu stub. `M72_OVERWORLD_TEXTSCRIPTS`
      is retired; genuinely unavailable services are structured subsystem stubs
      rather than hidden behind the blanket guard.
- [x] Replace the remaining blanket service guards / sentinel-byte fallbacks
      with structured owning-subsystem stubs for vending, prize, Safari,
      Pikachu, and cable. Cable-club behavior remains Phase 4, and its stand-in
      states that lifetime explicitly.
- [ ] Port vending, prize, Safari, Pikachu, and cable tails in their owning
      order, replacing those structured stubs with real providers and adding
      must-hit runtime scenarios for each observable behavior.

## Stage 3 — hidden interactions and ground items

The sign half of `hidden_events.asm` was already live. As of Stage 3 bullet 1 the
deep hidden-event/bookshelf tier is now **linked** (the `M72_HIDDEN_EVENTS_DEEP`
guard is gone) and wired into the A-press path in pret order.

### Stage 3 bullet-1 handoff — 2026-07-16

`tools/generators/gen_hidden_events.py` generates `assets/hidden_events.inc`
(`src/data/hidden_events_data.asm`) from `data/events/hidden_events.asm`: the flat
`HiddenEventMaps` dispatch table (81 maps; pret's `db map / dw ptr` becomes
`db map / dd ptr`, so `CheckForHiddenEvent` now uses `IsInArray` stride **5**, not
the old placeholder 3) and every `HiddenEventsFor_<map>` list (213 entries;
`db y / db x / db arg / db 0 / dd handler`). Args (item ids, facings, `COIN+n`,
slot/quiz constants, predef text ids) are resolved to numeric bytes from pret's
constant files.

The 35 distinct per-object handlers are Tier-2 ret-stubs in
`src/engine/overworld/hidden_object_stubs.asm` (each documents which subsystem/map
retires it). `PrintBookshelfText`'s stub is functional — it sets
`hInteractedWithBookshelf = $ff` ("no bookshelf") so the sprite/sign scan still
runs; a plain `ret` there would silently suppress NPC/sign interaction.
`JumpToAddress` (`jp hl` → `jmp esi`) is real in `src/home/bankswitch.asm`;
`GetTileAndCoordsInFrontOfPlayer` was already linked.
`CheckForHiddenEventOrBookshelfOrCardKeyDoor` is called **first** on A-press
(overworld.asm), returning to `OverworldLoop` when `hItemAlreadyFound == 0` and
falling through to the sign/NPC scan otherwise.

Verification: `make -C dos_port`, `goldencheck overworld_pallet` + `sign_pallet`
(both PASS — `sign_pallet` proves the new dispatch falls through to the sign path
without regression), `lint_pret_labels` (0 violations; `JumpToAddress` relocation
and `StartSlotMachine` dup_def added to the allowlist with retirement notes),
`faithdiff` on `CheckForHiddenEvent`/`CheckForHiddenEventOrBookshelfOrCardKeyDoor`/
`JumpToAddress`/`OverworldLoop` (all clean or register-map/pre-existing). No
reachable map has a hidden event in the current build state (OAKS_LAB etc. gate
behind the Oak cutscene / later story), so a hidden-event-specific must-hit
scenario lands with the first reachable hidden-event map in Stage 5. The two open
bullets below (HiddenItemCoords / itemfinder; PickUpItem — a **separate** visible
item-ball system) are unaffected.

- [x] Generate hidden-event map/coordinate/argument data from pret into
      `assets/hidden_events.inc`, keep per-object handlers in Tier-2 code, resolve
      the deep tier's real callees, remove the guard, and wire
      `CheckForHiddenEventOrBookshelfOrCardKeyDoor` in pret interaction order.
- [x] Publish the generated `HiddenItemCoords` interface for the items plan.
      That plan promotes `itemfinder.asm` and retires `ItemUseItemfinder`;
      acceptance must hit both nearby-unobtained and nothing-nearby outcomes
      without consuming or setting the hidden-item flag during a test.
- [x] Port `PickUpItem`, promote the check-only `GiveItem` provider, generate
      pickup text, hide the object, update inventory and event state, and route
      `PickUpItemText` through the live text-script path. Verify successful and
      bag-full pickup outcomes on a real map object.

### Stage 3 bullet-2/3 handoff — 2026-07-16

**Bullet 2 (HiddenItemCoords + itemfinder cross-cut):** `tools/generators/gen_hidden_item_coords.py`
generates `assets/hidden_item_coords.inc` (`HiddenItemCoords`, 55 rows, `db map,y,x`
+ `db -1`; pret's `hidden_item` macro swaps the source x,y so the stored order is
map,y,x — HiddenItemNear reads d=y, e=x). It is `%include`d by
`src/data/hidden_events_data.asm` and reuses `gen_hidden_events.parse_map_ids`.
The itemfinder half was a **cross-cut into `docs/plans/items.md`** (recorded
there): `src/engine/items/itemfinder.asm` (`HiddenItemNear`/`Sub5ClampTo0`) is now
linked (`ITEMS_SRCS`); `IsInRestOfArray` was promoted with `vcopy.asm` from
`HOME_CHECK_SRCS` to `HOME_SRCS`; and `ItemUseItemfinder` moved from the
`item_use_stubs.asm` ret-stub to a real body in `item_effects.asm`
(`farcall HiddenItemNear` → flat `call`; `jp PrintText` → the `iu_print_text`
overworld-projection tail; texts `ItemfinderFound{Item,Nothing}Text` already
generated in `item_text.inc`).

**Bullet 3 (PickUpItem):** `src/engine/events/pick_up_item.asm` ports `PickUpItem`
(predef `HideObject` → direct `call`; `predef PickUpItem`-in-`PickUpItemText` →
direct `call` — no predef dispatcher in the port). `PickUpItemText` is live in
`overworld_text.asm` (`call PickUpItem` / `jmp TextScriptEnd`, matching pret's
`predef PickUpItem / jp TextScriptEnd`; the text_asm dispatch discards the tail
stream). `hToggleableObjectIndex` (== `hInteractedWithBookshelf`, $FFDB) added to
`gb_memmap.inc`. `home/give.asm` promoted intact to `HOME_SRCS`
(`CopyToStringBuffer` was already `global`); its dead-but-referenced `GivePokemon`
resolves through a new `_GivePokemon` ret-stub
(`src/engine/events/give_pokemon_stubs.asm`). Pickup text
(`FoundItemText`/`NoMoreRoomForItemText`) is generated by `tools/generators/gen_pickup_text.py`
→ `assets/pickup_text.inc` (wrapped by `src/data/pickup_text.asm`). The pret
`sound_get_item_1` jingle rides past the far text's TX_END and, like every other
port text-stream sound, is not played (documented TODO-HW).

Verification: `make -C dos_port` clean (all six new/promoted `.o` link);
`lint_pret_labels` 0 violations (5 suppressed); `goldencheck overworld_pallet` +
`sign_pallet` PASS (`sign_pallet` proves the shared DisplayTextID/text_asm path
still dispatches after the `overworld_text.asm` edit); `faithdiff` on `PickUpItem`,
`PickUpItemText`, `GiveItem` clean, and on `ItemUseItemfinder` / `HiddenItemNear`
only the documented predef→`FlagAction` and `jp PrintText`→`iu_print_text`
deviations. **No runtime must-hit yet:** no reachable map in the current build has
an item ball, and ITEMFINDER is not obtainable, so both must-hit scenarios (pickup
success/bag-full; itemfinder near/nothing) land with the first reachable map that
uses them (Stage 5 for PickUpItem; an items-plan scenario for itemfinder).

## Stage 4 — remaining field-move and boulder tails

**Boulder/Strength is DONE (2026-07-16) — see the boulder-bullet handoff below.** It
also landed the shared OAM-animation substrate (`AdjustOAMBlock{X,Y}Pos(2)`,
`WriteOAMBlock`, `cut.asm`/`cut2.asm` linked), which the Cut bullet's first three
sub-items depended on. **Cut is DONE too (2026-07-16) — the party-menu tail is wired;
see the Cut-bullet handoff.** Remaining: **Fly, Surf**, plus must-hit coverage for the
already-linked Flash/Dig/Teleport/Softboiled paths — and the Stage 5 scenarios that
owe the boulder and cut cutscenes their first actual execution.

- [x] **Cut:** ~~promote `WriteOAMBlock`, port the missing
      `AdjustOAMBlock{X,Y}Pos` primitives, link `AnimCut`/`UsedCut`~~ (all DONE by
      the boulder bullet — the dust animation shares that OAM substrate; see the
      Stage 4 boulder handoff), ~~and replace the party-menu no-op tail~~ (DONE —
      see the Cut handoff below). All OBJ tile writes must invalidate `tile_cache`
      through `CopyVideoData` or `g_tilecache_dirty`.
      **Wired, NOT executed: the cut-animation / tree-tile-replacement must-hit is
      NOT met and cannot be met in the current build state — see the handoff.**
- [~] **Fly:** `ChooseFlyDestination` is ported and the `.canFly` warp tail is
      restored; the Town Map fly-target UI, destination selection, the fly-away
      LEAVE animation, and the wide-canvas bird trajectory all work live. **The
      ARRIVAL still page-faults** in the `DEBUG_SEED_PARTY` harness — NOT met, and
      suspected to be a debug-seed/new-game (title-screen) player-state artifact
      rather than a Fly-logic bug. See the Fly-bullet handoff below.
      **CORRECTED 2026-08-02: it is COMMITTED** — the wiring landed in `b3b31345`
      (2026-07-25, swept in by a pathspec commit) and the page-fault fix in `64400890`
      (2026-07-26). The "commit only after arrival verifies" gate was never honoured, so
      this code is in every green run since and NOTHING in the 37-row manifest exercises
      Fly, Teleport, Dig or any warp. A warp/Fly scenario is the retirement. See stigmergy
      `overworld-events-stage4-fly-arrival-open` (v3).
- [ ] **Surf:** ~~supply `IsSpriteInFrontOfPlayer2`~~ (DONE — the boulder bullet ported
      it as the long-range entry point of `IsSpriteInFrontOfPlayer`; it now lives in
      `src/home/overworld.asm` (moved there by the mirror-consolidation relocation
      chunks) and measures `implementation / linked / 2 callers /
      statically-reached-from-start` — it already EXECUTES on the A-press counter-tile
      branch (`IsSpriteOrSignInFrontOfPlayer` `je` at :2024, plus the
      `IsSpriteInFrontOfPlayer` fallthrough at :2030). What is still missing is the
      SURF consumer, not the routine.
      pret's consumer is `ItemUseSurfboard` at `engine/items/item_effects.asm:725`,
      which sets `d` = the long talking range before calling it — under the port's
      register map that is **DH**, and the count/pointer contract is on the routine's
      header) and prove that the normal overworld loop consumes the simulated forward
      step. The items plan owns `ItemUseSurfboard`, `SurfingAttemptFailed`,
      mount/dismount, and arming that step. Joint acceptance verifies party-menu
      selection, forced movement, graphics, collision, music, and
      `wWalkBikeSurfState` in both directions.
- [x] **Strength/boulders:** promote `TryPushingBoulder` and
      `DoBoulderDustAnimation`, wire the map-script/collision consumer, and test
      a permitted push plus a blocked push. The linked `PrintStrengthText` only
      arms the state; it is not proof that a boulder moved.
      **Linked and wired; the push/blocked-push must-hit is NOT met — see the
      Stage 4 boulder handoff below for exactly what is and is not proven.**
- [x] **Ledges: DONE 2026-08-03 (`3f0afc9e`), gated by the `ledge_hop` golden
      (id 41, tier `full`, class `datastruct`).** Re-verified in-tree 2026-08-04:
      `call HandleMidJump` is live at `dos_port/src/home/overworld.asm:953`, and
      the manifest row `ledge_hop` carries
      `must_hit = HandleLedges / HandleMidJump / _HandleMidJump` with
      `build_flags = DEBUG_LEDGE=1`. Repro: `make -C dos_port goldencheck
      SCENARIO=ledge_hop`.
      **The fix was THREE defects, not the one this bullet recorded** — the other
      two were found BY the scenario, which is the argument for the
      "no scenario, no wire" rule in miniature:
      1. the dropped `call HandleMidJump` (the only one predicted here);
      2. `CollisionCheckOnLand`'s whole
         `CheckForJumpingAndTilePairCollisions`/`HandleLedges` block sat behind
         `%ifdef OVERWORLD_LEDGES`, **defined in no build**, so on land the hop
         never even ARMED (its comment blamed an unlinked `ledges.asm` — which
         was in `GAME_SRCS` all along: the confident-comment defect class again);
      3. the port consumed `BIT_SCRIPTED_MOVEMENT_STATE` after ONE scripted step,
         freezing the hop's second queued press; pret drains it only in
         `AreInputsSimulated.doneSimulating`.
      The `BUG{class=temporary}` tag this bullet cited is deleted. Memory
      `regression-overworld-ledge-hop-never-advanced` is closed FIXED; the golden
      suite, not prose, is the currency mechanism from here.
      Residual cosmetic tail (NOT this bullet, and not claimed done): the hop ARC
      is not drawn and `LoadHoppingShadowOAM` is still a ret-stub — compositor
      work, tracked as `docs/current_plan_backlog.md` #29's last bullet.

### Stage 4 boulder-bullet handoff — 2026-07-16

**What landed.** `push_boulder.asm` + `dust_smoke.asm` + `cut.asm` + `cut2.asm` moved
`HOME_CHECK_SRCS` → `GAME_SRCS`, and `home/oam.asm` → `HOME_SRCS`. Four blockers were
resolved to get there:
1. `IsSpriteInFrontOfPlayer` (+ the `IsSpriteInFrontOfPlayer2` entry point) was
   `missing`; ported beside `IsSpriteOrSignInFrontOfPlayer` (both now in
   `src/home/overworld.asm` after the mirror consolidation; originally
   `src/engine/overworld/overworld.asm`), the sign branch of the same pret routine.
2. `AdjustOAMBlock{X,Y}Pos(2)` were `missing`; ported into their pret home
   `src/engine/battle/animations.asm` (shared by cut + boulder dust). The Y variant
   carries pret's `BUG{}` — it writes 160 to the PREVIOUS OAM entry's attribute.
3. `DiscardButtonPresses` — see the tooling trap below.
4. `WriteOAMBlock` (check-only) promoted; the Makefile note claiming
   `SaveScreenTilesToBuffer2`/`LoadScreenTilesFromBuffer2` blocked `cut.asm` was
   **stale** (Stage 3's `vcopy.asm` promotion already linked them).

**Decomposition closed (cross-cut into `docs/plans/current_plan_script_engine.md`,
recorded there).** `RunMapScript` was a skeleton; it now runs pret's full per-frame
chain internally — `TryPushingBoulder` → \[dust\] → `RunNPCMovementScript` →
`_Script` (`home/overworld.asm:1712`) — and `OverworldLoop` no longer calls
`RunNPCMovementScript` itself. `faithdiff RunMapScript` now matches 3/3 calls, and
`OverworldLoop`'s ADDED set dropped from 3 to 2. This also fixed a silent divergence
in `AllPokemonFainted`, which pret gives the whole chain but the skeleton gave only
the dispatch. Still open: no `JoypadOverworld` (faithdiff `missing` + ADDED on
`OverworldLoop`), and `SwitchToMapRomBank` (TODO-HW).

**Tooling trap worth carrying (stigmergy `label-db-wrong-provider-on-inlined-routines`).**
`project_state DiscardButtonPresses` reported `unlisted, provider=src/engine/joypad.asm`
— a **confident wrong provider** pointing at a DEAD file (in no SRCS list, unlinkable:
it ends in `jmp Joypad`, undefined in the port). The routine was in fact live all along,
INLINED into the ISR edge layer as the local label `.discard` in `src/input/joypad.asm`.
"unlisted" read as "unported". It was extracted into a real global there (one
realization; the port-input-model DEVIATION is unchanged). This is a THIRD shape of the
faithdiff gap, distinct from relocation/decomposition: the call site never moved and the
routine was not split — it stopped existing as a callable symbol while its body lived on
inside a differently-named host.

**Update 2026-07-27 (`33fc5137`): the "wrong provider" is now the RIGHT one, and the
trap it illustrates is gone at this site.** `src/engine/joypad.asm` is no longer dead —
it was repaired (%include path, pret-lowercase HRAM operands, the undefined `jmp Joypad`
target) and put in the build, and `DiscardButtonPresses` was moved out of
`src/input/joypad.asm` into it, which is its pret mirror. So `provider=src/engine/joypad.asm`
is now correct. **The generic lesson still holds** and is what this section is for: the
provider picker reported a confident path with no build check behind it, and the reader
supplied the "therefore unported" conclusion. Keep reading it as a lead, not a verdict.

**Evidence — what is and is not proven.** `make -C dos_port` links all five promoted
objects; `lint_pret_labels` 0 violations (6 suppressed; the `IsSpriteInFrontOfPlayer{,2}`
mirror + `DiscardButtonPresses` relocation/dup_def are allowlisted with retirement
notes); `faithdiff` on every touched label shows only documented classes (TODO-HW
banking, `jp hl`→flat-table dispatch, the slot<<4 selector convention, and two known
faithdiff blind spots: it does not count conditional jumps, so `ResetBoulderPushFlags`
reads DROPPED though `jz`/`jne`/`jnz` reach it, and it matches stores by name, so pret's
`set BIT_x, [hl]` surfaces as an ADDED named store). `goldencheck overworld_pallet` +
`sign_pallet` both PASS — `overworld_pallet` is the load-bearing one here, proving the
rebuilt `OverworldLoop`/`RunMapScript` per-frame chain did not regress.
**NO must-hit for the push itself, and the bullet's "permitted push plus blocked push"
acceptance is therefore NOT satisfied.** Evidence for why it cannot be today: nothing
can arm `BIT_STRENGTH_ACTIVE`, and no reachable map carries a boulder object, so
`TryPushingBoulder` returns at its first `test` every frame. The code is **linked and
executing per-frame**, not **executed** in the push sense.
(This bullet originally cited `project_state PrintStrengthText` = "not-statically-reached"
as part of that evidence; that was the tooling artifact described below, now fixed —
it reads `statically-reached-from-start`. The two facts above are what carry the
conclusion, and they are unchanged.) Both must-hits land with the
first reachable Strength/boulder map (Stage 5 — Seafoam/Victory Road), exactly as the
Stage 3 pickup/itemfinder must-hits were deferred.

**Left for the Stage 4 Cut bullet.** `cut.asm`/`cut2.asm` are linked for the OAM
primitives the dust shares, so `UsedCut`/`AnimCut` are now linked but had no caller —
that bullet still owns replacing the party-menu no-op tail. ("still unreachable" as
originally written was an unsupported negative: the tool could not see the subtree at
all. See the TOOLING TRAP section below.) Its "port the missing
`AdjustOAMBlock{X,Y}Pos` primitives" and "promote `WriteOAMBlock`" sub-items are done.

### Stage 4 Cut-bullet handoff — 2026-07-16

**What landed.** `StartMenu_Pokemon.cut` (`src/engine/menus/start_sub_menus.asm`) is
pret's real tail: `call UsedCut` → `wActionResultOrTookBattleTurn` → `jz .loop` /
`jmp CloseStartMenu`. `UsedCut` went from **0 callers to 1**, and it left
`StartMenu_Pokemon`'s faithdiff DROPPED set. Three sub-items beyond the literal tail:

1. **`jp CloseTextDisplay` → `jmp CloseStartMenu` is PERMANENT, not a linkage stopgap.**
   Do not "fix" this later. pret runs its whole START menu inside `DisplayTextID`'s
   frame (`dict TEXT_START_MENU, DisplayStartMenu`), which pushed `hLoadedROMBank`;
   `CloseTextDisplay`'s closing `pop af` is that push's partner. The port opens the
   menu straight from `OverworldLoop` under its own `pushad`/`popad`
   (`home/start_menu.asm:11`), so jumping there would eat a pushad register and
   return through it. The neighbouring `.goBackToMap` DEVIATION claimed
   `evidence=CloseTextDisplay check-only` / `lifetime=until text_script.asm links` —
   **that lifetime was reached in Stage 2 and the claim was stale**; both are
   rewritten to the permanent stack-model reason. `home/start_menu.asm:35-38` had
   already found this independently; the two now agree.
2. **Party-menu compositor teardown, projected into `UsedCut` (`cut.asm`, `.canCut`).**
   pret's `UsedCut` leaves the party screen for the map at exactly that point
   (`GBPalWhiteOutWithDelay3` / `RestoreScreenTilesAndReloadTilePatterns` /
   `LoadGBPal` / `LoadCurrentMapView`) — and *only* on `.canCut`; `.nothingToCut`
   prints on the party screen and returns, which is why pret's zero result resumes
   `.loop`. On the GB that teardown is complete; in the port `DisplayPartyMenu` also
   raised `g_bg_whiteout` + the window list, and the BG composites only when
   `g_bg_whiteout` is clear, so the whole cutscene would have run behind a whited
   screen under stale party windows. The same omission at `.goBackToMap` returned
   STRENGTH/FLASH/DIG/TELEPORT to a blank screen when observed live 2026-07-13.
   Placement mirrors `.exitMenu`/`.goBackToMap` verbatim (after `Restore…`, before
   `LoadGBPal`), incl. `LoadTilesetTilePatternData` (the party HP-bar patterns sit in
   the BG tileset slots and `Restore…` reloads only map SPRITE tiles). `UsedCut` has
   exactly one caller in pret too (`start_sub_menus.asm:158`), so this strands nobody.
   **This block is UNVERIFIED** — reasoned from a documented port invariant, not
   observed. It is the first thing the Stage 5 must-hit should confirm or correct.
3. **`.nothingToCut` now sets `text_msgbox = msgbox_dialog`** before its `jmp
   PrintText`, like every sibling refusal that prints on this screen
   (`.newBadgeRequired`, `.cannotFlyHereText`, `.notHealthyEnoughText`). Without it
   `PrintText` inherits whatever the last owner left. Latent-in-a-never-linked-file,
   exactly the class as the boulder bullet's `dust_smoke.asm` `CL`/`BL` bug.

**TOOLING TRAP — `project_state` reachability is a FALSE NEGATIVE across ~63% of the
port. Never cite `not-statically-reached` as evidence that anything is unreachable.**
Root cause established 2026-07-16 (full detail + measurements in stigmergy
`project-state-reachability-false-negative-overworld-menu-subtree`):

`project_state` (`tools/project_state:111`) BFSes from the single root `start` over
`calls` edges, and those edges come from `update_label_db`'s `PORT_CALL_RE`
(`tools/update_label_db:121`), which matches **only** explicit `call`/`jmp`/`j??`
mnemonics. **A fall-through is not an instruction** — when execution crosses a label
boundary by plain sequential execution there is no mnemonic to match, so no edge
exists. It is unrepresentable in the scanner's model, not a regex bug.

The boot chain into the entire game world is exactly that shape:

```
start --call--> Init --jmp--> EnterMapBoot --FALL--> EnterMap --FALL--> OverworldLoop --FALL--> OverworldLoopLessDelay
```

(`overworld.asm:427` "fall into EnterMap", `:939` "fall through to OverworldLoop",
`:969` "OverworldLoop falls through into OverworldLoopLessDelay (pret)"; line numbers
as of 2026-07-16 — measured 2026-08-02, the file has since been reorganised:
`EnterMap:214`, `OverworldLoop:799`, `OverworldLoopLessDelay:816`). The BFS
reaches `EnterMapBoot`, follows its explicit `call`s, and dies at the fall-through:
`EnterMapBoot` reachable, `EnterMap` — the very next instruction — not. Measured over
the live DB: 385 labels reachable; adding just that ONE edge → 948; adding all three
boot-chain fall-throughs → 1046. **Three missing edges dark 661 labels.**

A second, smaller class: data-table dispatch (`dd Label` in a table, `jmp esi` /
`jmp [tbl+ecx*4]`) is equally invisible — `PickUpItemText` is reached only from a map
text_asm pointer table, so `PickUpItem` stays dark even after the fall-through repair.
Map script tables, `HiddenEventMaps` handlers and `.outOfBattleMovePointers` are all
this shape.

The irony worth carrying: the port falls through pervasively (65+ commented instances)
**because pret does** — it is a core SM83 idiom and this project's hard rule is to
preserve pret's control flow. **The metric under-reported precisely where the port was
most faithful.** Use `callers` — that is the field that actually moved here
(`UsedCut` 0 → 1) — plus `label_status --callers`, which names the call site and line.

Retroactive: the boulder handoff cited `PrintStrengthText` = "linked but
not-statically-reached" as evidence that nothing arms `BIT_STRENGTH_ACTIVE`. That
inference is **not supported** — `PrintStrengthText` flips to reachable the moment the
fall-through edges are added. Its *conclusion* still stands, but only on the separate
ground that no reachable map carries a boulder.

### RESOLVED 2026-07-16 — the trap is fixed; the lesson is not retired

`docs/plans/label_db_reachability.md` landed the repair. The scanner now
evaluates NASM conditionals over the real member set (asked of GNU Make itself) and
emits proven `kind='fallthrough'` edges; reachable pret labels went **181 → 742**
(the tool's reported population — "385 → 1051" is BFS *nodes* with the `linked`
provider filter dropped, corrected by the plan's round-8 Amendment 10), all
three boot-chain edges exist, and every label named above — `UsedCut`,
`PrintStrengthText`, `StartMenu_Pokemon`, `DisplayTextID`, `OverworldLoop` — now reads
`statically-reached-from-start`. The values were renamed
(`static-live-entry` → `statically-reached-from-start`, `not-statically-reached` →
`not-proven-reached`) to stop the negative reading as "unreachable".

**What still holds, and is now permanent:** the second class above — `dd Label`
dispatch tables and address-taken operands — is a documented v1 gap, not a bug to
rediscover. `PickUpItemText`, map script tables, `HiddenEventMaps` handlers,
`.outOfBattleMovePointers`, and both ISRs (PIT, keyboard) stay `not-proven-reached`
while provably live. **`not-proven-reached` is still never proof of unreachability**;
`--callers` and runtime evidence remain the fields to cite.

This is a FOURTH shape of the faithdiff/label-DB gap, after relocation /
decomposition / inlining: the routine is genuinely called, and the tool reports it
unreached because the edge that reaches it is a fall-through or a table dispatch and
the scanner models neither.

**Evidence — what is and is not proven.** `make -C dos_port` clean;
`update_label_db`; `lint_pret_labels` **0 violations** (6 suppressed, unchanged — no
new allowlist entry needed); `faithdiff UsedCut` **16/16 pret calls matched**, sole
ADDED = the documented `LoadTilesetTilePatternData` projection (the ADDED
`[W_STATUS_FLAGS_5]` store is the known match-stores-by-name blind spot — pret's
`set BIT_NO_TEXT_DELAY,[hl]`; the `g_*` compositor writes are port-only globals, not
GB stores, so faithdiff correctly ignores them); `faithdiff StartMenu_Pokemon`
25/31 matched with every DROPPED/ADDED either documented here or owned by the open
Fly bullet (`ChooseFlyDestination`, `LoadFontTilePatterns`) or a known blind spot
(`jp hl` → flat table); `goldencheck overworld_pallet` + `sign_pallet` both **PASS**.
**The bullet's must-hit (cut animation + tree-tile replacement) is NOT met.** Every
line added is behind the `CASCADEBADGE` gate plus a mon knowing CUT, so a normal
build's behavior is unchanged — which is what the goldens confirm, and is the honest
ceiling on this session's evidence.

**Cheapest next evidence step (found this session, not yet built).** `DEBUG_PARTY=1`
(`src/engine/debug/debug_party.asm:113`) grants `wObtainedBadges = ~(1 <<
BIT_EARTHBADGE)` — **CASCADEBADGE included** — and gives Snorlax (party slot 0) all
four HM moves incl. CUT. So the **refusal path is executable today**: a `DEBUG_CUT`
harness modelled on `RunTMHMTest`/`RunPartyMenuTest` (`src/debug/debug_dump.asm`) —
`PrepareNewGameDebug` → `LoadFontTilePatterns` → `StartMenu_Pokemon`, with
`AutoKeyDrive` selecting Snorlax → CUT — would execute `UsedCut` for real in Pallet,
take `.nothingToCut` (Pallet has no `$3d` tree), and prove the tail dispatches, the
refusal prints, and the zero-result `.loop` return does not unbalance the pushad
frame. It cannot prove sub-item 2 above (the teardown is on `.canCut`) or the
animation/tile swap — **those need a map with a cut tree, i.e. Stage 5 (Viridian).**

### Handoff to the next Stage 4 session — 2026-07-16

**Start here.** Boulder and Cut are closed; **two bullets remain (Fly, Surf)** plus the
Flash/Dig/Teleport/Softboiled must-hit coverage. Read the Cut handoff above before
either: its `CloseTextDisplay` finding and the reachability trap both apply directly.
Do not re-derive the OAM substrate; read `src/engine/battle/animations.asm` first.
`ChooseFlyDestination` is the one genuinely `missing` routine in the whole field-move
dispatch — everything after it in `.canFly` is linked.

**Register contract you must not get wrong.** `AdjustOAMBlock{X,Y}Pos(2)` take **BL** =
pret's `c` (entry count) — the project map is BC→BX. `dust_smoke.asm` shipped `CL` and
was a latent bug precisely because it had never linked; `cut2.asm` already had it right.
The non-`2` entries take the pointer in **EDX** (pret `de`) and copy it to ESI; the `...2`
entries expect **ESI** already loaded.

**Do not trust these three claims — they were stale/wrong and are now corrected, but the
same class will recur:**
1. The Makefile's "remaining check-only blockers" prose (it claimed
   `SaveScreenTilesToBuffer2`/`LoadScreenTilesFromBuffer2` blocked `cut.asm`; Stage 3's
   `vcopy.asm` promotion had already linked them).
2. `docs/plans/current_plan_script_engine.md` located `RunMapScript` at
   `src/engine/overworld/run_map_script.asm`; this plan then corrected that to
   `src/home/run_map_script.asm`, and **that is now stale too** — measured
   2026-08-02, `project_state RunMapScript` reports
   `dos_port/src/home/overworld.asm` (its pret mirror). `src/home/run_map_script.asm`
   still exists but now defines only `DefaultMapScript`, and its file header still
   describes RunMapScript as if the body were there. Two corrections in a row got the
   path wrong: read the provider, do not copy it from prose.
3. `project_state DiscardButtonPresses` still names a DEAD file as provider (see the
   tooling trap above). **Rerun `project_state` per this plan's standing rules, but when
   a provider looks wrong, check the file's own header and the Makefile lists before
   believing it** — the DB cannot see inlined bodies, and `relocated_labels` does not
   redirect its provider pick.

**Owed must-hits, tracked so they are not silently dropped:** permitted push / blocked
push (boulder bullet, → Stage 5 Seafoam/Victory Road); cut animation + tree-tile
replacement (Cut bullet, → Stage 5 Viridian — plus the unverified party-menu teardown
projection inside `UsedCut`, which that scenario must confirm or correct); Stage 3's
pickup success/bag-full and itemfinder near/nothing. None are reachable in the current
build state; all are honest deferrals, not claimed coverage. The one piece of *executable*
evidence identified but not yet built is the `DEBUG_CUT` refusal-path harness (see the
Cut handoff).
### Stage 4 Fly-bullet handoff — 2026-07-17 (arrival OPEN; changes COMMITTED 2026-07-25/26 — see the bullet)

**What landed (gate-green; committed in `b3b31345` + `64400890`, not at the time this was written).** `ChooseFlyDestination`
ported into `dos_port/src/home/reload_tiles.asm` (res `BIT_NO_BATTLES`, tail-`jmp
LoadTownMap_Fly` — a `farjp`→flat banking DEVIATION); `.canFly` tail restored in
`start_sub_menus.asm` (`call ChooseFlyDestination` / test `BIT_FLY_WARP` / `LoadFontTilePatterns`+
`set BIT_UNKNOWN_4_1`+`jmp StartMenu_Pokemon`, else `Func_1510`+`.goBackToMap`). `LoadTownMap_Fly`
(the whole Town Map fly selector) was already a linked, faithful port. An `AUTOKEY_FLY`
scripted-input harness was added (`debug_dump.asm` + Makefile `DEBUG_AUTOKEY=1 AUTOKEY_FLY=1`;
also fixed the M-120-class hardcoded `AUTOKEY_DUMP_FRAME=160` in the DEBUG_AUTOKEY block).

**Verified LIVE (user-driven headed DEBUG_SEED_PARTY):** Town Map opens on FLY, destination
selection works, and after two downstream fixes the fly-away LEAVE animation plays with the
bird sweeping the wide canvas. Static gate green throughout (lint 0; `faithdiff LoadTownMap_Fly`
= only the two documented ADDED calls; `goldencheck overworld_pallet`+`sign_pallet` PASS).

**Two downstream bugs this exposed (both PRE-EXISTING in the never-executed special-warp
path), fixed:**
1. **Crash on leave + no-warp — FIXED.** `LoadTownMap_Fly.pressedB` skipped `ExitTownMap`, so
   the shared `W_TILEMAP` kept town-map tile IDs (≥ `MAP_TILESET_SIZE`) under the player;
   the next `UpdateSprites` (via `.goBackToMap`→`RestoreScreenTilesAndReloadTilePatterns`→
   `ReloadMapSpriteTilePatterns` tail-`jmp UpdateSprites`, BEFORE `CloseStartMenu`'s own
   `RefreshCollisionTileMap`) hit `UpdatePlayerSprite.disable` → `image index = 0xFF` →
   `InitFacingDirectionList`'s unbounded scan walked off GB memory (`cr2=0x5c2000`). Fix:
   `LoadTownMap_Fly.pressedB` now calls `ExitTownMap` + `RefreshCollisionTileMap` (mirrors
   `LoadTownMap_Nest`). `eax=0` in the fault dumps is CWSDPMI handler noise; the real index is `0xFF`.
2. **Bird trajectory on the wide canvas — FIXED.** `DoFlyAnimation` writes GB-screen coords
   into the slot-0 player sprite, which `PrepareOAMData` projects via signed `movsx +96` for
   the 320-wide canvas — so the pret coord bytes `≥ 0x80` (X up to `0xA0`) sign-wrapped to a
   negative canvas X (bird snapped to the left edge). Fix: rescaled the X columns of
   `FlyAnimationScreenCoords1/2` + `FlyAnimationEnterScreenCoords` to `≤ 0x7F`
   (`player_animations.asm`, projection DEVIATIONs).

**STILL OPEN — the ARRIVAL page-faults.** After the leave animation plays, the warp arrival
(`EnterMap`→`EnterMapAnim`→`InitFacingDirectionList`) still faults on a non-facing player
image index. Applied the port's own standing-pose precedent (image index = facing dir, anim
frame 0 — as in `map_sprites.asm:909` / `start_menu.asm:110`) at BOTH `EnterMapAnim` and
`_LeaveMapAnim` entry (this is the SHARED special-warp path, so it is intended to also cover
Teleport/Dig/Escape-Rope). **It did NOT stop the arrival fault.** Key contradiction to chase
next: the player walks fine in the seed overworld, so `wSpritePlayerStateData1FacingDirection`
(0xC109) IS a valid facing there — yet forcing image index from it doesn't prevent the arrival
crash. That means either the fault is at a different `InitFacingDirectionList` call than
assumed, or facing-dir/sprite state is specifically inconsistent on WARP ARRIVAL under the
debug seed. The user's read: the `DEBUG_SEED_PARTY`/new-game boot (no real title→new-game
route) leaves warp-arrival player state inconsistent — a proper title/new-game flow is the
likely prerequisite to verify/fix, and is **deferred to a future session**. The next session
should capture the arrival fault's exact `eip` in the current binary (addresses shifted after
these edits) and read `0xC102`/`0xC109` at the crash before deciding whether the standing-pose
additions are the right fix or should be reverted. `PrepareForSpecialWarp`/`SpecialEnterMap`
(`src/engine/overworld/special_warps.asm` — the code; the tables are the separate
`src/data/maps/special_warps.asm`) look complete and are NOT the suspect — they are simply never reached.

- [ ] Retain the already-linked Flash, Dig, Teleport, and Softboiled paths, but
      add must-hit coverage when their observable behavior is first claimed.
      For Dig and the item-owned Escape Rope handler, this plan owns the
      `HandleFlyWarpOrDungeonWarp`/arrival consumer and the end-to-end warp
      scenario. A generic menu or overworld regression run is not execution
      evidence.

## Stage 5 — story-ordered map rollout

- [ ] **Pallet/Viridian:** Oak's Lab starter/rival flow, Route 1, Viridian City
      and Mart, and Oak's Parcel round trip.
- [ ] **Forest/Pewter:** Viridian Forest, Pewter City/Gym, Route 2, gates, and
      museum/gym scripted movement. Requires trainer battles to be live without
      `TRAINER_BATTLE_LIVE` and to set beaten flags only after victory
      (battle-completion Stage 1).
- [ ] **Mt. Moon/Cerulean:** Mt. Moon, Cerulean, Nugget Bridge, and Bill.
- [ ] Continue in story order through Vermilion/S.S. Anne, Rock
      Tunnel/Lavender, Celadon, Fuchsia/Safari, Saffron/Silph, Cinnabar,
      Victory Road, and Indigo. Each batch registers its map scripts and
      `text_asm` overrides, generates all text/data, and ends with a deterministic
      state scenario plus a live traversal of the story leg.
- [ ] In the Route 12/16 batches, consume the fight events written by the
      item-owned Poké Flute handler and hand off to battle-completion for the
      Snorlax encounter. Do not duplicate the flute effect in map scripts.
- [ ] Viridian's catching tutorial, Pokémon Tower's Ghost Marowak, and Safari
      story batches seed/consume their map state here, while battle-completion
      Stages 4b–4d own the corresponding battle behavior. Each side needs its own
      must-hit evidence before the combined story leg is called complete.

## Stage 6 — retirement and archival

- [ ] Remove temporary guards and stand-ins whose real providers landed; run
      `label_status --callers` for every retired stub; update the label DB; run
      default and strict label lint plus `fidelity_gate`; and sweep related
      `STUB`, `TODO`, extern-provider, allowlist, plan, skill, and stigmergy
      claims. Archive this plan only after the generated plan inventory reports
      no open items here.

## Fidelity and acceptance

The current manifest supplies two overworld-facing core scenarios, plus three
`full`-tier scenarios covering the generic map-script trainer engagement:

| Scenario | Must-hit evidence | What it proves |
|---|---|---|
| `overworld_pallet` | `LoadCurrentMapView`, `DumpBackbuffer` | deterministic Pallet map/render state |
| `sign_pallet` | `DisplaySignText` | streamed sign dialog, tile/VRAM/OAM/WRAM projection |
| `route3_sight` / `route6_sight` / `route11_sight` (tier `full`, wram-only) | `TrainerMapScript`, `CheckFightingMapTrainers` | the generic map-script trainer-engagement STATE on three registered maps |
| `ledge_hop` (tier `full`, wram-only) | `HandleLedges`, `HandleMidJump`, `_HandleMidJump` | the Route 1 ledge hop + its state teardown, through the LIVE `OverworldLoop` on both sides |

**Do not read this table as the roster — it is a hand-maintained excerpt and has
been stale before.** The manifest is the authority; measure it:
`python3 dos_port/tools/generators/gen_scenario_registry.py --names full`.

None of these proves Oak's Pallet cutscene, service menus, hidden events, pickups,
field moves (Cut/Fly/Dig/Teleport/Flash/Softboiled/Strength), any warp, or
later map stories. **Ledges WERE on that list until 2026-08-03 and are not any
more** — `ledge_hop` (id 41) covers them; see the Stage 4 ledges bullet.
`oak_intro` in the manifest is the menu-intro plan's Prof. Oak
OPENING SPEECH, not this plan's Pallet cutscene.

For each remaining capability:

1. Establish current providers/callers with `project_state` and `label_status`,
   then inspect conditional guards and indirect tables directly.
2. Run `fidelity_gate` for the changed files and review every reported
   ADDED/DROPPED call; record required justifications in the commit message.
3. Add or extend a deterministic scenario whose must-hit markers identify the
   changed dispatcher/state and the downstream behavior being claimed. Compare
   WRAM and rendered surfaces according to what changed.
4. Run targeted `goldencheck`, the core tier, and `fidelity-full` when the
   affected surface is long-tail. Run `goldens-verify` whenever scenario or
   committed golden artifacts change.
5. Use live DOSBox-X for continuous choreography, movement, warps, and story
   traversal that cannot be represented by one terminal dump, and report it as
   visually observed rather than golden-matched.
