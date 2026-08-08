# Current Plan: In-Battle Animations (move + item-use)

> **Gate:** every commit under this plan follows the mandatory-linter preamble of
> `docs/current_plan_battle_completion.md` (lint_pret_labels both modes at 0,
> static_gate via pre-commit — run the hook with `PATH="/usr/bin:$PATH"` so
> pytest resolves — allowlist is not ours to grow, behavior changes need
> scenarios). Not duplicated here; read it there.

Status: **Stage 2 COMPLETE, maintainer-signed-off 2026-08-08** (2a interpreter
0b629e0a; 2b projection+BCOORD ec29c877, production wiring 1ad2fc46, demo
harness 88d3043a, OBJ-layer fix 6d31b454; POUND demo LGTM'd). **Plus the
measured CGB OBJ palette model landed 21412b32** (GUST demo LGTM'd:
white/black particles per real-hardware measurement; wOnSGB=1, slot=attr&7,
commit_palette 4-base×{OBP0,OBP1}; spec = memory
`battle-anim-cgb-obj-palette-model` — read it before ANY Stage 3+ palette
work). `SetAnimationPalette` is already translated (pulled forward from
Stage 3 in 21412b32). Next: Stage 3 remainder.
Owner: this plan.
Three defects were root-caused on the way (all memories FIXED; the third is
the palette model itself — wOnSGB=0 routed SetAnimationPalette to the DMG
branch, and render_sprites/commit_palette modeled OBJ slots wrong):
`regression-battle-anim-interp-runtime-crash` — the "interpreter crash" was the
port's `<DONE>` text sentinel at GB $C0F0/$C0F1 (= pret
wAudioSavedROMBank/wFrequencyModifier) destroyed by GetMoveSound's first-ever
freq-modifier write; sentinel is now flat .data in src/home/text.asm.
`regression-battle-anim-oam-never-composited` — HideBattlePokeballs' port-only
LCDC OBJ-bit disable kept render_sprites' gate shut for the whole battle.
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

**Stage 2b (DONE — code + maintainer visual sign-off 2026-08-08):**

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
- [x] **Maintainer visual sign-off — DONE 2026-08-08 ("LGTM"),** on the POUND
      demo AFTER the OBJ-layer fix 6d31b454 (first viewing caught that defect:
      memory `regression-battle-anim-oam-never-composited`). Sign-off command
      was `dos_port/run DEBUG_ANIM_DEMO=1 /LOOP`. Known harness artifact, NOT a
      bug: the demo starts the move before the send-out animation finishes —
      in a real battle the move-selection menu gates that; the harness has no
      menu. Do not "fix" this in the harness.
- [x] Gate: battle tier green — 13 scenarios PASS 2026-08-08 with the
      interpreter live (battle_intro/menu/move_selection/damage/faint/blackout,
      trainer_battle_init/win/loss/route, ball_catch, item_potion_use,
      fish_old_rod). Demo visual sign-off (Pound/Gust class) moves to the
      demo-harness item.

### Stage 3 — screen/palette special effects + wAnimationType (umbrella 6d)

- [x] Flash/palette family: `AnimationFlashScreen`, `AnimationFlashScreenLong`
      + `FlashScreenLong{Monochrome,SGB,Delay}`, `AnimationDarkScreenPalette`,
      `AnimationDarkenMonPalette`, `AnimationLightScreenPalette`,
      `AnimationResetScreenPalette`, `AnimationUnusedPalette1-4`,
      `SetAnimationBGPalette`, `FlashScreenUnused`. (`SetAnimationPalette`
      DONE — pulled forward, 21412b32.) Also took the two subanim-counter
      gated flashes `FlashScreenEveryFour/EightFrameBlocks`, which the
      checklist had not named but which belong to the same family (Hyper Beam,
      Thunderbolt, Spore dispatch to them). DONE 2026-08-08 — ten stubs
      retired; no HAL owed (a BGP write is the whole effect, `commit_palette`
      picks it up from `DelayFrame`).
      **Colour reference corrected.** The measured BGP sequence `6F,1B,00` ×3
      then `E4` is NOT `AnimationFlashScreenLong` — pret's `dc` tables decode
      to `F9 FE FF FE F9 E4 90 40 00 40 90 E4` (monochrome) and
      `F8 FC FF FC F8 E4 90 40 00 40 90 E4` (SGB), neither containing `$6F` or
      `$1B`. The trace is `AnimationDarkScreenPalette` + 3×
      `AnimationFlashScreen` + `AnimationResetScreenPalette`, so it validates
      those three routines. Memory `battle-anim-cgb-obj-palette-model` fact 6
      updated.
- [x] Shake family via whole-canvas H_SCX/H_SCY: `AnimationShakeScreen`,
      `AnimationShakeScreenVertically`, `AnimationShakeScreenHorizontallyFast`,
      `AnimationShakeScreenHorizontallySlow`, `AnimationUnusedShakeScreen`,
      `ShakeScreenVertically`, `ShakeScreenHorizontallyHeavy/Light/Slow/Slow2`;
      retire the `PredefShakeScreenHorizontally` stub (pret
      engine/gfx/screen_effects.asm — mirror placement decision at
      implementation: `dos_port/src/engine/gfx/screen_effects.asm`, per the
      "complete body in `dos_port/src/<pret path>`" rule).
      **Design facts established 2026-08-08 (measured, not assumed):**
      (a) On GB the battle screen IS the window layer — `core.asm` sets
      `rWY = 0` on battle entry, which is why pret shakes via `rWX`/`rWY` and
      why `AnimationWavyScreen` turns the window OFF (`hWY = 144`) to expose
      the BG before wobbling `rSCX`. In the port the battle screen is on the
      BG layer and the window is only descriptor-driven boxes, so the
      equivalent whole-screen displacement is `H_SCX`/`H_SCY` — the
      maintainer's directive, confirmed reachable.
      (b) Both pret shakes are **unidirectional from neutral**: `.MutateWX`
      clamps a negative result to 0 before `add 7`, so `rWX` only ever spans
      7..7+b, and `rWY` only ever spans 0..b. So the displacement never needs
      to be negative, and the port's unsigned `movzx`-based `bg_scx`/`bg_scy`
      is sufficient. Mapping: port `H_SCX = pret rWX - 7`, `H_SCY = pret rWY`;
      neutral is 0 on both. Axis sense is inverted (a larger `bg_sc*` samples
      further into the surface, moving content the opposite way from a window
      move) — cosmetically irrelevant for a symmetric jolt, but it gets a
      `DEVIATION{class=projection}`.
      (c) Do NOT route the shake through `IO_SCX`/`IO_SCY` directly:
      `commit_shadow_regs` (vblank.asm) overwrites both from `H_SCX`/`H_SCY`
      every `DelayFrame`. Write the shadows.
      (d) `hMutateWX`/`hMutateWY` do not exist in the port yet — add to
      `gb_memmap.inc`. `wDisableVBlankWYUpdate` already exists (0xD09F,
      honoured by `commit_shadow_regs`); keep pret's writes to it verbatim.
- [x] `BlinkEnemyMonSprite`; fill `PlayApplyingAttackAnimation`'s
      `AnimationTypePointerTable` dispatch (types 1–6) — retires its TODO-HW.
      DONE 2026-08-08. `AnimationBlinkEnemyMon` (the `CallWithTurnFlipped`
      wrapper) is real too; **`AnimationBlinkMon` stays a STUB** because its
      body loops over `AnimationHideMonPic` / `AnimationShowMonPic`, which are
      themselves Stage 4 mon-pic stubs — its lifetime field now says Stage 4
      rather than Stage 3. So blink dispatches and plays its sound but does not
      yet hide/show the pic.
      Two things measured while doing this, both worth keeping:
      * **pret does NOT exit `PredefShakeScreenVertically` with `rWY = 0`.**
        Traced at b=8, the xor-walk leaves `rWY = 1`; pret is saved by clearing
        `wDisableVBlankWYUpdate`, which lets VBlank rewrite `rWY` from `hWY` the
        next frame. `H_SCY` has no backing shadow — it IS what
        `commit_shadow_regs` copies out — so the port must park it at 0
        explicitly or the canvas stays 1px off forever. That store has no pret
        counterpart and must not be "simplified" away.
      * `PlayApplyingAttackAnimation`'s `jp hl` becomes `jmp [table + ecx*4]`
        (the table is `dd`, so the index scales by 4, not pret's 2). faithdiff
        reports `- DROPPED hl (jp)` and the six targets carry no graph edge —
        the documented indirect-dispatch blind spot, same as
        `SpecialEffectPointers`.
      Two false `- DROPPED` findings during this stage (`FlashScreenUnused`,
      `AnimationShakeScreenHorizontallySlow`) were first "fixed" by contorting
      the assembly into `jne <skip>` + `jmp`. That was backwards: the bug was in
      `tools/faithdiff`, whose port-side regex counted no conditional jumps while
      its pret-side one counted `jp z,`/`jr nz,`. Tool fixed in a separate commit;
      both routines reverted to the direct conditional form. Note the earlier
      diagnosis blaming `update_label_db` was wrong — that scanner already
      handled Jcc and the dependency graph never lost the edges.
- [x] Per-row offset HAL in ppu.asm (default-off fast path; compositor_perf
      constraints) + `AnimationWavyScreen` / `WavyScreen_SetSCX` /
      `WavyScreenLineOffsets`. DONE 2026-08-08, maintainer visual pass given on
      `ANIM=PSYWAVE` ("looks good, honestly better than the base game").
      `g_row_xoff` / `g_row_xoff_on` follow the `g_obj_clip` ownership model:
      default is the identity, the animation arms and clears it. Cost is
      per-ROW, never per-pixel — the `rep movsd` is untouched.
      The only behavioural difference is the **left-edge clamp**: GB `rSCX`
      wraps a 256px torus, `bg_surface` is a flat 384px row, so an unclamped
      negative source X samples the previous row and tears. Reachable on every
      negative half-cycle (table reaches -2, `bg_scx` is 0 in battle).
      It reads better than the original for two incidental reasons worth
      knowing: no H-blank timing jitter (pret's per-scanline `rSCX` writes race
      the PPU), and it covers the full 320x200 canvas rather than 160x144.
- [x] Gate: faithdiff; battle tier green; demo sign-off on flash (Thundershock
      class), shake, and Psychic wave. **MET 2026-08-08.** faithdiff clean on all
      Stage 3 labels bar four justified findings (two `GetPredefRegisters` drops
      from the direct-call convention, `PlayApplyingAttackAnimation`'s `jp hl`
      indirect dispatch, and `WavyScreen_SetSCX`'s absent H-blank spin);
      `lint_pret_labels` 0 both modes; `static_gate` PASS 5/5; 17/17 goldens.
      Maintainer visual sign-off on all three families:
      `ANIM=PSYWAVE` (wavy), `ANIM=GROWL` and `ANIM=HYPER_BEAM` (flash + shake).
      **What that sign-off does and does not cover** — worth stating so nobody
      later reads it as more than it is. GROWL/HYPER_BEAM drive their REAL
      animation streams (`SE_DARK_SCREEN_PALETTE` / `SE_DARK_SCREEN_FLASH` /
      `SE_RESET_SCREEN_PALETTE`, and Hyper Beam's
      `FlashScreenEveryFourFrameBlocks`) through the production interpreter on
      shipped Tier-1 data, so the flash family is observed end to end. The shake
      observation proves the `AnimationTypePointerTable` dispatch and the
      `H_SCX` displacement, but the demo harness SEEDS `wAnimationType = 3`
      itself — that a real battle sets `wAnimationType` is established
      statically (three writes in `effects.asm`, and `MoveAnimation` calls
      `PlayApplyingAttackAnimation`), not observed at runtime. One inferred
      link, evidenced; not a hole, and not full production coverage either.

### Stage 4 — mon-pic + OAM particle families

- [x] Slides: `AnimationSlideMonUp/Down/Off`, `_AnimationSlideMonUp/Off`,
      `AnimationSlideEnemyMonOff`, `AnimationSlideMonDownAndHide`,
      `AnimationSlideMonHalfOff`; retire `SlideDownFaintedMonPic` stub (pret
      core.asm label — body lands per pret placement).
      **Stage 4b DONE 2026-08-08 for seven of the nine:** `AnimationSlideMonUp`,
      `_AnimationSlideMonUp`, `AnimationSlideMonDown`, `AnimationSlideMonOff`,
      `_AnimationSlideMonOff`, `AnimationSlideEnemyMonOff`,
      `AnimationSlideMonHalfOff` — five stubs retired, faithdiff clean on all
      seven, lint 0 both modes, pgate 17/17 with mask-hit counts byte-identical
      to the 4a run in every scenario.
      New WRAM: `wSlideMonDelay` $D08A and `wSlideMonUpBottomRowLeftTile` $D09E
      (sym-measured; both land on pret's own union bytes, reproduced not
      introduced — see the notes in `gb_memmap.inc`).
      `AnimationSlideMonDownAndHide` CLOSED in Stage 4d (with `wTempPic` and
      `CopyTempPicToMonPic`). `SlideDownFaintedMonPic` CLOSED in Stage 4g: body
      in the port's `core.asm` mirror, `SevenSpacesText` **generated** into
      `assets/battle_core_runtime_strings.inc` via `gen_runtime_strings.py`, and
      both faint call sites now do the `BCOORD` setup they had been skipping
      while the stub "owned its own no-op geometry". faithdiff clean, no
      findings. **This box is now closed.**
- [x] Hide/show + tilemap helpers: `AnimationHideMonPic`,
      `AnimationHideEnemyMonPic`, `AnimationShowMonPic`,
      `AnimationShowEnemyMonPic`, `ClearMonPicFromTileMap`,
      `GetMonSpriteTileMapPointerFromRowCount`, `GetTileIDList`, `CopyTileIDs`,
      `CopyTileIDs_NoBGTransfer`, `CopyTileIDsFromList`, `CopyPicTiles`,
      `CopyDownscaledMonTiles`, `AnimCopyRowLeft`, `AnimCopyRowRight` (all
      BCOORD-projected, `; PROJ` tagged).
      **DONE 2026-08-08 (Stage 4a).** Also retired `AnimationBlinkMon`, whose
      stub existed only because those two callees did not — so blink now really
      hides and shows the pic. Tier-1 carrier `dos_port/src/data/tilemaps.asm`
      (`TileIDListPointerTable` + the ten `.tilemap` blobs, hand-written `dd`
      table per the `MoveEffectPointerTable` precedent); `TILEMAP_*` /
      `NUM_TILEMAPS` generated; `hBaseTileID equ 0xFF8B` added (sym-measured;
      the $FF8B union with `hROMBankTemp` is pret's own ordering, not a clash).
      **Row size changed** from pret's 3 bytes (`dw` + `dn`) to 5
      (`dd` + `db (h<<4)|w`), so `GetTileIDList` indexes by 5.
      One `DEVIATION{class=projection}`: `ClearMonPicFromTileMap` takes a full
      address in ESI, because `BCOORD(1,5)` is `W_TILEMAP+331` and pret's 8-bit
      `A` offset cannot reach it. Gate: build 0; lint 0 both modes; faithdiff
      clean bar two justified `GetPredefRegisters` drops (the port's
      direct-predef-call convention, both `DEVIATION{class=HAL}`-annotated);
      pgate 17/17 (`battle_intro` = 360 tilemap cells / 384 VRAM slots / 40 OAM
      entries / 13 WRAM regions OK, no mask added).
      **The goldens prove no regression, NOT execution** — no scenario in the
      battery dispatches to these routines. Runtime evidence is owed at the
      Stage 4 sign-off box.
- [x] Motion: `AnimationShakeBackAndForth`, `AnimationMoveMonHorizontally`,
      `AnimationResetMonPosition`, `AnimationBoundUpAndDown`,
      `AnimationSquishMonPic` + `_AnimationSquishMonPic`,
      `AnimationMinimizeMon` + `MinimizedMonSprite(End)`.
      **Stage 4c DONE 2026-08-08** for all but `AnimationMinimizeMon`, which
      **Stage 4d then closed** together with `wTempPic`, `MinimizedMonSprite`
      and `CopyTempPicToMonPic` (pulled forward from Stage 5). Five stubs retired;
      faithdiff clean on all six labels; lint 0 both modes; pgate 17/17 with
      mask-hit counts byte-identical to the 4b run in every scenario.
      New WRAM `wSquishMonCurrentDirection` $D09E (pret's own $D09E union).
      **faithdiff caught a real defect here, worth recording:** the first
      version ended `_AnimationSquishMonPic` with `ret`. pret ends it
      `jp Delay3` — a tail call, not a return. The `- DROPPED Delay3 (jp)`
      finding was the tool doing exactly its job; the fix was the code, not a
      suppression.
- [ ] Particles: `AnimationSpiralBallsInward` + `SpiralBallAnimationCoordinates`,
      `AnimationShootBallsUpward` + `_AnimationShootBallsUpward` +
      `AnimationShootManyBallsUpward` + `UpwardBallsAnimXCoordinates*Turn`,
      `AnimationLeavesFalling`, `AnimationPetalsFalling`,
      `AnimationFallingObjects` + `FallingObjects_*` (6 labels + 2 data),
      `AnimationWaterDropletsEverywhere` + `_AnimationWaterDroplets`.
- [~] HUD shake + OAM helpers: `AnimationShakeEnemyHUD`,
      `ShakeEnemyHUD_ShakeBG`, `ShakeEnemyHUD_WritePlayerMonPicOAM`,
      `BattleAnimWriteOAMEntry`, `InitMultipleObjectsOAM`, `Func_79929`.
      **DONE 2026-08-08 for five of the six** (`BattleAnimWriteOAMEntry` /
      `InitMultipleObjectsOAM` in Stage 4e; the three HUD-shake labels in 4g).
      `Func_79929` is genuinely BLOCKED: its body calls `AnimationFlashMonPic`
      -> `ChangeMonPic`, which Stage 5 owns. Left stubbed on purpose.
      **`AnimationShakeEnemyHUD`'s mechanism does not transfer, and this is the
      one Stage 4 decision a reviewer should look at first.** On the GB the
      battle screen IS the window layer, so pret slides the window down to cover
      everything below the enemy HUD with a pixel-identical copy, lifts the back
      pic into OAM, and jiggles `rSCX` — only the top 7 rows move. In this port
      the battle screen is on the BG layer and the window is descriptor-driven
      (`g_windows`), while `H_WY` is a legacy dialog-open flag whose gate
      compares against `RENDER_H` (200), so pret's `hWY` writes of 144/56/0
      would be meaningless at best and would confuse `sync_dialog_window` at
      worst. **Decision (autonomous, 2026-08-08): drop the window mechanism and
      the CGB `LoadBGMapAttributes` branches, keep every other pret call, and
      realize the jolt through the Stage 3c per-row displacement HAL restricted
      to the enemy-HUD rows** (canvas rows 24..79 = GB tile rows 0-6 under the
      +3-row projection), with the back-pic OAM lift kept exactly as pret wrote
      it so the pic still does not shake. Two `DEVIATION{class=HAL}` record it.
      faithdiff: 11 pret / 11 port calls, 10 matched; findings are the dropped
      `LoadBGMapAttributes` + `[hWY]`, and the added `PublishBattleAnimOAM` +
      `ShakeEnemyHUD_SetHUDRows`. **If the maintainer disagrees, this is one
      revertable commit.**
- [~] Gate: faithdiff; battle tier green; demo sign-off on Razor Leaf, Surf,
      Teleport, Minimize, Sing class representatives.
      **Static + runtime halves MET 2026-08-08; the visual half is OWED.**
      faithdiff justified on every Stage 4 label; lint 0 both modes; static_gate
      PASS 5/5 per commit; pgate 17/17 at each increment with per-scenario
      mask-hit counts byte-identical across 4a->4e.
      **Runtime evidence exists and is decomposed** (docs/translation_log.md,
      "Stage 4: RUNTIME evidence"): headless `DEBUG_ANIM_DEMO` runs of the REAL
      shipped streams for `TELEPORT` (`SE_SQUISH_MON_PIC` +
      `SE_SHOOT_BALLS_UPWARD`) and `MINIMIZE` (`SE_SPIRAL_BALLS_INWARD` +
      `SE_MINIMIZE_MON`) against a `POUND` baseline. TELEPORT changes exactly
      **49** `wTileMap` cells, forming a 7x7 block at canvas cols 11-17 / rows
      8-14 = GB (1,5)-(7,11) — i.e. `BCOORD(1,5)`, the player mon-pic origin,
      at `PIC_WIDTH * PIC_HEIGHT`. That witnesses execution AND that the
      projection is right. MINIMIZE changes 351 `vram_tiles` bytes, so the
      relocated `wTempPic` round-trips through `CopyTempPicToMonPic`.
      STILL OWED: maintainer visual sign-off; ball-pillar PLACEMENT is
      unverified (only "differs from POUND"); the slides, shake-back-and-forth
      and blink were not exercised — `DOUBLE_TEAM` cannot be a demo target
      because `gb_constants.inc` has no `DOUBLE_TEAM` equ (pre-existing
      move-constant gap, unrelated to this plan).

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
