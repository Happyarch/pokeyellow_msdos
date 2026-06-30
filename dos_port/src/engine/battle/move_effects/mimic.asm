; 1016__MimicEffect.asm — MimicEffect (move-translation swarm worker ticket 1016).
;
; Faithful translation of engine/battle/effects.asm:MimicEffect (pret/pokeyellow).
; Mimic: a 50-frame delay, then an accuracy test; on a hit, picks a move from the
; TARGET's move list and overwrites the USER's own Mimic-slot move with it for the
; rest of the battle. Two distinct move-pick paths (both faithfully kept, §3):
;   - .getRandomMove: random pick (BattleRandom & 3) — used when the AI (enemy turn)
;     uses Mimic, OR when the player uses it in a LINK battle.
;   - .letPlayerChooseMove: the human player, in a normal (non-link) battle, gets to
;     CHOOSE which of the foe's moves to mimic via a move-selection menu — a real
;     Gen-1 asymmetry vs. the AI's random pick (GLITCH tag below).
;
; Fidelity boundary: docs/move_translation_divergence.md. Shared externs (§4) are
; called, not redefined; only §2 allowlist items (literal subanim, audio, banks)
; diverge. Template: dos_port/src/engine/battle/move_effects/poison.asm.
;
; Register map: A=AL, B=BH, C=BL (BC=BX/EBX), D/E=DL (scratch byte, see note below),
; HL=ESI (full 32-bit GB-address pairs, [ebp+esi] idiom). EBP=GB base.
;
; Note on D: pret's MimicEffect uses register D purely as an 8-bit scratch holding
; the picked-move-id byte (never as a GB address/pointer in this routine, unlike
; poison.asm's DE/EDX usage) — translated here as plain DL, not EDX-as-pointer.
;
; Build: nasm -f coff -I include/ -I . -o /dev/null 1016__MimicEffect.asm

bits 32

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"

section .text

global MimicEffect_

; --- shared scaffold externs (§4: call, never define) ---
extern MoveHitTest                  ; core_damage.asm — accuracy test → wMoveMissed
extern BattleRandom                 ; core_damage.asm / home/random.asm
extern PrintText                    ; move_effect_helpers.asm — ESI = flat text stream
extern PrintButItFailedText_        ; move_effect_helpers.asm
extern DelayFrames                  ; video/frame.asm — BL = frame count
; --- allowlist anim stub (§2 item 1: literal subanim, ANIMATION=OFF path) ---
extern PlayCurrentMoveAnimation
; --- battle_text.inc stream (global in core.o) ---
extern MimicLearnedMoveText

; --- real, already-live routines elsewhere in the port (not listed in §4's example
; table, but real/linked, not effect-private — called per §3, never redefined here) ---
extern GetMoveName                  ; home/names.asm — [wNamedObjectIndex] → wNameBuffer
extern MoveSelectionMenu            ; engine/battle/core.asm — see TODO(master) below
extern LoadScreenTilesFromBuffer1   ; engine/battle/battle_menu.asm

; ===========================================================================
; MimicEffect_ — copy a move from the target's moveset into the user's Mimic
; slot for the remainder of the battle. Accuracy-tested (MoveHitTest); misses
; outright if the target is INVULNERABLE (charging Fly/Dig).
; ===========================================================================
MimicEffect_:
    mov bl, 50                          ; ld c, 50
    call DelayFrames
    call MoveHitTest
    mov al, [ebp + wMoveMissed]
    and al, al
    jnz .mimicMissed
    mov al, [ebp + hWhoseTurn]
    and al, al                          ; ZF=1 → player's turn; ZF=0 → enemy's turn
                                         ; (flags held live across the two mov's below,
                                         ; exactly as pret's ld/ld doesn't touch flags)
    mov esi, wBattleMonMoves            ; hl = wBattleMonMoves (target's moves, if
                                         ; this turns out to be the enemy's turn)
    mov dl, [ebp + wPlayerBattleStatus1]   ; a = wPlayerBattleStatus1 (target battlestatus
                                         ; if enemy's turn — player is the target)
    jnz .enemyTurn                      ; hWhoseTurn != 0 → enemy's turn: target = player
    ; --- player's turn: link battle picks at random; normal battle lets the
    ; player choose (the Gen-1 asymmetry — GLITCH, see .letPlayerChooseMove) ---
    mov al, [ebp + wLinkState]
    cmp al, LINK_STATE_BATTLING
    jne .letPlayerChooseMove
    mov esi, wEnemyMonMoves             ; link battle: target = enemy, random pick
    mov dl, [ebp + wEnemyBattleStatus1]
.enemyTurn:
    test dl, 1 << INVULNERABLE          ; bit INVULNERABLE, a — target charging Fly/Dig?
    jnz .mimicMissed
.getRandomMove:
    push esi                            ; push hl
    call BattleRandom
    and al, 3                           ; and $3
    movzx ebx, al                       ; ld c, a / ld b, 0
    add esi, ebx                        ; add hl, bc
    mov al, [ebp + esi]                 ; ld a, [hl]
    pop esi                             ; pop hl
    and al, al
    jz .getRandomMove                   ; loop until a non-empty move slot is hit
    mov dl, al                          ; ld d, a — picked move id
    mov al, [ebp + hWhoseTurn]
    and al, al
    mov esi, wBattleMonMoves            ; hl = user's own moves (write target)
    mov al, [ebp + wPlayerMoveListIndex]   ; a = index of the Mimic slot itself
    jz .playerTurn
    mov esi, wEnemyMonMoves
    mov al, [ebp + wEnemyMoveListIndex]
    jmp .playerTurn
.letPlayerChooseMove:
    mov al, [ebp + wEnemyBattleStatus1]
    test al, 1 << INVULNERABLE
    jnz .mimicMissed
    mov al, [ebp + wCurrentMenuItem]
    push eax                            ; push af — only AL (the index) matters
    mov byte [ebp + wMoveMenuType], 1   ; select the "choose which foe move to mimic" UI
    ; TODO(master): the live MoveSelectionMenu (engine/battle/core.asm) explicitly defers
    ; the mimic-mode menu (wMoveMenuType=1, listing wEnemyMonMoves) — its header comment
    ; says "Mimic/relearn menus ... deferred (not reachable here)"; it always lists the
    ; player's OWN wBattleMonMoves regardless of wMoveMenuType. Faithful pret call kept
    ; here (§3 control-flow-into-battle-core); the actual mimic-mode listing/selection is
    ; a real gap in core.asm's MoveSelectionMenu, not something this handler can fix.
    call MoveSelectionMenu
    call LoadScreenTilesFromBuffer1
    mov esi, wEnemyMonMoves
    movzx ebx, byte [ebp + wCurrentMenuItem]
    add esi, ebx                        ; (kept as add+deref rather than a single
    mov dl, [ebp + esi]                 ; [ebp+esi+ebx] form — see recoil.asm precedent)
    pop eax
    mov esi, wBattleMonMoves            ; hl = wBattleMonMoves — on the player's turn the
                                         ; write target is always the player's own moves
.playerTurn:
    movzx ebx, al                       ; ld c, a / ld b, 0 — index of the Mimic slot
    add esi, ebx                        ; add hl, bc
    mov al, dl                          ; ld a, d — the picked/chosen move id
    mov [ebp + esi], al                 ; ld [hl], a — overwrite the Mimic slot
    mov [ebp + wNamedObjectIndex], al
    call GetMoveName
    call PlayCurrentMoveAnimation
    mov esi, MimicLearnedMoveText
    jmp PrintText
.mimicMissed:
    jmp PrintButItFailedText_

; GLITCH: player-chooses-vs-AI-random Mimic asymmetry — pret ref:
; engine/battle/effects.asm:MimicEffect (.letPlayerChooseMove vs .getRandomMove).
; In a normal (non-link) battle the HUMAN player is shown a move-selection menu and
; freely CHOOSES which of the target's moves to copy; the enemy AI (and the player in
; a link battle) gets a uniformly random pick via BattleRandom & 3 (looping past empty
; slots). This is genuine Gen-1 behavior, not a translation bug — preserved verbatim,
; not "fixed" to be symmetric.
; Safety: safe — pure battle-logic fairness quirk, no engine/OOB hazard.
