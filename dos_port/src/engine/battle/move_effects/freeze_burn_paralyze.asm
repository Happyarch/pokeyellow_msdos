; 962__FreezeBurnParalyzeEffect.asm — FreezeBurnParalyzeEffect (move-effect
; translation swarm worker ticket). Handles the BURN_SIDE_EFFECT1/2,
; FREEZE_SIDE_EFFECT1/2, PARALYZE_SIDE_EFFECT1/2 chance-on-hit status (e.g. Body
; Slam's paralysis chance, Ice Beam's freeze chance, Thunderbolt's paralysis
; chance) — NOT the dedicated accuracy-tested status moves (those are
; BurnEffect/FreezeEffect/ParalyzeEffect, separate pret labels/tickets).
;
; Faithful translation of engine/battle/effects.asm:FreezeBurnParalyzeEffect,
; copying the structure of dos_port/src/engine/battle/move_effects/poison.asm
; (the swarm template). pret's FreezeBurnParalyzeEffect tail-jumps into
; CheckDefrost (already-statused guard) and HalveAttackDueToBurn/
; QuarterSpeedDueToParalysis (already-live shared status-penalty routines) —
; CheckDefrost has no other call site in pret and isn't part of the §4 shared
; interface, so it is translated here too, kept as a file-local `.` label (never
; `global`), matching the ConfusionEffect ticket's precedent for effect-private
; fallthrough code. ClearHyperBeam (effects.asm) is shared by several effects, so
; it lives as a global in move_effect_helpers.asm and is called here as a §4 extern.
;
; Fidelity boundary: docs/move_translation_divergence.md. Shared externs (§4) are
; called, not redefined; only §2 allowlist items (literal subanim) diverge.
; Drives PrintText/PrintMayNotAttackText/CheckTargetSubstitute/BattleRandom/
; QuarterSpeedDueToParalysis/HalveAttackDueToBurn/AddNTimes (all faithful, §3).
;
; Register map: A=AL, B=BH, C=BL (BC=BX/EBX), D=DH, E=DL (DE=EDX), HL=ESI, EBP=GB
; base. GB memory at [EBP+addr]; battle_text streams are flat program addresses.
; Per the established swarm idiom (poison.asm, SleepEffect), pret BC/DE register
; pairs holding a GB *address* are carried in full 32-bit EBX/EDX so
; `[ebp + ebx]` / `[ebp + edx]` addressing works directly.
;
; Build: nasm -f coff -I include/ -I . -o /dev/null 962__FreezeBurnParalyzeEffect.asm

bits 32

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"

section .text

global FreezeBurnParalyzeEffect_

; --- shared scaffold externs (§4: call, never define) ---
extern CheckTargetSubstitute        ; move_effect_helpers.asm — ZF=1 if no substitute
extern BattleRandom                 ; home/random.asm
extern PrintText                    ; move_effect_helpers.asm — ESI = flat text stream
extern PrintMayNotAttackText        ; move_effect_helpers.asm
extern QuarterSpeedDueToParalysis   ; status_penalties.asm — quarters off-turn mon's Speed
extern HalveAttackDueToBurn         ; status_penalties.asm — halves off-turn mon's Attack
extern AddNTimes                    ; home/array.asm — ESI += EBX(stride) * AL(count)
; --- allowlist anim stubs (§2 item 1: literal subanim, ANIMATION=OFF path) ---
extern PlayBattleAnimation          ; move_effect_helpers.asm allowlist stub
extern PlayBattleAnimation2
extern ClearHyperBeam               ; move_effect_helpers.asm — shared (Flinch/Trapping too)
; --- battle_text.inc streams (global in core.o) ---
extern BurnedText
extern FrozenText
extern FireDefrostedText

; wUnknownSerialFlag_d499 ($D499) is provided by gb_memmap.inc (folded in by the
; integration master; shared with SleepEffect's reroll restriction).

; ===========================================================================
; FreezeBurnParalyzeEffect_ — chance-on-hit BURN/FREEZE/PARALYZE side effect.
; No accuracy test here (unlike the dedicated status moves) — purely a percent
; roll via BattleRandom once the type-immunity guard passes. Misses silently if
; the target has a substitute, is already statused (tail-jumps to CheckDefrost
; instead, which may thaw a frozen target against a Fire-type move), or shares
; a type with the move (e.g. an Electric move can't paralyze an Electric-type).
; ===========================================================================
FreezeBurnParalyzeEffect_:
    mov byte [ebp + wAnimationType], 0  ; xor a / ld [wAnimationType],a
    call CheckTargetSubstitute
    jnz .ret                            ; ret nz — substitute up, can't effect them
    mov al, [ebp + hWhoseTurn]
    and al, al
    jnz .opponentAttacker

; --- player is attacking; target = enemy mon ---
    mov al, [ebp + wEnemyMonStatus]
    and al, al
    jnz .checkDefrost                   ; jp nz, CheckDefrost — already statused
    mov al, [ebp + wPlayerMoveType]
    mov bh, al                          ; ld b, a
    mov al, [ebp + wEnemyMonType1]
    cmp al, bh                          ; do target type 1 and move type match?
    je .ret                             ; ret z — e.g. an Ice move can't freeze an Ice-type
    mov al, [ebp + wEnemyMonType2]
    cmp al, bh
    je .ret
    mov al, [ebp + wPlayerMoveEffect]
    cmp al, FREEZE_SIDE_EFFECT2         ; more Stadium stuff
    jne .altThreshold1
    mov al, [ebp + wUnknownSerialFlag_d499]
    test al, al
    mov al, FREEZE_SIDE_EFFECT1         ; mov doesn't touch flags — ZF from the test above survives
    mov bh, (30 * 0xFF / 100) + 1
    jz .regularEffectiveness1
    mov bh, (10 * 0xFF / 100) + 1
    jmp .regularEffectiveness1
.altThreshold1:
    cmp al, PARALYZE_SIDE_EFFECT1 + 1
    mov bh, (10 * 0xFF / 100) + 1       ; mov doesn't touch flags — CF from the cmp above survives
    jc .regularEffectiveness1
; extra effectiveness
    mov bh, (30 * 0xFF / 100) + 1
    ; pret ASSERTs (compile-time, gb_constants.inc): PARALYZE_SIDE_EFFECT2 -
    ; PARALYZE_SIDE_EFFECT1 == BURN_SIDE_EFFECT2 - BURN_SIDE_EFFECT1 == FREEZE_SIDE_EFFECT2
    ; - FREEZE_SIDE_EFFECT1 (all == 30, 0x1E) — verified against gb_constants.inc above.
    sub al, PARALYZE_SIDE_EFFECT2 - PARALYZE_SIDE_EFFECT1   ; treat extra-effective as regular from now on
.regularEffectiveness1:
    ; "push af / call BattleRandom / cp b / pop bc / ret nc / ld a,b" — BL (C) is
    ; dead in this routine, so it stands in as the AF-pair's stash slot instead of
    ; a literal stack push/pop; behaviorally identical (flags from `cmp` below
    ; survive the following `mov`, exactly as pret's flags survive `pop bc`).
    mov bl, al                          ; stash the effect-type value (push af)
    call BattleRandom                   ; al = random 8-bit value
    cmp al, bh                          ; was the roll under the threshold?
    mov al, bl                          ; ld a,b (restore effect-type value)
    jae .ret                            ; ret nc — random >= threshold, no status applied
    cmp al, BURN_SIDE_EFFECT1
    je .burn1
    cmp al, FREEZE_SIDE_EFFECT1
    je .freeze1
; paralyze1 (fallthrough — only PARALYZE_SIDE_EFFECT1 remains by elimination)
    mov byte [ebp + wEnemyMonStatus], 1 << PAR
    call QuarterSpeedDueToParalysis     ; quarter speed of affected mon
    mov al, ENEMY_HUD_SHAKE_ANIM
    call PlayBattleAnimation
    jmp PrintMayNotAttackText
.burn1:
    mov byte [ebp + wEnemyMonStatus], 1 << BRN
    call HalveAttackDueToBurn           ; halve attack of affected mon
    mov al, ENEMY_HUD_SHAKE_ANIM
    call PlayBattleAnimation
    mov esi, BurnedText
    jmp PrintText
.freeze1:
    call ClearHyperBeam                 ; resets hyper beam (recharge) condition from target
    mov byte [ebp + wEnemyMonStatus], 1 << FRZ
    mov al, ENEMY_HUD_SHAKE_ANIM
    call PlayBattleAnimation
    mov esi, FrozenText
    jmp PrintText

; --- opponent is attacking; target = player's mon ---
; mostly the same as above with addresses swapped for the opponent.
.opponentAttacker:
    mov al, [ebp + wBattleMonStatus]
    and al, al
    jnz .checkDefrost
    mov al, [ebp + wEnemyMoveType]
    mov bh, al
    mov al, [ebp + wBattleMonType1]
    cmp al, bh
    je .ret
    mov al, [ebp + wBattleMonType2]
    cmp al, bh
    je .ret
    mov al, [ebp + wEnemyMoveEffect]
    cmp al, FREEZE_SIDE_EFFECT2
    jne .altThreshold2
    mov al, [ebp + wUnknownSerialFlag_d499]
    test al, al
    mov al, FREEZE_SIDE_EFFECT1
    mov bh, (30 * 0xFF / 100) + 1
    jz .regularEffectiveness2
    mov bh, (10 * 0xFF / 100) + 1
    jmp .regularEffectiveness2
.altThreshold2:
    cmp al, PARALYZE_SIDE_EFFECT1 + 1
    mov bh, (10 * 0xFF / 100) + 1
    jc .regularEffectiveness2
; extra effectiveness
    mov bh, (30 * 0xFF / 100) + 1
    sub al, BURN_SIDE_EFFECT2 - BURN_SIDE_EFFECT1   ; same numeric stride (30); pret literally
                                                     ; uses the BURN pair here, ASSERTed equal above
.regularEffectiveness2:
    mov bl, al                          ; stash (see .regularEffectiveness1 note)
    call BattleRandom
    cmp al, bh
    mov al, bl
    jae .ret
    cmp al, BURN_SIDE_EFFECT1
    je .burn2
    cmp al, FREEZE_SIDE_EFFECT1
    je .freeze2
; paralyze2 (fallthrough)
    mov byte [ebp + wBattleMonStatus], 1 << PAR
    call QuarterSpeedDueToParalysis
    mov al, SHAKE_SCREEN_ANIM
    call PlayBattleAnimation2
    jmp PrintMayNotAttackText
.burn2:
    mov byte [ebp + wBattleMonStatus], 1 << BRN
    call HalveAttackDueToBurn
    mov al, SHAKE_SCREEN_ANIM
    call PlayBattleAnimation2
    mov esi, BurnedText
    jmp PrintText
.freeze2:
    ; BUG(cosmetic): hyper beam recharge is reset for the player's side (.freeze1
    ; above calls ClearHyperBeam) but NOT here — pret's own source comment flags
    ; the asymmetry verbatim ("hyper beam bits aren't reset for opponent's side").
    ; A player mon that needed to recharge from Hyper Beam and then gets frozen by
    ; an opponent's move keeps the stale NEEDS_TO_RECHARGE flag; the symmetric
    ; case (opponent mon frozen by the player) correctly clears it.
    ; pret ref: engine/battle/effects.asm:FreezeBurnParalyzeEffect (.freeze2).
%if BUG_FIX_LEVEL >= 2
    call ClearHyperBeam                 ; fixed: symmetric reset on both sides
%else
    ; original (buggy): no ClearHyperBeam call on this path
%endif
    mov byte [ebp + wBattleMonStatus], 1 << FRZ
    mov al, SHAKE_SCREEN_ANIM
    call PlayBattleAnimation2
    mov esi, FrozenText
    jmp PrintText
.ret:
    ret

; ---------------------------------------------------------------------------
; .checkDefrost — pret effects.asm:CheckDefrost. Entry: AL = the target's
; current status byte (already loaded by the caller above). Any Fire-type move
; with a chance to inflict burn (i.e. every move that reaches this effect
; except Fire Spin, which has no burn chance) thaws a frozen target — even on
; the turn it's about to (re)inflict FRZ below, this label is only reached when
; the target ALREADY has a status, so a Fire move here only ever thaws, never
; re-freezes in the same call. Reached only from this effect (no other pret
; call site) — kept file-local (not `global`), §3 fallthrough control flow.
; ---------------------------------------------------------------------------
.checkDefrost:
    test al, 1 << FRZ                   ; are they frozen?
    jz .ret                             ; ret z — some other status, nothing to thaw
    mov al, [ebp + hWhoseTurn]
    and al, al
    jnz .checkDefrostOpponent
    ; player [attacker]
    mov al, [ebp + wPlayerMoveType]
    sub al, FIRE
    jnz .ret                            ; ret nz — move used isn't Fire-type, no thaw
    mov [ebp + wEnemyMonStatus], al     ; al == 0 here — "defrost" the frozen target
    mov esi, wEnemyMon1Status
    mov al, [ebp + wEnemyMonPartyPos]
    mov ebx, PARTYMON_STRUCT_LENGTH
    call AddNTimes
    mov byte [ebp + esi], 0             ; clear status in the roster copy too
    mov esi, FireDefrostedText
    jmp .checkDefrostCommon
.checkDefrostOpponent:
    mov al, [ebp + wEnemyMoveType]      ; same as above with addresses swapped
    sub al, FIRE
    jnz .ret
    mov [ebp + wBattleMonStatus], al
    mov esi, wPartyMon1Status
    mov al, [ebp + wPlayerMonNumber]
    mov ebx, PARTYMON_STRUCT_LENGTH
    call AddNTimes
    mov byte [ebp + esi], 0
    mov esi, FireDefrostedText
.checkDefrostCommon:
    jmp PrintText
