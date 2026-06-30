; 1015__RageEffect.asm — RageEffect (move-effect translation swarm worker output).
;
; Faithful translation of engine/battle/effects.asm:RageEffect (pret/pokeyellow).
; Rage just sets the USING_RAGE battle-status bit on the user's side — no accuracy
; test, no text, no animation. The only logic is the hWhoseTurn-based side select
; (player's wPlayerBattleStatus2 vs. enemy's wEnemyBattleStatus2).
;
; Fidelity boundary: docs/move_translation_divergence.md. No §2 allowlist items are
; touched by this handler (no subanim, no audio, no banks, no $FF__ I/O) — it is a
; 1:1 translation of the pret body.
;
; Register map: A=AL, HL=ESI, EBP=GB base. GB memory at [EBP+addr].
;
; Build: nasm -f coff -I include/ -I . -o /dev/null 1015__RageEffect.asm

bits 32

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"

section .text

global RageEffect_

; ===========================================================================
; RageEffect_ — set USING_RAGE on the attacker's battle-status byte.
;
; pret:
;   RageEffect:
;       ld hl, wPlayerBattleStatus2
;       ldh a, [hWhoseTurn]
;       and a
;       jr z, .player
;       ld hl, wEnemyBattleStatus2
;   .player
;       set USING_RAGE, [hl] ; mon is now in "rage" mode
;       ret
; ===========================================================================
RageEffect_:
    mov esi, wPlayerBattleStatus2       ; ld hl, wPlayerBattleStatus2
    mov al, [ebp + hWhoseTurn]          ; ldh a, [hWhoseTurn]
    and al, al
    jz .player                          ; jr z, .player (player's turn → keep player ptr)
    mov esi, wEnemyBattleStatus2        ; ld hl, wEnemyBattleStatus2
.player:
    or byte [ebp + esi], 1 << USING_RAGE   ; set USING_RAGE, [hl]
    ret
