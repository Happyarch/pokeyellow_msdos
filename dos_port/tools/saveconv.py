#!/usr/bin/env python3
"""
saveconv.py — Game Boy .sav ↔ DOS .dsv save file converter.

Usage:
    saveconv.py --verify save.dsv                 # validate header + checksum
    saveconv.py --info   save.dsv                 # alias of --verify
    saveconv.py --to-dos  input.sav  output.dsv   # GB SRAM dump → DOS save
    saveconv.py --to-gb   input.dsv  output.sav   # DOS save → GB SRAM dump

Conversion is lossless and exactly invertible: under v2 the payload IS the raw
.sav, so --to-dos prepends the 7-byte header and --to-gb validates and strips
it. `--to-dos X.sav Y.dsv && --to-gb Y.dsv Z.sav` reproduces X byte for byte.

.dsv format — version 2 (raw SRAM image, written by src/save/dsv_io.asm):
    Offset  Size   Description
    0x00    4      Magic: b'DOSV'
    0x04    1      Format version (currently 2)
    0x05    2      16-bit ADDITIVE checksum of the payload, little-endian
    0x07    32768  Payload: the raw emulated SRAM image, bank 0 first —
                   the same bank order as a real MBC5 .sav:
                     bank 0  sSpriteBuffer0/1/2, sHallOfFame
                     bank 1  sGameData (name/main/sprite/party/current box) + checksum
                     bank 2  sBox1..sBox6  + all-box and per-box checksums
                     bank 3  sBox7..sBox12 + all-box and per-box checksums
                   Total file = 32775 bytes.

Version 1 — a five-WRAM-block payload with no other-box or HoF banks — is retired
with NO migration path: it predates the port emulating SRAM, and a pre-release
project has no save files worth converting. A v1 file fails dsv_io's version
check and reads as "no save".

Because v2 IS a faithful bank image, .sav <-> .dsv conversion is now a header
strip plus a checksum recompute, not a WRAM-layout translation.

Checksum: sum of every payload byte, modulo 2^16, stored LE. NOT a CRC — matched
to what dsv_io.asm actually computes.

--verify checks exactly what src/save/dsv_io.asm:SramLoadImage checks before it
scatters a file back into the SRAM banks (full length, magic, version, checksum),
so a file this mode accepts is a file the port will load, and a file it rejects is
one the port treats as absent. It deliberately does NOT interpret the payload:
the bank layout is owned by gb_memmap.inc and ram/sram.asm, and re-deriving it
here would be a second copy to drift.
"""

import argparse
import struct
import sys
from pathlib import Path

DOSV_MAGIC = b'DOSV'
DOSV_VERSION = 2
DSV_HEADER_SIZE = 7           # magic(4) + version(1) + additive checksum(2)
SAV_SIZE = 32768              # raw GB SRAM = the v2 payload, byte for byte
DSV_PAYLOAD_SIZE = SAV_SIZE
DSV_TOTAL_SIZE = DSV_HEADER_SIZE + DSV_PAYLOAD_SIZE

MAGIC_OFFSET = 0
VERSION_OFFSET = 4
CHECKSUM_OFFSET = 5
PAYLOAD_OFFSET = DSV_HEADER_SIZE


def fail(path, message):
    """Report a validation failure on `path` and exit 1 (SystemExit → stderr)."""
    sys.exit(f"saveconv.py: {path}: {message}")


def payload_checksum(payload):
    """16-bit additive checksum: sum of every payload byte, mod 2^16.

    Mirrors dsv_io.asm:dsv_checksum, which accumulates with `add ax, dx` over
    PAYLOAD_TOTAL bytes and so wraps at 16 bits. Not a CRC.
    """
    return sum(payload) & 0xFFFF


def read_file(path):
    try:
        return Path(path).read_bytes()
    except OSError as exc:
        fail(path, f"cannot read file: {exc.strerror or exc}")


def write_file(path, data):
    try:
        Path(path).write_bytes(data)
    except OSError as exc:
        fail(path, f"cannot write file: {exc.strerror or exc}")


def validate_dsv(path, data):
    """Run SramLoadImage's checks, in its order, over an in-memory .dsv.

    Returns (payload, version, stored_checksum, computed_checksum); exits 1 on
    the first thing that does not match. Shared by --verify and --to-gb so the
    two can never disagree about what a loadable file is.
    """
    # 1. Total size. Checked first so a truncated/padded file is named as such
    #    rather than surfacing as a downstream magic/checksum error.
    if len(data) != DSV_TOTAL_SIZE:
        # A bare 32 KB input is a GB .sav (the v2 payload without the header) —
        # by far the likeliest way to reach this branch, and worth naming rather
        # than leaving the reader to recognise the number.
        hint = (" — this is a raw GB .sav: the same bytes as a v2 payload, but "
                "without the 7-byte header; convert it with --to-dos"
                ) if len(data) == SAV_SIZE else ""
        fail(path, f"bad file size: expected {DSV_TOTAL_SIZE} bytes "
                   f"({DSV_HEADER_SIZE}-byte header + "
                   f"{DSV_PAYLOAD_SIZE}-byte version-{DOSV_VERSION} payload), "
                   f"found {len(data)}{hint}")

    # 2. Magic.
    magic = data[MAGIC_OFFSET:MAGIC_OFFSET + len(DOSV_MAGIC)]
    if magic != DOSV_MAGIC:
        fail(path, f"bad magic at offset 0x00: expected {DOSV_MAGIC!r} "
                   f"({DOSV_MAGIC.hex(' ')}), found {magic!r} ({magic.hex(' ')})")

    # 3. Version byte.
    version = data[VERSION_OFFSET]
    if version != DOSV_VERSION:
        fail(path, f"unsupported format version at offset 0x04: expected "
                   f"{DOSV_VERSION}, found {version} (this tool only knows "
                   f"version {DOSV_VERSION})")

    # 4. Additive checksum over the opaque payload.
    stored, = struct.unpack_from('<H', data, CHECKSUM_OFFSET)
    payload = data[PAYLOAD_OFFSET:]
    computed = payload_checksum(payload)
    if computed != stored:
        fail(path, f"checksum mismatch over the {len(payload)}-byte payload: "
                   f"stored 0x{stored:04X} ({stored}) at offset 0x05, "
                   f"recomputed 0x{computed:04X} ({computed})")

    return payload, version, stored, computed


def build_dsv(payload):
    """Wrap a raw 32768-byte SRAM image in the 7-byte v2 header.

    The inverse of stripping it: dsv_io.asm writes exactly this layout, so a
    file built here is one SramLoadImage accepts.
    """
    return (DOSV_MAGIC
            + bytes([DOSV_VERSION])
            + struct.pack('<H', payload_checksum(payload))
            + payload)


def to_dos(in_path, out_path):
    """GB .sav → DOS .dsv: prepend the header. The payload IS the .sav."""
    payload = read_file(in_path)
    if len(payload) != SAV_SIZE:
        hint = (" — this is already a .dsv; use --to-gb for the reverse"
                ) if len(payload) == DSV_TOTAL_SIZE else ""
        fail(in_path, f"bad file size: a raw GB .sav is {SAV_SIZE} bytes, "
                      f"found {len(payload)}{hint}")

    data = build_dsv(payload)
    # Cheap self-check: the file we are about to write must pass the very checks
    # the port applies before it loads one.
    validate_dsv(out_path, data)
    write_file(out_path, data)

    stored, = struct.unpack_from('<H', data, CHECKSUM_OFFSET)
    print(f"OK: {in_path} → {out_path}")
    print(f"  wrote                 {len(data)} bytes "
          f"({DSV_HEADER_SIZE} header + {len(payload)} payload)")
    print(f"  version               {DOSV_VERSION}")
    print(f"  checksum              0x{stored:04X} ({stored})")


def to_gb(in_path, out_path):
    """DOS .dsv → GB .sav: validate, then strip the header."""
    data = read_file(in_path)
    payload, version, stored, _ = validate_dsv(in_path, data)
    write_file(out_path, payload)

    print(f"OK: {in_path} → {out_path}")
    print(f"  read                  {len(data)} bytes "
          f"(valid version-{version} .dsv, checksum 0x{stored:04X})")
    print(f"  wrote                 {len(payload)} bytes (raw GB SRAM image)")


def verify(path):
    """Validate one .dsv file. Prints a summary and returns on success; exits 1
    on the first thing that does not match."""
    data = read_file(path)
    payload, version, stored, computed = validate_dsv(path, data)
    magic = data[MAGIC_OFFSET:MAGIC_OFFSET + len(DOSV_MAGIC)]
    print(f"OK: {path} is a valid version-{version} .dsv save")
    print(f"  size                  {len(data)} bytes "
          f"({DSV_HEADER_SIZE} header + {len(payload)} payload)")
    print(f"  magic                 {DOSV_MAGIC.decode('ascii')} "
          f"({magic.hex(' ')})")
    print(f"  version               {version}")
    print(f"  checksum (stored)     0x{stored:04X} ({stored})")
    print(f"  checksum (recomputed) 0x{computed:04X} ({computed})")


def main():
    parser = argparse.ArgumentParser(
        description="Inspect and convert Pokémon Yellow save files.",
        epilog="With no arguments this prints usage and exits 1.")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--verify', '--info', metavar='FILE', dest='verify',
                      help='validate a .dsv file (size, magic, version, '
                           'payload checksum) and print a summary; '
                           '--info is an alias')
    mode.add_argument('--to-dos', nargs=2, metavar=('IN.sav', 'OUT.dsv'),
                      help='GB SRAM dump → DOS save (prepend the v2 header)')
    mode.add_argument('--to-gb', nargs=2, metavar=('IN.dsv', 'OUT.sav'),
                      help='DOS save → GB SRAM dump (validate, strip the header)')
    args = parser.parse_args()

    if args.verify is not None:
        verify(args.verify)
    elif args.to_dos is not None:
        to_dos(*args.to_dos)
    elif args.to_gb is not None:
        to_gb(*args.to_gb)
    else:
        parser.print_usage()
        sys.exit(1)


if __name__ == '__main__':
    main()
