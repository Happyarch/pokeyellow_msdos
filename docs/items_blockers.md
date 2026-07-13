# Items-layer blockers (handoff)

Open blockers found while working `docs/current_plan_items.md`. Each is **outside
the item layer** — the item-effect code is done or deliberately not written until
the blocker clears. Written for a fresh agent: each entry says what is broken, how
to see it, what the fix is, and what unblocks when it lands.

Status as of 2026-07-12 (Stage 8 `6e487263`, Stage 9 part 1 `b05696da`).

---

## B1 — `HandleFlyWarpOrDungeonWarp` is missing (blocks `ItemUseEscapeRope`)

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

## Cross-cutting: the `FlagActionPredef` trap

Not a blocker, a landmine. **Never `call FlagActionPredef` in the port** — it has no
predef dispatcher, but the routine still starts with `GetPredefRegisters`, which
overwrites ESI/EDX/EBX from WRAM slots nothing populates. Call **`FlagAction`**
directly (ESI = flag array, CL = bit, BH = action; result in CL). This was one of the
four bugs that made the whole evolution path dead code, and it was independently
present in `experience.asm` (documented there) and `itemfinder.asm`. If you add a
flag test/set, use `FlagAction`.
