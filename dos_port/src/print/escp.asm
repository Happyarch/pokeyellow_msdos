; ===========================================================================
; escp.asm — ESC/P grayscale / 24-pin / 9-pin page emitter for GB Printer.
;
; Renders accumulated 2bpp bands from g_print_band_buf to an ESC/P dot-matrix
; raster stream and outputs via lpt_dos.asm (Lpt_Open, Lpt_Write, Lpt_Close).
; See docs/current_plan_printer.md.
; ===========================================================================

bits 32

global Escp_PrintPage

extern Lpt_Open                          ; src/print/lpt_dos.asm
extern Lpt_Write                         ; src/print/lpt_dos.asm
extern Lpt_Close                         ; src/print/lpt_dos.asm

extern g_cfg_prn_9pin                    ; src/print/print_dev.asm
extern g_print_band_count                ; src/print/print_dev.asm
extern g_print_band_buf                  ; src/print/print_dev.asm
extern g_print_margins                   ; src/print/print_dev.asm
extern g_print_palette                   ; src/print/print_dev.asm
extern g_print_exposure                  ; src/print/print_dev.asm
extern g_print_status_flags              ; src/print/print_dev.asm

PRN_COLS_24PIN                  equ 320          ; 160 GB pixels * 2
PRN_PASS_HEIGHT_24PIN           equ 12           ; 12 GB pixel rows = 24 dots high
PRN_PASS_BYTES_24PIN            equ PRN_COLS_24PIN * 3 ; 960 bytes per pass

section .data

escp_init_seq:
    db 0x1B, 0x40                        ; ESC @   (Initialize printer)
    db 0x1B, 0x55, 0x01                  ; ESC U 1 (Unidirectional mode)
    db 0x1B, 0x33, 0x18                  ; ESC 3 24 (Line spacing 24/180")
ESCP_INIT_SEQ_LEN equ $ - escp_init_seq

escp_margin_cmd:
    db 0x1B, 0x4A, 0x00                  ; ESC J n (Feed n/180")

escp_pass_hdr_24pin:
    db 0x1B, 0x2A, 39, 0x40, 0x01        ; ESC * 39 (180 dpi 24-pin), 320 columns (0x0140)
ESCP_PASS_HDR_LEN equ $ - escp_pass_hdr_24pin

escp_crlf:
    db 0x0D, 0x0A                        ; CR LF

escp_ff:
    db 0x0C                              ; FF (Form Feed)

section .bss

g_escp_pass_buf:    resb PRN_PASS_BYTES_24PIN

section .text

; ---------------------------------------------------------------------------
; Escp_PrintPage — main entry to render accumulated bands to ESC/P printer
; ---------------------------------------------------------------------------
Escp_PrintPage:
    pushad

    mov eax, [g_print_band_count]
    test eax, eax
    jz .done                             ; no data to print

    call Lpt_Open
    jnc .open_ok
    or byte [g_print_status_flags], 0xFF ; device error
    popad
    ret

.open_ok:
    ; 1. Send Init sequence
    mov esi, escp_init_seq
    mov ecx, ESCP_INIT_SEQ_LEN
    call Lpt_Write

    ; 2. Top Margin
    movzx eax, byte [g_print_margins]
    shr eax, 4                           ; top margin (0-15)
    test eax, eax
    jz .skip_top_margin
    shl eax, 4                           ; scale by 16 lines (16/180")
    mov [escp_margin_cmd + 2], al
    mov esi, escp_margin_cmd
    mov ecx, 3
    call Lpt_Write
.skip_top_margin:

    ; 3. Render Passes
    ; Total GB pixel rows = g_print_band_count * 16
    mov eax, [g_print_band_count]
    shl eax, 4                           ; EAX = total_gb_rows (16 to 144)

    xor ebp, ebp                         ; EBP = current_gb_row_start (0, 12, 24, ...)
.pass_loop:
    cmp ebp, eax
    jae .passes_done

    ; Render one 24-dot (12 GB rows) pass starting at row EBP
    push eax
    call .RenderPass24Pin
    pop eax

    ; Send pass header (ESC * 39 320 0)
    mov esi, escp_pass_hdr_24pin
    mov ecx, ESCP_PASS_HDR_LEN
    call Lpt_Write

    ; Send 960 bytes of raster data
    mov esi, g_escp_pass_buf
    mov ecx, PRN_PASS_BYTES_24PIN
    call Lpt_Write

    ; Send CR LF
    mov esi, escp_crlf
    mov ecx, 2
    call Lpt_Write

    add ebp, PRN_PASS_HEIGHT_24PIN
    jmp .pass_loop

.passes_done:
    ; 4. Bottom Margin
    movzx eax, byte [g_print_margins]
    and eax, 0x0F                        ; bottom margin (0-15)
    test eax, eax
    jz .skip_bottom_margin
    shl eax, 4                           ; scale by 16 lines
    mov [escp_margin_cmd + 2], al
    mov esi, escp_margin_cmd
    mov ecx, 3
    call Lpt_Write
.skip_bottom_margin:

    ; 5. Form Feed (eject page)
    mov esi, escp_ff
    mov ecx, 1
    call Lpt_Write

    call Lpt_Close

.done:
    popad
    ret

; ---------------------------------------------------------------------------
; .RenderPass24Pin — render 12 GB pixel rows [EBP .. EBP+11] to g_escp_pass_buf
; Input: EBP = starting GB row
; Fills: g_escp_pass_buf with 320 columns * 3 bytes (960 bytes)
; ---------------------------------------------------------------------------
.RenderPass24Pin:
    pushad

    ; Clear pass buffer
    lea edi, [g_escp_pass_buf]
    mov ecx, PRN_PASS_BYTES_24PIN / 4
    xor eax, eax
    rep stosd

    ; For each GB pixel column X from 0 to 159:
    xor ecx, ecx                         ; ECX = gb_x (0..159)
.col_loop:
    cmp ecx, 160
    jae .pass_complete

    push ecx

    ; Group 0: GB rows [EBP+0 .. EBP+3] -> Byte 0 (dots 0..7)
    xor edx, edx                         ; EDX = r (0..3)
    xor ebx, ebx                         ; BL = col0_byte, BH = col1_byte
.grp0_loop:
    lea eax, [ebp + edx]                 ; row = EBP + r
    push ecx
    push edx
    push ebx
    call .GetPixelShade                  ; EAX = pixel shade (0..3) at (ECX, EAX)
    pop ebx
    pop edx
    pop ecx

    call .ApplyDitherBits8               ; updates BL / BH
    inc edx
    cmp edx, 4
    jb .grp0_loop

    ; Store Byte 0 for col0 and col1
    mov eax, [esp]                       ; get gb_x
    shl eax, 1                           ; col0 = gb_x * 2
    imul eax, eax, 3                     ; offset in pass_buf = col0 * 3
    mov [g_escp_pass_buf + eax + 0], bl
    mov [g_escp_pass_buf + eax + 3], bh

    ; Group 1: GB rows [EBP+4 .. EBP+7] -> Byte 1 (dots 8..15)
    xor edx, edx                         ; r = 0..3
    xor ebx, ebx
.grp1_loop:
    lea eax, [ebp + edx + 4]             ; row = EBP + 4 + r
    push ecx
    push edx
    push ebx
    call .GetPixelShade
    pop ebx
    pop edx
    pop ecx

    call .ApplyDitherBits8
    inc edx
    cmp edx, 4
    jb .grp1_loop

    mov eax, [esp]
    shl eax, 1
    imul eax, eax, 3
    mov [g_escp_pass_buf + eax + 1], bl
    mov [g_escp_pass_buf + eax + 4], bh

    ; Group 2: GB rows [EBP+8 .. EBP+11] -> Byte 2 (dots 16..23)
    xor edx, edx                         ; r = 0..3
    xor ebx, ebx
.grp2_loop:
    lea eax, [ebp + edx + 8]             ; row = EBP + 8 + r
    push ecx
    push edx
    push ebx
    call .GetPixelShade
    pop ebx
    pop edx
    pop ecx

    call .ApplyDitherBits8
    inc edx
    cmp edx, 4
    jb .grp2_loop

    mov eax, [esp]
    shl eax, 1
    imul eax, eax, 3
    mov [g_escp_pass_buf + eax + 2], bl
    mov [g_escp_pass_buf + eax + 5], bh

    pop ecx
    inc ecx
    jmp .col_loop

.pass_complete:
    popad
    ret

; ---------------------------------------------------------------------------
; .GetPixelShade — read 2bpp pixel shade at GB coordinate (ECX=x, EAX=y)
; Returns: EAX = mapped shade (0=white, 1=light, 2=dark, 3=black)
; ---------------------------------------------------------------------------
.GetPixelShade:
    push ebx
    push edx
    push esi
    push edi

    mov edx, [g_print_band_count]
    shl edx, 4                           ; total rows
    cmp eax, edx
    jae .out_of_bounds

    ; Band index = y / 16
    mov edx, eax
    shr edx, 4                           ; EDX = band_idx (0..8)
    imul edx, edx, 640                   ; band_offset

    ; Inside band (32 rows of tiles = 2 tile rows * 20 tiles = 40 tiles):
    mov ebx, eax
    and ebx, 0x0F                        ; row_in_band = y % 16 (0..15)
    shr ebx, 3                           ; tile_row = row_in_band / 8 (0 or 1)
    imul ebx, ebx, 20

    mov edi, ecx
    shr edi, 3                           ; tile_col = x / 8 (0..19)
    add ebx, edi                         ; ebx = tile_idx (0..39)
    shl ebx, 4                           ; ebx = tile_offset in band (tile_idx * 16)

    ; row_in_tile = y % 8 (0..7)
    mov edi, eax
    and edi, 7                           ; row_in_tile (0..7)
    shl edi, 1                           ; * 2 (plane 0 at +0, plane 1 at +1)

    ; Memory address in g_print_band_buf: g_print_band_buf + band_offset + tile_offset + row_in_tile
    add edx, ebx
    add edx, edi
    lea esi, [g_print_band_buf + edx]

    ; Pixel bit index = 7 - (x % 8)
    mov ebx, ecx
    and ebx, 7
    mov cl, 7
    sub cl, bl                           ; CL = bit shift (0..7)

    ; Read plane 0 (bit 0) and plane 1 (bit 1)
    movzx eax, byte [esi]                ; plane 0
    shr eax, cl
    and eax, 1

    movzx ebx, byte [esi + 1]            ; plane 1
    shr ebx, cl
    and ebx, 1
    shl ebx, 1
    or eax, ebx                          ; EAX = raw shade (0..3)

    ; Map through palette: (g_print_palette >> (EAX * 2)) & 3
    mov cl, al
    shl cl, 1
    movzx ebx, byte [g_print_palette]
    shr ebx, cl
    and ebx, 3
    mov eax, ebx

    ; Exposure adjustment:
    movzx ebx, byte [g_print_exposure]
    cmp ebx, 0x20
    jbe .lighten
    cmp ebx, 0x60
    jae .darken
    jmp .done_shade

.lighten:
    test eax, eax
    jz .done_shade
    dec eax
    jmp .done_shade

.darken:
    cmp eax, 3
    jae .done_shade
    inc eax
    jmp .done_shade

.out_of_bounds:
    xor eax, eax
.done_shade:
    pop edi
    pop esi
    pop edx
    pop ebx
    ret

; ---------------------------------------------------------------------------
; .ApplyDitherBits8 — set 2x2 dither dots for GB row r (0..3) in 8-dot byte
; Inputs:
;   EAX = mapped shade (0..3)
;   EDX = r (0..3) inside group
;   BL  = col0 byte
;   BH  = col1 byte
; Outputs:
;   BL, BH updated with dots for row r
; ---------------------------------------------------------------------------
.ApplyDitherBits8:
    push ecx
    push edx

    ; Dot rows for GB row r:
    ; dot_y0 = 2*r, dot bit0 = 7 - 2*r
    ; dot_y1 = 2*r+1, dot bit1 = 6 - 2*r
    mov cl, 7
    shl dl, 1
    sub cl, dl                           ; CL = bit0 shift

    ; 2x2 Dither rule:
    ; Shade 0 (white): no dots
    ; Shade 1 (light): dot (0,0) ON
    ; Shade 2 (dark):  dots (0,0) and (1,1) ON
    ; Shade 3 (black): dots (0,0), (1,0), (0,1), (1,1) ON

    test eax, eax
    jz .dither_done

    cmp eax, 1
    je .dither_light
    cmp eax, 2
    je .dither_dark
    jmp .dither_black

.dither_light:
    ; Col 0, Row 0 dot ON
    mov dl, 1
    shl dl, cl
    or bl, dl
    jmp .dither_done

.dither_dark:
    ; Col 0, Row 0 dot ON
    mov dl, 1
    shl dl, cl
    or bl, dl
    ; Col 1, Row 1 dot ON
    dec cl
    mov dl, 1
    shl dl, cl
    or bh, dl
    jmp .dither_done

.dither_black:
    ; All 4 dots ON
    mov dl, 1
    shl dl, cl
    or bl, dl                            ; col 0 row 0
    or bh, dl                            ; col 1 row 0
    dec cl
    mov dl, 1
    shl dl, cl
    or bl, dl                            ; col 0 row 1
    or bh, dl                            ; col 1 row 1

.dither_done:
    pop edx
    pop ecx
    ret
