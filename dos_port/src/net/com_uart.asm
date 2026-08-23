; ===========================================================================
; com_uart.asm — 8250/16550 COM-port byte transport for the link-cable HAL
; (port-only, no pret counterpart). docs/current_plan_link_cable.md Stage 2.
;
; Pure byte I/O: detect + program the UART, an IRQ-driven RX ring, and a
; bounded polled TX. The frame codec (net_frame.asm) and the session logic
; (net_hal.asm) sit above; this file knows nothing about frames.
;
; Patterns copied from the two existing drivers, per the plan:
;   - ISR install/restore: src/input/joypad.asm — DPMI 0204h save / 0205h
;     install, DS via [cs:uisr_ds], manual EOI, restore from cleanup. Like
;     the keyboard ISR, this one does NOT chain to the old handler.
;   - Bounded waits: src/audio/mpu401.asm — every poll is bounded, CF on
;     timeout; absent/wedged hardware degrades to no-link, never a hang.
;
; Port selection: g_net_com_sel (net_hal.asm; parsed from /COM1../COM4) picks
; base+IRQ: COM1 3F8/IRQ4, COM2 2F8/IRQ3, COM3 3E8/IRQ4, COM4 2E8/IRQ3.
; Baud: divisor from g_net_baud_div (parsed from /BAUD=n as 115200/n), 0 =
; default 115200 (divisor 1). 8N1 always.
;
; Register contract: called from NetInit/NetShutdown (boot/cleanup) and from
; codec callbacks inside NetHAL_Pump's pushad — clobbers EAX ECX EDX freely,
; preserves EBX/ESI/EDI/EBP (the codec callback contract needs EBX; the rest
; is cheap insurance).
;
; Build check: nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 \
;              -o /dev/null src/net/com_uart.asm   (from dos_port/)
; ===========================================================================

bits 32

global ComUart_Init
global ComUart_Shutdown
global ComUart_TxByte
global ComUart_RxByte

extern g_net_com_sel                ; src/net/net_hal.asm — 0 none / 1..4
extern g_net_baud_div               ; src/net/net_hal.asm — divisor (0 = 115200)

; UART register offsets from base
U_DATA          equ 0               ; RBR/THR (DLL when DLAB)
U_IER           equ 1               ; interrupt enable (DLM when DLAB)
U_IIR           equ 2               ; interrupt id (read) / FCR (write)
U_LCR           equ 3               ; line control
U_MCR           equ 4               ; modem control
U_LSR           equ 5               ; line status
U_SCRATCH       equ 7

LSR_DATA_READY  equ 0x01
LSR_THRE        equ 0x20

PIC_CMD         equ 0x20
PIC_DATA        equ 0x21
PIC_EOI_CMD     equ 0x20

TX_POLL_BOUND   equ 20000           ; ~ a few ms at ISA speed; CF on timeout
                                    ; (mpu401 MPU_POLL_BOUND family)

RX_RING_SIZE    equ 4096            ; power of two
RX_RING_MASK    equ RX_RING_SIZE - 1

section .bss
align 4
uart_base:      resw 1              ; 0 = not bound
uart_irq:       resb 1              ; 3 or 4
uart_vec:       resb 1              ; interrupt vector (8 + IRQ)
uart_fifo:      resb 1              ; 1 = 16550A FIFOs enabled
orig_vec_off:   resd 1              ; saved protected-mode vector (0204h)
orig_vec_sel:   resw 1
orig_pic_mask:  resb 1              ; saved IRQ mask bit state
rx_ring:        resb RX_RING_SIZE
global g_uart_diag                  ; DEBUG_LINKCHECK GBSTATE probe region
g_uart_diag:                        ; (8 dwords, layout below)
rx_head:        resd 1              ; ISR writes
rx_tail:        resd 1              ; reader consumes
rx_overruns:    resd 1              ; ring-full drops (diagnostic)
cnt_rx_calls:   resd 1              ; ComUart_RxByte entries
cnt_rx_ring:    resd 1              ; ... that popped the ring
cnt_rx_port:    resd 1              ; ... that pulled the port directly
cnt_rx_empty:   resd 1              ; ... that returned CF=1 empty
cnt_isr:        resd 1              ; uart_isr entries
cnt_tx_sent:    resd 1              ; TxByte successes
cnt_tx_drop:    resd 1              ; TxByte THRE timeouts (byte dropped)

section .data
align 4
uisr_ds:        dw 0                ; DS for the ISR, read via [cs:...]
                                    ; (joypad.asm kisr_ds pattern: CS base =
                                    ; DS base under DJGPP/CWSDPMI)
; per-COM base/IRQ tables, indexed by g_net_com_sel-1
com_bases:      dw 0x3F8, 0x2F8, 0x3E8, 0x2E8
com_irqs:       db 4, 3, 4, 3

section .text

; ---------------------------------------------------------------------------
; ComUart_Init — detect and program the UART selected by g_net_com_sel,
; install the RX ISR, unmask its IRQ. Out: CF=0 bound, CF=1 no UART (or no
; selection) — the caller leaves the transport unbound and the game runs
; single-player, the mpu401 "degrade, never hang" posture.
; ---------------------------------------------------------------------------
ComUart_Init:
    push ebx
    movzx ebx, byte [g_net_com_sel]
    test ebx, ebx
    jz .fail
    cmp ebx, 4
    ja .fail
    mov ax, [com_bases + (ebx - 1) * 2]
    mov [uart_base], ax
    mov cl, [com_irqs + ebx - 1]
    mov [uart_irq], cl
    add cl, 8                       ; master PIC base vector
    mov [uart_vec], cl

    ; --- presence: scratch-register test (8250A+/16450/16550 have it) ---
    movzx edx, word [uart_base]
    add edx, U_SCRATCH
    mov al, 0x5A
    out dx, al
    in al, dx
    cmp al, 0x5A
    jne .fail
    mov al, 0xA5
    out dx, al
    in al, dx
    cmp al, 0xA5
    jne .fail

    ; --- program: DLAB on, divisor, 8N1 ---
    movzx edx, word [uart_base]
    add edx, U_LCR
    mov al, 0x80                    ; DLAB
    out dx, al
    mov ax, [g_net_baud_div]
    test ax, ax
    jnz .have_div
    mov ax, 1                       ; default 115200 (divisor 1)
.have_div:
    movzx edx, word [uart_base]     ; DLL
    out dx, al
    inc edx                         ; DLM
    mov al, ah
    out dx, al
    movzx edx, word [uart_base]
    add edx, U_LCR
    mov al, 0x03                    ; 8N1, DLAB off
    out dx, al

    ; --- FIFO probe: FCR=enable+clear, trigger 1; IIR bits 7:6 = 11 -> 16550A ---
    movzx edx, word [uart_base]
    add edx, U_IIR
    mov al, 0x07
    out dx, al
    in al, dx
    and al, 0xC0
    cmp al, 0xC0
    sete al
    mov [uart_fifo], al             ; plain 8250: FCR write was ignored — fine

    ; --- drain any stale RX byte(s), clear LSR ---
    movzx edx, word [uart_base]
    add edx, U_LSR
    mov ecx, 16
.drain:
    in al, dx
    test al, LSR_DATA_READY
    jz .drained
    movzx edx, word [uart_base]
    in al, dx
    movzx edx, word [uart_base]
    add edx, U_LSR
    loop .drain
.drained:

    ; --- ISR install (joypad.asm pattern) ---
    mov ax, ds
    mov [uisr_ds], ax
    mov ax, 0x0204                  ; DPMI: get protected-mode vector
    mov bl, [uart_vec]
    int 0x31
    mov [orig_vec_off], edx
    mov [orig_vec_sel], cx
    mov ax, 0x0205                  ; DPMI: set protected-mode vector
    mov bl, [uart_vec]
    mov cx, cs
    mov edx, uart_isr
    int 0x31

    ; --- unmask the IRQ at the PIC (remember prior state) ---
    mov cl, [uart_irq]
    mov ah, 1
    shl ah, cl
    in al, PIC_DATA
    mov dl, al
    and dl, ah
    mov [orig_pic_mask], dl         ; the bit as it was (0 = was unmasked)
    not ah
    and al, ah
    out PIC_DATA, al

    ; --- MCR: DTR|RTS|OUT2 (OUT2 gates the IRQ line), then IER: RX int ---
    movzx edx, word [uart_base]
    add edx, U_MCR
    mov al, 0x0B
    out dx, al
    movzx edx, word [uart_base]
    add edx, U_IER
    mov al, 0x01                    ; received-data-available interrupt only
    out dx, al

    ; --- post-enable drain: force INTR low so the first arrival AFTER this
    ; point is a fresh edge. The peer may have been transmitting throughout
    ; our boot (linkcheck's staggered second instance boots into the first
    ; one's HELLO retransmissions, measured 2026-08-22): a byte already in
    ; the RBR when IER goes live holds the INTR line high, the 8259 is
    ; edge-triggered, and a held line is a dead line — the ISR never fires
    ; and every later byte overruns. Drain RBR (the discarded bytes are
    ; mid-frame noise; the ARQ retransmits), clear LSR error latches, and
    ; read IIR to retire any latched interrupt id. ---
    mov ecx, 64
.post_drain:
    movzx edx, word [uart_base]
    add edx, U_IIR
    in al, dx
    movzx edx, word [uart_base]
    add edx, U_LSR
    in al, dx
    test al, LSR_DATA_READY
    jz .post_done
    movzx edx, word [uart_base]
    in al, dx
    loop .post_drain
.post_done:

    pop ebx
    clc
    ret
.fail:
    mov word [uart_base], 0
    pop ebx
    stc
    ret

; ---------------------------------------------------------------------------
; ComUart_Shutdown — IER off, restore PIC mask bit and the saved vector.
; Safe to call when never bound (uart_base 0). Runs from cleanup.
; ---------------------------------------------------------------------------
ComUart_Shutdown:
    push ebx
    cmp word [uart_base], 0
    je .done
    movzx edx, word [uart_base]
    add edx, U_IER
    xor al, al
    out dx, al                      ; no more UART interrupts
    ; restore the PIC mask bit to its prior state
    mov cl, [uart_irq]
    mov ah, 1
    shl ah, cl
    in al, PIC_DATA
    or al, ah                       ; mask it...
    cmp byte [orig_pic_mask], 0
    jne .was_masked
    not ah
    and al, ah                      ; ...unless it was unmasked before us
.was_masked:
    out PIC_DATA, al
    ; restore the saved protected-mode vector
    mov ax, 0x0205
    mov bl, [uart_vec]
    mov cx, [orig_vec_sel]
    mov edx, [orig_vec_off]
    int 0x31
    mov word [uart_base], 0
.done:
    pop ebx
    ret

; ---------------------------------------------------------------------------
; ComUart_TxByte — transmit AL. Bounded THRE poll (mpu401 pattern).
; Out: CF=0 sent, CF=1 timeout (byte dropped — the ARQ recovers).
; Preserves EBX/ESI/EDI.
; ---------------------------------------------------------------------------
ComUart_TxByte:
    cmp word [uart_base], 0
    je .timeout
    push eax
    movzx edx, word [uart_base]
    add edx, U_LSR
    mov ecx, TX_POLL_BOUND
.poll:
    in al, dx
    test al, LSR_THRE
    jnz .ready
    loop .poll
    pop eax
    inc dword [cnt_tx_drop]
.timeout:
    stc
    ret
.ready:
    pop eax
    movzx edx, word [uart_base]
    out dx, al
    inc dword [cnt_tx_sent]
    clc
    ret

; ---------------------------------------------------------------------------
; ComUart_RxByte — pop one byte from the RX ring; with the ring empty, poll
; the port directly. Out: CF=1 nothing available, else AL. Preserves
; EBX/ESI/EDI.
;
; The direct poll is the IRQ-less fallback: if an interrupt edge is ever
; lost (see the post-enable drain note in ComUart_Init), the pump still
; drains the UART — slower (per-pump instead of per-byte, so overruns can
; cost retransmissions) but alive instead of deaf. The whole check-then-read
; runs under CLI so the ISR cannot interleave a ring push between the
; empty check and the port read (that reordering would deliver byte n+1
; before byte n and every frame CRC after it would reject).
; ---------------------------------------------------------------------------
ComUart_RxByte:
    cmp word [uart_base], 0
    je .unbound
    inc dword [cnt_rx_calls]
    pushfd
    cli
    mov ecx, [rx_tail]
    cmp ecx, [rx_head]
    jne .ring
    movzx edx, word [uart_base]     ; ring empty: poll the line status
    add edx, U_LSR
    in al, dx
    test al, LSR_DATA_READY
    jz .none
    movzx edx, word [uart_base]
    in al, dx
    inc dword [cnt_rx_port]
    popfd
    clc
    ret
.ring:
    mov al, [rx_ring + ecx]
    inc ecx
    and ecx, RX_RING_MASK
    mov [rx_tail], ecx
    inc dword [cnt_rx_ring]
    popfd
    clc
    ret
.none:
    inc dword [cnt_rx_empty]
    popfd
.unbound:
    stc
    ret

; ---------------------------------------------------------------------------
; uart_isr — RX interrupt: drain every ready byte into the ring. Follows
; kbd_isr (joypad.asm): load DS via [cs:uisr_ds], manual EOI, no chaining.
; ---------------------------------------------------------------------------
uart_isr:
    push ds
    push es
    push eax
    push ecx
    push edx

    mov ax, [cs:uisr_ds]
    mov ds, ax
    mov es, ax

    inc dword [cnt_isr]
    movzx edx, word [uart_base]
    add edx, U_LSR
.drain:
    in al, dx
    test al, LSR_DATA_READY
    jz .eoi
    movzx edx, word [uart_base]     ; data register
    in al, dx
    ; push into the ring (drop + count when full)
    mov ecx, [rx_head]
    mov [rx_ring + ecx], al
    inc ecx
    and ecx, RX_RING_MASK
    cmp ecx, [rx_tail]
    je .overrun
    mov [rx_head], ecx
.next:
    movzx edx, word [uart_base]
    add edx, U_LSR
    jmp .drain
.overrun:
    inc dword [rx_overruns]
    jmp .next
.eoi:
    mov al, PIC_EOI_CMD
    out PIC_CMD, al

    pop edx
    pop ecx
    pop eax
    pop es
    pop ds
    iret
