# Current plan — predef text (`TextPredefs` / `PrintPredefTextID`)

Goal: link `dos_port/src/home/predef_text.asm`, the last file the relocation
grind left blocked (stigmergy `relocated-labels-grind`), and with it retire the
final two `pret_label_allowlist.json` relocation rows
(`SetMapTextPointer` / `RestoreMapTextPointer`, currently split out into
`src/home/map_text_pointer.asm` so the SAVE flow's `ChangeBox` can link them).

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

- [x] Decide Option A vs B (maintainer call — it changes a live home routine).
      **DECIDED 2026-08-02: Option A**, the flat side-table mirroring the
      `w_map_text_table_ptr` precedent. Option B is rejected and closed.
      Acceptance for the `DisplayTextID` edit: full fidelity suite green **plus**
      a new must-hit scenario covering a predef text — the suite as it stands
      (37/37, measured 2026-08-02) does not exercise this path, so a green run
      without that new scenario proves nothing about the change.
- [ ] Port or stub the 14 `text_asm` + 3 `script_*` entries.
- [ ] Build the 68-entry `TextPredefs` table in `src/home/predef_text.asm`.
- [ ] Promote `predef_text.asm` out of `HOME_CHECK_SRCS`; promote
      `predef_text_data.asm` out of `DATA_CHECK_SRCS`.
- [ ] Merge `SetMapTextPointer`/`RestoreMapTextPointer` back from
      `map_text_pointer.asm` (use `fidelity_gate --move-baseline` / `--move-verify`),
      delete that file, free its Makefile slot.
- [ ] Retire the last 2 `pret_label_allowlist.json` rows — **last**, in its own
      commit, per the sequencing rule in `relocated-labels-grind`; then hand the
      measured hash to the maintainer for the two-sided bless.

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
