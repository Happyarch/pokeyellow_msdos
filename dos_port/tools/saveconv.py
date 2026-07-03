#!/usr/bin/env python3
"""
saveconv.py — Game Boy .sav ↔ DOS .dsv save file converter.

STATUS: STUB — GB<->DOS conversion not yet implemented (a Phase 5 item). But the
.dsv format is now REAL as of menus Session 7: src/save/dsv_io.asm writes/reads
version-1 files. This header documents that live layout so a future converter
maps into/out of it.

Planned usage (Phase 5):
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
"""

import sys

DOSV_MAGIC = b'DOSV'
DOSV_VERSION = 1
DSV_HEADER_SIZE = 7           # magic(4) + version(1) + additive checksum(2)
DSV_V1_PAYLOAD_SIZE = 3978    # sum of the WRAM blocks above
DSV_V1_TOTAL_SIZE = DSV_HEADER_SIZE + DSV_V1_PAYLOAD_SIZE
SAV_SIZE = 32768              # raw GB SRAM (the eventual faithful-format payload)


def main():
    print("saveconv.py: NOT YET IMPLEMENTED (Phase 5 item)")
    print("See ROADMAP.md for details.")
    print()
    print("Planned usage:")
    print("  saveconv.py --to-dos  input.sav  output.dsv")
    print("  saveconv.py --to-gb   input.dsv  output.sav")
    sys.exit(1)


if __name__ == '__main__':
    main()
