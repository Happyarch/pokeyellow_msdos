; 961__ExplodeEffect.asm — ExplodeEffect (move-effect translation swarm worker output).
;
; Faithful translation of engine/battle/effects.asm:ExplodeEffect (pret/pokeyellow).
; Self-Destruct / Explosion's effect body: zeroes the USER's own HP and status, and
; clears the user's SEEDED (Leech Seed) bit. EXPLODE_EFFECT's other special-casing —
; "even if Explosion or Selfdestruct missed, its effect still needs to be activated"
; and the defense-halving in the damage formula — lives in engine/battle/core.asm
; (cp EXPLODE_EFFECT sites), not in this handler; this ticket is ExplodeEffect's body
; only, per pret engine/battle/effects.asm:185-202.
;
; Fidelity boundary: docs/move_translation_divergence.md. Shared externs (§4) are
; called, not redefined; only §2 allowlist items (literal subanim, audio, banks)
; diverge — none of those apply to this handler (no animation/sound/bank calls in
; pret's ExplodeEffect body).
;
; Register map: A=AL, B=BH, C=BL (BC=BX), D=DH, E=DL (DE=EDX), HL=ESI, EBP=GB base.
; GB memory at [EBP+addr].
;
; Build: nasm -f coff -I include/ -I . -o /dev/null 961__ExplodeEffect.asm

bits 32

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"

section .text

global ExplodeEffect_

; ===========================================================================
; ExplodeEffect_ — pret engine/battle/effects.asm:ExplodeEffect. Sets the
; ATTACKING (using) mon's own HP to 0, status to 0, and clears its SEEDED bit.
; No accuracy test, no substitute check, no text — this is the bare backend
; effect; the faint/HP-bar/message handling happens in the battle core's
; general post-move-effect flow (EXPLODE_EFFECT is special-cased there to
; always apply even on a miss).
; ===========================================================================
ExplodeEffect_:
    mov esi, wBattleMonHP               ; hl = wBattleMonHP (player's own mon)
    mov edx, wPlayerBattleStatus2       ; de = wPlayerBattleStatus2
    mov al, [ebp + hWhoseTurn]
    and al, al
    jz .faintUser                       ; player's turn → the player's own mon explodes
    mov esi, wEnemyMonHP                ; enemy's turn → the enemy's own mon explodes
    mov edx, wEnemyBattleStatus2
.faintUser:
    xor al, al
    mov [ebp + esi], al                 ; ld [hli], a — HP high byte = 0
    inc esi
    mov [ebp + esi], al                 ; ld [hli], a — HP low byte = 0
    inc esi
    inc esi                             ; inc hl — skip wBattleMonBoxLevel/PartyPos byte
    mov [ebp + esi], al                 ; ld [hl], a — wBattleMonStatus = 0
    mov al, [ebp + edx]                 ; ld a, [de]
    and al, ~(1 << SEEDED) & 0xFF       ; res SEEDED, a — clear Leech Seed status
    mov [ebp + edx], al                 ; ld [de], a
    ret
