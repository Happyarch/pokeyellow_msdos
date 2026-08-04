# Current plan — predef text (`TextPredefs` / `PrintPredefTextID`)

> **Gate — the linter is MANDATORY. Rewritten 2026-08-02 against the tooling
> that actually exists; the version this replaces predated `static_gate` and
> told you "nothing runs it for you", which stopped being true on 2026-07-26.**
>
> **What runs automatically.** `dos_port/tools/static_gate` runs BOTH linter
> modes plus `test_label_db.py` and `validate_scenarios.py`, and it is invoked
> by `.githooks/pre-commit` (installed here: `core.hooksPath=.githooks`). It
> fires whenever anything under `dos_port/` is staged. It is a per-class
> RATCHET against a checked-in baseline: it fails a class that GREW.
>
> **What that does NOT mean.** A class sitting at baseline is not sanctioned —
> it is unfixed debt that merely has not gotten worse. `dos_port/tools/lint_pret_labels`
> **must exit 0**; it does not today — a small number of known, unsanctioned
> findings remain (`aux_misplaced` under plain `lint_pret_labels`;
> `--strict-claims` can add `hand_encoded_text` / `local_shadow` on top). None
> of those was ever approved by the maintainer, and the counts move as agents
> clear debt — **run `dos_port/tools/lint_pret_labels --no-scan` and
> `--no-scan --strict-claims` yourself** rather than trusting a number written
> here. Do not cite "at baseline" as permission to leave a class non-zero, and
> do not rewrite the rule to match the breakage.
>
> **For every commit made under this plan:**
> 1. Record the per-class counts from BOTH `lint_pret_labels` and
>    `lint_pret_labels --strict-claims` **before** you start.
> 2. Run both again before committing and compare per class. A class that grew
>    is your regression to fix now, not the next agent's to discover. Moving a
>    routine between files silently invalidates `extern` provider comments
>    elsewhere in the tree — collateral visible **only** under `--strict-claims`.
> 3. A green static gate proves **no structural or bookkeeping drift and nothing
>    about behaviour.** If the change can move a pixel or a WRAM byte, run
>    `make -C dos_port fidelity` (core) or `fidelity-full`, and add a must-hit
>    scenario when no existing one can witness the change.
>
> **The allowlist is not yours to grow.** `dos_port/tools/pret_label_allowlist.json`
> is hash-locked legacy debt, not precedent. New relocations are FORBIDDEN. An
> agent may not add, expand or reinterpret it — including `structural_findings`
> and `suppress` — to make its own work pass. **Any ADDITION requires explicit
> maintainer sign-off and cannot be committed without it**; the pre-commit hook
> refuses added keys outright and names them. If the linter says `mirror`, move
> the complete routine to `dos_port/src/<pret path>` instead.
>
> Do not quote a finding count from this file, CLAUDE.md, AGENTS.md, a skill, or
> a stigmergy memory as evidence that a class is clean — every one of those has
> been wrong before. Re-measure it.

Goal: link `dos_port/src/home/predef_text.asm`, the last file the relocation
grind left blocked (stigmergy `relocated-labels-grind`), and with it retire the
final two `pret_label_allowlist.json` relocation rows
(`SetMapTextPointer` / `RestoreMapTextPointer`, which were split out into
`src/home/map_text_pointer.asm` so the SAVE flow's `ChangeBox` could link them).

**Both halves of that goal are DONE.** `predef_text.asm` links (`ed82955a`) and
the two rows are retired (`d54a32e4`, blessed both places) — the relocation
registry is empty and `relocated` is 0 by DB count. What remains open in this
plan is the **acceptance**: no must-hit predef scenario can be built while the
port has no resident interior map data, so the path is runtime-unreachable and
the change carries regression evidence only. That is backlog #31, and it is the
only thing standing between this plan and archival.

Stage 1 (the data tier) is **done**. Stage 2 is **blocked on a measured
addressing-model gap**, described below — it is not more data entry.

---

## What `TextPredefs` actually is — measured, not assumed

`data/text_predef_pointers.asm` has **68** `add_tx_pre` entries, ids `$01..$44`.
(`grep -c add_tx_pre` reports 69: one of those lines is the `MACRO add_tx_pre`
definition itself. Count the entries, not the matches.)

Classified by reading each label's **body** in the pret tree — not by the file it
lives in, which is what an earlier scoping pass did and got wrong:

| class | count | what it is |
|---|---|---|
| plain `text_far` wrapper | 50 | pure printable stream → Tier-1 data |
| `db "@"` | 1 | `UnusedPredefText`, a bare terminator → Tier-1 data |
| `text_asm` wrapper | 14 | the message **is code** → Tier-2 |
| `script_*` marker | 3 | one script-opcode byte, dispatcher-owned |

So **51 of 68 are generatable data**; the other 17 are not, and no generator
should pretend otherwise. The 14 `text_asm` ones are real logic — the 5-page
`ViridianSchoolNotebook` reader, `CinnabarGymQuiz`'s state machine,
`IndigoPlateauStatues`' badge-count branch, `BillsHousePokemonList`'s
`HandleMenuInput`/`DisplayPokedex` menu, several `WaitForSoundToFinish` tails.
The 3 `script_*` are `script_players_pc`, `script_pokecenter_pc`,
`script_bills_pc`.

The per-label reasons live in `NOT_DATA` in
`dos_port/tools/generators/gen_predef_text.py`, and the generator **asserts the
whole 68-way split both directions** — a pret change that moves a label between
classes fails the generator loudly instead of silently emitting a different set.

---

## Stage 1 — the data tier — DONE

- [x] `tools/generators/gen_predef_text.py` — emits the 51 generatable streams
      into `assets/predef_text.inc` as flattened, self-terminating byte streams
      plus a `{ptr,len}` `<Label>_ref` pair each, reusing `gen_battle_text.py`'s
      charmap/memmap/far machinery (the `gen_pickup_text.py` precedent).
- [x] `src/data/predef_text_data.asm` — the include shell, wired into
      `make assets` and assembled **check-only** via a new `DATA_CHECK_SRCS`
      list. Check-only, not linked, because nothing can consume it yet (Stage 2);
      this keeps the bytes proven to assemble without putting dead data in the
      binary.
- [x] Two genuine bugs fixed in the shared `gen_battle_text.parse_body`, both
      found by this work and both previously capable of **silently dropping a
      whole stream**:
      - `text_far` target matched `_\w+`, requiring pret's leading-underscore
        convention. `TMNotebookText` and friends have none, so those wrappers
        died as "unhandled text line".
      - the tolerated-opcode table was missing `sound_get_item_2` ($10),
        `sound_get_key_item` ($11), `sound_pokedex_rating` ($0E) and
        `sound_get_item_1_duplicate` ($0F). `FoundHiddenCoinsText` and
        `DroppedHiddenCoinsText` need $10. Values read out of
        `macros/scripts/text.asm`, not derived.
      Blast radius **measured, not reasoned about**: `make assets` regenerated
      all **410** `assets/*.inc` and every one was byte-identical
      (`sha256sum` before/after, zero diff). The two gaps were only ever
      reachable from predef-text labels nothing generated before.
- [x] `src/engine/slots/game_corner_slots{,2}.asm`: their five hand-written
      `GameCorner*Text` wrappers duplicated the newly generated globals
      (`dup_def` ×5). Retired in favour of the generated definition, per the
      `experience.asm` precedent in stigmergy `battle-text-composed-in-code-audit`
      ("one definition each"). Note what this surfaced: those wrappers pointed at
      `_GameCorner*Text` far labels **no file in the tree defines**, so both files
      could never have linked as written. They are not in the Makefile either.

Verification: `make assets` EXIT=0 · `make` EXIT=0 · `nasm` on the data shell
emits 102 symbols (51 labels × {label, `_ref`}) · `update_label_db` clean ·
`lint_pret_labels --no-scan` back to the **pre-existing 14** `aux_misplaced`
(measured on a stashed clean tree — the "0 violations" figure in
`relocated-labels-grind` is stale, it predates the `aux_misplaced` class) ·
`static_gate: PASS`, every class at baseline.

Spot-checked decoded streams against pret source, e.g. `CardKeySuccessText`:

```
00 81 A8 AD A6 AE E7 50 0B 00 4F 93 A7 A4 7F ... 57 50
<START>Bingo!@<SND_GET_ITEM_1><START><LINE>The CARD KEY<CONT>opened the door!<DONE>@
```

matching `text_far _CardKeySuccessText1` / `sound_get_item_1` /
`text_far _CardKeySuccessText2` / `text_end` exactly, including the embedded `@`
that pret's own `text "Bingo!@"` carries.

---

## Stage 2 — BLOCKED: the TEXT_PREDEF branch cannot address flat streams

**This is the real blocker, and it is not "port more text".** Supplying a
`TextPredefs` table of flat `dd` pointers would link cleanly and be **runtime
garbage**. Do not do it.

`DisplayTextID`'s TEXT_PREDEF path (`src/home/text_script.asm`) is a faithful
**16-bit GB-address-space** pointer walk:

```nasm
.loadPredefTextPtr:
    movzx esi, word [ebp + wCurMapTextPtr]   ; 16-bit GB addr of the table
.lookupGbPointerTable:
    add esi, edx / add esi, edx
    and  esi, 0xFFFF                          ; faithful 16-bit GB wrap
    movzx esi, word [ebp + esi]               ; 16-bit LE entry, read from GB space
.readFirstByte:
    movzx eax, byte [ebp + esi]               ; stream read from GB space
```

and `SetMapTextPointer` (`src/home/map_text_pointer.asm`) stores only the low 16
bits of `ESI` into the 2-byte `wCurMapTextPtr` — its own comment says "HL (ESI)
holds a GB 16-bit address".

But the port's generated streams are **flat program-image data** in
`section .data`, and the port's text engine consumes flat pointers:
`PrintText` / `PrintText_NoCreatingTextBox` are both documented
"In: ESI = flat pointer to a text-command stream", and `PrintTextStaged` exists
precisely so a WRAM-composed stream can be *renamed* as a flat pointer
(`lea esi,[ebp + NPC_DIALOG_BUF]`), with the comment "Every other stream is flat
program-image data and enters at PrintText directly."

So `mov esi, TextPredefs` (a 32-bit program address) truncated to 16 bits and
dereferenced as a GB-space offset yields garbage. The ordinary map path already
sidesteps this with a **port-only flat side channel** — `w_map_text_table_ptr`,
flat `{dd stream, dd size}` rows — which is exactly the shape the predef path
needs.

### Option A — give the predef path its own flat table  ✅ **CHOSEN (maintainer, 2026-08-02)**

Mirror what the ordinary map path already does, as a
`DEVIATION{class=projection; ...}`:

- `TextPredefs` becomes a flat table (68 rows) in `src/home/predef_text.asm`,
  entries pointing at the generated streams / at Tier-2 wrappers.
- add a port-only flat published pointer (the `w_map_text_table_ptr` precedent)
  set by `PrintPredefTextID`, so `wCurMapTextPtr` / `SetMapTextPointer` /
  `RestoreMapTextPointer` stay byte-faithful and `ChangeBox`'s
  save/restore keeps working untouched.
- `DisplayTextID`'s predef branch reads the flat table instead of the GB walk.

Cost: touches `DisplayTextID`, which is live and golden-covered. Needs the full
fidelity suite plus a new must-hit scenario for a predef text.

### Option B — keep it faithful, copy streams into GB space  ❌ **REJECTED (maintainer, 2026-08-02)**

Rejected: there is no ROM-ish region in the port's GB map to hold 51 streams,
and it would mean a runtime copy for every predef text. Do not revisit without
new evidence that changes one of those two facts.

### Prerequisite either way

The 14 `text_asm` labels and 3 `script_*` markers still need Tier-2 bodies (or
documented `STUB{}`s in the owning subsystem) before the table is complete.

**Re-measured 2026-08-02:** this paragraph used to call `OpenBillsPCText` /
`BillsHousePokemonList` / `BillsHouseInitiatedText` "gated behind the unported
Bill's PC menu UI" and name them the natural stub group. **That is no longer
true** — the faithful Bill's PC box UI landed 2026-07-31
(`a2ea6550..0c9afce5`), lives at `src/engine/pokemon/bills_pc.asm`, and is
golden-gated by `bills_pc_ops` (id 37) and `box_change_roundtrip` (id 38).
Those three entries are therefore portable now, not stub candidates. Re-derive
the real stub group from generated state before writing any `STUB{}`.

## Stage 2 — IMPLEMENTED 2026-08-02, ACCEPTANCE BLOCKED

Everything Option A asked for is built, linked and gate-clean. The one thing that
is NOT done is the acceptance, and it is blocked by something outside this plan —
read the last box before concluding this plan is finished.

What landed:
- `TextPredefs` is a flat 68-row `{dd stream, dd size}` table — the SAME row shape
  the ordinary map text table uses — in `src/data/predef_text_data.asm`. Note the
  plan text above said "in `src/home/predef_text.asm`"; that would have ADDED an
  `aux_misplaced` finding, because pret files the table under `data/`. It lives in
  the data layer for exactly the reason `MoveEffectPointerTable` does: hand-written
  (17 rows name PORT routines, so no generator can derive it) yet filed as data.
- `PrintPredefTextID` publishes a port-only flat `w_predef_text_table_ptr`, the
  `w_map_text_table_ptr` precedent. `wCurMapTextPtr`, `SetMapTextPointer` and
  `RestoreMapTextPointer` are byte-faithful and untouched, so `ChangeBox` is
  unaffected. Tagged `DEVIATION{class=projection; ...}`.
- `DisplayTextID`'s TEXT_PREDEF branch reads the flat table. The 16-bit GB pointer
  walk (`.lookupGbPointerTable`) is DELETED, not left unreachable — both tables now
  share one lookup.
- The generator emits `<Label>_len` (so the table's byte counts are exact and not
  hand-duplicated) and a separate `assets/predef_text_ids.inc` with all 68
  `<Label>_id` constants. The ids have to be generated: pret computes them at the
  call site as `(Label_id - TextPredefs) / 2 + 1`, and the port cannot, because
  the `/ 2` is non-linear arithmetic on a cross-object symbol, which no COFF
  relocation can express. (Precision fix 2026-08-04: cross-object `equ`s as such
  DO work — linear uses relocate via `dir32`, which is how the `MapHeaderPointers`
  region was ultimately relocated. Only the non-linear arithmetic here is blocked.)
- `include/predef.inc` carries pret's `tx_pre_id` / `tx_pre`. Deliberately NOT
  `tx_pre_jump` — see backlog #32.
- The 17 non-data entries are ret-stubs in
  `src/engine/events/hidden_events/hidden_events_stubs.asm`, each with its pret
  ref, its reachability in the live build, a `TODO(<batch>)` retirement line and a
  machine-parsed `STUB{}` annotation.
- `PrintRedSNESText` is ported to its pret mirror
  `src/engine/events/hidden_events/reds_room.asm` and its `hidden_object_stubs.asm`
  ret-stub retired — the port's first real end-to-end predef call site.

**A real bug fell out of the merge, and it is worth recording.** pret's
`PrintPredefTextID` has no `ret`: it FALLS THROUGH into `RestoreMapTextPointer`.
With that pair relocated to `map_text_pointer.asm`, this file's `.text` ended in a
routine running off its own end — harmless while the file was check-only, a live
cross-file fall-through the moment it linked. `update_label_db`'s boundary scan
refused to model it and said so. Merging the pair back (and deleting
`map_text_pointer.asm`) is the fix, so that relocation retirement was required for
correctness, not tidiness.

- [x] Decide Option A vs B (maintainer call — it changes a live home routine).
      **DECIDED 2026-08-02: Option A**, the flat side-table mirroring the
      `w_map_text_table_ptr` precedent. Option B is rejected and closed.
      Acceptance for the `DisplayTextID` edit: full fidelity suite green **plus**
      a new must-hit scenario covering a predef text — the suite as it stands
      (37/37, measured 2026-08-02) does not exercise this path, so a green run
      without that new scenario proves nothing about the change.
- [x] Port or stub the 14 `text_asm` + 3 `script_*` entries. All 17 stubbed; all
      17 measured `missing`, in pret's `engine/events/hidden_events/` subsystem.
- [x] Build the 68-entry `TextPredefs` table — in `src/data/predef_text_data.asm`,
      not `src/home/predef_text.asm`; see the note above.
- [x] Promote `predef_text.asm` out of `HOME_CHECK_SRCS`; promote
      `predef_text_data.asm` out of `DATA_CHECK_SRCS` (that list is now empty).
- [x] Merge `SetMapTextPointer`/`RestoreMapTextPointer` back from
      `map_text_pointer.asm`, delete that file, free its Makefile slot.
      **The move battery could not be used as written:** `--move-baseline` refuses
      to snapshot through a failing rescan, and the rescan was failing on the very
      fall-through this merge fixes ("a snapshot taken through a stale DB is worse
      than none" — correct behaviour by the tool). Evidence is therefore the post-
      merge chain instead: `faithdiff` on both labels, `static_gate` PASS with
      `relocated` now **0**, and the full golden suite.
- [ ] **BLOCKED — the required must-hit predef scenario cannot be built yet.**
      The port has no resident interior map data (`include/gb_memmap.inc`: the
      `OW_<MAP>_BLK_GBADDR` set is "resident **outdoor** .blk"), and EVERY predef
      hidden event is on an interior map — Red's house, Blue's house, Oak's lab,
      the pokécentres, the gyms. So no predef text is reachable on any map the port
      can currently render. The `DEBUG_PREDEFTEXT` gate is written and correct
      (it seeds the SNES tile and runs the real dispatch); it renders a blank room.
      Filed as `docs/current_plan_backlog.md` #31. Until this clears, the predef
      path is runtime-unreachable and the change carries **regression evidence
      only** — never feature evidence.
- [x] Retire the last 2 `pret_label_allowlist.json` rows — **DONE 2026-08-03,
      commit `d54a32e4`.** `relocated_labels`, `relocated_files` and
      `structural_findings` are all `{}`; the legacy relocation registry is at
      **zero rows**, 348 -> 0 across the whole campaign.
      **Deliberately taken OUT of the planned order, at the maintainer's
      direction.** The sequencing rule says retire after the acceptance above,
      and that acceptance is still BLOCKED — but the rows were provably stale
      (both named the deleted `dos_port/src/home/map_text_pointer.asm` while
      `update_label_db` reported `relocated` = 0), so the retirement no longer
      depended on the predef work landing. It was a pure 2-key JSON delete with
      no code change.
      `git diff --numstat` read **`1 10`, not the `0 8`** the handoff predicted:
      emptying the last dict collapses its braces, so the campaign's
      `0 <4*rows>` rule reads `1 <4*rows+2>` on a dict going to empty.
      Gates: `static_gate` FAIL on the expected transient `registry_approval`
      only, then PASS once blessed; `aux_misplaced` stayed at its baseline 1;
      pytest 81 passed; 39 scenarios consistent. The runtime tier was **not**
      run and does not apply — the commit changes one JSON sidecar read only by
      the linter, so it cannot move a pixel or a WRAM byte.
      The maintainer blessed **both** halves the same session; all three of file,
      `git config` and the CI repo variable measure
      `9459552060a730318cf83c0d1ed73f989c5fb914f8c1340fb919f1a1c72b54aa`.
      See `registry-approval-state` and `relocated-labels-grind`.

---

## Adjacent finding — FIXED (`5f7aebff`)

`.readFirstByte` in `src/home/text_script.asm` read the stream's first byte as
`movzx eax, byte [ebp + esi]` — **EBP-relative** — but on the ordinary map path
`ESI` is already a **flat** pointer from `w_map_text_table_ptr`. That read landed
at `ebp + flat_addr`, far outside the ~96 KB GB allocation, so the `TX_SCRIPT_*`
dispatch below it compared an unrelated byte. Masked because the garbage rarely
equals a `TX_SCRIPT_*` constant and `PrintText_NoCreatingTextBox` then receives
the correct flat `ESI` — every golden scenario passed *through* the bug. The live
risk was a nondeterministic misdispatch: a stray `0xFE`/`0xFF` at that address
would have jumped an ordinary sign into `DisplayPokemartDialogue`.

Fixed by reading `[esi]`, and by making `.lookupGbPointerTable` name its GB-space
result flat (`lea esi, [ebp + esi]`, the `PrintTextStaged` idiom) so both entry
paths reach `.readFirstByte` with one convention.

Checked before changing rather than assuming the dict was dead: across all 410
generated `assets/*.inc`, **no text stream begins with a `TX_SCRIPT_*` byte**
(1427 begin with `0x00` = TX_START); the only 10 blobs that do are graphics and
layout tables unreachable from the map text table. The port dispatches real
script entries through the size sentinel (`0xFFFFFFFF` / `0xFFFFFFFE`) that
`.gotTextPtr` tests first, not through pret's first-byte dict. So the corrected
read makes the dict deterministically not fire on the ordinary path, where it
previously did not fire only by luck.

Note for whoever does Stage 2: the `TX_SCRIPT_*` dict targets
(`DisplayPokemartDialogue` and friends) still treat `ESI` as a **GB-relative**
text pointer (`inc esi` then `LoadItemList`, which reads `[ebp+esi]`). That
inconsistency is pre-existing, unreachable today, and left alone — those service
bodies are structured stubs. It must be resolved if Option A ever makes the dict
reachable.
