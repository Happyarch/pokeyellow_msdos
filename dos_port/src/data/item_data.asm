; item_data.asm — Pokémon item static data tables (items layer).
;
; Read-only item data so the engine routines (mart math, bag display, item use)
; can `extern` them. Per the linker rule in docs/assembly.md, embedded data lives
; in .data (not .rodata).
;
; MartInventories : tools/generators/gen_items.py (db count, item ids, $FF per mart);
;                   MartPointers indexes them in source order.
;
; ItemNames, ItemPrices, KeyItemFlags, TechnicalMachinePrices and
; TechnicalMachines each moved to their own mirrored carrier under
; src/data/items/ and src/data/moves/ on 2026-08-16
; (docs/current_plan_data_path_mirror.md). What is left has no single pret data/
; file of its own: marts, VitaminStats and the two UsableItems_* routing arrays
; (the last three declare their own globals inside assets/items.inc).
;
; Build: nasm -f coff -I include/ -I . -o item_data.o item_data.asm

bits 32

global MartInventories
global MartPointers

section .data
align 4

%include "assets/items.inc"
