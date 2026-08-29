; input_hal.asm — input HAL coordinator and Virtual Joypad hardware sampler.
;
; Manages active input devices (keyboard vs DOS game port), reads the active
; hardware during DelayFrame / ReadJoypad_, and populates [ebp + hJoyInput]
; and emulated [ebp + IO_JOYP].
;
; Edge calculation (hJoyPressed / hJoyLast) is strictly delegated to the
; faithful pret engine mirror (src/engine/joypad.asm:_Joypad), invoked on-demand
; by game logic.
;
; Build: nasm -f coff -I include/ -I . -o input_hal.o input_hal.asm

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"

JOYP_GET_DPAD   equ 0x10    ; rJOYP bit 4 low → D-pad nibble selected
JOYP_GET_BTN    equ 0x20    ; rJOYP bit 5 low → buttons nibble selected

INPUT_DEVICE_KBD     equ 0
INPUT_DEVICE_GAMEPAD equ 1

global input_init
global input_restore
global input_poll_hardware

; External HAL drivers
extern input_config_load    ; src/input/input_cfg.asm
extern kbd_init             ; src/input/kbd_isr.asm
extern kbd_restore          ; src/input/kbd_isr.asm
extern pad_dpad             ; src/input/kbd_isr.asm
extern pad_buttons          ; src/input/kbd_isr.asm
extern g_input_device       ; src/input/input_cfg.asm
extern gamepad_poll         ; src/input/gamepad_hal.asm

section .text

; ---------------------------------------------------------------------------
; input_init — initialize input subsystem at boot (entry.asm)
; ---------------------------------------------------------------------------
input_init:
    call input_config_load
    call kbd_init
    ret

; ---------------------------------------------------------------------------
; input_restore — restore hardware state on exit (entry.asm)
; ---------------------------------------------------------------------------
input_restore:
    call kbd_restore
    ret

; ---------------------------------------------------------------------------
; input_poll_hardware — sample active input device and write [ebp + hJoyInput]
;
; In: EBP = GB memory base
; Out: AL = active-high held buttons byte
; All other registers preserved.
; ---------------------------------------------------------------------------
input_poll_hardware:
    push ebx
    push ecx
    push edx

    cmp byte [g_input_device], INPUT_DEVICE_GAMEPAD
    je .poll_gamepad

    ; --- Poll Keyboard (default) ---
    movzx eax, byte [pad_dpad]
    shl al, 4
    or  al, [pad_buttons]        ; AL = active-high held buttons

    ; Update emulated IO_JOYP register
    mov cl, [ebp + IO_JOYP]
    or  cl, 0xCF
    test cl, JOYP_GET_DPAD
    jnz .kbd_no_dpad
    mov bl, [pad_dpad]
    not bl
    or  bl, 0xF0
    and cl, bl
.kbd_no_dpad:
    test cl, JOYP_GET_BTN
    jnz .kbd_no_btn
    mov bl, [pad_buttons]
    not bl
    or  bl, 0xF0
    and cl, bl
.kbd_no_btn:
    mov [ebp + IO_JOYP], cl
    jmp .store_input

.poll_gamepad:
    ; --- Poll Game Port (0x201) ---
    call gamepad_poll            ; AL = active-high held buttons

    ; Update emulated IO_JOYP register
    mov bl, al                   ; BL = active-high held buttons
    mov cl, [ebp + IO_JOYP]
    or  cl, 0xCF
    test cl, JOYP_GET_DPAD
    jnz .gp_no_dpad
    mov ch, bl
    shr ch, 4                    ; CH = D-pad bits 0..3
    not ch
    or  ch, 0xF0
    and cl, ch
.gp_no_dpad:
    test cl, JOYP_GET_BTN
    jnz .gp_no_btn
    mov ch, bl
    and ch, 0x0F                 ; CH = Button bits 0..3
    not ch
    or  ch, 0xF0
    and cl, ch
.gp_no_btn:
    mov [ebp + IO_JOYP], cl

.store_input:
%ifdef DEBUG_AUTOKEY
    or al, [ebp + hJoyInput]
%endif
    ; Store raw sampled buttons into hJoyInput
    mov [ebp + hJoyInput], al

    ; Also refresh hJoyHeld directly from input state for held-check consumers
    mov bl, [ebp + wStatusFlags5]
    test bl, 1 << BIT_DISABLE_JOYPAD
    jnz .disabled
    mov bl, [ebp + wJoyIgnore]
    test bl, bl
    jz .store_held
    not bl
    and al, bl
.store_held:
    mov [ebp + hJoyHeld], al
    jmp .done

.disabled:
    mov byte [ebp + hJoyHeld], 0

.done:
    pop edx
    pop ecx
    pop ebx
    ret
