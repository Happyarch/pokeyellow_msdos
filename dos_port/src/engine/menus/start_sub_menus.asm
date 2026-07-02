; start_sub_menus.asm — StartMenu_* dispatch targets (menus-port Session 4).
; Faithful port of pret engine/menus/start_sub_menus.asm — Session-4 scope is
; StartMenu_Item + ItemMenuLoop (the bag, realigned onto the generic
; DisplayListMenuID / DisplayTextBoxID / swap_items drivers, replacing the
; bespoke bag_menu.asm). The remaining StartMenu_* entries are thin seams:
;   StartMenu_Pokemon      — bespoke party_menu.asm seam (S5 realigns it)
;   StartMenu_Pokedex      — STUB(S6/S8: pokedex package)
;   StartMenu_TrainerInfo  — STUB(S6: draw_badges package / S9 trainer card)
;   StartMenu_SaveReset    — STUB(S7: save package)
;   StartMenu_Option       — STUB(S6: options package)
; Session 9 replaces the stubs when it wires all packages (see
; docs/current_plan_menus.md); each stub returns to RedisplayStartMenu, which
; is also pret's no-op-path behavior.
;
; USE/TOSS sub-menu rendering: pret draws it with DisplayTextBoxID
; (USE_TOSS_MENU_TEMPLATE) — the S2 canvas dispatcher, which lands the box at
; the UI_*-projected 40-wide W_TILEMAP coords. In the overworld the canvas is
; not the screen, so ut_show_window bridges the box rect to a window
; descriptor over the live map (same mechanism as every other overworld box).
;
; Register map (CLAUDE.md): A=AL, BC=BX, DE=DX, HL=ESI, EBP = GB base.
;
; Build (standalone check):
;   nasm -f coff -I include/ -I . -o /dev/null src/engine/menus/start_sub_menus.asm
; ---------------------------------------------------------------------------
bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

%define UI_LAYOUT_EQUATES_ONLY 1
%include "assets/ui_layout_menus.inc"

global StartMenu_Pokedex
global StartMenu_Pokemon
global StartMenu_Item
global StartMenu_TrainerInfo
global StartMenu_SaveReset
global StartMenu_Option
global ItemMenuLoop

extern RedisplayStartMenu            ; home/start_menu.asm
extern CloseStartMenu
extern DisplayPartyMenu              ; engine/menus/party_menu.asm (S5 seam)
extern DisplayListMenuID             ; home/list_menu.asm
extern DisplayChooseQuantityMenu
extern list_mirror                   ; home/list_menu.asm — refresh the list window
extern DisplayTextBoxID              ; home/textbox.asm
extern HandleMenuInput               ; home/window.asm
extern PlaceUnfilledArrowMenuCursor
extern GetItemName                   ; home/names.asm — [wNamedObjectIndex] → wNameBuffer
extern CopyToStringBuffer            ; engine/battle/core.asm — EDX=src → wStringBuffer
extern TossItem                      ; home/item.asm — ESI=inventory; CF=1 not tossed
extern add_window                    ; ppu/ppu.asm
extern g_window_count
extern text_row_stride               ; text/text.asm
extern menu_item_step                ; home/window.asm
extern menu_redraw_cb
extern IsKeyItem                     ; home/item_predicates.asm — [wCurItem] → [wIsKeyItem]
extern IsItemHM                      ; home/item_predicates.asm — AL=item id → CF

; --- USE/TOSS box geometry (frozen layout; pret GB(13,10) 7x5, text (15,11)) ---
; ; PROJ menus: GB(13,10) 7x5 --(anchor=right/top, X+20, Y+0)--> wx=271 wy=80
;   clip=56 max_y=120 [UI_USE_TOSS_MENU_TEMPLATE_*]
UT_COL   equ UI_USE_TOSS_MENU_TEMPLATE_COL
UT_ROW   equ UI_USE_TOSS_MENU_TEMPLATE_ROW
UT_W     equ UI_USE_TOSS_MENU_TEMPLATE_X2 - UI_USE_TOSS_MENU_TEMPLATE_COL + 1
UT_H     equ UI_USE_TOSS_MENU_TEMPLATE_Y2 - UI_USE_TOSS_MENU_TEMPLATE_ROW + 1
UT_SROW  equ 21                      ; GB_TILEMAP0 mirror rows 21-25 (list 0-10,
                                     ; qty 12-14, yes/no 16-20 — all distinct)

TILE_SPC equ 0x7F                    ; blank space tile (charmap)

section .text

; ---------------------------------------------------------------------------
; StartMenu_Pokedex — pret ref: start_sub_menus.asm:StartMenu_Pokedex.
; STUB(S6/S8): predef ShowPokedexMenu + screen restore land with the pokédex
; package; until then the entry is a no-op back to the menu.
; ---------------------------------------------------------------------------
StartMenu_Pokedex:
    jmp RedisplayStartMenu

; ---------------------------------------------------------------------------
; StartMenu_Pokemon — pret ref: start_sub_menus.asm:StartMenu_Pokemon.
; S5 seam: the party-count guard is pret's; the body dispatches to the bespoke
; DisplayPartyMenu (its own loop) and redraws the START menu on return.
; STUB(S5): field-move pop-up / SWITCH / STATS routing (pret .checkIfPokemonChosen
; onward) is Session-5 scope — party_menu.asm currently owns an equivalent.
; ---------------------------------------------------------------------------
StartMenu_Pokemon:
    mov al, [ebp + wPartyCount]
    test al, al                         ; and a
    jz RedisplayStartMenu               ; empty party → straight back
    call DisplayPartyMenu
    jmp RedisplayStartMenu

; ---------------------------------------------------------------------------
; StartMenu_TrainerInfo / StartMenu_SaveReset / StartMenu_Option — STUBs.
; ---------------------------------------------------------------------------
StartMenu_TrainerInfo:                  ; STUB(S6/S9): trainer card (DrawTrainerInfo/DrawBadges)
    jmp RedisplayStartMenu
StartMenu_SaveReset:                    ; STUB(S7): SaveMenu → real .dsv write (dsv_io)
    jmp RedisplayStartMenu
StartMenu_Option:                       ; STUB(S6): DisplayOptionMenu package
    jmp RedisplayStartMenu

; ---------------------------------------------------------------------------
; ItemMenuLoop — pret ref: start_sub_menus.asm:ItemMenuLoop.
; pret: LoadScreenTilesFromBuffer2DisableBGTransfer + RunDefaultPaletteCommand,
; then falls into StartMenu_Item. Port: the screen-buffer restore is subsumed
; by DisplayListMenuID's full redraw (window model — the stale sub-boxes are
; dropped when it resets the window list); the palette command is a GB CGB
; concern (TODO-HW: palettes are Phase 5).
; ---------------------------------------------------------------------------
ItemMenuLoop:
    ; fall through to StartMenu_Item

; ---------------------------------------------------------------------------
; StartMenu_Item — pret ref: start_sub_menus.asm:StartMenu_Item.
; The bag: DisplayListMenuID(ITEMLISTMENU) over wNumBagItems, then the
; USE/TOSS box for the chosen item. USE is a tagged stub (items-plan scope);
; TOSS runs the faithful chain (quantity → TossItem → yes/no → remove).
; ---------------------------------------------------------------------------
StartMenu_Item:
    mov al, [ebp + wLinkState]
    dec al                              ; LINK_STATE_IN_CABLE_CLUB?
    jnz .notInCableClubRoom
    ; STUB(text): CannotUseItemsHereText — link play not ported (S8/I1); the
    ; guard branch is kept, the message is not shown. pret prints then exits.
    jmp .exitMenu
.notInCableClubRoom:
    ; store the bag pointer in wListPointer (for DisplayListMenuID)
    mov word [ebp + wListPointer], wNumBagItems
    xor al, al
    mov [ebp + wPrintItemPrices], al
    mov al, ITEMLISTMENU
    mov [ebp + wListMenuID], al
    mov al, [ebp + wBagSavedMenuItem]
    mov [ebp + wCurrentMenuItem], al
    call DisplayListMenuID
    mov al, [ebp + wCurrentMenuItem]
    mov [ebp + wBagSavedMenuItem], al
    jnc .choseItem
.exitMenu:
    ; pret: LoadScreenTilesFromBuffer2 / LoadTextBoxTilePatterns / UpdateSprites
    ; — the START menu redraw (RedisplayStartMenu → DrawStartMenu) rebuilds the
    ; window list and box; no separate restore needed in the window model.
    jmp RedisplayStartMenu
.choseItem:
    ; erase the list-menu cursor: pret blanks coords (5,4)/(5,6)/(5,8)/(5,10)
    ; = list-box-relative (1,2)/(1,4)/(1,6)/(1,8) in the stride-20 scratch
    mov al, TILE_SPC
    mov [ebp + W_TILEMAP + 2 * 20 + 1], al
    mov [ebp + W_TILEMAP + 4 * 20 + 1], al
    mov [ebp + W_TILEMAP + 6 * 20 + 1], al
    mov [ebp + W_TILEMAP + 8 * 20 + 1], al
    call PlaceUnfilledArrowMenuCursor
    call list_mirror                    ; port: push the edits to the list window
    xor al, al
    mov [ebp + wMenuItemToSwap], al
    mov al, [ebp + wCurItem]
    cmp al, BICYCLE
    je .useOrTossItem                   ; Bicycle: no USE/TOSS box
    ; --- USE/TOSS sub-menu ---
    mov byte [ebp + wTextBoxID], USE_TOSS_MENU_TEMPLATE
    call DisplayTextBoxID               ; canvas box at UI_USE_TOSS_* coords
    call ut_show_window                 ; port: bridge the canvas rect → window
    ; menu vars — pret Y=11 X=14, projected onto the canvas:
    ; PROJ menus: cursor = (UI_USE_TOSS_MENU_TEMPLATE_TX-1, .._TY)
    mov byte [ebp + wTopMenuItemY], UI_USE_TOSS_MENU_TEMPLATE_TY
    mov byte [ebp + wTopMenuItemX], UI_USE_TOSS_MENU_TEMPLATE_TX - 1
    xor al, al
    mov [ebp + wCurrentMenuItem], al
    mov [ebp + wLastMenuItem], al       ; old menu item id
    inc al                              ; a = 1
    mov [ebp + wMaxMenuItem], al
    mov byte [ebp + wMenuWatchedKeys], PAD_A | PAD_B
    ; port: the box lives on the 40-wide canvas for the duration of the input
    mov dword [text_row_stride], SCREEN_TILES_W
    mov dword [menu_item_step], 2 * SCREEN_TILES_W
    mov dword [menu_redraw_cb], ut_mirror
    call HandleMenuInput
    mov dword [menu_redraw_cb], 0
    mov bl, al                          ; keep the pressed keys
    call PlaceUnfilledArrowMenuCursor
    call ut_mirror                      ; final cursor state → window
    mov dword [text_row_stride], 20     ; back to the overworld scratch stride
    test bl, PAD_B                      ; bit B_PAD_B,a
    jz .useOrTossItem
    jmp ItemMenuLoop
.useOrTossItem:
    mov al, [ebp + wCurItem]
    mov [ebp + wNamedObjectIndex], al
    call GetItemName
    mov edx, wNameBuffer
    call CopyToStringBuffer
    mov al, [ebp + wCurItem]
    cmp al, BICYCLE
    jne .notBicycle
    mov al, [ebp + W_STATUS_FLAGS_6]
    test al, (1 << BIT_ALWAYS_ON_BIKE)
    jz .useItem_closeMenu
    ; STUB(text): CannotGetOffHereText — bike riding not ported; the guard
    ; branch is kept (pret prints, then returns to the list).
    jmp ItemMenuLoop
.notBicycle:
    mov al, [ebp + wCurrentMenuItem]
    test al, al                         ; and a
    jnz .tossItem
    ; --- USE ---
    ; STUB(items-plan): item USE dispatch (wPseudoItemID, UsableItems_CloseMenu/
    ; UsableItems_PartyMenu routing, UseItem_/ItemUsePtrTable) is
    ; current_plan_items.md scope. Until it lands, USE takes no action and
    ; returns to the item list (pret runs UseItem here).
    jmp ItemMenuLoop
.useItem_closeMenu:
    ; STUB(items-plan): pret runs UseItem (Bicycle mount) then closes the START
    ; menu on success. With USE stubbed the close still matches pret's
    ; wActionResultOrTookBattleTurn==0 → ItemMenuLoop shape only when the item
    ; "fails"; the Bicycle is unobtainable until the items plan lands, so take
    ; the close path pret takes on success.
    jmp CloseStartMenu
.tossItem:
    call IsKeyItem                      ; [wCurItem] → [wIsKeyItem]
    mov al, [ebp + wIsKeyItem]
    test al, al
    jnz .skipAskingQuantity             ; key item: TossItem_ shows "too important"
    mov al, [ebp + wCurItem]
    call IsItemHM                       ; CF = is HM
    jc .skipAskingQuantity
    call DisplayChooseQuantityMenu      ; appends the qty window; AL=$ff on B
    inc al
    jz .tossZeroItems
.skipAskingQuantity:
    mov esi, wNumBagItems               ; ld hl, wNumBagItems
    call TossItem
.tossZeroItems:
    jmp ItemMenuLoop

; ---------------------------------------------------------------------------
; ut_show_window — append the USE/TOSS window descriptor over the list.
; ut_mirror — blit the canvas rect (UT_COL,UT_ROW) UT_W×UT_H (stride 40) →
; GB_TILEMAP0 rows UT_SROW.., cols 0.. (window source). Registers preserved
; (ut_mirror doubles as menu_redraw_cb).
; ---------------------------------------------------------------------------
ut_show_window:
    call ut_mirror
    mov eax, UI_USE_TOSS_MENU_TEMPLATE_WX
    mov ebx, UI_USE_TOSS_MENU_TEMPLATE_WY
    mov ecx, UI_USE_TOSS_MENU_TEMPLATE_CLIP
    mov edx, UI_USE_TOSS_MENU_TEMPLATE_MAXY
    mov esi, GB_TILEMAP0
    mov edi, UT_SROW
    call add_window                     ; [list] → [list, use/toss]
    ret

ut_mirror:
    pushad
    xor ebx, ebx
.row:
    mov esi, ebx
    imul esi, esi, SCREEN_TILES_W
    lea esi, [ebp + esi + W_TILEMAP + UT_ROW * SCREEN_TILES_W + UT_COL]
    mov edi, ebx
    shl edi, 5
    lea edi, [ebp + edi + GB_TILEMAP0 + UT_SROW * 32]
    mov ecx, UT_W
    rep movsb
    inc ebx
    cmp ebx, UT_H
    jb .row
    popad
    ret
