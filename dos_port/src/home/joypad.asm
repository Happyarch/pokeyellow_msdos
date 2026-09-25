; joypad.asm — Joypad / ReadJoypad, the two home-bank wrappers of pret
; home/joypad.asm.
;
; Mirror of pret home/joypad.asm, whose ONLY labels these are. Both are `homejp`
; one-liners onto the engine bodies in src/engine/joypad.asm; banking collapses
; under the flat DPMI model, so each is a plain jmp — the same banking boundary
; CLAUDE.md sanctions tree-wide.
;
; PORT NOTE — the port's PRIMARY input path is still the src/input/kbd_isr.asm HAL:
; an INT 9h keyboard ISR latches H_JOY_*, and joypad_update runs inside DelayFrame,
; so DelayFrame is the per-frame poll. These wrappers are NOT dead, though — they
; are the synchronous pad-edge call that routines needing a fresh read use: Joypad
; by OverworldLoop's scans (home/overworld.asm), WaitForTextScrollButtonPress
; (home/joypad2.asm), text_script.asm, surfing_pikachu.asm, and TrySoftReset's
; `jmp Joypad` tail (engine/joypad.asm); ReadJoypad by the DelayFrame pipeline
; (home/vblank.asm). So this file is linked and live, not a stub-only reference
; model. (The older claim here — and the related note at src/home/start_menu.asm:27
; that Joypad "has NO caller" — is contradicted by every call site above.)
;
; Register map: A=AL, B=BH, C=BL (BC=BX), D=DH, E=DL (DE=EDX), HL=ESI, EBP=GB base.
;
; Build: nasm -f coff -I include/ -I . -o joypad.o joypad.asm

bits 32

global Joypad
global ReadJoypad

extern _Joypad                   ; src/engine/joypad.asm
extern ReadJoypad_               ; src/engine/joypad.asm

section .text

; ---------------------------------------------------------------------------
; Joypad — pret home/joypad.asm:Joypad (`homejp _Joypad`).
; ---------------------------------------------------------------------------
Joypad:
    jmp _Joypad

; ---------------------------------------------------------------------------
; ReadJoypad — pret home/joypad.asm:ReadJoypad (`homejp ReadJoypad_`).
; ---------------------------------------------------------------------------
ReadJoypad:
    jmp ReadJoypad_
