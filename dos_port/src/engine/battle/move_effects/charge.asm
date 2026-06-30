; 994__ChargeEffect.asm — ChargeEffect (move-effect translation swarm worker output).
;
; Faithful translation of engine/battle/effects.asm:ChargeEffect (pret/pokeyellow).
; The two-turn "charge" handler for Razor Wind / Solar Beam / Skull Bash / Sky Attack
; / Fly / Dig: sets CHARGING_UP on the user's battle-status1 byte, sets INVULNERABLE
; for Fly (FLY_EFFECT) and Dig (move num DIG, checked directly — Dig has no separate
; "DIG_EFFECT"), plays the per-move "charge" screen animation (substitute hide/
; reshow bracketed around it), stashes the move number in wChargeMoveNum, and prints
; the per-move "<MON> <verb>!" charge text.
;
; Fidelity boundary: docs/move_translation_divergence.md. Shared externs (§4) are
; called, not redefined; only §2 allowlist items (literal subanim/bank) diverge.
;
; --- the ChargeMoveEffectText table-lookup: how it's handled here ---
; pret's `ChargeMoveEffectText` is NOT a plain text stream: it's `text_far
; _ChargeMoveEffectText` (which is itself just `text "<USER>@"` + text_end — i.e.
; "print the user's mon name, then stop") immediately followed by a `text_asm` block
; (no terminating text_end of its own) that does a `cp <move>` cascade against
; wChargeMoveNum and returns HL = one of MadeWhirlwindText / TookInSunlightText /
; LoweredItsHeadText / SkyAttackGlowingText / FlewUpHighText / DugAHoleText (DIG is
; the unconditional fallthrough default — pret's last `cp DIG` has no `jr z`, by
; design, not a bug). TextCommand_FAR (home/text.asm) implements text_far as a true
; CALL (it pushes the return address and pops it back after the far block's
; text_end), so control returns to the text_asm opcode right after the far pointer,
; which the engine then invokes as an inline ASM callback whose returned HL is
; spliced in to continue the SAME message — net effect: one continuous textbox
; reading "<MON NAME>\n<verb text>!".
;
; This port's PrintBattleText takes one flat already-resolved stream and has no
; TX_ASM splice mechanic, so the dispatch is resolved here in real code (the cascade
; below, 1:1 against pret's cp/jr z order and DIG default) and the result is a single
; PrintText call against one of six LOCAL composite streams defined at the bottom of
; this file. Each composite stream is mechanically `TX_START($00) + <USER>($5A) +
; <the corresponding completion text's own body bytes, unchanged>` — i.e. exactly
; what a single fused stream would contain if pret hadn't split it via text_far for
; ROM-byte sharing. The six completion texts (MadeWhirlwindText etc.) already exist
; as separate generated Tier-1 labels in assets/battle_text.inc; their bytes are
; reproduced here only to graft on the "<USER>" prefix pret supplies via the far
; call, which our generator cannot represent (gen_battle_text.py explicitly refuses
; to generate text_asm bodies — "translate as code"). FLAGGED FOR MASTER: this
; mechanism gap (no general TX_ASM splice support in PrintBattleText) likely recurs
; for other text_asm-driven messages; a shared splice primitive may be worth adding
; to move_effect_helpers.asm instead of every handler hand-composing local streams.
;
; Register map: A=AL, B=BH, C=BL (BC=BX), D=DH, E=DL (DE=EDX), HL=ESI, EBP=GB base.
; GB memory at [EBP+addr]; battle_text streams are flat program addresses.
;
; Build: nasm -f coff -I include/ -I . -o /dev/null 994__ChargeEffect.asm

bits 32

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"

section .text

global ChargeEffect_

; --- shared scaffold externs (§4: call, never define) ---
extern Bankswitch                   ; move_effect_helpers.asm — §2 item 4: jmp esi (no banks)
extern PlayBattleAnimation          ; move_effect_helpers.asm — §2 item 1: no-op (ANIMATION=OFF)
extern HideSubstituteShowMonAnim    ; move_effect_helpers.asm — §3: no-op stand-in (no Substitute pic yet)
extern ReshowSubstituteAnim         ; move_effect_helpers.asm — §3: no-op stand-in
extern PrintText                    ; move_effect_helpers.asm — ESI = flat text stream

; --- missing-WRAM / missing-constant equs (flag for master) ---
; wChargeMoveNum (ram/wram.asm:1014) lives in the same NEXTU lane (offset 0 of the
; "This union spans 30 bytes" UNION at ram/wram.asm:772, the run of one-off scratch
; aliases starting at wSavedY::) as wPPRestoreItem/wWereAnyMonsAsleep, which are
; ALREADY in gb_memmap.inc at 0xCD3D ("(aliased)") — so this is the same byte, not a
; guess. FLAG FOR MASTER: add `wChargeMoveNum equ 0xCD3D` to gb_memmap.inc proper.

; SLIDE_DOWN_ANIM / RAZOR_WIND / SOLARBEAM / SKULL_BASH / SKY_ATTACK are not yet in
; gb_constants.inc. Values derived from constants/move_constants.asm's const_def
; cascades (animation IDs continue the move-id enum after STRUGGLE=$a5/NUM_ATTACKS;
; move IDs carry their hex value in a trailing pret comment). Cross-checked against
; gb_constants.inc's existing XSTATITEM_DUPLICATE_ANIM=0xAF and SHAKE_SCREEN_ANIM=0xC7
; (both land exactly where the const_def cascade predicts). FLAG FOR MASTER: add to
; gb_constants.inc.

; ===========================================================================
; ChargeEffect_ — pret engine/battle/effects.asm:ChargeEffect.
; ===========================================================================
ChargeEffect_:
    mov esi, wPlayerBattleStatus1       ; ld hl, wPlayerBattleStatus1
    mov edx, wPlayerMoveEffect          ; ld de, wPlayerMoveEffect
    mov al, [ebp + hWhoseTurn]          ; ldh a, [hWhoseTurn]
    and al, al
    mov bh, XSTATITEM_ANIM              ; ld b, XSTATITEM_ANIM
    jz .chargeEffect                    ; jr z, .chargeEffect
    mov esi, wEnemyBattleStatus1        ; ld hl, wEnemyBattleStatus1
    mov edx, wEnemyMoveEffect           ; ld de, wEnemyMoveEffect
    mov bh, XSTATITEM_DUPLICATE_ANIM    ; ld b, XSTATITEM_DUPLICATE_ANIM
.chargeEffect:
    or byte [ebp + esi], 1 << CHARGING_UP   ; set CHARGING_UP, [hl]
    mov al, [ebp + edx]                 ; ld a, [de]  (move effect)
    dec edx                             ; dec de -> de contains enemy/player MOVENUM
    cmp al, FLY_EFFECT
    jne .notFly
    or byte [ebp + esi], 1 << INVULNERABLE  ; mon is now invulnerable to typical attacks (fly/dig)
    mov bh, TELEPORT                    ; load Teleport's animation
.notFly:
    mov al, [ebp + edx]                 ; ld a, [de]  (move num)
    cmp al, DIG
    jne .notDigOrFly
    or byte [ebp + esi], 1 << INVULNERABLE  ; mon is now invulnerable to typical attacks (fly/dig)
    mov bh, SLIDE_DOWN_ANIM
.notDigOrFly:
    push edx                            ; push de
    push ebx                            ; push bc  (preserve bh = chosen anim id)
    inc esi                             ; inc hl -> battle status 2
    push esi                            ; push hl
    mov al, [ebp + esi]                 ; ld a, [hl]
    test al, 1 << HAS_SUBSTITUTE_UP     ; bit HAS_SUBSTITUTE_UP, a
    jz .skipHide                        ; (call nz, Bankswitch — only if substitute is up)
    mov esi, HideSubstituteShowMonAnim  ; ld hl, HideSubstituteShowMonAnim (BANK(...) dropped — §2 item 4)
    call Bankswitch
.skipHide:
    pop esi                             ; pop hl  (esi = battle status 2 ptr again)
    pop ebx                             ; pop bc
    xor al, al
    mov [ebp + wAnimationType], al      ; xor a / ld [wAnimationType], a
    mov al, bh                          ; ld a, b
    call PlayBattleAnimation
    mov al, [ebp + esi]                 ; ld a, [hl]  (same status2 ptr, re-read like pret)
    test al, 1 << HAS_SUBSTITUTE_UP     ; bit HAS_SUBSTITUTE_UP, a
    jz .skipReshow                      ; (call nz, Bankswitch — only if substitute is up)
    mov esi, ReshowSubstituteAnim       ; ld hl, ReshowSubstituteAnim
    call Bankswitch
.skipReshow:
    pop edx                             ; pop de  (movenum ptr)
    mov al, [ebp + edx]                 ; ld a, [de]
    mov [ebp + wChargeMoveNum], al     ; ld [wChargeMoveNum], a

    ; ld hl, ChargeMoveEffectText / jp PrintText — resolved here (see file header):
    ; faithful translation of the pret text_asm cascade, cp/jr-z order preserved,
    ; DIG falls through as the unconditional default exactly like pret (no `jr z`
    ; after the last `cp DIG`).
    cmp al, RAZOR_WIND
    je .razorWind
    cmp al, SOLARBEAM
    je .solarbeam
    cmp al, SKULL_BASH
    je .skullBash
    cmp al, SKY_ATTACK
    je .skyAttack
    cmp al, FLY
    je .fly
.dig:
    mov esi, .DugAHoleChargeText
    jmp PrintText
.razorWind:
    mov esi, .MadeWhirlwindChargeText
    jmp PrintText
.solarbeam:
    mov esi, .TookInSunlightChargeText
    jmp PrintText
.skullBash:
    mov esi, .LoweredItsHeadChargeText
    jmp PrintText
.skyAttack:
    mov esi, .SkyAttackGlowingChargeText
    jmp PrintText
.fly:
    mov esi, .FlewUpHighChargeText
    jmp PrintText

; ---------------------------------------------------------------------------
; Local composite charge-text streams — TX_START($00) + <USER>($5A) + the matching
; completion text's own body bytes (assets/battle_text.inc: MadeWhirlwindText,
; TookInSunlightText, LoweredItsHeadText, SkyAttackGlowingText, FlewUpHighText,
; DugAHoleText — bytes copied verbatim, only the leading TX_START swapped for
; TX_START+<USER>). See file header for why this composition happens in code
; instead of via pret's text_far+text_asm splice.
; ---------------------------------------------------------------------------
.MadeWhirlwindChargeText:
    db 0x00, 0x5A, 0x4F, 0xAC, 0xA0, 0xA3, 0xA4, 0x7F, 0xA0, 0x7F, 0xB6, 0xA7, 0xA8, 0xB1, 0xAB, 0xB6
    db 0xA8, 0xAD, 0xA3, 0xE7, 0x58
.TookInSunlightChargeText:
    db 0x00, 0x5A, 0x4F, 0xB3, 0xAE, 0xAE, 0xAA, 0x7F, 0xA8, 0xAD, 0x7F, 0xB2, 0xB4, 0xAD, 0xAB, 0xA8
    db 0xA6, 0xA7, 0xB3, 0xE7, 0x58
.LoweredItsHeadChargeText:
    db 0x00, 0x5A, 0x4F, 0xAB, 0xAE, 0xB6, 0xA4, 0xB1, 0xA4, 0xA3, 0x7F, 0xA8, 0xB3, 0xB2, 0x7F, 0xA7
    db 0xA4, 0xA0, 0xA3, 0xE7, 0x58
.SkyAttackGlowingChargeText:
    db 0x00, 0x5A, 0x4F, 0xA8, 0xB2, 0x7F, 0xA6, 0xAB, 0xAE, 0xB6, 0xA8, 0xAD, 0xA6, 0xE7, 0x58
.FlewUpHighChargeText:
    db 0x00, 0x5A, 0x4F, 0xA5, 0xAB, 0xA4, 0xB6, 0x7F, 0xB4, 0xAF, 0x7F, 0xA7, 0xA8, 0xA6, 0xA7, 0xE7
    db 0x58
.DugAHoleChargeText:
    db 0x00, 0x5A, 0x4F, 0xA3, 0xB4, 0xA6, 0x7F, 0xA0, 0x7F, 0xA7, 0xAE, 0xAB, 0xA4, 0xE7, 0x58
