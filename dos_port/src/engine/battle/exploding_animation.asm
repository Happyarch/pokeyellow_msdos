; exploding_animation.asm — HandleExplodingAnimation (move-swarm worker output).
;
; Faithful translation of engine/battle/core.asm:HandleExplodingAnimation (pret/pokeyellow,
; core.asm:6787). Decides whether Self-Destruct/Explosion should play the
; screen-shake animation: no-op unless the move is SELFDESTRUCT/EXPLOSION, the
; target isn't invulnerable (charging Fly/Dig), the target isn't a Ghost-type
; (immune — takes no damage, no shake), and the move actually hit. On success it
; sets wAnimationType = ANIMATIONTYPE_SHAKE_SCREEN_HORIZONTALLY_LIGHT (5, which
; pret ASSERTs equals MEGA_PUNCH's anim id) and falls through into
; PlayMoveAnimation with that same value as the animation id — ported here as an
; explicit tail jmp since PlayMoveAnimation is a separate routine in this port.
;
; Template: dos_port/src/engine/battle/move_effects/poison.asm (swarm reference
; handler). Fidelity boundary: docs/plans/move_translation_divergence.md — the
; PlayMoveAnimation tail call lands in the allowlisted ANIMATION=OFF realization
; (dos_port/src/engine/battle/animations.asm), not a full subanimation engine.
;
; Register map: A=AL, F.Z=ZF, DE=EDX, HL=ESI, EBP=GB base. GB memory at [EBP+addr].
;
; Build: nasm -f coff -I include/ -I . -o exploding_animation.o exploding_animation.asm

bits 32

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"

section .text

global HandleExplodingAnimation

; --- shared scaffold extern (§4-style: call, never define) ---
extern PlayMoveAnimation            ; animations.asm — AL = animation id (ANIMATION=OFF path)

; Numeric ids not present as named constants in gb_constants.inc — literal + comment,
; per the swarm's numeric-id convention (matches poison.asm's TOXIC/POISON_EFFECT style).
%define SELFDESTRUCT_MOVE 0x4E      ; SELFDESTRUCT move id
%define EXPLOSION_MOVE     0x63     ; EXPLOSION move id
%define MEGA_PUNCH_ANIM    0x05     ; MEGA_PUNCH animation id — pret ASSERTs this ==
                                     ; ANIMATIONTYPE_SHAKE_SCREEN_HORIZONTALLY_LIGHT (5)

; ===========================================================================
; HandleExplodingAnimation — pret core.asm:6787. Called after a Self-Destruct/
; Explosion hit resolves; decides whether to shake the screen. All branches that
; don't reach the "isExplodingMove" success path return without touching
; wAnimationType (faithful to pret's ret nz/ret z guards — no animation plays).
;
; In: EBP = GB base, [ebp+hWhoseTurn] = whose turn (0 = player, 1 = enemy).
; Out (success path only): [ebp+wAnimationType] = 5, tail-jumps into
;   PlayMoveAnimation with AL = 5 (MEGA_PUNCH id == ANIMATIONTYPE_SHAKE_SCREEN_
;   HORIZONTALLY_LIGHT); PlayMoveAnimation's ret returns to our caller.
; Out (no-op paths): ret, registers as left by the guard that fired.
; ===========================================================================
HandleExplodingAnimation:
    mov al, [ebp + hWhoseTurn]
    and al, al
    mov esi, wEnemyMonType1         ; hl = target type1 — player's turn → target = enemy
    ; NOTE: pret reads wEnemyBattleStatus1 in BOTH branches (ld de, wEnemyBattleStatus1
    ; appears on both the z and fallthrough paths of the original code) — translated
    ; verbatim, not "fixed" to wPlayerBattleStatus1 for the enemy's-turn case.
    mov edx, wEnemyBattleStatus1    ; de = wEnemyBattleStatus1 (both branches, faithful)
    mov al, [ebp + wPlayerMoveNum]
    jz .player
    mov esi, wBattleMonType1        ; hl = target type1 — enemy's turn → target = player
    mov edx, wEnemyBattleStatus1    ; de = wEnemyBattleStatus1 (verbatim pret quirk, see above)
    mov al, [ebp + wEnemyMoveNum]
.player:
    cmp al, SELFDESTRUCT_MOVE
    je .isExplodingMove
    cmp al, EXPLOSION_MOVE
    jne .ret                        ; ret nz — not an exploding move, no animation
.isExplodingMove:
    mov al, [ebp + edx]
    test al, 1 << INVULNERABLE      ; bit 6 — fly/dig target is invulnerable
    jnz .ret                        ; ret nz — invulnerable target, no animation
    mov al, [ebp + esi]             ; ld a,[hli] — target type1
    inc esi
    cmp al, GHOST
    je .ret                         ; ret z — Ghost-type immune, no animation
    mov al, [ebp + esi]             ; ld a,[hl] — target type2 (immediately follows type1)
    cmp al, GHOST
    je .ret                         ; ret z — Ghost-type immune, no animation
    mov al, [ebp + wMoveMissed]
    and al, al
    jnz .ret                        ; ret nz — move missed, no animation
    mov byte [ebp + wAnimationType], MEGA_PUNCH_ANIM   ; == ANIMATIONTYPE_SHAKE_SCREEN_HORIZONTALLY_LIGHT
    ; falls through (pret) into PlayMoveAnimation with a == 5; ported as an
    ; explicit tail jmp — PlayMoveAnimation's ret returns to our caller.
    mov al, MEGA_PUNCH_ANIM
    jmp PlayMoveAnimation
.ret:
    ret
