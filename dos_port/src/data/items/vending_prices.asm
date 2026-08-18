; vending_prices.asm — pret mirror of data/items/vending_prices.asm.
;
; Table of drinks and their 3-byte BCD prices sold at Celadon Rooftop vending machine.

bits 32

%include "gb_constants.inc"
%include "data_macros.inc"

global VendingPrices

section .data

%macro vend_item 2
    db %1
    bcd3 %2
%endmacro

VendingPrices:
    ; item id, price
    vend_item FRESH_WATER, 200
    vend_item SODA_POP,    300
    vend_item LEMONADE,    350
