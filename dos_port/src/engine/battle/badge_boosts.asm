; badge_boosts.asm — ApplyBadgeStatBoosts (battle engine plan, Stage 5).
;
; Faithful translation of engine/battle/core.asm:ApplyBadgeStatBoosts. Whenever
; the player's stats are (re)loaded in battle, badges whose bit position is even
; grant a 1.125x boost to the matching stat (Boulder→Atk, Thunder→Def, Soul→Spd,
; Volcano→Spc), capped at MAX_STAT_VALUE (999). No-op in link battles.
;
; Register map: a=AL, b=BH, c=BL (bc=BX), d=DH, e=DL (de=DX), hl=ESI.
;
; Build: nasm -f coff -I include/ -I . -o badge_boosts.o badge_boosts.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

wObtainedBadges equ 0xD355

section .text

global ApplyBadgeStatBoosts

ApplyBadgeStatBoosts:
    mov al, [ebp + wLinkState]
    cmp al, LINK_STATE_BATTLING
    je .ret                          ; ret z — no badge boosts in link battles
    mov al, [ebp + wObtainedBadges]
    mov bh, al                       ; b = badge bitfield
    mov esi, wBattleMonAttack
    mov bl, 4                        ; c = 4 stats (Atk, Def, Spd, Spc)
.loop:
    shr bh, 1                        ; srl b
    jnc .skipBoost
    call .applyBoostToStat           ; call c
.skipBoost:
    inc esi
    inc esi
    shr bh, 1                        ; srl b (skip odd-position badge bit)
    dec bl
    jnz .loop
.ret:
    ret

; multiply 16-bit big-endian stat at [esi] by 1.125 (stat + stat/8), cap at 999.
; esi unchanged on return.
.applyBoostToStat:
    mov al, [ebp + esi]              ; high byte ([hli])
    inc esi
    mov dh, al                       ; d = high
    mov dl, [ebp + esi]              ; e = low (esi at low byte)
    shr dx, 1                        ; de = stat >> 3 = stat / 8
    shr dx, 1
    shr dx, 1
    mov al, [ebp + esi]              ; low byte
    add al, dl
    mov [ebp + esi], al              ; [hld] -> store low; esi -> high
    dec esi
    mov al, [ebp + esi]              ; high byte
    adc al, dh
    mov [ebp + esi], al              ; [hli] -> store high; esi -> low
    inc esi
    mov al, [ebp + esi]              ; low ([hld])
    dec esi
    sub al, MAX_STAT_VALUE & 0xFF
    mov al, [ebp + esi]              ; high
    sbb al, MAX_STAT_VALUE >> 8      ; sbb (x86), not sbc (SM83)
    jc .boostRet                     ; ret c — stat below cap
    mov al, MAX_STAT_VALUE >> 8
    mov [ebp + esi], al              ; [hli] high = 999 high
    inc esi
    mov al, MAX_STAT_VALUE & 0xFF
    mov [ebp + esi], al              ; [hld] low = 999 low
    dec esi
.boostRet:
    ret
