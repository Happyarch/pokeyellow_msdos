# Items-layer blockers (handoff)

Open blockers found while working `docs/current_plan_items.md`. Each is **outside
the item layer** — the item-effect code is done or deliberately not written until
the blocker clears. Written for a fresh agent: each entry says what is broken, how
to see it, what the fix is, and what unblocks when it lands.

Status as of 2026-07-13. **B1 is RESOLVED** (see below); **B7 is largely dissolved** by
the same change. Open: B5, B7 (reduced), B8, B9.

---

## B1 — RESOLVED 2026-07-13 — `HandleFlyWarpOrDungeonWarp` ported; Escape Rope is live

**What it was.** `ItemUseEscapeRope` only ARMS a warp (it sets FLY_WARP+ESCAPE_WARP in
`wStatusFlags6`); the consumer that acts on those bits, `HandleFlyWarpOrDungeonWarp`,
did not exist in the port, so shipping the item would have printed its message, eaten
itself, and not warped.

**What fixed it.** The root cause turned out to be a **link-shadow**, not missing code:
`engine/overworld/player_animations.asm` was translated but sat in `HOME_CHECK_SRCS`
(assembled, never linked), so its real `EnterMapAnim` was silently shadowed by a ret-stub
in `overworld_stubs.asm` and its `_LeaveMapAnim` was unreachable. Its link closure was
already satisfied except for one symbol, so:

- `player_animations.asm` → `GAME_SRCS`; the `EnterMapAnim` ret-stub deleted (the port
  now has the real fly/dungeon **arrival** animation, which it never had before).
- `EmotionBubble` (its only unresolved symbol, reached solely from `FishingAnim`) gets a
  documented ret-stub in `overworld_stubs.asm` until `trainer_engine.asm` links.
- `HandleFlyWarpOrDungeonWarp` + the `LeaveMapAnim` wrapper ported into
  `engine/overworld/overworld.asm` (the port's `home/overworld.asm`, allowlisted like
  `HandleBlackOut`), and hooked into `OverworldLoopLessDelay`.
- `ItemUseEscapeRope` translated in full (+ `EscapeRopeTilesets`); its stub retired.

**Verified** headlessly (`DEBUG_ITEMSTONE ITEMSTONE_ID=0x1D`, new `ITEMSTONE_CAVERN=1`
seed — the harness boots into Pallet Town, whose OVERWORLD tileset is *not* an escape-rope
tileset, so the success path is unreachable without it):
| case | `wStatusFlags6` | result | bag |
|---|---|---|---|
| Pallet Town (refusal) | `$00` | `wActionResultOrTookBattleTurn`=0 | rope NOT consumed |
| CAVERN tileset | `$48` = FLY_WARP\|ESCAPE_WARP | =1, `wEscapedFromBattle`=1 | rope consumed |

**Still unverified:** the *warp itself*. The harness dumps and exits right after `UseItem`,
so it proves the arming, not `HandleFlyWarpOrDungeonWarp`'s execution. Needs one live run
(use an Escape Rope in a cave → should land at the last Pokémon Center).

**Also unblocks Dig** (`wPseudoItemID`), which shares this exit path and is now a call away.

---

## B1 (original text, for reference) — `HandleFlyWarpOrDungeonWarp` is missing

**What.** `ItemUseEscapeRope` (pret `engine/items/item_effects.asm`) does not warp
by itself. Its whole job is to set `BIT_FLY_WARP` + `BIT_ESCAPE_WARP` in
`wStatusFlags6` (plus some Safari-Zone resets) and let the overworld act on them.
The consumer, **`HandleFlyWarpOrDungeonWarp`, does not exist in the port** —
`dos_port/tools/label_status HandleFlyWarpOrDungeonWarp` reports `missing`.

**Why it is not written yet.** Translating the effect today would ship an item that
prints its message, consumes itself, and does not warp. That is worse than the
current stub, which at least fails quietly. So `ItemUseEscapeRope` is still a
ret-stub in `src/engine/items/item_use_stubs.asm`.

**Fix.** Port `HandleFlyWarpOrDungeonWarp` (pret `engine/overworld/...`) — it reads
the `wStatusFlags6` bits and runs the warp to the last-heal map. The blackout-warp
machinery it needs already exists in the port (`black_out.asm`). This belongs to
`docs/current_plan_overworld_port.md`, not the items plan.

**Unblocks.** `ItemUseEscapeRope` (items Stage 9, part 2) — a ~30-line faithful
translation once the consumer is live. Also Dig (`wPseudoItemID`), which shares the
same exit path. Note pret's guards: not usable in battle, nor in AGATHAS_ROOM /
BILLS_HOUSE / POKEMON_FAN_CLUB, and only on the tilesets in `EscapeRopeTilesets`
(FOREST, CEMETERY, CAVERN, FACILITY, INTERIOR).

---

## B2 — the bag menu never loads the item name into `wStringBuffer`

**What.** `ItemUseText00` ("`<PLAYER> used <ITEM>!`") prints the item name with a
**TX_RAM command pointing at `wStringBuffer` ($CF4A)**. pret's item menu fills that
buffer before dispatching: `wNamedObjectIndex = wCurItem` → `GetItemName` →
`CopyToStringBuffer`. **The port's bag menu does none of that**
(`grep -rn GetItemName dos_port/src` finds only `home/give.asm`), so every item that
routes through `PrintItemUseTextAndRemoveItem` prints whatever stale bytes happen to
be sitting in `wStringBuffer` where the item name belongs.

**Scope.** This is a bag-menu/`UseItem` gap, not an item-effect gap — the item side
is faithful. It affects **every** item using that message (the whole Repel family
today, and most of Stage 10/11).

**Fix.** In the port's `UseItem` path (`src/home/item.asm` / the bag menu, mirroring
pret `engine/menus/start_sub_menus.asm`), before dispatch:
`wNamedObjectIndex = [wCurItem]` → `call GetItemName` (→ `wNameBuffer`, $CD6D) →
`call CopyToStringBuffer` (→ `wStringBuffer`, $CF4A). Both routines already exist and
are already used elsewhere (see `evolution.asm`, which does exactly this pair for the
mon nickname).

**How to see it.** `DEBUG_ITEMSTONE` with `ITEMSTONE_ID=0x1E` (REPEL) reaches the
message; dump `GBSTATE.BIN` and charmap-decode `wTileMap` to read the rendered line.

---

## B3 — `DisplayTextID` is a ret-stub, so "REPEL's effect wore off." never shows

**What.** Stage 9 made `wRepelRemainingSteps` writable for the first time, which
brought the already-translated `TryDoWildEncounter` `.lastRepelStep` branch
(`src/engine/battle/wild_encounters.asm:77`) to life. That branch calls
`DisplayTextID`, which is still a **ret-stub** (`src/home/home_stubs.asm`). Step
counting and encounter suppression are fully live; only the wore-off **message** is
missing.

**Stale comment to fix while you are there.** `home_stubs.asm` justifies the stub by
arguing the branch is *"unreachable dead code in every current build"* because
"nothing in the port ever writes `wRepelRemainingSteps`". That is **no longer true**
as of `b05696da`. The stub is still safe (pret's `DisplayTextID` returns nothing and
the caller ignores flags), but the justification needs rewriting.

**Fix.** Destub `DisplayTextID` — owned by `docs/current_plan_script_engine.md`. Do
**not** special-case the repel text in `wild_encounters.asm`; that would fork pret's
shape for one message.

---

## B4 — `TextCommandProcessor` reads its stream EBP-relative (bespoke staging)

Pre-existing, already handed to a separate agent — recorded here only so the items
plan's dependency on it is visible in one place. Every flat `.data` text stream must
be **copied into `NPC_DIALOG_BUF`** before printing (`iu_print_text`,
`PrintBattleText`), because TCP fetches with `[ebp + esi]`. The pret-shaped
linear-pointer refactor was attempted and **reverted** (`4a5f366a`): it passes
`make fidelity` 6/6 yet regresses live text (renders `REDRED`). **The goldens do not
cover streamed text** — `DEBUG_ITEMTM` is the oracle. Details in the plan doc and in
the `text-stream-staging-bespoke` memory.

---

## B5 — `itemfinder.asm` is fixed but UNVERIFIED

`HiddenItemNear` had three bugs (flag array in EDI instead of ESI; `FLAG_TEST` passed
as 1, which is actually `FLAG_SET`, so the "already obtained?" test would have **set**
the flag; and `call FlagActionPredef`, whose `GetPredefRegisters` reloads ESI/EBX from
the stale `wPredefHL`/`BC` slots). Fixed mechanically in `7c4fc06e`, but the file is
**not linked and has no callers**, so nothing exercised the fix. **Validate it when
items Stage 11 wires ITEMFINDER.**

---

## B6 — Poké Flute's Pewter sleeping-Pikachu branch is deferred

`ItemUsePokeFlute`'s third overworld branch (PEWTER_POKECENTER: wake the Pikachu
sleeping next to you) needs **`IsPikachuRightNextToPlayer`** and
**`PlaySpecificPikachuEmotion`**, neither of which is ported (`label_status`:
missing). The port's branch falls into `.noSnorlaxOrPikachuToWakeUp` — the
no-effect message, which is what pret does on every other map — so it is inert,
not wrong. Restore the branch when the Pikachu-emotion routines land.

Related: `ModifyPikachuHappiness` is still a ret-stub (`battle_exp_stubs.asm`), and
every item that should nudge Pikachu's mood (medicine, TM/HM, the four X items)
already calls it faithfully. Destubbing it is a one-file change that lights all of
them up at once.

Also note the Route 12 / Route 16 flute branches now **set**
`EVENT_FIGHT_ROUTE{12,16}_SNORLAX` correctly, but the Snorlax that *reads* that
event is a map script owned by the overworld plan — so the flag is set and nothing
appears yet.

---

## B7 — the fishing rods — LARGELY DISSOLVED 2026-07-13 (was: needs the `trainer_engine.asm` link closure)

**Update (B1's fix).** The analysis below was exactly right, and B1 acted on it:
`player_animations.asm` is now in `GAME_SRCS`, so **`FishingAnim` is linked**, and its one
undefined symbol `EmotionBubble` is a documented ret-stub in `overworld_stubs.asm` — so the
rods no longer need the trainer-engine closure to LINK. What remains for the rods:

1. link `super_rod.asm` (`ReadSuperRodData`) into `ITEMS_SRCS`;
2. the ~60-line faithful item side (`ItemUseOldRod`/`GoodRod`/`SuperRod`);
3. cosmetic residue: the "!" bubble on a bite won't draw until `trainer_engine.asm` is
   promoted (the stub is a no-op) — everything else about FishingAnim works.

That makes the rods ordinary item work now, not blocked cross-plan work. The trainer-engine
closure below is still what's needed to delete the `EmotionBubble` stub.

**Original analysis:**

`ItemUseOldRod` / `GoodRod` / `SuperRod` all end in `FishingAnim`
(`engine/overworld/player_animations.asm`) — it is not just the animation, it also
prints "Not even a nibble!" / "Looks like there's nothing here." and shakes the
player sprite on a bite. Its two files are **translated but check-only**, and I
measured the closure by linking them:

- Moving `super_rod.asm` (`ReadSuperRodData`) into `ITEMS_SRCS` and
  `player_animations.asm` (`FishingAnim`) into `GAME_SRCS` links with exactly **one**
  undefined symbol: **`EmotionBubble`** (FishingAnim shows the "!" bubble on a bite).
- `EmotionBubble` is *relocated* into `src/engine/overworld/trainer_engine.asm` and
  is not `global` there. Adding the `global` and linking that file pulls in
  **`SaveTrainerName`** (missing), **`JessieJamesPic`** (missing pic data),
  **`TrainerNameText`** (missing), **`WriteOAMBlock`** (`home/oam.asm`, check-only)
  and **`GetTrainerName_`** (translated, `get_trainer_name.asm`, not linked).

So the rods are three small ports away, but all three are **trainer-engine** work,
not item work — which is exactly what the items plan predicted ("Rod-cast … couple
to the overworld/battle boundary — flag both plans when wiring"). Whoever links
`trainer_engine.asm` should finish the rods in the same pass; the item side is a
~60-line faithful translation with no other dependency (`IsNextTileShoreOrWater`,
`Random`, `ReadSuperRodData`, `PlaySound`, `DelayFrames` are all live).

**Watch out:** `wRodResponse` is `$CD3D` — the same aliased scratch byte as
`wWereAnyMonsAsleep`. Do not dump it after the text path has run (see the Poké Flute
note in `src/debug/debug_dump.asm`).

---

## Cross-cutting: `faithdiff` cannot see port-side conditional jumps

Not a blocker, a gate weakness worth knowing before you read a report.
`tools/faithdiff`'s **port** matcher is `^\s*(call|jmp)\s+…` — it does not match
`jnz`/`jz`/`jne`/`je`. pret's matcher *does* accept `jp nz, Target`. So every
port routine that reaches a shared tail with a conditional jump (the whole
`… jnz ItemUseNotTime` family) reports a spurious **DROPPED ItemUseNotTime**.
`ItemUseCoinCase`, `ItemUseCardKey` and friends all carry it. Teaching the port
regex the `j<cc>` forms would remove a standing class of false positives — and would
probably surface some real ones — but it re-baselines every routine's report at once,
so it wants its own commit.

---

## Cross-cutting: the `FlagActionPredef` trap

Not a blocker, a landmine. **Never `call FlagActionPredef` in the port** — it has no
predef dispatcher, but the routine still starts with `GetPredefRegisters`, which
overwrites ESI/EDX/EBX from WRAM slots nothing populates. Call **`FlagAction`**
directly (ESI = flag array, CL = bit, BH = action; result in CL). This was one of the
four bugs that made the whole evolution path dead code, and it was independently
present in `experience.asm` (documented there) and `itemfinder.asm`. If you add a
flag test/set, use `FlagAction`.

---

## B8 — PP Up / PP Restore need `MoveSelectionMenu`'s type-2 (relearn) menu

**What.** `ItemUsePPUp` and `ItemUsePPRestore` are one routine in pret (PP Up falls
into PP Restore after an in-battle guard), and both reach their effect through a
**move-selection UI**: they set `wMoveMenuType = 2` and call `MoveSelectionMenu`,
which in pret branches to `.relearnmenu` — a box listing the *party* mon's moves
(`wPartyMon1Moves` + `wWhichPokemon`), drawn at a different position, with the
"WhichTechnique" prompt and WITHOUT the battle path's 0-PP / disabled checks
(`SelectMenuItem` also branches on `wMoveMenuType`).

**Why it is not written yet.** The port's `MoveSelectionMenu`
(`src/engine/battle/core.asm`) implements **only the regular battle path** — its own
header says the mimic/relearn menus are deferred. It reads `wBattleMonMoves` and
gates on `wBattleMonPP`, which is exactly wrong out of battle. Translating the item
side today would give an item that opens the battle move menu over the party screen
and reads another mon's PP. Everything ELSE the PP items need is already ported:
`GetMaxPP`, `GetSelectedMoveOffset`, `RestoreBonusPP`, `AddBonusPP`,
`DisplayPartyMenu`, `GetMoveName`, `CopyToStringBuffer`, `RemoveUsedItem`, and all
five texts (`assets/item_text.inc`).

**Fix.** Port `MoveSelectionMenu`'s `.mimicmenu` / `.relearnmenu` branches and the
`wMoveMenuType` dispatch in `SelectMenuItem` (which also owns the type-dependent
watched-keys set and the `WhichTechniqueString` prompt). That is battle/menus work.
`ItemUsePPUp` / `ItemUsePPRestore` are then a ~120-line faithful translation with no
other dependency — including pret's **Max Ether/Max Elixir PP-Up bug**
(`.fullyRestorePP` compares the raw PP byte without masking off the PP-Up count, so a
PP-Upped move at full PP is not detected as "no effect"), which must be preserved and
tagged.

**Unblocks.** Items Stage 11's last two non-trivial handlers (ETHER $50 / MAX_ETHER
$51 / ELIXER $52 / MAX_ELIXER $53, and PP_UP $2F).

---

## B9 — Surfboard needs the overworld Surf machinery

`ItemUseSurfboard` is not "a guard + refusal" (as the items plan assumed) — in pret it
**is** the Surf execution: mount (tile-pair collision check → `wWalkBikeSurfState` = 2
→ `PlayDefaultMusic` → "got on"), and dismount (sprite-in-the-way check → passability
→ walking graphics + Pikachu respawn state). Two of its dependencies are **missing**
in the port: **`IsSpriteInFrontOfPlayer2`** and **`SurfingAttemptFailed`**; the rest
(`IsNextTileShoreOrWater`, `CheckForTilePairCollisions`, `IsTilePassable`,
`PlayDefaultMusic`, `LoadWalkingPlayerSpriteGraphics`) are in. The scripted
forward-step (`.makePlayerMoveForward`, via `wSimulatedJoypadStatesEnd`) also wants
the overworld plan's simulated-input path. Owned by `docs/current_plan_overworld_port.md`.
