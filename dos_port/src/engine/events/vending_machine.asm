; ===========================================================================
; vending_machine.asm — faithful port of pret engine/events/vending_machine.asm (Pokemon Yellow)
;
; Implements VendingMachineMenu — the vending machine drink selection menu,
; money check, item delivery with sound effect, money deduction, and bag full /
; not thirsty exit handlers.
;
; Register map (SM83 -> x86): A=AL, HL=ESI, BC=BX, DE=EDX; EBP = GB base.
; GB memory is [ebp + addr].
;
; UI PROJECTION (docs/ui_projection.md):
;   overworld-ui (vending drinks): GB(0,3) 14x10 --(anchor=top-LEFT, X+0, Y+0)--> wx=7 wy=24 clip=112 max_y=104
;
; Build: nasm -f coff -I include/ -I . -o vending_machine.o src/engine/events/vending_machine.asm
; ===========================================================================

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_text.inc"
%include "coords.inc"
%include "assets/audio_constants.inc"

; HRAM definitions for vending machine (pret ram/hram.asm:310-311, union at 0xFFDB)
hVendingMachineItem   equ 0xFFDB
hVendingMachinePrice  equ 0xFFDC

section .text

global VendingMachineMenu
global LoadVendingMachineItem

; --- External routines ---
extern PrintText                        ; src/home/window.asm
extern DisplayTextBoxID                 ; src/home/textbox.asm
extern TextBoxBorder                    ; src/home/text.asm
extern UpdateSprites                    ; src/home/update_sprites.asm
extern PlaceString                      ; src/home/text.asm
extern HandleMenuInput                  ; src/home/window.asm
extern HasEnoughMoney                   ; src/home/money.asm
extern GiveItem                         ; src/home/give.asm
extern DelayFrames                      ; src/home/delay.asm
extern PlaySound                        ; src/home/audio.asm
extern SubBCD                           ; src/engine/math/bcd.asm
extern VendingPrices                    ; src/data/items/vending_prices.asm

; ---------------------------------------------------------------------------
; VendingMachineMenu — pret engine/events/vending_machine.asm:VendingMachineMenu
; ---------------------------------------------------------------------------
VendingMachineMenu:
    mov esi, VendingMachineText1                 ; ld hl, VendingMachineText1
    call PrintText                               ; call PrintText
    mov byte [ebp + wTextBoxID], MONEY_BOX       ; ld a, MONEY_BOX / ld [wTextBoxID], a
    call DisplayTextBoxID                        ; call DisplayTextBoxID
    xor al, al                                   ; xor a
    mov [ebp + wCurrentMenuItem], al             ; ld [wCurrentMenuItem], a
    mov [ebp + wLastMenuItem], al                ; ld [wLastMenuItem], a
    mov byte [ebp + wMenuWatchedKeys], PAD_A | PAD_B ; ld a, PAD_A | PAD_B / ld [wMenuWatchedKeys], a
    mov byte [ebp + wMaxMenuItem], 3             ; ld a, 3 / ld [wMaxMenuItem], a
    mov byte [ebp + wTopMenuItemY], 5            ; ld a, 5 / ld [wTopMenuItemY], a
    mov byte [ebp + wTopMenuItemX], 1            ; ld a, 1 / ld [wTopMenuItemX], a
    or byte [ebp + wStatusFlags5], (1 << BIT_NO_TEXT_DELAY) ; ld hl, wStatusFlags5 / set BIT_NO_TEXT_DELAY, [hl]
    ; PROJ overworld-ui (vending drinks): GB(0,3) 14x10 --(anchor=top-LEFT, X+0, Y+0)--> wx=7 wy=24 clip=112 max_y=104
    hlcoord 0, 3                                 ; hlcoord 0, 3
    mov bh, 8                                    ; lb bc, 8, 12
    mov bl, 12
    call TextBoxBorder                           ; call TextBoxBorder
    call UpdateSprites                           ; call UpdateSprites
    hlcoord 2, 5                                 ; hlcoord 2, 5
    mov eax, DrinkText                           ; ld de, DrinkText
    mov edx, eax
    call PlaceString                             ; call PlaceString
    hlcoord 9, 6                                 ; hlcoord 9, 6
    mov eax, DrinkPriceText                      ; ld de, DrinkPriceText
    mov edx, eax
    call PlaceString                             ; call PlaceString
    and byte [ebp + wStatusFlags5], ~(1 << BIT_NO_TEXT_DELAY) & 0xFF ; ld hl, wStatusFlags5 / res BIT_NO_TEXT_DELAY, [hl]
    call HandleMenuInput                         ; call HandleMenuInput
    test al, PAD_B                               ; bit B_PAD_B, a
    jnz .notThirsty                              ; jr nz, .notThirsty
    mov al, [ebp + wCurrentMenuItem]             ; ld a, [wCurrentMenuItem]
    cmp al, 3                                    ; cp 3 ; chose Cancel?
    jz .notThirsty                               ; jr z, .notThirsty
    xor al, al                                   ; xor a
    mov [ebp + hMoney], al                       ; ldh [hMoney], a
    mov [ebp + hMoney + 2], al                   ; ldh [hMoney + 2], a
    mov byte [ebp + hMoney + 1], 0x02            ; ld a, $2 / ldh [hMoney + 1], a
    call HasEnoughMoney                          ; call HasEnoughMoney
    jnc .enoughMoney                             ; jr nc, .enoughMoney
    mov esi, VendingMachineText4                 ; ld hl, VendingMachineText4
    jmp PrintText                                ; jp PrintText

.enoughMoney:
    call LoadVendingMachineItem                  ; call LoadVendingMachineItem
    mov bh, [ebp + hVendingMachineItem]          ; ldh a, [hVendingMachineItem] / ld b, a
    mov bl, 1                                    ; ld c, 1
    call GiveItem                                ; call GiveItem
    jnc .BagFull                                 ; jr nc, .BagFull

    mov bh, 60                                   ; ld b, 60 ; number of times to play the "brrrrr" sound
.playDeliverySound:
    mov bl, 2                                    ; ld c, 2
    call DelayFrames                             ; call DelayFrames
    push bx                                      ; push bc
    mov al, SFX_PUSH_BOULDER                     ; ld a, SFX_PUSH_BOULDER
    call PlaySound                               ; call PlaySound
    pop bx                                       ; pop bc
    dec bh                                       ; dec b
    jnz .playDeliverySound                       ; jr nz, .playDeliverySound

    mov esi, VendingMachineText5                 ; ld hl, VendingMachineText5
    call PrintText                               ; call PrintText
    mov esi, hVendingMachinePrice + 2            ; ld hl, hVendingMachinePrice + 2
    mov edx, wPlayerMoney + 2                    ; ld de, wPlayerMoney + 2
    mov cl, 0x3                                  ; ld c, $3
; DEVIATION{class=HAL; pret=engine/events/vending_machine.asm:VendingMachineMenu; behavior=calls SubBCD directly where pret runs predef SubBCDPredef; evidence=SubBCDPredef in the port is GetPredefRegisters falling through to SubBCD and the port has no predef dispatcher staging wPredefHL-DE-BC for this site so GetPredefRegisters would load stale registers over the live ones, the same convention AddBCD already uses; lifetime=permanent, the port calls predef targets directly}
    call SubBCD                                  ; predef SubBCDPredef
    mov byte [ebp + wTextBoxID], MONEY_BOX       ; ld a, MONEY_BOX / ld [wTextBoxID], a
    jmp DisplayTextBoxID                         ; jp DisplayTextBoxID

.BagFull:
    mov esi, VendingMachineText6                 ; ld hl, VendingMachineText6
    jmp PrintText                                ; jp PrintText

.notThirsty:
    mov esi, VendingMachineText7                 ; ld hl, VendingMachineText7
    jmp PrintText                                ; jp PrintText

; ---------------------------------------------------------------------------
; Text wrappers — pret engine/events/vending_machine.asm
; ---------------------------------------------------------------------------
VendingMachineText1:
    text_far _VendingMachineText1
    text_end

VendingMachineText4:
    text_far _VendingMachineText4
    text_end

VendingMachineText5:
    text_far _VendingMachineText5
    text_end

VendingMachineText6:
    text_far _VendingMachineText6
    text_end

VendingMachineText7:
    text_far _VendingMachineText7
    text_end

; ---------------------------------------------------------------------------
; LoadVendingMachineItem — pret engine/events/vending_machine.asm:LoadVendingMachineItem
; ---------------------------------------------------------------------------
LoadVendingMachineItem:
    mov esi, VendingPrices                       ; ld hl, VendingPrices (flat program-image ptr)
    movzx eax, byte [ebp + wCurrentMenuItem]    ; ld a, [wCurrentMenuItem]
    shl eax, 2                                   ; add a / add a (4 bytes per entry)
    add esi, eax                                 ; add hl, de
    mov al, [esi]                                ; ld a, [hli]
    inc esi
    mov [ebp + hVendingMachineItem], al          ; ldh [hVendingMachineItem], a
    mov al, [esi]                                ; ld a, [hli]
    inc esi
    mov [ebp + hVendingMachinePrice], al         ; ldh [hVendingMachinePrice], a
    mov al, [esi]                                ; ld a, [hli]
    inc esi
    mov [ebp + hVendingMachinePrice + 1], al     ; ldh [hVendingMachinePrice + 1], a
    mov al, [esi]                                ; ld a, [hl]
    mov [ebp + hVendingMachinePrice + 2], al     ; ldh [hVendingMachinePrice + 2], a
    ret

; ---------------------------------------------------------------------------
; Text and string assets — Tier 1 generated data
; ---------------------------------------------------------------------------
%include "assets/vending_machine_text.inc"
