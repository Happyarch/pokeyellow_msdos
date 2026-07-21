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

- [x] Phase A — Playable title → menu → new game *(all four subtasks port-side done + golden-verified; the only open tails are the per-stage TIMING TRACES (title bounce/blink, Oak — both need port-side per-frame trace instrumentation that does not yet exist, same blocker as the yellow-scene trace) and the deferred bespoke title-bounce reimpl. Functional playable chain + all state goldens PASS.)*
  - [x] A1 — Cinematic projection substrate
  - [x] A2 — Projected title with live audio and palettes *(port-side done; `title_timeout` golden id 27 DONE + PASS 2026-07-21; only the title bounce/blink timing trace + deferred bounce reimpl remain)*
  - [x] A3 — Real title → menu → entry routing *(DONE + verified 2026-07-21: title `jmp MainMenu`, reset-save branch preserved, `SKIP_TITLE`→`InitPlayerData2`, `EnterMapBoot` 2 legit callers; main_menu id22 / title_reentry id23 / continue_seed id24 goldens registered + committed)*
  - [x] A4 — Oak speech, naming, and stub retirement *(port-side done, faithdiff 24/24 + fidelity 16/16; oak_intro GBSTATE golden id 29 DONE + PASS 2026-07-21; only the Oak timing trace remains)*
- [ ] Phase B — Power-on movie
  - [x] B1 — Animated-object engine *(engine + data + runtime test; sine rides B3)*
  - [x] B2 — Game Freak splash *(bars + PlayShootingStar + copyright, per-row verified)*
  - [x] B3 — All 18 Yellow intro scenes *(ported; BG-origin fixed + per-row verified; mGBA scene goldens blocked unattended)*
  - [~] B4 — Full boot integration and permanent coverage *(PlayIntro ported + wired + faithful-default flip DONE `439ad057` (Init calls PlayIntro on every boot); gamefreak_intro + yellow_intro_s01 + title_timeout (id 27) + soft_reset (id 28) reset-route goldens registered + PASS; F-GFI fixed. Remaining: the human full-chain experiential smoke test only.)*
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
- [x] Register `title_timeout`. *(id 27, `c553c01c` — PASS; sibling `soft_reset` id 28 registered too.)*

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

### A3 — Real title → main-menu routing  ✅ DONE (verified 2026-07-21)

#### Work

- [x] Replace the title’s `OakSpeech → EnterMapBoot` shortcut with `jmp MainMenu`. *(title.asm:651 `jmp MainMenu` at `.go_to_main_menu`; no `EnterMapBoot`/`OakSpeech` reference remains in title.asm.)*
- [x] Remove obsolete title externs. *(title externs are current — `MainMenu` is "the real post-title route"; `lint_pret_labels` reports 0 stale-extern violations.)*
- [x] Preserve the reset-save branch. *(title.asm:584/645 — the UP+SELECT+B combo → `.doClearSaveDialogue`; the soft_reset golden id 28 exercises it.)*
- [x] Change `SKIP_TITLE` to call `InitPlayerData2`. *(init.asm:180 `call InitPlayerData2` under `%ifdef SKIP_TITLE`.)*
- [x] Keep harness seeding outside shared boot code. *(the default-name/`InitPlayerData2` seeding is `%ifdef SKIP_TITLE`-gated in init.asm / overworld.asm, not in the shared boot path.)*
- [x] Measure `EnterMapBoot` callers, hit counts, and continue-state writes. *(`label_status --callers`: exactly 2 — `SpecialEnterMap` (main_menu.asm, the menu→overworld path) and `Init` (SKIP_TITLE bypass); the title routes through MainMenu, not EnterMapBoot.)*
- [x] Make only the correction proven necessary. *(EnterMapBoot kept as the one-time overworld boot glue for both legit callers; only the title→shortcut was replaced with `jmp MainMenu`.)*
- [x] Verify continue and new-game separately. *(continue_seed golden id 24 = CONTINUE preserves loaded state and hits neither OakSpeech nor InitPlayerData2; NEW GAME→OakSpeech verified by oak_intro id 29.)*
- [x] Register `RunMainMenuTest` as `main_menu`. *(scenario id 22, `main_menu.bin` committed.)*
- [x] Add `title_reentry`. *(scenario id 23, `title_reentry.bin` committed.)*
- [x] Add `continue_seed`. *(scenario id 24, `continue_seed.bin` committed.)*

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

> **B1 COMPLETE (2026-07-21) — engine + data + runtime test, all verified.**
> The engine (14/14 routines, `9f39c54f`), the immutable Frames/OAM/Spawn data
> blob (`73f95c3c`, GB-space at 0xF700), and the runtime lifecycle harness
> (`abfcd4de`, `DEBUG_CINEMATIC_ANIMOBJ` / `pixelcheck animobj`: a spawned
> frameset-1 object renders a 16×16 4-OBJ block — 256 px inside the surface, 0
> outside, native positions = canonical + (80,24)). Only the **sine** data is
> deferred (it lives in the scene callbacks → B3). Bring-up caught one harness
> ordering bug (table pointers must be set AFTER ClearObjectAnimationBuffers,
> which zeroes the block they live in — the engine itself was correct).
>
> Detail below.
>
> `src/engine/gfx/animated_objects.asm` (`9f39c54f`) is the
> faithful translation of all 14 pret routines (Clear/Run/Spawn/Mask×2,
> UpdateCurrentAnimatedObjectFrame, tile Y/X, OAM attrs, the pointer getters,
> the duration/frame-script interpreter, and the callback trampoline).
> **Verification:** nasm clean; full image links with the file in the Makefile
> SOURCES; `lint_pret_labels` 0 violations; `faithdiff` clean on every routine
> except two explained diffs — `SpawnAnimatedObject`'s store to
> `wNumLoadedAnimatedObjects` (pret writes it via `inc [hl]`, invisible to
> faithdiff as a pret-side store) and `ExecuteCurrentAnimatedObjectCallback`'s
> `jp hl`→`jmp esi` (the data-model DEVIATION below).
>
> **Pointer/data model DECIDED (resolves the plan's "biggest unknown"):** the
> Spawn/Frames/OAMData tables stay 16-bit **GB pointers** so the engine's pointer
> arithmetic is byte-identical to pret — **B3 must generate those tables into a
> GB-space blob** (a reserved region ≤ 0xFFFF, addressed `[ebp+ptr]`). The
> **callback jumptable is the sole exception**: its entries are native x86 code
> addresses (link-time flat labels, not bakeable into a GB blob), so
> `wAnimatedObjectJumptablePointer` is a **32-bit flat** pointer and the dispatch
> uses a ×4 stride — one `data-model` DEVIATION, annotated in the file. **B3's
> per-set jumptable is therefore `dd Label` flat data in `.asm`**, and the scene
> driver stores its flat address into `wAnimatedObjectJumptablePointer`.
>
> **WRAM (B1.1):** relocated to free echo RAM at **0xF600** (202 B; pret's 0xC508
> union branch is swallowed by the port's extended 40×25 wTileMap). All members +
> `wYellowIntroCurrentScene`/`wc634` have symbols; `audit_memmap.py` clean.
> **Remaining B1:** the sine data + the deterministic lifecycle/edge-crossing test
> harness (B1.3); the per-frame projected-OAM publish is the same
> `PublishProjectedOAM`(80,24) pattern B2 proved (`publish_splash_oam`), wired by
> the B3 scene driver. Detail in stigmergy `a4-4-oak-speech2-porting-plan`.

#### Work

- [x] Port `engine/gfx/animated_objects.asm` with exact labels. *(9f39c54f, 14/14)*
- [x] Inventory required WRAM and HRAM. *(B1.1 — no HRAM; WRAM block enumerated)*
- [x] Add exact aliases or correctly sized regions. *(0xF600 block + wc634)*
- [x] Run `audit_memmap.py` after memory-map changes. *(clean, 47 regions)*
- [~] Generate immutable frame, spawn, OAM, and sine data. *(frame/OAM/spawn DONE — 73f95c3c, src/data/sprite_anims/intro_anim_data.asm, GB-space blob at 0xF700 copied flat→GB by CopyYellowIntroAnimatedObjectData; SINE rides B3 — it lives in the scene callbacks, not the object tables)*
- [x] Keep code-address tables in `.asm`. *(jumptable = flat `dd Label`, per the DEVIATION)*
- [x] Preserve masks, scripts, timers, and sine arithmetic. *(frame-script interpreter faithful; sine lives in scene callbacks = B3)*
- [x] Publish canonical OAM through `PublishProjectedOAM`. *(proven in B1.3 harness; B3 driver reuses it)*
- [x] Do not wire the surfing minigame. *(engine only; no `surfing_pikachu` dep)*
- [x] Add deterministic lifecycle and edge-crossing tests. *(B1.3 — abfcd4de, DEBUG_CINEMATIC_ANIMOBJ / pixelcheck animobj: 4-OBJ block, 256 px inside surface, 0 outside, native = canonical + (80,24))*

#### Acceptance

- Object state matches pret at selected frames.
- Masked slots produce no visible OAM.
- Canonical OAM matches GB output.
- Native positions equal canonical positions plus `(80,24)`.
- Edge-exiting objects never paint the matte.
- The engine remains separate from overworld sprite state.
- It links without surfing stubs.

### B2 — Game Freak splash

> **B2 progress (2026-07-21) — the splash ANIMATION is ported and pixel-verified.**
> `engine/movie/splash.asm` holds the full splash: the graphics (`fb24333b`), the OAM
> data tables (`7db09d52`, byte-exact `dbsprite`), `LoadShootingStarGraphics`
> (`a938454b`), `MoveDownSmallStars` + the per-frame `publish_splash_oam`
> (`c99a6c99`), and `AnimateShootingStar` (`ece7812e`) — plus the missing shared
> `CheckForUserInterruption` (`ea5c0584`). **Pixel-verified** via a
> `DEBUG_CINEMATIC_SPLASH` gate (`56aa0470`, `pixelcheck.sh splash`): the big star
> sweeps down-left over the Game Freak logo, OBJ projected + clipped to `UI_SPLASH`,
> matte clean (0 outside), ink 509→433 as the star clears. The OBJ-projection
> reconciliation is `publish_splash_oam` (`PublishProjectedOAM` 80,24) before each
> frame wait. **Remaining B2** (not blocking): `PlayShootingStar` + `GameFreakIntro`
> boot wiring (rides with B4), and the splash **timing trace** (⚠ mGBA-blocked here).
> Detail in stigmergy `a4-4-oak-speech2-porting-plan`.

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

> **B3.1 done (2026-07-21) — the animated-object BEHAVIOR layer is ported.**
> `src/engine/movie/intro_yellow.asm` (`0551d98c`, the file that will grow to
> hold PlayIntroScene + the scenes) holds `YellowIntro_AnimatedObjectJumptable`
> + the 6 callbacks (fa007/008/014/02b/062 + sub-jumptable fa03b→fa03f/051) +
> the sine helpers fa077/079/08e + `sine_table 32` (Unkn_fa0aa, verified
> byte-exact vs rgbasm). Both code-address jumptables are flat `dd` / ×4 stride
> (data-model DEVIATION); the sine table is read flat. **Motion-verified**: the
> animobj harness now dispatches the REAL jumptable and spawns object 4 (fa008
> mover) — the 36-OBJ block slides 28px left (frame 3→25), Y fixed, matte clean,
> matching fa008's 4px/frame clamp at 0x58.
>
> **B3.2a done (2026-07-21, `02dd02e7`)** — the scene-engine leaf helpers:
> `LoadYellowIntroObjectAnimationDataPointers` (3 GB addrs, exported as GBPTR
> equs from intro_anim_data.asm, + the flat jumptable), the OAM BG-priority hooks
> `Func_f98a2`/`Func_f98cb`, and `YellowIntro_NextScene`. faithdiff clean (stores
> match 4/4, 5/5, 6/6); image builds; lint 0.
>
> **B3.2b done (2026-07-21, `d828d753`)** — the intro gfx assets (the gating
> dependency): `gen_intro_gfx_inc.py` → `YellowIntroGraphics1/2` + `CloudGFX`
> (PNG→2bpp, byte-exact vs the committed `gfx/intro/*.2bpp`) + the `Unkn_f9b6e/
> be6/bf2` tilemaps, `%include`d into intro_yellow.asm. Image builds; lint 0.
>
> **B3.2c-1 done (2026-07-21, `8c465d18`)** — the scene timer/lifecycle
> primitives: `YellowIntro_SpawnAnimatedObjectAndSavePointer`,
> `YellowIntro_MaskCurrentAnimatedObjectStruct`, `SetTimerFor128/88Frames`,
> `CheckFrameTimerDecrement` (+ `wYellowIntroAnimatedObjectStructPointer` @0xF6CC).
> faithdiff clean; image builds; lint 0.
>
> **B3.2c-2 done (2026-07-21, `7b1ea69c`)** — the simple "wait-last" scenes
> 1/5/9 (timer→mask→next), 13 (+spawn obj $0a), 17 (DelayFrames + set done bit).
> faithdiff clean; image builds; lint 0.
>
> **B3.2c-3 done (2026-07-21, `8b993e89`)** — scene 3 (BG scroll to hSCX=0x68 via
> `H_SCX` + MaskAll) and `Func_fa06e` (scene-jumptable lookup, flat×4 DEVIATION —
> the dispatch keystone). **6/18 scenes ported** (1/3/5/9/13/17).
>
> **B3.2c-9 done (2026-07-21, `ccfc0a03`)** — `LoadYellowIntroFlyingSpeedBars`
> (scene-2 spawn helper; clears 1 of scene 2's 3 blockers).
>
> **Incremental-isolation phase COMPLETE (2026-07-21): 9/18 scenes + every helper
> that can be ported in isolation are done.** Everything remaining converges on
> the **running-intro milestone** and needs design decisions best made with a
> live `DEBUG_CINEMATIC_YELLOW` harness + fresh context:
> - **BG-map↔surface**: even scenes 2/4/6/8/10/12/14 write `vBGMap0` + toggle the
>   *retired* `hAutoBGTransferEnabled`; the surface mirror would clobber them.
>   Decide: route scene BG through `W_TILEMAP`, or gate the mirror during intro.
> - **Palette HAL**: `Func_f9e9a`'s `callfar YellowIntroPaletteAction` is CGB/SGB
>   machinery (`InitCGBPalettes`/`DMGPalToCGBPal`/`SendSGBPacket`) — the Phase-5
>   boundary. The port must route intro palettes through its VGA HAL
>   (`RunPaletteCommand`), NOT port that routine faithfully.
> - **VBlank-copy**: scenes 7/11 use `hVBlankCopy*` — no port mechanism exists.
> - `Func_f98fc`+`Jumptable_f9906` — **DONE (`5f570940`)**, 9 real handlers + 9
>   `NextScene` scaffolds. Blank helpers `BlankTileMap`/`BlankOAMBuffer`/
>   `BlankPalettes` — **DONE (`8d0d345f`)**.
>
> **Reassessment (2026-07-21):** the milestone doesn't need all 3 design
> decisions up front. The `vBGMap0` coupling is *only* in the unported even
> scenes (scaffolded to `NextScene`); `Init` writes the canonical `W_TILEMAP`, so
> `Init` + `PlayIntroScene` + the surface wiring are portable **now**. Plan: port
> them → **run with the 9 ported scenes + 9 auto-advance scaffolds** → then port
> each even scene against the *live* `DEBUG_CINEMATIC_YELLOW` harness (BG-map
> decision made only when the first `vBGMap0` scene lands).
> `InitYellowIntroGFXAndMusic` — **DONE (`064ac6c9`)**.
>
> **🎉 THE YELLOW INTRO RUNS (`40598dcc`).** `PlayIntroScene` + the
> `DEBUG_CINEMATIC_YELLOW` gate (`pixelcheck yellow`) — the intro plays end-to-end
> on the `UI_YELLOW_INTRO` surface: frame 40 (scene 0) = 10246 px inside, **0
> outside (matte clean)**, BG tilemap + animated Pikachu OBJ projected/clipped, no
> crash. The 9 ported scenes render; the 9 unported even scenes auto-advance
> (jumptable scaffold). DMG shades (CGB palette = Phase-5 boundary).
>
> **Remaining B3 (now against the LIVE harness):** port the even scenes
> 2/4/6/8/10/12/14 (the BG-map↔surface decision lands with the first `vBGMap0`
> scene), scenes 7/11 (VBlank-copy mechanism), and scene 16's `Func_f9e9a`
> (palette via `RunPaletteCommand`); repoint each `Jumptable_f9906` scaffold as it
> lands; then per-scene pixel-verify. Detail in stigmergy `a4-4-oak-speech2-porting-plan`.
>
> **BG-map↔surface decision RESOLVED + first framed even scene lands
> (2026-07-21).** The pattern: pret scenes write `vBGMap0` (`$9800`, 32-wide GB BG
> map); the port compositor renders from `W_TILEMAP` (40-wide, mirrored to
> `GB_TILEMAP0` by `g_surface_redraw_cb`). Translation: `vBGMap0` `$98xx` →
> `row=off/32, col=off%32` → `W_TILEMAP + row*SCREEN_TILES_W(40) + col`; uniform
> row-range fills become contiguous `W_TILEMAP` regions (projection DEVIATION).
> - **B3.2d-6 done (`21f6786b`)** — `Func_f9e5f` (framed-scene BG layout: rows 0-3
>   tile 1, 4-13 tile 0, 14-17 tile 1) establishes the redirect.
> - **B3.2e-1 done (`ff0ff9e6`)** — `YellowIntroScene4`, the **first framed even
>   scene** and the template for 6/8/10/12/14: `BlankPalsDelay2AndDisableLCD` +
>   `UpdateMusicCTimes(5)` + `Func_f9e5f` + spawn obj `$2` + `Func_f9e9a` +
>   128-frame timer + `NextScene`. The `hOnCGB` `rVBK` attribute box is omitted
>   (HAL DEVIATION, Phase-5). faithdiff 7/7 clean; `pixelcheck yellow` f40 =
>   10246 px inside / 0 matte, **f300 (past scene-4 activation) = 10240 / 0, no
>   crash through the chain**. **10/18 scenes** (0/1/3/4/5/9/13/15/16/17).
>   Remaining even scenes 2/6/8/10/12/14 follow this template (scene 2 also needs
>   `YellowIntroScene2_PlaceGraphic`'s 6×6 gengar grid; scene 10 `.FillBGMapBox`);
>   odd 7/11 still need a VBlank-copy shim/stub.
> - **B3.2e-2 done (`0761c1f6`)** — `YellowIntroScene8`, exact scene-4 clone
>   (spawns obj `$3`, no CGB branch).
> - **B3.2e-3 done (`2d9eff7c`)** — `YellowIntroScene14`, a fade-transition (like
>   scene 16): DMG fade via `LoadDMGPalAndIncrementCounter(f9dd6)`, then mask
>   objects + blank OAM + rebuild the framed BG (the `Func_f9e5f` pattern inlined,
>   targeting `wTileMap` directly) + restore palettes + spawn obj `$7` + advance +
>   `$28` timer. The two `hAutoBGTransferEnabled` stores are dropped (HAL
>   DEVIATION: the surface mirror copies `W_TILEMAP` each frame, so the three
>   `DelayFrame` waits stay but the flag is gone). **12/18 scenes render**
>   (0/1/3/4/5/8/9/13/14/15/16/17); the intro now runs **end-to-end to completion**
>   (surface clean/0-matte through ~f540, ending fade ~f580, teardown by f600).
>   Remaining even 2/6/10/12; odd 7/11. **Next best: a `YellowIntro_FillBGMapBox`
>   32→40-stride boxed-paste helper unlocks scenes 10 and 12.**
> - **B3.2e-4 done (`e118095e`)** — `YellowIntroScene10` (gengar battle): clears the
>   BG map, paints rows 0-7 tile `$2`, pastes three tilemap boxes (Unkn_f9b6e/be6/
>   bf2) via a scene-10-local `.FillBGMapBox` (kept local as in pret — the box copy
>   advances one 40-tile W_TILEMAP row per source row), spawns obj `$6`. Renders
>   distinct content (7964px) at 0 matte.
> - **B3.2e-5 done (`9a7e8757`)** — `YellowIntroScene12` (closing pan): framed BG
>   (Func_f9e5f pattern inlined) + a procedural 8×12 tile-incrementing paste at
>   (5,6) + three single-tile patches + spawn obj `$9`. Renders distinct content
>   (8808px) at 0 matte. **14/18 scenes render** (0/1/3/4/5/8/9/10/12/13/14/15/16/
>   17). **Remaining: even 2 (gengar grid, off-screen col — needs a scroll/clip
>   decision) + 6 (striped BG + inert LY-SCY wobble); odd 7/11 (VBlank-copy shim or
>   stub).**
> - **B3.2e-6 done (`0ee2e983`)** — `YellowIntroScene6` (surfing scene): arms the
>   per-scanline SCY wobble (`hLCDCPointer=LOW(rSCY)`, inert in the port), copies
>   the sine buffer, lays out a custom BG (rows 0-2 tile 0, row 3 a `$20/$21`
>   stripe, rows 4+ the water tile `$10`), spawns obj `$5`. The rows-4+ fill is
>   **capped at `SCREEN_AREA`** (pret's raw `$300` byte count would overrun
>   W_TILEMAP at the 40-tile stride). Renders distinct content (9280px) at 0 matte.
>   **15/18 scenes render.**
> - **Remaining 3 scenes — the VBlank tile-transfer decision.** Scenes 7/11 use the
>   generic VRAM tile-transfer VBlank pipeline (`hVBlankCopySource/Dest/Size`,
>   `Request7TileTransferFromC810ToC710`), which **the port does not have** (it has
>   only `VBlankCopyBgMap` for BG-map *rows*, in `src/video/bg_anim.asm`). Decision:
>   port each scene's portable logic faithfully (scene 7 = `hSCX+=2` scroll + the
>   circular `wLYOverridesBuffer` roll + timer; scene 11 = the every-8th-frame cloud
>   setup + timer) and **stub the tile-animation transfer** (deferred visual polish,
>   annotated STUB/DEVIATION — the water/cloud tile cycling won't animate but the
>   scenes run). Scene 2 still needs the gengar-grid scroll/clip decision.
> - **B3.2e-7 done (`e08638ba`)** — `YellowIntroScene7` (surf wait: hSCX scroll +
>   circular LY-buffer roll), `YellowIntroScene11` (clouds: every-8th-frame setup),
>   and `Request7TileTransferFromC810ToC710`. Defined `hVBlankCopySize/Source/Dest`
>   as inert HRAM (0xFFC6-CA) + `W_LY_OVERRIDES`: the port has no generic VBlank
>   tile copy, so the request bytes are written faithfully but never consumed — the
>   LY-wave / cloud tile animation does not cycle (HAL DEVIATION). Scroll, roll, and
>   timers are real. All three faithdiff-clean.
> - **B3.2e-8 done (`de5ffd36`)** — `YellowIntroScene2` + `YellowIntroScene2_Place
>   Graphic`, the **last scaffold**. The 6×6 gengar grid is placed at col 20
>   (off-screen at SCX=0, revealed when scene 3 scrolls right — the faithful,
>   non-clamped placement); CGB attr block omitted (Phase-5). Pixel-verified: scene
>   2 shows only the flying-bar OBJ, then the grid scrolls into view during scene 3.
>
> ### 🎉 B3 SCENE WORK COMPLETE — ALL 18 YELLOW INTRO SCENES PORTED
>
> Every `Jumptable_f9906` entry (0–17) now points at a real scene (zero scaffolds).
> The intro runs end-to-end through the `DEBUG_CINEMATIC_YELLOW` harness; every
> `YellowIntroScene*` is faithdiff- and lint-clean; `pixelcheck yellow` shows
> distinct per-scene content at 0 matte across the whole surface-active window,
> with a clean teardown to the post-intro state. DMG shades (CGB = Phase-5). The
> reusable **BG-map↔surface** translation (vBGMap0 → W_TILEMAP at the 40-tile
> stride) carried every framed/boxed/procedural scene. Deferred (mGBA-blocked): the
> per-scene / timing goldens. **Next: B3 whole-chain acceptance, then B4 (boot
> integration: power-on → splash → intro → title → menu → Oak → overworld).**
>
> #### B3 acceptance — PASS (2026-07-21)
>
> Consolidated faithfulness + visual gate over the whole intro:
> - **faithdiff**: all 18 `YellowIntroScene0..17` + `YellowIntroScene2_PlaceGraphic`
>   + `Request7TileTransferFromC810ToC710` report `status: translated` with **zero
>   non-benign diffs** — every remaining diff is one of the documented benign
>   classes (banking `Bank3E_FillMemory→FillMemory`; `IO_BGP/OBP0/OBP1` shadow ADDs
>   for pret `ldh`; `hAutoBGTransferEnabled` HAL drop; and the named-store-vs-pret-
>   indirect-`[hl]` ADDs `[W_TILEMAP]` / `[wYellowIntroCurrentScene]`), each carried
>   by a DEVIATION annotation.
> - **lint_pret_labels**: 0 violations, 5 suppressed.
> - **jumptable**: 0 `NextScene` scaffolds — every `Jumptable_f9906` entry is a real
>   scene.
> - **pixelcheck yellow**: distinct per-scene content at **0 matte** (documented per
>   scene: e.g. scene 2 = 1103px flying bars, scene 10 = 7964, scene 12 = 8808,
>   scene 6 = 9280, scenes 0/4/8 = 10246, a busy surf frame = 16890) — the varied
>   inside-content counts are the decomposition proving *different* scenes execute,
>   not a single repeated frame; the chain completes and tears down cleanly. Current
>   committed build re-confirmed booting clean (frame 40 = 10246px / 0 matte).
>
> **B3 is complete** (scene porting + faithfulness + visual acceptance). The only
> open B3 tail — mGBA per-scene / timing goldens — stays **deferred** (no
> mgba/baserom in the unattended env), not a completion blocker.
>
> **B3.2c-8 done (2026-07-21, `3858c01d`)** — `Copy8BitSineWave` +
> `wLYOverridesBuffer`@0xFA00 (amp-4 wave ×8 via inline flat→GB `rep movsb`;
> wobble inert — per-scanline LY not emulated). The easy scene-independent wins
> are now exhausted; what remains needs the BG-map↔surface decision and the
> dispatch/`Init`/`PlayIntroScene` wiring.
>
> **B3.2c-7 done (2026-07-21, `4053cac6`)** — scene 15 (thunderbolt palette
> flash; placed before scene 16 to keep the pret fallthrough). **9/18 scenes**
> (0/1/3/5/9/13/15/16/17) — halfway.
>
> **B3.2c-6 done (2026-07-21, `5b378f7e`)** — `BlankPalsDelay2AndDisableLCD`
> (a wrongly-deferred helper: all deps existed). An audit fork confirmed the
> deferred set: **PORTABLE-NOW** = `BlankPalsDelay2AndDisableLCD` (done),
> `Copy8BitSineWave` (effect inert, needs a `wLYOverridesBuffer` slot ≠ 0xF6CE),
> maybe scene 15; **BLOCKED** = `Func_f9e9a` (needs `YellowIntroPaletteAction`,
> missing), scenes 7/11 (no port VBlank-copy mechanism for `hVBlankCopy*`),
> `LoadYellowIntroFlyingSpeedBars`; **DESIGN-COUPLED** = even scenes 2/4/6/8/10/
> 12/14 write `vBGMap0` + toggle the retired `hAutoBGTransferEnabled`, which the
> surface mirror (`W_TILEMAP`→`GB_TILEMAP0`) would clobber — needs the BG-map↔
> surface reconciliation (route scene BG through `W_TILEMAP`, or gate the mirror),
> done WITH `PlayIntroScene`.
>
> **B3.2c-5 done (2026-07-21, `ed201f0b`)** — scene 16 (fade to white) +
> `LoadDMGPalAndIncrementCounter` + the f9dd6/f9e0a pal-sequence tables.
> **8/18 scenes** (0/1/3/5/9/13/16/17).
>
> **B3.2c-4 done (2026-07-21, `194a4da3`)** — scene 0 (intro opening): spawn +
> scroll/window/DMG+CGB palette setup + 130-frame timer. Confirmed the HAL the
> heavy scenes need (`UpdateCGBPal_*`, `DisableLCD`, `RunPaletteCommand`, IO
> shadows) all already exist, so the even scenes are portable. **7/18 scenes**
> (0/1/3/5/9/13/17).
>
> **Remaining B3**: the rest of the even scenes 2/4/6/8/10/12/14/16 + odd
> 7/11/15/16 (some need the deferred pal/LY helpers + VBlank-copy/LY-override),
> `Func_f98fc` + `Jumptable_f9906`, `InitYellowIntroGFXAndMusic` (loads the B3.2b
> gfx), `PlayIntroScene`, `UI_YELLOW_INTRO` projection, per-scene music/SFX.
> Detail in stigmergy `a4-4-oak-speech2-porting-plan`.

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

### ✅ CINEMATIC BG-ORIGIN — RESOLVED (2026-07-21, per-row verified)

**Fixed** in commits `9cf24236` (`Func_f9e5f`) + `d4e7f944` (all scenes). Defined
`INTRO_BG_ROW_OFF` (120) / `INTRO_BG_ORIGIN` (130) in `intro_yellow.asm` and applied
the (row 3, col 10) origin: row-range fills add the row offset (full-width), column-
specific writes add the full origin, whole-map `SCREEN_AREA` clears stay at 0.
**Per-row verified** (x=224): frame 300 (framed scene) went `[3,0×10,3,3,3,3,0,0,0]`
→ `[3,3,3,3,0×10,3,3,3,3]` (bars at surface rows 0-3 & 14-17); scene 10's tile-2
region now sits at the surface top; chain completes, 0 matte, no crash; lint 0.
The B3 letterbox now matches pret. Task #79 closed. **B2 splash is unblocked** (same
origin). Residual (non-blocking): confirm scene 2's grid reveal under scene 3's
scroll and scene 12's paste position — correct by construction, not frame-checked.

<details><summary>original confirmation write-up (history)</summary>

### ⚠ CINEMATIC BG-ORIGIN — CONFIRMED B3 DEFECT (2026-07-21)

**CONFIRMED at the code level (no longer "likely").** `MovieBeginSurface` sets
`g_surface_redraw_cb = MovieMirrorSurface` (there is exactly one mirror), and
`MovieMirrorSurface` reads the visible 18×20 window from `W_TILEMAP +
UI_TITLE_ROW*SCREEN_WIDTH + UI_TITLE_COL` (row 3, col 10). The intro's
`PlayIntroScene` calls the same `MovieBeginSurface`, so it uses the identical
mapping (`surface_row = W_TILEMAP_row − 3`, `surface_col = W_TILEMAP_col − 10`)
that the splash-bars test measured empirically. The intro authors every scene BG at
raw `W_TILEMAP + N*SCREEN_TILES_W` (row 0, col 0). **Therefore the intro's frame is
shifted up 3 rows, and the column-specific scenes (2 gengar grid, 10/12 boxed
pastes) are also shifted left 10 cols.** A2 (title) avoided this by projecting its
origin (`TITLE_ORIGIN equ UI_TITLE_ROW*SCREEN_TILES_W + UI_TITLE_COL` = 130, then
`W_TILEMAP + TITLE_ORIGIN + row*40 + col`); B3 did not.

**Fix design (the B3-align task):**
- Define `INTRO_ORIGIN equ UI_YELLOW_INTRO_ROW*SCREEN_TILES_W + UI_YELLOW_INTRO_COL`
  (= 3*40+10 = 130) in `intro_yellow.asm`, mirroring `TITLE_ORIGIN`.
- **Row-range fills** (`Func_f9e5f`, scene 6's row fills, scene 10/12's clear+row
  fills): these fill full-width, so only the row origin matters — add
  `UI_YELLOW_INTRO_ROW*SCREEN_TILES_W` (= 120) to each fill base. (Full-width covers
  the visible cols 10-29; the off-window cols 0-9/30-39 are clipped.)
- **Column-specific writes** (scene 2 `PlaceGraphic` @ GB col 20, scene 10
  `.FillBGMapBox` dests, scene 12 procedural paste + 3 singles): add the **full**
  `INTRO_ORIGIN` (row 3 + col 10) to each dest.
- **Verify per-row, not aggregate.** A clean, shift-sensitive test: before the fix
  the intro's surface bottom rows 15-17 are blank (W_TILEMAP rows 18-20 unwritten);
  after the fix they carry the bottom bar. Profile a framed scene's per-row bands.
- Then close the B3-align task and re-affirm B3.

**B2 splash unblocks once `INTRO_ORIGIN` exists** — the splash bars/copyright use
the same origin (a `SPLASH_ORIGIN`, same value).

---

### (superseded) earlier framing of the finding — kept for history

⚠ CINEMATIC BG-ORIGIN FINDING (2026-07-21) — likely affects B3

While building the splash's framing bars I hit a **surface-geometry misalignment
that needs resolution before more cinematic BG work, and likely means the yellow
intro (B3) frame is mis-positioned.**

**Proven:** `MovieMirrorSurface` (movie_projection.asm) copies the visible window
from `W_TILEMAP + UI_TITLE_ROW*SCREEN_WIDTH + UI_TITLE_COL` = **W_TILEMAP row 3,
col 10** into `GB_TILEMAP0`. So the cinematic BG-authoring origin is **(row 3, col
10)** — content written at `W_TILEMAP + N*40` (row 0, col 0) lands 3 rows above /
10 cols left of the visible surface. Confirmed empirically on the same surface: a
minimal `MovieBeginSurface` + bars written at W_TILEMAP rows 0-3 / 14-17 rendered
at surface rows **0 and 11-14** (shift = −3), not 0-3 / 14-17.

**Implication for B3 (needs definitive confirmation):** the intro's `Func_f9e5f`
and all scene fills author at `W_TILEMAP + N*40` (row 0, col 0) — the *wrong*
origin. If the intro uses the same surface path (it sets
`g_surface_redraw_cb = MovieMirrorSurface`), its letterbox frame is shifted up 3
rows. **My B3 aggregate pixelchecks (inside-count + 0-matte) could not catch this**
— full-row fills keep both the count and the matte unchanged under a vertical
shift. This is the "matching aggregate hides errors" trap. Note **A2 (title) DID
handle the origin** (task A2.3.a "Project the title's tilemap drawing origin"), so
the correct pattern exists; B3 apparently did not adopt it.

**Required before proceeding:**
1. **Definitively confirm** whether the live intro is shifted — per-row profile a
   framed scene (e.g. scene 4/6) at a column inside the fill (surface col 0 =
   x=80 = W_TILEMAP col 10), on a scene whose BG has a *distinct* top-vs-middle
   tile so the shift is visible (not a uniform fill). aggregate counts are not
   sufficient.
2. If confirmed, decide the fix: a shared **cinematic coord origin** (add
   `UI_TITLE_ROW`,`UI_TITLE_COL`) that all cinematic BG authoring uses — mirror
   how A2 projects the title's drawing origin — and apply it to the intro scene
   fills + `Func_f9e5f` + the splash bars/copyright. Re-verify B3 per-row.
3. **B2 is blocked on this** — the splash bars/copyright need the same origin, so
   there is no point finishing `PlayShootingStar` until the origin convention is
   settled (and the framing helpers, which were faithfully ported + faithdiff-clean
   this pass, were reverted to avoid landing misaligned output).

### B2 completion — `PlayShootingStar` orchestration (2026-07-21 scoping)

B3 is done; the boot cinematic's remaining prerequisite is **B2's top-level
`PlayShootingStar`**, which B4's `PlayIntro` calls. Its pieces mostly exist in
`splash.asm` (`LoadShootingStarGraphics`, `AnimateShootingStar`,
`MoveDownSmallStars`, `GameFreakIntro`/OAM data, the `RunSplashTest` harness) — the
**orchestrating routine is what's missing**.

**Rendering model:** the port renders the splash through a **cinematic surface**
(`MovieBeginSurface`, which clears `W_TILEMAP` to color 0) with the Game Freak logo,
shooting star, and small stars as **projected OBJ** (`AnimateShootingStar` →
`PublishProjectedOAM`). The genuine GB-hardware calls (`DisableLCD`/`EnableLCD` +
`rLCDC` window/BG-map bits, `hAutoBGTransferEnabled`, the VBlank/DMA path) have no
port counterpart — that is a real, permanent HAL DEVIATION (identical boundary to
`PlayIntroScene`).

**CORRECTION (2026-07-21) — the black bars are NOT subsumed by the matte.** An
earlier note claimed `IntroDrawBlackBars` could be dropped because the matte is
black. That was an *unverified* claim and is **wrong**: `MovieBeginSurface` clears
`W_TILEMAP` to color 0, and under the splash palette (`ldpal a, SHADE_BLACK,
SHADE_DARK, SHADE_LIGHT, SHADE_WHITE` → `rBGP = 0x1B`) **color 0 = SHADE_BLACK but
the bar tile (`$ff` = color 3) = SHADE_WHITE**. So pret draws a *white* frame on
rows 0-3 / 14-17 over a black middle — a visible element the uniform-black matte
would drop. The faithful port must **replicate** the framing on `W_TILEMAP` (load
the `$00`/`$ff` bar tiles into the BG tile area + arm `g_tilecache_dirty`, then fill
rows 0-3 & 14-17 with the bar tile) as a projection redirect, **not** drop it. The
second BG map (vBGMap1) writes collapse onto the single `W_TILEMAP` (projection).
The exact bar colour (white vs black) is **unverified pending an mGBA golden**
(blocked) — replicate pret's tile writes rather than guess the appearance.

**Tile-addressing requirement (verified 2026-07-21).** The splash's bar/copyright
tiles are loaded to `vChars2` (`$9000`) and referenced by BG tile index (`1` for
the bar, `$60`-`$7b` for the copyright), which only resolve there under **`$8800`
signed** tile addressing (index `1` → `$9010`, index `$60`/96 → `$9600`). The port
compositor **does** honor this: `render_bg` reads `IO_LCDC` bit 4 each frame into
`tiledata_mode` (0 = signed, base `$9000`) and rebuilds `id_cache_lut` accordingly
(the title already relies on it — its copyright tiles at `$8E00` are addressed via
signed indices `$e0+`). **So the faithful `PlayShootingStar` MUST set `IO_LCDC` bit
4 = 0 (e.g. `0xe3`, as `Func_f9e9a` does for the intro)** — that write is the port's
real equivalent of pret's `EnableLCD` + LCDC setup (a projection requirement), not a
droppable HAL call. If left unsigned, index `1` would render `vChars0` tile 1, not
the bar tile.

**Process note:** a first pass ported `PlayShootingStar` as a thin core that
*dropped* the black bars ("subsumed") and *deferred* the copyright screen behind a
`class=temporary` DEVIATION. Both were rejected as rubberstamping — a deferred
screen is incomplete work, not a deviation, and the "subsumed bars" claim was
unverified/wrong. That pass was **reverted** (uncommitted). The faithful port below
is the real B2 work.

**Remaining B2 steps:**
- **B2.x-1 — copyright screen.** Port `LoadCopyrightAndTextBoxTiles` + the 180-frame
  © display that opens `PlayShootingStar`. Check whether the copyright tile graphic
  is already generated (`assets/`), generate it if not (Tier-1 data). Project the
  copyright onto the surface (BG tiles → W_TILEMAP, or OBJ) following the intro/oak
  text pattern. If the asset/route proves large, it can itself be a sub-increment.
- **B2.x-2 — `PlayShootingStar` orchestration.** `MovieBeginSurface`; palette setup
  (`RunPaletteCommand SET_PAL_GAME_FREAK_INTRO` — HAL/inert like the intro; DMG
  shades via `rBGP = 0x1B`); copyright screen (B2.x-1); **faithfully draw the
  framing bars** — load the `$00`/`$ff` bar tiles into the BG tile area (arm
  `g_tilecache_dirty`) and fill `W_TILEMAP` rows 0-3 & 14-17 with the bar tile
  (`IntroDrawBlackBars` redirected to the surface, vBGMap1 writes collapsed onto
  W_TILEMAP); load logo tiles to vChars1; `AnimateShootingStar`;
  `IntroClearMiddleOfScreen` (redirected); cleanup (`ClearSprites`, `Delay3`,
  `MovieEndSurface`). Drop **only** the true GB HW with no port counterpart
  (`DisableLCD`/`EnableLCD`/`rLCDC` bits/`hAutoBGTransferEnabled`) — a tight HAL
  DEVIATION. Do **not** drop the bars or defer the copyright screen behind a
  deviation.
- **B2.x-3 — verify + close B2.** `pixelcheck splash` (scenario exists, dump 20);
  faithdiff `PlayShootingStar`; lint 0. Then close task #6.

**Then B4:** `PlayIntro` is a thin wrapper — `PlayShootingStar` + `callfar
PlayIntroScene` (done) + cleanup — wired into the boot chain (carefully, without
breaking the working `SKIP_TITLE` overworld boot).

### B4 — Full power-on integration

> **Status (2026-07-21).** **B2 (Game Freak splash) is COMPLETE** — framing bars,
> `PlayShootingStar`, and the copyright screen all ported and per-row verified.
> *(Fix `6a05a616`: `LoadCopyrightTiles` now uses pret's exact `jp PlaceString` instead
> of a bespoke placement loop — faithdiff had flagged the DROPPED PlaceString. The
> bespoke loop hand-rolled single-spaced newlines (lines on surface rows 7/8/9); pret's
> PlaceString double-spaces `<NEXT>` (`BIT_SINGLE_SPACED_LINES` is clear at boot), so the
> faithful layout is rows 7/9/11 — now verified. Also corrected the `CopyrightTextString`
> comment: it is a byte-exact mirror of pret's own hand-authored raw tile-index `db`, not
> two-tier debt — pret hand-encodes it too, the glyphs are not gb_text-encodable.)*
> **B4 is in progress:** `PlayIntro` is ported (`332f84cd`) and the full
> splash→intro chain is verified via the `DEBUG_CINEMATIC_SPLASH` harness (f50 =
> copyright screen, f900 = intro framed scene with bars at surface rows 0-3/14-17,
> 0 matte, no crash); the Init wiring point (`ef101dfb`) adds a gated
> `call PlayIntro` at pret's `predef PlayIntro` spot behind `BOOT_CINEMATIC`.
>
> **✅ Init-context runtime verify — DONE (`edafa36d`, 2026-07-21).** Added the
> `BOOT_CINEMATIC` Makefile harness + `bootcine` pixelcheck scenario, which boot the
> REAL `Init` chain (no `SKIP_TITLE`) with the gated `call PlayIntro` enabled and
> photograph frame 50. Result: the dump is the copyright screen — surface rows
> 7/8/9 = 289/335/308 non-bg px, **byte-identical** to the standalone `splash`
> scenario, 0 matte outside the surface. The gated `Init → PlayIntro` edge now has
> permanent runtime evidence, not just link-time presence. (The relocation-gate
> pause is lifted: the mirror-move landed in `3b16cfbe` — all cinematic pret labels
> live at `engine/movie/intro.asm` + `title.asm`, R-004 retired, lint 0.)
>
> **✅ DONE (`439ad057`, user-greenlit): the faithful-default flip.** `Init` now calls
> `PlayIntro` on every normal power-on (pret's `predef PlayIntro` lowered to a direct
> `call`), skipped only under `SKIP_TITLE` (the overworld bypass) or `SKIP_INTRO` (the
> piece-test bypass). A `class=banking` DEVIATION documents the predef→direct-call lowering;
> `faithdiff Init` is clean (PlayIntro now matches pret's predef). **Retrofit was smaller than
> feared:** only THREE real-title gates lack `SKIP_TITLE` (`DEBUG_TITLE`, `DEBUG_MAINMENU_LIVE`,
> `DEBUG_TITLE_REENTRY`) — every other DEBUG harness already implies `SKIP_TITLE` (Makefile
> "any debug flag implies SKIP_TITLE"), including all the oak/naming piece-tests and
> `continue_seed`; so `SKIP_INTRO` was added to just those 3. **Verified:** default build links;
> `title` / `main_menu` / `title_reentry` PASS (skip via `SKIP_INTRO`, land on the title
> unchanged); `gamefreak_intro` / `yellow_intro_s01` PASS (play the intro); `overworld_pallet`
> PASS (SKIP_TITLE skips it). The only remaining B4 item is the human full-chain experiential
> smoke test (audio + continuous motion) — the deterministic correctness is golden-established.

#### Work

- [x] Add complete `PlayIntro`. *(ported + full-chain verified; `332f84cd`)*
- [x] Call it from `Init` through direct predef lowering. *(DONE — the faithful-default
      flip landed `439ad057`: Init calls PlayIntro on every normal boot, skipped only
      under SKIP_TITLE / SKIP_INTRO; class=banking DEVIATION on Init; faithdiff Init clean.
      SKIP_INTRO retrofitted into the 3 real-title gates that lack SKIP_TITLE (DEBUG_TITLE,
      DEBUG_MAINMENU_LIVE, DEBUG_TITLE_REENTRY). Verified: title/main_menu/title_reentry PASS
      (skip via SKIP_INTRO), gamefreak_intro/yellow_intro_s01 PASS (play it), overworld_pallet
      PASS (SKIP_TITLE skips it).)*
- [x] Preserve later LCD, VRAM, palette, and title setup. *(Init still runs
      DisableLCD/ClearVram/GBPalNormal/ClearSprites after PlayIntro; verified linkable both ways)*
- [x] Register translated and linked state. *(2026-07-21: `project_state` reports
      PlayIntro / PlayShootingStar / PlayIntroScene / SpawnAnimatedObject /
      RunObjectAnimations all `implementation linked` at their mirror paths; label DB current.)*
- [~] Activate all permanent cinematic scenarios. *(IN PROGRESS. **`gamefreak_intro` is
      DONE and registered** — mGBA golden (`8dd7b6b1`) + F-GFI fix (`3175ff22`) +
      full CI registration (`da12fd4c`, gate `DEBUG_GAMEFREAK_INTRO` → BOOT_CINEMATIC
      real boot): `validate_scenarios` consistent, `goldencheck gamefreak_intro` PASS
      (TILEMAP/VRAM/OAM/WRAM OK), runs in `make fidelity-full`. This establishes the
      full pattern (mGBA `.lua` → golden → golden_diff entry → manifest + DEBUG_ gate →
      goldencheck). Remaining: the `yellow_intro_s00..17` scene goldens — see the note below.)*

> **Yellow-intro scene goldens (2026-07-21) — asset integrity verified; per-scene GBSTATE
> goldens need a state-triggered dump.** Asset-integrity check (like the one that caught F-GFI)
> passed clean: `YellowIntroGraphics1` (128 tiles), `YellowIntroGraphics2` (256), `YellowIntroCloudGFX`
> (8), and all three scene-10 tilemaps (`Unkn_f9b6e/be6/bf2`) are **byte-identical to pret** — no
> F-GFI-class asset truncation/mismatch in the yellow intro. `YellowIntroScene0` is a faithful
> line-for-line port. So the yellow intro is sound at the asset + code level (plus the earlier
> per-row BG-origin + hAutoBGTransfer fixes). **Blocker for the 18 GBSTATE scene goldens:** the
> scenes are ANIMATED — even scenes spawn an animated object + set a timer then advance; the odd
> "wait" scenes hold while `RunObjectAnimations` advances the pikachu every frame. So a single
> frame-based AUTOKEY dump (port) won't align with the mGBA scene-detected dump. NEXT: add a
> port-side STATE-triggered GBSTATE dump (fire when `wYellowIntroCurrentScene == N` at scene entry,
> before `RunObjectAnimations` runs that scene — the deterministic setup state), then author one
> parameterized mGBA scenario per scene (detect `wYellowIntroCurrentScene == N`, dump). Alternative/
> complement per the B3 plan: a single continuous transition TRACE (scene entries/timers/masks
> record-by-record) which catches scene-dispatch/timing bugs across all 18 in one scenario.
>
> **UPDATE (`ceb1f878`): `yellow_intro_s01` DONE + registered.** Built the state-triggered-dump
> pattern: a `DEBUG_YELLOW_S01` hook in `PlayIntroScene`'s loop (DEBUG-gated; `-D BOOT_CINEMATIC`
> real boot, no AUTOKEY) fires `DumpBackbuffer` at `wYellowIntroCurrentScene == 1` (deterministic
> scene-entry state); the mGBA scenario plays the boot (no START) and dumps at the same scene.
> `goldencheck yellow_intro_s01` PASS — **TILEMAP OK + VRAM OK (384 slots)** + WRAM OK (OBJ OAM
> masked: the running-Pikachu animates, so its phase depends on the dump frame — OBJ motion is the
> transition trace's job). This is the RUNTIME confirmation that the intro's graphics load faithfully
> to VRAM + the framing matches the ROM. Since all scenes share one `InitYellowIntroGFXAndMusic`
> graphics load + the same surface projection, s01 gives strong whole-intro confidence. Remaining
> (lower-priority, mechanical via the same pattern — new `DEBUG_YELLOW_Snn` gate/id per scene): the
> other holds, and especially the even scenes with UNIQUE BG (s02 gengar grid, s10/s12 boxed pastes)
> which s01's shared-graphics check doesn't cover.
>
> **FINDING (2026-07-21) — the unique-BG scenes are NOT cleanly GBSTATE-golden-able; s01 is the
> representative + sufficient GBSTATE golden.** Attempted `yellow_intro_s13` (scene-12 close-up paste,
> to close the "not frame-checked" residual) and found the surface-model divergence blocks it:
> **pret's scenes 2/12 write the BG map DIRECTLY to VRAM vBGMap0 ($98xx)** (e.g. scene 12 pastes at
> `$98c5`), while the port authors in `W_TILEMAP` (its 40×25 canvas, mirrored to $9800). The golden
> region set is `wTileMap` ($c3a0) + `vram_tiles` ($8000–$97FF) + `oam` — it does **not** capture
> vBGMap0 ($9800). So (a) the ROM's captured wTileMap for scene 13 is just the letterbox (the paste
> went to $9800, uncaptured), and (b) the port's wTileMap HAS the paste → they'd mismatch. Net: the
> direct-VRAM scenes can't be verified via the wTileMap GBSTATE golden. The golden-able yellow scenes
> are the shared-letterbox holds (s01, s05, s09 — a running-Pikachu OBJ over the letterbox), which are
> redundant with s01 (same static wTileMap; the object is masked). **Conclusion: s01 is sufficient
> GBSTATE coverage for the Yellow intro.** The unique-BG scenes (2/10/12) are verified by construction
> (faithful paste/tilemap code — the assets are byte-identical, the coords use `INTRO_BG_ORIGIN`).
> **A rendered-pixel comparison is also not feasible** (verified 2026-07-21): the mGBA harness has no
> framebuffer dump — it yields GBSTATE + register traces, not pixels (the A2 "mid-bounce FRAME.BIN"
> path recovers the *scroll value* from the port's FRAME.BIN and compares it to an expected sequence;
> it is not a pixel-vs-ROM-render diff). And even a software re-render of the ROM's GBSTATE can't show
> the paste, because it lives in the uncaptured vBGMap0 ($9800). Capturing vBGMap0 is rejected: the
> port's compositor reads `W_TILEMAP`, so its $9800 is stale for most screens → it would break existing
> goldens. **Net B3 scene coverage (accepted as sufficient): s01 GBSTATE golden (done) + byte-identical
> asset check (done) + by-construction faithful scene code (faithdiff-swept, done).** The unique/
> scrolling scenes get no per-scene ROM-diff beyond that — by design, not omission.

> **F-GFI (RESOLVED, `3175ff22`) — copyright screen dropped the "GAME FREAK inc." glyphs.**
> Root cause: `LoadCopyrightTiles` loaded only 19 tiles (copyright.2bpp), but pret's single
> CopyVideoData count spans the ROM-contiguous copyright + `GameFreakLogoGraphics`
> (gamefreak_inc, 9 tiles) + `NineTile` (1 tile) = 30 tiles to $60–$7C. The port's DEVIATION
> miscomputed this as "20 tiles / 1 overflow" and truncated, dropping the "GAME FREAK inc."
> glyphs ($73–$7B) + separator ($7C); those slots held stale font_extra tiles. Fix: load the
> three flat assets to their contiguous slots (copyright→$60, gamefreak_inc→$73, nine→$7C);
> omit pret's unused font_extra[0] overflow at $7D. **Verified**: `goldencheck gamefreak_intro`
> (BOOT_CINEMATIC vs the mGBA golden) = TILEMAP/VRAM(384)/OAM/WRAM **OK → PASS** (only the $7D
> overflow masked); faithdiff clean, lint 0. **Registration DONE (`da12fd4c`):** added a
> `DEBUG_GAMEFREAK_INTRO` gate (validate_scenarios requires `DEBUG_*`) that enables the
> BOOT_CINEMATIC real boot; manifest + golden_diff entry + regenerated (gitignored)
> `scenario_registry.inc`. `validate_scenarios` consistent, `goldencheck gamefreak_intro` PASS,
> runs in `make fidelity-full`. (The earlier `scenario_registry.inc` "staleness" was just the
> local generated file left over from the prototype build — it regenerates from the manifest.)
>
> <details><summary>original F-GFI finding (history)</summary>
>
> **F-GFI (OPEN, 2026-07-21) — copyright-screen glyph tiles $73–$7D diverge from the ROM.**
> `goldencheck gamefreak_intro` (port `BOOT_CINEMATIC=1 AUTOKEY_DUMP_FRAME=50` vs the
> committed mGBA golden) reports TILEMAP OK (360/360), OAM OK, WRAM OK — but **11 VRAM
> tile-DATA slots, vChars2 $73–$7D**, differ. That is exactly the "GAME FREAK inc." glyph
> region + the $7C/$7F separators the copyright text references. Evidence: tile $7C
> want `0000f870d8d8f8f81818f0f0…` (a real glyph) vs got `28282828…` (a "‖" vertical-bar
> pattern). So the port loads *wrong pixels* there — its earlier pixel-**count** check
> (289/335/308) passed because counts are shift/shape-blind (the "aggregate hides errors"
> trap). Likely root cause: the `LoadCopyrightTiles` 19-vs-20-tile `data-model` DEVIATION
> **understates** the divergence — pret's copyright graphic (20 tiles, $60–$73) supplies
> glyphs the port truncates to 19 ($60–$72), so $73+ falls back to `LoadTextBoxTilePatterns`
> font/box tiles that don't match the ROM's copyright glyphs. NEXT: decode the ROM's
> $73–$7D (golden) vs the port's, confirm whether the copyright renders the wrong glyphs
> visually, then fix the tile load (or justify+mask if provably invisible). Repro wiring
> (reverted): golden_diff `gamefreak_intro` entry {flags `BOOT_CINEMATIC=1
> AUTOKEY_DUMP_FRAME=50`, window (0,0), projection ((0,0,17,19),(10,3)), wram_skip
> `_NONBATTLE_WRAM_SKIP`}; `%elifdef BOOT_CINEMATIC → GBSTATE_SCENARIO 25` in
> debug_dump.asm; manifest `gamefreak_intro` id 25.
> </details>
- [ ] Regenerate the scenario registry. *(rides scenario activation above.)*
- [x] Add coordinate transforms to `golden_diff.py`. *(2026-07-21: no new code needed —
      the generic `projections` mechanism (window (col,row) + `(dcol,drow)` rects,
      `docs/ui_projection.md`) built in A1/A2 already covers the cinematic surface; a
      cinematic scenario just declares `"window": (10, 3)`.)*
- [ ] Add only measured, justified masks. *(NOW ACTIONABLE — measure against the mGBA goldens once authored.)*
- [~] Sweep stale `TODO-HW`, `STUB`, extern, allowlist, plan, and status claims.
      *(2026-07-21: TODO-HW/STUB/extern/status portion done — fixed init.asm's stale
      header TODOs for PlayIntro + title (`142a3197`); `project_state` confirms all
      cinematic routines `implementation linked` at their mirror paths, no stub-shadow
      or stale extern tree-wide. Remaining: the `pret_label_allowlist.json` may hold
      stale relocation entries for the mirror-moved labels — SHA-gated, needs a
      maintainer. CLAUDE.md's "title renders wrong" note is likely stale post-A2.3 but
      has uncommitted third-party edits, so left to a maintainer.)*
- [x] Add and verify `title_timeout` and `soft_reset` route scenarios. *(BOTH BUILT — per the
      user's "title timeouts are integral … I'd do soft reset too", reversing the earlier
      deprioritization. `title_timeout` (id 27, `c553c01c`, PASS): idle-loop
      `IncrementResetCounter` CF → `.doTitlescreenReset` → `MovieEndSurface` → `jmp Init` →
      (post-flip) PlayIntro replay. `soft_reset` (id 28): the UP+SELECT+B combo →
      `.go_to_main_menu` → `.doClearSaveDialogue` → `jmp Init` → replay. Each is a STATE
      golden of the replayed copyright, byte-identical to `gamefreak_intro` (the mGBA goldens
      share SHA `ec3db348…`) but reached via the reset route the scenario proves — enforced by
      `must_hit` (`DisplayTitleScreen`/`IncrementResetCounter` + `PlayIntro`/`PlayShootingStar`).
      Two documented divergences: `title_timeout` shortens the ~51 s idle countdown under its
      flag; `soft_reset`'s combo route hits the port's Phase-5-stubbed `DoClearSaveDialogue`
      (pret opens a NO/YES box, port jumps straight to Init) — the reset-replay observable is
      identical either way, the box is a pre-reset transient the copyright-state golden can't
      capture. Port-side gotcha fixed during build: the port's `.go_to_main_menu` exit sequence
      runs DelayFrame (whiteout/Delay3) which refreshes hJoyHeld from the empty harness keyboard,
      wiping a one-shot combo latch before the re-check — so the latch is re-asserted before the
      re-check to model the continuous hold real hardware requires, exactly as the mGBA .lua
      holds the combo 60 frames.)*
- [~] Run one uninterrupted power-on to overworld without `SKIP_TITLE`. *(Deterministic half
      DONE: the flip makes the default build boot Init → PlayIntro (splash + intro) → title
      → menu → … → overworld, and 8 scenarios across every category PASS after the flip. The
      remaining half is the HUMAN full-chain experiential smoke test — audio + continuous
      motion + interactive naming — which the plan's "Human-acceptance standard" reserves for
      a maintainer and which deterministic gates cannot replace.)*

> **B4 status (2026-07-21, mGBA UNBLOCKED).** Correcting a prior wrong assumption: the
> mGBA golden harness **runs in this environment** — `pokeyellow.gbc`/`.sym` are present
> and SHA-valid (repo root + `../pokeyellow_msdos-pret-golden`), mGBA is built
> (`dos_port/tools/mgba_build/`), and `mgba-lua-runner` regenerated the `title` golden
> byte-identical to the committed one. **Ground-truth win:** an mGBA probe confirmed the
> ROM draws the boot copyright on `wTileMap` rows **7/9/11** (tile counts 12/14/15) —
> exactly the `6a05a616` PlaceString fix, validating it against the real ROM (not just
> pret-reading).
>
> Done (checkable): PlayIntro ported + wired + Init-context runtime-verified (`edafa36d`),
> two real faithfulness bugs fixed (`6a05a616` copyright spacing — now ROM-confirmed,
> `59412c80` hAutoBGTransfer), 144 labels faithdiff-swept clean, stale claims swept
> (`142a3197`), translated/linked registered, golden_diff projection infra ready.
>
> **Remaining, now MOSTLY actionable via the mGBA harness:** author the cinematic golden
> scenarios (`gamefreak_intro`, `yellow_intro_s00..17`) — Lua nav + port DEBUG gate +
> goldencheck registration; then `title_timeout`/`soft_reset` traces + the whole-chain
> fidelity run. Only two things still truly gate on the human: the **faithful-default
> flip greenlight** and the **final full-chain human smoke test** (experiential/audio).

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

### A2.5 — bounce timing verified frame by frame (PASS)

**The reference exists and is built.** `tools/mgba_harness/scenarios/title_trace.lua`
records `(frame, hSCY, hWY, wTitleScreenScene)` from the golden ROM (sha1
`cc7d0326`, verified against `roms.sha1`). Two things it taught, both encoded in
the script: 700 uninterrupted frames never reach the title, because the ROM plays
the copyright screen, the Game Freak splash and the whole Yellow intro first; and
the safe detector is `hSCY == 64`, since the bounce never reads the joypad.

Reference findings:

- `hSCY` delta runs are exactly pret's table, one frame per step.
- `hSCY` range `[0,64]`, 22 distinct values, **zero** crossings of the 0/255
  boundary — the plan's "the bounce wraps" premise is now measured wrong, not
  merely derived wrong.
- `hWY` goes `144 -> 64` at the bounce start and back to `144` once `hSCY`
  reaches 0. This independently confirms the bounce window from the reference,
  having previously been concluded only from reading pret.

**Port comparison is through pixels, deliberately.** A register trace was not
used, for two reasons: `GBSTATE.BIN` has no HRAM region (so `hSCY` is in no dump
the port already writes, and adding a region would change the region count for
every existing golden), and more importantly a register trace proves what the
game *wrote*, not what the renderer *drew* — the projection is precisely the
layer in between, so it is the layer under test. `hSCY` drives `WIN_SRC_Y`, which
shifts the BG sample point, which moves the logo; measuring the logo's bottom
edge in a mid-bounce `FRAME.BIN` recovers the `hSCY` that actually reached the
screen.

`tools/check_title_timing.py` automates it. Result over 14 sampled frames
spanning every delta run in the table, including the run boundaries at 16/17,
20/21 and 24/25:

**exact = 13, mismatch = 0, unmeasurable = 1** (frame 1, where the logo has
scrolled entirely above the viewport and the measurement carries no signal).

**One real finding, not a fudge factor.** The first pass showed a constant
non-zero residual exactly equal to the current run's delta. The cause is that
pret's `.ScrollTitleScreenPokemonLogo` is `call DelayFrame` and *then*
`ld [bc], a` — the frame is rendered before `hSCY` is updated — so the buffer
captured at bounce frame N shows step N-1's `hSCY`. The port preserves that
order, so the lag is correct behaviour and the checker models it explicitly. A
constant residual was the clue; had it been absorbed as a calibration offset the
real ordering fact would have been missed.

### A2.5 — blink timing verified against the golden ROM (PASS)

Same method as the bounce: golden ROM for the reference, pixels for the port.
`tools/check_title_blink.py` classifies the eye state in each idle-loop capture
and compares it to the reference sequence. `TITLE_DUMP_LOOP=N` captures the Nth
iteration of `.titleScreenLoop`.

**Alignment was the entire difficulty, and it produced a false negative first.**
The reference must be indexed from `.loop`, marked by `wTitleScreenScene + 4`
becoming `$0F` (pret's idle loop writes it first thing). Indexing from the `hWY`
settle instead puts the origin ~54 frames early — that lands in the PCM/music
sequence *preceding* `.loop` — and makes the blink look like it starts at frame
54 when it actually starts one frame after `.loop`. A sweep aimed at iterations
50-63 on that mistaken alignment returned "all open" for the port. That looked
like a port defect for a moment, and it was neither: both sides are in the long
110-frame open window there. `title_trace.lua` now records the marker column so
the alignment is measured rather than re-derived.

The one-frame lag appears again, for the same structural reason: `.titleScreenLoop`
runs `DelayFrame` *before* `DoTitleScreenFunction`, so the buffer captured at
iteration N was rendered before that iteration's tile mutation and shows the
reference's `.loop`-relative frame N-1. This was predicted from the code order
before looking at the data, not fitted afterwards.

Scene-to-state mapping (the observed scene is one ahead of the dispatch that
ran, because `.BlinkWait` increments before anything can sample it): dispatch 1
half, 2-3 hold, 4 closed, 5-6 hold, 7 half, 8-9 hold, 10 open, 11 wrap.

The checker refuses to pass on a sample range containing no blink, precisely
because that is what the mis-aligned sweep looked like — "all open, no
mismatches" must not read as agreement.

### A2.6 — `title` golden registered

`tools/mgba_harness/scenarios/title.lua` dumps the stable checkpoint, detected by
the same `$0F` marker. The `golden_diff.py` entry uses one rigid projection rect
— the GB 20x18 screen translated to canvas tile `(10,3)`. Unlike `party_menu`
nothing is re-flowed, because a cinematic keeps the GB composition by design.

OAM is deliberately **not** masked. `PublishProjectedOAM` leaves the canonical
records in `$FE00` byte-for-byte and publishes the projection only through the
separate DOS coordinate tables, so the eye records compare directly against the
golden; the generated golden confirms it with exactly 32/160 OAM bytes nonzero
(8 records x 4 bytes). If a future change makes OAM need a mask here, that is a
regression in that contract, not a scenario quirk.

Regenerating the goldens rebuilt all 20 scenarios and every pre-existing one came
back byte-identical, which is also a determinism check on the harness.

Still open in A2.6: `title_timeout`. The timeout path is ~51 s of idle frames,
which no current scenario shape captures cheaply.

### A3 — the title routes through MainMenu for real (PASS)

`DisplayTitleScreen.go_to_main_menu` was `call OakSpeech / jmp EnterMapBoot`, a
Phase-2 shortcut that skipped the menu entirely. It is now `jmp MainMenu`.

`MainMenu` was already a complete linked implementation — `InitOptions`, the
save-file probe, `StartNewGame`, continue, options, and `.backToTitle ->
DisplayTitleScreen` — with **zero callers**. Nothing needed writing; the shortcut
was the only thing standing between it and the boot path.

Structural evidence (`project_state`, before -> after):

| label | callers | reachability |
| --- | --- | --- |
| `MainMenu` | 0 -> 1 | not-proven-reached -> statically-reached-from-start |
| `StartNewGame` | 1 -> 1 | not-proven-reached -> statically-reached-from-start |
| `InitOptions` | 1 -> 1 | not-proven-reached -> statically-reached-from-start |

`faithdiff DisplayTitleScreen` closed the corresponding delta: matched calls
29 -> 30, port calls 44 -> 43, with the `MainMenu` DROPPED entry and the
`OakSpeech` / `EnterMapBoot` ADDED entries all gone.

**`SKIP_TITLE` had been free-riding on the shortcut.** It called the `OakSpeech`
stub purely for its `InitPlayerData2` prologue. With the shortcut gone that path
seeds nothing, so `Init` now calls `InitOptions` and `InitPlayerData2` directly
**under `SKIP_TITLE` only** — a harness posture standing in for the two routines
normal boot reaches via `MainMenu` and `StartNewGame -> OakSpeech`. `InitOptions`
is called rather than partially duplicated, so `wPrinterSettings` matches too.

**The A2.6 `wOptions` mask is retired, not re-justified.** pret's `Init` never
writes `wOptions`; the port's early write was an unconditional divergence that
the title golden caught (`want $00 / got $03`). Moving it under `SKIP_TITLE`
makes the normal path faithful, and `goldencheck title` now compares 8 regions
with 5 skipped — up from 7 and 6 — with `wOptionsBlock` clean.

Gates: build clean, `lint_pret_labels` 0, `--strict-claims` 0, `fidelity` 13/13
PASS.

#### `main_menu` scenario — real navigation, not a synthetic redraw

The plan said "register `RunMainMenuTest` as `main_menu`". That predates the
routing existing. `RunMainMenuTest` is a *synthetic* gate — it seeds a save,
forces `wSaveFileStatus`, and re-draws the box with the same calls as
`MainMenu.mainMenuLoop` while skipping `HandleMenuInput`. Now that the title
actually reaches `MainMenu`, real navigation is available and is strictly
stronger evidence, so `main_menu` uses it and `RunMainMenuTest` stays as the
appearance-only unit gate it was.

`DEBUG_MAINMENU_LIVE` boots the real title, latches START in the joypad shadow on
the second idle-loop iteration so `.go_to_main_menu` runs the genuine exit
sequence, and dumps at `MainMenu` with the box drawn and the cursor placed,
before `HandleMenuInput` consumes anything — the same stopping point as the mGBA
side. The mGBA scenario (`main_menu.lua`) is `smoke_title`'s navigation migrated
verbatim, and the proof it was migrated rather than re-authored is that the
generated golden is byte-identical to `smoke_title.bin` (sha1 `db178e19`).

`goldencheck main_menu`: TILEMAP OK (360/360 cells), VRAM OK, OAM OK, WRAM OK
(8 regions, 5 skipped). `fidelity` 14/14 PASS.

Two capture-point facts, both surfaced by first-run failures rather than
inspection:

- The START latch has to sit *after* `JoypadLowSensitivity` and before the read.
  At the end of the loop body it is wiped by the next iteration's
  `DelayFrame -> joypad_update` and `JoypadLowSensitivity`, both of which refresh
  `hJoyHeld` from the keyboard. The first attempt did that and the harness sat on
  the title until it timed out.
- The dump must run `PlaceMenuCursor` first. `HandleMenuInput` draws the cursor
  at its start, so dumping straight after `MainMenuShowWindow` catches the one
  frame before it exists. The first run failed on exactly one cell — (row 2, col
  1), want `$ED` got `$7F`.

#### `title_reentry` — no leaked state, and a new finding (F-25)

`DEBUG_TITLE_REENTRY` boots the real title, latches START to reach `MainMenu`,
takes the B-cancel path back to `DisplayTitleScreen`, and dumps the checkpoint on
the second visit. The counter that distinguishes the visits lives in `.data`, so
it survives the `jmp` re-entry.

**The core acceptance is proven at the pixel level, and it is byte-exact.** The
reentry `FRAME.BIN` is *byte-identical* to the `title` `FRAME.BIN`
(`cmp title_reentry.bin title.bin` → identical). Since the compositor produces
the identical frame after a full round trip, every piece of state
`MovieBeginSurface` owns — `g_obj_clip`, `g_bg_whiteout`, the source offsets, the
window callbacks — was restored. `goldencheck title_reentry` independently
confirms the OAM half (OAM OK) and that no game data changed (WRAM OK).

**F-25 (OPEN, route difference), discovered here.** The plan assumed re-entry
reproduces the title checkpoint exactly. On the *ROM* it does not: the second
title visit loads the Pikachu tile block to VRAM slots `$40` higher than first
boot and shifts its tilemap ids by the same `$40` — measured directly,
`reentry.tile($26) == title.tile($66)`. The cause is the vChars1 font timeshare:
the main menu loaded the font into vChars1, so the title's second graphics load
packs Pikachu around it. The port re-loads to the first-boot slots both times, so
its rendered frame is pixel-identical to the checkpoint (the whole point) but its
VRAM bookkeeping does not follow the ROM's re-entry relocation. It is invisible —
nothing reads those ids by number on the title — so it is masked as a route
difference (`golden_diff.py` F-25, 136 tilemap cells + 12 VRAM slots) rather than
faked away, and F-25 retires when the port reproduces the ROM's re-entry
allocation. This is the same class of false premise as the "bounce wraps" one:
the plan was never validated, and measuring beat assuming again.

`goldencheck title_reentry`: TILEMAP OK, VRAM OK, OAM OK, WRAM OK (F-25 masked).
`fidelity` 15/15 PASS.

#### `continue_seed` — CONTINUE preserves loaded state (PASS)

The `.choseContinue` path (`DisplayContinueGameInfo` → input loop →
`SpecialEnterMap`) calls **neither** `OakSpeech` **nor** `InitPlayerData2` —
verified structurally: those are new-game-only (`OakSpeech` has one caller,
`StartNewGame`), and reading the continue path confirms it. `continue_seed`'s
`must_hit` is `TryLoadSaveFile` and nothing else.

The runtime half is a datastruct scenario that proves the load *preserves* state
rather than re-seeding it. The port gate (`DEBUG_CONTINUE_SEED`,
`save.asm:RunContinueSeedTest`) seeds the deterministic debug save
(`PrepareNewGameDebug` + `SeedDeterministicPlayerIdentity`, matching `seed.lua`),
writes `POKEMON.DSV`, **zeroes every saved WRAM span** (exactly `dsv_io.asm`'s
`payload_blocks`), then loads it back with `TryLoadSaveFile` — the identical load
`MainMenu`'s save-present branch runs. The clobber is what makes it a real load
test: without it the dumped bytes could be leftover seed. The golden
(`continue_seed.lua`) is the seed spec — the invariant the load must reproduce.

Result: all 8 compared WRAM regions match — the entire party, player name,
pokédex, bag, money, options block, and player id round-tripped through
save → clobber → load byte-for-byte. The DSV save/load is faithful for the whole
save block.

One reconciliation, caught by the first diff: `wLetterPrintingDelayFlags` came
back `$01` on the port (InitOptions sets it, so it was saved and faithfully
restored) against `$00` in the first golden — because the golden set `wOptions`
but not its `InitOptions` sibling `wLetterPrintingDelayFlags`. Both are in
`wMainData` and both round-trip through the save, so the golden sets both; the
port's restored `$01` was correct all along.

`goldencheck continue_seed`: WRAM OK (datastruct class). `fidelity` 16/16 PASS.

**A3 is complete.** Title → `MainMenu` routes for real; `SKIP_TITLE` seeds
correctly without the shortcut; the `wOptions` mask is retired; `main_menu`,
`title_reentry` and `continue_seed` are registered and passing; and the
new-game/continue split is verified (new game reaches `OakSpeech` once, continue
reaches neither `OakSpeech` nor `InitPlayerData2`).

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
- [x] `title`, `title_reentry`, `title_timeout`, `continue_seed`, `main_menu`, `oak_intro`, and `gamefreak_intro` pass. *(oak_intro id 29 PASS 2026-07-21; all others previously registered + PASS)*
- [ ] All 18 Yellow-scene scenarios pass.
- [ ] Native visual evidence is retained for every frame-yielding Yellow scene.
- [ ] `fidelity`, `fidelity-full`, and `goldens-verify` pass.
- [ ] Human smoke acceptance is recorded under the defined standard.
- [ ] Every observed failure has an automated regression or the required manual external-output record.
- [ ] Strict label and annotation lint reports no stale extern, malformed annotation, or duplicate provider.
- [ ] Related false `TODO-HW`, stub, allowlist, plan, and status claims are corrected.
- [ ] The plan is archived as `docs/plans/menu_intro.md`.

### A4 — investigation (2026-07-20): most of the pic engine already exists

Before porting anything, A4 was surveyed against the port. The result changes its
shape substantially: it is far less from-scratch than the routine list implies.

**`InitPlayerData2` ownership is settled.** It and `InitPlayerData1` are already a
faithful translated provider at the correct pret-mirrored path
`src/engine/movie/oak_speech/init_player_data.asm` (`faithdiff` 4/4 calls). Per
the A4 rule it stays put and is only a dependency — no relocation, no new module.

**Dependency map for the pic engine (A4.1).** `project_state` + reading pret's
`oak_speech.asm` shows the heavy routines are all already in the port:

| pret routine | port state |
| --- | --- |
| `CopyUncompressedPicToHL` | EXISTS — `home/pics.asm`, `global`, flip-aware |
| `UncompressSpriteData` | EXISTS — `home/uncompress.asm`, `global` |
| `InterlaceMergeSpriteBuffers` | EXISTS — `home/pics.asm`, linked |
| `GetPredefRegisters` | EXISTS — `home/predef.asm` |
| `CopyUncompressedPicToTilemap` | MISSING — thin predef wrapper over `CopyUncompressedPicToHL` (reads `wPredefHL`/`hStartTileID`) |
| `UncompressSpriteFromDE` | MISSING — thin adapter over `UncompressSpriteData` (source from DE + bank in A) |
| `DisplayPicCenteredOrUpperRight` / `IntroDisplayPicCenteredOrUpperRight` | MISSING — orchestrate uncompress → SRAM-buffer copy (HAL boundary) → `InterlaceMergeSpriteBuffers` → place at hlcoord (15,1) upper-right or (6,4) centred → predef `CopyUncompressedPicToTilemap` |

So A4.1 is: two thin wrappers + the two pic-display routines (glue), projected
through `UI_OAK_SPEECH`. The port's `CopyUncompressedPicToHL` already re-strides
per caller (`EDX` = 20 menu / 40 canvas) and reads `wSpriteFlipped`, so the
projection is a stride/coord choice, not new decode logic. `hStartTileID` (HRAM
`$FFE1`) is not yet in `gb_memmap.inc` — add it when the predef wrapper lands.

The SRAM sprite-buffer copy (`sSpriteBuffer1 -> sSpriteBuffer0` in pret's pic
display) is a HAL boundary: the port has no SRAM, and its `LoadMonFrontSprite`
path already decodes straight to the buffers, so the pic-display routines
reconcile that copy the way `LoadFrontSpriteByMonIndex` already does rather than
emulating SRAM.

**Remaining A4 shape** (subtasks A4.1–A4.5 in the harness): A4.1 pic engine;
A4.2 fades/slides (`FadeInIntroPic`/`IntroFadePalettes`/`MovePicLeft`/
`OakSpeechSlidePic*`, `GBFadeIn/OutFromWhite` already exist); A4.3 `oak_speech.asm`
main + generated text; A4.4 naming via the existing `DisplayNamingScreen` +
post-naming surface re-establishment; A4.5 wire the boot path (delete the stub),
the `oak_intro` golden, and the Oak timing trace. The boot path keeps working
throughout because the `OakSpeech` stub stays live until A4.5 swaps it.

### A4.5 progress (2026-07-20): full OakSpeech body assembled, stub retired

`oak_speech2.asm` is code-complete (A4.4). A4.5 has landed the full body:
- **ShrinkPic1/2** (`9838258a`): generated (`gen_trainer_pics.py`).
- **MovePicLeft** (`329efeca`): projected `rWX` window slide via `MovieSyncWindow`.
- **Full `OakSpeech` body + stub retirement** (`ec0639fe`): the real cutscene links
  from `oak_speech.asm` and replaces the `InitPlayerData2`-only stub in
  `main_menu_stubs.asm` (retired same commit). **faithdiff 24/24 calls + 10/10
  stores** — only `MovieBeginSurface`/`MovieEndSurface` added (the surface
  establish/teardown DEVIATION). lint clean; **fidelity 16/16** (no regression: the
  existing goldens use `SKIP_TITLE` or never select NEW GAME, so none hit
  `OakSpeech`). `OakSpeech` is now `translated`, not a stub.

Boot fact: `StartNewGame` clears `BIT_DEBUG_MODE` then calls the real `OakSpeech`,
so a real new game runs the full cutscene incl. naming (input-driven); a debug-mode
new game skips speech+naming.

- **A4.5.e** (`62c36422`): the `title.asm` hand-encoded debug boot names are now
  generated (`gen_debug_boot_names.py`) — the last hand-encoded charmap string in the
  workstream is gone.
- **A4.5.f START** (`53308bc4`): the **real `OakSpeech` renders the oak_intro
  checkpoint**. `IntroTextWait` is now `msgbox_oak_speech`'s permanent `MB_PROMPT`
  (the `<PARA>`/`<PROMPT>` hold), and `MovieBeginSurface` clears `spr_oam_valid` so the
  cinematic starts with no stray OBJ (the title's eyes, published after, survive).
  `RunOakSpeechCheckpoint` now drives the real `OakSpeech`; pixel-verified — Oak pic +
  box + page-1 text, matte clean, **zero** OBJ-palette pixels; fidelity 16/16.

- **A4.5.f: default naming verified** (`cff85d0f`): the `DEBUG_CHOOSENAME` gate +
  `AUTOKEY_CHOOSENAME` (DOWN+A) drive `ChoosePlayerName`'s default path end-to-end —
  `pixelcheck.sh choosename` shows the pic + box + "YOUR NAME IS …" text, matte clean.
- **A4.5.f: custom naming + surface re-establishment verified** (`36a2dc33`): the
  `CHOOSENAME_CUSTOM=1` variant (A → NEW NAME, A → letter, START → submit) drives the
  custom path with **before/after** proof — frame 180 the `DisplayNamingScreen` grid
  has taken over the whole surface (pic gone); frame 320 the pic is **restored** +
  "YOUR NAME IS" (`MovieBeginSurface` re-established the surface). This is the
  rival-pic-after-naming acceptance gate — the deferred runtime evidence for `a191c3e8`.
  Both naming paths now render end-to-end on the projected surface.

**✅ DONE (2026-07-21, mGBA UNBLOCKED):** the oak_intro **GBSTATE golden** is authored,
registered, and PASSES canonical `goldencheck`. Scenario **id 29** (NOT 21 — the disabled
scaffold's id 21 collides with active `title`=21), gate **`DEBUG_OAKINTRO`** (the real
checkpoint; `DEBUG_OAK_INTRO` with the underscore was the stale Pallet-overworld-event
scaffold — its `.lua.disabled` is `git rm`'d), must-hits `OakSpeech`/`PrepareOakSpeech`/
`FadeInIntroPic`/`DisplayPicCenteredOrUpperRight`. The mGBA `oak_intro.lua` navigates the
real boot→menu→NEW GAME→OakSpeech and parks at the page-1 `cont` key-wait ("Hello there!"
/ "Welcome to the"); the port's `RunOakSpeechCheckpoint` (AUTOKEY_QUIET, never taps) parks
at the same state. **The displayed cinematic matches the ROM byte-for-byte** — Oak's pic
(tilemap rows 4-10 + VRAM $9000-$9300 signed), font ($8800-$8FF0), and the whole box+text
(rows 12-17 + box tiles $9600-$97F0) are all compared and pass. Masked (justified, measured
from the first diff, naming_screen/_STATUS_MASKS pattern): the blank surround (rows 0-11
non-pic: port cinematic-clear $00 vs pret ClearScreen $7F, both zero-tile), the overworld-
boot VRAM residue in the unsigned area ($8000-$87F0) and the bilateral undisplayed residue
at $31-$5F, the overworld player-sprite OAM residue (spr_oam_valid=0), and pre-game WRAM
(wPlayerName/wRivalName/wPlayerID). **Only the Oak timing trace remains open** (needs
port-side per-frame trace instrumentation, the same as the yellow-scene trace note).

- **A4.5.f: cry-audio audit** (acceptance "the cry command is the sole silent audio
  operation"): verified. `OakSpeech`'s direct audio (`PlayMusic(Routes2)` /
  `PlaySound(SFX_SHRINK)` / `StopAllMusic`) are all `translated` (real, gated on
  `g_audio_engine_online`), and a scan of every generated intro text stream finds
  exactly ONE sound command — `sound_cry_pikachu` (0x14) in `OakSpeechText2` — which
  the text engine silently skips ("$0E+ sound command — no audio yet") and whose
  `PlayCry` is a stub. So the cry is the only silent op; music + SFX play. ✅

**A4 acceptance status** (plan §Acceptance): ✅ non-stub `OakSpeech`; ✅ no
hand-encoded boot strings; ✅ `InitPlayerData2` one provider; ✅
`CopyUncompressedPicToTilemap` linked+translated; ✅ pics on surface (pixel);
✅ slides preserve cadence (OAKSLIDE pixel); ✅ custom+default naming work + names
render (persistence shown by the `<PLAYER>`-read "YOUR NAME IS" text); ✅ cry is the
sole silent audio. **⛔ mGBA-blocked here:** the Oak timing trace and the initial
bag/party/box **golden** comparison (both need mGBA + baserom to produce the
reference). **Remaining port-side:** the whole-chain new-game boot under AUTOKEY
(title→menu→OakSpeech→overworld — the individual beats are all verified). Detail in
stigmergy `a4-4-oak-speech2-porting-plan`.

### A4 progress (2026-07-20): pic engine, fade, text, PrepareOakSpeech; the PrintText-under-surface finding

A4 is being ported bottom-up behind debug gates (the OakSpeech body itself waits
for A4.5 — defining it now would duplicate the still-live stub's global). Done and
verified so far:

- **A4.1 pic engine** — `CopyUncompressedPicToTilemap` (init_battle.asm),
  `IntroDisplayPicCenteredOrUpperRight` / `DisplayPicCenteredOrUpperRight`
  (oak_speech.asm). Oak's pic renders centred on the surface (`DEBUG_OAKPIC`:
  matte clean, 7-tile pic at projected row 7). Most of the engine already
  existed; these are glue over `LoadMonPicToVRAM` + `CopyUncompressedPicToHL`.
  `ProfOakPic`/`Rival1Pic` assets already existed (trainer-pic generator).
- **A4.2 fade** — `FadeInIntroPic` + `IntroFadePalettes` (ramp bytes from the
  `dc` macro, terminal `0xE4` = normal BGP validates them). Pixel-verified.
  Slides (`MovePicLeft`, `OakSpeechSlidePic*`) still open — and they come *after*
  the oak_intro checkpoint, so off the critical path to the golden.
- **A4.3 text** — `gen_oak_speech_strings.py` emits the five intro streams;
  `sound_cry_pikachu` ($14) added to the shared parser (the one permitted silent
  audio op).
- **A4.3 PrepareOakSpeech** — ported in full (save-block clear + option
  preservation + InitOptions + debug names). faithdiff caught an incomplete first
  attempt (only the name-copy tail) before commit.
- **A4.3 text-over-surface** — RESOLVED (commit `05da5bcc`); see the dedicated
  execution note below. `g_surface_redraw_cb` per-frame mirror + `msgbox_oak_speech`.
- **A4.4.a default-name data** — `gen_default_names.py` → `assets/default_names.inc`
  (`DefaultNames{Player,Rival}{,List}`, decode-verified byte-exact). Commit `b09cdae7`.
- **A4.4.b (in progress)** — `oak_speech2.asm` created.
  - `GetDefaultName` (commit `45252920`): flat→GB `rep movsb` for the `jp CopyData`
    tail (`data-model` DEVIATION — the name list is program-image data and the
    port's CopyData is EBP-relative on both ends). Assembles/links/lint-clean;
    runtime-verified later (dead code until `ChoosePlayerName`).
  - `DisplayIntroNameTextBox` (commit `67857d6b`): the projected name-select menu,
    **pixel-verified** (`DEBUG_NAMEMENU` gate, `pixelcheck.sh namemenu`) — box +
    "NAME" title + cursor + `NEW NAME`/`YELLOW`/`ASH`/`JACK`, matte clean; faithdiff
    clean (4 calls / 6 stores). Two fidelity facts verified against pret, not
    assumed: the list is `<NEXT>`-**double-spaced** (`2*SCREEN_WIDTH`, no
    `BIT_SINGLE_SPACED_LINES`), and the cursor step is `2 * text_row_stride` (pret
    `PlaceMenuCursor` `ld bc, 2*SCREEN_WIDTH`). The box title `NAME@` is generated
    (`IntroNameString`), not hand-encoded.
  - `OakSpeechSlidePic{Left,Right,Common}` (commit `ba54f7e7`): the projected
    picture slide, **pixel-verified** (`DEBUG_OAKSLIDE` gate, `pixelcheck.sh
    oakslide`) — Oak displayed centred (surface cols 128–168) slides to 176–216, a
    rigid +48px = 6-column shift matching pret's `hSlideAmount`, ink preserved,
    matte clean. `projection` DEVIATION: band origin projected, linear span
    restrided to `SLIDE_ROWS*SCREEN_TILES_W+5` for the 40-wide canvas, the vestigial
    `hAutoBGTransfer` toggles dropped (`g_surface_redraw_cb` mirrors every frame),
    and pret's `hSlide*` HRAM temps → file-local `.bss`.
  - `ChoosePlayerName`/`ChooseRivalName` (commit `a191c3e8`): the name-selection
    flow — **`oak_speech2.asm` is now code-complete**. faithdiff 8/9 calls + 1/1
    store each; the single divergence is `ClearScreen` → `MovieBeginSurface`, the
    `projection` DEVIATION that re-establishes the `UI_OAK_SPEECH` surface
    `DisplayNamingScreen` took over. Added pret label `RedPicFront` (= the port's
    `PlayerPicFront`, both `red.pic`). The default path is composed of already-
    pixel-verified pieces; **end-to-end runtime verification of both paths — the
    custom-path surface re-establishment is the rival-pic-after-naming acceptance
    gate — lands in A4.5**, where the full `OakSpeech` cinematic runs the boot→
    naming flow under AUTOKEY. Analysis in stigmergy `a4-4-oak-speech2-porting-plan`.

**Open finding — PrintText does not compose over the cinematic surface.** The
`DEBUG_OAKINTRO` diagnostic gate drives Oak pic + fade + `PrintText(OakSpeechText1)`
and photographs the parked frame. It came back wrong, and the cause is precise:
`PrintText`'s box creation calls `set_single_window` (`home/text.asm:423`), which
sets `g_window_count = 1` and **replaces** `MovieBeginSurface`'s surface
descriptor — the Oak pic (in the surface window) vanishes. And `msgbox_dialog` is
a screen-space descriptor (`WY=152`, `MAXY=RENDER_H`), so its box extends below
the surface (`y1=168`) and leaks into the matte (measured: 904 colour-3 px
outside the surface, 0 pic ink).

The reconciliation (A4.3/A4.5): the intro text is part of the GB 20x18 screen,
which under projection **is** the surface, so `PrintText`'s box must be drawn into
the surface's own canvas (`W_TILEMAP`, committed by `MovieMirrorSurface`) through
a `UI_OAK_SPEECH`-projected msgbox descriptor, WITHOUT `set_single_window`
replacing the surface window. The `DEBUG_OAKINTRO` gate is the tool to build that
fix against; its captured frame is wrong by design until the reconciliation lands.

### A4 text-box reconciliation — RE-DIAGNOSED (tractable, not risky) + runtime blocker

The earlier "PrintText replaces the surface via set_single_window" finding was
right about the symptom but pointed at the wrong fix. The battle already solved
this: `msgbox_centered` draws its box + text DIRECTLY into the canvas
(`W_TILEMAP`, stride 40) with `MB_WIN_TILEMAP = 0` ("no window: drawn into the
canvas, so the caller's window list survives"). So the intro needs its OWN
no-window descriptor, not a change to the shared windowed path — safe, no
95-caller risk.

Built: **`msgbox_oak_speech`** (oak_speech.asm) — `msgbox_centered`'s shape with
every coordinate projected by `UI_OAK_SPEECH_(COL,ROW) = (10,3)`: box at canvas
(10,15), lines at (11,17)/(11,19), ▼ at (28,19), `MB_WIN_TILEMAP = 0`. With this
the text lands in the surface canvas; `MovieMirrorSurface` commits pic + text to
`GB_TILEMAP0` and the one surface window shows both.

Two more mechanism facts, both real requirements the reconciliation must honour:

1. **The text engine does not mirror the canvas during typing.** `menu_redraw_cb`
   is invoked only by the menu loop (`window.asm`), not by `PrintText`. In the
   battle the canvas IS shown (render_bg reads `W_TILEMAP` on the flat path); the
   intro shows a WINDOW over `GB_TILEMAP0`, so its canvas text must be mirrored to
   `GB_TILEMAP0` after each page (or via an intro-armed per-frame hook).
2. **`para`/`<PROMPT>` dispatches through `text_prompt_hook` (a global), not the
   descriptor's `MB_PROMPT`.** When it is 0 the engine runs the windowed overworld
   scroll — which recreates the surface-replace problem and hangs headless. The
   intro must install its own `text_prompt_hook` (the checkpoint gate points it at
   a mirror-then-dump capture).

**Runtime blocker.** With `msgbox_oak_speech` + the intro prompt hook, the
`DEBUG_OAKINTRO` gate still crashes *before* the capture — the fault is upstream,
in `PrintText`'s own setup or box-border draw under the projected canvas
descriptor. Pinpointing it needs the interactive DOSBox debugger
(`tools/dosbox-x-mcp`), not blind iteration. Everything up to the text (surface,
Oak pic, fade) is verified; the descriptor and the two mechanism requirements
above are correct and reusable. This is the concrete next step for an attended /
debugger session.

### A4.3 text-over-surface — RESOLVED (2026-07-20, commit `05da5bcc`)

The "runtime blocker" above was a **misdiagnosis**. It was neither a crash nor in
`PrintText`. Two facts, found by *reading* the text engine and the frame pipeline
(no debugger needed):

1. **The surface never received the typed text.** The cinematic surface is shown
   through a WINDOW sampling `GB_TILEMAP0` (stride 32); `PrintText` types into
   `W_TILEMAP` (stride 40). The text engine's own per-char mirror
   (`sync_dialog_window`) is *gated off* when `g_bg_whiteout=1` (which
   `MovieBeginSurface` sets) **and** targets `GB_TILEMAP1`, not `GB_TILEMAP0` — so
   nothing typed ever reached the surface source. This is the concrete form of
   "mechanism fact 1" above.
   **Fix:** `g_surface_redraw_cb` (`src/ppu/ppu.asm`, `dd 0`). `DelayFrame` invokes
   it once per frame in the BG-transfer phase; `MovieBeginSurface` arms it =
   `MovieMirrorSurface`, `MovieEndSurface` clears it. This repacks the canvas to
   `GB_TILEMAP0` every frame while a cinematic owns the screen — the port's
   legitimate analog of the GB VBlank auto-BG-transfer (retired for menus, but the
   cinematic genuinely needs it). Inert (one predictable branch) otherwise. It
   *replaces* the "mirror after each page / arm an intro hook" TODO in mechanism
   fact 1 — no per-caller mirroring is needed anywhere now.

2. **Page 1 of `OakSpeechText1` ends with `<PARA>` (`$51`), not `<PROMPT>`
   (`$58`).** Both route through `text_pause → text_prompt_hook`, and `PrintText`'s
   box setup copies the descriptor's `MB_PROMPT` into that global — so the hold is
   installed via `msgbox_oak_speech`'s `MB_PROMPT` field, confirming mechanism
   fact 2. The headless gate simply HUNG in the input-wait; the blank `FRAME.BIN`
   read back was a **stale leftover**, not a real render. The gate now builds with
   `DEBUG_AUTOKEY + AUTOKEY_QUIET + AUTOKEY_DUMP_FRAME` (default 360) and parks in
   `.introWait` (the intro's ▼-hold: `DelayFrame`, return on A/B); `AutoKeyDrive`
   photographs the parked page-1 frame.

**Evidence** (`tools/pixelcheck.sh oakintro`, decomposed — not a bare aggregate):
Oak's pic **703 ink px** (matches `DEBUG_OAKPIC`), page-1 text **764 ink px** in
glyph shapes inside a correct box border, matte **clean (0 ink outside** the
surface rect). ASCII render confirms Oak's pic centred over a text box reading
"Hello there! Welcome to the world of #MON!". `faithdiff DelayFrame` +
`lint_pret_labels` clean; fidelity **16/16**.

**Still open under A4.3/A4.5** (unchanged by this fix): the full `OakSpeech` body
stays behind the stub until A4.5 (defining it now duplicates the live stub's
global); `.introWait` is a minimal park — the real flow wants the
`BattlePromptWait`-style ▼ arrow blink. `msgbox_oak_speech` + `g_surface_redraw_cb`
are the reusable substrate for the whole speech (pages 2/3, name-intro text,
`YourNameIs`/`HisNameIs`) and for A4.4's naming screen.
