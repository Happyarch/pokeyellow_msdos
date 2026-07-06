; audio_hal.asm — port-only audio HAL glue (no pret counterpart; descriptive
; names per convention).
;
; audio_tick runs once per DelayFrame, immediately after the hFrameCounter
; decrement, replicating pret home/vblank.asm's audio block order:
;   FadeOutAudio -> Music_DoLowHealthAlarm -> Audio1_UpdateMusic
; (pret bankswitches around the latter two; the port's engine is resident and
; Audio1_UpdateMusic is the single interpreter for all four banks). The
; device-shim pass (opl_shim) hooks in after the engine update: it reads the
; virtual APU block at [ebp+rAUD*] once per tick and mirrors it to hardware,
; consuming the NRx4 restart bits. DelayFrame is pushad-wrapped, so the tick
; may clobber registers freely.
;
; audio_init flips g_audio_engine_online (the PlaySound gate in
; src/home/audio.asm) and then runs the pret boot-path engine reset
; (StopAllSounds -> StopAllMusic -> PlaySound($ff) -> Audio2_StopAllAudio) so
; every engine variable (tempos, note delays, stereo mask, virtual APU regs)
; starts in GB power-on state. The flag must be set FIRST or the reset itself
; would be swallowed by the gate.

global audio_tick
global audio_init
global audio_shutdown

extern FadeOutAudio               ; src/home/audio.asm
extern Music_DoLowHealthAlarm     ; src/audio/low_health_alarm.asm
extern Audio1_UpdateMusic         ; src/audio/engine_1.asm
extern StopAllSounds              ; src/init/init.asm
extern g_audio_engine_online      ; src/home/audio.asm
extern opl_init                   ; src/audio/opl_shim.asm
extern opl_pass                   ; src/audio/opl_shim.asm
extern opl_shutdown               ; src/audio/opl_shim.asm

section .text

audio_tick:
    cmp byte [g_audio_engine_online], 0
    jz .off
    call FadeOutAudio
    call Music_DoLowHealthAlarm
    call Audio1_UpdateMusic
    call opl_pass                 ; virtual APU -> FM (no-ops if no OPL found)
.off:
    ret

audio_init:
    call opl_init                 ; detect + reset the OPL (388h)
    mov byte [g_audio_engine_online], 1
    call StopAllSounds
    ret

audio_shutdown:
    mov byte [g_audio_engine_online], 0
    call opl_shutdown             ; leave the FM chip silent
    ret
