; tandy_shim.asm — virtual APU → SN76489 device shim (port-only HAL layer).
;
; The Tandy 1000's 76496 PSG is nearly the GB APU's cousin: 3 square-wave
; tone generators + 1 noise generator, each with a 4-bit attenuator
; (docs/sound/tandy_sound_reference.md; register-level detail in
; docs/references/smspower/). Once per audio tick tandy_pass reads the 4 GB
; channels from the virtual APU block at [ebp+$FF10..$FF26] and mirrors them
; onto the PSG at port C0h:
;
;   GB ch0 pulse1  -> tone 1    (duty is lost — the SN only does 50%)
;   GB ch1 pulse2  -> tone 2
;   GB ch2 wave    -> tone 3    one octave down, NR32 level as attenuation
;   GB ch3 noise   -> noise     nearest of the 3 fixed shift rates; GB 7-bit
;                               LFSR (NR43 bit 3) -> periodic, 15-bit -> white
;
; Like opl_shim, the engine's NRx4 restart bit is CONSUMED here, and what the
; PSG lacks is emulated in software per tick, in GB units: envelope (NRx2),
; sweep (NR10, pulse1), length (NRx1/NRx4 bit 6), master volume (NR50 louder
; side -> extra attenuation steps), and NR51 muting (both terminal bits clear
; -> attenuation 15) — the PSG itself is mono, so NR51 carries no panning
; here, only the engine's rest/duck semantics.
;
; Volume path: att = TandyVolTable[env vol] + master (+ NR32 level for the
; wave voice), clamped to 15 (= off). Tables are Tier-1 generated data
; (assets/tandy_tables.inc, tools/audio/gen_tandy_tables.py).
;
; The SN76489 is write-only — there is no probe. The shim activates only via
; the /TANDY command-line flag (audio_init sets g_shim_device and calls
; tandy_init); with g_tandy_on = 0 every entry point no-ops.
;
; Frequency: tone Hz = 3.579545 MHz / (32 * N)  ->  N = 111861 / Hz, 10-bit.
; The GB's pulse range reaches ~131 kHz; N clamps to [1, 1023] (N=1 is
; ultrasonic, matching opl_shim's fnum clamp).

%include "gb_memmap.inc"

global tandy_init
global tandy_pass
global tandy_silence
global tandy_shutdown
global tandy_dbg_snapshot
global g_tandy_on

extern g_midi_music               ; src/audio/mpu401.asm — MIDI mode active

section .text

TANDY_PSG_PORT equ 0xC0
TANDY_PSG_CLK32 equ 111861        ; 3579545 / 32: tone divider N for 1 Hz

; --- per-voice software state (mirrors opl_shim's VS_* where shared) ------
TS_FREQ       equ 0    ; word: GB 11-bit freq (ch3: NR43 byte) incl. sweep
TS_KEY        equ 2    ; byte: key-on flag
TS_ENVVOL     equ 3    ; byte: current GB volume 0-15
TS_ENVDIR     equ 4    ; byte: envelope direction (1 = up)
TS_ENVPER     equ 5    ; byte: envelope period (0 = off)
TS_ENVACC     equ 6    ; word: envelope accumulator (64/tick vs 60*period)
TS_LEN        equ 8    ; word: length counter (1/256 s units)
TS_LENACC     equ 10   ; word: length accumulator (256/tick vs 60)
TS_LENEN      equ 12   ; byte: length enable (NRx4 bit 6)
TS_SWEEP      equ 13   ; byte: NR10 latched at key-on (ch0 only)
TS_SWACC      equ 14   ; word: sweep accumulator (128/tick vs 60*period)
TS_LASTATT    equ 16   ; byte: last attenuation written (0xFF = force)
TS_LASTDIV    equ 18   ; word: last tone divider N / noise ctrl (0xFFFF = force)
TS_SIZE       equ 20

; ===========================================================================
; psg_write — write AL to the PSG. On real hardware the chip's READY line
; stalls the bus for its ~32-clock load time; the settle reads are paranoia
; for clones that don't. Preserves all registers.
; ===========================================================================
psg_write:
    push eax
    push ecx
    push edx
    mov dx, TANDY_PSG_PORT
    out dx, al
    mov dl, 0x61                  ; harmless settle reads (~4 ISA cycles)
    mov ecx, 4
.settle:
    in al, dx
    loop .settle
    pop edx
    pop ecx
    pop eax
    ret

; ===========================================================================
; tandy_init — reset software state, silence the PSG, mark the shim active.
; Called from audio_init only when /TANDY selected the device.
; Preserves all registers.
; ===========================================================================
tandy_init:
    pushad
    mov byte [g_tandy_on], 1
    mov ecx, 4 * TS_SIZE
    mov edi, tandy_state
.clr:
    mov byte [edi], 0
    inc edi
    loop .clr
    mov edi, tandy_state
    mov ecx, 4
.vinit:
    mov byte [edi + TS_LASTATT], 0xFF
    mov word [edi + TS_LASTDIV], 0xFFFF
    add edi, TS_SIZE
    loop .vinit
    call tandy_silence
    popad
    ret

; attenuation 15 (off) on all 4 PSG channels. Safe with the shim inactive
; (bare OUTs to an absent port). Exported for PlayPikachuSoundClip like
; opl_silence: software envelopes freeze during the cli PCM clip, so held
; notes must be cut; voices re-key on their next note-on.
tandy_silence:
    cmp byte [g_tandy_on], 0
    jz .off
    push eax
    push ecx
    push edi
    mov al, 0x9F                  ; tone 1 att 15
    mov edi, tandy_state
    mov ecx, 4
.ch:
    call psg_write
    mov byte [edi + TS_LASTATT], 15
    add al, 0x20                  ; next channel's att latch
    add edi, TS_SIZE
    loop .ch
    pop edi
    pop ecx
    pop eax
.off:
    ret

; tandy_shutdown — leave the PSG silent on exit. Preserves all registers.
tandy_shutdown:
    jmp tandy_silence

; ===========================================================================
; tandy_pass — the per-tick APU mirror. Called from audio_tick (DelayFrame is
; pushad-wrapped, registers may be clobbered freely).
;   EBX = GB channel / PSG channel (0-3)
;   ESI = GB address of the channel's register file ($FF10 + ch*5)
;   EDI = its software voice state
; ===========================================================================
tandy_pass:
    cmp byte [g_tandy_on], 0
    jz .off
    ; master attenuation from NR50 (the louder terminal, like opl_shim, so
    ; FadeOutAudio's simultaneous L/R ramp maps to a single attenuation ramp)
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
    mov al, [TandyMasterAttTable + eax]
    mov [t_master_att], al
    mov al, [ebp + rAUDTERM]
    mov [t_nr51_snap], al

    xor ebx, ebx
.chLoop:
    lea esi, [ebx*4 + ebx]
    add esi, 0xFF10               ; channel register base
    lea eax, [ebx + ebx*4]
    shl eax, 2                    ; ch * 20
    lea edi, [tandy_state + eax]

    mov al, [ebp + esi + 4]       ; NRx4
    test al, 0x80
    jz .noRestart
    and al, 0x7F                  ; consume the restart bit
    mov [ebp + esi + 4], al
    call tandy_keyon
    jmp .running
.noRestart:
    cmp byte [edi + TS_KEY], 0
    jz .next
    ; frequency follow (engine vibrato / pitch slides / NR43 rewrites)
    mov cl, [ebp + esi + 3]
    mov ch, [ebp + esi + 4]
    and ch, 7
    cmp ebx, 3
    jnz .fcmp
    xor ch, ch                    ; noise: NR43 byte alone is the "frequency"
.fcmp:
    cmp cx, [edi + TS_FREQ]
    je .running
    mov [edi + TS_FREQ], cx
    call tandy_setfreq
.running:
    cmp byte [edi + TS_KEY], 0
    jz .next
    call tandy_sweep
    call tandy_envelope
    call tandy_length
    call tandy_volume
.next:
    inc ebx
    cmp ebx, 4
    jb .chLoop
.off:
    ret

; ---------------------------------------------------------------------------
; tandy_keyon — retrigger channel EBX from its APU registers (the same latch
; sequence as opl_shim's voice_keyon, minus patches/pan).
; ---------------------------------------------------------------------------
tandy_keyon:
    ; envelope from NRx2 (the wave channel has none — NR32 is a level)
    mov al, [ebp + esi + 2]
    mov ah, al
    shr ah, 4
    mov [edi + TS_ENVVOL], ah
    mov ah, al
    shr ah, 3
    and ah, 1
    mov [edi + TS_ENVDIR], ah
    and al, 7
    mov [edi + TS_ENVPER], al
    mov word [edi + TS_ENVACC], 0
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
    mov [edi + TS_LEN], ax
    mov word [edi + TS_LENACC], 0
    mov al, [ebp + esi + 4]
    and al, 0x40
    mov [edi + TS_LENEN], al
    ; sweep latch (pulse 1 only)
    test ebx, ebx
    jnz .noSweep
    mov al, [ebp + rAUD1SWEEP]
    mov [edi + TS_SWEEP], al
    mov word [edi + TS_SWACC], 0
.noSweep:
    ; frequency snapshot
    mov cl, [ebp + esi + 3]
    mov ch, [ebp + esi + 4]
    and ch, 7
    cmp ebx, 3
    jnz .fstore
    xor ch, ch
.fstore:
    mov [edi + TS_FREQ], cx
    mov byte [edi + TS_KEY], 1
    ; force the noise-control rewrite so the retrigger resets the LFSR
    ; (the SN restarts its shift register on a noise-register write)
    cmp ebx, 3
    jnz .prog
    mov word [edi + TS_LASTDIV], 0xFFFF
.prog:
    ; set the level before the frequency to avoid a burst at the old pitch
    call tandy_volume
    jmp tandy_setfreq

tandy_keyoff:
    mov byte [edi + TS_KEY], 0
    mov al, 15
    jmp tandy_att

; ---------------------------------------------------------------------------
; tandy_setfreq — program the PSG frequency for channel EBX from TS_FREQ.
; GB pulse: Hz = 131072/(2048-f); wave: 65536/(2048-f);
; noise (NR43, s=bits 7-4, r=bits 2-0): LFSR clock = 262144/r/2^(s+1),
; r=0 -> r=0.5. Tone: N = 111861/Hz clamped to [1,1023], written as
; latch (low 4) + data (high 6). Noise: nearest fixed shift rate
; (clock/512 = 6991 Hz, /1024 = 3496, /2048 = 1748; geometric midpoints
; 4944/2472) + white/periodic from the GB LFSR width bit.
; Writes only on change. Clobbers EAX ECX EDX.
; ---------------------------------------------------------------------------
tandy_setfreq:
    cmp ebx, 3
    jz .noise
    movzx eax, word [edi + TS_FREQ]
    mov ecx, 2048
    sub ecx, eax
    mov eax, 131072
    cmp ebx, 2
    jnz .div
    shr eax, 1                    ; wave channel: one octave lower
.div:
    xor edx, edx
    div ecx
    ; Hz -> divider N
    mov ecx, eax
    mov eax, TANDY_PSG_CLK32
    xor edx, edx
    div ecx
    cmp eax, 1024
    jb .lo
    mov eax, 1023                 ; subsonic: clamp to the deepest tone
.lo:
    test eax, eax
    jnz .have
    inc eax                       ; ultrasonic: clamp (N=0 means 1024 on SN)
.have:
    cmp ax, [edi + TS_LASTDIV]
    je .done
    mov [edi + TS_LASTDIV], ax
    mov ecx, eax
    ; latch byte: 1 cc 0 dddd (low 4 bits of N)
    and al, 0x0F
    mov ah, bl
    shl ah, 5
    or al, ah
    or al, 0x80
    call psg_write
    ; data byte: 0 x dddddd (high 6 bits of N)
    mov eax, ecx
    shr eax, 4
    call psg_write
.done:
    ret
.noise:
    mov al, [edi + TS_FREQ]       ; NR43
    mov cl, al
    shr cl, 4
    inc cl                        ; s+1
    and eax, 7                    ; r
    jnz .noiseDiv
    mov eax, 524288               ; r=0 counts as 0.5
    shr eax, cl
    jmp .haveHz
.noiseDiv:
    shl eax, cl                   ; r * 2^(s+1)
    mov ecx, eax
    mov eax, 262144
    xor edx, edx
    div ecx
.haveHz:
    xor cl, cl                    ; NF 0: clock/512 = 6991 Hz
    cmp eax, 4944
    jae .haveNF
    inc cl                        ; NF 1: clock/1024 = 3496 Hz
    cmp eax, 2472
    jae .haveNF
    inc cl                        ; NF 2: clock/2048 = 1748 Hz
.haveNF:
    mov al, 0xE0                  ; noise control latch
    or al, cl
    test byte [edi + TS_FREQ], 8  ; GB 7-bit LFSR -> periodic, 15-bit -> white
    jnz .width
    or al, 0x04                   ; FB = white
.width:
    movzx ecx, al
    cmp cx, [edi + TS_LASTDIV]
    je .ndone
    mov [edi + TS_LASTDIV], cx    ; (rewrite resets the LFSR — change/keyon only)
    call psg_write
.ndone:
    ret

; ---------------------------------------------------------------------------
; tandy_sweep — pulse-1 hardware sweep emulation (128 Hz base clock).
; Same math as opl_shim's voice_sweep.
; ---------------------------------------------------------------------------
tandy_sweep:
    test ebx, ebx
    jnz .done
    mov al, [edi + TS_SWEEP]
    mov cl, al
    shr cl, 4
    and cl, 7                     ; period
    jz .done
    movzx eax, cl
    imul eax, 60
    movzx ecx, word [edi + TS_SWACC]
    add ecx, 128
    cmp ecx, eax
    jb .store
    sub ecx, eax
    mov [edi + TS_SWACC], cx
    ; f' = f +/- (f >> n)
    movzx eax, word [edi + TS_FREQ]
    mov edx, eax
    mov cl, [edi + TS_SWEEP]
    and cl, 7
    shr eax, cl
    test byte [edi + TS_SWEEP], 8
    jnz .down
    add edx, eax
    cmp edx, 2048
    jb .apply
    jmp tandy_keyoff              ; overflow silences the channel (GB rule)
.down:
    sub edx, eax
    jns .apply
    xor edx, edx
.apply:
    mov [edi + TS_FREQ], dx
    jmp tandy_setfreq
.store:
    mov [edi + TS_SWACC], cx
.done:
    ret

; ---------------------------------------------------------------------------
; tandy_envelope — GB volume envelope: one step per (period / 64) s.
; ---------------------------------------------------------------------------
tandy_envelope:
    cmp ebx, 2
    je .done                      ; wave channel has no envelope
    mov al, [edi + TS_ENVPER]
    test al, al
    jz .done
    movzx ecx, al
    imul ecx, 60
    movzx eax, word [edi + TS_ENVACC]
    add eax, 64
    cmp eax, ecx
    jb .store
    sub eax, ecx
    mov cl, [edi + TS_ENVVOL]
    cmp byte [edi + TS_ENVDIR], 0
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
    mov [edi + TS_ENVVOL], cl
.store:
    mov [edi + TS_ENVACC], ax
.done:
    ret

; ---------------------------------------------------------------------------
; tandy_length — GB length counter: 256 Hz countdown, key-off at zero.
; ---------------------------------------------------------------------------
tandy_length:
    cmp byte [edi + TS_LENEN], 0
    jz .done
    movzx eax, word [edi + TS_LENACC]
    add eax, 256
    movzx ecx, word [edi + TS_LEN]
.step:
    cmp eax, 60
    jb .save
    sub eax, 60
    dec ecx
    jnz .step
    ; expired
    mov word [edi + TS_LEN], 0
    mov byte [edi + TS_LENEN], 0
    mov [edi + TS_LENACC], ax
    jmp tandy_keyoff
.save:
    mov [edi + TS_LEN], cx
    mov [edi + TS_LENACC], ax
.done:
    ret

; ---------------------------------------------------------------------------
; tandy_volume — attenuation = vol table + master (+ NR32 level), written on
; change. A channel with both NR51 bits clear is force-muted (rests/ducks).
; ---------------------------------------------------------------------------
tandy_volume:
    cmp ebx, 2
    je .wave
    movzx eax, byte [edi + TS_ENVVOL]
    mov al, [TandyVolTable + eax]
    jmp .att
.wave:
    mov al, [ebp + rAUD3ENA]
    test al, 0x80                 ; wave DAC off -> silent
    jz .mute
    mov al, [ebp + rAUD3LEVEL]
    shr al, 5
    and eax, 3
    mov al, [TandyWaveLevelAtt + eax]
.att:
    add al, [t_master_att]
    ; NR51: both terminal bits clear -> mute
    mov cl, bl
    mov ah, 0x11
    shl ah, cl
    test [t_nr51_snap], ah
    jz .mute
    ; MIDI mode: the MT-32/GM stream carries the music, so a GB channel
    ; only voices on the PSG while an SFX owns it (wChannelSoundIDs CHAN5-8)
    cmp byte [g_midi_music], 0
    jz .clamp
    cmp byte [ebp + wChannelSoundIDs + CHAN5 + ebx], 0
    jnz .clamp
.mute:
    mov al, 15
.clamp:
    cmp al, 15
    jb tandy_att
    mov al, 15
    ; fall through
; tandy_att — write attenuation AL (0-15) for channel EBX, on change.
tandy_att:
    cmp al, [edi + TS_LASTATT]
    je .done
    mov [edi + TS_LASTATT], al
    mov ah, bl
    shl ah, 5
    or al, ah
    or al, 0x90                   ; attenuation latch
    call psg_write
    and al, 0x1F                  ; restore AL = plain attenuation
.done:
    ret

; ---------------------------------------------------------------------------
; tandy_dbg_snapshot — copy shim state into the $D248+ debug scratch window
; (DEBUG_AUDIO window 9 spans $D220-$D25F; $D240-45 is pika_dbg_snapshot's):
;   $D248    g_tandy_on           $D249-4C  per-channel TS_LASTATT
;   $D24D    noise ctrl (last)    $D24E-4F  tone-1 divider N (last, word)
; In: EBP = GB memory base. Clobbers EAX.
; ---------------------------------------------------------------------------
tandy_dbg_snapshot:
    mov al, [g_tandy_on]
    mov [ebp + 0xD248], al
    mov al, [tandy_state + 0*TS_SIZE + TS_LASTATT]
    mov [ebp + 0xD249], al
    mov al, [tandy_state + 1*TS_SIZE + TS_LASTATT]
    mov [ebp + 0xD24A], al
    mov al, [tandy_state + 2*TS_SIZE + TS_LASTATT]
    mov [ebp + 0xD24B], al
    mov al, [tandy_state + 3*TS_SIZE + TS_LASTATT]
    mov [ebp + 0xD24C], al
    mov al, [tandy_state + 3*TS_SIZE + TS_LASTDIV]
    mov [ebp + 0xD24D], al
    mov ax, [tandy_state + 0*TS_SIZE + TS_LASTDIV]
    mov [ebp + 0xD24E], al
    mov [ebp + 0xD24F], ah
    ret

section .data

g_tandy_on:     db 0              ; /TANDY selected + tandy_init ran

%include "assets/tandy_tables.inc"

section .bss

tandy_state:    resb 4 * TS_SIZE
t_master_att:   resb 1
t_nr51_snap:    resb 1
