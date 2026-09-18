; cms_shim.asm — virtual APU → Creative CMS / Game Blaster device shim (port-only HAL layer).
;
; Port-only module (no pret counterpart; this file has no GB original and is
; owned by the DOS audio HAL, wired in stage 2 from audio_tick/audio_init).
;
; The Game Blaster carries 2x Philips SAA1099 (docs/sound/SAA1099_Philips_1984.md,
; cited below as [SAA] by section). Once per audio tick cms_pass reads the 4 GB
; channels from the virtual APU block at [ebp+$FF10..$FF26] and mirrors them
; onto the FIRST chip at CMS_BASE 0x220 (voices 1-6: address 0x221, data 0x220).
; The SECOND chip (voices 7-12: address 0x223, data 0x222) has its port pairs
; defined below but is never touched past cms_init's park: v1 needs 4 voices,
; the 8 spare voices are the plan's tier-1 enhancement headroom (not a defect),
; and the chip's power-on SE=0 state ([SAA] §8) plus the init park keep it silent.
;
; Voice/register allocation (first chip; SAA channel index = GB channel):
;   GB ch0 pulse1 ($FF10) -> voice 1 (ch 0): amp $00, tone $08, octave $10 low
;       half, FE bit 0. GB duty (NR11) collapses: SAA squares are fixed-shape,
;       the same Tandy treatment (the SN76489 also does 50% only).
;   GB ch1 pulse2 ($FF15) -> voice 2 (ch 1): amp $01, tone $09, octave $10 high
;       half, FE bit 1. Duty collapses likewise.
;   GB ch2 wave ($FF1A) -> voice 3 (ch 2): amp $02, tone $0A, octave $11 low
;       half, FE bit 2 = 0 and NE bit 2 = 0 always. With its driving frequency
;       channel off, the envelope generator itself appears at the output ([SAA]
;       §7 non-square mode), so voice 3 is a hardware repetitive triangle
;       (Fig.5 row f: $18 = 0x8A — envelope 0 enabled, 4-bit steps, internal
;       clock, non-inverted) at the $0A/$11 pitch, not a plain square. Row f
;       over row h (sawtooth train): the symmetric triangle has no DC step and
;       sits closer to the wave channel's usual mellow patches; the sawtooth
;       stays a later option. Envelope-drive caveats ([SAA] §§3.4/7): amplitude
;       resolution halves to 8 levels (the shim clears the LSB — even levels
;       only) and active output caps at 7/8 of the programmed level. NR32 rides
;       $02 directly (mute/full/half/quarter -> 0/15/8/4); the GB wave channel
;       carries no envelope selector, so $18 is programmed once at init and
;       never touched per tick. Rate ceiling is ~1 kHz at 4-bit steps, so high
;       wave notes flatten in hardware — still open past 1.3 (static check
;       only; needs the ear stage to judge).
;       Clock-assumption note: $18's internal clock is taken to follow voice 3's
;       own frequency generator (the Fig.1 FREQ-2-to-ENV-0 pairing, [SAA] §3 —
;       a [?]-marked reading), the only wiring under which the triangle tracks
;       $0A/$11 with no cross-channel coupling. If the tuner proves otherwise,
;       the mapping is revisited in 1.3.
;   GB ch3 noise ($FF1F) -> voice 4 (ch 3): amp $03, FE bit 3 = 0, NE bit 3 =
;       key state (mixer noise-only: the FE/NE bytes together encode the four
;       mixer selections, [SAA] §§3.3/5). No tone is programmed ($0B and the
;       $11 high half stay 0); the tone-boost remark ([SAA] §3.2) concerns mixed
;       tone+noise only, which v1 never selects. Colour from the $16 HIGH pair
;       (noise generator 1, the voices-4-6 group): presets 31.3/15.6/7.6 kHz by
;       nearest match to the GB LFSR clock (262144/r/2^(s+1), r=0 counts as
;       0.5 — the tandy formula) at geometric midpoints 22097/10889 Hz.
;       Presets over the `11` follow mode: the follow-mode generator pairing is
;       a [?]-marked inference ([SAA] §6) while the preset rates are Table-3
;       normative, the preset path is three compares with no tone programming
;       (simpler), and it mirrors the tandy precedent. The GB 7/15-bit width
;       bit has no SAA counterpart and is ignored. Unlike tandy's SN path,
;       keyon forces no noise rewrite: the SAA documents no LFSR reset on mixer
;       writes, so there is nothing to re-arm.
;   Voices 5-6 (ch 4-5): unused v1 (FE/NE 0, amps $04/$05 zeroed by silence).
;
; Like tandy_shim, the engine's NRx4 restart bit is CONSUMED here, and what the
; SAA lacks is emulated in software per tick, in GB units: envelope (NRx2,
; ridden as the voice amplitude), sweep (NR10, pulse1 — overflow silences per
; the GB rule), length (NRx1/NR44 bit 6, 256 Hz countdown), master volume (NR50
; louder side as a linear amplitude offset: drop = 7 - louder), and NR51 muting
; (both terminal bits clear -> amp 0; the SAA scales 0 = off to 15 = max, the
; inverse of the SN attenuator, so mute is 0 not 15). Under MIDI (g_midi_music)
; a voice sounds only while an SFX owns its GB channel (wChannelSoundIDs
; CHAN5-8 — the tandy guard shape, placed in cms_volume so stage 2.3 needs no
; change).
;
; Pitch (provisional v1, tuner-checked in 1.3): GB Hz by the exact integer
; formulae (pulse 131072/(2048-f), wave 65536/(2048-f)), SAA octave from the
; [SAA] §3.1 bands as half-open powers of two (lo = 31<<k; the printed bounds
; overlap, so half-open is the v1 reading; at/above 3968 Hz octave 7 with Fn
; clamped), Fn by linear interpolation within the band. [SAA] §11 gives no
; divider equations, so any Fn law is a guess; the gameblst note table ([SAA]
; §9.5) is the cross-check for the 1.3 tuner pass (its shrinking semitone steps
; already hint at a divider law, which would replace the linear map — expected,
; not feared). 1.3 cross-check (static, table A=3..G#=242 at C=55 Hz):
; DISCREPANCY CONFIRMED, map unchanged (no ears in 1.3). Table steps shrink
; 28..16 while the linear law predicts growing steps (A..D Fn 125.9/148.6/
; 172.7/198.2/225.2/253.8, steps ~22.7..~28.6) — opposite curvature, a divider
; law as foreseen. Placement disagrees too: the table spans A(46.2 Hz)..G#
; (87.3 Hz) in one octave byte (Fn 3..242 monotonic) while the half-open 31<<k
; bands split it at 62 Hz (D/D#), wrapping D#..G# to Fn 14..104 above. Retune
; stays a later ear stage. No octave shift for the wave voice: the SAA 31 Hz floor covers
; the GB wave range, unlike the SN divider clamp that forced tandy's shift.
;
; Bring-up follows [SAA] §9.2 verbatim on the first pair: $1C=$02 (reset),
; $15=$00 (noise off), $1C=$01 (enable). ISA OUTs are bare (no settle reads):
; the card docs show bare Port writes and an ISA OUT (~1 us) already exceeds
; the SAA 4-tCLK bus cycle ([SAA] §4).
;
; Address-latch exploitation ([SAA] §4 repeat-write rule: the latched register
; persists across data writes): every first-chip port write funnels through
; cms_wreg, which tracks the latched address in c_lastaddr and elides the
; address-port OUT when the next write targets the same register. The v1 tick
; pattern is mostly distinct registers per voice (4 amps + 3 tones + 2 composed
; octaves + FE/NE), so the elision fires on consecutive same-register updates
; (re-armed FE/NE across ticks, recomposed octave pairs) rather than long
; streams — the helper makes each such case free with no caller complexity. The
; second chip has its own latch; the tick path never touches it, so the tracker
; models the first pair only. Only cms_wreg writes CMS_ADDR_LO — that invariant
; is what keeps the tracker sound.
;
; The shim activates only via the /GB command-line flag (stage 2: audio_init
; sets the device and calls cms_init); with g_cms_on = 0 every entry point
; no-ops. Stage 1.3 done: $1C SE handling in silence (SE=0, tick re-arms
; SE=1), the pre-clip hook-in point recorded (pikachu_pcm.asm:90, wired in
; stage 2), and the snapshot map below (provisional +0x89..+0x8C on the covox
; echo-slack precedent; the debug_dump window extension stays stage 2/3).

bits 32

%include "gb_memmap.inc"

global cms_init
global cms_pass
global cms_silence
global cms_shutdown
global cms_dbg_snapshot
global g_cms_on

%ifndef ENABLE_AUDIO_CMS
%define ENABLE_AUDIO_CMS 1
%endif

%if ENABLE_AUDIO_CMS != 0

extern g_midi_music               ; src/audio/mpu401.asm — MIDI mode active

section .text

CMS_BASE    equ 0x220
CMS_DATA_LO equ (CMS_BASE + 0)    ; 0x220: data, voices 1-6 (first chip)
CMS_ADDR_LO equ (CMS_BASE + 1)    ; 0x221: register address, voices 1-6
CMS_DATA_HI equ (CMS_BASE + 2)    ; 0x222: data, voices 7-12 (second chip, init park only)
CMS_ADDR_HI equ (CMS_BASE + 3)    ; 0x223: register address, voices 7-12

; SAA register addresses (both chips; the v1 tick path uses the LO pair only)
CMS_R_AMP0  equ 0x00              ; $00-$05: voice amplitude (hi nibble R, lo nibble L)
CMS_R_TONE0 equ 0x08              ; $08-$0D: voice tone byte Fn
CMS_R_OCT01 equ 0x10              ; $10: octaves voice 2 (hi 3 bits) + voice 1 (lo 3 bits)
CMS_R_OCT23 equ 0x11              ; $11: octaves voice 4 (hi) + voice 3 (lo)
CMS_R_OCT45 equ 0x12              ; $12: octaves voice 6 (hi) + voice 5 (lo)
CMS_R_FE    equ 0x14              ; $14: tone enable bits 0-5
CMS_R_NE    equ 0x15              ; $15: noise enable bits 0-5
CMS_R_NCOL  equ 0x16              ; $16: noise colours, gen 1 hi pair, gen 0 lo pair
CMS_R_ENV0  equ 0x18              ; $18: envelope generator 0 (wave voice)
CMS_R_ENV1  equ 0x19              ; $19: envelope generator 1 (unused v1)
CMS_R_SE    equ 0x1C              ; $1C: bit 1 reset, bit 0 sound enable

CMS_SE_RESET  equ 0x02
CMS_SE_ENABLE equ 0x01
; Envelope 0 program for the wave voice: enabled, 4-bit steps, internal
; clock, repetitive triangle (Fig.5 row f), non-inverted right side.
CMS_ENV0_TRI equ 0x8A             ; En7=1, En6=0, En5=0, En4=0, En3-1=101, En0=0

; Noise preset colours ([SAA] Table 3) and the geometric-midpoint bounds
; against the GB LFSR clock in Hz (22097/10889 from 31300/15600/7600).
CMS_N_31K    equ 0
CMS_N_15K    equ 1
CMS_N_7K     equ 2
CMS_N_MID_HI equ 22097
CMS_N_MID_LO equ 10889

CMS_OCT_BASE equ 31               ; octave-0 band edge in Hz ([SAA] §3.1)
CMS_OCT_TOP  equ 3968             ; 31<<7: octave-7 entry edge

; --- per-voice software state (offsets 0-15 mirror tandy_shim's TS_*) ------
CMS_FREQ     equ 0    ; word: GB 11-bit freq (ch3: NR43 byte) incl. sweep
CMS_KEY      equ 2    ; byte: key-on flag
CMS_ENVVOL   equ 3    ; byte: current GB volume 0-15
CMS_ENVDIR   equ 4    ; byte: envelope direction (1 = up)
CMS_ENVPER   equ 5    ; byte: envelope period (0 = off)
CMS_ENVACC   equ 6    ; word: envelope accumulator (64/tick vs 60*period)
CMS_LEN      equ 8    ; word: length counter (1/256 s units)
CMS_LENACC   equ 10   ; word: length accumulator (256/tick vs 60)
CMS_LENEN    equ 12   ; byte: length enable (NRx4 bit 6)
CMS_SWEEP    equ 13   ; byte: NR10 latched at key-on (ch0 only)
CMS_SWACC    equ 14   ; word: sweep accumulator (128/tick vs 60*period)
CMS_LASTAMP  equ 16   ; byte: last amp nibble written (0xFF = force)
CMS_LASTTONE equ 17   ; word: last Fn written (0xFFFF = force; Fn reaches 0xFF)
CMS_LASTOCT  equ 19   ; byte: last 3-bit octave (init 0 keeps the compose valid)
CMS_SIZE     equ 20

; --- CMS debug snapshot block (covox precedent: past the dumped window, -----
; --- over echo-RAM slack; the harness window extension stays stage 2/3) -----
; CMS_SNAP = W_PORT_SCRATCH+0x89, 4 bytes +0x89..+0x8C, contiguous past covox's
; +0x81..+0x88: +0x89 g_cms_on, +0x8A v0|v1 LASTAMP nibbles, +0x8B v2|v3 LASTAMP
; nibbles, +0x8C last FE (bits 0-1) OR last NE (bit 3 — lossless, no shared
; bits). Free-verified the covox way: nearest named memmap symbols are
; W_CHECK_FOR_TURN at +0x80 (1 byte, skipped) and nothing named above it (no
; 0xF58x symbol past 0xF580 in gb_memmap.inc), and no other shim snapshot
; reaches +0x89 (enh ends +0x7C, innova ends +0x7F, covox ends +0x88). The port
; does not emulate the echo mirror, the same basis W_PORT_SCRATCH stands on.
CMS_SNAP equ (W_PORT_SCRATCH + 0x89)   ; +0x89..+0x8C (covox ends +0x88)

; ===========================================================================
; cms_wreg — write AH to SAA register AL on the first chip. The chip latch
; persists ([SAA] §4), so a write to the already-latched register skips the
; address-port OUT (repeat-write rule); anything else re-latches first.
; Only this routine writes CMS_ADDR_LO — that is what keeps c_lastaddr sound.
; In: AL = register, AH = data. Clobbers EAX EDX. Preserves the rest.
; ===========================================================================
cms_wreg:
    cmp al, [c_lastaddr]
    je .data
    mov [c_lastaddr], al
    mov dx, CMS_ADDR_LO
    out dx, al
.data:
    mov al, ah
    mov dx, CMS_DATA_LO
    out dx, al
    ret

; ===========================================================================
; cms_init — reset software state, bring the card up per [SAA] §9.2, park the
; second chip silent, quiet the first, mark the shim active. Called from
; audio_init only when /GB selected the device. Preserves all registers.
; ===========================================================================
cms_init:
    pushad
    mov byte [g_cms_on], 1
    mov byte [c_lastaddr], 0xFF
    mov ecx, 4 * CMS_SIZE
    mov edi, cms_state
.clr:
    mov byte [edi], 0
    inc edi
    loop .clr
    mov edi, cms_state
    mov ecx, 4
.vinit:
    mov byte [edi + CMS_LASTAMP], 0xFF
    mov word [edi + CMS_LASTTONE], 0xFFFF
    mov byte [edi + CMS_LASTOCT], 0   ; valid octave: the post-loop compose
    add edi, CMS_SIZE                  ; must never see a force-marker here
    loop .vinit
    mov byte [c_lastfe], 0xFF
    mov byte [c_lastne], 0xFF
    mov byte [c_lastse], 0xFF
    mov byte [c_lastoct10], 0xFF
    mov byte [c_lastoct11], 0xFF
    mov byte [c_lastncol], 0xFF
    ; §9.2 bring-up on the first pair: reset, noise off, enable.
    mov al, CMS_R_SE
    mov ah, CMS_SE_RESET
    call cms_wreg
    mov al, CMS_R_NE
    xor ah, ah
    call cms_wreg
    mov al, CMS_R_SE
    mov ah, CMS_SE_ENABLE
    call cms_wreg
    ; Fixed programs: noise colour 0, envelope 0 triangle, envelope 1 off,
    ; tones/octaves 0 (silence + the first commits bring the live values).
    mov al, CMS_R_NCOL
    xor ah, ah
    call cms_wreg
    mov byte [c_lastncol], 0
    mov al, CMS_R_ENV0
    mov ah, CMS_ENV0_TRI
    call cms_wreg
    mov al, CMS_R_ENV1
    xor ah, ah
    call cms_wreg
    xor ebx, ebx
.toneLoop:
    mov al, CMS_R_TONE0
    add al, bl
    xor ah, ah
    call cms_wreg
    inc ebx
    cmp ebx, 6
    jb .toneLoop
    mov al, CMS_R_OCT01
    xor ah, ah
    call cms_wreg
    mov al, CMS_R_OCT23
    xor ah, ah
    call cms_wreg
    mov al, CMS_R_OCT45
    xor ah, ah
    call cms_wreg
    ; Second chip park (HI pair, inline: its latch is separate and the tick
    ; path never touches it, so c_lastaddr stays sound). Reset, zero every
    ; voice/noise/envelope register the first chip uses, leave SE=0 so the
    ; chip stays disabled whatever a previous program left behind.
    mov dx, CMS_ADDR_HI
    mov al, CMS_R_SE
    out dx, al
    mov dx, CMS_DATA_HI
    mov al, CMS_SE_RESET
    out dx, al
    mov esi, cms_park_regs
.parkLoop:
    mov al, [esi]
    cmp al, 0xFF
    je .parked
    mov dx, CMS_ADDR_HI
    out dx, al
    mov dx, CMS_DATA_HI
    xor al, al
    out dx, al
    inc esi
    jmp .parkLoop
.parked:
    mov dx, CMS_ADDR_HI
    mov al, CMS_R_SE
    out dx, al
    mov dx, CMS_DATA_HI
    xor al, al
    out dx, al
    call cms_silence            ; parks SE=0 with everything else
    mov al, CMS_R_SE            ; ... but init leaves the card enabled-but-quiet
    mov ah, CMS_SE_ENABLE
    call cms_wreg
    mov byte [c_lastse], CMS_SE_ENABLE
    popad
    ret

; cms_silence — leave the first chip fully quiet: SE=0 via $1C (all channels
; disabled, the [SAA] §8 power-up state), FE/NE off, amps $00-$05 zeroed
; (amp 0 is off even under envelope drive — the programmed level stays the
; ceiling, [SAA] §7 rule 2 — so the triangle voice dies too). Amp/FE/NE/SE
; caches sync to the silenced values so the next tick re-arms every live voice
; (KEY flags stay, like tandy_silence: voices resume on their next tick and
; re-key fully on their next restart — cms_commit_se restores SE=1 on change);
; tone/octave caches stay stale (FE=0 gates every voice, the silenced
; tone/octave bytes are still on the chip, and keyon forces their rewrite).
; An unselected card must not see port traffic, hence the g_cms_on gate.
; Future pre-clip hook (wired stage 2, this file only records the site):
; pikachu_pcm.asm PlayPikachuSoundClip calls cms_silence after its
; covox_silence call (pikachu_pcm.asm:90), with an extern beside line 51.
; Preserves all registers.
cms_silence:
    cmp byte [g_cms_on], 0
    jz .off
    push eax
    push ebx
    push edx
    push edi
    mov al, CMS_R_SE
    xor ah, ah                    ; SE=0 first: the cut lands immediately
    call cms_wreg
    mov byte [c_lastse], 0
    mov al, CMS_R_FE
    xor ah, ah
    call cms_wreg
    mov byte [c_lastfe], 0
    mov al, CMS_R_NE
    xor ah, ah
    call cms_wreg
    mov byte [c_lastne], 0
    mov edi, cms_state
    xor ebx, ebx
.ch:
    mov al, CMS_R_AMP0
    add al, bl
    xor ah, ah
    call cms_wreg
    cmp ebx, 4
    jae .next
    mov byte [edi + CMS_LASTAMP], 0
    add edi, CMS_SIZE
.next:
    inc ebx
    cmp ebx, 6
    jb .ch
    pop edi
    pop edx
    pop ebx
    pop eax
.off:
    ret

; cms_shutdown — leave the CMS silent on exit (tandy_shutdown shape: tail-jump
; to silence, which parks SE=0 with the amps/FE/NE). Preserves all registers.
cms_shutdown:
    jmp cms_silence

; ===========================================================================
; cms_pass — the per-tick APU mirror. Called from audio_tick (DelayFrame is
; pushad-wrapped, registers may be clobbered freely).
;   EBX = GB channel (0-3; the SAA channel index is the same number)
;   ESI = GB address of the channel's register file ($FF10 + ch*5)
;   EDI = its software voice state
; Shared SAA registers ($10/$11 octaves, $14 FE, $15 NE) compose after the
; loop from the per-voice caches, one write each on change.
; ===========================================================================
cms_pass:
    cmp byte [g_cms_on], 0
    jz .off
    ; master drop from NR50 (the louder terminal, like tandy/opl, so
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
    mov ah, 7
    sub ah, al                    ; drop = 7 - louder (0 at full volume)
    mov [c_master], ah
    mov al, [ebp + rAUDTERM]
    mov [c_nr51], al

    xor ebx, ebx
.chLoop:
    lea esi, [ebx*4 + ebx]
    add esi, 0xFF10               ; channel register base
    lea eax, [ebx + ebx*4]
    shl eax, 2                    ; ch * 20
    lea edi, [cms_state + eax]

    mov al, [ebp + esi + 4]       ; NRx4
    test al, 0x80
    jz .noRestart
    and al, 0x7F                  ; consume the restart bit
    mov [ebp + esi + 4], al
    call cms_keyon
    jmp .running
.noRestart:
    cmp byte [edi + CMS_KEY], 0
    jz .next
    ; frequency follow (engine vibrato / pitch slides / NR43 rewrites)
    mov cl, [ebp + esi + 3]
    mov ch, [ebp + esi + 4]
    and ch, 7
    cmp ebx, 3
    jnz .fcmp
    xor ch, ch                    ; noise: NR43 byte alone is the "frequency"
.fcmp:
    cmp cx, [edi + CMS_FREQ]
    je .running
    mov [edi + CMS_FREQ], cx
    call cms_setfreq
.running:
    cmp byte [edi + CMS_KEY], 0
    jz .next
    call cms_sweep
    call cms_envelope
    call cms_length
    call cms_volume
.next:
    inc ebx
    cmp ebx, 4
    jb .chLoop
    call cms_commit_octaves
    call cms_commit_enables
    call cms_commit_se
.off:
    ret

; ---------------------------------------------------------------------------
; cms_keyon — retrigger channel EBX from its APU registers (the same latch
; sequence as tandy_keyon). Forces the voice's amp/tone/octave caches so the
; volume+setfreq tail re-emits even on a same-note restrike; shared registers
; ($10/$11/$14/$15) need no forcing — a 0->1 gate bit composes differently on
; its own, and an unchanged shared byte is already correct on the chip.
; ---------------------------------------------------------------------------
cms_keyon:
    ; envelope from NRx2 (the wave channel has none — NR32 is a level; the
    ; latch below is harmless there, exactly like tandy_keyon)
    mov al, [ebp + esi + 2]
    mov ah, al
    shr ah, 4
    mov [edi + CMS_ENVVOL], ah
    mov ah, al
    shr ah, 3
    and ah, 1
    mov [edi + CMS_ENVDIR], ah
    and al, 7
    mov [edi + CMS_ENVPER], al
    mov word [edi + CMS_ENVACC], 0
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
    mov [edi + CMS_LEN], ax
    mov word [edi + CMS_LENACC], 0
    mov al, [ebp + esi + 4]
    and al, 0x40
    mov [edi + CMS_LENEN], al
    ; sweep latch (pulse 1 only)
    test ebx, ebx
    jnz .noSweep
    mov al, [ebp + rAUD1SWEEP]
    mov [edi + CMS_SWEEP], al
    mov word [edi + CMS_SWACC], 0
.noSweep:
    ; frequency snapshot
    mov cl, [ebp + esi + 3]
    mov ch, [ebp + esi + 4]
    and ch, 7
    cmp ebx, 3
    jnz .fstore
    xor ch, ch
.fstore:
    mov [edi + CMS_FREQ], cx
    mov byte [edi + CMS_KEY], 1
    mov byte [edi + CMS_LASTAMP], 0xFF
    mov word [edi + CMS_LASTTONE], 0xFFFF
    mov byte [edi + CMS_LASTOCT], 0xFF
    ; set the level before the frequency to avoid a burst at the old pitch
    call cms_volume
    jmp cms_setfreq

cms_keyoff:
    mov byte [edi + CMS_KEY], 0
    xor al, al                    ; amp 0 = off (change-checked in cms_setamp)
    jmp cms_setamp

; ---------------------------------------------------------------------------
; cms_setfreq — program voice EBX from CMS_FREQ. GB pulse: Hz =
; 131072/(2048-f); wave: 65536/(2048-f). SAA octave from the §3.1 bands
; (half-open, lo = 31<<k), Fn linear in the band (the v1 provisional map — see
; header). Tone $08+voice writes at once; the octave half waits for the
; post-loop compose (two voices share each octave byte). Noise (NR43,
; s=bits 7-4, r=bits 2-0): LFSR clock = 262144/r/2^(s+1), r=0 counts as 0.5,
; then the nearest $16 preset (31.3/15.6/7.6 kHz at midpoints 22097/10889 Hz).
; Writes only on change. Clobbers EAX ECX EDX.
; ---------------------------------------------------------------------------
cms_setfreq:
    cmp ebx, 3
    jz .noise
    movzx eax, word [edi + CMS_FREQ]
    mov ecx, 2048
    sub ecx, eax                  ; 2048-f >= 1 (f is 11-bit)
    mov eax, 131072
    cmp ebx, 2
    jnz .div
    shr eax, 1                    ; wave channel pitch
.div:
    xor edx, edx
    div ecx                       ; eax = GB Hz
    ; octave select, top-down over lo = 31<<k
    mov ecx, 7
    cmp eax, CMS_OCT_TOP          ; 3968
    jae .haveOct
    mov ecx, 6
    cmp eax, 1984
    jae .haveOct
    mov ecx, 5
    cmp eax, 992
    jae .haveOct
    mov ecx, 4
    cmp eax, 496
    jae .haveOct
    mov ecx, 3
    cmp eax, 248
    jae .haveOct
    mov ecx, 2
    cmp eax, 124
    jae .haveOct
    mov ecx, 1
    cmp eax, 62
    jae .haveOct
    xor ecx, ecx
.haveOct:                         ; ecx = octave, eax = Hz
    push ecx
    mov edx, CMS_OCT_BASE
    shl edx, cl                   ; lo = 31<<k
    mov ecx, edx
    shl eax, 8                    ; Hz*256 (Hz <= 131072: fits 32 bits)
    xor edx, edx
    div ecx                       ; (Hz*256)/lo
    sub eax, 256                  ; Fn linear in the band
    js .fnLo
    cmp eax, 255
    jbe .fnOk
    mov eax, 255
    jmp .fnOk
.fnLo:
    xor eax, eax
.fnOk:
    pop ecx                       ; ecx = octave
    cmp ax, [edi + CMS_LASTTONE]
    jne .toneNew
    cmp cl, [edi + CMS_LASTOCT]
    je .done
.toneNew:
    mov [edi + CMS_LASTTONE], ax
    mov [edi + CMS_LASTOCT], cl
    mov ah, al                    ; Fn byte
    mov al, CMS_R_TONE0
    add al, bl                    ; $08+voice (ch0-2 -> voices 1-3)
    call cms_wreg
.done:
    ret
.noise:
    mov al, [edi + CMS_FREQ]       ; NR43
    mov cl, al
    shr cl, 4
    inc cl                        ; s+1
    and eax, 7                    ; r (the AND also clears the stale high bits)
    jnz .noiseDiv
    mov eax, 524288               ; r=0 counts as 0.5
    shr eax, cl
    jmp .haveHz
.noiseDiv:
    shl eax, cl                   ; r * 2^(s+1)
    mov ecx, eax
    mov eax, 262144
    xor edx, edx
    div ecx                       ; eax = LFSR clock Hz
.haveHz:
    xor cl, cl                    ; colour 0: 31.3 kHz
    cmp eax, CMS_N_MID_HI
    jae .haveCol
    inc cl                        ; colour 1: 15.6 kHz
    cmp eax, CMS_N_MID_LO
    jae .haveCol
    inc cl                        ; colour 2: 7.6 kHz
.haveCol:
    cmp cl, [c_lastncol]
    je .ndone
    mov [c_lastncol], cl
    shl cl, 2                     ; high pair: noise generator 1 (voices 4-6)
    mov ah, cl                    ; low pair stays 0 (generator 0 unused)
    mov al, CMS_R_NCOL
    call cms_wreg
.ndone:
    ret

; ---------------------------------------------------------------------------
; cms_sweep — pulse-1 hardware sweep emulation (128 Hz base clock).
; Same math as tandy_sweep.
; ---------------------------------------------------------------------------
cms_sweep:
    test ebx, ebx
    jnz .done
    mov al, [edi + CMS_SWEEP]
    mov cl, al
    shr cl, 4
    and cl, 7                     ; period
    jz .done
    movzx eax, cl
    imul eax, 60
    movzx ecx, word [edi + CMS_SWACC]
    add ecx, 128
    cmp ecx, eax
    jb .store
    sub ecx, eax
    mov [edi + CMS_SWACC], cx
    ; f' = f +/- (f >> n)
    movzx eax, word [edi + CMS_FREQ]
    mov edx, eax
    mov cl, [edi + CMS_SWEEP]
    and cl, 7
    shr eax, cl
    test byte [edi + CMS_SWEEP], 8
    jnz .down
    add edx, eax
    cmp edx, 2048
    jb .apply
    jmp cms_keyoff              ; overflow silences the channel (GB rule)
.down:
    sub edx, eax
    jns .apply
    xor edx, edx
.apply:
    mov [edi + CMS_FREQ], dx
    jmp cms_setfreq
.store:
    mov [edi + CMS_SWACC], cx
.done:
    ret

; ---------------------------------------------------------------------------
; cms_envelope — GB volume envelope: one step per (period / 64) s.
; ---------------------------------------------------------------------------
cms_envelope:
    cmp ebx, 2
    je .done                      ; wave channel has no envelope
    mov al, [edi + CMS_ENVPER]
    test al, al
    jz .done
    movzx ecx, al
    imul ecx, 60
    movzx eax, word [edi + CMS_ENVACC]
    add eax, 64
    cmp eax, ecx
    jb .store
    sub eax, ecx
    mov cl, [edi + CMS_ENVVOL]
    cmp byte [edi + CMS_ENVDIR], 0
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
    mov [edi + CMS_ENVVOL], cl
.store:
    mov [edi + CMS_ENVACC], ax
.done:
    ret

; ---------------------------------------------------------------------------
; cms_length — GB length counter: 256 Hz countdown, key-off at zero.
; ---------------------------------------------------------------------------
cms_length:
    cmp byte [edi + CMS_LENEN], 0
    jz .done
    movzx eax, word [edi + CMS_LENACC]
    add eax, 256
    movzx ecx, word [edi + CMS_LEN]
.step:
    cmp eax, 60
    jb .save
    sub eax, 60
    dec ecx
    jnz .step
    ; expired
    mov word [edi + CMS_LEN], 0
    mov byte [edi + CMS_LENEN], 0
    mov [edi + CMS_LENACC], ax
    jmp cms_keyoff
.save:
    mov [edi + CMS_LEN], cx
    mov [edi + CMS_LENACC], ax
.done:
    ret

; ---------------------------------------------------------------------------
; cms_volume — amp = base level - master drop, written on change. A channel
; with both NR51 bits clear is force-muted (rests/ducks). The wave voice maps
; NR32 through CmsWaveAmp and drops its LSB (envelope drive halves resolution
; to 8 levels); its 7/8 active cap ([SAA] §7) is hardware, not shimmed.
; ---------------------------------------------------------------------------
cms_volume:
    cmp ebx, 2
    je .wave
    movzx eax, byte [edi + CMS_ENVVOL]
    jmp .att
.wave:
    mov al, [ebp + rAUD3ENA]
    test al, 0x80                 ; wave DAC off -> silent
    jz .mute
    mov al, [ebp + rAUD3LEVEL]
    shr al, 5
    and eax, 3
    mov al, [CmsWaveAmp + eax]
.att:
    sub al, [c_master]            ; louder-side offset; borrow = below silent
    jb .mute
    ; NR51: both terminal bits clear -> mute
    mov cl, bl
    mov ah, 0x11
    shl ah, cl
    test [c_nr51], ah
    jz .mute
    ; MIDI mode: the MT-32/GM stream carries the music, so a GB channel
    ; only voices on the CMS while an SFX owns it (wChannelSoundIDs CHAN5-8)
    cmp byte [g_midi_music], 0
    jz .cap
    cmp byte [ebp + wChannelSoundIDs + CHAN5 + ebx], 0
    jnz .cap
.mute:
    xor al, al
.cap:
    cmp ebx, 2
    jne cms_setamp
    and al, 0xFE                  ; envelope drive: even levels only
    jmp cms_setamp

; cms_setamp — write amp nibble AL (0-15, 0 = off) to voice EBX ($00+EBX,
; duplicated to both stereo nibbles), on change. Clobbers EAX EDX.
cms_setamp:
    cmp al, [edi + CMS_LASTAMP]
    je .done
    mov [edi + CMS_LASTAMP], al
    mov ah, al
    shl al, 4
    or al, ah                     ; mono: same level both sides
    mov ah, al
    mov al, CMS_R_AMP0
    add al, bl
    call cms_wreg
.done:
    ret

; ---------------------------------------------------------------------------
; cms_commit_octaves — compose the shared octave bytes from the per-voice
; caches ($10 = v1<<4|v0, $11 low = v2; the $11 high half and $12 stay 0: the
; noise voice programs no tone and voices 5-6 are unused), one write each on
; change. Keyon always flows through cms_setfreq before this commit, so a
; force-marker can never leak into the composed byte.
; ---------------------------------------------------------------------------
cms_commit_octaves:
    mov al, [cms_state + 1*CMS_SIZE + CMS_LASTOCT]
    shl al, 4
    or al, [cms_state + 0*CMS_SIZE + CMS_LASTOCT]
    cmp al, [c_lastoct10]
    je .second
    mov [c_lastoct10], al
    mov ah, al
    mov al, CMS_R_OCT01
    call cms_wreg
.second:
    mov al, [cms_state + 2*CMS_SIZE + CMS_LASTOCT]
    cmp al, [c_lastoct11]
    je .done
    mov [c_lastoct11], al
    mov ah, al
    mov al, CMS_R_OCT23
    call cms_wreg
.done:
    ret

; ---------------------------------------------------------------------------
; cms_commit_enables — compose $14/$15 from the key states (FE bits 0-1 = the
; pulse voices; voice 3 stays FE=0 for envelope-itself mode, voice 4 stays
; FE=0 for noise-only, voices 5-6 unused. NE bit 3 = noise voice key).
; One write each on change.
; ---------------------------------------------------------------------------
cms_commit_enables:
    xor al, al
    cmp byte [cms_state + 0*CMS_SIZE + CMS_KEY], 0
    jz .fe1
    or al, 1
.fe1:
    cmp byte [cms_state + 1*CMS_SIZE + CMS_KEY], 0
    jz .feDone
    or al, 2
.feDone:
    cmp al, [c_lastfe]
    je .ne
    mov [c_lastfe], al
    mov ah, al
    mov al, CMS_R_FE
    call cms_wreg
.ne:
    xor al, al
    cmp byte [cms_state + 3*CMS_SIZE + CMS_KEY], 0
    jz .neDone
    mov al, 8
.neDone:
    cmp al, [c_lastne]
    je .done
    mov [c_lastne], al
    mov ah, al
    mov al, CMS_R_NE
    call cms_wreg
.done:
    ret

; ---------------------------------------------------------------------------
; cms_commit_se — re-arm $1C SE=1 while the shim is ticking (cms_silence parks
; SE=0; the first tick after it restores the enable on change vs c_lastse, so
; a silenced voice resumes without needing a re-key). One write per silence,
; then quiet. Clobbers EAX EDX.
; ---------------------------------------------------------------------------
cms_commit_se:
    cmp byte [c_lastse], CMS_SE_ENABLE
    je .done
    mov byte [c_lastse], CMS_SE_ENABLE
    mov ah, CMS_SE_ENABLE
    mov al, CMS_R_SE
    call cms_wreg
.done:
    ret

; ---------------------------------------------------------------------------
; cms_dbg_snapshot — provisional 4-byte block at CMS_SNAP (+0x89..+0x8C):
;   +0x89 g_cms_on  +0x8A v0|v1 last amps (hi|lo nibble)
;   +0x8B v2|v3 last amps  +0x8C last FE | last NE
; mpu401 shape (mov al/mov [ebp+...] stores, EAX only). The debug_dump window
; extension that dumps these bytes stays stage 2/3 (this file cannot touch it).
; In: EBP = GB memory base. Clobbers EAX.
; ---------------------------------------------------------------------------
cms_dbg_snapshot:
    mov al, [g_cms_on]
    mov [ebp + (CMS_SNAP + 0)], al
    mov al, [cms_state + 0*CMS_SIZE + CMS_LASTAMP]
    shl al, 4
    or al, [cms_state + 1*CMS_SIZE + CMS_LASTAMP]
    mov [ebp + (CMS_SNAP + 1)], al
    mov al, [cms_state + 2*CMS_SIZE + CMS_LASTAMP]
    shl al, 4
    or al, [cms_state + 3*CMS_SIZE + CMS_LASTAMP]
    mov [ebp + (CMS_SNAP + 2)], al
    mov al, [c_lastfe]
    or al, [c_lastne]
    mov [ebp + (CMS_SNAP + 3)], al
    ret

section .data

g_cms_on:     db 0              ; /GB selected + cms_init ran

; NR32 level -> SAA amp nibble (mute/full/half/quarter). Linear v1 map, inline
; (the InnovaWaveSUS inline precedent — too small for a generator); the 1.3 ear
; pass judges whether GB loudness needs a perceptual table like tandy's.
CmsWaveAmp:   db 0, 15, 8, 4

; Second-chip park list (cms_init): every register the first chip uses, plus
; the 0xFF terminator. A register table is code, not a string (Tier-2 by kind).
cms_park_regs:
    db 0x14, 0x15, 0x16, 0x18, 0x19
    db 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0xFF

section .bss

cms_state:    resb 4 * CMS_SIZE  ; ch0-3 voices (SAA channel index = GB channel)
c_lastaddr:   resb 1            ; last latched SAA address, LO pair (0xFF = unknown)
c_lastfe:     resb 1            ; last $14 byte (0xFF = force)
c_lastne:     resb 1            ; last $15 byte (0xFF = force)
c_lastse:     resb 1            ; last $1C byte (0xFF = force)
c_lastoct10:  resb 1            ; last $10 byte (0xFF = force)
c_lastoct11:  resb 1            ; last $11 byte (0xFF = force)
c_lastncol:   resb 1            ; last noise colour 0-2 (0xFF = force)
c_master:     resb 1            ; NR50 louder-side drop 0-7
c_nr51:       resb 1            ; NR51 snapshot for this tick

%else

section .text
cms_init:
cms_pass:
cms_silence:
cms_shutdown:
cms_dbg_snapshot:
    ret

section .data
g_cms_on:     db 0

%endif
