#!/usr/bin/env python3
"""Decode SEAMLOG.BIN, the DEBUG_SEAM harness trace.

One 12-byte record per rendered frame while the harness walks the player into a
map connection. Prints the trace and flags the two invariants that matter:

  1. VIEW-POINTER LOCKSTEP. wCurrentTileBlockMapViewPointer must equal the value
     the coords imply, for the CURRENT map's width:
         stride   = width + 2*MAP_BORDER
         view_row = (y>>1) + MAP_BORDER - SCREEN_BLOCK_HEIGHT//2
         view_col = (x>>1) + MAP_BORDER - SCREEN_BLOCK_WIDTH//2
         ptr      = wOverworldMap + view_row*stride + view_col
     A mismatch means the camera and the player disagree — the map appears to jump
     while the player sits on the wrong tile.

  2. COORDINATE LEGALITY. 0 <= x < 2*width and 0 <= y < 2*height on the current map.
     An out-of-range coord is the "player is on an illegal tile" symptom directly.

Usage:  tools/read_seamlog.py SEAMLOG.BIN
"""
import sys
import struct

MAP_BORDER = 6
SCREEN_BLOCK_WIDTH = 12
SCREEN_BLOCK_HEIGHT = 9
W_OVERWORLD_MAP = 0xE800

REC = 12


def expected_ptr(x, y, width):
    stride = width + 2 * MAP_BORDER
    row = (y >> 1) + MAP_BORDER - SCREEN_BLOCK_HEIGHT // 2
    col = (x >> 1) + MAP_BORDER - SCREEN_BLOCK_WIDTH // 2
    return (W_OVERWORLD_MAP + row * stride + col) & 0xFFFF


def main(path):
    data = open(path, "rb").read()
    if len(data) % REC:
        print(f"warning: {len(data)} bytes is not a multiple of {REC}", file=sys.stderr)
    n = len(data) // REC
    print(f"{n} frames\n")
    hdr = ("frame map    x    y walk   viewptr    exp  w  h  scx  scy "
           "oamY oamX  notes")
    print(hdr)
    print("-" * len(hdr))

    prev_map = None
    bad_ptr = bad_coord = 0
    for i in range(n):
        (cmap, x, y, walk, plo, phi, w, h,
         scx, scy, oy, ox) = struct.unpack_from("12B", data, i * REC)
        ptr = plo | (phi << 8)
        exp = expected_ptr(x, y, w) if w else 0

        notes = []
        if prev_map is not None and cmap != prev_map:
            notes.append(f"*** CROSSED {prev_map:#04x} -> {cmap:#04x}")
        prev_map = cmap

        # ROW WRAP. The view pointer is a flat offset, so its column is ptr % stride.
        # MAP_BORDER(6) == SCREEN_BLOCK_WIDTH//2(6) leaves ZERO horizontal slack, so a
        # west step at x=0 decrements column 0 into the previous row's last column.
        # Check this BEFORE the "pointer leads" excuse below — that excuse is exactly
        # what hid this bug: at x=0 the "lead of -1" IS the wrap.
        if w:
            stride = w + 2 * MAP_BORDER
            col = (ptr - W_OVERWORLD_MAP) % stride
            exp_col = (exp - W_OVERWORLD_MAP) % stride
            if abs(ptr - exp) <= 2 and abs(col - exp_col) > 2:
                notes.append(f"*** VIEW-PTR ROW WRAP (col {exp_col} -> {col})")
                bad_ptr += 1
                wrapped = True
            else:
                wrapped = False

        # Otherwise the pointer legitimately LEADS the coords: MoveTileBlockMapPointer*
        # fires at step start, wXCoord/wYCoord update at step end. A +/-1 delta mid-step
        # is normal; only a mismatch at rest (walk == 0) is a desync.
        if w and ptr != exp and not wrapped:
            if walk == 0:
                notes.append(f"PTR MISMATCH AT REST (off by {ptr - exp:+d})")
                bad_ptr += 1
            else:
                notes.append(f"(ptr leads by {ptr - exp:+d}, mid-step)")
        if w and h and not (0 <= x < 2 * w and 0 <= y < 2 * h):
            notes.append(f"COORD OOB (valid x<{2*w} y<{2*h})")
            bad_coord += 1
        if oy == 0:
            notes.append("player OAM hidden")

        print(f"{i:5d} {cmap:#04x} {x:4d} {y:4d} {walk:4d}  "
              f"{ptr:#06x} {exp:#06x} {w:2d} {h:2d} {scx:4d} {scy:4d} "
              f"{oy:4d} {ox:4d}  {'; '.join(notes)}")

    print()
    print(f"view-pointer lockstep violations : {bad_ptr}")
    print(f"out-of-range player coordinates  : {bad_coord}")
    return 1 if (bad_ptr or bad_coord) else 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(2)
    sys.exit(main(sys.argv[1]))
