# Joypad Subsystem Refactoring, DOS Gamepad Support & Table-Driven Config Parser

## Problem Statement & Architecture Goals

1. **Faithful pret Joypad Architecture**:
   - On Game Boy / pret, `ReadJoypad` (in VBlank ISR) only polls hardware into `hJoyInput`.
   - `_Joypad` is called on-demand by game logic (`JoypadOverworld`, `HandleMenuInput`, `JoypadLowSensitivity`), computing `hJoyPressed` / `hJoyReleased` against `hJoyLast` and updating `hJoyLast`.
   - The DOS port previously conflated sampling with edge calculation inside `DelayFrame`, making `hJoyPressed` a transient 1-frame pulse that broke multi-frame loops (`OverworldLoop`) and led to ad-hoc latches (`overworld_joy_latch`, `jls_prev`).
   - **Goal**: Restore 100% faithful pret joypad execution with zero dropped pret labels or bypassed calls.

2. **Modular Audio-Style Input HAL**:
   - Structure `src/input/` into clean HAL modules mirroring the audio subsystem pattern:
     - `src/input/input_hal.asm` (coordinator & virtual joypad driver)
     - `src/input/kbd_isr.asm` (INT 9h keyboard ISR driver)
     - `src/input/gamepad_hal.asm` (DOS game port `0x201` driver)
     - `src/input/input_cfg.asm` (table-driven `.cfg` parser)

3. **Dual Device Driver with Zero Overhead**:
   - `g_input_device` selects active device (`0 = Keyboard`, `1 = Gamepad`).
   - When Keyboard is active, zero gameport I/O is performed.
   - When Gamepad is active, game port `0x201` is polled with bounded axis timeout loops.

4. **Table-Driven Extensible NASM Config Parser (`POKEMON.CFG`)**:
   - Pure x86 NASM parser loaded once at boot in `boot/entry.asm` before any pret translated code runs.
   - Parses section headers, comments (`;`/`#`), key names (`up`, `down`, `enter`, `z`, `x`, `w`, `a`, `s`, `d`, etc.) and hex literals (`0x48`).
   - Populates static byte literals (`cfg_key_*`) with fallback to current defaults if the file is missing or omitted.
   - Zero parsing overhead during gameplay frames.

---

## Technical Design & Modules

```
               [ POKEMON.CFG (on disk) ]
                           | (parsed once at boot via DPMI INT 21h)
                           v
              [ Byte Literals cfg_key_* ]
                           |
 +-------------------------+     +--------------------------+
 | src/input/kbd_isr.asm   |     | src/input/gamepad_hal.asm|
 | (INT 9h Keyboard ISR)   |     | (Game Port 0x201 Driver) |
 +------------+------------+     +------------+-------------+
              |                               |
              +---------------+---------------+
                              | (selected by g_input_device)
                              v
             +-----------------------------------+
             | src/input/input_hal.asm           |
             | - input_poll_hardware             |
             |   (runs in DelayFrame / VBlank)   |
             | - Writes raw held state to        |
             |   hJoyInput (and emulated IO_JOYP)|
             +----------------+------------------+
                              |
                              v (hJoyInput)
             +-----------------------------------+
             | src/engine/joypad.asm: _Joypad    |
             | (pret faithful mirror)            |
             | - Called on-demand via Joypad     |
             | - Computes hJoyPressed &          |
             |   hJoyReleased from hJoyLast      |
             | - Updates hJoyLast = hJoyInput    |
             | - Applies wJoyIgnore / soft reset |
             +----------------+------------------+
                              |
     +------------------------+------------------------+
     |                        |                        |
     v                        v                        v
+------------------+   +-------------------+   +--------------------+
| JoypadOverworld  |   |  HandleMenuInput  |   |JoypadLowSensitivity|
| (home/overworld) |   |  (home/window)    |   | (home/joypad2)     |
+------------------+   +-------------------+   +--------------------+
```

---

## Detailed Implementation Steps

### Phase 1: Input HAL & Config Parser (`dos_port/src/input/`)

1. **[`dos_port/src/input/input_cfg.asm`](file:///mnt/sdb1/Code/Active%20Code/pokeyellow_msdos/dos_port/src/input/input_cfg.asm)**:
   - Implement `input_config_load`:
     - Uses DPMI real-mode INT 21h (AH=3Dh open, AH=3Fh read, AH=3Eh close) to load `POKEMON.CFG`.
     - Scans lines: trims whitespace, skips empty lines and comments (`#`, `;`), handles `[section]`.
     - Matches keys against an extensible table (`cfg_table`).
     - Resolves scancodes (by name or hex) into byte literals:
       - `cfg_key_up` (default `0x48`)
       - `cfg_key_down` (default `0x50`)
       - `cfg_key_left` (default `0x4B`)
       - `cfg_key_right` (default `0x4D`)
       - `cfg_key_a` (default `0x2C` / 'Z' and Enter)
       - `cfg_key_b` (default `0x2D` / 'X' and Backspace)
       - `cfg_key_start` (default `0x1C` / Enter)
       - `cfg_key_select` (default `0x0F` / Tab)
       - `g_input_device` (default `0 = keyboard`, `1 = gamepad`)
     - On file-not-found or read error, leaves default byte literals untouched.

2. **[`dos_port/src/input/gamepad_hal.asm`](file:///mnt/sdb1/Code/Active%20Code/pokeyellow_msdos/dos_port/src/input/gamepad_hal.asm)**:
   - Implement `gamepad_poll`:
     - Reads digital buttons (port `0x201` bits 4..7): Button 1 -> A, Button 2 -> B, Button 3 -> Select, Button 4 -> Start.
     - Reads X1/Y1 axes (port `0x201` bits 0..1) with bounded threshold counter: Left/Right, Up/Down.
     - Returns GB active-high bitmask in `AL`.

3. **[`dos_port/src/input/kbd_isr.asm`](file:///mnt/sdb1/Code/Active%20Code/pokeyellow_msdos/dos_port/src/input/kbd_isr.asm)**:
   - Refactor `joypad.asm` -> `kbd_isr.asm`:
     - Keeps INT 9h ISR installation (`kbd_init`), restore (`kbd_restore`), scancode handling.
     - Tests incoming scancodes against `cfg_key_*` byte literals.
     - Maps active keys to `pad_dpad` and `pad_buttons` bitfields.

4. **[`dos_port/src/input/input_hal.asm`](file:///mnt/sdb1/Code/Active%20Code/pokeyellow_msdos/dos_port/src/input/input_hal.asm)**:
   - Top-level HAL coordinator:
     - `input_init`: calls `input_config_load`, `kbd_init`.
     - `input_restore`: calls `kbd_restore`.
     - `input_poll_hardware`: checks `[g_input_device]`, polls either keyboard state or `gamepad_poll`, writes `[ebp + hJoyInput]` and `[ebp + IO_JOYP]`.

---

### Phase 2: Faithful pret Mirror Wiring & Call Sites

5. **[`dos_port/src/home/vblank.asm`](file:///mnt/sdb1/Code/Active%20Code/pokeyellow_msdos/dos_port/src/home/vblank.asm)**:
   - Call `input_poll_hardware` in `DelayFrame` to update `hJoyInput`.

6. **[`dos_port/src/engine/joypad.asm`](file:///mnt/sdb1/Code/Active%20Code/pokeyellow_msdos/dos_port/src/engine/joypad.asm)**:
   - Make `ReadJoypad_` and `_Joypad` the canonical, active engine routines:
     - `ReadJoypad_`: checks `hDisableJoypadPolling`, calls `input_poll_hardware`.
     - `_Joypad`: checks soft-reset, computes `hJoyReleased` and `hJoyPressed` against `hJoyLast`, updates `hJoyLast`, sets `hJoyHeld = hJoyLast`, applies `wJoyIgnore` mask.
     - `DiscardButtonPresses`: zeroes `hJoyHeld`, `hJoyPressed`, `hJoyReleased`.
     - `TrySoftReset`: decrements `hSoftReset`, triggers `SoftReset` or loops to `Joypad`.

7. **[`dos_port/src/home/joypad.asm`](file:///mnt/sdb1/Code/Active%20Code/pokeyellow_msdos/dos_port/src/home/joypad.asm)**:
   - `Joypad::` -> `jmp _Joypad`
   - `ReadJoypad::` -> `jmp ReadJoypad_`

8. **[`dos_port/src/home/joypad2.asm`](file:///mnt/sdb1/Code/Active%20Code/pokeyellow_msdos/dos_port/src/home/joypad2.asm)**:
   - Restore `call Joypad` at the top of `JoypadLowSensitivity`.
   - Remove `jls_prev` workaround.

9. **[`dos_port/src/home/overworld.asm`](file:///mnt/sdb1/Code/Active%20Code/pokeyellow_msdos/dos_port/src/home/overworld.asm)**:
   - Restore `call Joypad` inside `JoypadOverworld`.
   - Remove `overworld_joy_latch` entirely.
   - `OverworldLoopLessDelay` directly checks `[ebp + hJoyPressed]` for non-simulated START/A and `[ebp + hJoyHeld]` for D-pad.

10. **[`dos_port/boot/entry.asm`](file:///mnt/sdb1/Code/Active%20Code/pokeyellow_msdos/dos_port/boot/entry.asm)**:
    - Update boot bring-up: `call input_init` and `call input_restore`.

11. **[`dos_port/Makefile`](file:///mnt/sdb1/Code/Active%20Code/pokeyellow_msdos/dos_port/Makefile)**:
    - Update sources to link `src/input/input_hal.asm`, `src/input/input_cfg.asm`, `src/input/kbd_isr.asm`, `src/input/gamepad_hal.asm`.

---

## Verification Plan

### Automated Tests
1. **Compilation & Linkage**:
   - `make -C dos_port check` (verifies all assembly units, symbol resolution, and `DEBUG_NOCLIP` smoke).
2. **Static Gate**:
   - `dos_port/tools/static_gate` (verifies 8/8 static checks and label database).
3. **Core Fidelity Suite**:
   - `make -C dos_port fidelity` (verifies all 16 core scenarios: `overworld_pallet`, `start_menu`, `bag_menu`, `party_menu`, `options_menu`, `naming_screen`, `sign_pallet`, `battle_menu`, `item_tm_teach`, etc.).
4. **Golden Scenarios**:
   - `dos_port/tools/goldencheck.sh warp_door`
   - `dos_port/tools/goldencheck.sh map_connection`
   - `dos_port/tools/goldencheck.sh poison_tick`
   - `dos_port/tools/goldencheck.sh beaten_trainer_talk`

### Manual Verification
- **Default Keyboard**:
  - Verify crisp 1-tap responsiveness for A (NPC talk), Start (menu open), menu items in DOSBox-X.
- **Custom Config Rebinding**:
  - Create a test `POKEMON.CFG` with custom bindings (e.g. `a = enter`, `b = backspace`, `up = w`, `down = s`, `left = a`, `right = d`), boot into DOSBox-X, and verify custom keys work immediately.
- **Gamepad in DOSBox-X**:
  - Enable DOSBox-X joystick emulation (`joysticktype=4axis`), set `device = gamepad` in `POKEMON.CFG` or config, and verify gamepad input.
