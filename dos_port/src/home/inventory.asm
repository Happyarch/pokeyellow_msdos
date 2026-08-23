; inventory.asm — mirror of pret home/inventory.asm.
;
; Holds all four of that pret file's labels, in pret's order:
;   SubtractAmountPaidFromMoney — the farjp wrapper around the banked body
;                              SubtractAmountPaidFromMoney_, which stays in its
;                              own mirror src/engine/items/subtract_paid_money.asm
;   AddAmountSoldToMoney     — was src/home/money.asm (which keeps pret
;                              home/money.asm's own HasEnoughMoney/HasEnoughCoins)
;   RemoveItemFromInventory  — was src/engine/items/inventory.asm
;   AddItemToInventory       — was src/engine/items/inventory.asm
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

global SubtractAmountPaidFromMoney
global AddAmountSoldToMoney
global RemoveItemFromInventory
global AddItemToInventory

extern SubtractAmountPaidFromMoney_  ; src/engine/items/subtract_paid_money.asm
extern AddItemToInventory_           ; src/engine/items/inventory.asm
extern RemoveItemFromInventory_      ; src/engine/items/inventory.asm
extern AddBCD                        ; EDX=de LSB (dest), ESI=hl LSB (src), CL=len; BCD add
extern DisplayTextBoxID              ; redraw the text box selected by [wTextBoxID]

section .text

; ---------------------------------------------------------------------------
; SubtractAmountPaidFromMoney — pret home/inventory.asm's `farjp
; SubtractAmountPaidFromMoney_` wrapper. On the GB the farjp is the bank shuffle
; into the body's bank; the port's flat address space collapses that to a plain
; tail jump, so the body's `ret` returns straight to our caller and its carry
; output (0 = paid, 1 = could not afford) reaches the caller unchanged.
; ---------------------------------------------------------------------------
SubtractAmountPaidFromMoney:
    jmp SubtractAmountPaidFromMoney_ ; farjp — no bank to switch in the flat model

; ---------------------------------------------------------------------------
; AddAmountSoldToMoney — add the sale total (hMoney) to the player's money, then
; redraw the MONEY text box. pret home/inventory.asm:AddAmountSoldToMoney.
;
; NOTE: pret's `predef AddBCDPredef` is a bank-switch indirection around AddBCD
; that restores de/hl/c from the predef registers; in the flat port we set those
; registers directly and call AddBCD (matching subtract_paid_money.asm's SubBCD).
;
; BUG{class=temporary; pret=home/inventory.asm:AddAmountSoldToMoney; behavior=the sale never plays SFX_PURCHASE and never waits for the current sound to drain, so a shop sale is silent and does not block; evidence=pret home/inventory.asm:AddAmountSoldToMoney ends `ld a, SFX_PURCHASE / call PlaySoundWaitForCurrent / jp WaitForSoundToFinish` and tools/faithdiff AddAmountSoldToMoney reports both as DROPPED, while the comment that justified the omission (audio HAL deferred to Phase 3) is measurably stale — both routines have real linked bodies in src/home/delay.asm and PlaySound is live in src/home/audio.asm; lifetime=until the two calls are restored and a shop scenario covers them}
; STILL NOT FIXED, but the reason CHANGED on 2026-08-18 and the old one is dead.
; This used to read "no golden scenario reaches this routine (label_status
; --callers reports zero port callers — the shop layer is unported)". The shop
; layer IS ported now: label_status --callers AddAmountSoldToMoney reports
; DisplayPokemartDialogue_ calling it at engine/events/pokemart.asm:164 (landed
; 63473f858). What remains is only the second half — there is still no golden
; scenario that walks a mart SALE, so restoring the two dropped calls would still
; be an unverifiable behaviour change. Scenario first, then the calls; the
; scenario is now actually writable, which it was not before.
; ---------------------------------------------------------------------------
AddAmountSoldToMoney:
    mov edx, wPlayerMoney + 2      ; ld de, wPlayerMoney + 2 (LSB)
    mov esi, hMoney + 2             ; ld hl, hMoney + 2 (LSB, total price)
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
; (wNumBagItems for the bag), [wCurItem], [wItemQuantity].
; ---------------------------------------------------------------------------
AddItemToInventory:
    push ebx
    call AddItemToInventory_
    pop ebx
    ret
