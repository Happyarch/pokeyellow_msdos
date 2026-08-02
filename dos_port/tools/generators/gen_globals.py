"""gen_globals.py — shared helper: declare a generated label `global` in its own
`.inc`, instead of leaving the `global` to the `.asm` that %includes it.

WHY THIS EXISTS. `lint_pret_labels --strict-claims` reported 21 [local_shadow]
findings, all the same shape: a pret label's real definition sat NON-GLOBAL in a
generated assets/*.inc while the code file that included it carried
`global <Label>`. update_label_db then selected the .asm as the label's provider
even though the .asm does not define it, which makes static call attribution and
plain grep both point at the wrong file.

The fix is the pattern assets/trainer_parties.inc already used and the rest did
not: the file that DEFINES a label is the file that DECLARES it global. Then the
provider is the .inc, the shadow disappears, and the `global` in the .asm becomes
a duplicate that should be deleted.

Kept in one module rather than repeated in each generator so the five callers
(gen_menu_strings, gen_textbox_strings, gen_badge_tiles, gen_title_gfx_inc,
gen_intro_gfx_inc) cannot drift apart.
"""
from __future__ import annotations


def insert_globals(lines: list, labels, anchor: str = "section .data") -> list:
    """Insert `global <label>` declarations into a generated .inc's line list.

    Placed immediately before `anchor` when the file has one (the text .inc
    files all open with a `section .data`), otherwise immediately before the
    label's own definition line (`<label>:`), which is how the raw 2bpp/tilemap
    .inc files are shaped. NASM accepts `global` before or after the definition;
    before keeps it visible at the top of the block.

    Returns the same list, mutated, so callers can inline it at the write site.
    """
    labels = [labels] if isinstance(labels, str) else list(labels)
    if not labels:
        return lines

    decls = [f"global {label}" for label in labels]

    if anchor is not None and anchor in lines:
        at = lines.index(anchor)
        lines[at:at] = decls + [""]
        return lines

    # No section anchor: sit the declarations just above the first definition.
    # A definition line is either `Label:` on its own (the 2bpp/tilemap shape) or
    # `Label: db 0x..` all on one line (the short-string shape) — match the prefix
    # so both are found.
    for i, line in enumerate(lines):
        if any(line == f"{label}:" or line.startswith(f"{label}:")
               for label in labels):
            lines[i:i] = decls + [""]
            return lines

    # Nothing matched — fail loudly rather than silently emitting no `global`,
    # which would look like success and leave the local_shadow finding in place.
    raise ValueError(
        f"insert_globals: no anchor {anchor!r} and no definition line for {labels}"
    )
