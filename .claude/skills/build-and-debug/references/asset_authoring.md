# Asset-Authoring Tools (Palettes, Maps, UI Layout)

Detailed reference for the interactive pygame authoring tools, sidecar JSON schemas, and asset regeneration workflows.

---

## Two-Tier Rule for Asset Authoring

The project strictly separates hand-authored data from generated code:
1. **Tier 1 (Data / Sidecars)**: Hand-authored sidecar JSON files (e.g. `assets/colors/palettes.json`, `assets/map_overrides/*.json`, `assets/ui_layout_*_sidecar.json`).
2. **Tier 2 (Generated Code & Tables)**: Generated files in `dos_port/assets/*.inc`.

> [!WARNING]
> **Never hand-edit generated `assets/*.inc` files.**
> Pointer tables (e.g. `MapHeaderPointers`) and tile blobs are computed at generation time. Hand-editing an `.inc` will desync pointers, corrupt runtime memory, and will be overwritten on the next `make assets`. Always edit the sidecar JSON and run `make -C dos_port assets`.

---

## Palette Colorization Pipeline (`colorize.py` & `colors/editor.py`)

The colorization pipeline maps Game Boy palettes to VGA Mode 13h 6-bit DAC values.

### CLI Commands
```sh
# Generate assets/colors/palettes.inc from sidecar and pret source
dos_port/tools/colorize.py --gen

# Verify sidecar schema and check that palettes.inc is up to date
dos_port/tools/colorize.py --verify

# Launch interactive pygame shade editor
dos_port/tools/colorize.py --edit

# Export indexed PNG for pixel repainting
dos_port/tools/colorize.py --export-png SPECIES

# Re-import repainted PNG (<=4 colors/tile, <=4 palettes/asset), then re-run --gen
dos_port/tools/colorize.py --import-png PATH.png
```

### Pygame Shade Editor Keybindings (`colors/editor.py`)
- `[` / `]`: Cycle palette family (`PAL_*`).
- `,` / `.`: Cycle preview subject species.
- `t`: Toggle mock mode between **mon battle** (enemy front sprite + player-mon back sprite) and **trainer battle** (enemy trainer front pic + Red back sprite).
- `2` – `4`: Select shade 2, 3, or 4 for editing.
- Arrow keys (`Up` / `Down` / `Left` / `Right`): Adjust Red and Green channels.
- `PgUp` / `PgDn`: Adjust Blue channel.
- `S`: Save deltas to `assets/colors/palettes.json` (sidecar).
- `Esc`: Quit editor.

### Load-Bearing Palette Rules
- **Shade 1 (Index 0) is Read-Only**: The background white shade (`31, 31, 31` in pret's CGB palette) is shared across all 40 `CGBBasePalettes`. Changing it per-palette would corrupt the global background; the editor marks it read-only.
- **Species Palette Binding**: In mon mode, the preview palette automatically follows the species' defined `MonsterPalettes` entry. Sprite paths are resolved via pret's filenames (`gfx_core/sprites.py`).
- **Auto-Mapping**: Colors are automatically converted from 5-bit CGB to 6-bit VGA via `round(v * 63 / 31)`. The sidecar stores only manual overrides (`pal_overrides`).

---

## Overworld Map Editor (`map_editor/editor.py`)

Viewer and painter for map border-ring authoring and block painting.
```sh
python3 dos_port/tools/map_editor/editor.py [options]
```
- Edits sidecars in `dos_port/assets/map_overrides/<PascalCaseMapName>.json`.
- Feeds `dos_port/tools/generators/gen_map_borders.py` during `make assets`.
- Run with `--help` to view current active controls.

---

## UI Layout Editor (`ui_layout/editor.py`)

Interactive tool for placing UI text and box elements on the native 320×200 widescreen canvas with live preview.
```sh
# Launch layout editor on subsystem sidecar
python3 dos_port/tools/ui_layout/editor.py dos_port/assets/ui_layout_<subsystem>_sidecar.json

# Project sidecar to assembly include
python3 dos_port/tools/generators/gen_ui_layout.py <subsystem>
```

### Sidecar Bootstrapping
When creating a layout sidecar for a new screen:
- `tools/ui_layout/seed_from_battle.py`: Bootstraps layout coordinates from existing battle layouts.
- `tools/ui_layout/seed_from_pret.py`: Bootstraps layout coordinates from pret's `TextBoxCoordTable`.
- These are one-shot scripts used only when initializing a new subsystem.
