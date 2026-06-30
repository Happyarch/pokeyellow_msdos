# Move-Effect Translation — Faithfulness & Allowed-Divergence Spec

**This is the single source of truth for the move-translation swarm.** Worker tickets
and the auditor both cite this file. A translated move-effect handler is FAITHFUL if it
diverges from pret **only** at the items on the Allowlist below. Anything else is a bug
the auditor must flag.

---

## 1. Fidelity target: "ANIMATION = OFF", not "no animation"

The benchmark is **exactly what the original game does when the player sets ANIMATION to
OFF in the options menu** — NOT a stripped-down no-visuals version. With animations off
the game still shows a great deal: HP bars drain tick-by-tick, the screen shakes / the mon
flashes when a damaging move lands, the Substitute doll swaps in and out, and every
stat/status/failure message prints. **All of that is faithful behavior the handler must
perform.** The *only* thing "animations off" removes is the literal move subanimation (the
Thunderbolt bolts, the Tackle lunge, etc.).

So: translate the handler faithfully. It will still call shared routines that animate —
that is correct and required. Do not strip them.

---

## 2. Allowlist — the ONLY permitted divergences (all hardware-specific)

A worker may **call these shared symbols as `extern`s without translating their bodies**,
and the auditor must **not** flag their use. They are the hardware boundary the port hasn't
crossed yet. Nothing else may diverge.

| # | What | How the handler treats it | Why it's allowed |
|---|------|---------------------------|------------------|
| 1 | **Literal move subanimation** (`PlayCurrentMoveAnimation`, `PlayCurrentMoveAnimation2`, the move's `PlayAnimation` VFX stream) | `call PlayMoveAnimation` (already implements pret's ANIMATION=OFF path: a fixed delay + the apply-attack effect) | The subanimation tile/OAM-stream engine isn't ported; ANIMATION=OFF skips exactly this. |
| 2 | **Audio / SFX** (`PlaySound`, `sound_*`, cries) | no-op call + `; TODO-HW: audio HAL (Phase 3)` | Audio HAL is Phase 3. |
| 3 | **Raw `$FF__` I/O registers** | `; TODO-HW:` comment describing the original access (per CLAUDE.md) | Hardware-register boundary. |
| 4 | **Bank switching** (`Bankswitch`, `callfar`/`homecall`/`jpfar` bank loads, `ld [wPredefBank]` for code) | call the flat target directly; drop the bank load | Flat DPMI model has no banks. |

Everything in §3 is the opposite — it must be real.

---

## 3. NOT divergence — these are faithful behavior, must be translated/kept

The handler **must** drive these (they happen with animations off). The scaffold provides
them as real shared routines; the worker calls them and the auditor expects them:

- **HP bar drain** — `UpdateCurMonHPBar` (gradual, tick-by-tick, faithful).
- **Damage shake / mon flash** — `PlayApplyingAttackAnimation` (real, software-PPU).
- **Substitute doll swap** — `HideSubstituteShowMonAnim` / `ReshowSubstituteAnim` (real pic swap).
- **All text** — `PrintText`, `PrintStatText`, `ConditionalPrintButItFailed` /
  `PrintButItFailedText`, and any `XxxText` stream (generated in `battle_text.inc`).
- **All control flow into the battle core** — `EffectCallBattleCore`, `JumpMoveEffect`.
- **Every WRAM read/write**: stat stages, status bytes, battle-status flags, HP, counters,
  RNG (`BattleRandom`), damage, etc. — translate verbatim per the register map.
- **Bug / glitch preservation** (see §5).

---

## 4. Shared-extern interface (provided by the scaffold — call, never define)

These globals exist before the swarm starts. A worker **calls** them and lists them as
`extern`; it must **not** define or re-translate them. (Faithful behavior; §3.)

```
; --- text / logic (real) ---
PrintText                 ; print a battle_text.inc stream (ESI = stream GB offset)
PrintStatText             ; the stat name in "<MON>'s <STAT> rose/fell!"
ConditionalPrintButItFailed / PrintButItFailedText_   ; "But it failed!"
EffectCallBattleCore      ; tail back into the battle-core control flow
IsInArray                 ; scan a $FF-terminated byte array for AL; CF=found
BattleRandom              ; battle RNG
StatModifierUpEffect / StatModifierDownEffect   ; shared stat-stage effect bodies
DecrementPP, GetCurrentMove, the damage pipeline  ; already live
; --- faithful animation (real, ANIMATION=OFF behavior) ---
UpdateCurMonHPBar         ; gradual HP-bar drain
PlayApplyingAttackAnimation   ; damage shake / mon flash (software-PPU)
HideSubstituteShowMonAnim / ReshowSubstituteAnim   ; substitute doll swap
; --- allowlist stubs (HW-deferred; §2) ---
PlayMoveAnimation         ; literal subanim → ANIMATION=OFF path (delay + apply-attack)
```

The effect-category arrays the dispatch uses (already generated + linked in `battle_data.asm`):
`ResidualEffects1`, `ResidualEffects2`, `SpecialEffects`, `SpecialEffectsCont`,
`AlwaysHappenSideEffects`, `SetDamageEffects`.

---

## 5. Bug / glitch tagging (mandatory — auditor verifies)

Per project convention (CLAUDE.md, `docs/bugs_and_glitches.md`, `docs/glitch_safety.md`):

- A known pret bug at the site → a `; BUG(critical|cosmetic): <desc> — pret ref: <file>:<label>`
  comment **and** a `%if BUG_FIX_LEVEL >= N … %else … %endif` block carrying the original
  (buggy) behavior in the `%else` branch.
- A user-exploitable glitch → `; GLITCH: <name> — <desc>` + a safety note.
- **Faithfulness includes preserving these.** Silently "fixing" a Gen-1 move bug (e.g. the
  1/256 miss, Hyper Beam's no-recharge-on-faint, Focus Energy's crit *reduction*, the
  partial-trapping/​Wrap quirks, Substitute's self-KO, Counter target bug) is a divergence
  the auditor must flag.

---

## 6. Worker rules (one effect-handler label per ticket)

1. Read the exact pret label named in the ticket (and surrounding context).
2. Translate to NASM 32-bit per the register map; all GB memory via `[EBP + const]`.
3. **Call** §4 shared externs; **translate** everything else (§3). Diverge only per §2.
4. Apply §5 bug/glitch tags wherever pret's source or `bugs_and_glitches.md` calls for them.
5. Write only to `dos_port/scratch/<id>__<label>.asm`; never edit an existing file; never
   wire into `MoveEffectPointerTable` (that's the master's live-graph job).
6. `nasm -f coff -o /dev/null <file>` must pass. Report path + nasm output.

## 7. Auditor rules (Sonnet; before integration; 2 per 5 workers)

Read-compare the scratch `.asm` against the pret label. **Faithful** =
- every WRAM/state/control step matches pret (no missing/extra/reordered effects),
- divergences are limited to the §2 allowlist,
- §5 bug/glitch tags present wherever pret has the bug.

Output a verdict (FAITHFUL / DIVERGENT) + the specific divergence(s). Do **not** edit code.
On DIVERGENT, the master fixes trivial misses (a missing `; TODO-HW`/BUG tag) itself and
re-queues real logic divergence as `needs_translation` to a fresh worker.
