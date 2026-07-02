; start_sub_menus.asm — StartMenu_* dispatch targets (menus-port Sessions 4+5).
; Faithful port of pret engine/menus/start_sub_menus.asm — Session-4 scope is
; StartMenu_Item + ItemMenuLoop (the bag, realigned onto the generic
; DisplayListMenuID / DisplayTextBoxID / swap_items drivers, replacing the
; bespoke bag_menu.asm); Session-5 scope is StartMenu_Pokemon (the party menu
; dispatcher: DisplayPartyMenu → FIELD_MOVE_MON_MENU pop-up → HandleMenuInput
; → CANCEL/SWITCH/STATS/field-move routing) + the SwitchPartyMon family +
; ErasePartyMenuCursors. The remaining StartMenu_* entries are thin seams:
;   StartMenu_Pokedex      — STUB(S6/S8: pokedex package)
;   StartMenu_TrainerInfo  — STUB(S6: draw_badges package / S9 trainer card)
;   StartMenu_SaveReset    — STUB(S7: save package)
;   StartMenu_Option       — STUB(S6: options package)
; Session 9 replaces the stubs when it wires all packages (see
; docs/current_plan_menus.md); each stub returns to RedisplayStartMenu, which
; is also pret's no-op-path behavior.
;
; Field-move pop-up (port model): DisplayTextBoxID(FIELD_MOVE_MON_MENU) draws
; the box on the 40-wide canvas at the UI_FIELD_MOVE_MON_MENU anchor (S2's
; DisplayFieldMoveMonMenu); fm_show_window mirrors the box rect to GB_TILEMAP0
; and appends a window at the anchor's right/bottom placement (the box grows
; up/left with the mon's field moves, exactly pret's geometry, so the window
; rect is derived from the same wFieldMoves/wFieldMovesLeftmostXCoord math).
; The canvas rows the box occupies (canvas bytes >= 360) never alias the
; stride-20 party scratch (bytes 0-359), so the panel needs no save/restore —
; pret's SaveScreenTilesToBuffer1/LoadScreenTilesFromBuffer1 collapse to
; append/drop of the pop-up window descriptor.
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
global ErasePartyMenuCursors
global SwitchPartyMon
global SwitchPartyMon_InitVarOrSwapData

extern RedisplayStartMenu            ; home/start_menu.asm
extern CloseStartMenu
extern DisplayPartyMenu              ; home/pokemon.asm (S5)
extern GoBackToPartyMenu
extern RedrawPartyMenu_              ; engine/menus/party_menu.asm
extern GBPalWhiteOutWithDelay3       ; home/fade.asm
extern RestoreScreenTilesAndReloadTilePatterns
extern LoadGBPal
extern LoadTilesetTilePatternData    ; engine/overworld/overworld.asm — map tileset reload
extern g_bg_whiteout                 ; ppu/ppu.asm
extern AddNTimes                     ; home/array.asm — ESI += BX × AL
extern SkipFixedLengthTextEntries    ; home/array.asm — ESI += NAME_LENGTH × AL
extern CopyData                      ; home/copy_data.asm — ESI→EDX, BX bytes
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
; DisplayPartyMenu → on chosen mon, the FIELD_MOVE_MON_MENU pop-up →
; HandleMenuInput → dispatch CANCEL / SWITCH / STATS / field move.
; ---------------------------------------------------------------------------
StartMenu_Pokemon:
    mov al, [ebp + wPartyCount]
    test al, al                         ; and a
    jz RedisplayStartMenu               ; jp z — empty party → straight back
    xor al, al
    mov [ebp + wMenuItemToSwap], al
    mov [ebp + wPartyMenuTypeOrMessageID], al
    mov [ebp + W_UPDATE_SPRITES_ENABLED], al
    call DisplayPartyMenu
    jmp .checkIfPokemonChosen           ; jr
.loop:
    xor al, al
    mov [ebp + wMenuItemToSwap], al
    mov [ebp + wPartyMenuTypeOrMessageID], al
    call GoBackToPartyMenu
.checkIfPokemonChosen:
    jnc .chosePokemon                   ; jr nc
.exitMenu:
    call GBPalWhiteOutWithDelay3
    call RestoreScreenTilesAndReloadTilePatterns
    call LoadGBPal
    ; port(window model) exit restores: the party takeover's white field goes
    ; away with it, and the map tileset tiles the BG icons overwrote come back
    ; (DEVIATION(icons): pret's icons live in OAM VRAM, restored inside
    ; RestoreScreenTilesAndReloadTilePatterns via ReloadMapSpriteTilePatterns;
    ; the box tiles the HP-bar set clobbered are restored there too, via its
    ; LoadTextBoxTilePatterns).
    mov dword [g_bg_whiteout], 0
    call LoadTilesetTilePatternData
    jmp RedisplayStartMenu              ; jp RedisplayStartMenu
.chosePokemon:
    ; call SaveScreenTilesToBuffer1 — port(window model): the pop-up is its
    ; own window over an untouched panel scratch; nothing to save (see header)
    mov byte [ebp + wTextBoxID], FIELD_MOVE_MON_MENU
    call DisplayTextBoxID               ; display pokemon menu options (canvas)
    call fm_show_window                 ; port: bridge the canvas box → window
    ; walk wFieldMoves to grow the menu vars: b = max item, c = top Y
    mov esi, wFieldMoves                ; ld hl,wFieldMoves
    mov bh, 2                           ; lb bc, 2, 12
    mov bl, 12
    mov dl, 5                           ; ld e,5
.adjustMenuVariablesLoop:
    dec dl                              ; dec e
    jz .storeMenuVariables
    mov al, [ebp + esi]                 ; ld a,[hli]
    inc esi
    test al, al                         ; end of field moves?
    jz .storeMenuVariables
    inc bh                              ; inc b
    sub bl, 2                           ; dec c / dec c
    jmp .adjustMenuVariablesLoop
.storeMenuVariables:
    ; PROJ menus: the pop-up lives on the 40-wide canvas at the
    ; UI_FIELD_MOVE_MON_MENU anchor — pret's cursor coords (Y=c,
    ; X=hFieldMoveMonMenuTopMenuItemX) shift by the same FM_ROW/COL deltas
    ; the box was drawn with (S2 DisplayFieldMoveMonMenu convention: the
    ; hFieldMove… X stays GB-space; consumers project at placement)
    mov al, bl
    add al, FM_ROW_SHIFT
    mov [ebp + wTopMenuItemY], al       ; ld [hli],a — top menu item Y
    mov al, [ebp + hFieldMoveMonMenuTopMenuItemX]
    add al, FM_COL_SHIFT
    mov [ebp + wTopMenuItemX], al       ; ld [hli],a — top menu item X
    xor al, al
    mov [ebp + wCurrentMenuItem], al    ; ld [hli],a
    mov al, bh
    mov [ebp + wMaxMenuItem], al        ; ld [hli],a
    mov byte [ebp + wMenuWatchedKeys], PAD_A | PAD_B
    mov byte [ebp + wLastMenuItem], 0   ; xor a / ld [hl],a
    ; port: cursor moves on the canvas while the pop-up is up
    mov dword [text_row_stride], SCREEN_TILES_W
    mov dword [menu_item_step], 2 * SCREEN_TILES_W
    mov dword [menu_redraw_cb], fm_mirror
    call HandleMenuInput
    mov dword [menu_redraw_cb], 0
    mov dword [text_row_stride], 20     ; back to the stride-20 scratch
    mov dword [menu_item_step], 2 * 20
    mov bl, al                          ; keep the pressed keys
    ; call LoadScreenTilesFromBuffer1 — port: drop the pop-up window instead
    call fm_drop_window
    test bl, PAD_B                      ; bit B_PAD_B,a
    jnz .loop                           ; jp nz
    ; if the B button wasn't pressed
    mov ah, [ebp + wMaxMenuItem]        ; ld b,a
    mov al, [ebp + wCurrentMenuItem]    ; menu selection
    cmp al, ah                          ; cp b
    jz .exitMenu                        ; jp z — the player chose Cancel
    dec ah
    cmp al, ah
    jz .choseSwitch                     ; jr z
    dec ah
    cmp al, ah
    jz .choseStats                      ; jp z
    ; chose a field move (pret .choseOutOfBattleMove):
    ; STUB(field-effects): pret indexes wFieldMoves[wCurrentMenuItem] and
    ; dispatches .outOfBattleMovePointers (cut/fly/surf/surf/strength/flash/
    ; dig/teleport/softboiled) with wObtainedBadges gating + PrintText
    ; refusals. None of the field effects (UsedCut, ChooseFlyDestination,
    ; UseItem, PrintStrengthText, …) are ported yet — the selection re-enters
    ; the party menu, the shape of pret's refusal paths (jp .loop).
    jmp .loop
.choseSwitch:
    mov al, [ebp + wPartyCount]
    cmp al, 2                           ; more than one pokemon in the party?
    jc StartMenu_Pokemon                ; jp c — if not, no switching
    call SwitchPartyMon_InitVarOrSwapData ; init [wMenuItemToSwap]
    mov byte [ebp + wPartyMenuTypeOrMessageID], SWAP_MONS_PARTY_MENU
    call GoBackToPartyMenu
    jmp .checkIfPokemonChosen           ; jp
.choseStats:
    ; STUB(pokemon_behavior): predef StatusScreen / StatusScreen2 —
    ; current_plan_pokemon_behavior.md owns the status screen and its Stage 4
    ; wiring is still open. pret: ClearSprites / wMonDataLocation=0 /
    ; StatusScreen / StatusScreen2 / ReloadMapData / jp StartMenu_Pokemon;
    ; until it lands, STATS re-enters the party menu directly.
    jmp StartMenu_Pokemon

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

; ===========================================================================
; Field-move pop-up window bridge (S5). The box itself is drawn by S2's
; DisplayFieldMoveMonMenu on the 40-wide canvas; these routines recover its
; rect from the same wFieldMoves/wFieldMovesLeftmostXCoord state, mirror it
; to GB_TILEMAP0 rows 0.., and place a right/bottom-anchored window.
; PROJ menus: GB(11,11) 9x7 --(anchor=right/bottom)--> wx=255 wy=144 clip=72
;   max_y=200 [UI_FIELD_MOVE_MON_MENU_*]; a box grown by n field moves keeps
;   the same right/bottom anchor: wx = RENDER_W+7 - W*8, wy = RENDER_H - H*8
;   (W=9,H=7 lands exactly on UI_FIELD_MOVE_MON_MENU_WX/WY).
; ===========================================================================
FM_COL_SHIFT equ UI_FIELD_MOVE_MON_MENU_COL - UI_FIELD_MOVE_MON_MENU_GBX
FM_ROW_SHIFT equ UI_FIELD_MOVE_MON_MENU_ROW - UI_FIELD_MOVE_MON_MENU_GBY

section .bss
align 4
fm_left:      resd 1               ; pop-up rect, GB coords / tiles
fm_top:       resd 1
fm_w:         resd 1
fm_h:         resd 1
fm_saved_wc:  resd 1               ; g_window_count before the pop-up appended

section .text

fm_show_window:
    ; n = nonzero entries in wFieldMoves (wNumFieldMoves is consumed/zeroed by
    ; the draw itself, so recount — the same walk pret's menu-var loop does)
    xor ecx, ecx
    xor eax, eax
.count:
    cmp byte [ebp + eax + wFieldMoves], 0
    jz .counted
    inc ecx
    inc eax
    cmp eax, 4
    jb .count
.counted:
    test ecx, ecx
    jnz .dynamic
    ; no field moves: the static template box, GB (11,11) 9×7
    mov eax, UI_FIELD_MOVE_MON_MENU_GBX
    mov ebx, UI_FIELD_MOVE_MON_MENU_GBY
    mov edx, UI_FIELD_MOVE_MON_MENU_GBW
    mov esi, UI_FIELD_MOVE_MON_MENU_GBH
    jmp .have
.dynamic:
    ; DisplayFieldMoveMonMenu's geometry: left = leftmostX-1, interior width
    ; 19-leftmostX (total W = 21-leftmostX), box grown 2 rows per move above
    ; row 11 plus one blank row (top = 10-2n, total H = 8+2n)
    movzx eax, byte [ebp + wFieldMovesLeftmostXCoord]
    mov edx, 21
    sub edx, eax                        ; W
    dec eax                             ; left
    mov ebx, 10
    sub ebx, ecx
    sub ebx, ecx                        ; top = 10 - 2n
    lea esi, [ecx * 2 + 8]              ; H = 8 + 2n
.have:
    mov [fm_left], eax
    mov [fm_top], ebx
    mov [fm_w], edx
    mov [fm_h], esi
    call fm_mirror
    mov eax, [g_window_count]
    mov [fm_saved_wc], eax
    mov ecx, [fm_w]
    shl ecx, 3                          ; clip = W*8
    mov eax, RENDER_W + 7
    sub eax, ecx                        ; wx (right-anchored)
    mov ebx, [fm_h]
    shl ebx, 3
    neg ebx
    add ebx, RENDER_H                   ; wy = RENDER_H - H*8 (bottom-anchored)
    mov edx, UI_FIELD_MOVE_MON_MENU_MAXY
    mov esi, GB_TILEMAP0
    xor edi, edi                        ; source rows 0..H-1
    call add_window
    ret

; blit the pop-up's canvas rect → GB_TILEMAP0 rows 0.. — doubles as the
; menu_redraw_cb while the pop-up input runs (live cursor). Registers preserved.
fm_mirror:
    pushad
    mov edx, [fm_top]
    add edx, FM_ROW_SHIFT
    imul edx, edx, SCREEN_TILES_W
    add edx, [fm_left]
    add edx, FM_COL_SHIFT               ; canvas byte offset of the box rect
    xor ebx, ebx
.row:
    cmp ebx, [fm_h]
    jae .done
    mov esi, ebx
    imul esi, esi, SCREEN_TILES_W
    add esi, edx
    lea esi, [ebp + esi + W_TILEMAP]
    mov edi, ebx
    shl edi, 5
    lea edi, [ebp + edi + GB_TILEMAP0]
    mov ecx, [fm_w]
    rep movsb
    inc ebx
    jmp .row
.done:
    popad
    ret

; drop the pop-up window (pret's LoadScreenTilesFromBuffer1 analog). Clobbers EAX.
fm_drop_window:
    mov eax, [fm_saved_wc]
    mov [g_window_count], eax
    ret

; ---------------------------------------------------------------------------
; ErasePartyMenuCursors — pret ref: start_sub_menus.asm:ErasePartyMenuCursors.
; writes a blank tile to all possible menu cursor positions on the party menu
; (stride-20 scratch; positions are (0,1) + 2 rows apart). Clobbers ESI/ECX/AL.
; ---------------------------------------------------------------------------
ErasePartyMenuCursors:
    mov esi, W_TILEMAP + 1 * 20         ; hlcoord 0,1
    mov ecx, 6                          ; ld a,6 — 6 menu cursor positions
.loop:
    mov byte [ebp + esi], TILE_SPC      ; ld [hl],' '
    add esi, 2 * 20                     ; ld bc,2*SCREEN_WIDTH — 2 rows apart
    dec ecx
    jnz .loop
    ret

; ---------------------------------------------------------------------------
; SwitchPartyMon — pret ref: start_sub_menus.asm:SwitchPartyMon. Second A
; press of a swap: exchange the data, clear both mons' rows, full redraw.
; ---------------------------------------------------------------------------
SwitchPartyMon:
    call SwitchPartyMon_InitVarOrSwapData ; swap data
    mov al, [ebp + wSwappedMenuItem]
    call SwitchPartyMon_ClearGfx
    mov al, [ebp + wCurrentMenuItem]
    call SwitchPartyMon_ClearGfx
    jmp RedrawPartyMenu_                ; jp RedrawPartyMenu_

; In: AL = party slot. Clears the slot's two scratch rows.
; DEVIATION(icons): pret also parks the slot's 4 OAM icon sprites offscreen —
; the port's BG icons live in the rows just cleared and RedrawPartyMenu_
; re-places them.
SwitchPartyMon_ClearGfx:
    push eax                            ; push af
    push ecx
    push edi
    movzx eax, al
    imul eax, eax, 2 * 20               ; hlcoord 0,0 + AddNTimes(2*SCREEN_WIDTH)
    lea edi, [ebp + eax + W_TILEMAP]
    mov ecx, 2 * 20                     ; ld c,SCREEN_WIDTH*2
    mov al, TILE_SPC                    ; ld a,' '
    rep stosb                           ; .clearMonBGLoop
    pop edi
    pop ecx
    ; call WaitForSoundToFinish / ld a,SFX_SWAP / jp PlaySound — TODO-HW:
    ; audio HAL (Phase 3)
    pop eax                             ; pop af
    ret

; ---------------------------------------------------------------------------
; SwitchPartyMon_InitVarOrSwapData — pret ref:
; start_sub_menus.asm:SwitchPartyMon_InitVarOrSwapData.
; First call arms [wMenuItemToSwap] (1-based); the second swaps species byte,
; 44-byte structs, OT names and nicknames through wSwitchPartyMonTempBuffer.
; ---------------------------------------------------------------------------
SwitchPartyMon_InitVarOrSwapData:
    mov al, [ebp + wMenuItemToSwap]
    test al, al                         ; initialised yet?
    jnz .pickedMonsToSwap
    ; if not, initialise it so that it matches the current mon
    mov al, [ebp + wWhichPokemon]
    inc al                              ; counts from 1
    mov [ebp + wMenuItemToSwap], al
    ret
.pickedMonsToSwap:
    xor al, al
    mov [ebp + wPartyMenuTypeOrMessageID], al
    mov al, [ebp + wMenuItemToSwap]
    dec al
    mov ah, al                          ; ld b,a — 0-based armed index
    mov al, [ebp + wCurrentMenuItem]
    mov [ebp + wSwappedMenuItem], al
    cmp al, ah                          ; swapping a mon with itself?
    jnz .swappingDifferentMons
    ; can't swap a mon with itself
    xor al, al
    mov [ebp + wMenuItemToSwap], al
    mov [ebp + wPartyMenuTypeOrMessageID], al
    ret
.swappingDifferentMons:
    mov al, ah                          ; ld a,b
    mov [ebp + wMenuItemToSwap], al     ; now the 0-based partner index
    push esi                            ; push hl
    push edx                            ; push de
    push ebx
    ; swap the wPartySpecies bytes through hSwapTemp
    movzx esi, byte [ebp + wCurrentMenuItem]
    add esi, wPartySpecies
    movzx edx, byte [ebp + wMenuItemToSwap]
    add edx, wPartySpecies
    mov al, [ebp + esi]
    mov [ebp + hSwapTemp], al           ; ldh [hSwapTemp],a
    mov al, [ebp + edx]
    mov [ebp + esi], al
    mov al, [ebp + hSwapTemp]
    mov [ebp + edx], al
    ; swap the 44-byte party structs: cur → temp, partner → cur, temp → partner
    mov esi, wPartyMons
    mov bx, PARTYMON_STRUCT_LENGTH
    mov al, [ebp + wCurrentMenuItem]
    call AddNTimes
    push esi
    mov edx, wSwitchPartyMonTempBuffer
    mov bx, PARTYMON_STRUCT_LENGTH
    call CopyData
    mov esi, wPartyMons
    mov bx, PARTYMON_STRUCT_LENGTH
    mov al, [ebp + wMenuItemToSwap]
    call AddNTimes
    pop edx                             ; pop de — dest = cur struct
    push esi
    mov bx, PARTYMON_STRUCT_LENGTH
    call CopyData
    pop edx                             ; pop de — dest = partner struct
    mov esi, wSwitchPartyMonTempBuffer
    mov bx, PARTYMON_STRUCT_LENGTH
    call CopyData
    ; swap the OT names
    mov esi, wPartyMonOT
    mov al, [ebp + wCurrentMenuItem]
    call SkipFixedLengthTextEntries
    push esi
    mov edx, wSwitchPartyMonTempBuffer
    mov bx, NAME_LENGTH
    call CopyData
    mov esi, wPartyMonOT
    mov al, [ebp + wMenuItemToSwap]
    call SkipFixedLengthTextEntries
    pop edx
    push esi
    mov bx, NAME_LENGTH
    call CopyData
    pop edx
    mov esi, wSwitchPartyMonTempBuffer
    mov bx, NAME_LENGTH
    call CopyData
    ; swap the nicknames
    mov esi, wPartyMonNicks
    mov al, [ebp + wCurrentMenuItem]
    call SkipFixedLengthTextEntries
    push esi
    mov edx, wSwitchPartyMonTempBuffer
    mov bx, NAME_LENGTH
    call CopyData
    mov esi, wPartyMonNicks
    mov al, [ebp + wMenuItemToSwap]
    call SkipFixedLengthTextEntries
    pop edx
    push esi
    mov bx, NAME_LENGTH
    call CopyData
    pop edx
    mov esi, wSwitchPartyMonTempBuffer
    mov bx, NAME_LENGTH
    call CopyData
    mov al, [ebp + wMenuItemToSwap]
    mov [ebp + wSwappedMenuItem], al
    xor al, al
    mov [ebp + wMenuItemToSwap], al
    mov [ebp + wPartyMenuTypeOrMessageID], al
    pop ebx
    pop edx                             ; pop de
    pop esi                             ; pop hl
    ret
