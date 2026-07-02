"""schema.py — layout sidecar JSON model + validation (subsystem-generic).

Element geometry ground truth stays in pret-native GB tile coordinates
(``gb``); the port projection is always DERIVED via canvas.py from the
per-axis anchor, never stored. This keeps the JSON diffable against the pret
source a faithfulness reviewer reads.
"""
from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path

KINDS = ("textbox", "window", "text", "cursor", "sprite_popup",
         # battle kinds (current_plan_battle_ui.md B1); sprite_popup is a
         # bordered box (menus MON_SPRITE_POPUP), NOT a pixel OAM group,
         # hence the separate oam_row.
         "hp_gauge", "mon_pic", "hud_frame", "oam_row")
ANCHORS_X = ("left", "center", "right", "custom")
ANCHORS_Y = ("top", "center", "bottom", "custom")

# Kinds whose geometry is dictated by the engine, not the designer:
# hp_gauge = "HP"+":"+6 segments+cap drawn as 9 consecutive tiles in one row
# (battle_hud.asm draw_hp_bar); mon_pic = 7x7 tile block (pics.asm
# PlacePicTilemap); oam_row = 6 party-status pokéball sprites in one row.
FIXED_SIZES = {"hp_gauge": (9, 1), "mon_pic": (7, 7), "oam_row": (6, 1)}
# hud_frame = corner + 8 underline + triangle shelf (width 10) with a $73
# connector column above one end: h=2 enemy (1 connector), h=3 player (2).
HUD_FRAME_W = 10


@dataclass
class Element:
    id: str
    kind: str
    gb_x: int
    gb_y: int
    gb_w: int
    gb_h: int
    anchor_x: str
    anchor_y: str
    shift_x: int | None = None      # used only when anchor_* == "custom"
    shift_y: int | None = None
    movable: bool = True
    resizable: bool = False
    min_w: int = 3                  # border + >=1 interior tile
    min_h: int = 3
    pret_id: int | None = None      # numeric textbox ID (constants/menu_constants.asm)
    text_label: str | None = None   # TextBoxTextAndCoordTable entries only
    text_x: int | None = None       # GB coords, projected with the box
    text_y: int | None = None
    source: str = ""
    pret_ref: str = ""
    anchor_source: str = "inferred"  # "inferred" until confirmed in the editor
    notes: str = ""

    def validate(self, canvas: dict, gb_canvas: dict) -> list[str]:
        errs = []
        if self.kind not in KINDS:
            errs.append(f"{self.id}: bad kind {self.kind!r}")
        if self.anchor_x not in ANCHORS_X or self.anchor_y not in ANCHORS_Y:
            errs.append(f"{self.id}: bad anchor {self.anchor_x}/{self.anchor_y}")
        if self.anchor_x == "custom" and self.shift_x is None:
            errs.append(f"{self.id}: anchor_x=custom needs shift_x")
        if self.anchor_y == "custom" and self.shift_y is None:
            errs.append(f"{self.id}: anchor_y=custom needs shift_y")
        if self.resizable and (self.gb_w < self.min_w or self.gb_h < self.min_h):
            errs.append(f"{self.id}: size {self.gb_w}x{self.gb_h} under min")
        if self.kind in FIXED_SIZES:
            fw, fh = FIXED_SIZES[self.kind]
            if (self.gb_w, self.gb_h) != (fw, fh):
                errs.append(f"{self.id}: {self.kind} must be {fw}x{fh}, "
                            f"is {self.gb_w}x{self.gb_h}")
            if self.resizable:
                errs.append(f"{self.id}: {self.kind} is not resizable")
        if self.kind == "hud_frame":
            variant = "enemy" if "enemy" in self.notes else \
                "player" if "player" in self.notes else None
            if variant is None:
                errs.append(f"{self.id}: hud_frame needs 'enemy' or 'player' "
                            "in notes")
            want_h = 2 if variant == "enemy" else 3
            if self.gb_w != HUD_FRAME_W or (variant and self.gb_h != want_h):
                errs.append(f"{self.id}: hud_frame({variant}) must be "
                            f"{HUD_FRAME_W}x{want_h}, is "
                            f"{self.gb_w}x{self.gb_h}")
            if self.resizable:
                errs.append(f"{self.id}: hud_frame is not resizable")
        from . import canvas as _c  # late import to avoid cycle in generator use
        p = _c.project(self)
        if p.col < 0 or p.row < 0 or p.col + self.gb_w > canvas["cols"] \
                or p.row + self.gb_h > canvas["rows"]:
            errs.append(f"{self.id}: projected box ({p.col},{p.row}) "
                        f"{self.gb_w}x{self.gb_h} leaves the {canvas['cols']}x"
                        f"{canvas['rows']} canvas")
        return errs


@dataclass
class Layout:
    subsystem: str
    canvas: dict = field(default_factory=lambda: {"cols": 40, "rows": 25, "tile_px": 8})
    gb_canvas: dict = field(default_factory=lambda: {"cols": 20, "rows": 18})
    frozen_at: str = ""             # commit hash once the layout is frozen
    elements: list[Element] = field(default_factory=list)

    def validate(self) -> list[str]:
        errs = []
        seen = set()
        for el in self.elements:
            if el.id in seen:
                errs.append(f"duplicate element id {el.id}")
            seen.add(el.id)
            errs.extend(el.validate(self.canvas, self.gb_canvas))
        # containment: an element whose notes carry "inside=<ID>" must stay
        # within that element's projected box (e.g. dialog lines in the box)
        import re
        from . import canvas as _c
        by_id = {el.id: el for el in self.elements}
        for el in self.elements:
            m = re.search(r"inside=(\w+)", el.notes)
            if not m:
                continue
            host = by_id.get(m.group(1))
            if host is None:
                errs.append(f"{el.id}: inside={m.group(1)} names no element")
                continue
            p, hp = _c.project(el), _c.project(host)
            # interior of a bordered host = host box minus its 1-tile frame
            inset = 1 if host.kind in ("textbox", "window", "sprite_popup") \
                else 0
            if p.col < hp.col + inset or p.row < hp.row + inset \
                    or p.col + el.gb_w > hp.col + host.gb_w - inset \
                    or p.row + el.gb_h > hp.row + host.gb_h - inset:
                errs.append(f"{el.id}: leaves the interior of {host.id}")
        return errs

    def by_id(self, eid: str) -> Element:
        for el in self.elements:
            if el.id == eid:
                return el
        raise KeyError(eid)


# ── stable (de)serialization — key order fixed for reviewable diffs ──────────

_EL_KEYS = ("id", "kind", "pret_id", "gb_x", "gb_y", "gb_w", "gb_h",
            "anchor_x", "anchor_y", "shift_x", "shift_y", "movable",
            "resizable", "min_w", "min_h", "text_label", "text_x", "text_y",
            "source", "pret_ref", "anchor_source", "notes")


def load(path: str | Path) -> Layout:
    raw = json.loads(Path(path).read_text())
    els = [Element(**{k: v for k, v in e.items() if k in _EL_KEYS})
           for e in raw["elements"]]
    lay = Layout(subsystem=raw["subsystem"], canvas=raw["canvas"],
                 gb_canvas=raw["gb_canvas"], frozen_at=raw.get("frozen_at", ""),
                 elements=els)
    errs = lay.validate()
    if errs:
        raise ValueError(f"{path}: " + "; ".join(errs))
    return lay


def save(lay: Layout, path: str | Path) -> None:
    errs = lay.validate()
    if errs:
        raise ValueError("; ".join(errs))
    out = {
        "subsystem": lay.subsystem,
        "canvas": lay.canvas,
        "gb_canvas": lay.gb_canvas,
        "frozen_at": lay.frozen_at,
        "elements": [
            {k: getattr(el, k) for k in _EL_KEYS if getattr(el, k) is not None}
            for el in lay.elements
        ],
    }
    Path(path).write_text(json.dumps(out, indent=2) + "\n")
