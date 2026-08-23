# Current Plan: `PrintSendOutMonMessage` & Contextual Send-Out Lines

Implementation plan to port `PrintSendOutMonMessage` and its contextual intro text streams (`_GoText`, `_DoItText`, `_GetmText`, `_EnemysWeakText`), calculate enemy HP percentages on player send-out, latch `wLastSwitchInEnemyMonHP`, and retire the stub in `dos_port/src/engine/battle/battle_stubs.asm`.

## Background & Architecture

When sending out a Pokémon in battle, Pokémon Yellow selects one of four contextual intro messages based on the remaining enemy Pokémon HP percentage:
- **$\ge$ 70% remaining:** `GoText` $\to$ `"Go! <MON>!"`
- **40% – 69% remaining:** `DoItText` $\to$ `"Do it! <MON>!"`
- **10% – 39% remaining:** `GetmText` $\to$ `"Get'm! <MON>!"`
- **0% – 9% remaining:** `EnemysWeakText` $\to$ `"The enemy's weak! Get'm! <MON>!"`
- *(Special case: When enemy HP is 0, e.g. at battle initialization before mon load, `GoText` is selected unconditionally without updating `wLastSwitchInEnemyMonHP`)*.

`PrintSendOutMonMessage` also latches `wLastSwitchInEnemyMonHP` with the current `wEnemyMonHP`, establishing the baseline for the reciprocal switch-out dialogue in `RetreatMon` (`PlayerMon2Text`).

Currently, `PrintSendOutMonMessage` is a `ret`-stub in `dos_port/src/engine/battle/battle_stubs.asm:25`.

---

## Technical Details

### 1. Two-Tier Split
- **Tier 1 (Generated Data):** The four prefix text streams (`_GoText`, `_DoItText`, `_GetmText`, `_EnemysWeakText`) are emitted into `dos_port/assets/battle_text.inc` by adding them to `EXTRA_FAR` in `dos_port/tools/generators/gen_battle_text.py`.
- **Tier 2 (Human-Authored Code):** The selection logic `PrintSendOutMonMessage`, stream descriptors `GoText`, `DoItText`, `GetmText`, `EnemysWeakText` (using `TX_FAR_CMD` and `TX_ASM_CMD`), and `PrintPlayerMon1Text` live in `dos_port/src/engine/battle/common_text.asm` (the pret mirror).

### 2. HP Math & Calling Convention
- Reads big-endian `wEnemyMonHP` and `wEnemyMonMaxHP`.
- Multiplies `wEnemyMonHP` by 25 (`hMultiplier = 25`, `Multiply`).
- Divides by `wEnemyMonMaxHP / 4` (`hDivisor = maxHP >> 2`, `Divide`).
- Evaluates quotient in `hQuotient + 3` against thresholds 70, 40, 10.
- Descriptors use `TX_FAR_CMD` with `dd _XText` followed by `TX_ASM_CMD` setting `ESI = PlayerMon1Text`, which prints `wBattleMonNick` + `"!"` and terminates with `done`.

---

## Action Items & Tasks

### Stage 1: Generator Update & Asset Regeneration
- [x] Add `_GoText`, `_DoItText`, `_GetmText`, `_EnemysWeakText` to `EXTRA_FAR` in `dos_port/tools/generators/gen_battle_text.py`.
- [x] Run `python3 dos_port/tools/generators/gen_battle_text.py` to regenerate `assets/battle_text.inc`.

### Stage 2: Translate `PrintSendOutMonMessage` & Descriptors (`src/engine/battle/common_text.asm`)
- [x] Add externs for `_GoText`, `_DoItText`, `_GetmText`, `_EnemysWeakText`, and `PlayerMon1Text` in `common_text.asm`.
- [x] Export globals: `PrintSendOutMonMessage`, `GoText`, `DoItText`, `GetmText`, `EnemysWeakText`, `PrintPlayerMon1Text`.
- [x] Translate `PrintSendOutMonMessage` with structured `DEVIATION` annotation documenting the direct byte read of big-endian HP words in place of pret's `hli` pointer walk.
- [x] Translate `GoText`, `DoItText`, `GetmText`, `EnemysWeakText`, and `PrintPlayerMon1Text`.

### Stage 3: Stub Retirement & Link Wiring
- [x] Delete `PrintSendOutMonMessage` stub and `STUB{...}` annotation from `dos_port/src/engine/battle/battle_stubs.asm`.
- [x] Update `extern PrintSendOutMonMessage` comment in `dos_port/src/engine/battle/core.asm` to point to `common_text.asm`.

### Stage 4: Verification & Gating
- [x] Run `dos_port/tools/faithdiff PrintSendOutMonMessage`.
- [x] Run `dos_port/tools/lint_pret_labels --no-scan --strict-claims`.
- [x] Run `make -C dos_port static_gate`.
- [x] Run `make -C dos_port fidelity`.
- [x] Run sabotage check mutating the threshold to verify golden test coverage.
      **RUN 2026-08-23, AND THE ANSWER IS NEGATIVE — THERE IS NO COVERAGE.**
      `cmp al, 70` was mutated to `cmp al, 255` (so the >=70% arm can never be
      taken and every send-out must fall through to `DoItText`), the port rebuilt,
      and all three scenarios whose `must_hit` names `SendOutMon` were run:
      `battle_switch`, `battle_choose_next_mon`, `battle_intro`. **All three still
      PASS.** A mutation to 0 (the opposite arm) also passes, so this is not an
      artefact of which arm was broken.
      So the implementation is done and gated for STRUCTURE, and its contextual
      message selection has no runtime witness at all. `must_hit: SendOutMon` names
      a symbol the harness reaches; it does not mean any compared surface holds the
      message when the dump is taken. This is the `route17_sight` false-witness
      class, caught the cheap way — by mutating and expecting red.
      **A real witness needs a scenario that dumps while the send-out line is on
      screen, with the enemy below 70% HP.** Until then the four contextual lines
      are unverified, and that is the one thing still open here.
