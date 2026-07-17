; item_data.asm — Pokémon item static data tables (items layer).
;
; Read-only item data so the engine routines (mart math, bag display, item use)
; can `extern` them. Per the linker rule in docs/assembly.md, embedded data lives
; in .data (not .rodata).
;
; ItemNames       : tools/generators/gen_items.py ('@'-terminated, GB-charmap encoded).
; ItemPrices      : tools/generators/gen_items.py (3-byte BCD per item id).
; KeyItemFlags    : tools/generators/gen_items.py (1-bit-per-item untossable flags).
; MartInventories : tools/generators/gen_items.py (db count, item ids, $FF per mart);
;                   MartPointers indexes them in source order.
;
; Build: nasm -f coff -I include/ -I . -o item_data.o item_data.asm

bits 32

global ItemNames
global ItemPrices
global KeyItemFlags
global MartInventories
global MartPointers
global TechnicalMachinePrices
global TechnicalMachines

section .data
align 4

%include "assets/items.inc"
