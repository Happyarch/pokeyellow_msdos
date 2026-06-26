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
extern DelayFrame
extern set_single_window                 ; src/ppu/ppu.asm — define g_windows[] as one descriptor
extern g_bg_whiteout                     ; src/ppu/ppu.asm — full-screen white field
extern LoadHpBarAndStatusTilePatterns   ; src/gfx/load_font.asm
extern LoadTextBoxTilePatterns          ; restore box tiles for the START menu
extern LoadTilesetTilePatternData       ; restore overworld tileset ($9000) on exit
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

CHAR_CURSOR    equ 0xED      ; ▶
CHAR_SLASH     equ 0xF3      ; /
CHAR_DIGIT0    equ 0xF6      ; '0'; digit d → +d
TILE_SPC       equ 0x7F

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

section .bss
align 4
pm_count:      resd 1        ; party size (1..6)
pm_selected:   resd 1        ; selected entry index (0..count-1)
pm_slot:       resd 1        ; render-loop slot counter (survives PlaceString/div)
pm_pixels:     resd 1        ; current entry's HP-bar fill in pixels (0..48)
pm_anim_ctr:   resd 1        ; vblank counter for the selected mon's icon bob
pm_anim_frame: resd 1        ; 0/1 — current animation frame of the selected icon
pm_anim_period: resd 1       ; vblanks per frame (6 green / 17 yellow / 33 red)

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

    ; Bring in the HP-bar/status/":L" tiles (clobbers box-drawing tiles $79-$7E).
    call LoadHpBarAndStatusTilePatterns

    ; Whiteout the overworld behind the menu so the GB pokemon menu sits centered
    ; on a clean white field instead of over Pallet Town.
    mov dword [g_bg_whiteout], 1

    ; window placement: 160px (20-tile) box centered horizontally; the list block
    ; (count*2 rows) centered vertically: wy = (RENDER_H - rows*8) / 2.
    ; PROJ overworld-ui: GB(0,?) 20xN --(party, X centered, Y centered)--> wx=87 clip=160 wy/max_y computed
    mov ecx, [pm_count]
    shl ecx, 4                  ; pixel_h = count*2 rows * 8 px
    mov ebx, RENDER_H
    sub ebx, ecx                ; RENDER_H - pixel_h
    shr ebx, 1                  ; wy = centered top
    lea edx, [ebx + ecx]        ; max_y = wy + pixel_h (exclusive bottom)
    mov eax, PM_WIN_WX          ; wx = 87
    mov ecx, PM_WIN_CLIP_W      ; clip_w = 160
    mov esi, GB_TILEMAP1        ; party panel source tilemap
    xor edi, edi                ; start_row = 0
    call set_single_window      ; count=1; mirrors wy→H_WY, wx→IO_WX

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
    test al, PAD_B
    jnz .exit
    ; A is a no-op for now (party action sub-menu deferred).
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
