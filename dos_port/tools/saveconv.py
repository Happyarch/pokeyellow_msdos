#!/usr/bin/env python3
"""
saveconv.py — Game Boy .sav ↔ DOS .dsv save file converter.

STATUS: GB<->DOS conversion is still a STUB (a Phase 5 item); only the
read-only `--verify`/`--info` header check below is implemented. The .dsv format
is REAL as of menus Session 7: src/save/dsv_io.asm writes/reads version-1 files.
This header documents that live layout so a future converter maps into/out of it.

Usage:
    saveconv.py --verify save.dsv                 # validate header + checksum
    saveconv.py --info   save.dsv                 # alias of --verify

Planned usage (Phase 5, not implemented):
    saveconv.py --to-dos  input.sav  output.dsv   # GB SRAM dump → DOS save
    saveconv.py --to-gb   input.dsv  output.sav   # DOS save → GB SRAM dump

.dsv format — version 1 ("minimal real", written by src/save/dsv_io.asm):
    Offset  Size  Description
    0x00    4     Magic: b'DOSV'
    0x04    1     Format version (currently 1)
    0x05    2     16-bit ADDITIVE checksum of the payload, little-endian
    0x07    N     Payload: the WRAM blocks pret's SaveMainData/SaveCurrentBoxData/
                  SavePartyAndDexData serialize, concatenated in this order:
                    wPlayerName      11   (NAME_LENGTH)
                    wMainDataStart.. 1929 (pokédex/badges/money/options/time/box#)
                    wSpriteDataStart 512
                    wBoxDataStart..  1122 (current PC box)
                    wPartyDataStart  404  (party + nicknames)
                  N = 3978; total file = 3985 bytes.

Version 1 is NOT a faithful 32 KB SRAM bank image — no other-box banks / HoF
banks. A future faithful-SRAM format bumps the version byte (dsv_io gates on it),
and THIS converter is the tool that will translate a real 32 KB .sav into it.

Checksum (v1): sum of every payload byte, modulo 2^16, stored LE. NOT the CRC-16
originally sketched here — matched to what dsv_io.asm actually computes.

--verify checks exactly what src/save/dsv_io.asm:DsvReadSave checks before it
scatters a file back into WRAM (full length, magic, version, checksum), so a file
this mode accepts is a file the port will load, and a file it rejects is one the
port drops into its corrupt-save branch. It deliberately does NOT interpret the
3978-byte payload: block boundaries are a WRAM-layout question owned by
gb_memmap.inc, and re-deriving them here would be a second copy to drift.
"""

import argparse
import struct
import sys
from pathlib import Path

DOSV_MAGIC = b'DOSV'
DOSV_VERSION = 1
DSV_HEADER_SIZE = 7           # magic(4) + version(1) + additive checksum(2)
DSV_V1_PAYLOAD_SIZE = 3978    # sum of the WRAM blocks above
DSV_V1_TOTAL_SIZE = DSV_HEADER_SIZE + DSV_V1_PAYLOAD_SIZE
SAV_SIZE = 32768              # raw GB SRAM (the eventual faithful-format payload)

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


def verify(path):
    """Validate one .dsv file. Prints a summary and returns on success; exits 1
    on the first thing that does not match."""
    try:
        data = Path(path).read_bytes()
    except OSError as exc:
        fail(path, f"cannot read file: {exc.strerror or exc}")

    # 1. Total size. Checked first so a truncated/padded file is named as such
    #    rather than surfacing as a downstream magic/checksum error. This bound
    #    is version-1-specific: when a faithful-SRAM v2 lands with a different
    #    payload size, this check has to move behind the version dispatch below.
    if len(data) != DSV_V1_TOTAL_SIZE:
        # A 32 KB input is a GB .sav, not a .dsv — by far the likeliest way to
        # reach this branch, and worth naming rather than leaving the reader to
        # recognise the number.
        hint = (" — this is a raw GB .sav; conversion is the unimplemented "
                "--to-dos path") if len(data) == SAV_SIZE else ""
        fail(path, f"bad file size: expected {DSV_V1_TOTAL_SIZE} bytes "
                   f"({DSV_HEADER_SIZE}-byte header + "
                   f"{DSV_V1_PAYLOAD_SIZE}-byte version-{DOSV_VERSION} payload), "
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

    print(f"OK: {path} is a valid version-{version} .dsv save")
    print(f"  size                  {len(data)} bytes "
          f"({DSV_HEADER_SIZE} header + {len(payload)} payload)")
    print(f"  magic                 {DOSV_MAGIC.decode('ascii')} "
          f"({magic.hex(' ')})")
    print(f"  version               {version}")
    print(f"  checksum (stored)     0x{stored:04X} ({stored})")
    print(f"  checksum (recomputed) 0x{computed:04X} ({computed})")


def stub():
    """The unimplemented conversion path — unchanged Phase 5 stub."""
    print("saveconv.py: NOT YET IMPLEMENTED (Phase 5 item)")
    print("See ROADMAP.md for details.")
    print()
    print("Planned usage:")
    print("  saveconv.py --to-dos  input.sav  output.dsv")
    print("  saveconv.py --to-gb   input.dsv  output.sav")
    sys.exit(1)


def main():
    parser = argparse.ArgumentParser(
        description="Inspect (and eventually convert) Pokémon Yellow save files.",
        epilog="With no arguments, or with --to-dos/--to-gb, this prints the "
               "Phase 5 not-implemented notice and exits 1.")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--verify', '--info', metavar='FILE', dest='verify',
                      help='validate a .dsv file (size, magic, version, '
                           'payload checksum) and print a summary; '
                           '--info is an alias')
    # Declared only so they keep reaching the stub below. Before --verify
    # existed main() ignored argv entirely, so `--to-dos in.sav out.dsv` printed
    # the not-implemented notice; undeclared they would instead die as
    # "unrecognized arguments" (exit 2). nargs='*' keeps that true for any
    # arity, so no argparse error can pre-empt the notice.
    mode.add_argument('--to-dos', nargs='*', metavar='PATH',
                      help='GB SRAM dump → DOS save (NOT IMPLEMENTED)')
    mode.add_argument('--to-gb', nargs='*', metavar='PATH',
                      help='DOS save → GB SRAM dump (NOT IMPLEMENTED)')
    args = parser.parse_args()

    if args.verify is not None:
        verify(args.verify)
        return

    stub()


if __name__ == '__main__':
    main()
