; lcd_control.asm — DisableLCD / EnableLCD.
;
; Sources: home/lcd.asm:DisableLCD, EnableLCD
;
; ClearBgMap and FillBgMap are home/vcopy.asm labels and moved to that mirror,
; src/home/vcopy.asm.
;
; The LCD on/off dance on real hardware races the PPU scanline counter and
; toggles rLCDC bit 7. In this port the renderer is driven by the main loop,
; so we only keep/clear the shadow bit — there is no scanline hazard.
; ; TODO-HW: honour LCD-off timing if a scanline-accurate renderer is added.
;
; Build: nasm -f coff -I include/ -o lcd_control.o lcd_control.asm

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"

LCDC_ON_BIT equ 7

global DisableLCD
global EnableLCD

section .text

; ---------------------------------------------------------------------------
; DisableLCD — clear LCD-enable bit in the LCDC shadow. All registers preserved.
; ---------------------------------------------------------------------------
DisableLCD:
    and byte [ebp + IO_LCDC], ~(1 << LCDC_ON_BIT) & 0xFF
    ret

; ---------------------------------------------------------------------------
; EnableLCD — set LCD-enable bit in the LCDC shadow. All registers preserved.
; ---------------------------------------------------------------------------
EnableLCD:
    or byte [ebp + IO_LCDC], (1 << LCDC_ON_BIT)
    ret
