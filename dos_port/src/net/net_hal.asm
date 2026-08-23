; ===========================================================================
; net_hal.asm — link-cable network HAL: session core + transport vtable
; (port-only, no pret counterpart). docs/current_plan_link_cable.md Stage 2.
;
; This is the layer BELOW the home/serial.asm HAL line. The pret serial
; primitives keep their register/WRAM/HRAM contracts and call down here at
; the points where the GB touched rSC or relied on the serial interrupt:
;
;   NetHAL_StartTransfer — the `rSC = SC_START|*` sites.
;   NetHAL_Pump          — polled from DelayFrame (beside audio_tick) and
;                          from the primitives' wait loops.
;   NetHAL_LinkAlive     — ZF=1 when no link session is up; the primitives'
;                          no-partner escape hatches branch on it (each hatch
;                          carries its own class=HAL deviation in serial.asm).
;
; SESSION DESIGN (the "election maps onto the GB's own establishment
; exchange" scheme — plan §"Key design"):
;
; 1. Boot: /COM1-4 binds the UART transport (com_uart.asm) under the
;    net_frame codec, rolls a 32-bit token from PIT latches, and sends a
;    reliable HELLO {proto_ver, game_gen, build_id, token}. Both sides do
;    this symmetrically; the ARQ keeps retrying, and if the codec dies
;    while still in HELLO (peer not launched yet) the session silently
;    resets and re-sends — pret's own receptionist timeout is the only
;    user-facing bound.
; 2. On receiving the peer HELLO: proto/game_gen mismatch -> refuse (stay
;    down; the game sees pret's no-partner path). Token compare: greater
;    token = GB MASTER; equal = re-roll and re-send. Both sides compute the
;    same answer from the same two tokens. Session is UP (link alive).
; 3. Establishment: when the game's CableClubNPC race arms an establish
;    transfer (IO_SB = $01/$02 + NetHAL_StartTransfer), send one reliable
;    ESTABLISH_REQ (EXCH with exch_id 0). When BOTH sides have armed
;    (local flag + peer's REQ received), synthesize the GB exchange: the
;    elected master "receives" $02 and the slave "receives" $01, delivered
;    through the pret `Serial` handler — hSerialConnectionStatus becomes
;    pret's own USING_INTERNAL/EXTERNAL_CLOCK and every downstream
;    tie-break runs verbatim pret. A peer whose player is not at the
;    receptionist never sends REQ, so the 90-frame race times out exactly
;    as pret's no-partner path.
; 4. Established single-byte exchange = one EXCH message pair (1 RTT):
;    master kick (SC_INTERNAL) sends EXCH{++exch_ctr, hSerialSendData};
;    the slave replies with the same exch_id and its own staged byte, and
;    both sides deliver through `Serial`. The GB's one-transfer rSB
;    pipeline delay is deliberately NOT modeled — the primitives' repeat/
;    drain protocols are insensitive to it, and the message-level seam is
;    already the annotated deviation. exch_id is lockstep-checked; a
;    mismatch is a detected desync -> session down (the primitives' hatches
;    then drive pret terminal paths).
; 5. Codec death (ARQ exhaustion / silence) after UP -> session down.
; 6. Block exchange (Stage 3): Serial_ExchangeBytes' 17/424/200-byte blocks
;    cross as ONE reliable NF_BLK each way per exchange (the plan's
;    message-level seam table), never as per-byte EXCH lockstep. Both sides
;    call NetHAL_ExchangeBlock symmetrically: send own block with a
;    monotonic block id, wait for the peer's; ids and lengths must match or
;    it is a detected desync -> session down. The peer's block can arrive
;    BEFORE our own call (the peer runs ahead inside the same rendezvous
;    window), so delivery stages it in a one-deep buffer; one-deep is
;    sufficient because the peer cannot complete exchange N (and so cannot
;    send N+1) until it has received OUR block N. Block traffic is not
;    /LINKLOG'd — the ring records single-byte exchanges only, and the
;    tradecheck harness asserts block content end-to-end from the party
;    data instead.
;
; Register contract: NetHAL_* preserve all GP registers (pushad around the
; transport work); flags are clobbered (LinkAlive's ZF IS its result).
; Session internals run inside that pushad and clobber freely.
;
; Build check: nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 \
;              -o /dev/null src/net/net_hal.asm   (from dos_port/)
; ===========================================================================

bits 32

%include "gb_memmap.inc"
%include "net_frame.inc"

global NetHAL_Pump
global NetHAL_LinkAlive
global NetHAL_StartTransfer
global NetHAL_ExchangeBlock
global NetInit
global NetShutdown
global g_net_transport
global g_net_link_up
global g_peer_game_gen
global g_net_com_sel
global g_net_baud_div
global g_net_linklog
global g_nlog_count                 ; /LINKLOG ring (debug_dump.asm dumps it)
global g_nlog_buf
global net_role_master              ; session diagnostics, read by the
global net_state                    ; DEBUG_LINKCHECK GBSTATE probe regions
global net_desyncs                  ; (debug_dump.asm gbregion_flat rows)
global net_estab_local              ; ..estab_peer/estab_pend/kick_open follow
global net_exch_ctr
global net_pump_ticks
global link_ncb                     ; raw NFCB, parsed host-side by linkcheck
global net_uart_start                ; Stage 6 step 1: despite the name this is
                                    ; pure GB-register/session-state logic (no
                                    ; UART calls); the NET_TRANSPORT_IPX
                                    ; net_vt_start row points at it directly
                                    ; (see the vtable comment below)
global net_session_pump_tail         ; Stage 6 step 1: net_uart_pump's HELLO/
                                    ; ESTABLISH_REQ flush logic, factored out
                                    ; so ipx_dos_pump shares it verbatim instead
                                    ; of cloning ~30 lines of transport-agnostic
                                    ; session bookkeeping
global g_net_ipx_sel                ; /IPX flag (boot/entry.asm), consumed here
global g_net_ipx_socket              ; /IPXSOCK=n override, default 0x869C
                                    ; (DOSBox-X's dynamic-range convention);
                                    ; src/net/ipx_dos.asm reads it at Open Socket

extern NetFrame_Reset               ; src/net/net_frame.asm
extern NetFrame_SendMsg
extern NetFrame_Tick
extern ComUart_Init                 ; src/net/com_uart.asm
extern ComUart_Shutdown
extern ComUart_TxByte
extern ComUart_RxByte
extern Ipx_Init                     ; src/net/ipx_dos.asm
extern Ipx_Shutdown
extern Ipx_TxByte
extern Ipx_RxByte
extern ipx_dos_pump
extern Serial                       ; src/home/serial.asm — the pret handler;
                                    ; delivery = stage IO_SB, call it

; Transport ids (vtable rows). CLI flags/UI select by storing g_net_transport.
NET_TRANSPORT_NONE  equ 0
NET_TRANSPORT_UART  equ 1
NET_TRANSPORT_IPX   equ 2
NET_TRANSPORT_COUNT equ 3

; Session states
NS_IDLE         equ 0               ; no transport bound
NS_HELLO        equ 1               ; HELLO sent, awaiting peer's
NS_UP           equ 2               ; elected; session alive
NS_ESTABLISHED  equ 3               ; GB establishment synthesized
NS_DOWN         equ 4               ; was up, died (desync/transport death)

NET_PROTO_VER   equ 1
NET_GAME_GEN    equ 1               ; Gen I (full byte reserved — maintainer)

; GB serial constants used by the synthesis (constants/serial_constants.asm)
USING_EXTERNAL_CLOCK equ 0x01
USING_INTERNAL_CLOCK equ 0x02
SC_INTERNAL_BIT      equ 0x01       ; rSC bit 0: 1 = internal clock (master)

section .bss

g_net_transport resb 1              ; NET_TRANSPORT_* bound (0 = none)
g_net_link_up   resb 1              ; 1 = session alive (NS_UP or later)
g_peer_game_gen resb 1              ; peer's game_gen from HELLO
g_net_com_sel   resb 1              ; /COM1-4 -> 1..4 (0 = none given)
g_net_linklog   resb 1              ; /LINKLOG flag (consumed in Stage 2 step 5)
net_pump_lock   resb 1              ; pump reentrancy guard
g_net_ipx_sel   resb 1              ; /IPX flag (Stage 6 step 1; 0 = not selected)
align 2
g_net_baud_div  resw 1              ; /BAUD=n -> 115200/n (0 = default 115200)

net_state       resb 1              ; NS_*
net_role_master resb 1              ; 1 = elected GB master
net_refused     resb 1              ; peer HELLO failed validation
net_hello_pend  resb 1              ; HELLO (re)send queued
net_estab_local resb 1              ; our game armed an establish transfer
net_estab_peer  resb 1              ; peer's ESTABLISH_REQ arrived
net_estab_pend  resb 1              ; our ESTABLISH_REQ queued
net_kick_open   resb 1              ; master: kicked, awaiting slave reply
align 4
net_token       resd 1              ; our election token
net_peer_token  resd 1
net_exch_ctr    resw 1              ; monotonic exchange counter (lockstep)
net_desyncs     resw 1              ; diagnostic
net_pump_ticks  resd 1              ; diagnostic: net_uart_pump entries
hello_buf       resb 8              ; staged HELLO payload
exch_buf        resb 4              ; staged EXCH payload
; block exchange (design note 6 above): args snapshot + one-deep RX stage
net_blk_ctr     resw 1              ; monotonic block id (lockstep, like exch)
blk_tx_off      resd 1              ; caller's send GB offset
blk_rx_off      resd 1              ; caller's receive GB offset
blk_len         resw 1              ; caller's byte count
blk_rx_id       resw 1              ; staged peer block: id
blk_rx_len      resw 1              ;   ..length
blk_rx_have     resb 1              ;   ..1 = staged and unconsumed
blk_rx_buf      resb NET_MAX_PAYLOAD
link_ncb        resb NFCB.size      ; the one live codec instance

; /LINKLOG exchange ring — one 4-byte record per REAL exchange byte (exch_id
; >= 1; establishment synthesis and ESTABLISH_REQ are net bookkeeping, not
; cable bytes, and are excluded so two sides' logs cross-check as A.tx == B.rx).
; Record: {u8 dir (0=TX 1=RX), u8 gb_byte, u16 exch_id LE}. Saturating, not
; wrapping: the cross-check compares whole sequences from exchange 1, and a
; wrapped ring would silently drop the front. Port-only diagnostic data —
; little-endian is fine (the big-endian rule is for GB game data).
NLOG_MAX        equ 4096
align 4
g_nlog_count    resd 1              ; records written (saturates at NLOG_MAX)
g_nlog_buf      resb NLOG_MAX * 4

section .data

; /IPXSOCK=n override target — DOSBox-X's dynamic socket range convention is
; fine as a fixed default; entry.asm overwrites it before NetInit runs.
align 2
g_net_ipx_socket: dw 0x869C

; Transport vtable, indexed by g_net_transport. Row 0 = null transport.
net_vt_pump:
    dd net_null_op                  ; NET_TRANSPORT_NONE
    dd net_uart_pump                ; NET_TRANSPORT_UART
    dd ipx_dos_pump                 ; NET_TRANSPORT_IPX
net_vt_start:
    dd net_null_op
    dd net_uart_start
    dd net_uart_start               ; NET_TRANSPORT_IPX: same row — despite the
                                    ; name this routine is pure IO_SB/IO_SC/
                                    ; session-state arm logic with no UART
                                    ; access (see its header), so IPX arms and
                                    ; kicks on exactly the NetHAL_StartTransfer
                                    ; edges the game generates, byte-for-byte
                                    ; the UART transport's proven timing. A
                                    ; per-tick poll was rejected in review: it
                                    ; would keep kicking the STALE staged
                                    ; IO_SC/hSerialSendData after the game
                                    ; leaves an exchange loop, sending
                                    ; exchanges the UART transport never sends.

section .text

; ---------------------------------------------------------------------------
; NetInit — bind the transport selected on the command line (nothing given =
; single-player, byte-identical behavior: both branches below are gated on
; their own sel flag, default 0, so a plain run with no /COMx or /IPX takes
; neither and NetInit is a pushad/popad no-op exactly as before this step).
; Runs from boot/entry.asm after joypad_init. Preserves all registers.
;
; Re-callable (the link-cable UI re-invokes this on every connect attempt —
; src/net/link_ui.asm): the IPX branch only runs when g_net_transport is
; STILL NONE after the COM branch, so a stale g_net_com_sel/g_net_ipx_sel
; left over from an earlier FAILED attempt in the same run can never clobber
; an already-bound transport — by the time either branch could re-fire,
; g_net_transport is provably NONE (LinkTransportSelect's own top-level guard
; skips the whole UI once a transport is bound, so this file never observes a
; retry after success, only after a failure that left it NONE).
; ---------------------------------------------------------------------------
NetInit:
    pushad
    cmp byte [g_net_com_sel], 0
    je .try_ipx                     ; no /COMx: fall through to IPX
    call ComUart_Init
    jc .try_ipx                     ; no UART present: degrade, try IPX next
    mov ebx, link_ncb
    mov dword [ebx + NFCB.cb_txbyte],  ComUart_TxByte
    mov dword [ebx + NFCB.cb_rxbyte],  ComUart_RxByte
    mov dword [ebx + NFCB.cb_deliver], net_session_deliver
    mov dword [ebx + NFCB.cb_dead],    net_session_dead
    mov al, NET_TRANSPORT_UART
    call net_bind_common
    jmp .done
.try_ipx:
    cmp byte [g_net_transport], NET_TRANSPORT_NONE
    jne .done                       ; already bound (defensive; see header)
    cmp byte [g_net_ipx_sel], 0
    je .done                        ; no /IPX: stay unbound
    call Ipx_Init
    jc .done                        ; no IPX stack: degrade, never hang
    mov ebx, link_ncb
    mov dword [ebx + NFCB.cb_txbyte],  Ipx_TxByte
    mov dword [ebx + NFCB.cb_rxbyte],  Ipx_RxByte
    mov dword [ebx + NFCB.cb_deliver], net_session_deliver
    mov dword [ebx + NFCB.cb_dead],    net_session_dead
    mov al, NET_TRANSPORT_IPX
    call net_bind_common
.done:
    popad
    ret

; ---------------------------------------------------------------------------
; net_bind_common — the tail shared by both NetInit branches once their NFCB
; callbacks are wired: reset the codec, latch the transport id, roll the
; election token, and queue the first HELLO. In: AL = NET_TRANSPORT_*,
; EBX = link_ncb (callbacks already stored by the caller).
; ---------------------------------------------------------------------------
net_bind_common:
    push eax
    call NetFrame_Reset
    pop eax
    mov [g_net_transport], al
    call net_roll_token
    mov byte [net_state], NS_HELLO
    mov byte [net_hello_pend], 1    ; sent from the first pump tick
    ret

; ---------------------------------------------------------------------------
; NetShutdown — from cleanup (boot/entry.asm). Preserves all registers.
; ---------------------------------------------------------------------------
NetShutdown:
    pushad
    call ComUart_Shutdown           ; safe when never bound
    call Ipx_Shutdown               ; safe when never bound
    mov byte [g_net_transport], NET_TRANSPORT_NONE
    mov byte [g_net_link_up], 0
    mov byte [net_state], NS_IDLE
    popad
    ret

; ---------------------------------------------------------------------------
; net_roll_token — 32-bit election token from two PIT counter latches (the
; two machines' PIT phases differ; ties re-roll through here again mixed
; with the old token, so even an unlucky collision cannot persist).
; ---------------------------------------------------------------------------
net_roll_token:
    xor al, al
    out 0x43, al                    ; latch counter 0
    in al, 0x40
    mov cl, al
    in al, 0x40
    mov ch, al                      ; CX = latch 1
    movzx ecx, cx
    mov eax, [net_token]
    imul eax, eax, 5
    inc eax                         ; old*5+1 (pret's own RNG step shape)
    shl ecx, 16
    xor eax, ecx
    xor al, al
    out 0x43, al
    in al, 0x40
    mov cl, al
    in al, 0x40
    mov ch, al
    movzx ecx, cx
    xor eax, ecx
    mov [net_token], eax
    ret

; ---------------------------------------------------------------------------
; NetHAL_Pump — poll the bound transport. Once per frame from DelayFrame and
; ad hoc from the serial primitives' wait loops. Fast no-op while unbound.
; Preserves registers, clobbers flags.
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
; NetHAL_LinkAlive — ZF=1 when NO link session is up. Preserves registers.
; ---------------------------------------------------------------------------
NetHAL_LinkAlive:
    cmp byte [g_net_link_up], 0
    ret

; ---------------------------------------------------------------------------
; NetHAL_StartTransfer — the rSC-write HAL site. The caller staged its GB
; state (IO_SB/IO_SC/hSerialSendData) first. Preserves registers.
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

net_null_op:
    ret

; ---------------------------------------------------------------------------
; NetHAL_ExchangeBlock — one whole-block exchange (design note 6). Both sides
; call this symmetrically from Serial_ExchangeBytes' HAL cut.
; In:  ESI = send data GB offset, EDX = receive data GB offset,
;      BX = length (1..NET_MAX_PAYLOAD).
; Out: on success the peer's block is copied into [EBP+EDX..+BX). On session
;      death or desync nothing is copied and the session is down — the caller
;      re-checks NetHAL_LinkAlive and takes its no-partner hatch. Preserves
;      all GP registers; clobbers flags (the NetHAL_* contract).
; The wait loops are tight pump polls with no DelayFrame: pret's own block
; exchange runs with rIE narrowed to IE_SERIAL, i.e. the frame loop is frozen
; for its duration, and the ARQ timers advance by wall frames of the PIT
; tick_count regardless (net_frame.inc), so codec death still bounds the wait.
; ---------------------------------------------------------------------------
NetHAL_ExchangeBlock:
    cmp byte [g_net_transport], NET_TRANSPORT_NONE
    je .idle
    mov [blk_tx_off], esi
    mov [blk_rx_off], edx
    mov [blk_len], bx
    pushad
    cmp byte [net_state], NS_ESTABLISHED
    jne .out
    inc word [net_blk_ctr]
.send_wait:
    call NetHAL_Pump
    cmp byte [g_net_link_up], 0
    je .out                         ; died while our previous frame drained
    mov ebx, link_ncb
    cmp byte [ebx + NFCB.tx_out], 0
    jne .send_wait                  ; a kick/keepalive is still unacked
    mov al, NF_BLK
    mov cx, [net_blk_ctr]
    mov esi, [blk_tx_off]
    lea esi, [ebp + esi]            ; SendMsg copies from a flat pointer
    mov dx, [blk_len]
    call NetFrame_SendMsg
    jc .send_wait                   ; refused (raced a pump send): retry
.recv_wait:
    call NetHAL_Pump
    cmp byte [g_net_link_up], 0
    je .out                         ; died waiting for the peer's block
    cmp byte [blk_rx_have], 0
    je .recv_wait
    ; peer's block staged: lockstep id + length must match
    mov ax, [blk_rx_id]
    cmp ax, [net_blk_ctr]
    jne .desync
    mov ax, [blk_rx_len]
    cmp ax, [blk_len]
    jne .desync
    movzx ecx, ax
    mov esi, blk_rx_buf
    mov edi, [blk_rx_off]
    lea edi, [ebp + edi]
    rep movsb
    mov byte [blk_rx_have], 0
.out:
    popad
.idle:
    ret
.desync:
    inc word [net_desyncs]
    call net_session_down
    jmp .out

; ---------------------------------------------------------------------------
; net_log_rec — append one /LINKLOG record. In: AH = dir (0=TX 1=RX),
; AL = GB byte, CX = exch_id. No-op unless /LINKLOG was given. Preserves
; all registers and does not touch the codec, so it is safe at any point
; in the session paths.
; ---------------------------------------------------------------------------
net_log_rec:
    cmp byte [g_net_linklog], 0
    je .off
    pushad
    mov edx, [g_nlog_count]
    cmp edx, NLOG_MAX
    jae .full                       ; saturate (see the ring comment in .bss)
    lea edi, [g_nlog_buf + edx * 4]
    mov [edi], ah                   ; dir
    mov [edi + 1], al               ; byte
    mov [edi + 2], cx               ; exch_id (LE, port-only diagnostic)
    inc dword [g_nlog_count]
.full:
    popad
.off:
    ret

; ===========================================================================
; UART transport row (session logic; the byte layer is com_uart.asm)
; ===========================================================================

; ---------------------------------------------------------------------------
; net_uart_pump — tick the codec, then run session upkeep + queued sends.
; ---------------------------------------------------------------------------
net_uart_pump:
    inc dword [net_pump_ticks]
    mov ebx, link_ncb
    call NetFrame_Tick
    call net_session_pump_tail
    ret

; ---------------------------------------------------------------------------
; net_session_pump_tail — bootstrap recovery + queued HELLO/ESTABLISH_REQ
; flush. Factored out of net_uart_pump (Stage 6 step 1) so ipx_dos_pump
; shares it verbatim instead of cloning this transport-agnostic session
; bookkeeping: everything here reads/writes net_state/net_hello_pend/
; net_estab_pend and the codec's own NFCB fields, never touches a byte
; transport directly. In: EBX = link_ncb, already Tick'd by the caller.
; ---------------------------------------------------------------------------
net_session_pump_tail:
    ; bootstrap recovery: a codec that dies while still in HELLO just means
    ; the peer isn't up yet — reset and keep offering
    cmp byte [net_state], NS_HELLO
    jne .not_hello
    cmp byte [ebx + NFCB.dead], 0
    je .flush
    call NetFrame_Reset
    mov byte [net_hello_pend], 1
    jmp .flush
.not_hello:
.flush:
    ; queued HELLO
    cmp byte [net_hello_pend], 0
    je .no_hello
    cmp byte [ebx + NFCB.tx_out], 0
    jne .no_hello
    cmp byte [ebx + NFCB.dead], 0
    jne .no_hello
    call net_send_hello
.no_hello:
    ; queued ESTABLISH_REQ
    cmp byte [net_estab_pend], 0
    je .no_req
    cmp byte [ebx + NFCB.tx_out], 0
    jne .no_req
    mov al, NF_EXCH
    xor ecx, ecx                    ; exch_id 0 = ESTABLISH_REQ
    mov esi, exch_buf
    mov dx, 1
    call NetFrame_SendMsg
    jc .no_req
    mov byte [net_estab_pend], 0
    call net_try_establish
.no_req:
    ret

; ---------------------------------------------------------------------------
; net_send_hello — build + send the HELLO. Clears the pend flag on success.
; EBX = link_ncb.
; ---------------------------------------------------------------------------
net_send_hello:
    mov byte [hello_buf + 0], NET_PROTO_VER
    mov byte [hello_buf + 1], NET_GAME_GEN
    mov word [hello_buf + 2], (BUG_FIX_LEVEL << 8) | NET_PROTO_VER
                                    ; build_id: BUG_FIX_LEVEL is the one build
                                    ; axis that changes behavior today; a
                                    ; content hash is a recorded open item
    mov eax, [net_token]
    mov [hello_buf + 4], eax
    mov al, NF_HELLO
    xor ecx, ecx
    mov esi, hello_buf
    mov dx, 8
    call NetFrame_SendMsg
    jc .ret
    mov byte [net_hello_pend], 0
.ret:
    ret

; ---------------------------------------------------------------------------
; net_uart_start — the game armed a transfer. EBX not assumed.
;
; Despite the name, everything below is GB-register/session-state logic
; (IO_SB, IO_SC, net_role_master, net_estab_*, net_kick_open, net_exch_ctr) —
; it never touches the UART. That is exactly why Stage 6 step 1 made it
; `global` and calls it a second way: as the UART vtable's edge-triggered
; `start` row (via NetHAL_StartTransfer, unchanged) AND polled once per tick
; from ipx_dos_pump (src/net/ipx_dos.asm), since a datagram transport has no
; hardware line to kick synchronously the way a UART register write does.
; Both call sites are safe together because every branch below self-guards
; on net_state/net_estab_local/net_estab_pend/net_kick_open, so a redundant
; poll when nothing is armed is just an early `ret`.
; ---------------------------------------------------------------------------
net_uart_start:
    mov ebx, link_ncb
    mov al, [net_state]
    cmp al, NS_UP
    je .maybe_establish
    cmp al, NS_ESTABLISHED
    je .maybe_kick
    ret
.maybe_establish:
    ; establishment race arm? (CableClubNPC stages $01/$02 in rSB)
    mov al, [ebp + IO_SB]
    cmp al, 1
    je .arm
    cmp al, 2
    jne .ret
.arm:
    cmp byte [net_estab_local], 0
    jne .ret                        ; already armed + REQ queued/sent
    mov byte [net_estab_local], 1
    mov [exch_buf], al              ; carry the staged byte (diagnostic)
    mov byte [net_estab_pend], 1    ; sent from pump when the codec is free
    call net_try_establish          ; peer's REQ may already be here
.ret:
    ret
.maybe_kick:
    ; master kick: SC_INTERNAL armed and no exchange in flight
    cmp byte [net_role_master], 0
    je .ret
    mov al, [ebp + IO_SC]
    test al, SC_INTERNAL_BIT
    jz .ret
    cmp byte [net_estab_pend], 0
    jne .ret                        ; our ESTABLISH_REQ is still queued: a kick
                                    ; sent now OVERTAKES it (kicks go out
                                    ; synchronously, the REQ from the next pump
                                    ; tick), reaches the peer while it is still
                                    ; NS_UP, and is codec-acked but dropped —
                                    ; then never resent, wedging net_kick_open
                                    ; shut for the whole session (measured in
                                    ; linkcheck 2026-08-22: tx_seq showed
                                    ; HELLO=1 EXCH=2 REQ=3 on the wire). The
                                    ; skipped kick costs nothing: the zero-byte
                                    ; and nybble senders re-arm every frame.
    cmp byte [net_kick_open], 0
    jne .ret                        ; previous exchange still completing —
                                    ; frame-paced callers re-kick next frame
    cmp byte [ebx + NFCB.tx_out], 0
    jne .ret
    mov ax, [net_exch_ctr]
    inc ax
    mov [net_exch_ctr], ax
    mov cx, ax
    mov al, [ebp + hSerialSendData]
    mov [exch_buf], al
    mov al, NF_EXCH
    mov esi, exch_buf
    mov dx, 1
    call NetFrame_SendMsg
    jnc .kicked
    dec word [net_exch_ctr]         ; refused: retry on the next kick
    ret
.kicked:
    mov al, [exch_buf]
    mov cx, [net_exch_ctr]
    xor ah, ah                      ; /LINKLOG: TX of the kick byte
    call net_log_rec
    mov byte [net_kick_open], 1
    ret

; ---------------------------------------------------------------------------
; net_session_deliver — codec upcall: a reliable message arrived.
; In: AL=type, CX=exch_id, ESI=payload (flat), DX=len. EBX = link_ncb.
; ---------------------------------------------------------------------------
net_session_deliver:
    cmp al, NF_HELLO
    je .hello
    cmp al, NF_BLK
    je .blk
    cmp al, NF_EXCH
    jne .ret
    test cx, cx
    jz .estab_req
    jmp .exch
.ret:
    ret

.blk:
    ; stage the peer's block (one-deep — see design note 6). An overrun means
    ; the peer ran a second exchange before we consumed the first, which the
    ; lockstep makes impossible unless the streams diverged: detected desync.
    cmp byte [net_state], NS_ESTABLISHED
    jne .ret
    cmp byte [blk_rx_have], 0
    jne .blk_overrun
    mov [blk_rx_id], cx
    mov [blk_rx_len], dx
    movzx ecx, dx
    mov edi, blk_rx_buf
    rep movsb                       ; ESI = codec rx_buf (flat)
    mov byte [blk_rx_have], 1
    ret
.blk_overrun:
    inc word [net_desyncs]
    jmp net_session_down

.hello:
    cmp dx, 8
    jb .ret
    mov al, [esi + 0]
    cmp al, NET_PROTO_VER
    jne .refuse
    mov al, [esi + 1]
    mov [g_peer_game_gen], al
    cmp al, NET_GAME_GEN            ; v1: require Gen I (byte reserved for
    jne .refuse                     ; the planned Gen II — maintainer)
    mov ax, [esi + 2]
    cmp ax, (BUG_FIX_LEVEL << 8) | NET_PROTO_VER
    jne .refuse
    mov eax, [esi + 4]
    mov [net_peer_token], eax
    ; election: greater token = GB master; equal = re-roll and re-offer
    cmp eax, [net_token]
    je .tie
    mov cl, 0
    ja .decided                     ; peer greater -> we are slave
    mov cl, 1                       ; we are greater -> master
.decided:
    mov [net_role_master], cl
    mov byte [net_state], NS_UP
    mov byte [g_net_link_up], 1
    ret
.tie:
    call net_roll_token
    mov byte [net_hello_pend], 1    ; re-offer with the new token
    ret
.refuse:
    mov byte [net_refused], 1       ; stay down: the game sees pret's
    ret                             ; no-partner timeout path

.estab_req:
    cmp byte [net_state], NS_UP
    jne .ret
    mov byte [net_estab_peer], 1
    jmp net_try_establish

.exch:
    cmp byte [net_state], NS_ESTABLISHED
    jne .ret
    cmp byte [net_role_master], 0
    jne .master_reply
    ; ---- slave: master's kick arrived ----
    mov ax, [net_exch_ctr]
    inc ax
    cmp cx, ax
    jne .desync                     ; lockstep check
    mov [net_exch_ctr], ax
    ; reply with our currently staged byte, same exch_id
    mov al, [ebp + hSerialSendData]
    mov [exch_buf], al
    push ecx
    push dword [esi]                ; master's byte (payload[0]) — ESI may be
                                    ; the codec rx_buf, invalid after sends
    xor ah, ah
    call net_log_rec                ; /LINKLOG: TX of the reply (CX = exch_id)
    mov al, NF_EXCH
    mov esi, exch_buf
    mov dx, 1
    call NetFrame_SendMsg           ; refused only if outstanding: cannot be —
                                    ; the codec just delivered, so our ack
                                    ; went out and nothing else is in flight
    pop eax                         ; AL = master's byte
    pop ecx
    mov ah, 1                       ; /LINKLOG: RX of the master's byte
    call net_log_rec
    jmp net_deliver_gb_byte
.master_reply:
    ; ---- master: slave's reply to our kick ----
    cmp cx, [net_exch_ctr]
    jne .desync
    mov byte [net_kick_open], 0
    mov al, [esi]
    mov ah, 1                       ; /LINKLOG: RX of the reply (CX = exch_id)
    call net_log_rec
    jmp net_deliver_gb_byte
.desync:
    inc word [net_desyncs]
    jmp net_session_down

; ---------------------------------------------------------------------------
; net_try_establish — both sides armed? Then synthesize the GB establishment
; exchange: master "receives" $02 (-> USING_INTERNAL_CLOCK), slave $01
; (-> USING_EXTERNAL_CLOCK), through the pret Serial handler, exactly what
; each side's ISR would have latched from the peer's staged rSB offer.
; ---------------------------------------------------------------------------
net_try_establish:
    cmp byte [net_state], NS_UP
    jne .ret
    cmp byte [net_estab_local], 0
    je .ret
    cmp byte [net_estab_peer], 0
    je .ret
    mov byte [net_state], NS_ESTABLISHED
    mov word [net_exch_ctr], 0
    mov word [net_blk_ctr], 0
    mov byte [blk_rx_have], 0
    mov byte [net_kick_open], 0
    mov byte [net_estab_local], 0
    mov byte [net_estab_peer], 0
    mov al, USING_EXTERNAL_CLOCK    ; slave receives the master's $01 offer
    cmp byte [net_role_master], 0
    je net_deliver_gb_byte
    mov al, USING_INTERNAL_CLOCK    ; master receives the slave's $02 offer
    jmp net_deliver_gb_byte
.ret:
    ret

; ---------------------------------------------------------------------------
; net_deliver_gb_byte — AL = the byte "received over the cable": stage it in
; the virtual rSB and run the pret Serial handler (delivery = what the
; hardware serial interrupt did).
; ---------------------------------------------------------------------------
net_deliver_gb_byte:
    mov [ebp + IO_SB], al
    call Serial
    ret

; ---------------------------------------------------------------------------
; net_session_dead — codec upcall on ARQ exhaustion / silence.
; ---------------------------------------------------------------------------
net_session_dead:
    cmp byte [net_state], NS_HELLO
    jne net_session_down            ; peer was there and is gone
    ret                             ; still offering: pump resets + re-sends

net_session_down:
    mov byte [net_state], NS_DOWN
    mov byte [g_net_link_up], 0
    mov byte [net_kick_open], 0
    mov byte [blk_rx_have], 0
    ret
