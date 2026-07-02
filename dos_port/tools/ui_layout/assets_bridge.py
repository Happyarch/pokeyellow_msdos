"""assets_bridge.py — compatibility shim; the code moved to tools/gfx_core/.

Kept so pre-gfx_core imports (`from ui_layout import assets_bridge as ab`)
keep working. New code should import gfx_core.tiles / gfx_core.font directly.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from gfx_core.font import (            # noqa: E402,F401
    BOX_BL, BOX_BR, BOX_H, BOX_TL, BOX_TR, BOX_V, FONT_EXTRA_PNG, FONT_PNG,
    TILE_SPC, encode_label, tile_for_code,
)
from gfx_core.tiles import (           # noqa: E402,F401
    DMG_PAL, ROOT, TILE, TILES_PER_ROW,
)
