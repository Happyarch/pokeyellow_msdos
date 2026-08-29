; kbd_isr.asm — INT 9h keyboard ISR driver and matrix state.
;
; Hooks IRQ 1 (vector 9) via DPMI, reads scancodes from port 0x60, and
; maintains two pressed-state nibbles against configurable byte literals:
;
;   pad_dpad    bit 0=Right  1=Left  2=Up    3=Down    (1 = held)
;   pad_buttons bit 0=A      1=B     2=Select 3=Start  (1 = held)
;
; Key bindings are resolved against byte literals in src/input/input_cfg.asm
; (cfg_key_*), which are populated at boot from POKEMON.CFG.
;
; Build: nasm -f coff -I include/ -I . -o kbd_isr.o kbd_isr.asm

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"

KBD_INT         equ 0x09    ; protected-mode vector for IRQ 1
KBD_DATA_PORT   equ 0x60
PIC_CMD_PORT    equ 0x20
PIC_EOI         equ 0x20

; Scancodes
SC_EXT          equ 0xE0    ; extended-key prefix
SC_UP           equ 0x48    ; standard arrow defaults
SC_DOWN         equ 0x50
SC_LEFT         equ 0x4B
SC_RIGHT        equ 0x4D
SC_LSHIFT       equ 0x2A    ; text-entry shift tracking only
SC_RSHIFT       equ 0x36
SC_ESC          equ 0x01
%ifdef DEBUG_NOCLIP
SC_W            equ 0x11    ; noclip toggle key
%endif

PAD_RIGHT_BIT   equ 0
PAD_LEFT_BIT    equ 1
PAD_UP_BIT      equ 2
PAD_DOWN_BIT    equ 3
PAD_A_BIT       equ 0
PAD_B_BIT       equ 1
PAD_SELECT_BIT  equ 2
PAD_START_BIT   equ 3

KBD_RING_SIZE   equ 16      ; bytes; 2 bytes/key (scancode, shift) = 8 keys buffered

global kbd_init
global kbd_restore
global pad_dpad             ; byte: D-pad held state (1 = pressed)
global pad_buttons          ; byte: button held state (1 = pressed)
global pad_quit             ; byte: nonzero once Esc is pressed
global pad_reset            ; byte: nonzero once soft-reset combo fires
global g_kbd_text_mode      ; byte: nonzero -> kbd_isr also buffers scancodes
global kbd_ring_pop         ; AL=scancode, AH=shift, ZF=1 empty
%ifdef DEBUG_NOCLIP
global pad_noclip           ; byte: 1 = noclip active (W toggles)
%endif

; External configurable byte literals from input_cfg.asm
extern cfg_key_up
extern cfg_key_down
extern cfg_key_left
extern cfg_key_right
extern cfg_key_a
extern cfg_key_b
extern cfg_key_start
extern cfg_key_select

section .bss
align 4
orig_irq1_off:    resd 1
orig_irq1_sel:    resw 1
pad_dpad:         resb 1
pad_buttons:      resb 1
pad_quit:         resb 1
pad_reset:        resb 1
ext_pending:      resb 1
%ifdef DEBUG_NOCLIP
pad_noclip:       resb 1
%endif

g_kbd_text_mode:  resb 1
kbd_shift_state:  resb 1
kbd_ring:         resb KBD_RING_SIZE
kbd_ring_head:    resb 1
kbd_ring_tail:    resb 1

section .data
align 4
kisr_ds:          dw 0

section .text

; ---------------------------------------------------------------------------
; kbd_init — save original IRQ1 vector and install kbd_isr
; ---------------------------------------------------------------------------
kbd_init:
    push eax
    push ebx
    push ecx
    push edx

    mov ax, ds
    mov [kisr_ds], ax

    mov byte [pad_reset], 0
    mov byte [pad_quit], 0
    mov byte [pad_dpad], 0
    mov byte [pad_buttons], 0

    ; Save original protected-mode IRQ1 vector (DPMI fn 0204h)
    mov ax, 0x0204
    mov bl, KBD_INT
    int 0x31
    mov [orig_irq1_off], edx
    mov [orig_irq1_sel], cx

    ; Install kbd_isr (DPMI fn 0205h)
    mov ax, 0x0205
    mov bl, KBD_INT
    mov cx, cs
    mov edx, kbd_isr
    int 0x31

    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

; ---------------------------------------------------------------------------
; kbd_restore — restore original IRQ1 vector
; ---------------------------------------------------------------------------
kbd_restore:
    push eax
    push ebx
    push ecx
    push edx

    mov ax, 0x0205
    mov bl, KBD_INT
    mov cx, [orig_irq1_sel]
    mov edx, [orig_irq1_off]
    int 0x31

    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

; ---------------------------------------------------------------------------
; kbd_isr — IRQ 1 handler: read scancode, update pad state, EOI
; ---------------------------------------------------------------------------
kbd_isr:
    push ds
    push es
    push eax
    push ebx

    mov ax, [cs:kisr_ds]
    mov ds, ax
    mov es, ax

    in  al, KBD_DATA_PORT

    cmp al, SC_EXT
    jne .not_prefix
    mov byte [ext_pending], 1
    jmp .eoi
.not_prefix:
    mov byte [ext_pending], 0

    ; BL = make code, BH = 0 for press / 0x80 for release
    mov bl, al
    and bl, 0x7F
    mov bh, al
    and bh, 0x80

    ; Shift tracking
    cmp bl, SC_LSHIFT
    je .shift_key
    cmp bl, SC_RSHIFT
    jne .not_shift_key
.shift_key:
    test bh, bh
    jnz .shift_up
    mov byte [kbd_shift_state], 1
    jmp .not_shift_key
.shift_up:
    mov byte [kbd_shift_state], 0
.not_shift_key:

    ; Text-entry ring push
    cmp byte [g_kbd_text_mode], 0
    je .ring_done
    test bh, bh
    jnz .ring_done
    push eax
    push ecx
    push edx
    movzx ecx, byte [kbd_ring_head]
    mov al, bl
    mov [kbd_ring + ecx], al
    inc ecx
    and ecx, KBD_RING_SIZE - 1
    mov al, [kbd_shift_state]
    mov [kbd_ring + ecx], al
    inc ecx
    and ecx, KBD_RING_SIZE - 1
    mov dl, [kbd_ring_tail]
    cmp cl, dl
    jne .ring_no_overflow
    add dl, 2
    and dl, KBD_RING_SIZE - 1
    mov [kbd_ring_tail], dl
.ring_no_overflow:
    mov [kbd_ring_head], cl
    pop edx
    pop ecx
    pop eax
.ring_done:

    ; --- D-pad checks ---
    ; Right
    cmp bl, [cfg_key_right]
    je .match_right
    cmp bl, SC_RIGHT
    jne .chk_left
.match_right:
    mov al, 1 << PAD_RIGHT_BIT
    jmp .apply_dpad

.chk_left:
    cmp bl, [cfg_key_left]
    je .match_left
    cmp bl, SC_LEFT
    jne .chk_up
.match_left:
    mov al, 1 << PAD_LEFT_BIT
    jmp .apply_dpad

.chk_up:
    cmp bl, [cfg_key_up]
    je .match_up
    cmp bl, SC_UP
    jne .chk_down
.match_up:
    mov al, 1 << PAD_UP_BIT
    jmp .apply_dpad

.chk_down:
    cmp bl, [cfg_key_down]
    je .match_down
    cmp bl, SC_DOWN
    jne .chk_buttons
.match_down:
    mov al, 1 << PAD_DOWN_BIT
    jmp .apply_dpad

    ; --- Buttons checks ---
.chk_buttons:
    ; A Button
    cmp bl, [cfg_key_a]
    jne .chk_b
    mov al, 1 << PAD_A_BIT
    jmp .apply_btn

.chk_b:
    ; B Button
    cmp bl, [cfg_key_b]
    jne .chk_start
    mov al, 1 << PAD_B_BIT
    jmp .apply_btn

.chk_start:
    ; Start Button
    cmp bl, [cfg_key_start]
    jne .chk_select
    mov al, 1 << PAD_START_BIT
    jmp .apply_btn

.chk_select:
    ; Select Button
    cmp bl, [cfg_key_select]
    je .match_sel
    cmp bl, SC_RSHIFT           ; also accept RSHIFT as secondary Select
    jne .chk_host_keys
.match_sel:
    mov al, 1 << PAD_SELECT_BIT
    jmp .apply_btn

.chk_host_keys:
%ifdef DEBUG_NOCLIP
    cmp bl, SC_W
    jne .not_noclip_key
    test bh, bh
    jnz .eoi
    xor byte [pad_noclip], 1
    jmp .eoi
.not_noclip_key:
%endif
    cmp bl, SC_ESC
    jne .eoi
    test bh, bh
    jnz .eoi
    cmp byte [g_kbd_text_mode], 0
    jne .eoi
    mov byte [pad_quit], 1
    jmp .eoi

.apply_dpad:
    test bh, bh
    jnz .release_dpad
    or  [pad_dpad], al
    jmp .eoi
.release_dpad:
    not al
    and [pad_dpad], al
    jmp .eoi

.apply_btn:
    test bh, bh
    jnz .release_btn
    or  [pad_buttons], al
    jmp .eoi
.release_btn:
    not al
    and [pad_buttons], al

.eoi:
    mov al, PIC_EOI
    out PIC_CMD_PORT, al

    pop ebx
    pop eax
    pop es
    pop ds
    iret

; ---------------------------------------------------------------------------
; kbd_ring_pop — pop one (scancode, shift) pair from ring
; ---------------------------------------------------------------------------
kbd_ring_pop:
    cli
    mov bl, [kbd_ring_head]
    mov cl, [kbd_ring_tail]
    cmp bl, cl
    je .empty
    movzx edx, cl
    mov al, [kbd_ring + edx]
    inc edx
    and edx, KBD_RING_SIZE - 1
    mov ah, [kbd_ring + edx]
    inc edx
    and edx, KBD_RING_SIZE - 1
    mov [kbd_ring_tail], dl
    sti
    mov ecx, 1
    test ecx, ecx
    ret
.empty:
    sti
    xor eax, eax
    xor ecx, ecx
    test ecx, ecx
    ret

%ifdef AUTOKEY_KBDSCRIPT
global kbd_ring_push
kbd_ring_push:
    cli
    push eax
    movzx ecx, byte [kbd_ring_head]
    mov [kbd_ring + ecx], al
    inc ecx
    and ecx, KBD_RING_SIZE - 1
    mov [kbd_ring_pad], ah
    inc ecx
    and ecx, KBD_RING_SIZE - 1
    mov dl, [kbd_ring_tail]
    cmp cl, dl
    jne .no_overflow
    add dl, 2
    and dl, KBD_RING_SIZE - 1
    mov [kbd_ring_tail], dl
.no_overflow:
    mov [kbd_ring_head], cl
    pop eax
    sti
    ret
%endif
