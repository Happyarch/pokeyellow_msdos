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
- [ ] **Gate:** battle-swarm integration merged to `master`; then
      `git branch overworld-port master`.
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
- [ ] Capture pre-work FRAME.BIN baselines: `DEBUG_BASELINE`, `DEBUG_TRANSITION`,
      `DEBUG_WALK_NORTH` renders stored for later regression diffs.

### Stage A — Fidelity rectification + pret-label restoration `[ ]`

**TICKET OW-A.1: LoadTilesetHeader rectification** `[SWARM/Sonnet]`
- Pret: `engine/overworld/tilesets.asm:LoadTilesetHeader` (+ `data/tilesets/tileset_headers.asm`, `DungeonTilesets`)
- Target: `dos_port/src/engine/overworld/overworld.asm` (existing routine)
- Checklist:
  - [ ] Add missing tail per pret: `hPreviousTileset` compare (HRAM shadow byte in `gb_memmap.inc` if absent), `DungeonTilesets` membership check, `wDestinationWarpID` / `LoadDestinationWarpPosition` handling, and `wYBlockCoord/wXBlockCoord = wYCoord/wXCoord & 1` warp-arrival alignment
  - [ ] Header fields currently hardcoded (`bank=1`, `grass=$FF`, `anim=0`): read real grass-tile + animation fields from the tileset header data; keep bank as `; TODO-HW` no-op with note
  - [ ] `; PROJ`/`; DIVERGENCE` comments for any port asset-model differences
  - [ ] Verify: nasm check; `make -C dos_port SKIP_TITLE=1` boots; FRAME.BIN baseline unchanged; walk-through-door arrival position correct via MCP `gb_read` of `wYBlockCoord/wXBlockCoord`
- Exit: pret tail present; alignment omission fixed; translation_log entry (root).

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

### Stage 1 — Pure-logic leaves `[ ]` (SWARM wave 1 — all tickets independent)

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
