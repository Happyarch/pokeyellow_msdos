; gamepad_hal.asm — DOS Game Port (I/O port 0x201) hardware driver for standard
; 2/4-button joysticks and gamepads (e.g. Gravis GamePad).
;
; Game Port 0x201 register layout:
;   Write: any byte resets the 555 one-shot timers for analog axes.
;   Read:
;     Bit 0: Joystick 1 X axis (1 = charging, 0 = done)
;     Bit 1: Joystick 1 Y axis (1 = charging, 0 = done)
;     Bit 2: Joystick 2 X axis
;     Bit 3: Joystick 2 Y axis
;     Bit 4: Joystick 1 Button 1 (0 = pressed) -> GB A button
;     Bit 5: Joystick 1 Button 2 (0 = pressed) -> GB B button
;     Bit 6: Joystick 1/2 Button 3 (0 = pressed) -> GB Select
;     Bit 7: Joystick 1/2 Button 4 (0 = pressed) -> GB Start
;
; Build: nasm -f coff -I include/ -I . -o gamepad_hal.o gamepad_hal.asm

bits 32

%include "gb_constants.inc"

GAMEPORT_IO     equ 0x201
AXIS_MAX_TICKS  equ 100     ; safety bound for disconnected/floating ports
AXIS_LOW_THRESH equ 25      ; < 25 ticks: Left / Up
AXIS_HIGH_THRESH equ 75     ; > 75 ticks: Right / Down

global gamepad_poll

section .text

; ---------------------------------------------------------------------------
; gamepad_poll — Poll game port 0x201 and return GB active-high bitmask in AL.
; Active-high format:
;   bit 7=Down, 6=Up, 5=Left, 4=Right, 3=Start, 2=Select, 1=B, 0=A
; Clobbers: EAX, EBX, ECX, EDX
; ---------------------------------------------------------------------------
gamepad_poll:
    ; Read digital buttons first (bits 4..7)
    mov dx, GAMEPORT_IO
    in  al, dx
    mov bl, al              ; BL holds initial port read with button states

    ; Trigger one-shot timers for X/Y axes by writing any value to port 0x201
    out dx, al

    ; Count discharge cycles for X axis (bit 0) and Y axis (bit 1)
    xor ecx, ecx            ; ECX = loop counter
    xor bh, bh              ; BH = X axis tick count
    xor ah, ah              ; AH = Y axis tick count

.axis_loop:
    in  al, dx
    test al, 0x01           ; is X axis still timing?
    jz .x_done
    inc bh
.x_done:
    test al, 0x02           ; is Y axis still timing?
    jz .y_done
    inc ah
.y_done:
    test al, 0x03           ; are both axes finished?
    jz .axes_finished
    inc ecx
    cmp ecx, AXIS_MAX_TICKS
    jb .axis_loop

.axes_finished:
    ; Now decode buttons and axes into active-high GB layout in DL
    xor edx, edx

    ; Digital Buttons (from BL): active-low (0 = pressed)
    ; Button 1 (bit 4) -> PAD_A (bit 0)
    test bl, 0x10
    jnz .no_btn_a
    or dl, (1 << 0)
.no_btn_a:
    ; Button 2 (bit 5) -> PAD_B (bit 1)
    test bl, 0x20
    jnz .no_btn_b
    or dl, (1 << 1)
.no_btn_b:
    ; Button 3 (bit 6) -> PAD_SELECT (bit 2)
    test bl, 0x40
    jnz .no_btn_sel
    or dl, (1 << 2)
.no_btn_sel:
    ; Button 4 (bit 7) -> PAD_START (bit 3)
    test bl, 0x80
    jnz .no_btn_start
    or dl, (1 << 3)
.no_btn_start:

    ; X-Axis (BH ticks):
    ; < AXIS_LOW_THRESH -> Left (bit 5)
    ; > AXIS_HIGH_THRESH -> Right (bit 4)
    cmp bh, AXIS_LOW_THRESH
    jae .chk_right
    or dl, (1 << 5)         ; PAD_LEFT
    jmp .decode_y
.chk_right:
    cmp bh, AXIS_HIGH_THRESH
    jbe .decode_y
    or dl, (1 << 4)         ; PAD_RIGHT

.decode_y:
    ; Y-Axis (AH ticks):
    ; < AXIS_LOW_THRESH -> Up (bit 6)
    ; > AXIS_HIGH_THRESH -> Down (bit 7)
    cmp ah, AXIS_LOW_THRESH
    jae .chk_down
    or dl, (1 << 6)         ; PAD_UP
    jmp .done
.chk_down:
    cmp ah, AXIS_HIGH_THRESH
    jbe .done
    or dl, (1 << 7)         ; PAD_DOWN

.done:
    mov al, dl              ; AL = active-high GB bitmask
    ret
