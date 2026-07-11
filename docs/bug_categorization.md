# Bug / Glitch Categorization Ledger

Deliverable of `docs/current_plan_bug_tagging.md` Phase A (also the TODO Phase 6
categorization deliverable). Comment-only `BUG`/`GLITCH` tags — zero behavior
change at `BUG_FIX_LEVEL=0`. Sources: `docs/bugs_and_glitches.md` (pret bug
list) and `docs/references/yellow_glitches.md` (full glitch catalogue,
referenced from `docs/glitch_safety.md`).

Columns: **Bug/Glitch** | **Source ref** | **Severity + reasoning** | **Ported?**
| **Routine (file:label)** | **Tagged?**

Severity rubric (from the plan doc): `critical` = can corrupt saved/party/box
data, crash/hang, desync battle state, or change gameplay outcome. `cosmetic`
= visual/text/audio-only, no gameplay-state effect. Ambiguous cases default to
critical. `GLITCH` = intentional/exploitable, tagged with a `Safety:` rating
instead of a severity.

---

## `docs/bugs_and_glitches.md` (4 entries)

| Bug | Source ref | Severity + reasoning | Ported? | Routine | Tagged? |
|---|---|---|---|---|---|
| Options menu fails to clear joypad state on init | bugs_and_glitches.md#options-menu-code-fails-to-clear-joypad-state-on-initialization | cosmetic — shifts one option row left/right on the opening frame only; no save/party/battle-state effect, matches doc's own "(bug or feature!)" framing | Yes | `dos_port/src/engine/menus/options.asm:DisplayOptionMenu_` | Yes |
| Battle transitions fail to account for scripted battles (Oak-catches-Pikachu wRivalName/wPartyMon1HP read) | bugs_and_glitches.md#battle-transitions-fail-to-account-for-scripted-battles | critical (ambiguous — defaults critical per rubric; reads stale/uninitialized WRAM to pick a transition ID, no crash but data-dependent on layout) | **No** | pret `engine/battle/battle_transitions.asm:GetBattleTransitionID_CompareLevels` — not present anywhere in `dos_port/src`; the port's `init_battle.asm` (`_InitBattleCommon`) is a bespoke collapsed battle-init that skips pret's `DoBattleTransitionAndInitBattleVariables` transition-ID selection entirely (single fixed transition, no `BattleTransitions` jump table) | Pending port |
| `wPikachuFollowCommandBuffer` can overflow (`AppendPikachuFollowCommandToBuffer`, "Pikawalk") | bugs_and_glitches.md#wpikachufollowcommandbuffer-can-overflow | critical — unbounded buffer write into arbitrary WRAM past `d437` | **No** | pret `engine/pikachu/pikachu_follow.asm:AppendPikachuFollowCommandToBuffer` (#1165) — no `pikachu_follow.asm` port exists; `dos_port/src/engine/overworld/pikachu.asm` / `pikachu_status.asm` are a different (position/animation) subset of the Pikachu-follower system | Pending port |
| Unexpected Counter damage (shared `wDamage`) | bugs_and_glitches.md#unexpected-counter-damage | cosmetic — no data corruption, just a damage-value quirk (already the rubric's own worked example) | Yes | `dos_port/src/engine/battle/counter.asm:.counterableType` (pret `engine/battle/core.asm#L4960`) | Yes (pre-existing, verified — full site + ref format already correct) |

---

## `docs/references/yellow_glitches.md` (in progress — filled per engine-area batch below)

### Battle System (29 entries, yellow_glitches.md lines 53-81)

| Name | Catalogue category | Severity + reasoning (this rubric) | Ported? | Routine | Tagged? |
|---|---|---|---|---|---|
| Badge Stat Boost Glitch | BUG(general) | critical — 999-cap stat corruption over a battle | Yes | `src/engine/battle/stat_mod_effects.asm:.applyBadgeBoostsAndStatusPenalties` | Yes |
| Critical Hit Ratio Error | BUG(general) | critical — changes damage-roll outcome | Yes | `src/engine/battle/core_damage.asm:CriticalHitTest` | Yes |
| 1/256 Miss Glitch | BUG(general) | critical — changes hit/miss outcome | Yes | `src/engine/battle/core_damage.asm:MoveHitTest` (`.doAccuracyCheck`) | Yes |
| 0 Damage Glitch | BUG(general) | critical — changes hit/miss outcome | Yes | `src/engine/battle/core_damage.asm:AdjustDamageForMoveType` | Yes |
| HP Recovery Failure (mod 255) | BUG(general) | cosmetic (rubric: no state corruption, move silently no-ops) | Yes | `src/engine/battle/move_effects/heal.asm:HealEffect_` | Yes (ref corrected from a stale bugs_and_glitches.md backref) |
| Bide vs Fly/Dig | BUG(general) | critical (ambiguous default) | **No** | pret `engine/battle/effects.asm` — only Bide's SETUP half is ported (`move_effects/bide.asm:BideEffect_`); the damage-accumulation/release-on-expiry half (where this bug lives) doesn't exist anywhere in `dos_port/src` | Pending port |
| Counter Glitch | BUG(general) | cosmetic (rubric's own worked example) | Yes | `src/engine/battle/counter.asm:.counterableType` | Yes (pre-existing + extended) |
| Substitute + Confusion Self-Hit | BUG(general) | cosmetic — redirect-to-own-substitute, no data corruption | Yes | `src/engine/battle/core.asm:HandleSelfConfusionDamage` | Yes |
| Toxic + Leech Seed Stacking | BUG(general) | cosmetic — damage-scaling quirk only | Yes | `src/engine/battle/residual_damage.asm` (pre-existing tag) | Yes (extended w/ cross-ref + Safety line) |
| Rest + Toxic Counter | BUG(general) | critical (rubric: stat/HP math corruption carries across statuses) | Yes | `src/engine/battle/move_effects/heal.asm:.restEffect` | Yes |
| Substitute HP Drain Bug | BUG(general) | cosmetic — attacker over-heals, no corruption | Yes | `src/engine/battle/move_effects/drain_hp.asm:DrainHPEffect_` | Yes |
| Exp. All Dilution | BUG(general) | cosmetic — EXP-share quirk, not corruption | Yes | `src/engine/battle/experience.asm:DivideExpDataByNumMonsGainingExp` | Yes |
| Level-Up Learnset Skipping | BUG(general) | cosmetic — a move-learn opportunity is lost, no corruption | Yes | `src/engine/battle/experience.asm:.printGrewLevelText` (GainExperience level-up block) | Yes |
| Mimic Level-Up Glitch | BUG(general) | cosmetic — in-battle move slot resets to "--" | Yes | `src/engine/pokemon/learn_move.asm:LearnMove` | Yes |
| Hyper Beam + Sleep | BUG(general) | cosmetic — bypasses hit-tests but pret's own comment flags it; no corruption | Yes | `src/engine/battle/move_effects/sleep.asm:SleepEffect_` | Yes (pre-existing, incl. a `BUG_FIX_LEVEL>=2` real fix block) |
| Paralysis + Fly/Dig Invulnerability | BUG(general) | critical — mon can be stuck unable-to-be-hit for the rest of the battle (outcome-changing) | Yes | `src/engine/battle/core.asm:.monHurtItselfOrFullyParalysed` (both sides) | Yes (pre-existing, incl. a `BUG_FIX_LEVEL>=2` fix block) |
| Trapping Sleep Glitch | BUG(general) | critical (ambiguous default) | **No** (mechanism un-exercisable) | `CheckNumAttacksLeft` (`src/engine/battle/core.asm`) — the Bide/Thrash/Wrap multi-turn counter-expiry routine this glitch depends on is a literal `ret`-only stub ("TODO(faithful): translate. No-op until the multi-turn move effects are wired") | Pending port |
| Defrost Auto-Move | BUG(general) | cosmetic — turn-order quirk, not corruption | Yes (faithful by construction) | `src/engine/battle/core.asm` `.frozenCheck`/`.eFrozenCheck` — once `CheckDefrost` (freeze_burn_paralyze.asm) clears FRZ, the next status check naturally falls through with no special-casing needed; no divergent port-side code path exists to preserve | Not tagged — nothing pret-specific to guard; the faithful translation already reproduces this by construction |
| Transform Glitches | BUG(general), ACE: Potential | critical (ambiguous default; catalogue notes ACE potential but this port's translation doesn't add a new escape) | Yes | `src/engine/battle/move_effects/transform.asm:TransformEffect_` | Yes (pre-existing, 2 `BUG(cosmetic)` blocks, both with real `BUG_FIX_LEVEL>=2` fixes) |
| Swift Miss Glitch | BUG(general) | N/A — **fixed in English Yellow, do NOT emulate** | Yes | `src/engine/battle/core_damage.asm:MoveHitTest` (`.swiftCheck`) | No tag needed — confirmed correct (unconditional hit) English behavior already present |
| Ghost Marowak (Poké Doll) | BUG(general) | critical (ambiguous default; skips a scripted encounter permanently) | **No** | pret's scripted Lavender Tower ghost-Marowak battle + Poké Doll early-exit — no scripted-battle system or `Marowak`/`PokeDoll` reference anywhere in `dos_port/src` | Pending port |
| Experience Underflow → Lv 100 | GLITCH | GLITCH — functional speedrun exploit, no ACE | Yes | `src/engine/pokemon/experience.asm:CalcExperience` | Yes |
| Division by Zero Freeze | BUG(critical) | critical | Partial — see note | `src/engine/math/multiply_divide.asm:_Divide` already has an unconditional `test ecx,ecx / jz .done` divide-by-zero guard (comment: "guard divide-by-zero (GB would loop forever)"), so this port's shared math primitive does **not** reproduce the freeze at `BUG_FIX_LEVEL 0` — a deliberate, pre-existing, unconditional (not `BUG_FIX_LEVEL`-gated) divergence in shared infrastructure, not a per-callsite tag | Not tagged this pass — flagged here as a fidelity note; a real `BUG(critical)`+`%if BUG_FIX_LEVEL` treatment would need to move the guard behind a level check, which is a behavior change on shared code outside this pass's comment-only scope. Recommend follow-up in a dedicated fix ticket. |
| Psywave Infinite Loop | BUG(critical), ACE: Potential | critical | Yes | `src/engine/battle/core.asm` `.psywaveLoop` (both player and enemy sides, `CalculateDamage`-adjacent) | Yes (newly tagged this pass — was previously only a `GLITCH(faithful)` 0-damage-asymmetry note, missing the actual infinite-loop hazard) |
| Super Glitch | BUG(critical), ACE: Potential | critical | Yes | `src/home/names.asm:GetName` (`.walk`) | Yes (pre-existing `GLITCH (name-overflow)` header tag, extended this pass with explicit cross-refs; downgraded ACE-potential noted as not applicable to this port's bounded-destination translation) |
| Move 0x00 (CoolTrainer♀ glitch) | BUG(critical), ACE: Potential | critical | Yes | same site as Super Glitch (`GetName`/`.walk`, index 0 case) | Yes (same extended tag) |
| Struggle PP Underflow | BUG(critical), ACE: Potential | critical | Yes | `src/engine/battle/decrement_pp.asm:DecrementPP` | Yes (newly tagged this pass) |
| Hyper Beam + Freeze | BUG(critical) | critical | Yes | `src/engine/battle/core.asm` `.frozenCheck` / `.eFrozenCheck` | Yes (newly tagged this pass) |
| Index #000 Post-Capture | BUG(critical), ACE: Potential | critical | **No** | pret's `ThrowBall`/capture-to-party path — no catch-during-battle system (`ThrowBall`/`CatchMon`) exists anywhere in `dos_port/src`; only post-battle party-add (`add_party_mon.asm`) and trade/evolution paths are ported | Pending port |
