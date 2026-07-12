; perf.asm — per-stage frame profiler (DEBUG_PERF builds only).
;
; The compositor-perf plan (docs/plans/compositor_perf.md) is staged
; "instrument first, then fix in ranked order". This is the instrument: it
; latches PIT channel 0 around each phase of DelayFrame and accumulates the
; elapsed PIT counts per stage, then writes PERF.BIN for the host to read
; (tools/read_perf.py).
;
; Why the PIT and not the TSC: the yardstick is real 386/486 hardware, where
; RDTSC does not exist (Pentium+). PIT channel 0 is already reprogrammed by
; timing.asm to the frame divisor, it ticks at a known 1,193,181.666 Hz
; regardless of CPU speed, and it is the same clock the game is paced by — so a
; measurement here is directly comparable between DOSBox-X cycle settings and
; real iron.
;
; Counting model: channel 0 counts DOWN from PIT_DIVISOR and reloads (mode 3),
; and timing.asm's ISR increments tick_count on each reload. So the elapsed
; count between two samples is
;
;     (ticks_now - ticks_prev) * PIT_DIVISOR + (count_prev - count_now)
;
; which stays correct for a stage that runs longer than one whole frame period
; (exactly the overrun case this plan exists to measure). Sampling is done with
; interrupts disabled so the tick_count / counter pair is coherent; the one
; residual race (counter wrapped, ISR not yet run) shows up as a negative delta
; and is corrected by adding one divisor.
;
; NOTE: this file is HAL/debug code, not a pret translation.
;
; Build: nasm -f coff -I include/ -I . -o perf.o src/debug/perf.asm
;        (linked only under -D DEBUG_PERF)

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"

%ifndef PIT_DIVISOR
%define PIT_DIVISOR 19506
%endif

; DEBUG_PERF_FRAMES=N: auto-dump PERF.BIN and exit after N measured frames
; (headless baseline capture). 0 / unset = dump only on quit (Esc).
%ifndef DEBUG_PERF_FRAMES
%define DEBUG_PERF_FRAMES 0
%endif

PIT_CMD_PORT   equ 0x43
PIT_CH0_PORT   equ 0x40
PIT_LATCH_CH0  equ 0x00        ; counter-latch command, channel 0

PERF_STAGES    equ 9           ; keep in sync with tools/read_perf.py STAGE_NAMES

; DPMI real-mode call structure field offsets (DPMI 0.9 spec)
RMCS_EBX     equ 0x10
RMCS_EDX     equ 0x14
RMCS_ECX     equ 0x18
RMCS_EAX     equ 0x1C
RMCS_FLAGS   equ 0x20
RMCS_DS      equ 0x24
RMCS_SIZE    equ 0x32

extern ds_base                 ; entry.asm — linear base of DS selector
extern tick_count              ; timing.asm — PIT ISR frame counter

global perf_frame_begin
global perf_mark
global perf_frame_end
global DumpPerf

; ---------------------------------------------------------------------------
section .data
align 4
pfname: db "PERF.BIN", 0
align 4
perf_magic: db "PERF"          ; PERF.BIN header magic

; ---------------------------------------------------------------------------
section .bss
align 4
perf_prev_cnt:   resd 1        ; PIT counter at the previous mark
perf_prev_tick:  resd 1        ; tick_count at the previous mark
perf_frames:     resd 1        ; measured frames
perf_acc:        resd PERF_STAGES   ; total PIT counts per stage
perf_max:        resd PERF_STAGES   ; worst single frame per stage
perf_cur:        resd PERF_STAGES   ; this frame's counts (folded into max at frame end)
rmcs:            resb RMCS_SIZE
dos_seg:         resw 1
dos_sel:         resw 1
dos_flat:        resd 1
file_handle:     resw 1

; ---------------------------------------------------------------------------
section .text

; ---------------------------------------------------------------------------
; perf_sample — read the PIT ch0 counter + tick_count coherently.
; Out: EAX = counter (0..PIT_DIVISOR-1), EDX = tick_count. ECX + flags clobbered.
; ---------------------------------------------------------------------------
perf_sample:
    pushfd
    cli
    mov al, PIT_LATCH_CH0
    out PIT_CMD_PORT, al
    in  al, PIT_CH0_PORT           ; latched low byte
    mov ah, al
    in  al, PIT_CH0_PORT           ; latched high byte
    xchg al, ah                    ; AL = lo, AH = hi (PIT read order is lo, hi)
    movzx eax, ax
    mov edx, [tick_count]
    popfd
    ret

; ---------------------------------------------------------------------------
; perf_frame_begin — start a measured frame (arm the first mark's baseline).
; All registers/flags preserved.
; ---------------------------------------------------------------------------
perf_frame_begin:
    pushfd
    pushad
    call perf_sample
    mov [perf_prev_cnt], eax
    mov [perf_prev_tick], edx
    ; zero this frame's per-stage counts
    mov edi, perf_cur
    mov ecx, PERF_STAGES
    xor eax, eax
    rep stosd
    popad
    popfd
    ret

; ---------------------------------------------------------------------------
; perf_mark — attribute the time since the previous mark to stage EAX.
; In: EAX = stage index (0..PERF_STAGES-1). All registers/flags preserved.
; ---------------------------------------------------------------------------
perf_mark:
    pushfd
    pushad
    mov ebx, eax                   ; EBX = stage index
    call perf_sample               ; EAX = counter, EDX = tick_count

    mov ecx, edx
    sub ecx, [perf_prev_tick]      ; whole PIT periods elapsed
    imul ecx, ecx, PIT_DIVISOR
    mov esi, [perf_prev_cnt]
    sub esi, eax                   ; counter counts DOWN → prev - now
    add ecx, esi
    jns .have_delta
    add ecx, PIT_DIVISOR           ; counter wrapped before the ISR ran
.have_delta:
    add [perf_acc + ebx*4], ecx
    add [perf_cur + ebx*4], ecx

    mov [perf_prev_cnt], eax
    mov [perf_prev_tick], edx
    popad
    popfd
    ret

; ---------------------------------------------------------------------------
; perf_frame_end — close the frame: fold perf_cur into the per-stage maxima and
; count the frame. Under DEBUG_PERF_FRAMES=N, dumps PERF.BIN and exits on the
; Nth frame. All registers/flags preserved (unless it exits).
; ---------------------------------------------------------------------------
perf_frame_end:
    pushfd
    pushad
    xor ebx, ebx
.max_loop:
    mov eax, [perf_cur + ebx*4]
    cmp eax, [perf_max + ebx*4]
    jbe .no_max
    mov [perf_max + ebx*4], eax
.no_max:
    inc ebx
    cmp ebx, PERF_STAGES
    jb .max_loop

    inc dword [perf_frames]
%if DEBUG_PERF_FRAMES > 0
    cmp dword [perf_frames], DEBUG_PERF_FRAMES
    jb .done
    call DumpPerf                  ; writes PERF.BIN, then exits — never returns
%endif
.done:
    popad
    popfd
    ret

; ---------------------------------------------------------------------------
; DumpPerf — write PERF.BIN, then exit.
;
; Same channel as debug_dump.asm: a conventional DOS buffer (DPMI fn 0100h) +
; INT 21h reflected to real mode (INT 31h AX=0300h), because CWSDPMI does not
; translate a protected-mode int 21h DS:DX pointer.
;
; File layout (little-endian dwords after the magic):
;   0x00  "PERF"
;   0x04  version          (1)
;   0x08  stage count      (PERF_STAGES)
;   0x0C  measured frames
;   0x10  PIT divisor
;   0x14  perf_acc[stage]  — total PIT counts
;   ...   perf_max[stage]  — worst single frame, PIT counts
; Never returns.
; ---------------------------------------------------------------------------
PERF_BODY_SIZE equ 0x14 + PERF_STAGES * 8

DumpPerf:
    mov ax, 0x0100
    mov bx, 0x40                   ; 1 KB conventional buffer (needs ~0x100)
    int 0x31
    jc .exit
    mov [dos_seg], ax
    mov [dos_sel], dx
    movzx eax, ax
    shl eax, 4
    sub eax, [ds_base]
    mov [dos_flat], eax

    ; filename at offset 0
    mov esi, pfname
    mov edi, [dos_flat]
    mov ecx, 9                     ; "PERF.BIN" + NUL
    rep movsb

    ; header + payload at offset 0x10
    mov edi, [dos_flat]
    add edi, 0x10
    mov esi, perf_magic
    movsd                          ; "PERF"
    mov eax, 1
    stosd                          ; version
    mov eax, PERF_STAGES
    stosd
    mov eax, [perf_frames]
    stosd
    mov eax, PIT_DIVISOR
    stosd
    mov esi, perf_acc
    mov ecx, PERF_STAGES
    rep movsd
    mov esi, perf_max
    mov ecx, PERF_STAGES
    rep movsd

    ; create
    call zero_rmcs
    mov word [rmcs + RMCS_EAX], 0x3C00
    mov dword [rmcs + RMCS_EDX], 0
    mov ax, [dos_seg]
    mov [rmcs + RMCS_DS], ax
    call sim_int21
    test byte [rmcs + RMCS_FLAGS], 1
    jnz .free
    mov ax, [rmcs + RMCS_EAX]
    mov [file_handle], ax

    ; write
    call zero_rmcs
    mov word [rmcs + RMCS_EAX], 0x4000
    movzx eax, word [file_handle]
    mov [rmcs + RMCS_EBX], eax
    mov dword [rmcs + RMCS_ECX], PERF_BODY_SIZE
    mov dword [rmcs + RMCS_EDX], 0x10
    mov ax, [dos_seg]
    mov [rmcs + RMCS_DS], ax
    call sim_int21

    ; close
    call zero_rmcs
    mov word [rmcs + RMCS_EAX], 0x3E00
    movzx eax, word [file_handle]
    mov [rmcs + RMCS_EBX], eax
    call sim_int21

.free:
    mov ax, 0x0101
    mov dx, [dos_sel]
    int 0x31
.exit:
    mov ax, 0x4C00
    int 0x21

; ---------------------------------------------------------------------------
; sim_int21 / zero_rmcs — local copies of the debug_dump.asm helpers (perf.asm
; links independently of DEBUG_DUMP; they are file-local, not duplicate globals).
; ---------------------------------------------------------------------------
sim_int21:
    push eax
    push ebx
    push ecx
    push edi
    mov ax, 0x0300
    mov bl, 0x21
    mov bh, 0
    xor cx, cx
    mov edi, rmcs                  ; ES already = flat DS selector
    int 0x31
    pop edi
    pop ecx
    pop ebx
    pop eax
    ret

zero_rmcs:
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
