; cry_synth.asm — Game Boy APU software synthesis core for Pokémon cries.
;
; Port-only module (no pret counterpart; dedicated cry engine, Stage 1).
; Sourced from the proven APU synthesis core in covox_shim.asm.
;
; Synthesizes the 3-channel Game Boy APU cry audio stream:
;   - Pulse 1 & Pulse 2: 4 variable duty cycles (12.5%, 25%, 50%, 75%), phase
;     accumulators, and sub-sample bandlimited interpolation to eliminate edge
;     quantization jitter and aliasing at arbitrary sample rates.
;   - Noise: 15-bit and 7-bit LFSR polynomial generators with fractional clock
;     accumulation, faithfully emulating metallic buzz (7-bit) vs white noise (15-bit).
;   - Envelopes & Volume: 60 Hz volume envelope step emulation, length counter,
;     hardware frequency sweep on Pulse 1, master volume from rAUDVOL (NR50),
;     and terminal panning from rAUDTERM (NR51).
;   - Output format: 8-bit unsigned mono PCM centered on 128 (0=min, 128=silence, 255=max).
;
; Rate-agnostic: precalculates 64-bit/32-bit step numerators at initialization
; (defaults to 11025 Hz matching PIKA_PCM_RATE, supports 8000 Hz, 22050 Hz, etc.).

bits 32

%include "gb_memmap.inc"

global cry_synth_init
global cry_synth_reset
global cry_synth_set_rate
global cry_synth_frame_setup
global cry_synth_render_samples
global cry_synth_frame
global cry_render_clip
global cry_render_species
global cry_synth_init_c
global cry_synth_reset_c
global cry_synth_frame_c
global g_cry_synth_rate
global cry_state
global cry_master
global g_cry_frames_rendered
global cry_pcm_buffer

extern Audio1_UpdateMusic         ; src/audio/engine_1.asm
extern GetCryData                 ; src/home/pokemon.asm
extern PlaySound                  ; src/home/audio.asm

; --- Per-voice software state offsets (mirrors covox_shim CS_*) ---
CS_FREQ       equ 0    ; word: GB 11-bit freq incl. sweep (ch3: NR43 byte in lo)
CS_KEY        equ 2    ; byte: key-on flag
CS_ENVVOL     equ 3    ; byte: current GB volume 0-15 (ridden as amplitude)
CS_ENVDIR     equ 4    ; byte: envelope direction (1 = up)
CS_ENVPER     equ 5    ; byte: envelope period (0 = off)
CS_ENVACC     equ 6    ; word: envelope accumulator (64/tick vs 60*period)
CS_LEN        equ 8    ; word: length counter (1/256 s units)
CS_LENACC     equ 10   ; word: length accumulator (256/tick vs 60)
CS_LENEN      equ 12   ; byte: length enable (NRx4 bit 6)
CS_SWEEP      equ 13   ; byte: NR10 latched at key-on (ch0 only)
CS_SWACC      equ 14   ; word: sweep accumulator (128/tick vs 60*period)
CS_PHASE      equ 16   ; dd: 16.16-cycle phase accumulator (wrap is the octave)
CS_STEP       equ 20   ; dd: 16.16-cycle phase step per sample, latched per tick
                       ; (ch3 reuses this slot for its LFSR clocks-per-sample)
CS_LFSR       equ 24   ; word: ch3 15/7-bit LFSR (nonzero seed, never 0)
CS_NACC       equ 26   ; dd: ch3 LFSR-clock fractional accumulator (16.16)
CS_AMP        equ 30   ; byte: latched signed amplitude (0 = silent this tick)
CS_LVL        equ 31   ; byte: ch2 NR32 level code 0-2 (full/half/quarter)
CS_SIZE       equ 32

section .text

; ===========================================================================
; cry_synth_init — initialize synthesizer state and configure sample rate.
; In:  EAX = sample rate in Hz (0 defaults to 11025 Hz)
; Out: EAX = effective sample rate
; Preserves EBX, ECX, EDX, ESI, EDI, EBP.
; ===========================================================================
cry_synth_init:
    push ebx
    push ecx
    push edx
    push esi
    push edi

    test eax, eax
    jnz .haveRate
    mov eax, 11025                ; default rate (11,025 Hz)
.haveRate:
    call cry_synth_set_rate
    call cry_synth_reset

    mov eax, [g_cry_synth_rate]
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

; ===========================================================================
; cry_synth_reset — clear all voice state, reseeds noise LFSR, silences synth.
; Preserves all registers.
; ===========================================================================
cry_synth_reset:
    push eax
    push ecx
    push edi

    mov edi, cry_state
    mov ecx, 4 * CS_SIZE
    xor al, al
    rep stosb

    ; Noise LFSR must have non-zero seed (0x7FFF) so it never locks
    mov word [cry_state + 3*CS_SIZE + CS_LFSR], 0x7FFF

    mov byte [s_master], 7
    mov byte [cry_master], 7
    mov byte [s_nr51], 0xFF

    pop edi
    pop ecx
    pop eax
    ret

; ===========================================================================
; cry_synth_set_rate — calculate step numerators for a given sample rate.
; In:  EAX = sample rate in Hz (clamps < 16 to 11025)
; Out: EAX = effective sample rate
; Preserves EBX, ESI, EDI, EBP. Clobbers ECX, EDX.
; ===========================================================================
cry_synth_set_rate:
    cmp eax, 16
    jae .valid
    mov eax, 11025
.valid:
    mov [g_cry_synth_rate], eax
    mov ecx, eax                  ; ECX = sample rate

    ; Square: GB Fout = 131072 / (2048 - f). Phase wraps at 2^32.
    ; step = (131072 * 2^32 / rate) / (2048 - f) = (2^49 / rate) / (2048 - f).
    ; 2^49 = 0x20000:00000000. 64-bit div by rate gives [s_k_hi]:[s_k_lo].
    mov eax, 0x20000
    xor edx, edx
    div ecx                       ; EAX = s_k_hi, EDX = remainder
    mov [s_k_hi], eax
    xor eax, eax
    div ecx                       ; EAX = s_k_lo
    mov [s_k_lo], eax

    ; Wave: GB Fout = 65536 / (2048 - f) = half of square rate
    mov eax, [s_k_lo]
    mov edx, [s_k_hi]
    shr edx, 1
    rcr eax, 1
    mov [s_kw_lo], eax
    mov [s_kw_hi], edx

    ; Noise: 16.16 clocks-per-sample = (2^35 / rate) / divisor
    ; 2^35 = 0x8:00000000. Div by rate gives 32-bit quotient.
    xor eax, eax
    mov edx, 8
    div ecx
    mov [s_kn], eax

    mov eax, [g_cry_synth_rate]
    ret

; ===========================================================================
; cry_synth_frame_setup — update voice parameters from virtual APU for this frame.
; In:  EBP = pointer to GB memory base
; Clobbers: EAX, EBX, ECX, EDX, ESI, EDI. Preserves EBP.
; ===========================================================================
cry_synth_frame_setup:
    ; Master volume from NR50 (louder terminal)
    mov al, [ebp + rAUDVOL]
    mov ah, al
    shr ah, 4
    and ah, 7
    and al, 7
    cmp al, ah
    jae .m1
    mov al, ah
.m1:
    mov [s_master], al
    mov [cry_master], al
    mov al, [ebp + rAUDTERM]
    mov [s_nr51], al

    xor ebx, ebx                  ; voice index 0-3
.chLoop:
    lea esi, [ebx*4 + ebx + 0xFF10] ; channel register base (0xFF10, 0xFF15, 0xFF1A, 0xFF1F)
    imul eax, ebx, CS_SIZE
    lea edi, [cry_state + eax]    ; EDI = voice state pointer

    mov al, [ebp + esi + 4]       ; NRx4
    test al, 0x80
    jz .noRestart
    and al, 0x7F                  ; consume restart bit
    mov [ebp + esi + 4], al
    call cry_keyon
    jmp .svc

.noRestart:
    cmp byte [edi + CS_KEY], 0
    jz .next
    cmp ebx, 3
    je .fNoise
    ; Frequency follow (vibrato / pitch slides)
    mov cl, [ebp + esi + 3]
    mov ch, [ebp + esi + 4]
    and ch, 7
    cmp cx, [edi + CS_FREQ]
    je .svc
    mov [edi + CS_FREQ], cx
    jmp .svc

.fNoise:
    mov al, [ebp + esi + 3]       ; NR43
    cmp al, [edi + CS_FREQ]
    je .svc
    mov [edi + CS_FREQ], al

.svc:
    cmp byte [edi + CS_KEY], 0
    jz .next
    call cry_sweep
    call cry_envelope
    call cry_length
    cmp byte [edi + CS_KEY], 0
    jz .next
    call cry_setup

.next:
    inc ebx
    cmp ebx, 4
    jb .chLoop
    ret

; ---------------------------------------------------------------------------
; Internal helper: cry_keyon — trigger channel EBX from APU registers
; ---------------------------------------------------------------------------
cry_keyon:
    cmp ebx, 2
    je .noEnv
    mov al, [ebp + esi + 2]
    mov ah, al
    shr ah, 4
    mov [edi + CS_ENVVOL], ah
    mov ah, al
    shr ah, 3
    and ah, 1
    mov [edi + CS_ENVDIR], ah
    and al, 7
    mov [edi + CS_ENVPER], al
    mov word [edi + CS_ENVACC], 0
.noEnv:
    movzx eax, byte [ebp + esi + 1]
    cmp ebx, 2
    jz .len8
    and eax, 0x3F
    neg eax
    add eax, 64
    jmp .lenSet
.len8:
    neg eax
    add eax, 256
.lenSet:
    mov [edi + CS_LEN], ax
    mov word [edi + CS_LENACC], 0
    mov al, [ebp + esi + 4]
    and al, 0x40
    mov [edi + CS_LENEN], al
    test ebx, ebx
    jnz .noSweep
    mov al, [ebp + rAUD1SWEEP]
    mov [edi + CS_SWEEP], al
    mov word [edi + CS_SWACC], 0
.noSweep:
    cmp ebx, 3
    je .noiseInit
    mov cl, [ebp + esi + 3]
    mov ch, [ebp + esi + 4]
    and ch, 7
    mov [edi + CS_FREQ], cx
    mov dword [edi + CS_PHASE], 0
    jmp .keyed
.noiseInit:
    mov al, [ebp + esi + 3]
    mov [edi + CS_FREQ], al
    mov word [edi + CS_LFSR], 0x7FFF
    mov dword [edi + CS_NACC], 0
.keyed:
    mov byte [edi + CS_KEY], 1
    mov byte [edi + CS_AMP], 0
    ret

; ---------------------------------------------------------------------------
; Internal helper: cry_keyoff — silence channel EBX on expiry/overflow
; ---------------------------------------------------------------------------
cry_keyoff:
    mov byte [edi + CS_KEY], 0
    mov byte [edi + CS_AMP], 0
    ret

; ---------------------------------------------------------------------------
; Internal helper: cry_sweep — pulse 1 hardware sweep (128 Hz base clock)
; ---------------------------------------------------------------------------
cry_sweep:
    test ebx, ebx
    jnz .done
    mov al, [edi + CS_SWEEP]
    mov cl, al
    shr cl, 4
    and cl, 7                     ; period
    jz .done
    movzx eax, cl
    imul eax, 60
    movzx ecx, word [edi + CS_SWACC]
    add ecx, 128
    cmp ecx, eax
    jb .store
    sub ecx, eax
    mov [edi + CS_SWACC], cx
    ; f' = f +/- (f >> n)
    movzx eax, word [edi + CS_FREQ]
    mov edx, eax
    mov cl, [edi + CS_SWEEP]
    and cl, 7
    shr eax, cl
    test byte [edi + CS_SWEEP], 8
    jnz .down
    add edx, eax
    cmp edx, 2048
    jb .apply
    jmp cry_keyoff                ; 11-bit overflow silences channel
.down:
    sub edx, eax
    jns .apply
    xor edx, edx
.apply:
    mov [edi + CS_FREQ], dx
    ret
.store:
    mov [edi + CS_SWACC], cx
.done:
    ret

; ---------------------------------------------------------------------------
; Internal helper: cry_envelope — 64 Hz volume envelope step
; ---------------------------------------------------------------------------
cry_envelope:
    cmp ebx, 2
    je .done                      ; wave has no envelope
    mov al, [edi + CS_ENVPER]
    test al, al
    jz .done
    movzx ecx, al
    imul ecx, 60
    movzx eax, word [edi + CS_ENVACC]
    add eax, 64
    cmp eax, ecx
    jb .store
    sub eax, ecx
    mov cl, [edi + CS_ENVVOL]
    cmp byte [edi + CS_ENVDIR], 0
    jz .down
    cmp cl, 15
    jae .store
    inc cl
    jmp .set
.down:
    test cl, cl
    jz .store
    dec cl
.set:
    mov [edi + CS_ENVVOL], cl
.store:
    mov [edi + CS_ENVACC], ax
.done:
    ret

; ---------------------------------------------------------------------------
; Internal helper: cry_length — 256 Hz length countdown
; ---------------------------------------------------------------------------
cry_length:
    cmp byte [edi + CS_LENEN], 0
    jz .done
    movzx eax, word [edi + CS_LENACC]
    add eax, 256
    movzx ecx, word [edi + CS_LEN]
.step:
    cmp eax, 60
    jb .save
    sub eax, 60
    dec ecx
    jnz .step
    mov word [edi + CS_LEN], 0
    mov byte [edi + CS_LENEN], 0
    mov [edi + CS_LENACC], ax
    jmp cry_keyoff
.save:
    mov [edi + CS_LEN], cx
    mov [edi + CS_LENACC], ax
.done:
    ret

; ---------------------------------------------------------------------------
; Internal helper: cry_setup — latch phase step and amplitude for sounding voice
; ---------------------------------------------------------------------------
cry_setup:
    mov cl, bl
    mov ch, 0x11
    shl ch, cl
    test [s_nr51], ch             ; both stereo terminals clear -> mute
    jz .mute
    cmp ebx, 2
    je .wave
    cmp ebx, 3
    je .noise

    ; Square (ch0 / ch1): step = s_k / (2048 - f)
    movzx eax, word [edi + CS_FREQ]
    and eax, 0x7FF
    mov ecx, 2048
    sub ecx, eax
    mov eax, [s_k_lo]
    mov edx, [s_k_hi]
    cmp edx, ecx
    jae .sqMax
    div ecx
    jmp .sqStore
.sqMax:
    mov eax, 0x7FFFFFFF
.sqStore:
    mov [edi + CS_STEP], eax
    mov al, [edi + CS_ENVVOL]
    mov [edi + CS_AMP], al
    ret

.wave:
    mov al, [ebp + rAUD3ENA]
    test al, 0x80
    jz .mute
    movzx eax, byte [ebp + rAUD3LEVEL]
    shr eax, 5
    and eax, 3
    jz .mute
    dec eax
    mov [edi + CS_LVL], al
    movzx eax, word [edi + CS_FREQ]
    and eax, 0x7FF
    mov ecx, 2048
    sub ecx, eax
    mov eax, [s_kw_lo]
    mov edx, [s_kw_hi]
    cmp edx, ecx
    jae .wMax
    div ecx
    jmp .wStore
.wMax:
    mov eax, 0x7FFFFFFF
.wStore:
    mov [edi + CS_STEP], eax
    mov byte [edi + CS_AMP], 1
    ret

.noise:
    ; Clocks-per-sample = s_kn / nr43divisor
    mov al, [edi + CS_FREQ]
    movzx ecx, al
    shr ecx, 4                    ; s (0-15)
    and eax, 7                    ; r
    jnz .haveR
    mov eax, 1
    shl eax, cl
    jmp .haveDiv
.haveR:
    inc ecx                       ; s+1
    shl eax, cl
.haveDiv:
    mov ecx, eax
    mov eax, [s_kn]
    xor edx, edx
    div ecx
    mov [edi + CS_STEP], eax
    mov al, [edi + CS_ENVVOL]
    mov [edi + CS_AMP], al
    ret

.mute:
    mov byte [edi + CS_AMP], 0
    ret

; ===========================================================================
; cry_synth_render_samples — synthesize ECX samples into [EDI] buffer.
; In:  EDI = pointer to output buffer (unsigned 8-bit PCM)
;      ECX = number of samples to synthesize
;      EBP = pointer to GB memory base
; Out: EDI = advanced past written samples (EDI + ECX)
;      EAX = number of samples synthesized
; Preserves EBX, ESI, EBP.
; ===========================================================================
cry_synth_render_samples:
    test ecx, ecx
    jz .doneZero
    push ebx
    push esi
    push ebp

    mov [s_out_ptr], edi
    mov [s_nsamp_tot], ecx
    mov [s_nsamp_rem], ecx

.sampleLoop:
    xor edx, edx                  ; signed mix sum
    xor ebx, ebx                  ; voice index 0..3

.voiceLoop:
    imul eax, ebx, CS_SIZE
    lea edi, [cry_state + eax]    ; EDI = voice state pointer
    mov al, [edi + CS_AMP]
    test al, al
    jz .voiceNext
    cmp ebx, 2
    je .voiceWave
    cmp ebx, 3
    je .voiceNoise

    ; --- Square (ch0 / ch1): sub-sample bandlimited interpolation ---
    movsx esi, byte [edi + CS_AMP]
    mov eax, [edi + CS_PHASE]
    add eax, [edi + CS_STEP]
    mov [edi + CS_PHASE], eax
    jc .sqWrap

    ; No wrap: fetch duty threshold into ECX
    lea ecx, [ebx*4 + ebx]
    mov cl, [ebp + ecx + 0xFF11]  ; NRx1 duty bits
    shr cl, 6
    movzx ecx, cl
    mov ecx, [CryDutyThresh + ecx*4]
    cmp eax, ecx
    jae .sqFalling
    add edx, esi
    jmp .voiceNext

.sqFalling:
    sub eax, ecx                  ; delta = new_phase - threshold
    cmp eax, [edi + CS_STEP]
    jae .sqSteadyLo
    push edx
    lea ecx, [esi + esi]          ; 2 * A
    mul ecx                       ; delta * 2A
    div dword [edi + CS_STEP]     ; drop
    pop edx
    sub esi, eax                  ; A - drop
    add edx, esi
    jmp .voiceNext

.sqSteadyLo:
    sub edx, esi
    jmp .voiceNext

.sqWrap:
    lea ecx, [ebx*4 + ebx]
    mov cl, [ebp + ecx + 0xFF11]
    shr cl, 6
    movzx ecx, cl
    mov ecx, [CryDutyThresh + ecx*4]
    cmp eax, ecx
    jb .sqWrapRise
    mov eax, ecx
.sqWrapRise:
    push edx
    lea ecx, [esi + esi]          ; 2 * A
    mul ecx                       ; new_phase * 2A
    div dword [edi + CS_STEP]     ; rise
    pop edx
    sub eax, esi                  ; -A + rise
    add edx, eax
    jmp .voiceNext

.voiceWave:
    ; --- Wave (ch2) ---
    mov eax, [edi + CS_PHASE]
    add eax, [edi + CS_STEP]
    mov [edi + CS_PHASE], eax
    shr eax, 27
    mov esi, eax
    shr esi, 1
    mov cl, [ebp + esi + _AUD3WAVERAM]
    movzx ecx, cl
    test eax, 1
    jnz .wLo
    shr ecx, 4
    jmp .wLvl
.wLo:
    and ecx, 15
.wLvl:
    sub ecx, 8
    cmp byte [edi + CS_LVL], 1
    je .wAdd
    jb .wFull
    sar ecx, 1
    jmp .wAdd
.wFull:
    add ecx, ecx
.wAdd:
    add edx, ecx
    jmp .voiceNext

.voiceNoise:
    ; --- Noise (ch3) ---
    mov eax, [edi + CS_NACC]
    add eax, [edi + CS_STEP]
    mov ecx, eax
    shr ecx, 16
    and eax, 0xFFFF
    mov [edi + CS_NACC], eax
    movzx eax, word [edi + CS_LFSR]
    test ecx, ecx
    jz .nOut
    test byte [edi + CS_FREQ], 8
    jnz .n7
.n15:
    mov esi, eax
    shr esi, 1
    xor esi, eax
    and esi, 1
    shr eax, 1
    shl esi, 14
    or eax, esi
    loop .n15
    jmp .nStore
.n7:
    mov esi, eax
    shr esi, 1
    xor esi, eax
    and esi, 1
    shr eax, 1
    shl esi, 14
    or eax, esi
    shr esi, 8
    or eax, esi
    loop .n7
.nStore:
    mov [edi + CS_LFSR], ax
.nOut:
    and eax, 1
    jz .nLo
    movsx esi, byte [edi + CS_AMP]
    add edx, esi
    jmp .voiceNext
.nLo:
    movsx esi, byte [edi + CS_AMP]
    sub edx, esi

.voiceNext:
    inc ebx
    cmp ebx, 4
    jb .voiceLoop

    ; Master scale and center: out = 128 + sum*master/4
    mov eax, edx
    movzx ecx, byte [s_master]
    imul eax, ecx
    sar eax, 2
    add eax, 128
    test eax, eax
    jns .noMin
    xor eax, eax
.noMin:
    cmp eax, 255
    jbe .noMax
    mov eax, 255
.noMax:
    mov edi, [s_out_ptr]
    mov [edi], al
    inc edi
    mov [s_out_ptr], edi

    dec dword [s_nsamp_rem]
    jnz .sampleLoop

    pop ebp
    pop esi
    pop ebx
    mov edi, [s_out_ptr]
    mov eax, [s_nsamp_tot]
    ret

.doneZero:
    xor eax, eax
    ret

; ===========================================================================
; cry_synth_frame — convenience: setup one frame and render ECX samples into [EDI].
; In:  EDI = destination buffer (flat 32-bit pointer)
;      ECX = number of samples to synthesize
;      EBP = GB memory base
; Out: EDI = advanced past written samples
;      EAX = number of samples written
; Preserves EBX, ESI, EBP.
; ===========================================================================
cry_synth_frame:
    push edi
    push ecx
    call cry_synth_frame_setup
    pop ecx
    pop edi
    jmp cry_synth_render_samples

; ===========================================================================
; cry_render_clip — render an armed cry to completion into [EDI].
; Advances cry bytecode frame-by-frame via Audio1_UpdateMusic, synthesizing
; samples into [EDI] until the cry finishes or buffer space runs out.
;
; In:  EDI = destination buffer
;      ECX = max buffer size in bytes (samples)
;      EBP = GB memory base
; Out: EDI = advanced past written samples
;      EAX = total samples synthesized
; Preserves EBP. Clobbers EBX, ECX, EDX, ESI.
; ===========================================================================
cry_render_clip:
    push ebp
    mov [clip_dest], edi
    mov [clip_max], ecx
    mov dword [clip_tot_samples], 0
    mov dword [g_cry_frames_rendered], 0
    mov word [clip_carry], 0

    ; Ensure rate is configured
    mov eax, [g_cry_synth_rate]
    test eax, eax
    jnz .rateOk
    mov eax, 11025
    call cry_synth_set_rate
.rateOk:
    call cry_synth_reset

    ; Route all channels to both terminals during cry render
    mov byte [ebp + rAUDTERM], 0xFF

    ; Temporarily pause background music (CHAN1-CHAN4)
    mov al, [ebp + wMuteAudioAndPauseMusic]
    mov [clip_saved_mute], al
    or byte [ebp + wMuteAudioAndPauseMusic], 1 << BIT_MUTE_AUDIO

    ; Safety frame limit: max 300 frames (~5.0s)
    mov dword [clip_frame_limit], 300

.frameLoop:
    ; 1. Advance audio engine bytecode by 1 frame
    call Audio1_UpdateMusic

    ; 2. Check if cry channels are active (Pulse 1=CHAN5, Pulse 2=CHAN6, Noise=CHAN8)
    mov al, [ebp + wChannelSoundIDs + CHAN5]
    or al, [ebp + wChannelSoundIDs + CHAN6]
    or al, [ebp + wChannelSoundIDs + CHAN8]
    test al, al
    jz .cryDone

    ; 3. Calculate samples for this frame: (rate + carry) / 60
    movzx eax, word [clip_carry]
    add eax, [g_cry_synth_rate]
    xor edx, edx
    mov ecx, 60
    div ecx                       ; EAX = samples, EDX = remainder
    mov [clip_carry], dx
    mov ecx, eax                  ; ECX = samples to render

    ; 4. Check buffer space
    mov eax, [clip_max]
    sub eax, [clip_tot_samples]
    jbe .cryDone
    cmp ecx, eax
    jbe .spaceOk
    mov ecx, eax
.spaceOk:
    ; 5. Synthesize frame
    mov edi, [clip_dest]
    call cry_synth_frame
    mov [clip_dest], edi
    add [clip_tot_samples], eax
    inc dword [g_cry_frames_rendered]

    dec dword [clip_frame_limit]
    jnz .frameLoop

.cryDone:
    ; Restore background music pause/mute state
    mov al, [clip_saved_mute]
    mov [ebp + wMuteAudioAndPauseMusic], al

    mov edi, [clip_dest]
    mov eax, [clip_tot_samples]
    pop ebp
    ret

; ===========================================================================
; cry_render_species — setup and render a Pokémon's cry by species ID.
; In:  AL  = species ID (1..151)
;      EDI = destination buffer
;      ECX = max buffer size in bytes
;      EBP = GB memory base
; Out: EDI = advanced past written samples
;      EAX = total samples synthesized
; ===========================================================================
cry_render_species:
    push ebx
    push ecx
    push edx
    push esi

    push ecx
    push edi
    call GetCryData               ; AL = sound_id, wFrequencyModifier/wTempoModifier set
    call PlaySound                ; arms CHAN5-CHAN8
    pop edi
    pop ecx

    call cry_render_clip

    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

; ===========================================================================
; C calling convention wrappers (cdecl) for host / test harness integration:
; ===========================================================================
cry_synth_init_c:
    mov eax, [esp + 4]
    jmp cry_synth_init

cry_synth_reset_c:
    jmp cry_synth_reset

cry_synth_frame_c:
    push ebp
    push edi
    push ebx
    push esi
    mov edi, [esp + 20]           ; dest buffer
    mov ecx, [esp + 24]           ; num_samples
    mov ebp, [esp + 28]           ; gb_mem base
    call cry_synth_frame
    pop esi
    pop ebx
    pop edi
    pop ebp
    ret

section .data
align 4
CryDutyThresh: dd 0x20000000, 0x40000000, 0x80000000, 0xC0000000

section .bss

cry_state:          resb 4 * CS_SIZE
g_cry_synth_rate:   resd 1        ; sample rate in Hz (e.g. 11025)
s_k_lo:             resd 1        ; square step numerator lo
s_k_hi:             resd 1        ; square step numerator hi
s_kw_lo:            resd 1        ; wave step numerator lo
s_kw_hi:            resd 1        ; wave step numerator hi
s_kn:               resd 1        ; noise clocks numerator
s_out_ptr:          resd 1        ; output buffer cursor
s_nsamp_tot:        resd 1        ; total samples requested
s_nsamp_rem:        resd 1        ; remaining samples to render
clip_dest:          resd 1
clip_max:           resd 1
clip_tot_samples:   resd 1
clip_frame_limit:   resd 1
clip_carry:         resw 1
s_master:           resb 1        ; latched master volume (0-7)
cry_master:         resb 1        ; exported alias for master volume
s_nr51:             resb 1        ; latched NR51 routing
clip_saved_mute:    resb 1
alignb 4
g_cry_frames_rendered: resd 1     ; frames rendered during last cry_render_clip
cry_pcm_buffer:     resb 65536    ; 64 KB PCM render scratch buffer

