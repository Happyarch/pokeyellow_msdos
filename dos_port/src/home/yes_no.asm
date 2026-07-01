; ===========================================================================
; yes_no.asm — faithful YES/NO (two-option) menu framework.
; Intended repo path: dos_port/src/home/yes_no.asm
;
; Port of pret home/yes_no.asm + the TWO_OPTION_MENU path of
; engine/menus/text_box.asm:DisplayTwoOptionMenu, plus the
; data/yes_no_menu_strings.asm:TwoOptionMenuStrings table.
;
;   pret ref: home/yes_no.asm
;             engine/menus/text_box.asm:DisplayTwoOptionMenu (205-310)
;             data/yes_no_menu_strings.asm:TwoOptionMenuStrings
;             constants/menu_constants.asm (two-option menu constants)
;
; CARRY CONTRACT (preserved from pret DisplayTwoOptionMenu):
;   YesNoChoice / DisplayYesNoChoice / all two-option entry points return:
;     CF = 0 (and wCurrentMenuItem = 0)  -> the FIRST  option was chosen
;     CF = 1 (and wCurrentMenuItem = 1)  -> the SECOND option was chosen
;   For the default YES_NO_MENU the first option is "YES", so:
;     YES -> carry clear (AL/wCurrentMenuItem = 0)
;     NO  -> carry set   (AL/wCurrentMenuItem = 1)   (also when B is pressed)
;   wChosenMenuItem and wMenuExitMethod are also set as pret does
;   (CHOSE_FIRST_ITEM / CHOSE_SECOND_ITEM).
;
; -------------------------------------------------------------------------
; UI PROJECTION (see docs/ui_projection.md) — HARD REQUIREMENT.
; The two-option box is NEVER emitted at raw GB tile coords. It is rendered
; into the 20-stride W_TILEMAP scratch (TextBoxBorder/place_flat_str), mirrored
; to GB_TILEMAP0, and shown as a projected WINDOW DESCRIPTOR (add_window). The
; projected wx/wy/clip_w/max_y come straight from the anchor rule. This reuses
; the SAME mechanism the bag YES/NO box uses (bag_menu.asm .show_yesno_window).
;
; Two contexts share this framework, selected by [yn_proj_mode]:
;   overworld (mode 0, DEFAULT): per-element TOP-RIGHT anchor, X+20 / Y+0
;                                 (matches bag YES/NO GB(14,7) -> wx=279 wy=56).
;   battle    (mode 1):          uniform battle center, X+10 / Y+3.
; The battle caller (e.g. core.asm "use next Pokémon?") sets [yn_proj_mode]=1
; before calling; everything else is identical. See the ; PROJ tags at the
; placement site (yn_show_window) and the SUMMARY registry proposal.
; TODO(battle-verify): no battle caller is wired yet — the battle-mode numbers
; are projected & land in-viewport by construction, but need a live check when
; the first battle YES/NO caller lands.
;
; Register map: A=AL, BC=BX, DE=DX, HL=ESI, EBP=GB base; GB memory = [EBP+addr].
; Build (standalone check):
;   nasm -f coff -I dos_port/include -I dos_port -o /dev/null yes_no.asm
; ===========================================================================

%include "gb_memmap.inc"
%include "gb_constants.inc"

bits 32

; ---------------------------------------------------------------------------
; Local tile/char constants (mirror bag_menu.asm's local defs; these are
; charmap glyphs, not GB-memory symbols).
; ---------------------------------------------------------------------------
%ifndef CHAR_CURSOR
CHAR_CURSOR    equ 0xED          ; ▶ navigation cursor (charmap.asm)
%endif
%ifndef TILE_SPC
TILE_SPC       equ 0x7F          ; blank tile
%endif
%ifndef CHAR_TERM
CHAR_TERM      equ 0x50          ; '@' string terminator
%endif

; Menu WRAM (wTextBoxID/wTwoOptionMenuID/wChosenMenuItem/wMenuExitMethod) and the
; two-option menu constants (TWO_OPTION_MENU, YES_NO_MENU..NO_YES_MENU, CHOSE_*) now
; live canonically in gb_memmap.inc / gb_constants.inc (Wave 4 integration).

; GB_TILEMAP0 source row the projected box is mirrored to (matches bag YES/NO).
YN_SROW        equ 16

; -------------------------------------------------------------------------
extern TextBoxBorder            ; ESI=top-left(EBP-rel), BL=int_w, BH=int_h
extern place_flat_str           ; EAX=flat str ptr, ESI=tile-buf pos -> writes glyphs
extern PlaceMenuCursor          ; home/window.asm — draws ▶ at wTopMenuItem{X,Y}
extern HandleMenuInput          ; home/window.asm — vertical menu loop, AL=pressed keys
extern DelayFrame               ; one frame + present (drives the window compositor)
extern add_window               ; EAX=wx EBX=wy ECX=clip_w EDX=max_y ESI=tilemap EDI=srow
extern g_window_count           ; ppu/frame.asm — active window-descriptor count
extern menu_item_step           ; window.asm — cursor per-item row step (bytes)
extern menu_redraw_cb           ; window.asm — per-frame side-info redraw cb (0=none)
extern text_row_stride          ; text.asm — current W_TILEMAP row stride

global YesNoChoice
global TwoOptionMenu
global DisplayYesNoChoice
global WideYesNoChoice
global YesNoChoicePokeCenter
global InitYesNoTextBoxParameters

; ===========================================================================
section .bss
; ---------------------------------------------------------------------------
; Box placement + geometry for the current invocation. Set by the entry-point
; equivalents of pret's hlcoord/lb bc (which fix box top-left + cursor).
; ---------------------------------------------------------------------------
yn_box_col:     resd 1          ; box top-left GB column  (pret hlcoord X)
yn_box_row:     resd 1          ; box top-left GB row     (pret hlcoord Y)
yn_proj_mode:   resd 1          ; 0 = overworld (X+20/Y+0), 1 = battle (X+10/Y+3)
yn_tot_w:       resd 1          ; total box width  (int_w + 2)
yn_tot_h:       resd 1          ; total box height (int_h + 2)
yn_saved_wc:    resd 1          ; g_window_count on entry (restored on exit)
yn_saved_stride:resd 1          ; text_row_stride on entry (restored on exit)
yn_pressed:     resd 1          ; HandleMenuInput result (keys), kept across feedback

; ===========================================================================
section .text

; ---------------------------------------------------------------------------
; YesNoChoice — the standard YES/NO box. pret ref: home/yes_no.asm:YesNoChoice.
; In:  EBP = GB base. Out: CF=0 -> YES, CF=1 -> NO. (see carry contract above)
; ---------------------------------------------------------------------------
YesNoChoice:
    ; pret: call SaveScreenTilesToBuffer1 — in the port's window-descriptor
    ; model the box is a non-destructive overlay, so "restore" = drop our
    ; window descriptor on exit (done in yn_run). No BG tile save needed.
    call InitYesNoTextBoxParameters
    jmp DisplayYesNoChoice

; ---------------------------------------------------------------------------
; TwoOptionMenu — pret ref: home/yes_no.asm:TwoOptionMenu (unreferenced).
; Sets wTextBoxID = TWO_OPTION_MENU then runs the same YES_NO box.
; ---------------------------------------------------------------------------
TwoOptionMenu:
    mov byte [ebp + wTextBoxID], TWO_OPTION_MENU
    call InitYesNoTextBoxParameters
    jmp DisplayYesNoChoice          ; pret: jp DisplayTextBoxID -> TWO_OPTION path

; ---------------------------------------------------------------------------
; InitYesNoTextBoxParameters — pret ref: home/yes_no.asm.
;   xor a ; YES_NO_MENU        -> wTwoOptionMenuID = 0
;   hlcoord 14, 7              -> box top-left GB(14,7)
;   lb bc, 8, 15              -> cursor (Y=8, X=15); implied by box+geometry here
; ---------------------------------------------------------------------------
InitYesNoTextBoxParameters:
    mov byte [ebp + wTwoOptionMenuID], YES_NO_MENU
    mov dword [yn_box_col], 14
    mov dword [yn_box_row], 7
    mov dword [yn_proj_mode], 0         ; overworld anchor (battle caller sets 1)
    ret

; ---------------------------------------------------------------------------
; YesNoChoicePokeCenter — pret ref: home/yes_no.asm:YesNoChoicePokeCenter.
;   HEAL_CANCEL_MENU, hlcoord 11,6, box 9x6 (blank line before first item).
; ---------------------------------------------------------------------------
YesNoChoicePokeCenter:
    mov byte [ebp + wTwoOptionMenuID], HEAL_CANCEL_MENU
    mov dword [yn_box_col], 11
    mov dword [yn_box_row], 6
    mov dword [yn_proj_mode], 0         ; overworld anchor
    jmp DisplayYesNoChoice

; ---------------------------------------------------------------------------
; WideYesNoChoice — pret ref: home/yes_no.asm:WideYesNoChoice (unreferenced).
;   WIDE_YES_NO_MENU, hlcoord 12,7, box 8x5.
; ---------------------------------------------------------------------------
WideYesNoChoice:
    mov byte [ebp + wTwoOptionMenuID], WIDE_YES_NO_MENU
    mov dword [yn_box_col], 12
    mov dword [yn_box_row], 7
    mov dword [yn_proj_mode], 0         ; overworld anchor
    ; fall through

; ---------------------------------------------------------------------------
; DisplayYesNoChoice — pret ref: home/yes_no.asm:DisplayYesNoChoice, which sets
; wTextBoxID=TWO_OPTION_MENU and calls DisplayTextBoxID (dispatching to
; DisplayTwoOptionMenu). We inline the TWO_OPTION_MENU path directly.
; In: wTwoOptionMenuID + yn_box_col/row set. Out: carry = chosen option.
; ---------------------------------------------------------------------------
DisplayYesNoChoice:
    mov byte [ebp + wTextBoxID], TWO_OPTION_MENU
    jmp DisplayTwoOptionMenu

; ===========================================================================
; DisplayTwoOptionMenu — faithful port of engine/menus/text_box.asm (205-310).
;
; pret sequence: set BIT_NO_TEXT_DELAY; wMaxMenuItem=1; wMenuWatchedKeys=A|B;
; wTopMenuItem{Y,X}=b,c; default item from BIT_SECOND_MENU_OPTION_DEFAULT;
; draw TextBoxBorder + option strings; HandleMenuInput; B -> 2nd item, else A ->
; wCurrentMenuItem; DelayFrames 15; restore; carry = chose-second.
; ===========================================================================
DisplayTwoOptionMenu:
    pushad

    ; --- read + consume the "default to second option" bit (pret:
    ;     bit BIT_SECOND_MENU_OPTION_DEFAULT,[hl] / res ...) ---------------
    movzx ebx, byte [ebp + wTwoOptionMenuID]
    xor eax, eax
    test bl, 1 << BIT_SECOND_MENU_OPTION_DEFAULT
    jz .default_first
    mov eax, 1                       ; default = second option
.default_first:
    and bl, ~(1 << BIT_SECOND_MENU_OPTION_DEFAULT)   ; masked menu id (0..7)
    mov [ebp + wTwoOptionMenuID], bl
    mov [ebp + wCurrentMenuItem], al

    ; --- cutscene text-delay suppression (pret set BIT_NO_TEXT_DELAY) ------
    or byte [ebp + W_STATUS_FLAGS_5], 1 << BIT_NO_TEXT_DELAY

    ; --- force stride-20 W_TILEMAP staging (battle enters at stride 40) ----
    mov eax, [text_row_stride]
    mov [yn_saved_stride], eax
    mov dword [text_row_stride], 20

    ; --- descriptor table lookup: EBX = &TwoOptionMenuDesc[id] -------------
    ;     each entry = 12 bytes: int_w,int_h,blank,pad, opt_a(dd), opt_b(dd)
    movzx eax, byte [ebp + wTwoOptionMenuID]
    imul eax, eax, TOMD_SIZE
    lea ebx, [TwoOptionMenuDesc + eax]

    movzx eax, byte [ebx + TOMD_INT_W]
    add eax, 2
    mov [yn_tot_w], eax                          ; total width  = int_w + 2
    movzx eax, byte [ebx + TOMD_INT_H]
    add eax, 2
    mov [yn_tot_h], eax                          ; total height = int_h + 2

    ; first-option box-relative row: blank ? 2 : 1 (pret bc = 2*20+2 / 20+2)
    xor ecx, ecx
    mov cl, 1
    cmp byte [ebx + TOMD_BLANK], 0
    je .have_frow
    mov cl, 2
.have_frow:                                       ; ECX = first-option rel row

    ; --- render the border into the W_TILEMAP scratch at origin (row0,col0) -
    push ecx                                       ; save first-opt rel row
    mov esi, W_TILEMAP
    mov bh, [ebx + TOMD_INT_H]                     ; BH = interior height
    mov bl, [ebx + TOMD_INT_W]                     ; BL = interior width
    call TextBoxBorder

    ; --- option A text at rel (frow, 2), option B at (frow+1, 2) -----------
    pop ecx
    push ecx
    mov eax, ecx
    imul eax, eax, 20
    lea esi, [eax + W_TILEMAP + 2]                 ; ESI = rel(frow,2)
    mov eax, [ebx + TOMD_OPT_A]
    call place_flat_str
    pop ecx
    inc ecx                                        ; frow+1
    push ecx
    mov eax, ecx
    imul eax, eax, 20
    lea esi, [eax + W_TILEMAP + 2]                 ; ESI = rel(frow+1,2)
    mov eax, [ebx + TOMD_OPT_B]
    call place_flat_str

    ; --- menu-input state (pret DisplayTwoOptionMenu block) ----------------
    pop ecx                                        ; ECX = frow (first option row)
    mov [ebp + wTopMenuItemY], cl                  ; cursor top row (W_TILEMAP rel)
    mov byte [ebp + wTopMenuItemX], 1              ; cursor col (box-rel 1)
    mov byte [ebp + wMaxMenuItem], 1
    mov byte [ebp + wMenuWatchedKeys], PAD_A | PAD_B
    mov byte [ebp + wLastMenuItem], 0
    mov dword [menu_item_step], 20                 ; single-spaced: 1 row/item

    ; --- project + append the window descriptor ----------------------------
    call yn_show_window                            ; also saves g_window_count

    ; --- run HandleMenuInput; per-frame mirror keeps the cursor projected ---
    mov dword [menu_redraw_cb], yn_mirror          ; re-mirror box each loop
    call HandleMenuInput                           ; AL = watched keys pressed
    mov dword [menu_redraw_cb], 0
    movzx eax, al
    mov [yn_pressed], eax                           ; survive the feedback loop

    ; keep the box visible ~15 frames on the final choice (pret DelayFrames 15)
    mov ecx, 15
.fb_loop:
    call DelayFrame
    dec ecx
    jnz .fb_loop

    ; --- decide the chosen option (pret: B -> 2nd, else A -> wCurrentMenuItem)
    mov al, [yn_pressed]
    test al, PAD_B
    jnz .chose_second
    movzx eax, byte [ebp + wCurrentMenuItem]
    test al, al
    jnz .chose_second
.chose_first:
    mov byte [ebp + wCurrentMenuItem], 0
    mov byte [ebp + wChosenMenuItem], 0
    mov byte [ebp + wMenuExitMethod], CHOSE_FIRST_ITEM
    call yn_teardown
    popad
    clc                                             ; CF=0 -> first option (YES)
    ret
.chose_second:
    mov byte [ebp + wCurrentMenuItem], 1
    mov byte [ebp + wChosenMenuItem], 1
    mov byte [ebp + wMenuExitMethod], CHOSE_SECOND_ITEM
    call yn_teardown
    popad
    stc                                             ; CF=1 -> second option (NO)
    ret

; ---------------------------------------------------------------------------
; yn_teardown — restore state: drop our window descriptor + text_row_stride,
; clear BIT_NO_TEXT_DELAY. Mirrors pret's LoadScreenTilesFromBuffer1 net effect
; (screen returns to its pre-box state). Preserves EAX (carry decided by caller).
; ---------------------------------------------------------------------------
yn_teardown:
    push eax
    mov eax, [yn_saved_wc]
    mov [g_window_count], eax                       ; drop our appended box
    mov eax, [yn_saved_stride]
    mov [text_row_stride], eax
    and byte [ebp + W_STATUS_FLAGS_5], ~(1 << BIT_NO_TEXT_DELAY)
    pop eax
    ret

; ---------------------------------------------------------------------------
; yn_show_window — mirror the staged box to GB_TILEMAP0 and append a PROJECTED
; window descriptor. Saves g_window_count first so teardown can drop exactly our
; box (preserving any windows the caller already had).
;
; PROJECTION (anchor rule, docs/ui_projection.md):
;   mode 0 (overworld): our_col = col + 20 ; our_row = row + 0   (TOP-RIGHT)
;   mode 1 (battle):    our_col = col + 10 ; our_row = row + 3   (battle center)
;   wx = our_col*8 + 7 ; wy = our_row*8 ; clip = tot_w*8 ; max_y = (our_row+tot_h)*8
;
; ; PROJ overworld-ui: GB(14,7) 6x5 --(anchor=top-right, X+20, Y+0)--> wx=279 wy=56 clip=48 max_y=96
; ; PROJ overworld-ui: GB(12,7) 8x5 --(anchor=top-right, X+20, Y+0)--> wx=263 wy=56 clip=64 max_y=96
; ; PROJ overworld-ui: GB(11,6) 9x6 --(anchor=top-right, X+20, Y+0)--> wx=255 wy=48 clip=72 max_y=96
; ; PROJ battle:       GB(cc,rr) WxH --(battle center, X+10, Y+3)--> wx=(cc+10)*8+7 wy=(rr+3)*8 ...
; ---------------------------------------------------------------------------
yn_show_window:
    mov eax, [g_window_count]
    mov [yn_saved_wc], eax                          ; remember caller's window list

    call yn_mirror                                  ; W_TILEMAP box -> GB_TILEMAP0

    ; horizontal/vertical shifts by projection mode
    mov ecx, 20                                     ; H_SHIFT (overworld)
    mov edx, 0                                      ; V_SHIFT (overworld)
    cmp dword [yn_proj_mode], 0
    je .have_shift
    mov ecx, 10                                     ; battle center
    mov edx, 3
.have_shift:
    ; our_col = col + H_SHIFT ; wx = our_col*8 + 7
    mov eax, [yn_box_col]
    add eax, ecx
    shl eax, 3
    add eax, 7                                       ; EAX = wx
    ; our_row = row + V_SHIFT
    mov ebx, [yn_box_row]
    add ebx, edx                                     ; EBX = our_row
    ; max_y = (our_row + tot_h)*8   (compute before clobbering EBX)
    mov edx, ebx
    add edx, [yn_tot_h]
    shl edx, 3                                       ; EDX = max_y
    ; wy = our_row*8
    shl ebx, 3                                       ; EBX = wy
    ; clip_w = tot_w*8
    mov ecx, [yn_tot_w]
    shl ecx, 3                                       ; ECX = clip_w
    ; ESI = tilemap base, EDI = start row
    mov esi, GB_TILEMAP0
    mov edi, YN_SROW
    call add_window
    ret

; ---------------------------------------------------------------------------
; yn_mirror — copy the tot_w x tot_h box from W_TILEMAP (stride 20, col 0) to
; GB_TILEMAP0 (stride 32) at row YN_SROW, col 0. Used both for the initial draw
; and as menu_redraw_cb so HandleMenuInput's live cursor reaches the compositor.
; All registers preserved (safe to call from the menu loop).
; ---------------------------------------------------------------------------
yn_mirror:
    pushad
    xor ebx, ebx                                    ; row index
.row:
    mov esi, ebx
    imul esi, esi, 20
    lea esi, [ebp + esi + W_TILEMAP]                ; src = W_TILEMAP + row*20
    mov edi, ebx
    shl edi, 5                                      ; row*32
    lea edi, [ebp + edi + GB_TILEMAP0 + YN_SROW * 32]
    mov ecx, [yn_tot_w]
    rep movsb
    inc ebx
    cmp ebx, [yn_tot_h]
    jb .row
    popad
    ret

; ===========================================================================
section .data
align 4

; ---------------------------------------------------------------------------
; TwoOptionMenuDesc — port of data/yes_no_menu_strings.asm:TwoOptionMenuStrings,
; indexed by the (masked) wTwoOptionMenuID. Per-entry: interior width/height
; passed to TextBoxBorder (pret's "width,height"), a "blank line before first
; item" flag, and two '@'-terminated option strings (placed on consecutive rows
; instead of pret's single string with a <NEXT>).
;   pret entries: width, height, blank, pointer.
; ---------------------------------------------------------------------------
; struct offsets
TOMD_INT_W  equ 0
TOMD_INT_H  equ 1
TOMD_BLANK  equ 2
; byte 3 = pad
TOMD_OPT_A  equ 4
TOMD_OPT_B  equ 8
TOMD_SIZE   equ 12

%macro two_option 5     ; int_w, int_h, blank, opt_a, opt_b
    db %1, %2, %3, 0
    dd %4, %5
%endmacro

TwoOptionMenuDesc:
    two_option 4, 3, 0, str_yes,   str_no      ; 0 YES_NO_MENU
    two_option 6, 3, 0, str_north, str_west    ; 1 NORTH_WEST_MENU
    two_option 6, 3, 0, str_south, str_east    ; 2 SOUTH_EAST_MENU
    two_option 6, 3, 0, str_yes,   str_no      ; 3 WIDE_YES_NO_MENU
    two_option 6, 3, 0, str_north, str_east    ; 4 NORTH_EAST_MENU
    two_option 7, 3, 0, str_trade, str_cancel  ; 5 TRADE_CANCEL_MENU
    two_option 7, 4, 1, str_heal,  str_cancel  ; 6 HEAL_CANCEL_MENU (blank 1st)
    two_option 4, 3, 0, str_no,    str_yes     ; 7 NO_YES_MENU

; option strings — charmap glyphs (A=0x80 .. Z=0x99), '@' = CHAR_TERM.
str_yes:    db 0x98,0x84,0x92, CHAR_TERM                          ; "YES"
str_no:     db 0x8D,0x8E, CHAR_TERM                               ; "NO"
str_north:  db 0x8D,0x8E,0x91,0x93,0x87, CHAR_TERM                ; "NORTH"
str_west:   db 0x96,0x84,0x92,0x93, CHAR_TERM                     ; "WEST"
str_south:  db 0x92,0x8E,0x94,0x93,0x87, CHAR_TERM                ; "SOUTH"
str_east:   db 0x84,0x80,0x92,0x93, CHAR_TERM                     ; "EAST"
str_trade:  db 0x93,0x91,0x80,0x83,0x84, CHAR_TERM                ; "TRADE"
str_cancel: db 0x82,0x80,0x8D,0x82,0x84,0x8B, CHAR_TERM           ; "CANCEL"
str_heal:   db 0x87,0x84,0x80,0x8B, CHAR_TERM                     ; "HEAL"
