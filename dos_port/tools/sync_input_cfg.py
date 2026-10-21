#!/usr/bin/env python3
"""Enforce the [keyboard] device line of a POKEMON.CFG, touching nothing else.

Usage: sync_input_cfg.py <cfgfile> <gamepad|keyboard>

- Missing file -> create it from the managed template (device line plus the
  identity [gamepad] mapping when gamepad is wanted).
- Present file -> set the keyboard-section `device = ...` line to want,
  preserving keybindings, comments, blank lines, [audio] device and layout.
  Only the device line is ever managed; a custom file keeps everything else.

Always exits 0 (never fail the build). Prints what it did.
"""

import re
import sys

GAMEPAD_TEMPLATE = (
    "[keyboard]\n"
    "device = gamepad\n"
    "; walks untouched? your system may list a second stick first\n"
    "; (e.g. motion sensors) — relaunch with JOYSTICKTYPE=4axis_2\n"
    "\n"
    "[gamepad]\n"
    "gamepad_a = 1\n"
    "gamepad_b = 2\n"
    "gamepad_select = 3\n"
    "gamepad_start = 4\n"
)
KEYBOARD_TEMPLATE = "[keyboard]\ndevice = keyboard\n"

SECTION_RE = re.compile(r"\[(.*)\]")
DEVICE_RE = re.compile(r"^(\s*)device(\s*)=.*$")


def sync(lines, want):
    """lines: list of str without line endings. Returns (new_lines, changed)."""
    section = ""
    header_idx = None
    device_idx = None
    for i, line in enumerate(lines):
        m = SECTION_RE.match(line.strip())
        if m:
            section = m.group(1).strip().lower()
            if section == "keyboard" and header_idx is None:
                header_idx = i
            continue
        if section != "audio" and DEVICE_RE.match(line):
            # First non-audio device line wins (matches input_cfg's parse:
            # the input row matches everywhere but [audio]).
            if device_idx is None:
                device_idx = i
    newval = "device = %s" % want
    if device_idx is not None:
        m = DEVICE_RE.match(lines[device_idx])
        replacement = "%sdevice%s=%s" % (m.group(1), m.group(2), " " + want)
        if lines[device_idx] == replacement:
            return lines, False
        lines[device_idx] = replacement
        return lines, True
    if header_idx is not None:
        lines.insert(header_idx + 1, newval)
        return lines, True
    return ["[keyboard]", newval] + lines, True


def main():
    path, want = sys.argv[1], sys.argv[2]
    assert want in ("gamepad", "keyboard"), want
    try:
        with open(path, "rb") as f:
            raw = f.read()
    except FileNotFoundError:
        with open(path, "w", newline="") as f:
            f.write(GAMEPAD_TEMPLATE if want == "gamepad" else KEYBOARD_TEMPLATE)
        print("sync_input_cfg: created %s (device=%s)" % (path, want))
        return
    text = raw.decode("ascii", errors="replace")
    lines = text.split("\n")
    # Preserve a trailing newline exactly.
    trailing = lines and lines[-1] == ""
    body = lines[:-1] if trailing else lines
    # Strip \r for matching; input_cfg skips CR, and we re-emit it.
    stripped = [ln[:-1] if ln.endswith("\r") else ln for ln in body]
    cr = [ln.endswith("\r") for ln in body]
    new, changed = sync(stripped, want)
    if not changed:
        print("sync_input_cfg: already device=%s" % want)
        return
    out = []
    use_cr = any(cr)
    for i, ln in enumerate(new):
        suffix = "\r" if (i < len(cr) and cr[i]) or (i >= len(cr) and use_cr) else ""
        out.append(ln + suffix)
    ending = "\n" if trailing else ""
    with open(path, "w", newline="") as f:
        f.write("\n".join(out) + ending)
    print("sync_input_cfg: device -> %s" % want)


main()
