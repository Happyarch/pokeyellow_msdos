; low_health_alarm.asm — pret audio/low_health_alarm.asm translated to x86.
;
; Music_DoLowHealthAlarm runs once per audio tick (between FadeOutAudio and
; Audio1_UpdateMusic, pret home/vblank.asm order) and drives the in-battle
; low-HP beep by writing pulse-channel-1 registers directly, overriding the
; engine (it parks CRY_SFX_END in wChannelSoundIDs+CHAN5 so the music channel
; stays ducked while the alarm owns the hardware channel).
;
; Register map: A=AL, BC=BX, DE=DX, HL=ESI, EBP = GB memory base.

%include "gb_memmap.inc"
%include "assets/audio_constants.inc"

global Music_DoLowHealthAlarm

section .text

Music_DoLowHealthAlarm:
    mov al, [ebp + wLowHealthAlarm]
    cmp al, DISABLE_LOW_HEALTH_ALARM
    jz .disableAlarm

    test al, 1 << BIT_LOW_HEALTH_ALARM
    jz .off                             ; pret ret z — alarm not enabled

    and al, LOW_HEALTH_TIMER_MASK
    jnz .notToneHi                      ; if timer > 0, play low tone.

    call .playToneHi
    mov al, 30                          ; keep this tone for 30 frames.
    jmp .resetTimer

.notToneHi:
    cmp al, 20
    jnz .noTone                         ; if timer == 20,
    call .playToneLo                    ; actually set the sound registers.

.noTone:
    mov al, CRY_SFX_END
    mov [ebp + wChannelSoundIDs + CHAN5], al  ; disable sound channel?
    mov al, [ebp + wLowHealthAlarm]
    and al, LOW_HEALTH_TIMER_MASK
    dec al

.resetTimer:
    ; reset the timer and enable flag.
    or al, 1 << BIT_LOW_HEALTH_ALARM
    mov [ebp + wLowHealthAlarm], al
.off:
    ret

.disableAlarm:
    xor al, al
    mov [ebp + wLowHealthAlarm], al               ; disable alarm
    mov [ebp + wChannelSoundIDs + CHAN5], al      ; re-enable sound channel?
    mov edx, .toneDataSilence
    jmp .playTone

; update the sound registers to change the frequency.
; the tone set here stays until we change it.
.playToneHi:
    mov edx, .toneDataHi
    jmp .playTone

.playToneLo:
    mov edx, .toneDataLo

; update sound channel 1 to play the alarm, overriding all other sounds.
; de (EDX) = tone data (a linear pointer here; pret's was a ROM address).
.playTone:
    mov esi, rAUD1SWEEP                 ; channel 1 sound register
    mov cl, 5
    xor al, al
.copyLoop:
    mov [ebp + esi], al                 ; FF10 <- 0, then FF11..FF14 <- data
    inc esi
    mov al, [edx]
    inc edx
    dec cl
    jnz .copyLoop
    ret

section .data

; bytes to write to sound channel 1 registers for health alarm.
; starting at FF11 (FF10 is always zeroed). alarm_tone: length, envelope,
; frequency (dw, emitted LE like the ROM: lo byte lands in FF13, hi in FF14).
Music_DoLowHealthAlarm.toneDataHi:
    db 0xA0, 0xE2
    dw 0x8750

Music_DoLowHealthAlarm.toneDataLo:
    db 0xB0, 0xE2
    dw 0x86EE

; written to stop the alarm
Music_DoLowHealthAlarm.toneDataSilence:
    db 0x00, 0x00
    dw 0x8000
