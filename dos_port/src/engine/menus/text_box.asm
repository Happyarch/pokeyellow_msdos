; ===========================================================================
; text_box.asm — DisplayTextBoxID_ dispatcher + text-box tables + handlers.
; Faithful port of pret engine/menus/text_box.asm + data/text_boxes.asm
; (menus-port Session 2, docs/current_plan_menus.md).
;
;   DisplayTextBoxID_        — [wTextBoxID] → function / coord / text+coord table
;   SearchTextBoxTable       — $FF-terminated table scan (stride in DE)
;   GetTextBoxIDCoords / GetTextBoxIDText / GetAddressOfScreenCoords
;   DisplayMoneyBox / DoBuySellQuitMenu
;   DisplayFieldMoveMonMenu / GetMonFieldMoves (+ PokemonMenuEntries)
;
; The TWO_OPTION_MENU path dispatches to DisplayTwoOptionMenu in
; src/home/yes_no.asm — the ONE two-option implementation (S2 reconciliation;
; this file deliberately does NOT carry a second copy).
;
; ── UI PROJECTION (docs/ui_projection.md) — canvas model ────────────────────
; ; PROJ menus: all table geometry comes from assets/ui_layout_menus.inc
; (UI_* equates, generated from the frozen sidecar — never bare literals).
; The tables hold coordinates PRE-PROJECTED onto the port's 40×25 W_TILEMAP
; canvas (pret's 20×18 wTileMap screen coords mapped by the per-element anchor
; rules recorded in the .inc). DisplayTextBoxID_ therefore runs in the port's
; full-canvas contexts (render_bg view-ptr = 0: battle, mart, full-screen
; menus) where W_TILEMAP at stride 40 IS the screen — the same model the
; battle front-end uses (battle_menu.asm). It forces text_row_stride = 40 for
; the duration of the dispatch (saved/restored) so TextBoxBorder / PlaceString
; row-advance matches the canvas.
; NOTE: the battle engine hand-draws its own boxes at the battle-center
; projection (+10/+3); its MESSAGE_BOX sits at canvas row 15, while this
; table's MESSAGE_BOX row 19 is the overworld/menu bottom-anchored dialog
; position (= the wy=152 dialog window). Both are recorded in the .inc.
;
; Register map (CLAUDE.md): A=AL, BC=BX (B=BH, C=BL), DE=DX, HL=ESI,
; EBP = GB base; GB memory = [EBP+addr]. Tables/strings are program .data →
; read FLAT (no EBP bias); 16-bit pret table pointers widen to dd flat labels
; (function table stride 3→5, text+coord stride 9→11).
;
; Build (standalone check):
;   nasm -f coff -I include/ -I . -o /dev/null src/engine/menus/text_box.asm
; ===========================================================================

%include "gb_memmap.inc"
%include "gb_constants.inc"

bits 32

global DisplayTextBoxID_
global SearchTextBoxTable
global GetTextBoxIDCoords
global GetAddressOfScreenCoords
global DisplayMoneyBox
global DoBuySellQuitMenu
global DisplayFieldMoveMonMenu
global GetMonFieldMoves
global PokemonMenuEntries               ; S5 rebases party_menu's pop-up onto this

extern DisplayTwoOptionMenu             ; home/yes_no.asm — the ONE two-option impl
extern DisplayTextBoxID                 ; home/textbox.asm — pret home wrapper
extern TextBoxBorder                    ; text.asm — ESI=top-left, BL=int_w, BH=int_h
extern PlaceString                      ; text.asm — EAX=flat src, ESI=dest
extern text_row_stride                  ; text.asm — active W_TILEMAP row stride
extern UpdateSprites                    ; engine/overworld/movement.asm (gated on wUpdateSpritesEnabled)
extern ClearScreenArea                  ; home/copy2.asm — ESI=top-left, BH=rows, BL=cols (stride 40)
extern PrintBCDNumber                   ; home/print_bcd.asm — ESI=dest, EDX=src, BL=flags|len
extern HandleMenuInput                  ; home/window.asm — AL = watched keys pressed
extern PlaceUnfilledArrowMenuCursor     ; home/window.asm — ▷ at wMenuCursorLocation
extern menu_item_step                   ; home/window.asm — cursor per-item row step (bytes)
extern AddNTimes                        ; home/array.asm — ESI += BX * AL
extern FieldMoveDisplayData             ; engine/menus/field_moves.asm (flat, $FF-term, 3-byte recs)
extern FieldMoveNames                   ; engine/menus/field_moves.asm (flat, '@'-term, 1-based)

; ===========================================================================
section .data
align 4

; UI_* equates + the generated (projected) TextBoxCoordTable. Tier-1 machine
; output — regenerate via `make assets`, never edit (docs/current_plan_menus.md).
%include "assets/ui_layout_menus.inc"
; Battle-owned geometry for the BATTLE/SAFARI menu template rows (equates
; only — the battle layout single-sources the action-menu box; see
; docs/plans/battle_ui.md B5).
%define UI_LAYOUT_EQUATES_ONLY 1
%include "assets/ui_layout_battle.inc"

; ---------------------------------------------------------------------------
; TextBoxFunctionTable — pret data/text_boxes.asm:TextBoxFunctionTable.
; pret dbw (id + 16-bit ptr, stride 3) → db + dd flat ptr (stride 5).
; ---------------------------------------------------------------------------
TextBoxFunctionTable:
    db MONEY_BOX
    dd DisplayMoneyBox
    db BUY_SELL_QUIT_MENU
    dd DoBuySellQuitMenu
    db FIELD_MOVE_MON_MENU
    dd DisplayFieldMoveMonMenu
    db 0xFF                             ; end

; ---------------------------------------------------------------------------
; TextBoxTextAndCoordTable — pret data/text_boxes.asm:TextBoxTextAndCoordTable.
; Geometry = UI_* equates (projected canvas coords, incl. text TX/TY); text
; pointer widens to dd flat (stride 9 → 11).
; DEVIATION: JP_* rows omitted (JP-only templates not shipped in the EN port —
; same policy as the S1 layout seeder).
; ---------------------------------------------------------------------------
%macro text_box_text 8                  ; id, x1, y1, x2, y2, text, tx, ty
    db %1
    db %2, %3, %4, %5
    dd %6
    db %7, %8
%endmacro

TextBoxTextAndCoordTable:
    text_box_text USE_TOSS_MENU_TEMPLATE, \
        UI_USE_TOSS_MENU_TEMPLATE_COL, UI_USE_TOSS_MENU_TEMPLATE_ROW, \
        UI_USE_TOSS_MENU_TEMPLATE_X2, UI_USE_TOSS_MENU_TEMPLATE_Y2, \
        UseTossText, UI_USE_TOSS_MENU_TEMPLATE_TX, UI_USE_TOSS_MENU_TEMPLATE_TY
    ; PROJ battle: box = UI_ACTION_MENU_BOX, labels = UI_ACTION_TEXT
    ; (battle-sidecar-owned; the menus sidecar no longer carries this row)
    text_box_text BATTLE_MENU_TEMPLATE, \
        UI_ACTION_MENU_BOX_COL, UI_ACTION_MENU_BOX_ROW, \
        UI_ACTION_MENU_BOX_X2, UI_ACTION_MENU_BOX_Y2, \
        BattleMenuText, UI_ACTION_TEXT_COL, UI_ACTION_TEXT_ROW
    ; PROJ battle: safari uses the full dialog box + UI_SAFARI_TEXT labels
    text_box_text SAFARI_BATTLE_MENU_TEMPLATE, \
        UI_DIALOG_BOX_COL, UI_DIALOG_BOX_ROW, \
        UI_DIALOG_BOX_X2, UI_DIALOG_BOX_Y2, \
        SafariZoneBattleMenuText, UI_SAFARI_TEXT_COL, UI_SAFARI_TEXT_ROW
    text_box_text SWITCH_STATS_CANCEL_MENU_TEMPLATE, \
        UI_SWITCH_STATS_CANCEL_MENU_TEMPLATE_COL, UI_SWITCH_STATS_CANCEL_MENU_TEMPLATE_ROW, \
        UI_SWITCH_STATS_CANCEL_MENU_TEMPLATE_X2, UI_SWITCH_STATS_CANCEL_MENU_TEMPLATE_Y2, \
        SwitchStatsCancelText, UI_SWITCH_STATS_CANCEL_MENU_TEMPLATE_TX, UI_SWITCH_STATS_CANCEL_MENU_TEMPLATE_TY
    text_box_text BUY_SELL_QUIT_MENU_TEMPLATE, \
        UI_BUY_SELL_QUIT_MENU_TEMPLATE_COL, UI_BUY_SELL_QUIT_MENU_TEMPLATE_ROW, \
        UI_BUY_SELL_QUIT_MENU_TEMPLATE_X2, UI_BUY_SELL_QUIT_MENU_TEMPLATE_Y2, \
        BuySellQuitText, UI_BUY_SELL_QUIT_MENU_TEMPLATE_TX, UI_BUY_SELL_QUIT_MENU_TEMPLATE_TY
    text_box_text MONEY_BOX_TEMPLATE, \
        UI_MONEY_BOX_TEMPLATE_COL, UI_MONEY_BOX_TEMPLATE_ROW, \
        UI_MONEY_BOX_TEMPLATE_X2, UI_MONEY_BOX_TEMPLATE_Y2, \
        MoneyText, UI_MONEY_BOX_TEMPLATE_TX, UI_MONEY_BOX_TEMPLATE_TY
    db 0xFF                             ; end

; ---------------------------------------------------------------------------
; Menu strings — pret data/text_boxes.asm (+ PokemonMenuEntries / CurrencyString
; from engine/menus/text_box.asm). Tier-1 DATA: generated by
; tools/gen_textbox_strings.py through gb_text.encode, never hand-encoded
; charmap hex (the bytes it emits are byte-identical to the hand-written block
; this replaced). Regenerate via `make assets`.
; DEVIATION(en-only): the JP-only strings are omitted, with the JP table rows.
; ---------------------------------------------------------------------------
%include "assets/textbox_strings.inc"

; ===========================================================================
section .text

; ---------------------------------------------------------------------------
; DisplayTextBoxID_ — draw the text box selected by [wTextBoxID].
; pret ref: engine/menus/text_box.asm:DisplayTextBoxID_
; In:  [wTextBoxID]. TWO_OPTION_MENU additionally consumes the yes_no.asm box
;      parameters (yn_box_col/row via its entry points) — DEVIATION: the port's
;      DisplayTwoOptionMenu takes its box position from yes_no.asm state, not
;      pret's b/c/hl register triple (window-projected model, see yes_no.asm).
; Out: table paths draw into W_TILEMAP (canvas); function handlers as pret
;      (DoBuySellQuitMenu returns CF + wChosenMenuItem/wMenuExitMethod).
; ---------------------------------------------------------------------------
DisplayTextBoxID_:
    ; ld a,[wTextBoxID] / cp TWO_OPTION_MENU / jp z,DisplayTwoOptionMenu
    mov al, [ebp + wTextBoxID]
    cmp al, TWO_OPTION_MENU
    je DisplayTwoOptionMenu             ; ONE implementation (home/yes_no.asm)
    mov bl, al                          ; ld c,a — id to match

    ; PROJ menus: table coords are canvas-projected (UI_* equates) → force the
    ; 40-wide canvas stride for TextBoxBorder/PlaceString row-advance; restored
    ; at .done.
    ;
    ; The save slot MUST be the stack, not a static: this routine RE-ENTERS
    ; ITSELF. Both function-table handlers (DisplayMoneyBox, DoBuySellQuitMenu)
    ; call DisplayTextBoxID, so a nested dispatch runs inside the outer one. With
    ; a single static slot the inner call overwrote it with the already-forced 40
    ; and the outer restore then handed the caller 40 instead of its own stride.
    ; (The TWO_OPTION_MENU jump above happens before this push, so it cannot
    ; unbalance the stack.)
    push dword [text_row_stride]
    mov dword [text_row_stride], SCREEN_TILES_W

    ; ld hl,TextBoxFunctionTable / ld de,3 / call SearchTextBoxTable
    mov esi, TextBoxFunctionTable
    mov edx, 5                          ; stride 3 → 5 (dd flat handler ptr)
    call SearchTextBoxTable
    jc .functionTableMatch
    ; ld hl,TextBoxCoordTable / ld de,5
    mov esi, UI_TextBoxCoordTable_menus ; generated projected TextBoxCoordTable
    mov edx, 5
    call SearchTextBoxTable
    jc .coordTableMatch
    ; ld hl,TextBoxTextAndCoordTable / ld de,9
    mov esi, TextBoxTextAndCoordTable
    mov edx, 11                         ; stride 9 → 11 (dd flat text ptr)
    call SearchTextBoxTable
    jc .textAndCoordTableMatch
.done:
    ; Restore the caller's stride. `pop <mem>` touches neither EFLAGS nor AL, so
    ; the function-table handlers' return contract (CF + AL) passes through
    ; untouched — which is what pret's plain `ret` from .done gives them.
    pop dword [text_row_stride]
    ret

.functionTableMatch:
    ; ld a,[hli] / ld h,[hl] / ld l,a / ld de,.done / push de / jp hl
    mov eax, [esi]                      ; dd flat handler pointer
    call eax
    jmp .done

.coordTableMatch:
    call GetTextBoxIDCoords
    call GetAddressOfScreenCoords
    call TextBoxBorder
    jmp .done                           ; pret: ret (via .done)

.textAndCoordTableMatch:
    call GetTextBoxIDCoords
    push esi                            ; push hl — table ptr (text fields)
    call GetAddressOfScreenCoords
    call TextBoxBorder                  ; preserves ESI/EBX
    pop esi                             ; pop hl
    call GetTextBoxIDText               ; EAX = flat text ptr, ESI = text dest
    ; ld a,[wStatusFlags5] / push af / set BIT_NO_TEXT_DELAY / ld [..],a
    mov cl, [ebp + W_STATUS_FLAGS_5]
    push ecx
    or byte [ebp + W_STATUS_FLAGS_5], (1 << BIT_NO_TEXT_DELAY)
    call PlaceString
    pop ecx
    mov [ebp + W_STATUS_FLAGS_5], cl    ; pop af / ld [wStatusFlags5],a
    call UpdateSprites
    jmp .done                           ; pret: ret (via .done)

; ---------------------------------------------------------------------------
; SearchTextBoxTable — scan a $FF-terminated table for the byte in C (BL),
; advancing DE (EDX) bytes per entry. pret ref: text_box.asm:SearchTextBoxTable
; In:  ESI = table (FLAT — tables live in program .data), BL = target id,
;      EDX = entry stride.
; Out: CF=1 + ESI = entry payload (past the id byte) on match; CF=0 at $FF.
; ---------------------------------------------------------------------------
SearchTextBoxTable:
    dec edx                             ; dec de (compensate the id byte read)
.loop:
    mov al, [esi]                       ; ld a,[hli] — flat read
    inc esi
    cmp al, 0xFF
    je .notFound
    cmp al, bl                          ; cp c
    je .found
    add esi, edx                        ; add hl,de
    jmp .loop
.found:
    stc
    ret
.notFound:
    clc                                 ; pret falls through with carry clear
    ret

; ---------------------------------------------------------------------------
; GetTextBoxIDCoords — load coords from a coord/text+coord table entry.
; pret ref: text_box.asm:GetTextBoxIDCoords
; In:  ESI = entry coords (FLAT). Out: DL (E) = UL column, DH (D) = UL row,
;      BL (C) = interior width, BH (B) = interior height; ESI past the coords.
; ---------------------------------------------------------------------------
GetTextBoxIDCoords:
    mov dl, [esi]                       ; column of upper left corner
    inc esi
    mov dh, [esi]                       ; row of upper left corner
    inc esi
    mov al, [esi]                       ; column of lower right corner
    inc esi
    sub al, dl
    dec al
    mov bl, al                          ; c = interior width
    mov al, [esi]                       ; row of lower right corner
    inc esi
    sub al, dh
    dec al
    mov bh, al                          ; b = interior height
    ret

; ---------------------------------------------------------------------------
; GetTextBoxIDText — load the text pointer + text coords from a
; TextBoxTextAndCoordTable entry. pret ref: text_box.asm:GetTextBoxIDText
; In:  ESI = entry text fields (FLAT).
; Out: EAX = flat text pointer (DEVIATION: pret returns it in DE; the port's
;      16-bit DX cannot hold a flat pointer — EAX is PlaceString's source reg),
;      ESI = screen address of the text's upper-left corner (EBP-relative).
; ---------------------------------------------------------------------------
GetTextBoxIDText:
    mov eax, [esi]                      ; dd flat text pointer (pret: de = dw)
    add esi, 4
    mov dl, [esi]                       ; column of upper left corner of text
    inc esi
    mov dh, [esi]                       ; row of upper left corner of text
    push eax                            ; push de — save text address
    call GetAddressOfScreenCoords       ; ESI = screen coords
    pop eax                             ; pop de — restore text address
    ret

; ---------------------------------------------------------------------------
; GetAddressOfScreenCoords — point ESI (HL) at canvas cell (D=row, E=col).
; pret ref: text_box.asm:GetAddressOfScreenCoords (row loop × screen width).
; PROJ menus: canvas stride SCREEN_TILES_W (40), base W_TILEMAP — coords come
; pre-projected from the UI_* tables. 386: O(1) imul replaces the row loop.
; In:  DH = row, DL = column. Out: ESI = W_TILEMAP + row*40 + col (EBP-rel).
;      DH = 0 on return (the pret loop leaves d = 0). Clobbers ECX.
; ---------------------------------------------------------------------------
GetAddressOfScreenCoords:
    movzx esi, dh
    imul esi, esi, SCREEN_TILES_W
    movzx ecx, dl
    add esi, ecx
    add esi, W_TILEMAP
    xor dh, dh                          ; pret loop decrements d to 0
    ret

; ---------------------------------------------------------------------------
; DisplayMoneyBox — draw the MONEY box + the player's money (BCD).
; pret ref: engine/menus/text_box.asm:DisplayMoneyBox
; ---------------------------------------------------------------------------
DisplayMoneyBox:
    ; ld hl,wStatusFlags5 / set BIT_NO_TEXT_DELAY,[hl]
    or byte [ebp + W_STATUS_FLAGS_5], (1 << BIT_NO_TEXT_DELAY)
    mov byte [ebp + wTextBoxID], MONEY_BOX_TEMPLATE
    call DisplayTextBoxID               ; home wrapper → box + "MONEY" via the tables
    ; hlcoord 13,1 / lb bc,1,6 / ClearScreenArea
    ; PROJ menus: GB(13,1) = box-rel (2,1) → UI_MONEY_BOX_TEMPLATE_(COL+2,ROW+1)
    mov esi, W_TILEMAP + (UI_MONEY_BOX_TEMPLATE_ROW + 1) * SCREEN_TILES_W + UI_MONEY_BOX_TEMPLATE_COL + 2
    mov bh, 1                           ; b = 1 row
    mov bl, 6                           ; c = 6 columns
    call ClearScreenArea
    ; hlcoord 12,1 / de=wPlayerMoney / c=3|LEADING_ZEROES|MONEY_SIGN / PrintBCDNumber
    ; PROJ menus: GB(12,1) = box-rel (1,1) → UI_MONEY_BOX_TEMPLATE_(COL+1,ROW+1)
    mov esi, W_TILEMAP + (UI_MONEY_BOX_TEMPLATE_ROW + 1) * SCREEN_TILES_W + UI_MONEY_BOX_TEMPLATE_COL + 1
    mov edx, W_PLAYER_MONEY
    mov bl, 3 | (1 << BIT_LEADING_ZEROES) | (1 << BIT_MONEY_SIGN)
    call PrintBCDNumber
    ; ld hl,wStatusFlags5 / res BIT_NO_TEXT_DELAY,[hl]
    and byte [ebp + W_STATUS_FLAGS_5], (~(1 << BIT_NO_TEXT_DELAY)) & 0xFF
    ret

; ---------------------------------------------------------------------------
; DoBuySellQuitMenu — run the mart BUY/SELL/QUIT menu.
; pret ref: engine/menus/text_box.asm:DoBuySellQuitMenu
; Out: CF=0 + [wChosenMenuItem] on BUY/SELL; CF=1 (CANCELLED_MENU) on QUIT/B.
; ---------------------------------------------------------------------------
DoBuySellQuitMenu:
    ; ld a,[wStatusFlags5] / set BIT_NO_TEXT_DELAY,a / ld [wStatusFlags5],a
    or byte [ebp + W_STATUS_FLAGS_5], (1 << BIT_NO_TEXT_DELAY)
    xor al, al
    mov [ebp + wChosenMenuItem], al
    mov byte [ebp + wTextBoxID], BUY_SELL_QUIT_MENU_TEMPLATE
    call DisplayTextBoxID               ; box + "BUY/SELL/QUIT" via the tables
    mov byte [ebp + wMenuWatchedKeys], PAD_A | PAD_B
    mov byte [ebp + wMaxMenuItem], 2
    ; pret Y=1 / X=1 — the box anchors at the canvas origin (COL=ROW=0), so the
    ; pret screen coords survive projection unchanged.
    ; PROJ menus: cursor = (UI_BUY_SELL_QUIT_MENU_TEMPLATE_TX-1, .._TY)
    mov byte [ebp + wTopMenuItemY], UI_BUY_SELL_QUIT_MENU_TEMPLATE_TY
    mov byte [ebp + wTopMenuItemX], UI_BUY_SELL_QUIT_MENU_TEMPLATE_TX - 1
    xor al, al
    mov [ebp + wCurrentMenuItem], al
    mov [ebp + wLastMenuItem], al
    mov [ebp + wMenuWatchMovingOutOfBounds], al
    ; DEVIATION(framework): pret's PlaceMenuCursor hardcodes the 2-row item
    ; spacing; the port's carries it in menu_item_step (stride is the canvas 40).
    mov dword [menu_item_step], 2 * SCREEN_TILES_W
    ; ld a,[wStatusFlags5] / res BIT_NO_TEXT_DELAY,a / ld [wStatusFlags5],a
    and byte [ebp + W_STATUS_FLAGS_5], (~(1 << BIT_NO_TEXT_DELAY)) & 0xFF
    call HandleMenuInput                ; AL = watched keys pressed
    call PlaceUnfilledArrowMenuCursor
    test al, PAD_A                      ; bit B_PAD_A,a / jr nz,.pressedA
    jnz .pressedA
    test al, PAD_B                      ; bit B_PAD_B,a (always true) / jr z,.pressedA
    jz .pressedA
    mov byte [ebp + wMenuExitMethod], CANCELLED_MENU
    jmp .quit
.pressedA:
    mov byte [ebp + wMenuExitMethod], CHOSE_MENU_ITEM
    mov al, [ebp + wCurrentMenuItem]
    mov [ebp + wChosenMenuItem], al
    mov bh, al                          ; ld b,a
    mov al, [ebp + wMaxMenuItem]
    cmp al, bh                          ; cp b — QUIT is the last item
    je .quit
    ret                                 ; CF=0 (max > item, no borrow) — as pret
.quit:
    mov byte [ebp + wMenuExitMethod], CANCELLED_MENU
    mov al, [ebp + wCurrentMenuItem]
    mov [ebp + wChosenMenuItem], al
    stc
    ret

; ---------------------------------------------------------------------------
; DisplayFieldMoveMonMenu — the party-menu pop-up listing the selected mon's
; field moves above STATS/SWITCH/CANCEL. pret ref: DisplayFieldMoveMonMenu.
; PROJ menus: every dynamic GB coord in this routine shifts by the
; UI_FIELD_MOVE_MON_MENU anchor delta (COL-GBX, ROW-GBY = +20,+7 — the
; right/bottom anchor recorded in the .inc). hFieldMoveMonMenuTopMenuItemX
; keeps its GB-space value (consumers project at their own placement site).
; ---------------------------------------------------------------------------
FM_COL_SHIFT equ UI_FIELD_MOVE_MON_MENU_COL - UI_FIELD_MOVE_MON_MENU_GBX
FM_ROW_SHIFT equ UI_FIELD_MOVE_MON_MENU_ROW - UI_FIELD_MOVE_MON_MENU_GBY

DisplayFieldMoveMonMenu:
    ; xor a / clear wFieldMoves..wNumFieldMoves / wFieldMovesLeftmostXCoord=12
    xor al, al
    mov [ebp + wFieldMoves + 0], al
    mov [ebp + wFieldMoves + 1], al
    mov [ebp + wFieldMoves + 2], al
    mov [ebp + wFieldMoves + 3], al
    mov [ebp + wNumFieldMoves], al
    mov byte [ebp + wFieldMovesLeftmostXCoord], 12
    call GetMonFieldMoves
    mov al, [ebp + wNumFieldMoves]
    test al, al                         ; and a
    jnz .fieldMovesExist

    ; no field moves: hlcoord 11,11 / lb bc,5,7 / TextBoxBorder
    ; PROJ menus: GB(11,11) 9x7 → UI_FIELD_MOVE_MON_MENU_(COL,ROW) = (31,18)
    mov esi, W_TILEMAP + UI_FIELD_MOVE_MON_MENU_ROW * SCREEN_TILES_W + UI_FIELD_MOVE_MON_MENU_COL
    mov bh, 5                           ; b = interior height
    mov bl, 7                           ; c = interior width
    call TextBoxBorder
    call UpdateSprites
    mov byte [ebp + hFieldMoveMonMenuTopMenuItemX], 12  ; GB-space cursor X
    ; hlcoord 13,12 → box-rel (2,1); PROJ: UI_FIELD_MOVE_MON_MENU_(COL+2,ROW+1)
    mov esi, W_TILEMAP + (UI_FIELD_MOVE_MON_MENU_ROW + 1) * SCREEN_TILES_W + UI_FIELD_MOVE_MON_MENU_COL + 2
    mov eax, PokemonMenuEntries
    jmp PlaceString                     ; jp PlaceString

.fieldMovesExist:
    push eax                            ; push af — numFieldMoves

    ; box position/width from the leftmost field-move name X (before the
    ; move-count adjustment): hlcoord 0,11 + (leftmostX - 1); c = 18 - e; b = 5
    movzx ecx, byte [ebp + wFieldMovesLeftmostXCoord]
    dec ecx                             ; e = leftmostX - 1 (GB columns)
    mov esi, W_TILEMAP + (11 + FM_ROW_SHIFT) * SCREEN_TILES_W + FM_COL_SHIFT
    add esi, ecx                        ; add hl,de (projected)
    mov bh, 5                           ; ld b,5
    mov al, 18
    sub al, cl                          ; ld a,18 / sub e
    mov bl, al                          ; ld c,a
    pop eax                             ; pop af — numFieldMoves

    ; grow the box upward 2 rows per field move (bottom stays at screen bottom)
    mov edx, -(SCREEN_TILES_W * 2)      ; ld de,-SCREEN_WIDTH*2 (canvas stride)
.textBoxHeightLoop:
    add esi, edx                        ; add hl,de
    inc bh                              ; inc b
    inc bh                              ; inc b
    dec al
    jnz .textBoxHeightLoop
    ; one extra blank row above the top field move
    sub esi, SCREEN_TILES_W             ; ld de,-SCREEN_WIDTH / add hl,de
    inc bh
    call TextBoxBorder
    call UpdateSprites

    ; first field-move name position: hlcoord 0,12 + (leftmostX + 1), then up
    ; 2 rows per move
    movzx ecx, byte [ebp + wFieldMovesLeftmostXCoord]
    inc ecx                             ; e = leftmostX + 1
    mov esi, W_TILEMAP + (12 + FM_ROW_SHIFT) * SCREEN_TILES_W + FM_COL_SHIFT
    add esi, ecx
    mov edx, -(SCREEN_TILES_W * 2)
    movzx eax, byte [ebp + wNumFieldMoves]
.calcFirstFieldMoveYLoop:
    add esi, edx
    dec al
    jnz .calcFirstFieldMoveYLoop

    xor al, al
    mov [ebp + wNumFieldMoves], al
    mov edx, wFieldMoves                ; ld de,wFieldMoves (EBP-relative walker)
.printNamesLoop:
    push esi                            ; push hl — screen position
    mov esi, FieldMoveNames             ; ld hl,FieldMoveNames (FLAT)
    movzx eax, byte [ebp + edx]         ; ld a,[de] — 1-based name index
    test al, al
    jz .donePrintingNames
    inc edx                             ; inc de
    mov bh, al                          ; ld b,a — names to skip + 1
.skipNamesLoop:                         ; skip names before the one we want
    dec bh
    jz .reachedName
.skipNameLoop:                          ; skip one '@'-terminated name
    mov al, [esi]                       ; ld a,[hli] — flat read
    inc esi
    cmp al, 0x50                        ; cp '@'
    jne .skipNameLoop
    jmp .skipNamesLoop
.reachedName:
    mov eax, esi                        ; ld b,h / ld c,l — flat name pointer
    pop esi                             ; pop hl — screen position
    push edx                            ; push de — wFieldMoves walker
    call PlaceString                    ; (returns ESI = line start; clobbers EBX/EDX)
    add esi, SCREEN_TILES_W * 2         ; ld bc,SCREEN_WIDTH*2 / add hl,bc
    pop edx                             ; pop de
    jmp .printNamesLoop

.donePrintingNames:
    pop esi                             ; pop hl (stack balance, as pret)
    mov al, [ebp + wFieldMovesLeftmostXCoord]
    mov [ebp + hFieldMoveMonMenuTopMenuItemX], al       ; GB-space cursor X
    ; hlcoord 0,12 + (leftmostX + 1): the STATS/SWITCH/CANCEL tail
    movzx ecx, byte [ebp + wFieldMovesLeftmostXCoord]
    inc ecx
    mov esi, W_TILEMAP + (12 + FM_ROW_SHIFT) * SCREEN_TILES_W + FM_COL_SHIFT
    add esi, ecx
    mov eax, PokemonMenuEntries
    jmp PlaceString                     ; jp PlaceString

; ---------------------------------------------------------------------------
; GetMonFieldMoves — fill wFieldMoves with the name indices of the field moves
; known by party mon [wWhichPokemon]; track count + leftmost name X.
; pret ref: engine/menus/text_box.asm:GetMonFieldMoves. The scan reuses the
; shared FieldMoveDisplayData/FieldMoveNames tables (field_moves.asm) — the
; same data IsFieldMove consumes; no duplicate table.
; ---------------------------------------------------------------------------
GetMonFieldMoves:
    mov al, [ebp + wWhichPokemon]
    mov esi, wPartyMon1 + MON_MOVES     ; ld hl,wPartyMon1Moves
    mov bx, PARTYMON_STRUCT_LENGTH
    call AddNTimes                      ; ESI += 44 × mon index (clobbers ECX)
    mov edx, esi                        ; ld d,h / ld e,l — moves ptr (EBP-rel)
    mov bl, NUM_MOVES + 1               ; ld c,NUM_MOVES+1
    mov esi, wFieldMoves                ; ld hl,wFieldMoves (EBP-rel write ptr)
.loop:
    push esi                            ; push hl
.nextMove:
    dec bl                              ; dec c
    jz .done
    movzx eax, byte [ebp + edx]         ; ld a,[de] — move ID
    test al, al
    jz .done
    mov bh, al                          ; ld b,a
    inc edx                             ; inc de
    mov esi, FieldMoveDisplayData       ; ld hl,FieldMoveDisplayData (FLAT)
.fieldMoveLoop:
    mov al, [esi]                       ; ld a,[hli] — flat read
    inc esi
    cmp al, 0xFF
    je .nextMove                        ; not a field move
    cmp al, bh                          ; cp b
    je .foundFieldMove
    add esi, 2                          ; inc hl / inc hl (3-byte records)
    jmp .fieldMoveLoop
.foundFieldMove:
    mov al, bh                          ; ld a,b
    mov [ebp + wLastFieldMoveID], al
    mov al, [esi]                       ; ld a,[hli] — field move name index
    inc esi
    mov bh, [esi]                       ; ld b,[hl] — name leftmost X coordinate
    pop esi                             ; pop hl — wFieldMoves write ptr
    mov [ebp + esi], al                 ; ld [hli],a — store name index
    inc esi
    mov al, [ebp + wNumFieldMoves]
    inc al
    mov [ebp + wNumFieldMoves], al
    mov al, [ebp + wFieldMovesLeftmostXCoord]
    cmp al, bh                          ; cp b
    jc .skipUpdatingLeftmostXCoord      ; current leftmost < this name's X
    mov al, bh
    mov [ebp + wFieldMovesLeftmostXCoord], al
.skipUpdatingLeftmostXCoord:
    mov al, [ebp + wLastFieldMoveID]
    mov bh, al                          ; ld b,a (restore move id, as pret)
    jmp .loop
.done:
    pop esi                             ; pop hl
    ret
