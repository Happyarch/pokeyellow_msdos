#!/usr/bin/env python3
"""pret_audio.py — shared parser library for the pret pokeyellow audio sources.

Parses the audio *data* files (headers, music, sfx, wave samples) written in
the closed macro vocabulary of macros/scripts/audio.asm, assigns every label
its true GB ROM address (banks $02/$08/$1F/$20), and can render byte-exact
bank images. gen_audio_data.py, gb_to_midi.py and the byte-compare test all
build on this module; nothing here is DOS-port-specific.

Grammar note: the vocabulary is closed (verified by sweeping audio/music,
audio/sfx, audio/headers for leading tokens): the macros in ENCODERS below,
`channel_count`/`channel`, the four `db $ff,$ff,$ff` header paddings, and
wave_samples.asm's `dw`/`dn` lines. Anything else raises.

Address model: data sections are laid out at their true GB addresses so that
generated pointer bytes (headers, sound_call, sound_loop) match the ROM
byte-for-byte. Section bases that follow *code* sections cannot be derived
from data sources alone; those few facts are vendored in BANK_LAYOUT /
VENDORED_SYMBOLS below (extracted once from a pristine pret build's map/sym
at merge-base 7caf2e09) and are proven right by the ROM byte-compare test.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path

# repo root (this file lives in dos_port/tools/audio/)
ROOT = Path(__file__).resolve().parents[3]

BANK_SIZE = 0x4000
BANK_BASE = 0x4000  # ROMX banks are addressed $4000-$7FFF

# ---------------------------------------------------------------------------
# Vendored layout facts (from pret-golden pokeyellow.map / .sym, merge-base
# 7caf2e09; verified by tools/audio/test_audio_data.py byte-compare).
#
# Per bank: ordered data sections as (section name, base address or None).
# None = contiguous with the previous section. Engine/code sections between
# them are skipped; the section *after* a code section carries a vendored
# base address.
# ---------------------------------------------------------------------------
BANK_LAYOUT: dict[int, list[tuple[str, int | None]]] = {
    0x02: [
        ("Sound Effect Headers 1", 0x4000),
        ("Music Headers 1", None),
        ("Sound Effects 1", None),
        ("Music 1", 0x5A16),  # after "Audio Engine 1" code
    ],
    0x08: [
        ("Sound Effect Headers 2", 0x4000),
        ("Music Headers 2", None),
        ("Sound Effects 2", None),
        ("Music 2", 0x5B9A),  # after low-health alarm / Bill's PC / engine 2
    ],
    0x1F: [
        ("Sound Effect Headers 3", 0x4000),
        ("Music Headers 3", None),
        ("Sound Effects 3", None),
        ("Music 3", 0x5221),  # after "Audio Engine 3" code
    ],
    0x20: [
        ("Sound Effect Headers 4", 0x4000),
        ("Music Headers 4", None),
        ("Sound Effects 4", None),
        ("Music 4", 0x6CE8),  # after surfing-pikachu gfx + "Audio Engine 4"
    ],
}

# Data files embedded inside *code* sections; their addresses cannot be
# derived from the data layout, so they are vendored from the golden .sym.
# (path, bank, address, label-for-scope-or-None).
# - pokeflute_ch5_ch6 sits mid-"Audio Engine 2" (pointed at by
#   Music_PokeFluteInBattle's pointer overwrite);
# - notes.asm is the pitch table at the tail of engine_1.asm, labelled
#   Audio1_Pitches there.
EMBEDDED_DATA_FILES: list[tuple[str, int, int, str | None]] = [
    ("audio/sfx/pokeflute_ch5_ch6.asm", 0x08, 0x59EB, None),
    ("audio/notes.asm", 0x02, 0x59A5, "Audio1_Pitches"),
]

# Loose data bytes emitted by macros inside engine code, dereferenced via
# wChannelCommandPointers: (bank, address, bytes, label).
EMBEDDED_BYTES: list[tuple[int, int, bytes, str]] = [
    (0x08, 0x59CE, b"\xff", "Audio2_CryRet"),  # sound_ret
]

# Loose vendored symbols useful to consumers (bank, address).
VENDORED_SYMBOLS: dict[str, tuple[int, int]] = {
    "CryData": (0x0E, 0x5462),  # data/pokemon/cries.asm (bank $0E)
}

# ---------------------------------------------------------------------------
# Pitch constants (constants/audio_constants.asm)
# ---------------------------------------------------------------------------
PITCHES = {
    "C_": 0, "C#": 1, "D_": 2, "D#": 3, "E_": 4, "F_": 5,
    "F#": 6, "G_": 7, "G#": 8, "A_": 9, "A#": 10, "B_": 11,
}
NUM_NOTES = 12

# Command ids (macros/scripts/audio.asm)
PITCH_SWEEP_CMD = 0x10
SFX_NOTE_CMD = 0x20            # square_note / noise_note
DRUM_NOTE_CMD = 0xB0
REST_CMD = 0xC0
NOTE_TYPE_CMD = 0xD0           # drum_speed shares the id
OCTAVE_CMD = 0xE0
TOGGLE_PERFECT_PITCH_CMD = 0xE8
VIBRATO_CMD = 0xEA
PITCH_SLIDE_CMD = 0xEB
DUTY_CYCLE_CMD = 0xEC
TEMPO_CMD = 0xED
STEREO_PANNING_CMD = 0xEE
UNKNOWNMUSIC0XEF_CMD = 0xEF
VOLUME_CMD = 0xF0
EXECUTE_MUSIC_CMD = 0xF8
DUTY_CYCLE_PATTERN_CMD = 0xFC
SOUND_CALL_CMD = 0xFD
SOUND_LOOP_CMD = 0xFE
SOUND_RET_CMD = 0xFF

SFX_STOP_ALL_MUSIC = 0xFF


def parse_int(tok: str) -> int:
    """rgbds numeric literal: decimal, $hex, %binary, optional leading -."""
    tok = tok.strip()
    neg = tok.startswith("-")
    if neg:
        tok = tok[1:].strip()
    if tok.startswith("$"):
        val = int(tok[1:], 16)
    elif tok.startswith("%"):
        val = int(tok[1:], 2)
    else:
        val = int(tok, 10)
    return -val if neg else val


def parse_pitch(tok: str) -> int:
    tok = tok.strip()
    if tok in PITCHES:
        return PITCHES[tok]
    return parse_int(tok)


def signmag_nibble(val: int) -> int:
    """Signed-magnitude nibble used by fade/pitch-change arguments."""
    if val < 0:
        return 0b1000 | (-val)
    return val


def dn(hi: int, lo: int) -> int:
    return ((hi & 0xF) << 4) | (lo & 0xF)


# ---------------------------------------------------------------------------
# Parsed items
# ---------------------------------------------------------------------------
@dataclass
class Label:
    name: str        # full name; locals are expanded to "Parent.local"
    exported: bool
    size = 0

    def encode(self, symtab, addr):
        return b""


@dataclass
class Cmd:
    """One audio-macro invocation."""
    name: str
    args: list       # ints / pitch ints / str label refs (already classified)
    size: int
    _encode: object = field(repr=False)

    def encode(self, symtab: dict[str, int], addr: int) -> bytes:
        return self._encode(self.args, symtab)


@dataclass
class Raw:
    """db/dw/dn directive."""
    kind: str
    args: list       # ints or label-ref strings (dw only)
    size: int

    def encode(self, symtab: dict[str, int], addr: int) -> bytes:
        if self.kind == "db":
            return bytes(a & 0xFF for a in self.args)
        if self.kind == "dw":
            out = bytearray()
            for a in self.args:
                val = symtab[a] if isinstance(a, str) else a
                out += bytes((val & 0xFF, (val >> 8) & 0xFF))  # little-endian
            return bytes(out)
        if self.kind == "dn":
            if len(self.args) % 2:
                raise ValueError("dn needs an even nibble count")
            return bytes(
                dn(self.args[i], self.args[i + 1])
                for i in range(0, len(self.args), 2)
            )
        raise ValueError(self.kind)


# ---------------------------------------------------------------------------
# Macro encoders: name -> (size, arg-parser, encoder)
# Each entry: size (bytes), parse(args:list[str]) -> list, encode(args, symtab)
# ---------------------------------------------------------------------------
def _enc_pitch_sweep(a, _):
    return bytes((PITCH_SWEEP_CMD, dn(a[0], signmag_nibble(a[1]))))


def _enc_square_note(a, _):
    freq = a[3]
    return bytes((
        SFX_NOTE_CMD | a[0],
        dn(a[1], signmag_nibble(a[2])),
        freq & 0xFF, (freq >> 8) & 0xFF,
    ))


def _enc_noise_note(a, _):
    return bytes((
        SFX_NOTE_CMD | a[0],
        dn(a[1], signmag_nibble(a[2])),
        a[3] & 0xFF,
    ))


def _enc_note(a, _):
    return bytes((dn(a[0], a[1] - 1),))


def _enc_drum_note(a, _):
    return bytes((DRUM_NOTE_CMD | (a[1] - 1), a[0] & 0xFF))


def _enc_rest(a, _):
    return bytes((REST_CMD | (a[0] - 1),))


def _enc_note_type(a, _):
    return bytes((NOTE_TYPE_CMD | a[0], dn(a[1], signmag_nibble(a[2]))))


def _enc_drum_speed(a, _):
    return bytes((NOTE_TYPE_CMD | a[0],))


def _enc_octave(a, _):
    return bytes((OCTAVE_CMD | (8 - a[0]),))


def _enc_toggle_perfect_pitch(a, _):
    return bytes((TOGGLE_PERFECT_PITCH_CMD,))


def _enc_vibrato(a, _):
    return bytes((VIBRATO_CMD, a[0] & 0xFF, dn(a[1], a[2])))


def _enc_pitch_slide(a, _):
    return bytes((PITCH_SLIDE_CMD, (a[0] - 1) & 0xFF, dn(8 - a[1], a[2])))


def _enc_duty_cycle(a, _):
    return bytes((DUTY_CYCLE_CMD, a[0] & 0xFF))


def _enc_tempo(a, _):
    return bytes((TEMPO_CMD, (a[0] >> 8) & 0xFF, a[0] & 0xFF))  # big-endian


def _enc_stereo_panning(a, _):
    return bytes((STEREO_PANNING_CMD, dn(a[0], a[1])))


def _enc_volume(a, _):
    return bytes((VOLUME_CMD, dn(a[0], a[1])))


def _enc_execute_music(a, _):
    return bytes((EXECUTE_MUSIC_CMD,))


def _enc_duty_cycle_pattern(a, _):
    return bytes((
        DUTY_CYCLE_PATTERN_CMD,
        ((a[0] << 6) | (a[1] << 4) | (a[2] << 2) | a[3]) & 0xFF,
    ))


def _enc_sound_call(a, symtab):
    addr = symtab[a[0]]
    return bytes((SOUND_CALL_CMD, addr & 0xFF, (addr >> 8) & 0xFF))


def _enc_sound_loop(a, symtab):
    addr = symtab[a[1]]
    return bytes((SOUND_LOOP_CMD, a[0] & 0xFF, addr & 0xFF, (addr >> 8) & 0xFF))


def _enc_sound_ret(a, _):
    return bytes((SOUND_RET_CMD,))


def _args_ints(args):
    return [parse_int(a) for a in args]


def _args_note(args):
    return [parse_pitch(args[0]), parse_int(args[1])]


def _args_pitch_slide(args):
    return [parse_int(args[0]), parse_int(args[1]), parse_pitch(args[2])]


def _args_sound_call(args):
    return [args[0].strip()]


def _args_sound_loop(args):
    return [parse_int(args[0]), args[1].strip()]


# name -> (size, arg_parser, encoder)
ENCODERS = {
    "pitch_sweep":          (2, _args_ints, _enc_pitch_sweep),
    "square_note":          (4, _args_ints, _enc_square_note),
    "noise_note":           (3, _args_ints, _enc_noise_note),
    "note":                 (1, _args_note, _enc_note),
    "drum_note":            (2, _args_ints, _enc_drum_note),
    "rest":                 (1, _args_ints, _enc_rest),
    "note_type":            (2, _args_ints, _enc_note_type),
    "drum_speed":           (1, _args_ints, _enc_drum_speed),
    "octave":               (1, _args_ints, _enc_octave),
    "toggle_perfect_pitch": (1, _args_ints, _enc_toggle_perfect_pitch),
    "vibrato":              (3, _args_ints, _enc_vibrato),
    "pitch_slide":          (3, _args_pitch_slide, _enc_pitch_slide),
    "duty_cycle":           (2, _args_ints, _enc_duty_cycle),
    "tempo":                (3, _args_ints, _enc_tempo),
    "stereo_panning":       (2, _args_ints, _enc_stereo_panning),
    "volume":               (2, _args_ints, _enc_volume),
    "execute_music":        (1, _args_ints, _enc_execute_music),
    "duty_cycle_pattern":   (2, _args_ints, _enc_duty_cycle_pattern),
    "sound_call":           (3, _args_sound_call, _enc_sound_call),
    "sound_loop":           (4, _args_sound_loop, _enc_sound_loop),
    "sound_ret":            (1, _args_ints, _enc_sound_ret),
}

_LABEL_RE = re.compile(r"^(\.?[A-Za-z_][A-Za-z0-9_]*)(::|:)?$")


def _split_args(rest: str) -> list[str]:
    rest = rest.strip()
    if not rest:
        return []
    return [a.strip() for a in rest.split(",")]


@dataclass
class SourceFile:
    """One parsed audio data file (or inline snippet)."""
    path: str
    items: list = field(default_factory=list)

    @property
    def size(self) -> int:
        return sum(it.size for it in self.items)


def parse_data_file(path: Path, rel: str, scope: str | None = None) -> SourceFile:
    """Parse an audio data file into labels/commands/raw items.

    Local labels (.x) are expanded to "Parent.x" using the most recent
    global label, mirroring rgbds scoping. `scope` seeds that for files
    whose parent label sits in audio.asm (wave_samples.asm under
    Audio1_WavePointers). channel_count/channel state is resolved here
    (the header entry byte depends on the preceding channel_count).
    """
    sf = SourceFile(rel)
    pending_channels = None  # from channel_count, consumed by first channel

    for lineno, line in enumerate(path.read_text().splitlines(), 1):
        code = line.split(";", 1)[0].strip()
        if not code:
            continue
        where = f"{rel}:{lineno}"

        m = _LABEL_RE.match(code)
        # Globals must carry a colon; a bare dotted name is a local label
        # (bare non-dotted names are macro invocations like sound_ret).
        if m and (m.group(2) or (code.startswith(".") and " " not in code)):
            name, colons = m.group(1), m.group(2) or ""
            if name.startswith("."):
                if scope is None:
                    raise SyntaxError(f"{where}: local label without scope")
                full = scope + name
            else:
                full = name
                scope = name
            sf.items.append(Label(full, colons == "::"))
            continue

        # directive / macro
        head, _, rest = code.partition(" ")
        args = _split_args(rest)

        if head in ("table_width", "assert_table_length"):
            continue  # assertion-only directives (audio/notes.asm)
        if head == "db":
            sf.items.append(Raw("db", _args_ints(args), len(args)))
        elif head == "dw":
            vals = []
            for a in args:
                a = a.strip()
                try:
                    vals.append(parse_int(a))
                except ValueError:
                    vals.append(scope + a if a.startswith(".") else a)
            sf.items.append(Raw("dw", vals, 2 * len(args)))
        elif head == "dn":
            sf.items.append(Raw("dn", _args_ints(args), len(args) // 2))
        elif head == "channel_count":
            pending_channels = parse_int(args[0])
            if not 1 <= pending_channels <= 4:
                raise ValueError(f"{where}: channel_count {pending_channels}")
        elif head == "channel":
            chan = parse_int(args[0])
            target = args[1].strip()
            if target.startswith("."):
                target = scope + target
            count = pending_channels if pending_channels is not None else 1
            pending_channels = None
            first_byte = ((count - 1) << 6) | (chan - 1)

            def _enc_channel(a, symtab, _b=first_byte):
                addr = symtab[a[0]]
                return bytes((_b, addr & 0xFF, (addr >> 8) & 0xFF))

            sf.items.append(Cmd("channel", [target], 3, _enc_channel))
        elif head in ENCODERS:
            size, argp, enc = ENCODERS[head]
            parsed = argp(args)
            # locals in sound_call/sound_loop targets
            for i, a in enumerate(parsed):
                if isinstance(a, str) and a.startswith("."):
                    parsed[i] = scope + a
            sf.items.append(Cmd(head, parsed, size, enc))
        else:
            raise SyntaxError(f"{where}: unknown directive {head!r}")

    return sf


# ---------------------------------------------------------------------------
# audio.asm structure
# ---------------------------------------------------------------------------
_SECTION_RE = re.compile(r'^SECTION\s+"([^"]+)"')
_INCLUDE_RE = re.compile(r'^INCLUDE\s+"([^"]+)"')


def parse_audio_asm(root: Path) -> dict[str, list]:
    """Section name -> ordered list of includes/inline labels.

    Items are ("include", path) or ("label", name). IF/ENDC blocks (the
    release-only garbage INCBIN in Music 4) are skipped.
    """
    sections: dict[str, list] = {}
    current = None
    if_depth = 0
    for line in (root / "audio.asm").read_text().splitlines():
        code = line.split(";", 1)[0].strip()
        if not code:
            continue
        if code.startswith(("IF ", "IF\t")):
            if_depth += 1
            continue
        if code == "ENDC":
            if_depth -= 1
            continue
        if if_depth:
            continue
        m = _SECTION_RE.match(code)
        if m:
            current = m.group(1)
            sections[current] = []
            continue
        m = _INCLUDE_RE.match(code)
        if m and current:
            # pikachu_cries.asm opens its own SECTIONs (raw PCM banks,
            # handled by gen_pika_pcm.py in Phase C) — not Music 4 data.
            if m.group(1) == "audio/pikachu_cries.asm":
                current = None
                continue
            sections[current].append(("include", m.group(1)))
            continue
        m = _LABEL_RE.match(code)
        if m and current:
            sections[current].append(("label", m.group(1)))
    return sections


@dataclass
class Section:
    name: str
    bank: int
    start: int          # GB address
    files: list         # of SourceFile
    end: int = 0        # exclusive, filled by layout


class AudioROM:
    """All parsed audio data with resolved addresses and bank images."""

    def __init__(self, root: Path = ROOT):
        self.root = root
        self.sections: list[Section] = []
        self.symtab: dict[str, int] = {}          # label -> GB address
        self.sym_bank: dict[str, int] = {}        # label -> bank
        self.files: dict[str, SourceFile] = {}    # rel path -> parsed file
        self._load()

    # -- loading ------------------------------------------------------------
    def _parse(self, rel: str, scope: str | None = None) -> SourceFile:
        if rel not in self.files:
            self.files[rel] = parse_data_file(self.root / rel, rel, scope)
        return self.files[rel]

    def _load(self):
        asm = parse_audio_asm(self.root)
        for bank, layout in BANK_LAYOUT.items():
            cursor = None
            for name, base in layout:
                if name not in asm:
                    raise KeyError(f"audio.asm lacks section {name!r}")
                start = base if base is not None else cursor
                if start is None:
                    raise ValueError(f"{name}: no base address")
                sec = Section(name, bank, start, [])
                addr = start
                scope = None
                for kind, val in asm[name]:
                    if kind == "label":
                        self._def_symbol(val, addr, bank)
                        scope = val
                        continue
                    sf = self._parse(val, scope)
                    self._place(sf, addr, bank)
                    sec.files.append(sf)
                    addr += sf.size
                sec.end = addr
                self.sections.append(sec)
                cursor = addr
        # data files embedded inside code sections (vendored addresses)
        for rel, bank, addr, label in EMBEDDED_DATA_FILES:
            if label:
                self._def_symbol(label, addr, bank)
            sf = self._parse(rel, label)
            self._place(sf, addr, bank)
            self.sections.append(
                Section(f"(embedded) {rel}", bank, addr, [sf], addr + sf.size)
            )
        for bank, addr, data, label in EMBEDDED_BYTES:
            self._def_symbol(label, addr, bank)
            sf = SourceFile(f"(bytes) {label}")
            sf.items.append(Raw("db", list(data), len(data)))
            self.sections.append(
                Section(f"(embedded) {label}", bank, addr, [sf], addr + len(data))
            )

    def _def_symbol(self, name: str, addr: int, bank: int):
        if name in self.symtab:
            raise KeyError(f"duplicate label {name}")
        self.symtab[name] = addr
        self.sym_bank[name] = bank

    def _place(self, sf: SourceFile, addr: int, bank: int):
        for it in sf.items:
            if isinstance(it, Label):
                self._def_symbol(it.name, addr, bank)
            addr += it.size

    # -- output -------------------------------------------------------------
    def render_bank(self, bank: int) -> tuple[bytearray, bytearray]:
        """(image, mask) for one bank; offset 0 = $4000. mask: 1 = generated."""
        img = bytearray(BANK_SIZE)
        mask = bytearray(BANK_SIZE)
        for sec in self.sections:
            if sec.bank != bank:
                continue
            addr = sec.start
            for sf in sec.files:
                for it in sf.items:
                    data = it.encode(self.symtab, addr)
                    off = addr - BANK_BASE
                    img[off:off + len(data)] = data
                    for i in range(len(data)):
                        mask[off + i] = 1
                    addr += it.size
        return img, mask

    def banks(self):
        return sorted(BANK_LAYOUT)


# ---------------------------------------------------------------------------
# Timing evaluator
# ---------------------------------------------------------------------------
class ChannelTimer:
    """Replicates the engine's per-channel note-delay accumulation.

    Audio1_note_length computes, via Audio1_MultiplyAdd (hl = l + a*de,
    16-bit wrap):
        prod  = (length_nibble + 1) * note_speed        (low byte kept)
        acc   = frac + (prod & $FF) * tempo             (16-bit wrap)
        delay = HIGH(acc); frac' = LOW(acc)
    tempo is wMusicTempo for CHAN1-4, $0100 for the SFX noise channel
    (CHAN8), wSfxTempo for CHAN5-7. A delay of N means the next note plays
    on the Nth engine tick (60 Hz).
    """

    def __init__(self):
        self.frac = 0

    def note_frames(self, length_nibble: int, speed: int, tempo: int) -> int:
        prod = ((length_nibble + 1) * speed) & 0xFF
        acc = (self.frac + prod * tempo) & 0xFFFF
        self.frac = acc & 0xFF
        return acc >> 8
