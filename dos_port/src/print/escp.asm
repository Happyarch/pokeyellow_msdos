; ===========================================================================
; escp.asm — ESC/P grayscale / 24-pin / 9-pin / CMY(K) color page emitter.
;
; Renders accumulated 2bpp bands from g_print_band_buf to an ESC/P dot-matrix
; raster stream and outputs via lpt_dos.asm (Lpt_Open, Lpt_Write, Lpt_Close).
; Supports monochrome 2x2 ordered dither and 4-pass CMY(K) color (/PRNCOLOR).
; The GB Printer packet exposure byte is used as brightness/contrast in the
; monochrome path and as saturation in the /PRNCOLOR path (see
; .GetPixelColorLevel). The Options "PRINT:" row feeds it unmodified through
; wPrinterSettings -> wPrinterSettingsTempCopy -> g_print_exposure.
; See docs/plans/printer.md.
; ===========================================================================

bits 32

global Escp_PrintPage

extern Lpt_Open                          ; src/print/lpt_dos.asm
extern Lpt_Write                         ; src/print/lpt_dos.asm
extern Lpt_Close                         ; src/print/lpt_dos.asm

extern g_cfg_prn_9pin                    ; src/print/print_dev.asm
extern g_cfg_prn_color                   ; src/print/print_dev.asm
extern g_print_band_count                ; src/print/print_dev.asm
extern g_print_band_buf                  ; src/print/print_dev.asm
extern g_print_pal_buf                   ; src/print/print_dev.asm
extern g_print_margins                   ; src/print/print_dev.asm
extern g_print_palette                   ; src/print/print_dev.asm
extern g_print_exposure                  ; src/print/print_dev.asm
extern g_print_status_flags              ; src/print/print_dev.asm
extern pal_rgb_table                     ; src/home/palettes.asm

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

escp_color_select:
    db 0x1B, 0x72, 0x00                  ; ESC r n (Select ribbon color: 0=K, 1=M, 2=C, 4=Y)

escp_cr:
    db 0x0D                              ; CR (Carriage Return without line feed)

escp_lf:
    db 0x0A                              ; LF (Line Feed)

escp_crlf:
    db 0x0D, 0x0A                        ; CR LF

escp_ff:
    db 0x0C                              ; FF (Form Feed)

color_plane_order:
    db 4, 1, 2, 0                        ; Yellow (4) -> Magenta (1) -> Cyan (2) -> Black (0)

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

    cmp dword [g_cfg_prn_color], 0
    jnz .color_pass_loop

.mono_pass_loop:
    cmp ebp, eax
    jae .passes_done

    push eax
    call .RenderPass24PinMono
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
    jmp .mono_pass_loop

.color_pass_loop:
    cmp ebp, eax
    jae .passes_done

    ; Color mode: 4 planes (Yellow, Magenta, Cyan, Black)
    push eax
    xor ebx, ebx                         ; EBX = plane index (0..3)
.plane_loop:
    movzx edx, byte [color_plane_order + ebx] ; EDX = plane ID (4, 1, 2, 0)
    push ebx
    push edx
    call .RenderPass24PinColor           ; EAX = non_zero_dot_count
    pop edx
    pop ebx

    test eax, eax
    jz .skip_empty_plane                 ; skip sending if plane is completely white

    ; Select color plane (ESC r <plane>)
    mov [escp_color_select + 2], dl
    mov esi, escp_color_select
    mov ecx, 3
    call Lpt_Write

    ; Send pass header (ESC * 39 320 0)
    mov esi, escp_pass_hdr_24pin
    mov ecx, ESCP_PASS_HDR_LEN
    call Lpt_Write

    ; Send 960 bytes of raster data
    mov esi, g_escp_pass_buf
    mov ecx, PRN_PASS_BYTES_24PIN
    call Lpt_Write

    ; Send CR (no LF) to return head for next color pass
    mov esi, escp_cr
    mov ecx, 1
    call Lpt_Write

.skip_empty_plane:
    inc ebx
    cmp ebx, 4
    jb .plane_loop

    ; Advance paper after all 4 planes (LF)
    mov esi, escp_lf
    mov ecx, 1
    call Lpt_Write

    pop eax
    add ebp, PRN_PASS_HEIGHT_24PIN
    jmp .color_pass_loop

.passes_done:
    ; If color mode, restore black ribbon at job end
    cmp dword [g_cfg_prn_color], 0
    jz .no_color_cleanup
    mov byte [escp_color_select + 2], 0
    mov esi, escp_color_select
    mov ecx, 3
    call Lpt_Write
.no_color_cleanup:

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
; .RenderPass24PinMono — render 12 GB pixel rows [EBP .. EBP+11] grayscale
; Input: EBP = starting GB row
; Fills: g_escp_pass_buf with 320 columns * 3 bytes (960 bytes)
; ---------------------------------------------------------------------------
.RenderPass24PinMono:
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
    call .GetPixelShadeMono              ; EAX = pixel shade (0..3) at (ECX, EAX)
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
    call .GetPixelShadeMono
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
    call .GetPixelShadeMono
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
; .RenderPass24PinColor — render 12 GB pixel rows for one color plane
; Inputs:
;   EBP = starting GB row
;   EDX = plane ID (4=Yellow, 1=Magenta, 2=Cyan, 0=Black)
; Returns: EAX = non-zero byte count (0 if empty plane)
; ---------------------------------------------------------------------------
.RenderPass24PinColor:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp

    mov [esp + 8], edx                   ; save plane ID in stack

    ; Clear pass buffer
    lea edi, [g_escp_pass_buf]
    mov ecx, PRN_PASS_BYTES_24PIN / 4
    xor eax, eax
    rep stosd

    xor esi, esi                         ; ESI = non-zero accumulator

    ; For each GB pixel column X from 0 to 159:
    xor ecx, ecx                         ; ECX = gb_x (0..159)
.color_col_loop:
    cmp ecx, 160
    jae .color_pass_complete

    push ecx

    ; Group 0: GB rows [EBP+0 .. EBP+3] -> Byte 0
    xor edx, edx                         ; r = 0..3
    xor ebx, ebx                         ; BL = col0, BH = col1
.cgrp0_loop:
    lea eax, [ebp + edx]
    push ecx
    push edx
    push ebx
    mov edx, [esp + 20]                  ; retrieve plane ID
    call .GetPixelColorLevel             ; EAX = dither level (0..3) for this plane
    pop ebx
    pop edx
    pop ecx

    call .ApplyDitherBits8
    inc edx
    cmp edx, 4
    jb .cgrp0_loop

    mov eax, [esp]
    shl eax, 1
    imul eax, eax, 3
    mov [g_escp_pass_buf + eax + 0], bl
    mov [g_escp_pass_buf + eax + 3], bh
    movzx edx, bl
    or esi, edx
    movzx edx, bh
    or esi, edx

    ; Group 1: GB rows [EBP+4 .. EBP+7] -> Byte 1
    xor edx, edx
    xor ebx, ebx
.cgrp1_loop:
    lea eax, [ebp + edx + 4]
    push ecx
    push edx
    push ebx
    mov edx, [esp + 20]
    call .GetPixelColorLevel
    pop ebx
    pop edx
    pop ecx

    call .ApplyDitherBits8
    inc edx
    cmp edx, 4
    jb .cgrp1_loop

    mov eax, [esp]
    shl eax, 1
    imul eax, eax, 3
    mov [g_escp_pass_buf + eax + 1], bl
    mov [g_escp_pass_buf + eax + 4], bh
    movzx edx, bl
    or esi, edx
    movzx edx, bh
    or esi, edx

    ; Group 2: GB rows [EBP+8 .. EBP+11] -> Byte 2
    xor edx, edx
    xor ebx, ebx
.cgrp2_loop:
    lea eax, [ebp + edx + 8]
    push ecx
    push edx
    push ebx
    mov edx, [esp + 20]
    call .GetPixelColorLevel
    pop ebx
    pop edx
    pop ecx

    call .ApplyDitherBits8
    inc edx
    cmp edx, 4
    jb .cgrp2_loop

    mov eax, [esp]
    shl eax, 1
    imul eax, eax, 3
    mov [g_escp_pass_buf + eax + 2], bl
    mov [g_escp_pass_buf + eax + 5], bh
    movzx edx, bl
    or esi, edx
    movzx edx, bh
    or esi, edx

    pop ecx
    inc ecx
    jmp .color_col_loop

.color_pass_complete:
    mov eax, esi                         ; non-zero indicator
    pop ebp
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

; ---------------------------------------------------------------------------
; .GetPixelShadeMono — read 2bpp pixel shade at GB coordinate (ECX=x, EAX=y)
; Returns: EAX = mapped shade (0=white, 1=light, 2=dark, 3=black)
; ---------------------------------------------------------------------------
.GetPixelShadeMono:
    push ebx
    push edx
    push esi
    push edi

    mov edx, [g_print_band_count]
    shl edx, 4                           ; total rows
    cmp eax, edx
    jae .out_of_bounds_mono

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
    jbe .lighten_mono
    cmp ebx, 0x60
    jae .darken_mono
    jmp .done_shade_mono

.lighten_mono:
    test eax, eax
    jz .done_shade_mono
    dec eax
    jmp .done_shade_mono

.darken_mono:
    cmp eax, 3
    jae .done_shade_mono
    inc eax
    jmp .done_shade_mono

.out_of_bounds_mono:
    xor eax, eax
.done_shade_mono:
    pop edi
    pop esi
    pop edx
    pop ebx
    ret

; ---------------------------------------------------------------------------
; .GetPixelColorLevel — compute CMY(K) dither level (0..3) for plane EDX
; Inputs:
;   ECX = x (0..159)
;   EAX = y (0..143)
;   EDX = plane ID (4=Yellow, 1=Magenta, 2=Cyan, 0=Black)
; Returns: EAX = dither level (0..3)
;
; DEVIATION{class=HAL; pret=engine/printer/serial.asm:Printer_StageHeaderForSend; behavior=the GB Printer packet exposure byte (Options PRINT brightness) is reused as a saturation scale in the /PRNCOLOR backend (LIGHTEST=$00 desaturates to luminance, LIGHTER=$20 halves saturation, NORMAL=$40 is identity, DARKER=$60 boosts, DARKEST=$7f boosts maximally with clamping) while the mono path uses the same byte as exposure/brightness; evidence=the port-only ESC/P color backend owns the post-printer interpretation and the DOS output is at the printer hardware boundary; lifetime=permanent while /PRNCOLOR reuses the Options exposure byte}
; ---------------------------------------------------------------------------
.GetPixelColorLevel:
    push ebx
    push ecx
    push edx
    push esi
    push edi

    mov edx, [g_print_band_count]
    shl edx, 4
    cmp eax, edx
    jae .color_oob

    ; 1. Get raw shade from g_print_band_buf
    push eax                             ; save y
    push ecx                             ; save x

    mov edx, eax
    shr edx, 4
    imul edx, edx, 640

    mov ebx, eax
    and ebx, 0x0F
    shr ebx, 3
    imul ebx, ebx, 20

    mov edi, ecx
    shr edi, 3
    add ebx, edi
    shl ebx, 4

    mov edi, eax
    and edi, 7
    shl edi, 1

    add edx, ebx
    add edx, edi
    lea esi, [g_print_band_buf + edx]

    mov ebx, ecx
    and ebx, 7
    mov cl, 7
    sub cl, bl

    movzx eax, byte [esi]
    shr eax, cl
    and eax, 1

    movzx ebx, byte [esi + 1]
    shr ebx, cl
    and ebx, 1
    shl ebx, 1
    or eax, ebx                          ; EAX = raw shade (0..3)

    pop ecx                              ; restore x
    pop edx                              ; restore y into edx

    ; 2. Cell index in g_print_pal_buf = (y / 8) * 20 + (x / 8)
    shr edx, 3                           ; tile_row (0..17)
    imul edx, edx, 20
    mov ebx, ecx
    shr ebx, 3                           ; tile_col (0..19)
    add edx, ebx                         ; cell_idx (0..359)
    movzx ebx, byte [g_print_pal_buf + edx] ; palette ID (0..7)

    ; 3. Look up RGB in pal_rgb_table: offset = (pal_id * 4 + shade) * 3
    shl ebx, 2
    add ebx, eax
    imul ebx, ebx, 3
    lea esi, [pal_rgb_table + ebx]
    movzx eax, byte [esi + 0]            ; R6 (0..63)
    movzx ebx, byte [esi + 1]            ; G6 (0..63)
    movzx ecx, byte [esi + 2]            ; B6 (0..63)

    ; 3b. Exposure -> saturation in the color backend. Normal=$40 is identity;
    ; light settings desaturate toward luminance, dark settings boost it:
    ;   channel' = LUM + ((channel - LUM) * exposure) / 64, clamped 0..63.
    push eax                             ; R
    push ebx                             ; G
    push ecx                             ; B
    mov eax, [esp + 8]                   ; R
    add eax, [esp + 4]                   ; + G
    add eax, [esp]                       ; + B
    xor edx, edx
    mov ebx, 3
    div ebx                              ; EAX = LUM = (R+G+B)/3
    mov edi, eax                         ; EDI = luminance
    pop ecx                              ; B
    pop ebx                              ; G
    pop eax                              ; R

    movzx edx, byte [g_print_exposure]   ; EDX = exposure scale (0..127)

    sub eax, edi
    imul eax, edx
    sar eax, 6
    add eax, edi
    cmp eax, 0
    jge .r_ge0
    xor eax, eax
.r_ge0:
    cmp eax, 63
    jle .r_ok
    mov eax, 63
.r_ok:

    sub ebx, edi
    imul ebx, edx
    sar ebx, 6
    add ebx, edi
    cmp ebx, 0
    jge .g_ge0
    xor ebx, ebx
.g_ge0:
    cmp ebx, 63
    jle .g_ok
    mov ebx, 63
.g_ok:

    sub ecx, edi
    imul ecx, edx
    sar ecx, 6
    add ecx, edi
    cmp ecx, 0
    jge .b_ge0
    xor ecx, ecx
.b_ge0:
    cmp ecx, 63
    jle .b_ok
    mov ecx, 63
.b_ok:

    ; 4. Compute plane ink value based on EDX (plane ID: 4=Y, 1=M, 2=C, 0=K)
    mov edx, [esp + 8]                   ; retrieve plane ID
    cmp edx, 4
    je .plane_yellow
    cmp edx, 1
    je .plane_magenta
    cmp edx, 2
    je .plane_cyan

.plane_black:
    ; K = 63 - max(R, G, B)
    mov edx, eax
    cmp ebx, edx
    jbe .k_check_b
    mov edx, ebx
.k_check_b:
    cmp ecx, edx
    jbe .k_have_max
    mov edx, ecx
.k_have_max:
    mov eax, 63
    sub eax, edx
    jmp .map_level

.plane_yellow:
    ; Y = 63 - B6
    mov eax, 63
    sub eax, ecx
    jmp .map_level

.plane_magenta:
    ; M = 63 - G6
    mov eax, 63
    sub eax, ebx
    jmp .map_level

.plane_cyan:
    ; C = 63 - adjusted R
    mov edx, eax
    mov eax, 63
    sub eax, edx
    jmp .map_level

.map_level:
    ; EAX = ink value (0..63). Map to dither level 0..3
    cmp eax, 16
    jb .lvl0
    cmp eax, 32
    jb .lvl1
    cmp eax, 48
    jb .lvl2
    mov eax, 3
    jmp .color_done
.lvl0:
    xor eax, eax
    jmp .color_done
.lvl1:
    mov eax, 1
    jmp .color_done
.lvl2:
    mov eax, 2
    jmp .color_done

.color_oob:
    xor eax, eax
.color_done:
    pop edi
    pop esi
    pop edx
    pop ecx
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

    mov cl, 7
    shl dl, 1
    sub cl, dl                           ; CL = bit0 shift

    test eax, eax
    jz .dither_done

    cmp eax, 1
    je .dither_light
    cmp eax, 2
    je .dither_dark
    jmp .dither_black

.dither_light:
    mov dl, 1
    shl dl, cl
    or bl, dl
    jmp .dither_done

.dither_dark:
    mov dl, 1
    shl dl, cl
    or bl, dl
    dec cl
    mov dl, 1
    shl dl, cl
    or bh, dl
    jmp .dither_done

.dither_black:
    mov dl, 1
    shl dl, cl
    or bl, dl
    or bh, dl
    dec cl
    mov dl, 1
    shl dl, cl
    or bl, dl
    or bh, dl

.dither_done:
    pop edx
    pop ecx
    ret
