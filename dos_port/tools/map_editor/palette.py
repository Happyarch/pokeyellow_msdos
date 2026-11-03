"""Overworld palette preview using the port's palette data and map selection."""
from __future__ import annotations

from pathlib import Path

from colors import schema as colors_schema
from gfx_core import palettes, pret_maps as pm
from gfx_core.tiles import ROOT


def resolve(info, last_map: str | None = None):
    """Return palette name, RGB888 colors, and a warning if context is assumed.

    The overworld uses BG slot zero. Interior palettes depend on wLastMap,
    which cannot be inferred from a static map; absent context uses PAL_ROUTE.
    Assumes the normal identity BGP register, not a fade in progress.
    """
    maps = pm._constants()
    number = info.map_id
    warning = None
    if info.tileset_name == 'CEMETERY':
        name = 'PAL_GRAYMON'
    elif info.tileset_name == 'CAVERN':
        name = 'PAL_CAVE'
    elif maps['CERULEAN_CAVE_2F'][0] <= number <= maps['CERULEAN_CAVE_1F'][0] or number == maps['BRUNOS_ROOM'][0]:
        name = 'PAL_CAVE'
    elif number in (maps['TRADE_CENTER'][0], maps['COLOSSEUM'][0]):
        name = 'PAL_GRAYMON'
    else:
        if number == maps['LORELEIS_ROOM'][0]:
            number = maps['PALLET_TOWN'][0]
        elif number >= maps['REDS_HOUSE_1F'][0]:
            if last_map is None:
                warning = 'interior last-map palette unknown; assuming PAL_ROUTE'
                number = maps['SAFFRON_CITY'][0] + 1
            else:
                number = maps[last_map][0]
        pal_id = number + 1 if number <= maps['SAFFRON_CITY'][0] else 0
        enums, _ = palettes.palette_enums()
        name = next(key for key, value in enums.items() if value == pal_id)
    values = palettes.parse_cgb_base_palettes()
    sidecar = ROOT / 'dos_port/assets/colors/palettes.json'
    if sidecar.exists():
        values.update(colors_schema.load(sidecar).pal_overrides)
    return name, [tuple(round(v * 255 / 63) for v in color)
                  for color in values[name]], warning
