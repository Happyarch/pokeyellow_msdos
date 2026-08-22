#!/usr/bin/env python3
"""gen_sgb_packets.py — emit pret's SGB packet blobs as port data.

  assets/sgb_packets.inc      BlkPacket_PartyMenu   (data/sgb/sgb_packets.asm)

WHY ONLY ONE PACKET. The port has no SGB packet SENDER — two sanctioned
DEVIATION{class=HAL} annotations (SetPal_PartyMenu and
LoadOverworldPikachuFrontpicPalettes in src/engine/gfx/palettes.asm) record that
it publishes slot palettes directly instead of assembling and sending packets.
BlkPacket_PartyMenu is the one packet whose BYTES are nonetheless read here:
InitPartyMenuBlkPacket copies it into wPartyMenuBlkPacket, UpdatePartyMenuBlkPacket
overwrites the six HP-bar colour bytes in place, and HandlePartyHPBarAttributes
(src/engine/gfx/bg_map_attributes.asm) reads them back at +9 by stride 6. Adding
another packet here is one line in PACKETS below, but do not add one speculatively.

WHY GENERATED RATHER THAN HAND-TYPED. Two-tier rule: this is Tier-1 static data,
so it must be a deterministic function of the read-only pret source. The bytes
are not even in pret's file literally — they are the expansion of the ATTR_BLK /
ATTR_BLK_DATA macros pret defines at the top of that same file, which is exactly
the kind of arithmetic a human retypes wrong and nobody re-derives. The
generator re-expands them and asserts the resulting length against the size
pret's own consumer copies (`ld bc, $30`).
"""

import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
SRC = os.path.join(ROOT, 'data', 'sgb', 'sgb_packets.asm')
OUT = os.path.join(ROOT, 'dos_port', 'assets', 'sgb_packets.inc')

# label -> the byte count pret's consumer copies, asserted after expansion.
PACKETS = {'BlkPacket_PartyMenu': 0x30}


def num(tok):
    """RGBDS integer literal: %binary, $hex, or decimal (leading zeros are decimal)."""
    tok = tok.strip()
    if tok.startswith('%'):
        return int(tok[1:], 2)
    if tok.startswith('$'):
        return int(tok[1:], 16)
    return int(tok, 10)


def expand(label, lines):
    """Expand one packet body. Mirrors the MACRO definitions in the same pret file:

        ATTR_BLK n          db ($4 << 3) + ((n * 6) / 16 + 1) ; db n
        ATTR_BLK_DATA a,b,c,d,x1,y1,x2,y2
                            db a ; db b + (c << 2) + (d << 4) ; db x1,y1,x2,y2
        ds n, v             n copies of v
    """
    out = bytearray()
    for ln in lines:
        ln = ln.split(';')[0].strip()
        if not ln:
            continue
        op, _, rest = ln.partition(' ')
        args = [a.strip() for a in rest.split(',')] if rest.strip() else []
        if op == 'ATTR_BLK':
            n = num(args[0])
            out += bytes([(0x4 << 3) + ((n * 6) // 16 + 1), n])
        elif op == 'ATTR_BLK_DATA':
            a, b, c, d = (num(x) for x in args[:4])
            x1, y1, x2, y2 = (num(x) for x in args[4:8])
            out += bytes([a, b + (c << 2) + (d << 4), x1, y1, x2, y2])
        elif op == 'ds':
            cnt = num(args[0])
            val = num(args[1]) if len(args) > 1 else 0
            out += bytes([val]) * cnt
        else:
            sys.exit(f"gen_sgb_packets: {label}: unhandled directive {op!r} — "
                     f"teach expand() its macro before adding this packet")
    return bytes(out)


def main():
    text = open(SRC, encoding='utf-8').read().split('\n')
    starts = {}
    for i, ln in enumerate(text):
        m = re.match(r'^([A-Za-z_][A-Za-z0-9_]*):\s*$', ln)
        if m:
            starts[m.group(1)] = i

    chunks = []
    for label, want in PACKETS.items():
        if label not in starts:
            sys.exit(f"gen_sgb_packets: {label} not found in {SRC} "
                     f"(pret renamed it? re-read the file)")
        i = starts[label] + 1
        body = []
        while i < len(text) and not re.match(r'^[A-Za-z_][A-Za-z0-9_]*:\s*$', text[i]):
            body.append(text[i])
            i += 1
        blob = expand(label, body)
        if len(blob) != want:
            sys.exit(f"gen_sgb_packets: {label} expanded to {len(blob)} bytes, "
                     f"expected {want} — the macro definitions in {SRC} changed, "
                     f"or the packet gained a row; re-derive before trusting this")
        rows = '\n'.join('    db ' + ', '.join(f'0x{b:02X}' for b in blob[o:o + 8])
                         for o in range(0, len(blob), 8))
        # _SIZE stays FILE-LOCAL documentation. It is deliberately not global'd:
        # lint_pret_labels scans .asm files, so an extern pointing at the carrier
        # for a symbol only the generated .inc defines reports stale_provider.
        # The consumer uses pret's own literal ($30) instead — pret hardcodes it
        # too — and the assert above is what stops that literal drifting.
        chunks.append(f"global {label}\n{label}:\n{rows}\n"
                      f"{label}_END:\n{label}_SIZE equ {len(blob)}\n")

    with open(OUT, 'w', encoding='utf-8') as fh:
        fh.write("; sgb_packets.inc — generated by tools/generators/gen_sgb_packets.py. "
                 "DO NOT EDIT BY HAND.\n"
                 "; Source: data/sgb/sgb_packets.asm (ATTR_BLK / ATTR_BLK_DATA macros "
                 "expanded per that file's own definitions).\n\n")
        fh.write('\n'.join(chunks))
    print(f"gen_sgb_packets: wrote {OUT} "
          f"({', '.join(f'{k} {v}B' for k, v in PACKETS.items())})")


if __name__ == '__main__':
    main()
