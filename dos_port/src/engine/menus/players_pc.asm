; players_pc.asm — the player's-PC "ITEM STORAGE" menu (menus-port Session 6,
; package F). Faithful port of pret engine/menus/players_pc.asm.
;
; This is the FLAGSHIP second caller of the generic list driver
; DisplayListMenuID (home/list_menu.asm) after the bag — the point of the
; package is to prove the driver generalizes to a second inventory (the PC
; item box, wNumBoxItems). The parent 4-entry menu (WITHDRAW/DEPOSIT/TOSS/LOG
; OFF) drives three item flows:
;   PlayerPCDeposit  — bag → box (AddItemToInventory box / RemoveItemFromInventory bag)
;   PlayerPCWithdraw — box → bag (the mirror)
;   PlayerPCToss     — TossItem out of the box (the S4 toss chain, verbatim)
;
; PORT MODEL (CLAUDE.md + translation_log "menus-port Session 2/3/4/5"):
;  * SM83→x86: A=AL, BC=BX, DE=DX, HL=ESI, EBP = GB base; GB memory at [EBP+sym].
;  * The parent menu box is drawn box-relative into the stride-20 W_TILEMAP
;    scratch (same model as the bag list box), mirrored to GB_TILEMAP0, and
;    exposed as a window at the frozen UI_PLAYERS_PC_MENU_* anchor. A per-frame
;    pc_menu_mirror (menu_redraw_cb) re-blits it so HandleMenuInput's live ▶
;    cursor reaches the compositor (yes_no/list_mirror mechanism).
;  * DisplayListMenuID owns the list window (GB_TILEMAP0, its own hide_window);
;    the deposit/withdraw/toss lists just point wListPointer at wNumBagItems /
;    wNumBoxItems and set ITEMLISTMENU, exactly like the bag.
;  * Dialog text: pret prints each message with PrintText. The dialog projection
;    collapses the window list to the dialog alone (would hide the menu/list),
;    so — as in S4/S5 — the messages are DRAWN WHOLE into the stride-20 scratch
;    (rows 12-17) + a GB_TILEMAP1 window at UI_MESSAGE_BOX, with the pret wording
;    (data/text/text_3.asm) and the `prompt` terminal reproduced as a ▼ + A/B
;    wait. DEVIATION(text): the "done" prompts that precede a list do not persist
;    beneath it (DisplayListMenuID's hide_window resets the window list), where
;    the GB leaves the bottom text box on screen under the top list.
;  * PlaySound / WaitForSoundToFinish (SFX_TURN_ON/OFF_PC, SFX_WITHDRAW_DEPOSIT)
;    are ; TODO-HW: audio HAL (Phase 3) — no-ops (no return-contract impact).
;
; Callers (overworld PC script objects + pc.asm) are Session 9 — this file just
; exports PlayerPC.
;
; Build (standalone check):
;   nasm -f coff -I include/ -I . -o /dev/null src/engine/menus/players_pc.asm
; ---------------------------------------------------------------------------
bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

%define UI_LAYOUT_EQUATES_ONLY 1
%include "assets/ui_layout_menus.inc"

global PlayerPC
global PlayerPCMenu
global ExitPlayerPC
global PlayerPCDeposit
global PlayerPCWithdraw
global PlayerPCToss

extern DisplayListMenuID             ; home/list_menu.asm
extern DisplayChooseQuantityMenu     ; home/list_menu.asm
extern TextBoxBorder                 ; text/text.asm — ESI=top-left, BL=int_w, BH=int_h
extern PlaceString                   ; text/text.asm — ESI=dest, EAX=flat src
extern place_flat_str                ; text/text.asm — ESI=dest, EAX=flat '@'-term src
extern HandleMenuInput               ; home/window.asm — Out: AL = watched keys pressed
extern PlaceMenuCursor               ; home/window.asm
extern PlaceUnfilledArrowMenuCursor  ; home/window.asm
extern UpdateSprites                 ; engine/overworld/movement.asm
extern RefreshCollisionTileMap       ; engine/overworld/overworld.asm
extern AddItemToInventory            ; engine/items/inventory.asm — ESI=count addr; CF=1 room
extern RemoveItemFromInventory       ; engine/items/inventory.asm
extern IsKeyItem                     ; home/item_predicates.asm — [wCurItem] → [wIsKeyItem]
extern IsItemHM                      ; home/item_predicates.asm — AL=item id → CF
extern TossItem                      ; home/item.asm — ESI=inventory; CF=1 not tossed
extern DelayFrame                    ; video/frame.asm
extern hide_window                   ; ppu/ppu.asm
extern add_window                    ; ppu/ppu.asm — EAX=wx EBX=wy ECX=clip EDX=max_y ESI=tm EDI=row
extern g_window_count                ; ppu/ppu.asm
extern text_row_stride               ; text/text.asm — active W_TILEMAP row stride
extern menu_item_step                ; home/window.asm — per-item cursor row step
extern menu_redraw_cb                ; home/window.asm — per-frame redraw cb (0=none)

%ifdef DEBUG_PLAYERSPC
extern PrepareNewGameDebug           ; engine/debug/debug_party.asm
extern LoadFontTilePatterns          ; gfx/load_font.asm
extern DumpBackbuffer                ; debug/debug_dump.asm
global RunPlayersPCTest
%endif

; wParentMenuItem (0xCCD3), BIT_USING_GENERIC_PC (3), BIT_NO_MENU_BUTTON_SOUND (5)
; are now root-promoted into gb_memmap.inc (all sym-verified).

; --- parent PC-menu box geometry (frozen layout) ---
; ; PROJ menus: GB(0,0) 16x10 --(anchor=center/top, X+10, Y+0)--> wx=87 wy=0
;   clip=128 max_y=80 [UI_PLAYERS_PC_MENU_*]; pret hlcoord 0,0 / lb bc,8,14 =
;   a 14x8-interior (16x10 total) border.
PPC_INT_W   equ 14                   ; TextBoxBorder interior width  (pret c)
PPC_INT_H   equ 8                    ; TextBoxBorder interior height (pret b)
PPC_TOTAL_W equ UI_PLAYERS_PC_MENU_X2 - UI_PLAYERS_PC_MENU_COL + 1   ; 16
PPC_TOTAL_H equ UI_PLAYERS_PC_MENU_Y2 - UI_PLAYERS_PC_MENU_ROW + 1   ; 10
PPC_STRIDE  equ 20                   ; box-relative scratch stride (NOT port SCREEN_WIDTH=40)
PPC_SROW    equ 0                    ; GB_TILEMAP0 mirror start row (list reuses 0-10 later)

; --- drawn-whole message box (rows 12-17 scratch → GB_TILEMAP1 rows 0-5) ---
MSG_SROW    equ 12                   ; first scratch row of the message border

; charmap glyphs
CHAR_TERM   equ 0x50                 ; '@'
CHAR_DOT    equ 0xE8                 ; .
CHAR_QUEST  equ 0xE6                 ; ?
CHAR_DOWN   equ 0xEE                 ; ▼
TILE_SPC    equ 0x7F                 ; blank space tile

; ===========================================================================
section .data
align 4
; pret ref: engine/menus/players_pc.asm:PlayersPCMenuEntries — one string with
; <NEXT> ($4E) separators (double-spaced: rows 2,4,6,8).
PlayersPCMenuEntries:
    db 0x96,0x88,0x93,0x87,0x83,0x91,0x80,0x96,0x7F,0x88,0x93,0x84,0x8C   ; "WITHDRAW ITEM"
    db 0x4E
    db 0x83,0x84,0x8F,0x8E,0x92,0x88,0x93,0x7F,0x88,0x93,0x84,0x8C        ; "DEPOSIT ITEM"
    db 0x4E
    db 0x93,0x8E,0x92,0x92,0x7F,0x88,0x93,0x84,0x8C                       ; "TOSS ITEM"
    db 0x4E
    db 0x8B,0x8E,0x86,0x7F,0x8E,0x85,0x85, CHAR_TERM                      ; "LOG OFF@"

; Message lines (pret data/text/text_3.asm wording, GB charmap; '@'-terminated).
s_turnedon:      db 0x7F,0xB3,0xB4,0xB1,0xAD,0xA4,0xA3,0x7F,0xAE,0xAD, CHAR_TERM        ; " turned on"
s_thepc:         db 0xB3,0xA7,0xA4,0x7F,0x8F,0x82,0xE8, CHAR_TERM                       ; "the PC."
s_whatdo:        db 0x96,0xA7,0xA0,0xB3,0x7F,0xA3,0xAE,0x7F,0xB8,0xAE,0xB4,0x7F,0xB6,0xA0,0xAD,0xB3, CHAR_TERM   ; "What do you want"
s_todo:          db 0xB3,0xAE,0x7F,0xA3,0xAE, CHAR_QUEST, CHAR_TERM                     ; "to do?"
s_todeposit_q:   db 0xB3,0xAE,0x7F,0xA3,0xA4,0xAF,0xAE,0xB2,0xA8,0xB3, CHAR_QUEST, CHAR_TERM   ; "to deposit?"
s_howmany:       db 0x87,0xAE,0xB6,0x7F,0xAC,0xA0,0xAD,0xB8, CHAR_QUEST, CHAR_TERM      ; "How many?"
s_was:           db 0x7F,0xB6,0xA0,0xB2, CHAR_TERM                                      ; " was"
s_storedvia:     db 0xB2,0xB3,0xAE,0xB1,0xA4,0xA3,0x7F,0xB5,0xA8,0xA0,0x7F,0x8F,0x82,0xE8, CHAR_TERM   ; "stored via PC."
s_youhavenothing:db 0x98,0xAE,0xB4,0x7F,0xA7,0xA0,0xB5,0xA4,0x7F,0xAD,0xAE,0xB3,0xA7,0xA8,0xAD,0xA6, CHAR_TERM ; "You have nothing"
s_todeposit_d:   db 0xB3,0xAE,0x7F,0xA3,0xA4,0xAF,0xAE,0xB2,0xA8,0xB3,0xE8, CHAR_TERM   ; "to deposit."
s_noroomleft:    db 0x8D,0xAE,0x7F,0xB1,0xAE,0xAE,0xAC,0x7F,0xAB,0xA4,0xA5,0xB3,0x7F,0xB3,0xAE, CHAR_TERM   ; "No room left to"
s_storeitems:    db 0xB2,0xB3,0xAE,0xB1,0xA4,0x7F,0xA8,0xB3,0xA4,0xAC,0xB2,0xE8, CHAR_TERM   ; "store items."
s_towithdraw_q:  db 0xB3,0xAE,0x7F,0xB6,0xA8,0xB3,0xA7,0xA3,0xB1,0xA0,0xB6, CHAR_QUEST, CHAR_TERM   ; "to withdraw?"
s_withdrew:      db 0x96,0xA8,0xB3,0xA7,0xA3,0xB1,0xA4,0xB6, CHAR_TERM                  ; "Withdrew"
s_thereisnothing:db 0x93,0xA7,0xA4,0xB1,0xA4,0x7F,0xA8,0xB2,0x7F,0xAD,0xAE,0xB3,0xA7,0xA8,0xAD,0xA6, CHAR_TERM ; "There is nothing"
s_stored_d:      db 0xB2,0xB3,0xAE,0xB1,0xA4,0xA3,0xE8, CHAR_TERM                       ; "stored."
s_youcantcarry:  db 0x98,0xAE,0xB4,0x7F,0xA2,0xA0,0xAD,0xBE,0x7F,0xA2,0xA0,0xB1,0xB1,0xB8, CHAR_TERM   ; "You can't carry"
s_anymoreitems:  db 0xA0,0xAD,0xB8,0x7F,0xAC,0xAE,0xB1,0xA4,0x7F,0xA8,0xB3,0xA4,0xAC,0xB2,0xE8, CHAR_TERM   ; "any more items."
s_totossaway_q:  db 0xB3,0xAE,0x7F,0xB3,0xAE,0xB2,0xB2,0x7F,0xA0,0xB6,0xA0,0xB8, CHAR_QUEST, CHAR_TERM   ; "to toss away?"

section .bss
align 4
msg_saved_wc:    resd 1              ; g_window_count before a message window appended

; ===========================================================================
section .text

; ---------------------------------------------------------------------------
; PlayerPC — pret ref: engine/menus/players_pc.asm:PlayerPC.
; Entry from the overworld PC script (S9). In: EBP = GB base.
; ---------------------------------------------------------------------------
PlayerPC:
    mov byte [ebp + wNameListType], ITEM_NAME
    ; call SaveScreenTilesToBuffer1 — port(window model): the menu is a
    ; non-destructive window overlay; there is no screen to save/restore.
    xor al, al
    mov [ebp + wBagSavedMenuItem], al
    mov [ebp + wParentMenuItem], al
    mov al, [ebp + wMiscFlags]
    test al, (1 << BIT_USING_GENERIC_PC)
    jnz PlayerPCMenu                     ; jr nz — HoF/Bill's PC host: no turn-on FX
    ; accessing it directly
    ; TODO-HW: PlaySound SFX_TURN_ON_PC — audio HAL (Phase 3)
    call PC_TurnedOnPC2Text              ; PrintText TurnedOnPC2Text (drawn whole, prompt)
    ; fall through

; ---------------------------------------------------------------------------
; PlayerPCMenu — pret ref: engine/menus/players_pc.asm:PlayerPCMenu.
; The 4-entry parent menu. Sub-flows `jp PlayerPCMenu` back here for a full
; redraw.
; ---------------------------------------------------------------------------
PlayerPCMenu:
    or byte [ebp + W_STATUS_FLAGS_5], (1 << BIT_NO_TEXT_DELAY)  ; set BIT_NO_TEXT_DELAY
    mov al, [ebp + wParentMenuItem]
    mov [ebp + wCurrentMenuItem], al
    or byte [ebp + wMiscFlags], (1 << BIT_NO_MENU_BUTTON_SOUND)
    ; call LoadScreenTilesFromBuffer2 — port(window model): restore the map
    ; mirror so UpdateSprites' text-box tile check sees map + PC box only
    ; (RedisplayStartMenu precedent), then draw the box over it.
    mov dword [text_row_stride], PPC_STRIDE
    call RefreshCollisionTileMap
    ; hlcoord 0,0 / lb bc,8,14 / TextBoxBorder — box-relative into the scratch
    mov esi, W_TILEMAP
    mov bl, PPC_INT_W
    mov bh, PPC_INT_H
    call TextBoxBorder
    call UpdateSprites
    ; hlcoord 2,2 / PlaceString PlayersPCMenuEntries (double-spaced <NEXT>)
    ; DEVIATION: clear BIT_SINGLE_SPACED_LINES so <NEXT> advances 2 rows (pret
    ; relies on the ambient overworld default; make the render deterministic).
    and byte [ebp + H_UI_LAYOUT_FLAGS], (~(1 << BIT_SINGLE_SPACED_LINES)) & 0xFF
    mov esi, W_TILEMAP + 2 * PPC_STRIDE + 2
    mov eax, PlayersPCMenuEntries
    call PlaceString
    ; menu vars: wTopMenuItemY=2, wTopMenuItemX=1, wMaxMenuItem=3,
    ; wMenuWatchedKeys=A|B, wMenuWatchMovingOutOfBounds=0, wListScrollOffset=0
    mov byte [ebp + wTopMenuItemY], 2
    mov byte [ebp + wTopMenuItemX], 1        ; pret dec a (2 → 1)
    mov byte [ebp + wMaxMenuItem], 3
    mov byte [ebp + wMenuWatchedKeys], PAD_A | PAD_B
    xor al, al
    mov [ebp + wLastMenuItem], al             ; pret: ld [hl],a after wMenuWatchedKeys
    mov [ebp + wListScrollOffset], al
    mov [ebp + wMenuWatchMovingOutOfBounds], al
    mov [ebp + wPlayerMonNumber], al
    ; port: expose the parent box as window[0], then the "What do you want"
    ; message as window[1] (both visible while HandleMenuInput runs)
    call hide_window
    call pc_menu_show_window
    call PC_WhatDoYouWantText                ; PrintText WhatDoYouWantText (drawn whole, done)
    mov dword [menu_item_step], 2 * PPC_STRIDE
    mov dword [menu_redraw_cb], pc_menu_mirror
%ifdef DEBUG_PLAYERSPC
    ; menus S6 gate: render the parent menu (box + entries + ▶ cursor) for one
    ; frame, dump FRAME.BIN, exit (HandleMenuInput would block headless).
    call PlaceMenuCursor
    call pc_menu_mirror
    call DelayFrame
    call DumpBackbuffer                       ; never returns
%endif
    call HandleMenuInput
    mov dword [menu_redraw_cb], 0
    test al, PAD_B                            ; bit B_PAD_B,a
    jnz ExitPlayerPC                          ; jp nz
    call PlaceUnfilledArrowMenuCursor
    mov al, [ebp + wCurrentMenuItem]
    mov [ebp + wParentMenuItem], al
    test al, al                               ; and a
    jz PlayerPCWithdraw                       ; jp z — item 0 = WITHDRAW
    dec al
    jz PlayerPCDeposit                        ; jp z — item 1 = DEPOSIT
    dec al
    jz PlayerPCToss                           ; jp z — item 2 = TOSS
    ; item 3 = LOG OFF → fall through to ExitPlayerPC

; ---------------------------------------------------------------------------
; ExitPlayerPC — pret ref: engine/menus/players_pc.asm:ExitPlayerPC.
; ---------------------------------------------------------------------------
ExitPlayerPC:
    mov al, [ebp + wMiscFlags]
    test al, (1 << BIT_USING_GENERIC_PC)
    jnz .next                                 ; jr nz
    ; accessing it directly
    ; TODO-HW: PlaySound SFX_TURN_OFF_PC / WaitForSoundToFinish — audio HAL
.next:
    and byte [ebp + wMiscFlags], (~(1 << BIT_NO_MENU_BUTTON_SOUND)) & 0xFF
    ; call LoadScreenTilesFromBuffer2 — port(window model): drop the menu
    ; windows and scrub the box tiles from the collision mirror (CloseStartMenu
    ; precedent, since UpdateSprites ran).
    call hide_window
    call RefreshCollisionTileMap
    xor al, al
    mov [ebp + wListScrollOffset], al         ; restore the bag's saved scroll to 0
    mov [ebp + wBagSavedMenuItem], al
    and byte [ebp + W_STATUS_FLAGS_5], (~(1 << BIT_NO_TEXT_DELAY)) & 0xFF
    xor al, al
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    mov dword [text_row_stride], 20           ; restore the overworld dialog stride
    ret

; ---------------------------------------------------------------------------
; PlayerPCDeposit — pret ref: engine/menus/players_pc.asm:PlayerPCDeposit.
; bag (wNumBagItems) → box (wNumBoxItems).
; ---------------------------------------------------------------------------
PlayerPCDeposit:
    xor al, al
    mov [ebp + wCurrentMenuItem], al
    mov [ebp + wListScrollOffset], al
    mov al, [ebp + wNumBagItems]
    test al, al                               ; and a — empty bag?
    jnz .loop
    call PC_NothingToDepositText              ; PrintText NothingToDepositText (prompt)
    jmp PlayerPCMenu                          ; jp PlayerPCMenu
.loop:
    call PC_WhatToDepositText                 ; PrintText WhatToDepositText (done)
    mov word [ebp + wListPointer], wNumBagItems
    xor al, al
    mov [ebp + wPrintItemPrices], al
    mov al, ITEMLISTMENU
    mov [ebp + wListMenuID], al
    call DisplayListMenuID
    jc PlayerPCMenu                           ; jp c — cancelled
    call IsKeyItem                            ; [wCurItem] → [wIsKeyItem]
    mov byte [ebp + wItemQuantity], 1
    mov al, [ebp + wIsKeyItem]
    test al, al
    jnz .next                                 ; jr nz — key items: quantity 1
    ; if it's not a key item, there can be more than one of the item
    call PC_DepositHowManyText                ; PrintText DepositHowManyText (done)
    call DisplayChooseQuantityMenu            ; AL=$ff on B-cancel
    cmp al, 0xff
    jz .loop                                  ; jp z
.next:
    mov esi, wNumBoxItems                     ; ld hl, wNumBoxItems
    call AddItemToInventory                   ; CF=1 → room available
    jc .roomAvailable                         ; jr c
    call PC_NoRoomToStoreText                 ; PrintText NoRoomToStoreText (prompt)
    jmp .loop                                 ; jp .loop
.roomAvailable:
    mov esi, wNumBagItems                     ; ld hl, wNumBagItems
    call RemoveItemFromInventory
    ; TODO-HW: WaitForSoundToFinish / PlaySound SFX_WITHDRAW_DEPOSIT /
    ; WaitForSoundToFinish — audio HAL (Phase 3)
    call PC_ItemWasStoredText                 ; PrintText ItemWasStoredText (prompt)
    jmp .loop                                 ; jp .loop

; ---------------------------------------------------------------------------
; PlayerPCWithdraw — pret ref: engine/menus/players_pc.asm:PlayerPCWithdraw.
; box (wNumBoxItems) → bag (wNumBagItems). The mirror of Deposit.
; ---------------------------------------------------------------------------
PlayerPCWithdraw:
    xor al, al
    mov [ebp + wCurrentMenuItem], al
    mov [ebp + wListScrollOffset], al
    mov al, [ebp + wNumBoxItems]
    test al, al                               ; and a — empty box?
    jnz .loop
    call PC_NothingStoredText                 ; PrintText NothingStoredText (prompt)
    jmp PlayerPCMenu                          ; jp PlayerPCMenu
.loop:
    call PC_WhatToWithdrawText                ; PrintText WhatToWithdrawText (done)
    mov word [ebp + wListPointer], wNumBoxItems
    xor al, al
    mov [ebp + wPrintItemPrices], al
    mov al, ITEMLISTMENU
    mov [ebp + wListMenuID], al
    call DisplayListMenuID
    jc PlayerPCMenu                           ; jp c — cancelled
    call IsKeyItem
    mov byte [ebp + wItemQuantity], 1
    mov al, [ebp + wIsKeyItem]
    test al, al
    jnz .next                                 ; jr nz
    call PC_WithdrawHowManyText               ; PrintText WithdrawHowManyText (done)
    call DisplayChooseQuantityMenu
    cmp al, 0xff
    jz .loop                                  ; jp z
.next:
    mov esi, wNumBagItems                     ; ld hl, wNumBagItems
    call AddItemToInventory
    jc .roomAvailable                         ; jr c
    call PC_CantCarryMoreText                 ; PrintText CantCarryMoreText (prompt)
    jmp .loop                                 ; jp .loop
.roomAvailable:
    mov esi, wNumBoxItems                     ; ld hl, wNumBoxItems
    call RemoveItemFromInventory
    ; TODO-HW: WaitForSoundToFinish / PlaySound SFX_WITHDRAW_DEPOSIT /
    ; WaitForSoundToFinish — audio HAL (Phase 3)
    call PC_WithdrewItemText                  ; PrintText WithdrewItemText (prompt)
    jmp .loop                                 ; jp .loop

; ---------------------------------------------------------------------------
; PlayerPCToss — pret ref: engine/menus/players_pc.asm:PlayerPCToss.
; TossItem out of the box (wNumBoxItems). Reuses the S4 toss chain verbatim.
; ---------------------------------------------------------------------------
PlayerPCToss:
    xor al, al
    mov [ebp + wCurrentMenuItem], al
    mov [ebp + wListScrollOffset], al
    mov al, [ebp + wNumBoxItems]
    test al, al                               ; and a — empty box?
    jnz .loop
    call PC_NothingStoredText                 ; PrintText NothingStoredText (prompt)
    jmp PlayerPCMenu                          ; jp PlayerPCMenu
.loop:
    call PC_WhatToTossText                    ; PrintText WhatToTossText (done)
    mov word [ebp + wListPointer], wNumBoxItems
    xor al, al
    mov [ebp + wPrintItemPrices], al
    mov al, ITEMLISTMENU
    mov [ebp + wListMenuID], al
    ; pret push hl / DisplayListMenuID / pop hl — hl (wNumBoxItems) is a
    ; constant here, so it is simply re-loaded before TossItem below.
    call DisplayListMenuID
    jc PlayerPCMenu                           ; jp c — cancelled
    call IsKeyItem                            ; pret push hl / IsKeyItem / pop hl
    mov byte [ebp + wItemQuantity], 1
    mov al, [ebp + wIsKeyItem]
    test al, al
    jnz .next                                 ; jr nz
    ; pret: ld a,[wCurItem] / call IsItemHM / jr c,.next — HM check is folded
    ; into TossItem_ (it re-runs IsItemHM/IsKeyItem and shows "too important"),
    ; so the quantity prompt is skippable for HMs/key items via TossItem itself.
    ; Faithful to control flow: ask quantity only for a tossable stack.
    mov al, [ebp + wCurItem]
    call IsItemHM                             ; CF = is HM
    jc .next                                  ; jr c — HM: quantity 1, TossItem refuses
    call PC_TossHowManyText                   ; PrintText TossHowManyText (done)
    call DisplayChooseQuantityMenu
    cmp al, 0xff
    jz .loop                                  ; jp z
.next:
    mov esi, wNumBoxItems                     ; ld hl, wNumBoxItems
    call TossItem                             ; disallows tossing key items / HMs
    jmp .loop                                 ; jp .loop

; ===========================================================================
; Port plumbing — parent PC-menu window (GB_TILEMAP0) + drawn-whole messages
; (GB_TILEMAP1). Neither is a pret routine; both reproduce pret's on-screen
; result under the window compositor.
; ===========================================================================

; pc_menu_show_window — mirror the parent box (scratch rows 0..9) → GB_TILEMAP0
; and append it as a window at the UI_PLAYERS_PC_MENU anchor.
pc_menu_show_window:
    call pc_menu_mirror
    mov eax, UI_PLAYERS_PC_MENU_WX
    mov ebx, UI_PLAYERS_PC_MENU_WY
    mov ecx, UI_PLAYERS_PC_MENU_CLIP
    mov edx, UI_PLAYERS_PC_MENU_MAXY
    mov esi, GB_TILEMAP0
    mov edi, PPC_SROW
    call add_window
    ret

; pc_menu_mirror — blit the box rect (stride-20 scratch, cols 0..15, rows 0..9)
; → GB_TILEMAP0 rows 0.. (stride 32). Preserves all registers (menu_redraw_cb).
pc_menu_mirror:
    pushad
    xor ebx, ebx
.row:
    mov esi, ebx
    imul esi, esi, PPC_STRIDE
    lea esi, [ebp + esi + W_TILEMAP]
    mov edi, ebx
    shl edi, 5                                ; row * 32
    lea edi, [ebp + edi + GB_TILEMAP0 + PPC_SROW * 32]
    mov ecx, PPC_TOTAL_W
    rep movsb
    inc ebx
    cmp ebx, PPC_TOTAL_H
    jb .row
    popad
    ret

; ---------------------------------------------------------------------------
; Message helpers (DEVIATION(text) — see file header). Each PC_*Text draws the
; pret message whole into scratch rows 12-17 (stride 20), mirrors it to
; GB_TILEMAP1 rows 0-5, appends a window at UI_MESSAGE_BOX, and — for the pret
; texts terminated by `prompt` — waits out a ▼ + A/B cycle, then drops the
; window.  The "done"-terminated prompts (What to.../How many?) show and return
; (no wait); their window persists until the next hide_window.
; ---------------------------------------------------------------------------

; draw the empty message border into scratch rows 12-17 (interior 18x4)
pc_msg_box:
    mov esi, W_TILEMAP + MSG_SROW * PPC_STRIDE
    mov bl, 18                                ; interior width  (total 20)
    mov bh, 4                                 ; interior height (total 6)
    call TextBoxBorder
    ret

; mirror scratch rows 12-17 → GB_TILEMAP1 rows 0-5 (pad cols 20-31), append the
; dialog window (remembering g_window_count for pc_msg_drop).
pc_msg_show:
    pushad
    mov ecx, 6
    lea esi, [ebp + W_TILEMAP + MSG_SROW * PPC_STRIDE]
    lea edi, [ebp + GB_TILEMAP1]
.row:
    push ecx
    push edi
    mov ecx, 20
    rep movsb
    mov al, TILE_SPC
    mov ecx, 12                               ; pad cols 20-31
    rep stosb
    pop edi
    pop ecx
    add edi, 32
    dec ecx
    jnz .row
    mov eax, [g_window_count]
    mov [msg_saved_wc], eax
    mov eax, UI_MESSAGE_BOX_WX
    mov ebx, UI_MESSAGE_BOX_WY
    mov ecx, UI_MESSAGE_BOX_CLIP
    mov edx, UI_MESSAGE_BOX_MAXY
    mov esi, GB_TILEMAP1
    xor edi, edi
    call add_window
    popad
    ret

; ▼ + wait for an A/B press cycle (the text's terminal `prompt`), clear the ▼,
; then drop the window.
pc_msg_prompt:
    mov byte [ebp + GB_TILEMAP1 + DIALOG_ARROW_TILEMAP_OFFSET], CHAR_DOWN
.release:
    call DelayFrame
    test byte [ebp + H_JOY_HELD], PAD_A | PAD_B
    jnz .release
.press:
    call DelayFrame
    test byte [ebp + H_JOY_HELD], PAD_A | PAD_B
    jz .press
    mov byte [ebp + GB_TILEMAP1 + DIALOG_ARROW_TILEMAP_OFFSET], TILE_SPC
    ; fall through to pc_msg_drop

; drop the dialog window (restore the count pc_msg_show saved). Clobbers EAX.
pc_msg_drop:
    mov eax, [msg_saved_wc]
    mov [g_window_count], eax
    ret

; --- two-line "done" messages (no wait) ---
PC_WhatDoYouWantText:                          ; pret ref: WhatDoYouWantText
    call pc_msg_box
    mov esi, W_TILEMAP + 14 * PPC_STRIDE + 1
    mov eax, s_whatdo
    call place_flat_str
    mov esi, W_TILEMAP + 16 * PPC_STRIDE + 1
    mov eax, s_todo
    call place_flat_str
    call pc_msg_show
    ret

PC_WhatToDepositText:                          ; pret ref: WhatToDepositText
    call pc_msg_box
    mov esi, W_TILEMAP + 14 * PPC_STRIDE + 1
    mov eax, s_whatdo
    call place_flat_str
    mov esi, W_TILEMAP + 16 * PPC_STRIDE + 1
    mov eax, s_todeposit_q
    call place_flat_str
    call pc_msg_show
    ret

PC_WhatToWithdrawText:                          ; pret ref: WhatToWithdrawText
    call pc_msg_box
    mov esi, W_TILEMAP + 14 * PPC_STRIDE + 1
    mov eax, s_whatdo
    call place_flat_str
    mov esi, W_TILEMAP + 16 * PPC_STRIDE + 1
    mov eax, s_towithdraw_q
    call place_flat_str
    call pc_msg_show
    ret

PC_WhatToTossText:                              ; pret ref: WhatToTossText
    call pc_msg_box
    mov esi, W_TILEMAP + 14 * PPC_STRIDE + 1
    mov eax, s_whatdo
    call place_flat_str
    mov esi, W_TILEMAP + 16 * PPC_STRIDE + 1
    mov eax, s_totossaway_q
    call place_flat_str
    call pc_msg_show
    ret

; DepositHowManyText / WithdrawHowManyText / TossHowManyText — all "How many?"
PC_DepositHowManyText:
PC_WithdrawHowManyText:
PC_TossHowManyText:                             ; pret ref: {Deposit,Withdraw,Toss}HowManyText
    call pc_msg_box
    mov esi, W_TILEMAP + 14 * PPC_STRIDE + 1
    mov eax, s_howmany
    call place_flat_str
    call pc_msg_show
    ret

; --- messages terminated by `prompt` (▼ + A/B wait) ---
PC_TurnedOnPC2Text:                             ; pret ref: TurnedOnPC2Text
    call pc_msg_box
    ; "<PLAYER> turned on"
    lea eax, [ebp + W_PLAYER_NAME]
    mov esi, W_TILEMAP + 14 * PPC_STRIDE + 1
    call place_flat_str                         ; ESI advances past the name
    mov eax, s_turnedon
    call place_flat_str
    mov esi, W_TILEMAP + 16 * PPC_STRIDE + 1
    mov eax, s_thepc
    call place_flat_str
    call pc_msg_show
    jmp pc_msg_prompt

PC_ItemWasStoredText:                           ; pret ref: ItemWasStoredText
    call pc_msg_box
    ; "<wNameBuffer> was" — wNameBuffer holds the chosen item name (DisplayListMenuID)
    lea eax, [ebp + wNameBuffer]
    mov esi, W_TILEMAP + 14 * PPC_STRIDE + 1
    call place_flat_str
    mov eax, s_was
    call place_flat_str
    mov esi, W_TILEMAP + 16 * PPC_STRIDE + 1
    mov eax, s_storedvia
    call place_flat_str
    call pc_msg_show
    jmp pc_msg_prompt

PC_WithdrewItemText:                            ; pret ref: WithdrewItemText
    call pc_msg_box
    mov esi, W_TILEMAP + 14 * PPC_STRIDE + 1
    mov eax, s_withdrew
    call place_flat_str
    ; "<wNameBuffer>."
    lea eax, [ebp + wNameBuffer]
    mov esi, W_TILEMAP + 16 * PPC_STRIDE + 1
    call place_flat_str
    mov byte [ebp + esi], CHAR_DOT
    call pc_msg_show
    jmp pc_msg_prompt

PC_NothingToDepositText:                        ; pret ref: NothingToDepositText
    call pc_msg_box
    mov esi, W_TILEMAP + 14 * PPC_STRIDE + 1
    mov eax, s_youhavenothing
    call place_flat_str
    mov esi, W_TILEMAP + 16 * PPC_STRIDE + 1
    mov eax, s_todeposit_d
    call place_flat_str
    call pc_msg_show
    jmp pc_msg_prompt

PC_NoRoomToStoreText:                           ; pret ref: NoRoomToStoreText
    call pc_msg_box
    mov esi, W_TILEMAP + 14 * PPC_STRIDE + 1
    mov eax, s_noroomleft
    call place_flat_str
    mov esi, W_TILEMAP + 16 * PPC_STRIDE + 1
    mov eax, s_storeitems
    call place_flat_str
    call pc_msg_show
    jmp pc_msg_prompt

PC_NothingStoredText:                           ; pret ref: NothingStoredText
    call pc_msg_box
    mov esi, W_TILEMAP + 14 * PPC_STRIDE + 1
    mov eax, s_thereisnothing
    call place_flat_str
    mov esi, W_TILEMAP + 16 * PPC_STRIDE + 1
    mov eax, s_stored_d
    call place_flat_str
    call pc_msg_show
    jmp pc_msg_prompt

PC_CantCarryMoreText:                           ; pret ref: CantCarryMoreText
    call pc_msg_box
    mov esi, W_TILEMAP + 14 * PPC_STRIDE + 1
    mov eax, s_youcantcarry
    call place_flat_str
    mov esi, W_TILEMAP + 16 * PPC_STRIDE + 1
    mov eax, s_anymoreitems
    call place_flat_str
    call pc_msg_show
    jmp pc_msg_prompt

; ===========================================================================
%ifdef DEBUG_PLAYERSPC
; ---------------------------------------------------------------------------
; RunPlayersPCTest — seed the party + bag (+ 2 box items), load the font, open
; PlayerPC over the (already-loaded) overworld. PlayerPCMenu's DEBUG hook
; renders one frame with the parent menu and dumps FRAME.BIN. Never returns.
; In: EBP = GB base. Call from EnterMap (after the overworld is loaded) so
; Pallet Town backs the box. make DEBUG_PLAYERSPC=1 (root wires the call site).
; ---------------------------------------------------------------------------
RunPlayersPCTest:
    mov byte [ebp + 0xD162], 0                  ; wPartyCount = 0
    mov byte [ebp + 0xD163], 0xFF               ; wPartySpecies sentinel
    mov byte [ebp + wNumBagItems], 0
    mov byte [ebp + wBagItems], 0xFF
    call PrepareNewGameDebug                     ; seed party + bag
    ; seed 2 PC-box items (Gen-1 shape: count, [id,qty]*, $FF terminator)
    mov byte [ebp + wNumBoxItems], 2
    mov byte [ebp + wBoxItems + 0], POTION
    mov byte [ebp + wBoxItems + 1], 5
    mov byte [ebp + wBoxItems + 2], ANTIDOTE
    mov byte [ebp + wBoxItems + 3], 2
    mov byte [ebp + wBoxItems + 4], 0xFF
    ; swap the font into vFont so the box glyphs render (caller contract)
    or byte [ebp + W_FONT_LOADED], (1 << BIT_FONT_LOADED)
    call LoadFontTilePatterns
    ; skip the turn-on SFX/prompt (would block headless): host as a generic PC
    or byte [ebp + wMiscFlags], (1 << BIT_USING_GENERIC_PC)
    call PlayerPC                                ; PlayerPCMenu's hook dumps + exits
.hang:
    jmp .hang                                    ; unreachable
%endif
