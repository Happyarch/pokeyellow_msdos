; audio_hal.asm — port-only audio HAL glue (no pret counterpart; descriptive
;
; DEVIATION{class=HAL; pret=home/audio.asm:UpdateSound; behavior=a port-only glue layer ticks the translated pret audio engine once per DelayFrame and fans the virtual APU register block out to whichever device shim is present, instead of the engine writing the Game Boy APU registers directly; evidence=the DOS target has no APU at 0xFF10-0xFF26 so those writes land in a virtual register block this layer reads, and no pret routine spans engine tick plus device dispatch; lifetime=permanent, the audio HAL boundary is by design}
; names per convention).
;
; audio_tick runs once per DelayFrame, immediately after the hFrameCounter
; decrement, replicating pret home/vblank.asm's audio block order:
;   FadeOutAudio -> Music_DoLowHealthAlarm -> Audio1_UpdateMusic
; (pret bankswitches around the latter two; the port's engine is resident and
; Audio1_UpdateMusic is the single interpreter for all four banks). The
; device-shim pass hooks in after the engine update: audio_init resolves three
; tick slots (g_tick_shim/g_tick_enh/g_tick_midi) once from the g_audio_devices
; role nibbles, and the tick calls them blindly — zero per-tick compares.
; Unused slots point at tick_noop. Each shim pass is also self-guarded, and
; under MIDI (g_midi_music) every shim pass mutes music voices itself, so the
; winner's single pass voices SFX while midi_seq_tick carries the music (never
; double-pumped). DelayFrame is pushad-wrapped, so the tick may clobber
; registers freely.
;
; audio_init flips g_audio_engine_online (the PlaySound gate in
; src/home/audio.asm) and then runs the pret boot-path engine reset
; (StopAllSounds -> StopAllMusic -> PlaySound($ff) -> Audio2_StopAllAudio) so
; every engine variable (tempos, note delays, stereo mask, virtual APU regs)
; starts in GB power-on state. The flag must be set FIRST or the reset itself
; would be swallowed by the gate.

%include "gb_memmap.inc"        ; W_PORT_SCRATCH — port-only audio scratch
global audio_tick
global audio_init
global audio_shutdown
global g_cfg_nosound
global g_cfg_shim
global g_cfg_noenh
global g_cfg_musicloop
global g_shim_device
global hal_dbg_snapshot
global g_sb_base
global g_sb_irq
global g_sb_dma
global g_sb_present
global g_sb_dsp_ver

extern FadeOutAudio               ; src/home/fade_audio.asm
extern Music_DoLowHealthAlarm     ; src/audio/low_health_alarm.asm
extern Audio1_UpdateMusic         ; src/audio/engine_1.asm
extern StopAllSounds              ; src/home/init.asm
extern g_audio_engine_online      ; src/home/audio.asm
extern opl_init                   ; src/audio/opl_shim.asm
extern opl_pass                   ; src/audio/opl_shim.asm
extern opl_shutdown               ; src/audio/opl_shim.asm
extern g_opl_present              ; src/audio/opl_shim.asm
extern tandy_init                 ; src/audio/tandy_shim.asm
extern tandy_pass                 ; src/audio/tandy_shim.asm
extern tandy_shutdown             ; src/audio/tandy_shim.asm
extern spk_shim_init              ; src/audio/spk_shim.asm
extern spk_pass                   ; src/audio/spk_shim.asm
extern spk_shim_shutdown          ; src/audio/spk_shim.asm
extern innova_init                ; src/audio/innova_shim.asm
extern innova_pass                ; src/audio/innova_shim.asm
extern innova_shutdown            ; src/audio/innova_shim.asm
extern covox_init                 ; src/audio/covox_shim.asm
extern covox_pass                 ; src/audio/covox_shim.asm
extern covox_shutdown             ; src/audio/covox_shim.asm
extern g_covox_rate               ; src/input/input_cfg.asm
extern pit_set_rate               ; boot/timing.asm
extern cms_init                   ; src/audio/cms_shim.asm
extern cms_pass                   ; src/audio/cms_shim.asm
extern cms_shutdown               ; src/audio/cms_shim.asm
extern pas_init                   ; src/audio/pas_shim.asm
extern pas_pass                   ; src/audio/pas_shim.asm
extern pas_shutdown               ; src/audio/pas_shim.asm
extern enh_init                   ; src/audio/opl_enh.asm
extern enh_seq_tick               ; src/audio/opl_enh.asm
extern enh_seq_stop               ; src/audio/opl_enh.asm
extern mpu_detect                 ; src/audio/mpu401.asm
extern sb_dma_init                ; src/audio/sb_pcm.asm
extern sb_dma_shutdown            ; src/audio/sb_pcm.asm
extern sb_dma_poll_completion     ; src/audio/sb_pcm.asm
extern mt32_upload                ; src/audio/mpu401.asm
extern midi_seq_tick              ; src/audio/mpu401.asm
extern midi_seq_stop              ; src/audio/mpu401.asm
global g_audio_devices
global g_audio_devices2
global g_audio_forced
global g_tick_shim
global g_tick_enh
global g_tick_midi
extern g_midi_music               ; src/audio/mpu401.asm — 1 once mpu_detect IDs a UART
extern g_cfg_midi                 ; src/audio/mpu401.asm — set by /MT32 or /GM
extern g_cfg_audio_device         ; src/input/input_cfg.asm — POKEMON.CFG [audio] device request byte
extern ds_base                    ; boot/entry.asm — linear base of DS
extern seg_to_flat                ; boot/entry.asm — selector/segment -> flat

section .text

; Device nibble indices into g_audio_devices (one 4-bit role nibble each;
; nibble 6 reserved for the stage-4 /DISNEY FIFO device, nibble 7 is PCM-only).
; Devices 8+ live in g_audio_devices2 instead: the word-2 nibble index is
; (DEV - 8), sitting at bits (DEV - 8) * 4, so DEV_CMS = 8 is nibble 0
; (bits 0-3), a future DEV_DISNEY = 9 follows the same convention at
; nibble 1 (bits 4-7), and DEV_PAS = 10 sits at nibble 2 (bits 8-11).
DEV_MIDI   equ 0
DEV_OPL    equ 1
DEV_TANDY  equ 2
DEV_SPK    equ 3
DEV_INNOVA equ 4
DEV_COVOX  equ 5
DEV_DISNEY equ 6
DEV_SB     equ 7
DEV_CMS    equ 8
DEV_PAS    equ 10
; Role bits within a nibble (P S M E, high to low bit)
ROLE_EN    equ 1
ROLE_MUSIC equ 2
ROLE_SFX   equ 4
ROLE_PCM   equ 8
; g_audio_forced bit positions (bit N = /FLAG demanded device N; bits 8-31
; held nothing before the CMS change — the tree only ever set bits 0, 2, 3,
; 4, 5 — so bit 8 was free for FORCE_CMS, and bit 10 is free for FORCE_PAS)
FORCE_MIDI   equ (1 << DEV_MIDI)
FORCE_TANDY  equ (1 << DEV_TANDY)
FORCE_SPK    equ (1 << DEV_SPK)
FORCE_INNOVA equ (1 << DEV_INNOVA)
FORCE_COVOX  equ (1 << DEV_COVOX)
FORCE_CMS    equ (1 << DEV_CMS)
FORCE_PAS    equ (1 << DEV_PAS)

audio_tick:
    cmp byte [g_audio_engine_online], 0
    jz .off
    call sb_dma_poll_completion
    call FadeOutAudio
    call Music_DoLowHealthAlarm
    call Audio1_UpdateMusic
    ; Solved dispatch: three init-resolved passes, zero per-tick compares.
    ; Non-MIDI the winner voices music+SFX in its one pass; under MIDI the
    ; winner's pass self-mutes to SFX (g_midi_music gate inside each shim)
    ; and the MIDI slot carries the music. Unused slots are tick_noop.
    call [g_tick_shim]
    call [g_tick_enh]
    call [g_tick_midi]
.off:
    ret

tick_noop:
    ret

audio_init:
    cmp byte [g_cfg_nosound], 0   ; /NOSOUND: no probes, engine stays offline
    jnz .off
    call audio_parse_blaster      ; BLASTER env -> g_sb_base/irq/dma
    call dsp_detect               ; DSP reset + E1h version (Phase C consumer)
    call sb_dma_init              ; allocate conventional DMA buffer & hook IRQ
    call opl_init                 ; detect + reset the OPL (388h)
    call enh_init                 ; enhancement-player caches (no port I/O)
    ; device shim selection: solved = /FLAG forced, then config requested,
    ; then auto-fill. parse_cmdline recorded every /FLAG demand in
    ; g_audio_forced; forced shim bits resolve by fixed priority
    ; TANDY > INNOVA > COVOX > GB > PAS > SPK (the SN76489, SID, DAC, CMS latch
    ; are write-only — no probe is possible, the flag IS the detection, so a
    ; forced TANDY/INNOVA/COVOX/GB/PAS/SPK bit always survives this test chain.
    ; With no forced shim standing, POKEMON.CFG [audio] device (g_cfg_audio_device, parsed once
    ; at boot; 0xFF = auto) acts as the forced demand in the same order; a
    ; /FLAG above always wins over it. With that at auto too, the default is
    ; OPL when one answered, else the always-present speaker SFX shim so a
    ; no-card machine still blips. MIDI never suppresses the shim fill — it
    ; adds the stream alongside the winner.
    mov eax, [g_audio_forced]
    test eax, FORCE_TANDY
    jnz .wTandy
    test eax, FORCE_INNOVA
    jnz .wInnova
    test eax, FORCE_COVOX
    jnz .wCovox
    test eax, FORCE_CMS
    jnz .wGb
    test eax, FORCE_PAS
    jnz .wPas
    test eax, FORCE_SPK
    jnz .wSpk
    mov al, [g_cfg_audio_device]  ; 0xFF = auto (no config): today's fill below
    cmp al, 0xFF
    je .autoFill
    cmp al, 2                     ; TANDY
    je .wTandy
    cmp al, 4                     ; INNOVA
    je .wInnova
    cmp al, 5                     ; COVOX
    je .wCovox
    cmp al, 8                     ; GB (explicit /GB or config device 8)
    je .wGb
    cmp al, 10                    ; PAS (explicit /PAS or config device pas)
    je .wPas
    cmp al, 3                     ; SPK
    je .wSpk
    cmp al, 1                     ; OPL (forced even if the probe found none)
    je .wOpl
    test al, al                   ; 0 = none: silence like /NOSOUND from here
    jz .off                       ; (probes already ran; slots stay tick_noop)
    jmp .autoFill                 ; unknown byte: ignore, keep today's fill
.autoFill:
    cmp byte [g_opl_present], 0
    jnz .wOpl
.wSpk:
    mov ebx, 3                    ; PC speaker (forced /SPK or auto fallback)
    mov esi, spk_pass
    call spk_shim_init
    jmp .haveWinner
.wTandy:
    mov ebx, 2                    ; SN76489
    mov esi, tandy_pass
    call tandy_init
    jmp .haveWinner
.wInnova:
    mov ebx, 4                    ; Innovation SSI-2001
    mov esi, innova_pass
    call innova_init
    jmp .haveWinner
.wCovox:
    mov ebx, 5                    ; Covox DAC (explicit /COVOX only, never auto)
    mov esi, covox_pass
    call covox_init
    ; Reprogram PIT channel 0 to g_covox_rate: divisor = 1193182 / g_covox_rate
    movzx ecx, word [g_covox_rate]
    test ecx, ecx
    jz .pitDone
    mov eax, 1193182
    xor edx, edx
    div ecx                       ; AX = divisor
    call pit_set_rate
.pitDone:
    jmp .haveWinner
.wGb:
    mov ebx, 8                    ; Game Blaster / CMS (explicit /GB only, never auto)
    mov esi, cms_pass
    call cms_init
    jmp .haveWinner
.wPas:
    mov ebx, 10                   ; Pro Audio Spectrum 16 (explicit /PAS only, never auto)
    mov esi, pas_pass
    call pas_init
    jmp .haveWinner
.wOpl:
    mov ebx, 1                    ; OPL (opl_init already probed above)
    mov esi, opl_pass
.haveWinner:
    mov [g_tick_shim], esi        ; the single shim pass voices music+SFX
    mov dword [g_tick_enh], tick_noop
    cmp ebx, 1                    ; tier-1 enhancement rides only under OPL,
    jne .noEnh                    ; the old ladder's call pattern exactly
    mov dword [g_tick_enh], enh_seq_tick
.noEnh:
    mov dword [g_tick_midi], tick_noop
    cmp byte [g_cfg_midi], 0      ; /MT32 or /GM: probe the MPU-401 too
    jz .buildWord
    call mpu_detect               ; clears g_cfg_midi if nothing answers
    call mt32_upload              ; setup SysEx (no-op unless /MT32 + found)
    cmp byte [g_midi_music], 0
    jnz .midiLive
    mov byte [g_cfg_midi], 0      ; already cleared by mpu_detect on real
                                  ; hardware; explicit for the stub combo where
                                  ; mpu_detect is a ret-only no-op
    and dword [g_audio_forced], ~FORCE_MIDI
    jmp .buildWord
.midiLive:
    mov dword [g_tick_midi], midi_seq_tick
.buildWord:
    ; assemble the solved role word from the winner (EBX) and the probes
    xor eax, eax
    cmp byte [g_midi_music], 0
    jz .noMidiBit
    or eax, (ROLE_MUSIC | ROLE_EN) << (DEV_MIDI * 4)
.noMidiBit:
    cmp ebx, 1
    jne .noOplBit
    or eax, (ROLE_MUSIC | ROLE_SFX | ROLE_EN) << (DEV_OPL * 4)
.noOplBit:
    cmp ebx, 2
    jne .noTandyBit
    or eax, (ROLE_MUSIC | ROLE_SFX | ROLE_EN) << (DEV_TANDY * 4)
.noTandyBit:
    ; speaker: PCM field always (cry fallback), SFX only as the winner —
    ; Covox/DSS winners take no speaker SFX (the DAC covers SFX + cry)
    mov ecx, (ROLE_PCM | ROLE_EN) << (DEV_SPK * 4)
    cmp ebx, 3
    jne .spkBase
    or ecx, (ROLE_SFX) << (DEV_SPK * 4)
.spkBase:
    or eax, ecx
    cmp ebx, 4
    jne .noInnovaBit
    or eax, (ROLE_MUSIC | ROLE_SFX | ROLE_EN) << (DEV_INNOVA * 4)
.noInnovaBit:
    cmp ebx, 5
    jne .noCovoxBit
    or eax, (ROLE_MUSIC | ROLE_SFX | ROLE_PCM | ROLE_EN) << (DEV_COVOX * 4)
.noCovoxBit:
    cmp byte [g_sb_present], 0
    jz .noSbBit
    or eax, (ROLE_PCM | ROLE_EN) << (DEV_SB * 4)
.noSbBit:
    mov [g_audio_devices], eax
    ; word 2: the CMS nibble (nibble 0 = music+SFX+en, never PCM — the SAA
    ; has no DAC, so the speaker keeps its PCM field under a GB winner) and
    ; the PAS nibble (nibble 2 = music+SFX+en, never PCM — the G1 tick has no
    ; PCM path, so the speaker keeps its PCM field under a PAS winner too)
    mov dword [g_audio_devices2], 0
    cmp ebx, DEV_CMS
    jne .noCmsBit
    mov dword [g_audio_devices2], (ROLE_MUSIC | ROLE_SFX | ROLE_EN)
.noCmsBit:
    cmp ebx, DEV_PAS
    jne .noPasBit
    or dword [g_audio_devices2], (ROLE_MUSIC | ROLE_SFX | ROLE_EN) << 8
.noPasBit:
    mov [g_shim_device], bl       ; legacy byte follows the solved winner
    mov byte [g_audio_engine_online], 1
    call StopAllSounds
.off:
    ret

audio_shutdown:
    mov byte [g_audio_engine_online], 0
    call sb_dma_shutdown          ; free DMA buffer & restore IRQ
    call midi_seq_stop            ; all-notes-off on the MIDI module
    call enh_seq_stop             ; enhancement voices off before chip reset
    call opl_shutdown             ; leave the FM chip silent
    call tandy_shutdown           ; leave the PSG silent (no-op if inactive)
    call spk_shim_shutdown        ; speaker gate off (safe always)
    call innova_shutdown          ; leave the SID silent (no-op if inactive)
    call covox_shutdown           ; park the DAC at mid-level (no-op if inactive)
    call cms_shutdown             ; leave the CMS silent (no-op if inactive)
    call pas_shutdown             ; leave the PAS OPL3 silent (no-op if inactive)
    ; Restore PIT channel 0 rate to standard 60 Hz frame divisor
    xor ax, ax
    call pit_set_rate
    ret

; hal_dbg_snapshot — record the selected shim device at $D246 (DEBUG_AUDIO
; window 9; see the shims' snapshot maps for $D248+). Clobbers EAX.
hal_dbg_snapshot:
    mov al, [g_shim_device]
    mov [ebp + (W_PORT_SCRATCH + 0x66)], al
    mov al, [g_cfg_shim]
    mov [ebp + (W_PORT_SCRATCH + 0x67)], al
    ret

section .data

blaster_name:   db "BLASTER=", 0

g_cfg_nosound:  db 0              ; /NOSOUND on the command line
g_cfg_shim:     db 0              ; forced shim: /TANDY = 2, /SPK = 3, /INNOVA = 4 (0 = auto; /COVOX, /GB and /PAS set a forced bit only)
g_cfg_noenh:    db 0              ; /NOENH: disable the tier-1 OPL enhancement layer
g_cfg_musicloop: db 0            ; /LOOP: DEBUG_AUDIO harness plays music only, forever
g_shim_device:  db 0              ; active shim: 0 none, 1 OPL, 2 SN76489, 3 speaker, 4 innova, 5 covox, 8 CMS, 10 PAS (6 disney reserved)
; Solved device set (stage 0.4 bitmask): one 4-bit P-S-M-E role nibble per
; DEV_* index (PCM, SFX, MUSIC, ENABLE, high to low bit). Written once by
; audio_init; the tick slots below are resolved from it.
g_audio_devices: dd 0             ; role nibbles: MIDI 0, OPL 1, TANDY 2, SPK 3, INNOVA 4, COVOX 5, DISNEY 6, SB 7
g_audio_devices2: dd 0            ; word-2 role nibbles: CMS 8 at nibble 0 (bits 0-3), PAS 10 at nibble 2 (bits 8-11); the rest reserved, still 0
g_audio_forced:  dd 0             ; /FLAG demands, bit N = device N (bits 0-10); unavailable demands clear at solve
g_tick_shim:    dd tick_noop     ; the single shim pass (winner voices music+SFX)
g_tick_enh:     dd tick_noop     ; tier-1 enhancement (OPL winner only)
g_tick_midi:    dd tick_noop     ; MIDI music stream (MIDI nibble music only)
g_sb_base:      dw 0              ; BLASTER A field (e.g. 0x220); 0 = absent
g_sb_irq:       db 0              ; BLASTER I field
g_sb_dma:       db 0              ; BLASTER D field
g_sb_present:   db 0              ; DSP answered the reset with $AA
g_sb_dsp_ver:   dw 0              ; DSP version: major<<8 | minor

section .text

; ---------------------------------------------------------------------------
; audio_parse_blaster — find "BLASTER=" in the DOS environment (segment word
; at PSP+$2C, reached flat via ds_base like parse_cmdline reaches the PSP)
; and record the A (hex port), I (IRQ) and D (DMA) fields. Other fields
; (H/P/T/M/E) are skipped. Absent variable leaves g_sb_base = 0.
; Preserves all registers.
; ---------------------------------------------------------------------------
audio_parse_blaster:
    pushad
    mov ah, 0x62
    int 0x21                      ; BX = PSP (selector under a DPMI host)
    mov ax, bx
    call seg_to_flat
    mov ax, [eax + 0x2C]          ; environment pointer (selector under DPMI)
    test ax, ax
    jz .done
    call seg_to_flat
    mov esi, eax
.varLoop:
    cmp byte [esi], 0
    je .done                      ; empty string terminates the env block
    mov edi, blaster_name
.cmp:
    mov al, [edi]
    test al, al
    jz .fields                    ; full "BLASTER=" prefix matched
    cmp al, [esi]
    jne .nextVar
    inc esi
    inc edi
    jmp .cmp
.fields:
    mov al, [esi]
    test al, al
    jz .done
    inc esi
    cmp al, ' '
    je .fields
    or al, 0x20                   ; lowercase the field letter
    cmp al, 'a'
    je .fA
    cmp al, 'i'
    je .fI
    cmp al, 'd'
    je .fD
.skipTok:                         ; unknown field: skip to next space
    mov al, [esi]
    test al, al
    jz .done
    cmp al, ' '
    je .fields
    inc esi
    jmp .skipTok
.fA:
    call parse_hex
    mov [g_sb_base], ax
    jmp .fields
.fI:
    call parse_dec
    mov [g_sb_irq], al
    jmp .fields
.fD:
    call parse_dec
    mov [g_sb_dma], al
    jmp .fields
.nextVar:
    cmp byte [esi], 0
    je .n1
    inc esi
    jmp .nextVar
.n1:
    inc esi
    jmp .varLoop
.done:
    popad
    ret

; parse_hex / parse_dec — number at ESI -> EAX; ESI advanced past it.
parse_hex:
    xor eax, eax
.loop:
    movzx ecx, byte [esi]
    sub cl, '0'
    cmp cl, 9
    jbe .digit
    sub cl, 'A' - '0'
    cmp cl, 5
    jbe .upper
    sub cl, 'a' - 'A'
    cmp cl, 5
    ja .done
.upper:
    add cl, 10
.digit:
    shl eax, 4
    add eax, ecx
    inc esi
    jmp .loop
.done:
    ret

parse_dec:
    xor eax, eax
.loop:
    movzx ecx, byte [esi]
    sub cl, '0'
    cmp cl, 9
    ja .done
    lea eax, [eax + eax*4]
    shl eax, 1                    ; eax *= 10
    add eax, ecx
    inc esi
    jmp .loop
.done:
    ret

; ---------------------------------------------------------------------------
; dsp_detect — Sound Blaster DSP reset + version probe at g_sb_base (from
; BLASTER; 0 = don't probe). Reset: 1 -> base+6, ~3 µs, 0 -> base+6, then
; poll base+$E bit 7 and expect $AA from base+$A. Version: command $E1 ->
; base+$C (after write-ready), two reply bytes = major.minor. All polls are
; bounded — a wrong BLASTER can't hang boot. The DSP itself is only used by
; the Phase C PCM player; this just records what's there.
; Preserves all registers.
; ---------------------------------------------------------------------------
dsp_detect:
    pushad
    movzx ebx, word [g_sb_base]
    test ebx, ebx
    jz .done
    lea edx, [ebx + 6]            ; DSP reset port
    mov al, 1
    out dx, al
    mov ecx, 8                    ; >3 µs of ISA reads
.rst:
    in al, dx
    loop .rst
    xor al, al
    out dx, al
    lea edx, [ebx + 0xE]          ; read-buffer status
    mov ecx, 2000
.poll:
    in al, dx
    test al, 0x80
    jnz .avail
    loop .poll
    jmp .done                     ; no DSP answered
.avail:
    lea edx, [ebx + 0xA]          ; read data
    in al, dx
    cmp al, 0xAA
    jne .done
    mov byte [g_sb_present], 1
    ; DSP version
    lea edx, [ebx + 0xC]          ; write command/data
    mov ecx, 2000
.wrdy:
    in al, dx
    test al, 0x80
    jz .send
    loop .wrdy
    jmp .done
.send:
    mov al, 0xE1
    out dx, al
    call .readByte
    jc .done
    mov ah, al                    ; major
    push eax
    call .readByte
    pop ecx
    jc .done
    mov ah, ch                    ; major back in AH, minor in AL
    mov [g_sb_dsp_ver], ax
    jmp .done
.readByte:                        ; -> AL, CF set on timeout
    lea edx, [ebx + 0xE]
    push ecx
    mov ecx, 2000
.rb:
    in al, dx
    test al, 0x80
    jnz .rbGot
    loop .rb
    pop ecx
    stc
    ret
.rbGot:
    pop ecx
    lea edx, [ebx + 0xA]
    in al, dx
    clc
    ret
.done:
    popad
    ret
