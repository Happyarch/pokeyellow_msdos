; ===========================================================================
; net_frame.asm — link-cable frame codec + stop-and-wait ARQ (port-only, no
; pret counterpart). docs/current_plan_link_cable.md Stage 2.
;
; Transport-agnostic reliable message layer over an unreliable BYTE STREAM.
; A transport driver (com_uart.asm; later ipx_dos/pktdrv wrap datagrams as
; one-frame streams) owns physical I/O and hands this layer callbacks; this
; layer owns framing, CRC, retransmission, dedupe, keepalives and death
; detection. The session logic above it (HELLO election, establishment
; synthesis, EXCH semantics) lives in the transport driver + net_hal — this
; file moves typed messages reliably and knows nothing else.
;
; Frame on the wire:
;   SOF($A5) type seq ack exch.lo exch.hi len.lo len.hi payload... crc.lo crc.hi
;   crc16-CCITT (poly $1021, init $FFFF) over type..payload inclusive.
;   Resync = hunt for SOF; the CRC rejects false starts (bytes consumed by a
;   false start are lost — the ARQ re-sends, so nothing is lost end to end;
;   a rescan buffer is deliberately NOT implemented).
;
; ARQ: stop-and-wait, matching the game's own one-outstanding-exchange
; lockstep. Reliable types (HELLO/HELLO_ACK/EXCH) carry seq 1..255 (0 =
; none); the receiver delivers a NEW seq, records it, and answers NF_ACK; a
; repeated seq is re-acked and dropped (dedupe). The sender retransmits every
; NF_RTX_TICKS pump ticks until acked; NF_MAX_RETRIES exhausted, or
; NF_DEATH_TICKS with no valid inbound frame, fires the dead callback (the
; session layer routes that into pret's own timeout paths — the disconnect
; escape hatch). NF_ACK / NF_KEEPALIVE are themselves unreliable (seq 0).
;
; Instantiable: all state lives in an NFCB (include/net_frame.inc) addressed
; off EBX, because the DEBUG_NETTEST RAM-pipe harness cross-wires TWO codecs
; in one image.
;
; REGISTER CONTRACT: everything here is called from inside NetHAL_Pump /
; NetHAL_StartTransfer's pushad (or from the standalone test harness), so
; routines clobber freely: EAX ECX EDX ESI EDI + flags; EBX = NFCB is
; preserved by every routine. Callbacks may clobber EAX ECX EDX ESI EDI but
; must preserve EBX.
;
; Build check: nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 \
;              -o /dev/null src/net/net_frame.asm   (from dos_port/)
; ===========================================================================

bits 32

%include "net_frame.inc"

global NetFrame_Reset
global NetFrame_SendMsg
global NetFrame_Tick

section .bss

crc_table:      resw 256                ; CRC16-CCITT, built on first use

; diagnostics (all instances pooled; only link_ncb is live outside tests) —
; DEBUG_LINKCHECK dumps these as the "nfDiag" GBSTATE probe region.
global g_nf_diag
align 4
g_nf_diag:
nf_ka_sent:     resd 1                  ; keepalive sends attempted (Tick)
nf_ctl_sent:    resd 1                  ; nf_send_ctl entries (acks+keepalives)
nf_rtx_count:   resd 1                  ; nf_tx_stored retransmissions
nf_tick_live:   resd 1                  ; Tick entries while not dead

section .data

crc_table_ready: db 0

section .text

; ---------------------------------------------------------------------------
; NetFrame_Reset — EBX = NFCB. Clears all state EXCEPT the four callbacks.
; ---------------------------------------------------------------------------
NetFrame_Reset:
    lea edi, [ebx + NFCB.rx_state]
    mov ecx, NFCB.size - NFCB.rx_state
    xor eax, eax
    rep stosb
    ret

; ---------------------------------------------------------------------------
; nf_crc_init — build the CCITT table once. Preserves EBX AND ECX/EDX/EAX:
; it is called at the top of nf_crc16, whose LENGTH ARGUMENT lives in ECX —
; the first-ever CRC in the process otherwise runs over 256 bytes of garbage
; and bakes a wrong CRC into the stored (retransmitted!) frame. Caught by
; DEBUG_NETTEST phase 1: A's first message could never deliver while every
; later frame was fine.
; ---------------------------------------------------------------------------
nf_crc_init:
    cmp byte [crc_table_ready], 0
    jne .ret
    push eax
    push ecx
    push edx
    xor ecx, ecx                        ; byte value 0..255
.byte_loop:
    mov ax, cx
    shl ax, 8
    mov edx, 8
.bit_loop:
    shl ax, 1
    jnc .no_poly
    xor ax, 0x1021
.no_poly:
    dec edx
    jnz .bit_loop
    mov [crc_table + ecx * 2], ax
    inc ecx
    cmp ecx, 256
    jb .byte_loop
    mov byte [crc_table_ready], 1
    pop edx
    pop ecx
    pop eax
.ret:
    ret

; ---------------------------------------------------------------------------
; nf_crc16 — one-shot CRC. In: ESI = flat ptr, ECX = len. Out: AX.
; Clobbers ECX EDX ESI EDI. Preserves EBX.
; ---------------------------------------------------------------------------
nf_crc16:
    call nf_crc_init
    mov ax, 0xFFFF
    jmp nf_crc_cont

; nf_crc_cont — continue a CRC already in AX over ESI/ECX. Preserves EBX.
nf_crc_cont:
.loop:
    test ecx, ecx
    jz .done
    movzx edx, byte [esi]
    inc esi
    movzx edi, ah
    xor edx, edi
    shl ax, 8
    xor ax, [crc_table + edx * 2]
    dec ecx
    jmp .loop
.done:
    ret

; ---------------------------------------------------------------------------
; nf_tx_stored — (re)transmit the stored frame at .tx_buf/.tx_len. EBX = NFCB.
; ---------------------------------------------------------------------------
nf_tx_stored:
    inc dword [nf_rtx_count]
    xor ecx, ecx
.loop:
    cmp cx, [ebx + NFCB.tx_len]
    jae .done
    push ecx
    mov al, [ebx + NFCB.tx_buf + ecx]
    call [ebx + NFCB.cb_txbyte]         ; CF on tx failure -> byte dropped;
    pop ecx                             ; the ARQ recovers, nothing to do here
    inc ecx
    jmp .loop
.done:
    mov word [ebx + NFCB.tx_timer], 0
    mov word [ebx + NFCB.idle_timer], 0
    ret

; ---------------------------------------------------------------------------
; nf_send_ctl — send a control frame (NF_ACK / NF_KEEPALIVE): header-only,
; seq 0, unreliable, NOT stored for retransmit.
; In: AL = type, AH = ack value. EBX = NFCB.
; ---------------------------------------------------------------------------
nf_send_ctl:
    inc dword [nf_ctl_sent]
    sub esp, 12                         ; frame staged on the stack (10 bytes)
    mov edi, esp
    mov byte [edi + 0], NF_SOF
    mov [edi + 1], al                   ; type
    mov byte [edi + 2], 0               ; seq 0 = unreliable
    mov [edi + 3], ah                   ; ack
    mov word [edi + 4], 0               ; exch_id
    mov word [edi + 6], 0               ; len
    lea esi, [edi + 1]
    mov ecx, NF_HDR_LEN
    call nf_crc16                       ; buffer sits above ESP: calls below
    mov edi, esp                        ; it never reach it
    mov [edi + 8], al                   ; crc.lo
    mov [edi + 9], ah                   ; crc.hi
    xor ecx, ecx
.loop:
    cmp ecx, 10
    jae .done
    push ecx
    mov eax, esp
    mov al, [eax + 4 + ecx]             ; frame base = esp after the push
    call [ebx + NFCB.cb_txbyte]
    pop ecx
    inc ecx
    jmp .loop
.done:
    add esp, 12
    mov word [ebx + NFCB.idle_timer], 0
    ret

; ---------------------------------------------------------------------------
; NetFrame_SendMsg — send one reliable message.
; In:  EBX = NFCB, AL = type (NF_HELLO / NF_HELLO_ACK / NF_EXCH),
;      CX = exch_id, ESI = payload flat ptr, DX = len (0..NET_MAX_PAYLOAD).
; Out: CF=0 accepted (stored + first transmission done);
;      CF=1 refused (frame still outstanding, len too big, or link dead).
; ---------------------------------------------------------------------------
NetFrame_SendMsg:
    cmp byte [ebx + NFCB.dead], 0
    jne .refuse
    cmp byte [ebx + NFCB.tx_out], 0
    jne .refuse                         ; stop-and-wait: one outstanding
    cmp dx, NET_MAX_PAYLOAD
    ja .refuse
    ; next seq: 1..255, skipping 0
    mov ah, [ebx + NFCB.tx_seq]
    inc ah
    jnz .seq_ok
    inc ah                              ; wrapped: 0 -> 1
.seq_ok:
    mov [ebx + NFCB.tx_seq], ah
    ; build SOF + header into .tx_buf
    lea edi, [ebx + NFCB.tx_buf]
    mov byte [edi + 0], NF_SOF
    mov [edi + 1], al                   ; type
    mov [edi + 2], ah                   ; seq
    mov al, [ebx + NFCB.rx_last_seq]
    mov [edi + 3], al                   ; piggyback ack (informational)
    mov [edi + 4], cx                   ; exch_id
    mov [edi + 6], dx                   ; len
    ; payload
    push esi
    movzx ecx, dx
    lea edi, [edi + 1 + NF_HDR_LEN]
    rep movsb
    pop esi
    ; crc over type..payload (contiguous in tx_buf)
    push edx
    lea esi, [ebx + NFCB.tx_buf + 1]
    movzx ecx, dx
    add ecx, NF_HDR_LEN
    call nf_crc16
    pop edx
    movzx edi, dx
    lea edi, [ebx + NFCB.tx_buf + 1 + NF_HDR_LEN + edi]
    mov [edi + 0], al
    mov [edi + 1], ah
    ; total length + ARQ arm + first transmission
    movzx eax, dx
    add eax, 1 + NF_HDR_LEN + 2
    mov [ebx + NFCB.tx_len], ax
    mov byte [ebx + NFCB.tx_out], 1
    mov word [ebx + NFCB.tx_retries], 0
    call nf_tx_stored
    clc
    ret
.refuse:
    stc
    ret

; ---------------------------------------------------------------------------
; NetFrame_Tick — one pump tick: drain RX bytes through the parser, then
; service the ARQ timers (retransmit, keepalive, death). EBX = NFCB.
; ---------------------------------------------------------------------------
NetFrame_Tick:
    cmp byte [ebx + NFCB.dead], 0
    jne .ret
    inc dword [nf_tick_live]
.rx_loop:
    call [ebx + NFCB.cb_rxbyte]         ; CF=1: no more bytes this tick
    jc .rx_done
    call nf_rx_byte
    jmp .rx_loop
.rx_done:
    ; death timer: ticks since the last VALID inbound frame
    inc word [ebx + NFCB.death_timer]
    cmp word [ebx + NFCB.death_timer], NF_DEATH_TICKS
    jb .alive
    jmp nf_go_dead
.alive:
    ; retransmit
    cmp byte [ebx + NFCB.tx_out], 0
    je .no_rtx
    inc word [ebx + NFCB.tx_timer]
    cmp word [ebx + NFCB.tx_timer], NF_RTX_TICKS
    jb .no_rtx
    inc word [ebx + NFCB.tx_retries]
    cmp word [ebx + NFCB.tx_retries], NF_MAX_RETRIES
    jae nf_go_dead
    call nf_tx_stored
.no_rtx:
    ; keepalive when idle
    inc word [ebx + NFCB.idle_timer]
    cmp word [ebx + NFCB.idle_timer], NF_KEEPALIVE_IDLE
    jb .ret
    inc dword [nf_ka_sent]
    mov al, NF_KEEPALIVE
    mov ah, [ebx + NFCB.rx_last_seq]
    call nf_send_ctl
.ret:
    ret

nf_go_dead:
    cmp byte [ebx + NFCB.dead], 0
    jne .ret
    mov byte [ebx + NFCB.dead], 1
    call [ebx + NFCB.cb_dead]
.ret:
    ret

; ---------------------------------------------------------------------------
; nf_rx_byte — feed one byte (AL) into the parser FSM. EBX = NFCB.
; ---------------------------------------------------------------------------
nf_rx_byte:
    movzx ecx, byte [ebx + NFCB.rx_state]
    jecxz .hunt
    cmp cl, 1
    je .header
    cmp cl, 2
    je .payload
    jmp .crc
.hunt:
    cmp al, NF_SOF
    jne .ret
    mov byte [ebx + NFCB.rx_state], 1
    mov word [ebx + NFCB.rx_have], 0
    ret
.header:
    movzx ecx, word [ebx + NFCB.rx_have]
    mov [ebx + NFCB.rx_type + ecx], al  ; rx_type..rx_len contiguous (7 bytes)
    inc ecx
    mov [ebx + NFCB.rx_have], cx
    cmp ecx, NF_HDR_LEN
    jb .ret
    mov word [ebx + NFCB.rx_have], 0
    movzx eax, word [ebx + NFCB.rx_len]
    cmp eax, NET_MAX_PAYLOAD
    ja .resync                          ; impossible length: false SOF
    test eax, eax
    jz .to_crc
    mov byte [ebx + NFCB.rx_state], 2
    ret
.to_crc:
    mov byte [ebx + NFCB.rx_state], 3
    ret
.payload:
    movzx ecx, word [ebx + NFCB.rx_have]
    mov [ebx + NFCB.rx_buf + ecx], al
    inc ecx
    mov [ebx + NFCB.rx_have], cx
    cmp cx, [ebx + NFCB.rx_len]
    jb .ret
    mov word [ebx + NFCB.rx_have], 0
    mov byte [ebx + NFCB.rx_state], 3
    ret
.crc:
    movzx ecx, word [ebx + NFCB.rx_have]
    mov [ebx + NFCB.rx_crc + ecx], al   ; crc lo then hi
    inc ecx
    mov [ebx + NFCB.rx_have], cx
    cmp ecx, 2
    jb .ret
    mov byte [ebx + NFCB.rx_state], 0   ; frame complete either way
    mov word [ebx + NFCB.rx_have], 0
    call nf_crc_hdr_payload
    cmp ax, [ebx + NFCB.rx_crc]
    jne .ret                            ; corrupt: drop, hunt for next SOF
    jmp nf_rx_frame
.resync:
    mov byte [ebx + NFCB.rx_state], 0
.ret:
    ret

; ---------------------------------------------------------------------------
; nf_crc_hdr_payload — CRC16 over rx_type..rx_len (7 B) then rx_buf[rx_len]
; (header and payload are not adjacent in the NFCB). Out: AX. Preserves EBX.
; ---------------------------------------------------------------------------
nf_crc_hdr_payload:
    call nf_crc_init
    mov ax, 0xFFFF
    lea esi, [ebx + NFCB.rx_type]
    mov ecx, NF_HDR_LEN
    call nf_crc_cont
    lea esi, [ebx + NFCB.rx_buf]
    movzx ecx, word [ebx + NFCB.rx_len]
    jmp nf_crc_cont

; ---------------------------------------------------------------------------
; nf_rx_frame — a CRC-valid frame sits in rx_*. Dispatch it. EBX = NFCB.
; ---------------------------------------------------------------------------
nf_rx_frame:
    mov word [ebx + NFCB.death_timer], 0
    mov al, [ebx + NFCB.rx_type]
    cmp al, NF_ACK
    je .ack
    cmp al, NF_KEEPALIVE
    je .keepalive
    ; reliable frame (HELLO / HELLO_ACK / EXCH / future reliable types)
    mov ah, [ebx + NFCB.rx_seq]
    test ah, ah
    jz .ret                             ; reliable frames never carry seq 0
    cmp ah, [ebx + NFCB.rx_last_seq]
    je .dup                             ; duplicate: re-ack, do not deliver
    mov [ebx + NFCB.rx_last_seq], ah
    ; ack first, then deliver — delivery may itself send the reply message,
    ; and the peer needs our ack before it will accept a new send anyway
    push eax
    mov al, NF_ACK                      ; ah = seq being acked
    call nf_send_ctl
    pop eax
    mov cx, [ebx + NFCB.rx_exch]
    lea esi, [ebx + NFCB.rx_buf]
    mov dx, [ebx + NFCB.rx_len]
    call [ebx + NFCB.cb_deliver]        ; AL still = type
    ret
.dup:
    mov al, NF_ACK                      ; ah = duplicate seq
    call nf_send_ctl
    ret
.ack:
    cmp byte [ebx + NFCB.tx_out], 0
    je .ret
    mov al, [ebx + NFCB.rx_ack]
    cmp al, [ebx + NFCB.tx_seq]
    jne .ret                            ; stale ack
    mov byte [ebx + NFCB.tx_out], 0
    ret
.keepalive:
    inc word [ebx + NFCB.rx_keepalives]
.ret:
    ret
