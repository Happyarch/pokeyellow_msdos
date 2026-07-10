# Battle-Engine Faithfulness Audit — Findings Report

**Date:** 2026-07-01
**Method:** Read-only 11-auditor swarm (Sonnet), Opus aggregation. Every port `.asm`
routine compared line-by-line to its same-named pret label; every generator compared
to the pret data it parses. Fidelity boundary = `docs/plans/move_translation_divergence.md`
§2 allowlist (subanimation→ANIMATION=OFF, audio no-ops, raw `$FF__` I/O, bank/callfar/
jpfar/predef→flat call). Everything else must match pret; Gen-1 bugs must be preserved+tagged.

**Scope covered:** ~118 routines/tables across `dos_port/src/engine/battle/` (core turn
loop, damage, residual, 34 move-effect handlers + dispatch table, HUD/menu/init,
encounters/exp/pokéballs, trainer AI) and 7 Tier-1 data generators.

**Aggregate verdict:** The *translated logic* is overwhelmingly faithful — the damage
pipeline, residual damage, all of move-effects B (12/12), most of move-effects A & C,
trainer-AI source, and all 7 generators are clean, with every expected Gen-1 bug/glitch
present and correctly tagged. The real findings cluster in the **core turn-loop
(`core.asm`)** — largely fresh regressions from the recent Stage-2.5/3 rewrite — plus a
few HUD/menu edge bugs and one generator truncation bug. Separately, several byte-faithful
routines are **not linked into the live EXE** (coverage gaps, not fidelity bugs).

Legend: **[CONFIRMED]** = aggregator re-verified against source; **[reported]** = single-auditor
finding, well-cited, not independently re-verified. Owner = suggested Master (A = turn-loop/
damage core; B = move-effect handlers + effect/text data; C = HUD/menu/init, encounters/exp,
AI wiring, generators). **[RESOLVED]** = fixed on `master` after this audit — do not re-do.

> **Line-number currency (updated 2026-07-01):** port-side `file:line` citations were
> captured against the pre-`c3325e1e` tree and have since drifted (`c3325e1e` alone shifted
> `core.asm` by ~150 lines, and `battle_menu.asm` was later reduced to draw-helpers only).
> The port citations below were **refreshed to current `HEAD`** where the anchor is an
> unambiguous named routine; inner-line and moved-file citations are marked *(verify @HEAD)*.
> **pret** citations are stable (read-only source). **Always locate by routine label, not by
> line** — masters will re-shift these files anyway. **A-1 is already fixed on `master`
> (`c3325e1e`); it is struck from Master A's workpool.**

---

## TIER 1 — CRITICAL / HIGH (real, reachable state or gameplay corruption)

### A-1. `CheckForDisobedience` stub never clears ZF → every non-charging player move silently no-ops **[RESOLVED — c3325e1e]**
- **RESOLVED on `master` (`c3325e1e`, 2026-07-01):** the stub now does `mov al,1 / and al,al / ret`
  (clears ZF → "obeys"), exactly the fix below, with a comment documenting the flag contract.
  **Struck from Master A's workpool.** Retained here for the record.
- **File:** `dos_port/src/engine/battle/core.asm:1383` (def) / call site `:644`
- **pret:** `engine/battle/core.asm:3270` (`call CheckForDisobedience` / `jp z, ExecutePlayerMoveDone`), real body `:4001-4178`
- **What's wrong:** `CheckForDisobedience:` is a bare `ret`. Its only caller (`:642`) is reached
  by fall-through when `jnz PlayerCanExecuteChargingMove` (`:641`) is NOT taken — which means the
  preceding `test [wPlayerBattleStatus1], 1<<CHARGING_UP` left **ZF=1** (the mon is not charging =
  the common case for any normal attack). `ret` preserves flags, so `jz ExecutePlayerMoveDone`
  (`:643`) fires unconditionally. Result: menu selection completes, then the player's turn ends
  before `DisplayUsedMoveText`/`DecrementPP`/damage — **no attack, no PP use, no message**, for
  essentially every ordinary move. The inline comment claims "(stub: obeys → ZF=0)" but the code
  never sets that. Sibling stubs (`PrintGhostText`, `HandleCounterMove` in `core_stubs.asm`)
  correctly do `mov al,1 / and al,al`; this one is the outlier.
- **Fix:** make the stub honor the "obeys" contract (clear ZF), e.g. `mov al, 1 / and al, al / ret`.
- **Note:** fresh regression from the Stage-2.5 rewrite; the "live wild battle plays end-to-end"
  note in `docs/current_plan_battle_pret_alignment.md` predates it. Not listed among the deferred
  leaves in `translation_log.md`. **Owner A. Severity: high (core gameplay broken in the live build).**

### A-2. `ApplyAttackTo{Enemy,Player}Pokemon` — missing Super-Fang / Special-Damage dispatch + Substitute redirect (both sides) **[CONFIRMED]**
- **[LIKELY RESOLVED post-audit — verify @HEAD before ticketing]:** the dispatch the audit reported
  as *absent* is now present — `SUPER_FANG_EFFECT`/`SPECIAL_DAMAGE_EFFECT` branches at `core.asm:921-923`
  (enemy) and `:1583-1585` (player), and the `HAS_SUBSTITUTE_UP` → `AttackSubstitute` redirect at `:978`.
  Confirm the *values* are faithful (Seismic Toss=level, Sonic Boom=20, Dragon Rage=40, Psywave range,
  Super Fang=½ curHP) before assigning; the finding below describes the pre-fix state.
- **Files:** `core.asm:917` (`ApplyAttackToEnemyPokemon`), `core.asm:1579` (`ApplyAttackToPlayerPokemon`)
- **pret:** `engine/battle/core.asm:4783-4900` (enemy target) / `:4902-5018` (player target)
- **What's wrong:** both port routines implement only pret's *tail* (plain HP-subtract clamped at 0).
  Pret's real routine header additionally computes damage inline for:
  - **`SPECIAL_DAMAGE_EFFECT`** — Seismic Toss / Night Shade (= level), Sonic Boom (20),
    Dragon Rage (40), Psywave (random 0..level·1.5), and
  - **`SUPER_FANG_EFFECT`** — half the target's current HP.
  These effect ids are in `data/battle/set_damage_effects.asm`'s `SetDamageEffects`, so the turn
  flow deliberately **skips `CalculateDamage`** for them (`jc .moveHitTest` at `:674`/`:1288`) — their
  damage is *only* produced inside `ApplyAttackTo*`. Since that dispatch is absent, `wDamage` is
  stale garbage (typically the previous unrelated attack's value) for all six moves. They correctly
  map to `UnportedMoveEffect` in `effects.asm:218-219` (matching pret's NULL), but that is the wrong
  place — pret computes them here, not via `JumpMoveEffect`.
  - **Substitute:** pret redirects damage to the target's substitute HP (`bit HAS_SUBSTITUTE_UP` →
    `jp nz, AttackSubstitute`, pret `:4856`/`:4976`). `AttackSubstitute` is unimplemented repo-wide
    → Substitute gives **zero** protection on either side. (The `current_plan` "Substitute pic-swap"
    note covers only the *animation*, not this damage-redirect.)
- **Fix:** port the pret routine headers (special-damage/super-fang branches + `AttackSubstitute`).
- **Docs:** no `translation_log.md` entry for either name. **Owner A. Severity: high.**

### A-3. Orphaned `SwapPlayerAndEnemyLevels` in Bide-unleash → permanent level-field corruption (both sides) **[RESOLVED — c3325e1e]**
- **RESOLVED on `master` (`c3325e1e`):** zero `call SwapPlayerAndEnemyLevels` sites remain in
  `core.asm`; the player-unleash block (`CheckPlayerStatusConditions`, now `:1040`) carries a comment
  documenting why no swap belongs there. **Struck from Master A's workpool.**
- **Files:** `core.asm:1040` (`CheckPlayerStatusConditions`, player Bide unleash), `core.asm` enemy
  Bide unleash in `CheckEnemyStatusConditions` (now `:1716`); `SwapPlayerAndEnemyLevels` def now `:1348`
- **pret:** player `.UnleashEnergy` `:3674-3700` — **no swap**. The enemy path's swaps (`:5735/:5768`)
  live in `HandleIfEnemyMoveMissed` continuations that the port *correctly stripped* (its
  `CriticalHitTest`/`MoveHitTest` branch on `hWhoseTurn` instead of the memory-swap trick).
- **What's wrong:** the port kept a `call SwapPlayerAndEnemyLevels` in each Bide-unleash block, but
  the paired un-swap is gone (stripped elsewhere), and the block jumps straight to
  `HandleIfPlayerMoveMissed`. So after the **first** Bide unleash by either side, `wBattleMonLevel`
  and `wEnemyMonLevel` stay swapped for the rest of the battle — corrupting `GetDamageVarsFor*Attack`,
  the HUD level, and EXP math. `SwapPlayerAndEnemyLevels` itself (`:1197`) is byte-faithful; the bug
  is purely the orphaned call sites.
- **Fix:** **delete** both `call SwapPlayerAndEnemyLevels` in the Bide-unleash paths (do not add a
  swap-back — pret has neither).
- **Docs:** `translation_log.md:4003-4009` claims Bide is "release 2× via SwapPlayerAndEnemyLevels"
  for both sides and "Divergences: none" — inaccurate. **Owner A. Severity: high.**

### C-4. `gen_battle_text.py` truncates `text_far`+`text_asm` streams → stat-stage move messages lose their verb + prompt **[CONFIRMED]**
- **Files:** generator `dos_port/tools/gen_battle_text.py` (`collect_wrappers`); symptom in
  `dos_port/assets/battle_text.inc:269-274` (`MonsStatsRoseText`/`MonsStatsFellText`), consumed by
  `stat_mod_effects.asm:218,389`
- **pret:** `engine/battle/effects.asm:552-573,727` — `MonsStatsRoseText` is `text_far _MonsStatsRoseText`
  **followed by a `text_asm`** that branches on the effect id to append `RoseText`(" rose!") /
  `GreatlyRoseText`("greatly rose!") + `text_end`; same for Fell.
- **What's wrong:** the generator's wrapper scan breaks at the `text_far` line and never emits the
  `text_asm` continuation. Generated bytes end `…0x50, 0x50` (bare `text_end`) instead of the
  sibling pattern `…0xE7, 0x58` (`<PROMPT>`). Net: **every** stat-stage move (Growl, Tail Whip,
  Swords Dance, Amnesia, Sand-Attack, String Shot, Leer, Screech, …) prints "`<MON>'s`↵`STAT`" and
  stops — no "rose!/fell!/greatly", and no `<PROMPT>` button-wait. Per §3 all `XxxText` streams must
  be faithful; not allowlisted.
- **Resolves an inter-auditor conflict:** the generator auditor rated `gen_battle_text.py` FAITHFUL,
  but only spot-checked simple `text_far`-only wrappers; the move-effects auditor caught the
  `text_far`+`text_asm` case. Verified: the truncated bytes are real in the committed `.inc`.
- **Fix:** teach `collect_wrappers` to carry the branch text; or hand-author these two composite
  streams in code (Tier-2), matching pret's per-effect-id branch. **Owner C (generator). Severity: high.**

---

## TIER 2 — MEDIUM-HIGH (reachable edge bugs / silently-dropped Gen-1 quirk)

### C-5. `battle_hud.asm` — level-100 digit overflow + silently "fixed" Gen-1 maxHP>255 HP-bar quirk **[reported]**
- **File:** `battle_hud.asm:313` (`print_num2`), `:207`/`:215` (`calc_hp_pixels`/`hp_to_pixels`)
- **pret:** `PrintLevel` `home/pokemon.asm:363` (level≥100 writes a 3rd digit); `GetHPBarLength`
  `engine/gfx/hp_bar.asm:6-45` + enemy path `core.asm:1957-2033`
- **What's wrong:** (a) `print_num2` is hard-coded to 2 digits; at level 100 the tens digit computes
  AL=10, `add al, CHAR_DIG0` wraps the byte → garbage tile instead of "100" (level 100 is the legit
  Gen-1 max, reachable). (b) The Gen-1 HP-bar routine right-shifts *both* HP·48 and maxHP by 2 (÷4,
  lossy) before an 8-bit divide when maxHP≥256 — a hardware-precision quirk. The port does one exact
  32-bit divide, silently producing a *more accurate* (different) bar for any mon with maxHP>255. Per
  the fidelity boundary this "silent fix" is a divergence (should be preserved, or `BUG_FIX_LEVEL`-gated).
- **Owner C. Severity: medium-high (both reachable, both silent, both unflagged).**

### C-6. `TryRunningFromBattle` — missing Safari/Ghost/link "always-escape" branches **[reported]**
- **File:** `battle_menu.asm` *(verify @HEAD — this file was reduced to draw-helpers after the audit;
  the cited menu-behavior routine moved to `core.asm` `MoveSelectionMenu`/`DisplayBattleMenu` region)*
- **pret:** `engine/battle/core.asm:1536-1546` (guaranteed escape for `IsGhostBattle`,
  `BATTLE_TYPE_SAFARI`, `BATTLE_TYPE_RUN`, `LINK_STATE_BATTLING` before the speed formula)
- **What's wrong:** the port only branches on `wIsInBattle==2` (trainer). But `InitBattleVariables`
  already faithfully sets `BATTLE_TYPE_SAFARI` (`init_battle_variables.asm:54-59`), so a Safari-Zone
  RUN runs the normal speed-based escape-odds instead of always succeeding — **reachable**. Ghost/link
  omissions are lower (not yet reachable / Phase-4). Also: on failed escape pret sets
  `wForcePlayerToChooseMon=1` + re-saves screen (`:1619-1623`); the port does neither (subsumed by the
  tracked multi-mon deferral). **Owner C. Severity: medium-high (Safari case).**

### A-7. `wAILayer2Encouragement` never incremented in `ExecuteEnemyMove` → AI move-weighting broken **[reported]**
- **File:** `core.asm` `ExecuteEnemyMove` — **increment now present** at `core.asm:1412`
  (`inc byte [ebp+wAILayer2Encouragement]`, cites pret `:5656-5657`). *Increment half RESOLVED;* the
  consumer wiring (`AIMoveChoiceModification2`, `trainer_ai.asm:288`) remains Owner C. **Verify @HEAD.**
- **pret:** `engine/battle/core.asm:5656-5657` (`ld hl, wAILayer2Encouragement; inc [hl]`); consumed
  by `AIMoveChoiceModification2` (`trainer_ai.asm:288`, live dispatch); reset on switch-in (pret `:925`,
  unported)
- **What's wrong:** the counter never advances, so the "2nd move onward" AI weighting never engages
  correctly. (Interacts with the AI-wiring coverage gap below — currently the AI move-select path
  isn't even called, so this is latent until that is wired.) **Owner A (increment) / C (AI). Severity:
  medium-high once AI move-select is live.**

---

## TIER 3 — MEDIUM (correctness gaps, lower reachability today)

### B-8. `DelayFrames` register-convention bug — `mov cl, N` instead of `mov bl, N` (systemic) **[CONFIRMED]**
- **Battle files:** `move_effects/focus_energy.asm:31`, `move_effects/leech_seed.asm:48`
- **Also (out of battle scope, same bug):** `engine/menus/swap_items.asm:56,75`,
  `engine/pokemon/evos_moves.asm:142,163`
- **Callee:** `dos_port/src/video/frame.asm:213-224` — `DelayFrames` tests/decrements **BL** only,
  never touches CL, and exits BL=0.
- **What's wrong:** these 6 sites load the frame count into CL (a dead write). Because `DelayFrames`
  leaves BL=0 and nothing resets it, the intended delay runs for ~0 frames (or garbage BL). Cosmetic
  timing only — no WRAM/state corruption. Project-wide: 21 sites correctly use `mov bl,`, 6 use the
  buggy `mov cl,`. Note: `translation_log.md:1439-1447/1813-1821` deliberately logged a "C→CL" choice
  that was never reconciled with the BL calling convention.
- **Fix:** `mov cl,` → `mov bl,` at all 6 sites. **Owner B (battle two); flag menus/pokemon owners for the other 4. Severity: medium/low (cosmetic).**

### C-9. `LearnMoveFromLevelUp` — new move not synced into `wBattleMonMoves`/`wBattleMonPP` **[reported]**
- **File:** `battle_menu.asm` *(verify @HEAD — file reduced to draw-helpers after the audit; re-locate
  the cited routine in `core.asm`)*
- **pret:** `LearnMove` `engine/pokemon/learn_move.asm:53-63` — when the leveling mon is the active
  battle mon, also copies the new move into `wBattleMonMoves`/`wBattleMonPP` (the struct the FIGHT
  menu reads).
- **What's wrong:** the port writes only the party struct, never `wBattleMonMoves`/`wBattleMonPP`
  (grep-confirmed: no writer in the file). A mid-battle level-up that teaches a move is invisible to
  the FIGHT menu until the next battle. (Currently low-reachability behind the multi-mon deferral,
  but independent and unflagged.) **Owner C. Severity: medium.**

### A-10. `HandleEnemyMonFainted` — EXP ALL dispatch missing (unflagged) **[reported]**
- **File:** `core.asm` `HandleEnemyMonFainted` (`:1994`)
- **pret:** `engine/battle/core.asm ~808-867` — checks the bag for `EXP_ALL`; if present, halves the
  exp inputs, awards to the fought mons (`wBoostExpByExpAll=0`), then re-awards to the whole party
  (`wBoostExpByExpAll=TRUE`, all `wPartyGainExpFlags` set).
- **What's wrong:** the port calls `GainExperience` once unconditionally — EXP ALL does nothing. No
  TODO flags it (unlike the routine's other, well-documented multi-mon deferrals). Also heads-up for
  whoever ports `FaintEnemyPokemon`: preserve the Gen-1 half-zeroed `wPlayerBideAccumulatedDamage`
  link-desync bug (pret `:756-764`) under a `BUG_FIX_LEVEL` gate. **Owner A/C. Severity: medium.**

### C-11. `SwitchEnemyMon` drops pret's link-state `CF=0` guard **[reported]**
- **File:** `trainer_ai.asm:1002` (`stc; ret` unconditionally)
- **pret:** `engine/battle/trainer_ai.asm:618-622` (`cp LINK_STATE_BATTLING; ret z` → CF=0 in a link
  battle, else CF=1)
- **What's wrong:** dormant via the `TrainerAI` path (link excluded upstream), but wrong for the
  direct `callfar SwitchEnemyMon` at `core.asm:377`, reached only in a link battle. **Owner C.
  Severity: medium (dormant until Phase-4 link).**

### C-12. `ReadTrainer` prize-money is a no-op stub **[reported]**
- **File:** `read_trainer_party.asm:238-247` (`AddBCDPredef_stub`, extern at `:70`)
- **pret:** `read_trainer_party.asm` `.FinishUp` loops `wCurEnemyLevel`× calling `AddBCDPredef` into
  `wAmountMoneyWon`.
- **What's wrong:** stub is a pure no-op → prize money always 0. Clearly commented `; TODO-MATH`
  (declared, not silent), but a real functional gap once trainer battles are wired. Blocked on porting
  `home/predef.asm` BCD adder (`AddBCDPredef`). **Owner C. Severity: medium (tracked).**

---

### W-1. `InitBattle` corrupts the BG tile cache — overworld renders as solid grass after a wild encounter **[CONFIRMED — runtime, 2026-07-10]**

- **Symptom:** with wild encounters live, walking into Route 1 grass until an encounter fires turns the
  whole screen into one repeated grass tile.
- **Isolation (three-point A/B, live DOSBox-X):**
  1. `DISABLE_WILD=1` (both `NewBattle` call sites de-wired, verified via `nm -u src/engine/overworld/overworld.o`
     showing no `NewBattle` reference) → **corruption gone**. So it is on the encounter path.
  2. `SKIP_INITBATTLE=1` (encounter roll + the whole faithful `.battleOccurred` return path stay live —
     `AnyPartyAlive` → `DelayFrames 10` → `jmp EnterMap` — but `call InitBattle` is removed, verified via
     `nm -u src/engine/overworld/wild_encounter_check.o`) → **corruption gone**.
  3. Therefore the fault is inside **`InitBattle` / the bespoke battle-screen renderer**, NOT in
     `OverworldLoop`'s encounter trigger, NOT in `NewBattle`/`TryDoWildEncounter`, and NOT in the
     post-battle `EnterMap` reload. The overworld side is exonerated.
- **Why it only surfaced now:** encounters were gated off behind `-D WILD_ENCOUNTERS_LIVE` until the
  wild-live promotion (2026-07-10), so nothing had ever driven `InitBattle` from `OverworldLoop`. The
  `DEBUG_BATTLE` harness enters the battle screen from a *cold* boot, which is why the golden suite
  never caught it.
- **Prime suspect:** `g_tilecache_dirty`. CLAUDE.md's rule is that any routine writing VRAM tile data
  must set it, so `render_bg` re-decodes `tile_cache`. `InitBattle`'s tile loads mostly route through
  `copy2.asm`/`pics.asm`/`load_font.asm` (all of which do set it), so the leak is more likely a direct
  VRAM write, or state (`wSurroundingTiles` / the tileset header) left stale for the returning map.
- **Owner: battle. Severity: HIGH — this is the default gameplay path now.** Not fixed in the wild-live
  promotion (out of its scope: it is squarely battle-engine, and the promotion's own paths are proven
  clean by the A/B above).

### W-2. `pokeballs.asm` writes VRAM tile data without setting `g_tilecache_dirty` **[CONFIRMED — static]**

- Every other VRAM-tile writer in the tree sets the flag (`pics.asm`, `load_font.asm`, `copy2.asm`,
  `bg_anim.asm`, `title.asm`, `map_sprites.asm`, `update_map.asm`, `player_gfx.asm`, `overworld.asm`,
  `init.asm`, and four `engine/menus/*`). `src/engine/battle/pokeballs.asm` is the sole exception.
- Not on the W-1 repro path (no ball is thrown), so it is a *separate* latent bug: the decoded
  `tile_cache` will hold stale tiles after the ball animation writes VRAM.
- **Owner: battle. Severity: medium (latent).**

---

## TIER 4 — COVERAGE GAPS (byte-faithful or absent code not wired into the live EXE — re-scope tickets, not fidelity bugs)

These are the biggest *functional* gaps but are tracked deferrals, not divergences in translated logic:

- **Trainer AI move-selection is dead code.** `SelectEnemyMove` (`select_enemy_move.asm:73-74`) never
  calls `AIEnemyTrainerChooseMoves` — trainer battles use the same uniform-25%/slot random selection
  as wild battles. The entire byte-faithful `trainer_ai.asm` move-scoring engine (Mods 1/2/3 +
  47-entry class table) is unreachable. Disclosed in the file header + `translation_log.md:3004-3009`.
  **Owner C.**
- **Whole subsystems are `BATTLE_SRCS` check-only (compiled, not linked):** `trainer_ai.asm`,
  `wild_encounters.asm` (`TryDoWildEncounter`), `read_trainer_party.asm` (`ReadTrainer`). Wild-encounter
  triggering and trainer-party population in the running game bypass this validated logic. The live
  core also uses the `core_stubs.asm` `TrainerAI` (returns CF=0). **Owner C.**
- **`ItemUseBall` (Gen-1 catch algorithm) does not exist** anywhere in the port — not even stubbed.
  `pokeballs.asm` is a red herring (it's `draw_hud_pokeball_gfx.asm`, the intro ball-icon HUD, faithful
  for what it is). Tracked in `docs/current_plan_items.md` ("item USE dispatch deferred"). **Owner C.**
- **`core_stubs.asm` degraded moves (contracts safe, bodies deferred):** `HandleCounterMove` →
  Counter resolves as a normal 1-BP hit; `MetronomePickMove` → Metronome always whiffs (0-BP);
  `MirrorMoveCopyMove` → Mirror Move always "fails". All return a legitimate pret branch value (no
  state corruption). **Owner A/B.**
- **Faint/blackout/multi-mon flow:** `HandlePlayerMonFainted` ends every battle as a loss on first
  faint; `HandleEnemyMonFainted` lacks multi-mon switch-in / blackout / trainer-victory. Self-documented,
  matches `current_plan_battle_pret_alignment.md`. **Owner A/C.**
- **Battle-mon refresh stubs:** `CalculateModifiedStats` / `DrawPlayerHUDAndHPBar` in
  `battle_exp_stubs.asm` are `ret`-only, so a mid-battle level-up updates raw stats/HP correctly but
  doesn't recompute stage-modified stats or redraw the HP HUD until the next natural recompute.
  Documented. **Owner C.**

---

## TIER 5 — LOW / PROCESS (documentation, style, inert)

- **`translation_log.md` incomplete/inaccurate (multiple):** the `Stage 2.5 + 3` entry claims
  "Divergences: none beyond the leaf stubs" for `ExecutePlayerMove`/`ExecuteEnemyMove` — false given
  A-3 (Bide swap) and A-7 (AILayer2). No per-routine entries for `core_damage.asm` routines,
  `ApplyAttackTo{Enemy,Player}Pokemon`, `HandleEnemyMonFainted`, or `CheckForDisobedience`. Violates
  CLAUDE.md Workflow step 6. **Owner A.**
- **`GetCurrentMove` drops the inert `GetName`/`CopyToStringBuffer` name-fetch tail** (pret
  `core.asm:6166-6172`). Verified inert (all real callers fetch the name themselves); worth a
  `; DIVERGENCE(inert):` note. `get_current_move.asm`. **Owner A. Low.**
- **Gen-1 bugs lacking `%if BUG_FIX_LEVEL` blocks (style):** Focus Energy crit inversion
  (`core_damage.asm:520`) and the `$10`-init in `AIGetTypeEffectiveness` (`:890`) are present +
  commented but have no gated "fixed" alternate. Acceptable per the `residual_damage.asm` precedent
  for un-implemented-fix glitches, but inconsistent with the guarded "invulnerable-whole-battle" glitch.
  **Owner A. Low.**
- **Generator doc nits:** `gen_battle_text.py` misattributes control-code byte source to
  `constants/text_constants.asm` (real source `macros/scripts/text.asm`); `gen_trainer_parties.py`
  derives `NUM_TRAINERS` as `max(const)` vs pret's literal `const_value-1` (equivalent). **Owner C. Low.**
- **`TrainerAI` reload-branch comment** ("al was 0") describes the wrong trigger (actual: `wAICount==0xFF`);
  code is correct. `trainer_ai.asm`. **Owner C. Low.**
- **`heal.asm` local `REST_MOVE_ID equ 156`** instead of a centralized constant (blocked by a NASM
  name collision with `REST`); functionally correct. **Owner B. Low.**

---

## Owner summary (re-scoping the implementation swarm)

**Master A — turn-loop & damage core (`core.asm`):** A-1 (disobedience ZF — *do first, it breaks the
live build*), A-2 (special-damage/super-fang + AttackSubstitute, both sides), A-3 (delete orphaned Bide
swaps, both sides), A-7 (AILayer2 increment), A-10 (EXP ALL + preserve FaintEnemyPokemon Bide bug), plus
the `translation_log.md` corrections and the `core_stubs.asm` Counter/Metronome/Mirror-Move bodies.

**Master B — move-effect handlers + effect/text data:** B-8 (DelayFrames CL→BL in focus_energy +
leech_seed). Otherwise move-effects are clean (A/B/C slices: ~30/33 faithful, all bug tags intact).

**Master C — HUD/menu/init, encounters/exp, AI wiring, generators:** C-4 (gen_battle_text
text_far+text_asm truncation — highest-value C item), C-5 (HUD level-100 + maxHP>255), C-6 (Safari RUN),
C-9 (LearnMove battle-mon sync), C-11 (SwitchEnemyMon link guard), C-12 (prize money BCD), and the Tier-4
wiring gaps (SelectEnemyMove→AI, link `TryDoWildEncounter`/`ReadTrainer`/`trainer_ai` into the live build,
`ItemUseBall`).

**Clean (no action):** damage pipeline (`core_damage.asm` 11/12 + 1 scoped BattleRandom stub),
`residual_damage.asm` (both Gen-1 glitches preserved), move-effects B (12/12), all 7 data generators
(re-generate byte-identical), and the trainer-AI *source* (byte-faithful — the gap is wiring, not fidelity).
