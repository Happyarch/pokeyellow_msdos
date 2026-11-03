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


def scan_coordinate_macros(path: Path) -> list[CoordinateBinding]:
    """Find editable macro coordinates; macro source is (X,Y), model is (Y,X)."""
    text = path.read_text()
    result = []
    offset = 0
    for line in text.splitlines(keepends=True):
        code = line.split(';', 1)[0]
        for match in _COORD.finditer(code):
            start, end = offset + match.start(), offset + match.end()
            result.append(CoordinateBinding(
                match.group("macro"), TileYX(int(match.group("y")), int(match.group("x"))),
                SourceSpan.from_text(path, start, end, text), match.group(0)))
        offset += len(line)
    return result


def translate_binding(binding: CoordinateBinding, *, dy: int, dx: int,
                      write: bool = False) -> CoordinateBinding:
    """Translate one direct script macro without touching unrelated source."""
    tile = binding.tile.translated(dy, dx)
    if not (0 <= tile.y <= 255 and 0 <= tile.x <= 255):
        raise ValueError("script coordinate must fit in a byte")
    replacement = f"{binding.kind} {tile.x}, {tile.y}"
    if write:
        binding.span.replace(replacement)
    # A caller that wrote must rescan before performing another checked edit.
    return CoordinateBinding(binding.kind, tile, binding.span, replacement)
