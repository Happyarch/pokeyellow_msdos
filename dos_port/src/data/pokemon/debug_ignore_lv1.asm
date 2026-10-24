; dos_port/src/data/pokemon/debug_ignore_lv1.asm
; ============================================================
; Mirror of pret data/pokemon/debug_ignore_lv1.asm — the carrier for IgnoreLevel1LearnsetMons.
;
; pret's own comment:
; ; This list is used by unreferenced debug code which '×'es out moves that are
; ; not learnable by a particular Pokémon species.
; ; Species in this list do not consider their base data's level 1 learnsets as
; ; "learnable" for marking purposes.
; ; It's unclear why these specific Pokémon were listed.
;
; The bytes are Tier-1 data (tools/generators/gen_unknown_list.py transcribes the
; species list out of pret's file and resolves the names through
; assets/script_constants.inc), and this file is the carrier the aux placement
; rule pins to pret's path — a generated .inc is exempt, its .asm is not.
;
; The included .inc declares `global IgnoreLevel1LearnsetMons` and `global Pointer_3b0ee`.
;
; Build: nasm -f coff -I include/ -I . -o debug_ignore_lv1.o debug_ignore_lv1.asm

bits 32

section .data
align 4

%include "assets/debug_ignore_lv1.inc"
