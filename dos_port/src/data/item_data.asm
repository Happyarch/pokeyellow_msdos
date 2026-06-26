; item_data.asm — Pokémon item static data tables (items layer).
;
; Read-only item data so the engine routines (mart math, bag display, item use)
; can `extern` them. Per the linker rule in docs/assembly.md, embedded data lives
; in .data (not .rodata).
;
; ItemNames  : tools/gen_items.py ('@'-terminated, GB-charmap encoded).
; ItemPrices : tools/gen_items.py (3-byte BCD per item id).
;
; Build: nasm -f coff -I include/ -I . -o item_data.o item_data.asm

bits 32

global ItemNames
global ItemPrices
global KeyItemFlags

section .data
align 4

%include "assets/items.inc"
