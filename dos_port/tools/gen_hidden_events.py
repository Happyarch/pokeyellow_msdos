#!/usr/bin/env python3
"""gen_hidden_events.py — generate dos_port/assets/hidden_events.inc from pret source.

Emits the Gen-1 Yellow hidden-event data (overworld-events plan, Stage 3):

  HiddenEventMaps:   flat per-map dispatch table. pret packs each entry as
                     `db map_id / dw HiddenEventsFor_<map>` (3 bytes, same-bank
                     word pointer). The port has no banks, so the word pointer
                     becomes a flat `dd`: each entry is `db map_id / dd ptr`
                     (5-byte stride). `db -1` terminates. CheckForHiddenEvent
                     (src/home/hidden_events.asm) scans it with IsInArray stride 5.

  HiddenEventsFor_<map>: per-map list. pret packs each `hidden_event` as
                     `db y / db x / db arg / dba handler` where `dba` = bank + 2-byte
                     addr. Flat model: `db y / db x / db arg / db 0 (inert bank) /
                     dd handler` (8-byte entry). `db -1` terminates. This matches
                     CheckForHiddenEvent's flat reader exactly (read y,x; on match
                     read arg, bank, dd handler; on mismatch skip arg+bank+dd = 6).

Handler labels are Tier-2 code (src/engine/overworld/hidden_object_stubs.asm holds a
ret-stub for each until its owning map/subsystem lands; StartSlotMachine and the
Print*Text bodies retire the stubs as those subsystems are ported).

Constant args (item ids, SPRITE_FACING_*, ANY_FACING, predef text ids) and map ids
are resolved to numeric bytes here — the port's includes do not define the pret map
or full item constant sets, so symbolic emission is not an option.

Run from repo root (or dos_port/); paths resolve relative to the repo root.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "dos_port" / "assets"

# ANY_FACING is DEF'd inside data/events/hidden_events.asm itself.
FACINGS = {
    "SPRITE_FACING_DOWN": 0x00,
    "SPRITE_FACING_UP": 0x04,
    "SPRITE_FACING_LEFT": 0x08,
    "SPRITE_FACING_RIGHT": 0x0C,
    "ANY_FACING": 0xD0,
}


def parse_map_ids():
    """map const name -> numeric id (map_const order in constants/map_constants.asm)."""
    ids = {}
    idx = 0
    for line in (ROOT / "constants/map_constants.asm").read_text().splitlines():
        m = re.match(r"\s*map_const\s+(\w+)\s*,", line)
        if m:
            ids[m.group(1)] = idx
            idx += 1
    return ids


def parse_item_ids():
    """item const name -> numeric id (const_def sequence in item_constants.asm)."""
    ids = {}
    val = 0
    started = False
    for line in (ROOT / "constants/item_constants.asm").read_text().splitlines():
        if re.match(r"\s*const_def\b", line):
            started = True
            val = 0
            continue
        if not started:
            continue
        m = re.match(r"\s*const\s+(\w+)", line)
        if m:
            ids[m.group(1)] = val
            val += 1
    return ids


def parse_predef_text_ids():
    """predef text label -> 1-based index (db_tx_pre value) from text_predef_pointers."""
    ids = {}
    idx = 1
    for line in (ROOT / "data/text_predef_pointers.asm").read_text().splitlines():
        m = re.match(r"\s*add_tx_pre\s+(\w+)", line)
        if m:
            ids[m.group(1)] = idx
            idx += 1
    return ids


def parse_defs(relpath, names):
    """Collect `DEF NAME EQU value` / `NAME EQU value` for the given names."""
    out = {}
    text = (ROOT / relpath).read_text()
    for name in names:
        m = re.search(rf"(?:DEF\s+)?{re.escape(name)}\s+EQU\s+(\$?[0-9A-Fa-f]+)", text)
        if m:
            v = m.group(1)
            out[name] = int(v.replace("$", "0x"), 0) if "$" in v else int(v, 0)
    return out


def build_arg_namespace(items):
    """Symbol table for evaluating a hidden_event arg expression."""
    ns = {"TRUE": 1, "FALSE": 0}
    ns.update(items)        # item ids incl. COIN
    ns.update(FACINGS)
    ns.update(parse_defs("constants/script_constants.asm",
                         ["SLOTS_SOMEONESKEYS", "SLOTS_OUTOFORDER", "SLOTS_OUTTOLUNCH"]))
    return ns


def resolve_event_arg(expr, ns):
    """Evaluate a hidden_event 4th-arg expression (COIN+10, (TRUE << 4) | 2, $ff, POTION)."""
    py = re.sub(r"\$([0-9A-Fa-f]+)", r"0x\1", expr.strip())
    return eval(py, {"__builtins__": {}}, ns) & 0xFF


def parse_hidden_events():
    """Return (map_order, per_map_lists).

    map_order:    list of map const names, in HiddenEventMaps order.
    per_map_lists: {map_name: [ (y, x, arg, handler), ... ]}
    """
    text = (ROOT / "data/events/hidden_events.asm").read_text().splitlines()
    predef = parse_predef_text_ids()
    items = parse_item_ids()
    arg_ns = build_arg_namespace(items)

    map_order = []
    lists = {}
    cur = None
    in_maps = False

    for line in text:
        m = re.match(r"\s*hidden_event_map\s+(\w+)", line)
        if m:
            map_order.append(m.group(1))
            in_maps = True
            continue
        m = re.match(r"\s*hidden_events_for\s+(\w+)", line)
        if m:
            cur = m.group(1)
            lists[cur] = []
            in_maps = False
            continue
        # hidden_event X, Y, HANDLER, ARG-EXPR (arg may be an expression: COIN+10, (TRUE<<4)|2)
        m = re.match(r"\s*hidden_event\s+(\d+)\s*,\s*(\d+)\s*,\s*(\w+)\s*,\s*(.+)", line)
        if m and cur is not None:
            x, y, handler = m.group(1), m.group(2), m.group(3)
            arg = m.group(4).split(";")[0]      # strip trailing comment
            lists[cur].append((int(y), int(x), resolve_event_arg(arg, arg_ns), handler))
            continue
        # hidden_text_predef X, Y, HANDLER, PREDEF_TEXT
        m = re.match(r"\s*hidden_text_predef\s+(\d+)\s*,\s*(\d+)\s*,\s*(\w+)\s*,\s*(\w+)", line)
        if m and cur is not None:
            x, y, handler, textid = m.group(1), m.group(2), m.group(3), m.group(4)
            if textid not in predef:
                sys.exit(f"gen_hidden_events: unknown predef text id {textid}")
            lists[cur].append((int(y), int(x), predef[textid], handler))
            continue

    return map_order, lists


def collect_handlers(lists):
    seen = []
    for entries in lists.values():
        for (_y, _x, _arg, handler) in entries:
            if handler not in seen:
                seen.append(handler)
    return seen


def main():
    map_ids = parse_map_ids()
    map_order, lists = parse_hidden_events()

    unknown = [m for m in map_order if m not in map_ids]
    if unknown:
        sys.exit(f"gen_hidden_events: HiddenEventMaps names unknown maps: {unknown}")

    handlers = collect_handlers(lists)

    out = []
    out.append("; AUTO-GENERATED by tools/gen_hidden_events.py — do not edit.")
    out.append("; Gen-1 Yellow hidden-event data (overworld-events plan, Stage 3).")
    out.append("; Source: data/events/hidden_events.asm (read-only pret spec).")
    out.append(";")
    out.append("; HiddenEventMaps entry  = db map_id / dd HiddenEventsFor_<map>   (5-byte stride)")
    out.append("; hidden_event entry     = db y / db x / db arg / db 0 / dd handler (8 bytes)")
    out.append("; both lists are `db -1` terminated (checked against the first byte).")
    out.append("")

    # Handler labels live in src/engine/overworld/hidden_object_stubs.asm (Tier-2);
    # extern them so the `dd handler` fields resolve to a known 4-byte size (an
    # unresolved forward ref also destabilises the HiddenEventsFor_* label offsets).
    for handler in handlers:
        out.append(f"extern {handler}")
    out.append("")

    out.append("global HiddenEventMaps")
    out.append("HiddenEventMaps:")
    for name in map_order:
        out.append(f"    db 0x{map_ids[name]:02X}")
        out.append(f"    dd HiddenEventsFor_{name}")
        out.append(f"    ; {name}")
    out.append("    db 0xFF                         ; end")
    out.append("")

    for name in map_order:
        out.append(f"HiddenEventsFor_{name}:")
        for (y, x, arg, handler) in lists.get(name, []):
            out.append(
                f"    db {y:>3}, {x:>3}, 0x{arg & 0xFF:02X}, 0"
                f"                ; y, x, arg, bank"
            )
            out.append(f"    dd {handler}")
        out.append("    db 0xFF")
    out.append("")

    dst = ASSETS / "hidden_events.inc"
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_text("\n".join(out) + "\n")

    n_entries = sum(len(v) for v in lists.values())
    print(f"wrote {dst} (HiddenEventMaps {len(map_order)} maps, "
          f"{n_entries} entries, {len(handlers)} distinct handlers)")
    # Emit the handler list to stderr so the stub file can be cross-checked by hand.
    print("handlers: " + " ".join(handlers), file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
