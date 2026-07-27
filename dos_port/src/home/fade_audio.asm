; fade_audio.asm — FadeOutAudio.
;
; Mirror of pret home/fade_audio.asm, whose ONLY label this is. Carried by
; src/home/audio.asm until chunk 18 of the relocated-label grind; its single
; caller, audio_tick (src/audio/audio_hal.asm), reaches it as an extern.
;
; Register map: A=AL, B=BH, C=BL (BC=BX), D=DH, E=DL (DE=EDX), HL=ESI, EBP=GB base.
;
; Build: nasm -f coff -I include/ -I . -o fade_audio.o fade_audio.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

global FadeOutAudio

extern StopAllMusic                  ; src/home/audio.asm
extern PlaySound                     ; src/home/audio.asm

section .text

; ---------------------------------------------------------------------------
; pret home/fade_audio.asm — called once per audio tick, before the engine
; update, to step the volume fade driven by wAudioFadeOutControl.
FadeOutAudio:
    mov al, [ebp + wAudioFadeOutControl]
    test al, al                         ; currently fading out audio?
    jnz .fadingOut
    mov al, [ebp + wStatusFlags2]
    test al, 1 << BIT_NO_AUDIO_FADE_OUT
    jnz .ret
    mov byte [ebp + rAUDVOL], 0x77
.ret:
    ret
.fadingOut:
    mov al, [ebp + wAudioFadeOutCounter]
    test al, al
    jz .counterReachedZero
    dec al
    mov [ebp + wAudioFadeOutCounter], al
    ret
.counterReachedZero:
    mov al, [ebp + wAudioFadeOutCounterReloadValue]
    mov [ebp + wAudioFadeOutCounter], al
    mov al, [ebp + rAUDVOL]
    test al, al                         ; has the volume reached 0?
    jz .fadeOutComplete
    mov bh, al
    and al, 0x0F
    dec al
    mov bl, al                          ; c = right volume - 1
    mov al, bh
    and al, 0xF0
    ror al, 4                           ; swap a
    dec al                              ; left volume - 1 (in the low nibble)
    rol al, 4                           ; swap a
    or al, bl
    mov [ebp + rAUDVOL], al
    ret
.fadeOutComplete:
    mov al, [ebp + wAudioFadeOutControl]
    mov bh, al
    xor al, al
    mov [ebp + wAudioFadeOutControl], al
    call StopAllMusic
    mov al, [ebp + wAudioSavedROMBank]
    mov [ebp + wAudioROMBank], al
    mov al, bh
    mov [ebp + wNewSoundID], al
    jmp PlaySound
