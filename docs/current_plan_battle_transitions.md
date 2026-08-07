# Current Plan: Battle Transition Animations (overworld → battle)

**STATUS 2026-08-07 (session r-f0cc803b561d): Stages 1–6 IMPLEMENTED AND LANDED; Stage 7 verification run this session.**
`battle_transitions.asm` (all 8 effects + selectors + prologue), the core.asm wrapper, the
init_battle.asm splice, `dungeon_maps.asm`, the arc generator + `battle_transition_arcs.inc`,
and the WRAM vars are all in the tree. Verified: build green, `lint_pret_labels` 0 both modes,
faithdiff justifications recorded in the landing commit, scenario 51 `trainer_battle_route`
PASSES goldencheck with the transition on the production path, and the maintainer visually
approved all 8 animations via the new interactive `DEBUG_TRANSITION_DEMO=1` harness
(debug_dump.asm `RunTransitionDemo` — cycles all 8 over the live overworld; also empirically
confirmed the §Blockers W_TILEMAP dependency: `RefreshCollisionTileMap` refreshes the snapshot
every step on the production path). Remaining tail: per-transition state-checkpoint scenarios
(§6 battle_completion Stage 5 umbrella) stay open.

Scoped 2026-08-07 (session r-f4cc, seedlet); fully modeled + presolved 2026-08-07 (session
r-0a1227c2f63c). Goal: port the pret battle-transition animations
(`engine/battle/battle_transitions.asm`, 37 labels) and their wrapper
`DoBattleTransitionAndInitBattleVariables` end-to-end, re-parameterized for the port's 40×25
canvas per the maintainer's 2026-08-07 ruling: **adjust the geometry, do not project/letterbox
from 20×18**.

Everything marked *(measured)* below was gathered or simulation-verified in the planning session
(2026-08-07). The simulations implemented pret's exact algorithms (including the
CopyData src/dst swap semantics and the outward-spiral FSM), validated them against 20×18 GB
behavior first, then derived the 40×25 parameters. Re-run cheaply if in doubt — every claim
names its check.

Skill routing for the implementing session: `asm-translation` + `faithfulness-review` for every
routine (all pret-labeled), `project-conventions` for the arc-table generator / BUG tag / data
files, `build-and-debug` for pilots, dumps, and goldens.

---

## 1. End-to-end battle-intro model *(measured)*

### pret chain (spec)

1. `NewBattle` (`home/overworld.asm:324`) — gated on `BIT_NO_BATTLES` — `farjp InitBattle`.
   Trainer path: `DisplayEnemyTrainerTextAndStartBattle` (`home/trainers.asm:161-175`) sets
   `hSpriteIndex` from `wSpriteIndex` (:167-168) — the value `BattleTransition` later uses to
   spare the trainer's OAM block.
2. `InitBattleCommon` (`engine/battle/init_battle.asm:25`): push `wMapPalOffset` +
   `wLetterPrintingDelayFlags`, kill text delay, then `InitBattleVariables` (:32), whose tail is
   `jpfar PlayBattleMusic` — **battle music starts BEFORE the wipe, over the overworld view**.
3. Opponent data: trainer `GetTrainerInformation` + `ReadTrainer` (:37-38); wild
   `LoadEnemyMonData` (:63).
4. **`DoBattleTransitionAndInitBattleVariables`** — the ONLY two callers are
   `init_battle.asm:39` (trainer) and `:64` (wild). Full body (`core.asm:6333-6365`):
   link-battle branch (never taken in the port) → `DelayFrame` → `predef BattleTransition` →
   `LoadHudAndHpBarAndStatusTilePatterns` → `hAutoBGTransferEnabled=1` →
   `wUpdateSpritesEnabled=$ff` → `ClearSprites` → `ClearScreen` → `hAutoBGTransferEnabled=0` →
   `hWY=rWY=hTileAnimations=0` → zero `wPlayerStatsToDouble`(5 bytes) + `wPlayerDisabledMove`.
   **The transition animates over the LIVE overworld BG + OAM; all teardown follows it.**
5. Enemy pic → tilemap (:47/:97), `_InitBattleCommon` (:100): `SET_PAL_BATTLE_BLACK` →
   `SlidePlayerAndEnemySilhouettesOnScreen` (core.asm:9-105; loads font + HUD tiles INSIDE
   itself, does the rSCX raster slide) → `StartBattle` (:130).

### port chain today (`dos_port/src/engine/battle/init_battle.asm`)

`InitBattleCommon` :159 / `InitWildBattle` :180 → font bit + `LoadFontTilePatterns` +
`LoadTextBoxTilePatterns` (:164-166 / :183-185 — **destroys overworld tiles before any
transition could show them**) → `InitBattleCanvas` :200-280, which is a scattered out-of-order
copy of pret's post-transition teardown: `InitBattleVariables` :205 (music), `ClearSprites` +
`W_UPDATE_SPRITES_ENABLED=0` :223-226, view-ptr save/zero :249-251 (the overworld→flat-canvas
switch), scroll zeroes :252-255, `hTileAnimations=0` :265, `hide_window` :266, HUD tile loads
:270-272, canvas blank :276-279. The slide-in is the bespoke `SlideBattlePicsIn`
(`src/home/pics.asm:553`, declared software-native DEVIATION) — **out of scope for this plan**.

**Two battle-entry paths (load-bearing for goldens):**
- Production: `InitBattle` → `InitBattleCommon`/`InitWildBattle` (OverworldLoop poll; also
  harness gates 44/45/46 via direct `call InitBattle`, and scenario 51).
- Harness shortcut: direct `call InitBattleCanvas` (`debug_dump.asm:1840, 2375, 2565` —
  scenarios 15 battle_intro, 14 battle_menu, 16 move_selection). **These bypass the transition
  by construction under the splice below** — which is what keeps the frame-300 dumps green.

---

## 2. Splice spec (exact)

New mirror file `dos_port/src/engine/battle/battle_transitions.asm` (mandatory path per the
mirror rule); wrapper `DoBattleTransitionAndInitBattleVariables` in the port's
`src/engine/battle/core.asm` mirror position. In `init_battle.asm`:

- [ ] Hoist `call InitBattleVariables` out of `InitBattleCanvas` (:205) to before :164
      (trainer) and :182 (wild) — restores pret `InitBattleCommon:32`, keeps
      music-before-transition.
- [ ] Insert `call DoBattleTransitionAndInitBattleVariables` after `ReadTrainer` (:172) and
      after `LoadEnemyMonData` (:187) — pret's exact two call sites.
- [ ] Move `LoadFontTilePatterns`/`LoadTextBoxTilePatterns` + `InitBattleCanvas` to AFTER the
      transition (pret loads fonts inside the slide-in, core.asm:18-19), and move
      `ClearSprites` + `W_UPDATE_SPRITES_ENABLED=0` (:223-226) after it too — today they would
      destroy the trainer sprite the transition must keep frozen on screen.
- [ ] Transition entry performs the flat-canvas switch (replaces pret's implicit "BG is already
      a tilemap"): save + zero `W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR` (as :249-251 does), zero
      `H_SCX/H_SCY/IO_SCX/IO_SCY`, `hide_window`, `hTileAnimations=0`. `W_TILEMAP` is already
      maintained by `LoadCurrentMapView`; the wipe operates on it directly.
- [ ] Stage-1 build verifies the `W_TILEMAP` snapshot is current and aligned at encounter
      trigger (player is at rest post-step, so fine scroll should be neutral; annotate the
      1-frame fine-scroll pop as DEVIATION class=projection if visible).

---

## 3. Render/HAL integration facts *(measured, file:line)*

- **`hAutoBGTransferEnabled` is inert in the port** — written, read by nothing; the vblank
  transfer was retired (`dos_port/src/home/vblank.asm:135-150`). Keep pret's writes as
  vestigial bookkeeping (established pattern). `BattleTransition_TransferDelay3` ports as the
  two writes + `Delay3`. Pacing comes entirely from `DelayFrame` — `render_bg` is called ONLY
  from `DelayFrame` (`vblank.asm:210`), so mid-loop tilemap writes are never visible early and
  every `DelayFrame` publishes the whole canvas. pret's batching semantics fall out for free.
- **Tile id `$ff` maps exactly to pret's vChars1 tile $7f ($8FF0)** under the port's signed
  $8800 addressing (`build_id_cache_lut`, `ppu.asm:559-562`). `LoadBattleTransitionTile` ports
  verbatim on the `LoadSmokeTile` precedent (`dust_smoke.asm:146-150`):
  `incbin "../gfx/overworld/battle_transition.2bpp"` (16 B, already on disk, unreferenced) +
  `CopyVideoData` to `GB_VFONT + 0x7F*TILE_SIZE` (CopyVideoData arms `g_tilecache_dirty`
  itself). No collision with the BG-animator tiles ($9030/$9140). Note the later font load
  overwrites $8FF0 on BOTH sides — this is why golden VRAM slot $FF passes today; verify it
  stays green after landing.
- **`W_TILEMAP` ($C3A0, 1000 B, stride 40) is bordered below by `W_SHADOW_OAM`, which ends
  exactly at $C3A0** — an OOB underflow corrupts shadow-OAM slot 39 (DMA'd to real OAM every
  frame). Above it: ~850 unclaimed bytes ($C788-$CADB). The outward-spiral bounds guard (§4) is
  therefore mandatory, not cosmetic.
- **OAM freeze hazard + resolution** (`vblank.asm:296-316`, `ppu.asm:248-251, 928-933`):
  `wUpdateSpritesEnabled=$ff` freezes `PrepareOAMData` AND skips the shadow→`GB_OAM` DMA, so
  pret's clear-shadow-after-freeze never propagates in the port. `render_sprites` draws entries
  with index < `spr_oam_valid`, positioned from `spr_dos_sx/sy`, tile/attr from `GB_OAM`.
  Port realization: keep pret's spare-block scan verbatim (`hSpriteIndex` is already set at
  trainer entry — `dos_port/src/home/trainers.asm:390-391`; pret's `swap a / cp l`
  low-address-byte trick becomes a block-INDEX compare, DEVIATION class=data-model) and the
  shadow `FillMemory` clears (bookkeeping), PLUS set `spr_dos_sy[i]` off-canvas for entries
  4..39 outside the spared block (DEVIATION class=HAL — stands in for the vblank DMA pret
  implicitly gets). Acceptance: NPCs vanish, player + engaging trainer persist frozen, no
  garbage sprites (test on a map with ≥2 NPCs).
- **Window**: the battle screen has no window layer (`hide_window`, `init_battle.asm:266`);
  pret's `hWY=0` GB double-tilemap trick is inapplicable — annotate class=HAL and call
  `hide_window` at transition entry (also kills a stale dialog overlay that would float above
  the wipe).
- **`BattleTransition_BlackScreen`** = the `GBPalWhiteOut` shape (`palettes.asm:145-151`) with
  $ff; `UpdateCGBPal_BGP/OBP0/OBP1` all exist (all = `g_pal_dirty=1`). BGP-only effects cost a
  DAC reprogram, no tile re-decode — the flash/blackout steps are essentially free.
- **Primitives**: `Delay3` / `DelayFrame` / `DelayFrames`(BL) / `CopyData`(ESI src, EDX dst,
  BX count; advances ESI/EDX) / `FillMemory`(ESI, BX, AL) all exist. Port count-0 writes 0
  bytes, not pret's 256 — every transition call site passes a nonzero count, but keep the
  audit habit.
- **Coords**: `hlcoord`/`decoord` macros (`include/coords.inc`, stride 40, W_TILEMAP base).
  Transitions cover the FULL 40×25 canvas — do NOT use the battle-UI `BCOORD` (+10,+3)
  projection.
- **WRAM vars** (none exist yet; `include/gb_memmap.inc` is the sole definition file):
  `wBattleTransitionCircleScreenQuadrantY/X`, `wBattleTransitionCopyTilesOffset`,
  `wInwardSpiralUpdateScreenCounter`, `wBattleTransitionSpiralDirection` ($CD47) go on the
  established $CD3D union scratch lane with the usual "modal screen, nothing else live"
  justification comment. `wOutwardSpiralTileMapPointer` = $D099, stored as a **16-bit GB
  offset** (the `wMenuCursorLocation` precedent, `window.asm:241-245`; pret's h/l split becomes
  one word store — note in a comment). `wOutwardSpiralCurrentDirection` in its pret union slot.
- **`DungeonMaps1/2`**: unported; add the data mirror `dos_port/src/data/maps/dungeon_maps.asm`
  (map-id constants, not text — hand-written `db` of named constants is within the two-tier
  rule).

---

## 4. Per-effect 40×25 parameterization *(ALL simulation-verified)*

Canvas 40×25 vs GB 20×18. Two structural traps: **H is now odd**, and **W−H = 15** (GB's 2).
Several pret literals were dimension collisions — write every derived count as its formula.

### Shared building blocks

- [ ] `BattleTransition_CopyTiles1` inner count = **`(SCREEN_HEIGHT−1)/2` = 12** (pret's
      hardcoded `ld c, 8`; on GB `H/2−1 == (H−1)/2 == 8` — collision).
- [ ] `BattleTransition_CopyTiles2` outer count = **`SCREEN_WIDTH/2−1` = 19** (pret's
      `ld c, SCREEN_HEIGHT/2` = 9 was really W/2−1 — collision). Inner column length =
      `SCREEN_HEIGHT` = 25.
- [ ] Both keep pret's src/dst swap semantics (after each copy: new_src = old_dst + offset,
      new_dst = old_src; final fill lands at the last source row/column). The simulations used
      these exact semantics.

### Shrink (idx 101) — collapse toward center

- [ ] Calls: T1(src 0,11 → dst 0,12, offset −2 rows); T1(src 0,13 → dst 0,12, +2 rows);
      T2(col 18 → 19, −2); T2(col 21 → 20, +2). Rows converge on single center row 12 (odd H;
      bottom half overwrites row 12 after top each iteration — cosmetic, matches pret's
      center-pair behavior as closely as odd height allows). Cols converge on pair 19/20.
- [ ] Outer loop: **20 iterations** (pret 9). Columns step every iteration; rows step only on
      the Bresenham-12/20 schedule **{1,3,4,6,8,9,11,13,14,16,18,19}** so both axes reach
      center together (the maintainer's decoupled-axis requirement). Delay: `DelayFrames 3`
      per iteration (pret 6×9=54f → 60f) + `DelayFrames 10` tail after `BlackScreen`.
- [ ] *(measured)* Simulated with exact swap semantics: screen all-black exactly at iteration
      20; the same simulator reproduces GB all-black at 9/9. Endgame: a 1-row sliver at row 12
      erodes from both ends — the intended shrink-to-a-point look.

### Split (idx 111) — split from center outward

- [ ] Calls: T1(src 0,23 → dst 0,24, −2 rows); T1(src 0,1 → dst 0,0, +2 rows);
      T2(col 38 → 39, −2); T2(col 1 → 0, +2). Black seeds at center rows 12/13, cols 19/20.
- [ ] Outer: **20 iterations**; rows on Bresenham-13/20 **{1,3,4,6,7,9,10,12,13,15,16,18,19}**;
      per-iteration delay = the `TransferDelay3` equivalent only (3f; pret 6×9 → 60f) +
      10-frame tail. *(measured)* all-black exactly at iteration 20.

### VerticalStripes (idx 110)

- [ ] Verbatim translation scales — counts are already `SCREEN_WIDTH/2` (=20 per row-pass) and
      `SCREEN_HEIGHT` (=25 outer); `decoord 1, 24` for the bottom-up odd-column walker.
      25 iters × 3f = 75 frames (GB 54; accepted — per-step pacing kept faithful).

### HorizontalStripes (idx 100)

- [ ] **Two columns per side per iteration** (cols 2i, 2i+1 even rows from the left; cols
      39−2i, 38−2i odd rows from the right) → 20 iterations × 3f = 60 frames = GB duration and
      the same per-step coverage fraction.
- [ ] Odd height: the per-column fill count splits — **13** for even-row passes (rows
      0,2,…,24), **12** for odd-row passes (pret's single `SCREEN_HEIGHT/2` no longer serves
      both). Parameterize `BattleTransition_HorizontalStripes_`.

### Spiral — inward (idx 001/011 when enemy weaker)

- [ ] pret's `inc c`/`dec c` leg arithmetic silently encodes **W−H=2**; on 40×25 it breaks
      (right-leg count would come out 26, needs 39). Generalize with `D = SCREEN_WIDTH −
      SCREEN_HEIGHT` = 15: first leg down `H−1`; per lap: `c += D−1` (right leg), `c −= D`
      (up), `c += D−1` (left), `c −= D`, loop while `c > 0` **signed**.
- [ ] **Zero-count legs must be skipped** (guard `test ecx,ecx / jz`): the final degenerate lap
      has an up-leg of 0 — pret's 8-bit `dec c` idiom would loop 256×. DEVIATION
      class=projection for the D-generalization + guard.
- [ ] `wInwardSpiralUpdateScreenCounter` init 7 → **19** (≈ same cells-per-frame rate:
      1000/19 vs 360/7).
- [ ] *(measured)* Simulator reproduces pret on GB exactly — 359/360 cells written, (8,9) left
      unwritten (BlackScreen's palette covers it, as on hardware). Port: 1013 writes, 1000/1000
      coverage, 0 out-of-bounds, 53 delay events ≈ 159 frames (GB 153).

### Spiral — outward (idx 001/011 when enemy ≥3 levels higher)

- [ ] *(measured)* pret's FSM misbehaves at screen edges even on GB: 19 OOB writes (into the
      bytes below/above wTileMap) and only 341/360 cells filled at its 360-step cutoff —
      BlackScreen hides the gap on hardware. Raw on 40×25 it is far worse: 800/1000 filled,
      200 OOB writes — and in the port those land in **shadow OAM**. Do not port unguarded.
- [ ] Port: **bounds-guarded FSM** — an out-of-bounds neighbor read reports "not $ff" (forcing
      a turn, matching GB's underflow-side behavior where cleared shadow OAM reads 0), and
      out-of-bounds writes are dropped. DEVIATION class=projection citing both measurements.
- [ ] Parameters: start `hlcoord 20, 13` (pret 10,10 = W/2, H/2+1), initial direction 3,
      **b = 125 frames × c = 12 writes/frame = 1500 steps** (pret 120×3=360). *(measured)*
      full 1000/1000 coverage at step 1469 (margin 31); 125 frames ≈ GB's 120.
- [ ] `wOutwardSpiralTileMapPointer` as 16-bit GB offset (§3).

### Circle (idx 010) / DoubleCircle (idx 000) — regenerated arc tables

- [ ] **Tier-1 generated data**: `tools/generators/gen_battle_transition_arcs.py` →
      `assets/battle_transition_arcs.inc`, wired into `make assets`. Never hand-author the
      bytes.
- [ ] Generator algorithm *(prototyped + verified this session)*: **10 wedges per half** (keeps
      GB's step count and timing — `Circle_Sub1`'s count stays 10 as a named constant
      `HALF_CIRCLE_STEPS`, NOT `SCREEN_WIDTH/2`: that was a 20×18 collision). Wedge k = angle
      bin [k·18°, (k+1)·18°) sweeping counterclockwise from 3 o'clock; angles computed in
      DISPLAY space (cell y scale ×1.2 — 320×200 on a 4:3 monitor) about center (20.0, 12.5),
      so the wipe looks circular on screen. HalfCircle1 = bins 0-9 (top), HalfCircle2 = 10-19
      (bottom), paired k / k+10 for DoubleCircle's two opposed arms.
- [ ] Encoding = pret's `Circle_Sub3` format, unchanged: per row `run` byte then `skip|0`
      byte, `$ff` terminator; RIGHT quadrant writes incrementing / skips decrementing (LEFT
      mirrored); rows ordered edge→center; half 1 steps +SCREEN_WIDTH, half 2 −SCREEN_WIDTH.
      Entry struct: quadrant byte + 32-bit data pointer + 16-bit start coord (port stride
      replaces pret's `ld bc, 5`).
- [ ] *(measured)* Prototype output: all 20 wedges encodable (rows contiguous, one interval
      per row, all skips ≥ 0, all bytes ≤ 40), union exactly 1000/1000 cells, 412 data bytes.
      The generator MUST embed the Sub3 emulator as a self-check: emulate every entry, assert
      per-wedge cell sets match and total coverage is 1000.
- [ ] `BattleTransition_FlashScreen_` + `FlashScreenPalettes`: bytes
      `$F9,$FE,$FF,$FE,$F9,$E4,$90,$40,$00,$40,$90,$E4` + `db 1` terminator (pret's packed
      `dc` rows, precomputed; sanity anchor: `dc 3,2,1,0` = $E4 = normal BGP). 3 passes × 12
      × 2f = 72 frames, unchanged.

### Selection logic + prologue

- [ ] `GetBattleTransitionID_{WildOrTrainer,CompareLevels,IsDungeonMap}` verbatim
      (`wCurOpponent`/`wPartyMon1HP`/`wCurEnemyLevel`/`wCurMap` all modeled; `wLinkState`
      exists — link branch never taken, keep it faithful).
- [ ] **Preserve the documented bug** (`docs/bugs_and_glitches.md:37` "Battle transitions fail
      to account for scripted battles"): with no party (the Oak-intro scripted Pikachu battle),
      `GetBattleTransitionID_CompareLevels.faintedLoop` scans past party HP into
      `wRivalName+6`-equivalent memory. Keep faithful; add `BUG{...}` annotation (all five
      fields) + `%if BUG_FIX_LEVEL >= 2` guard bounding the scan by `wPartyCount`. (Same
      empty-party family as the fixed `AnyPartyAlive` wrap, commit 7deceb6f.)
- [ ] `BattleTransition` prologue: Delay3 → (hWY: see §3, `hide_window`) →
      `wUpdateSpritesEnabled = $ff` → DelayFrame → OAM spare-block clear (§3 realization) →
      Delay3 → `LoadBattleTransitionTile` → dispatch via `BattleTransitions` table (8 × 32-bit
      entries in the port).

### Timing summary (GB → port frames, per-iteration constants tunable)

| effect | GB | port |
|---|---|---|
| InwardSpiral | ~153 | ~159 |
| OutwardSpiral | 120 | 125 |
| Circle (incl. 72f flash) | 132 | 132 |
| DoubleCircle (incl. flash) | 102 | 102 |
| HorizontalStripes | 60 | 60 |
| VerticalStripes | 54 | 75 |
| Shrink | 54+10 | 60+10 |
| Split | 54+10 | 60+10 |

Annotate geometry deltas as DEVIATION class=projection, pacing deltas class=timing.

---

## 5. Staging

- [ ] **Stage 1 — skeleton (cheapest visible win):** wrapper + `BattleTransition`
      prologue/dispatch + `LoadBattleTransitionTile` + `BlackScreen`-only body (fill W_TILEMAP
      with $ff, palette $ff, delays) at the real splice (§2). Proves snapshot / $ff tile / OAM
      freeze / timing end-to-end with zero geometry math. Pilot:
      `make -C dos_port run DEBUG_START_MAP=0x0C DEBUG_SEAM_KEEP_BATTLES=1 DEBUG_SEED_PARTY=1`
      (Route 1 grass; KEEP_BATTLES is mandatory — the NO_BATTLES trap). Deterministic photos:
      `DEBUG_AUTOKEY=1 AUTOKEY_APRESS=1 AUTOKEY_DUMP_ON_BATTLE=1 AUTOKEY_BATTLE_DUMP_DELAY=N`
      (the state-gated dump precedent, Makefile:217-235 — fixed frames can't catch the window
      through ~150f boot drift).
- [ ] **Stage 2 — stripes** (vertical verbatim, horizontal 2-col).
- [ ] **Stage 3 — Shrink + Split** (schedules in §4).
- [ ] **Stage 4 — spirals** (D-generalized inward; bounds-guarded outward) + WRAM vars.
- [ ] **Stage 5 — Circle + DoubleCircle** (arc generator) + FlashScreen.
- [ ] **Stage 6 — selection logic** + `dungeon_maps` data + scripted-battle BUG tag + trainer
      OAM spare verification (2-NPC map).
- [ ] **Stage 7 — gates + goldens closure** (§6).

---

## 6. Verification & gates

- [ ] Mirror path `dos_port/src/engine/battle/battle_transitions.asm`; add to
      BATTLE_SRCS/LINK_SRCS (Makefile:1887-1940). translation.db updates by rescan — no manual
      registration; `label_status` flips `missing → translated` on its own.
- [ ] `fidelity_gate` faithdiffs every label in the file. Expected ADDED HAL calls
      (`hide_window`, spr_dos writes; `CopyVideoData` covers the tile-cache rule itself) —
      justify in commit message or `faithdiff_suppress.json` with why-strings.
      `lint_pret_labels` + `--strict-claims` stay 0; `static_gate` two-way ratchet at zero.
- [ ] DEVIATION/BUG annotations: all five fields, classes projection / timing / HAL /
      data-model only; no `;` or `}` inside values.
- [ ] **Golden impact** *(measured)*: scenarios 14/16 (`AUTOKEY_DUMP_FRAME=300`) stay safe
      ONLY because the §2 splice bypasses the harness `InitBattleCanvas` entry — if anyone
      later moves the transition into `InitBattleCanvas`, those two break first. 44/45/46
      (state-driven, direct `call InitBattle`) and 51 (`AUTOKEY_DUMP_FRAME=15000`, ~2×
      headroom; one 120-frame autokey cycle eaten) now RUN the transition — **51 becomes the
      production-path witness**. VRAM slot $FF is compared unmasked in the battle-tier
      scenarios: verify they stay green (font load overwrites the transition tile on both
      sides). Optional hardening: convert 14/16 to state-gated dumps (AUTOKEY_DUMP_ON_BATTLE
      idiom).
- [ ] Per battle_completion Stage 5: deterministic state checkpoints per selected transition,
      must-hit the selector AND each animation body; cover wild / trainer / dungeon / scripted
      inputs. A final FRAME.BIN alone is regression evidence, not execution proof.
- [ ] New golden scenario(s) need the full `scenario_manifest.json` key set +
      `golden_diff.py:SCENARIOS` + regenerated `assets/scenario_registry.inc`
      (`validate_scenarios.py` enforces).

---

## Blockers — honest answer *(re-verified 2026-08-07)*

- **No hard blocker.** Tilemap writes, DMG-palette writes, DelayFrame pacing, one $ff tile —
  every primitive exists and the geometry is presolved above with simulation evidence.
- The risk concentration shifted after presolve: the remaining risk is **integration order**
  (the §2 splice moves, the OAM freeze realization) — not math. The two former "hard cases"
  (Shrink/Split axis decoupling, arc regeneration) now have verified parameter sets and a
  prototyped generator algorithm.
- One dependency to confirm live in Stage 1 (not a blocker): W_TILEMAP holds the current
  overworld view at battle entry, fine-scroll neutral.

## Faithfulness note

All routines keep pret labels (`BattleTransition`, `BattleTransition_Shrink`, `_CopyTiles1`,
…). The 40×25 adjustments are `class=projection` DEVIATIONs; the pacing changes
`class=timing`; the OAM-publish and window substitutions `class=HAL`; the 16-bit pointer note
`class=data-model`. Arc tables are generated Tier-1 data. `docs/current_plan_battle_completion.md`
Stage 5 remains the umbrella; this document owns the detail.
