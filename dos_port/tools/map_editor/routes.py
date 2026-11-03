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

# Named movement bytes the port's scripts actually use. pret defines these in
# constants/map_object_constants.asm; a stream written as `db NPC_MOVEMENT_UP`
# must stay symbolic after an edit, so the writer maps back through this table.
MOVEMENT_NAMES = {
    "NPC_MOVEMENT_DOWN": 0x00,
    "NPC_MOVEMENT_UP": 0x40,
    "NPC_MOVEMENT_LEFT": 0x80,
    "NPC_MOVEMENT_RIGHT": 0xC0,
    "STAY": 0xFF,
}
_CANONICAL = {"NPC_MOVEMENT_DOWN": 0x00, "NPC_MOVEMENT_UP": 0x40,
              "NPC_MOVEMENT_LEFT": 0x80, "NPC_MOVEMENT_RIGHT": 0xC0}
_BY_VALUE = {value: name for name, value in _CANONICAL.items()}
_TERMINATOR_NAMES = {"STAY"}
_LITERAL = re.compile(r"^-?(?:\d+|0x[0-9a-fA-F]+|\$[0-9a-fA-F]+)$")
_IDENT = re.compile(r"^[A-Za-z_]\w*$")


def resolve_token(token: str) -> int | None:
    """Byte value of one `db` operand, or None when it is not a known form."""
    token = token.strip()
    if token in MOVEMENT_NAMES:
        return MOVEMENT_NAMES[token]
    if _LITERAL.match(token):
        if token.startswith("$"):
            return int(token[1:], 16)
        return int(token, 0) & 0xFF
    return None


def render_token(original: str, value: int) -> str:
    """Rewrite one operand in the author's own style.

    A symbolic operand stays symbolic when the new byte has a name (so a
    movement stream keeps reading as NPC_MOVEMENT_*), otherwise it falls back to
    a hex literal rather than inventing a constant. Numeric styles are kept.
    """
    original = original.strip()
    if original in MOVEMENT_NAMES or (_IDENT.match(original) and original.isupper()):
        name = _BY_VALUE.get(value)
        return name if name else f"0x{value:02X}"
    if original.startswith("$"):
        return f"${value:02X}"
    if original.lower().startswith("0x"):
        return f"0x{value:02X}"
    if original.startswith("-"):
        return str(value - 256)
    return str(value)


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
    pair: str | None = None       # MoveSprite2 call site co-driving two streams
    channel: int | None = None    # 0 = first walker (EDI), 1 = second (EDX)
    slot: int | None = None       # sprite slot the stream is armed for (1-15)
    tokens: tuple[str, ...] = ()  # original operand text, for style-preserving writes


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

    direct: dict[str, set[str]] = {}
    # label -> (pair id, channel, slot).  A MoveSprite2 call arms TWO streams from
    # one call site: EDI/AL for the first walker, EDX/BL for the second.  That is
    # what the port's MoveSprite2 does with the two 90-byte buffer halves, and it
    # is what the NPCMV1/NPCMV2 overlays need to draw both paths at once.
    pairing: dict[str, tuple[str, int, int | None]] = {}

    for i, line in enumerate(lines):
        call = re.match(r'^\s*call\s+(MoveSprite2?)\b', line)
        if not call:
            continue
        driver = call.group(1)
        pair_id = f'{path.stem}:{i}'
        found: dict[str, str] = {}
        slots: dict[str, int] = {}
        seen: set[str] = set()
        for previous in reversed(lines[max(0, i - 14):i]):
            raw = previous.rstrip('\r\n')
            if re.match(r'^\s*[A-Za-z_]\w*:', raw):
                break
            # Intervening calls may clobber argument registers; do not infer
            # bindings across them. Any later write to a register also wins.
            if re.match(r'^\s*call\b', raw, re.IGNORECASE):
                break
            m = re.match(r'^\s*mov\s+(edi|edx|al|bl)\s*,\s*([^;\s]+)\s*(?:;.*)?$',
                         raw, re.IGNORECASE)
            if m:
                register = m.group(1).lower()
                if register in seen:
                    continue
                seen.add(register)
                value = m.group(2)
                if register in ('al', 'bl'):
                    if re.fullmatch(r'\d+', value):
                        slots[register] = int(value)
                elif register == 'edi' or driver == 'MoveSprite2':
                    if re.fullmatch(r'[A-Za-z_]\w*', value):
                        found[register] = value
            else:
                modified = re.match(
                    r'^\s*(?:lea|pop|add|sub|xor|and|or|inc|dec)\s+(edi|edx|al|bl)\b',
                    raw, re.IGNORECASE)
                if modified:
                    seen.add(modified.group(1).lower())
        if 'edi' in found:
            direct.setdefault(found['edi'], set()).add(driver)
            if driver == 'MoveSprite2':
                pairing.setdefault(found['edi'], (pair_id, 0, slots.get('al')))
            else:
                # A lone MoveSprite is one stream: no pair, no channel, but the
                # sprite slot it arms is still the anchor its path starts from.
                pairing.setdefault(found['edi'], (None, None, slots.get('al')))
        if driver == 'MoveSprite2' and 'edx' in found:
            direct.setdefault(found['edx'], set()).add(driver)
            pairing.setdefault(found['edx'], (pair_id, 1, slots.get('bl')))

    found_bindings = []
    for label, drivers in sorted(direct.items()):
        if label not in labels:
            continue
        values, spans, tokens = [], [], []
        for i in range(labels[label] + 1, len(lines)):
            line = lines[i]
            if re.match(r'^\s*(?:;.*)?$', line.rstrip('\r\n')) or re.match(r'^\s*[A-Za-z_]\w*:\s*$', line.rstrip('\r\n')):
                continue
            match = re.match(r'^\s*db\s+([^;\s]+)\s*(?:;.*)?$', line.rstrip('\r\n'), re.IGNORECASE)
            if not match:
                break
            token = match.group(1)
            value = resolve_token(token)
            if value is None:
                break
            values.append(value)
            tokens.append(token)
            spans.append((offsets[i] + match.start(1), offsets[i] + match.end(1)))
            if value == 255:
                pair, channel, slot = pairing.get(label, (None, None, None))
                found_bindings.append(RouteBinding(
                    label, tuple(sorted(drivers)), bytes(values), tuple(spans),
                    pair, channel, slot, tuple(tokens)))
                break
    return found_bindings
