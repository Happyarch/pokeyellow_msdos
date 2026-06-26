; party_menu.asm — overworld party (POKéMON) screen.
;
; Lists the player's party — nickname, level, and current/max HP — opened from the
; START menu's POKéMON entry. Read-only for now: A is a no-op (the party action
; sub-menu, summary, and HP bar are deferred UI); B exits to the START menu.
;
; The party is capped at 6, so every entry fits and there is no scrolling (unlike
; the bag). Each mon takes two rows: "▶NICK  :Lnn" then "HP cur/max". Rendered
; through the GB window layer like the START / bag menus (draw into the 20-wide
; wTileMap scratch grid, copy the box rect to GB_TILEMAP1, blit via render_window
; with g_win_clip_w/g_win_max_y bounding).
;
; CALLER CONTRACT: the text font must already be resident in vFont (the START menu
; loads it before dispatching here). Input uses H_JOY_PRESSED.
;
; Pret ref: home/list_menu.asm PCPOKEMONLISTMENU path + PrintLevel (HP-bar/summary
; omitted in this first cut).
; ---------------------------------------------------------------------------
bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_macros.inc"

global DisplayPartyMenu

extern TextBoxBorder         ; ESI=top-left, BL=interior width, BH=interior height
extern PlaceString           ; ESI=dest (EBP-rel), EDX=src offset (EBP-rel)
extern DelayFrame
extern g_win_clip_w
extern g_win_max_y
%ifdef DEBUG_PARTYMENU
extern DumpBackbuffer
%endif

; --- layout (GB 20-wide logical wTileMap coords) ---
PM_BOX_W       equ 18        ; interior width → box cols 0-19
PM_CURSOR_COL  equ 1
PM_NAME_COL    equ 2
PM_LEVEL_COL   equ 13        ; ":" col; "L" at +1; level digits at +2..+4
PM_HP_COL      equ 3         ; "HP" col; cur at +3, "/" at +6, max at +7
PM_FIRST_ROW   equ 1         ; first name row (interior)

; window: full 20-tile (160px) box centered in the 320px viewport (WX-7=80).
PM_WIN_WX      equ 87
PM_WIN_CLIP_W  equ 160

CHAR_CURSOR    equ 0xED      ; ▶
CHAR_COLON     equ 0x9C      ; :
CHAR_L         equ 0x8B      ; L
CHAR_H         equ 0x87      ; H
CHAR_P         equ 0x8F      ; P
CHAR_SLASH     equ 0xF3      ; /
CHAR_DIGIT0    equ 0xF6      ; '0'; digit d → +d
TILE_SPC       equ 0x7F

section .bss
align 4
pm_count:      resd 1        ; party size (1..6)
pm_selected:   resd 1        ; selected entry index (0..count-1)
pm_slot:       resd 1        ; render-loop slot counter (survives PlaceString/div)

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

    ; window placement: box total rows = count*2 + 2 (borders); max_y = rows*8.
    mov byte  [ebp + H_WY], 0
    mov byte  [ebp + IO_WX], PM_WIN_WX
    mov dword [g_win_clip_w], PM_WIN_CLIP_W
    mov eax, [pm_count]
    shl eax, 1
    add eax, 2                  ; total box rows
    shl eax, 3                  ; * 8 px
    mov [g_win_max_y], eax

    call .render

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
    jmp .loop
.up:
    mov eax, [pm_selected]
    test eax, eax
    jz .loop
    dec eax
    mov [pm_selected], eax
    call .render
    jmp .loop

.exit:
.exit_release:
    call DelayFrame
    test byte [ebp + H_JOY_HELD], PAD_A | PAD_B
    jnz .exit_release
.exit_now:
    popad
    ret

; --- redraw box + all party entries + cursor into wTileMap, then copy ---------
.render:
    ; box border (clears interior); interior height = count*2.
    mov esi, W_TILEMAP
    mov bl, PM_BOX_W
    mov eax, [pm_count]
    shl eax, 1
    mov bh, al
    call TextBoxBorder

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
    imul eax, eax, 20
    mov edi, eax                        ; EDI = name row base (col 0)

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

    ; ":L" + level
    mov byte [ebp + edi + W_TILEMAP + PM_LEVEL_COL], CHAR_COLON
    mov byte [ebp + edi + W_TILEMAP + PM_LEVEL_COL + 1], CHAR_L
    movzx eax, byte [ebp + ebx + MON_LEVEL]
    push edi
    push ebx
    lea edi, [edi + W_TILEMAP + PM_LEVEL_COL + 2]
    call .print_num3
    pop ebx
    pop edi

    ; HP row = name row + 1 → "HP" + cur "/" max
    mov esi, edi
    add esi, 20                         ; HP row base (col 0)
    mov byte [ebp + esi + W_TILEMAP + PM_HP_COL], CHAR_H
    mov byte [ebp + esi + W_TILEMAP + PM_HP_COL + 1], CHAR_P
    mov byte [ebp + esi + W_TILEMAP + PM_HP_COL + 6], CHAR_SLASH
    ; current HP (big-endian word at struct+MON_HP)
    movzx eax, byte [ebp + ebx + MON_HP]
    shl eax, 8
    mov al, [ebp + ebx + MON_HP + 1]
    push edi
    push ebx
    push esi
    lea edi, [esi + W_TILEMAP + PM_HP_COL + 3]
    call .print_num3
    pop esi
    pop ebx
    pop edi
    ; max HP (big-endian word at struct+MON_MAXHP)
    movzx eax, byte [ebp + ebx + MON_MAXHP]
    shl eax, 8
    mov al, [ebp + ebx + MON_MAXHP + 1]
    push edi
    lea edi, [esi + W_TILEMAP + PM_HP_COL + 7]
    call .print_num3
    pop edi

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

    ; copy the box rect (cols 0-19) → GB_TILEMAP1 (cols 0-19)
    mov eax, [pm_count]
    shl eax, 1
    add eax, 2                          ; total box rows
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
