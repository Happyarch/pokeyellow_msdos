; serial.asm — Game Boy Printer packet staging & transmission state machine.
;
; Mirror of pret engine/printer/serial.asm.
;
; UNPORTED ROUTINE:
;   PrinterSerial_ (pret :452-632) — the per-byte serial interrupt pump is
;   unported because serial transmission is superseded by the synchronous
;   in-memory virtual GB Printer packet consumption (PrintDev_ConsumePacket).
;   See docs/current_plan_printer.md.
;
; ---------------------------------------------------------------------------

bits 32

%include "gb_memmap.inc"

%define rSB IO_SB
%define rSC IO_SC

; Status indicator constants (pret constants/printer_constants.asm)
PRINTER_STATUS_BLANK            equ 0
PRINTER_STATUS_CHECKING_LINK    equ 1
PRINTER_STATUS_TRANSMITTING     equ 2
PRINTER_STATUS_PRINTING         equ 3
PRINTER_ERROR_1                 equ 4
PRINTER_ERROR_2                 equ 5
PRINTER_ERROR_3                 equ 6
PRINTER_ERROR_4                 equ 7
PRINTER_ERROR_WRONG_DEVICE      equ 8

global StartTransmission_Send9Rows
global Printer_StartTransmission
global PrinterTransmissionJumptable
global Printer_Next
global Printer_Back
global Printer_Quit
global Printer_Next_
global Printer_LoopBack
global Printer_InitSerial
global Printer_StartTransmittingTilemap
global Printer_EndTilemapTransmission
global Printer_SignalSendHeader
global Printer_SignalLoopBack
global Printer_WaitSerial
global Printer_WaitSerialAndLoopBack2
global Printer_CheckConnectionStatus
global Printer_TransmissionLoop
global Printer_WaitUntilFinished
global Printer_WaitLoopBack
global Printer_WaitLoopBack_
global Printer_PrepareToSend
global CopyPrinterDataHeader
global ResetPrinterData
global ComputePrinterChecksum
global Printer_StageHeaderForSend
global Printer_Convert2RowsTo2bpp
global Printer_FillMemory
global PrinterDataPacket1
global PrinterDataPacket2
global PrinterDataPacket3
global PrinterDataPacket4
global PrinterDataPacket5
global PrinterDataPacket6

global PrintDev_ConsumePacket
global PrintDev_Cancel

section .text

StartTransmission_Send9Rows:
    mov al, 9
Printer_StartTransmission:
    push eax
    lea edi, [ebp + wPrinterData]
    mov ecx, W_PRINTER_DATA_SIZE
    xor al, al
    call Printer_FillMemory
    xor al, al
    mov [ebp + rSB], al
    mov [ebp + rSC], al
    mov [ebp + wPrinterOpcode], al
    or byte [ebp + wPrinterConnectionOpen], 1
    mov al, [ebp + wPrinterSettings]
    mov [ebp + wPrinterSettingsTempCopy], al
    pop eax
    mov [ebp + wPrinterQueueLength], al
    ret

PrinterTransmissionJumptable:
    movzx eax, byte [ebp + wPrinterSendState]
    jmp [.Jumptable + eax * 4]

.Jumptable:
    dd Printer_InitSerial               ; 00
    dd Printer_CheckConnectionStatus    ; 01
    dd Printer_WaitSerial               ; 02
    dd Printer_StartTransmittingTilemap ; 03
    dd Printer_TransmissionLoop         ; 04
    dd Printer_WaitSerialAndLoopBack2   ; 05
    dd Printer_EndTilemapTransmission   ; 06
    dd Printer_TransmissionLoop         ; 07
    dd Printer_WaitSerial               ; 08

    dd Printer_SignalSendHeader         ; 09
    dd Printer_TransmissionLoop         ; 0a
    dd Printer_WaitSerial               ; 0b
    dd Printer_WaitUntilFinished        ; 0c
    dd Printer_Quit                     ; 0d

    dd Printer_Next_                    ; 0e
    dd Printer_WaitSerial               ; 0f
    dd Printer_SignalLoopBack           ; 10
    dd Printer_LoopBack                 ; 11
    dd Printer_WaitLoopBack             ; 12
    dd Printer_WaitLoopBack_            ; 13

Printer_Next:
    inc byte [ebp + wPrinterSendState]
    ret

Printer_Back:
    dec byte [ebp + wPrinterSendState]
    ret

Printer_Quit:
    mov byte [ebp + wPrinterStatusFlags], 0
    or byte [ebp + wPrinterSendState], 0x80
    ret

Printer_Next_:
    call Printer_Next
    ret

Printer_LoopBack:
    mov byte [ebp + wPrinterSendState], 1
    ret

Printer_InitSerial:
    call ResetPrinterData
    mov esi, PrinterDataPacket1
    call CopyPrinterDataHeader
    mov word [ebp + wPrinterDataSize], 0
    mov al, [ebp + wPrinterQueueLength]
    mov [ebp + wPrinterRowIndex], al
    call Printer_Next
    call Printer_PrepareToSend
    mov byte [ebp + wPrinterStatusIndicator], PRINTER_STATUS_CHECKING_LINK
    ret

Printer_StartTransmittingTilemap:
    call ResetPrinterData
    mov al, [ebp + wPrinterRowIndex]
    test al, al
    jz Printer_EndTilemapTransmission
    mov esi, PrinterDataPacket3
    call CopyPrinterDataHeader
    call Printer_Convert2RowsTo2bpp
    mov word [ebp + wPrinterDataSize], wPrinterSendDataSource1End - wPrinterSendDataSource1
    call ComputePrinterChecksum
    call Printer_Next
    call Printer_PrepareToSend
    mov byte [ebp + wPrinterStatusIndicator], PRINTER_STATUS_TRANSMITTING
    ret

Printer_EndTilemapTransmission:
    mov byte [ebp + wPrinterSendState], 6
    mov esi, PrinterDataPacket4
    call CopyPrinterDataHeader
    mov word [ebp + wPrinterDataSize], 0
    call Printer_Next
    call Printer_PrepareToSend
    ret

Printer_SignalSendHeader:
    call ResetPrinterData
    mov esi, PrinterDataPacket2
    call CopyPrinterDataHeader
    call Printer_StageHeaderForSend
    mov word [ebp + wPrinterDataSize], 4
    call ComputePrinterChecksum
    call Printer_Next
    call Printer_PrepareToSend
    mov byte [ebp + wPrinterStatusIndicator], PRINTER_STATUS_PRINTING
    ret

Printer_SignalLoopBack:
    call ResetPrinterData
    mov esi, PrinterDataPacket1
    call CopyPrinterDataHeader
    mov word [ebp + wPrinterDataSize], 0
    mov al, [ebp + wPrinterQueueLength]
    mov [ebp + wPrinterRowIndex], al
    call Printer_Next
    call Printer_PrepareToSend
    ret

Printer_WaitSerial:
    inc byte [ebp + wPrinterSerialFrameDelay]
    cmp byte [ebp + wPrinterSerialFrameDelay], 6
    jb .ret
    mov byte [ebp + wPrinterSerialFrameDelay], 0
    call Printer_Next
.ret:
    ret

Printer_WaitSerialAndLoopBack2:
    inc byte [ebp + wPrinterSerialFrameDelay]
    cmp byte [ebp + wPrinterSerialFrameDelay], 6
    jb .ret
    mov byte [ebp + wPrinterSerialFrameDelay], 0
    dec byte [ebp + wPrinterRowIndex]
    call Printer_Back
    call Printer_Back
.ret:
    ret

Printer_CheckConnectionStatus:
    mov al, [ebp + wPrinterOpcode]
    test al, al
    jnz .ret
    mov al, [ebp + wPrinterHandshake]
    cmp al, 0xFF
    jne .check_ack
    cmp byte [ebp + wPrinterStatusFlags], 0xFF
    je .error
.check_ack:
    cmp byte [ebp + wPrinterHandshake], 0x81
    jne .error
    cmp byte [ebp + wPrinterStatusFlags], 0
    jne .error
    or byte [ebp + wPrinterConnectionOpen], 2
    mov byte [ebp + wHandshakeFrameDelay], 5
    call Printer_Next
    ret

.error:
    mov byte [ebp + wPrinterHandshake], 0xFF
    mov byte [ebp + wPrinterStatusFlags], 0xFF
    mov byte [ebp + wPrinterSendState], 0x0E
.ret:
    ret

Printer_TransmissionLoop:
    mov al, [ebp + wPrinterOpcode]
    test al, al
    jnz .ret
    mov al, [ebp + wPrinterStatusFlags]
    test al, 0xF0
    jnz .error
    test al, 0x01
    jnz .back
    call Printer_Next
    ret

.back:
    call Printer_Back
    ret

.error:
    mov byte [ebp + wPrinterSendState], 0x12
.ret:
    ret

Printer_WaitUntilFinished:
    mov al, [ebp + wPrinterOpcode]
    test al, al
    jnz .ret
    mov al, [ebp + wPrinterStatusFlags]
    test al, 0xF3
    jnz .ret
    call Printer_Next
.ret:
    ret

Printer_WaitLoopBack:
    call Printer_Next
Printer_WaitLoopBack_:
    mov al, [ebp + wPrinterOpcode]
    test al, al
    jnz .ret
    test byte [ebp + wPrinterStatusFlags], 0xF0
    jnz .ret
    mov byte [ebp + wPrinterSendState], 0
.ret:
    ret

; DEVIATION{class=HAL; pret=engine/printer/serial.asm:Printer_PrepareToSend; behavior=in-memory virtual GB Printer packet consumption replaces rSB/rSC serial transmission; evidence=docs/current_plan_printer.md; lifetime=permanent}
Printer_PrepareToSend:
    mov word [ebp + wPrinterSendByteOffset], 0
    call PrintDev_ConsumePacket
    ret

PrintDev_ConsumePacket:
    ; Minimal ACK-only device response for Stage 1: publish handshake $81, status $00, opcode $00
    mov byte [ebp + wPrinterHandshake], 0x81
    mov byte [ebp + wPrinterStatusFlags], 0x00
    mov byte [ebp + wPrinterOpcode], 0x00
    ret

PrintDev_Cancel:
    ; Minimal cancel response: clear opcode
    mov byte [ebp + wPrinterOpcode], 0x00
    ret

CopyPrinterDataHeader:
    mov eax, [esi]
    mov [ebp + wPrinterDataHeader], eax
    mov ax, [esi + 4]
    mov [ebp + wPrinterChecksum], ax
    ret

ResetPrinterData:
    mov dword [ebp + wPrinterDataHeader], 0
    mov word [ebp + wPrinterChecksum], 0
    mov word [ebp + wPrinterDataSize], 0
    lea edi, [ebp + wPrinterSendDataSource1]
    mov ecx, wPrinterSendDataSource1End - wPrinterSendDataSource1
    xor al, al
    call Printer_FillMemory
    ret

ComputePrinterChecksum:
    xor eax, eax
    lea edx, [ebp + wPrinterDataHeader]
    mov ecx, 4
    call .AddToChecksum
    lea edx, [ebp + wPrinterSendDataSource1]
    movzx ecx, word [ebp + wPrinterDataSize]
    call .AddToChecksum
    mov [ebp + wPrinterChecksum], ax
    ret

.AddToChecksum:
    test ecx, ecx
    jz .done
.loop:
    movzx ebx, byte [edx]
    inc edx
    add ax, bx
    dec ecx
    jnz .loop
.done:
    ret

Printer_StageHeaderForSend:
    mov byte [ebp + wPrinterSendDataSource1], 1
    mov al, [ebp + wcae2]
    mov [ebp + wPrinterSendDataSource1 + 1], al
    mov byte [ebp + wPrinterSendDataSource1 + 2], 0b11100100
    mov al, [ebp + wPrinterSettingsTempCopy]
    mov [ebp + wPrinterSendDataSource1 + 3], al
    ret

; DEVIATION{class=HAL; pret=engine/printer/serial.asm:Printer_Convert2RowsTo2bpp; behavior=direct 16-byte VRAM-to-WRAM copy replaces CopyVideoData VBlank queue; evidence=port CopyVideoData is flat-source to VRAM-dest; lifetime=permanent}
Printer_Convert2RowsTo2bpp:
    movzx eax, byte [ebp + wPrinterRowIndex]
    movzx edx, byte [ebp + wPrinterQueueLength]
    sub edx, eax                        ; edx = row pair index (0-based)
    imul edx, edx, 2 * 20               ; 40 bytes per row pair (2 rows of 20 tiles)
    lea edx, [ebp + wPrinterTileBuffer + edx] ; edx = tilemap pointer

    lea edi, [ebp + wPrinterSendDataSource1] ; edi = dest 2bpp tile buffer
    mov ecx, 2 * 20                     ; 40 tiles to convert

.loop:
    movzx eax, byte [edx]               ; tile id
    inc edx

    cmp al, 0x80
    jae .vchars1
    ; 0x00..0x7F -> VRAM $9000..$97F0 (vChars2)
    shl eax, 4
    add eax, 0x9000
    jmp .copy_tile

.vchars1:
    ; 0x80..0xFF -> VRAM $8800..$8FF0 (vChars1)
    sub al, 0x80
    shl eax, 4
    add eax, 0x8800

.copy_tile:
    lea esi, [ebp + eax]                ; esi = source 16-byte tile pattern in VRAM
    ; Copy 16 bytes (1 tile = 4 dwords) from VRAM to wPrinterSendDataSource1
    mov eax, [esi]
    mov [edi], eax
    mov eax, [esi + 4]
    mov [edi + 4], eax
    mov eax, [esi + 8]
    mov [edi + 8], eax
    mov eax, [esi + 12]
    mov [edi + 12], eax

    add edi, 16
    dec ecx
    jnz .loop
    ret

Printer_FillMemory:
    push edi
    push ecx
    rep stosb
    pop ecx
    pop edi
    ret

section .data

PrinterDataPacket1:
    db 1, 0, 0x00, 0
    dw 1

PrinterDataPacket2:
    db 2, 0, 0x04, 0
    dw 0

PrinterDataPacket3:
    db 4, 0, 0x80, 2
    dw 0

PrinterDataPacket4:
    db 4, 0, 0x00, 0
    dw 4

PrinterDataPacket5: ; unused
    db 8, 0, 0x00, 0
    dw 8

PrinterDataPacket6: ; unused
    db 15, 0, 0x00, 0
    dw 15
