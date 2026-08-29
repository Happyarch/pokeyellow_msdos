# Current Plan: engine/battle/core.asm pret realignment

> Born 2026-08-29 from a full-file audit, in the shape of the archived
> `docs/plans/overworld_realign.md`. pret `engine/battle/core.asm` (6,825 lines,
> 207 top-level labels) and `dos_port/src/engine/battle/core.asm` (8,685 lines,
> 149 top-level labels) were read end-to-end and compared routine-by-routine.
> Every load-bearing claim was re-verified against the supporting code on both
> sides: `constants/move_constants.asm`, `constants/item_constants.asm`,
> `constants/battle_anim_constants.asm`, `data/moves/moves.asm`,
> `audio/pikachu_cries_pointers.asm`, `macros/pikachu.asm`, `home/compare.asm`,
> `home/pokemon.asm`, `ram/hram.asm`, `ram/wram.asm`, `dos_port/include/gb_memmap.inc`,
> `dos_port/include/gb_constants.inc`, `dos_port/include/msgbox.inc`,
> `dos_port/src/home/window.asm`, `dos_port/src/home/math.asm`,
> `dos_port/src/engine/battle/animations.asm`,
> `dos_port/src/engine/battle/init_battle.asm`,
> `dos_port/src/engine/battle/core_stubs.asm`, and `dos_port/tools/faithdiff`
> run over all 207 pret labels.
>
> **Headline.** The port logic-matches pret on the whole damage/accuracy/status
> backend — `CalculateDamage`, `MoveHitTest`, `CalcHitChance`,
> `AdjustDamageForMoveType`, `RandomizeDamage`, `CheckPlayerStatusConditions`,
> `CheckEnemyStatusConditions`, `BattleRandom`, `TryRunningFromBattle`'s odds
> math, `HandlePoisonBurnLeechSeed` and its two helpers, `AnyPartyAlive`,
> `AnyEnemyPokemonAliveCheck`, `LoadBattleMonFromParty`, `LoadEnemyMonFromParty`,
> `IncrementMovePP`, `ReloadMoveData`, `Func_3d4f5`/`Func_3d523`/`Func_3d529`/
> `Func_3d536`, `SlideTrainerPicOffScreen`, `SlideDownFaintedMonPic`,
> `UpdateCurMonHPBar`, `PrintCriticalOHKOText`, `MoveHitTest`'s mist/X-Accuracy
> ladders and `FaintEnemyPokemon`'s EXP-ALL halving are all faithful, including
> pret's own bugs (verified one instruction at a time; see "Verified faithful").
> What remains is (a) **four wrong move-id constants** — the most severe finding
> in this file and the only outright data bug; (b) a small set of **dropped
> calls and stores** that faithdiff also reports; (c) a batch of **stale or
> measurably false comments**, several of which claim a provider is missing when
> it is translated and linked; and (d) **bespoke remnants** — duplicated
> constants, a hand-rolled delay loop, an asymmetric HUD draw order, and
> unannotated port-only stores.

**Scope rule.** Same as the overworld plan: everything realigns except the
banking/flat-model elisions (`Bankswitch` → direct call, `predef` → direct call
with register args, `FarCopyData` on flat tables → inline byte copy,
`hAutoBGTransferEnabled`/`rLCDC`/`rLY` writes → dropped) and the BCOORD /
generated-UI-layout coordinate projection. Those are accepted and are NOT
changed here — where one is the *reason* a line cannot be literal, it gets a
structured annotation instead. Text strings stay generated Tier-1 data
(`assets/battle_text.inc`); 63 of the 68 pret labels with no port counterpart
are `text_far` string labels and are correctly absent.

**The 5 genuinely-missing pret labels** (measured from `translation.db`,
read-only; `label_status` agrees): `BattleCore` (data anchor for the five
`INCLUDE`d effect tables — the port carries the tables in `battle_data.asm`
under their own names, so the anchor is a data-model question, Stage E),
`StartBattle` (**collapsed** into `init_battle.asm:_InitBattleCommon` — Stage E),
`SimulatedInputBattleItemList` (data, `DEVIATION`-annotated at
`core.asm:3401`), `SlidePlayerHeadLeft` and
`SetScrollXForSlidingPlayerBodyLeft` (both inside the `DEVIATION{class=HAL}` at
`core.asm:7471`; `rLY` is inert in the port so a literal translation cannot
terminate — that one is correct and stays).

## Gate

For every commit under this plan:

1. `nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 -o /dev/null <file>` per
   touched file, then `dos_port/tools/faithdiff <Label>` for each changed pret
   label (justify every unsuppressed call delta in the commit message), then
   `dos_port/tools/lint_pret_labels --no-scan` **and** `--no-scan
   --strict-claims`, then `dos_port/tools/static_gate`. Record the per-class
   counts from BOTH lint modes before and after; a class that grew is yours.
   **Measured 2026-08-29 in this checkout, before any edit under this plan:**
   both lint modes exit **1** with exactly **1 violation in one class,
   `registry_approval`** — `pret_label_allowlist.json` SHA-256
   `c19c8a06346125fcd648440638390d5ceac116411a2ed54ce430439e7b59086a` has no
   maintainer approval configured, and the linter itself states *"agents must
   not set or update this approval"*. Every other class is clean. So the gate
   here is **`registry_approval` stays at 1 and no other class appears** — not
   "exit 0", which this tree does not currently produce and no agent can make
   it produce. `dos_port/tools/static_gate` **cannot run here at all**: it dies
   at step 1 (`update_label_db`) with `dos_port/include/gb_memmap.inc:1887:
   cannot resolve %include "assets/rom_window.inc"`, because `dos_port/assets/`
   is generated and not checked in. Run it after a `make` that has produced the
   assets.
2. Any change that moves a pixel or a WRAM byte → `make -C dos_port fidelity`
   (core). Stage A (constants) and Stage B (faint/send-out seam) touch
   battle-visible state → `fidelity-full`, plus a new must-hit scenario where no
   existing one can witness the change (A.1 needs a Metronome-user scenario;
   B.1/B.2 need a faint scenario that compares the player-HUD band).
3. **The allowlist is not yours to grow.** No new keys in
   `dos_port/tools/pret_label_allowlist.json`; the pre-commit hook refuses added
   keys outright. A `mirror` finding means move the routine, not edit the
   registry.
4. Run `memory_search regression battle` before editing; if a change lands a fix
   a regression memory knows about, close the memory in the same commit.
5. One commit per numbered item or tightly-coupled pair; narrative in the commit
   message (the translation log is closed — do not resurrect it).

**Verification status of THIS document (be explicit, per the audit brief).**
Every finding below was derived by reading the two sources and the supporting
files, and by running `tools/faithdiff` over all 207 pret labels (68 report a
call/store delta; each was then read by hand and classified below as real,
justified, or a name-matching artifact). **Run here, with results:**
`dos_port/tools/faithdiff` (all 207 labels), `dos_port/tools/lint_pret_labels`
in both modes (see Gate item 1 — exit 1, one `registry_approval` violation),
`dos_port/tools/static_gate` (FAILs at step 1; generated assets absent),
`dos_port/tools/label_status`, and a read-only `translation.db` query
(202 translated / 5 missing, matching the list above).
**Not run here:** `nasm`, `make`, `goldencheck`, `fidelity`. `nasm` is not
installed in this sandbox and there is no root to install it (`apt-get` →
permission denied; `pip install nasm` → PEP 668), and `dos_port/assets/*.inc` is
generated, not checked in, so the file cannot be assembled in place. The four Stage-A constant
values are therefore established by **source reading plus an independent
cross-check against the generated table's ordering**, not by an object file:
`constants/move_constants.asm`'s `const_def` chain gives METRONOME=$76,
MIRROR_MOVE=$77, SELFDESTRUCT=$78, EXPLOSION=$99, and `data/moves/moves.asm`
independently puts `move METRONOME` at 0-based row 117 (= 1-based id 118 = $76).
**Re-run `make -C dos_port check` before trusting any fix that lands.**

Archive to `docs/plans/battle_core_realign.md` when all stages are `[x]`.

## Findings ledger

### Stage A — wrong constants (real behaviour bugs, highest priority)

The root cause is one decision, and the file records it against itself. Line
8542 defines `STRUGGLE_MOVE equ 0xA5`, which **duplicates the correct shared
constant** `%define STRUGGLE 0xA5` already at `include/gb_constants.inc:684`.
Whoever wrote that block did not look for the shared name; they hand-derived
four neighbours instead. The one they copied (STRUGGLE) is right. The four they
derived are wrong, and all four are wrong the same way: **pret's `; 76`-style
trailing comment in `move_constants.asm` is a HEX value, and it was read as
decimal and re-hexed.**

| # | Port symbol | Port value | pret name | pret value | What $the-port-value actually is |
|---|---|---|---|---|---|
| A.1 | `METRONOME_MOVE` (`core.asm:8541`) | `0x4C` (=76 dec) | `METRONOME` | `0x76` | `SOLARBEAM` |
| A.2 | `MIRROR_MOVE` (`core.asm:58`) | `0x4D` (=77 dec) | `MIRROR_MOVE` | `0x77` | `POISONPOWDER` |
| A.3 | `SELFDESTRUCT_MOVE` (`core.asm:8581`) | `0x4E` (=78 dec) | `SELFDESTRUCT` | `0x78` | `STUN_SPORE` |
| A.4 | `EXPLOSION_MOVE` (`core.asm:8582`) | `0x63` (=99 dec) | `EXPLOSION` | `0x99` | `RAGE` |

`SELFDESTRUCT` and `EXPLOSION` are **already defined correctly** in
`include/gb_constants.inc` (`0x78` / `0x99`, in the "move ids referenced by
battle logic" block, measured) — the port's local `*_MOVE` aliases shadow the
correct shared constants with wrong values. `METRONOME` and `MIRROR_MOVE` have
no shared constant at all; add them to that block.

Live call sites, all reachable in normal play:

- **A.1** `core.asm:466` — `MainInBattleLoop`'s link-battle branch
  (`cp METRONOME` after a peer switch while the player is trapped by a
  multi-turn move) and `core.asm:8554`/`8570`/`8572` — `MetronomePickMove`:
  it plays **Solarbeam's** animation (`ld a, METRONOME / call
  PlayMoveAnimation`) and then excludes **Solarbeam** from the random pool
  while happily allowing Metronome to pick itself, which pret forbids
  (`cp METRONOME / jr z, .pickMoveLoop`). Metronome-mirrors-Metronome is
  reachable and, per pret, must be impossible.
- **A.2** `core.asm:6733` — `MirrorMoveCopyMove`'s
  `cmp al, MIRROR_MOVE`. pret refuses to mirror Mirror Move; the port refuses
  to mirror **Poison Powder** and lets Mirror Move copy Mirror Move.
- **A.3 / A.4** `core.asm:8614`/`8616` — `HandleExplodingAnimation`'s
  `cp SELFDESTRUCT` / `cp EXPLOSION`. The screen shake after Self-Destruct /
  Explosion **never fires**; it fires instead after Stun Spore and Rage, which
  pret never shakes for.

None of the four is annotated, and `faithdiff`/`lint_pret_labels`/`static_gate`
are all structurally blind to it — a wrong immediate is a faithful-looking
`cmp`. This is precisely the "a translation whose behaviour drifts can pass
every gate" case the `asm-translation` skill opens with.

- [x] A.1 fix `METRONOME_MOVE` → `0x76`; delete the local `equ` at `core.asm:8541` and add
      `%define METRONOME 0x76` to `gb_constants.inc`'s move-id block, repointing
      the three call sites at the pret name. **DONE 2026-08-29 (912877372): moved to shared `gb_constants.inc`, repointed MainInBattleLoop+MetronomePickMove x3.**
- [x] A.2 fix `MIRROR_MOVE` → `0x77`; same treatment (delete the file-local
      `equ`, add the shared name, repoint `core.asm:6733`). **DONE 2026-08-29 (912877372): local equ 0x4D deleted, shared 0x77 used at MirrorMoveCopyMove.**
- [x] A.3 delete `SELFDESTRUCT_MOVE` and use the existing
      `gb_constants.inc` `SELFDESTRUCT`. **DONE 2026-08-29 (912877372).**
- [x] A.4 delete `EXPLOSION_MOVE` and use the existing `gb_constants.inc`
      `EXPLOSION`. **DONE 2026-08-29 (912877372): both repointed at HandleExplodingAnimation.**
- [x] A.5 delete `STRUGGLE_MOVE` (`core.asm:8542`) and use the existing
      `STRUGGLE`; also delete the duplicated dangling comment line at `8545`
      ("ids >= STRUGGLE are not real moves…" appears at `8542-8543` and again
      verbatim at `8545`). **DONE 2026-08-29 (912877372).**
- [x] A.6 housekeeping: `%define EXP_ALL 0x4B` sits in
      `gb_constants.inc`'s **"field-move ids"** block (`:702`) although it is an
      item id from `constants/item_constants.asm`. Move it to an item block.
      Value verified correct. **DONE 2026-08-29 (912877372): moved to item block.**
- [ ] A.7 golden: a must-hit scenario that stages Metronome in the player's
      slot and asserts (i) Metronome's own animation plays, (ii) Metronome is
      never the picked move over N rolls, (iii) Solarbeam's animation does not
      play. No existing scenario can witness this.
- [ ] A.8 golden: Self-Destruct screen shake fires (and Stun Spore's does not).

### Stage B — dropped calls and stores (functional)

Each of these is also a `faithdiff` DROPPED line, so the tool was already
saying it; what was missing was the reading.

- [x] **B.1** `RemoveFaintedPlayerMon` drops pret's
      `hlcoord 9,7 / lb bc,5,11 / call ClearScreenArea` (pret `core.asm:1039`,
      between `call ReadPlayerMonCurHPAndStatus` at `:1036` and the
      `SlideDownFaintedMonPic` at `:1040`). Insert point in the port is after
      `core.asm:5295`. Measured across the file: pret has 10
      `call ClearScreenArea` in `core.asm`; the port has 8 — one is
      `Func_3d536` (pret `_DEBUG`-only) and `AnimateRetreatingPlayerMon`'s two
      are folded into its `.clearScreenArea` helper, which leaves exactly this
      one unaccounted for. **Effect:** the player HUD/HP band is not wiped
      before the fainted mon's pic slides down, so a previous draw's glyphs
      survive wherever the slide writes fewer cells. This is the same defect
      class the port already fixed twice in this file (see the "FOURTH instance
      of the raw-GB-anchor class" note at `core.asm:7805` and the
      "Restored 2026-08-13" note at `core.asm:7189`) — those notes are accurate
      and this one is the same bug left standing. Use `BCOORD(9,7)`, `bh=5`,
      `bl=11`.
- [x] **B.2** `DisplayBattleMenu` drops pret's `call
      PlaceUnfilledArrowMenuCursor` at `.AButtonPressed` (pret `core.asm:2219`,
      the first statement of the label). The port's `.AButtonPressed`
      (`core.asm:709`) goes straight to the `BATTLE_TYPE_RUN` test.
      `PlaceUnfilledArrowMenuCursor` IS externed in this file (`core.asm:231`)
      and IS called at `core.asm:3623` (`PartyMenuOrRockOrRun`'s A-press, where
      pret also calls it) — so the provider is live and this is a pure
      omission, not a boundary. `faithdiff DisplayBattleMenu` reports
      `- DROPPED PlaceUnfilledArrowMenuCursor (call)`. **Effect:** the selected
      battle-menu item never gets its '▷' marker.
- [x] **B.3** `AttackSubstitute` drops pret's substitute-break animation AND
      the HUD redraw that closes the routine.
      (a) pret `core.asm:5052-5065` flips `hWhoseTurn`, `callfar Func_79929`
      (the substitute-break animation), flips back. The port carries
      `TODO(anim): … a no-op here (anim deferred, Master B), so skipped` at
      `core.asm:2892`. **That comment is stale and measurably false:**
      `tools/label_status Func_79929` reads `translated`,
      `port=dos_port/src/engine/battle/animations.asm` (body at
      `animations.asm:2158`), and `core_stubs.asm:107` records
      "ChangeMonPic, Func_79929: RETIRED 2026-08-08 — real bodies in
      animations.asm". The animation is available and linked; the deferral
      outlived the provider by three weeks.
      (b) pret's `.substituteBroke` path ends `jp DrawHUDsAndHPBars`
      (`core.asm:5073`) — a tail jump, so the HUD redraw is part of this
      routine's contract. The port's `.subDone: ret` (`core.asm:2908`) serves
      both the survived and the broke path, so the broke path returns with a
      stale HUD. `faithdiff AttackSubstitute` reports both
      (`- DROPPED DrawHUDsAndHPBars (jp)`, `- DROPPED Func_79929 (callfar)`).
      Split the tail: `ret` on survive, `jmp DrawHUDsAndHPBars` on break.
- [x] **B.4** `HasMonFainted` drops pret's `NoWillText` branch entirely
      (pret `core.asm:1519-1527`: on a fainted mon, if
      `wFirstMonsNotOutYet == 0`, `ld hl, NoWillText / call PrintText` before
      `xor a / ret`). Self-admitted at `core.asm:5237` as "that text path is a
      TODO". The ZF contract is exact (verified), so only the message is
      missing — but it is user-visible: `ChooseNextMon`'s
      `.monChosen → HasMonFainted → jz .goBackToPartyMenu` loop
      (`core.asm:5429-5432`) silently bounces the player back to the list with
      no explanation. `NoWillText` is not currently emitted by
      `gen_battle_text.py` (grepped: zero hits tree-wide) — add it to the
      generator, do not hand-encode it (two-tier rule).
- [x] **B.5** `BattleMenu_RunWasSelected` drops pret's
      `ld a, 0 / ld [wForcePlayerToChooseMon], a` (pret `core.asm:2559-2560`,
      immediately after the `TryRunningFromBattle` call, before `ret c`). The
      port (`core.asm:3765-3782`) goes straight from the call to the CF test.
      `faithdiff` reports `- DROPPED [wForcePlayerToChooseMon]`. **Not a
      no-op:** the port writes `1` there at `core.asm:7614`
      (`TryRunningFromBattle`'s can't-escape path, faithful to pret `:1621`)
      and the only clearer left is `home/pokemon.asm:328`, which fires inside
      `DisplayPartyMenu`. In pret the RUN-menu path clears it immediately; in
      the port it stays armed until the party menu happens to consume it, so a
      later party menu opens with B masked off (A-only watched keys) when pret
      would allow cancel.
- [x] **B.6** `TryRunningFromBattle`'s trainer-battle test narrows the
      condition. pret `core.asm:1544-1546` is `ld a,[wIsInBattle] / dec a /
      jr nz, .trainerBattle` — i.e. **any** value ≠ 1, including 0. The port
      (`core.asm:7537`) is `cmp byte [ebp + wIsInBattle], 2 / je .trainerBattle`
      — only 2. Diverges for `wIsInBattle == 0`. Almost certainly unreachable
      (the routine is only entered from a live battle), but it is a logic
      difference and it is unannotated; write pret's shape
      (`dec al / jnz .trainerBattle`) and the divergence disappears.
- [x] **B.7** `TryRunningFromBattle`'s run-attempt add loop widens pret's
      8-bit counter: `movzx ecx, byte [ebp + wNumRunAttempts]` + `dec ecx`
      (`core.asm:7586-7593`) for pret's `ld c,a / .loop: dec c / jr z`
      (`core.asm:1593-1605`). This is the single most-repeated translation
      defect in this project (skill `asm-translation`, "Preserve Counter
      WIDTH"). It is *nearly* safe — `wNumRunAttempts` is `inc`'d at the top of
      the same routine (`core.asm:7538`) so it is ≥1 on entry — but it wraps
      0xFF→0x00 after 256 attempts in one battle, and at that boundary pret
      loops 255 times where the port loops ~4 billion. Fix is one instruction:
      `dec cl`. No `DEVIATION` needed once narrowed.
- [x] **B.8** `DrawEnemyHUDAndHPBar` draws the HUD frame **last**
      (`call PlaceEnemyHUDTiles` at `core.asm:7407`, after the HP bar and the
      colour publish) where pret draws it **second**, immediately after the
      `ClearScreenArea` (pret `core.asm:1956-1958`). Its mirror
      `DrawPlayerHUDAndHPBar` was already fixed to pret's order and carries the
      reasoning ("pret DrawPlayerHUDAndHPBar draws the frame FIRST … The port
      used to draw the frame/connector last", `core.asm:7200-7204`). The enemy
      half never got the same treatment, and its own comment block
      (`core.asm:7336-7346`) discusses only the draw-then-colour order, never
      the frame position. Realign to pret's order so the two mirrors match.
- [x] **B.9** `FaintEnemyPokemon`'s trainer-faint SFX block is a bare
      `TODO-HW` (`core.asm:7823-7826`: `wFrequencyModifier`/`wTempoModifier`
      zeroing, `PlaySoundWaitForCurrent SFX_FAINT_FALL`, the CHAN5 wait loop,
      `PlaySound SFX_FAINT_THUD`, `WaitForSoundToFinish` — pret
      `core.asm:785-800`). **Suspect before accepting:** three sibling notes in
      this same file retired exactly this class of TODO as stale and then
      landed the call (`core.asm:5269` low-health alarm, `core.asm:5313`
      `PlayCry`, `core_stubs.asm:50` `PredefShakeScreenHorizontally`), and
      `PlaySoundWaitForCurrent` / `WaitForSoundToFinish` are both externed and
      called elsewhere in `core.asm` (`:7643`, `:7646`). Verify whether
      `PlaySound` and the CHAN5 poll are live; if they are, the TODO is stale
      and the block lands. If the CHAN5 poll genuinely cannot terminate under
      the audio HAL, that is a `DEVIATION{class=HAL}` and must say so.

> **DONE 2026-08-29 (0448f790d):** B.1-B.9 all landed and verified (build + faithdiff + lint 0/0). See commit 0448f790d for per-item narrative.

### Stage C — stale and measurably false comments

- [x] **C.1** `EndLowHealthAlarm` (`core.asm:7918-7924`) justifies dropping
      pret's `ld [wLowHealthAlarmDisabled], a` (pret `core.asm:880`) with:
      *"The port's alarm engine does not consult that flag (no reader exists in
      the tree), and the alarm can only re-arm while in battle — which is
      ending here — so the store is inert and omitted."* **The first clause is
      false.** `core.asm:7289` reads `wLowHealthAlarmDisabled` inside
      `DrawPlayerHUDAndHPBar` — a faithful translation of pret's own reader at
      `core.asm:1932` (`and a ; has the alarm been disabled because the player
      has already won? / ret nz`), landed 2026-08-13 per the note at
      `core.asm:7280-7285`. Measured: the tree has exactly one reader
      (`core.asm:7289`) and **zero** writers, so the omission is **not inert**.
      Reachable path: a trainer battle where an enemy mon faints
      (`EndLowHealthAlarm` runs) and the player's mon is at red HP — pret
      suppresses the alarm re-arming for the rest of that battle, the port
      re-arms it. Land the store (`%define wLowHealthAlarmDisabled 0xD844` is
      already in `gb_memmap.inc:555`) and delete the comment; if the maintainer
      prefers to keep the omission, it owes a `DEVIATION{}` whose evidence does
      not claim there is no reader. **DONE 2026-08-29: store restored (`inc al / mov [wLowHealthAlarmDisabled], al`), comment replaced with faithful header and cross-ref to DrawPlayerHUDAndHPBar reader.**
- [x] **C.2** Four `TODO(faithful, deepen)` blocks describe work that is
      **done**:
      - `core.asm:1549-1552` lists "PrintGhostText … charging moves …
        HandleCounterMove, multi-hit loop, Mirror Move / Metronome, Explosion
        handling … PrintCriticalOHKOText, DisplayEffectiveness,
        HandleBuildingRage, move-failure text" as "currently simplified/skipped".
        Every one is a real body: `PrintGhostText` at `:6858`,
        `IsGhostBattle` at `:6885`, `MirrorMoveCheck` at `:1681` (calls the real
        `MirrorMoveCopyMove` at `:6718`), `MetronomePickMove` at `:8551`,
        `HandleExplodingAnimation` at `:8600`, `PrintCriticalOHKOText` at
        `:6935`, `HandleBuildingRage` at `:8494`, `PrintMoveFailureText` at
        `:8330`, the multi-hit loop at `:1725-1731`, the charging arms
        `PlayerCanExecuteChargingMove` `:1604` and
        `PlayerCheckIfFlyOrChargeEffect` `:1668`.
      - `core.asm:1568-1570`: "Deferred leaves (Counter/MirrorMove/Metronome/
        crit+effectiveness text/EXPLODE anim/ghost) are explicit stub CALLs
        (`core_stubs.asm`)". `core_stubs.asm:35-46` says the opposite:
        "NOW FAITHFULLY PORTED (battle-swarm-A) … **The stubs that used to live
        here are deleted.**"
      - `core.asm:1906` (`CheckPlayerStatusConditions`): "The multi-turn
        lock-ins (Bide/Thrash/Trapping/Rage) fall through to
        `.checkConditionsDone` for now — TODO(Stage 3)." All four are
        implemented: `.bideCheck` `:2067`, `.thrashingAboutCheck` `:2113`,
        `.multiturnMoveCheck` `:2133`, `.rageCheck` `:2144`.
      - `core.asm:2504` and `core.asm:2912` repeat the same claim for
        `ExecuteEnemyMove` / `CheckEnemyStatusConditions`; both are complete
        (`EnemyCheckIfMirrorMoveEffect` `:2680`, and the enemy Bide / Thrash /
        multi-turn arms inside `CheckEnemyStatusConditions` (`:2914-3198`)).
      Delete all four; they actively mislead the next reader into re-doing
      landed work. **DONE 2026-08-29: deleted all four TODO blocks (ExecutePlayerMove header, deferred-leaves line, both status-condition headers).**
- [x] **C.3** `core.asm:7722-7723`: "wEnemyStatsToDouble / wEnemyStatsToHalve —
      now defined directly in gb_memmap.inc (**0xD064/0xD065**, =
      wEnemyBattleStatus1 - 2/-1)". Measured `gb_memmap.inc`:
      `wEnemyStatsToDouble 0xDE32` (`:511`), `wEnemyStatsToHalve 0xDE33`
      (`:512`), `wEnemyBattleStatus1 0xDE34` (`:513`). The relation is right,
      the addresses are wrong by `$DCE`. (This matters: the five-byte
      contiguous clear in `FaintEnemyPokemon` `:7785-7789` and
      `EnemySendOutFirstMon` `:5739-5743` depends on it, and both were verified
      contiguous against pret `ram/wram.asm:1467-1473`.) **DONE 2026-08-29: corrected to 0xDE32/0xDE33.**
- [x] **C.4** `core.asm:7726-7730`: "EXP_ALL — item id constant, **not defined
      anywhere in gb_constants.inc** or dos_port/assets (grepped the whole
      dos_port/ tree)". It is at `gb_constants.inc:702`, and the very next line
      of the same comment says it moved there. Value verified correct (`0x4B`,
      `constants/item_constants.asm:87`). Delete the false claim, keep the
      `%ifndef` guard or delete it too — either is fine, but not a comment that
      contradicts the file two lines below it. **DONE 2026-08-29: replaced false "not defined anywhere" claim with accurate note that it now lives in gb_constants.inc.**
- [x] **C.5** `core.asm:6279` (inside `AnyEnemyPokemonAliveCheck`): "Reached
      only via a wild faint that shouldn't hit this routine at all — **see the
      `wIsInBattle`-guard TODO below**." There is no `wIsInBattle` guard and no
      TODO below; the routine body (`:6284-6308`) has neither. Dangling
      cross-reference — either land the guard it points at or delete the
      pointer. **DONE 2026-08-29: replaced dangling TODO pointer with accurate note that callers guard via `wIsInBattle dec/jz .ret`.**
- [x] **C.6** `SendOutMon`'s header (`core.asm:5468-5487`) says "Two callees are
      ret-stubs, each with its own STUB annotation at its stub site:
      `PrintSendOutMonMessage` and `StarterPikachuBattleEntranceAnimation`
      (battle_stubs.asm)", and the inline comments at `:5490`
      (`call PrintSendOutMonMessage ; callfar … (STUB)`) and `:5538`
      (`call StarterPikachuBattleEntranceAnimation ; callfar (STUB)`) plus
      `:5548` (`call PlayCry ; (STUB — home_stubs.asm)`) repeat it. Re-measure
      with `tools/label_status PrintSendOutMonMessage
      StarterPikachuBattleEntranceAnimation PlayCry` and repoint or delete
      whichever have retired — this is the same class as C.1 and B.3, and the
      file has been wrong about it before (`:5313` records `PlayCry`'s TODO-HW
      being retired 2026-08-21). **DONE 2026-08-29: re-measured all three as `translated`; header rewritten to "All callees are now translated", inline `(STUB)` tags removed.**
- [x] **C.7** `ReplaceFaintedEnemyMon`'s `STILL DROPPED` note
      (`core.asm:5980-5986`) explains why `DrawEnemyPokeballs` stays unwired and
      is the right shape for this ledger — but it is free-form prose where a
      `DEVIATION{}` belongs, and its stated blocker ("pret reaches the screen
      through a shadow-OAM DMA this port deliberately skips while a ball row is
      up") should be re-measured against `PrepareStaticOAM` now that
      `draw_hud_pokeball_gfx.asm` exists as a pret mirror. **DONE 2026-08-29: converted free-form prose to `DEVIATION{class=HAL; pret=engine/battle/core.asm:ReplaceFaintedEnemyMon; ...}`.**

### Stage D — bespoke remnants and unannotated divergences

- [x] **D.1** **Two printers for one pret call.** pret has one `PrintText`; the
      port has `PrintText` (`home/window.asm:128`, reads the `[text_msgbox]`
      projection record) plus a battle wrapper `PrintBattleText`
      (`core.asm:1407`) that sets `text_msgbox = msgbox_centered` and tail-jumps
      to it. Measured in `core.asm` (regex over instruction lines, comments
      excluded): **45** sites call bare `PrintText`, **16** call
      `PrintBattleText`, plus one `jmp PrintBattleText` inside
      `PrintEmptyString` (`:1433`). The file's own justification for the wrapper
      (`core.asm:1414-1429`, at `PrintEmptyString`) is that a bare `PrintText`
      "would draw wherever the LAST printer left the record" and that
      `SendOutMon`'s call "can be the first text of a battle, so that record is
      not reliably the battle box yet" — an argument that applies to all 45.
      The `RestoreBattleScreenState` teardowns at `:3568`, `:3705` and
      `:5866` re-assert the record, which is why this has not visibly broken;
      that is a load-bearing invariant held in four scattered places instead of
      at the call. Decide one rule (wrapper everywhere in battle, or a single
      re-assert at battle entry) and apply it; whatever is chosen, the 45/16
      split is not a rule. **DONE 2026-08-29: adopted wrapper-everywhere rule — converted 48 bare `PrintText` instruction calls/jmps to `PrintBattleText`, leaving only the printer tail `jmp PrintText`; added `DEVIATION{class=projection}` at `PrintBattleText` documenting the wrapper.**
- [x] **D.2** `AnyMoveToSelect` hand-rolls pret's `ld c,60 / call DelayFrames`
      as `mov ecx,60 / .delay: call DelayFrame / dec ecx / jnz .delay`
      (`core.asm:1392-1396`). `DelayFrames` is translated, linked, and
      called 12 times elsewhere in this one file (measured). The unrolled loop is a bespoke remnant (it
      is what makes `faithdiff` report `- DROPPED DelayFrames (call)`) and it
      widens the counter to 32 bits for no reason — harmless here because the
      count is a literal, but it is the wrong shape to leave as an example.
      Replace with `mov bl, 60 / call DelayFrames`. **DONE 2026-08-29: replaced hand-rolled DelayFrame loop with `mov bl,60 / call DelayFrames`.**
- [x] **D.3** `TrainerBattleVictory` adds `mov byte [ebp + wBattleResult], 0`
      (`core.asm:6236`) which pret does not have. It is disclosed in prose at
      `:6238-6243` ("Port-only addition on this path") but carries no
      `DEVIATION{}`. In the normal win path pret has already set it
      (`FaintEnemyPokemon`, pret `:826`), so it is probably redundant — which
      is an argument for deleting it, not for leaving an unannotated store.
      Delete or annotate. **DONE 2026-08-29: kept the store and added `DEVIATION{class=temporary; pret=engine/battle/core.asm:TrainerBattleVictory; ... wBattleResult=0 where pret does not ... port-only store, redundant on normal path}`.**
- [x] **D.4** `TrainerBattleVictory`'s two `%ifndef DEBUG_TRAINER_RESULT`
      blocks (`core.asm:6215-6218`, `:6221-6228`) elide
      `TrainerDefeatedText`, `ScrollTrainerPicAfterBattle`, the 40-frame wait,
      `PrintEndBattleText` and `MoneyForWinningText` in harness builds. This is
      a harness-only divergence with no machine-parsed annotation. It needs a
      `DEVIATION{class=temporary}` (the schema's `class` must be one of
      `HAL|banking|projection|data-model|timing|stub|temporary`). **DONE 2026-08-29: added `DEVIATION{class=temporary}` covering both `%ifndef DEBUG_TRAINER_RESULT` blocks.**
- [x] **D.5** `DrawHUDsAndHPBars` adds two port-only operations pret lacks: a
      `wLetterPrintingDelayFlags` BIT_TEXT_DELAY clear (`core.asm:7173`) and a
      trailing `call SetPal_Battle` (`core.asm:7183`). Both are prose-explained
      and both are plausibly required by the port's text engine and two-slot
      palette publish — but neither is annotated, and `faithdiff` reports both
      (`+ ADDED [wLetterPrintingDelayFlags]`, `+ ADDED SetPal_Battle (call)`).
      Annotate, don't delete. **DONE 2026-08-29: added two `DEVIATION{class=HAL}` annotations at `DrawHUDsAndHPBars` for the BIT_TEXT_DELAY clear and the trailing `SetPal_Battle`.**
- [x] **D.6** Duplicate `extern` declarations in the same file:
      `CopyToStringBuffer` at `:243` and `:296`; `ClearScreenArea` at `:335`
      and `:358`. NASM tolerates it, but the two `ClearScreenArea` comments
      disagree about the register contract (`ESI=wTileMap dest, BH=rows,
      BL=width` vs `BH rows x BL cols of blanks at ESI`) — pick one and delete
      the other, since a reader auditing a call site cannot tell which is
      authoritative. **DONE 2026-08-29: deleted duplicate `extern CopyToStringBuffer` (kept detailed one at :296) and duplicate `extern ClearScreenArea` (kept `ESI=wTileMap dest` variant at :336).**
- [x] **D.7** `PartyMenuOrRockOrRun`'s three port-only teardown stores
      (`g_window_count`, `g_bg_whiteout`, `text_msgbox`, at `:3568-3570` and
      again at `:3705-3707`) and `EnemySendOutFirstMon`'s three (`:5866-5868`) are the
      same obligation repeated in three places (`UseBagItem`/`DisplayBagMenu`
      route through `RestoreBattleScreenState` at `:3502` instead). Consolidate
      on `RestoreBattleScreenState` and give it the `DEVIATION{class=projection}`
      that currently lives, three times over, at the individual sites. **DONE 2026-08-29: replaced all three triples with `call RestoreBattleScreenState`; moved `DEVIATION{class=projection}` onto `RestoreBattleScreenState`.**
- [x] **D.8** `LoadHudTilePatterns` (`core.asm:6970`) collapses pret's
      `ldh a,[rLCDC] / add a / jr c, .lcdEnabled` two-path copy
      (`FarCopyDataDouble` when the LCD is off, `CopyVideoDataDouble` when it is
      on — pret `core.asm:6696-6718`) into a single `rep movsd` pair. Correct
      for a port with no LCD enable state, and `g_tilecache_dirty` is armed
      first as the skill requires — but it is unannotated, and `faithdiff`
      reports both copies DROPPED. One `DEVIATION{class=HAL}` retires it. **DONE 2026-08-29: added `DEVIATION{class=HAL}` at `LoadHudTilePatterns`.**
- [x] **D.9** `slide_amount` (`core.asm:5717`, a file-local `.data` byte
      standing in for pret's `hSlideAmount` HRAM at `ram/hram.asm:34`) is
      correctly `DEVIATION`-annotated at `:5670`. **No action** — listed so the
      next auditor does not re-flag it, and because it is the precedent the
      annotation cites for `hSlideDirection`/`hSlidingRegionSize` in
      `oak_speech2.asm`.

### Stage E — collapsed routines and dead bodies

- [ ] **E.1** **`StartBattle` was collapsed and should not have been.** pret
      `engine/battle/core.asm:135-262` is its own routine: EXP/fought-flag
      resets, the "find first alive enemy mon" scan, `EnemySendOutFirstMon`,
      the 40-frame wait, `SaveScreenTilesToBuffer1`, the
      `.checkAnyPartyAlive`/`.specialBattle` split, the whole
      `.displaySafariZoneBattleMenu` loop (bait/escape-factor odds,
      `.outOfSafariBallsText`, `EnemyRan`), and `.playerSendOutFirstMon`. The
      port has **none of it as `StartBattle`** — it is folded into
      `init_battle.asm:_InitBattleCommon`, self-documented in a
      `DEVIATION{class=projection}` at `init_battle.asm:683` whose own lifetime
      field says *"until the collapsed StartBattle is restored as its own
      pret-labeled routine"*, and whose evidence field admits the collapse is
      why six of `StartBattle`'s callees read as ADDED on the wrong routine.
      `label_status StartBattle` reads `missing`. This is the
      "multiple functions collapsed to one when they shouldn't have been" case
      the audit brief names. **Restore it as its own pret-named routine in this
      mirror**, with `_InitBattleCommon` calling it at pret's position; the
      DEVIATION retires with the move, and `faithdiff` stops misattributing
      `EnemySendOutFirstMon` / `SendOutMon` / `Random` /
      `PrintSafariZoneBattleText` to `InitWildBattle`. Note the Safari half is
      currently only reachable through the harness entry
      `StartBattle_displaySafariZoneBattleMenu` (`debug_dump.asm:336`, externed
      from `init_battle.asm`) — that name is itself a bespoke label invented to
      stand in for the collapsed routine, and it should die with the restore.
- [ ] **E.2** `BattleCore` (pret `core.asm:1`) is the anchor label for the five
      `INCLUDE`d effect tables (`residual_effects_1`, `set_damage_effects`,
      `residual_effects_2`, `always_happen_effects`, `special_effects`). The
      port has all five tables (`extern`ed at `core.asm:298-303` from
      `battle_data.asm`) but not the anchor, so `label_status BattleCore` reads
      `missing`. Either carry the label in the mirrored data file or record a
      `DEVIATION{class=data-model}` saying the anchor has no meaning in a flat
      image. Do not leave a `missing` row unexplained.
- [ ] **E.3** `Func_3d4f5` / `Func_3d523` / `Func_3d529` / `asm_3d52d` /
      `Func_3d536` are pret `IF DEF(_DEBUG)`-only (pret `core.asm:2721-2728`
      gates the three `jp`s; `core.asm:2927-2930` gates `SwapMovesInMenu`'s
      head) and therefore **absent from the retail ROM**. The port translates
      all five faithfully (verified instruction-by-instruction against pret
      `:2824-2875`, including the `ASSERT B_PAD_START == BIT_TRAINER_BATTLE`
      note and the deliberate 8-bit id wrap at `:1322-1324`), `global`s them
      (`core.asm:123-127`), and **never calls them** — that is why `faithdiff`
      reports them DROPPED from `SelectMenuItem` and `SwapMovesInMenu`. The
      bodies are correct; the problem is that ~90 lines of unreachable code
      ship in the EXE and `Func_3d536` is the reason this file's
      `ClearScreenArea` count reconciles the way it does (B.1). Wrap them in
      `%ifdef DEBUG_TESTBATTLE` (mirroring pret's `IF DEF(_DEBUG)`) and add the
      flag to the `make check` smoke matrix the way the overworld plan's I.7 did
      for `DEBUG_NOCLIP`, so they cannot rot unobserved.

### Verified faithful (no action — do not re-audit)

Checked instruction-by-instruction against pret, including pret's own bugs and
its own "pointless"/"redundant" branches:

`MainInBattleLoop` (whole turn pipeline, the link-nybble dispatch, the
Quick Attack → Counter → speed → 50/50 ladder including the
`hSerialConnectionStatus` master inversion; `StringCmp`'s `cp [hl]` polarity
verified against `home/compare.asm:3` and both `ja`/`jb`/`jae` mappings are
correct); `HandlePoisonBurnLeechSeed` and
`HandlePoisonBurnLeechSeed_DecreaseOwnHP` (the `srl b / rr c` ×2 then `srl c` ×2
MaxHP/16 derivation, the "HP < 1024" assumption, the toxic multiply, the
overkill zeroing and the `pop hl`/`dec esi` restores) and
`_IncreaseEnemyHP` (the `-14` MaxHP→HP navigation and the overheal clamp);
`CheckNumAttacksLeft`; `HandleEnemyMonFainted`; `HandlePlayerMonFainted`;
`FaintEnemyPokemon` (the single-byte Bide clear under `BUG_FIX_LEVEL`, the
five-byte status clear, the EXP-ALL halving loop, the `push af`→memory park and
the correctly-inverted `jnz .return` that bug#3 fixed); `EndLowHealthAlarm`'s
two live stores; `AnyEnemyPokemonAliveCheck` (8-bit `dec cl`, correctly
restored); `TrainerBattleVictory`'s music/rival/link arms;
`ReplaceFaintedEnemyMon` (`GetBattleHealthBarColor` with `$30`, the `ldpal
$E4` → `IO_OBP0/1` + `UpdateCGBPal_OBP*` chain, the link RUN early-return with
its ZF contract, the `inc a ; reset Z flag` tail); `RemoveFaintedPlayerMon`'s
alarm guard, the `PikachuCry4`→index-3 lowering (verified against
`audio/pikachu_cries_pointers.asm`'s `pikacry_def` order and the
`macros/pikachu.asm:176` `(\2_id - PikachuCriesPointerTable) / 3` arithmetic)
and the happiness fork; `DoUseNextMonDialogue`; `ChooseNextMon`'s no-cancel
loop; `HandlePlayerBlackOut`; `SlideDownFaintedMonPic` (both slide directions
simulated cell-by-cell: `[hld]/[hli]/inc hl` and `[hli]/[hld]/dec hl` both
reproduce); `SlideTrainerPicOffScreen` (its `DEVIATION` on `slide_amount` is
correct and its "no projection needed because the window is edge-anchored"
argument holds); `EnemySendOut` / `EnemySendOutFirstMon` (the `$ff` scan, the
four switch-prompt early-outs, the `wLastSwitchInEnemyMonHP` snapshot, the
`-$31` `hStartTileID`, the `DrawEnemyHUDAndHPBar`-only draw, the
`SwitchPlayerMon` tail); `AnyPartyAlive` (8-bit wrap preserved on purpose, with
the Oak-intro regression reasoning intact); `TryRunningFromBattle`'s odds math
(the `hMultiplicand`/`hEnemySpeed` staging, the ×32, the enemy-speed `/4` with
`srl b / rr a` pairs, the byte divide, the `+30` per attempt, the link RUN
exchange); `LoadBattleMonFromParty` / `LoadEnemyMonFromParty` (chunk-for-chunk,
including the `MON_DVS - MON_OTID` source skip and the Gen-2 offset-7
non-clobber); `SendOutMon`; `AnimateRetreatingPlayerMon` (the `push af`/`pop bc`
→ `push eax`/`pop ebx` B-slot reasoning is right); `ReadPlayerMonCurHPAndStatus`
(direction corrected, and the copy length `MON_STATUS + 1 - MON_HP`);
`DisplayBattleMenu` (the flag-neutral `ld`/`mov` crossings at `.menuselected`,
`.leftColumn`, `.rightColumn` and `.AButtonPressed` are all preserved; the
Safari-skips-the-ID-swap branch is correct); `BagWasSelected` /
`DisplayPlayerBag` / `DisplayBagMenu` / `UseBagItem`; `PartyMenuOrRockOrRun`
(the dex-keyed `LoadMonFrontSprite` `DEVIATION` and its `wPokedexNum`
save/restore are correct); `SwitchPlayerMon`; `MoveSelectionMenu`;
`SelectMenuItem` (the 1-based sentinel cursor model, the `push af`→`pushfd`
B-verdict carry, the PP/disabled/Transform ladder);
`SelectMenuItem_CursorUp/_CursorDown`; `SwapMovesInMenu`; `PrintMenuItem`;
`AnyMoveToSelect`'s PP scan (both the plain and the disabled-move paths,
including the `$3f` PP-up mask); `SelectEnemyMove`; `LinkBattleExchangeData`;
`ExecutePlayerMove` / `ExecuteEnemyMove` and all six `IsInArray` checkpoints,
the multi-hit re-entry at `GetPlayerAnimationType`, the `.pTargetFainted`
`xor bh,bh` ↔ pret's `ld b,[hl]` B=0 contract; `CheckPlayerStatusConditions` /
`CheckEnemyStatusConditions` in full (sleep/freeze/trap/flinch/recharge/disable/
confusion/paralysis/Bide/Thrash/multi-turn/Rage, the Bide `add/adc` accumulate
and the `add a`+`rl a` doubling, the `jp hl`→`jmp esi` continuation);
`HandleSelfConfusionDamage`; `PrintMoveIsDisabledText`; `CheckForDisobedience`;
`GetDamageVarsForPlayerAttack` / `GetDamageVarsForEnemyAttack`;
`GetEnemyMonStat`; `CalculateDamage` (the whole
`hDividend`/`hMultiplier`/`Divide`/`Multiply` ladder including the
`EXPLODE_EFFECT` `srl c / jr nz / inc c` min-1, the level×2 carry, the +2, and
all three cap stages against `MAX_NEUTRAL_DAMAGE - MIN_NEUTRAL_DAMAGE`;
verified that `home/math.asm`'s `Multiply`/`Divide` wrappers preserve BX/DX/ESI
so the port's reliance on BH/BL/DH/DL surviving is sound);
`JumpToOHKOMoveEffect`; `CriticalHitTest`; `AdjustDamageForMoveType`;
`AIGetTypeEffectiveness`; `MoveHitTest` (Dream Eater, Swift, the
`CheckTargetSubstitute` overwrites-A glitch, INVULNERABLE, both mist ladders,
both X-Accuracy escapes, the `jae` 1/256 miss, both `res USING_TRAPPING_MOVE`
tails); `CalcHitChance`; `RandomizeDamage`; `HandleCounterMove`;
`ApplyAttackTo{Enemy,Player}Pokemon` / `ApplyDamageTo{Enemy,Player}Pokemon`;
`HandleBuildingRage`; `MirrorMoveCopyMove`; `ReloadMoveData` (the flat-source
inline copy and the `mov edx, wNameBuffer` compensation are both correct and
documented); `IncrementMovePP`; `MetronomePickMove` (structure — see A.1 for
the constant); `PrintGhostText` / `IsGhostBattle`; `PrintCriticalOHKOText`
(`dec a / add a` → `*4` on the widened `dd` table); `PrintMoveFailureText`;
`GetCurrentMove`; `LoadEnemyMonData`; `ApplyBurnAndParalysisPenalties*`;
`QuarterSpeedDueToParalysis`; `HalveAttackDueToBurn`;
`CalculateModifiedStats` / `CalculateModifiedStat`;
`DoubleOrHalveSelectedStats`; `ApplyBadgeStatBoosts`; `BattleRandom` (the
`ret c` seed-index contract and the ×5+1 reseed loop);
`HandleExplodingAnimation` (structure — see A.3/A.4 for the constants; the
"pret reads `wEnemyBattleStatus1` in BOTH branches" verbatim quirk is
correctly preserved); `PlayMoveAnimation`; `GetBattleHealthBarColor`;
`CenterMonName`; `DrawPlayerHUDAndHPBar` (the `wLoadedMon` staging,
`CenterMonName`, the status-vs-level rule, and the low-health-alarm tail where
the store precedes the bit test exactly as pret's flag-neutral `ld [hl],0`
requires); `PrintEmptyString` / `BattlePromptWait` (the `wLinkState`
65-frame `ManualTextScroll` arm is correctly restored).

## Sequencing

A first, alone: it is the only outright data bug and every later stage's golden
run is noise until Metronome/Mirror Move/explode pick the right moves. Then B
(any order; B.1 and B.2 are one-line insertions, B.3/B.5 are small, B.9 needs
its provider measured first). Then E.1 — it is the largest change and it moves
`faithdiff`'s baseline for `InitWildBattle`/`StartBattle`, so land it before
re-reading any call-graph evidence. C and D are comment/annotation work and must
come **after** the code stages so the comments describe the final state. E.2/E.3
are independent.
