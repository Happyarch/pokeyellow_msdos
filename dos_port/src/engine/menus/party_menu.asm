; party_menu.asm — overworld party (POKéMON) screen.
;
; Lists the player's party the way the original game's party menu does: for each
; mon a name row ("NICK  :Llvl  STATUS") and an HP row (the 6-segment HP-bar
; gauge + "cur/ max"), opened from the START menu's POKéMON entry. Read-only for
; now: A is a no-op (the per-mon action sub-menu / summary screen are deferred);
; B exits to the START menu.
;
; Faithful to pret engine/menus/party_menu.asm:RedrawPartyMenu_ — name
; (GetPartyMonName/PlaceString), PrintLevel (":L" + digits), PrintStatusCondition
; (FNT / PSN / BRN / FRZ / PAR / SLP or blank), and DrawHP2 → DrawHPBar
; (engine/gfx/hp_bar.asm GetHPBarLength: pixels = curHP * 48 / maxHP, a 6-tile /
; 48-pixel gauge). The animated party-mon ICON sprites and the full-screen white
; takeover are still deferred (see the party-menu polish handoff).
;
; The HP-bar gauge + ":L" tiles ($62-$6e) live in the HpBarAndStatus tile set
; (font_battle_extra), which is NOT resident in the overworld — so we load it on
; entry (LoadHpBarAndStatusTilePatterns) and restore the box-drawing tiles it
; clobbers (LoadTextBoxTilePatterns) on exit so the START menu border redraws.
;
; The party is capped at 6, so every entry fits and there is no scrolling. The
; panel is borderless (cleared to the blank space tile $7F) and rendered through
; the GB window layer like the START / bag menus (draw into the 20-wide wTileMap
; scratch grid, copy cols 0-19 to GB_TILEMAP1, shown via a single window
; descriptor (set_single_window) bounding the box rect).
;
; CALLER CONTRACT: the text font must already be resident in vFont (the START
; menu loads it before dispatching here). Input uses H_JOY_PRESSED.
; ---------------------------------------------------------------------------
bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_macros.inc"

global DisplayPartyMenu

extern PlaceString           ; ESI=dest (EBP-rel), EDX=src offset (EBP-rel)
extern place_flat_str        ; src/text/text.asm — ESI=dest, EAX=flat src ptr
extern TextBoxBorder         ; src/text/text.asm — ESI=top-left, BL=int width, BH=int height
extern DelayFrame
extern set_single_window                 ; src/ppu/ppu.asm — define g_windows[] as one descriptor
extern add_window                        ; src/ppu/ppu.asm — append a window descriptor (multi-layer menus)
extern g_window_count                    ; src/ppu/ppu.asm — live descriptor count
extern g_bg_whiteout                     ; src/ppu/ppu.asm — full-screen white field
extern LoadHpBarAndStatusTilePatterns   ; src/gfx/load_font.asm
extern LoadTextBoxTilePatterns          ; restore box tiles for the START menu
extern LoadTilesetTilePatternData       ; restore overworld tileset ($9000) on exit
extern IsFieldMove                       ; src/engine/menus/field_moves.asm — AL=move id → CF/EAX=name ptr
%ifdef DEBUG_PARTYMENU
extern DumpBackbuffer
%endif

; --- layout (GB 20-wide logical wTileMap coords) ---
; Faithful to pret: cursor(0), 2x2 icon(1-2), name(3), level(13), status(17),
; and on the HP row the gauge(4-12) + cur/max fraction(13-19).
PM_CURSOR_COL  equ 0         ; ▶ cursor
PM_ICON_COL    equ 1         ; 2x2 mon icon (cols 1-2, spanning both rows)
PM_NAME_COL    equ 3         ; nickname (≤10 chars → cols 3-12)
PM_LV_COL      equ 13        ; ":L" combined tile
PM_LEVEL_COL   equ 14        ; level digits (3-wide, leading spaces → 14-16)
PM_STATUS_COL  equ 17        ; status text (3 chars) / blank → 17-19
PM_HP_BAR_COL  equ 4         ; HP row: "HP:" gauge (9 tiles → cols 4-12)
PM_HP_FRAC_COL equ 13        ; cur(13-15) "/"(16) max(17-19)
PM_FIRST_ROW   equ 0         ; first name row (no border)

; Mon-icon VRAM tiles: slot i uses 4 consecutive tiles (TL,TR,BL,BR) starting at
; ICON_TILE_BASE + i*4, living in the vTileset region ($9000+) that the overworld
; reloads on exit. Animation swaps the VRAM contents of the selected slot's tiles
; (the window decoder reads VRAM directly, so the tilemap IDs stay fixed).
PM_ICON_TILE_BASE equ 0x01

; window: full 20-tile (160px) box centered in the 320px viewport (WX-7=80).
PM_WIN_WX      equ 87
PM_WIN_CLIP_W  equ 160

; HP-bar gauge tiles (HpBarAndStatus set, loaded over $62+).
HPB_HP         equ 0x71      ; narrow "HP" label
HPB_LEFT       equ 0x62      ; ":" + gauge left edge
HPB_EMPTY      equ 0x63      ; empty gauge segment; $63+n = n-pixel partial fill
HPB_FULL       equ 0x6b      ; full (8px) gauge segment
HPB_END        equ 0x6c      ; gauge right cap (pokemon menu variant)
TILE_LV        equ 0x6e      ; ":L" level prefix

CHAR_CURSOR    equ 0xED      ; ▶ (filled — navigation cursor)
CHAR_SWAP_CUR  equ 0xEC      ; ▷ (hollow — parent cursor while a submenu has focus / swap armed)
CHAR_SLASH     equ 0xF3      ; /
CHAR_DIGIT0    equ 0xF6      ; '0'; digit d → +d
CHAR_TERM      equ 0x50      ; '@' string terminator
TILE_SPC       equ 0x7F

; --- field-move pop-up (pret FIELD_MOVE_MON_MENU / DisplayFieldMoveMonMenu) -----
; A on a mon opens this; entries are the mon's field moves (slot order) + STATS,
; SWITCH, CANCEL. Rendered as a SECOND window over the party panel via add_window
; (the multi-layer menu compositor). ▷ marks the party cursor while it's open.
; Field-move names + ids come from the shared FieldMoveDisplayData/FieldMoveNames
; tables via IsFieldMove (src/engine/menus/field_moves.asm), not baked here.

POPUP_INT_W    equ 11        ; interior width: cursor(1) + name(≤10, "SOFTBOILED")
POPUP_BOX_W    equ 13        ; total tile width (INT_W + 2 borders)
POPUP_CUR_COL  equ 1         ; box-rel ▶ column
POPUP_TXT_COL  equ 2         ; box-rel text column
POPUP_SROW     equ 18        ; GB_TILEMAP1 source row for the pop-up box (panel uses 0-11)
POPUP_WX       equ 223       ; flush-right: left px = 320-104=216 → wx = 216+7
POPUP_CLIP_W   equ 104       ; POPUP_BOX_W * 8 px

; bottom message box (pret PartyMenu message; the standard 20×6 dialog at the
; viewport bottom, like the overworld/bag dialog). Source GB_TILEMAP1 rows 12-17
; (free: the panel uses 0-11), shown as a persistent window beneath the panel.
MSG_SROW       equ 12        ; W_TILEMAP / GB_TILEMAP1 box top row
MSG_WX         equ 87        ; center the 160px box (WX-7 = 80)
MSG_WY         equ 152       ; bottom 48px (6 rows)
MSG_LINE1_ROW  equ 14        ; text rows (col 1, inside the border)
MSG_LINE2_ROW  equ 16

; status-condition bits within MON_STATUS (constants/battle_constants.asm).
ST_PSN_BIT     equ 3
ST_BRN_BIT     equ 4
ST_FRZ_BIT     equ 5
ST_PAR_BIT     equ 6
ST_SLP_MASK    equ 0x07

section .data
align 4
; Mon-icon tile data + internal-index → ICON_* map (tools/gen_mon_icons_inc.py).
; NOTE (flipping): the right half of each icon is baked here as a HORIZONTAL
; MIRROR of the left half, because the window/BG layer this menu renders through
; has no per-tile X-flip (only OBJ sprites do). This assumes every party icon has
; a vertical line of symmetry — true for all non-helix icons in pret. If a future
; icon needs a genuine left/right-distinct or runtime-flipped layout (e.g. the
; helix/fossil sprite, or an OAM-based rewrite), revisit this and the generator.
%include "assets/mon_icons.inc"

; 3-tile status strings (font letters: tile = $80 + (letter-'A')).
st_fnt:   db 0x85, 0x8D, 0x93        ; FNT
st_psn:   db 0x8F, 0x92, 0x8D        ; PSN
st_brn:   db 0x81, 0x91, 0x8D        ; BRN
st_frz:   db 0x85, 0x91, 0x99        ; FRZ
st_par:   db 0x8F, 0x80, 0x91        ; PAR
st_slp:   db 0x92, 0x8B, 0x8F        ; SLP
st_blank: db TILE_SPC, TILE_SPC, TILE_SPC

; pop-up entry labels (GB charmap: 'A'=$80 … 'Z'=$99, '@'=$50). Field-move names
; now come from the shared FieldMoveNames table (via IsFieldMove); only the fixed
; STATS/SWITCH/CANCEL tail (pret PokemonMenuEntries) is baked here.
pm_str_stats:      db 0x92,0x93,0x80,0x93,0x92, CHAR_TERM                        ; STATS
pm_str_switch:     db 0x92,0x96,0x88,0x93,0x82,0x87, CHAR_TERM                   ; SWITCH
pm_str_cancel:     db 0x82,0x80,0x8D,0x82,0x84,0x8B, CHAR_TERM                   ; CANCEL

; bottom message box text (pret PartyMenuMessagePointers). 'a'=$A0…'z'=$B9, é=$BA,
; '.'=$E8, '?'=$E6; "POKéMON" = P O K é M O N. Only the two states the port reaches
; today (normal / swap); item-use, battle, and TM messages come with those systems.
pm_msg_choose: db 0x82,0xA7,0xAE,0xAE,0xB2,0xA4,0x7F,0xA0,0x7F,0x8F,0x8E,0x8A,0xBA,0x8C,0x8E,0x8D,0xE8, CHAR_TERM ; "Choose a POKéMON."
pm_msg_move1:  db 0x8C,0xAE,0xB5,0xA4,0x7F,0x8F,0x8E,0x8A,0xBA,0x8C,0x8E,0x8D, CHAR_TERM                          ; "Move POKéMON"
pm_msg_move2:  db 0xB6,0xA7,0xA4,0xB1,0xA4,0xE6, CHAR_TERM                                                        ; "where?"

section .bss
align 4
pm_count:      resd 1        ; party size (1..6)
pm_selected:   resd 1        ; selected entry index (0..count-1)
pm_slot:       resd 1        ; render-loop slot counter (survives PlaceString/div)
pm_pixels:     resd 1        ; current entry's HP-bar fill in pixels (0..48)
pm_anim_ctr:   resd 1        ; vblank counter for the selected mon's icon bob
pm_anim_frame: resd 1        ; 0/1 — current animation frame of the selected icon
pm_anim_period: resd 1       ; vblanks per frame (6 green / 17 yellow / 33 red)
pm_swap:       resd 1        ; SWITCH arm: 0 = none, else (held mon index + 1)
pm_menu_entries: resd 8      ; pop-up: flat ptrs to entry label strings (≤4 fields + 3)
pm_menu_count: resd 1        ; pop-up entry count
pm_menu_sel:   resd 1        ; pop-up cursor index

section .text

; ---------------------------------------------------------------------------
; DisplayPartyMenu — show the party list, run it until B, then return.
; In:  EBP = GB memory base; font already resident. All registers preserved.
; ---------------------------------------------------------------------------
DisplayPartyMenu:
    pushad

    movzx eax, byte [ebp + wPartyCount]
    test eax, eax
    jz .exit_now                ; empty party → nothing to show
    mov [pm_count], eax
    mov dword [pm_selected], 0
    mov dword [pm_swap], 0       ; no SWITCH armed on open

    ; Bring in the HP-bar/status/":L" tiles. font_battle_extra also carries the
    ; box-drawing tiles ($79-$7E, byte-identical to font_extra), so TextBoxBorder
    ; still works here — used by the bottom message box and the field-move pop-up.
    call LoadHpBarAndStatusTilePatterns

    ; Whiteout the overworld behind the menu so the GB pokemon menu sits centered
    ; on a clean white field instead of over Pallet Town.
    mov dword [g_bg_whiteout], 1

    ; window placement: 160px (20-tile) box centered horizontally; the list block
    ; (count*2 rows) is TOP-aligned (wy=0), faithful to the original (hlcoord 3,0):
    ; the list fills from the top, so any unused slots / blank space fall at the
    ; bottom (above the message box) rather than floating in the middle.
    ; PROJ overworld-ui: GB(0,0) 20xN --(party, X centered, Y top)--> wx=87 clip=160 wy=0 max_y=rows*8
    mov ecx, [pm_count]
    shl ecx, 4                  ; pixel_h = count*2 rows * 8 px
    xor ebx, ebx                ; wy = 0 (top-aligned)
    mov edx, ecx                ; max_y = pixel_h (exclusive bottom)
    mov eax, PM_WIN_WX          ; wx = 87
    mov ecx, PM_WIN_CLIP_W      ; clip_w = 160
    mov esi, GB_TILEMAP1        ; party panel source tilemap
    xor edi, edi                ; start_row = 0
    call set_single_window      ; count=1; window 0 = panel; mirrors wy→H_WY, wx→IO_WX

    ; window 1 = the persistent bottom message box (stays for the menu's lifetime;
    ; content is (re)drawn by .draw_message, which .render calls). PROJ overworld-ui:
    ; GB(0,17) 20×6 --(center, WX-7=80)--> wx=87 wy=152.
    mov eax, MSG_WX
    mov ebx, MSG_WY
    mov ecx, SCREEN_W           ; clip_w = 160
    mov edx, RENDER_H           ; max_y = 200
    mov esi, GB_TILEMAP1
    mov edi, MSG_SROW           ; start_row = 12
    call add_window             ; count = 2

    call .render
    call .refresh_icons             ; load icon gfx into VRAM + reset the bob timer

%ifdef DEBUG_PARTYMENU
    call DelayFrame
    call DumpBackbuffer         ; dump FRAME.BIN + exit (never returns)
%endif

.wait_open:
    call DelayFrame
    test byte [ebp + H_JOY_HELD], PAD_A
    jnz .wait_open

.loop:
    call DelayFrame
    ; advance the selected mon's icon bob (only the cursor mon animates, at a
    ; period set by its HP fraction — pret AnimatePartyMon / GetHealthBarColor).
    mov eax, [pm_anim_ctr]
    inc eax
    cmp eax, [pm_anim_period]
    jb .anim_store
    mov edx, [pm_anim_frame]
    xor edx, 1                      ; toggle frame
    mov [pm_anim_frame], edx
    mov eax, [pm_selected]
    call .load_icon_slot            ; reload selected slot's VRAM with the new frame
    xor eax, eax                    ; counter back to 0
.anim_store:
    mov [pm_anim_ctr], eax

    movzx eax, byte [ebp + H_JOY_PRESSED]
    test al, PAD_DOWN
    jnz .down
    test al, PAD_UP
    jnz .up
    test al, PAD_A
    jnz .a_press
    test al, PAD_B
    jnz .b_press
    jmp .loop

.a_press:
    ; In SWITCH-arm mode, A completes the reorder; otherwise A opens the pop-up.
    mov eax, [pm_swap]
    test eax, eax
    jnz .complete_swap
    call .open_popup
    jmp .loop

.b_press:
    ; B cancels an armed SWITCH; otherwise it leaves the party menu.
    mov eax, [pm_swap]
    test eax, eax
    jz .exit
    mov dword [pm_swap], 0
    call .render
    call .refresh_icons
    jmp .loop

.down:
    mov eax, [pm_selected]
    inc eax
    cmp eax, [pm_count]
    jae .loop
    mov [pm_selected], eax
    call .render
    call .refresh_icons
    jmp .loop
.up:
    mov eax, [pm_selected]
    test eax, eax
    jz .loop
    dec eax
    mov [pm_selected], eax
    call .render
    call .refresh_icons
    jmp .loop

; ===========================================================================
; Field-move pop-up (pret FIELD_MOVE_MON_MENU). Opened by A on a mon; appended
; as a SECOND window over the party panel (multi-layer compositor). The party
; cursor goes hollow ▷ while it's up. Returns here; SWITCH arms the reorder.
; ===========================================================================
.open_popup:
    call .build_popup                   ; → pm_menu_entries[], pm_menu_count
    mov dword [pm_menu_sel], 0
    ; hollow the party panel cursor at the selected mon (visible beside the pop-up)
    mov eax, [pm_selected]
    shl eax, 1                          ; row = sel*2 (PM_FIRST_ROW = 0)
    shl eax, 5                          ; * 32 (GB_TILEMAP1 stride)
    mov byte [ebp + eax + GB_TILEMAP1 + PM_CURSOR_COL], CHAR_SWAP_CUR
    call .run_popup                     ; EAX = chosen index, or -1 on B
    mov dword [g_window_count], 2        ; drop the pop-up window (keep panel + message)
    cmp eax, -1
    je .popup_close                     ; B → just close
    mov ecx, [pm_menu_count]
    dec ecx
    cmp eax, ecx
    je .popup_close                     ; CANCEL (last)
    dec ecx
    cmp eax, ecx
    je .popup_switch                    ; SWITCH (second-to-last)
    ; STATS / field move → deferred no-op (StatusScreen + field effects not ported)
    jmp .popup_close
.popup_switch:
    mov eax, [pm_count]
    cmp eax, 2
    jb .popup_close                     ; need ≥2 mons to reorder
    mov eax, [pm_selected]
    inc eax
    mov [pm_swap], eax                   ; arm: held = selected + 1 (kept hollow by .render)
.popup_close:
    call .render                        ; restore ▶ (or ▷ if a SWITCH is now armed)
    call .refresh_icons
    ret

; complete an armed SWITCH: swap the held mon with the currently selected one.
.complete_swap:
    mov eax, [pm_swap]
    dec eax                             ; held index
    mov dword [pm_swap], 0
    mov ebx, [pm_selected]              ; target index
    cmp eax, ebx
    je .cs_done                         ; same mon → just deselect
    ; wPartySpecies (1 byte)
    lea esi, [eax + wPartySpecies]
    lea edi, [ebx + wPartySpecies]
    mov cl, [ebp + esi]
    mov dl, [ebp + edi]
    mov [ebp + esi], dl
    mov [ebp + edi], cl
    ; wPartyMons struct (44 bytes)
    imul esi, eax, PARTYMON_STRUCT_LENGTH
    add esi, wPartyMons
    imul edi, ebx, PARTYMON_STRUCT_LENGTH
    add edi, wPartyMons
    mov ecx, PARTYMON_STRUCT_LENGTH
    call .swap_bytes
    ; OT name + nickname (NAME_LENGTH each)
    imul esi, eax, NAME_LENGTH
    add esi, wPartyMonOT
    imul edi, ebx, NAME_LENGTH
    add edi, wPartyMonOT
    mov ecx, NAME_LENGTH
    call .swap_bytes
    imul esi, eax, NAME_LENGTH
    add esi, wPartyMonNicks
    imul edi, ebx, NAME_LENGTH
    add edi, wPartyMonNicks
    mov ecx, NAME_LENGTH
    call .swap_bytes
.cs_done:
    call .render
    call .refresh_icons
    jmp .loop

; swap ECX bytes between [ebp+ESI] and [ebp+EDI]. Clobbers EDX,ESI,EDI,ECX; preserves EAX/EBX.
.swap_bytes:
    mov dl, [ebp + esi]
    mov dh, [ebp + edi]
    mov [ebp + esi], dh
    mov [ebp + edi], dl
    inc esi
    inc edi
    dec ecx
    jnz .swap_bytes
    ret

; build pm_menu_entries[] / pm_menu_count for the selected mon: its field moves
; (slot order) then STATS, SWITCH, CANCEL.
.build_popup:
    xor ecx, ecx                        ; entry count
    ; ESI = mon moves base = wPartyMons + sel*44 + MON_MOVES
    mov eax, [pm_selected]
    imul eax, eax, PARTYMON_STRUCT_LENGTH
    lea esi, [eax + wPartyMons + MON_MOVES]
    mov edx, NUM_MOVES                  ; 4 slots
.bp_loop:
    mov al, [ebp + esi]
    inc esi
    call IsFieldMove                    ; AL=id → CF + EAX = FieldMoveNames ptr (or 0)
    jnc .bp_next
    mov [pm_menu_entries + ecx*4], eax
    inc ecx
.bp_next:
    dec edx
    jnz .bp_loop
    ; fixed tail: STATS, SWITCH, CANCEL
    mov dword [pm_menu_entries + ecx*4], pm_str_stats
    inc ecx
    mov dword [pm_menu_entries + ecx*4], pm_str_switch
    inc ecx
    mov dword [pm_menu_entries + ecx*4], pm_str_cancel
    inc ecx
    mov [pm_menu_count], ecx
    ret

; render the pop-up box (border + entries + cursor) into the wTileMap scratch,
; copy it into a free GB_TILEMAP1 region, and (re)append its window descriptor.
.draw_popup:
    mov esi, W_TILEMAP                   ; box top-left = scratch col 0
    mov bl, POPUP_INT_W
    mov eax, [pm_menu_count]
    mov bh, al                          ; interior height = entry count
    call TextBoxBorder
    xor ecx, ecx
.dpu_row:
    cmp ecx, [pm_menu_count]
    jae .dpu_cursor
    push ecx
    mov eax, ecx
    inc eax                             ; interior row (after top border)
    imul eax, eax, 20
    lea esi, [eax + W_TILEMAP + POPUP_TXT_COL]
    mov eax, [pm_menu_entries + ecx*4]
    call place_flat_str
    pop ecx
    inc ecx
    jmp .dpu_row
.dpu_cursor:
    mov eax, [pm_menu_sel]
    inc eax
    imul eax, eax, 20
    mov byte [ebp + eax + W_TILEMAP + POPUP_CUR_COL], CHAR_CURSOR
    ; copy box rows (count+2) × POPUP_BOX_W → GB_TILEMAP1 rows POPUP_SROW.. (stride 32)
    xor ecx, ecx
.dpu_copy:
    push ecx
    mov eax, ecx
    imul eax, eax, 20
    lea esi, [ebp + eax + W_TILEMAP]
    mov eax, ecx
    add eax, POPUP_SROW
    shl eax, 5
    lea edi, [ebp + eax + GB_TILEMAP1]
    mov ecx, POPUP_BOX_W
    rep movsb
    pop ecx
    inc ecx
    mov eax, [pm_menu_count]
    add eax, 2
    cmp ecx, eax
    jb .dpu_copy
    ; (re)append the pop-up as window 2 (panel = 0, message box = 1 both stay)
    mov dword [g_window_count], 2
    mov ebx, [pm_menu_count]
    add ebx, 2
    shl ebx, 3                          ; box height in px
    mov ecx, RENDER_H
    sub ecx, ebx                        ; wy = bottom-aligned top
    mov ebx, ecx                        ; EBX = wy
    mov eax, POPUP_WX
    mov ecx, POPUP_CLIP_W
    mov edx, RENDER_H                   ; max_y = viewport bottom
    mov esi, GB_TILEMAP1
    mov edi, POPUP_SROW
    call add_window
    ret

; pop-up input loop. Returns EAX = chosen entry index, or -1 if B pressed.
.run_popup:
    call .draw_popup
.rpu_loop:
    call DelayFrame
    movzx eax, byte [ebp + H_JOY_PRESSED]
    test al, PAD_DOWN
    jnz .rpu_down
    test al, PAD_UP
    jnz .rpu_up
    test al, PAD_A
    jnz .rpu_a
    test al, PAD_B
    jnz .rpu_b
    jmp .rpu_loop
.rpu_down:
    mov eax, [pm_menu_sel]
    inc eax
    cmp eax, [pm_menu_count]
    jae .rpu_loop                       ; at bottom (field menu does not wrap)
    mov [pm_menu_sel], eax
    call .draw_popup
    jmp .rpu_loop
.rpu_up:
    mov eax, [pm_menu_sel]
    test eax, eax
    jz .rpu_loop
    dec eax
    mov [pm_menu_sel], eax
    call .draw_popup
    jmp .rpu_loop
.rpu_a:
    mov eax, [pm_menu_sel]
    ret
.rpu_b:
    mov eax, -1
    ret

.exit:
.exit_release:
    call DelayFrame
    test byte [ebp + H_JOY_HELD], PAD_A | PAD_B
    jnz .exit_release
    mov dword [g_bg_whiteout], 0         ; restore the overworld behind the START menu
    ; restore the VRAM tiles the menu borrowed: tileset ($00-$5F, icons) and the
    ; box-drawing tiles ($60-$7F) so the START menu border redraws correctly.
    call LoadTilesetTilePatternData
    call LoadTextBoxTilePatterns
.exit_now:
    popad
    ret

; --- redraw the whole panel + all party entries + cursor, then copy ----------
.render:
    ; clear the panel (count*2 rows × 20 cols) to blank space.
    mov eax, [pm_count]
    shl eax, 1
    imul ecx, eax, 20           ; total tiles to clear
    lea edi, [ebp + W_TILEMAP]
    mov al, TILE_SPC
    rep stosb

    mov dword [pm_slot], 0
.entry_loop:
    ; struct base = wPartyMons + slot*44 ; name row = FIRST_ROW + slot*2
    mov eax, [pm_slot]
    imul eax, eax, PARTYMON_STRUCT_LENGTH
    lea ebx, [eax + wPartyMons]         ; EBX = mon struct GB offset (kept across calls)

    ; name-row tile offset → EDI
    mov eax, [pm_slot]
    shl eax, 1
    add eax, PM_FIRST_ROW
    imul edi, eax, 20                   ; EDI = name row base (col 0)

    ; nickname (PlaceString: ESI=dest, EDX=src; clobbers EAX/EBX/EDX — save EBX/EDI)
    push ebx
    push edi
    lea esi, [edi + W_TILEMAP + PM_NAME_COL]
    mov eax, [pm_slot]
    imul eax, eax, NAME_LENGTH
    lea edx, [eax + wPartyMonNicks]
    call PlaceString
    pop edi
    pop ebx

    ; ":L" tile + level (3-digit, leading spaces)
    mov byte [ebp + edi + W_TILEMAP + PM_LV_COL], TILE_LV
    movzx eax, byte [ebp + ebx + MON_LEVEL]
    push edi
    push ebx
    lea edi, [edi + W_TILEMAP + PM_LEVEL_COL]
    call .print_num3
    pop ebx
    pop edi

    ; status condition (FNT / PSN / ... / blank) at the right of the name row
    push edi
    push ebx
    lea edi, [edi + W_TILEMAP + PM_STATUS_COL]
    call .print_status
    pop ebx
    pop edi

    ; --- HP-bar fill: pixels = curHP * 48 / maxHP (≥1 if alive, 0 if fainted) --
    movzx eax, byte [ebp + ebx + MON_HP]        ; curHP big-endian
    shl eax, 8
    mov al, [ebp + ebx + MON_HP + 1]
    mov ecx, eax                                ; ECX = curHP
    movzx eax, byte [ebp + ebx + MON_MAXHP]     ; maxHP big-endian
    shl eax, 8
    mov al, [ebp + ebx + MON_MAXHP + 1]
    mov esi, eax                                ; ESI = maxHP (divisor)
    test ecx, ecx
    jz .px_zero
    mov eax, ecx
    imul eax, eax, 48
    xor edx, edx
    div esi                                     ; EAX = curHP*48 / maxHP
    test eax, eax
    jnz .px_ok
    mov eax, 1                                  ; alive → at least a sliver
.px_ok:
    mov [pm_pixels], eax
    jmp .px_done
.px_zero:
    mov dword [pm_pixels], 0
.px_done:

    ; --- draw the HP-bar gauge on the HP row (name row + 1) -------------------
    mov eax, [pm_slot]
    shl eax, 1
    add eax, PM_FIRST_ROW
    inc eax                                      ; HP row
    imul edi, eax, 20                            ; EDI = HP row base (col 0)
    push edi                                     ; keep HP row base for the fraction

    lea esi, [ebp + edi + W_TILEMAP + PM_HP_BAR_COL]
    mov byte [esi], HPB_HP                        ; "HP"
    mov byte [esi + 1], HPB_LEFT                  ; ":" + gauge left
    mov byte [esi + 8], HPB_END                   ; gauge right cap
    mov edx, [pm_pixels]                          ; remaining pixels
    lea edi, [esi + 2]                            ; first of 6 gauge segments
    mov ecx, 6
.seg_loop:
    cmp edx, 8
    jb .seg_partial
    mov byte [edi], HPB_FULL
    sub edx, 8
    jmp .seg_next
.seg_partial:
    lea eax, [edx + HPB_EMPTY]                    ; $63 + n-pixel partial (n=0 → empty)
    mov [edi], al
    xor edx, edx                                 ; rest of the gauge stays empty
.seg_next:
    inc edi
    dec ecx
    jnz .seg_loop

    ; --- HP fraction "cur/ max" to the right of the gauge --------------------
    pop edi                                       ; EDI = HP row base
    movzx eax, byte [ebp + ebx + MON_HP]          ; curHP big-endian
    shl eax, 8
    mov al, [ebp + ebx + MON_HP + 1]
    push edi
    push ebx
    lea edi, [edi + W_TILEMAP + PM_HP_FRAC_COL]
    call .print_num3
    pop ebx
    pop edi
    mov byte [ebp + edi + W_TILEMAP + PM_HP_FRAC_COL + 3], CHAR_SLASH
    movzx eax, byte [ebp + ebx + MON_MAXHP]       ; maxHP big-endian
    shl eax, 8
    mov al, [ebp + ebx + MON_MAXHP + 1]
    push edi
    lea edi, [edi + W_TILEMAP + PM_HP_FRAC_COL + 4]
    call .print_num3
    pop edi

    ; --- place the 2x2 mon-icon tile IDs (cols 1-2 of name + HP rows) ----------
    ; EDI = HP row base; name row base = EDI - 20. VRAM content is loaded later.
    mov eax, [pm_slot]
    shl eax, 2                                          ; slot*4
    add eax, PM_ICON_TILE_BASE                          ; AL = TL tile id
    mov byte [ebp + edi - 20 + W_TILEMAP + PM_ICON_COL], al       ; TL
    inc eax
    mov byte [ebp + edi - 20 + W_TILEMAP + PM_ICON_COL + 1], al   ; TR
    inc eax
    mov byte [ebp + edi + W_TILEMAP + PM_ICON_COL], al            ; BL
    inc eax
    mov byte [ebp + edi + W_TILEMAP + PM_ICON_COL + 1], al        ; BR

    inc dword [pm_slot]
    mov eax, [pm_slot]
    cmp eax, [pm_count]
    jb .entry_loop

    ; cursor ▶ at the selected mon's name row
    mov eax, [pm_selected]
    shl eax, 1
    add eax, PM_FIRST_ROW
    imul eax, eax, 20
    mov byte [ebp + eax + W_TILEMAP + PM_CURSOR_COL], CHAR_CURSOR

    ; hollow ▷ on the SWITCH-armed mon (parent cursor while reorder is pending)
    mov eax, [pm_swap]
    test eax, eax
    jz .no_swap_cur
    dec eax
    shl eax, 1
    add eax, PM_FIRST_ROW
    imul eax, eax, 20
    mov byte [ebp + eax + W_TILEMAP + PM_CURSOR_COL], CHAR_SWAP_CUR
.no_swap_cur:

    ; copy the panel (cols 0-19) → GB_TILEMAP1 (cols 0-19)
    mov eax, [pm_count]
    shl eax, 1                          ; total rows
    mov [pm_slot], eax                  ; reuse pm_slot as row limit
    xor ecx, ecx
.copy_row:
    imul esi, ecx, 20
    lea esi, [ebp + esi + W_TILEMAP]
    mov edi, ecx
    shl edi, 5
    lea edi, [ebp + edi + GB_TILEMAP1]
    push ecx
    mov ecx, 20
    rep movsb
    pop ecx
    inc ecx
    cmp ecx, [pm_slot]
    jb .copy_row
    ; refresh the bottom message box content (its window was added once in init)
    call .draw_message
    ret

; --- bottom message box: contextual text per state (pret PartyMenuMessage*) ------
; Renders the 20×6 dialog border + text into wTileMap rows 12-17, then copies to
; GB_TILEMAP1 rows 12-17. Normal: "Choose a POKéMON."; SWITCH armed: "Move
; POKéMON / where?". Window descriptor (window 1) is added once by DisplayPartyMenu.
.draw_message:
    mov esi, W_TILEMAP + MSG_SROW * 20
    mov bl, 18                          ; interior width (total 20)
    mov bh, 4                           ; interior height (total 6)
    call TextBoxBorder
    mov eax, [pm_swap]
    test eax, eax
    jnz .msg_swap
    ; normal
    mov esi, W_TILEMAP + MSG_LINE1_ROW * 20 + 1
    mov eax, pm_msg_choose
    call place_flat_str
    jmp .msg_copy
.msg_swap:
    mov esi, W_TILEMAP + MSG_LINE1_ROW * 20 + 1
    mov eax, pm_msg_move1
    call place_flat_str
    mov esi, W_TILEMAP + MSG_LINE2_ROW * 20 + 1
    mov eax, pm_msg_move2
    call place_flat_str
.msg_copy:
    ; copy box rows MSG_SROW..MSG_SROW+5 (cols 0-19) → GB_TILEMAP1 (stride 32)
    xor ecx, ecx
.dm_row:
    mov eax, ecx
    add eax, MSG_SROW
    imul esi, eax, 20
    lea esi, [ebp + esi + W_TILEMAP]
    mov edi, eax
    shl edi, 5
    lea edi, [ebp + edi + GB_TILEMAP1]
    push ecx
    mov ecx, 20
    rep movsb
    pop ecx
    inc ecx
    cmp ecx, 6
    jb .dm_row
    ret

; --- (re)load every slot's icon to frame A, reset the bob timer, set its speed --
.refresh_icons:
    call .load_all_icons
    mov dword [pm_anim_ctr], 0
    mov dword [pm_anim_frame], 0
    jmp .calc_period            ; tail — sets pm_anim_period and returns

; --- load all party slots' icon gfx (frame 0) into their VRAM tiles ------------
.load_all_icons:
    xor ebx, ebx                ; slot
.lai_loop:
    mov eax, ebx
    xor edx, edx                ; frame 0
    push ebx
    call .load_icon_slot
    pop ebx
    inc ebx
    cmp ebx, [pm_count]
    jb .lai_loop
    ret

; --- load one slot's icon frame into VRAM ------------------------------------
; In: EAX = slot (0..5), EDX = frame (0/1). Clobbers EAX/ECX/EDX/ESI/EDI (EBX kept).
.load_icon_slot:
    push eax                                  ; save slot
    imul ecx, eax, PARTYMON_STRUCT_LENGTH
    movzx ecx, byte [ebp + ecx + wPartyMons + MON_SPECIES]   ; internal index (1-based)
    dec ecx
    movzx ecx, byte [mon_icon_by_index + ecx] ; ICON_* id (0..10)
    imul ecx, ecx, MON_ICON_BYTES             ; → icon base in mon_icon_data
    mov eax, edx
    imul eax, eax, MON_ICON_FRAME_BYTES        ; + frame offset
    add ecx, eax
    lea esi, [mon_icon_data + ecx]            ; src = chosen frame's 4 tiles
    pop eax                                   ; slot
    shl eax, 2
    add eax, PM_ICON_TILE_BASE                 ; first tile id of this slot
    shl eax, 4                                ; * TILE_SIZE → byte offset
    lea edi, [ebp + GB_VCHARS2 + eax]         ; dest = vTileset slot
    mov ecx, MON_ICON_FRAME_BYTES / 4
    rep movsd
    ret

; --- set pm_anim_period from the selected mon's HP fraction -------------------
; green (≥27px) → 6, yellow (≥10px) → 17, red (<10px / fainted) → 33 vblanks/frame.
.calc_period:
    mov eax, [pm_selected]
    imul eax, eax, PARTYMON_STRUCT_LENGTH
    lea ebx, [eax + wPartyMons]
    movzx eax, byte [ebp + ebx + MON_HP]      ; curHP big-endian
    shl eax, 8
    mov al, [ebp + ebx + MON_HP + 1]
    mov ecx, eax                              ; curHP
    movzx eax, byte [ebp + ebx + MON_MAXHP]   ; maxHP big-endian
    shl eax, 8
    mov al, [ebp + ebx + MON_MAXHP + 1]
    mov esi, eax                              ; maxHP
    test ecx, ecx
    jz .cp_red
    test esi, esi
    jz .cp_red
    mov eax, ecx
    imul eax, eax, 48
    xor edx, edx
    div esi                                   ; EAX = HP-bar pixels (0..48)
    cmp eax, 27
    jae .cp_green
    cmp eax, 10
    jae .cp_yellow
.cp_red:
    mov dword [pm_anim_period], 33
    ret
.cp_yellow:
    mov dword [pm_anim_period], 17
    ret
.cp_green:
    mov dword [pm_anim_period], 6
    ret

; --- print EAX (0..999) as 3 tiles at [ebp+EDI], leading zeros as spaces -------
; Clobbers EAX/EBX/ECX/EDX. EDI preserved.
.print_num3:
    movzx eax, ax
    xor edx, edx
    mov ecx, 100
    div ecx                     ; EAX=hundreds, EDX=remainder
    mov bl, al
    mov eax, edx
    xor edx, edx
    mov ecx, 10
    div ecx                     ; EAX=tens, EDX=ones
    mov bh, al
    mov cl, dl
    test bl, bl
    jnz .h_show
    mov byte [ebp + edi], TILE_SPC      ; blank hundreds
    test bh, bh
    jnz .t_show
    mov byte [ebp + edi + 1], TILE_SPC  ; blank tens too
    jmp .ones
.h_show:
    add bl, CHAR_DIGIT0
    mov [ebp + edi], bl
.t_show:
    add bh, CHAR_DIGIT0
    mov [ebp + edi + 1], bh
.ones:
    add cl, CHAR_DIGIT0
    mov [ebp + edi + 2], cl
    ret

; --- place 3-tile status text at [ebp+EDI] from the mon at EBX ------------------
; "FNT" if fainted, else PSN/BRN/FRZ/PAR/SLP by priority, else 3 blanks.
; Clobbers EAX/ESI. EBX/EDI preserved.
.print_status:
    movzx eax, byte [ebp + ebx + MON_HP]
    or al, [ebp + ebx + MON_HP + 1]
    jz .st_fnt                          ; HP == 0 → fainted
    mov al, [ebp + ebx + MON_STATUS]
    test al, 1 << ST_PSN_BIT
    jnz .st_psn
    test al, 1 << ST_BRN_BIT
    jnz .st_brn
    test al, 1 << ST_FRZ_BIT
    jnz .st_frz
    test al, 1 << ST_PAR_BIT
    jnz .st_par
    test al, ST_SLP_MASK
    jnz .st_slp
    mov esi, st_blank
    jmp .st_put
.st_fnt:
    mov esi, st_fnt
    jmp .st_put
.st_psn:
    mov esi, st_psn
    jmp .st_put
.st_brn:
    mov esi, st_brn
    jmp .st_put
.st_frz:
    mov esi, st_frz
    jmp .st_put
.st_par:
    mov esi, st_par
    jmp .st_put
.st_slp:
    mov esi, st_slp
.st_put:
    mov al, [esi]
    mov [ebp + edi], al
    mov al, [esi + 1]
    mov [ebp + edi + 1], al
    mov al, [esi + 2]
    mov [ebp + edi + 2], al
    ret
