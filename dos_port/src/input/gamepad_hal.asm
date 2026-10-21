; gamepad_hal.asm — DOS Game Port (I/O port 0x201) hardware driver for standard
; 4-button gameport pads (reference target: Gravis GamePad and compatibles).
; Buttons are numbered per the PC gameport: 1 = Red, 2 = Blue, 3 = Yellow,
; 4 = Green (PCGamingWiki "Controller:Gravis PC GamePad" technical table);
; the Gravis manual maps game manuals' "button A" to Red, i.e. button 1 is
; the primary — hence identity defaults (button 1 -> GB A).
;
; Game Port 0x201 register layout:
;   Write: any byte resets the 555 one-shot timers for analog axes.
;   Read:
;     Bit 0: Joystick 1 X axis (1 = charging, 0 = done)
;     Bit 1: Joystick 1 Y axis (1 = charging, 0 = done)
;     Bit 2: Joystick 2 X axis
;     Bit 3: Joystick 2 Y axis
;     Bit 4: Joystick 1 Button 1 (0 = pressed)
;     Bit 5: Joystick 1 Button 2 (0 = pressed)
;     Bit 6: Joystick 1/2 Button 3 (0 = pressed)
;     Bit 7: Joystick 1/2 Button 4 (0 = pressed)
;
; Which gameport button drives which GB bit is NOT decided here: input_init
; resolves POKEMON.CFG [gamepad] (gamepad_a/b/select/start, defaults 1/2/3/4 =
; identity = Gravis order) into the 16-entry pad_btn_xlat table once at boot,
; and the per-frame poll below is a single table lookup. That is the HAL's
; minimal-latency rule — no reparsing, no per-frame mapping work. A missing
; [gamepad] section or key keeps the default; only an explicit remap changes
; anything, so a typo can never deaden the pad.
;
; Timing model: this loop COUNTS port reads while each axis bit stays high.
; That matches DOSBox-X's UNTIMED gameport emulation exactly (one countdown
; tick per read: xcount starts at (xpos+1)*64, so centered = 64, full
; deflection = 0/128 — deterministic, host-speed independent). Under TIMED
; emulation the discharge is wall-time and no fixed loop budget can track it
; (a centered stick reads as deflection), so our run scripts force
; timed=false whenever they enable the stick. Thresholds below assume the
; untimed model: symmetric thirds around center.
;
; Build: nasm -f coff -I include/ -I . -o gamepad_hal.o gamepad_hal.asm

bits 32

%include "gb_constants.inc"

extern pad_btn_xlat   ; input_hal.asm: boot-built port-nibble -> GB-bits table

GAMEPORT_IO     equ 0x201
AXIS_MAX_TICKS  equ 160    ; safety bound for disconnected/floating ports
AXIS_LOW_THRESH equ 43     ; < 43 ticks: Left / Up
AXIS_HIGH_THRESH equ 85    ; > 85 ticks: Right / Down

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
    ; Now decode buttons and axes into active-high GB layout in DL.
    ; Digital Buttons (from BL): the port high nibble (buttons, active-low)
    ; indexes the boot-built pad_btn_xlat table — one lookup, zero per-frame
    ; mapping branches (minimal-latency HAL rule). Remapping lives in
    ; POKEMON.CFG [gamepad] (parsed once at boot), never here.
    xor edx, edx
    movzx eax, bl
    shr eax, 4
    mov dl, [pad_btn_xlat + eax]

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
