; ===========================================================================
; net_ip.asm — ARP + IPv4 + minimal stop-and-wait TCP transport for the
; link-cable HAL (port-only, no pret counterpart). docs/current_plan_link_cable.md
; Stage 7 step 2. Consumes step 1's src/net/pktdrv.asm (Pktdrv_Send/Recv,
; g_pkt_mac) exactly as ipx_dos.asm consumes IPX and com_uart.asm consumes
; the 16550 — this file is the byte-stream adapter net_frame.asm's codec
; needs, plus everything below it (ARP, IPv4, our own tiny TCP).
;
; ===========================================================================
; SCOPE (ROOT spec): "minimal stop-and-wait TCP" is NOT a general-purpose
; TCP/IP stack — net_frame.asm already provides framing+ARQ over a byte
; stream, so TCP's only job here is to BE that byte stream between two
; DOSBox-X guests. One connection, fixed roles, no congestion control, no
; window scaling, no urgent data, no options ever emitted (an inbound
; segment's data offset is still honored generically, skipping any options
; a real stack might have added, for robustness — see net_ip_handle_tcp).
;   - LISTEN role  (/TCPWAIT[=port], default port 8368): passive open.
;   - CONNECT role (/TCP=a.b.c.d[:port]): active open, 3-way handshake.
;   - Data: at most ONE unacknowledged segment in flight (stop-and-wait;
;     MSS 1460 = TCP_MSS); retransmit on a ~1 s timer; bounded retries (8)
;     -> connection dead -> the codec's cb_dead fires (see net_ip_go_dead).
;   - RX: accept only the in-order segment (seg.seq == rcv_nxt); ACK
;     everything correctly received, including a "duplicate ACK" for an
;     out-of-order/duplicate segment (payload dropped, current rcv_nxt
;     re-acked) — see net_ip_handle_established_data.
;   - FIN: NetIp_Shutdown sends FIN once, no TIME_WAIT ceremony, no wait
;     for its own ack; receiving FIN or RST while handshaking/established
;     -> dead. Nothing here ever SENDS an RST proactively (out of scope).
;   - Checksums: IPv4 header checksum + TCP checksum with pseudo-header,
;     both real (see the "CHECKSUMS" section below) — a real stack (or the
;     peer's own copy of this file) discards an unchecksummed segment.
;   - ARP: resolve the peer directly, or the /GW= gateway when
;     (peer&mask)!=(ip&mask) (net_ip_compute_arp_target); one-entry cache
;     (arp_target_ip/nexthop_mac); we also ANSWER incoming ARP requests for
;     our own /IP= (a slirp/pcap peer, or the other instance of this same
;     code, will ask). Static config only: /IP= /MASK= /GW= — no DHCP (v1;
;     deferred, per the plan).
;
; ===========================================================================
; TCP STATE MACHINE
; ===========================================================================
;   TCPS_CLOSED (0)      — never bound (net_ip_bound=0); NetIp_Init's own
;                           precondition state, never seen once bound.
;   TCPS_LISTEN (1)       — CONNECT role never visits this; passive, waits
;                           forever for a bare SYN (no bound retry budget —
;                           an idle listener isn't "retrying" anything, the
;                           same tolerance UART/IPX have while unconnected).
;   TCPS_ARP_WAIT (2)     — CONNECT role only: resolving nexthop_mac.
;                           Bounded: ARP_MAX_RETRIES(8) -> dead.
;   TCPS_SYN_SENT (3)     — CONNECT: SYN sent, awaiting SYN+ACK. Bounded:
;                           TCP_MAX_RETRIES(8) -> dead.
;   TCPS_SYN_RCVD (4)     — LISTEN: SYN+ACK sent, awaiting the final ACK
;                           (a duplicate inbound SYN here just re-sends the
;                           same SYN-ACK). Bounded -> dead.
;   TCPS_ESTABLISHED (5)  — data phase (net_ip_tx_flush / _handle_established_data).
;   TCPS_DEAD (6)         — terminal; net_ip_go_dead already fired cb_dead.
;                           No auto-reconnect (see DESIGN DECISIONS below).
;
; Events x states (which routine reacts):
;              ARP reply    SYN in      SYN+ACK in   ACK in       FIN/RST   retry timeout
;   LISTEN     -            ->SYN_RCVD  -            -            ignored   n/a (idle)
;   ARP_WAIT   ->SYN_SENT   -           -            -            n/a       ->dead
;   SYN_SENT   -            ignored     ->ESTABLISHED-            ->dead    ->dead
;   SYN_RCVD   -            re-send SA  -            ->ESTABLISHED->dead    ->dead
;   ESTABLISHED-            -           -            adv snd_nxt  ->dead    ->dead
;                                                     + data path
;
; ===========================================================================
; CHECKSUMS (both required — a real stack, or the peer's own copy of this
; file, silently drops an unchecksummed segment)
; ===========================================================================
; Internet checksum (RFC 1071): sum all 16-bit big-endian words, fold any
; carry out of bit 16 back into bit 0 repeatedly, then take the one's
; complement. IPv4: over the 20-byte header alone (no options — this file
; never emits or expects any: ver_ihl is always 0x45). TCP: over a 12-byte
; PSEUDO-header (src ip, dst ip, one zero byte, protocol=6, tcp_length =
; header+payload big-endian) followed by the real TCP header (checksum
; field zeroed while computing) and payload. VALIDATING an inbound
; header/segment sums it WITH its own already-filled checksum field
; included: a correct one folds to exactly 0 (net_ip_checksum_fold, no
; substitution). GENERATING one sums with the field zeroed, then folds +
; complements + substitutes an all-zero result with 0xFFFF, the
; conventional "never transmit an all-zero checksum" rule
; (net_ip_checksum_final). Every 16-bit word is read explicitly as two
; bytes (byte[n]<<8 | byte[n+1]) rather than relying on RFC 1071's
; either-endian-is-fine property — explicit is more auditable, and it is
; exactly what a host-side Python mirror can check bit-for-bit (see the
; step's self-check report). net_ip_checksum_accum/_fold/_final are shared
; by every checksum site in this file.
;
; ===========================================================================
; BYTE ORDER
; ===========================================================================
; Every multi-byte wire field is big-endian. A 16-bit VALUE already held in
; a register (a port number, a checksum, a length) is written to memory as
; `mov [p],ah / mov [p+1],al` — AH is already the value's high byte, no
; shift needed. A 32-bit VALUE (TCP seq/ack) is written as `bswap eax` then
; a native (little-endian) `mov [p],eax`: bswap reverses EAX's 4 bytes, so
; the subsequent little-endian store places the ORIGINAL most-significant
; byte at the lowest address — i.e. big-endian in memory (a standard,
; verifiable idiom: EAX=0x12345678 -> bswap -> 0x78563412 -> stored LE ->
; bytes [0x12,0x34,0x56,0x78], which read left-to-right IS 0x12345678
; big-endian). IP addresses and MAC addresses are plain byte ARRAYS in
; transmission order already (g_net_ip_local[0] is the first octet, etc. —
; the same convention link_book.asm's LBREC.addr and ipx_dos.asm's
; g_net_ipx_peer already use) so they move with a bare `rep movsb`, never a
; value needing a swap. CLI-config PORT NUMBERS (g_net_tcp_listen_port,
; g_net_tcp_peer_port, tcp_local_port, tcp_remote_port) are held as
; ordinary native 16-bit VALUES, not byte-swapped in memory — exactly
; net_hal.asm's own g_net_ipx_socket precedent ("a CPU register/value has
; no byte order until written to a WIRE field; only the wire write needs
; the explicit order").
;
; ===========================================================================
; DESIGN DECISIONS (read before extending this file)
; ===========================================================================
; 1. net_ip_go_dead fires [link_ncb+NFCB.cb_dead] DIRECTLY (mirroring
;    net_frame.asm's own nf_go_dead body exactly: set NFCB.dead=1, guarded,
;    call cb_dead) the instant our OWN raw-TCP retry budget is exhausted or
;    a FIN/RST arrives — rather than leaving it to net_frame's own
;    NF_DEATH_TICKS(600-tick / ~10 s) silence timeout to notice
;    independently (which it eventually WOULD, since a dead raw connection
;    never delivers another byte). This is what the spec's "the codec's
;    cb_dead fires exactly like a UART death" means in practice: the SAME
;    field and callback nf_go_dead uses, just triggered promptly from the
;    transport layer instead of waiting out the blunter generic timeout.
; 2. No auto-reconnect after TCPS_DEAD. The spec frames this as "one
;    connection, fixed roles" for the whole process run; once dead, this
;    transport stays dead (net_ip_tx_flush/_service_timers/_pump all
;    become permanent no-ops for a DEAD state). This is a deliberate
;    scope decision, not an oversight — see the step report's open
;    questions for the alternative (reviving the raw connection from
;    net_session_pump_tail's NS_HELLO bootstrap-recovery branch) and why
;    it was not attempted here.
; 3. A "duplicate SYN while SYN_RCVD" resends the SAME SYN-ACK without
;    checking the segment's source address (LISTEN only ever expects one
;    real peer at a time in this design) — a second, unrelated peer racing
;    a SYN in during our SYN_RCVD window would get a stale reply. Accepted:
;    this transport is a private point-to-point link between exactly two
;    DOSBox-X guests, never a general listener.
; 4. tcp_local_port is TCP_DEFAULT_PORT (8368) on BOTH roles unless
;    /TCPWAIT=port overrides the LISTEN side — there is no CLI knob for a
;    separate CONNECT-side local/ephemeral port (a fixed point-to-point
;    link has no OS-level multiplexing to protect against). Noted as an
;    open question in the step report.
; 5. The final handshake ACK and every "ack a received data segment" ACK
;    are fire-and-forget (net_ip_send_ack -> net_ip_build_and_send
;    directly, bypassing the out_pending retry engine entirely) — if lost,
;    the PEER's own retransmit (of its SYN-ACK, or its unacked data
;    segment) will trigger us to answer again. This is why
;    net_ip_build_and_send takes its flags/payload as PARAMETERS (via the
;    bas_* scratch fields) rather than always reading the tracked
;    out_flags/out_payload_len globals: a fire-and-forget ack must never
;    clobber whatever segment IS currently armed for retry.
;
; ===========================================================================
; net_vt_start (net_hal.asm) — Stage 6 review rule, applied here too: TCP's
; row is net_uart_start DIRECTLY (same as IPX's), NOT a new net_ip_start.
; net_uart_start is pure IO_SB/IO_SC/session-state arm logic with no UART
; access (its own header says so), so it arms establishment/kicks on
; exactly the NetHAL_StartTransfer edges the game generates for EVERY
; transport uniformly. Do not invent a per-tick poll of it.
;
; Build check: nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 \
;              -o /dev/null src/net/net_ip.asm   (from dos_port/)
; ===========================================================================

bits 32

%include "net_frame.inc"

global NetIp_Init
global NetIp_Shutdown
global NetIp_TxByte
global NetIp_RxByte
global net_ip_pump
global g_net_tcp_mode          ; boot/entry.asm — 0 off / 1 WAIT / 2 CONNECT;
                                ; also set by link_ui.asm's TCP connect seam
global g_net_tcp_listen_port   ; boot/entry.asm — /TCPWAIT[=port], default 8368
global g_net_tcp_peer_ip       ; boot/entry.asm + link_ui.asm — /TCP=a.b.c.d
global g_net_tcp_peer_port     ; boot/entry.asm + link_ui.asm — /TCP=...[:port]
global g_net_ip_local          ; boot/entry.asm — /IP=a.b.c.d
global g_net_ip_mask           ; boot/entry.asm — /MASK=a.b.c.d
global g_net_ip_gw             ; boot/entry.asm — /GW=a.b.c.d

extern ds_base                 ; boot/entry.asm — linear base of our DS
extern g_pkt_mac                ; src/net/pktdrv.asm — our NIC MAC
extern Pktdrv_Init
extern Pktdrv_Shutdown
extern Pktdrv_Send
extern Pktdrv_Recv
extern nf_clock                 ; src/net/net_frame.asm — shared wall-clock
                                 ; source (the PIT frame counter) our own
                                 ; retry timers ride, exactly like NFCB's own
extern net_session_pump_tail    ; src/net/net_hal.asm
extern net_pump_ticks           ; src/net/net_hal.asm
extern link_ncb                 ; src/net/net_hal.asm
extern NetFrame_Tick            ; src/net/net_frame.asm

; --- wire/geometry constants ---
FRAME_MAX        equ 1514
ETH_HDR_LEN      equ 14
ARP_PKT_LEN      equ 28              ; ARP payload only (after the ethertype)
IP_HDR_LEN       equ 20
TCP_HDR_LEN      equ 20
IP_PROTO_TCP     equ 6
ETHERTYPE_IP     equ 0x0800
ETHERTYPE_ARP    equ 0x0806
TCP_MSS          equ 1460
RX_STAGE_SIZE    equ TCP_MSS * 2     ; defensive doubling, ipx_dos.asm's own
                                     ; "both [slots] could complete" margin
TCP_DEFAULT_PORT equ 8368

; --- TCP flags (the on-wire flags byte) ---
TCP_FLAG_FIN equ 0x01
TCP_FLAG_SYN equ 0x02
TCP_FLAG_RST equ 0x04
TCP_FLAG_PSH equ 0x08
TCP_FLAG_ACK equ 0x10
TCP_FLAG_URG equ 0x20

; --- TCP states (tcp_state) ---
TCPS_CLOSED      equ 0
TCPS_LISTEN      equ 1
TCPS_ARP_WAIT    equ 2
TCPS_SYN_SENT    equ 3
TCPS_SYN_RCVD    equ 4
TCPS_ESTABLISHED equ 5
TCPS_DEAD        equ 6

; --- retry cadence, in ~60 Hz nf_clock ticks (same clock net_frame.asm's
; own NF_RTX_TICKS/NF_DEATH_TICKS ride — see the file header). "8 bounded
; retries" mirrors NF_MAX_RETRIES's own off-by-one shape EXACTLY (see
; net_ip_service_timers): the counter increments THEN is compared, so the
; total number of transmission attempts before going dead is 1 (initial,
; sent at state-entry) + (N-1) actual retransmissions = N total tries. ---
TCP_RTX_TICKS   equ 60
TCP_MAX_RETRIES equ 8
ARP_RTX_TICKS   equ 60
ARP_MAX_RETRIES equ 8

section .bss
align 4

net_ip_bound: resb 1            ; 1 once NetIp_Init has fully succeeded —
                                 ; idempotent re-Init sentinel (Ipx_Init's
                                 ; own pattern). Survives net_ip_reset_state.

; --- CLI/UI config — NOT touched by net_ip_reset_state; must survive
; repeated NetIp_Init calls exactly like g_net_ipx_socket survives repeated
; Ipx_Init calls. Default 0 = "no flag given" on every field. ---
g_net_tcp_mode:        resb 1
g_net_tcp_listen_port: resw 1
g_net_tcp_peer_ip:     resb 4
g_net_tcp_peer_port:   resw 1
g_net_ip_local:        resb 4
g_net_ip_mask:         resb 4
g_net_ip_gw:           resb 4

; --- everything from here to net_ip_state_end is cleared by
; net_ip_reset_state at each successful NetIp_Init (mirrors
; NetFrame_Reset's own contiguous-block clear). ---
net_ip_state_start:
tcp_state:        resb 1
tcp_local_port:   resw 1
tcp_remote_ip:    resb 4         ; CONNECT: = g_net_tcp_peer_ip; LISTEN:
                                 ; learned from the first inbound SYN
tcp_remote_port:  resw 1
nexthop_mac:      resb 6         ; Ethernet dest for outgoing IP frames —
                                 ; the peer's own MAC if same-subnet, else
                                 ; the gateway's MAC (the ARP cache's one
                                 ; entry; also learned directly from an
                                 ; inbound SYN's Ethernet source on LISTEN,
                                 ; skipping ARP for that role entirely)
arp_target_ip:    resb 4         ; which IP nexthop_mac was resolved for
arp_valid:        resb 1
arp_retries:      resw 1
arp_timer:        resw 1

snd_nxt:          resd 1
rcv_nxt:          resd 1

out_pending:      resb 1         ; 1 = a segment (SYN/SYN-ACK/DATA) is
                                 ; outstanding, tracked for retransmit
out_flags:        resb 1
out_payload_len:  resw 1         ; 0 for a bare SYN/SYN-ACK
out_retries:      resw 1
out_timer:        resw 1
out_payload_buf:  resb TCP_MSS

net_ip_last_clock: resd 1

tx_stage_len:     resw 1
tx_stage:         resb TCP_MSS

rx_stage_len:     resw 1
rx_stage_pos:     resw 1
rx_stage:         resb RX_STAGE_SIZE

ip_id_ctr:        resw 1
net_ip_state_end:

; --- per-poll scratch: rebuilt fresh on every net_ip_rx_drain iteration /
; net_ip_build_and_send call regardless of session state; NOT part of the
; reset block (nothing here needs to survive a re-Init in a meaningful way,
; and nothing here is read across pump ticks). ---
rx_frame_buf:     resb FRAME_MAX
rx_frame_len:     resd 1
tx_frame_buf:     resb FRAME_MAX

tcp_rx_hdr_off:   resd 1
tcp_rx_seg_len:   resd 1
seg_seq:          resd 1
seg_ack:          resd 1
seg_src_port:     resd 1
seg_flags:        resb 1
seg_hdr_len:      resd 1
seg_payload_off:  resd 1
seg_payload_len:  resd 1

bas_flags:        resb 1
bas_payload_ptr:  resd 1
bas_payload_len:  resd 1

section .text

; ===========================================================================
; NetIp_Init — bind the TCP transport (LISTEN or CONNECT per g_net_tcp_mode).
; Out: CF=0 bound, CF=1 no packet driver present, config missing (/IP= or
; /MASK= not both given), or g_net_tcp_mode==0 (not selected). Degrades
; exactly like Ipx_Init/ComUart_Init: the caller (net_hal.asm NetInit)
; leaves the transport unbound. Idempotent (net_ip_bound sentinel).
; ===========================================================================
NetIp_Init:
    cmp byte [net_ip_bound], 0
    jne .already_up
    cmp byte [g_net_tcp_mode], 0
    je .fail
    mov esi, g_net_ip_local
    call net_ip_is_zero4
    jc .fail                        ; /IP= missing
    mov esi, g_net_ip_mask
    call net_ip_is_zero4
    jc .fail                        ; /MASK= missing
    call Pktdrv_Init
    jc .fail                        ; no packet driver present

    call net_ip_reset_state
    cmp byte [g_net_tcp_mode], 1
    je .listen

    ; --- CONNECT (mode 2) ---
    mov esi, g_net_tcp_peer_ip
    mov edi, tcp_remote_ip
    mov ecx, 4
    rep movsb
    mov ax, [g_net_tcp_peer_port]
    mov [tcp_remote_port], ax
    mov word [tcp_local_port], TCP_DEFAULT_PORT
    call net_ip_compute_arp_target
    mov byte [tcp_state], TCPS_ARP_WAIT
    call net_ip_send_arp_request    ; first attempt; arp_retries/timer are
                                     ; already 0 from net_ip_reset_state, so
                                     ; the first retry fires after exactly
                                     ; one ARP_RTX_TICKS interval
    jmp .bound

.listen:
    movzx eax, word [g_net_tcp_listen_port]
    test eax, eax
    jnz .have_port
    mov eax, TCP_DEFAULT_PORT       ; defensive fallback — entry.asm always
                                     ; sets a real value when /TCPWAIT matches
.have_port:
    mov [tcp_local_port], ax
    mov byte [tcp_state], TCPS_LISTEN

.bound:
    mov byte [net_ip_bound], 1
.already_up:
    clc
    ret
.fail:
    stc
    ret

; ---------------------------------------------------------------------------
; NetIp_Shutdown — best-effort single FIN if a connection was ever
; established or mid-handshake ("no TIME_WAIT ceremony" — the spec's own
; phrase: no wait for its ack, no retry). Safe when never bound.
; ---------------------------------------------------------------------------
NetIp_Shutdown:
    cmp byte [net_ip_bound], 0
    je .done
    mov al, [tcp_state]
    cmp al, TCPS_ESTABLISHED
    je .send_fin
    cmp al, TCPS_SYN_SENT
    je .send_fin
    cmp al, TCPS_SYN_RCVD
    je .send_fin
    jmp .no_fin
.send_fin:
    mov al, TCP_FLAG_FIN | TCP_FLAG_ACK
    xor esi, esi
    xor ecx, ecx
    call net_ip_build_and_send
.no_fin:
    call Pktdrv_Shutdown
    mov byte [net_ip_bound], 0
.done:
    ret

; ---------------------------------------------------------------------------
; NetIp_TxByte — append AL to the flat TX staging buffer. Out: CF=0
; appended, CF=1 staging full (byte dropped — net_frame's ARQ recovers,
; exactly ipx_dos.asm's Ipx_TxByte contract). Preserves EBX/ESI/EDI.
; ---------------------------------------------------------------------------
NetIp_TxByte:
    push edx
    movzx edx, word [tx_stage_len]
    cmp edx, TCP_MSS
    jae .full
    mov [tx_stage + edx], al
    inc edx
    mov [tx_stage_len], dx
    pop edx
    clc
    ret
.full:
    pop edx
    stc
    ret

; ---------------------------------------------------------------------------
; NetIp_RxByte — pop one byte from the flat RX staging buffer (refilled by
; net_ip_rx_drain -> net_ip_handle_established_data, BEFORE NetFrame_Tick
; drains it — see net_ip_pump). Out: CF=1 none, else AL=byte. Preserves
; EBX/ESI/EDI.
; ---------------------------------------------------------------------------
NetIp_RxByte:
    push edx
    movzx edx, word [rx_stage_pos]
    cmp dx, [rx_stage_len]
    jae .empty
    mov al, [rx_stage + edx]
    inc edx
    mov [rx_stage_pos], dx
    pop edx
    clc
    ret
.empty:
    pop edx
    stc
    ret

; ===========================================================================
; net_ip_pump — vtable row (net_hal.asm). Shape mirrors ipx_dos_pump: drain
; RX, service our own raw-TCP/ARP timers, run the shared codec Tick, flush
; TX staging TWICE (catches Tick's own RX-drain acks/retransmits, then
; whatever net_session_pump_tail's HELLO/ESTABLISH_REQ queues — see
; ipx_dos.asm's own comment for why two flushes; unchanged reasoning here).
; No net_vt_start row of our own — see the file header.
; ===========================================================================
net_ip_pump:
    inc dword [net_pump_ticks]
    call net_ip_rx_drain
    call net_ip_service_timers
    mov ebx, link_ncb
    call NetFrame_Tick
    call net_ip_tx_flush
    call net_session_pump_tail
    call net_ip_tx_flush
    ret

; ---------------------------------------------------------------------------
; net_ip_rx_drain — drain every queued frame from Pktdrv_Recv (bounded by
; its own 2-slot RX buffer — see pktdrv.asm's own header), demux by
; ethertype. Clobbers EAX/ECX/EDX/ESI/EDI.
; ---------------------------------------------------------------------------
net_ip_rx_drain:
.loop:
    mov edi, rx_frame_buf
    call Pktdrv_Recv
    jc .done
    mov [rx_frame_len], ecx
    cmp ecx, ETH_HDR_LEN
    jb .loop
    lea esi, [rx_frame_buf + 12]
    call net_ip_read_be16
    cmp eax, ETHERTYPE_ARP
    je .arp
    cmp eax, ETHERTYPE_IP
    je .ip
    jmp .loop
.arp:
    call net_ip_handle_arp
    jmp .loop
.ip:
    call net_ip_handle_ip
    jmp .loop
.done:
    ret

; ---------------------------------------------------------------------------
; net_ip_service_timers — ARP-resolve and TCP-handshake/data retransmit
; timers, clocked off net_frame.asm's own [nf_clock] (never pump-call
; counts — see ipx_dos.asm's own documented lesson on why a frame-rate
; timer must not be call-counted: the pump runs far faster than 60 Hz
; inside wait loops). Elapsed ticks since the last call are clamped to
; TCP_RTX_TICKS, mirroring net_frame.asm's own NF_KEEPALIVE_IDLE clamp, so
; a long gap (a busy-wait loop, or the very first call) cannot make a
; single tick look like several seconds elapsed. Clobbers EAX/ECX/EDX.
; ---------------------------------------------------------------------------
net_ip_service_timers:
    mov eax, [nf_clock]
    mov eax, [eax]
    mov ecx, eax
    sub ecx, [net_ip_last_clock]
    mov [net_ip_last_clock], eax
    cmp ecx, TCP_RTX_TICKS
    jbe .clamped
    mov ecx, TCP_RTX_TICKS
.clamped:
    test ecx, ecx
    jz .ret

    mov al, [tcp_state]
    cmp al, TCPS_ARP_WAIT
    je .arp_phase
    cmp al, TCPS_SYN_SENT
    je .tcp_phase
    cmp al, TCPS_SYN_RCVD
    je .tcp_phase
    cmp al, TCPS_ESTABLISHED
    je .tcp_phase
    jmp .ret                        ; LISTEN / DEAD / CLOSED: nothing to time

.arp_phase:
    add [arp_timer], cx
    cmp word [arp_timer], ARP_RTX_TICKS
    jb .ret
    mov word [arp_timer], 0
    inc word [arp_retries]
    cmp word [arp_retries], ARP_MAX_RETRIES
    jae net_ip_go_dead
    call net_ip_send_arp_request
    jmp .ret

.tcp_phase:
    cmp byte [out_pending], 0
    je .ret
    add [out_timer], cx
    cmp word [out_timer], TCP_RTX_TICKS
    jb .ret
    mov word [out_timer], 0
    inc word [out_retries]
    cmp word [out_retries], TCP_MAX_RETRIES
    jae net_ip_go_dead
    call net_ip_send_outstanding
.ret:
    ret

; ---------------------------------------------------------------------------
; net_ip_tx_flush — mirrors ipx_tx_flush's shape: if ESTABLISHED, nothing
; currently outstanding, and app bytes are staged, send them as ONE segment
; (stop-and-wait). If a segment is already outstanding, the staged bytes
; are left queued for the next attempt (never dropped here — only
; NetIp_TxByte's buffer-full path drops). Clobbers EAX/ECX/ESI/EDI.
; ---------------------------------------------------------------------------
net_ip_tx_flush:
    cmp byte [tcp_state], TCPS_ESTABLISHED
    jne .ret
    cmp byte [out_pending], 0
    jne .ret
    cmp word [tx_stage_len], 0
    je .ret
    movzx ecx, word [tx_stage_len]
    mov [out_payload_len], cx
    mov esi, tx_stage
    mov edi, out_payload_buf
    rep movsb
    mov word [tx_stage_len], 0
    mov byte [out_flags], TCP_FLAG_ACK | TCP_FLAG_PSH
    mov byte [out_pending], 1
    mov word [out_retries], 0
    mov word [out_timer], 0
    call net_ip_send_outstanding
.ret:
    ret

; ---------------------------------------------------------------------------
; net_ip_go_dead — our raw TCP connection is permanently dead. Fires the
; codec's cb_dead directly — see DESIGN DECISIONS #1 in the file header.
; Guarded so a second call (e.g. an ARP timeout racing a stray inbound RST
; on the very same tick) never double-fires cb_dead, mirroring
; net_frame.asm's own nf_go_dead guard exactly.
; ---------------------------------------------------------------------------
net_ip_go_dead:
    mov byte [tcp_state], TCPS_DEAD
    mov ebx, link_ncb
    cmp byte [ebx + NFCB.dead], 0
    jne .ret
    mov byte [ebx + NFCB.dead], 1
    call [ebx + NFCB.cb_dead]
.ret:
    ret

; ---------------------------------------------------------------------------
; net_ip_is_zero4 — In: ESI = flat ptr to 4 bytes. Out: CF=1 iff all 4 are
; zero. Clobbers EAX/ECX. (ipx_maybe_latch_peer's own idiom.)
; ---------------------------------------------------------------------------
net_ip_is_zero4:
    xor eax, eax
    mov ecx, 4
.chk:
    or al, [esi + ecx - 1]
    dec ecx
    jnz .chk
    test al, al
    jnz .nonzero
    stc
    ret
.nonzero:
    clc
    ret

; ---------------------------------------------------------------------------
; net_ip_reset_state — zero the contiguous [net_ip_state_start,
; net_ip_state_end) block (NetFrame_Reset's own pattern). Clobbers
; EAX/ECX/EDI.
; ---------------------------------------------------------------------------
net_ip_reset_state:
    mov edi, net_ip_state_start
    mov ecx, net_ip_state_end - net_ip_state_start
    xor eax, eax
    rep stosb
    ret

; ---------------------------------------------------------------------------
; net_ip_compute_arp_target — arp_target_ip = g_net_tcp_peer_ip if
; (peer&mask)==(local&mask), else g_net_ip_gw (spec: "resolve the peer, or
; the /GW= gateway when off-subnet"). Clobbers EAX/EBX/ECX/ESI/EDI.
; ---------------------------------------------------------------------------
net_ip_compute_arp_target:
    xor ecx, ecx
.chk:
    mov al, [g_net_tcp_peer_ip + ecx]
    and al, [g_net_ip_mask + ecx]
    mov bl, [g_net_ip_local + ecx]
    and bl, [g_net_ip_mask + ecx]
    cmp al, bl
    jne .use_gw
    inc ecx
    cmp ecx, 4
    jb .chk
    mov esi, g_net_tcp_peer_ip
    jmp .copy
.use_gw:
    mov esi, g_net_ip_gw
.copy:
    mov edi, arp_target_ip
    mov ecx, 4
    rep movsb
    ret

; ---------------------------------------------------------------------------
; net_ip_roll_iss — Out: EAX = a PIT-latch-derived initial sequence number.
; Not cryptographic — "different enough per run" per real TCP convention;
; nothing here tracks old connections across a process restart anyway.
; Cloned from net_hal.asm's net_roll_token idea rather than shared (that
; routine is file-local there; pktdrv.asm's own precedent for small
; un-factored helpers is to clone, not invent a new shared .inc for one
; routine). Clobbers ECX/EDX.
; ---------------------------------------------------------------------------
net_ip_roll_iss:
    xor al, al
    out 0x43, al
    in al, 0x40
    mov cl, al
    in al, 0x40
    mov ch, al
    xor al, al
    out 0x43, al
    in al, 0x40
    mov dl, al
    in al, 0x40
    mov dh, al
    movzx eax, cx
    shl eax, 16
    movzx edx, dx
    or eax, edx
    ret

; ---------------------------------------------------------------------------
; net_ip_read_be16 — In: ESI = flat ptr. Out: EAX = value (zero-extended).
; Clobbers EDX.
; ---------------------------------------------------------------------------
net_ip_read_be16:
    movzx eax, byte [esi]
    shl eax, 8
    movzx edx, byte [esi + 1]
    or eax, edx
    ret

; ---------------------------------------------------------------------------
; net_ip_read_be32 — In: ESI = flat ptr. Out: EAX = value. Clobbers EDX.
; ---------------------------------------------------------------------------
net_ip_read_be32:
    movzx eax, byte [esi]
    shl eax, 8
    movzx edx, byte [esi + 1]
    or eax, edx
    shl eax, 8
    movzx edx, byte [esi + 2]
    or eax, edx
    shl eax, 8
    movzx edx, byte [esi + 3]
    or eax, edx
    ret

; ---------------------------------------------------------------------------
; net_ip_checksum_accum — internet ones'-complement running sum. In:
; ESI=flat ptr, ECX=byte length (may be odd — the trailing byte is padded
; with an assumed zero LOW byte per RFC 1071), EDX=running 32-bit
; accumulator (0 to start fresh). Out: EDX=updated accumulator, NOT yet
; folded — see net_ip_checksum_fold/_final. Clobbers EAX/ECX/ESI; preserves
; EBX.
; ---------------------------------------------------------------------------
net_ip_checksum_accum:
    push ebx
.word_loop:
    cmp ecx, 2
    jb .maybe_odd
    movzx eax, byte [esi]
    shl eax, 8
    movzx ebx, byte [esi + 1]
    or eax, ebx
    add edx, eax
    add esi, 2
    sub ecx, 2
    jmp .word_loop
.maybe_odd:
    test ecx, ecx
    jz .done
    movzx eax, byte [esi]
    shl eax, 8
    add edx, eax
.done:
    pop ebx
    ret

; net_ip_checksum_fold — In: EDX = raw accumulator. Out: AX = the folded,
; ones'-complemented checksum, WITHOUT the all-zero substitution — used to
; VALIDATE an inbound header/segment (a correct one folds to exactly 0 when
; its own checksum field is included in the sum). Clobbers EAX/EBX.
net_ip_checksum_fold:
    mov eax, edx
.fold:
    mov ebx, eax
    shr ebx, 16
    test ebx, ebx
    jz .folded
    and eax, 0xFFFF
    add eax, ebx
    jmp .fold
.folded:
    not eax
    and eax, 0xFFFF
    ret

; net_ip_checksum_final — same fold, but for GENERATING a checksum to
; write: a fold result of 0 is substituted with 0xFFFF (conventional
; "never transmit an all-zero checksum"). Clobbers EAX/EBX.
net_ip_checksum_final:
    call net_ip_checksum_fold
    test ax, ax
    jnz .ret
    mov ax, 0xFFFF
.ret:
    ret

; ---------------------------------------------------------------------------
; net_ip_send_arp_request — broadcast an ARP request for [arp_target_ip].
; Clobbers EAX/ECX/ESI/EDI.
; ---------------------------------------------------------------------------
net_ip_send_arp_request:
    mov edi, tx_frame_buf
    mov al, 0xFF
    mov ecx, 6
    rep stosb                          ; eth dest = broadcast
    mov esi, g_pkt_mac
    mov ecx, 6
    rep movsb                          ; eth src
    mov al, 0x08
    stosb
    mov al, 0x06
    stosb                              ; ethertype ARP
    mov al, 0x00
    stosb
    mov al, 0x01
    stosb                              ; hwtype=1 (Ethernet)
    mov al, 0x08
    stosb
    mov al, 0x00
    stosb                              ; protype=0x0800 (IP)
    mov al, 6
    stosb
    mov al, 4
    stosb                              ; hwlen/protolen
    mov al, 0x00
    stosb
    mov al, 0x01
    stosb                              ; opcode=1 (request)
    mov esi, g_pkt_mac
    mov ecx, 6
    rep movsb                          ; sha
    mov esi, g_net_ip_local
    mov ecx, 4
    rep movsb                          ; spa
    xor al, al
    mov ecx, 6
    rep stosb                          ; tha = 0 (unknown)
    mov esi, arp_target_ip
    mov ecx, 4
    rep movsb                          ; tpa
    mov ecx, edi
    sub ecx, tx_frame_buf
    mov esi, tx_frame_buf
    call Pktdrv_Send
    ret

; ---------------------------------------------------------------------------
; net_ip_send_arp_reply — the just-received ARP request sits in
; rx_frame_buf (sha at +22, spa at +28 — net_ip_handle_arp's own ARP
; payload offsets). Answers with our own IP bound to g_pkt_mac. Clobbers
; EAX/ECX/ESI/EDI.
; ---------------------------------------------------------------------------
net_ip_send_arp_reply:
    mov edi, tx_frame_buf
    mov esi, rx_frame_buf + 22         ; requester MAC -> eth dest
    mov ecx, 6
    rep movsb
    mov esi, g_pkt_mac
    mov ecx, 6
    rep movsb                          ; eth src
    mov al, 0x08
    stosb
    mov al, 0x06
    stosb
    mov al, 0x00
    stosb
    mov al, 0x01
    stosb
    mov al, 0x08
    stosb
    mov al, 0x00
    stosb
    mov al, 6
    stosb
    mov al, 4
    stosb
    mov al, 0x00
    stosb
    mov al, 0x02
    stosb                              ; opcode=2 (reply)
    mov esi, g_pkt_mac
    mov ecx, 6
    rep movsb                          ; sha = us
    mov esi, g_net_ip_local
    mov ecx, 4
    rep movsb                          ; spa = us
    mov esi, rx_frame_buf + 22
    mov ecx, 6
    rep movsb                          ; tha = requester MAC
    mov esi, rx_frame_buf + 28
    mov ecx, 4
    rep movsb                          ; tpa = requester IP
    mov ecx, edi
    sub ecx, tx_frame_buf
    mov esi, tx_frame_buf
    call Pktdrv_Send
    ret

; ---------------------------------------------------------------------------
; net_ip_handle_arp — [rx_frame_len] set, ethertype already known ARP.
; Answers a request for our own IP; latches a reply matching
; [arp_target_ip] while TCPS_ARP_WAIT. Clobbers EAX/ECX/EDX/ESI/EDI.
; ---------------------------------------------------------------------------
net_ip_handle_arp:
    cmp dword [rx_frame_len], ETH_HDR_LEN + ARP_PKT_LEN
    jb .out
    lea esi, [rx_frame_buf + 14]
    call net_ip_read_be16
    cmp eax, 1
    jne .out                            ; hwtype must be 1 (Ethernet)
    lea esi, [rx_frame_buf + 16]
    call net_ip_read_be16
    cmp eax, ETHERTYPE_IP
    jne .out                            ; protype must be 0x0800
    cmp byte [rx_frame_buf + 18], 6
    jne .out
    cmp byte [rx_frame_buf + 19], 4
    jne .out
    lea esi, [rx_frame_buf + 20]
    call net_ip_read_be16
    cmp eax, 1
    je .req
    cmp eax, 2
    je .reply
    jmp .out
.req:
    mov esi, rx_frame_buf + 38          ; tpa
    mov edi, g_net_ip_local
    mov ecx, 4
    repe cmpsb
    jne .out
    call net_ip_send_arp_reply
    jmp .out
.reply:
    cmp byte [tcp_state], TCPS_ARP_WAIT
    jne .out
    mov esi, rx_frame_buf + 28          ; spa
    mov edi, arp_target_ip
    mov ecx, 4
    repe cmpsb
    jne .out
    mov esi, rx_frame_buf + 22          ; sha
    mov edi, nexthop_mac
    mov ecx, 6
    rep movsb
    mov byte [arp_valid], 1
    call net_ip_start_connect
.out:
    ret

; ---------------------------------------------------------------------------
; net_ip_start_connect — ARP resolved for CONNECT: pick an ISS, transition
; to SYN_SENT, arm and send the SYN.
; ---------------------------------------------------------------------------
net_ip_start_connect:
    call net_ip_roll_iss
    mov [snd_nxt], eax
    mov byte [tcp_state], TCPS_SYN_SENT
    mov byte [out_flags], TCP_FLAG_SYN
    mov word [out_payload_len], 0
    mov byte [out_pending], 1
    mov word [out_retries], 0
    mov word [out_timer], 0
    call net_ip_send_outstanding
    ret

; ---------------------------------------------------------------------------
; net_ip_handle_ip — validate + dispatch one inbound IPv4 frame
; ([rx_frame_len] set, ethertype already known IP). Clobbers
; EAX/ECX/EDX/ESI/EDI.
; ---------------------------------------------------------------------------
net_ip_handle_ip:
    cmp dword [rx_frame_len], ETH_HDR_LEN + IP_HDR_LEN
    jb .out
    cmp byte [rx_frame_buf + 14], 0x45      ; ver=4 ihl=5 (no IP options)
    jne .out

    xor edx, edx
    lea esi, [rx_frame_buf + 14]
    mov ecx, IP_HDR_LEN
    call net_ip_checksum_accum
    call net_ip_checksum_fold
    test ax, ax
    jnz .out

    cmp byte [rx_frame_buf + 14 + 9], IP_PROTO_TCP
    jne .out

    mov esi, rx_frame_buf + 14 + 16         ; dest ip
    mov edi, g_net_ip_local
    mov ecx, 4
    repe cmpsb
    jne .out

    lea esi, [rx_frame_buf + 14 + 2]
    call net_ip_read_be16                   ; EAX = IP total length
    cmp eax, IP_HDR_LEN + TCP_HDR_LEN
    jb .out
    mov ecx, eax
    add ecx, ETH_HDR_LEN
    cmp ecx, [rx_frame_len]
    ja .out                                 ; claims more than we received

    cmp byte [tcp_state], TCPS_LISTEN
    je .dispatch
    push eax
    mov esi, rx_frame_buf + 14 + 12         ; src ip
    mov edi, tcp_remote_ip
    mov ecx, 4
    repe cmpsb
    pop eax
    jne .out
.dispatch:
    call net_ip_handle_tcp                  ; In: EAX = IP total length
.out:
    ret

; ---------------------------------------------------------------------------
; net_ip_handle_tcp — In: EAX = IP total length. Dispatches by tcp_state.
; Clobbers EAX/EBX/ECX/EDX/ESI/EDI.
; ---------------------------------------------------------------------------
net_ip_handle_tcp:
    sub eax, IP_HDR_LEN
    mov [tcp_rx_seg_len], eax
    cmp eax, TCP_HDR_LEN
    jb .out
    lea eax, [rx_frame_buf + 34]            ; IHL forced to 5 by handle_ip
    mov [tcp_rx_hdr_off], eax

    call net_ip_verify_tcp_checksum
    jc .out

    mov esi, [tcp_rx_hdr_off]
    lea esi, [esi + 2]
    call net_ip_read_be16                   ; dst port
    movzx edx, word [tcp_local_port]
    cmp eax, edx
    jne .out

    mov esi, [tcp_rx_hdr_off]
    mov al, [esi + 12]
    shr al, 4
    movzx ecx, al
    shl ecx, 2
    cmp ecx, [tcp_rx_seg_len]
    ja .out
    mov [seg_hdr_len], ecx

    mov al, [esi + 13]
    mov [seg_flags], al

    mov esi, [tcp_rx_hdr_off]
    call net_ip_read_be16                   ; src port (offset 0)
    mov [seg_src_port], eax

    mov esi, [tcp_rx_hdr_off]
    lea esi, [esi + 4]
    call net_ip_read_be32                   ; seq
    mov [seg_seq], eax

    mov esi, [tcp_rx_hdr_off]
    lea esi, [esi + 8]
    call net_ip_read_be32                   ; ack
    mov [seg_ack], eax

    mov eax, [tcp_rx_seg_len]
    sub eax, [seg_hdr_len]
    mov [seg_payload_len], eax
    mov eax, [tcp_rx_hdr_off]
    add eax, [seg_hdr_len]
    mov [seg_payload_off], eax

    test byte [seg_flags], TCP_FLAG_RST
    jnz .maybe_dead
    test byte [seg_flags], TCP_FLAG_FIN
    jz .dispatch
.maybe_dead:
    cmp byte [tcp_state], TCPS_ESTABLISHED
    je .go_dead
    cmp byte [tcp_state], TCPS_SYN_SENT
    je .go_dead
    cmp byte [tcp_state], TCPS_SYN_RCVD
    je .go_dead
    jmp .out                                ; RST/FIN outside an active
                                             ; connection: ignore
.go_dead:
    call net_ip_go_dead
    jmp .out

.dispatch:
    mov al, [tcp_state]
    cmp al, TCPS_LISTEN
    je .st_listen
    cmp al, TCPS_SYN_SENT
    je .st_syn_sent
    cmp al, TCPS_SYN_RCVD
    je .st_syn_rcvd
    cmp al, TCPS_ESTABLISHED
    je .st_established
    jmp .out                                ; ARP_WAIT/DEAD/CLOSED: ignore

.st_listen:
    test byte [seg_flags], TCP_FLAG_SYN
    jz .out
    test byte [seg_flags], TCP_FLAG_ACK
    jnz .out
    mov esi, rx_frame_buf + 14 + 12         ; peer ip
    mov edi, tcp_remote_ip
    mov ecx, 4
    rep movsb
    mov eax, [seg_src_port]
    mov [tcp_remote_port], ax
    mov esi, rx_frame_buf + 6               ; peer MAC (eth src)
    mov edi, nexthop_mac
    mov ecx, 6
    rep movsb
    mov eax, [seg_seq]
    inc eax
    mov [rcv_nxt], eax
    call net_ip_roll_iss
    mov [snd_nxt], eax
    mov byte [tcp_state], TCPS_SYN_RCVD
    mov byte [out_flags], TCP_FLAG_SYN | TCP_FLAG_ACK
    mov word [out_payload_len], 0
    mov byte [out_pending], 1
    mov word [out_retries], 0
    mov word [out_timer], 0
    call net_ip_send_outstanding
    jmp .out

.st_syn_rcvd:
    test byte [seg_flags], TCP_FLAG_SYN
    jz .syn_rcvd_ack
    call net_ip_send_outstanding            ; duplicate SYN: resend our
                                             ; existing SYN-ACK, no new ISS
    jmp .out
.syn_rcvd_ack:
    test byte [seg_flags], TCP_FLAG_ACK
    jz .out
    mov eax, [snd_nxt]
    inc eax
    cmp eax, [seg_ack]
    jne .out
    mov [snd_nxt], eax
    mov byte [out_pending], 0
    mov byte [tcp_state], TCPS_ESTABLISHED
    call net_ip_handle_established_data     ; the ACK may piggyback data
    jmp .out

.st_syn_sent:
    test byte [seg_flags], TCP_FLAG_SYN
    jz .out
    test byte [seg_flags], TCP_FLAG_ACK
    jz .out                                 ; simultaneous-open SYN: not
                                             ; modeled (fixed roles) — ignore
    mov eax, [snd_nxt]
    inc eax
    cmp eax, [seg_ack]
    jne .out
    mov [snd_nxt], eax
    mov eax, [seg_seq]
    inc eax
    mov [rcv_nxt], eax
    mov byte [out_pending], 0
    mov byte [tcp_state], TCPS_ESTABLISHED
    call net_ip_send_ack                    ; final handshake ACK — fire-
                                             ; and-forget, not retry-tracked
    jmp .out

.st_established:
    test byte [seg_flags], TCP_FLAG_ACK
    jz .est_data
    cmp byte [out_pending], 0
    je .est_data
    movzx edx, word [out_payload_len]       ; always >0 here: ESTABLISHED
                                             ; only ever has a DATA segment
                                             ; outstanding (SYN/FIN never
                                             ; use out_pending while
                                             ; ESTABLISHED — see DESIGN
                                             ; DECISIONS #5 in the header)
    mov eax, [snd_nxt]
    add eax, edx
    cmp eax, [seg_ack]
    jne .est_data
    mov [snd_nxt], eax
    mov byte [out_pending], 0
.est_data:
    call net_ip_handle_established_data
.out:
    ret

; ---------------------------------------------------------------------------
; net_ip_handle_established_data — call only when tcp_state==ESTABLISHED
; and a checksum-valid segment addressed to us is staged in seg_*. A
; payload-carrying segment: in-order (seg_seq==rcv_nxt) -> append to
; rx_stage, advance rcv_nxt, ack it; out-of-order/duplicate, or one that
; would overflow rx_stage -> drop the payload, ack the CURRENT (unchanged)
; rcv_nxt — a "duplicate ACK", the spec's own phrase. A payload-free
; segment needs no action here (its ack bookkeeping is the caller's job).
; Clobbers EAX/ECX/EDX/ESI/EDI.
; ---------------------------------------------------------------------------
net_ip_handle_established_data:
    mov eax, [seg_payload_len]
    test eax, eax
    jz .ret
    ; Recycle the staging buffer whenever the codec has fully drained it
    ; (pos==len). Without this, rx_stage_len grows monotonically over the
    ; CONNECTION's lifetime — the len/pos pair is cumulative, unlike
    ; ipx_dos.asm's, which zeroes both at every refill because a datagram
    ; tick fully replaces the staging contents — and after RX_STAGE_SIZE
    ; total bytes received the fit-check below rejects every further
    ; in-order segment forever (dup-ack -> peer retransmits -> peer dead).
    ; NetFrame_Tick's .rx_loop drains until CF=1 every tick, so pos==len
    ; holds at every drain that follows a Tick, making this effectively a
    ; per-tick reset; if a partial drain ever left pos<len the data is
    ; still intact and the reset simply waits for the next full drain.
    ; (ROOT review fix, Stage 7 step 2.)
    mov cx, [rx_stage_pos]
    cmp cx, [rx_stage_len]
    jne .no_recycle
    mov word [rx_stage_pos], 0
    mov word [rx_stage_len], 0
.no_recycle:
    mov edx, [seg_seq]
    cmp edx, [rcv_nxt]
    jne .send_ack
    movzx ecx, word [rx_stage_len]
    add ecx, eax
    cmp ecx, RX_STAGE_SIZE
    ja .send_ack
    movzx edi, word [rx_stage_len]
    add edi, rx_stage
    mov esi, [seg_payload_off]
    mov ecx, eax
    rep movsb
    add [rx_stage_len], ax
    add [rcv_nxt], eax
.send_ack:
    call net_ip_send_ack
.ret:
    ret

; ---------------------------------------------------------------------------
; net_ip_send_outstanding — (re)send the currently TRACKED segment (out_
; flags/out_payload_len/out_payload_buf). Used both for a fresh arm-and-send
; and for a plain retransmit (net_ip_service_timers) — same bytes either
; way, since nothing here mutates seq numbers.
; ---------------------------------------------------------------------------
net_ip_send_outstanding:
    movzx ecx, word [out_payload_len]
    mov esi, out_payload_buf
    mov al, [out_flags]
    call net_ip_build_and_send
    ret

; ---------------------------------------------------------------------------
; net_ip_send_ack — a bare, UNTRACKED ack (no retry, no out_pending) —
; DESIGN DECISIONS #5 in the file header explains why this must never touch
; out_flags/out_payload_len.
; ---------------------------------------------------------------------------
net_ip_send_ack:
    xor ecx, ecx
    xor esi, esi
    mov al, TCP_FLAG_ACK
    call net_ip_build_and_send
    ret

; ---------------------------------------------------------------------------
; net_ip_build_and_send — build one Ethernet/IPv4/TCP frame using the
; CURRENT snd_nxt (seq) / rcv_nxt (ack, written only when TCP_FLAG_ACK is
; set) and hand it to Pktdrv_Send. Touches NEITHER snd_nxt/rcv_nxt NOR any
; out_* retry-tracking field — see DESIGN DECISIONS #5.
; In: AL = TCP flags byte, ESI = flat payload ptr (ignored if ECX=0),
; ECX = payload length (0..TCP_MSS).
; Clobbers EAX/EBX/ECX/EDX/ESI/EDI.
; ---------------------------------------------------------------------------
net_ip_build_and_send:
    mov [bas_flags], al
    mov [bas_payload_ptr], esi
    mov [bas_payload_len], ecx

    mov edi, tx_frame_buf
    mov esi, nexthop_mac
    mov ecx, 6
    rep movsb                          ; eth dest
    mov esi, g_pkt_mac
    mov ecx, 6
    rep movsb                          ; eth src
    mov al, 0x08
    stosb
    xor al, al
    stosb                              ; ethertype 0x0800 = IP

    mov ebx, edi                       ; EBX = IP header start (temporarily)
    mov al, 0x45
    stosb                              ; ver/ihl
    xor al, al
    stosb                              ; tos
    mov eax, [bas_payload_len]
    add eax, IP_HDR_LEN + TCP_HDR_LEN
    mov [edi], ah
    mov [edi + 1], al
    add edi, 2                         ; total length
    movzx eax, word [ip_id_ctr]
    inc word [ip_id_ctr]
    mov [edi], ah
    mov [edi + 1], al
    add edi, 2                         ; identification
    mov al, 0x40
    stosb
    xor al, al
    stosb                              ; flags(DF)/frag offset
    mov al, 64
    stosb                              ; TTL
    mov al, IP_PROTO_TCP
    stosb                              ; protocol
    xor ax, ax
    stosw                              ; checksum placeholder
    mov esi, g_net_ip_local
    mov ecx, 4
    rep movsb                          ; src ip
    mov esi, tcp_remote_ip
    mov ecx, 4
    rep movsb                          ; dst ip; EDI is now the TCP hdr start

    xor edx, edx
    mov esi, ebx
    mov ecx, IP_HDR_LEN
    call net_ip_checksum_accum
    call net_ip_checksum_final
    mov [ebx + 10], ah
    mov [ebx + 11], al

    mov ebx, edi                       ; EBX = TCP header start (IP header
                                        ; done; reuse EBX for the rest —
                                        ; net_ip_tcp_checksum takes it too)
    movzx eax, word [tcp_local_port]
    mov [edi], ah
    mov [edi + 1], al
    add edi, 2
    movzx eax, word [tcp_remote_port]
    mov [edi], ah
    mov [edi + 1], al
    add edi, 2
    mov eax, [snd_nxt]
    bswap eax
    mov [edi], eax
    add edi, 4                         ; seq
    xor eax, eax
    test byte [bas_flags], TCP_FLAG_ACK
    jz .no_ack_field
    mov eax, [rcv_nxt]
.no_ack_field:
    bswap eax
    mov [edi], eax
    add edi, 4                         ; ack
    mov byte [edi], (TCP_HDR_LEN / 4) << 4   ; data offset=5, reserved=0
    inc edi
    mov al, [bas_flags]
    stosb                              ; flags
    mov ax, 2048
    mov [edi], ah
    mov [edi + 1], al
    add edi, 2                         ; window
    xor ax, ax
    stosw                              ; TCP checksum placeholder
    xor ax, ax
    stosw                              ; urgent pointer

    mov ecx, [bas_payload_len]
    test ecx, ecx
    jz .no_payload
    mov esi, [bas_payload_ptr]
    rep movsb
.no_payload:
    call net_ip_tcp_checksum           ; In: EBX = TCP header start; Out: AX
    mov [ebx + 16], ah
    mov [ebx + 17], al

    mov ecx, edi
    sub ecx, tx_frame_buf
    mov esi, tx_frame_buf
    call Pktdrv_Send
    ret

; ---------------------------------------------------------------------------
; net_ip_tcp_checksum — GENERATE the checksum for the segment being built.
; In: EBX = flat ptr to the TCP header (payload, if any, already appended
; right after it — [bas_payload_len] gives its length; the checksum field
; must be zero, as net_ip_build_and_send leaves it). Out: AX = checksum to
; write. Clobbers EAX/ECX/EDX/ESI/EDI; preserves EBX.
; ---------------------------------------------------------------------------
net_ip_tcp_checksum:
    sub esp, 12
    mov edi, esp
    mov esi, g_net_ip_local
    movsd
    mov esi, tcp_remote_ip
    movsd
    mov byte [edi], 0
    inc edi
    mov byte [edi], IP_PROTO_TCP
    inc edi
    mov eax, [bas_payload_len]
    add eax, TCP_HDR_LEN
    mov [edi], ah
    mov [edi + 1], al

    xor edx, edx
    mov esi, esp
    mov ecx, 12
    call net_ip_checksum_accum

    mov esi, ebx
    mov ecx, [bas_payload_len]
    add ecx, TCP_HDR_LEN
    call net_ip_checksum_accum

    call net_ip_checksum_final
    add esp, 12
    ret

; ---------------------------------------------------------------------------
; net_ip_verify_tcp_checksum — VALIDATE [tcp_rx_seg_len] bytes at
; [tcp_rx_hdr_off], using the pseudo-header built from the RECEIVED IP
; header's own src/dst fields (correct even before tcp_remote_ip has been
; learned — the very first inbound SYN on a LISTEN role). Out: CF=0 valid /
; CF=1 bad. Clobbers EAX/EBX/ECX/EDX/ESI/EDI.
; ---------------------------------------------------------------------------
net_ip_verify_tcp_checksum:
    sub esp, 12
    mov edi, esp
    mov esi, rx_frame_buf + 14 + 12    ; src ip (received IP header)
    movsd
    mov esi, rx_frame_buf + 14 + 16    ; dst ip
    movsd
    mov byte [edi], 0
    inc edi
    mov byte [edi], IP_PROTO_TCP
    inc edi
    mov eax, [tcp_rx_seg_len]
    mov [edi], ah
    mov [edi + 1], al

    xor edx, edx
    mov esi, esp
    mov ecx, 12
    call net_ip_checksum_accum

    mov esi, [tcp_rx_hdr_off]
    mov ecx, [tcp_rx_seg_len]
    call net_ip_checksum_accum

    call net_ip_checksum_fold
    add esp, 12
    test ax, ax
    jnz .bad
    clc
    ret
.bad:
    stc
    ret
