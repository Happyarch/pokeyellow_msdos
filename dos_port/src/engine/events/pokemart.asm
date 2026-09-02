; ===========================================================================
; pokemart.asm — faithful port of pret engine/events/pokemart.asm (Pokemon Yellow)
;
; Implements DisplayPokemartDialogue_ — the Poke Mart buy/sell/quit transaction
; loop, buy flow (priced item list, quantity select, BCD money check, bag
; capacity check, money deduction, SFX_PURCHASE), sell flow (bag list, key/HM
; check, quantity select, half-price sale, money add), and thank-you exit.
;
; Register map (SM83 -> x86): A=AL, HL=ESI, BC=BX, DE=EDX; EBP = GB base.
; GB memory is [ebp + addr].
;
; UI PROJECTION (docs/ui_projection.md):
;   BUY/SELL/QUIT box : anchor top-LEFT,  X+0,  Y+0  -> canvas cols 0-10,  rows 0-6
;   MONEY box         : anchor top-right, X+20, Y+0  -> canvas cols 31-39, rows 0-2
;   priced item list  : anchor top-right, X+20, Y+0  -> canvas cols 24-39, rows 2-12  (1-row overlap with MONEY bottom, flush-right)
;   qty box (buy qty) : RELATIVE to list, +3 col +7 row -> canvas cols 27-39, rows 9-11 (overlaps list interior)
;
; Build: nasm -f coff -I include/ -I . -o pokemart.o src/engine/events/pokemart.asm
; ===========================================================================

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_text.inc"
%include "assets/audio_constants.inc"

; pret ram/wram.asm:1172. Address from pokeyellow.sym (00:cf0a) — NOT inferred.
; Was 0xCCD5, which is pret's wAILayer2Encouragement: the mart flag was landing on
; a trainer-AI byte.

section .text

global DisplayPokemartDialogue_

; --- External routines ---
extern UpdateSprites                    ; src/home/update_sprites.asm
extern DisplayTextBoxID                 ; src/home/textbox.asm
extern InitList                         ; src/engine/battle/misc.asm (pret callfar)
extern PrintText                        ; src/home/window.asm
extern SaveScreenTilesToBuffer1         ; src/home/tilemap.asm
extern LoadScreenTilesFromBuffer1       ; src/home/tilemap.asm
extern DisplayListMenuID                ; src/home/list_menu.asm
extern IsKeyItem                        ; src/home/item.asm
extern IsItemHM                         ; src/home/names.asm
extern DisplayChooseQuantityMenu        ; src/home/list_menu.asm
extern InitYesNoTextBoxParameters       ; src/home/yes_no.asm
extern AddAmountSoldToMoney             ; src/home/inventory.asm
extern RemoveItemFromInventory          ; src/home/inventory.asm
extern GetItemName                      ; src/home/names.asm
extern CopyToStringBuffer               ; src/home/copy_string.asm
extern AddItemToInventory               ; src/home/inventory.asm
extern SubtractAmountPaidFromMoney      ; src/home/inventory.asm (farjp wrapper -> subtract_paid_money.asm)
extern PlaySoundWaitForCurrent          ; src/home/delay.asm
extern WaitForSoundToFinish             ; src/home/delay.asm
extern StringCmp                        ; src/home/compare.asm
extern g_window_count                   ; src/ppu/ppu.asm
extern sync_dialog_window               ; src/home/text.asm

; ---------------------------------------------------------------------------
; DisplayPokemartDialogue_ — pret engine/events/pokemart.asm:DisplayPokemartDialogue_
; ---------------------------------------------------------------------------
DisplayPokemartDialogue_:
    mov al, [ebp + wListScrollOffset]            ; ld a, [wListScrollOffset]
    mov [ebp + wSavedListScrollOffset], al       ; ld [wSavedListScrollOffset], a
    call UpdateSprites                           ; call UpdateSprites
    xor al, al                                   ; xor a
    mov [ebp + wBoughtOrSoldItemInMart], al      ; ld [wBoughtOrSoldItemInMart], a

.loop:
    xor al, al                                   ; xor a
    mov [ebp + wListScrollOffset], al            ; ld [wListScrollOffset], a
    mov [ebp + wCurrentMenuItem], al             ; ld [wCurrentMenuItem], a
    mov [ebp + wPlayerMonNumber], al             ; ld [wPlayerMonNumber], a
    inc al                                       ; inc a
    mov [ebp + wPrintItemPrices], al             ; ld [wPrintItemPrices], a
    ; PROJ overworld-ui: GB(11,0) 9x3 --(anchor=top-right, X+20, Y+0)--> wx=255 wy=0 clip=72 max_y=24
    mov byte [ebp + wTextBoxID], MONEY_BOX       ; ld a, MONEY_BOX / ld [wTextBoxID], a
    call DisplayTextBoxID                        ; call DisplayTextBoxID
    ; PROJ overworld-ui: GB(0,0) 11x7 --(anchor=top-LEFT, X+0, Y+0)--> wx=7 wy=0 clip=88 max_y=56
    mov byte [ebp + wTextBoxID], BUY_SELL_QUIT_MENU ; ld a, BUY_SELL_QUIT_MENU / ld [wTextBoxID], a
    call DisplayTextBoxID                        ; call DisplayTextBoxID

    ; This code is useless. It copies the address of the pokemart's inventory to hl,
    ; but the address is never used.
    mov esi, wItemListPointer                    ; ld hl, wItemListPointer
    mov al, [ebp + esi]                          ; ld a, [hli]
    inc esi
    mov dl, [ebp + esi]                          ; ld l, [hl]
    mov dh, al                                   ; ld h, a

    mov al, [ebp + wMenuExitMethod]              ; ld a, [wMenuExitMethod]
    cmp al, CANCELLED_MENU                       ; cp CANCELLED_MENU
    je .done                                     ; jp z, .done
    mov al, [ebp + wChosenMenuItem]              ; ld a, [wChosenMenuItem]
    test al, al                                  ; and a ; buying?
    jz .buyMenu                                  ; jp z, .buyMenu
    dec al                                       ; dec a ; selling?
    jz .sellMenu                                 ; jp z, .sellMenu
    dec al                                       ; dec a ; quitting?
    jz .done                                     ; jp z, .done

.sellMenu:
    ; the same variables are set again below, so this code has no effect
    xor al, al                                   ; xor a
    mov [ebp + wPrintItemPrices], al             ; ld [wPrintItemPrices], a
    mov byte [ebp + wInitListType], INIT_BAG_ITEM_LIST ; ld a, INIT_BAG_ITEM_LIST / ld [wInitListType], a
    call InitList                                ; callfar InitList

    mov al, [ebp + wNumBagItems]                 ; ld a, [wNumBagItems]
    test al, al                                  ; and a
    jz .bagEmpty                                 ; jp z, .bagEmpty
    mov esi, PokemonSellingGreetingText          ; ld hl, PokemonSellingGreetingText
    call PrintText                               ; call PrintText
    call SaveScreenTilesToBuffer1                ; call SaveScreenTilesToBuffer1
    mov eax, [g_window_count]
    mov [mart_saved_wc], eax

.sellMenuLoop:
    call LoadScreenTilesFromBuffer1              ; call LoadScreenTilesFromBuffer1
    mov eax, [mart_saved_wc]
    mov [g_window_count], eax
    call sync_dialog_window
    ; PROJ overworld-ui: GB(11,0) 9x3 --(anchor=top-right, X+20, Y+0)--> wx=255 wy=0 clip=72 max_y=24
    mov byte [ebp + wTextBoxID], MONEY_BOX       ; ld a, MONEY_BOX / ld [wTextBoxID], a
    call DisplayTextBoxID                        ; call DisplayTextBoxID
    mov word [ebp + wListPointer], wNumBagItems  ; ld hl, wNumBagItems / ld a, l / ld [wListPointer], a / ld a, h / ld [wListPointer + 1], a
    xor al, al                                   ; xor a
    mov [ebp + wPrintItemPrices], al             ; ld [wPrintItemPrices], a
    mov [ebp + wCurrentMenuItem], al             ; ld [wCurrentMenuItem], a
    mov byte [ebp + wListMenuID], ITEMLISTMENU   ; ld a, ITEMLISTMENU / ld [wListMenuID], a
    call DisplayListMenuID                       ; call DisplayListMenuID
    jc .returnToMainPokemartMenu                 ; jp c, .returnToMainPokemartMenu

.confirmItemSale:
    call IsKeyItem                               ; call IsKeyItem
    mov al, [ebp + wIsKeyItem]                   ; ld a, [wIsKeyItem]
    test al, al                                  ; and a
    jnz .unsellableItem                          ; jr nz, .unsellableItem
    mov al, [ebp + wCurItem]                     ; ld a, [wCurItem]
    call IsItemHM                                ; call IsItemHM
    jc .unsellableItem                           ; jr c, .unsellableItem
    mov byte [ebp + wListMenuID], PRICEDITEMLISTMENU ; ld a, PRICEDITEMLISTMENU / ld [wListMenuID], a
    mov byte [ebp + hHalveItemPrices], PRICEDITEMLISTMENU ; ldh [hHalveItemPrices], a
    call DisplayChooseQuantityMenu               ; call DisplayChooseQuantityMenu
    inc al                                       ; inc a
    jz .sellMenuLoop                             ; jr z, .sellMenuLoop
    mov esi, PokemartTellSellPriceText           ; ld hl, PokemartTellSellPriceText
    mov bh, 14                                   ; lb bc, 14, 1
    mov bl, 1
    call PrintText                               ; call PrintText
    ; PROJ overworld-ui: GB(14,7) 6x5 --(anchor=top-right, X+20, Y+0)--> wx=279 wy=56 clip=48 max_y=96
    call InitYesNoTextBoxParameters              ; hlcoord 14, 7 / lb bc, 8, 15
    mov byte [ebp + wTextBoxID], TWO_OPTION_MENU ; ld a, TWO_OPTION_MENU / ld [wTextBoxID], a
    call DisplayTextBoxID                        ; call DisplayTextBoxID
    mov al, [ebp + wMenuExitMethod]              ; ld a, [wMenuExitMethod]
    cmp al, CHOSE_SECOND_ITEM                    ; cp CHOSE_SECOND_ITEM
    je .sellMenuLoop                             ; jr z, .sellMenuLoop

    ; The following code is supposed to check if the player chose No, but the above
    ; check already catches it.
    mov al, [ebp + wChosenMenuItem]              ; ld a, [wChosenMenuItem]
    dec al                                       ; dec a
    jz .sellMenuLoop                             ; jr z, .sellMenuLoop

    ; sell item
    mov al, [ebp + wBoughtOrSoldItemInMart]      ; ld a, [wBoughtOrSoldItemInMart]
    test al, al                                  ; and a
    jnz .skipSettingFlag1                        ; jr nz, .skipSettingFlag1
    inc al                                       ; inc a
    mov [ebp + wBoughtOrSoldItemInMart], al      ; ld [wBoughtOrSoldItemInMart], a
.skipSettingFlag1:
    call AddAmountSoldToMoney                    ; call AddAmountSoldToMoney
    mov esi, wNumBagItems                        ; ld hl, wNumBagItems
    call RemoveItemFromInventory                 ; call RemoveItemFromInventory
    jmp .sellMenuLoop                            ; jp .sellMenuLoop

.unsellableItem:
    mov esi, PokemartUnsellableItemText          ; ld hl, PokemartUnsellableItemText
    call PrintText                               ; call PrintText
    jmp .returnToMainPokemartMenu                ; jp .returnToMainPokemartMenu

.bagEmpty:
    mov esi, PokemartItemBagEmptyText            ; ld hl, PokemartItemBagEmptyText
    call PrintText                               ; call PrintText
    call SaveScreenTilesToBuffer1                ; call SaveScreenTilesToBuffer1
    mov eax, [g_window_count]
    mov [mart_saved_wc], eax
    jmp .returnToMainPokemartMenu                ; jp .returnToMainPokemartMenu

.buyMenu:
    ; the same variables are set again below, so this code has no effect
    mov al, 1                                    ; ld a, 1
    mov [ebp + wPrintItemPrices], al             ; ld [wPrintItemPrices], a
    mov byte [ebp + wInitListType], INIT_OTHER_ITEM_LIST ; ld a, INIT_OTHER_ITEM_LIST / ld [wInitListType], a
    call InitList                                ; callfar InitList

    mov esi, PokemartBuyingGreetingText          ; ld hl, PokemartBuyingGreetingText
    call PrintText                               ; call PrintText
    call SaveScreenTilesToBuffer1                ; call SaveScreenTilesToBuffer1
    mov eax, [g_window_count]
    mov [mart_saved_wc], eax

.buyMenuLoop:
    call LoadScreenTilesFromBuffer1              ; call LoadScreenTilesFromBuffer1
    mov eax, [mart_saved_wc]
    mov [g_window_count], eax
    call sync_dialog_window
    ; PROJ overworld-ui: GB(11,0) 9x3 --(anchor=top-right, X+20, Y+0)--> wx=255 wy=0 clip=72 max_y=24
    mov byte [ebp + wTextBoxID], MONEY_BOX       ; ld a, MONEY_BOX / ld [wTextBoxID], a
    call DisplayTextBoxID                        ; call DisplayTextBoxID
    mov word [ebp + wListPointer], wItemList     ; ld hl, wItemList / ld a, l / ld [wListPointer], a / ld a, h / ld [wListPointer + 1], a
    xor al, al                                   ; xor a
    mov [ebp + wCurrentMenuItem], al             ; ld [wCurrentMenuItem], a
    inc al                                       ; inc a
    mov [ebp + wPrintItemPrices], al             ; ld [wPrintItemPrices], a
    inc al                                       ; inc a ; a = 2 (PRICEDITEMLISTMENU)
    mov [ebp + wListMenuID], al                  ; ld [wListMenuID], a
    ; PROJ overworld-ui: GB(4,2) 16x11 --(anchor=top-right, X+20, Y+0)--> wx=199 wy=16 clip=128 max_y=104  (borders DOS right edge, 1-row overlap with MONEY)
    call DisplayListMenuID                       ; call DisplayListMenuID
    jc .returnToMainPokemartMenu                 ; jr c, .returnToMainPokemartMenu
    mov byte [ebp + wMaxItemQuantity], 99        ; ld a, 99 / ld [wMaxItemQuantity], a
    xor al, al                                   ; xor a
    mov [ebp + hHalveItemPrices], al             ; ldh [hHalveItemPrices], a
    call DisplayChooseQuantityMenu               ; call DisplayChooseQuantityMenu — qty at (27,9) RELATIVE to list (24,2)+(+3,+7), overlapping list interior
    inc al                                       ; inc a
    jz .buyMenuLoop                              ; jr z, .buyMenuLoop
    mov al, [ebp + wCurItem]                     ; ld a, [wCurItem]
    mov [ebp + wNamedObjectIndex], al            ; ld [wNamedObjectIndex], a
    call GetItemName                             ; call GetItemName
    call CopyToStringBuffer                      ; call CopyToStringBuffer
    mov esi, PokemartTellBuyPriceText            ; ld hl, PokemartTellBuyPriceText
    call PrintText                               ; call PrintText
    ; PROJ overworld-ui: GB(14,7) 6x5 --(anchor=top-right, X+20, Y+0)--> wx=279 wy=56 clip=48 max_y=96
    call InitYesNoTextBoxParameters              ; hlcoord 14, 7 / lb bc, 8, 15
    mov byte [ebp + wTextBoxID], TWO_OPTION_MENU ; ld a, TWO_OPTION_MENU / ld [wTextBoxID], a
    call DisplayTextBoxID                        ; call DisplayTextBoxID
    mov al, [ebp + wMenuExitMethod]              ; ld a, [wMenuExitMethod]
    cmp al, CHOSE_SECOND_ITEM                    ; cp CHOSE_SECOND_ITEM
    je .buyMenuLoop                              ; jp z, .buyMenuLoop

    ; The following code is supposed to check if the player chose No, but the above
    ; check already catches it.
    mov al, [ebp + wChosenMenuItem]              ; ld a, [wChosenMenuItem]
    dec al                                       ; dec a
    jz .buyMenuLoop                              ; jr z, .buyMenuLoop

    ; buy item
    call .isThereEnoughMoney                     ; call .isThereEnoughMoney
    jc .notEnoughMoney                           ; jr c, .notEnoughMoney
    mov esi, wNumBagItems                        ; ld hl, wNumBagItems
    call AddItemToInventory                      ; call AddItemToInventory
    jnc .bagFull                                 ; jr nc, .bagFull
    call SubtractAmountPaidFromMoney             ; call SubtractAmountPaidFromMoney
    mov al, [ebp + wBoughtOrSoldItemInMart]      ; ld a, [wBoughtOrSoldItemInMart]
    test al, al                                  ; and a
    jnz .skipSettingFlag2                        ; jr nz, .skipSettingFlag2
    mov al, 1                                    ; ld a, 1
    mov [ebp + wBoughtOrSoldItemInMart], al      ; ld [wBoughtOrSoldItemInMart], a
.skipSettingFlag2:
    mov al, SFX_PURCHASE                         ; ld a, SFX_PURCHASE
    call PlaySoundWaitForCurrent                 ; call PlaySoundWaitForCurrent
    call WaitForSoundToFinish                    ; call WaitForSoundToFinish
    mov esi, PokemartBoughtItemText              ; ld hl, PokemartBoughtItemText
    call PrintText                               ; call PrintText
    jmp .buyMenuLoop                             ; jp .buyMenuLoop

.returnToMainPokemartMenu:
    call LoadScreenTilesFromBuffer1              ; call LoadScreenTilesFromBuffer1
    mov eax, [mart_saved_wc]
    mov [g_window_count], eax
    call sync_dialog_window
    ; PROJ overworld-ui: GB(11,0) 9x3 --(anchor=top-right, X+20, Y+0)--> wx=255 wy=0 clip=72 max_y=24
    mov byte [ebp + wTextBoxID], MONEY_BOX       ; ld a, MONEY_BOX / ld [wTextBoxID], a
    call DisplayTextBoxID                        ; call DisplayTextBoxID
    mov esi, PokemartAnythingElseText            ; ld hl, PokemartAnythingElseText
    call PrintText                               ; call PrintText
    jmp .loop                                    ; jp .loop

.isThereEnoughMoney:
    mov edx, wPlayerMoney                        ; ld de, wPlayerMoney
    mov esi, hMoney                              ; ld hl, hMoney
    mov bl, 3                                    ; ld c, 3
    jmp StringCmp                                ; jp StringCmp

.notEnoughMoney:
    mov esi, PokemartNotEnoughMoneyText          ; ld hl, PokemartNotEnoughMoneyText
    call PrintText                               ; call PrintText
    jmp .returnToMainPokemartMenu                ; jr .returnToMainPokemartMenu

.bagFull:
    mov esi, PokemartItemBagFullText             ; ld hl, PokemartItemBagFullText
    call PrintText                               ; call PrintText
    jmp .returnToMainPokemartMenu                ; jr .returnToMainPokemartMenu

.done:
    extern hide_window
    call hide_window                             ; clear leaked list/qty windows — otherwise GB_TILEMAP0 window at 24,2 (right edge) paints blank box over overworld after B/QUIT exit
    mov esi, PokemartThankYouText                ; ld hl, PokemartThankYouText
    call PrintText                               ; call PrintText
    mov byte [ebp + wUpdateSpritesEnabled], 1    ; ld a, 1 / ld [wUpdateSpritesEnabled], a
    call UpdateSprites                           ; call UpdateSprites
    mov al, [ebp + wSavedListScrollOffset]       ; ld a, [wSavedListScrollOffset]
    mov [ebp + wListScrollOffset], al            ; ld [wListScrollOffset], a
    ret

section .bss
mart_saved_wc: resd 1
mart_price_saved_wc: resd 1

section .text
; ---------------------------------------------------------------------------
; Text wrappers — pret engine/events/pokemart.asm
; ---------------------------------------------------------------------------
PokemartBuyingGreetingText:
    text_far _PokemartBuyingGreetingText
    text_end

PokemartTellBuyPriceText:
    text_far _PokemartTellBuyPriceText
    text_end

PokemartBoughtItemText:
    text_far _PokemartBoughtItemText
    text_end

PokemartNotEnoughMoneyText:
    text_far _PokemartNotEnoughMoneyText
    text_end

PokemartItemBagFullText:
    text_far _PokemartItemBagFullText
    text_end

PokemonSellingGreetingText:
    text_far _PokemonSellingGreetingText
    text_end

PokemartTellSellPriceText:
    text_far _PokemartTellSellPriceText
    text_end

PokemartItemBagEmptyText:
    text_far _PokemartItemBagEmptyText
    text_end

PokemartUnsellableItemText:
    text_far _PokemartUnsellableItemText
    text_end

PokemartThankYouText:
    text_far _PokemartThankYouText
    text_end

PokemartAnythingElseText:
    text_far _PokemartAnythingElseText
    text_end

%include "assets/pokemart_text.inc"
