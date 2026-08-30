; ===========================================================================
; print_dev.asm — port-only in-memory virtual Game Boy Printer device.
;
; Consumes GB Printer packets emitted by serial.asm (Printer_PrepareToSend)
; and accumulates 2bpp bands in memory for the ESC/P page backend.
; See docs/plans/printer.md.
; ===========================================================================

bits 32

%include "gb_memmap.inc"

; Game Boy Printer packet command IDs
PRN_CMD_INIT                    equ 0x01
PRN_CMD_PRINT                   equ 0x02
PRN_CMD_DATA                    equ 0x04
PRN_CMD_STATUS                  equ 0x0F

; Status bit flags (pret PRINTER_STATUS_* flags returned to GB)
PRN_STATUS_CHECKSUM_ERROR       equ 0x01
PRN_STATUS_PRINT_BUSY           equ 0x02
PRN_STATUS_IMAGE_DATA_FULL      equ 0x08
PRN_STATUS_UNPROCESSED_DATA     equ 0x10
PRN_STATUS_PACKET_ERROR         equ 0x20
PRN_STATUS_PAPER_JAM            equ 0x40
PRN_STATUS_LOW_BATTERY          equ 0x80

BAND_SIZE_BYTES                 equ 640          ; 40 tiles * 16 bytes = 20 * 2 tiles
MAX_BANDS_PER_PAGE              equ 9            ; 18 rows * 20 tiles = 9 bands max
MAX_PAGE_BYTES                  equ BAND_SIZE_BYTES * MAX_BANDS_PER_PAGE ; 5760 bytes

global PrintDev_ConsumePacket
global PrintDev_Cancel
global PrintDev_Reset

global g_cfg_prn_lpt
global g_cfg_prn_file
global g_cfg_prn_color
global g_cfg_prn_9pin

global g_print_band_count
global g_print_band_buf
global g_print_pal_buf
global g_print_sheets
global g_print_margins
global g_print_palette
global g_print_exposure
global g_print_status_flags

section .data

g_cfg_prn_lpt:                  dd 1             ; default LPT1 (1)
g_cfg_prn_file:                 dd 0             ; default false (0)
g_cfg_prn_color:                dd 0             ; default monochrome (0)
g_cfg_prn_9pin:                 dd 0             ; default 24-pin ESC/P (0)

g_print_band_count:             dd 0
g_print_sheets:                 db 0
g_print_margins:                db 0
g_print_palette:                db 0
g_print_exposure:               db 0
g_print_status_flags:           db 0

section .bss

g_print_band_buf:               resb MAX_PAGE_BYTES
g_print_pal_buf:                resb 360         ; 20x18 cell palette sidecar for Stage 5

extern Escp_PrintPage                    ; src/print/escp.asm

section .text

; ---------------------------------------------------------------------------
; PrintDev_Reset — initialize virtual printer device state
; ---------------------------------------------------------------------------
PrintDev_Reset:
    mov dword [g_print_band_count], 0
    mov byte [g_print_status_flags], 0
    ret

; ---------------------------------------------------------------------------
; PrintDev_Cancel — abort current print job and reset buffer
; ---------------------------------------------------------------------------
PrintDev_Cancel:
    mov dword [g_print_band_count], 0
    mov byte [ebp + wPrinterOpcode], 0
    mov byte [ebp + wPrinterHandshake], 0x81
    mov byte [ebp + wPrinterStatusFlags], 0
    ret

; ---------------------------------------------------------------------------
; PrintDev_ConsumePacket — packet arrival entry from serial.asm (Printer_PrepareToSend)
; Reads:
;   wPrinterDataHeader: 4 bytes (Magic1, Magic2, Command, Compression)
;   wPrinterDataSize:   word (length of payload at wPrinterSendDataSource1)
;   wPrinterChecksum:   word (16-bit sum)
;   wPrinterSendDataSource1: payload
; Writes:
;   wPrinterHandshake:   0x81 (ACK)
;   wPrinterStatusFlags: device status flags
;   wPrinterOpcode:      0x00 (ready / command completed)
; ---------------------------------------------------------------------------
PrintDev_ConsumePacket:
    pushad

    ; Verify Checksum
    call .VerifyChecksum
    jnc .checksum_ok
    or byte [g_print_status_flags], PRN_STATUS_CHECKSUM_ERROR
    jmp .respond

.checksum_ok:
    mov al, [ebp + wPrinterDataHeader + 0]       ; command (1=INIT, 2=PRINT, 4=DATA)
    cmp al, PRN_CMD_INIT
    je .handle_init
    cmp al, PRN_CMD_DATA
    je .handle_data
    cmp al, PRN_CMD_PRINT
    je .handle_print
    cmp al, PRN_CMD_STATUS
    je .handle_status
    jmp .respond

.handle_init:
    mov dword [g_print_band_count], 0
    mov byte [g_print_status_flags], 0
    jmp .respond

.handle_data:
    movzx ecx, word [ebp + wPrinterDataSize]
    test ecx, ecx
    jz .respond                                  ; empty data packet (close/sync)

    mov eax, [g_print_band_count]
    cmp eax, MAX_BANDS_PER_PAGE
    jae .buffer_full

    ; Destination in g_print_band_buf: g_print_band_buf + band_count * BAND_SIZE_BYTES
    imul eax, eax, BAND_SIZE_BYTES
    lea edi, [g_print_band_buf + eax]
    lea esi, [ebp + wPrinterSendDataSource1]
    rep movsb

    inc dword [g_print_band_count]
    jmp .respond

.buffer_full:
    or byte [g_print_status_flags], PRN_STATUS_IMAGE_DATA_FULL
    jmp .respond

.handle_print:
    ; 4-byte PRINT payload: sheets, margins, palette, exposure
    mov al, [ebp + wPrinterSendDataSource1 + 0]
    mov [g_print_sheets], al
    mov al, [ebp + wPrinterSendDataSource1 + 1]
    mov [g_print_margins], al
    mov al, [ebp + wPrinterSendDataSource1 + 2]
    mov [g_print_palette], al
    mov al, [ebp + wPrinterSendDataSource1 + 3]
    mov [g_print_exposure], al

    call PrintDev_RenderPage
    mov dword [g_print_band_count], 0
    jmp .respond

.handle_status:
    jmp .respond

.packet_error:
    or byte [g_print_status_flags], PRN_STATUS_PACKET_ERROR
    jmp .respond

.respond:
    mov byte [ebp + wPrinterHandshake], 0x81
    mov al, [g_print_status_flags]
    mov [ebp + wPrinterStatusFlags], al
    mov byte [ebp + wPrinterOpcode], 0x00

    popad
    ret

; ---------------------------------------------------------------------------
; .VerifyChecksum — compute 16-bit sum of header + payload and compare to wPrinterChecksum
; CF set on mismatch, CF clear on match.
; ---------------------------------------------------------------------------
.VerifyChecksum:
    xor edx, edx
    ; 4 header bytes
    movzx eax, byte [ebp + wPrinterDataHeader + 0]
    add edx, eax
    movzx eax, byte [ebp + wPrinterDataHeader + 1]
    add edx, eax
    movzx eax, byte [ebp + wPrinterDataHeader + 2]
    add edx, eax
    movzx eax, byte [ebp + wPrinterDataHeader + 3]
    add edx, eax

    ; payload bytes
    movzx ecx, word [ebp + wPrinterDataSize]
    test ecx, ecx
    jz .compare_checksum
    lea esi, [ebp + wPrinterSendDataSource1]
.sum_payload:
    movzx eax, byte [esi]
    inc esi
    add edx, eax
    dec ecx
    jnz .sum_payload

.compare_checksum:
    movzx eax, word [ebp + wPrinterChecksum]
    and edx, 0xFFFF
    cmp edx, eax
    je .checksum_matches
    stc
    ret

.checksum_matches:
    clc
    ret

; ---------------------------------------------------------------------------
; PrintDev_RenderPage — hook for Stage 4 ESC/P page backend
; ---------------------------------------------------------------------------
PrintDev_RenderPage:
    call Escp_PrintPage
    ret
