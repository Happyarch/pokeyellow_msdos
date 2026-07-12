#!/usr/bin/env python3
"""golden_diff.py — diff a port GBSTATE.BIN against an mGBA golden (fidelity plan 1.4).

The golden (tests/goldens/<scenario>.bin + .json sidecar) is ground truth dumped
from the sha1-verified pokeyellow ROM by tools/mgba_harness. The port dump
(GBSTATE.BIN, written by src/debug/debug_dump.asm:DumpGBState) has a fixed
layout: 16-byte header ("GBST", version, scenario id) + wTileMap 40x25 (1000 B,
stride 40) + VRAM 0x8000-0x97FF (6144 B) + OAM (160 B).

Regions compared:
  tilemap — the port's 20x18 subwindow (per-scenario (col,row) offset in
            SCENARIOS below; the port pins the GB screen inside its 40x25
            canvas) vs the golden's wTileMap, cell by cell, glyphs decoded via
            assets/gb_charmap.txt in the report.
  vram    — per 16-byte tile slot, so a clobbered slot is named directly
            (the $73/$74 HUD-clobber class).
  oam     — per 4-byte sprite entry.

Masks (per scenario, each with a written justification) suppress cells/slots
that legitimately diverge; anything else nonzero-exits.

Usage: golden_diff.py <scenario> --gbstate PATH [--goldens DIR] [--charmap PATH]
       golden_diff.py <scenario> --flags     (print the port make flags and exit)
"""

import argparse
import json
import re
import sys
from pathlib import Path

PORT_CANVAS_W, PORT_CANVAS_H = 40, 25
GB_W, GB_H = 20, 18
HDR_SIZE = 16
PORT_TILEMAP_SIZE = PORT_CANVAS_W * PORT_CANVAS_H
VRAM_SIZE = 0x1800
OAM_SIZE = 160
PORT_TOTAL = HDR_SIZE + PORT_TILEMAP_SIZE + VRAM_SIZE + OAM_SIZE

# Per-scenario port config:
#   flags  — make variables that build the matching DEBUG_* image
#   window — (col,row) of the 20x18 GB screen inside the port's 40x25 canvas
#   projections — optional list of ((row0,col0,row1,col1), (dcol,drow), why):
#     golden cells in the inclusive rect map to port canvas
#     (golden_col + dcol, golden_row + drow) instead of the window — the port
#     deliberately re-anchors some UI for the widescreen canvas
#     (docs/ui_projection.md); `why` names the projection.
#   offcanvas — justification string; golden cells whose mapped port cell
#     falls outside the 40x25 canvas count as masked with this reason
#     (without it, an off-canvas mapping is an error).
#   masks  — dict of region -> list of (spec, justification) entries:
#     tilemap: (row, col) cells or (row0, col0, row1, col1) inclusive rects
#     vram:    tile slot indices (0..383, slot n = 0x8000 + 16n)
#     oam:     sprite entry indices (0..39)
# OAM entries hidden on BOTH sides (Y == 0 or Y >= 160 — never on the 144-line
# screen) compare equal regardless of their stale X/tile/attr bytes.
# Shared mask set for the status screens (both pages keep the mon-pic area):
# FINDING (filed, Session E): for the starter Pikachu, Yellow's StatusScreen
# runs the PikaPic cartoon (engine/pikachu/pikachu_pic_animation.asm) instead
# of the static pic — it draws via direct BG-map writes that never touch
# wTileMap (the golden's pic cells read $7F), and streams cel gfx over
# vChars0. The port doesn't implement PikaPic; it draws the static flipped
# front pic (the non-starter path). Until PikaPic is ported, the whole pic
# area diverges by construction. Everything the motivating bugs lived in
# (text tiles, HUD/border tiles $60-$7F in vChars2 $9600+, stats digits, OAM)
# is still compared. The displayed 5x5 pic pattern data at $9000-$91FF
# matches the golden and IS compared.
_STATUS_MASKS = {
    "tilemap": [
        ((0, 1, 6, 7),
         "7x7 pic area: golden ran PikaPic (wTileMap left $7F); port draws the static pic IDs"),
    ],
    "vram": (
        [(s, "vChars0 sprite bank: golden holds PikaPic cel gfx, port holds sprite/pic scratch; "
              "OAM is empty on both sides so none of it is displayed") for s in range(0, 128)]
        + [(s, "vChars2 tiles $20-$5F: undisplayed stale data (golden: pre-status leftovers from "
               "the PikaPic run; port: 7x7 pic padding columns) — displayed golden IDs are all >= $60")
           for s in range(256 + 0x20, 256 + 0x60)]
    ),
}

# vChars0 tile slots that pret's MonPartySpritePointers (data/icon_pointers.asm) never
# writes: per animation frame (f = 0 and f = ICONOFFSET), the loader fills the icon
# bases below, leaving the unused ICON ids ($0B-$0D) and each 2-pattern icon's +1/+3
# tiles untouched. Used by the party_menu vram mask — see its justification there.
ICON_GAP_SLOTS = sorted(
    set(range(128))
    - {f + t for f in (0, 0x40) for t in
       list(range(0, 4)) + list(range(4, 12)) + list(range(12, 16))    # MON, BALL(+HELIX), FAIRY
       + list(range(16, 20)) + list(range(20, 24))                     # BIRD, WATER
       + [24, 26, 28, 30, 32, 34, 36, 38]                              # BUG, GRASS, SNAKE, QUADRUPED
       + list(range(40, 44)) + list(range(56, 60))}                    # PIKACHU, TRADEBUBBLE
)

SCENARIOS = {
    "status_p1": {
        "flags": "DEBUG_STATUS=1",
        "window": (10, 3),
        "masks": _STATUS_MASKS,
    },
    "status_p2": {
        "flags": "DEBUG_STATUS=1 DEBUG_STATUS_PAGE2=1",
        "window": (10, 3),
        "masks": _STATUS_MASKS,
    },
    "overworld_pallet": {
        "flags": "DEBUG_TRANSITION=1 DEBUG_BASELINE=1",
        # Same (8,8) Pallet spawn as start_menu -> same block-aligned mirror
        # window; golden rows 15-17 fall past the 25-row canvas.
        "window": (16, 10),
        "offcanvas": "block-aligned mirror window at (16,10): golden rows 15-17 map past the "
                     "25-row canvas",
        "masks": {
            "vram": [
                (256 + 0x03, "flower tile: VRAM tile-DATA animation, phase depends on dump frame"),
                (256 + 0x14, "water tile: VRAM tile-DATA animation, phase depends on dump frame"),
            ] + [
                (128 + t, "stale font residue: GB's real boot (intro/Oak speech) left the font in "
                          "vChars1 and map-entry sprite loads cover only $8800-$8F7F, so digits 2-9 "
                          "survive at the tail; the port's SKIP_TITLE boot has zeroed VRAM. No "
                          "displayed tile references $F8-$FF on this screen")
                for t in range(0x78, 0x80)
            ],
            "oam": [
                (i, "NPC entries: wander state is RNG-path-dependent (golden NPCs walked during "
                    "the scenario's navigation) — positions/frames cannot converge between "
                    "emulator runs; player entries 0-3 are compared and match")
                for i in range(4, 40)
            ],
        },
    },
    "party_menu": {
        "flags": "DEBUG_PARTYMENU=1",
        # The widescreen port re-lays the party list out (measured, byte-verified):
        # GB's two rows per mon (name / HP-bar) become one canvas row — name in
        # the left panel (cols 0-19), HP bar in the right (cols 20-39) — and the
        # 6-row message box re-flows into 3 rows x 2 panels.
        "window": (0, 0),  # every golden cell is covered by a projection rect
        "projections": (
            [((2 * i, 0, 2 * i, 19), (0, i - 2 * i),
              "widescreen party layout: name row 2i -> canvas row i, left panel") for i in range(6)]
            + [((2 * i + 1, 0, 2 * i + 1, 19), (20, i - (2 * i + 1)),
                "widescreen party layout: HP row 2i+1 -> canvas row i, right panel") for i in range(6)]
            + [((12 + k, 0, 12 + k, 19), (20 * (k % 2), (6 + k // 2) - (12 + k)),
                "message box re-flowed 6 rows x 1 panel -> 3 rows x 2 panels") for k in range(6)]
        ),
        # The three icon masks (tilemap cells, all 40 OAM entries, and vChars0 wholesale)
        # were retired with the BG-tile icon hack: the port now renders the icons the way
        # the GB does, through pret's engine/gfx/mon_icons.asm, so the tilemap cells are
        # blank, OAM is compared entry for entry, and every vChars0 slot the icon loader
        # writes matches the golden byte-for-byte (docs/plans/party_icons_oam.md).
        # What is left is ICON_GAP_SLOTS below.
        "masks": {
            "vram": (
                [(s, "vChars0 slot the icon loader never writes: an unused ICON id ($0B-$0D, "
                     "const_skip 3) or the +1/+3 gap of a 2-pattern icon (the symmetric writer "
                     "displays only base and base+2 — the right column is the left one X-flipped). "
                     "No OAM entry references these; the golden holds zeros because its scenario "
                     "never loaded map-sprite tiles into vSprites, while the port still has the "
                     "overworld's there under the menu. Every slot the loader DOES write matches "
                     "the golden exactly.") for s in ICON_GAP_SLOTS]
                + [(s, "vChars2 $00-$5F: the golden screen displays no tile ID below $62 here "
                       "(stale pre-menu data); the port keeps the live overworld tileset for "
                       "the widescreen backdrop rows outside the golden's 20x18 screen")
                   for s in range(256, 352)]
            ),
        },
    },
    "bag_menu": {
        "flags": "DEBUG_BAGMENU=1",
        # Overworld backdrop: same (8,8) spawn -> block-aligned mirror window
        # (16,10). ITEM box: GB's 2-rows-per-item list (name row / x-qty row,
        # box at golden rows 2-12 cols 4-19) re-flows into the widescreen
        # port's two panels — names left (canvas rows 0-5 cols 0-15), qty
        # right (cols 20-35). Measured/byte-verified like party_menu.
        "window": (16, 10),
        "projections": (
            # left panel: top border r2, name rows r4/6/8/10, bottom border r12
            [((r, 4, r, 19), (-4, dst - r), "widescreen bag layout: name rows -> left panel")
             for r, dst in ((2, 0), (4, 1), (6, 2), (8, 3), (10, 4), (12, 5))]
            # right panel: blank r3, qty rows r5/7/9, key-item blank r11
            + [((r, 4, r, 19), (16, dst - r), "widescreen bag layout: qty rows -> right panel")
               for r, dst in ((3, 0), (5, 1), (7, 2), (9, 3), (11, 4))]
        ),
        "offcanvas": "block-aligned mirror window at (16,10): golden rows 15-17 map past the "
                     "25-row canvas; pure overworld backdrop",
        "masks": {
            "tilemap": [
                ((0, 10, 1, 19),
                 "GB keeps the START menu box visible beside the ITEM list; the widescreen "
                 "port's panel redraw replaces it with the live overworld backdrop"),
                ((13, 10, 13, 19),
                 "GB keeps the START menu box visible beside the ITEM list; the widescreen "
                 "port's panel redraw replaces it with the live overworld backdrop"),
                ((11, 18),
                 "MORE-list arrow: blinking, phase depends on dump frame (golden caught "
                 "blink-off; the port draws it steady)"),
            ],
            "vram": [
                (256 + 0x03, "flower tile: VRAM tile-DATA animation, phase depends on dump frame"),
                (256 + 0x14, "water tile: VRAM tile-DATA animation, phase depends on dump frame"),
            ] + [
                (128 + t, "stale font residue at the vChars1 tail (see overworld_pallet mask)")
                for t in range(0x78, 0x80)
            ],
            "oam": [
                (i, "GB hides the player sprite under the centered ITEM box "
                    "(CheckSpriteAvailability) and its remaining visible entry is one "
                    "RNG-wandered NPC; the widescreen port re-anchors the box away from the "
                    "player, who stays visible at the canonical (76,72) — layouts do not share "
                    "a comparable OAM state (player-vs-golden checked in overworld_pallet)")
                for i in range(0, 40)
            ],
        },
    },
    "start_menu": {
        "flags": "DEBUG_STARTMENU=1",
        # Overworld portion: W_TILEMAP is the port's block-aligned map mirror;
        # at the (8,8) Pallet spawn its 20x18 GB window sits at (16,10)
        # (measured; block-grid alignment, not the pixel camera — the visible
        # screen compensates with the Xoff/Yoff pixel blit).
        "window": (16, 10),
        "projections": [
            # START menu box: the widescreen port anchors it top-right,
            # gb (row, col 10..19) -> canvas (row, col+20). docs/ui_projection.md
            # "overworld-ui (START menu)": X+20, Y+0.
            ((0, 10, 13, 19), (20, 0), "START menu box projected X+20 (ui_projection.md)"),
        ],
        "offcanvas": "block-aligned mirror window at (16,10): golden rows 15-17 map past the "
                     "25-row canvas; pure overworld backdrop (no menu content), covered by the "
                     "overworld_pallet scenario",
        "masks": {
            "vram": [
                (256 + 0x03, "flower tile: VRAM tile-DATA animation, phase depends on dump frame "
                             "(Session C differ note)"),
                (256 + 0x14, "water tile: VRAM tile-DATA animation, phase depends on dump frame "
                             "(Session C differ note)"),
            ],
        },
    },
}


def load_charmap(path):
    cmap = {}
    for line in Path(path).read_text(encoding="utf-8").splitlines():
        if ";" not in line:
            continue
        glyph, _, hexval = line.rpartition(";")
        try:
            code = int(hexval, 16)
        except ValueError:
            continue
        if code not in cmap:
            cmap[code] = glyph
    return cmap


def glyph(cmap, tid):
    g = cmap.get(tid, "")
    return f"'{g}'" if len(g) == 1 else "---"


def load_golden(goldens_dir, scenario):
    sidecar = json.loads((goldens_dir / f"{scenario}.json").read_text())
    blob = (goldens_dir / f"{scenario}.bin").read_bytes()
    if len(blob) != sidecar["total_size"]:
        sys.exit(f"golden {scenario}.bin is {len(blob)} B, sidecar says {sidecar['total_size']}")
    regions = {}
    for r in sidecar["regions"]:
        regions[r["name"]] = blob[r["file_offset"]:r["file_offset"] + r["size"]]
    for name, size in (("wTileMap", GB_W * GB_H), ("vram_tiles", VRAM_SIZE), ("oam", OAM_SIZE)):
        if len(regions.get(name, b"")) != size:
            sys.exit(f"golden {scenario}: region {name} missing or wrong size")
    return sidecar, regions


def load_gbstate(path):
    blob = Path(path).read_bytes()
    if len(blob) != PORT_TOTAL:
        sys.exit(f"{path}: {len(blob)} B, expected {PORT_TOTAL} (GBSTATE.BIN layout)")
    if blob[:4] != b"GBST":
        sys.exit(f"{path}: bad magic {blob[:4]!r}")
    if blob[4] != 1:
        sys.exit(f"{path}: unsupported GBSTATE version {blob[4]}")
    off = HDR_SIZE
    tilemap = blob[off:off + PORT_TILEMAP_SIZE]; off += PORT_TILEMAP_SIZE
    vram = blob[off:off + VRAM_SIZE]; off += VRAM_SIZE
    oam = blob[off:off + OAM_SIZE]
    return {"scenario_id": blob[5], "tilemap": tilemap, "vram": vram, "oam": oam}


def expand_tilemap_masks(entries):
    cells = {}
    for spec, why in entries:
        if len(spec) == 2:
            cells[(spec[0], spec[1])] = why
        else:
            r0, c0, r1, c1 = spec
            for r in range(r0, r1 + 1):
                for c in range(c0, c1 + 1):
                    cells[(r, c)] = why
    return cells


def vchars_name(slot):
    if slot < 128:
        return f"vChars0 tile ${slot:02X}"
    if slot < 256:
        return f"vChars1 tile ${slot - 128:02X}"
    return f"vChars2 tile ${slot - 256:02X}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("scenario", choices=sorted(SCENARIOS))
    ap.add_argument("--gbstate")
    ap.add_argument("--goldens", default=str(Path(__file__).resolve().parent.parent / "tests/goldens"))
    ap.add_argument("--charmap", default=str(Path(__file__).resolve().parent.parent / "assets/gb_charmap.txt"))
    ap.add_argument("--flags", action="store_true", help="print the make flags for this scenario and exit")
    ap.add_argument("--max-report", type=int, default=40, help="max mismatch lines per region")
    args = ap.parse_args()

    cfg = SCENARIOS[args.scenario]
    if args.flags:
        print(cfg["flags"])
        return

    if not args.gbstate:
        ap.error("--gbstate is required (path to the extracted GBSTATE.BIN)")

    cmap = load_charmap(args.charmap)
    _, golden = load_golden(Path(args.goldens), args.scenario)
    port = load_gbstate(args.gbstate)

    failures = 0
    masked_hits = []

    # --- tilemap: 20x18 subwindow at (col,row), minus projected UI rects ---
    col0, row0 = cfg["window"]
    tm_masks = expand_tilemap_masks(cfg["masks"].get("tilemap", []))
    projections = cfg.get("projections", [])
    offcanvas_why = cfg.get("offcanvas")
    tm_lines = []
    for r in range(GB_H):
        for c in range(GB_W):
            pc, pr = col0 + c, row0 + r
            for (r0, c0, r1, c1), (dcol, drow), _why in projections:
                if r0 <= r <= r1 and c0 <= c <= c1:
                    pc, pr = c + dcol, r + drow
                    break
            want = golden["wTileMap"][r * GB_W + c]
            if not (0 <= pc < PORT_CANVAS_W and 0 <= pr < PORT_CANVAS_H):
                if offcanvas_why:
                    masked_hits.append(f"tilemap ({r:2d},{c:2d}): {offcanvas_why}")
                    continue
                tm_lines.append(f"  ({r:2d},{c:2d}) maps off-canvas to ({pr},{pc}) — no justification")
                continue
            got = port["tilemap"][pr * PORT_CANVAS_W + pc]
            if want == got:
                continue
            if (r, c) in tm_masks:
                masked_hits.append(f"tilemap ({r:2d},{c:2d}): {tm_masks[(r, c)]}")
                continue
            tm_lines.append(
                f"  ({r:2d},{c:2d}) want ${want:02X} {glyph(cmap, want):>4} | got ${got:02X} {glyph(cmap, got):>4}")
    if tm_lines:
        failures += len(tm_lines)
        print(f"TILEMAP: {len(tm_lines)} mismatched cells (of {GB_W * GB_H}), window at col {col0} row {row0}:")
        for line in tm_lines[:args.max_report]:
            print(line)
        if len(tm_lines) > args.max_report:
            print(f"  ... and {len(tm_lines) - args.max_report} more")
    else:
        print(f"TILEMAP: OK (360 cells, window at col {col0} row {row0})")

    # --- vram: per 16-byte tile slot ---
    vr_masks = dict(cfg["masks"].get("vram", []))
    vr_lines = []
    for slot in range(VRAM_SIZE // 16):
        want = golden["vram_tiles"][slot * 16:(slot + 1) * 16]
        got = port["vram"][slot * 16:(slot + 1) * 16]
        if want == got:
            continue
        if slot in vr_masks:
            masked_hits.append(f"vram slot {slot}: {vr_masks[slot]}")
            continue
        vr_lines.append(
            f"  slot {slot:3d} (${0x8000 + slot * 16:04X}, {vchars_name(slot)}):"
            f" want {want.hex()} | got {got.hex()}")
    if vr_lines:
        failures += len(vr_lines)
        print(f"VRAM: {len(vr_lines)} mismatched tile slots (of 384):")
        for line in vr_lines[:args.max_report]:
            print(line)
        if len(vr_lines) > args.max_report:
            print(f"  ... and {len(vr_lines) - args.max_report} more")
    else:
        print("VRAM: OK (384 tile slots)")

    # --- oam: per 4-byte sprite entry ---
    oam_masks = dict(cfg["masks"].get("oam", []))
    oam_lines = []
    def oam_hidden(e):
        return e[0] == 0 or e[0] >= 160  # sprite Y fully off the 144-line screen

    for i in range(OAM_SIZE // 4):
        want = golden["oam"][i * 4:(i + 1) * 4]
        got = port["oam"][i * 4:(i + 1) * 4]
        if want == got:
            continue
        if oam_hidden(want) and oam_hidden(got):
            continue  # both invisible; stale X/tile/attr bytes are meaningless
        if i in oam_masks:
            masked_hits.append(f"oam entry {i}: {oam_masks[i]}")
            continue
        oam_lines.append(f"  entry {i:2d}: want Y={want[0]} X={want[1]} tile=${want[2]:02X} attr=${want[3]:02X}"
                         f" | got Y={got[0]} X={got[1]} tile=${got[2]:02X} attr=${got[3]:02X}")
    if oam_lines:
        failures += len(oam_lines)
        print(f"OAM: {len(oam_lines)} mismatched sprite entries (of 40):")
        for line in oam_lines[:args.max_report]:
            print(line)
    else:
        print("OAM: OK (40 entries)")

    if masked_hits:
        print(f"masked (justified) divergences hit: {len(masked_hits)}")
        by_why = {}
        for m in masked_hits:
            where, _, why = m.partition(": ")
            by_why.setdefault(why, []).append(where)
        for why, wheres in by_why.items():
            print(f"  [{len(wheres)}x] {wheres[0]} .. {wheres[-1]}: {why}")

    if failures:
        print(f"FAIL {args.scenario}: {failures} unmasked divergences")
        sys.exit(1)
    print(f"PASS {args.scenario}")


if __name__ == "__main__":
    main()
