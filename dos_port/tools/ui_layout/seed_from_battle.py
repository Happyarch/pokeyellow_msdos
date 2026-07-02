#!/usr/bin/env python3
"""seed_from_battle.py — one-shot seeder for the battle layout sidecar.

Builds assets/ui_layout_battle_sidecar.json from the CURRENT hardcoded battle
geometry (the `%define`s in src/engine/battle/{battle_hud,core,battle_menu,
init_battle}.asm, src/gfx/pics.asm and pokeballs.asm — see the pret refs per
element), every element on the uniform battle transform anchor=custom
shift=(+10,+3) (docs/ui_projection.md "Battle — GB-centered").

Like seed_from_pret.py (menus), this ASSERTS that the seeded layout projects
back to every legacy byte offset / pixel coordinate before writing, and
aborts on any mismatch — so the sidecar provably reproduces today's screen.

Run once (from dos_port/): python3 tools/ui_layout/seed_from_battle.py
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from ui_layout import canvas as cv                     # noqa: E402
from ui_layout.schema import Element, Layout, save     # noqa: E402

DOS_PORT = Path(__file__).resolve().parent.parent.parent
OUT = DOS_PORT / "assets" / "ui_layout_battle_sidecar.json"

FW = 40                       # battle canvas stride (SCREEN_TILES_W)
SHIFT = (10, 3)               # the uniform battle transform (+10 col, +3 row)


def el(id, kind, gb_x, gb_y, gb_w, gb_h, *, resizable=False, min_w=3,
       min_h=3, text_label=None, source="", pret_ref="", notes=""):
    return Element(
        id=id, kind=kind, gb_x=gb_x, gb_y=gb_y, gb_w=gb_w, gb_h=gb_h,
        anchor_x="custom", anchor_y="custom",
        shift_x=SHIFT[0], shift_y=SHIFT[1],
        movable=True, resizable=resizable, min_w=min_w, min_h=min_h,
        text_label=text_label, source=source, pret_ref=pret_ref,
        anchor_source="confirmed",      # battle transform is RESOLVED
        notes=notes)


ELEMENTS = [
    # ── enemy HUD (battle_hud.asm) ──────────────────────────────────────────
    el("ENEMY_NAME", "text", 1, 0, 10, 1, text_label="RATTATA",
       source="battle_hud.asm E_NAME", pret_ref="engine/battle/core.asm:DrawEnemyHUDAndHPBar"),
    el("ENEMY_LV", "text", 4, 1, 3, 1,
       source="battle_hud.asm E_LV", pret_ref="engine/battle/core.asm:PrintLevel",
       notes='":L" tile $6e + 2 digits'),
    el("ENEMY_HPBAR", "hp_gauge", 2, 2, 9, 1,
       source="battle_hud.asm E_HPBAR", pret_ref="engine/battle/core.asm:DrawHPBar"),
    el("ENEMY_HUD_FRAME", "hud_frame", 1, 2, 10, 2,
       source="battle_hud.asm DrawEnemyHUDFrame",
       pret_ref="engine/battle/core.asm:PlaceEnemyHUDTiles",
       notes="variant=enemy; $73 connector top-left, shelf corner->triangle rightward"),
    # ── player HUD (battle_hud.asm; port keeps it one row above pret) ──────
    el("PLAYER_NAME", "text", 10, 7, 10, 1, text_label="PIKACHU",
       source="battle_hud.asm P_NAME", pret_ref="engine/battle/core.asm:DrawPlayerHUDAndHPBar"),
    el("PLAYER_LV", "text", 14, 8, 3, 1,
       source="battle_hud.asm P_LV", pret_ref="engine/battle/core.asm:PrintLevel"),
    el("PLAYER_HPBAR", "hp_gauge", 10, 9, 9, 1,
       source="battle_hud.asm P_HPBAR", pret_ref="engine/battle/core.asm:DrawHPBar"),
    el("PLAYER_HPFRAC", "text", 11, 10, 7, 1, text_label="20/ 25",
       source="battle_hud.asm P_HPFRAC", pret_ref="engine/battle/core.asm:DrawPlayerHUDAndHPBar"),
    el("PLAYER_HUD_FRAME", "hud_frame", 9, 9, 10, 3,
       source="battle_hud.asm DrawPlayerHUDFrame",
       pret_ref="engine/battle/core.asm:PlacePlayerHUDTiles",
       notes="variant=player; 2 stacked $73 connectors top-right, shelf leftward"),
    # ── dialog box (init_battle.asm / core.asm / battle_menu.asm) ──────────
    el("DIALOG_BOX", "textbox", 0, 12, 20, 6, resizable=True, min_w=20, min_h=6,
       source="init_battle.asm BOX_*/battle_menu.asm OUTER_OFF",
       pret_ref="engine/battle/core.asm (hlcoord 0,12 text box)",
       notes="interior 18x4; pret <LINE> wrapping assumes 18-wide interior — "
             "never shrink below 20x6 outer. Single-spaced interim rows are "
             "OFS + n*stride + 1 relative to this box."),
    el("DIALOG_LINE1", "text", 1, 14, 18, 1, text_label="Wild RATTATA",
       source="core.asm BTXT_LINE1", pret_ref="home/text.asm:TextCommandProcessor",
       notes="box interior row 2; intro/message line 1"),
    el("DIALOG_LINE2", "text", 1, 16, 18, 1, text_label="appeared!",
       source="core.asm BTXT_LINE2", pret_ref="home/text.asm (<LINE>)",
       notes="box interior row 4; message line 2"),
    el("DIALOG_ARROW", "cursor", 18, 16, 1, 1, min_w=1, min_h=1,
       source="core.asm BTXT_ARROW / battle_menu.asm ARROW_OFF",
       pret_ref="home/text.asm:HandleDownArrowBlinkTiming",
       notes="blinking $ee down-arrow, box bottom-right interior"),
    # ── action menu FIGHT/PKMN/ITEM/RUN (battle_menu.asm / core.asm) ───────
    el("ACTION_MENU_BOX", "textbox", 8, 12, 12, 6, resizable=True,
       source="battle_menu.asm BOX_OFF/BOX_W/BOX_H",
       pret_ref="data/text_boxes.asm BATTLE_MENU_TEMPLATE 8,12,19,17",
       notes="interior 10x4"),
    el("ACTION_TEXT", "text", 10, 14, 8, 3, text_label="FIGHT\nITEM  RUN",
       source="battle_menu.asm TEXT_OFF",
       pret_ref="data/text_boxes.asm BattleMenuText",
       notes="double-spaced 2 lines (rows +0/+2)"),
    el("ACTION_CUR_L", "cursor", 9, 14, 1, 1, min_w=1, min_h=1,
       source="core.asm CUR_COL_L/MENU_ROW", pret_ref="engine/battle/core.asm:DisplayBattleMenu",
       notes="FIGHT/PKMN column; cursor rows +0/+2"),
    el("ACTION_CUR_R", "cursor", 15, 14, 1, 1, min_w=1, min_h=1,
       source="core.asm CUR_COL_R/MENU_ROW", pret_ref="engine/battle/core.asm:DisplayBattleMenu",
       notes="ITEM/RUN column"),
    el("SAFARI_TEXT", "text", 2, 14, 16, 3,
       text_label="BALL      BAIT\nTHROW ROCK  RUN",
       source="text_box.asm SAFARI_BATTLE_MENU_TEMPLATE (box = DIALOG_BOX)",
       pret_ref="data/text_boxes.asm SAFARI_BATTLE_MENU_TEMPLATE 0,12,19,17 / text 2,14",
       notes="double-spaced 2 lines inside DIALOG_BOX (safari replaces the "
             "action menu with full-width labels)"),
    # ── move select (core.asm) ─────────────────────────────────────────────
    el("MOVE_BOX", "textbox", 4, 12, 16, 6, resizable=True,
       source="core.asm MOVEBOX_OFF/MOVEBOX_W/MOVEBOX_H",
       pret_ref="engine/battle/core.asm:MoveSelectionMenu",
       notes="interior 14x4; top edge gets '-'/corner-join tiles at +0/+6"),
    el("MOVE_TEXT", "text", 6, 13, 12, 4, text_label="TACKLE",
       source="core.asm MOVES_TEXT", pret_ref="engine/battle/core.asm (.writemoves)",
       notes="single-spaced 4 move rows (preview shows row 1 only)"),
    el("MOVE_CURSOR", "cursor", 5, 13, 1, 1, min_w=1, min_h=1,
       source="core.asm MOVES_CUR_COL/MOVES_ROW0",
       pret_ref="engine/battle/core.asm:SelectMenuItem",
       notes="single-spaced rows +0..+3"),
    # ── TYPE/PP info box (battle_menu.asm) ─────────────────────────────────
    el("INFO_BOX", "textbox", 0, 8, 11, 5, resizable=True,
       source="battle_menu.asm IB_COL/IB_ROW (interior 9x3)",
       pret_ref="engine/battle/core.asm:PrintMenuItem",
       notes="TYPE/, type name, PP nn/nn — interior text derives from box origin"),
    # ── level-up stats box (battle_menu.asm) ───────────────────────────────
    el("LVLUP_BOX", "textbox", 9, 2, 11, 10, resizable=True,
       source="battle_menu.asm LVLBOX_OFF/W/H (interior 9x8)",
       pret_ref="engine/battle/experience.asm LevelUpStatsBox"),
    el("LVLUP_LBL", "text", 11, 3, 7, 7, text_label="ATTACK",
       source="battle_menu.asm LVL_LBL_OFF",
       pret_ref="engine/battle/experience.asm (stat labels)",
       notes="4 labels, step 2 rows; moves as a group with LVLUP_VAL"),
    el("LVLUP_VAL", "text", 15, 4, 3, 7,
       source="battle_menu.asm LVL_VAL_OFF",
       pret_ref="engine/battle/experience.asm (stat values)",
       notes="4 values, step 2 rows; moves as a group with LVLUP_LBL"),
    # ── mon pics (pics.asm) ────────────────────────────────────────────────
    el("ENEMY_PIC", "mon_pic", 12, 0, 7, 7,
       source="pics.asm SlideBattlePicsIn (col 22, row 3)",
       pret_ref="engine/battle/core.asm (enemy front pic hlcoord 12,0)"),
    el("PLAYER_PIC", "mon_pic", 1, 5, 7, 7,
       source="pics.asm SlideBattlePicsIn (col 11, row 8)",
       pret_ref="engine/battle/core.asm (player back pic hlcoord 1,5)"),
    # ── party-status pokéball OAM rows (pokeballs.asm) ─────────────────────
    el("PLAYER_BALLS", "oam_row", 11, 10, 6, 1,
       source="pokeballs.asm PB_X/PB_Y (OAM 0x60+80, 0x60+24)",
       pret_ref="engine/battle/core.asm:SetupOwnPartyPokeballs",
       notes="OAM base = LEFT ball, marches right (+8px)"),
    el("ENEMY_BALLS", "oam_row", 3, 2, 6, 1,
       source="pokeballs.asm EB_X/EB_Y (OAM 0x48+80, 0x20+24)",
       pret_ref="engine/battle/core.asm:SetupEnemyPartyPokeballs",
       notes="OAM base = RIGHT ball (element right edge), marches left (-8px);"
             " engine base = OAM_X + 5*8"),
]


def main() -> None:
    lay = Layout(subsystem="battle", elements=ELEMENTS)
    errs = lay.validate()
    if errs:
        sys.exit("validation failed:\n  " + "\n  ".join(errs))

    p = {e.id: cv.project(e) for e in ELEMENTS}
    ofs = {eid: pr.row * FW + pr.col for eid, pr in p.items()}

    # ── assert every legacy byte offset / pixel coordinate ──────────────────
    legacy = {
        # battle_hud.asm
        "ENEMY_NAME":  3 * FW + 11,     # E_NAME
        "ENEMY_LV":    4 * FW + 14,     # E_LV
        "ENEMY_HPBAR": 5 * FW + 12,     # E_HPBAR
        "ENEMY_HUD_FRAME": 5 * FW + 11,  # $73 connector (element top-left)
        "PLAYER_NAME": 10 * FW + 20,    # P_NAME
        "PLAYER_LV":   11 * FW + 24,    # P_LV
        "PLAYER_HPBAR": 12 * FW + 20,   # P_HPBAR
        "PLAYER_HPFRAC": 13 * FW + 21,  # P_HPFRAC
        "PLAYER_HUD_FRAME": 12 * FW + 28,  # upper $73 connector (top-RIGHT)
        # init_battle.asm / battle_menu.asm / core.asm
        "DIALOG_BOX":  15 * FW + 10,    # BOX_ROW*FW+BOX_COL == OUTER_OFF
        "DIALOG_LINE1": 17 * FW + 11,   # BTXT_LINE1
        "DIALOG_LINE2": 19 * FW + 11,   # BTXT_LINE2
        "DIALOG_ARROW": 19 * FW + 28,   # BTXT_ARROW == ARROW_OFF
        "ACTION_MENU_BOX": 15 * FW + 18,  # BOX_OFF
        "ACTION_TEXT": 17 * FW + 20,    # TEXT_OFF
        "ACTION_CUR_L": 17 * FW + 19,   # MENU_ROW*FW+CUR_COL_L
        "ACTION_CUR_R": 17 * FW + 25,   # MENU_ROW*FW+CUR_COL_R
        "MOVE_BOX":    15 * FW + 14,    # MOVEBOX_OFF
        "MOVE_TEXT":   16 * FW + 16,    # MOVES_TEXT
        "MOVE_CURSOR": 16 * FW + 15,    # MOVES_ROW0*FW+MOVES_CUR_COL
        "INFO_BOX":    11 * FW + 10,    # INFOBOX_OFF (IB_ROW*FW+IB_COL)
        "LVLUP_BOX":   5 * FW + 19,     # LVLBOX_OFF
        "LVLUP_LBL":   6 * FW + 21,     # LVL_LBL_OFF
        "LVLUP_VAL":   7 * FW + 25,     # LVL_VAL_OFF
        "SAFARI_TEXT": 17 * FW + 12,    # UI_SAFARI_BATTLE_MENU_TEMPLATE_TX/TY
    }
    bad = []
    for eid, want in legacy.items():
        got = ofs[eid]
        if eid == "PLAYER_HUD_FRAME":   # connector = top-RIGHT of the element
            got = ofs[eid] + ELEMENTS_BY_ID[eid].gb_w - 1
        if got != want:
            bad.append(f"{eid}: projected offset {got} != legacy {want}")

    # pics + slide (pics.asm: enemy col 22 row 3, player col 11 row 8, 18 steps)
    if (p["ENEMY_PIC"].col, p["ENEMY_PIC"].row) != (22, 3):
        bad.append("ENEMY_PIC != canvas (22,3)")
    if (p["PLAYER_PIC"].col, p["PLAYER_PIC"].row) != (11, 8):
        bad.append("PLAYER_PIC != canvas (11,8)")
    steps = max(FW - p["ENEMY_PIC"].col, p["PLAYER_PIC"].col + 7)
    if steps != 18:
        bad.append(f"derived SLIDE_STEPS {steps} != 18")

    # pokéballs (pokeballs.asm OAM values; OAM = screen px + (8,16))
    if (p["PLAYER_BALLS"].col * 8 + 8, p["PLAYER_BALLS"].row * 8 + 16) \
            != (0x60 + 80, 0x60 + 24):
        bad.append("PLAYER_BALLS OAM base mismatch (PB_X/PB_Y)")
    ebx = (p["ENEMY_BALLS"].col + 5) * 8 + 8      # right-end ball
    eby = p["ENEMY_BALLS"].row * 8 + 16
    if (ebx, eby) != (0x48 + 80, 0x20 + 24):
        bad.append("ENEMY_BALLS OAM base mismatch (EB_X/EB_Y)")

    if bad:
        sys.exit("LEGACY GEOMETRY MISMATCH — refusing to seed:\n  "
                 + "\n  ".join(bad))

    save(lay, OUT)
    print(f"seeded {OUT} ({len(ELEMENTS)} elements) — all "
          f"{len(legacy) + 5} legacy-geometry assertions passed")


ELEMENTS_BY_ID = {e.id: e for e in ELEMENTS}

if __name__ == "__main__":
    main()
