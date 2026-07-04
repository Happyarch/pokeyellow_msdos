# Current Plan: Full `engine/overworld/` Port

**Status:** Stage 0 in progress (this document written 2026-07-01; branch gate pending).
**Branch:** `overworld-port`, to be cut from `master` **after** the battle-swarm
integration merge lands. Do not start code work before the Stage 0 gate clears.

---

## Context

Port **everything** under pret `engine/overworld/` (33 files, ~5,700 lines) into
`dos_port/src/engine/overworld/`, faithfully, per CLAUDE.md conventions. Pret is
the permanent accuracy reference; every routine keeps its pret name. Sound stays
stubbed. The enlarged 40×25-tile native viewport is a sanctioned divergence.

A routine-level survey (2026-07-01, pre-merge) found: **8** pret files effectively
ported, **6** partial, **19** untouched. A line-level fidelity audit of the
"effectively ported" files found two scaffold-grade implementations and three
silent omissions (see Stage A). This plan absorbs **all** deferred overworld items
from other plans — scripted NPC movement + the Oak walk-up cutscene from
`current_plan_script_engine.md`, and the open TODO.md Phase 2 overworld items.

### Fixed decisions

- **Stub policy — faithful body, stub leaves.** Every routine's control flow is
  translated faithfully; only terminal calls into missing subsystems (menus,
  audio, battle UI) become named `TODO(faithful)` ret-stubs in `*_stubs.asm`
  files. Delete stubs as real routines land.
- **Sound stays stubbed.** `PlaySound` ret-stub exists (in
  `src/engine/battle/move_effect_helpers.asm` pre-merge — re-verify location at
  Stage 0). Add ret-stubs for `StopAllMusic`, `WaitForSoundToFinish`,
  `PlayMusic`, `PlayDefaultMusic` in a new `src/audio/audio_stubs.asm`.
- **Divergence policy.** Functional equivalence + `; PROJ` / `; TODO-HW` tags +
  `translation_log.md` entries where GB hardware died. The VRAM torus /
  `RedrawRowOrColumn` rings are **gone**: re-express VRAM-window redraws against
  `LoadCurrentMapView` / `render_bg`. Any routine writing VRAM tile data must set
  `g_tilecache_dirty`.
- **File layout.** 1:1 mirrored files for new work (pret `cut.asm` → port
  `cut.asm`). No retro-splitting of existing consolidated files. Two name
  collisions (`pathfinding.asm`, `hidden_events.asm` — the port files hold home/
  ports) are handled by **extending the existing port file** with a
  clearly-headed second section citing the engine/overworld pret source.
- **Restore pret labels.** Consolidated files get a label-rectification pass so
  each pret routine name exists as a real label (sized per file by the audit).
- **Dead code.** `unused_load_toggleable_object_data.asm` is ported check-only,
  never linked, with an `; UNREFERENCED (pret: unreferenced)` header.
- **Execution — hybrid.** Four SOLO files (judgment-heavy, interactive
  sessions): `movement.asm`, `player_animations.asm`, `update_map.asm`,
  `map_sprites.asm`. Everything else runs as SWARM waves.
- **Roles.** **Opus root agent**: issues tickets, reviews/integrates worker
  diffs, owns ALL git operations and ALL documentation (translation_log.md,
  ui_projection.md, TODO.md, this doc's checkmarks). **Sonnet workers**: one
  ticket each, on worktree copies, logic-only, **never touch git, never write
  docs** (see memories `sonnet-parallel-logic-only`,
  `swarm-workers-must-not-touch-git`; seed worktrees per
  `worktree-asset-seeding` — copy `dos_port/assets/*.inc` + `.2bpp/.pic/.1bpp`).
- **Final audit.** Stage 8 re-audits the entire surface against pret before this
  plan is archived.

---

## Coverage Matrix (pre-merge snapshot — re-verify at Stage 0)

| Status | pret files |
|---|---|
| Ported (8) | doors (in overworld.asm), emotion_bubbles (in trainer_engine.asm), ledges, tilesets (**scaffold — see Stage A**), wild_mons, map_sprites (**scaffold — see Stage A**), sprite_collisions (in movement.asm), advance_player_sprite (in overworld.asm) |
| Partial (6) | movement (scripted chain missing), auto_movement (cutscene script tables missing), player_animations (only `_HandleMidJump`, in ledges.asm), player_state (only 2 routines, in warp_check.asm), trainer_sight (accessors missing), toggleable_objects (show/hide missing) |
| Missing (19) | clear_variables, cut, cut2, daycare_exp, dungeon_warps, dust_smoke, elevator, field_move_messages, healing_machine, hidden_events (engine-side `CheckForHiddenEvent`), is_player_just_outside_map, npc_movement_2, pathfinding (`FindPathToPlayer`), push_boulder, special_warps, specific_script_flags, spinners, unused_load_toggleable_object_data, update_map |

Port-side check-only files awaiting link promotion (Makefile `HOME_CHECK_SRCS`):
`pikachu.asm`, `reload_sprites.asm`, `player_gfx.asm`, `overworld_text.asm`,
`ledges.asm`, `pathfinding.asm`, `trainer_engine.asm`.

---

## Fidelity Audit Findings (2026-07-01)

Line-level, routine-by-routine; sanctioned `; PROJ`/`TODO-HW` divergences excluded.

| Port file | Grade | Effort | Disposition |
|---|---|---|---|
| map_sprites.asm | **SCAFFOLD** | large | **SOLO (OW-A.2)** — bespoke loader replaces pret's entire sprite-set system: `InitOutsideMapSprites`, `LoadSpriteSetFromMapHeader` (VRAM slot = index-in-set), `GetSplitMapSpriteSetID`, `CheckForFourTileSprite` (4-tile sprites + Pikachu's reserved slot), `SpriteSheetPointerTable`, `LoadMapSpritesImageBaseOffset`, `wFontLoaded` half-reload — all silently absent |
| tilesets.asm (`LoadTilesetHeader`, in overworld.asm) | **SCAFFOLD** | medium | SWARM (OW-A.1) — missing tail: `hPreviousTileset` compare, `DungeonTilesets` detection, `LoadDestinationWarpPosition`, and the **`wYBlockCoord/wXBlockCoord = wYCoord/wXCoord & 1` warp-arrival alignment** (gameplay-relevant silent omission) |
| movement.asm | REORGANIZED (largely faithful) | medium | folds into SOLO OW-2.1 — two silent omissions: status-4 `Func_5357`/`Func_5288` dispatch (item-ball emerge / STAY-and-face) absent; `MakeNPCFacePlayer` missing `BIT_NO_NPC_FACE_PLAYER` guard |
| trainer_engine.asm (emotion_bubbles + trainer_sight) | FAITHFUL | small | missing accessors only → OW-1.7 |
| overworld.asm (advance_player_sprite) | REORGANIZED (sanctioned) | none | label pass only (OW-A.3) |
| ledges, doors, wild_mons, hidden_events (port), warp_check | FAITHFUL | none/small | label pass only (OW-A.3) |

### Standing rule (2026-07-04, user directive): audit EVERY pre-plan overworld port

**Any overworld-engine routine ported *before* this plan is suspect until graded.**
"Already ported weeks ago" ≠ faithful — the port has a documented habit of bespoke/
scaffold implementations that drop pret's control flow (confirmed: `tilesets`
`LoadTilesetHeader` dropped its whole tail → OW-A.1; `map_sprites`/`tilesets` graded
SCAFFOLD above; `GetTileInFrontOfPlayer` is a bespoke *subset* of pret's
`_GetTileAndCoordsInFrontOfPlayer`). So:

1. **Reuse-time check.** When any new ticket reuses/cross-refs a pre-plan routine,
   the routine's *contract AND control flow* is re-verified against pret before the
   reuse is trusted (not just its numbers). Bespoke-but-equivalent is fine if it
   preserves pret flow; bespoke-and-divergent gets a rectification ticket.
2. **Systematic sweep.** The 2026-07-01 grades above were a read-only snapshot; they
   are re-confirmed by a per-file faithfulness audit (read-only audit agents, one per
   consolidated pre-plan file: `overworld.asm`, `movement.asm`, `trainer_engine.asm`,
   `ledges.asm`, `warp_check.asm`, `wild_encounter_check.asm`, `map_sprites.asm`,
   `player_gfx.asm`, `pikachu.asm`, `reload_sprites.asm`, `overworld_text.asm`),
   grading each routine FAITHFUL / REORGANIZED-equivalent / SCAFFOLD / DIVERGENT vs
   pret. SCAFFOLD/DIVERGENT findings become rectification tickets folded into Stage A.
   This is Stage 8's line-level audit, pulled forward and made active.

---

## Cross-cutting defect this reimpl must resolve — VRAM tile-slot management (2026-07-04)

**Symptom (menus-port branch):** every menu that draws a `TextBoxBorder` (START,
options, bag/items, trainer card, …) renders with corrupted borders / "grass"
blanks / missing bottom rows in the *live* build, while each screen's `DEBUG_*`
harness renders it perfectly. Root cause is entirely VRAM tile-slot management —
the same early-bespoke tile handling this reimpl replaces — so it is recorded here
rather than fixed piecemeal in the menu code.

Two shared VRAM regions get clobbered and are not consistently reloaded:

1. **Box/border/space tiles `$79–$7F` in vChars2 (`$9000` region).**
   `LoadTextBoxTilePatterns` loads `$60–$7F` there, but the *same* slots are
   overwritten by `LoadHpBarAndStatusTilePatterns` (`$62–$7F`; party menu / battle /
   status), `LoadHudTilePatterns` (battle), and the trainer card's own tile loads —
   see the explicit warning at `src/gfx/load_font.asm:101-106`. Whatever loaded
   last wins, so a box drawn afterward takes its borders/spaces (`$7F` = space, so
   row gaps too) from stale HP-bar/HUD tiles. `LoadMapData` loads box tiles at map
   entry, so a *fresh* overworld is fine — corruption appears only after
   entering/leaving a clobbering screen (matches the reported "grass after menus").
2. **Font glyphs `$80–$8B` (letters A–L) in vFont `$8800`.** The port time-shares
   vFont with player/NPC **walk tiles** (`LoadPlayerSpriteGraphics` writes exactly
   `$80–$8B`). If walk tiles are resident when text is drawn, A–L render as sprite
   graphics. **OW-A.2's `wFontLoaded` upper-half-only reload is the pret mechanism
   that manages this** (`LoadStillTilePattern`/`LoadWalkingTilePattern`); porting it
   faithfully fixes half of this defect.

**Faithful fix direction:** pret keeps a fixed vChars layout with the box/font
tiles resident (tileset ≤ `$60` tiles at `$00–$5F`; box/extra at `$60–$7F`;
`wFontLoaded` gates the walk-tile reload so it never eats the font). Re-establish
that layout here so menus never need to reload tiles at open time. Until this
lands, the menu screens are only correct immediately after a `LoadTextBoxTilePatterns`
(hence the harnesses pass) — a targeted stopgap would be to reload
`LoadTextBoxTilePatterns` (+ `LoadFontTilePatterns` where letters are involved) at
each menu's box-draw entry, but that is a per-call-site port deviation and should be
avoided in favour of this reimpl. **Add a Stage A / Stage 8 verification item: after
the tile-management rewrite, open every menu *after* visiting the party menu /
battle and confirm box borders + blanks + letters render cleanly.**

---

## Stages

Mark items `[x]` as they complete. Every ticket below is prewritten; the root
agent issues SWARM tickets to Sonnet workers verbatim and follows SOLO tickets
interactively with the user.

### Stage 0 — Plan doc + branch gate + re-verification `[~]`

- [x] Write this document to `docs/current_plan_overworld_port.md`.
- [x] **Gate:** battle-swarm integration merged to `master` (verified: battle
      engine + `battle_audit_findings.md` + archived `pokemon_behavior.md` on
      master); `git branch overworld-port master` done (2026-07-04).
- [ ] Update cross-references (deferred until the merge lands — the working tree
      must stay clean while the merge agent runs): `current_plan_script_engine.md`
      (point its deferred Oak-cutscene/scripted-movement items here), `TODO.md`
      (~lines 236–241), CLAUDE.md "Currently active plans" list.
- [ ] **Re-verify the coverage matrix against the merged tree**: label-level diff
      of pret `engine/overworld/*.asm` globals vs `grep -rn 'global ' dos_port/src
      --include='*.asm'`. The battle swarm touched home/ promotions and stubs —
      amend the matrix, the audit table, and any ticket whose "existing symbol"
      assumptions moved (esp. `PlaySound` location, screen-buffer routines,
      `EmotionBubble` linkage).
- [x] Capture pre-work FRAME.BIN baselines: `DEBUG_BASELINE`, `DEBUG_TRANSITION`,
      `DEBUG_WALK_NORTH` renders stored (+ sha256 manifest) for regression diffs.
      (DPMI host CWSDPMI r7 restored — it was missing from the checkout, gitignored.)
      NB: `DEBUG_WALK_NORTH` skips collision by design — it is a render/transition
      oracle, NOT a collision test; collision-touching tickets need MCP live-input
      verification. The walk-north baseline was refreshed after OW-A.1 (now captures
      the correctly-enabled flower animation).

### Stage A — Fidelity rectification + pret-label restoration `[~]`

**TICKET OW-A.1: LoadTilesetHeader rectification** `[SWARM/Sonnet]` `[x] DONE 2026-07-04`
- Pret: `engine/overworld/tilesets.asm:LoadTilesetHeader` (+ `data/tilesets/tileset_headers.asm`, `DungeonTilesets`)
- Target: `dos_port/src/engine/overworld/overworld.asm` (existing routine)
- Checklist:
  - [x] Add missing tail per pret: `hPreviousTileset` compare, `DungeonTilesets` membership check (inlined, byte-verified), `wDestinationWarpID` / `LoadDestinationWarpPosition` handling (factored, pret name), and `wYBlockCoord/wXBlockCoord = wYCoord/wXCoord & 1` warp-arrival alignment
  - [x] Header fields (`grass`, `anim`): now per-tileset from inlined `TilesetGrassTiles`/`TilesetAnimations` (byte-verified vs pret); bank kept as `; TODO-HW` no-op
  - [x] `; PROJ`/`; DIVERGENCE` comments on asset-model + union divergences
  - [x] Verify: nasm clean; `make SKIP_TITLE=1` boots; pristine + transition FRAME.BIN byte-identical; walk-north +240B = correct flower-anim enablement
- **Root completion (required):** the tail regressed the render until root added the
  pret `home/overworld.asm:1813` `hPreviousTileset` snapshot in `LoadMapHeader`
  (worker-flagged F.1 — load-bearing). No spurious `wDestinationWarpID=$FF` sentinel
  added (pret resets it only post-battle; the hPreviousTileset gate is the faithful
  protector). Deferred (minor): F.2 `hMovingBGTilesCounter1` reset (needs symbol
  migration to gb_memmap.inc).
- Exit: pret tail present; alignment omission fixed; translation_log entry (root). ✓

**TICKET OW-A.2: map_sprites.asm faithful rewrite** `[SOLO #4]`
- Pret: `engine/overworld/map_sprites.asm` (all 15 routines) + `data/sprite_sets.asm`
- Target: `dos_port/src/engine/overworld/map_sprites.asm` (rewrite in place)
- Checklist:
  - [ ] Restore pret structure: `_InitMapSprites`, `InitOutsideMapSprites` (fixed outside-map sprite sets + `GetSplitMapSpriteSetID` Route-20 split logic), `LoadSpriteSetFromMapHeader` (VRAM slot = index-within-sprite-set), `ReadSpriteSheetData` + `SpriteSheetPointerTable` equivalent, `CheckForFourTileSprite` (Yellow 4-tile sprites; Pikachu's reserved 2nd slot), `LoadMapSpritesImageBaseOffset`, `LoadStillTilePattern`/`LoadWalkingTilePattern` incl. the `wFontLoaded` upper-half-only reload
  - [ ] Sprite-set data: extend `tools/gen_all_assets.py` or new generator for `data/sprite_sets.asm` → Tier-1 `assets/` inc (never hand-edit)
  - [ ] Preserve working port extensions where sanctioned (toggleable-hidden gate at load) with `; DIVERGENCE` notes
  - [ ] Regression: FRAME.BIN before/after on Pallet Town (NPC sprites identical); MCP `gb_read` of `wSpriteStateData1/2` slots 1–15
- Exit: 15 pret routine labels real; NPC rendering regression-free.

**TICKET OW-A.3: label restoration pass (mechanical)** `[SWARM/Sonnet, one worker per file]`
- Files: `overworld.asm` (advance_player_sprite labels: `_AdvancePlayerSprite` alias, doors `IsPlayerStandingOnDoorTile` — verify present), `movement.asm` (sprite_collisions labels: `_UpdateSprites`, `UpdateNPCSprite` as label into `UpdateNonPlayerSprite`, `Func_4d0a` port-or-document), `trainer_engine.asm`, `ledges.asm`, `hidden_events.asm`, `warp_check.asm`, `wild_mons.asm`
- Checklist (per file):
  - [ ] Every pret routine name folded into this file exists as a real label at the corresponding address (`PretName:` with `; pret: <file>:<label>` comment); no body restructuring beyond label insertion
  - [ ] Verify: nasm check; full build; FRAME.BIN baseline byte-identical
- Exit: pret→port cross-reference is label-complete for consolidated files.

---

#### Pre-plan faithfulness sweep — progress + rectification tickets (2026-07-04)

Read-only Sonnet audit agents, one per consolidated pre-plan file, grading each
routine FAITHFUL / REORGANIZED-equiv / SCAFFOLD / DIVERGENT vs pret (the standing
rule at the top of this doc). **Wave 1 DONE**: `overworld.asm` (35 routines),
`movement.asm` (24 routines). **Wave 2 DONE**: `trainer_engine.asm`, `warp_check.asm`,
`ledges.asm`. Wave 3 pending: `player_gfx.asm`, `pikachu.asm`, `reload_sprites.asm`,
`overworld_text.asm`, `wild_encounter_check.asm`. `map_sprites.asm` folded into OW-A.2.

**Standing-rule vindication (2026-07-04):** `trainer_engine.asm` was graded FAITHFUL in
the 2026-07-01 pre-plan snapshot ("missing accessors only"). The line-level audit proved
that WRONG — it carries a critical latent buffer overflow (`shl` vs `shr`) + several
register-ABI divergences (see OW-A.9). "Already ported" ≠ faithful, confirmed again.
`warp_check.asm` + `ledges.asm` graded clean (small tagging/filing misses only, OW-A.10).

Wave 1 also surfaced a **read-only-spec corruption** (out of port scope, fixed
immediately, commit `dfb4de24`): early-bringup commit `fec088bd` had short-circuited
`CollisionCheckOnLand`/`OnWater` in `home/overworld.asm` (the pret reference) with
`and a`+`ret`; restored to faithful. Scan confirmed no other foreign edits in the
root pret tree.

**TICKET OW-A.4: EnterMap re-entry architecture** `[SOLO — judgment-heavy]` — SCAFFOLD
- **A.4(a) DONE (2026-07-04):** faithful `EnterMap` body landed + boot restructured.
  `overworld.asm` now splits into `EnterMapBoot` (port-only one-time asset/sprite/name/
  text glue) → falls into faithful `EnterMap::` (line-for-line pret `home/overworld.asm:1-41`
  reset ladder: wJoyIgnore, LoadMapData, ClearVariablesOnEnterMap, wild-cooldown 3-step
  grant, battle-over/blackout split, fly/dungeon-warp anim block, surf/bike, dungeon-warp &
  NPC-face clears, UpdateSprites, CUR_MAP_LOADED_1/2, clear wJoyIgnore). `CheckForceBikeOrSurf`
  gated `%ifdef PLAYER_STATE_LINKED` (off; un-gate at OW-7.2). Prereqs landed: 4 bit constants +
  `wNumberOfNoRandomBattleStepsLeft` promoted to `gb_memmap.inc` (local deleted from
  `wild_encounter_check.asm`); 4 ret-stubs in `overworld_stubs.asm` (MapEntryAfterBattle,
  EnterMapAnim, ResetUsingStrengthOutOfBattleBit, IsSurfingPikachuInParty). Boot callers
  repointed `jmp EnterMap`→`jmp EnterMapBoot`: `init.asm`, `title.asm`, **and `main_menu.asm`
  `SpecialEnterMap`** (the 3rd caller — MISSING from the splash-radius list below; behavior-
  preserving since it relied on the glue formerly inside EnterMap). Verified: `make check`
  clean; 3 FRAME.BIN baselines (BASELINE/TRANSITION/WALK_NORTH) BYTE-IDENTICAL to HEAD (tripwire
  proves render/transition path untouched — resets don't run under baseline DEBUG builds); LIVE
  smoke (real build, user-confirmed): Pallet Town renders correctly + player walks all 4 dirs.
- **A.4(b) STILL PENDING (own MCP-verified SOLO session):** route `.warpTransition`/`.mapTransition`
  (and the post-battle `.battleOccurred` tail) back through `EnterMap` so the reset ladder re-runs
  on every warp/battle-return, as pret does (`jp EnterMap`). This changes the working transition
  control flow — highest regression risk; guard with the re-captured baselines + MCP live warp tests.
- Port `home/overworld.asm:1-42` `EnterMap` is a first-boot-only stand-in (port
  `overworld.asm:279-299`): silently drops `wJoyIgnore` gating,
  `ClearVariablesOnEnterMap` (now ported, OW-1.1), wild-encounter cooldown grant,
  `MapEntryAfterBattle`/`ResetUsingStrengthOutOfBattleBit`, Fly/Dungeon-warp
  `EnterMapAnim`+flag clears, `CheckForceBikeOrSurf`, `BIT_CUR_MAP_LOADED_1/2` set.
  Worse: pret RE-ENTERS `EnterMap` on every warp/battle-return, but the port's
  `.warpTransition`/`.mapTransition` `jmp OverworldLoop` directly, so these resets
  never re-run. Fix: port the real EnterMap body (wiring OW-1.1/OW-1.8 pieces already
  landed) and route warp/battle-return paths back through it. Effort L.
- **SEQUENCING DECISION (2026-07-04, user-confirmed):** EnterMap is the *spine* of the
  map-entry pipeline (Stages 2/3/5 — scripted movement, warps, cut, fly/teleport — all
  assume faithful map re-entry), so it must land BEFORE those stages, but it is NOT a
  hard blocker for the read-only audit sweep, `map_sprites` (OW-A.2), or label
  restoration (OW-A.3), which are structurally independent. **Slot:** first substantial
  CODE rectification after the sweep (waves 2-3) completes, PAIRED with OW-A.5 (same
  pipeline). **Decompose into two halves by risk:**
  - **(a) faithful EnterMap body** — new code wiring the landed OW-1.1/OW-1.8 resets;
    low risk (not yet on a hot path). Do first.
  - **(b) route warp/battle-return through EnterMap** — changes the transition control
    flow that currently renders correctly; carries regression risk to the working
    overworld transition. Do as a with-user SOLO, guarded by the re-captured FRAME.BIN
    baselines (BASELINE/TRANSITION/WALK_NORTH) + MCP live warp tests.
  - A.2/A.3/A.7/A.8 interleave around A.4; A.4+A.5 are the spine and land together.

- **FEASIBILITY (2026-07-04):** many-session job for the full spine. A.4(a) = one focused
  session (moderate spill risk from scaffolding couplings); A.4(b) = its own session (live
  MCP warp verification, iterative); A.5 partly rides A.4, partly separate. Best executed in
  FRESH context — this ticket is self-contained below so a cold session starts hot.

- **Splash radius — 5 direct files:** `overworld.asm` (EnterMap rewrite + boot-setup
  relocation), `init.asm` (SKIP_TITLE `jmp EnterMap` @ ~157 → boot wrapper), `title.asm`
  (`.go_to_main_menu` `jmp EnterMap` @ ~388 → boot wrapper), `overworld_stubs.asm` (4 new
  ret-stubs), `gb_memmap.inc` (4 bit constants + promote `wNumberOfNoRandomBattleStepsLeft`).

- **Verified facts (no re-investigation needed):**
  - Bit constants (pret `constants/ram_constants.asm`): `BIT_WILD_ENCOUNTER_COOLDOWN`=0
    (already def), `BIT_FLY_WARP`=3 (already def), `BIT_CUR_MAP_LOADED_1/2`=5/6 (already def);
    **ADD:** `BIT_NO_NPC_FACE_PLAYER`=5 (wStatusFlags3), `BIT_NO_BATTLES`=4 (wStatusFlags4),
    `BIT_BATTLE_OVER_OR_BLACKOUT`=5 (wStatusFlags4), `BIT_DUNGEON_WARP`=4 (wStatusFlags6).
    Confirmed NOT yet defined in port `include/`.
  - WRAM (port Red-anchored scheme, all present unless noted): `W_STATUS_FLAGS_2`=0xD72B,
    `_3`=0xD72C, `_4`=0xD72D, `_6`=0xD731; `W_JOY_IGNORE`=0xCCB7,
    `W_CURRENT_MAP_SCRIPT_FLAGS`=0xD125. **PROMOTE** `wNumberOfNoRandomBattleStepsLeft`=0xD13B
    (currently local equ in `wild_encounter_check.asm:70`, adjacent to `wStepCounter` 0xD13A;
    delete the local after promoting).
  - Leaves — MISSING → new `; TODO(faithful)` ret-stubs in `overworld_stubs.asm`:
    `MapEntryAfterBattle`, `EnterMapAnim`, `ResetUsingStrengthOutOfBattleBit`,
    `IsSurfingPikachuInParty` (all on inert fly/warp/battle-return branches at boot).
    `CheckForceBikeOrSurf` EXISTS in check-only `player_state.asm` → faithful `call` GATED
    behind `%ifdef PLAYER_STATE_LINKED` (off) w/ TODO (matches `WILD_ENCOUNTERS_LIVE`/
    `NPC_MOVEMENT_SCRIPTS_LINKED` idiom); un-gate at OW-7.2 player_state promotion.
    LINKED (call directly): `ClearVariablesOnEnterMap`, `UpdateSprites`, `LoadMapData`.
  - Boot callers both `jmp EnterMap` (tail): `init.asm:157` (SKIP_TITLE), `title.asm:388`.

- **Target structure:**
  ```
  EnterMapBoot:                 ; boot-only, runs ONCE; both boot callers jmp here
      call LoadOverworldAssets / SetupPlayerSprite / [%ifdef SKIP_TITLE name-seed]
      call text_engine_init / InitToggleableObjectFlags   ; fall into EnterMap
  EnterMap::                    ; faithful pret home/overworld.asm:1-41
      mov byte [ebp+W_JOY_IGNORE], PAD_BUTTONS | PAD_CTRL_PAD
      call LoadMapData
      [DEBUG_DUMP/WALK_NORTH/TRANSITION/DIALOG harnesses]   ; << KEEP HERE (tripwire)
      call ClearVariablesOnEnterMap
      ; wStatusFlags2 WILD_ENCOUNTER_COOLDOWN -> wNumberOfNoRandomBattleStepsLeft=3
      ; wStatusFlags4 BATTLE_OVER_OR_BLACKOUT: res; z->ResetUsingStrengthOutOfBattleBit; nz->MapEntryAfterBattle
      ; wStatusFlags6 (FLY_WARP|DUNGEON_WARP)!=0 -> EnterMapAnim;UpdateSprites;res FLY_WARP;res NO_BATTLES
      ; IsSurfingPikachuInParty ; %ifdef PLAYER_STATE_LINKED CheckForceBikeOrSurf
      ; wStatusFlags6 res DUNGEON_WARP ; wStatusFlags3 res NO_NPC_FACE_PLAYER
      call UpdateSprites
      ; wCurrentMapScriptFlags set CUR_MAP_LOADED_1|CUR_MAP_LOADED_2
      mov byte [ebp+W_JOY_IGNORE], 0     ; fall into OverworldLoop
  ```
  Repoint `init.asm:157` + `title.asm:388` from `jmp EnterMap` to `jmp EnterMapBoot`.

- **Tripwire (why it's safe-ish):** keep the DEBUG dump harnesses IMMEDIATELY after
  `LoadMapData`, BEFORE the new resets. DEBUG builds dump-and-exit inside the harness, so the
  resets never run under DEBUG → **all 3 FRAME.BIN baselines must stay byte-identical** = proof
  the render/transition path is untouched. Resets run only in the real build.

- **Step order + verification:**
  1. Prereqs (constants + `wNumber` promote + 4 stubs): `make check` clean, zero behavior change.
  2. Restructure: `make SKIP_TITLE=1` builds; re-capture 3 baselines → byte-identical to the
     session sha256 manifest; then a LIVE smoke test (MCP/visual: boot + walk 4 dirs) because
     the real build runs resets the baselines can't see.
  3. A.4(b): MCP live warp (breakpoint EnterMap, `gb_read` status flags per warp, `dump_frame`).
  - Baselines are scratchpad/session-ephemeral — RE-CAPTURE from HEAD at session start
    (recipe: build-and-debug skill). WALK_NORTH valid since the east-pre-walk fix (commit 9ecae0dc).

- **Open couplings / risks:** (1) `ClearVariablesOnEnterMap` at boot may zero state other init
  code set — watch the live smoke; (2) player_state linkage gates `CheckForceBikeOrSurf`
  (deferred OW-7.2); (3) `title.asm` is a known-broken bespoke impl — touching its EnterMap jump
  may surface title bugs; (4) A.4(b) changes the working transition path — highest risk, own
  session, MCP-verified.

**TICKET OW-A.5: map-load faithfulness cluster** `[SWARM/Sonnet]` — DIVERGENT (overworld.asm)
- **LoadWildData wiring DONE (2026-07-04):** `LoadMapHeader` now `call`s `LoadWildData`
  at the pret-faithful point (after `LoadTilesetHeader`, = pret `:1900`). Required promoting
  `src/data/wild_data.asm` + `src/engine/overworld/wild_mons.asm` from check-only `BATTLE_SRCS`
  to linked `GAME_SRCS` (self-contained 2-file unit: data table + inline flat→WRAM loader, no
  battle deps). Register-safe (LoadWildData clobbers only EAX/ECX/EDX/ESI, all restored by
  LoadMapHeader's pops). Verified: `make check` clean; real build links (wild_*.o in map); 3
  FRAME.BIN baselines byte-identical (LoadWildData runs during DEBUG_TRANSITION's Route1 load
  without crashing/altering render); DUMP.BIN ground-truth — after Route1 load, wCurMap=0x0C,
  wGrassRate=25, 10 mon pairs (3/4 PIDGEY, 2/3 RATTATA, …) + wWaterRate=0, byte-identical to
  pret `Route1WildMons`. Remaining A.5 items below still open.
- `LoadMapHeader` (`home/overworld.asm:1798-1926`): ~~call `LoadWildData`~~ DONE (above);
  still open: restore the `BIT_NO_PREVIOUS_MAP`
  early-return branch; add `MarkTownVisitedAndLoadToggleableObjects` +
  `SchedulePikachuSpawnForAfterText` (or `; TODO-HW`/`; PROJ` markers); verify
  `wCurrentMapHeight2/Width2` ordering vs first use.
- `LoadMapData` (`:1961-1988`): remove the duplicate `LoadScreenRelatedData` call +
  stray `GBPalNormal`, or comment the intent.
- `LoadWarpDestination` (`:449-517`): restore warp-pad/fly detection
  (`IsPlayerStandingOnWarpPadOrHole`/`BIT_FLY_WARP`), `PlayMapChangeSound`,
  `wMapPalOffset` reset, `ROCK_TUNNEL_1F` fade special-case, `SetPikachuSpawn*` — or
  mark each deferred. (Prior FAITHFUL claim was too broad; it is DIVERGENT.)
- `CopyMapViewToVRAM`: dead `global` + "faithful translation" doc block with NO body —
  delete the declaration or mark `; DIVERGENCE: obsoleted by native render_bg`.

**TICKET OW-A.6: OverworldLoop wild/surf gaps** `[SWARM or folds into Stage 4]` — DIVERGENT
- On-turn wild-encounter check `NewBattle` (pret `:196-199`) dropped → turning in grass
  can't trigger an encounter; add it, gate behind a `WILD_ENCOUNTERS_LIVE` flag (S).
- Surfing entirely absent (`.surfing`/`CollisionCheckOnWater` `:206-226`, `DoBikeSpeedup`
  `:243`) — larger; may fold into the boulder/field-move Stage 4 work. Effort M/L.

**TICKET OW-A.7: movement.asm NPC faithfulness fixes** `[SWARM/Sonnet]` — DIVERGENT
- Status-4 dispatch silently dropped (`UpdateNonPlayerSprite`, pret `movement.asm:134-5`):
  add the `cp 4` case + port `Func_5357` (item-ball-emerge/STAY-and-face, pret
  `movement.asm:1018-1075`; uses already-ported `Func_5274`/`Random`). S. (Same
  `Func_5357` also listed in OW-2.1's absent-chain; do it here — cheap + independent.)
- `CanWalkOntoTile` missing pret's off-screen pixel bound (`cp $80`/`cp $90`, pret
  `:581-590`) → WALK/STAY NPCs have NO east/south wander bound at all. Add the guard. S.
- `MakeNPCFacePlayer` missing `BIT_NO_NPC_FACE_PLAYER` guard on `W_STATUS_FLAGS_3`
  (pret `:371-373`; S.S.Anne captain cutscene needs it); also reconcile the
  `wPlayerDirection`→`W_SPRITE_PLAYER_FACING_DIR` field substitution with a
  `; DIVERGENCE` note (reads a different WRAM cell). S.
- `DetectCollisionBetweenSprites` over-zeroes `COLLISIONBITMAP_HI/LO` every call (pret
  never resets them, `sprite_collisions.asm:104-106`) — narrow the zero to 2 bytes to
  match; fix the backwards `DH[3:2]`/`.use_ybits`/`.pika_ybits` comments (code correct). S.
- `.randomMovement` extra clamp ([-3,+6]Y/[-7,+10]X) is narrower than
  `CheckSpriteAvailability`'s edge-visible zone → an edge-visible NPC can be blocked from
  random-walking; reconcile the two bound sets or document. S.

**TICKET OW-A.8: overworld.asm marker/hygiene sweep** `[SWARM/Sonnet, mechanical]` — DIVERGENT (silent)
- `CollisionCheckOnLand`: add `; TODO-HW: audio HAL` for dropped `SFX_COLLISION`;
  restore `wSimulatedJoypadStatesIndex` no-collision bypass + `wSpritePlayerStateData1CollisionData`
  quick-reject (needed once scripted movement lands); document that `IsNPCAtTargetBlock`
  is a bespoke replacement for pret's `IsSpriteInFrontOfPlayer`.
- `ResetMapVariables`: set `wMapViewVRAMPointer` as its comment claims, or fix the comment.
- `PlayerStepOutFromDoor`: restore entry `res BIT_UNKNOWN_5_1` + the 3 simulated-joypad
  field zeroes in `.notStandingOnDoor` (stale state leaks into `AreInputsSimulated`).
- `GetTileInFrontOfPlayer`: confirm no caller needs the D/E target-coord side-outputs
  (pret `_GetTileAndCoordsInFrontOfPlayer` leaves them for sign/warp callers); add or note.
- `LoadTilesetHeader`: 3 counter-tile fields silently unported — add WRAM slot + copy or
  an explicit deferral marker (rides tile-animation).
- `CheckMapConnections`: add `PlayDefaultMusicFadeOutCurrent`/`SET_PAL_OVERWORLD` calls or
  deferred markers at the crossing site.

**TICKET OW-A.9: trainer_engine.asm ABI/faithfulness fixes** `[SWARM/Sonnet]` — DIVERGENT (blocks OW-7.2 promotion)
- **CRITICAL (fix before this file links):** `TrainerWalkUpToPlayer` (port `:441,453,465,477`)
  uses `shl al,4` to translate pret's `swap a`, but the value is a block-aligned pixel
  distance (always ×16) so `swap` is a **divide**-by-16 → must be `shr al,4`. As written
  every call yields step count `0xFF` and `FillMemory` writes 255 bytes into the **10-byte**
  `wNPCMovementDirections2` → WRAM-scratch overflow. Latent only because the file is
  check-only today. 4 one-line fixes. **S but blocking.**
- `LoadGymLeaderAndCityName` (`:241-250`): passes dest in **EDI**; `CopyData` ABI is
  `ESI=src, EDX=dst, BX=count` (`copy_data.asm:36`) → writes to garbage, never fills
  `wGymCityName`/`wGymLeaderName`. Change EDI→EDX both sites; drop the resolved TODO. S.
- `EmotionBubble` (`:950-952`): `WriteOAMBlock` reads the block ptr from **DX/EDX** not ESI
  (`oam.asm:36,44`), AND `EmotionBubblesOAMBlock` is a flat `.data` label while WriteOAMBlock
  does `[ebp+DX]` (EBP-relative) — address-model mismatch, not just a register swap. Decide:
  copy block to WRAM scratch first, or a flat-addressing WriteOAMBlock variant. M. (Also
  blocked on unported `CopyVideoData`/`EmotionBubbleGfx` — rides OW-7.2 gfx embed.)
- `TrainerEndBattleText` (`:778-785`): emits a `TX_START_ASM` splice the port's
  `TextCommandProcessor` treats as a silent no-operand skip (`text.asm:959`) → the
  `_asm` tail is dead code and parsing runs into following opcode bytes. Cross-cutting with
  the `charge.asm` text_asm gap — either add real TX_ASM dispatch or call
  `GetSavedEndBattleTextPointer`/`PrintText` directly from `PrintEndBattleText`. M.
- `GetTrainerInformation` (`:854-864`): copies 3 BCD money bytes; pret copies 2 into a
  2-byte `wTrainerBaseMoney` (Gen-1 quirk). Match pret's 2-byte read, or wrap the 3-byte
  version in a `; BUG(known):`/`BUG_FIX_LEVEL` block (currently a bare TODO — silent). S.
- `PlayTrainerMusic` (`~:802`): silently drops `wAudioFadeOutControl`/`wAudioROMBank`/
  `wAudioSavedROMBank` writes — add `; TODO-HW:` markers (audio HAL no-ops today). S.
- Missing non-underscored `GetSpritePosition1/2`/`SetSpritePosition1/2` bank-wrappers
  (pret `trainers.asm:246-262`; called by `scripts/OaksLab.asm`) — trivial pass-throughs to
  the byte-verified `_Get/_Set*` pair. S, not urgent (Oak cutscene not yet ported).

**TICKET OW-A.10: wave-2 tagging + stub-filing hygiene** `[SWARM/Sonnet, mechanical]`
- `warp_check.asm` `IsWarpTileInFrontOfPlayer`: convert the prose note on the omitted
  `SS_ANNE_BOW` special case (tile `$15`→CF) into a `; DIVERGENCE:` block + `; TODO` for
  when S.S. Anne lands; and `; PROJ`-tag (not prose) the reliance on pre-populated
  `wTileInFrontOfPlayer`. Informational: `overworld.asm:715-720` should eventually call the
  now-faithful `CheckIfInOutsideMap` instead of the `W_CUR_MAP < FIRST_INDOOR_MAP_ID`
  heuristic (not identical for edge maps like Route 23/Plateau).
- `ledges.asm` `LoadHoppingShadowOAM`: move the no-op stub OUT of the pret-mirroring `.asm`
  into `overworld_stubs.asm` (convention: stub never in the file mirroring its own pret
  source) with a retirement TODO; leave an `extern` in `ledges.asm`. The real impl (shadow
  tile→vChars1 $7F, 2 shadow-OAM slots) is M, blocked on shadow-OAM slot support in
  `PrepareOAMData`. Carry-forward note: when surf/`CollisionCheckOnWater` is ported, its
  `CheckForJumpingAndTilePairCollisions` call must prime `wTileInFrontOfPlayer` first (the
  port routine no longer self-derives it, unlike pret).

**Verification-needed (MCP/FRAME.BIN before treating as settled — not tickets yet):**
- `CheckSpriteAvailability` Y/X visibility bounds (port `movement.asm:733-748`) don't
  literally match pret's asymmetric zero-tolerance-north test (`:466-482`); auditor
  medium-confidence — confirm live before fixing/accepting.
- `GetTileSpriteStandsOn` uses MAPY/MAPX (instant destination) vs pret YPIXELS/XPIXELS
  (mid-walk sweep) — affects grass-priority/textbox timing during the ~16 walk frames;
  decide keep-with-`; DIVERGENCE` vs pret-exact.
- `PLAYER_STANDING_ROW/COL` (17,24 into 40-wide `wTileMap`) vs pret `lda_coord 8,9` — the
  shared projection constants haven't been re-verified against the expanded-viewport
  render path (memory `coord-macros-logic-audit`).

**OW-2.1 scope update (from movement.asm audit):** the scripted-movement DISPATCH GATE is
WRONG, not just unfilled — port gates on bit-0 `BIT_SCRIPTED_NPC_MOVEMENT` (set only by
`pathfinding.asm:MoveSprite`); pret gates on per-slot `wNPCMovementScriptSpriteOffset ==
hCurrentSpriteOffset` (value compare) with `DoScriptedNPCMovement` separately checking bit-7
`BIT_SCRIPTED_MOVEMENT_STATE`. Tagged `; DIVERGENCE` in-port and dead today (nothing sets the
bit; `DoScriptedNPCMovement` is a ret-stub), but OW-2.1 must **rebuild the gate**, not just
unstub. Confirmed already-ported (faithful): `Func_5337`, `Func_5349`. Confirmed ABSENT (no
label/stub): `ChangeFacingDirection`, `InitScriptedNPCMovement`, `AnimScriptedNPCMovement`,
`Func_5288/531f/5325/532b/5331/5357`, `LoadDEPlusA`, `GetSpriteScreen{Y,X}Pointer`,
`GetSpriteScreenXYPointerCommon`, `AdvanceScriptedNPCAnimFrameCounter`.

### Stage 1 — Pure-logic leaves `[x]` COMPLETE (2026-07-04, SWARM wave 1)

All 9 done: OW-1.1 … OW-1.9. `clear_variables`, `daycare_exp`, `is_player_just_outside_map`,
`dungeon_warps`, `specific_script_flags`, `audio_stubs` link (GAME_SRCS); `npc_movement_2`,
`trainer_sight` (in trainer_engine.asm), `player_state` are check-only (HOME_CHECK_SRCS) until
their externs' home files are promoted (OW-7.2 / OW-A.3). Every worker diff root-reviewed vs pret.

**Stage-1 follow-ups (deferred, tracked):**
- **OW-1.8 `H_WARP_DESTINATION_MAP` placeholder** wrongly aliases 0xFF8B (hPreviousTileset);
  give it a distinct HRAM byte before player_state.asm links. (Inert while check-only.)
- **OW-1.8 `SafariSteps`/`SafariBallText`** two-tier violation — **RESOLVED 2026-07-04**:
  new `tools/gen_overworld_strings.py` → `assets/overworld_strings.inc` (byte-identical to
  the prior inline), `%include`d by player_state.asm; wired into `make assets` + player_state.o.
  This generator is the Tier-1 home for future overworld field-message strings (OW-4.x
  Strength/Surf/boulder text).
- **`IsPlayerStandingOnDoorTile` needs `global`** in overworld.asm (OW-A.3) — one of the two
  player_state link blockers; the other is `ForceBikeOrSurf` (promote player_gfx, OW-7.2).
- OW-1.7 hSprite*Coord/wSavedSprite* placeholders → reconcile into gb_memmap.inc at promotion.
- **Pre-plan-port faithfulness audit** (user directive, see the standing rule above): the
  reused pre-plan routines `ForceBikeOrSurf`, `IsPlayerStandingOnDoorTile`, warp_check's
  `IsWarpTileInFrontOfPlayer`/`IsPlayerFacingEdgeOfMap`, and trainer_engine's M8.2 sight
  routines must be graded bespoke-vs-faithful before their reuse is fully trusted.

Common ticket boilerplate (applies to OW-1.1 … OW-1.8): translate per CLAUDE.md
register map; `%include "dos_port/include/gb_memmap.inc"`; add missing WRAM/HRAM
offsets to `gb_memmap.inc` from `ram/wram.asm`/`ram/hram.asm` (sym-verify);
inline small pret data tables with `; pret: data/...` provenance; flag known bugs
per `docs/bugs_and_glitches.md` with `BUG_FIX_LEVEL` blocks; verify with
`nasm -f coff -o /dev/null <file>`; report symbols consumed/exported. Root agent
adds to `GAME_SRCS` (or `OVERWORLD_CHECK_SRCS` if closure unresolved), runs
`make check` + FRAME.BIN baseline, writes translation_log.

**TICKET OW-1.1: clear_variables.asm** — `ClearVariablesOnEnterMap`; scroll/`hWY` HRAM writes → `; TODO-HW` (renderer owns scroll); WRAM clear loop faithful.
**TICKET OW-1.2: specific_script_flags.asm** — `SetMapSpecificScriptFlagsOnMapReload` + inline map table.
**TICKET OW-1.3: is_player_just_outside_map.asm** — `IsPlayerJustOutsideMap`; cross-ref (do not duplicate) `CheckIfInOutsideMap` in `warp_check.asm`.
**TICKET OW-1.4: dungeon_warps.asm** — `IsPlayerOnDungeonWarp`; reuse `extern ArePlayerCoordsInArray` (port hidden_events.asm); inline `DungeonWarpList`; WRAM `wWhichDungeonWarp`.
**TICKET OW-1.5: daycare_exp.asm** — `IncrementDayCareMonExp`; party-struct offsets from `gb_constants.inc` (respect Gen-2 forward-compat: byte-identical structs).
**TICKET OW-1.6: npc_movement_2.asm** — `SetEnemyTrainerToStayAndFaceAnyDirection` + `RivalIDs` table.
**TICKET OW-1.7: trainer_sight accessors** — into `trainer_engine.asm`: `_GetSpritePosition1`, `_GetSpritePosition2`, `_SetSpritePosition1`, `_SetSpritePosition2`, `GetSpriteDataPointer` (pret `engine/overworld/trainer_sight.asm`).
**TICKET OW-1.8: player_state.asm (part 1 — getters)** — new mirrored file: `IsPlayerStandingOnWarp`, `CheckForceBikeOrSurf` (+ `force_bike_surf` table; cross-ref existing `ForceBikeOrSurf` in `player_gfx.asm` — reconcile, don't duplicate), `IsSSAnneBowWarpTileInFrontOfPlayer`, `IsPlayerStandingOnDoorTileOrWarpTile` (+ warp-carpet table; reuse door table from overworld.asm), `PrintSafariZoneSteps` (PrintNumber/PlaceString exist; `; PROJ` for textbox coords per ui_projection.md), `GetTileAndCoordsInFrontOfPlayer` / `_GetTileAndCoordsInFrontOfPlayer` / `GetTileTwoStepsInFrontOfPlayer` (`; PROJ`: pret reads wTileMap at GB screen-center 8,9 — port equivalent is the 40×25 center; heavily depended on by Stages 3–4). Boulder checks deferred to OW-4.1. Note the two routines already in `warp_check.asm` stay there (extern + header note).
**TICKET OW-1.9: audio_stubs.asm** — new `src/audio/audio_stubs.asm`: `global` ret-stubs `StopAllMusic`, `WaitForSoundToFinish`, `PlayMusic`, `PlayDefaultMusic` (verify each is still undefined post-merge); each with `; TODO-HW: audio HAL (Phase 3)` header; add to `GAME_SRCS`.

- Exit: 7 new files + 2 extensions linked; baseline unchanged.

### Stage 2 — Scripted NPC movement `[ ]` — unblocks Oak cutscene

**TICKET OW-2.1: movement.asm scripted chain** `[SOLO #1]`
- Pret: `engine/overworld/movement.asm` (remaining routines)
- Checklist:
  - [ ] `ChangeFacingDirection`, `DoScriptedNPCMovement`, `InitScriptedNPCMovement`, `GetSpriteScreenYPointer`/`GetSpriteScreenXPointer`/`GetSpriteScreenXYPointerCommon`, `AnimScriptedNPCMovement`, `AdvanceScriptedNPCAnimFrameCounter`, `Func_5288`/`Func_531f`/`Func_5325`/`Func_532b`/`Func_5331`/`Func_5337`/`Func_5349`/`Func_5357` (keep pret Func names)
  - [ ] Fix audit omissions: status-4 dispatch → `Func_5357` (item-ball emerge / STAY-and-face path); `MakeNPCFacePlayer` `BIT_NO_NPC_FACE_PLAYER` guard
  - [ ] Reconcile the `BIT_SCRIPTED_NPC_MOVEMENT` bit-0 (port) vs bit-7 + `wNPCMovementScriptSpriteOffset` (pret) divergence — decide once, document in translation_log, sweep all readers
  - [ ] Delete `overworld_stubs.asm:DoScriptedNPCMovement` ret-stub
  - [ ] WRAM: `wNPCMovementDirections2(+Index)`, `wNPCMovementScriptFunctionIndex`, `wScriptedNPCWalkCounter`, `wNPCMovementScriptSpriteOffset`
- Exit: scripted stepper runs under harness; stub deleted.

**TICKET OW-2.2: pathfinding.asm engine section** `[SWARM/Sonnet]` — append clearly-headed section to port `pathfinding.asm` (which holds home/pathfinding): `FindPathToPlayer`, `CalcPositionOfPlayerRelativeToNPC`, `ConvertNPCMovementDirectionsToJoypadMasks` + masks table (pret `engine/overworld/pathfinding.asm`).
**TICKET OW-2.3: auto_movement.asm** `[SWARM/Sonnet]` — new mirrored file: `_EndNPCMovementScript`, `PalletMovementScriptPointerTable` + all `PalletMovementScript_*`, `RLEList_ProfOakWalkToLab`/`RLEList_PlayerWalkToLab`, `PewterMuseumGuyMovementScriptPointerTable`/`PewterGymGuyMovementScriptPointerTable` + RLELists. Cross-ref `PlayerStepOutFromDoor`/`RunNPCMovementScript` already in `overworld.asm` (extern, note). Leaves: `PlayDefaultMusic`/`StopAllMusic` (OW-1.9 stubs).
**TICKET OW-2.4: pewter_guys.asm** `[SWARM/Sonnet]` — new `src/engine/events/pewter_guys.asm` (pret `engine/events/pewter_guys.asm`, 102 lines, pure logic + `DecodeRLEList` from simulate_joypad.asm).
**OW-2.5: Oak cutscene verification** `[root]` — enable `PalletTownDefaultScript` trigger (script-engine Stage 6 stubs), DOSBox-X MCP: breakpoint `DoScriptedNPCMovement`, `gb_read wNPCMovementDirections2`, `dump_frame` per step; final FRAME.BIN shows Oak + player walked to the Lab. Update `current_plan_script_engine.md` (deferral resolved).

### Stage 3 — Map mutation `[ ]`

**TICKET OW-3.1: update_map.asm** `[SOLO #3]`
- Pret: `engine/overworld/update_map.asm`
- Checklist:
  - [ ] `ReplaceTileBlock` — pure `wOverworldMap` pointer math, direct translation; `CompareHLWithBC` faithful
  - [ ] `RedrawMapView` — **re-expressed**: pret's per-row `REDRAW_ROW` VRAM staggering collapses to `LoadCurrentMapView` + `g_tilecache_dirty` (+ one frame); keep the `wIsInBattle` guard; large `; PROJ`/`; TODO-HW` header citing CLAUDE.md ("rings are gone") — this is the **canonical redraw precedent** cut/elevator/scripts will cite
  - [ ] Verify: MCP `ReplaceTileBlock` on a visible Pallet block → `dump_frame` before/after shows clean swap, no artifacts
- Exit: canonical redraw primitive established.

**TICKET OW-3.2: toggleable_objects.asm completion** `[SWARM/Sonnet]` — new mirrored file: `MarkTownVisitedAndLoadToggleableObjects`, `ShowObject`/`ShowObject2`, `HideObject`, `ToggleableObjectFlagAction` (pure flag ops); alias/extern the two already-ported routines in `map_sprites.asm` (`InitToggleableObjectFlags`→pret `InitializeToggleableObjectsFlags`, `IsToggleableHidden`→pret `IsObjectHidden`) — reconcile naming toward pret.
**TICKET OW-3.3: hidden_events engine side** `[SWARM/Sonnet]` — into existing port `hidden_events.asm` (clearly-headed section): `CheckForHiddenEvent`, `CheckIfCoordsInFrontOfPlayerMatch`; retire the `M72_HIDDEN_EVENTS_DEEP` guard. Data: new `tools/gen_hidden_events.py` → Tier-1 `assets/hidden_events.inc` (coords + extern handler symbols) + Tier-2 `hidden_object_stubs.asm` (hand-written ret-stub handlers). **Timebox the generator; fallback = hand-transcribe reachable maps only.**
**TICKET OW-3.4: cut.asm** `[SWARM/Sonnet]` — new mirrored file: `UsedCut` (faithful body; leaves: `GetPartyMonName` exists; fade/palette calls via fade.asm else stubs; screen-buffer routines `SaveScreenTilesToBuffer2`/`LoadScreenTilesFromBuffer2`/`RestoreScreenTilesAndReloadTilePatterns` — audit post-merge, stub if absent; `AnimCut` → ret-stub until OW-6.1), `InitCutAnimOAM` (tree tiles $2d/$3d from `assets/overworld_gfx.inc`; grass leaf tile — check battle animations.asm embedding, else incbin `gfx/battle/move_anim_1.2bpp` slice), `WriteCutOrBoulderDustAnimationOAMBlock`, `GetCutOrBoulderDustAnimationOffsets` + tables, `ReplaceTreeTileBlock` + `cut_tree_blocks` table (calls OW-3.1's `ReplaceTileBlock`/`RedrawMapView`).
- Verify (root): tree-cut block swap renders cleanly under harness; Show/HideObject on Oak sprite via MCP.

### Stage 4 — Boulder subsystem `[ ]` (SWARM wave)

**TICKET OW-4.1: player_state.asm part 2** — `CheckForCollisionWhenPushingBoulder`, `CheckForBoulderCollisionWithSprites` (completes the file).
**TICKET OW-4.2: push_boulder.asm** — `TryPushingBoulder` + movement tables, `DoBoulderDustAnimation`, `ResetBoulderPushFlags`. Leaves: `SFX_PUSH_BOULDER` → `PlaySound` stub; `EmotionBubble` (extern; if trainer_engine still check-only, note for OW-7.2 promotion).
**TICKET OW-4.3: dust_smoke.asm** — `AnimateBoulderDust`, `GetMoveBoulderDustFunctionPointer` + table, `LoadSmokeTileFourTimes`/`LoadSmokeTile` (sets `g_tilecache_dirty`); incbin `gfx/overworld/smoke.2bpp` (precedent: pokeballs.asm).
**TICKET OW-4.4: field_move_messages.asm** — `PrintStrengthText`, `IsSurfingAllowed` + texts/coords; hooks the existing party pop-up field-move layer (`FieldMoveDisplayData`).
- Verify (root): MCP unit-drive — fabricate `wTileInFrontOfPlayer` = boulder tile + sprite state, call `TryPushingBoulder`, check flags/`wSimulatedJoypadStates`, dust OAM in FRAME.BIN. (No boulder maps reachable yet — harness-level only, noted in translation_log.)

### Stage 5 — Player warp/fly/spin animations `[ ]`

**TICKET OW-5.1: player_animations.asm** `[SOLO #2]`
- Pret: `engine/overworld/player_animations.asm`
- Checklist:
  - [ ] `EnterMapAnim`, `PlayerSpinWhileMovingDown`, `_LeaveMapAnim`, `LeaveMapThroughHoleAnim`, `DoFlyAnimation` + coord lists, `LoadBirdSpriteGraphics` (incbin `gfx/sprites/bird.2bpp`; loads NPC-sprite VRAM → `g_tilecache_dirty`; integrate with `src/gfx/sprites.asm` sheet layout), `InitFacingDirectionList`, `SpinPlayerSprite`, `PlayerSpinInPlace`, `PlayerSpinWhileMovingUpOrDown`, `RestoreFacingDirectionAndYScreenPos`, `GetPlayerTeleportAnimFrameDelay` (`wOnSGB` read — `; PROJ` note re Makefile TIMING modes), `IsPlayerStandingOnWarpPadOrHole` (+ tile table; writes `wStandingOnWarpPadOrHole`), `FishingAnim` (leaves: `LoadAnimSpriteGfx`/rod gfx/`EmotionBubble`/texts — stub what's missing, body faithful)
  - [ ] `_HandleMidJump` stays in ledges.asm; alias note here
  - [ ] Bounded-wait divergences for any sound-state polling vs ret-stubs
  - [ ] Verify: `DEBUG_TELEPORT_ANIM` harness in `EnterMap` (pattern: `DEBUG_TRANSITION`) — set `BIT_USED_FLY`/dungeon-warp state, run `EnterMapAnim`, FRAME.BIN mid-anim shows bird/spin frames; MCP breakpoints on `DoFlyAnimation`
- Exit: fly-in / teleport / hole-fall animations render.

**TICKET OW-5.2: special_warps.asm** `[SWARM/Sonnet]` — `PrepareForSpecialWarp`, `LoadSpecialWarpData` + inlined `data/maps/special_warps.asm` (91 lines); wires into existing warp_check/doors flow.

### Stage 6 — Cosmetic OAM/screen animations `[ ]` (SWARM wave)

**TICKET OW-6.1: cut2.asm** — `AnimCut`, `AnimCutGrass_UpdateOAMEntries`/`_SwapOAMEntries` (pure shadow-OAM); delete the OW-3.4 `AnimCut` stub.
**TICKET OW-6.2: healing_machine.asm** — `AnimateHealingMachine` + OAM data, `FlashSprite8Times`, `CopyHealingMachineOAM`; incbin `gfx/overworld/heal_machine.2bpp`; sound leaves stubbed; `[wAudioROMBank]` guard dropped with `; DIVERGENCE` note; **bounded** waits vs sound stubs.
**TICKET OW-6.3: elevator.asm** — `ShakeElevator` (`hSCY` shake → port `H_SCY` fine-scroll, native renderer honors it); `ShakeElevatorRedrawRow` → `RedrawMapView` call or documented no-op (`; PROJ`); `.musicLoop` on `wChannelSoundIDs` must be **bounded** against sound stubs (no infinite spin) — divergence note.
**TICKET OW-6.4: spinners.asm** — `LoadSpinnerArrowTiles` (per-frame vChars0 writes from `SpinnerArrowAnimTiles` → `g_tilecache_dirty`; `; TODO-HW` re VRAM coord math), facing table + `spinner_tiles`; incbin `gfx/overworld/spinners.2bpp`.
- Verify (root): cut animation end-to-end (full `UsedCut` visual); healing machine / elevator / spinners via MCP unit-invocation + FRAME.BIN (maps unreachable — check-only linkage acceptable where callers don't exist).

### Stage 7 — Completeness + link promotion + cleanup `[ ]`

**TICKET OW-7.1: unused_load_toggleable_object_data.asm** `[SWARM/Sonnet]` — port check-only (`OVERWORLD_CHECK_SRCS`), `; UNREFERENCED (pret: unreferenced)` header.
**OW-7.2: link promotion** `[root + SWARM closure fixes]` — promote check-only overworld files to `GAME_SRCS` as closures resolve: `ledges.asm`, `trainer_engine.asm` (embed `EmotionBubbleGfx` — incbin the 8 `gfx/emotes/*.2bpp`, resolving the M8.2 extern-TODO), `pathfinding.asm`; then per-file closure audit for `pikachu.asm`, `reload_sprites.asm`, `player_gfx.asm`, `overworld_text.asm` (promote or document remaining blockers in this doc).
**OW-7.3: stub + docs sweep** `[root]` — delete every stub superseded in Stages 1–6; list surviving stubs here with owners; translation_log completeness sweep; ui_projection.md overworld rows; TODO.md checkboxes.

### Stage 8 — Final full-surface audit `[ ]` (root; gates archival)

- [ ] **Coverage re-diff**: every global label in pret `engine/overworld/*.asm`
      exists in dos_port as a real body, a sanctioned documented stub, or a
      documented UNREFERENCED port — zero unexplained gaps.
- [ ] **Line-level fidelity audit** (same method as the 2026-07-01 pre-plan
      audit): routine-by-routine control-flow comparison of everything this plan
      touched; grade FAITHFUL/REORGANIZED/SCAFFOLD; any SCAFFOLD or silent
      omission → fix ticket before closing.
- [ ] **Silent-omission sweep**: every pret step absent from the port carries an
      explicit `; TODO` / `; PROJ` / `; DIVERGENCE` marker.
- [ ] **Runtime regression**: full FRAME.BIN suite (baseline / north-transition /
      walk-to-edge / Oak cutscene / tree-cut) matches or improves Stage 0
      captures; `make -C dos_port check` clean.
- [ ] **VRAM tile-slot regression** (see "Cross-cutting defect" above): after the
      `wFontLoaded`/vChars-layout rewrite, open **every** menu (START, options,
      bag, trainer card, party, pokédex) *after* visiting the party menu / a battle
      and confirm box borders, `$7F` blanks, and letter glyphs A–L render cleanly —
      i.e. the box tiles `$79–$7F` and font `$80+` are no longer clobbered. This is
      the menus-port corruption; it must be gone before archival.
- [ ] Archive: `git mv docs/current_plan_overworld_port.md docs/plans/overworld_port.md`.

---

## Swarm launch template (root agent fills per wave)

Precedent: `docs/` battle-swarm launch prompts. Per worker:
1. Root creates worktree, seeds `dos_port/assets/*.inc` + `.2bpp/.pic/.1bpp`
   from the primary clone (memory: `worktree-asset-seeding`).
2. Worker prompt = the verbatim ticket + CLAUDE.md pointers (register map,
   gb_memmap.inc, stub/PROJ conventions) + **hard rules**: model=sonnet;
   logic-only; NEVER run git commands; NEVER edit docs/ or generated assets/;
   deliverable = changed/new `.asm` files + a symbols-consumed/exported +
   divergence-notes report returned in the final message.
3. Root reviews the diff against pret, integrates into the branch, updates the
   Makefile, runs `make check` + FRAME.BIN baseline, writes translation_log,
   ticks the ticket here.

## Stub inventory

- **Create**: `src/audio/audio_stubs.asm` (OW-1.9); `hidden_object_stubs.asm`
  (OW-3.3); screen-buffer stubs (`SaveScreenTilesToBuffer2`,
  `LoadScreenTilesFromBuffer2`, `RestoreScreenTilesAndReloadTilePatterns`) if
  absent post-merge (OW-3.4); `AnimCut` (OW-3.4 → deleted OW-6.1);
  `RunDefaultPaletteCommand` if absent.
- **Delete**: `overworld_stubs.asm:DoScriptedNPCMovement` (OW-2.1);
  `M72_HIDDEN_EVENTS_DEEP` guard (OW-3.3); `AnimCut` stub (OW-6.1);
  trainer_engine `EmotionBubbleGfx` extern-TODO (OW-7.2).

## Asset dependencies

Pattern: direct `incbin "../gfx/<path>.2bpp"` from the port `.asm` (precedent:
`pokeballs.asm`); requires repo-root `make` to have rendered `.2bpp` first
(memory: `asset-regen-needs-2bpp`). Needed: `gfx/overworld/smoke.2bpp`,
`gfx/overworld/heal_machine.2bpp`, `gfx/overworld/spinners.2bpp`,
`gfx/sprites/bird.2bpp`, `gfx/emotes/*.2bpp` (8 files),
`gfx/battle/move_anim_1.2bpp` tile 6 (cut grass leaf — may already ride battle
animations.asm). Generators: sprite-set data (OW-A.2), hidden-events table
(OW-3.3) — Tier-1/Tier-2 split per CLAUDE.md; small pret data INCLUDEs are
inlined with `; pret:` provenance.

## Risks

1. `RedrawMapView` (OW-3.1) is load-bearing — cut/elevator/scripts cite it; solo,
   land it before its consumers.
2. Scripted-movement bit divergence (port bit-0 vs pret bit-7) may ripple through
   live `_UpdateSprites` branches (OW-2.1 reconciliation sweep).
3. hidden_events generator scope creep — timeboxed, reachable-maps fallback.
4. Post-merge tree drift — Stage 0 re-verification is mandatory; matrix and
   ticket assumptions above are pre-merge.
5. Busy-waits on sound state (`elevator.musicLoop`, spin cadence, healing
   machine) hang against ret-stubs — every ticket that touches one carries a
   bounded-wait divergence requirement.
6. Stage 5/6 features live on maps the port can't reach — verification is
   harness/MCP-level, recorded per ticket in translation_log.
7. Stage A touches working code — FRAME.BIN baseline before/after every file.

## Verification (overall)

- Per file: `nasm -f coff -o /dev/null`; per wave: `make -C dos_port check` +
  full `make -C dos_port SKIP_TITLE=1` + FRAME.BIN baseline diff
  (`DEBUG_TRANSITION`/`DEBUG_BASELINE` harnesses; view via
  `tools/render_frame.py`, verify with byte histograms per memory
  `frame-bin-image-viewer-unreliable`).
- Live behavior: DOSBox-X MCP (breakpoints, `gb_read`, `dump_frame`).
- Milestones: Stage 2 exit = Oak cutscene visibly walks; Stage 3 exit = tree-cut
  block swap renders cleanly; Stage 8 gates archival.

---

### Stage 9 — Directory-mirror rectification `[ ]` (DEFERRED to plan end; user-confirmed 2026-07-04)

**Decision:** hold the port to STRICT pret directory mirroring, executed **after** all other
overworld-port stages land (so nothing in this plan has to chase moved paths mid-flight),
**before** the Stage 8 archival `git mv`. A repo-wide scan (223 `src/*.asm`) found the port
uses a subsystem-thematic layout instead of pret's flat `home/`; relocate the thematic
files to mirror pret. All moves are pure `git mv` + Makefile path update — logic-risk-free;
verify each with `nasm` clean + full build + FRAME.BIN baselines unchanged.

**Sanctioned exceptions that STAY (do NOT move):** `src/ppu/`, `src/video/`, `boot/` (HAL —
software PPU / VGA, no pret analog, user-approved 2026-07-04); `*_stubs.asm` (stub
convention: stub lives in `src/<area>/<area>_stubs.asm`); `engine/battle/move_effects/*`
(per-effect split under the already-mirrored `engine/battle/`).

**Relocations (mirror the pret source dir):**
- **C. `home/` → thematic bucket → back to `src/home/`:** `gfx/load_font.asm`, `gfx/pics.asm`,
  `gfx/sprites.asm` (home/clear_sprites.asm), `gfx/uncompress.asm`, `init/init.asm`,
  `input/joypad_lowsens.asm` (home/joypad2.asm), `text/auto_textbox.asm`, `text/text.asm`
  (home/text.asm + home/window.asm), `util/play_time.asm`.
- **D. pret-standalone `home/` files currently in `engine/overworld/` → `src/home/`:**
  `reload_sprites.asm` (home/reload_sprites.asm), `overworld_text.asm` (home/overworld_text.asm),
  `hidden_events.asm` (home/hidden_events.asm), `pathfinding.asm` (home/pathfinding.asm).
- **F. cross-subsystem single-source → mirror pret:** `engine/items/item_price.asm` →
  `src/home/` (home/item_price.asm); `engine/pokemon/get_max_pp.asm` → `engine/items/`
  (engine/items/item_effects.asm); `engine/pokemon/remove_mon.asm` → `src/home/`
  (home/move_mon.asm); `gfx/sprite_oam.asm` → `engine/gfx/` (engine/gfx/sprite_oam.asm).
- **Per-file call at execution (home/overworld.asm-DERIVED port splits):** `player_gfx.asm`,
  `run_map_script.asm`, `simulate_joypad.asm`, `wild_encounter_check.asm` are port-invented
  splits of `home/overworld.asm` routines — decide at execution whether each moves to
  `src/home/` as a standalone file or folds into the sanctioned `overworld.asm` consolidation.
  `overworld.asm` itself is the sanctioned big consolidation (home/overworld.asm +
  engine/overworld/*) — KEEP as-is.

**Also fix (provenance defect, may be handled earlier under the wave-3 audit):**
`engine/overworld/overworld_text.asm` cites `home/overworld_text.asm` but actually holds
`home/map_objects.asm` routines; the 8 real `home/overworld_text.asm` labels are unported —
correct the `; pret:` header and port the missing labels.

**Invariant going forward:** every ported file carries an accurate `; pret: <file>:<label>`
header AND sits in the dir mirroring that pret source (HAL/stub/move_effects excepted).

---

#### Pre-plan faithfulness sweep — WAVE 3 findings (2026-07-04) — SWEEP COMPLETE

Wave 3 (player_gfx, pikachu, reload_sprites, overworld_text, wild_encounter_check) done.
All 3 waves complete; the pre-plan faithfulness audit is closed.

**reload_sprites.asm** — FAITHFUL, no tickets. **player_gfx.asm** — FAITHFUL throughout; its
only defect is the already-known cross-file collision (the live `LoadPlayerSpriteGraphics`
in overworld.asm is SCAFFOLD; the faithful copy here is inert/check-only) → handled by
OW-A.5 + OW-7.2 promotion (delete the scaffold, promote player_gfx, generate
RedBikeSprite/SeelSprite/SurfingPikachuSprite assets). Plus a stale comment ("CopyVideoData
does not exist" — it does, `src/home/copy2.asm`). 

**TICKET OW-A.11: pikachu.asm rectification** `[SWARM/Sonnet]` — check-only; blocks OW-7.2
- `_SpawnPikachu`/`TrySpawnPikachu`/`ApplyPikachuMovementData_` are documented SCAFFOLD
  (spawn state-machine + movement interpreter deferred — need Pikachu overworld gfx first).
  Bit-flag routines + `ShouldPikachuSpawn` + `Pikachu_IsInArray` are FAITHFUL.
- **Bug (fix before link):** the file-local WRAM placeholders (`wPikachuOverworldStateFlags`
  etc., `pikachu.asm:53-56`) were derived by MISREADING pret's placeholder label `wd431`
  (hex suffix mistaken for the address) — self-contradictory per the file's own anchor note.
  Re-derive against the PORT's own gb_memmap anchoring scheme (NOT pokeyellow-real values).
- `BANK_PikachuOverworld=0x3D` → `0x3F` (cosmetic in flat model, but factually wrong).
- Convention: move the `ApplyPikachuMovementData_` deferred `ret` body into a `*_stubs.asm`
  before linking.

**TICKET OW-A.12: overworld_text.asm rectification** `[SWARM/Sonnet]` — check-only
- `DisplaySignText` is SCAFFOLD: never inspects the resolved TX stream's first byte for
  pret `DisplayTextID`'s `TX_SCRIPT_*` ($F5-$FF) sentinels (home/text_script.asm:77-84) →
  PC/Mart/Prize signs (the primary Gen-1 "sign" path) would render the selector byte as
  garbage text. Wire the first-byte dispatch to the already-present `TextScript_*` routines.
- Doc bug: header claims "all GP registers preserved" but EBX is clobbered by
  `ShowTextStream`→`npc_dialog_wait_impl` — add `push/pop ebx` (or `pushad`/`popad`).
- Provenance defect (also in Stage 9): file cites `home/overworld_text.asm` but holds
  `home/map_objects.asm` routines; the 8 real `home/overworld_text.asm` labels
  (`TextScriptEnd` etc.) are UNPORTED — `TextScriptEnd` is already extern'd by
  trainer_engine.asm:128/785 → hard link failure on its promotion. Port the 8 labels + fix
  the header. Flip the `M72_OVERWORLD_TEXTSCRIPTS` ifdef only after the dispatch is wired.

**wild_encounter_check.asm** — routines mostly FAITHFUL (`StepCountCheck`, `AnyPartyAlive`,
`AllPokemonFainted`); `NewBattle` is documented SCAFFOLD + one UNFLAGGED omission (pret's
`BIT_DEBUG_MODE`+`B_PAD_B` encounter-suppress check). The value is its **call-graph map** for
enabling wild encounters, ordered: (1) wire `LoadWildData` into `LoadMapHeader.finishUp`
(= OW-A.5, cheap, populates grass/water rate+mon data — currently ZERO call sites); (2)
implement `IsPlayerCharacterBeingControlledByGame` + `HandleBlackOut` (hard link blockers);
(3) resolve `TryDoWildEncounter`'s externs to move wild_mons/wild_encounters off check-only;
(4) build the faithful post-battle `EnterMap` re-entry into `OverworldLoop` (= **OW-A.4**),
then flip `WILD_ENCOUNTERS_LIVE` on by default. So wild encounters are gated on the
EnterMap spine (OW-A.4) + the LoadWildData wiring (OW-A.5) — both already scheduled.

**OPEN QUESTION — gb_memmap.inc WRAM anchoring (pending user decision 2026-07-04):** the
pikachu audit's rgbasm/rgblink rebuild flagged a constant −0x2EC delta between gb_memmap.inc
D-block addresses and pokeYELLOW-real addresses (e.g. `W_PARTY_COUNT` 0xD162 vs Yellow 0xD44E),
hypothesizing a repo-wide error. BUT gb_memmap.inc uses pokeRED-family addresses with an
explicit internal-packing justification, and the linked port is self-consistent (party/bag
seed correctly). So this is most likely a DELIBERATE Red-derived self-consistent layout, not
a bug — the "correct" absolute addresses only matter for future save-file compat / pret
address-level cross-ref, not runtime. **Deferred to a user call:** (a) confirm Red-anchored
layout is intended (then no action; pikachu placeholders fixed to the port scheme), or (b) if
the port should match Yellow absolute addresses, that's a separate high-priority gb_memmap
verification workstream (rgbasm/rgblink diff vs unmodified pokeyellow), OUT of overworld scope.
