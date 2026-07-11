; ============================================================================
; swap_items.asm — SELECT-swap for the bag/item list (HandleItemListSwapping).
; Faithful translation of pret engine/menus/swap_items.asm.
;
; Wave 4 / M4.2: the generic list-menu driver this tail-calls
; (DisplayListMenuIDLoop) is now provided by src/home/list_menu.asm, so this file
; is no longer a dead end. The two link together via mutual tail jumps
; (DisplayListMenuIDLoop → HandleItemListSwapping on SELECT, and back).
;
; Assembly-convention fix (M4.2): WRAM/constant symbols are ABSOLUTE `equ`s and
; MUST come from %include "gb_memmap.inc" (the port convention, as bag_menu.asm
; does) — NOT `extern`. Externing them made this file fail to *assemble*
; ("COFF format does not support non-32-bit relocations" on `cmp al,
; ITEMLISTMENU`, an 8-bit immediate). Only real code labels stay `extern`.
; Symbols still missing from gb_memmap.inc / gb_constants.inc are LOCAL
; PLACEHOLDERS below (pret-derived, identical-valued) — ROOT migrates + deletes.
;
; LINK status: assembles CHECK-only now. To LINK, list_menu.asm must be in the
; same SRCS list and ROOT must assign real HRAM bytes for hSwapItemID /
; hSwapItemQuantity (placeholders here). No live caller invokes the list menu yet.
; ============================================================================
; dos_port/engine/menus/swap_items.asm
global HandleItemListSwapping

%include "gb_memmap.inc"
%include "gb_constants.inc"          ; ITEMLISTMENU (Wave 4)

; ── code labels (resolved at link) ──
extern DisplayListMenuIDLoop        ; src/home/list_menu.asm (M4.2)
extern DelayFrames                  ; src/video/frame.asm

; wListMenuID / wListPointer / ITEMLISTMENU / hSwapItemID / hSwapItemQuantity now
; live canonically in gb_memmap.inc / gb_constants.inc (Wave 4 integration).

section .text

HandleItemListSwapping:
    mov al, [ebp + wListMenuID]
    cmp al, ITEMLISTMENU
    jnz DisplayListMenuIDLoop

    push esi

    movzx esi, word [ebp + wListPointer]
    inc esi

    mov bl, [ebp + wCurrentMenuItem]
    mov al, [ebp + wListScrollOffset]
    add al, bl
    add al, al
    movzx ecx, al
    add esi, ecx
    
    mov al, [ebp + esi]
    
    mov dl, al
    pop esi
    mov al, dl
    
    inc al
    jz DisplayListMenuIDLoop
    
    mov al, [ebp + wMenuItemToSwap]
    test al, al
    jnz .swapItems
    
    mov al, [ebp + wCurrentMenuItem]
    inc al
    mov bl, al
    mov al, [ebp + wListScrollOffset]
    add al, bl
    mov [ebp + wMenuItemToSwap], al
    
    mov bl, 20                          ; DelayFrames reads BL (frame.asm:213)
    call DelayFrames
    jmp DisplayListMenuIDLoop

.swapItems:
    mov al, [ebp + wCurrentMenuItem]
    inc al
    mov bl, al
    mov al, [ebp + wListScrollOffset]
    add al, bl
    mov bl, al
    
    mov al, [ebp + wMenuItemToSwap]
    cmp al, bl
    jz DisplayListMenuIDLoop
    
    dec al
    mov [ebp + wMenuItemToSwap], al
    
    mov bl, 20                          ; DelayFrames reads BL (frame.asm:213)
    call DelayFrames
    
    push esi
    push dx
    
    movzx esi, word [ebp + wListPointer]
    inc esi
    
    mov edx, esi
    
    mov bl, [ebp + wCurrentMenuItem]
    mov al, [ebp + wListScrollOffset]
    add al, bl
    add al, al
    movzx ecx, al
    add esi, ecx
    
    mov al, [ebp + wMenuItemToSwap]
    add al, al
    movzx ecx, al
    add edx, ecx
    
    mov bl, [ebp + edx]
    mov al, [ebp + esi]
    inc esi
    cmp al, bl
    jz .swapSameItemType
    
    mov [ebp + hSwapItemID], al
    mov al, [ebp + esi]
    dec esi
    mov [ebp + hSwapItemQuantity], al
    
    mov al, [ebp + edx]
    mov [ebp + esi], al
    inc esi
    
    inc edx
    mov al, [ebp + edx]
    mov [ebp + esi], al
    
    mov al, [ebp + hSwapItemQuantity]
    mov [ebp + edx], al
    
    dec edx
    mov al, [ebp + hSwapItemID]
    mov [ebp + edx], al
    
    xor al, al
    mov [ebp + wMenuItemToSwap], al
    
    pop dx
    pop esi
    jmp DisplayListMenuIDLoop

.swapSameItemType:
    ; GLITCH: "Item Underflow / Dry Underflow" — `add al,bl` below is an
    ; unclamped 8-bit add of the two stacks' quantities. If the true sum is
    ; exactly 256 (reachable via the documented multi-step PC-box manipulation
    ; that engineers a >=100 quantity byte, then SELECT-merges it against a
    ; second stack), AL wraps to 0 BEFORE the `cmp al,100` check below, which
    ; then sees 0 < 100 and takes the "just combine" path — writing a quantity
    ; of 0 into the surviving slot instead of detecting overflow. A displayed
    ; ×0 stack is the entry point for the item-underflow chain: TOSSing one unit
    ; from a ×0 stack underflows the packed quantity byte 0x00 -> 0xFF (×255),
    ; exposing memory beyond the bag's real slot count as a fake, editable item
    ; slot — the gateway to "ws# #m#" and the item-underflow ACE chain. Gen-1
    ; behavior, preserved verbatim (matches pret's identical 8-bit `add`/`cp
    ; 100`). pret ref: engine/menus/swap_items.asm:HandleItemListSwapping
    ; (.swapSameItemType), docs/references/yellow_glitches.md#item--inventory
    ; (Item Underflow / Dry Underflow). Safety: this file is CHECK-only per its
    ; header (DisplayListMenuIDLoop/HandleItemListSwapping are not yet wired
    ; into any linked caller — "No live caller invokes the list menu yet"), so
    ; this path is dormant, not reachable, in the current build. Once linked:
    ; unsafe — ACE can escape EBP allocation via the downstream ws# #m# chain
    ; (see docs/glitch_safety.md); test only under DOSBox or 86Box.
    inc edx
    mov al, [ebp + esi]
    mov bl, al
    mov al, [ebp + edx]
    add al, bl
    cmp al, 100
    jc .combineItemSlots
    
    sub al, 99
    mov [ebp + edx], al
    mov al, 99
    mov [ebp + esi], al
    jmp .done

.combineItemSlots:
    mov [ebp + esi], al
    
    movzx esi, word [ebp + wListPointer]
    dec byte [ebp + esi]
    
    mov al, [ebp + esi]
    mov [ebp + wListCount], al
    
    cmp al, 1
    jnz .skipSettingMaxMenuItemID
    mov [ebp + wMaxMenuItem], al
.skipSettingMaxMenuItemID:
    dec edx
    mov esi, edx
    add esi, 2
    
.moveItemsUpLoop:
    mov al, [ebp + esi]
    inc esi
    mov [ebp + edx], al
    
    inc edx
    
    inc al
    jz .afterMovingItemsUp
    
    mov al, [ebp + esi]
    inc esi
    mov [ebp + edx], al
    
    inc edx
    jmp .moveItemsUpLoop
    
.afterMovingItemsUp:
    xor al, al
    mov [ebp + wListScrollOffset], al
    mov [ebp + wCurrentMenuItem], al

.done:
    xor al, al
    mov [ebp + wMenuItemToSwap], al
    
    pop dx
    pop esi
    jmp DisplayListMenuIDLoop
