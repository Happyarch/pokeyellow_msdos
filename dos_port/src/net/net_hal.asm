; ===========================================================================
; net_hal.asm — link-cable network HAL, session core (port-only, no pret
; counterpart). docs/current_plan_link_cable.md Stage 1.
;
; This is the layer BELOW the home/serial.asm HAL line. The pret serial
; primitives (Serial_ExchangeByte & family, src/home/serial.asm) keep their
; register/WRAM/HRAM contracts and call down into this file at the points
; where the GB touched rSC or relied on the serial interrupt:
;
;   NetHAL_StartTransfer — the `rSC = SC_START|*` sites. On the GB that write
;       clocks one 8-bit exchange; here it pokes the bound transport driver
;       ("a byte is staged in hSerialSendData / IO_SB").
;   NetHAL_Pump          — polled from DelayFrame (beside audio_tick) and from
;       the primitives' wait loops. A transport driver's pump moves RX bytes/
;       messages and, on a completed exchange, performs delivery by calling
;       the pret `Serial` handler (src/home/serial.asm) — the port's stand-in
;       for the serial interrupt.
;   NetHAL_LinkAlive     — ZF=1 when no link session is up. The primitives'
;       no-partner escape hatches branch on this (each hatch carries its own
;       class=HAL deviation annotation in serial.asm).
;
; Stage 1 ships the NULL transport only: nothing is ever bound, the pump's
; fast path is a compare+ret each frame, LinkAlive always reports dead, and
; the primitives therefore always take their no-partner hatches — exactly the
; behavior the retired src/home/serial_stubs.asm provided, now beneath the
; faithful pret bodies. Stage 2 adds com_uart.asm + the frame codec and the
; HELLO/role-election session state; Stages 5-7 add the UI, IPX and TCP.
;
; Register contract (all three entries): preserve every GB-mapped register
; (AL/EBX/EDX/ESI) and every other GP register; FLAGS are clobbered
; (NetHAL_LinkAlive's ZF *is* its result). Call sites in the primitives are
; placed where no SM83 flag is live.
;
; Build check: nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 \
;              -o /dev/null src/net/net_hal.asm   (from dos_port/)
; ===========================================================================

bits 32

%include "gb_memmap.inc"

global NetHAL_Pump
global NetHAL_LinkAlive
global NetHAL_StartTransfer
global g_net_transport
global g_net_link_up
global g_peer_game_gen

; Transport ids (index into the vtables below). Stage 2+ append rows; the
; CLI flags / link setup UI select one by storing its id in g_net_transport.
NET_TRANSPORT_NONE  equ 0
NET_TRANSPORT_COUNT equ 1           ; grows as transport drivers land

section .bss

g_net_transport resb 1              ; NET_TRANSPORT_* currently bound (0 = none)
g_net_link_up   resb 1              ; 1 = HELLO handshake completed, session live
g_peer_game_gen resb 1              ; peer's game_gen byte from HELLO ($01 = Gen I)
net_pump_lock   resb 1              ; reentrancy guard: pump runs from DelayFrame
                                    ; AND from the primitives' wait loops, and a
                                    ; transport pump may itself DelayFrame-free
                                    ; poll — never nest deliveries

section .data

; Transport vtable, one column per operation, indexed by g_net_transport.
; Row 0 = null transport: every operation is a no-op. A transport driver
; lands by appending its row to BOTH columns (and bumping NET_TRANSPORT_COUNT).
net_vt_pump:
    dd net_null_op                  ; NET_TRANSPORT_NONE
net_vt_start:
    dd net_null_op                  ; NET_TRANSPORT_NONE

section .text

; ---------------------------------------------------------------------------
; NetHAL_Pump — poll the bound transport. Runs once per frame from DelayFrame
; and ad hoc from the serial primitives' wait loops. Fast no-op while no
; transport is bound (the whole of Stage 1). Preserves registers, clobbers
; flags.
; ---------------------------------------------------------------------------
NetHAL_Pump:
    cmp byte [g_net_transport], NET_TRANSPORT_NONE
    je .idle
    cmp byte [net_pump_lock], 0
    jne .idle
    mov byte [net_pump_lock], 1
    pushad
    movzx eax, byte [g_net_transport]
    call [net_vt_pump + eax * 4]
    popad
    mov byte [net_pump_lock], 0
.idle:
    ret

; ---------------------------------------------------------------------------
; NetHAL_LinkAlive — Out: ZF=1 when NO link session is up (no transport bound,
; or the peer/session is gone). ZF=0 while a session is live. Preserves
; registers; ZF is the result.
; ---------------------------------------------------------------------------
NetHAL_LinkAlive:
    cmp byte [g_net_link_up], 0
    ret

; ---------------------------------------------------------------------------
; NetHAL_StartTransfer — the rSC-write HAL site. The caller has staged its
; send byte in hSerialSendData (and mirrored the GB register state into
; IO_SB/IO_SC). With a live transport this pokes the driver to move data;
; with none it is a no-op. Preserves registers, clobbers flags.
; ---------------------------------------------------------------------------
NetHAL_StartTransfer:
    cmp byte [g_net_transport], NET_TRANSPORT_NONE
    je .idle
    pushad
    movzx eax, byte [g_net_transport]
    call [net_vt_start + eax * 4]
    popad
.idle:
    ret

; Shared null vtable row.
net_null_op:
    ret
