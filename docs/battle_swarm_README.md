# Battle-engine swarm — entry point

Parallelizes the remaining battle-engine work across three Opus masters (each driving a
Sonnet worker/auditor/docs sub-swarm), preceded by a read-only faithfulness audit. Hand each
master its own doc; run the audit first.

## Run order

1. **Audit swarm (read-only, prerequisite).** `docs/battle_swarm_audit.md`. Sweeps *all*
   current battle code vs pret and writes `docs/battle_audit_findings.md` (ranked, most-severe
   first, each finding tagged with a suggested owner A/B/C). This tells you what prior runs got
   wrong AND re-scopes the master tickets. **Do this before launching A/B/C.** No edits, no
   branches — pure fan-out + one Opus aggregator.
2. **Masters A / B / C, concurrently**, each on its own branch/worktree, consuming the audit
   findings for their subsystem:
   - `docs/battle_swarm_master_A.md` — turn execution & special-move mechanics → branch `battle-swarm-A`
   - `docs/battle_swarm_master_B.md` — battle text & HUD pacing (message-overrun fix) → branch `battle-swarm-B`
   - `docs/battle_swarm_master_C.md` — lifecycle, multi-mon & sub-UIs → branch `battle-swarm-C`
3. **Merge.** Fast-forward/merge A, then B, then C into `master`. Non-overlapping routines
   auto-merge; resolve any true overlap by hand (rare — see the partition). Rebuild green
   (levels 0 and 2) after each merge.

## Why branches, not a shared tree

`core.asm` is one file containing all three subsystems' routines (turn-flow = A,
`MainInBattleLoop` pacing = B, faint/lifecycle = C). Concurrent agents on the *same* working
tree would clobber each other. Separate branches/worktrees let each master edit `core.asm`
freely; git merges the non-overlapping hunks. **Ownership is by routine, not by file** — each
master doc lists exactly which routines it owns and says "stay in your lane."

## File / routine partition (enforced by isolation + the per-doc lane rules)

| Master | Owns (routines / files) | Effective workers |
|---|---|---|
| **A** | leaf routines as new files (Counter, MirrorMove, Metronome), crit/effectiveness/ghost/failure text, charging-move flow, EXPLODE; `core_stubs.asm`; `ExecuteXxxMove` bodies | up to ~8 (independent new files) |
| **B** | `battle_hud.asm`, `UpdateCurMonHPBar` + text engine (`PrintBattleText`/`RunBattleTextStream`/`BattlePromptWait`), `MainInBattleLoop` menu-redraw gating only | ~2–3 (serial integration) |
| **C** | faint/switch handlers, multi-mon send-out, party↔battle-mon sync, `battle_menu.asm` sub-UIs, `trainer_ai.asm`, `CheckForDisobedience` | ~4 (sub-UIs couple to items/party layers) |

Don't over-provision B/C — width past the table just burns tokens on merge coordination.

## Shared conventions (every agent obeys)

- **pret is the spec** (`engine/battle/core.asm` etc., read-only). Cite `file:line` per unit.
- **Fidelity boundary:** `docs/plans/move_translation_divergence.md` — diverge only at the §2
  allowlist (literal subanim → ANIMATION=OFF stub; audio; raw `$FF__`; bank/`callfar`/`jpfar`/
  `predef` → flat call). Everything else real. Preserve Gen-1 bugs/glitches with
  `; BUG(level):` + `%if BUG_FIX_LEVEL >= N` (or `; GLITCH:`). ANIMATION=OFF is faithful: HP
  bars drain, screen shakes, mon flashes — only the literal subanimation is skipped.
- **Register map:** A=AL; BC=BX; DE=EDX; HL=ESI; EBP=GB base, `[ebp+X]`; `percent` = `* $FF / 100`.
- **Topology precedent:** `docs/plans/move_swarm.md` (the move-effect swarm — same
  master/worker/auditor/docs shape, proven).
- **Build:** `make -C dos_port SKIP_TITLE=1 DEBUG_BATTLE_LIVE=1` (and `BUG_FIX_LEVEL=2`) green
  after every integration. Live-verify UX-timing work (Master B) via `dos_port/run` or the
  DOSBox-X MCP. Never commit generated `assets/*.inc`.
- **Queue:** `dos_port/tools/work_queue` (categories, atomic `claim --category`,
  `complete/place/wire/verify`, `reset`, `stub`). Seed per-subsystem categories per master;
  no DB schema change needed — contention is prevented by the branch/routine partition.

## Ledger

Each master keeps `docs/translation_log.md` current (every integrated unit → an entry whose
**Divergences** field lists each allowlist divergence + a one-line why; a faithful body records
"none (faithful)"). Commit in batches on the human's say-so only, with the `Co-Authored-By`
trailer.
