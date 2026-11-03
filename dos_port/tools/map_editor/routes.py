"""Lossless route-byte decoding for editor path previews."""
from __future__ import annotations

from dataclasses import dataclass

from map_editor.scripts import TileYX


_STEP = {0x00: (1, 0, "down"), 0x40: (-1, 0, "up"),
         0x80: (0, -1, "left"), 0xC0: (0, 1, "right")}
_QUICK = {0x04: (1, 0, "down"), 0x05: (-1, 0, "up"),
          0x06: (0, -1, "left"), 0x07: (0, 1, "right")}


@dataclass(frozen=True)
class RouteOp:
    kind: str
    byte: int
    direction: str | None = None


def decode(raw: bytes) -> list[RouteOp]:
    result = []
    for value in raw:
        if value == 0xff:
            result.append(RouteOp("end", value))
            break
        if value in _STEP:
            result.append(RouteOp("step", value, _STEP[value][2]))
        elif value in _QUICK:
            result.append(RouteOp("quick_step", value, _QUICK[value][2]))
        elif value == 0xe0:
            # The driver uses a stale facing register; it is not a direction.
            result.append(RouteOp("change_facing_unknown", value))
        elif 0x11 <= value <= 0x14:
            # Func_5288's set-2 path has a documented WRAM write bug. Do not
            # present these as safe turns or invent a positional trace.
            result.append(RouteOp("unsafe_special", value))
        else:
            result.append(RouteOp("unknown", value))
    return result


def preview(anchor: TileYX, ops: list[RouteOp]) -> list[TileYX]:
    """Derive visible positions; expansion moves anchor, never direction bytes."""
    out = [anchor]
    pos = anchor
    for op in ops:
        table = _STEP if op.kind == "step" else _QUICK if op.kind == "quick_step" else None
        if table and op.byte in table:
            dy, dx, _ = table[op.byte]
            # The driver advances one 16px map square = two 8px tiles.
            pos = pos.translated(dy * 2, dx * 2)
            out.append(pos)
    return out
