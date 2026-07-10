# Current Plan: Full `engine/overworld/` Port

**Status:** Stage 0 in progress (this document written 2026-07-01).
**Branch:** work lands directly on **`master`** — everything was folded into master
(user-confirmed 2026-07-09); the earlier `overworld-port` branch plan was dropped.

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
  translated faithfully; only terminal calls into **still-missing** subsystems
  (menus, battle UI) become named `TODO(faithful)` ret-stubs in `*_stubs.asm`
  files. Delete stubs as real routines land. **Audio is no longer a stub-leaf
  category** — see the next bullet.
- **UPDATED 2026-07-09 — Sound is LIVE; wire real audio calls, do NOT stub.**
  The audio engine now exists: `home/audio.asm` provides the real gateway
  (`PlaySound`, `PlaySoundWaitForCurrent`, `PlayMusic`, `PlayDefaultMusic`,
  `PlayDefaultMusicFadeOutCurrent`, `StopAllMusic`, `WaitForSoundToFinish`),
  backed by the translated engine (`src/audio/engine_1..4.asm` + `audio_hal.asm`
  + device shims). The former OW-1.9 `audio_stubs.asm` is **retired** (created
  `5727f316`, deleted when the real engine landed `fc74a70c`; already out of the
  Makefile — a stale `.o` may linger). **New policy:** every faithful routine
  that pret calls an audio routine from calls the **real** routine — no
  `; TODO-HW: audio HAL` no-op. This turns the previously-safe "sound-state
  polling → bounded-wait divergence" seams (elevator/healing-machine/fishing)
  back into faithful blocking waits on the real engine; drop those bounded-wait
  `; DIVERGENCE` shims where the real `WaitForSoundToFinish` now terminates.
  **Scope for THIS plan = the overworld surface only** (user directive
  2026-07-09): the battle/menus/evolution `; TODO-HW: audio HAL` no-ops are NOT
  this plan's problem. But this *does* mean **retreading already-landed overworld
  tickets to destub their audio** — the overworld files carrying dropped-audio
  no-ops that must be wired to the real gateway are enumerated in the new
  **"Stage A.14 — overworld audio destub"** ticket below. Faithfulness gate
  applies (`faithdiff` will now flag a *dropped* audio call as a real divergence,
  not a suppressed HAL boundary), and each rewired routine re-runs its FRAME.BIN
  baseline (audio no-ops don't change the rendered frame, so the 3 baselines must
  stay byte-identical — that is the destub tripwire).
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

## Cross-cutting defect — menu box-draw geometry + window compositor (was: "VRAM tile-slot management")

> **CORRECTION (2026-07-05, OW-A.2 P4):** the VRAM tile-slot hypothesis below is
> **DISPROVEN.** Ground-truth check: the box/border/space tiles `$79–$7F` are
> **byte-identical** in the text-box set (`gfx/font/font_extra.2bpp`, loaded at vChars2
> `$60`) and the HP-bar set (`gfx/font/font_battle_extra.2bpp`, loaded at `$62`), so
> `LoadHpBarAndStatusTilePatterns` overwrites those tiles with the SAME bytes — it never
> corrupts a border or a blank. Rendered menus confirm the borders are real border tiles
> (not stale HP-bar glyphs), and the corruption triggers **immediately** on the first menu
> — no battle / tile-clobber required. So this is NOT a sprite/VRAM tile-loader problem;
> OW-A.2's `wFontLoaded` reload was never going to fix it. The real defect is **menu-engine
> box-draw geometry** (mangled bag borders, missing options-menu bottom border) + the
> **canvas↔window compositor** (START menu "turns to grass" after a submenu round-trip =
> the menu window isn't re-composited, so the overworld BG shows through). Refiled as
> **TICKET OW-A.13**. The original (incorrect) analysis is kept below for the record.

**Symptom (menus-port branch):** every menu that draws a `TextBoxBorder` (START,
options, bag/items, trainer card, …) renders with corrupted borders / "grass"
blanks / missing bottom rows in the *live* build, while each screen's `DEBUG_*`
harness renders it perfectly. ~~Root cause is entirely VRAM tile-slot management~~
(**disproven — see correction above**) — the same early-bespoke tile handling this
reimpl replaces — so it is recorded here rather than fixed piecemeal in the menu code.

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

**TICKET OW-A.2: map_sprites.asm faithful rewrite** `[SOLO #4]` — **DONE 2026-07-05** (see Exit below)
- Pret: `engine/overworld/map_sprites.asm` (15 routines) + `data/maps/sprite_sets.asm`
  + `data/sprites/sprites.asm` + **`home/overworld.asm:InitSprites`/`ZeroSpriteStateData`/
  `DisableRegularSprites`/`LoadSprite` (:2137-2266)**.
- Target: `dos_port/src/engine/overworld/map_sprites.asm` (rewrite) + `overworld.asm`
  (add the home object-loader half).

- **SCOPE (user directive 2026-07-05): full de-bespoke to faithful, mirror pret's
  FILE MAPPINGS.** The current port `map_sprites.asm` is a total bespoke replacement
  that FUSES two pret responsibilities pret keeps in separate files:
  1. **Home object-loader** — reads the map-object binary → populates slot
     PICTUREID/MAPY/MAPX/movement/text + trainer cache. Pret = `home/overworld.asm`
     `InitSprites`(+`ZeroSpriteStateData`/`DisableRegularSprites`/`LoadSprite`),
     called from `LoadMapHeader:1892`. → belongs in port `overworld.asm`.
  2. **Tile/set loader** — the 15 pret `map_sprites.asm` routines, via the
     `InitMapSprites` wrapper called from `LoadMapData:1966`. → stays in `map_sprites.asm`.
- **Second bespoke layer — invented `wSpriteStateData2` fields (absorbed into A.2,
  user-confirmed 2026-07-05):** the port put `MOVEMENTBYTE2`@`0x1`, `ISTRAINER`@`0x9`
  (**collides with pret `ORIGFACINGDIRECTION`**), `TEXTID`@`0xA`. Pret keeps movement-byte-2
  + masked text-id in **`wMapSpriteData`** ($20) and trainer class/num in **`wMapSpriteExtraData`**.
  Faithful fix: add `wMapSpriteData`, relocate those fields, restore `0x9`=ORIGFACINGDIR,
  and update ALL readers — reaches into `movement.asm`, `pathfinding.asm`, and the port's
  own interaction routines (mandatory coupling; guarded by the 3 FRAME.BIN baselines).
- **GLITCH-POLICY CONSTRAINT (user directive 2026-07-05):** the bespoke engine
  *accidentally* introduced engine bugs (esp. **collision**) AND accidentally "fixed"
  some original bugs — both are undesirable divergences under the glitch policy. The
  faithful de-bespoke must **restore the original's exact behavior**, INCLUDING its bugs:
  do not silently keep a bespoke collision "fix." Any intentional deviation goes under a
  `; BUG(level):` + `%if BUG_FIX_LEVEL` guard (fixes) or a `; GLITCH:` + `; Safety:` tag
  (preserved exploitable glitches) — never a silent bespoke change. This applies to the
  collision-adjacent routines touched here (`IsNPCAtTargetBlock`, `CheckNPCInteraction`,
  and, when P3 reaches them, the movement/collision seams shared with `movement.asm`).
- **Sanctioned port extensions kept (`; DIVERGENCE`):** the toggleable-hidden gate at
  load (`IsToggleableHidden`), and the port-only interaction stack
  (`CheckNPCInteraction`/`ShowTextStream`/`IsNPCAtTargetBlock`/`CheckTrainerSight`/
  `TrainerEncounterFlow`) — pret's `IsSpriteOrSignInFrontOfPlayer` etc. are unported.

- **Phasing (reviewable sub-steps, check-in between each):**
  - [x] **P1 — infra + Tier-1 data (delivered via the re-scoped P3a/P3c sub-steps; see Exit):** `wSpriteSet`(11B)/
    `wMapSpriteData`($20)/`hVRAM_slot` WRAM + sprite-set constants; new generator
    `data/maps/sprite_sets.asm` → `assets/sprite_sets.inc`
    (`SpriteSets`/`MapSpriteSets`/`SplitMapSpriteSets`) + generated `SpriteSheetPointerTable`.
  - [x] **P2 — WRAM relocation (in-place) — DONE 2026-07-05 (5a1ae792):** move movement-byte-2 + masked text-id to
    a new flat `wMapSpriteData` (pret-faithful content), `ISTRAINER` off the pret
    `ORIGFACINGDIRECTION@0x9` collision (→ pret-unused `0xA`), update all readers
    (`movement.asm:343`, check-only `pathfinding.asm` accessor, `map_sprites.asm`
    interaction reads). **RE-SCOPE (2026-07-05):** the structural `InitSprites`
    extraction was pulled into P3 — the bespoke `InitMapSprites` entangles slot-population
    with VRAM-slot assignment (`FindOrAssignVramSlot`), so the home object-loader split
    and the faithful `_InitMapSprites` must land together (can't half-split cleanly).
    P2 does the WRAM layout in the still-bespoke loader so the field locations are already
    faithful when P3 moves the writer wholesale.
  - [~] **P3 — home object-loader + `map_sprites.asm` 15-routine faithful rewrite (together):**
    Sub-steps (check-in between each): **3a DONE 2026-07-05** — full-coverage
    `SpriteSheetPointerTable` + sprite-gfx generation (`tools/gen_all_assets.py`
    `generate_sprite_sheet_pointers()` → `assets/sprite_sheet_pointers.inc`, all 82
    sprite ids incl. outside-map fillers, indexed `(id-1)`, entry `dd flat_ptr, dd
    tilecount`; self-contained, not yet linked). Verified: standalone nasm-clean; 3
    FRAME.BIN baselines byte-identical (existing bespoke path untouched).
    **3b DONE 2026-07-05** — faithful home object-loader (`InitSprites` /
    `ZeroSpriteStateData` / `DisableRegularSprites` / `LoadSprite`, real routines) added
    to `overworld.asm` and wired into `LoadMapHeader` at the pret `:1892` point (gated on
    `BIT_BATTLE_OVER_OR_BLACKOUT`). `InitSprites` also writes `wNumSprites` (0xD4E0), which
    the bespoke never set — a latent omission `src/home/text_script.asm` reads (faithful
    restore, unread in baselines). The bespoke `InitMapSprites` stays the driver (its
    clear+repopulate in `LoadMapData` overwrites `InitSprites`' output), so this is
    redundant-but-byte-identical. **Harness fix (required):** the `DEBUG_TRANSITION`
    harness re-calls `LoadMapHeader` standalone (:431) but had OMITTED the `InitMapSprites`
    the real `.mapTransition` (:902/:913) pairs with it — harmless pre-3b, but post-3b that
    left `IMAGEBASEOFFSET` cleared → an NPC vanished (root-caused via DUMP.BIN: sprite slot
    state provably identical, divergence was the harness's un-paired re-load). Added the
    missing `call InitMapSprites` so the harness mirrors `.mapTransition`. Verified: nasm
    clean; `make check` clean; real SKIP_TITLE build links; 3 FRAME.BIN baselines
    byte-identical. All real `LoadMapHeader` sites pair with `InitMapSprites`
    (`LoadMapData` / `.mapTransition` / warp→`EnterMap`→`LoadMapData`), so the real game is
    safe; **user live smoke passed 2026-07-05** (real build boots Pallet Town normally).
    **3c DONE 2026-07-05** — faithful `_InitMapSprites` + the pret sprite-set routines
    (`InitOutsideMapSprites`/`GetSplitMapSpriteSetID`/`LoadSpriteSetFromMapHeader`/
    `CheckIfPictureIDAlreadyLoaded`/`CheckForFourTileSprite`/`LoadMapSpriteTilePatterns`/
    `ReloadWalkingTilePatterns`/`LoadStillTilePattern`/`LoadWalkingTilePattern`/
    `GetSpriteVRAMAddress`+`SpriteVRAMAddresses`/`ReadSpriteSheetData`/
    `LoadMapSpritesImageBaseOffset`/`GetSpriteImageBaseOffset`) as real routines in
    `map_sprites.asm`; the bespoke `InitMapSprites` slot-pop + `FindOrAssignVramSlot` +
    `LoadNPCSpriteTiles` retired; `InitMapSprites` is now a home wrapper (reset + toggleable
    gate + `_InitMapSprites`). Uses the P3a `SpriteSheetPointerTable` + `sprite_sets.inc`
    (swapped in for `npc_sprite_data_table.inc`). `wFontLoaded` upper-half reload in place.
    Callers repointed: interaction stack + `start_menu.asm` `LoadNPCSpriteTiles` →
    `ReloadWalkingTilePatterns`; `text_script.asm` already used `InitMapSprites`. Home-loader
    inlined (`CopyData`/`AddNTimes`/`FillMemory` → `rep movsb`/`imul`; `CopyVideoDataAlternate`
    → flat copy). Two DIVERGENCEs (tagged): (1) `InitSprites` writes the port `ISTRAINER`
    field the interaction stack reads (the retired bespoke set it; pret re-derives it);
    (2) `DisableRegularSprites` seeds `IMAGEINDEX=0` not pret's `$ff`. This has **zero
    real-game effect** — the first `UpdateSprites` frame's `InitializeSpriteStatus`
    overwrites `IMAGEINDEX=$ff` regardless of the seed, so `0`/`$ff` are live-identical; the
    seed only changes the STATIC pre-`UpdateSprites` DEBUG snapshot (`0` keeps NPCs visible
    there so the baseline still exercises NPC rendering). Restoring faithful `$ff` (harness
    `UpdateSprites` + NPC move-delay so NPCs don't wander in the snapshot) is **handed off to
    OW-A.7** (reopened follow-up) — see its FOLLOW-UP item + the DIVERGENCE block at
    `overworld.asm:DisableRegularSprites`.
    **Root-caused a subtle regression** (Pallet NPC vanished): faithful fixed-set VRAM assign
    gives GIRL/FISHER imageBaseOffset 5/6 (vs bespoke 3/4) — byte-identical render (tiles land
    at matching slots); the vanish was the `$ff` IMAGEINDEX issue above, found via a DUMP.BIN
    slot + shadow-OAM diff (slots correct, OAM had only the player). Verified: nasm + `make
    check` clean; real build links; **3 FRAME.BIN baselines byte-identical**. **Pending user
    live smoke** (NPCs render + dialog + menus + the Viridian old-man coverage fix). P4/3d =
    menu-corruption verification.
    `InitSprites`/`ZeroSpriteStateData`/`DisableRegularSprites`/`LoadSprite` → `overworld.asm`
    (wired into `LoadMapHeader:1892`), retiring the bespoke slot-pop; then `_InitMapSprites`,
    `InitOutsideMapSprites` (+`GetSplitMapSpriteSetID` Route-20 split), `LoadSpriteSetFromMapHeader`
    (VRAM slot = index-within-set), `CheckIfPictureIDAlreadyLoaded`, `CheckForFourTileSprite`
    (4-tile + Pikachu reserved slot), `LoadMapSpriteTilePatterns`, `ReloadWalkingTilePatterns`,
    `LoadStillTilePattern`/`LoadWalkingTilePattern` (**`wFontLoaded` upper-half reload**),
    `GetSpriteVRAMAddress`+`SpriteVRAMAddresses`, `ReadSpriteSheetData`,
    `LoadMapSpritesImageBaseOffset`, `GetSpriteImageBaseOffset`. `CopyVideoDataAlternate`
    → `; DIVERGENCE` (flat copy, per OW-A.1 asset-model precedent). Retire the fused bespoke.
  - [x] **P4 — verification DONE 2026-07-05:** 3 FRAME.BIN baselines byte-identical
    (BASELINE/TRANSITION/WALK_NORTH) across P3a/P3b/P3c; user live smoke passed (Pallet
    Town + NPCs + dialog + start-menu round-trip render, all 4 walk dirs). The
    **menu-corruption item did NOT resolve and is refiled** — investigation DISPROVED the
    plan's VRAM tile-slot hypothesis (the box/space tiles `$79–$7F` are byte-identical in
    the text-box set `font_extra.2bpp` and the HP-bar set `font_battle_extra.2bpp`, so
    `LoadHpBarAndStatusTilePatterns` never actually corrupts a border/blank; the borders
    render as real tiles). User-confirmed symptoms (grass-after-submenu, missing option-menu
    bottom border, mangled bag borders, triggering IMMEDIATELY with no battle) are a
    **menu-engine geometry + canvas↔window compositor** defect, a different subsystem from
    this sprite tile loader. → **TICKET OW-A.13** (final round-off). See the corrected
    cross-cutting note above.
- **Baselines captured (HEAD aa128d2c):** BASELINE `b4e48c46`, TRANSITION `747d824c`,
  WALK_NORTH `58d005ce` (manifest in session scratchpad; BASELINE has the 2 Pallet Town NPCs).
- **Exit: DONE 2026-07-05.** 15 pret map_sprites routine labels real (+ the 4 home
  object-loader routines InitSprites/ZeroSpriteStateData/DisableRegularSprites/LoadSprite);
  faithful sprite-set VRAM machinery + `wFontLoaded` upper-half reload; bespoke
  InitMapSprites/FindOrAssignVramSlot/LoadNPCSpriteTiles retired; full-coverage
  SpriteSheetPointerTable generated; NPC rendering regression-free (3 baselines
  byte-identical + smoke). One tagged real-game-neutral divergence handed to OW-A.7
  (`DisableRegularSprites` `$ff` seed). Commits: P1 962b4acb, P2 5a1ae792, P3a d637b09a,
  P3b cc2a0d11, P3c d4a43413, P3c-doc 9a26d11a.

**TICKET OW-A.3: label restoration / de-fold pass** `[Opus solo]` — **DONE 2026-07-05**
- **SCOPE UPGRADE (user directive 2026-07-05):** promoted from "add alias labels" to **actually
  de-fold merged pret routines into separate routines like pret** (not aliases). Ran as a full
  7-file sweep, not per-file swarm.
- **CLOSED OUT.** 3 genuine in-file folds found + split; `Func_4d0a` documented; all other
  "missing" pret labels accounted for as out-of-A.3-scope (see below). Verified: `make check`
  clean; full SKIP_TITLE build links; 3 FRAME.BIN baselines (BASELINE/TRANSITION/WALK_NORTH)
  BYTE-IDENTICAL to the reference manifest — including WALK_NORTH, which exercises the real
  movement primitives, so the de-folds are provably control-flow-equivalent.
- <details><summary>De-folds performed + full accounting</summary>

  - **movement.asm — `UpdateNonPlayerSprite` / `UpdateNPCSprite`:** the port had fused pret's
    dispatcher (`UpdateNonPlayerSprite`, sprite_collisions.asm:34 — hTilePlayerStandingOn +
    scripted-vs-freeroam route) and body (`UpdateNPCSprite`, movement.asm:99 — the walk state
    machine) into one routine. Split: dispatcher now ends `jz UpdateNPCSprite` / `jmp
    DoScriptedNPCMovement`; `UpdateNPCSprite:` is a separate routine at the old `.notScripted`.
  - **overworld.asm — `AdvancePlayerSprite` / `_AdvancePlayerSprite`:** the port had the engine
    body directly under `AdvancePlayerSprite` with NO home wrapper. Split: body renamed
    `_AdvancePlayerSprite`; added the faithful `AdvancePlayerSprite` home wrapper (saves
    `wUpdateSpritesEnabled`, forces `$FF` for the advance, restores) — this reinstates a
    previously-documented Phase-2 omission. **BEHAVIOR NOTE:** this is a live-walk-path change;
    WALK_NORTH baseline is byte-identical (flag already enabled during walking → force+restore is
    neutral). **Visual smoke test CONFIRMED OK (user, 2026-07-05)** — no NPC-animation timing shift.
  - **overworld.asm — `OverworldLoop` / `OverworldLoopLessDelay`:** split the `.lessDelay` local
    into a real `OverworldLoopLessDelay:` label (pret's delay-skipping loop entry); updated the
    lone `jmp OverworldLoop.lessDelay` ref + added a `global`.
  - **movement.asm — `Func_4d0a`:** DOCUMENTED (not split). It's inlined into the *bespoke* native
    `DetectCollisionBetweenSprites` rewrite (thresholds in stack slots + DH, not pret HRAM temps),
    so it has no callable boundary — extracting it would add an unfaithful seam. Provenance note
    added at the `.pika_*` block.
  - **Everything else in the label diffs is NOT a fold** and is correctly out of A.3 scope:
    unported subsystems (surf/bike/battle/scripted-movement → OW-A.6/Stage 2/4/5), routines that
    live in other port files (`ExtraWarpCheck`→warp_check, `CheckForTilePairCollisions`→ledges,
    `StepCountCheck`→wild_encounter_check, `IsPlayerJustOutsideMap`→own file, `RunMapScript`→
    run_map_script), generated-include data (`EmotionBubbles`/emotes → assets/emotes.inc),
    renderer-deleted redraw rings (`CopyMapViewToVRAM`, `Schedule*RowRedraw` — "rings are gone"),
    externs (`ResetButtonPressedAndMapScript`, `LoadHoppingShadowOAM`→overworld_stubs per A.10),
    flat-model no-ops (`SwitchToMapRomBank`, `SpritePositionBankswitch`), deferred shadow-OAM data
    (`LedgeHoppingShadow*`), and bespoke replacements (`IsSpriteInFrontOfPlayer`/`SignLoop`→
    `CheckNPCInteraction`, `CheckWarpsCollision`→`CheckWarpTile`, `WarpFound2`→`.warpTransition`).
    `trainer_engine.asm`, `wild_mons.asm`, `hidden_events.asm` had no in-file folds.
  </details>

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
- **A.4(b) DONE (2026-07-05):** `.warpTransition` now `jmp EnterMap` (was `jmp OverworldLoop`),
  faithful to pret `WarpFound2.done` (`home/overworld.asm:517`, `jp EnterMap`) — so the full reset
  ladder (wJoyIgnore gate, LoadMapData reload, ClearVariablesOnEnterMap, fly/dungeon/battle-return
  resets, UpdateSprites, CUR_MAP_LOADED_1/2) re-runs on every warp. The port's pre-warp work
  (wCurMap/wLastMap, LoadWarpDestination, view/scroll reset, door flags) mirrors WarpFound2's body;
  EnterMap's LoadMapData then re-loads for the destination. Double InitMapSprites (port `.warpTransition`
  + EnterMap→LoadMapData) is redundant-but-harmless (idempotent slot repopulate). `.battleOccurred`
  wired to route to the now-existing spine but left dead (WILD_ENCOUNTERS_LIVE off; full tail = OW-A.6).
  - **SCOPE CORRECTION vs ticket text (pret ground truth):** the ticket said route
    `.warpTransition`/**`.mapTransition`** through EnterMap, but pret does NOT route connection
    crossings through EnterMap — `CheckMapConnections` ends `jp OverworldLoopLessDelay`
    (`home/overworld.asm:660`). The port's `.mapTransition` already exits to `OverworldLoop.lessDelay`,
    which is faithful; rerouting it would be an UNfaithful regression. **`.mapTransition` left untouched.**
  - **Verification:** `make check` clean; the 3 FRAME.BIN baselines (BASELINE/TRANSITION/WALK_NORTH)
    re-captured BYTE-IDENTICAL to the pre-change manifest (render/connection path provably untouched —
    the DEBUG harnesses don't exercise warps and dump-and-exit before the reset ladder). MCP live-warp
    test was BLOCKED by a pre-existing dosbox-mcp code-breakpoint bug (BPLM uses raw pkmn.map VMA as
    linear; never trips under CWSDPMI — user to fix in a separate session), so verified instead by
    **user visual smoke on the real build: warp transition succeeds** (same MCP-deferred + live-smoke
    posture as A.4(a)).
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
- **A.5 CLOSED OUT (2026-07-05).** All items below resolved:
- `LoadMapHeader` (`home/overworld.asm:1798-1926`): ~~call `LoadWildData`~~ DONE; DONE (wip
  c183dd67): `res BIT_NO_PREVIOUS_MAP` + `MarkTownVisitedAndLoadToggleableObjects` +
  `SchedulePikachuSpawnForAfterText` `; TODO(faithful)` markers added; `wCurrentMapHeight2/Width2`
  ordering verified (port derives them in `CheckMapConnections`, its only consumer, set-before-use —
  DIVERGENCE noted). The `BIT_NO_PREVIOUS_MAP` **early-return stays DEFERRED** (documented): it's only
  reached post-continue-from-save, and the port's `.dsv` restore doesn't repopulate `wCurMapHeader`, so
  skipping the header reload there would break the map. Restore with the save/continue flow (live-verify).
- `LoadMapData` (`:1961-1988`): DONE — removed the duplicate `LoadScreenRelatedData` call (pret calls it
  once, `:1967`; the port's copy is idempotent and its `LoadCurrentMapView` subsumes pret's trailing
  `CopyMapViewToVRAM`); relabeled `GBPalNormal` as the `RunPaletteCommand SET_PAL_OVERWORLD` stand-in
  and moved the music `; TODO-HW` note to pret's tail position. Baselines byte-identical.
- `LoadWarpDestination` (`:449-517`): DONE — added a `DIVERGENCE (deferred faithfulness)` header block
  enumerating each dropped pret `WarpFound2` piece (`ROCK_TUNNEL_1F` fade, `PlayMapChangeSound`,
  `IsPlayerStandingOnWarpPadOrHole`→`BIT_FLY_WARP`+`LeaveMapAnim`, `SetPikachuSpawn*`,
  `wMapPalOffset` reset, `wWarpedFromWhichWarp/Map`) with its subsystem/HW deferral reason.
- `CopyMapViewToVRAM`: DONE — deleted the dead `global` (exported an undefined symbol) and converted the
  bodyless "faithful translation" doc block to a `DIVERGENCE: obsoleted by native render_bg` note.

**TICKET OW-A.6: OverworldLoop wild/surf gaps** `[SWARM or folds into Stage 4]` — DIVERGENT
- On-turn wild-encounter check `NewBattle` (pret `:196-199`) dropped → turning in grass
  can't trigger an encounter; add it, gate behind a `WILD_ENCOUNTERS_LIVE` flag (S).
- Surfing entirely absent (`.surfing`/`CollisionCheckOnWater` `:206-226`, `DoBikeSpeedup`
  `:243`) — larger; may fold into the boulder/field-move Stage 4 work. Effort M/L.

**TICKET OW-A.7: movement.asm NPC faithfulness fixes** `[SWARM/Sonnet]` — **DONE 2026-07-05**
- **CLOSED OUT.** All 5 items resolved (make check clean; full build links; 3 FRAME.BIN
  baselines byte-identical — the behavioral fixes are latent for the captured scenarios,
  which don't exercise edge-walking/item-balls/captain/sprite-collisions, so no render regression):
  1. Status-4 dispatch: added `cmp al,4 → Func_5357` in `UpdateNonPlayerSprite` and ported
     `Func_5357` (finish-step: pixel-advance by 2×step, dec WALKANIMCOUNTER, on expiry →
     status 1 scripted or status 2 random w/ fresh delay + cleared step vectors). Global added.
  2. `CanWalkOntoTile`: added pret's off-screen pixel bound (YPIXELS+4+Δ ≥ $80 / XPIXELS+Δ ≥ $90
     → blocked) after the STAY check — was missing, so WALK/STAY NPCs had no east/south limit.
  3. `MakeNPCFacePlayer`: added the `BIT_NO_NPC_FACE_PLAYER` (wStatusFlags3) guard (S.S. Anne
     captain); documented the `wPlayerDirection`→`W_SPRITE_PLAYER_FACING_DIR` field substitution
     (`; DIVERGENCE`, equivalent for a standing spoken-to player).
  4. `DetectCollisionBetweenSprites`: narrowed the COLLISIONDATA clear from `dword` to `word`
     (0x0C/0x0D only) — pret never resets COLLISIONBITMAP_HI/LO (0x0E/0x0F), which accumulate
     via OR; the dword zero was wiping them each call. Fixed the backwards axis-label comments
     (final layout DH[3:2]=Y, DH[1:0]=X per pret sprite_collisions.asm:293; `.use_ybits`/
     `.pika_ybits` are misnomers — they select the X bits).
  5. `.randomMovement`: documented the port-only MAPY/MAPX clamp as a `DIVERGENCE` (guards
     GetTileSpriteStandsOn from OOB reads; narrower than CheckSpriteAvailability's visible zone —
     reconcile/delete when the map-data extension removes the OOB region).
- **FOLLOW-UP (reopened 2026-07-05, handed off from OW-A.2 P3c) — NPC initial move-delay +
  restore faithful `DisableRegularSprites=$ff`:** `.randomMovement` (movement.asm:307) makes a
  status-1 WALK NPC attempt a walk EVERY frame with no startup delay, so a fresh NPC starts
  moving on the second `UpdateSprites` frame after a map load (the bespoke loader masked this by
  seeding `MOVEMENTDELAY=30`; pret uses a per-NPC random move-delay/probability the port hasn't
  ported). Because of this, OW-A.2 P3c had to keep the PORT's `DisableRegularSprites` seeding
  `IMAGEINDEX=0` (visible) instead of pret's `$ff` (hidden-until-init): the two are
  **real-game-identical** (the first `UpdateSprites` frame's `InitializeSpriteStatus`
  overwrites `IMAGEINDEX=$ff` regardless — see the DIVERGENCE block at
  `overworld.asm:DisableRegularSprites`), but `$ff` hides NPCs in the STATIC pre-`UpdateSprites`
  DEBUG snapshot, and restoring `$ff` cleanly requires (a) the DEBUG_TRANSITION harness to run
  `UpdateSprites` like `EnterMap`, and (b) this move-delay port so the NPCs don't immediately
  wander (which would make the baseline dynamic/nondeterministic). Do both here, then flip
  `DisableRegularSprites` to `$ff`, add the harness `UpdateSprites`, and re-capture the 3
  reference baselines (they become post-`UpdateSprites` snapshots). Zero in-game behavior change
  is at stake — this is faithfulness + a cleaner move-delay, not a live bug.

<details><summary>Original ticket items (all done)</summary>

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

</details>

**TICKET OW-A.8: overworld.asm marker/hygiene sweep** `[SWARM/Sonnet, mechanical]` — **DONE 2026-07-05** (Opus solo)
- **CLOSED OUT.** All 6 items resolved (nasm clean; full SKIP_TITLE build links; 3 FRAME.BIN
  baselines — BASELINE/TRANSITION/WALK_NORTH — byte-identical to the reference manifest, so
  the restored/marked logic is latent for the captured scenarios: no render regression).
- <details><summary>Original items (all done)</summary>

  - `CollisionCheckOnLand`: **DONE** — restored the `wSimulatedJoypadStatesIndex != 0` no-collision
    bypass (provably inert today: nothing sets the index until scripted movement lands) and the
    `wSpritePlayerStateData1CollisionData & wPlayerDirection` quick-reject (bit layouts verified
    identical: bit0=RIGHT/bit1=LEFT/bit2=DOWN/bit3=UP — the DH[3:2]/DH[1:0] write in
    `DetectCollisionBetweenSprites`; can only ADD a block `IsNPCAtTargetBlock` would also catch).
    Added `; TODO-HW: audio HAL` at `.blocked` for the dropped `SFX_COLLISION`. Documented that
    `IsNPCAtTargetBlock` is the bespoke replacement for pret's `IsSpriteInFrontOfPlayer` + the
    dropped `res BIT_FACE_PLAYER`/`hTextID`/Pikachu-collision-counter tail.
  - `ResetMapVariables`: **DONE** — restored `wMapViewVRAMPointer = GB_TILEMAP0` (vestigial under
    the native renderer but kept in lockstep with the other reset sites; matches pret's inline
    reset). Header comment now names the port equivalent.
  - `PlayerStepOutFromDoor`: **DONE** — restored the entry `res BIT_UNKNOWN_5_1` (new
    `BIT_UNKNOWN_5_1 equ 1` in gb_memmap.inc) and the 3 simulated-joypad field zeroes
    (`wUnusedOverrideSimulatedJoypadStatesIndex`/`wSimulatedJoypadStatesIndex`/`wSimulatedJoypadStatesEnd`)
    in `.notStandingOnDoor`, with the AreInputsSimulated-leak rationale.
  - `GetTileInFrontOfPlayer`: **DONE (note)** — confirmed the ONLY port caller (CollisionCheckOnLand)
    needs just the tile; the D/E target-coord side-outputs feed SignLoop (sign reading) + the
    hidden-event coord scan, neither live. Added an explicit DEFERRED note (dependents self-derive
    front coords from wYCoord/wXCoord + facing when they land).
  - `LoadTilesetHeader`: **DONE (copy)** — added a `TilesetCounterTiles` table (3 bytes × 25
    tilesets, from pret `tileset_headers.asm`) and a copy into the existing
    `wTilesetTalkingOverTiles` WRAM slot. Not yet read by the bespoke CheckNPCInteraction, but
    correct for when talking-range-over-counter lands.
  - `CheckMapConnections`: **DONE (markers)** — the reload actually lives at
    `OverworldLoop.mapTransition` (pret inlines it in `.loadNewMap`); added deferred markers there
    for the dropped `PlayDefaultMusicFadeOutCurrent` (TODO-HW audio) + `RunPaletteCommand(SET_PAL_OVERWORLD)`
    (Phase-5 palette; DMG-green today) + the Pikachu spawn set, plus a cross-reference note at
    CheckMapConnections `.loadNewMap`.
  </details>

**TICKET OW-A.9: trainer_engine.asm ABI/faithfulness fixes** `[SWARM/Sonnet]` — **DONE 2026-07-05** (unblocks OW-7.2 promotion)
- **CLOSED OUT.** trainer_engine.asm assembles clean. Resolved:
  1. **CRITICAL landmine defused:** `TrainerWalkUpToPlayer` distance sites (`:441,453,465,477`)
     `shl al,4`→`shr al,4` — the value is a block-aligned pixel distance (multiple of $10) so
     pret's `swap a` is a DIVIDE; the old `shl` overflowed AL→0 → dec → $FF steps → 255-byte
     FillMemory into the 10-byte `wNPCMovementDirections2`. The slot-offset `swap` sites (423/
     500/697/1073) correctly kept `shl` (verified — they're ×16, not ÷16).
  2. `LoadGymLeaderAndCityName`: made pret-faithful — dst was in EDI (CopyData reads dst from
     DX → wrote garbage) AND the entry `push esi/pop esi` restored the city src as the leader
     src. Now `push edx / pop esi` + dst GB offset in EDX, matching pret's push de/pop hl.
  3. `GetTrainerInformation`: 3→2 BCD-byte copy — pret's `wTrainerBaseMoney` is a 2-byte dw and
     pret keeps only the top 2 BCD bytes (Gen-1 quirk); the 3-byte copy diverged AND overflowed
     into wTrainerBaseMoney+2.
  4. `PlayTrainerMusic`: named `; TODO-HW` markers for the dropped `wAudioFadeOutControl` /
     `wAudioROMBank` / `wAudioSavedROMBank` writes (audio HAL, Phase 3).
  5. `GetSpritePosition1/2` + `SetSpritePosition1/2`: added the 4 non-underscored bank-wrapper
     trampolines (flat-model direct jmps to the `_` versions), globals added.
  6. `EmotionBubble`: **gfx wired + load path fixed (2026-07-05).** Added `tools/gen_emotes.py`
     (Tier-1 2bpp passthrough of pret `gfx/emotes/*.2bpp` → `assets/emotes.inc`,
     `EmotionBubbles`/`EmotionBubbleGfx`), `%include`d into trainer_engine.asm (extern removed),
     Makefile rule + `trainer_engine.o` dep + assets list. Fixed the gfx-load bugs: emote stride
     `*16`→`*64` (EMOTE_BUBBLE_BYTES; pret swap+4×add), CopyVideoData register ABI (src→EDX,
     dst→ESI, count→BL — was all wrong), and the VRAM target `GB_VCHARS1_TILE78` `$8780`→
     `GB_VFONT+$780` ($8F80 = OBJ tile $F8, matching the OAM block). `CopyVideoData` was already
     ported (stale note corrected). SOLE remaining gap: the `WriteOAMBlock` address-model mismatch
     (flat OAM block vs EBP-relative src) — deferred (EmotionBubble is check-only, no live caller).
  7. `TrainerEndBattleText`: converted the vague TODO to an explicit KNOWN-BROKEN/DEFERRED note
     (TX_ASM $08 is a no-op skip → dead `_asm` tail + parse run-on; also needs the unported
     `_TrainerNameText` Tier-1 text; two unblock paths documented).

<details><summary>Original ticket items (all done/deferred as noted)</summary>

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

</details>

**TICKET OW-A.10: wave-2 tagging + stub-filing hygiene** `[SWARM/Sonnet, mechanical]` — **DONE 2026-07-05** (Opus solo)
- **CLOSED OUT.** Both files rectified (nasm clean on all 4 touched files; `make check` clean;
  full SKIP_TITLE build links — `ledges.o` correctly stays check-only/out-of-link; 3 FRAME.BIN
  baselines BYTE-IDENTICAL to the reference manifest — pure markers + a stub relocation, zero
  live-path change).
- <details><summary>Original items (all done)</summary>

  - `warp_check.asm` `IsWarpTileInFrontOfPlayer`: **DONE** — the omitted `SS_ANNE_BOW` special
    case is now a `; DIVERGENCE:` block (documents pret's `IsSSAnneBowWarpTileInFrontOfPlayer`
    tile `$15`→CF bypass of the per-facing scan) + a `; TODO(SS-Anne):` for the entry-dispatch to
    add when `MAP_SS_ANNE_BOW` lands; the pre-populated-`wTileInFrontOfPlayer` reliance is now a
    `; PROJ:` tag (was prose) with a restore-the-`_GetTileAndCoordsInFrontOfPlayer`-prime note for
    a future second caller. The `overworld.asm` heuristic informational note was **converted to a
    marker at the code site** (`.warpTransition`, ~L825): `; DIVERGENCE` + `; TODO(edge-maps):`
    switch the `W_CUR_MAP < FIRST_INDOOR_MAP_ID` test to `call CheckIfInOutsideMap` (already global
    + faithful) for Route 23 / Plateau (PLATEAU-tileset maps above FIRST_INDOOR_MAP_ID misclassify).
  - `ledges.asm` `LoadHoppingShadowOAM`: **DONE** — the no-op stub moved OUT of the pret-mirroring
    `ledges.asm` into `overworld_stubs.asm` (`global` + full header + `TODO(retire)`), per the stub
    convention; `ledges.asm` now carries an `extern LoadHoppingShadowOAM` with a retirement note.
    Real impl (shadow tile→vChars1 $7F + 2 shadow-OAM slots) still M, blocked on `PrepareOAMData`
    shadow-slot support. Carry-forward (surf/`CollisionCheckOnWater` must prime `wTileInFrontOfPlayer`
    before `CheckForJumpingAndTilePairCollisions`) recorded here for OW-A.6/Stage 4.
  </details>

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

**TICKET OW-A.14: overworld audio destub** `[SOLO — retread; user directive 2026-07-09]` `[x] COMPLETE 2026-07-09` (see the COMPLETE note at the end of this ticket)
- **Why now:** the audio engine landed after most of Stage A/1 was written, so those
  tickets faithfully translated control flow but left every audio leaf as a
  `; TODO-HW: audio HAL (Phase 3)` no-op. The gateway is now real (`home/audio.asm`:
  `PlaySound`/`PlaySoundWaitForCurrent`/`PlayMusic`/`PlayDefaultMusic`/
  `PlayDefaultMusicFadeOutCurrent`/`StopAllMusic`/`WaitForSoundToFinish`). This ticket
  retreads the **overworld surface only** (battle/menus/evolution audio is out of scope)
  and wires the dropped calls back to the real routines, faithful to pret.
- **Verified available (2026-07-09):** SFX/MUSIC ids in `assets/audio_constants.inc`
  (`SFX_LEDGE`=0xA2, `SFX_COLLISION`=0xB4, `SFX_GO_INSIDE`/`_OUTSIDE`, …); audio WRAM in
  `gb_memmap.inc` (`wAudioFadeOutControl` 0xCFC6, `wAudioROMBank` 0xC0EF,
  `wAudioSavedROMBank` 0xC0F0, `wNewSoundID` 0xC0EE, `wMapMusicSoundID`/`ROMBank`);
  `PlayDefaultMusicFadeOutCurrent` is a real global.
- **Sub-dependency:** `PlayMapChangeSound` (pret home/audio.asm) is **NOT yet ported**
  (no global). The door/warp `PlayMapChangeSound` sites (`overworld.asm:2971`) need it
  translated first (small home routine: SFX_GO_INSIDE/OUTSIDE selection) OR a scoped
  `overworld_stubs.asm` ret-stub with a clear TODO — decide at that site.
- **Sites (enumerated 2026-07-09):**
  - `ledges.asm:227` — **already calls** `PlaySound SFX_LEDGE`; just stale
    `; TODO-HW(audio): stub` comment + hand-`equ SFX_LEDGE 0xB6` (WRONG — real id is
    0xA2 in audio_constants.inc) + stale `extern PlaySound ; …move_effect_helpers.asm
    (stub, linked)` comment (retired file). → drop the local equ, source from
    audio_constants, fix both extern comment and the site comment. LOW risk.
  - `trainer_engine.asm:825-830,111,124-125` — calls to StopAllMusic/PlaySound/
    WaitForSoundToFinish already present but the `wAudioFadeOutControl`/`wAudioROMBank`/
    `wAudioSavedROMBank` writes in `PlayTrainerMusic` are dropped; extern comments stale
    (point at retired stub). → restore the 3 audio-state writes faithfully; fix externs.
  - `player_gfx.asm:277,320` — `PlayDefaultMusic` dropped (pret `jp`/`call
    PlayDefaultMusic`). → wire the real call.
  - `overworld.asm` — genuinely-dropped calls: `PlayDefaultMusicFadeOutCurrent` map-load
    tail (`:931`, `:1241`, `:3242`) gated on `!(DUNGEON_WARP|FLY_WARP) && !BIT_NO_MAP_MUSIC`;
    `SFX_COLLISION` on the blocked-move bump (`:2132`); `PlayMapChangeSound` door/warp
    (`:2971`, needs the sub-dependency above); music-selection (`:2408`). HOT PATHS
    (map-load / warp / collision) — judgment-heavy SOLO, per-site check-in.
- **Verification (fidelity harness — mandatory):** audio no-ops don't change the rendered
  frame, so the **3 FRAME.BIN baselines (BASELINE/TRANSITION/WALK_NORTH) must stay
  byte-identical** after each destub — that's the tripwire proving control flow/render is
  untouched. Re-capture from HEAD at session start (baselines are ephemeral). Run
  `tools/faithdiff <Label>` on each touched pret routine (a *dropped* audio call is now a
  real divergence, not a suppressed HAL boundary) + `tools/lint_pret_labels` (catches the
  stale extern comments). Live audio (does it actually play) is a `DEBUG_AUDIO`/live-smoke
  check, not a baseline check.
- **Phasing (safest first, check-in between):**
  - **P1 `ledges.asm` DONE 2026-07-09** — dropped the wrong hand-`equ SFX_LEDGE 0xB6`,
    sourced the real id (0xA2) from `assets/audio_constants.inc`, fixed the stale
    `extern PlaySound` comment (→ real `home/audio.asm` gateway) + the site comment.
    Check-only file; nasm + `make check` clean.
  - **P2 `player_gfx.asm` DONE 2026-07-09** — `ForceBikeOrSurf` now tail-`jmp
    PlayDefaultMusic` (pret `jp`); `StopBikeSurf` dungeon-warp branch `call
    PlayDefaultMusic`; `extern PlayDefaultMusic` added. Check-only; nasm clean.
  - **P3 `trainer_engine.asm` DONE 2026-07-09** — restored the dropped
    `wAudioFadeOutControl=0` + `wAudioROMBank`/`wAudioSavedROMBank=MUSIC_MEET_EVIL_TRAINER_BANK`
    writes in `PlayTrainerMusic` (**load-bearing now** — the real engine selects the song
    table by `wAudioROMBank`, `home/audio.asm:PlaySound`); fixed 3 stale externs +
    line-778 comment. Check-only; nasm clean.
  - **P4a `overworld.asm` SFX_COLLISION DONE 2026-07-09** — `CollisionCheckOnLand.blocked`
    now plays `SFX_COLLISION` on the bump with pret's CHAN5 "already playing" guard, before
    the register pops (which restore PlaySound's clobber); `stc` lands after.
  - **P4b `overworld.asm` map-music subsystem DONE 2026-07-09** — new Tier-1 generator
    `tools/gen_map_songs.py` → `assets/map_songs.inc` (`MapSongBanks`, 249 maps, from pret
    `data/maps/songs.asm`; bank = `MUSIC_*_BANK`, col1↔col2 correspondence verified) wired
    into `make assets` + `overworld.o` prereq + linked in `.rodata`. `LoadMapHeader` now
    loads `wMapMusicSoundID`/`wMapMusicROMBank` from `MapSongBanks[wCurMap]`; `LoadMapData`
    tail runs `UpdateMusic6Times`+`PlayDefaultMusicFadeOutCurrent` gated on
    `!(DUNGEON_WARP|FLY_WARP) && !NO_MAP_MUSIC` (added `BIT_NO_MAP_MUSIC=1` to gb_memmap.inc);
    the connection-crossing `.mapTransition` runs `PlayDefaultMusicFadeOutCurrent` after
    `LoadMapHeader` (pret `.loadNewMap`, unconditional). Externs: `PlaySound`,
    `PlayDefaultMusicFadeOutCurrent`, `UpdateMusic6Times`.
  - **P4 VERIFICATION DONE 2026-07-09** — `make check` clean; full SKIP_TITLE link OK (new
    externs + `MapSongBanks` resolve); **`goldencheck overworld_pallet` PASS** (TILEMAP/VRAM/OAM
    byte-identical to mGBA ground truth — the boot map-load path runs the new music tail +
    header load + the real audio engine, headless, without perturbing the render or hanging);
    `faithdiff` on `CollisionCheckOnLand`/`LoadMapData`/`LoadMapHeader`/`PlayTrainerMusic`/
    `ForceBikeOrSurf`/`StopBikeSurf` shows the audio additions **match pret** (absent from the
    ADDED/DROPPED diff; remaining diffs are pre-existing sanctioned banking/renderer/Phase-5
    divergences); `lint_pret_labels` 0 violations. `PlayTrainerMusic`'s `DROPPED [wNewSoundID]`
    is the port's established PlaySound-id-in-AL ABI (PlaySound `mov bh,al` @ home/audio.asm:231),
    same for every port PlaySound caller — not a regression.
  - **P4c `PlayMapChangeSound` DONE 2026-07-09** — ported the pret home routine into
    `overworld.asm` (consolidated, allowlisted): FACILITY/CEMETERY tileset exclusion, then
    the door-tile `$0b` check → SFX_GO_INSIDE else SFX_GO_OUTSIDE; `jp GBFadeOutToBlack` tail
    is a deferred `; TODO-HW: palette` (Phase 5). Wired **before** `LoadWarpDestination` in
    `.warpTransition` (which now calls `LoadMapHeader` → destination tileset/tilemap/music, so
    the call must precede it to read the SOURCE door tile, faithful to pret WarpFound2). Added
    local `FACILITY`/`CEMETERY`/`OVERWORLD_DOOR_TILE` constants; allowlist entry added.
    `; PROJ`: the `lda_coord 8,8` → `(PLAYER_STANDING_ROW-1, PLAYER_STANDING_COL)` row
    projection + pre-EnterMap tilemap timing are unverified (no golden warp scenario) — the
    inside/outside jingle selection needs MCP live-warp verification (a wrong projection only
    mis-picks the jingle). faithdiff clean but for the intentional `GBFadeOutToBlack` deferral;
    `make check` clean; **goldencheck overworld_pallet PASS**; `lint_pret_labels` 0 violations.
- **OW-A.14 COMPLETE 2026-07-09** — zero `; TODO-HW: audio HAL` no-ops remain in
  `engine/overworld/*.asm` + `player_gfx.asm`; every overworld audio leaf calls the real
  gateway; the map-music subsystem (`MapSongBanks` + header load + entry/connection fades) is
  live; faithdiff clean/justified on every touched label; goldencheck PASS; lint 0. One `; PROJ`
  follow-up: P4c door-jingle projection → MCP live-warp verification when the dosbox-mcp
  code-breakpoint bug is fixed.

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

**TICKET OW-2.1: movement.asm scripted chain** `[SOLO #1]` — **CORE DONE 2026-07-09**
- Pret: `engine/overworld/movement.asm` (remaining routines)
- Checklist:
  - [x] Scripted-movement core ported (the Oak-cutscene path): `DoScriptedNPCMovement`,
        `InitScriptedNPCMovement`, `GetSpriteScreenYPointer`/`GetSpriteScreenXPointer`/
        `GetSpriteScreenXYPointerCommon`, `AnimScriptedNPCMovement`,
        `AdvanceScriptedNPCAnimFrameCounter` (all real globals in movement.asm).
        `Func_5337`/`Func_5349`/`Func_5357`/`Func_5274` already existed (OW-A.7).
  - [x] **Dispatch-gate rebuild:** replaced the port's bespoke global
        `BIT_SCRIPTED_NPC_MOVEMENT` (bit-0) gate with pret's per-slot
        `wNPCMovementScriptSpriteOffset == hCurrentSpriteOffset` compare
        (`UpdateNonPlayerSprite`); `DoScriptedNPCMovement` gates internally on
        `BIT_SCRIPTED_MOVEMENT_STATE` (wStatusFlags5 bit 7). Inert by default
        (offset 0 = player slot, never matches an NPC). Documented in-code.
  - [x] `overworld_stubs.asm:DoScriptedNPCMovement` ret-stub deleted.
  - [x] WRAM/HRAM added to gb_memmap.inc: `wNPCMovementDirections2(+Index)`,
        `wScriptedNPCWalkCounter`, `wNPCMovementScriptSpriteOffset`,
        `BIT_INIT_SCRIPTED_MOVEMENT`, `hSpriteVRAMSlotAndFacing`/`hSpriteAnimFrameCounter`
        (port-assigned scratch, pret address not load-bearing).
  - [x] Audit omissions (`Func_5357` status-4 dispatch, `MakeNPCFacePlayer` guard)
        — already fixed in OW-A.7.
  - [x] **Func_5288 tail — DONE 2026-07-10 (analysis + full port).** The 2026-07-09
        framing was corrected by the analysis: `Func_5288` is NOT a separate item-ball
        path — it sits **inline in the MoveSprite scripted-movement chain**
        (`.asm_4ecb`), which the port's `UpdateNPCSprite` had skipped entirely
        (`jmp .ret`). Ported the **whole scripted branch** (index/steps bookkeeping,
        `LoadDEPlusA`, `NPC_CHANGE_FACING`/STAY/WALK handling incl. pret's own
        "seems buggy" WALK OOB re-read of `[wNPCMovementDirections+$fe]` = 0xCD59
        wTradedEnemyMonOTID garbage, replicated verbatim) + `Func_5288` +
        `Func_531f/5325/532b/5331` + `ChangeFacingDirection` (falls through to
        TryWalking; stale-facing quirk documented — unreachable: the only
        NPC_CHANGE_FACING list byte is overwritten by OaksLabRivalStartsExitScript
        before the list runs). Analysis results:
        1. **Reachability:** set 1 ($04-$07) is MAINLINE — Oak's Lab rival exit
           (`$04`×5) and SilphCo11F ($05 lists); required for the intro cutscene
           (feeds OW-2.5). Set 2 ($11-$14) appears in NO shipped movement list —
           reachable only via the WALK OOB path or corruption. Set 3 unreferenced
           in pret; ported verbatim with `; UNREFERENCED`.
        2. **H-page bug CONFIRMED latent, replicated byte-for-byte** under a
           `; BUG(latent):` tag: `.asm_52fa` writes `data1[off]`=PICTUREID=8 then
           `$C000+off+1`=3 — **audio engine WRAM** (slot-dependent:
           wChannelCommandPointers/wChannelFlags1/…). The port memmap mirrors pret
           WRAM, so `[ebp+0xC001+off]` hits the port's live audio state with
           corruption parity. `BUG_FIX_LEVEL >= 2` variant writes the coherent
           data2-walkanim=8/status=3 pair instead. Per user directive 2026-07-10:
           pret bytes are ground truth (auto-disassembled ROM), replicate.
        3. **ABI adaptation:** `Func_531f` family emits (CH=facing, DH/DL=steps)
           per the port's established `Func_5337` convention; scripted fall-in to
           `.determineDirection` mirrors pret's registers (EBX := pret's stale
           HL = data2+off+6 — garbage tile ptr, never consulted because
           CanWalkOntoTile's scripted early-allow; CL := wMapSpriteData constraint,
           the port's wCurSpriteMovement2 relocation).
        All auto-labeled `Func_*` in the chain carry `Semantic:` header comments
        (would-be names) while keeping pret labels primary (user directive — stay
        in sync with pret until it names them). faithdiff: 4 deltas, all
        established classes (conditional-`je` parser artifact on ChangeFacingDirection,
        wCurSpriteMovement2→wMapSpriteData relocation, two `[hl]`-indirect stores
        named directly); lint 0; full `make fidelity` 6/6 PASS (normal NPCs are
        STAY/WALK so the scripted branch is inert until a script MoveSprites —
        runtime exercise rides with OW-2.5's rival-exit/Oak cutscene).
- Verification: `make check` clean; full SKIP_TITLE link OK (stub retired, no double-def);
  `goldencheck overworld_pallet` PASS (gate rebuild + inert scripted code don't regress
  Pallet NPCs); faithdiff clean modulo 2 justified parser artifacts (pret's `[hl]`-indirect
  writes to wStatusFlags4/Index not attributed; `jne` vs pret `jp UpdateNPCSprite`); lint 0.
- Exit (core): scripted stepper linked + faithful; stub deleted; gate rebuilt. Item-ball
  block + runtime Oak-cutscene exercise (OW-2.5) remain.

**TICKET OW-2.2: pathfinding.asm engine section** `[SWARM/Sonnet]` **— DONE 2026-07-09 (solo, commit pending stamp)**. Appended the clearly-headed engine section to port `pathfinding.asm`: `FindPathToPlayer`, `CalcPositionOfPlayerRelativeToNPC`, `ConvertNPCMovementDirectionsToJoypadMasks`, `ConvertNPCMovementDirectionToJoypadMask` + `NPCMovementDirectionsToJoypadMasksTable` (in `section .rodata`). Added the FindPath/NPCPlayer HRAM cells (0xFF95 union..0xFF9D) + `BIT_PATH_FOUND_Y/X`, `BIT_PLAYER_LOWER_Y/X`.
  - **Prerequisite bug fix (behaviour-affecting):** two WRAM addresses were unverified guesses disagreeing with the golden sym — `wSimulatedJoypadStatesEnd` 0xCC5B→**0xCCD3**, `wNPCMovementDirections2` 0xCF08→**0xCC97**. The END alias at 0xCC5B collided with `wNPCMovementDirections`, so `MoveSprite_`'s faithful `ld [wSimulatedJoypadStatesEnd],a` was zeroing step[0] of the movement list. Both now match pret's union layout.
  - Gate: overworld_pallet goldencheck PASS (no regression from the relocation); faithdiff clean on all four labels; lint 0. Check-only until `npc_movement_2`/trainer-AI callers land (they set `hNPCSpriteOffset`/`hFindPath*`).
**TICKET OW-2.3: auto_movement.asm** `[SWARM/Sonnet]` **— DONE 2026-07-09 (solo)**. New `src/engine/overworld/auto_movement.asm`: `_EndNPCMovementScript` + `EndNPCMovementScript` (banking-wrapper, allowlisted), the 5 `PalletMovementScript_*` (Oak walk-to-lab state machine) + `PalletMovementScriptPointerTable`, both Pewter tables + `PewterMovementScript_*`, all RLELists. `PlayerStepOutFromDoor` left in overworld.asm (not redefined). Real audio wired (`PlayMusic` al=id/bl=bank — the "PlayDefaultMusic/StopAllMusic stub" leaf is obsolete post-OW-A.14). `dw`→`dd` flat dispatch tables (match `CallFunctionInTable`/`RunNPCMovementScript` ×4). Check-only (HOME_CHECK_SRCS); `HideObject` an unported predef extern. faithdiff artifacts (indirect `res[hl]`, sprite-offset ABI, composite field) all justified; lint 0.

**Stage 2 status:** OW-2.1 (core + Func_5288 tail) / OW-2.2 / OW-2.3 / OW-2.4 all
DONE. Remaining Stage 2 = **OW-2.5 only** (runtime Oak-cutscene exercise via MCP —
needs the real PalletTown_Script trigger/states, currently ret-stubs in
src/scripts/pallet_town.asm, owned jointly with script-engine Stage 6; the
movement side is now fully in place: scripted branch + Func_5288 linked,
RunNPCMovementScript dispatch ungated, auto_movement tables linked).
**TICKET OW-2.4: pewter_guys.asm** `[SWARM/Sonnet]` **— DONE 2026-07-09 (solo)**. New `src/engine/events/pewter_guys.asm` (pret `engine/events/pewter_guys.asm`); flat-pointer adaptation (`dw`→`dd`, 6-byte coord stride). Check-only (HOME_CHECK_SRCS). faithdiff clean/lint 0. **Note:** the plan's "`DecodeRLEList`" hint was inaccurate — real `PewterGuys` is self-contained (0 calls), directly copying movement streams onto the sim-joypad queue.
  - **Foundation fix (separate commit):** discovered + corrected a family of guessed sim-joypad / trainer-union / field-move WRAM addresses that disagreed with the golden sym and sat *inside* the 180-byte `wNPCMovementDirections` buffer (`wSimulatedJoypadStatesIndex` 0xCC84→0xCD38, `wJoyIgnore` 0xCCB7→0xCD6B, override index/mask, `wFieldMoves*`, the whole m8_2 trainer/emotion union +6/+7). All relocate together (symbol-referenced); added `wWhichPewterGuy`=0xD12E. Gate: full `make fidelity` (6/6) PASS. This unblocks any scripted-movement/sim-joypad runtime work.
**OW-2.5: Oak cutscene verification** `[root]` — enable `PalletTownDefaultScript` trigger (script-engine Stage 6 stubs), DOSBox-X MCP: breakpoint `DoScriptedNPCMovement`, `gb_read wNPCMovementDirections2`, `dump_frame` per step; final FRAME.BIN shows Oak + player walked to the Lab. Update `current_plan_script_engine.md` (deferral resolved).

### Stage 3 — Map mutation `[x]` COMPLETE (2026-07-10; OW-3.3 data-generator tail + the deferred MCP runtime verifies remain, tracked in-ticket)

**TICKET OW-3.1: update_map.asm** `[SOLO #3]` **— DONE 2026-07-10 (code; MCP verify deferred)**
- Pret: `engine/overworld/update_map.asm` → port `src/engine/overworld/update_map.asm` (check-only)
- Checklist:
  - [x] `ReplaceTileBlock` — faithful `wOverworldMap` pointer math + the two `CompareHLWithBC` view-bounds checks; falls through (explicit jmp) to `RedrawMapView`. `CompareHLWithBC` faithful (16-bit hi-first compare). Added `W_NEW_TILE_BLOCK_ID`=0xD09E (golden).
  - [x] `RedrawMapView` — **re-expressed** to `LoadCurrentMapView` + `g_tilecache_dirty=1` + one `DelayFrame`, `wIsInBattle==$ff` guard kept; big PROJ header citing CLAUDE.md ("rings are gone"). **Canonical redraw precedent established.** faithdiff DROPs (`CopyToRedrawRowOrColumnSrcTiles`/`RunDefaultPaletteCommand`/`hRedraw*`/`hAutoBGTransferEnabled`/`hTileAnimations`) are that documented divergence; palette = TODO-HW.
  - [ ] Verify (deferred): MCP `ReplaceTileBlock` on a visible Pallet block → `dump_frame` before/after (runtime — bundled with the other deferred MCP checks).
- Exit: canonical redraw primitive established (code). lint 0.

**TICKET OW-3.2: toggleable_objects.asm completion** — **DONE 2026-07-10** (new mirrored file: `MarkTownVisitedAndLoadToggleableObjects`, `ShowObject`/`ShowObject2`, `HideObject`, `ToggleableObjectFlagAction`). **The ticket premise ("pure flag ops") was wrong** — the port's toggleable subsystem was *pre-flattened* ahead of this ticket (`gen_toggleable_objects.py` + `map_sprites.asm`): global indices are baked into each `toggle_list_<map>` entry, `IsToggleableHidden` reads them directly via `ToggleableMapPointers`, and hidden bits live in the FLAT .bss `g_toggleable_flags` (not pret's ebp-relative `wToggleableObjectFlags`/`wToggleableObjectList`). So this ticket is a **divergence-reconciliation**, done against the port's model: `ShowObject`/`HideObject` bts/btr the flat array via `ToggleableObjectFlagAction` (can't route through the ebp-relative `FlagAction`); `MarkTown…` does the town-visited flag faithfully (`predef FlagActionPredef`→direct `FlagAction`, the established port pattern) and drops the obsolete `Divide`/`wToggleableObjectList` list-build (nothing consults it). Retires the `HideObject` extern in auto_movement. **Surfaced a town_map.asm bug**: its `wTownVisitedFlag` reader uses a placeholder (0xDEA6) not the golden 0xD70A — reader/writer disagree until town_map is reconciled (noted in-file). The port's `InitToggleableObjectFlags`/`IsToggleableHidden` (map_sprites.asm) are the flattened-model equivalents of pret `InitializeToggleableObjectsFlags`/`IsObjectHidden` — left as-is (not aliased; a pret-name alias would falsely imply a faithful translation of the divergent model). faithdiff diffs all justified (divergences above), lint 0. Check-only.
**TICKET OW-3.3: hidden_events engine side** — **ENGINE DONE 2026-07-10; data+guard-retirement DEFERRED** (documented tail). Ported `CheckForHiddenEvent` + `CheckIfCoordsInFrontOfPlayerMatch` faithfully into `hidden_events.asm` (under the existing `M72_HIDDEN_EVENTS_DEEP` guard, replacing the `extern CheckForHiddenEvent`), and **fixed every deep-tier PLACEHOLDER HRAM/WRAM address to golden** (hItemAlreadyFound 0xFFA0→0xFFEB, hDidntFindAnyHiddenEvent 0xFFA1→0xFFEE, hInteractedWithBookshelf 0xFFA2→0xFFDB, hSpriteIndex 0xFF8F→0xFF8C, wHiddenEventFunctionRomBank 0xD3A5→0xCD3E, + the wHiddenEvent* cluster 0xCD3D–41, hCoordsInFrontOfPlayerMatch 0xFFEA). Flat-pointer: `dw HiddenEventsFor_<map>`→`dd`, so the per-entry skip is arg+bank+4=6 bytes. **Why deferred, not "retire the guard":** the plan's timebox/fallback applies at its extreme — the 60-map `HiddenEventMaps` data (data/events/hidden_events.asm) covers **zero currently-in-scope maps** (all Silph/caves/Safari/late-game), and its handlers are mostly unported, so building `gen_hidden_events.py` + `assets/hidden_events.inc` + `hidden_object_stubs.asm` now has no payoff. Linking `CheckForHiddenEvent` with empty data would be a *silent no-hidden-events divergence*, so it stays guarded (check-only, `HiddenEventMaps` externed) until the data generator lands. faithdiff clean (only ADDED [W_HIDDEN_EVENT_INDEX] = pret's indirect `[hli]`/`inc[hl]` named directly), lint 0; assembles under `-DM72_HIDDEN_EVENTS_DEEP` and in the normal build. **TAIL: gen_hidden_events.py + full data + stub handlers + full guard retirement.**
**TICKET OW-3.4: cut.asm** `[SWARM/Sonnet]` — new mirrored file: `UsedCut` (faithful body; leaves: `GetPartyMonName` exists; fade/palette calls via fade.asm else stubs; screen-buffer routines `SaveScreenTilesToBuffer2`/`LoadScreenTilesFromBuffer2`/`RestoreScreenTilesAndReloadTilePatterns` — audit post-merge, stub if absent; `AnimCut` → ret-stub until OW-6.1), `InitCutAnimOAM` (tree tiles $2d/$3d from `assets/overworld_gfx.inc`; grass leaf tile — check battle animations.asm embedding, else incbin `gfx/battle/move_anim_1.2bpp` slice), `WriteCutOrBoulderDustAnimationOAMBlock`, `GetCutOrBoulderDustAnimationOffsets` + tables, `ReplaceTreeTileBlock` + `cut_tree_blocks` table (calls OW-3.1's `ReplaceTileBlock`/`RedrawMapView`).

**TICKET OW-3.4: cut.asm — DONE 2026-07-10.** First fixed the shared-infra blocker (`WriteOAMBlock` flat-source, commit 11994238 — also fixed the live-broken `EmotionBubble`). Then ported `UsedCut` (16/16 calls matched), `InitCutAnimOAM`, `LoadCutGrassAnimationTilePattern`, `WriteCutOrBoulderDustAnimationOAMBlock` (**retires the dust_smoke extern**), `GetCutOrBoulderDustAnimationOffsets` + `CutAnimationOffsets`/`BoulderDustAnimationOffsets`, `ReplaceTreeTileBlock` + `CutTreeBlockSwaps`. `overworld_gfx` made `global` (overworld.asm) + externed for the tree tiles; grass leaf incbin'd `move_anim_1.2bpp` as `MoveAnimationTiles1` (allowlisted INTERIM — retire+extern when battle animations.asm lands); `AnimCut` ret-stub in overworld_stubs.asm (OW-6.1); `UpdateCGBPal_OBP1` stays externed. Text (`_NothingToCutText`/`_UsedCutText`) generated → `assets/cut_text.inc` (gen_overworld_strings.py CUT_FAR list). faithdiff clean (ADDED [W_STATUS_FLAGS_5] = pret `set/res[hl]` named; ADDED [IO_OBP1] = rOBP1 TODO-HW), lint 0. Check-only. **Stage 3 COMPLETE** (OW-3.1/3.2/3.4 done; OW-3.3 engine done, data-generator tail deferred).

**OW-3.4 SCOPING (investigated 2026-07-10 — kept for reference):**
Almost all callees already exist per `label_status` — `ClearSprites`, `Delay3`,
`GBPalWhiteOutWithDelay3`, `LoadGBPal`, `LoadCurrentMapView`, `LoadScreenTilesFromBuffer2`,
`SaveScreenTilesToBuffer2`, `RestoreScreenTilesAndReloadTilePatterns`, `PlaySound`,
`PrintText`, `RedrawMapView` (OW-3.1), `UpdateSprites`, `GetPartyMonName`, `CopyVideoData`,
`WriteOAMBlock` all present. Resolved sub-deps: **AnimCut** → ret-stub (OW-6.1); **UpdateCGBPal_OBP1**
→ extern (still unported palette — shared w/ dust_smoke, NOT retired by this ticket); **AdjustOAMBlockYPos/XPos**
live in pret `engine/battle/animations.asm` (NOT cut.asm) so this ticket does **not** retire those
dust_smoke externs — only `WriteCutOrBoulderDustAnimationOAMBlock` is retired. Golden WRAM: wCutTile
0xCD4D, wActionResultOrTookBattleTurn 0xCD6A, wYBlockCoord 0xD362, wXBlockCoord 0xD363,
wSpritePlayerStateData1YPixels 0xC104, wShadowOAMSprite36Attributes 0xC393. Consts: GYM=7,
OBJ_SIZE=4, SCREEN_HEIGHT_PX=144, OAM_XFLIP=1<<5, OAM_YFLIP=1<<6, OAM_PAL1=1<<4, OAM_HIGH_PALS=1<<2.
gfx: `overworld_gfx` label exists (assets/overworld_gfx.inc, %included by overworld.asm) but is **not
`global`** → must export it (make global in overworld.asm, extern in cut.asm) for the `Overworld_GFX tile $2d/$3d`
tree copies. grass leaf = `MoveAnimationTiles1 tile 6` — not in port; incbin `../gfx/battle/move_anim_1.2bpp`
as `MoveAnimationTiles1`. Text: `_NothingToCutText`/`_UsedCutText` in data/text/text_9.asm → generate
(extend the gen_overworld_strings far list, or gen_battle_text). `CutTreeBlockSwaps` + offset tables +
`.OAMBlock` = Tier-2 hand-written data.
**BLOCKER — shared OAM infra:** `WriteCutOrBoulderDustAnimationOAMBlock` → `WriteOAMBlock` (home/oam.asm),
but the port's `WriteOAMBlock` reads its tile/attr source as a **GB WRAM offset** (`movzx esi,dx; lea
esi,[ebp+esi]`), while cut/dust `.OAMBlock` are **flat image labels**. `trainer_engine.asm:988-994`
already documents this exact defect ("reg+addr-model wrong… add a flat-addressing WriteOAMBlock variant")
for the **live `EmotionBubble` feature**. So OW-3.4 must first rework `WriteOAMBlock` to accept a flat
source (EDX-flat, or a `WriteOAMBlock_Flat` sibling) and migrate the `EmotionBubble` caller — a shared
change touching a working feature, to be done deliberately (regressing EmotionBubble's OAM is the risk).
THEN port cut.asm. (dust_smoke's `WriteCutOrBoulderDustAnimationOAMBlock` extern also resolves once this lands.)
- Verify (root): tree-cut block swap renders cleanly under harness; Show/HideObject on Oak sprite via MCP.

### Stage 4 — Boulder subsystem `[x]` COMPLETE (2026-07-10; root MCP verify deferred — bundled runtime checks, see line below OW-4.4)

**TICKET OW-4.1: player_state.asm part 2** — `CheckForCollisionWhenPushingBoulder` + `CheckForBoulderCollisionWithSprites` **DONE 2026-07-10** (both into player_state.asm; the plan's grouping was correct — both are defined in pret `engine/overworld/player_state.asm`. An intermediate commit wrongly externed the second one based on a bad grep; corrected same session). faithdiff clean on both, lint 0. Check-only. Added wBoulderSpriteIndex/wNumSprites/H_PLAYER_Y/X_COORD/wSprite01StateData2MapY (golden).
**TICKET OW-4.2: push_boulder.asm** — **DONE 2026-07-10** (`TryPushingBoulder` + the four `PushBoulder*MovementData`, `DoBoulderDustAnimation`, `ResetBoulderPushFlags`). PlaySound is LIVE (real audio) — used directly for SFX_PUSH_BOULDER/SFX_CUT, no stub. Externs the unported `IsSpriteInFrontOfPlayer` (pret home/overworld.asm — the port's bespoke IsNPCAtTargetBlock is a different ABI, NOT a drop-in; TODO port) and `AnimateBoulderDust` (OW-4.3). Sprite-selector: keeps H_SPRITE_INDEX (=hSpriteIndex slot) only for IsSpriteInFrontOfPlayer; derives H_CURRENT_SPRITE_OFFSET=slot<<4 once for GetSpriteMovementByte2Pointer/MoveSprite (verified it survives the CheckForCollisionWhenPushingBoulder predef). faithdiff clean (all diffs = documented selector convention or false-positive on jz-to-Reset / [hl]-store naming), lint 0. Check-only. Also fixed a latent flat-EDI bug in OW-2.3 auto_movement (MoveSprite fed `mov edi, wNPCMovementDirections2` instead of `lea edi,[ebp+…]`).
**TICKET OW-4.3: dust_smoke.asm** — **DONE 2026-07-10** (`AnimateBoulderDust`, `GetMoveBoulderDustFunctionPointer` + `MoveBoulderDustFunctionPointerTable`, `LoadSmokeTileFourTimes`/`LoadSmokeTile`; incbin `../gfx/overworld/smoke.2bpp` as `SSAnneSmokePuffTile`). `CopyVideoData` sets `g_tilecache_dirty` itself. Externs the unported OAM-animation/palette primitives shared with cut (OW-3.4): `UpdateCGBPal_OBP1`, `WriteCutOrBoulderDustAnimationOAMBlock`, `AdjustOAMBlock{Y,X}Pos` — **OW-3.4 retires these externs**. Flat-pointer table: pret `dw`→`dd`, 6-byte entries, facing/4·6 index. `jp hl` trampoline → indirect `call esi`. rOBP1 flicker → `[ebp+IO_OBP1]` TODO-HW. faithdiff clean/lint 0. Check-only.
**TICKET OW-4.4: field_move_messages.asm** — **DONE 2026-07-10** (`PrintStrengthText`, the text wrappers `UsedStrengthText`/`CanMoveBouldersText`/`CurrentTooFastText`/`CyclingIsFunText`, `IsSurfingAllowed`, `SeafoamIslandsB4FStairsCoords`). Tier-1 FAR text streams (`_UsedStrengthText` etc.) generated by extending `gen_overworld_strings.py` to reuse `gen_battle_text.collect_far` (authoritative pret data/text/text_8.asm parser) → new `assets/field_move_text.inc` (own file, so they don't collide in player_state.asm's TU); wrappers hand-written Tier-2 (text_far + the text_asm cry hook). PlayCry externed (unported cry synth — status_screen plays cry as TODO-HW). faithdiff clean (only ADDED [W_STATUS_FLAGS_1] = pret's `set/res [hl]` named directly), lint 0. Check-only. **Stage 4 (boulder/Strength/Surf field mechanics) COMPLETE.**
- Verify (root): MCP unit-drive — fabricate `wTileInFrontOfPlayer` = boulder tile + sprite state, call `TryPushingBoulder`, check flags/`wSimulatedJoypadStates`, dust OAM in FRAME.BIN. (No boulder maps reachable yet — harness-level only, noted in translation_log.)

### Stage 5 — Player warp/fly/spin animations `[x]` (2026-07-10)

**TICKET OW-5.1: player_animations.asm** `[SOLO #2]` — **DONE 2026-07-10.**
New mirrored file: `EnterMapAnim` (14/14 calls; **retires the overworld_stubs.asm
ret-stub** — dup_def suppressed, stub stays LINKED for EnterMap's caller until
OW-7.2 promotion, same pattern as SpawnPikachu), `_LeaveMapAnim`,
`LeaveMapThroughHoleAnim`, `DoFlyAnimation` + 3 coord lists, `LoadBirdSpriteGraphics`
(incbin `gfx/sprites/bird.2bpp`), `InitFacingDirectionList`, `SpinPlayerSprite`,
`PlayerSpinInPlace`, `PlayerSpinWhileMovingUpOrDown`, `PlayerSpinWhileMovingDown`,
`RestoreFacingDirectionAndYScreenPos`, `GetPlayerTeleportAnimFrameDelay` (`; PROJ`
re wOnSGB/TIMING), `IsPlayerStandingOnWarpPadOrHole` + `WarpPadAndHoleData` (`; PROJ`:
`lda_coord 8,9` → `W_TILEMAP + PLAYER_STANDING_ROW*SCREEN_TILES_W+PLAYER_STANDING_COL`,
same anchor as player_state.asm), `FishingAnim` + `FishingRodOAM`/`RedFishingTiles`
(fishing gfx incbin'd; `LoadAnimSpriteGfx` externed UNPORTED). Real audio LIVE
(PlaySound/PlayDefaultMusic; StopMusic externed UNPORTED — home/overworld.asm).
`_HandleMidJump`/`PlayerJumpingYScreenCoords` left in ledges.asm (not duplicated).
Fishing text (`_NoNibbleText`/`_NothingHereText`/`_ItsABiteText`) generated →
`assets/player_anim_text.inc` (gen_overworld_strings.py PLAYER_ANIM_FAR). BirdSprite +
fishing tiles are file-local incbins (INTERIM; retire+extern at gfx port). faithdiff:
all diffs are the 3 established justified classes — (1) indirect `ld [hli],a` /
`set/res [hl]` stores the port names directly, (2) conditional `jr/jp nz` self-loops
faithdiff can't parse (DoFlyAnimation, LeaveMapThroughHoleAnim), (3) two flat-source
`CopyData`→inline `rep movsb` (InitFacingDirectionList/FishingAnim; flat ROM label
src, map_sprites.asm:ShowTextStream precedent). lint 0 (7 suppressed). Check-only.
- Pret: `engine/overworld/player_animations.asm`
- Checklist (all DONE except the runtime verify below):
  - [x] `EnterMapAnim`, `PlayerSpinWhileMovingDown`, `_LeaveMapAnim`, `LeaveMapThroughHoleAnim`, `DoFlyAnimation` + coord lists, `LoadBirdSpriteGraphics` (incbin `gfx/sprites/bird.2bpp`; loads NPC-sprite VRAM → `g_tilecache_dirty`; integrate with `src/gfx/sprites.asm` sheet layout), `InitFacingDirectionList`, `SpinPlayerSprite`, `PlayerSpinInPlace`, `PlayerSpinWhileMovingUpOrDown`, `RestoreFacingDirectionAndYScreenPos`, `GetPlayerTeleportAnimFrameDelay` (`wOnSGB` read — `; PROJ` note re Makefile TIMING modes), `IsPlayerStandingOnWarpPadOrHole` (+ tile table; writes `wStandingOnWarpPadOrHole`), `FishingAnim` (leaves: `LoadAnimSpriteGfx`/rod gfx/`EmotionBubble`/texts — stub what's missing, body faithful)
  - [x] `_HandleMidJump` stays in ledges.asm; alias note here
  - [x] Bounded-wait divergences for any sound-state polling vs ret-stubs
  - [ ] Verify: `DEBUG_TELEPORT_ANIM` harness in `EnterMap` (pattern: `DEBUG_TRANSITION`) — set `BIT_USED_FLY`/dungeon-warp state, run `EnterMapAnim`, FRAME.BIN mid-anim shows bird/spin frames; MCP breakpoints on `DoFlyAnimation`
- Exit: fly-in / teleport / hole-fall animations render.

**TICKET OW-5.2: special_warps.asm** `[SWARM/Sonnet]` — **DONE 2026-07-10 (unblocked; user-approved approach).**
- `PrepareForSpecialWarp` ported faithfully (new mirrored file; retires the
  main_menu_stubs.asm ret-stub, dup_def suppressed → OW-7.2, like EnterMapAnim).
  Pure flag/map-selection logic, no pointer-walk. faithdiff clean (ADDED
  [wStatusFlags6] = pret's `res [hl]` named directly), lint 0, check-only.
- **`LoadSpecialWarpData` + warp data tables UNBLOCKED 2026-07-10.** The blocker
  dissolved once observed that overworld.asm:`LoadWarpDestination` already holds
  the port's canonical runtime view-pointer formula: `event_displacement`
  (coords.inc) was **re-derived** as the same pure function of
  `MAP_BORDER`/`SCREEN_BLOCK_*` (assemble-time), emitting `dw` (2-byte GB-space
  pointer; the old `dd` was a latent size mismatch). Precomputed table values and
  the runtime recompute now agree by construction (lockstep note in both places);
  a future border change reassembles both. Pret's 6-byte fly_warp entry layout,
  `wDungeonWarpDataEntrySize=6`, and both copy loops port **verbatim** (port
  memmap keeps pret's 0xD35D–0xD363 contiguity). Data tables mirrored at
  `src/data/maps/special_warps.asm` (%include'd like pret); map ids/`_WIDTH`s/
  tileset ids from new **generated `assets/map_dims.inc`** (gen_map_headers.py,
  Tier-1). One structural divergence: FlyWarpDataPtr stores flat 32-bit `dd`
  pointers (pret: 2-byte ROM `dw`) → walk skips 4, match is one 32-bit load
  (PROJ-documented). **Verified:** tables assembled to flat bin and cross-checked
  byte-for-byte against the runtime formula applied to pret's source data
  (12 dungeon + 5 special + 13 fly entries, 293 bytes, 0 mismatches); faithdiff
  clean (ADDED wStatusFlags3/6 = pret `res [hl]` named directly); lint 0;
  `make check` green. Runtime special-warp exercise deferred to OW-7.2+ (no
  fly/dungeon trigger exists yet); spawns near map edges lean on the rendering
  clamps like normal warps (map-data extension unaffected, still TODO).

### Stage 6 — Cosmetic OAM/screen animations `[x]` COMPLETE (2026-07-10; root verify deferred — see line below OW-6.4)

**TICKET OW-6.1: cut2.asm** — **DONE 2026-07-10.** New mirrored file: `AnimCut`
(tree-spread + grass-leaf paths), `AnimCutGrass_UpdateOAMEntries`, `AnimCutGrass_SwapOAMEntries`.
All shadow-OAM/wBuffer copies are WRAM→WRAM (real CopyData used directly). **Deleted
the OW-3.4 `AnimCut` ret-stub** cleanly (its only caller UsedCut/cut.asm is check-only
→ no linked caller → no dup_def needed; cut.asm extern comment repointed). Externs the
unported OAM-anim/palette primitives `AdjustOAMBlockXPos2`/`AdjustOAMBlockYPos2`
(pret engine/battle/animations.asm; ABI ESI=GB OAM off, BL=count) + `UpdateCGBPal_OBP1`.
rOBP1 flicker → `[ebp+IO_OBP1]` TODO-HW. faithdiff clean (ADDED [IO_OBP1] = rOBP1
TODO-HW; DROPPED self-`jr` faithdiff can't parse), lint 0. Check-only.
**TICKET OW-6.2: healing_machine.asm** — **DONE 2026-07-10.** New mirrored file:
`AnimateHealingMachine` + `PokeCenterFlashingMonitorAndHealBall` (incbin
`gfx/overworld/heal_machine.2bpp`) + `PokeCenterOAMData`, `FlashSprite8Times`,
`CopyHealingMachineOAM` (flat-src EDX cursor + GB-WRAM ESI dest, both persist/advance
across the party loop). Audio is LIVE (StopAllMusic/PlaySound). Two DIVERGENCE notes
per ticket: (1) the `wAudioROMBank == Audio Engine 3` guard + bank-swap around
Music_PkmnHealed is elided (meaningless under the flat single audio engine —
jingle played directly); (2) the two bare `jr nz` audio waits (wAudioFadeOutControl /
wChannelSoundIDs) are bounded (the port has no VBlank audio ISR, so an unbounded
spin would hang; engine-tick yield deferred to promotion). rOBP1 → `[ebp+IO_OBP1]`
TODO-HW. faithdiff clean (DROPPED [wAudioROMBank] = banking divergence; ADDED
[IO_OBP1] = rOBP1 TODO-HW; ADDED [wUpdateSpritesEnabled] = indirect `[hl]` named),
lint 0. Check-only.
**TICKET OW-6.3: elevator.asm** — **DONE 2026-07-10.** New mirrored file:
`ShakeElevator` (hSCY shake → `[ebp+H_SCY]` fine-scroll, native renderer honors it;
100× jerk w/ SFX via LIVE PlayMusic, PA jingle, restore music) + `ShakeElevatorRedrawRow`
(documented **NO-OP** tail-calling Delay3 — pret itself notes "no visible effect", and
its wMapViewVRAMPointer/vBGMap0 torus rewrite has no native-renderer analog; DROPPED
ScheduleNorthRowRedraw justified as the no-op). `.musicLoop` bounded (DIVERGENCE — no
VBlank audio ISR). PlayMusic bl=bank vestigial (flat). faithdiff clean, lint 0. Check-only.
**TICKET OW-6.4: spinners.asm** — **DONE 2026-07-10.** New mirrored file:
`LoadSpinnerArrowTiles` + `SpinnerPlayerFacingDirections` + Facility/Gym spinner tables +
`SpinnerArrowAnimTiles` (incbin `gfx/overworld/spinners.2bpp`). Flat-table reshape: pret
`spinner` macro's `dw <src> tile N` → `dd` flat pointer, so entries grow 6→8 bytes (dd src,
db count, db bank, dw dest) and the loop stride / skip-offset scale (SPINNER_ENTRY_SIZE=8).
CopyVideoData(ESI=VRAM dest, EDX=flat src, BL=count) sets g_tilecache_dirty. Facility_GFX/
Gym_GFX incbin'd as file-local INTERIM (port loads tilesets dynamically; retire when
unified). faithdiff clean, lint 0. Check-only. **Stage 6 COMPLETE.**
- Verify (root): cut animation end-to-end (full `UsedCut` visual); healing machine / elevator / spinners via MCP unit-invocation + FRAME.BIN (maps unreachable — check-only linkage acceptable where callers don't exist).

### Stage 7 — Completeness + link promotion + cleanup `[x]` COMPLETE (2026-07-10)

**TICKET OW-7.1: unused_load_toggleable_object_data.asm** — **DONE 2026-07-10.**
New mirrored file (HOME_CHECK_SRCS): `Func_f0a54` (bare ret) + `LoadToggleableObjectData`
+ `.ToggleableObjectsMaps`/`.BluesHouse` data, all `; UNREFERENCED (pret: unreferenced)`.
Flat-reshape: `toggleable_object_map`'s `dw ptr` → `dd` (4→6 byte entries, skip stride
5); flat-source copy → inline rep movsb (DROPPED CopyData justified). Builds the
port-unused `wToggleableObjectList` (externed to golden 0xD5CD; the flat model doesn't
read it — noted). faithdiff clean, lint 0. Check-only.
**OW-7.2: link promotion** `[root + SWARM closure fixes]` — **DONE 2026-07-10.**
Closures computed mechanically (assemble every check-only file, `nm -u` diff vs
the linked build's global defs, transitive over co-promoted files — script
pattern in scratchpad `ow72/`, method noted here for reruns). **13 files
promoted to GAME_SRCS:** ledges, pathfinding, npc_movement_2, auto_movement,
overworld_text, pikachu, pewter_guys, toggleable_objects, update_map, elevator,
spinners, healing_machine, unused_load_toggleable_object_data. Two unlocks made
this maximal: `global g_toggleable_flags` (map_sprites.asm → toggleable_objects
→ HideObject → auto_movement), and a new `UpdateCGBPal_OBP1` ret-stub in
overworld_stubs.asm (TODO-HW palette boundary, pret home/cgb_palettes.asm —
same class as RunDefaultPaletteCommand; retires at Phase 5 palettes) →
healing_machine. **SpawnPikachu ret-stub retired** (real follower FSM linked;
still unreachable — slot-15 gate fires on no current map, so behavior-neutral;
movement.asm extern repointed). Also exported `IsPlayerStandingOnDoorTile` +
`LoadTilesetHeader` from overworld.asm (removes two future blockers).
**Still check-only, per-file blockers documented in the Makefile comment block
(authoritative list):** trainer_engine (DisplayTextID/GetTrainerName_/
SaveTrainerName/_TrainerNameText/JessieJamesPic + WriteOAMBlock in check-only
home/oam.asm; the EmotionBubbleGfx embed rides with its promotion), cut
(vcopy/oam home promotions + AnimCut), cut2 + dust_smoke
(AdjustOAMBlock{X,Y}Pos(2) — unported pret battle/animations.asm OAM
primitives), field_move_messages (PlayCry), player_animations (EmotionBubble/
LoadAnimSpriteGfx/player_sprite/StopMusic), player_gfx (sprite gfx labels),
player_state (ForceBikeOrSurf via player_gfx), special_warps
(PrepareNewGameDebug is DEBUG-gated-link-only). reload_sprites was already
promoted (menus S7). **Verified:** full build + link clean (no dup defs),
`make check` green, lint_pret_labels 0, **full `make fidelity` suite PASS
(all 6 scenarios)** — promotion is behavior-neutral (newly linked code is
dead until wired; the one replaced stub was never-called).
**OW-7.3: stub + docs sweep** `[root]` — **DONE 2026-07-10.** Superseded stubs
were already deleted at their tickets (DoScriptedNPCMovement OW-2.1, AnimCut
OW-6.1, SpawnPikachu OW-7.2) — verified none remain shadowing (link is clean;
survivor census with owners added to the "Stub inventory" section below, all
headers refreshed to current status, incl. InitializeToggleableObjectsFlags
re-documented as the OW-3.2 flattened-model no-op rather than a pending port).
**Ungated `RunNPCMovementScript`'s scripted dispatch** (removed the
NPC_MOVEMENT_SCRIPTS_LINKED %ifdef — its table providers linked at OW-7.2;
still inert until a script sets wNPCMovementScriptPointerTableNum, verified by
goldencheck). Docs: translation_log.md got a Stages-2–7 pointer entry (per-
ticket notes live in this plan, per-commit justifications in git); ui_projection.md
gained the overworld-field tile-read row (the (+16,+8) PLAYER_STANDING
projection — the plan's most load-bearing PROJ); TODO.md umbrella item
refreshed to current stage status. Verified: full build + link clean,
lint_pret_labels 0, goldencheck overworld_pallet PASS.

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

**Surviving-stub census (OW-7.3 sweep, 2026-07-10 — all verified legitimate,
headers current):**
- `overworld_stubs.asm` (linked): `UpdateCGBPal_OBP1` (TODO-HW palette, retires
  Phase 5); `ApplyPikachuMovementData_` (pikachu_movement subsystem, M9.1);
  `InitializeToggleableObjectsFlags` (deliberate no-op — OW-3.2 flattened
  g_toggleable_flags model covers it; retires only on model re-derivation);
  `MapEntryAfterBattle` (unported home post-battle re-entry, OW-A.4(b));
  `EnterMapAnim` (real body in check-only player_animations.asm — dup_def
  suppressed; retires at its promotion); `ResetUsingStrengthOutOfBattleBit`
  (unported home; boot-path behavior-equivalent); `IsSurfingPikachuInParty`
  (unported home follower-flag scan); `LoadHoppingShadowOAM` (cosmetic ledge
  shadow, no shadow slots in the port OAM model yet).
- `main_menu_stubs.asm` (linked): `OakSpeech` (unported movie);
  `PrepareForSpecialWarp` (real body in check-only special_warps.asm —
  dup_def suppressed; retires at its promotion).
- Deleted this sweep-cycle: `SpawnPikachu` (OW-7.2 — real body linked).
- Also ungated at OW-7.3: `RunNPCMovementScript`'s scripted dispatch
  (`NPC_MOVEMENT_SCRIPTS_LINKED` %ifdef removed — its providers linked at
  OW-7.2; dispatch inert until OW-2.5 sets the table num).

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

**TICKET OW-A.11: pikachu.asm rectification** `[Opus solo]` — **DONE 2026-07-05** (check-only; unblocks OW-7.2)
- **CLOSED OUT.** nasm clean; `make check` clean; full SKIP_TITLE build links; 3 FRAME.BIN
  baselines byte-identical (all changes are in check-only pikachu.asm + a dead linked global +
  additive gb_memmap symbols — the linked build is provably untouched).
- <details><summary>Items (all done)</summary>

  - **WRAM placeholders — RE-DIAGNOSED + promoted:** the audit's "misread wd431 / re-derive to a
    non-Yellow scheme" framing was itself wrong. The five values are correct **pokeyellow-real**
    addresses (`wPikachuOverworldStateFlags` $D42F, `...ScriptBank` $D449, `...ScriptAddress` $D44A,
    slot-15 `MovementStatus` $C1F1, `ImageIndex` $C1F2 — all verified against pret ram/wram.asm)
    AND they are **consistent with the port's EXISTING gb_memmap Pikachu block** (`W_D433` $D433,
    `wPikachuHappiness` $D46F, `wPikachuMood` $D470 — all Yellow-real). The real defect was that they
    were stranded as a file-local placeholder block. Fix: **promoted the 5 symbols into
    gb_memmap.inc** next to the existing Pikachu block (removed the file-local block; pikachu.asm
    resolves them via `%include`). Absolute anchoring still rides the deferred gb_memmap Red-vs-Yellow
    decision, but the block is internally consistent so it re-anchors as a unit. (See the "OPEN
    QUESTION — gb_memmap.inc WRAM anchoring" note at the end of this doc — this narrows it: the
    Pikachu block is Yellow-real in the port today, matching W_D433.)
  - `BANK_PikachuOverworld` `0x3D` → `0x3F` (pret "Overworld Pikachu" section; flat-model bookkeeping).
  - `ApplyPikachuMovementData_` deferred ret-body **relocated to overworld_stubs.asm** (global +
    retire-TODO), where the sibling `SpawnPikachu` pikachu-stub already lives; pikachu.asm now carries
    an `extern` + retirement note (stub convention).
  - SCAFFOLD routines (`_SpawnPikachu` guard-entry, `TrySpawnPikachu` spawn-coord calc) now carry
    explicit `; SCAFFOLD` tags; FAITHFUL routines (bit-flags, `ShouldPikachuSpawn`, `Pikachu_IsInArray`)
    unchanged.
  </details>

**TICKET OW-A.12: overworld_text.asm rectification** `[Opus solo]` — **DONE 2026-07-05** (check-only)
- **CLOSED OUT.** nasm clean (default AND `-D M72_OVERWORLD_TEXTSCRIPTS`); `make check` clean;
  full SKIP_TITLE build links; 3 FRAME.BIN baselines byte-identical (check-only file, linked
  build untouched).
- <details><summary>Items (all done)</summary>

  - **DisplaySignText first-byte dispatch:** added the pret `DisplayTextID` first-byte check —
    if the resolved stream's first byte is a `TX_SCRIPT_*` sentinel ($F6-$FF) it is NOT printed
    as text (fixes the garbage-glyph SCAFFOLD bug). Under `M72_OVERWORLD_TEXTSCRIPTS` the four
    sentinels with landed handlers (PLAYERS_PC/BILLS_PC/POKECENTER_PC/PRIZE_VENDOR) tail-dispatch
    to the `TextScript_*` routines (popad-then-jmp, stack-balanced); MART/NURSE/CABLE need the
    still-NI `DisplayPokemartDialogue`/`DisplayPokemonCenterDialogue`/`CableClubNPC` so they're
    recognized-and-skipped with a `; SCAFFOLD`/`TODO(M7.2)` marker. (Sentinel range corrected:
    $F6-$FF, not the ticket's "$F5-$FF"; $F5 is `TX_SCRIPT_VENDING_MACHINE`, a valid sentinel, but
    the floor is $F6 CABLE.) TX_SCRIPT_* defined locally with provenance (not in the include chain).
  - **EBX preservation:** `DisplaySignText` now brackets with `pushad`/`popad` (was an explicit
    push set omitting EBX, which `ShowTextStream`→`npc_dialog_wait_impl` clobbers); doc note fixed.
  - **Provenance + link-critical labels:** header corrected — `DisplaySignText` is BESPOKE (mirrors
    the port's CheckNPCInteraction dispatch / pret home/overworld.asm:IsSpriteOrSignInFrontOfPlayer
    sign leg + home/text_script.asm:DisplayTextID), and `TextScript_*` are home/text_script.asm
    targets (NOT home/overworld_text.asm). **Ported `TextScriptEnd` + `TextScriptEndingText`** (pret
    home/overworld_text.asm) — resolves the trainer_engine.asm extern (`jmp TextScriptEnd` :808) that
    would hard-fail on trainer_engine promotion. The other **6** home/overworld_text.asm labels
    (`ExclamationText`/`GroundRoseText`/`BoulderText`/`MartSignText`/`PokeCenterSignText`/
    `PickUpItemText`) are DEFERRED with a documented note: they are `text_far _XxxText` wrappers whose
    Tier-1 strings aren't generated for the port yet — per the two-tier rule they must come from a
    gen_*.py, not hand-encoded here; no live caller needs them. `M72_OVERWORLD_TEXTSCRIPTS` left OFF
    (dispatch wired but its ultimate mart/PC-nurse handlers are still NI).
  </details>

**TICKET OW-A.13: menu box-draw geometry + canvas↔window compositor fix** `[SOLO — final round-off]` `[FIXED 2026-07-06 — commits b8e8ecff (transfer retirement) + 51ef4852 (bag stride); LIVE SMOKE of the bag fix pending]`

> **2026-07-06 (second session): bag stride bugs FIXED + A/B-verified (commit 51ef4852).**
> (a) `DisplayListMenuID` now sets `text_row_stride=20` + `menu_item_step` at entry, BEFORE
> `list_draw_box_border` (was ~25 lines later — arriving from the START menu at stride 40 the
> border landed every other scratch row); (b) `PrintListMenuEntries`'s stride-40
> `ClearScreenArea` on the stride-20 scratch replaced with the inline `list_clear_interior`
> (pdex/link_menu precedent) — stale interior rows 2/4/6/8 + the QTY-region (rows ≥11) clobber
> are gone. Audit of all other ClearScreenArea call sites found no further instance of the trap
> (status_screen/evolution/faint_enemy = stride-40 canvas contexts; text_box/naming = single-row
> or canvas). Harness upgraded into a real regression repro: `RunBagMenuTest` seeds
> `text_row_stride=40` (the live entry state) and `DEBUG_BAGMENU_EMPTY=1` gives the
> empty-inventory worst case. Headless FRAME.BIN A/B: unfixed code renders interleaved borders
> with stale map bytes in the walls; fixed code renders clean boxes (empty CANCEL-only + populated).
> **Pokédex re-verify (harness): PASS** — `DEBUG_G1`/`RunPokedexTest` renders the CONTENTS list
> clean post-transfer-retirement (numbers/names/SEEN 12/OWN 4/side menu). Remaining dex visual
> roughness is the documented `LoadPokedexTilePatterns` no-op stub (dex tileset $60–$7A not
> ported — TODO.md S10 gfx). Live smoke of bag (empty + populated) + dex still pending (user).

> **2026-07-06 ROOT CAUSE (verified by A/B FRAME.BIN repro):** the primary corruption family
> (grass-after-submenu, options every-other-row/missing bottom border, pokédex garble-while-open)
> was **`do_bg_transfer`** (frame.asm): its geometry had rotted (it copied `SCREEN_TILES_W`=40
> bytes per 32-wide GB tilemap row — row pad 32−40=−8 — for `SCREEN_TILES_H`=25 rows; written for
> the GB 20×18), and any faithful pret `hAutoBGTransferEnabled=1` write turned it on:
> `DisplayListMenuIDLoop` (bag) and `Pokedex_PlacePokemonList` arm it and **leak it back to the
> START menu** (no exit path cleared it), whereupon every DelayFrame re-smeared the canvas (map
> mirror = grass) over `GB_TILEMAP1` — the START-menu/options/pokédex window SOURCE — out-fighting
> `sm_canvas_mirror`/`options_mirror`/`pdex_mirror`. No single geometry can serve it (EN=1 arms
> exist from stride-20 scratch screens AND 40-wide canvas screens), so it was **retired outright**;
> explicit per-window mirrors are the port's only WRAM→tilemap path. The `hAutoBGTransferEnabled`
> writes remain as vestigial pret-fidelity bookkeeping (nothing reads them).
> DEBUG_STARTMENU now seeds the leaked EN=1 state as the permanent regression repro
> (old code: menu = pure map tiles; fixed: clean menu — both captured via the headless
> FRAME.BIN harness). **Still open, separate mechanisms:** (a) bag/list borders — 
> `DisplayListMenuID` runs `list_draw_box_border`/`TextBoxBorder` BEFORE setting
> `text_row_stride=20` (arriving from the START menu it is still 40 → border drawn every other
> scratch row; boot-default 20 is why the DEBUG_BAGMENU harness looked fine), plus
> `PrintListMenuEntries` calls the stride-40 `ClearScreenArea` on the stride-20 scratch (stale
> interior rows + clobbers scratch rows ≥11 incl. the QTY box region — pokedex.asm:500 dodged
> this same trap with an inline clear); (b) pokédex residuals after the transfer retirement
> (needs re-verify + the `LoadPokedexTilePatterns` tileset note in TODO.md — the player never
> has the dex in a fresh live boot, so verify via the `DEBUG_G1`/`RunPokedexTest` harness or by
> seeding EVENT_GOT_POKEDEX).
>
> **2026-07-06 live smoke (user):** grass-after-submenu GONE and the OPTION screen renders fully
> (all rows + bottom border) — (1) and (2) of the symptom list are CLOSED by the transfer
> retirement. The bag/items box (3) is still corrupt, as predicted — its stride bugs above are
> the open work. Pokédex untested live (no dex event in a fresh save).
- **Origin:** refiled from OW-A.2 P4 after the plan's "VRAM tile-slot management" root cause
  for the live menu corruption was **DISPROVEN** (box/space tiles `$79–$7F` are byte-identical
  across `font_extra.2bpp`/`font_battle_extra.2bpp`; the corruption triggers immediately with no
  battle; borders render as real border tiles, not stale HP-bar glyphs). See the corrected
  cross-cutting note near the top of this doc. **Technically its own subsystem (menu engine, not
  the overworld sprite loader)** — filed here as the final item to round off the overworld
  overhaul at the user's request (2026-07-05).
- **User-confirmed symptoms (real build, 2026-07-05):**
  1. **START menu "turns to grass" after entering+exiting ANY submenu** (party/bag/options/…) —
     i.e. `RedisplayStartMenu` after a submenu round-trip: the menu window is not re-composited,
     so the overworld BG (grass) shows through. → **canvas↔window compositor** (the submenu runs
     the full-canvas render mode; the return to the windowed START menu doesn't restore the window
     overlay). Suspects: `RedisplayStartMenu` (`home/start_menu.asm`) not re-showing the window
     after the submenu's `RestoreScreenTilesAndReloadTilePatterns` / canvas mode; the
     canvas→window bridge (`sm_canvas_mirror` / `set_single_window` / `hide_window` state).
  2. **Options-menu bottom border missing** — box-draw geometry (height/bottom-row off by one, or
     the bottom border row is drawn off the window clip).
  3. **Bag/items box borders mangled** (fresh open, DEBUG_BAGMENU render confirms: item name field
     too narrow — "MASTER BALL" truncated to "MASTER BAL" — quantity column crammed, stray tile
     after names). Box width / column layout geometry.
- **Explicitly out of scope (user, 2026-07-05):** the **Pokédex** is also corrupt but has a lot of
  its own logic → tracked as a SEPARATE issue, not part of OW-A.13.
- **NOT the cause (already ruled out this session):** VRAM tile-slot clobbering / sprite tile
  loader / `wFontLoaded` reload (all verified correct in OW-A.2); the box/space tile data.
- **Approach:** build per-menu DEBUG_* renders (DEBUG_STARTMENU / DEBUG_BAGMENU exist; add an
  options render + a START→submenu→redisplay repro) as the ground-truth oracle, then fix the
  box-geometry (bag/options) and the RedisplayStartMenu window re-composite. Menu engine files:
  `home/start_menu.asm`, `engine/menus/*`, `home/window.asm`, `home/textbox.asm`, `text/text.asm`
  (stride/geometry), the canvas↔window bridge in `ppu/ppu.asm` (`set_single_window`/`hide_window`).
  Cross-ref memories: `menu-corruption-vram-tileslots` (mark superseded by this finding),
  `menus-s4-realign-complete` (W_TILEMAP triple-duty + canvas→window bridge), `placestring-eax-flat-convention`.

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
