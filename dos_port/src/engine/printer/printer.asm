; ===========================================================================
; printer.asm — pret mirror of engine/printer/printer.asm.
;
; UNPORTED ROUTINES:
;   PrinterDebug (pret :387-432) — debug test routine, unreferenced in pret
;   (only called inside an unreferenced block in engine/movie/title.asm:209-213).
;   See docs/current_plan_printer.md.
;
; ===========================================================================

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "coords.inc"
%include "gb_text.inc"
%include "assets/printer_strings.inc"

extern SurfingMinigame_HighScore1Tilemap ; src/engine/minigame/surfing_pikachu.asm
extern SurfingMinigame_HighScore2Tilemap ; src/engine/minigame/surfing_pikachu.asm

%ifndef SET_PAL_GENERIC
SET_PAL_GENERIC equ 0x08
%endif

%ifndef PAD_B
PAD_B equ 0x02
%endif

PRINTER_STATUS_BLANK            equ 0
PRINTER_STATUS_CHECKING_LINK    equ 1
PRINTER_STATUS_TRANSMITTING     equ 2
PRINTER_STATUS_PRINTING         equ 3
PRINTER_ERROR_1                 equ 4
PRINTER_ERROR_2                 equ 5
PRINTER_ERROR_3                 equ 6
PRINTER_ERROR_4                 equ 7
PRINTER_ERROR_WRONG_DEVICE      equ 8

MUSIC_GB_PRINTER                equ 0xA3
BANK_AUDIO_4                    equ 0x1F

rIE                             equ 0xFFFF
rIF                             equ 0xFF0F

global PrintPokedexEntry
global Printer_GetDexEntryRegisters
global Printer_PrepareDexEntryForPrinting
global PrintSurfingMinigameHighScore
global PrintDiploma
global PrintDiplomaPage
global PrintPCBox
global PrintPCBoxPage
global PrintFanClubPortrait
global Printer_StopIfPressB
global Printer_CopyTileMapToPrinterTileBuffer
global Printer_CopyTileMapFromPrinterTileBuffer
global Printer_ResetJoypadHRAM
global Printer_PlayPrinterMusic
global Printer_PlayMapMusic
global Printer_FadeOutMusicAndWait
global GBPrinter_CheckForErrors
global GBPrinter_UpdateStatusMessage
global Printer_PrepareSurfingMinigameHighScoreTileMap
global Diploma_Surfing_CopyBox
global CopySurfingMinigameScore
global PrintPCBox_DrawPage1
global PrintPCBox_DrawPage2
global PrintPCBox_DrawPage3
global PrintPCBox_DrawPage4
global PrintPCBox_PlaceBoxMonInfo
global PrintPCBox_DrawTopBorder
global PrintPCBox_DrawLeftAndRightBorders
global PrintPCBox_DrawBottomBorder
global PrintPCBox_DrawBottomBorderAtHL
global PrintPCBox_PlaceHorizontalLines

global PrinterMonStats_OT
global PrinterMonStats_IDNo
global PrinterMonStats_Stats
global PrinterMonStats_Blank

global g_printer_capture_addr
global g_printer_capture_stride

extern ClearScreen                       ; src/home/copy2.asm
extern CopyVideoData                     ; src/home/copy2.asm
extern CopyData                          ; src/home/copy.asm
extern FillMemory                        ; src/home/copy2.asm
extern DelayFrame                        ; src/home/vblank.asm
extern DelayFrames                       ; src/home/delay.asm
extern Delay3                            ; src/home/palettes.asm
extern JoypadLowSensitivity              ; src/home/joypad2.asm
extern PlaySound                         ; src/home/audio.asm
extern StopAllMusic                      ; src/home/audio.asm
extern PlayDefaultMusic                  ; src/home/audio.asm
extern GBPalWhiteOutWithDelay3           ; src/home/palettes.asm
extern GBPalNormal                       ; src/home/palettes.asm
extern RunPaletteCommand                 ; src/home/palettes.asm
extern TextBoxBorder                     ; src/home/text.asm
extern PlaceString                       ; src/home/text.asm
extern PrintText                         ; src/home/window.asm
extern SaveScreenTilesToBuffer1          ; src/home/tilemap.asm
extern LoadScreenTilesFromBuffer1        ; src/home/tilemap.asm
extern ReloadMapAfterPrinter             ; src/home/overworld.asm
extern DrawDexEntryOnScreen              ; src/engine/menus/pokedex.asm
extern Pokedex_DrawInterface             ; src/engine/menus/pokedex.asm
extern Pokedex_PlacePokemonList          ; src/engine/menus/pokedex.asm
extern Pokedex_PrepareDexEntryForPrinting ; src/engine/menus/pokedex.asm
extern DisplayDiplomaTop                 ; src/engine/events/diploma2.asm
extern DisplayDiplomaBottom              ; src/engine/events/diploma2.asm
extern Printer_GetMonStats               ; src/engine/printer/printer2.asm
extern GetMonName                        ; src/home/names.asm
extern AddNTimes                         ; src/home/array.asm
extern StartTransmission_Send9Rows       ; src/engine/printer/serial.asm
extern Printer_StartTransmission         ; src/engine/printer/serial.asm
extern PrinterTransmissionJumptable      ; src/engine/printer/serial.asm
extern PrintDev_Cancel                   ; src/engine/printer/serial.asm

section .bss

g_printer_capture_addr:   resd 1
g_printer_capture_stride: resd 1

section .text

; ---------------------------------------------------------------------------
; PrintPokedexEntry — pret engine/printer/printer.asm:1-70.
; ---------------------------------------------------------------------------
PrintPokedexEntry:
    mov al, [ebp + wUpdateSpritesEnabled]
    push eax
    xor al, al
    mov [ebp + wUpdateSpritesEnabled], al
    mov [ebp + hCanceledPrinting], al
    call Printer_PlayPrinterMusic
    mov al, [ebp + rIE]
    push eax
    xor al, al
    mov [ebp + rIF], al
    mov byte [ebp + rIE], 9
    mov [ebp + hAutoBGTransferEnabled], al

    mov dword [g_printer_capture_addr], wTileMap
    mov dword [g_printer_capture_stride], 20

    call Printer_GetDexEntryRegisters
    call Printer_StartTransmission
    mov al, [ebp + wPrinterPokedexMonIsOwned]
    test al, al
    jz .not_caught
    mov al, 16
    jmp .got_size

.not_caught:
    mov al, 19
.got_size:
    mov [ebp + wcae2], al
    call Printer_CopyTileMapToPrinterTileBuffer
    call ClearScreen
    call Pokedex_DrawInterface
    call Pokedex_PlacePokemonList
    mov byte [ebp + hAutoBGTransferEnabled], 1
    call .TryPrintPage
    jc .finish_printing
    mov al, [ebp + wPrinterPokedexMonIsOwned]
    test al, al
    jz .finish_printing
    xor al, al
    mov [ebp + wPrinterConnectionOpen], al
    mov [ebp + wPrinterOpcode], al
    mov cl, 0x0C
    call DelayFrames
    call SaveScreenTilesToBuffer1
    xor al, al
    mov [ebp + hAutoBGTransferEnabled], al
    call Printer_PrepareDexEntryForPrinting
    mov al, 7
    call Printer_StartTransmission
    mov byte [ebp + wcae2], 3
    call Printer_CopyTileMapToPrinterTileBuffer
    call LoadScreenTilesFromBuffer1
    mov byte [ebp + hAutoBGTransferEnabled], 1
    call .TryPrintPage

.finish_printing:
    xor al, al
    mov [ebp + wPrinterConnectionOpen], al
    mov [ebp + wPrinterOpcode], al
    mov [ebp + rIF], al
    pop eax
    mov [ebp + rIE], al
    call ReloadMapAfterPrinter
    call Printer_PlayMapMusic
    pop eax
    mov [ebp + wUpdateSpritesEnabled], al
    ret

.TryPrintPage:
    call Printer_ResetJoypadHRAM
.print_loop:
    call JoypadLowSensitivity
    call Printer_StopIfPressB
    jc .pressed_b
    test byte [ebp + wPrinterSendState], 0x80
    jnz .completed
    call PrinterTransmissionJumptable
    call GBPrinter_CheckForErrors
    call GBPrinter_UpdateStatusMessage
    call DelayFrame
    jmp .print_loop

.completed:
    clc
    ret

.pressed_b:
    stc
    ret

; ---------------------------------------------------------------------------
; Printer_GetDexEntryRegisters — pret engine/printer/printer.asm:94-111.
; ---------------------------------------------------------------------------
Printer_GetDexEntryRegisters:
    call DrawDexEntryOnScreen
    mov [ebp + wPrinterPokedexEntryTextPointer], si
    setc al
    mov [ebp + wPrinterPokedexMonIsOwned], al
    test al, al
    jz .not_caught
    mov al, 5
    ret

.not_caught:
    mov al, 9
    ret

; ---------------------------------------------------------------------------
; Printer_PrepareDexEntryForPrinting — pret engine/printer/printer.asm:113-116.
; ---------------------------------------------------------------------------
Printer_PrepareDexEntryForPrinting:
    call ClearScreen
    call Pokedex_PrepareDexEntryForPrinting
    ret

; ---------------------------------------------------------------------------
; PrintSurfingMinigameHighScore — pret engine/printer/printer.asm:118-159.
; ---------------------------------------------------------------------------
PrintSurfingMinigameHighScore:
    xor al, al
    mov [ebp + hCanceledPrinting], al
    call Printer_PlayPrinterMusic
    mov dword [g_printer_capture_addr], wTileMap + 3 * SCREEN_WIDTH + 10
    mov dword [g_printer_capture_stride], SCREEN_WIDTH
    call Printer_PrepareSurfingMinigameHighScoreTileMap
    mov al, [ebp + rIE]
    push eax
    xor al, al
    mov [ebp + rIF], al
    mov byte [ebp + rIE], 9
    call StartTransmission_Send9Rows
    mov byte [ebp + wcae2], 0x13
    call Printer_CopyTileMapToPrinterTileBuffer
    call Printer_ResetJoypadHRAM
.loop:
    call JoypadLowSensitivity
    call Printer_StopIfPressB
    jc .quit
    test byte [ebp + wPrinterSendState], 0x80
    jnz .quit
    call PrinterTransmissionJumptable
    call GBPrinter_CheckForErrors
    call GBPrinter_UpdateStatusMessage
    call DelayFrame
    jmp .loop

.quit:
    xor al, al
    mov [ebp + wPrinterConnectionOpen], al
    mov [ebp + wPrinterOpcode], al
    call Printer_CopyTileMapFromPrinterTileBuffer
    xor al, al
    mov [ebp + rIF], al
    pop eax
    mov [ebp + rIE], al
    call ReloadMapAfterPrinter
    call Printer_PlayMapMusic
    ret

; ---------------------------------------------------------------------------
; PrintDiploma — pret engine/printer/printer.asm:160-204.
; ---------------------------------------------------------------------------
PrintDiploma:
    xor al, al
    mov [ebp + hCanceledPrinting], al
    call Printer_PlayPrinterMusic
    mov dword [g_printer_capture_addr], wTileMap + 3 * SCREEN_WIDTH + 10
    mov dword [g_printer_capture_stride], SCREEN_WIDTH
    call DisplayDiplomaTop
    mov al, [ebp + rIE]
    push eax
    xor al, al
    mov [ebp + rIF], al
    mov byte [ebp + rIE], 9
    call StartTransmission_Send9Rows
    mov byte [ebp + wcae2], 0x10
    call Printer_CopyTileMapToPrinterTileBuffer
    call PrintDiplomaPage
    jc .quit
    xor al, al
    mov [ebp + wPrinterConnectionOpen], al
    mov [ebp + wPrinterOpcode], al
    mov cl, 0x0C
    call DelayFrames
    call SaveScreenTilesToBuffer1
    xor al, al
    mov [ebp + hAutoBGTransferEnabled], al
    call DisplayDiplomaBottom
    call StartTransmission_Send9Rows
    mov byte [ebp + wcae2], 3
    call Printer_CopyTileMapToPrinterTileBuffer
    call LoadScreenTilesFromBuffer1
    call PrintDiplomaPage
.quit:
    xor al, al
    mov [ebp + wPrinterConnectionOpen], al
    mov [ebp + wPrinterOpcode], al
    call Printer_CopyTileMapFromPrinterTileBuffer
    xor al, al
    mov [ebp + rIF], al
    pop eax
    mov [ebp + rIE], al
    call ReloadMapAfterPrinter
    call Printer_PlayMapMusic
    ret

; ---------------------------------------------------------------------------
; PrintDiplomaPage — pret engine/printer/printer.asm:205-226.
; ---------------------------------------------------------------------------
PrintDiplomaPage:
    call Printer_ResetJoypadHRAM
.print_loop:
    call JoypadLowSensitivity
    call Printer_StopIfPressB
    jc .pressed_b
    test byte [ebp + wPrinterSendState], 0x80
    jnz .completed
    call PrinterTransmissionJumptable
    call GBPrinter_CheckForErrors
    call GBPrinter_UpdateStatusMessage
    call DelayFrame
    jmp .print_loop

.completed:
    clc
    ret

.pressed_b:
    stc
    ret

; ---------------------------------------------------------------------------
; PrintPCBox — pret engine/printer/printer.asm:228-316.
; ---------------------------------------------------------------------------
PrintPCBox:
    mov al, [ebp + wBoxCount]
    test al, al
    jz .emptyBox
    mov al, [ebp + wUpdateSpritesEnabled]
    push eax
    xor al, al
    mov [ebp + wUpdateSpritesEnabled], al
    mov [ebp + hCanceledPrinting], al
    call Printer_PlayPrinterMusic
    mov al, [ebp + rIE]
    push eax
    xor al, al
    mov [ebp + rIF], al
    mov byte [ebp + rIE], 9
    mov dword [g_printer_capture_addr], wTileMap + 3 * SCREEN_WIDTH + 10
    mov dword [g_printer_capture_stride], SCREEN_WIDTH
    call SaveScreenTilesToBuffer1
    xor al, al
    mov [ebp + hAutoBGTransferEnabled], al
    call PrintPCBox_DrawPage1
    call StartTransmission_Send9Rows
    mov byte [ebp + wcae2], 0x10
    call Printer_CopyTileMapToPrinterTileBuffer
    call LoadScreenTilesFromBuffer1
    call PrintPCBoxPage
    jc .quit
    xor al, al
    mov [ebp + wPrinterConnectionOpen], al
    mov [ebp + wPrinterOpcode], al
    mov cl, 12
    call DelayFrames
    xor al, al
    mov [ebp + hAutoBGTransferEnabled], al
    call PrintPCBox_DrawPage2
    call StartTransmission_Send9Rows
    mov byte [ebp + wcae2], 0
    call Printer_CopyTileMapToPrinterTileBuffer
    call LoadScreenTilesFromBuffer1
    call PrintPCBoxPage
    jc .quit
    xor al, al
    mov [ebp + wPrinterConnectionOpen], al
    mov [ebp + wPrinterOpcode], al
    mov cl, 12
    call DelayFrames
    xor al, al
    mov [ebp + hAutoBGTransferEnabled], al
    call PrintPCBox_DrawPage3
    call StartTransmission_Send9Rows
    mov byte [ebp + wcae2], 0
    call Printer_CopyTileMapToPrinterTileBuffer
    call LoadScreenTilesFromBuffer1
    call PrintPCBoxPage
    jc .quit
    xor al, al
    mov [ebp + wPrinterConnectionOpen], al
    mov [ebp + wPrinterOpcode], al
    mov cl, 12
    call DelayFrames
    xor al, al
    mov [ebp + hAutoBGTransferEnabled], al
    call PrintPCBox_DrawPage4
    call StartTransmission_Send9Rows
    mov byte [ebp + wcae2], 3
    call Printer_CopyTileMapToPrinterTileBuffer
    call LoadScreenTilesFromBuffer1
    call PrintPCBoxPage
.quit:
    xor al, al
    mov [ebp + wPrinterConnectionOpen], al
    mov [ebp + wPrinterOpcode], al
    mov [ebp + rIF], al
    pop eax
    mov [ebp + rIE], al
    call ReloadMapAfterPrinter
    call Printer_PlayMapMusic
    pop eax
    mov [ebp + wUpdateSpritesEnabled], al
    ret

.emptyBox:
    mov esi, NoPokemonText
    call PrintText
    ret

; ---------------------------------------------------------------------------
; PrintPCBoxPage — pret engine/printer/printer.asm:318-339.
; ---------------------------------------------------------------------------
PrintPCBoxPage:
    call Printer_ResetJoypadHRAM
.print_loop:
    call JoypadLowSensitivity
    call Printer_StopIfPressB
    jc .pressed_b
    test byte [ebp + wPrinterSendState], 0x80
    jnz .completed
    call PrinterTransmissionJumptable
    call GBPrinter_CheckForErrors
    call GBPrinter_UpdateStatusMessage
    call DelayFrame
    jmp .print_loop

.completed:
    clc
    ret

.pressed_b:
    stc
    ret

NoPokemonText:
    text_far _NoPokemonText
    text_end

; ---------------------------------------------------------------------------
; PrintFanClubPortrait — pret engine/printer/printer.asm:346-385.
; ---------------------------------------------------------------------------
PrintFanClubPortrait:
    xor al, al
    mov [ebp + hCanceledPrinting], al
    call Printer_PlayPrinterMusic
    mov dword [g_printer_capture_addr], wTileMap + 3 * SCREEN_WIDTH + 10
    mov dword [g_printer_capture_stride], SCREEN_WIDTH
    call Printer_GetMonStats
    mov al, [ebp + rIE]
    push eax
    xor al, al
    mov [ebp + rIF], al
    mov byte [ebp + rIE], 9
    call StartTransmission_Send9Rows
    mov byte [ebp + wcae2], 0x13
    call Printer_CopyTileMapToPrinterTileBuffer
    call Printer_ResetJoypadHRAM
.print_loop:
    call JoypadLowSensitivity
    call Printer_StopIfPressB
    jc .quit
    test byte [ebp + wPrinterSendState], 0x80
    jnz .quit
    call PrinterTransmissionJumptable
    call GBPrinter_CheckForErrors
    call GBPrinter_UpdateStatusMessage
    call DelayFrame
    jmp .print_loop

.quit:
    xor al, al
    mov [ebp + wPrinterConnectionOpen], al
    mov [ebp + wPrinterOpcode], al
    call Printer_CopyTileMapFromPrinterTileBuffer
    xor al, al
    mov [ebp + rIF], al
    pop eax
    mov [ebp + rIE], al
    call ReloadMapAfterPrinter
    call Printer_PlayMapMusic
    ret

; ---------------------------------------------------------------------------
; Printer_StopIfPressB — pret engine/printer/printer.asm:433-464.
;
; DEVIATION{class=HAL; pret=engine/printer/printer.asm:Printer_StopIfPressB; behavior=replaces direct rSB/rSC cancel burst with call PrintDev_Cancel; evidence=docs/current_plan_printer.md; lifetime=permanent}
; ---------------------------------------------------------------------------
Printer_StopIfPressB:
    test byte [ebp + hJoyHeld], PAD_B
    jnz .quit
    clc
    ret

.quit:
    cmp byte [ebp + wPrinterSendState], 0x0C
    jne .already_done
.wait_current_task:
    cmp byte [ebp + wPrinterOpcode], 0
    jne .wait_current_task
    mov byte [ebp + wPrinterOpcode], 0x16
    call PrintDev_Cancel
.wait_send_cancel:
    cmp byte [ebp + wPrinterOpcode], 0
    jne .wait_send_cancel
.already_done:
    mov byte [ebp + hCanceledPrinting], 1
    stc
    ret

; ---------------------------------------------------------------------------
; Printer_CopyTileMapToPrinterTileBuffer — pret engine/printer/printer.asm:466-471.
;
; DEVIATION{class=projection; pret=engine/printer/printer.asm:Printer_CopyTileMapToPrinterTileBuffer; behavior=copies 18 rows of 20 tiles from parameterized source address and stride to wPrinterTileBuffer; evidence=port uses 40x25 canvas with +10/+3 GB-centered projection for 4 screens and stride-20 scratch for pokedex; lifetime=permanent}
; ---------------------------------------------------------------------------
Printer_CopyTileMapToPrinterTileBuffer:
    mov esi, [g_printer_capture_addr]
    lea edi, [ebp + wPrinterTileBuffer]
    mov ecx, 18
.row_loop:
    push ecx
    push esi
    lea esi, [ebp + esi]
    mov ecx, 20
    rep movsb
    pop esi
    add esi, [g_printer_capture_stride]
    pop ecx
    dec ecx
    jnz .row_loop
    ret

; ---------------------------------------------------------------------------
; Printer_CopyTileMapFromPrinterTileBuffer — pret engine/printer/printer.asm:473-478.
;
; DEVIATION{class=projection; pret=engine/printer/printer.asm:Printer_CopyTileMapFromPrinterTileBuffer; behavior=restores 18 rows of 20 tiles from wPrinterTileBuffer to parameterized destination address and stride; evidence=port uses 40x25 canvas with +10/+3 GB-centered projection for 4 screens and stride-20 scratch for pokedex; lifetime=permanent}
; ---------------------------------------------------------------------------
Printer_CopyTileMapFromPrinterTileBuffer:
    lea esi, [ebp + wPrinterTileBuffer]
    mov edi, [g_printer_capture_addr]
    mov ecx, 18
.row_loop:
    push ecx
    push edi
    lea edi, [ebp + edi]
    mov ecx, 20
    rep movsb
    pop edi
    add edi, [g_printer_capture_stride]
    pop ecx
    dec ecx
    jnz .row_loop
    ret

; ---------------------------------------------------------------------------
; Printer_ResetJoypadHRAM — pret engine/printer/printer.asm:480-488.
; ---------------------------------------------------------------------------
Printer_ResetJoypadHRAM:
    xor al, al
    mov [ebp + hJoyLast], al
    mov [ebp + hJoyReleased], al
    mov [ebp + hJoyPressed], al
    mov [ebp + hJoyHeld], al
    mov [ebp + hJoy5], al
    mov [ebp + hJoy6], al
    ret

; ---------------------------------------------------------------------------
; Printer_PlayPrinterMusic — pret engine/printer/printer.asm:490-499.
; ---------------------------------------------------------------------------
Printer_PlayPrinterMusic:
    call Printer_FadeOutMusicAndWait
    mov al, [ebp + wAudioROMBank]
    mov [ebp + wAudioSavedROMBank], al
    mov byte [ebp + wAudioROMBank], BANK_AUDIO_4
    mov byte [ebp + wNewSoundID], MUSIC_GB_PRINTER
    call PlaySound
    ret

; ---------------------------------------------------------------------------
; Printer_PlayMapMusic — pret engine/printer/printer.asm:501-504.
; ---------------------------------------------------------------------------
Printer_PlayMapMusic:
    call Printer_FadeOutMusicAndWait
    call PlayDefaultMusic
    ret

; ---------------------------------------------------------------------------
; Printer_FadeOutMusicAndWait — pret engine/printer/printer.asm:506-514.
; ---------------------------------------------------------------------------
Printer_FadeOutMusicAndWait:
    mov byte [ebp + wAudioFadeOutControl], 4
    call StopAllMusic
.wait_music_stop:
    cmp byte [ebp + wAudioFadeOutControl], 0
    jne .wait_music_stop
    ret

; ---------------------------------------------------------------------------
; GBPrinter_CheckForErrors — pret engine/printer/printer.asm:516-550.
; ---------------------------------------------------------------------------
GBPrinter_CheckForErrors:
    mov al, [ebp + wPrinterHandshake]
    cmp al, 0x81
    je .check_other_errors
    mov al, [ebp + wPrinterStatusFlags]
    cmp al, 0xFF
    je .error2
    xor al, al
    jmp .load_status

.check_other_errors:
    mov al, [ebp + wPrinterStatusFlags]
    test al, 0xE0
    jz .ret
    test al, 0x80
    jnz .error1
    test al, 0x40
    jnz .error4
    ; error 3
    mov al, PRINTER_ERROR_3
    jmp .load_status

.error4:
    mov al, PRINTER_ERROR_4
    jmp .load_status

.error1:
    mov al, PRINTER_ERROR_1
    jmp .load_status

.error2:
    mov al, PRINTER_ERROR_2
.load_status:
    mov [ebp + wPrinterStatusIndicator], al
.ret:
    ret

PrinterStatusMessages:
    dd PrinterBlankText         ; 0
    dd PrinterCheckingLinkText  ; 1
    dd PrinterTransmittingText  ; 2
    dd PrinterPrintingText      ; 3
    dd PrinterError1Text        ; 4
    dd PrinterError2Text        ; 5
    dd PrinterError3Text        ; 6
    dd PrinterError4Text        ; 7
    dd PrinterWrongDeviceText   ; 8

; ---------------------------------------------------------------------------
; GBPrinter_UpdateStatusMessage — pret engine/printer/printer.asm:552-580.
;
; DEVIATION{class=projection; pret=engine/printer/printer.asm:GBPrinter_UpdateStatusMessage; behavior=draws printer status dialog box at (10,8) on 40x25 canvas or (0,5) on stride-20 pokedex scratch depending on active screen stride; evidence=port uses 40x25 canvas with +10/+3 GB-centered projection for 4 screens and stride-20 scratch for pokedex; lifetime=permanent}
; ---------------------------------------------------------------------------
GBPrinter_UpdateStatusMessage:
    mov al, [ebp + wPrinterStatusIndicator]
    test al, al
    jz .ret
    push eax
    xor al, al
    mov [ebp + hAutoBGTransferEnabled], al

    cmp dword [g_printer_capture_stride], 20
    jne .proj_40x25

    ; Stride 20 (Pokédex)
    mov esi, wTileMap + 5 * 20 + 0       ; hlcoord 0, 5
    mov bh, 10                           ; lb bc, 10, 18
    mov bl, 18
    call TextBoxBorder
    pop eax
    movzx edx, al
    mov edx, [PrinterStatusMessages + edx * 4]
    mov eax, edx
    mov esi, wTileMap + 7 * 20 + 1       ; hlcoord 1, 7
    call PlaceString
    mov edx, PrinterPressBToCancelText   ; ld de, .PressBToCancel
    mov eax, edx
    mov esi, wTileMap + 15 * 20 + 2      ; hlcoord 2, 15
    call PlaceString
    jmp .done

.proj_40x25:
    ; Stride 40 (+10 col, +3 row)
    hlcoord 10, 8                        ; PROJ — pret hlcoord 0, 5 -> (0+10, 5+3)
    mov bh, 10                           ; lb bc, 10, 18
    mov bl, 18
    call TextBoxBorder
    pop eax
    movzx edx, al
    mov edx, [PrinterStatusMessages + edx * 4]
    mov eax, edx
    hlcoord 11, 10                       ; PROJ — pret hlcoord 1, 7 -> (1+10, 7+3)
    call PlaceString
    mov edx, PrinterPressBToCancelText   ; ld de, .PressBToCancel
    mov eax, edx
    hlcoord 12, 18                       ; PROJ — pret hlcoord 2, 15 -> (2+10, 15+3)
    call PlaceString

.done:
    mov byte [ebp + hAutoBGTransferEnabled], 1
    mov byte [ebp + wPrinterStatusIndicator], 0
.ret:
    ret

; ---------------------------------------------------------------------------
; Printer_PrepareSurfingMinigameHighScoreTileMap — pret engine/printer/printer.asm:631-697.
;
; DEVIATION{class=projection; pret=engine/printer/printer.asm:Printer_PrepareSurfingMinigameHighScoreTileMap; behavior=the Surfing Pikachu high score screen layout is centered on the 40x25 canvas by adding 10 columns and 3 rows to pret hlcoords; evidence=pret 20x18 layout centered on port 40x25 canvas per maintainer screen projection ruling; lifetime=permanent while the port renders a 40x25 canvas}
; ---------------------------------------------------------------------------
Printer_PrepareSurfingMinigameHighScoreTileMap:
    call GBPalWhiteOutWithDelay3
    call ClearScreen
    mov edx, SurfingPikachu2Graphics
    mov esi, vChars2
    mov bh, 0                            ; BANK(SurfingPikachu2Graphics) unused
    mov bl, (SurfingPikachu2GraphicsEnd - SurfingPikachu2Graphics) / 16
    call CopyVideoData

    hlcoord 10, 3                        ; PROJ — pret hlcoord 0, 0
    call .PlaceRowAlternatingTiles
    hlcoord 10, 20                       ; PROJ — pret hlcoord 0, 17
    call .PlaceRowAlternatingTiles
    hlcoord 10, 3                        ; PROJ — pret hlcoord 0, 0
    call .PlaceColumnAlternatingTiles
    hlcoord 29, 3                        ; PROJ — pret hlcoord 19, 0
    call .PlaceColumnAlternatingTiles

    mov al, 4
    hlcoord 10, 3                        ; PROJ — pret hlcoord 0, 0
    mov [ebp + esi], al
    hlcoord 10, 20                       ; PROJ — pret hlcoord 0, 17
    mov [ebp + esi], al
    hlcoord 29, 3                        ; PROJ — pret hlcoord 19, 0
    mov [ebp + esi], al
    hlcoord 29, 20                       ; PROJ — pret hlcoord 19, 17
    mov [ebp + esi], al

    mov edx, SurfingMinigame_HighScore1Tilemap
    hlcoord 20, 11                       ; PROJ — pret hlcoord 10, 8 -> (10+10, 8+3)
    mov bh, 3                            ; lb bc, 3, 8
    mov bl, 8
    call Diploma_Surfing_CopyBox

    mov edx, SurfingMinigame_HighScore2Tilemap
    hlcoord 12, 14                       ; PROJ — pret hlcoord 2, 11 -> (2+10, 11+3)
    mov bh, 6                            ; lb bc, 6, 16
    mov bl, 16
    call Diploma_Surfing_CopyBox

    mov edx, PrinterPikachusBeachString  ; ld de, .PikachusBeachString
    mov eax, edx
    hlcoord 13, 5                        ; PROJ — pret hlcoord 3, 2 -> (3+10, 2+3)
    call PlaceString

    mov edx, PrinterHiScoreString        ; ld de, .HiScoreString
    mov eax, edx
    hlcoord 19, 7                        ; PROJ — pret hlcoord 9, 4 -> (9+10, 4+3)
    call PlaceString

    mov edx, PrinterPointsString         ; ld de, .PointsString
    mov eax, edx
    hlcoord 22, 9                        ; PROJ — pret hlcoord 12, 6 -> (12+10, 6+3)
    call PlaceString

    mov edx, wPlayerName
    mov esi, wPlayerName
    xor ecx, ecx
.find_end_of_name:
    mov al, [ebp + esi]
    inc esi
    inc cl
    cmp al, 0x50                         ; '@'
    jne .find_end_of_name
    mov al, 8
    sub al, cl
    jnc .got_name_length
    xor al, al
.got_name_length:
    movzx ecx, al
    hlcoord 12, 7                        ; PROJ — pret hlcoord 2, 4 -> (2+10, 4+3)
    add esi, ecx
    lea eax, [ebp + wPlayerName]
    call PlaceString
    call CopySurfingMinigameScore
    mov bl, SET_PAL_GENERIC              ; ld b, SET_PAL_GENERIC
    call RunPaletteCommand
    mov byte [ebp + hAutoBGTransferEnabled], 1
    call Delay3
    call GBPalNormal
    ret

.PlaceRowAlternatingTiles:
    mov cl, 20 / 2                       ; ld c, SCREEN_WIDTH / 2 (pret extent = 10 pairs)
.row_loop:
    mov byte [ebp + esi], 0
    inc esi
    mov byte [ebp + esi], 1
    inc esi
    dec cl
    jnz .row_loop
    ret

.PlaceColumnAlternatingTiles:
    mov cl, 18 / 2                       ; ld c, SCREEN_HEIGHT / 2 (pret extent = 9 pairs)
.col_loop:
    mov byte [ebp + esi], 2
    add esi, SCREEN_WIDTH                ; advance 1 canvas row (stride 40)
    mov byte [ebp + esi], 3
    add esi, SCREEN_WIDTH
    dec cl
    jnz .col_loop
    ret

; ---------------------------------------------------------------------------
; Diploma_Surfing_CopyBox — pret engine/printer/printer.asm:734-750.
; ---------------------------------------------------------------------------
Diploma_Surfing_CopyBox:
.y:
    push ebx
    push esi
.x:
    mov al, [edx]
    inc edx
    mov [ebp + esi], al
    inc esi
    dec bl
    jnz .x
    pop esi
    add esi, SCREEN_WIDTH
    pop ebx
    dec bh
    jnz .y
    ret

; ---------------------------------------------------------------------------
; CopySurfingMinigameScore — pret engine/printer/printer.asm:752-770.
;
; DEVIATION{class=projection; pret=engine/printer/printer.asm:CopySurfingMinigameScore; behavior=the score display is placed at (17,9) on the 40x25 canvas; evidence=pret hlcoord 7,6 centered on port 40x25 canvas via +10 col / +3 row; lifetime=permanent while the port renders a 40x25 canvas}
; ---------------------------------------------------------------------------
CopySurfingMinigameScore:
    mov edx, wSurfingMinigameHiScore + 1
    hlcoord 17, 9                        ; PROJ — pret hlcoord 7, 6 -> (7+10, 6+3)
    mov al, [ebp + edx]
    call .BCDConvertScore
    mov al, [ebp + edx]
.BCDConvertScore:
    mov cl, al
    shr al, 4                            ; swap a / and $f
    add al, -10                          ; tile offset for digits
    mov [ebp + esi], al
    inc esi
    mov al, cl
    and al, 0x0F
    add al, -10
    mov [ebp + esi], al
    inc esi
    dec edx
    ret

; ---------------------------------------------------------------------------
; PrintPCBox_DrawPage1 — pret engine/printer/printer.asm:774-810.
;
; DEVIATION{class=projection; pret=engine/printer/printer.asm:PrintPCBox_DrawPage1; behavior=the PC box print page 1 layout is centered on the 40x25 canvas by adding 10 columns and 3 rows to pret hlcoords; evidence=pret 20x18 layout centered on port 40x25 canvas per maintainer screen projection ruling; lifetime=permanent while the port renders a 40x25 canvas}
; ---------------------------------------------------------------------------
PrintPCBox_DrawPage1:
    xor al, al
    mov [ebp + wBoxNumString], al
    call ClearScreen
    call PrintPCBox_PlaceHorizontalLines
    hlcoord 10, 3                        ; PROJ — pret hlcoord 0, 0
    mov cl, 11
.fill_11_rows:
    push ecx
    push esi
    mov bh, 0
    mov bl, 20
    mov al, ' '
    call FillMemory
    pop esi
    add esi, SCREEN_WIDTH
    pop ecx
    dec cl
    jnz .fill_11_rows

    call PrintPCBox_DrawLeftAndRightBorders
    call PrintPCBox_DrawTopBorder
    hlcoord 14, 7                        ; PROJ — pret hlcoord 4, 4 -> (4+10, 4+3)
    mov edx, PrinterPokemonListString
    mov eax, edx
    call PlaceString

    hlcoord 17, 9                        ; PROJ — pret hlcoord 7, 6 -> (7+10, 6+3)
    mov edx, PrinterBoxString
    mov eax, edx
    call PlaceString

    hlcoord 21, 9                        ; PROJ — pret hlcoord 11, 6 -> (11+10, 6+3)
    mov al, [ebp + wCurrentBoxNum]
    and al, 0x7F
    cmp al, 9
    jb .less_than_9
    sub al, 9
    mov byte [ebp + esi], '1'
    inc esi
    add al, '0'
    jmp .placed_box_number

.less_than_9:
    add al, '1'
.placed_box_number:
    mov [ebp + esi], al
    hlcoord 14, 12                       ; PROJ — pret hlcoord 4, 9 -> (4+10, 9+3)
    mov edx, wBoxSpecies
    mov cl, 3
    call PrintPCBox_PlaceBoxMonInfo
    ret

; ---------------------------------------------------------------------------
; PrintPCBox_DrawPage2 — pret engine/printer/printer.asm:815-827.
;
; DEVIATION{class=projection; pret=engine/printer/printer.asm:PrintPCBox_DrawPage2; behavior=the PC box print page 2 layout is centered on the 40x25 canvas by adding 10 columns and 3 rows to pret hlcoords; evidence=pret 20x18 layout centered on port 40x25 canvas per maintainer screen projection ruling; lifetime=permanent while the port renders a 40x25 canvas}
; ---------------------------------------------------------------------------
PrintPCBox_DrawPage2:
    call ClearScreen
    call PrintPCBox_PlaceHorizontalLines
    call PrintPCBox_DrawLeftAndRightBorders
    cmp byte [ebp + wBoxDataStart], 4
    jb .ret
    hlcoord 14, 3                        ; PROJ — pret hlcoord 4, 0 -> (4+10, 0+3)
    mov edx, wBoxSpecies + 3
    mov cl, 6
    call PrintPCBox_PlaceBoxMonInfo
.ret:
    ret

; ---------------------------------------------------------------------------
; PrintPCBox_DrawPage3 — pret engine/printer/printer.asm:828-840.
;
; DEVIATION{class=projection; pret=engine/printer/printer.asm:PrintPCBox_DrawPage3; behavior=the PC box print page 3 layout is centered on the 40x25 canvas by adding 10 columns and 3 rows to pret hlcoords; evidence=pret 20x18 layout centered on port 40x25 canvas per maintainer screen projection ruling; lifetime=permanent while the port renders a 40x25 canvas}
; ---------------------------------------------------------------------------
PrintPCBox_DrawPage3:
    call ClearScreen
    call PrintPCBox_PlaceHorizontalLines
    call PrintPCBox_DrawLeftAndRightBorders
    cmp byte [ebp + wBoxDataStart], 10
    jb .ret
    hlcoord 14, 3                        ; PROJ — pret hlcoord 4, 0 -> (4+10, 0+3)
    mov edx, wBoxSpecies + 9
    mov cl, 6
    call PrintPCBox_PlaceBoxMonInfo
.ret:
    ret

; ---------------------------------------------------------------------------
; PrintPCBox_DrawPage4 — pret engine/printer/printer.asm:841-859.
;
; DEVIATION{class=projection; pret=engine/printer/printer.asm:PrintPCBox_DrawPage4; behavior=the PC box print page 4 layout is centered on the 40x25 canvas by adding 10 columns and 3 rows to pret hlcoords; evidence=pret 20x18 layout centered on port 40x25 canvas per maintainer screen projection ruling; lifetime=permanent while the port renders a 40x25 canvas}
; ---------------------------------------------------------------------------
PrintPCBox_DrawPage4:
    call ClearScreen
    call PrintPCBox_PlaceHorizontalLines
    call PrintPCBox_DrawLeftAndRightBorders
    hlcoord 10, 18                       ; PROJ — pret hlcoord 0, 15 -> (0+10, 15+3)
    call PrintPCBox_DrawBottomBorderAtHL
    hlcoord 10, 19                       ; PROJ — pret hlcoord 0, 16 -> (0+10, 16+3)
    mov cl, 2
.fill_2_rows:
    push ecx
    push esi
    mov bh, 0
    mov bl, 20
    mov al, ' '
    call FillMemory
    pop esi
    add esi, SCREEN_WIDTH
    pop ecx
    dec cl
    jnz .fill_2_rows

    cmp byte [ebp + wBoxDataStart], 16
    jb .ret
    hlcoord 14, 3                        ; PROJ — pret hlcoord 4, 0 -> (4+10, 0+3)
    mov edx, wBoxSpecies + 15
    mov cl, 5
    call PrintPCBox_PlaceBoxMonInfo
.ret:
    ret

; ---------------------------------------------------------------------------
; PrintPCBox_PlaceBoxMonInfo — pret engine/printer/printer.asm:860-914.
; ---------------------------------------------------------------------------
PrintPCBox_PlaceBoxMonInfo:
.loop:
    test cl, cl
    jz .done
    dec cl
    mov al, [ebp + edx]
    cmp al, 0xFF
    je .done
    mov [ebp + wPokedexNum], al
    push ecx
    push esi
    push edx

    push esi
    mov bh, 0
    mov bl, 12
    mov al, ' '
    call FillMemory
    pop esi

    push esi
    add esi, SCREEN_WIDTH
    mov bh, 0
    mov bl, 12
    mov al, ' '
    call FillMemory
    pop esi

    push esi
    call GetMonName
    lea eax, [ebp + wNameBuffer]
    pop esi
    call PlaceString

    push esi
    mov esi, wBoxMonNicks
    mov bh, 0
    mov bl, NAME_LENGTH
    mov al, [ebp + wBoxNumString]
    call AddNTimes
    lea edx, [ebp + esi]
    mov eax, edx
    pop esi
    add esi, SCREEN_WIDTH + 1
    mov byte [ebp + esi], ' '            ; blank tile instead of "/"
    inc esi
    call PlaceString

    inc byte [ebp + wBoxNumString]

    pop edx
    pop esi
    add esi, 3 * SCREEN_WIDTH
    pop ecx
    inc edx
    jmp .loop

.done:
    ret

; ---------------------------------------------------------------------------
; PrintPCBox_DrawTopBorder — pret engine/printer/printer.asm:915-927.
; ---------------------------------------------------------------------------
PrintPCBox_DrawTopBorder:
    hlcoord 10, 3                        ; PROJ — pret hlcoord 0, 0
    mov byte [ebp + esi], 0x79           ; ld a, $79 / ld [hli], a
    inc esi
    mov al, 0x7A                         ; ld a, $7a
    mov cl, 18                           ; SCREEN_WIDTH - 2
.loop:
    mov [ebp + esi], al
    inc esi
    dec cl
    jnz .loop
    mov byte [ebp + esi], 0x7B           ; ld a, $7b / ld [hl], a
    ret

; ---------------------------------------------------------------------------
; PrintPCBox_DrawLeftAndRightBorders — pret engine/printer/printer.asm:929-942.
; ---------------------------------------------------------------------------
PrintPCBox_DrawLeftAndRightBorders:
    hlcoord 10, 3                        ; PROJ — pret hlcoord 0, 0
    mov cl, 18                           ; SCREEN_HEIGHT
.loop:
    mov byte [ebp + esi], 0x7C           ; ld a, $7c / ld [hl], a
    mov byte [ebp + esi + 19], 0x7C      ; right border of 20-wide box
    add esi, SCREEN_WIDTH                ; advance 1 canvas row (stride 40)
    dec cl
    jnz .loop
    ret

; ---------------------------------------------------------------------------
; PrintPCBox_DrawBottomBorder / ...AtHL — pret engine/printer/printer.asm:944-956.
; ---------------------------------------------------------------------------
PrintPCBox_DrawBottomBorder:
    hlcoord 10, 20                       ; PROJ — pret hlcoord 0, 17
PrintPCBox_DrawBottomBorderAtHL:
    mov byte [ebp + esi], 0x7D           ; ld a, $7d / ld [hli], a
    inc esi
    mov al, 0x7A                         ; ld a, $7a
    mov cl, 18                           ; SCREEN_WIDTH - 2
.loop:
    mov [ebp + esi], al
    inc esi
    dec cl
    jnz .loop
    mov byte [ebp + esi], 0x7E           ; ld a, $7e / ld [hl], a
    ret

; ---------------------------------------------------------------------------
; PrintPCBox_PlaceHorizontalLines — pret engine/printer/printer.asm:958-976.
; ---------------------------------------------------------------------------
PrintPCBox_PlaceHorizontalLines:
    hlcoord 14, 3                        ; PROJ — pret hlcoord 4, 0 -> (4+10, 0+3)
    mov cl, 6
    call .PlaceHorizontalLine
    hlcoord 16, 4                        ; PROJ — pret hlcoord 6, 1 -> (6+10, 1+3)
    mov cl, 6
.PlaceHorizontalLine:
.loop:
    push ecx
    push esi
    mov edx, PrinterHorizontalLineString ; ld de, .HorizontalLineString
    mov eax, edx
    call PlaceString
    pop esi
    add esi, 3 * SCREEN_WIDTH            ; ld bc, 3 * SCREEN_WIDTH / add hl, bc
    pop ecx
    dec cl
    jnz .loop
    ret

; ---------------------------------------------------------------------------
; SurfingPikachu2Graphics — pret engine/printer/printer.asm:699-732.
; ---------------------------------------------------------------------------
section .data

%include "assets/surfing_pikachu2.inc"
