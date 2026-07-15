; text.asm — PlaceString, TextCommandProcessor, and PrintText.
;
; Source files:  home/text.asm, home/window.asm
; Translated to: x86 NASM, 32-bit protected mode, EBP = GB memory base.
;
; TWO-LEVEL TEXT ENGINE
; ─────────────────────
; Level 1 — TextCommandProcessor (home/text.asm:TextCommandProcessor)
;   Reads a stream of TX_* command bytes. Commands: TX_START writes a string,
;   TX_BOX draws a border, TX_MOVE repositions the cursor, TX_FAR recursively
;   splices another stream inline, TX_END terminates.
;   Register mapping: ESI = command stream ptr (HL) — a FLAT LINEAR pointer, since
;   the port's text streams live in program-image .data, outside GB space; EBX =
;   cursor (BC), EBP-relative as on the GB. See the TextCommandProcessor header.
;
; Level 2 — PlaceString (home/text.asm:PlaceString)
;   Renders a '@'-terminated charmap string into the tile buffer.
;   Register mapping: EDX = source ptr (DE, EBP-relative), ESI = cursor (HL),
;   EBX = cursor at terminator on return (BC). EDX points at '@' on return.
;   Control codes $00–$5F are dispatched via the dictionary table.
;
; Inline substitution strings (POKe, TM, PC, …) live in .data (DS-relative)
; and are written by place_flat_str, which bypasses the EBP-relative read.
; By contrast, player/rival names live in WRAM (EBP-relative) and are read
; via the normal [EBP+EDX] mechanism in a local substitution loop.
;
; Build: nasm -f coff -I include/ -I . -o text.o text.asm

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"

extern DelayFrame

; ---------------------------------------------------------------------------
; TX_* command bytes (home/macros/scripts/text.asm const_def block)
; ---------------------------------------------------------------------------
TX_START            equ 0x00
TX_RAM              equ 0x01
TX_BCD              equ 0x02
TX_MOVE             equ 0x03
TX_BOX              equ 0x04
TX_LOW              equ 0x05
TX_PROMPT_BUTTON    equ 0x06
TX_SCROLL           equ 0x07
TX_START_ASM        equ 0x08
TX_NUM              equ 0x09
TX_PAUSE            equ 0x0A
TX_SOUND_GET_ITEM_1 equ 0x0B
TX_DOTS             equ 0x0C
TX_WAIT_BUTTON      equ 0x0D
TX_SOUND_PDEX_RATE  equ 0x0E    ; first sound-range command
TX_FAR              equ 0x17
TX_END              equ 0x50    ; text_end / '@' string terminator

; ---------------------------------------------------------------------------
; Charmap control codes ($00–$5F, from constants/charmap.asm)
; ---------------------------------------------------------------------------
CHAR_NULL       equ 0x00   ; <NULL>    debug error
CHAR_PAGE       equ 0x49   ; <PAGE>    Pokedex page break
CHAR_PKMN       equ 0x4A   ; <PKMN>    prints "PK MN"
CHAR_CONT_      equ 0x4B   ; <_CONT>   scroll + pause (_ContText)
CHAR_SCROLL     equ 0x4C   ; <SCROLL>  scroll no pause (_ContTextNoPause)
CHAR_NEXT       equ 0x4E   ; <NEXT>    next line
CHAR_LINE       equ 0x4F   ; <LINE>    second dialogue line
CHAR_TERMINATOR equ 0x50   ; '@'       end of string
CHAR_PARA       equ 0x51   ; <PARA>    paragraph break
CHAR_PLAYER     equ 0x52   ; <PLAYER>  player name
CHAR_RIVAL      equ 0x53   ; <RIVAL>   rival name
CHAR_POKE       equ 0x54   ; '#'       prints "POKe"
CHAR_CONT       equ 0x55   ; <CONT>    scroll + wait
CHAR_DOTS       equ 0x56   ; <...>     six dots ("......")
CHAR_DONE       equ 0x57   ; <DONE>    terminate text engine
CHAR_PROMPT     equ 0x58   ; <PROMPT>  show arrow, wait button
CHAR_TARGET     equ 0x59   ; <TARGET>  battle target name
CHAR_USER       equ 0x5A   ; <USER>    battle user name
CHAR_PC         equ 0x5B   ; <PC>      prints "PC"
CHAR_TM         equ 0x5C   ; <TM>      prints "TM"
CHAR_TRAINER    equ 0x5D   ; <TRAINER> prints "TRAINER"
CHAR_ROCKET     equ 0x5E   ; <ROCKET>  prints "ROCKET"
CHAR_DEXEND     equ 0x5F   ; <DEXEND>  prints "."

CHAR_FIRST_GLYPH equ 0x60  ; first renderable character

BIT_LEFT_ALIGN  equ 6      ; PrintNumber flag bit (constants/text_constants.asm)

SCREEN_W_TILES  equ 20     ; SCREEN_WIDTH in tile units

; Message box geometry (data/text_boxes.asm: MESSAGE_BOX entry = 0,12,19,17)
; Top-left coord(0,12), lower-right coord(19,17): width=20, height=6,
; interior width=18, interior height=4 (B=4, C=18 for TextBoxBorder).
MSG_BOX_ESI     equ W_TILEMAP + 12 * SCREEN_W_TILES   ; tile buf at (0,12)
MSG_BOX_HEIGHT  equ 4      ; interior rows (B)
MSG_BOX_WIDTH   equ 18     ; interior columns (C)
MSG_TEXT_EBX    equ W_TILEMAP + 14 * SCREEN_W_TILES + 1  ; cursor at (1,14)

; Box-drawing tile codes (constants/charmap.asm $79-$7F)
BOX_TL   equ 0x79
BOX_H    equ 0x7A
BOX_TR   equ 0x7B
BOX_V    equ 0x7C
BOX_BL   equ 0x7D
BOX_BR   equ 0x7E
TILE_SPC equ 0x7F   ; space

; PAD bits (from joypad.asm)
PAD_A_BIT   equ 0
PAD_B_BIT   equ 1

; --- M1.2 (control-code fidelity) local constants ---------------------------
; The following are defined locally to keep this patch self-contained. ROOT: the
; two hardware/gfx constants ideally belong in dos_port/include/gb_memmap.inc:
;   BIT_PAGE_CHAR_IS_NEXT               equ 3       ; hUILayoutFlags bit (constants/gfx_constants.asm)
;   H_CLEAR_LETTER_PRINTING_DELAY_FLAGS equ 0xFFF9  ; hClearLetterPrintingDelayFlags (ram/hram.asm)
BIT_PAGE_CHAR_IS_NEXT               equ 3          ; hUILayoutFlags bit 3 → treat <PAGE> as <NEXT>
H_CLEAR_LETTER_PRINTING_DELAY_FLAGS equ 0xFFF9     ; hClearLetterPrintingDelayFlags (byte before hUILayoutFlags)
LINK_STATE_BATTLING                 equ 0x04       ; wLinkState value (constants/serial_constants.asm); in gb_constants.inc too
CHAR_DOTS_GLYPH                     equ 0x75       ; '…' single ellipsis glyph (constants/charmap.asm)

; ---------------------------------------------------------------------------
; Exports
; ---------------------------------------------------------------------------
global TextBoxBorder
global PlaceString
global PlaceNextChar
global PrintLetterDelay
global TextCommandProcessor
global text_msgbox              ; → the active msgbox projection record (msgbox.inc)
global msgbox_dialog            ; the overworld dialog projection (this file, .data)
global sync_dialog_window
extern HandleDownArrowBlinkTiming   ; canonical def in home/window.asm (Wave 4/M4.3)
global place_flat_str
global text_row_stride
global text_line2
global text_prompt_hook
global text_arrow_pos

; ---------------------------------------------------------------------------
; External
; ---------------------------------------------------------------------------
extern pad_buttons   ; joypad.asm — button held state (bit 0=A, bit 1=B)
extern set_single_window   ; src/ppu/ppu.asm — define g_windows[] as one descriptor
extern g_window_count      ; src/ppu/ppu.asm — unified window list count (open flag)
extern g_bg_whiteout       ; src/ppu/ppu.asm — set by full-takeover menus (party/dex/…)
extern PrintNumber         ; src/home/print_num.asm — TX_NUM (text_decimal)
extern PrintBCDNumber      ; src/home/print_bcd.asm — TX_BCD (text_bcd / money)

; ---------------------------------------------------------------------------
; .data — inline substitution strings in DS (flat, not EBP-relative).
; These are read by place_flat_str, not through [EBP+n].
; All strings use charmap.asm codes; '$50' = CHAR_TERMINATOR.
; ---------------------------------------------------------------------------
section .data
align 4

%include "assets/home_text_runtime_strings.inc"

; One-byte sentinel used by CHAR_DONE to signal TX_END to TextCommandProcessor
done_sentinel: db TX_END

; Runtime row stride (tiles per W_TILEMAP row) for the ONE text engine. Default 20
; (the GB/overworld screen). The battle layout projects the GB viewport into the
; 40-wide full-screen canvas, so it sets this to 40 — there is no separate
; "wide" engine (see docs/current_plan_battle_pret_alignment.md Stage 0.5).
align 4
text_row_stride: dd 20
; <LINE> ($4F) target tile-buffer offset (the box's 2nd text line). Default = the
; overworld message box (1,16); the battle box sets its own (PrintBattleText).
text_line2:      dd (W_TILEMAP + 16 * SCREEN_W_TILES + 1)
; <PROMPT> ($58) display hook (0 = overworld window scroll via manual_text_scroll).
; The battle path installs a routine that draws the ▼ at text_arrow_pos in W_TILEMAP,
; waits for A/B, and erases it. text_arrow_pos = that ▼ tile-buffer offset.
text_prompt_hook: dd 0
text_arrow_pos:   dd 0

; M1.2: when nonzero, manual_text_scroll suppresses the ▼ advance arrow (used by
; TX_WAIT_BUTTON, and by TX_PROMPT_BUTTON when in a link battle — pret shows no
; arrow in those cases). manual_text_scroll resets it to 0 before it returns.
mts_hide_arrow:   db 0

; Pokedex flavor-text mode. When nonzero, the dialog-window helpers
; (sync_dialog_window / manual_text_scroll) mirror the FULL 20×18 pokédex page
; (rows 0-17 → GB_TILEMAP1) and keep the page's own full-screen window, instead
; of the dialog-box copy (rows 12-17 → window 0-5) + bottom-dialog window swap.
; Without this the pokédex DATA page's flavor print hijacks the window into a
; 6-row dialog box at the bottom — the "only bottom half renders" bug. The
; pokédex flavor routine sets it around its TextCommandProcessor call.
global g_dex_flavor_active
g_dex_flavor_active: db 0
; ▼ advance arrow position for the full-page pokédex window: pret ldcoord_a 18,16
POKEDEX_ARROW_TILEMAP_OFFSET equ 16 * TILEMAP_W + 18
; …and the same (18,16) in the stride-20 W_TILEMAP scratch — where pret's
; PageChar actually writes it (`ld a,'▼' / ldcoord_a 18,16` into wTileMap) and
; WaitForTextScrollButtonPress blinks it. The port used to place the arrow ONLY
; in the GB_TILEMAP1 window copy, so the compared scratch byte read ' ' while
; the screen showed a ▼ — caught by the pokedex_entry golden (F-14 class).
POKEDEX_ARROW_SCRATCH_OFFSET equ W_TILEMAP + 16 * SCREEN_W_TILES + 18

; ---------------------------------------------------------------------------
; .text
; ---------------------------------------------------------------------------
section .text

; ---------------------------------------------------------------------------
; place_flat_str — write '@'-terminated DS string to tile buffer at ESI.
;
; Reads from EAX (flat DS address), writes glyphs ($60+) to [EBP+ESI].
; Control codes below CHAR_FIRST_GLYPH in the substitution strings are skipped.
; In:  EAX = flat DS ptr to '@'-terminated string
;      ESI = tile buffer write position (EBP-relative)
; Out: EAX advanced past '@', ESI advanced past last written glyph.
;      ECX clobbered.
; ---------------------------------------------------------------------------
place_flat_str:
.loop:
    movzx ecx, byte [eax]
    cmp cl, CHAR_TERMINATOR
    je .done
    cmp cl, CHAR_FIRST_GLYPH
    jb .skip
    mov [ebp + esi], cl
    inc esi
.skip:
    inc eax
    jmp .loop
.done:
    ret

; ---------------------------------------------------------------------------
; TextBoxBorder — draw a BL-wide x BH-tall bordered text box at ESI.
;
; Source: home/text.asm:TextBoxBorder
; In:  ESI = top-left tile-buffer offset (HL, EBP-relative)
;      BL  = interior width (C), BH = interior height (B)
; Out: ESI preserved. EBX preserved (BH/BL unchanged on return).
;      EDI clobbered.
; ---------------------------------------------------------------------------
TextBoxBorder:
%ifdef DEBUG_ASSERT_SCRATCH
    cmp dword [text_row_stride], 20
    je .assert_stride_ok
    cmp dword [text_row_stride], SCREEN_WIDTH
    jne .assert_bad_stride
.assert_stride_ok:
    jmp .assert_stride_done
.assert_bad_stride:
    int3                                ; scratch owner published an invalid stride
    jmp .assert_bad_stride
.assert_stride_done:
%endif
    push esi
    push ebx

    movzx ecx, bl       ; ECX = interior width
    movzx edx, bh       ; EDX = interior height (rows of middle)
    lea edi, [ebp + esi]

    ; top row: box_tl + box_h*width + box_tr
    mov byte [edi], BOX_TL
    call .fill_h
    mov byte [edi + ecx + 1], BOX_TR
    add edi, [text_row_stride]

    ; middle rows: box_v + space*width + box_v (EDX times)
.mid:
    mov byte [edi], BOX_V
    push eax
    mov al, TILE_SPC
    call .fill_chars
    pop eax
    mov byte [edi + ecx + 1], BOX_V
    add edi, [text_row_stride]
    dec edx
    jnz .mid

    ; bottom row: box_bl + box_h*width + box_br
    mov byte [edi], BOX_BL
    call .fill_h
    mov byte [edi + ecx + 1], BOX_BR

    pop ebx
    pop esi
    ret

.fill_h:
    push eax
    mov al, BOX_H
    call .fill_chars
    pop eax
    ret

; Fill ECX copies of AL starting at [edi+1]. Preserves EDI and ECX.
.fill_chars:
    push ecx
    push edi
    inc edi
.fc_loop:
    mov [edi], al
    inc edi
    dec ecx
    jnz .fc_loop
    pop edi
    pop ecx
    ret

; ---------------------------------------------------------------------------
; PrintLetterDelay — wait per-character delay based on the text speed setting.
; Pret ref: home/print_text.asm:PrintLetterDelay.
;
; Reads delay frame count from wOptions bits 3-0 (TEXT_DELAY_FAST/MEDIUM/SLOW = 1/3/5).
; Exits early if A or B is held. No-op if BIT_TEXT_DELAY is not set in
; wLetterPrintingDelayFlags (TextCommandProcessor sets it) or if BIT_NO_TEXT_DELAY
; is set in wStatusFlags5 (cutscenes, auto-scroll).
; All registers preserved.
; ---------------------------------------------------------------------------
PrintLetterDelay:
    push eax
    push ecx
    movzx eax, byte [ebp + W_STATUS_FLAGS_5]
    test al, (1 << BIT_NO_TEXT_DELAY)          ; cutscene/auto-scroll: skip delay
    jnz .done
    movzx eax, byte [ebp + W_LETTER_PRINTING_DELAY]
    test al, (1 << BIT_TEXT_DELAY)             ; delay enabled by TextCommandProcessor?
    jz .done
    call sync_dialog_window                    ; mirror latest char to window before first frame
    movzx ecx, byte [ebp + H_JOY_HELD]
    test cl, PAD_A | PAD_B
    jnz .one_frame                             ; button held: skip to one-frame exit
    test al, (1 << BIT_FAST_TEXT_DELAY)        ; use wOptions speed or fixed 1-frame?
    jz .one_frame
    movzx ecx, byte [ebp + W_OPTIONS]
    and cl, TEXT_DELAY_MASK                    ; isolate speed bits (1, 3, or 5)
    jz .done                                   ; speed 0: instant (not used in practice)
    jmp .count_down
.one_frame:
    mov cl, 1
.count_down:
    call DelayFrame                            ; renders frame + updates H_JOY_HELD
    movzx eax, byte [ebp + H_JOY_HELD]
    test al, PAD_A | PAD_B
    jnz .done                                  ; button held: abort remaining delay
    dec cl
    jnz .count_down
.done:
    pop ecx
    pop eax
    ret

; HandleDownArrowBlinkTiming now lives canonically in home/window.asm (Wave 4/M4.3,
; faithful two-phase pret port). This file's single-phase copy was removed to
; de-duplicate; the internal caller below resolves the extern.

; ---------------------------------------------------------------------------
; manual_text_scroll — copy current dialog box to window layer and wait for A/B.
;
; Copies wTileMap rows 12-17 (6 rows × 20 tiles) to GB_TILEMAP1 rows 0-5, pads
; cols 20-31 with TILE_SPC, sets H_WY=152 / IO_WX=87 so the window renders centered,
; places the ▼ advance arrow (tile CHAR_DOWN_ARROW at row 4, col 18 of GB_TILEMAP1),
; and polls until A or B is pressed (release-then-press cycle to avoid sticky input).
; Called at CHAR_PARA, CHAR_CONT, CHAR_DONE control codes inside PlaceString.
; All registers preserved (blink state saved/restored around pushad/popad).
; ---------------------------------------------------------------------------
; ---------------------------------------------------------------------------
; text_pause — the "▼, wait for A/B" step of <_CONT>/<CONT>/<PARA>.
;
; Same dispatch <PROMPT> already uses (.handle_prompt): [text_prompt_hook] = 0 is
; the overworld display (manual_text_scroll hijacks the window layer to show the
; dialog rows); non-zero is the owning screen's own wait (battle: BattlePromptWait,
; which blinks the ▼ at [text_arrow_pos] in W_TILEMAP). Calling manual_text_scroll
; unconditionally opened the overworld dialog window on top of the battle screen.
; All registers preserved.
; ---------------------------------------------------------------------------
text_pause:
    pushad
    mov eax, [text_prompt_hook]
    test eax, eax
    jz .tp_overworld
    call eax
    jmp .tp_done
.tp_overworld:
    call manual_text_scroll
.tp_done:
    popad
    ret

manual_text_scroll:
    ; Save existing blink state so nested/sequential dialogs don't clobber each other.
    movzx eax, byte [ebp + H_DOWN_ARROW_COUNT1]
    push eax
    movzx eax, byte [ebp + H_DOWN_ARROW_COUNT2]
    push eax
    pushad
    cmp byte [g_dex_flavor_active], 0
    jne .dex_flavor_page                    ; pokédex: full page, no window hijack
    ; Copy wTileMap rows 12-17 to GB_TILEMAP1 rows 0-5.
    ; wTileMap rows: 20 tiles wide (SCREEN_W_TILES).
    ; GB_TILEMAP1 rows: 32 tiles wide (TILEMAP_W) — pad cols 20-31 with TILE_SPC.
    mov ecx, 6
    lea esi, [ebp + W_TILEMAP + 12 * SCREEN_W_TILES]
    lea edi, [ebp + GB_TILEMAP1]
.copy_row:
    push ecx
    push edi
    mov ecx, SCREEN_W_TILES
    rep movsb
    mov al, TILE_SPC
    mov ecx, TILEMAP_W - SCREEN_W_TILES     ; 12 filler tiles
    rep stosb
    pop edi
    pop ecx
    add edi, TILEMAP_W                      ; next GB_TILEMAP1 row
    dec ecx
    jnz .copy_row
    ; Enable window at bottom of 320×200 viewport; center 160px box in 320px width.
    ; PROJ overworld-ui: GB(0,19) 20x6 --(dialog, X+0/centered, WX-7=80)--> wx=87 wy=152 clip=160 max_y=200
    mov eax, 87                  ; wx (WX-7=80 → x=80..239 centers 160px in 320px)
    mov ebx, 152                 ; wy (bottom of 320×200 viewport)
    mov ecx, SCREEN_W            ; clip_w = 160px (20-tile dialog content)
    mov edx, RENDER_H            ; max_y = 200 (draws to bottom)
    mov esi, GB_TILEMAP1         ; dialog box source tilemap
    xor edi, edi                 ; start_row = 0
    call set_single_window       ; also mirrors wy→H_WY (sync_dialog_window flag), wx→IO_WX
    ; Place ▼ arrow and init blink counters.
    ; Pret ref: home/joypad2.asm:WaitForTextScrollButtonPress places coord(18,16).
    ; M1.2: TX_WAIT_BUTTON / in-battle TX_PROMPT_BUTTON suppress the ▼ (mts_hide_arrow).
    mov esi, GB_TILEMAP1 + DIALOG_ARROW_TILEMAP_OFFSET
    cmp byte [mts_hide_arrow], 0
    jne .mts_no_arrow
    mov byte [ebp + esi], CHAR_DOWN_ARROW
.mts_no_arrow:
    mov byte [ebp + H_DOWN_ARROW_COUNT1], ARROW_ON_FRAMES
    mov byte [ebp + H_DOWN_ARROW_COUNT2], 1
    ; Release cycle: wait until A/B is no longer held (avoids re-triggering on held button).
.mts_release:
    call DelayFrame
    test byte [ebp + H_JOY_HELD], PAD_A | PAD_B
    jnz .mts_release
    ; Press cycle: wait for A or B; blink ▼ each frame.
.mts_press:
    call DelayFrame
    cmp byte [mts_hide_arrow], 0
    jne .mts_no_blink
    call HandleDownArrowBlinkTiming
.mts_no_blink:
    test byte [ebp + H_JOY_HELD], PAD_A | PAD_B
    jz .mts_press
    ; Clear arrow from window tilemap.
    mov byte [ebp + GB_TILEMAP1 + DIALOG_ARROW_TILEMAP_OFFSET], TILE_SPC
    popad
    ; Restore blink counters.
    pop eax
    mov [ebp + H_DOWN_ARROW_COUNT2], al
    pop eax
    mov [ebp + H_DOWN_ARROW_COUNT1], al
    mov byte [mts_hide_arrow], 0        ; M1.2: re-arm arrow for the next caller
    ret

; --- pokédex flavor page-break (<PAGE>): full-page window, no dialog hijack ---
.dex_flavor_page:
    ; The ▼ is already in the W_TILEMAP scratch at (18,16) — .handle_page wrote
    ; it there as pret's PageChar does — so the full-page mirror carries it into
    ; the window. The wait then BLINKS the scratch cell (pret: ManualTextScroll →
    ; WaitForTextScrollButtonPress blinking hlcoord 18,16 of wTileMap) and
    ; re-mirrors that one cell so the display blinks too.
    call dex_flavor_full_mirror          ; show the current full page in the window
    mov byte [ebp + H_DOWN_ARROW_COUNT1], ARROW_ON_FRAMES
    mov byte [ebp + H_DOWN_ARROW_COUNT2], 1
.dfp_release:                            ; wait for A/B release (avoid sticky input)
    call DelayFrame
    test byte [ebp + H_JOY_HELD], PAD_A | PAD_B
    jnz .dfp_release
.dfp_press:                              ; wait for a fresh A/B press
    call DelayFrame
    mov esi, POKEDEX_ARROW_SCRATCH_OFFSET
    call HandleDownArrowBlinkTiming      ; blink the compared scratch byte…
    mov al, [ebp + POKEDEX_ARROW_SCRATCH_OFFSET]
    mov [ebp + GB_TILEMAP1 + POKEDEX_ARROW_TILEMAP_OFFSET], al  ; …and show it
    test byte [ebp + H_JOY_HELD], PAD_A | PAD_B
    jz .dfp_press
    ; the scratch cell is cleared by .handle_page's 7×18 page clear right after
    ; this returns (pret: PageChar's ClearScreenArea does the same)
    mov byte [ebp + GB_TILEMAP1 + POKEDEX_ARROW_TILEMAP_OFFSET], TILE_SPC
    popad
    pop eax
    mov [ebp + H_DOWN_ARROW_COUNT2], al
    pop eax
    mov [ebp + H_DOWN_ARROW_COUNT1], al
    mov byte [mts_hide_arrow], 0
    ret

; ---------------------------------------------------------------------------
; scroll_text_up — scroll tile rows 14-16 up one row and clear row 16 interior.
;
; Copies W_TILEMAP rows 14,15,16 → rows 13,14,15 (60 bytes), then clears
; the 18-column interior of row 16 with TILE_SPC.
; Called TWICE in succession (by handle_cont and handle_scroll_cont) to move
; the bottom text line from row 16 to the top text position row 14:
;   call 1: row16→row15, row15→row14, row14→row13; clear row16
;   call 2: row16(blank)→row15, row15(old16)→row14, row14(old15)→row13; clear row16
;   net result: old row16 is now at row14, rows 15-16 are blank.
; Pret ref: home/text.asm:ScrollTextUpOneLine (called twice per _ContText).
; Syncs W_TILEMAP to GB_TILEMAP1 and delays 2 frames per call so the
; scroll is visible in the window layer.
; All registers preserved.
; ---------------------------------------------------------------------------
scroll_text_up:
    pushad
    ; Geometry is derived, not hardcoded: [text_line2] is the box's 2nd text line
    ; (col 1 of it) and [text_row_stride] the tilemap row stride — the same two
    ; knobs <LINE> uses. Hardcoding row 16 / stride 20 printed the battle's
    ; <CONT> continuation at canvas (8,1) instead of inside the battle box.
    mov ecx, [text_row_stride]
    mov edx, [text_line2]                ; GB offset of (1, line2)
    mov edi, edx
    sub edi, ecx
    sub edi, ecx
    sub edi, ecx                         ; dst = line2 - 3 rows
    mov esi, edx
    sub esi, ecx
    sub esi, ecx                         ; src = line2 - 2 rows
    mov ebx, 3                           ; 3 text rows move up one row each
.stu_row:
    push esi
    push edi
    push ecx
    lea esi, [ebp + esi]
    lea edi, [ebp + edi]
    mov ecx, MSG_BOX_WIDTH               ; 18 interior columns
    rep movsb                            ; dst < src → forward copy is safe
    pop ecx
    pop edi
    pop esi
    add esi, ecx
    add edi, ecx
    dec ebx
    jnz .stu_row
    ; Clear the line-2 interior it just duplicated upward
    lea edi, [ebp + edx]
    mov al, TILE_SPC
    mov ecx, MSG_BOX_WIDTH
    rep stosb
    ; Sync to window layer then delay so the scroll is visible
    call sync_dialog_window
    call DelayFrame
    call DelayFrame
    popad
    ret

; ---------------------------------------------------------------------------
; sync_dialog_window — mirror W_TILEMAP dialog rows to the window tilemap.
;
; Copies W_TILEMAP rows 12-17 (6 × 20 tiles) into GB_TILEMAP1 rows 0-5
; (32-tile stride), padding cols 20-31 with TILE_SPC.
; Called from PrintText (after TextBoxBorder, before first character) and from
; PrintLetterDelay (before the delay frames) so each character becomes visible
; as it is typed rather than all at once at the end.
; No-op when the dialog window is not open (H_WY == RENDER_H).
; All registers preserved.
; ---------------------------------------------------------------------------
sync_dialog_window:
    push eax
    movzx eax, byte [ebp + H_WY]
    cmp al, RENDER_H
    je .skip
    cmp byte [g_dex_flavor_active], 0
    jne .full_page                       ; pokédex flavor: mirror the whole page
    ; A full-takeover menu (g_bg_whiteout=1) owns GB_TILEMAP1 rows 0-5 for its own
    ; windows (e.g. the party-menu panel). The overworld dialog's char-reveal mirror
    ; must NOT paint the dialog rows (W_TILEMAP 12-17) over that panel. Only the
    ; map-overlay dialog (g_bg_whiteout=0) wants this copy. Without the gate, a stray
    ; PrintText/PrintLetterDelay during such a menu (H_WY left != RENDER_H by the
    ; menu's own set_single_window) duplicates the menu's message box into rows 0-5.
    cmp byte [g_bg_whiteout], 0
    jne .skip
    push ecx
    push esi
    push edi
    mov ecx, 6                            ; 6 dialog rows (rows 12-17)
    lea esi, [ebp + MSG_BOX_ESI]          ; W_TILEMAP + 12*SCREEN_W_TILES
    lea edi, [ebp + GB_TILEMAP1]
.sdw_row:
    push ecx
    push edi
    mov ecx, SCREEN_W_TILES               ; 20 visible tiles per row
    rep movsb
    mov al, TILE_SPC
    mov ecx, TILEMAP_W - SCREEN_W_TILES   ; pad cols 20-31
    rep stosb
    pop edi
    pop ecx
    add edi, TILEMAP_W                    ; advance to next window tilemap row
    dec ecx
    jnz .sdw_row
    pop edi
    pop esi
    pop ecx
.skip:
    pop eax
    ret
.full_page:
    call dex_flavor_full_mirror
    pop eax
    ret

; ---------------------------------------------------------------------------
; dex_flavor_full_mirror — copy the full 20×18 stride-20 scratch (rows 0-17)
; into GB_TILEMAP1 rows 0-17 (32-tile stride, cols 20-31 padded with TILE_SPC).
; The pokédex DATA page's window shows GB_TILEMAP1 rows 0-17 full-screen, so this
; is the pokédex analog of sync_dialog_window's dialog copy. All regs preserved.
; ---------------------------------------------------------------------------
dex_flavor_full_mirror:
    push eax
    push ebx
    push ecx
    push esi
    push edi
    xor ebx, ebx                         ; row 0..17
.dffm_row:
    mov esi, ebx
    imul esi, esi, SCREEN_W_TILES
    lea esi, [ebp + esi + W_TILEMAP]
    mov edi, ebx
    shl edi, 5                           ; ×32
    lea edi, [ebp + edi + GB_TILEMAP1]
    mov ecx, SCREEN_W_TILES              ; 20 visible tiles
    rep movsb
    mov al, TILE_SPC
    mov ecx, TILEMAP_W - SCREEN_W_TILES  ; pad cols 20-31
    rep stosb
    inc ebx
    cmp ebx, 18
    jb .dffm_row
    pop edi
    pop esi
    pop ecx
    pop ebx
    pop eax
    ret

; ---------------------------------------------------------------------------
; PlaceString — render '@'-terminated charmap string at tile buffer position.
;
; Source: home/text.asm:PlaceString / PlaceNextChar
; In:  EAX = source string ptr — FLAT-LINEAR (not EBP-biased). Pass a `.data` label
;            directly, or `lea eax,[ebp+offset]` for a GB-memory string. This matches
;            place_flat_str / the old WidePlaceString and the DJGPP flat model. (pret
;            passes it in DE as a GB address; the flat model collapses GB address =
;            ebp+offset = a linear pointer, so callers hand us the linear pointer.)
;      ESI = tile buffer write position (EBP-relative GB offset, HL)
; Out: EBX = tile buf position at '@' terminator (BC = pret's end coord)
;      ESI = restored to line start (HL restored by pop on return)
;      EDX = flat-linear pointer at the '@' terminator
;      EAX clobbered
; ---------------------------------------------------------------------------
PlaceString:
%ifdef DEBUG_ASSERT_SCRATCH
    cmp dword [text_row_stride], 20
    je .assert_stride_ok
    cmp dword [text_row_stride], SCREEN_WIDTH
    jne .assert_bad_stride
.assert_stride_ok:
    jmp .assert_stride_done
.assert_bad_stride:
    int3                                ; PlaceString cannot safely walk this scratch
    jmp .assert_bad_stride
.assert_stride_done:
%endif
    mov edx, eax                ; EAX (flat src) → EDX (internal walking pointer)
    push esi                    ; SM83: push hl (save line start)

PlaceNextChar:
    movzx eax, byte [edx]       ; source is a FLAT-LINEAR pointer (no EBP bias)

    ; --- Terminator '@' ($50) ---
    cmp al, CHAR_TERMINATOR
    jne .not_term
    mov ebx, esi               ; BC = current cursor
    pop esi                    ; restore HL = line start
    ret

    ; --- <NEXT> ($4E): advance one or two rows ---
.not_term:
    cmp al, CHAR_NEXT
    jne .not_next
    pop esi                    ; restore line start
    add esi, [text_row_stride] ; +1 row (stride-aware: 20 overworld / 40 battle)
    test byte [ebp + H_UI_LAYOUT_FLAGS], 1 << BIT_SINGLE_SPACED_LINES
    jnz .next_push
    add esi, [text_row_stride]  ; double-spaced: +2 rows total
.next_push:
    push esi
    jmp .advance

    ; --- <LINE> ($4F): cursor to (1,16) ---
.not_next:
    cmp al, CHAR_LINE
    jne .not_line
    pop esi
    mov esi, [text_line2]              ; box 2nd text line (overworld default / battle-set)
    push esi
    jmp .advance

    ; --- Control codes $00–$5F (excluding $4E/$4F/$50 already handled) ---
.not_line:
    cmp al, CHAR_FIRST_GLYPH
    jae .glyph                 ; $60+ = renderable glyph

    ; Dispatch control codes
    cmp al, CHAR_NULL
    je .handle_null            ; $00
    cmp al, CHAR_PAGE
    je .handle_page            ; $49 — Pokedex page break (or <NEXT>)
    cmp al, CHAR_PKMN
    je .handle_pkmn            ; $4A
    cmp al, CHAR_CONT_
    je .handle_cont_scroll     ; $4B — _ContText (arrow+wait, then scroll)
    cmp al, CHAR_SCROLL
    je .handle_scroll          ; $4C — _ContTextNoPause (scroll only)
    cmp al, CHAR_PARA
    je .handle_para            ; $51
    cmp al, CHAR_PLAYER
    je .handle_player          ; $52
    cmp al, CHAR_RIVAL
    je .handle_rival           ; $53
    cmp al, CHAR_POKE
    je .handle_poke            ; $54
    cmp al, CHAR_CONT
    je .handle_cont            ; $55
    cmp al, CHAR_DOTS
    je .handle_dots6           ; $56
    cmp al, CHAR_DONE
    je .handle_done            ; $57
    cmp al, CHAR_PROMPT
    je .handle_prompt          ; $58
    cmp al, CHAR_TARGET
    je .handle_target          ; $59
    cmp al, CHAR_USER
    je .handle_user            ; $5A
    cmp al, CHAR_PC
    je .handle_pc              ; $5B
    cmp al, CHAR_TM
    je .handle_tm              ; $5C
    cmp al, CHAR_TRAINER
    je .handle_trainer         ; $5D
    cmp al, CHAR_ROCKET
    je .handle_rocket          ; $5E
    cmp al, CHAR_DEXEND
    je .handle_dexend          ; $5F
    jmp .advance               ; unknown control code: skip

    ; --- Renderable glyph ---
.glyph:
    mov [ebp + esi], al
    inc esi
    call PrintLetterDelay
    jmp .advance

.advance:
    inc edx
    jmp PlaceNextChar

; ── Control code handlers ──────────────────────────────────────────────────

.handle_null:
    ; <NULL> ($00): debug error terminator — stop silently
    mov ebx, esi
    pop esi
    ret

.handle_page:
    ; <PAGE> ($49): PageChar. If BIT_PAGE_CHAR_IS_NEXT is set in hUILayoutFlags,
    ; behave exactly like <NEXT>; otherwise (Pokedex full-page break) wait for input,
    ; clear the 7×18 text area at coord(1,10), pause ~20 frames, and re-home the
    ; cursor at coord(1,11).  Pret ref: home/text.asm:PageChar.
    test byte [ebp + H_UI_LAYOUT_FLAGS], 1 << BIT_PAGE_CHAR_IS_NEXT
    jz .page_full
    mov al, CHAR_NEXT
    jmp .not_term                    ; process as <NEXT> (pret: jp PlaceNextChar.NotTerminator)
.page_full:
    ; pret PageChar: `ld a,'▼' / ldcoord_a 18,16` — into wTileMap itself, BEFORE
    ; the wait; the window mirror below then carries it. (The port used to poke
    ; the arrow only into GB_TILEMAP1 — see POKEDEX_ARROW_SCRATCH_OFFSET.)
    mov byte [ebp + POKEDEX_ARROW_SCRATCH_OFFSET], CHAR_DOWN_ARROW
    call manual_text_scroll          ; ▼ + wait (pret: ProtectedDelay3 + ManualTextScroll)
    ; ClearScreenArea b=7 rows, c=18 cols at hlcoord(1,10). EDX is the live source
    ; ptr (DE) — preserve it; use it as the row counter only inside this block.
    push eax
    push ecx
    push edx
    push edi
    mov edx, 7                       ; 7 rows
    lea edi, [ebp + W_TILEMAP + 10 * SCREEN_W_TILES + 1]
.page_clear_row:
    push edi
    mov al, TILE_SPC
    mov ecx, 18                      ; 18 interior columns
    rep stosb
    pop edi
    add edi, SCREEN_W_TILES
    dec edx
    jnz .page_clear_row
    pop edi
    pop edx
    pop ecx
    pop eax
    ; DelayFrames c=20. Bounded DelayFrame loop — the pret set-hFrameCounter-and-spin
    ; idiom would deadlock until Wave-2/M2.1 adds the hFrameCounter decrementer.
    push ecx
    mov ecx, 20
.page_wait:
    call DelayFrame
    dec ecx
    jnz .page_wait
    pop ecx
    ; re-home cursor at coord(1,11) (pret: pop hl / hlcoord 1,11 / push hl)
    pop esi
    mov esi, W_TILEMAP + 11 * SCREEN_W_TILES + 1
    push esi
    jmp .advance

.handle_pkmn:
    ; <PKMN> ($4A): prints "PK MN" glyphs ($E1,$E2)
    push eax
    mov eax, str_pkmn
    call place_flat_str
    pop eax
    jmp .advance

.handle_cont_scroll:
    ; <_CONT> ($4B): _ContText — show the ▼, wait for A/B, THEN scroll up two lines.
    ; Pret ref: home/text.asm:_ContText (falls through into _ContTextNoPause).
    call text_pause                  ; ▼ + wait; (pret places arrow, ProtectedDelay3, ManualTextScroll)
    ; fall through into the scroll
.handle_scroll:
    ; <SCROLL> ($4C): _ContTextNoPause — scroll up two lines, cursor to (1,16), no wait.
    ; Pret ref: home/text.asm:_ContTextNoPause.
    call scroll_text_up
    call scroll_text_up
    pop esi
    mov esi, [text_line2]            ; pret's (1,16) — the box's 2nd text line
    push esi
    jmp .advance

.handle_para:
    ; <PARA> ($51): paragraph break — wait for input, clear text area, reposition at (1,14).
    ; Pret ref: home/text.asm:Paragraph — ManualTextScroll, ClearScreenArea 4×18 at (1,13).
    call text_pause
    ; Clear all 4 interior rows (pret's rows 13-16, cols 1-18) with TILE_SPC —
    ; addressed off [text_line2]/[text_row_stride], as scroll_text_up is.
    pushad
    mov ecx, [text_row_stride]
    mov edx, [text_line2]                ; (1, line2) = pret's (1,16)
    mov ebx, edx
    sub ebx, ecx
    sub ebx, ecx
    sub ebx, ecx                         ; (1, line2 - 3 rows) = pret's (1,13)
    mov esi, 4                           ; 4 interior rows
.para_row:
    lea edi, [ebp + ebx]
    push ecx
    mov al, TILE_SPC
    mov ecx, MSG_BOX_WIDTH
    rep stosb
    pop ecx
    add ebx, ecx
    dec esi
    jnz .para_row
    popad
    call sync_dialog_window              ; show cleared box immediately
    pop esi
    mov esi, [text_line2]
    sub esi, [text_row_stride]
    sub esi, [text_row_stride]           ; pret's (1,14) — the box's 1st text line
    push esi
    jmp .advance

.handle_player:
    ; <PLAYER> ($52): insert player name from wPlayerName (EBP+W_PLAYER_NAME)
    push edx
    mov edx, W_PLAYER_NAME
.player_loop:
    movzx eax, byte [ebp + edx]
    cmp al, CHAR_TERMINATOR
    je .player_done
    cmp al, CHAR_FIRST_GLYPH
    jb .player_next
    mov [ebp + esi], al
    inc esi
.player_next:
    inc edx
    jmp .player_loop
.player_done:
    pop edx
    jmp .advance

.handle_rival:
    ; <RIVAL> ($53): insert rival name from wRivalName (EBP+W_RIVAL_NAME)
    push edx
    mov edx, W_RIVAL_NAME
.rival_loop:
    movzx eax, byte [ebp + edx]
    cmp al, CHAR_TERMINATOR
    je .rival_done
    cmp al, CHAR_FIRST_GLYPH
    jb .rival_next
    mov [ebp + esi], al
    inc esi
.rival_next:
    inc edx
    jmp .rival_loop
.rival_done:
    pop edx
    jmp .advance

.handle_target:
    ; <TARGET> ($59): the move TARGET's name. Pret PlaceMoveTargetsName: hWhoseTurn ^ 1.
    mov al, [ebp + hWhoseTurn]
    xor al, 1
    jmp .place_battler_name
.handle_user:
    ; <USER> ($5A): the move USER's name. Pret PlaceMoveUsersName: hWhoseTurn.
    mov al, [ebp + hWhoseTurn]
.place_battler_name:
    ; AL == 0 → player side: wBattleMonNick (no prefix).
    ; AL != 0 → enemy side: "Enemy " + wEnemyMonNick.  (home/text.asm:.place)
    push edx                        ; save outer command-string ptr
    test al, al
    jnz .battler_enemy
    mov edx, wBattleMonNick
    jmp .battler_copy
.battler_enemy:
    push eax
    mov eax, str_enemy              ; "Enemy " (flat DS prefix)
    call place_flat_str             ; writes glyphs at [ebp+esi], advances ESI
    pop eax
    mov edx, wEnemyMonNick
.battler_copy:
    movzx eax, byte [ebp + edx]
    cmp al, CHAR_TERMINATOR
    je .battler_done
    cmp al, CHAR_FIRST_GLYPH
    jb .battler_next
    mov [ebp + esi], al
    inc esi
.battler_next:
    inc edx
    jmp .battler_copy
.battler_done:
    pop edx                         ; restore outer string ptr
    jmp .advance

.handle_poke:
    ; '#' ($54): prints "POKe"
    push eax
    mov eax, str_poke
    call place_flat_str
    pop eax
    jmp .advance

.handle_cont:
    ; <CONT> ($55): ContText — scroll two lines, reposition at (1,16)
    call text_pause
    call scroll_text_up
    call scroll_text_up
    pop esi
    mov esi, [text_line2]            ; pret's (1,16) — the box's 2nd text line
    push esi
    jmp .advance

.handle_dots6:
    ; <......> ($56): prints "......"
    push eax
    mov eax, str_dots6
    call place_flat_str
    pop eax
    jmp .advance

.handle_done:
    ; <DONE> ($57): end the text command stream. Restore the PlaceString stack
    ; frame and return EDX = a FLAT-LINEAR pointer at the TX_END sentinel, so that
    ; .cmd_start's `mov esi,edx; sub esi,ebp; inc esi` lands ESI = DONE_SENTINEL_WRAM
    ; +1 (a GB offset whose byte is TX_END, set by text_engine_init) → TCP exits.
    pop esi                         ; restore line start
    lea edx, [ebp + DONE_SENTINEL_WRAM]   ; flat ptr to the TX_END sentinel
    ret

.handle_prompt:
    ; <PROMPT> ($58): pret PromptText — draw ▼, wait for A/B, erase, then TERMINATE
    ; the text box (PromptText falls through to DoneText). The display context is
    ; [text_prompt_hook]: 0 = overworld window scroll; non-zero = battle routine that
    ; draws the ▼ at text_arrow_pos in W_TILEMAP, waits, and erases it.
    mov eax, [text_prompt_hook]
    test eax, eax
    jz .prompt_overworld
    call eax
    jmp .prompt_done
.prompt_overworld:
    call manual_text_scroll
.prompt_done:
    pop esi                            ; restore line start, terminate like <DONE>
    lea edx, [ebp + DONE_SENTINEL_WRAM]
    ret

.handle_pc:
    push eax
    mov eax, str_pc
    call place_flat_str
    pop eax
    jmp .advance

.handle_tm:
    push eax
    mov eax, str_tm
    call place_flat_str
    pop eax
    jmp .advance

.handle_trainer:
    push eax
    mov eax, str_trainer
    call place_flat_str
    pop eax
    jmp .advance

.handle_rocket:
    push eax
    mov eax, str_rocket
    call place_flat_str
    pop eax
    jmp .advance

.handle_dexend:
    ; <DEXEND> ($5F): prints "." and terminates PlaceString
    push eax
    mov eax, str_dot
    call place_flat_str
    pop eax
    mov ebx, esi
    pop esi
    ret

; ---------------------------------------------------------------------------
; text_engine_init — write TX_END sentinel to GB memory for CHAR_DONE.
;
; Must be called once at startup after EBP is established.
; Writes two TX_END bytes at DONE_SENTINEL_WRAM so <DONE> terminates cleanly.
; In:  EBP = GB memory base.
; Out: all registers preserved.
; ---------------------------------------------------------------------------
DONE_SENTINEL_WRAM  equ GB_WRAM0 + 0x0F0   ; two bytes reserved for <DONE> sentinel

global text_engine_init

text_engine_init:
    push eax
    mov al, TX_END
    mov byte [ebp + DONE_SENTINEL_WRAM],     al
    mov byte [ebp + DONE_SENTINEL_WRAM + 1], al
    pop eax
    ret

; ---------------------------------------------------------------------------
; TextCommandProcessor — execute a TX_* command stream.
;
; Source: home/text.asm:TextCommandProcessor / NextTextCommand
;
; DEVIATION(flat-pointer): the STREAM pointer is a FLAT LINEAR address, not a GB
; offset. On the GB, text lives in addressable ROM, so pret's HL is just a GB
; address. In the port every text stream is flat program-image .data, outside the
; 64 KB emulated GB space — an EBP-relative HL cannot name one at all. Making the
; stream pointer flat is what lets a caller pass a `.data` label directly (and is
; what makes TX_FAR's 32-bit label operand work).
;
; Everything else keeps pret's GB-space meaning:
;   - the CURSOR (EBX/BC) is a tilemap offset → EBP-relative;
;   - command OPERANDS that name memory (TX_RAM/TX_NUM/TX_BCD sources, TX_MOVE/
;     TX_BOX destinations) are genuine GB addresses → EBP-relative, as in pret.
; A stream that lives in GB space (battle composes one in WRAM) is passed as
; `lea esi, [ebp + addr]`.
;
; In:  ESI = command stream ptr (HL) — FLAT LINEAR
;      EBX = tile buffer cursor (BC, EBP-relative)
; Out: ESI = past the TX_END byte (flat)
;      EBX = cursor at last position written
; Clobbers: EAX, ECX, EDX.
; ---------------------------------------------------------------------------
TextCommandProcessor:
    push eax
    push ecx
    push edx
    ; Pret ref: home/text.asm:TextCommandProcessor — save delay flags, enable delay.
    ; PrintLetterDelay gates on BIT_TEXT_DELAY; TextCommandProcessor sets it for the
    ; duration of this text session and restores the original value at TX_END.
    movzx eax, byte [ebp + W_LETTER_PRINTING_DELAY]
    push eax                                    ; save original wLetterPrintingDelayFlags
    or al, (1 << BIT_TEXT_DELAY)                ; set BIT_TEXT_DELAY for this session
    ; Pret ref: home/text.asm:TextCommandProcessor — XOR in hClearLetterPrintingDelayFlags
    ; so a caller can force-clear delay bits for the duration of the text stream.
    movzx ecx, byte [ebp + H_CLEAR_LETTER_PRINTING_DELAY_FLAGS]
    xor al, cl
    mov [ebp + W_LETTER_PRINTING_DELAY], al

.next_cmd:
    movzx eax, byte [esi]           ; stream is FLAT (see header)
    inc esi                         ; ESI now points to operands / next command

    cmp al, TX_END                  ; $50
    je .done

    cmp al, TX_FAR                  ; $17: far-bank text — skip 3 bytes in flat model
    je .cmd_far

    cmp al, TX_SOUND_PDEX_RATE      ; $0E+: sound command — no audio yet
    jae .cmd_skip0                  ; zero-byte operand skip

    cmp al, TX_START
    je .cmd_start
    cmp al, TX_RAM
    je .cmd_ram
    cmp al, TX_BCD
    je .cmd_bcd
    cmp al, TX_MOVE
    je .cmd_move
    cmp al, TX_BOX
    je .cmd_box
    cmp al, TX_LOW
    je .cmd_low
    cmp al, TX_PROMPT_BUTTON
    je .cmd_prompt_btn
    cmp al, TX_SCROLL
    je .cmd_scroll
    cmp al, TX_START_ASM
    je .cmd_asm
    cmp al, TX_NUM
    je .cmd_num
    cmp al, TX_PAUSE
    je .cmd_pause
    ; TX_SOUND_GET_ITEM_1 ($0B): TODO-HW: audio
    cmp al, TX_SOUND_GET_ITEM_1
    je .cmd_skip0
    cmp al, TX_DOTS
    je .cmd_dots
    cmp al, TX_WAIT_BUTTON
    je .cmd_wait_btn
    jmp .next_cmd                   ; unknown command: skip

.done:
    pop eax
    mov [ebp + W_LETTER_PRINTING_DELAY], al    ; restore saved wLetterPrintingDelayFlags
    pop edx
    pop ecx
    pop eax
    ret

; --- TX_START ($00): render '@'-terminated string at cursor ---
.cmd_start:
    ; ESI = source string (flat ptr into the command stream), EBX = cursor
    mov eax, esi           ; PlaceString takes a flat-linear source in EAX
    mov esi, ebx           ; ESI (HL) = cursor
    call PlaceString
    ; After PlaceString: EBX = cursor at '@', EDX = flat-linear ptr to '@'.
    ; <DONE>/<PROMPT> instead return EDX = flat ptr to the TX_END sentinel
    ; (text_engine_init), so the same two instructions terminate the stream.
    lea esi, [edx + 1]     ; ESI = past '@' = next command (flat)
    jmp .next_cmd

; --- TX_FAR ($17): far-bank text — faithful recursive splice. ---
; Source: home/text.asm:TextCommand_FAR (pret/pokeyellow).
; Pret reads operands addr_lo, addr_hi, bank; saves the current ROM bank; switches
; to the far bank; sets HL = [addr_hi:addr_lo]; recursively runs TextCommandProcessor
; on that pointer; then restores HL/bank and continues the outer stream. The far
; text is spliced INLINE: the recursion advances the cursor (BC/EBX) and that
; position is carried forward, so pret never restores the cursor here — nor do we.
;
; DEVIATION(flat-pointer): the operand is ONE 32-bit FLAT pointer, not pret's
; 3-byte addr_lo/addr_hi/bank triple — a bank:offset pair cannot name a flat
; .data label. This is what the `text_far` macro emits (include/gb_text.inc:141,
; `db TX_FAR / dd %1`), so the operand is 4 bytes wide and the resume point is
; ESI+4. Banks are a no-op in the flat model (src/home/bankswitch.asm elides the
; rROMB write); with no bank byte in the stream there is nothing to switch to, so
; pret's push/pop af bank save-restore is dropped with it — it would save and
; restore the same value.
;
; This was previously WRONG, not merely deviant: it read 3 bytes and combined them
; into a GB offset, so it computed a garbage pointer AND desynced the outer stream
; by one byte. It never fired because the only producers are unlinked
; (text_script.asm is check-only; gen_battle_text.py inlines far text instead of
; emitting the command) — see docs/current_plan_text_engine.md finding T-1.
.cmd_far:
    ; ESI -> operand: dd <flat target>. EBX = current cursor (carried forward).
    mov  eax, [esi]                     ; EAX = far stream ptr (flat, 32-bit)
    add  esi, 4                         ; ESI = resume point in the outer stream
    push esi                            ; save outer stream ptr        (pret: push hl)
    mov  esi, eax                       ; ESI (HL) = far stream ptr
    call TextCommandProcessor           ; recurse: render far text; advances EBX cursor
    pop  esi                            ; restore outer stream ptr      (pret: pop hl)
    jmp  .next_cmd

; --- TX_MOVE ($03): set cursor to new tile-buffer address ---
.cmd_move:
    movzx ebx, byte [esi]          ; lo byte of new cursor addr
    inc esi
    movzx ecx, byte [esi]          ; hi byte
    inc esi
    shl ecx, 8
    or  ebx, ecx                   ; EBX = new cursor (BC in SM83)
    jmp .next_cmd

; --- TX_BOX ($04): draw a text box ---
.cmd_box:
    ; Operands: addr_lo, addr_hi, b_height, c_width
    movzx eax, byte [esi]          ; lo of tile buf destination
    inc esi
    movzx ecx, byte [esi]          ; hi
    inc esi
    shl ecx, 8
    or  eax, ecx                   ; EAX = tile buf dest (GB addr — EBP-relative)
    movzx ecx, byte [esi]          ; B = height
    inc esi
    movzx edx, byte [esi]          ; C = width
    inc esi
    shl ecx, 8
    or  ecx, edx                   ; ECX[15:8]=height, ECX[7:0]=width = EBX for TextBoxBorder
    push esi                        ; save stream ptr
    push ebx                        ; save cursor
    mov esi, eax                    ; ESI = tile buf pos
    mov ebx, ecx                    ; BH = height, BL = width
    call TextBoxBorder
    pop ebx                         ; restore cursor
    pop esi                         ; restore stream ptr
    jmp .next_cmd

; --- TX_LOW ($05): cursor to coord(1,16) ---
.cmd_low:
    mov ebx, W_TILEMAP + 16 * SCREEN_W_TILES + 1
    jmp .next_cmd

; --- TX_PROMPT_BUTTON ($06): show ▼ and wait for A/B; in a link battle, defer to
;     TX_WAIT_BUTTON (no arrow). Pret ref: home/text.asm:TextCommand_PROMPT_BUTTON. ---
.cmd_prompt_btn:
    movzx eax, byte [ebp + wLinkState]
    cmp al, LINK_STATE_BATTLING
    je .cmd_wait_btn                    ; in battle: no arrow (fall to WAIT_BUTTON path)
    call manual_text_scroll             ; shows ▼, blinks it, waits for A/B, erases it
    jmp .next_cmd

; --- TX_WAIT_BUTTON ($0D): wait for A/B, NO arrow. Pret ref: TextCommand_WAIT_BUTTON. ---
.cmd_wait_btn:
    mov byte [mts_hide_arrow], 1        ; suppress the ▼ for this wait
    call manual_text_scroll
    jmp .next_cmd

; --- TX_PAUSE ($0A): if A or B is already held, continue immediately; otherwise
;     pause ~30 frames. Pret ref: home/text.asm:TextCommand_PAUSE. No operand. ---
.cmd_pause:
    movzx eax, byte [ebp + H_JOY_HELD]
    test al, PAD_A | PAD_B
    jnz .next_cmd
    ; DelayFrames c=30. Bounded DelayFrame loop (the set-hFrameCounter-and-spin idiom
    ; would deadlock until Wave-2/M2.1 adds the hFrameCounter decrementer).
    mov ecx, 30
.pause_wait:
    call DelayFrame
    dec ecx
    jnz .pause_wait
    jmp .next_cmd

; --- TX_DOTS ($0C): print N '…' glyphs, pausing ~10 frames per glyph unless A/B is
;     held. Operand: 1-byte glyph count. Pret ref: home/text.asm:TextCommand_DOTS.
;     Cursor is EBX (BC); it advances by the glyph count, matching pret. ---
.cmd_dots:
    movzx edx, byte [esi]               ; EDX = glyph count (pret d)
    inc esi                             ; past the 1-byte count operand
.dots_loop:
    mov byte [ebp + ebx], CHAR_DOTS_GLYPH   ; write '…' at the cursor
    inc ebx
    movzx eax, byte [ebp + H_JOY_HELD]
    test al, PAD_A | PAD_B
    jnz .dots_next                      ; button held: skip this glyph's delay
    mov ecx, 10                         ; DelayFrames c=10 (bounded loop; see M2.1 note above)
.dots_delay:
    call DelayFrame
    dec ecx
    jnz .dots_delay
.dots_next:
    dec edx
    jnz .dots_loop
    jmp .next_cmd

; --- TX_SCROLL ($07): scroll text up two lines ---
.cmd_scroll:
    call scroll_text_up
    call scroll_text_up
    mov ebx, W_TILEMAP + 16 * SCREEN_W_TILES + 1
    jmp .next_cmd

; --- TX_RAM ($01): write an '@'-terminated string from a RAM address ---
; Pret ref: home/text.asm:TextCommand_RAM. Operands: addr_lo, addr_hi (little-
; endian WRAM pointer, e.g. wBattleMonNick). PlaceString it at the cursor.
.cmd_ram:
    movzx edx, byte [esi]          ; lo of RAM source addr
    inc esi
    movzx eax, byte [esi]          ; hi
    inc esi
    shl eax, 8
    or  edx, eax                   ; EDX = RAM source string addr
    push esi                       ; save command-stream ptr
    mov esi, ebx                   ; ESI (HL) = cursor
    lea eax, [ebp + edx]           ; flat-linear source ptr (RAM addr → linear)
    call PlaceString               ; EBX = end cursor, ESI = line start, EDX = '@'
    pop esi                        ; restore stream ptr
    jmp .next_cmd

; --- TX_NUM ($09 / text_decimal): print a decimal number ---
; Pret ref: home/text.asm:TextCommand_NUM. Operands: addr_lo, addr_hi, format,
; where format = (byte-count << 4) | digit-count. LEFT_ALIGN is forced on.
.cmd_num:
    movzx edx, byte [esi]          ; lo of value addr
    inc esi
    movzx eax, byte [esi]          ; hi
    inc esi
    shl eax, 8
    or  edx, eax                   ; EDX (DE) = value source addr (GB addr)
    movzx eax, byte [esi]          ; AL = format byte
    inc esi
    push esi                       ; save stream ptr
    mov esi, ebx                   ; ESI (HL) = cursor
    mov bl, al
    and bl, 0x0F                   ; BL = digit count
    shr al, 4                      ; AL = byte count
    or  al, (1 << BIT_LEFT_ALIGN)  ; force left-align (TextCommand_NUM)
    mov bh, al                     ; BH = flags | byte count
    call PrintNumber               ; advances ESI past the field
    mov ebx, esi                   ; cursor := end
    pop esi                        ; restore stream ptr
    jmp .next_cmd

; --- TX_BCD ($02 / text_bcd): print a BCD number (money) ---
; Pret ref: home/text.asm:TextCommand_BCD. Operands: addr_lo, addr_hi, flags|len.
.cmd_bcd:
    movzx edx, byte [esi]          ; lo of BCD addr
    inc esi
    movzx eax, byte [esi]          ; hi
    inc esi
    shl eax, 8
    or  edx, eax                   ; EDX (DE) = BCD source addr (GB addr)
    movzx eax, byte [esi]          ; AL = flags | length (C)
    inc esi
    push esi                       ; save stream ptr
    mov esi, ebx                   ; ESI (HL) = cursor
    mov bl, al                     ; BL = flags | length
    call PrintBCDNumber            ; advances ESI
    mov ebx, esi                   ; cursor := end
    pop esi                        ; restore stream ptr
    jmp .next_cmd

; --- TX_START_ASM ($08 / text_asm): run the inline code spliced into the stream ---
; Pret ref: home/text.asm:TextCommand_START_ASM —
;   pop hl / ld de, NextTextCommand / push de / jp hl
; ESI already points PAST the command byte, i.e. straight at the hook's code: the
; text_asm macro splices real instructions into the stream, so the stream IS the
; code. In the flat port that is simpler than on the GB, not harder — one address
; space, no bank to restore — so `jmp esi` is the whole of pret's `jp hl`.
;
; This used to be `je .cmd_skip0` under the comment "can't translate inline ASM;
; skip silently". Both halves were false, and skipping is not harmless: it does not
; skip the hook, it feeds the hook's opcode bytes to the renderer as glyphs, AND it
; swallows the `jmp TextScriptEnd` that TERMINATES the message — so the processor
; runs on into whatever follows the stream. Live consequence (2026-07-13): STRENGTH
; printed "<MON> used" and then ran straight into the NEXT message.
;
; Contract, exactly pret's: the resume point is pushed as the hook's return address,
; so a hook that `ret`s continues the stream at whatever ESI it leaves. That is what
; makes TextScriptEnd (overworld_text.asm: `mov esi, TextScriptEndingText / ret`)
; end the message — it returns onto a lone $50. TextCommandProcessor's saved
; EAX/ECX/EDX + delay flags stay on the stack below and unwind normally at .done.
.cmd_asm:
    push .next_cmd                  ; pret: ld de, NextTextCommand / push de
    jmp esi                         ; pret: jp hl

; --- Operand-skip helpers ---
.cmd_skip3:
    inc esi
.cmd_skip2:
    inc esi
.cmd_skip1:
    inc esi
.cmd_skip0:
    jmp .next_cmd

; ---------------------------------------------------------------------------
; msgbox_dialog — the OVERWORLD dialog projection (msgbox.inc).
;
; This is what used to be a second printer (`PrintText_Overworld`, a forked name
; for pret's PrintText). It is not code: it is the placement. pret's PrintText
; draws MESSAGE_BOX at GB (0,12) and types at (1,14) on the live tilemap; the port
; draws that same box into the GB-shaped stride-20 scratch and shows it through
; the dialog window, at a placement HAND-TUNED for the wider screen — not a
; mechanical GB→canvas mapping, which is why the numbers below are not derivable
; from the GB coords. The window stays open until CheckNPCInteraction hides it.
;
; PROJ overworld-ui: GB(0,19) 20x6 --(dialog, X+0/centered, WX-7=80)--> wx=87 wy=152 clip=160 max_y=200
; ---------------------------------------------------------------------------
section .data
align 4
msgbox_dialog:
    dd 20                       ; MB_STRIDE       — GB-shaped scratch
    dd MSG_BOX_ESI              ; MB_BOX_OFS      — (0,12)
    dd MSG_BOX_WIDTH            ; MB_BOX_W        — 18 interior columns
    dd MSG_BOX_HEIGHT           ; MB_BOX_H        — 4 interior rows
    dd MSG_TEXT_EBX             ; MB_LINE1        — (1,14)
    dd W_TILEMAP + 16 * SCREEN_W_TILES + 1  ; MB_LINE2 — <LINE> at (1,16)
    dd 0                        ; MB_ARROW        — no ▼ of its own
    dd 0                        ; MB_PROMPT       — caller waits (manual_text_scroll)
    dd 87                       ; MB_WIN_WX
    dd 152                      ; MB_WIN_WY
    dd SCREEN_W                 ; MB_WIN_CLIP
    dd RENDER_H                 ; MB_WIN_MAXY
    dd GB_TILEMAP1              ; MB_WIN_TILEMAP  — shown through the dialog window
    dd 0                        ; MB_WIN_STARTROW

; text_msgbox — the active projection. Defaults to the overworld dialog, i.e. to
; pret's PrintText semantics: a screen that says nothing gets the message box.
; A screen that must not have its window list collapsed (battle, and the
; full-screen menus) points this at msgbox_centered (core.asm) instead.
text_msgbox: dd msgbox_dialog

section .text
