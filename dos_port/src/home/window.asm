; window.asm — menu-input primitives (mirrors home/window.asm:HandleMenuInput /
; PlaceMenuCursor). Relocated here from the deleted wide_text.asm as part of the
; text-engine unification (docs/current_plan_battle_pret_alignment.md Stage 0.5):
; there is no separate "wide" engine any more. These use the shared runtime
; `text_row_stride` (text.asm) for the tilemap row stride, so the same code works
; at stride 20 (overworld) or 40 (centered battle layout).
;
; Register map: A=AL, BC=BX, DE=DX, HL=ESI, EBP=GB base; GB memory = [EBP+addr].
;
; Build: nasm -f coff -I include/ -I . -o window.o window.asm
%include "gb_memmap.inc"
%include "gb_constants.inc"

bits 32

%define CHAR_CURSOR 0xED               ; ▶ (charmap.asm)

extern DelayFrame
extern text_row_stride                 ; text.asm — current W_TILEMAP row stride

global HandleMenuInput
global PlaceMenuCursor
global menu_item_step
global menu_redraw_cb

section .bss
; Menu cursor vertical item spacing (bytes). Set by the caller: text_row_stride
; (single-spaced list) or 2*text_row_stride (double-spaced, e.g. the battle
; FIGHT/PKMN/ITEM/RUN grid). Mirrors the GB hUILayoutFlags spacing toggles.
menu_item_step: resd 1
; Optional per-item redraw callback (0 = none): called after the cursor is
; (re)drawn each loop so a menu can refresh side info (e.g. the move TYPE/PP box)
; on cursor move — mirrors pret SelectMenuItem calling PrintMenuItem each frame.
menu_redraw_cb: resd 1

section .text

; ---------------------------------------------------------------------------
; PlaceMenuCursor — draw the ▶ cursor at the current menu item, erasing the
; previous one. Faithful to home/window.asm:PlaceMenuCursor (cursor at
; wTopMenuItem{X,Y}, item spacing = menu_item_step). In: EBP = GB base.
; ---------------------------------------------------------------------------
PlaceMenuCursor:
    ; base = W_TILEMAP + Y*stride + X
    movzx eax, byte [ebp + wTopMenuItemY]
    imul eax, [text_row_stride]
    movzx ecx, byte [ebp + wTopMenuItemX]
    add eax, ecx
    add eax, W_TILEMAP
    mov ebx, [menu_item_step]           ; per-item row step
    ; erase the cursor at the previous item (if still there)
    movzx ecx, byte [ebp + wLastMenuItem]
    imul ecx, ebx
    mov edx, eax
    add edx, ecx
    cmp byte [ebp + edx], CHAR_CURSOR
    jne .skip_erase
    mov cl, [ebp + wTileBehindCursor]
    mov [ebp + edx], cl
.skip_erase:
    ; draw at the current item
    movzx ecx, byte [ebp + wCurrentMenuItem]
    imul ecx, ebx
    add eax, ecx
    cmp byte [ebp + eax], CHAR_CURSOR
    je .skip_save
    mov cl, [ebp + eax]
    mov [ebp + wTileBehindCursor], cl
.skip_save:
    mov byte [ebp + eax], CHAR_CURSOR
    mov cl, [ebp + wCurrentMenuItem]
    mov [ebp + wLastMenuItem], cl
    ret

; ---------------------------------------------------------------------------
; HandleMenuInput — vertical menu input loop. Faithful to home/window.asm
; HandleMenuInput's core (UP/DOWN within [0,wMaxMenuItem], no wrap; ends when a
; key in wMenuWatchedKeys is pressed). Drops the GB peripherals (down-arrow blink,
; party-mon shake, AB sound, low-sensitivity auto-repeat); reads the per-frame
; edge-triggered H_JOY_PRESSED via DelayFrame, like the START menu.
; Out: AL = the watched key(s) that ended input.
; ---------------------------------------------------------------------------
HandleMenuInput:
.loop1:
    call PlaceMenuCursor
    mov eax, [menu_redraw_cb]           ; optional side-info redraw (e.g. TYPE/PP box)
    test eax, eax
    jz .loop2
    call eax
.loop2:
    call DelayFrame
    movzx eax, byte [ebp + H_JOY_PRESSED]
    test al, al
    jz .loop2
    mov bl, al                          ; b = pressed keys
    test al, PAD_A
    jnz .checkWatched                   ; A: skip movement
    test al, PAD_UP
    jz .checkDown
    ; UP
    mov al, [ebp + wCurrentMenuItem]
    test al, al
    jz .checkWatched                    ; already at top (no wrap)
    dec al
    mov [ebp + wCurrentMenuItem], al
    jmp .checkWatched
.checkDown:
    test bl, PAD_DOWN
    jz .checkWatched
    ; DOWN
    movzx eax, byte [ebp + wCurrentMenuItem]
    inc eax
    mov cl, al                          ; c = cur+1
    mov al, [ebp + wMaxMenuItem]
    cmp al, cl
    jb .checkWatched                    ; max < cur+1 → already at bottom
    mov [ebp + wCurrentMenuItem], cl
.checkWatched:
    mov al, [ebp + wMenuWatchedKeys]
    and al, bl
    jz .loop1                           ; no watched key → redraw cursor, keep waiting
    mov al, bl                          ; return the pressed keys
    ret
