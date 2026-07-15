# Current Plan: Items Layer — finish the remaining USE handlers

Status: **Stages 1–10 and most of Stage 11 are complete.** The remaining item
work is Itemfinder, the three fishing rods, PP Up/PP restoration, Surfboard,
and the final stub-retirement sweep. Archive this file to
`docs/plans/items.md` when those items are complete.

This status was refreshed 2026-07-15 against the linked build,
`dos_port/tools/project_state`, the 19-scenario fidelity manifest, and the
operational evidence policy in `AGENTS.md`. Older completion narratives and
resolved blockers remain in git history rather than being maintained here.

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
  in-battle bag belongs to `docs/current_plan_battle_completion.md`.

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

- [ ] **Itemfinder.** `ItemUseItemfinder` is a linked ret-stub and
      `HiddenItemNear` is implemented but unlisted. The generated hidden-object
      coordinate/data layer does not yet exist. Overworld-events Stage 3 owns
      `HiddenItemCoords` and hidden-object A-press dispatch; once that data
      contract lands, this plan links `itemfinder.asm`, ports the USE handler,
      and verifies both "near" and "nothing" outcomes. See
      `docs/items_blockers.md` → Itemfinder.

- [ ] **Fishing rods.** This is ready item-layer work, not an external blocker:
      `FishingAnim` is linked and `ReadSuperRodData` is check-only. Promote
      `super_rod.asm`, port `FishingInit` plus the Old/Good/Super Rod handlers,
      and exercise no-bite and bite branches. The linked `EmotionBubble`
      stand-in only omits the cosmetic "!" bubble; its real translated body is
      still check-only with the trainer-engine closure.

- [ ] **PP Up and PP restoration.** This is ready item-layer work. The battle
      menu audit replaced the old battle-only move picker with pret-shaped
      `MoveSelectionMenu`/`SelectMenuItem`, including `wMoveMenuType = 2` and
      the party-mon relearn menu. Port `ItemUsePPUp` and `ItemUsePPRestore`,
      retire both stubs, and preserve/tag pret's Max Ether/Max Elixer PP-Up-bit
      no-effect bug. Existing `move_selection` coverage exercises the regular
      battle menu, not this type-2 item path, so the item flow needs its own
      must-hit evidence.

- [ ] **Surfboard.** `ItemUseSurfboard` remains a linked ret-stub. Generated
      state reports `IsSpriteInFrontOfPlayer2` and `SurfingAttemptFailed`
      missing, while `IsSurfingAllowed`, shore/water detection, tile-pair
      collision, passability, walking graphics, and simulated joypad support
      are present. Overworld-events supplies `IsSpriteInFrontOfPlayer2` and the
      normal-loop forced-step contract; this plan ports `SurfingAttemptFailed`
      with `ItemUseSurfboard`, including mount and dismount. Verify both
      directions through the real movement loop. See `docs/items_blockers.md`
      → Surfboard.

- [ ] **Stage 12 — stub and claim retirement.** Empty
      `src/engine/items/item_use_stubs.asm`; run `label_status --callers` for
      every retired provider; update the label DB; run the strict/default label
      lint and `fidelity_gate`; sweep related `STUB`, `TODO`, extern-provider,
      allowlist, plan, skill, and stigmergy claims; then archive this plan.

## Cross-plan reachability and fidelity tails

These do not block implementing the remaining item bodies, but they prevent
some completed effects from being fully reachable or faithful end to end:

- `DisplayTextID` has a translated check-only implementation and a linked
  ret-stub. Repel step counting and encounter suppression work, but the
  "REPEL's effect wore off" message cannot display until overworld-events
  Stage 2 links the real dispatcher.
- `BattleItemMenu` is a linked ret-only helper. Balls and battle-item effects
  have direct state coverage, but the live battle ITEM button cannot reach the
  dispatcher until battle-completion Stage 2c lands.
- Poké Flute's Pewter sleeping-Pikachu branch lacks
  `IsPikachuRightNextToPlayer` and `PlaySpecificPikachuEmotion`; the Route
  12/16 Snorlax flags still need their overworld-owned map-script consumers.
  `ModifyPikachuHappiness`
  is also a linked stub, so all already-placed item happiness calls remain
  inert. These are owner-plan tails, not reasons to reopen the completed item
  handlers.

## Fidelity and acceptance

The scenario manifest currently supplies these item-facing comparisons:

| Scenario | Tier / class | Must-hit evidence | What it proves |
|---|---|---|---|
| `item_tm_teach` | core / datastruct | `RunTMHMTest` | TM/HM post-flow WRAM state |
| `item_stone_evolve` | full / datastruct | `RunStoneTest` | evolution-stone post-flow WRAM state |
| `item_potion_use` | full / datastruct | `UseItem` | medicine post-flow WRAM state |
| `ball_catch` | full / datastruct | `RunBattleTest`, `UseItem` | capture post-flow WRAM state |

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
