; subtract_paid_money.asm — mart/vendor money math (items layer, Stage 4).
;
; Source: engine/items/subtract_paid_money.asm + home/inventory.asm (pret). The
; non-UI cores of buy/sell: BCD compare + subtract the price from the player's
; money, and BCD add the sale total to it. The original also redraws the MONEY
; text box and plays SFX_PURCHASE — that's UI and is dropped here.
;
; Money and prices are 3-byte big-endian BCD. wPlayerMoney lives at
; W_PLAYER_MONEY; the transaction amount is staged at H_MONEY (hMoney). The BCD
; helpers (engine/math/bcd.asm) and StringCmp (home/compare.asm) walk from the
; pointer given: StringCmp compares MSB->LSB starting at EDX/ESI for BL bytes;
; AddBCD/SubBCD work LSB->MSB starting at EDX(dest)/ESI(operand) for CL bytes.
;
; NOTE: the prior swarm draft passed the operands in EDI/CL, but StringCmp reads
; EDX (de) and BL (c) — so the compare ran on stale registers. Fixed here, and
; the predef wrappers (which reload args from the predef regs) are replaced with
; direct AddBCD/SubBCD calls since we set the registers ourselves.
;
; Build: nasm -f coff -I include/ -I . -o subtract_paid_money.o subtract_paid_money.asm

bits 32

%include "gb_memmap.inc"

section .text

global SubtractAmountPaidFromMoney_
global AddAmountSoldToMoney_

extern StringCmp        ; EDX=de, ESI=hl, BL=len; CF set if [de] < [hl]
extern AddBCD           ; EDX=dest LSB, ESI=operand LSB, CL=len
extern SubBCD           ; EDX=dest LSB, ESI=operand LSB, CL=len

; ---------------------------------------------------------------------------
; SubtractAmountPaidFromMoney_ — pay [hMoney] out of the player's money.
; Out: CF = 0 on success (money debited), CF = 1 if the player can't afford it
;      (money left unchanged).
; ---------------------------------------------------------------------------
SubtractAmountPaidFromMoney_:
    mov edx, W_PLAYER_MONEY          ; de = money MSB
    mov esi, H_MONEY                 ; hl = price MSB
    mov bl, 3
    call StringCmp                   ; CF set if money < price
    jc .notEnoughMoney

    mov edx, W_PLAYER_MONEY + 2      ; de = money LSB (dest)
    mov esi, H_MONEY + 2             ; hl = price LSB (operand)
    mov cl, 3
    call SubBCD                      ; money -= price
    clc                              ; success
    ret

.notEnoughMoney:
    stc
    ret

; ---------------------------------------------------------------------------
; AddAmountSoldToMoney_ — credit [hMoney] (the sale total) to the player's money.
; BCD overflow above 999999 saturates inside AddBCD (fills 0x99), as on the GB.
; ---------------------------------------------------------------------------
AddAmountSoldToMoney_:
    mov edx, W_PLAYER_MONEY + 2      ; de = money LSB (dest)
    mov esi, H_MONEY + 2             ; hl = sale total LSB (operand)
    mov cl, 3
    call AddBCD                      ; money += sale total
    ret
