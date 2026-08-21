; unused_input.asm — faithful port of engine/menus/unused_input.asm (pret).
;
; Three routines pret itself marks `; unreferenced`: a second copy of the
; HandleMenuInput / HandleMenuInputPokemonSelection / PlaceMenuCursor family that
; shipped in the ROM but that nothing calls. They are ported for label-for-label
; parity with the pret file, not for behaviour — nothing calls them here either,
; exactly as in pret. Kept non-`global`, matching pret's single-colon labels.
;
; The duplicates are NOT identical to the live routines in home/window.asm: this
; copy hardcodes the tilemap geometry (SCREEN_WIDTH row step, $28 = two rows per
; menu item) instead of reading the menu state, and carries the entry defect
; noted at PlaceMenuCursorDuplicate. Translated as written — see that note.
;
; Build: nasm -f coff -I include/ -I . -o /dev/null src/engine/menus/unused_input.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "assets/audio_constants.inc"   ; SFX_PRESS_AB

%define CHAR_CURSOR         0xED        ; ▶ (constants/charmap.asm)

section .text

; ---- ported dependencies ---------------------------------------------------
extern JoypadLowSensitivity            ; src/home/joypad2.asm
extern PlaySound                       ; src/home/audio.asm
extern text_row_stride                 ; global dd in src/home/text.asm (canvas row stride)

; ---------------------------------------------------------------------------
; HandleMenuInputDuplicate — pret ref: engine/menus/unused_input.asm, marked
; `; unreferenced`. Clears the party-menu icon animation flag and FALLS THROUGH
; into HandleMenuInputPokemonSelectionDuplicate, exactly as pret does (the same
; relationship home/window.asm's HandleMenuInput has with HandleMenuInput_).
; ---------------------------------------------------------------------------
HandleMenuInputDuplicate:
    xor al, al
    mov [ebp + wPartyMenuAnimMonEnabled], al
    ; falls through

; ---------------------------------------------------------------------------
; HandleMenuInputPokemonSelectionDuplicate — pret ref: same file, also marked
; `; unreferenced`. Vertical menu input loop: save the two down-arrow blink
; counters, poll until a watched key is pressed, move the cursor, restore the
; counters and return the pressed keys in A.
;
; Out: AL = hJoy5 (the keys that ended input); 0 via the no-key exit path.
; ---------------------------------------------------------------------------
HandleMenuInputPokemonSelectionDuplicate:
    mov al, [ebp + hDownArrowBlinkCount1]
    push eax                            ; push af
    mov al, [ebp + hDownArrowBlinkCount2]
    push eax                            ; push af — save existing values on stack
    xor al, al
    mov [ebp + hDownArrowBlinkCount1], al ; blinking down arrow timing value 1
    mov al, 6
    mov [ebp + hDownArrowBlinkCount2], al ; blinking down arrow timing value 2
.loop1:
    xor al, al
    mov [ebp + wAnimCounter], al        ; counter for pokemon shaking animation
    call PlaceMenuCursorDuplicate
    call JoypadLowSensitivity
    mov al, [ebp + hJoy5]
    test al, al                         ; and a — was a key pressed?
    jnz .keyPressed
    pop eax                             ; pop af
    mov [ebp + hDownArrowBlinkCount2], al
    pop eax                             ; pop af
    mov [ebp + hDownArrowBlinkCount1], al ; restore previous values
    xor al, al
    mov [ebp + wMenuWrappingEnabled], al ; disable menu wrapping
    ret
.keyPressed:
    xor al, al
    mov [ebp + wCheckFor180DegreeTurn], al
    mov al, [ebp + hJoy5]
    mov bh, al                          ; ld b, a   (mov sets no flags)
    test al, PAD_UP                     ; bit B_PAD_UP, a
    jz .checkIfDownPressed
.upPressed:
    mov al, [ebp + wCurrentMenuItem]    ; selected menu item
    test al, al                         ; already at the top of the menu?
    jz .checkOtherKeys
.notAtTop:
    dec al
    mov [ebp + wCurrentMenuItem], al    ; move selected menu item up one space
    jmp .checkOtherKeys
.checkIfDownPressed:
    test al, PAD_DOWN                   ; bit B_PAD_DOWN, a (A still holds hJoy5)
    jz .checkOtherKeys
.downPressed:
    mov al, [ebp + wCurrentMenuItem]
    inc al
    mov bl, al                          ; ld c, a
    mov al, [ebp + wMaxMenuItem]
    cmp al, bl                          ; cp c
    jb .checkOtherKeys                  ; jr c — past the last item, ignore
    mov al, bl
    mov [ebp + wCurrentMenuItem], al
.checkOtherKeys:
    mov al, [ebp + wMenuWatchedKeys]
    and al, bh                          ; and b — any key the menu cares about?
    jz .loop1                           ; jp z, .loop1
.checkIfAButtonOrBButtonPressed:
    mov al, [ebp + hJoy5]
    and al, PAD_A | PAD_B
    jz .skipPlayingSound
.AButtonOrBButtonPressed:
    mov al, SFX_PRESS_AB
    call PlaySound                      ; play sound
.skipPlayingSound:
    pop eax                             ; pop af
    mov [ebp + hDownArrowBlinkCount2], al
    pop eax                             ; pop af
    mov [ebp + hDownArrowBlinkCount1], al ; restore previous values
    mov al, [ebp + hJoy5]
    ret

; ---------------------------------------------------------------------------
; PlaceMenuCursorDuplicate — pret ref: same file. Erase the ▶ at wLastMenuItem
; and draw it at wCurrentMenuItem, two tilemap rows per menu item.
;
; pret ENTRY DEFECT, carried verbatim: `hlcoord 0, 0` is executed only on the
; wTopMenuItemY != 0 path, so with a top row of 0 the routine indexes off
; whatever HL its caller happened to leave — HL is never initialised on that
; path. home/window.asm's live PlaceMenuCursor sets the base first and has no
; such hole. Reproduced here (ESI is likewise the caller's), because this is the
; code pret ships; it is also part of why the family is unreferenced.
;
; DEVIATION{class=projection; pret=engine/menus/unused_input.asm:PlaceMenuCursorDuplicate; behavior=step the cursor by the port canvas row stride and twice that per menu item rather than pret's literal 20 and 40, so the cursor lands on the same tilemap cells; evidence=port wTileMap is 40x25 with the row stride published as text_row_stride which every ported menu drawer already uses, so the pret literals would address the wrong row entirely; lifetime=permanent canvas projection boundary}
; pret's `ld bc, $28` is the two-rows-per-item party-menu spacing (2 * 20), not
; the current menu's step, so it is projected as 2 * text_row_stride rather than
; the port's menu_item_step — that would be a different routine.
; ---------------------------------------------------------------------------
PlaceMenuCursorDuplicate:
    mov al, [ebp + wTopMenuItemY]
    test al, al
    jz .asm_f5ac0                       ; (leaves ESI as the caller left it — see above)
    mov esi, wTileMap                   ; hlcoord 0, 0
    mov ebx, [text_row_stride]          ; ld bc, SCREEN_WIDTH
.loop:
    add esi, ebx
    dec al                              ; 8-bit counter, as pret (dec a)
    jnz .loop
.asm_f5ac0:
    movzx ebx, byte [ebp + wTopMenuItemX] ; ld b, $0 / ld c, a
    add esi, ebx
    push esi
    mov al, [ebp + wLastMenuItem]
    test al, al
    jz .asm_f5ad5
    mov ebx, [text_row_stride]
    shl ebx, 1                          ; ld bc, $28 — two rows per menu item
.loop2:
    add esi, ebx
    dec al
    jnz .loop2
.asm_f5ad5:
    mov al, [ebp + esi]
    cmp al, CHAR_CURSOR                 ; cp "▶"
    jne .asm_f5ade
    mov al, [ebp + wTileBehindCursor]
    mov [ebp + esi], al
.asm_f5ade:
    pop esi
    mov al, [ebp + wCurrentMenuItem]
    test al, al
    jz .asm_f5aec
    mov ebx, [text_row_stride]
    shl ebx, 1                          ; ld bc, $28
.loop3:
    add esi, ebx
    dec al
    jnz .loop3
.asm_f5aec:
    mov al, [ebp + esi]
    cmp al, CHAR_CURSOR
    je .asm_f5af4
    mov [ebp + wTileBehindCursor], al
.asm_f5af4:
    mov byte [ebp + esi], CHAR_CURSOR
    ; ld a, l / ld [wMenuCursorLocation], a / ld a, h / ld [wMenuCursorLocation+1], a
    ; The port's tile offset is wTileMap-based and < 0x10000, so the 16-bit store
    ; is exact — the same idiom home/window.asm:PlaceMenuCursor uses.
    mov [ebp + wMenuCursorLocation], si
    mov al, [ebp + wCurrentMenuItem]
    mov [ebp + wLastMenuItem], al
    ret
