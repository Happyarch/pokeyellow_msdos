"""Lossless route-byte decoding for editor path previews."""
from __future__ import annotations

from dataclasses import dataclass
import re
from pathlib import Path

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
        if op.kind in ('unknown', 'unsafe_special', 'change_facing_unknown'):
            break  # later positions are not safely predictable
        table = _STEP if op.kind == "step" else _QUICK if op.kind == "quick_step" else None
        if table and op.byte in table:
            dy, dx, _ = table[op.byte]
            # The driver advances one 16px map square = two 8px tiles.
            pos = pos.translated(dy * 2, dx * 2)
            out.append(pos)
    return out


@dataclass(frozen=True)
class RouteBinding:
    label: str
    drivers: tuple[str, ...]
    values: bytes
    spans: tuple[tuple[int, int], ...]


def scan(path: Path) -> list[RouteBinding]:
    """Recognize literal byte streams bound directly to MoveSprite drivers.

    This deliberately does not infer computed pointers or generated macros.
    Numeric byte spans are retained separately so checked edits preserve all
    labels, surrounding assembly and comments.
    """
    text = path.read_text()
    lines = text.splitlines(keepends=True)
    offsets = []
    at = 0
    for line in lines:
        offsets.append(at)
        at += len(line)
    labels = {}
    for i, line in enumerate(lines):
        match = re.match(r'^\s*([A-Za-z_]\w*):\s*(?:;.*)?$', line.rstrip('\r\n'))
        if match:
            labels[match.group(1)] = i
    direct = {}
    for i, line in enumerate(lines):
        call = re.match(r'^\s*call\s+(MoveSprite2?)\b', line)
        if not call:
            continue
        driver = call.group(1)
        seen_registers = set()
        for previous in reversed(lines[max(0, i-12):i]):
            if re.match(r'^\s*[A-Za-z_]\w*:', previous):
                break
            m = re.match(r'^\s*mov\s+(edi|edx)\s*,\s*([^;\s]+)\s*(?:;.*)?$',
                         previous.rstrip('\r\n'), re.IGNORECASE)
            if m:
                register = m.group(1).lower()
                if register in seen_registers:
                    continue
                seen_registers.add(register)
                if (register == 'edi' or driver == 'MoveSprite2') and re.fullmatch(r'[A-Za-z_]\w*', m.group(2)):
                    direct.setdefault(m.group(2), set()).add(driver)
    found = []
    for label, drivers in sorted(direct.items()):
        if label not in labels:
            continue
        values, spans = [], []
        for i in range(labels[label] + 1, len(lines)):
            line = lines[i]
            if re.match(r'^\s*(?:;.*)?$', line.rstrip('\r\n')) or re.match(r'^\s*[A-Za-z_]\w*:\s*$', line.rstrip('\r\n')):
                continue
            match = re.match(r'^\s*db\s+(0x[0-9a-fA-F]+|\$[0-9a-fA-F]+|\d+)\s*(?:;.*)?$', line.rstrip('\r\n'), re.IGNORECASE)
            if not match:
                break
            literal = match.group(1)
            value = int(literal[1:], 16) if literal.startswith('$') else int(literal, 0)
            if value > 255:
                break
            values.append(value)
            spans.append((offsets[i] + match.start(1), offsets[i] + match.end(1)))
            if value == 255:
                found.append(RouteBinding(label, tuple(sorted(drivers)), bytes(values), tuple(spans)))
                break
    return found
