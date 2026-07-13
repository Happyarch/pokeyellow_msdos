"""PNG <-> GB 2bpp repaint interchange with CGB-style per-tile palettes."""
from __future__ import annotations

from pathlib import Path
from PIL import Image, PngImagePlugin

from gfx_core.tiles import ROOT
from . import schema
from .render import species_png

ASSETS = ROOT / "dos_port" / "assets" / "colors"
REPAINT = ASSETS / "repaint"


def _asset(asset: str) -> tuple[str, str]:
    stem = asset.lower().removesuffix(".png")
    if not stem.endswith("_front"):
        stem += "_front"
    return stem, stem[:-6].upper()


def _palette_for_species(sidecar: schema.Sidecar, species: str):
    from gfx_core import palettes
    source = palettes.parse_monster_palettes()[species]
    override = sidecar.species_overrides.get(species, {})
    if "colors" in override:
        return override["colors"]
    pal = override.get("pal", source)
    return sidecar.pal_overrides.get(pal, palettes.parse_cgb_base_palettes()[pal])


def export_png(asset: str, sidecar: schema.Sidecar, destination: Path | None = None) -> Path:
    stem, species = _asset(asset)
    existing = sidecar.repaint.get(stem.upper(), {}).get("png")
    if destination is None and existing:
        path = ASSETS / existing
        if path.exists():
            # The editor-authored indexed PNG is the repaint source of truth;
            # returning it untouched makes export→import→export byte-stable.
            return path
    src = species_png(species)
    pal = _palette_for_species(sidecar, species)
    out = Image.new("P", src.size)
    table = []
    for rgb in pal:
        table += [v * 255 // 63 for v in rgb]
    out.putpalette(table + [0] * (768 - len(table)))
    for y in range(src.height):
        for x in range(src.width):
            out.putpixel((x, y), 3 - min(3, round(src.getpixel((x, y)) / 85)))
    path = destination or REPAINT / f"{stem}.png"
    path.parent.mkdir(parents=True, exist_ok=True)
    info = PngImagePlugin.PngInfo(); info.add_text("pokeyellow_asset", stem)
    info.add_text("pokeyellow_shade_order", "0,1,2,3")
    out.save(path, pnginfo=info)
    return path


def _rgb(img: Image.Image, x: int, y: int) -> tuple[int, int, int]:
    return tuple(img.convert("RGB").getpixel((x, y)))


def _sixbit(rgb: tuple[int, int, int]) -> tuple[int, int, int]:
    return tuple(round(v * 63 / 255) for v in rgb)


def import_png(path: str | Path, sidecar: schema.Sidecar,
               sidecar_path: Path | None = None, destination: Path | None = None) -> str:
    path = Path(path)
    img = Image.open(path)
    if img.width % 8 or img.height % 8:
        raise ValueError(f"{path}: dimensions must be multiples of 8")
    stem = img.info.get("pokeyellow_asset", path.stem)
    stem, _ = _asset(stem)
    rgb = img.convert("RGB")
    indexed = img.mode == "P" and max(img.getdata(), default=0) < 4
    indexed_colors = []
    if indexed:
        raw = img.getpalette()
        indexed_colors = [tuple(round(raw[i * 3 + c] * 63 / 255) for c in range(3))
                          for i in range(4)]
    palettes: list[list[tuple[int, int, int]]] = []
    tile_pal: list[int] = []
    packed = bytearray()
    for ty in range(0, img.height, 8):
        for tx in range(0, img.width, 8):
            colors = list(indexed_colors) if indexed else []
            if not indexed:
                for y in range(8):
                    for x in range(8):
                        color = _sixbit(rgb.getpixel((tx + x, ty + y)))
                        if color not in colors: colors.append(color)
            if len(colors) > 4:
                raise ValueError(f"{path}: tile ({tx // 8},{ty // 8}) has {len(colors)} colors (max 4)")
            # Indexed export preserves shades 0..3. For arbitrary RGB input,
            # first occurrence is deterministic and directly represents paint order.
            key = colors + [colors[-1]] * (4 - len(colors))
            if key not in palettes:
                if len(palettes) == 4:
                    raise ValueError(f"{path}: asset uses more than 4 tile palettes")
                palettes.append(key)
            p = palettes.index(key); tile_pal.append(p)
            lookup = {color: i for i, color in enumerate(key)}
            for y in range(8):
                lo = hi = 0
                for x in range(8):
                    shade = img.getpixel((tx + x, ty + y)) if indexed else \
                        lookup[_sixbit(rgb.getpixel((tx + x, ty + y)))]
                    lo |= (shade & 1) << (7 - x); hi |= (shade >> 1) << (7 - x)
                packed += bytes((lo, hi))
    out_2bpp = destination or REPAINT / f"{stem}.2bpp"
    out_2bpp.parent.mkdir(parents=True, exist_ok=True); out_2bpp.write_bytes(packed)
    rel = f"colors/repaint/{stem}"
    sidecar.repaint[stem.upper()] = {"png": rel + ".png", "tile_pal": tile_pal,
                                    "extra_palettes": palettes,
                                    "override_2bpp": rel + ".2bpp"}
    schema.save(sidecar, sidecar_path or ASSETS / "palettes.json")
    return stem.upper()
