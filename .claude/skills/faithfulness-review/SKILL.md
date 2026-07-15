---
name: faithfulness-review
description: Pret-fidelity review gate for the Pokémon Yellow DOS port. Invoke BEFORE committing any change that touches a pret-labeled routine (any routine whose name comes from the pret disassembly), when reviewing such a change, or when asked to check a translation's faithfulness. Provides the faithdiff / lint_pret_labels / label_status / golden-differ workflow and the justification rules for added or dropped calls. Triggers: "review this translation", "is this faithful to pret", "faithdiff", "lint labels", "pre-commit fidelity check", "goldencheck".
---

# Faithfulness Review Gate

The last four status-screen bugs (sprite bleed-in, HUD tile-slot clobber, missing
PTile, spurious ▼) shared one root cause: generalizing from the port's own code
instead of reading pret's specific routine. All four were mechanically detectable.
This gate makes that class of divergence fail a check instead of surviving to the
user. All tools live in `dos_port/tools/`; they read `translation.db`, which is
**always rescan-derived — never edit it by hand or write it from an agent.**

## The gate (run before committing a change that touches a pret-labeled routine)

1. **`tools/faithdiff <Label>`** for every pret-labeled routine you touched.
   It diffs the pret vs port call graph and named-WRAM/HRAM store set.
   - Every unsuppressed **ADDED/DROPPED** line must be either (a) fixed, or
     (b) justified **in the commit message** (what diverged and why it must).
   - Global translation boundaries (DelayFrame plumbing, TODO-HW, banking,
     scroll-register mirrors) are already suppressed in
     `tools/faithdiff_suppress.json` — add there only symbols that are expected
     on one side of *every* routine, with a why. Routine-specific divergence
     never goes in the suppression file; it goes in the commit message.
2. **`tools/lint_pret_labels`** — must exit 0 before committing. It rescans the
   tree (so it sees your change) and enforces: pret-named globals live in the
   path-mirrored file or a `*_stubs.asm` (else the relocation allowlist
   `tools/pret_label_allowlist.json` needs an entry with a why); stubs stay
   ret-only; no duplicate global defs (silent-shadow trap); extern comments
   point at stub files that still define the symbol.
3. **Run every golden scenario whose compared surface could observe the change.**
   Use `make -C dos_port goldencheck SCENARIO=<name>` for targeted coverage,
   `make -C dos_port fidelity` for the core pre-commit tier, and
   `make -C dos_port fidelity-full` when the change can affect long-tail
   scenarios. Do not select scenarios only by whether the routine draws pixels:
   WRAM datastruct flows are first-class fidelity evidence.

   Subsystem guide:
   - Status, START, overworld, party, bag, options, trainer card, pokédex, naming,
     battle HUD/menu, and streamed dialog changes need their matching rendered
     scenario(s).
   - Party/bag/dex/add-mon/item-effect data mutations need the relevant
     **datastruct** scenario(s), even if the changed path renders nothing.
   - Text printers and NPC/sign dialog need `sign_pallet` or a new
     dialog-bearing scenario if `sign_pallet` does not exercise the path.
   - Battle UI/menu changes need the relevant battle/menu tier
     (`battle_intro`, `battle_menu`, `move_selection`, `ball_catch`, or the
     core/full target that covers them).

   A new legitimate divergence needs a mask **with a written justification** in
   `tools/golden_diff.py` — never a bare mask. If an OPEN finding owns the
   divergence, the mask's why-string must carry that finding id so retiring the
   finding greps to the masks that must be deleted.

## While translating (before writing code)

- `tools/label_status --callees <Label>` — classifies every call target of the
  pret routine as translated / relocated / stub / missing, so you know what to
  extern vs stub before writing a line. Detail: `asm-translation` skill, step 2.
- Retiring a stub? `tools/label_status --callers <Label>` is the retirement
  checklist (repoint extern comments; audit callers translated against stub-era
  behavior). Detail: `project-conventions` skill, stub rule 5.

## After the change lands

Run `tools/update_label_db` so the DB reflects the tree. Skipping it is
self-healing (the next scan fixes it), never corrupting — but the next session's
`label_status` answers will be stale until someone rescans.

## Reviewer's checklist for justifications

A commit that adds/drops a call on a pret-labeled routine must say, per label:
- the pret line(s) it diverges from (file:label reference),
- why the divergence is forced (HAL boundary, unported dependency, documented
  port deviation) — "the port's other screens do it this way" is exactly the
  reasoning this gate exists to reject,
- what retires it, if it's interim (which plan/wave, or "permanent, by design").
