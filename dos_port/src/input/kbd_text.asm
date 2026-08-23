; kbd_text.asm — port-only keyboard line-edit widget.
;
; NO PRET COUNTERPART: link cable plan Stage 5 step 1. This is a port-only
; input widget (lowercase, descriptive name per the "new port-only routines...
; get descriptive names" rule) sitting on top of the raw-scancode ring
; src/input/joypad.asm's kbd_isr feeds. It is the shared input layer Stage 5's
; link setup UI (address/name entry) and the later KBD_NAMING naming-screen
; path both consume — NO consumer is wired this step, so kbd_text_edit must
; link and be callable but nothing calls it in a normal build yet.
;
; kbd_text_edit — modal line-edit loop, one call per field:
;   In:  ESI = GB-space dest buffer address (charmap bytes, terminated $50 "@")
;        BL  = max length in characters (not counting the terminator)
;        BH  = charset class (see CHARSET_* below): filters which translated
;              characters may be appended
;        EDX = GB-space tilemap position where the field is echoed each frame
;   Out: AL  = 1 if committed (Enter pressed), 0 if cancelled (Esc pressed)
;        The dest buffer is '@'-terminated on EVERY exit path (Enter, Esc, or
;        hitting max length does not auto-commit -- only Enter does).
;   All other registers clobbered (matches PlaceString's own convention this
;   file already depends on -- see naming_screen.asm's callers).
;
;   Sets g_kbd_text_mode=1 on entry so kbd_isr starts buffering scancodes, and
;   0 on every exit path (commit, cancel -- there is exactly one exit point).
;   Drains the scancode ring on entry so keys buffered before the widget was
;   entered (e.g. the Enter/click that opened this field) are never replayed
;   into it. The normal joypad mapping keeps running throughout -- this widget
;   layers on top of it, it does not suspend it (see src/input/joypad.asm).
;
; ECHO SHAPE: modeled directly on how naming_screen.asm echoes wStringBuffer
; (src/engine/menus/naming_screen.asm:PrintNicknameAndUnderscores /
; .pressedA's PlaceString call) -- ClearScreenArea to blank the field width,
; then PlaceString the buffer (EAX = flat pointer via `lea eax,[ebp+dest]`,
; matching PlaceString's documented flat-source contract), then drop a cursor
; tile at the EBX position PlaceString hands back (its "cursor after the
; terminator" output, the same convention naming_screen's .pressedA relies on
; when it does `mov esi, ebx ; continue at the cursor PlaceString left`).
;
; CHARSET CLASSES ARE TABLE-DRIVEN CONTROL DATA, not human-rendered text: each
; class is a plain-byte {range-count, {min,max}...} list in this .asm below
; (KbdCharsetRanges_*). This is NOT the "text strings are DATA -- generate
; them" rule: these bytes are inclusive GB-charmap byte ranges the widget
; tests membership against, never glyphs PlaceString renders, so there is
; nothing for a Tier-1 generator to encode -- see gb_text.py's docstring: it
; encodes human-readable strings, not byte-range predicates.
;
; Build: nasm -f coff -I include/ -I . -o kbd_text.o kbd_text.asm

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"

CHAR_TERMINATOR equ 0x50   ; '@' -- end of a charmap string (matches every
                            ; other file's local equ of the same pret constant)
KBD_CURSOR_TILE equ 0xED   ; '▶' -- reuses pret's own list-menu cursor glyph
                            ; (src/home/list_menu.asm CHAR_CURSOR), for the
                            ; same reason: it is a control tile, not a string.

CHARSET_FREE    equ 0      ; any translated (nonzero) character is accepted
CHARSET_IP      equ 1      ; digits + '.' + ':'  (IPv4[:port]-shaped address)
CHARSET_HEX     equ 2      ; digits + 'A'-'F' + ':' (hex address)

SC_ENTER_KEY     equ 0x1C
SC_ESC_KEY       equ 0x01
SC_BACKSPACE_KEY equ 0x0E

%include "assets/kbd_scancode_map.inc"

; ---------------------------------------------------------------------------
; Exported symbols
; ---------------------------------------------------------------------------
global kbd_text_edit

; ---------------------------------------------------------------------------
; Imported symbols
; ---------------------------------------------------------------------------
extern g_kbd_text_mode     ; src/input/joypad.asm -- byte, gates kbd_isr's ring push
extern kbd_ring_pop        ; src/input/joypad.asm -- AL=scancode AH=shift ZF=1 empty
extern DelayFrame          ; src/home/vblank.asm -- all registers preserved
extern PlaceString         ; src/home/text.asm -- ESI=GB-space dest, EAX=flat src;
                            ; out: EBX=GB-space cursor pos after the terminator
extern ClearScreenArea     ; src/home/copy2.asm -- ESI=GB-space dest, BH=rows, BL=cols

; ---------------------------------------------------------------------------
; BSS -- per-invocation widget state. Flat (not GB WRAM): this is a port-only
; widget with no pret WRAM allocation, same convention as joypad.asm's own
; pad_dpad/pad_buttons. Lives in the existing .bss section this file opens
; below (no new section name -- link.ld rule).
; ---------------------------------------------------------------------------
section .bss
align 4
kbd_dest_ptr:       resd 1   ; GB-space dest buffer address (caller's ESI)
kbd_tile_pos:       resd 1   ; GB-space tilemap position (caller's EDX)
kbd_max_len:        resb 1   ; caller's BL
kbd_charset_class:  resb 1   ; caller's BH
kbd_cur_len:        resb 1   ; current character count in the buffer

; ---------------------------------------------------------------------------
; Data -- charset allow-tables. Plain control bytes, not text (see header).
; Layout per class: db range_count, then range_count pairs of {min, max}
; (inclusive, GB charmap byte values). CHARSET_FREE has 0 ranges, meaning
; "accept any nonzero translated byte" -- handled as a special case in
; .filter_char rather than an all-encompassing 0x01,0xFF range, so the table
; reads as "no restriction" rather than encoding the same thing two ways.
; ---------------------------------------------------------------------------
section .data
align 4
KbdCharsetRanges_Free:
    db 0
KbdCharsetRanges_IP:
    db 3
    db 0xF6, 0xFF   ; '0'-'9'
    db 0xE8, 0xE8   ; '.'
    db 0x9C, 0x9C   ; ':'
KbdCharsetRanges_Hex:
    db 3
    db 0xF6, 0xFF   ; '0'-'9'
    db 0x80, 0x85   ; 'A'-'F'
    db 0x9C, 0x9C   ; ':'

KbdCharsetTable:
    dd KbdCharsetRanges_Free   ; CHARSET_FREE
    dd KbdCharsetRanges_IP     ; CHARSET_IP
    dd KbdCharsetRanges_Hex    ; CHARSET_HEX

section .text

; ---------------------------------------------------------------------------
; kbd_text_edit -- see file header for the full contract.
; ---------------------------------------------------------------------------
kbd_text_edit:
    mov [kbd_dest_ptr], esi
    mov [kbd_tile_pos], edx
    mov [kbd_max_len], bl
    mov [kbd_charset_class], bh
    mov byte [kbd_cur_len], 0
    mov byte [ebp + esi], CHAR_TERMINATOR   ; buffer valid even if cancelled at 0 chars

    mov byte [g_kbd_text_mode], 1

    ; Drain stale ring entries buffered before this field was entered (e.g.
    ; the keypress that opened it).
.drain:
    call kbd_ring_pop
    jnz .drain

.redraw_and_wait:
    call .draw
    call DelayFrame
    call kbd_ring_pop
    jz .redraw_and_wait   ; nothing typed this frame -- keep polling

    ; AL = scancode, AH = shift flag
    cmp al, SC_ENTER_KEY
    je .commit
    cmp al, SC_ESC_KEY
    je .cancel
    cmp al, SC_BACKSPACE_KEY
    je .do_backspace

    ; Translate via the generated scancode->charmap tables.
    movzx ebx, al
    test ah, ah
    jz .use_unshifted
    mov al, [KbdScancodeMapShift + ebx]
    jmp .have_char
.use_unshifted:
    mov al, [KbdScancodeMap + ebx]
.have_char:
    test al, al
    jz .redraw_and_wait          ; untypable scancode -- ignore

    call .filter_char
    jnc .redraw_and_wait         ; rejected by the active charset class

    movzx ecx, byte [kbd_cur_len]
    cmp cl, [kbd_max_len]
    jae .redraw_and_wait         ; field full -- ignore

    mov edx, [kbd_dest_ptr]
    add edx, ecx
    mov [ebp + edx], al
    inc cl
    mov [kbd_cur_len], cl
    mov edx, [kbd_dest_ptr]
    add edx, ecx
    mov byte [ebp + edx], CHAR_TERMINATOR
    jmp .redraw_and_wait

.do_backspace:
    movzx ecx, byte [kbd_cur_len]
    test cl, cl
    jz .redraw_and_wait          ; already empty
    dec cl
    mov [kbd_cur_len], cl
    mov edx, [kbd_dest_ptr]
    add edx, ecx
    mov byte [ebp + edx], CHAR_TERMINATOR
    jmp .redraw_and_wait

.commit:
    call .draw                   ; leave the final committed text on screen
    mov al, 1
    jmp .exit
.cancel:
    call .draw
    xor al, al
.exit:
    push eax
    mov byte [g_kbd_text_mode], 0
    pop eax
    ret

; ---------------------------------------------------------------------------
; .draw -- blank the field width, echo the buffer, drop the cursor tile.
; Clobbers EAX/EBX/ECX/EDX/ESI (ClearScreenArea/PlaceString's own convention).
; ---------------------------------------------------------------------------
.draw:
    movzx ebx, byte [kbd_max_len]
    inc bl                       ; +1 column for the trailing cursor tile
                                  ; (confined to BL -- ClearScreenArea reads
                                  ; BL/BH as independent byte fields, and this
                                  ; keeps a 255-length field's wrap contained
                                  ; to the width byte instead of carrying into
                                  ; the row-count byte set just below)
    mov esi, [kbd_tile_pos]
    mov bh, 1                    ; one row
    call ClearScreenArea
    mov esi, [kbd_tile_pos]
    mov edx, [kbd_dest_ptr]
    lea eax, [ebp + edx]
    call PlaceString              ; out: EBX = GB-space cursor pos (post-terminator)
    mov byte [ebp + ebx], KBD_CURSOR_TILE
    ret

; ---------------------------------------------------------------------------
; .filter_char -- charset-class membership test.
; In:  AL = candidate byte (already known nonzero)
; Out: CF = 1 accept, CF = 0 reject. Clobbers EBX/ECX/EDX.
; ---------------------------------------------------------------------------
.filter_char:
    movzx ebx, byte [kbd_charset_class]
    cmp ebx, CHARSET_FREE
    je .filter_accept
    mov edx, [KbdCharsetTable + ebx * 4]
    movzx ecx, byte [edx]        ; range count
    inc edx
.filter_loop:
    test ecx, ecx
    jz .filter_reject
    cmp al, [edx]
    jb .filter_next
    cmp al, [edx + 1]
    ja .filter_next
    jmp .filter_accept
.filter_next:
    add edx, 2
    dec ecx
    jmp .filter_loop
.filter_reject:
    clc
    ret
.filter_accept:
    stc
    ret
