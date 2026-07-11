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

### Overworld / Map (5 entries, yellow_glitches.md lines 87-91)

All 5 are **pending port** — every one depends on a subsystem not yet present:

| Name | Category | Ported? | Reasoning |
|---|---|---|---|
| Mew Glitch | GLITCH | **No** | Requires the Fly-out-of-battle field effect (no `FLY_EFFECT` field-move execution exists — `src/engine/menus/field_moves.asm` has no Fly handling, only `town_map.asm`'s menu display) combined with trainer-sight-pending-battle carryover across a map load. |
| Trainer Escape / Trainer-Fly | GLITCH | **No** | Same missing Fly-out-of-battle mechanism; `trainer_engine.asm` (ported: `TrainerEngage`/`CheckForEngagingTrainers`/`EngageMapTrainer`) has no pending-battle-flag-survives-a-warp path to trigger this from. |
| Glitch City | GLITCH | **No** | Requires Safari Zone + the save system's mid-session hard-reset timing window; no save system exists yet (`SaveSAVtoSRAM`/`LoadSAV` unported — see Save/SRAM category below). |
| OobLG (Out-of-bounds map loading) | GLITCH (YES ACE) | **No** | This port's map loader is fundamentally different from pret's mechanism — maps are loaded from a fixed, embedded per-map blob table, not a generic ROM-bank `MapHeaderPointers` walk indexed by an unclamped map ID, so there is no equivalent "overflow the map index" code path to preserve or guard yet. Revisit once/if a generic indexed map-table loader lands. |
| Fossil / Ghost MissingNo. (Yellow) | GLITCH | **No** | Requires the Cinnabar fossil-choice script + MissingNo. species/sprite handling; no `Fossil`/`MissingNo` reference anywhere in `dos_port/src`. |

### Follower / Pikachu Sprite (7 entries, yellow_glitches.md lines 96-103)

All 7 are **pending port**. `src/engine/overworld/pikachu.asm` + `src/engine/pikachu/pikachu_status.asm` exist but (per the batch-1 finding on `bugs_and_glitches.md`'s `AppendPikachuFollowCommandToBuffer` entry) only cover the position/animation-display subset of the follower system — the step-command buffer, happiness bookkeeping, and dance/freeze state machine these glitches depend on are not ported:

| Name | Category | Ported? | Reasoning |
|---|---|---|---|
| Pikachu Off-Screen ACE | GLITCH (YES ACE) | **No** | Depends on `AppendPikachuFollowCommandToBuffer` (pikachu_follow.asm) — confirmed not ported (see `docs/bug_categorization.md`'s bugs_and_glitches.md table, row 3). |
| Pikachu Off-Screen Corruption (non-ACE) | BUG(general) | **No** | Same missing buffer mechanism. |
| Pikachu Item Happiness Glitch | BUG(general) | **No** | No happiness-update routine exists (`grep -ri happiness` across `src/` finds only unrelated EXP-happiness-bonus code in battle files and a memory-map comment in `pikachu.asm`; no item-use happiness check). |
| Walking Pikachu Happiness Edge Cases | BUG(general) | **No** | Same — no step/walking happiness-increment logic ported. |
| Pikachu vs. Poké Ball (link battle) | BUG(general) | **No** | Requires link-battle support (`; TODO-HW: network HAL`, Phase 4 — not started per CLAUDE.md). |
| Pikachu Freeze (cliff + dance) | BUG(general) | **No** | Requires ledge-jump interrupt handling cross-wired with Pikachu's dance-animation state machine; no dance-state code found. |
| Pikachu Stutter (Pokémon Tower) | BUG(general) | **No** | Requires the Pokémon Tower purified-zone flag + fainted-Pikachu follower-animation interaction; neither exists yet. |

### Item / Inventory (6 entries, yellow_glitches.md lines 109-114)

| Name | Category | Severity + reasoning | Ported? | Routine | Tagged? |
|---|---|---|---|---|---|
| Item Underflow / Dry Underflow | GLITCH (YES ACE) | GLITCH | Yes (translated, **not linked** — see Tagged? note) | `src/engine/menus/swap_items.asm:HandleItemListSwapping` (`.swapSameItemType`) | Yes (newly tagged this pass) — found the exact root cause: an unclamped 8-bit `add al,bl` before the `cmp al,100` overflow check, identical to pret's own 8-bit arithmetic. File header states `DisplayListMenuIDLoop`/`HandleItemListSwapping` have "No live caller" yet (check-only), so this path is translated but dormant, not reachable, in the current build. |
| ws# #m# (Yellow ACE glitch item) | GLITCH (YES ACE) | GLITCH | **No** | Requires (a) the item-underflow chain to be reachable (currently dormant — see above) and (b) a generic item-use effect dispatch for out-of-range item ids; no `ItemUsePtrTable`/`UseItem_` dispatch exists (`docs/current_plan_items.md` confirms: "item USE dispatch...deferred") | Pending port |
| Expanded Item Pack | GLITCH (YES ACE) | GLITCH | **No** (dormant, same mechanism) | Shares `swap_items.asm`'s dormant list-menu driver; `SanitizeInventory` (`inventory.asm`, `BUG_FIX_LEVEL>=1`) already clamps bag/PC count to hardcoded capacity when that code path IS exercised via `AddItemToInventory_`/`RemoveItemFromInventory_`, but this is a separate mechanism (over-capacity list access via the swap UI, not the add/remove path) | Not independently tagged — tracks the Item Underflow entry above; revisit once `HandleItemListSwapping` is linked |
| Text Pointer Manipulation / Mart Pwner / LWA | GLITCH (YES ACE) | GLITCH | **No** | Requires the shop/mart buy screen (unterminated glitch-item name overflowing a text buffer); no `mart`/`buy`-named file exists anywhere in `dos_port/src` | Pending port |
| LOL Glitch | GLITCH (YES ACE) | GLITCH | **No** | Same — no mart/buy screen | Pending port |
| Item slot $FF | BUG(critical), ACE: Indirect | critical | **No** | Catalogue describes reading a pointer from position 255 of an item-effect pointer table past `wItems`; no `ItemUsePtrTable`-equivalent generic item-use dispatch exists yet (individual effect helpers in `item_effects.asm` are called directly, not through an index-256 pointer table) | Pending port |
