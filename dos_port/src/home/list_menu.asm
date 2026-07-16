; ============================================================================
; list_menu.asm — generic list-menu driver.  Faithful translation of pret
; home/list_menu.asm (DisplayListMenuID / DisplayListMenuIDLoop /
; PrintListMenuEntries / DisplayChooseQuantityMenu / ExitListMenu).
;
; Wave 4 / M4.2 (docs/current_plan_home_rectification.md); menu-fidelity row 4.
;
; ── What this is ────────────────────────────────────────────────────────────
; The gen-1 generic list menu, keyed on [wListMenuID]:
;   PCPOKEMONLISTMENU ($00) — PC withdraw/deposit mon lists
;   MOVESLISTMENU     ($01) — move-relearner / move list
;   PRICEDITEMLISTMENU($02) — Pokémart buy menu (name + price + quantity picker)
;   ITEMLISTMENU      ($03) — Start-menu Item bag / Pokémart sell menu
; Draws the framed list box, prints up to 4 entries (+ CANCEL + ▼ scroll hint),
; runs the cursor + up/down scroll, and returns the chosen entry.  For priced
; lists it also runs DisplayChooseQuantityMenu (the ×NN quantity/price selector).
;
; ── Register map (CLAUDE.md) ─ A=AL, BC=BX, DE=DX, HL=ESI, EBP=GB base ────────
;   Emulated GB memory is [ebp + SYM].
;
; ── Return contract (preserved from pret) ────────────────────────────────────
;   * ITEM chosen  (A):  CF=0, [wMenuExitMethod]=CHOSE_MENU_ITEM,
;                        [wChosenMenuItem]=[wCurrentMenuItem],
;                        [wCurItem]/[wCurListMenuItem]=selected entry id,
;                        [wWhichPokemon]=absolute index, name in wNameBuffer.
;   * CANCEL/B/empty:    CF=1 (ExitListMenu), [wMenuExitMethod]=CANCELLED_MENU,
;                        [wChosenMenuItem]=[wCurrentMenuItem].
;   * DisplayChooseQuantityMenu: A-confirm → ret with the count in [wItemQuantity]
;                        (and total price in hMoney for priced lists);
;                        B-cancel  → ret with AL=$ff.
;
; ── UI PROJECTION (docs/ui_projection.md) ────────────────────────────────────
; The port renders into a 40×25 / 320×200 canvas; GB (20×18) tile coords do NOT
; map 1:1.  This driver REUSES the *existing* overworld-ui bag-list projection
; and window mechanism already established (and confirmed) by
; src/engine/menus/bag_menu.asm — it is NOT a new/parallel projection:
;   - Boxes/entries are drawn box-relative into the W_TILEMAP scratch (stride 20,
;     exactly like bag_menu), then a window descriptor (add_window) places them at
;     the projected screen position (wx/wy/clip/max_y).  See ; PROJ tags below.
;   - The list box uses the SAME anchor as bag_menu's LIST_* (top-right, X+20 Y+0
;     → wx=199 wy=16 clip=128 max_y=104), so a list rendered through this generic
;     driver lands exactly where the bespoke bag list does.
; CONTEXT NOTE: the overworld/item anchor is the only one wired here.  The Old-Man
; battle (wBattleType≠0), the PC-box, and the Pokémart(priced) contexts want their
; own anchors (battle = uniform +10col/+3row per ui_projection.md); they are
; deferred and marked TODO(proj).
; This driver IS LIVE — DO NOT trust an older revision of this header, which claimed
; "there is no live caller of this driver yet". Verified callers (2026-07-13):
;   engine/menus/players_pc.asm:284,330,377   DisplayListMenuID (deposit/withdraw/toss)
;   engine/menus/start_sub_menus.asm:412      DisplayListMenuID (START→ITEM bag list)
;   engine/menus/swap_items.asm:76,147,229    tail-jumps back into DisplayListMenuIDLoop
;   engine/menus/players_pc.asm:293,338,392 + start_sub_menus.asm:529
;                                             DisplayChooseQuantityMenu
;   debug/debug_dump.asm:727                  the headless list harness
; So the deferred anchors above affect only those NON-overworld contexts; every
; wired caller today goes through the overworld/item anchor.
;
; pret citations are inline as ; pret list_menu.asm:<line/label>.
; LINKED (menus S3): all former link-blockers resolve to real linked routines
; (ClearScreenArea/LoadGBPal/PlaceUnfilledArrowMenuCursor/IsKeyItem/PrintLevel/
; GetPartyMonName/CopyToStringBuffer); party/box nick + box-level paths are in.
;
; Build check: nasm -f coff -I include/ -I . -o /dev/null list_menu.asm
; ============================================================================

%include "include/gb_memmap.inc"
%include "include/gb_constants.inc"
%include "include/gb_macros.inc"                ; BUG_FIX_LEVEL

global DisplayListMenuID
global DisplayListMenuIDLoop
global DisplayChooseQuantityMenu
global list_mirror              ; menus S4: StartMenu_Item refreshes the list
                                ; window after its cursor-cell edits

; ── globals resolved elsewhere (present in the port) ─────────────────────────
extern TextBoxBorder            ; text.asm       ESI=top-left dest, BL=int w, BH=int h
extern PlaceString              ; text.asm       ESI=dest(HL), EAX=src FLAT ptr
                                ;                (GB-memory src: lea eax,[ebp+off])
extern place_flat_str           ; text.asm       ESI=dest, EAX=flat '@'-term src
extern PrintNumber              ; home/print_num.asm  ESI=dest, EDX=src, BH=flags|bytes, BL=digits
extern PrintBCDNumber           ; home/print_bcd.asm  ESI=dest, EDX=src, BL=flags|len
extern add_window               ; ppu.asm        EAX=wx EBX=wy ECX=clip EDX=max_y ESI=tilemap EDI=start_row
extern hide_window              ; ppu.asm        clear window list (count=0)
extern HandleMenuInput          ; home/window.asm  Out: AL=watched keys pressed
extern PlaceMenuCursor          ; home/window.asm
extern text_row_stride          ; text.asm       (resd) active W_TILEMAP row stride
extern menu_item_step           ; home/window.asm(resd) per-item cursor row step
extern menu_redraw_cb           ; home/window.asm(resd) per-frame redraw cb (0=none)
extern menu_arrow_pos           ; home/window.asm(resd) the blinking ▼'s tile offset (0=none)
extern DelayFrames              ; frame.asm      BL=frame count
extern DelayFrame               ; frame.asm      the port's frame pump — joypad edge
                                ;                + compositor present both live here
                                ;                (see .waitForKeyPressLoop)
extern Delay3                   ; frame.asm
extern JoypadLowSensitivity     ; input/joypad_lowsens.asm  → H_JOY_PRESSED
extern BankswitchHome           ; home/bankswitch.asm  AL=bank (flat no-op bookkeeping)
extern BankswitchBack           ; home/bankswitch.asm
extern GetItemName              ; home/names.asm  [wNamedObjectIndex] → wNameBuffer
extern GetMoveName              ; home/names.asm
extern GetName                  ; home/names.asm  [wNameListIndex]/[wNameListType] → wNameBuffer
extern GetItemPrice             ; engine/items/item_price.asm  [wCurItem] → hItemPrice
extern LoadMonData              ; engine/pokemon/load_mon_data.asm
extern GetPartyMonName          ; home/pokemon.asm  AL=index, ESI=nick list base
extern CopyToStringBuffer       ; engine/battle/core.asm  EDX=src → wStringBuffer
extern AddBCDPredef             ; engine/math/bcd.asm
extern DivideBCDPredef3         ; engine/math/bcd.asm

; ── former link-blockers, all resolved by linked code (menus S3) ─────────────
; (ClearScreenArea no longer used here: its stride-40 row advance corrupted the
;  stride-20 list scratch — replaced by the inline list_clear_interior below.)
extern LoadGBPal                ; home/fade.asm  (flat: palette load)
extern PlaceUnfilledArrowMenuCursor ; home/window.asm  AL=item → hollow ▶
extern IsKeyItem                ; home/item_predicates.asm  [wCurItem] → [wIsKeyItem]
extern PrintLevel               ; home/pokemon.asm  ESI=dest, [wLoadedMonLevel]

; SELECT-swap driver lives in swap_items.asm (mutual extern; both link together)
extern HandleItemListSwapping

; Menu WRAM (wListPointer/wCurListMenuItem/wPrintItemPrices/wMenuCursorLocation/
; wMenuWatchMovingOutOfBounds/wChosenMenuItem/wMenuExitMethod/wIsKeyItem/wTextBoxID/
; wLoadedMonBoxLevel/wLoadedMonLevel/wListMenuID/hHalveItemPrices) and the list
; constants (PC/MOVES/PRICED/ITEMLISTMENU, LIST_MENU_BOX, CHOSE_MENU_ITEM,
; CANCELLED_MENU) now live canonically in gb_memmap.inc / gb_constants.inc (Wave 4).
;
; Local lowercase aliases onto existing port H_*/W_* symbols the code below uses:
wStatusFlags5               equ W_STATUS_FLAGS_5
hAutoBGTransferEnabled      equ H_AUTO_BG_TRANSFER_EN
hJoyPressed                 equ H_JOY_PRESSED
hJoy7                       equ H_JOY7
hItemPrice                  equ H_ITEM_PRICE
hMoney                      equ H_MONEY
hDivideBCDDivisor           equ H_DIVIDE_BCD_DIVISOR
hDivideBCDQuotient          equ H_DIVIDE_BCD_QUOTIENT

; ── list-box geometry: REUSED from bag_menu.asm LIST_* (confirmed projection) ─
LIST_STRIDE     equ 20          ; W_TILEMAP box-relative stride (NOT port SCREEN_WIDTH=40)
LIST_INT_W      equ 14          ; TextBoxBorder interior width  (total 16)
LIST_INT_H      equ 9           ; TextBoxBorder interior height (total 11)
LIST_TOTAL_W    equ LIST_INT_W + 2
LIST_TOTAL_H    equ LIST_INT_H + 2
LIST_WX         equ 199         ; ; PROJ overworld-ui GB(4,2) anchor=top-right X+20 Y+0
LIST_WY         equ 16
LIST_CLIP       equ 128
LIST_MAXY       equ 104
LIST_SROW       equ 0           ; GB_TILEMAP0 start row
LIST_CURSOR_COL equ 1           ; pret hlcoord 5,4 → box-rel (1,2)
LIST_NAME_COL   equ 2           ; pret hlcoord 6,4 → box-rel (2,2)
LIST_NAME_ROW0  equ 2
LIST_ROW_STEP   equ 2           ; each entry spans 2 rows
LIST_PRICE_COL  equ 7           ; pret bc = SCREEN_WIDTH+5 from name (row+1, col+5)
LIST_INFO_COL   equ 10          ; pret bc = SCREEN_WIDTH+8 (qty '×' / level) (row+1, col+8)
LIST_DOWN_COL   equ 14
LIST_DOWN_ROW   equ 9

; quantity box geometry (DisplayChooseQuantityMenu). Overworld-ui anchor reused;
; priced(mart) anchor is context-specific → TODO(proj) when the mart is wired.
; The qty box gets its OWN scratch rows + GB_TILEMAP0 region (bag_menu's
; distinct-start-row scheme) so it never collides with the list box (rows 0-10).
QTY_WX          equ 287         ; ; PROJ overworld-ui GB(15,9) anchor=top-right X+20 Y+0
QTY_WY          equ 72
QTY_CLIP        equ 40
QTY_MAXY        equ 96
QTY_SROW        equ 12          ; GB_TILEMAP0 start row (below the 11-row list box)
QTY_SCRATCH     equ W_TILEMAP + QTY_SROW * LIST_STRIDE  ; scratch row == tilemap row
QTY_TOTAL_W     equ 13          ; widest (priced) box; small box clipped by window
QTY_TOTAL_H     equ 3

; charmap codes (constants/charmap.asm)
CHAR_CURSOR     equ 0xED        ; ▶
CHAR_DOWN       equ 0xEE        ; ▼ (= CHAR_DOWN_ARROW)
CHAR_SWAP_CUR   equ 0xEC        ; ▷
CHAR_TIMES      equ 0xF1        ; ×
CHAR_TERM       equ 0x50        ; '@'
TILE_BLANK      equ 0x7F        ; ' ' (charmap blank — matches copy2.asm/pokedex.asm)

; ============================================================================
section .data

; ListMenuCancelText / InitialQuantityText / SpacesBetweenQuantityAndPriceText —
; pret home/list_menu.asm. Tier-1 DATA: generated by tools/gen_list_menu_strings.py
; through gb_text.encode, never hand-encoded charmap hex (the bytes it emits are
; byte-identical to the hand-written block this replaced). Regenerate: `make assets`.
%include "assets/list_menu_strings.inc"

; ============================================================================
section .text

; ----------------------------------------------------------------------------
; DisplayListMenuID  — pret list_menu.asm:4
; In: [wListMenuID], [wListPointer] (2 bytes) = address of the list.
; ----------------------------------------------------------------------------
DisplayListMenuID:
    xor al, al
    mov [ebp + hAutoBGTransferEnabled], al   ; disable auto-transfer
    mov al, 1
    mov [ebp + hJoy7], al                     ; joypad state update flag

    mov al, [ebp + wBattleType]
    test al, al                               ; Old Man battle?  pret:.specialBattleType
    jnz .specialBattleType
    mov al, 0x01                              ; hardcoded bank
    jmp .bankswitch
.specialBattleType:
    mov al, 0x01                              ; BANK(DisplayBattleMenu) — flat: any (bookkeeping)
.bankswitch:
    call BankswitchHome                       ; flat: records requested bank only
    ; set BIT_NO_TEXT_DELAY in wStatusFlags5
    or byte [ebp + wStatusFlags5], (1 << BIT_NO_TEXT_DELAY)

    xor al, al
    mov [ebp + wMenuItemToSwap], al           ; 0 = no item being swapped
    mov [ebp + wListCount], al
    ; [wListCount] = first byte of the list (number of entries)
    movzx esi, word [ebp + wListPointer]      ; hl = list address
    mov al, [ebp + esi]
%if BUG_FIX_LEVEL >= 1
    ; Safety guard: a garbage/un-seeded list length would make the render loop
    ; iterate through memory. Clamp to the largest valid list (PC box = 50), an
    ; upper bound over every list type (party 6 / bag 20 / box 50), so a legit
    ; list is never truncated. docs/glitch_safety.md.
    cmp al, PC_ITEM_CAPACITY
    jbe .listCountOk
    mov al, PC_ITEM_CAPACITY
.listCountOk:
%endif
    mov [ebp + wListCount], al

    mov al, LIST_MENU_BOX
    mov [ebp + wTextBoxID], al                ; pret draws via DisplayTextBoxID(LIST_MENU_BOX)
    ; Stride MUST be 20 before ANY drawing into the list scratch: TextBoxBorder
    ; advances rows by [text_row_stride], and arriving from the START menu the
    ; live stride is still 40 (canvas) — drawing the border before setting it
    ; landed every other scratch row (the live bag-border corruption; the boot
    ; default of 20 is why the DEBUG_BAGMENU harness never showed it).
    ; list = single-column, entries spaced 2 rows apart; stride 20 (box-relative)
    mov dword [text_row_stride], LIST_STRIDE
    mov dword [menu_item_step], LIST_ROW_STEP * LIST_STRIDE
    ; PROJ overworld-ui: GB(4,2) 16x11 --(anchor=top-right, X+20, Y+0)--> wx=199 wy=16 clip=128 max_y=104
    ; DEVIATION{class=projection; pret=home/list_menu.asm:DisplayListMenuIDLoop; behavior=draw the list box into stride-20 scratch and publish a projected window instead of calling DisplayTextBoxID on the live tilemap; evidence=pret LIST_MENU_BOX call plus port list_draw_box_border window contract; lifetime=permanent window-compositor boundary}
    ; pret draws the box with `call DisplayTextBoxID`
    ; (LIST_MENU_BOX), which renders straight into the live GB tilemap at absolute
    ; GB(4,2). This driver instead renders the SAME border into the stride-20
    ; W_TILEMAP scratch and registers a window descriptor for it, because the port's
    ; box is a compositor window, not tilemap cells: the 40x25 canvas puts the list
    ; at a projected screen position, and the entries below are all drawn box-relative
    ; into that same scratch. wTextBoxID is still set (above) so the pret-visible
    ; state matches; only the blit path differs. list_draw_box_border is the
    ; LIST_MENU_BOX template (14x9 interior) expressed at that anchor.
    call list_draw_box_border

    ; DEVIATION{class=projection; pret=home/list_menu.asm:DisplayListMenuIDLoop; behavior=omit two UpdateSprites calls because the port window layer already occludes OBJ; evidence=pret sprite-hide calls plus port window-over-OBJ compositor order; lifetime=permanent compositor z-order boundary}
    ; pret's two `call UpdateSprites` here exist to
    ; hide OBJ that would otherwise show through the text box (pret's own comment
    ; calls the second one "useless"). The port composites the window layer OVER
    ; OBJ (inverse of GB z-order — see CLAUDE.md), so the list window occludes
    ; sprites by construction and there is nothing to hide. Eliding is not a
    ; shortcut: calling UpdateSprites here would re-publish overworld OAM under a
    ; window that already covers it. Pure GB-hardware bookkeeping, dropped.

    ; max menu item id: 1 if <2 entries, else 2                 (pret:.setMenuVariables)
    mov al, 1
    mov [ebp + wMenuWatchMovingOutOfBounds], al
    mov al, [ebp + wListCount]
    cmp al, 2
    jc .setMenuVariables
    mov al, 2
.setMenuVariables:
    mov [ebp + wMaxMenuItem], al
    ; cursor coords — PROJECTED: pret writes absolute GB (Y=4,X=5); the port's
    ; PlaceMenuCursor treats wTopMenuItem{X,Y} as box-relative offsets into the
    ; W_TILEMAP scratch (stride text_row_stride), so we store the box-relative
    ; cursor (col 1, row 2) = GB(5,4) − box-origin GB(4,2). Deviation is the
    ; window projection, not a behaviour change. ; PROJ overworld-ui (cursor)
    mov al, LIST_NAME_ROW0                     ; = 2  (pret Y=4 → box-rel 2)
    mov [ebp + wTopMenuItemY], al
    mov al, LIST_CURSOR_COL                    ; = 1  (pret X=5 → box-rel 1)
    mov [ebp + wTopMenuItemX], al
    ; (stride + menu_item_step were set above, BEFORE the border draw)

    mov al, PAD_A | PAD_B | PAD_SELECT
    mov [ebp + wMenuWatchedKeys], al
    mov bl, 10
    call DelayFrames

; ----------------------------------------------------------------------------
; DisplayListMenuIDLoop  — pret list_menu.asm:58 (also the swap_items tail target)
; ----------------------------------------------------------------------------
DisplayListMenuIDLoop:
    xor al, al
    mov [ebp + hAutoBGTransferEnabled], al    ; disable transfer
    call PrintListMenuEntries
    call list_mirror                           ; scratch box → GB_TILEMAP0
                                               ; (port window model)
    mov al, 1
    mov [ebp + hAutoBGTransferEnabled], al     ; pret fidelity only — nothing
                                               ; reads this (do_bg_transfer is
                                               ; retired; it used to smear the
                                               ; canvas over GB_TILEMAP1, the
                                               ; START-menu window source, and
                                               ; LEAKED past ExitListMenu →
                                               ; the grass-after-bag bug)
    call Delay3

    mov al, [ebp + wBattleType]
    test al, al                                ; Old Man battle? (auto-select first entry)
    jz .notOldManBattle
    ; ── Old Man battle: force-select entry 0 (pret:69-80) ────────────────────
    ; place ▶ at box-rel cursor and auto-advance. ; PROJ overworld-ui reused;
    ; TODO(proj): Old-Man battle really wants the battle anchor (+10col/+3row).
    mov byte [ebp + W_TILEMAP + LIST_NAME_ROW0 * LIST_STRIDE + LIST_CURSOR_COL], CHAR_CURSOR
    call list_mirror
    mov bl, 20
    call DelayFrames
    xor al, al
    mov [ebp + wCurrentMenuItem], al
    ; wMenuCursorLocation = W_TILEMAP box-rel cursor address (low/high byte)
    mov ax, W_TILEMAP + LIST_NAME_ROW0 * LIST_STRIDE + LIST_CURSOR_COL
    mov [ebp + wMenuCursorLocation], ax
    jmp .buttonAPressed
.notOldManBattle:
    call LoadGBPal                             ; home/fade.asm (flat palette reload)
%ifdef DEBUG_BAGMENU
    ; Fidelity Stage 4 gate: fall through into the real HandleMenuInput loop
    ; below, and let AutoKeyDrive photograph a deterministic blink phase. The
    ; previous hook dumped here, before HandleMenuInput armed the MORE-list ▼
    ; blink, so the golden's blink-OFF frame required a timing mask.
%endif
    ; per-frame mirror keeps HandleMenuInput's live cursor reaching the
    ; compositor (same mechanism as yes_no.asm's yn_mirror callback)
    mov dword [menu_redraw_cb], list_mirror
    ; Tell HandleMenuInput where this menu's "more below" ▼ actually is. pret names
    ; it as the absolute screen cell (18,11) because the list box sits at GB(4,2)
    ; and its arrow at box-relative (14,9); the port's box lives box-relative in the
    ; W_TILEMAP scratch, so it publishes the cell PrintListMenuEntries wrote. Without
    ; this the blink targeted scratch (18,11) — a cell outside the box — and was
    ; inert (menu-fidelity M-2 corrected / row 24).
    mov dword [menu_arrow_pos], W_TILEMAP + LIST_DOWN_ROW * LIST_STRIDE + LIST_DOWN_COL
    call HandleMenuInput                       ; Out: AL = watched keys pressed
    mov dword [menu_arrow_pos], 0
    mov dword [menu_redraw_cb], 0
    push eax
    call PlaceMenuCursor
    call list_mirror
    pop eax
    test al, PAD_A
    jz .checkOtherKeys

.buttonAPressed:
    mov al, [ebp + wCurrentMenuItem]
    call PlaceUnfilledArrowMenuCursor          ; home/window.asm: hollow ▶

    ; pret sets wMenuExitMethod/wChosenMenuItem=$01 here but both are overwritten
    ; before being read — faithfully harmless. Kept for fidelity.
    mov al, 0x01
    mov [ebp + wMenuExitMethod], al
    mov [ebp + wChosenMenuItem], al

    xor al, al
    mov [ebp + wMenuWatchMovingOutOfBounds], al
    ; c = wCurrentMenuItem + wListScrollOffset  (absolute index)
    mov al, [ebp + wCurrentMenuItem]
    mov bl, al                                 ; c
    mov al, [ebp + wListScrollOffset]
    add al, bl
    mov bl, al                                 ; c = absolute index
    mov al, [ebp + wListCount]
    test al, al                                ; list empty?
    jz ExitListMenu
    dec al
    cmp al, bl                                 ; player selected Cancel? (index >= count-1... via carry)
    jc ExitListMenu                            ; (count-1) < c → Cancel → exit
    mov al, bl
    mov [ebp + wWhichPokemon], al

    ; esi = list entries base; index by c (item lists: entries are 2 bytes)
    mov al, [ebp + wListMenuID]
    cmp al, ITEMLISTMENU
    jne .skipMultiplying
    add bl, bl                                 ; item entries 2 bytes → sla c
.skipMultiplying:
    movzx esi, word [ebp + wListPointer]
    inc esi                                    ; hl = beginning of list entries
    movzx ecx, bl
    add esi, ecx
    mov al, [ebp + esi]
    mov [ebp + wCurListMenuItem], al           ; == wCurItem / wCurPartySpecies

    mov al, [ebp + wListMenuID]
    test al, al                                ; PCPOKEMONLISTMENU?
    jz .pokemonList
    ; ── item menu ────────────────────────────────────────────────────────────
    push esi
    call GetItemPrice                          ; [wCurItem] → hItemPrice
    pop esi
    mov al, [ebp + wListMenuID]
    cmp al, ITEMLISTMENU
    jne .skipGettingQuantity
    inc esi
    mov al, [ebp + esi]                        ; a = item quantity
    mov [ebp + wMaxItemQuantity], al
.skipGettingQuantity:
    mov al, [ebp + wCurItem]
    mov [ebp + wNameListIndex], al
    mov al, 0x01                               ; BANK(ItemNames) — flat: bookkeeping
    mov [ebp + wPredefBank], al
    call GetName
    jmp .storeChosenEntry
.pokemonList:
    ; name of the chosen party/box mon (pret .pokemonList:149)
    ; party vs box: pret compares low([wListPointer]) against low(wPartyCount)
    ; ("cp l" with hl=wPartyCount) to pick the nick-list base.
    mov al, [ebp + wListPointer]               ; low byte of the list address
    mov esi, wPartyMonNicks
    cmp al, wPartyCount & 0xFF
    je .getPokemonName
    mov esi, wBoxMonNicks                      ; box pokemon names
.getPokemonName:
    mov al, [ebp + wWhichPokemon]
    call GetPartyMonName                       ; AL=index, ESI=nick list base
.storeChosenEntry:
    ; store chosen entry name & return (pret .storeChosenEntry:160)
    mov edx, wNameBuffer
    call CopyToStringBuffer
    mov al, CHOSE_MENU_ITEM
    mov [ebp + wMenuExitMethod], al
    mov al, [ebp + wCurrentMenuItem]
    mov [ebp + wChosenMenuItem], al
    xor al, al
    mov [ebp + hJoy7], al
    and byte [ebp + wStatusFlags5], ~(1 << BIT_NO_TEXT_DELAY)  ; res BIT_NO_TEXT_DELAY
    call BankswitchBack
    clc                                        ; CF=0: an item was chosen
    ret

.checkOtherKeys:                               ; B / SELECT / Up / Down  (pret:172)
    test al, PAD_B
    jnz ExitListMenu
    test al, PAD_SELECT
    jz .noSelect
    jmp HandleItemListSwapping                 ; SELECT: swap menu entries (swap_items.asm)
.noSelect:
    mov bl, al                                 ; b = pressed keys
    test bl, PAD_DOWN
    jz .upPressed
    ; ── Down ──
    mov al, [ebp + wListScrollOffset]
    add al, 3
    mov bl, al
    mov al, [ebp + wListCount]
    cmp al, bl                                 ; going down scroll past Cancel?
    jc DisplayListMenuIDLoop                    ; yes → don't scroll
    inc byte [ebp + wListScrollOffset]
    jmp DisplayListMenuIDLoop
.upPressed:
    mov al, [ebp + wListScrollOffset]
    test al, al
    jz DisplayListMenuIDLoop
    dec byte [ebp + wListScrollOffset]
    jmp DisplayListMenuIDLoop

; ----------------------------------------------------------------------------
; ExitListMenu  — pret list_menu.asm:320.  Cancel/empty path.  Out: CF=1.
; ----------------------------------------------------------------------------
ExitListMenu:
    mov al, [ebp + wCurrentMenuItem]
    mov [ebp + wChosenMenuItem], al
    mov al, CANCELLED_MENU
    mov [ebp + wMenuExitMethod], al
    mov [ebp + wMenuWatchMovingOutOfBounds], al
    xor al, al
    mov [ebp + hJoy7], al
    and byte [ebp + wStatusFlags5], ~(1 << BIT_NO_TEXT_DELAY)
    call BankswitchBack
    xor al, al
    mov [ebp + wMenuItemToSwap], al            ; 0 = no item being swapped
    stc                                        ; CF=1: cancelled
    ret

; ----------------------------------------------------------------------------
; DisplayChooseQuantityMenu  — pret list_menu.asm:197
; Priced-item quantity selector (×NN, and total price for PRICEDITEMLISTMENU).
; Out: A-confirm → ret ([wItemQuantity]=count, hMoney=total);
;      B-cancel  → ret with AL=$ff.
; ----------------------------------------------------------------------------
DisplayChooseQuantityMenu:
    ; text box: GB(15,9) 1x3 (quantity only) or GB(7,9) 1x11 (quantity+price).
    ; PROJ overworld-ui: GB(15,9) 5x3 --(anchor=top-right, X+20, Y+0)--> wx=287 wy=72 clip=40 max_y=96
    ; TODO(proj): PRICEDITEMLISTMENU is a Pokémart box (GB 7,9 x11) → needs the
    ; mart anchor. Deferred, and genuinely unreachable today — the only setter of
    ; PRICEDITEMLISTMENU is home/text_script.asm:DisplayPokemartDialogue, whose
    ; DisplayPokemartDialogue_ is still a ret-stub in engine/menus/main_menu_stubs.asm. So the
    ; priced branch below is reasoned from pret, NOT observed at runtime.
    mov esi, QTY_SCRATCH                       ; box-relative top-left in scratch
    mov bl, 3                                  ; interior width  (quantity only)
    mov bh, 1                                  ; interior height
    mov al, [ebp + wListMenuID]
    cmp al, PRICEDITEMLISTMENU
    jne .drawTextBox
    mov bl, 11                                 ; priced: wider box
.drawTextBox:
    call TextBoxBorder
    ; DEVIATION{class=projection; pret=home/list_menu.asm:DisplayChooseQuantityMenu; behavior=publish the quantity box as a second window stacked over the list; evidence=pret draws both boxes into one tilemap while port list_add_qty_window owns the second descriptor; lifetime=permanent window-compositor boundary}
    ; The qty box is a SECOND window stacked on the
    ; list's, so it needs its own descriptor. pret has no equivalent — on the GB
    ; both boxes are just cells in the one tilemap.
    call list_add_qty_window
    ; "×01" initial label — box-rel (col 1, row 1), same in both layouts.
    ; DEVIATION{class=data-model; pret=home/list_menu.asm:DisplayChooseQuantityMenu; behavior=place generated InitialQuantityText through a flat-pointer helper instead of a GB-address DE operand; evidence=pret PlaceString call plus generated list_menu_strings.inc flat data; lifetime=permanent flat-data boundary}
    ; pret `ld de, InitialQuantityText / call PlaceString`
    ; reads the string through the GB address space; the port's generated strings are
    ; flat .data (assets/list_menu_strings.inc), so they go through place_flat_str,
    ; which is PlaceString over a flat pointer. Same glyphs, same dest, same ESI
    ; contract — only the source address space differs.
    mov esi, QTY_SCRATCH + 1 * LIST_STRIDE + 1
    mov eax, InitialQuantityText
    call place_flat_str
    xor al, al
    mov [ebp + wItemQuantity], al              ; current quantity = 0
    jmp .incrementQuantity

.waitForKeyPressLoop:
    call qty_mirror                            ; scratch → GB_TILEMAP0 qty region
    ; DEVIATION{class=HAL; pret=home/list_menu.asm:DisplayChooseQuantityMenu; behavior=pump DelayFrame in the quantity wait loop so keyboard joypad edges and compositor presentation advance; evidence=pret direct Joypad polling plus port joypad_update and render ownership in DelayFrame; lifetime=permanent input and software-video HAL boundary}
    ; pret's wait loop has NO DelayFrame, and must not —
    ; on the GB, JoypadLowSensitivity opens with `call Joypad`, which reads the pad
    ; hardware directly, and the LCD scans the tilemap continuously, so a tight spin
    ; is both responsive and visible.
    ; In the port BOTH of those are frame-driven: joypad_update (which computes the
    ; hJoyHeld/hJoyPressed edge JoypadLowSensitivity reads) and the compositor's
    ; render+present run inside DelayFrame and NOWHERE else. Spinning without one
    ; therefore reads a frozen pad forever and never presents the box it just
    ; mirrored — i.e. the quantity selector HUNG THE GAME with its own box invisible.
    ; Reachable live: START → ITEM → TOSS (engine/menus/start_sub_menus.asm:529) and
    ; every players_pc.asm deposit/withdraw/toss. Found by DEBUG_LISTMENU_QTY, which
    ; hung identically until this call landed.
    ; This is the same pump pret's own HandleMenuInput_ loop has (and which the port
    ; mirrors in home/window.asm) — the qty loop is the one input loop that relied on
    ; the hardware instead.
    call DelayFrame
    call JoypadLowSensitivity
    movzx eax, byte [ebp + hJoyPressed]        ; newly pressed
    test al, PAD_A
    jnz .buttonAPressed
    test al, PAD_B
    jnz .buttonBPressed
    test al, PAD_UP
    jnz .incrementQuantity
    test al, PAD_DOWN
    jnz .decrementQuantity
    jmp .waitForKeyPressLoop

.incrementQuantity:
    mov al, [ebp + wMaxItemQuantity]
    inc al
    mov bl, al                                 ; b = max+1
    inc byte [ebp + wItemQuantity]
    mov al, [ebp + wItemQuantity]
    cmp al, bl
    jne .handleNewQuantity
    mov byte [ebp + wItemQuantity], 1          ; wrap above max → 1
    jmp .handleNewQuantity
.decrementQuantity:
    dec byte [ebp + wItemQuantity]
    jnz .handleNewQuantity
    mov al, [ebp + wMaxItemQuantity]           ; wrap below 1 → max
    mov [ebp + wItemQuantity], al
.handleNewQuantity:
    ; dest for the printed quantity/price
    mov al, [ebp + wListMenuID]
    cmp al, PRICEDITEMLISTMENU
    jne .printQuantity
.printPrice:
    ; total price = itemPrice * quantity  (BCD, 3 bytes)          (pret:257)
    mov bl, [ebp + wItemQuantity]              ; b = quantity (loop count)
    ; hMoney = 0
    xor al, al
    mov [ebp + hMoney], al
    mov [ebp + hMoney + 1], al
    mov [ebp + hMoney + 2], al
.addLoop:
    push ebx
    mov edx, hMoney + 2                        ; DE = hMoney+2
    mov esi, hItemPrice + 2                    ; HL = hItemPrice+2
    call AddBCDPredef                          ; hMoney += hItemPrice
    pop ebx
    dec bl
    jnz .addLoop
    mov al, [ebp + hHalveItemPrices]
    test al, al                                ; halve price (selling)?
    jz .skipHalvingPrice
    xor al, al
    mov [ebp + hDivideBCDDivisor], al
    mov [ebp + hDivideBCDDivisor + 1], al
    mov al, 0x02
    mov [ebp + hDivideBCDDivisor + 2], al
    call DivideBCDPredef3                       ; halve
    mov al, [ebp + hDivideBCDQuotient]
    mov [ebp + hMoney], al
    mov al, [ebp + hDivideBCDQuotient + 1]
    mov [ebp + hMoney + 1], al
    mov al, [ebp + hDivideBCDQuotient + 2]
    mov [ebp + hMoney + 2], al
.skipHalvingPrice:
    ; Spaces, then the total price — BOTH at box-rel (col 5, row 1).
    ; pret: `hlcoord 12,10 / PlaceString(Spaces) / PrintBCDNumber`. PlaceString
    ; returns HL at the string START (its terminator handler does `ld b,h / ld c,l
    ; / pop hl`), so pret's PrintBCDNumber prints at 12,10 — the same cell the
    ; spaces began at, blanking then overwriting that run. The port's PlaceString
    ; keeps the same contract (ESI = line start), so the price goes to (5,1) too.
    ; Priced box origin is GB(7,9): (12,10) → box-rel (5,1).
    mov esi, QTY_SCRATCH + 1 * LIST_STRIDE + 5
    mov eax, SpacesBetweenQuantityAndPriceText  ; flat .data label
    call PlaceString
    mov esi, QTY_SCRATCH + 1 * LIST_STRIDE + 5  ; pret: HL still 12,10 after PlaceString
    mov edx, hMoney
    mov bl, 3 | (1 << BIT_LEADING_ZEROES) | (1 << BIT_MONEY_SIGN)
    call PrintBCDNumber
    ; pret then does `hlcoord 9,10` for the quantity digits → box-rel (2,1).
.printQuantity:
    ; The quantity digits land at box-rel (col 2, row 1) in BOTH layouts:
    ; priced  GB(9,10)  − origin GB(7,9)  = (2,1)
    ; qty-only GB(17,10) − origin GB(15,9) = (2,1)
    ; They overwrite the "01" of the "×01" label placed at box-rel (1,1).
    mov esi, QTY_SCRATCH + 1 * LIST_STRIDE + 2
    mov edx, wItemQuantity
    mov bh, (1 << BIT_LEADING_ZEROES) | 1      ; flags|bytes: LEADING_ZEROES | 1 byte
    mov bl, 2                                  ; 2 digits
    call PrintNumber
    jmp .waitForKeyPressLoop

.buttonAPressed:                               ; confirm transaction
    xor al, al
    mov [ebp + wMenuItemToSwap], al
    ret
.buttonBPressed:                               ; cancel transaction
    xor al, al
    mov [ebp + wMenuItemToSwap], al
    mov al, 0xff
    ret

; ----------------------------------------------------------------------------
; PrintListMenuEntries — pret list_menu.asm:336
; Clears the list area and prints up to 4 entries (name [+price][+qty/level]),
; the CANCEL row, the SELECT-swap ▷ marker, and the ▼ "more below" hint.
; ----------------------------------------------------------------------------
PrintListMenuEntries:
    ; clear the list interior — box-rel (col 1, row 1), 9 rows x 14 cols
    ; (pret hlcoord 5,3 / lb bc,9,14 / ClearScreenArea).
    ; DEVIATION{class=projection; pret=home/list_menu.asm:PrintListMenuEntries; behavior=clear the stride-20 list interior inline instead of using stride-40 ClearScreenArea; evidence=pret ClearScreenArea call plus port list scratch stride contract; lifetime=until ClearScreenArea accepts an explicit stride}
    ; The port ClearScreenArea advances rows by
    ; SCREEN_WIDTH=40; this is the stride-20 list scratch, so clear inline
    ; (pokedex.asm pdex_clear_list_area / link_menu.asm precedent). The
    ; stride-40 call left interior rows 2/4/6/8 stale AND clobbered scratch
    ; rows >= 11 including the QTY box region (QTY_SROW=12).
    call list_clear_interior

    ; de = list entries base (+scroll*entrysize)
    movzx edx, word [ebp + wListPointer]
    inc edx                                    ; de = beginning of list entries
    mov al, [ebp + wListScrollOffset]
    mov cl, al                                 ; c = scroll
    mov al, [ebp + wListMenuID]
    cmp al, ITEMLISTMENU
    jne .skipMul
    add cl, cl                                 ; item entries 2 bytes → sla c
.skipMul:
    movzx ecx, cl
    add edx, ecx                               ; de += (scroll * entrysize)

    ; hl = first entry name dest — box-rel (col 2, row 2)   (pret hlcoord 6,4)
    mov esi, W_TILEMAP + LIST_NAME_ROW0 * LIST_STRIDE + LIST_NAME_COL
    ; c = the SAME scroll value the address math above consumed (sla'd for item
    ; lists) — pret never re-loads it: `ld c,a` / `sla c` leaves it in BC, and the
    ; loop then walks it as the 1-based ▷ swap-position counter. The port does the
    ; address math in ECX, so BL must be seeded from CL here or the swap compare
    ; below runs against a garbage counter.
    mov bl, cl                                 ; c = scroll (×2 on item lists)
    mov bh, 4                                  ; b = 4 names to print
.loop:
    mov al, bh
    mov [ebp + wWhichPokemon], al              ; countdown 4..1 (used by mon-name index math)
    mov al, [ebp + edx]                        ; entry id
    mov [ebp + wNamedObjectIndex], al
    cmp al, 0xff
    je .printCancelMenuItem

    push ebx
    push edx
    push esi
    ; resolve the entry name → wNameBuffer
    mov al, [ebp + wListMenuID]
    test al, al
    jz .pokemonPCMenu
    cmp al, MOVESLISTMENU
    je .movesMenu
    call GetItemName                           ; [wNamedObjectIndex] → wNameBuffer
    jmp .placeNameString
.pokemonPCMenu:
    ; party vs box nick base: pret "cp l" with hl=wPartyCount (see .pokemonList)
    mov al, [ebp + wListPointer]
    mov esi, wPartyMonNicks
    cmp al, wPartyCount & 0xFF
    je .getMonNameIndex
    mov esi, wBoxMonNicks                      ; box pokemon names
.getMonNameIndex:
    ; index = wListScrollOffset + (4 - wWhichPokemon)   (pret .pokemonPCMenu:383)
    mov al, [ebp + wWhichPokemon]
    mov bl, al
    mov al, 4
    sub al, bl
    mov bl, al
    mov al, [ebp + wListScrollOffset]
    add al, bl
    call GetPartyMonName                       ; AL=index, ESI=nick list base
    jmp .placeNameString
.movesMenu:
    call GetMoveName
.placeNameString:
    mov esi, [esp]                             ; hl = name dest (peek saved esi)
    lea eax, [ebp + wNameBuffer]               ; flat ptr to the GB-memory string
    call PlaceString

    ; price (if wPrintItemPrices) — box-rel from name (row+1, col+5) (pret bc SW+5)
    mov al, [ebp + wPrintItemPrices]
    test al, al
    jz .skipPrintingItemPrice
    mov edx, [esp + 4]                         ; saved entry ptr (pret pop de before
                                               ; the read; PlaceString clobbered EDX)
    mov al, [ebp + edx]                        ; [de] = entry id
    mov [ebp + wCurItem], al
    call GetItemPrice
    mov esi, [esp]
    add esi, LIST_STRIDE + (LIST_PRICE_COL - LIST_NAME_COL)  ; 1 row down, +5 cols
    mov edx, hItemPrice
    mov bl, 3 | (1 << BIT_LEADING_ZEROES) | (1 << BIT_MONEY_SIGN)
    call PrintBCDNumber
.skipPrintingItemPrice:

    ; pokémon level (only for PCPOKEMONLISTMENU)   (pret .skipPrintingPokemonLevel)
    mov al, [ebp + wListMenuID]
    test al, al
    jnz .skipPrintingPokemonLevel
    ; print Pokémon level (pret list_menu.asm:426-460)
    mov al, [ebp + wNamedObjectIndex]
    push eax                                   ; pret push af (restored below)
    ; party vs box data source: pret "cp l" with hl=wPartyCount; flags-preserving
    ; mov mirrors pret's "ld a, PLAYER_PARTY_DATA" before the branch.
    mov al, [ebp + wListPointer]
    cmp al, wPartyCount & 0xFF
    mov al, PLAYER_PARTY_DATA
    je .monDataLocationSet
    mov al, BOX_DATA
.monDataLocationSet:
    mov [ebp + wMonDataLocation], al
    mov al, [ebp + wWhichPokemon]
    mov bl, al
    mov al, 4
    sub al, bl
    mov bl, al
    mov al, [ebp + wListScrollOffset]
    add al, bl
    mov [ebp + wWhichPokemon], al
    call LoadMonData
    mov al, [ebp + wMonDataLocation]
    test al, al                                ; party (0) or box?
    jz .skipCopyingLevel
    mov al, [ebp + wLoadedMonBoxLevel]         ; copy box level over level
    mov [ebp + wLoadedMonLevel], al
.skipCopyingLevel:
    mov esi, [esp + 4]                         ; saved name dest (under the push eax)
    add esi, LIST_STRIDE + (LIST_INFO_COL - LIST_NAME_COL)   ; 1 row down, +8 cols
    call PrintLevel
    pop eax
    mov [ebp + wNamedObjectIndex], al          ; pret pop af / ld [wNamedObjectIndex], a
.skipPrintingPokemonLevel:

    pop esi
    pop edx
    inc edx                                    ; advance de past the name/id byte

    ; item quantity (only for ITEMLISTMENU, non-key items)   (pret:465)
    mov al, [ebp + wListMenuID]
    cmp al, ITEMLISTMENU
    jne .nextListEntry
    mov al, [ebp + wNamedObjectIndex]
    mov [ebp + wCurItem], al
    call IsKeyItem                             ; home/item_predicates.asm → [wIsKeyItem]
    mov al, [ebp + wIsKeyItem]
    test al, al                                ; unsellable?
    jnz .skipPrintingItemQuantity
    push esi
    lea esi, [esi + LIST_STRIDE + (LIST_INFO_COL - LIST_NAME_COL)]  ; row+1, col+8
    mov byte [ebp + esi], CHAR_TIMES           ; '×'
    inc esi
    mov al, [ebp + edx]                        ; quantity byte
    mov [ebp + wMaxItemQuantity], al
    mov [ebp + wTempByteValue], al             ; PrintNumber src
    push edx
    mov edx, wTempByteValue
    mov bh, 1                                  ; flags|bytes: 1 byte
    mov bl, 2                                  ; 2 digits
    call PrintNumber
    pop edx
    pop esi
.skipPrintingItemQuantity:
    inc edx                                    ; advance de past quantity byte

    ; SELECT-swap ▷ marker on the swapped item      (pret:499)
    ; ITEM LISTS ONLY — the non-item path jumped straight to .nextListEntry above,
    ; so it never runs this block: no extra c bump and no ▷. (wMenuItemToSwap is an
    ; ITEM position; a swap marker on a mon/move list would be meaningless, and the
    ; doubled c would misindex the compare.)
    ;
    ; Stack discipline is pret's, exactly: the loop-top `push bc` is popped HERE,
    ; re-pushed with c+1, and popped again by the shared tail. That is what lets the
    ; non-item path skip this block and still find one bc on the stack for the tail's
    ; own `pop bc`. Net c per entry: +2 for items, +1 otherwise.
    pop ebx                                     ; pret: pop bc  (the loop-top push)
    inc bl                                      ; c++
    push ebx                                    ; pret: push bc — the tail pops this one
    inc bl                                      ; c++ (compare value only)
    mov al, [ebp + wMenuItemToSwap]
    test al, al
    jz .nextListEntry
    add al, al
    cmp al, bl
    jne .nextListEntry
    ; mark: overwrite the char before the name with ▷
    mov byte [ebp + esi - 1], CHAR_SWAP_CUR

.nextListEntry:
    ; Shared tail — pret's single .nextListEntry. Reached from the item path by
    ; fallthrough / the two swap-check exits, and from non-item lists by the `jne`
    ; on the ITEMLISTMENU compare (which is why the `pop ebx` lives here).
    add esi, 2 * LIST_STRIDE                    ; pret: ld bc, 2*SCREEN_WIDTH / add hl,bc
    pop ebx                                     ; pret: pop bc
    inc bl                                      ; pret: inc c
    dec bh                                      ; b--
    jnz .loop
    ; ▼ "more below" hint. pret: `ld bc,-8 / add hl,bc / ld [hl],'▼'` — hl has
    ; walked to the name column of the row after the last entry (row 10, col 2 in
    ; box-rel terms), and -8 on a stride-20 line lands on row 9, col 14. Folded to
    ; the constant here; identical cell.
    mov byte [ebp + W_TILEMAP + LIST_DOWN_ROW * LIST_STRIDE + LIST_DOWN_COL], CHAR_DOWN
    ret

.printCancelMenuItem:
    ; "CANCEL" at the current running dest (esi)     (pret:520)
    ; DEVIATION{class=data-model; pret=home/list_menu.asm:PrintListMenuEntries; behavior=place generated CANCEL text through the flat-pointer helper instead of GB-address PlaceString; evidence=pret tail-jump to PlaceString plus generated ListMenuCancelText flat data; lifetime=permanent flat-data boundary}
    ; See the InitialQuantityText note in
    ; DisplayChooseQuantityMenu — generated strings live in flat .data, so PlaceString
    ; becomes place_flat_str. pret tail-calls (`jp PlaceString`); the port calls and
    ; rets, which is the same thing (PlaceString returns to this frame's caller either
    ; way and neither path reads its return registers).
    mov eax, ListMenuCancelText
    call place_flat_str
    ret

; ----------------------------------------------------------------------------
; Window helper — register the list box descriptor at the overworld-ui anchor.
; Mirrors bag_menu.asm .add_list_window (SAME projection).
; ----------------------------------------------------------------------------
list_draw_box_border:
    mov esi, W_TILEMAP                          ; box top-left in scratch
    mov bl, LIST_INT_W
    mov bh, LIST_INT_H
    call TextBoxBorder
    call hide_window                            ; reset descriptor list (count=0)
    mov eax, LIST_WX
    mov ebx, LIST_WY
    mov ecx, LIST_CLIP
    mov edx, LIST_MAXY
    mov esi, GB_TILEMAP0
    mov edi, LIST_SROW
    call add_window
    ret

list_add_qty_window:
    mov eax, QTY_WX
    mov ebx, QTY_WY
    mov ecx, QTY_CLIP
    mov edx, QTY_MAXY
    mov esi, GB_TILEMAP0
    mov edi, QTY_SROW
    call add_window
    ret

; ----------------------------------------------------------------------------
; DEVIATION{class=projection; pret=home/list_menu.asm:DisplayListMenuIDLoop; behavior=mirror staged list and quantity scratches into compositor tilemaps through port-only helpers; evidence=pret boxes are live tilemap cells while port window descriptors consume GB_TILEMAP0; lifetime=permanent window-compositor boundary}
; list_mirror / qty_mirror have no pret counterpart
; and are the reason faithdiff reports them as ADDED calls in DisplayListMenuIDLoop
; and DisplayChooseQuantityMenu.
; Mirror helpers — copy the staged boxes from the W_TILEMAP scratch (stride 20)
; into their GB_TILEMAP0 regions (stride 32) so the window compositor sees them.
; On the GB there is nothing to mirror: pret's boxes ARE tilemap cells, drawn in
; place, and the hardware BG transfer publishes them. The port stages every menu
; box in a GB-shaped stride-20 scratch (so pret's box-relative coordinate math
; ports verbatim) and then blits it to the window the compositor reads — explicit
; mirrors are the port's ONLY WRAM→tilemap path, since the legacy do_bg_transfer
; is retired. Same mechanism as bag_menu .copy_box / yes_no yn_mirror.
; list_mirror doubles as the HandleMenuInput menu_redraw_cb, so it preserves
; all registers.
; ----------------------------------------------------------------------------
; list_clear_interior — clear the LIST_INT_H×LIST_INT_W (9×14) list interior at
; box-rel (1,1) on the stride-20 scratch (stands in for pret's ClearScreenArea,
; which the port bakes to stride 40 — see the DEVIATION note at the call site).
; Preserves every register the caller holds live.
; ----------------------------------------------------------------------------
list_clear_interior:
    push eax
    push ecx
    push edx
    push edi
    lea edi, [ebp + W_TILEMAP + 1 * LIST_STRIDE + 1]
    mov dl, LIST_INT_H                          ; 9 rows
    mov al, TILE_BLANK
.row:
    mov ecx, LIST_INT_W                         ; 14 cols
    rep stosb
    add edi, LIST_STRIDE - LIST_INT_W           ; next row, same column
    dec dl
    jnz .row
    pop edi
    pop edx
    pop ecx
    pop eax
    ret

list_mirror:
    pushad
    xor ebx, ebx                                ; row 0..LIST_TOTAL_H-1
.row:
    mov esi, ebx
    imul esi, esi, LIST_STRIDE
    lea esi, [ebp + esi + W_TILEMAP]
    mov edi, ebx
    shl edi, 5                                  ; row*32
    lea edi, [ebp + edi + GB_TILEMAP0 + LIST_SROW * 32]
    mov ecx, LIST_TOTAL_W
    rep movsb
    inc ebx
    cmp ebx, LIST_TOTAL_H
    jb .row
    popad
    ret

qty_mirror:
    pushad
    xor ebx, ebx                                ; row 0..QTY_TOTAL_H-1
.row:
    mov esi, ebx
    imul esi, esi, LIST_STRIDE
    lea esi, [ebp + esi + QTY_SCRATCH]
    mov edi, ebx
    shl edi, 5
    lea edi, [ebp + edi + GB_TILEMAP0 + QTY_SROW * 32]
    mov ecx, QTY_TOTAL_W
    rep movsb
    inc ebx
    cmp ebx, QTY_TOTAL_H
    jb .row
    popad
    ret
