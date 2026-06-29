; wide_text.asm — stride-40 (W_TILEMAP) text/box/menu primitives.
;
; Faithful ports of the GB routines (home/text.asm TextBoxBorder / PlaceString /
; PlaceNextChar, home/window.asm HandleMenuInput / PlaceMenuCursor), with the GB
; SCREEN_WIDTH=20 stride replaced by the port's 40-wide battle canvas (W_TILEMAP).
;
; The shipped text.asm routines hardcode a 20-tile stride and funnel through the
; 32-wide GB VRAM-tilemap window path, so they cannot address the centered 40x25
; battle layout. These parallel routines let the battle UI reuse pret's actual
; routine STRUCTURE (DisplayTextBoxID-style box, PlaceString, HandleMenuInput's
; two-column dispatch) instead of hand-drawing — on the wide canvas.
;
; Register map: A=AL, BC=BX, DE=DX, HL=ESI, EBP=GB base; GB memory = [EBP+addr].
;
%include "gb_memmap.inc"
%include "gb_constants.inc"

bits 32

%define FW          SCREEN_TILES_W     ; 40 — W_TILEMAP stride
%define CHAR_CURSOR 0xED               ; ▶
%define CHAR_NEXT   0x4E               ; <NEXT>  (charmap.asm)
%define CHAR_TERM   0x50               ; @
%define T_TL 0x79      ; ┌
%define T_H  0x7A      ; ─
%define T_TR 0x7B      ; ┐
%define T_V  0x7C      ; │
%define T_BL 0x7D      ; └
%define T_BR 0x7E      ; ┘
%define T_SP 0x7F      ; space / blank

extern DelayFrame

global WideTextBoxBorder
global WidePlaceString
global WideHandleMenuInput
global WidePlaceMenuCursor
global wide_line_step
global wide_menu_redraw_cb

section .bss
; Row step (bytes) for <NEXT> line breaks AND menu cursor item spacing — mirrors
; the GB hUILayoutFlags BIT_SINGLE_SPACED_LINES / BIT_DOUBLE_SPACED_MENU toggles.
; Callers set it: 2*FW (double-spaced, e.g. the FIGHT/PKMN/ITEM/RUN menu) or FW
; (single-spaced lists, e.g. the move list).
wide_line_step: resd 1
wide_line_start: resd 1                ; current line's start offset (for <NEXT>)
; Optional per-item redraw callback (0 = none): called after the cursor is (re)drawn
; each loop, so a menu can refresh side info (e.g. the move TYPE/PP box) on cursor
; move — mirrors pret SelectMenuItem calling PrintMenuItem each iteration.
wide_menu_redraw_cb: resd 1

section .text

; ---------------------------------------------------------------------------
; WideTextBoxBorder — draw a BL-wide × BH-tall bordered box at ESI (W_TILEMAP
; offset). Faithful to home/text.asm TextBoxBorder, stride 40. Clears interior to
; spaces. In: ESI = top-left offset, BH = interior height, BL = interior width.
; Preserves ESI, EBX.
; ---------------------------------------------------------------------------
WideTextBoxBorder:
    push esi
    push ebx
    movzx ecx, bl                      ; interior width
    movzx edx, bh                      ; interior height
    lea edi, [ebp + esi]
    ; top row:  ┌ ─×w ┐
    mov byte [edi], T_TL
    call .fill_row
    mov byte [edi + ecx + 1], T_TR
    add edi, FW
    ; middle rows:  │ space×w │
.mid:
    mov byte [edi], T_V
    push eax
    mov al, T_SP
    call .fill_chars
    pop eax
    mov byte [edi + ecx + 1], T_V
    add edi, FW
    dec edx
    jnz .mid
    ; bottom row:  └ ─×w ┘
    mov byte [edi], T_BL
    call .fill_row
    mov byte [edi + ecx + 1], T_BR
    pop ebx
    pop esi
    ret
.fill_row:
    mov al, T_H
.fill_chars:
    push edi
    push ecx
    inc edi                            ; start after the left corner/wall
    rep stosb                          ; AL × ECX(width)
    pop ecx
    pop edi
    ret

; ---------------------------------------------------------------------------
; WidePlaceString — place an '@'-terminated charmap string at ESI (W_TILEMAP
; offset). Faithful to PlaceString/PlaceNextChar: <NEXT> ($4E) returns to the
; string's start column two rows down; other bytes are placed as glyph tiles.
; In: ESI = dest W_TILEMAP offset, EAX = flat source pointer. Clobbers EAX,ECX.
; Out: ESI = offset just past the last glyph written (for chaining segments).
; ---------------------------------------------------------------------------
WidePlaceString:
    mov [wide_line_start], esi          ; remember line start (for <NEXT>)
.next:
    movzx ecx, byte [eax]
    cmp cl, CHAR_TERM
    je .done
    cmp cl, CHAR_NEXT
    je .newline
    mov [ebp + esi], cl
    inc esi
.advance:
    inc eax
    jmp .next
.newline:
    mov esi, [wide_line_start]
    add esi, [wide_line_step]           ; next line, same start column
    mov [wide_line_start], esi
    jmp .advance
.done:
    ret                                 ; ESI = end write position

; ---------------------------------------------------------------------------
; WidePlaceMenuCursor — erase the previous ▶ and draw it at the current item.
; Faithful to home/window.asm PlaceMenuCursor (double-spaced), stride 40. Uses
; wTopMenuItemY/X, wCurrentMenuItem, wLastMenuItem, wTileBehindCursor.
; ---------------------------------------------------------------------------
WidePlaceMenuCursor:
    ; base = W_TILEMAP + Y*FW + X
    movzx eax, byte [ebp + wTopMenuItemY]
    imul eax, eax, FW
    movzx ecx, byte [ebp + wTopMenuItemX]
    add eax, ecx
    add eax, W_TILEMAP
    mov ebx, [wide_line_step]           ; per-item row step
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
; WideHandleMenuInput — vertical menu input loop. Faithful to home/window.asm
; HandleMenuInput's core (UP/DOWN within [0,wMaxMenuItem], no wrap; ends when a
; key in wMenuWatchedKeys is pressed). Drops the GB peripherals (down-arrow blink,
; party-mon shake, AB sound, low-sensitivity auto-repeat); reads the per-frame
; edge-triggered H_JOY_PRESSED via DelayFrame, like the START menu.
; Out: AL = the watched key(s) that ended input.
; ---------------------------------------------------------------------------
WideHandleMenuInput:
.loop1:
    call WidePlaceMenuCursor
    mov eax, [wide_menu_redraw_cb]      ; optional side-info redraw (e.g. TYPE/PP box)
    test eax, eax
    jz .loop2
    call eax
.loop2:
    call DelayFrame
    movzx eax, byte [ebp + H_JOY_PRESSED]
    test al, al
    jz .loop2
    mov bl, al                         ; b = pressed keys
    test al, PAD_A
    jnz .checkWatched                  ; A: skip movement
    test al, PAD_UP
    jz .checkDown
    ; UP
    mov al, [ebp + wCurrentMenuItem]
    test al, al
    jz .checkWatched                   ; already at top (no wrap)
    dec al
    mov [ebp + wCurrentMenuItem], al
    jmp .checkWatched
.checkDown:
    test bl, PAD_DOWN
    jz .checkWatched
    ; DOWN
    movzx eax, byte [ebp + wCurrentMenuItem]
    inc eax
    mov cl, al                         ; c = cur+1
    mov al, [ebp + wMaxMenuItem]
    cmp al, cl
    jb .checkWatched                   ; max < cur+1 → already at bottom
    mov [ebp + wCurrentMenuItem], cl
.checkWatched:
    mov al, [ebp + wMenuWatchedKeys]
    and al, bl
    jz .loop1                          ; no watched key → redraw cursor, keep waiting
    mov al, bl                         ; return the pressed keys
    ret
