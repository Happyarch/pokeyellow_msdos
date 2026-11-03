"""Direct port-script coordinate bindings.

This module intentionally recognizes only source forms it can round-trip.  It
does not guess that arbitrary numeric assembly immediates are map coordinates.
"""
from __future__ import annotations

from dataclasses import dataclass
import hashlib
from pathlib import Path
import re


@dataclass(frozen=True)
class TileYX:
    y: int
    x: int

    def translated(self, dy: int, dx: int) -> "TileYX":
        return TileYX(self.y + dy, self.x + dx)


@dataclass(frozen=True)
class SourceSpan:
    path: Path
    start: int
    end: int
    digest: str

    @classmethod
    def from_text(cls, path: Path, start: int, end: int, text: str) -> "SourceSpan":
        return cls(path, start, end,
                   hashlib.sha256(text[start:end].encode()).hexdigest())

    def checked_text(self) -> str:
        text = self.path.read_text()
        actual = hashlib.sha256(text[self.start:self.end].encode()).hexdigest()
        if actual != self.digest:
            raise ValueError(f"{self.path}:{self.start}-{self.end} changed since scan")
        return text

    def replace(self, replacement: str) -> None:
        text = self.checked_text()
        self.path.write_text(text[:self.start] + replacement + text[self.end:])


@dataclass(frozen=True)
class CoordinateBinding:
    kind: str
    tile: TileYX
    span: SourceSpan
    source: str


_COORD = re.compile(r"\b(?P<macro>dbmapcoord|map_coord_movement)\s+"
                      r"(?P<x>\d+)\s*,\s*(?P<y>\d+)")
_ANNOTATED_DB = re.compile(r"\bdb\s+(?P<y>\d+)\s*,\s*(?P<x>\d+)"
                           r"(?P<gap>\s*;\s*dbmapcoord\s+)"
                           r"(?P<comment_x>\d+)\s*,\s*(?P<comment_y>\d+)")


def scan_coordinate_macros(path: Path) -> list[CoordinateBinding]:
    """Find editable macro coordinates; macro source is (X,Y), model is (Y,X)."""
    text = path.read_text()
    result = []
    offset = 0
    for line in text.splitlines(keepends=True):
        code = line.split(';', 1)[0]
        annotated = _ANNOTATED_DB.search(line)
        if annotated:
            y, x = int(annotated['y']), int(annotated['x'])
            if (x, y) != (int(annotated['comment_x']), int(annotated['comment_y'])):
                raise ValueError(f"{path}: dbmapcoord annotation disagrees with bytes")
            start, end = offset + annotated.start(), offset + annotated.end()
            result.append(CoordinateBinding(
                'annotated_dbmapcoord', TileYX(y * 2, x * 2),
                SourceSpan.from_text(path, start, end, text), annotated.group(0)))
        for match in _COORD.finditer(code):
            start, end = offset + match.start(), offset + match.end()
            result.append(CoordinateBinding(
                match.group("macro"), TileYX(int(match.group("y")) * 2, int(match.group("x")) * 2),
                SourceSpan.from_text(path, start, end, text), match.group(0)))
        offset += len(line)
    return result


def translate_binding(binding: CoordinateBinding, *, dy: int, dx: int,
                      write: bool = False) -> CoordinateBinding:
    """Translate one direct script macro without touching unrelated source."""
    tile = binding.tile.translated(dy, dx)
    if not (0 <= tile.y <= 510 and 0 <= tile.x <= 510 and tile.y % 2 == 0 and tile.x % 2 == 0):
        raise ValueError("script tile coordinates must be even and fit in a byte")
    y, x = tile.y // 2, tile.x // 2
    if binding.kind == 'annotated_dbmapcoord':
        old = _ANNOTATED_DB.fullmatch(binding.source)
        if old is None:
            raise ValueError("invalid annotated coordinate binding")
        replacement = f"db {y}, {x}{old['gap']}{x}, {y}"
    else:
        replacement = f"{binding.kind} {x}, {y}"
    if write:
        binding.span.replace(replacement)
    # A caller that wrote must rescan before performing another checked edit.
    return CoordinateBinding(binding.kind, tile, binding.span, replacement)
