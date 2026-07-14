; video.asm — VGA mode 13h initialisation, test pattern, and frame present.
;
; Mode 13h: 320×200, 256 indexed colors, linear framebuffer at 0xA0000.
; Under DPMI, INT 10h is reflected to the real-mode BIOS automatically.
;
; ADDRESSING NOTE: DS base is not linear 0 under DJGPP. All VGA framebuffer
; access goes through [vga_base], computed at init as 0xA0000 - ds_base.
; This requires the 4 GB DS limit set by setup_flat_access (entry.asm) —
; the offset wraps modulo 2^32 and lands on linear 0xA0000.
;
; present() copies the 320×200 tile-blitter back buffer to VGA via rep movsd.
; No scaling, no letterbox — the back buffer matches VGA dimensions exactly.
;
; Build: nasm -f coff -I include/ -o video.o video.asm

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"

extern ds_base           ; entry.asm — linear base of DS selector
extern tick_count        ; timing.asm — incremented at ~60 Hz by the PIT ISR

; ---------------------------------------------------------------------------
; Exported symbols
; ---------------------------------------------------------------------------
global video_init
global present           ; copy 320×200 back buffer → VGA framebuffer
global draw_tick_band    ; visible PIT tick indicator (top screen band)
global commit_palette    ; map CGB-style slot palettes + DMG regs → DAC 0-63

; ---------------------------------------------------------------------------
; BSS
; ---------------------------------------------------------------------------
section .bss
align 4
vga_base:   resd 1       ; DS-relative address of the VGA framebuffer
pal_bgp_shadow: resb 1
pal_obp0_shadow: resb 1
pal_obp1_shadow: resb 1

; ---------------------------------------------------------------------------
; Data
; ---------------------------------------------------------------------------
section .data
align 4

; Bootstrap test palette: four 64-entry ramps (blue, green, yellow, gray).
; Confirms the DAC ports work. Replaced by the real game palette in Phase 5.
test_palette:
%assign _i 0
%rep 64
    db (_i),    0,    0     ; ramp 0–63: blue-ish (R channel ramp actually; see note)
    %assign _i _i+1
%endrep
%assign _i 0
%rep 64
    db 0,    (_i),    0     ; ramp 64–127: green
    %assign _i _i+1
%endrep
%assign _i 0
%rep 64
    db (_i), (_i),    0     ; ramp 128–191: yellow
    %assign _i _i+1
%endrep
%assign _i 0
%rep 64
    db (_i), (_i), (_i)    ; ramp 192–255: gray
    %assign _i _i+1
%endrep
; Note: port 0x3C9 write order is R, G, B — so ramp 0 is actually red.
; Cosmetic only; this palette exists just to verify the DAC.

extern g_pal_dirty
extern bg_slot_pal, obj_slot_pal
extern pal_rgb_table

; ---------------------------------------------------------------------------
; Code
; ---------------------------------------------------------------------------
section .text

; ---------------------------------------------------------------------------
; video_init — set VGA mode 13h, load test palette, draw test pattern
; ---------------------------------------------------------------------------
video_init:
    push eax
    push ecx
    push edx
    push esi

    ; Compute DS-relative framebuffer address (wraps via 4 GB limit)
    mov eax, VGA_FRAMEBUF
    sub eax, [ds_base]
    mov [vga_base], eax

    ; Set VGA mode 13h via BIOS (reflected to real mode by the DPMI host)
    mov ax, 0x0013
    int 0x10

    ; Load palette through the VGA DAC:
    ;   port 0x3C8 = write index (auto-increments after each RGB triple)
    ;   port 0x3C9 = R, G, B data (6-bit, 0–63)
    mov dx, 0x3C8
    xor al, al
    out dx, al

    mov dx, 0x3C9
    mov esi, test_palette
    mov ecx, 256 * 3
.pal_loop:
    lodsb
    out dx, al
    loop .pal_loop

    call draw_test_pattern

    pop esi
    pop edx
    pop ecx
    pop eax
    ret

; ---------------------------------------------------------------------------
; draw_test_pattern — diagonal color gradient across the full screen
; color = (row + col) & 0xFF. Confirms framebuffer addressing + palette.
; ---------------------------------------------------------------------------
draw_test_pattern:
    push eax
    push ebx
    push ecx
    push edx
    push edi

    mov edi, [vga_base]
    xor ebx, ebx            ; EBX = row
.row_loop:
    xor edx, edx            ; EDX = column
.px_loop:
    lea eax, [ebx + edx]    ; color = row + col
    stosb                   ; AL → [ES:EDI], EDI++
    inc edx
    cmp edx, VGA_W
    jb .px_loop
    inc ebx
    cmp ebx, VGA_H
    jb .row_loop

    pop edi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

; ---------------------------------------------------------------------------
; draw_tick_band — fill the top 4 screen rows with color = tick_count & 0xFF
;
; Called once per frame from the main loop. Because tick_count increments at
; ~60 Hz, the band visibly cycles through the palette — a moving band proves
; the PIT ISR is firing. (A static band means the ISR is dead.)
; ---------------------------------------------------------------------------
draw_tick_band:
    push eax
    push ecx
    push edi

    mov edi, [vga_base]
    mov eax, [tick_count]
    ; AL = low byte of tick count = palette index that cycles at 60 Hz
    mov ecx, VGA_W * 4      ; top 4 rows
    rep stosb

    pop edi
    pop ecx
    pop eax
    ret

; ---------------------------------------------------------------------------
; commit_palette — map CGB-style slots + GB DMG palette registers to DAC 0-63.
;
; The PPU renderer writes RAW GB color indices into the back buffer:
; BG cache bytes are slot*4+color, OBJ pixels are 32+slot*4+color.  Each DAC
; entry chooses a color from its PAL_* RGB quad via BGP (BG) or OBP0/OBP1 (OBJ),
; keeping fades as a pure register/DAC update.  g_pal_dirty is armed whenever a
; palette command swaps a slot; register changes are detected by the frame's
; ordinary call through this routine.
;
; In: EBP = GB memory base. All registers preserved.
; ---------------------------------------------------------------------------
commit_palette:
    pushad
    cmp byte [g_pal_dirty], 0
    jne .commit
    mov al, [ebp + IO_BGP]
    cmp al, [pal_bgp_shadow]
    jne .commit
    mov al, [ebp + IO_OBP0]
    cmp al, [pal_obp0_shadow]
    jne .commit
    mov al, [ebp + IO_OBP1]
    cmp al, [pal_obp1_shadow]
    jne .commit
    jmp .done
.commit:
    mov dx, 0x3C8
    xor al, al
    out dx, al
    mov dx, 0x3C9
    xor ebx, ebx                    ; BG slot 0..7
.bg_slot:
    movzx esi, byte [bg_slot_pal + ebx]
    imul esi, 12
    add esi, pal_rgb_table
    movzx edi, byte [ebp + IO_BGP]
    mov ecx, 4
.bg_color:
    mov eax, edi
    and eax, 3
    lea eax, [eax + eax*2]
    add eax, esi
    mov al, [eax]
    out dx, al
    mov al, [eax + 1]
    out dx, al
    mov al, [eax + 2]
    out dx, al
    shr edi, 2
    dec ecx
    jnz .bg_color
    inc ebx
    cmp ebx, 8
    jb .bg_slot
    xor ebx, ebx                    ; OBJ slot 0..7
.obj_slot:
    movzx esi, byte [obj_slot_pal + ebx]
    imul esi, 12
    add esi, pal_rgb_table
    mov edi, [ebp + IO_OBP0]
    test ebx, 1
    jz .obj_reg
    mov edi, [ebp + IO_OBP1]
.obj_reg:
    mov ecx, 4
.obj_color:
    mov eax, edi
    and eax, 3
    lea eax, [eax + eax*2]
    add eax, esi
    mov al, [eax]                  ; R
    out dx, al
    mov al, [eax + 1]              ; G
    out dx, al
    mov al, [eax + 2]              ; B
    out dx, al
    shr edi, 2
    dec ecx
    jnz .obj_color
    inc ebx
    cmp ebx, 8
    jb .obj_slot
    mov al, [ebp + IO_BGP]
    mov [pal_bgp_shadow], al
    mov al, [ebp + IO_OBP0]
    mov [pal_obp0_shadow], al
    mov al, [ebp + IO_OBP1]
    mov [pal_obp1_shadow], al
    mov byte [g_pal_dirty], 0
.done:
    popad
    ret

; ---------------------------------------------------------------------------
; present — copy 320×200 back buffer to VGA framebuffer
;
; Reads:  [EBP + GB_BACKBUF] — 320×200 8bpp pixels (raw-index PPU output)
; Writes: [vga_base] — VGA linear framebuffer (Mode 13h)
;
; Single rep movsd of 16,000 dwords.  No scaling, no letterbox.
; ---------------------------------------------------------------------------
present:
    push ecx
    push esi
    push edi

    lea esi, [ebp + GB_BACKBUF]
    mov edi, [vga_base]
    mov ecx, RENDER_W * RENDER_H / 4      ; 16,000 dwords
    rep movsd

    pop edi
    pop esi
    pop ecx
    ret
