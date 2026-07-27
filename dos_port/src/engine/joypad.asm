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
; WHAT IS LIVE. DiscardButtonPresses is the one routine here the port calls: from
; DoBoulderDustAnimation (src/engine/overworld/push_boulder.asm), which relies on
; pret's AL = 0 on return, and from joypad_update's `.discard` edge in the input
; HAL. It moved here from src/input/joypad.asm in chunk 18, retiring the last
; ordinary relocated_labels row.
;
; WHAT IS NOT. ReadJoypad_, _Joypad and TrySoftReset link but have ZERO callers.
; They are pret's synchronous polling model, which the port does not use:
; joypad_update (src/input/joypad.asm) re-realizes the same edge/mask layer from an
; INT 9h keyboard ISR inside DelayFrame, so DelayFrame *is* the poll and there is
; nothing synchronous to call. That is the port-input-model DEVIATION recorded at
; src/home/start_menu.asm:28. Linking them rather than leaving them unbuildable is
; a deliberate maintainer decision (2026-07-27): pret's model belongs in the binary
; as a faithful cross-reference, not as text nobody can assemble.
;
; DEVIATION{class=HAL; pret=engine/joypad.asm:ReadJoypad_; behavior=links but is never called, and would not read correct input if it were - it selects a key row by writing IO_JOYP then reads the register back in the same call, while the port only recomposes that shadow once per frame in joypad_update, so the read returns the previously selected row; evidence=zero call sites tree-wide for ReadJoypad_ and _Joypad, and joypad_update at src/input/joypad.asm composes IO_JOYP from pad_dpad/pad_buttons on its own once-per-frame tick; lifetime=retires when the port either drives input through pret's model or emulates IO_JOYP synchronously}
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

ReadJoypad_:
	mov al, [ebp + H_DISABLE_JOYPAD_POLLING]
	test al, al
	jnz .done

	mov al, 1 << 5
	mov [ebp + IO_JOYP], al
	mov al, [ebp + IO_JOYP]
	mov al, [ebp + IO_JOYP]
	not al
	and al, 0x0F
	shl al, 4
	mov bh, al

	mov al, 1 << 4
	mov [ebp + IO_JOYP], al
	mov al, [ebp + IO_JOYP]
	mov al, [ebp + IO_JOYP]
	mov al, [ebp + IO_JOYP]
	mov al, [ebp + IO_JOYP]
	mov al, [ebp + IO_JOYP]
	mov al, [ebp + IO_JOYP]
	not al
	and al, 0x0F
	or al, bh
	mov [ebp + H_JOY_INPUT], al

	mov al, (1 << 4) | (1 << 5)
	mov [ebp + IO_JOYP], al
.done:
	ret

_Joypad:
	mov al, [ebp + H_JOY_INPUT]
	mov bh, al
	and al, PAD_BUTTONS | PAD_UP
	cmp al, PAD_BUTTONS
	je TrySoftReset

	mov al, [ebp + H_JOY_LAST]
	mov dl, al
	xor al, bh
	mov dh, al
	and al, dl
	mov [ebp + H_JOY_RELEASED], al
	mov al, dh
	and al, bh
	mov [ebp + H_JOY_PRESSED], al
	mov al, bh
	mov [ebp + H_JOY_LAST], al

	mov al, [ebp + W_STATUS_FLAGS_5]
	test al, 1 << BIT_DISABLE_JOYPAD
	jnz DiscardButtonPresses

	mov al, [ebp + H_JOY_LAST]
	mov [ebp + H_JOY_HELD], al

	mov al, [ebp + W_JOY_IGNORE]
	test al, al
	jz .done_ignore

	not al
	mov bh, al
	mov al, [ebp + H_JOY_HELD]
	and al, bh
	mov [ebp + H_JOY_HELD], al
	mov al, [ebp + H_JOY_PRESSED]
	and al, bh
	mov [ebp + H_JOY_PRESSED], al
.done_ignore:
	ret

DiscardButtonPresses:
	xor al, al
	mov [ebp + H_JOY_HELD], al
	mov [ebp + H_JOY_PRESSED], al
	mov [ebp + H_JOY_RELEASED], al
	ret

TrySoftReset:
	call DelayFrame

	mov al, 0x30
	mov [ebp + IO_JOYP], al

	dec byte [ebp + H_SOFT_RESET]
	jz SoftReset

	jmp Joypad
