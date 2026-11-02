; dos_port/src/engine/items/get_bag_item_quantity.asm

%include "gb_macros.inc"
%include "gb_memmap.inc"

section .text

global GetQuantityOfItemInBag
extern GetPredefRegisters

; -----------------------------------------------------------------------------
; GetQuantityOfItemInBag
;
; In: BH (b) = item ID
; Out: BH (b) = how many of that item are in the bag
; -----------------------------------------------------------------------------
GetQuantityOfItemInBag:
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=the callee saves B (the item id) into wPredefBC itself before GetPredefRegisters reloads BX from that slot, instead of relying on pret's predef macro to save it at the call site; evidence=pret's GetQuantityOfItemInBag opens with `call GetPredefRegisters` (engine/items/get_bag_item_quantity.asm:4), which reloads HL/DE/BC from wPredefHL/DE/BC, and on the GB the id survives only because the `predef` macro ran `call Predef` -> GetPredefPointer, which stores the caller's BC there first - the port has NO predef dispatcher (src/engine/predefs.asm is dead and excluded from the build), so every direct caller passes the id in BH and GetPredefRegisters overwrote it with stale wPredefBC, making cmp al, bh compare against garbage and the lookup always report quantity 0 - measured on the S.S. Ticket guard (Vermilion x=18 y=29, ticket 0x3F qty 1 in the bag, guard still refuses); lifetime=retire when PredefPointers is ported and callers go through a real predef dispatcher}
    mov [ebp + wPredefBC], bh        ; pret's predef macro saves b here; do it in the callee
    mov [ebp + wPredefBC + 1], bl    ; c — unused by this routine, saved for fidelity
    call GetPredefRegisters
    mov esi, wNumBagItems
.loop:
    inc esi
    mov al, byte [ebp + esi]
    inc esi
    cmp al, 0xFF
    jz .notInBag
    cmp al, bh
    jnz .loop
    
    ; Found the item, load its quantity into BH
    mov al, byte [ebp + esi]
    mov bh, al
    ret

.notInBag:
    mov bh, 0
    ret
