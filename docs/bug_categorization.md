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
