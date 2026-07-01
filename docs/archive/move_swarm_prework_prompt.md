# Move-Swarm PRE-WORK Prompt (build the backdrop, then hand off)

Paste the block below into a fresh Claude Code session (Opus 4.8). This session builds the
scaffolding the swarm needs — the queue, the live dispatch, the shared helpers, and one
reference handler — and stops. It does NOT spawn workers. When it's green + committed, start a
SEPARATE fresh session with `docs/move_swarm_kickoff_prompt.md` (the master, clean context).

---

```
You are building the BACKDROP for a move-effect translation swarm on the Pokémon Yellow → MS-DOS
NASM port. Build the scaffold so move-effect bodies can be translated + linked faithfully, then
STOP and hand off — do NOT spawn worker subagents. Keep the build green throughout.

READ FIRST: CLAUDE.md ; docs/move_translation_divergence.md (the fidelity boundary) ;
docs/current_plan_move_swarm.md (work-units + the S2–S4 recipe you are executing).

Context you can rely on (already live + linked): the faithful core.asm battle loop
(MainInBattleLoop), the damage pipeline, GetCurrentMove, DecrementPP, BattleRandom, the generated
effect text (battle_text.inc), the effect-category arrays (ResidualEffects1/ResidualEffects2/
SpecialEffects/SpecialEffectsCont/AlwaysHappenSideEffects/SetDamageEffects, globals in
src/data/battle_data.asm), StatModifierUp/DownEffect (stat_mod_effects.asm), and the 14 drafted
move_effects/*.asm bodies. JumpMoveEffect is currently STUBBED in core_stubs.asm.

BUILD, IN ORDER (build green after each — make -C dos_port SKIP_TITLE=1 DEBUG_BATTLE_LIVE=1):

S2 — QUEUE. Add a `move` category to dos_port/tools/build_index: schema CHECK +(move); a per-LABEL
categoriser that tags (a) all labels in engine/battle/move_effects/*.asm and (b) the hand-listed
inline effect-body labels in pret engine/battle/effects.asm (the 18 in the plan's "translate fresh"
list) as `move`. Seed status: the 16 drafts (14 move_effects/ + StatModifierUp/DownEffect) →
`translated` (audit-first, via TRANSLATED_MAP with their dos_port output paths); the 18 inline ones
→ `needs_translation`. Run `dos_port/tools/build_index --rebuild`; verify
`dos_port/tools/work_queue list --category move` shows ~34 bodies with the right statuses.

S3 — SCAFFOLD (this is the load-bearing part; expect a link cascade and resolve it):
  1. IsInArray — add as a shared home global (src/home/array.asm or similar). It's currently only
     a local label inside trainer_ai.asm / bills_pc.asm. Signature: AL = value, [ESI]=$FF-term
     array (or per pret home/ IsInArray) → CF=1 if found. Make trainer_ai/bills_pc use the global.
  2. Array-gated dispatch — translate pret core.asm:3294-3436 into our
     src/engine/battle/core.asm ExecutePlayerMove (and mirror in ExecuteEnemyMove), REPLACING the
     current simplified "call JumpMoveEffect once after damage". The faithful order:
       - effect in ResidualEffects1   → jp JumpMoveEffect (skip damage + accuracy entirely)
       - effect in SpecialEffectsCont → call JumpMoveEffect (before damage, don't skip)
       - effect in SetDamageEffects   → skip damage CALC, go to MoveHitTest
       - …damage calc / crit / type / randomize / MoveHitTest / apply / HUD…
       - effect in ResidualEffects2   → jp JumpMoveEffect (after damage, done)
       - effect in AlwaysHappenSideEffects → call JumpMoveEffect (after damage, not done)
       - else (SpecialEffects catch-all) → call nc JumpMoveEffect (the X%-chance secondary effects)
     Use the linked arrays in battle_data.asm + your new IsInArray. Preserve any Gen-1 ordering bugs.
  3. Wire JumpMoveEffect LIVE: drop the JumpMoveEffect stub in core_stubs.asm; let effects.asm's
     MoveEffectPointerTable be the real dispatch. Every table entry whose body isn't ported yet
     routes to an UnportedMoveEffect no-op (so it links + a battle can't crash on an unported move).
     Effect text is already generated (battle_text.inc); the move_effects drafts already extern it.
  4. Real shared text/logic helpers (faithful — NOT stubs): PrintStatText, ConditionalPrintButItFailed
     / PrintButItFailedText_, EffectCallBattleCore. (Resolve any other undefined refs the cascade
     surfaces — Bankswitch becomes a flat passthrough/no-op; bare $FF hooks get ; TODO-HW.)
  5. Faithful-animation (ANIMATION=OFF behavior — the game shows these with anims off). Build them
     real; if any one balloons, land it incrementally but at minimum provide a linking symbol:
       - UpdateCurMonHPBar — gradual, tick-by-tick HP-bar drain.
       - PlayApplyingAttackAnimation — the damage shake / mon flash; add a software-PPU blit-offset/
         flash hook to the renderer (it drives rWX / OBJ palette on hardware).
       - HideSubstituteShowMonAnim / ReshowSubstituteAnim — the mon↔substitute pic VRAM swap.
     The literal move subanimation stays PlayMoveAnimation (already the ANIMATION=OFF path); audio
     stays a no-op ; TODO-HW.

S4 — REFERENCE HANDLER. Translate ONE body end-to-end yourself as the gold standard — suggest
PoisonEffect (status-only: accuracy/already-poisoned/type-immunity checks, sets the status byte,
PrintText, and carries a Gen-1 bug tag). Output dos_port/src/engine/battle/move_effects/poison.asm,
body label PoisonEffect_, wired into MoveEffectPointerTable. Build green; this is the template the
swarm copies. Verify in DOSBox-X if practical (DEBUG_BATTLE_LIVE) that a move with that effect works.

WHEN DONE: build green, commit (Co-Authored-By trailer; never commit generated assets/*.inc), mark
S2–S4 [x] in docs/current_plan_move_swarm.md + log to docs/translation_log.md, and tell the user the
backdrop is ready — they will start a FRESH session with docs/move_swarm_kickoff_prompt.md to run
the swarm. Do NOT spawn workers yourself.
```
