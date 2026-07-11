; 1177__HealEffect.asm — HealEffect_: Recover/Softboiled (heal half max HP) AND
; Rest (full heal + sleep 2 turns).
;
; Faithful translation of engine/battle/move_effects/heal.asm:HealEffect_ (pret/pokeyellow).
;
; RE-TRANSLATION. The prior draft (dos_port/src/engine/battle/move_effects/heal.asm) FAILED
; audit on two points; both are fixed here:
;
;   1. The REST-vs-halve decision. pret:
;        ld a, b        ; b = move num
;        cp REST
;        jr nz, .healHP
;        push hl
;        push de
;        push af        ; <-- saves BOTH A and F (the cp REST result) across the block
;        ... DelayFrames / status-byte write / PrintText (FellAsleep/StartedSleeping) ...
;        pop af         ; <-- restores the cp-REST flags (none of the intervening `ld`s
;        pop de             touch flags, so this is the EXACT Z from `cp REST`)
;        pop hl
;      .healHP
;        ld a, [hld] / ld [wHPBarMaxHP], a / ld c, a / ld a, [hl] / ld [wHPBarMaxHP+1], a
;        ld b, a
;        jr z, .gotHPAmountToHeal   ; <-- branches on the Z PERSISTED from `cp REST`, not
;                                       anything computed since
;        srl b / rr c               ; halve (Recover/Softboiled only)
;      .gotHPAmountToHeal
;      SM83 `push af`/`pop af` saves+restores A *and* F together; x86 `push eax`/`pop eax`
;      does NOT touch EFLAGS, so that idiom cannot be ported literally — and substituting an
;      unrelated freshly-loaded-byte test (what the prior draft did) breaks the decision
;      entirely. Fix: immediately after `cp REST`, latch the outcome into `isRestStash`, a
;      byte of plain x86 scratch (NOT GB WRAM — there is no GB address backing this; it is a
;      host-side stand-in for "the flag bit the SM83 stack happened to preserve"), then
;      re-test *that stash* (not stale EFLAGS, which the DelayFrames/PrintText calls below
;      are free to clobber) at the `.gotHPAmountToHeal` join point, exactly where pret
;      re-tests the persisted Z. Net behavior reproduced exactly: REST -> stash=1 -> skip
;      halving (full heal); Recover/Softboiled -> stash=0 -> halve max HP.
;
;   2. HP-bar redraw. pret's `.updateHPBar` block (hWhoseTurn check -> hlcoord 10,9 vs
;      hlcoord 2,2 -> ld [wHPBarType],a -> predef UpdateHPBar2) is a byte-for-byte inlined
;      copy of engine/battle/core.asm:UpdateCurMonHPBar's body (that routine is literally
;      `hlcoord 10,9 / ldh a,[hWhoseTurn] / and a / ld a,$1 / jr z, .playersTurn / hlcoord
;      2,2 / xor a / .playersTurn / push bc / ld [wHPBarType],a / predef UpdateHPBar2 / pop
;      bc / ret` — identical save for the bc save/restore). So this is not new logic to
;      hand-translate; it is the shared §4 helper UpdateCurMonHPBar, called directly. The
;      prior draft hand-computed stride-20 hlcoord tile addresses instead (wrong: this repo's
;      battle canvas is the 40x25 widescreen surface, not the GB's 20x18 — see
;      docs/move_translation_divergence.md and the battle-widescreen-canvas note); dropped
;      here in favor of `call UpdateCurMonHPBar`.
;
; KEPT from the prior draft (correct, unchanged): the Gen-1 "most significant bytes
; comparison is ignored" bug — preserved faithfully under BUG_FIX_LEVEL<2 as pret's
; carry-chained cmp/sbb, with a real independent-byte-compare fix at BUG_FIX_LEVEL>=2.
;
; Fidelity boundary: docs/move_translation_divergence.md. Template:
; dos_port/src/engine/battle/move_effects/poison.asm. Shared externs (§4) are called, not
; redefined; only §2 allowlist items (literal subanim, audio, banks) diverge.
;
; Register map: A=AL, B=BH (BC=BX), D=DH, E=DL (DE=EDX), HL=ESI, EBP=GB base.
; wBattleMonHP/wEnemyMonHP (pret DE) -> EDI; wBattleMonMaxHP/wEnemyMonMaxHP (pret HL) -> ESI.
; GB memory at [EBP+addr]; battle_text streams are flat program addresses.
;
; Build: nasm -f coff -I include/ -I . -o /dev/null scratch/1177__HealEffect.asm

bits 32

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"

; --- shared scaffold externs (§4: call, never define) ---
extern EffectCallBattleCore         ; move_effect_helpers.asm — flat tail-call (no banks, §2.4)
extern PrintText                    ; move_effect_helpers.asm — ESI = flat text stream
extern PrintButItFailedText_        ; move_effect_helpers.asm
extern DelayFrames                  ; frame.asm (already live) — BL = frame count
extern UpdateCurMonHPBar            ; move_effect_helpers.asm — faithful HP-bar redraw; see
                                     ; header note #2 (substitutes pret's inlined hlcoord +
                                     ; predef UpdateHPBar2, which IS this routine's body)
extern DrawHUDsAndHPBars            ; battle_menu.asm / battle_hud.asm — full HUD+bar redraw
; --- allowlist anim stub (§2 item 1: literal subanim, ANIMATION=OFF path) ---
extern PlayCurrentMoveAnimation
; --- battle_text.inc streams (Tier-1 generated; global in core.o) ---
extern FellAsleepBecameHealthyText
extern RegainedHealthText
; FLAG FOR MASTER: StartedSleepingEffect (pret data/text/text_5.asm:216,
; "_StartedSleepingEffect", wrapped by engine/battle/move_effects/heal.asm's local
; `StartedSleepingEffect: text_far _StartedSleepingEffect`) was checked against
; dos_port/assets/battle_text.inc and is NOT currently emitted there — only
; FellAsleepBecameHealthyText and RegainedHealthText (this routine's other two strings)
; are present. tools/gen_battle_text.py needs the missing label added (Tier-1, generator-
; owned — do not hand-add to the .inc) before this handler can link. Externed here on the
; assumption it lands under this same name.
extern StartedSleepingEffect

; --- local: REST move id ---
; Not yet in dos_port/include/gb_constants.inc (only SOFTBOILED equ 0x87 and friends are
; present there; REST is absent). Derivation: constants/move_constants.asm:164 `const REST`
; comment marks it "; 9c" i.e. 0x9c = 156 decimal in the move-id enum.
; Named REST_MOVE_ID, not REST: bare `REST` collides with NASM's reserved RESB/RESW/.../REST
; pseudo-instruction (reserve-tword) and fails to assemble as an equ label.
; FLAG FOR MASTER: add REST equ 156 to gb_constants.inc (that file has no such collision
; risk — equ symbols there aren't used as bare mnemonics) and drop this local equ.
REST_MOVE_ID equ 156                ; 0x9c — constants/move_constants.asm:164

section .text

global HealEffect_

; ===========================================================================
; HealEffect_ — pret engine/battle/move_effects/heal.asm:HealEffect_.
; Heals the active mon: REST clears status, sets 2 turns of sleep, and heals to
; full; RECOVER/SOFTBOILED (any other move reaching this handler) heal half max
; HP. No-ops ("But it failed!") if already at max HP (subject to the BUG below).
; ===========================================================================
HealEffect_:
    mov al, [ebp + hWhoseTurn]
    and al, al
    mov edi, wBattleMonHP               ; de
    mov esi, wBattleMonMaxHP            ; hl
    mov al, [ebp + wPlayerMoveNum]
    jz .healEffect
    mov edi, wEnemyMonHP
    mov esi, wEnemyMonMaxHP
    mov al, [ebp + wEnemyMoveNum]
.healEffect:
    mov bh, al                          ; ld b, a — move num (kept live until the cp REST)

; BUG(cosmetic): most significant bytes comparison is ignored — causes the move to
; report "already at max HP" (no-op) if max HP is 255/511 points higher than current
; HP. pret ref: engine/battle/move_effects/heal.asm:HealEffect_ ("most significant
; bytes comparison is ignored / causes the move to miss if max HP is 255 or 511
; points higher than the current HP"); also catalogued as "HP Recovery Failure
; (mod 255)" in docs/references/yellow_glitches.md#battle-system ("Recovery moves
; fail silently when HP deficit ≡ 255 (mod 256); treated as -1"). Preserved
; faithfully under BUG_FIX_LEVEL<2 (pret's carry-chained cmp/sbb, MSB result
; discarded exactly as the original); independent two-byte compare fix at
; BUG_FIX_LEVEL>=2.
%if BUG_FIX_LEVEL >= 2
    mov ah, [ebp + edi]
    cmp ah, [ebp + esi]
    jne .notMaxHp
    mov ah, [ebp + edi + 1]
    cmp ah, [ebp + esi + 1]
    je .failed
.notMaxHp:
    inc edi
    inc esi
%else
    mov al, [ebp + edi]                 ; ld a, [de]
    cmp al, [ebp + esi]                 ; cp [hl]  -- MSB-deciding result discarded (the bug)
    inc edi                             ; inc de
    inc esi                             ; inc hl
    mov al, [ebp + edi]                 ; ld a, [de]
    sbb al, [ebp + esi]                 ; sbc [hl]
    jz .failed                          ; jp z, .failed
%endif

    ; --- cp REST: latch the outcome now; see file header note #1 for why. ---
    mov al, bh                          ; ld a, b
    cmp al, REST_MOVE_ID                ; cp REST
    mov byte [isRestStash], 0           ; default: "halve" (Recover/Softboiled)
    jne .healHP                         ; jr nz, .healHP — stash stays 0
    mov byte [isRestStash], 1           ; REST — remember to skip the halving below

    push esi                            ; push hl  (preserve across DelayFrames/PrintText,
    push edi                            ; push de   which are free to clobber ESI/EDI)
    mov bl, 50                          ; ld c, 50
    call DelayFrames
    mov esi, wBattleMonStatus           ; ld hl, wBattleMonStatus
    mov al, [ebp + hWhoseTurn]
    and al, al
    jz .restEffect
    mov esi, wEnemyMonStatus
.restEffect:
    mov al, [ebp + esi]                 ; ld a, [hl]
    and al, al
    mov byte [ebp + esi], 2             ; ld [hl], 2 — clear status, 2 turns asleep
    mov esi, StartedSleepingEffect      ; ld hl, StartedSleepingEffect (if no prior status)
    jz .printRestText
    mov esi, FellAsleepBecameHealthyText ; (if mon had a status)
.printRestText:
    call PrintText
    pop edi                             ; pop de
    pop esi                             ; pop hl

.healHP:
    mov al, [ebp + esi]                 ; ld a, [hld]
    dec esi
    mov [ebp + wHPBarMaxHP], al
    mov bl, al                          ; ld c, a
    mov al, [ebp + esi]                 ; ld a, [hl]
    mov [ebp + wHPBarMaxHP + 1], al
    mov bh, al                          ; ld b, a — bh now repurposed (move num no longer needed)

    cmp byte [isRestStash], 1
    je .gotHPAmountToHeal               ; jr z, .gotHPAmountToHeal — REST -> full heal

; Recover and Softboiled only heal for half the mon's max HP
    shr bh, 1                           ; srl b
    rcr bl, 1                           ; rr c

.gotHPAmountToHeal:
    mov al, [ebp + edi]                 ; ld a, [de]
    mov [ebp + wHPBarOldHP], al
    add al, bl                          ; add c
    mov [ebp + edi], al
    mov [ebp + wHPBarNewHP], al
    dec edi                             ; dec de
    mov al, [ebp + edi]
    mov [ebp + wHPBarOldHP + 1], al
    adc al, bh                          ; adc b
    mov [ebp + edi], al
    mov [ebp + wHPBarNewHP + 1], al

    inc esi                             ; inc hl
    inc edi                             ; inc de
    mov al, [ebp + edi]                 ; ld a, [de]
    dec edi                             ; dec de
    sub al, [ebp + esi]                 ; sub [hl]
    dec esi                             ; dec hl
    mov al, [ebp + edi]                 ; ld a, [de]
    sbb al, [ebp + esi]                 ; sbc [hl]
    jc .playAnim                        ; jr c, .playAnim

; copy max HP to current HP if an overflow occurred
    mov al, [ebp + esi]                 ; ld a, [hli]
    inc esi
    mov [ebp + edi], al                 ; ld [de], a
    mov [ebp + wHPBarNewHP + 1], al
    inc edi                             ; inc de
    mov al, [ebp + esi]                 ; ld a, [hl]
    mov [ebp + edi], al
    mov [ebp + wHPBarNewHP], al

.playAnim:
    mov esi, PlayCurrentMoveAnimation
    call EffectCallBattleCore

    ; pret inlines UpdateCurMonHPBar's own body here (see file header note #2) — call
    ; the shared §4 helper directly rather than re-hand-computing its hlcoord/predef pair.
    call UpdateCurMonHPBar

    mov esi, DrawHUDsAndHPBars
    call EffectCallBattleCore
    mov esi, RegainedHealthText
    jmp PrintText

.failed:
    mov bl, 50                          ; ld c, 50
    call DelayFrames
    mov esi, PrintButItFailedText_
    jmp EffectCallBattleCore

; ---------------------------------------------------------------------------
; isRestStash — local x86 scratch latch for the cp-REST outcome (file header note #1).
; NOT a GB WRAM address: there is no [ebp+] bias here, by design — it stands in for the
; SM83 stack-preserved Z flag, not for anything the original hardware addressed.
; ---------------------------------------------------------------------------
section .bss
isRestStash: resb 1
