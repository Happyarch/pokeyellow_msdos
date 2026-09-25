#!/usr/bin/env python3
"""gen_imfc_patches.py — IBM Music Feature Card (IMFC) SysEx setup generator.

Wrapper around gen_imfc_custom_patches.py for compatibility.
"""

from __future__ import annotations

import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from gen_imfc_custom_patches import main, build_imfc_sysex_blob, pack_voice_definition, encode_voice_sysex

if __name__ == "__main__":
    main()
