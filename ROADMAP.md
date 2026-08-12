# Pokémon Yellow DOS Port — Development Roadmap

High-level phase view — the coarse map only. Live status/scope lives in
`CLAUDE.md` ("Current Phase") and in the active plan set. **Do not maintain a
plan list by hand anywhere; generate it:**

```sh
dos_port/tools/project_state --plans     # the authoritative plan inventory
```

That currently emits 11 `docs/current_plan*.md` / `docs/current_plans*.md`
entries with per-plan completed/open checkbox counts. Deferred tails with no
other owner live in `docs/current_plan_backlog.md`. Files under `docs/plans/`
are the **archive** — completed or superseded plans kept for provenance; they
are not the work queue.

**Current focus: Phase 2 (game loop).**

### Feature freeze, early July 2026 → 2026-08-02 (ENDED)

Between early July and 2026-08-02 the project ran a deliberate feature freeze:
no new gameplay, only correctness, fidelity tooling and maintainability. What it
produced, and what a reader should expect to find as a result:

- **`dos_port/tools/static_gate`** — a whole-tree static ratchet over a
  checked-in per-class baseline (`tools/static_gate_baseline.json`), running
  both `lint_pret_labels` modes, `pytest tools/test_label_db.py` and
  `validate_scenarios.py`. It is invoked automatically by `.githooks/pre-commit`
  (install: `make -C dos_port install-hooks`).
- **`dos_port/tools/fidelity_gate`** — the per-change, per-label evidence chain,
  including the relocation move battery.
- **The golden fidelity harness matured** — `dos_port/tools/scenario_manifest.json`
  holds 37 scenarios (16 `core`, 37 `full`), with an empty `disabled_scenarios`
  list.
- **Structured annotations replaced free-form ones** — `DEVIATION` / `BUG` /
  `GLITCH` / `STUB` in the machine-parsed `{class=…; pret=…; …}` form.
- **Lint debt driven down to a single documented `aux_misplaced` finding**
  (commits `a3804828`, `3fad3249`, 2026-08-02).

The freeze is over; feature work on finishing the port resumes.

---

## Phase 0: Bootstrapping — ✅ COMPLETE

**Goal:** Prove the translation toolchain end-to-end before writing any game logic.

Acceptance criteria:
- Reference ROM builds cleanly and SHA1-verifies (`make compare` with rgbds
  **1.0.2** — pinned in `.rgbds-version`; the installed toolchain reports
  `rgbasm v1.0.2+hotfix`)
- DOS skeleton: mode 13h initializes, test pattern visible, PIT tick counter increments on screen
- `dos_port/include/gb_memmap.inc` defined with all offsets from `constants/hardware.inc`
- First routine translated (`FillMemory`) with translation log entry
- `CLAUDE.md`, `docs/register_map.md`, `docs/references/` populated
- Bug-fix flag architecture (`BUG_FIX_LEVEL`, `/FIXALL`, `/FIXCRIT`) defined in `gb_macros.inc`

---

## Phase 1: Core Infrastructure — ✅ COMPLETE

**Goal:** The game loop runs with emulated memory, working input, and a basic renderer.

**Status:** GB memory model, software PPU (BG + native-width renderer + OAM sprites +
window compositor), and joypad all live.
`BUG_FIX_LEVEL`/`/FIXCRIT`/`/FIXALL` in effect (e.g. the inventory-terminator guard,
2026-07-04).

**Save is complete and SRAM-compatible — this is no longer a Phase 5 item.**
All four SRAM banks are emulated **resident** (bank 0 at `$A000`, banks 1–3 at
`$22000-$27FFF`; `class=banking` deviation, the same flat model as the ROM), and
pret's save/load/box routines read and write the real `s*` addresses.
`dos_port/src/save/dsv_io.asm` persists the whole 32 KiB image as **`.dsv` v2**
(`DSV_VERSION = 2`): 32775 bytes = a 7-byte header (`DOSV` magic 4 + version 1 +
checksum 2) followed by the raw 32768-byte SRAM image, bank 0 first.
`SramLoadImage` runs at boot, `SramStoreImage` at every save commit. The Bill's
PC box UI is a faithful pret mirror
(`dos_port/src/engine/pokemon/bills_pc.asm`) and the tier is golden-gated by the
`bills_pc_ops` and `box_change_roundtrip` scenarios. Plan archived at
`docs/plans/sram_pc_storage.md`; its one open flag is the torn-write-guard
acceptance awaiting maintainer sign-off.

Acceptance criteria:
- GB memory model live: 72 KB DPMI allocation, EBP-relative access working
- Software PPU:
  - Tile renderer (8×8 tiles from VRAM, 2bpp → 8bpp palette lookup)
  - Background tilemap render (32×32 tilemap, SCX/SCY scroll)
  - OAM/sprite renderer (40 sprites, 8×8 and 8×16, priority)
  - Window layer
- Joypad: DOS keyboard/INT 9h → emulated JOYP register
- Save/load: DOS file I/O (INT 21h) behind resident emulated SRAM; `.dsv` v2
  format defined and shipping
- All critical bugs categorized (`/FIXCRIT` flag has meaningful effect)

---

## Phase 2: Game Loop — 🔨 IN PROGRESS (current)

**Goal:** Main game is playable through overworld and battles.

Acceptance criteria:
- [~] Title screen — bespoke early implementation; boots and reaches the menu but
      does **not** render fully correctly (a known low-priority defect; "works
      enough"). Faithful reimpl deferred — likely folds in with the overworld
      tile-management rewrite. See `docs/current_plan_backlog.md`.
- [x] Overworld renders and scrolls; player walks around Pallet Town
- [x] Wild encounters trigger (`src/engine/battle/wild_encounters.asm`; the
      `AnyPartyAlive` gate moved to `src/engine/battle/core.asm` and the old
      `src/home/wild_encounter_check.asm` was deleted 2026-07-26)
- [x] Battle UI renders and accepts input — full wild + trainer battles play
      end-to-end (battle swarm, merged to `master`; open fidelity items in
      `docs/archive/battle_audit_findings.md`)
- [x] NPCs display dialogue (`docs/plans/npc_implementation.md`)
- [x] `engine/menus/` ported + realigned onto generic drivers
      (`docs/plans/menus.md`, complete 2026-07-04)
- [x] Pokémon data/stats + behavior/UI (evolution, learn-move, status screen,
      post-battle) — `docs/plans/pokemon_engine.md`, `docs/plans/pokemon_behavior.md`
- [x] Items/bag layer — add/remove/TOSS, USE dispatch, and every item-handler
      family. `UseItem_` and `ItemUsePtrTable` are translated in
      `src/engine/items/item_effects.asm`; the last handler family, fishing rods,
      landed in `fe91b329`, deleting `item_use_stubs.asm`. Completed plan:
      `docs/plans/items.md`.
- [x] New-game data init (`InitPlayerData2` — party/box/bag terminators + money/ID)

**Remaining before Phase 2 closes — query it, do not read a list here.**

This section used to enumerate four open items. Every one of them was wrong by
2026-08-02, in a different direction, so the list is gone rather than corrected —
the same call already made in `CLAUDE.md`'s Current Phase, for the same reason.
What it claimed and what was measured:

| Old claim | Measured 2026-08-02 |
|---|---|
| "Faithful full `engine/overworld/` reimpl … the main open item" | That plan is **complete and archived** (`docs/plans/overworld_port.md`) |
| "scripted NPC movement" still open | **Done** |
| "the **VRAM tile-slot management fix** that resolves the live menu-box corruption" | The VRAM tile-slot *explanation* was **disproven in the plan itself** on 2026-07-05 and refiled as ticket OW-A.13 (`docs/plans/overworld_port.md:153`: "the original (incorrect) analysis is kept below for the record"). It also cited stigmergy memory `menu-corruption-vram-tileslots`, **which does not exist**. Whether any menu-box defect is still live needs re-measuring, not repeating |
| "item USE dispatch" deferred | **False** — see the items bullet above |

**To find what is actually open:**
```sh
dos_port/tools/project_state --plans          # every active plan + open counts
dos_port/tools/label_status --callers <Label> # is a given routine linked/reached
```
then read the owning `docs/current_plan_*.md`. The live Phase-2 plans are
`current_plan_overworld_events.md`, `current_plan_items.md`,
`current_plan_battle_completion.md` and `plans/menu_intro.md`; deferred
tails with no other owner are in `docs/current_plan_backlog.md`.

⚠ **Those first three carry a maintainer directive (2026-08-02): re-measure
before executing.** Their open-item lists come from a 2026-07-12 hand survey done
*before* the analysis tooling existed, and at least one confirmed stale claim
survives in them. Do that pass first; do not work them top-down.

---

## Phase 3: Audio — ✅ ARCHITECTURE COMPLETE; open work is per-track arrangement

**Goal:** Full audio support across supported sound cards.

**Status.** The sound HAL landed as `dos_port/src/audio/audio_hal.asm` (a `.asm`,
not an `.inc`) with the per-device shims beside it: `opl_shim.asm`,
`tandy_shim.asm`, `spk_shim.asm`, `mpu401.asm`, `sb_pcm.asm` (plus `spk_pcm.asm`
and the `opl_enh.asm` enhancement layer). The pret audio engine is translated and
live in the build (`engine_1..4.asm`, `low_health_alarm.asm`, `poke_flute.asm`,
`play_battle_music.asm`, `pikachu_pcm.asm`, `alternate_tempo.asm`,
`pokedex_rating_sfx.asm`). Per `docs/current_plan_audio.md`, phases A–E are
implemented and merged to master; **Phase C (Pikachu PCM) and Phase D (Tandy +
speaker SFX + polish) both completed 2026-07-07**, and Phase B's MIDI/MT-32
infrastructure is complete with only by-ear tuning outstanding.

Device selection at runtime is via `PKMN.EXE` flags (see `dos_port/boot/entry.asm`
`parse_cmdline`): `/NOSOUND /MT32 /GM /TANDY /SPK /NOENH`.

| Driver | Notes |
|--------|-------|
| Sound Blaster / OPL | `opl_shim.asm` + `sb_pcm.asm` — the default path |
| General MIDI | `mpu401.asm`, UART mode (`/GM`) |
| Roland MT-32 | `mpu401.asm` + `assets/mt32_sysex.inc` (`/MT32`) |
| Tandy 3-voice | `tandy_shim.asm` + `assets/tandy_tables.inc` (`/TANDY`) |
| PC Speaker | `spk_shim.asm` / `spk_pcm.asm` (`/SPK`) |

**Remaining Phase 3 work — content, not architecture:**
- Per-track LLM arrangement passes (Phase E): OPL3 tier-1, then MT-32/GM
  tier 2–3, auditioned per song. See `docs/current_plan_audio.md` and the
  `score-analysis` / `music-theory` / `audio-enhance-*` skills.
- MT-32 by-ear patch tuning through the audition loop (Phase B tail).
- Deferred: upgrading `sb_pcm` to auto-init DMA.

Query the live open-item list rather than trusting this list:
`dos_port/tools/project_state --plans` (as of writing: `current_plan_audio.md`
30 completed / 4 open).

---

## Phase 4: Network Multiplayer

**Goal:** Trade and battle over a network connection, replacing the link cable.

Transport selection (decide during implementation):
- IPX packets (Novell/DOS; works in DOSBox and 86Box)
- Raw serial / null-modem (real hardware via COM port)
- Packet-driver TCP/IP (WATTCP or mTCP)

Acceptance criteria:
- Link cable I/O HAL defined, replacing the `; TODO-HW: network HAL` stubs. Those
  stubs live in `dos_port/src/home/serial_stubs.asm`; the call sites carrying the
  tag are in `src/engine/menus/link_menu.asm`, `src/engine/pokemon/bills_pc.asm`
  and `src/engine/battle/end_of_battle.asm`. There is no HAL file yet —
  `serial_hal.inc` is a proposed name, not a path.
- Pokémon trade verified between two instances
- Link battle verified between two instances

---

## Phase 5: Polish & Save Compatibility — 🔨 PARTIALLY LANDED

**Goal:** Shippable quality; saves interoperate with the original Game Boy version.

**The save-compatibility half is already done** (see Phase 1 and the converter
criterion below); what is left here is polish and packaging.

Acceptance criteria:
- [x] Save file converter: `dos_port/tools/saveconv.py` — **DONE**. Bidirectional
      GB `.sav` ↔ DOS `.dsv` with `--verify` / `--info` / `--to-dos` / `--to-gb`;
      no stubs. It is load-bearing, not shelfware: `dos_port/tools/goldencheck.sh`
      calls `--to-dos` to build the seed save on every `save_real_load`-class run,
      which keeps the converter honest against the shipping format.
      - GB `.sav`: raw 32768-byte SRAM dump (MBC5+RAM+BATTERY)
      - DOS `.dsv` v2: 32775 bytes — a 7-byte header (`DOSV` magic 4 + version
        byte + 2-byte payload checksum) followed by that same 32768-byte image
- [~] Full colorization: the tool + pipeline are complete and archived
      (`docs/plans/colorization.md`, "complete — archived 2026-07-13";
      `dos_port/tools/colorize.py`, `assets/colors/palettes.{json,inc}`, runtime
      stages R1–R3 all ticked). Remaining Phase 5 work is per-asset palette
      authoring, not tooling.
- [~] CGB BG attribute planes: `data/cgb/bg_map_attributes.asm` is consumed and
      `LoadBGMapAttributes` is ported (2026-08-09). The port resolves the
      per-cell plane to its per-tile-id `tile_pal` and re-applies it every frame,
      which is what the hardware's VRAM-bank-1 plane does. Live on the title,
      status, pokédex-entry and trainer-card screens; the Yellow intro's
      `YellowIntroPaletteAction` is ported too. **Battle needs no per-cell
      compositor layer** — measured: its only colliding tile is the HP-bar
      segment, already solved by the existing `$C0-$C8` gauge clones. Left: the
      two per-cell runtime handlers (`HandleBadgeFaceAttributes`,
      `HandlePartyHPBarAttributes`, both stubs) and the two inline intro
      attribute boxes, all of which need a real per-cell layer.
- [ ] Fullscreen scaling options: 2× nearest-neighbor (default), integer scale options
- [ ] Packaging: documentation, DOSBox config example (a working one already
      exists at `dos_port/dosbox-x.conf`, used by `dos_port/run`), 86Box config
      example

---

## Phase 6: Glitch Preservation & Sandbox

**Goal:** All known glitches preserved and documented; dangerous glitches safely isolated.

Bug categorization: the working inventory is **`docs/bug_categorization.md`**
(tracked by `docs/current_plan_bug_tagging.md`); `docs/bugs_and_glitches.md` is
the small upstream-pret list, not the full catalogue.
- **Critical**: buffer overflows, OOB writes, save corruption, arbitrary code execution paths
- **Cosmetic**: wrong text, minor visual/behavioral differences
- **Intentional glitch**: MissingNo, item duplication, item slot $FF, ACE routes

Acceptance criteria:
- [~] Every catalogued bug tagged at its site in the translated source using the
      **machine-parsed** annotation form
      `; BUG{class=…; pret=…; behavior=…; evidence=…; lifetime=…}` (and
      `GLITCH{…}` / `DEVIATION{…}` / `STUB{…}`). **The old free-form
      `; BUG(level):` syntax is dead — do not write it.** Tagging is well under
      way, not finished: `dos_port/src` currently carries 46 `BUG{`, 10
      `GLITCH{`, 192 `DEVIATION{` and 21 `STUB{` annotations (grep counts,
      2026-08-02 — re-measure rather than quoting these). Progress and the
      remaining sweep live in `docs/current_plan_bug_tagging.md`.
- [x] `/FIXCRIT` (level 1) and `/FIXALL` (level 2) parsed at runtime and gating
      `BUG_FIX_LEVEL` blocks (`dos_port/include/gb_macros.inc`,
      `dos_port/boot/entry.asm` `parse_cmdline`)
- [ ] Startup warning emitted when running with critical glitches enabled on bare
      hardware (detect via DPMI host ID string, INT 31h fn 0400h)
- [~] `docs/glitch_safety.md` exists; finalize with per-glitch safety notes
- [~] Stretch goal: launcher script for glitch/ACE mode. `dos_port/run` already
      launches DOSBox-X against the isolated `PKMN.IMG` (the host filesystem is
      never mounted, so an OOB disk write at any `BUG_FIX_LEVEL` can only corrupt
      the image); an 86Box equivalent does not exist.

---

## Deferred / Out of Scope

- SGB (Super Game Boy) functions — not relevant for this port
- Game Boy Printer / Camera accessories
- Virtual Console (VC) patch support
