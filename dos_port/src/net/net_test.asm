; ===========================================================================
; net_test.asm — DEBUG_NETTEST RAM-pipe unit test for the net_frame codec
; (port-only; linked only on DEBUG_NETTEST builds). Pattern: DEBUG_I2
; (RunLinkCupsTest) — a boot harness called from src/home/overworld.asm that
; runs synchronously, records results, and exits through DebugDumpMemory.
;
; Two NFCB codec instances (A, B) are cross-wired through in-memory byte
; FIFOs with deterministic fault injection at the sending edge:
;
;   A --tx--> [fault: drop/corrupt] --> fifo_ab --> rx --> B
;   B --tx--> [fault: drop/corrupt] --> fifo_ba --> rx --> A
;
; Phases:
;   1  clean pipe        — 20 EXCH messages each way, in order
;   2  byte drops A->B   — every 17th byte dropped; 20 more each way (ARQ)
;   3  corruption B->A   — every 19th byte xor $55; 20 more each way (CRC+ARQ)
;      (fault periods deliberately EXCEED the 14-byte frame length — see the
;       phase-2 comment in the driver for why a shorter period can never pass)
;   4  idle              — 200 ticks, no sends; both sides must emit
;                          keepalives (peer's rx_keepalives > 0)
;   5  dead pipe         — all bytes dropped both ways; A sends once; A must
;                          latch dead (retries/death timer); B unasserted
;
; Assertions -> results block written to GB WRAM at wTileMap (harness runs
; pre-game, the tilemap is free scratch), photographed by DebugDumpMemory's
; DEBUG_NETTEST window (src/debug/debug_dump.asm):
;   +0  db 'N','T', 1 (layout version), pass (1 = all assertions held)
;   +4  dw a_delivered   (expect 60)     +6  dw b_delivered   (expect 60)
;   +8  dw a_order_fail  (expect 0)      +10 dw b_order_fail  (expect 0)
;   +12 dw a_keepalives  (expect >0)     +14 dw b_keepalives  (expect >0)
;   +16 db a_dead        (expect 1)      +17 db b_dead        (informational)
;   +18 dw send_refused  (expect 0)      +20 dw ack_timeouts  (expect 0)
;
; Register use is free x86 (port-only test code); the net_frame callback
; contract (preserve EBX) is honored by every callback below.
;
; Build check: nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 \
;              -D DEBUG_NETTEST -o /dev/null src/net/net_test.asm
; ===========================================================================

bits 32

%include "gb_memmap.inc"
%include "net_frame.inc"

%ifdef DEBUG_NETTEST

global RunNetPipeTest

extern NetFrame_Reset               ; src/net/net_frame.asm
extern NetFrame_SendMsg
extern NetFrame_Tick
extern DebugDumpMemory              ; src/debug/debug_dump.asm — writes
                                    ; DUMP.BIN (+GBSTATE.BIN) and exits

FIFO_SIZE       equ 8192            ; power of two (mask below)
FIFO_MASK       equ FIFO_SIZE - 1

MSGS_PER_PHASE  equ 20
ACK_BOUND       equ 400             ; ticks to wait for one ack before failing
DEAD_BOUND      equ 1500            ; ticks to wait for phase-5 death latch

section .bss

ncb_a:          resb NFCB.size
ncb_b:          resb NFCB.size

fifo_ab_buf:    resb FIFO_SIZE
fifo_ba_buf:    resb FIFO_SIZE
fifo_ab_head:   resd 1              ; write index
fifo_ab_tail:   resd 1              ; read index
fifo_ba_head:   resd 1
fifo_ba_tail:   resd 1

; fault injection, applied at the sending edge of each pipe.
; drop_every = N: every Nth byte is dropped (1 = drop ALL). 0 = off.
; corrupt_every = N: every Nth byte is xor'd with $55. 0 = off.
drop_every_ab:  resd 1
drop_ctr_ab:    resd 1
corrupt_every_ab: resd 1
corrupt_ctr_ab: resd 1
drop_every_ba:  resd 1
drop_ctr_ba:    resd 1
corrupt_every_ba: resd 1
corrupt_ctr_ba: resd 1

; per-side receive tracking
a_expect:       resd 1              ; next exch_id A expects from B
b_expect:       resd 1              ; next exch_id B expects from A
a_delivered:    resd 1
b_delivered:    resd 1
a_order_fail:   resd 1
b_order_fail:   resd 1
a_dead_flag:    resb 1
b_dead_flag:    resb 1
send_refused:   resd 1
ack_timeouts:   resd 1

msg_buf:        resb 4              ; scratch payload

section .text

; ---------------------------------------------------------------------------
; FIFO helpers. In/out via EAX (byte in AL); indices wrap with FIFO_MASK.
; A full fifo drops the byte (counts as a wire drop; the ARQ recovers —
; and the driver drains every tick, so this never fires in practice).
; ---------------------------------------------------------------------------
%macro DEF_FIFO_PUSH 3              ; %1 name, %2 buf, %3 head/tail prefix
%1:
    push ecx
    push edx
    mov ecx, [%3 %+ _head]
    mov edx, ecx
    inc edx
    and edx, FIFO_MASK
    cmp edx, [%3 %+ _tail]
    je %%full                       ; full: drop
    mov [%2 + ecx], al
    mov [%3 %+ _head], edx
%%full:
    pop edx
    pop ecx
    ret
%endmacro

%macro DEF_FIFO_POP 3               ; %1 name, %2 buf, %3 head/tail prefix
%1:
    push ecx
    mov ecx, [%3 %+ _tail]
    cmp ecx, [%3 %+ _head]
    je %%empty
    mov al, [%2 + ecx]
    inc ecx
    and ecx, FIFO_MASK
    mov [%3 %+ _tail], ecx
    pop ecx
    clc
    ret
%%empty:
    pop ecx
    stc
    ret
%endmacro

DEF_FIFO_PUSH fifo_ab_push, fifo_ab_buf, fifo_ab
DEF_FIFO_POP  fifo_ab_pop,  fifo_ab_buf, fifo_ab
DEF_FIFO_PUSH fifo_ba_push, fifo_ba_buf, fifo_ba
DEF_FIFO_POP  fifo_ba_pop,  fifo_ba_buf, fifo_ba

; ---------------------------------------------------------------------------
; Fault filter — %1 pipe suffix (ab/ba), then push AL or mangle/drop it.
; ---------------------------------------------------------------------------
%macro DEF_FAULT_TX 2               ; %1 name, %2 pipe suffix
%1:
    push ecx
    ; drop?
    mov ecx, [drop_every_ %+ %2]
    test ecx, ecx
    jz %%no_drop
    inc dword [drop_ctr_ %+ %2]
    push eax
    mov eax, [drop_ctr_ %+ %2]
    xor edx, edx
    div ecx
    test edx, edx
    pop eax
    jnz %%no_drop
    pop ecx
    clc                             ; dropped silently ("sent" fine)
    ret
%%no_drop:
    ; corrupt?
    mov ecx, [corrupt_every_ %+ %2]
    test ecx, ecx
    jz %%no_corrupt
    inc dword [corrupt_ctr_ %+ %2]
    push eax
    mov eax, [corrupt_ctr_ %+ %2]
    xor edx, edx
    div ecx
    test edx, edx
    pop eax
    jnz %%no_corrupt
    xor al, 0x55
%%no_corrupt:
    call fifo_ %+ %2 %+ _push
    pop ecx
    clc
    ret
%endmacro

DEF_FAULT_TX a_txbyte, ab           ; A transmits into the A->B pipe
DEF_FAULT_TX b_txbyte, ba           ; B transmits into the B->A pipe

a_rxbyte:                           ; A receives from the B->A pipe
    jmp fifo_ba_pop
b_rxbyte:
    jmp fifo_ab_pop

; ---------------------------------------------------------------------------
; Deliver callbacks — record EXCH order/count. In: AL=type, CX=exch, DX=len.
; ---------------------------------------------------------------------------
a_deliver:
    cmp al, NF_EXCH
    jne .ret
    inc dword [a_delivered]
    movzx ecx, cx
    cmp ecx, [a_expect]
    je .in_order
    inc dword [a_order_fail]
.in_order:
    mov eax, [a_expect]
    inc eax
    mov [a_expect], eax
.ret:
    ret

b_deliver:
    cmp al, NF_EXCH
    jne .ret
    inc dword [b_delivered]
    movzx ecx, cx
    cmp ecx, [b_expect]
    je .in_order
    inc dword [b_order_fail]
.in_order:
    mov eax, [b_expect]
    inc eax
    mov [b_expect], eax
.ret:
    ret

a_dead_cb:
    mov byte [a_dead_flag], 1
    ret
b_dead_cb:
    mov byte [b_dead_flag], 1
    ret

; ---------------------------------------------------------------------------
; tick_both — one tick on each codec.
; ---------------------------------------------------------------------------
tick_both:
    mov ebx, ncb_a
    call NetFrame_Tick
    mov ebx, ncb_b
    call NetFrame_Tick
    ret

; ---------------------------------------------------------------------------
; send_and_wait — send EXCH exch_id=EAX from the codec in EBX, then tick both
; until that codec's tx_out clears or ACK_BOUND ticks pass (counted as an
; ack_timeout). Preserves EBX.
; ---------------------------------------------------------------------------
send_and_wait:
    mov [msg_buf + 0], al
    mov [msg_buf + 1], ah
    mov dl, al
    not dl
    mov [msg_buf + 2], dl
    mov byte [msg_buf + 3], 0x5A
    mov ecx, eax                    ; CX = exch_id
    mov esi, msg_buf
    mov dx, 4
    mov al, NF_EXCH
    call NetFrame_SendMsg
    jnc .sent
    inc dword [send_refused]
    ret
.sent:
    mov edi, ACK_BOUND
.wait:
    push edi
    push ebx
    call tick_both
    pop ebx
    pop edi
    cmp byte [ebx + NFCB.tx_out], 0
    je .done
    dec edi
    jnz .wait
    inc dword [ack_timeouts]
.done:
    ret

; ---------------------------------------------------------------------------
; run_phase — send MSGS_PER_PHASE messages alternately A->B then B->A.
; In: EAX = first exch_id of this phase (same id sequence both directions).
; ---------------------------------------------------------------------------
run_phase:
    mov edi, MSGS_PER_PHASE
.loop:
    push edi
    push eax
    mov ebx, ncb_a
    call send_and_wait              ; A -> B, exch id EAX
    pop eax
    push eax
    mov ebx, ncb_b
    call send_and_wait              ; B -> A, same id
    pop eax
    inc eax
    pop edi
    dec edi
    jnz .loop
    ret

; ---------------------------------------------------------------------------
; RunNetPipeTest — the harness entry (called at boot from overworld.asm).
; ---------------------------------------------------------------------------
RunNetPipeTest:
    ; wire A
    mov ebx, ncb_a
    mov dword [ebx + NFCB.cb_txbyte],  a_txbyte
    mov dword [ebx + NFCB.cb_rxbyte],  a_rxbyte
    mov dword [ebx + NFCB.cb_deliver], a_deliver
    mov dword [ebx + NFCB.cb_dead],    a_dead_cb
    call NetFrame_Reset
    ; wire B
    mov ebx, ncb_b
    mov dword [ebx + NFCB.cb_txbyte],  b_txbyte
    mov dword [ebx + NFCB.cb_rxbyte],  b_rxbyte
    mov dword [ebx + NFCB.cb_deliver], b_deliver
    mov dword [ebx + NFCB.cb_dead],    b_dead_cb
    call NetFrame_Reset
    mov dword [a_expect], 1
    mov dword [b_expect], 1

    ; ---- phase 1: clean ----
    mov eax, 1
    call run_phase
    ; ---- phase 2: drops on A->B ----
    mov dword [drop_every_ab], 17  ; MUST exceed the 14-byte frame length:
                                    ; a period <= frame length damages EVERY
                                    ; retransmission (a 14-byte window always
                                    ; contains a multiple of it) and the ARQ
                                    ; can never get a clean copy through
    mov eax, MSGS_PER_PHASE + 1
    call run_phase
    mov dword [drop_every_ab], 0
    ; ---- phase 3: corruption on B->A ----
    mov dword [corrupt_every_ba], 19 ; same rule as the drop period above
    mov eax, MSGS_PER_PHASE * 2 + 1
    call run_phase
    mov dword [corrupt_every_ba], 0
    ; ---- phase 4: idle -> keepalives ----
    mov edi, 200
.idle:
    push edi
    call tick_both
    pop edi
    dec edi
    jnz .idle
    ; ---- phase 5: dead pipe -> A latches dead ----
    mov dword [drop_every_ab], 1    ; drop everything, both directions
    mov dword [drop_every_ba], 1
    mov eax, 0x7777
    mov ebx, ncb_a
    mov [msg_buf], eax
    mov ecx, eax
    mov esi, msg_buf
    mov dx, 4
    mov al, NF_EXCH
    call NetFrame_SendMsg
    mov edi, DEAD_BOUND
.dead_wait:
    push edi
    call tick_both
    pop edi
    cmp byte [a_dead_flag], 0
    jne .dead_done
    dec edi
    jnz .dead_wait
.dead_done:

    ; ---- results -> GB WRAM @ wTileMap ----
    mov byte [ebp + wTileMap + 0], 'N'
    mov byte [ebp + wTileMap + 1], 'T'
    mov byte [ebp + wTileMap + 2], 1
    mov eax, [a_delivered]
    mov [ebp + wTileMap + 4], ax
    mov eax, [b_delivered]
    mov [ebp + wTileMap + 6], ax
    mov eax, [a_order_fail]
    mov [ebp + wTileMap + 8], ax
    mov eax, [b_order_fail]
    mov [ebp + wTileMap + 10], ax
    mov ax, [ncb_a + NFCB.rx_keepalives]
    mov [ebp + wTileMap + 12], ax
    mov ax, [ncb_b + NFCB.rx_keepalives]
    mov [ebp + wTileMap + 14], ax
    mov al, [a_dead_flag]
    mov [ebp + wTileMap + 16], al
    mov al, [b_dead_flag]
    mov [ebp + wTileMap + 17], al
    mov eax, [send_refused]
    mov [ebp + wTileMap + 18], ax
    mov eax, [ack_timeouts]
    mov [ebp + wTileMap + 20], ax
    ; diagnostic probe (bytes 24+): B parser state + the raw head of the A->B
    ; pipe, so a broken direction is debuggable from the dump alone
    mov al, [ncb_b + NFCB.rx_state]
    mov [ebp + wTileMap + 24], al
    mov al, [ncb_b + NFCB.rx_last_seq]
    mov [ebp + wTileMap + 25], al
    mov eax, [fifo_ab_head]
    mov [ebp + wTileMap + 26], ax
    mov eax, [fifo_ab_tail]
    mov [ebp + wTileMap + 28], ax
    mov al, [ncb_a + NFCB.tx_seq]
    mov [ebp + wTileMap + 30], al
    mov al, [ncb_a + NFCB.tx_out]
    mov [ebp + wTileMap + 31], al
    xor ecx, ecx
.probe_copy:
    mov al, [fifo_ab_buf + ecx]
    mov [ebp + wTileMap + 32 + ecx], al
    inc ecx
    cmp ecx, 16
    jb .probe_copy

    ; pass = every assertion held
    mov cl, 1
    cmp dword [a_delivered], MSGS_PER_PHASE * 3
    je .a_ok
    xor cl, cl
.a_ok:
    cmp dword [b_delivered], MSGS_PER_PHASE * 3
    je .b_ok
    xor cl, cl
.b_ok:
    cmp dword [a_order_fail], 0
    je .ao_ok
    xor cl, cl
.ao_ok:
    cmp dword [b_order_fail], 0
    je .bo_ok
    xor cl, cl
.bo_ok:
    cmp word [ncb_a + NFCB.rx_keepalives], 0
    jne .ka_ok
    xor cl, cl
.ka_ok:
    cmp word [ncb_b + NFCB.rx_keepalives], 0
    jne .kb_ok
    xor cl, cl
.kb_ok:
    cmp byte [a_dead_flag], 1
    je .ad_ok
    xor cl, cl
.ad_ok:
    cmp dword [send_refused], 0
    je .sr_ok
    xor cl, cl
.sr_ok:
    cmp dword [ack_timeouts], 0
    je .at_ok
    xor cl, cl
.at_ok:
    mov [ebp + wTileMap + 3], cl

    jmp DebugDumpMemory             ; writes DUMP.BIN (+GBSTATE.BIN), exits

%endif ; DEBUG_NETTEST
