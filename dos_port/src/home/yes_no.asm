; ===========================================================================
; yes_no.asm — the YES/NO (two-option) menu framework.
;
; AUDITED at menu-fidelity row 5 (2026-07-13). It was NOT "faithful", whatever the
; old header said: the two options were rendered one row apart and the cursor was
; placed one row below the first of them, so the ▶ sat next to the WRONG option.
; pret is DOUBLE-spaced here (its <NEXT> advances 2*SCREEN_WIDTH and PlaceMenuCursor
; steps 40 — see DisplayTwoOptionMenu). Both are fixed; treat the claims below as
; audited, not as inherited assertions.
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
extern CableClub_TextBoxBorder  ; engine/link/cable_club.asm — same interface;
                                ; TRADE_CANCEL_MENU border (pret text_box.asm:257)
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
global DisplayTwoOptionMenu     ; menus S2: DisplayTextBoxID_'s TWO_OPTION_MENU
                                ; dispatch target — the ONE two-option impl.
                                ; Port contract: box position comes from
                                ; yn_box_col/row (set by the entry points above),
                                ; not pret's b/c/hl register triple.

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
yn_frow:        resd 1          ; first option's box-relative row (blank ? 2 : 1)

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
    ; Kept in a named slot, NOT juggled on the stack. The push/pop dance this
    ; replaced ended up popping the LAST value pushed (the second option's row)
    ; into the cursor-row register, while its comment claimed it was `frow` — so
    ; wTopMenuItemY was set one row below the first option and the ▶ sat next to
    ; the wrong line. One slot, read three times, cannot drift like that.
    xor ecx, ecx
    mov cl, 1
    cmp byte [ebx + TOMD_BLANK], 0
    je .have_frow
    mov cl, 2
.have_frow:
    mov [yn_frow], ecx                             ; first-option box-relative row

    ; --- render the border into the W_TILEMAP scratch at origin (row0,col0) -
    ; NB: load the geometry via AX first — writing BH/BL directly from [ebx+..]
    ; would corrupt EBX (the descriptor pointer) between the two reads (S3 fix).
    mov esi, W_TILEMAP
    mov ah, [ebx + TOMD_INT_H]                     ; interior height
    mov al, [ebx + TOMD_INT_W]                     ; interior width
    push ebx
    mov bx, ax                                     ; BH = int_h, BL = int_w
    ; TRADE_CANCEL_MENU uses the cable-club border (pret text_box.asm:255-262)
    cmp byte [ebp + wTwoOptionMenuID], TRADE_CANCEL_MENU
    jne .notTradeCancelMenu
    call CableClub_TextBoxBorder
    jmp .afterTextBoxBorder
.notTradeCancelMenu:
    call TextBoxBorder
.afterTextBoxBorder:
    pop ebx                                        ; descriptor pointer restored
    ; DEVIATION(window-compositor): pret calls UpdateSprites here to hide OBJ that
    ; would otherwise show through the box. The port composites the window layer OVER
    ; OBJ (inverse of the GB's z-order), so this box occludes sprites by construction;
    ; calling UpdateSprites would only re-publish overworld OAM beneath a window that
    ; already covers it. Same reasoning as home/list_menu.asm:DisplayListMenuID.

    ; --- option A at rel (frow, 2), option B at rel (frow + 2, 2) ----------
    ; TWO rows apart, not one. pret stores the pair as ONE string joined by a
    ; `next` ($4E), and PlaceString's <NEXT> handler (home/text.asm:63) advances
    ; `2 * SCREEN_WIDTH` unless hUILayoutFlags' BIT_SINGLE_SPACED_LINES is set —
    ; and NOTHING in the two-option path sets it (the only setters are save.asm,
    ; learn_move.asm, printer2.asm and battle core.asm). So the two options are
    ; DOUBLE-SPACED, with a blank interior row between them.
    ; The descriptor heights confirm it and are otherwise unexplainable: a 2-item
    ; menu is given int_h 3 (options on interior rows 1 and 3) — or int_h 4 with
    ; `blank` for HEAL_CANCEL (rows 2 and 4). Single-spaced, every one of those
    ; boxes would carry a stray empty row at the bottom.
    ; Cross-check against pret's entry points, whose `lb bc` is the CURSOR (Y,X),
    ; not the box: YES/NO box GB(14,7) + cursor GB(15,8) = box-rel (col 1, row 1);
    ; PokéCenter box GB(11,6) + cursor GB(12,8) = box-rel (col 1, row 2) — which is
    ; exactly the `blank ? 2 : 1` first-option row computed above, and the second
    ; option sits a doubled cursor step below it.
    mov eax, [yn_frow]
    imul eax, eax, 20
    lea esi, [eax + W_TILEMAP + 2]                 ; ESI = rel(frow,2)
    mov eax, [ebx + TOMD_OPT_A]
    call place_flat_str
    mov eax, [yn_frow]
    add eax, 2                                     ; pret's <NEXT> = 2 rows
    imul eax, eax, 20
    lea esi, [eax + W_TILEMAP + 2]                 ; ESI = rel(frow+2,2)
    mov eax, [ebx + TOMD_OPT_B]
    call place_flat_str

    ; --- menu-input state (pret DisplayTwoOptionMenu block) ----------------
    mov ecx, [yn_frow]
    mov [ebp + wTopMenuItemY], cl                  ; cursor top row = FIRST option's row
    mov byte [ebp + wTopMenuItemX], 1              ; cursor col (box-rel 1)
    mov byte [ebp + wMaxMenuItem], 1
    mov byte [ebp + wMenuWatchedKeys], PAD_A | PAD_B
    mov byte [ebp + wLastMenuItem], 0
    ; pret: `xor a / ld [wLastMenuItem],a / ld [wMenuWatchMovingOutOfBounds],a`.
    ; The port set wLastMenuItem but never wMenuWatchMovingOutOfBounds, so this menu
    ; inherited whatever the PREVIOUS menu left there — and DisplayListMenuID sets it
    ; to 1. A YES/NO opened from a list (bag TOSS: list → "TOSS HOW MANY?" → YES/NO)
    ; therefore ran with out-of-bounds movement watching still armed.
    mov byte [ebp + wMenuWatchMovingOutOfBounds], 0
    ; Two rows per item — pret's PlaceMenuCursor default (home/window.asm:141 `ld bc,40`);
    ; it only drops to one row when hUILayoutFlags' BIT_DOUBLE_SPACED_MENU is SET (the
    ; constant name reads backwards), and nothing in this path sets it. Matches the
    ; doubled <NEXT> row step used for the option text above.
    mov dword [menu_item_step], 2 * 20

    ; --- project + append the window descriptor ----------------------------
    call yn_show_window                            ; also saves g_window_count

    ; pret clears the menu id + text-delay bit before taking input
    ; (text_box.asm:278-281: xor a / ld [wTwoOptionMenuID], a / res
    ; BIT_NO_TEXT_DELAY). yn_teardown's clear stays as a no-op backstop.
    mov byte [ebp + wTwoOptionMenuID], 0
    and byte [ebp + W_STATUS_FLAGS_5], ~(1 << BIT_NO_TEXT_DELAY)

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
; clear BIT_NO_TEXT_DELAY. Preserves EAX (carry decided by caller).
;
; DEVIATION(window-compositor): this is why the port has no
; TwoOptionMenu_SaveScreenTiles / TwoOptionMenu_RestoreScreenTiles (ledger M-5 —
; they are absent, not stubbed, and this is the reason). pret must SNAPSHOT the
; tilemap cells the box is about to overwrite and paste them back afterwards,
; because on the GB the box IS the tilemap. In the port the box is a window
; descriptor composited over an untouched background, so "restore" is just dropping
; the descriptor: nothing under it was ever modified.
;
; NOTE — a pret BUG this model cannot reproduce, deliberately. pret's own comment
; (engine/menus/text_box.asm, right below DisplayTwoOptionMenu) says: "Some of the
; wider/taller two option menus will not have the screen areas they cover be fully
; saved/restored by the two functions below. The bottom and right edges of the menu
; may remain after the function returns." That residue is a save/restore sizing bug;
; with no save/restore there is no residue. This is NOT a silent "fix" of a Gen-1
; bug we were supposed to preserve — it is unreachable in this rendering model, and
; is recorded here so the absence is explained rather than merely unnoticed.
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

; Option strings — Tier-1 DATA: generated by tools/gen_yes_no_strings.py through
; gb_text.encode, never hand-encoded charmap hex (the bytes it emits are
; byte-identical to the hand-written block this replaced). Regenerate: `make assets`.
%include "assets/yes_no_strings.inc"
