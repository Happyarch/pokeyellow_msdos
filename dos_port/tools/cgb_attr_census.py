#!/usr/bin/env python3
"""Stage 0 collision census, re-derived as a reusable script.

THE QUESTION: for one screen, can its per-CELL CGB attribute plane be
re-expressed per TILE ID?  It can iff no tile id appears under two palettes
that differ at a colour index that tile actually uses.

INPUTS, all measured, none assumed:
  * the screen's BGMapAttributes_<Screen> table   -> per-cell palette slot
  * the golden's wTileMap (20x18)                 -> per-cell tile id
  * the golden's vram_tiles ($8000, $1800)        -> tile pixels
  * PalPacket_<Screen> + CGBBasePalettes          -> slot -> RGB

SELF-CHECKS (a census that cannot fail is not a measurement):
  * signed BG addressing is verified by decoding $7F, which must be all-zero
    (LCDC_BLOCK21 is in LCDC_DEFAULT; unsigned addressing fails this).
  * --selftest injects a synthetic collision and asserts it is reported.

Usage:
  census.py --screen Slots --golden <dir-with-name.bin/.json>
  census.py --screen Slots --golden <dir> --selftest
"""
import argparse, json, pathlib, re, sys

REPO = pathlib.Path.cwd().resolve()
while REPO.name and not (REPO / "constants" / "palette_constants.asm").exists():
    REPO = REPO.parent
if not REPO.name:
    sys.exit("census: run me from inside the pret repo (cwd has no constants/)")


def _lines(rel):
    return (REPO / rel).read_text().splitlines()


def pal_constants():
    """PAL_* name -> numeric value, from the const_def run in palette_constants.asm."""
    out, val = {}, None
    for ln in _lines("constants/palette_constants.asm"):
        s = ln.strip()
        # `const_def` may be bare (start at 0) or carry a start value, so the
        # whitespace is OPTIONAL -- requiring it parsed ZERO constants silently.
        m = re.match(r"const_def(?:\s+\$?([0-9A-Fa-f]+))?\s*$", s)
        if m:
            val = int(m.group(1), 16) if m.group(1) else 0
            continue
        m = re.match(r"const\s+(\w+)", s)
        if m and val is not None:
            out[m.group(1)] = val
            val += 1
    return out


def base_palettes():
    """CGBBasePalettes -> list of 4x(r,g,b) rows, 5-bit components."""
    rows, started = [], False
    for ln in _lines("data/sgb/sgb_palettes.asm"):
        s = ln.strip()
        if s.startswith("CGBBasePalettes:"):
            started = True
            continue
        if not started:
            continue
        if s.startswith("SGBBasePalettes") or re.match(r"^\w+::?$", s):
            break
        m = re.match(r"RGB\s+([^;]+)", s)
        if not m:
            continue
        # ONE `RGB` line is a whole palette: 4 colours x 3 components = 12 ints.
        n = [int(x.strip()) for x in m.group(1).split(",")]
        assert len(n) == 12, f"census: RGB line has {len(n)} values, expected 12: {s}"
        rows.append([tuple(n[i * 3:i * 3 + 3]) for i in range(4)])
    return rows


def pal_packet(screen):
    """PalPacket_<screen> -> the four PAL_* slot numbers."""
    consts = pal_constants()
    for ln in _lines("data/sgb/sgb_packets.asm"):
        m = re.match(rf"PalPacket_{screen}:\s*PAL_SET\s+(.+)$", ln.strip(), re.I)
        if m:
            out = []
            for tok in m.group(1).split(","):
                tok = tok.strip()
                out.append(consts[tok] if tok in consts else int(tok, 0))
            return out
    sys.exit(f"census: no PalPacket_{screen} in data/sgb/sgb_packets.asm")


def attr_table(screen):
    """BGMapAttributes_<screen> -> 18 rows x 32 cols of attribute bytes.

    Header per the plan's derived format: base+0 count, base+1..2 LE offset,
    base+3..15 padding, base+16 payload.  Payload is 32 bytes per row.
    """
    body, started = [], False
    for ln in _lines("data/cgb/bg_map_attributes.asm"):
        s = ln.strip()
        if s.startswith(f"BGMapAttributes_{screen}:"):
            started = True
            continue
        if not started:
            continue
        if re.match(r"^BGMapAttributes_\w+:", s):
            break
        m = re.match(r"db\s+(.+)$", s)
        if m:
            body += [int(x.strip().lstrip("$"), 16) for x in m.group(1).split(",")]
        elif re.match(r"dw\s+", s):
            v = int(s.split()[1].lstrip("$"), 16)
            body += [v & 0xFF, v >> 8]
    payload = body[16:]
    rows = [payload[i * 32:(i + 1) * 32] for i in range(18)]
    assert all(len(r) == 32 for r in rows), "census: attribute payload short"
    return rows


def load_golden(gdir, name):
    gdir = pathlib.Path(gdir)
    blob = (gdir / f"{name}.bin").read_bytes()
    meta = json.loads((gdir / f"{name}.json").read_text())
    regions = {}
    for r in meta["regions"]:
        o = r["file_offset"]
        regions[r["name"]] = blob[o:o + r["size"]]
    return regions


def decode_tile(vram, tid):
    """Signed BG addressing: id 0..127 -> $9000, 128..255 -> $8800.
    vram is the $8000-based blob, so subtract $8000 from the address."""
    base = (0x9000 + tid * 16) if tid < 128 else (0x8800 + (tid - 128) * 16)
    off = base - 0x8000
    px = []
    for row in range(8):
        lo, hi = vram[off + row * 2], vram[off + row * 2 + 1]
        for bit in range(7, -1, -1):
            px.append(((hi >> bit) & 1) * 2 | ((lo >> bit) & 1))
    return px


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--screen", required=True)
    ap.add_argument("--golden", required=True)
    ap.add_argument("--name", help="golden basename (default: lowercased screen)")
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()

    name = a.name or a.screen.lower()
    g = load_golden(a.golden, name)
    tilemap, vram = g["wTileMap"], g["vram_tiles"]

    # --- self-check: signed addressing.  $7F is the charmap space; it must be
    # all-colour-0.  Under unsigned addressing this fails on almost every golden.
    space = decode_tile(vram, 0x7F)
    if any(space):
        print("census: WARNING — tile $7F is not blank; signed-addressing "
              "assumption may be wrong for this golden", file=sys.stderr)
    else:
        print("  self-check: tile $7F decodes all-zero (signed addressing OK)")

    attrs = attr_table(a.screen)
    slots = pal_packet(a.screen)
    base = base_palettes()
    rgb = [base[s] for s in slots]          # slot -> 4 colours
    print(f"  PalPacket_{a.screen} slots = {slots}")

    # --- per tile id, the set of palette slots it appears under
    seen = {}
    for row in range(18):
        for col in range(20):
            tid = tilemap[row * 20 + col]
            pal = attrs[row][col] & 0x07
            seen.setdefault(tid, set()).add(pal)

    if a.selftest:
        # Inject a synthetic collision: force a tile that HAS pixels to appear
        # under two slots whose RGB differ.  If the census reports zero after
        # this, the census is broken.
        victim = next((t for t in sorted(seen) if any(decode_tile(vram, t))), None)
        assert victim is not None, "census selftest: no non-blank tile on screen"
        seen[victim] = {0, 1, 2, 3}
        print(f"  SELFTEST: forced tile ${victim:02X} under slots 0-3")

    raw = {t: p for t, p in seen.items() if len(p) > 1}
    real = {}
    for tid, pals in raw.items():
        px = set(decode_tile(vram, tid))
        differ = set()
        pl = sorted(pals)
        for i in range(len(pl)):
            for j in range(i + 1, len(pl)):
                for ci in px:
                    if rgb[pl[i]][ci] != rgb[pl[j]][ci]:
                        differ.add((pl[i], pl[j], ci))
        if differ:
            real[tid] = (pl, sorted(px), sorted(differ))

    print(f"\n  raw collisions (>1 palette):        {len(raw)}"
          f"  -> {[f'${t:02X}' for t in sorted(raw)]}")
    print(f"  REAL collisions (differ at a used colour index): {len(real)}")
    for tid, (pl, px, differ) in sorted(real.items()):
        print(f"    ${tid:02X}: slots {pl}, colour indices used {px}")
        for i, j, ci in differ:
            print(f"        slot {i} vs {j} at colour {ci}: "
                  f"{rgb[i][ci]} != {rgb[j][ci]}")

    if a.selftest:
        ok = len(real) > 0
        print(f"\n  SELFTEST {'PASS' if ok else 'FAIL'} — census "
              f"{'does' if ok else 'does NOT'} report an injected collision")
        return 0 if ok else 1

    print(f"\n  VERDICT: {a.screen} is "
          f"{'CLEAN — expressible per tile ID' if not real else str(len(real)) + ' tile(s) NEED per-cell'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
