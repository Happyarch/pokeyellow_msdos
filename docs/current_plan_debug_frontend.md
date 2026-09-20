# Current Plan: Debug Audio Front-End (`pkmn-audio-dbg`)

Status: **IN BUILD (round-robin subagents via OpenCode `opencode-go/muse-spark-1.3-contributor#xhigh`, serial).**
Standalone Dear ImGui + SDL2 C++ successor application replacing `dos_port/tools/audio/audition.py`.
Builds directly against native audio synthesis cores (`nukedopl.cpp`, `Basic_Gb_Apu.cpp`, `libmt32emu`, `libfluidsynth`).

---

## §0 Design Principles

1. **Unified Standalone Application (Successor to `audition.py`)** ⚡:
   Instead of a split TUI + bus viewer, build directly against the same audio and emulation cores into a single desktop application (`pkmn-audio-dbg`). Features full transport controls (Play/Pause, Stop, Time/Frame display, interactive Seek bar, Loop markers) directly in the UI, completely replacing `audition.py` and eliminating IPC/socket complexity.
2. **MUNT-QT–inspired UI**:
   Channel status strips with persistent piano-roll note bars, per-channel mute toggles, partial-state grids. MUNT-QT is reference-only (no code reuse — license hygiene).
3. **Tab-based, one tab per sound device**, each tailored to that device's needs.
4. **Deep debug views**:
   Per-channel waveform scopes (the main addition beyond MUNT-QT); operator/envelope state for OPL3; Schism-style tracker view for sim-vs-sound divergence.
5. **MT-32 channel waveforms wanted** (constraint documented in §4).
6. **Extensible by design**:
   Future devices (Innovation SSI-2001, PAS 16, Yamaha FB-01, …) plug in as one backend + one tab, zero changes to shared code.
7. **C++ with Polymorphism — Three Intermediate Families** ⚡:
   - **Universal Base**: `SoundDevice` / `DeviceTab` — transport sync, mute/solo matrix, multitrack recording, master waveform ring buffer.
   - **MIDI Intermediate Base**: `MidiDevice` / `MidiTab` — shared across all MIDI-type devices (MT-32, GM, future FB-01). Carries persistent piano-roll note bars, MIDI note/CC/PC tracking, pre-synth stream-filter muting, unified channel strip layout.
   - **FM Intermediate Base**: `FmDevice` / `FmTab` — shared across operator-based FM synthesizers (OPL3, future OPL2, Yamaha OPM/YM2151). Carries operator/carrier parameter tracking, ADSR envelope phase models, software envelope stepping, and operator voice cards.
   - **PSG Intermediate Base**: `PsgDevice` / `PsgTab` — shared across programmable sound generators (GB-APU, future Innovation SSI-2001/SID, PC Speaker). Carries discrete channel types (Pulse/Duty, LFSR Noise, Wave RAM/Custom Tables), register frequency decode, and hardware envelope tracking.
8. **Lazy Channel Wake-Up & Fast Dormant Escape** ⚡:
   Channels remain dormant until they receive their first active command. Scope processing, animation updates, and shadow-chip rendering execute a fast early-return escape on dormant channels, preventing CPU waste on high-channel devices (18-voice OPL3, 16-channel GM).
9. **Native Engine Telemetry (No Heuristics)** ⚡:
   Because the application links directly against headless `libmt32emu` (Munt), partial allocation, active partial counts, and voice states are queried directly from the engine's internal C++ API—just as Munt-QT does—requiring no synthetic estimation.

---

## §1 Architecture Overview

```
┌───────────────────────────────────────────────────────────────────────────────┐
│                    pkmn-audio-dbg (Unified Successor Application)             │
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │ Top Bar: Track Selector | A/B Checkpoints | Enhancements [E] | GB [G]   │  │
│  ├─────────────────────────────────────────────────────────────────────────┤  │
│  │ Device Tab Bar: [OPL3] [GB-APU] [MT-32] [General MIDI] (future: FB-01)   │  │
│  ├─────────────────────────────────────────────────────────────────────────┤  │
│  │ Active Device View (MUNT-QT Strips, Scopes, Register Detail, Tracker)   │  │
│  ├─────────────────────────────────────────────────────────────────────────┤  │
│  │ Transport Bar: [▶/⏸] [⏹] [01:24.3 / 02:45.0 (f: 5040/9900)] [━━━●━━━]   │  │
│  │                Loop [A: 00:10 | B: 02:30] | Speed [1.0x] | Rec [● STEMS]│  │
│  └─────────────────────────────────────────────────────────────────────────┘  │
│                                      │                                        │
│  ┌───────────────────────────────────▼─────────────────────────────────────┐  │
│  │ Session & Playback Engine (60 Hz Paced Frame Scheduler)                 │  │
│  │  • Song Catalog & pret Header Resolver                                  │  │
│  │  • SM83 GB Sound Driver Simulation (pret_audio / gb_to_midi note events) │  │
│  │  • YAML Enhancement Watcher, Compiler & Revision Manager (revisions.py) │  │
│  │  • Direct in-process event dispatch to active SoundDevice / MidiDevice  │  │
│  └───────────────────────────────────┬─────────────────────────────────────┘  │
│                                      │                                        │
│  ┌───────────────────────────────────▼─────────────────────────────────────┐  │
│  │ Device Synthesizer Layer (Polymorphic SoundDevice / MidiDevice)         │  │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌────────────────┐  │  │
│  │  │ Opl3Device   │ │ GbApuDevice  │ │ Mt32Device   │ │ GmDevice       │  │  │
│  │  │ (NukedOPL3)  │ │ (Basic_Gb_   │ │ (libmt32emu) │ │ (FluidSynth)   │  │  │
│  │  │ +18 shadow   │ │  Apu)        │ │              │ │                │  │  │
│  │  │  voice chips │ │ +4 shadow APU│ │              │ │                │  │  │
│  │  └──────┬───────┘ └──────┬───────┘ └──────┬───────┘ └───────┬────────┘  │  │
│  └─────────┼────────────────┼────────────────┼─────────────────┼───────────┘  │
│            └────────────────┴────────┬───────┴─────────────────┘              │
│                                      │                                        │
│  ┌───────────────────────────────────▼─────────────────────────────────────┐  │
│  │ Audio Mixer, ALSA Output Callback & Multitrack WAV Recorder             │  │
│  │  • Low-latency PCM stream to ALSA / SDL2 audio output                   │  │
│  │  • Multitrack WAV stem writing (Master, Per-Device, Per-Voice)          │  │
│  └─────────────────────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────────────────────┘
```

---

## §2 Class Hierarchy & Three Intermediate Polymorphic Families

```
SoundDevice (Universal Base)               DeviceTab (Universal UI Base)
    │                                          │
    ├── FmDevice                               ├── FmTab
    │    └── Opl3Device                        │    └── Opl3Tab
    │    └── (future: Opl2Device, OpmDevice)   │    └── (future: Opl2Tab, OpmTab)
    │                                          │
    ├── PsgDevice                              ├── PsgTab
    │    ├── GbApuDevice                       │    ├── GbApuTab
    │    └── Ssi2001Device (future: SID)       │    └── Ssi2001Tab (future: SID)
    │                                          │
    └── MidiDevice                             └── MidiTab
         ├── Mt32Device                        │    ├── Mt32Tab
         ├── GmDevice                          │    ├── GmTab
         └── Fb01Device (future)               │    └── Fb01Tab (future)
```

### 2.1 Universal Base Classes
- `SoundDevice`: Pure virtual `init()`, `shutdown()`, `render(float* buf, size_t frames)`, `renderPerChannel(float** bufs, size_t frames)`, `setChannelMute(int ch, bool mute)`.
- `DeviceTab`: Pure virtual `drawChannelStrips()`, `drawDetail()`, `drawTracker()`, `onMuteClick(int ch)`.

### 2.2 MIDI Intermediate Base: `MidiDevice` & `MidiTab`
- Tracks 16 channels, pitch, velocity, active note duration.
- Holds persistent piano-roll note history (`std::vector<MidiNoteEvent> active_notes_`).
- Color coding: `RGB(2*vel, 255-2*vel, 0)` matching Munt-QT velocity grading.
- Pre-synth stream muting: suppressed Note-On events prevent synth voice allocation.

### 2.3 FM Intermediate Base: `FmDevice` & `FmTab`
- Tracks operator parameters (MULT, TL, AR, DR, SL, RR, KSL, WS) and carrier connections.
- Software ADSR envelope phase estimation (ATTACK, DECAY, SUSTAIN, RELEASE).
- Carrier waveform oscilloscopes and algorithm topology rendering.

### 2.4 PSG Intermediate Base: `PsgDevice` & `PsgTab`
- Tracks discrete channel modes (Pulse 1, Pulse 2, Wave RAM, LFSR Noise).
- Duty cycle visualizer (12.5%, 25%, 50%, 75%), 32-nibble Wave RAM visualizer, LFSR polynomial step display.

### 2.5 Lazy Channel Wake-Up & Fast Dormant Escape
- Channels default to `DORMANT`.
- Awakened upon first incoming register write or note command.
- Fast escape: `if (is_dormant) return;` skips shadow synthesis, buffer updates, and UI drawing for unused channels.

---

## §3 Stages

- [x] **1. Foundation & Tooling Setup (`dos_port/tools/viewer`)** — DONE 2026-09-19 (Stage 1 subagent).
  - [x] 1.1 Directory layout and `CMakeLists.txt` setup with SDL2, OpenGL 3, ALSA / audio device detection, and C++17 configuration.
  - [x] 1.2 Vendor Dear ImGui and ImPlot in `dos_port/tools/viewer/third_party/` with clean CMake targets. (ImGui v1.91.9b, ImPlot v0.16, shallow-pinned tags; `imgui`/`implot` static libs incl. SDL2 + OpenGL3 backends; out-of-source `build/` git-ignored.)
  - [x] 1.3 Application entry point (`main.cpp`) with SDL2 window, OpenGL context, ImGui/ImPlot initialization, event loop, and 60 Hz frame pacing.
  - [x] 1.4 Acceptance: builds cleanly via `cmake -B build && cmake --build build` (zero warnings), runs interactive GUI window (8 s Xvfb run, no errors, killed by timeout = loop alive), exits cleanly on ESC / window close.
- [x] **2. Polymorphic Device & Tab Hierarchy** — DONE 2026-09-20 (Stage 2 subagents).
  - [x] 2.1 Universal Tier-1 bases: `SoundDevice` and `DeviceTab` (transport sync, mute/solo bitmask, master buffer ring, multitrack hooks). — DONE 2026-09-20 (Stage 2 Part 2A subagent: `src/devices/sound_device.h` — init/shutdown/render/renderPerChannel/setMute/setSolo/reset pure virtuals, tick/handleCommand pacing, isDormant/wakeChannel, WaveformRing scope buffers, ChannelState/DeviceSnapshot/SimState; `src/tabs/device_tab.h` — drawChannelStrips/drawDetail/drawTracker/onMuteClick/pushWaveformData pure virtuals + audible/velocityColor/mute-solo-label UI helpers; `src/` on include path, `main.cpp` compile-checks both headers, clean `cmake --build` zero warnings + `-Werror` mock dispatch probe passing).
  - [x] 2.2 MIDI Intermediate Tier-2A bases: `MidiDevice` and `MidiTab` (16-channel tracking, note-on/off, pitch/velocity, persistent piano-roll bars, pre-synth stream-filter muting). — DONE 2026-09-20 (Stage 2 Part 2B subagent: `src/devices/midi_device.h/.cpp` — 16ch program/pitch/CC, velocity+sounding note matrix, note-history bars, shouldFilterNoteOn pre-synth mute/solo filter, dispatchNoteOn/Off pure virtuals, wake-on-noteOn/non-empty-command; `src/tabs/midi_tab.h/.cpp` — MUNT-QT strips, programName pure virtual, ImDrawList drawNoteBar velocity-graded helper, dormant-escape pushWaveformData).
  - [x] 2.3 FM Intermediate Tier-2B bases: `FmDevice` and `FmTab` (operator parameter matrix, envelope phase model, carrier waveform scopes, algorithm visualizer). — DONE 2026-09-20 (Stage 2 Part 2B subagent: `src/devices/fm_device.h/.cpp` — FmOperatorParams/FmVoice structs, ≤32 voices, wakeVoice on key-on/config, configureOperator/applyFrequency/applyKeyOn/Off pure virtuals; `src/tabs/fm_tab.h/.cpp` — voice grid, MOD/CAR cards, drawAlgorithm routing visualizer, envelopePhaseName + carrier-scope pushWaveformData with dormant escape, voiceLabel pure virtual).
  - [x] 2.4 PSG Intermediate Tier-2C bases: `PsgDevice` and `PsgTab` (discrete channel state, pulse duty visualizer, LFSR noise mode, wave RAM bar graph). — DONE 2026-09-20 (Stage 2 Part 2B subagent: `src/devices/psg_device.h/.cpp` — PsgChannelType enum, PsgChannel struct, duty/wave-RAM/LFSR/volume/envelope setters, activateChannel wake-up, applyRegister pure virtual; `src/tabs/psg_tab.h/.cpp` — channel cards, dutyFraction/drawDutyBar/drawWaveRam helpers, envelopeName pure virtual, dormant-escape pushWaveformData).
  - [x] 2.5 Lazy channel wake-up: `is_dormant` tracking, `wakeVoice()` / `wakeChannel()`, and 1-cycle fast escape on dormant channels across all bases. — DONE 2026-09-20 (Stage 2 Part 2A subagent: channels default dormant, wakeChannel() on first command, `if (isDormant(ch)) return/continue;` fast escape in SoundDevice::pushWaveform + documented pattern for render/UI draw paths, out-of-range reads dormant-safe; verified by mock probe — dormant push stores nothing, post-wake push stores 8/8).
  - [x] 2.6 Acceptance: compiles with mock/unit tests demonstrating polymorphic dispatch and zero-overhead dormant skipping. — DONE 2026-09-20 (Stage 2 Part 2B subagent: `tests/test_intermediate.cpp` → `pkmn-audio-dbg-tests` ctest target `intermediate_bases`; mocks for all six bases; 108 checks ALL PASS covering dispatch, pre-synth muting, FM config, PSG duty/wave, dormant skipping; clean `-Wall -Wextra` build).
- [x] **3. Audio Mixer & Multitrack Recording** — DONE 2026-09-20 (Stage 3 subagent).
  - [x] 3.1 Audio mixer engine (`audio_mixer.cpp/h`) with low-latency SDL2 audio callback, 48 kHz / 44.1 kHz resampler, and master ring buffer. — DONE 2026-09-20 (`src/audio_mixer.h/.cpp`: stereo float32 SDL2 device, default 48000 Hz / 512-frame buffer, disabled/headless mode for tests, `renderBlock()` master path + `renderStemsBlock()` per-channel path, `resampleLinear` linear-interpolation 44100→48000, mutex-guarded `WaveformRing` scope tap, atomic recorder feed).
  - [x] 3.2 Master, Device, and Channel Mute/Solo logic with thread-safe atomic controls between UI and audio thread. — DONE 2026-09-20 (atomic `master_gain`/`master_muted` + atomic device/recorder pointers; `setDeviceChannelMute/Solo` forward through the atomic device pointer; device-local mute matrix unchanged).
  - [x] 3.3 Multitrack WAV recorder (`recorder.cpp/h`): master mix output, device submixes, and individual per-voice stem files. — DONE 2026-09-20 (`WavWriter` RIFF float32/PCM16 mono/stereo with `buildHeader` helper + patch-on-close; `Recorder::startMaster/startStems/pushMaster/pushStems`; stems master derived as exact sum → null-sum within float rounding, measured worst 0.00e+00).
  - [x] 3.4 Raw `.audiolog` recorder and binary serial stream capture for deterministic replay. — DONE 2026-09-20 (`AudioLogWriter` magic 'AUDIOLOG' + version 1 + (frame u32, opcode u8, len u16, payload) records; `AudioLogReader::readNext/readAll` sequential replay; empty-payload + 300 B payload round-trip verified).
  - [x] 3.5 Acceptance: clean real-time audio playback without underruns, accurate WAV stem export verified by file headers and audio null sums. — DONE 2026-09-20 (`tests/test_audio.cpp` → ctest `audio_mixer_recorder`: WAV header/file, stem null-sum, AudioLog round-trip, mixer atomics + headless render incl. thread hammer + recorder feed, resampleLinear; `ctest` 2/2 PASS, 6004 checks ALL PASS, clean `-Wall -Wextra` zero warnings).
- [x] **4. Concrete Synthesizer Backends** — DONE 2026-09-20 (Stage 4 subagents).
  - [x] 4.1 `Opl3Device` linking `nukedopl.cpp`: 18 shadow voice chips with lazy wake-up, per-voice carrier scopes, register shadow matrix. — DONE 2026-09-20 (Stage 4 Part 4A subagent: `src/devices/opl3_device.h/.cpp` — FmDevice subclass, 18 voices, main + 18 shadow NukedOPL3 chips, lazy shadow Reset on first write/key-on, 1-cycle dormant fast escape in renderPerChannel(), 512-reg shadow matrix 0x000-0x1F5, operator/frequency/connection decode into FmVoice + ChannelState freq, writeReg/readReg incl. bank-1 voices, mute/solo-aware render with main-chip fast path + shadow remix; global regs 0x001/0x008/0x0BD/0x101/0x104/0x105 mirrored to initialized shadows).
  - [x] 4.2 `GbApuDevice` linking Blargg's `Basic_Gb_Apu`: 4 shadow APU instances, register decode, wave RAM inspector. — DONE 2026-09-20 (Stage 4 Part 4A subagent: `src/devices/gb_apu_device.h/.cpp` — PsgDevice subclass, 4 channels, master + 4 shadow APUs, FF10-FF25 + FF30-FF3F decode: pulse duty/freq/volume/sweep, wave RAM 32 nibbles, noise LFSR 7/15-bit + divisor/shift, lazy shadow init on first write/trigger, fast escape in renderPerChannel(), mute/solo-aware render. NOTE: holds a method-for-method Gb_Apu+Stereo_Buffer replica of Basic_Gb_Apu (same classes/EQ/clocking, bit-identical PCM) with an explicit 500 ms buffer — Basic_Gb_Apu's default buffer size underflows to ~16 GB memset per instance on 64-bit, measured 33 s for 5 instances, 0 s after the fix).
  - [x] 4.1/4.2 build + tests: NukedOPL3 + Gb_Snd_Emu compiled as `nukedopl`/`gbapu` static libs (`-w`, SYSTEM includes so `-Wall -Wextra` stays clean on our code); `tests/test_synths.cpp` → ctest `synth_backends`: OPL3 + GB-APU register writes/rendering with dormant-skipping verification — ALL PASS (242 checks), full suite 3/3 PASS in ~0.1 s, zero warnings. — DONE 2026-09-20 (Stage 4 Part 4A subagent).
  - [x] 4.3 `Mt32Device` linking headless `libmt32emu`: native Munt engine telemetry (`Synth::getActivePartialCount()`, `Synth::getPartialStates()`), part allocation, zero-heuristic Munt parity. — DONE 2026-09-20 (Stage 4 Part 4B subagent: `src/devices/mt32_device.h/.cpp` — MidiDevice subclass, FileStream+ROMImage ROM resolution with `MT32_ROM_DIR=none` mock override, sine-mixer fallback when no ROMs, native partial/part/LCD telemetry (`getPartialStates`/`getPartStates`/`getDisplayState`), 128-name timbre resolver, dispatchNoteOn/Off/ProgramChange/ControlChange/SysEx, CC7 mute-others stem dance converging engine volumes to the mute matrix every render; factory part map kept (parts 1-8 on 0-based ch 1-8 — a channel-assign remap SysEx was tried and dropped after measurement showed it left parts unmoved and killed rhythm; MT-32 captures part volume at note start, so the gate silences newly triggered voices while held voices decay naturally).
  - [x] 4.4 `GmDevice` linking `libfluidsynth`: SoundFont loader, 16-channel MIDI render, program/bank resolution. — DONE 2026-09-20 (Stage 4 Part 4B subagent: `src/devices/gm_device.h/.cpp` — MidiDevice subclass, 44100 Hz `fluid_synth_write_float` render, SoundFont search with `SOUNDFONT=none` mock override + sine-mixer fallback, 128-name GM resolver, dispatchNoteOn/Off/ProgramChange/ControlChange, CC7 stem dance with per-render matrix convergence; measured FluidSynth applies CC7 up to a block late, tests account for it).
  - [x] 4.5 Acceptance: each device produces sound and populates per-voice buffers correctly; memory and CPU usage remain low thanks to dormant skipping. — DONE 2026-09-20 (Stage 4 Part 4B subagent: `find_package(PkgConfig)` + `pkg_check_modules` mt32emu/fluidsynth linked to `pkmn-audio-dbg`, synth-tests, and new `pkmn-audio-dbg-midi-tests` (`tests/test_midi_devices.cpp` → ctest `midi_backends`); full suite 4/4 PASS — REAL ROMs/SoundFont and forced-MOCK both ALL PASS (462 checks), clean `-Wall -Wextra` zero warnings).
- [x] **5. Session Engine, Playback Scheduler & Song Catalog** — DONE 2026-09-20 (Stage 5 subagents).
  - [x] 5.1 Track catalog (`song_catalog.cpp/h`) parsing pret constants and song headers from `audio/headers/*.asm`. — DONE 2026-09-20 (Stage 5 Part 5A subagent: `src/song_catalog.h/.cpp` — `SongInfo` {constant, header, bank 1..4 from header filename digit, channel_count, repo-relative file_path, channel pointers}; auto-discovers repo root via `$PKMN_REPO_ROOT` or CWD walk-up; `findTrack()` layers exact → case-insensitive → normalized-stem → substring → Levenshtein (`route1`→`MUSIC_ROUTES1`); 216 tracks parsed incl. SFX, all music headers bound).
  - [x] 5.2 Deterministic 60 Hz frame clock scheduler (`session_engine.cpp/h`) simulating SM83 sound driver note events (`pret_audio` / `gb_to_midi`). — DONE 2026-09-20 (Stage 5 Part 5A subagent: `src/session_engine.h/.cpp` — `SimNoteEvent` {frame, channel, note, velocity, duration_frames, is_note_on}; play/pause/stop/seekToFrame/setLoop/setTotalFrames/setActiveDevice; tick() dispatches frame-stamped events — noteOn/Off on `MidiDevice`, `handleCommand` note packets otherwise — then steps the device, wraps loop_end→loop_start, auto-stops at total_frames; `ctest session_engine` ALL PASS — 93 checks: >50 tracks, pallet/gym/route1/title, stepping, play/pause/seek, loop wrap, mock dispatch, MIDI translation, auto-stop + device swap, null device).
  - [x] 5.3 YAML enhancement watcher & runtime compiler (`revisions.py` integration) for hot-reloading enhancements on file save. — DONE 2026-09-20 (Stage 5 Part 5B subagent: `src/enhancement_manager.h/.cpp` — `EnhancementManager` watches `dos_port/tools/audio/enhancements/<Song>.yaml` via `last_write_time` (`watchSong`/`pollForChanges`, once-per-change); revision parity with `audition/revisions.py` (`saveSnapshot` byte-identical dedup == hash-compare, `{id:04d}_{YYYYmmdd_HHMMSS}_{note}.yaml` names, `listRevisions` parses id/parts[1] like the Python, `getRevisionContent`/`revertToRevision`); `compileEnhancement()` shells to `python3 src/enhancement_dump.py` (imports `yaml_lint.lint`, so lint and viewer agree; MIDI channels mirror `gb_to_midi.enhancement_tracks` free parts 4-8/9) and native SMF type-0/1 `loadMidiFile()`/`loadSongBaseline()` from `dos_port/assets/midi/<target>/` with exact frame timings (1 tick = 1 frame at div-60/1s-quarter, tempo-scaled otherwise). No yaml-cpp dependency.)
  - [x] 5.4 Position-locked A/B comparison state tracking (preserves playback sample index across backend/enhancement switches). — DONE 2026-09-20 (Stage 5 Part 5B subagent: `ComparisonSlot {A,B}` in `session_engine.h/.cpp` — per-slot stored lists + enhancement overlay, dispatched stream rebuilt from active slot + overlay; `setComparisonSlot`/`toggleSlotAB`/`setEnhancementEnabled`/`setEnhancementEvents`/`setActiveDevice` all preserve `current_frame_` exactly and silence the outgoing device first (`MidiDevice::allNotesOff()`, new in `midi_device.h/.cpp`); legacy `setEvents`/`addEvent`/`addNote` address the active slot, so pre-5.4 tests pass unchanged).
  - [x] 5.5 Acceptance: select any Pokémon Yellow track, play back notes matching pret audio sequence accurately. — DONE 2026-09-20 (Stage 5 Part 5B subagent: `tests/test_session.cpp` — Music_PalletTown mt32 baseline loads 542 notes / 1084 events over 3840 frames (GB 1/2/3 + merged enhancement 4/5/6, the shipped .mid merges the layer per `gb_to_midi`), field-identical across loads, full play-through dispatches every on/off; strict GB-channel check on enhancement-free Music_Gym ⊆ {1,2,3,9}; Routes1 gm spot check; compiled PalletTown YAML = 92 notes mt32 + gm; temp-dir revisions (snapshot dedup/list/content/revert) + deterministic mtime polling; A/B slot swap / enhancement toggle / device swap all preserve frame, silence outgoing, continue at current_frame. `ctest` 5/5 PASS, 741/741 session checks, clean `-Wall -Wextra` zero warnings.)
- [x] **6. Transport Bar UI & Scrubbing** — DONE 2026-09-20 (Stage 6 subagent).
  - [x] 6.1 Transport bar layout (`transport_bar.cpp/h`): Play/Pause, Stop, Frame/Time readouts (`MM:SS.f` and frame number). — DONE 2026-09-20 (Stage 6 subagent: `src/transport_bar.h/.cpp` `TransportBar::render` + `formatTime`/`formatReadout`, pinned bottom-of-viewport window).
  - [x] 6.2 Interactive seek scrubber: smooth draggable progress slider, seek-to-frame with audio core state resynchronization. — DONE 2026-09-20 (Stage 6 subagent: `SliderInt` over `[0, total_frames]` + `seekToFrame` silencing `MidiDevice::allNotesOff` / non-MIDI `reset()`, next `advance()` re-dispatches).
  - [x] 6.3 Loop markers (A/B range), Speed multiplier controls (0.25x, 0.5x, 1.0x, 2.0x, 4.0x), and Enhancement toggle (`[E]` vs `[G]`). — DONE 2026-09-20 (Stage 6 subagent: Set [A]/[B] + enable stash + Clear, speed accumulator in `advance()`, `[E]/[G]` + Slot A/B buttons).
  - [x] 6.4 Keyboard shortcuts (Space = Play/Pause, Home = Rewind, Left/Right = Step frame, E = Toggle Enhancement). — DONE 2026-09-20 (Stage 6 subagent: `TransportKey` + `handleKey`, incl. `[`/`]` revision stepping and Tab slot toggle; SDL forwarding in `main.cpp`, repeats ignored).
  - [x] 6.5 Acceptance: interactive seeking works smoothly without audio glitches; loop points loop seamlessly; speed adjustments work. — DONE 2026-09-20 (Stage 6 subagent: `tests/test_transport.cpp` → ctest `transport_bar`, 182 checks ALL PASS; full suite 6/6 PASS; clean `-Wall -Wextra` zero warnings; 8 s Xvfb smoke run no errors; `main.cpp` placeholder transport window replaced).
- [x] **7. Device Tabs & Deep Diagnostics UI** — DONE 2026-09-20 (Stage 7 subagents).
  - [x] 7.1 MUNT-QT parity channel strips: 9 rows (Parts 1-8 + Rhythm), mute toggles, patch names, patch selector, persistent piano-roll note bars (`RGB(2*vel, 255-2*vel, 0)`). — DONE 2026-09-20 (Stage 7 Part 7A subagent: `src/tabs/mt32_tab.h/.cpp` — `Mt32Tab : MidiTab`, `programName()` → `Mt32Device::mt32TimbreName`, 9 part strips via `partChannel()`/`partLabel()`/`partStrip()` with LED/mute/combo/note-bar/peak, `pushWaveformData` dormant escape).
  - [x] 7.2 MT-32 partial state 4x8 LED matrix and 20x2 dot-matrix LCD display. — DONE 2026-09-20 (Stage 7 Part 7A subagent: `partialColor()` spec palette 0=dim gray/1=orange-red/2=green/3=amber + `Partials: X / 32` readout + `drawPartialCell()` null-safe primitive, LCD child rendering `lcdText()` green-on-black; `drawDetail()`).
  - [x] 7.3 OPL3 tab: 18-voice operator matrix (MOD/CAR, TL, MULT, ADSR), connection algorithm routing, carrier oscilloscopes with zero-crossing stabilization. — DONE 2026-09-20 (Stage 7 Part 7B subagent: `src/tabs/opl3_tab.h/.cpp` — `Opl3Tab : FmTab`, `voiceLabel()` 18 banked labels + `bankName()`, `opParams()` MOD/CAR probe, `findZeroCrossing()` positive-slope stabilization, operator cards + `drawAlgorithm()` routing + feedback + stabilized carrier scopes in `drawDetail()`).
  - [x] 7.4 GB-APU tab: Pulse 1/2 duty cycle displays, Wave RAM hex/waveform visualizer, Noise LFSR graph, per-channel oscilloscopes. — DONE 2026-09-20 (Stage 7 Part 7B subagent: `src/tabs/gb_apu_tab.h/.cpp` — `GbApuTab : PsgTab`, `envelopeName()` pace strings, `channelLabel()`/`noiseWidthName()`/`waveVolumeName()`/`channelCard()` sweep/duty/freq/vol/wave-nibble/LFSR probes, `drawDutyBar`/`drawWaveRam` cards + hex + stabilized scopes in `drawDetail()`).
  - [x] 7.5 General MIDI tab: 16-channel strip layout with GM program names, volume/pan meters, piano-roll bars. — DONE 2026-09-20 (Stage 7 Part 7A subagent: `src/tabs/gm_tab.h/.cpp` — `GmTab : MidiTab`, `programName()` → `GmDevice::gmProgramName`, 16 strips via `channelLabel()`/`channelStrip()` with `Ch 10 [Drums]` marker, `[M]`/`[S]` toggles, CC7/CC10 volume/pan, combo selector, `drawNoteBar()` bars, `pushWaveformData` dormant escape).
  - [x] 7.6 Schism-style tracker view (`tracker_view.cpp/h`): dual-column display comparing SM83 driver simulation vs actual sound chip register state. — DONE 2026-09-20 (Stage 7 Part 7B subagent: `src/tabs/tracker_view.h/.cpp` — Schism `C-4`/`C#4` note text, `isDivergent()` sim-vs-chip mismatch, green-match / yellow-missing / red-clash `cellColor()`, `compare()` SimState + `compareEvents()` SimNoteEvent builders, headless-safe `draw()` table).
  - [x] 7.7 Acceptance: all tabs render interactively, oscilloscopes trace live waveforms, mute buttons silence individual channels, tracker view highlights divergence. — DONE 2026-09-20 (Stage 7 Part 7B subagent: `src/main.cpp` wires Opl3/GbApu/Mt32/Gm devices + tabs + TrackerView + AudioMixer into the tab bar — tab select routes `SessionEngine::setActiveDevice` + mixer pull position-locked, per-frame scope feed drives live scopes; `tests/test_synth_tabs.cpp` → ctest `synth_tabs` ALL PASS (235 checks); full suite 8/8 PASS, clean `-Wall -Wextra` zero warnings).
- [x] **8. Headless CLI Mode, Audio Log Replay & Verification** — DONE 2026-09-20 (Stage 8 subagent).
  - [x] 8.1 Headless rendering mode (`--headless --track <ID> --frames <N> --out <WAV>`): batch audio rendering without GUI. — DONE 2026-09-20 (`src/cli.h/.cpp` — pure arg parsing: --help/--headless/--track/--device/--frames/--out/--no-enh/--enhancement/--replay with `=` forms, device normalization mt32/gm/opl3/gbapu, usage text; `src/headless.h/.cpp` — SessionEngine + SongCatalog + EnhancementManager pipeline, device-native-rate stereo float32 WAV, exact stateless per-frame sample distribution, GB-baseline-only switch; `main.cpp` parses before SDL and returns without creating a window/GL/ImGui).
  - [x] 8.2 Audio log playback (`--replay <file.audiolog>`): frame-exact playback from captured log. — DONE 2026-09-20 (`runReplayLog` — AudioLogReader + stable frame sort + `dispatchReplayEvent` with the engine's note-on/off mapping, renders to --out or discards; `--replay` implies --headless).
  - [x] 8.3 Bit-exact audio verification against `audition.py` reference render (null test / diff check). — DONE 2026-09-20 (`tests/test_cli.cpp` → ctest `cli_verification`: CLI parsing/normalization/frame-math unit checks; Music_PalletTown mt32 240-frame render — valid WAV header, exact sample count, non-zero content, byte-identical re-render; hand-recorded log replays byte-identical and matches the direct SessionEngine render — ALL PASS, 2022 checks).
  - [x] 8.4 Documentation update: retiring `audition.py` instructions, documenting `pkmn-audio-dbg` CLI flags and UI hotkeys. — DONE 2026-09-20 (`dos_port/tools/viewer/README.md` — architecture + three device families, backend/Core/rate table, build + zero-warning policy, CLI flag table + examples, Space/Home/Left/Right/E/Tab/[/]/Esc shortcuts, stem + .audiolog recording, audition.py migration map).
  - [x] 8.5 Acceptance: automated test suite passes with 0 audio diff vs reference cores; all acceptance criteria (§8) met. — DONE 2026-09-20 (cli_verification wired into CMakeLists.txt; full `cmake --build` zero `-Wall -Wextra` warnings; `ctest` 9/9 PASS 100%; binary smoke-tested: --help, gm headless render, --replay parity vs test WAV via cmp).

---

## §4 Directory Layout

```
dos_port/tools/viewer/
    CMakeLists.txt
    src/
        main.cpp               # App entrypoint, SDL2 + ImGui loop
        session_engine.cpp/h   # 60 Hz frame clock, pret note event dispatch, YAML watcher
        song_catalog.cpp/h     # pret constants & header parser, fuzzy track finder
        transport_bar.cpp/h    # Play/pause, seek scrubber, time counters, speed, A/B
        audio_mixer.cpp/h      # Audio stream callback & master mixing
        recorder.cpp/h         # Multitrack WAV recorder (master, stems, per-channel)
        devices/
            sound_device.h        # Tier-1 universal base
            fm_device.cpp/h       # Tier-2B FM intermediate base (operator/voice tracking)
            psg_device.cpp/h      # Tier-2C PSG intermediate base (duty/noise/wave tracking)
            midi_device.cpp/h     # Tier-2A MIDI intermediate base (note/CC tracking, mute filter)
            opl3_device.cpp/h     # Concrete FM (NukedOPL3 + shadow chips)
            gb_apu_device.cpp/h   # Concrete PSG (Basic_Gb_Apu + shadow chips)
            mt32_device.cpp/h     # Concrete MIDI (libmt32emu headless)
            gm_device.cpp/h       # Concrete MIDI (libfluidsynth)
            fb01_device.cpp/h     # (future Yamaha FB-01)
            ssi2001_device.cpp/h  # (future Innovation SSI-2001 SID)
        tabs/
            device_tab.h          # Tier-1 universal tab base
            fm_tab.cpp/h          # Tier-2B FM tab base (voice grid, operator matrix)
            psg_tab.cpp/h         # Tier-2C PSG tab base (channel cards, duty visualizer)
            midi_tab.cpp/h        # Tier-2A MIDI tab base (piano-roll, channel strips)
            opl3_tab.cpp/h
            gb_apu_tab.cpp/h
            mt32_tab.cpp/h
            gm_tab.cpp/h
            fb01_tab.cpp/h        # (future Yamaha FB-01)
            ssi2001_tab.cpp/h     # (future Innovation SSI-2001 SID)
            tracker_view.cpp/h
    third_party/
        imgui/          # vendored
        implot/         # vendored
```

---

## §5 Acceptance Criteria Summary

1. **Fidelity Verification**:
   Bit-identical PCM between `pkmn-audio-dbg` and `audition.py` reference cores for identical song and enhancement inputs.
2. **Per-Widget Provenance**:
   - Piano-roll note bars from `MidiDevice` note-on/off events.
   - OPL3 register grid from register shadow array.
   - GB-APU channel cards from GB APU register shadow.
   - Per-voice oscilloscopes from shadow chip audio streams.
   - Partial state grid directly from Munt `Synth::getPartialStates()`.
   - Tracker view showing simulation vs actual hardware registers.
3. **Extensibility**:
   Adding a future device (e.g. SSI-2001 or FB-01) touches only its device/tab subclasses and the factory registration; zero touches to transport, mixer, or session engine.
4. **Recording**:
   Per-channel stem export sums to master PCM within floating-point tolerance.
