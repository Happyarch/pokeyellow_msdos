# Port-introduced bugs and potential bugs — audit 2026-10-02

Skills used: `faithfulness-review` (fidelity gate, faithdiff/lint provenance, BUG/DEVIATION annotation discipline), `build-and-debug` (headless dumps, PAL.BIN/FRAME.BIN, golden harness, memmap audits), `asm-translation` (register map, ZF/CF preservation, counter-width, endianness/signedness, EBP model), `project-conventions` (BUG/DEVIATION/STUB schema, two-tier data rule, active-plan convention).
Why: every finding below is either a divergence from pret as specification, a widened/relocated construct the translation skill defines, or a stigmergy-tracked regression with a repro command.

Stigmergy checked: `memory_search regression bug`, `memory_search port bug audit`, `memory_search regression OPEN`, `memory_search bug class`, `episode_list bug` (top 20). Claims checked: tree-wide active claims listed before writing; this file claimed as `docs/port_bug_audit_2026-10-02.md` (claim 2744). Regression memories re-read in full for the five OPEN items in §A.

Static state re-measured 2026-10-02 (host, worktree HEAD `d670ec5cb`):
- `audit_memmap.py`: `1316 symbols, 78 sized regions — clean: no overlaps, no strays`
- `check_ram_straddle.py`: `clean — no difference expression spans a growth point`
- `unnamed.py pkmn.sym`: `Unnamed pokeyellow symbols: 0 (100.00% complete)`
- `validate_scenarios.py`: `109 scenarios consistent`
- Annotation counts: `DEVIATION: 743, BUG: 52, GLITCH: 11, STUB: 0` (STUB 0 = all 14 legacy stub files retired; BUG entries below are near-all pret-bug preservation, not port bugs — see §C)
- `TODO-HW` still present in ~30 files (serial/timer/LCD/fade paths — known deferred HAL boundaries, not filed as bugs here)

Subagent sweep (read-only, no edits, 2026-10-02): three `explore` audits covering (1) counter-width `movzx+dec r32`, (2) `g_tilecache_dirty` invalidation, (3) flag-preservation + endianness + signedness. Their verdicts are folded into §B/§D with file:line pointers. No subagent wrote code; all findings below were re-verified against the tree by the root before filing.

> Scope note: `BUG{}` in-tree means "pret did this; port replicates it" (Gen-1 behavior preserved under `BUG_FIX_LEVEL`). Only §A/§B are port-introduced or potentially port-introduced. §C explains what was deliberately NOT filed and why.

---

## A. Confirmed port-introduced bugs (stigmergy-tracked, with repro — A1 and A5 FIXED; A2/A3/A4 open)

### A1. Indoor maps share one VGA DAC palette — `regression-indoor-maps-share-one-dac-palette` — **FIXED**
- **RESOLVED:** the hidden-object gates seeded `wCurMap` but never `wLastMap`, so the
  palette path derived from a stale/zero previous map and every indoor gate
  published the same DAC bytes. The gate now passes `HIDDENOBJ_LAST_MAP` (6th
  argument to `hiddenobj_gate`, `dos_port/Makefile:2145-2147`, wired for
  BINOCULARS=`0x18`, OAKSPOSTER=`0x00`, STATUES=`0x02`) and `EnterMap` seeds it
  (`dos_port/src/home/overworld.asm:598-600`). Static-verified in the tree;
  the DAC-level gate run is NOT VERIFIED by this pass (heavy harness).
- Symptom (historical): three different indoor maps render byte-identical `PAL.BIN` (`md5 e549a3ea2725` for ROUTE_15_GATE_2F, OAKS_LAB, PEWTER_GYM); outdoor INDIGO_PLATEAU differs (`517b8757ccb4`). Maintainer: "Brock's gym had the Pallet Town palette".
- Evidence: memory body: "golden_diff's PALETTE section for all three scenarios reports the SAME 8 divergences and no others — OBJ pal4..pal7 colour2/colour3 … THE BG PALETTES MATCH THE ROM. So the CGB palette RAM the port computes for each map is right, and what is wrong is downstream of it — the VGA DAC that `commit_palette` (`boot/video.asm`) publishes, which early-outs unless `g_pal_dirty` or one of rBGP/rOBP0/rOBP1 changed."
- Repro:
  ```
  tools/run_headless.sh "DEBUG_BINOCULARS=1" /tmp/p1
  tools/run_headless.sh "DEBUG_OAKSPOSTER=1" /tmp/p2
  tools/run_headless.sh "DEBUG_STATUES=1" /tmp/p3
  md5sum /tmp/p{1,2,3}/PAL.BIN
  ```
- Why the suite is blind: `GBSTATE.BIN` dumps `cgb_palettes` (which match), never the DAC bytes. A DAC-level golden or `g_pal_dirty` arming audit is the fix direction. Open question recorded in memory: warp-in gate path vs normal warp — do not assume the gate is at fault.

### A2. SURF battle animation first half missing — `regression-battle-surf-animation-first-half-missing` (OPEN 2026-08-15, untriaged)
- Symptom (maintainer live play): SURF's droplet phase renders nothing; water-column phase renders correctly.
- Evidence: memory filed as observed-only, no code read. Starting point recorded there: SURF's frame-block/subanimation list; droplet phase likely uses a mechanism the column phase does not (OBJ particles vs BG effect / per-row displacement `g_row_xoff`).
- Repro (scripted probe, per memory): `DEBUG_ANIM_DEMO=1 ANIM=SURF` headless animation viewer.
- Code anchor: `dos_port/src/engine/battle/animations.asm` (`LoadMoveAnimationTiles` at :577,:2546 routes through `CopyVideoData` — correct by construction, so the defect is upstream in the subanimation primitive, not the tile load).

### A3. Stat-change message prints target as "PKMN" — `regression-battle-target-name-prints-pkmn` (OPEN 2026-08-15, triaged read-only)
- Symptom (maintainer live play): String Shot SPEED-fall message named the mon "PKMN".
- Evidence (triage eliminated the whole text path, all MATCH pret): composer `engine/battle/effects.asm:774-1011` (`MonsStatsRose/MonsStatsFell/ComposeStatIntro` writes `TX_START` + `<USER>/<TARGET>` byte correctly paired `$59` fall / `$5A` rise — moved here from `core.asm` in the battle realign); dispatch `src/home/text.asm:850-853` (`CHAR_TARGET $59` → `PlaceMoveTargetsName`, `CHAR_USER $5A` → `PlaceMoveUsersName`); handlers (`.handle_target` does `hWhoseTurn ^ 1`, pret's `PlaceMoveTargetsName` exactly). Therefore the nick buffer itself contained the PKMN glyphs.
- Fix direction (per memory): dump `wBattleMonNick` / `wEnemyMonNick` first; do not start in the text printer. Pret ref: `data/text/text_5.asm:_MonsStatsFellText` (`<TARGET>'s` + `text_ram wStringBuffer` — name is control char `$59`, stat name is the buffer, so a wrong NAME cannot be a `wStringBuffer` problem).

### A4. HRAM `FF8C` port alias is gate-blind — `regression-hram-ff8c-temp-relocation-gate-blind` (OPEN follow-up)
- Symptom: none today (harmless), but a live unauthorized alias the gate cannot see.
- Evidence: `H_LOAD_SPRITE_TEMP1=FF8C` (pret `hLoadSpriteTemp1=FF8D`), `TEMP2=FF8D` (pret `FF8E`) alias onto the `hTextID/hSpriteIndex` union byte (`gb_memmap.inc:973-974`). `check_ram_collisions.py` compares by name; the `UPPER_SNAKE` names never match pret's camelCase, so the `FF8C` group authorises on the other members. Only writers are `InitSprites`/`LoadSprite` (`overworld.asm:5268-5362`, e.g. `H_LOAD_SPRITE_TEMP1` at `:5268,:5333,:5349` and `TEMP2` at `:5272,:5352`) at map load; proven not in the `195-205` prize window (`FF8C=03` throughout).
- Fix direction: relocate to pret's own `FF8D/FF8E` (+ rename toward pret labels); moves the 8-reviewed-relocations baseline, so a separate work item with its own repro, not piggybacked. Companion fixed pair: `regression-hram-rlebytevalue-halveitemprices-squat` (FIXED 2026-09-25) — same "asserted free rather than derived" class.

### A5. Party-menu switch S4: player wears incoming mon's palette — **FIXED** (`regression-battle-party-menu-graphics-not-set-up`)
- **RESOLVED:** `SwitchPlayerMon` now rebinds the battle palette to the incoming
  mon before the send-out: `LoadBattleMonFromParty`, then
  `call SetPal_Battle` (`dos_port/src/engine/battle/core.asm:3763`, port R1
  palette binding), then `SendOutMon`. `SetPal_Battle`
  (`engine/gfx/palettes.asm:223`) arms `g_pal_dirty` and repaints through
  `RefreshMonFrontRepaintPalette`, so the switch path re-publishes instead of
  leaving the previous mon's back-pic palette resident. Static-verified; the
  headless switch witness is NOT VERIFIED by this pass.
- Context (historical): theme is port-only obligations of the battle caller of the full-screen party menu (whited-out BG + window descriptors): S1 FIXED `3975ae039` (`SetPartyMenuHPBarColor` publishes into window per-cell plane via `SetBGCellAttrWin`); S2 FIXED `7471492d9`; S5 FIXED `55d9d45b8` (missing `g_window_count` + `g_bg_whiteout` teardown); S5b FIXED `65aa5a233` (party menu restores `text_msgbox` to OVERWORLD record, wrong for battle caller); shift-prompt companion FIXED `f2477979a` (`GBPalWhiteOut` without `GBPalNormal` + missing `RestoreBattleScreenState` in `ChooseNextMon`).
- Do-not-re-file: v6 wrongly listed S1 as remaining; S1 was fixed the day before (commit subject "menus: party HP bars are coloured again — backlog 10b closed").

---

## B. Fresh POTENTIAL port bugs found this loop (need a repro before fixing)

Severity: none is confirmed reachable today. Each has the exact `file:line` shape, the pret counterpart, and the can-it-be-zero analysis. **B1–B3 are FIXED** (`cca010d0d`, 2026-10-06 — `gfx/overworld: narrow widened loop counters (audit B1-B3)`) and are recorded in §D. B4–B7 remain as filed. The fix for the loop bugs is `dec cl` (8-bit bound), NOT a zero-guard — a guard writes 0 items where the GB writes 256 (see `DelayFrames` precedent, §D).

### B1. `UpdateCurrentAnimatedObjectFrame` OBJ-count loop widens to 32 bits — **FIXED** (`cca010d0d`)
- Now `dec cl` at `animated_objects.asm:272` with the count widened only as `movzx ecx, byte [...]` for the pointer stride; the 8-bit decrement preserves pret's 0→256 bound. See §D.
- File: `dos_port/src/engine/gfx/animated_objects.asm:232` + `:272-273`
  ```
  movzx ecx, byte [ebp + esi]   ; ld a,[hli]/ld c,a (template OBJ count)
  ...
  dec ecx                       ; dec c
  jnz .loop                     ; jr nz, .loop
  ```
- Pret: `engine/gfx/animated_objects.asm:163/210` — `ld c, a … dec c / jr nz, .loop` (8-bit; count 0 runs 256 and stops).
- Can-be-zero: data-dependent (OAM-template first byte). No guard; observed tables always ≥1 but no structural guarantee. Same file `:84,113,192` use literal `mov ecx,10` — OK, never zero.
- Blast radius if hit: `dec ecx` wraps 0 → ~4.29e9, walks `[ebp+edx]` (shadow-OAM cursor) off the DPMI allocation → page fault. Fix: `dec cl`.

### B2. `PrepareOAMData` facing-entry tile loop widens to 32 bits — **FIXED** (`cca010d0d`)
- Now `dec cl` at `sprite_oam.asm:446`; the entry count is still `movzx ecx, byte [ebx]` but the loop bound is 8-bit. See §D.
- File: `dos_port/src/engine/gfx/sprite_oam.asm:387-388` + `:445-446`
  ```
  movzx ecx, byte [ebx]         ; entry count
  ...
  dec ecx
  jnz .tileLoop
  ```
- Pret: `engine/gfx/sprite_oam.asm:53` (`ld c, a`).
- Can-be-zero: data-dependent (facing-block entry count). Observed tables ≥1, no structural guarantee. Same shape and same fix (`dec cl`) as B1.

### B3. `ApplyMapBorderOverrides` run-length loop widens to 32 bits — **FIXED** (`cca010d0d`) (port-only, no pret counterpart)
- Now guarded: `movzx ecx, byte [esi+2]` + `test cl, cl / jz .run` at `overworld.asm:3204-3208`; a zero-length run copies nothing (the format-correct semantics for the port-only run encoding, unlike pret-faithful loops where 0 means 256). See §D.
- File: `dos_port/src/home/overworld.asm:3201-3209`
  ```
  movzx ecx, byte [esi + 2]     ; len
  add esi, 3
  .copy: mov al,[esi] / mov [ebp+edi],al / inc esi / inc edi / dec ecx / jnz .copy
  ```
- Format is `db row,col,len` runs from `assets/map_border_overrides.inc`; `len 0` is structurally encodable. Generator currently emits only nonzero runs, but nothing in the loop defends it.
- Blast radius: 0 wraps to ~4.29e9 `mov [ebp+edi]` writes. Fix: `dec cl` (or `test cl,jz` skip — here a skip IS safe because a 0-length run means "copy nothing" by construction of the port-only format, unlike the pret-faithful loops where 0 means 256).

### B4. `VBlankCopyBgMap` zero-guard diverges from pret (currently inert) — DIVERGENCE, flag if the queue is ever armed
- File: `dos_port/src/home/vcopy.asm:427-429` + `:444-445`
  ```
  movzx ebx, byte [ebp + hVBlankCopyBGNumRows]
  test ebx, ebx
  jz .done                     ; nothing queued
  ...
  dec ebx / jnz .row
  ```
- Pret: `home/vcopy.asm:203` (`ldh a,[hVBlankCopyBGNumRows] / ld b,a`, loop `TransferBgRows/dec b`) — 0 means 256 rows. The guard makes 0 → 0 rows.
- Verdict OK today only because the site is dead (header: queue currently never armed → self-gate `.done`); the guard prevents the wrap but IS the divergence. Same class as the removed `DelayFrames` guard. If anything ever arms `hVBlankCopyBGNumRows`, re-audit this first. Companion: `read_trainer_party.asm:220-221,230` prize-money loop has the same guard shape with `wCurEnemyLevel==0` unreachable — harmless dead code, same latent 0-vs-256 note.

### B5. `CopyData` / `FillMemory` 0-vs-256 divergences — INTENTIONAL, but every future caller inherits the contract
- Files: `dos_port/src/home/copy.asm:77` (`movzx ecx, bx ; BX=0 → 0 bytes (pret would copy 256 — see header)` + `rep movsb`); `dos_port/src/home/copy2.asm:226` (`movzx ecx, bx … count=0 → ECX=0 → rep stosb no-op. DIVERGENCE: pret BC=0 writes 256 bytes … Intentionally NOT emulated.`).
- No `dec`, so no unbounded loop — the hazard is semantic, not a fault: a caller passing `BC=0` expecting pret's 256 gets 0. Header claims no caller passes 0 expecting 256 (callers wanting 256 pass `$100`). Do not "fix" with a guard; do check each new `CopyData/FillMemory` caller for the zero case. Reference repair pattern for the REAL loop bugs lives beside them: `CopyVideoDataDouble/FarCopyDataDouble/ClearScreenArea` (`copy2.asm:134-204,294`) use `mov cl,bl / test cl,jz .done / dec cl` with the comment "`movzx ecx, bl` + `imul ecx,16` + `dec ecx` wrapped 0 → ~4.29e9 and walked EDI off the DPMI allocation."

### B6. Signed slot-0 projection cannot represent pret unsigned OAM X ≥ 0x80 — PERMANENT DEVIATION, data rescaled to hide it
- Files: `dos_port/src/engine/overworld/player_animations.asm:204` (`EnterMapAnim`) + `:303` (`_LeaveMapAnim`) — first four X bytes rescaled `0x98 0x90 0x88 0x80 → 0x7F 0x7D 0x7B 0x79` (and `0x48-0xA0 → 0x48-0x7F`, `0x90 0x80 → 0x78 0x74`).
- Evidence (annotation): "`DoFlyAnimation` writes these into `wSpritePlayerStateData1XPixels` and `PrepareOAMData` slot-0 projects the player X with signed `movsx` plus 96 onto the 320-wide DOS canvas so any byte at or above `0x80` sign-wraps to a negative canvas X whereas GB hardware reads OAM X unsigned 0-255."
- Why filed: the rescaling fixes the two known tables, but the renderer limitation is shared — any FUTURE table/routine writing `≥0x80` into the slot-0 X path re-exposes it (old `0x80` gave canvas -32, bird snapped to left edge). The general fix is a shared-renderer change (unsigned slot-0 projection), not more table rescaling. Contrast: `GBScreenToCanvasXY` (`sprite_oam.asm:62-77`) HAD the same `movsx` bug until 2026-08-15 (right-half/lower sprites sent to negative canvas; Route 3 lass '!' bubble never appeared) and is now `movzx` — the slot-0 path is the one that stayed signed.

### B7. `WarpFound2` non-warp arms store port garbage instead of ROM garbage — benign TODAY, tripwire for new readers
- File: `dos_port/src/home/overworld.asm:2439` (`DEVIATION{class=projection; … behavior=… on the three entries that are not a warp scan, both Safari game-over arms and the script warp, BL holds whatever the port last left there rather than whatever pret last left in c … lifetime=permanent, an artifact of pret reading an unset register}`).
- Pret reads unset `c` on those arms too, so the store is indeterminate on both sides; the only readers (Celadon Mart / Rocket Hideout / Silph Co elevator scripts) are entered through a warp TILE where the scan has run and both sides agree. Filed so a future reader of `wWarpedFromWhichWarp` outside those three scripts knows the value is garbage on BOTH sides, not a port bug to "fix" by initialising it (initialising would DIVERGE the garbage).

---

## C. What was deliberately NOT filed (with why)

- In-tree `BUG{}` (52) / `GLITCH{}` (11): near-all preserve documented Gen-1 behavior (e.g. `names2.asm:34` HM01 threshold, `trainer_ai.asm:125,204,261,637` AI quirks, `effects.asm:214,310,542,760,1873` Sleep/1-in-256/Freeze/Disable, `core.asm:1816,1945` Psywave/freeze-recharge, `animations.asm:1197` OAM-attr off-by-one with pret's own "bug, sets previous OAM entry's attribute" comment). They are pret bugs faithfully replicated under `BUG_FIX_LEVEL`, not port bugs. Do not cite them as port findings.
- `DEVIATION{class=projection}` (~bulk of 743): widescreen/flat-model/window-compositor consequences (viewport 40×25 vs 20×18, `MAP_BORDER 7`, stride-40 tilemap, `hWY parked at 200`, dialog-projection records, `DefaultMapScript` standing in for ~209 identical per-map `jp EnableAutoTextBoxDrawing` bodies). Sanctioned permanent HAL/projection, each with `evidence` + `lifetime`. The two out-of-map clamps (`DrawTileBlock` block-ID clamp, `LoadCurrentMapView` border-block clamp) are PERMANENT maintainer decision 2026-08-16 — do not propose retiring them.
- Recently FIXED pattern kept as tripwire, not a finding: START-menu null-text-table ordering (`cf5ec020d`, gated `4c5dad6a1`, scenario `start_menu_null_text_map` id 110 — port-only null bail sat before `hTextID==0 → DisplayStartMenu` dispatch on the 34 NULL-table maps like `REDS_HOUSE_2F`). Currency is the golden, which FAILS (102 unmasked divergences) when the ordering is reverted. Watch for the same shape (port-only early bail before pret's dispatch) in new code; do not re-file this one.
- `wPlayerCoins 0xD5A4→0xD5A3` (`regression-memmap-wplayercoins-off-by-one`, FIXED 2026-08-17): source-verified against `ram/wram.asm` + `pokeyellow.sym`, still with no golden exercising Game Corner coins — a verification gap, not an open bug.

---

## D. Clean sheets this loop (do not re-audit without new evidence)

- **B1–B3 widened loop counters — FIXED `cca010d0d` (2026-10-01).** `UpdateCurrentAnimatedObjectFrame` (`animated_objects.asm:272`) and `PrepareOAMData` (`sprite_oam.asm:446`) now `dec cl` (pret's exact 8-bit bound, no `DEVIATION` owed); `ApplyMapBorderOverrides` (`overworld.asm:3204-3208`) now `test cl,cl / jz .run` so a port-only zero-length run copies nothing. Verified by that commit's own evidence (nasm exit 0, `lint_pret_labels --no-scan` 0); the current tree still shows all three edits, and this pass re-assembled the touched files cleanly.
- **Tile-cache invalidation:** swept `home/copy2.asm:91,119,168`, `home/vcopy.asm:484,576,673`, `home/load_font.asm:52,86,120,161`, `home/overworld.asm:3164,4384`, `gfx/load_pokedex_tiles.asm:46`, `gfx/mon_icons.asm:315`, `battle/draw_hud_pokeball_gfx.asm:109`, `battle/battle_transitions.asm:273`, `battle/ghost_marowak_anim.asm:153`, `battle/animations.asm:577,2546`, `battle/core.asm:7166`, `battle/init_battle.asm:283,651,845` (via `pics.asm:219`), `menus/draw_badges.asm:103`, `menus/naming_screen.asm:919`, `menus/start_sub_menus.asm:801,815,828,840,847,852`, `movie/title.asm:334` (terminal arming via `title_yellow.asm:100`), `slots/slot_machine.asm:994,1000,1010` (terminal arming at `:1017`). All route through `CopyVideoData*` or arm `g_tilecache_dirty` in the same load sequence. `vBGMap` tilemap fills, OAM/WRAM `rep movs`, and `evos_moves.asm:362` correctly do NOT arm. Verdict: 0 missing invalidations in the swept areas.
- **Flag preservation:** `battle/core.asm:1856-1866,2840-2850,6771-6784` (HP `sub→mov→sbb→jnc`, `mov` flag-neutral, BE low-then-high correct), `:2088-2092` Bide `add→adc`, `:2105-2110` `add→rcl`, `experience.asm:297-305` 3-byte `sub→sbb→sbb→jc` (`dec` preserves CF as SM83 preserves C), `heal.asm:140-146` (faithful discarded-MSB bug: `jz` reads `sbb` not `cmp`), `common_text.asm:144-150`, `serial.asm:289-293,302-305`, `movement.asm:755-762` (`call` preserves `EFLAGS` into `Func_5033`'s `jnc`), `compare.asm:11-18`. Verdict: clean in sampled scope.
- **Endianness:** reference idiom `battle/core.asm:7548-7561` (`movzx hi / shl 8 / mov lo` = `hi*256+lo`), `trainer_ai.asm:803-929`, `experience.asm:39-45`, `item_effects.asm:268-288`, `print_num.asm:96-102` (MSB-first accumulate, LE bug fixed). `debug_dump.asm:6669` `cmp word [HP],0x1F03` for 799 is the correct byte-swap-immediate idiom (`799=0x031F`, BE bytes `03 1F` read as LE word `0x1F03`), not a misread. GB `dw` pointers correctly `word`-loaded (`overworld.asm:3975,4067`, `uncompress.asm:219,282,310`); `text_script.asm:489-491` BE store is pret's own H-then-L quirk. Verdict: clean.
- **Signedness:** every sampled `movsx` is on a genuinely signed quantity (`battle_transitions.asm:565,599` signed tile offset; `scale_sprites.asm:75,108` `BX=-55/+55`; `animations.asm:2617` signed shake; `sprite_oam.asm:397,410` table Y/X with `-4` entries; step/row offsets; `ppu.asm:924` signed `$9000`-mode tile id vs `decode_tile:964` unsigned path — intentional pair). `sprite_oam.asm:317-324` vs `movement.asm:526-537` `movsx`-vs-`movzx` on `MAPY/MAPX/wYCoord/wXCoord` is style-only (`<64`, `<128`, numerically identical). Verdict: clean.
- **Fixed-reference loops:** `home/delay.asm:61` (`DelayFrames` `dec bl`, 8-bit faithful), `home/text.asm:394` (`.fill_chars` `dec cl`, was `dec ecx` page-fault), `home/copy2.asm:134-204,294`, `home/overworld.asm:4832` (`CopySignData` `dec cl`), `:3260-3271`, `:3377,3404` (literal `MAP_BORDER`/counts), `town_map.asm:527,979`, `load_font.asm:67`, `pics.asm:199/211`, `vcopy.asm:390,634,642`, `text.asm:463,707`, `audio/engine_1.asm:832` — all literal-nonzero or 8-bit. `learn_move.asm:153` / `add_mon.asm:370` `movzx+dec` are index arithmetic, not loops. Verdict: OK, and the `test/jz` guard is NOT an equivalent fix (0→0 vs GB 0→256).

---

## Repro / verification index

| ID | Command / gate |
|----|----------------|
| A1 | `tools/run_headless.sh "DEBUG_BINOCULARS=1" /tmp/p1` etc. + `md5sum PAL.BIN`; render with `tools/render_frame.py FRAME.BIN out.png PAL.BIN` |
| A2 | `dos_port/run DEBUG_ANIM_DEMO=1 ANIM=SURF` or `make -C dos_port goldencheck SCENARIO=<anim_surf>` if registered; check `validate_scenarios.py` |
| A3 | headless dump of `wBattleMonNick/wEnemyMonNick` in a stat-fall battle; text path already eliminated — do not re-audit `effects.asm:774-1011` / `text.asm:850-853` |
| A4 | `tools/check_ram_collisions.py` will NOT show it (gate-blind by name); inspect `gb_memmap.inc:973-974` + writers `overworld.asm:5268-5362` |
| A5 | live play `TRAINER_ROUTE_PILOT=1` Route 3 → PKMN → switch; headless does not reproduce. FIXED — `core.asm:3763` (witness not run this pass) |
| B1–B3 | code read (lines above) + pret `ld c,a/dec c/jr nz` counterparts; repro = drive count 0 (template/face-table/run-length) headlessly and watch for page fault / 4e9 walk |
| B4 | arm `hVBlankCopyBGNumRows=0` vs pret 256-row expectation; currently inert |
| B5 | grep new `CopyData/FillMemory` callers for `BC=0` |
| B6 | write `≥0x80` into slot-0 X path (`wSpritePlayerStateData1XPixels`) and observe canvas sign-wrap |
| Gates | `dos_port/tools/lint_pret_labels --no-scan` must stay 0; `static_gate` ratchet both ways; `fidelity_gate` per touched label; `make -C dos_port fidelity` core tier (~30s parallel via `pgate.sh`, never `fidelity-serial` unless maintainer asks) |

*Evidence policy: every OPEN claim above cites generated state (`project_state`, `audit_memmap`, `check_ram_straddle`, `unnamed`, `validate_scenarios`), runtime dumps (`PAL.BIN` md5, `FRAME.BIN`), or line-pinned code pairs (port + pret). `port-only` is never inferred from the raw `status` column alone (see AGENTS.md: 216/776 `port_only` rows are real pret labels via `aux_labels`/`script_labels`); `unreachable` is never inferred from `reachability` alone (`dd Label` tables + ISRs have no edges). Matching aggregates are decomposed per the symmetric-confirmation rule.*

---

# Iteration 2 (same date, new areas — nothing above re-filed)

Skills used: same four. Stigmergy re-queried: `regression OPEN`, `bug audit`, plus full reads of `bug-hunt-detector-gaps-2026-09-25`, `flagactionpredef-clobbers-regs`, `bug-class-loop-counter-in-cl-across-a-clobbering-call`, `coord-macros-logic-audit`, `bug-class-gb-counter-widened-to-32-bit`. All line numbers re-verified against the tree this iteration.

## E. Live port bug: `FlagActionPredef` called without predef-slot setup in tool-seeded scripts

Rule (memory `flagactionpredef-clobbers-regs`): the port has no predef dispatcher, and `FlagActionPredef`'s first instruction is `call GetPredefRegisters`, which reloads ESI/EDX/EBX from `wPredefHL/DE/BC`. Nothing populates those slots on these paths, so register-set-up callers get their inputs overwritten with stale garbage and the flag read/write lands at a random WRAM address — no fault, no symptom at the call site. Standing convention everywhere else in the tree is `call FlagAction` with `ESI=array, CL/BH=index/action` (documented deviations in `evos_moves.asm:896-902`, `pokedex.asm:681-691`, `core.asm:3737,5468`, fixed call sites in `experience.asm:510,542,553`).

### E1. `Route23.asm` — 3 direct `call FlagActionPredef` with register setup, zero slot setup — BUG (static-proven, runtime repro owed)
- Sites: `:160` (`ESI=wEventFlags+EVENT_BYTE(...)`, `BH=FLAG_TEST`, `BL=whichBadge`), `:322` (`ESI=wObtainedBadges`, `BH=FLAG_TEST`), `:344` (`ESI=wEventFlags+...`, `BH=FLAG_SET`). Each sets ESI/BH/BL directly, then `call FlagActionPredef`.
- Evidence of missing setup: `grep wPredefHL/wPredefBC/wPredefDE dos_port/src/scripts/Route23.asm` → zero hits. Same for `CinnabarGym.asm` → zero hits.
- Evidence of clobber: `dos_port/src/engine/flag_action.asm:11-13` is `FlagActionPredef: call GetPredefRegisters` + fallthrough into `FlagAction`; `GetPredefRegisters` (`home/predef.asm:27-37`) does `movzx esi,ax / movzx edx,ax / movzx ebx,ax` from the three WRAM slots — every input register the caller just set is destroyed before use. (`predef.asm:11` confirms "no predef caller exists in the port yet, so the predef WRAM slots are populated directly by callers" — these callers do not.)
- Why correct on GB: pret uses the `predef` dispatcher (`scripts/Route23.asm:54,203,220`), which stashes HL/DE/BC into the slots before jumping — so `GetPredefRegisters` restores the right values there. The port replaced dispatch with a direct call but kept the restoring prologue: the stash never happens, the restore reads stale.
- Impact: badge-gate progression flags (`EVENT_PASSED_CASCADEBADGE_CHECK`, `wObtainedBadges` membership, badge-set after guard dialogue). Wrong address/bit = guard blocks a qualified player or waves through an unqualified one, depending on whatever stale bytes happen to be in the slots.
- Note on registers: `mov al,bl` after the call is NOT a second bug — port register map is SM83 BC→BX so BL *is* pret's C (`ld a,c`). Only ESI/EBX-via-slots is at fault.
- Repro owed: drive the Route 23 guard with a known badge state headlessly and observe the branch; no scenario covers the Itemfinder-equivalent here either (cf. the loop-counter memory's "WITNESS OWED" note for the same reason).

### E2. `CinnabarGym.asm` — 4 calls through the `CinnabarGymFlagAction` trampoline — same BUG, same evidence
- Trampoline: `:184-186` is `CinnabarGymFlagAction: jmp FlagActionPredef` (with only a banking `DEVIATION` about A holding the callee's leftover, which is fine — no dataflow reads A after).
- Callers: `:303` (gate-unlock TEST), `:343` (trainer-beaten SET), `:355` (trainer-beaten TEST), `:367` (gate-unlock SET). All follow the identical pattern: `mov bl,<bit> / mov bh,FLAG_TEST|FLAG_SET / mov esi,wEventFlags+EVENT_BYTE(...)` then `call CinnabarGymFlagAction`. Pret counterpart is `predef_jump FlagActionPredef` (`scripts/CinnabarGym.asm:45-46`, called at pret `:142,176,185,194`) — same dispatcher-stash reasoning as E1.
- Impact: gym gate unlock + quiz-beaten bookkeeping. A stale-slot read here can leave the gate shut after a correct answer or mark an unbeaten trainer beaten.
- Fix (both files): `call FlagAction` / `jmp FlagAction` with the existing register setup, plus the standard banking `DEVIATION` already carried. Do NOT "fix" by populating `wPredefHL/BC` — that would simulate the dispatcher for one call site instead of using the port-wide direct convention.

## F. Palette-dirty arming: writers all arm, so A1's stale DAC means no writer ran (narrows, not re-files, A1)

Swept this iteration: `SetPal_BattleBlack` (`palettes.asm:218` arms), `SetPal_Battle` (`:279-280` arms after the `RefreshMonFrontRepaintPalette` call at `:277`), `SetPal_Screen` (`:329-330` arms), `ApplyMonFrontRepaint` (`pics.asm:412-413` arms both `g_tilecache_dirty` + `g_pal_dirty`).
- `RefreshMonFrontRepaintPalette` (`pics.asm:421-469`) writes `bg_slot_pal+4` (`:431-432`) and `tile_pal[]` (`:458`) with NO local arming — but its only caller in the tree is `SetPal_Battle:277`, which arms both flags immediately after (`:279-280`), and its early-outs (`:423-424` inactive, `:427-428` null record) skip all writes, so nothing is owed on those paths. Verdict: OK-today, fragile-by-construction (same terminal-arming shape as `movie/title.asm:334`, previously accepted). Tripwire: any second caller added without terminal arming re-exposes stale front-pic palettes; prefer arming inside `Refresh` itself if it ever gains one.
- Consequence for A1: every palette writer in the swept set arms `g_pal_dirty`. A byte-identical stale `PAL.BIN` across three indoor maps therefore points at the warp-in gate path running NO palette writer at all (stale DAC kept by `commit_palette`'s early-out), not at a writer forgetting the flag. That eliminates one hypothesis from A1's open question; the remaining work is still to determine whether the gate path or normal warps skip the load.

## G. Detector gaps: five live tooling blind spots (bugs about the gates, not the game)

Source: memory `bug-hunt-detector-gaps-2026-09-25` (measured 2026-09-24/25, all green gates + real defects). Re-confirmed live this iteration; gate changes need maintainer approval, so filed here, not fixed here.

- G1. Orphan `; Safety:` lines (3): `home/names2.asm:44`, `battle/effects.asm:1808`, `items/item_effects.asm:1820`. `LEGACY_ANNOTATION_RE` matches `DEVIATION|STUB|BUG|GLITCH` but not `Safety:`, so each survives `--strict-claims` despite the migration being otherwise complete. Fix: extend the regex (or fold the lines into their paired structured annotations).
- G2. Annotations outside `dos_port/src` never validated: `boot/entry.asm:3,170`, `boot/timing.asm:3`, `boot/video.asm:3`, `include/gb_memmap.inc:882,1592,1617`, `include/gb_macros.inc:39` (template). `lint_pret_labels:479` walks `dos_port/src` + `.asm` only. A malformed `DEVIATION` in `boot/` or `include/` fails nothing.
- G3. Stale-provider regex blind to bare-path extern comments: `lint_pret_labels:351` only checks comments carrying the `src/` prefix (2090 of 3253 checked); 1163 bare-path comments are never resolved, of which 56 name a file existing in NEITHER tree (memory's examples: `gfx/load_font.asm`→`home/load_font.asm`, `text/text.asm`→`home/text.asm`, `battle_data.asm`→the four `data/battle`+`data/types` files). Fix comments BEFORE widening the regex or lint goes red.
- G4. Counter scan is register-only: it matches `movzx (ecx|ebx|edx), <8-bit REGISTER>` only, so counts from MEMORY are invisible. Corroborated this loop: iteration-1 findings B1 (`movzx ecx, byte [ebp+esi]`, `animated_objects.asm:232`) and B2 (`movzx ecx, byte [ebx]`, `sprite_oam.asm:387`) are exactly the memory-source shape the scan cannot see.
- G5. `check_ram_collisions.py` blind to flat-`.bss` pret-named labels: it scans only `gb_memmap.inc` + `pret_ram.inc`, so `wMapSpriteData` / `wMapSpriteExtraData` (`map_sprites.asm:85-86`, referenced across 7 files: `home/overworld.asm`, `home/map_objects.asm`, `home/text_script.asm`, `home/trainers.asm`, `overworld/movement.asm`, `map_sprites.asm`, `events/pick_up_item.asm`) are invisible, and `strays()` skips any name present in pret, so a pret symbol shifted inside another pret symbol's extent is not flagged (this is how the bss-save break read clean).

## H. Approved-but-unimplemented data-loss guard: `SramStoreImage` torn-write (backlog 39)

- Evidence: `docs/current_plan_backlog.md:1066-1078` — maintainer APPROVED (2026-08-02, overturning C6's "accepted as-is") a write-temp + atomic-rename guard (INT 21h `AH=56h`) at measured ≈8.7 ms/save. A torn write is detectable (header checksum fails → `SramLoadImage` corrupt-save branch) but NOT recoverable: the save reads as a fresh cartridge, silently destroying the playthrough. Must carry `DEVIATION{class=HAL; ...}` (pret/hardware has no counterpart). Work is on `SramStoreImage` (`src/save/dsv_io.asm`); none of the four existing save scenarios exercises a torn write.
- Filed as potential data-loss rather than mistranslation: the on-disk format is correct, the write sequence is not crash-safe.

## I. Checked-clean this iteration (do not re-audit without new evidence)

- PPU LUT builders (`ppu.asm:910-932`): `movsx eax,cl` at `:924` is the intentional signed `$9000`-mode tile-id decode (ids `$80-FF` address `$8800-8FFF`); `jb` at `:920,930` is on the unsigned ECX 0..255 loop counter — no width/compare crossing. The `:924`/`:964`-`decode_tile` signed/unsigned pair is deliberate (cf. iteration-1 §D).
- `movement.asm:304-317,530-543,839-844` `jg/jl` on `movzx`'d MAP/coords: values are `<64`, `lea` displacements (`-7..+10`) stay non-negative in practice and both sides agree on the small-positive domain — no reachable inversion. Crossing hunt otherwise empty in sampled scope.
- `bug-class-loop-counter-in-cl-across-a-clobbering-call` (CLOSED 2026-08-12): both instances fixed (`DivideExpDataByNumMonsGainingExp`, `ItemUseItemfinder`); 37-site shape-1 triage stands (19 protected, 17 safe). No new `dec cl`-across-call site filed this loop; the script files in §E hold no loop counters.
- `coord`/`hlcoord` projection debt (memory `coord-macros-logic-audit`): `owcoord` border-generic fix and `event_displacement` re-derivation stand; `coord`-family stride-40 arithmetic correct but pret screen-coord literals still need per-site `ui_projection.md` re-projection and `validate_coords` only `%error`s on ≥40. No new mis-projected literal proven this loop — noted as the place to look when a menu/dialog tile lands wrong, not as a finding.

---

# Iteration 3 (same date, new areas — nothing above re-filed)

Skills used: same four. Two read-only `explore` subagents (IO-register boundaries; window-compositor obligations) plus root verification of every cited line. `lint_pret_labels --no-scan` re-measured this iteration: **EXIT=0 both modes, 0 violations** (strict-claims included).

## J. Live port bugs: overworld `DisplayPartyMenu` callers leak the compositor state — BUG (code-inspection, runtime repro owed)

The obligation chain, all verified this iteration:
- `ShowPartyMenuWindows` (`engine/menus/party_menu.asm:537-557`) raises `g_bg_whiteout=1` (`:538`), `g_obj_over_window=1` (`:542`), and **two** windows (`set_single_window` `:549`, `add_window` `:556`), then `ret` — no in-file teardown.
- `DisplayPartyMenu` (`home/pokemon.asm:261-281`) and every `HandlePartyMenuInput` exit (`clc/ret` chosen, `stc/ret` cancelled) perform **zero** whiteout/window/msgbox teardown (only `grep` hit for those symbols in `home/pokemon.asm` is the *entry* `ClearSprites` at `:266`, which zeroes `obj_over` *before* the menu re-arms it).
- Teardown is therefore 100% caller-owned. Battle callers honour it via `RestoreBattleScreenState` (`battle/core.asm:3526-3530`: `g_window_count=0`, `g_bg_whiteout=0`, `text_msgbox=msgbox_centered`, always paired with an adjacent `ClearSprites` for `obj_over`) — audited exit-by-exit this iteration (`:3576-3596` cancel, `:3701-3720` switch, `:5490-5511` forced, `:6057-6073` shift-prompt, `:3462-3517` bag paths): all OK.
- Nothing else in the tree clears the leaked state: tree-wide `g_bg_whiteout` writer grep shows clearers only in `start_sub_menus` (×7), `cut`, `movie`, `surfing`, `naming`, `main_menu`, `pokedex`/`town_map`/`evolution` save-restores, `prize_menu`, and battle core. `LoadGBPal`, `ReloadTilesetTilePatterns`, `RestoreScreenTilesAndReloadTilePatterns`, `RedrawMapView`, `ClearScreen` touch none of the three flags. `text.asm:688`, `movement.asm:955`, `pikachu_follow.asm:1734`, `vblank.asm:244` only READ whiteout.

### J1. `InGameTrade_DoTrade` — both paths — BUG
- `engine/events/in_game_trades.asm:206` `call DisplayPartyMenu`, then `:209` `call InGameTrade_RestoreScreen` (`:273-283`: WhiteOut + tile/palette restores + `LoadGBPal` + `DelayFrames` + `jmp LoadWildData`) — no `g_window_count`, `g_bg_whiteout`, `g_obj_over_window`, or `text_msgbox` handling on the cancel path (`:209-212`) or the success path (`:257-259`, which re-calls `RestoreScreen` + `RedrawMapView`, neither of which clears). Expected visible effect: whiteout stuck at 1 (overworld renders white — `render_bg` skips the tilemap) plus two stale windows composited; `obj_over=1` leaves GB order into the overworld (dialog under OBJ).
- Repro owed: drive an in-game NPC trade headlessly (cancel + complete) and inspect `FRAME.BIN`/subsequent overworld render. No scenario covers it.
- Correction to scope: `:229` `call InGameTrade_FlagActionPredef` is NOT an §E instance — `:398-402` is a local leaf that sets `ESI=wCompletedInGameTradeFlags`/`CL=wWhichTrade` itself and `jmp FlagAction` directly (bypassing `GetPredefRegisters`), with a `:394` DEVIATION documenting exactly why. It joins `home/trainers.asm:TrainerFlagAction` (`jmp FlagAction`, verified this iteration) as the correct-pattern exemplars that make §E's seven sites stand out. §E otherwise stands unchanged (Route23 ×3 + CinnabarGym ×4 call the real predef wrapper).

### J2. `Daycare.asm` deposit — BUG (same shape, one shared gap)
- `:107` `call DisplayPartyMenu`, then `:109-111` `GBPalWhiteOutWithDelay3` + `RestoreScreenTilesAndReloadTilePatterns` + `LoadGBPal` — no compositor teardown on cancel (`:114`) or accept (falls through `:116+`). Reachable in normal play (deposit with >1 mon), so this is the most likely of the three to have a visible witness already — repro: deposit headlessly, check the overworld render after.

### J3. `PokemonFanClub.asm` showcase — BUG ×2 paths
- Cancel (`:375-380`): `DisplayPartyMenu` → `WhiteOut` + `RestoreScreenTiles` only. Chosen (`:384-398`, incl. portrait + `ReloadTileset` + `Restore` + `LoadScreenTilesFromBuffer2` + `Delay3` + `GBPalNormal`): full tile/palette restore but still no window/whiteout/obj/msgbox teardown. Same expected effect as J1.

### J4. `town_map.asm` — POTENTIAL (narrower: `g_window_count` only)
- Whiteout is SAVED (`:480-481`), zeroed on entry (`:501`, "the bag menu may have set it"), and RESTORED (`:646-647`) — fine. But entry (`:485-513`) never hides windows while comment `:516` asserts `g_window_count==0` without establishing it. If the bag list window is up on the `.useItem` route, it stays composited over the flat-canvas modal. Needs a runtime FRAME check, not a fix — the bag path may hide first elsewhere.
- Latents noted, not filed: `status_screen.asm` never touches `g_obj_over_window` (stale `=1` through STATS; harmless today — zero windows ⇒ order moot, both callers re-arm — but a second screen stacked on STATS without re-arm inherits GB order); `bills_pc.asm:327,444,804` writes `g_bg_whiteout` with `mov byte` against the `dd` (functionally OK, upper bytes stay 0; width-mismatched, do not copy).

## K. I/O-register boundaries: clean sheet (do not re-audit without new evidence)

Subagent sweep of all 48 `IO_SCX|IO_SCY` hits + all `IO_LY/IO_STAT/rLY/rSTAT` references, mechanism re-verified by root:
- Every direct `IO_SCX/IO_SCY` write is shadow-paired: `commit_shadow_regs` (`home/vblank.asm:344-359`, sole caller `DelayFrame :134`) copies `hSCX/hSCY→IO_SCX/IO_SCY`; all 12 write sites (`init.asm:197-198`, `battle/core.asm:2271-2272`, `init_battle.asm:384-385`, `status_screen.asm:193-194`, `town_map.asm:499-500,642,645`, `bills_pc.asm:792-798`, `start_sub_menus.asm:670-676`, `credits.asm:140-143`, `evolution.asm:379-380`, `debug_dump.asm:848-849,2672-2673`) write the shadow to the same value adjacent. `ppu.asm:681,684` are READS (blit offset). 0 lone writes.
- Zero live `rLY`/`rSTAT` spins: every hit is a comment, `DEVIATION{class=HAL}`, or inert init store. `vcopy.asm:604-607` (vblank-gate dropped, documented), `animations.asm:787-800` (WavyScreen per-row table HAL), `core.asm:7664-7670` (rLY self-loop replaced by `SlideBattlePicsIn`), `surfing_pikachu.asm:363,393` (inert STAT store, presentation via `g_row_yoff`), `VermilionDock.asm:472,477,507` (coarse re-decode HAL). No reads of `IO_LY` anywhere in `src/`.
- `IO_BGP/IO_OBP0/IO_OBP1` writes (~100 hits) are LIVE via `commit_palette` (`DelayFrame :135`, impl `boot/video.asm`) — correct by construction, never flag.

## L. Faithfulness-review debt, measured: `faithdiff DisplayTextID` EXIT=1, 16 ADDED (pre-existing, untriaged)

```
calls: 5 pret / 21 port (5 matched)
  + ADDED CableClubNPC, DisplayPikachuEmotion, DisplayPlayerBlackedOutText,
    DisplayPokemartDialogue, DisplayPokemonCenterDialogue, DisplayPokemonFaintedText,
    DisplayRepelWoreOffText, DisplaySafariGameOverText, DisplayStartMenu,
    TextScript_BillsPC, TextScript_GameCornerPrizeMenu, TextScript_ItemStoragePC,
    TextScript_PokemonCenterPC (all jz), TrainerTalkHook (call), VendingMachineMenu (call), esi (call)
stores: + ADDED [wTextPredefFlag]
```
- The 12 `jz` targets are the known flattened-dispatch shape (pret pointer-table dispatch → direct jumps; cf. `_RunPaletteCommand` → `SetPal_*` family in the skill's untriaged-11 note). `+ ADDED esi (call)` is a faithdiff artifact (register-indirect call, no edge on either side), not a divergence. Pre-existing, not this loop's work; `fidelity_gate` fails on touch until each line is justified in `faithdiff_suppress.json` (global-boundary only) or the divergence is fixed. Filed as triage debt, not behaviour bugs.

## M. Counter-width leftovers triaged (methods: can-it-be-zero per site)

- `cry_length` (`audio/cry_synth.asm:390-397`) — POTENTIAL: `ECX = CS_LEN` (16-bit wave length widened) drives `dec ecx/jnz .step` with EAX shedding 60/iter. If `CS_LEN==0` with `CS_LENEN≠0`, first qualifying iteration wraps ECX to ~4.29e9; exit then depends on EAX wrapping below 60 (~2³²/60 ≈ 71M iterations worst case) — a seconds-long spin inside `audio_tick` (audible freeze), no memory corruption (loop body writes nothing). Reachability needs `LEN==0`+enabled domain analysis + pret comparison. Repro: zero-length wave with length enabled, watch tick latency.
- OK, no loop: `cry_envelope` (`:372-376`, `dec cl` 8-bit + zero-guard, vol domain 0-15); `pokemon.asm:187` (`movzx ecx,cl` → width-preserving store, no loop); `GetCryData` (`:705`, `(species-1)*3` index arithmetic); `vcopy.asm:490/512` (`dec bl` 8-bit, already noted); `VBlankCopy` (`:543`, guarded byte-count `rep`, no `dec`-wrap); `escp.asm:392-452` (`movzx edx,bl/bh` feed dither/pixel math; nearby loops are `jb`-bounded protocol loops, no `dec`-consumer); `home/audio.asm:290`, `array2.asm:33`, `uncompress.asm:491`, `text_script.asm:238/245` (slot scans with `jz` exits / pointer selects / `dec al` index, no widened `dec r32` loop).
- Reserved tiles `$03/$14`: only the animator itself references `FLOWER_TILE_ADDR`/`WATER_TILE_ADDR` (`vcopy.asm:99-100,673`, rotate/copy at `:618,659`); no other file parks graphics there since `be6500bc` moved the party icons out. Clean.

---

# Iteration 4 (same date, new areas — nothing above re-filed)

Skills used: same four. Stigmergy re-queried (`save SRAM box commit` → `sram-emulation-and-dsv-v2`, `savegen-pkhex-box-fixtures`). All lines re-verified this iteration; no subagents (direct greps + reads sufficed).

## N. Save-durability gap: box mutations update resident SRAM but never commit to disk — POTENTIAL (maintainer decision, not mistranslation)

- Evidence: `SramStoreImage` (disk-boundary seam, `save/dsv_io.asm:150`) has exactly three call sites in the game: `SaveGameData` (`menus/save.asm:763`, after all three slices commit), `ClearAllSRAMBanks` (`save.asm:1397`), and `TradeCenter_Trade` (`link/cable_club.asm:1171`, with a HAL DEVIATION noting that without it "a reset after a link trade loses the traded mon"). Zero hits in `bills_pc.asm`, `Daycare.asm`, `in_game_trades.asm`, or any `MoveMon`/`RemovePokemon`/`AddPartyMon` path — every Bill's PC deposit/withdraw/release, daycare deposit, and NPC-trade swap updates only the resident image.
- Why it matters: on GB hardware SRAM is battery-backed, so box mutations are durable the instant they happen — powering off without SAVE keeps the deposited mon (only WRAM progress is lost). In the port, durability == `SramStoreImage`; a crash/emulator kill between a box mutation and the next SAVE/link-trade loses it, a window GB never had. `SramStoreImage` itself "has always returned CF, and NO caller has ever read it" (`dsv_io.asm:133`) — a failed commit is also silent, compounding §H's torn-write exposure.
- Precedent for the fix shape already exists: the link-trade commit (`cable_club.asm:1171`) was added precisely because "SavePartyAndDexData only updates the resident image". The consistent options are (a) commit after every box mutation (larger disk churn, GB-faithful durability) or (b) document the window. Either needs a maintainer call + `DEVIATION{class=HAL}` if (a); filed here so the decision has a home. Repro: deposit via Bill's PC headlessly, kill without SAVE, reload, compare box.
- Related memory `savegen-pkhex-box-fixtures` (PKHeX leaving Gen-1 PC-box checksums stale) is correctly NOT filed: those 14 checksums are write-only in pret (0 read sites vs 5 for `sMainDataCheckSum`), harmless by measurement.

## O. Width and flag-contract verification (clean — do not re-audit)

- `g_pal_dirty: db 1` (`home/palettes.asm:73`), `g_tilecache_dirty: db 1` (`ppu.asm:196`): both byte flags, and no `mov dword/word` to either exists tree-wide — no reverse (wide-write-to-byte-flag) mismatch that would clobber neighbours.
- The sole narrow-write-to-dword-flag remains `bills_pc.asm:327,444,804` (`mov byte [g_bg_whiteout]` vs `dd`, already noted latent in §J4): safe in practice (values only 0/1, BSS-zero upper bytes, dword `1` → byte `0` clears fully). Style debt, not behaviour; do not copy the idiom.
- `pushfd/popfd` balance around the §J party-menu restores is exact (`in_game_trades.asm` 1/1, `Daycare.asm` 3/3, `PokemonFanClub.asm` 0/0 — FanClub branches on `jae`, no flags saved): the CF return contract survives the restore calls, so §J's leak is purely compositor state, never control flow.

## P. Counter-exposure closure: every remaining `movzx` site triaged OK

Method: for each leftover from the iteration-1 exposure list, confirmed the widened register feeds arithmetic/table-index/protocol-staging with no `dec r32/jnz` consumer (or an 8-bit/`rep` one already covered). One line each:
- `print/lpt_dos.asm:159` (`movzx edx,dl`): INT 21h register staging. `net/link_book.asm:343,345` (`family*5+slot` index): header declares the "(documented, unchecked) bounds contract", callers pass 0/1 + 0-4 — port-only tooling UI, OK by contract. `net/pktdrv.asm:544` (IVT entry arithmetic), `net_ip.asm:1029` (TCP header length, `cmp/ja` bound-checked), `link_ui.asm:1151` (money-parse loop over `$F6-$FF` bytes, exits on terminator — string-bounded, no counter). `audio/cry_synth.asm:358` (envelope threshold product), `:471` (`s+1` shift count 1-16, x86 5-bit masking exact), `:541,569` (duty-threshold table lookups). `scripts/CinnabarGym.asm:855` (`ld d,0` jump-table index), `SafariZoneGate.asm:567` (admission table index, domain ≤3). `home/list_menu.asm:417,717` (scroll/index arithmetic; `:722+` comment documents the scroll value's reuse as swap counter — pret's own `ld c,a/sla c` shape). `home/overworld.asm:2770,2801` (`movzx ecx,cl` pointer-save slots, no loop), `:4579` (`warps*4 rep movsb` — port-only header-parse step; pret performs no such copy since warps live in ROM behind a pointer, so 0 warps → no-op has no 256-behavior to diverge from).
- False positive recorded so nobody "fixes" it: the tree-wide `db 0x8+`-run grep has exactly one hit, `CopyrightRowTiles` (`movie/title.asm:187`) — tile INDICES into vChars1 with an explicit "tile indices, $FF sentinel" comment, i.e. a pointer/table-class row the two-tier rule keeps in `.asm`, not charmap text. No Tier-1 violation.

---

# Iteration 5 (same date — verification round: one erratum, coverage gaps, clean audits)

Skills used: same four. Stigmergy re-queried (`Gen 2 catch rate held item Time Capsule` → no dedicated memory; the rule lives in `gb_constants.inc` + `add_mon.asm:14`). No subagents; direct greps + reads.

## Q. Erratum to §J plus coverage: `text_msgbox` does NOT leak in overworld flows; J2/J3 have zero golden coverage

- Correction (narrows §J1–J3 as written): `text_msgbox` defaults to `msgbox_dialog` (`home/text.asm:1709-1713`, "Defaults to the overworld dialog"), and battle screens repoint it to `msgbox_centered` instead. `PartyMenuPrintText` restoring the dialog record is therefore CORRECT for overworld callers — the S5b/`65aa5a233` hazard was the inverse case (battle caller getting the overworld record). The leaked state in J1–J3 is `g_window_count` + `g_bg_whiteout` + `g_obj_over_window` only. The BUG stands; the expected-effect description is corrected.
- Coverage (manifest query, 109 scenarios): exactly one scenario named `in_game_trade`, zero matching `daycare`/`fanclub`/`fan_club`. So J2 (Daycare) and J3 (FanClub) are entirely unwitnessed — no golden renders any post-party-menu frame on those paths — while J1 has a single scenario whose dump points were not checked this loop against the leak (the scenario existing does not clear it; repro from §J still owed). If J1–J3 get fixed, J2/J3 need new scenarios; J1 needs its existing scenario's dump points reviewed for post-menu overworld frames.

## R. Clean audits (do not re-audit without new evidence)

- Gen-2 forward-compat struct rule: copies go through named lengths (`add_mon.asm` uses `PARTYMON_STRUCT_LENGTH`/`BOXMON_STRUCT_LENGTH` at `:119,402,407,507,512,524,532,540,551,656`; header `:13-14` documents offset-7 verbatim carry-through), and offset-7 handling is explicitly annotated at all six touchpoints (`add_mon.asm:14,232`, `battle/core.asm:6484,6512,8228,8258`, `item_effects.asm:2253,2436` incl. the `TWISTEDSPOON_GSC` write). No shrinking, realigning, or byte-skipping found. The rule is actively maintained, not just stated.
- `DefaultMapScript` lifetime verified-current: only 3 `src/` refs (global + annotation + label, `overworld.asm:2551,4356-4357`) and the generated `assets/map_scripts.inc` now points every real map at its own script — remaining `DefaultMapScript` rows are UNUSED/COPY fallbacks (`0x0B`, `0x45`, `0x4B`, `0x69`). "Retires per map" is nearly fulfilled with legitimate residue.
- `BUG_FIX_LEVEL` pairing: 33 `%if` blocks vs 52 `BUG{}` + 11 `GLITCH{}`; backwards scan (15 lines above each block) finds all but one annotated. The single exception (`home/list_menu.asm:244`, list-length clamp to `PC_ITEM_CAPACITY`) is the sanctioned `docs/glitch_safety.md` hardening idiom (described at `glitch_safety.md:88-89`), shared by 5 files (`init`, `list_menu`, `swap_items`, `inventory`, `oak_speech/init_player_data`) — doc-pointer instead of machine annotation, by design. Not a violation; noted so a future schema extension (if the maintainer wants these lint-visible) has its site list.


---

# Iteration 6 (same date — one adopted bug from the backlog, rest verification)

Skills used: same four. Backlog scanned for bug-like open items (`APPROVED|still OPEN|OPEN:` → item 33 below plus the already-filed 39); evolution/palette plans checked for bug-shaped tails; no subagents.

## S. Adopted: Surfboard dismount's simulated step is never consumed — OPEN port bug (backlog item 33, owner: overworld-events)

Not found by this loop's greps — adopted from `docs/current_plan_backlog.md` item 33 (filed 2026-08-02 by the Surfboard/items-plan Stage 11 work) because it meets this file's bar (symptom + repro + evidence) and was missing here:
- Symptom: after `ItemUseSurfboard`'s `.stopSurfing` branch runs, the player never takes the armed forward step — stuck on the dismount tile, not slow.
- Repro: `dos_port/tools/run_headless.sh "DEBUG_SURF=1 AUTOKEY_DUMP_FRAME=1800"` with the `AUTOKEY_SURF` script extended to close the bag + START menu after dismount (two `PAD_B` taps).
- Evidence: GBSTATE at frames 1180, 1440 AND 1800 identical — player `(15,4)`, `wSimulatedJoypadStatesIndex` = 1, `wSimulatedJoypadStatesEnd` = `$20` (PAD_LEFT), `wJoyIgnore` = `$FF`. `.stopSurfing` sets `wJoyIgnore` = `$FF` (the mount path does not, and the mount's step IS consumed on both sides), and the port has no `JoypadOverworld` to clear it. The golden `surf_round_trip` deliberately dumps with the bag still open (both sides armed-and-unconsumed), so the suite compares exactly what `ItemUseSurfboard` wrote and asserts nothing about post-menu behaviour — same false-coverage shape as §A1's DAC-vs-RAM split.
- Root gap shared with `overworld-events-stage4-boulder-linked` ("STILL OPEN: no JoypadOverworld"): two stuck-input symptoms, one missing consumer. Fixing the consumer retires both; fixing either symptom site alone leaves the other.
- Status pointer, not duplication: owner is overworld-events; the items plan's own acceptance is met. Do not re-file under items/battle.

## T. Checked-clean (do not re-audit without new evidence)

- DeSmuME-footer asymmetry is deliberate and documented on both sides: `dsv2sav.c:37-42` states `SramLoadImage` "has no such probe (a foreign file simply fails its size check and reads as 'no save')" while the converter probes first "to tell the user WHY". Verified game side: `SramLoadImage` (`save/dsv_io.asm:255+`) demands exactly `CONTENTS_TOTAL` bytes (`cmp cx, CONTENTS_TOTAL / jne .fail`) then magic/version/checksum — a 122-byte-footed foreign file fails size, leaves banks untouched, reads as fresh cartridge. Safe failure, documented explanation path. Not a bug.
- `wUpdateSpritesEnabled` at §J sites matches pret: `scripts/Daycare.asm:28`, `scripts/PokemonFanClub.asm:228,240`, `engine/events/in_game_trades.asm:94` all write it, and the port mirrors each with `ld`-commented stores (`Daycare.asm:104` =0, `in_game_trades.asm:205` =$FF via `dec`, `PokemonFanClub.asm:372/386` =$FF then =0). No protocol divergence at these call sites; §J's leak is compositor-only as stated.
- Active-plan tails are tracked work, not findings: evolution plan has one box left and it is maintainer sign-off (`current_plan_evolution_animation.md:88`); palette plan's open boxes (OBJ pal4-7 252/523, ITEM-screen HP-bar half, blackout path, `PALETTE_GATING` flip) are the known-divergence family §A1 already attributes (BG RAM matches, DAC/reporting side open). Pointers, not filings.

---

# Iteration 7 (same date — one build-breaker, one triage, ISR hygiene)

Skills used: same four. No subagents; direct reads of the reworked input layer (the skill still names `src/input/joypad.asm`, which no longer exists — the ISR now lives in `src/input/kbd_isr.asm` alongside `input_hal/cfg.asm` + `gamepad_hal.asm`; skill doc-rot noted, not filed).

## U. `kbd_ring_push` does not assemble — registered scenario `kbd_naming_entry` cannot build — BUG (port-introduced, proven at assemble time)

- Proof: `nasm -f coff -I dos_port/include -I dos_port -D BUG_FIX_LEVEL=0 -D AUTOKEY_KBDSCRIPT -o /tmp/kbd_test.o dos_port/src/input/kbd_isr.asm` fails:
  `kbd_isr.asm:379: error: symbol 'kbd_ring_pad' not defined` (+ a knock-on `label-redef-late` at `:388`, plausibly cascade).
- The defect (`kbd_isr.asm:370-392`, `%ifdef AUTOKEY_KBDSCRIPT`): the scancode-injection producer writes the key byte into the ring (`:376 mov [kbd_ring + ecx], al`) but the shift byte into a scalar that exists nowhere (`:379 mov [kbd_ring_pad], ah` — zero declarations tree-wide: no `resb`, no `global`, no `extern`), while still advancing head by 2 (`:377-381`, mirroring the ISR's 2-byte entries). So even past the missing symbol, every injected key's shift slot would read stale ring garbage in `kbd_ring_pop` (`:355-357` reads both bytes from the ring).
- The ISR itself (`:203-219`) shows the correct shape: scancode at `[kbd_ring + head]`, shift at `[kbd_ring + head+1]`, overflow drops oldest pair. Fix is one line — `:379` should be `mov [kbd_ring + ecx], ah` — but this loop only documents.
- Blast radius: `-D AUTOKEY_KBDSCRIPT` is set by two live Makefile gates (`DEBUG_LINKBOOKCHECK` at `Makefile:3137`, `DEBUG_KBDNAMECHECK` at `:3164`), and scenario `kbd_naming_entry` (manifest id 95, tier full, `build_flags: KBD_NAMING=1 DEBUG_KBDNAMECHECK=1`, must_hit `DisplayNamingScreen` + `kbd_ring_pop`) requires one of them. A registered golden cannot compile — `fidelity-full`/`goldencheck` on it fails at assembly, not at comparison. Normal builds are unaffected (the `%ifdef` block is skipped), which is why nothing caught it.
- Adjacent rot: the `Makefile:3118` comment still points at `(src/input/joypad.asm)` for `kbd_ring_push`; the file was renamed to `kbd_isr.asm`. Doc pointer only.

## V. Second faithdiff instance triaged + ISR verification notes

- `_RunPaletteCommand` (`faithdiff` EXIT=1): `calls: 2 pret / 1 port`, single line `- DROPPED GetPredefRegisters (call)`. Verdict: JUSTIFIED divergence, gate-debt only. Pret line 2 (`engine/gfx/palettes.asm:2: call GetPredefRegisters`) restores HL/DE/BC from slots its `predef` dispatcher populated; the port dispatches `SetPal_*` through a direct `dd` table on AL (`palettes.asm:89-107`, with the documented `SET_PAL_DEFAULT` resolution and the `SetPal_GameFreakIntro` publish fix) and populates nothing — calling `GetPredefRegisters` would clobber, exactly the §E-correct-pattern class (`TrainerFlagAction`, `InGameTrade_FlagActionPredef`). Needs a suppress-entry with this why-string (or equivalent annotation) when touched; `fidelity_gate` fails until then. Second measured instance of the skill's untriaged set after §L's `DisplayTextID`.
- `ext_pending` (`kbd_isr.asm:78,170,173`) is write-only: set on `0xE0` prefix, cleared on every following scancode, read by nothing. Harmless (extended arrows still resolve via the `SC_*` compares after the prefix is consumed) — delete or use, do not extend.
- Exit-path restore verified: `boot/entry.asm:926-927` calls `input_restore` (`input_hal.asm:50-51` → `kbd_restore`, DPMI 0205h vector restore) then `pit_restore` on the single shutdown sequence. EOI discipline in-ISR correct (`out 0x20, al` per IRQ including prefix bytes; IRQ1 lives on the master PIC so no slave EOI owed; DS/ES reloaded via `cs:kisr_ds` per the documented pattern; `pushad`-balanced save/restore with `iret`). No missing-restore or EOI bug filed; AT-controller `0x61`-toggle and `0x64`-status hardening are absent but unneeded under the DOSBox-X target — noted as a real-hardware caveat, not a finding.

---

# Iteration 8 (same date — callee-contract verification round)

Skills used: same four, with emphasis on `asm-translation`'s register-map and callee-preservation expectations. No subagents.

## W. Register contracts of the three most-called routines: verified, no new loop-counter class (do not re-audit)

This closes the remaining popular callees behind the CLOSED `bug-class-loop-counter-in-cl-across-a-clobbering-call` memory (which proved 0 remaining defects across its 37-site shape-1 sweep but named only three callees explicitly):
- `Random` (`home/random.asm:12`): `push esi/dx/bx` around `Random_`; `Random_` itself (`engine/math/random.asm`, full body read) touches only `al/bl` plus a `pushf/popf` pair that exists solely to carry the caller's incoming carry into the faithful `adc` (the `add byte [IO_DIV],0x25` churn would otherwise destroy it — documented in the header, including the removed double-add). ECX/EDX/EDI untouched on both levels: a caller holding a loop counter in ECX across `call Random` is safe.
- `DelayFrame` (`home/vblank.asm:126-127`): `pushad` on entry ("Out: all registers preserved"). The `WaitForSoundToFinish → DelayFrame` path can never be the leak the Itemfinder instance taught us to look for.
- `PlaySound` (`home/audio.asm:233-235`): `push esi/edx/ebx`, mirroring pret's `push hl/de/bc` exactly (the fact the Itemfinder fix relied on). Its offline-swallow guard (`:227-231`, structured `DEVIATION{class=HAL}`) forces `wNewSoundID=0` with no audio device so `WaitForSoundToFinish` cannot spin — documented permanent HAL boundary, not a finding.
- Consequence: the only known register-clobber loop bugs remain the two fixed instances; no third callee in this set can produce one. Future loop audits need only check *new* callees against this list.

## X. Refinement to §U: the shift byte IS consumed, so injected keys can mistype case

- `kbd_text.asm:154-168` reads `AH` from `kbd_ring_pop` (`test ah,ah / jz .use_unshifted`) to select the shifted symbol map. The ISR stores the shift byte correctly (`kbd_isr.asm:208-211`); only the autokey producer (§U, `:379`) misroutes it to the undeclared scalar, leaving stale bytes in the ring slot `pop` actually reads. So §U's blast radius is specifically wrong-case/wrong-symbol injection in scripted naming runs (plus the assemble-time failure that currently masks it entirely). No change to §U's verdict; this pins the symptom to expect once it builds.

---

# Iteration 9 (same date — two parity verifications, no new bugs)

Skills used: same four. No subagents; pret-vs-port line pairs plus shim reads.

## Y. Trade-evolution `wForceEvolution` lifecycle: pret parity, not a bug (do not file)

- The suspicious shape: both trade paths set `wForceEvolution=1` immediately before `TryEvolvingMon` and never clear it after (`in_game_trades.asm:422-428`, `cable_club.asm:1125+`), while `end_of_battle.asm:136` and `item_effects.asm:1497` clear it on other paths. A stale `=1` would block B-cancel (`evolution.asm:340`) and gate the level-evo check (`evos_moves.asm:209-211`) on later, unrelated evolutions.
- Verdict after reading pret: line-for-line identical (`engine/events/in_game_trades.asm:249-259`: `ld a,$1 / ld [wForceEvolution],a`, same placement, same absent clear). The lifecycle — set before forced evos, cleared by battle-end/item paths — is GB behavior reproduced exactly. The only port-side addition is documentation: `cable_club.asm:1120` notes "the 44-byte struct verbatim (offset 7 incl.)", further Gen-2-rule evidence for §R. If the lifecycle is wrong, it is wrong in the ROM too.

## Z. NRx4 restart-bit protocol: skill claim corroborated at the shim (do not re-audit)

- `opl_shim.asm:335-339`: `test al,0x80 / jz .noRestart / and al,0x7F` + writeback + `voice_keyon` — the shim consumes and clears bit 7 exactly as `asm-translation` states. Engine side is write-only (`engine_2.asm:161-163` counter-mode init; `cry_synth.asm:925-928` clears); no engine read-back of the bit exists. The "engine never reads it back" half holds tree-wide by grep.
- `wJoyIgnore` writer survey (context for §S): writers abound (`overworld.asm:350,1386,4216`, `trainers.asm:385,404,416,514`, `pathfinding.asm:100`, per-map scripts), nearly all clearing or script-set values — the stuck state in §S comes from the missing *consumer* (`JoypadOverworld`), not from a rogue writer. No writer-side finding; §S stands as written.

---

# Iteration 10 (same date — census closure + consumer verification)

Skills used: same four. No subagents.

## AA. §E census closed: tree-wide re-sweep finds exactly the known sites; `AskName` exonerated

- Re-sweep `call/jmp FlagActionPredef` (code, not comments) returns exactly `CinnabarGym.asm:186` + `Route23.asm:160,322,344` — the §E1/§E2 sites, no new ones. (The `experience.asm:15` hit is the header documenting the already-fixed instances.)
- The one lookalike investigated: `AskName` calls `GetPredefRegisters` itself (`naming_screen.asm:217`) — but so does pret (`engine/menus/naming_screen.asm:3`), and pret's callers arrive via `predef` (`add_mon.asm:52`, `item_effects.asm:3024`). Both port callers populate the slots first (`add_mon.asm:104-106` big-endian split, `item_effects.asm:2338-2339`) — the sanctioned populate-it-yourself pattern (`predef.asm:11` anticipates exactly this; `evos_moves.asm` `SetPartyMonTypes` does the same at `:430-436`). Correct, no bug.
- Complete census, no further hunting needed: WRONG pattern — Route23 ×3, CinnabarGym ×4 (via trampoline). RIGHT pattern — `TrainerFlagAction`, `InGameTrade_FlagActionPredef`, `AskName` + its 2 slot-populating callers, `experience.asm` ×3 (fixed), `evos_moves.asm`, `pokedex.asm`, `battle/core.asm` ×4. §E is now fix + repro only.

## AB. KBD_NAMING consumer verified: no empty-ring hang (producer-only blast radius for §U)

- `naming_screen.asm:461-509`: `call kbd_ring_pop / jz .kbdSkip` (empty ring falls through to joypad handling), one entry per frame paced by `AnimatePartyMon_ForceSpeed1`'s internal `DelayFrame`, unmapped scancodes ignored (`test al,al / jz .kbdSkip`), Backspace/Tab clear their joypad double-fire bits. The loop always progresses; an empty ring only means "nothing typed this frame". Combined with §X (shift byte consumed): §U's blast radius is strictly the broken producer — wrong-case injection once it assembles, never a consumer hang.

---

# Iteration 11 (same date — shared-state balance verification, no new bugs)

Skills used: same four. No subagents.

## AC. `text_row_stride` balance: clean (do not re-audit)

- Writers: `window.asm:151,285` (callers' values), `pokemon.asm:343` (=20), `text_script.asm:433` (=20, "restore overworld dialog stride"), `list_menu.asm:271` (=`LIST_STRIDE`), `link_ui.asm` ×8 (=`LU_STRIDE`), `town_map.asm:478-484,649` (save/set-40/restore), `debug_dump.asm:2069,9346` (set-40/restore-20), `text_engine_init` (`text.asm:1221` =20 + msgbox reset, called from title/overworld init).
- The load-bearing measurement: `LIST_STRIDE` (`list_menu.asm:135`) and `LU_STRIDE` (`link_ui.asm:207`) are both **20** — every list/link write is a value-identical no-op, so those paths cannot leak a wrong stride by construction. The only non-20 writers (`town_map`, `debug_dump`) both pair with restores (town_map via save/restore, debug via explicit 20). No unbalanced writer exists.
- Related global the same audit covered incidentally: `text_msgbox` reset lives beside the stride reset in `text_engine_init`, corroborating §Q's default-record claim from the code rather than the comment.

## AD. `hJoy7` joypad-mode flag: pret-mirrored, no port state to leak (do not re-audit)

- Every `hJoy7` writer carries a pret `ldh [hJoy7],a` comment (`list_menu.asm:224,463,506`, `pokedex.asm:249,272,327,361`, `town_map.asm:144,219,315,397`, …) — values track the ROM by construction, including the 0/1 arms. The naming-screen `hJoy5`-vs-`hJoyPressed` DEVIATION therefore rests on pret-identical inputs; its "mode 1 default" assumption is about pret's own flag lifecycle, not port-owned state. Nothing here can diverge without pret diverging first.

---

# Iteration 12 (same date — shim-protocol uniformity + menu-state balance)

Skills used: same four. No subagents.

## AE. Restart-bit consume is uniform across all shims (extends §Z, do not re-audit)

- `test al,0x80 / jz .noRestart / and al,0x7F` + writeback + `*_keyon` in `opl_shim.asm:335-339`, `tandy_shim.asm:188-192`, `spk_shim.asm:116-120`, `cms_shim.asm:422-425`, `covox_shim.asm:305-307`, `innova_shim.asm:319-322,351-354,385-386`. (`mpu401.asm:66`'s `0x80` is a UART status bit, unrelated.) Since all shims share the same NRx4 bytes, the first ticker to run clears the bit for the rest that tick — no double-keyon ordering hazard, and no shim can retrigger on a stale bit even running solo. §Z's protocol claim now covers every audio device, including the in-progress ones (Covox/GameBlaster/GUS/SID plans).

## AF. Menu shared-state balance: clean (do not re-audit)

- `menu_item_step`: set-on-entry everywhere it is consumed (`pokemon.asm:344` =40, `list_menu.asm:272` =`LIST_ROW_STEP`*20, `link_ui.asm` ×4 =20, `debug_dump.asm:9319,9328` =80), consumer `window.asm:346`. Exemplary instance: `learn_move.asm:296-300` derives double-spacing from live `text_row_stride` and restores single-spacing after, with a comment recording the ECX-not-EAX pret `res`-bit detail. No caller reaches `HandleMenuInput` on a stale step.
- `BIT_NO_TEXT_DELAY`: paired set/clear at every site (`pokemon.asm:318/391`, `list_menu.asm:236/464,507`, `PokemonFanClub.asm:388/392`, `GameCorner.asm:692/727`, `BikeShop.asm:130/150`, `SummerBeachHouse.asm:258/265,308/312`, …). No orphan set.

---

# Iteration 13 (same date — §S mechanism correction + path-rot notes)

Skills used: same four. No subagents.

## AG. Correction to §S: both halves of its root-cause theory are stale — re-measure, do not implement the prescribed fix

- Backlog-33 blames "no `JoypadOverworld`". Measured this iteration: `JoypadOverworld` exists (`overworld.asm:4152`), the live loop calls it (`:1779`, with comments recording the 2026-08-22 restoration of pret order), and it drives `AreInputsSimulated` (`:4189`) → `GetSimulatedInput` (`:4199`) → `.doneSimulating` (`:4214-4222`, which clears `wJoyIgnore`, the index/end, `hJoyHeld`, and the scripted-movement bit). The consumer the item says is missing has existed for ~6 weeks.
- The armed side holds too: `.stopSurfing` sets `BIT_SCRIPTED_MOVEMENT_STATE` (`item_effects.asm:689`) and arms the buffer via `.makePlayerMoveForward` (`:686,697+`), with `wJoyIgnore=$FF` exactly as the item reports (`:691`, pret `xor a / dec a` shape). Flag armed + consumer present ⇒ the stuck state, if it reproduces, comes from somewhere else (menu-flow gating around the loop, the override-mask cancel at `:4194-4197`, or the item is already fixed and the backlog line is stale-OPEN).
- Standing: §S stays OPEN (the symptom was measured, the repro is concrete), but its mechanism paragraph is superseded by this one — whoever works it must re-run the `DEBUG_SURF` repro first rather than building the missing consumer. Same caveat extends to the linked boulder item citing the same gap.
- Producer census for that re-measurement: `wSimulatedJoypadStates*` producers span 12 files (`home/overworld.asm`, `map_objects.asm` (`DecodeArrowMovementRLE` → `DecodeRLEList`), `pathfinding.asm`, + 9 scripts from `LoreleisRoom` to `PokemonTower6F`) — all funnel through the single `AreInputsSimulated` consumer above, so one functioning drain covers every producer.

## AH. Stale path rot, comment-only (do not fix content, fix pointers)

- `Makefile:3120` and `tools/linkbookcheck.sh:12` cite `kbd_ring_push (src/input/joypad.asm)` — the file is `src/input/kbd_isr.asm` after the input-layer rework (same rename §U already noted for `Makefile:3118`). `Makefile:3641` is the exception that proves the rule: it narrates its own move history (`joypad.asm` → `engine/joypad.asm` chunk 18) and is still accurate. Three pointers, zero behavior; fix on next touch of those lines.

---

# Iteration 14 (same date — simulated-input machinery parity, no new bugs)

Skills used: same four. No subagents. This further narrows §S/§AG: the machinery below the symptom is faithful, so a re-measurement that still reproduces must look at flow (menu gating, override cancel), not at these routines.

## AI. `AreInputsSimulated` + override mask + `.doneSimulating`: pret-identical (do not re-audit)

- Shape: port `overworld.asm:4189-4208` matches pret `home/overworld.asm:1603-1620` instruction for instruction — scripted-bit test, `hJoyHeld`/override-mask AND with early-ret on real-press cancel, `GetSimulatedInput` drain check, `hJoyHeld` inject, zero-input edge clearing `hJoyPressed/hJoyReleased`.
- Override mask: read at port `:4195`, set per-script (`PokemonTower6F.asm:185`, `Route6Gate.asm:141`, `Route8Gate.asm:78`, `Route7Gate.asm:79`, `VermilionDock.asm:104`, `pokedex.asm:274`) or zeroed (`map_objects.asm:173`, `pathfinding.asm:98`, `auto_movement.asm:211`) — same producer-owned pattern as pret's `wOverrideSimulatedJoypadStatesMask` writes. No stale-mask leak class beyond what pret has.
- `.doneSimulating` teardown: port `:4214-4222` matches pret `:1624-1633` (four zero stores + `hJoyHeld=0` + movement-flags `0xF8` preserve mask), plus the scripted-bit clear both sides carry. The `wJoyIgnore=0` clearing the §S symptom needs happens here, on drain — reached whenever the buffer actually drains through this path.

---

# Iteration 15 (same date — §S arming semantics pin the prime suspect on the harness)

Skills used: same four, plus `build-and-debug`'s headless-repro discipline. No subagents.

## AK. The dismount arming is exactly one step by construction — stuck-at-index-1 means the consumer never ran once

- `.makePlayerMoveForward` (`item_effects.asm:697-712`): direction → `BH`, stored at `wSimulatedJoypadStatesEnd[0]`, index armed to **1**. Against `GetSimulatedInput` (`overworld.asm:4225-4236`: `dec index`, `0xFF` → drained): first call reads 1→0 and injects the step (CF=1); second call reads 0→`0xFF` and tears everything down (`.doneSimulating`, incl. `wJoyIgnore=0`). One armed step = one injected step + one teardown. The arming is correct, and `StartSimulatingJoypadStates` (the shared armer, `map_objects.asm:172`, pret `home/map_objects.asm`) follows the same index convention.
- The backlog's stuck evidence is index **1** at frames 1180, 1440, 1800 — i.e. zero consumptions in 620 frames. With flag armed (§AG), consumer live (§AG), machinery identical (§AI), arming correct (here), and no clearer on the path (§AI), the remaining explanation that fits ALL the evidence is that the game never returned to `OverworldLoop`'s idle branch at all: the repro's two `PAD_B` taps ("extended to close the bag and the START menu") never got it out of the menus. A game sitting in a menu shows exactly this signature — armed, flagged, ignored, unchanging — with no game-side defect required.
- Prescription (not taken this loop — headless runs are the maintainer's/owner's call): re-run the `DEBUG_SURF` repro logging menu openness (`wBagMenuExitMethod`/`wCurrentMenuItem`-adjacent state, or simply whether `OverworldLoop` iterations advance) at the dump frames; add taps until the loop is observably iterating before judging the step. If the loop IS iterating with the flag set and index frozen, that — and only that — reopens a game-side hunt, starting at `AreInputsSimulated`'s override-cancel and the idle-branch gating (`overworld.asm:1773-1800`, verified present this loop).
- `StartSimulatingJoypadStates` pointer check, folded in: the `:1876` comment reference resolves (`map_objects.asm:53,172`, pret `home/map_objects.asm`), no rot.

---

# Iteration 16 (same date — §S diagnostic refinement: the one datum the evidence lacks)

Skills used: same four, plus `build-and-debug`'s dump-window mechanics. No subagents.

## AM. `wWalkCounter` writer survey: the stuck state has a third reading, and the dumps cannot distinguish it

- Writers: step-arms of 8 (`overworld.asm:883,914,967,986` seam steps, `:2101` new step), zeroes (`:1021`, `:2221` loadNewMap — the sanctioned extra-zero projection deviation, `:4981` ResetMapVariables region, `init.asm:581`), decrement in `AdvancePlayerSprite` (`advance_player_sprite.asm:60`). Readers gate the idle branch (`movement.asm:191,885,892` compare-0), sprite updates (`movement.asm:125,792,1069`, `sprite_oam.asm:370`, `ppu.asm:604,646`, `pikachu_follow.asm:724`).
- The loop only reaches `JoypadOverworld` (hence `AreInputsSimulated`) on the idle branch (`wWalkCounter == 0`, else `.moveAhead`). So stuck-at-index-1 has THREE readings, not two: (a) never returned to the loop [§AK harness hypothesis]; (b) loop iterating but never idling — counter held nonzero while `.moveAhead` runs every frame without draining it; (c) consumer running but buffer misarmed (ruled out: arming audited correct in §AK).
- The backlog evidence (player `(15,4)`, index 1, end `$20`, `wJoyIgnore=$FF` at frames 1180/1440/1800) contains no `wWalkCounter` value — yet it decides between (a) and (b) outright: counter 0 ⇒ (a); counter frozen nonzero ⇒ (b), a walk-machinery stall, different root, different owner. `wStatusFlags5` (scripted bit still set?) belongs in the same dump line.
- Prescription, refined from §AK: extend the `DEBUG_SURF` dump windows (`debug_dump.asm` `windows:` table) with `wWalkCounter` + `wStatusFlags5` before re-running — one run then classifies the stuck state instead of merely re-observing it. No code change proposed; this is measurement design for whoever re-opens the item.

---

# Iteration 17 (same date — `_HandleMidJump` audit: faithful, terminates, one near-miss documented)

Skills used: `asm-translation` (register/flag/width reading) + `faithfulness-review` (pret pair). No subagents.

## AN. Ledge-hop arc: logic faithful, teardown matches pret line-for-line, no stall

- Arc: port `player_animations.asm:722-732` vs pret `:498-510` — `inc`/`cmp $10`/`nc` + store + table write, identical. The index is monotonic and any start value terminates (even a corrupted `0xFF` wraps to 0 and proceeds normally — self-healing, no stall input exists). `.finishedJump` waits for `wWalkCounter==0` then tears down exactly pret's list (`:733-745` vs pret `:511-528`: `UpdateSprites`, `Delay3`, zero `hJoy{Held,Pressed,Released}`, index 0, `res LEDGE_OR_FISHING`, `res SCRIPTED_MOVEMENT_STATE`, `wJoyIgnore=0`).
- Near-miss recorded so nobody "fixes" it: `w_player_jumping_y_index` is read/written WITHOUT `[ebp + …]` (`:723,728,741`) — correct, because it is a port-local `section .bss` byte (`:758-760`), not GB memory. Adding `ebp` would break it. (Contrast: every `w*` GB symbol in the same routine keeps its base.)
- Known visual gap, pointer not finding: the header (`:714-718`) documents that the hop's vertical arc is not drawn — the player renderer pins screen-centre and never reads `YPixels` for the player — while logic/teardown stay faithful. If a ledge-hop golden is green, it is not observing the arc; do not cite it as arc coverage.

---

# Iteration 18 (same date — `_Joypad` reader parity, no new bugs)

Skills used: `asm-translation` (flag/edge semantics) + `faithfulness-review` (pret pair). No subagents.

## AO. Joypad edge detection + ignore masking: line-for-line pret parity (do not re-audit)

- Port `engine/joypad.asm:55-101` vs pret `engine/joypad.asm:34+`: soft-reset gate (`and PAD_BUTTONS|PAD_UP`, `== PAD_BUTTONS` — including the quirk that a held Up blocks reset on both sides), edge equations (`released=(last^input)&last`, `pressed=(last^input)&input`), `BIT_DISABLE_JOYPAD` → zero-all `DiscardButtonPresses`, `wJoyIgnore` masking held+pressed but NOT released, `TrySoftReset` (`DelayFrame`, `$30`, `dec hSoftReset`, tail `Joypad`) — all identical.
- The unmasked-`hJoyReleased` shape is therefore pret's own, not a port omission; its 9 reader files (`overworld`, `trainers`, `joypad2`, `GameCorner`, `main_menu`, `joypad`, `clear_variables`, `player_animations`, `printer`) receive ROM-identical values. The home-bank wrappers (`home/joypad.asm:37-44`, plain `jmp` under the flat banking model) are link-live with multiple callers — the file header's own stale "no caller" note it already retracts is not re-filed here.

---

# Iteration 19 (same date — `.stopSurfing` parity closes the §S static pipeline)

Skills used: `faithfulness-review` (pret pair) + `asm-translation` (flag/bit reading). No subagents.

## AP. Dismount routine fully faithful — every statically auditable link of §S now checks out

- Port `item_effects.asm:685-694` vs pret `engine/items/item_effects.asm:741-755`: `.makePlayerMoveForward`, `wPikachuSpawnState=3`, `wPikachuOverworldStateFlags` bit 5, `BIT_SCRIPTED_MOVEMENT_STATE`, `wWalkBikeSurfState=0`, `wJoyIgnore=$FF` (both via `dec a` from 0), `PlayDefaultMusic`, `GBPalWhiteOutWithDelay3`, tail `LoadWalkingPlayerSpriteGraphics` — all identical, in order.
- Pipeline status for §S after this loop's coverage: arming (§AK) ✓, flag (§AG) ✓, routine incl. Pikachu writes (here) ✓, consumer + teardown (§AG/§AI) ✓, walk-counter design (§AM) ✓. Every link auditable without running the game is faithful. What remains is runtime-only: the instrumented `DEBUG_SURF` re-measurement (§AM prescription stands unamended). No further static work on this item can add information — future loops should run the repro or leave it to the owner.

---

# Iteration 20 (same date — deferred item/bag classification closed + fix record)

Skills used: same four. No subagents.

## AQ. Bag/item-use paths absorb the leak: no bug (deferred question from the §J fix, answered)

- The `.useItem_partyMenu` return in `start_sub_menus.asm:1327-1344` already performs the full teardown (`:1337-1339`: `g_window_count`/`g_bg_whiteout`/`g_obj_over_window` zeroed, dword idiom) behind a structured `DEVIATION{class=projection}` (`:1336`) naming exactly the party-window leak, then reloads tileset + palette and redraws the bag (`jmp StartMenu_Item`). The `.useItem_closeMenu` path (`:1322-1324`) clears the same three flags before `CloseStartMenu`.
- Consequence: the four `item_effects.asm` `DisplayPartyMenu` sites (USE_ITEM, PP-restore, TMHM, evo-stone cancels) return into the bag, whose resume path tears down. Only direct-to-overworld callers leaked — the three filed §J sites plus NameRater (same shape, found in the fix sweep). No further caller in the `call DisplayPartyMenu` census (11 sites: 3 battle + START (:262, own teardown at `:283-285`) + 4 fixed + 4 bag-absorbed) leaks. Do not re-audit without a new caller.

## AR. Fix record: audit U/E/B/J fixes landed and tested (not re-filings)

- `71366ae53` §U (`kbd_ring_push` shift byte to undeclared scalar → `[kbd_ring + ecx]`): `KBD_NAMING=1 DEBUG_KBDNAMECHECK=1` full build + link now passes (was unassemblable); plain build clean.
- `8ce61ecb0` §E (Route23 ×3 + CinnabarGym ×4 `FlagActionPredef` → `FlagAction` leaf): fixing the call target alone was insufficient — the sites also passed the bit in BL and read the result from BL while the leaf consumes/returns CL (tree convention per `TrainerFlagAction`/`IsPokemonBitSet`/`add_mon`/`core`). Each site now copies the bit to CL; TEST sites read back CL. Pret discards the result at `CinnabarGymScript_75032` too, so that site stays readback-free. Census re-swept: zero `call/jmp FlagActionPredef` remain in sources.
- `cca010d0d` §B1–B3 (B1/B2 `dec ecx` → `dec cl`; B3 zero-run `test cl/jz` skip, the format-correct semantics for the port-only run list).
- `9a5af14d9` §J1–J3 + NameRater (three-flag dword teardown at each overworld restore; `text_msgbox` deliberately untouched per §Q; item/bag paths untouched per §AQ).
- Gates at land: nasm 0 on every touched file (both `AUTOKEY` and plain configs), `lint_pret_labels --no-scan` and `--strict-claims` 0 violations, core `fidelity` 17/17 PASS, `in_game_trade` golden PASS (after save-backup + `clean-image` for a pre-existing image-size boundary; save restored).

---

# Iteration 21 (same date — §J4 promoted to OPEN: town-map window leak on the bag route)

Skills used: same four. No subagents.

## AS. `ItemUseTownMap` enters the flat-canvas modal with the bag window up — OPEN port bug (code-inspection, runtime repro owed)

- Chain, all verified this iteration: the bag list box IS a window (`add_window` at `list_menu.asm:985/1015`, count never reset by the list driver — only the `:1138` shift-remove helper decs). `ItemUseTownMap` (`item_effects.asm:3479-3482`) does `jmp DisplayTownMap` with no hide/teardown; `LoadTownMap` (`town_map.asm:464+`) saves and zeroes `g_bg_whiteout` (`tm_saved_whiteout`, entry `:501`, restore `:646-647`) but never touches `g_window_count` — the only mention is the `:516` comment asserting `g_window_count==0` without establishing it. So on the bag USE route the stale bag-list window stays composited over the map modal.
- Second half of the same defect: on exit the bag redraws via `StartMenu_Item`/`ItemMenuLoop`, whose driver `add_window`s again onto the never-zeroed count — descriptor accumulation across visits (bounded only by the `MAX_WINDOWS` clamp at `ppu.asm:1651`). One missing teardown, two symptoms.
- Fix direction (not taken this loop): save/zero/restore `g_window_count` in `LoadTownMap` exit exactly like the existing `tm_saved_whiteout` pattern — the file already owns that idiom, so no new convention is needed. Pret has no counterpart (full-screen takeover needs no window accounting on the GB): `DEVIATION{class=projection}`.
- Repro owed: USE the town map from the bag headlessly, dump `FRAME.BIN` on the map screen (bag window over map) and `g_window_count` before/after (count growth per visit).

---

# Iteration 22 (same date — re-entry idempotence + START coverage, no new bugs)

Skills used: same four. No subagents.

## AT. `GoBackToPartyMenu` re-entry cannot accumulate windows (do not re-audit)

- `ShowPartyMenuWindows` has exactly one caller (`party_menu.asm:393`, the `RedrawPartyMenu_` tail): `set_single_window` (count=1) + `add_window` (count=2) rebuild the descriptor pair from scratch every redraw — including the documented drop of any stale field-move pop-up third window. `GoBackToPartyMenu` (`pokemon.asm:281-287`) raises nothing itself; it re-runs init + redraw, so SWITCH/submenu/battle no-cancel re-entries (`start_sub_menus.asm:268,634`, `core.asm:3602`, `item_effects.asm:1048` Softboiled) reset the count to 2 rather than growing it. Re-entry is idempotent by construction.

## AU. START-Pokemon exits fully covered (do not re-audit)

- Cancel falls through `StartMenu_Pokemon` → `.exitMenu` (`start_sub_menus.asm:262-288`), which carries the full three-flag teardown before `RedisplayStartMenu`. Chosen-mon flow continues into the pop-up/dispatch, whose menu-leaving tails (`:589-591` and the `:243-245` pokedex path) carry the same teardown. No START exit bypasses it.

## AV. Post-commit verification of the §J fix (commits as measured, no drift)

- Teardown-site census after landing: `in_game_trades.asm` 1 (shared `InGameTrade_RestoreScreen`, covers cancel + success), `Daycare.asm` 1 (shared pre-split restore block), `PokemonFanClub.asm` 2 (cancel + chosen), `NameRatersHouse.asm` 1 (shared block) — 5 sites, all three flags, dword idiom, `mov`-preserves-flags safe inside the `pushfd/popfd` windows. Fidelity 17/17 + `in_game_trade` golden (Iteration 20) already cover the behavior.

---

# Iteration 23 (same date — §M `cry_length` closed: zero-length unreachable by construction)

Skills used: `asm-translation` (counter-width domain analysis) + `faithfulness-review`. No subagents.

## AW. `cry_length` zero-input unreachable — POTENTIAL retired, no fix (do not re-audit)

- The loop (`cry_synth.asm:387-405`) wraps ECX only if entered with `CS_LEN==0` while `CS_LENEN≠0`. That state is unreachable through every writer:
  - `cry_keyon` (`:258-273`) is the sole armer, and its domain excludes 0 on all channels: ch 0/1/3 compute `64-(NRx1 & 0x3F)` = 1..64; ch 2 (wave) computes `256-NRx1` = 1..256. `CS_LENEN` = `NRx4 & 0x40`.
  - Expiry co-clears: when the countdown reaches 0 it writes `CS_LEN=0` AND `CS_LENEN=0` together (`:398-399`), and the LENEN early-out (`:387`) guards the only LEN=0 state.
  - The `.save` store (`:403`) only runs via `jb` with ECX≥1 (a `dec`-to-0 falls through to the co-clear, never to `.save`).
- Verdict: the 32-bit counter is exposure without a reachable zero — same shape as the triaged-OK sites in §P, now with the domain proof §M asked for. No `dec cl` change (LEN is genuinely 16-bit: 256 is a live value on ch 2, and an 8-bit counter could not hold it). No runtime repro can arm it short of corrupting the voice struct directly.

---

# Iteration 24 (same date — §A5/S4 switch-palette pipeline narrowing: no missing step found, stays OPEN)

Skills used: same four. No subagents.

## AX. Battle-switch palette sequence matches initial send-out — S4 needs its witness, not more static reading

- Switch path (`core.asm:3701-3741`): `GBPalWhiteOut` → `ClearSprites` → `LoadHudTilePatterns` → `RestoreBattleScreenState` → `LoadScreenTilesFromBuffer1` → `RunDefaultPaletteCommand` → `GBPalNormal` → fall through `SwitchPlayerMon` (`:3743+`) → `SendOutMon` (`:5537+`) → `RunPaletteCommand` with `BH=SET_PAL_BATTLE` (the M-72 fix: BH was previously unsettled dispatch junk).
- `SendOutMon` is the SAME routine the working initial send-out uses, and its palette publish (`SET_PAL_BATTLE` → `SetPal_Battle`, which arms `g_pal_dirty` at `palettes.asm:279-280` after the `RefreshMonFrontRepaintPalette` write at `pics.asm:421-469`) runs on both paths. No missing arming step, no skipped publish, no divergent ordering found between switch and initial send-out.
- Consequence: the S4 wrong-palette state, if it reproduces, is not a missing palette call on the switch path — candidates move downstream (stale `tile_pal[]`/slot contents the publish derives from, or the party-menu front-repaint interaction), all of which need the maintainer's exact moment or a headless switch witness to distinguish. S4 stays OPEN (single tail of §A5); this iteration closes the "missing call on the path" hypothesis the same way §F closed the writer-arming hypothesis for §A1. Do not re-walk this pipeline without a dump.

---

# Iteration 25 (same date — §A3 nick-fill narrowing: all fills faithful, stays OPEN)

Skills used: same four. No subagents.

## AY. Enemy-nick dataflows match pret on every path — A3 needs its dump, not more reading

- Wild: `GetMonName(species2)` → `CopyData` NAME_LENGTH → `wEnemyMonNick` (`core.asm:4046-4053`, pret `core.asm:6308` block) — faithful.
- Trainer: indexed copy `wEnemyMonNicks[wWhichPokemon]` → `wEnemyMonNick` (`core.asm:8287-8293`, pret `:1733`) — faithful; trade-catch fill of `wEnemyMonNicks` (`add_mon.asm:428`, pret `:326`) — faithful. `GetMonName` itself (`names.asm:66`) is a fixed-stride copy with `@` terminator — faithful, and no `"PKMN@"` literal exists anywhere in data (so the glyphs were not a produced string).
- Wrong-index theory checked and weakened: the neighbor past `wEnemyMonNicks` (`ram/wram.asm:2449`: `wTrainerHeaderPtr` + 6 pad bytes) is binary/pointer data — a stale `wWhichPokemon ≥ 6` would print garbage, not clean `PKMN` glyphs. Do not pursue it without a dump.
- Sharpened prescription (not taken this loop): the owed dump must capture battle type (wild vs trainer) + `wWhichPokemon` + the full nick bytes at the stat-fall moment — the audit's standing `wBattleMonNick`/`wEnemyMonNick` dump, plus the two discriminators this iteration showed decide between the remaining theories.

---

# Iteration 26 (same date — §A1 reframed: identical DAC explained by pret's own `.lastMap` logic)

Skills used: same four. No subagents.

## AZ. The three identical `PAL.BIN`s are what pret computes when no outside walk sets `wLastMap` — probably faithful, not a port bug

- Mechanism, all links verified: `SetPal_Overworld` (`palettes.asm:544+`, arms `g_pal_dirty` at the tail so `commit_palette` DOES commit) chooses by branch — `wCurMap < FIRST_INDOOR_MAP (0x25)` reads the map directly, indoor IDs in `[0x25, CERULEAN_CAVE_2F=0xE2)` take `.lastMap` and read `wLastMap`. All three A1 maps (`OAKS_LAB=0x28`, `PEWTER_GYM=0x36`, `ROUTE_15_GATE_2F=0xB9`) take `.lastMap`; `INDIGO_PLATEAU=0x09` does not (which is why the outdoor plate differs).
- Neither harness path ever sets `wLastMap`: the port's SKIP_TITLE boot funnels `EnterMapBoot → EnterMap → LoadMapData` (palette pipeline runs, dirty armed — no skipped writer, closing §F's remaining hypothesis too); mGBA runs new-game → Pallet → script-warp (`hidden_object.lua:87-90`), and the script-warp arm of `WarpFound2` (`.indoorMaps`, destination ≠ LAST_MAP) never writes `wLastMap` — only the outside branch and `.goBackOutside` do. Neither side's game init writes it either (no hits in pret or port oak-speech/init). Both sides therefore read power-on zero (mGBA zeroes RAM; port BSS/DPMI zero) → same palette ID → byte-identical DAC, while the per-map CGB RAM both sides compute matches the ROM.
- Reframing: the identical-across-maps half of §A1 is very likely TWO FAITHFUL EMULATIONS of an unset-variable read, not a port divergence — no `g_pal_dirty`/writer defect is needed to explain it, and none was found (`SetPal_Battle/Screen/Overworld` all arm; `commit_palette` early-out is correct-by-construction here since dirty IS armed). What REMAINS genuinely suspect is only the 8 shared divergences (OBJ pal4–7 colour2/3).
- Separation the file previously blurred: the maintainer's live-play report (walked-in gym wearing the wrong town palette, `wLastMap` properly set by the outside walk) is a DIFFERENT phenomenon from the harness-identical-DAC and the harness cannot observe it — do not cite the three-md5 evidence for the walked-in complaint or vice versa.
- Discriminating measurements (not taken this loop): dump `wLastMap` + computed slot-0 palette ID on both sides in one scenario (agreement ⇒ faithful, close the identical-DAC half); then a walked-in pob (Pewter City → Gym door) dumping the DAC — THAT is the repro the live-play complaint owes.

---

# Iteration 27 (same date — the 8 OBJ divergences, byte evidence + a paradox)

Skills used: same four. No subagents.

## BA. `route_15_binoculars` golden measured: OBJ pal4–7 c2/c3 = port white vs ROM blue/black; OBP1-restore theory dead

- Exact bytes (`goldencheck SCENARIO=route_15_binoculars`, PASS with reporting-only PALETTE section): OBJ pal4/5/6/7 colour2 `rom=(11,23,31) port=(31,31,31)`, colour3 `rom=(3,3,3) port=(31,31,31)`. Port shows double-white; ROM shows blue then near-black. Scenario otherwise fully green (TILEMAP/VRAM/OAM/WRAM OK).
- Killed this iteration: the "OBP1 never restored" theory. `LoadGBPal` (`fade.asm:77-84`) restores `IO_BGP/OBP0/OBP1` from `FadePal4` (`fade.asm:178`: BGP=$E4, OBP0=$D0, OBP1=$E0) and the boot path runs it. With OBP1=$E0 (pairs c0=0,c1=0,c2=2,c3=3), `DumpPalette` builds pal4–7 c2/c3 from `pal_rgb_table[slot][2..3]` — so the white comes from the TABLE entries for the slot's palette ID, and the ROM side disagrees on exactly those two entries.
- Paradox recorded, not resolved: `SetPal_Overworld` writes the SAME id into `bg_slot_pal[0]` and `obj_slot_pal[0]`, and BGP=$E4 is identity — so port BG c2/c3 should equal the same white table entries, yet the PALETTE section reports BG matching. Candidate resolutions: (a) the PALETTE section's BG comparison rides a different surface than the DAC-slot construction (e.g. the `cgb_palettes` GBSTATE region, which matches via the per-map path §A1 cites); (b) BG entries genuinely coincide for another reason. Do NOT "fix" the table yet — a Tier-1 data edit on a paradox is how regressions are made.
- Decisive next measurement (not taken): dump `bg_slot_pal[0]` vs `obj_slot_pal[0]`, `IO_BGP/OBP1`, and the table row for that palette ID in one port run, against the golden's expected bytes — that decomposes white-vs-blue into register/slot/table, the symmetric-confirmation discipline. The wLastMap-agreement question from §AZ rides along: same dump must carry `wLastMap` (it is in NO compared golden region — 17 regions checked, `wLastMap` absent).

---

# Iteration 28 (same date — §A2 root-caused: droplet publish on the wrong side of the wipe — OPEN)

Skills used: same four. No subagents.

## BB. `_AnimationWaterDroplets` publishes AFTER `AnimationCleanOAM` wipes — droplets never reach the renderer (statically proven, repro owed)

- Tail (`animations.asm:1766-1769`): compose droplets into `wShadowOAM` → `call AnimationCleanOAM` (DelayFrame + `ClearSprites` + publish-zeroed, `:943-970`) → `call PublishBattleAnimOAM` (re-publishes the ZEROED shadow) → `jmp DelayFrame` (renders nothing). The DelayFrame that should show the droplets runs BEFORE any publish of them — and in battle `update_oam` skips the shadow copy (`wUpdateSpritesEnabled=$FF`, `vblank.asm:324-328`), so nothing else carries them either. Net per frame: stale → wiped → wiped. The 32-iteration outer loop recomposes positions no frame ever displays. Exactly the reported symptom (droplet phase invisible, column phase via `DrawFrameBlock` — which publishes BEFORE its delay, `:373-375` — fine).
- Why pret's identical text order works: GB VBlank DMA copies shadow→OAM continuously, so CleanOAM's DelayFrame displays the just-composed droplets; the port has no live DMA and its explicit publish sits on the wrong side of the wipe. The projection bridge is real (both helpers exist and are correct) — it is only misordered here.
- Uniqueness proven, not asserted: every other `PublishBattleAnimOAM` caller (`:1543`, `:1620`, `:1650`, `:1822`, `:2566`) and both inlined `PublishProjectedOAM` sites (TradeShake `:598`, TradeJump `:639`) publish BEFORE their delay/clean. `_AnimationWaterDroplets` (`:1767`) is the sole inversion. Tiles exonerated (`MoveAnimationTiles0` = 79 tiles at vSprites `$31`, covering droplet tile `$71`; `CopyVideoData` arms the cache); clip rect exonerated (battle-frame clip contains the droplet span; offscreen hiding correct).
- Fix direction (not taken this loop): swap the two calls — publish, then CleanOAM, then the closing DelayFrame (which then shows the cleared state, matching pret's final `jp DelayFrame`). Must re-run `battle_menu`/`move_selection` goldens after: the publish-zeroed behavior inside CleanOAM exists to keep those two green (12 stale OAM entries, `:935-941`), so the reorder must preserve it. Repro owed: `DEBUG_ANIM_DEMO=1 ANIM=SURF` headless, `FRAME.BIN` during the droplet phase.


## BC. `wPredef` slot populators: endianness clean (do not re-audit)

- `add_mon.asm:104-106` (runtime-split low/high with explicit big-endian comment) and `item_effects.asm:2342-2343` (`>> 8` / `& 0xFF` assembly-time split) both stage H at `[slot]`, L at `[slot+1]`, matching `GetPredefRegisters`' read order (`predef.asm:27-37`). The §AA-correct `AskName` pattern rests on correct inputs.

---

# Iteration 29 (same date — BB repro caveat + fix/state verifications, no new bugs)

Skills used: same four. No subagents.

## BD. BB masking interaction: a stale `$43` capture code un-breaks the droplets (repro must use a fresh battle)

- `AnimationCleanOAM`'s port-only `$43` early-return (`animations.asm:960-962`, documented capture-ball divergence) skips the wipe when `wPokeBallAnimData=$43`. That byte is set at capture (`item_effects.asm:1798`) and only overwritten by the next ball throw (`:2030`, ball id) — so in any LATER battle before a throw, the droplet tail becomes compose → CleanOAM (DelayFrame stale, NO wipe) → publish DROPLETS → DelayFrame SHOWS them. The BB inversion is masked exactly when a previous capture is in history.
- Consequence for the owed repro: `DEBUG_ANIM_DEMO=1 ANIM=SURF` must run with no prior capture in the session, or droplets will appear and the bug will read as absent. Same caveat for Mist/Toxic droplet phases. (The early-return itself is not filed: pret's CleanOAM has no `$43` check, but the divergence is documented, reasoned, and load-bearing for the catch prompt.)

## BE. Post-commit state verifications (do not re-audit)

- §E fix final state: Route23 site-1 (`:155-163`) carries `mov cl, bl` + `call FlagAction` + `mov al, cl` with BL (loop counter) preserved; Cinnabar trampoline (`:184-186`) is `jmp FlagAction`. Census stands at zero remaining `call/jmp FlagActionPredef` in sources.
- §A4 writers still confined: `H_LOAD_SPRITE_TEMP1/2` written only in `home/overworld.asm:5265-5350` (InitSprites/LoadSprite region). No new reader or writer; gate-blindness unchanged, still owner-side work.

---

# Iteration 30 (same date — BB uniqueness completed: all 7 `AnimationCleanOAM` call sites classified)

Skills used: same four. No subagents.

## BF. CleanOAM census: the droplet tail is the only compose-then-clean site (BB stands, nothing else shares it)

- All 7 port callers: `:410` (frame-block loop end-cleanup, after final `DelayFrames`, nothing composed after), `:624` (`MoveAnimation.animationFinished` end-cleanup before clip restore), `:1552` (publish → delay → … → end-cleanup), `:1600` (per-frame publish loop tail-jumping cleanup), `:2394` (publish → … → cleanup), `:2450` (conditional end-cleanup), `:1766` (droplets: compose → cleanup → publish → delay). Six are end-cleanups or publish-first; only `:1766` composes fresh OAM after its last publish and then wipes before publishing.
- Also closed in passing: the live `OverworldLoop.mapTransition` (`.mapTransition`, `overworld.asm:2218+`) DOES run `RunPaletteCommand(SET_PAL_OVERWORLD)` — the "palette reload still deferred" note at `:2816-2824` describes the `CheckMapConnections` helper's own scope (it returns CF=1 for the caller to reload), not the live path. No connection-crossing palette staleness; do not file.

---

# Iteration 31 (same date — counter-width re-sweep: no new defects)

Skills used: `asm-translation` (counter-width rule) + `faithfulness-review`. No subagents.

## BG. Tree-wide `dec r32` re-sweep after the B1–B3 fixes: everything remaining is guarded or not a counter

- Method: all `dec (ecx|ebx|edx)` sites re-examined for the can-it-be-zero question. Results, one line each:
  - `print_dev.asm:207` checksum loop — `test ecx,jz` guarded, protocol length. OK.
  - `overworld.asm:896,923,975,998` — `DEBUG_SEAM_STEPS` literals, debug-only. OK.
  - `overworld.asm:3379,3406` — connection-strip widths / `MAP_BORDER` literal. OK (prior §D).
  - `overworld.asm:5277` (sprite count, `dec ebx`) — guarded by `test al,jz .done`, and the guard MIRRORS pret (`and a / ret z`, `home/overworld.asm:2148-2150`), so no 0-vs-256 divergence is owed an annotation. OK.
  - `overworld.asm:5310` — literal 14. OK. `load_font.asm:67`, `vcopy.asm:390,634,642` — prior §D, still OK. `vcopy.asm:444` — same B4-gated routine. OK. `vcopy.asm:506` — `TILE_SIZE/4` literal. OK.
  - `pokemon.asm:454,457`, `pics.asm:184,192` — `dec` on walking POINTERS inside `ECX`-counted loops, not counters. False positives; do not "fix".
- Verdict: the widened-counter class is exhausted tree-wide (B1–B3 were the only live defects, now fixed). Future loops need only check NEW `dec r32` sites, not re-sweep.

---

# Iteration 32 (same date — new OPEN: Daycare `WriteMonMoves` without slot setup, §E-class)

Skills used: same four. No subagents.

## BH. Daycare deposit learns moves into a stale address — BUG (static-proven, runtime repro owed)

- `Daycare.asm:295-305` computes the mon's move-slot base into EDX (`AddNTimes` + `mov edx, esi` pair-copy) and `call WriteMonMoves` directly — but `WriteMonMoves` (`evos_moves.asm:792`) opens with `call GetPredefRegisters`, which RELOADS EDX from `wPredefDE`, and nothing on this path stages that slot. Pret uses the `predef` dispatcher (`scripts/Daycare.asm:194`), which stashes DE first. Same shape as §E1/§E2 (direct call keeping the restoring prologue), different routine — the §E census (which swept only `FlagActionPredef`) did not cover it.
- Only EDX is live: ESI is re-derived by `GetMonLearnset` and EBX is scratch inside, so the damage is exactly the move-slot base — daycare level-up moves are read from / written to whatever stale address the slot holds (WRAM corruption + mon learns nothing), instead of the deposited mon's `MON_MOVES`.
- Census (complete): `WriteMonMoves` has 4 port callers — `core.asm:4017`, `add_mon.asm:273`, `debug_battle_moveset.asm:77` all stage `wPredefDE` big-endian with comments; Daycare is the sole unstaged one. `LoadMovePPs` census also swept (`core.asm:4025`, `item_effects.asm:749`, debug `:85` — all stage both slots). `SetPartyMonTypes` callers stand as §AA verified.
- Fix direction (not taken this loop): stage `wPredefDE` from EDX big-endian before the call, mirroring `add_mon.asm:267-269` (or the debug `:74-76` lines). Repro owed: deposit a mon that gains a daycare level with new moves due, then inspect its move list (and the stale target) — no scenario covers daycare move learning.
- Process note: this section was hunted one loop earlier but its append collided with a parallel worker's same-file claim; the hunt parked it in episode 336 and this loop appended it once the claim lapsed. No content changed in between; line refs re-verified at append time.

---

# Iteration 33 (same date — clean sheets: fishing rods + daycare-flag writers)

Skills used: same four. No subagents.

## BI. Rod routines faithful, `wLearningMovesFromDayCare` fully staged (do not re-audit)

- `ItemUseOldRod/GoodRod/SuperRod` + `RodResponse` (`item_effects.asm:3223-3290`) match pret (`engine/items/item_effects.asm:2033+`) branch for branch, including the subtle bits both sides document: `shr/srl` CF into the no-bite path, `and a` clearing CF on the mon-picked path, `setc` as the flag-faithful `rla` (`AL=CF` flipped by `xor 1`), `dec al/jnz` bite gate, and the walk-state force-0 around `FishingAnim`. `fish_old_rod` golden covers the path.
- `wLearningMovesFromDayCare` writers (complete census): `Daycare.asm:304` (=1), `add_mon.asm:271` (=0), `core.asm:4013` (=0), `debug_battle_moveset.asm:73` (=0) — every `WriteMonMoves` caller sets it immediately before the call. No stale-flag leak onto the §BH path or elsewhere.

---

# Iteration 34 (same date — 8 OBJ divergences: white-collapse points at `IO_OBP1`, precedent found)

Skills used: same four. No subagents.

## BJ. Port renders OBJ pal4–7 c2/c3 white while the table row is not white — register collapse, same class as the fixed `battle_intro` one

- Table exonerated (conditional on slot=PAL_PALLET from §AZ): `pal_rgb_table[PAL_PALLET]` = c0 white, c1 `(47,35,63)`, c2 `(22,47,63)`, c3 `(6,6,6)` — entries 2/3 are NOT white, so the port's double-white `(31,31,31)` cannot come from the table through OBP1=$E0 (pairs c2→2, c3→3). It matches OBP1=$00 instead (all pairs → entry 0 = white), with ROM c0/c1 agreeing because entry 0/1 coincide in white there. (Byte note: the golden reports 5-bit BGR555 components — `(11,23,31)`/`(3,3,3)` vs `(31,31,31)`.)
- Precedent found in-tree: `SlideBattlePicsIn` (`pics.asm:605-626`) documents the IDENTICAL collapse (OBP0/OBP1 left at init 0 → OBJ palettes white → 12 pal4–7 divergences in `battle_intro`), fixed by writing pret's `$E4` binary literal, measured against `battle_palette_trace.lua`. The binoculars 8 read as the overworld-path twin of that bug.
- Writer census for `IO_OBP1`: `LoadGBPal` (restores `$E0`), fades, `GBPalWhiteOut` (the ONLY zeroer, `palettes.asm:174`), boot init (zero, later overwritten), battle/surf/ghost/demo paths (not on this flow). No `GBPalWhiteOut` caller found yet on the A-press → hidden-event → textbox → mon-box path (`text.asm`/`window.asm`/`text_box.asm` clean) — so the zeroer, or the missing restore, is still unidentified. Candidates narrow to the mon-box popup (`DisplayMonFrontSpriteInBox`/front-repaint) or the hidden-object gate setup.
- Next measurement (not taken): dump `IO_OBP0/OBP1` + slot bases at the dump frame — one run decomposes register-vs-slot-vs-table outright. If OBP1=$00 is confirmed, the fix mirrors the `pics.asm` precedent (restore pret's register value on the path that dropped it) and must cite it.

---

# Iteration 35 (same date — colorization table VINDICATED; OBP1=$00 stranded by `GBPalNormal` shape)

Skills used: same four. No subagents.

## BK. `pal_rgb_table[PAL_PALLET]` equals the ROM bytes — the white comes from the register, and `GBPalNormal` cannot repair it

- Vindication: table c2 `(22,47,63)` >>1 = `(11,23,31)` = ROM c2; table c3 `(6,6,6)` >>1 = `(3,3,3)` = ROM c3 (6-bit DAC halved to the golden's 5-bit BGR555). The Tier-1 colorization data MATCHES hardware — no table edit is owed or permitted. The port renders white/white only if OBP1 maps c2/c3 to entry 0, i.e. OBP1=$00 at dump.
- Stranding mechanism: `GBPalNormal` (`palettes.asm:146`) restores `IO_BGP` + `IO_OBP0` but NOT `IO_OBP1` — faithful to pret, which also skips OBP1 there. So ANY `GBPalWhiteOut` ($00 all three) followed by `GBPalNormal`-instead-of-`LoadGBPal` strands OBP1=$00 permanently: BGP/OBP0 come back, OBP1 does not. `LoadGBPal` (FadePal4 → $E0) is the only restorer, and the mon-box popup (`DisplayMonFrontSpriteInBox`, audited this iteration: window save/restore correct, `AnimateSendingOutMon` tile-only, no palette writes) does not call it — nor does anything else on the A-press → textbox → mon-box path found so far.
- Suspect pool narrowed to one shape: a WhiteOut→Normal (not WhiteOut→LoadGBPal) sequence on the scenario flow. Our own §J teardown sites all pair WhiteOut with `LoadGBPal` (safe). Still to find: which call on this flow zeroes. The one-run dump (`IO_OBP1` at frame) from §BJ/§BA remains the arbiter; if it reads $00, grep the flow for the WhiteOut and convert its restore to `LoadGBPal` (or add the OBP1 register write with a pret citation, `pics.asm`-style).

# Iteration 36 (same date — static trail on the 8 OBJ divergences EXHAUSTED; runtime values only)

Skills used: same four. No subagents.

## BL. Every static theory of the white-collapse is dead — the dump is the only remaining arbiter

- Killed this iteration, in order: (1) mon-box popup exonerated — `DisplayMonFrontSpriteInBox` (`museum_fossils2.asm:48-79`) does window save/restore + tiles only, no palette writes; `AnimateSendingOutMon` (`init_battle.asm:745+`) is tile animation, no register writes. (2) `LoadMapData` DOES run `GBPalNormal` + `BH=SET_PAL_OVERWORLD → RunPaletteCommand` (`overworld.asm:4870-4872`), so slots are map-populated, not boot-white. (3) `LoadGBPal` runs EVERY `OverworldLoopLessDelay` iteration (`overworld.asm:1767`, restored 2026-08-11 expressly because its absence left OBP1 at zero) — OBP1=$E0 at any in-loop dump frame. (4) `UpdateCGBPal_OBP1` is a trivial dirty-arm (`cgb_palettes.asm:10-12`), no overwrite. (5) `pal_rgb_table` has no runtime writers (only its `global` decl) — the .inc row stands.
- Standing paradox, stated plainly: slots map-populated + OBP1=$E0 + static-correct table ⇒ port should render the ROM bytes, but renders white. All three premises are code-read, none is runtime-measured. One of them is wrong at frame 260, and no further reading can say which — the candidate the code cannot exclude is a runtime slot/Table/offset value differing from the read (e.g. `wMapPalOffset`, a `RunDefaultPaletteCommand` with a different resident command mid-flow, or the dump frame landing outside the loop's LoadGBPal).
- Stop rule for future loops: do NOT re-walk boot/dispatch/table/flow without the dump (`IO_BGP/OBP0/OBP1` + `bg/obj_slot_pal[0..3]` + `wMapPalOffset` + `wLastMap` + `wDefaultPaletteCommand` at the dump frame, against the golden's 8 bytes). Any further static theory must first explain why the five kills above do not apply to it.

---

# Iteration 37 (same date — final: Gen-2 offset-7 path verified through `MoveMon`)

Skills used: same four. No subagents.

## BM. Party↔box conversion carries offset 7 by whole-struct copy (do not re-audit)

- `BillsPCDeposit/Withdraw` funnel through `MoveMon` → `_MoveMon` (`add_mon.asm:459+`): the mon-data move is a single `CopyData` of `BOXMON_STRUCT_LENGTH` (33) bytes (`.copyMonData`), then OT/nick moves by `NAME_LENGTH` copies. No per-field packing, no byte skipped or realigned — offset 7 travels inside the verbatim 33-byte window on every direction (party→box, box→party, daycare legs), exactly as pret's equivalent does. Corroborates §R from the conversion core rather than the annotations: the Gen-2 held-item slot survives Bill's PC by construction, not by six scattered annotations holding.
- Loop stopped per maintainer instruction after this iteration; audit stands at 37 iterations, fixes landed for U/E/B/J (+NameRater), OPEN items carry repro prescriptions.

---

# Iteration 38 (fix record: BB/BH/AS landed and tested)

Skills used: same four. No subagents (maintainer-directed fixes).

## BN. `a27a9066b` §BB (droplet publish reorder), `42489bd74` §BH (daycare slot staging), `fc4230292` §AS (town-map window save/restore)

- BB: two-line swap + comment; `battle_menu` + `move_selection` goldens PASS (the constraining pair named in §BB); nasm + lint clean both modes.
- BH: two-line `wPredefDE` staging; nasm + lint clean. No golden covers daycare move learning — covered by core fidelity below.
- AS: `tm_saved_wc` cell + save/zero/restore + extern (10 insertions); nasm + lint clean. Covered by core fidelity below.
- Regression gate: core `fidelity` 17/17 PASS (EXIT=0) after all three commits. §A1: analysis only, no code change.
