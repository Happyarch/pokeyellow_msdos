; run_map_script.asm — RunMapScript + CallFunctionInTable (script engine, Stage 5).
;
; Faithful translation of home/overworld.asm:RunMapScript (the per-frame map-script
; dispatcher) and home/scripting.asm:CallFunctionInTable (the generic jumptable
; dispatch every map _Script uses on its current-script index).
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
extern RunNPCMovementScript         ; src/engine/overworld/overworld.asm

section .text

global RunMapScript
global DefaultMapScript
global CallFunctionInTable

RunMapScript:
    ; pret: push hl / push de / push bc around the boulder step, restored before
    ; RunNPCMovementScript. TryPushingBoulder and the dust animation clobber freely.
    push esi
    push edx
    push ebx
    call TryPushingBoulder                   ; pret: farcall (banking elided)
    mov al, [ebp + wMiscFlags]
    test al, (1 << BIT_BOULDER_DUST)
    jz .afterBoulderEffect                   ; jr z — no push happened this frame
    call DoBoulderDustAnimation              ; pret: farcall (banking elided)
.afterBoulderEffect:
    pop ebx
    pop edx
    pop esi
    call RunNPCMovementScript                ; pret home/overworld.asm:1725
    ; TODO-HW: SwitchToMapRomBank — no-op under the flat address model.
    movzx ecx, byte [ebp + wCurMap]
    call dword [MapScriptPointers + ecx*4]   ; run this map's _Script (flat ptr)
    ret

; Default _Script for maps without a ported one. Most pret map scripts that do
; nothing else are exactly `jp EnableAutoTextBoxDrawing`, so that is the faithful
; default (a few, e.g. Indigo Plateau, are a bare ret — close enough here).
DefaultMapScript:
    jmp EnableAutoTextBoxDrawing

; CallFunctionInTable — call function index AL in the flat dd jumptable ESI.
; pret's version is a 16-bit table (add a / ld a,[hli] / ld h,[hl]); here the table
; is flat dd, so index ×4 and load a 32-bit pointer. ESI/EDX/EBX preserved.
CallFunctionInTable:
    push esi
    push edx
    push ebx
    movzx ecx, al
    mov esi, [esi + ecx*4]
    call esi
    pop ebx
    pop edx
    pop esi
    ret
