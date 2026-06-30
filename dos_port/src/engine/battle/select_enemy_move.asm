; select_enemy_move.asm — SelectEnemyMove (battle front-end, Wave 2 Stage 2b).
;
; Faithful translation of engine/battle/core.asm:SelectEnemyMove. Picks the move the
; enemy will use this turn into wEnemySelectedMove.
;
; AI scope (user directive 2026-06-29): the WILD random-move path is the whole of
; the enemy's move choice for now, and it doubles as the default stub for EVERY
; opponent — trainer-AI move scoring (pret `callfar AIEnemyTrainerChooseMoves`,
; ported in trainer_ai.asm but unwired) is deferred, so wild + trainer both fall
; straight into .chooseRandomMove. The random selection rolls BattleRandom and
; assigns 25% to each of the 4 move slots, re-rolling on a disabled or empty slot.
;
; Forced-move early-outs (recharge/charge/thrash/freeze/sleep/trapping/bide) `ret`
; without choosing, leaving the previously-selected move in place — faithful to the
; GB, where those states lock the mon into its current move.
;
; Register map (CLAUDE.md): a=AL, b=BH, c=BL (bc=BX), hl=ESI; GB memory at [EBP+addr].
;
; Build: nasm -f coff -I include/ -I . -o select_enemy_move.o select_enemy_move.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

; pret `n percent` = n * $ff / 100 (macros/data.asm). 25→63, 50→127, 75→191.
%define PERCENT(n) ((n) * 0xFF / 100)

section .text

global SelectEnemyMove
extern BattleRandom

SelectEnemyMove:
    ; TODO-HW: link-battle move exchange (Phase 4 network HAL). Single-player skips
    ; it and selects locally; the link path would read the opponent's chosen move.
    mov al, [ebp + wLinkState]
    cmp al, LINK_STATE_BATTLING
    jne .noLinkBattle
    ; (link path not implemented; fall through to local selection for determinism)
.noLinkBattle:
    ; --- forced-move early-outs: keep the current wEnemySelectedMove ---
    mov al, [ebp + wEnemyBattleStatus2]
    test al, (1 << NEEDS_TO_RECHARGE) | (1 << USING_RAGE)   ; Hyper Beam recharge / Rage
    jnz .ret
    mov al, [ebp + wEnemyBattleStatus1]
    test al, (1 << CHARGING_UP) | (1 << THRASHING_ABOUT)    ; Solar Beam/Fly / Thrash
    jnz .ret
    mov al, [ebp + wEnemyMonStatus]
    test al, (1 << FRZ) | SLP_MASK                          ; frozen or asleep
    jnz .ret
    mov al, [ebp + wEnemyBattleStatus1]
    test al, (1 << USING_TRAPPING_MOVE) | (1 << STORING_ENERGY)  ; Wrap etc. / Bide
    jnz .ret
    mov al, [ebp + wPlayerBattleStatus1]
    test al, (1 << USING_TRAPPING_MOVE)   ; caught in the player's trapping move
    jz .canSelectMove
.unableToSelectMove:
    mov al, 0xFF
    jmp .done
.canSelectMove:
    ; if the 2nd move slot is empty there is only one move; Struggle if it is disabled
    mov esi, wEnemyMonMoves + 1
    mov al, [ebp + esi]                   ; a = move slot 1 ([hld])
    dec esi                               ; esi -> slot 0
    test al, al
    jnz .atLeastTwoMovesAvailable
    mov al, [ebp + wEnemyDisabledMove]
    test al, al
    mov al, STRUGGLE
    jnz .done                             ; only move is disabled → Struggle
    ; else: one usable move — fall through; the random loop re-rolls onto slot 0
.atLeastTwoMovesAvailable:
.chooseRandomMove:
    push esi                              ; remember slot-0 ptr for re-rolls
    call BattleRandom
    mov bh, 1                             ; b = 1: 25% → move 1
    cmp al, PERCENT(25)
    jb .moveChosen
    inc esi
    inc bh                                ; 25% → move 2
    cmp al, PERCENT(50)
    jb .moveChosen
    inc esi
    inc bh                                ; 25% → move 3
    cmp al, PERCENT(75) - 1
    jb .moveChosen
    inc esi
    inc bh                                ; 25% → move 4
.moveChosen:
    mov al, bh
    dec al
    mov [ebp + wEnemyMoveListIndex], al
    mov al, [ebp + wEnemyDisabledMove]
    shr al, 4                             ; pret `swap a` + `and $f` = high nybble = disabled slot
    cmp al, bh                            ; chosen slot == disabled slot?
    mov al, [ebp + esi]                   ; a = candidate move id ([hl]); preserves flags
    pop esi                               ; restore slot-0 ptr
    je .chooseRandomMove                  ; disabled → re-roll
    test al, al
    jz .chooseRandomMove                  ; empty slot → re-roll
.done:
    mov [ebp + wEnemySelectedMove], al
.ret:
    ret
