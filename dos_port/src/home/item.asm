; item.asm — home item wrappers (menus-port Session 4).
; Faithful port of pret home/item.asm — Session-4 scope is TossItem (the bag
; TOSS chain); UseItem stays with current_plan_items.md (item USE dispatch).
;
;   TossItem:: — bank-switch shell around TossItem_ (engine/items/
;   item_effects.asm). Flat memory model: the hLoadedROMBank save/restore and
;   rROMB writes collapse to a plain call (TODO-HW: MBC banking).
;
; (pret home/item.asm's IsKeyItem wrapper is exported by
; src/home/item_predicates.asm; UseItem is deliberately absent — see the
; tagged stub in start_sub_menus.asm.)
;
; In:  ESI (hl) = inventory count addr (wNumBagItems / wNumBoxItems),
;      [wCurItem], [wWhichPokemon], [wItemQuantity].
; Out: CF clear if the item was tossed, CF set if not.
;
; Build (standalone check):
;   nasm -f coff -I include/ -I . -o /dev/null src/home/item.asm
; ---------------------------------------------------------------------------
bits 32

global TossItem

extern TossItem_                     ; engine/items/item_effects.asm

section .text

; pret ref: home/item.asm:TossItem
TossItem:
    ; TODO-HW: ldh a,[hLoadedROMBank]/push af/ld a,BANK(TossItem_)/… — MBC
    ; banking collapses to a near call in the flat model.
    call TossItem_
    ret
