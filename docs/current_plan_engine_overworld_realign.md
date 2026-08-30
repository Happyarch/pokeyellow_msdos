# Plan: engine/overworld/ pret realignment & overworld.asm dissolution

> Born 2026-08-29 from a full-directory audit: pret `engine/overworld/` (33 files, ~4,500 lines)
> and `dos_port/src/engine/overworld/` (36 files, ~8,700 lines) read end-to-end and compared
> file-by-file and routine-by-routine against the supporting code on both sides (`home/overworld.asm`,
> `src/ppu/ppu.asm`, `src/home/text_script.asm`, `src/data/maps/map_headers.asm`, `include/gb_memmap.inc`).
> The port's functional core logic matches pret closely; what remains is an instruction omission
> in `tilesets.asm`, a timing deviation in `elevator.asm`, a set of stale `UNPORTED` / `TODO-HW` comments,
> the immediate retirement of `DoSignInteraction`, the relocation of `RefreshCollisionTileMap` to `src/ppu/ppu.asm`,
> the elimination of the `LoadDestinationMapData` double-map-load flaw, and the permanent dissolution of the
> non-standard `dos_port/src/engine/overworld/overworld.asm` container to restore 100% directory and label parity.

**Scope rule (maintainer): everything realigns except the data model and the flat
model.** Data-model bakes (flat `dd` pointer tables, 32-bit addresses) and flat-model elisions (bank switches,
`FarCopyData` bank arg) are accepted and are NOT changed here — where they are the *reason* a line cannot be literal,
they get a machine-parsed `DEVIATION{}` annotation. The two out-of-map viewport clamps are PERMANENT (maintainer decision 2026-08-16) and stay.

---

## Gate

For every commit under this plan:
1. `nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 -o /dev/null <file>` per touched file, then `dos_port/tools/faithdiff <Label>` for each changed pret label (justify every unsuppressed call delta in the commit message), then `dos_port/tools/lint_pret_labels --no-scan --strict-claims` (exit 0), then `dos_port/tools/static_gate`.
2. Behavior moves pixels or WRAM bytes → `make -C dos_port fidelity` (core); full tier (`make -C dos_port fidelity-full`) for structural stages (Stages C and D). Judge by reported=N/N nonzero=0.
3. Run `memory_search regression overworld` before editing; if a change lands a fix a regression memory knows about, close the memory in the same commit.
4. One commit per numbered item or tightly-coupled pair; narrative in the commit message.
5. Archive to `docs/plans/engine_overworld_realign.md` when all stages are `[x]`.

---

## Findings Ledger

### Functional (Logic & Missing Instructions)
- **F1** `tilesets.asm:LoadTilesetHeader`: Omitted `xor a / ldh [hMovingBGTilesCounter1], a` (pret `:18-19`). Sets `hTileAnimations` but leaves `hMovingBGTilesCounter1` uninitialized across tileset switches.
- **F2** `elevator.asm:ShakeElevator`: Polls audio channel 1 using an inline CPU loop (`WAIT_PA_MAX equ 600`) without calling `DelayFrame`, documented only by an informal free-form comment.
- **F3** `LoadDestinationMapData` (in `overworld.asm`): On warp transitions, performs a complete map load (`LoadMapHeader`, `LoadTilesetTilePatternData`, `LoadTileBlockMap`, `LoadCurrentMapView`), after which `OverworldLoop.warpTransition` jumps to `EnterMap`, executing `LoadMapData` a **second time**. Requires fragile save/restore workarounds for `wDestinationWarpID` to prevent warp coordinates from corrupting.
- **F4** `DoSignInteraction` (in `overworld.asm`): Ad-hoc sign text presentation wrapper that manually loads font patterns and freezes the player, bypassing pret's unified `DisplayTextID` dispatcher.

### Structural & Directory Architecture
- **S1** Non-standard `src/engine/overworld/overworld.asm` container: Pret has no `engine/overworld/overworld.asm`. The port's file is an obsolete catch-all container holding glue and data that belong in `src/home/overworld.asm`, `src/ppu/ppu.asm`, `src/data/maps/`, and `src/home/init.asm`.
- **S2** `RefreshCollisionTileMap` placement: Currently in `overworld.asm`. Because it crops the 40×25 collision window from `wSurroundingTiles` (the 48×36 PPU surface buffer), its natural home is [`src/ppu/ppu.asm`](file:///mnt/sdb1/Code/Active%20Code/pokeyellow_msdos/dos_port/src/ppu/ppu.asm) directly alongside its sibling surface cropper, `SnapshotRenderedTileMap`.
- **S3** `StageIndoorMapBlk` placement: Currently in `overworld.asm`. Belongs inside `src/home/overworld.asm:LoadMapHeader` where indoor map headers are processed.
- **S4** `ApplyMapBorderOverrides` placement: Currently in `overworld.asm`. Belongs in `src/home/overworld.asm:LoadTileBlockMap`.
- **S5** `h_load_sprite_temp1/2` allocation: Defined as `.data` variables in `overworld.asm` instead of canonical HRAM addresses in `include/gb_memmap.inc` (`0xFF8C` / `0xFF8D`).
- **S6** Embedded Asset Blobs in `overworld.asm`: `.blk`, `.2bpp`, and `.bst` `%include`s belong in `src/data/maps/map_headers.asm`.
- **S7** `map_sprites.asm` Bloat: Contains 740+ lines of legacy bespoke dialog and custom trainer sight loops (`CheckTrainerSight`, `TrainerEncounterFlow`) that duplicate `trainer_sight.asm` and `home/trainers.asm`.

### Stale Comments & Annotations
- **C1** `cut.asm`: `ReplaceTreeTileBlock` uses free-form `; PROJECTION (border/viewport):` instead of machine-parsed `DEVIATION{class=projection; ...}`; `InitCutAnimOAM` carries stale `; TODO-HW: rOBP1`.
- **C2** `cut2.asm`: Claims `AdjustOAMBlockXPos2/YPos2` are `UNPORTED` (linked in `battle/animations.asm`).
- **C3** `dust_smoke.asm`: Carries stale `; TODO-HW: rOBP1` comments.
- **C4** `field_move_messages.asm`: Claims `PlayCry` is `UNPORTED` (linked in `src/home/pokemon.asm`).
- **C5** `healing_machine.asm`: Carries stale `; TODO-HW: rOBP1` comment.
- **C6** `hidden_events.asm`: Claims `HiddenEventMaps` is unresolved (linked and generated).
- **C7** `overworld_stubs.asm`: 100% of stubs are retired; header still describes active dispatch targets.

---

## Actionable Plan Stages

### Stage A — Bug Fixes, Missing Instructions & Annotations (F1, F2, C1–C6)

- [x] **A.1** `tilesets.asm`: In `LoadTilesetHeader`, add `mov byte [ebp + hMovingBGTilesCounter1], 0` immediately after storing `hTileAnimations` (`mov [ebp + hTileAnimations], bl`), restoring pret lines 18–19 fidelity.
- [x] **A.2** `elevator.asm`: Add structured machine-parsed `DEVIATION{class=timing; pret=engine/overworld/elevator.asm:ShakeElevator; behavior=the sound-channel active wait is bounded by a 600-iteration CPU loop rather than polling audio register hardware directly; evidence=audio channel state on DOS is driven asynchronously by the PIT mixer; lifetime=permanent}` to `ShakeElevator`.
- [x] **A.3** `cut.asm`: Replace free-form projection comment on `ReplaceTreeTileBlock` with `DEVIATION{class=projection; pret=engine/overworld/cut.asm:ReplaceTreeTileBlock; behavior=wCurrentTileBlockMapViewPointer formula uses MAP_BORDER 7 and SCREEN_BLOCK_WIDTH 12 for the 40x25 viewport; evidence=native renderer viewport geometry; lifetime=permanent}`. Remove stale `; TODO-HW: rOBP1` in `InitCutAnimOAM`.
- [x] **A.4** `cut2.asm`: Remove stale comment claiming `AdjustOAMBlockXPos2/YPos2` are `UNPORTED`.
- [x] **A.5** `dust_smoke.asm`, `healing_machine.asm`: Remove stale `; TODO-HW: rOBP1` comments across both files.
- [x] **A.6** `field_move_messages.asm`, `hidden_events.asm`: Remove stale `UNPORTED PlayCry` and unresolved `HiddenEventMaps` comments.

---

### Stage B — Relocate PPU & Home Overworld Subsystems (S2, S3, S4, S5)

- [x] **B.1** Move `RefreshCollisionTileMap` from `dos_port/src/engine/overworld/overworld.asm` to [`dos_port/src/ppu/ppu.asm`](file:///mnt/sdb1/Code/Active%20Code/pokeyellow_msdos/dos_port/src/ppu/ppu.asm), co-locating it with `SnapshotRenderedTileMap`. Update callers (`src/home/overworld.asm`, `advance_player_sprite.asm`, `start_menu.asm`, `players_pc.asm`, `bills_pc.asm`, `town_map.asm`) to extern from `ppu.asm`.
- [x] **B.2** Move `StageIndoorMapBlk` into [`dos_port/src/home/overworld.asm`](file:///mnt/sdb1/Code/Active%20Code/pokeyellow_msdos/dos_port/src/home/overworld.asm) right before `LoadMapHeader`, and annotate with `DEVIATION{class=banking; pret=home/overworld.asm:LoadMapHeader; ...}`.
- [x] **B.3** Move `ApplyMapBorderOverrides` into [`dos_port/src/home/overworld.asm`](file:///mnt/sdb1/Code/Active%20Code/pokeyellow_msdos/dos_port/src/home/overworld.asm) right before `LoadTileBlockMap`.
- [x] **B.4** Promote `h_load_sprite_temp1` and `h_load_sprite_temp2` to canonical HRAM addresses in `include/gb_memmap.inc` (`H_LOAD_SPRITE_TEMP1 equ 0xFF8C`, `H_LOAD_SPRITE_TEMP2 equ 0xFF8D`). Remove `.data` definitions and update `InitSprites` / `LoadSprite` in `src/home/overworld.asm` to use `[ebp + H_LOAD_SPRITE_TEMP1/2]`.

---

### Stage C — Retire Ad-hoc Glue & Eliminate Double Map Load (F3, F4)

- [x] **C.1** In [`dos_port/src/home/overworld.asm`](file:///mnt/sdb1/Code/Active%20Code/pokeyellow_msdos/dos_port/src/home/overworld.asm), realign the `.displayDialogue` / `.displayOverworldText` dispatch: replace `call DoSignInteraction` and `call CheckNPCInteraction` with pret's single `call DisplayTextID` (`src/home/text_script.asm`).
- [x] **C.2** Delete `DoSignInteraction` from `overworld.asm` and retire its `DEVIATION{temporary}` annotation.
- [x] **C.3** Eliminate `LoadDestinationMapData`: In `src/home/overworld.asm`, update `WarpFound2` to match pret by setting `wCurMap`, `wLastMap`, `BIT_STANDING_ON_DOOR`, and tail-jumping straight to `EnterMap`. Verify single-pass `LoadMapData` execution and remove the `wDestinationWarpID` save/restore workaround. `StageIndoorMapBlk` now called from `asm_0dbd` (inside `LoadMapHeader`) to preserve indoor window staging without the double load.

---

### Stage D — Dissolve `src/engine/overworld/overworld.asm` (S1, S6)

- [ ] **D.1** Move embedded data asset includes (`overworld_gfx.inc`, `overworld_blocks.inc`, `overworld_coll.inc`, and all outdoor `.blk.inc` files) from `overworld.asm` to [`dos_port/src/data/maps/map_headers.asm`](file:///mnt/sdb1/Code/Active%20Code/pokeyellow_msdos/dos_port/src/data/maps/map_headers.asm).
- [ ] **D.2** Move `EnterMapBoot`, `SetupPlayerSprite`, and `LoadOverworldAssets` to [`dos_port/src/home/init.asm`](file:///mnt/sdb1/Code/Active%20Code/pokeyellow_msdos/dos_port/src/home/init.asm) as dedicated boot initialization routines.
- [ ] **D.3** Move debug helpers (`SeamReseatView`, `WalkSpeedSample`, `seam_seeded`, `trroute_seeded`) under `%ifdef DEBUG_*` guards in `src/home/overworld.asm`.
- [ ] **D.4** Move `player_sprite` asset include (`assets/player_sprite.inc`) to `src/data/sprites/` or `src/home/player_gfx.asm`.
- [ ] **D.5** Delete [`dos_port/src/engine/overworld/overworld.asm`](file:///mnt/sdb1/Code/Active%20Code/pokeyellow_msdos/dos_port/src/engine/overworld/overworld.asm) entirely and remove its entry from `dos_port/Makefile` (`GAME_SRCS`).

---

### Stage E — Verification, Static Gates & Fidelity Suite

- [ ] **E.1** Run `make -C dos_port check` and verify clean build with zero warnings or undefined symbols.
- [ ] **E.2** Run `dos_port/tools/static_gate` and `dos_port/tools/lint_pret_labels --no-scan --strict-claims`.
- [ ] **E.3** Run core fidelity suite: `make -C dos_port fidelity`.
- [ ] **E.4** Run full fidelity suite: `make -C dos_port fidelity-full` (verifying all 66 scenarios pass 100%).
- [ ] **E.5** Archive plan to `docs/plans/engine_overworld_realign.md`.
