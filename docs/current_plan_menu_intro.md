<!-- deliberated: INTERRUPTED — a turn failed in round 2.
     error: slot 2 (antigravity/Gemini 3.1 Pro (High)) failed: fork/exec /usr/bin/bwrap: argument list too long: 
     This is the last spec completed at an agent handoff; it was NOT validated. -->

<!-- EXECUTION LOG 2026-07-20 — see "Execution notes" at the end of Phase A for
     evidence corrections found while executing A1. -->

# Menu Intro + Full Boot Cinematic

> Active plan: `docs/current_plan_menu_intro.md`  
> Supersedes the rejected `docs/menu_intro_plan.md`.  
> Archive as `docs/plans/menu_intro.md` only after every definition-of-done item passes.

Required project skills: `asm-translation`, `project-conventions`, `build-and-debug`, and `faithfulness-review`.

## Status

- [ ] Phase A — Playable title → menu → new game
  - [x] A1 — Cinematic projection substrate
  - [ ] A2 — Projected title with live audio and palettes
  - [ ] A3 — Real title → menu → entry routing
  - [ ] A4 — Oak speech, naming, and stub retirement
- [ ] Phase B — Power-on movie
  - [ ] B1 — Animated-object engine
  - [ ] B2 — Game Freak splash
  - [ ] B3 — All 18 Yellow intro scenes
  - [ ] B4 — Full boot integration and permanent coverage
- [ ] Whole-chain acceptance
- [ ] Plan archived

## Objective

Implement the complete normal power-on sequence:

```text
Init
  → PlayIntro
    → PlayShootingStar
    → GameFreakIntro
    → PlayIntroScene
  → DisableLCD / ClearVram / GBPalNormal
  → PrepareTitleScreen
  → DisplayTitleScreen
  → MainMenu
  → StartNewGame
  → OakSpeech
  → SpecialEnterMap
  → EnterMapBoot
  → EnterMap
  → overworld
```

Every cinematic screen is an exact 160×144 Game Boy surface centered on the 320×200 DOS canvas. Its projected rectangle begins at canvas tile `(10,3)`, pixel `(80,24)`, and ends exclusively at pixel `(240,168)`.

Backgrounds, OBJ, clipping, scrolling, frame cadence, input, fades, audio commands, palettes, and Pikachu PCM remain faithful to pret except for documented flat-banking, hardware, and projection boundaries. Faithful clipping includes OBJ: a sprite the Game Boy would hide or edge-clip at its 160×144 boundary must be hidden or edge-clipped at the projected boundary, never drawn into the widescreen border. Faithful scrolling includes wrap: BG sampling on the Game Boy wraps modulo 256 pixels in both axes within one 32×32-tile map, and the projected surface must reproduce that wrap, not approximate it with a linear read.

## Presentation boundary

The boot sequence deliberately retains the Game Boy’s 160×144 composition rather than adapting it to the overworld’s 40×25 camera.

The overworld uses widescreen expansion because its camera observes a larger portion of an existing spatial map. Cinematics are authored compositions whose framing, entrances, exits, slide distances, object masks, and screen-edge timing depend on the original 160×144 viewport. Expanding those scenes would either expose artwork and sprite states that pret deliberately hides or require inventing new content and staging. Both would violate fidelity.

The surrounding canvas is a presentation matte:

- Left: 80 pixels.
- Right: 80 pixels.
- Top: 24 pixels.
- Bottom: 32 pixels, due to tile-aligned vertical placement on the 25-row canvas.
- It uses the current cinematic color-zero/whiteout field.
- It participates in whole-screen fades so transitions do not leave a bright static frame around a fading scene.
- It contains no duplicated artwork, overworld residue, decorative replacement art, or OBJ.
- It remains visually quiet except when a palette or fade intentionally changes the cinematic’s color-zero field.

The player experience is therefore a centered, faithful Game Boy cinematic presented as a clean vignette within the DOS display. The matte makes the original framing explicit and prevents widescreen space from revealing otherwise hidden animation state. The game expands naturally to the full widescreen camera only when control reaches the overworld.

## Phase-ordering rationale

Phase A lands before Phase B.

This is the user-selected sequence and the dependency-correct order:

1. Phase A delivers a playable title → menu → new game → overworld chain independently of the movie.
2. Every Phase-B screen consumes the A1 projection, fine-scroll, OAM-publication, and clipping substrate.
3. A2’s title eyes and A1’s clipping and wrap markers provide a small proving ground before OBJ-heavy scenes compound projection and animation risks.
4. B1’s animated-object engine is the largest unknown. It must delay only the movie, not basic playability.

Until B4, a normal Phase-A build starts at `PrepareTitleScreen`. It must not add a fake, partial, or stubbed intro.

## Scope

### Included

- `PlayShootingStar` and the Game Freak splash.
- `PlayIntroScene` and all 18 Yellow intro scenes.
- The shared animated-object engine required by the Yellow intro.
- Title projection, eye OBJ publication, audio, palettes, and real menu routing.
- Oak’s introductory speech, picture transitions, player naming, and rival naming.
- New-game and continue handoffs through `SpecialEnterMap`.
- Cinematic OBJ viewport clipping that reproduces GB screen-edge hiding.
- Cinematic fine source scrolling on both axes with GB mod-256 wrap semantics.
- Deterministic static, state, visual, timing, and execution evidence.
- Removal of stale title-era audio, palette, PCM, and OAM comments.

### Excluded

- `credits.asm`.
- `hall_of_fame.asm`.
- `trade.asm` and `trade2.asm`.
- `evolution.asm`.
- The surfing minigame itself. Only its shared animated-object foundation is included.
- Rewriting the existing title or main-menu state machines for style.
- Creating a partial generic predef dispatcher solely for `PlayIntro`.
- Implementing `PlayCry`.

`PlayCry` remains the sole accepted audio gap. Unlike the other cinematic audio calls, it is not a live service this work merely needs to invoke. It is a cross-cutting per-species cry engine used by battles, the Pokédex, menus, and the overworld. Building it here would introduce battle-scale audio work to serve one silent beat in `OakSpeechText2`. It remains separately tracked so one eventual implementation serves every caller.

All other cinematic audio must use the live `PlaySound`, `PlayMusic`, `StopAllMusic`, `WaitForSoundToFinish`, fade, and PCM implementations.

## Evidence baseline

Repository and generated state must be rechecked immediately before each stage. At the planning baseline on 2026-07-17:

| Capability | Repository evidence | Consequence |
|---|---|---|
| Title | `dos_port/src/movie/title.asm` contains the title label set and state machine | Modify projection and live-service wiring; do not replace the state machine |
| Main menu | `dos_port/src/engine/menus/main_menu.asm` is linked and already uses the `UI_*`, mirror, and compositor projection pattern | Route the title to it; do not create another menu |
| `OakSpeech` | `project_state OakSpeech` reports a linked stub in `main_menu_stubs.asm` | Delete that definition when the real path-mirrored body is linked |
| `InitPlayerData2` | A linked provider already exists and is called by the current Oak stub | Preserve that provider unless current generated evidence shows it must itself be translated or relocated |
| `CopyUncompressedPicToTilemap` | `project_state` reports `missing` | Verify and port an exact-label implementation during A4 |
| Intro routines | `PlayIntro`, `PlayIntroScene`, `PlayShootingStar`, and `SpawnAnimatedObject` report `missing` | Port them without replacement stubs |
| Audio | `PlaySound`, `PlayMusic`, `StopAllMusic`, `WaitForSoundToFinish`, and `PlayPikachuSoundClip` are linked | Call the real implementations |
| Palettes | `RunPaletteCommand`, `SetPal_TitleScreen`, `SetPal_GameFreakIntro`, and `SetPal_NidorinoIntro` are linked | Use the real palette-command path |
| `PlayCry` | `project_state PlayCry` reports a linked ret-stub in `home_stubs.asm` | Oak’s cry command may remain silent; no other cinematic audio may be stubbed |
| OBJ renderer | `render_sprites` clips OBJ to the 320×200 canvas only | A1 must add the default-pass-through cinematic clip rectangle |
| Main-menu harness | `RunMainMenuTest` and `DEBUG_MAINMENU` exist, but no active `main_menu` scenario is registered | Register it in A3 |
| `smoke_title` | Its Lua navigation stops only after `NEW GAME` appears | It is main-menu evidence, not title-screen evidence |
| Disabled `oak_intro` | It navigates to the Pallet Town Oak overworld event and declares Pallet script must-hits | Rewrite it before activation; it does not currently validate `OakSpeech` |
| Cinematic scroll usage | Pret’s title scrolls `hSCY` (with overshoot entries such as the `-3` crash step); Yellow-intro scenes scroll BG content (clouds, flying bars) | A1 must provide fine source offsets on **both** axes with wrap; A2 and B3 must extract the exact per-frame `hSCY`/`hSCX` sequences from pret/mGBA before implementing their presentation |

Negative and positive claims must be regenerated with `project_state`, `label_status`, generated analysis, or runtime evidence. Comments and this plan do not override newer repository state.

## Timing-fidelity contract

“Timing remains faithful to pret” means that, under the same deterministic input schedule, the port produces the same ordered sequence of game-visible frame events as the reference ROM.

The unit of comparison is the Game Boy frame boundary represented by the corresponding `DelayFrame` or wait-loop iteration. Host wall-clock scheduling, DOSBox presentation jitter, sound-device buffering, and time spent paused waiting for unscripted user input are not part of the comparison.

For each stage, extract an mGBA reference timing trace and compare it record by record with a DOS trace.

Register-level traces are necessary but not sufficient for scrolled content: a trace logs the scroll value the game code *wrote*, which matches ground truth even if the renderer ignores it. Scroll rendering therefore has its own pixel-evidence rule (see “Scroll-render pixel evidence”).

### Common timing record

Each emitted frame record contains, where applicable:

```text
stage id
routine or scene id
frame ordinal within the stage
input state consumed on that frame
H_SCX / H_SCY / H_WY / IO_WX
WIN_SRC_X / WIN_SRC_Y as presented
active OAM count
stage-specific object position or state
palette command issued
music/SFX/PCM command issued
fade step
text-engine state
```

Only fields relevant to a stage need values, but the record schema and omission rules are fixed before golden generation.

### Splash timing

The splash trace must compare:

- Frames from `PlayShootingStar` entry to exit.
- Shooting-star OAM X/Y on every rendered frame.
- Small-star positions and valid count.
- Logo appearance frame.
- `SFX_SHOOTING_STAR` dispatch frame.
- Game Freak palette-command frame.
- Skip-input sampling frames.
- Cleanup and handoff frame.

### Title timing

The title trace must compare:

- Every `TitleScreenYScrolls` value consumed.
- The frame on which crash and whoosh SFX dispatch.
- `H_SCY` and `WIN_SRC_Y` for every bounce frame.
- Reveal PCM start and completion boundary.
- Title-music start.
- Eye animation state and tile IDs for a complete blink cycle.
- Input polling frames.
- Timeout frame and reset handoff.
- Exit PCM, fade, and handoff frames.

### Oak timing

The Oak trace must compare:

- Fade-step count and palette sequence.
- Frame count for every picture slide.
- Picture X position at every slide frame.
- Text-character reveal cadence.
- Page-complete and input-wait boundaries.
- Naming-screen entry and exit boundaries.
- Shrink SFX and music handoff frames.
- Final handoff to `SpecialEnterMap`.

User dwell time at a text or naming prompt is excluded by injecting input on a fixed reference frame. The number and ordering of active animation frames before and after that injected input remain compared.

### Yellow-intro timing

B3 compares the continuous scene trace record by record, including:

- Scene entries.
- Scene timers.
- Active-object masks.
- Object state.
- `H_SCX`/`H_SCY` per frame for scrolling scenes.
- Palette commands.
- Music and SFX requests.
- Skip-input sampling and handoff.

### PCM and audio waits

Timing fidelity for PCM and sound waits is defined at the game-engine boundary:

- The command must be issued on the same logical frame as pret.
- Blocking and completion must occur in the same order relative to fades, input, and subsequent commands.
- Backend buffer latency and analog output duration are outside cinematic timing evidence.
- Any intentional difference caused by the DOS audio gateway requires a structured timing or HAL deviation and a measured replacement contract.

Aggregate frame totals are insufficient. The traces must be compared record by record so opposing timing errors cannot cancel.

## Boot-route requirements

### Phase-A normal build

```text
Init
  → PrepareTitleScreen
  → DisplayTitleScreen
  → MainMenu
```

Routes:

```text
NEW GAME → StartNewGame → OakSpeech → SpecialEnterMap → EnterMapBoot
CONTINUE → SpecialEnterMap → EnterMapBoot
OPTION → existing option-menu behavior
B from MainMenu → DisplayTitleScreen
```

Returning from the menu to `DisplayTitleScreen` rather than replaying the splash is required because menu cancellation remains inside the title/menu loop. `DisplayTitleScreen` is pret’s designed re-entry point and reloads its graphics, tilemaps, palettes, and presentation state. The port must not assume title VRAM survives the menu.

The `title_reentry` scenario exercises this route.

### Timeout and reset behavior

A title timeout and a soft reset replay the complete power-on movie because both cross the reset boundary and return to `Init`; they are not menu cancellation.

This behavior is required for three reasons:

1. Pret’s control flow distinguishes a reset/timeout return to `Init` from B-cancel’s direct return to `DisplayTitleScreen`.
2. The title timeout acts as an idle attract-loop restart. Replaying the movie restores the complete unattended boot presentation rather than looping only the final title screen.
3. Re-entering `Init` reestablishes LCD, VRAM, palette, audio, callback, and OAM ownership from a known state. Skipping the movie while still claiming reset semantics would create a DOS-only route with different visible behavior.

The `title_timeout` route trace must prove:

```text
DisplayTitleScreen timeout
  → Init
  → PlayIntro
  → splash
  → Yellow intro
  → PrepareTitleScreen
```

The `soft_reset` route must prove the same sequence. If repository or mGBA evidence shows a particular reset combination targets a different pret label, the port follows that exact route rather than forcing every reset-like input through `Init`.

### Phase-B normal build

`Init` invokes `PlayIntro` before the existing LCD/VRAM reset and title handoff.

### `SKIP_TITLE=1`

`SKIP_TITLE` is a deterministic test bypass:

```text
Init
  → InitPlayerData2
  → EnterMapBoot
  → EnterMap
```

It bypasses the splash, Yellow intro, title, main menu, Oak cutscene, and naming screens.

The invariant is “reach a valid overworld state without input.” Interactive naming and menu stages would block headless tests.

`InitPlayerData2` provides structurally valid default names and new-game data. Map and spawn initialization is not added here because it is not missing: the current `SKIP_TITLE` route — whose `OakSpeech` stub already reduces to exactly `InitPlayerData2 → EnterMapBoot` — demonstrably boots into a fully drawn, valid Pallet Town today, which is runtime evidence that the existing `EnterMapBoot` contract owns the first-map spawn. Codifying the direct call changes routing, not behavior. Shared initialization beyond `InitPlayerData2` is limited to that existing `EnterMapBoot` contract:

- Build-default player/rival names used when title seeding is absent.
- `text_engine_init`.
- Existing port-resource setup required before the first map.

Harness-specific party, bag, map, event, or inventory state belongs in that harness’s `DEBUG_*` entry gate in `home/init.asm`.

Once real `OakSpeech` lands, `Init` must not call it under `SKIP_TITLE`.

## Projection architecture

### Layout source

Create:

- `dos_port/assets/ui_layout_intro_sidecar.json`
- `dos_port/assets/ui_layout_intro.inc`, generated by `tools/generators/gen_ui_layout.py intro`

Add four separate 20×18 elements:

- `UI_TITLE`
- `UI_OAK_SPEECH`
- `UI_SPLASH`
- `UI_YELLOW_INTRO`

Required values:

```text
GBX=0
GBY=0
GBW=20
GBH=18
COL=10
ROW=3
WX=87
WY=24
CLIP=160
MAXY=168
```

`WX=87` yields screen X `87−7=80`. `MAXY` is the absolute exclusive coordinate `24+144=168`.

Consumers use:

```nasm
%define UI_LAYOUT_EQUATES_ONLY 1
%include "assets/ui_layout_intro.inc"
```

Generated `.inc` files are never edited directly.

### Stable cinematic surface

For a stable frame:

1. Clear the 40×25 `W_TILEMAP`.
2. Draw original 20×18 content at generated `COL,ROW`.
3. Mirror that rectangle into rows `0..17`, columns `0..19` of a 32-stride GB tilemap.
4. Set `g_bg_whiteout=1`.
5. Publish one window descriptor with generated `WX`, `WY`, `CLIP`, and `MAXY`.
6. Set `g_obj_over_window=1` when the screen owns OBJ.
7. Set the OBJ clip rectangle to the projected surface.
8. Clear the callback, descriptor, whiteout, OBJ ownership, and clip rectangle on exit.

A shared port-only `src/engine/movie/movie_projection.asm` owns the stride-40-to-stride-32 mirror, matte publication, and stable full-screen takeover.

### Fine source scrolling — `WIN_SRC_X` / `WIN_SRC_Y` with GB wrap semantics

Cinematic content scrolls the BG on both axes. The title scrolls `hSCY` one pixel at a time, including overshoot entries (the `-3` crash step) whose unsigned byte values wrap. Yellow-intro scenes scroll BG content horizontally per frame (clouds, flying bars) via `hSCX`. Whole-tile remirroring would quantize this motion, and moving the destination rectangle would expose content outside the surface. The window descriptor is therefore extended with **two** default-zero fine source offsets, one per axis, landed together in A1 so no later stage discovers a missing axis mid-implementation.

The GB PPU samples the BG map modulo 256 pixels in both axes **within one 32×32-tile map**; it never walks past the map boundary into the adjacent map. A linear source read is not equivalent: linear continuation past the map boundary reads bytes (the next tilemap, cleared VRAM) that differ from the wrap target, which is the *same map’s* row/column 0. The projected sampling must reproduce the hardware wrap exactly:

```text
src_y      = (WIN_SRC_Y + (screen_y - WIN_WY))  & 255
src_x      = (WIN_SRC_X + (screen_x - WIN_X0))  & 255
source tile = SRC_MAP[(src_y / 8) & 31][(src_x / 8) & 31]
tile_line  = src_y & 7
tile_col   = src_x & 7
```

`SRC_MAP` is the single 32-stride GB tilemap the descriptor names (`GB_TILEMAP0` for cinematic surfaces). Because the offsets are masked, every source address is valid by construction; there is no “out-of-range source line” case. The earlier draft’s in-populated-region debug assertion is **removed**: it validated the wrong property (it would have blessed a blank linear read of cleared VRAM as “in range” on exactly the wrapped frames where the GB shows real content). Correctness of wrapped sampling is established by pixel evidence, below, not by an address-range check.

**Correction of a prior claim.** The earlier draft asserted that during the bounce the sampled region continues linearly from `GB_TILEMAP0` into `GB_TILEMAP1` and called that “exactly pret’s two-copy layout.” That was wrong. Pret’s row-24 copy does write contiguous VRAM crossing into the second tilemap — and the port’s `TitleScreenCopyTileMapToVRAM` must still perform that byte-exact contiguous copy so canonical VRAM matches for GBSTATE comparison — but the GB PPU never samples those overflow bytes for BG display: sampling wraps within the selected map. The port renders through the mod-32 wrap and treats the `GB_TILEMAP1` overflow bytes as canonical-but-unsampled, matching hardware.

Requirements:

- `set_single_window` and `add_window` initialize `WIN_SRC_X=0` and `WIN_SRC_Y=0`.
- Existing callers retain their current API and pixel output; with both offsets zero and the window narrower than the map, the masked formulas degenerate to the current behavior.
- `movie_projection` provides one shared scroll helper that presents `H_SCY → WIN_SRC_Y` and `H_SCX → WIN_SRC_X` as raw unsigned bytes; screens do not hand-roll the transfer.
- Destination clipping remains `UI_*_WY..UI_*_MAXY` and the `CLIP` width; fine offsets move the source, never the projected rectangle.
- `TitleScreenCopyTileMapToVRAM` performs the projected 20×18 physical copy; its row-24 destination copies contiguously across the map boundary for byte fidelity.
- After restoring the logo-plus-Pikachu buffer, copy it to source row zero and reset `WIN_SRC_Y`.

This shared compositor change is required because pret’s scroll behavior is explicitly retained by the fixed target and the current full-screen window interface cannot express it. It is deliberately two symmetric default-zero fields rather than a title-specific renderer; its blast radius is bounded by zero-initialization of all existing descriptors plus every existing window golden, `fidelity-full`, and the A1 performance contract. Any unexplained existing-screen difference blocks A1.

### Scroll-render pixel evidence

A timing trace logs the scroll values the game code wrote; those match mGBA even if the renderer ignores or mis-samples them. Therefore, for every stage whose trace contains a changing `H_SCX` or `H_SCY`:

- Retain host `FRAME.BIN` captures at defined scroll offsets, compared against mGBA rendered frames through the projection coordinate transform in `golden_diff.py`.
- The capture set must include at least one **wrapped** offset whenever the stage’s scroll sequence wraps (unsigned value crosses the 0/255 boundary), because wrapped frames are exactly where linear and modular sampling diverge.
- The capture set must include at least two distinct offsets per scrolling axis, so a renderer that ignores the offset entirely (static content) cannot pass.

Concretely: A2 captures mid-bounce frames including every overshoot entry of `TitleScreenYScrolls` (the `-3` crash frame mandatorily); B3 captures two-plus offsets for each `H_SCX`-scrolling scene. The A1 harness proves the mechanism synthetically before any real content depends on it.

### Live mirrors

`menu_redraw_cb` is invoked by generic menu-input loops, not by `DelayFrame`.

Cinematic code must:

- Mirror after every tilemap mutation and before the next frame.
- Republish OAM after every OAM mutation and before the next frame.
- Set `menu_redraw_cb` only for an existing generic menu-input loop that requires it.
- Clear callbacks it owns before returning.

No automatic mirror may overwrite the title’s physical tilemap copies.

### Cinematic OBJ viewport clipping

Add:

```text
g_obj_clip = (x0, y0, x1, y1)
```

Upper bounds are exclusive.

Requirements:

- Default: `(0,0,320,200)`.
- `render_sprites` clips every pixel against this rectangle and the canvas.
- Default behavior is pixel-identical to the current renderer.
- Cinematic entry sets `(80,24,240,168)`.
- Cinematic exit restores the full canvas.
- `ClearSprites` does not modify it.

The full-canvas default is deliberate: it is the semantic identity, invisible to every screen that predates the feature, and it follows the proven `g_obj_over_window` ownership model — only code needing non-default behavior sets, owns, and restores it. A leaked narrow rectangle is caught immediately because the next overworld frame visibly clips its sprites and the existing overworld goldens fail.

Renderer clipping, rather than publisher culling, is required to preserve partial edge clipping and canonical OAM. A GB sprite straddling the screen edge shows exactly its on-screen pixels shifted by the anchor; a GB-hidden sprite (`OAM_Y=0`, `OAM_Y≥160`, `OAM_X=0`, `OAM_X≥168`) falls entirely outside the rectangle and produces no pixels.

### Projected OAM API

Add port-only `PublishProjectedOAM` beside `PrepareStaticOAM`.

Inputs:

```text
ESI = GB-relative source of canonical Y,X,tile,attr records
ECX = valid entry count, 0..40
EAX = projection X offset
EBX = projection Y offset
EBP = emulated GB memory base
```

Behavior:

1. Copy all 160 canonical bytes to `GB_OAM`.
2. Preserve raw Y/X values, including off-screen records.
3. Publish:

   ```text
   spr_dos_sx[n] = unsigned(OAM_X) - 8  + projection_x
   spr_dos_sy[n] = unsigned(OAM_Y) - 16 + projection_y
   ```

4. Set `spr_oam_valid=ECX`.
5. Do not render records beyond `ECX`.
6. Perform no visibility culling.
7. Leave clip and z-order state under screen ownership.
8. Honor a documented register-preservation contract.

All cinematic surfaces use offsets `(80,24)`.

The title eyes are the mandatory first acceptance case because they isolate the helper from both later animation systems: eight fixed canonical records, unambiguous BG anchor, blink changes tiles without moving. Because the eyes never leave the screen, the A1 hidden and edge-straddling markers are the separately mandatory clipping acceptance; both must pass before B1 or B2 begins.

## Cinematic state ownership

Each cinematic screen owns and restores:

- Window descriptors.
- `g_bg_whiteout`.
- `g_obj_over_window`.
- `g_obj_clip`.
- `WIN_SRC_X` / `WIN_SRC_Y` on its descriptor.
- Its redraw callback.
- `spr_oam_valid` and published OAM.
- `H_SCX`, `H_SCY`, `H_WY`, and `IO_WX`.
- `W_UPDATE_SPRITES_ENABLED` while bespoke OAM is active.

Cinematic entry parks the overworld OAM rebuild path. Exit clears cinematic OAM and establishes the next owner’s state.

Ownership spans embedded screens: when a cinematic invokes an interactive screen mid-flow (Oak calling `DisplayNamingScreen`), the cinematic re-establishes its full surface state on return, via its faithful post-return redraw routed through `movie_projection`. Pret’s own flow performs a complete redraw after naming, so this is the faithful call sequence, not an addition; it is stated here so the re-entry is an explicit obligation rather than an inference, and it is gated by the A4 acceptance that the rival picture — which only appears after naming — occupies the centered surface.

## Audio and palette rules

- Preserve each pret routine’s register contract.
- `RunPaletteCommand` receives its command in `BH`.
- `PlayPikachuSoundClip` receives its clip index in `DL`.
- Use `RunPaletteCommand` where pret calls the dispatcher.
- Use live `PlaySound`, `PlayMusic`, `StopAllMusic`, `WaitForSoundToFinish`, fades, and PCM.
- `PlayCry` is the sole accepted silent call.
- `/NOSOUND` and initialization failure use the audio gateway’s existing behavior; cinematic code adds no second fallback.
- Golden scenarios capture palette state and audio-command logs alongside GBSTATE. Command logs and native register state are the durable deterministic boundary because host waveform capture is backend- and environment-dependent; the smoke test separately verifies audible output.
- Boot evidence must prove the real engine was invoked and advanced. Separate auditioning is supplementary.

## `EnterMapBoot` boundary

Intended routes:

```text
NEW GAME → OakSpeech → SpecialEnterMap → EnterMapBoot
CONTINUE → SpecialEnterMap → EnterMapBoot
SKIP_TITLE → EnterMapBoot
```

A3 measures callers, hit counts, and loaded-state effects. If each route hits once and loaded state remains intact, no split or guard is added.

If evidence shows duplicate execution or overwritten continue state, A3 makes only the smallest correction:

- Remove the duplicate route or guard duplicated host setup.
- Separate only writes proven to be new-game-only.
- Preserve unrelated overworld initialization.

This seam belongs here because routing the title through `MainMenu` activates the continue/new-game handoff for normal boot. Broader cleanup requires a separate plan with overworld-scale evidence: `EnterMapBoot` is shared boot glue whose regression surface this plan’s goldens cannot detect.

## Predef boundary

B4 lowers pret’s `predef PlayIntro` to a direct call to exact label `PlayIntro`, matching the DOS port’s existing flat-banking model.

Requirements:

- One linked non-stub provider.
- A linked `Init → PlayIntro` edge.
- Translated and linked state in generated reports.
- A structured banking annotation on `Init`.
- `faithdiff Init` documenting the boundary.

A partial predef table or specialized fake dispatcher is prohibited.

## Phase A — Menu-intro core

### A1 — Cinematic projection substrate

#### Work

- [x] Add the `intro` UI-layout sidecar and generator target. *(2026-07-20:
      `assets/ui_layout_intro_sidecar.json`, anchor `center/center` → the plan's
      exact COL=10 ROW=3 WX=87 WY=24 CLIP=160 MAXY=168.)*
- [x] Generate all four `UI_*` blocks. *(`assets/ui_layout_intro.inc`, idempotent.)*
- [x] Add Makefile rules and consumer dependencies. *(Generator rule + `assets`
      target entry; consumer `.o` prerequisites land with A1.4's consumer.)*
- [x] Add the cinematic mirror/window/matte helper. *(`src/engine/movie/movie_projection.asm`:
      `MovieBeginSurface`, `MovieEndSurface`, `MovieMirrorSurface`, `MovieSyncScroll`.
      Geometry from the generated `UI_*` equates, never literals. Assembles;
      **not yet in the link list** — it links with A1.6, its first consumer.)*
- [x] Add `WIN_SRC_X` and `WIN_SRC_Y` with zero defaults and mod-256/mod-32 wrap sampling.
      *(Descriptor grew to `WIN_DESC_SIZE` 32. At 0/0 `render_window` takes its
      ORIGINAL unwrapped path, so pre-existing screens are pixel- and
      cost-identical by construction — still gated on goldens + the after-capture.)*
- [x] Add the shared `H_SCX/H_SCY → WIN_SRC_X/Y` scroll helper in `movie_projection`.
      *(`MovieSyncScroll`, raw unsigned byte transfer.)*
- [x] Add `g_obj_clip` with full-canvas default. *(4 dwords in `ppu.asm`,
      default `(0,0,RENDER_W,RENDER_H)`. Vertical clip once per ROW; horizontal
      via a separate `SPR_COL_CLIP` unrolled variant reached only when the X
      bounds are non-default, so the default per-pixel sequence is unchanged.
      `ClearSprites` deliberately does not reset it.)*
- [x] Add `PublishProjectedOAM`. *(`src/engine/gfx/sprite_oam.asm`, beside
      `PrepareStaticOAM`. Copies all 160 canonical bytes, publishes
      `spr_dos_sx/sy` at the projection offset, no visibility culling, all
      registers preserved.)*
- [x] Add BG and OBJ corner markers.
- [x] Add hidden markers at `OAM_Y=0`, `OAM_Y=160`, `OAM_X=0`, and `OAM_X=168`.
- [x] Add edge-straddling markers for all four edges.
- [x] Add fine-scroll coverage for offsets `0..7` on **both** axes.
- [x] Add wrap coverage on both axes: offsets near 255 (e.g. `252..255`) with distinct marker content at the source map’s row 0 / column 0, proving wrapped samples come from the same map’s origin, not from the adjacent tilemap or cleared VRAM. *(Poison fill in `GB_TILEMAP1` is the discriminator; 0 poison px across all 23 frames.)*
- [x] Capture a before-change performance baseline. *(See "Execution notes —
      A1.0" below: required extending the profiler first.)*
- [x] Document projection, clipping, and wrap sampling in `docs/ui_projection.md`.

#### Performance contract

A1 changes the compositor and sprite renderer, the two standing full-frame hot paths. The protected commitment is that the port continues to render the existing 320×200 presentation within its frame deadline on the established DOSBox-X performance configuration.

“No newly missed frame budget” means:

- Use the same build, DOSBox-X configuration, host power profile, scenario inputs, and captured frame interval before and after the change.
- Record decomposed frame count, deadline-miss count, maximum render time, and available percentile data for BG/window and sprite work separately.
- Run each capture five times and compare the median run to reduce host scheduling noise.
- Both the baseline and changed build must have zero deadline misses in the selected steady-state interval.
- The changed build must not introduce a new miss in any run.
- Median and 95th-percentile render costs must remain within 5% of baseline unless the absolute increase is below the profiler’s measurement resolution.
- An aggregate total is not sufficient; window and sprite costs must be reported separately.

The unchanged projected menu exercises the descriptor and window path. The sprite-heavy overworld scenario exercises the default clip rectangle and hottest OBJ loop. They do not substitute for functional goldens.

#### Acceptance

- GB tile `(0,0)` appears at `(10,3)`.
- GB tile `(19,17)` appears at `(29,20)`.
- A GB OBJ at screen pixel `(0,0)` appears at DOS pixel `(80,24)`.
- BG and OBJ are clipped to `x=80..239`, `y=24..167`.
- Every hidden marker produces zero pixels.
- Every edge-straddling marker is clipped per pixel.
- Source offsets `1..7` move pixels without tile quantization, on both axes.
- Wrapped offsets sample the same map’s origin content — the wrap markers render, and no blank or adjacent-map content appears.
- The matte contains only the intended color-zero/whiteout field.
- `WIN_SRC_X=0`, `WIN_SRC_Y=0`, and default `g_obj_clip` are pixel-identical for pre-existing screens.
- Existing window, sprite, menu, dialog, battle, and overworld goldens pass.
- `fidelity-full` passes.
- The decomposed performance contract passes.

### A2 — Projected title with live services

#### Deterministic title checkpoint

The title is continuously animated, so “stable” means stable composition, not permanently motionless execution.

The `title` scenario stops immediately after a defined `DelayFrame` satisfying all of these conditions:

- The initial bounce sequence has completed.
- `H_SCY=0` and `WIN_SRC_Y=0`.
- The restored logo-plus-Pikachu tilemap is installed at source row zero.
- The centered window and matte are published.
- The title palette is active.
- `MUSIC_TITLE_SCREEN` has been dispatched.
- Eye OAM is published in the open-eye state at the first fixed frame of a blink cycle.
- No START/A input has been consumed.

This frame is the correct visual golden because it contains the complete final composition without conflating evidence with an arbitrary mid-bounce offset. Motion fidelity is established separately: the timing trace compares the full bounce and blink register sequence, and the mid-bounce pixel captures (below) compare the rendered wrapped frames. `title_reentry` captures the same checkpoint after B-cancel from `MainMenu`.

#### Work

- [ ] Extract the actual `TitleScreenYScrolls` values and the per-frame mGBA `hSCY` sequence before implementing presentation.
- [ ] Preserve the existing state machine and pret labels.
- [ ] Replace raw destinations with `UI_TITLE`.
- [ ] Make `TitleScreenCopyTileMapToVRAM` perform the projected physical copy, byte-contiguous across the map boundary for canonical VRAM fidelity.
- [ ] Present the bounce through the shared scroll helper (`WIN_SRC_Y = H_SCY`, wrap semantics from A1).
- [ ] Restore the final title frame to source row zero and reset `WIN_SRC_Y`.
- [ ] Mirror speech-bubble mutation before its next frame.
- [ ] Route title-eye data through `PublishProjectedOAM`.
- [ ] Republish eye tile changes.
- [ ] Own and restore `g_obj_over_window`, `g_obj_clip`, and the descriptor’s source offsets.
- [ ] Apply `SET_PAL_TITLE_SCREEN` through `RunPaletteCommand`.
- [ ] Wire crash and whoosh SFX.
- [ ] Play both Pikachu PCM beats.
- [ ] Wait, stop, start, and fade at pret’s call points.
- [ ] Remove stale hardware comments.
- [ ] Generate and compare the title timing trace.
- [ ] Capture mid-bounce `FRAME.BIN` frames at each distinct `TitleScreenYScrolls` step, mandatorily including every overshoot/wrap entry (the `-3` crash frame), and diff them against mGBA rendered frames through the projection transform.
- [ ] Register `title_timeout`.

#### Acceptance

- Bounce and blink timing traces match mGBA record by record.
- Mid-bounce pixel captures match mGBA rendered frames through the projection transform, including every wrapped/overshoot frame.
- The stable title checkpoint meets every condition above.
- The centered surface begins at `(80,24)`.
- Eyes align and visibly animate through open, half, and closed states.
- Canonical OAM matches pret.
- The title palette is live.
- Crash, whoosh, PCM, title music, timeout stop, and fade calls are observed.
- `/NOSOUND` remains safe.
- Timeout returns through `Init` and replays the complete movie once B4 is active.

### A3 — Real title → main-menu routing

#### Work

- [ ] Replace the title’s `OakSpeech → EnterMapBoot` shortcut with `jmp MainMenu`.
- [ ] Remove obsolete title externs.
- [ ] Preserve the reset-save branch.
- [ ] Change `SKIP_TITLE` to call `InitPlayerData2`.
- [ ] Keep harness seeding outside shared boot code.
- [ ] Measure `EnterMapBoot` callers, hit counts, and continue-state writes.
- [ ] Make only the correction proven necessary.
- [ ] Verify continue and new-game separately.
- [ ] Register `RunMainMenuTest` as `main_menu`.
- [ ] Add `title_reentry`.
- [ ] Add `continue_seed`.

#### Golden correction

The current `smoke_title` stops after `NEW GAME` appears and is therefore main-menu evidence. Migrate its navigation and regenerate it as `main_menu`.

The new `title` scenario uses A2’s deterministic stable-composition checkpoint. Renaming existing artifacts without changing navigation is prohibited.

#### Acceptance

- A/START reaches `MainMenu`.
- B returns directly to `DisplayTitleScreen`.
- `title_reentry` matches the defined title checkpoint, proving no leaked `g_obj_clip`, `g_bg_whiteout`, source-offset, OAM, or callback state.
- `NEW GAME` reaches the Oak provider once.
- `CONTINUE` calls neither `OakSpeech` nor `InitPlayerData2`.
- `SKIP_TITLE=1` reaches the overworld without input.
- Each route hits `EnterMapBoot` according to the measured contract.
- `continue_seed` proves loaded state is preserved.
- `main_menu` passes.

### A4 — Oak speech, naming, and stub retirement

#### Files

- `dos_port/src/engine/movie/oak_speech/oak_speech.asm`
- `dos_port/src/engine/movie/oak_speech/oak_speech2.asm`
- `dos_port/src/engine/menus/main_menu_stubs.asm`
- The current linked provider file for `InitPlayerData2`
- `dos_port/src/home/pics.asm`
- `dos_port/tools/generators/gen_oak_speech_strings.py`
- `dos_port/assets/oak_speech_strings.inc`
- `dos_port/Makefile`

#### `InitPlayerData2` ownership

This stage does not create an otherwise empty `oak_speech/init_player_data.asm`.

`InitPlayerData2` already has a linked provider. A4 calls that exact provider from real `OakSpeech`, matching pret. Before editing it, A4 checks its generated provider state, pret location, caller set, and faithdiff.

- If it is already a faithful non-stub provider, it remains where it is and is only listed as a dependency.
- If its body must be translated or its current location violates path-mirroring, move the complete exact-label provider to `src/engine/movie/oak_speech/init_player_data.asm` in the same commit that removes the old definition.
- Never create an empty module, duplicate provider, forwarding stub, or second `global InitPlayerData2`.
- If relocation occurs, that file owns the pret routines and data from pret’s `engine/movie/oak_speech/init_player_data.asm`, including `InitPlayerData1`, `InitPlayerData2`, and their exact associated labels. It does not become a bucket for DOS debug defaults or `EnterMapBoot` setup.

#### Required labels

`oak_speech.asm`:

- `PrepareOakSpeech`
- `OakSpeech`
- `FadeInIntroPic`
- `IntroFadePalettes`
- `MovePicLeft`
- `DisplayPicCenteredOrUpperRight`
- `IntroDisplayPicCenteredOrUpperRight`
- Associated pret text wrappers and data labels

`oak_speech2.asm`:

- `ChoosePlayerName`
- `ChooseRivalName`
- `OakSpeechSlidePicLeft`
- `OakSpeechSlidePicRight`
- `OakSpeechSlidePicCommon`
- `DisplayIntroNameTextBox`
- `GetDefaultName`
- Associated pret table and target labels

#### Work

- [ ] Run `label_status --callees` for every translated entry.
- [ ] Verify `InitPlayerData2` ownership and fidelity.
- [ ] Port routines in pret order.
- [ ] Keep the `InitPlayerData2` call inside `OakSpeech`.
- [ ] Generate all Oak speech and naming text.
- [ ] Encode controls through named generator constants.
- [ ] Use existing `DisplayNamingScreen`.
- [ ] Re-establish the full `UI_OAK_SPEECH` surface state on return from each naming screen, through pret’s own post-naming redraw routed via `movie_projection`.
- [ ] Project pictures, text, and slide endpoints through `UI_OAK_SPEECH`.
- [ ] Preserve slide distances and cadence; if slide presentation uses fine scroll, present it through the A1 source-offset helper.
- [ ] Clip slides to the projected surface.
- [ ] Use real fades, music, and SFX.
- [ ] Permit only `PlayCry` silence.
- [ ] Port or reconcile `CopyUncompressedPicToTilemap`.
- [ ] Verify register, tile-order, flip, and flag contracts before reusing nearby helpers.
- [ ] Invalidate the tile cache for all picture tile writes.
- [ ] Migrate hand-encoded boot names into generated data.
- [ ] Generate and compare the Oak timing trace.
- [ ] Delete the `OakSpeech` stub and its annotation.
- [ ] Repoint extern comments.
- [ ] Confirm one linked non-stub provider per required label.

#### `oak_intro` correction

Retain scenario id 21 but rewrite it:

```text
power-on → title → main menu → NEW GAME
  → first fully faded Oak picture
  → completed first text page
  → waiting for deterministic input
```

Requirements:

- Class: `default`.
- Regions: tilemap, VRAM, OAM, and WRAM.
- Must-hits: `OakSpeech`, `PrepareOakSpeech`, `FadeInIntroPic`, and `DisplayPicCenteredOrUpperRight`.
- Remove Pallet Town event-script must-hits.
- Enable only after deterministic golden generation succeeds.

Add `new_game_seed` immediately before `SpecialEnterMap` if relevant initialization occurs after the visual checkpoint.

#### Acceptance

- Oak, Nidorino, player, and rival pictures occupy the centered surface — the rival picture appearing after naming is the built-in gate on post-naming surface re-establishment.
- Slides preserve pret positions and cadence, with pixel evidence at two slide offsets if fine scroll is used.
- The Oak timing trace matches mGBA.
- Custom and default naming work.
- Selected names persist.
- Initial bag, party, box, and inventory state matches ground truth.
- `OakSpeech` has one linked non-stub provider.
- `CopyUncompressedPicToTilemap` is linked and translated.
- `InitPlayerData2` has one linked provider and no orphan replacement module.
- The cry command is the sole silent audio operation.
- No touched boot or naming string remains hand-encoded.

## Execution notes (2026-07-20)

Corrections and cross-cuts discovered while executing Phase A. These override
the planning-baseline text above where they conflict.

### A1.0 — the performance contract was not measurable as written

`PERF.BIN` v1 recorded only per-stage **accumulated sums and maxima**. Mean and
worst are derivable from that; **deadline-miss count and 95th percentile are
not**. The A1 contract gates on median, p95, and misses, so it could not have
been honestly evaluated with the existing tooling — and reporting mean+worst
instead would be exactly the cancelling-aggregate failure this project's
evidence policy prohibits.

**Cross-cut (tooling, port-only debug code):** `PERF.BIN` extended to **v2**,
appending a per-frame WORK series after the v1 accumulators, so v1 offsets stay
byte-identical and old captures still parse. `src/debug/perf.asm` records each
frame's busy total; `tools/read_perf.py` gains `work_stats()`, nearest-rank
percentiles, `--from N`, and reports v1 captures as *distribution unavailable*
rather than silently omitting it. Durable note:
stigmergy `perf-bin-v2-per-frame-series`.

**Measured correction to the contract's "zero deadline misses" clause.** The
baseline is *not* miss-free over a full run: `party_menu` misses at frames 62,
82, 83, 87, 103, 104 — identically in all 5 runs. These are the scenario's own
START→party-menu **navigation transient**, not boot warmup. Frames 150+ are
miss-free. `ow_idle` has zero misses over its full 300 frames.

So the contract's "steady-state interval" must be **stated explicitly**:
`party_menu` uses `--from 150`, `ow_idle` uses `--from 0`. Report the full-run
miss count too, so a newly introduced transient miss cannot hide inside the
excluded prefix. Baseline numbers and reproduction: `dos_port/perf/a1_baseline/README.md`.

**Determinism finding:** the harness is effectively deterministic (fixed
DOSBox-X cycles + scripted input) — medians identical to 3 decimals across 5
runs, p95 spread ≤0.005 ms, stage means identical. The plan's "5 runs, compare
the median to reduce host scheduling noise" is satisfied, and any change larger
than ~0.05 ms is signal rather than noise.

**⚠ Headroom warning carried into A1.3.** `ow_idle` p95 is **14.95 ms against a
16.348 ms budget (~8.5% headroom)**: `render_bg` dirty-skips make most frames
cheap (median 4.58 ms) with periodic full-redraw spikes. A per-pixel
`g_obj_clip` test can convert those spike frames into misses while the mean and
median barely move. **Judge A1.3 on p95 and miss count in `ow_idle`, not on the
mean.** At DOSBox's 23880 cycles/ms, ~2 extra cycles/pixel over ~2560 sprite
pixels is ~0.2 ms against a 0.548 ms `render_sprites` budget — which is why both
A1.2 and A1.3 keep the default (zero-offset / full-canvas) path on the original
code path rather than adding a universal per-pixel test.

### A1.2 — `make fidelity` cannot evidence "pixel-identical"

Worth stating plainly because it is easy to bank the wrong green: the golden
scenarios compare **GBSTATE** (tilemap, VRAM, OAM, WRAM). `WIN_SRC_X`/`WIN_SRC_Y`
and `g_obj_clip` change **rendering only**, which GBSTATE cannot observe — a
mis-sampled window or a wrongly clipped sprite leaves game state byte-identical
and every golden passing. This is the plan's own rule ("GBSTATE cannot prove
host-side projection, clipping, or scroll rendering") applied to A1 itself.

`make fidelity` is therefore **necessary but not sufficient** for the
"pre-existing screens are pixel-identical" acceptance. The binding evidence is a
`tools/pixelcheck.sh` **before/after byte-compare** of the window- and
sprite-bearing scenarios (`startmenu`, `partymenu`, `bagmenu` for stacked
descriptors and the grown `WIN_DESC_SIZE`; `pokedex` for the flat path;
`battle` for sprites), captured on the HEAD tree and the changed tree and
`cmp`-ed. Do not substitute a golden pass for it.

**Result (2026-07-20).** HEAD vs the combined A1.2+A1.3 tree, `FRAME.BIN`
byte-compare, 64000 bytes each — **all six IDENTICAL**: `startmenu`,
`partymenu`, `bagmenu`, `pokedex`, `pallet`, `battle`. That covers the window
layer, stacked descriptors (the grown `WIN_DESC_SIZE`), the flat wTileMap path,
overworld OBJ, and battle OBJ. `make fidelity` also passed (exit 0; note its log
was truncated by `tail -40`, so per-scenario PASS lines were captured for only
the last 3 of 12 — the full decomposition comes from `fidelity-full` at A1.7).

### A1.3 — performance contract result (PASS)

Median of 5 runs per side, same build/config/inputs, `perf/a1_baseline/` vs
`perf/a1_after/`:

| metric | party_menu (frames 150+) | ow_idle (frames 0+) | limit |
|---|---|---|---|
| median | 9.132 → 9.227 (+1.05%) | 4.581 → 4.598 (+0.37%) | ≤5% |
| p95 | 9.812 → 9.910 (+0.99%) | 14.952 → 14.970 (+0.12%) | ≤5% |
| misses, steady | 0 → 0 | 0 → 0 | zero both sides |
| misses, full run | 6 → 6 | 0 → 0 | no new miss |
| `render_bg` | 2.130 → 2.130 (±0.000) | 3.162 → 3.162 (±0.000) | reported separately |
| `render_sprites` | 1.205 → 1.250 (+3.68%) | 0.548 → 0.564 (+3.04%) | reported separately |
| `present_windows` | 3.184 → 3.217 (+1.02%) | 0.009 → 0.009 | reported separately |

`render_sprites` is the largest single-stage delta and is **accounted for, not
absorbed**: the change adds exactly two per-ROW memory compares (the `g_obj_clip`
y-pair replacing `js`+`cmp imm`, and the `spr_clipped` dispatch). At ~40 sprites
x 8 rows x ~3 cycles ≈ 1000 cycles ≈ 0.04 ms at 23880 cycles/ms, which is the
+0.044 ms measured. The per-PIXEL path is untouched, which is why the cost did
not scale with sprite area. `render_bg` at ±0.000 confirms nothing leaked into
the BG path.

### A1.6 — marker harness result (PASS), and two real defects it caught

`DEBUG_CINEMATIC_MARKERS` (`src/debug/debug_dump.asm:RunCinematicMarkersTest`) +
`tools/check_projection.py`. 23 frames: offsets 0..7 and 252..255 on each axis.
**All PASS.** Frames retained in `/tmp/markers` during the session; regenerate
with `MARKER_SX=n MARKER_SY=n tools/pixelcheck.sh markers -o …`.

Verified: GB (0,0) at pixel (80,24); GB (19,17) at (232,160); matte contains
only colour zero; **128 OBJ px on every frame** = 4 edge-straddling markers x 32
visible px, with the 4 GB-hidden markers (`OAM_Y`=0/160, `OAM_X`=0/168) drawing
nothing; zero poison px on all 23 frames.

**The harness caught two defects that every other gate would have missed:**

1. **BG tile addressing.** Marker tiles were written to `$8000`, but BG/window
   addressing follows `rLCDC` bit 4 — clear (the overworld's setting) means
   SIGNED `$9000` addressing, so the BG half of the scene decoded as garbage
   while OBJ (always unsigned `$8000`) looked fine. The harness now sets bit 4.
   Any cinematic screen loading tiles at `$8000` must do the same.
2. **`W_UPDATE_SPRITES_ENABLED` = 0 erases cinematic OAM.** 0 means "hide once,
   then park at `$FF`", so `PrepareOAMData` ran `HideSprites` and republished
   `spr_oam_valid = 0` on the next `DelayFrame` — the published OBJ vanished.
   The parking value is **`$FF`**, and `MovieBeginSurface` now sets it (restoring
   1 on exit). This is the plan's "cinematic entry parks the overworld OAM
   rebuild path" made concrete; A2/B2/B3 inherit it for free.

**Decomposition note (do not skip this when re-reading the numbers).** The wrap
total is 2240 at `sy=0` AND at `sy=252` — but not for the same reason. Per-row
measurement shows two opposing 32-px effects cancelling: rows 28..31 *gain* 32 px
(the top-straddling OBJ no longer covers them) while GB row 17 *loses* 32 px off
the bottom. An unexamined "total unchanged, looks fine" reading would have been
wrong about why.

**Why this is the decisive wrap evidence.** At `src_y` 252..255 a linear read and
a wrapped read agree (tile row 31 is inside the map either way). They diverge one
scanline later: linear continues to tile row 32 = `GB_TILEMAP0 + 1024` = `0x9C00`
= `GB_TILEMAP1`, which the harness fills with POISON. Measured: rows 24..27 blank
(this map's row 31), GB row 0's marker content at row 28, poison count 0. The
discriminator fires exactly where the theory says it must.

### A1.7 — acceptance gates (ALL PASS), and A1 is committed

Commit `6a8bd934`. Every A1 acceptance criterion is met:

| Gate | Result |
|---|---|
| build | clean |
| generated-layout `--check` | OK, idempotent |
| `lint_pret_labels` | 0 violations, 6 suppressed |
| `audit_memmap.py` | clean — no overlaps, no strays |
| `fidelity-full` | **19/19 PASS**, full per-scenario log captured |
| projection/clipping/wrap harness | **23/23 frames PASS**, 0 poison |
| pre-existing screens pixel-identical | 6/6 `FRAME.BIN` byte-identical |
| decomposed performance contract | PASS (see the A1.3 table above) |

The 19 scenarios: status_p1, status_p2, start_menu, overworld_pallet,
party_menu, bag_menu, sign_pallet, item_tm_teach, item_stone_evolve,
item_potion_use, battle_intro, battle_menu, move_selection, ball_catch,
options_menu, trainer_card, pokedex_list, pokedex_entry, naming_screen.

**Logging lesson worth keeping.** An earlier `make fidelity` was piped through
`tail -40`, which left per-scenario PASS lines visible for only 3 of 12 — exit 0
was the only evidence for the other 9. Redirect these runs to a file and grep the
verdicts; never judge a suite by a truncated tail.

`faithdiff` has no subject in A1: no pret-labeled routine is touched.
`movie_projection.asm` and `PublishProjectedOAM` are port-only with no pret
counterpart (descriptive names per the naming rule); `perf.asm` / `read_perf.py`
are debug/HAL.

**Commit hygiene note.** `dos_port/Makefile` and `src/debug/debug_dump.asm` were
already dirty from the overworld-events Stage 4 (Fly) session, and the A1 harness
cannot build without both, so `6a8bd934` necessarily carries their `AUTOKEY_FLY`
block and `AUTOKEY_DUMP_FRAME` forwarding fix. That is declared in the commit
message rather than swept in silently; the rest of that workstream is untouched
and uncommitted.

### A2 — CORRECTION: the title bounce does not wrap, and the label is pret-local

Two planning-baseline errors found by reading pret before implementing. Both
change A2's acceptance criteria; the text above is superseded where it conflicts.

**1. `TitleScreenYScrolls` is not a pret name.** Pret has the table as a LOCAL
label inside `DisplayTitleScreen`:
`engine/movie/title.asm:DisplayTitleScreen.TitleScreenPokemonLogoYScrolls`. The
port invented a global `TitleScreenYScrolls`. The *values* are byte-identical and
faithful — `(-4,16) (3,4) (-3,4) (2,2) (-2,2) (1,2) (-1,2) 0` — so this is a
naming divergence only. Per the preserve-pret-labels rule the port keeps pret's
local name and scope; A2 renames it. (NASM binds a local label to the most recent
textually preceding global, so the data block must sit after `DisplayTitleScreen:`
or be written fully qualified.)

**2. The bounce NEVER WRAPS.** `hSCY` starts at `$40` and the table walks it:

```text
64 --(-4 x16)--> 0 --(+3 x4)--> 12 --(-3 x4)--> 0 --(+2 x2)--> 4
   --(-2 x2)--> 0 --(+1 x2)--> 2 --(-1 x2)--> 0
```

Range [0,64], 22 distinct values, **zero crossings of the 0/255 boundary**. The
`-3` entry is special because it is where `SFX_INTRO_CRASH` is dispatched
(pret compares `cp -3` to trigger the sound), **not** because it overshoots into
a wrap. The planning text calling it "the `-3` crash step whose unsigned byte
values wrap" is wrong on the wrap.

Consequences:

- A2 **cannot** supply wrapped-frame pixel evidence, because no wrapped frame
  exists. The "Scroll-render pixel evidence" rule is written conditionally
  ("whenever the stage's scroll sequence wraps"), so it is satisfied vacuously —
  but the A2 acceptance line "including every wrapped/overshoot frame" must read
  **"including the `-3` crash-SFX frame"** instead.
- The two-distinct-offsets-per-axis requirement still binds and is easily met
  (22 distinct `hSCY` values), so a renderer that ignored `WIN_SRC_Y` still
  cannot pass.
- The wrap machinery remains justified and is already proven: A1's marker harness
  established it synthetically. Whether any B3 `hSCX` scene actually wraps must be
  **measured in B3**, not assumed — the same assumption is what produced this
  error.

**3. The title's audio `TODO-HW` comments are stale.** `PlaySound` / `PlayMusic`
and the PCM path are live (the plan's own evidence table says so). The crash /
whoosh / title-music sites in `src/movie/title.asm` still carry
`; TODO-HW: audio (Phase 3)` comments from before the audio engine landed. Those
are false negative claims of the kind the evidence policy forbids; A2 deletes
them as it wires the real calls.

### A2.1 / A2.2 done — labels restored, live audio and palettes wired

- `TitleScreenYScrolls` → pret's `DisplayTitleScreen.TitleScreenPokemonLogoYScrolls`
  (qualified spelling; NASM would otherwise bind a bare `.name` to the wrong
  preceding global). Values already matched pret byte-for-byte.
- The header's `TODO-HW` block is **deleted, not carried**: `project_state`
  shows every routine it disclaimed is a linked implementation — `PlaySound`
  (35 callers), `StopAllMusic` (9), `PlayMusic` (11), `PlayPikachuSoundClip`,
  `RunPaletteCommand` (14), `UpdateCGBPal_OBP0` (5), `GBPalNormal` (13) — and
  the OBP0 note predated `render_sprites`. Only `FillSpriteBuffer0WithAA` is
  genuinely absent (`missing`), and its note is corrected rather than removed.
- Live wiring at pret's exact call points: `SET_PAL_TITLE_SCREEN` via
  `RunPaletteCommand` (BH), `rOBP0` + `UpdateCGBPal_OBP0`, `SFX_INTRO_CRASH` on
  the `-3` entry, `SFX_INTRO_WHOOSH`, both PCM beats (`PikachuCry1` at reveal,
  `PikachuCry11` at exit), `WaitForSoundToFinish`, `StopAllMusic`,
  `MUSIC_TITLE_SCREEN`, `GBPalWhiteOutWithDelay3`, `LoadGBPal`.

**Generator change (Tier-1).** `PlayPikachuSoundClip` takes an INDEX, but
`gen_pika_pcm.py` emitted only data addresses, which would have forced magic
ordinals (`0`, `10`) into the `.asm`. It now also emits `PIKA_CRY_<n>_IDX`, and
guards the table + ~700 KB `incbin` behind `PIKA_PCM_EQUATES_ONLY` so an
index-only consumer does not duplicate the blob into a second object. The diff is
emission-only — the sample-blob path has zero changed lines, so `pika_pcm.bin` is
byte-identical.

`SET_PAL_TITLE_SCREEN` moved into `include/gb_constants.inc` beside the three
`SET_PAL_*` already there, rather than duplicating `palettes.asm`'s file-local
`%define` (those two headers must not both define a symbol).

**Gates:** build clean; `lint_pret_labels` 0 violations; the new
`DEVIATION{class=banking}` for the `TitleScreen_PlayPikachuPCM` thunk parses.
`faithdiff DisplayTitleScreen` is otherwise unchanged from its pre-existing
bespoke-title divergences (the `MainMenu` → `OakSpeech`/`EnterMapBoot` shortcut
is A3's to remove). One **pre-existing, unrelated** `--strict-claims` violation
remains: a stale `extern HiddenEventMaps` in `home/hidden_events.asm`.

### Stale-claim sweep done in passing (A2.1/A2.2)

`--strict-claims` is back to **zero tree-wide**, the property CLAUDE.md
documents.

- **`extern HiddenEventMaps`** (`src/home/hidden_events.asm`) named
  `src/data/hidden_events_data.asm`, which does not literally define it — the
  symbol is in the generated `assets/hidden_events.inc` that file `%include`s,
  and the linter does not follow includes. Comment now names the defining `.inc`
  and the including `.asm`. Pre-existing, unrelated to menu-intro; fixed because
  it was a one-line correction.
- **Title OAM notes** claiming "OAM sprite renderer not yet implemented"
  predated `render_sprites`; replaced with pointers to A2.4's publication step.
- **`.doTitlescreenReset` is now really wired**, and doing so exposed a genuine
  translation boundary rather than a comment fix:
  - pret's `IncrementResetCounter` returns with `a = d = $0C`, and
    `.doTitlescreenReset` stores that byte as the **audio fade length**. The
    port's `pushad`/`popad` discarded it, so the reset path now restores
    `AL = $0C` explicitly on the carry return.
  - pret's `.audioFadeLoop` is a **bare spin** on `wAudioFadeOutControl`, which
    works on the GB because the audio engine runs from the VBlank interrupt.
    This port ticks audio inside `DelayFrame` (`frame.asm` → `audio_tick` →
    `FadeOutAudio`), so a bare spin would never decrement the counter and would
    **hang forever**. The loop calls `DelayFrame` each iteration under a
    `DEVIATION{class=HAL}`.

Only one `TODO-HW` remains in `title.asm` — `FillSpriteBuffer0WithAA`, which
`project_state` confirms is genuinely `missing`.

### A4 — `InitPlayerData2` relocation branch is moot

Generated state (`project_state`, 2026-07-20) reports `InitPlayerData2` as
`implementation / linked`, provider
`dos_port/src/engine/movie/oak_speech/init_player_data.asm` — **already
path-mirrored**. A4's "if its current location violates path-mirroring, move
it" branch therefore does not apply: list it as a dependency and leave it in
place. `OakSpeech` remains a linked stub in `main_menu_stubs.asm`, and
`CopyUncompressedPicToTilemap`, `PlayIntro`, `PlayIntroScene`,
`PlayShootingStar`, `SpawnAnimatedObject` all remain `missing` as the plan
recorded.

### Tree state

Phase A began on a tree carrying **uncommitted overworld-events Stage 4 (Fly)
work** from another session. It is preserved and kept out of this plan's
commits. Related: stigmergy `overworld-events-stage4-fly-arrival-open` notes the
Fly *arrival* page-fault was deferred pending "a session with a real
title/new-game flow" — which is precisely what A3/A4 deliver, so that item
should be retested once A4 lands.

## Phase B — Splash and Yellow intro

### Dependency graph

```text
A1 ───────────────┬──────────────→ B2 splash
                  └→ B1 animated objects → B3 Yellow intro
B2 + B3 ─────────────────────────→ B4 boot integration
```

B1 and B2 may land in either order after A1 because the splash uses plain OAM tables, not the object engine — pret’s own structure, not an invented dependency. This keeps B1, the plan’s biggest unknown, off the critical path of the splash. B2 must pass its visual and timing acceptance before B3 integrates the animated-object engine into the projected surface.

B2 must not create a `PlayIntroScene` stub.

### B1 — Animated-object engine

#### Work

- [ ] Port `engine/gfx/animated_objects.asm` with exact labels.
- [ ] Inventory required WRAM and HRAM.
- [ ] Add exact aliases or correctly sized regions.
- [ ] Run `audit_memmap.py` after memory-map changes.
- [ ] Generate immutable frame, spawn, OAM, and sine data.
- [ ] Keep code-address tables in `.asm`.
- [ ] Preserve masks, scripts, timers, and sine arithmetic.
- [ ] Publish canonical OAM through `PublishProjectedOAM`.
- [ ] Do not wire the surfing minigame.
- [ ] Add deterministic lifecycle and edge-crossing tests.

#### Acceptance

- Object state matches pret at selected frames.
- Masked slots produce no visible OAM.
- Canonical OAM matches GB output.
- Native positions equal canonical positions plus `(80,24)`.
- Edge-exiting objects never paint the matte.
- The engine remains separate from overworld sprite state.
- It links without surfing stubs.

### B2 — Game Freak splash

#### Work

- [ ] Port `PlayShootingStar` and `GameFreakIntro`.
- [ ] Port `splash.asm`.
- [ ] Preserve `LoadShootingStarGraphics`, `AnimateShootingStar`, and `MoveDownSmallStars`.
- [ ] Generate static star/logo OAM data.
- [ ] Project BG through `UI_SPLASH`.
- [ ] Publish OBJ through `PublishProjectedOAM`.
- [ ] Own and restore cinematic clipping.
- [ ] Use real `SFX_SHOOTING_STAR`.
- [ ] Apply `SET_PAL_GAME_FREAK_INTRO`.
- [ ] Preserve skip behavior.
- [ ] Add `DEBUG_CINEMATIC_SPLASH` in `home/init.asm`.
- [ ] Generate and compare the splash timing trace.

`PlayIntro` may remain absent until B4.

#### Acceptance

- Splash timing matches mGBA record by record.
- Star paths match pret at projected coordinates.
- Entering and exiting OBJ clip at the surface; `MoveDownSmallStars` exits produce no matte pixels.
- Logo OBJ align with the BG.
- Live SFX and palette commands execute.
- Skip exits with clean ownership.
- `gamefreak_intro` passes.

### B3 — All 18 Yellow intro scenes

#### Work

- [ ] Extract, before implementation, the per-frame mGBA `hSCX`/`hSCY` sequences for every scrolling scene; these define each scene’s scroll-evidence capture points.
- [ ] Port `PlayIntroScene`.
- [ ] Port scene dispatch and scenes 0–17.
- [ ] Preserve timers, transitions, masks, sine tables, spawning, and skip behavior.
- [ ] Present all `H_SCX`/`H_SCY` BG scrolling through the A1 `WIN_SRC_X`/`WIN_SRC_Y` helper.
- [ ] Generate immutable graphics, tilemaps, sequences, spawn records, frames, and OAM.
- [ ] Keep code-address tables in `.asm`.
- [ ] Project all BG mutations through `UI_YELLOW_INTRO`.
- [ ] Republish changing OAM before each frame.
- [ ] Own and restore window, matte, OAM, source-offset, and clip state.
- [ ] Use live palettes, music, and SFX.
- [ ] Follow the tile-cache invalidation rule.
- [ ] Avoid vTileset `$03` and `$14`.
- [ ] Add a continuous transition trace.
- [ ] Add `DEBUG_CINEMATIC_YELLOW` in `home/init.asm`.
- [ ] Extract and compare an mGBA trace.
- [ ] Add one state golden per scene.
- [ ] Retain host frames for every frame-yielding scene; for each scrolling scene retain frames at a minimum of two distinct scroll offsets, including a wrapped offset if the scene’s sequence wraps.

A scene golden must reach its target through the preceding movie path and assert all preceding entries. Directly writing the current-scene variable is prohibited. For scenes that transition without a `DelayFrame`, per-scene evidence is the transition-trace record (entry, timers, masks), which does not depend on frame boundaries; a GBSTATE snapshot taken at the next frame boundary is retained and labeled as post-scene state — dump points are port-owned code and mGBA Lua can break anywhere, so this is a labeling rule, not a capture limitation.

#### Permanent-evidence rationale

Sampling only early, middle, and final scenes would leave most scene-specific tilemaps, palettes, scripts, and object layouts without permanent evidence. Permanent coverage consists of:

- An mGBA trace of scene entries, timers, and masks compared record by record with the DOS trace.
- Eighteen named scene scenarios containing compared tilemap, VRAM, OAM, and WRAM state.
- Retained host `FRAME.BIN` output for every frame-yielding scene, including the multi-offset scroll captures — GBSTATE cannot prove host-side projection, clipping, or scroll rendering.
- Must-hit assertions tying each artifact to its intended scene provider.

#### Acceptance

- The trace contains scenes 0–17 in order and matches mGBA record by record.
- No scene is evidenced only through debug mutation.
- All scene scenarios pass.
- All frame-yielding scenes retain native visual evidence; scrolling scenes visibly scroll — their multi-offset captures differ from each other and match mGBA through the projection transform.
- BG and OBJ remain inside the projected rectangle.
- Timers and active-object masks match ground truth.
- Skip exits cleanly to title preparation.

### B4 — Full power-on integration

#### Work

- [ ] Add complete `PlayIntro`.
- [ ] Call it from `Init` through direct predef lowering.
- [ ] Preserve later LCD, VRAM, palette, and title setup.
- [ ] Register translated and linked state.
- [ ] Activate all permanent cinematic scenarios.
- [ ] Regenerate the scenario registry.
- [ ] Add coordinate transforms to `golden_diff.py`.
- [ ] Add only measured, justified masks.
- [ ] Sweep stale `TODO-HW`, `STUB`, extern, allowlist, plan, and status claims.
- [ ] Add and verify `title_timeout` and `soft_reset` route scenarios.
- [ ] Run one uninterrupted power-on to overworld without `SKIP_TITLE`.

#### Golden naming

- Existing `smoke_title` becomes regenerated `main_menu`.
- `title` captures A2’s defined checkpoint.
- `title_reentry` captures the same checkpoint after B-cancel.
- Scenario id 21 remains `oak_intro`.
- `gamefreak_intro` covers the splash.
- `yellow_intro_s00..s17` cover all Yellow scenes.
- Projection uses coordinate transforms, never broad masks.
- Canonical OAM and native projection receive separate evidence.

## Generated-data requirements

Generators are deterministic functions of pret source, constants, and explicit sidecars.

Generated outputs include:

- Intro UI layout.
- Oak speech strings.
- Migrated boot default names.
- Animated-object frames and OAM.
- Splash tables.
- Yellow-intro graphics, tilemaps, sequences, and animation data.

Human-readable text uses `gb_text.encode`. Control bytes use named constants. Modified `.asm` files must not introduce hand-encoded charmap strings.

Generators write only `assets/*.inc`. Hand-written `.asm` owns routines, dispatch logic, and code-address tables.

## Fidelity and annotation requirements

For every changed pret label:

1. Read the exact pret routine and callees.
2. Preserve label names, register mapping, big-endian data, and live flags.
3. Run `faithdiff`.
4. Fix or annotate every unsuppressed difference.
5. Run strict label/annotation lint.
6. Run relevant runtime scenarios and timing traces.
7. Update the translation database.
8. Recheck provider state.

Projection differences use:

```nasm
; DEVIATION{class=projection; pret=<file>:<label>; behavior=<exact projected behavior>; evidence=<measured requirement>; lifetime=permanent widescreen projection}
```

Flat predef boundaries use `class=banking`. Routine-specific differences never enter the global suppression file. Pure relocation uses the relocation allowlist.

## Verification matrix

| Stage | Static gates | Runtime gates | Required evidence |
|---|---|---|---|
| A1 | build, generated-layout check, strict lint, memmap audit | existing window/sprite scenarios, projection/clipping/wrap harness, `fidelity-full`, decomposed perf captures | unchanged existing screens, exact projection and clipping, hidden-marker culling, dual-axis fine scroll incl. wrap, standing frame budget preserved |
| A2 | title faithdiff | `title`, title timing trace, mid-bounce pixel captures, audio/palette logs | centered final composition, complete bounce/blink timing, wrapped-frame pixels, eyes and live services |
| A3 | title/MainMenu/Init seam gates | `main_menu`, `title_reentry`, `continue_seed`, route traces | real menu routing, preserved continue state, no leaked presentation state |
| A4 | Oak gates and stub retirement | `oak_intro`, Oak timing trace, naming, `new_game_seed` when required | complete cutscene, naming, data, one provider per label |
| B1 | animated-object gates and memmap audit | lifecycle/OAM/edge-crossing harness | exact state and clipping |
| B2 | splash faithdiff | `gamefreak_intro`, splash timing trace, audio/palette logs | complete timed splash |
| B3 | every Yellow label | mGBA transition comparison, 18 scene scenarios, multi-offset scroll captures | every scene independently evidenced, visible scrolling, all pixels in bounds |
| B4 | Init/PlayIntro gates and stale-claim sweep | all scenarios, timeout/reset routes, `goldens-verify`, `fidelity`, `fidelity-full` | uninterrupted normal boot and reset behavior |

Canonical commands include:

```sh
make -C dos_port assets
python3 dos_port/tools/audit_memmap.py
make -C dos_port goldencheck SCENARIO=title
make -C dos_port goldencheck SCENARIO=title_reentry
make -C dos_port goldencheck SCENARIO=title_timeout
make -C dos_port goldencheck SCENARIO=main_menu
make -C dos_port goldencheck SCENARIO=continue_seed
make -C dos_port goldencheck SCENARIO=oak_intro
make -C dos_port goldencheck SCENARIO=gamefreak_intro
make -C dos_port goldencheck SCENARIO=yellow_intro_s00
# Repeat for yellow_intro_s01 through yellow_intro_s17.
make -C dos_port fidelity
make -C dos_port fidelity-full
make -C dos_port goldens-verify
```

Do not use root-level `make clean`. Use `make -C dos_port clean` only when generated dependencies require it.

### A2.3 — the port had no auto-BG-transfer, so the title's VRAM copy was a no-op

Implementing the projection surfaced a defect the plan did not anticipate, and it
is very likely a cause of the long-standing "title screen graphics are wrong"
entry in CLAUDE.md.

`TitleScreenCopyTileMapToVRAM` was storing `hAutoBGTransferDest+1` and calling
`Delay3` — and **nothing in this tree reads `hAutoBGTransferDest`**. There is no
auto-BG-transfer implementation. The physical copy pret's title depends on has
never run. The bespoke title only looked plausible because `render_bg` read
`wTileMap` flat and never consulted the GB tilemap at all.

Under projection the compositor samples the GB tilemap through the window
descriptor, so the transfer had to be made real. It now copies the 20x18
rectangle (canvas stride 40) to the destination at the GB's 32-byte row stride,
**byte-contiguous and deliberately not wrapped**: a row-24 destination (`$9B00`)
genuinely runs off tilemap 0 into tilemap 1 at `$9C00`, exactly as the hardware
transfer would. The wrap belongs to the *sampler* — `render_window` re-reads rows
mod-32 within one tilemap — never to the writer. That is what makes the bounce
show tilemap 0's row-0 content once `hSCY` scrolls past row 31, and it is why
pret copies to row 24 and row 0 separately.

**Carry-forward:** any other pret screen that relies on `hAutoBGTransferEnabled`
to commit `wTileMap` has the same latent no-op. Check before assuming a screen's
tilemap reaches VRAM.

Three smaller corrections came with it:

- `SCREEN_TILES_W` is **40**, not 20. Title comments reading `17*20` and "skip to
  next row (4 bytes)" were GB-era leftovers that were *wrong*, not merely stale.
- `ClearScreen` is exported and other screens need its whole-canvas meaning, so
  it was left alone; the title uses a local `TitleBlankSurface` for the
  rectangle-limited `$7F` fill, called after `MovieBeginSurface` zeroes the matte.
- **`hWY` reconciled by evidence, not by choosing a side.** Neither pret's 144 nor
  the port's 200 was correct. `set_single_window` mirrors the descriptor's `wy`
  into `H_WY`, and `sync_dialog_window` gates on `H_WY == RENDER_H`, so writing
  either value after the surface is published corrupts the mirror. The write is
  dropped under `DEVIATION{class=projection}`; the descriptor owns the window.

#### A2.3 pixel evidence (PASS)

`make fidelity` is 12/12 PASS, but that is a **no-regression** result and cannot
evidence this change: the goldens compare GB memory, and the projection lives in
the compositor. The binding evidence is `tools/pixelcheck.sh title`, a new
scenario (`DEBUG_TITLE=1`) that deliberately does **not** set `SKIP_TITLE` — it
boots the real title through the full bounce and photographs the stable
checkpoint at `.loop`.

Decomposed, because a matching total is not a result:

| Check | Measured |
| --- | --- |
| Matte outside (80,24)-(240,168) | 40960 px, all colour 0 |
| Surface interior | 23040 px = 160x144 exactly |
| Non-matte bounding box | x 96-223, y 32-166 |
| Logo at pret coord(2,1) | 4658 ink px |
| Pikachu at pret coord(4,8) | 4759 ink px |
| Ear/tail tiles col 16, rows 10-13 | 162 ink px |
| Copyright row 17 | 383 ink px |
| Row 0 (must be blank) | 0 ink px |

The bounding box is derived from pret's own coordinates rather than compared to a
remembered number: logo col 2 gives `80 + 2*8 = 96`, 18 columns wide gives `223`,
row 1 gives `24 + 8 = 32`. Four distinct shades inside the surface prove the
tilemap genuinely reached VRAM — under the old no-op copy nothing could have
rendered there.

Still open for A2.4/A2.5: eye OAM is not yet published to the surface, so the
checkpoint above is the composition **without** eyes, and no timing trace has
been taken yet.

### A2.3 SELF-CORRECTION: the title DOES use the GB window layer, and the port dropped it

The `hWY` reconciliation recorded above is right about the mechanism but its
stated *evidence* was wrong, and the wrong version shipped in `eaf70452` before
being caught while starting A2.4. Recording it rather than quietly amending it.

Pret's full `hWY` sequence is four writes, not one:

1. `$90` (144) — window off, at the top of `DisplayTitleScreen`.
2. **`$40` (64), immediately after `SaveScreenTilesToBuffer1` — window ON.**
3. `SCREEN_HEIGHT_PX` at the speech bubble — window off again.
4. `0` at `.go_to_main_menu`.

So the claim "the title composes entirely on BG" is false. Worse, the port never
translated write 2 at all: at that line it has `mov [H_SCY], 0x40`, which is a
mistranslation twice over — `hSCY` was already set to `$40` at the top of the
routine, so the write is a dead duplicate, and pret's `hWY` write was dropped.

**What that window does is load-bearing.** The row-24 copy runs contiguously off
tilemap 0 into tilemap 1 at `$9C00`, which places `wTileMap` rows 8..17 (Pikachu
and the copyright line) into vBGMap1 rows 0..9. `LCDC $E3` has the window enabled
and mapped to `$9C00`, so the window at `y=64` paints exactly those rows at
exactly the screen position they belong to. The top 64 px bounce with `hSCY`
while the bottom 80 px stay nailed down. Without it the copyright line bounces
along with the logo.

This retroactively justifies A2.3's byte-contiguous, non-wrapping copy: the
spill into tilemap 1 is not an artifact to be tolerated, it is the mechanism.

**RESOLVED — the bounce window is implemented, not deferred.** The initial
instinct was to record it as a `STUB` and push it to A2.5; that was wrong, since
leaving a known-unfaithful gap in place is exactly what the fidelity rules exist
to prevent. `MovieSyncWindow` (`movie_projection.asm`) now presents the GB window
layer as a **second** projected descriptor appended over the surface, honouring
`LCDC` bit 5 (window enable) and bit 6 (map select) — real GB window semantics,
not a title-shaped special case. `title.asm` carries pret's `hWY` writes verbatim
(`$90`, `$40`, `SCREEN_HEIGHT_PX`, `0`) and calls `MovieSyncWindow` after each,
so the STUB and the projection DEVIATION are both retired.

Two register-ownership traps had to be resolved for that to work, and they are
the same trap twice:

- `set_single_window` mirrors the descriptor's `wy` into `hWY`. A cinematic needs
  that byte to hold **pret's** `hWY`, so `MovieBeginSurface` parks it back at 144.
- `set_single_window` also mirrors the descriptor's `wx` into `rWX` — and that one
  is the subtle one. `MovieSyncWindow` projects `rWX`, so an already-projected 87
  became 167 and placed the window a full **80 px** right of the surface, with the
  overflow clipped at the surface edge. `MovieBeginSurface` now saves and restores
  the GB's own `rWX` across the call.

The 80 px was not diagnosed by inspection — it was measured. The first capture
showed the window band at exactly half the checkpoint's ink, and the halving was
uniform across colours 1/2/3, which pointed at geometry rather than content;
dumping the actual column positions showed the whole band displaced by exactly
`UI_TITLE_COL * 8`.

#### Bounce-window pixel evidence (PASS)

`tools/pixelcheck.sh title` gained `TITLE_DUMP_FRAME=N`, which photographs the
Nth frame of the bounce instead of the checkpoint. This is required: by the
checkpoint pret has parked the window off-screen, so the checkpoint frame
**structurally cannot** evidence the window.

At `TITLE_DUMP_FRAME=8` (`hSCY` = 64 − 8·4 = 32):

| Check | Measured |
| --- | --- |
| Window band y96..168 vs checkpoint | **byte-identical** |
| Copyright band y160..168 vs checkpoint | **byte-identical** |
| Bottom-half ink | 5291 vs checkpoint 5304 |
| Top-half ink (must differ — it is bouncing) | 1953 vs checkpoint 4658 |
| Matte above / below | 0 / 0 |

Byte-identity of the bottom band across a frame where the top half is mid-bounce
*is* the property under test: the window nails the bottom 80 px down while the
logo moves. The 13-pixel bottom-half residual was not waved away — it localises
to surface tile columns 9-10 at row 8, exactly the two speech-bubble overlay
tiles (`$64`/`$65`) that `TitleScreen_PlacePikaSpeechBubble` writes *after* the
row-24 copy that feeds the window. Expected, and it sits outside the identical
band.

The stable checkpoint is unaffected and its A2.3 capture is bit-for-bit
unchanged, confirming the new descriptor does not leak into the BG-only frame.

### A2.4 — eye OAM on the projected surface (PASS)

`TitleScreen_PlacePikachu` copies the 8 canonical eye records to `wShadowOAM` as
before — the records stay byte-comparable against a golden, and the projection
lives only in the published DOS coordinates — then calls the new local
`TitleScreenPublishEyes` (`PublishProjectedOAM`, offset `(80,24)`).
`.LoadBlinkFrame` republishes after mutating the tile IDs. That republish is
mandatory, not defensive: `MovieBeginSurface` parks `wUpdateSpritesEnabled` at
`$FF`, so nothing else rebuilds OAM while the cinematic owns the screen and the
compositor would otherwise keep drawing the previous blink frame.

Placement evidence, against the OAM records rather than a remembered box: all
**152** changed pixels versus the eyeless capture fall inside the union of the
eight expected 8x8 boxes, with **zero** outside and zero anywhere in the matte.
Per-record pixel counts are `[1,9,17,49]` for records 0-3 and `[9,1,49,17]` for
records 4-7 — the mirrored pattern the `$22` vs `$02` attribute byte (bit 5,
X-flip) predicts.

Animation evidence, via a new `TITLE_DUMP_SCENE=N` capture mode:

| Comparison | px differ | outside eye boxes |
| --- | --- | --- |
| open vs half | 64 | 0 |
| open vs closed | 126 | 0 |
| half vs closed | 82 | 0 |
| **open vs reopened** | **0** | 0 |

Three visually distinct states, all confined to the eye boxes, and the cycle
returns **byte-identically** to the open state — so `BlinkOpen` restores the tile
bits exactly and the animation cannot drift over repeated blinks.

Two harness notes worth keeping, both found by the captures disagreeing with
expectation rather than by inspection:

- The checkpoint dump was initially gated only on `TITLE_DUMP_FRAME == 0`, so it
  fired at `.loop` and exited before `.titleScreenLoop` ever ran. Every
  scene capture came back byte-identical to the checkpoint. Identical captures
  across supposedly different states are a harness smell, not a pass.
- Post-call `wTitleScreenScene` is one AHEAD of the dispatch that ran, because
  `.BlinkWait` increments before the check. Scene 1 is therefore never observable
  at that point. The states to capture are `S=2` (half), `S=5` (closed) and
  `S=11` (reopened).

**Method note.** This was found by reading pret's routine end-to-end while
starting an unrelated subtask, not by any gate. Every gate was green across it:
the build, `lint_pret_labels`, `--strict-claims`, 12/12 `fidelity`, and a
decomposed pixel capture. None of them can see a dropped write whose only
symptom is motion, and the checkpoint frame is deliberately the one frame where
the window is off. A green board is not evidence that a translation is complete.

## Full-chain target-runtime smoke test

After deterministic gates pass, perform one uninterrupted normal DOSBox-X run with a configured audio device:

1. The matte is blank, centered, and free of leaked sprites or stale artwork.
2. Game Freak splash appears centered.
3. Shooting-star SFX is audible.
4. Yellow intro runs, scrolling scenes visibly move, and valid skip input works.
5. Intro OBJ remain aligned and disappear at the projected edges.
6. Title bounce and eye animation appear continuous, including the crash overshoot.
7. Pikachu PCM plays at reveal and title exit.
8. Title music starts.
9. START opens `MainMenu`.
10. OPTION opens and returns.
11. B returns to a cleanly reloaded title.
12. NEW GAME enters Oak’s cutscene.
13. Pictures and slides remain centered.
14. Player and rival naming work, and the cutscene resumes cleanly after each naming screen.
15. Chosen names persist.
16. Oak hands off through `SpecialEnterMap`.
17. Pallet Town loads with music and palette.
18. No debug scene mutation, dump exit, or `SKIP_TITLE` is used.

Repeat the entry portion with a valid save and choose CONTINUE.

### Human-acceptance standard

The smoke test is performed by the user or a designated project maintainer. When practical, the observer should not be the author of the stage under review. Record:

- Observer.
- Commit.
- DOSBox-X version and configuration.
- Audio backend.
- Date.
- Pass/fail for every numbered step.
- Any observed anomaly and its disposition.

Terms are judged as follows:

- **Continuous/smooth:** no visible tile-sized jump in pixel-scroll motion, no repeated or skipped animation pose, and no pause inconsistent with the reference timing trace.
- **Clean transition:** no stale frame, one-frame flash, residual OBJ, matte contamination, callback leak, or palette discontinuity at a handoff.
- **Aligned:** OBJ retain their intended relationship to BG throughout motion, including edge entry and exit.
- **Overall pacing:** the uninterrupted sequence contains no perceptible stall or premature transition beyond waits established by the timing traces and intentional input pauses.
- **Audible:** the configured device produces the expected music, SFX, or PCM at the corresponding visible event without clipping the sequence or hanging.

Human judgment is sufficient only for these end-to-end experiential properties because deterministic gates already establish exact state, frame ordering, projection, clipping, scroll rendering, and command dispatch. The smoke test does not replace those gates and cannot override a failure. One configured audio backend is sufficient here because cinematic code targets the shared command gateway; backend-specific failures belong to the audio engine.

## Failure-to-regression policy

“When practical” is not an unbounded exception.

An observed failure must become an automated deterministic regression check when all of these are true:

- It can be reproduced through scripted input or a fixed debug entry gate.
- Its failure state is observable in GBSTATE, `FRAME.BIN`, a timing trace, an audio/palette command log, a memory dump, or a profiler capture.
- Reproduction does not require analog audio capture, host-display filming, or nondeterministic physical-device behavior.
- The check can run within the existing `fidelity-full` resource envelope or as a named long-tail scenario.

Examples include stale frames, incorrect positions, static content that should scroll, leaked sprites, wrong palette commands, duplicate handoffs, skipped scenes, incorrect frame counts, and state corruption.

A failure is impractical to automate only when its defining symptom exists exclusively in nondeterministic host presentation or physical output, such as:

- Backend-specific analog distortion.
- Host audio underruns that cannot be observed in the command queue.
- Display tearing caused by host compositor scheduling.
- Intermittent device-driver latency outside the emulated game state.

An impractical failure is not ignored. It requires:

1. A tracked issue or durable project-memory entry.
2. Exact reproduction configuration.
3. A repeatable manual regression step.
4. Two clean repetitions on the affected configuration before the stage closes.
5. Explicit classification as cinematic, emulator, audio-backend, or host-environment behavior.

A persistent scope-relevant failure blocks closure even if automation is impractical. Only a proven external backend or host defect may be deferred from this plan, and the cinematic command/state path must still pass deterministic evidence.

## Risks and mitigations

### Shared window descriptor

`WIN_SRC_X`/`WIN_SRC_Y` affect the shared compositor. Zero-default initialization, all existing window goldens, `fidelity-full`, and decomposed performance evidence are mandatory. Any unexplained existing-screen change blocks A1.

### Wrap-sampling correctness

The confirmed review failure mode for the bounce: a linear source read diverges from the GB’s mod-256 wrap exactly on overshoot/wrap frames, while register-level traces still match because they log what the game wrote. The mitigation is structural (masked mod-256/mod-32 sampling within one map, defined in A1) plus dedicated pixel evidence (A1 wrap markers, A2 mid-bounce captures including every overshoot entry, B3 multi-offset scroll captures). Register traces are never accepted as scroll-render evidence.

### Shared sprite renderer

`g_obj_clip` affects every screen with OBJ. The full-canvas default must be a proven pass-through through existing sprite scenarios and performance captures.

### OBJ border leakage

Unclipped off-screen GB coordinates would become visible in the DOS matte. Structural clipping, hidden markers, edge-straddling markers, edge-crossing animation tests, and retained native frames are all mandatory.

### OAM ownership

`DelayFrame` can rebuild overworld OAM. Cinematic entry parks that path and publishes canonical plus native OAM. Title eyes gate publication; A1 markers gate clipping.

### `EnterMapBoot`

Only route and state effects activated by the real menu path belong here. Broader cleanup requires separate overworld evidence.

### `CopyUncompressedPicToTilemap`

Matching visible output does not prove register, tile-order, flip, or flag compatibility. A4 verifies the exact pret contract.

### Animated-object memory

New regions preserve pret addresses and never repurpose party, box, save, or Gen-2-compatible bytes.

### Audio timing

Command order and game-visible waits must match the reference trace. Backend buffering is separately covered by the smoke test.

### Golden misclassification

`smoke_title` and disabled `oak_intro` must be regenerated after navigation changes. Renaming artifacts alone is prohibited.

### `PlayCry`

Oak’s cry remains silent by explicit scope decision. Every other cinematic audio path must be live and observed.

## Commit and coordination policy

- Check stigmergy memories and active claims before each stage.
- Claim files before editing.
- Preserve unrelated dirty-tree work.
- Use one reviewable commit per stage unless generator and output are mechanically inseparable.
- Land generator and output together.
- Land stub deletion and real-provider linkage together.
- Do not include unrelated active-plan changes.
- List every unsuppressed faithdiff difference and its annotation in the commit message.
- Mark a checkbox complete only after its runtime and timing evidence exists.

## Definition of done

- [ ] Normal power-on reaches the overworld without `SKIP_TITLE`.
- [ ] Game Freak splash, all 18 Yellow scenes, title, Oak speech, and naming are present.
- [ ] Every cinematic BG occupies `(80,24)..(239,167)`.
- [ ] The surrounding matte is intentional, clean, and contains no leaked scene content.
- [ ] Every cinematic OBJ uses the same projection without changing canonical GB OAM.
- [ ] Hidden OBJ render nothing, edge-straddling OBJ clip per pixel, and no OBJ paint the matte.
- [ ] Default `g_obj_clip`, `WIN_SRC_X=0`, and `WIN_SRC_Y=0` leave pre-existing screens pixel-identical.
- [ ] Fine source scrolling reproduces the GB mod-256 wrap on both axes, proven by the A1 wrap harness.
- [ ] The title bounce is pixel-smooth and its wrapped/overshoot frames match mGBA rendered pixels.
- [ ] Yellow scrolling scenes visibly scroll, with multi-offset host-frame evidence.
- [ ] Splash, title, Oak, and Yellow timing traces match mGBA record by record.
- [ ] The title golden uses the defined post-bounce, open-eye checkpoint.
- [ ] Title timeout and soft reset replay the power-on movie through `Init`.
- [ ] Audio uses live engines; only `PlayCry` remains silent.
- [ ] Palette commands and fades are live.
- [ ] `OakSpeech`, `PlayIntro`, `PlayIntroScene`, `PlayShootingStar`, `SpawnAnimatedObject`, and `CopyUncompressedPicToTilemap` have linked non-stub providers.
- [ ] `InitPlayerData2` has one linked provider and no orphan or duplicate module.
- [ ] `main_menu_stubs.asm` no longer defines `OakSpeech`.
- [ ] `SKIP_TITLE` remains minimal and noninteractive.
- [ ] CONTINUE preserves loaded state and does not run new-game initialization.
- [ ] `EnterMapBoot` follows the measured route contract.
- [ ] The A1 decomposed performance contract passes.
- [ ] `title`, `title_reentry`, `title_timeout`, `continue_seed`, `main_menu`, `oak_intro`, and `gamefreak_intro` pass.
- [ ] All 18 Yellow-scene scenarios pass.
- [ ] Native visual evidence is retained for every frame-yielding Yellow scene.
- [ ] `fidelity`, `fidelity-full`, and `goldens-verify` pass.
- [ ] Human smoke acceptance is recorded under the defined standard.
- [ ] Every observed failure has an automated regression or the required manual external-output record.
- [ ] Strict label and annotation lint reports no stale extern, malformed annotation, or duplicate provider.
- [ ] Related false `TODO-HW`, stub, allowlist, plan, and status claims are corrected.
- [ ] The plan is archived as `docs/plans/menu_intro.md`.
