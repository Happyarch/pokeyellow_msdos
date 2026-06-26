; bag_menu.asm — overworld bag (ITEM) screen.
;
; A scrollable list of the player's bag items (name + "×NN" quantity), opened from
; the START menu's ITEM entry. Read-only for now: A on an item is a no-op (the
; USE/TOSS sub-menu is deferred UI); A on CANCEL or B exits back to the START menu.
;
; Modelled on pret's DisplayListMenuID / PrintListMenuEntries (home/list_menu.asm)
; ITEMLISTMENU path: 4 visible entries, name then "×qty", a CANCEL tail entry,
; scrolling via a top-of-window offset. Rendered through the GB window layer like
; the START menu (render into the 20-wide wTileMap scratch grid, copy the box rect
; to GB_TILEMAP1, blit via render_window with g_win_clip_w/g_win_max_y bounding).
;
; CALLER CONTRACT: the text font must already be resident in vFont — DisplayStartMenu
; loads it before dispatching here, so we do NOT swap it again. Input uses
; H_JOY_PRESSED (reliable: one DelayFrame → one joypad_update per loop iteration).
;
; Pret ref: home/list_menu.asm (ITEMLISTMENU subset).
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
extern g_win_clip_w
extern g_win_max_y
%ifdef DEBUG_BAGMENU
extern DumpBackbuffer
%endif

; --- layout (GB 20-wide logical wTileMap coords) ---
BM_BOX_W       equ 18        ; interior width → box cols 0-19 (full GB-screen width)
BM_BOX_H       equ 9         ; interior height → box rows 0-10
BM_BOX_ROWS    equ 11        ; total rows incl borders
BM_CURSOR_COL  equ 1         ; leftmost interior col
BM_NAME_COL    equ 2
BM_QTY_COL     equ 15        ; "×" col; tens at +1, ones at +2
BM_FIRST_ROW   equ 2         ; first entry row
BM_ROW_STEP    equ 2
BM_VISIBLE     equ 4         ; entries shown at once (pret's `ld b, 4`)
BM_DOWN_COL    equ 18        ; ▼ "more below" indicator col
BM_DOWN_ROW    equ 9         ; bottom interior row

; window placement: full 20-tile (160px) box centered in the 320px viewport, like
; the dialog box (WX-7=80 → px 80-240). Rows 0-10 → max_y = 11*8 = 88.
BM_WIN_WX      equ 87
BM_WIN_CLIP_W  equ 160
BM_WIN_MAX_Y   equ BM_BOX_ROWS * 8

CHAR_CURSOR    equ 0xED      ; ▶
CHAR_DOWN      equ 0xEE      ; ▼
CHAR_TIMES     equ 0xF1      ; ×
CHAR_DIGIT0    equ 0xF6      ; '0'; digit d → CHAR_DIGIT0 + d
TILE_SPC       equ 0x7F
CHAR_TERM      equ 0x50      ; '@'

section .data
align 4
; "CANCEL" (single-char charmap glyphs, '@'-terminated). C A N C E L.
bm_str_cancel: db 0x82, 0x80, 0x8D, 0x82, 0x84, 0x8B, CHAR_TERM

section .bss
align 4
bm_selected:   resd 1        ; absolute index into the entry list (0..num_entries-1)
bm_scroll:     resd 1        ; index of the top visible entry
bm_num_entries: resd 1       ; bag item count + 1 (the CANCEL tail)
bm_toss_qty:   resd 1        ; quantity being chosen to toss (1..item qty)

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

    ; window placement / bounds for the box.
    mov byte  [ebp + H_WY], 0
    mov byte  [ebp + IO_WX], BM_WIN_WX
    mov dword [g_win_clip_w], BM_WIN_CLIP_W
    mov dword [g_win_max_y], BM_WIN_MAX_Y

    call .render

%ifdef DEBUG_BAGMENU
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

.select:
    ; CANCEL (last entry) closes. An item → TOSS flow (USE is deferred).
    mov eax, [bm_selected]
    inc eax
    cmp eax, [bm_num_entries]   ; selected == num_entries-1 ?
    je .exit

    ; item id at wBagItems + bm_selected*2 — key items can't be tossed.
    mov ecx, [bm_selected]
    shl ecx, 1
    movzx eax, byte [ebp + wBagItems + ecx]
    call .is_key_item           ; ZF=0 (NZ) if key item
    jnz .loop                   ; key item → can't toss (no-op for now)

    ; tossable: if only 1, toss it; else let the player choose 1..qty.
    mov ecx, [bm_selected]
    shl ecx, 1
    movzx edx, byte [ebp + wBagItems + ecx + 1]   ; item quantity
    mov dword [bm_toss_qty], 1
    cmp edx, 1
    je .toss_do

.tc_render:
    call .render_toss_qty       ; show the chosen count in the item's qty field
.tc_loop:
    call DelayFrame
    movzx eax, byte [ebp + H_JOY_PRESSED]
    test al, PAD_UP
    jnz .tc_up
    test al, PAD_DOWN
    jnz .tc_down
    test al, PAD_A
    jnz .toss_do
    test al, PAD_B
    jnz .tc_cancel
    jmp .tc_loop
.tc_up:
    mov eax, [bm_toss_qty]
    inc eax
    mov ecx, [bm_selected]
    shl ecx, 1
    movzx edx, byte [ebp + wBagItems + ecx + 1]   ; item qty (ceiling)
    cmp eax, edx
    jbe .tc_store
    mov eax, 1                  ; past max → wrap to 1
    jmp .tc_store
.tc_down:
    mov eax, [bm_toss_qty]
    dec eax
    jnz .tc_store
    mov ecx, [bm_selected]
    shl ecx, 1
    movzx eax, byte [ebp + wBagItems + ecx + 1]   ; below 1 → wrap to max
.tc_store:
    mov [bm_toss_qty], eax
    jmp .tc_render
.tc_cancel:
    call .render                ; restore the real qty display
    jmp .wait_a_release

.toss_do:
    ; wWhichPokemon = bm_selected (bag slot); wItemQuantity = bm_toss_qty.
    mov eax, [bm_selected]
    mov [ebp + wWhichPokemon], al
    mov eax, [bm_toss_qty]
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
    call .fix_scroll
    call .render
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

; --- redraw the whole box + visible entries + cursor into wTileMap, then copy --
.render:
    ; Box border (also fills the interior with spaces, clearing stale text).
    mov esi, W_TILEMAP
    mov bl, BM_BOX_W
    mov bh, BM_BOX_H
    call TextBoxBorder

    ; Draw the BM_VISIBLE entries.
    xor ebx, ebx                ; slot 0..BM_VISIBLE-1
.row_loop:
    mov eax, [bm_scroll]
    add eax, ebx                ; entry index = scroll + slot
    cmp eax, [bm_num_entries]
    jae .row_next               ; past the list end → blank slot

    ; ESI = wTileMap dest for this slot's name: (BM_NAME_COL, BM_FIRST_ROW + slot*2)
    mov ecx, ebx
    imul ecx, ecx, BM_ROW_STEP
    add ecx, BM_FIRST_ROW
    imul ecx, ecx, 20           ; row * 20 (logical width)
    add ecx, W_TILEMAP + BM_NAME_COL
    mov esi, ecx                ; save name dest

    ; Is this the CANCEL tail entry (index == num_entries-1)?
    mov edx, [bm_num_entries]
    dec edx
    cmp eax, edx
    je .row_cancel

    ; --- item entry: name + "×qty" ---
    ; bag pair at wBagItems + entry*2 : (id, qty)
    mov ecx, eax
    shl ecx, 1                  ; entry*2
    movzx edx, byte [ebp + wBagItems + ecx]   ; item id
    mov al, dl
    call .find_item_name        ; EAX = flat name ptr (clobbers EAX/ECX/EDX)
    call place_flat_str         ; ESI=name dest, EAX=flat ptr

    ; quantity at wBagItems + entry*2 + 1
    mov ecx, [bm_scroll]
    add ecx, ebx
    shl ecx, 1
    movzx edx, byte [ebp + wBagItems + ecx + 1]   ; EDX = qty (1..99)

    ; qty dest = name dest - BM_NAME_COL + BM_QTY_COL (same row)
    mov esi, [bm_scroll]
    add esi, ebx
    ; recompute row base offset cleanly:
    mov ecx, ebx
    imul ecx, ecx, BM_ROW_STEP
    add ecx, BM_FIRST_ROW
    imul ecx, ecx, 20
    lea edi, [ebp + ecx + W_TILEMAP + BM_QTY_COL]
    mov byte [edi], CHAR_TIMES
    ; tens digit (or space if qty < 10)
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
    mov byte [ebp + W_TILEMAP + BM_DOWN_ROW * 20 + BM_DOWN_COL], CHAR_DOWN
.no_down_arrow:

    ; cursor ▶ at (BM_CURSOR_COL, FIRST_ROW + (selected - scroll)*2)
    mov eax, [bm_selected]
    sub eax, [bm_scroll]
    imul eax, eax, BM_ROW_STEP
    add eax, BM_FIRST_ROW
    imul eax, eax, 20
    mov byte [ebp + eax + W_TILEMAP + BM_CURSOR_COL], CHAR_CURSOR

    ; --- copy the box rect (wTileMap cols 0-19) → GB_TILEMAP1 (cols 0-19) ---
    xor ecx, ecx                ; row
.copy_row:
    imul esi, ecx, 20
    lea esi, [ebp + esi + W_TILEMAP]
    mov edi, ecx
    shl edi, 5                  ; row * 32
    lea edi, [ebp + edi + GB_TILEMAP1]
    push ecx
    mov ecx, 20
    rep movsb
    pop ecx
    inc ecx
    cmp ecx, BM_BOX_ROWS
    jb .copy_row
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

; --- write "×NN" (bm_toss_qty, 2 digits) into the selected item's qty field in
;     GB_TILEMAP1 (live feedback during the toss-quantity choice). ------------
.render_toss_qty:
    mov eax, [bm_selected]
    sub eax, [bm_scroll]
    imul eax, eax, BM_ROW_STEP
    add eax, BM_FIRST_ROW
    imul eax, eax, 32           ; GB_TILEMAP1 row stride
    add eax, GB_TILEMAP1 + BM_QTY_COL
    mov edi, eax                ; EDI = GB_TILEMAP1 qty offset
    mov byte [ebp + edi], CHAR_TIMES
    movzx eax, byte [bm_toss_qty]
    mov cl, 10
    div cl                      ; AL = tens, AH = ones
    movzx ecx, ah
    movzx eax, al
    test eax, eax
    jnz .rtq_tens
    mov byte [ebp + edi + 1], TILE_SPC
    jmp .rtq_ones
.rtq_tens:
    add eax, CHAR_DIGIT0
    mov [ebp + edi + 1], al
.rtq_ones:
    add ecx, CHAR_DIGIT0
    mov [ebp + edi + 2], cl
    ret
