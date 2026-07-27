; joypad.asm — Joypad / ReadJoypad, the two home-bank wrappers of pret
; home/joypad.asm.
;
; Mirror of pret home/joypad.asm, whose ONLY labels these are. Both are `homejp`
; one-liners onto the engine bodies in src/engine/joypad.asm; banking collapses
; under the flat DPMI model, so each is a plain jmp — the same banking boundary
; CLAUDE.md sanctions tree-wide.
;
; PORT NOTE — NEITHER WRAPPER HAS A PORT CALLER, BY DESIGN. The port's live input
; path is the src/input/joypad.asm HAL: an INT 9h keyboard ISR latches H_JOY_*,
; and joypad_update runs inside DelayFrame, so DelayFrame *is* the poll and there
; is nothing synchronous to call. That is the port-input-model DEVIATION recorded
; at src/home/start_menu.asm:28. These wrappers were ported so that pret's
; engine/joypad.asm reference model links as pret writes it, with TrySoftReset's
; `jp Joypad` tail resolved against a real label instead of a stub.
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
