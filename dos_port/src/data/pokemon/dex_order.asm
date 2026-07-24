; dex_order.asm — pret data/pokemon/dex_order.asm mirror.
;
; PokedexOrder: 190 bytes, internal (index) order -> national dex number
; (1-based; 0x00 for the MISSINGNO. slots). Walked forward by IndexToPokedex
; and scanned by PokedexToIndex (both engine/menus/pokedex.asm, as in pret).
; Tier-1 generated data: tools/generators/gen_base_stats.py emits
; assets/dex_order.inc from the pret source table — never hand-edit.
bits 32

global PokedexOrder

section .data
%include "assets/dex_order.inc"
