; inventory.asm — mirror of pret home/inventory.asm.
;
; Holds three of that pret file's four labels, in pret's order:
;   AddAmountSoldToMoney     — was src/home/money.asm (which keeps pret
;                              home/money.asm's own HasEnoughMoney/HasEnoughCoins)
;   RemoveItemFromInventory  — was src/engine/items/inventory.asm
;   AddItemToInventory       — was src/engine/items/inventory.asm
;
; The fourth, SubtractAmountPaidFromMoney, is `missing` in the port: only its
; banked body SubtractAmountPaidFromMoney_ is translated, in
; src/engine/items/subtract_paid_money.asm. No home wrapper exists yet.
;
; The two inventory routines are pret's own wrapper/body split: the `_`-suffixed
; bodies AddItemToInventory_ and RemoveItemFromInventory_ are
; engine/items/inventory.asm labels and correctly STAY in that mirror, so these
; wrappers just extern back to them. On the GB the wrappers are the bank
; shuffle (homecall / homecall_sf); the port's flat memory model collapses that
; to preserving EBX(bc) around the call, which is all AddItemToInventory does.
;
; Register map: A=AL, BC=BX, HL=ESI, DE=EDX; EBP = GB memory base.
;
; Build: nasm -f coff -I include/ -I . -o inventory.o inventory.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

global AddAmountSoldToMoney
global RemoveItemFromInventory
global AddItemToInventory

extern AddItemToInventory_           ; src/engine/items/inventory.asm
extern RemoveItemFromInventory_      ; src/engine/items/inventory.asm
extern AddBCD                        ; EDX=de LSB (dest), ESI=hl LSB (src), CL=len; BCD add
extern DisplayTextBoxID              ; redraw the text box selected by [wTextBoxID]

section .text

; ---------------------------------------------------------------------------
; AddAmountSoldToMoney — add the sale total (hMoney) to the player's money, then
; redraw the MONEY text box. pret home/inventory.asm:AddAmountSoldToMoney.
;
; NOTE: pret's `predef AddBCDPredef` is a bank-switch indirection around AddBCD
; that restores de/hl/c from the predef registers; in the flat port we set those
; registers directly and call AddBCD (matching subtract_paid_money.asm's SubBCD).
;
; BUG{class=temporary; pret=home/inventory.asm:AddAmountSoldToMoney; behavior=the sale never plays SFX_PURCHASE and never waits for the current sound to drain, so a shop sale is silent and does not block; evidence=pret home/inventory.asm:AddAmountSoldToMoney ends `ld a, SFX_PURCHASE / call PlaySoundWaitForCurrent / jp WaitForSoundToFinish` and tools/faithdiff AddAmountSoldToMoney reports both as DROPPED, while the comment that justified the omission (audio HAL deferred to Phase 3) is measurably stale — both routines have real linked bodies in src/home/delay.asm and PlaySound is live in src/home/audio.asm; lifetime=until the two calls are restored and a shop scenario covers them}
; NOT fixed in the chunk-16 relocation commit: restoring dropped calls is a
; behaviour change, and no golden scenario reaches this routine (label_status
; --callers reports zero port callers — the shop layer is unported), so the
; change would be unverifiable. Scenario first, then the calls.
; ---------------------------------------------------------------------------
AddAmountSoldToMoney:
    mov edx, W_PLAYER_MONEY + 2      ; ld de, wPlayerMoney + 2 (LSB)
    mov esi, H_MONEY + 2             ; ld hl, hMoney + 2 (LSB, total price)
    mov cl, 3                        ; ld c, 3
    call AddBCD                      ; predef AddBCDPredef — add price to money

    mov byte [ebp + wTextBoxID], MONEY_BOX ; ld a, MONEY_BOX / ld [wTextBoxID], a
    call DisplayTextBoxID             ; redraw money text box

    ; DROPPED (see the BUG annotation above): pret then plays SFX_PURCHASE via
    ; PlaySoundWaitForCurrent and tail-jumps WaitForSoundToFinish.
    ret

; ---------------------------------------------------------------------------
; RemoveItemFromInventory — home wrapper around RemoveItemFromInventory_ (pret
; home/inventory.asm: homecall — bank shuffle only). Flat model: plain call;
; ESI (hl) passes through untouched.
; ---------------------------------------------------------------------------
RemoveItemFromInventory:
    call RemoveItemFromInventory_
    ret

; ---------------------------------------------------------------------------
; AddItemToInventory — home wrapper around AddItemToInventory_ (pret
; home/inventory.asm: push bc / homecall_sf / pop bc). Flat model: no banking,
; just preserve EBX(bc) around the call. Caller sets ESI = inventory count addr
; (W_NUM_BAG_ITEMS for the bag), [wCurItem], [wItemQuantity].
; ---------------------------------------------------------------------------
AddItemToInventory:
    push ebx
    call AddItemToInventory_
    pop ebx
    ret
