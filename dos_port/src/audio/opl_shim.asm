; opl_shim.asm — virtual APU → OPL2/OPL3 device shim (port-only HAL layer).
;
; Once per audio tick (audio_hal.asm, after Audio1_UpdateMusic) opl_pass reads
; the 4 GB hardware channels' registers from the virtual APU block at
; [ebp+$FF10..$FF26] and mirrors them onto OPL voices 0-3 at port 388h:
;
;   GB ch0 pulse1  -> OPL voice 0   patch = duty variant 0-3 (NRx1 bits 7-6)
;   GB ch1 pulse2  -> OPL voice 1   patch = duty variant 0-3
;   GB ch2 wave    -> OPL voice 2   patch 4; NR32 level as attenuation
;   GB ch3 noise   -> OPL voice 3   patch 5; pitch from the NR43 divisor
;
; The engine leaves NRx4 bit 7 (restart) set; the shim CONSUMES it (clears the
; bit in the virtual APU) and retriggers the FM voice — the engine never reads
; it back (verified in the plan audit). What the OPL cannot do in hardware is
; emulated in software per tick, in GB units:
;   - envelope  (NRx2: initial vol 0-15, direction, period n -> 64/n Hz steps)
;   - sweep     (NR10, pulse1 only: period p -> 128/p Hz, f +/- f>>n,
;                overflow past 2047 keys the voice off — the pokeball SFX arc)
;   - length    (NRx1/NRx4 bit 6: 256 Hz countdown -> key-off)
;   - master    (NR50 louder side -> extra attenuation; fades come through
;                FadeOutAudio's rAUDVOL writes for free)
;   - panning   (NR51 -> OPL3 C0 CHA/CHB bits; on any chip a channel with
;                both NR51 bits clear is force-muted via TL — this is how the
;                engine's rest/duck writes become silence)
; Volume path: TL = patch carrier base + OplVolTable[vol] + master (+ NR32
; level for the wave voice), clamped to 63. Carrier TL is rewritten on change
; only. Patches/attenuation tables are Tier-1 data (assets/opl_patches.inc,
; hand-tuned in tools/audio/gen_opl_patches.py).
;
; opl_init runs the classic AdLib timer detection at 388h, then the OPL2-vs-
; OPL3 status probe (status bits 1-2: $06 = OPL2, $00 = OPL3, per
; docs/sound/OPL3_YMF262.md); on OPL3 it sets NEW (reg $105) so waveforms and
; stereo work. All register writes use OPL2-safe delays (6/35 status reads).
; No OPL found -> g_opl_present stays 0 and every entry point no-ops (the
; engine still runs; there is just no device).

%include "gb_memmap.inc"

global opl_init
global opl_shutdown
global opl_silence
global opl_pass
global opl_dbg_snapshot
global g_opl_present
global g_opl3
; shared with the tier-1 enhancement player (src/audio/opl_enh.asm)
global opl_write
global opl_write_hi
global OplPatches
global OplSlotMod
global OplRegGroups
global OplMasterAttTable

extern g_midi_music               ; src/audio/mpu401.asm — MIDI mode active
extern g_sb_present               ; src/audio/audio_hal.asm (BLASTER/DSP probe)
extern g_sb_base
extern g_sb_dsp_ver
extern g_sb_irq
extern g_sb_dma

section .text

OPL_BASE      equ 0x388

; --- per-voice software state --------------------------------------------
VS_FREQ       equ 0    ; word: GB 11-bit freq (ch3: NR43 byte) incl. sweep
VS_B0         equ 2    ; byte: last B0 value written (incl. key bit)
VS_KEY        equ 3    ; byte: key-on flag
VS_PATCH      equ 4    ; byte: loaded patch id (0xFF = none)
VS_ENVVOL     equ 5    ; byte: current GB volume 0-15
VS_ENVDIR     equ 6    ; byte: envelope direction (1 = up)
VS_ENVPER     equ 7    ; byte: envelope period (0 = off)
VS_ENVACC     equ 8    ; word: envelope accumulator (64/tick vs 60*period)
VS_LEN        equ 10   ; word: length counter (1/256 s units)
VS_LENACC     equ 12   ; word: length accumulator (256/tick vs 60)
VS_LENEN      equ 14   ; byte: length enable (NRx4 bit 6)
VS_SWEEP      equ 15   ; byte: NR10 latched at key-on (ch0 only)
VS_SWACC      equ 16   ; word: sweep accumulator (128/tick vs 60*period)
VS_PAN        equ 18   ; byte: last written pan bits ($10 L | $20 R)
VS_C0         equ 19   ; byte: patch C0 base (feedback/connection)
VS_BASETL     equ 20   ; byte: patch carrier TL base (0-63)
VS_KSL        equ 21   ; byte: patch carrier KSL bits ($C0 mask)
VS_LAST40     equ 22   ; byte: last carrier $40 value written
VS_SIZE       equ 24

; ===========================================================================
; opl_write — write AL to OPL register AH at OPL_BASE, with OPL2-safe delays
; (3.3 µs after address, 23 µs after data, via status-port reads).
; Preserves all registers.
; ===========================================================================
opl_write:
    push eax
    push ebx
    push ecx
    push edx
    mov bl, al                  ; value
    mov bh, ah                  ; register index
    mov dx, OPL_BASE
    mov al, bh
    out dx, al
    mov ecx, 6
.adelay:
    in al, dx
    loop .adelay
    inc dx
    mov al, bl
    out dx, al
    dec dx
    mov ecx, 35
.ddelay:
    in al, dx
    loop .ddelay
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

; opl_write_hi — same, to the OPL3 second register bank (38Ah/38Bh).
opl_write_hi:
    push eax
    push ebx
    push ecx
    push edx
    mov bl, al
    mov bh, ah
    mov dx, OPL_BASE + 2
    mov al, bh
    out dx, al
    mov ecx, 6
.adelay:
    in al, dx
    loop .adelay
    inc dx
    mov al, bl
    out dx, al
    sub dx, 3                   ; delays read the base status port
    mov ecx, 35
.ddelay:
    in al, dx
    loop .ddelay
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

; ===========================================================================
; opl_init — detect an OPL at 388h, probe OPL2 vs OPL3, put the chip in a
; clean melodic-mode state. Preserves all registers.
; ===========================================================================
opl_init:
    pushad
    ; classic AdLib timer detection
    mov ax, 0x0460
    call opl_write              ; mask both timers
    mov ax, 0x0480
    call opl_write              ; reset timer IRQ flags
    mov dx, OPL_BASE
    in al, dx
    and al, 0xE0
    mov bl, al                  ; status with timers reset (must be 0)
    mov ax, 0x02FF
    call opl_write              ; timer 1 latch = $FF (80 µs to overflow)
    mov ax, 0x0421
    call opl_write              ; start timer 1
    mov ecx, 130                ; ~130 ISA reads ≈ >100 µs
.wait:
    in al, dx
    loop .wait
    in al, dx
    and al, 0xE0
    mov bh, al                  ; status after overflow (must be $C0)
    mov ax, 0x0460
    call opl_write
    mov ax, 0x0480
    call opl_write
    test bl, bl
    jnz .done                   ; pre-status dirty: no OPL
    cmp bh, 0xC0
    jnz .done                   ; timer never fired: no OPL
    mov byte [g_opl_present], 1
    ; OPL2 vs OPL3: status bits 1-2 read $06 on OPL2, $00 on OPL3
    in al, dx
    and al, 0x06
    jnz .haveGen
    mov byte [g_opl3], 1
    mov ax, 0x0501              ; reg $105 NEW=1: enable OPL3 features
    call opl_write_hi
    mov ax, 0x0400              ; reg $104: no 4-op pairs
    call opl_write_hi
.haveGen:
    mov ax, 0x0120              ; waveform select enable (OPL2; reserved on OPL3)
    call opl_write
    mov ax, 0x0800              ; CSM / note-select off
    call opl_write
    mov ax, 0xBD00              ; rhythm mode off, AM/VIB depth low
    call opl_write
    call opl_silence
    ; reset software voice state
    mov ecx, 4 * VS_SIZE
    mov edi, voice_state
.clr:
    mov byte [edi], 0
    inc edi
    loop .clr
    mov edi, voice_state
    mov ecx, 4
.vinit:
    mov byte [edi + VS_PATCH], 0xFF
    mov byte [edi + VS_LAST40], 0xFF
    add edi, VS_SIZE
    loop .vinit
.done:
    popad
    ret

; key off all 9 voices and pull every operator to max attenuation. Safe with
; no OPL present. Exported for PlayPikachuSoundClip: the shim's software
; envelopes freeze during the cli PCM clip (the GB's *hardware* envelopes
; kept decaying through its freeze), so held notes must be cut. opl_pass
; restores TL every tick; a cut voice re-keys on its next note-on.
opl_silence:
    cmp byte [g_opl_present], 0
    jz .absent
    push eax
    push ecx
    mov ah, 0xB0
    mov ecx, 9
.koff:
    xor al, al
    call opl_write
    inc ah
    loop .koff
    mov ah, 0x40
    mov ecx, 22                 ; slots 0-21 (gaps are harmless no-ops)
.tl:
    mov al, 0x3F
    call opl_write
    inc ah
    loop .tl
    pop ecx
    pop eax
.absent:
    ret

; opl_shutdown — leave the chip silent on exit. Preserves all registers.
opl_shutdown:
    cmp byte [g_opl_present], 0
    jz .off
    call opl_silence
.off:
    ret

; ===========================================================================
; opl_pass — the per-tick APU mirror. Called from audio_tick (DelayFrame is
; pushad-wrapped, registers may be clobbered freely).
;   EBX = GB channel / OPL voice (0-3)
;   ESI = GB address of the channel's register file ($FF10 + ch*5)
;   EDI = its software voice state
; ===========================================================================
opl_pass:
    cmp byte [g_opl_present], 0
    jz .off
    ; master attenuation from NR50 (the louder of the two terminals, so
    ; FadeOutAudio's simultaneous L/R ramp maps to a single TL ramp)
    mov al, [ebp + rAUDVOL]
    mov ah, al
    shr ah, 4
    and ah, 7
    and al, 7
    cmp al, ah
    jae .m1
    mov al, ah
.m1:
    movzx eax, al
    mov al, [OplMasterAttTable + eax]
    mov [master_att], al
    mov al, [ebp + rAUDTERM]
    mov [nr51_snap], al

    xor ebx, ebx
.chLoop:
    lea esi, [ebx*4 + ebx]
    add esi, 0xFF10             ; channel register base
    lea eax, [ebx + ebx*2]
    shl eax, 3                  ; ch * 24
    lea edi, [voice_state + eax]

    mov al, [ebp + esi + 4]     ; NRx4
    test al, 0x80
    jz .noRestart
    and al, 0x7F                ; consume the restart bit
    mov [ebp + esi + 4], al
    call voice_keyon
    jmp .running
.noRestart:
    cmp byte [edi + VS_KEY], 0
    jz .next
    ; frequency follow (engine vibrato / pitch slides / NR43 rewrites)
    mov cl, [ebp + esi + 3]
    mov ch, [ebp + esi + 4]
    and ch, 7
    cmp ebx, 3
    jnz .fcmp
    xor ch, ch                  ; noise: NR43 byte alone is the "frequency"
.fcmp:
    cmp cx, [edi + VS_FREQ]
    je .fsame
    mov [edi + VS_FREQ], cx
    call voice_setfreq
.fsame:
    ; duty follow (pulse channels; the rotate_duty cry effect)
    cmp ebx, 2
    jae .running
    mov al, [ebp + esi + 1]
    shr al, 6
    cmp al, [edi + VS_PATCH]
    je .running
    call voice_loadpatch
.running:
    cmp byte [edi + VS_KEY], 0
    jz .next
    call voice_sweep
    call voice_envelope
    call voice_length
    call voice_volume
    call voice_pan
.next:
    inc ebx
    cmp ebx, 4
    jb .chLoop
.off:
    ret

; ---------------------------------------------------------------------------
; voice_keyon — retrigger voice EBX from its APU registers.
; ---------------------------------------------------------------------------
voice_keyon:
    ; patch select
    cmp ebx, 2
    jb .pulse
    mov al, 4                   ; wave
    jz .have
    mov al, 5                   ; noise
    jmp .have
.pulse:
    mov al, [ebp + esi + 1]
    shr al, 6                   ; duty 0-3
.have:
    call voice_loadpatch
    ; envelope from NRx2 (the wave channel has none — NR32 is a level)
    mov al, [ebp + esi + 2]
    mov ah, al
    shr ah, 4
    mov [edi + VS_ENVVOL], ah
    mov ah, al
    shr ah, 3
    and ah, 1
    mov [edi + VS_ENVDIR], ah
    and al, 7
    mov [edi + VS_ENVPER], al
    mov word [edi + VS_ENVACC], 0
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
    mov [edi + VS_LEN], ax
    mov word [edi + VS_LENACC], 0
    mov al, [ebp + esi + 4]
    and al, 0x40
    mov [edi + VS_LENEN], al
    ; sweep latch (pulse 1 only)
    test ebx, ebx
    jnz .noSweep
    mov al, [ebp + rAUD1SWEEP]
    mov [edi + VS_SWEEP], al
    mov word [edi + VS_SWACC], 0
.noSweep:
    ; frequency snapshot
    mov cl, [ebp + esi + 3]
    mov ch, [ebp + esi + 4]
    and ch, 7
    cmp ebx, 3
    jnz .fstore
    xor ch, ch
.fstore:
    mov [edi + VS_FREQ], cx
    ; set level/pan before keying to avoid a burst at the wrong volume
    call voice_volume
    call voice_pan
    ; retrigger: key off (if keyed), then on
    mov al, [edi + VS_B0]
    and al, 0x1F
    mov ah, 0xB0
    add ah, bl
    call opl_write
    mov byte [edi + VS_KEY], 1
    jmp voice_setfreq           ; writes A0 + B0 with the key bit set

; ---------------------------------------------------------------------------
; voice_setfreq — program A0/B0 for voice EBX from VS_FREQ (+ VS_KEY).
; GB pulse: Hz = 131072/(2048-f); wave: 65536/(2048-f);
; noise (NR43, s=bits 7-4, r=bits 2-0): Hz = 262144/r/2^(s+1), r=0 -> r=0.5.
; OPL: fnum = Hz * 2^(20-block) / 49716, normalized into block 0-7.
; Clobbers EAX ECX EDX.
; ---------------------------------------------------------------------------
voice_setfreq:
    cmp ebx, 3
    jz .noise
    movzx eax, word [edi + VS_FREQ]
    mov ecx, 2048
    sub ecx, eax
    mov eax, 131072
    cmp ebx, 2
    jnz .div
    shr eax, 1                  ; wave channel: one octave lower
.div:
    xor edx, edx
    div ecx
    jmp .haveHz
.noise:
    mov al, [edi + VS_FREQ]
    mov cl, al
    shr cl, 4
    inc cl                      ; s+1
    and eax, 7                  ; r
    jnz .noiseDiv
    mov eax, 524288             ; r=0 counts as 0.5
    shr eax, cl
    jmp .haveHz
.noiseDiv:
    shl eax, cl                 ; r * 2^(s+1)
    mov ecx, eax
    mov eax, 262144
    xor edx, edx
    div ecx
.haveHz:
    ; Hz -> fnum/block: start at block 7, halve block while fnum < 512
    shl eax, 13                 ; * 2^(20-7)
    xor edx, edx
    mov ecx, 49716
    div ecx
    mov cl, 7
.norm:
    cmp eax, 1024
    jb .fit
    mov eax, 1023               ; ultrasonic: clamp
    jmp .haveBlk
.fit:
    cmp eax, 512
    jae .haveBlk
    test cl, cl
    jz .haveBlk
    shl eax, 1
    dec cl
    jmp .norm
.haveBlk:
    mov ch, al                  ; fnum low byte
    shr eax, 8
    shl cl, 2
    or al, cl                   ; block<<2 | fnum hi
    cmp byte [edi + VS_KEY], 0
    jz .noKey
    or al, 0x20
.noKey:
    mov [edi + VS_B0], al
    mov cl, al                  ; B0 value
    mov al, ch
    mov ah, 0xA0
    add ah, bl
    call opl_write              ; fnum low
    mov al, cl
    mov ah, 0xB0
    add ah, bl
    call opl_write              ; key | block | fnum hi
    ret

voice_keyoff:
    mov al, [edi + VS_B0]
    and al, 0x1F
    mov [edi + VS_B0], al
    mov ah, 0xB0
    add ah, bl
    call opl_write
    mov byte [edi + VS_KEY], 0
    ret

; ---------------------------------------------------------------------------
; voice_loadpatch — load patch AL (0-5) onto voice EBX if not already there.
; Clobbers EAX ECX EDX.
; ---------------------------------------------------------------------------
voice_loadpatch:
    cmp al, [edi + VS_PATCH]
    je .done
    mov [edi + VS_PATCH], al
    push esi
    push ebx
    movzx esi, al
    imul esi, OPL_PATCH_SIZE
    add esi, OplPatches
    mov bh, [OplSlotMod + ebx]  ; modulator slot offset for this voice
    xor ecx, ecx                ; reg-group index 0-4
.ops:
    mov ah, [OplRegGroups + ecx]
    add ah, bh                  ; modulator register
    mov al, [esi + ecx]
    call opl_write
    add ah, 3                   ; carrier register (slot+3)
    mov al, [esi + ecx + 5]
    call opl_write
    inc ecx
    cmp ecx, 5
    jb .ops
    pop ebx
    ; cache the carrier level split + C0 base
    mov al, [esi + 6]           ; carrier $40 byte
    mov ah, al
    and al, 0x3F
    mov [edi + VS_BASETL], al
    and ah, 0xC0
    mov [edi + VS_KSL], ah
    mov al, [esi + 10]
    mov [edi + VS_C0], al
    pop esi
    mov byte [edi + VS_LAST40], 0xFF   ; force a level rewrite
    mov al, [edi + VS_PAN]
    or al, [edi + VS_C0]
    mov ah, 0xC0
    add ah, bl
    call opl_write
.done:
    ret

; ---------------------------------------------------------------------------
; voice_sweep — pulse-1 hardware sweep emulation (128 Hz base clock).
; ---------------------------------------------------------------------------
voice_sweep:
    test ebx, ebx
    jnz .done
    mov al, [edi + VS_SWEEP]
    mov cl, al
    shr cl, 4
    and cl, 7                   ; period
    jz .done
    movzx eax, cl
    imul eax, 60
    movzx ecx, word [edi + VS_SWACC]
    add ecx, 128
    cmp ecx, eax
    jb .store
    sub ecx, eax
    mov [edi + VS_SWACC], cx
    ; f' = f +/- (f >> n)
    movzx eax, word [edi + VS_FREQ]
    mov edx, eax
    mov cl, [edi + VS_SWEEP]
    and cl, 7
    shr eax, cl
    test byte [edi + VS_SWEEP], 8
    jnz .down
    add edx, eax
    cmp edx, 2048
    jb .apply
    jmp voice_keyoff            ; overflow silences the channel (GB rule)
.down:
    sub edx, eax
    jns .apply
    xor edx, edx
.apply:
    mov [edi + VS_FREQ], dx
    jmp voice_setfreq
.store:
    mov [edi + VS_SWACC], cx
.done:
    ret

; ---------------------------------------------------------------------------
; voice_envelope — GB volume envelope: one step per (period / 64) s.
; ---------------------------------------------------------------------------
voice_envelope:
    cmp ebx, 2
    je .done                    ; wave channel has no envelope
    mov al, [edi + VS_ENVPER]
    test al, al
    jz .done
    movzx ecx, al
    imul ecx, 60
    movzx eax, word [edi + VS_ENVACC]
    add eax, 64
    cmp eax, ecx
    jb .store
    sub eax, ecx
    mov cl, [edi + VS_ENVVOL]
    cmp byte [edi + VS_ENVDIR], 0
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
    mov [edi + VS_ENVVOL], cl
.store:
    mov [edi + VS_ENVACC], ax
.done:
    ret

; ---------------------------------------------------------------------------
; voice_length — GB length counter: 256 Hz countdown, key-off at zero.
; ---------------------------------------------------------------------------
voice_length:
    cmp byte [edi + VS_LENEN], 0
    jz .done
    movzx eax, word [edi + VS_LENACC]
    add eax, 256
    movzx ecx, word [edi + VS_LEN]
.step:
    cmp eax, 60
    jb .save
    sub eax, 60
    dec ecx
    jnz .step
    ; expired
    mov word [edi + VS_LEN], 0
    mov byte [edi + VS_LENEN], 0
    mov [edi + VS_LENACC], ax
    jmp voice_keyoff
.save:
    mov [edi + VS_LEN], cx
    mov [edi + VS_LENACC], ax
.done:
    ret

; ---------------------------------------------------------------------------
; voice_volume — carrier TL = base + envelope/level + master, written on
; change. A channel with both NR51 bits clear is force-muted (rests/ducks).
; ---------------------------------------------------------------------------
voice_volume:
    cmp ebx, 2
    je .wave
    movzx eax, byte [edi + VS_ENVVOL]
    mov al, [OplVolTable + eax]
    jmp .att
.wave:
    mov al, [ebp + rAUD3ENA]
    test al, 0x80               ; wave DAC off -> silent
    jz .mute
    mov al, [ebp + rAUD3LEVEL]
    shr al, 5
    and eax, 3
    mov al, [OplWaveLevelAtt + eax]
.att:
    add al, [master_att]
    ; NR51: both terminal bits clear -> mute
    mov cl, bl
    mov ah, 0x11
    shl ah, cl
    test [nr51_snap], ah
    jz .mute
    ; MIDI mode: the MT-32/GM stream carries the music, so a GB channel
    ; only voices on FM while an SFX owns it (wChannelSoundIDs CHAN5-8)
    cmp byte [g_midi_music], 0
    jz .clamp
    cmp byte [ebp + wChannelSoundIDs + CHAN5 + ebx], 0
    jnz .clamp
.mute:
    mov al, 63
.clamp:
    cmp al, 63
    jb .base
    mov al, 63
.base:
    add al, [edi + VS_BASETL]
    cmp al, 63
    jb .ksl
    mov al, 63
.ksl:
    or al, [edi + VS_KSL]
    cmp al, [edi + VS_LAST40]
    je .done
    mov [edi + VS_LAST40], al
    mov ah, [OplSlotMod + ebx]
    add ah, 0x40 + 3            ; carrier level register
    call opl_write
.done:
    ret

; ---------------------------------------------------------------------------
; voice_pan — NR51 terminal bits -> OPL3 C0 CHA(L)/CHB(R), written on change.
; Ignored by an OPL2 (bits are don't-care there; muting is TL-based above).
; ---------------------------------------------------------------------------
voice_pan:
    mov al, [nr51_snap]
    mov cl, bl
    shr al, cl
    xor ah, ah
    test al, 0x01               ; NR51 low nibble = right terminal
    jz .noR
    or ah, 0x20                 ; C0 CHB = right
.noR:
    test al, 0x10               ; NR51 high nibble = left terminal
    jz .noL
    or ah, 0x10                 ; C0 CHA = left
.noL:
    cmp ah, [edi + VS_PAN]
    je .done
    mov [edi + VS_PAN], ah
    mov al, [edi + VS_C0]
    or al, ah
    mov ah, 0xC0
    add ah, bl
    call opl_write
.done:
    ret

; ---------------------------------------------------------------------------
; opl_dbg_snapshot — copy detection flags + the first voices' software state
; into GB scratch at $D1E0 so the DEBUG_AUDIO DUMP.BIN can carry them.
; Layout: $D1E0 g_opl_present, +1 g_opl3, +2.. voice_state[0..61];
;         $D220 g_sb_present, +1 g_sb_base (word), +3 dsp ver (word, maj hi),
;         +5 g_sb_irq, +6 g_sb_dma.
; ---------------------------------------------------------------------------
opl_dbg_snapshot:
    push esi
    push edi
    push ecx
    mov al, [g_opl_present]
    mov [ebp + 0xD1E0], al
    mov al, [g_opl3]
    mov [ebp + 0xD1E1], al
    mov esi, voice_state
    mov edi, 0xD1E2
    mov ecx, 62
.copy:
    mov al, [esi]
    mov [ebp + edi], al
    inc esi
    inc edi
    loop .copy
    mov al, [g_sb_present]
    mov [ebp + 0xD220], al
    mov ax, [g_sb_base]
    mov [ebp + 0xD221], al
    mov [ebp + 0xD222], ah
    mov ax, [g_sb_dsp_ver]
    mov [ebp + 0xD223], al          ; minor
    mov [ebp + 0xD224], ah          ; major
    mov al, [g_sb_irq]
    mov [ebp + 0xD225], al
    mov al, [g_sb_dma]
    mov [ebp + 0xD226], al
    pop ecx
    pop edi
    pop esi
    ret

section .data

g_opl_present:  db 0
g_opl3:         db 0

; modulator slot offset per melodic voice 0-8 (carrier = +3)
OplSlotMod:
    db 0x00, 0x01, 0x02, 0x08, 0x09, 0x0A, 0x10, 0x11, 0x12

; the five per-operator register groups, in patch byte order
OplRegGroups:
    db 0x20, 0x40, 0x60, 0x80, 0xE0

%include "assets/opl_patches.inc"

section .bss

voice_state:    resb 4 * VS_SIZE
master_att:     resb 1
nr51_snap:      resb 1
