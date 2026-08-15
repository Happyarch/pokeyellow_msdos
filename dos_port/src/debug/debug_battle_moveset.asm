; debug_battle_moveset.asm — DebugLoadWildMonMoves (debug harness only).
;
; DEVIATION{class=temporary; pret=engine/battle/core.asm:LoadEnemyMonData; behavior=this routine duplicates only the .copyStandardMoves/.loadMovePPs slice of LoadEnemyMonData (base moves + level-up learnset + PP) so a debug harness can generate a real wild moveset while every other wEnemyMon* field is hand-seeded for deterministic visual inspection, instead of calling the full translated LoadEnemyMonData (dos_port/src/engine/battle/core.asm), which would also roll random DVs and recompute HP/stats/types and so clobber that hand-seeding; evidence=the routine's sole caller is the DEBUG_BATTLE synthetic-seed path in debug_dump.asm (the branch reached only when DEBUG_BATTLE is defined without DEBUG_BATTLE_GOLDEN — DEBUG_BATTLE_LIVE / DEBUG_BATTLE_ENEMYHIT / DEBUG_BATTLE_TRAINER, per label_status --callers LoadWildMonMoves 2026-08-15, exactly one port caller), none of which appear in tools/scenario_manifest.json, so it carries no golden coverage; lifetime=retire this file if/when the synthetic-seed harness is rewired onto the real LoadEnemyMonData path (not done today, because that would remove the deterministic HP/stat/type seeding those harnesses rely on for visual inspection)}
;
; Was dos_port/src/engine/battle/load_enemy_moves.asm ("LoadWildMonMoves"), sitting
; in the engine/battle pret-mirror directory even though it has no pret counterpart
; (pret builds a wild moveset INLINE inside LoadEnemyMonData; the port's faithful
; translation of that whole routine already lives at
; dos_port/src/engine/battle/core.asm:LoadEnemyMonData and is linked/used elsewhere
; in this file, e.g. the DEBUG_BATTLE_GOLDEN branch's `call LoadEnemyMonData`).
; Relocated here 2026-08-15 (remediation slice S4) because a debug-only helper with
; no pret label does not belong beside real pret-mirrored translation, and renamed
; with the file's `Debug*` convention (anim_show_label / DebugLoadEmbeddedEnemyFrontPic
; / DebugDumpMemory) since it never carried a pret name to preserve.
;
; What it does — the wild-mon moveset slice of LoadEnemyMonData's
; `.copyStandardMoves` + `.loadMovePPs`:
;   1. copy the species' 4 base moves from the mon header (wMonHMoves, from base
;      stats — for PIDGEY that's [GUST,0,0,0]);
;   2. WriteMonMoves walks the level-up learnset (assets/evos_moves.inc, the data
;      past each mon's evolution block) and adds every move the mon would have
;      learned by its level, shifting the oldest out when all 4 slots are full;
;   3. LoadMovePPs writes each move's base PP into the PP slots.
;
; NOTE (Gen 1): the enemy mon carries a PP field like the player's, but the game
; never decrements enemy PP — LoadMovePPs runs here for faithfulness/parity, the
; values are otherwise inert. TM/HM moves are NOT part of wild generation (that
; learnset category only matters when the *player* teaches a TM/HM); only the
; level-up learnset + the base moves feed a wild moveset.
;
; In:  [wEnemyMonSpecies] = internal index, [wEnemyMonLevel] = level.
; Out: wEnemyMonMoves[0..3] + wEnemyMonPP[0..3] populated.
; Clobbers the wMonH* header scratch (via GetMonHeader); leaves wEnemyMon* stats
; untouched (the caller/harness computes/seeds those separately).
;
; Register map (CLAUDE.md): a=AL, hl=ESI, de=EDX, ecx scratch; GB memory [EBP+addr].
;
; Build: nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 -o debug_battle_moveset.o debug_battle_moveset.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

section .text

global DebugLoadWildMonMoves
extern GetMonHeader
extern WriteMonMoves
extern LoadMovePPs

DebugLoadWildMonMoves:
    ; header for the species — GetMonHeader populates wMonHMoves (base moves).
    mov al, [ebp + wEnemyMonSpecies]
    mov [ebp + wCurSpecies], al
    mov [ebp + wCurPartySpecies], al      ; GetMonLearnset keys off wCurPartySpecies
    call GetMonHeader
    ; WriteMonMoves reads the level from wCurEnemyLevel.
    mov al, [ebp + wEnemyMonLevel]
    mov [ebp + wCurEnemyLevel], al
    ; copy the 4 base moves: wMonHMoves → wEnemyMonMoves
    mov al, [ebp + wMonHMoves + 0]
    mov [ebp + wEnemyMonMoves + 0], al
    mov al, [ebp + wMonHMoves + 1]
    mov [ebp + wEnemyMonMoves + 1], al
    mov al, [ebp + wMonHMoves + 2]
    mov [ebp + wEnemyMonMoves + 2], al
    mov al, [ebp + wMonHMoves + 3]
    mov [ebp + wEnemyMonMoves + 3], al
    ; level-up fill. pret `predef WriteMonMoves` with de = move-slot base; the predef
    ; dispatch stashes de in wPredefDE, which WriteMonMoves restores. Set it directly.
    xor al, al
    mov [ebp + wLearningMovesFromDayCare], al
    mov ecx, wEnemyMonMoves
    mov [ebp + wPredefDE], ch              ; big-endian: high byte
    mov [ebp + wPredefDE + 1], cl          ;             low byte
    call WriteMonMoves
    ; PP. pret: hl = wEnemyMonMoves, de = wEnemyMonPP − 1 (LoadMovePPs pre-increments).
    mov ecx, wEnemyMonMoves
    mov [ebp + wPredefHL], ch
    mov [ebp + wPredefHL + 1], cl
    mov ecx, wEnemyMonPP - 1
    mov [ebp + wPredefDE], ch
    mov [ebp + wPredefDE + 1], cl
    call LoadMovePPs
    ret
