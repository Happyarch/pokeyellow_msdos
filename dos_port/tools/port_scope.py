#!/usr/bin/env python3
"""port_scope — the ONE reader for tools/port_scope_exclusions.json.

WHY THIS IS A MODULE AND NOT THREE COPIES
The exclusion registry says which pret labels this port is never going to
translate. That answer has to be the same everywhere or it is worse than
useless: a progress report that excludes a label while `label_status` still
lists it as `missing` work sends the next agent to port something the
maintainer already ruled out. Same reason gen_progress_report imports
lint_pret_labels' annotation parser instead of reimplementing it — one fact,
one implementation.

WHAT EXCLUSION MEANS, PRECISELY
  * The label is UNPORTABLE IN THIS FRAMEWORK, not merely unported. "Nobody has
    got to it" is a backlog item; "the port's virtual APU reads this register
    once per audio_tick so a literal translation emits silence" is an exclusion.
  * Being UNUSED IN PRET IS NOT GROUNDS (maintainer, 2026-08-23). Unused pret
    routines are ported anyway when genuinely portable, for completeness and bug
    compatibility, since uncalled code does not run. GetwMoves and
    OverwritewMoves were ported on that basis rather than excluded.
  * Exclusion NEVER hides a row. Every consumer must still show excluded labels,
    marked, with the reason available — it removes them from the SCORED
    denominator and from "what still needs writing", nothing more. An
    unexplained disappearance is exactly the kind of unsupported negative claim
    CLAUDE.md's evidence policy forbids.

EDITING THE REGISTRY IS A MAINTAINER DECISION. An agent adding an entry to make
its own numbers look better is the failure mode the pret_label_allowlist rules
already exist to prevent.
"""
import json
import os

REGISTRY = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                        'port_scope_exclusions.json')


def load(path=REGISTRY):
    """-> {label: {'pret_file': str, 'reason': str}}. Missing file = {}."""
    try:
        with open(path) as fh:
            data = json.load(fh)
    except FileNotFoundError:
        return {}
    out = {}
    for pret_file, entry in (data.get('files') or {}).items():
        for label in entry.get('labels', []):
            out[label] = {'pret_file': pret_file,
                          'reason': entry.get('reason', '')}
    return out


def by_file(path=REGISTRY):
    """-> [(pret_file, {'reason': str, 'labels': [...]}), ...] sorted by file."""
    try:
        with open(path) as fh:
            data = json.load(fh)
    except FileNotFoundError:
        return []
    return sorted((data.get('files') or {}).items())


NOTE = ('out-of-scope labels are EXCLUDED from the counts above and listed '
        'separately; they are declared unportable in tools/port_scope_exclusions.json, '
        'not merely unported. Pass --include-out-of-scope to score them as missing.')
