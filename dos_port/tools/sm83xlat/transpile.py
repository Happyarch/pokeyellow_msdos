#!/usr/bin/env python3
"""transpile.py — the one shot. Stages 3-7 of current_plan_script_transpiler.md.

Reads pret's 251 `scripts/*.asm` and writes `dos_port/src/scripts/*.asm`, plus
`bail_report.json` and `coverage.md`. It runs ONCE; the output is committed and
hand-maintained from then on. There is no Makefile wiring, by design — see
README.md.

WHAT IT WILL NOT DO
-------------------
* **Overwrite a file that already exists.** `pallet_town.asm` and
  `trainer_map_script.asm` are hand-written, linked, and in one case the Stage 4
  regression fixture. Emission goes to a shadow directory for those and the
  differences get reported, because silently replacing hand work with tool
  output is exactly the failure a one-shot migration is most likely to cause.
* **Wire anything into the build.** The emitted files are not added to any SRCS
  list. Most reference callees the port does not define yet, which is the
  designed witness — an `extern` the linker enumerates — but a witness is only
  useful when someone is looking at it, not when it breaks everyone's build.

Usage:
    python3 dos_port/tools/sm83xlat/transpile.py            # write output
    python3 dos_port/tools/sm83xlat/transpile.py --dry-run  # report only
    python3 dos_port/tools/sm83xlat/transpile.py --assemble # + nasm each file
"""
from __future__ import annotations

import argparse
import json
import re
import sqlite3
import subprocess
import sys
from collections import Counter, defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import emit          # noqa: E402
import ir            # noqa: E402
import isa           # noqa: E402
import macros        # noqa: E402
import parser as sparser  # noqa: E402
import resolve       # noqa: E402

SHADOW = "emitted_shadow"   # where output goes when a port file already exists

HEADER = """\
; {stem}.asm — translated from pret {pret} by dos_port/tools/sm83xlat.
;
; ONE-SHOT OUTPUT, NOW HAND-MAINTAINED. The transpiler ran once at the SHA
; recorded in dos_port/tools/sm83xlat/README.md and is not re-run; this file is
; ordinary Tier-2 source and editing it is the normal way it changes. There is
; deliberately no DO NOT EDIT header.
;
; Every pret label is preserved verbatim so the file stays line-for-line
; cross-referenceable against the disassembly.
;
; Regions the tool could not lower WITH CERTAINTY are reproduced below as
; commented pret source under a `; BAIL[reason]` banner, and define NO symbol —
; so a reference to one is a link error rather than a plausible wrong lowering.

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_text.inc"
%include "events.inc"
%include "assets/event_constants.inc"
"""

BASE_INCLUDES = ("gb_memmap.inc", "gb_constants.inc", "gb_text.inc",
                 "events.inc", "assets/event_constants.inc")


def port_path(db: Path, pret_file: str) -> str:
    """The output path, read from translation.db rather than re-derived.

    `lint_pret_labels`' `script_misplaced` rule decides where a pret scripts/
    label may live, and it reads the same table. Inventing a snake_case rule
    here would let the output and the linter disagree; reading the oracle makes
    that impossible by construction.
    """
    con = sqlite3.connect(db)
    row = con.execute(
        "select expect_port_file from script_labels where pret_file = ? limit 1",
        (pret_file,)).fetchone()
    con.close()
    if row:
        return row[0]
    stem = re.sub(r"(?<!^)(?=[A-Z])", "_", Path(pret_file).stem).lower()
    return f"dos_port/src/scripts/{stem}.asm"


def transpile_file(f: sparser.ScriptFile, R: resolve.Resolver, abi: dict,
                   pret_src: list) -> emit.Emitted:
    """Two passes, because a bail is contagious through a LOCAL label.

    Pass 1 finds which regions bail. A NASM local label (`.Text`) cannot be
    `extern`, so a region that jumps to `.Text` in a region that bailed has no
    honest lowering either — the target does not exist and never will in this
    file. Emitting it anyway would be an assembly error, which is a worse
    failure than the intended one: an assembly error stops the build for
    everyone, where a link error names exactly the missing routine. So pass 2
    bails those regions too, and reports them under their own reason so the
    cascade is visible rather than looking like 40 independent problems.
    """
    an = ir.analyse(f, R)
    regions = ir.build_regions(f)

    dead_locals = set()
    for _ in range(4):          # a fixed point; the cascade is shallow
        probe = _emit_pass(f, regions, an, R, abi, dead_locals, pret_src)
        # OWNED regions feed this too, and must: the generated asset defines the
        # region's TOP-LEVEL label, but nothing defines its `.locals` — the region
        # is not emitted at all — so a jump to one is just as dead as a jump into
        # a bailed region. Splitting `owned` out of `bails` for reporting must not
        # quietly narrow this set.
        newly = {l for b in probe.bails + probe.owned
                 for l in b["labels"] if "." in l}
        if newly <= dead_locals:
            break
        dead_locals |= newly
    return _emit_pass(f, regions, an, R, abi, dead_locals, pret_src)


def _emit_pass(f, regions, an, R, abi, dead_locals, pret_src) -> emit.Emitted:
    out = emit.Emitted()
    E = emit.Emitter(R, abi)
    # FULL labels, not bare `.tail`. NASM scopes a local to the preceding GLOBAL
    # label, so `A.Text2` and `B.Text2` are different symbols; keying on the tail
    # killed every `.Text2` in a file when any one of them died, which both
    # inflated target-region-bailed and IS the local-label-scope-collision class.
    E.dead_locals = set(dead_locals)

    scope = None
    for region in regions:
        # The global label a bare `.local` inside this region is scoped to —
        # NASM's "most recent global label", which region labels give directly
        # since they arrive already qualified and in source order. A region with
        # no label of its own inherits the previous region's scope, exactly as a
        # fall-through continuation does in the assembler.
        for lab in region.labels:
            scope = lab.split(".")[0] if "." in lab else lab
        E.local_scope = scope

        body: list = []
        failed = None
        # Snapshot the self-test counter: a region that bails contributes no
        # emitted lines, so its would-be `test r, r` must not be counted either
        # or the invariant check compares an emitted total against a source
        # total that includes discarded work.
        self_tests_before = out.self_tests
        # A region whose label the port's generated assets ALREADY define is not
        # ours to emit: assets/trainer_headers.inc owns every battle-text stream.
        # Emitting it too is a duplicate definition of the same data, which the
        # static gate reports as dup_def -- correctly.
        owned = [l for l in region.labels
                 if l in R.asset_labels and l not in R.shadow_exempt]
        if owned:
            out.owned_regions += 1
            lo = region.items[0].line.lineno
            hi = region.items[-1].line.lineno
            out.owned.append({
                "file": f.path, "region": region.name, "labels": region.labels,
                "reason": "owned-by-generated-assets",
                "detail": f"{owned[0]} is already defined in "
                          f"{R.symbol_include.get(owned[0], 'a generated asset')}",
                "at": region.items[0].where, "lines": [lo, hi]})
            # Deliberately NOT the full banner + verbatim pret dump the other
            # bail paths emit. This region is Tier-1 data the port already
            # generates, so nobody will ever hand-translate it: reproducing the
            # pret source would be 5,975 lines of noise across 67 files (32% of
            # all bails) describing work that does not exist. One line naming the
            # owning asset is the whole useful content.
            out.lines.append("")
            _owner = R.symbol_include.get(owned[0])
            out.lines.append(
                f"; {region.name} ({f.path}:{lo}-{hi}) — not re-emitted: "
                + (f"{owned[0]} is already defined in {_owner}."
                   if _owner else
                   f"{owned[0]} is already defined elsewhere in the port."))
            continue

        skip = 0
        for idx, it in enumerate(region.items):
            if skip:
                skip -= 1          # consumed by a fused idiom on an earlier item
                continue
            E.pending_callee = None if region.is_data else _next_callee(region.items, idx)
            try:
                lines = None
                if not region.is_data:
                    fused = E.fuse(region.items, idx, an, out)
                    if fused is not None:
                        lines, consumed = fused
                        skip = consumed - 1
                if lines is None:
                    lines = E.data(it, out) if region.is_data else E.item(it, an, out)
            except emit.Bail as b:
                failed = (b, it)
                break
            for lab in it.labels:
                body.append(f"{_label_text(lab)}:")
            body.extend("    " + l if not l.endswith(":") and not l.startswith(";")
                        else l for l in lines)

        if failed is not None:
            b, it = failed
            out.self_tests = self_tests_before
            out.bailed_regions += 1
            lo = region.items[0].line.lineno
            hi = region.items[-1].line.lineno
            out.bails.append({
                "file": f.path, "region": region.name,
                "labels": region.labels,
                "reason": b.reason, "detail": b.detail,
                "at": it.where, "lines": [lo, hi],
            })
            out.lines.append("")
            out.lines.append(f"; ---------------------------------------------------------------------------")
            out.lines.append(f"; BAIL[{b.reason}] {region.name} "
                             f"({f.path}:{lo}-{hi}) — at {it.where}: {b.detail}")
            out.lines.append(f"; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.")
            out.lines.append(f"; ---------------------------------------------------------------------------")
            for n in range(lo, hi + 1):
                out.lines.append("; PRET| " + _neutralise(pret_src[n - 1].rstrip()))
            continue

        # A NASM local label is scoped to the last non-local label above it. A
        # bailed region between two pret regions removes its global anchor, so
        # two pret `.Text`s that lived in different scopes can collapse into one
        # and collide. Bail the later region rather than emit a redefinition.
        locals_here = {l for l in region.labels if "." in l}
        short = {"." + l.split(".")[-1] for l in locals_here}
        if short & out.emitted_locals and not any(
                l in out.emitted_globals for l in region.labels if "." not in l):
            out.bailed_regions += 1
            lo = region.items[0].line.lineno
            hi = region.items[-1].line.lineno
            out.bails.append({
                "file": f.path, "region": region.name, "labels": region.labels,
                "reason": "local-label-scope-collision",
                "detail": f"{sorted(short & out.emitted_locals)} would redefine a "
                          f"local label already emitted in this scope",
                "at": region.items[0].where, "lines": [lo, hi]})
            out.lines.append("")
            out.lines.append("; ---------------------------------------------------------------------------")
            out.lines.append(f"; BAIL[local-label-scope-collision] {region.name} "
                             f"({f.path}:{lo}-{hi})")
            out.lines.append("; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.")
            out.lines.append("; ---------------------------------------------------------------------------")
            for n in range(lo, hi + 1):
                out.lines.append("; PRET| " + _neutralise(pret_src[n - 1].rstrip()))
            continue

        for lab in region.labels:
            if "." in lab:
                out.emitted_locals.add("." + lab.split(".")[-1])
            else:
                out.emitted_globals.add(lab)
                out.emitted_locals.clear()   # a new global opens a new scope

        out.ok_regions += 1
        for lab in region.labels:
            if not lab.startswith(".") and "." not in lab:
                out.globals_.append(lab)
        out.lines.append("")
        # SEAM RESET for the *ReuseHL family. `event_byte` is assembly-time state
        # tracking which byte of wEventFlags ESI points at, and it is only sound
        # while the emitted sequence matches pret's. A bailed region between two
        # of these breaks that correspondence, and so does entering a region from
        # anywhere but its predecessor. Resetting at every region head forces the
        # next event macro to reload the pointer: at worst one redundant load,
        # where the alternative is reading the wrong flag.
        out.lines.append("%assign event_byte -1")
        # Same reset for the *ReuseA family's tracker: `event_byte_a` says which
        # byte AL holds, and entering a region from anywhere but its emitted
        # predecessor makes that claim unfounded in exactly the same way.
        out.lines.append("%assign event_byte_a -1")
        out.lines.extend(body)

    return out


def _next_callee(items, i: int, window: int = 8):
    """The callee a register load is setting up for, if one is within reach.

    pret writes the argument loads immediately before the call, so a short
    forward window finds the right one. The window is deliberately short: a
    "callee" ten instructions and a branch away is not the one this load is for,
    and pretending otherwise would apply the wrong ABI entry.
    """
    for j in range(i + 1, min(i + 1 + window, len(items))):
        it = items[j]
        d = it.decoded
        if d is not None and d.effect.kind == "call" and d.classes \
                and d.classes[-1] == isa.CLS_IMM:
            return d.operands[-1]
        if d is not None and d.effect.kind in ("branch", "ret"):
            return None            # control leaves; the call is not ours
        if it.kind == sparser.KIND_MACRO and it.macro is not None \
                and it.macro.cls == macros.CODE_CALL and it.line.operands:
            return it.line.operands[0].strip()
    return None


#: An annotation keyword sitting in annotation position inside COPIED pret source
#: parses as a real annotation. `lint_pret_labels` read one bailed region's
#: verbatim `; BUG(...)` comment as a free-form BUG claim and failed the gate —
#: correctly, by its own rules. The keyword is moved out of that position so the
#: copy stays readable and stops being a claim this port is making.
_ANNOT = re.compile(r"(;\s*)(BUG|GLITCH|DEVIATION|STUB)\b")


def _neutralise(line: str) -> str:
    return _ANNOT.sub(lambda m: f"{m.group(1)}[pret] {m.group(2)}", line)


def _label_text(lab: str) -> str:
    # A pret local label keeps its pret spelling; NASM local labels are the same
    # `.name` form, so the scoping survives translation unchanged.
    return "." + lab.split(".")[-1] if "." in lab else lab


def render(f: sparser.ScriptFile, out: emit.Emitted, R: resolve.Resolver,
           sources=None, group=None) -> str:
    stem = Path(f.path).stem
    sources = sources or [f.path]
    parts = [HEADER.format(stem=stem, pret=", ".join(sources))]

    body = "\n".join(out.lines)
    used = set(ir._IDENT_RE.findall(body))
    defined = {l.split(":")[0].strip()
               for l in out.lines if l.rstrip().endswith(":")}

    # Every header whose symbols this file actually uses. Derived rather than
    # guessed: a fixed include list either misses one (assembly error) or pulls
    # in all of them (slow, and hides what the file really depends on).
    extra = sorted({R.symbol_include[n] for n in used
                    if n in R.symbol_include} - set(BASE_INCLUDES))
    for inc in extra:
        parts.append(f'%include "{inc}"')

    # A referenced label this file does not define is EXTERN. Most are labels in
    # regions that bailed or that another owner emits (the generated trainer
    # tables); the point is that the failure lands at LINK time, naming the exact
    # missing routine, rather than at assembly time stopping everyone's build.
    for name in sorted(used):
        if name in defined or name in R.port_symbols or name in out.externs:
            continue
        if (name in R.script_labels or name in R.asset_labels) \
                and name not in defined:
            out.externs.add(name)

    if out.globals_:
        parts.append("")
        for g in sorted(set(out.globals_)):
            parts.append(f"global {g}")

    if out.externs:
        parts.append("")
        for e in sorted(out.externs):
            if e in defined:
                continue
            note = "" if e in R.port_symbols else "   ; NOT YET DEFINED IN THE PORT"
            parts.append(f"extern {e}{note}")

    # File-local equs: the script's own dw_const constants, and any pret RAM
    # symbol gb_memmap.inc has no equ for (address from pokeyellow.sym, the
    # linker's own table). Both follow the precedent set by the hand-written
    # pallet_town.asm, which does exactly this.
    consts, rams = _file_equs(group or [f], out, R)
    if consts:
        parts.append("")
        parts.append("; Script constants — pret defines these via dw_const in this file.")
        for k, v in consts:
            parts.append(f"{k:<46} equ {v}")
    if rams:
        parts.append("")
        parts.append("; pret RAM symbols gb_memmap.inc does not carry. Addresses are"
                     " rgblink's,")
        parts.append("; read from pokeyellow.sym — not inferred.")
        for k, v in rams:
            parts.append(f"{k:<46} equ 0x{v:04X}")

    parts.append("")
    parts.append("; Code and data are emitted in pret's SOURCE ORDER, in one section.")
    parts.append("; That is not cosmetic: a NASM local label binds to the last")
    parts.append("; non-local label above it, so hoisting the text streams into a")
    parts.append("; separate section rebound every `.Text` to the wrong parent.")
    parts.append("section .text")
    parts.extend(out.lines)
    parts.append("")
    return "\n".join(parts)


SCRIPT_CONST_VALUES: dict = {}


def _index_script_constants(files) -> None:
    """Every TEXT_*/SCRIPT_* constant in the corpus, with its dw_const value.

    Indexed corpus-wide, not per file, because scripts reference each other's
    constants: AgathasRoom sets `SCRIPT_CHAMPIONSROOM_PLAYER_ENTERS`, which
    ChampionsRoom.asm defines. A per-file table emitted an undefined symbol at
    exactly those cross-map handoffs — which are the interesting ones.
    """
    for f in files:
        value = None
        for it in f.items:
            if it.head in ("def_text_pointers", "def_script_pointers"):
                value = 1 if it.head == "def_text_pointers" else 0
            elif it.head == "dw_const" and len(it.line.operands) >= 2 \
                    and value is not None:
                SCRIPT_CONST_VALUES.setdefault(it.line.operands[1].strip(), value)
                value += 1


def _file_equs(group, out: emit.Emitted, R: resolve.Resolver):
    text = "\n".join(out.lines)
    used = set(ir._IDENT_RE.findall(text))
    consts = []
    seen = set()
    for f in group:
        value = None
        for it in f.items:
            if it.head in ("def_text_pointers", "def_script_pointers"):
                value = 1 if it.head == "def_text_pointers" else 0
            elif it.head == "dw_const" and len(it.line.operands) >= 2 \
                    and value is not None:
                name = it.line.operands[1].strip()
                if name in used and name not in seen:
                    seen.add(name)
                    consts.append((name, str(value)))
                value += 1
    # Anything still unaccounted for that is a script constant defined in ANOTHER
    # map's file — a cross-map script handoff.
    for name in sorted(used - seen):
        if name in SCRIPT_CONST_VALUES and name not in R.port_symbols:
            consts.append((name, str(SCRIPT_CONST_VALUES[name])))
    rams = sorted((n, R.missing_ram[n]) for n in used if n in R.missing_ram)
    return consts, rams


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--root", type=Path, default=HERE.parents[2])
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--assemble", action="store_true",
                    help="run nasm over every emitted file (Stage 5)")
    args = ap.parse_args(argv)

    root = args.root.resolve()
    port = root / "dos_port"
    db = port / "tools" / "translation.db"

    files = sparser.parse_corpus(root)
    script_labels, script_consts = set(), set()
    for f in files:
        for lab in f.labels:
            script_labels.add(lab.name)
            script_labels.add(lab.qualified)
        for it in f.items:
            if it.head == "dw_const" and len(it.line.operands) >= 2:
                script_consts.add(it.line.operands[1].strip())

    _index_script_constants(files)
    R = resolve.build(root, port, script_labels, script_consts)
    abi_path = HERE / "tables" / "abi.json"
    abi = json.loads(abi_path.read_text())["callees"] if abi_path.exists() else {}

    reasons = Counter()
    per_file = {}
    all_bails = []
    all_owned = []
    total_ok = total_bail = total_owned = 0
    written = []
    shadowed = []

    by_dest = defaultdict(list)
    for f in files:
        by_dest[port_path(db, f.path)].append(f)

    for rel, group in sorted(by_dest.items()):
        # If the destination is a HAND-WRITTEN port file we are not going to
        # overwrite, we are producing a COMPARISON artifact, not a linkable one.
        # The "this label is already defined in the port" rule must not apply to
        # that file's own labels — it is the whole point of the comparison. Left
        # in place, it silently emptied the Stage 4 fixture: 17 emitted routines
        # became 7, and 0 of them overlapped the hand port.
        dest_probe = root / rel
        shadow_exempt = set()
        if dest_probe.exists() and resolve.TOOL_OUTPUT_MARKER not in \
                dest_probe.read_text(encoding="utf-8", errors="replace")[:1024]:
            shadow_exempt = set(re.findall(
                r"^([A-Za-z_]\w*):", dest_probe.read_text(encoding="utf-8",
                                                          errors="replace"), re.M))
        R.shadow_exempt = shadow_exempt

        merged = emit.Emitted()
        sources = []
        for f in group:
            pret_src = (root / f.path).read_text(encoding="utf-8").splitlines()
            out = transpile_file(f, R, abi, pret_src)
            sources.append(f.path)
            merged.lines.extend(out.lines)
            merged.externs |= out.externs
            merged.globals_.extend(out.globals_)
            merged.bails.extend(out.bails)
            merged.owned.extend(out.owned)
            merged.ok_regions += out.ok_regions
            merged.bailed_regions += out.bailed_regions
            merged.owned_regions += out.owned_regions
            merged.self_tests += out.self_tests
        out = merged
        f = group[0]
        text = render(f, out, R, sources, group)
        total_ok += out.ok_regions
        total_bail += out.bailed_regions
        total_owned += out.owned_regions
        for b in out.bails:
            reasons[b["reason"]] += 1
        all_bails.extend(out.bails)
        all_owned.extend(out.owned)
        per_file[f.path] = {"ok_regions": out.ok_regions,
                            "bailed_regions": out.bailed_regions,
                            "owned_regions": out.owned_regions,
                            "reasons": sorted({b["reason"] for b in out.bails})}

        dest = root / rel
        # Protect HAND-WRITTEN port files, not the tool's own previous output.
        # Once the one shot has been committed every destination exists, so a
        # bare `dest.exists()` redirected everything to the shadow directory and
        # silently stopped updating the real files — the run reported success
        # while writing nothing where it mattered. The marker distinguishes them.
        if dest.exists() and resolve.TOOL_OUTPUT_MARKER not in \
                dest.read_text(encoding="utf-8", errors="replace")[:1024]:
            dest = HERE / SHADOW / dest.name
            shadowed.append(rel)
        if not args.dry_run:
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_text(text)
        written.append(str(dest.relative_to(root)) if not args.dry_run else rel)

        findings = emit.check_invariants(text, out.self_tests)
        if findings:
            print(f"INVARIANT VIOLATION in {rel}: {findings}", file=sys.stderr)
            return 3

    # COVERAGE EXCLUDES THE OWNED REGIONS FROM ITS DENOMINATOR. They are Tier-1
    # data the port's generators already define; the tool must not emit them
    # (a second definition is a dup_def the static gate catches), so they are not
    # work it failed to do and counting them as bails understated it by ~10
    # points. They are still printed, and still listed in bail_report.json --
    # excluded from a ratio, not hidden.
    print(f"regions: {total_ok} lowered, {total_bail} bailed "
          f"({100.0 * total_ok / max(1, total_ok + total_bail):.1f}% lowered), "
          f"{total_owned} owned by generated assets (excluded — not work)")
    for r, n in reasons.most_common():
        print(f"  {n:5d}  {r}")
    if shadowed:
        print(f"\n{len(shadowed)} file(s) already exist in the port and were NOT "
              f"overwritten; output went to {SHADOW}/:")
        for s in shadowed:
            print(f"  {s}")

    if not args.dry_run:
        (HERE / "tables" / "bail_report.json").write_text(json.dumps({
            "_comment": "Every region the transpiler refused to lower. One entry "
                        "per region; the region defines no symbol in the output.",
            "_owned_comment": "`owned` is NOT a bail list. Those regions are "
                              "Tier-1 data the port's generators already define, "
                              "so the tool must not emit them at all — emitting "
                              "one would be a duplicate definition. They describe "
                              "no outstanding work and are excluded from the "
                              "coverage denominator; they are listed here so the "
                              "exclusion stays auditable.",
            "regions_lowered": total_ok,
            "regions_bailed": total_bail,
            "regions_owned": total_owned,
            "by_reason": dict(reasons),
            "per_file": per_file,
            "bails": all_bails,
            "owned": all_owned,
        }, indent=1))

    if not args.dry_run:
        (HERE / "transpile_report.md").write_text(_report(
            total_ok, total_bail, total_owned, reasons, per_file, shadowed,
            written))

    if args.assemble:
        return _assemble(root, port, written)
    return 0


def _report(total_ok, total_bail, total_owned, reasons, per_file, shadowed,
            written) -> str:
    total = total_ok + total_bail
    L = ["# sm83xlat — the one shot (Stages 3-7)\n",
         "Generated by `transpile.py`. Every figure is a measurement over pret's",
         "`scripts/*.asm` at the SHA in README.md; re-run the tool rather than",
         "quoting this file.\n",
         f"- regions lowered: **{total_ok} / {total} "
         f"({100.0 * total_ok / max(1, total):.1f}%)**",
         f"- regions owned by generated assets: **{total_owned}** — excluded from"
         f" the ratio above. These are Tier-1 data the port already generates, so"
         f" the tool must not emit them; they are not work it failed to do."
         f" Listed in `tables/bail_report.json` under `owned`.",
         f"- output files: **{len(written)}** "
         f"(251 pret files merge into 224 port files — 26 maps are split across "
         f"two or three pret sources)",
         f"- files not overwritten because the port already had one: "
         f"{len(shadowed)}\n",
         "## What a bail means\n",
         "A bailed region emits its verbatim pret source as a comment and **no**",
         "symbol. Anything referencing it fails to LINK, naming the exact missing",
         "routine. That is the entire safety argument: the failure mode is a loud",
         "missing symbol, never a plausible wrong behaviour that assembles, runs,",
         "and reads the wrong byte.\n",
         "## Reason codes\n",
         "| reason | regions | what it means |", "|---|---:|---|"]
    meaning = {
        "target-region-bailed": "a CASCADE: this region jumps to a local label in a "
            "region that bailed. A NASM local label cannot be `extern`, so there is "
            "no honest lowering. Clearing an upstream bail clears these too",
        "owned-by-gen_map_script_tables": "the trainer-header tables are already "
            "generated into assets/map_script_tables.inc; emitting them here would "
            "put the same data under two owners",
        "text-script-mart-item-list": "script_mart carries a variadic item list "
            "(db _NARG / db \\# / db -1), which is Tier-1 data owned by a generator; "
            "its seven zero-operand TX_SCRIPT_* siblings lower normally",
        "host-pointer-in-16bit-reg": "pret puts a pointer in DE (16-bit DX here); a "
            "port HOST address is 32 bits and the callee has no abi.json entry",
        "event-byte-assembly-state": "a *Reuse* event macro whose expansion depends "
            "on the assembly-time event_byte DEF carried from a line above",
        "predef-leaves-parent-bank-in-a": "pret's predef leaves the parent ROM bank in A and a direct call "
            "does not, and dataflow shows a live reader of A",
        "pointer-domain-unknown": "HL is dereferenced where the GB/HOST domain is not "
            "proven on every path",
        "bit-clobbers-live-carry": "SM83 `bit` preserves C, x86 `test` clears it, and "
            "C is live — no short x86 form gives the new Z and the old C",
        "bank-expression": "BANK(x) needs a port-side bank constant per target",
        "inline-text-db": "a quoted glyph run — Tier-1 data, belongs to a generator",
        "hl-half-register-access": "`ld l, a` — ESI's low byte is not addressable in "
            "32-bit mode without REX",
        "local-label-scope-collision": "an intervening bail removed the global anchor, "
            "so two pret locals would collide in one NASM scope",
        "event-range-macro": "SetEventRange/ResetEventRange expand to a "
            "variable-length run driven by assembly-time arithmetic",
        "screen-coord-projection": "the port's tilemap stride is context-dependent; a "
            "rule here would be a guess",
        "add-hl-r16": "SM83 `add hl,r16` leaves Z alone and wraps at 16 bits; ESI is 32",
        "pikachu-table-index": "needs (X_id - Table) / N across object files",
        "checkevent-carry-form": "the 2-arg CheckEvent returns the bit in CARRY; the "
            "port macro is 1-arg only",
        "unresolved-symbol": "a name that resolves in no namespace",
        "ld-via-bc-de": "`ld a, [bc]` needs a 16-bit GB pointer in BX/DX",
        "macro-arity-unmodelled": "a port macro exists but not at this argument count",
        "unknown-macro": "no row in macros.py",
    }
    for r, n in reasons.most_common():
        L.append(f"| `{r}` | {n} | {meaning.get(r, '')} |")
    L.append("")
    L.append("## Files with the most bailed regions\n")
    L.append("| file | lowered | bailed |")
    L.append("|---|---:|---:|")
    worst = sorted(per_file.items(), key=lambda kv: -kv[1]["bailed_regions"])[:15]
    for path, d in worst:
        L.append(f"| `{path}` | {d['ok_regions']} | {d['bailed_regions']} |")
    L.append("")
    return "\n".join(L) + "\n"


def _assemble(root: Path, port: Path, written) -> int:
    """Stage 5 — every emitted file through nasm, exactly as the Makefile does."""
    bad = []
    for rel in written:
        p = root / rel if not str(rel).startswith("/") else Path(rel)
        if not p.exists():
            continue
        r = subprocess.run(
            ["nasm", "-f", "coff", "-I", "include/", "-I", ".",
             "-D", "BUG_FIX_LEVEL=0", "-o", "/dev/null", str(p.resolve())],
            cwd=port, capture_output=True, text=True)
        if r.returncode != 0:
            bad.append((str(rel), r.stderr.strip().splitlines()[:4]))
    print(f"\nassemble: {len(written) - len(bad)}/{len(written)} files assemble clean")
    for name, err in bad[:20]:
        print(f"  FAIL {name}")
        for line in err:
            print(f"       {line}")
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main())
