# Antigravity Pokemon Yellow DOS Port

## General Rules & Disciplines

### Preserve Flags (ZF/CF) — x86 ≠ SM83

**Translating a conditional is not just translating the branch — it's preserving
the flag the branch reads.** SM83 and x86 set flags on *different* instructions,
so a faithful-looking translation can silently break a `jr z`/`jr c` by clobbering
the flag between where it's set and where it's tested. This has bitten real
routines (see the `lea esi,[esi+1]`-instead-of-`inc` fix in `pikachu_status.asm`).

- **Identify the exact instruction that sets the flag pret's branch depends on,
  and make sure nothing between it and the branch disturbs that flag.** Map
  `jr z/nz` → `jz/jnz` (ZF), `jr c/nc` → `jb/jae` (CF, unsigned) — but only after
  confirming the flag still holds at the branch.
- **`inc`/`dec` preserve CF but modify ZF/SF/OF/AF/PF.** So an `inc de`/`dec hl`
  that pret places between a `sub` and an `sbc` (borrow chain) is safe in x86
  too — CF survives. But an `inc`/`dec` between a `cp`/`or`/`and` and a `jr z`
  **destroys ZF** — pret's `inc hl` after a compare was flag-neutral on SM83 in
  that spot only because SM83's `ld`/`inc [hl]` differ; re-check each case.
- **`mov`, `lea`, `movzx`, `push`/`pop` do NOT touch flags** — use `lea
  esi,[esi+1]` instead of `inc esi`, or reorder, when you must advance a pointer
  without disturbing a live ZF/CF.
- **`test`/`cmp`/`and`/`or`/`add`/`sub`/`shl`/`shr` all set flags** — never place
  one of these between a flag producer and its consumer unless it *is* the
  producer.
- SM83 `F: N`/`H` are tracked separately (`[hf_shadow]`, lazy) — see the register
  table above; most routines don't touch them, but DAA/CPL paths do.
- Related: multi-byte GB values are **big-endian** — see "Data Endianness" below.

### Data Endianness (preserve pret byte order)

**GB game data is big-endian; keep it that way.** The SM83 stores multi-byte
game values **high byte first** (big-endian): mon HP, MaxHP, the five stats,
OT ID, EXP, and every other multi-byte field in the party/box/`wLoadedMon`
structs. This is load-bearing for pret cross-reference *and* for the Gen-2
byte-identical-struct rule — **do not** re-store any GB value in x86-native
little-endian order.

- **Reading a multi-byte GB value:** treat `[EBP+addr]` as big-endian
  (`hi = [addr]`, `lo = [addr+1]`), exactly as the pret routine does. Do not
  assume x86 little-endian just because the host is.
- **Home/shared routines must match pret's byte order.** `PrintNumber`
  (`home/print_num.asm`) reads its source **big-endian** — the first byte at
  `DE` is most-significant (pret loads it into the high slot of `hNumToPrint`).
  A prior port revision read it little-endian; that was a latent divergence
  (harmless only because every caller so far passed 1-byte values) and is now
  fixed. When you translate any routine that consumes a multi-byte value,
  verify the endianness against the pret source rather than the x86 default.
- **Flags caveat that often rides along:** SM83 16-bit math builds values
  hi-then-lo; when porting a borrow/carry chain (`sub`/`sbc`) that walks such a
  value, remember `inc`/`dec` on the pointer preserve CF (unlike some other x86
  ops), so the borrow survives the pointer step — but a `cmp`/`add`/`sub`/`test`
  between the halves will clobber it.

### Other Hard Conventions

- **Preserve pret Labels.** Keep pret label names exactly as they are in the SM83 disassembly. Add aliases alongside if necessary, but never replace.
- **Data vs. Code (Two-tier rule).** Generators write only `assets/*.inc` (Tier 1 data). Human-owned behavior goes in `.asm` (Tier 2 code). Never hand-encode charmap strings in `.asm`—always use Python generators.
- **Stub Conventions.** Put stubs in subsystem `*_stubs.asm` files, never in the source-mirror file. When a real routine lands, delete the stub.
- **Bug/Glitch Annotations.** Wrap known bug fixes in `%if BUG_FIX_LEVEL >= ...` blocks and preserve original behavior in `%else`. Document glitches with `GLITCH:` safety comments.
- **Hardware I/O Boundary.** Do not translate GB I/O register accesses (`$FF__`) directly. Emit `; TODO-HW:` comments instead. Escalation may be required.
- **Gen 2 Compatibility.** Keep Pokémon party/box data structures byte-identical to Gen 1. Never shrink or repurpose bytes (especially offset 7, the catch rate byte).
- **Commit Policy.** Stage only files changed by the current work unit (`git add <exact files>`). No `git add -A` for unrelated changes. Never skip pre-commit hooks (`--no-verify`).
- **Debugging.** Do not debug by staring at the screen. Use memory dumps (`DUMP.BIN`) or back-buffer dumps (`FRAME.BIN`) for ground truth.

## Current Plans Workflow

Active multi-step implementation plans live as `docs/current_plan_<topic>.md`.
- Always scan `docs/current_plan_*.md` at the start of a session or task to see open work items.
- Check off stages `[x]` as they complete.
- When a plan is fully complete, archive it to `docs/plans/<topic>.md`.

**Active Plans Reference:**
- `docs/current_plan_script_engine.md` (gen-1 script system)
- `docs/current_plan_overworld_port.md` (overworld port, VRAM tile-slot defect)
- `docs/current_plan_items.md` (item/bag layer)
- `docs/current_plan_battle_ui.md` (battle-UI layout pipeline + widescreen redesign)
- `docs/current_plan_map_tool.md` (overworld map tool)
- `docs/current_plan_macros.md` (port pret's portable RGBDS macros to NASM)
*(See `CLAUDE.md` for completed/archived plans and finer details.)*

## Swarm Workflow

If you need to perform bulk translation of `simple`-category functions, please activate the swarm skill:
`agy skill pokeyellow-swarm`
This skill will load the full swarm coordinator role, agent definitions, and swarm-specific guidelines.
