; 992__FlinchSideEffect.asm — FlinchSideEffect (move-effect translation swarm worker).
;
; Faithful translation of engine/battle/effects.asm:FlinchSideEffect (pret/pokeyellow).
; Side-effect handler for FLINCH_SIDE_EFFECT1 (10%) / FLINCH_SIDE_EFFECT2-or-other (30%).
; On a successful roll it sets the FLINCHED battle-status bit on the move's TARGET.
; Per pret it also clears the TARGET's Hyper Beam recharge flag via ClearHyperBeam —
; once unconditionally (gated only by link-battle state) before the flinch roll, and
; again after a successful flinch. Silent throughout: side effects never print
; "But it failed!" on miss (matches poison.asm's side-effect branches).
;
; Translated structure follows dos_port/src/engine/battle/move_effects/poison.asm
; (the swarm template).
;
; Fidelity boundary: docs/move_translation_divergence.md. Shared externs (§4) are
; called, not redefined; only §2 allowlist items (literal subanim, audio, banks)
; diverge here — and this handler hits none of them (no subanim/audio/bank in
; pret's FlinchSideEffect). ClearHyperBeam (engine/battle/effects.asm) is shared
; by FreezeBurnParalyzeEffect/TrappingEffect too, so it lives as a global in
; move_effect_helpers.asm and is called here as a §4 extern.
;
; Register map: A=AL, B=BH, C=BL (BC=BX), D=DH, E=DL (DE=EDX), HL=ESI, EBP=GB base.
; GB memory at [EBP+addr].
;
; Build: nasm -f coff -I include/ -I . -o /dev/null scratch/992__FlinchSideEffect.asm

bits 32

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"

section .text

global FlinchSideEffect_

; --- shared scaffold externs (§4: call, never define) ---
extern CheckTargetSubstitute        ; move_effect_helpers.asm — ZF=1 if no substitute
extern BattleRandom                 ; home/random.asm — al = random roll
extern ClearHyperBeam               ; move_effect_helpers.asm — clears target's recharge

; ===========================================================================
; FlinchSideEffect_ — pret engine/battle/effects.asm:FlinchSideEffect.
; Rolls FLINCH_SIDE_EFFECT1 (10%) or otherwise (30%) and, on success, sets
; FLINCHED on the move's target. A substitute on the target blocks the effect
; entirely (silent — `ret nz`, no text, matching pret).
; ===========================================================================
FlinchSideEffect_:
    call CheckTargetSubstitute
    jnz .ret                            ; ret nz — substitute up, stay silent

    mov esi, wEnemyBattleStatus1        ; hl = target's battle status1
    mov edx, wPlayerMoveEffect          ; de = attacker's move effect
    mov al, [ebp + hWhoseTurn]
    and al, al
    jz .flinchSideEffect                ; player's turn → target = enemy (defaults above)
    mov esi, wPlayerBattleStatus1       ; enemy's turn → target = player
    mov edx, wEnemyMoveEffect
.flinchSideEffect:
    mov al, [ebp + wLinkState]
    cmp al, LINK_STATE_BATTLING
    jne .skipClear1
    call ClearHyperBeam
.skipClear1:
    mov al, [ebp + edx]                 ; ld a,[de] — move effect
    cmp al, FLINCH_SIDE_EFFECT1
    mov bh, (10 * 0xFF / 100) + 1       ; chance of flinch (FLINCH_SIDE_EFFECT1)
    je .gotEffectChance
    mov bh, (30 * 0xFF / 100) + 1       ; chance of flinch otherwise (FLINCH_SIDE_EFFECT2)
.gotEffectChance:
    call BattleRandom
    cmp al, bh                          ; was the flinch successful?
    jae .ret                            ; ret nc — roll failed, stay silent

    or byte [ebp + esi], 1 << FLINCHED  ; set mon's status to flinching
    call ClearHyperBeam
.ret:
    ret
