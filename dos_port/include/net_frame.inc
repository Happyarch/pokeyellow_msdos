; ===========================================================================
; net_frame.inc — wire constants + NFCB layout for the link-cable frame
; codec (src/net/net_frame.asm). Shared with the DEBUG_NETTEST RAM-pipe
; harness (src/net/net_test.asm), which instantiates two NFCBs, and with
; transport drivers that bind callbacks. Port-only; no pret counterpart.
; docs/current_plan_link_cable.md Stage 2.
; ===========================================================================

%ifndef NET_FRAME_INC
%define NET_FRAME_INC

NF_SOF              equ 0xA5
NF_HDR_LEN          equ 7               ; type..len.hi (after SOF)

; frame types
NF_HELLO            equ 1               ; reliable — session handshake
NF_HELLO_ACK        equ 2               ; reliable — handshake reply
NF_EXCH             equ 3               ; reliable — one semantic GB exchange
NF_ACK              equ 4               ; control, unreliable (seq 0)
NF_KEEPALIVE        equ 5               ; control, unreliable (seq 0)

NET_MAX_PAYLOAD     equ 512             ; Stage 3's 424-byte block + headroom

; timers, in ~60 Hz frames of the nf_clock source (boot/timing.asm tick_count
; by default — see NetFrame_Tick). NOT pump calls: the pump runs far faster
; than the frame rate inside wait loops, and call-counted timers collapse the
; death window in wall time (measured 2026-08-22, linkcheck lc2: a LinkMenu
; park ticked ~10x frame rate, so the 600-"tick" death window shrank to ~1 s
; while the peer's keepalives still came at 1/s — both sides died).
NF_RTX_TICKS        equ 6               ; retransmit cadence (~100 ms)
NF_MAX_RETRIES      equ 180             ; retries before declaring dead
NF_KEEPALIVE_IDLE   equ 60              ; ~1 s idle -> keepalive
NF_DEATH_TICKS      equ 600             ; ~10 s no valid inbound -> dead

; ---- NFCB — per-instance codec control block ------------------------------
; All codec state; addressed off EBX in net_frame.asm. Callbacks first (the
; only fields an owner initializes by hand; NetFrame_Reset clears the rest).
struc NFCB
    .cb_txbyte:     resd 1              ; in AL=byte; CF=1 tx failure
    .cb_rxbyte:     resd 1              ; out CF=1 none, else AL=byte
    .cb_deliver:    resd 1              ; in AL=type CX=exch ESI=payload DX=len
    .cb_dead:       resd 1              ; link failure upcall
    ; RX parser
    .rx_state:      resb 1              ; 0 hunt / 1 header / 2 payload / 3 crc
    .rx_have:       resw 1
    .rx_type:       resb 1              ; rx_type..rx_len are CONTIGUOUS: the
    .rx_seq:        resb 1              ; header state stores by index off
    .rx_ack:        resb 1              ; rx_type (7 bytes)
    .rx_exch:       resw 1
    .rx_len:        resw 1
    .rx_crc:        resw 1
    .rx_buf:        resb NET_MAX_PAYLOAD
    ; RX ARQ state
    .rx_last_seq:   resb 1              ; last delivered reliable seq (0 none)
    .rx_keepalives: resw 1              ; observed keepalives (stats/tests)
    .death_timer:   resw 1              ; ticks since last valid inbound frame
    .dead:          resb 1              ; latched once cb_dead has fired
    ; TX ARQ state
    .tx_seq:        resb 1              ; seq of outstanding/last frame (0 none)
    .tx_out:        resb 1              ; 1 = awaiting ack
    .tx_timer:      resw 1              ; ticks since last (re)transmit
    .tx_retries:    resw 1
    .idle_timer:    resw 1              ; ticks since we last transmitted
    ; stored outstanding frame (SOF..crc) for retransmit
    .tx_len:        resw 1
    .tx_buf:        resb 1 + NF_HDR_LEN + NET_MAX_PAYLOAD + 2
    ; ARQ timer clock (kept AFTER tx_buf so the DEBUG_LINKCHECK ncbState
    ; probe's fixed 540-byte window keeps its field offsets)
    .last_clock:    resd 1              ; [nf_clock] value at the last Tick
    .size:
endstruc

%endif ; NET_FRAME_INC
