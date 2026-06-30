; 1190__RecoilEffect.asm — RecoilEffect_ (Take Down/Double-Edge/Submission/Struggle:
; the user takes recoil damage equal to a fraction of the damage it just dealt).
;
; Faithful translation of engine/battle/effects.asm:RecoilEffect /
; engine/battle/move_effects/recoil.asm:RecoilEffect_ (pret/pokeyellow).
;
; RE-TRANSLATION — prior draft (dos_port/src/engine/battle/move_effects/recoil.asm)
; failed audit:
;   1. hand-computed HP-bar tile coords via a nonexistent `wTileMap` symbol with a
;      20-wide stride (port tilemap is `W_TILEMAP`, 40 wide) — wrong address, wrong math.
;   2. externed `predef_UpdateHPBar2`, which is not linked anywhere (link-time undefined
;      reference).
; Fix: per docs/move_translation_divergence.md §4, the HP-bar redraw is the shared
; extern `UpdateCurMonHPBar` (move_effect_helpers.asm) — it reads hWhoseTurn itself,
; sets wHPBarType, and redraws the HUD/HP bars (tail-calls DrawHUDsAndHPBars). Pret's
; `hlcoord 10,9` / `hlcoord 2,2` + `ld [wHPBarType],a` + `predef UpdateHPBar2` sequence
; is dropped entirely in favor of one call (§2.4 bank/predef flattening — flat DPMI has
; no banks, so a `predef` call becomes a direct flat call).
;
; Fidelity boundary: docs/move_translation_divergence.md. Shared externs (§4) are
; called, not redefined; only §2 allowlist items (banks/predefs) diverge here — this
; handler has no subanimation or audio call of its own (pret's RecoilEffect doesn't
; play one either; the move's own PlayCurrentMoveAnimation already ran for the damage
; that produced wDamage, before JumpMoveEffect reached this handler).
;
; Register map: A=AL, B=BH, C=BL (BC=BX), D=DH (move num scratch), HL=ESI, EBP=GB base.
; GB memory at [EBP+addr]; battle_text streams are flat program addresses.
;
; Build: nasm -f coff -I include/ -I . -o /dev/null 1190__RecoilEffect.asm

bits 32

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"

section .text

global RecoilEffect_

; --- shared scaffold externs (§4: call, never define) ---
extern UpdateCurMonHPBar            ; move_effect_helpers.asm — reads hWhoseTurn, sets
                                     ; wHPBarType, redraws HUDs/HP bars (replaces pret's
                                     ; hlcoord + predef UpdateHPBar2 — see header note)
extern PrintText                    ; move_effect_helpers.asm — ESI = flat text stream
; --- battle_text.inc stream (generated, global in core.o) ---
extern HitWithRecoilText

; ===========================================================================
; RecoilEffect_ — subtract recoil damage from the ATTACKER's own HP.
; Recoil = wDamage >> 2 (Take Down / Double-Edge / Submission), or wDamage >> 1
; for Struggle (move id STRUGGLE), minimum 1. Clamps the attacker's HP to 0 if
; the recoil would exceed it (Gen-1 lets a mon faint to its own recoil). Redraws
; the attacker's HP bar (UpdateCurMonHPBar) and prints HitWithRecoilText.
; ===========================================================================
RecoilEffect_:
    ; hl = &(attacker's) MaxHP word; a = the move num that was just used.
    mov al, [ebp + hWhoseTurn]
    and al, al
    mov al, [ebp + wPlayerMoveNum]
    mov esi, wBattleMonMaxHP
    jz .recoilEffect                    ; jr z — player's turn: recoil hits the player's mon
    mov al, [ebp + wEnemyMoveNum]
    mov esi, wEnemyMonMaxHP             ; enemy's turn: recoil hits the enemy's mon
.recoilEffect:
    mov dh, al                          ; ld d, a — stash the move num

    ; bc = wDamage >> 1 (always), then >> 1 again unless the move was Struggle
    ; (Struggle recoils 1/2 the damage; the others recoil 1/4).
    mov al, [ebp + wDamage]
    mov bh, al                          ; ld b, a — damage high byte
    mov al, [ebp + wDamage + 1]
    mov bl, al                          ; ld c, a — damage low byte
    shr bh, 1                           ; srl b
    rcr bl, 1                           ; rr c   (16-bit shift right through carry)
    mov al, dh
    cmp al, STRUGGLE                    ; struggle deals 50% recoil damage
    jz .gotRecoilDamage
    shr bh, 1                           ; srl b  } the other recoil moves are 25%
    rcr bl, 1                           ; rr c   }
.gotRecoilDamage:
    mov al, bh
    or al, bl
    jnz .updateHP
    inc bl                              ; minimum recoil damage is 1

.updateHP:
; subtract HP from user due to the recoil damage
    mov al, [ebp + esi]                 ; ld a,[hli] — MaxHP high byte
    inc esi
    mov [ebp + wHPBarMaxHP + 1], al
    mov al, [ebp + esi]                 ; ld a,[hl]  — MaxHP low byte
    mov [ebp + wHPBarMaxHP], al

    push ebx
    mov ebx, wBattleMonHP - wBattleMonMaxHP   ; same displacement for either mon's
                                               ; HP/MaxHP pair (both structs match)
    add esi, ebx                        ; add hl, bc — hl now -> HP low byte (+1 from above)
    pop ebx

    mov al, [ebp + esi]                 ; ld a,[hl] — HP low byte
    mov [ebp + wHPBarOldHP], al
    sub al, bl                          ; sub c
    mov [ebp + esi], al                 ; ld [hld],a — store, then hl-- -> HP high byte
    dec esi
    mov [ebp + wHPBarNewHP], al

    mov al, [ebp + esi]                 ; ld a,[hl] — HP high byte
    mov [ebp + wHPBarOldHP + 1], al
    sbb al, bh                          ; sbc b — borrow from the low-byte subtraction
    mov [ebp + esi], al                 ; ld [hl],a
    mov [ebp + wHPBarNewHP + 1], al
    jnc .updateHPBar                    ; jr nc — no underflow, HP didn't go negative

; if recoil damage is higher than the Pokemon's HP, set its HP to 0
    xor al, al
    mov [ebp + esi], al                 ; ld [hli],a — HP high byte = 0
    inc esi
    mov [ebp + esi], al                 ; ld [hl],a  — HP low byte = 0
    mov esi, wHPBarNewHP
    mov [ebp + esi], al                 ; ld [hli],a
    inc esi
    mov [ebp + esi], al                 ; ld [hl],a

.updateHPBar:
    ; pret: hlcoord 10,9 / hlcoord 2,2 + ld [wHPBarType],a + predef UpdateHPBar2.
    ; Replaced wholesale by the shared UpdateCurMonHPBar extern (see header note) —
    ; it derives wHPBarType from hWhoseTurn itself and redraws the HUD/HP bars; no
    ; tilemap coordinates are computed here.
    call UpdateCurMonHPBar
    mov esi, HitWithRecoilText
    jmp PrintText
