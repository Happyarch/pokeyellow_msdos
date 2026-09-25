"""imfc_presets.py — IBM Music Feature Card (IMFC) voice preset library and resolver.

Contains the 240 ROM presets (ROM 1 to 5, 48 voices each) harvested from
dos_port/tools/dosbox-x/src/hardware/imfc_rom.c, plus custom voices from
dos_port/tools/audio/imfc/imfc_custom_voices.yaml.

Banks in Yamaha FB-01 / IMFC architecture:
  Bank 0: User RAM Bank A (custom voices 1-48)
  Bank 1: User RAM Bank B (custom voices 49-96)
  Bank 2: ROM 1 (Standard / General instruments)
  Bank 3: ROM 2 (Pianos & Keyboards)
  Bank 4: ROM 3 (Orchestral, Strings, Brass, Winds)
  Bank 5: ROM 4 (Synths, Basses, Percussion)
  Bank 6: ROM 5 (Organs, Guitars, Effects)

Voice numbers within banks are 1-based (1..48) for user-facing definitions
and YAML files, mapping to 0-based (0..47) on the wire.
"""

from __future__ import annotations

import difflib
from pathlib import Path
from typing import Any
import yaml

IMFC_ROM_BANKS: dict[int, list[str]] = {
    2: [
        "Brass", "Horn", "Trumpet", "LoStrig", "Strings", "Piano", "NewEP", "EGrand",
        "Jazz Gt", "EBass", "WodBass", "EOrgan1", "EOrgan2", "POrgan1", "POrgan2",
        "Flute", "Piccolo", "Oboe", "Clarine", "Glocken", "Vibes", "Xylophn",
        "Koto", "Zither", "Clav", "Harpsic", "Bells", "Harp", "SmadSyn", "Harmoni",
        "SteelDr", "Timpani", "LoStrg2", "Horn Lo", "Whistle", "ZingPlp", "Metal",
        "Heavy", "FunkSyn", "Voices", "Marimba", "EBass 2", "SnareDr", "RD Cymb",
        "Tom Tom", "Mars to", "Storm", "Windbel",
    ],
    3: [
        "UpPiano", "SPiano", "Piano2", "Piano3", "Piano4", "Piano5", "PhGrand",
        "Grand", "DpGrand", "LPiano1", "LPiano2", "EGrand2", "Honkey1", "Honkey2",
        "Pfbell", "PfVibe", "NewEP2", "NewEP3", "NewEP4", "NewEP5", "EPiano1",
        "EPiano2", "EPiano3", "EPiano4", "EPiano5", "HighTin", "HardTin", "PercPf",
        "WoodPf", "EPStrng", "EPBrass", "Clav2", "Clav3", "Clav4", "FuzzClv",
        "MuteClv", "MuteCl2", "SynClv1", "SynClv2", "SynClv3", "SynClv4", "Harpsi2",
        "Harpsi3", "Harpsi4", "Harpsi5", "Circust", "Celeste", "Squeeze",
    ],
    4: [
        "Horn2", "Horn3", "Horns", "Flugelh", "Trombon", "Trumpt2", "Brass2",
        "Brass3", "HardBr1", "HardBr2", "HardBr3", "HardBr4", "HuffBrs", "PercBr1",
        "PercBr2", "String1", "String2", "String3", "String4", "SoloVio", "RichSt1",
        "RichSt2", "RichSt3", "RichSt4", "Cello1", "Cello2", "LoStrg3", "LoStrg4",
        "LoStrg5", "Orchest", "5th Str", "Pizzic1", "Pizzic2", "Flute2", "Flute3",
        "Flute4", "Pan Flt", "SlowFlt", "5th Flt", "Oboe2", "Bassoon", "Reed",
        "Harmon2", "Harmon3", "Harmon4", "MonoSax", "Sax 1", "Sax 2",
    ],
    5: [
        "FnkSyn2", "FnkSyn3", "SynOrgn", "SynFeed", "SynHarm", "SynClar", "SynLead",
        "HuffTak", "SoHeavy", "Hollow", "Schmooh", "MonoSyn", "Cheeky", "SynBell",
        "SynPluk", "EBass3", "RubBass", "SolBass", "PlukBas", "UprtBas", "Fretles",
        "FlapBas", "MonoBas", "SynBas1", "SynBas2", "SynBas3", "SynBas4", "SynBas5",
        "SynBas6", "SynBas7", "Marimb2", "Marimb3", "Xyloph2", "Vibe2", "Vibe3",
        "Glockn2", "TubeBe1", "TubeBe2", "Bells 2", "TempleG", "SteelDr", "ElectDr",
        "Hand Dr", "SynTimp", "Clock", "Heifer", "SnareD2", "SnareD3",
    ],
    6: [
        "JOrgan1", "JOrgan2", "COrgan1", "COrgan2", "EOrgan3", "EOrgan4", "EOrgan5",
        "EOrgan6", "EOrgan7", "EOrgan8", "SmlPipe", "MidPipe", "BigPipe", "SftPipe",
        "Organ", "Guitar", "Folk Gt", "PluckGt", "BriteGt", "Fuzz Gt", "Zither2",
        "Lute", "Banjo", "SftHarp", "Harp2", "Harp3", "SftKoto", "HitKoto",
        "Sitar1", "Sitar2", "HuffSyn", "Fantasy", "Synvoic", "M.Voice", "VSAR",
        "Racing", "Water", "WildWar", "Ghostie", "Wave", "Space 1", "SpChime",
        "SpTalk", "Winds", "Smash", "Alarm", "Helicop", "SineWav",
    ],
}

for _b, _v in IMFC_ROM_BANKS.items():
    assert len(_v) == 48, f"Bank {_b} has {len(_v)} voices, expected 48"

# Flat list of all 240 factory ROM presets in bank/program order
IMFC_FACTORY: list[str] = [name for b in sorted(IMFC_ROM_BANKS) for name in IMFC_ROM_BANKS[b]]


def _norm(name: str) -> str:
    """Strips whitespace, lowercases, and removes non-alphanumeric characters."""
    return "".join(c for c in name.lower() if c.isalnum())


def _build_name_to_imfc() -> dict[str, tuple[int, int]]:
    lookup: dict[str, tuple[int, int]] = {}

    # 1. First add all ROM presets
    for bank, voices in IMFC_ROM_BANKS.items():
        for prog, name in enumerate(voices, start=1):
            norm = _norm(name)
            if norm not in lookup:
                lookup[norm] = (bank, prog)
            # Also add bank-qualified aliases e.g. "rom1:brass" or "bank2:brass"
            rom_num = bank - 1
            lookup[_norm(f"rom{rom_num}:{name}")] = (bank, prog)
            lookup[_norm(f"bank{bank}:{name}")] = (bank, prog)

    # 2. Add custom voices from imfc_custom_voices.yaml (or fallback voices.yaml)
    # Custom voices have priority over ROM presets with the same name.
    audio_dir = Path(__file__).resolve().parent
    custom_yaml = audio_dir / "imfc" / "imfc_custom_voices.yaml"
    if not custom_yaml.exists():
        custom_yaml = audio_dir / "imfc" / "voices.yaml"

    if custom_yaml.exists():
        try:
            data = yaml.safe_load(custom_yaml.read_text()) or {}
            for idx, cv in enumerate(data.get("custom_voices", []) or [], start=1):
                cbank = int(cv.get("bank", 0))
                cprog = int(cv.get("program", idx))
                cname = cv.get("name")
                cfull = cv.get("full_name")
                if cname:
                    lookup[_norm(cname)] = (cbank, cprog)
                    lookup[_norm(f"bank{cbank}:{cname}")] = (cbank, cprog)
                if cfull:
                    lookup[_norm(cfull)] = (cbank, cprog)
                    lookup[_norm(f"bank{cbank}:{cfull}")] = (cbank, cprog)
        except Exception:
            pass

    return lookup


# Dictionary mapping real-word preset names to (bank, program)
NAME_TO_IMFC: dict[str, tuple[int, int]] = _build_name_to_imfc()
IMFC_PATCHES: dict[str, tuple[int, int]] = NAME_TO_IMFC


def resolve_imfc_voice(val: Any, context: str = "") -> tuple[int, int]:
    """Resolve an IMFC voice specification to (bank, program).

    - If dict: {bank: int, program: int} (validates 0 <= bank <= 6, 1 <= program <= 48).
    - If str: looks up in IMFC_PATCHES (case-/punctuation-insensitive).
    - If int: if 1 <= val <= 48, defaults to bank 2 (ROM 1); else raises ValueError.
    - Returns (bank, program) where bank is 0..6 and program is 1..48 (1-based).
    """
    prefix = f"{context}: " if context else ""

    if isinstance(val, dict):
        if "bank" not in val or "program" not in val:
            raise ValueError(f"{prefix}IMFC voice dict must contain 'bank' and 'program', got {val!r}")
        bank = val["bank"]
        program = val["program"]
        if not isinstance(bank, int) or not (0 <= bank <= 6):
            raise ValueError(f"{prefix}IMFC voice bank {bank!r} out of range 0-6")
        if not isinstance(program, int) or not (1 <= program <= 48):
            raise ValueError(f"{prefix}IMFC voice program {program!r} out of range 1-48")
        return (bank, program)

    if isinstance(val, (tuple, list)) and len(val) == 2:
        bank, program = val
        if not isinstance(bank, int) or not (0 <= bank <= 6):
            raise ValueError(f"{prefix}IMFC voice bank {bank!r} out of range 0-6")
        if not isinstance(program, int) or not (1 <= program <= 48):
            raise ValueError(f"{prefix}IMFC voice program {program!r} out of range 1-48")
        return (bank, program)

    if isinstance(val, str):
        norm = _norm(val)
        if norm in NAME_TO_IMFC:
            return NAME_TO_IMFC[norm]

        all_names = list(IMFC_PATCHES.keys())
        close = difflib.get_close_matches(norm, all_names, n=3, cutoff=0.5)
        hint = f" (did you mean {', '.join(map(repr, close))}?)" if close else ""
        raise ValueError(f"{prefix}unknown IMFC voice preset name {val!r}{hint}")

    if isinstance(val, int):
        if 1 <= val <= 48:
            return (2, val)
        raise ValueError(f"{prefix}IMFC program {val} out of range 1-48 (default bank 2)")

    raise ValueError(f"{prefix}IMFC voice must be dict, str, or int, got {type(val).__name__}")


def load_drum_map(map_path: Path | str | None = None) -> dict[int, tuple[int, int]]:
    """Loads the GM drum note -> (bank, program) map from imfc_drums.map."""
    if map_path is None:
        map_path = Path(__file__).resolve().parent / "imfc" / "imfc_drums.map"
    p = Path(map_path)
    if not p.exists():
        return {}

    raw = yaml.safe_load(p.read_text()) or {}
    resolved: dict[int, tuple[int, int]] = {}
    for key, voice in raw.items():
        try:
            note_num = int(key)
            resolved[note_num] = resolve_imfc_voice(voice, context=f"imfc_drums.map note {key}")
        except Exception:
            continue
    return resolved


def resolve_imfc_drum(note: int, drum_map: dict[int, tuple[int, int]] | None = None) -> tuple[int, int]:
    """Resolves a GM drum note (35..81) to an IMFC (bank, program).

    If unlisted or drum_map not provided, defaults to 'SnareDr' (Bank 2, Program 43).
    """
    default_drum = resolve_imfc_voice("SnareDr", context="default drum")
    if drum_map and note in drum_map:
        return drum_map[note]
    return default_drum
