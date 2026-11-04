"""Connection-assembly geometry, checked against the runtime strip copy.

`compose_padded` already reproduces what `LoadNorthSouth/EastWestConnectionsTileMap`
writes into the border ring. The connection view must place whole neighbouring
maps at the SAME relative offset, so the two are compared cell-for-cell here: if
`neighbour_origin` drifted, the assembled map would disagree with the strips the
runtime actually draws.
"""
import sys
from pathlib import Path
import unittest
from tempfile import TemporaryDirectory
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from gfx_core import pret_maps as pm
from map_editor import view, schema, commands

MAPS = ("PALLET_TOWN", "ROUTE_1", "VIRIDIAN_CITY", "ROUTE_2")


class ConnectionAssemblyTest(unittest.TestCase):
    def test_assembled_neighbours_agree_with_runtime_strips(self):
        checked = 0
        for const in MAPS:
            padded = view.compose_padded(const)
            assembled = view.compose_connections(const)
            by_const = {e['const']: e for e in assembled.neighbours}
            for direction, nconst, offset in pm.CONNECTIONS.get(const, []):
                entry = by_const.get(nconst)
                if entry is None:
                    continue  # skipped: tileset mismatch or unusable map
                ninfo = pm.map_info(nconst)
                conn = pm.get_connection(direction, ninfo.map_id, offset,
                                         padded.info.w, padded.info.h,
                                         ninfo.w, ninfo.h)
                src, dst = conn["blk"], conn["map"]
                dst_row, dst_col = divmod(dst, padded.stride)
                src_row, src_col = divmod(src, ninfo.w)
                if direction in ("NORTH", "SOUTH"):
                    span = [(r, i) for r in range(view.BORDER)
                            for i in range(conn["len"])]
                else:
                    span = [(r, i) for r in range(conn["len"])
                            for i in range(view.BORDER)]
                nr, nc = entry['canvas_origin']
                for r, i in span:
                    strip_index = dst + r * padded.stride + i
                    if not 0 <= strip_index < len(padded.grid):
                        continue
                    # The strip cell's padded position is (dst_row + r, dst_col + i);
                    # convert that to a neighbour cell through the padded-relative
                    # origin, then index the shifted canvas.
                    row = (dst_row + r) - entry['origin'][0]
                    col = (dst_col + i) - entry['origin'][1]
                    if not (0 <= row < entry['h'] and 0 <= col < entry['w']):
                        continue
                    asm_index = (nr + row) * assembled.stride + (nc + col)
                    self.assertEqual(
                        padded.grid[strip_index], assembled.grid[asm_index],
                        f"{const} {direction}->{nconst} offset {offset} "
                        f"strip cell (row {r}, col {i}) disagrees with assembly")
                    checked += 1
        self.assertGreater(checked, 500, "the comparison must actually cover cells")

    def test_own_map_blocks_land_at_the_expected_origin(self):
        cv = view.compose_connections("PALLET_TOWN")
        info = cv.info
        padded = view.compose_padded("PALLET_TOWN")
        r0, c0 = cv.origin
        for y in range(info.h):
            for x in range(info.w):
                asm = cv.grid[(r0 + y) * cv.stride + (c0 + x)]
                pad = padded.grid[(y + view.BORDER) * padded.stride
                                  + (x + view.BORDER)]
                self.assertEqual(asm, pad, f"own block ({y},{x})")

    def test_tileset_mismatch_is_reported_not_drawn(self):
        for const in pm.all_map_consts():
            if not pm.CONNECTIONS.get(const):
                continue
            cv = view.compose_connections(const)
            for note in cv.anomalies:
                self.assertIn("tileset", note.lower() + " " + note)
            break

    def test_assembly_writes_nothing(self):
        """Neighbours are rendered, never edited: composing must not touch disk."""
        def snapshot():
            root = pm.ROOT
            out = {}
            for base in (root / "maps", root / "data" / "maps" / "objects"):
                for path in sorted(base.rglob("*")):
                    if path.is_file():
                        stat = path.stat()
                        out[str(path)] = (stat.st_mtime_ns, stat.st_size)
            return out

        before = snapshot()
        for const in ("PALLET_TOWN", "ROUTE_1", "VIRIDIAN_CITY"):
            view.compose_connections(const)
        self.assertEqual(before, snapshot(),
                         "compose_connections must be read-only")

    def test_expanding_this_map_moves_the_neighbours(self):
        """A grown map must re-assemble: get_connection is called with its size."""
        base = view.compose_connections("PALLET_TOWN")
        south_before = next(e for e in base.neighbours
                            if e['direction'] == "SOUTH")
        with TemporaryDirectory() as directory:
            root = Path(directory)
            with patch.object(schema, "OVERRIDES", root / "overrides"), \
                 patch.object(schema, "ROOT", root):
                commands.set_extents("PALLET_TOWN", north=0, west=0,
                                     south=3, east=0, write=True)
                grown = view.compose_connections("PALLET_TOWN")
        south_after = next(e for e in grown.neighbours
                           if e['direction'] == "SOUTH")
        self.assertEqual(grown.info.h, base.info.h + 3)
        # Route 21 sits below this map, so a taller map pushes it down 3 blocks.
        self.assertEqual(south_after['origin'][0], south_before['origin'][0] + 3)
        self.assertEqual(grown.rows, base.rows + 3)
        pm._constants.cache_clear()
        pm.map_info.cache_clear()


if __name__ == "__main__":
    unittest.main()
