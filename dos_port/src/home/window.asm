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
%include "msgbox.inc"                    ; the message-box projection record
%include "assets/audio_constants.inc"    ; SFX_PRESS_AB

bits 32

; Menu-state WRAM (wMenuCursorLocation/wMenuJoypadPollCount/wMenuWatchMovingOutOfBounds/
; wMenuWrappingEnabled) lives canonically in gb_memmap.inc (Wave 4 integration).

%define CHAR_CURSOR         0xED          ; ▶ (charmap.asm)
%define CHAR_UNFILLED_ARROW 0xEC          ; ▷ (charmap.asm)
%define CHAR_SPACE          0x7F          ; blank space tile (charmap.asm)

; pret: hlcoord 18, 11 — "coordinates of blinking down arrow in some menus"
; (home/window.asm HandleMenuInput_). Row/col, applied to the current
; text_row_stride rather than the GB's fixed SCREEN_WIDTH.
%define MENU_ARROW_ROW      11
%define MENU_ARROW_COL      18

extern DelayFrame
extern AnimatePartyMon                 ; src/engine/gfx/mon_icons.asm — icon bob (ends in DelayFrame)
extern text_row_stride                 ; text.asm — current W_TILEMAP row stride
extern PlaySound                       ; src/home/audio.asm — sound id in AL

; --- PrintText's collaborators (all in text.asm — the text engine) ---
extern text_msgbox                     ; → the active msgbox projection record (msgbox.inc)
extern text_line2                      ; <LINE> cursor      ] the engine's live scratch,
extern text_arrow_pos                  ; <PROMPT> ▼ tile    ] loaded from the record
extern text_prompt_hook                ; <PROMPT> hook      ] on every PrintText
extern TextBoxBorder
extern TextCommandProcessor
extern sync_dialog_window
extern set_single_window               ; src/ppu/ppu.asm

global HandleMenuInput
global HandleMenuInput_
global PrintText
global PrintTextStaged
global PrintText_NoCreatingTextBox
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
; PrintText — pret home/window.asm:PrintText. Print the text-command stream at
; ESI in the message box.
;
;   pret:  push hl / ld a,MESSAGE_BOX / ld [wTextBoxID],a / call DisplayTextBoxID
;          call UpdateSprites / call Delay3 / pop hl
;          PrintText_NoCreatingTextBox: bccoord 1,14 / jp TextCommandProcessor
;
; There is ONE printer, exactly as in pret. What differs between the port's
; screens is not behavior but PROJECTION: the GB has a single 20x18 tilemap, the
; port has a 40x25 canvas, so each screen says *where* its message box lands by
; pointing text_msgbox at a projection record (msgbox.inc). The overworld's
; msgbox_dialog is a hand-tuned wide-screen placement shown through the dialog
; window; battle's msgbox_centered is center-projected and drawn straight into the
; canvas. Re-projecting either is a data edit — never a second PrintText.
;
; DEVIATION(canvas): the box geometry, the <LINE>/<PROMPT> targets and the window
; descriptor come from the record instead of pret's fixed hlcoord/bccoord literals.
;
; In:  ESI = flat pointer to a text-command stream.
; Out: as TextCommandProcessor. Clobbers EAX/EBX/ECX/EDX/ESI/EDI.
;
; PrintTextStaged (below, falls through) is a port-only second entry for a stream
; COMPOSED AT RUN TIME IN WRAM.
; ---------------------------------------------------------------------------
PrintTextStaged:
    ; Port-only entry: the stream was composed in WRAM at run time
    ; (battle/core.asm:AppendStringBufferText splices a `TX_RAM wStringBuffer`
    ; operand into NPC_DIALOG_BUF), so it genuinely lives in GB space and is named
    ; EBP-relative. Every other stream is flat program-image data and enters at
    ; PrintText directly. This is not a workaround for the engine — it is a second
    ; entry for a second kind of stream; pret needs no such split because its
    ; streams are all addressable in place.
    lea esi, [ebp + NPC_DIALOG_BUF]     ; name the composed stream as a flat pointer
    ; fall through

PrintText:
    push esi                            ; pret: push hl
    mov edi, [text_msgbox]              ; the active projection record

    ; Publish this projection to the text engine (pret has no equivalent: on the
    ; GB these are fixed literals inside TextCommandProcessor). Doing it on every
    ; PrintText is also what keeps a battle's projection from leaking into the
    ; next overworld dialog — nothing else ever restores them.
    mov eax, [edi + MB_STRIDE]
    mov [text_row_stride], eax
    mov eax, [edi + MB_LINE2]
    mov [text_line2], eax
    mov eax, [edi + MB_ARROW]
    mov [text_arrow_pos], eax
    mov eax, [edi + MB_PROMPT]
    mov [text_prompt_hook], eax

    ; Draw the box (pret: DisplayTextBoxID MESSAGE_BOX).
    mov esi, [edi + MB_BOX_OFS]
    mov bh, [edi + MB_BOX_H]
    mov bl, [edi + MB_BOX_W]
    call TextBoxBorder                  ; preserves ESI and EBX — but NOT EDI
    mov edi, [text_msgbox]              ; TextBoxBorder walks EDI over the box rows

    ; Present it. A projection with a window (the overworld dialog) shows the box
    ; through the window layer and mirrors each character as it is typed; one
    ; without (MB_WIN_TILEMAP == 0, the centered box) draws straight into the
    ; canvas, leaving the caller's window list untouched — which is exactly why
    ; the full-screen menus select it.
    mov eax, [edi + MB_WIN_TILEMAP]
    test eax, eax
    jz .noWindow
    mov esi, eax                        ; window source tilemap
    mov eax, [edi + MB_WIN_WX]
    mov ebx, [edi + MB_WIN_WY]
    mov ecx, [edi + MB_WIN_CLIP]
    mov edx, [edi + MB_WIN_MAXY]
    push edi
    mov edi, [edi + MB_WIN_STARTROW]
    call set_single_window              ; count=1; mirrors wy→H_WY (dialog-open flag)
    pop edi
    call sync_dialog_window             ; show the empty box before the first char
    call DelayFrame
.noWindow:
    pop esi                             ; pret: `pop hl` — restore the stream pointer

; ---------------------------------------------------------------------------
; PrintText_NoCreatingTextBox — pret home/window.asm. Type the stream without
; drawing a box. pret: `bccoord 1, 14 / jp TextCommandProcessor`; here the cursor
; is the active projection's first text line.
; In: ESI = flat pointer to a text-command stream.
; ---------------------------------------------------------------------------
PrintText_NoCreatingTextBox:
    mov edi, [text_msgbox]
    mov ebx, [edi + MB_LINE1]           ; bccoord 1, 14
    jmp TextCommandProcessor            ; tail call

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
; HandleMenuInput / HandleMenuInput_ — vertical menu input loop. Mirrors
; home/window.asm: HandleMenuInput clears wPartyMenuAnimMonEnabled and falls
; through into HandleMenuInput_, which is the loop proper (callers that want the
; party-mon icon bob — HandlePartyMenuInput — set the flag and call the
; underscore entry so it survives).
;
; Faithful: UP/DOWN within [0,wMaxMenuItem]; optional wrap (wMenuWrappingEnabled)
; and out-of-bounds early-return (wMenuWatchMovingOutOfBounds); the joypad-poll
; timeout (wMenuJoypadPollCount); the per-iteration AnimatePartyMon shake; the
; blinking ▼ at (18,11); the A/B press SFX gated on wMiscFlags
; BIT_NO_MENU_BUTTON_SOUND; the down-arrow blink counters saved/restored around
; the loop; wMenuWrappingEnabled cleared on every exit. Ends when a key in
; wMenuWatchedKeys is pressed.
;
; DEVIATION(timing): pret spins .loop2 free-running (JoypadLowSensitivity polls
; the hardware; .loop1 ends in Delay3). The port has no busy-poll — the joypad is
; an ISR and H_JOY_PRESSED is edge-triggered per frame — so the loop is paced by
; one DelayFrame per iteration (AnimatePartyMon ends in DelayFrame, hence the
; either/or) and pret's Delay3 is dropped: it would add 3 dead frames per cursor
; move on top of the frame the port already spends, which is the menu lethargy
; that was fixed in JoypadLowSensitivity (docs/plans/menus.md, 2026-07-04).
; wMenuJoypadPollCount is therefore counted in frames, not poll iterations.
;
; Out: AL = the watched key(s) that ended input (0 on timeout).
; Preserves ESI (callers' menu pointers); clobbers EAX/EBX/ECX/EDX.
; ---------------------------------------------------------------------------
HandleMenuInput:
    mov byte [ebp + wPartyMenuAnimMonEnabled], 0 ; xor a / ld [wPartyMenuAnimMonEnabled],a
HandleMenuInput_:
    push esi
    ; pret pushes hDownArrowBlinkCount1/2 and restores them on both exits.
    mov al, [ebp + H_DOWN_ARROW_COUNT1]
    mov ah, [ebp + H_DOWN_ARROW_COUNT2]
    push eax
    ; DEVIATION(timing): pret seeds COUNT1=0 / COUNT2=6 — with its kHz-rate
    ; .loop2 that is "arrow visible, blink phase reset", and COUNT1=0 doubles as
    ; HandleDownArrowBlinkTiming's "no blink active" guard so the call is inert
    ; on menus with no ▼. The port's blink is frame-paced (ARROW_ON/OFF_FRAMES),
    ; where a nonzero COUNT1 on an arrow-less menu would eventually *draw* a
    ; spurious ▼. So arm the frame-paced counters only when the tile really is a
    ; ▼, and leave COUNT1=0 (inert) otherwise — pret's net behavior, in frames.
    call .downArrowTile                 ; ESI = ▼ tile offset
    mov byte [ebp + H_DOWN_ARROW_COUNT1], 0
    mov byte [ebp + H_DOWN_ARROW_COUNT2], 1
    cmp byte [ebp + esi], CHAR_DOWN_ARROW
    jne .loop1
    mov byte [ebp + H_DOWN_ARROW_COUNT1], ARROW_ON_FRAMES
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
    ; no key this frame — blink the down arrow (pret: hlcoord 18,11 /
    ; call HandleDownArrowBlinkTiming), then the poll-count timeout
    ; (pret .giveUpWaiting). Faithful: the stored count is read fresh and
    ; decremented in-register only (no write-back), so the timeout fires only
    ; when [wMenuJoypadPollCount] == 1. With the default 0 (0-1=0xFF, not zero)
    ; it never fires → the menu waits forever, as pret's does.
    call .downArrowTile                 ; ESI = ▼ tile offset
    call HandleDownArrowBlinkTiming
    mov al, [ebp + wMenuJoypadPollCount]
    dec al
    jz .giveUpWaiting
    jmp .loop2
.giveUpWaiting:
    ; timed out without a watched key: restore the blink counters, disable
    ; wrapping (pret) and return 0.
    pop eax
    mov [ebp + H_DOWN_ARROW_COUNT1], al
    mov [ebp + H_DOWN_ARROW_COUNT2], ah
    pop esi
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
    ; pret .checkIfAButtonOrBButtonPressed: A or B ends the menu with a blip,
    ; unless the caller asked for silence (the generic-PC screens do).
    test bl, PAD_A | PAD_B
    jz .skipPlayingSound
    test byte [ebp + wMiscFlags], 1 << BIT_NO_MENU_BUTTON_SOUND
    jnz .skipPlayingSound
    mov al, SFX_PRESS_AB
    call PlaySound                      ; preserves EBX (home/audio.asm)
.skipPlayingSound:
    pop eax                             ; restore the down-arrow blink counters
    mov [ebp + H_DOWN_ARROW_COUNT1], al
    mov [ebp + H_DOWN_ARROW_COUNT2], ah
    pop esi
    xor al, al
    mov [ebp + wMenuWrappingEnabled], al ; pret: disable wrapping on exit
    mov al, bl                          ; ldh a, [hJoy5] — the pressed keys
    ret

; ---------------------------------------------------------------------------
; .downArrowTile — ESI = EBP-relative tile offset of the blinking ▼.
; pret: `hlcoord 18, 11`. DEVIATION(stride): the port's menu scratch tilemap has
; a runtime row stride (20 or 40), so the row is scaled by text_row_stride
; instead of the GB's fixed SCREEN_WIDTH. Preserves EAX/EBX/ECX/EDX.
; ---------------------------------------------------------------------------
.downArrowTile:
    mov esi, [text_row_stride]
    imul esi, MENU_ARROW_ROW
    add esi, W_TILEMAP + MENU_ARROW_COL
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
; its 0xFF/6 reloads would give a ~25 s blink here. Every caller arms
; COUNT1=ARROW_ON_FRAMES, COUNT2=1 before the first call (text.asm
; manual_text_scroll, map_sprites sync_dialog_window, and HandleMenuInput_ —
; which arms them only when the tile at (18,11) really is a ▼); the COUNT1==0
; guard below is what keeps the call inert everywhere else.
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
