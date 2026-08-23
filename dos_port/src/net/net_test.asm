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
;   3b blocks, clean     — Stage 3: two 424-byte NF_BLK messages each way
;                          (the Serial_ExchangeBytes party-block size),
;                          content-verified byte-for-byte in the deliver cb
;   3c block + one-shot drop — one byte dropped mid-frame on A->B; the CRC
;                          rejects the severed frame and the ARQ's clean
;                          retransmit must deliver. (A PERIODIC fault cannot
;                          test a 434-byte frame: any period below the frame
;                          length damages every retransmission too — hence
;                          the one-shot mechanism.)
;   4  idle              — 200 ticks, no sends; both sides must emit
;                          keepalives (peer's rx_keepalives > 0)
;   5  dead pipe         — all bytes dropped both ways; A sends once; A must
;                          latch dead (retries/death timer); B unasserted
;
; Assertions -> results block written to GB WRAM at wTileMap (harness runs
; pre-game, the tilemap is free scratch), photographed by DebugDumpMemory's
; DEBUG_NETTEST window (src/debug/debug_dump.asm):
;   +0  db 'N','T', 2 (layout version), pass (1 = all assertions held)
;   +4  dw a_delivered   (expect 60)     +6  dw b_delivered   (expect 60)
;   +8  dw a_order_fail  (expect 0)      +10 dw b_order_fail  (expect 0)
;   +12 dw a_keepalives  (expect >0)     +14 dw b_keepalives  (expect >0)
;   +16 db a_dead        (expect 1)      +17 db b_dead        (informational)
;   +18 dw send_refused  (expect 0)      +20 dw ack_timeouts  (expect 0)
;   +48 dw a_blk_ok      (expect 3)      +50 dw b_blk_ok      (expect 3)
;   +52 dw blk_content_fail (expect 0)   (+24..47 = diagnostic probe, below)
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
extern nf_clock                     ; repointed at nt_clock below: the ARQ
                                    ; timers advance per tick_both iteration
                                    ; (wall frames would barely move in this
                                    ; tight loop), keeping every *_BOUND and
                                    ; NF_*_TICKS expectation an iteration count
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
nt_clock:       resd 1              ; the test's tick counter (see nf_clock)

fifo_ab_buf:    resb FIFO_SIZE
fifo_ba_buf:    resb FIFO_SIZE
fifo_ab_head:   resd 1              ; write index
fifo_ab_tail:   resd 1              ; read index
fifo_ba_head:   resd 1
fifo_ba_tail:   resd 1

; fault injection, applied at the sending edge of each pipe.
; drop_every = N: every Nth byte is dropped (1 = drop ALL). 0 = off.
; corrupt_every = N: every Nth byte is xor'd with $55. 0 = off.
; drop_once_at = N: drop exactly the Nth byte EVER sent on the pipe (one-shot,
;   absolute count against tx_total; self-clears). 0 = off. Exists for the
;   block phases: a periodic fault with period below the 434-byte block frame
;   damages every retransmission, so only a one-shot can prove ARQ recovery.
drop_every_ab:  resd 1
drop_ctr_ab:    resd 1
corrupt_every_ab: resd 1
corrupt_ctr_ab: resd 1
drop_once_at_ab: resd 1
tx_total_ab:    resd 1
drop_every_ba:  resd 1
drop_ctr_ba:    resd 1
corrupt_every_ba: resd 1
corrupt_ctr_ba: resd 1
drop_once_at_ba: resd 1
tx_total_ba:    resd 1

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

; block-phase tracking (Stage 3)
a_blk_ok:       resd 1              ; content-verified NF_BLK deliveries at A
b_blk_ok:       resd 1
blk_content_fail: resd 1            ; any byte mismatch, either side

msg_buf:        resb 4              ; scratch payload
BLK_LEN         equ 424             ; the Serial_ExchangeBytes party-block size
blk_pat:        resb BLK_LEN        ; staged block payload (pattern-filled)

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
    inc dword [tx_total_ %+ %2]
    ; one-shot drop? (absolute byte count; self-clears — header comment)
    mov ecx, [drop_once_at_ %+ %2]
    test ecx, ecx
    jz %%no_once
    cmp ecx, [tx_total_ %+ %2]
    jne %%no_once
    mov dword [drop_once_at_ %+ %2], 0
    pop ecx
    clc                             ; dropped silently ("sent" fine)
    ret
%%no_once:
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
; blk_verify — shared NF_BLK content check. In: CX=exch id, ESI=payload,
; DX=len. Out: EAX=1 content ok (len BLK_LEN and every byte == (i^id)&$ff),
; else 0 with blk_content_fail bumped. Preserves EBX (deliver cb contract).
blk_verify:
    cmp dx, BLK_LEN
    jne .bad
    xor eax, eax                    ; EAX = i
.chk:
    mov dl, al
    xor dl, cl                      ; expected byte = (i ^ id) & $ff
    cmp dl, [esi + eax]
    jne .bad
    inc eax
    cmp eax, BLK_LEN
    jb .chk
    mov eax, 1
    ret
.bad:
    inc dword [blk_content_fail]
    xor eax, eax
    ret

a_deliver:
    cmp al, NF_BLK
    jne .not_blk
    call blk_verify
    add [a_blk_ok], eax
    ret
.not_blk:
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
    cmp al, NF_BLK
    jne .not_blk
    call blk_verify
    add [b_blk_ok], eax
    ret
.not_blk:
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
    inc dword [nt_clock]
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
; blk_send_and_wait — fill blk_pat with the (i ^ id) pattern, send it as one
; NF_BLK from the codec in EBX, tick until acked (send_and_wait shape).
; In: EAX = block exch id. Preserves EBX.
; ---------------------------------------------------------------------------
blk_send_and_wait:
    push eax
    xor ecx, ecx
.fill:
    mov dl, cl
    xor dl, al                      ; byte i = (i ^ id) & $ff
    mov [blk_pat + ecx], dl
    inc ecx
    cmp ecx, BLK_LEN
    jb .fill
    pop eax
    mov ecx, eax                    ; CX = exch id
    mov esi, blk_pat
    mov dx, BLK_LEN
    mov al, NF_BLK
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
    mov dword [nf_clock], nt_clock  ; iteration-denominated timers (above)
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
    ; ---- phase 3b: blocks, clean (Stage 3 — 424-byte NF_BLK each way) ----
    mov eax, 100
    mov ebx, ncb_a
    call blk_send_and_wait          ; A -> B
    mov eax, 100
    mov ebx, ncb_b
    call blk_send_and_wait          ; B -> A
    mov eax, 101
    mov ebx, ncb_a
    call blk_send_and_wait
    mov eax, 101
    mov ebx, ncb_b
    call blk_send_and_wait
    ; ---- phase 3c: block + one-shot drop mid-frame on A->B (ARQ must
    ;      recover with the clean retransmit; see the one-shot rationale) ----
    mov eax, [tx_total_ab]
    add eax, 50                     ; lands inside A's next 434-byte frame
    mov [drop_once_at_ab], eax
    mov eax, 102
    mov ebx, ncb_a
    call blk_send_and_wait
    mov eax, 102
    mov ebx, ncb_b
    call blk_send_and_wait
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
    mov byte [ebp + wTileMap + 2], 2    ; layout v2: +48 block-phase results
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
    ; block-phase results (layout v2)
    mov eax, [a_blk_ok]
    mov [ebp + wTileMap + 48], ax
    mov eax, [b_blk_ok]
    mov [ebp + wTileMap + 50], ax
    mov eax, [blk_content_fail]
    mov [ebp + wTileMap + 52], ax

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
    cmp dword [a_blk_ok], 3
    je .abk_ok
    xor cl, cl
.abk_ok:
    cmp dword [b_blk_ok], 3
    je .bbk_ok
    xor cl, cl
.bbk_ok:
    cmp dword [blk_content_fail], 0
    je .bcf_ok
    xor cl, cl
.bcf_ok:
    mov [ebp + wTileMap + 3], cl

    jmp DebugDumpMemory             ; writes DUMP.BIN (+GBSTATE.BIN), exits

%endif ; DEBUG_NETTEST
