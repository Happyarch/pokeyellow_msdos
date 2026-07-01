; money.asm — faithful port of home/money.asm + the AddAmountSoldToMoney home
; helper (pret home/inventory.asm).
;
;   HasEnoughMoney      — BCD compare wPlayerMoney (3 bytes) vs hMoney.
;   HasEnoughCoins      — BCD compare wPlayerCoins (2 bytes) vs hCoins.
;   AddAmountSoldToMoney — BCD add the sale total (hMoney) into wPlayerMoney and
;                          redraw the MONEY text box.
;
; Money/coins are stored big-endian BCD; StringCmp walks MSB->LSB and leaves the
; carry contract of the last differing byte: carry set  => player has LESS than
; the price (cannot afford); carry clear => player has AT LEAST the price. This
; is exactly the contract SubtractAmountPaidFromMoney_ consumes.
;
; Register map (SM83 -> x86): a=AL, c=BL/CL, hl=ESI, de=EDX. GB memory is
; [ebp+SYM] from gb_memmap.inc.
;
; LINK STATUS: LINK-able. All externs resolve today:
;   StringCmp (home/compare.asm), AddBCD (engine/math/bcd.asm),
;   DisplayTextBoxID (home/text_script.asm — Wave 1/M1.3).
;
; MISSING MEMMAP SYMBOLS (see placeholders below): wPlayerCoins (0xD5A4) and
; hCoins (0xFFA0) are NOT yet in gb_memmap.inc. They are provided here as guarded
; %define placeholders so this file assembles standalone; root should add the two
; equ lines to gb_memmap.inc and drop these placeholders.
;
; Build (check): nasm -f coff -I include/ -I . -o /dev/null src/home/money.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

; wPlayerCoins / hCoins (gb_memmap.inc) and MONEY_BOX (gb_constants.inc) now live
; canonically (Wave 5 integration).

section .text

global HasEnoughMoney
global HasEnoughCoins
global AddAmountSoldToMoney

extern StringCmp                     ; EDX=de MSB, ESI=hl MSB, BL=len; CF from last cmp
extern AddBCD                        ; EDX=de LSB (dest), ESI=hl LSB (src), CL=len; BCD add
extern DisplayTextBoxID              ; redraw the text box selected by [wTextBoxID]

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

; ---------------------------------------------------------------------------
; AddAmountSoldToMoney — add the sale total (hMoney) to the player's money, then
; redraw the MONEY text box. pret home/inventory.asm:AddAmountSoldToMoney.
;
; NOTE: pret's `predef AddBCDPredef` is a bank-switch indirection around AddBCD
; that restores de/hl/c from the predef registers; in the flat port we set those
; registers directly and call AddBCD (matching subtract_paid_money.asm's SubBCD).
; The trailing SFX_PURCHASE / PlaySoundWaitForCurrent / WaitForSoundToFinish is
; an audio-HAL boundary (Phase 3) and is elided.
; ---------------------------------------------------------------------------
AddAmountSoldToMoney:
    mov edx, W_PLAYER_MONEY + 2      ; ld de, wPlayerMoney + 2 (LSB)
    mov esi, H_MONEY + 2             ; ld hl, hMoney + 2 (LSB, total price)
    mov cl, 3                        ; ld c, 3
    call AddBCD                      ; predef AddBCDPredef — add price to money

    mov byte [ebp + wTextBoxID], MONEY_BOX ; ld a, MONEY_BOX / ld [wTextBoxID], a
    call DisplayTextBoxID             ; redraw money text box

    ; TODO-HW: audio HAL (Phase 3) — original then plays SFX_PURCHASE via
    ; PlaySoundWaitForCurrent and tail-jumps WaitForSoundToFinish.
    ret
