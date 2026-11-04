"""Editor preferences, overridable from a JSON file.

Defaults live here; a `config.json` next to this module overrides them. The file
is optional — a missing or empty config is not an error, so the tool works on a
fresh checkout and an LLM can edit the file without touching code.

Unknown keys are rejected rather than ignored: a typo in a config file that
silently does nothing is worse than a startup error.
"""
from __future__ import annotations

import json
from pathlib import Path

CONFIG_PATH = Path(__file__).resolve().parent / "config.json"

DEFAULTS = {
    # Where the view anchors when the zoom changes: "cursor" keeps the map point
    # under the mouse still, "center" keeps the viewport centre still.
    "zoom_anchor": "cursor",
    # Zoom bounds and the per-notch multiplier for the scroll wheel.
    "zoom_min": 0.25,
    "zoom_max": 6.0,
    "zoom_step": 1.1,
    # Multiplier for the keyboard zoom (Ctrl+= / Ctrl+-).
    "zoom_key_step": 1.25,
    # Mouse button that pans: 1 left, 2 middle, 3 right.
    "pan_button": 2,
    # UI chrome scale. "auto" derives it from the window size (so it follows a
    # resize); a number pins it. Bounds apply either way.
    "ui_scale": "auto",
    "ui_scale_min": 0.75,
    "ui_scale_max": 2.5,
    # The window size "auto" is measured against.
    "ui_reference": [1024, 700],
}

_ALLOWED_ANCHORS = ("cursor", "center")


def load(path: Path | None = None) -> dict:
    """Return the effective settings: DEFAULTS updated by the JSON file."""
    path = CONFIG_PATH if path is None else path
    settings = dict(DEFAULTS)
    if not path.exists():
        return settings
    raw = json.loads(path.read_text())
    if not isinstance(raw, dict):
        raise ValueError(f"{path}: expected a JSON object")
    unknown = set(raw) - set(DEFAULTS)
    if unknown:
        raise ValueError(f"{path}: unknown setting(s) {sorted(unknown)}; "
                         f"known keys are {sorted(DEFAULTS)}")
    settings.update(raw)
    validate(settings, path)
    return settings


def validate(settings: dict, where: object = "config") -> None:
    if settings["zoom_anchor"] not in _ALLOWED_ANCHORS:
        raise ValueError(f"{where}: zoom_anchor must be one of {_ALLOWED_ANCHORS}")
    if not 0 < settings["zoom_min"] <= settings["zoom_max"]:
        raise ValueError(f"{where}: need 0 < zoom_min <= zoom_max")
    if settings["zoom_step"] <= 1 or settings["zoom_key_step"] <= 1:
        raise ValueError(f"{where}: zoom steps must be greater than 1")
    if settings["pan_button"] not in (1, 2, 3):
        raise ValueError(f"{where}: pan_button must be 1, 2 or 3")
    scale = settings["ui_scale"]
    if scale != "auto" and not isinstance(scale, (int, float)):
        raise ValueError(f"{where}: ui_scale must be \"auto\" or a number")
    if isinstance(scale, (int, float)) and not scale > 0:
        raise ValueError(f"{where}: ui_scale must be positive")
    if not 0 < settings["ui_scale_min"] <= settings["ui_scale_max"]:
        raise ValueError(f"{where}: need 0 < ui_scale_min <= ui_scale_max")
    ref = settings["ui_reference"]
    if (not isinstance(ref, (list, tuple)) or len(ref) != 2
            or any(not isinstance(v, int) or v <= 0 for v in ref)):
        raise ValueError(f"{where}: ui_reference must be [width, height]")
