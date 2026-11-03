"""Overworld sprite thumbnails from pret's sheet pointer table."""
from functools import lru_cache
import re

from PIL import Image
from gfx_core.tiles import ROOT


@lru_cache(maxsize=1)
def sprite_paths():
    table = (ROOT / 'data/sprites/sprites.asm').read_text()
    labels = re.findall(r'^\s*overworld_sprite\s+(\w+),', table, re.MULTILINE)
    definitions = (ROOT / 'gfx/sprites.asm').read_text()
    paths = dict(re.findall(r'^\s*(\w+)::?\s+INCBIN\s+"([^"]+)"',
                            definitions, re.MULTILINE))
    return {i: (ROOT / paths[label]).with_suffix('.png')
            for i, label in enumerate(labels, 1) if label in paths}


@lru_cache(maxsize=512)
def thumbnail(sprite_id, colors):
    """Return the downward 16px frame, with index zero transparent.

    Colors are a preview of the map palette under identity OBP; runtime OBP
    registers and scripts can change it or the facing later.
    """
    path = sprite_paths().get(sprite_id)
    if not path or not path.exists():
        return None
    with Image.open(path) as source:
        source = source.convert('L').crop((0, 0, 16, 16))
        img = Image.new('RGBA', (16, 16))
        pixels = []
        for luminance in source.getdata():
            shade = 3 - min(3, round(luminance / 85))
            pixels.append((*colors[shade], 0 if shade == 0 else 255))
        img.putdata(pixels)
    return img
