; engine_2.asm — pret audio/engine_2.asm translated to x86.
;
; Engine 2 (GB bank $08) is Audio2_PlaySound plus the engine's shared
; init/reset helpers — the bytecode interpreter itself lives only in
; engine_1.asm (Audio1_UpdateMusic ticks every channel regardless of bank).
; Audio2_PlaySound shares AudioCommon_PlaySound (engine_1.asm) via its
; parameter block: pret's four near-identical PlaySound copies differ only
; in header base / MAX_SFX_ID / music-id boundary / CryRet address.
;
; The Audio2_* helpers are reached through the home wrappers
; (InitMusicVariables / InitSFXVariables / StopAllAudio in src/home/audio.asm)
; whose push/pop shell preserves all registers but EAX — so these bodies may
; clobber freely, like their banked pret originals.
;
; Register map: A=AL, BC=BX, DE=DX, HL=ESI, EBP = GB memory base.

%include "gb_memmap.inc"
%include "assets/audio_constants.inc"

global Audio2_PlaySound
global Audio2_InitMusicVariables
global Audio2_InitSFXVariables
global Audio2_StopAllAudio

extern AudioCommon_PlaySound      ; src/audio/engine_1.asm
extern AudioRom                   ; src/data/audio_data.asm

section .text

Audio2_PlaySound:
    mov edi, audio2_params
    jmp AudioCommon_PlaySound

; ---------------------------------------------------------------------------
Audio2_InitMusicVariables:
    xor al, al
    mov [ebp + wUnusedMusicByte], al
    mov [ebp + wDisableChannelOutputWhenSfxEnds], al
    mov [ebp + wMusicTempo + 1], al
    mov [ebp + wMusicWaveInstrument], al
    mov [ebp + wSfxWaveInstrument], al
    mov dh, NUM_CHANNELS                ; pret quirk kept: clears only the
    mov esi, wChannelReturnAddresses    ; first 8 BYTES of these two dw arrays
    call Audio2_FillMem
    mov esi, wChannelCommandPointers
    call Audio2_FillMem
    mov dh, NUM_MUSIC_CHANS
    mov esi, wChannelSoundIDs
    call Audio2_FillMem
    mov esi, wChannelFlags1
    call Audio2_FillMem
    mov esi, wChannelDutyCycles
    call Audio2_FillMem
    mov esi, wChannelDutyCyclePatterns
    call Audio2_FillMem
    mov esi, wChannelVibratoDelayCounters
    call Audio2_FillMem
    mov esi, wChannelVibratoExtents
    call Audio2_FillMem
    mov esi, wChannelVibratoRates
    call Audio2_FillMem
    mov esi, wChannelFrequencyLowBytes
    call Audio2_FillMem
    mov esi, wChannelVibratoDelayCounterReloadValues
    call Audio2_FillMem
    mov esi, wChannelFlags2
    call Audio2_FillMem
    mov esi, wChannelPitchSlideLengthModifiers
    call Audio2_FillMem
    mov esi, wChannelPitchSlideFrequencySteps
    call Audio2_FillMem
    mov esi, wChannelPitchSlideFrequencyStepsFractionalPart
    call Audio2_FillMem
    mov esi, wChannelPitchSlideCurrentFrequencyFractionalPart
    call Audio2_FillMem
    mov esi, wChannelPitchSlideCurrentFrequencyHighBytes
    call Audio2_FillMem
    mov esi, wChannelPitchSlideCurrentFrequencyLowBytes
    call Audio2_FillMem
    mov esi, wChannelPitchSlideTargetFrequencyHighBytes
    call Audio2_FillMem
    mov esi, wChannelPitchSlideTargetFrequencyLowBytes
    call Audio2_FillMem
    mov al, 1
    mov esi, wChannelLoopCounters
    call Audio2_FillMem
    mov esi, wChannelNoteDelayCounters
    call Audio2_FillMem
    mov esi, wChannelNoteSpeeds
    call Audio2_FillMem
    mov [ebp + wMusicTempo], al         ; tempo = $0100 (hi byte, big-endian)
    mov al, 0xFF
    mov [ebp + wStereoPanning], al
    xor al, al
    mov [ebp + rAUDVOL], al
    mov al, AUD1SWEEP_DOWN
    mov [ebp + rAUD1SWEEP], al
    mov al, 0
    mov [ebp + rAUDTERM], al
    xor al, al
    mov [ebp + rAUD3ENA], al
    mov al, AUD3ENA_ON
    mov [ebp + rAUD3ENA], al
    mov al, 0x77
    mov [ebp + rAUDVOL], al
    ret

; ---------------------------------------------------------------------------
; e (DL) = software channel to reset (d = 0).
Audio2_InitSFXVariables:
    xor al, al
    movzx edi, dl
    mov [ebp + wChannelReturnAddresses + edi*2], al
    mov [ebp + wChannelReturnAddresses + edi*2 + 1], al
    mov [ebp + wChannelCommandPointers + edi*2], al
    mov [ebp + wChannelCommandPointers + edi*2 + 1], al
    mov [ebp + wChannelSoundIDs + edi], al
    mov [ebp + wChannelFlags1 + edi], al
    mov [ebp + wChannelDutyCycles + edi], al
    mov [ebp + wChannelDutyCyclePatterns + edi], al
    mov [ebp + wChannelVibratoDelayCounters + edi], al
    mov [ebp + wChannelVibratoExtents + edi], al
    mov [ebp + wChannelVibratoRates + edi], al
    mov [ebp + wChannelFrequencyLowBytes + edi], al
    mov [ebp + wChannelVibratoDelayCounterReloadValues + edi], al
    mov [ebp + wChannelPitchSlideLengthModifiers + edi], al
    mov [ebp + wChannelPitchSlideFrequencySteps + edi], al
    mov [ebp + wChannelPitchSlideFrequencyStepsFractionalPart + edi], al
    mov [ebp + wChannelPitchSlideCurrentFrequencyFractionalPart + edi], al
    mov [ebp + wChannelPitchSlideCurrentFrequencyHighBytes + edi], al
    mov [ebp + wChannelPitchSlideCurrentFrequencyLowBytes + edi], al
    mov [ebp + wChannelPitchSlideTargetFrequencyHighBytes + edi], al
    mov [ebp + wChannelPitchSlideTargetFrequencyLowBytes + edi], al
    mov [ebp + wChannelFlags2 + edi], al
    mov al, 1
    mov [ebp + wChannelLoopCounters + edi], al
    mov [ebp + wChannelNoteDelayCounters + edi], al
    mov [ebp + wChannelNoteSpeeds + edi], al
    mov al, dl
    cmp al, CHAN5
    jnz .done
    mov al, AUD1SWEEP_DOWN
    mov [ebp + rAUD1SWEEP], al          ; sweep off
.done:
    ret

; ---------------------------------------------------------------------------
Audio2_StopAllAudio:
    mov al, AUDENA_ON
    mov [ebp + rAUDENA], al             ; sound hardware on
    mov [ebp + rAUD3ENA], al            ; wave playback on
    xor al, al
    mov [ebp + rAUDTERM], al            ; no sound output
    mov [ebp + rAUD3LEVEL], al          ; mute channel 3 (wave channel)
    mov al, AUD1SWEEP_DOWN
    mov [ebp + rAUD1SWEEP], al          ; sweep off
    mov [ebp + rAUD1ENV], al            ; mute channel 1 (pulse channel 1)
    mov [ebp + rAUD2ENV], al            ; mute channel 2 (pulse channel 2)
    mov [ebp + rAUD4ENV], al            ; mute channel 4 (noise channel)
    mov al, AUD1HIGH_LENGTH_ON
    mov [ebp + rAUD1HIGH], al           ; counter mode
    mov [ebp + rAUD2HIGH], al
    mov [ebp + rAUD4GO], al
    mov al, 0x77
    mov [ebp + rAUDVOL], al             ; full volume
    xor al, al
    mov [ebp + wUnusedMusicByte], al
    mov [ebp + wDisableChannelOutputWhenSfxEnds], al
    mov [ebp + wMuteAudioAndPauseMusic], al
    mov [ebp + wMusicTempo + 1], al
    mov [ebp + wSfxTempo + 1], al
    mov [ebp + wMusicWaveInstrument], al
    mov [ebp + wSfxWaveInstrument], al
    mov dh, 0xB0
    mov esi, wChannelCommandPointers
    call Audio2_FillMem
    mov al, 1
    mov dh, 0x18
    mov esi, wChannelNoteDelayCounters
    call Audio2_FillMem
    mov [ebp + wMusicTempo], al         ; tempos = $0100 (hi bytes)
    mov [ebp + wSfxTempo], al
    mov al, 0xFF
    mov [ebp + wStereoPanning], al
    ret

; fills d (DH) bytes at hl (ESI) with a (AL)
Audio2_FillMem:
    mov bh, dh
.loop:
    mov [ebp + esi], al
    inc esi
    dec bh
    jnz .loop
    ret

section .data

audio2_params:
    dd AudioRom + 1*0x4000              ; bank $08 = blob slot 1
    db MAX_SFX_ID_2
    db 0xFE                             ; music-id boundary
    dw GB_AUDIO2_CRYRET
