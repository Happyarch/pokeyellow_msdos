#!/usr/bin/env python3
"""Render FRAME.BIN (320x200 palette-indexed back buffer) to a PNG.

With PAL.BIN (optional third argument, or beside FRAME.BIN), values 0-63 use
the exact live VGA DAC state.  Without it a conspicuous debug palette is used.
Usage: render_frame.py FRAME.BIN out.png [PAL.BIN]
"""
import sys
from pathlib import Path
from PIL import Image

W, H = 320, 200

# DMG green ramp (debug palette) + a few distinct sprite colors so anything
# out of the 0-3 range is visually obvious.
PAL = {
    0: (224, 248, 208),  # lightest
    1: (136, 192, 112),
    2: (52, 104, 86),
    3: (8, 24, 32),      # darkest
    4: (255, 0, 0),      # sprite colors (magenta/red family) — should stand out
    5: (255, 128, 0),
    6: (255, 255, 0),
    7: (0, 255, 0),
    8: (0, 255, 255),
    9: (0, 128, 255),
    10: (128, 0, 255),
    11: (255, 0, 255),
}


def load_pal(path: Path) -> dict[int, tuple[int, int, int]]:
    """Read the PAL0 v1 debug contract emitted by debug_dump.asm."""
    data = path.read_bytes()
    if len(data) < 16 + 64 * 3 or data[:4] != b"PAL0" or data[4] != 1:
        raise ValueError(f"{path}: not a PAL0 v1 palette dump")
    rgb6 = data[16:16 + 64 * 3]
    return {i: tuple(round(component * 255 / 63)
                      for component in rgb6[i * 3:i * 3 + 3])
            for i in range(64)}

def main():
    if len(sys.argv) not in (3, 4):
        raise SystemExit(__doc__)
    frame_path = Path(sys.argv[1])
    data = frame_path.read_bytes()
    pal_path = Path(sys.argv[3]) if len(sys.argv) == 4 else frame_path.with_name("PAL.BIN")
    pal = load_pal(pal_path) if pal_path.exists() else PAL
    img = Image.new("RGB", (W, H))
    px = img.load()
    for y in range(H):
        for x in range(W):
            i = y * W + x
            v = data[i] if i < len(data) else 0
            px[x, y] = pal.get(v, (255, 0, 255))
    img.save(sys.argv[2])
    print(f"Wrote {sys.argv[2]} ({len(data)} bytes in)")

if __name__ == "__main__":
    main()
