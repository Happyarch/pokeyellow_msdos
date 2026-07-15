; ============================================================================
; swap_items.asm — SELECT-swap for the bag/item list (HandleItemListSwapping).
; Faithful translation of pret engine/menus/swap_items.asm.
;
; The generic list-menu driver this tail-calls (DisplayListMenuIDLoop) lives in
; src/home/list_menu.asm. The two link together via mutual tail jumps
; (DisplayListMenuIDLoop → HandleItemListSwapping on SELECT, and back).
;
; Assembly convention: WRAM/constant symbols are ABSOLUTE `equ`s and MUST come
; from %include "gb_memmap.inc" — NOT `extern`. Externing them made this file
; fail to *assemble* ("COFF format does not support non-32-bit relocations" on
; `cmp al, ITEMLISTMENU`, an 8-bit immediate). Only real code labels stay `extern`.
;
; LINK status: LIVE. This file is in GAME_SRCS (Makefile), `nm` shows
; `T HandleItemListSwapping`, and its only caller — list_menu.asm's SELECT branch
; — is linked too, so the SELECT-swap runs whenever the bag list menu is open.
; hSwapItemID / hSwapItemQuantity are real HRAM equs in gb_memmap.inc.
; (An earlier header claimed this file was CHECK-only with "no live caller" and
; that the WRAM symbols below were local placeholders. Both were stale — there
; are no placeholders in this file, and the routine is in the linked binary.
; Corrected at menu-fidelity row 12; see M-47.)
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
    
    mov al, [ebp + esi]                 ; a = ID of the selected entry
    pop esi                             ; `pop` touches neither AL nor EFLAGS

    inc al
    jz DisplayListMenuIDLoop            ; ignore attempts to swap the Cancel entry
    
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
    
    push esi                            ; pret: push hl
    push edx                            ; pret: push de  (full EDX: it is used as a
                                        ; flat pointer below, so saving only DX
                                        ; would leave the high half clobbered)

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
    
    pop edx
    pop esi
    jmp DisplayListMenuIDLoop

.swapSameItemType:
    ; GLITCH{class=data-model; pret=engine/menus/swap_items.asm:HandleItemListSwapping; behavior=8-bit quantity merge can wrap an exact sum of 256 to a zero-count stack and open the item-underflow chain; evidence=pret .swapSameItemType add/cp sequence plus docs/references/yellow_glitches.md item-inventory section; lifetime=permanent Gen-1 behavior; safety=live ACE-capable chain can escape the EBP allocation, emulator only and never bare metal}
    ; "Item Underflow / Dry Underflow" — `add al,bl` below is an
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
    ; (Item Underflow / Dry Underflow).
    ; Safety: LIVE — this path is reachable in the current build. (The previous
    ; Safety note claimed the file was CHECK-only with no linked caller and that
    ; the glitch was therefore "dormant, not reachable". It inherited that from
    ; the stale header: swap_items.asm is in GAME_SRCS and list_menu.asm's SELECT
    ; branch jumps here. See M-47.) Reaching the underflow still requires the
    ; multi-step quantity manipulation described above, but the guard rail is
    ; the *setup*, not the link. Unsafe: ACE can escape the EBP allocation via
    ; the downstream ws# #m# chain (see docs/glitch_safety.md) — exercise only
    ; under DOSBox or 86Box, never on bare metal.
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
    
    pop edx
    pop esi
    jmp DisplayListMenuIDLoop
