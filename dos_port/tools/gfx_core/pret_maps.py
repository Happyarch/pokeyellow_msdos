"""pret_maps.py — read-only pret map metadata, via gen_map_headers's parsers.

Imports tools/gen_map_headers.py as a module (its main() is guarded) and
reuses its parsers/tables verbatim — parse_map_constants, parse_all_headers,
parse_object_file, TILESET_IDS/TILESET_CANONICAL, CONNECTIONS,
get_connection — so the tools can never drift from what the generator emits.
Everything here reads the pret tree; nothing writes.
"""
from __future__ import annotations

import sys
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_TOOLS))

import gen_map_headers as gmh          # noqa: E402

from .tiles import ROOT                # noqa: E402

# Re-exports: the generator's own tables are the single source of truth.
CONNECTIONS = gmh.CONNECTIONS
get_connection = gmh.get_connection
TILESET_IDS = gmh.TILESET_IDS
TILESET_CANONICAL = gmh.TILESET_CANONICAL
MAP_BORDER_BLOCKS = 6                  # gb_memmap.inc MAP_BORDER (verified)


@dataclass(frozen=True)
class MapInfo:
    const: str                         # e.g. "PALLET_TOWN"
    map_id: int
    w: int                             # width in blocks
    h: int                             # height in blocks
    label: str | None                  # e.g. "PalletTown" (None if headerless)
    tileset_name: str | None           # e.g. "OVERWORLD"
    tileset_id: int | None
    tileset_stem: str | None           # gfx/blockset stem, e.g. "overworld"


@lru_cache(maxsize=None)
def _constants() -> dict[str, tuple[int, int, int]]:
    return gmh.parse_map_constants()   # {const: (id, w, h)}


@lru_cache(maxsize=None)
def _headers() -> tuple[dict[str, str], dict[str, str]]:
    return gmh.parse_all_headers()     # (const->label, label->tileset)


def all_map_consts() -> list[str]:
    return list(_constants())


@lru_cache(maxsize=None)
def map_info(const: str) -> MapInfo:
    map_id, w, h = _constants()[const]
    const_to_label, label_tileset = _headers()
    label = const_to_label.get(const) or (
        gmh.const_to_pascal(const)
        if gmh.const_to_pascal(const) in label_tileset else None)
    ts = label_tileset.get(label) if label else None
    ts_id = TILESET_IDS.get(ts) if ts else None
    stem = TILESET_CANONICAL[ts_id] if ts_id is not None else None
    return MapInfo(const, map_id, w, h, label, ts, ts_id, stem)


def load_blk(info: MapInfo) -> bytes:
    """The map's raw block grid (w*h bytes) from pret maps/<Pascal>.blk."""
    blk = ROOT / "maps" / f"{info.label}.blk"
    data = blk.read_bytes()
    if len(data) != info.w * info.h:
        raise ValueError(
            f"{blk.name}: {len(data)} bytes != {info.w}x{info.h} blocks")
    return data


def objects(info: MapInfo, debug_warps: bool = False):
    """(border_block, warps, sign_count, sprites) via gmh.parse_object_file;
    None when the map has no objects file."""
    if info.label is None:
        return None
    return gmh.parse_object_file(info.label, debug_warps)
