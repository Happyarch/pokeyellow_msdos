# Current Plan: Battle Front-End (Wave 2)

The keystone milestone: the on-screen battle loop that ties the Wave-1 backend
(damage pipeline, type/category/effect data, `JumpMoveEffect` dispatch, trainer AI,
status residual, EXP/level-up) into a playable wild + trainer battle.

**Scope note (user directive, 2026-06-26):** the front end can't be validated
headless. Validation here is **FRAME.BIN** (`tools/render_frame.py`) + interactive
**DOSBox-X** `DEBUG_BATTLE_*` builds, NOT native ELF32 harnesses. **Every stage is
gated on a manual visual check by the user before moving on.** This plan is
intentionally staged into small, individually-verifiable steps.

**Viewport / placement (user, 2026-06-27):** the port viewport (320×200, 40×25
tiles) differs substantially from the GB (160×144, 20×18), so pret battle-screen
coordinates do NOT map 1:1. **Every on-screen placement (HUD boxes, HP bars, mon
sprites, text box, menus) is a sign-off point:** propose coords → render FRAME.BIN →
iterate with the user. Record the agreed coords as `; PROJ` tags + entries in
`docs/ui_projection.md` (the GB→port UI coordinate registry) so they're reusable and
documented. Expect frequent placement check-ins throughout Stage 1.

**Sequencing:** Wave 1 backend (done) → here → Wave 3 (battle-gated features).

## Wave-1 handoff (foundation in place)
Backend landed + native-validated on `wave1-battle-backend`: `CalculateDamage`/
`AdjustDamageForMoveType`/`MoveHitTest`/`CriticalHitTest`, type/category/effect data,
`JumpMoveEffect` dispatch (`effects.asm`, 14 handlers wired + `UnportedMoveEffect`
stub for the rest), `trainer_ai.asm`/`read_trainer_party.asm`, `residual_damage.asm`,
`GainExperience` math, stat-mod effects, badge boosts, status penalties, building
rage, wild-encounter gen. **All are BATTLE_SRCS check-only** (assemble + validated,
not yet linked) — Wave 2 supplies the UI/text/HUD externs they call and pulls the
whole closure into LINK_SRCS.

## Substrate already available (reuse, don't rebuild)
Text/box: `PrintText`, `PrintText_NoBox`, `PlaceString`, `TextBoxBorder`,
`EnableAutoTextBoxDrawing`, `LoadFontTilePatterns`, `LoadTextBoxTilePatterns`,
**`LoadHpBarAndStatusTilePatterns`**. Sprites: `PrepareOAMData`, `ClearSprites`,
`HideSprites`. Menus: `DisplayPartyMenu`, `DisplayBagMenu` (for PKMN/ITEM in battle).
PPU: software BG + OAM renderer, window layer. Math/data: the full Wave-1 backend.

## Known cross-cutting prerequisites (resolve as encountered, not up front)
- **Bank-switch shims** (`Bankswitch`, `CallBankF`, `BANK_*`, `predef *`): pret
  far-calls. Port convention (CLAUDE.md RST/bank section) = direct `call`. Provide a
  thin shim/`%define` so the many `BANK_x`/`CallBankF` refs resolve to direct calls.
- **`CheckTargetSubstitute`, `CalculateModifiedStats`** — small battle-core helpers
  pulled in by the loop; build alongside Stage 2.
- The `_MoveMon` extraction (bills_pc) and trainer-party data generator
  (`gen_trainer_parties.py` + `AddBCDPredef`) are Wave-1 deferrals; trainer data +
  AddBCDPredef are needed in **Stage 4** (trainer battles), built there.

---

## Stages (each ends at a manual FRAME.BIN / DOSBox-X gate)

### Stage 0 — Battle harness + entry scaffold (infra; no gameplay yet)
- `DEBUG_BATTLE` build hook mirroring `DEBUG_PARTY`/`DEBUG_BAGMENU_LIVE`: seed the
  player party (existing `DEBUG_PARTY` seed) + a fixed wild enemy mon, then jump
  straight into battle init and dump FRAME.BIN. Add to `boot/entry.asm` + Makefile.
- `init_battle_variables.asm` (clear/seed battle WRAM) + a minimal `InitBattle` that
  populates the enemy battle-mon struct from the seeded species/level.
- **GATE:** boots into "battle mode" without crashing; FRAME.BIN renders *something*
  deterministic (even if just a cleared screen + text box).

### Stage 0.5 — Full-screen tilemap renderer (engine prerequisite for widescreen)
**Layout decision (user, 2026-06-27): WIDESCREEN 40×25** — the battle uses the full
320×200 viewport with NEW coords (not pret's GB 20×18). Implication: neither existing
render path fits — `render_window` caps at a 32-tile-wide GB tilemap; `render_bg`
decodes the overworld block surface (`wSurroundingTiles`), not a raw tilemap. So add
`render_screen_tilemap`: blit the 40×25 `W_TILEMAP` directly to `GB_BACKBUF` via the
existing `tile_cache` (2bpp→8bpp), mirroring `render_bg`'s inner loop but from a flat
40-wide map. The frame pipeline renders this instead of the overworld while in battle
(gate on `wIsInBattle` / a render-mode flag). All battle drawing then writes
`W_TILEMAP`; sub-boxes can still use the window overlay. **GATE:** a `DEBUG_BATTLE`
build shows a deterministic 40×25 pattern / cleared battle field in FRAME.BIN.

### Stage 1 (≈glue 2a) — Static battle screen + HUD
**All Stage-1 coords are widescreen (40×25), decided per-placement with the user via
FRAME.BIN and recorded as `; PROJ` / `docs/ui_projection.md` entries.**
- 1a: battle screen frame — `TextBoxBorder` layout, bottom text box, `PrintText`
  "Wild NIDORAN appeared!" style intro. **GATE:** layout approved by user.
- 1b: `DrawEnemyHUDAndHPBar` + `DrawPlayerHUDAndHPBar` — name, `:L`level, HP bar
  (via `LoadHpBarAndStatusTilePatterns`), status; player side shows HP number.
  **GATE:** both HUD boxes + bars at correct coords, correct fill for seeded HP.
- 1c: mon sprites — enemy front pic (top-right) + player back pic (bottom-left).
  **DECIDED (user, 2026-06-27): real pic decompression now** — port `pkmncompress`
  decode + pic loading in this stage (not a placeholder). This is the heaviest
  single sub-step; may split into 1c-i (decoder, validated vs a known pic) and 1c-ii
  (place both pics on screen). `HideSubstituteShowMonAnim`/`ReshowSubstituteAnim` deferred.
- `CheckTargetSubstitute` (small) lands here.

### Stage 2 (≈glue 2b) — Main turn loop (silent: `PlayMoveAnimation` stays a stub)
- 2a: battle menu (FIGHT / PKMN / ITEM / RUN) + move-select submenu (player moves +
  PP) using existing menu primitives. **GATE:** menu navigates, move list correct.
- 2b: one full turn — `MainInBattle` core: read selection, turn ordering (speed
  compare), `ExecutePlayerMove`/`ExecuteEnemyMove` → `GetDamageVars`+`CalculateDamage`
  (Wave 1) → apply HP → `UpdateHPBar` → `JumpMoveEffect` (Wave 1) → faint check →
  `HandlePoisonBurnLeechSeed` (Wave 1). Text: "X used MOVE!", effectiveness, faint.
  **GATE:** a scripted `DEBUG_BATTLE` turn drops HP + prints text in FRAME.BIN.
- 2c: win/lose terminal states (enemy faints → victory; player party faints → lose).
  **GATE:** battle ends cleanly to the overworld/black.

### Stage 3 (≈glue 2c) — Wild battle end-to-end
- Wild `InitBattle` entry (intro text, simple/stubbed transition), RUN flow, victory
  → `GainExperience` (Wave 1) wired with its text/`PrintStatsBox`. Catch flow may
  defer to Wave 3 (item USE) — note as stub.
- **GATE:** a wild battle is playable start→finish in DOSBox-X.

### Stage 4 (≈glue 2c) — Trainer battle end-to-end
- Trainer `InitBattle` (Wave-1 `read_trainer_party` — needs the
  `gen_trainer_parties.py` data tables + `AddBCDPredef`, built here), trainer intro,
  AI turns (Wave-1 `trainer_ai`), multi-mon `EnemySendOut`, `end_of_battle` (prize
  money), defeat text.
- **GATE:** a trainer battle is playable start→finish in DOSBox-X.

### Cross-cut — Audio HAL (glue Wave-2 tail / Phase 3)
`dos_port/include/audio_hal.inc` + a first driver (Tandy/SB16 = 1:1 APU synthesis;
MT-32/GM = build-time pre-rendered MIDI). Disjoint files (`src/audio/*`) → could run
as a **separate agent alongside** Stage 2+, BUT it needs *hardware* verification
(not headless/logic-only), so it does not fit the "sonnet parallel = logic-only"
rule — treat as a serial/owner-verified track. Battles stay **silent** until then.

## Handoff
(empty — fill as stages complete)
