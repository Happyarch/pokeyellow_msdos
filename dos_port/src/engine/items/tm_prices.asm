; tm_prices.asm — faithful port of engine/items/tm_prices.asm (pret).
; GetMachinePrice: look up a TM's buy price (in thousands) from the packed-nybble
; TechnicalMachinePrices table and store it as BCD at hItemPrice.
;
; TechnicalMachinePrices is generated into assets/items.inc by tools/gen_items.py.
;
; Build: nasm -f coff -I include/ -I . -o /dev/null src/engine/items/tm_prices.asm

bits 32

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"     ; TM01 = 0xC9

section .text

global GetMachinePrice
extern TechnicalMachinePrices

; ---------------------------------------------------------------------------
; GetMachinePrice
; Input:  [wCurItem] = Item ID of a TM
; Output: TM price stored at hItemPrice (3-byte BCD, thousands in high nybble)
; ---------------------------------------------------------------------------
GetMachinePrice:
    mov al, [ebp + W_CUR_ITEM]
    sub al, TM01                     ; underflows (CF) for HM items (below TM items)
    jc .done                         ; ret c — HMs are priceless

    mov dh, al                       ; ld d, a
    shr al, 1                        ; srl a — two TMs share each price byte
    movzx ecx, al                    ; ld c, a / ld b, 0
    lea esi, [TechnicalMachinePrices]
    add esi, ecx                     ; add hl, bc
    mov al, [esi]                    ; ld a, [hl] — packed price byte

    shr dh, 1                        ; srl d — is TM id odd?
    jnc .highNybbleIsPrice
    ; swap a — bring low nybble up
    mov cl, al
    shl cl, 4
    shr al, 4
    or al, cl
.highNybbleIsPrice:
    and al, 0xF0
    mov [ebp + H_ITEM_PRICE + 1], al
    mov byte [ebp + H_ITEM_PRICE], 0
    mov byte [ebp + H_ITEM_PRICE + 2], 0
.done:
    ret
