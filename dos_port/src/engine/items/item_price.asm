; item_price.asm — GetItemPrice (items layer, Stage 4).
;
; Source: home/item_price.asm (pret). Looks up an item's price into hItemPrice
; (3 bytes, big-endian BCD). Regular items index the flat ItemPrices table;
; TMs/HMs (id >= HM01) defer to GetMachinePrice (HMs are priceless).
;
; The pret original banks ROM and special-cases wListMenuID == MOVESLISTMENU
; (the move-relearner price-by-move list) — both are bank/UI concerns dropped in
; the flat port. ItemPrices is a native .data table, so the lookup is a direct
; flat index (no [ebp+...] bias); the result still lands in emulated HRAM.
;
; In:  [wCurItem] = item id
; Out: hItemPrice (H_ITEM_PRICE..+2) = price, big-endian BCD.
;
; Build: nasm -f coff -I include/ -I . -o item_price.o item_price.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

section .text

global GetItemPrice

extern ItemPrices       ; flat 3-byte-BCD-per-item table (item_data.asm)
extern GetMachinePrice  ; TM/HM price (tm_prices.asm)

GetItemPrice:
    mov al, [ebp + W_CUR_ITEM]
    cmp al, HM01
    jnc .machine                     ; TMs/HMs handled separately

    movzx eax, al
    dec eax                          ; 0-based item index
    lea ecx, [eax + eax*2]           ; * 3 (bytes per entry)
    lea esi, [ItemPrices]
    add esi, ecx                     ; -> entry's MSB

    mov al, [esi]                    ; big-endian: MSB first
    mov [ebp + H_ITEM_PRICE], al
    mov al, [esi + 1]
    mov [ebp + H_ITEM_PRICE + 1], al
    mov al, [esi + 2]
    mov [ebp + H_ITEM_PRICE + 2], al
    ret

.machine:
    jmp GetMachinePrice
