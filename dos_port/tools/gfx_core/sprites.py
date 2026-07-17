"""Resolve pret battle-sprite PNG paths for the palette preview tools.

Front/back Pokémon sprites and trainer/player pics live in the read-only pret
tree under filenames that do NOT follow from the species constant by any string
transform (``NIDORAN_F`` -> ``nidoranf``, ``MR_MIME`` -> ``mr.mime`` with a dot).
The only reliable mapping is the one pret itself uses: ``base_stats.asm``'s
``INCLUDE`` order is national-dex order, and each per-species file names its
front ``.pic`` via ``INCBIN``.  This module mirrors ``gen_mon_pics.py`` /
``gen_trainer_pics.py`` so the color editor never guesses a filename — the old
``species.lower()`` guess silently fell back to ``pikachu.png`` for every miss.
"""
from __future__ import annotations

import re
from functools import lru_cache
from pathlib import Path

from .palettes import parse_monster_palettes
from .tiles import ROOT

FRONT_DIR = ROOT / "gfx" / "pokemon" / "front"
BACK_DIR = ROOT / "gfx" / "pokemon" / "back"
TRAINER_DIR = ROOT / "gfx" / "trainers"
PLAYER_FRONT = ROOT / "gfx" / "player" / "red.png"
PLAYER_BACK = ROOT / "gfx" / "player" / "redb.png"

NUM_POKEMON = 151


def _dex_front_stems() -> list[str]:
    """Front-pic stems in national-dex order (dex 1..151), read from pret exactly
    as ``gen_mon_pics.py`` does: base_stats INCLUDE order, then each file's
    front-pic INCBIN."""
    base_stats = ROOT / "data" / "pokemon" / "base_stats.asm"
    files = [
        m.group(1)
        for line in base_stats.read_text().splitlines()
        if (m := re.search(r'INCLUDE\s+"(data/pokemon/base_stats/[^"]+)"', line))
    ]
    if len(files) != NUM_POKEMON:
        raise ValueError(f"expected {NUM_POKEMON} base-stats species, got {len(files)}")
    stems: list[str] = []
    for rel in files:
        text = (ROOT / rel).read_text()
        m = re.search(r'INCBIN\s+"gfx/pokemon/front/([^"]+)\.pic"', text)
        if not m:
            raise ValueError(f"{rel}: no front-pic INCBIN")
        stems.append(m.group(1))
    return stems


@lru_cache(maxsize=1)
def front_stems() -> dict[str, str]:
    """``species_constant -> real front-pic stem`` (e.g. ``NIDORAN_F`` ->
    ``'nidoranf'``, ``MR_MIME`` -> ``'mr.mime'``).

    ``MonsterPalettes`` (dex-ordered, index 0 = MISSINGNO) and ``base_stats.asm``
    (dex 1..151) share national-dex order, so dropping MISSINGNO and zipping the
    two lists positionally is exact.  MISSINGNO has no battle sprite and is
    excluded."""
    species = [s for s in parse_monster_palettes() if s != "MISSINGNO"]
    stems = _dex_front_stems()
    if len(species) != len(stems):
        raise ValueError(f"{len(species)} palette species vs {len(stems)} dex stems")
    return dict(zip(species, stems))


def previewable_species() -> list[str]:
    """Dex-ordered species names that have a real front sprite (drops MISSINGNO)."""
    return list(front_stems())


def front_png(species: str) -> Path | None:
    """Front battle sprite PNG for a species, or ``None`` if unmapped."""
    stem = front_stems().get(species)
    return (FRONT_DIR / f"{stem}.png") if stem else None


def back_png(species: str) -> Path | None:
    """Player-side back sprite PNG (``<stem>b.png``), or ``None`` if unmapped.

    Back sprites are stored 32x32 (half-res) and doubled in-game via
    ``ScaleSpriteByTwo``."""
    stem = front_stems().get(species)
    return (BACK_DIR / f"{stem}b.png") if stem else None


@lru_cache(maxsize=1)
def trainer_pngs() -> list[tuple[str, Path]]:
    """``(label, path)`` for every trainer battle FRONT sprite PNG.

    The player (Red) leads the list: he is the only trainer with a back sprite,
    so in the mock his front pic (enemy slot) pairs with his back (player slot) —
    both shown.  Every enemy trainer that follows has only a front pic (all they
    have), drawn against Red's back.  Enumerated straight from ``gfx/trainers/``
    (real files, readable names); the preview doesn't need pret's class->pic
    aliasing, only the sprites."""
    return [("red (player)", PLAYER_FRONT)] + [
        (p.stem, p) for p in sorted(TRAINER_DIR.glob("*.png"))]


def player_back_png() -> Path:
    """Red's back sprite — the trainer slide-in shown on the player's side at the
    start of a battle (``gfx/player/redb.png``)."""
    return PLAYER_BACK
