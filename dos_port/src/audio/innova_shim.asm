; innova_shim.asm — virtual APU → Innovation SSI-2001 (MOS 6581 SID) device shim (port-only HAL layer).
;
; Port-only module (no pret counterpart; this file has no GB original and is
; owned by the DOS audio HAL, wired in stage 2 from audio_tick/audio_init).
;
; The SSI-2001 is a 6581 on an 8-bit ISA card (default base 0x280, card clock
; 14.31818/16 MHz). Once per audio tick innova_pass reads the GB channels from
; the virtual APU block at [ebp+$FF10..$FF26] and mirrors them onto the SID:
;
;   GB ch0 pulse1  -> V1 pulse     GB duty 0-3 -> 12-bit PW 512/1024/2048/3072
;   GB ch1 pulse2  -> V2 pulse     (same duty mapping)
;   GB ch2 wave    -> V3 triangle  at pitch, NR32 level as sustain
;   GB ch3 noise   -> V3-steal     (stage 1b: save $0E-$14, noise, restore)
;
; Stage 3 SFX audit (31 profiles in tools/audio/sfx/*.yaml vs the engine
; headers audio/headers/sfxheaders*.asm: every yaml channel set equals every
; bank variant's set, so the yaml ch8 flag IS the engine answer):
;   noise-driven (16, ch8 present, V3-steal path on live NR42/NR43, no id key):
;     Ball_Poof 5+8, Damage 8, Doubleslap 8, Faint_Thud 5+8, Go_Inside 8,
;     Go_Outside 8, Horn_Drill 8, Not_Very_Effective 8, Peck 8, Pound 8,
;     Psybeam 5+6+8, Psychic_M 5+6+8, Run 8, Start_Menu 8, Super_Effective 8,
;     Vine_Whip 8
;   pitched-only (15, default pulse/triangle mapping, no id key):
;     Ball_Toss 5+6, Caught_Mon 5+6+7 (sole ch7 wave voice), Collision 5,
;     Denied 5+6, Enter_PC 5, Faint_Fall 5, Ledge 5, Press_AB 5,
;     Purchase 5+6, Save 5+6, Swap 5+6, Tink 5, Turn_Off_PC 5, Turn_On_PC 5,
;     Withdraw_Deposit 5
; No per-id table ships: pitched voices read duty/NR32/envelope live and the
; steal path latches the live NR42/NR43 payload, so per-SFX differences already
; in the engine data (e.g. Pound's noise_note args) arrive with no lookup. The
; yaml volume/patch columns (85-110, whoosh/thud/crunch/click/poof) tune the
; OPL mixer only. SFX ids repeat across audio banks (0xB6 is Save and
; Horn_Drill, 0xAB Withdraw_Deposit and Vine_Whip), so an id-keyed table with
; no bank key would misroute. Zero rows needs no generator (the InnovaDutyPW
; inline precedent applies twice over). Ear-check cover (stage 3.3, in-DOS):
; Press_AB (pulse, already in RunAudioTest), Caught_Mon (wave), Pound,
; Go_Outside, Start_Menu (steal: thud/whoosh/click), Faint_Thud, Psybeam
; (mixed), Super_Effective, Psychic_M (battle noise-heavy).
;
; Like tandy_shim, the engine's NRx4 restart bit is CONSUMED here, and what
; the SID lacks is emulated in software per tick, in GB units: envelope
; (NRx2, ridden as the sustain level with gate held on and A/D/R 0), sweep
; (NR10, pulse1), length (NRx1/NRx4 bit 6), master volume (NR50 louder side
; into the $18 volume nibble), and NR51 muting (both terminal bits clear ->
; gate off). Filter is OFF in v1 ($18 upper nibble 0, no routing).
;
; The SID is write-only ($00-$18; POT/OSC3/ENV3 have no shim use and $19-$1C
; are never touched). There is no probe: the shim activates only via the /INNOVA
; command-line flag (stage 2: audio_init sets the device and calls innova_init);
; with g_innova_on = 0 every entry point no-ops.
;
; Frequency: GB Fout = 131072/(2048-f) Hz; card Fn = Fout x 18.7478755
; (see innova_setfreq for the exact integer form). Single-waveform control
; bytes only (pulse 0x40 / triangle 0x10, plus GATE): combining noise with
; anything wedges real silicon until a TEST pulse, so noise travels the
; stage-1b steal path, never a combined byte. Bring-up order per note:
; params (Fn, PW, S) first, CONTROL gate last.

%include "gb_memmap.inc"

global innova_init
global innova_pass
global innova_silence
global innova_shutdown
global innova_dbg_snapshot
global g_innova_on

%ifndef ENABLE_AUDIO_INNOVA
%define ENABLE_AUDIO_INNOVA 1
%endif

%if ENABLE_AUDIO_INNOVA != 0

extern g_midi_music               ; src/audio/mpu401.asm — MIDI mode active

section .text

INNOVA_BASE equ 0x280             ; default SSI-2001 base (jumpers: 2A0/2C0/2E0)
; Card clock 14.31818 MHz / 16 = 894886.25 Hz. Fn = Fout x 16777216/Fclk
; = Fout x 18.7478755 (Fclk truncation to the integer below moves Fn by
; far less than one LSB; the .25 is carried in the numerator instead).
INNOVA_CLOCK equ 894886           ; ISA card O2 in Hz (documentary; math uses the numerator)
INNOVA_GBFN_NUM equ 2457322      ; round(131072 x 18.7478755), see innova_setfreq

INNOVA_VSTRIDE equ 7              ; voice register stride ($00/V1, $07/V2, $0E/V3)

; Temporary debug toggles for isolating channels and Voice 3 switching:
%define DEBUG_DISABLE_NOISE 0     ; 1 = disable GB Ch3 (noise) & Voice 3 switching
%define DEBUG_DISABLE_WAVE  0     ; 1 = disable GB Ch2 (wave)
INNOVA_R_FREQLO equ 0
INNOVA_R_FREQHI equ 1
INNOVA_R_PWLO equ 2
INNOVA_R_PWHI equ 3
INNOVA_R_CTL equ 4
INNOVA_R_AD equ 5                 ; attack/decay: stays at its silenced 0
INNOVA_R_SR equ 6                 ; sustain/release: sustain rides GB envvol, R = 0
INNOVA_R_FCLO equ 0x15            ; filter cutoff low (bits 2-0)
INNOVA_R_FCHI equ 0x16            ; filter cutoff high (bits 7-0)
INNOVA_R_RESVOI equ 0x17          ; resonance (bits 7-4) + voice filter enable (bits 3-0)
INNOVA_R_MODEVOL equ 0x18         ; filter mode (bit 4: LP) + master volume nibble

INNOVA_FILTER_LP equ 0x10         ; low-pass filter enable bit in $18
INNOVA_FILTER_VOICES equ 0x07     ; voices 1, 2, 3 routed through filter
INNOVA_FILTER_CUTOFF equ 0xC8     ; cutoff high byte (~3.5-5 kHz, Planet X3 reference)

INNOVA_CTL_PULSE equ 0x40         ; single waveform bits (never combined, never noise)
INNOVA_CTL_TRI equ 0x10
INNOVA_CTL_NOISE equ 0x80        ; noise: only ever NOISE+GATE, via the V3-steal path
INNOVA_CTL_TEST equ 0x08         ; TEST: locks the osc at zero, resets the noise LFSR
INNOVA_GATE equ 0x01
INNOVA_NOISE_NUM equ 4914643     ; round(262144 x 18.7478755), see innova_noise_freq

; --- per-voice software state (offsets 0-15 mirror tandy_shim's TS_*) -----
SS_FREQ       equ 0    ; word: GB 11-bit freq incl. sweep
SS_KEY        equ 2    ; byte: key-on flag
SS_ENVVOL     equ 3    ; byte: current GB volume 0-15 (ridden as sustain)
SS_ENVDIR     equ 4    ; byte: envelope direction (1 = up)
SS_ENVPER     equ 5    ; byte: envelope period (0 = off)
SS_ENVACC     equ 6    ; word: envelope accumulator (64/tick vs 60*period)
SS_LEN        equ 8    ; word: length counter (1/256 s units)
SS_LENACC     equ 10   ; word: length accumulator (256/tick vs 60)
SS_LENEN      equ 12   ; byte: length enable (NRx4 bit 6)
SS_SWEEP      equ 13   ; byte: NR10 latched at key-on (ch0 only)
SS_SWACC      equ 14   ; word: sweep accumulator (128/tick vs 60*period)
SS_LASTCTL    equ 16   ; byte: last CONTROL written (0xFF = force)
SS_LASTSUS    equ 17   ; byte: last $06 sustain byte written (0xFF = force)
SS_LASTFN     equ 18   ; word: last Fn written (0xFFFF = force)
SS_LASTPW     equ 20   ; word: last 12-bit PW written (0xFFFF = force)
SS_SIZE       equ 22

; ===========================================================================
; innova_write — write AL to INNOVA_BASE+AH. Blind OUTs: the ISA card needs no
; pacing (Tacc 300 ns). In: AH = SID register offset ($00-$18), AL = data.
; Preserves all registers and flags (movzx/lea/out/push/pop touch neither).
; ===========================================================================
innova_write:
    push edx
    movzx edx, ah
    lea edx, [edx + INNOVA_BASE]
    out dx, al
    pop edx
    ret

; ===========================================================================
; innova_filter_init — configure the MOS 6581 analog low-pass filter across
; all three voices (matching Planet X3 reference setup: Cutoff $C8, voices
; 1-3 enabled in $17, mode low-pass). Clobbers nothing (innova_write preserves
; all registers and flags).
; ===========================================================================
innova_filter_init:
    push eax
    mov ah, INNOVA_R_FCLO
    xor al, al
    call innova_write
    mov ah, INNOVA_R_FCHI
    mov al, INNOVA_FILTER_CUTOFF
    call innova_write
    mov ah, INNOVA_R_RESVOI
    mov al, INNOVA_FILTER_VOICES
    call innova_write
    pop eax
    ret

; ===========================================================================
; innova_init — reset software state, silence the card, mark the shim active.
; Stage-2 audio_init calls this only when /INNOVA selected the device.
; Preserves all registers.
; ===========================================================================
innova_init:
    pushad
    mov byte [g_innova_on], 1
    mov ecx, 3 * SS_SIZE
    mov edi, innova_state
.clr:
    mov byte [edi], 0
    inc edi
    loop .clr
    mov edi, innova_state
    mov ecx, 3
.vinit:
    mov byte [edi + SS_LASTCTL], 0xFF
    mov byte [edi + SS_LASTSUS], 0xFF
    mov word [edi + SS_LASTFN], 0xFFFF
    mov word [edi + SS_LASTPW], 0xFFFF
    add edi, SS_SIZE
    loop .vinit
    mov byte [s_lastmode], 0xFF
    call innova_silence
    call innova_filter_init
    popad
    ret

; ===========================================================================
; innova_silence — leave the card silent (zero $00-$18). Exported for
; PlayPikachuSoundClip like tandy_silence: software envelopes freeze during
; the cli PCM clip, so held notes must be cut; voices re-key on their next
; note-on. Safe with the shim inactive (bare OUTs to an absent port).
; ===========================================================================
innova_silence:
    cmp byte [g_innova_on], 0
    jz .off
    push eax
    push ecx
    push edi
    ; a steal in flight restores first (V3 image + TEST pulse); the zero run
    ; below then cuts everything
    cmp byte [s_noise_on], 0
    jz .zero
    call innova_noise_restore
.zero:
    ; zero $00-$18: params already zeroed, $18 last is irrelevant when all
    ; zero — one straight run (innova_write preserves regs and flags, loop
    ; reads neither)
    xor eax, eax                  ; AH = reg 0, AL = 0
    mov ecx, 25
.reg:
    call innova_write
    inc ah                        ; next register
    loop .reg
    ; set fast AD on all 3 voices (0x00: Attack 2ms, Decay 6ms)
    mov ah, 0x05
    xor al, al
    call innova_write
    mov ah, 0x0C
    xor al, al
    call innova_write
    mov ah, 0x13
    xor al, al
    call innova_write
    ; caches read back as the silenced values, so the next tick re-emits only
    ; on change (KEY flags stay, like tandy_silence: voices resume on their
    ; next tick and re-key fully on their next restart)
    lea edi, [innova_state]
    mov ecx, 3
.cache:
    mov byte [edi + SS_LASTCTL], 0
    mov byte [edi + SS_LASTSUS], 0
    mov word [edi + SS_LASTFN], 0
    mov word [edi + SS_LASTPW], 0
    add edi, SS_SIZE
    loop .cache
    mov byte [s_lastmode], 0
    mov byte [s_noise_is_sfx], 0
    call innova_filter_init
    pop edi
    pop ecx
    pop eax
.off:
    ret

; innova_shutdown — leave the card silent on exit. Tail-jump (tandy_shutdown
; shape); silence's own save/restore keeps every register. Preserves all.
innova_shutdown:
    jmp innova_silence

; ===========================================================================
; innova_pass — the per-tick APU mirror. Stage-2 audio_tick calls this (DelayFrame
; is pushad-wrapped, registers may be clobbered freely).
;   EBX = GB channel (0-2; ch3 noise is consumed into the stage-1b hook)
;   ESI = GB address of the channel's register file ($FF10 + ch*5)
;   EDI = its software voice state
; ===========================================================================
innova_pass:
    cmp byte [g_innova_on], 0
    jz .off
    ; master volume from NR50 (the louder terminal, like tandy_shim, so
    ; FadeOutAudio's simultaneous L/R ramp maps to a single volume ramp):
    ; 3-bit side 0-7 << 1 -> even nibble 0-14.
    ; Bit 4 = INNOVA_FILTER_LP: analog Low-Pass filter kept enabled across all
    ; volume levels (Planet X3 reference).
    mov al, [ebp + rAUDVOL]
    mov ah, al
    shr ah, 4
    and ah, 7
    and al, 7
    cmp al, ah
    jae .m1
    mov al, ah
.m1:
    shl al, 1
    cmp al, [s_lastmode]
    je .m2
    mov [s_lastmode], al
    or al, INNOVA_FILTER_LP
    mov ch, al
    mov ah, INNOVA_R_MODEVOL
    mov al, ch
    call innova_write
.m2:
    mov al, [ebp + rAUDTERM]
    mov [s_nr51_snap], al

    xor ebx, ebx
.chLoop:
%if DEBUG_DISABLE_WAVE
    cmp ebx, 2
    je .next
%endif
    lea esi, [ebx*4 + ebx]
    add esi, 0xFF10             ; channel register base
    imul eax, ebx, SS_SIZE      ; ch * SS_SIZE
    lea edi, [innova_state + eax]

    cmp ebx, 2
    jne .normalCh
    cmp byte [s_noise_on], 0
    jnz .waveStolen
    cmp byte [ebp + wChannelSoundIDs + CHAN8], 0
    jnz .waveStolen
    test byte [ebp + rAUD4GO], 0x80
    jnz .waveStolen
    jmp .normalCh

.waveStolen:
    ; Voice 3 stolen by noise (or about to be stolen on this frame):
    ; update Wave software state only, no HW writes
    mov al, [ebp + esi + 4]     ; NR34
    test al, 0x80
    jz .waveNoRestart
    and al, 0x7F                ; consume restart bit
    mov [ebp + esi + 4], al
    mov al, [ebp + esi + 1]     ; NR31 length
    movzx eax, al
    neg eax
    add eax, 256
    mov [edi + SS_LEN], ax
    mov word [edi + SS_LENACC], 0
    mov al, [ebp + esi + 4]
    and al, 0x40
    mov [edi + SS_LENEN], al
    mov cl, [ebp + esi + 3]
    mov ch, [ebp + esi + 4]
    and ch, 7
    mov [edi + SS_FREQ], cx
    mov byte [edi + SS_KEY], 1
    jmp .waveRunning
.waveNoRestart:
    cmp byte [edi + SS_KEY], 0
    jz .next
    mov cl, [ebp + esi + 3]
    mov ch, [ebp + esi + 4]
    and ch, 7
    mov [edi + SS_FREQ], cx
.waveRunning:
    call innova_length_sw
    jmp .next

.normalCh:
    mov al, [ebp + esi + 4]     ; NRx4
    test al, 0x80
    jz .noRestart
    and al, 0x7F                ; consume the restart bit
    mov [ebp + esi + 4], al
    call innova_keyon
    jmp .running
.noRestart:
    cmp byte [edi + SS_KEY], 0
    jz .next
    ; frequency follow (engine vibrato / pitch slides)
    mov cl, [ebp + esi + 3]
    mov ch, [ebp + esi + 4]
    and ch, 7
    cmp cx, [edi + SS_FREQ]
    je .running
    mov [edi + SS_FREQ], cx
    call innova_setfreq
.running:
    cmp byte [edi + SS_KEY], 0
    jz .next
    call innova_sweep
    call innova_envelope
    call innova_length
    call innova_pulsew
    call innova_volume
.next:
    inc ebx
    cmp ebx, 3
    jb .chLoop
    ; ch3 (noise) restart is consumed here so the bit never lingers; without
    ; one a stolen voice in flight still needs its per-tick service, so the
    ; fall-through ticks it instead (innova_noise_tick no-ops unless stealing)
    mov al, [ebp + rAUD4GO]
    test al, 0x80
    jz .noiseTick
    and al, 0x7F
    mov [ebp + rAUD4GO], al
%if DEBUG_DISABLE_NOISE == 0
    call innova_noise_keyon
    jmp .off
.noiseTick:
    call innova_noise_tick
%else
.noiseTick:
%endif
.off:
    ret

; ---------------------------------------------------------------------------
; innova_keyon — retrigger channel EBX from its APU registers (the same latch
; sequence as tandy_shim's keyon: envelope, length, sweep, frequency).
; Cuts the stale voice first, programs params, gates last (bring-up order).
; ---------------------------------------------------------------------------
innova_keyon:
    ; envelope from NRx2 (the wave channel has none — NR32 is a live level)
    cmp ebx, 2
    je .noEnv
    mov al, [ebp + esi + 2]
    mov ah, al
    shr ah, 4
    mov [edi + SS_ENVVOL], ah
    mov ah, al
    shr ah, 3
    and ah, 1
    mov [edi + SS_ENVDIR], ah
    and al, 7
    mov [edi + SS_ENVPER], al
    mov word [edi + SS_ENVACC], 0
.noEnv:
    ; length from NRx1 (+ NRx4 bit 6 enable, still intact in the APU)
    mov al, [ebp + esi + 1]
    cmp ebx, 2
    jz .len8
    and eax, 0x3F
    neg eax
    add eax, 64
    jmp .lenSet
.len8:
    movzx eax, al
    neg eax
    add eax, 256
.lenSet:
    mov [edi + SS_LEN], ax
    mov word [edi + SS_LENACC], 0
    mov al, [ebp + esi + 4]
    and al, 0x40
    mov [edi + SS_LENEN], al
    ; sweep latch (pulse 1 only)
    test ebx, ebx
    jnz .noSweep
    mov al, [ebp + rAUD1SWEEP]
    mov [edi + SS_SWEEP], al
    mov word [edi + SS_SWACC], 0
.noSweep:
    ; frequency snapshot
    mov cl, [ebp + esi + 3]
    mov ch, [ebp + esi + 4]
    and ch, 7
    mov [edi + SS_FREQ], cx
    mov byte [edi + SS_KEY], 1
    ; force every cached SID byte so the retrigger re-emits (gate included)
    mov byte [edi + SS_LASTCTL], 0xFF
    mov byte [edi + SS_LASTSUS], 0xFF
    mov word [edi + SS_LASTFN], 0xFFFF
    mov word [edi + SS_LASTPW], 0xFFFF
    ; params before gate: cut the stale voice, program, then ride+gate
    call innova_gateoff
    call innova_setfreq
    call innova_pulsew
    imul ecx, ebx, INNOVA_VSTRIDE
    add ecx, INNOVA_R_AD
    mov ah, cl
    xor al, al                    ; Attack 2ms, Decay 6ms (fast tracking ADSR)
    call innova_write
    jmp innova_volume

; innova_keyoff — length/sweep expiry: drop KEY and cut the gate. The sustain
; cache is left for the next keyon (which forces a rewrite).
innova_keyoff:
    mov byte [edi + SS_KEY], 0
    ; fall through

; innova_gateoff — write CONTROL without GATE for channel EBX (single waveform,
; never noise). Updates SS_LASTCTL. Clobbers EAX ECX.
innova_gateoff:
    mov al, INNOVA_CTL_PULSE
    cmp ebx, 2
    jne .w
    mov al, INNOVA_CTL_TRI
.w:
    mov [edi + SS_LASTCTL], al
    imul ecx, ebx, INNOVA_VSTRIDE
    add ecx, INNOVA_R_CTL
    mov ah, cl
    call innova_write
    ret

; ---------------------------------------------------------------------------
; innova_setfreq — program Fn for voice EBX from SS_FREQ (GB 11-bit f).
; GB: Fout = 131072/(2048-f) Hz. Card: Fn = Fout x 18.7478755, so
;   Fn = 131072 x 18.7478755 / (2048-f) = 2457321.5375... / (2048-f)
;   (131072 x 18 = 2359296; 131072 x 0.7478755 = 98025.5375; sum 2457321.5375)
; Integer form: Fn = INNOVA_GBFN_NUM (2457322) div (2048-f), f masked to 11
; bits so the divisor is in 1..2048 (never 0), then clamped to 16 bits.
; Cross-check: A4 (GB f = 1750) -> 2457322/298 = 8246 = $2036, within a few
; LSB of the printed $2039 (GB-step quantization plus rounding).
; Divisor math and the table-free clamp below are branch-free; the hi/lo
; split write is skipped when Fn is unchanged. Clobbers EAX ECX EDX.
; ---------------------------------------------------------------------------
innova_setfreq:
    movzx eax, word [edi + SS_FREQ]
    and eax, 0x7FF
    mov ecx, 2048
    sub ecx, eax
    mov eax, INNOVA_GBFN_NUM
    xor edx, edx
    div ecx                       ; EAX = Fn, truncated
    cmp eax, 0xFFFF
    sbb ecx, ecx                  ; ECX = -1 if EAX < FFFF else 0
    and eax, ecx
    not ecx
    and ecx, 0xFFFF
    or eax, ecx                   ; EAX = Fn clamped to 16 bits, no branch
    cmp ax, [edi + SS_LASTFN]
    je .done
    mov [edi + SS_LASTFN], ax
    mov edx, eax                  ; DX = Fn
    imul ecx, ebx, INNOVA_VSTRIDE    ; voice base offset
    mov ah, cl
    inc ah                        ; FREQ HI first (C64 PRG Ch. 4 order)
    mov al, dh
    call innova_write
    mov ah, cl                    ; FREQ LO second
    mov al, dl
    call innova_write
.done:
    ret

; ---------------------------------------------------------------------------
; innova_pulsew — program the 12-bit pulse width for V1/V2 from the GB duty
; bits (NRx1 bits 7-6): 12.5/25/50/75% -> PWn 512/1024/2048/3072
; (PWout = PWn/40.95%: 2048 = square). Branch-free table lookup, written
; on change (PW HI carries the low nibble only, per Table 1). No-op on
; ch2 (triangle has no width). Clobbers EAX ECX EDX.
; ---------------------------------------------------------------------------
innova_pulsew:
    cmp ebx, 2
    je .done
    mov al, [ebp + esi + 1]
    shr al, 6
    movzx eax, al
    mov ax, [InnovaDutyPW + eax*2]
    cmp ax, [edi + SS_LASTPW]
    je .done
    mov [edi + SS_LASTPW], ax
    mov edx, eax                  ; DX = PWn
    imul ecx, ebx, INNOVA_VSTRIDE
    add ecx, INNOVA_R_PWLO
    mov ah, cl                    ; PW LO
    mov al, dl
    call innova_write
    mov ah, cl
    inc ah                        ; PW HI
    mov al, dh
    and al, 0x0F
    call innova_write
.done:
    ret

; ---------------------------------------------------------------------------
; innova_sweep — pulse-1 hardware sweep emulation (128 Hz base clock).
; Same math as tandy_shim's sweep.
; ---------------------------------------------------------------------------
innova_sweep:
    test ebx, ebx
    jnz .done
    mov al, [edi + SS_SWEEP]
    mov cl, al
    shr cl, 4
    and cl, 7                     ; period
    jz .done
    movzx eax, cl
    imul eax, 60
    movzx ecx, word [edi + SS_SWACC]
    add ecx, 128
    cmp ecx, eax
    jb .store
    sub ecx, eax
    mov [edi + SS_SWACC], cx
    ; f' = f +/- (f >> n)
    movzx eax, word [edi + SS_FREQ]
    mov edx, eax
    mov cl, [edi + SS_SWEEP]
    and cl, 7
    shr eax, cl
    test byte [edi + SS_SWEEP], 8
    jnz .down
    add edx, eax
    cmp edx, 2048
    jb .apply
    jmp innova_keyoff                ; overflow silences the channel (GB rule)
.down:
    sub edx, eax
    jns .apply
    xor edx, edx
.apply:
    mov [edi + SS_FREQ], dx
    jmp innova_setfreq
.store:
    mov [edi + SS_SWACC], cx
.done:
    ret

; ---------------------------------------------------------------------------
; innova_envelope — GB volume envelope: one step per (period / 64) s. The level
; rides the SUSTAIN nibble each tick (gate stays on, A/D/R 0); hitting 0
; plays silence through an open gate, exactly like a GB channel at vol 0.
; ---------------------------------------------------------------------------
innova_envelope:
    cmp ebx, 2
    je .done                      ; wave channel has no envelope
    mov al, [edi + SS_ENVPER]
    test al, al
    jz .done
    movzx ecx, al
    imul ecx, 60
    movzx eax, word [edi + SS_ENVACC]
    add eax, 64
    cmp eax, ecx
    jb .store
    sub eax, ecx
    mov cl, [edi + SS_ENVVOL]
    cmp byte [edi + SS_ENVDIR], 0
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
    mov [edi + SS_ENVVOL], cl
.store:
    mov [edi + SS_ENVACC], ax
.done:
    ret

; ---------------------------------------------------------------------------
; innova_length — GB length counter: 256 Hz countdown, key-off at zero.
; ---------------------------------------------------------------------------
innova_length:
    cmp byte [edi + SS_LENEN], 0
    jz .done
    movzx eax, word [edi + SS_LENACC]
    add eax, 256
    movzx ecx, word [edi + SS_LEN]
.step:
    cmp eax, 60
    jb .save
    sub eax, 60
    dec ecx
    jnz .step
    ; expired
    mov word [edi + SS_LEN], 0
    mov byte [edi + SS_LENEN], 0
    mov [edi + SS_LENACC], ax
    jmp innova_keyoff
.save:
    mov [edi + SS_LEN], cx
    mov [edi + SS_LENACC], ax
.done:
    ret

; innova_length_sw — software-only length countdown for Wave during noise steal.
; Drops SS_KEY at zero without touching hardware registers.
innova_length_sw:
    cmp byte [edi + SS_LENEN], 0
    jz .done
    movzx eax, word [edi + SS_LENACC]
    add eax, 256
    movzx ecx, word [edi + SS_LEN]
.step:
    cmp eax, 60
    jb .save
    sub eax, 60
    dec ecx
    jnz .step
    mov word [edi + SS_LEN], 0
    mov byte [edi + SS_LENEN], 0
    mov [edi + SS_LENACC], ax
    mov byte [edi + SS_KEY], 0
    ret
.save:
    mov [edi + SS_LEN], cx
    mov [edi + SS_LENACC], ax
.done:
    ret

; ---------------------------------------------------------------------------
; innova_volume — sustain-riding plus gate: S nibble follows GB envvol
; (ch0/ch1) or the NR32 level (ch2); CONTROL carries the single waveform
; with GATE while sounding, without it while muted. A channel with both
; NR51 bits clear, a disabled wave DAC, or NR32 level 0 is force-muted
; (rests/ducks). $05 is never written (its silenced 0 already means A/D 0).
; Clobbers EAX ECX EDX.
; ---------------------------------------------------------------------------
innova_volume:
    mov cl, bl
    mov ch, 0x11
    shl ch, cl                    ; NR51 terminal pair mask for this channel
    test [s_nr51_snap], ch        ; ZF set below iff both bits clear
    jz .mute
    cmp ebx, 2
    je .wave
    mov al, [edi + SS_ENVVOL]
    test al, al                   ; volume 0 -> silent (cut gate)
    jz .mute
    shl al, 4                     ; $06 byte: S = envvol, R = 0
    jmp .haveSR
.wave:
    mov al, [ebp + rAUD3ENA]
    test al, 0x80                 ; wave DAC off -> silent
    jz .mute
    mov al, [ebp + rAUD3LEVEL]
    shr al, 5
    and eax, 3
    mov al, [InnovaWaveSUS + eax]
    test al, al                   ; NR32 level 0 -> silent
    jz .mute
    shl al, 4
.haveSR:
    ; MIDI mode: the MT-32/GM stream carries the music, so a GB channel
    ; only voices on the SID while an SFX owns it (wChannelSoundIDs CHAN5-8)
    cmp byte [g_midi_music], 0
    jz .voice
    cmp byte [ebp + wChannelSoundIDs + CHAN5 + ebx], 0
    jz .mute
.voice:
    cmp al, [edi + SS_LASTSUS]
    je .gate
    mov [edi + SS_LASTSUS], al
    imul ecx, ebx, INNOVA_VSTRIDE
    add ecx, INNOVA_R_SR
    mov ah, cl
    call innova_write
.gate:
    ; CONTROL = single waveform + GATE
    mov al, INNOVA_CTL_PULSE
    cmp ebx, 2
    jne .haveCtl
    mov al, INNOVA_CTL_TRI
.haveCtl:
    or al, INNOVA_GATE
    cmp al, [edi + SS_LASTCTL]
    je .done
    mov [edi + SS_LASTCTL], al
    imul ecx, ebx, INNOVA_VSTRIDE
    add ecx, INNOVA_R_CTL
    mov ah, cl
    call innova_write
.done:
    ret
.mute:
    ; cut the gate; the sustain cache stays for the next keyon (forced there)
    mov al, INNOVA_CTL_PULSE
    cmp ebx, 2
    jne .haveMute
    mov al, INNOVA_CTL_TRI
.haveMute:
    cmp al, [edi + SS_LASTCTL]
    je .done
    mov [edi + SS_LASTCTL], al
    imul ecx, ebx, INNOVA_VSTRIDE
    add ecx, INNOVA_R_CTL
    mov ah, cl
    call innova_write
    ret

; ---------------------------------------------------------------------------
; innova_noise_keyon — ch3 trigger hook: uniform V3-steal (plan 0.3.2).
; Steals Voice 3 for Noise, sets AD to 0x00, programs live NR42 envelope
; and NR43 frequency, gating NOISE. Active SFX on CHAN8 retains exclusive
; ownership until finished; music Wave cannot preempt it.
; In: EBX = 3 from the wired call site, EBP = GB memory base, restart already consumed.
; Clobbers EAX ECX EDX EDI. No-op with the shim inactive.
; ---------------------------------------------------------------------------
innova_noise_keyon:
    cmp byte [g_innova_on], 0
    jz .off
    ; SFX voice stealing lockout:
    ; If this noise event is a music drum (wChannelSoundIDs + CHAN8 == 0),
    ; it is strictly prohibited from stealing Voice 3 if ANY SFX is active
    ; on CHAN5..CHAN7.
    cmp byte [ebp + wChannelSoundIDs + CHAN8], 0
    jnz .isNoiseSfx
    mov al, [ebp + wChannelSoundIDs + CHAN5]
    or al, [ebp + wChannelSoundIDs + CHAN6]
    or al, [ebp + wChannelSoundIDs + CHAN7]
    jnz .off                    ; SFX in flight: suppress music drum steal
    ; MIDI mode: the MT-32/GM stream carries the music, so music drums never steal V3
    cmp byte [g_midi_music], 0
    jnz .off
    mov byte [s_noise_is_sfx], 0
    jmp .latchPayload
.isNoiseSfx:
    mov byte [s_noise_is_sfx], 1

.latchPayload:
    ; latch the GB noise payload (NR42/NR41)
    mov al, [ebp + rAUD4ENV]
    mov ah, al
    shr ah, 4
    mov [s_noise_vol], ah
    mov ah, al
    shr ah, 3
    and ah, 1
    mov [s_noise_dir], ah
    and al, 7
    mov [s_noise_per], al
    mov word [s_noise_acc], 0
    mov al, [ebp + rAUD4LEN]
    and eax, 0x3F
    neg eax
    add eax, 64
    mov [s_noise_len], ax
    mov word [s_noise_lacc], 0
    mov al, [ebp + rAUD4GO]       ; restart consumed at the call site already
    and al, 0x40                  ; bit 6 = length enable
    mov [s_noise_lenen], al
    mov al, [ebp + rAUD4POLY]
    mov [s_noise_nr43], al

    ; program the noise, params before gate (bring-up order)
    lea edi, [innova_state + 2*SS_SIZE]
    mov ah, 0x13                  ; AD = 0x00 (Attack 2ms, Decay 6ms)
    xor al, al
    call innova_write
    mov al, [s_noise_vol]
    shl al, 4                     ; SR: sustain rides GB volume, R = 0
    mov [edi + SS_LASTSUS], al
    mov ah, 0x14
    call innova_write
    call innova_noise_freq        ; $0E/$0F from NR43
    mov al, INNOVA_CTL_NOISE | INNOVA_GATE
    mov [edi + SS_LASTCTL], al
    mov ah, 0x12                  ; CONTROL = NOISE+GATE last
    call innova_write
    mov byte [s_noise_on], 1
.off:
    ret

; ---------------------------------------------------------------------------
; innova_noise_freq — program V3 Fn ($0E/$0F) from NR43 (GB ch3 pitch).
; GB: LFSR clock Hz = 262144/(r·2^(s+1)), r = NR43 bits 2-0 (0 counts as
; 0.5, tandy shape), s = bits 7-4. Card: Fn = Hz x 18.7478755, so
;   Fn = 262144 x 18.7478755 / divisor = 4914643.075... / divisor
;   (262144 x 18 = 4718592; 262144 x 0.7478755 = 196051.075; sum 4914643.075)
; Integer form: Fn = INNOVA_NOISE_NUM (4914643) div divisor, divisor in
; 1..458752 (never 0: r = 0 folds to 1 << s), then clamped to 16 bits
; (innova_setfreq's branch-free shape). SID noise pitch tracks Fn (rumble to
; hiss), so NR43 lands as brightness. Clobbers EAX ECX EDX.
; ---------------------------------------------------------------------------
innova_noise_freq:
    mov al, [ebp + rAUD4POLY]
    movzx ecx, al
    shr ecx, 4                    ; ECX = s (0-15)
    and eax, 7                    ; EAX = r
    jnz .haveR
    mov eax, 1                    ; r = 0 counts as 0.5: divisor 2^s
    shl eax, cl
    jmp .haveDiv
.haveR:
    inc ecx                       ; s+1
    shl eax, cl                   ; divisor r << (s+1)
.haveDiv:
    mov ecx, eax
    mov eax, INNOVA_NOISE_NUM
    xor edx, edx
    div ecx                       ; EAX = Fn, truncated
    cmp eax, 0xFFFF
    sbb ecx, ecx                  ; ECX = -1 if EAX < FFFF else 0
    and eax, ecx
    not ecx
    and ecx, 0xFFFF
    or eax, ecx                   ; EAX = Fn clamped to 16 bits, no branch
    mov edx, eax                  ; DX = Fn
    mov ah, 0x0E                  ; FREQ LO
    mov al, dl
    call innova_write
    mov ah, 0x0F                  ; FREQ HI (no live flags here)
    mov al, dh
    call innova_write
    ret

; ---------------------------------------------------------------------------
; innova_noise_tick — per-tick service for a stolen V3.
; Rides the noise envelope onto $14, follows NR43 rewrites, and handles note-off.
; Multi-note SFX remain active until wChannelSoundIDs CHAN8 is 0.
; Releases Voice 3 back to the live Wave state cleanly when finished.
; Clobbers EAX ECX EDX EDI, plus EBX on restore.
; ---------------------------------------------------------------------------
innova_noise_tick:
    cmp byte [s_noise_on], 0
    jz .done

    ; If an SFX owned Voice 3 and the SFX has finished, release Voice 3 back at once
    cmp byte [s_noise_is_sfx], 0
    jz .checkMidi
    cmp byte [ebp + wChannelSoundIDs + CHAN8], 0
    jnz .tickVoice
    call innova_noise_restore
    ret

.checkMidi:
    ; MIDI mode: music drums never stay on SID
    cmp byte [g_midi_music], 0
    jz .tickVoice
    call innova_noise_restore
    ret

.tickVoice:
    lea edi, [innova_state + 2*SS_SIZE]
    ; envelope: one step per (period / 64) s, riding the $14 sustain nibble
    mov al, [s_noise_per]
    test al, al
    jz .freq
    movzx ecx, al
    imul ecx, 60
    movzx eax, word [s_noise_acc]
    add eax, 64
    cmp eax, ecx
    jb .storeEnv
    sub eax, ecx
    mov cl, [s_noise_vol]
    cmp byte [s_noise_dir], 0
    jz .envDown
    cmp cl, 15
    jae .storeEnv
    inc cl
    jmp .envSet
.envDown:
    test cl, cl
    jz .noiseDecayed
    dec cl
.envSet:
    mov [s_noise_vol], cl
    shl cl, 4
    cmp cl, [edi + SS_LASTSUS]
    je .storeEnv
    mov [edi + SS_LASTSUS], cl
    mov ah, 0x14
    mov al, cl
    call innova_write                ; EAX survives (innova_write preserves all)
.storeEnv:
    mov [s_noise_acc], ax
    jmp .freq
.noiseDecayed:
    ; Noise faded to 0. If SFX is still active, mute gate; if drum, restore.
    cmp byte [s_noise_is_sfx], 0
    jnz .muteNoise
    call innova_noise_restore
    jmp .done
.freq:
    mov al, [ebp + rAUD4POLY]
    cmp al, [s_noise_nr43]
    je .len
    mov [s_noise_nr43], al
    call innova_noise_freq
.len:
    ; length: 256 Hz countdown (innova_length's math); expiry is the note-off
    cmp byte [s_noise_lenen], 0
    jz .checkSfxEnd
    movzx eax, word [s_noise_lacc]
    add eax, 256
    movzx ecx, word [s_noise_len]
.step:
    cmp eax, 60
    jb .save
    sub eax, 60
    dec ecx
    jnz .step
    mov word [s_noise_len], 0
    mov byte [s_noise_lenen], 0
    mov [s_noise_lacc], ax
    cmp byte [s_noise_is_sfx], 0
    jnz .muteNoise
    call innova_noise_restore
    jmp .done
.save:
    mov [s_noise_len], cx
    mov [s_noise_lacc], ax
.checkSfxEnd:
    ; Check if active noise SFX has ended in the engine
    cmp byte [s_noise_is_sfx], 0
    jz .done
    cmp byte [ebp + wChannelSoundIDs + CHAN8], 0
    jnz .done
    ; SFX has ended: release Voice 3 back to Wave
    call innova_noise_restore
.done:
    ret
.muteNoise:
    ; Mute noise gate while SFX channel is still active
    test byte [edi + SS_LASTCTL], INNOVA_GATE
    jz .checkSfxEnd
    mov byte [edi + SS_LASTCTL], INNOVA_CTL_NOISE
    mov ah, 0x12
    mov al, INNOVA_CTL_NOISE
    call innova_write
    jmp .checkSfxEnd

; ---------------------------------------------------------------------------
; innova_noise_restore — hand Voice 3 back to Wave: reconstructs Voice 3
; directly from the live software state of Channel 2 (Wave) without stale
; snapshots or disruptive TEST pulses.
; Clobbers EAX ECX EDX EDI, plus EBX.
; ---------------------------------------------------------------------------
innova_noise_restore:
    mov byte [s_noise_on], 0
    mov byte [s_noise_is_sfx], 0
    lea edi, [innova_state + 2*SS_SIZE]
    cmp byte [edi + SS_KEY], 0
    jz .muteWave
    test byte [s_nr51_snap], 0x44
    jz .muteWave
    test byte [ebp + rAUD3ENA], 0x80
    jz .muteWave
    mov al, [ebp + rAUD3LEVEL]
    shr al, 5
    and eax, 3
    mov al, [InnovaWaveSUS + eax]
    test al, al
    jz .muteWave
    shl al, 4                     ; AL = sustain byte
    mov [edi + SS_LASTSUS], al
    ; program hardware V3 for Wave (Triangle)
    mov ah, 0x13
    xor al, al
    call innova_write             ; AD = 0x00
    mov ah, 0x14
    mov al, [edi + SS_LASTSUS]
    call innova_write             ; SR = sustain
    mov word [edi + SS_LASTFN], 0xFFFF ; force frequency rewrite
    mov ebx, 2
    call innova_setfreq           ; $0E/$0F from live SS_FREQ
    mov byte [edi + SS_LASTCTL], INNOVA_CTL_TRI | INNOVA_GATE
    mov ah, 0x12
    mov al, INNOVA_CTL_TRI | INNOVA_GATE
    call innova_write
    ret
.muteWave:
    mov byte [edi + SS_LASTCTL], INNOVA_CTL_TRI
    mov ah, 0x12
    mov al, INNOVA_CTL_TRI
    call innova_write
    ret

; ---------------------------------------------------------------------------
; innova_dbg_snapshot — copy shim state into the DEBUG_AUDIO scratch window
; (mpu401's midi_dbg_snapshot shape: mov al/mov [ebp+...] stores, EAX only).
; Window 9 ($D220-$D25F) is full past enh's $D25C, so this packs into the two
; free fragments (midi ends $D23D, pika starts $D240; window ends $D25F):
;   $D23E    g_innova_on             $D23F V1 packed voice byte
;   $D25D    V2 packed voice byte $D25E V3 packed voice byte
;   $D25F    last $18 byte (filter OFF + volume nibble)
; Packed voice byte: hi nibble = sustain 0-15 (SS_LASTSUS >> 4, the riding
; level), lo nibble bit3 = noise, bit2 = pulse, bit1 = tri, bit0 = gate
; (single-waveform, so at most one of the three is ever set). V3's noise
; bit doubles as the steal flag: pitched V3 never selects noise.
; In: EBP = GB memory base. Clobbers EAX.
; ---------------------------------------------------------------------------
innova_dbg_snapshot:
    mov al, [g_innova_on]
    mov [ebp + (W_PORT_SCRATCH + 0x5E)], al
    mov al, [innova_state + 0*SS_SIZE + SS_LASTCTL]
    mov ah, al
    and al, 0x01
    and ah, 0xC0
    shr ah, 4
    or al, ah
    mov ah, [innova_state + 0*SS_SIZE + SS_LASTCTL]
    and ah, 0x10
    shr ah, 3
    or al, ah
    mov ah, [innova_state + 0*SS_SIZE + SS_LASTSUS]
    and ah, 0xF0
    or al, ah
    mov [ebp + (W_PORT_SCRATCH + 0x5F)], al
    mov al, [innova_state + 1*SS_SIZE + SS_LASTCTL]
    mov ah, al
    and al, 0x01
    and ah, 0xC0
    shr ah, 4
    or al, ah
    mov ah, [innova_state + 1*SS_SIZE + SS_LASTCTL]
    and ah, 0x10
    shr ah, 3
    or al, ah
    mov ah, [innova_state + 1*SS_SIZE + SS_LASTSUS]
    and ah, 0xF0
    or al, ah
    mov [ebp + (W_PORT_SCRATCH + 0x7D)], al
    mov al, [innova_state + 2*SS_SIZE + SS_LASTCTL]
    mov ah, al
    and al, 0x01
    and ah, 0xC0
    shr ah, 4
    or al, ah
    mov ah, [innova_state + 2*SS_SIZE + SS_LASTCTL]
    and ah, 0x10
    shr ah, 3
    or al, ah
    mov ah, [innova_state + 2*SS_SIZE + SS_LASTSUS]
    and ah, 0xF0
    or al, ah
    mov [ebp + (W_PORT_SCRATCH + 0x7E)], al
    mov al, [s_lastmode]
    mov [ebp + (W_PORT_SCRATCH + 0x7F)], al
    ret

section .data

g_innova_on:     db 0              ; /INNOVA selected + innova_init ran

; Duty 0-3 -> 12-bit PWn (12.5/25/50/75% of 4096). Identity map from the
; datasheet PWout formula, not game data: too small to warrant a generator.
InnovaDutyPW:    dw 512, 1024, 2048, 3072
; NR32 level -> sustain nibble (mute/full/half/quarter onto linear 0-15).
InnovaWaveSUS:   db 0, 15, 8, 4

section .bss

innova_state:    resb 3 * SS_SIZE   ; ch0-2 voices (ch3 noise state is s_noise_*)
s_lastmode:   resb 1              ; last $18 byte written (0xFF = force)
s_nr51_snap:  resb 1              ; NR51 snapshot for this tick
s_v3save:     resb 7              ; stolen-voice image of V3 $0E-$14
                                ; (+0/1 Fn lo/hi, +2/3 PW lo/hi, +4 CONTROL,
                                ; +5 AD, +6 SR — from the ch2 LAST* caches)
s_noise_on:   resb 1              ; 1 = V3 currently stolen by ch3 noise
s_noise_is_sfx: resb 1            ; 1 = active steal belongs to an SFX (CHAN8)
s_noise_vol:  resb 1              ; latched NR42 init volume 0-15 (ridden as sustain)
s_noise_dir:  resb 1              ; envelope direction (1 = up)
s_noise_per:  resb 1              ; envelope period (0 = off)
s_noise_acc:  resw 1              ; envelope accumulator (64/tick vs 60*period)
s_noise_len:  resw 1              ; length counter (1/256 s units)
s_noise_lacc: resw 1              ; length accumulator (256/tick vs 60)
s_noise_lenen: resb 1             ; length enable (NR44 bit 6)
s_noise_nr43: resb 1              ; last NR43 (freq-follow)

%else

section .text
innova_init:
innova_pass:
innova_silence:
innova_shutdown:
innova_dbg_snapshot:
    ret

section .data
g_innova_on:     db 0

%endif
