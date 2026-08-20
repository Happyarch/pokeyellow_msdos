"""Port-side horizontal map expansion — the single source of the rule.

WHY THIS EXISTS. The S.S. Anne departure cutscene (scripts/VermilionDock.asm)
works by walking the BG's sampling window EAST while the camera stays put: pret
advances wMapViewVRAMPointer by 2 tiles per pass and calls
ScheduleEastColumnRedraw to keep feeding the columns that scroll in. The ship
never moves in the map -- the window moves out from under it.

On the Game Boy that walk is 4 blocks and VermilionDock's 14 columns cover it.
The port's viewport is 40 tiles wide instead of 20, so the ship starts 8 blocks
further from the left edge and the walk must be 8 blocks. That runs past the
map's east boundary, and LoadCurrentMapView's range check (home/overworld.asm)
answers an out-of-map read with wMapBackgroundTile -- the map's BORDER block,
$0F here, not sea. The water behind the departing ship would be a stream of
border blocks.

So the map is given real cells to be sampled from. This is a PORT-SIDE data
expansion: pret's maps/*.blk and constants/map_constants.asm are never written,
so the ROM the golden harness runs stays the real game.

ONE RULE, TWO DERIVATIONS. The width reaches the port through
gen_map_headers.parse_map_constants() (which feeds assets/map_dims.inc's
<MAP>_WIDTH and the map-header blob) and the bytes reach it through
gen_all_assets' per-.blk loop. Both read THIS module, because the failure mode
of splitting them is silent: a blob laid out 22 columns wide behind a header
that says 14 renders as garbage with nothing to fault on.

DEVIATION{class=data-model; pret=constants/map_constants.asm:VERMILION_DOCK; behavior=the port's VERMILION_DOCK is widened east from 14 to 22 block columns by repeating the open-sea column, so the S.S. Anne departure's eastward view walk samples real map cells instead of the border block; evidence=the port's 40-tile viewport puts the ship 8 blocks from the left edge against the GB's 0 so the walk is 8 blocks instead of 4 and LoadCurrentMapView answers an out-of-map read with wMapBackgroundTile which is $0F not sea, and the expansion is generated from pret's own .blk at build time so pret's map data stays read-only; lifetime=permanent, a consequence of the widened viewport}
"""

# Blocks the departure scroll must travel for the ship to clear the port's left
# screen edge: the ship sits at screen columns 16..31 of 40, so 32 tile columns
# = 256 px = 8 blocks. (The GB needs 4: its ship starts flush with the edge.)
DEPARTURE_SCROLL_BLOCKS = 8

# Blocks the decode surface spans (SCREEN_BLOCK_WIDTH in include/gb_memmap.inc).
# Duplicated here rather than parsed because the assert below is the only use and
# a mismatch is caught by it, loudly, at generation time.
SCREEN_BLOCK_WIDTH = 12

# map const -> (columns added at the east edge, source column, row overrides).
#
# The source column is an interior column, not the edge column: the edge column
# stays the edge and copies of the source are inserted before it. For
# VermilionDock, column 12 is `0c/01/0d/0d/0d/12` and column 13 is the boundary.
#
# ROW OVERRIDES exist because a verbatim duplicate would extend the PIER. Column
# 12's row 1 is $01, the dock walkway the player stands on; repeating it eight
# times builds eight blocks of pier over open water. The cutscene itself would
# not notice (the joypad is ignored throughout), but the player comes back to
# this map afterwards, and that is walkable space pret does not have -- a
# gameplay divergence smuggled in by a rendering fix. The truthful extension is
# that the pier ENDS and open sea continues, so row 1 is forced to the water
# block $0D like the rows beneath it.
EXPANSIONS = {
    "VERMILION_DOCK": (DEPARTURE_SCROLL_BLOCKS, 12, {1: 0x0D}),
}


def expanded_dims(const, w, h):
    """(w, h) the PORT uses for `const`. Identity for every unexpanded map."""
    if const not in EXPANSIONS:
        return w, h
    east = EXPANSIONS[const][0]
    new_w = w + east
    # The walk needs the surface's east edge to stay inside the map for the whole
    # scroll. Assert it rather than trust the arithmetic in the comment above.
    need = SCREEN_BLOCK_WIDTH + DEPARTURE_SCROLL_BLOCKS
    if new_w < need:
        raise ValueError(
            f"map_expansion: {const} widened to {new_w} blocks, but the "
            f"departure walk needs at least {need} "
            f"(SCREEN_BLOCK_WIDTH {SCREEN_BLOCK_WIDTH} + "
            f"DEPARTURE_SCROLL_BLOCKS {DEPARTURE_SCROLL_BLOCKS}).")
    return new_w, h


def expand_blk(const, data, w, h):
    """Widen `data` (row-major, w bytes per row, h rows) per the rule above.

    Returns the bytes unchanged for any map with no expansion entry.
    """
    if const not in EXPANSIONS:
        return bytes(data)
    east, src_col, row_overrides = EXPANSIONS[const]
    if len(data) != w * h:
        raise ValueError(
            f"map_expansion: {const} .blk is {len(data)} bytes, expected "
            f"{w}*{h}={w * h}. Refusing to guess the row stride.")
    if not 0 <= src_col < w - 1:
        raise ValueError(
            f"map_expansion: {const} source column {src_col} is not an interior "
            f"column of a {w}-wide map.")
    out = bytearray()
    for r in range(h):
        row = data[r * w:(r + 1) * w]
        fill = row_overrides.get(r, row[src_col])
        out += row[:w - 1] + bytes([fill]) * east + row[w - 1:w]
    return bytes(out)
