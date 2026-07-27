; delay.asm — mirror of pret home/delay.asm.
;
; COMPLETE: this file holds all three of that pret file's labels, in pret's
; order — DelayFrames, PlaySoundWaitForCurrent, WaitForSoundToFinish.
;
; DelayFrames was in src/video/frame.asm (whose other pret label, DelayFrame,
; is a home/vblank.asm label and moved to src/home/vblank.asm; frame.asm was
; deleted). PlaySoundWaitForCurrent and WaitForSoundToFinish were in
; src/home/audio.asm, which keeps pret home/audio.asm's own labels.
;
; Register map (asm-translation skill): A=AL, BC=BX (B=BH, C=BL), HL=ESI,
; EBP = GB memory base. GB memory is [ebp+SYM] from gb_memmap.inc.
;
; Build: nasm -f coff -I include/ -o delay.o delay.asm

bits 32

%include "gb_memmap.inc"

global DelayFrames
global PlaySoundWaitForCurrent
global WaitForSoundToFinish

extern DelayFrame                 ; src/home/vblank.asm
extern PlaySound                  ; src/home/audio.asm

section .text

; ---------------------------------------------------------------------------
; DelayFrames — wait BL (C register) frames.
; In:  BL = frame count. Out: BL = 0. Other registers preserved.
;
; Delay3 (pret home/palettes.asm) lives in src/home/palettes.asm and tail-calls
; this, which is why DelayFrames stays global.
; ---------------------------------------------------------------------------
DelayFrames:
    test bl, bl
    jz .done
.loop:
    call DelayFrame
    dec bl
    jnz .loop
.done:
    ret

; ---------------------------------------------------------------------------
; PlaySoundWaitForCurrent / WaitForSoundToFinish — let the current sound drain
; before starting the next one. WaitForSoundToFinish spins on the three SFX
; channel-id slots pret checks (CHAN5, CHAN6, CHAN8 — pret skips CHAN7 with two
; bare `inc hl`), and returns immediately while the low-health alarm owns the
; channels.
; ---------------------------------------------------------------------------
PlaySoundWaitForCurrent:
    push eax
    call WaitForSoundToFinish
    pop eax
    jmp PlaySound

; Wait for sound to finish playing
WaitForSoundToFinish:
    mov al, [ebp + wLowHealthAlarm]
    and al, 0x80
    jnz .done
.waitLoop:
    xor al, al
    or al, [ebp + wChannelSoundIDs + CHAN5]
    or al, [ebp + wChannelSoundIDs + CHAN6]
    or al, [ebp + wChannelSoundIDs + CHAN8]  ; pret skips CHAN7 (inc hl x2)
    jz .done
    ; On the GB the VBlank ISR advanced the engine during this spin; in the
    ; port the audio tick lives in DelayFrame (Task 5), so pump it here —
    ; a bare spin would never see the sound IDs clear.
    call DelayFrame
    jmp .waitLoop
.done:
    ret
