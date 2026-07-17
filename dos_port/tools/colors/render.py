"""Palette-aware PNG previews used by the shade-reassignment editor."""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw

from gfx_core import sprites


def _load_gray(path: Path | None) -> Image.Image | None:
    if path is None or not path.exists():
        return None
    return Image.open(path).convert("L")


def _placeholder(label: str, size: int = 112) -> Image.Image:
    """A visible 'no sprite' box.  A missing file must never masquerade as a real
    (wrong) mon the way the old silent ``pikachu.png`` fallback did."""
    img = Image.new("L", (size, size), 170)
    draw = ImageDraw.Draw(img)
    draw.rectangle((0, 0, size - 1, size - 1), outline=0, width=2)
    draw.line((0, 0, size - 1, size - 1), fill=0, width=2)
    draw.line((0, size - 1, size - 1, 0), fill=0, width=2)
    draw.text((4, size // 2 - 6), label[:12], fill=0)
    return img


def species_png(species: str) -> Image.Image:
    """Front battle sprite for a species, resolved via pret's real filenames."""
    img = _load_gray(sprites.front_png(species))
    if img is None:
        print(f"colorize: no front sprite for {species!r}", file=sys.stderr)
        return _placeholder(species)
    return img


def back_png(species: str) -> Image.Image:
    """Player-side back sprite for a species (32x32 in pret, doubled in-game)."""
    img = _load_gray(sprites.back_png(species))
    if img is None:
        print(f"colorize: no back sprite for {species!r}", file=sys.stderr)
        return _placeholder(species)
    return img


def trainer_png(path: Path) -> Image.Image:
    """Enemy trainer battle sprite from a ``gfx/trainers/`` path."""
    img = _load_gray(path)
    if img is None:
        print(f"colorize: no trainer sprite at {path}", file=sys.stderr)
        return _placeholder("TRAINER")
    return img


def player_back_png() -> Image.Image:
    """Red's back sprite (the player-side battle slide-in)."""
    img = _load_gray(sprites.player_back_png())
    if img is None:
        print("colorize: no player back sprite (gfx/player/redb.png)", file=sys.stderr)
        return _placeholder("RED")
    return img


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


def battle_mock(subject, slots: list[list[tuple[int, int, int]]],
                mode: str = "mon") -> Image.Image:
    """Compact battle composition: enemy/player pictures, bars and message box.

    ``mode='mon'``    — ``subject`` is a species name: enemy slot = front sprite,
                        player slot = that species' back sprite.
    ``mode='trainer'`` — ``subject`` is a ``gfx/trainers/`` Path: enemy slot =
                        trainer front pic, player slot = Red's back sprite.
    """
    img = Image.new("RGB", (320, 216), tuple(v * 255 // 63 for v in slots[0][0]))
    if mode == "trainer":
        enemy, player = trainer_png(subject), player_back_png()
    else:
        enemy, player = species_png(subject), back_png(subject)
    # Both slots fill a 112x112 box; back/Red sprites are half-res so they read
    # chunkier, exactly as Gen-1 back sprites do next to a full-size front pic.
    enemy = enemy.resize((112, 112), Image.Resampling.NEAREST)
    player = player.resize((112, 112), Image.Resampling.NEAREST)
    img.paste(recolor(enemy, slots[3]), (190, 0))
    img.paste(recolor(player, slots[2]), (18, 68))
    draw = ImageDraw.Draw(img)
    for y, pal in ((42, slots[1]), (145, slots[0])):
        draw.rectangle((24, y, 154, y + 12), fill=tuple(v * 255 // 63 for v in pal[3]))
        draw.rectangle((27, y + 3, 127, y + 9), fill=tuple(v * 255 // 63 for v in pal[1]))
    draw.rectangle((0, 168, 319, 215), fill=tuple(v * 255 // 63 for v in slots[2][0]),
                   outline=tuple(v * 255 // 63 for v in slots[2][3]), width=3)
    return img
