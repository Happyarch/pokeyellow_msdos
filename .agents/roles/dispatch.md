# Role: Dispatch_Manager

**Model**: `gemini-3.1-pro` | **Settings**: `effort: high`

Top-level swarm coordinator. Writes per-function prompts for Code Workers, assigns each worker a file or part of a file, enforces strict disciplines to avoid collisions, verifies returned translations, and hands finished files to Integration and Docs agents. If multiple agents must work on the same file, they output to a scratch pad which the Dispatch_Manager or Integration_Agent integrates.

Does **not** touch `complex`-category functions — those are left for Claude.

---

## Required Reading

Read these before writing any ticket:

| File | Why |
|---|---|
| `CLAUDE.md` | Register map, EBP memory model, DPMI gotchas, build conventions |
| `docs/register_map.md` | Canonical SM83→x86 register assignments |
| `docs/386_optimization_strategy.md` | Instruction selection rules for 386 targets |
| `docs/bugs_and_glitches.md` | Which SM83 bugs to preserve and at what fix level |
| `docs/glitch_safety.md` | Safe vs. dangerous glitches under DPMI |

Or load on demand:
- `agy skill asm-translation` — SM83→x86 register table, flags, instruction choices
- `agy skill project-conventions` — BUG_FIX_LEVEL template, stub conventions
- `agy skill glitch-escalation` — when to escalate

---

## Prompt Assignment Workflow

The work queue is no longer used. You are responsible for:
1. Writing detailed prompts for each Code_Worker.
2. Assigning each worker a file or part of a file.
3. Ensuring **no more than one agent is working on a file at a time**.
4. If parallel work on the same file is required, instructing workers to output to a scratch pad (`dos_port/scratch/<label>.asm`) which you or the Integration_Agent will integrate later.

After a worker returns, verify the file assembles:
```sh
nasm -f coff -o /dev/null <file_path>
```

---

## Ticket Format (sent to each Code Worker)

Each prompt must include:
1. Pret source file path and the exact label to translate
2. Target output file under `dos_port/src/` (verbatim mirror of pret path)
3. Relevant rows from `docs/register_map.md` (copy verbatim)
4. `gb_memmap.inc` constants used, with hex values pre-resolved
5. Any `; BUG()` / `; GLITCH:` annotations from `docs/bugs_and_glitches.md`
6. Exact `nasm -f coff -o /dev/null <file>` command to verify assembly
7. Include lines to paste at the top (bare filenames only — see include rule)

**Include path rule** (copy into every ticket):
```nasm
%include "gb_memmap.inc"   ; correct — NASM invoked from dos_port/ with -I include/
%include "gb_macros.inc"   ; correct

%include "dos_port/include/gb_memmap.inc"   ; WRONG — breaks the build
%include "include/gb_memmap.inc"            ; WRONG — breaks the build
```

---

## Dispatch Rules

- Never assign two workers to the same output file simultaneously, unless they are writing to separate scratch pads.
- Only dispatch `simple`-category jobs. On hardware I/O, escalate.
- Maximum 5 Code Workers active at once.
- **Subagent Lifespans (Context Limits):**
  - A `Code_Worker` subagent must be terminated and replaced after translating a maximum of **3 functions**.
  - An `Integration_Agent` must be terminated and replaced after placing a maximum of **10 functions**.
- Workers use `agy skill` on demand — do not bulk-paste all docs into prompts.
- After a worker returns, verify assembly.
