; item.asm — home item wrappers (menus-port Session 4).
; Faithful port of pret home/item.asm — TossItem (the bag TOSS chain) and
; UseItem (the item-USE dispatcher's home entry, items-plan Stage 5).
;
;   TossItem:: / UseItem:: — bank-switch shells around TossItem_ / UseItem_
;   (engine/items/item_effects.asm, engine/items/item_use.asm). Flat memory
;   model: the hLoadedROMBank save/restore and rROMB writes collapse to a plain
;   call (TODO-HW: MBC banking).
;
;   IsKeyItem:: — the third and last pret home/item.asm label (pret :41). It
;   arrived here from the deleted src/home/item_predicates.asm bucket; pret
;   orders it after UseItem (:10) and TossItem (:21), so it is appended at the
;   foot of the file. (TossItem preceding UseItem here is a pre-existing
;   inversion this chunk did not rewrite.)
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
global IsKeyItem

extern TossItem_                     ; engine/items/item_effects.asm
extern UseItem_                      ; engine/items/item_use.asm
extern IsKeyItem_               ; src/engine/items/item_effects.asm — its pret mirror

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

; ---------------------------------------------------------------------------
; IsKeyItem — pret home/item.asm:IsKeyItem.
; Thin wrapper: preserve HL/DE/BC and run IsKeyItem_ (a farcall in pret; a plain
; call under the flat model). Result left in [wIsKeyItem].
; In:  [wCurItem] = item id.   Out: [wIsKeyItem] = 0/1.
; ---------------------------------------------------------------------------
IsKeyItem:
    push esi                    ; push hl
    push edx                    ; push de
    push ebx                    ; push bc
    call IsKeyItem_             ; farcall IsKeyItem_
    pop ebx                     ; pop bc
    pop edx                     ; pop de
    pop esi                     ; pop hl
    ret
