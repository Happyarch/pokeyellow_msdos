; ===========================================================================
; lpt_dos.asm — DOS LPT / PRN file transport backend for Game Boy Printer.
;
; Implements Lpt_Open, Lpt_Write, Lpt_Close using reflected INT 21h via DPMI
; (INT 31h AX=0300h) in raw mode or creating PRINTnnn.PRN capture files.
; Follows the dsv_io.asm reflected-INT-21h DPMI conventional buffer idiom.
; See docs/plans/printer.md.
; ===========================================================================

bits 32

global Lpt_Open
global Lpt_Write
global Lpt_Close
global g_lpt_handle

extern ds_base                           ; boot/entry.asm
extern g_cfg_prn_file                    ; src/print/print_dev.asm

; --- DPMI real-mode call structure field offsets (DPMI 0.9 spec) ---
RMCS_EBX        equ 0x10
RMCS_EDX        equ 0x14
RMCS_ECX        equ 0x18
RMCS_EAX        equ 0x1C
RMCS_FLAGS      equ 0x20
RMCS_DS         equ 0x24
RMCS_SIZE       equ 0x32

PRN_CHUNK_SIZE  equ 4096
PRN_BUF_PARAS   equ (16 + PRN_CHUNK_SIZE + 15) / 16

section .data

align 4
lpt_dev_name:   db "LPT1", 0
prn_file_name:  db "PRINT001.PRN", 0

g_lpt_handle:   dd -1

section .bss

align 4
rmcs:           resb RMCS_SIZE
prn_seg:        resw 1                   ; real-mode segment of DOS buffer
prn_sel:        resw 1                   ; PM selector of DOS buffer
prn_flat:       resd 1                   ; DS-relative (flat) offset of DOS buffer

section .text

; ---------------------------------------------------------------------------
; prn_ensure_buffer — allocate conventional (<1MB) DOS buffer if not allocated
; ---------------------------------------------------------------------------
prn_ensure_buffer:
    cmp word [prn_sel], 0
    jne .have
    mov ax, 0x0100
    mov bx, PRN_BUF_PARAS
    int 0x31
    jc .fail
    mov [prn_seg], ax
    mov [prn_sel], dx
    movzx eax, ax
    shl eax, 4                           ; linear = seg * 16
    sub eax, [ds_base]                   ; flat offset
    mov [prn_flat], eax
.have:
    clc
    ret
.fail:
    stc
    ret

; ---------------------------------------------------------------------------
; prn_sim_int21 — reflect INT 21h to real mode using rmcs (DPMI fn 0300h)
; ---------------------------------------------------------------------------
prn_sim_int21:
    push eax
    push ebx
    push ecx
    push edi
    mov ax, 0x0300
    mov bl, 0x21
    mov bh, 0
    xor cx, cx
    mov edi, rmcs
    int 0x31
    pop edi
    pop ecx
    pop ebx
    pop eax
    ret

; ---------------------------------------------------------------------------
; prn_zero_rmcs — clear the real-mode call structure
; ---------------------------------------------------------------------------
prn_zero_rmcs:
    push eax
    push ecx
    push edi
    mov edi, rmcs
    xor al, al
    mov ecx, RMCS_SIZE
    rep stosb
    pop edi
    pop ecx
    pop eax
    ret

; ---------------------------------------------------------------------------
; Lpt_Open — open LPT1 in raw binary mode or create PRINTnnn.PRN file
; Returns: CF=0 success (g_lpt_handle set), CF=1 error
; ---------------------------------------------------------------------------
Lpt_Open:
    pushad

    call prn_ensure_buffer
    jc .fail

    cmp dword [g_cfg_prn_file], 0
    jnz .open_file

.open_lpt:
    ; Stage "LPT1\0" into DOS buffer at offset 0
    mov esi, lpt_dev_name
    mov edi, [prn_flat]
    mov ecx, 5
    rep movsb

    ; Open device LPT1 for write (INT 21h AX=3D01h, DS:DX = prn_seg:0)
    call prn_zero_rmcs
    mov word [rmcs + RMCS_EAX], 0x3D01
    mov dword [rmcs + RMCS_EDX], 0
    mov ax, [prn_seg]
    mov [rmcs + RMCS_DS], ax
    call prn_sim_int21
    test byte [rmcs + RMCS_FLAGS], 1
    jnz .fail

    movzx eax, word [rmcs + RMCS_EAX]
    mov [g_lpt_handle], eax
    mov ebx, eax

    ; Set RAW mode via IOCTL (INT 21h AX=4400h get, AX=4401h set)
    call prn_zero_rmcs
    mov word [rmcs + RMCS_EAX], 0x4400
    mov [rmcs + RMCS_EBX], ebx
    call prn_sim_int21
    test byte [rmcs + RMCS_FLAGS], 1
    jnz .done_ok

    mov dl, [rmcs + RMCS_EDX]
    test dl, 0x80                        ; verify character device
    jz .done_ok

    or dl, 0x20                          ; bit 5 = raw binary mode
    call prn_zero_rmcs
    mov word [rmcs + RMCS_EAX], 0x4401
    mov [rmcs + RMCS_EBX], ebx
    movzx edx, dl
    mov [rmcs + RMCS_EDX], edx
    call prn_sim_int21

.done_ok:
    popad
    clc
    ret

.open_file:
    ; Stage "PRINT001.PRN\0" into DOS buffer at offset 0
    mov esi, prn_file_name
    mov edi, [prn_flat]
    mov ecx, 13
    rep movsb

    ; Create file (INT 21h AH=3Ch, CX=0 normal attributes, DS:DX = prn_seg:0)
    call prn_zero_rmcs
    mov word [rmcs + RMCS_EAX], 0x3C00
    mov dword [rmcs + RMCS_ECX], 0
    mov dword [rmcs + RMCS_EDX], 0
    mov ax, [prn_seg]
    mov [rmcs + RMCS_DS], ax
    call prn_sim_int21
    test byte [rmcs + RMCS_FLAGS], 1
    jnz .fail

    movzx eax, word [rmcs + RMCS_EAX]
    mov [g_lpt_handle], eax
    popad
    clc
    ret

.fail:
    mov dword [g_lpt_handle], -1
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

    test ecx, ecx
    jz .ok

.write_loop:
    mov eax, ecx
    cmp eax, PRN_CHUNK_SIZE
    jbe .do_chunk
    mov eax, PRN_CHUNK_SIZE
.do_chunk:
    push ecx
    push eax

    ; Copy chunk from [ESI] to [prn_flat + 16]
    push esi
    mov edi, [prn_flat]
    add edi, 16
    mov ecx, eax
    rep movsb
    pop esi

    ; Reflect INT 21h AH=40h (Write to file EBX, CX=eax bytes, DS:DX=prn_seg:16)
    call prn_zero_rmcs
    mov word [rmcs + RMCS_EAX], 0x4000
    mov [rmcs + RMCS_EBX], ebx
    mov [rmcs + RMCS_ECX], eax
    mov dword [rmcs + RMCS_EDX], 16
    mov ax, [prn_seg]
    mov [rmcs + RMCS_DS], ax
    call prn_sim_int21

    pop eax                              ; eax = requested bytes
    pop ecx                              ; ecx = total remaining bytes

    test byte [rmcs + RMCS_FLAGS], 1
    jnz .fail

    movzx edx, word [rmcs + RMCS_EAX]    ; edx = actual written bytes
    cmp edx, eax
    jne .fail

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
    pushad
    mov ebx, [g_lpt_handle]
    cmp ebx, -1
    je .done

    call prn_zero_rmcs
    mov word [rmcs + RMCS_EAX], 0x3E00
    mov [rmcs + RMCS_EBX], ebx
    call prn_sim_int21
    mov dword [g_lpt_handle], -1

.done:
    popad
    ret
