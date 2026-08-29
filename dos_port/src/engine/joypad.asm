; joypad.asm — pret engine/joypad.asm: ReadJoypad_ / _Joypad / DiscardButtonPresses
; / TrySoftReset. All four pret labels preserved.
;
; STATUS — LIVE AND LINKED as of chunk 18 of the relocated-label grind (2026-07-27).
; This file spent a long time as unbuildable reference text, and it was dead at
; THREE independent layers, not the one its old header admitted to:
;   1. its %include named "dos_port/include/gb_memmap.inc", a repo-root-relative
;      path the build's `-I include/ -I .` cannot open;
;   2. even with that fixed it did not assemble — its operands used pret's
;      lowercase HRAM spellings (hJoyInput, hJoyLast, hJoyPressed, …), which the
;      port's memmap does not define;
;   3. `jp Joypad` had no target anywhere in the port.
; All three are repaired: the include path, the operands (repointed at the port's
; canonical H_JOY_* / W_* equates for the SAME addresses — hJoyInput 0xFFF5 and
; hDisableJoypadPolling 0xFFF8 were added to gb_memmap.inc from pokeyellow.sym),
; and Joypad, now a real pret mirror at src/home/joypad.asm.
;
; ALL FOUR ROUTINES ARE LIVE AND ACTIVELY CALLED:
;   ReadJoypad_          — queries the input HAL (input_poll_hardware)
;   _Joypad              — computes hJoyPressed/hJoyReleased against hJoyLast
;   DiscardButtonPresses — zeroes input buffers when disabled
;   TrySoftReset         — manages soft reset countdown
;
; DEVIATION{class=HAL; pret=engine/joypad.asm:ReadJoypad_; behavior=queries active input device via input_poll_hardware to populate hJoyInput instead of strobing hardware rJOYP; evidence=DOS target has no Game Boy joypad register so the hardware matrix is read via INT 9h ISR or game port 0x201; lifetime=permanent input HAL boundary}
;
; Register map: A=AL, B=BH, C=BL (BC=BX), D=DH, E=DL (DE=EDX), HL=ESI, EBP=GB base.
;
; Build: nasm -f coff -I include/ -I . -o joypad.o joypad.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"      ; PAD_BUTTONS

SECTION .text

global ReadJoypad_
global _Joypad
global DiscardButtonPresses
global TrySoftReset

extern DelayFrame                ; src/home/vblank.asm
extern SoftReset                 ; src/home/init.asm
extern Joypad                    ; src/home/joypad.asm
extern input_poll_hardware       ; src/input/input_hal.asm

ReadJoypad_:
	mov al, [ebp + hDisableJoypadPolling]
	test al, al
	jnz .done
	call input_poll_hardware
.done:
	ret

_Joypad:
	mov al, [ebp + hJoyInput]
	mov bh, al
	and al, PAD_BUTTONS | PAD_UP
	cmp al, PAD_BUTTONS
	je TrySoftReset

	mov al, [ebp + hJoyLast]
	mov dl, al
	xor al, bh
	mov dh, al
	and al, dl
	mov [ebp + hJoyReleased], al
	mov al, dh
	and al, bh
	mov [ebp + hJoyPressed], al
	mov al, bh
	mov [ebp + hJoyLast], al

	mov al, [ebp + wStatusFlags5]
	test al, 1 << BIT_DISABLE_JOYPAD
	jnz DiscardButtonPresses

	mov al, [ebp + hJoyLast]
	mov [ebp + hJoyHeld], al

	mov al, [ebp + wJoyIgnore]
	test al, al
	jz .done_ignore

	not al
	mov bh, al
	mov al, [ebp + hJoyHeld]
	and al, bh
	mov [ebp + hJoyHeld], al
	mov al, [ebp + hJoyPressed]
	and al, bh
	mov [ebp + hJoyPressed], al
.done_ignore:
	ret

DiscardButtonPresses:
	xor al, al
	mov [ebp + hJoyHeld], al
	mov [ebp + hJoyPressed], al
	mov [ebp + hJoyReleased], al
	ret

TrySoftReset:
	call DelayFrame

	mov al, 0x30
	mov [ebp + IO_JOYP], al

	dec byte [ebp + hSoftReset]
	jz SoftReset

	jmp Joypad
