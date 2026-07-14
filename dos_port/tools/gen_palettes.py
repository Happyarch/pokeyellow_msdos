#!/usr/bin/env python3
"""Generate ``assets/colors/palettes.inc`` from pret data plus sidecar deltas."""
from __future__ import annotations

from pathlib import Path
import sys
from PIL import Image

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from colors import schema
from gfx_core import palettes

ASSETS = HERE.parent / "assets" / "colors"
SIDECAR = ASSETS / "palettes.json"
OUT = ASSETS / "palettes.inc"


def emit() -> str:
    sidecar = schema.load(SIDECAR)
    rgb = palettes.parse_cgb_base_palettes()
    rgb.update(sidecar.pal_overrides)
    pals, _ = palettes.palette_enums()
    rows = sorted(pals.items(), key=lambda item: item[1])
    # Per-species RGB deltas receive deterministic port-only palette ids after
    # pret's PAL_* range. The runtime consumes ids, not their provenance.
    custom = []
    for species in sorted(sidecar.species_overrides):
        override = sidecar.species_overrides[species]
        if "colors" in override:
            custom.append((f"PAL_OVERRIDE_{species}", override["colors"]))
    rgb_rows = [(name, rgb[name]) for name, _ in rows] + custom
    # Repaint palettes are local to a front-pic record.  Give each one a
    # generated RGB-table id; R2 installs those ids in otherwise-free BG slots
    # 4..7 when that record is loaded.
    repaint_rows: dict[str, tuple[list[int], int, int]] = {}
    for asset, repaint in sorted(sidecar.repaint.items()):
        if not asset.endswith("_FRONT"):
            raise ValueError(f"repaint.{asset}: only *_FRONT assets are supported")
        if asset[:-6] not in palettes.parse_monster_palettes():
            raise ValueError(f"repaint.{asset}: unknown Pok\u00e9mon species")
        grid = repaint.get("tile_pal")
        extra = repaint.get("extra_palettes")
        blob = repaint.get("override_2bpp")
        png = repaint.get("png")
        if not isinstance(png, str):
            raise ValueError(f"repaint.{asset}.png: expected a path")
        png_path = HERE.parent / "assets" / png
        if not png_path.is_file():
            raise ValueError(f"repaint.{asset}.png: source image not found")
        with Image.open(png_path) as image:
            if image.width % 8 or image.height % 8:
                raise ValueError(f"repaint.{asset}.png: dimensions must be tile-aligned")
            width, height = image.width // 8, image.height // 8
        if not 1 <= width <= 7 or not 1 <= height <= 7:
            raise ValueError(f"repaint.{asset}.png: picture must fit the 7x7 sprite canvas")
        if not isinstance(grid, list) or len(grid) != width * height:
            raise ValueError(f"repaint.{asset}.tile_pal: expected {width * height} cells from its PNG")
        if not isinstance(extra, list) or not extra:
            raise ValueError(f"repaint.{asset}.extra_palettes: expected one to four palettes")
        if max(grid) >= len(extra):
            raise ValueError(f"repaint.{asset}.tile_pal: references a missing extra palette")
        if not isinstance(blob, str):
            raise ValueError(f"repaint.{asset}.override_2bpp: expected a path")
        blob_path = HERE.parent / "assets" / blob
        if not blob_path.is_file() or blob_path.stat().st_size != width * height * 16:
            raise ValueError(f"repaint.{asset}.override_2bpp: expected a {width * height * 16}-byte 2bpp file")
        ids: list[int] = []
        for i, colors in enumerate(extra):
            name = f"PAL_REPAINT_{asset}_{i}"
            rgb_rows.append((name, colors))
            ids.append(len(rgb_rows) - 1)
        repaint_rows[asset] = ids, width, height
    # Port bootstrap palette.  Keeping it in the generated table makes the
    # runtime's non-battle defaults byte-for-byte equivalent to the old DMG
    # green ramp while every live slot still follows one code path.
    rgb_rows.append(("PAL_DMG_GREEN", [(38, 47, 3), (34, 43, 3),
                                        (12, 24, 12), (3, 14, 3)]))
    palette_ids = {name: i for i, (name, _) in enumerate(rgb_rows)}

    mon_source = palettes.parse_monster_palettes()
    mon_rows = []
    for species, source_pal in mon_source.items():
        override = sidecar.species_overrides.get(species, {})
        pal = f"PAL_OVERRIDE_{species}" if "colors" in override else override.get("pal", source_pal)
        mon_rows.append(palette_ids[pal])

    # SetPal_Battle starts with PalPacket_Empty then patches all four slots.
    # These defaults make the generated table usable by previews before R1.
    battle_slots = [palette_ids["PAL_GREENBAR"], palette_ids["PAL_GREENBAR"],
                    palette_ids["PAL_MEWMON"], palette_ids["PAL_MEWMON"]]
    for slot, pal in sidecar.screen_overrides.get("SET_PAL_BATTLE", {}).items():
        battle_slots[int(slot[4:])] = palette_ids[pal]

    # Physical tile_cache order is $8000..$97ff. Battle signed-BG tile IDs map
    # vFrontPic $9000+$00..$30 to cache 256..304 and vBackPic $9000+$31..$61
    # to 305..353. BlkPacket_Battle is the source for the slot order below.
    battle_blocks = palettes.parse_blk_packets()["BlkPacket_Battle"]
    if [b["pal0"] for b in battle_blocks] != [2, 1, 0, 2, 3]:
        raise ValueError("BlkPacket_Battle layout no longer matches colorization design")
    battle_tile_pal = [0] * 384
    battle_tile_pal[128:256] = [2] * 128     # font/message-box tile band
    battle_tile_pal[256:305] = [3] * 49      # enemy front pic
    battle_tile_pal[305:354] = [2] * 49      # player back pic
    # $62..$7f currently share player/enemy HP patterns. R1 clones the nine
    # gauge patterns ($63..$6b) into battle-only vFont glyph slots; physical
    # cache index for a signed tile id is 256 + signed(id). F-19: the slots are
    # $C0-$C8 — the charmap maps NOTHING in $C0-$DF, so no text can reference
    # them (the previous picks $EC/$EE/$EF/$F0/$F1/$F4 were live glyphs and
    # clobbered the battle dialog's ▼ prompt). Keep in sync with
    # battle_hud.asm:enemy_hp_tile_ids.
    battle_tile_pal[354:384] = [0] * 30
    for tile_id in (0xC0, 0xC1, 0xC2, 0xC3, 0xC4, 0xC5, 0xC6, 0xC7, 0xC8):
        battle_tile_pal[tile_id] = 1
    # The non-battle SetPal_* commands consume their corresponding SGB packet's
    # four palette ids.  The renderer's current tile ownership supplies the
    # per-region slot selection; commands still reset the default slots below.
    packet_for_command = [
        "PalPacket_Black", "PalPacket_Empty", "PalPacket_TownMap", "PalPacket_Empty",
        "PalPacket_Pokedex", "PalPacket_Slots", "PalPacket_Titlescreen",
        "PalPacket_NidorinoIntro", "PalPacket_Generic", "PalPacket_Empty",
        "PalPacket_PartyMenu", "PalPacket_Empty", "PalPacket_GameFreakIntro",
        "PalPacket_TrainerCard", "PalPacket_PikachusBeach", "PalPacket_PikachusBeachTitle",
    ]
    packet_rows = palettes.parse_pal_packets()
    command_pal = []
    for command, packet_name in enumerate(packet_for_command):
        row = [palette_ids[value] if isinstance(value, str) else value
               for value in packet_rows[packet_name]]
        for slot, palette in sidecar.screen_overrides.get(
                next((name for name, value in palettes.palette_enums()[1].items()
                      if value == command), ""), {}).items():
            row[int(slot[4:])] = palette_ids[palette]
        command_pal.extend(row)
    lines = [
        "; palettes.inc — generated by tools/gen_palettes.py. DO NOT EDIT BY HAND.",
        "; Source: pret CGBBasePalettes plus assets/colors/palettes.json deltas.",
        "; RGB values are VGA DAC six-bit R,G,B triples.", "",
        f"PAL_RGB_COUNT equ {len(rgb_rows)}",
        *[f"{name} equ {palette_id}" for name, palette_id in palette_ids.items()],
        "pal_rgb_table:",
    ]
    for name, colors in rgb_rows:
        flat = ", ".join(str(v) for color in colors for v in color)
        lines.append(f"    db {flat}  ; {name}")
    lines += ["", "; Pokédex order: MISSINGNO then #001..#151.",
              "mon_pal_table:"]
    for start in range(0, len(mon_rows), 16):
        lines.append("    db " + ", ".join(str(v) for v in mon_rows[start:start + 16]))
    lines += ["", "; SET_PAL_BATTLE slots: player HP, enemy HP, player pic, enemy pic.",
              "battle_slot_pal:", "    db " + ", ".join(map(str, battle_slots)),
              "", "; SET_PAL_* command x BG/OBJ palette slot (four bytes per command).",
              "command_pal_table:"]
    for start in range(0, len(command_pal), 16):
        lines.append("    db " + ", ".join(map(str, command_pal[start:start + 16])))
    lines += ["", "; physical cache tile ($8000-based) -> battle BG palette slot.",
              "battle_tile_pal:"]
    for start in range(0, len(battle_tile_pal), 32):
        lines.append("    db " + ", ".join(str(v) for v in battle_tile_pal[start:start + 32]))
    lines += ["", "; Pokédex #001..#151: dd repaint record, or zero for the normal decoder path.",
              "repaint_front_table:"]
    for species in list(mon_source)[1:]:
        asset = f"{species}_FRONT"
        lines.append(f"    dd repaint_{asset.lower()}" if asset in repaint_rows else "    dd 0")
    for asset, (ids, width, height) in sorted(repaint_rows.items()):
        repaint = sidecar.repaint[asset]
        stem = asset.lower()
        blob = repaint["override_2bpp"]
        grid = repaint["tile_pal"]
        lines += ["", f"repaint_{stem}:", f"    dd repaint_{stem}_2bpp, repaint_{stem}_tile_pal",
                  "    db " + str(len(ids)) + ", " + ", ".join(map(str, ids)) + f", {width}, {height}",
                  f"repaint_{stem}_2bpp: incbin \"assets/{blob}\"",
                  f"repaint_{stem}_tile_pal:"]
        for start in range(0, len(grid), 16):
            lines.append("    db " + ", ".join(map(str, grid[start:start + 16])))
    lines.append("")
    return "\n".join(lines)


def main() -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(emit())


if __name__ == "__main__":
    main()
