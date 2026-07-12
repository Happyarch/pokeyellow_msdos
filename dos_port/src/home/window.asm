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

; Menu-state WRAM (wMenuCursorLocation/wMenuJoypadPollCount/wMenuWatchMovingOutOfBounds/
; wMenuWrappingEnabled) lives canonically in gb_memmap.inc (Wave 4 integration).

%define CHAR_CURSOR         0xED          ; ▶ (charmap.asm)
%define CHAR_UNFILLED_ARROW 0xEC          ; ▷ (charmap.asm)
%define CHAR_SPACE          0x7F          ; blank space tile (charmap.asm)

extern DelayFrame
extern AnimatePartyMon                 ; src/engine/gfx/mon_icons.asm — icon bob (ends in DelayFrame)
extern text_row_stride                 ; text.asm — current W_TILEMAP row stride

global HandleMenuInput
global PlaceMenuCursor
global EraseMenuCursor
global PlaceUnfilledArrowMenuCursor
global HandleDownArrowBlinkTiming
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
; wTopMenuItem{X,Y}, item spacing = menu_item_step). Records the cursor's tile
; offset in wMenuCursorLocation so EraseMenuCursor / PlaceUnfilledArrowMenuCursor
; can address it (pret stores hl there). In: EBP = GB base.
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
    ; pret: ld [wMenuCursorLocation], hl — save the cursor's tile address so
    ; EraseMenuCursor can restore/blank it. The port's EBP-relative tile offset
    ; is < 0x10000 (W_TILEMAP-based), so a 16-bit store is exact and leaves the
    ; reserved bytes (0xCC32-33) untouched, matching the pret dw.
    mov [ebp + wMenuCursorLocation], ax
    mov cl, [ebp + wCurrentMenuItem]
    mov [ebp + wLastMenuItem], cl
    ret

; ---------------------------------------------------------------------------
; EraseMenuCursor — blank the tile at wMenuCursorLocation. Faithful to
; home/window.asm:EraseMenuCursor. In: EBP = GB base. Preserves EAX.
; ---------------------------------------------------------------------------
EraseMenuCursor:
    push eax
    movzx eax, word [ebp + wMenuCursorLocation]
    mov byte [ebp + eax], CHAR_SPACE
    pop eax
    ret

; ---------------------------------------------------------------------------
; PlaceUnfilledArrowMenuCursor — draw the ▷ (unfilled) cursor at
; wMenuCursorLocation. Faithful to home/window.asm:PlaceUnfilledArrowMenuCursor
; (used to grey out the cursor while a submenu/selection is active). In: EBP =
; GB base. Preserves EAX (pret saves A in B and restores it).
; ---------------------------------------------------------------------------
PlaceUnfilledArrowMenuCursor:
    push eax
    movzx eax, word [ebp + wMenuCursorLocation]
    mov byte [ebp + eax], CHAR_UNFILLED_ARROW
    pop eax
    ret

; ---------------------------------------------------------------------------
; HandleMenuInput — vertical menu input loop. Faithful to home/window.asm
; HandleMenuInput's core: UP/DOWN within [0,wMaxMenuItem]; optional wrap
; (wMenuWrappingEnabled) and out-of-bounds early-return (wMenuWatchMovingOutOfBounds);
; optional joypad-poll timeout (wMenuJoypadPollCount); ends when a key in
; wMenuWatchedKeys is pressed. Drops the GB party-mon shake and AB-press sound;
; reads the per-frame edge-triggered H_JOY_PRESSED via DelayFrame, like the START
; menu. All the new behaviors are GATED on their flag bytes, so with the port's
; default (zeroed) menu state the behavior is identical to the previous version.
; Out: AL = the watched key(s) that ended input (0 on timeout).
; ---------------------------------------------------------------------------
HandleMenuInput:
.loop1:
    mov byte [ebp + wAnimCounter], 0    ; xor a / ld [wAnimCounter],a — icon-bob phase
    call PlaceMenuCursor
    mov eax, [menu_redraw_cb]           ; optional side-info redraw (e.g. TYPE/PP box)
    test eax, eax
    jz .loop2
    call eax
.loop2:
    ; pret home/window.asm .loop2: when this is a pokémon-selection menu, the
    ; selected mon's icon is animated once per iteration — and AnimatePartyMon ends
    ; in DelayFrame, so it IS this loop's frame pacing (exactly one frame either way).
    cmp byte [ebp + wPartyMenuAnimMonEnabled], 0
    jz .noPartyMonAnim              ; and a / jr z,.getJoypadState
    call AnimatePartyMon            ; farcall AnimatePartyMon — shake the mini sprite
    jmp .getJoypadState
.noPartyMonAnim:
    call DelayFrame
.getJoypadState:
    movzx eax, byte [ebp + H_JOY_PRESSED]
    test al, al
    jnz .keyPressed
    ; no key this frame — poll-count timeout (pret .giveUpWaiting). Faithful:
    ; the stored count is read fresh and decremented in-register only (no
    ; write-back), so the timeout fires only when [wMenuJoypadPollCount] == 1.
    ; With the default 0 (0-1=0xFF, not zero) it never fires → unchanged.
    mov al, [ebp + wMenuJoypadPollCount]
    dec al
    jz .giveUpWaiting
    jmp .loop2
.giveUpWaiting:
    ; timed out without a watched key: disable wrapping (pret) and return 0.
    xor al, al
    mov [ebp + wMenuWrappingEnabled], al
    ret                                 ; AL = 0
.keyPressed:
    mov bl, al                          ; b = pressed keys
    mov byte [ebp + W_CHECK_FOR_TURN], 0 ; pret: clear wCheckFor180DegreeTurn
    test al, PAD_A
    jnz .checkWatched                   ; A: skip movement
    test al, PAD_UP
    jz .checkDown
    ; UP
    mov al, [ebp + wCurrentMenuItem]
    test al, al
    jz .alreadyAtTop                    ; at top → wrap / out-of-bounds
    dec al
    mov [ebp + wCurrentMenuItem], al
    jmp .checkWatched
.alreadyAtTop:
    mov al, [ebp + wMenuWrappingEnabled]
    test al, al
    jz .noWrap                          ; wrapping disabled
    mov al, [ebp + wMaxMenuItem]        ; wrap to the bottom of the menu
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
    jae .notAtBottom                    ; max >= cur+1 → accept move
    ; already at bottom
    mov al, [ebp + wMenuWrappingEnabled]
    test al, al
    jz .noWrap                          ; wrapping disabled
    xor cl, cl                          ; wrap from bottom to top
.notAtBottom:
    mov [ebp + wCurrentMenuItem], cl
    jmp .checkWatched
.noWrap:
    ; tried to move past top/bottom with wrapping off. If the caller is watching
    ; for that (wMenuWatchMovingOutOfBounds != 0), return so it can scroll the
    ; whole list; otherwise ignore and keep waiting.
    mov al, [ebp + wMenuWatchMovingOutOfBounds]
    test al, al
    jz .checkWatched
    jmp .returnKeys                     ; return the UP/DOWN press (pret behavior)
.checkWatched:
    mov al, [ebp + wMenuWatchedKeys]
    and al, bl
    jz .loop1                           ; no watched key → redraw cursor, keep waiting
.returnKeys:
    xor al, al
    mov [ebp + wMenuWrappingEnabled], al ; pret: disable wrapping on exit
    mov al, bl                          ; return the pressed keys
    ret

; ---------------------------------------------------------------------------
; HandleDownArrowBlinkTiming — toggle a blinking ▼ at [EBP+ESI] on/off.
; Faithful (structure) to home/window.asm:HandleDownArrowBlinkTiming: a two-
; counter scheme (H_DOWN_ARROW_COUNT1 inner / H_DOWN_ARROW_COUNT2 outer) with
; the pret guard — when the tile isn't a ▼ *and* COUNT1 == 0, do nothing, so
; the routine is harmless to call on menus that have no down arrow (pret relies
; on callers zeroing COUNT1 for exactly this). The reload immediates are 60 Hz-
; adapted (ARROW_ON_FRAMES / ARROW_OFF_FRAMES) because the port calls this once
; per frame, whereas pret spins it inside JoypadLowSensitivity's busy-wait, so
; its 0xFF/6 reloads would give a ~25 s blink here. All existing callers already
; init COUNT1=ARROW_ON_FRAMES, COUNT2=1 (text.asm manual_text_scroll,
; map_sprites sync_dialog_window), so the visible cadence is unchanged; the new
; COUNT1==0 guard additionally fixes a latent spurious-arrow draw.
; In: ESI = EBP-relative tile offset of the arrow. Preserves EAX, EBX.
; ---------------------------------------------------------------------------
HandleDownArrowBlinkTiming:
    push eax
    push ebx
    movzx eax, byte [ebp + esi]
    cmp al, CHAR_DOWN_ARROW
    jne .arrowOff
.arrowOn:
    ; visible: count down the inner (ON) timer; when it and the outer expire,
    ; blink the arrow off.
    mov al, [ebp + H_DOWN_ARROW_COUNT1]
    dec al
    mov [ebp + H_DOWN_ARROW_COUNT1], al
    jnz .ret                            ; inner still counting
    mov byte [ebp + H_DOWN_ARROW_COUNT1], ARROW_ON_FRAMES ; reload inner
    mov al, [ebp + H_DOWN_ARROW_COUNT2]
    dec al
    mov [ebp + H_DOWN_ARROW_COUNT2], al
    jnz .ret                            ; outer still counting
    mov byte [ebp + esi], CHAR_SPACE    ; blink off
    mov byte [ebp + H_DOWN_ARROW_COUNT1], ARROW_OFF_FRAMES
    mov byte [ebp + H_DOWN_ARROW_COUNT2], 1
    jmp .ret
.arrowOff:
    ; hidden (or no arrow present). Pret guard: COUNT1 == 0 means no blink is
    ; active — do nothing (leave the tile alone).
    mov al, [ebp + H_DOWN_ARROW_COUNT1]
    and al, al
    jz .ret
    dec al
    mov [ebp + H_DOWN_ARROW_COUNT1], al
    jnz .ret                            ; inner (OFF) still counting
    mov byte [ebp + H_DOWN_ARROW_COUNT1], ARROW_OFF_FRAMES ; reload inner
    mov al, [ebp + H_DOWN_ARROW_COUNT2]
    dec al
    mov [ebp + H_DOWN_ARROW_COUNT2], al
    jnz .ret                            ; outer still counting
    mov byte [ebp + H_DOWN_ARROW_COUNT2], 1
    mov byte [ebp + H_DOWN_ARROW_COUNT1], ARROW_ON_FRAMES
    mov byte [ebp + esi], CHAR_DOWN_ARROW ; blink on
.ret:
    pop ebx
    pop eax
    ret
