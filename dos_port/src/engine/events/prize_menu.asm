; ===========================================================================
; prize_menu.asm — faithful port of pret engine/events/prize_menu.asm (Pokemon Yellow)
;
; Implements CeladonPrizeMenu — the Celadon Game Corner prize menu,
; coin check, item / mon delivery, coin deduction, and exit handlers.
;
; Register map (SM83 -> x86): A=AL, HL=ESI, BC=BX (B=BH, C=BL), DE=EDX (D=DH, E=DL); EBP = GB base.
; GB memory is [ebp + addr].
;
; UI PROJECTION (docs/ui_projection.md):
;   overworld-ui (prize menu):     GB(0,2)  18x10 --(anchor=top-LEFT, X+0, Y+0)-->  wx=7   wy=16 clip=144 max_y=96
;   overworld-ui (prize coin box): GB(11,0) 9x3   --(anchor=top-right, X+20, Y+0)--> wx=255 wy=0  clip=72  max_y=24
;
; Build: nasm -f coff -I include/ -I . -o prize_menu.o src/engine/events/prize_menu.asm
; ===========================================================================

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_text.inc"
%include "coords.inc"
%include "assets/ui_layout_menus.inc"

; Vendor 1 text ID constant (scripts/GameCornerPrizeRoom.asm, data/maps/objects/GameCornerPrizeRoom.asm)
TEXT_GAMECORNERPRIZEROOM_PRIZE_VENDOR_1 equ 0x03

; Port-only presentation (mart class, 10850fd95): the overworld canvas drawing
; below is invisible until mirrored into GB_TILEMAP0 and published as a window
; descriptor (the compositor reads the window source, not wTileMap — measured
; prize_corner frames 280/500: no coin box, no menu, blank WhichPrize).
; Coin shares money's mirror slot AND window geometry (same GB(11,0) 9x3 box);
; the mart money window is never open concurrently, and PrintText's
; dialog-preservation scan already keeps srow 20.
PRIZE_COIN_SROW equ 20           ; GB_TILEMAP0 mirror rows 20-22 (coin 9x3)
; The 18x10 menu needs 10 rows; srow 1 (rows 1-10) is unique among concurrent
; flows (YN 11-15 opens during SoYouWantPrize confirm) and is added to
; PrintText's dialog-preservation scan in src/home/window.asm.
PRIZE_MENU_SROW equ 1            ; GB_TILEMAP0 mirror rows 1-10 (menu 18x10)
; Publish geometry from the header PROJ rulings (coin = money's textbox,
; menu left-projected).
PRIZE_MENU_WX   equ 7
PRIZE_MENU_WY   equ 16
PRIZE_MENU_CLIP equ 144
PRIZE_MENU_MAXY equ 96

; Prize menu WRAM / HRAM definitions (pret ram/wram.asm:1837, 1848, 1860-1872; ram/hram.asm:175)

section .text

global CeladonPrizeMenu
global GetPrizeMenuId
global PrintPrizePrice
global LoadCoinsToSubtract
global HandlePrizeChoice
global GetPrizeMonLevel
global UnknownPrizeData

; --- External routines ---
extern IsItemInBag                      ; src/home/map_objects.asm
extern PrintText                        ; src/home/window.asm
extern TextBoxBorder                    ; src/home/text.asm
extern UpdateSprites                    ; src/home/update_sprites.asm
extern HandleMenuInput                  ; src/home/window.asm
extern GetItemName                      ; src/home/names.asm
extern GetMonName                       ; src/home/names.asm
extern PlaceString                      ; src/home/text.asm
extern PrintBCDNumber                   ; src/home/print_bcd.asm
extern YesNoChoice                      ; src/home/yes_no.asm
extern HasEnoughCoins                   ; src/home/money.asm
extern GiveItem                         ; src/home/give.asm
extern GivePokemon                      ; src/home/give.asm
extern WaitForTextScrollButtonPress     ; src/home/joypad2.asm
extern SubBCD                           ; src/engine/math/bcd.asm
extern text_row_stride                  ; src/home/text.asm — active wTileMap row stride
extern add_window                       ; src/ppu/ppu.asm — publish a window descriptor
extern g_windows                        ; src/ppu/ppu.asm — window descriptor array
extern g_window_count                   ; src/ppu/ppu.asm — active window-descriptor count
extern menu_redraw_cb                   ; src/home/window.asm — per-frame side-info redraw cb
extern menu_item_step                   ; src/home/window.asm — per-item row step (bytes)
extern g_dialog_preserve_windows        ; src/home/text.asm — 1 = dialog pauses keep windows (mart pattern)
extern g_bg_whiteout                    ; src/ppu/ppu.asm — 1 = blank BG, full-screen takeover

; --- External data tables ---
extern PrizeDifferentMenuPtrs           ; src/data/events/prizes.asm
extern PrizeMonLevelDictionary          ; src/data/events/prize_mon_levels.asm

; ---------------------------------------------------------------------------
; CeladonPrizeMenu — pret engine/events/prize_menu.asm:CeladonPrizeMenu
; ---------------------------------------------------------------------------
CeladonPrizeMenu:
    mov bh, COIN_CASE                            ; ld b, COIN_CASE
    call IsItemInBag                             ; call IsItemInBag
    jnz .havingCoinCase                          ; jr nz, .havingCoinCase
    mov esi, RequireCoinCaseText                 ; ld hl, RequireCoinCaseText
    jmp PrintText                                ; jp PrintText

.havingCoinCase:
    or byte [ebp + wStatusFlags5], (1 << BIT_NO_TEXT_DELAY) ; ld hl, wStatusFlags5 / set BIT_NO_TEXT_DELAY, [hl]
    mov esi, ExchangeCoinsForPrizesText          ; ld hl, ExchangeCoinsForPrizesText
    call PrintText                               ; call PrintText
; the following are the menu settings
    xor al, al                                   ; xor a
    mov [ebp + wCurrentMenuItem], al             ; ld [wCurrentMenuItem], a
    mov [ebp + wLastMenuItem], al                ; ld [wLastMenuItem], a
    mov byte [ebp + wMenuWatchedKeys], PAD_A | PAD_B ; ld a, PAD_A | PAD_B / ld [wMenuWatchedKeys], a
    mov byte [ebp + wMaxMenuItem], 0x03          ; ld a, $03 / ld [wMaxMenuItem], a
    mov byte [ebp + wTopMenuItemY], 0x04         ; ld a, $04 / ld [wTopMenuItemY], a
    mov byte [ebp + wTopMenuItemX], 0x01         ; ld a, $01 / ld [wTopMenuItemX], a
    call PrintPrizePrice                         ; call PrintPrizePrice (stride-safe, coin window published inside)
    ; Canvas menu drawing runs at the 40-wide canvas stride: PrintText publishes
    ; the 20-wide dialog stride, and DisplayTextBoxID_'s temporary force does not
    ; cover this manual box (same trap the mart mirrors were built for).
    push dword [text_row_stride]
    mov dword [text_row_stride], SCREEN_TILES_W
    ; PROJ overworld-ui (prize menu): GB(0,2) 18x10 --(anchor=top-LEFT, X+0, Y+0)--> wx=7 wy=16 clip=144 max_y=96
    hlcoord 0, 2                                 ; hlcoord 0, 2
    mov bh, 8                                    ; lb bc, 8, 16
    mov bl, 16
    call TextBoxBorder                           ; call TextBoxBorder
    call GetPrizeMenuId                          ; call GetPrizeMenuId
    pop dword [text_row_stride]
    call UpdateSprites                           ; call UpdateSprites
    mov esi, WhichPrizeText                      ; ld hl, WhichPrizeText
    call PrintText                               ; call PrintText
    ; Which's dialog scratch (20-wide rows 12-17) aliases canvas rows 6-8, so it
    ; types over the menu names just drawn; redraw before mirroring (pret needs
    ; no equivalent: one 20x18 tilemap keeps menu rows 2-11 clear of dialog
    ; rows 12-17).
    push dword [text_row_stride]
    mov dword [text_row_stride], SCREEN_TILES_W
    hlcoord 0, 2
    mov bh, 8
    mov bl, 16
    call TextBoxBorder
    call GetPrizeMenuId
    pop dword [text_row_stride]
    call prize_show_menu_window                  ; mirror + idempotent publish (mart class)
    ; Mart pattern (pokemart.asm): dialog pauses (prompt/cont) reset the window
    ; list via set_single_window unless this flag is set — without it the
    ; Sorry/OhFineThen prompts would tear down the coin+menu windows mid-flow.
    ; Host BSS byte (no EBP bias), as in pokemart.asm.
    mov byte [g_dialog_preserve_windows], 1
    ; PlaceMenuCursor addresses Y*stride+X: the dialog stride (20) would park the
    ; cursor on the box's top border; drive input at the canvas stride with the
    ; two-row canvas step (pret: hlcoord + 2*20 default, here 2 rows of 40).
    mov dword [menu_item_step], 2 * SCREEN_TILES_W
    push dword [text_row_stride]
    mov dword [text_row_stride], SCREEN_TILES_W
    mov dword [menu_redraw_cb], prize_menu_mirror ; re-mirror per input frame (cursor moves)
    call HandleMenuInput                         ; call HandleMenuInput ; menu choice handler
    mov dword [menu_redraw_cb], 0
    pop dword [text_row_stride]
    test al, PAD_B                               ; bit B_PAD_B, a
    jnz .noChoice                                ; jr nz, .noChoice
    mov al, [ebp + wCurrentMenuItem]             ; ld a, [wCurrentMenuItem]
    cmp al, 3                                    ; cp 3 ; "NO,THANKS" choice
    jz .noChoice                                 ; jr z, .noChoice
    call HandlePrizeChoice                       ; call HandlePrizeChoice
.noChoice:
    ; Spec: teardown happens here — after naming completes/declines (or the
    ; choice otherwise resolves), never earlier. Drops exactly the two prize
    ; windows; the dialog stays for HoldTextDisplayOpen, closed by
    ; CloseTextDisplay's hide_window.
    call prize_drop_windows
    mov byte [g_dialog_preserve_windows], 0
    and byte [ebp + wStatusFlags5], ~(1 << BIT_NO_TEXT_DELAY) & 0xFF ; ld hl, wStatusFlags5 / res BIT_NO_TEXT_DELAY, [hl]
    ret

; ---------------------------------------------------------------------------
; Text wrappers — pret engine/events/prize_menu.asm
; ---------------------------------------------------------------------------
RequireCoinCaseText:
    text_far _RequireCoinCaseText
    text_waitbutton
    text_end

ExchangeCoinsForPrizesText:
    text_far _ExchangeCoinsForPrizesText
    text_end

WhichPrizeText:
    text_far _WhichPrizeText
    text_end

HereYouGoText: ; unreferenced
    text_far _HereYouGoText
    text_waitbutton
    text_end

SoYouWantPrizeText:
    text_far _SoYouWantPrizeText
    text_end

SorryNeedMoreCoinsText:
    text_far _SorryNeedMoreCoinsText
    text_waitbutton
    text_end

PrizeRoomBagIsFullText:
    text_far _OopsYouDontHaveEnoughRoomText
    text_waitbutton
    text_end

OhFineThenText:
    text_far _OhFineThenText
    text_waitbutton
    text_end

; ---------------------------------------------------------------------------
; GetPrizeMenuId — pret engine/events/prize_menu.asm:GetPrizeMenuId
; ---------------------------------------------------------------------------
GetPrizeMenuId:
    mov al, [ebp + hTextID]                      ; ldh a, [hTextID]
    sub al, TEXT_GAMECORNERPRIZEROOM_PRIZE_VENDOR_1 ; sub TEXT_GAMECORNERPRIZEROOM_PRIZE_VENDOR_1
    mov [ebp + wWhichPrizeWindow], al            ; ld [wWhichPrizeWindow], a ; prize texts' relative ID (i.e. 0-2)
    movzx eax, al
    mov edx, [PrizeDifferentMenuPtrs + eax * 8]      ; entries pointer (flat)
    mov esi, [PrizeDifferentMenuPtrs + eax * 8 + 4]  ; prices pointer (flat)

; DEVIATION{class=projection; pret=engine/events/prize_menu.asm:GetPrizeMenuId; behavior=copy prize entries and prices inline from FLAT program-image pointers rather than calling CopyString/CopyData with GB offsets; evidence=PrizeDifferentMenuPtrs lives in .data in the host image while CopyString/CopyData resolve their sources as GB offsets via [ebp+reg], same as LoadGymLeaderAndCityName; lifetime=permanent flat-program-image boundary}
    ; Copy prize entries string (3 bytes + '@') to wPrize1
    lea edi, [ebp + wPrize1]
.copy_entries:
    mov al, [edx]
    inc edx
    mov [edi], al
    inc edi
    cmp al, 0x50                                 ; '@'
    jne .copy_entries

    ; Copy 3 prize prices (6 bytes) from esi to wPrize1Price
    lea edi, [ebp + wPrize1Price]
    mov ecx, 6
    rep movsb

    mov al, [ebp + wWhichPrizeWindow]            ; ld a, [wWhichPrizeWindow]
    cmp al, 2                                    ; cp 2 ; is TM_menu?
    jnz .putMonName                              ; jr nz, .putMonName

    mov al, [ebp + wPrize1]                      ; ld a, [wPrize1]
    mov [ebp + wNamedObjectIndex], al            ; ld [wNamedObjectIndex], a
    call GetItemName                             ; call GetItemName
    lea eax, [ebp + wNameBuffer]
    hlcoord 2, 4                                 ; hlcoord 2, 4
    call PlaceString                             ; call PlaceString
    mov al, [ebp + wPrize2]                      ; ld a, [wPrize2]
    mov [ebp + wNamedObjectIndex], al            ; ld [wNamedObjectIndex], a
    call GetItemName                             ; call GetItemName
    lea eax, [ebp + wNameBuffer]
    hlcoord 2, 6                                 ; hlcoord 2, 6
    call PlaceString                             ; call PlaceString
    mov al, [ebp + wPrize3]                      ; ld a, [wPrize3]
    mov [ebp + wNamedObjectIndex], al            ; ld [wNamedObjectIndex], a
    call GetItemName                             ; call GetItemName
    lea eax, [ebp + wNameBuffer]
    hlcoord 2, 8                                 ; hlcoord 2, 8
    call PlaceString                             ; call PlaceString
    jmp .putNoThanksText                         ; jr .putNoThanksText

.putMonName:
    mov al, [ebp + wPrize1]                      ; ld a, [wPrize1]
    mov [ebp + wNamedObjectIndex], al            ; ld [wNamedObjectIndex], a
    call GetMonName                              ; call GetMonName
    lea eax, [ebp + wNameBuffer]
    hlcoord 2, 4                                 ; hlcoord 2, 4
    call PlaceString                             ; call PlaceString
    mov al, [ebp + wPrize2]                      ; ld a, [wPrize2]
    mov [ebp + wNamedObjectIndex], al            ; ld [wNamedObjectIndex], a
    call GetMonName                              ; call GetMonName
    lea eax, [ebp + wNameBuffer]
    hlcoord 2, 6                                 ; hlcoord 2, 6
    call PlaceString                             ; call PlaceString
    mov al, [ebp + wPrize3]                      ; ld a, [wPrize3]
    mov [ebp + wNamedObjectIndex], al            ; ld [wNamedObjectIndex], a
    call GetMonName                              ; call GetMonName
    lea eax, [ebp + wNameBuffer]
    hlcoord 2, 8                                 ; hlcoord 2, 8
    call PlaceString                             ; call PlaceString

.putNoThanksText:
    hlcoord 2, 10                                ; hlcoord 2, 10
    mov eax, NoThanksText                        ; ld de, NoThanksText
    mov edx, eax
    call PlaceString                             ; call PlaceString

; put prices on the right side of the textbox
    mov edx, wPrize1Price                        ; ld de, wPrize1Price
    hlcoord 13, 5                                ; hlcoord 13, 5
    mov bl, 2 | LEADING_ZEROES                   ; ld c, 2 | LEADING_ZEROES
    call PrintBCDNumber                          ; call PrintBCDNumber
    mov edx, wPrize2Price                        ; ld de, wPrize2Price
    hlcoord 13, 7                                ; hlcoord 13, 7
    mov bl, 2 | LEADING_ZEROES                   ; ld c, 2 | LEADING_ZEROES
    call PrintBCDNumber                          ; call PrintBCDNumber
    mov edx, wPrize3Price                        ; ld de, wPrize3Price
    hlcoord 13, 9                                ; hlcoord 13, 9
    mov bl, 2 | LEADING_ZEROES                   ; ld c, 2 | LEADING_ZEROES
    jmp PrintBCDNumber                           ; jp PrintBCDNumber

; ---------------------------------------------------------------------------
; PrintPrizePrice — pret engine/events/prize_menu.asm:PrintPrizePrice
;
; Coins share money's textbox: the GB(11,0) 9x3 coin box is drawn at the money
; template's right/top-anchored canvas position (UI_MONEY_BOX_TEMPLATE_COL,ROW),
; at the 40-wide canvas stride, then mirrored + window-published (mart class).
; Self-contained stride force: also called from .subtractCoins after the stride
; was restored.
; ---------------------------------------------------------------------------
PrintPrizePrice:
    push dword [text_row_stride]
    mov dword [text_row_stride], SCREEN_TILES_W
    ; PROJ overworld-ui (prize coin box): GB(11,0) 9x3 --(anchor=top-right, X+20, Y+0)--> wx=255 wy=0 clip=72 max_y=24
    mov esi, wTileMap + UI_MONEY_BOX_TEMPLATE_ROW * SCREEN_TILES_W + UI_MONEY_BOX_TEMPLATE_COL
    mov bh, 1                                    ; lb bc, 1, 7
    mov bl, 7
    call TextBoxBorder                           ; call TextBoxBorder
    call UpdateSprites                           ; call UpdateSprites
    mov esi, wTileMap + UI_MONEY_BOX_TEMPLATE_ROW * SCREEN_TILES_W + UI_MONEY_BOX_TEMPLATE_COL + 1
    mov eax, PrizeCoinString                     ; ld de, .CoinString
    call PlaceString                             ; call PlaceString
    mov esi, wTileMap + (UI_MONEY_BOX_TEMPLATE_ROW + 1) * SCREEN_TILES_W + UI_MONEY_BOX_TEMPLATE_COL + 2
    mov eax, PrizeSixSpacesString                ; ld de, .SixSpacesString
    call PlaceString                             ; call PlaceString
    mov esi, wTileMap + (UI_MONEY_BOX_TEMPLATE_ROW + 1) * SCREEN_TILES_W + UI_MONEY_BOX_TEMPLATE_COL + 2
    mov edx, wPlayerCoins                        ; ld de, wPlayerCoins
    mov bl, 2 | LEADING_ZEROES                   ; ld c, 2 | LEADING_ZEROES
    call PrintBCDNumber                          ; call PrintBCDNumber
    pop dword [text_row_stride]
    call prize_show_coin_window                  ; mirror + idempotent publish (mart class)
    ret

; ---------------------------------------------------------------------------
; LoadCoinsToSubtract — pret engine/events/prize_menu.asm:LoadCoinsToSubtract
; ---------------------------------------------------------------------------
LoadCoinsToSubtract:
    movzx eax, byte [ebp + wWhichPrize]          ; ld a, [wWhichPrize]
    shl eax, 1                                   ; add a
    lea esi, [ebp + wPrize1Price + eax]          ; ld hl, wPrize1Price / add hl, de ; get selected prize's price
    xor al, al                                   ; xor a
    mov [ebp + hUnusedCoinsByte], al             ; ldh [hUnusedCoinsByte], a
    mov al, [esi]                                ; ld a, [hli]
    inc esi
    mov [ebp + hCoins], al                       ; ldh [hCoins], a
    mov al, [esi]                                ; ld a, [hl]
    mov [ebp + hCoins + 1], al                   ; ldh [hCoins + 1], a
    ret

; ---------------------------------------------------------------------------
; HandlePrizeChoice — pret engine/events/prize_menu.asm:HandlePrizeChoice
; ---------------------------------------------------------------------------
HandlePrizeChoice:
    mov al, [ebp + wCurrentMenuItem]             ; ld a, [wCurrentMenuItem]
    mov [ebp + wWhichPrize], al                  ; ld [wWhichPrize], a
    movzx edx, al                                ; ld d, 0 / ld e, a
    lea esi, [ebp + wPrize1 + edx]               ; ld hl, wPrize1 / add hl, de
    mov al, [esi]                                ; ld a, [hl]
    mov [ebp + wNamedObjectIndex], al            ; ld [wNamedObjectIndex], a
    mov al, [ebp + wWhichPrizeWindow]            ; ld a, [wWhichPrizeWindow]
    cmp al, 2                                    ; cp 2 ; is prize a TM?
    jnz .getMonName                              ; jr nz, .getMonName
    call GetItemName                             ; call GetItemName
    jmp .givePrize                               ; jr .givePrize
.getMonName:
    call GetMonName                              ; call GetMonName
.givePrize:
    mov esi, SoYouWantPrizeText                  ; ld hl, SoYouWantPrizeText
    call PrintText                               ; call PrintText
    call YesNoChoice                             ; call YesNoChoice
    ; Spec: coin + menu persist through the confirm. Re-establish both windows
    ; after the YES/NO box (its scratch/staging overlaps canvas rows 0-3) —
    ; idempotent when undisturbed. GetPrizeMenuId rewrites wNamedObjectIndex
    ; (last: wPrize3), which HandlePrizeChoice set pre-confirm and reads below,
    ; so save/restore it across the redraw.
    mov al, [ebp + wNamedObjectIndex]
    push eax
    call PrintPrizePrice
    push dword [text_row_stride]
    mov dword [text_row_stride], SCREEN_TILES_W
    hlcoord 0, 2
    mov bh, 8
    mov bl, 16
    call TextBoxBorder
    call GetPrizeMenuId
    pop dword [text_row_stride]
    call prize_show_menu_window
    pop eax
    mov [ebp + wNamedObjectIndex], al
    mov al, [ebp + wCurrentMenuItem]             ; ld a, [wCurrentMenuItem] ; yes/no answer (Y=0, N=1)
    and al, al                                   ; and a
    jnz .printOhFineThen                         ; jr nz, .printOhFineThen
    call LoadCoinsToSubtract                     ; call LoadCoinsToSubtract
    call HasEnoughCoins                          ; call HasEnoughCoins
    jc .notEnoughCoins                           ; jr c, .notEnoughCoins
    mov al, [ebp + wWhichPrizeWindow]            ; ld a, [wWhichPrizeWindow]
    cmp al, 2                                    ; cp 2 ; is prize a TM?
    jnz .giveMon                                 ; jr nz, .giveMon
    mov bh, [ebp + wNamedObjectIndex]            ; ld a, [wNamedObjectIndex] / ld b, a
    mov bl, 1                                    ; ld a, 1 / ld c, a
    call GiveItem                                ; call GiveItem
    jnc .bagFull                                 ; jr nc, .bagFull
    jmp .subtractCoins                           ; jr .subtractCoins

.giveMon:
    mov al, [ebp + wNamedObjectIndex]            ; ld a, [wNamedObjectIndex]
    mov [ebp + wCurPartySpecies], al             ; ld [wCurPartySpecies], a
    push eax                                     ; push af
    call GetPrizeMonLevel                        ; call GetPrizeMonLevel
    mov bl, al                                   ; ld c, a
    pop eax                                      ; pop af
    mov bh, al                                   ; ld b, a
    call GivePokemon                             ; call GivePokemon

; If either the party or box was full, wait after displaying message.
    pushf                                        ; push af
    mov al, [ebp + wAddedToParty]                ; ld a, [wAddedToParty]
    and al, al                                   ; and a
    jnz .skipWait                                ; jr nz, ... / call z, WaitForTextScrollButtonPress
    call WaitForTextScrollButtonPress
.skipWait:
    popf                                         ; pop af

; If the mon couldn't be given to the player (because both the party and box
; were full), return without subtracting coins.
    jnc .giveMonFailed                           ; ret nc

; Spec: coin + menu persist through naming. DisplayNamingScreen resets the
; window list for its takeover, so re-establish both windows after GivePokemon
; returns (declined naming never enters it; completed naming returns here).
; Placed after the carry is consumed — the restores clobber flags. GetPrizeMenuId
; rewrites wNamedObjectIndex (last: wPrize3); nothing below reads it, but restore
; it anyway so the redraw stays side-effect-free like the post-confirm one.
; Naming also leaves g_bg_whiteout set with no in-file clear; drop it here so the
; map shows behind the re-established windows (harmless no-op when naming ran).
    mov dword [g_bg_whiteout], 0
    mov al, [ebp + wNamedObjectIndex]
    push eax
    call PrintPrizePrice
    push dword [text_row_stride]
    mov dword [text_row_stride], SCREEN_TILES_W
    hlcoord 0, 2
    mov bh, 8
    mov bl, 16
    call TextBoxBorder
    call GetPrizeMenuId
    pop dword [text_row_stride]
    call prize_show_menu_window
    pop eax
    mov [ebp + wNamedObjectIndex], al

.subtractCoins:
    call LoadCoinsToSubtract                     ; call LoadCoinsToSubtract
    mov esi, hCoins + 1                          ; ld hl, hCoins + 1
    mov edx, wPlayerCoins + 1                    ; ld de, wPlayerCoins + 1
    mov cl, 0x02                                 ; ld c, $02 ; how many bytes
; DEVIATION{class=HAL; pret=engine/events/prize_menu.asm:HandlePrizeChoice; behavior=calls SubBCD directly where pret runs predef SubBCDPredef; evidence=SubBCDPredef in the port is GetPredefRegisters falling through to SubBCD and the port has no predef dispatcher staging wPredefHL-DE-BC for this site so GetPredefRegisters would load stale registers over the live ones, the same convention AddBCD and vending_machine already use; lifetime=permanent, the port calls predef targets directly}
    call SubBCD                                  ; predef SubBCDPredef
    jmp PrintPrizePrice                          ; jp PrintPrizePrice

.giveMonFailed:
    ret

.bagFull:
    mov esi, PrizeRoomBagIsFullText              ; ld hl, PrizeRoomBagIsFullText
    jmp PrintText                                ; jp PrintText

.notEnoughCoins:
    mov esi, SorryNeedMoreCoinsText              ; ld hl, SorryNeedMoreCoinsText
    jmp PrintText                                ; jp PrintText

.printOhFineThen:
    mov esi, OhFineThenText                      ; ld hl, OhFineThenText
    jmp PrintText                                ; jp PrintText

; ---------------------------------------------------------------------------
; UnknownPrizeData — pret engine/events/prize_menu.asm:UnknownPrizeData
; ---------------------------------------------------------------------------
UnknownPrizeData:
    db 0x00, 0x01, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x01

; ---------------------------------------------------------------------------
; GetPrizeMonLevel — pret engine/events/prize_menu.asm:GetPrizeMonLevel
; ---------------------------------------------------------------------------
GetPrizeMonLevel:
    mov bh, [ebp + wCurPartySpecies]             ; ld a, [wCurPartySpecies] / ld b, a
    mov esi, PrizeMonLevelDictionary             ; ld hl, PrizeMonLevelDictionary
.loop:
    mov al, [esi]                                ; ld a, [hli]
    inc esi
    cmp al, bh                                   ; cp b
    jz .matchFound                               ; jr z, .matchFound
    inc esi                                      ; inc hl
    jmp .loop                                    ; jr .loop
.matchFound:
    mov al, [esi]                                ; ld a, [hl]
    mov [ebp + wCurEnemyLevel], al               ; ld [wCurEnemyLevel], a
    ret

; ---------------------------------------------------------------------------
; Prize window mirrors — port-only presentation, mart class (10850fd95).
; Copy the stride-40 canvas box rows into GB_TILEMAP0 source rows and publish
; them as window descriptors (idempotent: re-mirror when already published).
; Teardown is prize_drop_windows at .noChoice; CloseTextDisplay's hide_window
; (src/home/text_script.asm) remains the final backstop.
; ---------------------------------------------------------------------------
prize_coin_mirror:
    pushad
    xor ebx, ebx
.coin_row:
    mov esi, ebx
    imul esi, esi, SCREEN_TILES_W
    add esi, wTileMap + UI_MONEY_BOX_TEMPLATE_ROW * SCREEN_TILES_W + UI_MONEY_BOX_TEMPLATE_COL
    add esi, ebp
    mov edi, ebx
    shl edi, 5
    lea edi, [ebp + edi + GB_TILEMAP0 + PRIZE_COIN_SROW * 32]
    mov ecx, UI_MONEY_BOX_TEMPLATE_GBW
    rep movsb
    inc ebx
    cmp ebx, UI_MONEY_BOX_TEMPLATE_GBH
    jb .coin_row
    popad
    ret

prize_menu_mirror:
    pushad
    xor ebx, ebx
.menu_row:
    mov esi, ebx
    imul esi, esi, SCREEN_TILES_W
    add esi, wTileMap + 2 * SCREEN_TILES_W + 0
    add esi, ebp
    mov edi, ebx
    shl edi, 5
    lea edi, [ebp + edi + GB_TILEMAP0 + PRIZE_MENU_SROW * 32]
    mov ecx, 18
    rep movsb
    inc ebx
    cmp ebx, 10
    jb .menu_row
    popad
    ret

prize_show_coin_window:
    pushad
    mov ecx, [g_window_count]
    xor ebx, ebx
.coin_check:
    cmp ebx, ecx
    jge .coin_notfound
    imul eax, ebx, WIN_DESC_SIZE
    mov edx, [g_windows + eax + WIN_START_ROW]
    cmp edx, PRIZE_COIN_SROW
    je .coin_found
    inc ebx
    jmp .coin_check
.coin_found:
    call prize_coin_mirror
    popad
    ret
.coin_notfound:
    popad
    call prize_coin_mirror
    mov eax, UI_MONEY_BOX_TEMPLATE_WX
    mov ebx, UI_MONEY_BOX_TEMPLATE_WY
    mov ecx, UI_MONEY_BOX_TEMPLATE_CLIP
    mov edx, UI_MONEY_BOX_TEMPLATE_MAXY
    mov esi, GB_TILEMAP0
    mov edi, PRIZE_COIN_SROW
    call add_window
    ret

prize_show_menu_window:
    pushad
    mov ecx, [g_window_count]
    xor ebx, ebx
.menu_check:
    cmp ebx, ecx
    jge .menu_notfound
    imul eax, ebx, WIN_DESC_SIZE
    mov edx, [g_windows + eax + WIN_START_ROW]
    cmp edx, PRIZE_MENU_SROW
    je .menu_found
    inc ebx
    jmp .menu_check
.menu_found:
    call prize_menu_mirror
    popad
    ret
.menu_notfound:
    popad
    call prize_menu_mirror
    mov eax, PRIZE_MENU_WX
    mov ebx, PRIZE_MENU_WY
    mov ecx, PRIZE_MENU_CLIP
    mov edx, PRIZE_MENU_MAXY
    mov esi, GB_TILEMAP0
    mov edi, PRIZE_MENU_SROW
    call add_window
    ret

; ---------------------------------------------------------------------------
; prize_drop_windows — port-only presentation: remove exactly the two prize
; window descriptors (coin srow 20, menu srow 1), compacting the list.
; Template: list_drop_qty_window (src/home/list_menu.asm) — same scan by
; WIN_START_ROW, shift-down removal. Called at .noChoice (teardown-after-naming
; spec); CloseTextDisplay's hide_window remains the final backstop.
; All registers preserved.
; ---------------------------------------------------------------------------
prize_drop_windows:
    pushad
    mov ebx, PRIZE_COIN_SROW
    call .drop_one
    mov ebx, PRIZE_MENU_SROW
    call .drop_one
    popad
    ret
.drop_one:
    ; In: EBX = srow to remove.
    mov ecx, [g_window_count]
    test ecx, ecx
    jz .done
    push ebx
    xor ebx, ebx
.scan:
    cmp ebx, ecx
    jge .notfound
    imul eax, ebx, WIN_DESC_SIZE
    mov edx, [g_windows + eax + WIN_START_ROW]
    cmp edx, [esp]
    je .found
    inc ebx
    jmp .scan
.found:
    mov edi, ebx
    imul edi, edi, WIN_DESC_SIZE
    add edi, g_windows
.shift_loop:
    inc ebx
    cmp ebx, ecx
    jge .shifted
    mov esi, ebx
    imul esi, esi, WIN_DESC_SIZE
    add esi, g_windows
    push ecx
    mov ecx, WIN_DESC_SIZE / 4
    rep movsd
    pop ecx
    jmp .shift_loop
.shifted:
    dec dword [g_window_count]
.notfound:
    pop ebx
.done:
    ret

; ---------------------------------------------------------------------------
; Text and string assets — Tier 1 generated data
; ---------------------------------------------------------------------------
%include "assets/prize_menu_text.inc"
