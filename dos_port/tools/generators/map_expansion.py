"""Compatibility facade for generic map-authoring extents.

Historically this module carried a one-off VERMILION_DOCK rule.  Map extension
data now lives in editor-owned ``assets/map_overrides/<Pascal>.json`` schema 2,
and both map headers and blobs call this facade so legacy imports retain one
shared implementation.
"""
from __future__ import annotations

import sys
from pathlib import Path


TOOLS = Path(__file__).resolve().parent.parent
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from map_editor import schema  # noqa: E402


def _pascal(const: str) -> str:
    return "".join(word.capitalize() for word in const.split("_"))


def expanded_dims(const: str, w: int, h: int) -> tuple[int, int]:
    """Return port dimensions from the generic map-diff sidecar."""
    return schema.expanded_dims(_pascal(const), w, h)


def expand_blk(const: str, data: bytes, w: int, h: int) -> bytes:
    """Compose the raw pret layout with its generic map-diff expansion.

    Legacy callers have already merged v1 block overrides into ``data``. Schema
    2 owns its own base-block overrides, so the asset generator calls the shared
    composition path directly instead of combining both representations.
    """
    pascal = _pascal(const)
    # Several historical .blk stems map to shared/COPY headers whose parsed
    # dimensions do not describe this standalone blob. Identity map diffs must
    # preserve the old generator behavior and leave those bytes alone.
    if not schema.load(pascal).is_v2:
        return bytes(data)
    composed, out_w, out_h, _ = schema.compose_layout(pascal, data, w, h)
    if len(composed) != out_w * out_h:
        raise AssertionError("map composition returned an invalid block layout")
    return bytes(composed)
