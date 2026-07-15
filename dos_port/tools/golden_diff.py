#!/usr/bin/env python3
"""golden_diff.py — diff a port GBSTATE.BIN against an mGBA golden (fidelity plan 1.4).

The golden (tests/goldens/<scenario>.bin + .json sidecar) is ground truth dumped
from the sha1-verified pokeyellow ROM by tools/mgba_harness. The port dump
(GBSTATE.BIN, written by src/debug/debug_dump.asm:DumpGBState) is SELF-DESCRIBING
as of v2: a 16-byte header + a region directory (name, GB address, size, file
offset) + the payloads. Neither side hardcodes an address here — the port table is
built from gb_memmap.inc equates, the golden's from pret's .sym, and this differ
reads both layouts and joins them BY REGION NAME. WRAM is a moving target, so
every shared region's GB address is cross-checked between the two sides: a memmap
drift fails loudly instead of silently comparing the wrong bytes.

Regions compared:
  wTileMap   — the port's 20x18 subwindow (per-scenario (col,row) offset in
               SCENARIOS below; the port pins the GB screen inside its 40x25
               canvas) vs the golden's wTileMap, cell by cell, glyphs decoded via
               assets/gb_charmap.txt in the report.
  vram_tiles — per 16-byte tile slot, so a clobbered slot is named directly
               (the $73/$74 HUD-clobber class).
  oam        — per 4-byte sprite entry.
  WRAM       — every other region, byte for byte, reported field-aware: a bad DV
               prints as "mon 3 DVs" and a bad slot as "bag slot 2 quantity",
               with names/species charmap-decoded (see the FIELDS tables).

Masks (per scenario, each with a written justification) suppress cells/slots
that legitimately diverge; anything else nonzero-exits. Policy: a mask owned by
an OPEN finding must carry the finding id in its why-string, so retiring the
finding greps to every mask that must be deleted. Current finding-owned masks:
F-13 (sign_pallet dialog-scratch/map-mirror overlap) and F-19 (battle
enemy-gauge clone tile ids/VRAM slots). Route-difference masks are not
finding-owned: e.g. status PikaPic, naming_screen ICON_GAP_SLOTS/vChars2 route
leftovers, and flower/water animation phase masks. They still need written
why-strings, but no finding id unless an OPEN finding owns the divergence.

Usage: golden_diff.py <scenario> --gbstate PATH [--goldens DIR] [--charmap PATH]
       golden_diff.py <scenario> --flags     (print the port make flags and exit)
"""

import argparse
import json
import struct
import sys
from pathlib import Path

PORT_CANVAS_W, PORT_CANVAS_H = 40, 25
GB_W, GB_H = 20, 18
HDR_SIZE = 16
DIRENT_SIZE = 32
NAME_LEN = 20
GBSTATE_VERSION = 2
PORT_TILEMAP_SIZE = PORT_CANVAS_W * PORT_CANVAS_H
VRAM_SIZE = 0x1800
OAM_SIZE = 160

# Regions handled by the dedicated video comparators; everything else in the
# dump is WRAM game data, compared byte-for-byte by compare_wram().
VIDEO_REGIONS = ("wTileMap", "vram_tiles", "oam")

# --- struct field maps: (offset, size, name) — used to name a diverging byte ---
# party_struct (pret macros/ram.asm:20), 44 B. Offset 7 is the catch rate, which
# Gen 2's Time Capsule reuses as the held item — see CLAUDE.md.
PARTYMON_FIELDS = [
    (0, 1, "species"), (1, 2, "HP"), (3, 1, "box level"), (4, 1, "status"),
    (5, 1, "type1"), (6, 1, "type2"), (7, 1, "catch rate (Gen-2 held item)"),
    (8, 1, "move 1"), (9, 1, "move 2"), (10, 1, "move 3"), (11, 1, "move 4"),
    (12, 2, "OT ID"), (14, 3, "EXP"),
    (17, 2, "HP stat exp"), (19, 2, "attack stat exp"), (21, 2, "defense stat exp"),
    (23, 2, "speed stat exp"), (25, 2, "special stat exp"),
    (27, 2, "DVs"),
    (29, 1, "PP 1"), (30, 1, "PP 2"), (31, 1, "PP 3"), (32, 1, "PP 4"),
    (33, 1, "level"), (34, 2, "max HP"), (36, 2, "attack"), (38, 2, "defense"),
    (40, 2, "speed"), (42, 2, "special"),
]
# battle_struct (pret macros/ram.asm:39), 29 B — no EXP/stat-exp, DVs move up.
BATTLEMON_FIELDS = [
    (0, 1, "species"), (1, 2, "HP"), (3, 1, "party pos"), (4, 1, "status"),
    (5, 1, "type1"), (6, 1, "type2"), (7, 1, "catch rate"),
    (8, 1, "move 1"), (9, 1, "move 2"), (10, 1, "move 3"), (11, 1, "move 4"),
    (12, 2, "DVs"), (14, 1, "level"),
    (15, 2, "max HP"), (17, 2, "attack"), (19, 2, "defense"), (21, 2, "speed"),
    (23, 2, "special"),
    (25, 1, "PP 1"), (26, 1, "PP 2"), (27, 1, "PP 3"), (28, 1, "PP 4"),
]
PARTYMON_LEN = 44
NAME_LENGTH = 11
PARTY_LENGTH = 6
BAG_ITEM_CAPACITY = 20

# Flat byte-index -> field-name maps for the fixed-layout blocks.
_OPTIONS_BLOCK = {0: "wOptions", 1: "wObtainedBadges", 2: "wUnusedObtainedBadges",
                  3: "wLetterPrintingDelayFlags"}
_BATTLE_FLAGS = {0: "wIsInBattle", 1: "wD057", 2: "wCurOpponent", 3: "wBattleType"}

# Charmap, for decoding names/glyphs in the report. Set from main().
_CHARMAP = {}

# Outside a battle, the battle-mon scratch regions hold whatever the last battle
# (or, on a fresh boot, nothing) left there — the golden's boot path and the
# port's SKIP_TITLE path do not converge on uninitialized scratch, and the game
# never reads it in this state. Battle scenarios drop this and compare them.
_NONBATTLE_WRAM_SKIP = {
    "wBattleFlags": "no battle: wIsInBattle/wCurOpponent/wBattleType are only meaningful "
                    "inside one; battle scenarios (Stage 2) compare them",
    "wEnemyMonNick": "no battle: enemy-mon scratch is uninitialized on both sides",
    "wEnemyMon": "no battle: enemy-mon scratch is uninitialized on both sides",
    "wBattleMonNick": "no battle: player-battle-mon scratch is uninitialized on both sides",
    "wBattleMon": "no battle: player-battle-mon scratch is uninitialized on both sides",
}

# Scenario CLASSES (fidelity plan Stage 1c). Default (no "class" key): compare
# everything — tilemap window, VRAM tile slots, OAM, WRAM. Class "datastruct":
# compare ONLY the WRAM regions; the three video comparators are skipped with the
# class-level justification below (reported like a mask, so the skip is visible
# in every run's output, never silent).
DATASTRUCT_CLASS_WHY = (
    "datastruct class: the dump point is a post-flow WRAM gate — the screen holds a "
    "transient message/menu frame whose exact tilemap/vram/oam state is timing-coupled "
    "(message scroll and blink phase at the dump frame); rendered-text fidelity is owned "
    "by the menu/dialog scenarios. What these scenarios pin is the WRAM game data the "
    "flow mutated."
)

# Per-scenario port config:
#   class  — optional scenario class (see above); "datastruct" skips
#            tilemap/vram/oam and needs no window
#   flags  — make variables that build the matching DEBUG_* image
#   window — (col,row) of the 20x18 GB screen inside the port's 40x25 canvas
#   stride — optional; the port's W_TILEMAP row stride for this scenario
#     (default 40, the canvas). Full-screen takeover screens (options menu,
#     trainer card, pokédex) draw W_TILEMAP as a GB-SHAPED stride-20 scratch
#     (the screen sets text_row_stride=20 and mirrors rows 0-17 to GB_TILEMAP1),
#     so golden cell (r,c) lives at flat offset r*20+c, NOT r*40+c. Such
#     scenarios use "stride": 20 with window (0,0). The stride applies to the
#     port cell computed from window+projections: flat = row*stride + col.
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

# Shared VRAM masks for the Stage 2 battle scenarios (measured, battle_intro
# first-diff 2026-07-14).
_BATTLE_VRAM_MASKS = [
    # Golden slots $00-$30 hold a second copy of the enemy front pic: the GB
    # battle screen uses $8000-addressing for BG ids $00-$7F, so pret loads the
    # pic to vFrontPic(=vSprites $8000) AND the engine's $9310 copy. The port's
    # flat-canvas battle render maps pic ids through its own bank scheme and
    # draws from the $9310 copy — which IS compared and matches (slots
    # $131-$161); its $8000-$8300 holds undisplayed overworld OBJ leftovers.
    # Render-HAL divergence: pic content fidelity is pinned by the tilemap ids
    # + the matching $93xx slots.
    *[(s, "pic bank placement: golden's $8000-addressing copy of the front pic; the port "
          "draws from the matching (compared) $9310 copy — port $80xx is undisplayed "
          "OBJ leftovers") for s in range(0x00, 0x31)],
    # F-19: the port clones the nine enemy-gauge patterns into vFont ids
    # $C0-$C8 for per-tile palette binding (ids the charmap never maps, so no
    # text can reference them); the golden holds the never-referenced Japanese
    # kana font tiles there. Retiring F-19's mechanism (per-cell palettes)
    # deletes this mask.
    *[(s, "F-19 enemy-gauge clone slots $C0-$C8: port palette-HAL clones vs golden's "
          "never-referenced kana glyphs") for s in range(0xC0, 0xC9)],
]

# Post-send-out variant (battle_menu / move_selection): the GB has by now used
# its whole $8000 bank — back pic reloaded over the ball tiles at $8310+, and
# the send-out POOF animation + slide buffers streamed through $8400-$87FF.
# The port's battle render never touches that bank after the intro (its BG
# draws from the $93xx copies, which ARE compared and match; OBJ is off), so
# the full bank is the pic/anim-bank placement divergence. The intro variant
# above keeps $31+ compared — that is where the port's ball OBJ tiles live and
# display.
_BATTLE_VRAM_MASKS_MENU = [
    *[(s, "GB battle anim/pic bank ($8000-$87FF) post-send-out: back pic + POOF/slide "
          "anim tiles on the golden; the port draws from the matching (compared) $93xx "
          "copies and its $80xx is undisplayed after the intro") for s in range(0x00, 0x80)],
    *[(s, "F-19 enemy-gauge clone slots $C0-$C8: port palette-HAL clones vs golden's "
          "never-referenced kana glyphs") for s in range(0xC0, 0xC9)],
]

# The enemy HP gauge's six segment cells carry the F-19 clone ids on the port
# ($C0-$C8 band) where the golden has the shared $62-$6B gauge ids. GB cells
# (row 2, cols 4-9). Retiring F-19 deletes this mask too.
_BATTLE_TILEMAP_MASKS_MENU = [
    ((2, 4, 2, 9), "F-19: enemy gauge segments use the port's palette-HAL clone tile ids; "
                   "the golden uses the shared $62-$6B gauge ids"),
]

# Shared WRAM masks for the Stage 2 battle scenarios.
_BATTLE_WRAM_MASKS = {
    "wOptionsBlock": [
        ((3, 3), "wLetterPrintingDelayFlags: sanctioned draw-layer divergence — the GB "
                 "keeps BIT_TEXT_DELAY set through the battle (TextCommandProcessor "
                 "gates the delay per message); the port's PlaceString calls "
                 "PrintLetterDelay unconditionally, so InitBattle keeps the bit OFF "
                 "except while a dialog message prints (init_battle.asm text-delay "
                 "config note)"),
    ],
}

SCENARIOS = {
    "status_p1": {
        "flags": "DEBUG_STATUS=1",
        "wram_skip": dict(_NONBATTLE_WRAM_SKIP),
        "window": (10, 3),
        "masks": _STATUS_MASKS,
    },
    "status_p2": {
        "flags": "DEBUG_STATUS=1 DEBUG_STATUS_PAGE2=1",
        "wram_skip": dict(_NONBATTLE_WRAM_SKIP),
        "window": (10, 3),
        "masks": _STATUS_MASKS,
    },
    "overworld_pallet": {
        "flags": "DEBUG_TRANSITION=1 DEBUG_BASELINE=1",
        "wram_skip": dict(_NONBATTLE_WRAM_SKIP),
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
    "sign_pallet": {
        "flags": "DEBUG_SIGNTEXT=1",
        "wram_skip": dict(_NONBATTLE_WRAM_SKIP),
        # Pallet Town, player at (9,8) facing LEFT, reading `bg_event 7, 9` — the tile
        # BELOW the sign is a flower ($03, not in Overworld_Coll), so this is the only
        # reachable reading tile (the port's gate seeds the same coords). The odd Y
        # puts the block-aligned mirror window two rows above overworld_pallet's.
        "window": (16, 8),
        "projections": [
            # The overworld dialog is drawn into a GB-SHAPED stride-20 scratch at
            # W_TILEMAP + 12*20 (msgbox_dialog, home/text.asm) and displayed through the
            # dialog window from GB_TILEMAP1. Laid over the 40-wide canvas, those 6
            # stride-20 rows re-flow into 3 canvas rows x 2 panels — the same shape
            # party_menu/bag_menu's message box takes.
            ((12 + k, 0, 12 + k, 19), (20 * (k % 2), (6 + k // 2) - (12 + k)),
             "stride-20 dialog scratch re-flowed over the 40-wide canvas: "
             "6 rows x 1 panel -> 3 rows x 2 panels")
            for k in range(6)
        ],
        "masks": {
            "tilemap": [
                ((0, 0, 0, 19),
                 "the stride-20 dialog scratch (W_TILEMAP+240..359) physically overlaps "
                 "canvas rows 6-8 of the block-aligned map mirror, and at this window "
                 "(row 8) canvas row 8 is golden row 0 — so the map mirror's top row is "
                 "sitting under the dialog's last two rows. Invisible on screen (render_bg "
                 "draws from the tile surface, the dialog from GB_TILEMAP1), but it IS a "
                 "staging-buffer collision: anything that reads the mirror back while a "
                 "dialog is open (SaveScreenTilesToBuffer) would read dialog bytes. "
                 "Fidelity plan F-13, M-29 family"),
            ],
            "vram": [
                (256 + 0x03, "flower tile: VRAM tile-DATA animation, phase depends on dump frame"),
                (256 + 0x14, "water tile: VRAM tile-DATA animation, phase depends on dump frame"),
            ] + [
                (128 + t, "stale font residue at the vChars1 tail (see overworld_pallet mask)")
                for t in range(0x78, 0x80)
            ],
            "oam": [
                (i, "NPC entries: the GIRL/FISHER wander state is RNG-path-dependent "
                    "(the golden's NPCs walked during its navigation to the sign) — it "
                    "cannot converge between emulator runs; player entries 0-3 are compared")
                for i in range(4, 40)
            ],
        },
    },
    "party_menu": {
        "flags": "DEBUG_PARTYMENU=1",
        "wram_skip": dict(_NONBATTLE_WRAM_SKIP),
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
        "wram_skip": dict(_NONBATTLE_WRAM_SKIP),
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
    # --- Stage 1c: item datastruct scenarios (class "datastruct" — WRAM only) ---
    # The port gates RunTMHMTest/RunStoneTest bypass the bag UI (they preset
    # wCurItem/wWhichPokemon and call UseItem directly); the goldens drive the
    # real START→ITEM→…→USE flow to the same post-flow WRAM state. DEBUG_ITEMUSE
    # drives the real UI on both sides (AUTOKEY_ITEMUSE script).
    "item_tm_teach": {
        "class": "datastruct",
        "flags": "DEBUG_ITEMTM=1",
        "wram_skip": dict(_NONBATTLE_WRAM_SKIP),
    },
    "item_stone_evolve": {
        "class": "datastruct",
        "flags": "DEBUG_ITEMSTONE=1",
        "wram_skip": dict(_NONBATTLE_WRAM_SKIP),
    },
    "item_potion_use": {
        # frame 700 = the gate's AUTOKEY_ITEMUSE script done (POTION heal +
        # ANTIDOTE refusal), bag list reopened — the WRAM state is settled there
        "class": "datastruct",
        "flags": "DEBUG_ITEMUSE=1 AUTOKEY_DUMP_FRAME=700",
        "wram_skip": dict(_NONBATTLE_WRAM_SKIP),
    },
    # --- Stage 2: battle scenarios. Window (10,3) = the uniform GB-centering of
    # (shared wram_masks defined above SCENARIOS: _BATTLE_WRAM_MASKS)
    # the widescreen battle canvas (docs/ui_projection.md, "Battle — GB-centered");
    # no per-element projections. Battle WRAM IS compared (no
    # _NONBATTLE_WRAM_SKIP): the enemy is the convergence-spec wild PIDGEY L13
    # (DVs $98 $76, real loaders on both sides — see seed.enemy /
    # DEBUG_BATTLE_GOLDEN). Masks are measured, per entry. ---
    "battle_intro": {
        "flags": "DEBUG_BATTLE_GOLDEN=1 DEBUG_BATTLE_INTRO=1",
        "window": (10, 3),
        "oam_window": True,  # battle canvas = fixed GB-centering; OBJ shift with it
        "masks": {"vram": list(_BATTLE_VRAM_MASKS)},
        "wram_masks": dict(_BATTLE_WRAM_MASKS),
    },
    "battle_menu": {
        # dump frame 300: well past the intro slide-in + send-out draws — the
        # screen is parked in HandleMenuInput long before (state, not timing)
        "flags": "DEBUG_BATTLE_GOLDEN=1 DEBUG_BATTLE_MENU=1 AUTOKEY_DUMP_FRAME=300",
        "window": (10, 3),
        "oam_window": True,
        "masks": {"vram": list(_BATTLE_VRAM_MASKS_MENU),
                  "tilemap": list(_BATTLE_TILEMAP_MASKS_MENU)},
        "wram_masks": dict(_BATTLE_WRAM_MASKS),
    },
    "move_selection": {
        "flags": "DEBUG_BATTLE_GOLDEN=1 DEBUG_MOVEMENU=1 AUTOKEY_DUMP_FRAME=300",
        "window": (10, 3),
        "oam_window": True,
        "masks": {"vram": list(_BATTLE_VRAM_MASKS_MENU),
                  "tilemap": list(_BATTLE_TILEMAP_MASKS_MENU)},
        "wram_masks": dict(_BATTLE_WRAM_MASKS),
    },
    "ball_catch": {
        # datastruct: the catch's WRAM outcome (party append, bag decrement,
        # dex bits, spec enemy still loaded). Both sides dump the instant
        # UseBagItem's post-capture tail sets wBattleResult=2 (golden polls it
        # per-frame; the port gate mirrors the tail then dumps).
        "class": "datastruct",
        "flags": "DEBUG_BATTLE_GOLDEN=1 DEBUG_ITEMBALL=1",
        "wram_masks": dict(_BATTLE_WRAM_MASKS),
    },
    # --- Stage 3: full-screen takeover menus. Both port screens draw W_TILEMAP
    # as a GB-shaped STRIDE-20 scratch (options.asm GBSCR_W / trainer_card.asm
    # TCSCR_W) and mirror rows 0-17 to GB_TILEMAP1, so the golden maps at
    # "stride": 20, window (0,0) — flat offset r*20+c, not the 40-wide canvas. ---
    "options_menu": {
        "flags": "DEBUG_OPTIONS=1",
        "wram_skip": dict(_NONBATTLE_WRAM_SKIP),
        "window": (0, 0),
        "stride": 20,
        # First diff (2026-07-14): 360/360 tilemap cells, OAM and WRAM clean;
        # the ONLY divergence was the flower-anim slot. Both sides keep the
        # outdoor tileset in vChars2 under the full-screen takeover; the two
        # animated tiles' phase is a function of each side's own dump frame
        # (the water slot happened to match this frame — same mask pair every
        # overworld-backdrop scenario carries).
        "masks": {
            "vram": [
                (256 + 0x03, "flower tile: VRAM tile-DATA animation, phase depends on dump frame"),
                (256 + 0x14, "water tile: VRAM tile-DATA animation, phase depends on dump frame"),
            ],
        },
    },
    "trainer_card": {
        "flags": "DEBUG_TRAINERCARD=1",
        "wram_skip": dict(_NONBATTLE_WRAM_SKIP),
        "window": (0, 0),
        "stride": 20,
        "masks": {
            "vram": [
                (256 + 0x03, "flower tile: VRAM tile-DATA animation, phase depends on dump frame"),
                (256 + 0x14, "water tile: VRAM tile-DATA animation, phase depends on dump frame"),
            ],
        },
    },
    "pokedex_list": {
        "flags": "DEBUG_G1=1",
        "wram_skip": dict(_NONBATTLE_WRAM_SKIP),
        "window": (0, 0),
        "stride": 20,
        "masks": {
            "vram": [
                (256 + 0x03, "flower tile: VRAM tile-DATA animation, phase depends on dump frame"),
                (256 + 0x14, "water tile: VRAM tile-DATA animation, phase depends on dump frame"),
            ],
        },
    },
    "pokedex_entry": {
        "flags": "DEBUG_G2=1",
        "wram_skip": dict(_NONBATTLE_WRAM_SKIP),
        "window": (0, 0),
        "stride": 20,
        "masks": {
            "vram": [
                (256 + 0x03, "flower tile: VRAM tile-DATA animation, phase depends on dump frame"),
                (256 + 0x14, "water tile: VRAM tile-DATA animation, phase depends on dump frame"),
            ],
        },
    },
    "naming_screen": {
        "flags": "DEBUG_NAMINGSCREEN=1",
        "wram_skip": dict(_NONBATTLE_WRAM_SKIP),
        "window": (0, 0),
        "stride": 20,
        # The two sides reach the same screen by different routes — the golden
        # inside the intro (NEW GAME → NEW NAME; the real screen only exists
        # there), the port gate from its overworld boot — so slots the screen
        # itself does not load hold different stale data by construction.
        # Everything the screen DOES load is compared and matches: the party-
        # sprite icon gfx (both sides run LoadMonPartySpriteGfx), the border/
        # HP-bar/ED tiles ($16x), and the font. Measured first diff 2026-07-15:
        # the diverging vChars0 slots were EXACTLY the ICON_GAP_SLOTS set.
        "masks": {
            "vram": (
                [(s, "vChars0 icon GAP slots (never written by the mon-icon loader): "
                     "port holds boot overworld OBJ leftovers, golden fresh-boot zeros; "
                     "OAM is hidden on both sides") for s in ICON_GAP_SLOTS]
                + [(s, "vChars2 $01-$5F undisplayed stale data: golden holds Oak-speech "
                       "remnants (intro route), port the boot overworld tileset; the "
                       "naming screen's displayed ids are $60+ (borders/ED) and $80+ "
                       "(font), all compared") for s in range(256 + 0x01, 256 + 0x60)]
            ),
        },
    },
    "start_menu": {
        "flags": "DEBUG_STARTMENU=1",
        "wram_skip": dict(_NONBATTLE_WRAM_SKIP),
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
    """Golden regions -> {name: {"addr", "size", "data"}} (layout from the sidecar)."""
    sidecar = json.loads((goldens_dir / f"{scenario}.json").read_text())
    blob = (goldens_dir / f"{scenario}.bin").read_bytes()
    if len(blob) != sidecar["total_size"]:
        sys.exit(f"golden {scenario}.bin is {len(blob)} B, sidecar says {sidecar['total_size']}")
    regions = {}
    for r in sidecar["regions"]:
        regions[r["name"]] = {
            "addr": int(r["gb_addr"], 16),
            "size": r["size"],
            "data": blob[r["file_offset"]:r["file_offset"] + r["size"]],
        }
    for name, size in (("wTileMap", GB_W * GB_H), ("vram_tiles", VRAM_SIZE), ("oam", OAM_SIZE)):
        if regions.get(name, {}).get("size") != size:
            sys.exit(f"golden {scenario}: region {name} missing or wrong size")
    return sidecar, regions


def load_gbstate(path):
    """Port regions -> {name: {"addr", "size", "data"}} (layout from the dump itself)."""
    blob = Path(path).read_bytes()
    if blob[:4] != b"GBST":
        sys.exit(f"{path}: bad magic {blob[:4]!r}")
    version, scenario_id, count, dir_size, total = struct.unpack_from("<BBHII", blob, 4)
    if version != GBSTATE_VERSION:
        sys.exit(f"{path}: GBSTATE version {version}, this differ speaks {GBSTATE_VERSION} "
                 f"(rebuild the port image — src/debug/debug_dump.asm)")
    if total != len(blob):
        sys.exit(f"{path}: header says {total} B, file is {len(blob)} B")
    if dir_size != count * DIRENT_SIZE:
        sys.exit(f"{path}: directory size {dir_size} != {count} x {DIRENT_SIZE}")

    regions = {}
    for i in range(count):
        raw = blob[HDR_SIZE + i * DIRENT_SIZE: HDR_SIZE + (i + 1) * DIRENT_SIZE]
        name = raw[:NAME_LEN].rstrip(b"\0").decode("ascii")
        addr, size, foff = struct.unpack_from("<III", raw, NAME_LEN)
        if foff + size > len(blob):
            sys.exit(f"{path}: region {name} runs past the end of the file")
        regions[name] = {"addr": addr, "size": size, "data": blob[foff:foff + size]}
    for name, size in (("wTileMap", PORT_TILEMAP_SIZE), ("vram_tiles", VRAM_SIZE),
                       ("oam", OAM_SIZE)):
        if regions.get(name, {}).get("size") != size:
            sys.exit(f"{path}: region {name} missing or wrong size")
    return {"scenario_id": scenario_id, "regions": regions}


def check_addresses(golden, port, scenario):
    """Both sides name their regions the same; assert they also AGREE ON THE ADDRESS.

    The port table is built from gb_memmap.inc, the golden's from pret's .sym. If a
    label moves on one side only, the bytes would still line up positionally and the
    diff would silently compare the wrong memory. Catch it here instead.
    """
    bad = []
    for name in sorted(set(golden) & set(port)):
        if name in VIDEO_REGIONS:
            continue  # wTileMap is deliberately a different size (canvas vs screen)
        g, p = golden[name], port[name]
        if g["addr"] != p["addr"] or g["size"] != p["size"]:
            bad.append(f"  {name}: golden ${g['addr']:04X}/{g['size']}B (pret .sym) != "
                       f"port ${p['addr']:04X}/{p['size']}B (gb_memmap.inc)")
    if bad:
        print(f"REGION LAYOUT MISMATCH ({scenario}) — the two sides disagree on where a region "
              f"lives, so the bytes are not comparable:")
        print("\n".join(bad))
        print("Fix the address/size in dos_port/src/debug/debug_dump.asm:gbstate_regions or "
              "tools/mgba_harness/lib/dump.lua:wram_regions, then regenerate the goldens.")
        sys.exit(2)


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


# ---------------------------------------------------------------------------
# Field-aware WRAM reporting
#
# A raw "byte 137 differs" is the kind of report that gets masked instead of
# fixed. Each decoder maps a region-relative byte offset to the field it belongs
# to, so a divergence reads "wPartyData mon 3 DVs: want $9876 got $A3C1" — the
# same language as pret's struct. Multi-byte fields collapse to one line (GB data
# is big-endian; see CLAUDE.md).
# ---------------------------------------------------------------------------
def _struct_field(fields, off):
    """(field_start, size, name) covering byte `off` of a mon struct, or None."""
    for f_off, f_size, f_name in fields:
        if f_off <= off < f_off + f_size:
            return f_off, f_size, f_name
    return None


def decode_name(data):
    """Charmap-decoded name, for the report ('@'-terminated GB string)."""
    out = []
    for b in data:
        if b == 0x50:  # '@' terminator
            break
        out.append(_CHARMAP.get(b, "?") if len(_CHARMAP.get(b, "")) == 1 else "?")
    return "".join(out)


def field_partydata(off):
    """wPartyData: count | species list | 6 party_structs | 6 OT names | 6 nicks."""
    if off == 0:
        return "wPartyCount", 0, 1
    species_len = 1 + PARTY_LENGTH  # 6 species + $FF sentinel
    if off < 1 + species_len:
        i = off - 1
        return (f"species list [{i}]" if i < PARTY_LENGTH else "species list terminator"), off, 1
    base = 1 + species_len
    structs_end = base + PARTY_LENGTH * PARTYMON_LEN
    if off < structs_end:
        mon, rel = divmod(off - base, PARTYMON_LEN)
        f = _struct_field(PARTYMON_FIELDS, rel)
        if f:
            f_off, f_size, f_name = f
            return f"mon {mon} {f_name}", base + mon * PARTYMON_LEN + f_off, f_size
        return f"mon {mon} +{rel}", off, 1
    ot_end = structs_end + PARTY_LENGTH * NAME_LENGTH
    if off < ot_end:
        mon = (off - structs_end) // NAME_LENGTH
        return f"mon {mon} OT name", structs_end + mon * NAME_LENGTH, NAME_LENGTH
    mon = (off - ot_end) // NAME_LENGTH
    return f"mon {mon} nickname", ot_end + mon * NAME_LENGTH, NAME_LENGTH


def field_battlemon(off):
    f = _struct_field(BATTLEMON_FIELDS, off)
    if f:
        f_off, f_size, f_name = f
        return f_name, f_off, f_size
    return f"+{off}", off, 1


def field_loadedmon(off):
    f = _struct_field(PARTYMON_FIELDS, off)
    if f:
        f_off, f_size, f_name = f
        return f_name, f_off, f_size
    return f"+{off}", off, 1


def field_bagitems(off):
    """wBagItems: count | 20 x (id, qty) | $FF terminator."""
    if off == 0:
        return "wNumBagItems", 0, 1
    i = off - 1
    if i >= BAG_ITEM_CAPACITY * 2:
        return "terminator", off, 1
    slot, which = divmod(i, 2)
    return f"slot {slot} {'item id' if which == 0 else 'quantity'}", off, 1


def field_pokedex(off):
    """wPokedex: owned flag array then seen flag array (bit n = dex #n+1)."""
    half = 19  # (NUM_POKEMON + 7) // 8
    which, byte_i = ("owned", off) if off < half else ("seen", off - half)
    lo, hi = byte_i * 8 + 1, byte_i * 8 + 8
    return f"{which} dex #{lo}-#{hi}", off, 1


def field_flat(table):
    def decode(off):
        return table.get(off, f"+{off}"), off, 1
    return decode


# region name -> (byte offset) -> (field name, field start, field size)
WRAM_DECODERS = {
    "wPartyData": field_partydata,
    "wLoadedMon": field_loadedmon,
    "wEnemyMon": field_battlemon,
    "wBattleMon": field_battlemon,
    "wBagItems": field_bagitems,
    "wPokedex": field_pokedex,
    "wOptionsBlock": field_flat(_OPTIONS_BLOCK),
    "wBattleFlags": field_flat(_BATTLE_FLAGS),
}
# Regions that are a single '@'-terminated name — report the decoded string.
NAME_REGIONS = ("wPlayerName", "wEnemyMonNick", "wBattleMonNick")


def value_str(data, start, size):
    """Big-endian field value, hex, with the decimal for small ints."""
    chunk = data[start:start + size]
    v = int.from_bytes(chunk, "big")
    if size == 1:
        return f"${v:02X}"
    if size <= 3:
        return f"${v:0{size * 2}X} ({v})"
    return chunk.hex()


def compare_wram(golden, port, cfg, max_report):
    """Diff every non-video region present on both sides. Returns (failures, masked)."""
    skips = cfg.get("wram_skip", {})
    masks = cfg.get("wram_masks", {})
    failures, masked_hits, lines = 0, [], []

    names = sorted((set(golden) | set(port)) - set(VIDEO_REGIONS))
    for name in names:
        if name in skips:
            masked_hits.append(f"wram {name} (whole region): {skips[name]}")
            continue
        if name not in golden or name not in port:
            side = "port" if name in port else "golden"
            lines.append(f"  {name}: present only on the {side} side — add it to the other "
                         f"region table, or give it a wram_skip justification")
            continue

        g, p = golden[name]["data"], port[name]["data"]
        region_masks = masks.get(name, [])
        decoder = WRAM_DECODERS.get(name)
        reported = set()  # field starts already reported (multi-byte -> one line)

        for off in range(len(g)):
            if g[off] == p[off]:
                continue
            why = next((w for (lo, hi), w in region_masks if lo <= off <= hi), None)
            if why:
                masked_hits.append(f"wram {name} +{off}: {why}")
                continue
            if name in NAME_REGIONS:
                if name in reported:
                    continue
                reported.add(name)
                lines.append(f"  {name}: want '{decode_name(g)}' | got '{decode_name(p)}'"
                             f"  ({g.hex()} | {p.hex()})")
                continue
            if decoder:
                field, start, size = decoder(off)
                if (name, start) in reported:
                    continue
                reported.add((name, start))
                want, got = value_str(g, start, size), value_str(p, start, size)
                extra = ""
                if "name" in field or "nickname" in field:
                    extra = f"  ('{decode_name(g[start:start + size])}' | "\
                            f"'{decode_name(p[start:start + size])}')"
                lines.append(f"  {name} {field}: want {want} | got {got}{extra}")
            else:
                lines.append(f"  {name} +{off}: want ${g[off]:02X} | got ${p[off]:02X}")

    if lines:
        failures = len(lines)
        print(f"WRAM: {len(lines)} mismatched fields:")
        for line in lines[:max_report]:
            print(line)
        if len(lines) > max_report:
            print(f"  ... and {len(lines) - max_report} more")
    else:
        compared = len(names) - len(skips)
        print(f"WRAM: OK ({compared} regions, {len(skips)} skipped)")
    return failures, masked_hits


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

    global _CHARMAP
    cmap = _CHARMAP = load_charmap(args.charmap)
    _, golden_regions = load_golden(Path(args.goldens), args.scenario)
    port_state = load_gbstate(args.gbstate)
    port_regions = port_state["regions"]
    check_addresses(golden_regions, port_regions, args.scenario)

    golden = {k: v["data"] for k, v in golden_regions.items()}
    port = {
        "tilemap": port_regions["wTileMap"]["data"],
        "vram": port_regions["vram_tiles"]["data"],
        "oam": port_regions["oam"]["data"],
    }

    failures = 0
    masked_hits = []

    if cfg.get("class") == "datastruct":
        # Class-level skip: the video comparators do not run at all. Reported
        # through the masked-divergence channel so the skip is loud in every run.
        print("TILEMAP: SKIPPED (datastruct class)")
        print("VRAM: SKIPPED (datastruct class)")
        print("OAM: SKIPPED (datastruct class)")
        masked_hits.append(f"tilemap/vram/oam (whole regions): {DATASTRUCT_CLASS_WHY}")
    else:
        # --- tilemap: 20x18 subwindow at (col,row), minus projected UI rects ---
        col0, row0 = cfg["window"]
        stride = cfg.get("stride", PORT_CANVAS_W)
        tm_masks = expand_tilemap_masks(cfg.get("masks", {}).get("tilemap", []))
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
                if not (0 <= pc < stride and pr >= 0
                        and pr * stride + pc < PORT_TILEMAP_SIZE):
                    if offcanvas_why:
                        masked_hits.append(f"tilemap ({r:2d},{c:2d}): {offcanvas_why}")
                        continue
                    tm_lines.append(f"  ({r:2d},{c:2d}) maps off-canvas to ({pr},{pc}) — no justification")
                    continue
                got = port["tilemap"][pr * stride + pc]
                if want == got:
                    continue
                if (r, c) in tm_masks:
                    masked_hits.append(f"tilemap ({r:2d},{c:2d}): {tm_masks[(r, c)]}")
                    continue
                tm_lines.append(
                    f"  ({r:2d},{c:2d}) want ${want:02X} {glyph(cmap, want):>4} | got ${got:02X} {glyph(cmap, got):>4}")
        if tm_lines:
            failures += len(tm_lines)
            print(f"TILEMAP: {len(tm_lines)} mismatched cells (of {GB_W * GB_H}), "
                  f"window at col {col0} row {row0}, stride {stride}:")
            for line in tm_lines[:args.max_report]:
                print(line)
            if len(tm_lines) > args.max_report:
                print(f"  ... and {len(tm_lines) - args.max_report} more")
        else:
            print(f"TILEMAP: OK (360 cells, window at col {col0} row {row0}, stride {stride})")

        # --- vram: per 16-byte tile slot ---
        vr_masks = dict(cfg.get("masks", {}).get("vram", []))
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

        # --- oam: per 4-byte sprite entry. Scenarios whose canvas is a FIXED
        # pixel projection of the GB screen (battle: the uniform GB-centering)
        # set "oam_window": True — a VISIBLE golden sprite is then compared at
        # its position + the window's pixel offset (8*col, 8*row). Overworld
        # scenarios must NOT set it: their tilemap window is block-grid
        # alignment, and the visible pixel offset lives in the Xoff/Yoff blit,
        # not in the OAM bytes. Hidden entries (Y == 0 / Y >= 160) compare
        # unshifted (parked positions are arbitrary; the both-hidden rule
        # absorbs them anyway). ---
        oam_masks = dict(cfg.get("masks", {}).get("oam", []))
        if cfg.get("oam_window"):
            oam_dx, oam_dy = col0 * 8, row0 * 8
        else:
            oam_dx = oam_dy = 0
        oam_lines = []
        def oam_hidden(e):
            return e[0] == 0 or e[0] >= 160  # sprite Y fully off the 144-line screen

        for i in range(OAM_SIZE // 4):
            want = golden["oam"][i * 4:(i + 1) * 4]
            if (oam_dx or oam_dy) and not oam_hidden(want):
                want = bytes(((want[0] + oam_dy) & 0xFF, (want[1] + oam_dx) & 0xFF,
                              want[2], want[3]))
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

    # --- wram: every non-video region, field-aware ---
    wram_failures, wram_masked = compare_wram(
        golden_regions, port_regions, cfg, args.max_report)
    failures += wram_failures
    masked_hits.extend(wram_masked)

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
