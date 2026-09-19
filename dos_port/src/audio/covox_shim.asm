; covox_shim.asm — virtual APU → Covox Speech Thing / Disney Sound Source DAC shim (port-only HAL layer).
;
; Port-only module (no pret counterpart; this file has no GB original and is
; owned by the DOS audio HAL, wired in stage 2 from audio_tick/audio_init).
;
; The Covox is a passive 8-bit R-2R DAC on the LPT data lines: no voices, no
; clock, no buffer, no DMA/IRQ. The CPU outputs one byte per sample
; (OUT COVOX_DATA); the sustained output rate is whatever the CPU holds, so
; quality scales with the machine. The Disney Sound Source accepts the same
; raw writes and re-clocks them through its FIFO at its own fixed rate, which
; absorbs the burst-then-idle pacing of a 60 Hz tick loop.
;
; Once per audio tick covox_pass renders the 4 GB channels from the virtual
; APU block at [ebp+$FF10..$FF26] as unsigned 8-bit PCM into an internal
; ring buffer (the fill side advances the write cursor s_wr), and covox_pump
; drains that tick's samples to COVOX_DATA in a short port-I/O burst:
;
;   GB ch0 pulse1  -> square at GB duty (12.5/25/50/75%) and GB pitch
;   GB ch1 pulse2  -> square (same duty/pitch rendering)
;   GB ch2 wave    -> _AUD3WAVERAM 32-nibble wavetable verbatim, upsampled
;                     through the phase accumulator, NR32 level as amplitude
;                     (the fidelity win no other shim gets: OPL fakes the wave
;                     with an FM patch and the PSG cannot do it at all)
;   GB ch3 noise   -> software 15/7-bit LFSR, clocked at the NR43 rate
;
; Like innova_shim, the engine's NRx4 restart bit is CONSUMED here (read and
; cleared; the engine never reads it back), and what the DAC lacks is
; emulated in software per tick, in GB units: envelope (NRx2), sweep (NR10,
; pulse1), length (NRx1/NRx4 bit 6), master volume (NR50 louder side), and
; NR51 muting (both terminal bits clear -> silent). The sustain-riding
; convention is innova's (gate held, attack/decay/release 0) — here it means
; the envelope level rides the output amplitude directly each tick, i.e. the
; amplitude is held, not shaped.
;
; SFX ducking is inherited, not built: the mixer reads the virtual APU after
; Audio1_UpdateMusic, so the engine's own SFX channel-takeover flows through
; with no shim logic. The MIDI-coexistence guard (tandy shape: voices mute
; unless an SFX owns the channel while g_midi_music is active) is replicated
; now so stage 2.3 needs no mixer change.
;
; Output encoding follows the DSS guide section 3 table (8-bit unsigned:
; 255 = max, 128 = mid, 0 = min) — silence MUST center on 128, not 0. Every
; render path funnels through the master scaler, so an all-muted tick emits
; exactly 128.
;
; Rate-agnostic from day one (fixed-point phase accumulators, no rate
; literals anywhere in this file): the per-tick step numerators are derived
; from g_covox_rate (extern word owned by input_cfg, parsed once at boot
; from the config into its compiled-in default and clamped there), and
; samples-per-tick is rate/60 with fractional carry. A zero or degenerate
; rate (< 16 Hz) renders nothing rather than faulting a divide.
;
; The shim activates only via the /COVOX command-line flag (stage 2:
; audio_init sets the device and calls covox_init); with g_covox_on = 0
; every entry point no-ops. Covox is explicit-only, never auto-selected.
;
; Snapshot placement (provisional; stage 1.4 wired the harness call, the
; tick/init wiring stays stage 2): window 9
; of the DEBUG_AUDIO dump is fully allocated (+0x40..+0x7F: opl SB detect,
; MIDI driver, pika PCM, hal device, tandy, speaker, OPL enh, innova frag —
; every byte spoken for, all snapshots run unconditionally), so there is no
; free dumped byte for a Covox block today. covox_dbg_snapshot publishes 8
; bytes at W_PORT_SCRATCH+0x81..+0x88, deliberately skipping the named
; W_CHECK_FOR_TURN byte at +0x80; the bytes overlay unnamed echo-RAM slack
; (the port does not emulate the echo mirror, the same basis W_PORT_SCRATCH
; itself stands on) on the innova +0x7D..+0x7F precedent. The DEBUG_AUDIO
; harness calls the snapshot (debug_dump RunAudioTest); the tick/init wiring
; stays stage 2. Stage 1.4 extended window 9 in debug_dump.asm (a 64-byte
; window at +0x40 cannot see past +0x7F) and confirms via DUMP.BIN that the
; bytes arrive undisturbed.

%include "gb_memmap.inc"

global covox_init
global covox_pass
global covox_pump
global covox_play_clip
global covox_silence
global covox_shutdown
global covox_dbg_snapshot
global g_covox_on

%ifndef ENABLE_AUDIO_COVOX
%define ENABLE_AUDIO_COVOX 1
%endif

%if ENABLE_AUDIO_COVOX != 0

; Rate equ only (the blob stays in pikachu_pcm.o): the cry player resamples
; the PIKA_PCM_RATE blob to g_covox_rate, so it needs the source rate.
%define PIKA_PCM_EQUATES_ONLY
%include "assets/pika_pcm.inc"

extern g_midi_music               ; src/audio/mpu401.asm — MIDI mode active
extern g_covox_rate               ; word: PCM rate in Hz, owned by input_cfg
                                  ; (parsed once at boot; tick path only)
extern pcm_pace_init              ; src/audio/sb_pcm.asm — PIT pacer
extern pcm_pace                   ; (both stub-safe when PIKA is disabled)

section .text

COVOX_DATA equ 0x378              ; LPT data lines = the DAC (raw writes)
COVOX_STATUS equ 0x379            ; status port: DSS FIFO-full sense is bit 6
                                  ; (low = room; the pump polls it bounded)
COVOX_CONTROL equ 0x37A           ; DSS strobe/power control (pin 17 SELECT);
                                ; raw-Covox v1 never writes it
PR_STROBE     equ 0x0C            ; guide §6: control byte whose pin-17 LOW
PR_POWER_UP   equ 0x04            ; ...then HIGH clocks one byte into the FIFO
                                ; (rising edge; power stays on)
COVOX_POLLS equ 64                ; per-burst cadence-poll bound (never a hang)

; --- per-voice software state (offsets 0-15 mirror innova_shim's SS_*) ----
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

; --- internal sample ring (filled here, pumped to COVOX_DATA by covox_pump)
COVOX_RING_SIZE equ 2048          ; ~2.7 ticks at the fastest configured rate;
                                  ; fill and pump stay in lockstep, so the ring
                                  ; never overruns in steady state
COVOX_RING_MASK equ 2047         ; power-of-two mask for the write cursor

; --- debug snapshot block (provisional placement, see header) --------------
COVOX_SNAP equ (W_PORT_SCRATCH + 0x81)

; ===========================================================================
; covox_init — reset software state, prime the ring with silence, mark active.
; Stage-2 audio_init calls this only when /COVOX selected the device.
; Preserves all registers.
; ===========================================================================
covox_init:
    pushad
    mov byte [g_covox_on], 1
    mov ecx, 4 * CS_SIZE
    mov edi, covox_state
.clr:
    mov byte [edi], 0
    inc edi
    loop .clr
    mov word [covox_state + 3*CS_SIZE + CS_LFSR], 0x7FFF
    mov word [s_wr], 0
    mov word [s_rd], 0
    mov word [s_carry], 0
    call covox_silence
    popad
    ret

; ===========================================================================
; covox_silence — leave the DAC silent: cut every voice and center the ring
; on 128 (the DSS mid level). Exported for PlayPikachuSoundClip like
; tandy_silence: software envelopes freeze during the cli PCM clip, so held
; notes must be cut; voices re-key on their next note-on. Safe with the shim
; inactive (touches only port RAM, no port I/O).
; ===========================================================================
covox_silence:
    cmp byte [g_covox_on], 0
    jz .off
    push eax
    push ecx
    push edi
    lea edi, [covox_state]
    mov ecx, 4
.key:
    mov byte [edi + CS_KEY], 0
    mov byte [edi + CS_AMP], 0
    add edi, CS_SIZE
    loop .key
    mov edi, covox_ring
    mov ecx, COVOX_RING_SIZE
    mov al, 128
    rep stosb
    mov word [s_wr], 0
    mov word [s_rd], 0
    mov word [s_carry], 0
    pop edi
    pop ecx
    pop eax
.off:
    ret

; covox_shutdown — leave the DAC silent on exit. Tail-jump (tandy_shutdown
; shape); silence's own save/restore keeps every register. Preserves all.
covox_shutdown:
    jmp covox_silence

; ===========================================================================
; covox_pass — the per-tick render. Stage-2 audio_tick calls this (DelayFrame
; is pushad-wrapped, registers may be clobbered freely). Updates envelopes,
; sweep and length in GB units, latches per-voice step/amplitude, then mixes
; rate/60 samples (fractional carry) into the ring as unsigned bytes.
; ===========================================================================
covox_pass:
    cmp byte [g_covox_on], 0
    jz .off
    movzx ecx, word [g_covox_rate]
    test ecx, ecx
    jz .off                       ; unconfigured rate: render nothing
    cmp ecx, 16
    jb .off                       ; degenerate rate: no output, never a fault
    ; master amplitude from NR50 (the louder terminal, like tandy_shim, so
    ; FadeOutAudio's simultaneous L/R ramp maps to a single amplitude ramp)
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
    mov al, [ebp + rAUDTERM]
    mov [s_nr51], al
    ; per-tick step numerators from the configured rate (64-bit dividends so
    ; no GB clock literal appears: 2^33 = EDX:EAX with EDX=2, 2^34 with EDX=4)
    xor eax, eax
    mov edx, 2
    div ecx                       ; EAX = 2^33/rate (square/wave numerator)
    mov [s_k16], eax
    xor eax, eax
    mov edx, 4
    div ecx                       ; EAX = 2^34/rate (noise numerator)
    mov [s_kn], eax
    ; samples this tick: quot = rate/60 plus Bresenham carry on the remainder
    mov eax, ecx
    xor edx, edx
    mov ebx, 60
    div ebx
    add dx, [s_carry]
    cmp dx, 60
    jb .noCarry
    sub dx, 60
    inc eax
.noCarry:
    mov [s_carry], dx
    mov [s_nsamp], ax
    xor ebx, ebx                  ; voice index 0-3
.chLoop:
    lea esi, [ebx*4 + ebx]
    add esi, 0xFF10               ; channel register base
    imul eax, ebx, CS_SIZE
    lea edi, [covox_state + eax]
    mov al, [ebp + esi + 4]       ; NRx4
    test al, 0x80
    jz .noRestart
    and al, 0x7F                  ; consume the restart bit
    mov [ebp + esi + 4], al
    call covox_keyon
    jmp .svc
.noRestart:
    cmp byte [edi + CS_KEY], 0
    jz .next
    cmp ebx, 3
    je .fNoise
    ; frequency follow (engine vibrato / pitch slides)
    mov cl, [ebp + esi + 3]
    mov ch, [ebp + esi + 4]
    and ch, 7
    cmp cx, [edi + CS_FREQ]
    je .svc
    mov [edi + CS_FREQ], cx
    jmp .svc
.fNoise:
    mov al, [ebp + esi + 3]       ; NR43 live (base 0xFF1F + 3)
    cmp al, [edi + CS_FREQ]
    je .svc
    mov [edi + CS_FREQ], al
.svc:
    cmp byte [edi + CS_KEY], 0
    jz .next
    call covox_sweep
    call covox_envelope
    call covox_length
    ; re-checked after length/sweep: an expired voice renders silence this
    ; tick instead of one last latched sample (its KEY is already 0)
    cmp byte [edi + CS_KEY], 0
    jz .next
    call covox_setup
.next:
    inc ebx
    cmp ebx, 4
    jb .chLoop
    ; --- silence fast path: every voice latched amplitude 0 AND the ring
    ; empty means this tick would emit ~117 mid-level bytes at the cost of
    ; ~117*64 status polls + 117 OUTs — pure overhead (measured 2026-09-18:
    ; it buried the frame budget and stalled boot). Skip render AND pump;
    ; keys/phases are preserved, so audio resumes cleanly next tick. A
    ; non-empty ring still drains below (stale samples must flush).
    xor eax, eax
    or al, [covox_state + 0*CS_SIZE + CS_AMP]
    or al, [covox_state + 1*CS_SIZE + CS_AMP]
    or al, [covox_state + 2*CS_SIZE + CS_AMP]
    or al, [covox_state + 3*CS_SIZE + CS_AMP]
    jnz .samp
    mov ax, [s_wr]
    sub ax, [s_rd]
    jz .off
    ; --- backlog guard (render-on-demand): the pump leaves undrained
    ; samples in the ring when the FIFO stays full (wedged/absent port);
    ; never render on top of a nearly-full ring — the write cursor would
    ; lap the read cursor and replay stale PCM as stutter. Voice timing
    ; above already advanced, so state stays coherent; the pump below
    ; drains whatever the FIFO accepts. 742 = biggest legal fill
    ; (max clamp 44500/60 + carry).
    cmp ax, COVOX_RING_SIZE - 742
    ja .pump
    ; --- sample render loop ---
    movzx ecx, word [s_nsamp]
    test ecx, ecx
    jz .off
.samp:
    push ecx                      ; sample counter (ECX is scratch below)
    xor edx, edx                  ; mix sum, signed (EDX survives the voices)
    xor ebx, ebx                  ; voice index
.v:
    imul eax, ebx, CS_SIZE       ; voice state stride is CS_SIZE (32), NOT the
                                ; NR-register stride 5 used at .chLoop — the
                                ; ×5 form here read voices 1-3 from the ring
                                ; (regression 2026-09-18: noise clocks came
                                ; from ring bytes ≈ 33k/sample ≈ 31M
                                ; cycles/tick, plus garbled mixing)
    lea edi, [covox_state + eax]
    mov al, [edi + CS_AMP]
    test al, al
    jz .vnext                     ; muted voice contributes nothing
    cmp ebx, 2
    je .vwave
    cmp ebx, 3
    je .vnoise
    ; square ch0/1: high while phase < duty threshold (phase resets to 0 at
    ; key-on, so the wave starts high like the GB)
    movsx esi, byte [edi + CS_AMP]
    mov eax, [edi + CS_PHASE]
    add eax, [edi + CS_STEP]
    mov [edi + CS_PHASE], eax
    lea ecx, [ebx*4 + ebx]
    mov cl, [ebp + ecx + 0xFF11]  ; NRx1 duty bits (last use of ECX as index)
    shr cl, 6
    movzx ecx, cl
    mov ecx, [CovoxDutyThresh + ecx*4]
    cmp eax, ecx
    jae .sqLo
    add edx, esi
    jmp .vnext
.sqLo:
    sub edx, esi
    jmp .vnext
.vwave:
    ; wave ch2: top 5 phase bits index the 32-nibble table verbatim
    mov eax, [edi + CS_PHASE]
    add eax, [edi + CS_STEP]
    mov [edi + CS_PHASE], eax
    shr eax, 27                   ; nibble index 0..31 (kept for the odd test)
    mov esi, eax
    shr esi, 1                    ; byte index 0..15
    mov cl, [ebp + esi + _AUD3WAVERAM]
    movzx ecx, cl
    test eax, 1
    jnz .wLo
    shr ecx, 4                    ; even index: high nibble
    jmp .wLvl
.wLo:
    and ecx, 15                   ; odd index: low nibble
.wLvl:
    sub ecx, 8                    ; -8..+7, centered like the DAC mid level
    cmp byte [edi + CS_LVL], 1
    je .wAdd                      ; half: x1
    jb .wFull                     ; full: x2
    sar ecx, 1                    ; quarter: /2 (arithmetic, sign survives)
    jmp .wAdd
.wFull:
    add ecx, ecx
.wAdd:
    add edx, ecx
    jmp .vnext
.vnoise:
    ; noise ch3: accumulate fractional LFSR clocks, step the LFSR, emit bit 0
    ; (polarity is fixed-but-arbitrary; noise has no phase to preserve)
    mov eax, [edi + CS_NACC]
    add eax, [edi + CS_STEP]      ; CS_STEP holds clocks-per-sample here
    mov ecx, eax
    shr ecx, 16                   ; whole clocks this sample
    and eax, 0xFFFF
    mov [edi + CS_NACC], eax
    movzx eax, word [edi + CS_LFSR]
    test ecx, ecx
    jz .nOut
    test byte [edi + CS_FREQ], 8  ; NR43 bit 3: 7-bit mode
    jnz .n7
.n15:
    mov esi, eax
    shr esi, 1
    xor esi, eax                  ; parity = bit0 ^ bit1
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
    and esi, 1                    ; ESI = parity
    shr eax, 1
    shl esi, 14
    or eax, esi                   ; 15-bit tap
    shr esi, 8                    ; parity<<14 >> 8 = parity<<6: 7-bit tap
    or eax, esi
    loop .n7
.nStore:
    mov [edi + CS_LFSR], ax
.nOut:
    and eax, 1
    jz .nLo
    movsx esi, byte [edi + CS_AMP]
    add edx, esi
    jmp .vnext
.nLo:
    movsx esi, byte [edi + CS_AMP]
    sub edx, esi
.vnext:
    inc ebx
    cmp ebx, 4
    jb .v
    ; master scale and center: out = 128 + sum*master/8 (an all-muted tick
    ; mixes exactly 0 and emits exactly 128)
    mov eax, edx
    movzx ecx, byte [s_master]
    imul eax, ecx
    sar eax, 3
    add eax, 128
    movzx ecx, word [s_wr]
    and ecx, COVOX_RING_MASK
    mov [covox_ring + ecx], al
    inc word [s_wr]               ; inc preserves CF; no live flags here
    pop ecx
    dec ecx                       ; samples left (32-bit: max parcels in the
    jnz .samp                     ; hundreds, zero-guarded at entry — no wrap)
.pump:
    call covox_pump               ; drain this tick's render to the DAC
.off:
    ret

; ---------------------------------------------------------------------------
; covox_pump — drain one tick's samples from the ring to COVOX_DATA.
; Called at the end of covox_pass (DelayFrame is pushad-wrapped, registers
; may be clobbered freely); exported so stage 2 can call it directly if the
; tick wiring ever splits fill from drain. Port I/O only, no mixing here.
;
; Count comes from the live g_covox_rate (rate/60 with its own Bresenham
; carry s_pcarry, the same math as the fill side, so fill and drain stay in
; lockstep and the ring never drifts in steady state). The pump sends in
; guide-shaped flow: poll first; while the FIFO reports room, consume one
; sample and strobe it out; on the FIRST full/timeout reading, stop for the
; tick (sticky) — remaining samples stay ring-buffered for a later tick
; instead of spinning 64 polls per sample (measured 2026-09-18: the old
; spin-then-write-anyway cost ~7,500 port accesses per tick and wrote into
; a full FIFO whose bytes the hardware drops — paid for and unheard).
; Worst case per tick is now one 64-poll timeout plus ~4 accesses per
; delivered sample (~470 DSS / ~120 raw at 7 kHz); a wedged/absent port
; costs exactly one timeout per tick. Every byte is strobed (guide §3/§6):
; DATA, then CONTROL=PR_STROBE, then CONTROL=PR_POWER_UP — the pin-17
; rising edge clocks it into the FIFO. Raw Covox ignores the control port
; (data latches on the DATA OUT), so the strobe pair is harmless there
; and mandatory on DSS. Added 2026-09-18: without it the DSS FIFO never
; clocks out and audio arrives slow/muffled/gapped.
;
; An empty ring (or a shortfall after a config change) emits mid-level 128,
; so an underrun is silence rather than a stuck DC level. g_covox_on = 0 or
; a degenerate rate (< 16 Hz) emits nothing; parking a live DAC at mid-level
; on teardown is covox_silence's job, not the pump's. Preserves all registers.
; ---------------------------------------------------------------------------
covox_pump:
    pushad
    cmp byte [g_covox_on], 0
    jz .done
    movzx ecx, word [g_covox_rate]
    test ecx, ecx
    jz .done                       ; unconfigured rate: nothing to pace with
    cmp ecx, 16
    jb .done                       ; degenerate rate: no output, never a fault
    ; samples due this tick: quot = rate/60 plus Bresenham carry
    mov eax, ecx
    xor edx, edx
    mov ebx, 60
    div ebx
    add dx, [s_pcarry]
    cmp dx, 60
    jb .noCarry
    sub dx, 60
    inc eax
.noCarry:
    mov [s_pcarry], dx
    mov ecx, eax                  ; ECX = samples remaining this burst
    test ecx, ecx
    jz .done                      ; sub-60 Hz fractional tick: none due yet
.next:
    ; poll FIRST: on timeout stop for the tick (sticky) — the sample stays
    ; ring-buffered, s_rd untouched, so nothing is lost or reordered
    mov dx, COVOX_STATUS
    mov ebx, COVOX_POLLS
.poll:
    in al, dx
    test al, 0x40                 ; bit 6 low = FIFO has room
    jz .haveRoom
    dec ebx                       ; bounded: 64 -> 0, never wraps, always exits
    jnz .poll
    jmp .done                     ; full/wedged: stop, retry next tick
.haveRoom:
    movzx eax, word [s_wr]
    sub ax, [s_rd]                ; AX = available (monotonic words, ring < 32K)
    jz .silence                   ; empty: hold mid-level, leave s_rd alone
    movzx eax, word [s_rd]
    and eax, COVOX_RING_MASK
    mov al, [covox_ring + eax]
    inc word [s_rd]               ; consume only what the FIFO accepted
.silence:
    ; AL = sample (or 128 mid-level on underrun — silence, not stuck DC)
    mov dx, COVOX_DATA
    out dx, al                    ; data byte
    mov dx, COVOX_CONTROL
    mov al, PR_STROBE
    out dx, al                    ; pin 17 low...
    mov al, PR_POWER_UP
    out dx, al                    ; ...rising edge clocks it into the FIFO
    dec ecx                       ; 32-bit: bursts in the hundreds, never 0-entry
    jnz .next
.done:
    popad
    ret

; ---------------------------------------------------------------------------
; covox_play_clip — play an 8-bit unsigned mono clip on the DAC, blocking,
; interrupts off (sb_pcm_play/spk_pcm_play shape: the GB also monopolized the
; CPU with IME off for the whole cry). The PIKA_PCM_RATE blob is resampled to
; g_covox_rate inline, per play: one divide arms an 8.8 fixed-point input
; step, then each output advances it (a boot-time table was rejected — the
; rate is a boot-parsed config value, and streaming costs one div plus an add
; per sample, trivial next to the port I/O, while the Tier-1 blob stays
; untouched and no byte is ever hand-encoded here).
;
; Pacing reuses sb_pcm's PIT pacer at one output sample per step, so a raw
; dongle (which plays whatever rate the CPU sustains) hears the true rate
; while the DSS re-clocks the burst through its FIFO either way. Status polls
; are bounded exactly like the pump's: a wedged port shortens the clip, never
; hangs the game.
; In:  ESI = flat ptr to blob samples at PIKA_PCM_RATE
;      ECX = sample count (>0)
;      EBP = GB memory base (preserved, unused — no GB state is read)
; Out: EAX = samples actually played (== output count, or 0 when inactive)
; Clobbers: EAX/EBX/ECX/EDX/EDI; ESI stays on the blob base. Preserves EBP.
; ---------------------------------------------------------------------------
covox_play_clip:
    cmp byte [g_covox_on], 0
    jz .off                       ; selected-but-uninitialized: play nothing
    movzx ebx, word [g_covox_rate]
    test ebx, ebx
    jz .off
    cmp ebx, 16
    jb .off
    ; 8.8 input step = (PIKA_PCM_RATE << 8) / rate (one div per play)
    mov eax, (PIKA_PCM_RATE << 8)
    xor edx, edx
    div ebx
    mov [c_step], eax
    mov [c_len], ecx              ; input samples at PIKA_PCM_RATE
    ; output count = len * rate / PIKA_PCM_RATE (64-bit dividend: a long cry
    ; at the fastest rate exceeds 32 bits before the divide)
    mov eax, ecx
    mul ebx                       ; EDX:EAX = len * rate
    mov ecx, PIKA_PCM_RATE
    div ecx
    test eax, eax
    jz .off                       ; degenerate: no output (EAX = 0 already)
    mov edi, eax                  ; EDI = outputs remaining
    mov [c_count], eax
    ; PIT-clocks-per-output step, 24.8 fixed point, rounded (sb_pcm shape)
    mov eax, (1193182 * 256)      ; PIT input clock: hardware, not a rate
    mov ecx, ebx
    shr ecx, 1                    ; rate/2 rounding (mov/shr: flags dead here)
    xor edx, edx
    add eax, ecx
    adc edx, 0
    div ebx
    pushfd
    cli                           ; tick stands still, like the GB's freeze
    call pcm_pace_init            ; EAX = step; clobbers AX/DX/flags only
    mov dword [c_pos], 0          ; 24.8 input position (integer part = index)
.play:
    call pcm_pace                 ; clobbers EAX/EDX: position lives in memory
    mov ecx, [c_pos]
    mov eax, ecx
    shr eax, 8                    ; input index for this output
    cmp eax, [c_len]
    jae .finished                 ; rounding tail ran past the blob: stop
    mov al, [esi + eax]           ; the resampled byte
    add ecx, [c_step]
    mov [c_pos], ecx
    push eax                      ; sample (push preserves flags; IN needs AL)
    mov dx, COVOX_STATUS
    mov ebx, COVOX_POLLS
.poll:
    in al, dx
    test al, 0x40
    jz .out
    dec ebx
    jnz .poll
.out:
    mov dx, COVOX_DATA
    pop eax                       ; sample back to AL (pop preserves flags)
    out dx, al                    ; data byte
    mov dx, COVOX_CONTROL
    mov al, PR_STROBE
    out dx, al                    ; pin 17 low...
    mov al, PR_POWER_UP
    out dx, al                    ; ...rising edge clocks it into the FIFO
    dec edi
    jnz .play
.finished:
    popfd
    mov eax, [c_count]
    sub eax, edi                  ; samples played
    ret
.off:
    xor eax, eax
    ret

; ---------------------------------------------------------------------------
; covox_keyon — retrigger channel EBX from its APU registers (the same latch
; sequence as innova_shim's keyon: envelope, length, sweep, frequency).
; Squares restart their phase at 0 (wave starts high); noise reseeds its
; LFSR to all-ones (an all-zero LFSR would lock and emit DC).
; ---------------------------------------------------------------------------
covox_keyon:
    ; envelope from NRx2 (the wave channel has none — NR32 is a live level)
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
    ; length from NRx1 (+ NRx4 bit 6 enable, still intact in the APU)
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
    ; sweep latch (pulse 1 only)
    test ebx, ebx
    jnz .noSweep
    mov al, [ebp + rAUD1SWEEP]
    mov [edi + CS_SWEEP], al
    mov word [edi + CS_SWACC], 0
.noSweep:
    cmp ebx, 3
    je .noiseInit
    ; frequency snapshot, phase restart
    mov cl, [ebp + esi + 3]
    mov ch, [ebp + esi + 4]
    and ch, 7
    mov [edi + CS_FREQ], cx
    mov dword [edi + CS_PHASE], 0
    jmp .keyed
.noiseInit:
    mov al, [ebp + esi + 3]       ; NR43 snapshot
    mov [edi + CS_FREQ], al
    mov word [edi + CS_LFSR], 0x7FFF
    mov dword [edi + CS_NACC], 0
.keyed:
    mov byte [edi + CS_KEY], 1
    mov byte [edi + CS_AMP], 0    ; covox_setup latches the level below
    ret

; covox_keyoff — length/sweep expiry: drop KEY and cut the amplitude. The
; envelope payload stays for the next keyon (which re-latches it).
covox_keyoff:
    mov byte [edi + CS_KEY], 0
    mov byte [edi + CS_AMP], 0
    ret

; ---------------------------------------------------------------------------
; covox_sweep — pulse-1 hardware sweep emulation (128 Hz base clock).
; Same math as innova_shim's sweep; the step is re-derived in covox_setup,
; so this only moves CS_FREQ (overflow silences the channel, GB rule).
; ---------------------------------------------------------------------------
covox_sweep:
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
    jmp covox_keyoff                ; overflow silences the channel (GB rule)
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
; covox_envelope — GB volume envelope: one step per (period / 64) s. The
; level rides the output amplitude directly each tick (sustain-riding: the
; gate is held and attack/decay/release are 0, so this IS the amplitude —
; hitting 0 plays silence, exactly like a GB channel at vol 0).
; ---------------------------------------------------------------------------
covox_envelope:
    cmp ebx, 2
    je .done                      ; wave channel has no envelope
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
; covox_length — GB length counter: 256 Hz countdown, key-off at zero.
; ---------------------------------------------------------------------------
covox_length:
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
    ; expired
    mov word [edi + CS_LEN], 0
    mov byte [edi + CS_LENEN], 0
    mov [edi + CS_LENACC], ax
    jmp covox_keyoff
.save:
    mov [edi + CS_LEN], cx
    mov [edi + CS_LENACC], ax
.done:
    ret

; ---------------------------------------------------------------------------
; covox_setup — latch the per-tick render parameters for a sounding voice:
; the 16.16 phase step (squares/wave) or LFSR clocks-per-sample (noise) plus
; the signed amplitude. A channel with both NR51 bits clear is force-muted
; (rests/ducks); MIDI mode voices a channel only while an SFX owns it
; (tandy_shim's guard shape, for stage 2.3: the MT-32/GM stream carries the
; music, so the DAC must not double it).
; Clobbers EAX ECX EDX.
; ---------------------------------------------------------------------------
covox_setup:
    mov cl, bl
    mov ch, 0x11
    shl ch, cl                    ; NR51 terminal pair mask for this channel
    test [s_nr51], ch             ; ZF set below iff both bits clear
    jz .mute
    cmp ebx, 2
    je .wave
    cmp ebx, 3
    je .noise
    ; square ch0/1: step = s_k16 / (2048 - f), amplitude = envelope level
    movzx eax, word [edi + CS_FREQ]
    and eax, 0x7FF                ; divisor in 1..2048, never 0
    mov ecx, 2048
    sub ecx, eax
    mov eax, [s_k16]
    xor edx, edx
    div ecx
    mov [edi + CS_STEP], eax
    mov al, [edi + CS_ENVVOL]
    mov [edi + CS_AMP], al
    jmp .midi
.wave:
    mov al, [ebp + rAUD3ENA]
    test al, 0x80                 ; wave DAC off -> silent
    jz .mute
    movzx eax, byte [ebp + rAUD3LEVEL]
    shr eax, 5
    and eax, 3
    jz .mute                      ; NR32 level 0 -> silent
    dec eax                       ; 1..3 -> 0..2 (full/half/quarter)
    mov [edi + CS_LVL], al
    movzx eax, word [edi + CS_FREQ]
    and eax, 0x7FF
    mov ecx, 2048
    sub ecx, eax
    mov eax, [s_k16]
    xor edx, edx
    div ecx
    mov [edi + CS_STEP], eax
    mov byte [edi + CS_AMP], 1    ; audible marker (level rides CS_LVL)
    jmp .midi
.noise:
    ; clocks-per-sample = s_kn / nr43divisor (innova_noise_freq's divisor:
    ; r = 0 folds to 1 << s, else r << (s+1), always nonzero)
    mov al, [edi + CS_FREQ]       ; latched NR43
    movzx ecx, al
    shr ecx, 4                    ; ECX = s (0-15)
    and eax, 7                    ; EAX = r
    jnz .haveR
    mov eax, 1
    shl eax, cl
    jmp .haveDiv
.haveR:
    inc ecx                       ; s+1
    shl eax, cl                   ; divisor r << (s+1)
.haveDiv:
    mov ecx, eax
    mov eax, [s_kn]
    xor edx, edx
    div ecx
    mov [edi + CS_STEP], eax
    mov al, [edi + CS_ENVVOL]
    mov [edi + CS_AMP], al
.midi:
    ; MIDI mode: the MT-32/GM stream carries the music, so a GB channel
    ; only renders while an SFX owns it (wChannelSoundIDs CHAN5-8)
    cmp byte [g_midi_music], 0
    jz .done
    cmp byte [ebp + wChannelSoundIDs + CHAN5 + ebx], 0
    jnz .done
.mute:
    mov byte [edi + CS_AMP], 0
.done:
    ret

; ---------------------------------------------------------------------------
; covox_dbg_snapshot — copy shim state into GB scratch (mpu401's
; midi_dbg_snapshot shape: mov al/mov [ebp+...] stores, EAX only).
; Provisional 8-byte block at COVOX_SNAP (+0x81..+0x88; see header):
;   +0x81 g_covox_on  +0x82/83 s_wr (monotonic: proves the render advanced)
;   +0x84 s_master    +0x85/86 packed ch0/1 amps +0x87/88 packed ch2/3 amps
; Packed voice byte: hi nibble = latched amplitude 0-15, bit 0 = KEY flag.
; In: EBP = GB memory base. Clobbers EAX.
; ---------------------------------------------------------------------------
covox_dbg_snapshot:
    mov al, [g_covox_on]
    mov [ebp + (COVOX_SNAP + 0)], al
    mov ax, [s_wr]
    mov [ebp + (COVOX_SNAP + 1)], al
    mov [ebp + (COVOX_SNAP + 2)], ah
    mov al, [s_master]
    mov [ebp + (COVOX_SNAP + 3)], al
    mov al, [covox_state + 0*CS_SIZE + CS_AMP]
    shl al, 4
    or al, [covox_state + 0*CS_SIZE + CS_KEY]
    mov [ebp + (COVOX_SNAP + 4)], al
    mov al, [covox_state + 1*CS_SIZE + CS_AMP]
    shl al, 4
    or al, [covox_state + 1*CS_SIZE + CS_KEY]
    mov [ebp + (COVOX_SNAP + 5)], al
    mov al, [covox_state + 2*CS_SIZE + CS_AMP]
    shl al, 4
    or al, [covox_state + 2*CS_SIZE + CS_KEY]
    mov [ebp + (COVOX_SNAP + 6)], al
    mov al, [covox_state + 3*CS_SIZE + CS_AMP]
    shl al, 4
    or al, [covox_state + 3*CS_SIZE + CS_KEY]
    mov [ebp + (COVOX_SNAP + 7)], al
    ret

section .data

g_covox_on:     db 0              ; /COVOX selected + covox_init ran

; GB duty 0-3 -> full-circle 32-bit phase threshold (12.5/25/50/75% of 2^32).
; Identity map from the duty definition, not game data: too small for a
; generator (the InnovaDutyPW inline precedent).
CovoxDutyThresh: dd 0x20000000, 0x40000000, 0x80000000, 0xC0000000

section .bss

covox_state:    resb 4 * CS_SIZE   ; ch0-3 voices (ch3 LFSR/nacc live in-slot)
covox_ring:     resb COVOX_RING_SIZE ; rendered PCM (covox_pump drains it)
s_master:       resb 1              ; latched NR50 louder side 0-7
s_nr51:         resb 1              ; NR51 snapshot for this tick
s_k16:          resd 1              ; 2^33/rate: square/wave step numerator
s_kn:           resd 1              ; 2^34/rate: noise clocks numerator
s_nsamp:        resw 1              ; samples to render this tick
s_carry:        resw 1              ; samples-per-tick fractional carry
s_wr:           resw 1              ; ring write cursor (monotonic)
s_rd:           resw 1              ; ring read cursor (the pump drains toward s_wr)
s_pcarry:       resw 1              ; pump samples-per-tick fractional carry
c_step:         resd 1              ; cry resample step, 8.8 input samples/output
c_len:          resd 1              ; cry input length (blob samples)
c_count:        resd 1              ; cry outputs requested (for the played tally)
c_pos:          resd 1              ; cry resample position, 24.8 fixed point

%else

section .text
covox_play_clip:
    xor eax, eax                  ; played tally reads 0 (sb_pcm/spk_pcm shape)
    ret
covox_init:
covox_pass:
covox_pump:
covox_silence:
covox_shutdown:
covox_dbg_snapshot:
    ret

section .data
g_covox_on:     db 0

%endif
