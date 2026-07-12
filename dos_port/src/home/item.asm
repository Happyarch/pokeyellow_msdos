; item.asm — home item wrappers (menus-port Session 4).
; Faithful port of pret home/item.asm — TossItem (the bag TOSS chain) and
; UseItem (the item-USE dispatcher's home entry, items-plan Stage 5).
;
;   TossItem:: / UseItem:: — bank-switch shells around TossItem_ / UseItem_
;   (engine/items/item_effects.asm, engine/items/item_use.asm). Flat memory
;   model: the hLoadedROMBank save/restore and rROMB writes collapse to a plain
;   call (TODO-HW: MBC banking).
;
; (pret home/item.asm's IsKeyItem wrapper is exported by
; src/home/item_predicates.asm.)
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
global UseItem

extern TossItem_                     ; engine/items/item_effects.asm
extern UseItem_                      ; engine/items/item_use.asm

section .text

; pret ref: home/item.asm:TossItem
TossItem:
    ; TODO-HW: ldh a,[hLoadedROMBank]/push af/ld a,BANK(TossItem_)/… — MBC
    ; banking collapses to a near call in the flat model.
    call TossItem_
    ret

; ---------------------------------------------------------------------------
; UseItem — pret ref: home/item.asm:UseItem (`farjp UseItem_`).
; In:  [wCurItem] = item id.
; Out: [wActionResultOrTookBattleTurn] — 0 unsuccessful, 1 successful, 2 not
;      usable right now with no extra menu shown (only some items use 2).
; ---------------------------------------------------------------------------
UseItem:
    jmp UseItem_                     ; farjp — no bank to switch in the flat model
