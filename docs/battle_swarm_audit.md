# Battle-engine faithfulness AUDIT swarm (read-only, prerequisite)

**Purpose.** Before any new battle-engine implementation, do a **read-only** faithfulness
sweep of *all current battle code* to (a) find where previous runs diverged from pret and
(b) re-scope the implementation tickets. **No agent in this swarm edits code.** Output is a
single ranked findings report + (optionally) `needs_translation` tickets for confirmed
divergences.

This is the ideal swarm shape: read-only = zero file contention, so fan as wide as you like.

---

## Ground truth

- **pret is the spec.** The SM83 disassembly at the repo root (`engine/`, `home/`,
  `constants/`, `data/`, `ram/`) is authoritative. Every port routine keeps pret's label
  name; audit by comparing the port `.asm` to the same-named pret label.
- **Fidelity boundary:** `docs/plans/move_translation_divergence.md`. A routine is FAITHFUL
  iff it diverges from pret **only** at the §2 allowlist (literal move subanimation → the
  ANIMATION=OFF stub; audio/SFX; raw `$FF__` I/O; bank switching/`callfar`/`jpfar`/`predef`
  → flat call). Everything else — every WRAM read/write, RNG draw, counter, status/stat bit,
  branch, and text — must match pret. Gen-1 bugs/glitches must be **preserved** and tagged
  (`; BUG(level):` + `%if BUG_FIX_LEVEL >= N … %else … %endif`, or `; GLITCH:`); a silently
  "fixed" Gen-1 bug is a divergence.
- **Register map** (for reading the port): A=AL; F.Z/F.C=ZF/CF; BC=BX (B=BH,C=BL); DE=EDX;
  HL=ESI; EBP=GB base, GB addr X = `[ebp+X]`; a BC/DE/HL holding a GB *address* is carried in
  full EBX/EDX/ESI. Semantic-preserving register reshuffles are NOT divergences.

## Scope (audit every one of these against its pret label)

Fan the files below across auditors (see topology). Each auditor gets a slice.

**Battle turn-loop & damage (`dos_port/src/engine/battle/`)**
- `core.asm` — MainInBattleLoop (pret `core.asm:289`), ExecutePlayerMove (`:3244`),
  ExecuteEnemyMove (`:5639`), CheckPlayerStatusConditions (`:3499`),
  CheckEnemyStatusConditions (`:5859`), HandleSelfConfusionDamage (`:3843`),
  PrintMoveIsDisabledText (`:3821`), the faint handlers, ApplyAttackTo* , SwapPlayerAndEnemyLevels (`:6370`).
- `core_stubs.asm` — every stub here is a KNOWN deferral; **flag each as `STUB` (not a
  divergence)** with the pret label it stands in for, so the masters know what's real vs stubbed.
- `core_damage.asm` (CriticalHitTest, MoveHitTest, GetDamageVarsFor*, CalculateDamage,
  AdjustDamageForMoveType, RandomizeDamage), `get_current_move.asm`, `decrement_pp.asm`,
  `residual_damage.asm` (HandlePoisonBurnLeechSeed, pret `core.asm:479`), `building_rage.asm`,
  `badge_boosts.asm`, `status_penalties.asm`.

**Move-effect handlers (`move_effects/*.asm` + `effects.asm` + `stat_mod_effects.asm`)**
- All 34 handlers + `MoveEffectPointerTable` (effects.asm). Compare each to its
  `engine/battle/effects.asm` / `engine/battle/move_effects/*.asm` label. Confirm the
  `translation_log.md` "Divergences" claims are accurate and the Gen-1 bug tags are present
  (SleepEffect / FreezeBurnParalyze hyper-beam-recharge, Disable non-link PP-skip,
  Substitute self-KO, Heal MSB-compare, Transform ×2, Mimic GLITCH, etc.).
- `move_effect_helpers.asm` — confirm the shared helpers match pret and the stubs are the
  allowlist set.

**Battle data (Tier-1, generated) — audit the GENERATOR, not the `.inc`**
- `tools/gen_battle_text.py`, `gen_trainer_parties.py`, `gen_trainer_names.py`,
  `gen_move_grammar.py`, `gen_type_names.py`, `gen_effect_categories.py`, `gen_battle_hud_inc.py`
  vs the pret data they read. Flag any value that deviates from pret without a documented override.

**HUD / menus / init**
- `battle_hud.asm`, `battle_menu.asm`, `battle_hud.asm`, `init_battle.asm`,
  `init_battle_variables.asm`, `select_enemy_move.asm`, `load_enemy_moves.asm`,
  `wild_encounters.asm`, `pokeballs.asm`, `experience.asm`, `trainer_ai.asm`.

(You may extend to `pokemon/`, `items/`, `home/` if time allows — but battle is the priority.)

## Topology

- **N Sonnet read-only auditors** (recommend 8–12). Each owns a file slice. Tools:
  read/grep/build-check only — **never Edit/Write**. An auditor reads a port routine and its
  pret label side-by-side and classifies each routine.
- **1 Opus aggregator** collates all auditor reports into ONE ranked findings report
  (most-severe divergence first), de-dupes, and — if you enable it — files a
  `needs_translation` ticket (or `reset`s an existing one) per **confirmed** divergence via
  `dos_port/tools/work_queue`.

## Per-routine verdict format (each auditor returns this list)

```
ROUTINE: <PortLabel>  (file: <path>  ←  pret <file>:<label/line>)
VERDICT: FAITHFUL | DIVERGENT | STUB (deferred, names pret target) | PARTIAL
DIVERGENCES: for DIVERGENT/PARTIAL — each concrete mismatch with the pret line ref and the
  wrong port line; classify each as allowlist(OK) vs real. For STUB — the pret label it
  defers + whether the flag/return contract is faithful.
BUG_TAGS: expected Gen-1 bug/glitch present & correct? (which, or "none expected")
SEVERITY: high (wrong gameplay/state) | medium (wrong text/edge) | low (cosmetic/comment)
```

## Rules

1. **Read-only. No edits.** Any auditor that wants to "just fix" a thing instead files a finding.
2. Distinguish **DIVERGENT** (a real fidelity bug) from **STUB** (a known, intentional deferral —
   e.g. everything in `core_stubs.asm`, the anim/audio no-ops). Stubs are not divergences;
   report them so the masters know the deferral surface.
3. Cite the pret `file:line` for every claim. No claim without a pret reference.
4. Prefer confirming the `translation_log.md` "Divergences" fields are complete and accurate —
   incomplete divergence logs are themselves findings (this bit the move-swarm: LeechSeed's
   §2.4 was missing).

## Deliverable

`docs/battle_audit_findings.md` — the aggregator's single ranked report, grouped by
subsystem, most-severe first, each finding actionable (file, routine, pret ref, what's wrong,
suggested owner: Master A/B/C). This report re-scopes the implementation swarm.
