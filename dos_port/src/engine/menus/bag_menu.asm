; bag_menu.asm — overworld bag (ITEM) screen.
;
; A scrollable list of the player's bag items (name + "×NN" quantity), opened from
; the START menu's ITEM entry. A on CANCEL or B exits back to the START menu.
; A on a tossable item runs the TOSS flow: choose a quantity (1..held), then a
; YES/NO confirmation; YES removes the items via RemoveItemFromInventory_. Key
; items / HMs can't be tossed. (The USE branch is still deferred — most item
; effects are battle/UI coupled.)
;
; WINDOWING (Stage 3 — unified compositor, faithful top-right layout):
;   Each box is its OWN window descriptor at faithful GB→port coordinates (the
;   bag inherits the START menu's TOP-RIGHT anchor: our_col = gb_col + 20, Y kept).
;   The list stays as g_windows[0]; the active sub-box (USE/TOSS, quantity, YES/NO)
;   is appended via add_window so list + sub-box(es) coexist (painter's order). All
;   bag boxes own GB_TILEMAP0 (distinct start_rows) so they never collide with the
;   bottom dialog's GB_TILEMAP1 rows (used by Stage 4 toss messages). Boxes are
;   rendered into the 20-wide W_TILEMAP scratch (TextBoxBorder/place_flat_str use a
;   fixed 20-stride), then .copy_box blits each W×H rect to its GB_TILEMAP0 region.
;
;   ; PROJ tags below record every GB(col,row)→port transform (see docs/ui_projection.md).
;
; CALLER CONTRACT: the text font must already be resident in vFont — DisplayStartMenu
; loads it before dispatching here, so we do NOT swap it again. Input uses
; H_JOY_PRESSED (reliable: one DelayFrame → one joypad_update per loop iteration).
;
; Pret ref: home/list_menu.asm (ITEMLISTMENU + DisplayChooseQuantityMenu),
;           engine/menus/start_sub_menus.asm (ItemMenuLoop USE/TOSS),
;           engine/items/item_effects.asm (TossItem_ YES/NO), data/text_boxes.asm.
; ---------------------------------------------------------------------------
bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"

global DisplayBagMenu

extern TextBoxBorder         ; ESI=top-left, BL=interior width, BH=interior height
extern place_flat_str        ; ESI=dest (EBP-rel), EAX=flat '@'-terminated src
extern DelayFrame
extern ItemNames             ; src/data/item_data.asm — flat '@'-terminated name table
extern KeyItemFlags          ; src/data/item_data.asm — LSB-first key-item bit array
extern RemoveItemFromInventory_  ; src/engine/items/inventory.asm
extern add_window            ; src/ppu/ppu.asm — append a window descriptor (count++)
extern hide_window           ; src/ppu/ppu.asm — clear the window list (count=0)
extern g_window_count        ; src/ppu/ppu.asm — live descriptor count
%ifdef DEBUG_BAGMENU
extern DumpBackbuffer
%endif

; ===========================================================================
; Box geometry + faithful TOP-RIGHT projections (PROJ overworld-ui, X+20 Y+0).
;   wx = (gb_col + 20)*8 + 7 ; wy = gb_row*8 ; clip = totalW*8 ; max_y = (gb_row+H)*8
;   All boxes draw from column 0 of their own GB_TILEMAP0 region (start_row).
; ===========================================================================

; --- Item list: GB(4,2) total 16×11 ---------------------------------------
; ; PROJ overworld-ui: GB(4,2) 16x11 --(anchor=top-right, X+20, Y+0)--> wx=199 wy=16 clip=128 max_y=104
LIST_INT_W     equ 14        ; TextBoxBorder interior width  (total 16)
LIST_INT_H     equ 9         ; TextBoxBorder interior height (total 11)
LIST_TOTAL_W   equ 16
LIST_TOTAL_H   equ 11
LIST_SROW      equ 0         ; GB_TILEMAP0 start row
LIST_WX        equ 199
LIST_WY        equ 16
LIST_CLIP      equ 128
LIST_MAXY      equ 104
; list internals (box-relative; scratch offset = row*20 + col)
LIST_CURSOR_COL equ 1
LIST_NAME_COL   equ 2
LIST_NAME_ROW0  equ 2        ; first entry name row (pret hlcoord 6,4 → box-rel (2,2))
LIST_ROW_STEP   equ 2        ; each entry spans 2 rows (name; qty below)
LIST_QTY_COL    equ 10       ; "×" col on the row BELOW the name (pret name_col+8)
LIST_DOWN_COL   equ 14       ; ▼ "more below" indicator
LIST_DOWN_ROW   equ 9
BM_VISIBLE      equ 4        ; entries shown at once (pret's `ld b, 4`)

; --- USE/TOSS sub-menu: GB(13,10) total 7×5 -------------------------------
; ; PROJ overworld-ui: GB(13,10) 7x5 --(anchor=top-right, X+20, Y+0)--> wx=271 wy=80 clip=56 max_y=120
USETOSS_INT_W  equ 5
USETOSS_TOT_W  equ 7
USETOSS_SROW   equ 11
USETOSS_WX     equ 271
USETOSS_WY     equ 80
USETOSS_CLIP   equ 56
USETOSS_MAXY   equ 120

; --- Toss YES/NO: GB(14,7) total 6×5 --------------------------------------
; ; PROJ overworld-ui: GB(14,7) 6x5 --(anchor=top-right, X+20, Y+0)--> wx=279 wy=56 clip=48 max_y=96
YESNO_INT_W    equ 4
YESNO_TOT_W    equ 6
YESNO_SROW     equ 16
YESNO_WX       equ 279
YESNO_WY       equ 56
YESNO_CLIP     equ 48
YESNO_MAXY     equ 96

; --- Toss quantity (unpriced): GB(15,9) total 5×3 -------------------------
; ; PROJ overworld-ui: GB(15,9) 5x3 --(anchor=top-right, X+20, Y+0)--> wx=287 wy=72 clip=40 max_y=96
QTY_SROW       equ 21
QTY_WX         equ 287
QTY_WY         equ 72
QTY_CLIP       equ 40
QTY_MAXY       equ 96

; Both two-option sub-boxes share interior height 3 (options on rows 1 and 3).
OPT_INT_H      equ 3
OPT_TOT_H      equ 5
OPT_A_ROW      equ 1         ; box-rel row of the top option text/cursor
OPT_B_ROW      equ 3         ; box-rel row of the bottom option
OPT_TEXT_COL   equ 2         ; option text col (pret USE/TOSS items at 15,11 → box-rel 2)
OPT_CURSOR_COL equ 1

CHAR_CURSOR    equ 0xED      ; ▶ (filled — navigation cursor)
CHAR_SWAP_CUR  equ 0xEC      ; ▷ (hollow — marks the SELECT-swap held item)
CHAR_DOWN      equ 0xEE      ; ▼ (= CHAR_DOWN_ARROW)
CHAR_TIMES     equ 0xF1      ; ×
CHAR_DIGIT0    equ 0xF6      ; '0'; digit d → CHAR_DIGIT0 + d
CHAR_QUEST     equ 0xE6      ; ?
CHAR_EXCL      equ 0xE7      ; !
CHAR_DOT       equ 0xE8      ; .
TILE_SPC       equ 0x7F
CHAR_TERM      equ 0x50      ; '@'

section .data
align 4
; charmap glyphs ('@'-terminated). Upper $80+(c-'A'); lower $A0+(c-'a'); sp $7F.
bm_str_cancel: db 0x82, 0x80, 0x8D, 0x82, 0x84, 0x8B, CHAR_TERM           ; CANCEL
bm_str_use:    db 0x94, 0x92, 0x84, CHAR_TERM                             ; USE
bm_str_toss:   db 0x93, 0x8E, 0x92, 0x92, CHAR_TERM                       ; TOSS
bm_str_yes:    db 0x98, 0x84, 0x92, CHAR_TERM                             ; YES
bm_str_no:     db 0x8D, 0x8E, CHAR_TERM                                   ; NO
; Toss dialog messages (pret text_9.asm wording; item name substituted at runtime).
bm_msg_threw:  db 0x93,0xA7,0xB1,0xA4,0xB6,0x7F,0xA0,0xB6,0xA0,0xB8, CHAR_TERM          ; "Threw away"
bm_msg_isok:   db 0x88,0xB2,0x7F,0xA8,0xB3,0x7F,0x8E,0x8A,0x7F,0xB3,0xAE,0x7F,0xB3,0xAE,0xB2,0xB2, CHAR_TERM ; "Is it OK to toss"
; "That's too impor-" / "tant to toss!" — pret wording; 'BD = "'s" ligature, 'E3 = "-".
bm_msg_imp1:   db 0x93,0xA7,0xA0,0xB3,0xBD,0x7F,0xB3,0xAE,0xAE,0x7F,0xA8,0xAC,0xAF,0xAE,0xB1,0xE3, CHAR_TERM ; "That's too impor-"
bm_msg_imp2:   db 0xB3,0xA0,0xAD,0xB3,0x7F,0xB3,0xAE,0x7F,0xB3,0xAE,0xB2,0xB2,CHAR_EXCL, CHAR_TERM ; "tant to toss!"

section .bss
align 4
bm_selected:    resd 1       ; absolute index into the entry list (0..num_entries-1)
bm_scroll:      resd 1       ; index of the top visible entry
bm_num_entries: resd 1       ; bag item count + 1 (the CANCEL tail)
bm_swap:        resd 1       ; SELECT-swap: 0 = none pending, else (held index + 1)
bm_toss_qty:    resd 1       ; quantity being chosen to toss (1..item qty)
bm_toss_item:   resd 1       ; item id captured before removal (for "Threw away" msg)
bm_opt_sel:     resd 1       ; 2-option menu cursor: 0 = top, 1 = bottom
bm_opt_a:       resd 1       ; flat ptr to the top option string
bm_opt_b:       resd 1       ; flat ptr to the bottom option string
; current two-option sub-box config (set before .draw_sub_opt / .opt2_run):
bm_sub_int_w:   resd 1       ; interior width passed to TextBoxBorder
bm_sub_tot_w:   resd 1       ; total width copied to the tilemap region
bm_sub_dst:     resd 1       ; GB_TILEMAP0 dest base offset for the sub-box
; .copy_box scratch params:
bm_cb_w:        resd 1
bm_cb_h:        resd 1
bm_cb_dst:      resd 1

section .text

; ---------------------------------------------------------------------------
; DisplayBagMenu — show the bag list, run it until CANCEL/B, then return.
; In:  EBP = GB memory base; font already resident (see caller contract).
; All registers preserved (pushad/popad).
; ---------------------------------------------------------------------------
DisplayBagMenu:
    pushad

    ; num_entries = wNumBagItems + 1 (CANCEL); selection/scroll start at top.
    movzx eax, byte [ebp + wNumBagItems]
    inc eax
    mov [bm_num_entries], eax
    mov dword [bm_selected], 0
    mov dword [bm_scroll], 0
    mov dword [bm_swap], 0              ; no SELECT-swap pending on open

    ; Render the list content, then define the window list as exactly the list box.
    call .render
    call hide_window                   ; count=0 (also parks the dialog gate closed)
    call .add_list_window              ; count=1, g_windows[0] = list box

%ifdef DEBUG_BAGMENU
    ; DEBUG_BAGMENU_CONFIRM statically renders the toss-confirm state — list +
    ; "Is it OK to toss <ITEM>?" bottom dialog + YES/NO box — to check all three
    ; faithful descriptors coexist (no input loop).
%ifdef DEBUG_BAGMENU_CONFIRM
    call .dialog_prep_box
    mov esi, W_TILEMAP + 14 * 20 + 1
    mov eax, bm_msg_isok
    call place_flat_str
    movzx eax, byte [ebp + wBagItems]  ; first item id
    call .find_item_name
    mov esi, W_TILEMAP + 16 * 20 + 1
    call place_flat_str
    mov byte [ebp + esi], CHAR_QUEST
    call .dialog_mirror
    call .add_dialog_window            ; count=2 (list + dialog)
    mov dword [bm_opt_sel], 0
    mov eax, bm_str_yes
    mov [bm_opt_a], eax
    mov eax, bm_str_no
    mov [bm_opt_b], eax
    call .show_yesno_window            ; count=3 (list + dialog + YES/NO)
%endif
    call DelayFrame             ; render one frame with the bag shown
    call DumpBackbuffer         ; dump FRAME.BIN + exit (never returns)
%endif

    ; swallow the opening A press (START menu dispatched us on A-held).
.wait_open:
    call DelayFrame
    test byte [ebp + H_JOY_HELD], PAD_A
    jnz .wait_open

.loop:
    call DelayFrame
    movzx eax, byte [ebp + H_JOY_PRESSED]
    test al, PAD_DOWN
    jnz .down
    test al, PAD_UP
    jnz .up
    test al, PAD_SELECT
    jnz .swap
    test al, PAD_A
    jnz .select
    test al, PAD_B
    jnz .exit
    jmp .loop

.down:
    mov eax, [bm_selected]
    inc eax
    cmp eax, [bm_num_entries]
    jae .loop                   ; already at the bottom
    mov [bm_selected], eax
    call .fix_scroll
    call .render
    jmp .loop

.up:
    mov eax, [bm_selected]
    test eax, eax
    jz .loop                    ; already at the top
    dec eax
    mov [bm_selected], eax
    call .fix_scroll
    call .render
    jmp .loop

; --- SELECT: reorder the bag (pret engine/menus/swap_items.asm) ---
; The bag is an ordered list of [id,qty] pairs. The first SELECT marks the held
; entry (bm_swap = index+1); the second swaps the two entries. Swapping two slots
; of the SAME item merges them (cap 99; on full combine the held slot is removed
; and the list compacts), faithfully matching HandleItemListSwapping. SELECT on
; CANCEL or on the held entry itself is ignored.
.swap:
    mov eax, [bm_selected]
    inc eax
    cmp eax, [bm_num_entries]
    je .loop                    ; ignore SELECT on the CANCEL tail
    mov eax, [bm_swap]
    test eax, eax
    jnz .swap_second
    ; no held entry yet → mark the current one (store index + 1), show ▷
    mov eax, [bm_selected]
    inc eax
    mov [bm_swap], eax
    call .render
    jmp .loop

.swap_second:
    dec eax                     ; eax = held (first) absolute index
    mov dword [bm_swap], 0      ; clear the pending state
    mov ebx, [bm_selected]      ; ebx = second (currently selected) index
    cmp eax, ebx
    je .loop                    ; SELECT on the same entry → just deselect
    lea esi, [ebp + eax*2 + wBagItems]   ; &entry[first]  (held)
    lea edi, [ebp + ebx*2 + wBagItems]   ; &entry[second] (selected)
    mov al, [esi]               ; first item id
    cmp al, [edi]               ; same item type?
    je .swap_merge
    ; --- different items: plain 2-byte entry swap ---
    mov ax, [esi]               ; first  id+qty
    mov dx, [edi]               ; second id+qty
    mov [esi], dx
    mov [edi], ax
    jmp .swap_redraw

.swap_merge:
    movzx eax, byte [esi + 1]   ; first (held) qty
    movzx edx, byte [edi + 1]   ; second qty
    add eax, edx                ; combined quantity
    cmp eax, 100
    jb .swap_combine
    ; sum >= 100: cap the selected slot at 99, leftover stays in the held slot
    sub eax, 99
    mov byte [esi + 1], al      ; held slot keeps the leftover
    mov byte [edi + 1], 99
    jmp .swap_redraw
.swap_combine:
    mov byte [edi + 1], al      ; selected slot gets the full sum (al < 100)
    ; remove the held slot: shift the following pairs (incl 0xFF terminator) up
    mov edi, esi                ; dst = held slot
    lea esi, [esi + 2]          ; src = next slot
.swap_shift:
    mov al, [esi]               ; id (or 0xFF terminator)
    mov [edi], al
    inc al                      ; 0xFF → 0 ?
    jz .swap_compacted
    mov al, [esi + 1]
    mov [edi + 1], al
    add esi, 2
    add edi, 2
    jmp .swap_shift
.swap_compacted:
    dec byte [ebp + wNumBagItems]
    movzx eax, byte [ebp + wNumBagItems]
    inc eax
    mov [bm_num_entries], eax   ; refresh entry count (+ CANCEL tail)
    mov dword [bm_selected], 0  ; original resets the cursor to the top
    mov dword [bm_scroll], 0
.swap_redraw:
    call .fix_scroll
    call .render
    jmp .loop

.select:
    ; CANCEL (last entry) closes. An item opens the USE/TOSS sub-menu.
    mov eax, [bm_selected]
    inc eax
    cmp eax, [bm_num_entries]   ; selected == num_entries-1 ?
    je .exit

    ; --- USE/TOSS sub-menu (pret ItemMenuLoop USE_TOSS_MENU_TEMPLATE) ---
    call .run_usetoss           ; EAX = 0 (USE), 1 (TOSS), 2 (cancel)
    cmp eax, 2
    je .submenu_close
    test eax, eax
    jz .use_item                ; USE is deferred (battle/UI-coupled effects)
    jmp .toss_begin             ; TOSS

.submenu_close:
    mov dword [g_window_count], 1   ; drop the sub-box, list only
    jmp .wait_a_release

.use_item:
    ; USE dispatch (UseItem_/ItemUsePtrTable) is deferred — most effects are
    ; battle/UI coupled. For now, drop the sub-menu and return to the list.
    mov dword [g_window_count], 1
    jmp .wait_a_release

.toss_begin:
    ; .run_usetoss already restored count=1. Item id at wBagItems + bm_selected*2;
    ; key items / HMs can't be tossed.
    mov ecx, [bm_selected]
    shl ecx, 1
    movzx eax, byte [ebp + wBagItems + ecx]
    call .is_key_item           ; ZF=0 (NZ) if key item / HM
    jnz .key_item_notice        ; → INTERIM notice, then bail to the list

    ; tossable: if only 1, skip the chooser; else choose 1..held.
    mov ecx, [bm_selected]
    shl ecx, 1
    movzx edx, byte [ebp + wBagItems + ecx + 1]   ; item quantity (held)
    mov dword [bm_toss_qty], 1
    cmp edx, 1
    je .toss_confirm
    call .run_qty               ; CF=0 chosen (qty box stays), CF=1 cancelled
    jc .toss_cancel

.toss_confirm:
    ; Faithful "Is it OK to toss <ITEM>?" bottom dialog (pret IsItOKToTossItemText),
    ; coexisting with the list, plus the YES/NO box flush-right at GB(14,7).
    call .dialog_prep_box
    mov esi, W_TILEMAP + 14 * 20 + 1            ; line 1 cursor (1,14)
    mov eax, bm_msg_isok
    call place_flat_str
    mov ecx, [bm_selected]                      ; line 2: <ITEM>?
    shl ecx, 1
    movzx eax, byte [ebp + wBagItems + ecx]
    call .find_item_name
    mov esi, W_TILEMAP + 16 * 20 + 1            ; line 2 cursor (1,16)
    call place_flat_str                         ; ESI advanced past the name
    mov byte [ebp + esi], CHAR_QUEST
    call .dialog_mirror
    mov dword [g_window_count], 1               ; list only (drop any qty box)
    call .add_dialog_window                     ; count = 2 ([list, dialog])
    mov dword [bm_opt_sel], 0
    mov eax, bm_str_yes
    mov [bm_opt_a], eax
    mov eax, bm_str_no
    mov [bm_opt_b], eax
    call .show_yesno_window     ; count = 3 ([list, dialog, YES/NO])
    call .opt2_run              ; EAX = 0 (YES), 1 (NO), 2 (cancel)
    test eax, eax
    jz .toss_commit             ; YES
    ; fall through: NO/cancel

.toss_cancel:
    mov dword [g_window_count], 1   ; drop qty/YES-NO sub-boxes, list only
    call .render                    ; wipe the interim prompt, restore the list
    jmp .wait_a_release

.toss_commit:
    ; Capture the item id NOW — removal may delete the slot (qty→0), but the
    ; "Threw away <ITEM>." message still needs the name (pret CopyToStringBuffer).
    mov ecx, [bm_selected]
    shl ecx, 1
    movzx eax, byte [ebp + wBagItems + ecx]
    mov [bm_toss_item], eax
    ; wWhichPokemon = bm_selected (bag slot); wItemQuantity = toss qty, clamped to
    ; the held count so we can never remove more than the player has.
    mov eax, [bm_selected]
    mov [ebp + wWhichPokemon], al
    mov ecx, [bm_selected]
    shl ecx, 1
    movzx edx, byte [ebp + wBagItems + ecx + 1]   ; held quantity
    mov eax, [bm_toss_qty]
    cmp eax, edx
    jbe .tc_qty_ok
    mov eax, edx                                  ; clamp to held
.tc_qty_ok:
    mov [ebp + wItemQuantity], al
    mov esi, wNumBagItems
    call RemoveItemFromInventory_
    ; refresh entry count; clamp selection into range.
    movzx eax, byte [ebp + wNumBagItems]
    inc eax
    mov [bm_num_entries], eax
    mov eax, [bm_selected]
    cmp eax, [bm_num_entries]
    jb .td_sel_ok
    mov eax, [bm_num_entries]
    dec eax
    mov [bm_selected], eax
.td_sel_ok:
    mov dword [g_window_count], 1   ; list only
    call .fix_scroll
    call .render
    ; Faithful "Threw away <ITEM>." bottom dialog (pret ThrewAwayItemText).
    call .dialog_prep_box
    mov esi, W_TILEMAP + 14 * 20 + 1
    mov eax, bm_msg_threw
    call place_flat_str
    mov eax, [bm_toss_item]
    call .find_item_name
    mov esi, W_TILEMAP + 16 * 20 + 1
    call place_flat_str
    mov byte [ebp + esi], CHAR_DOT
    call .dialog_mirror
    call .add_dialog_window         ; count = 2 ([list, dialog])
    call .dialog_wait
    mov dword [g_window_count], 1   ; drop the dialog, list only
.wait_a_release:
    call DelayFrame
    test byte [ebp + H_JOY_HELD], PAD_A | PAD_B
    jnz .wait_a_release
    jmp .loop

.exit:
    ; Leave window state as-is; the START menu redraws its own box + bounds on
    ; return. Wait for A/B release so its edge-read loop doesn't re-trigger.
.exit_release:
    call DelayFrame
    test byte [ebp + H_JOY_HELD], PAD_A | PAD_B
    jnz .exit_release
    popad
    ret

; --- "Too important to toss!" notice for an untossable item (key item / HM) ------
; Faithful bottom dialog (pret TooImportantToTossText), coexisting with the list;
; wait for A/B, then drop the dialog and return to the list.
.key_item_notice:
    call .dialog_prep_box
    mov esi, W_TILEMAP + 14 * 20 + 1
    mov eax, bm_msg_imp1
    call place_flat_str
    mov esi, W_TILEMAP + 16 * 20 + 1
    mov eax, bm_msg_imp2
    call place_flat_str
    call .dialog_mirror
    call .add_dialog_window         ; count = 2 ([list, dialog])
    call .dialog_wait
    mov dword [g_window_count], 1   ; drop the dialog, list only
    jmp .wait_a_release

; --- keep the selection within the visible window -----------------------------
.fix_scroll:
    mov eax, [bm_selected]
    cmp eax, [bm_scroll]
    jae .fs_check_bottom
    mov [bm_scroll], eax        ; scrolled above the window → pin to top
    ret
.fs_check_bottom:
    mov eax, [bm_scroll]
    add eax, BM_VISIBLE - 1     ; last visible index
    cmp [bm_selected], eax
    jbe .fs_done
    mov eax, [bm_selected]
    sub eax, BM_VISIBLE - 1
    mov [bm_scroll], eax        ; scrolled below the window → pin to bottom
.fs_done:
    ret

; ===========================================================================
; Window-list helpers (the bag owns g_windows[]: [0]=list, [1..]=active sub-box)
; ===========================================================================

; append the list descriptor (caller has reset the count to 0).
.add_list_window:
    mov eax, LIST_WX
    mov ebx, LIST_WY
    mov ecx, LIST_CLIP
    mov edx, LIST_MAXY
    mov esi, GB_TILEMAP0
    mov edi, LIST_SROW
    call add_window
    ret

; render + append the quantity box (count → +1).
.show_qty_window:
    call .draw_qty
    mov eax, QTY_WX
    mov ebx, QTY_WY
    mov ecx, QTY_CLIP
    mov edx, QTY_MAXY
    mov esi, GB_TILEMAP0
    mov edi, QTY_SROW
    call add_window
    ret

; render + append the YES/NO box (count → +1). Caller sets bm_opt_a/_b/_sel.
.show_yesno_window:
    mov dword [bm_sub_int_w], YESNO_INT_W
    mov dword [bm_sub_tot_w], YESNO_TOT_W
    mov dword [bm_sub_dst], GB_TILEMAP0 + YESNO_SROW * 32
    call .draw_sub_opt
    mov eax, YESNO_WX
    mov ebx, YESNO_WY
    mov ecx, YESNO_CLIP
    mov edx, YESNO_MAXY
    mov esi, GB_TILEMAP0
    mov edi, YESNO_SROW
    call add_window
    ret

; ===========================================================================
; Bottom dialog box (toss messages) — a descriptor coexisting with the list.
; The list (GB_TILEMAP0) stays visible while the dialog renders into GB_TILEMAP1
; (rows 0–5), so list + dialog (+ YES/NO) all show at once. No typewriter reveal
; (rendered whole, not via PrintText) — keeps the list-coexistence path simple and
; avoids the single-window collapse in set_single_window. ; PROJ matches the
; overworld dialog: GB(0,17) 20×6 --(center, X+10/WX-7=80)--> wx=87 wy=152.
; ===========================================================================

; draw the empty dialog box border into the W_TILEMAP scratch (rows 12–17).
.dialog_prep_box:
    mov esi, W_TILEMAP + 12 * 20
    mov bl, 18                  ; interior width  (total 20)
    mov bh, 4                   ; interior height (total 6)
    call TextBoxBorder
    ret

; mirror W_TILEMAP dialog rows 12–17 → GB_TILEMAP1 rows 0–5 (pad cols 20–31).
.dialog_mirror:
    push eax
    push ecx
    push esi
    push edi
    mov ecx, 6
    lea esi, [ebp + W_TILEMAP + 12 * 20]
    lea edi, [ebp + GB_TILEMAP1]
.dm_row:
    push ecx
    push edi
    mov ecx, 20
    rep movsb
    mov al, TILE_SPC
    mov ecx, 12                 ; pad cols 20–31
    rep stosb
    pop edi
    pop ecx
    add edi, 32                 ; next GB_TILEMAP1 row (32 wide)
    dec ecx
    jnz .dm_row
    pop edi
    pop esi
    pop ecx
    pop eax
    ret

; append the bottom dialog descriptor (count → +1).
.add_dialog_window:
    mov eax, 87                 ; wx (WX-7=80 → center 160px dialog in 320px)
    mov ebx, 152                ; wy (bottom of the 320×200 viewport)
    mov ecx, SCREEN_W           ; clip_w = 160
    mov edx, RENDER_H           ; max_y = 200
    mov esi, GB_TILEMAP1
    xor edi, edi                ; start_row = 0
    call add_window
    ret

; place the ▼ advance arrow, wait for an A/B press cycle, clear the arrow.
.dialog_wait:
    mov byte [ebp + GB_TILEMAP1 + DIALOG_ARROW_TILEMAP_OFFSET], CHAR_DOWN
.dlw_release:
    call DelayFrame
    test byte [ebp + H_JOY_HELD], PAD_A | PAD_B
    jnz .dlw_release
.dlw_press:
    call DelayFrame
    test byte [ebp + H_JOY_HELD], PAD_A | PAD_B
    jz .dlw_press
    mov byte [ebp + GB_TILEMAP1 + DIALOG_ARROW_TILEMAP_OFFSET], TILE_SPC
    ret

; ===========================================================================
; USE/TOSS sub-menu — append its descriptor, run input, drop it on return.
; Out: EAX = 0 (USE), 1 (TOSS), 2 (cancelled).
; ===========================================================================
.run_usetoss:
    mov dword [bm_opt_sel], 0
    mov eax, bm_str_use
    mov [bm_opt_a], eax
    mov eax, bm_str_toss
    mov [bm_opt_b], eax
    mov dword [bm_sub_int_w], USETOSS_INT_W
    mov dword [bm_sub_tot_w], USETOSS_TOT_W
    mov dword [bm_sub_dst], GB_TILEMAP0 + USETOSS_SROW * 32
    mov dword [g_window_count], 1   ; list only, then append the sub-box
    call .draw_sub_opt
    mov eax, USETOSS_WX
    mov ebx, USETOSS_WY
    mov ecx, USETOSS_CLIP
    mov edx, USETOSS_MAXY
    mov esi, GB_TILEMAP0
    mov edi, USETOSS_SROW
    call add_window                 ; count = 2
    call .opt2_run                  ; EAX = result
    push eax
    mov dword [g_window_count], 1   ; drop the sub-box
    pop eax
    ret

; ===========================================================================
; Toss-quantity chooser — append the quantity box, run UP/DOWN/A/B input.
; Out: CF=0 if a quantity was chosen (A; box left appended for the confirm),
;      CF=1 if cancelled (B). bm_toss_qty holds the choice.
; ===========================================================================
.run_qty:
    call .show_qty_window           ; count → +1
.q_loop:
    call DelayFrame
    movzx eax, byte [ebp + H_JOY_PRESSED]
    test al, PAD_UP
    jnz .q_up
    test al, PAD_DOWN
    jnz .q_down
    test al, PAD_A
    jnz .q_choose
    test al, PAD_B
    jnz .q_cancel
    jmp .q_loop
.q_up:
    mov eax, [bm_toss_qty]
    inc eax
    mov ecx, [bm_selected]
    shl ecx, 1
    movzx edx, byte [ebp + wBagItems + ecx + 1]   ; item qty (ceiling)
    cmp eax, edx
    jbe .q_store
    mov eax, 1                  ; past max → wrap to 1
    jmp .q_store
.q_down:
    mov eax, [bm_toss_qty]
    dec eax
    jnz .q_store
    mov ecx, [bm_selected]
    shl ecx, 1
    movzx eax, byte [ebp + wBagItems + ecx + 1]   ; below 1 → wrap to max
.q_store:
    mov [bm_toss_qty], eax
    call .draw_qty              ; redraw the box content (descriptor unchanged)
    jmp .q_loop
.q_choose:
    call .opt_release
    clc
    ret
.q_cancel:
    call .opt_release
    stc
    ret

; --- EAX(id, 1-based) → EAX = flat ptr to that ItemNames entry --------------
; Walks the '@'-terminated ItemNames table, skipping (id-1) names.
.find_item_name:
    movzx ecx, al
    dec ecx                     ; names to skip
    mov eax, ItemNames
.fin_skip:
    test ecx, ecx
    jz .fin_done
.fin_scan:
    mov dl, [eax]
    inc eax
    cmp dl, CHAR_TERM
    jne .fin_scan
    dec ecx
    jmp .fin_skip
.fin_done:
    ret

; --- AL = item id → key-item test (pret IsKeyItem_). ZF=0 (NZ) if key/untossable,
;     ZF=1 (Z) if tossable. Clobbers EAX, ECX. ---------------------------------
; HMs ($C4-$C8) are key; TMs ($C9+) are tossable; everything below uses the
; KeyItemFlags bit array, testing bit (id-1).
.is_key_item:
    cmp al, 0xC4
    jb .ik_bitfield
    cmp al, 0xC9
    jb .ik_key                  ; $C4..$C8 = HM → key
    xor al, al                  ; $C9+ = TM → tossable (ZF=1)
    ret
.ik_bitfield:
    movzx ecx, al
    dec ecx                     ; bit index (id - 1)
    mov eax, ecx
    shr eax, 3                  ; byte index
    and ecx, 7                  ; bit within byte
    mov al, [KeyItemFlags + eax]   ; flat table
    shr al, cl
    and al, 1                   ; ZF=0 if key bit set, ZF=1 if clear
    ret
.ik_key:
    mov al, 1
    and al, al                  ; ZF=0 → key
    ret

; ===========================================================================
; Rendering — render each box into the W_TILEMAP scratch (20-stride), then
; .copy_box blits W×H tiles (col 0) into its GB_TILEMAP0 region (32-stride).
; ===========================================================================

; --- render the whole list box (border + visible entries + cursor + ▼) -------
.render:
    ; Box border (also fills the interior with spaces, clearing stale text).
    mov esi, W_TILEMAP
    mov bl, LIST_INT_W
    mov bh, LIST_INT_H
    call TextBoxBorder

    xor ebx, ebx                ; slot 0..BM_VISIBLE-1
.row_loop:
    mov eax, [bm_scroll]
    add eax, ebx                ; entry index = scroll + slot
    cmp eax, [bm_num_entries]
    jae .row_next               ; past the list end → blank slot

    ; name dest = W_TILEMAP + (LIST_NAME_ROW0 + slot*2)*20 + LIST_NAME_COL
    mov ecx, ebx
    imul ecx, ecx, LIST_ROW_STEP
    add ecx, LIST_NAME_ROW0
    imul ecx, ecx, 20
    add ecx, W_TILEMAP + LIST_NAME_COL
    mov esi, ecx                ; save name dest

    ; CANCEL tail entry (index == num_entries-1)?
    mov edx, [bm_num_entries]
    dec edx
    cmp eax, edx
    je .row_cancel

    ; --- item entry: name, then "×qty" on the row below -------------------
    mov ecx, eax
    shl ecx, 1                  ; entry*2
    movzx edx, byte [ebp + wBagItems + ecx]   ; item id
    mov al, dl
    call .find_item_name        ; EAX = flat name ptr (clobbers EAX/ECX/EDX)
    call place_flat_str         ; ESI = name dest, EAX = flat ptr

    ; Key items / HMs show no quantity (pret PrintListMenuEntries: IsKeyItem skip).
    mov ecx, [bm_scroll]
    add ecx, ebx
    shl ecx, 1
    movzx eax, byte [ebp + wBagItems + ecx]       ; item id
    call .is_key_item           ; ZF=0 (NZ) if key item / HM
    jnz .row_next               ; key item → no qty printed

    ; quantity at wBagItems + entry*2 + 1
    mov ecx, [bm_scroll]
    add ecx, ebx
    shl ecx, 1
    movzx edx, byte [ebp + wBagItems + ecx + 1]   ; EDX = qty (1..99)

    ; qty dest = W_TILEMAP + (LIST_NAME_ROW0 + slot*2 + 1)*20 + LIST_QTY_COL
    mov ecx, ebx
    imul ecx, ecx, LIST_ROW_STEP
    add ecx, LIST_NAME_ROW0 + 1
    imul ecx, ecx, 20
    lea edi, [ebp + ecx + W_TILEMAP + LIST_QTY_COL]
    mov byte [edi], CHAR_TIMES
    ; tens digit (or space if qty < 10), then ones
    mov eax, edx
    mov cl, 10
    div cl                      ; AL = qty/10, AH = qty%10
    movzx ecx, ah               ; ones
    movzx eax, al               ; tens
    test eax, eax
    jnz .qty_tens
    mov byte [edi + 1], TILE_SPC
    jmp .qty_ones
.qty_tens:
    add eax, CHAR_DIGIT0
    mov [edi + 1], al
.qty_ones:
    add ecx, CHAR_DIGIT0
    mov [edi + 2], cl
    jmp .row_next

.row_cancel:
    mov eax, bm_str_cancel
    call place_flat_str         ; ESI already = name dest

.row_next:
    inc ebx
    cmp ebx, BM_VISIBLE
    jb .row_loop

    ; ▼ "more below" indicator if there are entries past the window.
    mov eax, [bm_scroll]
    add eax, BM_VISIBLE
    cmp eax, [bm_num_entries]
    jae .no_down_arrow
    mov byte [ebp + W_TILEMAP + LIST_DOWN_ROW * 20 + LIST_DOWN_COL], CHAR_DOWN
.no_down_arrow:

    ; cursor ▶ at (LIST_CURSOR_COL, NAME_ROW0 + (selected - scroll)*2)
    mov eax, [bm_selected]
    sub eax, [bm_scroll]
    imul eax, eax, LIST_ROW_STEP
    add eax, LIST_NAME_ROW0
    imul eax, eax, 20
    mov byte [ebp + eax + W_TILEMAP + LIST_CURSOR_COL], CHAR_CURSOR

    ; hollow ▷ over the SELECT-swap held item, if one is pending and on-screen.
    ; Drawn after the filled ▶ so when the navigation cursor sits on the held item
    ; the hollow arrow wins — faithful to PlaceUnfilledArrowMenuCursor.
    mov eax, [bm_swap]
    test eax, eax
    jz .no_swap_cursor
    dec eax                     ; held item absolute index
    sub eax, [bm_scroll]        ; → visible slot
    js .no_swap_cursor          ; scrolled off the top
    cmp eax, BM_VISIBLE
    jae .no_swap_cursor         ; scrolled off the bottom
    imul eax, eax, LIST_ROW_STEP
    add eax, LIST_NAME_ROW0
    imul eax, eax, 20
    mov byte [ebp + eax + W_TILEMAP + LIST_CURSOR_COL], CHAR_SWAP_CUR
.no_swap_cursor:

    ; copy 16×11 scratch → GB_TILEMAP0 list region.
    mov ecx, LIST_TOTAL_W
    mov edx, LIST_TOTAL_H
    mov edi, GB_TILEMAP0 + LIST_SROW * 32
    call .copy_box
    ret

; --- render a generic two-option box (USE/TOSS or YES/NO) into its region ----
; Reads bm_sub_int_w / bm_sub_tot_w / bm_sub_dst, bm_opt_a/_b, bm_opt_sel.
.draw_sub_opt:
    mov esi, W_TILEMAP
    mov ebx, [bm_sub_int_w]
    mov bh, OPT_INT_H           ; BH = interior height (3), BL = interior width
    call TextBoxBorder
    mov esi, W_TILEMAP + OPT_A_ROW * 20 + OPT_TEXT_COL
    mov eax, [bm_opt_a]
    call place_flat_str
    mov esi, W_TILEMAP + OPT_B_ROW * 20 + OPT_TEXT_COL
    mov eax, [bm_opt_b]
    call place_flat_str
    ; cursor: clear both cells, set the selected one.
    mov byte [ebp + W_TILEMAP + OPT_A_ROW * 20 + OPT_CURSOR_COL], TILE_SPC
    mov byte [ebp + W_TILEMAP + OPT_B_ROW * 20 + OPT_CURSOR_COL], TILE_SPC
    cmp dword [bm_opt_sel], 0
    jne .dso_b
    mov byte [ebp + W_TILEMAP + OPT_A_ROW * 20 + OPT_CURSOR_COL], CHAR_CURSOR
    jmp .dso_copy
.dso_b:
    mov byte [ebp + W_TILEMAP + OPT_B_ROW * 20 + OPT_CURSOR_COL], CHAR_CURSOR
.dso_copy:
    mov ecx, [bm_sub_tot_w]
    mov edx, OPT_TOT_H
    mov edi, [bm_sub_dst]
    call .copy_box
    ret

; --- render the toss-quantity box ("×NN", leading zero) into its region ------
.draw_qty:
    mov esi, W_TILEMAP
    mov bl, 3                   ; interior width  (total 5)
    mov bh, 1                   ; interior height (total 3)
    call TextBoxBorder
    ; "×" at box-rel (1,1); 2-digit qty (leading zero, pret InitialQuantityText).
    mov edi, W_TILEMAP + 1 * 20 + 1
    mov byte [ebp + edi], CHAR_TIMES
    movzx eax, byte [bm_toss_qty]
    mov cl, 10
    div cl                      ; AL = tens, AH = ones
    movzx ecx, ah
    movzx eax, al
    add eax, CHAR_DIGIT0        ; always show tens digit (leading zero)
    mov [ebp + edi + 1], al
    add ecx, CHAR_DIGIT0
    mov [ebp + edi + 2], cl
    ; copy 5×3 scratch → GB_TILEMAP0 quantity region.
    mov ecx, 5
    mov edx, 3
    mov edi, GB_TILEMAP0 + QTY_SROW * 32
    call .copy_box
    ret

; --- copy a width×height tile rect from W_TILEMAP (20-stride, col 0) to a ------
;     GB_TILEMAP0 region (32-stride, col 0).
; In: ECX = width, EDX = height, EDI = dest base offset (EBP-rel into GB_TILEMAP0).
; Clobbers EAX, EBX, ECX, EDX, ESI, EDI.
.copy_box:
    mov [bm_cb_w], ecx
    mov [bm_cb_h], edx
    mov [bm_cb_dst], edi
    xor ebx, ebx                ; row
.cb_row:
    mov esi, ebx
    imul esi, esi, 20
    lea esi, [ebp + esi + W_TILEMAP]
    mov edi, ebx
    shl edi, 5                  ; row * 32
    add edi, [bm_cb_dst]
    lea edi, [ebp + edi]
    mov ecx, [bm_cb_w]
    rep movsb
    inc ebx
    cmp ebx, [bm_cb_h]
    jb .cb_row
    ret

; ===========================================================================
; Generic two-option input loop (USE/TOSS, YES/NO). The descriptor is already
; appended; this only re-renders content on cursor moves.
; Out: EAX = 0 (top option), 1 (bottom option), 2 (cancelled with B).
; ===========================================================================
.opt2_run:
.o2_render:
    call .draw_sub_opt
.o2_loop:
    call DelayFrame
    movzx eax, byte [ebp + H_JOY_PRESSED]
    test al, PAD_UP
    jnz .o2_up
    test al, PAD_DOWN
    jnz .o2_down
    test al, PAD_A
    jnz .o2_confirm
    test al, PAD_B
    jnz .o2_cancel
    jmp .o2_loop
.o2_up:
    mov dword [bm_opt_sel], 0
    jmp .o2_render
.o2_down:
    mov dword [bm_opt_sel], 1
    jmp .o2_render
.o2_confirm:
    call .opt_release
    mov eax, [bm_opt_sel]        ; 0 or 1
    ret
.o2_cancel:
    call .opt_release
    mov eax, 2                   ; cancelled
    ret

; wait for A and B to be released before returning to the caller's edge-reads.
.opt_release:
    call DelayFrame
    test byte [ebp + H_JOY_HELD], PAD_A | PAD_B
    jnz .opt_release
    ret
