; guard_drink_items.asm — pret mirror of data/items/guard_drink_items.asm.
;
; The three drinks the Saffron gate guards accept. pret pulls this in with
; `INCLUDE "data/items/guard_drink_items.asm"` from engine/events/saffron_guards.asm;
; the port keeps it as its own translation unit because lint_pret_labels mirrors pret
; data/ paths exactly — inlining it into saffron_guards.asm tripped `aux_misplaced`.
;
; Item ids stay SYMBOLIC (gb_constants.inc:375-377), as pret writes them.

bits 32

%include "gb_constants.inc"             ; FRESH_WATER / SODA_POP / LEMONADE

global GuardDrinksList

section .data

GuardDrinksList:
    db FRESH_WATER
    db SODA_POP
    db LEMONADE
    db 0 ; end
