# current_plan_battle_pret_alignment.md — align the battle engine with pret's tree + Tier-1 data

Status: **proposed** (2026-06-30). Triggered by review feedback that the Wave-2
battle front end diverged from pret's project tree, reinvented functions pret
already isolates, and hardcoded string/gfx data that should be machine-generated
(Tier 1, see CLAUDE.md "Data vs. code: the two-tier rule").

---

## DIVERGENCE AUDIT (2026-06-30) — battle front end vs pret

**Governing principle (user, 2026-06-30):** the battle BACKEND must be byte-faithful
to pret; the FRONT END should diverge from pret ONLY at the actual screen-draw
primitive (the tile write into our centered 40-wide `W_TILEMAP` / software PPU).
Everything above the draw — menu/turn/message *orchestration* — should be a faithful
translation of `core.asm`, calling pret-named functions and **generated** text data.

**Reality:** the Wave-2 front end (`battle_menu.asm`) was written as a *bespoke
reimplementation*, so it diverges pervasively above the draw layer. Classified:

### A. Hardcoded text data — must be GENERATED (Tier 1) [~21 labels]
`BattleMenuText` + `str_used/excl/type/enemy/fainted/gotaway/cantesc/norun1-3/
gained/exppts/grew/tolevel/learned/nopp1/nopp2/hasno/movesleft/attack/defense/
speed/special` (battle_menu.asm:47-82). pret keeps these in `data/text/text_2.asm`
(+ `BattleMenuText` in core.asm). → `tools/gen_battle_text.py` → `assets/battle_text.inc`,
streams with `prompt`/`done`/`text_end` terminators intact (drives the ▼ data-driven).

### B. Reinvented backend / helpers — use the pret-named ones (backend = identical) [5]
1. `DecrementPlayerPP` (1005) → existing faithful `decrement_pp.asm:DecrementPP`
   (battle+party struct). Ours is a weaker battle-only duplicate.
2. `CheckAllMovesNoPP` (994) → pret `AnyMoveToSelect` (core.asm).
3. `FindMoveName` (1301) + `DrawMoveList`'s bespoke move loop → pret `FormatMovesString`
   (we ALREADY have it in `misc.asm`, GetName-based) + PlaceString `wMovesString`,
   exactly as `MoveSelectionMenu.loadmoves/.writemoves`. **This is why blank slots
   miss the `'-'` placeholder — we don't call the function that produces it.**
4. `print_num3` (933) / `print_dec` (965) / `print_2d` (1364) → `PrintNumber`
   (now in `home/print_num.asm`). Retire the duplicates.

### C. Bespoke orchestration — translate from core.asm, diverge only at draw [~13]
`DisplayBattleMenu` (→core.asm:DisplayBattleMenu), `MoveSelectionMenu`
(→MoveSelectionMenu+SelectMenuItem), `ExecutePlayerTurn`/`PlayerAttackStep`/
`EnemyAttackStep` (→MainInBattle/ExecutePlayerMove/ExecuteEnemyMove),
`RenderPlayerTurn`/`RenderEnemyTurn` (→the move-execution sequence: DisplayUsedMoveText
→ animation → ApplyDamage → HUD), `WaitForAPress` (→PromptText/ManualTextScroll,
data-driven ▼), `RunWasSelected` (→BattleMenu_RunWasSelected), and the message
helpers `ShowEnemyFainted/ShowPlayerFainted/ShowGainedExpText/ShowGrewLevelText/
ShowLearnedMoveText/ShowNoPP/ShowNoMovesLeft/PrintRunLine/PrintStatsBox/BattleWonGiveExp`
(→ pret prints these via `PrintText` + the generated text data; EXP/level via
`GainExperience`'s own text calls).

### D. Draw primitives — divergence ACCEPTABLE, but mirror pret structure/names [~8]
`DrawBattleMenu`, `DrawMoveList`(box), `PrintMoveInfoBox`, `SaveBattleScreen`/
`RestoreBattleScreen` (→Save/LoadScreenTilesToBuffer1), `EndBattleScreen`,
`DrawBattleHUDs` (→DrawHUDsAndHPBars), HP bar, box borders. These legitimately
write to the projected 40-wide canvas — that's the *one* allowed divergence point.

**Faithful already (keep):** the unified text engine (`text.asm`, `print_num/bcd`,
`window.asm`), and the backend math — `core_damage`, `experience`, `select_enemy_move`,
`load_enemy_moves`, `get_current_move`, `decrement_pp`, `misc:FormatMovesString`,
`TryRunningFromBattle` (faithful, though mis-placed in battle_menu — belongs in core.asm).

**Bottom line:** divergence is *pervasive* (A+B+C ≈ 40 points), not isolated to the
draw layer. Realignment = re-derive the orchestration as a faithful `core.asm`
translation (this is Stage 3 done *right*), generate the text (Stage 2), and retire
the reinvented helpers (Stage 1) — leaving only category D as the divergence point.


This is a cleanup/refactor pass over already-working battle code. Sequenced
lowest-risk first; each stage is independently committable and leaves the
`DEBUG_BATTLE_LIVE` build working.

---

## The three problems

1. **Reinvented functions** — code that pret keeps in a dedicated file/label was
   rewritten inline under a new name. Smoking gun: `DecrementPlayerPP` in
   `battle_menu.asm` duplicates (more weakly — battle struct only) the faithful
   `decrement_pp.asm:DecrementPP` we already have. Similarly `CheckAllMovesNoPP`
   is pret's `AnyMoveToSelect`.
2. **Hardcoded strings** — `str_nopp1`, `intro_line1`, `str_grew`, … are inline
   `db` charmap bytes in `.asm`. pret stores battle text as data in
   `data/text/text_2.asm` (`_MoveNoPPText`, `_NoMovesLeftText`,
   `_WildMonAppearedText`, …), referenced via `text_far`. → must be **generated**
   into `assets/*.inc` (Tier 1), not authored in code.
3. **Hardcoded gfx** — e.g. `pokeballs.asm` `incbin "../gfx/battle/balls.2bpp"`.
   Gfx must be produced by a generator (the `.2bpp` + a `gen_*` step), like the
   font/HUD/title assets.

---

## Verified pret homes (file layout)

All confirmed via `grep '^<label>:' engine/battle/*.asm`:

| Our file | Routine(s) | pret home |
|---|---|---|
| battle_menu.asm | DisplayBattleMenu, MoveSelectionMenu, turn loop | **core.asm** |
| battle_hud.asm | DrawHUDsAndHPBars, DrawPlayerHUDAndHPBar | **core.asm** + draw_hud_pokeball_gfx.asm |
| core_damage.asm | GetDamageVars*, CalculateDamage | **core.asm** |
| get_current_move.asm | GetCurrentMove | **core.asm** |
| select_enemy_move.asm | SelectEnemyMove | **core.asm** |
| load_enemy_moves.asm | LoadEnemyMonData (wild path) | **core.asm** |
| residual_damage.asm | HandlePoisonBurnLeechSeed | **core.asm** |
| status_penalties.asm | ApplyBurnAndParalysisPenalties | **core.asm** |
| building_rage.asm | HandleBuildingRage | **core.asm** |
| badge_boosts.asm | ApplyBadgeStatBoosts | **core.asm** |
| stat_mod_effects.asm | StatModifierUp/DownEffect | **effects.asm** |
| pokeballs.asm | (port OAM reimpl; names differ) | draw_hud_pokeball_gfx.asm |

Already matching pret (no change): decrement_pp, experience, effects,
init_battle, init_battle_variables, misc, trainer_ai, read_trainer_party,
wild_encounters, get_trainer_name, move_effects/*.

Port-only, no pret equivalent (keep, document): battle_stubs, battle_exp_stubs
(link stubs), move_category (Gen-1 derives category from type inline in pret).

---

## DECISION (2026-06-30) — complete the text engine FIRST, game-wide

Direction: port/finish the text engine game-wide before the battle-text work, so
the runtime parses dynamic fields (player name, nick, numbers) like pret. The
generator emits the data **with control codes intact**; the engine resolves them
at runtime. (No "pre-split into segments" hack.)

**Crucial finding: most of the engine already exists** (`src/text/text.asm`,
used by overworld NPC dialog). Present and working:
- `PlaceNextChar` control-code dispatch incl. the dynamic name tokens:
  `<PLAYER>`$52→wPlayerName, `<RIVAL>`$53→wRivalName, `<PKMN>`$4A, POKé$54,
  `<TM>`$5C, `<PC>`$5B, `<TRAINER>`$5D, `<ROCKET>`$5E, `<......>`$56, `<DEXEND>`$5F,
  `<NEXT>`/`<LINE>`/`<PARA>`/`<CONT>`/`<PROMPT>`/`<DONE>` (some scroll/prompt are stubs).
- `TextCommandProcessor` layout cmds: TX_START, TX_MOVE, TX_BOX, TX_LOW, TX_SCROLL,
  button waits.

**The gap = operand-bearing dynamic commands + battle name tokens, all currently
stubbed/skipped in `TextCommandProcessor`/`PlaceNextChar`:**

| Cmd | Byte | pret | port now | needed for |
|---|---|---|---|---|
| TX_RAM (`text_ram`) | $01 | read 2-byte addr → PlaceString | `.cmd_skip2` (skips) | nicknames / RAM strings |
| TX_NUM (`text_decimal`) | $09 | PrintNumber | `.cmd_skip3` (skips) | EXP/level/counts |
| TX_BCD (`text_bcd`) | $02 | PrintBCDNumber | `.cmd_skip3` (skips) | money |
| `<TARGET>`/`<USER>` | $59/$5A | active mon name (+"Enemy ") | stub | battle "X used Y!" |

No shared `PrintNumber`/`PrintBCDNumber` exists yet — only ad-hoc `print_dec`/
`print_num3` in battle_menu/battle_hud/party_menu. Promote one into the engine as
the routine TX_NUM calls (port home/text.asm:PrintNumber; PrintBCDNumber from
home/).

---

## Staged plan (low-risk first)

- [x] **Stage 0 — complete the text engine (game-wide foundation).** DONE
  (2026-06-30, assembles + links). `TX_RAM`/`TX_NUM`/`TX_BCD` implemented in
  `src/text/text.asm:TextCommandProcessor` (were skip-stubs); `<TARGET>`/`<USER>`
  ($59/$5A) added to `PlaceNextChar` (player→wBattleMonNick, enemy→"Enemy "+
  wEnemyMonNick, per hWhoseTurn^target). New pret-mirrored files
  `src/home/print_num.asm` (PrintNumber) + `src/home/print_bcd.asm` (PrintBCDNumber,
  PrintBCDDigit). Text flag bits added to gb_constants.inc. **Still TODO in this
  stage:** retire the ad-hoc `print_dec`/`print_num3` copies in
  battle_menu/battle_hud/party_menu in favor of PrintNumber (do alongside Stage 2,
  when those call sites move to generated streams). Needs a live exercise —
  nothing emits TX_RAM/TX_NUM yet (overworld dialog uses line/para/done only), so
  proof comes when Stage 2 routes a battle message through it.
- [x] **Stage 0.5 — UNIFY the text engine (delete `wide_text.asm`).** DONE
  (2026-06-30, builds clean). `text.asm` parameterized on runtime `text_row_stride`
  (default 20; `TextBoxBorder` + `<NEXT>` use it). `PlaceString` now takes its src
  ptr in EAX (port calling convention; logic identical to pret) — updated all
  callers (TextCommandProcessor cmd_start/cmd_ram, battle_hud, party_menu,
  start_menu). Battle menu-input relocated to new pret-mirrored `src/home/window.asm`
  (`HandleMenuInput`/`PlaceMenuCursor`, stride-aware via `text_row_stride`, item
  spacing `menu_item_step`, callback `menu_redraw_cb`). `battle_menu.asm` migrated:
  `WidePlaceString`→`PlaceString`+`mov esi,ebx`, `WideTextBoxBorder`→`TextBoxBorder`,
  `WideHandleMenuInput`→`HandleMenuInput`. `InitBattle` sets `text_row_stride=40`;
  `EndBattleScreen` resets it to 20. **`wide_text.asm` deleted.** `type_names.asm`
  (data table `WideTypeNames`) and `init_battle.asm` had no Wide *calls* (only a
  data label / comment), left as-is. NEEDS live regression check (battle UI
  unchanged) — see below.
- [ ] **Stage 1 — function dedup (no behavior change).** Replace
  `battle_menu.asm:DecrementPlayerPP` with `decrement_pp.asm:DecrementPP` (extern);
  rename `CheckAllMovesNoPP` → `AnyMoveToSelect` (and put it where pret has it once
  Stage 3 lands). Verify PP still decrements battle **and** party struct.
- [ ] **Stage 2 — battle-text generator (Tier 1).** New `tools/gen_battle_text.py`
  modeled on `gen_npc_dialogs._parse_text_file` + `gen_menu_strings` emit shape:
  read the battle `_*Text` labels from `data/text/text_2.asm`, emit
  `assets/battle_text.inc` (`label: db …, 0x50`). Add to `gen_all_assets.py` +
  Makefile `assets`. Replace inline `str_*`/`intro_*` in battle `.asm` with
  `extern`s. Per the fork, emit static segments (Option B).
- [ ] **Stage 3 — file layout to mirror pret.** Fold stat_mod_effects → effects.asm;
  consolidate the core.asm-derived files into `src/engine/battle/core.asm`
  (or, if kept physically split for sanity, rename with pret-matching names +
  header noting the core.asm slice). Update Makefile FRONTEND/BATTLE srcs +
  all global/extern linkage. **Riskiest — do last, isolated commit.**

  (Stage 2 now emits streams **with control codes intact** — TX_RAM/TX_NUM, nick
  tokens — rendered by the Stage-0 engine; no segment-splitting.)
- [ ] **Stage 4 — gfx generator.** Route `balls.2bpp` (and any other hand-placed
  battle gfx) through a `gen_*` step like the font/HUD assets.

---

## ░░ HANDOFF — resume here ░░

Nothing executed yet — plan proposed, awaiting go-ahead on sequencing + the
text-field fork (A vs B). The PP-box restore bug (snapshot kept stale dialog text;
fixed by adding pret's `PrintEmptyString` equivalent before `SaveBattleScreen` in
`DisplayBattleMenu`) is already fixed and is separate from this cleanup. TEMP
PP-test seed (PP 2/1/1/1, enemy HP 200) still in `debug_dump.asm` — revert after
PP sign-off.

---

## Stage 4 audit findings (Sonnet Explore, read-only)

### Draw geometry (battle_hud / battle_menu / init_battle) — agent a32d10
Projection `port_offset = (gb_row+3)*40 + (gb_col+10)` verified against pret hlcoord.
Nearly all positions MATCH. Issues to fix:
1. **E_LV bug** (`battle_hud.asm:56`): `%define E_LV (4*FW+15)` → should be `(4*FW+14)`.
   pret places enemy ":L" at `hlcoord 4,1` → col 4+10=14, not 15. Slip propagated from
   the PROJ comment (line 64) which miscomputes "4+10=15". Player P_LV (=…+24) is right.
   Knock-on: enemy level digits are one col too far right; ":L" sits on the status cell.
2. **Player HUD missing upper connector**: pret `DrawPlayerHUDAndHPBar` (core.asm
   1897-98) writes a 2nd `$73` at `hlcoord 18,9` = canvas (28,12), above the
   PlacePlayerHUDTiles `$73` at (28,13). Port's `DrawPlayerHUDFrame` only draws the
   lower one — add the upper `$73` at offset (12*40+28)=508.
3. **INFOBOX (TYPE/PP) shifted -1 col** (IB_COL=9 vs canonical 10): INTENTIONAL/
   documented (avoids clipping P_NAME at col 20). All 6 internal offsets inherit the
   -1 uniformly. Leave as-is (re-confirm rationale when porting PrintMenuItem faithfully).
Everything else (E_NAME, E_HPBAR, HUD frames, P_NAME..P_HPFRAC, all menu boxes/text/
cursors, dialog rows, ▼ arrow at (18,16)→788, level-up stats box) = MATCH.

### Damage backend (core_damage / get_current_move) — agent abcb03
ALL damage-pipeline routines FAITHFUL: GetDamageVarsForPlayer/EnemyAttack,
GetEnemyMonStat, CalculateDamage, JumpToOHKOMoveEffect, CriticalHitTest (Focus
Energy bug preserved), AdjustDamageForMoveType (STAB/dual-type/type aliases ok;
AIGetTypeEffectiveness $10 bug preserved), MoveHitTest (substitute-drain dead-code
preserved), CalcHitChance, RandomizeDamage. No constant/mask/HRAM/branch/off-by-one
errors. Two documented divergences:
- BattleRandom: link path uses local PRNG instead of the shared seed list →
  link-battle desync only. TODO-HW Phase 4. Leave.
- **GetCurrentMove: omits the GetName/CopyToStringBuffer tail** → move-name string
  buffer stays stale. FIX for faithful flow (DisplayUsedMoveText needs it): append
  the GetName + name-buffer copy like pret core.asm:GetCurrentMove. (Stage 4 fix.)

### AI/EXP/status backend — agent a29a7f
FAITHFUL: decrement_pp, residual_damage (both glitches preserved), stat_mod_effects, misc.
FIX (real bugs):
- **trainer_ai.asm AIRecoverHP**: `add edx, eax` (32-bit) never sets CF for the byte
  HP add → HP-high not incremented on low-byte overflow → under-heal (e.g. HyperPotion
  on a high-HP enemy). Fix to carry into HP-high like pret (8-bit add + adc).
- **experience.asm .done**: CL (=wPlayerMonNumber) not preserved around the 1st
  FlagAction call; if FlagAction clobbers ECX the 2nd (fought-enemy) flag hits the wrong
  slot. Push/pop ECX around it.
- **select_enemy_move.asm**: TrainerAI never called (all battles random); the random
  loop hardcodes wEnemyMonMoves. Faithful fix = MainInBattleLoop calls `callfar TrainerAI`
  (handled in core.asm); verify SelectEnemyMove reads the right move buffer. (Wire in core.asm.)

---

## 2026-06-30 — Stage 5 DONE: core.asm linked & driving the battle

The faithful `core.asm` battle loop is LINKED (`make SKIP_TITLE=1 DEBUG_BATTLE_LIVE=1`
builds; static `DEBUG_BATTLE=1` FRAME confirms HUD/menu/sprites/▼). battle_menu.asm gutted
to draw helpers + EXP display + run-odds; pret-named draw entry points added; JumpMoveEffect/
HandlePoisonBurnLeechSeed/TrainerAI/FormatMovesString live as faithful stubs in the new
core_stubs.asm (deep effect/residual/AI closures aren't link-ready). animations.asm now
always renders pret's ANIMATION=OFF behaviour. See translation_log.md 2026-06-30 for the
full file-by-file change list and the marked TODO(faithful) deferral set.

**NEEDS LIVE TEST** (interactive, `dos_port/run` after a DEBUG_BATTLE_LIVE build): FIGHT →
move menu (TYPE/PP box, '-' empty slots, 0-PP→Struggle), an attack round (player+enemy,
speed order, ~0.5s anim-off delay, HP drop, faint), victory EXP/level-up, RUN. Watch for:
DecrementPP calling convention (EDX=move-id ptr), DisplayUsedMoveText <USER> token,
the ▼ appearing only on prompt messages.

---

## 2026-06-30 (cont.) — live-test fixes + battle data generators

After Stage 5 went live, three live-test bugs were fixed faithfully:
- FIGHT move names blank (`FormatMovesString` clobbered its dest cursor across `FindMoveName`).
- "X used MOVE!" overran the box — added the faithful `<LINE>` (matches `_UsedMove1Text`).
- "grew to level 1" — the deferred `LoadMonData` stub left `wLoadedMon` stale for
  `CalcLevelFromExperience`; wired the real `LoadMonData_` (faithful, not a hand-copy).

Then the **data half** was generated (Tier-1, one Sonnet agent each, reviewed vs pret):
- `gen_battle_text.py` extended (scan `move_effects/*.asm`, emit `global`, handle
  `text_pause`): 103→123 labels. The 10 `move_effects/*.asm` that hand-authored their
  text streams were **de-duplicated** — they now `extern` the generated label (resolves
  the Tier-1/Tier-2 violation; the JumpMoveEffect handler closure's text is ready).
- NEW: `gen_trainer_parties.py` (rosters + special moves), `gen_trainer_names.py`
  (`TrainerNames`), `gen_move_grammar.py` (`MoveGrammar`), `gen_type_names.py`
  (`WideTypeNames`, replacing the last hand-authored battle data table).
- Type-id handling verified end-to-end (Gen-1 0x09-0x13 gap; SPECIAL=FIRE=0x14).

**So every deferred core.asm TODO(faithful) now has its Tier-1 data in place.** Remaining
faithful work is wiring the consumers (code, Tier-2): ~~JumpMoveEffect→effects closure~~
(**DONE 2026-06-30** — the move-effect translation swarm; see `docs/plans/move_swarm.md`),
status conditions, residual damage, trainer AI/multi-mon/prize.

**UPDATE 2026-06-30 — JumpMoveEffect→effects closure is COMPLETE.** All 34 non-NULL
move effects are faithfully translated, audited, and live in `MoveEffectPointerTable`
(`src/engine/battle/move_effects/*.asm`, linked via FRONTEND_SRCS); the 7 NULL-in-pret
slots correctly stay `UnportedMoveEffect`. Gen-1 bugs preserved under `BUG_FIX_LEVEL>=2`;
allowlist divergences (literal subanim / audio / bank drops) logged per body in
`translation_log.md`. The `StartedSleepingEffect` generator gap noted below is RESOLVED —
`gen_battle_text.py`'s wrapper regex was widened (it now also emits `StartedSleepingEffect`),
and the regen restored a stale-missing `PickUpPayDayMoneyText`. The shared scaffold gained
`ClearHyperBeam`/`PrintDoesntAffectText` + anim no-op stubs. Still deferred (faithful
ANIMATION=OFF no-ops): the literal-subanimation engine, audio HAL, the real Substitute
pic-swap, and gradual HP-bar drain — to fill in during the PPU/audio passes. Next on THIS
plan: status conditions / residual damage / trainer AI multi-mon.
