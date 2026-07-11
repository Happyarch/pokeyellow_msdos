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

**translation.db / allowlist hygiene (plan doc Phase A step 5):** `update_label_db`
+ `lint_pret_labels` ran after every batch this task — 0 violations throughout.
Separately swept `dos_port/tools/pret_label_allowlist.json` (56 `relocated_files`,
261 `relocated_labels`, 7 `suppress` entries) for staleness: every `port_file`
reference resolves to a real file (no broken relocations), and the 7 `suppress`
entries' "known interim" claims were spot-checked against current `Makefile`
state (e.g. the `FormatMovesString` dup_def entry claims `misc.asm` is still
check-only — confirmed, still excluded from `LINK_SRCS`). No new doubts to
report; the file's own header already carries a standing
`"DRAFT (Session H 2026-07-07)... Flagged for user review"` note predating this
task, which this pass didn't need to add to.

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
| Glitch City | GLITCH | **No** | Requires Safari Zone (not ported — no Safari Zone map/step-counter system anywhere in `dos_port/src`) combined with a mid-session hard-reset timing window against the save write. The save system itself **is** ported and live (`SaveGameData`/`TryLoadSaveFile` family, `save.asm` — corrected from a batch-2 error, see Save/SRAM category below), but Safari Zone alone still blocks this entry. |
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

### Save / SRAM (6 entries, yellow_glitches.md lines 120-125)

**Correction (this pass):** the batch-2 pass of this table asserted "no save system
exists" for every entry below except Experience PC Withdrawing Softlock. That was
**wrong** — it searched for the plan doc's placeholder names (`SaveSAVtoSRAM`/
`LoadSAV`), which are not pret's actual labels and don't exist under those names
anywhere in pret either. The real pret labels are `SaveGameData`/`TryLoadSaveFile`
(+ `SaveMainData`/`SaveCurrentBoxData`/`SavePartyAndDexData`,
`LoadMainData`/`LoadCurrentBoxData`/`LoadPartyAndDexData`, `EnableSRAM`/
`DisableSRAM`/`CalcCheckSum`, `ChangeBox`, `SaveHallOfFameTeams`/
`LoadHallOfFameTeams`/`HallOfFame_Copy`, `CheckPreviousSaveFile`,
`ClearAllSRAMBanks`, …), all faithfully translated and **already live** in
`dos_port/src/engine/menus/save.asm` (header credits it to "menus-port Session 7,
package H" — predates this bug-tagging task) and **wired into the real START→SAVE
menu and boot-time load** via `main_menu.asm` (`extern TryLoadSaveFile` / `call
TryLoadSaveFile`, plus `SaveMenu`). It even has its own smoke-test harness
(`RunSaveTest`, gated `%ifdef DEBUG_SAVE` / `DEBUG_SAVE_ROUNDTRIP`). The rows below
are re-derived against the actual code. See also this file's plan doc's "Save
draft status" section for what this means for Phase B.

**Port SRAM model (all 5 rows below hinge on this):** pret's `s*` SRAM labels have
no port address at all — every SRAM `CopyData` slice pret does per stage
(`SaveMainData`/`SaveCurrentBoxData`/`SavePartyAndDexData`) collapses to one call
to `src/save/dsv_io.asm:DsvWriteSave`, which **atomically rewrites the entire
`POKEMON.DSV` payload from current WRAM** (single `INT 21h AH=3Ch` create +
single `AH=40h` write of the whole blob) on **every one of the 3 stage calls** —
not just that stage's slice. `EnableSRAM`/`DisableSRAM` are flag-preserving
no-ops (`; TODO-HW: SRAM`); `CalcCheckSum` is translated faithfully but unused by
the collapsed path (kept for label parity / a future faithful-SRAM layout).

| Name | Category | Severity + reasoning | Ported? | Routine | Tagged? |
|---|---|---|---|---|---|
| SRAM Glitch / Partial Save | GLITCH (YES ACE) | GLITCH | **Yes** (save path), but the **exploit precondition does not transfer** | `src/engine/menus/save.asm:SaveGameData`/`SaveMainData`/`SaveCurrentBoxData`/`SavePartyAndDexData` → `src/save/dsv_io.asm:DsvWriteSave` | **No tag** — pret's glitch needs a mid-multi-bank-write hard-reset that leaves *some* SRAM banks updated (new per-stage checksum) and others stale, so a corrupted/partial-merge state still reads back as checksum-valid. The port's design forecloses this structurally: each of the 3 stage calls is an **independent atomic full-payload rewrite** (old WRAM state or new WRAM state, never a stage-partial mix), and a write interrupted between the `AH=3Ch` create and the `AH=40h` write leaves a truncated file that `DsvReadSave`'s `"DOSV"`-magic check rejects outright (routes to `CheckSumFailed`/"file data destroyed", pret's own designed failure path) rather than silently validating. Re-introducing the race (3 truly independent partial SRAM writes) would be a **regression**, not increased fidelity — noted here rather than tagged, since there's no reachable in-port site to *guard*. |
| Pokémon Storage Cloning | GLITCH | GLITCH | **Yes** (both halves), precondition does not transfer | `src/engine/pokemon/bills_pc.asm:BillsPCDepositLogic`/`BillsPCWithdrawLogic` + `save.asm:SaveGameData` | **No tag** — same structural argument as above: the port has no reset-mid-synchronous-call mechanism analogous to a GB hard reset firing mid-instruction while an SRAM bank write is in flight (DOSBox-X's DPMI calls run to completion or the process is killed outright; there's only one save "bank" to race, and it's atomically rewritten per point above). |
| Save Data Carryover | GLITCH | GLITCH | Partial (`clear_save.asm`-equivalent new-game flow referenced from `src/movie/title.asm`, not deeply audited this pass) | `src/movie/title.asm` (references the clear-save concept) | **No tag** — same 2-frame hard-reset-at-new-game-start mechanism as above; no DOS-process analog to a GB reset mid-WRAM-init. Not deeply re-investigated this pass since the conclusion (mechanism doesn't transfer) is the same as the two rows above; flag for a closer look only if the title/new-game flow is revisited for its own sake. |
| Hall of Fame Sprite Buffer Overflow | BUG(critical) | critical | **Partial** — pret-labeled routines exist but are no-ops over the specific memory this bug needs | `save.asm:SaveHallOfFameTeams`/`LoadHallOfFameTeams`/`HallOfFame_Copy` (all `; TODO-HW: SRAM` no-ops — "no port HoF SRAM region yet") | Pending port — the bug needs pret's exact SRAM bank-0 adjacency (`sSpriteBuffer0`/`1`/`2` + `$100` pad immediately followed by `sHallOfFame`, `ram/sram.asm`) *and* a glitch-Pokémon OOB sprite-decompression path that overflows the fixed 3-buffer region into it — neither the adjacency nor the OOB decompression path exist in the port (`sHallOfFame` has no port address at all). |
| Save Corruption (power-off timing) | BUG(critical), ACE: Indirect | critical | **Yes** (save path), precondition does not transfer | Same as SRAM Glitch / Partial Save row above | **No tag** — identical mechanism/timing window to SRAM Glitch / Partial Save (this is the "if not exploited cleanly" failure-mode framing of the same underlying race), same structural non-reproducibility. |
| Experience PC Withdrawing Softlock | BUG(critical) | critical | **Yes** | `src/engine/pokemon/add_mon.asm:_MoveMon` (BOX_TO_PARTY/DAYCARE_TO_PARTY path, the `call CalcLevelFromExperience` site) | Yes (newly tagged this pass) — found the actual reachable call site (`BillsPCWithdrawLogic` → `_MoveMon` → `CalcLevelFromExperience` → the already-tagged `CalcExperience` underflow); corrected the batch-2 `CalcExperience` cross-reference, which had guessed this call site wasn't ported yet. |

### Text / Menu, Audio, Sprite / Graphics (10 entries, yellow_glitches.md lines 131-150)

| Name | Category | Severity + reasoning | Ported? | Routine | Tagged? |
|---|---|---|---|---|---|
| Town Map Navigation Oversight | BUG(general) | cosmetic — extra button press, no state effect | Yes (faithful by construction) | `src/engine/items/town_map.asm:.pressedUp`/`.pressedDown` — a straightforward modulo cursor over `TownMapOrder`; the "Route 1 needs a double-press" quirk is a property of that Tier-1 data table's entry ordering (byte-identical to pret), not a distinct navigation-code bug | Not tagged — nothing pret-specific in the port's own code to guard; the faithful data table already reproduces it |
| Trade Evolution Glitch Move | BUG(general) | cosmetic — Gen-I/II move-id mismatch, cosmetic only | **No** | Requires Gen I ↔ Gen II trading (Time Capsule); no `trade`-named file anywhere in `dos_port/src` | Pending port |
| Full Box Glitch | — (fixed in Yellow) | N/A — **fixed in Yellow, do NOT emulate** | **No** | Requires the old-man catching demo + a full PC box; no such scripted sequence ported | Pending port (no tag needed even once ported — do not emulate) |
| Nidorino Cry Mismatch | BUG(general) | cosmetic — wrong cry SFX only | **No** | Requires the title-screen/intro rival-Nidorino demo battle; `src/movie/title.asm` is explicitly a "bespoke early implementation that does NOT render fully correctly" (CLAUDE.md) with no demo battle sequence | Pending port |
| Battle Draw Victory Fanfare | BUG(general) | cosmetic — wrong music cue only | **No** | Requires mutual-faint ("draw") detection/resolution on a Self-Destruct/Explosion KO; no such handling found in `faint_enemy.asm`/`faint_leaves.asm`/`move_effects/explode.asm` | Pending port |
| Silent Indigo Plateau | BUG(general) | cosmetic — music stops, no state effect | **No** | Requires the scripted Elite Four rival battle + an evolution-during-battle timing interaction with the music driver; no scripted rival-battle sequence ported | Pending port |
| Red's Transparent White Pixels | BUG(general) | cosmetic — palette/transparency quirk | **No** | Title-screen Red sprite; `src/movie/title.asm` doesn't render fully correctly yet (known low-priority defect per CLAUDE.md) — not independently verifiable until the title-screen rewrite lands | Pending port (tracked under the existing title-screen defect, not a new item) |
| NPC Over Grass (Viridian Forest) | BUG(general) | cosmetic — visual layering only | Yes (faithful by construction) | Viridian Forest is a ported map (`map_sprites.asm:InitMapSprites` places NPCs from the embedded, Tier-1 map-object binary); the Lass's on-grass position is a property of that byte-identical data, not port-side placement logic | Not tagged — nothing pret-specific in the port's own code to guard; not independently re-verified in-game this pass |
| Chansey Facing South (Pokémon Zoo) | BUG(general) | cosmetic — visual only | **No** | No Pokémon Zoo (Cerulean Cave-adjacent) map data found in `assets/`/`include/` yet | Pending port |
| Trade Menu Palette Glitch | — (fixed in Yellow) | N/A — **fixed in Yellow, do NOT emulate** | **No** | Requires the trade UI; no trade system ported | Pending port (no tag needed even once ported — do not emulate) |
