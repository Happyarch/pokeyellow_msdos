; saffron_guards.asm — pret mirror of engine/events/saffron_guards.asm.
;
; RemoveGuardDrink: walks GuardDrinksList (a program-image table, not GB
; memory), looking for the first drink item the player is carrying; removes
; it via RemoveItemByID and returns. Pret pulls the list in with
; `INCLUDE "data/items/guard_drink_items.asm"` (data/items/guard_drink_items.asm);
; the port inlines the same three symbolic item ids here.

bits 32

%include "gb_memmap.inc"

global RemoveGuardDrink

extern GuardDrinksList             ; src/data/items/guard_drink_items.asm (pret data/ mirror)
extern IsItemInBag                 ; home/map_objects.asm — In: BH = item id, Out: ZF set if not in bag
extern RemoveItemByID              ; engine/menus/pc.asm — In: [hItemToRemoveID], no other args

section .text

; ---------------------------------------------------------------------------
; RemoveGuardDrink — pret ref: engine/events/saffron_guards.asm:RemoveGuardDrink
;
; pret:
;   RemoveGuardDrink::
;       ld hl, GuardDrinksList
;   .drinkLoop
;       ld a, [hli]
;       ldh [hItemToRemoveID], a
;       and a
;       ret z
;       push hl
;       ld b, a
;       call IsItemInBag
;       pop hl
;       jr z, .drinkLoop
;       farjp RemoveItemByID
;
; GuardDrinksList is defined in src/data/items/guard_drink_items.asm, living in
; the flat program image, not in emulated GB memory — so `ld hl, GuardDrinksList` /
; `ld a, [hli]` is a FLAT pointer walk: `mov esi, GuardDrinksList` then
; `mov al, [esi]` with NO `ebp` added. (Compare CeladonMartRoofDrinkList in
; src/scripts/celadon_mart_roof.asm, the established precedent for exactly
; this shape: `mov esi, CeladonMartRoofDrinkList` / `mov al, [esi]`.) Using
; `[ebp + esi]` here would assemble cleanly and silently read emulated GB
; memory at GuardDrinksList's link address instead of the table itself.
; ---------------------------------------------------------------------------
RemoveGuardDrink:
    mov esi, GuardDrinksList            ; ld hl, GuardDrinksList (flat program-image ptr)
.drinkLoop:
    mov al, [esi]                       ; ld a, [hl]   (flat read, no ebp)
    lea esi, [esi+1]                    ; ...hli — advance WITHOUT touching flags:
                                         ; `and a` right below is what must set ZF,
                                         ; so the pointer step cannot be `inc esi`.
    mov [ebp + hItemToRemoveID], al     ; ldh [hItemToRemoveID], a
    and al, al                          ; and a  — sets ZF on the list terminator (0)
    jz .done                            ; ret z
    push esi
    mov bh, al                          ; ld b, a — IsItemInBag reads the item id in BH
    call IsItemInBag                    ; Out: ZF set ⇒ not in bag
    pop esi
    jz .drinkLoop                       ; jr z, .drinkLoop
    jmp RemoveItemByID                  ; farjp RemoveItemByID — flat model: plain tail jmp
.done:
    ret
