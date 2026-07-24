#!/usr/bin/env python3
"""gen_trainer_headers.py — generate dos_port/assets/trainer_headers.inc (Tier-1).

Emits, for EVERY pret map that has a `<Map>TrainerHeaders:` block in
scripts/*.asm, the flat trainer-header table the port's trainer engine
(src/home/trainers.asm) consumes, plus the pre/end/after-battle text streams the
headers point at.

FLAT header layout (stride TH_SIZE=22, replacing pret's 12-byte `trainer` macro
stride — see src/home/trainers.asm header comment for the field ABI):
  +0  db  flag_bit            = the running CURRENT_TRAINER_BIT (def_trainers seed,
                                +1 per trainer). DOUBLES as the map-object index
                                (CheckForEngagingTrainers stores it into wSpriteIndex).
                                Can exceed 7 (FlagAction re-derives byte+bit from it).
  +1  db  view_range << 4     (pret packs it pre-shifted; kept verbatim)
  +2  dd  flag_ptr            GB WRAM OFFSET into wEventFlags, consumed by FlagAction
                              as [ebp+ESI]. = wEventFlags + (EVENT - CURRENT_TRAINER_BIT)/8
  +6  dd  before_battle_text  FLAT text ptr (pret trainer macro \3)
  +10 dd  after_battle_text   FLAT text ptr (pret \5)
  +14 dd  end_battle_win_text FLAT text ptr (pret \4)
  +18 dd  end_battle_lose_text FLAT text ptr (pret \4 again — Gen-1 uses the same)
Table terminated by `db 0xFF` in the TH_FLAG_BIT slot.

pret `trainer` macro (macros/scripts/maps.asm): the emitted `dw \3, \5, \4, \4`
fixes the field ORDER — before, after, end, end — mirrored into TH slots 6/10/14/18.

The referenced battle-text streams (pret `<Label>: text_far _X / text_end` wrappers
in scripts/<Map>.asm, bodies in text/<Map>.asm) are NOT emitted by any other
generator under these pret names, so this generator emits them itself, flattening
`text_far` indirection inline via gen_battle_text.parse_body (same machinery
gen_trainer_text/gen_item_text reuse). Never hand-encode charmap bytes.

Determinism: output is a pure function of pret scripts/*.asm + text/*.asm +
constants/event_constants.asm (via the generated assets/event_constants.inc) +
the fixed wEventFlags base. DO NOT EDIT the output by hand — re-run this generator.

Section discipline: the .inc does NOT self-open a section; its carrier
src/data/trainer_headers.asm opens `section .data` before %include-ing it (the
map_scripts.asm pattern). `global` directives sit at the top of the .inc.

Run from repo root or dos_port/.
"""
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_battle_text as gbt  # noqa: E402  (charmap/memmap/parse_body machinery)

ROOT    = Path(__file__).resolve().parents[3]
ASSETS  = ROOT / "dos_port" / "assets"
OUT     = ASSETS / "trainer_headers.inc"
EVENTS  = ASSETS / "event_constants.inc"
SCRIPTS = ROOT / "scripts"
TEXTS   = ROOT / "text"

TH_SIZE      = 22
WEVENTFLAGS  = 0xD746   # W_EVENT_FLAGS (dos_port/include/gb_memmap.inc canonical)


# ---------------------------------------------------------------------------
# EVENT_* bit index -> value (from the generated event_constants.inc)
# ---------------------------------------------------------------------------
def load_events() -> dict:
    ev = {}
    for line in EVENTS.read_text(encoding="utf-8").splitlines():
        m = re.match(r'%define\s+(EVENT_\w+)\s+(\d+)', line)
        if m:
            ev[m.group(1)] = int(m.group(2))
    if not ev:
        sys.exit(f"gen_trainer_headers: no EVENT_* in {EVENTS} (run gen_event_constants.py)")
    return ev


# ---------------------------------------------------------------------------
# text/<Map>.asm  ->  {_FarLabel: flattened bytes}
# ---------------------------------------------------------------------------
def collect_far_textfile(stem: str, cm, mem) -> dict:
    # A map's far bodies may be split across text/<stem>.asm and text/<stem>_N.asm
    # (e.g. Route9.asm + Route9_2.asm). Match precisely so "Route1" never grabs
    # Route10/Route11.
    pat = re.compile(rf'{re.escape(stem)}(_\d+)?\.asm$')
    blocks, cur, buf = {}, None, []
    for p in sorted(TEXTS.glob(f"{stem}*.asm")):
        if not pat.fullmatch(p.name):
            continue
        if cur:                       # flush across file boundary
            blocks[cur] = buf
            cur, buf = None, []
        for raw in p.read_text(encoding="utf-8").splitlines():
            m = re.match(r'(_\w+)::\s*$', raw.strip())
            if m:
                if cur:
                    blocks[cur] = buf
                cur, buf = m.group(1), []
                continue
            if cur is not None:
                buf.append(raw)
        if cur:
            blocks[cur] = buf
            cur, buf = None, []
    far = {}
    for label, body in blocks.items():
        try:
            far[label] = gbt.parse_body(body, cm, mem, {})
        except (KeyError, ValueError):
            pass  # not a plain string body — headers won't reference it
    return far


# ---------------------------------------------------------------------------
# scripts/<Map>.asm  ->  {WrapperLabel: _FarLabel}  for `Label: / text_far _X`
# ---------------------------------------------------------------------------
def parse_wrappers(text: str) -> dict:
    """{WrapperLabel: (far_label_or_None, [extra directive lines])}.

    `extra` is every non-comment line in the wrapper block that is not the
    text_far itself or a bare text_end — i.e. pret content the flattened data
    stream CANNOT carry (text_promptbutton, text_asm tails with PlayCry or
    SetEvent side effects). Callers must surface these, never drop them silently
    (two-tier rule: asm tails are Tier-2 code owed by the map's script layer)."""
    wrappers = {}
    lines = text.splitlines()
    for i, raw in enumerate(lines):
        m = re.match(r'([A-Za-z_]\w*):\s*$', raw.strip())
        if not m:
            continue
        label = m.group(1)
        far_lbl, extra = None, []
        for j in range(i + 1, len(lines)):
            s = lines[j].split(';', 1)[0].strip()
            if not s:
                continue
            if re.match(r'[A-Za-z_.]\w*:+\s*$', s):
                break                      # next label ends the block
            mf = re.match(r'text_far\s+(_\w+)\s*$', s)
            if mf and far_lbl is None:
                far_lbl = mf.group(1)
            elif s != 'text_end':
                extra.append(s)
        if far_lbl is not None or extra:
            wrappers[label] = (far_lbl, extra)
    return wrappers


# ---------------------------------------------------------------------------
# scripts/<Map>.asm  ->  (table_label, [entries])
# each entry = (header_label, flag_bit, view_range, flag_ptr, before, after, end)
# ---------------------------------------------------------------------------
def parse_headers(text: str, events: dict):
    lines = text.splitlines()
    # locate the `<Map>TrainerHeaders:` line
    tbl_idx = None
    table_label = None
    for i, raw in enumerate(lines):
        m = re.match(r'(\w+TrainerHeaders):\s*$', raw.strip())
        if m:
            table_label, tbl_idx = m.group(1), i
            break
    if tbl_idx is None:
        return None

    cur_bit = 1               # def_trainers default when no arg
    cur_label = None
    entries = []
    i = tbl_idx + 1
    while i < len(lines):
        s = lines[i].split(';', 1)[0].strip()
        i += 1
        if not s:
            continue
        m = re.match(r'def_trainers(?:\s+(\d+))?\s*$', s)
        if m:
            cur_bit = int(m.group(1)) if m.group(1) else 1
            continue
        m = re.match(r'(\w+):\s*$', s)   # a HeaderK: label
        if m:
            cur_label = m.group(1)
            continue
        m = re.match(r'trainer\s+(.+)$', s)
        if m:
            args = [a.strip() for a in m.group(1).split(',')]
            if len(args) != 5:
                sys.exit(f"gen_trainer_headers: {table_label}: bad trainer args {args!r}")
            event_name, view_s, before, endbattle, afterbattle = args
            if event_name not in events:
                sys.exit(f"gen_trainer_headers: {table_label}: unknown event {event_name!r}")
            ev = events[event_name]
            view = int(view_s, 0)
            flag_ptr = WEVENTFLAGS + (ev - cur_bit) // 8
            entries.append({
                "label": cur_label or f"{table_label}Entry{len(entries)}",
                "flag_bit": cur_bit,
                "view": view,
                "flag_ptr": flag_ptr,
                "before": before, "after": afterbattle, "end": endbattle,
            })
            cur_bit += 1
            cur_label = None
            continue
        if re.match(r'db\s+-1', s):    # terminator: end of the table
            break
        # any other line inside the block (blank handled above) ends nothing;
        # a non-header label without a following `trainer` is unexpected → stop.
        if re.match(r'\w+:\s*$', s):
            continue
        break
    return table_label, entries


# ---------------------------------------------------------------------------
def fmt_bytes(data) -> str:
    rows = []
    for k in range(0, len(data), 16):
        rows.append("    db " + ", ".join(f"0x{b:02X}" for b in data[k:k + 16]))
    return "\n".join(rows)


def main() -> int:
    cm  = gbt.load_charmap()
    mem = gbt.load_memmap()
    events = load_events()
    # data/text fallback far bodies (a few maps' battle text may live there).
    far_fallback = gbt.collect_far(cm, mem)

    out = [
        "; trainer_headers.inc — generated by tools/generators/gen_trainer_headers.py.",
        "; DO NOT EDIT BY HAND — re-run the generator.",
        ";",
        "; Flat trainer-header tables (stride TH_SIZE=22) + their battle-text streams,",
        "; for every pret map with a <Map>TrainerHeaders block. Field ABI:",
        ";   +0 db flag_bit  +1 db view<<4  +2 dd flag_ptr(GB WRAM offset)",
        ";   +6 dd before  +10 dd after  +14 dd end_win  +18 dd end_lose   (0xFF terminates)",
        ";",
        "; The .inc does NOT open a section; carrier src/data/trainer_headers.asm opens",
        "; section .data before %include-ing this file (map_scripts.asm pattern).",
        "",
    ]

    global_labels = []      # table + per-trainer header labels (cross-file refs)
    body_blocks = []
    emitted_streams = set()
    truncated = []          # (stream_label, dropped asm/directive lines)
    n_maps = 0
    n_trainers = 0

    for path in sorted(SCRIPTS.glob("*.asm")):
        text = path.read_text(encoding="utf-8")
        if "TrainerHeaders:" not in text:
            continue
        parsed = parse_headers(text, events)
        if parsed is None:
            continue
        table_label, entries = parsed
        if not entries:
            continue
        n_maps += 1
        n_trainers += len(entries)

        far = dict(far_fallback)
        far.update(collect_far_textfile(path.stem, cm, mem))
        wrappers = parse_wrappers(text)

        blk = [f"; ---- {table_label} ({len(entries)} trainer(s)) ----"]

        # Emit each referenced battle-text stream once (flattened text_far inline).
        stream_labels = []
        for e in entries:
            stream_labels += [e["before"], e["after"], e["end"]]
        for lbl in dict.fromkeys(stream_labels):     # de-dup, keep order
            if lbl in emitted_streams:
                continue
            emitted_streams.add(lbl)
            far_lbl, extra = wrappers.get(lbl, (None, []))
            if far_lbl is None:
                # A few maps wrap the after-battle text in a `text_asm` routine
                # (RocketHideoutB4F: `Label: text_asm / ... / .Text: text_far _X`)
                # rather than a bare `text_far`. The far body follows the
                # `_<WrapperLabel>` convention; flattening it is behaviourally
                # identical to pret's text_asm→PrintText (same visible string).
                cand = "_" + lbl
                if cand in far:
                    far_lbl = cand
            if far_lbl is None:
                sys.exit(f"gen_trainer_headers: {table_label}: no text_far wrapper for {lbl!r}")
            try:
                data = gbt.parse_body(["text_far " + far_lbl, "text_end"], cm, mem, far)
            except (KeyError, ValueError) as exc:
                sys.exit(f"gen_trainer_headers: {table_label}: cannot flatten {lbl} "
                         f"({far_lbl}): {exc}")
            blk.append(f"{lbl}:")
            # A wrapper whose block carries directives beyond text_far/text_end
            # (text_promptbutton, text_asm PlayCry/SetEvent tails) CANNOT be fully
            # represented as data. Emit the printable stream, but mark the dropped
            # tail loudly — the tail is Tier-2 code owed when the map's script
            # layer is hand-ported (route_3.asm pattern). No silent truncation.
            asm_extra = [x for x in extra
                         if not re.match(r'(ld hl, \.\w+|call PrintText|jp TextScriptEnd)$', x)]
            if asm_extra:
                truncated.append((lbl, asm_extra))
                blk.append("    ; TRUNCATED TAIL (Tier-2 debt — see .inc header): pret wrapper also runs:")
                for x in asm_extra:
                    blk.append(f"    ;   {x}")
            blk.append(fmt_bytes(data))

        # Emit the header table.
        global_labels.append(table_label)
        blk.append(f"{table_label}:")
        for idx, e in enumerate(entries):
            hlabel = e["label"]
            global_labels.append(hlabel)
            if idx == 0:
                # table_label and the first header label share the same address
                # (pret def_trainers emits no bytes), so put the label on its own line.
                blk.append(f"{hlabel}:")
            else:
                blk.append(f"{hlabel}:")
            blk.append(f"    db 0x{e['flag_bit']:02X}, 0x{(e['view'] << 4) & 0xFF:02X}"
                       f"        ; flag_bit={e['flag_bit']}, view={e['view']}")
            blk.append(f"    dd 0x{e['flag_ptr']:04X}                 ; flag_ptr (GB WRAM offset)")
            blk.append(f"    dd {e['before']}, {e['after']}, {e['end']}, {e['end']}")
        blk.append(f"    db 0xFF               ; end of {table_label}")
        blk.append("")
        body_blocks.append("\n".join(blk))

    if truncated:
        out.append("; ── TRUNCATED TAILS (Tier-2 debt inventory) ─────────────────────────────")
        out.append("; These pret wrappers carry text_asm/directive tails a data stream cannot")
        out.append("; hold (PlayCry, SetEvent, text_promptbutton). The printable stream is")
        out.append("; emitted; the tail must be realized as Tier-2 code when the owning map's")
        out.append("; script layer is hand-ported (src/scripts/route_3.asm pattern):")
        for lbl, extra in truncated:
            out.append(f";   {lbl}: " + " / ".join(extra))
        out.append("")
    for lbl in global_labels:
        out.append(f"global {lbl}")
    out.append("")
    out.extend(body_blocks)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(out) + "\n", encoding="utf-8")
    print(f"wrote {OUT.relative_to(ROOT)} — {n_maps} maps, {n_trainers} trainers, "
          f"{len(emitted_streams)} battle-text streams, {len(global_labels)} globals")
    for lbl, extra in truncated:
        sys.stderr.write(f"gen_trainer_headers: TRUNCATED TAIL {lbl}: "
                         + " / ".join(extra) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
