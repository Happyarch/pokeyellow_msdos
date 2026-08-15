; run_map_script.asm — DefaultMapScript (script engine, Stage 5).
;
; *** WHAT THIS FILE ACTUALLY CONTAINS (corrected 2026-08-02): DefaultMapScript,
; *** and nothing else. RunMapScript itself now lives in src/home/overworld.asm,
; *** its pret mirror. Everything below describing RunMapScript's behaviour is
; *** retained because it is accurate and load-bearing documentation OF THAT
; *** ROUTINE — but read it there. This header described a routine the file no
; *** longer held, which is how a reader ends up editing the wrong copy.
;
; Faithful translation of home/overworld.asm:RunMapScript (the per-frame map-script
; dispatcher). CallFunctionInTable used to live here too, attributed to a
; home/scripting.asm that does not exist — it is a home/array2.asm label and now
; sits in src/home/array2.asm.
;
; Each overworld frame, RunMapScript runs the current map's _Script. In the flat
; port the dispatch is a flat `dd` MapScriptPointers table indexed by wCurMap
; (gen_map_scripts.py), defaulting to DefaultMapScript (a no-op) for maps without a
; ported script — mirroring WildDataPointers / EvosMovesPointerTable.
;
; DECOMPOSITION CLOSED (overworld-events Stage 4, boulder bullet). This file was
; previously a SKELETON: only the _Script dispatch, with pret's boulder step dropped
; and RunNPCMovementScript hoisted up into OverworldLoop. Both are now back inside
; RunMapScript, in pret's order, so this routine is structurally faithful again:
;   TryPushingBoulder → [dust] → RunNPCMovementScript → the map's _Script.
; That ordering is load-bearing, not cosmetic: pret pushes the boulder BEFORE NPC
; movement runs. It also fixes a silent divergence in the port's OTHER caller —
; AllPokemonFainted (home/wild_encounter_check.asm) calls RunMapScript exactly as
; pret does (home/overworld.asm:319), so under the skeleton it was quietly getting
; only the _Script dispatch and none of the steps pret gives it.
;
; Remaining sanctioned deviations (see docs/plans/current_plan_script_engine.md and
; stigmergy memory `faithdiff-no-call-relocation-model`):
;   - No JoypadOverworld. pret reaches RunMapScript from JoypadOverworld
;     (home/overworld.asm:1583); the port calls it directly from OverworldLoop, so
;     faithdiff still reports JoypadOverworld `missing` + these calls ADDED on
;     OverworldLoop. That half of the decomposition is still open.
;   - The _Script dispatch is a flat MapScriptPointers table indexed by wCurMap
;     (gen_map_scripts.py) rather than pret's wCurMapScriptPtr / `jp hl`, mirroring
;     WildDataPointers / EvosMovesPointerTable.
;   - SwitchToMapRomBank — ; TODO-HW: no-op under the flat address model.
;
; Register map: a=AL, hl=ESI, ecx scratch.
;
; Build: nasm -f coff -I include/ -I . -o run_map_script.o run_map_script.asm

bits 32

%include "gb_memmap.inc"

extern MapScriptPointers
extern EnableAutoTextBoxDrawing
extern TryPushingBoulder            ; src/engine/overworld/push_boulder.asm
extern DoBoulderDustAnimation       ; src/engine/overworld/push_boulder.asm
extern RunNPCMovementScript         ; src/home/npc_movement.asm

section .text

global DefaultMapScript


; Default _Script for maps without a ported one. Most pret map scripts that do
; nothing else are exactly `jp EnableAutoTextBoxDrawing`, so that is the faithful
; default (a few, e.g. Indigo Plateau, are a bare ret — close enough here).
; Measured 2026-08-15: 209 of 224 pret scripts/*.asm map scripts match this
; exact one-line body (`call`/`jp EnableAutoTextBoxDrawing`); IndigoPlateau_Script
; is the lone bare-`ret` case found. DefaultMapScript has no single pret
; counterpart label — it is port-only glue synthesizing that shared pattern for
; the generated MapScriptPointers dispatch table (gen_map_scripts.py), exactly
; as WildDataPointers/EvosMovesPointerTable synthesize their own defaults —
; hence the DEVIATION below rather than a per-map fork.
; DEVIATION{class=projection; pret=scripts/CeladonHotel.asm:CeladonHotel_Script; behavior=one shared port-only default routine stands in for the ~209 pret per-map _Script bodies that are exactly `jp EnableAutoTextBoxDrawing`, referenced by MapScriptPointers[wCurMap] instead of pret's per-map identical labels; evidence=grep across scripts/*.asm counts 209/224 matching this exact body, plus IndigoPlateau_Script as a bare-ret outlier tolerated here; lifetime=retires per map as each map real _Script is ported and wired into MapScriptPointers, shrinking DefaultMapScript's caller set toward zero}
DefaultMapScript:
    jmp EnableAutoTextBoxDrawing
