---
name: pokeyellow-swarm
description: Orchestrates the multi-agent swarm for translating pokeyellow SM83 assembly to x86. Activate this when asked to run the swarm or translate simple functions in bulk.
---
# Antigravity Pokemon Yellow DOS Port — Agent Swarm

## Overview

Claude Code handles architecture, complex functions, and live-graph wiring.
The swarm handles bulk translation of `simple`-category functions only.

```
Dispatch_Manager (gemini-3.1-pro)       ← coordinator
    ├── Code_Worker_1..5 (gemini-3.5-flash)
    ├── Integration_Agent (gemini-3.5-flash)
    └── Docs_Commit_Agent (gemini-3.1-pro)
```

**Hard boundary**: Swarm places translated code. It does **not** wire functions
into the live game loop. Live-graph connections (`OverworldLoop`, `EnterMap`,
`DelayFrame` callees) are Claude Code only.

---

## Role Files (read your role file before doing anything)

| Role | File |
|---|---|
| Dispatch_Manager | `.agents/roles/dispatch.md` |
| Code_Worker | `.agents/roles/worker.md` |
| Integration_Agent | `.agents/roles/integration.md` |
| Docs_Commit_Agent | `.agents/roles/docs.md` |

---

## Skills (load on demand with `agy skill <name>`)

| Skill | When to load |
|---|---|
| `asm-translation` | Before writing any NASM — register map, flags, 386+ instruction choices |
| `path-map` | Before placing any file |
| `project-conventions` | When a BUG/GLITCH annotation or stub is needed |
| `glitch-escalation` | When hitting a $FF__ register |
| `commit-format` | Before committing |
| `build-and-debug` | Repo layout, build commands, memory-dump debugging |

`register-map`, `386-checklist`, and `bug-check` were retired — their content is
now folded into `asm-translation` (register map + flags + instruction choices)
and `project-conventions` (BUG/GLITCH conventions), which are more complete.
Archived at `.agents/archive/skills/` if you need the old compact form.

---

## Swarm Coordination Interface

The ticketing tools are no longer used. Instead:
- The **Dispatch_Manager** (root agent) writes the prompts for each worker agent.
- Each worker is assigned a specific file or part of a file.
- **Strict parallel editing discipline**: No more than one agent is working on a file at a time. 
- If multiple agents need to work on the same file, they must output to a scratch pad (`dos_port/scratch/`). The Dispatch_Manager or Integration_Agent then integrates those scratch pads into the main file.
- **Flag Preservation**: Agents must be extremely mindful of the zero flags. x86 and SM83 set flags on different instructions. `inc`/`dec` preserve CF but modify ZF/SF/OF/AF/PF. `test`/`cmp`/`and`/`or` set flags, while `mov`/`lea`/`push`/`pop` do NOT touch flags. Do not clobber a flag between its setter and its consumer.

Status pipeline: `needs_translation → in_progress → translated → [wired → verified]`

`wired` and `verified` are Claude Code session transitions only.

---

## Category Definitions

**`simple`** → swarm handles: pure arithmetic, data lookup, flag set/clear,
inventory math, battle formulas, BCD, random numbers. No `$FF__` I/O.

**`complex`** → Claude Code only: anything touching PPU, VGA, OAM, tile cache,
audio, joypad, menus with tile rendering, map transitions, pikachu, link cable.

---

## Swarm Rules

1. **No Claude in the loop.** Swarm does not spawn Claude agents.
2. **Live-graph boundary is inviolable.** No new edges into untested code from
   live-game-loop functions. Translated functions calling each other is fine.
3. **Prompt Assignment.** The Dispatch_Manager writes explicit prompts for each Code_Worker instead of using a ticketing system.
4. **No parallel file edits.** One worker per output file at a time. If parallel work is required on the same file, workers output to `dos_port/scratch/` and the root agent integrates them.
5. **Preserve Flags (ZF/CF) — x86 ≠ SM83**
   **Translating a conditional is not just translating the branch — it's preserving the flag the branch reads.** SM83 and x86 set flags on *different* instructions, so a faithful-looking translation can silently break a `jr z`/`jr c` by clobbering the flag between where it's set and where it's tested.
   - **Identify the exact instruction that sets the flag pret's branch depends on, and make sure nothing between it and the branch disturbs that flag.** Map `jr z/nz` → `jz/jnz` (ZF), `jr c/nc` → `jb/jae` (CF, unsigned) — but only after confirming the flag still holds at the branch.
   - **`inc`/`dec` preserve CF but modify ZF/SF/OF/AF/PF.** So an `inc de`/`dec hl` that pret places between a `sub` and an `sbc` (borrow chain) is safe in x86 too — CF survives. But an `inc`/`dec` between a `cp`/`or`/`and` and a `jr z` **destroys ZF** — pret's `inc hl` after a compare was flag-neutral on SM83 in that spot only because SM83's `ld`/`inc [hl]` differ; re-check each case.
   - **`mov`, `lea`, `movzx`, `push`/`pop` do NOT touch flags** — use `lea esi,[esi+1]` instead of `inc esi`, or reorder, when you must advance a pointer without disturbing a live ZF/CF.
   - **`test`/`cmp`/`and`/`or`/`add`/`sub`/`shl`/`shr` all set flags** — never place one of these between a flag producer and its consumer unless it *is* the producer.
   - SM83 `F: N`/`H` are tracked separately (`[hf_shadow]`, lazy); most routines don't touch them, but DAA/CPL paths do.
   - Related: multi-byte GB values are **big-endian**. GB game data is big-endian; keep it that way. The SM83 stores multi-byte game values high byte first (big-endian). Treat `[EBP+addr]` as big-endian (`hi = [addr]`, `lo = [addr+1]`), exactly as the pret routine does. Do not assume x86 little-endian just because the host is.
6. **No `git add -A`.** Stage only files changed by the current work unit.
7. **No `--no-verify`.** Never skip pre-commit hooks.
8. **Hardware escalation.** `$FF__` hit on a simple job → escalate and fail out.

---

## Adding New Functions

New functions are identified and assigned directly by the Dispatch_Manager via custom prompts.

---

## Agent Invocation Note

Due to dynamic subagent registration, use `TypeName: self` in `invoke_subagent`
and supply the full system prompt + ticket in the `Prompt` field.
