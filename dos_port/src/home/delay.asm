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
;
; DO-WHILE, AND THE COUNTER IS 8-BIT ON PURPOSE. This is pret's exact shape:
; wait first, then decrement, loop while nonzero. Entered with BL = 0 it waits a
; frame, wraps 0 -> 255, and runs 256 frames (~4.3 s) — the register WIDTH is the
; bound, which is why the GB needs no zero check.
;
; This used to open with `test bl, bl / jz .done`. That guard was NOT equivalent:
; it made a zero count wait 0 frames where the GB waits 256, an unannotated
; behavioural divergence that lint and faithdiff both reported as faithful. It
; was also a masking trap — a caller that ever passed 0 would freeze visibly on
; the GB but silently do nothing here, and silent-wrong is far harder to find
; than a hang. Removed 2026-08-08 (maintainer-approved) after measuring all 105
; call sites: 102 pass a literal non-zero, none passes a literal zero, and the 3
; computed sites cannot reach zero —
;   * the subanimation delay is command_byte & $3F, and all 245 subanimation rows
;     in data/moves/animations.asm use delays in {1,2,3,4,5,6,8,16,18,21,22};
;   * PlayerSpinInPlace runs 0 +1.. up to end 8 (yields 1..7), and its
;     escape-warp variant runs 16 -1.. to end 0 where pret's own `cp c / ret z`
;     returns EXACTLY when the delay would hit zero;
;   * PlayerSpinWhileMovingUpOrDown takes GetPlayerTeleportAnimFrameDelay = 2.
; That last one is the general point: pret's CALLERS maintain the nonzero
; invariant, so the routine does not have to. Do not reintroduce the guard — if a
; future caller can pass 0, fix the caller.
; ---------------------------------------------------------------------------
DelayFrames:
    call DelayFrame
    dec bl                                ; dec c — 8-bit, as on the GB
    jnz DelayFrames
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
