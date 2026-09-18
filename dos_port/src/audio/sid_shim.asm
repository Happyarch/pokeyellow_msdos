; sid_shim.asm — virtual APU → Innovation SSI-2001 (MOS 6581 SID) device shim (port-only HAL layer).
;
; Port-only module (no pret counterpart; this file has no GB original and is
; owned by the DOS audio HAL, wired in stage 2 from audio_tick/audio_init).
;
; The SSI-2001 is a 6581 on an 8-bit ISA card (default base 0x280, card clock
; 14.31818/16 MHz). Once per audio tick sid_pass reads the GB channels from
; the virtual APU block at [ebp+$FF10..$FF26] and mirrors them onto the SID:
;
;   GB ch0 pulse1  -> V1 pulse     GB duty 0-3 -> 12-bit PW 512/1024/2048/3072
;   GB ch1 pulse2  -> V2 pulse     (same duty mapping)
;   GB ch2 wave    -> V3 triangle  at pitch, NR32 level as sustain
;   GB ch3 noise   -> V3-steal     (stage 1b: save $0E-$14, noise, restore)
;
; Like tandy_shim, the engine's NRx4 restart bit is CONSUMED here, and what
; the SID lacks is emulated in software per tick, in GB units: envelope
; (NRx2, ridden as the sustain level with gate held on and A/D/R 0), sweep
; (NR10, pulse1), length (NRx1/NRx4 bit 6), master volume (NR50 louder side
; into the $18 volume nibble), and NR51 muting (both terminal bits clear ->
; gate off). Filter is OFF in v1 ($18 upper nibble 0, no routing).
;
; The SID is write-only ($00-$18; POT/OSC3/ENV3 have no shim use and $19-$1C
; are never touched). There is no probe: the shim activates only via the /SID
; command-line flag (stage 2: audio_init sets the device and calls sid_init);
; with g_sid_on = 0 every entry point no-ops.
;
; Frequency: GB Fout = 131072/(2048-f) Hz; card Fn = Fout x 18.7478755
; (see sid_setfreq for the exact integer form). Single-waveform control
; bytes only (pulse 0x40 / triangle 0x10, plus GATE): combining noise with
; anything wedges real silicon until a TEST pulse, so noise travels the
; stage-1b steal path, never a combined byte. Bring-up order per note:
; params (Fn, PW, S) first, CONTROL gate last.

%include "gb_memmap.inc"

global sid_init
global sid_pass
global sid_silence
global sid_shutdown
global sid_dbg_snapshot
global g_sid_on

section .text

SID_BASE equ 0x280             ; default SSI-2001 base (jumpers: 2A0/2C0/2E0)
; Card clock 14.31818 MHz / 16 = 894886.25 Hz. Fn = Fout x 16777216/Fclk
; = Fout x 18.7478755 (Fclk truncation to the integer below moves Fn by
; far less than one LSB; the .25 is carried in the numerator instead).
SID_CLOCK equ 894886           ; ISA card O2 in Hz (documentary; math uses the numerator)
SID_GBFN_NUM equ 2457322      ; round(131072 x 18.7478755), see sid_setfreq

SID_VSTRIDE equ 7              ; voice register stride ($00/V1, $07/V2, $0E/V3)
SID_R_FREQLO equ 0
SID_R_FREQHI equ 1
SID_R_PWLO equ 2
SID_R_PWHI equ 3
SID_R_CTL equ 4
SID_R_AD equ 5                 ; attack/decay: stays at its silenced 0
SID_R_SR equ 6                 ; sustain/release: sustain rides GB envvol, R = 0
SID_R_MODEVOL equ 0x18         ; filter mode (OFF v1) + master volume nibble

SID_CTL_PULSE equ 0x40         ; single waveform bits (never combined, never noise)
SID_CTL_TRI equ 0x10
SID_GATE equ 0x01

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
; sid_write — write AL to SID_BASE+AH. Blind OUTs: the ISA card needs no
; pacing (Tacc 300 ns). In: AH = SID register offset ($00-$18), AL = data.
; Preserves all registers and flags (movzx/lea/out/push/pop touch neither).
; ===========================================================================
sid_write:
    push edx
    movzx edx, ah
    lea edx, [edx + SID_BASE]
    out dx, al
    pop edx
    ret

; ===========================================================================
; sid_init — reset software state, silence the card, mark the shim active.
; Stage-2 audio_init calls this only when /SID selected the device.
; Preserves all registers.
; ===========================================================================
sid_init:
    pushad
    mov byte [g_sid_on], 1
    mov ecx, 3 * SS_SIZE
    mov edi, sid_state
.clr:
    mov byte [edi], 0
    inc edi
    loop .clr
    mov edi, sid_state
    mov ecx, 3
.vinit:
    mov byte [edi + SS_LASTCTL], 0xFF
    mov byte [edi + SS_LASTSUS], 0xFF
    mov word [edi + SS_LASTFN], 0xFFFF
    mov word [edi + SS_LASTPW], 0xFFFF
    add edi, SS_SIZE
    loop .vinit
    mov byte [s_lastmode], 0xFF
    call sid_silence
    popad
    ret

; ===========================================================================
; sid_silence — leave the card silent (zero $00-$18). Exported for
; PlayPikachuSoundClip like tandy_silence: software envelopes freeze during
; the cli PCM clip, so held notes must be cut; voices re-key on their next
; note-on. Safe with the shim inactive (bare OUTs to an absent port).
; ===========================================================================
sid_silence:
    ; TODO(Stage 1b): zero $00-$18 in bring-up order, reset the SS_LAST*
    ; caches, TEST-pulse hygiene on release.
    cmp byte [g_sid_on], 0
    jz .off
.off:
    ret

; sid_shutdown — leave the card silent on exit. Preserves all registers.
sid_shutdown:
    ; TODO(Stage 1b): card-silent exit once sid_silence lands.
    jmp sid_silence

; ===========================================================================
; sid_pass — the per-tick APU mirror. Stage-2 audio_tick calls this (DelayFrame
; is pushad-wrapped, registers may be clobbered freely).
;   EBX = GB channel (0-2; ch3 noise is consumed into the stage-1b hook)
;   ESI = GB address of the channel's register file ($FF10 + ch*5)
;   EDI = its software voice state
; ===========================================================================
sid_pass:
    cmp byte [g_sid_on], 0
    jz .off
    ; master volume from NR50 (the louder terminal, like tandy_shim, so
    ; FadeOutAudio's simultaneous L/R ramp maps to a single volume ramp):
    ; 3-bit side 0-7 << 1 -> even nibble 0-14 ($18 upper nibble stays 0:
    ; filter OFF v1). GB 0 stays silent; SID 15 is simply unused headroom.
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
    mov ch, al
    mov ah, SID_R_MODEVOL
    mov al, ch
    call sid_write
.m2:
    mov al, [ebp + rAUDTERM]
    mov [s_nr51_snap], al

    xor ebx, ebx
.chLoop:
    lea esi, [ebx*4 + ebx]
    add esi, 0xFF10             ; channel register base
    lea eax, [ebx + ebx*4]
    imul eax, eax, SS_SIZE      ; ch * SS_SIZE
    lea edi, [sid_state + eax]

    mov al, [ebp + esi + 4]     ; NRx4
    test al, 0x80
    jz .noRestart
    and al, 0x7F                ; consume the restart bit
    mov [ebp + esi + 4], al
    call sid_keyon
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
    call sid_setfreq
.running:
    cmp byte [edi + SS_KEY], 0
    jz .next
    call sid_sweep
    call sid_envelope
    call sid_length
    call sid_pulsew
    call sid_volume
.next:
    inc ebx
    cmp ebx, 3
    jb .chLoop
    ; ch3 (noise) restart is consumed here so the bit never lingers; the
    ; V3-steal voice itself is stage 1b.
    mov al, [ebp + rAUD4GO]
    test al, 0x80
    jz .off
    and al, 0x7F
    mov [ebp + rAUD4GO], al
    call sid_noise_keyon
.off:
    ret

; ---------------------------------------------------------------------------
; sid_keyon — retrigger channel EBX from its APU registers (the same latch
; sequence as tandy_shim's keyon: envelope, length, sweep, frequency).
; Cuts the stale voice first, programs params, gates last (bring-up order).
; ---------------------------------------------------------------------------
sid_keyon:
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
    call sid_gateoff
    call sid_setfreq
    call sid_pulsew
    jmp sid_volume

; sid_keyoff — length/sweep expiry: drop KEY and cut the gate. The sustain
; cache is left for the next keyon (which forces a rewrite).
sid_keyoff:
    mov byte [edi + SS_KEY], 0
    ; fall through

; sid_gateoff — write CONTROL without GATE for channel EBX (single waveform,
; never noise). Updates SS_LASTCTL. Clobbers EAX ECX.
sid_gateoff:
    mov al, SID_CTL_PULSE
    cmp ebx, 2
    jne .w
    mov al, SID_CTL_TRI
.w:
    mov [edi + SS_LASTCTL], al
    imul ecx, ebx, SID_VSTRIDE
    add ecx, SID_R_CTL
    mov ah, cl
    call sid_write
    ret

; ---------------------------------------------------------------------------
; sid_setfreq — program Fn for voice EBX from SS_FREQ (GB 11-bit f).
; GB: Fout = 131072/(2048-f) Hz. Card: Fn = Fout x 18.7478755, so
;   Fn = 131072 x 18.7478755 / (2048-f) = 2457321.5375... / (2048-f)
;   (131072 x 18 = 2359296; 131072 x 0.7478755 = 98025.5375; sum 2457321.5375)
; Integer form: Fn = SID_GBFN_NUM (2457322) div (2048-f), f masked to 11
; bits so the divisor is in 1..2048 (never 0), then clamped to 16 bits.
; Cross-check: A4 (GB f = 1750) -> 2457322/298 = 8246 = $2036, within a few
; LSB of the printed $2039 (GB-step quantization plus rounding).
; Divisor math and the table-free clamp below are branch-free; the hi/lo
; split write is skipped when Fn is unchanged. Clobbers EAX ECX EDX.
; ---------------------------------------------------------------------------
sid_setfreq:
    movzx eax, word [edi + SS_FREQ]
    and eax, 0x7FF
    mov ecx, 2048
    sub ecx, eax
    mov eax, SID_GBFN_NUM
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
    imul ecx, ebx, SID_VSTRIDE    ; voice base offset
    mov ah, cl                    ; FREQ LO
    mov al, dl
    call sid_write
    mov ah, cl
    inc ah                        ; FREQ HI (no live flags here)
    mov al, dh
    call sid_write
.done:
    ret

; ---------------------------------------------------------------------------
; sid_pulsew — program the 12-bit pulse width for V1/V2 from the GB duty
; bits (NRx1 bits 7-6): 12.5/25/50/75% -> PWn 512/1024/2048/3072
; (PWout = PWn/40.95%: 2048 = square). Branch-free table lookup, written
; on change (PW HI carries the low nibble only, per Table 1). No-op on
; ch2 (triangle has no width). Clobbers EAX ECX EDX.
; ---------------------------------------------------------------------------
sid_pulsew:
    cmp ebx, 2
    je .done
    mov al, [ebp + esi + 1]
    shr al, 6
    movzx eax, al
    mov ax, [SidDutyPW + eax*2]
    cmp ax, [edi + SS_LASTPW]
    je .done
    mov [edi + SS_LASTPW], ax
    mov edx, eax                  ; DX = PWn
    imul ecx, ebx, SID_VSTRIDE
    add ecx, SID_R_PWLO
    mov ah, cl                    ; PW LO
    mov al, dl
    call sid_write
    mov ah, cl
    inc ah                        ; PW HI
    mov al, dh
    and al, 0x0F
    call sid_write
.done:
    ret

; ---------------------------------------------------------------------------
; sid_sweep — pulse-1 hardware sweep emulation (128 Hz base clock).
; Same math as tandy_shim's sweep.
; ---------------------------------------------------------------------------
sid_sweep:
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
    jmp sid_keyoff                ; overflow silences the channel (GB rule)
.down:
    sub edx, eax
    jns .apply
    xor edx, edx
.apply:
    mov [edi + SS_FREQ], dx
    jmp sid_setfreq
.store:
    mov [edi + SS_SWACC], cx
.done:
    ret

; ---------------------------------------------------------------------------
; sid_envelope — GB volume envelope: one step per (period / 64) s. The level
; rides the SUSTAIN nibble each tick (gate stays on, A/D/R 0); hitting 0
; plays silence through an open gate, exactly like a GB channel at vol 0.
; ---------------------------------------------------------------------------
sid_envelope:
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
; sid_length — GB length counter: 256 Hz countdown, key-off at zero.
; ---------------------------------------------------------------------------
sid_length:
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
    jmp sid_keyoff
.save:
    mov [edi + SS_LEN], cx
    mov [edi + SS_LENACC], ax
.done:
    ret

; ---------------------------------------------------------------------------
; sid_volume — sustain-riding plus gate: S nibble follows GB envvol
; (ch0/ch1) or the NR32 level (ch2); CONTROL carries the single waveform
; with GATE while sounding, without it while muted. A channel with both
; NR51 bits clear, a disabled wave DAC, or NR32 level 0 is force-muted
; (rests/ducks). $05 is never written (its silenced 0 already means A/D 0).
; Clobbers EAX ECX EDX.
; ---------------------------------------------------------------------------
sid_volume:
    mov cl, bl
    mov ch, 0x11
    shl ch, cl                    ; NR51 terminal pair mask for this channel
    test [s_nr51_snap], ch        ; ZF set below iff both bits clear
    jz .mute
    cmp ebx, 2
    je .wave
    mov al, [edi + SS_ENVVOL]
    shl al, 4                     ; $06 byte: S = envvol, R = 0
    jmp .haveSR
.wave:
    mov al, [ebp + rAUD3ENA]
    test al, 0x80                 ; wave DAC off -> silent
    jz .mute
    mov al, [ebp + rAUD3LEVEL]
    shr al, 5
    and eax, 3
    mov al, [SidWaveSUS + eax]
    test al, al                   ; NR32 level 0 -> silent
    jz .mute
    shl al, 4
.haveSR:
    cmp al, [edi + SS_LASTSUS]
    je .gate
    mov [edi + SS_LASTSUS], al
    imul ecx, ebx, SID_VSTRIDE
    add ecx, SID_R_SR
    mov ah, cl
    call sid_write
.gate:
    ; CONTROL = single waveform + GATE
    mov al, SID_CTL_PULSE
    cmp ebx, 2
    jne .haveCtl
    mov al, SID_CTL_TRI
.haveCtl:
    or al, SID_GATE
    cmp al, [edi + SS_LASTCTL]
    je .done
    mov [edi + SS_LASTCTL], al
    imul ecx, ebx, SID_VSTRIDE
    add ecx, SID_R_CTL
    mov ah, cl
    call sid_write
.done:
    ret
.mute:
    ; cut the gate; the sustain cache stays for the next keyon (forced there)
    mov al, SID_CTL_PULSE
    cmp ebx, 2
    jne .haveMute
    mov al, SID_CTL_TRI
.haveMute:
    cmp al, [edi + SS_LASTCTL]
    je .done
    mov [edi + SS_LASTCTL], al
    imul ecx, ebx, SID_VSTRIDE
    add ecx, SID_R_CTL
    mov ah, cl
    call sid_write
    ret

; ---------------------------------------------------------------------------
; sid_noise_keyon — ch3 trigger hook: V3-steal lives here in stage 1b
; (save V3 $0E-$14, program noise control + ADSR, restore on note-off with
; a TEST pulse on release, single-waveform invariant throughout).
; ---------------------------------------------------------------------------
sid_noise_keyon:
    ; TODO(Stage 1b): V3-steal body.
    ret

; ---------------------------------------------------------------------------
; sid_dbg_snapshot — copy shim state into the $D248+ debug scratch window
; (DEBUG_AUDIO window 9 spans $D220-$D25F; $D240-45 is pika_dbg_snapshot's).
; In: EBP = GB memory base. Clobbers EAX.
; ---------------------------------------------------------------------------
sid_dbg_snapshot:
    ; TODO(Stage 1b): snapshot map in mpu401's shape (g_sid_on, per-voice
    ; CONTROL/SUSTAIN/Fn caches, last $18 byte).
    ret

section .data

g_sid_on:     db 0              ; /SID selected + sid_init ran

; Duty 0-3 -> 12-bit PWn (12.5/25/50/75% of 4096). Identity map from the
; datasheet PWout formula, not game data: too small to warrant a generator.
SidDutyPW:    dw 512, 1024, 2048, 3072
; NR32 level -> sustain nibble (mute/full/half/quarter onto linear 0-15).
SidWaveSUS:   db 0, 15, 8, 4

section .bss

sid_state:    resb 3 * SS_SIZE   ; ch0-2 voices (ch3 noise state lands in 1b)
s_lastmode:   resb 1              ; last $18 byte written (0xFF = force)
s_nr51_snap:  resb 1              ; NR51 snapshot for this tick
