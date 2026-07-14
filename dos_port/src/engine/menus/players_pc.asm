; players_pc.asm — the player's-PC "ITEM STORAGE" menu. Faithful port of pret
; engine/menus/players_pc.asm: PlayerPC / PlayerPCMenu / ExitPlayerPC and the
; three item flows (PlayerPCDeposit / PlayerPCWithdraw / PlayerPCToss), each
; driven by the generic list driver DisplayListMenuID (home/list_menu.asm) over
; wNumBagItems (the bag) and wNumBoxItems (the PC item box).
;
; HISTORY / CORRECTED CLAIMS (menu-fidelity row 17 part 2). The header this
; replaces asserted three things; all three were false, and each had cost the
; file real code (the same three classes row 17 part 1 found in pc.asm):
;   * "PlaySound / WaitForSoundToFinish … are ; TODO-HW: audio HAL (Phase 3) —
;     no-ops" — both are ported and live (home/audio.asm) and the port's audio
;     engine plays SFX. All eight calls (SFX_TURN_ON_PC; SFX_TURN_OFF_PC +
;     WaitForSoundToFinish; and the WaitForSoundToFinish / SFX_WITHDRAW_DEPOSIT /
;     WaitForSoundToFinish triple in both .roomAvailable paths) are restored. M-83.
;   * "call SaveScreenTilesToBuffer1 / LoadScreenTilesFromBuffer2 — port(window
;     model): there is no screen to save/restore" — both routines are ported and
;     linked (battle/battle_menu.asm and movie/title.asm) and are plain
;     wTileMap ↔ wTileMapBackup{,2} WRAM copies. All three calls are restored. M-83.
;   * The fourteen messages were "DRAWN WHOLE … with the pret wording", i.e. as
;     hand-encoded charmap glyph runs — the Tier-1 DATA violation. That form cannot
;     express what two of the streams do: _ItemWasStoredText and _WithdrewItemText
;     splice wNameBuffer with TX_RAM. All fourteen now generate into
;     assets/players_pc_text.inc and print through PrintText, behind pret's own
;     text_far wrappers. M-84.
;   Also corrected: the old .loop comment claimed pret's IsItemHM check was "folded
;   into TossItem_" — pret calls IsItemHM right here (players_pc.asm:228), exactly
;   as the port does. M-85.
;
; PORT MODEL:
;  * SM83→x86: A=AL, BC=BX, DE=DX, HL=ESI, EBP = GB base; GB memory at [EBP+sym].
;  * DEVIATION(window-compositor): this screen's PC menu box is a WINDOW over the
;    live overworld canvas, and PrintText's usual projection (msgbox_dialog) opens
;    its box with set_single_window — which collapses the window list to the dialog
;    alone and would erase the menu box (and, mid-flow, DisplayListMenuID's item
;    list) that the message is supposed to sit under. So this file selects its own
;    projection record, msgbox_players_pc: pret's geometry exactly (box at (0,12),
;    text at (1,14)/(1,16)) but MB_WIN_TILEMAP = 0, so PrintText draws into the
;    stride-20 scratch and leaves the window list alone; PlayerPCMirror carries the
;    scratch to the two window tilemaps and ppc_show_msg_window appends the message
;    box on top. Same shape, and the same reason, as the party menu's msgbox_party
;    (party_menu.asm:172).
;    Consequence: a message becomes visible when it is mirrored, not letter by
;    letter (the per-character reveal, sync_dialog_window, only runs for a
;    window-owning projection). PlayerPCMenu sets BIT_NO_TEXT_DELAY — as pret does —
;    so every message printed from the menu is instant on the GB too; only the
;    direct-access TurnedOnPC2Text differs.
;  * DEVIATION(canvas) at the LoadScreenTilesFromBuffer2 sites: the WRAM restore is
;    faithful and kept, but the port's map lives in the 40×25 canvas, not in
;    wTileMap (which is the port's stride-20 collision/text mirror) — and on a
;    direct-access entry buffer2 holds whatever screen was saved last, not this map.
;    RefreshCollisionTileMap rebuilds the mirror from wSurroundingTiles so
;    UpdateSprites' text-box tile check sees map + box.
;
; Build (standalone check):
;   nasm -f coff -I include/ -I . -o /dev/null src/engine/menus/players_pc.asm
; ---------------------------------------------------------------------------
bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_text.inc"                   ; text_far / text_end + TX_* codes
%include "msgbox.inc"                    ; MB_* — the message-box projection record
%include "assets/audio_constants.inc"    ; SFX_TURN_ON_PC / SFX_TURN_OFF_PC / SFX_WITHDRAW_DEPOSIT

%define UI_LAYOUT_EQUATES_ONLY 1
%include "assets/ui_layout_menus.inc"

global PlayerPC
global PlayerPCMenu
global ExitPlayerPC
global PlayerPCDeposit
global PlayerPCWithdraw
global PlayerPCToss
global PlayersPCMenuEntries
global TurnedOnPC2Text
global WhatDoYouWantText
global WhatToDepositText
global DepositHowManyText
global ItemWasStoredText
global NothingToDepositText
global NoRoomToStoreText
global WhatToWithdrawText
global WithdrawHowManyText
global WithdrewItemText
global NothingStoredText
global CantCarryMoreText
global WhatToTossText
global TossHowManyText

extern DisplayListMenuID             ; home/list_menu.asm
extern DisplayChooseQuantityMenu     ; home/list_menu.asm
extern TextBoxBorder                 ; text/text.asm — ESI=top-left, BL=int_w, BH=int_h
extern PlaceString                   ; text/text.asm — ESI=dest, EAX=flat src
extern HandleMenuInput               ; home/window.asm — Out: AL = watched keys pressed
extern PlaceMenuCursor               ; home/window.asm
extern PlaceUnfilledArrowMenuCursor  ; home/window.asm
extern PrintText                     ; home/window.asm — In: ESI = text stream
extern text_msgbox                   ; home/text.asm — the active msgbox projection
extern msgbox_dialog                 ; home/text.asm — the overworld dialog projection
extern text_arrow_pos                ; home/text.asm — <PROMPT> ▼ cell (from MB_ARROW)
extern PlaySound                     ; home/audio.asm — In: AL = sound id
extern WaitForSoundToFinish          ; home/audio.asm
extern SaveScreenTilesToBuffer1      ; battle/battle_menu.asm — wTileMap → wTileMapBackup
extern LoadScreenTilesFromBuffer2    ; movie/title.asm — wTileMapBackup2 → wTileMap
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

; --- parent PC-menu box geometry (frozen layout) ---
; ; PROJ menus: GB(0,0) 16x10 --(anchor=center/top, X+10, Y+0)--> wx=87 wy=0
;   clip=128 max_y=80 [UI_PLAYERS_PC_MENU_*]; pret hlcoord 0,0 / lb bc,8,14 =
;   a 14x8-interior (16x10 total) border.
PPC_INT_W   equ 14                   ; TextBoxBorder interior width  (pret c)
PPC_INT_H   equ 8                    ; TextBoxBorder interior height (pret b)
PPC_TOTAL_W equ UI_PLAYERS_PC_MENU_X2 - UI_PLAYERS_PC_MENU_COL + 1   ; 16
PPC_TOTAL_H equ UI_PLAYERS_PC_MENU_Y2 - UI_PLAYERS_PC_MENU_ROW + 1   ; 10
PPC_STRIDE  equ 20                   ; the GB-shaped scratch stride (NOT the 40-wide canvas)
PPC_SROW    equ 0                    ; GB_TILEMAP0 mirror start row

; --- the message box: pret's own GB placement, rows 12-17 of the same scratch ---
MSG_SROW    equ 12                   ; first scratch row of the message border

TILE_SPC        equ 0x7F             ; blank space tile
PPC_ARROW_BLINK equ 20               ; ▼ blink half-period, frames (party menu / battle)

; ===========================================================================
; Tier-1 DATA: PlayersPCMenuEntries + the fourteen message streams, generated
; from pret engine/menus/players_pc.asm + data/text/text_3.asm.
%include "assets/players_pc_text.inc"

section .data
align 4
; msgbox_players_pc — this screen's message-box projection (msgbox.inc). pret's
; geometry exactly; MB_WIN_TILEMAP = 0 so PrintText draws into the scratch and does
; NOT collapse the window list (see the header's DEVIATION(window-compositor)).
msgbox_players_pc:
    dd PPC_STRIDE                                ; MB_STRIDE
    dd W_TILEMAP + MSG_SROW * PPC_STRIDE         ; MB_BOX_OFS      — (0,12)
    dd 18                                        ; MB_BOX_W        — 18 interior columns
    dd 4                                         ; MB_BOX_H        — 4 interior rows
    dd W_TILEMAP + 14 * PPC_STRIDE + 1           ; MB_LINE1        — pret bccoord 1,14
    dd W_TILEMAP + 16 * PPC_STRIDE + 1           ; MB_LINE2        — <LINE> at (1,16)
    dd W_TILEMAP + 16 * PPC_STRIDE + 18          ; MB_ARROW        — ▼ at (18,16)
    dd PlayerPCPromptWait                        ; MB_PROMPT       — our own wait
    dd 0                                         ; MB_WIN_WX       ] no window: this
    dd 0                                         ; MB_WIN_WY       ] file mirrors the
    dd 0                                         ; MB_WIN_CLIP     ] scratch itself, so
    dd 0                                         ; MB_WIN_MAXY     ] the menu and list
    dd 0                                         ; MB_WIN_TILEMAP  ] windows survive the
    dd 0                                         ; MB_WIN_STARTROW ] message

section .bss
align 4
ppc_msg_wc:      resd 1              ; g_window_count when the message window was appended
ppc_msg_up:      resd 1              ; 1 = that window is still the one on top

; ===========================================================================
section .text

; ---------------------------------------------------------------------------
; PlayerPC — pret ref: engine/menus/players_pc.asm:PlayerPC.
; Entry from the overworld PC script object and from pc.asm:PCMainMenu.
; In: EBP = GB base.
; ---------------------------------------------------------------------------
PlayerPC:
    mov byte [ebp + wNameListType], ITEM_NAME
    call SaveScreenTilesToBuffer1
    xor al, al
    mov [ebp + wBagSavedMenuItem], al
    mov [ebp + wParentMenuItem], al
    mov al, [ebp + wMiscFlags]
    test al, (1 << BIT_USING_GENERIC_PC)
    jnz PlayerPCMenu                     ; jr nz — hosted by the generic PC: no turn-on FX
    ; accessing it directly
    mov al, SFX_TURN_ON_PC
    call PlaySound
    mov esi, TurnedOnPC2Text
    call PlayerPCPrintText               ; call PrintText (through our projection)
    ; fall through

; ---------------------------------------------------------------------------
; PlayerPCMenu — pret ref: engine/menus/players_pc.asm:PlayerPCMenu.
; The 4-entry parent menu. Sub-flows `jp PlayerPCMenu` back here for a full redraw.
; ---------------------------------------------------------------------------
PlayerPCMenu:
    or byte [ebp + W_STATUS_FLAGS_5], (1 << BIT_NO_TEXT_DELAY)  ; set BIT_NO_TEXT_DELAY
    mov al, [ebp + wParentMenuItem]
    mov [ebp + wCurrentMenuItem], al
    or byte [ebp + wMiscFlags], (1 << BIT_NO_MENU_BUTTON_SOUND)
    call LoadScreenTilesFromBuffer2
    ; DEVIATION(window-compositor): the WRAM restore puts wTileMap back, but what is
    ; on screen here are WINDOWS, which no WRAM copy touches — drop them.
    call hide_window
    mov dword [ppc_msg_up], 0            ; …so the message window must be re-appended
    mov dword [text_row_stride], PPC_STRIDE
    ; DEVIATION(canvas): rebuild the wTileMap map mirror — see the file header.
    call RefreshCollisionTileMap
    ; hlcoord 0,0 / lb bc,8,14 / TextBoxBorder — box-relative into the scratch
    mov esi, W_TILEMAP
    mov bl, PPC_INT_W
    mov bh, PPC_INT_H
    call TextBoxBorder
    call UpdateSprites
    ; hlcoord 2,2 / PlaceString PlayersPCMenuEntries (double-spaced <NEXT>)
    ; DEVIATION(canvas): clear BIT_SINGLE_SPACED_LINES so <NEXT> advances 2 rows.
    ; pret relies on the ambient overworld default; the port's canvas screens set
    ; the bit, and a menu that inherits it draws all four entries on one row.
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
    ; port(window model): expose the finished box as this screen's window
    call ppc_show_menu_window
    mov esi, WhatDoYouWantText
    call PlayerPCPrintText                    ; call PrintText
    mov dword [menu_item_step], 2 * PPC_STRIDE
    mov dword [menu_redraw_cb], PlayerPCMirror ; carry the live ▶ cursor to the window
%ifdef DEBUG_PLAYERSPC
    ; menus row-17 gate: render the parent menu (box + entries + ▶ cursor + the
    ; "What do you want to do?" box) for one frame, dump FRAME.BIN, exit
    ; (HandleMenuInput would block headless).
    call PlaceMenuCursor
    call PlayerPCMirror
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
    mov al, SFX_TURN_OFF_PC
    call PlaySound
    call WaitForSoundToFinish
.next:
    and byte [ebp + wMiscFlags], (~(1 << BIT_NO_MENU_BUTTON_SOUND)) & 0xFF
    call LoadScreenTilesFromBuffer2
    ; DEVIATION(window-compositor) + DEVIATION(canvas), as in PlayerPCMenu: the WRAM
    ; restore can neither drop this screen's windows nor rebuild the canvas-backed
    ; map mirror that UpdateSprites reads.
    call hide_window
    mov dword [ppc_msg_up], 0
    call RefreshCollisionTileMap
    xor al, al
    mov [ebp + wListScrollOffset], al
    mov [ebp + wBagSavedMenuItem], al
    and byte [ebp + W_STATUS_FLAGS_5], (~(1 << BIT_NO_TEXT_DELAY)) & 0xFF
    xor al, al
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
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
    mov esi, NothingToDepositText
    call PlayerPCPrintText                    ; call PrintText
    jmp PlayerPCMenu                          ; jp PlayerPCMenu
.loop:
    mov esi, WhatToDepositText
    call PlayerPCPrintText                    ; call PrintText
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
    mov esi, DepositHowManyText
    call PlayerPCPrintText                    ; call PrintText
    call DisplayChooseQuantityMenu            ; AL=$ff on B-cancel
    cmp al, 0xff
    jz .loop                                  ; jp z
.next:
    mov esi, wNumBoxItems                     ; ld hl, wNumBoxItems
    call AddItemToInventory                   ; CF=1 → room available
    jc .roomAvailable                         ; jr c
    mov esi, NoRoomToStoreText
    call PlayerPCPrintText                    ; call PrintText
    jmp .loop                                 ; jp .loop
.roomAvailable:
    mov esi, wNumBagItems                     ; ld hl, wNumBagItems
    call RemoveItemFromInventory
    call WaitForSoundToFinish
    mov al, SFX_WITHDRAW_DEPOSIT
    call PlaySound
    call WaitForSoundToFinish
    mov esi, ItemWasStoredText
    call PlayerPCPrintText                    ; call PrintText
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
    mov esi, NothingStoredText
    call PlayerPCPrintText                    ; call PrintText
    jmp PlayerPCMenu                          ; jp PlayerPCMenu
.loop:
    mov esi, WhatToWithdrawText
    call PlayerPCPrintText                    ; call PrintText
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
    ; if it's not a key item, there can be more than one of the item
    mov esi, WithdrawHowManyText
    call PlayerPCPrintText                    ; call PrintText
    call DisplayChooseQuantityMenu
    cmp al, 0xff
    jz .loop                                  ; jp z
.next:
    mov esi, wNumBagItems                     ; ld hl, wNumBagItems
    call AddItemToInventory
    jc .roomAvailable                         ; jr c
    mov esi, CantCarryMoreText
    call PlayerPCPrintText                    ; call PrintText
    jmp .loop                                 ; jp .loop
.roomAvailable:
    mov esi, wNumBoxItems                     ; ld hl, wNumBoxItems
    call RemoveItemFromInventory
    call WaitForSoundToFinish
    mov al, SFX_WITHDRAW_DEPOSIT
    call PlaySound
    call WaitForSoundToFinish
    mov esi, WithdrewItemText
    call PlayerPCPrintText                    ; call PrintText
    jmp .loop                                 ; jp .loop

; ---------------------------------------------------------------------------
; PlayerPCToss — pret ref: engine/menus/players_pc.asm:PlayerPCToss.
; TossItem out of the box (wNumBoxItems).
; ---------------------------------------------------------------------------
PlayerPCToss:
    xor al, al
    mov [ebp + wCurrentMenuItem], al
    mov [ebp + wListScrollOffset], al
    mov al, [ebp + wNumBoxItems]
    test al, al                               ; and a — empty box?
    jnz .loop
    mov esi, NothingStoredText
    call PlayerPCPrintText                    ; call PrintText
    jmp PlayerPCMenu                          ; jp PlayerPCMenu
.loop:
    mov esi, WhatToTossText
    call PlayerPCPrintText                    ; call PrintText
    mov word [ebp + wListPointer], wNumBoxItems
    xor al, al
    mov [ebp + wPrintItemPrices], al
    mov al, ITEMLISTMENU
    mov [ebp + wListMenuID], al
    ; pret push hl / DisplayListMenuID / pop hl — and the same push/pop around
    ; IsKeyItem and the quantity prompt. hl is the constant wNumBoxItems throughout,
    ; so the port re-loads it into ESI before TossItem instead of saving it thrice.
    call DisplayListMenuID
    jc PlayerPCMenu                           ; jp c — cancelled
    call IsKeyItem
    mov byte [ebp + wItemQuantity], 1
    mov al, [ebp + wIsKeyItem]
    test al, al
    jnz .next                                 ; jr nz
    mov al, [ebp + wCurItem]
    call IsItemHM                             ; CF = is HM
    jc .next                                  ; jr c — HM: quantity 1, TossItem refuses
    ; if it's not a key item, there can be more than one of the item
    mov esi, TossHowManyText
    call PlayerPCPrintText                    ; call PrintText
    call DisplayChooseQuantityMenu
    cmp al, 0xff
    jz .loop                                  ; jp z
.next:
    mov esi, wNumBoxItems                     ; pret: the hl it pushed/popped above
    call TossItem                             ; disallows tossing key items
    jmp .loop                                 ; jp .loop

; ===========================================================================
; The text streams — pret's own wrappers (engine/menus/players_pc.asm) around the
; generated bodies in assets/players_pc_text.inc.
; ===========================================================================
section .data

TurnedOnPC2Text:
    text_far _TurnedOnPC2Text
    text_end

WhatDoYouWantText:
    text_far _WhatDoYouWantText
    text_end

WhatToDepositText:
    text_far _WhatToDepositText
    text_end

DepositHowManyText:
    text_far _DepositHowManyText
    text_end

ItemWasStoredText:
    text_far _ItemWasStoredText
    text_end

NothingToDepositText:
    text_far _NothingToDepositText
    text_end

NoRoomToStoreText:
    text_far _NoRoomToStoreText
    text_end

WhatToWithdrawText:
    text_far _WhatToWithdrawText
    text_end

WithdrawHowManyText:
    text_far _WithdrawHowManyText
    text_end

WithdrewItemText:
    text_far _WithdrewItemText
    text_end

NothingStoredText:
    text_far _NothingStoredText
    text_end

CantCarryMoreText:
    text_far _CantCarryMoreText
    text_end

WhatToTossText:
    text_far _WhatToTossText
    text_end

TossHowManyText:
    text_far _TossHowManyText
    text_end

; ===========================================================================
; Port plumbing — the window projection of this screen. pret has no counterpart:
; on the GB the tilemap IS the screen. See the header's DEVIATION(window-compositor).
; ===========================================================================
section .text

; ---------------------------------------------------------------------------
; PlayerPCPrintText — PrintText through msgbox_players_pc, then carry the result to
; the window layer. text_msgbox is global mutable state, so the record is selected
; around the call and restored to the overworld default afterwards (as
; party_menu.asm:PartyMenuPrintText does, for the same reason: leaving it pointed
; here would re-project the next overworld dialog into a scratch nothing mirrors).
; In: ESI = text stream.
; ---------------------------------------------------------------------------
PlayerPCPrintText:
    mov dword [text_msgbox], msgbox_players_pc
    call PrintText
    mov dword [text_msgbox], msgbox_dialog
    call ppc_show_msg_window
    ret

; ---------------------------------------------------------------------------
; PlayerPCPromptWait — msgbox_players_pc's MB_PROMPT hook: blink the ▼ at
; [text_arrow_pos] and wait for A/B, mirroring the scratch each frame so the arrow
; is actually on screen. The default hook (text_prompt_hook == 0) is
; manual_text_scroll, which hijacks the window layer for the overworld dialog and
; would drop this screen's boxes. Modelled on PartyMenuPromptWait (M-29).
; All registers preserved (the caller is mid-stream).
; ---------------------------------------------------------------------------
PlayerPCPromptWait:
    pushad
    call ppc_show_msg_window                ; the finished box exists in the scratch now
    mov esi, [text_arrow_pos]
    mov byte [ebp + esi], CHAR_DOWN_ARROW
    mov ecx, PPC_ARROW_BLINK
.wait:
    call PlayerPCMirror                     ; the ▼ lives in the scratch; show it
    call DelayFrame
    test byte [ebp + H_JOY_PRESSED], PAD_A | PAD_B
    jnz .done
    dec ecx
    jnz .wait
    mov ecx, PPC_ARROW_BLINK                ; blink toggle
    cmp byte [ebp + esi], CHAR_DOWN_ARROW
    jne .turnOn
    mov byte [ebp + esi], TILE_SPC
    jmp .wait
.turnOn:
    mov byte [ebp + esi], CHAR_DOWN_ARROW
    jmp .wait
.done:
    mov byte [ebp + esi], TILE_SPC          ; erase the ▼
    call PlayerPCMirror
    popad
    ret

; ---------------------------------------------------------------------------
; ppc_show_menu_window — mirror the scratch and append the PC menu box (scratch
; rows 0-9 → GB_TILEMAP0) as this screen's window.
; ---------------------------------------------------------------------------
ppc_show_menu_window:
    call PlayerPCMirror
    mov eax, UI_PLAYERS_PC_MENU_WX
    mov ebx, UI_PLAYERS_PC_MENU_WY
    mov ecx, UI_PLAYERS_PC_MENU_CLIP
    mov edx, UI_PLAYERS_PC_MENU_MAXY
    mov esi, GB_TILEMAP0
    mov edi, PPC_SROW
    call add_window
    ret

; ---------------------------------------------------------------------------
; ppc_show_msg_window — mirror the scratch and make sure the message box (scratch
; rows 12-17 → GB_TILEMAP1) is the window on top. It is APPENDED, never
; set_single_window'd, so the menu box — and, in the item flows, DisplayListMenuID's
; list window — stay up beneath it, which is what the GB shows. It is appended only
; once per screen state: while g_window_count still equals the count recorded at the
; append, the window is ours and still on top, so re-printing into the same state
; just re-mirrors (the .loop paths print many messages). DisplayListMenuID's own
; hide_window resets the count, and the next message re-appends.
; All registers preserved.
; ---------------------------------------------------------------------------
ppc_show_msg_window:
    pushad
    call PlayerPCMirror
    cmp dword [ppc_msg_up], 0
    je .append
    mov eax, [g_window_count]
    cmp eax, [ppc_msg_wc]
    je .done                                ; still ours, still on top
.append:
    mov eax, UI_MESSAGE_BOX_WX
    mov ebx, UI_MESSAGE_BOX_WY
    mov ecx, UI_MESSAGE_BOX_CLIP
    mov edx, UI_MESSAGE_BOX_MAXY
    mov esi, GB_TILEMAP1
    xor edi, edi
    call add_window
    mov eax, [g_window_count]
    mov [ppc_msg_wc], eax
    mov dword [ppc_msg_up], 1
.done:
    popad
    ret

; ---------------------------------------------------------------------------
; PlayerPCMirror — carry the stride-20 scratch to the two window tilemaps: rows 0-9
; (the PC menu box) → GB_TILEMAP0 rows 0-9, and rows 12-17 (the message box) →
; GB_TILEMAP1 rows 0-5, padding cols 20-31 with the blank tile. The port's stand-in
; for the GB's "the tilemap is the screen". Preserves all registers, so it also
; serves as HandleMenuInput's menu_redraw_cb (the live ▶ cursor is a scratch tile).
; ---------------------------------------------------------------------------
PlayerPCMirror:
    pushad
    xor ebx, ebx
.menuRow:
    imul esi, ebx, PPC_STRIDE
    lea esi, [ebp + esi + W_TILEMAP]
    mov edi, ebx
    shl edi, 5                                ; row * 32
    lea edi, [ebp + edi + GB_TILEMAP0 + PPC_SROW * 32]
    mov ecx, PPC_TOTAL_W
    rep movsb
    inc ebx
    cmp ebx, PPC_TOTAL_H
    jb .menuRow
    mov ecx, 6                                ; 6 message rows (scratch rows 12-17)
    lea esi, [ebp + W_TILEMAP + MSG_SROW * PPC_STRIDE]
    lea edi, [ebp + GB_TILEMAP1]
.msgRow:
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
    jnz .msgRow
    popad
    ret

; ===========================================================================
%ifdef DEBUG_PLAYERSPC
; ---------------------------------------------------------------------------
; RunPlayersPCTest — seed the party + bag (+ 2 box items), load the font, open
; PlayerPC over the (already-loaded) overworld. PlayerPCMenu's DEBUG hook renders
; one frame with the parent menu and dumps FRAME.BIN. Never returns.
; In: EBP = GB base. Call from EnterMap (after the overworld is loaded) so Pallet
; Town backs the box. make DEBUG_PLAYERSPC=1 (root wires the call site).
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
