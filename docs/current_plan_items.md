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
work is Itemfinder, the three fishing rods, PP Up/PP restoration, Surfboard,
and the final stub-retirement sweep. Archive this file to
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

- [ ] **Fishing rods.** This is ready item-layer work, not an external blocker:
      `FishingAnim` is linked and `ReadSuperRodData` is check-only. Promote
      `super_rod.asm`, port `FishingInit` plus the Old/Good/Super Rod handlers,
      and exercise no-bite and bite branches. `EmotionBubble` is NOT a blocker: the
      faithful body is linked at its pret mirror
      (`src/engine/overworld/emotion_bubbles.asm`) and the `overworld_stubs.asm`
      ret-stub was retired by the M8.2 promotion 2026-07-24, so a bite draws the
      real "!" bubble. The genuine open dependency is `LoadAnimSpriteGfx`: see
      the header-layout defect below.

      **Header-layout defect on the already-linked `FishingAnim` path
      (measured 2026-08-02, not previously recorded).** `FishingAnim`
      (`src/engine/overworld/player_animations.asm:686-687`) calls
      `LoadAnimSpriteGfx` with `RedFishingTiles`, but the two disagree on the
      header shape: the linked `LoadAnimSpriteGfx`
      (`src/engine/gfx/mon_icons.asm:295-309`) reads 12-byte entries
      (`MON_ICON_HDR_SIZE equ 12`, fields at +0/+4/+8), while `RedFishingTiles`
      (`player_animations.asm:772-788`) is 8 bytes per entry
      (`dd ptr / db count / db bank / dw vram_off`). The same call also passes
      the entry count in `AL` (`mov al, 0x4`) where the callee consumes `EAX`
      (`mov [las_left], eax`), so the loop bound is whatever was in the upper
      24 bits. Both must be fixed before a rod can be used; the port's own
      `; UNPORTED` comment at `:687` and the "Check-only (HOME_CHECK_SRCS)"
      note at `:35-38` are stale (the file is in `GAME_SRCS`, Makefile:354) and
      were hiding this. A related `wRodResponse` memmap-promotion note for this
      same handler family is tracked in `docs/current_plan_backlog.md`, not
      here.

- [ ] **PP Up and PP restoration.** This is ready item-layer work. The battle
      menu audit replaced the old battle-only move picker with pret-shaped
      `MoveSelectionMenu`/`SelectMenuItem`, including `wMoveMenuType = 2` and
      the party-mon relearn menu. Port `ItemUsePPUp` and `ItemUsePPRestore`,
      retire both stubs, and preserve/tag pret's Max Ether/Max Elixer PP-Up-bit
      no-effect bug. Existing `move_selection` coverage exercises the regular
      battle menu, not this type-2 item path, so the item flow needs its own
      must-hit evidence.

- [ ] **Surfboard.** `ItemUseSurfboard` remains a linked ret-stub and
      `SurfingAttemptFailed` is the only missing dependency. Re-measured
      2026-08-02: `IsSpriteInFrontOfPlayer2` is DONE — `implementation /
      linked / statically-reached-from-start`, provider
      `src/home/overworld.asm`, 2 callers (`IsSpriteOrSignInFrontOfPlayer`,
      `IsSpriteInFrontOfPlayer`) — delivered by the overworld-events boulder
      work 2026-07-16; the earlier "missing" reading here predated it.
      `IsSurfingAllowed`, shore/water detection, tile-pair collision,
      passability, walking graphics and simulated-joypad support are all
      linked, and so is the whole water-collision loop
      (`CollisionCheckOnWater`, `ForceBikeOrSurf`,
      `LoadSurfingPlayerSpriteGraphics`, `CheckForJumpingAndTilePairCollisions`
      — all linked and statically reached). This plan ports
      `SurfingAttemptFailed` with `ItemUseSurfboard`, including mount and
      dismount; overworld-events still owns normal-loop consumption of the
      simulated forward step. Verify both directions through the real movement
      loop. The mount/dismount runtime scenario belongs here — it is also the
      first coverage of the overworld-owned `CollisionCheckOnWater` /
      `LoadSurfingPlayerSpriteGraphics` path, so do not write it twice. See
      `docs/items_blockers.md` → Surfboard.

- [ ] **Stage 12 — stub and claim retirement.** Empty
      `src/engine/items/item_use_stubs.asm` — measured 2026-08-02, that file
      holds exactly six labels aliased onto one `ret`: `ItemUseSurfboard`,
      `ItemUse{Old,Good,Super}Rod`, `ItemUsePPUp`, `ItemUsePPRestore`; its
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
