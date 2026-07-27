; money.asm — mirror of pret home/money.asm.
;
;   HasEnoughMoney      — BCD compare wPlayerMoney (3 bytes) vs hMoney.
;   HasEnoughCoins      — BCD compare wPlayerCoins (2 bytes) vs hCoins.
;
; Those are both of that pret file's labels, so this mirror is complete. It also
; used to carry AddAmountSoldToMoney, which is a pret home/inventory.asm label
; and now lives in that mirror, src/home/inventory.asm.
;
; Money/coins are stored big-endian BCD; StringCmp walks MSB->LSB and leaves the
; carry contract of the last differing byte: carry set  => player has LESS than
; the price (cannot afford); carry clear => player has AT LEAST the price. This
; is exactly the contract SubtractAmountPaidFromMoney_ consumes.
;
; Register map (SM83 -> x86): a=AL, c=BL/CL, hl=ESI, de=EDX. GB memory is
; [ebp+SYM] from gb_memmap.inc.
;
; LINK STATUS: LINK-able. Its one extern resolves today:
;   StringCmp (home/compare.asm).
;
; Build (check): nasm -f coff -I include/ -I . -o /dev/null src/home/money.asm

bits 32

%include "gb_memmap.inc"

; wPlayerCoins / hCoins live canonically in gb_memmap.inc (Wave 5 integration).
; gb_constants.inc travelled to src/home/inventory.asm with AddAmountSoldToMoney:
; MONEY_BOX and wTextBoxID were its only readers here.

section .text

global HasEnoughMoney
global HasEnoughCoins

extern StringCmp                     ; EDX=de MSB, ESI=hl MSB, BL=len; CF from last cmp

; ---------------------------------------------------------------------------
; HasEnoughMoney — check the player has at least the 3-byte BCD value at hMoney.
; OUTPUT: carry set => not enough money. pret home/money.asm:HasEnoughMoney.
; ---------------------------------------------------------------------------
HasEnoughMoney:
    mov edx, W_PLAYER_MONEY          ; ld de, wPlayerMoney (MSB)
    mov esi, H_MONEY                 ; ld hl, hMoney (MSB)
    mov bl, 3                        ; ld c, 3
    jmp StringCmp                    ; jp StringCmp (tail)

; ---------------------------------------------------------------------------
; HasEnoughCoins — check the player has at least the 2-byte BCD value at hCoins.
; OUTPUT: carry set => not enough coins. pret home/money.asm:HasEnoughCoins.
; ---------------------------------------------------------------------------
HasEnoughCoins:
    mov edx, wPlayerCoins            ; ld de, wPlayerCoins (MSB)
    mov esi, hCoins                  ; ld hl, hCoins (MSB)
    mov bl, 2                        ; ld c, 2
    jmp StringCmp                    ; jp StringCmp (tail)
