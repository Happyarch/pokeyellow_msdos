; input_cfg.asm — on-disk configuration parser (POKEMON.CFG) for keyboard
; rebinding and input device selection.
;
; Format (POKEMON.CFG):
;   [keyboard]
;   up = up         ; or 0x48 / w
;   down = down     ; or 0x50 / s
;   left = left     ; or 0x4B / a
;   right = right   ; or 0x4D / d
;   a = x           ; or 0x2D / z
;   b = z           ; or 0x2C / x
;   start = enter   ; or 0x1C / space
;   select = backspace ; or 0x0E / tab / rshift
;   device = keyboard  ; or gamepad
;
; Loaded ONCE at boot in boot/entry.asm before any pret-translated code runs.
; Populates static byte literals (cfg_key_*) in memory with fallback to current
; defaults if the file is missing or omitted. Zero parsing overhead during frames.
;
; Build: nasm -f coff -I include/ -I . -o input_cfg.o input_cfg.asm

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"

extern ds_base

global input_config_load
global cfg_key_up
global cfg_key_down
global cfg_key_left
global cfg_key_right
global cfg_key_a
global cfg_key_b
global cfg_key_start
global cfg_key_select
global g_input_device

; Input device constants
INPUT_DEVICE_KBD     equ 0
INPUT_DEVICE_GAMEPAD equ 1

; DPMI real-mode call structure offsets
RMCS_EBX     equ 0x10
RMCS_EDX     equ 0x14
RMCS_ECX     equ 0x18
RMCS_EAX     equ 0x1C
RMCS_FLAGS   equ 0x20
RMCS_DS      equ 0x24
RMCS_SIZE    equ 0x32

CFG_BUF_SIZE equ 4096

section .data
align 4

; --- Configuration Byte Literals (initialized to default bindings) ---
cfg_key_up:     db 0x48    ; Up Arrow
cfg_key_down:   db 0x50    ; Down Arrow
cfg_key_left:   db 0x4B    ; Left Arrow
cfg_key_right:  db 0x4D    ; Right Arrow
cfg_key_a:      db 0x2D    ; 'X'
cfg_key_b:      db 0x2C    ; 'Z'
cfg_key_start:  db 0x1C    ; Enter
cfg_key_select: db 0x0E    ; Backspace
g_input_device: db INPUT_DEVICE_KBD

cfg_filename:   db "POKEMON.CFG", 0

; --- Option dispatch table for extensible parsing ---
PARSE_TYPE_SCANCODE equ 1
PARSE_TYPE_DEVICE   equ 2

align 4
opt_table:
    dd .str_up,     cfg_key_up,     PARSE_TYPE_SCANCODE
    dd .str_down,   cfg_key_down,   PARSE_TYPE_SCANCODE
    dd .str_left,   cfg_key_left,   PARSE_TYPE_SCANCODE
    dd .str_right,  cfg_key_right,  PARSE_TYPE_SCANCODE
    dd .str_a,      cfg_key_a,      PARSE_TYPE_SCANCODE
    dd .str_b,      cfg_key_b,      PARSE_TYPE_SCANCODE
    dd .str_start,  cfg_key_start,  PARSE_TYPE_SCANCODE
    dd .str_select, cfg_key_select, PARSE_TYPE_SCANCODE
    dd .str_device, g_input_device, PARSE_TYPE_DEVICE
    dd 0 ; terminator

.str_up:     db "UP", 0
.str_down:   db "DOWN", 0
.str_left:   db "LEFT", 0
.str_right:  db "RIGHT", 0
.str_a:      db "A", 0
.str_b:      db "B", 0
.str_start:  db "START", 0
.str_select: db "SELECT", 0
.str_device: db "DEVICE", 0

; --- Key name to scancode lookup table ---
align 4
key_name_table:
    dd .k_up,        0x48
    dd .k_down,      0x50
    dd .k_left,      0x4B
    dd .k_right,     0x4D
    dd .k_enter,     0x1C
    dd .k_return,    0x1C
    dd .k_space,     0x39
    dd .k_tab,       0x0F
    dd .k_backspace, 0x0E
    dd .k_bksp,      0x0E
    dd .k_esc,       0x01
    dd .k_escape,    0x01
    dd .k_lshift,    0x2A
    dd .k_rshift,    0x36
    dd .k_shift,     0x2A
    dd .k_ctrl,      0x1D
    dd .k_alt,       0x38
    ; Alphabet
    dd .k_a, 0x1E
    dd .k_b, 0x30
    dd .k_c, 0x2E
    dd .k_d, 0x20
    dd .k_e, 0x12
    dd .k_f, 0x21
    dd .k_g, 0x22
    dd .k_h, 0x23
    dd .k_i, 0x17
    dd .k_j, 0x24
    dd .k_k, 0x25
    dd .k_l, 0x26
    dd .k_m, 0x32
    dd .k_n, 0x31
    dd .k_o, 0x18
    dd .k_p, 0x19
    dd .k_q, 0x10
    dd .k_r, 0x13
    dd .k_s, 0x1F
    dd .k_t, 0x14
    dd .k_u, 0x16
    dd .k_v, 0x2F
    dd .k_w, 0x11
    dd .k_x, 0x2D
    dd .k_y, 0x15
    dd .k_z, 0x2C
    ; Numbers
    dd .k_0, 0x0B
    dd .k_1, 0x02
    dd .k_2, 0x03
    dd .k_3, 0x04
    dd .k_4, 0x05
    dd .k_5, 0x06
    dd .k_6, 0x07
    dd .k_7, 0x08
    dd .k_8, 0x09
    dd .k_9, 0x0A
    dd 0 ; terminator

.k_up:        db "UP", 0
.k_down:      db "DOWN", 0
.k_left:      db "LEFT", 0
.k_right:     db "RIGHT", 0
.k_enter:     db "ENTER", 0
.k_return:    db "RETURN", 0
.k_space:     db "SPACE", 0
.k_tab:       db "TAB", 0
.k_backspace: db "BACKSPACE", 0
.k_bksp:      db "BKSP", 0
.k_esc:       db "ESC", 0
.k_escape:    db "ESCAPE", 0
.k_lshift:    db "LSHIFT", 0
.k_rshift:    db "RSHIFT", 0
.k_shift:     db "SHIFT", 0
.k_ctrl:      db "CTRL", 0
.k_alt:       db "ALT", 0
.k_a: db "A", 0
.k_b: db "B", 0
.k_c: db "C", 0
.k_d: db "D", 0
.k_e: db "E", 0
.k_f: db "F", 0
.k_g: db "G", 0
.k_h: db "H", 0
.k_i: db "I", 0
.k_j: db "J", 0
.k_k: db "K", 0
.k_l: db "L", 0
.k_m: db "M", 0
.k_n: db "N", 0
.k_o: db "O", 0
.k_p: db "P", 0
.k_q: db "Q", 0
.k_r: db "R", 0
.k_s: db "S", 0
.k_t: db "T", 0
.k_u: db "U", 0
.k_v: db "V", 0
.k_w: db "W", 0
.k_x: db "X", 0
.k_y: db "Y", 0
.k_z: db "Z", 0
.k_0: db "0", 0
.k_1: db "1", 0
.k_2: db "2", 0
.k_3: db "3", 0
.k_4: db "4", 0
.k_5: db "5", 0
.k_6: db "6", 0
.k_7: db "7", 0
.k_8: db "8", 0
.k_9: db "9", 0

section .bss
align 4
rmcs:           resb RMCS_SIZE
dos_buf_seg:    resw 1
dos_buf_sel:    resw 1
dos_buf_ptr:    resd 1
cfg_file_bytes: resd 1

section .text

; ---------------------------------------------------------------------------
; input_config_load — Read POKEMON.CFG if present and update bindings.
; ---------------------------------------------------------------------------
input_config_load:
    pushad

    ; Allocate conventional memory buffer for real-mode INT 21h (DPMI fn 0100h)
    ; Size in paragraphs: (CFG_BUF_SIZE + 15) >> 4 = 256
    mov ax, 0x0100
    mov bx, (CFG_BUF_SIZE + 15) >> 4
    int 0x31
    jc .done

    mov [dos_buf_seg], ax
    mov [dos_buf_sel], dx

    ; Linear pointer = (segment * 16) - ds_base
    movzx eax, ax
    shl eax, 4
    sub eax, [ds_base]
    mov [dos_buf_ptr], eax

    ; Copy filename "POKEMON.CFG" into beginning of conventional buffer (offset 0)
    mov edi, eax
    mov esi, cfg_filename
.copy_fn:
    lodsb
    stosb
    test al, al
    jnz .copy_fn

    ; Open file (INT 21h AH=3Dh, read-only AL=00h, DS:DX -> filename at offset 0)
    lea edi, [rmcs]
    push edi
    mov ecx, RMCS_SIZE
    xor al, al
    rep stosb
    pop edi

    mov dword [edi + RMCS_EAX], 0x3D00      ; AH=3Dh, AL=0 (read-only)
    mov dword [edi + RMCS_EDX], 0           ; offset 0 in DOS buffer
    mov ax, [dos_buf_seg]
    mov [edi + RMCS_DS], ax

    mov ax, 0x0300
    mov bl, 0x21
    xor bh, bh
    xor ecx, ecx
    mov edx, edi
    int 0x31
    jc .free_buf

    test word [edi + RMCS_FLAGS], 1         ; CF=1 on open error (file not found)
    jnz .free_buf

    mov bx, [edi + RMCS_EAX]                ; BX = file handle

    ; Read up to (CFG_BUF_SIZE - 64) bytes at buffer offset 64
    lea edi, [rmcs]
    push edi
    mov ecx, RMCS_SIZE
    xor al, al
    rep stosb
    pop edi

    mov dword [edi + RMCS_EAX], 0x3F00
    mov [edi + RMCS_EBX], ebx
    mov dword [edi + RMCS_ECX], CFG_BUF_SIZE - 64
    mov dword [edi + RMCS_EDX], 64          ; buffer offset 64
    mov ax, [dos_buf_seg]
    mov [edi + RMCS_DS], ax

    mov ax, 0x0300
    mov bl, 0x21
    xor bh, bh
    xor ecx, ecx
    mov edx, edi
    int 0x31

    mov eax, [edi + RMCS_EAX]               ; bytes read
    mov [cfg_file_bytes], eax

    ; Close file handle (INT 21h AH=3Eh)
    lea edi, [rmcs]
    push edi
    mov ecx, RMCS_SIZE
    xor al, al
    rep stosb
    pop edi

    mov dword [edi + RMCS_EAX], 0x3E00
    mov [edi + RMCS_EBX], ebx

    mov ax, 0x0300
    mov bl, 0x21
    xor bh, bh
    xor ecx, ecx
    mov edx, edi
    int 0x31

    ; Now parse the buffer if bytes read > 0
    mov ecx, [cfg_file_bytes]
    test ecx, ecx
    jz .free_buf

    mov esi, [dos_buf_ptr]
    add esi, 64                             ; start of file data
    call parse_config_buffer

.free_buf:
    ; Free conventional buffer (DPMI fn 0101h)
    mov dx, [dos_buf_sel]
    mov ax, 0x0101
    int 0x31

.done:
    popad
    ret

; ---------------------------------------------------------------------------
; parse_config_buffer — parse text lines in buffer at ESI, length ECX
; ---------------------------------------------------------------------------
parse_config_buffer:
    pushad
    lea ebx, [esi + ecx]                    ; EBX = buffer end pointer

.line_loop:
    cmp esi, ebx
    jae .parse_done

    ; Skip leading spaces / tabs / newlines
.skip_leading:
    cmp esi, ebx
    jae .parse_done
    mov al, [esi]
    cmp al, ' '
    je .inc_lead
    cmp al, 9                               ; tab
    je .inc_lead
    cmp al, 10                              ; LF
    je .inc_lead
    cmp al, 13                              ; CR
    je .inc_lead
    jmp .got_line_start
.inc_lead:
    inc esi
    jmp .skip_leading

.got_line_start:
    ; Check for comment or section header
    mov al, [esi]
    cmp al, '#'
    je .skip_to_eol
    cmp al, ';'
    je .skip_to_eol
    cmp al, '['
    je .skip_to_eol

    ; Found potential key. Record key start
    mov edx, esi                            ; EDX = key start

    ; Scan until '=', EOL, or comment
.find_equals:
    cmp esi, ebx
    jae .parse_done
    mov al, [esi]
    cmp al, '='
    je .found_equals
    cmp al, 10
    je .line_loop
    cmp al, 13
    je .line_loop
    cmp al, '#'
    je .skip_to_eol
    cmp al, ';'
    je .skip_to_eol
    inc esi
    jmp .find_equals

.found_equals:
    mov edi, esi                            ; EDI = end of key (points to '=')
    inc esi                                 ; ESI = start of value

    ; Trim trailing whitespace from key [EDX .. EDI)
.trim_key_tail:
    cmp edi, edx
    jbe .skip_to_eol                        ; empty key
    mov al, [edi - 1]
    cmp al, ' '
    je .dec_key_tail
    cmp al, 9
    je .dec_key_tail
    jmp .key_trimmed
.dec_key_tail:
    dec edi
    jmp .trim_key_tail

.key_trimmed:
    ; Trim leading whitespace from value at ESI
.trim_val_lead:
    cmp esi, ebx
    jae .parse_done
    mov al, [esi]
    cmp al, ' '
    je .inc_val_lead
    cmp al, 9
    je .inc_val_lead
    jmp .got_val_start
.inc_val_lead:
    inc esi
    jmp .trim_val_lead

.got_val_start:
    mov ebp, esi                            ; EBP = val start

    ; Scan until EOL or comment for value end
.find_val_end:
    cmp esi, ebx
    jae .got_val_end
    mov al, [esi]
    cmp al, 10
    je .got_val_end
    cmp al, 13
    je .got_val_end
    cmp al, '#'
    je .got_val_end
    cmp al, ';'
    je .got_val_end
    inc esi
    jmp .find_val_end

.got_val_end:
    push esi                                ; save current scan pointer for next line
    mov ecx, esi                            ; ECX = end of val

    ; Trim trailing whitespace from value [EBP .. ECX)
.trim_val_tail:
    cmp ecx, ebp
    jbe .apply_done                         ; empty val
    mov al, [ecx - 1]
    cmp al, ' '
    je .dec_val_tail
    cmp al, 9
    je .dec_val_tail
    jmp .val_trimmed
.dec_val_tail:
    dec ecx
    jmp .trim_val_tail

.val_trimmed:
    ; Now we have:
    ;   Key: [EDX .. EDI)
    ;   Val: [EBP .. ECX)
    call apply_config_key_val

.apply_done:
    pop esi                                 ; restore scan pointer

.skip_to_eol:
    cmp esi, ebx
    jae .parse_done
    mov al, [esi]
    inc esi
    cmp al, 10
    jne .skip_to_eol
    jmp .line_loop

.parse_done:
    popad
    ret

; ---------------------------------------------------------------------------
; apply_config_key_val
; In: EDX = key start, EDI = key end
;     EBP = val start, ECX = val end
; ---------------------------------------------------------------------------
apply_config_key_val:
    pushad

    ; Match key against opt_table
    lea esi, [opt_table]

.match_opt_loop:
    mov eax, [esi]                          ; EAX = opt string ptr
    test eax, eax
    jz .opt_not_found

    ; Compare string at EAX with key [EDX .. EDI)
    push esi
    mov esi, eax
    mov eax, edx                            ; EAX = key start
.cmp_key_chars:
    cmp eax, edi
    jae .key_at_end
    mov bl, [eax]
    mov bh, [esi]
    test bh, bh
    jz .key_mismatch                        ; opt string shorter than key
    ; Case-insensitive uppercase compare
    and bl, 0xDF
    and bh, 0xDF
    cmp bl, bh
    jne .key_mismatch
    inc eax
    inc esi
    jmp .cmp_key_chars

.key_at_end:
    cmp byte [esi], 0
    jne .key_mismatch                       ; opt string longer than key

    ; Matched! Pop opt_table ptr
    pop esi
    mov edi, [esi + 4]                      ; EDI = target byte ptr
    mov eax, [esi + 8]                      ; EAX = parse type

    ; Parse value [EBP .. ECX) based on type
    cmp eax, PARSE_TYPE_SCANCODE
    je .parse_scancode
    cmp eax, PARSE_TYPE_DEVICE
    je .parse_device
    jmp .apply_exit

.key_mismatch:
    pop esi
    add esi, 12                             ; next entry (3 dwords)
    jmp .match_opt_loop

.opt_not_found:
    jmp .apply_exit

; --- Value Parsers ---

.parse_device:
    ; Check for "GAMEPAD" or "JOYSTICK" vs "KEYBOARD"
    mov esi, ebp
    cmp esi, ecx
    jae .apply_exit
    mov al, [esi]
    and al, 0xDF
    cmp al, 'G'                             ; Gamepad
    je .set_gamepad
    cmp al, 'J'                             ; Joystick
    je .set_gamepad
    mov byte [edi], INPUT_DEVICE_KBD
    jmp .apply_exit
.set_gamepad:
    mov byte [edi], INPUT_DEVICE_GAMEPAD
    jmp .apply_exit

.parse_scancode:
    ; Check if value starts with "0X" or "$" or is decimal/hex
    mov esi, ebp
    cmp esi, ecx
    jae .apply_exit

    ; Check if it matches "0X" or "$"
    mov al, [esi]
    cmp al, '$'
    je .parse_hex_dollar
    cmp al, '0'
    jne .try_name_lookup
    inc esi
    cmp esi, ecx
    jae .try_name_lookup
    mov al, [esi]
    and al, 0xDF
    cmp al, 'X'
    jne .try_name_lookup
    inc esi                                 ; skip 'x'

    ; Parse hex string starting at ESI up to ECX
    call parse_hex_number
    mov [edi], al
    jmp .apply_exit

.parse_hex_dollar:
    inc esi
    call parse_hex_number
    mov [edi], al
    jmp .apply_exit

.try_name_lookup:
    ; Match string [EBP .. ECX) against key_name_table
    lea esi, [key_name_table]

.match_name_loop:
    mov eax, [esi]
    test eax, eax
    jz .apply_exit                          ; not found in name table

    push esi
    mov esi, eax
    mov eax, ebp
.cmp_name_chars:
    cmp eax, ecx
    jae .name_at_end
    mov bl, [eax]
    mov bh, [esi]
    test bh, bh
    jz .name_mismatch
    and bl, 0xDF
    and bh, 0xDF
    cmp bl, bh
    jne .name_mismatch
    inc eax
    inc esi
    jmp .cmp_name_chars

.name_at_end:
    cmp byte [esi], 0
    jne .name_mismatch

    ; Matched key name!
    pop esi
    mov eax, [esi + 4]                      ; EAX = scancode
    mov [edi], al
    jmp .apply_exit

.name_mismatch:
    pop esi
    add esi, 8                              ; next entry (2 dwords)
    jmp .match_name_loop

.apply_exit:
    popad
    ret

; ---------------------------------------------------------------------------
; parse_hex_number — parse hex digits at [ESI .. ECX) into AL
; ---------------------------------------------------------------------------
parse_hex_number:
    xor eax, eax
.hex_loop:
    cmp esi, ecx
    jae .hex_done
    mov bl, [esi]
    inc esi
    cmp bl, '0'
    jb .hex_done
    cmp bl, '9'
    jbe .is_digit
    and bl, 0xDF
    cmp bl, 'A'
    jb .hex_done
    cmp bl, 'F'
    ja .hex_done
    sub bl, 'A' - 10
    jmp .accum
.is_digit:
    sub bl, '0'
.accum:
    shl al, 4
    or al, bl
    jmp .hex_loop
.hex_done:
    ret
