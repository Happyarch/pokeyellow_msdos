; pas_shim.asm — virtual APU → Pro Audio Spectrum 16 device shim (port-only HAL layer).
;
; Port-only module (no pret counterpart; this file has no GB original and is
; owned by the DOS audio HAL, wired in stage G2 from audio_tick/audio_init).
;
; The PAS16 carries its OPL3 at the card base (base 0x388: base+0/+1 bank-0
; address/data, base+2/+3 bank-1 address/data — the oracle port decode answers
; reads and writes at those four offsets with its FM drivers, plus a
; write-both alias at base+0x400 the driver never uses). Once per audio tick
; pas_pass reads the 4 GB channels from the virtual APU block at
; [ebp+$FF10..$FF26] and mirrors them onto the card's OPL3 at PAS_BASE,
; voicing FM the same way opl_shim voices the SB OPL at 0x388:
;
;   GB ch0 pulse1  -> OPL voice 0   patch = duty variant 0-3 (NRx1 bits 7-6)
;   GB ch1 pulse2  -> OPL voice 1   patch = duty variant 0-3
;   GB ch2 wave    -> OPL voice 2   patch 4; NR32 level as attenuation
;   GB ch3 noise   -> OPL voice 3   patch 5; pitch from the NR43 divisor
;
; Noise-path choice: the PAS PCM route (F88/F89 sample bytes, F8A control with
; the bit-6 PCM enable, the 1388 PIT rate generator, IRQ/DMA delivery) is a
; DMA-driven sample engine with no simple CPU-programmed noise register, so a
; G1 tick cannot tickle noise out of it with bare OUTs. The OPL noise voice
; reuses the proven opl voice-3 shape at the PAS base instead: zero new
; hardware programming, silence-is-silent now, and the same GB-unit pitch
; formula (262144/r/2^(s+1), r=0 counts as 0.5). A PCM voice, if ever wanted,
; is a later stage with fork DMA/IRQ plumbing behind it, not this tick.
;
; Like opl_shim, the engine's NRx4 restart bit is CONSUMED here, and what the
; FM hardware cannot do is emulated in software per tick, in GB units:
; envelope (NRx2), sweep (NR10, pulse1 only, overflow keys off), length
; (NRx1/NRx4 bit 6, 256 Hz countdown), master (NR50 louder side through the
; shared OplMasterAttTable, so FadeOutAudio ramps ride for free), panning
; (NR51 to OPL3 C0 CHA/CHB; both bits clear force-mute through TL, which is
; how rests and ducks become silence). FM programs come from the shared
; OplPatches/OplSlotMod/OplRegGroups rows (single definition in opl_shim, so
; the PAS card speaks the same timbres as the SB OPL); the GB-unit volume path
; is PAS-local linear v1 data below (PasVolAtt/PasWaveAtt), judged by the
; later ear stage. Per-song and per-SFX patch overrides stay out of G1.
;
; Under MIDI (g_midi_music) a voice sounds only while an SFX owns its GB
; channel (wChannelSoundIDs CHAN5-8 — the tandy guard shape, placed in
; pas_volume so stage G2 needs no change).
;
; Bring-up: pas_init runs the classic AdLib timer detection at PAS_BASE, then
; the OPL2-vs-OPL3 probe; on OPL3 it sets NEW (reg $105) so waveforms and
; stereo work. All register writes use OPL2-safe delays. g_pas_on is set only
; when FM answers — with no card every entry point no-ops (the engine still
; runs; there is just no device). The pre-clip hook-in point stays G2 (the cms
; precedent records the pikachu site; this file only notes it).
;
; Snapshot map (provisional, covox/cms echo-slack precedent; the debug_dump
; window extension stays G2/G3): PAS_SNAP = W_PORT_SCRATCH+0x8D, 4 bytes
; +0x8D..+0x90: +0x8D g_pas_on, +0x8E v0|v1 patch ids, +0x8F v2|v3 patch ids,
; +0x90 NR51 snapshot. Free-verified the cms way: nearest named memmap symbol
; is W_CHECK_FOR_TURN at +0x80 (1 byte), nothing named above it, and no other
; shim snapshot reaches +0x8D (cms ends +0x8C, the tree max).

bits 32

%include "gb_memmap.inc"

global pas_init
global pas_pass
global pas_silence
global pas_shutdown
global pas_dbg_snapshot
global g_pas_on

%ifndef ENABLE_AUDIO_PAS
%define ENABLE_AUDIO_PAS 1
%endif

%if ENABLE_AUDIO_PAS != 0

extern g_midi_music               ; src/audio/mpu401.asm — MIDI mode active
extern OplPatches                 ; src/audio/opl_shim.asm — shared FM rows
extern OplSlotMod                 ; (single definition there; the %else arm
extern OplRegGroups               ; keeps these resolving when OPL is off)
extern OplMasterAttTable

section .text

PAS_BASE        equ 0x388
PAS_OPL_ADDR    equ (PAS_BASE + 0)  ; bank-0 register address / status
PAS_OPL_DATA    equ (PAS_BASE + 1)  ; bank-0 data
PAS_OPL_ADDR_HI equ (PAS_BASE + 2)  ; bank-1 register address
PAS_OPL_DATA_HI equ (PAS_BASE + 3)  ; bank-1 data

PAS_PATCH_SIZE  equ 11              ; OplPatches row layout (shared, see opl_shim)

; --- per-voice software state (offsets 0-15 match tandy TS_* / cms CMS_*) --
PS_FREQ       equ 0    ; word: GB 11-bit freq (ch3: NR43 byte) incl. sweep
PS_KEY        equ 2    ; byte: key-on flag
PS_ENVVOL     equ 3    ; byte: current GB volume 0-15
PS_ENVDIR     equ 4    ; byte: envelope direction (1 = up)
PS_ENVPER     equ 5    ; byte: envelope period (0 = off)
PS_ENVACC     equ 6    ; word: envelope accumulator (64/tick vs 60*period)
PS_LEN        equ 8    ; word: length counter (1/256 s units)
PS_LENACC     equ 10   ; word: length accumulator (256/tick vs 60)
PS_LENEN      equ 12   ; byte: length enable (NRx4 bit 6)
PS_SWEEP      equ 13   ; byte: NR10 latched at key-on (ch0 only)
PS_SWACC      equ 14   ; word: sweep accumulator (128/tick vs 60*period)
PS_PATCH      equ 16   ; byte: loaded patch id (0xFF = none)
PS_B0         equ 17   ; byte: last B0 value written (incl. key bit)
PS_PAN        equ 18   ; byte: last written pan bits ($10 L | $20 R)
PS_C0         equ 19   ; byte: patch C0 base (feedback/connection)
PS_BASETL     equ 20   ; byte: patch carrier TL base (0-63)
PS_KSL        equ 21   ; byte: patch carrier KSL bits ($C0 mask)
PS_LAST40     equ 22   ; byte: last carrier $40 value written
PS_SIZE       equ 24

; --- PAS debug snapshot block (past cms, same echo-slack basis) -------------
PAS_SNAP equ (W_PORT_SCRATCH + 0x8D)   ; +0x8D..+0x90 (cms ends +0x8C)

; ===========================================================================
; pas_write — write AL to OPL register AH at PAS_BASE, with OPL2-safe delays
; (3.3 us after address, 23 us after data, via status-port reads).
; Preserves all registers.
; ===========================================================================
pas_write:
    push eax
    push ebx
    push ecx
    push edx
    mov bl, al                  ; value
    mov bh, ah                  ; register index
    mov dx, PAS_OPL_ADDR
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

; pas_write_hi — same, to the OPL3 second register bank (38Ah/38Bh).
pas_write_hi:
    push eax
    push ebx
    push ecx
    push edx
    mov bl, al
    mov bh, ah
    mov dx, PAS_OPL_ADDR_HI
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
; pas_init — detect FM at PAS_BASE, probe OPL2 vs OPL3, put the chip in a
; clean melodic-mode state, mark the shim active only when FM answers.
; Called from audio_init only when /PAS selected the device.
; Preserves all registers.
; ===========================================================================
pas_init:
    pushad
    ; classic AdLib timer detection
    mov ax, 0x0460
    call pas_write               ; mask both timers
    mov ax, 0x0480
    call pas_write               ; reset timer IRQ flags
    mov dx, PAS_OPL_ADDR
    in al, dx
    and al, 0xE0
    mov bl, al                  ; status with timers reset (must be 0)
    mov ax, 0x02FF
    call pas_write              ; timer 1 latch = $FF (80 us to overflow)
    mov ax, 0x0421
    call pas_write              ; start timer 1
    mov ecx, 130                ; ~130 ISA reads = >100 us
.wait:
    in al, dx
    loop .wait
    in al, dx
    and al, 0xE0
    mov bh, al                  ; status after overflow (must be $C0)
    mov ax, 0x0460
    call pas_write
    mov ax, 0x0480
    call pas_write
    test bl, bl
    jnz .done                   ; pre-status dirty: no FM here
    cmp bh, 0xC0
    jnz .done                   ; timer never fired: no FM here
    ; OPL2 vs OPL3: status bits 1-2 read $06 on OPL2, $00 on OPL3
    in al, dx
    and al, 0x06
    jnz .haveGen
    mov ax, 0x0501              ; reg $105 NEW=1: enable OPL3 features
    call pas_write_hi
    mov ax, 0x0400              ; reg $104: no 4-op pairs
    call pas_write_hi
.haveGen:
    mov ax, 0x0120              ; waveform select enable (OPL2; reserved on OPL3)
    call pas_write
    mov ax, 0x0800              ; CSM / note-select off
    call pas_write
    mov ax, 0xBD00              ; rhythm mode off, AM/VIB depth low
    call pas_write
    mov byte [g_pas_on], 1
    call pas_silence
    ; reset software voice state
    mov ecx, 4 * PS_SIZE
    mov edi, pas_state
.clr:
    mov byte [edi], 0
    inc edi
    loop .clr
    mov edi, pas_state
    mov ecx, 4
.vinit:
    mov byte [edi + PS_PATCH], 0xFF
    mov byte [edi + PS_LAST40], 0xFF
    add edi, PS_SIZE
    loop .vinit
.done:
    popad
    ret

; pas_silence — key off all 9 voices and pull every operator to max
; attenuation. No-op without the card. Voices re-key on their next note-on.
pas_silence:
    cmp byte [g_pas_on], 0
    jz .absent
    push eax
    push ecx
    mov ah, 0xB0
    mov ecx, 9
.koff:
    xor al, al
    call pas_write
    inc ah
    loop .koff
    mov ah, 0x40
    mov ecx, 22                 ; slots 0-21 (gaps are harmless no-ops)
.tl:
    mov al, 0x3F
    call pas_write
    inc ah
    loop .tl
    pop ecx
    pop eax
.absent:
    ret

; pas_shutdown — leave the card silent on exit. Preserves all registers.
pas_shutdown:
    cmp byte [g_pas_on], 0
    jz .off
    call pas_silence
.off:
    ret

; ===========================================================================
; pas_pass — the per-tick APU mirror. Called from audio_tick (DelayFrame is
; pushad-wrapped, registers may be clobbered freely).
;   EBX = GB channel / OPL voice (0-3)
;   ESI = GB address of the channel's register file ($FF10 + ch*5)
;   EDI = its software voice state
; ===========================================================================
pas_pass:
    cmp byte [g_pas_on], 0
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
    mov [p_master], al
    mov al, [ebp + rAUDTERM]
    mov [p_nr51], al

    xor ebx, ebx
.chLoop:
    lea esi, [ebx*4 + ebx]
    add esi, 0xFF10             ; channel register base
    lea eax, [ebx + ebx*2]
    shl eax, 3                  ; ch * 24
    lea edi, [pas_state + eax]

    mov al, [ebp + esi + 4]     ; NRx4
    test al, 0x80
    jz .noRestart
    and al, 0x7F                ; consume the restart bit
    mov [ebp + esi + 4], al
    call pas_keyon
    jmp .running
.noRestart:
    cmp byte [edi + PS_KEY], 0
    jz .next
    ; keep sweep register in sync for pulse 1
    test ebx, ebx
    jnz .noSweepSync
    mov al, [ebp + rAUD1SWEEP]
    cmp al, [edi + PS_SWEEP]
    je .noSweepSync
    mov [edi + PS_SWEEP], al
    mov word [edi + PS_SWACC], 0
.noSweepSync:
    ; frequency follow (engine vibrato / pitch slides / NR43 rewrites)
    ; Pulse 1 with active hardware sweep manages its own frequency via pas_sweep;
    ; comparing against static NRx3/NRx4 would clobber the swept frequency every tick.
    test ebx, ebx
    jnz .doFreqFollow
    test byte [edi + PS_SWEEP], 0x70
    jnz .fsame
.doFreqFollow:
    mov cl, [ebp + esi + 3]
    mov ch, [ebp + esi + 4]
    and ch, 7
    cmp ebx, 3
    jnz .fcmp
    xor ch, ch                  ; noise: NR43 byte alone is the "frequency"
.fcmp:
    cmp cx, [edi + PS_FREQ]
    je .fsame
    mov [edi + PS_FREQ], cx
    call pas_setfreq
.fsame:
    ; duty follow (pulse channels; the rotate_duty cry effect)
    cmp ebx, 2
    jae .running
    mov al, [ebp + esi + 1]
    shr al, 6                   ; duty 0-3 = patch id
    cmp al, [edi + PS_PATCH]
    je .running
    call pas_loadpatch
.running:
    cmp byte [edi + PS_KEY], 0
    jz .next
    call pas_sweep
    call pas_envelope
    call pas_length
    call pas_volume
    call pas_pan
.next:
    inc ebx
    cmp ebx, 4
    jb .chLoop
.off:
    ret

; ---------------------------------------------------------------------------
; pas_keyon — retrigger voice EBX from its APU registers.
; ---------------------------------------------------------------------------
pas_keyon:
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
    call pas_loadpatch
    ; envelope from NRx2 (the wave channel has none — NR32 is a level)
    mov al, [ebp + esi + 2]
    mov ah, al
    shr ah, 4
    mov [edi + PS_ENVVOL], ah
    mov ah, al
    shr ah, 3
    and ah, 1
    mov [edi + PS_ENVDIR], ah
    and al, 7
    mov [edi + PS_ENVPER], al
    mov word [edi + PS_ENVACC], 0
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
    mov [edi + PS_LEN], ax
    mov word [edi + PS_LENACC], 0
    mov al, [ebp + esi + 4]
    and al, 0x40
    mov [edi + PS_LENEN], al
    ; sweep latch (pulse 1 only)
    test ebx, ebx
    jnz .noSweep
    mov al, [ebp + rAUD1SWEEP]
    mov [edi + PS_SWEEP], al
    mov word [edi + PS_SWACC], 0
.noSweep:
    ; frequency snapshot
    mov cl, [ebp + esi + 3]
    mov ch, [ebp + esi + 4]
    and ch, 7
    cmp ebx, 3
    jnz .fstore
    xor ch, ch
.fstore:
    mov [edi + PS_FREQ], cx
    ; set level/pan before keying to avoid a burst at the wrong volume
    call pas_volume
    call pas_pan
    ; retrigger: key off (if keyed), then on
    mov al, [edi + PS_B0]
    and al, 0x1F
    mov ah, 0xB0
    add ah, bl
    call pas_write
    mov byte [edi + PS_KEY], 1
    jmp pas_setfreq             ; writes A0 + B0 with the key bit set

; ---------------------------------------------------------------------------
; pas_setfreq — program A0/B0 for voice EBX from PS_FREQ (+ PS_KEY).
; GB pulse: Hz = 131072/(2048-f); wave: 65536/(2048-f);
; noise (NR43, s=bits 7-4, r=bits 2-0): Hz = 262144/r/2^(s+1), r=0 -> r=0.5.
; OPL: fnum = Hz * 2^(20-block) / 49716, normalized into block 0-7.
; Clobbers EAX ECX EDX.
; ---------------------------------------------------------------------------
pas_setfreq:
    cmp ebx, 3
    jz .noise
    movzx eax, word [edi + PS_FREQ]
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
    mov al, [edi + PS_FREQ]
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
    cmp byte [edi + PS_KEY], 0
    jz .noKey
    or al, 0x20
.noKey:
    mov [edi + PS_B0], al
    mov cl, al                  ; B0 value
    mov al, ch
    mov ah, 0xA0
    add ah, bl
    call pas_write              ; fnum low
    mov al, cl
    mov ah, 0xB0
    add ah, bl
    call pas_write              ; key | block | fnum hi
    ret

pas_keyoff:
    mov al, [edi + PS_B0]
    and al, 0x1F
    mov [edi + PS_B0], al
    mov ah, 0xB0
    add ah, bl
    call pas_write
    mov byte [edi + PS_KEY], 0
    ret

; ---------------------------------------------------------------------------
; pas_loadpatch — load patch AL (0-5) onto voice EBX if not already there.
; Clobbers EAX ECX EDX.
; ---------------------------------------------------------------------------
pas_loadpatch:
    cmp al, [edi + PS_PATCH]
    je .done
    mov [edi + PS_PATCH], al
    push esi
    push ebx
    movzx esi, al
    imul esi, PAS_PATCH_SIZE
    add esi, OplPatches
    mov bh, [OplSlotMod + ebx]  ; modulator slot offset for this voice
    xor ecx, ecx                ; reg-group index 0-4
.ops:
    mov ah, [OplRegGroups + ecx]
    add ah, bh                  ; modulator register
    mov al, [esi + ecx]
    call pas_write
    add ah, 3                   ; carrier register (slot+3)
    mov al, [esi + ecx + 5]
    call pas_write
    inc ecx
    cmp ecx, 5
    jb .ops
    pop ebx
    ; cache the carrier level split + C0 base
    mov al, [esi + 6]           ; carrier $40 byte
    mov ah, al
    and al, 0x3F
    mov [edi + PS_BASETL], al
    and ah, 0xC0
    mov [edi + PS_KSL], ah
    mov al, [esi + 10]
    mov [edi + PS_C0], al
    pop esi
    mov byte [edi + PS_LAST40], 0xFF   ; force a level rewrite
    mov al, [edi + PS_PAN]
    or al, [edi + PS_C0]
    mov ah, 0xC0
    add ah, bl
    call pas_write
.done:
    ret

; ---------------------------------------------------------------------------
; pas_sweep — pulse-1 hardware sweep emulation (128 Hz base clock).
; ---------------------------------------------------------------------------
pas_sweep:
    test ebx, ebx
    jnz .done
    mov al, [edi + PS_SWEEP]
    mov cl, al
    shr cl, 4
    and cl, 7                   ; period
    jz .done
    movzx eax, cl
    imul eax, 60                ; threshold = period * 60
    movzx edx, word [edi + PS_SWACC]
    add edx, 128                ; accumulate 128 Hz clock
    cmp edx, eax
    jb .store
.loop:
    sub edx, eax
    push eax
    push edx
    movzx eax, word [edi + PS_FREQ]
    mov edx, eax
    mov cl, [edi + PS_SWEEP]
    and cl, 7                   ; shift
    jz .noFreqChange
    shr eax, cl
    test byte [edi + PS_SWEEP], 8
    jnz .down
    add edx, eax
    cmp edx, 2048
    jb .stepOk
    ; overflow: silences channel (GB rule)
    pop edx
    pop eax
    mov word [edi + PS_SWACC], 0
    jmp pas_keyoff
.down:
    sub edx, eax
    jns .stepOk
    xor edx, edx
.stepOk:
    mov [edi + PS_FREQ], dx
.noFreqChange:
    pop edx
    pop eax
    cmp edx, eax
    jae .loop
    mov [edi + PS_SWACC], dx
    jmp pas_setfreq
.store:
    mov [edi + PS_SWACC], dx
.done:
    ret

; ---------------------------------------------------------------------------
; pas_envelope — GB volume envelope: one step per (period / 64) s.
; ---------------------------------------------------------------------------
pas_envelope:
    cmp ebx, 2
    je .done                    ; wave channel has no envelope
    mov al, [edi + PS_ENVPER]
    test al, al
    jz .done
    movzx ecx, al
    imul ecx, 60
    movzx eax, word [edi + PS_ENVACC]
    add eax, 64
    cmp eax, ecx
    jb .store
    sub eax, ecx
    mov cl, [edi + PS_ENVVOL]
    cmp byte [edi + PS_ENVDIR], 0
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
    mov [edi + PS_ENVVOL], cl
.store:
    mov [edi + PS_ENVACC], ax
.done:
    ret

; ---------------------------------------------------------------------------
; pas_length — GB length counter: 256 Hz countdown, key-off at zero.
; ---------------------------------------------------------------------------
pas_length:
    cmp byte [edi + PS_LENEN], 0
    jz .done
    movzx eax, word [edi + PS_LENACC]
    add eax, 256
    movzx ecx, word [edi + PS_LEN]
.step:
    cmp eax, 60
    jb .save
    sub eax, 60
    dec ecx
    jnz .step
    ; expired
    mov word [edi + PS_LEN], 0
    mov byte [edi + PS_LENEN], 0
    mov [edi + PS_LENACC], ax
    jmp pas_keyoff
.save:
    mov [edi + PS_LEN], cx
    mov [edi + PS_LENACC], ax
.done:
    ret

; ---------------------------------------------------------------------------
; pas_volume — carrier TL = base + envelope/level + master, written on
; change. A channel with both NR51 bits clear is force-muted (rests/ducks).
; ---------------------------------------------------------------------------
pas_volume:
    cmp ebx, 2
    je .wave
    movzx eax, byte [edi + PS_ENVVOL]
    mov al, [PasVolAtt + eax]
    jmp .att
.wave:
    mov al, [ebp + rAUD3ENA]
    test al, 0x80               ; wave DAC off -> silent
    jz .mute
    mov al, [ebp + rAUD3LEVEL]
    shr al, 5
    and eax, 3
    mov al, [PasWaveAtt + eax]
.att:
    add al, [p_master]
    ; NR51: both terminal bits clear -> mute
    mov cl, bl
    mov ah, 0x11
    shl ah, cl
    test [p_nr51], ah
    jz .mute
    ; MIDI mode: the MT-32/GM stream carries the music, so a GB channel
    ; only voices on FM while an SFX owns it (wChannelSoundIDs CHAN5-8)
    cmp byte [g_midi_music], 0
    jz .clamp
    cmp byte [ebp + wChannelSoundIDs + CHAN5 + ebx], 0
    jnz .clamp
.mute:
    call pas_keyoff
    mov al, 63
.clamp:
    cmp al, 63
    jb .base
    mov al, 63
.base:
    add al, [edi + PS_BASETL]
    cmp al, 63
    jb .ksl
    mov al, 63
.ksl:
    or al, [edi + PS_KSL]
    cmp al, [edi + PS_LAST40]
    je .done
    mov [edi + PS_LAST40], al
    mov ah, [OplSlotMod + ebx]
    add ah, 0x40 + 3            ; carrier level register
    call pas_write
.done:
    ret

; ---------------------------------------------------------------------------
; pas_pan — NR51 terminal bits -> OPL3 C0 CHA(L)/CHB(R), written on change.
; Ignored by an OPL2 (bits are don't-care there; muting is TL-based above).
; ---------------------------------------------------------------------------
pas_pan:
    mov al, [p_nr51]
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
    cmp ah, [edi + PS_PAN]
    je .done
    mov [edi + PS_PAN], ah
    mov al, [edi + PS_C0]
    or al, ah
    mov ah, 0xC0
    add ah, bl
    call pas_write
.done:
    ret

; ---------------------------------------------------------------------------
; pas_dbg_snapshot — 4-byte block at PAS_SNAP (+0x8D..+0x90):
;   +0x8D g_pas_on  +0x8E v0|v1 patch ids  +0x8F v2|v3 patch ids  +0x90 NR51
; mpu401 shape (mov al/mov [ebp+...] stores, EAX only). The debug_dump window
; extension that dumps these bytes stays G2/G3 (this file cannot touch it).
; In: EBP = GB memory base. Clobbers EAX.
; ---------------------------------------------------------------------------
pas_dbg_snapshot:
    mov al, [g_pas_on]
    mov [ebp + (PAS_SNAP + 0)], al
    mov al, [pas_state + 0*PS_SIZE + PS_PATCH]
    shl al, 4
    or al, [pas_state + 1*PS_SIZE + PS_PATCH]
    mov [ebp + (PAS_SNAP + 1)], al
    mov al, [pas_state + 2*PS_SIZE + PS_PATCH]
    shl al, 4
    or al, [pas_state + 3*PS_SIZE + PS_PATCH]
    mov [ebp + (PAS_SNAP + 2)], al
    mov al, [p_nr51]
    mov [ebp + (PAS_SNAP + 3)], al
    ret

section .data

g_pas_on:       db 0              ; /PAS selected + FM answered the probe

; GB envelope volume 0-15 -> TL attenuation, linear v1 ((15-vol)*4).
; The later ear stage judges whether GB loudness needs a perceptual curve.
PasVolAtt:
    db 60, 56, 52, 48, 44, 40, 36, 32, 28, 24, 20, 16, 12, 8, 4, 0

; NR32 level 0-3 -> TL attenuation (mute/full/half/quarter: mute parks at 63,
; full is open, half is +6 dB = 8 steps of 0.75 dB, quarter +12 dB = 16).
PasWaveAtt:     db 63, 0, 8, 16

section .bss

pas_state:      resb 4 * PS_SIZE   ; ch0-3 voices (OPL voice index = GB channel)
p_master:       resb 1              ; NR50 louder-side attenuation this tick
p_nr51:         resb 1              ; NR51 snapshot for this tick

%else

section .text
pas_init:
pas_pass:
pas_silence:
pas_shutdown:
pas_dbg_snapshot:
    ret

section .data
g_pas_on:     db 0

%endif
