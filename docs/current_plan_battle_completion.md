# Current Plan: Battle Engine Completion (trainer battles, sub-menus, special types, transitions, animations)

Status: **not started** — tick stages as they land. Archive to
`docs/plans/battle_completion.md` when complete.

Successor to the archived battle plans (`docs/plans/battle_engine.md`,
`battle_pret_alignment.md`) and the closed audit ledger
(`docs/archive/battle_audit_findings.md`). Basis: the 2026-07-12 engine-gap
survey. The battle **backend is done and linked** — core turn loop, damage
pipeline, all 32 move-effect handlers (dispatch table 1:1 with pret), trainer-AI
move scoring, residual damage/status penalties/badge boosts, EXP/level-up/
evolution/learn-move, enemy send-out on faint, blackout, run prevention. What
remains is reachability wiring, interactive sub-flows, special battle types,
and the two visual subsystems (transitions, animations).

**Interfaces with sibling plans (do not implement here):**
- `UseItem_`/`ItemUsePtrTable`/`ItemUseBall` internals → **items plan**
  (`current_plan_item_use.md`). This plan owns only `BattleItemMenu` (the menu +
  battle-context routing into that dispatcher). Stage 2b is blocked on it.
- Oak-intro cutscene script + trainer-sight overworld side → **overworld plan**
  (`current_plan_overworld_events.md`). This plan owns the *battle-side*
  `BATTLE_TYPE_PIKACHU` behavior it needs (Stage 4a blocks that cutscene's
  final verification).
- Battle-screen geometry/widescreen → `current_plan_battle_ui.md` (unchanged).
- Link battles → Phase 4 (out of scope; keep pret's link branches as the
  existing documented dead branches).

## Stage 1 — trainer battles live (small, highest value: mostly de-gating + one init branch)

- [ ] **1a. `InitBattleCommon` trainer branch.** The port's `_InitBattleCommon`
  (`src/engine/battle/init_battle.asm:207`) is wild-only. Port pret's branch
  (pret `engine/battle/init_battle.asm:25-58`): `wEnemyMonSpecies2 - OPP_ID_OFFSET`
  carry test → wild vs trainer; trainer path = `ld [wTrainerClass]` +
  `GetTrainerInformation` + `ReadTrainer` + `_LoadTrainerPic` (front-pic slot,
  pret `:143`, `CopyUncompressedPicToTilemap` at coord 12,0 — reuse the
  consolidated `LoadFrontSpriteByMonIndex`/`CopyUncompressedPicToHL` machinery,
  see memory `sprite-flipped-placement`), `wEnemyMonPartyPos=$FF`, `wAICount=$FF`,
  `wIsInBattle=2`, and the `wLoneAttackNo` → `ModifyPikachuHappiness
  PIKAHAPPY_GYMLEADER` tail (stub today — see Stage 3d). Keep pret's label split
  (`InitBattleCommon`/`InitWildBattle`/`_InitBattleCommon`) with a comment where
  the port collapses it. `ReadTrainer` + `read_trainer_party.asm` are already
  real and linked; `GetTrainerInformation` needs a port (grep first — the name
  is referenced in `trainer_battle.asm` comments only). **Note:** pret calls
  `DoBattleTransitionAndInitBattleVariables` here; until Stage 5 lands, keep the
  port's current fixed-transition init and leave a `; TODO(stage5)` at the pret
  call site.
- [ ] **1b. De-gate `TRAINER_BATTLE_LIVE`.** The gate (`trainer_battle.asm:50,103`,
  `map_sprites.asm:77,1224`) is never defined in the Makefile, so trainers
  currently talk, get flagged **beaten without fighting** (default-build defect),
  and no battle starts. Once 1a works under the flag (via the existing
  `DEBUG_BATTLE_TRAINER` harness, Makefile:695), define it by default, then
  delete the `%ifdef`s outright (retire the gate, don't leave dead arms). Also
  resolve the `TODO(M8.2)` in `StartTrainerBattle`: pret `inc [wCurMapScript]`
  so the map script advances to `EndTrainerBattle` — coordinate the
  `wCurMapScript` alias with the overworld plan's script work.
- [ ] **1c. Beaten-flag ordering fix.** Move the "mark trainer beaten" write
  (`map_sprites.asm:TrainerEncounterFlow`) to the post-victory path (pret sets
  it via `EndTrainerBattle` after the battle resolves), so losing/escaping a
  trainer doesn't permanently disarm them.
- [ ] **1d. Trainer end-of-battle.** Verify the loss path (blackout via the
  generic `AnyPartyAlive` → `HandleBlackOut` in `overworld.asm:1019-1027` —
  statically audited as trainer-generic, never exercised) and the win path:
  prize money is **already real** (`read_trainer_party.asm` computes
  `wAmountMoneyWon` via flat `AddBCD`; `TrainerBattleVictory`
  (`faint_sendout.asm:156-169`) awards it — the audit's C-12 "no-op stub" note
  is stale). Missing: **class-specific `TrainerDefeatedText`** — a Tier-1
  generator task (extend `gen_battle_text.py` or a sibling `gen_trainer_text.py`
  parsing pret's per-class end-battle text; remember the C-4 lesson: carry
  `text_far`+`text_asm` continuations, don't truncate). Also the trainer-win
  faint SFX + `PlayBattleVictoryMusic` trainer branch (`TODO-HW` in
  `faint_enemy.asm` — audio engine is live per memory `overworld-audio-destub`,
  so wire real calls, not no-ops).
- [ ] **1e. AI execution halves** (`trainer_ai.asm`): `SwitchEnemyMon` (`:995`)
  updates party HP/status but never sends the new mon out — wire it to the real
  `EnemySendOut` (`faint_sendout.asm`) + withdrawal text; destub the
  `AIUseX*`/`AIRecoverHP`/`AICureStatus` UI leaves (item-use text + effect
  application; the decision logic is already live).
- **Verify:** `DEBUG_BATTLE_TRAINER` end-to-end win/lose headless (FRAME.BIN);
  live DOSBox-X walk into a Route-1-reachable trainer sightline → battle →
  victory → money/beaten-flag → re-talk shows end-battle text, no re-fight;
  lose → blackout to Pokécenter, trainer still armed. `faithdiff` per routine,
  `lint_pret_labels` exit 0. Build with `DEBUG_SEED_PARTY=1`.

## Stage 2 — in-battle sub-menus (the two dead battle-menu buttons)

- [ ] **2a. `BattlePartyMenu` (PKMN — voluntary switch).** Real body for the
  `ret` stub (`battle_menu.asm:227-232`): pret's PKMN path = party menu in
  `BATTLE_PARTY_MENU` mode → confirm → withdraw text → `SendOutMon` + HUD
  redraw + enemy gets a free move. Reuse the linked overworld `DisplayPartyMenu`
  with the battle menu-type byte (do NOT fork a battle copy — pret
  distinguishes by `wPartyMenuTypeOrMessageID`).
- [ ] **2b. Forced-switch flow.** `DoUseNextMonDialogue`
  (`faint_switch.asm:121-131`) auto-answers Yes → real Yes/No box (the generic
  two-option menu from the bag work exists — `start_sub_menus.asm .opt2_menu`);
  `ChooseNextMon` (`:141-180`) auto-picks the first live mon → interactive
  `BATTLE_PARTY_MENU` **with CANCEL disallowed** (the documented reason the
  overworld menu wasn't reused; the menu-type byte governs this).
- [ ] **2c. `BattleItemMenu` (ITEM).** Wire the `ret` stub to the items plan's
  `UseItem_` dispatcher: bag list in battle context, selection → `UseItem_`,
  consume turn on success per pret. **Blocked on items plan Stage 1-2**; land
  the menu shell + a `; STUB(items-plan)` routing note earlier if useful for
  testing. Catching then works end-to-end via the items plan's `ItemUseBall`
  (which needs `wIsInBattle`/this menu as its entry).
- **Verify:** mid-battle switch (voluntary + on-faint) headless with a 2-mon
  `DEBUG_SEED_PARTY`; FIGHT menu reflects switched mon's moves; item use in
  battle once dispatcher lands (potion heals, turn consumed).

## Stage 3 — backend leaves + stub retirement (independent, parallelizable)

- [ ] **3a. `CheckNumAttacksLeft` destub** (`core.asm:2340`, a live-called `ret`
  — call sites `:290,:316`): multi-turn counters (Bide/Thrash/Wrap) currently
  never expire. Faithful translation; preserve + tag the **Trapping Sleep
  Glitch** (`GLITCH` + `Safety:`, bug-ledger row).
- [ ] **3b. Bide accumulation half.** Only Bide's setup half is ported
  (`move_effects/bide.asm`); the damage-accumulation/unleash path lives in the
  status-condition checks — verify what `CheckPlayerStatusConditions`/
  `CheckEnemyStatusConditions` actually have (the audit's A-3 fix touched this
  region) and port the missing accumulation/release, preserving the **Bide vs
  Fly/Dig** bug (ledger row, tag it).
- [ ] **3c. Pay Day payout** (`end_of_battle.asm:56-66` dead branch): flat
  `AddBCD` call (pattern: `faint_sendout.asm:161-167`) + generate
  `PickUpPayDayMoneyText`; also make the Pay Day move effect actually
  accumulate `wTotalPayDayMoney` (its `TODO-HW`).
- [ ] **3d. `battle_exp_stubs.asm` cleanup:** real `CalculateModifiedStats`
  (in-battle stat-stage recompute after level-up/vitamin — pret
  `engine/battle/core.asm`), real `ModifyPikachuHappiness` (coordinate with the
  wider Pikachu-follower gap — a minimal faithful happiness delta is fine here),
  `PrintEmptyString` (trivial). **Ride-along:** rewrite the file's stale header
  prose (the "LATENT COLLISION" paragraph describes already-retired stubs).
- [ ] **3e. Mutual-faint draw fanfare** (bug-ledger row "Battle Draw Victory
  Fanfare"): port the draw detection on Self-Destruct/Explosion KO with the
  Gen-1 wrong-music-cue bug preserved + tagged.
- [ ] **3f. EXP_ALL investigation** (memory `battle-win-crash-not-in-gainexp`
  OPEN tail): bug#3's polarity fix is in, but the *genuine* EXP_ALL whole-party
  `GainExperience` pass zeroed `wIsInBattle` in the original repro — suspect an
  OOB write in the multi-participant loop. Seed EXP_ALL into the bag
  (`DEBUG_SEED_*`), win a wild battle, checkpoint `wIsInBattle` (the FE_CP
  in-code checkpoint method from that memory cracked bug#3; MCP watchpoints
  didn't — worth a retry with the rebuilt harness's `set_watchpoint` (BPLM)
  on `wIsInBattle` before falling back to FE_CP). Fix or close.
- **Verify:** native ELF32 harness where applicable (Bide/counter math);
  headless battle scenarios per item; `faithdiff` each touched pret label.

## Stage 4 — special battle types

- [ ] **4a. `BATTLE_TYPE_PIKACHU` (starter battle).** Constant exists
  (`gb_constants.inc:313`), referenced nowhere. Audit every pret branch on it
  (`init_battle_variables`, battle menu, ball-throw refusal, loss handling) and
  implement so the overworld plan's Oak cutscene can fire
  `wCurOpponent=STARTER_PIKACHU, wBattleType=BATTLE_TYPE_PIKACHU, level 5` (its
  documented ABI). **This item unblocks the Oak-intro milestone — do early in
  this stage.**
- [ ] **4b. `BATTLE_TYPE_OLD_MAN`** (catching-tutorial battle): pret branches in
  the battle menu (player name → OLD MAN, no FIGHT) + the scripted throw. Needs
  the Viridian old-man script (overworld plan) to be reachable; battle-side can
  land first behind the debug harness.
- [ ] **4c. Ghost Marowak.** `IsGhostBattle` is already real (`ghost.asm`) and
  the RUN check has its `TODO(faithful)` slot (`battle_menu.asm:275`). Port the
  wild-side ghost init (pret `InitWildBattle` `.isGhost`: GHOST pic/name swap)
  + unidentified-ghost move refusal, and the Poké-Doll early-exit **with its
  bug-ledger `BUG` tag** (skips the encounter permanently). Reachability
  (Pokémon Tower, Silph Scope event) is overworld-plan content; battle side
  lands behind a harness.
- [ ] **4d. Safari battle mechanics.** `BATTLE_TYPE_SAFARI` is set (map-range,
  `init_battle_variables.asm:54-61`) and RUN always escapes, but nothing else
  exists: BAIT/ROCK menu replacing FIGHT/ITEM, `wSafariBaitFactor`/
  `wSafariEscapeFactor` (WRAM aliases needed — `transform.asm:38` notes the
  addresses), angry/eating text, per-turn flee roll, catch handoff to
  `ItemUseBall`'s Safari branch (items plan owns the ball math; this plan owns
  the menu + turn loop divergence). Low urgency until the Safari Zone maps/step
  counter exist (overworld/content side) — keep last in this stage.
- **Verify:** each type behind a `DEBUG_BATTLE_*` seed; FRAME.BIN for menu
  variants; the Pikachu battle plays as part of the Oak cutscene live test.

## Stage 5 — battle transitions (pret `engine/battle/battle_transitions.asm`, 757 lines)

- [ ] Port `GetBattleTransitionID_WhichDungeonMap` /
  `GetBattleTransitionID_CompareLevels` / `_IsDungeonMap` + the
  `BattleTransitions` jump table + the 4 transition implementations (spiral/
  shrink × flash/no-flash). These animate via `rSCX`/`rSCY`/palette writes —
  map onto the port's shadow-scroll + present pipeline (`H_SCX`/`H_SCY`,
  `IO_SCX/SCY` shadows; remember memory `battle-init-carryover-reset`: the
  flat-canvas entry zeros these — transitions run *before* that reset).
  Tag the ledger row **"Battle transitions fail to account for scripted
  battles"** (`GetBattleTransitionID_CompareLevels` reads stale
  `wPartyMon1HP`-adjacent WRAM in scripted battles) as `BUG(critical)` when
  ported. Replace the current single fixed transition in `_InitBattleCommon`
  (Stage 1a's `TODO(stage5)`).
- **Verify:** FRAME.BIN sequence dumps per transition ID; goldencheck scenarios
  still pass; wild + trainer + dungeon-map variants.

## Stage 6 — battle animations (the long pole; design-gated, do last)

Current state: `animations.asm` (85 lines) = pret's ANIMATION=OFF branch only —
a 30-frame delay; `PlayApplyingAttackAnimation` dispatch is faithfully gated on
`wAnimationType` but the backend never sets it and the shake/blink bodies are
`TODO-HW` (`animations.asm:46-47,78-82`; `PredefShakeScreenHorizontally` stub in
`core_stubs.asm:107`). pret's engine is 2858 lines + Tier-1 data
(`data/battle_anims/`: subanimations, frame blocks, animation ids).

- [ ] **6a. HAL hook design (gate for everything below — write a short design
  doc section here before coding).** The interpreter needs, from the software
  PPU: (i) a battle-OAM scratch layer `DrawFrameBlock` can write sprite tuples
  into (the existing shadow-OAM path + `spr_oam_valid` — see memory
  `flatcanvas-sprite-suppression`; battle currently suppresses sprites), (ii)
  per-frame `rSCX`/`rSCY`-shadow displacement for screen shake (exists:
  `H_SCX`/`H_SCY` drive `render_bg`'s blit offset), (iii) palette-flash hooks
  (BGP rewrite → the DMG-green ramp remap; keep Phase-5 CGB in mind), (iv) VRAM
  tile uploads for move-anim tilesets (`LoadMoveAnimationTiles`) — **must set
  `g_tilecache_dirty`**. ~~**Sequencing conflict:** the compositor-perf plan
  (`docs/plans/compositor_perf.md`) rewrites these exact files
  (`ppu.asm` render_bg/render_sprites/present). Land perf Stages 1-4 first, or
  freeze that plan while this stage runs — do not interleave; both plans'
  FRAME.BIN baselines invalidate each other.~~ **Cleared 2026-07-12:** that plan
  is complete and archived, so there is no conflict left to sequence around. It
  did raise the stakes on the flag, though — BG *and* window now read only
  `tile_cache`, so a move-anim tile upload that fails to arm `g_tilecache_dirty`
  is **visible corruption**, not merely a stale decode.
- [ ] **6b. Tier-1 data generators.** `gen_battle_anims.py` → `assets/`:
  subanimation tables, frame blocks, `AttackAnimationPointers`, move-anim
  tileset graphics (pret `data/battle_anims/*.asm` + `gfx/battle/*.png`).
  Two-tier rule: tables generated; the interpreter + special-effect handlers
  are hand-written Tier-2.
- [ ] **6c. Core interpreter:** `PlayAnimation` → `LoadSubanimation` /
  `GetSubanimationTransform1/2` / `PlaySubanimation` / `DrawFrameBlock` /
  `AnimationCleanOAM`, with `DoSpecialEffectByAnimationId` dispatch (ball toss/
  shake/poof/rock slide/explode/blizzard/growl flags first — the ones battle
  reaches; the trade/slot-machine effects are out of scope until those systems
  exist).
- [ ] **6d. `AnimationTypePointerTable` + shake/blink:** `ShakeScreenVertically`
  / `ShakeScreenHorizontally*` / `BlinkEnemyMonSprite`; make the backend set
  `wAnimationType` per pret (core.asm sets 1-3 around the damage application);
  retire `PredefShakeScreenHorizontally` stub. Screen-flash/palette commands
  (`AnimationFlashScreen*`, `SetAnimationPalette`) via the 6a palette hook.
- [ ] **6e. Options wiring:** honor `wOptions` BIT_BATTLE_ANIMATION properly
  (the current file documents why it can't yet — once ON path exists, restore
  pret's exact gate; the options menu already writes the bit).
- **Verify:** per-move FRAME.BIN sequences vs mGBA golden captures for a
  sample set (tackle, gust, thunderbolt, ball toss); ANIMATION=OFF still
  byte-identical to today's delay path; perf spot-check on 486-class cycles
  (animations must not blow the frame budget the perf plan just recovered).

## Files (primary)

- `src/engine/battle/init_battle.asm`, `trainer_battle.asm`,
  `read_trainer_party.asm`, `faint_sendout.asm`, `trainer_ai.asm` — Stage 1
- `src/engine/battle/battle_menu.asm`, `faint_switch.asm` — Stage 2
- `src/engine/battle/core.asm`, `move_effects/bide.asm`, `end_of_battle.asm`,
  `battle_exp_stubs.asm` (retire) — Stage 3
- `src/engine/battle/init_battle_variables.asm`, `ghost.asm`, new
  `safari.asm` — Stage 4
- new `src/engine/battle/battle_transitions.asm` — Stage 5
- `src/engine/battle/animations.asm` (rewrite), new `tools/gen_battle_anims.py`,
  `src/ppu/ppu.asm` hooks — Stage 6
- `map_sprites.asm` (gate + beaten-flag), `Makefile` (gate retirement,
  generator wiring)

## Conventions checklist (every stage)

pret labels preserved; stubs only in `*_stubs.asm` and retired via
`label_status --callers`; text via generators (never hand-encoded charmap);
`BUG`/`GLITCH` + `Safety:` tags for newly-reachable ledger rows (Trapping
Sleep, Bide vs Fly/Dig, Ghost-Marowak Poké Doll, scripted-battle transition,
Index #000 rides with items-plan catching); `faithdiff <Label>` +
`lint_pret_labels` + `update_label_db` before each commit; translation_log
entries per routine.
