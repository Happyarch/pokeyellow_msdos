; inventory.asm — AddItemToInventory_ / RemoveItemFromInventory_ (items layer).
;
; Source: engine/items/inventory.asm (pret/pokeyellow).
;
; Pure data manipulation of a bag/PC inventory (no UI). An inventory is laid out
; as: db count, then (item id, quantity) pairs, then a $FF terminator. Both take
; ESI (hl) = the inventory's count address (wNumBagItems or wNumBoxItems); all
; reads/writes are EBP-relative GB WRAM (no flat tables here).
;
; RemoveItemFromInventory_ resets a handful of menu-state bytes (scroll offset,
; cursor, …) exactly as the original — these are plain WRAM writes; the menu
; *rendering* that consumes them is UI and lives elsewhere, so nothing here
; touches the GUI.
;
; Register map: a=AL, b=BH, c=BL, d=DH, e=DL, hl=ESI, de=EDX. GB memory at
; [EBP+addr]. The SM83 stack tricks (push af / pop bc to stash wItemQuantity)
; are replaced by an explicit save/restore; behaviour is identical.
;
; NOTE: the prior swarm draft tested the wrong byte for an empty inventory — it
; advanced hl before the zero-count check (pret's `ld a,[hli]` reads the count
; THEN increments), so a fresh `00 FF` bag misbehaved. Fixed here.
;
; Build: nasm -f coff -I include/ -I . -o inventory.o inventory.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

global AddItemToInventory_
global RemoveItemFromInventory_

section .text

; In:  ESI (hl) = inventory count addr; [wCurItem]; [wItemQuantity].
; Out: CF set on success, clear if full. wItemQuantity restored to its input.
AddItemToInventory_:
    mov al, [ebp + wItemQuantity]
    push eax                         ; [orig_qty] (restore on exit)
    push esi                         ; [inv] count addr

    mov dh, PC_ITEM_CAPACITY
    cmp esi, wNumBagItems            ; is this the bag (vs PC box)?
    jne .checkFull
    mov dh, BAG_ITEM_CAPACITY
.checkFull:
    mov al, [ebp + esi]              ; count
    sub al, dh
    mov dh, al                       ; d = count - capacity (0 ⇒ full)
    mov al, [ebp + esi]              ; count again (ld a,[hli])
    inc esi                          ; hl -> first item id
    test al, al                      ; empty inventory?
    jz .addNewItem
.notAtEnd:
    mov al, [ebp + esi]              ; item id
    inc esi                          ; -> quantity
    mov bh, al
    mov al, [ebp + wCurItem]
    cmp al, bh                       ; already in the inventory?
    je .increaseQty
    inc esi                          ; skip quantity -> next id / terminator
.addAnotherStack:
    mov al, [ebp + esi]
    cmp al, 0xFF
    jne .notAtEnd
.addNewItem:
    pop esi                          ; [inv] count addr
    mov al, dh
    test al, al                      ; room for a new slot?
    jz .doneFail
    mov al, [ebp + esi]
    inc al
    mov [ebp + esi], al              ; count++
    add al, al
    dec al                           ; bc = 2*count - 1
    movzx ebx, al
    add esi, ebx                     ; hl = address to store the new item
    mov al, [ebp + wCurItem]
    mov [ebp + esi], al              ; item id
    inc esi
    mov al, [ebp + wItemQuantity]
    mov [ebp + esi], al              ; quantity
    inc esi
    mov byte [ebp + esi], 0xFF       ; terminator
    jmp .success
.increaseQty:
    mov al, [ebp + wItemQuantity]
    mov bh, al                       ; b = quantity to add
    mov al, [ebp + esi]              ; existing quantity (hl -> quantity)
    add al, bh
    cmp al, 100
    jc .storeNewQty                  ; < 100: just store it
    sub al, 99                       ; >= 100: max this slot at 99, overflow to new
    mov [ebp + wItemQuantity], al    ; leftover for the new slot
    mov al, dh
    test al, al                      ; room for a new slot?
    jz .increaseFailed
    mov al, 99
    mov [ebp + esi], al
    inc esi
    jmp .addAnotherStack
.increaseFailed:
    pop esi                          ; [inv]
    jmp .doneFail
.storeNewQty:
    mov [ebp + esi], al
    pop esi                          ; [inv]
.success:
    pop eax                          ; [orig_qty]
    mov [ebp + wItemQuantity], al    ; restore caller's quantity
    stc
    ret
.doneFail:
    pop eax                          ; [orig_qty]
    mov [ebp + wItemQuantity], al
    clc
    ret

; In:  ESI (hl) = inventory count addr; [wWhichPokemon] = slot index;
;      [wItemQuantity] = amount to remove. Removes the slot if it hits 0.
RemoveItemFromInventory_:
    push esi                         ; [inv]
    inc esi                          ; -> first item id
    mov al, [ebp + wWhichPokemon]
    add al, al                       ; 2 * index
    movzx ecx, al
    add esi, ecx
    inc esi                          ; hl -> quantity of the target slot
    mov al, [ebp + wItemQuantity]
    mov dl, al                       ; e = amount to remove
    mov al, [ebp + esi]              ; current quantity
    sub al, dl
    mov [ebp + esi], al              ; store new quantity
    dec esi                          ; hl -> item id (ld [hld])
    mov [ebp + wMaxItemQuantity], al
    test al, al
    jnz .skipMovingUp
    ; quantity hit 0 — drop this slot, shift the following (id,qty) pairs up
    mov edx, esi
    inc edx
    inc edx                          ; de = next slot
.loop:
    mov al, [ebp + edx]
    inc edx
    mov [ebp + esi], al
    inc esi
    cmp al, 0xFF
    jne .loop
    xor al, al
    mov [ebp + wListScrollOffset], al
    mov [ebp + wCurrentMenuItem], al
    mov [ebp + wBagSavedMenuItem], al
    mov [ebp + wSavedListScrollOffset], al
    pop esi                          ; [inv]
    mov al, [ebp + esi]
    dec al
    mov [ebp + esi], al              ; count--
    mov [ebp + wListCount], al
    cmp al, 2
    jc .done
    mov [ebp + wMaxMenuItem], al
    jmp .done
.skipMovingUp:
    pop esi                          ; [inv]
.done:
    ret
