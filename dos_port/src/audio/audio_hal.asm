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
global g_cfg_nosound
global g_sb_base
global g_sb_irq
global g_sb_dma
global g_sb_present
global g_sb_dsp_ver

extern FadeOutAudio               ; src/home/audio.asm
extern Music_DoLowHealthAlarm     ; src/audio/low_health_alarm.asm
extern Audio1_UpdateMusic         ; src/audio/engine_1.asm
extern StopAllSounds              ; src/init/init.asm
extern g_audio_engine_online      ; src/home/audio.asm
extern opl_init                   ; src/audio/opl_shim.asm
extern opl_pass                   ; src/audio/opl_shim.asm
extern opl_shutdown               ; src/audio/opl_shim.asm
extern ds_base                    ; boot/entry.asm — linear base of DS
extern seg_to_flat                ; boot/entry.asm — selector/segment -> flat

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
    cmp byte [g_cfg_nosound], 0   ; /NOSOUND: no probes, engine stays offline
    jnz .off
    call audio_parse_blaster      ; BLASTER env -> g_sb_base/irq/dma
    call dsp_detect               ; DSP reset + E1h version (Phase C consumer)
    call opl_init                 ; detect + reset the OPL (388h)
    mov byte [g_audio_engine_online], 1
    call StopAllSounds
.off:
    ret

audio_shutdown:
    mov byte [g_audio_engine_online], 0
    call opl_shutdown             ; leave the FM chip silent
    ret

section .data

blaster_name:   db "BLASTER=", 0

g_cfg_nosound:  db 0              ; /NOSOUND on the command line
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
