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
;
; DEVIATION{class=HAL; pret=home/pikachu_cries.asm:PlayPikachuPCM; behavior=a digitized clip is fed to a Sound Blaster DSP one sample at a time in direct mode and paced by latching PIT channel 0, instead of being streamed as 1-bit samples through the Game Boy wave channel's DAC via rAUD3LEVEL; evidence=the DOS target has no wave channel and its DSP takes 8-bit PCM bytes rather than a DAC level, so both the output path and the timebase must be re-derived, and no pret routine has a DSP or PIT counterpart, the blocking interrupts-off structure is what pret does keep; lifetime=permanent, the PCM device shim is a hardware boundary}

bits 32

%include "gb_memmap.inc"

global sb_pcm_play
global pcm_pace_init
global pcm_pace
global sb_cry_play

%ifndef ENABLE_PIKA_PCM
%define ENABLE_PIKA_PCM 1
%endif

%if ENABLE_PIKA_PCM != 0

extern g_sb_base                  ; src/audio/audio_hal.asm (BLASTER A field)
extern current_pit_divisor        ; boot/timing.asm

; --- Pokemon cry audio engine externs (Stage 2/3) ---
extern opl_silence                ; src/audio/opl_shim.asm
extern enh_seq_stop               ; src/audio/opl_enh.asm
extern midi_all_notes_off         ; src/audio/mpu401.asm
extern tandy_silence              ; src/audio/tandy_shim.asm
extern spk_silence                ; src/audio/spk_shim.asm
extern covox_silence              ; src/audio/covox_shim.asm
extern cms_silence                ; src/audio/cms_shim.asm
extern innova_silence             ; src/audio/innova_shim.asm
extern g_cry_rate                 ; src/input/input_cfg.asm
extern cry_synth_set_rate         ; src/audio/cry_synth.asm
extern cry_pcm_buffer             ; src/audio/cry_synth.asm
extern cry_render_species         ; src/audio/cry_synth.asm
extern g_cry_frames_rendered      ; src/audio/cry_synth.asm
extern tick_count                 ; boot/timing.asm

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
    add dx, [current_pit_divisor] ; latched counter reloaded mid-gap
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

; ---------------------------------------------------------------------------
; sb_cry_play — play monster AL's cry on Sound Blaster DSP (Stage 2/3).
; Mutes all active sound sources, sets sample rate, renders cry via APU synth
; into cry_pcm_buffer, paces direct-mode DSP playback, reconciles frame timing
; for frozen tick_count / hFrameCounter / autokey_frame, and clears SFX channels.
;
; In:  AL  = species ID (1..151)
;      EBP = GB memory base
; Out: AL, EBX, EBP preserved.
; Clobbers: ECX, EDX, ESI, EDI.
; ---------------------------------------------------------------------------
sb_cry_play:
    push ebx
    push esi
    push edi
    push eax                      ; preserve AL (species ID) on stack

    ; a) Silence/mute all active sound sources:
    call opl_silence
    call enh_seq_stop
    call midi_all_notes_off
    call tandy_silence
    call spk_silence
    call covox_silence
    call cms_silence
    call innova_silence

    ; b) Setup sample rate:
    movzx eax, word [g_cry_rate]
    call cry_synth_set_rate

    ; c) Render the cry into cry_pcm_buffer:
    mov al, [esp]                 ; restore AL = species ID
    mov edi, cry_pcm_buffer
    mov ecx, 65536
    call cry_render_species
    ; EAX = samples rendered

    ; d) If EAX > 0:
    test eax, eax
    jz .reconcile
    push eax                      ; save samples rendered

    ; Calculate pacing step: step = (1193182 * 256 + rate / 2) / rate
    ; 1193182 * 256 = 305454592
    movzx ecx, word [g_cry_rate]
    test ecx, ecx
    jnz .haveRate
    mov ecx, 22050
.haveRate:
    mov eax, ecx
    shr eax, 1                    ; rate / 2
    add eax, 305454592            ; 1193182 * 256 + rate / 2
    xor edx, edx
    div ecx                       ; EAX = step in 24.8 fixed point

    pop ecx                       ; ECX = samples count
    mov esi, cry_pcm_buffer
    call sb_pcm_play

.reconcile:
    ; e) Reconcile frame timing:
    mov ecx, [g_cry_frames_rendered]
    add [tick_count], ecx
    sub byte [ebp + hFrameCounter], cl

    ; f) Clear stale sound IDs on CHAN5-CHAN8:
    xor eax, eax
    mov [ebp + wChannelSoundIDs + CHAN5], al
    mov [ebp + wChannelSoundIDs + CHAN6], al
    mov [ebp + wChannelSoundIDs + CHAN7], al
    mov [ebp + wChannelSoundIDs + CHAN8], al

    pop eax                       ; restore AL (species ID)
    pop edi
    pop esi
    pop ebx
    ret

section .bss
align 4
pace_step:  resd 1                ; PIT clocks per pacing tick, 24.8 fp
pace_acc:   resd 1                ; accumulated elapsed clocks, 24.8 fp
pace_prev:  resw 1                ; last latched ch0 count

%else

section .text
sb_pcm_play:
pcm_pace_init:
pcm_pace:
sb_cry_play:
    xor eax, eax
    ret

%endif
