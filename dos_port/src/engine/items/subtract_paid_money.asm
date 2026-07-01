; subtract_paid_money.asm — faithful port of engine/items/subtract_paid_money.asm
; (pret). The whole pret file is a single routine, SubtractAmountPaidFromMoney_,
; which debits the transaction total (hMoney) from the player's money after a BCD
; affordability check, then redraws the MONEY text box.
;
; Faithful 1:1 translation. The GB `predef SubBCDPredef` is a bank-switch
; indirection around SubBCD that preserves de/hl/bc; in the port that collapses to
; a direct SubBCD call with the registers we set (matching how bcd.asm is used).
;
; (pret's AddAmountSoldToMoney_ lives in home/inventory.asm, NOT this file, so it is
; not ported here — port it with the rest of home/inventory.asm.)
;
; Build: nasm -f coff -I include/ -I . -o /dev/null src/engine/items/subtract_paid_money.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

section .text

global SubtractAmountPaidFromMoney_

extern StringCmp            ; EDX=de, ESI=hl, BL=len; flags = last MSB->LSB compare
extern SubBCD               ; EDX=dest LSB, ESI=operand LSB, CL=len; CF=1 on borrow
extern DisplayTextBoxID     ; home/text_script.asm (Wave 1/M1.3) — redraw money box

; wTextBoxID (gb_memmap.inc) and MONEY_BOX (gb_constants.inc) are now canonical.

; ---------------------------------------------------------------------------
; SubtractAmountPaidFromMoney_ — subtract the amount the player paid from money.
; OUTPUT: carry = 0 (success) or 1 (fail because there is not enough money)
; ---------------------------------------------------------------------------
SubtractAmountPaidFromMoney_:
    mov edx, W_PLAYER_MONEY          ; ld de, wPlayerMoney (MSB — total price compare)
    mov esi, H_MONEY                 ; ld hl, hMoney
    mov bl, 3                        ; ld c, 3 (length of money in bytes)
    call StringCmp
    jc .cannotAfford                 ; ret c

    mov edx, W_PLAYER_MONEY + 2      ; ld de, wPlayerMoney + 2 (LSB — subtract)
    mov esi, H_MONEY + 2             ; ld hl, hMoney + 2
    mov cl, 3                        ; ld c, 3
    call SubBCD                      ; predef SubBCDPredef — subtract price from money

    mov byte [ebp + wTextBoxID], MONEY_BOX  ; ld a, MONEY_BOX / ld [wTextBoxID], a
    call DisplayTextBoxID            ; redraw money text box
    and al, al                       ; and a — clear carry (success)
    ret

.cannotAfford:
    ret                              ; carry still set from StringCmp
