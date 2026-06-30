#!/usr/bin/env python3
"""gen_trainer_parties.py — generate dos_port/assets/trainer_parties.inc from pret source.

Emits the trainer-battle roster data consumed by ReadTrainer
(dos_port/src/engine/battle/read_trainer_party.asm):

  TrainerDataPointers — NUM_TRAINERS flat (dd) pointers, one per trainer class
                        (1-based class id; index 0 of the table = class id 1,
                        i.e. YOUNGSTER), each pointing at that class's
                        sequential, null-terminated trainer-roster blobs.
                        Mirrors data/trainers/parties.asm:TrainerDataPointers,
                        translated from pret's `dw` (bank-relative) entries to
                        the port's flat 32-bit `dd` pointer model (same
                        convention as WildDataPointers / EvosMovesPointerTable).

  <Class>Data:          per-class roster blob — concatenated trainer entries,
                        each in one of two pret-faithful formats:
                          fixed-level: db level, species_1, ..., species_n, 0
                          per-mon:     db $FF, level_1, species_1, ..., 0
                        reproduced byte-for-byte from data/trainers/parties.asm
                        (species resolved via constants/pokemon_constants.asm —
                        those constants ARE the internal index already used by
                        AddPartyMon/wPartySpecies; PokedexOrder is a separate
                        permutation used only for Pokédex display order, see
                        data/pokemon/dex_order.asm).

  SpecialTrainerMoves — Yellow's per-trainer move-override byte stream:
                        repeated { db trainerClass, trainerNo,
                        {db partySlot, moveSlot, moveId}*, db 0 },
                        globally $FF-terminated. From
                        data/trainers/special_moves.asm, trainer classes
                        resolved via constants/trainer_constants.asm and move
                        ids via constants/move_constants.asm.

Run from repo root (or dos_port/); paths resolve relative to the repo root.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]          # repo root
ASSETS = ROOT / "dos_port" / "assets"


def parse_consts(rel_path: str, const_macro: str = "const") -> dict:
    """Parse an rgbds const_def/const (or trainer_const-style) enum file.

    const_macro selects the per-entry macro name to match (e.g. "const" or
    "trainer_const"); both expand the same const_def/const_skip/const_next
    bookkeeping pret's rgbds macros provide.
    """
    out = {}
    val = 0
    pat = re.compile(rf"{const_macro}\s+(\w+)$")
    for line in (ROOT / rel_path).read_text().splitlines():
        s = line.split(";", 1)[0].strip()
        if not s:
            continue
        m = re.match(r"const_def(?:\s+(-?\w+))?$", s)
        if m:
            val = int(m.group(1), 0) if m.group(1) else 0
            continue
        m = re.match(r"const_next\s+(-?\w+)$", s)
        if m:
            val = int(m.group(1), 0)
            continue
        m = re.match(r"const_skip(?:\s+(\w+))?$", s)
        if m:
            val += int(m.group(1), 0) if m.group(1) else 1
            continue
        m = pat.match(s)
        if m:
            out[m.group(1)] = val
            val += 1
            continue
    return out


SPECIES = parse_consts("constants/pokemon_constants.asm")
TRAINER_CLASSES = parse_consts("constants/trainer_constants.asm", const_macro="trainer_const")
MOVES = parse_consts("constants/move_constants.asm")

# NUM_TRAINERS = const_value - 1 (excludes NOBODY at id 0); trainer class ids
# run 1..NUM_TRAINERS and index TrainerDataPointers as (class - 1).
NUM_TRAINERS = max(TRAINER_CLASSES.values())


def resolve_token(tok: str) -> int:
    """Resolve one comma-separated db operand: decimal int, $hex, -1, or a
    symbolic constant (species name, looked up in pokemon_constants.asm)."""
    tok = tok.strip()
    if tok in SPECIES:
        return SPECIES[tok] & 0xFF
    if tok.startswith("$"):
        return int(tok[1:], 16) & 0xFF
    if tok.startswith("0x"):
        return int(tok, 16) & 0xFF
    return int(tok, 10) & 0xFF


def parse_pointer_order() -> list:
    """Ordered list of class-data labels from parties.asm:TrainerDataPointers."""
    labels = []
    in_table = False
    for raw in (ROOT / "data/trainers/parties.asm").read_text().splitlines():
        s = raw.split(";", 1)[0].strip()
        if s == "TrainerDataPointers:":
            in_table = True
            continue
        if not in_table:
            continue
        if s.startswith("assert_table_length"):
            break
        m = re.match(r"dw\s+(\w+)$", s)
        if m:
            labels.append(m.group(1))
    return labels


def parse_party_blobs() -> dict:
    """Parse every top-level `<Label>:` roster block in parties.asm into a
    flat byte list, preserving the exact pret byte layout (both the
    fixed-level and $FF per-mon formats are just literal db streams)."""
    blobs = {}
    cur = None
    text = (ROOT / "data/trainers/parties.asm").read_text().splitlines()
    for raw in text:
        s = raw.split(";", 1)[0].strip()
        if not s:
            continue
        m = re.match(r"(\w+):$", s)
        if m:
            label = m.group(1)
            if label == "TrainerDataPointers":
                cur = None  # pointer table itself, not a roster blob
                continue
            cur = label
            blobs[cur] = bytearray()
            continue
        if cur is None:
            continue
        m = re.match(r"db\s+(.+)$", s)
        if m:
            for tok in m.group(1).split(","):
                blobs[cur].append(resolve_token(tok))
            continue
        # table_width / assert_table_length / other directives inside the
        # pointer table are handled above (cur is None there); anything else
        # at this point inside a roster block is unexpected.
        sys.exit(f"gen_trainer_parties: unparsed line under {cur!r}: {raw!r}")
    return blobs


def parse_special_moves() -> list:
    """Flat byte list for SpecialTrainerMoves, from special_moves.asm.

    Format (faithfully reproduced): repeated
      db trainerClass, trainerNo
      db partySlot, moveSlot, moveId   (repeated, 0-terminated per trainer)
    globally terminated by `db -1` (== $FF).
    """
    out = bytearray()
    in_table = False
    for raw in (ROOT / "data/trainers/special_moves.asm").read_text().splitlines():
        s = raw.split(";", 1)[0].strip()
        if not s:
            continue
        if s == "SpecialTrainerMoves:":
            in_table = True
            continue
        if not in_table:
            continue
        m = re.match(r"db\s+(.+)$", s)
        if not m:
            sys.exit(f"gen_trainer_parties: unparsed SpecialTrainerMoves line: {raw!r}")
        tokens = [t.strip() for t in m.group(1).split(",")]
        for tok in tokens:
            if tok in TRAINER_CLASSES:
                out.append(TRAINER_CLASSES[tok] & 0xFF)
            elif tok in MOVES:
                out.append(MOVES[tok] & 0xFF)
            else:
                out.append(resolve_token(tok))
    if not out or out[-1] != 0xFF:
        sys.exit("gen_trainer_parties: SpecialTrainerMoves missing $FF terminator")
    return list(out)


def main():
    pointer_order = parse_pointer_order()
    blobs = parse_party_blobs()
    special_moves = parse_special_moves()

    if len(pointer_order) != NUM_TRAINERS:
        sys.exit(
            f"gen_trainer_parties: TrainerDataPointers has {len(pointer_order)} "
            f"entries, expected NUM_TRAINERS={NUM_TRAINERS}"
        )

    missing = [lbl for lbl in pointer_order if lbl not in blobs]
    if missing:
        sys.exit(f"gen_trainer_parties: pointer labels with no blob: {sorted(set(missing))}")

    out = []
    out.append("; AUTO-GENERATED by tools/gen_trainer_parties.py — do not edit.")
    out.append("; Trainer battle roster data, from data/trainers/parties.asm and")
    out.append("; data/trainers/special_moves.asm.")
    out.append(f"; TrainerDataPointers: {len(pointer_order)} flat (dd) pointers, indexed by")
    out.append("; (wTrainerClass - 1) -- class ids are 1-based (NOBODY = 0 has no entry).")
    out.append("")
    out.append("global TrainerDataPointers")
    out.append("global SpecialTrainerMoves")
    out.append("")

    # Pointer table (flat dd, like WildDataPointers / EvosMovesPointerTable).
    out.append("TrainerDataPointers:")
    for lbl in pointer_order:
        out.append(f"    dd {lbl}")
    out.append("")

    # SpecialTrainerMoves byte stream.
    out.append("SpecialTrainerMoves:")
    out.append("    db " + ", ".join(str(b) for b in special_moves))
    out.append("")

    # The roster blobs themselves, in first-reference (pointer-table) order.
    emitted = set()
    for lbl in pointer_order:
        if lbl in emitted:
            continue
        emitted.add(lbl)
        data = blobs[lbl]
        out.append(f"{lbl}:")
        # Two pret classes (UnusedJugglerData, ChiefData) are genuinely empty
        # ("; none" in parties.asm -- the class is never instantiated in the
        # original game). Emit no `db` line for those rather than a bare
        # `db` with no operand (which NASM flags with a warning).
        if data:
            out.append("    db " + ", ".join(str(b) for b in data))
    out.append("")

    dst = ASSETS / "trainer_parties.inc"
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_text("\n".join(out) + "\n")
    print(
        f"wrote {dst} (TrainerDataPointers {len(pointer_order)} entries, "
        f"{len(emitted)} unique roster blobs, SpecialTrainerMoves "
        f"{len(special_moves)} bytes)"
    )


if __name__ == "__main__":
    main()
