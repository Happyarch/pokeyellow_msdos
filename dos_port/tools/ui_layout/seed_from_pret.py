#!/usr/bin/env python3
"""seed_from_pret.py — one-shot seeder for a subsystem layout sidecar.

Sources of truth:
  1. pret data/text_boxes.asm — TextBoxCoordTable (id,x1,y1,x2,y2) and
     TextBoxTextAndCoordTable (+ text ptr/x/y). JP_* templates are omitted
     (DEVIATION: JP-only, not shipped in the EN port).
  2. pret constants/menu_constants.asm — numeric textbox ID values.
  3. The port's already-placed `; PROJ` geometry (docs/ui_projection.md index)
     — seeded as elements with the SAME anchors so the new pipeline reproduces
     today's on-screen positions bit-for-bit (asserted below).

Anchors are inferences from pret developer intent (anchor_source="inferred");
confirm/adjust them in the editor.

Run from repo root:  python3 dos_port/tools/ui_layout/seed_from_pret.py
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from ui_layout import canvas as cv                     # noqa: E402
from ui_layout.schema import Element, Layout, save     # noqa: E402

ROOT = Path(__file__).resolve().parent.parent.parent.parent
PRET_TEXT_BOXES = ROOT / "data" / "text_boxes.asm"
PRET_CONSTANTS = ROOT / "constants" / "menu_constants.asm"
OUT = ROOT / "dos_port" / "assets" / "ui_layout_menus_sidecar.json"


def parse_textbox_ids() -> dict[str, int]:
    """Walk the `const_def 1` block in menu_constants.asm."""
    ids, val, active = {}, None, False
    for line in PRET_CONSTANTS.read_text().splitlines():
        line = line.split(";")[0].strip()
        if line.startswith("const_def"):
            if active:
                break  # only the first block (text box IDs)
            m = re.match(r"const_def\s+(\d+)", line)
            val, active = int(m.group(1)) if m else 0, True
        elif active and line.startswith("const_skip"):
            val += 1
        elif active and line.startswith("const_next"):
            val = int(line.split()[1].replace("$", "0x"), 0)
        elif active and line.startswith("const "):
            ids[line.split()[1]] = val
            val += 1
        elif active and line == "":
            continue
        elif active and not line.startswith("const"):
            break
    return ids


def parse_coord_tables() -> tuple[list, list]:
    """-> ([(name,x1,y1,x2,y2)], [(name,x1,y1,x2,y2,label,tx,ty)])."""
    text = PRET_TEXT_BOXES.read_text()
    coords, textcoords = [], []
    in_coord = in_text = False
    for line in text.splitlines():
        s = line.strip()
        if s.startswith("TextBoxCoordTable:"):
            in_coord, in_text = True, False
            continue
        if s.startswith("TextBoxTextAndCoordTable:"):
            in_coord, in_text = False, True
            continue
        if in_coord:
            m = re.match(r"db\s+(\w+),\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+)", s)
            if m:
                coords.append((m.group(1), *(int(m.group(i)) for i in range(2, 6))))
            elif s.startswith("db -1"):
                in_coord = False
        if in_text:
            m = re.match(r"text_box_text\s+(\w+),\s*(\d+),\s*(\d+),\s*(\d+),"
                         r"\s*(\d+),\s*(\w+),\s*(\d+),\s*(\d+)", s)
            if m:
                textcoords.append((m.group(1),
                                   *(int(m.group(i)) for i in range(2, 6)),
                                   m.group(6), int(m.group(7)), int(m.group(8))))
            elif s and not s.startswith(("text_box_text", ";")):
                in_text = False
    return coords, textcoords


# Anchor inferences per pret intent (docs/ui_projection.md process rule).
# Verified rows reproduce the port's live geometry — asserted in EXPECTED.
ANCHORS = {
    "MESSAGE_BOX":                     ("center", "bottom"),
    "MENU_TEMPLATE_03":                ("center", "top"),
    "MENU_TEMPLATE_07":                ("left", "top"),
    "LIST_MENU_BOX":                   ("right", "top"),
    "MENU_TEMPLATE_10":                ("right", "top"),
    "MON_SPRITE_POPUP":                ("center", "center"),
    "USE_TOSS_MENU_TEMPLATE":          ("right", "top"),
    "BATTLE_MENU_TEMPLATE":            ("custom", "custom"),   # battle +10/+3
    "SAFARI_BATTLE_MENU_TEMPLATE":     ("custom", "custom"),
    "SWITCH_STATS_CANCEL_MENU_TEMPLATE": ("right", "bottom"),
    "BUY_SELL_QUIT_MENU_TEMPLATE":     ("left", "top"),
    "MONEY_BOX_TEMPLATE":              ("right", "top"),
}
BATTLE_SHIFT = (10, 3)   # uniform battle-subsystem transform

# Preview labels: charmap-single-char approximations of the pret strings
# (<PK><MN> glyphs dropped — preview only; real strings come from generators).
LABELS = {
    "USE_TOSS_MENU_TEMPLATE": "USE\nTOSS",
    "BATTLE_MENU_TEMPLATE": "FIGHT\nITEM  RUN",
    "SAFARI_BATTLE_MENU_TEMPLATE": "BALL      BAIT\nTHROW ROCK  RUN",
    "SWITCH_STATS_CANCEL_MENU_TEMPLATE": "SWITCH\nSTATS\nCANCEL",
    "BUY_SELL_QUIT_MENU_TEMPLATE": "BUY\nSELL\nQUIT",
    "MONEY_BOX_TEMPLATE": "MONEY",
}

# Port-only elements (no pret textbox ID) — geometry/anchors lifted verbatim
# from the live `; PROJ` tags (docs/ui_projection.md index table).
PORT_ELEMENTS = [
    # id, kind, gb(x,y,w,h), anchor, resizable, source-site, notes
    ("START_MENU", "textbox", (10, 0, 10, 16), ("right", "top"), True,
     "start_menu.asm (.draw_full)",
     "height dynamic in-game (2*items+2 rows); w/h here = max footprint"),
    ("PARTY_PANEL", "window", (0, 0, 20, 18), ("center", "top"), False,
     "party_menu.asm",
     "full-GB-screen panel; rows drawn per party count"),
    ("YES_NO_MENU", "textbox", (14, 7, 6, 5), ("right", "top"), True,
     "yes_no.asm (YesNoChoice) + bag_menu.asm (YESNO_*)", ""),
    ("WIDE_YES_NO_MENU", "textbox", (12, 7, 8, 5), ("right", "top"), True,
     "yes_no.asm (WideYesNoChoice)", ""),
    ("HEAL_CANCEL_MENU", "textbox", (11, 6, 9, 6), ("right", "top"), True,
     "yes_no.asm (YesNoChoicePokeCenter)", ""),
    ("QTY_BOX", "textbox", (15, 9, 5, 3), ("right", "top"), True,
     "list_menu.asm (DisplayChooseQuantityMenu) + bag_menu.asm (QTY_*)", ""),
    ("FIELD_MOVE_MON_MENU", "textbox", (11, 11, 9, 7), ("right", "bottom"), True,
     "text_box.asm (DisplayFieldMoveMonMenu)",
     "pret computes width from wFieldMovesLeftmostXCoord; this is the widest case"),
]

# The port's CURRENT live geometry — the seeded projection must reproduce these
# exactly or the new pipeline would silently move working UI. (wx, wy, clip, max_y)
EXPECTED = {
    "MESSAGE_BOX": (87, 152, 160, 200),
    "LIST_MENU_BOX": (199, 16, 128, 104),
    "USE_TOSS_MENU_TEMPLATE": (271, 80, 56, 120),
    "YES_NO_MENU": (279, 56, 48, 96),
    "WIDE_YES_NO_MENU": (263, 56, 64, 96),
    "HEAL_CANCEL_MENU": (255, 48, 72, 96),
    "QTY_BOX": (287, 72, 40, 96),
    "START_MENU": (247, 0, 80, None),    # max_y dynamic (rows*8)
    "PARTY_PANEL": (87, 0, 160, None),
}


def main() -> None:
    ids = parse_textbox_ids()
    coords, textcoords = parse_coord_tables()
    els: list[Element] = []

    def add_pret(name, x1, y1, x2, y2, label=None, tx=None, ty=None, line=""):
        if name.startswith("JP_"):
            return  # DEVIATION: JP-only templates omitted from the EN port
        ax, ay = ANCHORS[name]
        sx, sy = (BATTLE_SHIFT if ax == "custom" else (None, None))
        els.append(Element(
            id=name, kind="sprite_popup" if name == "MON_SPRITE_POPUP" else "textbox",
            pret_id=ids[name],
            gb_x=x1, gb_y=y1, gb_w=x2 - x1 + 1, gb_h=y2 - y1 + 1,
            anchor_x=ax, anchor_y=ay, shift_x=sx, shift_y=sy,
            movable=True, resizable=True,
            text_label=LABELS.get(name), text_x=tx, text_y=ty,
            source=line, pret_ref="data/text_boxes.asm",
        ))

    for name, x1, y1, x2, y2 in coords:
        add_pret(name, x1, y1, x2, y2, line="TextBoxCoordTable")
    for name, x1, y1, x2, y2, _ptr, tx, ty in textcoords:
        add_pret(name, x1, y1, x2, y2, tx=tx, ty=ty,
                 line="TextBoxTextAndCoordTable")

    # FIELD_MOVE_MON_MENU is a FunctionTable entry (dynamic box) + the port-only
    # PROJ elements.
    for eid, kind, (x, y, w, h), (ax, ay), rz, site, notes in PORT_ELEMENTS:
        els.append(Element(
            id=eid, kind=kind, pret_id=ids.get(eid),
            gb_x=x, gb_y=y, gb_w=w, gb_h=h,
            anchor_x=ax, anchor_y=ay, movable=True, resizable=rz,
            source=f"; PROJ {site}", pret_ref="docs/ui_projection.md",
            notes=notes,
        ))

    lay = Layout(subsystem="menus", elements=els)
    errs = lay.validate()
    if errs:
        sys.exit("validation: " + "; ".join(errs))

    # ── assert the pipeline reproduces the live port geometry ────────────────
    bad = []
    for eid, (wx, wy, clip, maxy) in EXPECTED.items():
        p = cv.project(lay.by_id(eid))
        got = (p.wx, p.wy, p.clip, p.max_y if maxy is not None else None)
        if got != (wx, wy, clip, maxy):
            bad.append(f"{eid}: expected wx={wx} wy={wy} clip={clip} "
                       f"max_y={maxy}, got wx={p.wx} wy={p.wy} clip={p.clip} "
                       f"max_y={p.max_y}")
    if bad:
        sys.exit("LEGACY GEOMETRY MISMATCH — refusing to seed:\n  "
                 + "\n  ".join(bad))

    save(lay, OUT)
    print(f"seeded {len(els)} elements -> {OUT}")
    for el in els:
        print(" ", cv.proj_tag("menus", el))


if __name__ == "__main__":
    main()
