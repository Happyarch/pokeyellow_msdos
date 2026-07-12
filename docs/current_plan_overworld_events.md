# Current Plan — Overworld Events (per-map scripts + interaction dispatch)

Status: **not started** — tick stages as they land. Archive to
`docs/plans/overworld_events.md` when complete.

Absorbs and supersedes `docs/current_plan_script_engine.md` (its Stages 1–6 —
event flags, ShowTextStream, RunMapScript dispatch, Pallet skeleton — are DONE
and carried forward here; its "Next milestone" Oak-intro spec is this plan's
Stage 1). Ground truth for the gap list: the 2026-07-12 code survey (Makefile
linked-vs-check state + stub files), NOT TODO.md.

## Scope boundaries (interfaces to the sibling plans)

- **Items plan** (`current_plan_items.md`) owns `UseItem_`/`ItemUsePtrTable` and
  every `ItemUse*` handler. Nothing here forks its own item-use dispatch: the
  mart SELL path and field-item pickups call inventory/money routines directly
  (already linked); Itemfinder/rods/bicycle USE entry points are items-plan
  work even though their overworld halves land here.
- **Battle plan** (`current_plan_battle_completion.md`) owns
  `BATTLE_TYPE_PIKACHU` behavior, trainer-battle de-gating
  (`TRAINER_BATTLE_LIVE` — note the default build currently marks trainers
  beaten *without fighting*, see that plan), and Safari battle mechanics. Our
  scripts only seed `wCurOpponent`/`wBattleType`/`wCurEnemyLevel` and hand off.
- Tracking: `dos_port/tools/work_queue` claims/wire/verify +
  `stub add --kind <…>` for deferrals, per the script-engine plan's workflow.
  Every pret-labeled routine passes `faithdiff` + `lint_pret_labels` before
  commit. All human-readable text is Tier-1 generated (`gen_npc_dialogs.py`
  SCRIPT_OVERRIDES / sibling `gen_*.py` → `assets/*.inc`) — never hand-encoded
  charmap bytes.

## Stage 1 — Oak intro cutscene (reference milestone; validates the pattern)

Port all 10 `PalletTown.asm` `_Script` states + `PalletTownOakText` in one
pass, replacing the `ret`-stubs `PalletTownDefaultScript`
(`src/scripts/pallet_town.asm:95`) and `PalletTown_CutsceneStub` (`:100`,
backing 8 pointer-table slots). Dependencies verified real 2026-07-10:
scripted-NPC-movement engine (`DoScriptedNPCMovement`, `MoveSprite`/
`MoveSprite_`, pathfinding, `PalletMovementScript_*` + RLELists in
auto_movement), `_InitBattleCommon`, `EnableAutoTextBoxDrawing`,
`StopAllMusic`/`PlayMusic`, `ShowObject`/`HideObject`,
`CalcPositionOfPlayerRelativeToNPC`, `FindPathToPlayer`, `EmotionBubble`,
`CheckBothEventsSet`/`SetEventReuseHL`.

**Integration risks (from the absorbed plan — verify live, don't trust blind):**
- `MoveSprite` selector: the port's `GetSpriteMovementByte1Pointer` reads
  `H_CURRENT_SPRITE_OFFSET` (0xFFDA) as a **pre-multiplied byte offset**
  (slot×$10), not pret's raw `hSpriteIndex` slot → write `slot*$10`; confirm
  whether the port's `MoveSprite` swaps first (cross-check
  `trainer_engine.asm:505-511` `MoveSprite_`). Pathfinding uses
  `H_NPC_SPRITE_OFFSET` (0xFF95, unions `hNPCPlayerYDistance`).
- Dialog dispatch: the port routes NPC dialog through TextTable SCRIPT entries
  / `ShowTextStream`, not pret `hTextID`→TextPointers — verify the cutscene's
  `DisplayTextID` uses reach `PalletTownOakText`.
- `BATTLE_TYPE_PIKACHU`: seed `wCurOpponent=STARTER_PIKACHU`,
  `wBattleType=BATTLE_TYPE_PIKACHU`, `wCurEnemyLevel=5`; the forced-opponent
  overworld path fires the battle. Until the battle plan lands the special
  type, it runs as a plain wild flow — record with
  `work_queue stub add --kind battle` (already recorded on fn 4398).
- ABI cheatsheet (verified): `PlayMusic` AL=music id, BL=audio bank;
  `SetEventReuseHL`≡`SetEvent`; `H_JOY_HELD`=0xFFB4, `W_JOY_IGNORE`=0xCD6B,
  `W_PLAYER_MOVING_DIRECTION`=0xD527, `W_Y_COORD`=0xD360/`W_X_COORD`=0xD361,
  `PLAYER_DIR_UP`=8, `SPRITE_FACING_UP`=$04/`LEFT`=$08/`RIGHT`=$0C,
  `TOGGLE_PALLET_TOWN_OAK`=0, `wNPCMovementDirections2`=0xCC97,
  `W_NPC_MOVEMENT_SCRIPT_FUNCTION_NUM`=0xCF10/`_BANK`=0xCC58,
  `wStatusFlags5` bit `BIT_SCRIPTED_NPC_MOVEMENT`=0.

Execution: gate the `PalletTownDefaultScript` trigger body behind
`%ifdef DEBUG_OAK_INTRO` (default build = today's free-roam, zero regression);
live-test the whole chain via the flag + Oak spawn; drop the gate once
verified.

- [ ] 1a. Port states 0–8 + `PalletTownPikachuBattleScript` seed; assemble +
      link; `DEBUG_OAK_INTRO` gate on the trigger.
- [ ] 1b. Live verify (dosbox-mcp): breakpoint `DoScriptedNPCMovement`,
      `gb_read wNPCMovementDirections2`, `dump_frame` per step; final
      FRAME.BIN shows Oak + player walked to the Lab; event flags advance
      `EVENT_FOLLOWED_OAK_INTO_LAB`. Report to the overworld-port plan's
      Stage 8 runtime-regression item (OW-2.5 spec).
- [ ] 1c. Drop the debug gate; `faithdiff` each pret-labeled state;
      translation-log entries.

## Stage 2 — DisplayTextID special cases (marts / Centers / PCs)

Promote `src/home/text_script.asm` (faithful body, currently
`HOME_CHECK_SRCS`) to linked and **delete** the `home_stubs.asm:54`
`DisplayTextID` ret-stub (dup-global link error makes the collision loud —
Makefile:930 note). Closure per Makefile:930-935: `Joypad` (bind to the port's
ISR-backed joypad wrapper), 4 Tier-1 far-text labels (generator), and 8
dispatch targets, staged:

- [ ] 2a. Link prep: `Joypad` shim + far-text generation; reconcile the file's
      ADDRESSING MODEL CAVEAT (map text tables vs the port's SCRIPT-entry
      dialog path) — decide and document whether `DisplayTextID` becomes the
      real NPC path or stays special-cases-only alongside
      `CheckNPCInteraction`.
- [ ] 2b. **Mart**: port `DisplayPokemartDialogue_` (buy/sell loops). Already
      in place: `DoBuySellQuitMenu` chrome (`text_box.asm:380`), generated
      `MartInventories`/`MartPointers`/prices (`assets/items.inc`),
      `GetItemPrice`, BCD money math. Link
      `src/engine/items/subtract_paid_money.asm` (ITEMS_CHECK_SRCS) and
      resolve the `PRICEDITEMLISTMENU` mart anchor TODO
      (`home/list_menu.asm:463`). Buy path ends at `AddItemToInventory_`;
      sell at `RemoveItemFromInventory_` + `AddAmountSoldToMoney_`.
- [ ] 2c. **Pokémon Center**: `DisplayPokemonCenterDialogue_` (nurse heal —
      `HealParty` exists via blackout path) + `TextScript_PokemonCenterPC`.
- [ ] 2d. **PCs**: `TextScript_ItemStoragePC` / `TextScript_BillsPC` (Bill's
      PC logic `bills_pc.asm` is ported; this is the dialog/dispatch shell).
- [ ] 2e. **Vending machines** (`VendingMachineMenu`) + tails: stub
      `TextScript_GameCornerPrizeMenu`, `CableClubNPC` (Phase 4),
      `PrintSafariGameOverText`, `TalkToPikachu` in a `*_stubs.asm` with
      `work_queue stub add` records; retire `overworld_text.asm`'s
      `M72_OVERWORLD_TEXTSCRIPTS` guard once the linked dispatch subsumes it.

## Stage 3 — Signs

`SignLoop`/`CopySignData` are linked and correct (`home/hidden_events.asm:32`,
sign data populated by `overworld.asm:2766`) with **zero callers**. Wire the
A-press path per the routine's own INTEGRATION note (`hidden_events.asm:98-104`):
in `OverworldLoop` alongside `CheckNPCInteraction` — skip if `W_NUM_SIGNS`==0,
facing coords → DH/DL, `call SignLoop`, CF=1 → font/freeze setup →
`DisplaySignText` (`overworld_text.asm:54`). Sign text = Tier-1 via the dialog
generator.

- [ ] 3a. A-press wire + one map's sign text end-to-end (Pallet's sign already
      renders via NPC path — regression-check it).
- [ ] 3b. Headless FRAME.BIN scenario: walk to a sign, press A, dump.

## Stage 4 — Hidden objects & bookshelves

Code exists behind `M72_HIDDEN_EVENTS_DEEP` (`hidden_events.asm:181-418`,
never defined in the Makefile). Missing: the data table + generator.

- [ ] 4a. `tools/gen_hidden_events.py` → `assets/hidden_events.inc`
      (`HiddenObjectMaps`/pointers from pret `data/events/hidden_objects.asm`),
      two-tier: coordinates/ids generated; per-object *handlers* are Tier-2
      code labels.
- [ ] 4b. Define the guard → retire it (promote the block to default
      assembly); wire `CheckForHiddenEventOrBookshelfOrCardKeyDoor` into the
      A-press path (ordering vs signs/NPCs per pret).
- [ ] 4c. Add `src/engine/items/itemfinder.asm` to the Makefile (currently
      orphaned — in no SRCS list); the USE entry point stays items-plan.

## Stage 5 — Item balls on the ground

- [ ] 5a. Port `PickUpItem` (pret `engine/events/pick_up_item.asm`) — ball
      sprite hide (`HideObject` exists), `GiveItem`, "found ITEM!" text
      (generated), event flag set.
- [ ] 5b. Link `src/home/give.asm` (HOME_CHECK_SRCS): export
      `CopyToStringBuffer`; `_GivePokemon` may stay stubbed (record it) —
      `GiveItem` is the needed half.
- [ ] 5c. Wire `PickUpItemText` (`overworld_text.asm:160` deferral) into the
      TextTable SCRIPT-entry path; verify on Viridian Forest's items live.

## Stage 6 — Field-move execution

The single chokepoint: `start_sub_menus.asm:248` `STUB(field-effects)` — the
party-menu selection re-enters the menu. Port pret's
`.choseOutOfBattleMove`/`.outOfBattleMovePointers` dispatch with
`wObtainedBadges` gating + refusal texts (generated).

- [ ] 6a. Dispatch + **Cut** first (already coded+linked, just unreachable):
      promote its blockers per Makefile:919-927 — `home/vcopy.asm`
      (SaveScreenTilesToBuffer2/Load…2), `home/oam.asm` (WriteOAMBlock),
      `cut2.asm`/`dust_smoke.asm` (need `AdjustOAMBlock{X,Y}Pos` — small OAM
      primitives from pret animations.asm, port standalone),
      `field_move_messages.asm` (PlayCry → audio engine is live, wire it).
- [ ] 6b. **Surf** (`UsedSurf`/`IsSurfingAllowed` — unported; water-tile
      collision + `wWalkBikeSurfState`; player_gfx surf sprites already
      generated) and **Strength** (`UsedStrength`/`PrintStrengthText` +
      boulder gating; `push_boulder.asm` is the generic mechanic, check-only;
      `run_map_script.asm:12` defers `TryPushingBoulder`/
      `DoBoulderDustAnimation` — un-defer here).
- [ ] 6c. **Fly** (`ChooseFlyDestination` — town_map.asm is check-only,
      "intentionally dangling"; link it), **Flash**, **Dig/Teleport**
      (share `SwitchAndTeleportEffect_`'s warp machinery), **Softboiled**.
      Stub what's blocked, record each.
- [ ] 6d. `player_animations.asm` promotion (EmotionBubble/LoadAnimSpriteGfx
      blockers) rides with whichever of 6a–6c first needs it.

## Stage 7 — Per-map script rollout (batched, story order)

Pattern per map: pret `scripts/<Map>.asm` → `src/scripts/<map>.asm`
(`_Script` state machine + `text_asm` handlers), register in
`gen_map_scripts.py` + `gen_npc_dialogs.py` SCRIPT_OVERRIDES, text via the
generator, `work_queue` claim→wire→verify, stub-record anything
battle/items-blocked.

- [ ] 7a. Batch 1 — Pallet story tail: Oak's Lab (starter/rival flow),
      Route 1, Viridian City + Mart (Oak's Parcel round-trip).
- [ ] 7b. Batch 2 — Viridian Forest, Pewter City + Gym (first badge;
      needs trainer battles live from the battle plan), Route 2/gates.
- [ ] 7c. Batch 3 — Mt. Moon → Cerulean (Nugget Bridge, Bill).
- [ ] 7d. Batch 4+ — continue in story order (Vermilion/S.S. Anne, Rock
      Tunnel/Lavender, Celadon, Fuchsia/Safari, Saffron/Silph, Cinnabar,
      Victory Road, Indigo). Re-batch as reality dictates; each batch is its
      own commit series with a live-walkthrough verification of that leg.

## Ride-alongs

- [ ] `PlayerStepOutFromDoor` omits pret's `wJoyIgnore` set
      (`overworld.asm:3294-3297` TODO home-rectify M3.3) — re-add once
      multi-step simulated-joypad scripts drain via `.doneSimulating`
      (Stage 1's cutscene work touches exactly this machinery).
- [ ] Cross-ref (battle plan): trainers currently get flagged beaten without
      fighting (`map_sprites.asm` TRAINER_BATTLE_LIVE gate) — Stage 7b's gym
      batch depends on that fix.

## Verification (every stage)

1. `make -C dos_port` + `make -C dos_port check` green; `lint_pret_labels`
   exit 0; `faithdiff` per pret-labeled routine (justify divergences in the
   commit message).
2. Headless FRAME.BIN scenario per feature (the DEBUG_* seed-flag harness);
   goldencheck suite stays green.
3. Live spot-check in DOSBox-X for anything input-driven (signs, marts, PCs,
   cutscenes) — dosbox-mcp breakpoints for state machines. Breakpoints/
   `where()` resolve symbolically (pret labels incl. NASM local labels, e.g.
   per-state `_Script` targets), and `pkmn.sym` auto-refreshes on rebuild —
   no server restart needed between iterations on a multi-state script.
4. `update_label_db` after each stub add/retire.
