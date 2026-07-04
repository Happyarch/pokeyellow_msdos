# Pokémon Yellow DOS Port — Development Roadmap

High-level phase view. Live status/scope lives in `CLAUDE.md` ("Current Phase" +
"Currently active plans"), `TODO.md`, and `docs/(current_)plan_*.md`; this file is
the coarse map. **Current focus: Phase 2 (game loop) — substantially playable;
remaining work is the faithful `engine/overworld/` reimpl + scripting.**

---

## Phase 0: Bootstrapping — ✅ COMPLETE

**Goal:** Prove the translation toolchain end-to-end before writing any game logic.

Acceptance criteria:
- Reference ROM builds cleanly and SHA1-verifies (`make compare` with rgbds 1.0.1)
- DOS skeleton: mode 13h initializes, test pattern visible, PIT tick counter increments on screen
- `dos_port/include/gb_memmap.inc` defined with all offsets from `constants/hardware.inc`
- First routine translated (`FillMemory`) with translation log entry
- `CLAUDE.md`, `docs/register_map.md`, `docs/references/` populated
- Bug-fix flag architecture (`BUG_FIX_LEVEL`, `/FIXALL`, `/FIXCRIT`) defined in `gb_macros.inc`

---

## Phase 1: Core Infrastructure — ✅ COMPLETE (save = minimal)

**Goal:** The game loop runs with emulated memory, working input, and a basic renderer.

**Status:** GB memory model, software PPU (BG + native-width renderer + OAM sprites +
window compositor), and joypad all live. Save is a **minimal real `.dsv`**
(`src/save/dsv_io.asm`, menus S7) — the full SRAM-compatible format is Phase 5.
`BUG_FIX_LEVEL`/`/FIXCRIT`/`/FIXALL` in effect (e.g. the inventory-terminator guard,
2026-07-04).

Acceptance criteria:
- GB memory model live: 72 KB DPMI allocation, EBP-relative access working
- Software PPU:
  - Tile renderer (8×8 tiles from VRAM, 2bpp → 8bpp palette lookup)
  - Background tilemap render (32×32 tilemap, SCX/SCY scroll)
  - OAM/sprite renderer (40 sprites, 8×8 and 8×16, priority)
  - Window layer
- Joypad: DOS keyboard/INT 9h → emulated JOYP register
- Save/load: DOS file I/O (INT 21h) replacing SRAM; `.dsv` format defined
- All critical bugs categorized (`/FIXCRIT` flag has meaningful effect)

---

## Phase 2: Game Loop — 🔨 IN PROGRESS (current)

**Goal:** Main game is playable through overworld and battles.

Acceptance criteria:
- [~] Title screen — bespoke early implementation; boots and reaches the menu but
      does **not** render fully correctly (a known low-priority defect; "works
      enough"). Faithful reimpl deferred — likely folds in with the overworld
      tile-management rewrite. See `TODO.md`.
- [x] Overworld renders and scrolls; player walks around Pallet Town
- [x] Wild encounters trigger (`wild_encounter_check.asm`)
- [x] Battle UI renders and accepts input — full wild + trainer battles play
      end-to-end (battle swarm, merged to `master`; open fidelity items in
      `docs/battle_audit_findings.md`)
- [x] NPCs display dialogue (`docs/plans/npc_implementation.md`)
- [x] `engine/menus/` ported + realigned onto generic drivers
      (`docs/plans/menus.md`, complete 2026-07-04)
- [x] Pokémon data/stats + behavior/UI (evolution, learn-move, status screen,
      post-battle) — `docs/plans/pokemon_engine.md`, `docs/plans/pokemon_behavior.md`
- [x] Items/bag layer (add/remove/TOSS; USE dispatch deferred)
- [x] New-game data init (`InitPlayerData2` — party/box/bag terminators + money/ID)

**Remaining before Phase 2 closes:**
- Faithful full `engine/overworld/` reimpl (`docs/current_plan_overworld_port.md`) —
  scripted NPC movement, cut/boulder/fly/etc., and the **VRAM tile-slot management
  fix** that resolves the live menu-box corruption. This is the main open item.
- Scripting engine (`docs/current_plan_script_engine.md`): per-map `_Script`
  machines, Oak walk-up cutscene, mart/pokécenter/PC scripts.
- Deferred UI/menu tails and item USE dispatch (see `TODO.md`).

---

## Phase 3: Audio

**Goal:** Full audio support across supported sound cards.

Sound HAL abstraction layer defined first; drivers plugged in behind it.

| Driver | Priority | Notes |
|--------|----------|-------|
| Sound Blaster 16 | High | Primary target; CT1341 DSP programming |
| General MIDI | High | Via MPU-401 UART mode (INT 33h or direct port) |
| Roland MT-32 | Medium | SysEx via MIDI; LA synthesis parameters |
| AdLib/OPL2 | Medium | Fallback for machines without SB16 |
| Tandy 3-voice | Low | Optional; Tandy 1000 compatibility |
| PC Speaker | Low | Beeper fallback |

Acceptance criteria:
- HAL interface defined (`audio_hal.inc`)
- At least SB16 and General MIDI drivers functional
- All GB APU channels (pulse 1/2, wave, noise) mapped to target sound card

---

## Phase 4: Network Multiplayer

**Goal:** Trade and battle over a network connection, replacing the link cable.

Transport selection (decide during implementation):
- IPX packets (Novell/DOS; works in DOSBox and 86Box)
- Raw serial / null-modem (real hardware via COM port)
- Packet-driver TCP/IP (WATTCP or mTCP)

Acceptance criteria:
- Link cable I/O HAL defined (`serial_hal.inc`) replacing `; TODO-HW: network HAL` stubs
- Pokémon trade verified between two instances
- Link battle verified between two instances

---

## Phase 5: Polish & Save Compatibility

**Goal:** Shippable quality; saves interoperate with the original Game Boy version.

Acceptance criteria:
- Full colorization: all assets processed through `tools/colorize.py`, palette layout finalized
- Fullscreen scaling options: 2× nearest-neighbor (default), integer scale options
- Save file converter: `tools/saveconv.py` — bidirectional GB `.sav` ↔ DOS `.dsv`
  - **Note:** Converter only implemented after DOS save format is stable (end of Phase 5)
  - GB `.sav`: raw 32 KB SRAM dump (MBC5+RAM+BATTERY)
  - DOS `.dsv`: same data + 4-byte header (`DOSV` magic, version byte, 2-byte checksum)
- Packaging: documentation, DOSBox config example, 86Box config example

---

## Phase 6: Glitch Preservation & Sandbox

**Goal:** All known glitches preserved and documented; dangerous glitches safely isolated.

Bug categorization (from `docs/bugs_and_glitches.md`):
- **Critical**: buffer overflows, OOB writes, save corruption, arbitrary code execution paths
- **Cosmetic**: wrong text, minor visual/behavioral differences
- **Intentional glitch**: MissingNo, item duplication, item slot $FF, ACE routes

Acceptance criteria:
- Every bug in `docs/bugs_and_glitches.md` tagged with `; BUG(level):` in the translated source
- `/FIXCRIT` and `/FIXALL` flags produce correct behavior
- Startup warning emitted when running with critical glitches enabled on bare hardware
  (detect via DPMI host ID string, INT 31h fn 0400h)
- `docs/glitch_safety.md` finalized with per-glitch safety notes
- Stretch goal: launcher script that starts 86Box/DOSBox automatically for ACE glitch mode

---

## Deferred / Out of Scope

- SGB (Super Game Boy) functions — not relevant for this port
- Game Boy Printer / Camera accessories
- Virtual Console (VC) patch support
