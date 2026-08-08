# Current Plan: In-Battle Animations (move + item-use)

> **Gate:** every commit under this plan follows the mandatory-linter preamble of
> `docs/current_plan_battle_completion.md` (lint_pret_labels both modes at 0,
> static_gate via pre-commit — run the hook with `PATH="/usr/bin:$PATH"` so
> pytest resolves — allowlist is not ours to grow, behavior changes need
> scenarios). Not duplicated here; read it there.

Status: **Stage 2 COMPLETE except the demo harness** (2a landed; 2b projection +
BCOORD + production wiring landed 2026-08-08 — the interpreter now RUNS in
production and the battle tier is green). Owner: this plan.
The 2026-08-08 "interpreter crash" blocker is FIXED: it was never in the
interpreter — the port's `<DONE>` text sentinel lived at GB $C0F0/$C0F1
(= pret wAudioSavedROMBank/wFrequencyModifier) and GetMoveSound's first-ever
freq-modifier write destroyed the text terminator; the sentinel is now flat
.data in src/home/text.asm (memory `regression-battle-anim-interp-runtime-crash`,
FIXED). Remaining Stage 2 item: the `DEBUG_ANIM_DEMO` harness (Item 4).
See memories `battle-animations-plan-created` +
`regression-battle-anim-interp-runtime-crash`.
Umbrella: `docs/current_plan_battle_completion.md` Stage 6 (6a–6e) — this file
is the dedicated detail owner for the in-battle animation engine, the same
relationship the archived `docs/plans/battle_transitions.md` had to Stage 5.
Archive this file to `docs/plans/battle_animations.md` when Stage 6 closes.

## Scope

Port pret `engine/battle/animations.asm` (2858 lines; measured 2026-08-07:
**135 missing / 4 stubs / 6 translated** of 145 modeled labels) plus the
animation entry points in `engine/battle/effects.asm`
(`PlayCurrentMoveAnimation(2)`, `PlayBattleAnimation(2)`), the
`SlideDownFaintedMonPic` / `PredefShakeScreenHorizontally` stubs, and the
in-battle item-use animation splices (`TOSS_ANIM` in `ItemUseBall` /
`ThrowBallAtTrainerMon`; Safari BAIT/ROCK and X-items ride
`PlayBattleAnimation`). Potions/status heals have **no** PlayAnimation sequence
in pret (only `UpdateHPBar2` + SFX, already ported) — no work owed.

**Out of scope** (recorded so nobody "finishes" them here):
- Trade-side consumers `TradeHidePokemon`/`TradeShakePokeball`/
  `TradeJumpPokeball` and the slots engine (`SlotMachineTiles2`) — Phase 4 /
  slots; labels stay `missing`. `BallMoveDistances1/2` are trade-anim data
  (verify at Stage 5 whether the in-battle ball path touches them; port data
  only if referenced).
- Ghost-Marowak reveal (`MarowakAnim`) — reachability owned by
  battle_completion Stage 4c; Stage 5 here carries it as an optional tail.
- F-19 mask retirement — owned by umbrella 6e; Stage 6 here only EVALUATES and
  reports.

## Geometry directive (maintainer, 2026-08-07)

In-battle animations project into the **battle frame** — the GB 20×18 viewport
at the uniform **+10 col / +3 row** tile offset (pixel origin (80,24), extent
(240,168) exclusive; `docs/ui_projection.md` "Battle — GB-centered"). This is
the **opposite** of the transitions precedent: `docs/plans/battle_transitions.md`
re-parameterized to the full 40×25 canvas and says "do NOT use BCOORD"; here
BCOORD/UI_* **is** the rule. Every non-identity coordinate op gets a `; PROJ`
tag + a `DEVIATION{class=projection}` where structure diverges, and a row in
`docs/ui_projection.md`'s index.

Two maintainer-confirmed decisions (AskUserQuestion, 2026-08-07):
- **Screen shake = whole-canvas displacement** via the existing H_SCX/H_SCY
  render offset path (the GB jolts the entire LCD; the matte moves with the
  scene). No frame-only shake HAL.
- **Wavy screen (Psychic family) = per-row horizontal-offset HAL**: an optional
  per-row offset table consulted by the render path, off by default; must
  respect the archived `docs/plans/compositor_perf.md` constraints.

## HAL design (umbrella Stage 6a)

1. **Interpreter runs 100% in GB coordinate space; projection at publication
   only.** All pret math — the `168-X`/`136-Y` HVFLIP mirrors, the
   HFLIP +40px translate, COORDFLIP base-coord mirroring, the X≥168/Y≥112
   off-screen clamps in `AdjustOAMBlock*`, raw `FrameBlockBaseCoords` pixels —
   operates on GB values, byte-faithful. `wShadowOAM` holds pret's exact bytes.
   Load-bearing: battle goldens (`battle_intro`/`battle_menu`/`move_selection`)
   compare the **oam** region; `PublishProjectedOAM`'s own DEVIATION documents
   the "offset in renderer tables, never in OAM bytes" rule.
2. **OAM publication: `PublishProjectedOAM` (sprite_oam.asm), called with
   (80,24)** — copies canonical OAM to GB_OAM unchanged, fills
   `spr_dos_sx/sy = OAM-(8,16)+(80,24)`. One `class=projection` DEVIATION at
   the battle publication site. The animation frame loop republishes after
   every `DrawFrameBlock`/`AdjustOAMBlock*` mutation (the GB's per-frame OAM
   DMA equivalent).
3. **`g_obj_clip = (80,24,240,168)` during animation playback — REQUIRED for
   correctness**: GB off-screen coordinates project to canvas positions that
   are still visible on 320×200 (X=168 → 240 clipped; OAM_Y=160 → dos y
   160-16+24=168 clipped). The clip rectangle reproduces GB hiding semantics
   exactly. Ownership per the established model: the animation entry sets it,
   cleanup restores (0,0,320,200); `ClearSprites` deliberately does not touch
   it. A leaked rectangle visibly clips the next overworld frame and fails
   overworld goldens — same tripwire as cinematics.
4. **Tilemap effects use stride 40 + BCOORD(+10,+3).** pret's stride-20
   literals (player pic origin `5*SCREEN_WIDTH+1`, enemy origin `12`,
   `ClearMonPicFromTileMap`, `CopyTileIDs*`, `AnimCopyRowLeft/Right`,
   `ShakeEnemyHUD`'s BG half) are rewritten as `BCOORD(x,y)` / `UI_*_OFS` —
   never copied. **`BCOORD` is hoisted from `core.asm:580` into
   `include/coords.inc`** (same formula, single definition) so animations.asm
   and core.asm share it. Bounds rule: `W_SHADOW_OAM` ends exactly at
   `W_TILEMAP` — any row arithmetic that could step outside the frame is
   bounds-guarded (transitions postmortem).
5. **Tile uploads route through `CopyVideoData`** (arms `g_tilecache_dirty` by
   construction). `LoadMoveAnimationTiles` targets OBJ tile $31 upward
   (vSprites $8310); at Stage 2 verify the port's battle VRAM occupancy of
   those OBJ slots (player back pic "tile $31" is BG signed space — distinct),
   and keep clear of BG-animator tiles $03/$14.
6. **Palette effects** (`AnimationFlashScreen(Long)`, dark/light/reset,
   `SetAnimationBGPalette`, `SetAnimationPalette`/OBP0) write IO_BGP/IO_OBP*
   through `UpdateCGBPal_BGP`/`UpdateCGBPal_OBP0` (transitions precedent) and
   arm `g_pal_dirty`.
7. **Shake**: whole-canvas H_SCX/H_SCY displacement (decision above), restored
   to 0 at effect end; `class=projection` DEVIATION per shake routine.
8. **Wavy screen**: new per-row X-offset table in the render path (ppu.asm),
   default-off fast path preserved (same pattern as `g_obj_clip`'s non-default
   branch); `AnimationWavyScreen` drives it from `WavyScreenLineOffsets`;
   `class=HAL` + `class=timing` DEVIATIONs (HBlank → per-frame pacing).
9. **Timing**: HBlank loops and raw delay loops become DelayFrame-paced
   equivalents; `class=timing` DEVIATIONs.
10. **Counter widths stay 8-bit** (`dec cl`, not `dec ecx`) — the animation
    file is full of `dec c / jr nz` loops; the widened-counter bug class is the
    project's most-repeated translation defect.
11. **Data is Tier-1, GB-space raw.** Generator emits pret's bytes untouched
    (base coords stay GB pixels; frame blocks stay GB deltas); ALL projection
    lives in code. Dispatch tables that hold PORT routine addresses
    (`SpecialEffectPointers`, `AnimationIdSpecialEffects`,
    `AnimationTypePointerTable`) are hand-written `dd` tables
    (MoveEffectPointerTable pattern).

## Stages

### Stage 0 — plan + HAL design (umbrella 6a)

- [x] `docs/current_plan_battle_animations.md` created with the HAL design
      section (this file, 2026-08-07). Projection spec confirmed against
      `docs/ui_projection.md`, `assets/ui_layout_battle.inc`,
      `PublishProjectedOAM`, and the battle goldens' compared regions.
- [x] Record the plan-created stigmergy memory + link to
      `battle-transitions-landed`'s "next planned work" tail.
      DONE 2026-08-07: memory `battle-animations-plan-created`, linked.

### Stage 1 — Tier-1 data + WRAM + constants

- [x] `tools/generators/gen_battle_anim_data.py` → `assets/battle_anim_data.inc`:
      `AttackAnimationPointers` (dd, flat) + per-move command streams,
      `SubanimationPointers` + bodies, `FrameBlockPointers` + bodies,
      `FrameBlockBaseCoords`, `MoveSoundTable` (SFX_* symbolic against
      `assets/audio_constants.inc`). DONE 2026-08-07: **ROM cross-check green —
      569 bodies byte-identical** against the sha1-verified golden ROM via
      pokeyellow.sym (skipped with a warning when the golden worktree is absent,
      so CI `make assets` still works; `--verify` forces it). 202 anim rows /
      1367 stream bytes / 86 subanims / 122 frame blocks / 177 base coords /
      166 sound rows. Two pret data quirks preserved byte-for-byte: FrameBlock62
      declares 15 entries but carries 16 (dead ROM bytes), and MoveSoundTable
      has one unlabeled row after its assert_table_length. Carrier is the
      data-layer `src/data/battle_anims.asm` (aux_misplaced-clean placement);
      the engine externs from there.
- [x] Constants: generated `assets/battle_anim_constants.inc` (99 equs:
      FIRST_SE_ID, SE_*, SUBANIMTYPE_*, FRAMEBLOCKMODE_*, ANIMATIONTYPE_*, the
      full anim-id tail, NUM_*), include-guarded; `gb_constants.inc` now
      %includes it and its scattered hand equs (TOSS_ANIM, BURN_PSN_ANIM,
      XSTATITEM_*, SLP/CONF pairs, ENEMY_HUD_SHAKE_ANIM, SHAKE_SCREEN_ANIM,
      ANIMATIONTYPE_ pair, NUM_ATTACKS, trainer_ai.asm's local XSTATITEM_ANIM)
      were retired in the same change — generated values confirmed equal before
      removal.
- [x] WRAM: subanimation engine vars added to `include/gb_memmap.inc`,
      sym-pinned vs golden (incl. `wdef4` $DEF4 — pret's address-named
      DrawFrameBlock scratch — and the $D089/$D08A scratch unions;
      `wNumShakes` $CD3D shares the transitions' scratch lane, lifetimes
      disjoint). `wCoordAdjustmentAmount` centralized. audit_memmap: clean
      (1244 symbols, 78 regions).
- [x] Makefile: grouped-target generator rule with full pret-source deps;
      both .incs in the `assets` list; `src/data/battle_anims.asm` linked in
      FRONTEND_SRCS. INC_DEPS wildcard covers consumer rebuilds.
- [x] Gate: build green (0); update_label_db + lint 0 both modes;
      audit_memmap clean; core fidelity **16/16 PASS**; battle tier
      battle_intro/move_selection/ball_catch/battle_faint/battle_blackout/
      battle_damage/trainer_battle_init/win/loss/trainer_battle_route all
      **PASS** (battle_menu green inside the core tier) — measured 2026-08-07.
      battle_intro/battle_menu/move_selection compare the OAM region, so this
      also witnesses that the data landing left shadow OAM untouched.

### Stage 2 — interpreter core + demo harness

**Stage 2a (DONE, committed 2026-08-07):**
- [x] Ported under pret labels into `src/engine/battle/animations.asm` (pret file
      order): `PlayAnimation`, `MoveAnimation`, `ShareMoveAnimations`,
      `LoadSubanimation`, `GetSubanimationTransform1/2`, `PlaySubanimation`,
      `DrawFrameBlock` (all four `wSubAnimTransform` branches),
      `LoadMoveAnimationTiles` + `MoveAnimationTilesPointers` +
      `MoveAnimationTiles0/2`, `AnimationCleanOAM`, `DoSpecialEffectByAnimationId`,
      `GetMoveSound` / `IsCryMove` / `PlayApplyingAttackSound`, `Func_78e98` /
      `BattleAnimCopyTileMapToVRAM` / `WriteLowerByteOfBGMapAndEnableBGTransfer`,
      `CallWithTurnFlipped`, `AnimationDelay10`. Flat-pointer model documented in a
      `class=data-model` DEVIATION (dd tables → ×4 index / 5-byte dispatch entries;
      `wSubAnim*Addr` cursors in port-local `.bss`).
- [x] Hand-written `dd` dispatch tables `SpecialEffectPointers` /
      `AnimationIdSpecialEffects` — placed in the **data layer**
      (`src/data/battle_anim_dispatch.asm`, FRONTEND_SRCS), NOT `animations.asm`:
      the engine-file placement trips `aux_misplaced` (MoveEffectPointerTable
      precedent). ~50 unimplemented `Animation*`/`Do*`/`Trade*` handlers as
      `STUB{}` entries in `core_stubs.asm` (retired across Stages 3–5).
- [x] Gate (static): build+link 0; lint 0 both modes; faithdiff all 19 labels
      clean-with-justification; update_label_db 0; audit_memmap clean.
      **NOTE:** interpreter is LINKED but UNREACHED — production `PlayMoveAnimation`
      (core.asm) is unchanged, so battle behavior is unchanged and the runtime
      golden tier is deferred to 2b (also: mgba absent in the 2a build env).

**Stage 2b (code DONE; only the maintainer's visual sign-off is open):**

> ✅ **The 2026-08-08 crash blocker is FIXED (root cause was NOT the
> interpreter).** The port's `<DONE>`/`<PROMPT>` text-stream sentinel was two
> runtime-written TX_END bytes at GB $C0F0/$C0F1 — pret's wAudioSavedROMBank /
> wFrequencyModifier. `GetMoveSound`'s freq-modifier store (the first ever, once
> the interpreter went live) overwrote the terminator, and the next
> `<DONE>`-terminated battle text (EnemyMonFaintedText) marched the
> TextCommandProcessor through WRAM as a command stream — TX_ASM garbage → the
> old #UD at ebp+0xC235; TX_NUM zeros → a PrintNumber page fault at
> [ebp+0x28000]. Fix: the sentinel is static flat `.data`
> (`done_sentinel_flat`, src/home/text.asm); `text_engine_init` is a retained
> no-op. Full forensic chain: memory
> `regression-battle-anim-interp-runtime-crash` (FIXED).

- [x] Projection publication: `PublishProjectedOAM(80,24)` after each
      `DrawFrameBlock` mutation + `g_obj_clip = (80,24,240,168)` set at
      `MoveAnimation` entry / restored at `.animationFinished` (HAL design
      items 2-3). DONE 2026-08-08 (now REACHED in production; battle tier green).
- [x] `BCOORD` hoist to `include/coords.inc`; core.asm `%include`s it and drops
      its local `%define` (faithdiff-neutral, no behavior change). DONE 2026-08-08.
- [x] Retire the 4 dispatcher stubs with real bodies in the `effects.asm`
      mirror (`PlayCurrentMoveAnimation(2)`, `PlayBattleAnimation(2)` +
      `PlayBattleAnimationGotID`); core.asm `PlayMoveAnimation` = faithful pret
      body (`wAnimationID` / Delay3 / MoveAnimation / Func_78e98). DONE
      2026-08-08 — faithdiff clean on all 6 labels, lint 0 both modes.
- [x] `DEBUG_ANIM_DEMO=1` harness. DONE 2026-08-08. Makefile gate → NASMFLAGS
      `-D DEBUG_ANIM_DEMO -D DEBUG_BATTLE_GOLDEN -D DEBUG_BATTLE`; the harness
      branch rides the DEBUG_BATTLE_GOLDEN battle scene in `debug_dump.asm`
      (`RunBattleTest`) and calls the real `PlayMoveAnimation` in a loop.
      `ANIM=<MOVE_CONST>` pins the move (default `POUND`); the counter lives in
      `.data` (`anim_demo_count`), never a register. Bounded by default —
      `DEBUG_ANIM_LOOPS` (3) iterations then `DebugDumpMemory`; the shared
      `/LOOP` exe flag (`g_cfg_musicloop`) makes it run forever for watching.
      Evidence: bounded headless runs dump GBSTATE+DUMP (rc 0); `ANIM=POUND` vs
      `ANIM=GUST` differ in 9 OAM bytes (the interpreter really ran and the knob
      is live); `DEBUG_ANIM_LOOPS` 1 vs 15 = 16 s vs 36 s (the counter is
      honored). battle_faint + battle_intro still PASS; lint 0 both modes.
- [ ] **Maintainer visual sign-off of a Pound/Gust-class animation — STILL
      PENDING.** The harness existing is not the sign-off. Sign-off command:
      `dos_port/run DEBUG_ANIM_DEMO=1 [ANIM=<MOVE_CONST>] /LOOP`
      (Esc quits via the normal DelayFrame quit path). Expect OAM particle
      frame blocks only until Stages 3-5 retire the handler stubs.
- [x] Gate: battle tier green — 13 scenarios PASS 2026-08-08 with the
      interpreter live (battle_intro/menu/move_selection/damage/faint/blackout,
      trainer_battle_init/win/loss/route, ball_catch, item_potion_use,
      fish_old_rod). Demo visual sign-off (Pound/Gust class) moves to the
      demo-harness item.

### Stage 3 — screen/palette special effects + wAnimationType (umbrella 6d)

- [ ] Flash/palette family: `AnimationFlashScreen`, `AnimationFlashScreenLong`
      + `FlashScreenLong{Monochrome,SGB,Delay}`, `AnimationDarkScreenPalette`,
      `AnimationDarkenMonPalette`, `AnimationLightScreenPalette`,
      `AnimationResetScreenPalette`, `AnimationUnusedPalette1-4`,
      `SetAnimationBGPalette`, `SetAnimationPalette`, `FlashScreenUnused`.
- [ ] Shake family via whole-canvas H_SCX/H_SCY: `AnimationShakeScreen`,
      `AnimationShakeScreenVertically`, `AnimationShakeScreenHorizontallyFast`,
      `AnimationShakeScreenHorizontallySlow`, `AnimationUnusedShakeScreen`,
      `ShakeScreenVertically`, `ShakeScreenHorizontallyHeavy/Light/Slow/Slow2`;
      retire the `PredefShakeScreenHorizontally` stub (pret
      engine/gfx/screen_effects.asm — mirror placement decision at
      implementation).
- [ ] `BlinkEnemyMonSprite`; fill `PlayApplyingAttackAnimation`'s
      `AnimationTypePointerTable` dispatch (types 1–6) — retires its TODO-HW.
- [ ] Per-row offset HAL in ppu.asm (default-off fast path; compositor_perf
      constraints) + `AnimationWavyScreen` / `WavyScreen_SetSCX` /
      `WavyScreenLineOffsets`.
- [ ] Gate: faithdiff; battle tier green; demo sign-off on flash (Thundershock
      class), shake, and Psychic wave.

### Stage 4 — mon-pic + OAM particle families

- [ ] Slides: `AnimationSlideMonUp/Down/Off`, `_AnimationSlideMonUp/Off`,
      `AnimationSlideEnemyMonOff`, `AnimationSlideMonDownAndHide`,
      `AnimationSlideMonHalfOff`; retire `SlideDownFaintedMonPic` stub (pret
      core.asm label — body lands per pret placement).
- [ ] Hide/show + tilemap helpers: `AnimationHideMonPic`,
      `AnimationHideEnemyMonPic`, `AnimationShowMonPic`,
      `AnimationShowEnemyMonPic`, `ClearMonPicFromTileMap`,
      `GetMonSpriteTileMapPointerFromRowCount`, `GetTileIDList`, `CopyTileIDs`,
      `CopyTileIDs_NoBGTransfer`, `CopyTileIDsFromList`, `CopyPicTiles`,
      `CopyDownscaledMonTiles`, `AnimCopyRowLeft`, `AnimCopyRowRight` (all
      BCOORD-projected, `; PROJ` tagged).
- [ ] Motion: `AnimationShakeBackAndForth`, `AnimationMoveMonHorizontally`,
      `AnimationResetMonPosition`, `AnimationBoundUpAndDown`,
      `AnimationSquishMonPic` + `_AnimationSquishMonPic`,
      `AnimationMinimizeMon` + `MinimizedMonSprite(End)`.
- [ ] Particles: `AnimationSpiralBallsInward` + `SpiralBallAnimationCoordinates`,
      `AnimationShootBallsUpward` + `_AnimationShootBallsUpward` +
      `AnimationShootManyBallsUpward` + `UpwardBallsAnimXCoordinates*Turn`,
      `AnimationLeavesFalling`, `AnimationPetalsFalling`,
      `AnimationFallingObjects` + `FallingObjects_*` (6 labels + 2 data),
      `AnimationWaterDropletsEverywhere` + `_AnimationWaterDroplets`.
- [ ] HUD shake + OAM helpers: `AnimationShakeEnemyHUD`,
      `ShakeEnemyHUD_ShakeBG`, `ShakeEnemyHUD_WritePlayerMonPicOAM`,
      `BattleAnimWriteOAMEntry`, `InitMultipleObjectsOAM`, `Func_79929`.
- [ ] Gate: faithdiff; battle tier green; demo sign-off on Razor Leaf, Surf,
      Teleport, Minimize, Sing class representatives.

### Stage 5 — item-path animations + substitute/transform

- [ ] Ball path: `TossBallAnimation`, `DoBallTossSpecialEffects`,
      `DoBallShakeSpecialEffects`, `DoPoofSpecialEffects`; restore pret's
      `ld a, TOSS_ANIM / MoveAnimation` splice in `ItemUseBall` and
      `ThrowBallAtTrainerMon` (BLOCKBALL path); verify `BallMoveDistances1/2`
      referencing (port data only if the battle path reads them).
- [ ] Remaining per-anim hooks: `DoGrowlSpecialEffects`,
      `DoRockSlideSpecialEffects`, `DoExplodeSpecialEffects`,
      `DoBlizzardSpecialEffects`, `FlashScreenEveryFourFrameBlocks`,
      `FlashScreenEveryEightFrameBlocks`, `TailWhipAnimationUnused`,
      `GetIntroMoveSound`.
- [ ] Substitute/Transform: `AnimationSubstitute`, `AnimationTransformMon`,
      `HideSubstituteShowMonAnim`, `ReshowSubstituteAnim` (retire 4 stubs),
      `ChangeMonPic`, `CopyMonsterSpriteData`, `CopyTempPicToMonPic`; sweep the
      stale `FLAG FOR MASTER` comments in `move_effects/substitute.asm:43` and
      `move_effects/transform.asm:66`.
- [ ] Optional tail (coordinate with umbrella 4c): `MarowakAnim` +
      `CopyMonPicFromBGToSpriteVRAM` (engine/battle/ghost_marowak_anim.asm).
- [ ] Gate: faithdiff; `ball_catch` stays green; demo sign-off on ball toss/
      shake/capture + Substitute; Oak-intro capture visually shows the throw
      (`DEBUG_SEAM_KEEP_BATTLES=1` pilot).

### Stage 6 — verification closure + bookkeeping

- [ ] New must-hit golden scenarios (umbrella Stage 6 final box): physical
      (Pound/Tackle), elemental flash (Thundershock), ball (TOSS_ANIM entered
      through the item path), shake/blink (`wAnimationType`), option-off
      (`BIT_BATTLE_ANIMATION` set). Ordered checkpoints (GBSTATE dumps at
      defined landmarks), not terminal-screen-only; any mask carries a written
      why-string. Scenario registration per the manifest/validate_scenarios
      chain; each scenario's entry states what path it actually ENTERS (false-
      witness rule).
- [ ] Full battle tier + core fidelity + `fidelity-full`; `goldens-verify` if
      golden artifacts changed.
- [ ] Evaluate F-19 masks against the now-real animation route; report to
      umbrella 6e (do not delete unilaterally).
- [ ] Sweep: retired stubs' extern comments (`label_status --callers` each),
      `update_label_db`, `docs/ui_projection.md` index rows + a battle-anim
      subsystem note, `docs/translation_log.md` entries, stigmergy memories
      (close/update + `episode_record`), refresh umbrella Stage 6 boxes,
      archive this plan.

## Verification summary

- Per-label: faithdiff justified; lint both modes 0; `fidelity_gate --base`
  per batch; static_gate via pre-commit (`PATH="/usr/bin:$PATH"` trap).
- Behavior: battle scenarios 14/15/16/20/33/34/43/44/45/46/51 green at every
  stage; new animation scenarios at Stage 6.
- Visual: `dos_port/run DEBUG_ANIM_DEMO=1 [ANIM=…]` maintainer sign-off per
  stage (transitions precedent).
- Traps carried forward: AUTOKEY_DUMP_ON_BATTLE gates on `wIsInBattle` (cannot
  photograph pre-battle trainer phases — wild path sets it earlier); harness
  loop counters in memory; `W_SHADOW_OAM` ends at `W_TILEMAP` (bounds-guard);
  tiles $03/$14 reserved; 8-bit loop counters; `%include` bare filenames.
