; 1167__DrainHPEffect.asm — DrainHPEffect_ (move-effect translation swarm, re-translation).
;
; Faithful translation of engine/battle/move_effects/drain_hp.asm:DrainHPEffect_
; (pret/pokeyellow). Shared by Absorb / Mega Drain / Leech Life (DRAIN_HP_EFFECT)
; and Dream Eater (DREAM_EATER_EFFECT): halve wDamage, add it to the attacker's
; HP (capped at MaxHP), redraw both HP bars/HUDs, then print either
; "<MON> had its energy drained!" (SuckedHealthText) or, for Dream Eater,
; "<MON>'s dream was eaten!" (DreamWasEatenText). pret: DrainHPEffect (effects.asm)
; is `jpfar DrainHPEffect_`; the flat target IS the body (§2 item 4, bank
; flattening — there is only one DrainHPEffect_ label to translate).
;
; Fidelity boundary: docs/move_translation_divergence.md. Shared externs (§4) are
; called, not redefined; only §2 allowlist items (predef/bank flattening) diverge.
; Structure copied from move_effects/poison.asm (the swarm's reference template).
;
; RE-TRANSLATION NOTE (prior draft at
; dos_port/src/engine/battle/move_effects/drain_hp.asm FAILED audit — do not
; repeat its bugs):
;   1. Dream Eater check must use the symbolic constant DREAM_EATER_EFFECT ($08,
;      gb_constants.inc), not a hand-typed `cmp al, 0x4B` (0x4B is RAZOR_LEAF).
;   2. The HP-bar redraw must NOT hand-compute hlcoord-style tile coordinates
;      (the port's wTileMap is 40 tiles wide, not 20 — pret's `hlcoord 10, 9` /
;      `hlcoord 2, 2` literals don't carry over). Per §2 item 4 (predef/bank
;      flattening), pret's `ld a,$1 / hlcoord 10,9 / ... / ld [wHPBarType],a /
;      predef UpdateHPBar2 / predef DrawPlayerHUDAndHPBar / predef
;      DrawEnemyHUDAndHPBar` triplet is replaced by a single
;      `call UpdateCurMonHPBar`: the port's UpdateCurMonHPBar (move_effect_helpers.asm)
;      already reads hWhoseTurn itself, sets wHPBarType, and redraws BOTH HUDs +
;      both HP bars (it tail-calls DrawHUDsAndHPBars) — i.e. it is the faithful
;      stand-in for all three pret predefs at once, not just UpdateHPBar2. This
;      also avoids referencing DrawEnemyHUDAndHPBar, which does not exist as a
;      linked symbol anywhere in dos_port (the prior draft's extern of it would
;      have failed at link time).
;
; Register map: A=AL, B=BH, C=BL (BC=EBX here — full word offsets, not BX), D/E
; folded into EDX (DE=EDX), HL=ESI, EBP=GB base. GB memory at [EBP+addr];
; battle_text streams are flat program addresses.
;
; Build: nasm -f coff -I include/ -I . -o /dev/null 1167__DrainHPEffect.asm

bits 32

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"

section .text

global DrainHPEffect_

; --- shared scaffold externs (§4: call, never define) ---
extern UpdateCurMonHPBar            ; move_effect_helpers.asm — gradual HP-bar drain;
                                     ; substitutes for predef UpdateHPBar2 +
                                     ; DrawPlayerHUDAndHPBar + DrawEnemyHUDAndHPBar
                                     ; (see RE-TRANSLATION NOTE #2 above).
extern ReadPlayerMonCurHPAndStatus  ; core.asm — global, flat call (was `callfar`)
extern PrintText                    ; move_effect_helpers.asm — ESI = flat text stream
; --- battle_text.inc streams (global in core.o) ---
extern SuckedHealthText
extern DreamWasEatenText

; ===========================================================================
; DrainHPEffect_ — halve wDamage, heal the attacker by that amount (capped at
; MaxHP; if the halved damage is 0, heal 1 HP instead so the move always
; restores something), redraw both HP bars/HUDs, then print the drain text
; (Dream Eater gets its own line via DREAM_EATER_EFFECT).
; ===========================================================================
DrainHPEffect_:
    ; --- halve wDamage (16-bit, big-endian: wDamage = high byte, +1 = low byte) ---
    mov esi, wDamage
    mov al, [ebp + esi]
    shr al, 1                       ; high byte >>= 1, CF = old bit0 of high byte
    mov [ebp + esi], al
    inc esi                         ; esi -> wDamage+1 (low byte)
    mov al, [ebp + esi]
    rcr al, 1                       ; low byte = (CF<<7)|(low>>1), new CF = old bit0
    mov [ebp + esi], al
    dec esi                         ; esi -> wDamage (high byte) — pret: ld [hld], a
    or al, [ebp + esi]              ; al(low) | high byte — is the halved damage 0?
    jnz .getAttackerHP
    ; halved damage is 0 → bump to 1 so the attacker always gains >=1 HP
    inc esi                         ; esi -> wDamage+1 (low byte)
    inc byte [ebp + esi]

.getAttackerHP:
    mov esi, wBattleMonHP
    mov edx, wBattleMonMaxHP
    mov al, [ebp + hWhoseTurn]
    test al, al
    jz .addDamageToAttackerHP
    mov esi, wEnemyMonHP
    mov edx, wEnemyMonMaxHP

.addDamageToAttackerHP:
    ; pret: ld bc, wHPBarOldHP+1 — copy current HP / MaxHP into the wHPBarXxx
    ; scratch (note pret stores these LITTLE-endian: +0=low byte, +1=high byte,
    ; despite the source HP fields being big-endian — preserved verbatim).
    mov ebx, wHPBarOldHP + 1
    mov al, [ebp + esi]             ; HP high byte
    mov [ebp + ebx], al
    inc esi                         ; esi -> HP low byte address
    mov al, [ebp + esi]             ; HP low byte (esi unchanged after)
    dec ebx
    mov [ebp + ebx], al             ; wHPBarOldHP (low slot)

    mov al, [ebp + edx]             ; MaxHP high byte
    dec ebx
    mov [ebp + ebx], al             ; wHPBarMaxHP+1
    inc edx                         ; edx -> MaxHP low byte address
    mov al, [ebp + edx]             ; MaxHP low byte
    dec ebx
    mov [ebp + ebx], al             ; wHPBarMaxHP (low slot)
    ; esi = HP low byte address, edx = MaxHP low byte address

    ; --- add halved damage to attacker's HP; copy new HP to wHPBarNewHP ---
    mov al, [ebp + wDamage + 1]     ; damage low byte
    mov bh, [ebp + esi]             ; HP low byte
    add al, bh
    mov [ebp + esi], al             ; store new HP low byte
    dec esi                         ; esi -> HP high byte address (pret: ld [hld], a)
    mov [ebp + wHPBarNewHP], al     ; wHPBarNewHP (low slot)

    mov al, [ebp + wDamage]         ; damage high byte
    mov bh, [ebp + esi]             ; HP high byte
    adc al, bh
    mov [ebp + esi], al             ; store new HP high byte
    inc esi                         ; esi -> HP low byte address (pret: ld [hli], a)
    mov [ebp + wHPBarNewHP + 1], al ; wHPBarNewHP (high slot)
    jc .capToMaxHP                  ; HP overflowed past 65535 -> cap to MaxHP

    ; --- compare new HP against MaxHP (MaxHP - HP; borrow => HP > MaxHP) ---
    mov al, [ebp + esi]             ; HP low byte (pret: ld a, [hld])
    dec esi                         ; esi -> HP high byte
    mov bh, al
    mov al, [ebp + edx]             ; MaxHP low byte
    dec edx                         ; edx -> MaxHP high byte
    sub al, bh                      ; MaxHP_low - HP_low
    mov al, [ebp + esi]             ; HP high byte (pret: ld a, [hli])
    inc esi                         ; esi -> HP low byte
    mov bh, al
    mov al, [ebp + edx]             ; MaxHP high byte
    inc edx                         ; edx -> MaxHP low byte
    sbb al, bh                      ; MaxHP_high - HP_high - borrow
    jnc .next                       ; no borrow -> HP <= MaxHP, no clamp needed

.capToMaxHP:
    ; esi = HP low byte address, edx = MaxHP low byte address (both entry paths)
    mov al, [ebp + edx]             ; MaxHP low byte
    mov [ebp + esi], al             ; HP low byte = MaxHP low byte
    dec esi                         ; esi -> HP high byte (pret: ld [hld], a)
    mov [ebp + wHPBarNewHP], al
    dec edx                         ; edx -> MaxHP high byte
    mov al, [ebp + edx]             ; MaxHP high byte
    mov [ebp + esi], al             ; HP high byte = MaxHP high byte
    inc esi                         ; esi -> HP low byte (pret: ld [hli], a)
    mov [ebp + wHPBarNewHP + 1], al
    inc edx                         ; edx -> MaxHP low byte (cleanup; unused after)

.next:
    ; pret: ld a,$1/hlcoord 10,9 (player) or xor a/hlcoord 2,2 (enemy), then
    ; ld [wHPBarType],a / predef UpdateHPBar2 / predef DrawPlayerHUDAndHPBar /
    ; predef DrawEnemyHUDAndHPBar — flattened (§2 item 4) to a single
    ; UpdateCurMonHPBar call; see RE-TRANSLATION NOTE #2 at the top of this file.
    call UpdateCurMonHPBar
    call ReadPlayerMonCurHPAndStatus    ; pret: callfar ReadPlayerMonCurHPAndStatus

    ; --- select the drain text: Dream Eater gets its own line ---
    mov esi, SuckedHealthText
    mov al, [ebp + hWhoseTurn]
    test al, al
    mov al, [ebp + wPlayerMoveEffect]
    jz .next3
    mov al, [ebp + wEnemyMoveEffect]
.next3:
    cmp al, DREAM_EATER_EFFECT
    jnz .printText
    mov esi, DreamWasEatenText
.printText:
    jmp PrintText
