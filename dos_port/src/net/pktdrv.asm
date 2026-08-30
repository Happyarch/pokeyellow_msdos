; ===========================================================================
; pktdrv.asm — FTP Software Packet Driver 1.09 client (port-only, no pret
; counterpart). docs/current_plan_link_cable.md Stage 7 step 1.
;
; Stage 7 delivered the driver-facing primitives first (Pktdrv_Init/Shutdown/
; Send/Recv), and Stage 7 step 2 (net_ip.asm) wired them into the TCP
; transport: net_ip.asm calls Pktdrv_* and net_hal.asm's NET_TRANSPORT_TCP
; vtable row runs net_ip_pump.
;
; ===========================================================================
; THE PACKET DRIVER API CONTRACT (per the Stage 7 spec's FTP Software Packet
; Driver 1.09 contract)
; ===========================================================================
; Probe: for INT vectors 0x60..0x80 inclusive, read the real-mode IVT entry
; (DPMI is not needed to READ the IVT — the real-mode vector table sits at
; LINEAR 0, and this port already maps flat memory the same way video.asm's
; vga_base does for 0xA0000: linear_addr - ds_base, wrapping mod 2^32 —
; see pktdrv_check_vector). The 9 bytes at linear seg*16+ofs+3 are checked
; against "PKT DRVR",0; first match wins. /PKTINT=0xNN (boot/entry.asm,
; g_pkt_int) overrides the scan with exactly that one vector — still
; signature-checked, so a bad override degrades exactly like "no driver
; present" rather than trusting an unverified vector.
;
; All calls except the async receiver upcall are a simulated real-mode INT
; <probed vector> via DPMI 0300h (the dsv_io.asm rmcs pattern). This project
; already has a 0301h user (Stage 6's ipx_dos.asm, which calls a real-mode
; PROCEDURE ENTRY POINT with no interrupt number involved) — packet drivers
; are the simpler INT-vector case, so pktdrv_call_real is a 0300h/BL=vector
; call, structurally identical to dsv_io.asm's own INT 21h simulation, not
; ipx_dos.asm's 0301h. CF set in the rmcs FLAGS byte (bit 0) after the call
; = the DRIVER's own error indication (DH = error code, not decoded here —
; nothing consumes it yet); CF from the DPMI simulate itself is a separate,
; earlier check (pktdrv_call_real's own jc).
;
; Functions used here (AH = function):
;   AH=2 access_type — AL=1 (DIX Ethernet), BX=0xFFFF (if_type: any),
;     DL=0 (if_number), DS:SI = 2-byte big-endian ethertype template
;     (real-mode, inside our DOS block), CX=2 (template length — NEVER 0;
;     0 would mean "receive ALL", and we want exactly 0x0800 IP and 0x0806
;     ARP as TWO SEPARATE handles), ES:DI = the receiver callback (real-mode
;     far address, from 0303h — SAME callback for both handles). Out: AX =
;     handle. Called twice (pktdrv_access_type), once per ethertype.
;   AH=3 release_type — BX=handle.
;   AH=4 send_pkt — DS:SI = frame (real-mode buffer, full Ethernet frame:
;     dest MAC(6) src MAC(6) ethertype(2) payload), CX=length.
;   AH=6 get_address — ES:DI = 6-byte real-mode buffer, CX=6. Out: our MAC,
;     copied to the flat g_pkt_mac.
; AH=1 driver_info is part of the contract but is NOT called here — it is
; documented as diagnostic-only ("call once for diagnostics... if trivial")
; and this step has no /LINKLOG-equivalent sink to route it to without
; touching net_hal.asm, which step 1 must not touch. Left as an open
; question for step 2 (see the report).
; ===========================================================================
;
; ===========================================================================
; THE DPMI 0303h REAL-MODE CALLBACK PATTERN — ANNOTATED (repo's first user)
; ===========================================================================
; WHY: the packet driver's receiver upcall runs IN REAL MODE (it is a real-
; mode TSR/driver servicing a hardware interrupt). To have it deliver
; packets to our protected-mode code, we need a REAL-MODE far address that,
; when called, transfers control into OUR protected-mode handler. That is
; exactly what DPMI AX=0303h "Allocate Real Mode Call-Back Address" hands
; out (DPMI 0.9 spec, "Allocate Real Mode Call-Back Address"):
;
;   To call:
;     AX = 0303h
;     DS:(E)SI = Selector:Offset of the PROCEDURE TO CALL back
;     ES:(E)DI = Selector:Offset of a REAL MODE CALL STRUCTURE (rmcs) —
;                the SAME 0x32-byte layout dsv_io.asm/ipx_dos.asm already
;                use for 0300h/0301h, per the DPMI spec's "Real Mode Call
;                Structure". We give it pktdrv_cb_rmcs (see below).
;   Returns:
;     CF=0: CX:DX = segment:offset of the REAL-MODE callback address — THIS
;     is what we hand the packet driver as ES:DI at access_type (AH=2) time.
;     CF=1: failed (out of callback descriptors — DPMI hosts guarantee only
;     a minimum of 16 per task, and we allocate exactly one).
;
; DS:(E)SI at ALLOCATION time is a genuine SELECTOR:offset naming a
; PROCEDURE — DS itself must therefore be loaded with an EXECUTABLE (code)
; selector for the duration of that one int 31h call, unlike every other
; DPMI call in this codebase (0204h/0205h use a separate CX:EDX pair for
; that, so DS is never disturbed there). pktdrv_alloc_callback borrows CS:
;
;     mov ax, cs
;     mov ds, ax
;     mov ax, 0x0303
;     int 0x31
;
; and restores the real DS immediately after. This is safe with interrupts
; live because every hardware ISR in this port (kbd_isr in joypad.asm, the
; PIT tick ISR in boot/timing.asm, com_uart.asm's UART ISR) reloads DS/ES
; ITSELF from a CS-relative cache before touching any memory (joypad.asm's
; `mov ax, [cs:kisr_ds] / mov ds, ax` is the precedent this file's own
; pktdrv_pm_handler copies) — none of them ever trust the interrupted
; code's DS, so a foreground DS=CS window can never be observed as wrong.
;
; INVOCATION time — what the packet driver's real-mode CALL actually
; produces (DPMI spec, "Call-Back Procedure Parameters"), quoted because
; it is the crux of the whole pattern and easy to get backwards:
;
;     Interrupts disabled
;     DS:(E)SI = Selector:Offset of REAL MODE SS:SP
;     ES:(E)DI = Selector:Offset of the real mode call structure (our own
;                pktdrv_cb_rmcs, already filled by the DPMI host with the
;                real-mode register state — AX/CX/DS/SI etc, exactly as the
;                packet driver set them before calling us)
;     SS:(E)SP = a locked protected-mode API stack (push/pop-safe scratch;
;                NOT our own stack)
;     All other registers undefined
;
; The critical, easy-to-miss point: DS:ESI on ENTRY is *not* our own flat
; data selector and does *not* point at the rmcs — it aliases the REAL-MODE
; STACK, at the exact moment the driver's `CALL FAR ptr <our address>`
; landed. A real-mode far CALL pushes return CS then return IP (IP ends up
; on TOP, at SS:SP, since it is pushed second) — so [DS:ESI] is the return
; IP word and [DS:ESI+2] is the return CS word, and pktdrv_pm_handler reads
; BOTH of those FIRST, before touching DS at all, for exactly this reason.
;
; RETURN — the DPMI spec ("Return from Call-Back Procedure"):
;
;     Execute an IRET to return
;     ES:(E)DI = Selector:Offset of the real mode call structure to restore
;
;     Programmer's note: "The called procedure is responsible for modifying
;     the real mode CS:IP before returning" — otherwise the DPMI host would
;     resume real mode by re-entering OUR OWN callback stub (rmcs.CS:IP, as
;     filled by the host, is the CALLBACK'S OWN address, not the driver's
;     return address — using it verbatim is the infinite-recursion trap the
;     note warns about).
;
; So pktdrv_pm_handler's tail does exactly what ROOT's spec names: write
; the CAPTURED return IP/CS (read in step 1, above) into pktdrv_cb_rmcs's
; own CS/IP fields, `add [pktdrv_cb_rmcs + RMCS_SP], 4` (popping the 2
; words we just consumed off the real-mode stack — mirroring what a real
; RETF would have done to SP), restore ES:EDI = pktdrv_cb_rmcs (it was
; overwritten with our own flat data selector midway through, to make the
; structure's fields addressable — see the handler body), then `iret`.
; `iret` (not `iretd`) is this port's own convention for a CS-bits-32
; protected-mode handler — plain `iret` inside a `bits 32` file already
; assembles as the 32-bit form (opcode 0xCF, no 66h override needed), the
; same as kbd_isr/the PIT tick ISR/com_uart's UART ISR all use.
;
; KEPT MINIMAL, per ROOT's explicit constraint: the handler does rmcs/flag
; bookkeeping ONLY — no calls into game code, no DelayFrame, nothing that
; could re-enter DOS or the game loop from inside a real-mode driver's own
; interrupt-time call depth with interrupts disabled.
;
; Freed with AX=0304h (CX:DX = the real-mode address 0303h returned) in
; Pktdrv_Shutdown; safe to call even if Init never ran (checked via the
; 0=unallocated sentinel, same pattern as every other "safe when never
; bound" teardown in this codebase).
; ===========================================================================
;
; ===========================================================================
; DOS BLOCK MEMORY MAP (one DPMI 0100h conventional-memory allocation,
; offsets from its real-mode segment:0 — see pktdrv_alloc_dos_block)
; ===========================================================================
;   OFF_TXBUF        =    0   (FRAME_MAX = 1514 bytes) — Pktdrv_Send's
;                                real-mode staging buffer for AH=4
;   OFF_RXBUF0       = 1514   (1514 bytes) — RX slot 0, handed to the
;                                driver as ES:DI on call 1
;   OFF_RXBUF1       = 3028   (1514 bytes) — RX slot 1 (the two rotate —
;                                see "RX BUFFER PROTOCOL" below)
;   OFF_MACBUF       = 4542   (6 bytes)    — AH=6 get_address scratch
;   OFF_ETHTYPE_IP   = 4548   (2 bytes)    — 0x08,0x00 big-endian template
;   OFF_ETHTYPE_ARP  = 4550   (2 bytes)    — 0x08,0x06 big-endian template
;   BLOCK_SIZE       = 4552 bytes total (285 paragraphs)
; The rmcs structures (`rmcs`, `pktdrv_cb_rmcs`) are ordinary flat .bss —
; they are PROTECTED MODE structures the DPMI host addresses via a PM
; selector, so they carry no real-mode-reachability constraint and do NOT
; live in this DOS block.
; ===========================================================================
;
; ===========================================================================
; RX BUFFER PROTOCOL (2 rotating real-mode buffers; degrade-safely, matching
; ComUart_RxByte's ring-full drop / Ipx_RxByte's own staging-buffer policy)
; ===========================================================================
; pktdrv_rxbuf_state[0..1]: 0=free, 1=pending (driver is filling it, between
; call1 and call2), 2=filled (ready for Pktdrv_Recv). pktdrv_pending_slot
; names whichever slot the LAST call1 handed out, consumed by the matching
; call2 — safe because the packet driver spec's call1/call2 pair for one
; packet is atomic (no interleaving with a different packet's call1/call2 in
; between; this is real-mode interrupt-time code, not reentrant).
;
;   call 1 (rmcs.AX=0, rmcs.CX=incoming length): pick the first FREE slot
;   (0 then 1), mark it 1=pending, hand back its real-mode ES:DI. If both
;   slots are busy (pending or filled and not yet drained), hand back
;   ES:DI=0:0 — the documented packet-driver reject convention. The dropped
;   packet is exactly as recoverable as any other transport's drop (higher
;   layers retransmit); nothing here busy-waits for a free slot.
;
;   call 2 (rmcs.AX=1, rmcs.CX=final length): the pending slot (set by our
;   own call1 above) is marked 2=filled, its length recorded (clamped to
;   FRAME_MAX defensively — a misbehaving driver reporting CX larger than
;   the buffer it was given must not desync a later Pktdrv_Recv copy).
;
;   Pktdrv_Recv (polled, from protected mode / the transport pump, step 2):
;   drains the oldest FILLED slot via a round-robin cursor
;   (pktdrv_rx_next_read) that trails the round-robin alloc order call1
;   already uses (0 then 1, repeating) — with only 2 slots this reproduces
;   FIFO order in the normal case. Draining resets the slot to 0=free.
;
; Buffers hold RAW ETHERNET FRAMES (dest MAC(6) src MAC(6) ethertype(2)
; payload...) exactly as received off the wire/DOSBox-X NE2000 emulation —
; no header stripped, no byte-order adjustment; every multi-byte on-wire
; field (ethertype, and whatever step 2's IP/ARP layer parses next) stays
; BIG-ENDIAN as the frame arrived.
; ===========================================================================
;
; Referenced by net_ip.asm (Stage 7 step 2): Pktdrv_Init/Shutdown/Send/Recv
; are the packet-driver half of the TCP transport. The step-1 invariant
; ("nothing calls these yet") is superseded — the "pre-wiring" comment was a
; stage marker, not a permanent dead-code claim.
;
; Build check: nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 \
;              -o /dev/null src/net/pktdrv.asm   (from dos_port/)
; ===========================================================================

bits 32

global Pktdrv_Init
global Pktdrv_Shutdown
global Pktdrv_Send
global Pktdrv_Recv
global g_pkt_int                    ; boot/entry.asm — /PKTINT=0xNN override
global g_pkt_mac                    ; our NIC MAC (AH=6), for step 2's frame
                                    ; source-MAC field — published, not yet
                                    ; read by anything (see file header)

extern ds_base                      ; boot/entry.asm — linear base of our DS

; --- DPMI real-mode call structure field offsets (DPMI 0.9 spec; cloned
; from ipx_dos.asm — there is no shared .inc for this in the tree, and the
; Stage 6 spec's "reuse the shared helpers if Stage 6 factored any, else
; clone" directive applies: none were factored) ---
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
FRAME_MAX equ 1514                  ; max Ethernet frame: 6+6+2+1500

PROBE_LO equ 0x60                   ; packet-driver dynamic INT range
PROBE_HI equ 0x80                   ; (inclusive at both ends per the spec)

; --- ONE DOS conventional-memory block layout (offsets from its real-mode
; segment:0 — see the file header's "DOS BLOCK MEMORY MAP") ---
OFF_TXBUF        equ 0
OFF_RXBUF0       equ OFF_TXBUF + FRAME_MAX          ; 1514
OFF_RXBUF1       equ OFF_RXBUF0 + FRAME_MAX         ; 3028
OFF_MACBUF       equ OFF_RXBUF1 + FRAME_MAX         ; 4542
OFF_ETHTYPE_IP   equ OFF_MACBUF + 6                 ; 4548
OFF_ETHTYPE_ARP  equ OFF_ETHTYPE_IP + 2             ; 4550
BLOCK_SIZE       equ OFF_ETHTYPE_ARP + 2            ; 4552
BLOCK_PARAS      equ (BLOCK_SIZE + 15) / 16         ; 285 paragraphs

section .bss
align 4
rmcs:              resb RMCS_SIZE    ; FOREGROUND rmcs — Init/Shutdown/Send/
                                     ; probe, everything except the async
                                     ; receiver callback
pktdrv_cb_rmcs:    resb RMCS_SIZE    ; DEDICATED callback rmcs. Must never be
                                     ; shared with the foreground `rmcs`
                                     ; above: the receiver callback can fire
                                     ; asynchronously (interrupts are live
                                     ; during a 0300h simulate) while
                                     ; foreground code is itself mid-call —
                                     ; one shared buffer would let the two
                                     ; race and corrupt each other's fields.

g_pkt_int:         resb 1            ; /PKTINT=0xNN (boot/entry.asm); 0 =
                                     ; auto-scan PROBE_LO..PROBE_HI
pktdrv_bound:      resb 1            ; 1 once Pktdrv_Init fully succeeded —
                                     ; idempotent re-Init sentinel
pktdrv_int_no:     resb 1            ; the probed/overridden INT vector now
                                     ; in use (diagnostic; also fed to every
                                     ; pktdrv_call_real)
pktdrv_seg:        resw 1            ; real-mode segment of the DOS block
pktdrv_sel:        resw 1            ; PM selector — 0100h "already
                                     ; allocated" sentinel (0 = not yet)
pktdrv_flat:       resd 1            ; DS-relative flat ptr to the DOS block
pktdrv_ip_handle:  resw 1            ; access_type handle, ethertype 0x0800
pktdrv_arp_handle: resw 1            ; access_type handle, ethertype 0x0806
pktdrv_cb_seg:     resw 1            ; 0303h real-mode callback far address —
pktdrv_cb_off:     resw 1            ; 0 = not allocated (0304h no-op guard)
pktdrv_ds_cache:   resw 1            ; our flat data selector, cached here so
                                     ; pktdrv_pm_handler can reload DS/ES on
                                     ; entry (it cannot assume DS is ours —
                                     ; see the handler's own header)

; --- RX staging: see the file header's "RX BUFFER PROTOCOL" ---
pktdrv_rxbuf_state:  resb 2          ; index 0/1: 0=free 1=pending 2=filled
pktdrv_rxbuf_len:    resw 2          ; valid once the matching state==2
pktdrv_pending_slot: resb 1          ; slot handed out by the LAST call1,
                                     ; consumed by the matching call2;
                                     ; 0xFF = none pending
pktdrv_rx_next_read: resb 1          ; Pktdrv_Recv's round-robin FIFO cursor

g_pkt_mac:         resb 6            ; our NIC's MAC address (AH=6 result)

section .data
align 4
pktdrv_sig: db "PKT DRVR", 0         ; 9-byte packet-driver signature (contract)

section .text

; ===========================================================================
; Pktdrv_Init — probe for a packet driver, allocate the DOS block + the
; 0303h receiver callback, open IP+ARP access_type handles, fetch our MAC.
; Out: CF=0 bound, CF=1 no packet driver present (or any DPMI/driver step
; failed) — degrades exactly like ComUart_Init/Ipx_Init: the caller (not
; wired up until step 2) is expected to leave the transport unbound.
;
; Idempotent (pktdrv_bound sentinel, dsv_ensure_buffer's own pattern) and,
; like Ipx_Init, NOT torn down on a partial failure (DOS reclaims every DPMI
; allocation at process exit; a DOS block or callback already allocated by a
; failed attempt is harmless to leave in place for a caller that retries).
; ===========================================================================
Pktdrv_Init:
    cmp byte [pktdrv_bound], 0
    jne .already_up

    call pktdrv_probe
    jc .fail
    call pktdrv_alloc_dos_block
    jc .fail
    call pktdrv_alloc_callback
    jc .fail

    mov ax, OFF_ETHTYPE_IP
    call pktdrv_access_type
    jc .fail
    mov [pktdrv_ip_handle], ax

    mov ax, OFF_ETHTYPE_ARP
    call pktdrv_access_type
    jc .fail
    mov [pktdrv_arp_handle], ax

    call pktdrv_get_address
    jc .fail

    mov byte [pktdrv_bound], 1
.already_up:
    clc
    ret
.fail:
    stc
    ret

; ---------------------------------------------------------------------------
; Pktdrv_Shutdown — release both access_type handles, free the 0303h
; callback. Safe when never bound (ComUart_Shutdown/Ipx_Shutdown's own
; contract). Release failures are not checked (matches Ipx_Shutdown: nothing
; useful to do differently on a teardown call).
; ---------------------------------------------------------------------------
Pktdrv_Shutdown:
    cmp byte [pktdrv_bound], 0
    je .done

    call pktdrv_zero_rmcs
    mov word [rmcs + RMCS_EAX], 0x0300       ; AH=3 release_type
    movzx eax, word [pktdrv_ip_handle]
    mov [rmcs + RMCS_EBX], eax
    call pktdrv_call_real

    call pktdrv_zero_rmcs
    mov word [rmcs + RMCS_EAX], 0x0300
    movzx eax, word [pktdrv_arp_handle]
    mov [rmcs + RMCS_EBX], eax
    call pktdrv_call_real

    call pktdrv_free_callback
    mov byte [pktdrv_bound], 0
.done:
    ret

; ---------------------------------------------------------------------------
; Pktdrv_Send — In: ESI = flat ptr to a complete Ethernet frame (dest MAC(6)
; src MAC(6) ethertype(2) + payload), ECX = length (<= FRAME_MAX). Out:
; CF=0 sent / CF=1 on any failure: not bound, length too large, the DPMI
; simulate itself failing, or the driver's own send error (rmcs FLAGS bit 0
; after the call). Preserves nothing beyond the pushed set below.
; ---------------------------------------------------------------------------
Pktdrv_Send:
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi

    cmp byte [pktdrv_bound], 0
    je .fail
    cmp ecx, FRAME_MAX
    ja .fail

    push ecx
    mov edi, [pktdrv_flat]
    add edi, OFF_TXBUF
    rep movsb                        ; ESI (flat, caller's) -> TX buf
    pop ecx

    call pktdrv_zero_rmcs
    mov word [rmcs + RMCS_EAX], 0x0400       ; AH=4 send_pkt
    mov ax, [pktdrv_seg]
    mov [rmcs + RMCS_DS], ax
    mov dword [rmcs + RMCS_ESI], OFF_TXBUF
    mov [rmcs + RMCS_ECX], ecx
    call pktdrv_call_real
    jc .fail
    test byte [rmcs + RMCS_FLAGS], 1
    jnz .fail

    clc
    jmp .out
.fail:
    stc
.out:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

; ---------------------------------------------------------------------------
; Pktdrv_Recv — In: EDI = flat dest ptr. Out: CF=1 nothing queued; else
; CF=0 + ECX = length (<= FRAME_MAX), frame bytes copied to [EDI]. Drains
; the oldest FILLED RX staging slot (see the file header's "RX BUFFER
; PROTOCOL") and resets it to free. Preserves EBX/ESI (used internally, not
; part of the out contract, but restored anyway — no reason not to);
; advances EDI by the copied length (ordinary destination-pointer semantics,
; matching every other flat-copy routine in this codebase).
; ---------------------------------------------------------------------------
Pktdrv_Recv:
    push eax
    push ebx
    push esi

    movzx eax, byte [pktdrv_rx_next_read]
    mov bl, [pktdrv_rxbuf_state + eax]
    cmp bl, 2
    je .have
    xor eax, 1                       ; try the other slot
    mov bl, [pktdrv_rxbuf_state + eax]
    cmp bl, 2
    jne .none

.have:                                ; EAX = slot index, state==2 (filled)
    movzx ecx, word [pktdrv_rxbuf_len + eax * 2]
    mov esi, [pktdrv_flat]
    test eax, eax
    jnz .slot1
    add esi, OFF_RXBUF0
    jmp .copy
.slot1:
    add esi, OFF_RXBUF1
.copy:
    push eax
    push ecx
    rep movsb
    pop ecx
    pop eax
    mov byte [pktdrv_rxbuf_state + eax], 0     ; slot -> free
    xor al, 1
    mov [pktdrv_rx_next_read], al              ; advance the FIFO cursor
    clc
    jmp .out
.none:
    stc
.out:
    pop esi
    pop ebx
    pop eax
    ret

; ===========================================================================
; Internal helpers
; ===========================================================================

; ---------------------------------------------------------------------------
; pktdrv_probe — find a resident packet driver. If g_pkt_int is nonzero,
; check ONLY that vector (still signature-verified — a bad override
; degrades exactly like "no driver present", never trusted blind); else
; scan PROBE_LO..PROBE_HI, first match wins. Out: CF=0 + [pktdrv_int_no]
; set, CF=1 none found. Clobbers EAX.
; ---------------------------------------------------------------------------
pktdrv_probe:
    movzx eax, byte [g_pkt_int]
    test al, al
    jz .scan
    call pktdrv_check_vector
    jc .fail
    mov [pktdrv_int_no], al
    clc
    ret
.scan:
    mov al, PROBE_LO
.loop:
    call pktdrv_check_vector
    jnc .found
    inc al
    cmp al, PROBE_HI
    jbe .loop
    jmp .fail
.found:
    mov [pktdrv_int_no], al
    clc
    ret
.fail:
    stc
    ret

; ---------------------------------------------------------------------------
; pktdrv_check_vector — In: AL = interrupt vector number. Reads the
; real-mode IVT entry for that vector directly out of flat memory (no DPMI
; call needed to READ it — see the file header) and checks the 9-byte
; "PKT DRVR",0 signature at seg*16+ofs+3. Out: CF=0 signature matched,
; CF=1 not. AL preserved. Clobbers EBX/ECX/ESI/EDI (all restored via the
; full-EAX save, except EBX/ECX/ESI/EDI which are pushed/popped directly).
; ---------------------------------------------------------------------------
pktdrv_check_vector:
    push eax
    push ebx
    push esi
    push edi

    movzx ebx, al
    shl ebx, 2
    sub ebx, [ds_base]                ; flat ptr to the 4-byte IVT entry
    movzx eax, word [ebx]             ; real-mode offset
    movzx ecx, word [ebx + 2]         ; real-mode segment
    shl ecx, 4
    add ecx, eax
    add ecx, 3                        ; seg*16 + ofs + 3 (signature start)
    sub ecx, [ds_base]                ; flat ptr to the signature bytes

    mov esi, ecx
    mov edi, pktdrv_sig
    mov ecx, 9
    repe cmpsb
    je .match
    stc
    jmp .out
.match:
    clc
.out:
    pop edi
    pop esi
    pop ebx
    pop eax                           ; restores AL (full EAX) as entered;
                                       ; CF from cmp/stc/clc survives POP
    ret

; ---------------------------------------------------------------------------
; pktdrv_alloc_dos_block — DPMI 0100h: allocate the one conventional DOS
; block (see the file header's "DOS BLOCK MEMORY MAP"), zero it, and stamp
; the two ethertype templates. Idempotent via pktdrv_sel (dsv_ensure_buffer's
; own "already allocated" sentinel pattern — DPMI 0100h never returns the
; null selector, and .bss starts zeroed). Out: CF=1 on the DPMI call
; failing. Clobbers EAX/EBX/ECX/EDX/EDI.
; ---------------------------------------------------------------------------
pktdrv_alloc_dos_block:
    cmp word [pktdrv_sel], 0
    jne .have
    mov ax, 0x0100
    mov bx, BLOCK_PARAS
    int 0x31
    jc .fail
    mov [pktdrv_seg], ax
    mov [pktdrv_sel], dx
    movzx eax, ax
    shl eax, 4
    sub eax, [ds_base]
    mov [pktdrv_flat], eax

    mov edi, eax
    mov ecx, BLOCK_SIZE
    xor eax, eax
    rep stosb                          ; zero the whole block

    mov edi, [pktdrv_flat]
    add edi, OFF_ETHTYPE_IP
    mov byte [edi], 0x08               ; 0x0800, big-endian on the wire
    mov byte [edi + 1], 0x00
    mov edi, [pktdrv_flat]
    add edi, OFF_ETHTYPE_ARP
    mov byte [edi], 0x08               ; 0x0806, big-endian on the wire
    mov byte [edi + 1], 0x06
.have:
    clc
    ret
.fail:
    stc
    ret

; ---------------------------------------------------------------------------
; pktdrv_alloc_callback — DPMI 0303h. See the file header's "THE DPMI 0303h
; REAL-MODE CALLBACK PATTERN" for the full annotated walkthrough; this is
; just the mechanical call. Out: CF=0 + pktdrv_cb_seg/off set, CF=1 on
; failure. Clobbers EAX/ECX/EDX/ESI/EDI.
; ---------------------------------------------------------------------------
pktdrv_alloc_callback:
    push eax
    push ecx
    push edx
    push esi
    push edi
    push ds

    mov ax, ds
    mov [pktdrv_ds_cache], ax          ; cached for pktdrv_pm_handler to
                                        ; reload DS/ES with on every fire
    mov es, ax                         ; ES:EDI = selector:offset of
    mov edi, pktdrv_cb_rmcs            ; pktdrv_cb_rmcs — explicit, rather
                                        ; than relying on the global ES=DS
                                        ; alias entry.asm's setup_flat_access
                                        ; set once at boot

    mov esi, pktdrv_pm_handler         ; DS:ESI will be the PM handler's
                                        ; selector:offset — plain label,
                                        ; valid as a CS-relative OR
                                        ; DS-relative offset since CS and DS
                                        ; share one flat base in this port
                                        ; (same convention joypad.asm's
                                        ; kbd_isr install relies on)
    mov ax, cs
    mov ds, ax                         ; borrow CS as DS for this ONE call —
                                        ; see the file header for why this is
                                        ; safe with interrupts live
    mov ax, 0x0303
    int 0x31
    pop ds
    jc .fail
    mov [pktdrv_cb_seg], cx
    mov [pktdrv_cb_off], dx
    clc
    jmp .out
.fail:
    stc
.out:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop eax
    ret

; ---------------------------------------------------------------------------
; pktdrv_free_callback — DPMI 0304h. Safe when never allocated (pktdrv_cb_seg
; == 0 sentinel — a real-mode segment 0 is never returned by 0303h for an
; allocated callback, and .bss starts zeroed).
; ---------------------------------------------------------------------------
pktdrv_free_callback:
    cmp word [pktdrv_cb_seg], 0
    je .done
    push eax
    push ecx
    push edx
    mov cx, [pktdrv_cb_seg]
    mov dx, [pktdrv_cb_off]
    mov ax, 0x0304
    int 0x31
    mov word [pktdrv_cb_seg], 0
    pop edx
    pop ecx
    pop eax
.done:
    ret

; ---------------------------------------------------------------------------
; pktdrv_access_type — In: AX = template offset within the DOS block
; (OFF_ETHTYPE_IP or OFF_ETHTYPE_ARP). Out: CF=0 + AX = handle, CF=1 on any
; DPMI/driver failure. Clobbers EAX; preserves EBX/ECX/EDX/ESI/EDI.
; ---------------------------------------------------------------------------
pktdrv_access_type:
    push ebx
    push ecx
    push edx
    push esi
    push edi

    movzx edx, ax                      ; EDX = template offset arg
    call pktdrv_zero_rmcs
    mov word [rmcs + RMCS_EAX], 0x0201 ; AH=2 access_type, AL=1 (DIX Ethernet)
    mov word [rmcs + RMCS_EBX], 0xFFFF ; if_type = any
    mov word [rmcs + RMCS_EDX], 0x0000 ; DL = if_number 0
    mov ax, [pktdrv_seg]
    mov [rmcs + RMCS_DS], ax
    mov [rmcs + RMCS_ESI], edx         ; template pointer (real-mode)
    mov word [rmcs + RMCS_ECX], 2      ; template length — NEVER 0 (see
                                        ; the file header: 0 = receive ALL)
    mov ax, [pktdrv_cb_seg]
    mov [rmcs + RMCS_ES], ax
    movzx eax, word [pktdrv_cb_off]
    mov [rmcs + RMCS_EDI], eax         ; receiver callback (real-mode far)
    call pktdrv_call_real
    jc .fail
    test byte [rmcs + RMCS_FLAGS], 1
    jnz .fail
    movzx eax, word [rmcs + RMCS_EAX]  ; AX = handle
    clc
    jmp .out
.fail:
    stc
.out:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

; ---------------------------------------------------------------------------
; pktdrv_get_address — AH=6: ES:DI = 6-byte real-mode buffer, CX=6. Copies
; the result into the flat g_pkt_mac. Out: CF=0 ok, CF=1 fail. Clobbers
; EAX/ECX/ESI/EDI.
; ---------------------------------------------------------------------------
pktdrv_get_address:
    call pktdrv_zero_rmcs
    mov word [rmcs + RMCS_EAX], 0x0600 ; AH=6 get_address
    mov ax, [pktdrv_seg]
    mov [rmcs + RMCS_ES], ax
    mov dword [rmcs + RMCS_EDI], OFF_MACBUF
    mov word [rmcs + RMCS_ECX], 6
    call pktdrv_call_real
    jc .fail
    test byte [rmcs + RMCS_FLAGS], 1
    jnz .fail
    mov esi, [pktdrv_flat]
    add esi, OFF_MACBUF
    mov edi, g_pkt_mac
    mov ecx, 6
    rep movsb
    clc
    ret
.fail:
    stc
    ret

; ---------------------------------------------------------------------------
; pktdrv_call_real — invoke the probed packet-driver INT vector via DPMI
; 0300h (simulate real mode interrupt) — this project's dsv_io.asm pattern,
; NOT ipx_dos.asm's 0301h (no real-mode ENTRY POINT is involved here; the
; packet driver hooks an ordinary software interrupt). Caller has already
; filled every rmcs field the target function needs. Out: CF = the DPMI
; call's own success/fail (rare); the driver's OWN error indication is a
; separate check callers make afterward (rmcs FLAGS bit 0 + DH, per the
; packet driver spec). Clobbers nothing beyond the pushed set.
; ---------------------------------------------------------------------------
pktdrv_call_real:
    push ebx
    push ecx
    push edi
    mov ax, 0x0300
    movzx ebx, byte [pktdrv_int_no]
    mov bh, 0
    xor cx, cx
    mov edi, rmcs
    int 0x31
    pop edi
    pop ecx
    pop ebx
    ret

; ---------------------------------------------------------------------------
; pktdrv_zero_rmcs — clear the FOREGROUND rmcs (ipx_zero_rmcs's own local
; pattern, cloned — see the RMCS_* comment above for why there is no shared
; helper to call instead). Never touches pktdrv_cb_rmcs (the DPMI host owns
; that one's lifecycle entirely — see the file header's reentrancy note).
; ---------------------------------------------------------------------------
pktdrv_zero_rmcs:
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

; ===========================================================================
; pktdrv_pm_handler — the protected-mode procedure DPMI 0303h invokes when
; the real-mode packet driver calls our allocated callback address. See the
; file header's "THE DPMI 0303h REAL-MODE CALLBACK PATTERN" for the full
; annotated walkthrough — this comment is the terse operational summary.
;
; Entry state (DPMI spec, "Call-Back Procedure Parameters"): interrupts
; disabled; DS:(E)SI = selector:offset of the REAL-MODE SS:SP (NOT our flat
; data selector, NOT the rmcs — [DS:ESI]=return IP, [DS:ESI+2]=return CS,
; pushed by the driver's far CALL); ES:(E)DI = selector:offset of
; pktdrv_cb_rmcs, already filled with the real-mode register state (AX/CX/
; DS/SI etc, exactly as the driver set them); SS:(E)SP = a locked
; protected-mode API stack (push/pop-safe); all other registers undefined.
;
; MUST NOT call into game code, call DelayFrame, or do anything beyond
; rmcs/flag bookkeeping — this runs at a real-mode driver's interrupt-time
; call depth with interrupts disabled (ROOT spec's "KEEP THE PM HANDLER
; MINIMAL").
; ===========================================================================
pktdrv_pm_handler:
    ; --- capture the real-mode return address FIRST, while DS:ESI still
    ; aliases the real-mode stack (see the entry-state comment above) ---
    movzx eax, word [esi]              ; return IP
    movzx ebx, word [esi + 2]          ; return CS

    ; --- now switch to OUR flat data selector so pktdrv_cb_rmcs and the RX
    ; staging state become addressable. Cannot assume DS is anything useful
    ; here — use the same CS-relative-cache trick kbd_isr uses (joypad.asm):
    ; a plain `mov cx, [pktdrv_ds_cache]` would itself dereference through
    ; the WRONG (real-mode-aliasing) DS we are trying to replace. ---
    mov cx, [cs:pktdrv_ds_cache]
    mov ds, cx
    mov es, cx

    ; --- dispatch on the driver's call type (rmcs.AX, filled by the host) ---
    movzx edx, word [pktdrv_cb_rmcs + RMCS_EAX]
    test dx, dx
    jnz .call2

.call1:
    ; AX=0, rmcs.CX=incoming length (unused — buffers are fixed FRAME_MAX,
    ; and the driver never sends more than it was told the interface MTU
    ; is). Hand back a free RX slot's real-mode ES:DI, or 0:0 to reject.
    mov byte [pktdrv_pending_slot], 0xFF
    cmp byte [pktdrv_rxbuf_state + 0], 0
    jne .try1
    mov byte [pktdrv_rxbuf_state + 0], 1
    mov byte [pktdrv_pending_slot], 0
    mov cx, [pktdrv_seg]
    mov word [pktdrv_cb_rmcs + RMCS_ES], cx
    mov dword [pktdrv_cb_rmcs + RMCS_EDI], OFF_RXBUF0
    jmp .finish
.try1:
    cmp byte [pktdrv_rxbuf_state + 1], 0
    jne .reject
    mov byte [pktdrv_rxbuf_state + 1], 1
    mov byte [pktdrv_pending_slot], 1
    mov cx, [pktdrv_seg]
    mov word [pktdrv_cb_rmcs + RMCS_ES], cx
    mov dword [pktdrv_cb_rmcs + RMCS_EDI], OFF_RXBUF1
    jmp .finish
.reject:
    mov word [pktdrv_cb_rmcs + RMCS_ES], 0
    mov dword [pktdrv_cb_rmcs + RMCS_EDI], 0
    jmp .finish

.call2:
    ; AX=1: the slot our own call1 marked pending is now filled. If none was
    ; pending (a call2 with no matching call1 — should not happen per the
    ; packet driver spec's atomic call1/call2 pairing), drop it silently.
    movzx ecx, byte [pktdrv_pending_slot]
    cmp cl, 0xFF
    je .finish
    movzx edx, word [pktdrv_cb_rmcs + RMCS_ECX]  ; driver-reported length
    cmp dx, FRAME_MAX
    jbe .lenok
    mov dx, FRAME_MAX                  ; defensive clamp — never trust a
                                        ; real-mode driver's length blindly
.lenok:
    mov [pktdrv_rxbuf_len + ecx * 2], dx
    mov byte [pktdrv_rxbuf_state + ecx], 2       ; filled, ready for Recv
    mov byte [pktdrv_pending_slot], 0xFF

.finish:
    ; --- ES:EDI must again name pktdrv_cb_rmcs at IRET time (DPMI spec,
    ; "Return from Call-Back Procedure"). ES is already our flat selector
    ; (set above); EDI just needs the structure's own offset. ---
    mov edi, pktdrv_cb_rmcs

    ; --- set the return CS:IP (captured in EBX:EAX at entry) so real mode
    ; resumes AT THE DRIVER'S CALLER, not by re-entering our own callback
    ; address — the DPMI spec's documented anti-recursion requirement. ---
    mov word [pktdrv_cb_rmcs + RMCS_IP], ax
    mov word [pktdrv_cb_rmcs + RMCS_CS], bx

    ; --- pop the 2 words (IP, CS) we just consumed off the real-mode
    ; stack, mirroring what a real RETF would have done to SP. ---
    add word [pktdrv_cb_rmcs + RMCS_SP], 4

    iret
