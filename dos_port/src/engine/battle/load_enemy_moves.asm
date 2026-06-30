; load_enemy_moves.asm — LoadWildMonMoves (battle front-end, Wave 2 Stage 2b/3).
;
; Faithful port of the wild-mon moveset path of engine/battle/core.asm:LoadEnemyMonData
; (the `.copyStandardMoves` branch + `.loadMovePPs`). This is how the actual game
; builds a wild Pokémon's moveset:
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
; untouched (the caller/encounter path computes those separately).
;
; Register map (CLAUDE.md): a=AL, hl=ESI, de=EDX, ecx scratch; GB memory [EBP+addr].
;
; Build: nasm -f coff -I include/ -I . -o load_enemy_moves.o load_enemy_moves.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

section .text

global LoadWildMonMoves
extern GetMonHeader
extern WriteMonMoves
extern LoadMovePPs

LoadWildMonMoves:
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
