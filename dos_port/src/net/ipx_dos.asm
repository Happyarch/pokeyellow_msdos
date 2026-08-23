; ===========================================================================
; ipx_dos.asm — Novell IPX transport driver for the link-cable HAL (port-only,
; no pret counterpart). docs/current_plan_link_cable.md Stage 6 step 1.
;
; com_uart.asm is the shape template (Init/Shutdown/pump + byte-callback
; contract), but IPX is DATAGRAM, not a byte stream: the frame codec
; (net_frame.asm) needs a continuous byte pipe, so this file adapts one --
; see "DATAGRAM<->BYTE-STREAM ADAPTATION" below, which is this file's real
; design content. Everything else (session election, establishment, EXCH/BLK
; semantics) is unchanged and lives in net_hal.asm; this file only replaces
; com_uart.asm's role of moving bytes.
;
; ===========================================================================
; THE NOVELL IPX API CONTRACT (per the Stage 6 spec's Novell IPX contract;
; RBIL "INT 7A" / "INT 2F/AX=7A00" for a second source)
; ===========================================================================
; Detection: DPMI 0300h ("simulate real mode interrupt") reflects INT 2Fh
; with AX=7A00h. IPX is present iff AL==0xFF on return; ES:DI in the returned
; rmcs is then the real-mode FAR ENTRY POINT of the IPX dispatcher — not an
; interrupt vector, a plain code address the driver expects to be CALLED.
;
; Every subsequent IPX operation goes through THAT entry point with a
; function code in BX, invoked via DPMI 0301h ("call real-mode procedure
; with far return frame"). This is the repo's FIRST 0301h user (dsv_io.asm
; and debug_dump.asm use only 0300h, which reflects a real INT n and needs no
; entry point — the "which real-mode routine" is the vector table). 0301h is
; different: there is no interrupt number, so the rmcs's CS:IP fields name
; the callee directly, and the DPMI host itself synthesizes a real-mode far
; return frame so that when the callee (the IPX driver) executes its own
; RETF, control returns to the DPMI host, which resumes us in protected mode
; with the rmcs's register fields updated to whatever the callee left in the
; real registers — functionally identical to 0300h's "the simulated
; interrupt handler IRET'd, here's what changed" contract, just reached via
; CALL instead of INT. ipx_call_real (below) is the one place this project
; issues 0301h; every IPX operation funnels through it.
;
; Function codes (BX) used here:
;   0000h Open Socket    — AL=0 (short-lived), DX=socket number.
;                           Out: AL=0 ok / 0xFE in use / 0xFF table full;
;                           DX=assigned socket.
;   0001h Close Socket   — DX=socket.
;   0003h Send Packet    — ES:SI = ECB (real-mode address).
;   0004h Listen For Packet — ES:SI = ECB.
;   0009h Get Internetwork Address — ES:SI -> 10-byte real-mode buffer
;                           receiving net(4)+node(6).
;   000Ah Relinquish Control — give the (real-mode) IPX driver polling time;
;                           DOSBox-X's IPX emulation processes RX on this and
;                           on other entry calls, so the pump calls it once
;                           per tick before checking listen ECBs.
;
; Register byte order — a subtlety worth being explicit about, because it is
; NOT symmetric between registers and memory: DX for Open/Close Socket is a
; plain x86 register value loaded with the socket constant AS WRITTEN
; (`mov dx, 0x869C` already puts DH=0x86/DL=0x9C, i.e. the natural "first two
; hex digits, then the next two" reading order — there is nothing to swap,
; because a CPU register has no byte order until it is stored to memory).
; The ECB's SocketNumber FIELD (a `dw` the driver reads directly out of
; real-mode memory) is genuinely big-endian on the wire, so it is written
; one byte at a time (high byte first) — see ipx_post_listen / ipx_tx_flush.
; "The API takes it as-is — use one constant" (the spec's phrasing) means:
; g_net_ipx_socket's bit pattern is correct for BOTH uses without any
; runtime swap; only the MEMORY writes need the explicit byte order.
;
; ECB (Event Control Block) layout, all fields REAL-MODE memory (per spec):
;   +0  dd Link/ESR address (0 = no ESR — POLLED, no callbacks taken)
;   +4  dd (second dword of the ESR field region — historic; kept zero)
;   +8  db InUse (nonzero while owned by IPX; 0 = complete/free)
;   +9  db CompletionCode (0 = success)
;   +10 dw SocketNumber (BIG-ENDIAN)
;   +12 db[16] IPXWorkspace(4)+DriverWorkspace(12) — driver-owned scratch,
;       left zeroed by us and never read back
;   +28 db[6] ImmediateAddress (next-hop node; same-net = dest node)
;   +34 dw FragmentCount (always 1 here — one descriptor per datagram)
;   +36 dd FragmentAddress (real-mode SEGMENT:OFFSET, OFFSET word first)
;   +40 dw FragmentSize
;   = 42 bytes; ECB_ALIGN (44) is the per-instance stride in our DOS block so
;   each ECB starts 4-byte aligned.
;
; IPX packet header (30 bytes, BIG-ENDIAN multi-byte fields), sits at the
; start of every fragment buffer, payload immediately after it at +30:
;   +0  dw checksum = 0xFFFF (no checksum)
;   +2  dw length (header+payload total; WE fill this on send — the spec
;       note "IPX fills on send" describes some stacks auto-computing it,
;       but nothing in this contract says ours does, so ipx_tx_flush sets it
;       explicitly; a received datagram's OWN length field, filled by
;       whichever peer sent it, is how ipx_rx_drain_one recovers the true
;       payload size — see its comment)
;   +4  db transportControl = 0
;   +5  db packetType = 4 (IPX)
;   +6  dest: net(4) node(6) socket(2)
;   +18 src:  net(4) node(6) socket(2)
;
; Broadcast (AUTO peer search): dest net = 0 (same net), dest node =
; FF:FF:FF:FF:FF:FF, ECB.ImmediateAddress = the broadcast node too.
; ===========================================================================
;
; ===========================================================================
; DATAGRAM<->BYTE-STREAM ADAPTATION
; ===========================================================================
; net_frame.asm needs a byte-wise cb_txbyte/cb_rxbyte pair; IPX only offers
; whole datagrams. The design rests on one fact confirmed by READING
; net_frame.asm (src/net/net_frame.asm), not assumed:
;
;   EVERY individual transmission is written by a single synchronous,
;   uninterrupted loop that calls cb_txbyte for each of that ONE frame's
;   bytes back-to-back, with no other code able to run in between (this is
;   single-threaded polled code — no ISR, no reentrancy). Concretely:
;     - nf_tx_stored (initial sends AND every retransmit) loops
;       `[ecb].tx_buf[0..tx_len)` through cb_txbyte in one straight-line pass.
;     - nf_send_ctl (ACK / KEEPALIVE) builds its 10-byte control frame on the
;       stack and loops it through cb_txbyte the same way.
;   So at the granularity of "one call to nf_tx_stored or nf_send_ctl", the
;   bytes emitted ARE a complete, contiguous frame — concatenating several
;   such bursts in one buffer (in the order they were written) can never
;   split a frame internally, because each burst is atomic and whole.
;
; What can happen within or across ONE NetFrame_Tick call is MULTIPLE such
; bursts: the RX drain loop acks each newly-delivered reliable frame inline
; (nf_send_ctl, 10 B) as part of nf_rx_frame; the timer-service tail can
; ALSO fire a retransmit (nf_tx_stored, up to 522 B: 1+NF_HDR_LEN+
; NET_MAX_PAYLOAD+2) and, independently, a keepalive (nf_send_ctl, 10 B) in
; the same call if the elapsed-tick delta is large enough to satisfy both
; thresholds at once. And net_hal.asm's session tail (net_send_hello /
; net_uart_start's EXCH kick / NetHAL_ExchangeBlock's NF_BLK) calls
; NetFrame_SendMsg directly, sometimes from inside NetFrame_Tick's own RX
; delivery (Serial -> NetHAL_StartTransfer, re-arming a slave transfer while
; still inside nf_rx_frame's dispatch) and sometimes from plain pump-adjacent
; code outside this file. None of these EVER interleave with each other
; byte-for-byte (still single-threaded), so they just accumulate as more
; complete frames appended to whatever's already staged.
;
; Conclusion: Ipx_TxByte does NOT need to track frame boundaries at all — it
; can be a dumb append to a flat staging buffer. ipx_tx_flush (called from
; ipx_dos_pump) sends the ENTIRE staged buffer as ONE datagram whenever it is
; non-empty and the send ECB is free; whatever is staged is, by the argument
; above, always a whole number of complete frames, so concatenating them
; into one IPX packet never splits any individual frame — the RX side's
; nf_rx_byte state machine hunts SOF and parses byte-by-byte regardless of
; datagram boundaries, exactly as it already does for the UART's continuous
; stream, so multiple frames landing in one packet is transparent to it.
;
; ipx_dos_pump flushes TWICE per tick (not once, contrary to a naive reading
; of "flush after Tick"): once right after NetFrame_Tick (catches the RX
; drain's acks + Tick's own retransmit/keepalive), and again after the
; net_session_pump_tail HELLO/ESTABLISH_REQ session logic that net_uart_pump
; also runs after Tick in the same call — otherwise a HELLO/EXCH queued by
; that tail would sit unflushed for one whole extra pump call. Since
; NetHAL_Pump is called every DelayFrame AND repeatedly from busy-wait loops,
; that would usually be sub-frame anyway, but two cheap flush attempts (each
; a no-op when tx_stage is empty or the send ECB is still busy) costs nothing
; and removes the question. See ipx_dos_pump.
;
; RX mirrors this: ipx_rx_refill drains any COMPLETED listen ECB's payload
; (header stripped) into a flat RX staging buffer once per pump tick, then
; NetFrame_Tick's own rx_loop pops it byte-by-byte via Ipx_RxByte exactly as
; it would pop UART bytes — Tick always drains RX staging down to empty
; before returning (its loop runs until Ipx_RxByte returns CF=1), so
; ipx_rx_refill is free to reset the staging cursors to 0 at the top of every
; refill without ever discarding an unconsumed byte from the previous tick.
;
; DEGRADE-SAFELY CONTRACT (matches ComUart_TxByte's THRE-timeout drop and
; ComUart_RxByte's ring-full drop): Ipx_TxByte drops a byte (CF=1) only if
; the bounded TX staging buffer is completely full — this can only corrupt
; whichever frame was mid-write, which then fails the peer's CRC and is
; silently discarded, and the ARQ retransmits it after NF_RTX_TICKS. A
; datagram send that finds the send ECB still busy is NOT dropped — the
; staged bytes are simply left queued for the next flush attempt (no data
; loss, only a short delay). A completed listen ECB whose payload would
; overflow the bounded RX staging buffer is dropped the same "ARQ recovers"
; way. No busy-wait loop in this file lacks a bounded exit: every DPMI call
; is a single 0301h/0300h invocation (host-bounded), and every buffer
; operation is a fixed-count copy or a capacity check that returns early.
;
; Register contract: called from NetInit/NetShutdown (boot/cleanup) and from
; net_hal.asm's NetHAL_Pump pushad (same convention as com_uart.asm) —
; clobbers freely, preserves nothing beyond what a normal `call` implies.
;
; Build check: nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 \
;              -o /dev/null src/net/ipx_dos.asm   (from dos_port/)
; ===========================================================================

bits 32

%include "net_frame.inc"

global Ipx_Init
global Ipx_Shutdown
global Ipx_TxByte
global Ipx_RxByte
global ipx_dos_pump
global g_net_ipx_peer

extern ds_base                      ; boot/entry.asm — linear base of our DS
extern g_net_ipx_socket             ; src/net/net_hal.asm — /IPXSOCK= override,
                                    ; default 0x869C (net_hal.asm's .data)
extern net_session_pump_tail        ; src/net/net_hal.asm — HELLO/ESTABLISH_REQ
                                    ; flush state machine factored out of
                                    ; net_uart_pump so IPX shares it verbatim
                                    ; instead of cloning ~30 lines
extern net_pump_ticks               ; src/net/net_hal.asm — diagnostic counter,
                                    ; incremented by whichever transport pumps
extern link_ncb                     ; src/net/net_hal.asm — the one live NFCB
extern NetFrame_Tick                ; src/net/net_frame.asm

; --- DPMI real-mode call structure field offsets (DPMI 0.9 spec; full set —
; dsv_io.asm only needed a subset since it only ever used 0300h with
; register args, never ES/EDI-as-input or CS:IP-as-target) ---
RMCS_EDI     equ 0x00
RMCS_ESI     equ 0x04
RMCS_EBP     equ 0x08
RMCS_EBX     equ 0x10
RMCS_EDX     equ 0x14
RMCS_ECX     equ 0x18
RMCS_EAX     equ 0x1C
RMCS_FLAGS   equ 0x20
RMCS_ES      equ 0x22
RMCS_DS      equ 0x24
RMCS_FS      equ 0x26
RMCS_GS      equ 0x28
RMCS_IP      equ 0x2A
RMCS_CS      equ 0x2C
RMCS_SP      equ 0x2E
RMCS_SS      equ 0x30
RMCS_SIZE    equ 0x32

; --- wire/geometry constants ---
IPX_HDR_LEN     equ 30              ; IPX packet header size
ECB_LEN         equ 42              ; live ECB fields, +0..+41
ECB_ALIGN       equ 44              ; per-instance stride (42 rounded to 4)

; Per-flush payload budget: comfortably above one max NF frame (522 B =
; 1+NF_HDR_LEN+NET_MAX_PAYLOAD+2) with slack for a same-tick ACK/keepalive
; piggyback (10 B each — see the adaptation note above on multi-burst
; Ticks). Ipx_TxByte drops bytes past this bound (degrade-safely contract).
IPX_PAYLOAD_MAX equ 600
IPX_FRAG_LEN    equ IPX_HDR_LEN + IPX_PAYLOAD_MAX   ; 630: one full fragment
                                                     ; buffer, header+payload
RX_STAGE_SIZE   equ 2 * IPX_PAYLOAD_MAX             ; both listen ECBs could
                                                     ; complete in one refill

; --- ONE DOS conventional-memory block, layout (offsets from its real-mode
; segment:0 — DPMI 0100h allocations start paragraph-aligned, so offset 0 is
; trivially 4-aligned and every ECB_ALIGN stride keeps the next one aligned
; too): 2 listen ECBs + their RX fragment buffers, 1 send ECB + its TX
; fragment buffer, then the 10-byte Get-Internetwork-Address scratch. ---
OFF_ECB_LISTEN0  equ 0
OFF_ECB_LISTEN1  equ OFF_ECB_LISTEN0 + ECB_ALIGN            ; 44
OFF_ECB_SEND     equ OFF_ECB_LISTEN1 + ECB_ALIGN            ; 88
OFF_RXBUF0       equ OFF_ECB_SEND + ECB_ALIGN               ; 132
OFF_RXBUF1       equ OFF_RXBUF0 + IPX_FRAG_LEN              ; 762
OFF_TXBUF        equ OFF_RXBUF1 + IPX_FRAG_LEN              ; 1392
OFF_ADDR_SCRATCH equ OFF_TXBUF + IPX_FRAG_LEN                ; 2022
BLOCK_SIZE       equ OFF_ADDR_SCRATCH + 10                   ; 2032
BLOCK_PARAS      equ (BLOCK_SIZE + 15) / 16                  ; 127 paragraphs

section .bss
align 4
rmcs:            resb RMCS_SIZE

ipx_bound:       resb 1              ; 1 once Ipx_Init has fully succeeded —
                                     ; makes it a safe idempotent re-call
ipx_seg:         resw 1              ; real-mode segment of the DOS block
ipx_sel:         resw 1              ; PM selector of the DOS block (DPMI
                                     ; 0100h "already allocated" sentinel,
                                     ; dsv_ensure_buffer's own pattern)
ipx_flat:        resd 1              ; DS-relative flat pointer to the block
ipx_entry_seg:   resw 1              ; IPX dispatcher far entry point,
ipx_entry_off:   resw 1              ; cached from detection
ipx_socket_assigned: resw 1          ; socket number Open Socket handed back
ipx_own_addr:    resb 10             ; our own net(4)+node(6), cached at Init

; peer addressing (link_ui.asm pokes this before binding — see the file
; header's ADAPTATION note is about bytes, this is about WHO they go to):
; all-zero = AUTO/broadcast search; non-zero = direct net+node from a book
; record or a latched first-responder. Same 10-byte layout link_ui.asm's
; LBREC.addr / lu_addr_scratch already use for the IPX family (net BE + node
; in transmission order), so link_ui.asm can rep movsb straight across.
g_net_ipx_peer:  resb 10

; TX staging: Ipx_TxByte appends here; ipx_tx_flush sends it all as one
; datagram and resets the length to 0.
tx_stage:        resb IPX_PAYLOAD_MAX
tx_stage_len:    resw 1

; RX staging: ipx_rx_refill fills it (payloads only, IPX headers stripped);
; Ipx_RxByte pops from [rx_stage_pos] up to [rx_stage_len].
rx_stage:        resb RX_STAGE_SIZE
rx_stage_len:    resw 1
rx_stage_pos:    resw 1

; ipx_post_listen's parameters (named temps rather than register threading
; across its own rep stosb — keeps every helper here simple to read).
ipx_pl_ecb_off:  resw 1
ipx_pl_frag_off: resw 1

section .text

; ===========================================================================
; Ipx_Init — detect the IPX stack, allocate the one DOS block, open the
; socket, fetch our own address, post both listen ECBs. Out: CF=0 bound,
; CF=1 no IPX stack present (or any DPMI/driver step failed) — the caller
; (net_hal.asm NetInit) leaves the transport unbound, exactly ComUart_Init's
; "degrade, never hang" contract.
;
; Idempotent: a second call while already bound just returns CF=0 without
; redoing any work (ipx_bound sentinel — dsv_ensure_buffer's own pattern,
; generalized to the whole stack rather than just the DOS buffer, since here
; the socket-open and listen-post steps ALSO must not repeat on an
; already-live session). A call that fails partway is not torn down (no
; teardown path — matches dsv_ensure_buffer's own "DOS reclaims every DPMI
; allocation at AH=4Ch exit" reasoning): a DOS block already allocated by a
; failed attempt is harmless to leave in place and a caller retrying from
; the link-cable UI (link_ui.asm link_ui_connect_attempt) re-runs the whole
; sequence, which is safe for detection/allocation (both self-guard) but NOT
; proven safe if Open Socket itself had partially succeeded before a LATER
; step failed — that interleaving is not reachable from any call site this
; step wires up (Get Internetwork Address and the ECB posts have no failure
; path of their own to land in), so it is left as a documented open question
; rather than speculative extra guarding.
; ===========================================================================
Ipx_Init:
    cmp byte [ipx_bound], 0
    jne .already_up

    ; --- 1. detect: INT 2Fh AX=7A00h via DPMI 0300h ---
    call ipx_zero_rmcs
    mov word [rmcs + RMCS_EAX], 0x7A00
    push eax
    push ebx
    push ecx
    push edi
    mov ax, 0x0300
    mov bl, 0x2F
    mov bh, 0
    xor cx, cx
    mov edi, rmcs
    int 0x31
    pop edi
    pop ecx
    pop ebx
    pop eax
    jc .fail                        ; the SIMULATE call itself failed
    mov al, [rmcs + RMCS_EAX]       ; low byte = the reflected AL
    cmp al, 0xFF
    jne .fail                       ; no IPX stack resident
    mov ax, [rmcs + RMCS_ES]
    mov [ipx_entry_seg], ax
    mov ax, [rmcs + RMCS_EDI]       ; low word of EDI = DI
    mov [ipx_entry_off], ax

    ; --- 2. allocate the one DOS block (DPMI 0100h), if not already done ---
    cmp word [ipx_sel], 0
    jne .have_block
    mov ax, 0x0100
    mov bx, BLOCK_PARAS
    int 0x31
    jc .fail
    mov [ipx_seg], ax
    mov [ipx_sel], dx
    movzx eax, ax
    shl eax, 4
    sub eax, [ds_base]
    mov [ipx_flat], eax
    ; zero the whole block: ECBs start clean (Link=0=no ESR, InUse=0, etc.)
    mov edi, eax
    mov ecx, BLOCK_SIZE
    xor eax, eax
    rep stosb
.have_block:

    ; --- 3. Open Socket (BX=0000h): AL=0 short-lived, DX=requested socket ---
    call ipx_zero_rmcs
    mov word [rmcs + RMCS_EBX], 0x0000
    mov word [rmcs + RMCS_EAX], 0x0000       ; AL=0 (AH unused)
    movzx eax, word [g_net_ipx_socket]
    mov [rmcs + RMCS_EDX], eax
    call ipx_call_real
    movzx eax, word [rmcs + RMCS_EAX]
    test al, al
    jnz .fail                       ; 0xFE in use / 0xFF table full
    mov ax, [rmcs + RMCS_EDX]
    mov [ipx_socket_assigned], ax

    ; --- 4. Get Internetwork Address (BX=0009h): ES:SI -> 10-byte scratch,
    ; in the DOS block so the driver can reach it real-mode; copy the result
    ; into our own flat cache once it returns. ---
    call ipx_zero_rmcs
    mov word [rmcs + RMCS_EBX], 0x0009
    mov ax, [ipx_seg]
    mov [rmcs + RMCS_ES], ax
    mov word [rmcs + RMCS_ESI], OFF_ADDR_SCRATCH
    call ipx_call_real
    mov esi, [ipx_flat]
    add esi, OFF_ADDR_SCRATCH
    mov edi, ipx_own_addr
    mov ecx, 10
    rep movsb

    ; --- 5. post both listen ECBs ---
    mov word [ipx_pl_ecb_off], OFF_ECB_LISTEN0
    mov word [ipx_pl_frag_off], OFF_RXBUF0
    call ipx_post_listen
    mov word [ipx_pl_ecb_off], OFF_ECB_LISTEN1
    mov word [ipx_pl_frag_off], OFF_RXBUF1
    call ipx_post_listen

    mov word [tx_stage_len], 0
    mov word [rx_stage_len], 0
    mov word [rx_stage_pos], 0
    mov byte [ipx_bound], 1
.already_up:
    clc
    ret
.fail:
    stc
    ret

; ---------------------------------------------------------------------------
; Ipx_Shutdown — close the socket. Safe when never bound (ComUart_Shutdown's
; own "safe when never bound" contract).
; ---------------------------------------------------------------------------
Ipx_Shutdown:
    cmp byte [ipx_bound], 0
    je .done
    call ipx_zero_rmcs
    mov word [rmcs + RMCS_EBX], 0x0001       ; Close Socket
    movzx eax, word [ipx_socket_assigned]
    mov [rmcs + RMCS_EDX], eax
    call ipx_call_real
    mov byte [ipx_bound], 0
.done:
    ret

; ---------------------------------------------------------------------------
; Ipx_TxByte — append AL to the flat TX staging buffer (see the file header's
; DATAGRAM<->BYTE-STREAM ADAPTATION note). Out: CF=0 appended, CF=1 the
; staging buffer is full (byte dropped — degrades exactly like
; ComUart_TxByte's THRE-timeout drop: the ARQ recovers). Preserves
; EBX/ESI/EDI (the codec callback contract).
; ---------------------------------------------------------------------------
Ipx_TxByte:
    push edx
    movzx edx, word [tx_stage_len]
    cmp edx, IPX_PAYLOAD_MAX
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
; Ipx_RxByte — pop one byte from the flat RX staging buffer (refilled once
; per pump tick by ipx_rx_refill, BEFORE NetFrame_Tick drains it — see
; ipx_dos_pump). Out: CF=1 nothing available, else AL=byte. Preserves
; EBX/ESI/EDI.
; ---------------------------------------------------------------------------
Ipx_RxByte:
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
; ipx_dos_pump — net_uart_pump's shape (tick counter, NetFrame_Tick, HELLO/
; ESTABLISH_REQ flush state machine via the now-shared net_session_pump_tail
; — see net_hal.asm) PLUS the datagram refill/flush bracketing this
; transport needs on top of it. Establishment arms / master kicks are NOT
; polled here — the vtable's NET_TRANSPORT_IPX start row IS net_uart_start
; (see the review NOTE below ipx_dos_pump).
; ===========================================================================
ipx_dos_pump:
    inc dword [net_pump_ticks]
    call ipx_rx_refill              ; Relinquish Control + drain completed
                                    ; listen ECBs into RX staging, repost them
    mov ebx, link_ncb
    call NetFrame_Tick              ; drains RX staging via Ipx_RxByte; may
                                    ; TX (ack/retransmit/keepalive) via
                                    ; nf_send_ctl/nf_tx_stored -> Ipx_TxByte
    call ipx_tx_flush               ; flush #1: whatever Tick just staged
    call net_session_pump_tail      ; HELLO/ESTABLISH_REQ session tail,
                                    ; shared verbatim with net_uart_pump
    call ipx_tx_flush               ; flush #2: whatever the tail queued
    ret

; NOTE (review decision): IPX has NO transport-specific net_vt_start row —
; the vtable's NET_TRANSPORT_IPX start entry points at net_uart_start
; directly (src/net/net_hal.asm), because that routine is pure IO_SB/IO_SC/
; session-state arm logic with no UART access, so establishment arms and
; master kicks fire on exactly the NetHAL_StartTransfer edges the game
; generates — the UART transport's proven timing. An earlier draft polled
; that logic from the pump instead; rejected because a per-tick poll keeps
; re-kicking the STALE staged IO_SC/hSerialSendData after the game leaves
; an exchange loop, emitting exchanges the UART transport never emits. Any
; kick queued by an in-Tick arm is flushed by this pump's flush #1/#2 on
; the same tick.

; ---------------------------------------------------------------------------
; ipx_rx_refill — Relinquish Control (BX=000Ah, let DOSBox-X's IPX emulation
; process), then drain each listen ECB that has completed. Resets the RX
; staging cursors to 0 first: safe because NetFrame_Tick always drains
; staging down to empty before returning (its rx_loop runs cb_rxbyte until
; CF=1), so nothing here can discard an unconsumed byte from the last tick.
; ---------------------------------------------------------------------------
ipx_rx_refill:
    mov word [rx_stage_len], 0
    mov word [rx_stage_pos], 0
    call ipx_zero_rmcs
    mov word [rmcs + RMCS_EBX], 0x000A       ; Relinquish Control
    call ipx_call_real
    mov word [ipx_pl_ecb_off], OFF_ECB_LISTEN0
    mov word [ipx_pl_frag_off], OFF_RXBUF0
    call ipx_rx_drain_one
    mov word [ipx_pl_ecb_off], OFF_ECB_LISTEN1
    mov word [ipx_pl_frag_off], OFF_RXBUF1
    call ipx_rx_drain_one
    ret

; ---------------------------------------------------------------------------
; ipx_rx_drain_one — In: [ipx_pl_ecb_off]/[ipx_pl_frag_off] name one listen
; ECB + its fragment buffer. If it has completed (InUse==0), copy its
; payload (header stripped) into RX staging, latch the sender as the AUTO
; peer if still searching, then re-post it (ipx_post_listen). A pending
; (still InUse) ECB is left untouched.
; ---------------------------------------------------------------------------
ipx_rx_drain_one:
    movzx eax, word [ipx_pl_ecb_off]
    add eax, [ipx_flat]
    cmp byte [eax + 8], 0            ; ECB.InUse
    jne .none                        ; still owned by the driver: nothing yet
    cmp byte [eax + 9], 0            ; ECB.CompletionCode: nonzero = error
    jne .repost                      ; (e.g. $FD overflow/$FC canceled) — drop,
                                     ; ARQ recovers, same as a bad-CRC frame
    movzx edx, word [ipx_pl_frag_off]
    add edx, [ipx_flat]              ; EDX = flat ptr to the received datagram
    ; the datagram's OWN header length field (+2, BIG-ENDIAN) is the true
    ; on-wire size (header+payload) the SENDER filled — NOT our ECB's
    ; FragmentSize, which only describes our buffer's receive capacity
    movzx ecx, byte [edx + 2]
    shl ecx, 8
    movzx eax, byte [edx + 3]
    or ecx, eax
    cmp ecx, IPX_HDR_LEN
    jb .repost                       ; malformed (shorter than a bare header)
    sub ecx, IPX_HDR_LEN             ; ECX = payload length
    call ipx_maybe_latch_peer        ; In: EDX = flat ptr to the datagram
    movzx eax, word [rx_stage_len]
    add eax, ecx
    cmp eax, RX_STAGE_SIZE
    ja .repost                       ; would overflow staging: drop (ARQ recovers)
    movzx edi, word [rx_stage_len]
    add edi, rx_stage
    lea esi, [edx + IPX_HDR_LEN]
    push ecx
    rep movsb
    pop ecx
    add [rx_stage_len], cx
.repost:
    call ipx_post_listen
.none:
    ret

; ---------------------------------------------------------------------------
; ipx_maybe_latch_peer — In: EDX = flat ptr to a just-received datagram. If
; g_net_ipx_peer is still all-zero (AUTO mode still broadcasting), adopt the
; datagram's SRC net+node (header +18, 10 bytes) as the peer, so every later
; send addresses back to whoever answered first. Clobbers EAX/ECX/ESI/EDI.
; ---------------------------------------------------------------------------
ipx_maybe_latch_peer:
    mov edi, g_net_ipx_peer
    xor eax, eax
    mov ecx, 10
.chk:
    or al, [edi + ecx - 1]
    dec ecx
    jnz .chk
    test al, al
    jnz .ret                         ; already set: keep the existing peer
    lea esi, [edx + 18]
    mov edi, g_net_ipx_peer
    mov ecx, 10
    rep movsb
.ret:
    ret

; ---------------------------------------------------------------------------
; ipx_post_listen — (re)post a Listen For Packet ECB. In:
; [ipx_pl_ecb_off]/[ipx_pl_frag_off] name the ECB and its fragment buffer
; (both DOS-block offsets). Zeroes the ECB first (fresh InUse/CompletionCode/
; workspace), fills SocketNumber/FragmentCount/FragmentAddress/FragmentSize,
; then issues BX=0004h.
; ---------------------------------------------------------------------------
ipx_post_listen:
    movzx eax, word [ipx_pl_ecb_off]
    add eax, [ipx_flat]
    push eax
    mov edi, eax
    mov ecx, ECB_LEN
    xor eax, eax
    rep stosb
    pop edi
    mov ax, [ipx_socket_assigned]
    mov [edi + 10], ah                ; SocketNumber, big-endian
    mov [edi + 11], al
    mov word [edi + 34], 1            ; FragmentCount
    mov ax, [ipx_pl_frag_off]
    mov [edi + 36], ax                ; FragmentAddress: offset word first
    mov ax, [ipx_seg]
    mov [edi + 38], ax                ; ...then segment word
    mov word [edi + 40], IPX_FRAG_LEN ; FragmentSize = full receive capacity

    call ipx_zero_rmcs
    mov word [rmcs + RMCS_EBX], 0x0004       ; Listen For Packet
    mov ax, [ipx_seg]
    mov [rmcs + RMCS_ES], ax
    mov ax, [ipx_pl_ecb_off]
    mov [rmcs + RMCS_ESI], ax
    call ipx_call_real
    ret

; ---------------------------------------------------------------------------
; ipx_tx_flush — if the TX staging buffer holds >= 1 byte AND the send ECB
; is free, build one IPX datagram (header + all staged bytes — always a
; whole number of complete NF frames, see the file header) and send it. If
; the send ECB is still busy, the staged bytes are left queued for the next
; attempt (never dropped here — only Ipx_TxByte's buffer-full path drops).
; ---------------------------------------------------------------------------
ipx_tx_flush:
    cmp word [tx_stage_len], 0
    je .ret
    mov eax, [ipx_flat]
    add eax, OFF_ECB_SEND
    cmp byte [eax + 8], 0             ; ECB.InUse: previous send still out?
    jne .ret

    ; zero the send ECB (Link/InUse/CompletionCode/workspace reset)
    push eax
    mov edi, eax
    mov ecx, ECB_LEN
    xor eax, eax
    rep stosb
    pop eax                            ; EAX = flat send-ECB ptr again

    ; build the IPX header in the DOS block's TX fragment buffer
    mov edi, [ipx_flat]
    add edi, OFF_TXBUF
    mov word [edi + 0], 0xFFFF        ; checksum sentinel (byte-symmetric:
                                       ; no swap needed either order)
    movzx ecx, word [tx_stage_len]
    mov edx, ecx
    add edx, IPX_HDR_LEN
    mov [edi + 2], dh                 ; length, big-endian
    mov [edi + 3], dl
    mov byte [edi + 4], 0             ; transportControl
    mov byte [edi + 5], 4             ; packetType = 4 (IPX)
    call ipx_build_dest               ; fills +6..+17 dest + ECB.ImmediateAddress;
                                       ; EDI restored to the header ptr on return
    lea edi, [edi + 18]
    mov esi, ipx_own_addr
    mov ecx, 10
    rep movsb                          ; src net+node -> +18..+27, EDI -> +28
    mov ax, [ipx_socket_assigned]
    mov [edi + 0], ah                  ; src socket -> +28..+29
    mov [edi + 1], al

    ; payload, right after the 30-byte header
    mov edi, [ipx_flat]
    add edi, OFF_TXBUF + IPX_HDR_LEN
    mov esi, tx_stage
    movzx ecx, word [tx_stage_len]
    rep movsb

    ; finish the send ECB: socket, fragment descriptor, size
    mov eax, [ipx_flat]
    add eax, OFF_ECB_SEND
    mov edi, eax
    mov ax, [ipx_socket_assigned]
    mov [edi + 10], ah
    mov [edi + 11], al
    mov word [edi + 34], 1
    mov ax, OFF_TXBUF
    mov [edi + 36], ax
    mov ax, [ipx_seg]
    mov [edi + 38], ax
    movzx eax, word [tx_stage_len]
    add eax, IPX_HDR_LEN
    mov [edi + 40], ax

    call ipx_zero_rmcs
    mov word [rmcs + RMCS_EBX], 0x0003       ; Send Packet
    mov ax, [ipx_seg]
    mov [rmcs + RMCS_ES], ax
    mov word [rmcs + RMCS_ESI], OFF_ECB_SEND
    call ipx_call_real

    mov word [tx_stage_len], 0
.ret:
    ret

; ---------------------------------------------------------------------------
; ipx_build_dest — In: EDI = flat ptr to the TX header being built (dest
; fields start at +6). Fills +6..+17 (dest net/node/socket) from
; g_net_ipx_peer, or broadcasts (net=0, node=FF:FF:FF:FF:FF:FF) while still
; all-zero (AUTO search), and copies the same dest node into the send ECB's
; ImmediateAddress (+28, same-net direct delivery, no routing). Out: EDI
; restored to the header ptr the caller passed in. Clobbers EAX/ECX/ESI/EDI;
; preserves EBX (used to hold the header ptr across the ECB write).
; ---------------------------------------------------------------------------
ipx_build_dest:
    push ebx
    mov ebx, edi                      ; EBX = header ptr (survives EDI moves)
    mov esi, g_net_ipx_peer
    xor eax, eax
    mov ecx, 10
.chk:
    or al, [esi + ecx - 1]
    dec ecx
    jnz .chk
    test al, al
    jnz .direct
    mov dword [ebx + 6], 0            ; dest net = 0 (same net)
    mov byte [ebx + 10], 0xFF
    mov byte [ebx + 11], 0xFF
    mov byte [ebx + 12], 0xFF
    mov byte [ebx + 13], 0xFF
    mov byte [ebx + 14], 0xFF
    mov byte [ebx + 15], 0xFF         ; dest node = broadcast
    jmp .socket
.direct:
    mov esi, g_net_ipx_peer
    lea edi, [ebx + 6]
    mov ecx, 10
    rep movsb
.socket:
    mov ax, [ipx_socket_assigned]     ; dest socket = our own bound socket
    mov [ebx + 16], ah                ; (the peer listens on the same
    mov [ebx + 17], al                ; well-known socket we do)
    mov eax, [ipx_flat]
    add eax, OFF_ECB_SEND
    lea esi, [ebx + 10]               ; dest node just written above
    lea edi, [eax + 28]               ; ECB.ImmediateAddress
    mov ecx, 6
    rep movsb
    mov edi, ebx                      ; restore EDI to the header ptr
    pop ebx
    ret

; ---------------------------------------------------------------------------
; ipx_call_real — invoke the cached IPX far entry point via DPMI 0301h
; ("call real-mode procedure with far return frame"). Caller has already
; filled every other rmcs field the target function needs (EBX=function
; code, and whichever of EAX/EDX/ES/ESI it reads — see each call site
; above); this sets CS:IP (every call targets the same dispatcher entry, so
; it is centralized here rather than repeated at each site) and issues the
; call. BH=flags=0 (no special real-mode flag handling needed), BL is
; unused for 0301h (there is no interrupt number — the target comes from
; CS:IP), CX=0 (no parameter words to copy onto the real-mode stack; every
; argument here travels in a register field of the rmcs itself).
; ---------------------------------------------------------------------------
ipx_call_real:
    mov ax, [ipx_entry_seg]
    mov [rmcs + RMCS_CS], ax
    mov ax, [ipx_entry_off]
    mov [rmcs + RMCS_IP], ax
    push eax
    push ebx
    push ecx
    push edi
    mov ax, 0x0301
    xor bx, bx
    xor cx, cx
    mov edi, rmcs
    int 0x31
    pop edi
    pop ecx
    pop ebx
    pop eax
    ret

; ---------------------------------------------------------------------------
; ipx_zero_rmcs — clear the real-mode call structure (dsv_io.asm's
; dsv_zero_rmcs pattern, local to this file since RMCS_* here is the full
; field set dsv_io.asm doesn't need).
; ---------------------------------------------------------------------------
ipx_zero_rmcs:
    push eax
    push ecx
    push edi
    mov edi, rmcs
    xor al, al
    mov ecx, RMCS_SIZE
    rep stosb
    pop edi
    pop ecx
    pop eax
    ret
