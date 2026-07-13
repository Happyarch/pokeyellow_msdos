"""Palette-aware PNG previews used by the shade-reassignment editor."""
from __future__ import annotations

from PIL import Image, ImageDraw

from gfx_core.tiles import ROOT


def species_png(species: str) -> Image.Image:
    path = ROOT / "gfx" / "pokemon" / "front" / f"{species.lower()}.png"
    if not path.exists():
        path = ROOT / "gfx" / "pokemon" / "front" / "pikachu.png"
    return Image.open(path).convert("L")


def recolor(img: Image.Image, palette: list[tuple[int, int, int]]) -> Image.Image:
    """Pret grayscale (light=shade 0) to a candidate VGA-six-bit palette."""
    out = Image.new("RGB", img.size)
    src, dst = img.load(), out.load()
    for y in range(img.height):
        for x in range(img.width):
            shade = 3 - min(3, round(src[x, y] / 85))
            rgb = palette[shade]
            dst[x, y] = tuple(v * 255 // 63 for v in rgb)
    return out


def battle_mock(species: str, slots: list[list[tuple[int, int, int]]]) -> Image.Image:
    """Compact battle composition: player/enemy pictures, bars and message box."""
    img = Image.new("RGB", (320, 216), tuple(v * 255 // 63 for v in slots[0][0]))
    mon = species_png(species).resize((112, 112), Image.Resampling.NEAREST)
    img.paste(recolor(mon, slots[3]), (190, 0))
    img.paste(recolor(mon, slots[2]), (18, 68))
    draw = ImageDraw.Draw(img)
    for y, pal in ((42, slots[1]), (145, slots[0])):
        draw.rectangle((24, y, 154, y + 12), fill=tuple(v * 255 // 63 for v in pal[3]))
        draw.rectangle((27, y + 3, 127, y + 9), fill=tuple(v * 255 // 63 for v in pal[1]))
    draw.rectangle((0, 168, 319, 215), fill=tuple(v * 255 // 63 for v in slots[2][0]),
                   outline=tuple(v * 255 // 63 for v in slots[2][3]), width=3)
    return img
