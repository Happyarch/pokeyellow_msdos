; spk_pcm.asm — PC-speaker PWM PCM player (Phase C).
; Port-only module (no pret counterpart; descriptive names per convention).
;
; RealSound-style pulse-width modulation: PIT channel 2 is put in mode 0
; (interrupt on terminal count) with lobyte-only access, the speaker gate is
; held open, and every carrier tick writes a new count proportional to the
; sample. In mode 0 the output sits low for <count> clocks after the write
; and high until the next write, so the duty cycle — and after the speaker
; cone's own low-pass, the voltage — tracks the sample. The carrier runs at
; 2× the sample rate (each sample written twice, ~22 kHz) to keep the
; carrier whine above hearing.
;
; Pacing reuses the PIT ch0 latch pacer from sb_pcm.asm. Interrupts are off
; for the whole clip — blocking is authentic (see sb_pcm.asm header).
;
; PWM depth: at 2×11025 Hz the carrier period is ~54 PIT clocks, so ~5.75
; bits of amplitude resolution — comfortably above the 1-bit source
; material. The pulse range is derived from the pacing step at run time, so
; a rate change in gen_pika_pcm.py needs no edit here.

bits 32

global spk_pcm_play

extern pcm_pace_init              ; src/audio/sb_pcm.asm
extern pcm_pace

PIT_CMD_PORT    equ 0x43
PIT_CH2_PORT    equ 0x42
PIT_CMD_CH2_PWM equ 0x90          ; channel 2, lobyte only, mode 0
PIT_CMD_CH2_SQR equ 0xB6          ; channel 2, lobyte/hibyte, mode 3 (BIOS-ish)
SPK_GATE_PORT   equ 0x61          ; bit 0 = ch2 gate, bit 1 = speaker data

section .text

; ---------------------------------------------------------------------------
; spk_pcm_play — play a clip through the speaker, blocking, interrupts off.
; In:  ESI = flat ptr to 8-bit unsigned samples
;      ECX = sample count (>0)
;      EAX = pacing step: PIT input clocks per sample in 24.8 fixed point
; Out: EAX = samples played (always == count; no handshake to wedge)
; Clobbers: EBX/ECX/EDX/EDI; advances ESI. Preserves EBP.
; ---------------------------------------------------------------------------
spk_pcm_play:
    push ecx
    pushfd
    cli
    shr eax, 1                    ; carrier step = sample step / 2
    mov edx, eax
    shr edx, 8
    dec edx                       ; pulse range = carrier clocks - 1 (~53)
    mov [spk_range], dl
    call pcm_pace_init
    in al, SPK_GATE_PORT
    mov [spk_gate_save], al
    or al, 3                      ; gate ch2 on + speaker data on
    out SPK_GATE_PORT, al
    mov al, PIT_CMD_CH2_PWM
    out PIT_CMD_PORT, al
    xor ebx, ebx                  ; carrier phase toggle
.carrier:
    call pcm_pace
    mov al, [esi]
    xor al, 0xFF                  ; mode 0: high (loud) time = period - count
    mul byte [spk_range]          ; AX = inverted sample * range
    mov al, ah
    inc al                        ; count in 1..range+1
    out PIT_CH2_PORT, al          ; restarts the one-shot -> next pulse
    xor bl, 1
    jnz .carrier                  ; first half of the sample: same byte again
    inc esi
    dec ecx
    jnz .carrier
    ; restore: gate/speaker off, ch2 back to a square-wave setup so a later
    ; beep (or the Phase D spk_shim) starts from the BIOS-conventional mode
    mov al, [spk_gate_save]
    out SPK_GATE_PORT, al
    mov al, PIT_CMD_CH2_SQR
    out PIT_CMD_PORT, al
    xor al, al
    out PIT_CH2_PORT, al          ; count 65536 (lo)
    out PIT_CH2_PORT, al          ; (hi)
    popfd
    pop eax                       ; samples played = requested count
    ret

section .bss
spk_range:      resb 1            ; PWM pulse range (carrier clocks - 1)
spk_gate_save:  resb 1            ; port 61h state to restore
