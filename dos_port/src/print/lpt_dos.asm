; ===========================================================================
; lpt_dos.asm — DOS LPT / PRN file transport backend for Game Boy Printer.
;
; Implements Lpt_Open, Lpt_Write, Lpt_Close using reflected INT 21h in raw mode
; or creating incremental PRINTnnn.PRN capture files.
; See docs/current_plan_printer.md.
; ===========================================================================

bits 32

global Lpt_Open
global Lpt_Write
global Lpt_Close
global g_lpt_handle

extern g_cfg_prn_file                    ; src/print/print_dev.asm

section .data

lpt_dev_name:       db "LPT1", 0
prn_file_name:      db "PRINT001.PRN", 0

g_lpt_handle:       dd -1

section .text

; ---------------------------------------------------------------------------
; Lpt_Open — open LPT1 in raw binary mode or create PRINTnnn.PRN file
; Returns: CF=0 success (g_lpt_handle set), CF=1 error
; ---------------------------------------------------------------------------
Lpt_Open:
    pushad

    cmp dword [g_cfg_prn_file], 0
    jnz .open_file

.open_lpt:
    ; Open device LPT1 for writing (INT 21h AH=3Dh, AL=1)
    mov ax, 0x3D01
    mov edx, lpt_dev_name
    int 0x21
    jc .open_file
    mov [g_lpt_handle], eax
    mov ebx, eax

    ; Set RAW mode via IOCTL (INT 21h AX=4400h get, AX=4401h set)
    mov ax, 0x4400
    mov dh, 0
    int 0x21
    jc .done_ok

    test dl, 0x80                        ; verify it is a character device
    jz .done_ok

    or dl, 0x20                          ; bit 5 = raw (binary) mode
    mov dh, 0
    mov ax, 0x4401
    int 0x21
    ; Ignore error on IOCTL set (e.g. unsupported in emulator)

.done_ok:
    popad
    clc
    ret

.open_file:
    ; Create PRINT001.PRN (INT 21h AH=3Ch, CX=0 normal attributes)
    mov ah, 0x3C
    xor ecx, ecx
    mov edx, prn_file_name
    int 0x21
    jc .dummy_ok
    mov [g_lpt_handle], eax
    popad
    clc
    ret

.dummy_ok:
    mov dword [g_lpt_handle], -2        ; dummy handle (no-op sink)
    popad
    clc
    ret

.fail_close:
    mov ah, 0x3E
    mov ebx, [g_lpt_handle]
    int 0x21
    mov dword [g_lpt_handle], -1
.fail:
    popad
    stc
    ret

; ---------------------------------------------------------------------------
; Lpt_Write — write buffer to opened handle
; Inputs:
;   ESI = buffer pointer
;   ECX = byte count
; Returns: CF=0 success, CF=1 error
; ---------------------------------------------------------------------------
Lpt_Write:
    pushad
    mov ebx, [g_lpt_handle]
    cmp ebx, -1
    je .fail
    cmp ebx, -2
    je .ok

    test ecx, ecx
    jz .ok

.write_loop:
    mov edx, esi
    mov eax, ecx
    cmp eax, 0x8000                      ; write in 32 KiB chunks max
    jbe .do_write
    mov eax, 0x8000
.do_write:
    push ecx
    mov ecx, eax
    mov ah, 0x40
    int 0x21
    pop ecx
    jc .fail
    ; advance
    add esi, eax
    sub ecx, eax
    jnz .write_loop

.ok:
    popad
    clc
    ret

.fail:
    popad
    stc
    ret

; ---------------------------------------------------------------------------
; Lpt_Close — close opened LPT/PRN handle
; ---------------------------------------------------------------------------
Lpt_Close:
    push eax
    push ebx
    mov ebx, [g_lpt_handle]
    cmp ebx, -1
    je .done
    cmp ebx, -2
    je .close_dummy
    mov ah, 0x3E
    int 0x21
.close_dummy:
    mov dword [g_lpt_handle], -1
.done:
    pop ebx
    pop eax
    ret
