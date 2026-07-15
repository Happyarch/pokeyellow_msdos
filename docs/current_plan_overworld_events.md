# Current Plan: Overworld Events — story scripts and interaction services

Status: **the script/event foundation, sign milestone, and Pallet Oak-intro
state-machine code are complete.** The remaining work is the real
`DisplayTextID` service closure, active Oak-intro golden coverage, hidden
interactions and pickups, the unfinished field-move tails, the per-map story
rollout, and the final stub/claim sweep. Archive this file to
`docs/plans/overworld_events.md` when those stages are complete.

This status was refreshed 2026-07-15 against the linked build,
`dos_port/tools/project_state`, the 19-scenario fidelity manifest, and the
operational evidence policy in `AGENTS.md`. Superseded execution narratives
remain in git history instead of being maintained here.

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
- `docs/current_plan_items.md` owns `ItemUse*` bodies and item-subsystem helpers,
  including `ItemUseSurfboard`, `SurfingAttemptFailed`, `ItemUseItemfinder`, and
  `HiddenItemNear`. This plan owns map/event data and dispatch,
  `IsSpriteInFrontOfPlayer2`, movement consumers, and story-script consumers.
  `docs/current_plan_battle_completion.md` Stage 1 owns trainer-battle
  activation/exit and victory-dependent beaten flags; Stage 4 owns special
  battle-type behavior. Map scripts seed battle state, hand off, and consume
  results without duplicating battle logic.

## Completed foundation

- [x] Event flags, generated event constants, generated map text tables,
      `ShowTextStream`, `RunMapScript`, `CallFunctionInTable`, and the default
      per-map no-op dispatch are linked.
- [x] Pallet Town has the first linked `_Script`/`text_asm` skeleton and is the
      only map registered with a non-default script. Its Oak cutscene states
      0–8 now have Stage 1 code; state 9 remains the no-op tail.
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
      a disabled scaffold as `tools/mgba_harness/scenarios/oak_intro.lua.disabled`
      and a `disabled_scenarios` manifest entry, but the active golden is still
      open because the generated mGBA WRAM state was not valid evidence. Use
      live DOSBox-X only for continuous choreography not captured by the dump.

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

Text remains the critical Stage 2 dependency. `DisplayTextID` is still
check-only while the linked default-build provider is the `home_stubs.asm`
stand-in, so Stage 1 used a Pallet-local `DisplayPalletTownTextID` shim plus
generated runtime strings for the Oak lines. Replace that shim with the real
`DisplayTextID` closure when Stage 2 lands the text-script service. Also note
that `ShowTextStream` currently waits for A/B even when
`wDoNotWaitForButtonPressAfterDisplayingText` is set, so Oak's first
"Hey! Wait!" line is functionally shown but does not yet match pret's
auto-advance timing.

`PlayerStepOutFromDoor` now stores the pret-style `wJoyIgnore` mask before
arming the simulated one-step PAD_DOWN sequence and relies on
`AreInputsSimulated.doneSimulating` to clear it. Preserve that ownership model if
Stage 2 touches text/input waits.

The Oak intro test hook is deliberately retained but not registered as active
golden evidence. `DEBUG_OAK_INTRO` still builds and calls `RunOakIntroTest`, and
the attempted mGBA scenario is preserved as
`tools/mgba_harness/scenarios/oak_intro.lua.disabled` with a disabled manifest
entry. Re-enable it only after the title/new-game route and GBSTATE projection
produce a valid committed golden; `goldens-verify` executes every active
`*.lua` scenario.

`project_state DisplayTextID` reports the translated implementation check-only;
`label_status --callers DisplayTextID` reports the linked stand-in in
`home_stubs.asm`. `DisplayTextIDInit` is linked, but the full closure is not:
`Joypad`, mart, nurse, vending, cable, Safari, Pikachu, prize-service handlers,
and four far-text streams still lack default-build providers.

- [ ] Reconcile the port's flat map-text table with pret's `wCurMapTextPtr`
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
- [ ] Enable the guarded PC script dispatch only after checking current targets:
      `PlayerPC` and `ActivatePC` are linked, `BillsPC_` is a linked stub, and
      `CeladonPrizeMenu` is missing. Retire `M72_OVERWORLD_TEXTSCRIPTS`; keep
      genuinely unavailable services as structured subsystem stubs rather than
      preserving the blanket guard.
- [ ] Add vending, prize, Safari, Pikachu, and cable tails in their owning
      order. Cable-club behavior remains Phase 4; its structured stand-in must
      state that lifetime explicitly.

## Stage 3 — hidden interactions and ground items

The sign half of `hidden_events.asm` is live. The deeper hidden-event/bookshelf
half remains under `M72_HIDDEN_EVENTS_DEEP`; do not describe it as linked merely
because static scanning can see its definitions.

- [ ] Generate hidden-event map/coordinate/argument data from pret into
      `assets/hidden_events.inc`, keep per-object handlers in Tier-2 code, resolve
      the deep tier's real callees, remove the guard, and wire
      `CheckForHiddenEventOrBookshelfOrCardKeyDoor` in pret interaction order.
- [ ] Publish the generated `HiddenItemCoords` interface for the items plan.
      That plan promotes `itemfinder.asm` and retires `ItemUseItemfinder`;
      acceptance must hit both nearby-unobtained and nothing-nearby outcomes
      without consuming or setting the hidden-item flag during a test.
- [ ] Port `PickUpItem`, promote the check-only `GiveItem` provider, generate
      pickup text, hide the object, update inventory and event state, and route
      `PickUpItemText` through the live text-script path. Verify successful and
      bag-full pickup outcomes on a real map object.

## Stage 4 — remaining field-move and boulder tails

- [ ] **Cut:** promote `WriteOAMBlock`, port the missing
      `AdjustOAMBlock{X,Y}Pos` primitives, link `AnimCut`/`UsedCut`, and replace
      the party-menu no-op tail. All OBJ tile writes must invalidate
      `tile_cache` through `CopyVideoData` or `g_tilecache_dirty`.
- [ ] **Fly:** port `ChooseFlyDestination` on the linked Town Map foundation,
      restore the existing warp tail, and verify destination selection through
      arrival rather than stopping after flag arming.
- [ ] **Surf:** supply `IsSpriteInFrontOfPlayer2` and prove that the normal
      overworld loop consumes the simulated forward step. The items plan owns
      `ItemUseSurfboard`, `SurfingAttemptFailed`, mount/dismount, and arming that
      step. Joint acceptance verifies party-menu selection, forced movement,
      graphics, collision, music, and `wWalkBikeSurfState` in both directions.
- [ ] **Strength/boulders:** promote `TryPushingBoulder` and
      `DoBoulderDustAnimation`, wire the map-script/collision consumer, and test
      a permitted push plus a blocked push. The linked `PrintStrengthText` only
      arms the state; it is not proof that a boulder moved.
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

The current manifest supplies two overworld-facing core scenarios:

| Scenario | Must-hit evidence | What it proves |
|---|---|---|
| `overworld_pallet` | `LoadCurrentMapView`, `DumpBackbuffer` | deterministic Pallet map/render state |
| `sign_pallet` | `DisplaySignText` | streamed sign dialog, tile/VRAM/OAM/WRAM projection |

Neither scenario proves Oak's cutscene, service menus, hidden events, pickups,
field moves, trainer/story scripts, or later maps.

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
