; sb_pcm.asm — Sound Blaster DSP direct-mode PCM player (Phase C).
; Port-only module (no pret counterpart; descriptive names per convention).
;
; Plays an 8-bit unsigned mono clip by hand-feeding the DAC one sample at a
; time: DSP command $10 + sample byte, paced by polling the PIT. Direct mode
; works on every DSP from 1.xx up and needs no DMA/IRQ setup — and blocking
; with interrupts off is *authentic*: the GB original (PlayPikachuPCM,
; home/pikachu_cries.asm) also monopolized the CPU with IME off for the
; whole clip.
;
; Pacing: PIT channel 0 keeps running its mode-3 square wave (boot/timing.asm,
; divisor PIT_DIVISOR) — we can't touch it, but we can *read* it. In mode 3
; the latched count decrements by 2 per 1.193182 MHz input clock and reloads
; at the half-period, so successive latches give elapsed clocks as
; ((prev - cur) mod PIT_DIVISOR) / 2, unambiguous for gaps < ~8 ms — the
; sample period here is ~91 µs. The pacer accumulates clocks in 24.8 fixed
; point against a caller-supplied step, so the average rate is exact and
; poll jitter self-corrects.
;
; The exported pacer (pcm_pace_init/pcm_pace) is also used by spk_pcm.asm.
; All DSP handshake polls are bounded — a wedged DSP aborts the clip, never
; hangs. Interrupts are off for the duration (tick_count stands still, like
; the GB's frozen VBlank).

bits 32

global sb_pcm_play
global pcm_pace_init
global pcm_pace

extern g_sb_base                  ; src/audio/audio_hal.asm (BLASTER A field)

PIT_CMD_PORT    equ 0x43
PIT_CH0_PORT    equ 0x40
%ifndef PIT_DIVISOR
%define PIT_DIVISOR 19506         ; SGB default, matches boot/timing.asm
%endif
DSP_TIMEOUT     equ 4000          ; bounded write-ready polls

section .text

; ---------------------------------------------------------------------------
; sb_pcm_play — play a clip on the DSP, blocking, interrupts off.
; In:  ESI = flat ptr to 8-bit unsigned samples
;      ECX = sample count (>0)
;      EAX = pacing step: PIT input clocks per sample in 24.8 fixed point
; Out: EAX = samples actually played (== count unless the DSP wedged)
; Clobbers: EBX/ECX/EDX/EDI; advances ESI. Preserves EBP.
; ---------------------------------------------------------------------------
sb_pcm_play:
    mov edi, ecx                  ; samples remaining
    movzx ebx, word [g_sb_base]
    test ebx, ebx
    jz .nodsp
    pushfd
    cli
    call pcm_pace_init
    mov al, 0xD1                  ; DSP speaker on (needed on pre-4.xx DSPs)
    call .dspWrite
    jc .abort
.sample:
    call pcm_pace
    mov al, 0x10                  ; DSP direct-mode output
    call .dspWrite
    jc .abort
    mov al, [esi]
    call .dspWrite
    jc .abort
    inc esi
    dec edi
    jnz .sample
.abort:
    mov al, 0xD3                  ; DSP speaker off
    call .dspWrite
    popfd
    mov eax, ecx
    sub eax, edi                  ; samples played
    ret
.nodsp:
    xor eax, eax
    ret

; .dspWrite — write AL to the DSP command/data port with a bounded
; write-ready poll. In: EBX = DSP base. Out: CF set on timeout. Preserves AL.
.dspWrite:
    push ecx
    mov ah, al
    lea edx, [ebx + 0xC]
    mov ecx, DSP_TIMEOUT
.rdy:
    in al, dx
    test al, 0x80                 ; bit 7 clear = ready for write
    jz .send
    loop .rdy
    mov al, ah
    pop ecx
    stc
    ret
.send:
    mov al, ah
    out dx, al
    pop ecx
    clc
    ret

; ---------------------------------------------------------------------------
; pcm_pace_init — arm the pacer. In: EAX = step (PIT clocks per tick, 24.8
; fixed point). Clobbers AX/DX flags only. Call with interrupts off.
; ---------------------------------------------------------------------------
pcm_pace_init:
    mov [pace_step], eax
    xor eax, eax
    mov [pace_acc], eax
    call pit_latch_ch0
    mov [pace_prev], ax
    ret

; ---------------------------------------------------------------------------
; pcm_pace — busy-wait until one pacing step has elapsed since the last
; return (steps never drift: the fractional remainder carries over, and an
; overrun is repaid on the next call). Clobbers EAX/EDX.
; ---------------------------------------------------------------------------
pcm_pace:
.wait:
    call pit_latch_ch0
    mov dx, [pace_prev]
    mov [pace_prev], ax
    sub dx, ax                    ; elapsed mode-3 counts = prev - cur
    jnc .noWrap
    add dx, PIT_DIVISOR           ; latched counter reloaded mid-gap
.noWrap:
    movzx edx, dx
    shl edx, 7                    ; counts dec by 2 per clock; <<8 fp, /2
    add edx, [pace_acc]
    mov [pace_acc], edx
    cmp edx, [pace_step]
    jb .wait
    sub edx, [pace_step]
    mov [pace_acc], edx
    ret

; pit_latch_ch0 — latch and read PIT channel 0. Out: AX = count. Clobbers AL.
pit_latch_ch0:
    xor al, al                    ; latch command, channel 0
    out PIT_CMD_PORT, al
    in al, PIT_CH0_PORT
    mov ah, al
    in al, PIT_CH0_PORT
    xchg al, ah                   ; AX = lo | hi<<8
    ret

section .bss
align 4
pace_step:  resd 1                ; PIT clocks per pacing tick, 24.8 fp
pace_acc:   resd 1                ; accumulated elapsed clocks, 24.8 fp
pace_prev:  resw 1                ; last latched ch0 count
