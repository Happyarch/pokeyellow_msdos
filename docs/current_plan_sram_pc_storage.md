# Current Plan: SRAM emulation + Bill's PC box storage (in-memory tier)

> **Gate — run the STRICT linter, every time.** `dos_port/tools/lint_pret_labels`
> alone is not sufficient: it does not gate on `legacy_annotation`, `stale_provider`,
> `local_shadow` or `hand_encoded_text`. Record the per-class counts from
> `dos_port/tools/lint_pret_labels --strict-claims` **before** you start, run both
> modes before committing, and compare per class. A class that grew is your
> regression to fix now. Do not quote a finding count from this file, CLAUDE.md, a
> skill or a memory as evidence that a class is clean — re-measure it.

**Status:** not started. Measured against the linked build at HEAD `76115615`
(2026-07-28).

**Ownership.** Stages 1-4 (everything in memory) are implemented by an **external
agent working outside this repo's harness** — it has no stigmergy, and may not be
able to run DOSBox-X, mGBA or the djgpp link. Stage 5 (the disk boundary) and stage 6
(goldens + sweep) are the maintainers'. The PC **UI** is a separate later sweep and is
out of scope here.

---

## 1. Why

The Bill's PC logic is not blocked on the box format — that is fully known. It is
blocked on **storage**: only the current box exists in WRAM, and pret keeps the other
eleven in SRAM banks the port does not emulate. Maintainer direction is to **emulate
all GB RAM** (ROM banking stays flat), so "implement the PC logic" and "emulate SRAM"
are one program and the PC is its first consumer.

## 2. What exists today

**WRAM: fully emulated.** `boot/entry.asm:204 alloc_gb_memory` DPMI-allocates the whole
GB address space, zeroes it, and parks the base in EBP. `GB_TOTAL_SIZE` (`entry.asm:24`)
is an expression evaluating to **`0x21A00`**; its inline comment saying "0x17A00 (96768
bytes)" is stale (challenge 8). Every `[ebp + wFoo]` is real emulated memory at pret's
address.

**SRAM: the bank-0 window only.** `$A000-$BFFF` is inside the allocation and holds
`sSpriteBuffer0/1/2` (`dos_port/include/gb_memmap.inc:1390-1392`). There is no `rRAMB`,
no bank storage, and no `sHallOfFame` / `sGameData` / `sBox*` anywhere.

**Boxes:** the current box is complete and pret-identical (`wBoxDataStart..End`, 1122 B
at `$DA7F`, `gb_memmap.inc:1052`); `BOXMON_STRUCT_LENGTH=33`, `MONS_PER_BOX=20`,
`NUM_BOXES=12` (`gb_constants.inc:34,35,85`). `_MoveMon` / `_RemovePokemon` /
`AddPartyMon` / `SendNewMonToBox` are translated and linked; the deposit/withdraw/release
backends exist (`dos_port/src/engine/pokemon/bills_pc.asm:61,98,129`); the whole
`ChangeBox` spine is translated (`dos_port/src/engine/menus/save.asm:599`). The six
storage routines are `TODO-HW: SRAM` no-ops (`save.asm:677,881,889,905,924,935`).

**Save:** pret's SRAM save/load routines are already redirected onto the `.dsv` HAL
(`dos_port/src/save/dsv_io.asm`), which serializes five WRAM blocks (3978 B payload, v1).
That file's own header says it is "NOT yet a faithful 32 KB SRAM bank image" and that the
version byte gates the future format. `save.asm`'s header enumerates the debts real SRAM
retires: **M-106** (`hTileAnimations` is HRAM, outside the payload, so the setting does
not survive save/load), **M-107** (the saved player ID is unreachable, so
`CheckPreviousSaveFile` always answers "same playthrough" and NEW GAME silently
overwrites an existing save), plus dead-but-wrong `SaveHallOfFameTeams`,
`ClearAllSRAMBanks`, and the degraded box swap.

**Coverage:** there is **no box/PC scenario** in the 33-scenario golden suite. This work
starts with zero behavioural coverage; stage 6 closes that.

## 3. Design (locked)

**All four banks resident, flat — no switchable window.** Same deviation class the port
already sanctions for ROM (`class=banking`).

| bank | contents | where |
|---|---|---|
| 0 | `sSpriteBuffer0/1/2`, `sHallOfFame` | **stays at `$A000-$BFFF`** |
| 1 | `sGameData` (name/main/sprite/party/curbox/tileanims) + `sMainDataCheckSum` | extended region |
| 2 | `sBox1..sBox6` + all-box and per-box checksums | extended region |
| 3 | `sBox7..sBox12` + checksums | extended region |

Banks 1-3 are **contiguous**, starting at the next `0x1000`-aligned address after the
back buffer (`GB_BACKBUF 0x12000` + `0xFA00` = `0x21A00`):

```
SRAM bank 1  0x22000 .. 0x23FFF
SRAM bank 2  0x24000 .. 0x25FFF
SRAM bank 3  0x26000 .. 0x27FFF
GB_TOTAL_SIZE -> 0x28000        (160 KB, from 137728 B today)
```

Bank 0 is deliberately **not** moved up with them: the pic decompressor stores its
staging pointer into `wSpriteInputPtr`, a **2-byte GB slot** (`src/home/pics.asm:468`),
so anything it points at must be ≤ `$FFFF`. Consequence for stage 5: the 32 KB disk
image is assembled from two regions (8 KB at `$A000` + 24 KB at `0x22000`), not one.

`ld [rRAMB], a` sites become annotated no-ops. Intra-bank offsets are **derived from
pret `ram/sram.asm`**, never invented — note bank 0's `ds $100` before `sHallOfFame`
and bank 1's leading `ds $598`.

Fallback, only if the pointer audit in §5 turns out incomplete: active bank in the
`$A000` window with the resident banks as backing store. That is a maintainer call.

## 4. Stages

### Stage 1 — SRAM address space  *(external)*
- [ ] `equ`s for all four banks under **pret's own label names**, derived from
      `ram/sram.asm` + `layout.link:248-255`.
- [ ] Grow `GB_TOTAL_SIZE`; fix its stale inline comment.
- [ ] Teach `dos_port/tools/audit_memmap.py` the extended region — it currently audits
      only `val <= 0xFFFF` (`audit_memmap.py:91`), so the new banks would be unaudited.
- [ ] Resolve the `PIC_STAGE` / `sHallOfFame` collision (challenge 6) and fold
      `PIC_STAGE`'s three duplicated literals into one `gb_memmap.inc` entry.

### Stage 2 — pointer-safety substrate  *(external)*
- [ ] Port-only 32-bit-safe copy helper for SRAM destinations (do **not** widen
      `CopyData`).
- [ ] `BoxSRAMPointerTable` as `dd` + full-dword load in `GetBoxSRAMLocation`.
- [ ] Adopt and document the invariant: no address above `$FFFF` is passed to a
      pret-labeled home helper.

### Stage 3 — box tier  *(external; safe to merge alone)*
- [ ] `GetBoxSRAMLocation`, `CopyBoxToOrFromSRAM`, `EmptyAllSRAMBoxes`,
      `EmptySRAMBoxesInBank`, `EmptySRAMBox`, `GetMonCountsForBoxesInBank`.
- [ ] Faithful all-box / per-box checksums (`CalcCheckSum`,
      `CalcIndividualBoxCheckSums` already exist and are 32-bit safe).
- [ ] Box-full / per-box count semantics checked against pret (challenge 19).

After stage 3 boxes swap for real in-session; only the **current** box still persists
across a save/load. That is an expected intermediate — declare it, do not paper over it.

### Stage 4 — in-memory save realization  *(external; merges WITH stage 5)*
- [ ] `SaveMainData` / `SaveCurrentBoxData` / `SavePartyAndDexData` / `LoadSAVToReRAM`
      read and write the real `s*` regions instead of calling the `.dsv` HAL.
- [ ] `CheckForPlayerNameInSRAM` becomes pret's real `sPlayerName` scan.
- [ ] `CheckPreviousSaveFile` (retires M-107), `sTileAnimations` (retires M-106).
- [ ] `ClearAllSRAMBanks`, `SaveHallOfFameTeams` become correct rather than no-ops.
- [ ] Call the two seam entry points (below) at the boot and save-commit points.

### Stage 5 — disk boundary  *(maintainers)*
- [ ] `.dsv` v2 = raw 32 KB SRAM image; load at boot, store on save.
- [ ] Bump `DSV_VERSION`; **no v1 migration** — pre-release project, a v1 file simply
      fails the version check and falls into the existing absent/corrupt-save branch.
      Delete v1's payload-block machinery and `saveconv.py`'s v1 constants.

### Stage 6 — sweep  *(maintainers)*
- [ ] Retire every `TODO-HW: SRAM`; close M-106 / M-107 at their sites.
- [ ] New goldens: a `datastruct` deposit/withdraw/release scenario and a change-box
      round trip (deposit into box 1 → change to box 2 → change back → the mon is still
      there). `item_potion_use` / `ball_catch` are the WRAM-mutation templates.
- [ ] Update the memories and archive this plan to `docs/plans/sram_pc_storage.md`.

### The sequencing hazard
Stage 4 stops the pret save routines from reaching disk. `continue_seed` is a
**core-tier golden with `must_hit TryLoadSaveFile`**
(`dos_port/tools/scenario_manifest.json:620-636`), so it goes red the moment stage 4
lands without stage 5. Stages 1-3 leave the save path untouched and keep it green.
Stage 4 therefore develops on a branch and merges in the same window as stage 5.
**Nobody reports a green suite from a branch where 4 is in and 5 is not.**

### The seam contract
So stage 4 links before stage 5 exists: declare `extern` on two port-only HAL entry
points — working names `SramLoadImage` / `SramStoreImage` — and call them at the boot
and save-commit points. Until stage 5 lands they are ret-stubs in a new
`dos_port/src/save/save_stubs.asm` under the stub convention.
**The external implementer must not edit `dos_port/src/save/dsv_io.asm`.**

## 5. Challenges

**Pointer model**

1. **16-bit truncation is real, and it has been audited.** `CopyData`'s *destination* is
   `movzx edi, dx` (`src/home/copy.asm:56`) — DE is 16-bit by the register map
   (`docs/register_map.md:21`), so an SRAM destination above `$FFFF` silently wraps into
   the GB window. That hits the WRAM→SRAM direction of `CopyBoxToOrFromSRAM` and every
   `ld de, sMainData`-style store in pret `save.asm:206-267`. **Safe by measurement:**
   `CopyData`'s source (`lea esi, [ebp+esi]`), `CalcCheckSum` (reads `[ebp+esi]`, 32-bit;
   `dl` is an 8-bit accumulator), `ChangeBox`'s `mov edx, esi` (`save.asm:641`), and the
   `movzx ecx, bx` sites in `array.asm`/`move_mon.asm`/`copy2.asm` (BC counts, not
   addresses).
2. **`GetBoxSRAMLocation` rebuilds a 16-bit pointer** from a `dw` table (pret
   `save.asm:329-340`). Needs `dd` entries and a full-dword load; annotate
   `class=data-model`.
3. **Do not widen `CopyData` itself.** That would need "the upper half of EDX is always
   clean" as a tree-wide invariant, which the register map does not promise — a
   translated `ld d, 0` written as `mov dh, 0` leaves stale high bits. Widening it is a
   separate, audited change.
4. **The invariant is the load-bearing part:** SRAM pointers live in ESI/EDI/full-32-bit
   EDX or 4-byte port-only storage, never a 2-byte GB slot, never through `DX`/`DH`/`DL`.
   If a truncation site outside the audited set appears, **stop and report** — do not
   widen a GB field to make it fit.
5. **`audit_memmap.py` audits only `val <= 0xFFFF`.** This work is the first thing to put
   *structured, overlappable* data above the window (VRAM1 and the back buffer are single
   opaque blocks), so teach the auditor in stage 1 rather than leaving a region nothing
   checks.

**Bank 0 is already occupied by port-only scratch — and it collides**

6. **`PIC_STAGE` at `$A4A0` sits where pret's `sHallOfFame` region begins.** The port
   stages a compressed mon pic there (`src/home/pics.asm:466`, "free SRAM just past
   sSpriteBuffer2 `$A498`"), copying a variable-length stream. pret's bank 0 is
   `sSpriteBuffer0/1/2`, then `ds $100`, then `sHallOfFame` at `$A598` — only **248
   bytes** of headroom. **Measured 2026-07-28 across all 350 `.pic` blobs (front, back,
   trainers): the largest is 599 bytes** (`kangaskhan`, `charizard`), so the staged
   stream overruns into `sHallOfFame` by up to 351 bytes. Placing `sHallOfFame` at
   pret's offset therefore creates a live corruption path, dormant only because HoF is
   unported.

   **Relocate the port-only `PIC_STAGE` scratch — that is the strictly more faithful
   option**, because `PIC_STAGE` is a port invention (pret has no staging buffer; it
   decompresses straight out of banked ROM, which the port flattened) while
   `sHallOfFame` is a real pret symbol at a real pret offset. Moving the pret symbol
   would also break byte-comparability of the future 32 KB image against a real GB
   `.sav`, which `saveconv.py`'s Phase-5 `.sav` ↔ `.dsv` conversion depends on — it
   would need a fixup table forever. Recommended home: bank 0's dead tail after
   `sHallOfFame`, which ends at `$B858`, leaving **1960 free bytes to `$BFFF`** —
   e.g. `PIC_STAGE = $B860`, 1952 bytes of headroom against a 599-byte worst case.
   Annotate that the port parks scratch in bank 0's unused tail, and note that those
   bytes ride along in the SRAM image as harmless garbage (the region is unused in a
   real `.sav` too). **Maintainer sign-off still required.**
7. **`PIC_STAGE` is a duplicated literal** — `%define`d separately in
   `src/engine/battle/init_battle.asm:47`, `src/engine/menus/start_sub_menus.asm:204`,
   `src/engine/movie/oak_speech/oak_speech.asm:93`. Fold it into one `gb_memmap.inc`
   `equ` so the auditor can see it; three copies of an address literal is how the
   collision above stayed invisible.
8. **`GB_TOTAL_SIZE`'s comment is stale** (`boot/entry.asm:24`). The value is computed so
   nothing is broken — but this file is about to grow the allocation, and a confident
   wrong comment is this project's most-repeated defect class.

**Fidelity and naming**

9. **The 32-bit copy helper produces faithdiff fallout.** Every routine that stops calling
   `CopyData` shows a DROPPED call; each needs a `DEVIATION{class=banking; …}` at the site
   and a justification in the commit message. Expected — but an unjustified DROPPED call
   fails review.
10. **Naming.** `BillsPCDepositLogic` / `WithdrawLogic` / `ReleaseLogic`
    (`src/engine/pokemon/bills_pc.asm`) are **port-only names** already on a maintainer
    suspicion list precisely because they are pret-shaped. Do not mint more of that shape;
    new work uses pret's own labels. Folding those three into pret's
    `BillsPCDeposit`/`Withdraw`/`Release` happens with the UI sweep, not here.
11. **Mirror rule.** Everything here has a pret counterpart, so it lives at
    `dos_port/src/<pret path>`. No `pret_label_allowlist.json` edits, ever, to make one's
    own work pass.

**Semantics**

12. **Checksums are in scope and faithful.** The box tier maintains the all-box and
    per-box checksums in banks 2/3 and `sMainDataCheckSum` in bank 1. This is what makes
    the eventual disk image byte-meaningful and keeps pret's corrupt-save branch real.
13. **Battery semantics vs power-up zeroing.** `entry.asm` zeroes the whole allocation to
    mimic power-up; real SRAM is battery-backed and is not. Between stages 4 and 5 the
    game boots with empty SRAM and therefore "no save file". Expected; declare it.
14. **`CheckForPlayerNameInSRAM` changes character** — from a `.dsv` presence check
    (`src/engine/menus/main_menu.asm:571-578`) to pret's real `sPlayerName` scan, which
    only answers correctly once the image is loaded at boot. Another reason 4 and 5
    travel together.
15. **M-107 becomes fixable and should be fixed:** a real `sPlayerName` lets
    `CheckPreviousSaveFile` compare the saved player ID without clobbering the live game.
16. **M-106 likewise:** `sTileAnimations` is a real SRAM byte again.
17. **Bank 0 aliasing is designed out and must stay out.** `sSpriteBuffer0/1/2` are the
    pic-decompression buffers, touched at arbitrary times; the resident design makes a
    swapped-out bank 0 unrepresentable. Do not reintroduce a switchable window.
18. **Gen-2 forward compatibility.** Box entries are 33 bytes with frozen offsets;
    `MON_CATCH_RATE` (offset 7) is Gen 2's held-item slot and must be carried verbatim by
    every box copy. Do not "clean up" a reserved byte.
19. **Box-full / box-count semantics.** With real boxes, `wBoxCount` is per box and the
    deposit path's box-full check must consult the destination box. Check
    `BillsPCDepositLogic`'s failure path against pret.
20. **`SaveHallOfFameTeams` stops being dead** once bank 0 has `sHallOfFame`. Still
    unreachable (the HoF movie is unported), but it must be correct rather than a no-op.

## 6. Rules for an implementer outside the harness

Read, in this order, from the repo: **`CLAUDE.md`**, then
`.claude/skills/asm-translation/SKILL.md` (register map, ZF/CF preservation,
big-endian GB data, the EBP model),
`.claude/skills/project-conventions/SKILL.md` (stub convention, two-tier data rule,
the annotation schema),
`.claude/skills/faithfulness-review/SKILL.md` (faithdiff / lint / mirror rule and the
justification rules), and `.claude/skills/build-and-debug/SKILL.md` (build, gates,
harness). They are ordinary markdown; read them as files.

Condensed, the rules that bite here:

- **Keep pret's label names.** Aliases go alongside, never instead. New port-only
  helpers get descriptive names; anything with a pret counterpart uses pret's name.
- **Mirror rule:** a routine with a pret counterpart lives at `dos_port/src/<pret path>`.
- **GB data is big-endian.** Never re-store a GB value little-endian.
- **Register map:** A→AL, BC→BX, DE→DX, HL→ESI, EBP = GB memory base; preserve the exact
  ZF/CF a `jr z`/`jr c` reads. Flat program-image tables are read via `[label]`/`[esi]`,
  never `[ebp + label]`.
- **Stubs** live in `src/<area>/<area>_stubs.asm` under their exact pret label, `ret`-only.
- **Human-rendered strings are generated data**, never hand-encoded charmap `db` bytes.
- **New sections must be added to `dos_port/link.ld` first**, or their bytes never load
  and their symbols read back as zero at runtime with no fault.
- **Structured annotations** are machine-parsed, exactly four kinds
  (`DEVIATION`/`BUG`/`GLITCH`/`STUB`), all requiring `class`, `pret`, `behavior`,
  `evidence`, `lifetime`; `class` ∈ {HAL, banking, projection, data-model, timing, stub,
  temporary}; no `;` or `}` inside a value.
- **Shell is zsh**, and never read a gate's status through a pipe — redirect output to a
  file, `echo $?` to a file, read that file.

**Evidence discipline.** Repository and runtime evidence outrank prose. Negative claims
(`missing`, `stub`, `unreachable`, `no caller`) need generated state
(`dos_port/tools/project_state <Label>`) or runtime evidence — and so do
*confirmations*: a matching count or "no diff" is not evidence without its
decomposition. `status = port_only` does **not** mean port-invented (the label DB models
pret `home/` + `engine/` only, so real pret labels from `audio/`, `data/`, `gfx/`, `ram/`,
`scripts/` read that way by elimination — check `aux_labels`/`script_labels`).
`not-proven-reached` is not proof of unreachability. **Report what you could not verify
rather than implying coverage.**

## 7. What the shared-memory store would have told you

The external implementer has no access to it; these are the entries that bear on this
work.

- **`static-gate-and-ci-wiring` / `relocated-labels-grind`** — two gates by scope.
  `tools/static_gate` is a whole-tree ratchet against a checked-in per-class baseline,
  invoked by the pre-commit hook whether you remember it or not, and the ratchet goes
  **both ways** (a class that shrank also fails until the baseline is lowered
  deliberately). `tools/fidelity_gate` is the per-change, per-label chain and carries the
  relocation move battery. Neither runs a scenario.
- **`port-only-70-unannotated-inventory`** — ~70 genuinely port-only labels still lack
  `DEVIATION` annotations. The three `BillsPC*Logic` names sit on its highest-suspicion
  list: "pret-shaped CamelCase names for gameplay behaviour, exactly the shape the three
  removed forks had. Check whether pret has a counterpart under a different name before
  writing any DEVIATION — a DEVIATION on a routine that should have been named after a
  pret label just documents the fork instead of removing it."
- **`golden-harness-traps`** — traps that make a fidelity run *lie*: `make assets` is
  mtime-gated, so after a stash/rebase the generated `.inc` files can be newer than their
  generators and nothing regenerates; a harness that hand-seeds coordinates can park the
  game in a state it cannot reach; `PKMN.IMG` carries dump files from earlier builds, so a
  run that crashes before dumping yields the previous result as a PASS; and when a test
  fails, run the control — if the known-good config also fails, the variable under test is
  not the variable that changed.
- **`stale-frame-bin-false-pass`** — same family: delete the dump before the run or the
  "result" is the last run's screen.
- **`regression-battle-blackout-gate-hangs`** — the nearest prior defect to this work:
  `ReadPlayerMonCurHPAndStatus` was a no-op with the copy direction backwards, so a
  fainted mon's 0 HP never reached its party slot and the battle looped forever.
  Party/box **copy direction and field offsets** are exactly the class of bug static
  checks cannot see and only a datastruct golden catches.
- **`plan-filing-and-skill-mirror`** — active plans are `docs/current_plan_*.md`
  (`dos_port/tools/project_state --plans` is the authority on what exists); completed ones
  move to `docs/plans/`. There is no `TODO.md` and no regressions log file — a regression
  gets a `BUG{}` annotation at the code that is wrong.

## 8. Verification

Record every gate's status to a file (never read it through a pipe).

- **Stages 1-2:** `nasm -f coff -I dos_port/include -I dos_port` on touched files;
  `make -C dos_port`; `dos_port/tools/audit_memmap.py`; `dos_port/tools/static_gate`
  green at its baseline.
- **Stage 3:** the above, plus `dos_port/tools/faithdiff` on each of the six box routines
  with every ADDED/DROPPED line justified, and `make -C dos_port fidelity` still 16/16 —
  stage 3 must not move an existing golden.
- **Stages 4+5 together:** `make -C dos_port fidelity-full` (33 scenarios) with
  `continue_seed` green as the gate that the save path survived the format change, plus
  `dos_port/tools/saveconv.py --verify` on a fresh v2 file.
- **Stage 6:** the two new box scenarios above, committed as goldens.

## 9. Open decisions

- Seam entry-point names (`SramLoadImage` / `SramStoreImage` are working names).
- **`PIC_STAGE` vs `sHallOfFame` (challenge 6)** — recommendation, with the measurement
  behind it, is to relocate the port-only scratch to bank 0's dead tail
  (`PIC_STAGE = $B860`) and leave `sHallOfFame` at pret's `$A598`. Needs maintainer
  sign-off before stage 1 writes bank 0's `equ`s.
