#!/usr/bin/env python3
"""overworld_inventory.py — enumerate every interactive overworld element in the
Pokémon Yellow DOS port and classify its port status.

This is a read-only survey. It does NOT build anything, write to translation.db,
or modify generated assets. It reads the checked-in pret source (the read-only
specification) and the port's hand-written/dialect source, and reports, per map:

  * every object_event (NPC / trainer / item ball / scripted object)
  * every bg_event (sign / event tile)
  * every warp_event
  * how each dialog TEXT ID currently resolves in the port's NPC-dialog pipeline:
        STATIC_TEXT  — generated as a real byte stream from a `text_far` row
        PORTED_SCRIPT— a hand-translated text_asm routine exists in dos_port/src/scripts
        STUB_PLACEHOLDER ("...") — the generator emits the `...` placeholder
        ITEM_MARKED  — object_event carries the ITEM flag
        TRAINER      — object_event is a trainer (TextBefore/End/AfterBattle)
  * every hidden item / hidden coin / hidden event (event tiles)
  * which maps have a live (wired) script layer in gen_map_script_tables.WIRED_MAPS

The "..." placeholder is what the user keeps bumping into (Rival's sister / TV,
etc.): it is emitted by tools/generators/gen_npc_dialogs.py for every dialog slot
whose pret pointer is a `text_asm` script that the generator does not route through
SCRIPT_OVERRIDES, or whose object_event is ITEM-marked.

Outputs (next to this script, under dos_port/overworld/):
  overworld_inventory.json       — full machine-readable survey
  overworld_inventory.md         — human-readable report
  (also prints a summary to stdout)

Run from dos_port/ or repo root:
    python3 tools/overworld_inventory.py
"""

import json
import re
import sys
from collections import defaultdict
from pathlib import Path

# gen_map_headers parses cleanly on its own (no generated-asset dependency),
# giving us the authoritative object/bg/warp enumerations for every map.
sys.path.insert(0, str(Path(__file__).resolve().parent / "generators"))
import gen_map_headers as gmh  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]  # .../pokeyellow_msdos
SCRIPTS = ROOT / "scripts"
TEXT = ROOT / "text"
OBJECTS = ROOT / "data" / "maps" / "objects"
PORT_SCRIPTS = ROOT / "dos_port" / "src" / "scripts"
EVENTS = ROOT / "data" / "events"
GENNPD = ROOT / "dos_port" / "tools" / "generators" / "gen_npc_dialogs.py"

# ---------------------------------------------------------------------------
# Text-command byte constants (mirrors gen_npc_dialogs.py)
# ---------------------------------------------------------------------------
TX_START = 0x00
TX_END = 0x50
CHAR_DONE = 0x57

# Charmap is needed only if we want to print raw strings; the survey just needs
# to know whether a text label resolves. Keep an empty default so the tool never
# hard-fails on a missing/odd charmap.
_CHARMAP_CACHE = None
_ITEM_NAMES = None


def _load_item_names() -> dict:
    """{numeric_item_id: NAME} from constants/item_constants.asm (1-based)."""
    global _ITEM_NAMES
    if _ITEM_NAMES is not None:
        return _ITEM_NAMES
    idx = {}
    order = []
    for line in (ROOT / "constants" / "item_constants.asm").read_text().splitlines():
        m = re.match(r"\s*const\s+([A-Z0-9_]+)", line)
        if m:
            order.append(m.group(1))
    for i, name in enumerate(order, 1):
        idx[i] = name
    _ITEM_NAMES = idx
    return idx


def item_name(item_id):
    """Return the item constant name for a numeric id, or the id as a string."""
    names = _load_item_names()
    return names.get(item_id, str(item_id))


def _load_charmap():
    global _CHARMAP_CACHE
    if _CHARMAP_CACHE is not None:
        return _CHARMAP_CACHE
    cm = []
    path = ROOT / "constants" / "charmap.asm"
    if not path.exists():
        _CHARMAP_CACHE = cm
        return cm
    for line in path.read_text(encoding="utf-8").splitlines():
        m = re.match(r'\s+charmap\s+"((?:[^"\\]|\\.)*)",\s*\$([0-9a-fA-F]+)', line)
        if m:
            cm.append((m.group(1), int(m.group(2), 16)))
    cm.sort(key=lambda x: -len(x[0]))
    _CHARMAP_CACHE = cm
    return cm


def _encode(s, charmap):
    out = []
    i = 0
    while i < len(s):
        for key, val in charmap:
            if s[i:].startswith(key):
                out.append(val)
                i += len(key)
                break
        else:
            i += 1  # incremental decode; survey tool is lossy on purpose
    return bytes(out)


# ---------------------------------------------------------------------------
# scripts/<Map>.asm → list of text-pointer local labels + kind classification
# ---------------------------------------------------------------------------
def _parse_text_pointers(path: Path, map_pascal: str) -> list:
    """Return the ordered list of local labels in <Map>_TextPointers.

    Mirrors gen_npc_dialogs._parse_text_pointers so slot indexes match the
    generated dialog tables exactly.
    """
    target = f"{map_pascal}_TextPointers:"
    in_table = False
    result = []
    text = path.read_text(encoding="utf-8")
    for line in text.splitlines():
        s = line.strip()
        if s == target:
            in_table = True
            continue
        if not in_table:
            continue
        if not s or s.startswith(";"):
            continue
        if s.startswith("def_text_pointers") or re.match(r"const_def\s+\d+", s):
            continue
        m = re.match(r"dw\s+(\w+)", s)
        if m:
            result.append(m.group(1))
            continue
        m = re.match(r"dw_const\s+(\w+)", s)
        if m:
            result.append(m.group(1))
            continue
        if re.match(r"^\w+:\s*$", s):
            break
        break
    return result


def _label_body(path: Path, label: str) -> str:
    """Return the indented body under `label:` in a scripts file."""
    text = path.read_text(encoding="utf-8", errors="replace")
    m = re.search(rf"^{re.escape(label)}:\n((?:.*\n)+?)(?=^\S|\Z)", text, re.M)
    if not m:
        return ""
    return m.group(1)


# ---------------------------------------------------------------------------
# Global far-text index: text/<Map>.asm + data/text/text_*.asm define _Label::
# ---------------------------------------------------------------------------
_FAR_TEXT = None


def _collect_far_text() -> dict:
    """{far_label (no underscore): source_path} for every `_Label::` in the tree."""
    global _FAR_TEXT
    if _FAR_TEXT is not None:
        return _FAR_TEXT
    idx = {}
    files = list(TEXT.glob("*.asm")) + list((ROOT / "data" / "text").glob("*.asm"))
    for f in files:
        try:
            for line in f.read_text(encoding="utf-8", errors="replace").splitlines():
                m = re.match(r"(_\w+)::\s*", line.strip())
                if m:
                    idx[m.group(1)] = f.name
        except Exception:  # noqa: BLE001
            continue
    _FAR_TEXT = idx
    return idx


def _resolve_local_label(path: Path, label: str):
    """Find `text_far X` under `label:` in a scripts file; return X or None.

    pret's far text labels are usually `_X` but not always (e.g.
    `text_far MelanieBulbasaurText` in CeruleanMelaniesHouse.asm), so match a
    bare word too; whether the far label actually exists is checked separately.
    """
    body = _label_body(path, label)
    if not body:
        return None
    m = re.match(r"\s*text_far\s+(\w+)", body)
    if m:
        return m.group(1)
    return None


def _strip_leading_comments(body: str) -> str:
    """Drop leading `; comment` lines (and blank lines) from a script body."""
    lines = body.splitlines()
    i = 0
    while i < len(lines) and (not lines[i].strip() or lines[i].strip().startswith(";")):
        i += 1
    return "\n".join(lines[i:])


def _is_static_text_label(path: Path, label: str) -> bool:
    """True if `label:` is a PLAIN static text wrapper in a scripts file.

    Mirrors tools/generators/gen_npc_dialogs.py's `_is_static_text_label`. A
    plain wrapper is exactly `text_far _X / text_end` (or raw `text "..."` rows)
    with no logic. A `text_asm` block (even one that CONTAINS nested `text_far`
    rows under its own `.Label:` sub-labels) is a runtime routine and must be
    CALLed (SCRIPT), not inlined as a static byte stream — inlining a gym-leader's
    pre-battle text would drop the battle/reward state machine. Script_* macros
    are dynamic too; empty alias bodies (`text_end`) are NOT routines.
    """
    body = path.read_text(encoding="utf-8", errors="replace")
    m = re.search(rf"^{re.escape(label)}:\n((?:.*\n)+?)(?=^\S|\Z)", body, re.M)
    if not m:
        return True                 # no body at all — alias/pointer, not a routine
    inner = m.group(1)
    first = None
    for line in inner.splitlines():
        s = line.strip()
        if not s or s.startswith(";"):
            continue
        first = s
        break
    if first is None:
        return True                 # empty body — alias/pointer, not a routine
    if first.startswith("text_asm"):
        return False                # runtime routine — auto-wire it
    if first.startswith("script_vending_machine") or first.startswith("script_prize_vendor"):
        return False                # dynamic script macro — auto-wire it
    return True                     # text_far / text / text_start / text_end — static or alias


def classify_text_pointer(path: Path, label: str):
    """Classify how pret resolves `label:` in a scripts file.

    Mirrors tools/generators/gen_npc_dialogs.py's resolution order so the survey's
    statuses match what the NPC-dialog pipeline actually produces. Returns
    (kind, detail) where kind is one of:
      STATIC_TEXT  — text_far _X, or a `_<label>` that exists in a text file
      INLINE_TEXT  — body is raw `text "..."` rows (no text_far)
      TEXT_ASM     — a text_asm block (dynamic, game-state-gated)
      TRAINER_HOOK — the standard TalkToTrainer hook (trainer)
      UNKNOWN      — could not classify
    """
    body = _strip_leading_comments(_label_body(path, label)).strip()
    if not body:
        # No body anywhere: could be a shared code label (e.g. PickUpItemText in
        # home/overworld_text.asm) that is effectively a scripted/auto item flow,
        # or a pointer-only alias (e.g. MtMoonB2FJessieJamesText: text_end).
        if f"_{label}" in _collect_far_text():
            return "STATIC_TEXT", f"_{label}"
        return "UNKNOWN_GLOBAL", ""
    if body in ("text_end", "text_start"):
        # An alias/empty text label whose real body lives under a sibling label.
        if f"_{label}" in _collect_far_text():
            return "STATIC_TEXT", f"_{label}"
        return "EMPTY_ALIAS", ""
    if re.match(r"script_vending_machine\b", body) or re.match(r"script_prize_vendor\b", body):
        # Special vending-machine / prize-vendor script macros — dynamic.
        return "TEXT_ASM", ""
    m = re.match(r"text_asm\b", body)
    if m:
        # A `text_asm` body is ALWAYS a runtime routine — never a static byte
        # stream, even if a sibling `_<label>::` far-text row shares the name
        # (e.g. BikeShopMiddleAgedWomanText: its `.Text` advice is a separate
        # `_BikeShopMiddleAgedWomanText::` row, but the routine it belongs to is
        # a game-state dispatch, so the generated slot must CALL it, not inline
        # the bytes). Check the trainer-talk hook spellings FIRST — but only the
        # STRICT forms gen_npc_dialogs._resolve_trainer_talk_hook honours:
        #     ld hl, <Map>TrainerHeaderN / call TalkToTrainer / jp TextScriptEnd
        #     ld hl, <Map>TrainerHeaderN / jr <Map>TalkToTrainer
        # Anything else (e.g. `jr <Map>InitBattleScript`) is NOT the standard hook
        # and the generator auto-wires the ported routine as a SCRIPT, so call it
        # TEXT_ASM to match. A broad `(?:jr|jp) (\w+)` would mislabel those as
        # TRAINER_HOOK (TRAINER) when the emitted row is actually a SCRIPT.
        m = re.match(
            r"text_asm\s*\n\s*ld hl, (\w+TrainerHeader\d+)\s*\n\s*call TalkToTrainer\s*\n\s*jp TextScriptEnd", body)
        if m:
            return "TRAINER_HOOK", m.group(1)
        m = re.match(
            r"text_asm\s*\n\s*ld hl, (\w+TrainerHeader\d+)\s*\n\s*(?:jr|jp) (\w+TalkToTrainer)", body)
        if m:
            return "TRAINER_HOOK", m.group(1)
        return "TEXT_ASM", ""
    # Genuine static text wrapper: `text_far _X` at the top of the body.
    far = _resolve_local_label(path, label)
    if far:
        return "STATIC_TEXT", far
    # Static `_<label>` convention (e.g. _PokeCenterSignText, _MartSignText live
    # in data/text/text_1.asm) — only reachable when the body is NOT a text_asm
    # routine (handled above), so a shared sign resolves as real bytes.
    if f"_{label}" in _collect_far_text():
        return "STATIC_TEXT", f"_{label}"
    if re.match(r"text\s+", body) or re.match(r"text_start", body):
        return "INLINE_TEXT", ""
    return "UNKNOWN", ""


# ---------------------------------------------------------------------------
# SCRIPT_OVERRIDES from gen_npc_dialogs.py (which imports a gen_map_script_tables
# that needs generated assets, so we cannot import it; parse the dict instead).
# ---------------------------------------------------------------------------
def _load_script_overrides() -> dict:
    src = GENNPD.read_text(encoding="utf-8")
    m = re.search(r"SCRIPT_OVERRIDES = \{(.*?)\n\}", src, re.S)
    if not m:
        return {}
    body = m.group(1)
    out = {}
    for line in body.splitlines():
        mm = re.match(r"\s*'([^']+)':\s*'([^']+)'", line)
        if mm:
            out[mm.group(1)] = mm.group(2)
    return out


SCRIPT_OVERRIDES = _load_script_overrides()


# ---------------------------------------------------------------------------
# Port script label presence: dos_port/src/scripts/<Map>.asm globals
# ---------------------------------------------------------------------------
_PORT_ALL_GLOBALS = None


def _all_port_globals() -> set:
    """Every `global` symbol declared anywhere under dos_port/src/."""
    global _PORT_ALL_GLOBALS
    if _PORT_ALL_GLOBALS is not None:
        return _PORT_ALL_GLOBALS
    syms = set()
    for path in (ROOT / "dos_port" / "src").rglob("*.asm"):
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
            syms |= set(re.findall(r"^\s*global\s+(\w+)", text, re.M))
        except Exception:  # noqa: BLE001
            continue
    _PORT_ALL_GLOBALS = syms
    return syms


def _port_globals(map_pascal: str) -> set:
    path = PORT_SCRIPTS / f"{map_pascal}.asm"
    if not path.exists():
        return set()
    text = path.read_text(encoding="utf-8", errors="replace")
    return set(re.findall(r"^\s*global\s+(\w+)", text, re.M))


# ---------------------------------------------------------------------------
# Wired maps
# ---------------------------------------------------------------------------
def _load_wired_maps() -> set:
    src = (ROOT / "dos_port" / "tools" / "generators" / "gen_map_script_tables.py")
    if not src.exists():
        return set()
    text = src.read_text(encoding="utf-8")
    m = re.search(r"WIRED_MAPS = \{(.*?)\n\}", text, re.S)
    if not m:
        return set()
    return set(re.findall(r'"([A-Z0-9_]+)"', m.group(1)))


WIRED_MAPS = _load_wired_maps()


# ---------------------------------------------------------------------------
# Hidden items / coins / events
# ---------------------------------------------------------------------------
def _parse_hidden_items() -> list:
    """Parse data/events/hidden_item_coords.asm → [{map, x, y}]."""
    out = []
    path = EVENTS / "hidden_item_coords.asm"
    if not path.exists():
        return out
    for line in path.read_text(encoding="utf-8").splitlines():
        m = re.match(r"\s*hidden_item\s+([A-Z0-9_]+),\s*(\d+),\s*(\d+)", line)
        if m:
            out.append({"map": m.group(1), "x": int(m.group(2)), "y": int(m.group(3))})
    return out


def _parse_hidden_coins() -> list:
    out = []
    path = EVENTS / "hidden_coins.asm"
    if not path.exists():
        return out
    for line in path.read_text(encoding="utf-8").splitlines():
        m = re.match(r"\s*hidden_coin\s+([A-Z0-9_]+),\s*(\d+),\s*(\d+)", line)
        if m:
            out.append({"map": m.group(1), "x": int(m.group(2)), "y": int(m.group(3))})
    return out


def _parse_hidden_events() -> list:
    out = []
    path = EVENTS / "hidden_events.asm"
    if not path.exists():
        return out
    text = path.read_text(encoding="utf-8")
    for m in re.finditer(r"\s*hidden_event_map\s+([A-Z0-9_]+)", text):
        out.append({"map": m.group(1)})
    return out


def _parse_hidden_event_entries(map_const: str) -> list:
    """Parse the `hidden_events_for <map>` block for one map.

    pret defines each block with `hidden_events_for <MAP>` (expanding to
    `HiddenEventsFor_<MAP>:`); blocks are indented, so split on the macro line
    rather than matching an unindented label.
    """
    path = EVENTS / "hidden_events.asm"
    if not path.exists():
        return []
    text = path.read_text(encoding="utf-8", errors="replace")
    # Split the file into (map_const, body) blocks at each indented macro line.
    parts = re.split(r"^\s*hidden_events_for\s+(\w+)\s*$", text, flags=re.M)
    # re.split with a capture yields [pre, cap1, body1, cap2, body2, ...].
    blocks = {}
    for i in range(1, len(parts) - 1, 2):
        blocks[parts[i]] = parts[i + 1]
    body = blocks.get(map_const)
    if body is None:
        return []
    entries = []
    for line in body.splitlines():
        s = line.strip()
        if not s or s.startswith(";") or s == "db -1 ; end":
            continue
        # macro: hidden_event x, y, handler, arg  →  db y, x, arg, dba handler
        mm = re.match(r"hidden_event\s+(\d+),\s*(\d+),\s*(\w+),\s*(\w+)", s)
        if mm:
            entries.append({"x": int(mm.group(1)), "y": int(mm.group(2)),
                            "handler": mm.group(3), "arg": mm.group(4)})
    return entries


# ---------------------------------------------------------------------------
# Per-map survey
# ---------------------------------------------------------------------------
def survey_map(const: str, map_pascal: str) -> dict:
    rec = {
        "const": const,
        "label": map_pascal,
        "wired": const in WIRED_MAPS,
        "src_script_exists": (PORT_SCRIPTS / f"{map_pascal}.asm").exists(),
        "warps": [],
        "bg_events": [],
        "object_events": [],
        "dialog_slots": [],
    }

    try:
        border, warps, signs, sprites = gmh.parse_object_file(map_pascal)
    except Exception as e:  # noqa: BLE001
        rec["parse_error"] = str(e)
        return rec

    for (y, x, dest, warp_id) in warps:
        rec["warps"].append({"x": x, "y": y, "dest": dest, "warp_id": warp_id})
    for sign in signs:
        rec["bg_events"].append(sign)

    scripts_path = SCRIPTS / f"{map_pascal}.asm"
    pointers = _parse_text_pointers(scripts_path, map_pascal) if scripts_path.exists() else []
    rec["text_pointer_count"] = len(pointers)

    npc_count = len(sprites)
    max_sign_id = max((s.get("text_id", 0) for s in signs), default=0)
    npc_count_eff = max(npc_count, max_sign_id, len(pointers))

    # object_event records (NPC / trainer / item / scripted)
    for i, sp in enumerate(sprites):
        rec["object_events"].append({
            "slot": i + 1,
            "sprite_id": sp.get("sprite_id"),
            "x": sp.get("mapx", 0) - 4,   # macro stores x+4, y+4; recover logical coord
            "y": sp.get("mapy", 0) - 4,
            "mov": sp.get("mov"),
            "dir": sp.get("dir"),
            "is_trainer": sp.get("is_trainer"),
            "trainer_class": sp.get("trainer_class"),
            "trainer_num": sp.get("trainer_num"),
            "is_item": sp.get("is_item"),
            "item_id": sp.get("item_id"),
        })

    port_globals = _port_globals(map_pascal)

    for i in range(npc_count_eff):
        local_label = pointers[i] if i < len(pointers) else None
        slot = {
            "slot": i + 1,
            "text_id": i + 1,            # text ids are 1-based
            "local_label": local_label,
            "is_object": i < npc_count,
            "is_sign": i >= npc_count,
            "status": "TEXT_ONLY_SLOT",   # slot past known pointers, nothing to do
        }
        if i < npc_count:
            sp = sprites[i]
            slot["sprite"] = sp.get("sprite_id")
            slot["x"] = sp.get("mapx", 0) - 4
            slot["y"] = sp.get("mapy", 0) - 4
            slot["is_trainer"] = sp.get("is_trainer")
            slot["is_item"] = sp.get("is_item")
            slot["item_id"] = sp.get("item_id", 0)
            # An ITEM-flagged object with item_id 0 is a scripted/toggleable object
            # (e.g. Blues House's Daisy + Town Map), not a real item ball. The
            # generator still emits the "..." byte stream for it, so flag it.
            if sp.get("is_item"):
                slot["status"] = "ITEM_MARKED" if sp.get("item_id", 0) else "ITEM_MARKED_ID0"
            elif sp.get("is_trainer"):
                slot["status"] = "TRAINER"
        # Determine per-slot resolution kind + whether a ported script exists
        if local_label:
            kind, detail = classify_text_pointer(scripts_path, local_label) \
                if scripts_path.exists() else ("UNKNOWN", "")
            slot["pret_kind"] = kind
            slot["pret_detail"] = detail
            override = SCRIPT_OVERRIDES.get(local_label)
            slot["script_override"] = override
            # Is this label already-translated (a ported global in the map's own
            # src/scripts/<Map>.asm)? That is what the generator auto-discovers.
            ported_in_map = local_label in port_globals
            # Order mirrors tools/generators/gen_npc_dialogs.py resolution.
            #
            # 1. SCRIPT_OVERRIDES first (explicitly hand-wired). The target may
            #    live in the map's script file OR any engine/home port file.
            if override:
                slot["status"] = ("PORTED_SCRIPT"
                                  if override in _all_port_globals()
                                  else "PORTED_SCRIPT_MISSING_EXTERN")
            # 2. Item-flagged object_event with a real item id (id != 0): the
            #    generator always emits the item byte stream. Pickup is a
            #    separate system (PickUpItem / give_item), so mark it as such.
            #    A trailing id of 0 means a scripted/toggleable object, not a
            #    ball — it is treated as a plain slot now.
            elif slot.get("is_item") and slot.get("item_id", 0) != 0:
                slot["status"] = "ITEM_MARKED"
            elif slot.get("is_item") and slot.get("item_id", 0) == 0:
                # item id 0 (e.g. Blues House Daisy/Town Map): the generator now
                # treats it as a plain text slot, so it may auto-wire or static.
                # Re-derive with the same rules as a normal slot (mirrors the
                # generator's auto-discovery order).
                slot["item_zero"] = True
                if (ported_in_map and scripts_path.exists()
                        and not _is_static_text_label(scripts_path, local_label)):
                    slot["status"] = "PORTED_SCRIPT"
                elif kind in ("STATIC_TEXT", "INLINE_TEXT"):
                    slot["status"] = "STATIC_TEXT"
                elif ported_in_map:
                    slot["status"] = "PORTED_SCRIPT"
                elif kind == "TEXT_ASM":
                    slot["status"] = "STUB_PLACEHOLDER"
                else:
                    slot["status"] = "ITEM_MARKED_ID0_LEGACY"
            # 3. Wired-map trainer talk hook: the generator emits the shared
            #    TrainerTalkHook entry (TRAINER_TALK_SENTINEL) automatically, so
            #    no SCRIPT_OVERRIDES row is needed.
            elif kind == "TRAINER_HOOK" and const in WIRED_MAPS and slot.get("is_trainer"):
                slot["status"] = "TRAINER"
            # 4. Auto-wire a ported text_asm script (gen_npc_dialogs auto-discovery):
            #    the pret label is a `global` in the map's own port script file AND
            #    the pret body is NOT a plain static wrapper. The generator emits a
            #    SCRIPT entry that CALLs it. Runs for gym/Elite-Four trainers, story
            #    NPCs and service dialogs whose maps are NOT in WIRED_MAPS.
            elif (ported_in_map and scripts_path.exists()
                  and not _is_static_text_label(scripts_path, local_label)):
                slot["status"] = "PORTED_SCRIPT"
            # 5. Static text (trainer pre-battle or plain NPC/sign): real bytes,
            #    either from the map's text file or the shared far-text index.
            elif kind in ("STATIC_TEXT", "INLINE_TEXT"):
                slot["status"] = "TRAINER_STATIC" if slot.get("is_trainer") else "STATIC_TEXT"
            # 6. Dynamic text_asm script (trainer state machine, service dialog,
            #    etc.). If the port has a same-named global in the map's script
            #    file, the generator auto-wires it (SCRIPT_SENTINEL); otherwise it
            #    is a hand-port candidate / "..." stub.
            elif kind == "TEXT_ASM":
                slot["status"] = ("TRAINER_STUB" if slot.get("is_trainer")
                                  else "STUB_PLACEHOLDER")
            elif kind in ("UNKNOWN_GLOBAL", "EMPTY_ALIAS"):
                # Shared/alias code label with no map-local body (e.g.
                # PickUpItemText, MtMoonB2FJessieJamesText): almost always a
                # text_asm item/script flow or a pointer alias. The generator
                # cannot resolve it today, so it renders "..." until wired.
                slot["status"] = "STUB_PLACEHOLDER"
            elif kind == "UNKNOWN":
                slot["status"] = "UNKNOWN"
            # 6. Fallback: a trainer whose standard-hook text has no wired map
            #    and no static text — the generator emits the "TRAINER!" stub
            #    and the talk can't enter TalkToTrainer. Wire the map or override.
            elif slot.get("is_trainer"):
                slot["status"] = "TRAINER_STUB"
        rec["dialog_slots"].append(slot)

    # hidden items / coins for this map
    rec["hidden_items"] = [h for h in HIDDEN_ITEMS if h["map"] == const]
    rec["hidden_coins"] = [c for c in HIDDEN_COINS if c["map"] == const]
    rec["hidden_events"] = _parse_hidden_event_entries(const)
    rec["hidden_event_map_listed"] = any(h["map"] == const for h in HIDDEN_EVENT_MAPS)

    return rec


def main() -> int:
    global HIDDEN_ITEMS, HIDDEN_COINS, HIDDEN_EVENT_MAPS
    const_to_label, _ = gmh.parse_all_headers()

    HIDDEN_ITEMS = _parse_hidden_items()
    HIDDEN_COINS = _parse_hidden_coins()
    HIDDEN_EVENT_MAPS = _parse_hidden_events()

    maps = []
    for const, map_pascal in sorted(const_to_label.items()):
        maps.append(survey_map(const, map_pascal))

    outdir = Path(__file__).resolve().parent.parent / "overworld"
    outdir.mkdir(parents=True, exist_ok=True)

    json_path = outdir / "overworld_inventory.json"
    md_path = outdir / "overworld_inventory.md"

    json_path.write_text(json.dumps(maps, indent=2), encoding="utf-8")

    # ---- aggregate stats ----------------------------------------------------
    status_count = defaultdict(int)
    map_stats = defaultdict(int)
    for m in maps:
        has_slot = False
        for s in m["dialog_slots"]:
            status_count[s["status"]] += 1
            has_slot = True
        if has_slot:
            map_stats["maps_with_slots"] += 1
        for k in ("bg_events", "object_events", "warps", "hidden_items",
                  "hidden_coins", "hidden_events"):
            map_stats[k] += len(m[k])
        if m["wired"]:
            map_stats["wired_maps"] += 1

    # ---- candidate SCRIPT_OVERRIDES additions --------------------------------
    # For every PORTED_SCRIPT_UNWIRED slot (a ported text_asm routine exists and
    # the generator just has no SCRIPT_OVERRIDES row, so it renders "..."), the
    # wired mapping is `'<pret_label>': '<port_label>'` where the two names are
    # identical (the port keeps pret's label verbatim). Emit a ready-to-paste
    # dict fragment so the batch fix is mechanical.
    candidates = []
    seen_labels = set()
    for m in maps:
        for s in m["dialog_slots"]:
            lbl = s.get("local_label")
            if s["status"] == "PORTED_SCRIPT_UNWIRED" and lbl and lbl not in seen_labels:
                seen_labels.add(lbl)
                candidates.append((m["label"], s["slot"], lbl))
    # Only emit the candidate file when there really are unwired ported labels;
    # with auto-discovery the list is normally empty and a stale "to-do" file
    # would be misleading.
    cand_path = outdir / "script_overrides_candidates.py"
    if candidates:
        cand_lines = [
            "# Auto-generated candidate SCRIPT_OVERRIDES additions.",
            "# Every row below is a ported text_asm routine that gen_npc_dialogs.py",
            "# is NOT yet auto-discovered (the label is a ported global but the",
            "# generator does not wire it, so the slot renders '...').",
            "# The mapping is identity: pret label == port NASM global (the port keeps",
            "# pret's labels verbatim). Review each row, then paste into",
            "# dos_port/tools/generators/gen_npc_dialogs.py SCRIPT_OVERRIDES = { ... }.",
            "# Run the generator after applying and re-run this inventory to confirm.",
            "ORPHAN_SCRIPT_OVERRIDES = {",
        ]
        for label, _slot, local in candidates:
            cand_lines.append(f"    '{local}': '{local}',   # {label}")
        cand_lines.append("}")
        cand_path.write_text("\n".join(cand_lines) + "\n", encoding="utf-8")
    elif cand_path.exists():
        cand_path.unlink()

    # ---- markdown report ----------------------------------------------------
    # Pre-index port globals once for the whole tree (cheap, avoids re-reading).
    port_global_by_map = {m["label"]: _port_globals(m["label"]) for m in maps}
    all_globals = _all_port_globals()

    lines = []
    lines.append("# Overworld Interaction Inventory")
    lines.append("")
    lines.append("Generated by `dos_port/tools/overworld_inventory.py`. Read-only survey of the")
    lines.append("pret source + port script layer. Status of each dialog TEXT ID slot describes")
    lines.append("how the port's NPC-dialog pipeline currently resolves that slot.")
    lines.append("")
    lines.append("## Status legend")
    lines.append("")
    lines.append("| Status | Meaning |")
    lines.append("| --- | --- |")
    lines.append("| `STATIC_TEXT` | pret `text_far` row; the generator already emits real text bytes. |")
    lines.append("| `PORTED_SCRIPT` | a hand-translated text_asm routine is wired to this slot (auto-discovered or SCRIPT_OVERRIDES). |")
    lines.append("| `PORTED_SCRIPT_UNWIRED` | a ported routine exists but gen_npc_dialogs cannot wire it — renders \"...\" (same-name label not in the map file, or off-map). |")
    lines.append("| `PORTED_SCRIPT_MISSING_EXTERN` | SCRIPT_OVERRIDES row points at a label not present in the port script (link error). |")
    lines.append("| `STUB_PLACEHOLDER` | emits the \"...\" placeholder — a text_asm script NPC/sign with no ported route. |")
    lines.append("| `ITEM_MARKED` | object_event carries the ITEM flag with a real item id (item ball / pokeball). |")
    lines.append("| `TRAINER` | object_event is a trainer routed through the shared TrainerTalkHook (wired maps). |")
    lines.append("| `TRAINER_STATIC` | trainer whose pre-battle text is static text_far — already generated. |")
    lines.append("| `TRAINER_STUB` | trainer with no static text — generator emits the \"TRAINER!\" stub. |")
    lines.append("| `INLINE_TEXT` | raw `text \"...\"` rows in the scripts file (rare). |")
    lines.append("| `UNKNOWN` | script body could not be classified. |")
    lines.append("")
    lines.append("## Aggregate")
    lines.append("")
    lines.append("| Count | Value |")
    lines.append("| --- | --- |")
    for k, v in sorted(map_stats.items()):
        lines.append(f"| {k} | {v} |")
    lines.append("")
    lines.append("Dialog-slot status totals:")
    lines.append("")
    lines.append("| Status | Count |")
    lines.append("| --- | --- |")
    for k in sorted(status_count):
        lines.append(f"| {k} | {status_count[k]} |")
    lines.append("")
    lines.append("## How to close the gaps")
    lines.append("")
    lines.append("`gen_npc_dialogs.py` now auto-wires any dialog slot whose pret `text_asm` label is a")
    lines.append("ported `global` in the map's own `src/scripts/<Map>.asm`, and treats an ITEM-flagged")
    lines.append("object with item id 0 as a plain text slot. Shared subsystem far text (`BoulderText`,")
    lines.append("`MartSignText`, `PokeCenterSignText`, ...) resolves from a global far-text index. So the")
    lines.append("old `PORTED_SCRIPT_UNWIRED` / `ITEM_MARKED_ID0` buckets are gone.")
    lines.append("")
    lines.append("What is still open:")
    lines.append("")
    lines.append("1. **Hand-port or route the `STUB_PLACEHOLDER` slots** (mart clerks → the shared")
    lines.append("   `DisplayPokemartDialogue_`; Jessie/James, gate guards, mansion switches → port the")
    lines.append("   state-gated text_asm). See the problem-slots table below.")
    lines.append("2. **Wire the remaining `TRAINER_STUB`** (`MtMoonB2FSuperNerdText`) — port it or add")
    lines.append("   the map to a wired set.")
    lines.append("3. **Audit items & event tiles** against the tables below — they are generated data")
    lines.append("   (`gen_hidden_events.py`, `gen_hidden_item_coords.py`, `gen_hidden_coins.py`), so")
    lines.append("   coverage is a matter of confirming each generator emits everything in pret's")
    lines.append("   `data/events/*.asm` and the port entity reads it.")
    lines.append("")
    lines.append("## Per-map breakdown")
    lines.append("")
    lines.append("| Map | Wired | Slots | NPC | ItemBalls | Signs | HiddenItems | HiddenCoins | Status mix |")
    lines.append("| --- | --- | --- | --- | --- | --- | --- | --- | --- |")
    for m in maps:
        if not (m["object_events"] or m["bg_events"] or m["hidden_items"] or m["dialog_slots"]):
            continue
        slots = len(m["dialog_slots"])
        npcs = len(m["object_events"])
        balls = sum(1 for s in m["dialog_slots"] if s["status"] == "ITEM_MARKED")
        signs = len(m["bg_events"])
        hidden_items = len(m["hidden_items"])
        hidden_coins = len(m["hidden_coins"])
        mix = defaultdict(int)
        for s in m["dialog_slots"]:
            mix[s["status"]] += 1
        mixstr = ", ".join(f"{k}:{v}" for k, v in sorted(mix.items()))
        lines.append(f"| {m['label']} | {'Y' if m['wired'] else 'n'} | {slots} | {npcs} | "
                     f"{balls} | {signs} | {hidden_items} | {hidden_coins} | {mixstr} |")
    lines.append("")

    # ---- Items & event tiles ------------------------------------------------
    lines.append("## Items (seen item balls, per map)")
    lines.append("")
    lines.append("| Map | Item id | Item name | x | y | Sprite |")
    lines.append("| --- | --- | --- | --- | --- | --- |")
    for m in maps:
        balls = [s for s in m["dialog_slots"] if s["status"] == "ITEM_MARKED"]
        if not balls:
            continue
        for s in balls:
            lines.append(f"| {m['label']} | {s.get('item_id')} | {item_name(s.get('item_id', 0))} | "
                         f"{s.get('x', '?')} | {s.get('y', '?')} | {s.get('sprite')} |")
    lines.append("")
    lines.append("Item ids/names come from `constants/item_constants.asm`; the object x,y are the")
    lines.append("map coordinates (the macro stores x+4, y+4). Item pickup is a separate system")
    lines.append("(`src/engine/events/hidden_items.asm` / `pick_up_item.asm`), so these slots are")
    lines.append("NOT the same \"...\" problem as NPC text. They are listed so item-coverage work")
    lines.append("can be tracked from the same tool.")
    lines.append("")
    lines.append("## Scripted/toggleable objects misclassified as items (item id 0)")
    lines.append("")
    item_zero = [ (m, s) for m in maps for s in m["dialog_slots"] if s["status"] == "ITEM_MARKED_ID0_LEGACY" ]
    if item_zero:
        lines.append("These are the `ITEM_MARKED_ID0_LEGACY` slots — ITEM-flagged with id 0 that the")
        lines.append("generator has not been made to treat as a plain text slot.")
        lines.append("")
        lines.append("| Map | Slot | Local label | Pret kind |")
        lines.append("| --- | --- | --- | --- |")
        for m, s in item_zero:
            lines.append(f"| {m['label']} | {s['slot']} | {s.get('local_label') or '-'} | "
                         f"{s.get('pret_kind') or '-'} |")
    else:
        lines.append("Resolved. `gen_npc_dialogs.py` now treats an ITEM-flagged object with item id 0")
        lines.append("(Blues House Daisy/Town Map) as a plain text slot, so it wires to the ported")
        lines.append("script instead of the `...` item stub.")
    lines.append("")
    lines.append("## Hidden items (event tiles)")
    lines.append("")
    lines.append("| Map | x | y |")
    lines.append("| --- | --- | --- |")
    for m in maps:
        if not m["hidden_items"]:
            continue
        for h in m["hidden_items"]:
            lines.append(f"| {m['label']} | {h['x']} | {h['y']} |")
    lines.append("")
    lines.append("Hidden items come from `data/events/hidden_item_coords.asm`; the item is the")
    lines.append("`HiddenItems` handler arg in `data/events/hidden_events.asm`. Nearby items are")
    lines.append("read by `src/engine/items/itemfinder.asm` (HiddenItemNear, stride-3 scan over")
    lines.append("map_id, y, x).")
    lines.append("")
    lines.append("## Hidden coins (event tiles)")
    lines.append("")
    lines.append("| Map | x | y |")
    lines.append("| --- | --- | --- |")
    for m in maps:
        if not m["hidden_coins"]:
            continue
        for c in m["hidden_coins"]:
            lines.append(f"| {m['label']} | {c['x']} | {c['y']} |")
    lines.append("")
    lines.append("## Hidden events (event tiles / statues / PCs / switches / slot machines)")
    lines.append("")
    lines.append("| Map | x | y | Handler | Arg |")
    lines.append("| --- | --- | --- | --- | --- |")
    for m in maps:
        if not m["hidden_events"]:
            continue
        for e in m["hidden_events"]:
            lines.append(f"| {m['label']} | {e['x']} | {e['y']} | {e['handler']} | {e['arg']} |")
    lines.append("")
    lines.append("Hidden items/coins/events live in `data/events/hidden_item_coords.asm`,")
    lines.append("`hidden_coins.asm` and `hidden_events.asm`. Generators:")
    lines.append("`gen_hidden_events.py`, `gen_hidden_item_coords.py`, `gen_hidden_coins.py`,")
    lines.append("`gen_hidden_items_text.py`.")
    lines.append("")
    lines.append("## Problem dialog slots (currently \"...\" placeholders)")
    lines.append("")
    lines.append("These are dialog slots that resolve to the `...` stub today but a ported routine")
    lines.append("(or a trivially classifiable static/trainer source) is close at hand.")
    lines.append("")
    lines.append("| Map | Slot | Local label | Pret kind | Port label exists | Suggested action |")
    lines.append("| --- | --- | --- | --- | --- | --- |")
    for m in maps:
        globs = port_global_by_map.get(m["label"], set())
        for s in m["dialog_slots"]:
            if s["status"] in ("STUB_PLACEHOLDER", "TRAINER_STUB",
                               "PORTED_SCRIPT_UNWIRED", "PORTED_SCRIPT_MISSING_EXTERN"):
                target = s.get("local_label")
                exists = target in all_globals or target in globs
                action = {
                    "TRAINER_STUB": "port the text_asm or wire the map",
                    "PORTED_SCRIPT_UNWIRED": "same-named label not in the map file — hand-route",
                    "PORTED_SCRIPT_MISSING_EXTERN": "fix the SCRIPT_OVERRIDES target name",
                    "STUB_PLACEHOLDER": "hand-port the text_asm script or route to a shared handler",
                }[s["status"]]
                lines.append(f"| {m['label']} | {s['slot']} | {s.get('local_label') or '-'} | "
                             f"{s.get('pret_kind') or '-'} | {'Y' if exists else 'n'} | {action} |")
    lines.append("")

    md_path.write_text("\n".join(lines), encoding="utf-8")

    print(f"Wrote {json_path}")
    print(f"Wrote {md_path}")
    print()
    print("Aggregate:")
    for k, v in sorted(map_stats.items()):
        print(f"  {k}: {v}")
    print()
    print("Dialog-slot status totals:")
    for k in sorted(status_count):
        print(f"  {k}: {status_count[k]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
