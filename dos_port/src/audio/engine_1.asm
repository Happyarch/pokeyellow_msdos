; engine_1.asm — pret audio/engine_1.asm translated to x86.
;
; The complete GB sound-engine interpreter: Audio1_UpdateMusic ticks all 8
; software channels once per frame, executing bytecode commands (via
; GetNextMusicByte) until each channel's next note, and writes the resulting
; GB APU register state to the VIRTUAL APU block at [ebp+rAUD*] ($FF10-$FF3F
; in emulated GB memory). The active device shim (opl_shim, Phase A item 6)
; turns that state into hardware writes once per tick; NRx4 bit-7 restarts
; stay set in the virtual block and are consumed (cleared) by the shim — the
; engine never reads them back.
;
; Banking collapses in the port: pret ran this engine from bank 2 and read
; foreign-bank music data through home GetNextMusicByte's bankswitch; here
; all four audio banks live in the AudioRom blob (assets/audio_rom.inc,
; slot = 0/1/2/3 for GB bank $02/$08/$1F/$20) and GetNextMusicByte
; (src/home/audio.asm) indexes it by wAudioROMBank.
;
; pret: audio/engine_1.asm — all labels preserved. Audio1_PlaySound shares
; its body with Audio2/3/4_PlaySound as AudioCommon_PlaySound (pret carries
; four near-identical copies differing only in header base / MAX_SFX_ID /
; music-id boundary / CryRet address; each AudioN_PlaySound label survives
; in its source-mirror file and selects its parameter block).
;
; Register discipline (asm-translation skill): A=AL, BC=BX (B=BH, C=BL),
; DE=DX (D=DH, E=DL), HL=ESI, EBP = GB memory base; ECX/EDI port scratch.
; The channel index c is BL for the whole tick. pret's ubiquitous
; "ld b,0 / ld hl,tbl / add hl,bc / [hl]" collapses to
; "movzx edi, bl / [ebp + tbl + edi]" (movzx/mov/lea are flag-neutral).
; SM83 `bit n` sets ZF -> translated as `test al, mask` + jz/jnz.
;
; Helper-clobber contract (see src/home/audio.asm):
;   GetNextMusicByte            clobbers EAX EDX ESI; preserves EBX ECX EDI
;   InitMusicVariables/InitSFXVariables/StopAllAudio preserve all but EAX
;   DetermineAudioFunction      clobbers EAX ECX EDX ESI EDI; preserves EBX

%include "gb_memmap.inc"
%include "assets/audio_constants.inc"

global Audio1_UpdateMusic
global Audio1_PlaySound
global Audio1_ApplyMonoStereo
global Audio1_HWChannelDisableMasks
global Audio1_HWChannelEnableMasks
global AudioCommon_PlaySound

extern GetNextMusicByte           ; src/home/audio.asm
extern InitMusicVariables         ; src/home/audio.asm (-> Audio2_*)
extern InitSFXVariables           ; src/home/audio.asm
extern StopAllAudio               ; src/home/audio.asm
extern DetermineAudioFunction     ; src/home/audio.asm
extern AudioRom                   ; src/data/audio_data.asm
extern midi_seq_start             ; src/audio/mpu401.asm (no-op unless /MT32)
extern midi_seq_stop              ; src/audio/mpu401.asm

section .text

; ===========================================================================
Audio1_UpdateMusic:
    mov bl, CHAN1
.loop:
    movzx edi, bl
    mov al, [ebp + wChannelSoundIDs + edi]
    test al, al
    jz .nextChannel
    mov al, bl
    cmp al, CHAN5
    jae .applyAffects                   ; if sfx channel
    mov al, [ebp + wMuteAudioAndPauseMusic]
    test al, al
    jz .applyAffects
    test al, 1 << BIT_MUTE_AUDIO
    jnz .nextChannel
    or al, 1 << BIT_MUTE_AUDIO
    mov [ebp + wMuteAudioAndPauseMusic], al
    xor al, al                          ; disable all channels' output
    mov [ebp + rAUDTERM], al
    mov [ebp + rAUD3ENA], al
    mov al, AUD3ENA_ON
    mov [ebp + rAUD3ENA], al
    jmp .nextChannel
.applyAffects:
    call Audio1_ApplyMusicAffects
.nextChannel:
    mov al, bl
    inc bl                              ; inc channel number
    cmp al, CHAN8
    jnz .loop
    ret

; ---------------------------------------------------------------------------
; checks flags for music effects currently applied to the channel and calls
; certain functions based on flags. c (BL) = channel.
Audio1_ApplyMusicAffects:
    movzx edi, bl
    mov al, [ebp + wChannelNoteDelayCounters + edi]
    cmp al, 1                           ; delay 1 -> play next note
    jz Audio1_PlayNextNote
    dec al                              ; otherwise decrease the delay timer
    mov [ebp + wChannelNoteDelayCounters + edi], al
    mov al, bl
    cmp al, CHAN5
    jae .startChecks                    ; if a sfx channel
    mov al, [ebp + wChannelSoundIDs + CHAN5 + edi]
    test al, al
    jz .startChecks
    ret
.startChecks:
    mov al, [ebp + wChannelFlags1 + edi]
    test al, 1 << BIT_ROTATE_DUTY_CYCLE
    jz .checkForExecuteMusic
    call Audio1_ApplyDutyCyclePattern
.checkForExecuteMusic:
    movzx edi, bl
    mov al, [ebp + wChannelFlags2 + edi]
    test al, 1 << BIT_EXECUTE_MUSIC
    jnz .checkForPitchSlide
    mov al, [ebp + wChannelFlags1 + edi]
    test al, 1 << BIT_NOISE_OR_SFX
    jnz .skipPitchSlideVibrato
.checkForPitchSlide:
    mov al, [ebp + wChannelFlags1 + edi]
    test al, 1 << BIT_PITCH_SLIDE_ON
    jz .checkVibratoDelay
    jmp Audio1_ApplyPitchSlide
.checkVibratoDelay:
    mov al, [ebp + wChannelVibratoDelayCounters + edi]
    test al, al                         ; is the delay over?
    jz .checkForVibrato
    dec byte [ebp + wChannelVibratoDelayCounters + edi]
.skipPitchSlideVibrato:
    ret
.checkForVibrato:
    mov al, [ebp + wChannelVibratoExtents + edi]
    test al, al
    jnz .vibrato
    ret                                 ; no vibrato
.vibrato:
    mov dh, al                          ; d = extent byte
    mov al, [ebp + wChannelVibratoRates + edi]
    and al, 0x0F
    jz .applyVibrato
    dec byte [ebp + wChannelVibratoRates + edi] ; decrement counter
    ret
.applyVibrato:
    ; reload the counter (hi nibble is the reload value)
    mov al, [ebp + wChannelVibratoRates + edi]
    mov cl, al
    rol cl, 4                           ; swap
    or al, cl
    mov [ebp + wChannelVibratoRates + edi], al
    mov dl, [ebp + wChannelFrequencyLowBytes + edi] ; e = note pitch
    ; the only code touching the direction bit — it alternates every visit
    mov al, [ebp + wChannelFlags1 + edi]
    test al, 1 << BIT_VIBRATO_DIRECTION
    jz .unset
    and al, (~(1 << BIT_VIBRATO_DIRECTION)) & 0xFF
    mov [ebp + wChannelFlags1 + edi], al
    mov al, dh
    and al, 0x0F                        ; below-note extent
    mov dh, al
    mov al, dl
    sub al, dh
    jnc .noCarry
    mov al, 0
.noCarry:
    jmp .done
.unset:
    or al, 1 << BIT_VIBRATO_DIRECTION
    mov [ebp + wChannelFlags1 + edi], al
    mov al, dh
    and al, 0xF0                        ; above-note extent
    rol al, 4                           ; swap
    add al, dl
    jnc .done
    mov al, 0xFF
.done:
    mov dh, al
    mov bh, REG_FREQUENCY_LO
    call Audio1_GetRegisterPointer
    mov [ebp + esi], dh
    ret

; ---------------------------------------------------------------------------
; executes all music commands that take up no time (tempo, duty cycle, ...)
; and doesn't return until the first note is reached
Audio1_PlayNextNote:
    movzx edi, bl
    mov al, [ebp + wChannelVibratoDelayCounterReloadValues + edi]
    mov [ebp + wChannelVibratoDelayCounters + edi], al
    mov al, [ebp + wChannelFlags1 + edi]
    and al, (~((1 << BIT_PITCH_SLIDE_ON) | (1 << BIT_PITCH_SLIDE_DECREASING))) & 0xFF
    mov [ebp + wChannelFlags1 + edi], al
    mov al, bl
    cmp al, CHAN5                       ; pret: cp $4 (= CHAN5, alarm channel)
    jnz .asm_918c
    mov al, [ebp + wLowHealthAlarm]
    test al, 1 << BIT_LOW_HEALTH_ALARM
    jz .asm_918c
    call Audio1_EnableChannelOutput
    ret
.asm_918c:
    call Audio1_sound_ret
    ret

; ---------------------------------------------------------------------------
; Command dispatch chain. DH holds the command byte through the chain,
; exactly as pret keeps it in D (GetNextMusicByte may clobber DX; every
; handler that reads more bytes re-enters the chain via Audio1_sound_ret,
; which refreshes DH).
Audio1_sound_ret:
    call Audio1_GetNextMusicByte
    mov dh, al
    cmp al, 0xFF                        ; sound_ret_cmd
    jnz Audio1_sound_call
    movzx edi, bl
    mov al, [ebp + wChannelFlags1 + edi]
    test al, 1 << BIT_SOUND_CALL
    jnz .returnFromCall
    mov al, bl
    cmp al, CHAN4
    jae .noiseOrSfxChannel
    jmp .disableChannelOutput
.noiseOrSfxChannel:
    and byte [ebp + wChannelFlags1 + edi], (~(1 << BIT_NOISE_OR_SFX)) & 0xFF
    and byte [ebp + wChannelFlags2 + edi], (~(1 << BIT_EXECUTE_MUSIC)) & 0xFF
    cmp al, CHAN7
    jnz .skipSfxChannel3
    ; restart hardware channel 3 (wave channel) output
    mov byte [ebp + rAUD3ENA], AUD3ENA_OFF
    mov byte [ebp + rAUD3ENA], AUD3ENA_ON
.skipSfxChannel3:
    ; ZF still holds the cmp al, CHAN7 result (mov doesn't touch flags):
    ; only the SFX wave channel consults wDisableChannelOutputWhenSfxEnds
    jnz .dontDisable
    mov al, [ebp + wDisableChannelOutputWhenSfxEnds]
    test al, al
    jz .dontDisable
    xor al, al
    mov [ebp + wDisableChannelOutputWhenSfxEnds], al
    jmp .disableChannelOutput
.dontDisable:
    jmp .afterDisable
.returnFromCall:
    and byte [ebp + wChannelFlags1 + edi], (~(1 << BIT_SOUND_CALL)) & 0xFF
    ; restore wChannelCommandPointers[c] from wChannelReturnAddresses[c]
    mov ax, [ebp + wChannelReturnAddresses + edi*2]
    mov [ebp + wChannelCommandPointers + edi*2], ax
    jmp Audio1_sound_ret
.disableChannelOutput:
    movzx edi, bl
    mov al, [ebp + rAUDTERM]
    and al, [Audio1_HWChannelDisableMasks + edi]
    mov [ebp + rAUDTERM], al
.afterDisable:
    mov al, [ebp + wChannelSoundIDs + CHAN5]
    cmp al, CRY_SFX_START
    jae .maybeCry
    jmp .skipCry
.maybeCry:
    cmp al, CRY_SFX_END
    jz .skipCry
    jc .cry
    jmp .skipCry
.cry:
    mov al, bl
    cmp al, CHAN5
    jz .skipRewind
    call Audio1_GoBackOneCommandIfCry
    jnc .skipRewind
    ret                                 ; pret ret c: cry held, keep volume
.skipRewind:
    mov al, [ebp + wSavedVolume]
    mov [ebp + rAUDVOL], al
    xor al, al
    mov [ebp + wSavedVolume], al
.skipCry:
    movzx edi, bl
    mov byte [ebp + wChannelSoundIDs + edi], 0 ; pret ld [hl], b — b = 0 here
    ret

Audio1_sound_call:
    cmp al, 0xFD                        ; sound_call_cmd
    jnz Audio1_sound_loop
    call Audio1_GetNextMusicByte        ; target low byte
    mov cl, al                          ; (pret push af)
    call Audio1_GetNextMusicByte        ; target high byte
    mov dh, al
    mov dl, cl                          ; de = call target
    movzx edi, bl
    mov ax, [ebp + wChannelCommandPointers + edi*2]
    mov [ebp + wChannelReturnAddresses + edi*2], ax  ; save return address
    mov [ebp + wChannelCommandPointers + edi*2], dx  ; jump to target
    or byte [ebp + wChannelFlags1 + edi], 1 << BIT_SOUND_CALL
    jmp Audio1_sound_ret

Audio1_sound_loop:
    cmp al, 0xFE                        ; sound_loop_cmd
    jnz Audio1_note_type
    call Audio1_GetNextMusicByte
    mov dl, al                          ; e = loop count
    test al, al
    jz .infiniteLoop
    movzx edi, bl
    mov al, [ebp + wChannelLoopCounters + edi]
    cmp al, dl
    jnz .loopAgain
    mov byte [ebp + wChannelLoopCounters + edi], 1 ; no more loops to make
    call Audio1_GetNextMusicByte        ; skip pointer
    call Audio1_GetNextMusicByte
    jmp Audio1_sound_ret
.loopAgain:
    inc al
    mov [ebp + wChannelLoopCounters + edi], al
    ; fall through
.infiniteLoop:                          ; overwrite current address with target
    call Audio1_GetNextMusicByte
    mov cl, al                          ; low byte  (pret push af)
    call Audio1_GetNextMusicByte
    mov ch, al                          ; high byte (pret ld b, a)
    movzx edi, bl
    mov [ebp + wChannelCommandPointers + edi*2], cx
    jmp Audio1_sound_ret

Audio1_note_type:
    and al, 0xF0
    cmp al, 0xD0                        ; note_type_cmd
    jnz Audio1_toggle_perfect_pitch
    mov al, dh
    and al, 0x0F
    movzx edi, bl
    mov [ebp + wChannelNoteSpeeds + edi], al ; low nibble = speed
    mov al, bl
    cmp al, CHAN4
    jz .noiseChannel                    ; noise channel (drum_speed): no params
    call Audio1_GetNextMusicByte
    mov dh, al
    mov al, bl
    cmp al, CHAN3
    jz .musicChannel3
    cmp al, CHAN7
    jnz .skipChannel3
    lea esi, [ebp + wSfxWaveInstrument]
    jmp .channel3
.musicChannel3:
    lea esi, [ebp + wMusicWaveInstrument]
.channel3:
    mov al, dh
    and al, 0x0F
    mov [esi], al                       ; low nibble = wave instrument
    mov al, dh
    and al, 0x30
    shl al, 1                           ; -> NR32 output-level bits
    mov dh, al
    ; fall through — channel 3 keeps only the (shifted) volume bits
.skipChannel3:
    movzx edi, bl
    mov [ebp + wChannelVolumes + edi], dh
.noiseChannel:
    jmp Audio1_sound_ret

Audio1_toggle_perfect_pitch:
    mov al, dh
    cmp al, 0xE8                        ; toggle_perfect_pitch_cmd
    jnz Audio1_vibrato
    movzx edi, bl
    xor byte [ebp + wChannelFlags1 + edi], 1 << BIT_PERFECT_PITCH
    jmp Audio1_sound_ret

Audio1_vibrato:
    cmp al, 0xEA                        ; vibrato_cmd
    jnz Audio1_pitch_slide
    call Audio1_GetNextMusicByte
    movzx edi, bl
    mov [ebp + wChannelVibratoDelayCounters + edi], al       ; store delay
    mov [ebp + wChannelVibratoDelayCounterReloadValues + edi], al
    call Audio1_GetNextMusicByte
    mov dh, al
    ; extent n -> hi nibble (n/2)+(n%2) above the note, lo nibble n/2 below
    and al, 0xF0
    rol al, 4                           ; swap a
    shr al, 1                           ; srl a — CF = n%2
    mov dl, al                          ; e = n/2
    adc al, 0                           ; adc b (b=0): + n%2
    rol al, 4                           ; swap a
    or al, dl
    mov [ebp + wChannelVibratoExtents + edi], al
    ; rate -> both nibbles (hi = counter reload value, lo = live counter)
    mov al, dh
    and al, 0x0F
    mov dh, al
    rol al, 4                           ; swap a
    or al, dh
    mov [ebp + wChannelVibratoRates + edi], al
    jmp Audio1_sound_ret

Audio1_pitch_slide:
    cmp al, 0xEB                        ; pitch_slide_cmd
    jnz Audio1_duty_cycle
    call Audio1_GetNextMusicByte
    movzx edi, bl
    mov [ebp + wChannelPitchSlideLengthModifiers + edi], al
    call Audio1_GetNextMusicByte
    mov dh, al
    and al, 0xF0
    rol al, 4                           ; swap a -> stored (8 - octave)
    mov bh, al                          ; b = octave arg
    mov al, dh
    and al, 0x0F                        ; a = pitch
    call Audio1_CalculateFrequency      ; -> de
    movzx edi, bl
    mov [ebp + wChannelPitchSlideTargetFrequencyHighBytes + edi], dh
    mov [ebp + wChannelPitchSlideTargetFrequencyLowBytes + edi], dl
    or byte [ebp + wChannelFlags1 + edi], 1 << BIT_PITCH_SLIDE_ON
    call Audio1_GetNextMusicByte        ; the following note command
    mov dh, al
    jmp Audio1_note_length

Audio1_duty_cycle:
    cmp al, 0xEC                        ; duty_cycle_cmd
    jnz Audio1_tempo
    call Audio1_GetNextMusicByte
    ror al, 1
    ror al, 1                           ; rrca x2: %000000dd -> %dd000000
    and al, 0xC0
    movzx edi, bl
    mov [ebp + wChannelDutyCycles + edi], al
    jmp Audio1_sound_ret

Audio1_tempo:
    cmp al, 0xED                        ; tempo_cmd
    jnz Audio1_stereo_panning
    mov al, bl
    cmp al, CHAN5
    jae .sfxChannel
    call Audio1_GetNextMusicByte
    mov [ebp + wMusicTempo], al         ; first param — hi byte (big-endian)
    call Audio1_GetNextMusicByte
    mov [ebp + wMusicTempo + 1], al     ; second param — lo byte
    xor al, al                          ; clear the music channels' fractions
    mov [ebp + wChannelNoteDelayCountersFractionalPart + 0], al
    mov [ebp + wChannelNoteDelayCountersFractionalPart + 1], al
    mov [ebp + wChannelNoteDelayCountersFractionalPart + 2], al
    mov [ebp + wChannelNoteDelayCountersFractionalPart + 3], al
    jmp .musicChannelDone
.sfxChannel:
    call Audio1_GetNextMusicByte
    mov [ebp + wSfxTempo], al           ; hi byte (big-endian)
    call Audio1_GetNextMusicByte
    mov [ebp + wSfxTempo + 1], al       ; lo byte
    xor al, al                          ; clear the sfx channels' fractions
    mov [ebp + wChannelNoteDelayCountersFractionalPart + 4], al
    mov [ebp + wChannelNoteDelayCountersFractionalPart + 5], al
    mov [ebp + wChannelNoteDelayCountersFractionalPart + 6], al
    mov [ebp + wChannelNoteDelayCountersFractionalPart + 7], al
.musicChannelDone:
    jmp Audio1_sound_ret

Audio1_stereo_panning:
    cmp al, 0xEE                        ; stereo_panning_cmd
    jnz Audio1_unknownmusic0xef
    call Audio1_GetNextMusicByte
    mov [ebp + wStereoPanning], al
    jmp Audio1_sound_ret

; this appears to never be used
Audio1_unknownmusic0xef:
    cmp al, 0xEF                        ; unknownmusic0xef_cmd
    jnz Audio1_duty_cycle_pattern
    call Audio1_GetNextMusicByte
    push ebx
    mov bh, al                          ; b = sound id for the dispatcher
    call DetermineAudioFunction
    pop ebx
    mov al, [ebp + wDisableChannelOutputWhenSfxEnds]
    test al, al
    jnz .skip
    mov al, [ebp + wChannelSoundIDs + CHAN8]
    mov [ebp + wDisableChannelOutputWhenSfxEnds], al
    xor al, al
    mov [ebp + wChannelSoundIDs + CHAN8], al
.skip:
    jmp Audio1_sound_ret

Audio1_duty_cycle_pattern:
    cmp al, 0xFC                        ; duty_cycle_pattern_cmd
    jnz Audio1_volume
    call Audio1_GetNextMusicByte
    movzx edi, bl
    mov [ebp + wChannelDutyCyclePatterns + edi], al ; full pattern
    and al, 0xC0
    mov [ebp + wChannelDutyCycles + edi], al        ; first duty cycle
    or byte [ebp + wChannelFlags1 + edi], 1 << BIT_ROTATE_DUTY_CYCLE
    jmp Audio1_sound_ret

Audio1_volume:
    cmp al, 0xF0                        ; volume_cmd
    jnz Audio1_execute_music
    call Audio1_GetNextMusicByte
    mov [ebp + rAUDVOL], al
    jmp Audio1_sound_ret

Audio1_execute_music:
    cmp al, 0xF8                        ; execute_music_cmd
    jnz Audio1_octave
    movzx edi, bl
    or byte [ebp + wChannelFlags2 + edi], 1 << BIT_EXECUTE_MUSIC
    jmp Audio1_sound_ret

Audio1_octave:
    and al, 0xF0
    cmp al, 0xE0                        ; octave_cmd
    jnz Audio1_sfx_note
    movzx edi, bl
    mov al, dh
    and al, 0x0F
    mov [ebp + wChannelOctaves + edi], al ; low nibble = octave
    jmp Audio1_sound_ret

; sfx_note is either square_note or noise_note depending on the channel
Audio1_sfx_note:
    cmp al, 0x20                        ; sfx_note_cmd (upper nibble)
    jnz Audio1_pitch_sweep
    mov al, bl
    cmp al, CHAN4                       ; noise or sfx channel?
    jb Audio1_pitch_sweep               ; no
    movzx edi, bl
    mov al, [ebp + wChannelFlags2 + edi]
    test al, 1 << BIT_EXECUTE_MUSIC     ; is execute_music being used?
    jnz Audio1_pitch_sweep              ; yes
    call Audio1_note_length             ; -> al = note delay (sound length)
    ; duty | length -> NRx1 (pret notes this duplicates
    ; Audio1_ApplyDutyCycleAndSoundLength below)
    mov dh, al
    movzx edi, bl
    mov al, [ebp + wChannelDutyCycles + edi]
    or al, dh
    mov dh, al
    mov bh, REG_DUTY_SOUND_LEN
    call Audio1_GetRegisterPointer
    mov [ebp + esi], dh
    call Audio1_GetNextMusicByte        ; volume/fade byte
    mov dh, al
    mov bh, REG_VOLUME_ENVELOPE
    call Audio1_GetRegisterPointer
    mov [ebp + esi], dh
    call Audio1_GetNextMusicByte        ; frequency low (or noise poly)
    mov dl, al
    mov al, bl
    cmp al, CHAN8
    mov al, 0                           ; (mov keeps ZF, like SM83 ld)
    jz .skip                            ; noise channel: no freq-hi byte
    push edx
    call Audio1_GetNextMusicByte
    pop edx
.skip:
    mov dh, al
    push edx
    call Audio1_ApplyDutyCycleAndSoundLength
    call Audio1_EnableChannelOutput
    pop edx
    call Audio1_ApplyWavePatternAndFrequency
    ret

Audio1_pitch_sweep:
    mov al, bl
    cmp al, CHAN5
    jb Audio1_note                      ; if not a sfx channel
    mov al, dh
    cmp al, 0x10                        ; pitch_sweep_cmd
    jnz Audio1_note
    movzx edi, bl
    mov al, [ebp + wChannelFlags2 + edi]
    test al, 1 << BIT_EXECUTE_MUSIC
    jnz Audio1_note
    call Audio1_GetNextMusicByte
    mov [ebp + rAUD1SWEEP], al
    jmp Audio1_sound_ret

Audio1_note:
    mov al, bl
    cmp al, CHAN4
    jnz Audio1_note_length              ; not the music noise channel
    mov al, dh
    and al, 0xF0
    cmp al, 0xB0                        ; drum_note_cmd
    jz .drum_note
    jae Audio1_note_length              ; $c0+ (rest etc.)
    ; command id < $b0 on the noise channel: unused 1-byte drum form —
    ; upper nibble is the instrument, lower nibble the length-1
    rol al, 4                           ; swap: a = instrument
    mov cl, al                          ; (pret ld b, a)
    mov al, dh
    and al, 0x0F
    mov dh, al                          ; d = length nibble
    mov al, cl                          ; a = instrument
    push edx                            ; pret push de
    push ebx                            ; pret push bc
    jmp .playDnote
.drum_note:
    mov al, dh
    and al, 0x0F
    mov dh, al                          ; d = length nibble (pret keeps it in
    push edx                            ;  the pushed AF; we park it in DH —
    push ebx                            ;  GetNextMusicByte clobbers DX, so
    call Audio1_GetNextMusicByte        ;  it rides the stack like pret's af)
.playDnote:
    mov dh, al                          ; d = instrument
    mov al, [ebp + wDisableChannelOutputWhenSfxEnds]
    test al, al
    jnz .skipDnote
    mov bh, dh                          ; ld b, d (sound id for dispatcher)
    call DetermineAudioFunction
.skipDnote:
    pop ebx
    pop edx                             ; dh = length nibble (pret pop de)
    ; fall through

; ---------------------------------------------------------------------------
; Computes the note delay: ((len+1) * speed) low byte, times tempo, plus the
; per-channel fractional accumulator; integer part -> delay counter. Music
; notes fall through into Audio1_note_pitch (command byte rides the stack);
; SFX channels outside execute_music return to the caller with AL = delay.
Audio1_note_length:
    mov al, dh
    push eax                            ; pret push af (command byte)
    and al, 0x0F
    inc al
    movzx edx, al                       ; de = note length (in 16ths)
    movzx edi, bl
    mov al, [ebp + wChannelNoteSpeeds + edi]
    xor esi, esi                        ; l = 0
    call Audio1_MultiplyAdd             ; si = length * speed
    mov al, bl
    cmp al, CHAN5
    jae .sfxChannel
    mov dh, [ebp + wMusicTempo]         ; big-endian pair: hi, lo
    mov dl, [ebp + wMusicTempo + 1]
    jmp .skip
.sfxChannel:
    mov dh, 1
    mov dl, 0
    cmp al, CHAN8
    jz .skip                            ; noise channel: tempo = $0100
    call Audio1_SetSfxTempo
    mov dh, [ebp + wSfxTempo]
    mov dl, [ebp + wSfxTempo + 1]
.skip:
    mov eax, esi                        ; a = (length * speed) low byte
    movzx edi, bl
    movzx esi, byte [ebp + wChannelNoteDelayCountersFractionalPart + edi]
    call Audio1_MultiplyAdd             ; si = frac + a * tempo (16-bit wrap)
    mov eax, esi
    mov [ebp + wChannelNoteDelayCountersFractionalPart + edi], al
    shr eax, 8
    mov [ebp + wChannelNoteDelayCounters + edi], al
    mov cl, al                          ; keep delay for the SFX return path
    mov al, [ebp + wChannelFlags2 + edi]
    test al, 1 << BIT_EXECUTE_MUSIC
    jnz Audio1_note_pitch
    mov al, [ebp + wChannelFlags1 + edi]
    test al, 1 << BIT_NOISE_OR_SFX
    jz Audio1_note_pitch
    ; SFX channel: discard the saved command byte and return to
    ; Audio1_sfx_note with a = the note delay (pret pop hl / ret — pret's A
    ; still holds the delay it just stored)
    pop edx
    mov al, cl
    ret

; falls through from Audio1_note_length with the command byte on the stack
Audio1_note_pitch:
    pop eax                             ; pret pop af (command byte)
    and al, 0xF0
    cmp al, 0xC0                        ; rest_cmd
    jnz .notRest
    mov al, bl
    cmp al, CHAN5
    jae .next
    ; music channel: only silence hardware if its SFX twin is idle
    movzx edi, bl
    mov al, [ebp + wChannelSoundIDs + CHAN5 + edi]
    test al, al
    jnz .done
    ; fall through
.next:
    mov al, bl
    cmp al, CHAN3
    jz .channel3
    cmp al, CHAN7
    jnz .notChannel3
.channel3:
    movzx edi, bl
    mov al, [ebp + rAUDTERM]
    and al, [Audio1_HWChannelDisableMasks + edi]
    mov [ebp + rAUDTERM], al            ; disable hw channel 3 output
    jmp .done
.notChannel3:
    mov bh, REG_VOLUME_ENVELOPE
    call Audio1_GetRegisterPointer
    mov byte [ebp + esi], 0x08          ; fade in sound
    mov byte [ebp + esi + 2], 0x80      ; restart sound (NRx4)
.done:
    ret
.notRest:
    rol al, 4                           ; swap: a = pitch
    movzx edi, bl
    mov bh, [ebp + wChannelOctaves + edi] ; b = octave
    call Audio1_CalculateFrequency      ; -> de
    movzx edi, bl
    mov al, [ebp + wChannelFlags1 + edi]
    test al, 1 << BIT_PITCH_SLIDE_ON
    jz .skipPitchSlide
    call Audio1_InitPitchSlideVars
.skipPitchSlide:
    push edx
    mov al, bl
    cmp al, CHAN5
    jae .sfxChannel                     ; if sfx channel
    movzx edi, bl
    mov al, [ebp + wChannelSoundIDs + CHAN5 + edi]
    test al, al
    jnz .noSfx                          ; SFX twin busy: stay silent
    jmp .sfxChannel
.noSfx:
    pop edx
    ret
.sfxChannel:
    movzx edi, bl
    mov dh, [ebp + wChannelVolumes + edi]
    mov bh, REG_VOLUME_ENVELOPE
    call Audio1_GetRegisterPointer
    mov [ebp + esi], dh
    call Audio1_ApplyDutyCycleAndSoundLength
    call Audio1_EnableChannelOutput
    pop edx
    movzx edi, bl
    mov al, [ebp + wChannelFlags1 + edi]
    test al, 1 << BIT_PERFECT_PITCH     ; has toggle_perfect_pitch been used?
    jz .skipFrequencyInc
    inc dl                              ; if yes, increment the frequency
    ; pret follows with `jr nc, .../ inc d`, but SM83 inc never sets CF, so
    ; the carry into D never happens — faithfully omitted (pret comment
    ; calls it out as a harmless mistake).
.skipFrequencyInc:
    movzx edi, bl
    mov [ebp + wChannelFrequencyLowBytes + edi], dl
    call Audio1_ApplyWavePatternAndFrequency
    ret

; ---------------------------------------------------------------------------
Audio1_EnableChannelOutput:
    call Audio1_ApplyMonoStereo         ; -> esi = enable-mask row
    movzx edi, bl
    mov al, [ebp + rAUDTERM]
    or al, [esi + edi]                  ; set this channel's output bits
    mov dh, al
    mov al, bl
    cmp al, CHAN8
    jz .noiseChannelOrNoSfx
    cmp al, CHAN5
    jae .skip                           ; if sfx channel
    mov al, [ebp + wChannelSoundIDs + CHAN5 + edi]
    test al, al
    jnz .skip                           ; SFX twin busy: no re-pan
.noiseChannelOrNoSfx:
    ; apply stereo panning
    mov al, [ebp + wStereoPanning]
    call Audio1_ApplyMonoStereo         ; preserves a, like pret
    and al, [esi + edi]
    mov dh, al
    mov al, [ebp + rAUDTERM]
    and al, [Audio1_HWChannelDisableMasks + edi] ; clear channel's bits
    or al, dh                           ; set the panning-enabled bits
    mov dh, al
.skip:
    mov [ebp + rAUDTERM], dh
    ret

Audio1_ApplyDutyCycleAndSoundLength:
    movzx edi, bl
    mov dh, [ebp + wChannelNoteDelayCounters + edi] ; note delay = length
    mov al, bl
    cmp al, CHAN3
    jz .skipDuty                        ; music wave channel: no duty
    cmp al, CHAN7
    jz .skipDuty                        ; sfx wave channel: no duty
    mov al, dh
    and al, 0x3F
    mov dh, al
    mov al, [ebp + wChannelDutyCycles + edi]
    or al, dh
    mov dh, al
.skipDuty:
    mov bh, REG_DUTY_SOUND_LEN
    call Audio1_GetRegisterPointer
    mov [ebp + esi], dh
    ret

Audio1_ApplyWavePatternAndFrequency:
; de = frequency. For the wave channels, first copy the current wave
; instrument's 16 bytes from the blob into _AUD3WAVERAM.
    mov al, bl
    cmp al, CHAN3
    jz .channel3
    cmp al, CHAN7
    jnz .notChannel3
    ; fall through
.channel3:
    push edx
    lea esi, [ebp + wMusicWaveInstrument]
    cmp al, CHAN3
    jz .next
    lea esi, [ebp + wSfxWaveInstrument]
.next:
    movzx edx, byte [esi]               ; instrument index
    ; Audio1_WavePointers is engine-1 data: always bank 2 = blob slot 0
    movzx edx, word [AudioRom + GB_AUDIO1_WAVEPOINTERS - 0x4000 + edx*2]
    lea edi, [AudioRom + edx - 0x4000]  ; sample bytes in the blob
    mov byte [ebp + rAUD3ENA], AUD3ENA_OFF ; stop hardware channel 3
    lea esi, [ebp + _AUD3WAVERAM]
    mov ecx, AUD3WAVE_SIZE
.loop:
    mov al, [edi]
    inc edi
    mov [esi], al
    inc esi
    dec ecx
    jnz .loop
    mov byte [ebp + rAUD3ENA], AUD3ENA_ON ; start hardware channel 3
    pop edx
.notChannel3:
    mov al, dh
    or al, 0x80                         ; counter mode / restart (NRx4 bit 7)
    and al, 0xC7                        ; zero the unused bits
    mov dh, al
    mov bh, REG_FREQUENCY_LO
    call Audio1_GetRegisterPointer
    mov [ebp + esi], dl                 ; frequency low byte
    mov [ebp + esi + 1], dh             ; frequency high byte (NRx4)
    mov al, bl
    cmp al, CHAN5                       ; pret cp $4 (music channels skip)
    jb .asm_9642
    call Audio1_ApplyFrequencyModifier
.asm_9642:
    ret

Audio1_SetSfxTempo:
    call Audio1_IsCry
    jc .isCry
    call Audio1_IsBattleSFX
    jnc .notCry
.isCry:
    mov dh, 0
    mov al, [ebp + wTempoModifier]
    add al, 0x80
    jnc .next
    inc dh
.next:
    mov [ebp + wSfxTempo + 1], al       ; lo byte (big-endian pair)
    mov [ebp + wSfxTempo], dh           ; hi byte
    ret
.notCry:
    xor al, al
    mov [ebp + wSfxTempo + 1], al
    inc al
    mov [ebp + wSfxTempo], al           ; sfx tempo = $0100
    ret

Audio1_ApplyFrequencyModifier:
; Called right after the frequency write; esi still addresses the freq-lo
; register (pret's HL sits one past, at NRx4, and dec's back — same cells).
    call Audio1_IsCry
    jc .isCry
    call Audio1_IsBattleSFX
    jnc .done
.isCry:
    ; add the cry's frequency modifier to the just-written frequency
    mov al, [ebp + wFrequencyModifier]
    add al, dl
    jnc .noCarry
    inc dh
.noCarry:
    mov dl, al
    mov [ebp + esi], dl
    mov [ebp + esi + 1], dh
.done:
    ret

Audio1_GoBackOneCommandIfCry:
    call Audio1_IsCry
    jnc .done
    movzx edi, bl
    mov ax, [ebp + wChannelCommandPointers + edi*2]
    dec ax                              ; sub 1 / sbc 0 = 16-bit step back
    mov [ebp + wChannelCommandPointers + edi*2], ax
    stc
    ret
.done:
    clc                                 ; pret and a
    ret

Audio1_IsCry:
; Returns whether the currently playing audio is a cry in carry.
    mov al, [ebp + wChannelSoundIDs + CHAN5]
    cmp al, CRY_SFX_START
    jae .next
    jmp .no
.next:
    cmp al, CRY_SFX_END
    jz .no
    jc .yes
.no:
    clc
    ret
.yes:
    stc
    ret

Audio1_IsBattleSFX:
; Returns whether the currently playing audio is a battle sfx in carry.
    mov al, [ebp + wAudioROMBank]
    cmp al, AUDIO_BANK_2
    jnz .no
    mov al, [ebp + wChannelSoundIDs + CHAN8]
    mov cl, al
    mov al, [ebp + wChannelSoundIDs + CHAN5]
    or al, cl
    cmp al, BATTLE_SFX_START
    jb .no
    cmp al, BATTLE_SFX_END
    jz .yes
    jc .yes
.no:
    clc
    ret
.yes:
    stc
    ret

; ---------------------------------------------------------------------------
Audio1_ApplyPitchSlide:
    movzx edi, bl
    mov al, [ebp + wChannelFlags1 + edi]
    test al, 1 << BIT_PITCH_SLIDE_DECREASING
    jnz .frequencyDecreasing
    ; frequency increasing
    mov dl, [ebp + wChannelPitchSlideCurrentFrequencyLowBytes + edi]
    mov dh, [ebp + wChannelPitchSlideCurrentFrequencyHighBytes + edi]
    movzx ecx, byte [ebp + wChannelPitchSlideFrequencySteps + edi]
    add dx, cx                          ; de += steps
    mov al, [ebp + wChannelPitchSlideFrequencyStepsFractionalPart + edi]
    add al, [ebp + wChannelPitchSlideCurrentFrequencyFractionalPart + edi]
    mov [ebp + wChannelPitchSlideCurrentFrequencyFractionalPart + edi], al
    adc dl, 0                           ; carry from the fraction add
    adc dh, 0                           ;  ... propagates through de
    mov al, [ebp + wChannelPitchSlideTargetFrequencyHighBytes + edi]
    cmp al, dh
    jc .reachedTargetFrequency
    jnz .applyUpdatedFrequency
    mov al, [ebp + wChannelPitchSlideTargetFrequencyLowBytes + edi]
    cmp al, dl
    jc .reachedTargetFrequency
    jmp .applyUpdatedFrequency
.frequencyDecreasing:
    mov al, [ebp + wChannelPitchSlideCurrentFrequencyLowBytes + edi]
    mov dh, [ebp + wChannelPitchSlideCurrentFrequencyHighBytes + edi]
    mov dl, [ebp + wChannelPitchSlideFrequencySteps + edi]
    sub al, dl
    mov dl, al
    mov al, dh
    sbb al, 0
    mov dh, al
    ; the step fraction doubles each tick in the decreasing path (pret
    ; quirk: `add a` on the stored value) and its carry drains from de
    mov al, [ebp + wChannelPitchSlideFrequencyStepsFractionalPart + edi]
    add al, al
    mov [ebp + wChannelPitchSlideFrequencyStepsFractionalPart + edi], al
    mov al, dl
    sbb al, 0
    mov dl, al
    mov al, dh
    sbb al, 0
    mov dh, al
    mov al, dh
    cmp al, [ebp + wChannelPitchSlideTargetFrequencyHighBytes + edi]
    jc .reachedTargetFrequency
    jnz .applyUpdatedFrequency
    mov al, dl
    cmp al, [ebp + wChannelPitchSlideTargetFrequencyLowBytes + edi]
    jc .reachedTargetFrequency
.applyUpdatedFrequency:
    mov [ebp + wChannelPitchSlideCurrentFrequencyLowBytes + edi], dl
    mov [ebp + wChannelPitchSlideCurrentFrequencyHighBytes + edi], dh
    mov bh, REG_FREQUENCY_LO
    call Audio1_GetRegisterPointer
    mov [ebp + esi], dl
    mov [ebp + esi + 1], dh
    ret
.reachedTargetFrequency:
    ; turn off pitch slide when the target frequency has been reached
    movzx edi, bl
    mov al, [ebp + wChannelFlags1 + edi]
    and al, (~((1 << BIT_PITCH_SLIDE_ON) | (1 << BIT_PITCH_SLIDE_DECREASING))) & 0xFF
    mov [ebp + wChannelFlags1 + edi], al
    ret

Audio1_InitPitchSlideVars:
; de = the new note's frequency (becomes the slide's starting point)
    movzx edi, bl
    mov [ebp + wChannelPitchSlideCurrentFrequencyHighBytes + edi], dh
    mov [ebp + wChannelPitchSlideCurrentFrequencyLowBytes + edi], dl
    mov al, [ebp + wChannelNoteDelayCounters + edi]
    sub al, [ebp + wChannelPitchSlideLengthModifiers + edi]
    jnc .next
    mov al, 1
.next:
    mov [ebp + wChannelPitchSlideLengthModifiers + edi], al
    mov al, dl
    sub al, [ebp + wChannelPitchSlideTargetFrequencyLowBytes + edi]
    mov dl, al
    mov al, dh
    sbb al, 0
    sub al, [ebp + wChannelPitchSlideTargetFrequencyHighBytes + edi]
    jc .targetFrequencyGreater
    mov dh, al
    or byte [ebp + wChannelFlags1 + edi], 1 << BIT_PITCH_SLIDE_DECREASING
    jmp .next2
.targetFrequencyGreater:
    ; target > current: compute target - current as the slide span
    mov dh, [ebp + wChannelPitchSlideCurrentFrequencyHighBytes + edi]
    mov dl, [ebp + wChannelPitchSlideCurrentFrequencyLowBytes + edi]
    mov al, [ebp + wChannelPitchSlideTargetFrequencyLowBytes + edi]
    sub al, dl
    mov dl, al
    ; BUG: pret borrows from the CURRENT frequency's high byte instead of
    ; the target's, so the span is $200 too large when cur.lo > target.lo.
    ; Faithfully reproduced — the audible quirk is part of the original.
    mov al, dh
    sbb al, 0
    mov dh, al
    mov al, [ebp + wChannelPitchSlideTargetFrequencyHighBytes + edi]
    sub al, dh
    mov dh, al
    and byte [ebp + wChannelFlags1 + edi], (~(1 << BIT_PITCH_SLIDE_DECREASING)) & 0xFF
.next2:
    ; divide the span by the slide length: (quotient+1) -> whole steps,
    ; (remainder - divisor) -> both fractional accumulators
    mov ch, 0                           ; quotient counter (pret b)
    mov cl, [ebp + wChannelPitchSlideLengthModifiers + edi]
.divideLoop:
    inc ch
    mov al, dl
    sub al, cl
    mov dl, al
    jnc .divideLoop
    mov al, dh
    test al, al
    jz .doneDividing
    dec al
    mov dh, al
    jmp .divideLoop
.doneDividing:
    mov al, dl                          ; a = remainder - divisor
    add al, cl
    mov dh, ch                          ; d = quotient + 1
    mov [ebp + wChannelPitchSlideFrequencySteps + edi], dh
    mov [ebp + wChannelPitchSlideFrequencyStepsFractionalPart + edi], al
    mov [ebp + wChannelPitchSlideCurrentFrequencyFractionalPart + edi], al
    ret

Audio1_ApplyDutyCyclePattern:
    movzx edi, bl
    mov al, [ebp + wChannelDutyCyclePatterns + edi]
    rol al, 1
    rol al, 1                           ; rlca x2: rotate to the next duty
    mov [ebp + wChannelDutyCyclePatterns + edi], al
    and al, 0xC0
    mov dh, al
    mov bh, REG_DUTY_SOUND_LEN
    call Audio1_GetRegisterPointer
    mov al, [ebp + esi]
    and al, 0x3F
    or al, dh
    mov [ebp + esi], al
    ret

Audio1_GetNextMusicByte:
    call GetNextMusicByte
    ret

; ---------------------------------------------------------------------------
; esi = GB address ($FFxx) of hardware sound register b (BH) for software
; channel c (BL); writes then go through [ebp + esi] into the virtual APU.
Audio1_GetRegisterPointer:
    movzx edi, bl
    movzx esi, byte [Audio1_HWChannelBaseAddresses + edi]
    movzx eax, bh
    add esi, eax
    or esi, 0xFF00
    ret

; ---------------------------------------------------------------------------
; si = si.low8 + (al * dx), all 16-bit wrap — pret's hl = l + a*de.
Audio1_MultiplyAdd:
    and esi, 0xFF                       ; ld h, 0 (and clear stale upper bits)
.loop:
    shr al, 1
    jnc .skipAdd
    add si, dx                          ; 16-bit add, wraps like SM83
.skipAdd:
    shl dx, 1                           ; sla e / rl d (top bit falls off)
    test al, al
    jz .done
    jmp .loop
.done:
    ret

; ---------------------------------------------------------------------------
; return the frequency for note a, octave b (BH) in de
Audio1_CalculateFrequency:
    movzx esi, al
    ; Audio1_Pitches is engine-1 data: bank 2 = blob slot 0
    movzx edx, word [AudioRom + GB_AUDIO1_PITCHES - 0x4000 + esi*2]
    mov al, bh
.loop:
    cmp al, 7
    jz .done
    sar dx, 1                           ; sra d / rr e (16-bit arithmetic)
    inc al
    jmp .loop
.done:
    mov al, 8
    add al, dh
    mov dh, al
    ret

; ===========================================================================
; Audio1_PlaySound / AudioCommon_PlaySound — see file header. EDI = params:
;   [edi+0] dd  blob base (= AudioRom + slot*0x4000; headers start there)
;   [edi+4] db  MAX_SFX_ID_N
;   [edi+5] db  music-id boundary (engines 1,2: $fe; 3: $fd; 4: $a3)
;   [edi+6] dw  AudioN_CryRet GB address
; ===========================================================================
Audio1_PlaySound:
    mov edi, audio1_params
    jmp AudioCommon_PlaySound

; a = sound id, EDI = per-engine parameter block.
AudioCommon_PlaySound:
    mov [ebp + wSoundID], al
    mov al, [ebp + wSoundID]
    cmp al, SFX_STOP_ALL_MUSIC
    jz .stopAllAudio
    cmp al, [edi + 4]                   ; MAX_SFX_ID_N
    jz .playSfx
    jc .playSfx
    cmp al, [edi + 5]                   ; music boundary
    jz .playMusic
    ja .playSfx
    ; fall through: ids between MAX_SFX_ID and the boundary are music

.playMusic:
    ; port: in MIDI mode the MT-32/GM stream carries the song (mpu401.asm);
    ; the engine still initializes and runs the music for authentic
    ; bookkeeping/fades, muted on FM by opl_shim's voice_volume.
    call midi_seq_start
    call InitMusicVariables
    jmp .playSoundCommon

.playSfx:
    ; header GB address = $4000 + id*3, cached big-endian like pret's
    ; wSfxHeaderPointer; scan the channel entries last-to-first
    movzx esi, al
    lea esi, [esi + esi*2]              ; id * 3
    add esi, 0x4000
    mov eax, esi
    mov [ebp + wSfxHeaderPointer], ah   ; hi first (big-endian)
    mov [ebp + wSfxHeaderPointer + 1], al
    mov edx, [edi]                      ; blob base
    mov al, [edx + esi - 0x4000]        ; first header byte
    and al, 0xC0
    rol al, 1
    rol al, 1                           ; -> channel count - 1
    mov bl, al                          ; c = entry index (count-1 .. 0)
.sfxChannelLoop:
    mov ah, [ebp + wSfxHeaderPointer]
    mov al, [ebp + wSfxHeaderPointer + 1]
    movzx esi, ax
    movzx ecx, bl
    lea ecx, [ecx + ecx*2]              ; entry offset = index*3
    add esi, ecx
    mov edx, [edi]
    mov al, [edx + esi - 0x4000]        ; entry's dn byte
    and al, 0x0F
    movzx ecx, al                       ; e = software channel id
    mov al, [ebp + wChannelSoundIDs + ecx]
    test al, al
    jz .playChannel
    mov al, cl
    cmp al, CHAN8
    jnz .notNoiseChannel
    mov al, [ebp + wSoundID]
    cmp al, NOISE_INSTRUMENTS_END
    jae .notNoiseInstrument
    ret                                 ; noise instrument never interrupts
.notNoiseInstrument:
    mov al, [ebp + wChannelSoundIDs + ecx]
    cmp al, NOISE_INSTRUMENTS_END
    jz .playChannel
    jc .playChannel
.notNoiseChannel:
    mov al, [ebp + wSoundID]
    cmp al, [ebp + wChannelSoundIDs + ecx]
    jz .playChannel
    jc .playChannel
    ret                                 ; lower-priority sound: dropped
.playChannel:
    mov dx, cx                          ; de = channel id
    call InitSFXVariables               ; (preserves EBX/ECX/EDX/ESI/EDI)
    mov al, bl
    test al, al
    jz .playSoundCommon
    dec bl
    jmp .sfxChannelLoop

.stopAllAudio:
    call midi_seq_stop                  ; port: silence the MIDI stream too
    call StopAllAudio
    ret

.playSoundCommon:
    ; walk the header's channel entries, pointing each software channel at
    ; its stream and stamping the sound id. pret walks a hl pointer down
    ; wChannelCommandPointers entry by entry; the port indexes directly —
    ; same effect, 386 idiom.
    mov al, [ebp + wSoundID]
    movzx esi, al
    lea esi, [esi + esi*2]              ; id * 3
    mov edx, [edi]                      ; blob base (headers at +0)
    lea edx, [edx + esi]                ; entry pointer (linear)
    mov al, [edx]                       ; dn byte: count-1 in bits 7-6
    mov ch, al
    rol al, 1
    rol al, 1
    and al, 0x03
    mov cl, al
    inc cl                              ; cl = channel count
    mov al, ch
    and al, 0x0F                        ; al = first channel id
    inc edx
.entryLoop:
    movzx esi, al
    cmp al, CHAN4
    jb .skipSettingFlag
    or byte [ebp + wChannelFlags1 + esi], 1 << BIT_NOISE_OR_SFX
.skipSettingFlag:
    mov ax, [edx]                       ; channel data pointer (LE, as ROM)
    add edx, 2
    mov [ebp + wChannelCommandPointers + esi*2], ax
    mov al, [ebp + wSoundID]
    mov [ebp + wChannelSoundIDs + esi], al
    dec cl
    jz .channelsDone
    mov al, [edx]                       ; next entry's dn byte (count bits 0)
    inc edx
    and al, 0x0F
    jmp .entryLoop
.channelsDone:
    mov al, [ebp + wSoundID]
    cmp al, CRY_SFX_START
    jae .maybeCry
    jmp .done
.maybeCry:
    cmp al, CRY_SFX_END
    jz .done
    jc .cry
    jmp .done
.cry:
    ; a cry owns all four SFX channels; the SFX wave channel is pointed at
    ; AudioN_CryRet (a lone in-blob sound_ret)
    mov [ebp + wChannelSoundIDs + CHAN5], al
    mov [ebp + wChannelSoundIDs + CHAN6], al
    mov [ebp + wChannelSoundIDs + CHAN7], al
    mov [ebp + wChannelSoundIDs + CHAN8], al
    mov ax, [edi + 6]                   ; AudioN_CryRet GB address
    mov [ebp + wChannelCommandPointers + CHAN7*2], ax
    mov al, [ebp + wSavedVolume]
    test al, al
    jnz .done
    mov al, [ebp + rAUDVOL]
    mov [ebp + wSavedVolume], al
    mov byte [ebp + rAUDVOL], 0x77      ; full volume
.done:
    ret

; ---------------------------------------------------------------------------
; esi = enable-mask row for the current wOptions sound setting (mono /
; earphone 1-3). Preserves a and the other engine registers, like pret.
Audio1_ApplyMonoStereo:
    push eax
    mov al, [ebp + W_OPTIONS]
    and al, SOUND_MASK
    shr al, 1                           ; $00/$10/$20/$30 -> 0/8/16/24
    movzx esi, al
    add esi, Audio1_HWChannelEnableMasks
    pop eax
    ret

section .data

Audio1_HWChannelBaseAddresses:
; the low bytes of each HW channel's register-file base address
    db AUD1RAM & 0xFF, AUD2RAM & 0xFF, AUD3RAM & 0xFF, AUD4RAM & 0xFF
    db AUD1RAM & 0xFF, AUD2RAM & 0xFF, AUD3RAM & 0xFF, AUD4RAM & 0xFF

Audio1_HWChannelDisableMasks:
    db 0xEE, 0xDD, 0xBB, 0x77           ; ~(chN left|right)
    db 0xEE, 0xDD, 0xBB, 0x77

Audio1_HWChannelEnableMasks:
    ; mono
    db 0x11, 0x22, 0x44, 0x88
    db 0x11, 0x22, 0x44, 0x88
    ; earphone 1
    db 0x01, 0x20, 0x44, 0x88
    db 0x11, 0x22, 0x44, 0x88
    ; earphone 2
    db 0x01, 0x20, 0x04, 0x80
    db 0x01, 0x20, 0x04, 0x80
    ; earphone 3
    db 0x01, 0x02, 0x40, 0x80
    db 0x01, 0x02, 0x40, 0x80

audio1_params:
    dd AudioRom + 0*0x4000
    db MAX_SFX_ID_1
    db 0xFE
    dw GB_AUDIO1_CRYRET
